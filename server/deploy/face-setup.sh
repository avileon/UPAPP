#!/usr/bin/env bash
# Installs or updates the face sidecar. Called by provision.sh and update.sh;
# safe to run on its own and safe to run twice.
#
#   venv    /opt/up/face-venv     rebuilt only if missing
#   models  /opt/up/face-models   hash-checked against face-svc/models.lock
#   unit    up-face.service
set -euo pipefail
APP_DIR=/opt/up/app
VENV=/opt/up/face-venv
MODELS=/opt/up/face-models
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }

if ! python3 -c 'import venv, ensurepip' >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq python3-venv >/dev/null
fi

[ -x "$VENV/bin/python" ] || python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$APP_DIR/face-svc/requirements.txt"

"$APP_DIR/face-svc/fetch-models.sh" "$MODELS"
chown -R up:up "$VENV" "$MODELS"

install -m 644 "$APP_DIR/server/deploy/up-face.service" /etc/systemd/system/up-face.service
systemctl daemon-reload
systemctl enable --quiet up-face.service
systemctl restart up-face.service

# The models take a second or two to load.
for _ in $(seq 1 20); do
  curl -fsS http://127.0.0.1:8091/health >/dev/null 2>&1 && break
  sleep 0.5
done
curl -fsS http://127.0.0.1:8091/health >/dev/null && echo "face-svc up" || {
  echo "face-svc did not come up — journalctl -u up-face -n 50" >&2
  exit 1
}
