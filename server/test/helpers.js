import { createServer } from 'node:http';
import { once } from 'node:events';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { createApp } from '../src/app.js';
import { normaliseVenue } from '../src/domain/presence.js';
import { PhotoStore } from '../src/lib/media.js';

/** Where every test venue is, and a phone standing in it. */
export const HERE = { lat: 32.0853, lng: 34.7818, accuracy: 10 };

/**
 * A face-svc stand-in. `script` maps the first bytes of an image (as a
 * string) to a canned analysis, so a test can say "this frame is person A
 * turned left" without a model.
 */
export class FakeFaces {
  constructor() {
    this.byTag = new Map();
    this.down = false;
    this.calls = 0;
  }

  set(tag, analysis) {
    this.byTag.set(tag.padEnd(8).slice(0, 8), analysis);
  }

  async analyze(bytes) {
    this.calls += 1;
    if (this.down) {
      const { FaceServiceUnavailable } = await import('../src/domain/face.js');
      throw new FaceServiceUnavailable();
    }
    const tag = Buffer.from(bytes).subarray(-8).toString('latin1');
    const raw = this.byTag.get(tag) ?? { width: 640, height: 640, faces: [] };
    // The same decoding FaceClient does on face-svc's JSON.
    const { decodeEmbedding } = await import('../src/domain/face.js');
    return {
      ...raw,
      faces: raw.faces.map((f) => ({ ...f, embedding: decodeEmbedding(f.embedding) })),
    };
  }
}

/**
 * Spins the real app on an ephemeral port and talks to it over real HTTP.
 *
 * Testing through the wire rather than by calling handlers directly is what
 * makes these tests worth having: routing, auth headers, status codes and JSON
 * shapes are all part of the contract the Flutter client depends on.
 */
export async function startTestServer({ faces = new FakeFaces() } = {}) {
  // A directory of its own per suite. Photos are the one thing in this server
  // that outlives the in-memory database, so without this the tests would be
  // writing real files into the repository.
  const photoDir = mkdtempSync(join(tmpdir(), 'up-photos-'));
  // Verification selfies live somewhere else entirely — that separation is a
  // property the tests check, so the fixture has to honour it too.
  const selfieDir = mkdtempSync(join(tmpdir(), 'up-selfies-'));
  const app = createApp({
    database: ':memory:',
    photos: new PhotoStore(photoDir),
    selfies: new PhotoStore(selfieDir),
    face: faces,
  });
  const server = createServer(app.handle);
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const { port } = server.address();
  const base = `http://127.0.0.1:${port}`;

  const call = async (method, path, { token, body, headers } = {}) => {
    const response = await fetch(`${base}${path}`, {
      method,
      headers: {
        'content-type': 'application/json',
        ...(token ? { authorization: `Bearer ${token}` } : {}),
        ...headers,
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await response.text();
    return {
      status: response.status,
      body: text ? JSON.parse(text) : {},
    };
  };

  /** Registers a user and leaves them with a complete, of-age profile. */
  const signUp = async (phone, overrides = {}) => {
    const requested = await call('POST', '/auth/request-otp', { body: { phone } });
    const verified = await call('POST', '/auth/verify-otp', {
      body: { phone, code: requested.body.devCode, acceptedTerms: true },
    });
    const token = verified.body.accessToken;
    const profile = await call('PUT', '/me/profile', {
      token,
      body: {
        firstName: overrides.firstName ?? 'Test',
        birthDate: overrides.birthDate ?? '1994-05-01',
        gender: overrides.gender ?? 'male',
        interestedIn: overrides.interestedIn ?? 'everyone',
        bio: overrides.bio ?? '',
      },
    });
    // Verified by default: going Live requires it, and almost no test is
    // about verification. The ones that are pass `verified: false`.
    if (overrides.verified !== false && profile.body.id) {
      app.store.recordLiveVerification(profile.body.id, { status: 'approved' });
    }
    return { token, id: profile.body.id, refreshToken: verified.body.refreshToken };
  };

  /** Puts two users in range of each other and returns their swapped tokens. */
  const goLiveTogether = async (a, b, intent) => {
    const liveA = await call('POST', '/live/start', {
      token: a.token,
      body: { durationSeconds: 3600, intent },
    });
    const liveB = await call('POST', '/live/start', {
      token: b.token,
      body: { durationSeconds: 3600, intent },
    });
    return {
      aSeesB: liveB.body.tokens.map((t) => t.token),
      bSeesA: liveA.body.tokens.map((t) => t.token),
    };
  };

  /** Goes live under a venue key, the way the app does when a code is set. */
  const registerVenue = (venue) => {
    const code = normaliseVenue(venue);
    if (code && !app.store.findVenue(code)) {
      app.store.createVenue({ code, name: `Venue ${code}`, lat: HERE.lat, lng: HERE.lng, radiusM: 80 });
    }
    return code;
  };

  const goLiveAt = async (user, venue, intent, position = HERE) => {
    registerVenue(venue);
    return call('POST', '/live/start', {
      token: user.token,
      body: { durationSeconds: 3600, venue, intent, ...position },
    });
  };

  /** Who this user can see right now with no BLE tokens at all. */
  const nearby = async (user, tokens = []) =>
    call('POST', '/nearby/resolve', { token: user.token, body: { tokens } });

  /** Uploads raw bytes the way the app does — the body is the image itself. */
  const uploadPhoto = async (user, bytes, contentType = 'image/png') => {
    const response = await fetch(`${base}/media/photo`, {
      method: 'POST',
      headers: {
        'content-type': contentType,
        authorization: `Bearer ${user.token}`,
      },
      body: bytes,
    });
    const text = await response.text();
    return { status: response.status, body: text ? JSON.parse(text) : {} };
  };

  /** Posts raw bytes to any endpoint that takes an image body. */
  const uploadRaw = async (user, path, bytes, contentType = 'image/png') => {
    const response = await fetch(`${base}${path}`, {
      method: 'POST',
      headers: {
        'content-type': contentType,
        authorization: `Bearer ${user.token}`,
      },
      body: bytes,
    });
    const text = await response.text();
    return { status: response.status, body: text ? JSON.parse(text) : {} };
  };

  const close = async () => {
    server.close();
    await once(server, 'close');
    app.db.close();
    rmSync(photoDir, { recursive: true, force: true });
    rmSync(selfieDir, { recursive: true, force: true });
  };

  return {
    app,
    faces,
    // The store itself, for the handful of assertions that are about a row
    // existing rather than about a response. Reaching for it is a smell
    // everywhere the HTTP surface can answer the question instead.
    store: app.store,
    call,
    signUp,
    goLiveTogether,
    goLiveAt,
    registerVenue,
    nearby,
    uploadPhoto,
    uploadRaw,
    close,
    base,
    photoDir,
    selfieDir,
  };
}
