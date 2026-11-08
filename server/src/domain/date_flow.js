/**
 * What happens between a match and a date.
 *
 * November 2026, from the first real test night:
 *
 * - The chat clock starts at the first *reply*, not the first message. An
 *   opening line nobody answered has not started anything.
 * - Seven minutes, then both choose: meet now, talk on the phone, or not a
 *   match.
 * - While a match is open, the room is closed to both people. They see only
 *   their chat, and nobody else sees them. "Not a match" (or silence past the
 *   deadlines) opens the room to both again.
 *
 * Everything here is a pure function of the match row, its messages and the
 * two choices, so the same answer comes out of `/matches`, `/nearby/resolve`
 * and `/likes` without any of them storing a phase.
 */

export const DATE_CHOICES = Object.freeze(['meet', 'phone', 'no']);

/**
 * @param {object} args
 * @param {{matched_at: string, status: string}} args.match
 * @param {{sender_id: string, created_at: string}[]} args.messages oldest first
 * @param {Record<string, string>} args.choices userId -> choice
 * @param {{chatWindowSeconds: number, chatGraceSeconds: number,
 *          date: {replyMinutes: number, decideMinutes: number, lockHours: number}}} args.config
 * @param {number} [args.now]
 */
export function dateState({ match, messages, choices, config, now = Date.now() }) {
  const matchedAt = Date.parse(match.matched_at);
  const first = messages[0];
  const reply = first ? messages.find((m) => m.sender_id !== first.sender_id) : undefined;
  const replyAt = reply ? Date.parse(reply.created_at) : null;
  const chatEndsAt = replyAt === null ? null : replyAt + config.chatWindowSeconds * 1000;
  const decideBy = chatEndsAt === null ? null : chatEndsAt + config.date.decideMinutes * 60_000;

  const picks = Object.values(choices);
  const outcome = (() => {
    if (picks.includes('no')) return 'no';
    if (picks.length < 2) return null;
    // Numbers are shared only when both asked for the phone. One "meet" and
    // one "phone" is a yes to meeting — not consent to hand over a number.
    return picks.every((c) => c === 'phone') ? 'phone' : 'meet';
  })();

  let phase;
  if (match.status !== 'active' || outcome === 'no') phase = 'ended';
  else if (outcome) phase = outcome;
  else if (replyAt === null) {
    phase = now < matchedAt + config.date.replyMinutes * 60_000 ? 'waiting' : 'stale';
  } else if (now < chatEndsAt) phase = 'chatting';
  else if (now < decideBy) phase = 'deciding';
  else phase = 'stale';

  const holdsRoom =
    phase === 'waiting' ||
    phase === 'chatting' ||
    phase === 'deciding' ||
    ((phase === 'meet' || phase === 'phone') &&
      now < matchedAt + config.date.lockHours * 3600_000);

  // Before the reply anyone may write (that is how the reply happens). Inside
  // the window, plus a few seconds of grace. After an agreed date, freely —
  // "I'm by the bar" is the most useful message there is.
  const canWrite =
    phase === 'waiting' ||
    phase === 'stale' && replyAt === null ||
    (phase === 'chatting') ||
    (chatEndsAt !== null && now <= chatEndsAt + config.chatGraceSeconds * 1000 && phase !== 'ended') ||
    phase === 'meet' ||
    phase === 'phone';

  return {
    phase,
    holdsRoom,
    canWrite,
    outcome,
    replyAt,
    chatEndsAt,
    decideBy,
  };
}
