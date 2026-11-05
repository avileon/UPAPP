import test from 'node:test';
import assert from 'node:assert/strict';

import { config } from '../src/config.js';
import { HERE, startTestServer } from './helpers.js';

/**
 * New accounts get 24 hours to use everything before their verification has
 * to be approved — nobody waits on a human to start.
 */

const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);

test('new-account grace window', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  const area = (user) =>
    s.call('POST', '/live/start', { token: user.token, body: { durationSeconds: 1800, ...HERE } });
  const backdate = (user, hours) =>
    s.store.db
      .prepare(`UPDATE users SET created_at = ? WHERE id = ?`)
      .run(new Date(Date.now() - hours * 3600_000).toISOString(), user.id);

  const viewer = await s.signUp('+972574000001');
  await area(viewer);

  await t.test('fresh and unverified: in, with a deadline', async () => {
    const a = await s.signUp('+972574000002', { verified: false, fresh: true });
    const res = await area(a);
    assert.equal(res.status, 200);
    const me = await s.call('GET', '/me/profile', { token: a.token });
    const hours = (Date.parse(me.body.verificationGraceEndsAt) - Date.now()) / 3600_000;
    assert.ok(hours > 23.9 && hours <= 24, `got ${hours}`);
    const v = await s.call('GET', '/me/verification', { token: a.token });
    assert.equal(v.body.graceEndsAt, me.body.verificationGraceEndsAt);
  });

  await t.test('others see the pending tag, and photos waiting for review', async () => {
    const a = await s.signUp('+972574000003', { verified: false, fresh: true });
    const waiting = (await s.uploadPhoto(a, PNG)).body.key;
    const rejected = (await s.uploadPhoto(a, PNG)).body.key;
    s.store.setPhotoCheck(a.id, waiting, 'review');
    s.store.setPhotoCheck(a.id, rejected, 'rejected');
    await area(a);

    const seen = (await s.nearby(viewer)).body.people.find((p) => p.id === a.id);
    assert.equal(seen.pendingVerification, true);
    assert.equal(seen.selfieVerified, false);
    assert.deepEqual(seen.photos, [waiting]);

    // Once the window closes, what is waiting for review is hidden again.
    backdate(a, 25);
    const later = (await s.nearby(viewer)).body.people.find((p) => p.id === a.id);
    assert.deepEqual(later?.photos ?? [], []);
  });

  await t.test('UP works inside the window', async () => {
    const a = await s.signUp('+972574000004', { verified: false, fresh: true });
    const res = await s.call('POST', `/likes/${viewer.id}`, { token: a.token });
    assert.equal(res.status, 200);
  });

  await t.test('after 24 hours without approval: refused', async () => {
    const a = await s.signUp('+972574000005', { verified: false, fresh: true });
    backdate(a, 24.1);
    const res = await area(a);
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'verification_required');
    const me = await s.call('GET', '/me/profile', { token: a.token });
    assert.equal(me.body.verificationGraceEndsAt, null);
  });

  await t.test('approved: no tag, no deadline', async () => {
    const a = await s.signUp('+972574000006');
    await area(a);
    const me = await s.call('GET', '/me/profile', { token: a.token });
    assert.equal(me.body.verificationGraceEndsAt, null);
    assert.equal(me.body.pendingVerification, false);
  });
});

test('sent to a human: 24 hours from then, whatever the account age', async (t) => {
  const previousToken = config.adminToken;
  config.adminToken = 'test-operator-key';
  const s = await startTestServer();
  t.after(() => {
    config.adminToken = previousToken;
    return s.close();
  });
  const area = (user) =>
    s.call('POST', '/live/start', { token: user.token, body: { durationSeconds: 1800, ...HERE } });
  const decide = (id, approve) =>
    s.call('POST', `/admin/verifications/${id}/decide`, {
      body: { approve },
      headers: { 'x-admin-token': config.adminToken },
    });
  const sendToReview = (user) =>
    s.store.recordLiveVerification(user.id, { status: 'pending', reason: 'too_blurry', score: 0.5 });
  const pendingId = (user) => s.store.latestVerification(user.id).id;

  await t.test('old account, borderline check: in for 24 hours', async () => {
    const a = await s.signUp('+972574000101', { verified: false }); // 72h old
    assert.equal((await area(a)).status, 403);
    sendToReview(a);
    assert.equal((await area(a)).status, 200);
    const v = await s.call('GET', '/me/verification', { token: a.token });
    assert.equal(v.body.status, 'pending');
    const hours = (Date.parse(v.body.graceEndsAt) - Date.now()) / 3600_000;
    assert.ok(hours > 23.9 && hours <= 24, `got ${hours}`);
  });

  await t.test('trying again while waiting does not restart the clock', async () => {
    const a = await s.signUp('+972574000102', { verified: false });
    sendToReview(a);
    s.store.db
      .prepare(`UPDATE users SET review_grace_from = ? WHERE id = ?`)
      .run(new Date(Date.now() - 20 * 3600_000).toISOString(), a.id);
    sendToReview(a);
    const v = await s.call('GET', '/me/verification', { token: a.token });
    const hours = (Date.parse(v.body.graceEndsAt) - Date.now()) / 3600_000;
    assert.ok(hours > 3.9 && hours <= 4, `got ${hours}`);
  });

  await t.test('after the 24 hours: refused until approved', async () => {
    const a = await s.signUp('+972574000103', { verified: false });
    sendToReview(a);
    s.store.db
      .prepare(`UPDATE users SET review_grace_from = ? WHERE id = ?`)
      .run(new Date(Date.now() - 24.1 * 3600_000).toISOString(), a.id);
    assert.equal((await area(a)).status, 403);
    assert.equal((await decide(pendingId(a), true)).status, 200);
    assert.equal((await area(a)).status, 200);
  });

  await t.test('rejected by the reviewer: the window closes at once', async () => {
    const a = await s.signUp('+972574000104', { verified: false });
    sendToReview(a);
    assert.equal((await area(a)).status, 200);
    await s.call('POST', '/live/stop', { token: a.token });
    assert.equal((await decide(pendingId(a), false)).status, 200);
    const res = await area(a);
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'verification_required');
  });
});
