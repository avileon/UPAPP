import { config } from './config.js';
import { nowIso, transaction } from './db/db.js';
import { hashSecret, newId, randomToken } from './lib/crypto.js';
import { orderedPair, RealityBadge } from './domain/rules.js';

/**
 * Every SQL statement in the server lives here.
 *
 * Routes deal in users and matches; this file deals in rows. Keeping the two
 * apart is what will make the eventual Postgres move a change to one file.
 */
export class Store {
  constructor(db) {
    this.db = db;
  }

  // -- users ---------------------------------------------------------------

  findUserByPhone(phone) {
    return this.db
      .prepare(`SELECT * FROM users WHERE phone = ? AND status = 'active'`)
      .get(phone);
  }

  findUser(id) {
    return this.db
      .prepare(`SELECT * FROM users WHERE id = ? AND status = 'active'`)
      .get(id);
  }

  createUser(phone) {
    const id = newId();
    const at = nowIso();
    this.db
      .prepare(
        `INSERT INTO users (id, phone, status, created_at) VALUES (?, ?, 'active', ?)`,
      )
      .run(id, phone, at);
    this.db
      .prepare(`INSERT INTO profiles (user_id, updated_at) VALUES (?, ?)`)
      .run(id, at);
    return this.findUser(id);
  }

  /**
   * Anonymise rather than delete outright: matches and reports the other side
   * still needs stay intact, while nothing identifying survives. A hard delete
   * follows within the retention window.
   */
  deleteUser(userId) {
    return transaction(this.db, () => {
      this.db
        .prepare(
          `UPDATE users
              SET status = 'deleted', phone = ?, birth_date = NULL,
                  gender = NULL, interested_in = NULL
            WHERE id = ?`,
        )
        .run(`deleted:${userId}`, userId);
      this.db
        .prepare(
          `UPDATE profiles
              SET first_name = '', bio_short = '', photo_primary = NULL,
                  photos = '[]', updated_at = ?
            WHERE user_id = ?`,
        )
        .run(nowIso(), userId);
      this.db.prepare(`DELETE FROM refresh_tokens WHERE user_id = ?`).run(userId);
      // A deleted account must stop being able to interrupt anyone's phone.
      this.db.prepare(`DELETE FROM push_subscriptions WHERE user_id = ?`).run(userId);
      this.db
        .prepare(`UPDATE matches SET status = 'unmatched' WHERE user_a = ? OR user_b = ?`)
        .run(userId, userId);
      return true;
    });
  }

  // -- profiles ------------------------------------------------------------

  findProfile(userId) {
    return this.db.prepare(`SELECT * FROM profiles WHERE user_id = ?`).get(userId);
  }

  saveProfile(userId, { firstName, bioShort, birthDate, gender, interestedIn }) {
    return transaction(this.db, () => {
      this.db
        .prepare(
          `UPDATE users SET birth_date = ?, gender = ?, interested_in = ? WHERE id = ?`,
        )
        .run(birthDate ?? null, gender ?? null, interestedIn ?? null, userId);
      this.db
        .prepare(
          `UPDATE profiles SET first_name = ?, bio_short = ?, updated_at = ? WHERE user_id = ?`,
        )
        .run(firstName ?? '', bioShort ?? '', nowIso(), userId);
      return { user: this.findUser(userId), profile: this.findProfile(userId) };
    });
  }

  acceptTerms(userId) {
    this.db
      .prepare(`UPDATE users SET terms_accepted_at = ? WHERE id = ?`)
      .run(nowIso(), userId);
  }

