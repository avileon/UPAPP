import { config } from '../config.js';
import { intentsMeet, normaliseIntent, normaliseNote } from './intent.js';
import { hashSecret, newId, randomToken } from '../lib/crypto.js';
import { distanceM } from '../lib/geo.js';

/**
 * Live sessions and the rotating BLE tokens that belong to them.
 *
 * Kept in memory on purpose. Everything here expires on its own within two
 * hours, so persisting it would mean writing rows whose only future is a
 * cleanup job that can fail quietly. Redis takes this over the moment there is
 * more than one server process — the interface below is what it has to
 * implement, and nothing outside this file touches the maps.
 *
 * The security property this file exists to enforce: a BLE token is an opaque
 * random string that resolves to a person only while its session is live, and
 * the raw token is never stored — only its hash. Observing a token off the air
 * therefore tells an attacker nothing, and replaying it after the session ends
 * resolves to nobody.
 */
/**
 * Turns whatever the user typed into a venue key, or null.
 *
 * Two people standing in the same bar will type `bar12`, `BAR 12` and
 * `bar-12`, and they have to land on the same key or the feature does not
 * work. Uppercase, drop everything that is not a letter or a digit, and
 * require enough characters that a typo is not a collision. Latin letters and
 * digits only: the key travels in a URL-ish payload and is compared exactly,
 * so a Hebrew code that survives one normalisation pass and not another would
 * silently split a room in two. The UI asks for a short code, not a name.
 */
export function normaliseVenue(raw) {
  if (typeof raw !== 'string') return null;
  const key = raw.toUpperCase().replace(/[^A-Z0-9]/g, '');
  if (key.length < 3 || key.length > 12) return null;
  return key;
}

export class PresenceStore {
  constructor({ now = () => Date.now() } = {}) {
    this._now = now;
    /** @type {Map<string, {id: string, userId: string, startedAt: number, expiresAt: number, venue: string|null}>} */
    this._sessionsByUser = new Map();
    /** @type {Map<string, {userId: string, sessionId: string, validUntil: number}>} */
    this._tokensByHash = new Map();
  }

  /**
   * Starts (or replaces) a user's live session and mints a first token batch.
   *
   * `options.venue` must already have been checked by the caller (QR + GPS);
   * this store trusts it. `options.position` puts the session in "area" mode:
   * it sees other area sessions within `config.area.radiusM`. The position is
   * held in memory for the session only and never leaves this file.
   *
   * Renewing in the same place (scanning the QR again inside the hour) keeps
   * the people this person hid: a hide lasts for the visit, not for a scan.
   */
  startLive(userId, durationSeconds, venueOrOptions = null, intent = null, note = '') {
    const options =
      venueOrOptions && typeof venueOrOptions === 'object'
        ? venueOrOptions
        : { venue: venueOrOptions, intent, note };
    const capped = Math.min(
      Math.max(Number(durationSeconds) || 0, 60),
      options.maxSeconds ?? config.live.maxDurationSeconds,
    );
    const venue = normaliseVenue(options.venue);
    const position = venue ? null : (options.position ?? null);
    const previous = this.activeSession(userId);
    const samePlace =
      previous &&
      previous.venue === venue &&
      Boolean(previous.position) === Boolean(position);
    this.stopLive(userId);

    const startedAt = this._now();
    const session = {
      id: newId(),
      userId,
      startedAt,
      expiresAt: startedAt + capped * 1000,
      venue,
      venueName: venue ? (options.venueName ?? venue) : null,
      position: position ? { lat: position.lat, lng: position.lng } : null,
      // Why they are here, and what they are doing. Both belong to the session
      // rather than the account: they are true for the next hour and then they
      // are not, which is exactly what makes them worth showing to a stranger.
      intent: normaliseIntent(options.intent),
      note: normaliseNote(options.note ?? ''),
      hidden: samePlace ? previous.hidden : new Set(),
      reminded: false,
    };
    this._sessionsByUser.set(userId, session);
    return { session, tokens: this.mintTokens(userId) };
  }

  /** Moves an area session. Ignored for venue sessions and when not live. */
  updatePosition(userId, position) {
    const session = this.activeSession(userId);
    if (!session || session.venue || !session.position || !position) return false;
    session.position = { lat: position.lat, lng: position.lng };
    return true;
  }

  /**
   * Hides someone for the rest of this visit.
   *
   * Not a block: the next time both are live in the same place, they see each
   * other again. One-way — the hidden person is not told, and still sees the
   * person who hid them.
   */
  hide(userId, otherId) {
    const session = this.activeSession(userId);
    if (!session) return false;
    session.hidden.add(otherId);
    return true;
  }

  hasHidden(userId, otherId) {
    return this.activeSession(userId)?.hidden.has(otherId) ?? false;
  }

  /**
   * Area sessions within the radius, same intent.
   *
   * Venue sessions are a closed room and are not mixed in: somebody who
   * scanned into a bar sees the bar.
   */
  areaPeers(userId) {
    const session = this.activeSession(userId);
    if (!session?.position) return [];
    const now = this._now();
    const peers = [];
    for (const [otherId, other] of this._sessionsByUser) {
      if (otherId === userId) continue;
      if (!other.position || other.expiresAt <= now) continue;
      if (!intentsMeet(other.intent, session.intent)) continue;
      if (distanceM(session.position, other.position) > config.area.radiusM) continue;
      peers.push(otherId);
    }
    return peers;
  }

