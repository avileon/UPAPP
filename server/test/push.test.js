import test from 'node:test';
import assert from 'node:assert/strict';

import { config } from '../src/config.js';
import { generateVapidKeys } from '../src/lib/webpush.js';
import { startTestServer } from './helpers.js';

/**
 * The subscription endpoints.
 *
 * A push subscription is a capability: whoever holds the endpoint can queue a
 * notification onto someone's phone. That makes these three small routes worth
 * more care than their size suggests — most of what is pinned here is about
 * who is allowed to create, replace, or cancel one.
 */
test('push subscriptions', async (t) => {
  const s = await startTestServer();
  t.after(() => s.close());

  const keys = generateVapidKeys();
  const withKeys = (fn) => async () => {
    const previous = { ...config.vapid };
    Object.assign(config.vapid, keys);
    try {
      await fn();
    } finally {
      Object.assign(config.vapid, previous);
    }
  };

  const subscription = (suffix) => ({
    endpoint: `https://push.example.com/s/${suffix}`,
    p256dh: 'BOxWlLzp9K7XyNvHnJ8pQqRsTuVwXyZ0123456789abcdefghijklmnopqrstuvwxyzAB',
    auth: 'c29tZS1hdXRoLXNlY3I',
  });

  await t.test('the public key is readable without signing in', async () => {
    // The app needs it before it has decided whether to ask for permission,
    // and it is public by definition — it ends up inside every subscription.
    await withKeys(async () => {
      const res = await s.call('GET', '/push/key');
      assert.equal(res.status, 200);
      assert.equal(res.body.publicKey, keys.publicKey);
    })();
  });

  await t.test('a deployment with no keys says so instead of failing',
    async () => {
      const res = await s.call('GET', '/push/key');
      assert.equal(res.status, 200);
      assert.equal(res.body.publicKey, '');
      // An empty key is how the app knows not to offer notifications at all.
    });

  await t.test('subscribing requires a session', async () => {
    await withKeys(async () => {
      const res = await s.call('POST', '/push/subscribe', {
        body: subscription('anon'),
      });
      assert.equal(res.status, 401);
    })();
  });

  await t.test('an endpoint that is not https is refused', async () => {
    // The server will later POST to whatever is stored here. Anything but an
    // https push endpoint is a request to point it somewhere it should not go.
    await withKeys(async () => {
      const a = await s.signUp('+972530000001');
      for (const endpoint of ['http://push.example.com/s/1', 'file:///etc/passwd', 'nonsense']) {
        const res = await s.call('POST', '/push/subscribe', {
          token: a.token,
          body: { ...subscription('1'), endpoint },
        });
        assert.equal(res.status, 400, `${endpoint} should be refused`);
        assert.equal(res.body.error, 'invalid_subscription');
      }
    })();
  });

  await t.test('a subscription missing its keys is refused', async () => {
    await withKeys(async () => {
      const a = await s.signUp('+972530000002');
      const res = await s.call('POST', '/push/subscribe', {
        token: a.token,
        body: { endpoint: 'https://push.example.com/s/2' },
      });
      assert.equal(res.status, 400);
    })();
  });

  await t.test('the same browser subscribing twice keeps one row', async () => {
    // Push services rotate endpoints, and browsers re-subscribe on their own.
    // Accumulating rows would mean sending the same notification five times.
    await withKeys(async () => {
      const a = await s.signUp('+972530000003');
      const body = subscription('same');
      assert.equal(
        (await s.call('POST', '/push/subscribe', { token: a.token, body })).status,
        200,
      );
      assert.equal(
        (await s.call('POST', '/push/subscribe', { token: a.token, body })).status,
        200,
      );
      assert.equal(s.store.listPushSubscriptions(a.id).length, 1);
    })();
  });

  await t.test('one person cannot cancel another person’s notifications',
    async () => {
      // The endpoint is guessable from a shared browser or a leaked log. It
      // must not be enough to silence somebody else's phone.
      await withKeys(async () => {
        const a = await s.signUp('+972530000004');
        const b = await s.signUp('+972530000005');
        const body = subscription('victim');

        await s.call('POST', '/push/subscribe', { token: a.token, body });
        const res = await s.call('POST', '/push/unsubscribe', {
          token: b.token,
          body: { endpoint: body.endpoint },
        });

        assert.equal(res.status, 200, 'answers the same either way');
        assert.equal(
          s.store.listPushSubscriptions(a.id).length,
          1,
          'but changes nothing',
        );
      })();
    });

  await t.test('unsubscribing removes your own', async () => {
    await withKeys(async () => {
      const a = await s.signUp('+972530000006');
      const body = subscription('mine');
      await s.call('POST', '/push/subscribe', { token: a.token, body });
      await s.call('POST', '/push/unsubscribe', {
        token: a.token,
        body: { endpoint: body.endpoint },
      });
      assert.deepEqual(s.store.listPushSubscriptions(a.id), []);
    })();
  });

  await t.test('a browser moving to another account moves its row', async () => {
    // Two people on one laptop. The second person's notifications must not go
    // to the first, and the first must stop receiving them.
    await withKeys(async () => {
      const a = await s.signUp('+972530000007');
      const b = await s.signUp('+972530000008');
      const body = subscription('shared-laptop');

      await s.call('POST', '/push/subscribe', { token: a.token, body });
      await s.call('POST', '/push/subscribe', { token: b.token, body });

      assert.deepEqual(s.store.listPushSubscriptions(a.id), []);
      assert.equal(s.store.listPushSubscriptions(b.id).length, 1);
    })();
  });

  await t.test('deleting an account takes its subscriptions with it', async () => {
    await withKeys(async () => {
      const a = await s.signUp('+972530000009');
      await s.call('POST', '/push/subscribe', {
        token: a.token,
        body: subscription('deleted'),
      });
      await s.call('DELETE', '/me', { token: a.token });
      assert.deepEqual(s.store.listPushSubscriptions(a.id), []);
    })();
  });
});