  /**
   * Drops one photo from a profile.
   *
   * `photo_primary` is repaired here rather than left dangling: a profile whose
   * primary key points at a file that no longer exists renders as a broken
   * image on every screen that shows that person.
   */
  removePhoto(userId, storageKey) {
    const profile = this.findProfile(userId);
    const photos = JSON.parse(profile?.photos ?? '[]');
    const index = photos.indexOf(storageKey);
    if (index === -1) return { photos, removed: false };
    photos.splice(index, 1);
    const primary = profile?.photo_primary === storageKey
      ? (photos[0] ?? null)
      : (profile?.photo_primary ?? null);
    this.db
      .prepare(
        `UPDATE profiles SET photos = ?, photo_primary = ?, updated_at = ?
          WHERE user_id = ?`,
      )
      .run(JSON.stringify(photos), primary, nowIso(), userId);
    return { photos, removed: true };
  }

  addPhoto(userId, storageKey) {
    const profile = this.findProfile(userId);
    const photos = JSON.parse(profile?.photos ?? '[]');
    if (photos.length >= config.maxPhotos) return { photos, added: false };
    photos.push(storageKey);
    this.db
      .prepare(
        `UPDATE profiles SET photos = ?, photo_primary = COALESCE(photo_primary, ?), updated_at = ?
          WHERE user_id = ?`,
      )
      .run(JSON.stringify(photos), storageKey, nowIso(), userId);
    return { photos, added: true };
  }

  // -- otp -----------------------------------------------------------------

  countRecentOtpRequests(phone, sinceIso) {
    const row = this.db
      .prepare(
        `SELECT COUNT(*) AS n FROM otp_requests WHERE phone = ? AND requested_at >= ?`,
      )
      .get(phone, sinceIso);
    return row?.n ?? 0;
  }

  recordOtpRequest(phone, codeHash, expiresAt) {
    const at = nowIso();
    transaction(this.db, () => {
      this.db
        .prepare(`INSERT INTO otp_requests (phone, requested_at) VALUES (?, ?)`)
        .run(phone, at);
      this.db
        .prepare(
          `INSERT INTO otp_codes (phone, code_hash, expires_at, attempts, created_at)
           VALUES (?, ?, ?, 0, ?)
           ON CONFLICT(phone) DO UPDATE SET
             code_hash = excluded.code_hash,
             expires_at = excluded.expires_at,
             attempts = 0,
             created_at = excluded.created_at`,
        )
        .run(phone, codeHash, expiresAt, at);
    });
  }

  findOtp(phone) {
    return this.db.prepare(`SELECT * FROM otp_codes WHERE phone = ?`).get(phone);
  }

  bumpOtpAttempts(phone) {
    this.db
      .prepare(`UPDATE otp_codes SET attempts = attempts + 1 WHERE phone = ?`)
      .run(phone);
  }

  clearOtp(phone) {
    this.db.prepare(`DELETE FROM otp_codes WHERE phone = ?`).run(phone);
  }

  // -- refresh tokens ------------------------------------------------------

  issueRefreshToken(userId) {
    const value = randomToken(32);
    const expiresAt = new Date(
      Date.now() + config.refreshTokenTtlSeconds * 1000,
    ).toISOString();
    this.db
      .prepare(
        `INSERT INTO refresh_tokens (token_hash, user_id, expires_at, created_at)
         VALUES (?, ?, ?, ?)`,
      )
      .run(hashSecret(value), userId, expiresAt, nowIso());
    return value;
  }

  /** Single use: the row is consumed whether or not it was still valid. */
  consumeRefreshToken(value) {
    const hash = hashSecret(value);
    const row = this.db
      .prepare(`SELECT * FROM refresh_tokens WHERE token_hash = ?`)
      .get(hash);
    if (!row) return null;
    this.db.prepare(`DELETE FROM refresh_tokens WHERE token_hash = ?`).run(hash);
    if (new Date(row.expires_at).getTime() <= Date.now()) return null;
    return row.user_id;
  }

  // -- safety --------------------------------------------------------------

