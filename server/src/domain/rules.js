import { config } from '../config.js';

/**
 * The product rules that must mean the same thing on every surface.
 *
 * These are deliberately pure functions with no database and no I/O: the
 * Flutter client implements the same rules in Dart, and the only way to keep
 * two implementations honest is to state each rule once, plainly, and test it
 * on both sides.
 */

/** Age from an ISO birth date, or null when it is missing or unparseable. */
export function ageFromBirthDate(birthDate, now = new Date()) {
  if (typeof birthDate !== 'string') return null;
  const born = new Date(birthDate);
  if (Number.isNaN(born.getTime())) return null;
  let age = now.getUTCFullYear() - born.getUTCFullYear();
  const monthDiff = now.getUTCMonth() - born.getUTCMonth();
  if (monthDiff < 0 || (monthDiff === 0 && now.getUTCDate() < born.getUTCDate())) {
    age -= 1;
  }
  return age;
}

export function isOfAge(birthDate, now = new Date()) {
  const age = ageFromBirthDate(birthDate, now);
  return age !== null && age >= config.minimumAge;
}

/**
 * A match row always stores the smaller id first. That is what turns the
 * unique index into a real one-match-per-pair guarantee: two simultaneous
 * inserts from opposite directions collide on the same key instead of
 * producing two rows.
 */
export function orderedPair(a, b) {
  return a < b ? { userA: a, userB: b } : { userA: b, userB: a };
}

/**
 * Does what one side is looking for admit the other side's gender?
 *
 * Both directions must agree — discovery is mutual or it does not happen.
 */
export function preferenceAdmits(interestedIn, gender) {
  if (interestedIn === 'everyone' || interestedIn == null) return true;
  if (interestedIn === 'men') return gender === 'male';
  if (interestedIn === 'women') return gender === 'female';
  return true;
}

export function mutuallyCompatible(viewer, candidate) {
  return (
    preferenceAdmits(viewer.interested_in, candidate.gender) &&
    preferenceAdmits(candidate.interested_in, viewer.gender)
  );
}

export const REALITY_ANSWERS = Object.freeze(['yes', 'somewhat', 'no']);

/**
 * Reality Verified.
 *
 * Only `yes` counts toward the badge. `somewhat` is neutral rather than
 * negative — people photograph differently, and a soft answer should not
 * punish anyone. Below the minimum there is no badge at all, because a single
 * opinion is noise and showing it would make the badge gameable.
 */
export const RealityBadge = Object.freeze({
  minimumAnswers: 3,
  positiveThreshold: 0.7,
  qualifies(total, positive) {
    if (total < RealityBadge.minimumAnswers) return false;
    return positive / total >= RealityBadge.positiveThreshold;
  },
});
