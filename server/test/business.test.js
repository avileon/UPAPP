import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { once } from 'node:events';

import { createApp } from '../src/app.js';
import { config } from '../src/config.js';

/**
 * A bar signing itself up from /business: it gets a code and a private page
 * at once, but nobody can check in there until the operator approves it.
 */
test('business sign-up', async (t) => {
  const lookups = [];
  const geocoder = {
    search: async (q) => {
      lookups.push(q);
      return [{ label: 'דיזנגוף 100, תל אביב', lat: 32.078, lng: 34.774 }];
    },
  };
  const app = createApp({ database: ':memory:', geocoder });
  const server = createServer(app.handle);
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;
  const previous = config.adminToken;
  config.adminToken = 'op-key';
  t.after(async () => {
    config.adminToken = previous;
    server.close();
    await once(server, 'close');
    app.db.close();
  });

  const call = async (method, path, body, headers = {}) => {
    const r = await fetch(`${base}${path}`, {
      method,
      headers: { 'content-type': 'application/json', ...headers },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await r.text();
    return { status: r.status, body: text.startsWith('{') ? JSON.parse(text) : text, headers: r.headers };
  };
  const op = (method, path, body) => call(method, path, body, { 'x-admin-token': 'op-key' });

  const form = {
    name: 'הבר של רוני',
    kind: 'bar',
    address: 'דיזנגוף 100, תל אביב',
    lat: 32.078,
    lng: 34.774,
    contactName: 'רוני',
    contactPhone: '050-1234567',
    contactEmail: 'roni@example.com',
    terms: true,
  };

  let owner;
  await t.test('an application gets a code and a private status link', async () => {
    const r = await call('POST', '/business/apply', form);
    assert.equal(r.status, 201);
    assert.match(r.body.code, /^[A-Z0-9]{6}$/);
    assert.equal(r.body.status, 'pending');
    assert.ok(r.body.ownerToken.length >= 24);
    assert.equal(r.body.statusUrl, `${config.publicUrl}/business/status#k=${r.body.ownerToken}`);
    owner = r.body;
  });

  await t.test('the form refuses what it should', async () => {
    const bad = async (patch) => (await call('POST', '/business/apply', { ...form, ...patch })).body.error;
    assert.equal(await bad({ name: '' }), 'name_required');
    assert.equal(await bad({ lat: 51.5, lng: -0.1 }), 'invalid_location');
    assert.equal(await bad({ contactPhone: '12' }), 'invalid_phone');
    assert.equal(await bad({ terms: false }), 'terms_required');
  });

  await t.test('too many applications from one address are refused', async () => {
    // Five per hour per address; the first test used one and the refusals four.
    const r = await call('POST', '/business/apply', form);
    assert.equal(r.status, 429);
    assert.equal(r.body.error, 'apply_rate_limited');
  });

  await t.test('pending: visible to its owner, closed to guests', async () => {
    const me = await call('GET', '/business/me', undefined, { 'x-business-token': owner.ownerToken });
    assert.equal(me.status, 200);
    assert.equal(me.body.name, form.name);
    assert.equal(me.body.status, 'pending');
    assert.equal(me.body.active, false);
    assert.equal(me.body.joinUrl, `${config.publicUrl}/?venue=${owner.code}`);
    // No contact details on the owner view — it is a bearer link.
    assert.equal(me.body.contact, undefined);

    assert.equal((await call('GET', '/business/me', undefined, { 'x-business-token': 'x'.repeat(32) })).status, 401);
    assert.equal((await call('GET', '/business/me')).status, 401);
  });

  await t.test('the operator sees it with contact details, and approves it', async () => {
    const list = await op('GET', '/admin/venues');
    const row = list.body.venues.find((v) => v.code === owner.code);
    assert.equal(row.status, 'pending');
    assert.equal(row.contact.phone, '0501234567');
    assert.equal(row.kind, 'bar');

    const ok = await op('POST', `/admin/venues/${owner.code}/approve`);
    assert.equal(ok.body.status, 'approved');
    assert.equal(ok.body.active, true);

    const me = await call('GET', '/business/me', undefined, { 'x-business-token': owner.ownerToken });
    assert.equal(me.body.status, 'approved');
    assert.equal(me.body.active, true);
  });

  await t.test('approve and reject need the operator key', async () => {
    assert.equal((await call('POST', `/admin/venues/${owner.code}/reject`)).status, 401);
    const no = await op('POST', `/admin/venues/${owner.code}/reject`);
    assert.equal(no.body.status, 'rejected');
    assert.equal(no.body.active, false);
  });

  await t.test('address search goes through the geocoder', async () => {
    const r = await call('GET', `/geo/search?q=${encodeURIComponent('דיזנגוף 100')}`);
    assert.equal(r.status, 200);
    assert.equal(r.body.results[0].lat, 32.078);
    assert.deepEqual(lookups, ['דיזנגוף 100']);
    assert.equal((await call('GET', '/geo/search?q=a')).body.error, 'query_too_short');
  });
});

test('the public site', async (t) => {
  const app = createApp({ database: ':memory:' });
  const server = createServer(app.handle);
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;
  t.after(async () => {
    server.close();
    await once(server, 'close');
    app.db.close();
  });
  const get = (p) => fetch(`${base}${p}`);

  await t.test('landing page carries what search engines read', async () => {
    const html = await (await get('/')).text();
    assert.match(html, /<html lang="he" dir="rtl">/);
    assert.match(html, /<title>UP — אפליקציית הכרויות/);
    assert.match(html, /<meta name="description" content="[^"]{80,}">/);
    assert.match(html, /<link rel="canonical" href="https:\/\/up\.atar\.co\/">/);
    assert.match(html, /og:image" content="https:\/\/up\.atar\.co\/site\/og\.png"/);
    const ld = JSON.parse(html.match(/<script type="application\/ld\+json">(.*?)<\/script>/s)[1]);
    const types = ld['@graph'].map((n) => n['@type']);
    for (const type of ['Organization', 'WebSite', 'WebApplication', 'FAQPage']) {
      assert.ok(types.includes(type), type);
    }
    assert.equal((html.match(/<h1>/g) ?? []).length, 1);
    assert.match(html, /href="\/business"/);
    assert.match(html, /href="\/app"/);
  });

  await t.test('business page has the sign-up form', async () => {
    const html = await (await get('/business')).text();
    assert.match(html, /<link rel="canonical" href="https:\/\/up\.atar\.co\/business">/);
    assert.match(html, /id="apply"/);
    assert.match(html, /BreadcrumbList/);
  });

  await t.test('the owner page is never indexed', async () => {
    const res = await get('/business/status');
    assert.equal(res.headers.get('x-robots-tag'), 'noindex');
    assert.match(res.headers.get('cache-control'), /no-store/);
  });

  await t.test('robots, sitemap and manifest', async () => {
    const robots = await (await get('/robots.txt')).text();
    assert.match(robots, /Disallow: \/admin/);
    assert.match(robots, /Sitemap: https:\/\/up\.atar\.co\/sitemap\.xml/);
    const sitemap = await (await get('/sitemap.xml')).text();
    assert.match(sitemap, /<loc>https:\/\/up\.atar\.co\/<\/loc>/);
    assert.match(sitemap, /<loc>https:\/\/up\.atar\.co\/business<\/loc>/);
    const manifest = await (await get('/manifest.json')).json();
    assert.equal(manifest.start_url, '/app');
    assert.equal(manifest.short_name, 'UP');
  });

  await t.test('assets are served, and nothing outside them', async () => {
    for (const [p, type] of [
      ['/site/site.css', /text\/css/],
      ['/site/og.png', /image\/png/],
      ['/site/Rubik-800.woff2', /font\/woff2/],
      ['/site/qrcode.js', /javascript/],
      ['/icons/Icon-192.png', /image\/png/],
    ]) {
      const res = await get(p);
      assert.equal(res.status, 200, p);
      assert.match(res.headers.get('content-type'), type, p);
    }
    assert.equal((await get('/site/..%2Fpages.js')).status, 404);
    assert.equal((await get('/site/pages.js')).status, 404);
  });
});