  block(blockerId, blockedId) {
    return transaction(this.db, () => {
      this.db
        .prepare(
          `INSERT OR IGNORE INTO blocks (blocker_id, blocked_id, created_at) VALUES (?, ?, ?)`,
        )
        .run(blockerId, blockedId, nowIso());
      this.db
        .prepare(`DELETE FROM likes WHERE (from_user = ? AND to_user = ?) OR (from_user = ? AND to_user = ?)`)
        .run(blockerId, blockedId, blockedId, blockerId);
      const { userA, userB } = orderedPair(blockerId, blockedId);
      this.db
        .prepare(`UPDATE matches SET status = 'unmatched' WHERE user_a = ? AND user_b = ?`)
        .run(userA, userB);
      return true;
    });
  }

  /** True when either side has blocked the other. Blocks are symmetric here. */
  isBlockedEitherWay(a, b) {
    const row = this.db
      .prepare(
        `SELECT 1 FROM blocks
          WHERE (blocker_id = ? AND blocked_id = ?) OR (blocker_id = ? AND blocked_id = ?)
          LIMIT 1`,
      )
      .get(a, b, b, a);
    return row !== undefined;
  }

  blockedIds(userId) {
    return this.db
      .prepare(`SELECT blocked_id FROM blocks WHERE blocker_id = ?`)
      .all(userId)
      .map((r) => r.blocked_id);
  }

