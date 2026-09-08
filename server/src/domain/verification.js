import { newId } from '../lib/crypto.js';

/**
 * Photo verification, and an honest account of what it can prove.
 *
 * It cannot prove the photo was taken just now. A browser has no way to tell a
 * server "this came from a camera a second ago" — every signal it could send
 * is produced by software the person controls. Anybody claiming otherwise on
 * the web is selling something.
 *
 * What it *can* do is raise the cost. The app opens the camera rather than a
 * file picker, and the server names a pose the person could not have known in
 * advance, seconds earlier, from a set of five. Reusing somebody else's photo
 * now means finding one of that person, in that pose, taken since the
 * challenge was issued. That is not impossible; it is just a great deal of
 * work for the kind of person who was going to give up at the first obstacle.
 *
 * The badge is granted by a human looking at it, never automatically, because
 * the automatic version would be a claim the system cannot back.
 */

/**
 * Five poses, deliberately awkward and deliberately few.
 *
 * Awkward because a pose that appears in ordinary photographs proves nothing —
 * "smile at the camera" is satisfied by half of anyone's gallery. Few because a
 * reviewer has to hold the whole set in their head to judge quickly, and
 * because the security comes from the pose being unpredictable at the moment
 * of asking, not from the size of the list.
 */
export const POSES = Object.freeze([
  {
    key: 'peace',
    he: 'שתי אצבעות (V) ליד הלחי',
    en: 'Two fingers (V) beside your cheek',
  },
  {
    key: 'thumb',
    he: 'אגודל למעלה ליד הכתף',
    en: 'Thumbs up beside your shoulder',
  },
  {
    key: 'palm',
    he: 'כף יד פתוחה ליד האוזן',
    en: 'Open palm beside your ear',
  },
  {
    key: 'crossEar',
    he: 'יד ימין נוגעת באוזן שמאל',
    en: 'Right hand touching your left ear',
  },
  {
    key: 'three',
    he: 'שלוש אצבעות מעל הראש',
    en: 'Three fingers above your head',
  },
]);

export const VERIFICATION_STATUSES = Object.freeze([
  'none',
  'pending',
  'approved',
  'rejected',
]);

export function findPose(key) {
  return POSES.find((pose) => pose.key === key) ?? null;
}

/**
 * Short-lived, one per person, and issued by the server.
 *
 * All three properties are the point. Server-issued, so the pose cannot be
 * chosen; short-lived, so a photo cannot be sourced at leisure; one per
 * person, so nobody can hold five open challenges and submit whichever one
 * they happen to have a picture for.
 *
 * In memory, like live sessions: these expire within minutes and persisting
 * them would mean rows whose only future is a cleanup job.
 */
export class ChallengeStore {
  constructor({ now = () => Date.now(), ttlSeconds = 300, random = Math.random } = {}) {
    this._now = now;
    this._ttl = ttlSeconds * 1000;
    this._random = random;
    /** @type {Map<string, {id: string, pose: string, expiresAt: number}>} */
    this._byUser = new Map();
  }

  issue(userId) {
    const pose = POSES[Math.floor(this._random() * POSES.length) % POSES.length];
    const challenge = {
      id: newId(),
      pose: pose.key,
      expiresAt: this._now() + this._ttl,
    };
    this._byUser.set(userId, challenge);
    return challenge;
  }

  /**
   * Consumes the challenge, or returns null.
   *
   * Consuming rather than checking: a challenge that survived its own use
   * could be answered twice, and the second answer would be a photo taken with
   * all the time in the world.
   */
  take(userId, challengeId) {
    const challenge = this._byUser.get(userId);
    if (!challenge) return null;
    if (challenge.expiresAt <= this._now()) {
      this._byUser.delete(userId);
      return null;
    }
    if (challenge.id !== challengeId) return null;
    this._byUser.delete(userId);
    return challenge;
  }

  sweep() {
    const now = this._now();
    for (const [userId, challenge] of this._byUser) {
      if (challenge.expiresAt <= now) this._byUser.delete(userId);
    }
  }
}
