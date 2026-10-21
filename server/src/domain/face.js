import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

import { config } from '../config.js';
import { newId } from '../lib/crypto.js';

/**
 * Face checks: talking to face-svc, and deciding.
 *
 * face-svc reports (boxes, landmarks, yaw, blur, embeddings); everything that
 * is a *decision* — is this the same person, did they turn, is the photo them
 * — lives here, next to the thresholds in `config.face`. Spec:
 * docs/FACE_VERIFICATION_SPEC.md.
 *
 * Nothing in this file logs a score, an embedding or an image.
 */

export class FaceServiceUnavailable extends Error {
  constructor() {
    super('face_service_unavailable');
  }
}

/** Calls face-svc. Throws `FaceServiceUnavailable` for any transport problem. */
export class FaceClient {
  constructor({ url = config.face.serviceUrl, timeoutMs = config.face.timeoutMs } = {}) {
    this.url = url.replace(/\/+$/, '');
    this.timeoutMs = timeoutMs;
  }

  async analyze(bytes) {
    let response;
    try {
      response = await fetch(`${this.url}/analyze`, {
        method: 'POST',
        headers: { 'content-type': 'application/octet-stream' },
        body: bytes,
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch {
      throw new FaceServiceUnavailable();
    }
    if (response.status === 400 || response.status === 413) {
      // Not an image it could read. Same as "no face" for every caller.
      return { width: 0, height: 0, faces: [] };
    }
    if (!response.ok) throw new FaceServiceUnavailable();
    const json = await response.json();
    return {
      width: Number(json.width) || 0,
      height: Number(json.height) || 0,
      faces: (Array.isArray(json.faces) ? json.faces : []).map((f) => ({
        box: f.box,
        score: Number(f.score) || 0,
        yaw: Number(f.yaw) || 0,
        pitch: Number(f.pitch) || 0,
        blur: Number(f.blur) || 0,
        embedding: decodeEmbedding(f.embedding),
      })),
    };
  }
}

export function decodeEmbedding(b64) {
  if (typeof b64 !== 'string') return null;
  const buf = Buffer.from(b64, 'base64');
  if (buf.length !== 128 * 4) return null;
  const out = new Float32Array(128);
  for (let i = 0; i < 128; i++) out[i] = buf.readFloatLE(i * 4);
  return out;
}

export function cosine(a, b) {
  if (!a || !b || a.length !== b.length) return -1;
  let dot = 0;
  let na = 0;
  let nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return na && nb ? dot / Math.sqrt(na * nb) : -1;
}

export function meanTemplate(embeddings) {
  const out = new Float32Array(128);
  for (const e of embeddings) for (let i = 0; i < 128; i++) out[i] += e[i];
  let norm = 0;
  for (let i = 0; i < 128; i++) norm += out[i] * out[i];
  norm = Math.sqrt(norm) || 1;
  for (let i = 0; i < 128; i++) out[i] /= norm;
  return out;
}

// -- template sealing ---------------------------------------------------------

/**
 * AES-256-GCM with a key that lives in a file beside the database.
 *
 * A leaked database without the key file holds no usable faces. The key is
 * created on first use; losing it costs everybody one re-verification, never
 * a face.
 */
export class TemplateSealer {
  constructor({ keyFile = '', key = null } = {}) {
    if (key) {
      this.key = key;
    } else if (keyFile) {
      if (!existsSync(keyFile)) {
        mkdirSync(dirname(keyFile), { recursive: true });
        writeFileSync(keyFile, randomBytes(32).toString('hex'), { mode: 0o600 });
      }
      this.key = Buffer.from(readFileSync(keyFile, 'utf8').trim(), 'hex');
    } else {
      this.key = randomBytes(32);
    }
    if (this.key.length !== 32) throw new Error('face key must be 32 bytes');
  }

  seal(embedding) {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    const plain = Buffer.from(embedding.buffer, embedding.byteOffset, embedding.byteLength);
    const body = Buffer.concat([cipher.update(plain), cipher.final()]);
    return Buffer.concat([iv, cipher.getAuthTag(), body]);
  }

  open(sealed) {
    try {
      const buf = Buffer.from(sealed);
      const decipher = createDecipheriv('aes-256-gcm', this.key, buf.subarray(0, 12));
      decipher.setAuthTag(buf.subarray(12, 28));
      const plain = Buffer.concat([decipher.update(buf.subarray(28)), decipher.final()]);
      const out = new Float32Array(128);
      for (let i = 0; i < 128; i++) out[i] = plain.readFloatLE(i * 4);
      return out;
    } catch {
      return null;
    }
  }
}

// -- live challenge ---------------------------------------------------------

/**
 * A head-turn sequence, issued by the server seconds before the camera opens.
 *
 * Always starts and ends facing the camera, with left and right in a random
 * order in between — a recorded clip or a still photo cannot follow a
 * sequence it did not know.
 */
export class LiveChallengeStore {
  constructor({ now = () => Date.now(), ttlSeconds = config.face.liveTtlSeconds, random = Math.random } = {}) {
    this._now = now;
    this._ttl = ttlSeconds * 1000;
    this._random = random;
    this._byUser = new Map();
  }

  issue(userId) {
    const turns = this._random() < 0.5 ? ['left', 'right'] : ['right', 'left'];
    const steps = ['center', turns[0], 'center', turns[1]];
    const challenge = { id: newId(), steps, expiresAt: this._now() + this._ttl };
    this._byUser.set(userId, challenge);
    return challenge;
  }

  take(userId, challengeId) {
    const challenge = this._byUser.get(userId);
    if (!challenge) return null;
    if (challenge.id !== challengeId) return null;
    this._byUser.delete(userId);
    if (challenge.expiresAt <= this._now()) return null;
    return challenge;
  }

  sweep() {
    const now = this._now();
    for (const [userId, c] of this._byUser) if (c.expiresAt <= now) this._byUser.delete(userId);
  }
}

/**
 * Judges one live attempt.
 *
 * `analyses[i]` is face-svc's answer for frame i of `steps`. Returns
 * `{ status: 'approved' | 'pending' | 'rejected', reason?, template?, centerIndex }`.
 *
 * Left and right are checked under one consistent mapping, either way round:
 * some browsers mirror the front camera and some do not, and a person must not
 * fail because their phone flipped the picture. Every turn has to agree with
 * the same mapping, so this is no weaker against a still photograph.
 */
export function judgeLiveAttempt(steps, analyses, t = config.face) {
  if (analyses.length !== steps.length) return { status: 'rejected', reason: 'wrong_frame_count' };

  const faces = [];
  for (const a of analyses) {
    const good = a.faces.filter((f) => f.score >= t.minScore && f.embedding);
    if (good.length === 0) return { status: 'rejected', reason: 'no_face' };
    if (good.length > 1) return { status: 'rejected', reason: 'multiple_faces' };
    const face = good[0];
    const width = Array.isArray(face.box) ? Number(face.box[2]) : 0;
    if (a.width > 0 && width / a.width < t.minWidthRatio) {
      return { status: 'rejected', reason: 'face_too_small' };
    }
    faces.push(face);
  }

  // Identity: every frame is the person in the first centre frame.
  const centers = steps.map((s, i) => (s === 'center' ? i : -1)).filter((i) => i >= 0);
  const anchor = faces[centers[0]].embedding;
  for (let i = 0; i < faces.length; i++) {
    if (i === centers[0]) continue;
    if (cosine(anchor, faces[i].embedding) < t.samePerson) {
      return { status: 'rejected', reason: 'identity_mismatch' };
    }
  }
  // Two centre frames that are byte-for-byte the same picture.
  if (centers.length >= 2 && cosine(faces[centers[0]].embedding, faces[centers[1]].embedding) >= t.replayed) {
    return { status: 'rejected', reason: 'replayed_frame' };
  }

  // Direction, under whichever mirroring the device used.
  const softFailures = (sign) => {
    let soft = 0;
    for (let i = 0; i < steps.length; i++) {
      const yaw = faces[i].yaw * sign;
      const ok =
        steps[i] === 'center'
          ? Math.abs(yaw) < t.yawCenter
          : steps[i] === 'left'
            ? yaw < -t.yawTurn
            : yaw > t.yawTurn;
      if (!ok) soft += 1;
      if (faces[i].blur < t.blurMin) soft += 1;
    }
    return soft;
  };
  const soft = Math.min(softFailures(1), softFailures(-1));

  const template = meanTemplate(centers.map((i) => faces[i].embedding));
  const score = Math.min(
    ...faces.map((f, i) => (i === centers[0] ? 1 : cosine(anchor, f.embedding))),
  );
  if (soft === 0) return { status: 'approved', template, score, centerIndex: centers[0] };
  if (soft === 1) return { status: 'pending', reason: 'borderline', template, score, centerIndex: centers[0] };
  return { status: 'rejected', reason: 'wrong_direction' };
}

/**
 * Matches one profile photo against a template.
 * `ok` | `review` | `mismatch` | `no_face`, plus the best score.
 */
export function judgeProfilePhoto(analysis, template, t = config.face) {
  const faces = analysis.faces.filter((f) => f.embedding && f.score >= 0.6);
  if (faces.length === 0) return { result: 'no_face', score: null };
  const best = Math.max(...faces.map((f) => cosine(template, f.embedding)));
  if (best >= t.matchAccept) return { result: 'ok', score: best };
  if (best >= t.matchReview) return { result: 'review', score: best };
  return { result: 'mismatch', score: best };
}
