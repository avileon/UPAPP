import test from 'node:test';
import assert from 'node:assert/strict';

import { normaliseVenue } from '../src/domain/presence.js';
import { startTestServer } from './helpers.js';

/**
 * Venue presence — the fallback for the case the product actually has to
 * survive: a crowded room, where BLE under-discovers badly.
 *
 * Two people type the same short code and the server puts them in each other's
 * list. The reason this is a feature and not a shortcut around the radio is
 * that it earns its place independently: BLE will never be reliable in a bar,
 * and a venue key is coarser than the radio rather than more precise — it is a
 * label two people agreed on, it holds no coordinates, and it dies with the
 * session.
 *
 * The rule these tests exist to pin down: the venue is a *discovery* channel
 * and nothing else. Every permission decision is the same one BLE gets.
 */
test('venue presence', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  await t.test('two people on the same code see each other with no BLE at all', async () => {
    const a = await s.signUp('+972520000001', { firstName: 'Avi' });
    const b = await s.signUp('+972520000002', { firstName: 'Dana' });

    await s.goLiveAt(a, 'ROOM01');
    await s.goLiveAt(b, 'ROOM01');

    const seenByA = await s.nearby(a);
    const seenByB = await s.nearby(b);

    assert.equal(seenByA.body.people.length, 1);
    assert.equal(seenByA.body.people[0].firstName, 'Dana');
    assert.equal(seenByB.body.people.length, 1);
    assert.equal(seenByB.body.people[0].firstName, 'Avi');
  });

  await t.test('a different code is a different room', async () => {
    const a = await s.signUp('+972520000003');
    const b = await s.signUp('+972520000004');

    await s.goLiveAt(a, 'ROOM02A');
    await s.goLiveAt(b, 'ROOM02B');

    assert.deepEqual((await s.nearby(a)).body.people, []);
    assert.deepEqual((await s.nearby(b)).body.people, []);
  });

  await t.test('no code means no venue peers — not "everyone"', async () => {
    // The failure mode worth guarding: two null venues comparing equal would
    // put every live user on the planet in one room.
    const a = await s.signUp('+972520000005');
    const b = await s.signUp('+972520000006');

    await s.call('POST', '/live/start', { token: a.token, body: { durationSeconds: 600 } });
    await s.call('POST', '/live/start', { token: b.token, body: { durationSeconds: 600 } });

    assert.deepEqual((await s.nearby(a)).body.people, []);
  });

  await t.test('codes are normalised, so people who type it differently still meet', async () => {
    const a = await s.signUp('+972520000007');
    const b = await s.signUp('+972520000008');

    const liveA = await s.goLiveAt(a, ' room-04 ');
    const liveB = await s.goLiveAt(b, 'Room 04');

    assert.equal(liveA.body.venue, 'ROOM04');
    assert.equal(liveB.body.venue, 'ROOM04');
    assert.equal((await s.nearby(a)).body.people.length, 1);
  });

  await t.test('a code too short to be meant is no code', async () => {
    const a = await s.signUp('+972520000009');
    const b = await s.signUp('+972520000010');

    const liveA = await s.goLiveAt(a, 'x');
    await s.goLiveAt(b, 'x');

    assert.equal(liveA.body.venue, null);
    assert.deepEqual((await s.nearby(a)).body.people, []);
  });

  await t.test('leaving the venue means going live again without it', async () => {
    const a = await s.signUp('+972520000011');
    const b = await s.signUp('+972520000012');

    await s.goLiveAt(a, 'ROOM06');
    await s.goLiveAt(b, 'ROOM06');
    assert.equal((await s.nearby(a)).body.people.length, 1);

    await s.call('POST', '/live/start', { token: b.token, body: { durationSeconds: 600 } });
    assert.deepEqual((await s.nearby(a)).body.people, []);
  });

  await t.test('stopping live takes you out of the room', async () => {
    const a = await s.signUp('+972520000013');
    const b = await s.signUp('+972520000014');

    await s.goLiveAt(a, 'ROOM07');
    await s.goLiveAt(b, 'ROOM07');
    await s.call('POST', '/live/stop', { token: b.token });

    assert.deepEqual((await s.nearby(a)).body.people, []);
  });

  await t.test('you still have to be live yourself', async () => {
    const a = await s.signUp('+972520000015');
    const b = await s.signUp('+972520000016');

    await s.goLiveAt(b, 'ROOM08');
    const res = await s.nearby(a);

    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'not_live');
  });

  await t.test('a block hides a venue peer exactly like a BLE one', async () => {
    const a = await s.signUp('+972520000017');
    const b = await s.signUp('+972520000018');

    await s.call('POST', `/users/${b.id}/block`, { token: a.token });
    await s.goLiveAt(a, 'ROOM09');
    await s.goLiveAt(b, 'ROOM09');

    assert.deepEqual((await s.nearby(a)).body.people, []);
    assert.deepEqual((await s.nearby(b)).body.people, []);
  });

  await t.test('preferences must still agree in both directions', async () => {
    const a = await s.signUp('+972520000019', { gender: 'male', interestedIn: 'women' });
    const b = await s.signUp('+972520000020', { gender: 'male', interestedIn: 'women' });

    await s.goLiveAt(a, 'ROOM10');
    await s.goLiveAt(b, 'ROOM10');

    assert.deepEqual((await s.nearby(a)).body.people, []);
  });

  await t.test('a venue peer is serialised exactly like anyone else', async () => {
    // No `via`, no `venue`, no provenance of any kind. The app cannot render a
    // "found by radio" badge because it never receives the fact.
    const a = await s.signUp('+972520000021');
    const b = await s.signUp('+972520000022');

    await s.goLiveAt(a, 'ROOM11');
    await s.goLiveAt(b, 'ROOM11');

    const person = (await s.nearby(a)).body.people[0];
    assert.deepEqual(
      Object.keys(person).sort(),
      ['age', 'bio', 'firstName', 'id', 'photoVerified', 'photos'],
    );
  });

  await t.test('BLE and the venue produce one person, not two', async () => {
    const a = await s.signUp('+972520000023');
    const b = await s.signUp('+972520000024');

    await s.goLiveAt(a, 'ROOM12');
    const liveB = await s.goLiveAt(b, 'ROOM12');

    const res = await s.nearby(a, liveB.body.tokens.map((token) => token.token));
    assert.equal(res.body.people.length, 1);
    assert.equal(res.body.liveNearbyCount, 1);
  });

  await t.test('the room and its occupancy come back, so silence can be explained', async () => {
    // The one thing a person staring at an empty list cannot work out for
    // themselves: whether they are in the room at all, and whether anyone else
    // is. Two people whose preferences rule each other out must still both see
    // roomPeers: 1 — otherwise "nobody here" and "we cannot see each other"
    // look identical on the phone.
    const a = await s.signUp('+972520000025', { gender: 'male', interestedIn: 'women' });
    const b = await s.signUp('+972520000026', { gender: 'male', interestedIn: 'women' });

    await s.goLiveAt(a, 'ROOM13');
    await s.goLiveAt(b, 'ROOM13');

    const res = await s.nearby(a);
    assert.equal(res.body.room, 'ROOM13');
    assert.equal(res.body.roomPeers, 1);
    assert.deepEqual(res.body.people, []);
  });

  await t.test('no room is null, and nobody else is zero', async () => {
    const a = await s.signUp('+972520000027');
    await s.call('POST', '/live/start', { token: a.token, body: { durationSeconds: 600 } });

    const noRoom = await s.nearby(a);
    assert.equal(noRoom.body.room, null);
    assert.equal(noRoom.body.roomPeers, 0);

    await s.goLiveAt(a, 'ROOM14');
    const alone = await s.nearby(a);
    assert.equal(alone.body.room, 'ROOM14');
    assert.equal(alone.body.roomPeers, 0);
  });
});

test('venue keys normalise the way two strangers would need them to', async (t) => {
  await t.test('the same room, however it is typed', () => {
    for (const raw of ['BAR12', 'bar12', ' bar 12 ', 'bar-12', 'Bar_12', 'bar.12']) {
      assert.equal(normaliseVenue(raw), 'BAR12', `${raw} should reach BAR12`);
    }
  });

  await t.test('nothing usable is null, never a shared empty room', () => {
    for (const raw of ['', '  ', '--', 'ab', null, undefined, 42, {}, 'שלום']) {
      assert.equal(normaliseVenue(raw), null);
    }
  });

  await t.test('long codes are rejected rather than truncated into collisions', () => {
    assert.equal(normaliseVenue('THIRTEENCHARS'), null);
    assert.equal(normaliseVenue('TWELVECHARSX'), 'TWELVECHARSX');
  });
});
