#!/usr/bin/env bash
# Turns a bare Ubuntu box into the UP server. Safe to re-run.
#
# Everything here is deliberate about one split: code lives in /opt/up/app and
# is disposable — deleted and re-cloned at will — while data lives in
# /var/lib/up and is never touched by a deploy. The signing key is data, not
# configuration: losing it signs every phone out, which is why it is generated
# once and left alone on every subsequent run.
set -euo pipefail

REPO="https://github.com/avileon/UPAPP.git"
APP_DIR=/opt/up/app
DATA_DIR=/var/lib/up
ENV_FILE=/etc/up.env
DOMAIN=up.atar.co

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }

say "Packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl git ca-certificates debian-keyring debian-archive-keyring apt-transport-https gnupg >/dev/null

say "Node"
# The server uses node:sqlite, which needs 22.5 or newer. Take the distro's
# node when it is new enough and NodeSource only when it is not — one less
# third-party repository to trust for no reason.
node_ok() {
  command -v node >/dev/null 2>&1 || return 1
  local v major minor
  v=$(node --version | tr -d 'v')
  major=${v%%.*}; minor=$(echo "$v" | cut -d. -f2)
  [ "$major" -gt 22 ] || { [ "$major" -eq 22 ] && [ "$minor" -ge 5 ]; }
}
if ! node_ok; then
  apt-get install -y -qq nodejs >/dev/null 2>&1 || true
fi
if ! node_ok; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null
  apt-get install -y -qq nodejs >/dev/null
fi
node_ok || { echo "could not install node 22.5+" >&2; exit 1; }
echo "node $(node --version)"

say "Caddy"
if ! command -v caddy >/dev/null 2>&1; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
  apt-get update -qq
  apt-get install -y -qq caddy >/dev/null
fi
echo "caddy $(caddy version | head -1)"

say "User and directories"
id -u up >/dev/null 2>&1 || useradd --system --home /opt/up --shell /usr/sbin/nologin up
mkdir -p /opt/up "$DATA_DIR/uploads" "$DATA_DIR/public" /var/log/caddy
chown -R up:up /opt/up "$DATA_DIR"

say "Code"
# The checkout is owned by `up` and these commands run as root, which git
# refuses to touch by default ("dubious ownership") — and refuses *before*
# doing anything, so an update would silently stop here.
git config --global --add safe.directory "$APP_DIR" 2>/dev/null || true
if [ -d "$APP_DIR/.git" ]; then
  git -C "$APP_DIR" fetch --quiet origin main
  git -C "$APP_DIR" reset --hard --quiet origin/main
else
  rm -rf "$APP_DIR"
  git clone --quiet --depth 1 "$REPO" "$APP_DIR"
fi
chown -R up:up "$APP_DIR"
echo "at $(git -C "$APP_DIR" rev-parse --short HEAD)"

say "Signing key"
# Generated once, ever. Every phone's session is signed with it, so a new key
# on each deploy would be a sign-out for everybody.
if [ ! -f "$DATA_DIR/.jwt-secret" ]; then
  openssl rand -hex 32 > "$DATA_DIR/.jwt-secret"
  chown up:up "$DATA_DIR/.jwt-secret"
  chmod 600 "$DATA_DIR/.jwt-secret"
  echo "created"
else
  echo "kept the existing one"
fi

say "Notification keys"
# The VAPID pair, generated once for the same reason as the signing key above:
# it is baked into every push subscription a browser has already made, so
# changing it does not re-key anything — it silently stops every existing
# subscription from ever receiving another notification.
if [ ! -f "$DATA_DIR/.vapid.json" ]; then
  node --input-type=module -e "
    import { generateVapidKeys } from 'file://$APP_DIR/server/src/lib/webpush.js';
    process.stdout.write(JSON.stringify(generateVapidKeys()));
  " > "$DATA_DIR/.vapid.json"
  chown up:up "$DATA_DIR/.vapid.json"
  chmod 600 "$DATA_DIR/.vapid.json"
  echo "created"
else
  echo "kept the existing pair"
fi
read_vapid() {
  node -p "JSON.parse(require('fs').readFileSync('$DATA_DIR/.vapid.json','utf8')).$1"
}
VAPID_PUBLIC=$(read_vapid publicKey)
VAPID_PRIVATE=$(read_vapid privateKey)

say "Environment"
cat > "$ENV_FILE" <<ENV
# The app listens on loopback only. Caddy in front of it is the sole way in,
# which is what makes HTTPS non-optional rather than a suggestion.
HOST=127.0.0.1
PORT=3000

DATABASE_FILE=$DATA_DIR/up.db
MEDIA_DIR=$DATA_DIR/uploads
SITE_DIR=$DATA_DIR/public

JWT_SECRET=$(cat "$DATA_DIR/.jwt-secret")

# Web Push. Absent keys mean the app simply does not offer notifications.
VAPID_PUBLIC_KEY=$VAPID_PUBLIC
VAPID_PRIVATE_KEY=$VAPID_PRIVATE
VAPID_SUBJECT=mailto:avi@vibit.co.il

# Still the mock SMS provider: the one-time code comes back in the response.
# That is why NODE_ENV is not "production" — the server refuses to start in
# production with a mock provider, and it is right to. Fine while the testers
# are people you invited by hand; the day this is public, it needs a real
# provider or an invite gate, because today anyone who finds the address can
# sign up as any phone number.
NODE_ENV=development
SMS_PROVIDER=mock
ENV
chmod 640 "$ENV_FILE"
chown root:up "$ENV_FILE"

say "Web build"
"$APP_DIR/server/deploy/fetch-web.sh"

say "Services"
install -m 644 "$APP_DIR/server/deploy/up.service" /etc/systemd/system/up.service
install -m 644 "$APP_DIR/server/deploy/Caddyfile" /etc/caddy/Caddyfile
chown -R caddy:caddy /var/log/caddy
systemctl daemon-reload
systemctl enable --now up.service
systemctl reload caddy 2>/dev/null || systemctl restart caddy

say "Firewall"
# Only the two web ports and SSH. The app's own port is unreachable from
# outside by construction, and this makes that explicit.
if command -v ufw >/dev/null 2>&1; then
  ufw --force reset >/dev/null
  ufw default deny incoming >/dev/null
  ufw default allow outgoing >/dev/null
  ufw allow 22/tcp >/dev/null
  ufw allow 80/tcp >/dev/null
  ufw allow 443/tcp >/dev/null
  ufw --force enable >/dev/null
  echo "ufw on: 22, 80, 443"
fi

say "Status"
sleep 2
systemctl is-active up.service caddy || true
curl -fsS http://127.0.0.1:3000/health && echo
echo
echo "Done. $DOMAIN needs a plain A record pointing at this machine."
