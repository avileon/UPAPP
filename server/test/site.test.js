import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

import { createApp } from '../src/app.js';
import { StaticSite } from '../src/lib/static.js';

/**
 * Serving the app and the API from one origin.
 *
 * The reason this is worth its own file: a static file server reachable from
 * the internet is the classic place to hand out `/etc/passwd`, and the path
 * that gets there is attacker-controlled by construction.
 */
test('the web app', async (t) => {
  const root = mkdtempSync(join(tmpdir(), 'up-site-'));
  mkdirSync(join(root, 'assets'), { recursive: true });
  writeFileSync(join(root, 'index.html'), '<!doctype html><title>UP</title>');
  writeFileSync(join(root, 'main.dart.js'), 'console.log(1)');
  writeFileSync(join(root, 'assets', 'logo.png'), Buffer.from([0x89, 0x50]));
  writeFileSync(join(tmpdir(), 'up-secret-outside.txt'), 'do not serve me');

  const app = createApp({
    database: ':memory:',
    site: new StaticSite(root),
  });
  const server = createServer(app.handle);
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;

  t.after(async () => {
    server.close();
    await once(server, 'close');
    app.db.close();
    rmSync(root, { recursive: true, force: true });
  });

  await t.test('the root serves the app', async () => {
    const res = await fetch(`${base}/`);
    assert.equal(res.status, 200);
    assert.match(res.headers.get('content-type'), /text\/html/);
    assert.match(await res.text(), /<title>UP<\/title>/);
  });

  await t.test('assets get their real content types', async () => {
    const js = await fetch(`${base}/main.dart.js`);
    assert.match(js.headers.get('content-type'), /javascript/);

    const png = await fetch(`${base}/assets/logo.png`);
    assert.equal(png.headers.get('content-type'), 'image/png');
  });

  await t.test('an unknown path is a screen, not a 404', async () => {
    // The app owns its own routing: /chat is a screen, not a file.
    const res = await fetch(`${base}/chat`);
    assert.equal(res.status, 200);
    assert.match(await res.text(), /<title>UP<\/title>/);
  });

  await t.test('the API still wins over the app', async () => {
    const res = await fetch(`${base}/health`);
    assert.equal(res.status, 200);
    assert.equal((await res.json()).ok, true);

    // And an API route that exists but is refused stays JSON, rather than
    // quietly serving index.html to a client expecting an answer.
    const unauthorised = await fetch(`${base}/me/profile`);
    assert.equal(unauthorised.status, 401);
  });

  await t.test('a path cannot climb out of the web root', async () => {
    for (const path of [
      '/../up-secret-outside.txt',
      '/..%2Fup-secret-outside.txt',
      '/assets/../../up-secret-outside.txt',
      '/%2e%2e/%2e%2e/etc/passwd',
    ]) {
      const res = await fetch(`${base}${path}`);
      const body = await res.text();
      assert.ok(
        !body.includes('do not serve me'),
        `${path} escaped the web root`,
      );
    }
  });

  await t.test('the second load of an asset is a 304', async () => {
    const first = await fetch(`${base}/main.dart.js`);
    const etag = first.headers.get('etag');
    assert.ok(etag);

    const second = await fetch(`${base}/main.dart.js`, {
      headers: { 'if-none-match': etag },
    });
    assert.equal(second.status, 304);
  });
});

test('a server with no web build still serves the API', async (t) => {
  const app = createApp({
    database: ':memory:',
    site: new StaticSite(join(tmpdir(), 'up-site-that-does-not-exist')),
  });
  const server = createServer(app.handle);
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;

  t.after(async () => {
    server.close();
    await once(server, 'close');
    app.db.close();
  });

  await t.test('health works and an unknown path is an honest 404', async () => {
    assert.equal((await fetch(`${base}/health`)).status, 200);
    const missing = await fetch(`${base}/whatever`);
    assert.equal(missing.status, 404);
    assert.equal((await missing.json()).error, 'no_such_route');
  });
});
