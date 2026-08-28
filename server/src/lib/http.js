/**
 * A very small router and the JSON plumbing around it.
 *
 * Hand-rolled rather than pulled from npm: the whole surface is 18 endpoints
 * with one path parameter each, and a framework would be more configuration
 * than code. If routing ever becomes interesting, replace this file.
 */

/** Thrown by handlers; turned into a JSON response by `handle`. */
export class HttpError extends Error {
  constructor(status, code, message) {
    super(message ?? code);
    this.status = status;
    this.code = code;
  }
}

export const badRequest = (code, message) => new HttpError(400, code, message);
export const unauthorized = (code = 'unauthorized') => new HttpError(401, code);
export const forbidden = (code = 'forbidden') => new HttpError(403, code);
export const notFound = (code = 'not_found') => new HttpError(404, code);
export const tooManyRequests = (code, message) =>
  new HttpError(429, code, message);

export function createRouter() {
  /** @type {Array<{method: string, parts: string[], handler: Function}>} */
  const routes = [];

  const add = (method, pattern, handler) => {
    routes.push({
      method,
      parts: pattern.split('/').filter(Boolean),
      handler,
    });
  };

  const match = (method, pathname) => {
    const parts = pathname.split('/').filter(Boolean);
    for (const route of routes) {
      if (route.method !== method) continue;
      if (route.parts.length !== parts.length) continue;
      const params = {};
      let ok = true;
      for (let i = 0; i < parts.length; i++) {
        const expected = route.parts[i];
        if (expected.startsWith(':')) {
          params[expected.slice(1)] = decodeURIComponent(parts[i]);
        } else if (expected !== parts[i]) {
          ok = false;
          break;
        }
      }
      if (ok) return { handler: route.handler, params };
    }
    return null;
  };

  return {
    get: (p, h) => add('GET', p, h),
    post: (p, h) => add('POST', p, h),
    put: (p, h) => add('PUT', p, h),
    delete: (p, h) => add('DELETE', p, h),
    match,
  };
}

const MAX_BODY_BYTES = 1_000_000;

export async function readJsonBody(req) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) throw badRequest('body_too_large');
    chunks.push(chunk);
  }
  if (chunks.length === 0) return {};
  const text = Buffer.concat(chunks).toString('utf8').trim();
  if (text === '') return {};
  try {
    const parsed = JSON.parse(text);
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw badRequest('body_must_be_object');
    }
    return parsed;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw badRequest('invalid_json');
  }
}

/**
 * Writes bytes rather than JSON — photos, and nothing else so far.
 *
 * `nosniff` and an explicit content type matter more here than anywhere else
 * in this file: these bytes were uploaded by a user, and a browser that
 * guesses their type is a browser that can be talked into running them.
 */
export function sendBinary(res, status, { body, mime, etag }) {
  const headers = {
    'content-type': mime,
    'x-content-type-options': 'nosniff',
    'content-disposition': 'inline',
    // Private: a photo is not something a shared proxy should keep.
    'cache-control': 'private, max-age=86400',
  };
  // A 304 carries no body, and a content-length on one makes some
  // intermediaries treat the response as framed with one. It does have to
  // carry the ETag it would have sent with the 200.
  if (status !== 304) headers['content-length'] = body.length;
  if (etag) headers.etag = etag;
  res.writeHead(status, headers);
  res.end(body);
}

export function sendJson(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(body),
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
  });
  res.end(body);
}
