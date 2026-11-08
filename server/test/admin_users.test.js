import { test } from 'node:test';
import assert from 'node:assert/strict';

import { config } from '../src/config.js';
import { existsSync } from 'node:fs';
import { join } from 'node:path';

import { startTestServer } from './helpers.js';

const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk' +
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);

test('operator: users, suspension, verification, reports, delete', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());
  const previous = config.adminToken;
  config.adminToken = 'op-key';
  t.after(() => {
    config.adminToken = previous;
  });
  const op = (method, path, body) =>
    s.call(method, path, { body, headers: { 'x-admin-token': 'op-key' } });

  const dana = await s.signUp('+972501110001', { firstName: 'Dana', gender: 'female' });
  const omer = await s.signUp('+972501110002', { firstName: 'Omer', verified: false, fresh: true });
  // Straight into the store: Omer has no face check, so the API would refuse
  // his UP — which is not what this test is about.
  s.store.sendLike(dana.id, omer.id);
  s.store.sendLike(omer.id, dana.id);
  await s.call('POST', `/users/${omer.id}/report`, {
    token: dana.token,
    body: { category: 'fake', notes: 'not him' },
  });

  await t.test('the list needs the key', async () => {
    assert.equal((await s.call('GET', '/admin/users')).status, 401);
    assert.equal((await s.call('DELETE', `/admin/users/${dana.id}`)).status, 401);
  });

  await t.test('list and stats show what is going on', async () => {
    const list = await op('GET', '/admin/users');
    assert.equal(list.status, 200);
    const o = list.body.users.find((u) => u.id === omer.id);
    assert.equal(o.firstName, 'Omer');
    assert.equal(o.phone, '+972501110002');
    assert.equal(o.verification, 'none');
    assert.equal(o.graceEndsAt, null, 'no grace without a face check waiting for review');
    assert.equal(o.counts.matches, 1);
    assert.equal(o.counts.reportsOpen, 1);
    assert.ok(o.lastSeenAt);

    const stats = await op('GET', '/admin/stats');
    assert.equal(stats.body.users, 2);
    assert.equal(stats.body.matches, 1);
    assert.equal(stats.body.openReports, 1);
    assert.equal(typeof stats.body.liveNow, 'number');
  });

  await t.test('detail has matches and message counts, not message text', async () => {
    const d = await op('GET', `/admin/users/${dana.id}`);
    assert.equal(d.body.matches.length, 1);
    assert.equal(d.body.matches[0].other.firstName, 'Omer');
    assert.deepEqual(d.body.matches[0].messages, { mine: 0, theirs: 0 });
    assert.equal(d.body.reports.length, 1);
  });

  await t.test('manual approval from the card, then revoke', async () => {
    const ok = await op('POST', `/admin/users/${omer.id}/verification`, { approve: true });
    assert.equal(ok.body.verification, 'approved');
    assert.equal(s.store.isSelfieVerified(omer.id), true);
    const back = await op('POST', `/admin/users/${omer.id}/verification`, { approve: false });
    assert.equal(back.body.verification, 'none');
    assert.equal(s.store.isSelfieVerified(omer.id), false);
  });

  await t.test('reports resolve', async () => {
    const open = await op('GET', '/admin/reports');
    assert.equal(open.body.reports.length, 1);
    assert.equal(open.body.reports[0].reported.firstName, 'Omer');
    await op('POST', `/admin/reports/${open.body.reports[0].id}/resolve`, {});
    assert.equal((await op('GET', '/admin/reports')).body.reports.length, 0);
    assert.equal((await op('GET', '/admin/reports?all=1')).body.reports.length, 1);
  });

  await t.test('suspension locks every door and lifts cleanly', async () => {
    const sus = await op('POST', `/admin/users/${omer.id}/suspend`, { reason: 'spam' });
    assert.equal(sus.body.status, 'suspended');
    const me = await s.call('GET', '/me/profile', { token: omer.token });
    assert.equal(me.status, 401);
    assert.equal(me.body.error, 'account_suspended');
    assert.equal(
      (await s.call('POST', '/auth/refresh', { body: { refreshToken: omer.refreshToken } })).status,
      401,
    );
    const otp = await s.call('POST', '/auth/request-otp', { body: { phone: '+972501110002' } });
    const login = await s.call('POST', '/auth/verify-otp', {
      body: { phone: '+972501110002', code: otp.body.devCode },
    });
    assert.equal(login.status, 403);
    assert.equal(login.body.error, 'account_suspended');

    await op('POST', `/admin/users/${omer.id}/unsuspend`);
    assert.equal((await s.call('GET', '/me/profile', { token: omer.token })).status, 200);
  });

  await t.test('delete removes the person and every trace', async () => {
    const photo = await s.uploadPhoto(omer, PNG);
    assert.equal(photo.status, 200);
    const key = JSON.parse(s.store.findProfile(omer.id).photos)[0];
    assert.ok(existsSync(join(s.photoDir, key)));
    const gone = await op('DELETE', `/admin/users/${omer.id}`);
    assert.equal(gone.status, 200);
    assert.equal((await op('GET', `/admin/users/${omer.id}`)).status, 404);
    assert.equal(existsSync(join(s.photoDir, key)), false, 'photo file removed from disk');
    assert.equal((await s.call('GET', '/me/profile', { token: omer.token })).status, 401);
    const left = (n) => s.store.db.prepare(n).get(omer.id).n;
    assert.equal(left(`SELECT COUNT(*) AS n FROM likes WHERE from_user = ?1 OR to_user = ?1`), 0);
    assert.equal(left(`SELECT COUNT(*) AS n FROM matches WHERE user_a = ?1 OR user_b = ?1`), 0);
    assert.equal(left(`SELECT COUNT(*) AS n FROM reports WHERE reported_id = ?1`), 0);
    assert.equal(left(`SELECT COUNT(*) AS n FROM profiles WHERE user_id = ?1`), 0);
    assert.equal((await op('GET', '/admin/stats')).body.users, 1);
    // The number can sign up again, as a new person.
    const again = await s.signUp('+972501110002', { firstName: 'New' });
    assert.notEqual(again.id, omer.id);
    assert.equal((await op('DELETE', '/admin/users/nope')).status, 404);
  });
});