  report(reporterId, reportedId, category, notes) {
    this.db
      .prepare(
        `INSERT INTO reports (id, reporter_id, reported_id, category, notes, created_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
      )
      .run(newId(), reporterId, reportedId, category, notes ?? '', nowIso());
  }

  // -- likes and matches ---------------------------------------------------

  countRecentLikes(userId, sinceIso) {
    const row = this.db
      .prepare(`SELECT COUNT(*) AS n FROM likes WHERE from_user = ? AND created_at >= ?`)
      .get(userId, sinceIso);
    return row?.n ?? 0;
  }

  hasLiked(fromUser, toUser) {
    return (
      this.db
        .prepare(`SELECT 1 FROM likes WHERE from_user = ? AND to_user = ? LIMIT 1`)
        .get(fromUser, toUser) !== undefined
    );
  }

  findMatchByPair(a, b) {
    const { userA, userB } = orderedPair(a, b);
    return this.db
      .prepare(`SELECT * FROM matches WHERE user_a = ? AND user_b = ?`)
      .get(userA, userB);
  }

  /**
   * Records an UP and creates the match when — and only when — the reverse
   * like already exists.
   *
   * The whole thing runs in one transaction so that two devices pressing UP at
   * the same instant cannot both observe "no match yet" and both insert. The
   * unique index on the ordered pair is the backstop if they somehow do.
   */
  sendLike(fromUser, toUser) {
    return transaction(this.db, () => {
      if (this.hasLiked(fromUser, toUser)) {
        const existing = this.findMatchByPair(fromUser, toUser);
        return { outcome: 'duplicate', match: existing ?? null };
      }

      this.db
        .prepare(`INSERT INTO likes (from_user, to_user, created_at) VALUES (?, ?, ?)`)
        .run(fromUser, toUser, nowIso());

      if (!this.hasLiked(toUser, fromUser)) {
        return { outcome: 'recorded', match: null };
      }

      const existing = this.findMatchByPair(fromUser, toUser);
      if (existing) {
        if (existing.status !== 'active') {
          this.db
            .prepare(`UPDATE matches SET status = 'active' WHERE id = ?`)
            .run(existing.id);
        }
        return { outcome: 'matched', match: this.findMatchByPair(fromUser, toUser) };
      }

      const { userA, userB } = orderedPair(fromUser, toUser);
      const id = newId();
      this.db
        .prepare(
          `INSERT INTO matches (id, user_a, user_b, matched_at, status)
           VALUES (?, ?, ?, ?, 'active')`,
        )
        .run(id, userA, userB, nowIso());
      return { outcome: 'matched', match: this.db.prepare(`SELECT * FROM matches WHERE id = ?`).get(id) };
    });
  }

  removeLike(fromUser, toUser) {
    this.db
      .prepare(`DELETE FROM likes WHERE from_user = ? AND to_user = ?`)
      .run(fromUser, toUser);
  }

  listMatches(userId) {
    return this.db
      .prepare(
        `SELECT * FROM matches
          WHERE (user_a = ? OR user_b = ?) AND status = 'active'
          ORDER BY matched_at DESC`,
      )
      .all(userId, userId);
  }

  findMatch(matchId) {
    return this.db.prepare(`SELECT * FROM matches WHERE id = ?`).get(matchId);
  }

  unmatch(matchId) {
    this.db.prepare(`UPDATE matches SET status = 'unmatched' WHERE id = ?`).run(matchId);
  }

  // -- messages ------------------------------------------------------------

  listMessages(matchId) {
    return this.db
      .prepare(`SELECT * FROM messages WHERE match_id = ? ORDER BY created_at ASC`)
      .all(matchId);
  }

  addMessage(matchId, senderId, body) {
    const id = newId();
    this.db
      .prepare(
        `INSERT INTO messages (id, match_id, sender_id, body, created_at)
         VALUES (?, ?, ?, ?, ?)`,
      )
      .run(id, matchId, senderId, body, nowIso());
    return this.db.prepare(`SELECT * FROM messages WHERE id = ?`).get(id);
  }

  countMessages(matchId) {
    const row = this.db
      .prepare(`SELECT COUNT(*) AS n FROM messages WHERE match_id = ?`)
      .get(matchId);
    return row?.n ?? 0;
  }

  // -- reality feedback ----------------------------------------------------

  hasRealityAnswer(matchId, reviewerId) {
    return (
      this.db
        .prepare(
          `SELECT 1 FROM reality_feedback WHERE match_id = ? AND reviewer_id = ? LIMIT 1`,
        )
        .get(matchId, reviewerId) !== undefined
    );
  }

  addRealityAnswer(matchId, reviewerId, reviewedId, answer) {
    this.db
      .prepare(
        `INSERT INTO reality_feedback (match_id, reviewer_id, reviewed_id, answer, created_at)
         VALUES (?, ?, ?, ?, ?)`,
      )
      .run(matchId, reviewerId, reviewedId, answer, nowIso());
  }

  /**
   * Returns only the badge, never the counts.
   *
   * The tally exists in the database and must never leave it: showing "4 of 5
   * said yes" turns photo honesty into a score, which is the one thing this
   * feature is designed not to be.
   */
  /**
   * Records a browser's willingness to be interrupted.
   *
   * Keyed on the endpoint rather than the user, so the same browser
   * re-subscribing (which happens whenever the push service rotates it)
   * replaces its own row instead of accumulating dead ones. Re-pointing an
   * endpoint at a different user is the case that matters on a shared laptop:
   * the second person's notifications must not go to the first.
   */
  savePushSubscription(userId, { endpoint, p256dh, auth }) {
    this.db
      .prepare(
        `INSERT INTO push_subscriptions (endpoint, user_id, p256dh, auth, created_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(endpoint) DO UPDATE SET
           user_id = excluded.user_id,
           p256dh = excluded.p256dh,
           auth = excluded.auth,
           created_at = excluded.created_at`,
      )
      .run(endpoint, userId, p256dh, auth, nowIso());
    return true;
  }

  listPushSubscriptions(userId) {
    return this.db
      .prepare(
        `SELECT endpoint, p256dh, auth FROM push_subscriptions WHERE user_id = ?`,
      )
      .all(userId);
  }

  deletePushSubscription(endpoint) {
    this.db.prepare(`DELETE FROM push_subscriptions WHERE endpoint = ?`).run(endpoint);
    return true;
  }

  realityBadge(userId) {
    const row = this.db
      .prepare(
        `SELECT COUNT(*) AS total,
                SUM(CASE WHEN answer = 'yes' THEN 1 ELSE 0 END) AS positive
           FROM reality_feedback WHERE reviewed_id = ?`,
      )
      .get(userId);
    const total = row?.total ?? 0;
    const positive = row?.positive ?? 0;
    return RealityBadge.qualifies(total, positive);
  }
}
