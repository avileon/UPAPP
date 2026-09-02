import { randomBytes } from 'node:crypto';

/**
 * Everything tunable, in one place, read from the environment once.
 *
 * The defaults are development defaults on purpose: the server has to run with
 * no configuration at all so the first `node src/server.js` works. Anything
 * that would be unsafe in production fails loudly instead — see `assertProd`.
 */

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

  minimumAge: 18,
  maxPhotos: 6,
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
