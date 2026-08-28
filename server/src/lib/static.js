import { createHash } from 'node:crypto';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, normalize, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));

/**
 * Serves the built web app.
 *
 * The app and the API come from one origin on purpose. It means the page knows
 * its own server address without anyone pasting one, it means a QR code can
 * carry both the address and the room in a single link, and it means there is
 * no CORS story to get wrong.
 *
 * Everything unknown falls through to `index.html`, because the app owns its
 * own routing — `/chat` is a screen, not a file.
 */

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.map': 'application/json; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
};

export class StaticSite {
  constructor(directory = 'public') {
    this.root = resolve(
      directory.startsWith('/') ? directory : join(here, '..', '..', directory),
    );
  }

  get exists() {
    return existsSync(join(this.root, 'index.html'));
  }

  /**
   * Resolves a request path to a file inside the root, or null.
   *
   * The containment check is the point: a URL is attacker-controlled, and
   * `normalize` alone still lets `..` climb out. Anything that does not resolve
   * to a path starting with the root is refused before the disk is touched.
   */
  resolveFile(pathname) {
    let decoded;
    try {
      decoded = decodeURIComponent(pathname);
    } catch {
      return null;
    }
    if (decoded.includes('\0')) return null;

    const relative = normalize(decoded).replace(/^(\.\.[/\\])+/, '');
    const candidate = resolve(join(this.root, relative));
    if (candidate !== this.root && !candidate.startsWith(this.root + sep)) {
      return null;
    }

    if (existsSync(candidate) && statSync(candidate).isFile()) return candidate;

    const index = join(this.root, 'index.html');
    return existsSync(index) ? index : null;
  }

  /** Reads a file and the headers it should be served with. */
  read(pathname) {
    const file = this.resolveFile(pathname);
    if (!file) return null;

    const dot = file.lastIndexOf('.');
    const type = TYPES[file.slice(dot).toLowerCase()] ?? 'application/octet-stream';
    const body = readFileSync(file);

    // The entry point must never be cached: a stale index.html points at
    // hashed asset names that no longer exist, and the app comes up blank with
    // nothing in the console to explain why. The hashed assets themselves are
    // safe to keep for a long time, but this build does not fingerprint them,
    // so nothing here is cached beyond a revalidation.
    return {
      body,
      mime: type,
      etag: `"${createHash('sha1').update(body).digest('hex')}"`,
      cacheControl: 'no-cache',
    };
  }
}
