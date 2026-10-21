/**
 * Distances on the earth, and what counts as a usable phone location.
 *
 * Nothing here stores anything. A position goes in, a yes/no or a number of
 * metres comes out, and the caller throws the position away — UP knows you
 * are in the room, not where you are.
 */

const EARTH_RADIUS_M = 6_371_000;
const rad = (deg) => (deg * Math.PI) / 180;

/** Great-circle distance in metres. */
export function distanceM(a, b) {
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}

/**
 * `{lat, lng, accuracy}` from a request body, or null.
 *
 * Null for anything missing, out of range, or less accurate than
 * `maxAccuracy` — a "fix" with a three-kilometre error circle says nothing
 * about which bar somebody is in.
 */
export function readPosition(body, maxAccuracy) {
  const lat = Number(body?.lat);
  const lng = Number(body?.lng);
  const accuracy = Number(body?.accuracy ?? 0);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  if (Math.abs(lat) > 90 || Math.abs(lng) > 180) return null;
  if (lat === 0 && lng === 0) return null;
  if (!Number.isFinite(accuracy) || accuracy < 0) return null;
  if (accuracy > maxAccuracy) return null;
  return { lat, lng, accuracy };
}

/**
 * Is this phone inside the venue?
 *
 * The phone's own error estimate is forgiven up to `maxCredit` metres: GPS
 * indoors is honestly fuzzy, and refusing someone standing at the bar because
 * their fix drifted forty metres into the street would make the feature
 * useless exactly where it is used.
 */
export function insideVenue(position, venue, maxCredit) {
  const allowed = venue.radius_m + Math.min(position.accuracy, maxCredit);
  return distanceM(position, venue) <= allowed;
}
