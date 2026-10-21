import { config, revealsOtp } from './config.js';
import { openDatabase } from './db/db.js';
import {
  intentsMeet,
  normaliseIntent,
  preferencesGateDiscovery,
} from './domain/intent.js';
import {
  FaceClient,
  FaceServiceUnavailable,
  judgeLiveAttempt,
  judgeProfilePhoto,
  LiveChallengeStore,
  TemplateSealer,
} from './domain/face.js';
import { normaliseVenue, PresenceStore } from './domain/presence.js';
import {
  ChallengeStore,
  findPose,
  POSES,
} from './domain/verification.js';
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
import { insideVenue, readPosition } from './lib/geo.js';
import { PhotoStore, readBinaryBody, sniffImage } from './lib/media.js';
import { adminPage } from './lib/admin_page.js';
import { StaticSite } from './lib/static.js';
import {
  notifyIncomingUp,
  notifyMatch,
  notifyNewMessage,
  notifyVenueEnding,
  pushConfigured,
} from './push.js';
import { randomBytes } from 'node:crypto';
import { dirname, join } from 'node:path';
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
/**
 * The photos other people may see: checked against the owner's face, or
 * uploaded before checks existed. Anything waiting, unverified or rejected
 * stays visible to its owner only.
 */
function visiblePhotos(store, userId, profile) {
  const photos = JSON.parse(profile?.photos ?? '[]');
  const checks = store.photoChecks(userId);
  return photos.filter((key) => checks[key] === undefined || checks[key] === 'ok');
}

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
    photos: visiblePhotos(store, user.id, profile),
    photoVerified: store.realityBadge(user.id),
    // A different claim from `photoVerified`, and worth its own field. That
    // one is other people's opinion after meeting you; this one is somebody
    // having looked at a selfie in a pose this person could not have known in
    // advance. Neither substitutes for the other.
    selfieVerified: store.isSelfieVerified(user.id),
    // 'live' (automatic face check) or 'manual' (a human looked), or null.
    verifiedBy: store.verificationMethod(user.id),
  };
}

function privateProfile(store, user, profile) {
  return {
    ...publicProfile(store, user, profile),
    // Your own profile shows every photo, with what the face check said.
    photos: JSON.parse(profile?.photos ?? '[]'),
    photoChecks: store.photoChecks(user.id),
    phone: user.phone,
    gender: user.gender,
    interestedIn: user.interested_in,
    birthDate: user.birth_date,
    termsAcceptedAt: user.terms_accepted_at,
  };
}

