/**
 * Address → coordinates, for a business that signs up from home rather than
 * from inside its own bar.
 *
 * OpenStreetMap's Nominatim: free, no key, and its usage policy asks for two
 * things this class does — an identifying User-Agent and at most one request
 * a second. Answers are cached, because the same street gets typed by the
 * same person three times while they fix a typo.
 */
export class Geocoder {
  constructor({ endpoint = 'https://nominatim.openstreetmap.org/search', fetchImpl = fetch } = {}) {
    this.endpoint = endpoint;
    this.fetch = fetchImpl;
    this.cache = new Map();
    this.queue = Promise.resolve();
    this.lastAt = 0;
  }

  async search(query) {
    const key = query.trim().toLowerCase();
    if (this.cache.has(key)) return this.cache.get(key);

    // One at a time, a second apart, whoever is asking.
    const run = this.queue.then(async () => {
      const wait = this.lastAt + 1100 - Date.now();
      if (wait > 0) await new Promise((r) => setTimeout(r, wait));
      this.lastAt = Date.now();
      const url = new URL(this.endpoint);
      url.searchParams.set('format', 'jsonv2');
      url.searchParams.set('q', query);
      url.searchParams.set('countrycodes', 'il');
      url.searchParams.set('limit', '5');
      url.searchParams.set('accept-language', 'he');
      const res = await this.fetch(url, {
        headers: { 'user-agent': 'UP-venue-signup/1.0 (+https://up.atar.co)' },
        signal: AbortSignal.timeout(8000),
      });
      if (!res.ok) throw new Error(`geocoder ${res.status}`);
      const rows = await res.json();
      return (Array.isArray(rows) ? rows : [])
        .map((r) => ({ label: String(r.display_name ?? ''), lat: Number(r.lat), lng: Number(r.lon) }))
        .filter((r) => r.label && Number.isFinite(r.lat) && Number.isFinite(r.lng));
    });
    this.queue = run.catch(() => {});
    const results = await run;
    if (this.cache.size > 500) this.cache.delete(this.cache.keys().next().value);
    this.cache.set(key, results);
    return results;
  }
}

/** A fixed-window counter per key: enough to keep a form from being a spam cannon. */
export class RateLimiter {
  constructor({ limit, windowMs }) {
    this.limit = limit;
    this.windowMs = windowMs;
    this.hits = new Map();
  }

  /** True if this hit is allowed. */
  take(key) {
    const now = Date.now();
    const row = this.hits.get(key);
    if (!row || now - row.start > this.windowMs) {
      this.hits.set(key, { start: now, count: 1 });
      if (this.hits.size > 10_000) this.hits.delete(this.hits.keys().next().value);
      return true;
    }
    row.count += 1;
    return row.count <= this.limit;
  }
}

/** The caller's address as Caddy saw it. The app only listens on localhost. */
export function clientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded) return forwarded.split(',')[0].trim();
  return req.socket?.remoteAddress ?? 'unknown';
}
