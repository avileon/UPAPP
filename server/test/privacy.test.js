import test from 'node:test';
import assert from 'node:assert/strict';

import { startTestServer } from './helpers.js';

/**
 * The rules that make UP defensible. Every one of these is a thing the server
 * must refuse to send, not a thing the client must remember to hide.
 */
test('privacy and safety', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  await t.test('a resolved profile carries no location, phone or vote count', async () => {
    const a = await s.signUp('+972510000001', { gender: 'male', interestedIn: 'everyone' });
    const b = await s.signUp('+972510000002', { gender: 'female', interestedIn: 'everyone' });
    const { aSeesB } = await s.goLiveTogether(a, b);

    const res = await s.call('POST', '/nearby/resolve', {
      token: a.token,
      body: { tokens: aSeesB },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.people.length, 1);

    // The list is exhaustive on purpose: anything new that shows up here is a
    // decision somebody has to make deliberately. `sentYouUp` and `youSentUp`
    // are facts about this pair and nobody else's business — and nobody else
    // receives them.
    const person = res.body.people[0];
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
    const serialised = JSON.stringify(res.body);
    assert.ok(!serialised.includes('+9725100'), 'a phone number leaked');
    assert.ok(!/distance|metres|meters|rssi|lat|lng/i.test(serialised));
  });

  await t.test('a BLE token stops resolving once its session ends', async () => {
    const a = await s.signUp('+972510000003');
    const b = await s.signUp('+972510000004');
    const { aSeesB } = await s.goLiveTogether(a, b);

    await s.call('POST', '/live/stop', { token: b.token });

    const res = await s.call('POST', '/nearby/resolve', {
      token: a.token,
      body: { tokens: aSeesB },
    });
    assert.deepEqual(res.body.people, []);
  });

  await t.test('an unknown token resolves to nobody rather than an error', async () => {
    const a = await s.signUp('+972510000005');
    await s.call('POST', '/live/start', { token: a.token, body: { durationSeconds: 600 } });

    const res = await s.call('POST', '/nearby/resolve', {
      token: a.token,
      body: { tokens: ['not-a-real-token', 'another-fake'] },
    });
    assert.equal(res.status, 200);
    assert.deepEqual(res.body.people, []);
  });

  await t.test('you must be live yourself to resolve anyone', async () => {
    const a = await s.signUp('+972510000006');
    const b = await s.signUp('+972510000007');
    const { aSeesB } = await s.goLiveTogether(a, b);
    await s.call('POST', '/live/stop', { token: a.token });

    const res = await s.call('POST', '/nearby/resolve', {
      token: a.token,
      body: { tokens: aSeesB },
    });
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'not_live');
  });

  await t.test('preferences must agree in both directions', async () => {
    const a = await s.signUp('+972510000008', { gender: 'male', interestedIn: 'women' });
    const b = await s.signUp('+972510000009', { gender: 'male', interestedIn: 'women' });
    const { aSeesB } = await s.goLiveTogether(a, b);

    const res = await s.call('POST', '/nearby/resolve', {
      token: a.token,
      body: { tokens: aSeesB },
    });
    assert.deepEqual(res.body.people, []);
  });

  await t.test('blocking hides both ways and closes the match', async () => {
    const a = await s.signUp('+972510000010');
    const b = await s.signUp('+972510000011');
    await s.call('POST', `/likes/${b.id}`, { token: a.token });
    await s.call('POST', `/likes/${a.id}`, { token: b.token });

    await s.call('POST', `/users/${b.id}/block`, { token: a.token });

    assert.deepEqual((await s.call('GET', '/matches', { token: a.token })).body.matches, []);
    assert.deepEqual((await s.call('GET', '/matches', { token: b.token })).body.matches, []);

    const { aSeesB } = await s.goLiveTogether(a, b);
    const nearby = await s.call('POST', '/nearby/resolve', {
      token: a.token,
      body: { tokens: aSeesB },
    });
    assert.deepEqual(nearby.body.people, []);

    const like = await s.call('POST', `/likes/${b.id}`, { token: a.token });
    assert.equal(like.status, 403);
  });

  await t.test('one user cannot read another pair\'s messages', async () => {
    const a = await s.signUp('+972510000012');
    const b = await s.signUp('+972510000013');
    const intruder = await s.signUp('+972510000014');

    await s.call('POST', `/likes/${b.id}`, { token: a.token });
    const matched = await s.call('POST', `/likes/${a.id}`, { token: b.token });
    const matchId = matched.body.match.id;

    await s.call('POST', `/matches/${matchId}/messages`, {
      token: a.token,
      body: { body: 'private' },
    });

    const res = await s.call('GET', `/matches/${matchId}/messages`, {
      token: intruder.token,
    });
    assert.equal(res.status, 403);
  });

  await t.test('requests without a valid token are refused', async () => {
    assert.equal((await s.call('GET', '/me/profile')).status, 401);
    assert.equal(
      (await s.call('GET', '/me/profile', { token: 'forged.token.value' })).status,
      401,
    );
  });
});
