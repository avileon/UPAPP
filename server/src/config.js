import { randomBytes } from 'node:crypto';
import { dirname, join } from 'node:path';

/**
 * Everything tunable, in one place, read from the environment once.
 *
 * The defaults are development defaults on purpose: the server has to run with
 * no configuration at all so the first `node src/server.js` works. Anything
 * that would be unsafe in production fails loudly instead — see `assertProd`.
 */

const num = (name, fallback) => {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const value = Number.parseFloat(raw);
  if (Number.isNaN(value)) throw new Error(`${name} must be a number`);
  return value;
};

const bool = (name, fallback) => {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  return !['0', 'false', 'no', 'off'].includes(raw.toLowerCase());
};

const int = (name, fallback) => {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const value = Number.parseInt(raw, 10);
  if (Number.isNaN(value)) throw new Error(`${name} must be an integer`);
  return value;
};

export const config = {
  env: process.env.NODE_ENV ?? 'development',
  port: int('PORT', 3000),
  host: process.env.HOST ?? '0.0.0.0',

  databaseFile: process.env.DATABASE_FILE ?? 'up.db',

  /** Signing key for access and refresh tokens. */
  jwtSecret: process.env.JWT_SECRET ?? randomBytes(32).toString('hex'),
  accessTokenTtlSeconds: int('ACCESS_TOKEN_TTL', 15 * 60),
  refreshTokenTtlSeconds: int('REFRESH_TOKEN_TTL', 30 * 24 * 60 * 60),

  /**
   * With no SMS provider configured the OTP is returned in the response and
   * printed to the log. Fine for development, catastrophic in production —
   * `assertProd` refuses to start that way.
   */
  smsProvider: process.env.SMS_PROVIDER ?? 'mock',

  otp: {
    length: 4,
    ttlSeconds: int('OTP_TTL', 5 * 60),
    maxPerNumberPerHour: int('OTP_MAX_PER_HOUR', 5),
    maxAttempts: 5,
  },

  likes: {
    /** An UP is cheap to send and expensive to receive. */
    maxPerHour: int('LIKES_MAX_PER_HOUR', 60),
  },

  live: {
    maxDurationSeconds: int('LIVE_MAX_DURATION', 2 * 60 * 60),
    /** How long a single BLE token stays valid before rotation. */
    tokenTtlSeconds: int('BLE_TOKEN_TTL', 10 * 60),
    /** How many tokens a device gets per batch. */
    tokenBatchSize: int('BLE_TOKEN_BATCH', 6),
    /**
     * Going Live requires a verified face (live check or manual review).
     * A dating app where anyone can appear as anyone is the thing UP is not.
     */
    requireVerification: bool('REQUIRE_VERIFICATION', true),
  },

  /** Registered places: a QR on the wall plus the phone's location. */
  venues: {
    /** One scan buys one hour in the room; after that, scan again. */
    sessionSeconds: int('VENUE_SESSION_SECONDS', 60 * 60),
    /** Push "your hour is almost up" this long before it ends. */
    remindBeforeSeconds: int('VENUE_REMIND_BEFORE_SECONDS', 5 * 60),
    /** A GPS fix is fuzzy; this much of its stated error is forgiven. */
    maxAccuracyCreditM: int('MAX_ACCURACY_CREDIT_M', 150),
    /** A fix worse than this is no fix at all. */
    maxAcceptedAccuracyM: int('MAX_ACCEPTED_ACCURACY_M', 500),
    defaultRadiusM: int('VENUE_DEFAULT_RADIUS_M', 80),
  },

  /** "Who is around me" without a venue: phones within this many metres. */
  area: {
    radiusM: int('AREA_RADIUS_M', 500),
  },

  /** Face checks. Thresholds per docs/FACE_VERIFICATION_SPEC.md. */
  face: {
    serviceUrl: process.env.FACE_SVC_URL ?? 'http://127.0.0.1:8091',
    timeoutMs: int('FACE_SVC_TIMEOUT_MS', 15000),
    liveTtlSeconds: int('FACE_LIVE_TTL_SECONDS', 120),
    minScore: num('FACE_MIN_SCORE', 0.85),
    minWidthRatio: num('FACE_MIN_WIDTH_RATIO', 0.18),
    yawCenter: num('FACE_YAW_CENTER', 0.15),
    yawTurn: num('FACE_YAW_TURN', 0.22),
    blurMin: num('FACE_BLUR_MIN', 15),
    samePerson: num('FACE_SAME_PERSON', 0.45),
    replayed: num('FACE_REPLAYED', 0.995),
    matchAccept: num('FACE_MATCH_ACCEPT', 0.40),
    matchReview: num('FACE_MATCH_REVIEW', 0.30),
    attemptsPerDay: int('FACE_ATTEMPTS_PER_DAY', 8),
    keyFile: process.env.FACE_TEMPLATE_KEY_FILE ?? '',
    model: 'sface-2021dec',
  },

  /** Where the built web app lives, if it has been fetched. */
  siteDirectory: process.env.SITE_DIR ?? 'public',

  media: {
    /** Where photos land. Relative paths resolve next to the server code. */
    directory: process.env.MEDIA_DIR ?? 'uploads',
    /**
     * Six megabytes. A phone camera JPEG is two to four; the app downscales
     * before uploading, so anything near this cap is either a very large photo
     * or someone testing the limit.
     */
    maxBytes: int('MEDIA_MAX_BYTES', 6 * 1024 * 1024),
  },

  verification: {
    /**
     * Where verification selfies live while they wait to be looked at.
     *
     * A directory of its own, separate from `media.directory`, because the
     * public `GET /media/:key` route can reach anything in that one. A photo
     * somebody took of their face on demand, and never chose to publish, must
     * not be one URL guess away from being served.
     *
     * Defaulted *beside* the media directory rather than to a bare relative
     * path. A bare one resolves next to the code, which on a real deployment
     * is mounted read-only — so a server whose operator set `MEDIA_DIR` and
     * not this one refused to start at all, with a stack trace about `mkdir`.
     * Deriving it means there is one directory to configure and the two are
     * siblings by construction.
     */
    directory:
      process.env.VERIFICATION_DIR ??
      join(dirname(process.env.MEDIA_DIR ?? 'uploads'), 'verification'),
    /** How long a pose challenge stays answerable. */
    challengeTtlSeconds: int('VERIFICATION_CHALLENGE_TTL', 5 * 60),
  },

  /**
   * The key for the review screen.
   *
   * Empty disables the admin routes entirely rather than leaving them open —
   * a deployment that forgot to set this has no review queue, not a public one.
   */
  adminToken: process.env.ADMIN_TOKEN ?? '',

  /**
   * Web Push signing identity.
   *
   * Absent means notifications are off, and everything else still works — the
   * app polls. Generated once by the provisioning script into a file, for the
   * same reason the JWT secret is: rotating it silently invalidates every
   * subscription every browser has already made, and the only symptom is
   * notifications that quietly stop.
   */
  vapid: {
    publicKey: process.env.VAPID_PUBLIC_KEY ?? '',
    privateKey: process.env.VAPID_PRIVATE_KEY ?? '',
    /** Where a push service should complain. Must be a mailto: or https: URL. */
    subject: process.env.VAPID_SUBJECT ?? 'mailto:admin@up.atar.co',
  },

  /** Where the web app is reached from outside — what a venue QR points at. */
  publicUrl: (process.env.PUBLIC_URL ?? 'https://up.atar.co').replace(/\/+$/, ''),

  minimumAge: 18,
  maxPhotos: 4,
  maxMessageLength: 1000,
};

/** Refuses to run a production server with development shortcuts enabled. */
export function assertProd() {
  if (config.env !== 'production') return;
  const problems = [];
  if (!process.env.JWT_SECRET) problems.push('JWT_SECRET is not set');
  if (config.smsProvider === 'mock') problems.push('SMS_PROVIDER is still "mock"');
  if (problems.length > 0) {
    throw new Error(`refusing to start in production: ${problems.join('; ')}`);
  }
}

/** True when it is safe to hand the OTP back to the caller. */
export const revealsOtp = () => config.smsProvider === 'mock';