  /**
   * Venue sessions whose hour is nearly over and that have not been told yet.
   * Marks them, so each session is reminded once.
   */
  takeDueReminders(beforeMs) {
    const now = this._now();
    const due = [];
    for (const session of this._sessionsByUser.values()) {
      if (!session.venue || session.reminded) continue;
      if (session.expiresAt <= now) continue;
      if (session.expiresAt - now > beforeMs) continue;
      session.reminded = true;
      due.push(session);
    }
    return due;
  }

  /**
   * Everyone else currently live under the same venue key.
   *
   * This is the presence fallback, and it is a product decision rather than a
   * stand-in for BLE: in a crowded room the radio under-discovers badly, which
   * is exactly where the product is supposed to work. A venue key is coarse by
   * construction — it is a label two people agree on, it holds no coordinates,
   * and it dies with the session.
   */
  venuePeers(userId) {
    const session = this.activeSession(userId);
    if (!session?.venue) return [];
    const peers = [];
    for (const [otherId, other] of this._sessionsByUser) {
      if (otherId === userId) continue;
      if (other.venue !== session.venue) continue;
      if (other.expiresAt <= this._now()) continue;
      // Same room *and* same reason. A room is a place; an intent is why you
      // walked into it, and mixing the two is what produced the awkwardness
      // this app is supposed to remove.
      if (!intentsMeet(other.intent, session.intent)) continue;
      peers.push(otherId);
    }
    return peers;
  }

  /**
   * Rooms with people in them right now, for one intent.
   *
   * Typing a code is a fine way to join a room you were told about and a
   * terrible way to find one at all — a person standing in a bar has nothing
   * to type. This is the answer: the rooms that already exist, with a count.
   *
   * Two deliberate limits. Only rooms holding at least two people are listed,
   * because a room of one is a person, and publishing "AVI42: 1 person" turns
   * a private label into a way to find somebody. And only counts are returned:
   * no names, no ids, nothing that survives the session.
   */
  rooms(intent, { minimum = 2, limit = 20 } = {}) {
    const wanted = normaliseIntent(intent);
    const counts = new Map();
    const now = this._now();
    for (const session of this._sessionsByUser.values()) {
      if (!session.venue) continue;
      if (session.expiresAt <= now) continue;
      if (!intentsMeet(session.intent, wanted)) continue;
      counts.set(session.venue, (counts.get(session.venue) ?? 0) + 1);
    }
    return [...counts.entries()]
      .filter(([, people]) => people >= minimum)
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      .slice(0, limit)
      .map(([code, people]) => ({ code, people }));
  }

  stopLive(userId) {
    const existing = this._sessionsByUser.get(userId);
    if (!existing) return false;
    this._sessionsByUser.delete(userId);
    for (const [hash, token] of this._tokensByHash) {
      if (token.sessionId === existing.id) this._tokensByHash.delete(hash);
    }
    return true;
  }

  activeSession(userId) {
    const session = this._sessionsByUser.get(userId);
    if (!session) return null;
    if (session.expiresAt <= this._now()) {
      this.stopLive(userId);
      return null;
    }
    return session;
  }

  isLive(userId) {
    return this.activeSession(userId) !== null;
  }

  /**
   * Issues a fresh batch of tokens for the caller's live session.
   *
   * The device advertises one at a time and rotates; overlapping validity
   * windows mean a rotation never leaves a gap where the device is invisible.
   */
  mintTokens(userId) {
    const session = this.activeSession(userId);
    if (!session) return [];
    const now = this._now();
    const ttl = config.live.tokenTtlSeconds * 1000;
    const tokens = [];
    for (let i = 0; i < config.live.tokenBatchSize; i++) {
      const value = randomToken(16);
      const validFrom = now + i * ttl;
      const validUntil = Math.min(validFrom + ttl * 2, session.expiresAt);
      if (validFrom >= session.expiresAt) break;
      this._tokensByHash.set(hashSecret(value), {
        userId,
        sessionId: session.id,
        validUntil,
      });
      tokens.push({
        token: value,
        validFrom: new Date(validFrom).toISOString(),
        validUntil: new Date(validUntil).toISOString(),
      });
    }
    return tokens;
  }

  /**
   * Turns an observed token into a user id — or null.
   *
   * Null covers every failure identically on purpose: unknown token, expired
   * token, ended session. A caller must not be able to tell them apart.
   */
  resolveToken(token) {
    const entry = this._tokensByHash.get(hashSecret(token));
    if (!entry) return null;
    const now = this._now();
    if (entry.validUntil <= now) {
      this._tokensByHash.delete(hashSecret(token));
      return null;
    }
    const session = this._sessionsByUser.get(entry.userId);
    if (!session || session.id !== entry.sessionId || session.expiresAt <= now) {
      return null;
    }
    return entry.userId;
  }

  /** Drops everything that has expired. Cheap; safe to call on a timer. */
  sweep() {
    const now = this._now();
    for (const [userId, session] of this._sessionsByUser) {
      if (session.expiresAt <= now) this.stopLive(userId);
    }
    for (const [hash, token] of this._tokensByHash) {
      if (token.validUntil <= now) this._tokensByHash.delete(hash);
    }
  }

  get liveUserCount() {
    this.sweep();
    return this._sessionsByUser.size;
  }
}
