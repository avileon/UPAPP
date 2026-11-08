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
      // The face goes with the account, immediately — not at the hard delete.
      this.db.prepare(`DELETE FROM face_templates WHERE user_id = ?`).run(userId);
      this.db.prepare(`DELETE FROM photo_checks WHERE user_id = ?`).run(userId);
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

  /**
   * Makes one of the person's photos the first one — the one everybody sees.
   *
   * The order of `photos` *is* the display order everywhere, so "primary" is
   * stored as position zero as well as in `photo_primary`; a screen that only
   * reads the array still gets it right.
   */
  setPrimaryPhoto(userId, storageKey) {
    const profile = this.findProfile(userId);
    const photos = JSON.parse(profile?.photos ?? '[]');
    const index = photos.indexOf(storageKey);
    if (index === -1) return { photos, updated: false };
    photos.splice(index, 1);
    photos.unshift(storageKey);
    this.db
      .prepare(
        `UPDATE profiles SET photos = ?, photo_primary = ?, updated_at = ? WHERE user_id = ?`,
      )
      .run(JSON.stringify(photos), storageKey, nowIso(), userId);
    return { photos, updated: true };
  }

  // -- photo face checks -----------------------------------------------------

  setPhotoCheck(userId, storageKey, faceMatch, score = null) {
    this.db
      .prepare(
        `INSERT INTO photo_checks (storage_key, user_id, face_match, score, checked_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(storage_key) DO UPDATE SET
           face_match = excluded.face_match,
           score = excluded.score,
           checked_at = excluded.checked_at`,
      )
      .run(storageKey, userId, faceMatch, score, nowIso());
  }

  /** `{ key: status }` for one person's photos. Missing = never checked. */
  photoChecks(userId) {
    const rows = this.db
      .prepare(`SELECT storage_key, face_match FROM photo_checks WHERE user_id = ?`)
      .all(userId);
    return Object.fromEntries(rows.map((r) => [r.storage_key, r.face_match]));
  }

  removePhotoCheck(storageKey) {
    this.db.prepare(`DELETE FROM photo_checks WHERE storage_key = ?`).run(storageKey);
  }

  pendingPhotoReviews(limit = 50) {
    return this.db
      .prepare(
        `SELECT c.storage_key, c.user_id, c.score, c.checked_at, p.first_name
           FROM photo_checks c
           LEFT JOIN profiles p ON p.user_id = c.user_id
          WHERE c.face_match = 'review'
          ORDER BY c.checked_at ASC
          LIMIT ?`,
      )
      .all(limit);
  }

  findPhotoCheck(storageKey) {
    return (
      this.db.prepare(`SELECT * FROM photo_checks WHERE storage_key = ?`).get(storageKey) ??
      null
    );
  }

  // -- face templates and consent -------------------------------------------

  recordBiometricConsent(userId) {
    this.db
      .prepare(`UPDATE users SET biometric_consent_at = ? WHERE id = ?`)
      .run(nowIso(), userId);
  }

  saveFaceTemplate(userId, sealed, model) {
    this.db
      .prepare(
        `INSERT INTO face_templates (user_id, embedding, model, created_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(user_id) DO UPDATE SET
           embedding = excluded.embedding,
           model = excluded.model,
           created_at = excluded.created_at`,
      )
      .run(userId, sealed, model, nowIso());
  }

  findFaceTemplate(userId) {
    return (
      this.db.prepare(`SELECT * FROM face_templates WHERE user_id = ?`).get(userId) ?? null
    );
  }

  /**
   * Forgets the face. The badge goes with it: a live-verified badge is a
   * claim about a template that no longer exists.
   */
  deleteBiometrics(userId) {
    return transaction(this.db, () => {
      this.db.prepare(`DELETE FROM face_templates WHERE user_id = ?`).run(userId);
      this.db
        .prepare(`UPDATE users SET biometric_consent_at = NULL WHERE id = ?`)
        .run(userId);
      this.db
        .prepare(
          `UPDATE verifications SET status = 'revoked'
            WHERE user_id = ? AND method = 'live' AND status = 'approved'`,
        )
        .run(userId);
      return true;
    });
  }

  /** Live attempts in the last day — the rate limit on face checks. */
  countRecentLiveAttempts(userId, sinceIso) {
    const row = this.db
      .prepare(
        `SELECT COUNT(*) AS n FROM verifications
          WHERE user_id = ? AND method = 'live' AND created_at >= ?`,
      )
      .get(userId, sinceIso);
    return row?.n ?? 0;
  }

  /**
   * Records the outcome of an automatic live check.
   *
   * `approved` and `rejected` are final rows with no file. `pending` keeps the
   * centre frame for a human, exactly like a manual selfie.
   */
  recordLiveVerification(userId, { status, score = null, reason = null, storageKey = null }) {
    return transaction(this.db, () => {
      let replacedKey = null;
      if (status === 'pending') {
        this.#startReviewGrace(userId);
        const previous = this.db
          .prepare(
            `SELECT id, storage_key FROM verifications WHERE user_id = ? AND status = 'pending'`,
          )
          .get(userId);
        if (previous) {
          this.db.prepare(`DELETE FROM verifications WHERE id = ?`).run(previous.id);
          replacedKey = previous.storage_key;
        }
      }
      const id = newId();
      const at = nowIso();
      this.db
        .prepare(
          `INSERT INTO verifications
             (id, user_id, status, pose, storage_key, created_at, decided_at, method, score, reason)
           VALUES (?, ?, ?, 'live', ?, ?, ?, 'live', ?, ?)`,
        )
        .run(
          id,
          userId,
          status,
          storageKey,
          at,
          status === 'pending' ? null : at,
          score,
          reason,
        );
      return { id, replacedKey };
    });
  }

  /** How this person got their badge, if they have one: 'live' | 'manual' | null. */
  verificationMethod(userId) {
    const row = this.db
      .prepare(
        `SELECT method FROM verifications WHERE user_id = ? AND status = 'approved'
          ORDER BY CASE method WHEN 'live' THEN 0 ELSE 1 END LIMIT 1`,
      )
      .get(userId);
    return row?.method ?? null;
  }

  // -- venues ----------------------------------------------------------------

  findVenue(code) {
    return this.db.prepare(`SELECT * FROM venues WHERE code = ?`).get(code) ?? null;
  }

  listVenues() {
    return this.db.prepare(`SELECT * FROM venues ORDER BY created_at DESC`).all();
  }

  createVenue({ code, name, lat, lng, radiusM }) {
    this.db
      .prepare(
        `INSERT INTO venues (code, name, lat, lng, radius_m, active, created_at)
         VALUES (?, ?, ?, ?, ?, 1, ?)`,
      )
      .run(code, name, lat, lng, radiusM, nowIso());
    return this.findVenue(code);
  }

  /**
   * A place that signed itself up from /business. It exists from the first
   * second — so its owner can see the sticker it will get — but stays
   * inactive until the operator approves it.
   */
  createVenueApplication({ code, name, lat, lng, radiusM, kind, address, contactName, contactPhone, contactEmail, ownerTokenHash }) {
    this.db
      .prepare(
        `INSERT INTO venues (code, name, lat, lng, radius_m, active, created_at,
           status, kind, address, contact_name, contact_phone, contact_email, owner_token_hash)
         VALUES (?, ?, ?, ?, ?, 0, ?, 'pending', ?, ?, ?, ?, ?, ?)`,
      )
      .run(code, name, lat, lng, radiusM, nowIso(), kind, address, contactName, contactPhone, contactEmail, ownerTokenHash);
    return this.findVenue(code);
  }

  findVenueByOwnerToken(hash) {
    return this.db.prepare(`SELECT * FROM venues WHERE owner_token_hash = ?`).get(hash) ?? null;
  }

  setVenueStatus(code, status, active) {
    return (
      this.db
        .prepare(`UPDATE venues SET status = ?, active = ? WHERE code = ?`)
        .run(status, active ? 1 : 0, code).changes > 0
    );
  }

  updateVenue(code, fields) {
    const current = this.findVenue(code);
    if (!current) return null;
    const next = { ...current, ...fields };
    this.db
      .prepare(
        `UPDATE venues SET name = ?, lat = ?, lng = ?, radius_m = ?, active = ? WHERE code = ?`,
      )
      .run(next.name, next.lat, next.lng, next.radius_m, next.active ? 1 : 0, code);
    return this.findVenue(code);
  }

  /** Sets the place's logo (a media key) and returns the one it replaced. */
  setVenueLogo(code, key) {
    const current = this.findVenue(code);
    if (!current) return { found: false, previous: null };
    this.db.prepare(`UPDATE venues SET logo_key = ? WHERE code = ?`).run(key, code);
    return { found: true, previous: current.logo_key ?? null };
  }

  deleteVenue(code) {
    return this.db.prepare(`DELETE FROM venues WHERE code = ?`).run(code).changes > 0;
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

  /** Lifts a block. Nothing that the block deleted (UPs, a match) comes back. */
  unblock(blockerId, blockedId) {
    return (
      this.db
        .prepare(`DELETE FROM blocks WHERE blocker_id = ? AND blocked_id = ?`)
        .run(blockerId, blockedId).changes > 0
    );
  }

  /** The people this user blocked, newest first, with what it takes to show them. */
  listBlocked(userId) {
    return this.db
      .prepare(
        `SELECT b.blocked_id AS id, b.created_at, p.first_name, p.photos
           FROM blocks b
           LEFT JOIN profiles p ON p.user_id = b.blocked_id
          WHERE b.blocker_id = ?
          ORDER BY b.created_at DESC`,
      )
      .all(userId);
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

  // -- the per-place UP limit ---------------------------------------------

  countVenueUps(fromUser, venue, night) {
    const row = this.db
      .prepare(`SELECT COUNT(*) AS n FROM venue_ups WHERE from_user = ? AND venue = ? AND night = ?`)
      .get(fromUser, venue, night);
    return row?.n ?? 0;
  }

  /**
   * Takes one of tonight's UPs at [venue], unless they are spent.
   *
   * Count and insert in one transaction, so two UPs pressed at the same
   * instant cannot both see "3 used" and both go through. Spending on the same
   * person twice is a no-op that succeeds — it was already paid for.
   */
  trySpendVenueUp(fromUser, toUser, venue, night, limit) {
    return transaction(this.db, () => {
      const already = this.db
        .prepare(
          `SELECT 1 FROM venue_ups WHERE from_user = ? AND to_user = ? AND venue = ? AND night = ?`,
        )
        .get(fromUser, toUser, venue, night);
      if (already) return true;
      if (this.countVenueUps(fromUser, venue, night) >= limit) return false;
      this.db
        .prepare(
          `INSERT INTO venue_ups (from_user, to_user, venue, night, created_at) VALUES (?, ?, ?, ?, ?)`,
        )
        .run(fromUser, toUser, venue, night, nowIso());
      return true;
    });
  }

  /** Gives a slot back — only when the UP it paid for never got recorded. */
  refundVenueUp(fromUser, toUser, venue, night) {
    this.db
      .prepare(`DELETE FROM venue_ups WHERE from_user = ? AND to_user = ? AND venue = ? AND night = ?`)
      .run(fromUser, toUser, venue, night);
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

  // -- after the chat -------------------------------------------------------

  /** userId -> choice for one match. */
  matchChoices(matchId) {
    const rows = this.db
      .prepare(`SELECT user_id, choice FROM match_decisions WHERE match_id = ?`)
      .all(matchId);
    return Object.fromEntries(rows.map((r) => [r.user_id, r.choice]));
  }

  /** Records (or changes) one person's choice. */
  setMatchChoice(matchId, userId, choice) {
    this.db
      .prepare(
        `INSERT INTO match_decisions (match_id, user_id, choice, created_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT (match_id, user_id) DO UPDATE SET choice = excluded.choice,
           created_at = excluded.created_at`,
      )
      .run(matchId, userId, choice, nowIso());
  }

  /** Active matches of [userId] made since [sinceIso], newest first. */
  recentActiveMatches(userId, sinceIso) {
    return this.db
      .prepare(
        `SELECT * FROM matches
          WHERE (user_a = ? OR user_b = ?) AND status = 'active' AND matched_at >= ?
          ORDER BY matched_at DESC`,
      )
      .all(userId, userId, sinceIso);
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

  /**
   * Records a submitted selfie, replacing any earlier undecided one.
   *
   * Replacing rather than queueing: a person who submits twice has decided the
   * first attempt was bad, and a reviewer should never be asked to judge a
   * photo its own subject has already given up on. Returns the storage key of
   * the replaced attempt so the caller can delete the file.
   */
  submitVerification(userId, { pose, storageKey }) {
    return transaction(this.db, () => {
      this.#startReviewGrace(userId);
      const previous = this.db
        .prepare(
          `SELECT id, storage_key FROM verifications
            WHERE user_id = ? AND status = 'pending'`,
        )
        .get(userId);
      if (previous) {
        this.db.prepare(`DELETE FROM verifications WHERE id = ?`).run(previous.id);
      }
      const id = newId();
      this.db
        .prepare(
          `INSERT INTO verifications (id, user_id, status, pose, storage_key, created_at)
           VALUES (?, ?, 'pending', ?, ?, ?)`,
        )
        .run(id, userId, pose, storageKey, nowIso());
      return { id, replacedKey: previous?.storage_key ?? null };
    });
  }

  /**
   * Starts the waiting-for-a-human window, once per person.
   *
   * COALESCE rather than overwrite: resubmitting while pending must not buy
   * another 24 hours.
   */
  #startReviewGrace(userId) {
    this.db
      .prepare(`UPDATE users SET review_grace_from = COALESCE(review_grace_from, ?) WHERE id = ?`)
      .run(nowIso(), userId);
  }

  /** The most recent attempt, whatever became of it. */
  latestVerification(userId) {
    return (
      this.db
        .prepare(
          `SELECT * FROM verifications WHERE user_id = ?
            ORDER BY created_at DESC LIMIT 1`,
        )
        .get(userId) ?? null
    );
  }

  /** Has this person ever been approved? An approval does not expire. */
  isSelfieVerified(userId) {
    const row = this.db
      .prepare(
        `SELECT 1 FROM verifications WHERE user_id = ? AND status = 'approved' LIMIT 1`,
      )
      .get(userId);
    return Boolean(row);
  }

  /** The review queue, oldest first: whoever waited longest is looked at first. */
  pendingVerifications(limit = 50) {
    return this.db
      .prepare(
        `SELECT v.id, v.user_id, v.pose, v.storage_key, v.created_at,
                v.method, v.score, v.reason,
                p.first_name, p.photos
           FROM verifications v
           LEFT JOIN profiles p ON p.user_id = v.user_id
          WHERE v.status = 'pending'
          ORDER BY v.created_at ASC
          LIMIT ?`,
      )
      .all(limit);
  }

  findVerification(id) {
    return this.db.prepare(`SELECT * FROM verifications WHERE id = ?`).get(id) ?? null;
  }

  /**
   * Records the verdict and forgets the photograph.
   *
   * Clearing `storage_key` in the same transaction as the decision is what
   * makes "the selfie is deleted when it is decided" a property of the data
   * rather than a promise in a comment — the row can never again point at a
   * file. Returns the key so the caller can remove it from disk.
   */
  decideVerification(id, status) {
    return transaction(this.db, () => {
      const row = this.db
        .prepare(`SELECT * FROM verifications WHERE id = ?`)
        .get(id);
      if (!row || row.status !== 'pending') return null;
      this.db
        .prepare(
          `UPDATE verifications SET status = ?, decided_at = ?, storage_key = NULL
            WHERE id = ?`,
        )
        .run(status, nowIso(), id);
      return { key: row.storage_key, userId: row.user_id };
    });
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

  // -- operator ------------------------------------------------------------

  /** Cheap heartbeat: written at most once a minute per person. */
  touchLastSeen(userId, at = nowIso()) {
    this.db
      .prepare(
        `UPDATE users SET last_seen_at = ?
          WHERE id = ? AND (last_seen_at IS NULL OR last_seen_at < ?)`,
      )
      .run(at, userId, new Date(Date.parse(at) - 60_000).toISOString());
  }

  /**
   * Every account with the numbers the operator scans for.
   *
   * One query with correlated counts, all of it on indexed columns. Fine for
   * thousands of accounts; at real scale this becomes a paged, filtered query.
   */
  adminUsers() {
    return this.db
      .prepare(
        `SELECT u.id, u.phone, u.birth_date, u.gender, u.interested_in, u.status,
                u.created_at, u.last_seen_at, u.suspended_at, u.suspended_reason,
                u.review_grace_from, u.terms_accepted_at,
                p.first_name, p.bio_short, p.photo_primary, p.photos,
                (SELECT COUNT(*) FROM likes WHERE from_user = u.id) AS ups_sent,
                (SELECT COUNT(*) FROM likes WHERE to_user = u.id) AS ups_received,
                (SELECT COUNT(*) FROM matches
                  WHERE (user_a = u.id OR user_b = u.id) AND status = 'active') AS matches,
                (SELECT COUNT(*) FROM messages WHERE sender_id = u.id) AS messages_sent,
                (SELECT COUNT(*) FROM reports WHERE reported_id = u.id) AS reports_against,
                (SELECT COUNT(*) FROM reports
                  WHERE reported_id = u.id AND resolved_at IS NULL) AS reports_open,
                (SELECT COUNT(*) FROM blocks WHERE blocked_id = u.id) AS blocked_by,
                (SELECT COUNT(*) FROM push_subscriptions WHERE user_id = u.id) AS devices,
                (SELECT status FROM verifications WHERE user_id = u.id
                  ORDER BY created_at DESC LIMIT 1) AS latest_verification,
                EXISTS (SELECT 1 FROM verifications
                  WHERE user_id = u.id AND status = 'approved') AS verified
           FROM users u
           LEFT JOIN profiles p ON p.user_id = u.id
          ORDER BY u.created_at DESC`,
      )
      .all();
  }

  adminUser(userId) {
    return this.adminUsers().find((u) => u.id === userId) ?? null;
  }

  adminStats() {
    const day = new Date(Date.now() - 24 * 3600_000).toISOString();
    const week = new Date(Date.now() - 7 * 24 * 3600_000).toISOString();
    const one = (sql, ...args) => this.db.prepare(sql).get(...args)?.n ?? 0;
    return {
      users: one(`SELECT COUNT(*) AS n FROM users WHERE status = 'active'`),
      newDay: one(`SELECT COUNT(*) AS n FROM users WHERE status = 'active' AND created_at >= ?`, day),
      newWeek: one(`SELECT COUNT(*) AS n FROM users WHERE status = 'active' AND created_at >= ?`, week),
      activeDay: one(`SELECT COUNT(*) AS n FROM users WHERE status = 'active' AND last_seen_at >= ?`, day),
      verified: one(
        `SELECT COUNT(DISTINCT v.user_id) AS n FROM verifications v
           JOIN users u ON u.id = v.user_id AND u.status = 'active'
          WHERE v.status = 'approved'`,
      ),
      pendingVerifications: one(`SELECT COUNT(*) AS n FROM verifications WHERE status = 'pending'`),
      suspended: one(`SELECT COUNT(*) AS n FROM users WHERE status = 'active' AND suspended_at IS NOT NULL`),
      matches: one(`SELECT COUNT(*) AS n FROM matches WHERE status = 'active'`),
      matchesWeek: one(`SELECT COUNT(*) AS n FROM matches WHERE matched_at >= ?`, week),
      upsDay: one(`SELECT COUNT(*) AS n FROM likes WHERE created_at >= ?`, day),
      messagesDay: one(`SELECT COUNT(*) AS n FROM messages WHERE created_at >= ?`, day),
      openReports: one(`SELECT COUNT(*) AS n FROM reports WHERE resolved_at IS NULL`),
      pendingVenues: one(`SELECT COUNT(*) AS n FROM venues WHERE status = 'pending'`),
    };
  }

  /** Who they matched with and how much was said — never what was said. */
  adminMatches(userId) {
    return this.db
      .prepare(
        `SELECT m.id, m.matched_at, m.status,
                CASE WHEN m.user_a = ? THEN m.user_b ELSE m.user_a END AS other_id,
                p.first_name AS other_name,
                (SELECT COUNT(*) FROM messages WHERE match_id = m.id AND sender_id = ?) AS mine,
                (SELECT COUNT(*) FROM messages WHERE match_id = m.id AND sender_id != ?) AS theirs,
                (SELECT MAX(created_at) FROM messages WHERE match_id = m.id) AS last_message_at
           FROM matches m
           LEFT JOIN profiles p
             ON p.user_id = CASE WHEN m.user_a = ? THEN m.user_b ELSE m.user_a END
          WHERE m.user_a = ? OR m.user_b = ?
          ORDER BY m.matched_at DESC`,
      )
      .all(userId, userId, userId, userId, userId, userId);
  }

  adminVerifications(userId) {
    return this.db
      .prepare(
        `SELECT id, status, method, pose, score, reason, created_at, decided_at,
                storage_key IS NOT NULL AS has_selfie
           FROM verifications WHERE user_id = ? ORDER BY created_at DESC`,
      )
      .all(userId);
  }

  listReports({ userId = null, includeResolved = false } = {}) {
    return this.db
      .prepare(
        `SELECT r.*, a.first_name AS reporter_name, b.first_name AS reported_name
           FROM reports r
           LEFT JOIN profiles a ON a.user_id = r.reporter_id
           LEFT JOIN profiles b ON b.user_id = r.reported_id
          WHERE (? IS NULL OR r.reported_id = ? OR r.reporter_id = ?)
            AND (? = 1 OR r.resolved_at IS NULL)
          ORDER BY r.created_at DESC
          LIMIT 500`,
      )
      .all(userId, userId, userId, includeResolved ? 1 : 0);
  }

  resolveReport(id, resolved = true) {
    return (
      this.db
        .prepare(`UPDATE reports SET resolved_at = ? WHERE id = ?`)
        .run(resolved ? nowIso() : null, id).changes > 0
    );
  }

  /** Locks the account and signs every device out. Reversible. */
  suspendUser(userId, reason = '') {
    return transaction(this.db, () => {
      const changed = this.db
        .prepare(
          `UPDATE users SET suspended_at = ?, suspended_reason = ?
            WHERE id = ? AND status = 'active'`,
        )
        .run(nowIso(), reason, userId).changes;
      if (!changed) return false;
      this.db.prepare(`DELETE FROM refresh_tokens WHERE user_id = ?`).run(userId);
      return true;
    });
  }

  unsuspendUser(userId) {
    return (
      this.db
        .prepare(`UPDATE users SET suspended_at = NULL, suspended_reason = NULL WHERE id = ?`)
        .run(userId).changes > 0
    );
  }

  /**
   * The operator vouches for this person. Closes whatever is waiting and
   * leaves an approved manual row, which is what the badge reads.
   * Returns the selfie keys that no longer need to exist.
   */
  approveVerificationManually(userId) {
    return transaction(this.db, () => {
      const at = nowIso();
      const waiting = this.db
        .prepare(`SELECT id, storage_key FROM verifications WHERE user_id = ? AND status = 'pending'`)
        .all(userId);
      this.db
        .prepare(
          `UPDATE verifications SET status = 'approved', decided_at = ?, storage_key = NULL
            WHERE user_id = ? AND status = 'pending'`,
        )
        .run(at, userId);
      if (!waiting.length) {
        this.db
          .prepare(
            `INSERT INTO verifications (id, user_id, status, pose, created_at, decided_at, method, reason)
             VALUES (?, ?, 'approved', 'operator', ?, ?, 'manual', 'operator')`,
          )
          .run(newId(), userId, at, at);
      }
      return waiting.map((w) => w.storage_key).filter(Boolean);
    });
  }

  /** Takes the badge away. They are back to "not verified", grace over. */
  revokeVerification(userId) {
    return transaction(this.db, () => {
      const waiting = this.db
        .prepare(`SELECT storage_key FROM verifications WHERE user_id = ? AND status = 'pending'`)
        .all(userId);
      this.db
        .prepare(
          `UPDATE verifications SET status = 'revoked', decided_at = COALESCE(decided_at, ?),
                  storage_key = NULL
            WHERE user_id = ? AND status IN ('approved', 'pending')`,
        )
        .run(nowIso(), userId);
      this.db.prepare(`DELETE FROM face_templates WHERE user_id = ?`).run(userId);
      return waiting.map((w) => w.storage_key).filter(Boolean);
    });
  }

  /**
   * Gone for good: the row and, through ON DELETE CASCADE, every UP, match,
   * message, report, card, device and verification that names them.
   * Returns the files the caller must remove from disk.
   */
  hardDeleteUser(userId) {
    return transaction(this.db, () => {
      const user = this.db.prepare(`SELECT * FROM users WHERE id = ?`).get(userId);
      if (!user) return null;
      const profile = this.findProfile(userId);
      const photos = JSON.parse(profile?.photos ?? '[]');
      if (profile?.photo_primary && !photos.includes(profile.photo_primary)) {
        photos.push(profile.photo_primary);
      }
      const selfies = this.db
        .prepare(`SELECT storage_key FROM verifications WHERE user_id = ? AND storage_key IS NOT NULL`)
        .all(userId)
        .map((r) => r.storage_key);
      this.db.prepare(`DELETE FROM otp_codes WHERE phone = ?`).run(user.phone);
      this.db.prepare(`DELETE FROM otp_requests WHERE phone = ?`).run(user.phone);
      this.db.prepare(`DELETE FROM users WHERE id = ?`).run(userId);
      return { photos, selfies };
    });
  }

  // -- operators -------------------------------------------------------------

  createOperator({ name, email, keyHash }) {
    const id = newId();
    this.db
      .prepare(`INSERT INTO operators (id, name, email, key_hash, created_at) VALUES (?, ?, ?, ?, ?)`)
      .run(id, name, email ?? '', keyHash, nowIso());
    return this.db.prepare(`SELECT * FROM operators WHERE id = ?`).get(id);
  }

  findOperatorByKeyHash(keyHash) {
    return (
      this.db
        .prepare(`SELECT * FROM operators WHERE key_hash = ? AND revoked_at IS NULL`)
        .get(keyHash) ?? null
    );
  }

  listOperators() {
    return this.db.prepare(`SELECT * FROM operators ORDER BY created_at DESC`).all();
  }

  touchOperator(id) {
    const at = nowIso();
    this.db
      .prepare(
        `UPDATE operators SET last_used_at = ?
          WHERE id = ? AND (last_used_at IS NULL OR last_used_at < ?)`,
      )
      .run(at, id, new Date(Date.now() - 60_000).toISOString());
  }

  revokeOperator(id) {
    return (
      this.db
        .prepare(`UPDATE operators SET revoked_at = ? WHERE id = ? AND revoked_at IS NULL`)
        .run(nowIso(), id).changes > 0
    );
  }

  logAdminAction({ operatorId, operator, method, path }) {
    this.db
      .prepare(
        `INSERT INTO admin_log (id, operator_id, operator, method, path, at) VALUES (?, ?, ?, ?, ?, ?)`,
      )
      .run(newId(), operatorId, operator, method, path, nowIso());
  }

  adminLog(limit = 200) {
    return this.db
      .prepare(
        `SELECT l.*, p.first_name AS target_name
           FROM admin_log l
           LEFT JOIN profiles p
             ON l.path LIKE '/admin/users/%' AND p.user_id = substr(l.path, 14, 36)
          ORDER BY l.at DESC LIMIT ?`,
      )
      .all(limit);
  }

  // -- in-app notices ----------------------------------------------------------

  /** One unseen notice per kind: a second decision replaces the first. */
  addNotice(userId, kind) {
    return transaction(this.db, () => {
      this.db
        .prepare(
          `DELETE FROM user_notices WHERE user_id = ? AND seen_at IS NULL
             AND kind LIKE ?`,
        )
        .run(userId, `${kind.split('_')[0]}_%`);
      const id = newId();
      this.db
        .prepare(`INSERT INTO user_notices (id, user_id, kind, created_at) VALUES (?, ?, ?, ?)`)
        .run(id, userId, kind, nowIso());
      return id;
    });
  }

  unseenNotices(userId) {
    return this.db
      .prepare(
        `SELECT id, kind, created_at FROM user_notices
          WHERE user_id = ? AND seen_at IS NULL ORDER BY created_at ASC`,
      )
      .all(userId);
  }

  markNoticeSeen(userId, id) {
    return (
      this.db
        .prepare(`UPDATE user_notices SET seen_at = ? WHERE id = ? AND user_id = ? AND seen_at IS NULL`)
        .run(nowIso(), id, userId).changes > 0
    );
  }
}
