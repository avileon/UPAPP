#!/usr/bin/env bash
# Generates the android/ and ios/ folders for this project and fetches
# dependencies. Safe to re-run: `flutter create` only adds what is missing and
# does not touch lib/, test/ or the docs.
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found on PATH — install Flutter 3.22 or newer first." >&2
  exit 1
fi

echo "==> Flutter version"
flutter --version

echo
echo "==> Generating platform folders"
flutter create --org co.vibit.up --project-name up --platforms=ios,android .

echo
echo "==> Fetching dependencies"
flutter pub get

echo
echo "==> Analyzing"
flutter analyze || echo "(analyze reported issues — send me the output)"

echo
echo "==> Testing"
flutter test || echo "(tests reported failures — send me the output)"

echo
echo "Done. Run the app with:  flutter run"
