import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync } from 'node:fs';

import { sniffImage } from '../src/lib/media.js';
import { startTestServer } from './helpers.js';

/** The smallest valid PNG: 1×1, transparent. */
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk' +
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);

/** A JPEG header followed by filler — enough to be sniffed as a JPEG. */
const JPEG = Buffer.concat([
  Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01]),
  Buffer.alloc(64, 0x20),
]);

/**
 * Photos.
 *
 * This is the part of the product where a mistake is not an inconvenience: the
 * files are photographs of real people, uploaded on the understanding that
 * only the people the server decides can see them will. Everything below is a
 * rule the server has to enforce because no client can be trusted to.
 */
test('photos', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  await t.test('a photo round-trips: upload, listed on the profile, fetched back', async () => {
    const a = await s.signUp('+972530000001');

    const upload = await s.uploadPhoto(a, PNG);
    assert.equal(upload.status, 200);
    assert.match(upload.body.key, /^[0-9a-f]{32}\.png$/);
    assert.deepEqual(upload.body.photos, [upload.body.key]);

    const profile = await s.call('GET', '/me/profile', { token: a.token });
    assert.deepEqual(profile.body.photos, [upload.body.key]);

    const fetched = await fetch(`${s.base}/media/${upload.body.key}`, {
      headers: { authorization: `Bearer ${a.token}` },
    });
    assert.equal(fetched.status, 200);
    assert.equal(fetched.headers.get('content-type'), 'image/png');
    assert.equal(fetched.headers.get('x-content-type-options'), 'nosniff');
    const body = Buffer.from(await fetched.arrayBuffer());
    assert.deepEqual(body, PNG, 'the bytes that come back are the bytes that went in');
  });

  await t.test('a second fetch of the same photo is a 304, with its ETag', async () => {
    const a = await s.signUp('+972530000013');
    const upload = await s.uploadPhoto(a, PNG);

    const first = await fetch(`${s.base}/media/${upload.body.key}`, {
      headers: { authorization: `Bearer ${a.token}` },
    });
    const etag = first.headers.get('etag');
    assert.ok(etag, 'a photo must be cacheable by its content');

    const second = await fetch(`${s.base}/media/${upload.body.key}`, {
      headers: {
        authorization: `Bearer ${a.token}`,
        'if-none-match': etag,
      },
    });
    assert.equal(second.status, 304);
    assert.equal(second.headers.get('etag'), etag);
    assert.equal(second.headers.get('content-length'), null);
  });

  await t.test('a stranger cannot fetch a photo', async () => {
    // Not "a different user cannot" — that is the next rule to build. This is
    // the floor: an unauthenticated URL is worthless on its own.
    const a = await s.signUp('+972530000002');
    const upload = await s.uploadPhoto(a, PNG);

    const anonymous = await fetch(`${s.base}/media/${upload.body.key}`);
    assert.equal(anonymous.status, 401);

    const forged = await fetch(`${s.base}/media/${upload.body.key}`, {
      headers: { authorization: 'Bearer forged.token.value' },
    });
    assert.equal(forged.status, 401);
  });

  await t.test('the bytes decide the type, not the header', async () => {
    const a = await s.signUp('+972530000003');

    // An executable announcing itself as a JPEG.
    const notAnImage = Buffer.concat([
      Buffer.from([0x4d, 0x5a, 0x90, 0x00]),
      Buffer.alloc(64, 0x41),
    ]);
    const refused = await s.uploadPhoto(a, notAnImage, 'image/jpeg');
    assert.equal(refused.status, 400);
    assert.equal(refused.body.error, 'not_an_image');

    // A real JPEG announcing itself as something else is still a JPEG.
    const accepted = await s.uploadPhoto(a, JPEG, 'application/octet-stream');
    assert.equal(accepted.status, 200);
    assert.match(accepted.body.key, /[.]jpg$/);
  });

  await t.test('a key is a name we chose', async () => {
    const a = await s.signUp('+972530000004');
    for (const key of [
      '..%2F..%2Fetc%2Fpasswd',
      'not-a-key.png',
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.exe',
    ]) {
      const res = await s.call('GET', `/media/${key}`, { token: a.token });
      assert.equal(res.status, 404, key);
    }
  });

  await t.test('the photo limit holds and leaves nothing on disk', async () => {
    const a = await s.signUp('+972530000005');
    for (let i = 0; i < 6; i++) {
      assert.equal((await s.uploadPhoto(a, PNG)).status, 200, `photo ${i + 1}`);
    }
    const before = readdirSync(s.photoDir).length;

    const seventh = await s.uploadPhoto(a, PNG);
    assert.equal(seventh.status, 400);
    assert.equal(seventh.body.error, 'photo_limit_reached');
    assert.equal(
      readdirSync(s.photoDir).length,
      before,
      'a refused upload must not leave an orphan file',
    );
  });

  await t.test('deleting a photo removes the row and the file', async () => {
    const a = await s.signUp('+972530000006');
    const upload = await s.uploadPhoto(a, PNG);

    const deleted = await s.call('DELETE', `/media/${upload.body.key}`, {
      token: a.token,
    });
    assert.equal(deleted.status, 200);
    assert.deepEqual(deleted.body.photos, []);

    const gone = await s.call('GET', `/media/${upload.body.key}`, { token: a.token });
    assert.equal(gone.status, 404);
  });

  await t.test('one person cannot delete another person\'s photo', async () => {
    const a = await s.signUp('+972530000007');
    const b = await s.signUp('+972530000008');
    const upload = await s.uploadPhoto(a, PNG);

    const attempt = await s.call('DELETE', `/media/${upload.body.key}`, {
      token: b.token,
    });
    assert.equal(attempt.status, 404);

    // Not `s.call` — that parses JSON, and this response is a PNG.
    const still = await fetch(`${s.base}/media/${upload.body.key}`, {
      headers: { authorization: `Bearer ${a.token}` },
    });
    assert.equal(still.status, 200);
  });

  await t.test('a resolved profile carries photo keys and still nothing else', async () => {
    const a = await s.signUp('+972530000009', { gender: 'male', interestedIn: 'everyone' });
    const b = await s.signUp('+972530000010', { gender: 'female', interestedIn: 'everyone' });
    const upload = await s.uploadPhoto(b, PNG);

    await s.goLiveAt(a, 'PHOTOS1');
    await s.goLiveAt(b, 'PHOTOS1');

    const person = (await s.nearby(a)).body.people[0];
    assert.deepEqual(person.photos, [upload.body.key]);
    assert.deepEqual(
      Object.keys(person).sort(),
      [
        'age',
        'bio',
        'firstName',
        'id',
        'photoVerified',
        'photos',
        'sentYouUp',
        'youSentUp',
      ].sort(),
    );
  });

  await t.test('deleting an account takes the photos with it', async () => {
    const a = await s.signUp('+972530000011');
    const upload = await s.uploadPhoto(a, PNG);
    const before = readdirSync(s.photoDir).length;

    await s.call('DELETE', '/me', { token: a.token });

    assert.equal(readdirSync(s.photoDir).length, before - 1);
    const other = await s.signUp('+972530000012');
    const gone = await s.call('GET', `/media/${upload.body.key}`, { token: other.token });
    assert.equal(gone.status, 404);
  });
});

test('image sniffing', async (t) => {
  await t.test('recognises the three formats a phone actually produces', () => {
    assert.equal(sniffImage(PNG)?.ext, 'png');
    assert.equal(sniffImage(JPEG)?.ext, 'jpg');
    const webp = Buffer.concat([
      Buffer.from('RIFF'),
      Buffer.alloc(4),
      Buffer.from('WEBP'),
      Buffer.alloc(16),
    ]);
    assert.equal(sniffImage(webp)?.ext, 'webp');
  });

  await t.test('refuses everything else, including near-misses', () => {
    assert.equal(sniffImage(Buffer.alloc(0)), null);
    assert.equal(sniffImage(Buffer.from('GIF89a-and-then-some')), null);
    assert.equal(sniffImage(Buffer.from('%PDF-1.7 and then some')), null);
    // Right container, wrong payload: RIFF is also WAV.
    const wav = Buffer.concat([
      Buffer.from('RIFF'),
      Buffer.alloc(4),
      Buffer.from('WAVE'),
      Buffer.alloc(16),
    ]);
    assert.equal(sniffImage(wav), null);
    assert.equal(sniffImage('not a buffer'), null);
  });
});
