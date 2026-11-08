import test from 'node:test';
import assert from 'node:assert/strict';

import { nightKey } from '../src/domain/night.js';
import { HERE, startTestServer } from './helpers.js';

/** Four UPs per place per night; answering one is free; area mode is open. */

test('night key rolls at 06:00 local, not at midnight', () => {
  // 2026-10-28 22:00 and 2026-10-29 03:00 Israel time (UTC+2) — same night.
  const evening = Date.UTC(2026, 9, 28, 20, 0);
  const lateNight = Date.UTC(2026, 9, 29, 1, 0);
  const nextMorning = Date.UTC(2026, 9, 29, 5, 0); // 07:00 local
  assert.equal(nightKey(evening), '2026-10-28');
  assert.equal(nightKey(lateNight), '2026-10-28');
  assert.equal(nightKey(nextMorning), '2026-10-29');
});

test('four UPs per place per night', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());
  s.registerVenue('PUB1');
  s.registerVenue('PUB2');

  const join = (user, venue = 'PUB1') =>
    s.call('POST', '/live/start', { token: user.token, body: { venue, ...HERE } });
  const up = (from, to) => s.call('POST', `/likes/${to.id}`, { token: from.token });

  const me = await s.signUp('+972572000001');
  const others = [];
  for (let i = 0; i < 6; i++) others.push(await s.signUp(`+97257200001${i}`));
  await join(me);
  for (const o of others) await join(o);

  await t.test('the room says how many are left', async () => {
    const res = await s.nearby(me);
    assert.deepEqual(res.body.upQuota, { venue: 'PUB1', limit: 4, used: 0, remaining: 4 });
  });

  await t.test('four go through, the fifth is refused', async () => {
    for (let i = 0; i < 4; i++) {
      const res = await up(me, others[i]);
      assert.equal(res.status, 200);
      assert.equal(res.body.upQuota.remaining, 3 - i);
    }
    const fifth = await up(me, others[4]);
    assert.equal(fifth.status, 429);
    assert.equal(fifth.body.error, 'venue_up_limit');
  });

  await t.test('pressing again on someone already sent to costs nothing', async () => {
    const res = await up(me, others[0]);
    assert.equal(res.status, 200);
    assert.equal(res.body.outcome, 'duplicate');
  });

  await t.test('answering an UP you received is free', async () => {
    await up(others[5], me);
    const res = await up(me, others[5]);
    assert.equal(res.status, 200);
    assert.equal(res.body.outcome, 'matched');
    assert.equal(res.body.upQuota.remaining, 0);
    // A match closes the room for both until one of them says "not a match".
    const blocked = await up(me, others[4]);
    assert.equal(blocked.status, 403);
    assert.equal(blocked.body.error, 'in_a_date');
    const no = await s.call('POST', `/matches/${res.body.match.id}/decision`, {
      token: me.token,
      body: { choice: 'no' },
    });
    assert.equal(no.status, 200);
  });

  await t.test('taking one back does not hand the slot back', async () => {
    await s.call('DELETE', `/likes/${others[1].id}`, { token: me.token });
    const res = await up(me, others[4]);
    assert.equal(res.status, 429);
  });

  await t.test('scanning again at the same place does not reset it', async () => {
    await join(me);
    assert.equal((await s.nearby(me)).body.upQuota.remaining, 0);
  });

  await t.test('another place, four new ones', async () => {
    await join(me, 'PUB2');
    assert.equal((await s.nearby(me)).body.upQuota.remaining, 4);
    const res = await up(me, others[4]);
    assert.equal(res.status, 200);
  });
});

test('around me (no QR) has no limit', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());
  const area = (user) =>
    s.call('POST', '/live/start', { token: user.token, body: { durationSeconds: 1800, ...HERE } });

  const me = await s.signUp('+972573000001');
  await area(me);
  assert.equal((await s.nearby(me)).body.upQuota, null);
  for (let i = 0; i < 6; i++) {
    const o = await s.signUp(`+97257300001${i}`);
    const res = await s.call('POST', `/likes/${o.id}`, { token: me.token });
    assert.equal(res.status, 200);
  }
});
