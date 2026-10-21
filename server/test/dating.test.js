import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync } from 'node:fs';

import { config } from '../src/config.js';
import { judgeLiveAttempt } from '../src/domain/face.js';
import { HERE, startTestServer } from './helpers.js';

/**
 * October 2026: UP becomes a dating / meet-people app.
 *
 * Venues with a QR + location check and a one-hour stay, "who is in my area"
 * by location, hide-for-this-visit versus block, four photos with a chosen
 * main one, and face checks that run automatically.
 */

const PNG_HEAD = Buffer.from('89504e470d0a1a0a00000000', 'hex');
/** An "image" the fake face service recognises by its last 8 bytes. */
const img = (tag) => Buffer.concat([PNG_HEAD, Buffer.from(tag.padEnd(8).slice(0, 8), 'latin1')]);

/** A deterministic unit-ish vector per person, with a little per-frame noise. */
function vec(person, noise = 0) {
  const out = [];
  let seed = [...person].reduce((a, c) => a * 31 + c.charCodeAt(0), 7) >>> 0;
  for (let i = 0; i < 128; i++) {
    seed = (seed * 1103515245 + 12345) >>> 0;
    out.push(((seed % 2000) / 1000 - 1) + noise * Math.sin(i * 7.3 + noise * 13));
  }
  const n = Math.hypot(...out);
  return out.map((v) => v / n);
}
const b64 = (arr) => {
  const buf = Buffer.alloc(512);
  arr.forEach((v, i) => buf.writeFloatLE(v, i * 4));
  return buf.toString('base64');
};
const face = (person, { yaw = 0, noise = 0.05, blur = 100, score = 0.98, width = 300 } = {}) => ({
  box: [100, 100, width, width],
  score,
  yaw,
  pitch: 0.5,
  blur,
  embedding: b64(vec(person, noise)),
});
const analysis = (...faces) => ({ width: 640, height: 640, faces });

const YAW = { center: 0.01, left: -0.4, right: 0.4 };

test('venues: QR code + location, one hour', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  const join = (user, extra = {}) =>
    s.call('POST', '/live/start', { token: user.token, body: { venue: 'PUB1', ...HERE, ...extra } });

  s.registerVenue('PUB1');

  await t.test('inside the radius: in, for exactly the venue hour', async () => {
    const a = await s.signUp('+972570000001');
    const res = await join(a, { durationSeconds: 7200 });
    assert.equal(res.status, 200);
    assert.equal(res.body.venue, 'PUB1');
    assert.equal(res.body.venueName, 'Venue PUB1');
    assert.equal(res.body.mode, 'venue');
    const minutes = (new Date(res.body.expiresAt) - Date.now()) / 60000;
    assert.ok(minutes > 59 && minutes <= 60, `got ${minutes}`);
  });

  await t.test('no location, no entry', async () => {
    const a = await s.signUp('+972570000002');
    const res = await s.call('POST', '/live/start', { token: a.token, body: { venue: 'PUB1' } });
    assert.equal(res.status, 400);
    assert.equal(res.body.error, 'location_required');
  });

  await t.test('a photo of the QR sent to a friend at home does not work', async () => {
    const a = await s.signUp('+972570000003');
    const res = await join(a, { lat: HERE.lat + 0.02, lng: HERE.lng }); // ~2km away
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'too_far');
  });

  await t.test('a fix too vague to mean anything is no fix', async () => {
    const a = await s.signUp('+972570000004');
    const res = await join(a, { accuracy: 3000 });
    assert.equal(res.body.error, 'location_required');
  });

  await t.test('GPS error is forgiven, up to a cap', async () => {
    const a = await s.signUp('+972570000005');
    // ~150m north; radius 80 + accuracy credit up to 150 → allowed.
    const near = await join(a, { lat: HERE.lat + 0.00135, accuracy: 120 });
    assert.equal(near.status, 200);
    // ~400m north with a claimed 450m accuracy: credit is capped at 150.
    const far = await join(a, { lat: HERE.lat + 0.0036, accuracy: 450 });
    assert.equal(far.status, 403);
  });

  await t.test('an inactive venue is not a room', async () => {
    const a = await s.signUp('+972570000006');
    s.registerVenue('SHUT1');
    s.store.updateVenue('SHUT1', { active: false });
    const res = await s.call('POST', '/live/start', {
      token: a.token,
      body: { venue: 'SHUT1', ...HERE },
    });
    assert.equal(res.body.error, 'venue_unknown');
  });

  await t.test('the venue name is available to the join screen', async () => {
    const a = await s.signUp('+972570000007');
    const res = await s.call('GET', '/venues/pub1', { token: a.token });
    assert.equal(res.status, 200);
    assert.equal(res.body.name, 'Venue PUB1');
    assert.equal(res.body.lat, undefined);
  });

  await t.test('people in a venue do not see people in area mode, and vice versa', async () => {
    const a = await s.signUp('+972570000008');
    const b = await s.signUp('+972570000009');
    s.registerVenue('SOLO1');
    await s.call('POST', '/live/start', { token: a.token, body: { venue: 'SOLO1', ...HERE } });
    await s.call('POST', '/live/start', { token: b.token, body: { mode: 'area', ...HERE } });
    assert.deepEqual((await s.nearby(a)).body.people, []);
    assert.deepEqual((await s.nearby(b)).body.people, []);
  });
});

