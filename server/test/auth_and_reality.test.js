import test from 'node:test';
import assert from 'node:assert/strict';

import { startTestServer } from './helpers.js';
import { RealityBadge } from '../src/domain/rules.js';

test('auth', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  await t.test('the wrong code does not sign anyone in', async () => {
    const phone = '+972520000001';
    await s.call('POST', '/auth/request-otp', { body: { phone } });
    const res = await s.call('POST', '/auth/verify-otp', {
      body: { phone, code: '0000-wrong' },
    });
    assert.equal(res.status, 400);
    assert.equal(res.body.error, 'otp_incorrect');
  });

  await t.test('OTP requests are rate limited per number', async () => {
    const phone = '+972520000002';
    let limited = false;
    for (let i = 0; i < 8; i++) {
      const res = await s.call('POST', '/auth/request-otp', { body: { phone } });
      if (res.status === 429) limited = true;
    }
    assert.ok(limited, 'an attacker could bill unlimited SMS');
  });

  await t.test('a refresh token is single use', async () => {
    const a = await s.signUp('+972520000003');
    const first = await s.call('POST', '/auth/refresh', {
      body: { refreshToken: a.refreshToken },
    });
    assert.equal(first.status, 200);
    const replay = await s.call('POST', '/auth/refresh', {
      body: { refreshToken: a.refreshToken },
    });
    assert.equal(replay.status, 401);
  });

  await t.test('an under-18 profile is refused by the server clock', async () => {
    const phone = '+972520000004';
    const requested = await s.call('POST', '/auth/request-otp', { body: { phone } });
    const verified = await s.call('POST', '/auth/verify-otp', {
      body: { phone, code: requested.body.devCode },
    });
    const res = await s.call('PUT', '/me/profile', {
      token: verified.body.accessToken,
      body: {
        firstName: 'Too Young',
        birthDate: new Date(Date.now() - 15 * 365 * 86400_000).toISOString().slice(0, 10),
        gender: 'male',
        interestedIn: 'everyone',
      },
    });
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'under_minimum_age');
  });

  await t.test('going live needs a complete profile', async () => {
    const phone = '+972520000005';
    const requested = await s.call('POST', '/auth/request-otp', { body: { phone } });
    const verified = await s.call('POST', '/auth/verify-otp', {
      body: { phone, code: requested.body.devCode },
    });
    const res = await s.call('POST', '/live/start', {
      token: verified.body.accessToken,
      body: { durationSeconds: 600 },
    });
    assert.equal(res.status, 403);
  });
});

test('reality check', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  const matchedPair = async (n) => {
    const a = await s.signUp(`+97253000${String(n).padStart(4, '0')}`);
    const b = await s.signUp(`+97253100${String(n).padStart(4, '0')}`);
    await s.call('POST', `/likes/${b.id}`, { token: a.token });
    const matched = await s.call('POST', `/likes/${a.id}`, { token: b.token });
    return { a, b, matchId: matched.body.match.id };
  };

  await t.test('is refused before the match becomes a conversation', async () => {
    const { a, matchId } = await matchedPair(1);
    const res = await s.call('POST', `/matches/${matchId}/reality-feedback`, {
      token: a.token,
      body: { answer: 'yes' },
    });
    assert.equal(res.status, 400);
    assert.equal(res.body.error, 'conversation_too_short');
  });

  await t.test('accepts one answer per match and no more', async () => {
    const { a, b, matchId } = await matchedPair(2);
    for (let i = 0; i < 4; i++) {
      await s.call('POST', `/matches/${matchId}/messages`, {
        token: i % 2 === 0 ? a.token : b.token,
        body: { body: `message ${i}` },
      });
    }

    const first = await s.call('POST', `/matches/${matchId}/reality-feedback`, {
      token: a.token,
      body: { answer: 'yes' },
    });
    assert.equal(first.status, 200);

    const second = await s.call('POST', `/matches/${matchId}/reality-feedback`, {
      token: a.token,
      body: { answer: 'no' },
    });
    assert.equal(second.status, 400);
    assert.equal(second.body.error, 'already_answered');
  });

  await t.test('a stranger cannot answer about a pair they are not in', async () => {
    const { matchId } = await matchedPair(3);
    const stranger = await s.signUp('+972539999999');
    const res = await s.call('POST', `/matches/${matchId}/reality-feedback`, {
      token: stranger.token,
      body: { answer: 'no' },
    });
    assert.equal(res.status, 403);
  });

  await t.test('the badge needs a minimum and a clear majority', () => {
    assert.equal(RealityBadge.qualifies(2, 2), false, 'two answers is noise');
    assert.equal(RealityBadge.qualifies(5, 4), true);
    assert.equal(RealityBadge.qualifies(10, 9), true, 'one no must not strip a badge');
    assert.equal(RealityBadge.qualifies(10, 6), false, 'a weak majority is not a badge');
  });

  await t.test('the vote tally never reaches a client', async () => {
    const { a, b, matchId } = await matchedPair(4);
    for (let i = 0; i < 4; i++) {
      await s.call('POST', `/matches/${matchId}/messages`, {
        token: i % 2 === 0 ? a.token : b.token,
        body: { body: `m${i}` },
      });
    }
    await s.call('POST', `/matches/${matchId}/reality-feedback`, {
      token: a.token,
      body: { answer: 'yes' },
    });

    const matches = await s.call('GET', '/matches', { token: b.token });
    const serialised = JSON.stringify(matches.body);
    assert.ok(!/total|positive|votes|count.*yes/i.test(serialised));
    assert.equal(typeof matches.body.matches[0].person.photoVerified, 'boolean');
  });
});
