import test from 'node:test';
import assert from 'node:assert/strict';

import { startTestServer } from './helpers.js';

test('a chat lasts two minutes, then it is time to meet', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  const matchedPair = async (n) => {
    const a = await s.signUp(`+97255000${String(n).padStart(4, '0')}`);
    const b = await s.signUp(`+97255100${String(n).padStart(4, '0')}`);
    await s.call('POST', `/likes/${b.id}`, { token: a.token });
    const matched = await s.call('POST', `/likes/${a.id}`, { token: b.token });
    return { a, b, matchId: matched.body.match.id };
  };

  const send = (user, matchId, body) =>
    s.call('POST', `/matches/${matchId}/messages`, { token: user.token, body: { body } });

  await t.test('inside the window both sides can write', async () => {
    const { a, b, matchId } = await matchedPair(1);
    assert.equal((await send(a, matchId, 'hi')).status, 201);
    assert.equal((await send(b, matchId, 'hey')).status, 201);
  });

  await t.test('after two minutes from the first message, sending is refused', async () => {
    const { a, b, matchId } = await matchedPair(2);
    assert.equal((await send(a, matchId, 'hi')).status, 201);
    s.store.db
      .prepare(`UPDATE messages SET created_at = ? WHERE match_id = ?`)
      .run(new Date(Date.now() - 130_000).toISOString(), matchId);

    const late = await send(b, matchId, 'still here?');
    assert.equal(late.status, 403);
    assert.equal(late.body.error, 'chat_time_up');
    // What was said stays readable.
    const history = await s.call('GET', `/matches/${matchId}/messages`, { token: b.token });
    assert.equal(history.body.messages.length, 1);
  });
});
