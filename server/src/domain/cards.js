import { nowIso, transaction } from '../db/db.js';
import { hashSecret, randomToken } from '../lib/crypto.js';

/**
 * Personal business cards: the link that passes from one phone to another
 * over NFC, a QR on the screen, a Wallet pass or a sticker.
 *
 * **Giving your card is your UP.** The person who receives it does not know
 * who else is in the room and the giver cannot find her in the app, so a
 * one-way UP from her side would be a row nobody ever acts on. Handing the
 * card over is the giver saying "yes" in advance; her UP from the card page
 * closes the pair and opens the chat.
 *
 * That is also why a `share` card answers exactly one person. A link that a
 * screenshot can forward to a WhatsApp group must not become a standing yes
 * to the whole group.
 *
 * The token itself is never stored, only its hash — like every other secret
 * in this database.
 */

export const CARD_KINDS = ['share', 'wallet', 'physical'];

/** How long a tap or an on-screen QR stays good. */
export const SHARE_TTL_HOURS = 24;

/** 12 URL-safe characters: short enough for an NFC tag, 72 bits of guessing. */
const newToken = () => randomToken(9);

export class CardStore {
  constructor(db) {
    this.db = db;
  }

  issue(userId, kind = 'share') {
    if (!CARD_KINDS.includes(kind)) kind = 'share';
    const token = newToken();
    const expiresAt =
      kind === 'share'
        ? new Date(Date.now() + SHARE_TTL_HOURS * 3600_000).toISOString()
        : null;
    this.db
      .prepare(
        `INSERT INTO cards (token_hash, user_id, kind, expires_at, created_at)
         VALUES (?, ?, ?, ?, ?)`,
      )
      .run(hashSecret(token), userId, kind, expiresAt, nowIso());
    return { token, kind, expiresAt };
  }

  /**
   * The card behind a token, or why there is none.
   * `{ card }` or `{ problem: 'card_unknown' | 'card_expired' | 'card_used' }`.
   */
  resolve(token, { forUser = null } = {}) {
    if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{8,32}$/.test(token)) {
      return { problem: 'card_unknown' };
    }
    const card = this.db
      .prepare(`SELECT * FROM cards WHERE token_hash = ?`)
      .get(hashSecret(token));
    if (!card || card.revoked_at) return { problem: 'card_unknown' };
    if (card.expires_at && card.expires_at <= nowIso()) return { problem: 'card_expired' };
    if (card.kind === 'share' && card.used_by && card.used_by !== forUser) {
      return { problem: 'card_used' };
    }
    return { card };
  }

  /**
   * Marks a share card as answered by `userId`. False if someone else got
   * there first — checked inside the transaction, so two people tapping UP on
   * the same forwarded link at the same moment cannot both win.
   */
  claim(card, userId) {
    if (card.kind !== 'share') return true;
    return transaction(this.db, () => {
      const row = this.db
        .prepare(`SELECT used_by FROM cards WHERE token_hash = ?`)
        .get(card.token_hash);
      if (row?.used_by && row.used_by !== userId) return false;
      this.db
        .prepare(`UPDATE cards SET used_by = ?, used_at = ? WHERE token_hash = ?`)
        .run(userId, nowIso(), card.token_hash);
      return true;
    });
  }

  /** Every card this person has given out stops working. */
  revokeAll(userId) {
    const result = this.db
      .prepare(`UPDATE cards SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL`)
      .run(nowIso(), userId);
    return Number(result.changes);
  }

  /** Retires one kind of card, e.g. the previous Wallet pass. */
  revokeKind(userId, kind) {
    this.db
      .prepare(
        `UPDATE cards SET revoked_at = ? WHERE user_id = ? AND kind = ? AND revoked_at IS NULL`,
      )
      .run(nowIso(), userId, kind);
  }

  /** Expired share cards are dead weight; nothing ever reads them again. */
  sweep() {
    this.db
      .prepare(`DELETE FROM cards WHERE expires_at IS NOT NULL AND expires_at < ?`)
      .run(new Date(Date.now() - 7 * 24 * 3600_000).toISOString());
  }
}