test('area mode: who is around me', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  const area = (user, pos = HERE) =>
    s.call('POST', '/live/start', { token: user.token, body: { durationSeconds: 1800, ...pos } });

  await t.test('within the radius, yes; across town, no', async () => {
    const a = await s.signUp('+972571000001', { firstName: 'Avi' });
    const b = await s.signUp('+972571000002', { firstName: 'Dana' });
    const c = await s.signUp('+972571000003', { firstName: 'Far' });
    assert.equal((await area(a)).body.mode, 'area');
    await area(b, { ...HERE, lat: HERE.lat + 0.002 }); // ~220m
    await area(c, { ...HERE, lat: HERE.lat + 0.05 }); // ~5.5km
    const names = (await s.nearby(a)).body.people.map((p) => p.firstName);
    assert.deepEqual(names, ['Dana']);
  });

  await t.test('area without a location is refused', async () => {
    const a = await s.signUp('+972571000004');
    const res = await s.call('POST', '/live/start', { token: a.token, body: { mode: 'area' } });
    assert.equal(res.body.error, 'location_required');
  });

  await t.test('the area follows the phone', async () => {
    const a = await s.signUp('+972571000005');
    const b = await s.signUp('+972571000006');
    const far = { ...HERE, lat: HERE.lat + 0.3 };
    await area(a, far);
    await area(b, { ...far, lat: far.lat + 0.05 });
    assert.equal((await s.nearby(a)).body.people.length, 0);
    // b walks over.
    await s.call('POST', '/nearby/resolve', { token: b.token, body: { ...far } });
    assert.equal((await s.nearby(a)).body.people.length, 1);
  });

  await t.test('a position is never echoed back', async () => {
    const a = await s.signUp('+972571000007');
    const b = await s.signUp('+972571000008');
    const spot = { ...HERE, lng: HERE.lng + 0.5 };
    await area(a, spot);
    await area(b, spot);
    const res = await s.nearby(a);
    assert.ok(!JSON.stringify(res.body).includes(String(spot.lng).slice(0, 6)));
  });
});

test('hide for this visit, block until unblocked', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  await t.test('hidden now, back next visit', async () => {
    const a = await s.signUp('+972572000001');
    const b = await s.signUp('+972572000002');
    await s.goLiveAt(a, 'HIDE1');
    await s.goLiveAt(b, 'HIDE1');
    assert.equal((await s.nearby(a)).body.people.length, 1);

    const hid = await s.call('POST', `/users/${b.id}/hide`, { token: a.token });
    assert.equal(hid.status, 200);
    assert.equal((await s.nearby(a)).body.people.length, 0);
    // One-way: b is not told and still sees a.
    assert.equal((await s.nearby(b)).body.people.length, 1);

    // Scanning again in the same place keeps the hide…
    await s.goLiveAt(a, 'HIDE1');
    assert.equal((await s.nearby(a)).body.people.length, 0);

    // …a new visit does not.
    await s.call('POST', '/live/stop', { token: a.token });
    await s.goLiveAt(a, 'HIDE1');
    assert.equal((await s.nearby(a)).body.people.length, 1);
  });

  await t.test('hiding needs a live session', async () => {
    const a = await s.signUp('+972572000003');
    const b = await s.signUp('+972572000004');
    const res = await s.call('POST', `/users/${b.id}/hide`, { token: a.token });
    assert.equal(res.body.error, 'not_live');
  });

  await t.test('the block list, and lifting a block', async () => {
    const a = await s.signUp('+972572000005', { firstName: 'Avi' });
    const b = await s.signUp('+972572000006', { firstName: 'Bo' });
    await s.call('POST', `/users/${b.id}/block`, { token: a.token });

    const list = await s.call('GET', '/me/blocks', { token: a.token });
    assert.deepEqual(list.body.blocked.map((x) => x.firstName), ['Bo']);
    assert.deepEqual(Object.keys(list.body.blocked[0]).sort(), ['blockedAt', 'firstName', 'id', 'photo']);

    await s.goLiveAt(a, 'BLK1');
    await s.goLiveAt(b, 'BLK1');
    assert.equal((await s.nearby(a)).body.people.length, 0);

    const lifted = await s.call('DELETE', `/users/${b.id}/block`, { token: a.token });
    assert.equal(lifted.status, 200);
    assert.equal((await s.call('GET', '/me/blocks', { token: a.token })).body.blocked.length, 0);
    assert.equal((await s.nearby(a)).body.people.length, 1);

    const again = await s.call('DELETE', `/users/${b.id}/block`, { token: a.token });
    assert.equal(again.status, 404);
  });

  await t.test('someone else\'s block cannot be lifted', async () => {
    const a = await s.signUp('+972572000007');
    const b = await s.signUp('+972572000008');
    const c = await s.signUp('+972572000009');
    await s.call('POST', `/users/${b.id}/block`, { token: a.token });
    const res = await s.call('DELETE', `/users/${b.id}/block`, { token: c.token });
    assert.equal(res.status, 404);
    assert.equal(s.store.isBlockedEitherWay(a.id, b.id), true);
  });
});

