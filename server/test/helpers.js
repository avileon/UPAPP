import { createServer } from 'node:http';
import { once } from 'node:events';

import { createApp } from '../src/app.js';

/**
 * Spins the real app on an ephemeral port and talks to it over real HTTP.
 *
 * Testing through the wire rather than by calling handlers directly is what
 * makes these tests worth having: routing, auth headers, status codes and JSON
 * shapes are all part of the contract the Flutter client depends on.
 */
export async function startTestServer() {
  const app = createApp({ database: ':memory:' });
  const server = createServer(app.handle);
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const { port } = server.address();
  const base = `http://127.0.0.1:${port}`;

  const call = async (method, path, { token, body } = {}) => {
    const response = await fetch(`${base}${path}`, {
      method,
      headers: {
        'content-type': 'application/json',
        ...(token ? { authorization: `Bearer ${token}` } : {}),
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
    return { token, id: profile.body.id, refreshToken: verified.body.refreshToken };
  };

  /** Puts two users in range of each other and returns their swapped tokens. */
  const goLiveTogether = async (a, b) => {
    const liveA = await call('POST', '/live/start', {
      token: a.token,
      body: { durationSeconds: 3600 },
    });
    const liveB = await call('POST', '/live/start', {
      token: b.token,
      body: { durationSeconds: 3600 },
    });
    return {
      aSeesB: liveB.body.tokens.map((t) => t.token),
      bSeesA: liveA.body.tokens.map((t) => t.token),
    };
  };

  /** Goes live under a venue key, the way the app does when a code is set. */
  const goLiveAt = async (user, venue) =>
    call('POST', '/live/start', {
      token: user.token,
      body: { durationSeconds: 3600, venue },
    });

  /** Who this user can see right now with no BLE tokens at all. */
  const nearby = async (user, tokens = []) =>
    call('POST', '/nearby/resolve', { token: user.token, body: { tokens } });

  const close = async () => {
    server.close();
    await once(server, 'close');
    app.db.close();
  };

  return { app, call, signUp, goLiveTogether, goLiveAt, nearby, close, base };
}
