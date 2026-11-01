import test from 'node:test';
import assert from 'node:assert/strict';

import { startTestServer } from './helpers.js';

/**
 * Business cards: a tap or a scan hands over `/c/<token>`; an UP from that
 * page is a match, because giving the card was the giver's UP.
 */
test('business cards', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  const avi = await s.signUp('+972580000001', { firstName: 'אבי' });
  const dana = await s.signUp('+972580000002', { firstName: 'Dana' });
  const noa = await s.signUp('+972580000003', { firstName: 'Noa' });

  const issue = (user, body = {}) => s.call('POST', '/me/card', { token: user.token, body });
  const tokenOf = (res) => res.body.token;

  await t.test('issuing: a short token, a /c/ link, 24 hours', async () => {
    const res = await issue(avi);
    assert.equal(res.status, 200);
    assert.match(res.body.token, /^[A-Za-z0-9_-]{12}$/);
    assert.match(res.body.url, /\/c\/[A-Za-z0-9_-]{12}$/);
    assert.equal(res.body.kind, 'share');
    const hours = (new Date(res.body.expiresAt) - Date.now()) / 3600_000;
    assert.ok(hours > 23.9 && hours <= 24);
  });

  await t.test('issuing needs a signed-in user with a name', async () => {
    assert.equal((await s.call('POST', '/me/card', { body: {} })).status, 401);
  });

  await t.test('the public page shows a first name and nothing else', async () => {
    const token = tokenOf(await issue(avi));
    const res = await fetch(`${s.base}/c/${token}`);
    assert.equal(res.status, 200);
    assert.match(res.headers.get('x-robots-tag') ?? '', /noindex/);
    const html = await res.text();
    assert.match(html, /אבי/);
    assert.match(html, new RegExp(`/app\\?card=${token}`));
    assert.doesNotMatch(html, /\+9725/);
    assert.doesNotMatch(html, /1994/);

    const json = await s.call('GET', `/cards/${token}`);
    assert.equal(json.status, 200);
    assert.deepEqual(Object.keys(json.body).sort(), ['firstName', 'kind', 'photo', 'verified']);
    assert.equal(json.body.firstName, 'אבי');
  });

  await t.test('an unknown token is a polite 410, not a crash', async () => {
    const res = await fetch(`${s.base}/c/nope-nope-nope`);
    assert.equal(res.status, 410);
    assert.equal((await s.call('GET', '/cards/../../etc')).status, 404);
    assert.equal((await s.call('GET', '/cards/short')).status, 410);
  });

  await t.test('her UP from the card is an instant match, and the chat opens', async () => {
    const token = tokenOf(await issue(avi));
    const res = await s.call('POST', `/cards/${token}/up`, { token: dana.token });
    assert.equal(res.status, 200);
    assert.ok(res.body.match?.id);
    assert.equal(res.body.match.personId, avi.id);
    assert.equal(res.body.person.firstName, 'אבי');

    const aviMatches = await s.call('GET', '/matches', { token: avi.token });
    assert.ok(aviMatches.body.matches.some((m) => m.person?.id === dana.id));
  });

  await t.test('a share card answers one person: forwarding it does nothing', async () => {
    const token = tokenOf(await issue(avi));
    assert.equal((await s.call('POST', `/cards/${token}/up`, { token: noa.token })).status, 200);
    const again = await s.call('POST', `/cards/${token}/up`, { token: dana.token });
    assert.equal(again.status, 410);
    assert.equal(again.body.error, 'card_used');
    // The one who answered can retry safely.
    assert.equal((await s.call('POST', `/cards/${token}/up`, { token: noa.token })).status, 200);
    assert.equal((await fetch(`${s.base}/c/${token}`)).status, 410);
  });

  await t.test('your own card cannot be answered by you', async () => {
    const token = tokenOf(await issue(avi));
    assert.equal((await s.call('POST', `/cards/${token}/up`, { token: avi.token })).status, 400);
  });

  await t.test('answering needs a verified face', async () => {
    const shy = await s.signUp('+972580000004', { verified: false });
    const token = tokenOf(await issue(avi));
    const res = await s.call('POST', `/cards/${token}/up`, { token: shy.token });
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'verification_required');
    // Not used up by a refusal.
    assert.equal((await s.call('GET', `/cards/${token}`)).status, 200);
  });

  await t.test('a block either way stops the card', async () => {
    const eli = await s.signUp('+972580000005', { firstName: 'Eli' });
    await s.call('POST', `/users/${eli.id}/block`, { token: avi.token });
    const token = tokenOf(await issue(avi));
    const res = await s.call('POST', `/cards/${token}/up`, { token: eli.token });
    assert.equal(res.status, 403);
  });

  await t.test('physical cards last and answer many; revoking kills them all', async () => {
    const card = await issue(avi, { kind: 'physical' });
    assert.equal(card.body.expiresAt, null);
    const a = await s.signUp('+972580000006');
    const b = await s.signUp('+972580000007');
    assert.equal((await s.call('POST', `/cards/${card.body.token}/up`, { token: a.token })).status, 200);
    assert.equal((await s.call('POST', `/cards/${card.body.token}/up`, { token: b.token })).status, 200);

    const revoked = await s.call('DELETE', '/me/cards', { token: avi.token });
    assert.ok(revoked.body.revoked >= 1);
    assert.equal((await s.call('GET', `/cards/${card.body.token}`)).status, 410);
  });

  await t.test('an expired card is gone', async () => {
    const token = tokenOf(await issue(avi));
    s.app.db.prepare(`UPDATE cards SET expires_at = '2000-01-01T00:00:00.000Z'`).run();
    const res = await s.call('GET', `/cards/${token}`);
    assert.equal(res.status, 410);
    assert.equal(res.body.error, 'card_expired');
  });

  await t.test('the token is not stored in the clear', async () => {
    const token = tokenOf(await issue(avi));
    const dump = JSON.stringify(s.app.db.prepare('SELECT * FROM cards').all());
    assert.ok(!dump.includes(token));
  });

  await t.test('/app?card= and /?card= open the app', async () => {
    const res = await fetch(`${s.base}/?card=abc`);
    assert.equal(res.status, 200);
  });
});

