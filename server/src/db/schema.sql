-- UP schema, Milestone 2.
--
-- SQLite for now; the SQL is kept plain so the move to Postgres is a driver
-- swap rather than a rewrite. Every constraint that protects a product rule is
-- expressed here rather than in application code, because the database is the
-- only layer that still holds under concurrency.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id             TEXT PRIMARY KEY,
  phone          TEXT NOT NULL UNIQUE,
  birth_date     TEXT,                        -- ISO date; age is derived, never stored
  gender         TEXT,
  interested_in  TEXT,
  status         TEXT NOT NULL DEFAULT 'active',   -- active | deleted
  terms_accepted_at TEXT,                     -- server timestamp, not a device flag
  created_at     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS profiles (
  user_id        TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  first_name     TEXT NOT NULL DEFAULT '',
  bio_short      TEXT NOT NULL DEFAULT '',
  photo_primary  TEXT,                        -- storage key, never a public URL
  photos         TEXT NOT NULL DEFAULT '[]',  -- JSON array of storage keys
  updated_at     TEXT NOT NULL
);

-- One-time codes. Stored hashed: a leaked table must not let anyone sign in.
CREATE TABLE IF NOT EXISTS otp_codes (
  phone        TEXT NOT NULL,
  code_hash    TEXT NOT NULL,
  expires_at   TEXT NOT NULL,
  attempts     INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL,
  PRIMARY KEY (phone)
);

CREATE TABLE IF NOT EXISTS otp_requests (
  phone        TEXT NOT NULL,
  requested_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_otp_requests_phone ON otp_requests(phone, requested_at);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  token_hash  TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  TEXT NOT NULL,
  created_at  TEXT NOT NULL
);

-- A one-way UP. Nobody but the sender may learn this row exists until the
-- reverse row also exists.
CREATE TABLE IF NOT EXISTS likes (
  from_user   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  to_user     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  TEXT NOT NULL,
  PRIMARY KEY (from_user, to_user)
);
CREATE INDEX IF NOT EXISTS idx_likes_to ON likes(to_user);

-- user_a is always the lexicographically smaller id, which is what makes the
-- primary key a true one-match-per-pair guarantee under concurrent inserts.
CREATE TABLE IF NOT EXISTS matches (
  id          TEXT PRIMARY KEY,
  user_a      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_b      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  matched_at  TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'active',  -- active | unmatched
  CHECK (user_a < user_b)
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_matches_pair ON matches(user_a, user_b);

CREATE TABLE IF NOT EXISTS messages (
  id          TEXT PRIMARY KEY,
  match_id    TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  sender_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body        TEXT NOT NULL,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_messages_match ON messages(match_id, created_at);

-- One answer per reviewer per match, ever. The reviewer is never revealed.
CREATE TABLE IF NOT EXISTS reality_feedback (
  match_id     TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  reviewer_id  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reviewed_id  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  answer       TEXT NOT NULL,                  -- yes | somewhat | no
  created_at   TEXT NOT NULL,
  PRIMARY KEY (match_id, reviewer_id)
);
CREATE INDEX IF NOT EXISTS idx_reality_reviewed ON reality_feedback(reviewed_id);

CREATE TABLE IF NOT EXISTS blocks (
  blocker_id  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  TEXT NOT NULL,
  PRIMARY KEY (blocker_id, blocked_id)
);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON blocks(blocked_id);

CREATE TABLE IF NOT EXISTS reports (
  id           TEXT PRIMARY KEY,
  reporter_id  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported_id  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category     TEXT NOT NULL,
  notes        TEXT NOT NULL DEFAULT '',
  created_at   TEXT NOT NULL
);

-- One row per browser or device that agreed to be interrupted.
--
-- The endpoint is the identity: the same person on a phone and a laptop is two
-- rows, and re-subscribing on the same browser replaces its row rather than
-- adding a second. The two keys are the browser's half of the end-to-end
-- encryption — the push service relays bytes it cannot read.
CREATE TABLE IF NOT EXISTS push_subscriptions (
  endpoint    TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  p256dh      TEXT NOT NULL,
  auth        TEXT NOT NULL,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_push_user ON push_subscriptions(user_id);
