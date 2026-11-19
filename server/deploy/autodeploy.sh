#!/usr/bin/env bash
# Runs every 2 minutes from up-autodeploy.timer. Deploys when CI has
# published a release built from the current tip of main that this server
# has not deployed yet. Nothing to do -> exits quietly.
#
# "Built from main" matters: CI also builds branches and publishes them to
# the same release, and only main is what update.sh checks out.
set -euo pipefail
APP_DIR=/opt/up/app
MARK=/var/lib/up/.deployed-release
API=https://api.github.com/repos/avileon/UPAPP/releases/tags/latest

release=$(curl -fsS --max-time 20 "$API") || exit 0
want=$(printf '%s' "$release" | grep -o 'Commit [0-9a-f]\{40\}' | head -1 | cut -d' ' -f2 || true)
[ -n "$want" ] || exit 0
# A failed build publishes logs only; wait for one that has the web app.
printf '%s' "$release" | grep -q '"name": *"web.zip"' || exit 0

git -C "$APP_DIR" fetch --quiet origin main
[ "$want" = "$(git -C "$APP_DIR" rev-parse origin/main)" ] || exit 0
[ "$want" = "$(cat "$MARK" 2>/dev/null || true)" ] && exit 0

echo "autodeploy: $want"
"$APP_DIR/server/deploy/update.sh"
echo "$want" > "$MARK"
