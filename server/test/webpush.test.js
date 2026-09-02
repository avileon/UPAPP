import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createDecipheriv,
  createECDH,
  createPublicKey,
  hkdfSync,
  verify as verifyWith,
} from 'node:crypto';

import { generateVapidKeys } from '../src/lib/webpush.js';

/**
 * Web Push, verified by playing the browser's part.
 *
 * This is hand-rolled crypto against a spec, which is exactly the code that
 * cannot be checked by reading it: every mistake in a key derivation produces
 * bytes that look perfectly random and decrypt to nothing. The only honest
 * test is to be the subscriber — generate a keypair the way a browser does,
 * hand over the public half, and decrypt what comes back.
 *
 * The parts pinned here are the ones with no second chance in production: a
 * push service answers a bad signature with a bare 401, and a browser that
 * cannot decrypt a payload drops it in silence.
 */

const b64url = (buffer) => Buffer.from(buffer).toString('base64url');
const fromB64url = (value) => Buffer.from(String(value), 'base64url');

/** Stands in for a browser: the keypair a real `pushManager.subscribe` makes. */
function fakeSubscriber() {
  const ecdh = createECDH('prime256v1');
  const publicKey = ecdh.generateKeys();
  return {
    endpoint: 'https://push.example.com/subscription/abc123',
    p256dh: b64url(publicKey),
    auth: b64url(Buffer.from('0123456789abcdef')),
    _private: ecdh,
  };
}

/** The receiving half of RFC 8291, written independently of the sender. */
function decrypt(body, subscriber) {
  const salt = body.subarray(0, 16);
  const idlen = body.readUInt8(20);
  const serverPublic = body.subarray(21, 21 + idlen);
  const ciphertext = body.subarray(21 + idlen);

  const shared = subscriber._private.computeSecret(serverPublic);
  const userPublic = fromB64url(subscriber.p256dh);
  const authSecret = fromB64url(subscriber.auth);

  const keyInfo = Buffer.concat([
    Buffer.from('WebPush: info\0'),
    userPublic,
    serverPublic,
  ]);
  const ikm = Buffer.from(hkdfSync('sha256', shared, authSecret, keyInfo, 32));
  const cek = Buffer.from(
    hkdfSync('sha256', ikm, salt, Buffer.from('Content-Encoding: aes128gcm\0'), 16),
  );
  const nonce = Buffer.from(
    hkdfSync('sha256', ikm, salt, Buffer.from('Content-Encoding: nonce\0'), 12),
  );

  const tag = ciphertext.subarray(ciphertext.length - 16);
  const decipher = createDecipheriv('aes-128-gcm', cek, nonce);
  decipher.setAuthTag(tag);
  const plaintext = Buffer.concat([
    decipher.update(ciphertext.subarray(0, ciphertext.length - 16)),
    decipher.final(),
  ]);

  // The last byte is the record delimiter, not content.
  assert.equal(plaintext.at(-1), 0x02, 'last record must be marked 0x02');
  return plaintext.subarray(0, plaintext.length - 1).toString('utf8');
}

/**
 * Captures what `sendPush` would put on the wire, without a network.
 *
 * `fetch` is a global, which is the one thing that makes this testable at all
 * against a module that takes no transport parameter.
 */
async function capture(fn) {
  const original = globalThis.fetch;
  let captured = null;
  globalThis.fetch = async (url, init) => {
    captured = { url, init };
    return { status: 201 };
  };
  try {
    await fn();
  } finally {
    globalThis.fetch = original;
  }
  return captured;
}