test('google wallet', async (t) => {
  const { generateKeyPairSync, createVerify } = await import('node:crypto');
  const { WalletSigner } = await import('../src/lib/wallet.js');
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const signer = new WalletSigner({
    issuerId: '3388000000012345678',
    serviceAccount: {
      client_email: 'up-wallet@test.iam.gserviceaccount.com',
      private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }),
    },
    publicUrl: 'https://up.atar.co',
  });

  await t.test('the save link is a JWT Google can verify, holding the card QR', () => {
    const link = signer.saveUrl({ objectSuffix: 'card_u1_1', firstName: 'אבי', cardUrl: 'https://up.atar.co/c/abcdefghijkl' });
    assert.match(link, /^https:\/\/pay\.google\.com\/gp\/v\/save\//);
    const jwt = link.split('/').pop();
    const [h, c, sig] = jwt.split('.');
    assert.ok(createVerify('RSA-SHA256').update(`${h}.${c}`).verify(publicKey, sig, 'base64url'));
    const claims = JSON.parse(Buffer.from(c, 'base64url').toString());
    assert.equal(claims.typ, 'savetowallet');
    assert.equal(claims.aud, 'google');
    const obj = claims.payload.genericObjects[0];
    assert.equal(obj.barcode.type, 'QR_CODE');
    assert.equal(obj.barcode.value, 'https://up.atar.co/c/abcdefghijkl');
    assert.equal(obj.header.defaultValue.value, 'אבי');
    assert.ok(obj.id.startsWith('3388000000012345678.'));
  });

  await t.test('not configured: no button, and the route says so', async () => {
    const s = await startTestServer();
    t.after(() => s.close());
    const u = await s.signUp('+972589999001', { firstName: 'X' });
    const card = await s.call('POST', '/me/card', { token: u.token, body: {} });
    assert.equal(card.body.wallet, false);
    const res = await s.call('POST', '/me/card/wallet', { token: u.token, body: {} });
    assert.equal(res.status, 503);
    assert.equal(res.body.error, 'wallet_unavailable');
  });
});
