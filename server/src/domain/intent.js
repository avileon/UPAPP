/**
 * Why someone is Live right now.
 *
 * This is the single change that stops UP from being a dating app that also
 * lets you meet people, and makes it an app for meeting people that also lets
 * you date. Both were always possible; the reason it read as dating is that
 * the gender-preference filter ran on every discovery, so a room of eight
 * people showed you two — and the two it showed were selected by a rule that
 * only makes sense if the answer to "why are you here" is romance.
 *
 * An intent is chosen per session, not per account. The same person is looking
 * for a running partner on Tuesday morning and a date on Friday night, and an
 * app that makes them edit a profile to say so will get neither.
 *
 * Four, deliberately. Every extra option splits the room, and a room split
 * four ways in a bar with twelve people in it already has three empty
 * corners.
 */
export const INTENTS = Object.freeze(['meet', 'date', 'work', 'doing']);

export const DEFAULT_INTENT = 'meet';

export function normaliseIntent(raw) {
  return INTENTS.includes(raw) ? raw : DEFAULT_INTENT;
}

/**
 * Two people discover each other only inside the same intent.
 *
 * The alternative — showing everyone and labelling them — was tempting and is
 * wrong: it puts a person who came to find a tennis partner in front of
 * someone who came to date, and leaves the awkwardness for them to sort out.
 * The whole value of asking the question is that the answer is acted on.
 */
export function intentsMeet(a, b) {
  return normaliseIntent(a) === normaliseIntent(b);
}

/**
 * Whether "who are you interested in" should gate discovery at all.
 *
 * Only for dating. Filtering a professional meetup or a five-a-side game by
 * gender preference is not a privacy feature, it is a bug that makes half the
 * room invisible for no reason anybody could explain.
 */
export function preferencesGateDiscovery(intent) {
  return normaliseIntent(intent) === 'date';
}

/**
 * The one line under a name: what this person is doing right now.
 *
 * It dies with the session, which is what makes it worth writing. A profile
 * bio is a permanent claim and reads like one; "יושב עם קפה בפינה, שולחן ליד
 * החלון" is only true for the next hour and is the single most useful thing a
 * stranger in the same room could know.
 *
 * Short by construction. Sixty characters is a sentence, not a paragraph, and
 * the cap is what keeps this from turning into a second bio.
 */
export const NOTE_MAX_LENGTH = 60;

export function normaliseNote(raw) {
  if (typeof raw !== 'string') return '';
  // One line. A note is rendered on a card beside a name, and a newline — or a
  // stray control character — there is a layout bug that someone else gets to
  // look at. Everything the person actually typed survives, punctuation
  // included; only the invisible characters are turned into spaces.
  const collapsed = raw
    .split('')
    .map((ch) => (ch.codePointAt(0) < 0x20 || ch.codePointAt(0) === 0x7f ? ' ' : ch))
    .join('')
    .replace(/\s+/g, ' ')
    .trim();
  return collapsed.slice(0, NOTE_MAX_LENGTH);
}
