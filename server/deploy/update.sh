#!/usr/bin/env bash
# One command to deploy whatever CI last built. Code and web build only —
# nothing in /var/lib/up is touched, so the database, the photos and the
# signing key all survive.
set -euo pipefail
APP_DIR=/opt/up/app
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }

git -C "$APP_DIR" fetch --quiet origin main
git -C "$APP_DIR" reset --hard --quiet origin/main
chown -R up:up "$APP_DIR"
"$APP_DIR/server/deploy/fetch-web.sh"
systemctl restart up.service
sleep 2
systemctl is-active up.service
curl -fsS http://127.0.0.1:3000/health && echo
echo "deployed $(git -C "$APP_DIR" rev-parse --short HEAD)"
