import test from 'node:test';
import assert from 'node:assert/strict';

import {
  DEFAULT_INTENT,
  INTENTS,
  intentsMeet,
  normaliseIntent,
  normaliseNote,
  NOTE_MAX_LENGTH,
  preferencesGateDiscovery,
} from '../src/domain/intent.js';
import { startTestServer } from './helpers.js';

/**
 * Why someone is Live, and what it changes.
 *
 * The rule these tests exist to hold down is the one that decides what kind of
 * product this is: the gender-preference filter runs for dating and for
 * nothing else. It used to run on every discovery, which meant a room of eight
 * showed you two, selected by a rule that only makes sense if the answer to
 * "why are you here" is romance. That is why the app read as a dating app
 * whatever anyone used it for.
 */
test('intent shapes who you meet', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  const live = (user, { venue, intent, note, seconds = 600 } = {}) =>
    s.call('POST', '/live/start', {
      token: user.token,
      body: { durationSeconds: seconds, venue, intent, note },
    });

  await t.test('two men in a room see each other when they came to meet people',
    async () => {
      // The exact case that made the app look broken: same room, same moment,
      // and an empty list because both had said they were interested in women.
      const a = await s.signUp('+972540000001', {
        firstName: 'Avi',
        gender: 'male',
        interestedIn: 'women',
      });
      const b = await s.signUp('+972540000002', {
        firstName: 'Dan',
        gender: 'male',
        interestedIn: 'women',
      });

      await live(a, { venue: 'MEET01', intent: 'meet' });
      await live(b, { venue: 'MEET01', intent: 'meet' });

      const seen = await s.nearby(a);
      assert.equal(seen.body.people.length, 1);
      assert.equal(seen.body.people[0].firstName, 'Dan');
    });

  await t.test('the same two, both there to date, do not', async () => {
    const a = await s.signUp('+972540000003', {
      gender: 'male',
      interestedIn: 'women',
    });
    const b = await s.signUp('+972540000004', {
      gender: 'male',
      interestedIn: 'women',
    });

    await live(a, { venue: 'DATE01', intent: 'date' });
    await live(b, { venue: 'DATE01', intent: 'date' });

    assert.deepEqual((await s.nearby(a)).body.people, []);
    // And the room still says they are both in it, so "nobody here" and
    // "we cannot see each other" stay distinguishable.
    assert.equal((await s.nearby(a)).body.roomPeers, 1);
  });

  await t.test('different intents in one room are different rooms', async () => {
    const a = await s.signUp('+972540000005');
    const b = await s.signUp('+972540000006');

    await live(a, { venue: 'MIX01', intent: 'work' });
    await live(b, { venue: 'MIX01', intent: 'doing' });

    assert.deepEqual((await s.nearby(a)).body.people, []);
    assert.equal((await s.nearby(a)).body.roomPeers, 0);
  });

  await t.test('a blocked person stays hidden whatever the intent', async () => {
    const a = await s.signUp('+972540000007');
    const b = await s.signUp('+972540000008');
    await s.call('POST', `/users/${b.id}/block`, { token: a.token });

    await live(a, { venue: 'BLOCK1', intent: 'meet' });
    await live(b, { venue: 'BLOCK1', intent: 'meet' });

    assert.deepEqual((await s.nearby(a)).body.people, []);
    assert.deepEqual((await s.nearby(b)).body.people, []);
  });

  await t.test('an unknown intent becomes the safe one rather than an error',
    async () => {
      // A phone running last week's build must not fail to go Live.
      const a = await s.signUp('+972540000009');
      const res = await live(a, { venue: 'FALL01', intent: 'nonsense' });
      assert.equal(res.status, 200);
      assert.equal(res.body.intent, DEFAULT_INTENT);
    });

  await t.test('the note travels with the person and dies with the session',
    async () => {
      const a = await s.signUp('+972540000010');
      const b = await s.signUp('+972540000011', { firstName: 'Noa' });

      await live(a, { venue: 'NOTE01', intent: 'meet' });
      await live(b, {
        venue: 'NOTE01',
        intent: 'meet',
        note: '  יושב עם קפה\nליד החלון  ',
      });

      const person = (await s.nearby(a)).body.people[0];
      assert.equal(person.note, 'יושב עם קפה ליד החלון');

      // Going Live again without one clears it. A note that outlived its
      // session would be a bio nobody meant to write.
      await live(b, { venue: 'NOTE01', intent: 'meet' });
      assert.equal((await s.nearby(a)).body.people[0].note, '');
    });

  await t.test('rooms can be found without being told the code', async () => {
    const [a, b, c] = await Promise.all([
      s.signUp('+972540000012'),
      s.signUp('+972540000013'),
      s.signUp('+972540000014'),
    ]);
    await live(a, { venue: 'BUSY01', intent: 'meet' });
    await live(b, { venue: 'BUSY01', intent: 'meet' });
    await live(c, { venue: 'QUIET1', intent: 'meet' });

    const res = await s.call('GET', '/rooms?intent=meet', { token: c.token });
    assert.equal(res.status, 200);
    const codes = res.body.rooms.map((room) => room.code);
    assert.ok(codes.includes('BUSY01'));
    // A room of one is a person. Listing it would turn a private label into a
    // way to find them.
    assert.ok(!codes.includes('QUIET1'));
    assert.equal(res.body.rooms.find((room) => room.code === 'BUSY01').people, 2);
  });

  await t.test('the room list is per intent', async () => {
    const [a, b, c] = await Promise.all([
      s.signUp('+972540000015'),
      s.signUp('+972540000016'),
      s.signUp('+972540000017'),
    ]);
    await live(a, { venue: 'WORK01', intent: 'work' });
    await live(b, { venue: 'WORK01', intent: 'work' });

    const codesFor = async (intent) =>
      (await s.call(`GET`, `/rooms?intent=${intent}`, { token: c.token })).body.rooms
        .map((room) => room.code);

    assert.ok(!(await codesFor('date')).includes('WORK01'));
    assert.ok((await codesFor('work')).includes('WORK01'));
  });

  await t.test('finding rooms requires signing in', async () => {
    assert.equal((await s.call('GET', '/rooms')).status, 401);
  });
});

test('intent is a small closed set with sane defaults', async (t) => {
  await t.test('four of them, and dating is the only one that filters', () => {
    assert.deepEqual(INTENTS, ['meet', 'date', 'work', 'doing']);
    assert.equal(preferencesGateDiscovery('date'), true);
    for (const intent of ['meet', 'work', 'doing']) {
      assert.equal(preferencesGateDiscovery(intent), false, intent);
    }
  });

  await t.test('anything unrecognised falls to meeting people', () => {
    for (const raw of [null, undefined, '', 'DATE', 'romance', 42, {}]) {
      assert.equal(normaliseIntent(raw), 'meet');
    }
    assert.equal(intentsMeet('meet', undefined), true);
    assert.equal(intentsMeet('date', 'meet'), false);
  });

  await t.test('a note is one short line of whatever they typed', () => {
    assert.equal(normaliseNote('  two   spaces  '), 'two spaces');
    assert.equal(normaliseNote('a\nb\tc'), 'a b c');
    // Punctuation is theirs to keep; only the invisible characters go.
    assert.equal(normaliseNote('table 4 — by the window'), 'table 4 — by the window');
    assert.equal(normaliseNote('x'.repeat(200)).length, NOTE_MAX_LENGTH);
    assert.equal(normaliseNote(null), '');
  });
});
