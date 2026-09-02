import { config } from './config.js';
import { sendPush } from './lib/webpush.js';

/**
 * What is worth waking someone's phone for, and what it is allowed to say.
 *
 * Two events qualify and no others: a message in a conversation you are
 * already in, and a match. Both are things the person is waiting for and
 * neither can be manufactured by a stranger — an UP on its own is deliberately
 * silent, because a notification for "someone likes you" turns a private
 * signal into leverage and invites exactly the behaviour this app exists to
 * avoid.
 *
 * The body carries a first name and a line of text. That is a real disclosure:
 * it appears on a lock screen where other people can see it. It is here anyway
 * because a notification that says "New message" and nothing else gets opened
 * at the wrong times and ignored at the right ones — and the payload is
 * encrypted to a key only that browser holds, so the disclosure is to whoever
 * can see the screen, not to Google, Mozilla or us.
 */

/** Notifications are simply off when no keys have been configured. */
export const pushConfigured = () =>
  Boolean(config.vapid.publicKey && config.vapid.privateKey);

const truncate = (text, limit) => {
  const value = String(text ?? '').replace(/\s+/g, ' ').trim();
  return value.length <= limit ? value : `${value.slice(0, limit - 1)}…`;
};

/**
 * Fans one notification out to every device the person has.
 *
 * Never awaited by a request handler. Sending a message must not get slower,
 * or fail, because a push service in another country is having a bad minute —
 * the message is already saved and the app polls for it regardless. Failures
 * are dropped; a subscription the service reports as dead is deleted, which is
 * the only outcome here that changes any state.
 */
async function deliver(store, userId, payload) {
  if (!pushConfigured()) return;
  const subscriptions = store.listPushSubscriptions(userId);
  if (subscriptions.length === 0) return;

  const body = JSON.stringify(payload);
  await Promise.all(
    subscriptions.map(async (subscription) => {
      const result = await sendPush({
        subscription,
        payload: body,
        keys: config.vapid,
        subject: config.vapid.subject,
      });
      if (result.gone) {
        store.deletePushSubscription(subscription.endpoint);
      }
    }),
  );
}

/** Fire-and-forget, with the rejection swallowed rather than left unhandled. */
function detach(promise) {
  promise.catch(() => {});
}

export function notifyNewMessage(store, { recipientId, senderName, body, matchId }) {
  detach(
    deliver(store, recipientId, {
      kind: 'message',
      title: senderName || 'UP',
      // Enough to decide whether to open it, short enough to fit on a lock
      // screen without being cut mid-word by the operating system.
      body: truncate(body, 120),
      matchId,
    }),
  );
}

export function notifyMatch(store, { recipientId, otherName, matchId }) {
  detach(
    deliver(store, recipientId, {
      kind: 'match',
      title: 'UP',
      body: otherName ? `${otherName} — It’s an UP!` : 'It’s an UP!',
      matchId,
    }),
  );
}
