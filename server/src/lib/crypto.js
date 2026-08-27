import {
  createHmac,
  randomBytes,
  randomUUID,
  timingSafeEqual,
} from 'node:crypto';

import { config } from '../config.js';

export const newId = () => randomUUID();

/** Opaque, URL-safe random string. Used for BLE tokens and refresh tokens. */
export const randomToken = (bytes = 32) => randomBytes(bytes).toString('base64url');

/**
 * Everything secret is stored hashed: OTP codes, refresh tokens, BLE tokens.
 * A dump of this database must not let anyone impersonate a user or replay a
 * proximity token.
 */
export const hashSecret = (value) =>
  createHmac('sha256', config.jwtSecret).update(String(value)).digest('base64url');

export function safeEqual(a, b) {
  const left = Buffer.from(String(a));
  const right = Buffer.from(String(b));
  if (left.length !== right.length) return false;
  return timingSafeEqual(left, right);
}

// ---------------------------------------------------------------------------
// JWT (HS256)
//
// Hand-rolled because it is thirty lines and removes a dependency from the
// most security-sensitive path in the server. It signs and verifies exactly
// one algorithm — there is no `alg` negotiation to confuse, which is where
// most JWT libraries have historically been broken.
// ---------------------------------------------------------------------------

const b64 = (input) => Buffer.from(input).toString('base64url');

const sign = (data) =>
  createHmac('sha256', config.jwtSecret).update(data).digest('base64url');

export function issueAccessToken(userId, ttlSeconds = config.accessTokenTtlSeconds) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = b64(
    JSON.stringify({ sub: userId, iat: now, exp: now + ttlSeconds }),
  );
  const data = `${header}.${payload}`;
  return `${data}.${sign(data)}`;
}

/** Returns the user id, or null for anything malformed, forged or expired. */
export function verifyAccessToken(token) {
  if (typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [header, payload, signature] = parts;
  if (!safeEqual(signature, sign(`${header}.${payload}`))) return null;
  let claims;
  try {
    claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
  } catch {
    return null;
  }
  if (typeof claims?.sub !== 'string') return null;
  if (typeof claims.exp !== 'number') return null;
  if (claims.exp <= Math.floor(Date.now() / 1000)) return null;
  return claims.sub;
}

/** Numeric OTP of the configured length, drawn from a CSPRNG. */
export function generateOtp(length = config.otp.length) {
  let out = '';
  while (out.length < length) {
    for (const byte of randomBytes(length)) {
      if (byte < 250) {
        out += String(byte % 10);
        if (out.length === length) break;
      }
    }
  }
  return out;
}
