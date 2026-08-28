import { config, revealsOtp } from './config.js';
import { openDatabase } from './db/db.js';
import { PresenceStore } from './domain/presence.js';
import {
  isOfAge,
  mutuallyCompatible,
  REALITY_ANSWERS,
} from './domain/rules.js';
import {
  generateOtp,
  hashSecret,
  issueAccessToken,
  safeEqual,
  verifyAccessToken,
} from './lib/crypto.js';
import {
  badRequest,
  createRouter,
  forbidden,
  HttpError,
  notFound,
  readJsonBody,
  sendBinary,
  sendJson,
  tooManyRequests,
  unauthorized,
} from './lib/http.js';
import { PhotoStore, readBinaryBody } from './lib/media.js';
import { Store } from './store.js';

const GENDERS = ['male', 'female', 'other'];
const INTERESTS = ['men', 'women', 'everyone'];

/** Israeli-friendly normalisation: digits and a single leading +. */
function normalisePhone(raw) {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  const digits = trimmed.replace(/[^\d+]/g, '');
  const normalised = digits.startsWith('+')
    ? `+${digits.slice(1).replace(/\D/g, '')}`
    : digits.replace(/\D/g, '');
  const bare = normalised.replace(/^\+/, '');
  if (bare.length < 9 || bare.length > 15) return null;
  return normalised;
}

const str = (value, max) =>
  typeof value === 'string' ? value.trim().slice(0, max) : '';

/**
 * What one user is allowed to see about another.
 *
 * This is the only place a profile crosses the boundary, and it is deliberately
 * a whitelist. There is no distance, no last-seen, no phone, no vote count —
 * not hidden in the client, simply never sent.
 */
function publicProfile(store, user, profile) {
  return {
    id: user.id,
    firstName: profile?.first_name ?? '',
    age: (() => {
      const born = user.birth_date ? new Date(user.birth_date) : null;
      if (!born || Number.isNaN(born.getTime())) return null;
      const now = new Date();
      let age = now.getUTCFullYear() - born.getUTCFullYear();
      const m = now.getUTCMonth() - born.getUTCMonth();
      if (m < 0 || (m === 0 && now.getUTCDate() < born.getUTCDate())) age -= 1;
      return age;
    })(),
    bio: profile?.bio_short ?? '',
    photos: JSON.parse(profile?.photos ?? '[]'),
    photoVerified: store.realityBadge(user.id),
  };
}

function privateProfile(store, user, profile) {
  return {
    ...publicProfile(store, user, profile),
    phone: user.phone,
    gender: user.gender,
    interestedIn: user.interested_in,
    birthDate: user.birth_date,
    termsAcceptedAt: user.terms_accepted_at,
  };
}

