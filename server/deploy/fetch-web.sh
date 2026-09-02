#!/usr/bin/env bash
# Downloads the web build CI publishes with the latest release.
#
# Kept separate from provisioning because it is the one step that runs on every
# deploy, and because a failure here must not take the API down with it: an
# unreachable GitHub leaves the previous build in place and says so.
set -euo pipefail
DATA_DIR=/var/lib/up
URL="https://github.com/avileon/UPAPP/releases/latest/download/web.zip"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

command -v unzip >/dev/null 2>&1 || { apt-get install -y -qq unzip >/dev/null; }

if ! curl -fsSL "$URL" -o "$TMP/web.zip"; then
  echo "could not download the web build; keeping the one already there" >&2
  exit 0
fi
unzip -q "$TMP/web.zip" -d "$TMP/web"
[ -f "$TMP/web/index.html" ] || { echo "the archive has no index.html; keeping the old build" >&2; exit 0; }

# Swap it in one move, so a request that arrives mid-deploy never sees half a
# build.
rm -rf "$DATA_DIR/public.new"
mv "$TMP/web" "$DATA_DIR/public.new"
rm -rf "$DATA_DIR/public.old"
[ -d "$DATA_DIR/public" ] && mv "$DATA_DIR/public" "$DATA_DIR/public.old"
mv "$DATA_DIR/public.new" "$DATA_DIR/public"
rm -rf "$DATA_DIR/public.old"
chown -R up:up "$DATA_DIR/public"
echo "web build in place ($(du -sh "$DATA_DIR/public" | cut -f1))"
