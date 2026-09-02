import {
  createCipheriv,
  createECDH,
  createPrivateKey,
  generateKeyPairSync,
  hkdfSync,
  randomBytes,
  sign as signWith,
} from 'node:crypto';

/**
 * Web Push, written out rather than installed.
 *
 * This is the one thing in the product that has to work while nobody is
 * looking at the app, which is most of the time — a proximity app whose
 * messages only arrive when you already have it open is a chat you have to
 * remember to check, and nobody does. So it earns the weight.
 *
 * It is ~150 lines against `node:crypto` instead of a dependency because the
 * server has none at all, and that is a property worth keeping for something
 * that holds phone numbers and private messages: every package added here is
 * a supply chain that can reach them. The protocol is small and frozen —
 * RFC 8291 for the encryption, RFC 8292 for the signature — so this is code
 * that gets written once and then does not move.
 *
 * The payload is encrypted end-to-end with a key only the subscriber's browser
 * holds. Google's and Mozilla's push services relay the bytes; they cannot
 * read them, which is the reason a message body may be put in one at all.
 */

const b64url = (buffer) => Buffer.from(buffer).toString('base64url');
const fromB64url = (value) => Buffer.from(String(value), 'base64url');

/**
 * A VAPID keypair, generated once and kept for the life of the deployment.
 *
 * The public half is baked into every subscription a browser creates. Change
 * it and every existing subscription silently stops working — the push service
 * refuses a message signed by a key that does not match the one the
 * subscription was made with — so this is generated like the JWT secret: once,
 * on the server, into a file nothing else touches.
 */
export function generateVapidKeys() {
  const { privateKey } = generateKeyPairSync('ec', {
    namedCurve: 'prime256v1',
  });
  const jwk = privateKey.export({ format: 'jwk' });
  // The browser wants the public half as one uncompressed point, not as a JWK.
  const raw = Buffer.concat([
    Buffer.from([0x04]),
    fromB64url(jwk.x),
    fromB64url(jwk.y),
  ]);
  return {
    publicKey: b64url(raw),
    privateKey: jwk.d,
    createdAt: new Date().toISOString(),
  };
}

/** Rebuilds a signing key from the two base64url halves we store. */
function vapidSigningKey({ publicKey, privateKey }) {
  const raw = fromB64url(publicKey);
  if (raw.length !== 65 || raw[0] !== 0x04) {
    throw new Error('VAPID public key must be a 65-byte uncompressed point');
  }
  return createPrivateKey({
    format: 'jwk',
    key: {
      kty: 'EC',
      crv: 'P-256',
      x: b64url(raw.subarray(1, 33)),
      y: b64url(raw.subarray(33, 65)),
      d: privateKey,
    },
  });
}

/**
 * The `Authorization` header that tells a push service who is asking.
 *
 * Signed over the *origin* of the endpoint, not the endpoint itself: the full
 * URL contains the subscription id, and it has no business inside a token that
 * gets logged by every hop on the way.
 */
function vapidHeader(endpoint, keys, subject) {
  const audience = new URL(endpoint).origin;
  const header = b64url(JSON.stringify({ typ: 'JWT', alg: 'ES256' }));
  const payload = b64url(
    JSON.stringify({
      aud: audience,
      // Twelve hours. The spec caps it at 24; shorter limits what a leaked
      // token is worth without making the server re-sign on every message.
      exp: Math.floor(Date.now() / 1000) + 12 * 60 * 60,
      sub: subject,
    }),
  );
  const signature = signWith(
    'sha256',
    Buffer.from(`${header}.${payload}`),
    // ES256 wants the raw r||s pair. Node's default is DER, which every push
    // service rejects with a bare 401 and no explanation.
    { key: vapidSigningKey(keys), dsaEncoding: 'ieee-p1363' },
  );
  return `vapid t=${header}.${payload}.${b64url(signature)}, k=${keys.publicKey}`;
}

/** RFC 8188 record size. One record is plenty for a name and a line of text. */
const RECORD_SIZE = 4096;

/**
 * Encrypts a payload for one subscription (RFC 8291, `aes128gcm`).
 *
 * The shape of the derivation is worth stating because it is easy to get
 * subtly wrong and the only symptom is a browser that silently drops the
 * message: the subscription's `auth` secret is the salt of the *first* HKDF,
 * whose output then becomes the key material of the second. Skipping that
 * first step yields a key that encrypts fine and decrypts nowhere.
 */
function encrypt(payload, { p256dh, auth }) {
  const userPublic = fromB64url(p256dh);
  const authSecret = fromB64url(auth);
  if (userPublic.length !== 65 || authSecret.length !== 16) {
    throw new Error('malformed push subscription keys');
  }

  const ecdh = createECDH('prime256v1');
  const serverPublic = ecdh.generateKeys();
  const shared = ecdh.computeSecret(userPublic);

  const keyInfo = Buffer.concat([
    Buffer.from('WebPush: info\0'),
    userPublic,
    serverPublic,
  ]);
  const ikm = Buffer.from(hkdfSync('sha256', shared, authSecret, keyInfo, 32));

  const salt = randomBytes(16);
  const cek = Buffer.from(
    hkdfSync('sha256', ikm, salt, Buffer.from('Content-Encoding: aes128gcm\0'), 16),
  );
  const nonce = Buffer.from(
    hkdfSync('sha256', ikm, salt, Buffer.from('Content-Encoding: nonce\0'), 12),
  );

  // 0x02 marks the last record. Without it Chrome accepts the message and
  // Firefox does not, which is a delightful afternoon to debug.
  const plaintext = Buffer.concat([
    Buffer.from(payload, 'utf8'),
    Buffer.from([0x02]),
  ]);
  if (plaintext.length + 16 > RECORD_SIZE) {
    throw new Error('push payload too large for one record');
  }

  const cipher = createCipheriv('aes-128-gcm', cek, nonce);
  const body = Buffer.concat([
    cipher.update(plaintext),
    cipher.final(),
    cipher.getAuthTag(),
  ]);

  const recordSize = Buffer.alloc(4);
  recordSize.writeUInt32BE(RECORD_SIZE, 0);

  return Buffer.concat([
    salt,
    recordSize,
    Buffer.from([serverPublic.length]),
    serverPublic,
    body,
  ]);
}

/**
 * Delivers one notification.
 *
 * Returns `{ ok, gone }`. `gone` is the important one: a browser that has been
 * uninstalled, cleared or permission-revoked answers 404 or 410 forever, and a
 * server that does not act on that keeps a dead row and retries it for the
 * rest of the machine's life.
 */
export async function sendPush({
  subscription,
  payload,
  keys,
  subject,
  ttlSeconds = 12 * 60 * 60,
  timeoutMs = 8000,
}) {
  const body = encrypt(payload, subscription);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(subscription.endpoint, {
      method: 'POST',
      signal: controller.signal,
      headers: {
        Authorization: vapidHeader(subscription.endpoint, keys, subject),
        'Content-Encoding': 'aes128gcm',
        'Content-Type': 'application/octet-stream',
        TTL: String(ttlSeconds),
        // Above "normal" so a phone with the screen off still wakes for it.
        Urgency: 'high',
      },
      body,
    });
    return {
      ok: response.status >= 200 && response.status < 300,
      gone: response.status === 404 || response.status === 410,
      status: response.status,
    };
  } catch (error) {
    // A push service that is down, slow, or unreachable must never take a
    // message send down with it.
    return { ok: false, gone: false, status: 0, error: String(error) };
  } finally {
    clearTimeout(timer);
  }
}
