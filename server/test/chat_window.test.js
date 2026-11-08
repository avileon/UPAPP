import test from 'node:test';
import assert from 'node:assert/strict';

import { config } from '../src/config.js';
import { HERE, startTestServer } from './helpers.js';

/**
 * November 2026: seven minutes from the first reply, then a choice — meet,
 * phone, or not a match — and while a match is open, the room is closed.
 */
test('chat, decision and the closed room', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());
  s.registerVenue('BAR1');
  const join = (user) =>
    s.call('POST', '/live/start', { token: user.token, body: { venue: 'BAR1', ...HERE } });

  let n = 0;
  const matchedPair = async () => {
    n += 1;
    const a = await s.signUp(`+97255000${String(n).padStart(4, '0')}`, { gender: 'male', interestedIn: 'women' });
    const b = await s.signUp(`+97255100${String(n).padStart(4, '0')}`, { gender: 'female', interestedIn: 'men' });
    await join(a);
    await join(b);
    await s.call('POST', `/likes/${b.id}`, { token: a.token });
    const matched = await s.call('POST', `/likes/${a.id}`, { token: b.token });
    return { a, b, matchId: matched.body.match.id };
  };
  const send = (user, matchId, body) =>
    s.call('POST', `/matches/${matchId}/messages`, { token: user.token, body: { body } });
  const decide = (user, matchId, choice) =>
    s.call('POST', `/matches/${matchId}/decision`, { token: user.token, body: { choice } });
  const dateOf = async (user, matchId) =>
    (await s.call('GET', '/matches', { token: user.token })).body.matches.find((m) => m.id === matchId).date;
  const age = (matchId, seconds) =>
    s.store.db
      .prepare(`UPDATE messages SET created_at = ? WHERE match_id = ?`)
      .run(new Date(Date.now() - seconds * 1000).toISOString(), matchId);

  await t.test('the clock waits for a reply', async () => {
    const { a, b, matchId } = await matchedPair();
    assert.equal((await send(a, matchId, 'hi')).status, 201);
    assert.equal((await dateOf(a, matchId)).phase, 'waiting');
    // An unanswered opener long ago did not start anything.
    age(matchId, 60 * 60);
    assert.equal((await send(b, matchId, 'hey')).status, 201);
    const d = await dateOf(a, matchId);
    assert.equal(d.phase, 'chatting');
    const left = Date.parse(d.chatEndsAt) - Date.now();
    assert.ok(left > (config.chatWindowSeconds - 5) * 1000, 'seven minutes from the reply');
  });

  await t.test('after seven minutes from the reply, sending is refused', async () => {
    const { a, b, matchId } = await matchedPair();
    await send(a, matchId, 'hi');
    await send(b, matchId, 'hey');
    age(matchId, config.chatWindowSeconds + 30);
    const late = await send(a, matchId, 'still here?');
    assert.equal(late.status, 403);
    assert.equal(late.body.error, 'chat_time_up');
    assert.equal((await dateOf(a, matchId)).phase, 'deciding');
  });

  await t.test('both phone: numbers are shared; meet + phone is meet', async () => {
    const { a, b, matchId } = await matchedPair();
    assert.equal((await decide(a, matchId, 'meet')).status, 400, 'not before a reply');
    await send(a, matchId, 'hi');
    await send(b, matchId, 'hey');
    await decide(a, matchId, 'phone');
    let d = await dateOf(b, matchId);
    assert.equal(d.theyChose, true);
    assert.equal(d.theirPhone, null);
    await decide(b, matchId, 'phone');
    d = await dateOf(b, matchId);
    assert.equal(d.phase, 'phone');
    assert.equal(d.theirPhone, a.phone ?? s.store.findUser(a.id).phone);

    const other = await matchedPair();
    await send(other.a, other.matchId, 'hi');
    await send(other.b, other.matchId, 'hey');
    await decide(other.a, other.matchId, 'meet');
    await decide(other.b, other.matchId, 'phone');
    const m = await dateOf(other.a, other.matchId);
    assert.equal(m.phase, 'meet');
    assert.equal(m.theirPhone, null);
    // An agreed date can talk freely again.
    assert.equal((await send(other.a, other.matchId, 'by the bar')).status, 201);
  });

  await t.test('a match closes the room; "not a match" opens it', async () => {
    const { a, b, matchId } = await matchedPair();
    const c = await s.signUp('+972559990001', { gender: 'female', interestedIn: 'men' });
    await join(c);

    const fromA = await s.nearby(a);
    assert.deepEqual(fromA.body.people.map((p) => p.id), [b.id]);
    assert.equal(fromA.body.inDate.matchId, matchId);
    const fromC = await s.nearby(c);
    assert.ok(!fromC.body.people.some((p) => p.id === a.id), 'a is out of the room');
    assert.equal((await s.call('POST', `/likes/${a.id}`, { token: c.token })).body.error, 'person_unavailable');
    assert.equal((await s.call('POST', `/likes/${c.id}`, { token: a.token })).body.error, 'in_a_date');

    assert.equal((await decide(b, matchId, 'no')).status, 200);
    const after = await s.nearby(a);
    assert.equal(after.body.inDate, null);
    assert.ok(after.body.people.some((p) => p.id === c.id), 'c is back');
    assert.ok(!after.body.people.some((p) => p.id === b.id), 'b is hidden for the visit');
    assert.equal((await send(a, matchId, 'hm')).status, 403);
  });

  await t.test('an unanswered match stops holding the room', async () => {
    const { a, matchId } = await matchedPair();
    s.store.db
      .prepare(`UPDATE matches SET matched_at = ? WHERE id = ?`)
      .run(new Date(Date.now() - (config.date.replyMinutes + 1) * 60_000).toISOString(), matchId);
    assert.equal((await s.nearby(a)).body.inDate, null);
  });

  await t.test('no face check, no UP', async () => {
    const x = await s.signUp('+972559990002', { verified: false });
    const y = await s.signUp('+972559990003');
    const res = await s.call('POST', `/likes/${y.id}`, { token: x.token });
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'verification_required');
  });
});
