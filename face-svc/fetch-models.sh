#!/usr/bin/env bash
# Downloads the two ONNX models into a directory and refuses anything whose
# hash is not the one in models.lock. Idempotent: a file already present with
# the right hash is left alone, so this is safe to run on every deploy.
#
#   ./fetch-models.sh [dest]        (default: ./models)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
DEST=${1:-$HERE/models}
mkdir -p "$DEST"

while read -r file sha url; do
  case "$file" in ''|\#*) continue ;; esac
  target="$DEST/$file"
  if [ -f "$target" ] && echo "$sha  $target" | sha256sum -c --status; then
    echo "ok    $file"
    continue
  fi
  tmp=$(mktemp "$DEST/.dl.XXXXXX")
  curl -fsSL --retry 3 -o "$tmp" "$url"
  if ! echo "$sha  $tmp" | sha256sum -c --status; then
    rm -f "$tmp"
    echo "HASH MISMATCH for $file — refusing to install it" >&2
    exit 1
  fi
  chmod 644 "$tmp"
  mv -f "$tmp" "$target"
  echo "got   $file"
done < "$HERE/models.lock"
