# Milestone 2 — Auth, profile and the real backend

**Nothing in this document is implemented.** It exists so that when Milestone 2
starts, the shape of the work is already agreed and the Flutter side barely
moves.

---

## The idea in one line

Milestone 1 defined four repository interfaces and implemented them in memory.
Milestone 2 implements the **same four interfaces** over HTTP. `lib/ui/` and
`lib/state/` do not change.

```
domain/repositories/          data/mock/              data/api/          ← new
  AuthRepository        ←──   MockAuthRepository      ApiAuthRepository
  ProfileRepository     ←──   MockProfileRepository   ApiProfileRepository
  PresenceRepository    ←──   MockPresenceRepository  ApiPresenceRepository
  InteractionRepository ←──   MockInteractionRepo     ApiInteractionRepository
```

Swapping them is one edit in `state/app_scope.dart`. Keep both: the mock stack
stays the fastest way to demo the app and the only way to run widget tests
without a server.

---

## Server

Node.js 20 + TypeScript. Fastify or NestJS — either is fine; pick one and stop
discussing it. PostgreSQL for everything durable, Redis for anything that
expires on its own.

### Tables

Straight from the spec, with the notes that matter:

| Table | Notes |
|---|---|
| `users` | `birth_date`, never a stored age. 18+ enforced at write time, with the acceptance timestamp recorded server-side — a device flag is not evidence. |
| `profiles` | `photo_primary` and `photos` hold storage keys, never public URLs. |
| `live_sessions` | `expires_at` is authoritative. A client claiming to be Live past it gets nothing. |
| `ble_tokens` | Store `token_hash`, never the token. Rotate every 5–15 min. |
| `likes` | Unique on `(from_user, to_user)`. |
| `matches` | **Unique on the ordered pair** `(least(a,b), greatest(a,b))`. This constraint is what makes double-matching impossible under concurrency, not the application code. |
| `messages` | Text only. |
| `reality_feedback` | Unique on `(match_id, reviewer_id)`. One answer per match, ever. |
| `blocks`, `reports` | Blocks filter server-side in `/nearby/resolve`, never client-side. |

Presence lives in Redis, not Postgres: live sessions and BLE tokens both expire
on their own, and giving them a TTL is cheaper and safer than a cleanup job that
can fail quietly.

### Endpoints

Each of these is already named in a doc comment on the matching repository
method.

```
POST   /auth/request-otp          rate limit: 5 per number per hour
POST   /auth/verify-otp           returns access + refresh tokens
GET    /me/profile
PUT    /me/profile
POST   /media/upload-url          signed PUT straight to object storage
POST   /live/start                creates session, mints token batch
POST   /live/refresh              extends nothing, rotates tokens
POST   /live/stop
POST   /nearby/resolve            tokens in, permitted profiles out
POST   /likes/:userId             rate limited
DELETE /likes/:userId
GET    /matches
POST   /matches/:id/unmatch
GET    /matches/:id/messages
POST   /matches/:id/messages
POST   /matches/:id/reality-feedback
POST   /users/:id/block
POST   /users/:id/report
DELETE /me
```

### The two rules that are easy to get wrong

**`/nearby/resolve` is the privacy boundary.** It receives observed tokens and
returns profiles. Everything gets decided here: is the token still valid, is
either party blocked, do the preferences match, is the observer's own session
live. If any of that leaks to the client, the whole model is decorative.

**Never send a client anything it should not be able to see.** Not "send it and
hide it in the UI" — do not send it. That includes: who liked whom before
mutuality, exact distance or RSSI, who answered a Reality Check, and the vote
counts behind a badge.

---

## Order of work

1. **Auth.** OTP behind a provider interface so Twilio / Vonage / a local
   Israeli gateway swap without touching the app. `ApiAuthRepository` first,
   because everything else needs a token.
2. **Profile + media.** Signed upload URLs. Automated NSFW screening before a
   photo goes live — App Review will test this, and finding out then is
   expensive.
3. **Wire the app.** Replace the two mocks in `app_scope.dart`. Add a
   `--dart-define` for the base URL. Keep the mock stack behind a flag.
4. **Realtime.** Socket.IO for `match.created` and `message.created`. Push via
   FCM/APNs as the fallback when the socket is down, never as the primary path.

Nothing about BLE happens in Milestone 2. Presence stays mocked until the
backend it talks to actually exists.

---

## Then Milestone 3 — real BLE

The part to plan carefully rather than discover:

- **iOS backgrounded advertisements land in the overflow area** and Android
  cannot read them. Design foreground-first and degrade honestly. Do not build
  UX that assumes discovery while the app is closed.
- **Android permissions differ by API level** — `BLUETOOTH_SCAN`,
  `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT`, plus location on some versions
  purely to permit scanning. The pre-prompt copy for this is already written in
  `PermissionsScreen`.
- **A foreground service only if the architecture genuinely needs one.** Google
  Play asks what it is for, and "so the app keeps scanning" is not an answer
  that survives review on its own.
- **RSSI is a coarse presence hint and nothing else.** It is not a distance and
  must never be rendered as one.
- **Test on physical devices only.** Simulators do not do BLE. Test across at
  least two Android manufacturers — battery optimisation behaviour varies more
  between OEMs than between OS versions.
- **Add venue presence at the same time** (see README, point 2). BLE alone will
  under-discover in exactly the crowded rooms the product is for, and shipping
  BLE-only means the first real test looks like a failure.

---

## Store readiness, worth starting early

- Privacy nutrition labels and the Play data-safety form must match what is
  actually collected. Write them from the code, not from the pitch.
- Deletion policy: immediate anonymisation client-side, hard delete within 30
  days, documented in the listing.
- Crash reporting and a minimal analytics set — enough to know whether people go
  Live twice, which is the only retention number that matters at this stage.
- TestFlight and Play Internal Testing before anything else.
