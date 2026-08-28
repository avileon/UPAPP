import { createHash, randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { config } from '../config.js';
import { badRequest } from './http.js';

const here = dirname(fileURLToPath(import.meta.url));

/**
 * Photo storage.
 *
 * Files on disk beside the server rather than S3, for the same reason the
 * database is SQLite: a photo you can see in a folder is a photo you can
 * reason about, and object storage is an account, a bucket policy and a
 * presigning dance before the first picture appears on a phone. The interface
 * here — save, open, remove — is what an S3 implementation has to satisfy, and
 * nothing outside this file touches the filesystem.
 *
 * Two rules this file exists to enforce:
 *
 * 1. **A key is a name we chose, never a name the caller chose.** It is 32 hex
 *    characters plus a known extension, and `open` re-validates the shape
 *    before touching the disk. A caller cannot get `../../etc/passwd` through
 *    here no matter what they send.
 *
 * 2. **The bytes decide the type, not the header.** `content-type: image/jpeg`
 *    is a claim by whoever is uploading. We read the magic bytes and store the
 *    file under the extension those bytes justify, or refuse it.
 */

const SIGNATURES = [
  { ext: 'jpg', mime: 'image/jpeg', test: (b) => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff },
  {
    ext: 'png',
    mime: 'image/png',
    test: (b) =>
      b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47 &&
      b[4] === 0x0d && b[5] === 0x0a && b[6] === 0x1a && b[7] === 0x0a,
  },
  {
    ext: 'webp',
    mime: 'image/webp',
    test: (b) =>
      b.length > 12 &&
      b.toString('ascii', 0, 4) === 'RIFF' &&
      b.toString('ascii', 8, 12) === 'WEBP',
  },
];

const KEY_PATTERN = /^[0-9a-f]{32}\.(jpg|png|webp)$/;

/** The image type these bytes actually are, or null. */
export function sniffImage(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 12) return null;
  return SIGNATURES.find((signature) => signature.test(buffer)) ?? null;
}

export function mimeForKey(key) {
  const ext = key.slice(key.lastIndexOf('.') + 1);
  return SIGNATURES.find((signature) => signature.ext === ext)?.mime ?? null;
}

/**
 * Reads a request body as bytes.
 *
 * Separate from `readJsonBody` because the limits are different by an order of
 * magnitude, and because a photo that arrives truncated must fail here rather
 * than at the point where someone tries to look at it.
 */
export async function readBinaryBody(req, maxBytes = config.media.maxBytes) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > maxBytes) throw badRequest('photo_too_large');
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

export class PhotoStore {
  constructor(directory = config.media.directory) {
    // Relative to the server, not to whatever directory it was started from.
    this.directory = resolve(directory.startsWith('/') ? directory : join(here, '..', '..', directory));
    mkdirSync(this.directory, { recursive: true });
  }

  /** Stores the bytes and returns the key. Throws if they are not an image. */
  save(buffer) {
    const kind = sniffImage(buffer);
    if (!kind) throw badRequest('not_an_image');
    const key = `${randomBytes(16).toString('hex')}.${kind.ext}`;
    writeFileSync(join(this.directory, key), buffer);
    return { key, mime: kind.mime, bytes: buffer.length };
  }

  /** Returns the bytes for a key, or null. Never throws on a bad key. */
  open(key) {
    if (typeof key !== 'string' || !KEY_PATTERN.test(key)) return null;
    const path = join(this.directory, key);
    if (!existsSync(path)) return null;
    const body = readFileSync(path);
    return {
      body,
      mime: mimeForKey(key),
      // Content addresses the bytes, so a phone that already has this photo
      // gets a 304 instead of the megabyte.
      etag: `"${createHash('sha1').update(body).digest('hex')}"`,
    };
  }

  remove(key) {
    if (typeof key !== 'string' || !KEY_PATTERN.test(key)) return false;
    const path = join(this.directory, key);
    if (!existsSync(path)) return false;
    rmSync(path, { force: true });
    return true;
  }
}