export function createApp({
  database = ':memory:',
  presence,
  photos,
  selfies,
  site,
  face,
  sealer,
} = {}) {
  const db = openDatabase(database);
  const store = new Store(db);
  const live = presence ?? new PresenceStore();
  const media = photos ?? new PhotoStore();
  // A store of its own, unreachable from `GET /media/:key`. See
  // `config.verification.directory` for why that separation is the point.
  const selfieStore = selfies ?? new PhotoStore(config.verification.directory);
  const challenges = new ChallengeStore({
    ttlSeconds: config.verification.challengeTtlSeconds,
  });
  const web = site ?? new StaticSite(config.siteDirectory);
  const faces = face ?? new FaceClient();
  const templates =
    sealer ??
    new TemplateSealer({
      keyFile:
        config.face.keyFile ||
        (database === ':memory:' ? '' : join(dirname(database), '.face-key')),
    });
  const liveChallenges = new LiveChallengeStore();

  const faceUnavailable = () => new HttpError(503, 'face_service_unavailable');

  /** The person's verified face, or null. */
  const templateFor = (userId) => {
    const row = store.findFaceTemplate(userId);
    if (!row || row.model !== config.face.model) return null;
    return templates.open(row.embedding);
  };

  /**
   * Re-checks a person's photos against a template that has just appeared.
   *
   * Photos uploaded before verification were saved as `unverified` (or never
   * checked at all); now there is a face to compare them with. Ones that do
   * not match are hidden, not deleted — the owner sees why and decides.
   */
  const recheckPhotos = async (userId) => {
    const template = templateFor(userId);
    if (!template) return;
    const photos = JSON.parse(store.findProfile(userId)?.photos ?? '[]');
    const checks = store.photoChecks(userId);
    for (const key of photos) {
      const current = checks[key];
      if (current === 'ok' || current === 'review') continue;
      const file = media.open(key);
      if (!file) continue;
      try {
        const verdict = judgeProfilePhoto(await faces.analyze(file.body), template);
        const status =
          verdict.result === 'ok' ? 'ok' : verdict.result === 'review' ? 'review' : 'rejected';
        store.setPhotoCheck(userId, key, status, verdict.score);
      } catch {
        return; // face-svc down: leave the rest for the next attempt.
      }
    }
  };
  const recheckLater = (userId) => {
    recheckPhotos(userId).catch(() => {});
  };
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
    if (!sniffImage(body)) throw badRequest('not_an_image');

    // The face check runs before anything is written. A photo that is not
    // the verified person never touches the disk.
    // No verified face yet: nothing to compare with, so no check is recorded
    // and the photo is treated like any unchecked one. Verifying later runs
    // the comparison over everything already uploaded (see recheckPhotos).
    const template = templateFor(user.id);
    let faceMatch = null;
    let score = null;
    if (template) {
      let verdict;
      try {
        verdict = judgeProfilePhoto(await faces.analyze(body), template);
      } catch (error) {
        if (error instanceof FaceServiceUnavailable) throw faceUnavailable();
        throw error;
      }
      if (verdict.result === 'no_face') throw badRequest('photo_no_face');
      if (verdict.result === 'mismatch') throw badRequest('photo_face_mismatch');
      faceMatch = verdict.result;
      score = verdict.score;
    }

    const saved = media.save(body);
    const result = store.addPhoto(user.id, saved.key);
    if (!result.added) {
      // Losing the race for the last slot should not leave an orphan on disk.
      media.remove(saved.key);
      throw badRequest('photo_limit_reached');
    }
    if (faceMatch) store.setPhotoCheck(user.id, saved.key, faceMatch, score);
    return {
      status: 200,
      body: { key: saved.key, photos: result.photos, faceMatch },
    };
  });

  /** Makes one photo the main one — first everywhere it is shown. */
  router.put('/me/photos/primary', async (req) => {
    const user = requireUser(req);
    const body = await readJsonBody(req);
    const key = str(body.key, 64);
    if (store.photoChecks(user.id)[key] === 'rejected') {
      throw badRequest('photo_not_approved');
    }
    const result = store.setPrimaryPhoto(user.id, key);
    if (!result.updated) throw notFound('photo_not_found');
    return { status: 200, body: { photos: result.photos } };
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
    store.removePhotoCheck(params.key);
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

  /**
   * Going Live, in one of three ways.
   *
   * - **At a venue** (`venue` + location): the code came off a QR on the wall,
   *   and the phone has to be inside that place's radius. One hour, then scan
   *   again. An unregistered code is refused — a code anyone can type from
   *   home is not a room.
   * - **In the area** (location only): everyone else in area mode within
   *   `config.area.radiusM`.
   * - **Radio only** (neither): BLE tokens, for the native app.
   *
   * The location is used for the check and then dropped; an area session keeps
   * its last position in memory, for its own lifetime, and never sends it.
   */
  router.post('/live/start', async (req) => {
    const user = requireUser(req);
    if (!isOfAge(user.birth_date)) throw forbidden('profile_incomplete');
    if (config.live.requireVerification && !store.isSelfieVerified(user.id)) {
      throw forbidden('verification_required');
    }
    const body = await readJsonBody(req);
    const position = readPosition(body, config.venues.maxAcceptedAccuracyM);
    const options = { intent: body.intent, note: body.note };
    let seconds = Number(body.durationSeconds) || 3600;
    let venueRow = null;

    if (body.venue !== undefined && body.venue !== null && body.venue !== '') {
      const code = normaliseVenue(String(body.venue));
      venueRow = code ? store.findVenue(code) : null;
      if (!venueRow || !venueRow.active) throw notFound('venue_unknown');
      if (!position) throw badRequest('location_required');
      if (!insideVenue(position, venueRow, config.venues.maxAccuracyCreditM)) {
        throw forbidden('too_far');
      }
      options.venue = venueRow.code;
      options.venueName = venueRow.name;
      seconds = config.venues.sessionSeconds;
      options.maxSeconds = config.venues.sessionSeconds;
    } else if (body.lat !== undefined || body.lng !== undefined || body.mode === 'area') {
      if (!position) throw badRequest('location_required');
      options.position = position;
    }

    const { session, tokens } = live.startLive(user.id, seconds, options);
    return {
      status: 200,
      body: {
        sessionId: session.id,
        expiresAt: new Date(session.expiresAt).toISOString(),
        // Echoed back normalised so the client can show the key it actually
        // joined rather than the characters the user typed. The same goes for
        // the intent and the note: an unknown intent silently becomes "meet",
        // and the phone has to be told which one it got.
        venue: session.venue,
        venueName: session.venueName,
        mode: session.venue ? 'venue' : session.position ? 'area' : 'radio',
        intent: session.intent,
        note: session.note,
        tokens,
      },
    };
  });

  /** The name of a registered place, for the screen that asks to join it. */
  router.get('/venues/:code', async (req, params) => {
    requireUser(req);
    const code = normaliseVenue(params.code);
    const venue = code ? store.findVenue(code) : null;
    if (!venue || !venue.active) throw notFound('venue_unknown');
    return {
      status: 200,
      body: { code: venue.code, name: venue.name, sessionMinutes: config.venues.sessionSeconds / 60 },
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

    const session = live.activeSession(user.id);
    if (!session) throw forbidden('not_live');
    // Area mode follows the phone. A fix that is missing or too vague changes
    // nothing — the last good one stands.
    const position = readPosition(body, config.venues.maxAcceptedAccuracyM);
    if (position) live.updatePosition(user.id, position);

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
      // Hidden for this visit. Back next time.
      if (live.hasHidden(user.id, otherId)) return;

      const otherSession = live.activeSession(otherId);
      if (!otherSession) return;
      // Same reason for being here, or you do not see each other at all.
      if (!intentsMeet(otherSession.intent, session.intent)) return;
      // Gender preference gates dating and nothing else. Applying it to a
      // five-a-side game or a professional meetup made half of every room
      // invisible for a reason nobody could have explained to the people in
      // it — which is why this app read as a dating app even when it was not
      // being used as one.
      if (preferencesGateDiscovery(session.intent) && !mutuallyCompatible(user, other)) {
        return;
      }

      people.push({
        ...publicProfile(store, other, store.findProfile(otherId)),
        // What they are doing right now, in their words. Dies with their
        // session, which is the only reason it can be this specific.
        note: otherSession.note,
        // Two facts about *this pair*, and the only two the caller is party to.
        //
        // `sentYouUp` is the whole point of an UP: without it the person who
        // received one has no way to know, and the feature is a button that
        // does nothing anybody can observe. It is not a leak of the sender's
        // intent — telling the recipient is what sending means. What stays
        // hidden is the other direction, which is why `/likes` still answers a
        // sender with nothing about the person they sent to.
        //
        // `youSentUp` is the caller's own action reflected back, so the "UP
        // sent" state survives a reload instead of living in the app's memory
        // until the page is refreshed.
        sentYouUp: store.hasLiked(otherId, user.id),
        youSentUp: store.hasLiked(user.id, otherId),
      });
    };

    for (const raw of tokens) {
      if (typeof raw !== 'string') continue;
      admit(live.resolveToken(raw));
    }
    const peers = [...live.venuePeers(user.id), ...live.areaPeers(user.id)];
    for (const peerId of peers) {
      admit(peerId);
    }

    return {
      status: 200,
      body: {
        people,
        // A coarse count so the home screen can say "3 people nearby" without
        // any of them being identifiable.
        liveNearbyCount: people.length,
        // The room this session actually joined, and how many other people are
        // live in it. Not a nicety: without them "nobody is here" is
        // indistinguishable from "you never joined the room" and from "you are
        // both here but your preferences rule each other out", and a person
        // holding a phone cannot tell those apart by staring at an empty list.
        // A count carries no identity — a venue key is a label two people
        // already agreed on, and everyone counted here typed it themselves.
        room: session.venue,
        roomName: session.venueName,
        mode: session.venue ? 'venue' : session.position ? 'area' : 'radio',
        expiresAt: new Date(session.expiresAt).toISOString(),
        roomPeers: peers.length,
        // Echoed so a phone that reconnected mid-session knows which room it
        // is actually in — the answer to "why is this list empty" is usually
        // one of these two fields.
        intent: session.intent,
        self: { firstName: profile?.first_name ?? '' },
      },
    };
  });

  /**
   * Rooms that already have people in them.
   *
   * Typing a code is a fine way to join a room somebody told you about and a
   * useless way to find one: a person standing in a bar has nothing to type.
   * This is the other half — the rooms that exist right now, for the intent
   * you are about to go Live with.
   *
   * Signing in is required, and the response holds counts only. A room key is
   * a label people agreed on rather than a secret, but listing one that holds
   * a single person would turn that label into a way to locate them, so those
   * are not listed at all.
   */
  router.get('/rooms', async (req, _params, url) => {
    requireUser(req);
    const intent = normaliseIntent(url.searchParams.get('intent'));
    return { status: 200, body: { intent, rooms: live.rooms(intent) } };
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
    if (result.outcome === 'recorded' && live.isLive(targetId)) {
      // Someone in the same room just sent you an UP. Worth a buzz: they are
      // here, now, and the whole point is that you can look up.
      notifyIncomingUp(store, { recipientId: targetId });
    }
    if (result.match) {
      // Only the other person is told. The sender is looking at the match
      // screen this call just produced.
      notifyMatch(store, {
        recipientId: targetId,
        otherName: store.findProfile(user.id)?.first_name ?? '',
        matchId: result.match.id,
      });
    }
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

    // Not awaited, deliberately: the message is saved, the app polls, and a
    // push service having a bad minute must never turn a successful send into
    // an error on the sender's screen.
    const recipientId = otherSide(match, user);
    notifyNewMessage(store, {
      recipientId,
      senderName: store.findProfile(user.id)?.first_name ?? '',
      body: message.body,
      matchId: match.id,
    });

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

  /** Unblocks. What the block deleted — UPs, a match — does not come back. */
  router.delete('/users/:id/block', async (req, params) => {
    const user = requireUser(req);
    const removed = store.unblock(user.id, params.id);
    if (!removed) throw notFound('not_blocked');
    return { status: 200, body: { blocked: false } };
  });

  router.get('/me/blocks', async (req) => {
    const user = requireUser(req);
    return {
      status: 200,
      body: {
        blocked: store.listBlocked(user.id).map((row) => ({
          id: row.id,
          firstName: row.first_name ?? '',
          // Their main photo, so the list is recognisable. The photo route
          // still serves it only to a signed-in caller.
          photo: JSON.parse(row.photos ?? '[]')[0] ?? null,
          blockedAt: row.created_at,
        })),
      },
    };
  });

  /**
   * Hides someone until this visit ends.
   *
   * The next time both are live in the same place, they show up again — the
   * difference from a block, which is forever until lifted.
   */
  router.post('/users/:id/hide', async (req, params) => {
    const user = requireUser(req);
    if (params.id === user.id) throw badRequest('cannot_hide_self');
    if (!live.hide(user.id, params.id)) throw badRequest('not_live');
    return { status: 200, body: { hidden: true } };
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

  // -- photo verification ---------------------------------------------------

  /**
   * Asks for a pose.
   *
   * The pose comes from here and nowhere else, seconds before the photo, which
   * is the entire security property: a person cannot prepare a picture for a
   * pose they have not been told yet. Everything downstream — the camera, the
   * review — is about raising cost, not about proof.
   */
  router.post('/me/verification/challenge', async (req) => {
    const user = requireUser(req);
    const body = await readJsonBody(req);

    if (body.mode === 'live') {
      // Biometric data is "special category" data. No template without an
      // explicit yes, and the manual route below stays open for anyone who
      // says no.
      if (!user.biometric_consent_at) throw forbidden('consent_required');
      if (
        store.countRecentLiveAttempts(user.id, hoursAgo(24)) >= config.face.attemptsPerDay
      ) {
        throw tooManyRequests('too_many_attempts');
      }
      const challenge = liveChallenges.issue(user.id);
      return {
        status: 200,
        body: {
          challengeId: challenge.id,
          mode: 'live',
          steps: challenge.steps,
          expiresAt: new Date(challenge.expiresAt).toISOString(),
        },
      };
    }

    const challenge = challenges.issue(user.id);
    const pose = findPose(challenge.pose);
    return {
      status: 200,
      body: {
        challengeId: challenge.id,
        mode: 'manual',
        pose: challenge.pose,
        // Both languages: the app decides which to show, and a pose nobody can
        // read is a pose nobody can strike.
        instructionHe: pose?.he ?? '',
        instructionEn: pose?.en ?? '',
        expiresAt: new Date(challenge.expiresAt).toISOString(),
      },
    };
  });

  router.post('/me/biometric/consent', async (req) => {
    const user = requireUser(req);
    const body = await readJsonBody(req);
    if (body.accepted !== true) throw badRequest('consent_not_given');
    store.recordBiometricConsent(user.id);
    return { status: 200, body: { consent: true } };
  });

  router.delete('/me/biometric', async (req) => {
    const user = requireUser(req);
    store.deleteBiometrics(user.id);
    return { status: 200, body: { deleted: true } };
  });

  /**
   * The live check: one frame per step, taken by the app's own camera
   * preview, judged here.
   *
   * Frames arrive as base64 in one JSON body and leave memory when this
   * request does — except the single centre frame of a borderline attempt,
   * which waits in the review directory for a human and is deleted when they
   * decide.
   */
  router.post('/me/verification/frames', async (req) => {
    const user = requireUser(req);
    const body = await readJsonBody(req, 24 * 1024 * 1024);
    const challenge = liveChallenges.take(user.id, str(body.challengeId, 64));
    if (!challenge) throw badRequest('challenge_expired');

    const frames = Array.isArray(body.frames) ? body.frames : [];
    if (frames.length !== challenge.steps.length) throw badRequest('wrong_frame_count');
    const images = frames.map((f) => Buffer.from(typeof f === 'string' ? f : '', 'base64'));
    if (images.some((img) => !sniffImage(img))) throw badRequest('not_an_image');

    const analyses = [];
    try {
      for (const img of images) analyses.push(await faces.analyze(img));
    } catch (error) {
      if (error instanceof FaceServiceUnavailable) throw faceUnavailable();
      throw error;
    }

    const verdict = judgeLiveAttempt(challenge.steps, analyses);
    if (verdict.status === 'rejected') {
      store.recordLiveVerification(user.id, { status: 'rejected', reason: verdict.reason });
      return { status: 200, body: { status: 'rejected', reason: verdict.reason } };
    }

    store.saveFaceTemplate(user.id, templates.seal(verdict.template), config.face.model);

    if (verdict.status === 'pending') {
      const saved = selfieStore.save(images[verdict.centerIndex]);
      const result = store.recordLiveVerification(user.id, {
        status: 'pending',
        reason: verdict.reason,
        score: verdict.score,
        storageKey: saved.key,
      });
      if (result.replacedKey) selfieStore.remove(result.replacedKey);
      return { status: 200, body: { status: 'pending' } };
    }

    store.recordLiveVerification(user.id, { status: 'approved', score: verdict.score });
    recheckLater(user.id);
    return { status: 200, body: { status: 'approved' } };
  });

  /**
   * The selfie itself. Raw bytes, exactly like a profile photo.
   *
   * Stored in a directory the public media route cannot reach, and deleted the
   * moment somebody decides — see `Store.decideVerification`.
   */
  router.post('/me/verification/selfie', async (req, _params, url) => {
    const user = requireUser(req);
    const challengeId = url.searchParams.get('challenge') ?? '';
    const challenge = challenges.take(user.id, challengeId);
    // Expired, already used, or for a different pose than the one asked for.
    // One error for all three: telling them apart helps nobody but an attacker.
    if (!challenge) throw badRequest('challenge_expired');

    const body = await readBinaryBody(req);
    if (body.length === 0) throw badRequest('empty_body');

    const saved = selfieStore.save(body);
    const result = store.submitVerification(user.id, {
      pose: challenge.pose,
      storageKey: saved.key,
    });
    // An attempt this person has already replaced should not sit on disk
    // waiting for a review that will never come.
    if (result.replacedKey) selfieStore.remove(result.replacedKey);

    return { status: 201, body: { status: 'pending' } };
  });

  router.get('/me/verification', async (req) => {
    const user = requireUser(req);
    const latest = store.latestVerification(user.id);
    const approved = store.isSelfieVerified(user.id);
    return {
      status: 200,
      body: {
        // "approved" wins over a later rejected attempt: the badge is a fact
        // about the person, and it does not come and go with a bad photograph.
        status: approved
          ? 'approved'
          : latest?.status === 'revoked'
            ? 'none'
            : (latest?.status ?? 'none'),
        submittedAt: latest?.created_at ?? null,
        reason: approved ? null : (latest?.reason ?? null),
        method: store.verificationMethod(user.id),
        consent: Boolean(user.biometric_consent_at),
        hasTemplate: Boolean(store.findFaceTemplate(user.id)),
        poses: POSES.map((pose) => pose.key),
      },
    };
  });

  // -- review (operator only) ------------------------------------------------

  /**
   * A shared key rather than an account role.
   *
   * There is exactly one operator and no admin UI to speak of, so a role
   * column, a permissions table and an audit trail would all be scaffolding
   * around a person checking photographs on a laptop. An unset key disables
   * these routes entirely — a deployment that forgot to configure one has no
   * review queue rather than an open one.
   */
  const requireOperator = (req) => {
    if (!config.adminToken) throw notFound('no_such_route');
    const offered = req.headers['x-admin-token'];
    if (typeof offered !== 'string' || !safeEqual(offered, config.adminToken)) {
      throw unauthorized();
    }
  };

  router.get('/admin/verifications', async (req) => {
    requireOperator(req);
    return {
      status: 200,
      body: {
        pending: store.pendingVerifications().map((row) => ({
          id: row.id,
          pose: row.pose,
          method: row.method,
          score: row.score,
          reason: row.reason,
          instruction:
            row.method === 'live'
              ? 'בדיקת פנים חיה — גבולית'
              : (findPose(row.pose)?.he ?? row.pose),
          firstName: row.first_name ?? '',
          // The profile photos, to compare the face against. This is the whole
          // job: is the person in the selfie the person in the profile.
          photos: JSON.parse(row.photos ?? '[]'),
          selfie: row.storage_key,
          createdAt: row.created_at,
        })),
      },
    };
  });

  /** The selfie, for the review screen only. Never reachable via `/media`. */
  router.get('/admin/verifications/:key/photo', async (req, params) => {
    requireOperator(req);
    const file = selfieStore.open(params.key);
    if (!file) throw notFound('photo_not_found');
    return { binary: { status: 200, ...file } };
  });

  router.post('/admin/verifications/:id/decide', async (req, params) => {
    requireOperator(req);
    const body = await readJsonBody(req);
    const status = body.approve === true ? 'approved' : 'rejected';
    const row = store.findVerification(params.id);
    const decided = store.decideVerification(params.id, status);
    if (!decided) throw notFound('verification_not_found');
    if (row?.method === 'live') {
      // A rejected borderline attempt leaves no face behind; an approved one
      // turns on photo checks for everything already uploaded.
      if (status === 'rejected') store.deleteBiometrics(decided.userId);
      else recheckLater(decided.userId);
    }
    // The photograph has done its job. Keeping a library of face photographs
    // taken on demand is a liability that grows every day and protects nobody.
    if (decided.key) selfieStore.remove(decided.key);
    return { status: 200, body: { status } };
  });

  router.get('/admin/photo-reviews', async (req) => {
    requireOperator(req);
    return {
      status: 200,
      body: {
        pending: store.pendingPhotoReviews().map((row) => ({
          key: row.storage_key,
          userId: row.user_id,
          firstName: row.first_name ?? '',
          score: row.score,
          checkedAt: row.checked_at,
        })),
      },
    };
  });

  router.get('/admin/photos/:key', async (req, params) => {
    requireOperator(req);
    const file = media.open(params.key);
    if (!file) throw notFound('photo_not_found');
    return { binary: { status: 200, ...file } };
  });

  router.post('/admin/photo-reviews/:key/decide', async (req, params) => {
    requireOperator(req);
    const body = await readJsonBody(req);
    const check = store.findPhotoCheck(params.key);
    if (!check || check.face_match !== 'review') throw notFound('review_not_found');
    store.setPhotoCheck(check.user_id, params.key, body.approve === true ? 'ok' : 'rejected', check.score);
    return { status: 200, body: { status: body.approve === true ? 'ok' : 'rejected' } };
  });

  // -- venues (operator) -------------------------------------------------------

  const venueJson = (v) => ({
    code: v.code,
    name: v.name,
    lat: v.lat,
    lng: v.lng,
    radiusM: v.radius_m,
    active: Boolean(v.active),
    createdAt: v.created_at,
    // What goes on the sticker. Scanning it opens the app on the join screen;
    // the phone's location is what actually lets you in.
    joinUrl: `${config.publicUrl}/?venue=${v.code}`,
    live: live.rooms('meet', { minimum: 1, limit: 1000 }).find((r) => r.code === v.code)?.people ?? 0,
  });

  const readVenueFields = (body, { partial = false } = {}) => {
    const fields = {};
    if (body.name !== undefined || !partial) {
      const name = str(body.name, 60);
      if (!name) throw badRequest('name_required');
      fields.name = name;
    }
    if (body.lat !== undefined || body.lng !== undefined || !partial) {
      const lat = Number(body.lat);
      const lng = Number(body.lng);
      if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) {
        throw badRequest('invalid_location');
      }
      fields.lat = lat;
      fields.lng = lng;
    }
    if (body.radiusM !== undefined || !partial) {
      const radius = Math.round(Number(body.radiusM ?? config.venues.defaultRadiusM));
      if (!Number.isFinite(radius) || radius < 20 || radius > 2000) throw badRequest('invalid_radius');
      fields.radius_m = radius;
    }
    if (body.active !== undefined) fields.active = body.active === true;
    return fields;
  };

  router.get('/admin/venues', async (req) => {
    requireOperator(req);
    return { status: 200, body: { venues: store.listVenues().map(venueJson) } };
  });

  router.post('/admin/venues', async (req) => {
    requireOperator(req);
    const body = await readJsonBody(req);
    const fields = readVenueFields(body);
    let code = body.code ? normaliseVenue(String(body.code)) : null;
    if (body.code && !code) throw badRequest('invalid_code');
    if (!code) {
      // Names are usually Hebrew; the code is what fits in a URL.
      const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      do {
        code = Array.from(randomBytes(6), (b) => alphabet[b % alphabet.length]).join('');
      } while (store.findVenue(code));
    }
    if (store.findVenue(code)) throw badRequest('code_taken');
    const venue = store.createVenue({
      code,
      name: fields.name,
      lat: fields.lat,
      lng: fields.lng,
      radiusM: fields.radius_m,
    });
    return { status: 201, body: venueJson(venue) };
  });

  router.patch('/admin/venues/:code', async (req, params) => {
    requireOperator(req);
    const body = await readJsonBody(req);
    const venue = store.updateVenue(params.code, readVenueFields(body, { partial: true }));
    if (!venue) throw notFound('venue_unknown');
    return { status: 200, body: venueJson(venue) };
  });

  router.delete('/admin/venues/:code', async (req, params) => {
    requireOperator(req);
    if (!store.deleteVenue(params.code)) throw notFound('venue_unknown');
    return { status: 200, body: { deleted: true } };
  });

  /**
   * The operator's page: places and their stickers, and the review queue.
   * The page itself is public HTML with nothing in it; every action it takes
   * goes through the routes above with the admin key.
   */
  router.get('/admin', async () => ({
    html: adminPage(),
  }));

  // -- notifications -------------------------------------------------------

  /**
   * The public half of the signing key, so a browser can subscribe.
   *
   * Unauthenticated on purpose: it is public by definition — it ends up baked
   * into every subscription — and the app needs it before it has decided
   * whether to ask for permission at all. An empty key means the deployment
   * has no notifications configured, which the app reads as "do not offer it"
   * rather than as an error.
   */
  router.get('/push/key', async () => ({
    status: 200,
    body: { publicKey: pushConfigured() ? config.vapid.publicKey : '' },
  }));

  router.post('/push/subscribe', async (req) => {
    const user = requireUser(req);
    if (!pushConfigured()) throw badRequest('push_unavailable');
    const body = await readJsonBody(req);
    const endpoint = str(body.endpoint, 1000);
    const p256dh = str(body.p256dh, 200);
    const auth = str(body.auth, 100);
    if (!endpoint || !p256dh || !auth) throw badRequest('invalid_subscription');
    // The endpoint is a URL this server will later POST to. Refusing anything
    // that is not an https push endpoint keeps it from being pointed at an
    // internal address.
    let parsed;
    try {
      parsed = new URL(endpoint);
    } catch {
      throw badRequest('invalid_subscription');
    }
    if (parsed.protocol !== 'https:') throw badRequest('invalid_subscription');

    store.savePushSubscription(user.id, { endpoint, p256dh, auth });
    return { status: 200, body: { subscribed: true } };
  });

  router.post('/push/unsubscribe', async (req) => {
    const user = requireUser(req);
    const body = await readJsonBody(req);
    const endpoint = str(body.endpoint, 1000);
    if (!endpoint) throw badRequest('invalid_subscription');
    // Scoped to this user's own rows: an endpoint is a bearer-ish string, and
    // knowing one must not let anyone silence somebody else's phone.
    const mine = store
      .listPushSubscriptions(user.id)
      .some((row) => row.endpoint === endpoint);
    if (mine) store.deletePushSubscription(endpoint);
    return { status: 200, body: { unsubscribed: true } };
  });

  router.get('/health', async () => ({
    status: 200,
    body: { ok: true, liveUsers: live.liveUserCount, env: config.env },
  }));

  /**
   * Prints every refusal, with its machine-readable code.
   *
   * The app deliberately collapses unknown codes into one sentence, because a
   * person cannot act on `gender_and_preference_required`. That is right for
   * the user and useless for whoever has to fix it: "something went wrong" on a
   * phone in another room is unfalsifiable. This is the other half — the code
   * the phone saw, on the machine running the server.
   *
   * Method, path and code only. No bodies, no tokens, no phone numbers: a log
   * that quietly accumulates people's credentials is a worse problem than the
   * one it solves.
   */
  const logRefusal = (req, url, status, code) => {
    console.log(`[refused] ${req.method} ${url.pathname} -> ${status} ${code ?? ''}`);
  };

  /** Node http handler. */
  const handle = async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    const route = router.match(req.method, url.pathname);
    if (!route) {
      // Not an API route. If a web build is present, this is the app itself
      // being asked for — every unknown GET is one of its screens.
      if (req.method === 'GET' && web.exists) {
        const file = web.read(url.pathname);
        if (file) {
          if (req.headers['if-none-match'] === file.etag) {
            sendBinary(res, 304, { ...file, body: Buffer.alloc(0) });
            return;
          }
          sendBinary(res, 200, file);
          return;
        }
      }
      sendJson(res, 404, { error: 'no_such_route' });
      return;
    }
    try {
      const result = await route.handler(req, route.params, url);
      if (result.binary) {
        sendBinary(res, result.binary.status ?? 200, result.binary);
        return;
      }
      if (result.html !== undefined) {
        const html = Buffer.from(result.html, 'utf8');
        res.writeHead(200, {
          'content-type': 'text/html; charset=utf-8',
          'content-length': html.length,
          'cache-control': 'no-store',
          'x-content-type-options': 'nosniff',
          'x-frame-options': 'DENY',
          'referrer-policy': 'no-referrer',
        });
        res.end(html);
        return;
      }
      if ((result.status ?? 200) >= 400) {
        logRefusal(req, url, result.status, result.body?.error);
      }
      sendJson(res, result.status ?? 200, result.body ?? {});
    } catch (error) {
      if (error instanceof HttpError) {
        logRefusal(req, url, error.status, error.code);
        sendJson(res, error.status, { error: error.code, message: error.message });
        return;
      }
      console.error('unhandled', error);
      sendJson(res, 500, { error: 'internal_error' });
    }
  };

  /** Called by the sweeper: "your hour here is nearly up — scan again". */
  const remindVenueEndings = () => {
    for (const session of live.takeDueReminders(config.venues.remindBeforeSeconds * 1000)) {
      notifyVenueEnding(store, {
        recipientId: session.userId,
        venueName: session.venueName ?? session.venue,
      });
    }
    liveChallenges.sweep();
  };

  return { handle, store, live, media, web, db, router, remindVenueEndings };
}
