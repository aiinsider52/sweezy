#!/usr/bin/env bash
# Capture Journey screenshots from the iOS Simulator into fastlane metadata folders.
# Usage:
#   1. Boot a simulator and open the app on Home / Directory / Map / Market / Settings
#   2. Run: ./scripts/capture-journey-screenshots.sh [locale]
# locale defaults to en-US; also supports uk and de-DE.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCALE="${1:-en-US}"
OUT="$ROOT/fastlane/metadata/$LOCALE/screenshots"
mkdir -p "$OUT"

DEVICE_UDID="$(xcrun simctl list devices booted | awk -F '[()]' '/Booted/{print $2; exit}')"
if [[ -z "${DEVICE_UDID:-}" ]]; then
  echo "No booted simulator. Open Simulator, launch Sweezy, then re-run." >&2
  exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
FILE="$OUT/journey-${STAMP}.png"
xcrun simctl io "$DEVICE_UDID" screenshot "$FILE"
echo "Saved $FILE"
echo "Repeat on each Journey tab (Home, Directory, Map, Market, Settings), then copy into uk/ and de-DE/ as needed."
