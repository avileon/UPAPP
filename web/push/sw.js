/* eslint-env serviceworker */

/**
 * The push worker.
 *
 * It lives in `push/` rather than at the site root because Flutter registers
 * its own service worker at `/`, and two workers cannot control one scope —
 * the second registration silently replaces the first. A script served from a
 * subdirectory gets that subdirectory as its default scope, so the two live
 * side by side with no server header and no coordination.
 *
 * Controlling no pages costs nothing here: a push subscription belongs to the
 * registration rather than to the scope, so this receives every message
 * regardless of which page is open.
 */

self.addEventListener('install', () => {
  // No cache to warm and nothing to wait for. Taking over immediately means a
  // deploy that changes this file is in effect on the next notification
  // instead of after the browser is next closed.
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', (event) => {
  // A push with no readable payload still has to show something: the browser
  // permission was granted on the promise that every message is visible, and
  // an engine that receives one and shows nothing may revoke the subscription.
  let data = { kind: 'message', title: 'UP', body: 'הודעה חדשה' };
  try {
    if (event.data) data = { ...data, ...event.data.json() };
  } catch (_) {
    // Malformed payload. The default above stands.
  }

  event.waitUntil(
    (async () => {
      // Silence for a conversation that is already open on screen. Buzzing a
      // phone about a message the person is watching arrive is the fastest way
      // to teach them to turn notifications off.
      const clients = await self.clients.matchAll({
        type: 'window',
        // Without this the list is empty: the app is controlled by Flutter's
        // worker at `/`, not by this one.
        includeUncontrolled: true,
      });
      const watching = clients.some((client) => client.visibilityState === 'visible');
      if (watching && data.kind === 'message') return;

      await self.registration.showNotification(data.title || 'UP', {
        body: data.body || '',
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        // One notification per conversation, replaced rather than stacked:
        // twelve buzzes from one person is the same information as one.
        tag: data.matchId ? `up-match-${data.matchId}` : 'up',
        renotify: true,
        data: { matchId: data.matchId || null },
      });
    })(),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const matchId = event.notification.data && event.notification.data.matchId;

  event.waitUntil(
    (async () => {
      const clients = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });
      // Reuse the tab that is already open rather than opening a second copy
      // of the app next to it. No navigation in that case: `navigate()` is
      // only allowed on clients this worker controls, and this one controls
      // none by design. A focused tab already shows the banner and the badge,
      // which is one tap from the conversation.
      for (const client of clients) {
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      // Nothing open: this is the case the deep link exists for. The app reads
      // `?chat=` once at startup and opens that thread.
      return self.clients.openWindow(matchId ? `/?chat=${matchId}` : '/');
    })(),
  );
});
