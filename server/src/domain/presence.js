import { config } from '../config.js';
import { hashSecret, newId, randomToken } from '../lib/crypto.js';

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
export class PresenceStore {
  constructor({ now = () => Date.now() } = {}) {
    this._now = now;
    /** @type {Map<string, {id: string, userId: string, startedAt: number, expiresAt: number}>} */
    this._sessionsByUser = new Map();
    /** @type {Map<string, {userId: string, sessionId: string, validUntil: number}>} */
    this._tokensByHash = new Map();
  }

  /** Starts (or replaces) a user's live session and mints a first token batch. */
  startLive(userId, durationSeconds) {
    const capped = Math.min(
      Math.max(Number(durationSeconds) || 0, 60),
      config.live.maxDurationSeconds,
    );
    this.stopLive(userId);

    const startedAt = this._now();
    const session = {
      id: newId(),
      userId,
      startedAt,
      expiresAt: startedAt + capped * 1000,
    };
    this._sessionsByUser.set(userId, session);
    return { session, tokens: this.mintTokens(userId) };
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