test('operator: a second person with a key of their own', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());
  const previous = config.adminToken;
  config.adminToken = 'owner-key-0123456789';
  t.after(() => {
    config.adminToken = previous;
  });
  const as = (key) => (method, path, body) =>
    s.call(method, path, { body, headers: { 'x-admin-token': key } });
  const owner = as('owner-key-0123456789');

  assert.deepEqual((await owner('GET', '/admin/me')).body, { name: 'בעלים', owner: true });
  const made = await owner('POST', '/admin/operators', { name: 'ארז', email: 'erez@example.com' });
  assert.equal(made.status, 201);
  assert.match(made.body.key, /^upk_/);
  const erez = as(made.body.key);

  assert.deepEqual((await erez('GET', '/admin/me')).body, { name: 'ארז', owner: false });
  assert.equal((await erez('GET', '/admin/users')).status, 200);
  assert.equal((await erez('GET', '/admin/operators')).status, 403);
  assert.equal((await erez('POST', '/admin/operators', { name: 'x' })).status, 403);
  assert.equal((await erez('GET', '/admin/mail')).status, 403);
  assert.equal((await owner('GET', '/admin/operators')).body.operators[0].name, 'ארז');
  // The key is never stored or listed in the clear.
  assert.equal(JSON.stringify((await owner('GET', '/admin/operators')).body).includes(made.body.key), false);

  const dana = await s.signUp('+972501110009', { firstName: 'Dana' });
  await erez('POST', `/admin/users/${dana.id}/suspend`, { reason: 'test' });
  const log = (await owner('GET', '/admin/log')).body.log;
  const entry = log.find((l) => l.path.endsWith('/suspend'));
  assert.equal(entry.operator, 'ארז');
  assert.equal(entry.targetName, 'Dana');

  await owner('DELETE', `/admin/operators/${made.body.id}`);
  assert.equal((await erez('GET', '/admin/users')).status, 401);
  assert.equal((await as('wrong-key-0123456789')('GET', '/admin/users')).status, 401);
});

test('an approval from /admin waits inside the app until it is seen', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());
  const previous = config.adminToken;
  config.adminToken = 'op-key';
  t.after(() => {
    config.adminToken = previous;
  });
  const op = (method, path, body) =>
    s.call(method, path, { body, headers: { 'x-admin-token': 'op-key' } });
  const lee = await s.signUp('+972501110021', { firstName: 'Lee', verified: false, fresh: true });

  assert.deepEqual((await s.call('GET', '/me/notices', { token: lee.token })).body.notices, []);
  await op('POST', `/admin/users/${lee.id}/verification`, { approve: false });
  await op('POST', `/admin/users/${lee.id}/verification`, { approve: true });
  const { notices } = (await s.call('GET', '/me/notices', { token: lee.token })).body;
  // The later decision replaces the earlier one: no "rejected" then "approved".
  assert.equal(notices.length, 1);
  assert.equal(notices[0].kind, 'verification_approved');

  await s.call('POST', `/me/notices/${notices[0].id}/seen`, { token: lee.token });
  assert.deepEqual((await s.call('GET', '/me/notices', { token: lee.token })).body.notices, []);
});