test('photos: four, and a chosen main one', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  await t.test('the main photo moves to the front for everyone', async () => {
    const a = await s.signUp('+972573000001');
    const keys = [];
    for (let i = 0; i < 3; i++) keys.push((await s.uploadPhoto(a, img(`p${i}`))).body.key);

    const res = await s.call('PUT', '/me/photos/primary', { token: a.token, body: { key: keys[2] } });
    assert.equal(res.status, 200);
    assert.deepEqual(res.body.photos, [keys[2], keys[0], keys[1]]);
    const me = await s.call('GET', '/me/profile', { token: a.token });
    assert.equal(me.body.photos[0], keys[2]);
  });

  await t.test('only your own photo can be main', async () => {
    const a = await s.signUp('+972573000002');
    const b = await s.signUp('+972573000003');
    const theirs = (await s.uploadPhoto(b, img('b0'))).body.key;
    const res = await s.call('PUT', '/me/photos/primary', { token: a.token, body: { key: theirs } });
    assert.equal(res.status, 404);
  });
});

test('going live requires a verified face', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  await t.test('unverified: refused with a code the app can act on', async () => {
    const a = await s.signUp('+972574000001', { verified: false });
    const res = await s.goLiveAt(a, 'VER1');
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'verification_required');
  });
});

test('live face check', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  const consent = (u) =>
    s.call('POST', '/me/biometric/consent', { token: u.token, body: { accepted: true } });
  const challenge = (u) =>
    s.call('POST', '/me/verification/challenge', { token: u.token, body: { mode: 'live' } });

  /** Scripts one frame per step for `person` and returns the request body. */
  const frames = (u, ch, person, { yawSign = 1, override = {} } = {}) => {
    const out = ch.body.steps.map((step, i) => {
      const tag = `${u.id.slice(0, 4)}${i}`;
      const yaw = YAW[step] * yawSign;
      s.faces.set(tag, override[i] ?? analysis(face(person, { yaw, noise: 0.1 + 0.05 * i })));
      return img(tag).toString('base64');
    });
    return { challengeId: ch.body.challengeId, frames: out };
  };

  await t.test('no consent, no live check — the manual route stays open', async () => {
    const a = await s.signUp('+972575000001', { verified: false });
    const live = await challenge(a);
    assert.equal(live.status, 403);
    assert.equal(live.body.error, 'consent_required');
    const manual = await s.call('POST', '/me/verification/challenge', { token: a.token, body: {} });
    assert.equal(manual.body.mode, 'manual');
    assert.ok(manual.body.pose);
  });

  await t.test('a clean sequence is approved automatically and keeps no frames', async () => {
    const a = await s.signUp('+972575000002', { verified: false });
    await consent(a);
    const ch = await challenge(a);
    assert.equal(ch.status, 200);
    assert.equal(ch.body.steps[0], 'center');
    assert.ok(ch.body.steps.includes('left') && ch.body.steps.includes('right'));

    const before = readdirSync(s.selfieDir).length;
    const res = await s.call('POST', '/me/verification/frames', {
      token: a.token,
      body: frames(a, ch, 'alice'),
    });
    assert.equal(res.body.status, 'approved');
    assert.equal(readdirSync(s.selfieDir).length, before);
    const me = await s.call('GET', '/me/verification', { token: a.token });
    assert.equal(me.body.status, 'approved');
    assert.equal(me.body.method, 'live');
    assert.equal(me.body.hasTemplate, true);
    assert.equal((await s.goLiveAt(a, 'FACE1')).status, 200);
  });

  await t.test('a mirrored camera is fine, as long as it is consistent', async () => {
    const a = await s.signUp('+972575000003', { verified: false });
    await consent(a);
    const ch = await challenge(a);
    const res = await s.call('POST', '/me/verification/frames', {
      token: a.token,
      body: frames(a, ch, 'bob', { yawSign: -1 }),
    });
    assert.equal(res.body.status, 'approved');
  });

  await t.test('someone else in the middle of the sequence is refused', async () => {
    const a = await s.signUp('+972575000004', { verified: false });
    await consent(a);
    const ch = await challenge(a);
    const tag = `${a.id.slice(0, 4)}2`;
    const body = frames(a, ch, 'carol', {
      override: { 2: analysis(face('mallory', { yaw: 0.01 })) },
    });
    s.faces.set(tag, analysis(face('mallory', { yaw: 0.01 })));
    const res = await s.call('POST', '/me/verification/frames', { token: a.token, body });
    assert.equal(res.body.status, 'rejected');
    assert.equal(res.body.reason, 'identity_mismatch');
  });

  await t.test('one blurry frame goes to a human, not to a rejection', async () => {
    const a = await s.signUp('+972575000005', { verified: false });
    await consent(a);
    const ch = await challenge(a);
    const res = await s.call('POST', '/me/verification/frames', {
      token: a.token,
      body: frames(a, ch, 'dave', {
        override: { 1: analysis(face('dave', { yaw: YAW[ch.body.steps[1]], blur: 1, noise: 0.03 })) },
      }),
    });
    assert.equal(res.body.status, 'pending');
    assert.equal(readdirSync(s.selfieDir).length >= 1, true);
    assert.equal(s.store.isSelfieVerified(a.id), false);
  });

  await t.test('a challenge answers once', async () => {
    const a = await s.signUp('+972575000006', { verified: false });
    await consent(a);
    const ch = await challenge(a);
    const body = frames(a, ch, 'erin');
    await s.call('POST', '/me/verification/frames', { token: a.token, body });
    const again = await s.call('POST', '/me/verification/frames', { token: a.token, body });
    assert.equal(again.body.error, 'challenge_expired');
  });

  await t.test('face service down: 503 and nothing saved', async () => {
    const a = await s.signUp('+972575000007', { verified: false });
    await consent(a);
    const ch = await challenge(a);
    const body = frames(a, ch, 'fay');
    s.faces.down = true;
    const res = await s.call('POST', '/me/verification/frames', { token: a.token, body });
    s.faces.down = false;
    assert.equal(res.status, 503);
    assert.equal(res.body.error, 'face_service_unavailable');
    assert.equal(s.store.findFaceTemplate(a.id), null);
  });

  await t.test('profile photos are checked against the verified face', async () => {
    const a = await s.signUp('+972575000008', { verified: false });
    await consent(a);
    const ch = await challenge(a);
    await s.call('POST', '/me/verification/frames', { token: a.token, body: frames(a, ch, 'gil') });

    s.faces.set('gil-ok', analysis(face('gil', { noise: 0.1 })));
    s.faces.set('group', analysis(face('zed'), face('gil', { noise: 0.1 })));
    s.faces.set('stranger', analysis(face('zed')));
    s.faces.set('dog', analysis());

    const ok = await s.uploadPhoto(a, img('gil-ok'));
    assert.equal(ok.status, 200);
    assert.equal(ok.body.faceMatch, 'ok');
    assert.equal((await s.uploadPhoto(a, img('group'))).body.faceMatch, 'ok');

    const before = readdirSync(s.photoDir).length;
    const wrong = await s.uploadPhoto(a, img('stranger'));
    assert.equal(wrong.body.error, 'photo_face_mismatch');
    const none = await s.uploadPhoto(a, img('dog'));
    assert.equal(none.body.error, 'photo_no_face');
    assert.equal(readdirSync(s.photoDir).length, before, 'refused photos never touch the disk');
  });

  await t.test('photos from before verification are re-checked and hidden if not you', async () => {
    const a = await s.signUp('+972575000009', { verified: false });
    const viewer = await s.signUp('+972575000010');
    s.faces.set('hana-1', analysis(face('hana', { noise: 0.1 })));
    s.faces.set('notme', analysis(face('zed')));
    const mine = (await s.uploadPhoto(a, img('hana-1'))).body.key;
    const fake = (await s.uploadPhoto(a, img('notme'))).body.key;

    await consent(a);
    const ch = await challenge(a);
    await s.call('POST', '/me/verification/frames', { token: a.token, body: frames(a, ch, 'hana') });
    // The re-check runs after the response; give it a tick.
    await new Promise((r) => setTimeout(r, 50));

    const own = await s.call('GET', '/me/profile', { token: a.token });
    assert.equal(own.body.photoChecks[mine], 'ok');
    assert.equal(own.body.photoChecks[fake], 'rejected');

    await s.goLiveAt(a, 'RECHK');
    await s.goLiveAt(viewer, 'RECHK');
    const seen = (await s.nearby(viewer)).body.people[0];
    assert.deepEqual(seen.photos, [mine]);
  });

  await t.test('deleting biometrics removes the template and the live badge', async () => {
    const a = await s.signUp('+972575000011', { verified: false });
    await consent(a);
    const ch = await challenge(a);
    await s.call('POST', '/me/verification/frames', { token: a.token, body: frames(a, ch, 'ivy') });
    assert.equal(s.store.isSelfieVerified(a.id), true);

    await s.call('DELETE', '/me/biometric', { token: a.token });
    assert.equal(s.store.findFaceTemplate(a.id), null);
    assert.equal(s.store.isSelfieVerified(a.id), false);
    const me = await s.call('GET', '/me/verification', { token: a.token });
    assert.equal(me.body.status, 'none');
    assert.equal(me.body.consent, false);
  });

  await t.test('the judge, directly: a still photo cannot turn its head', () => {
    const still = analysis(face('kim', { yaw: 0.01 }));
    const verdict = judgeLiveAttempt(['center', 'left', 'center', 'right'], [still, still, still, still]);
    assert.equal(verdict.status, 'rejected');
  });
});