export function createApp({ database = ':memory:', presence, photos } = {}) {
  const db = openDatabase(database);
  const store = new Store(db);
  const live = presence ?? new PresenceStore();
  const media = photos ?? new PhotoStore();
  const router = createRouter();

  const requireUser = (req) => {
    const header = req.headers.authorization ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    const userId = verifyAccessToken(token);
    if (!userId) throw unauthorized();
    const user = store.findUser(userId);
    if (!user) throw unauthorized('account_gone');
    return user;
  };

  const hoursAgo = (n) => new Date(Date.now() - n * 3600_000).toISOString();

  // -- auth ----------------------------------------------------------------

  router.post('/auth/request-otp', async (req) => {
    const body = await readJsonBody(req);
    const phone = normalisePhone(body.phone);
    if (!phone) throw badRequest('invalid_phone');

    const recent = store.countRecentOtpRequests(phone, hoursAgo(1));
    if (recent >= config.otp.maxPerNumberPerHour) {
      // Without this an attacker bills the project for unlimited SMS.
      throw tooManyRequests('otp_rate_limited', 'too many codes requested');
    }

    const code = generateOtp();
    const expiresAt = new Date(Date.now() + config.otp.ttlSeconds * 1000).toISOString();
    store.recordOtpRequest(phone, hashSecret(code), expiresAt);

    if (revealsOtp()) {
      console.log(`[otp] ${phone} -> ${code}`);
    }
    return {
      status: 200,
      body: { sent: true, ...(revealsOtp() ? { devCode: code } : {}) },
    };
  });

  router.post('/auth/verify-otp', async (req) => {
    const body = await readJsonBody(req);
    const phone = normalisePhone(body.phone);
    const code = str(body.code, 10);
    if (!phone || !code) throw badRequest('invalid_request');

    const record = store.findOtp(phone);
    if (!record) throw badRequest('otp_not_requested');
    if (new Date(record.expires_at).getTime() <= Date.now()) {
      store.clearOtp(phone);
      throw badRequest('otp_expired');
    }
    if (record.attempts >= config.otp.maxAttempts) {
      store.clearOtp(phone);
      throw tooManyRequests('otp_attempts_exhausted');
    }
    if (!safeEqual(hashSecret(code), record.code_hash)) {
      store.bumpOtpAttempts(phone);
      throw badRequest('otp_incorrect');
    }

    store.clearOtp(phone);
    const user = store.findUserByPhone(phone) ?? store.createUser(phone);
    if (body.acceptedTerms === true) store.acceptTerms(user.id);

    return {
      status: 200,
      body: {
        accessToken: issueAccessToken(user.id),
        refreshToken: store.issueRefreshToken(user.id),
        profileComplete: Boolean(user.birth_date && store.findProfile(user.id)?.first_name),
      },
    };
  });

  router.post('/auth/refresh', async (req) => {
    const body = await readJsonBody(req);
    const userId = store.consumeRefreshToken(str(body.refreshToken, 200));
    if (!userId || !store.findUser(userId)) throw unauthorized('refresh_invalid');
    return {
      status: 200,
      body: {
        accessToken: issueAccessToken(userId),
        refreshToken: store.issueRefreshToken(userId),
      },
    };
  });

  // -- me ------------------------------------------------------------------

  router.get('/me/profile', async (req) => {
    const user = requireUser(req);
    return { status: 200, body: privateProfile(store, user, store.findProfile(user.id)) };
  });

  router.put('/me/profile', async (req) => {
    const user = requireUser(req);
    const body = await readJsonBody(req);

    const firstName = str(body.firstName, 40);
    if (!firstName) throw badRequest('first_name_required');

    const birthDate = str(body.birthDate, 32);
    if (!isOfAge(birthDate)) {
      // 18+ is enforced here, with the server's clock. A device flag is not
      // evidence, and both stores treat an unenforced claim as a rejection.
      throw forbidden('under_minimum_age');
    }

    const gender = GENDERS.includes(body.gender) ? body.gender : null;
    const interestedIn = INTERESTS.includes(body.interestedIn) ? body.interestedIn : null;
    if (!gender || !interestedIn) throw badRequest('gender_and_preference_required');

    const saved = store.saveProfile(user.id, {
      firstName,
      bioShort: str(body.bio, 120),
      birthDate,
      gender,
      interestedIn,
    });
    return { status: 200, body: privateProfile(store, saved.user, saved.profile) };
  });

  /**
   * Uploads one photo. The body is the image itself, not a JSON envelope or a
   * multipart form: the app has exactly one file to send, and base64 in JSON
   * would cost a third more bytes over a phone connection for nothing.
   *
   * The declared content type is ignored. `PhotoStore` reads the magic bytes
   * and stores the file under the extension those bytes justify, so an
   * executable renamed to `.jpg` is refused here rather than served later.
   */
  router.post('/media/photo', async (req) => {
    const user = requireUser(req);
    const existing = JSON.parse(store.findProfile(user.id)?.photos ?? '[]');
    if (existing.length >= config.maxPhotos) throw badRequest('photo_limit_reached');

    const body = await readBinaryBody(req);
    if (body.length === 0) throw badRequest('empty_body');

    const saved = media.save(body);
    const result = store.addPhoto(user.id, saved.key);
    if (!result.added) {
      // Losing the race for the last slot should not leave an orphan on disk.
      media.remove(saved.key);
      throw badRequest('photo_limit_reached');
    }
    return { status: 200, body: { key: saved.key, photos: result.photos } };
  });

  /**
   * Serves one photo, to a signed-in caller only.
   *
   * Authentication rather than an unguessable URL: a link that works for
   * anyone who has it is a link that works forever once it is forwarded, and
   * these are photographs of real people. The next step, when the app has more
   * than a handful of users, is to decide per request whether *this* caller is
   * allowed to see *this* person — the same question `/nearby/resolve` already
   * answers — and it goes here.
   */
  router.get('/media/:key', async (req, params) => {
    requireUser(req);
    const file = media.open(params.key);
    if (!file) throw notFound('photo_not_found');
    if (req.headers['if-none-match'] === file.etag) {
      return {
        binary: {
          status: 304,
          body: Buffer.alloc(0),
          mime: file.mime,
          etag: file.etag,
        },
      };
    }
    return { binary: { status: 200, ...file } };
  });

  router.delete('/media/:key', async (req, params) => {
    const user = requireUser(req);
    const result = store.removePhoto(user.id, params.key);
    if (!result.removed) throw notFound('photo_not_found');
    media.remove(params.key);
    return { status: 200, body: { photos: result.photos } };
  });

  router.delete('/me', async (req) => {
    const user = requireUser(req);
    live.stopLive(user.id);
    // The photos go before the row that names them, or nothing is left to say
    // which files on disk belonged to this person.
    for (const key of JSON.parse(store.findProfile(user.id)?.photos ?? '[]')) {
      media.remove(key);
    }
    store.deleteUser(user.id);
    return { status: 200, body: { deleted: true } };
  });

  // -- live ----------------------------------------------------------------

  router.post('/live/start', async (req) => {
    const user = requireUser(req);
    if (!isOfAge(user.birth_date)) throw forbidden('profile_incomplete');
    const body = await readJsonBody(req);
    const seconds = Number(body.durationSeconds) || 3600;
    const { session, tokens } = live.startLive(user.id, seconds, body.venue);
    return {
      status: 200,
      body: {
        sessionId: session.id,
        expiresAt: new Date(session.expiresAt).toISOString(),
        // Echoed back normalised so the client can show the key it actually
        // joined rather than the characters the user typed.
        venue: session.venue,
        tokens,
      },
    };
  });

  router.post('/live/refresh', async (req) => {
    const user = requireUser(req);
    const session = live.activeSession(user.id);
    if (!session) throw badRequest('not_live');
    return {
      status: 200,
      body: {
        sessionId: session.id,
        expiresAt: new Date(session.expiresAt).toISOString(),
        venue: session.venue,
        tokens: live.mintTokens(user.id),
      },
    };
  });

  router.post('/live/stop', async (req) => {
    const user = requireUser(req);
    live.stopLive(user.id);
    return { status: 200, body: { live: false } };
  });

  /**
   * The privacy boundary of the whole product.
   *
   * Observed BLE tokens go in; profiles the caller is allowed to see come out.
   * Everything is decided here — token validity, both live sessions, blocks in
   * either direction, mutual preference. Nothing is filtered on the client,
   * because a client filter is a client that received the data.
   *
   * People found through the venue key join the same list through the same
   * gate. Which of the two channels surfaced a person is decided here and
   * never leaves: the response carries profiles, not provenance, so the app
   * has nothing to render a "found by radio" badge from even if someone later
   * wanted one.
   */
  router.post('/nearby/resolve', async (req) => {
    const user = requireUser(req);
    const body = await readJsonBody(req);
    const tokens = Array.isArray(body.tokens) ? body.tokens.slice(0, 100) : [];

    if (!live.isLive(user.id)) throw forbidden('not_live');

    const profile = store.findProfile(user.id);
    const seen = new Set([user.id]);
    const people = [];

    /** One gate, whichever channel found them. */
    const admit = (otherId) => {
      if (!otherId || seen.has(otherId)) return;
      seen.add(otherId);

      const other = store.findUser(otherId);
      if (!other) return;
      if (store.isBlockedEitherWay(user.id, otherId)) return;
      if (!mutuallyCompatible(user, other)) return;

      people.push(publicProfile(store, other, store.findProfile(otherId)));
    };

    for (const raw of tokens) {
      if (typeof raw !== 'string') continue;
      admit(live.resolveToken(raw));
    }
    for (const peerId of live.venuePeers(user.id)) {
      admit(peerId);
    }

    return {
      status: 200,
      body: {
        people,
        // A coarse count so the home screen can say "3 people nearby" without
        // any of them being identifiable.
        liveNearbyCount: people.length,
        self: { firstName: profile?.first_name ?? '' },
      },
    };
  });

  // -- likes and matches ---------------------------------------------------

  router.post('/likes/:userId', async (req, params) => {
    const user = requireUser(req);
    const targetId = params.userId;
    if (targetId === user.id) throw badRequest('cannot_like_self');

    const target = store.findUser(targetId);
    if (!target) throw notFound('user_not_found');
    if (store.isBlockedEitherWay(user.id, targetId)) throw forbidden('blocked');

    if (store.countRecentLikes(user.id, hoursAgo(1)) >= config.likes.maxPerHour) {
      throw tooManyRequests('like_rate_limited');
    }

    const result = store.sendLike(user.id, targetId);
    return {
      status: 200,
      body: {
        outcome: result.outcome,
        // Only ever populated on mutuality. A one-way UP tells the sender
        // nothing about the other side, which is the entire point.
        match: result.match
          ? { id: result.match.id, personId: targetId, matchedAt: result.match.matched_at }
          : null,
      },
    };
  });

  router.delete('/likes/:userId', async (req, params) => {
    const user = requireUser(req);
    if (store.findMatchByPair(user.id, params.userId)?.status === 'active') {
      throw badRequest('already_matched');
    }
    store.removeLike(user.id, params.userId);
    return { status: 200, body: { removed: true } };
  });

  const matchFor = (user, matchId) => {
    const match = store.findMatch(matchId);
    if (!match) throw notFound('match_not_found');
    if (match.user_a !== user.id && match.user_b !== user.id) throw forbidden();
    return match;
  };

  const otherSide = (match, user) =>
    match.user_a === user.id ? match.user_b : match.user_a;

  router.get('/matches', async (req) => {
    const user = requireUser(req);
    const matches = store.listMatches(user.id).map((match) => {
      const otherId = otherSide(match, user);
      const other = store.findUser(otherId);
      const messages = store.listMessages(match.id);
      return {
        id: match.id,
        matchedAt: match.matched_at,
        person: other
          ? publicProfile(store, other, store.findProfile(otherId))
          : null,
        lastMessage: messages.at(-1)?.body ?? null,
        messageCount: messages.length,
        realityAnswered: store.hasRealityAnswer(match.id, user.id),
      };
    });
    return { status: 200, body: { matches } };
  });

  router.post('/matches/:id/unmatch', async (req, params) => {
    const user = requireUser(req);
    const match = matchFor(user, params.id);
    store.unmatch(match.id);
    return { status: 200, body: { unmatched: true } };
  });

  router.get('/matches/:id/messages', async (req, params) => {
    const user = requireUser(req);
    const match = matchFor(user, params.id);
    const messages = store.listMessages(match.id).map((m) => ({
      id: m.id,
      body: m.body,
      mine: m.sender_id === user.id,
      sentAt: m.created_at,
    }));
    return { status: 200, body: { messages } };
  });

  router.post('/matches/:id/messages', async (req, params) => {
    const user = requireUser(req);
    const match = matchFor(user, params.id);
    if (match.status !== 'active') throw forbidden('match_closed');
    const body = await readJsonBody(req);
    const text = str(body.body, config.maxMessageLength);
    if (!text) throw badRequest('empty_message');
    const message = store.addMessage(match.id, user.id, text);
    return {
      status: 201,
      body: { id: message.id, body: message.body, mine: true, sentAt: message.created_at },
    };
  });

  /**
   * Reality Check.
   *
   * Three guards, all of them the point of the feature: the answer comes from
   * someone who actually matched, the conversation has to have happened, and
   * one answer per match forever. The reviewer is never stored in anything the
   * reviewed user can read.
   */
  router.post('/matches/:id/reality-feedback', async (req, params) => {
    const user = requireUser(req);
    const match = matchFor(user, params.id);
    const body = await readJsonBody(req);
    const answer = str(body.answer, 16);
    if (!REALITY_ANSWERS.includes(answer)) throw badRequest('invalid_answer');
    if (store.hasRealityAnswer(match.id, user.id)) throw badRequest('already_answered');
    if (store.countMessages(match.id) < 4) throw badRequest('conversation_too_short');

    store.addRealityAnswer(match.id, user.id, otherSide(match, user), answer);
    return { status: 200, body: { recorded: true } };
  });

  // -- safety --------------------------------------------------------------

  router.post('/users/:id/block', async (req, params) => {
    const user = requireUser(req);
    if (params.id === user.id) throw badRequest('cannot_block_self');
    if (!store.findUser(params.id)) throw notFound('user_not_found');
    store.block(user.id, params.id);
    return { status: 200, body: { blocked: true } };
  });

  router.post('/users/:id/report', async (req, params) => {
    const user = requireUser(req);
    if (!store.findUser(params.id)) throw notFound('user_not_found');
    const body = await readJsonBody(req);
    // Reporting deliberately does not block: a report should be cheap enough
    // that people actually file one.
    store.report(user.id, params.id, str(body.category, 40) || 'other', str(body.notes, 500));
    return { status: 200, body: { reported: true } };
  });

  router.get('/health', async () => ({
    status: 200,
    body: { ok: true, liveUsers: live.liveUserCount, env: config.env },
  }));

  /** Node http handler. */
  const handle = async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    const route = router.match(req.method, url.pathname);
    if (!route) {
      sendJson(res, 404, { error: 'no_such_route' });
      return;
    }
    try {
      const result = await route.handler(req, route.params, url);
      if (result.binary) {
        sendBinary(res, result.binary.status ?? 200, result.binary);
        return;
      }
      sendJson(res, result.status ?? 200, result.body ?? {});
    } catch (error) {
      if (error instanceof HttpError) {
        sendJson(res, error.status, { error: error.code, message: error.message });
        return;
      }
      console.error('unhandled', error);
      sendJson(res, 500, { error: 'internal_error' });
    }
  };

  return { handle, store, live, media, db, router };
}
