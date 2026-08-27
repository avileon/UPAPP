# UP server — Milestone 2

Phone auth, profiles, presence, likes, matches, chat and safety. Runs on your
own machine and reaches the phone through a Cloudflare tunnel.

**45 tests, all passing.** Unlike the Flutter code, this was written and run in
the same place — every claim below is something the test suite asserts.

---

## Run it

You need **Node 22.5 or newer** — nothing else. No database to install, no
Docker, no `npm install`: this project has **zero dependencies** and uses only
what ships inside Node.

```powershell
cd server
node src/server.js
```

That's it. The server creates `up.db` beside itself on first run.

```
UP server listening on http://0.0.0.0:3000
  database : up.db
  sms      : mock (codes are returned in the response)
```

### Reach it from the phone

In a second window:

```powershell
cloudflared tunnel --url http://localhost:3000
```

Cloudflare prints a public `https://something.trycloudflare.com` URL. That is
what the app will point at — no account, no DNS, real HTTPS.

Sanity check from any browser: `https://<that-url>/health`

### Tests

```powershell
npm test
```

---

## Why these choices

**Zero dependencies.** `node:http` for the server, `node:sqlite` for storage,
`node:crypto` for tokens. The same reasoning as the Flutter app: nothing to
install is nothing to break, and the two files where security actually lives —
JWT signing and token hashing — are thirty lines each and readable in full.

**SQLite, not Postgres — for now.** The spec says Postgres and it will be
Postgres. But Postgres means installing and running a database on your machine
before you can see a single request work, and the SQL here is deliberately
plain: no extensions, no JSON operators, no `RETURNING`. Moving to Postgres is
a change to `src/store.js` and `src/db/db.js`.

**Presence in memory, not Redis.** Live sessions and BLE tokens all expire
within two hours by construction. Persisting them would mean writing rows whose
only future is a cleanup job that can fail quietly. `src/domain/presence.js` is
the interface Redis has to implement the day there is more than one process.

**The OTP is returned in the response.** Only while `SMS_PROVIDER=mock`. The
server refuses to start in production that way — see `assertProd` in
`src/config.js`.

---

## The rules the server enforces

These are the parts worth reviewing, because they are the ones a client cannot
be trusted to enforce.

**One match per pair, always.** `matches` stores the smaller user id first and
has a unique index on the pair, so two devices pressing UP at the same instant
collide on one key instead of creating two rows. The whole read-then-write runs
in one transaction. There is a test that fires both directions concurrently.

**A one-way UP is invisible.** The response to `POST /likes/:userId` carries a
match object only on mutuality. The receiving side has no endpoint that would
reveal a pending like — not one that filters it out, one that does not exist.

**Two people in one room find each other without BLE.** `POST /live/start`
accepts an optional `venue` — a short code both people type, normalised to
`BAR12` however it was written. Anyone live under the same key is resolved into
the same nearby list. This is a product decision, not a stand-in for the radio:
BLE under-discovers badly in a crowded bar, which is exactly where UP has to
work. The key holds no coordinates, is never stored, and dies with the session.
The response carries profiles and no provenance, so nothing downstream can tell
— or show — which channel surfaced a person.

**`/nearby/resolve` is the privacy boundary.** Observed BLE tokens go in,
permitted profiles come out. Token validity, both live sessions, blocks in
either direction and mutual preference are all decided there. The serialiser is
a whitelist: id, first name, age, bio, photos, badge. No distance, no RSSI, no
phone, no last-seen — a test asserts the exact key set and greps the payload
for leaks.

**BLE tokens are opaque and short-lived.** The server mints random tokens,
stores only their hash, and rotates them. Observing one off the air tells an
attacker nothing; replaying it after the session ends resolves to nobody. Every
failure — unknown, expired, session over — returns the same empty result, so a
caller cannot tell them apart.

**18+ is enforced with the server's clock**, on profile save, and again before
going live. The acceptance timestamp is written server-side.

**Rate limits that matter.** Five OTP requests per number per hour (without it,
an attacker bills you for unlimited SMS) and sixty UPs per hour (without it, UP
is a harassment tool).

**Reality Check stays honest.** Only a real match can answer, only after four
messages, only once, ever. The tally lives in the database and never leaves it
— clients receive a boolean badge and nothing else. `somewhat` counts as
neutral rather than negative; a badge needs at least three answers and 70%
positive.

---

## Endpoints

| Method | Path | Notes |
|---|---|---|
| POST | `/auth/request-otp` | 5/hour/number |
| POST | `/auth/verify-otp` | creates the user on first success |
| POST | `/auth/refresh` | refresh tokens are single use |
| GET / PUT | `/me/profile` | PUT enforces 18+ |
| POST | `/media/upload-url` | placeholder key; S3 presign later |
| DELETE | `/me` | anonymises immediately |
| POST | `/live/start` `/live/refresh` `/live/stop` | mints and rotates BLE tokens; `venue` is optional |
| POST | `/nearby/resolve` | the privacy boundary |
| POST / DELETE | `/likes/:userId` | rate limited |
| GET | `/matches` | |
| POST | `/matches/:id/unmatch` | |
| GET / POST | `/matches/:id/messages` | text only |
| POST | `/matches/:id/reality-feedback` | |
| POST | `/users/:id/block` `/users/:id/report` | separate on purpose |
| GET | `/health` | |

---

## Configuration

Everything has a working default. Set these when it stops being a laptop:

| Variable | Default | |
|---|---|---|
| `PORT` | 3000 | |
| `DATABASE_FILE` | `up.db` | |
| `JWT_SECRET` | random per boot | **set this** — otherwise every restart signs everyone out |
| `SMS_PROVIDER` | `mock` | anything else stops revealing codes |
| `LIKES_MAX_PER_HOUR` | 60 | |
| `OTP_MAX_PER_HOUR` | 5 | |

---

## Not done yet, on purpose

- **Real SMS.** The provider sits behind one function in `src/app.js`.
- **Real photo storage.** `/media/upload-url` returns a key and no URL.
- **Realtime.** No WebSocket yet; the app polls. Socket.IO or plain WS for
  `match.created` and `message.created` is the next piece.
- **Push.** FCM/APNs as the fallback when the socket is down, never as the
  primary path.
- **Real BLE.** The app sends an empty token list today; the venue key is the
  discovery channel until the radio lands.

The Flutter app **is** wired to this now — see `lib/data/api/`. Paste the tunnel
URL into the app's settings and it stops using mock data.