test('web push', async (t) => {
  const { sendPush } = await import('../src/lib/webpush.js');
  const keys = generateVapidKeys();
  const subject = 'mailto:test@example.com';

  await t.test('a subscriber can decrypt what we send them', async () => {
    const subscription = fakeSubscriber();
    const payload = JSON.stringify({ kind: 'message', title: 'דנה', body: 'היי' });

    const captured = await capture(() =>
      sendPush({ subscription, payload, keys, subject }),
    );

    assert.equal(captured.url, subscription.endpoint);
    assert.equal(captured.init.headers['Content-Encoding'], 'aes128gcm');
    assert.equal(decrypt(Buffer.from(captured.init.body), subscription), payload);
  });

  await t.test('every message uses a fresh salt and ephemeral key', async () => {
    // Reusing either would leak the relationship between two messages to the
    // push service, which sees the ciphertext of both.
    const subscription = fakeSubscriber();
    const first = await capture(() =>
      sendPush({ subscription, payload: 'a', keys, subject }),
    );
    const second = await capture(() =>
      sendPush({ subscription, payload: 'a', keys, subject }),
    );

    const salt = (body) => Buffer.from(body).subarray(0, 16).toString('hex');
    const ephemeral = (body) => Buffer.from(body).subarray(21, 86).toString('hex');
    assert.notEqual(salt(first.init.body), salt(second.init.body));
    assert.notEqual(ephemeral(first.init.body), ephemeral(second.init.body));
  });

  await t.test('the VAPID token is a real ES256 signature over the origin',
    async () => {
      const subscription = fakeSubscriber();
      const captured = await capture(() =>
        sendPush({ subscription, payload: 'x', keys, subject }),
      );

      const header = captured.init.headers.Authorization;
      assert.match(header, /^vapid t=[\w-]+\.[\w-]+\.[\w-]+, k=[\w-]+$/);

      const [, token] = header.match(/t=([^,]+)/);
      const [head, claims, signature] = token.split('.');
      assert.deepEqual(JSON.parse(fromB64url(head).toString()), {
        typ: 'JWT',
        alg: 'ES256',
      });

      const payload = JSON.parse(fromB64url(claims).toString());
      // The origin, never the full endpoint: the path carries the
      // subscription id and has no business inside a token every hop logs.
      assert.equal(payload.aud, 'https://push.example.com');
      assert.equal(payload.sub, subject);
      assert.ok(payload.exp > Math.floor(Date.now() / 1000));
      assert.ok(payload.exp <= Math.floor(Date.now() / 1000) + 24 * 60 * 60);

      const raw = fromB64url(keys.publicKey);
      const verified = verifyWith(
        'sha256',
        Buffer.from(`${head}.${claims}`),
        {
          key: createPublicKey({
            format: 'jwk',
            key: {
              kty: 'EC',
              crv: 'P-256',
              x: b64url(raw.subarray(1, 33)),
              y: b64url(raw.subarray(33, 65)),
            },
          }),
          dsaEncoding: 'ieee-p1363',
        },
        fromB64url(signature),
      );
      assert.ok(verified, 'the push service must be able to verify this');
    });

  await t.test('a dead subscription is reported as gone, not as failed',
    async () => {
      // The distinction is the whole reason the caller can clean up: a 410 is
      // permanent and the row has to go, a 500 is the push service having a
      // bad minute and the row must stay.
      const subscription = fakeSubscriber();
      const original = globalThis.fetch;
      globalThis.fetch = async () => ({ status: 410 });
      try {
        const result = await sendPush({
          subscription,
          payload: 'x',
          keys,
          subject,
        });
        assert.equal(result.gone, true);
        assert.equal(result.ok, false);
      } finally {
        globalThis.fetch = original;
      }
    });

  await t.test('a push service that never answers does not throw', async () => {
    // This runs inside a request handler's shadow. An unhandled rejection here
    // would take down message sending for a network problem in another country.
    const subscription = fakeSubscriber();
    const original = globalThis.fetch;
    globalThis.fetch = async () => {
      throw new Error('ECONNRESET');
    };
    try {
      const result = await sendPush({ subscription, payload: 'x', keys, subject });
      assert.equal(result.ok, false);
      assert.equal(result.gone, false);
    } finally {
      globalThis.fetch = original;
    }
  });

  await t.test('malformed subscription keys are refused before any network',
    async () => {
      await assert.rejects(
        () =>
          sendPush({
            subscription: { endpoint: 'https://x/y', p256dh: 'AAAA', auth: 'AAAA' },
            payload: 'x',
            keys,
            subject,
          }),
        /malformed push subscription keys/,
      );
    });
});

test('VAPID keys are a usable P-256 pair', () => {
  const keys = generateVapidKeys();
  const raw = fromB64url(keys.publicKey);
  assert.equal(raw.length, 65);
  assert.equal(raw[0], 0x04, 'browsers want an uncompressed point');
  assert.equal(fromB64url(keys.privateKey).length, 32);
  assert.notEqual(generateVapidKeys().publicKey, keys.publicKey);
});
