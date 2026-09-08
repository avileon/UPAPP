import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { join } from 'node:path';

import { config } from '../src/config.js';
import { ChallengeStore, findPose, POSES } from '../src/domain/verification.js';
import { startTestServer } from './helpers.js';

/**
 * Photo verification.
 *
 * What is pinned here is mostly about what the feature does *not* do. It does
 * not prove a photo was taken now — nothing on the web can. It does not grant
 * a badge automatically. And it does not keep the photograph: the selfie is
 * deleted the moment a human decides, which is the difference between a
 * verification feature and a slowly accumulating library of face photographs
 * taken on demand.
 */

/** The smallest thing `PhotoStore` will accept as an image. */
const PNG = Buffer.from(
  '89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a4944415478da6360000002000100ffff03000006000557bfabd40000000049454e44ae426082',
  'hex',
);

test('photo verification', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  const previousToken = config.adminToken;
  config.adminToken = 'test-operator-key';
  t.after(() => {
    config.adminToken = previousToken;
  });

  const operator = (method, path, body) =>
    s.call(method, path, { body, headers: { 'x-admin-token': config.adminToken } });

  const challenge = (user) =>
    s.call('POST', '/me/verification/challenge', { token: user.token });

  const submit = (user, challengeId, bytes = PNG) =>
    s.uploadRaw(user, `/me/verification/selfie?challenge=${challengeId}`, bytes);

  await t.test('the pose comes from the server, not from the phone', async () => {
    // The whole security property: a person cannot prepare a photograph for a
    // pose they have not been told yet.
    const a = await s.signUp('+972550000001');
    const res = await challenge(a);

    assert.equal(res.status, 200);
    assert.ok(POSES.some((pose) => pose.key === res.body.pose));
    assert.equal(res.body.instructionHe, findPose(res.body.pose).he);
    assert.ok(res.body.challengeId.length > 0);
    assert.ok(new Date(res.body.expiresAt).getTime() > Date.now());
  });

  await t.test('a selfie without a live challenge is refused', async () => {
    const a = await s.signUp('+972550000002');
    const res = await submit(a, 'not-a-real-challenge');
    assert.equal(res.status, 400);
    assert.equal(res.body.error, 'challenge_expired');
  });

  await t.test('a challenge answers once', async () => {
    // A challenge that survived its own use could be answered again later, with
    // all the time in the world to find a photograph.
    const a = await s.signUp('+972550000003');
    const issued = await challenge(a);

    assert.equal((await submit(a, issued.body.challengeId)).status, 201);
    assert.equal((await submit(a, issued.body.challengeId)).status, 400);
  });

  await t.test('one person cannot answer another person’s challenge', async () => {
    const a = await s.signUp('+972550000004');
    const b = await s.signUp('+972550000005');
    const issued = await challenge(a);

    assert.equal((await submit(b, issued.body.challengeId)).status, 400);
  });

  await t.test('submitting again replaces the attempt rather than queueing it',
    async () => {
      // A reviewer must never be asked to judge a photo its own subject has
      // already given up on.
      const a = await s.signUp('+972550000006');
      for (let i = 0; i < 2; i++) {
        const issued = await challenge(a);
        assert.equal((await submit(a, issued.body.challengeId)).status, 201);
      }

      const queue = await operator('GET', '/admin/verifications');
      const mine = queue.body.pending.filter((row) => row.firstName === 'Test');
      assert.equal(
        mine.filter((row) => row.id).length >= 1,
        true,
        'at least one pending row',
      );
      assert.equal(s.store.pendingVerifications().filter((r) => r.user_id === a.id).length, 1);
    });

  await t.test('the badge is granted by a person, never by submitting', async () => {
    const a = await s.signUp('+972550000007');
    const issued = await challenge(a);
    await submit(a, issued.body.challengeId);

    const pending = await s.call('GET', '/me/verification', { token: a.token });
    assert.equal(pending.body.status, 'pending');
    assert.equal(s.store.isSelfieVerified(a.id), false);

    const row = s.store.pendingVerifications().find((r) => r.user_id === a.id);
    await operator('POST', `/admin/verifications/${row.id}/decide`, { approve: true });

    const after = await s.call('GET', '/me/verification', { token: a.token });
    assert.equal(after.body.status, 'approved');
    assert.equal(s.store.isSelfieVerified(a.id), true);
  });

  await t.test('the selfie is deleted the moment it is decided', async () => {
    // The point of the whole design. Only the verdict survives.
    const a = await s.signUp('+972550000008');
    const issued = await challenge(a);
    await submit(a, issued.body.challengeId);

    const row = s.store.pendingVerifications().find((r) => r.user_id === a.id);
    const path = join(s.selfieDir, row.storage_key);
    assert.ok(existsSync(path), 'the file exists while it waits for review');

    await operator('POST', `/admin/verifications/${row.id}/decide`, { approve: false });

    assert.ok(!existsSync(path), 'and is gone once somebody has looked at it');
    assert.equal(s.store.findVerification(row.id).storage_key, null);
  });

  await t.test('a rejection does not revoke a badge already earned', async () => {
    // The badge is a fact about the person. A later bad photograph is a bad
    // photograph, not evidence the first one was wrong.
    const a = await s.signUp('+972550000009');
    const first = await challenge(a);
    await submit(a, first.body.challengeId);
    const approvedRow = s.store.pendingVerifications().find((r) => r.user_id === a.id);
    await operator('POST', `/admin/verifications/${approvedRow.id}/decide`, {
      approve: true,
    });

    const second = await challenge(a);
    await submit(a, second.body.challengeId);
    const rejectedRow = s.store.pendingVerifications().find((r) => r.user_id === a.id);
    await operator('POST', `/admin/verifications/${rejectedRow.id}/decide`, {
      approve: false,
    });

    const status = await s.call('GET', '/me/verification', { token: a.token });
    assert.equal(status.body.status, 'approved');
  });

  await t.test('a verified person carries the flag into other people’s lists',
    async () => {
      const a = await s.signUp('+972550000010');
      const b = await s.signUp('+972550000011');
      const issued = await challenge(b);
      await submit(b, issued.body.challengeId);
      const row = s.store.pendingVerifications().find((r) => r.user_id === b.id);
      await operator('POST', `/admin/verifications/${row.id}/decide`, { approve: true });

      await s.goLiveAt(a, 'VERIF1', 'meet');
      await s.goLiveAt(b, 'VERIF1', 'meet');

      const person = (await s.nearby(a)).body.people[0];
      assert.equal(person.selfieVerified, true);
      // And it is a different claim from the peer-feedback badge, which nobody
      // has given them.
      assert.equal(person.photoVerified, false);
    });

  await t.test('the review queue is closed without the operator key', async () => {
    assert.equal((await s.call('GET', '/admin/verifications')).status, 401);
    assert.equal(
      (await s.call('GET', '/admin/verifications', {
        headers: { 'x-admin-token': 'wrong' },
      })).status,
      401,
    );
  });

  await t.test('a selfie is not reachable through the public media route',
    async () => {
      // The reason it is stored in a directory of its own. `GET /media/:key`
      // serves anything in the photo store to any signed-in caller.
      const a = await s.signUp('+972550000012');
      const issued = await challenge(a);
      await submit(a, issued.body.challengeId);
      const row = s.store.pendingVerifications().find((r) => r.user_id === a.id);

      const res = await s.call('GET', `/media/${row.storage_key}`, { token: a.token });
      assert.equal(res.status, 404);
    });

  await t.test('with no operator key configured there is no review queue at all',
    async () => {
      const saved = config.adminToken;
      config.adminToken = '';
      try {
        const res = await operator('GET', '/admin/verifications');
        assert.equal(res.status, 404);
      } finally {
        config.adminToken = saved;
      }
    });
});

test('the challenge store', async (t) => {
  await t.test('expires, and a expired challenge answers nothing', () => {
    let now = 1000;
    const store = new ChallengeStore({ now: () => now, ttlSeconds: 60 });
    const issued = store.issue('u1');

    now += 61_000;
    assert.equal(store.take('u1', issued.id), null);
  });

  await t.test('holds one challenge per person', () => {
    // Otherwise somebody could keep five open and answer whichever one they
    // happen to have a photograph for.
    const store = new ChallengeStore();
    const first = store.issue('u1');
    const second = store.issue('u1');

    assert.equal(store.take('u1', first.id), null);
    assert.equal(store.take('u1', second.id)?.id, second.id);
  });

  await t.test('reaches every pose', () => {
    // A pose that never comes up is a pose that is not part of the defence.
    const seen = new Set();
    const store = new ChallengeStore();
    for (let i = 0; i < 400; i++) {
      seen.add(store.issue(`u${i}`).pose);
    }
    assert.equal(seen.size, POSES.length);
  });
});