test('operator: venues and the admin page', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());
  const previous = config.adminToken;
  config.adminToken = 'op-key';
  t.after(() => {
    config.adminToken = previous;
  });
  const op = (method, path, body) =>
    s.call(method, path, { body, headers: { 'x-admin-token': 'op-key' } });

  await t.test('create, list, deactivate, delete', async () => {
    const created = await op('POST', '/admin/venues', { name: 'פאב הנמל', lat: 32.08, lng: 34.78 });
    assert.equal(created.status, 201);
    assert.match(created.body.code, /^[A-Z0-9]{6}$/);
    assert.equal(created.body.radiusM, config.venues.defaultRadiusM);
    assert.equal(created.body.joinUrl, `${config.publicUrl}/?venue=${created.body.code}`);

    const named = await op('POST', '/admin/venues', { name: 'Bar', code: 'bar-12', lat: 1, lng: 1, radiusM: 120 });
    assert.equal(named.body.code, 'BAR12');
    assert.equal((await op('POST', '/admin/venues', { name: 'Dup', code: 'BAR12', lat: 1, lng: 1 })).body.error, 'code_taken');

    const list = await op('GET', '/admin/venues');
    assert.equal(list.body.venues.length, 2);

    const off = await op('PATCH', `/admin/venues/${created.body.code}`, { active: false });
    assert.equal(off.body.active, false);
    assert.equal((await op('DELETE', '/admin/venues/BAR12')).status, 200);
  });

  await t.test('bad input is refused', async () => {
    assert.equal((await op('POST', '/admin/venues', { lat: 1, lng: 1 })).body.error, 'name_required');
    assert.equal((await op('POST', '/admin/venues', { name: 'x', lat: 100, lng: 1 })).body.error, 'invalid_location');
    assert.equal((await op('POST', '/admin/venues', { name: 'x', lat: 1, lng: 1, radiusM: 5 })).body.error, 'invalid_radius');
  });

  await t.test('without the key there is nothing', async () => {
    const res = await s.call('GET', '/admin/venues');
    assert.equal(res.status, 401);
  });

  await t.test('the page is served and needs no CDN', async () => {
    const res = await fetch(`${s.base}/admin`);
    assert.equal(res.status, 200);
    assert.match(res.headers.get('content-type'), /text\/html/);
    const html = await res.text();
    assert.ok(html.includes('qrcode'));
    assert.ok(!/src="https?:/.test(html));
  });

  await t.test('venue-ending reminders fire once per session', async () => {
    const a = await s.signUp('+972576000001');
    await s.goLiveAt(a, 'REMIND');
    const session = s.app.live.activeSession(a.id);
    session.expiresAt = Date.now() + 60_000;
    assert.equal(s.app.live.takeDueReminders(5 * 60_000).length, 1);
    assert.equal(s.app.live.takeDueReminders(5 * 60_000).length, 0);
  });
});
