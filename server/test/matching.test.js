import test from 'node:test';
import assert from 'node:assert/strict';

import { startTestServer } from './helpers.js';

/**
 * The matching contract. These are the same rules the Flutter client asserts
 * in `test/match_logic_test.dart`; if the two ever disagree, this file is the
 * one that is right.
 */
test('matching', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  await t.test('a one-way UP creates no match and reveals nothing', async () => {
    const a = await s.signUp('+972500000001');
    const b = await s.signUp('+972500000002');

    const sent = await s.call('POST', `/likes/${b.id}`, { token: a.token });
    assert.equal(sent.status, 200);
    assert.equal(sent.body.outcome, 'recorded');
    assert.equal(sent.body.match, null);

    // The receiving side must not be able to learn that it happened.
    const bMatches = await s.call('GET', '/matches', { token: b.token });
    assert.deepEqual(bMatches.body.matches, []);
  });

  await t.test('a mutual UP creates exactly one match', async () => {
    const a = await s.signUp('+972500000003');
    const b = await s.signUp('+972500000004');

    await s.call('POST', `/likes/${b.id}`, { token: a.token });
    const second = await s.call('POST', `/likes/${a.id}`, { token: b.token });

    assert.equal(second.body.outcome, 'matched');
    assert.ok(second.body.match?.id);

    const aMatches = await s.call('GET', '/matches', { token: a.token });
    const bMatches = await s.call('GET', '/matches', { token: b.token });
    assert.equal(aMatches.body.matches.length, 1);
    assert.equal(bMatches.body.matches.length, 1);
    assert.equal(aMatches.body.matches[0].id, bMatches.body.matches[0].id);
  });

  await t.test('pressing UP twice never produces a second match', async () => {
    const a = await s.signUp('+972500000005');
    const b = await s.signUp('+972500000006');

    await s.call('POST', `/likes/${b.id}`, { token: a.token });
    await s.call('POST', `/likes/${a.id}`, { token: b.token });
    const again = await s.call('POST', `/likes/${b.id}`, { token: a.token });

    assert.equal(again.body.outcome, 'duplicate');
    const matches = await s.call('GET', '/matches', { token: a.token });
    assert.equal(matches.body.matches.length, 1);
  });

  await t.test('simultaneous UPs still yield one match', async () => {
    const a = await s.signUp('+972500000007');
    const b = await s.signUp('+972500000008');

    const [first, second] = await Promise.all([
      s.call('POST', `/likes/${b.id}`, { token: a.token }),
      s.call('POST', `/likes/${a.id}`, { token: b.token }),
    ]);

    const outcomes = [first.body.outcome, second.body.outcome].sort();
    assert.deepEqual(outcomes, ['matched', 'recorded']);

    const matches = await s.call('GET', '/matches', { token: a.token });
    assert.equal(matches.body.matches.length, 1);
  });

  await t.test('UPs are rate limited', async () => {
    const a = await s.signUp('+972500000009');
    let limited = null;
    for (let i = 0; i < 70 && !limited; i++) {
      const victim = await s.signUp(`+9725001${String(i).padStart(5, '0')}`);
      const res = await s.call('POST', `/likes/${victim.id}`, { token: a.token });
      if (res.status === 429) limited = res.body.error;
    }
    assert.equal(limited, 'like_rate_limited');
  });

  await t.test('you cannot UP yourself', async () => {
    const a = await s.signUp('+972500000010');
    const res = await s.call('POST', `/likes/${a.id}`, { token: a.token });
    assert.equal(res.status, 400);
    assert.equal(res.body.error, 'cannot_like_self');
  });
});
