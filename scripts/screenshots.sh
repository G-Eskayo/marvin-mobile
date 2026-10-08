#!/bin/sh
# Builds the app, runs it in demo mode on an iPhone simulator, and saves one screenshot per
# screen to docs/screenshots/<set>/ for tickets and PRs (docs/agents/pr-requirements.md).
# Usage: scripts/screenshots.sh <set-name>     e.g. scripts/screenshots.sh issue-1
# Simulator: $SIM_UDID, else the first booted iPhone. Xcode 27's simulator window is DeviceHub.app.
set -eu
SET="${1:?usage: scripts/screenshots.sh <set-name>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/screenshots/$SET"
DERIVED="${TMPDIR:-/tmp}/marvin-mobile-screenshots"
UDID="${SIM_UDID:-$(xcrun simctl list devices booted | grep -m1 -oE 'iPhone[^(]*\(([0-9A-F-]{36})\)' | grep -oE '[0-9A-F-]{36}')}"
[ -n "$UDID" ] || { echo "no booted iPhone simulator; boot one or set SIM_UDID" >&2; exit 1; }
BUNDLE=com.gileskayo.marvin

"$ROOT/scripts/generate-project.sh" >/dev/null
xcodebuild -project "$ROOT/Apps/Marvin/Marvin.xcodeproj" -scheme Marvin \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DERIVED" -quiet build
xcrun simctl install "$UDID" "$DERIVED/Build/Products/Debug-iphonesimulator/Marvin.app"
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 >/dev/null 2>&1 || true
mkdir -p "$OUT"

# shot <file> <seconds to settle> <launch args...>
shot() {
  name="$1"; wait="$2"; shift 2
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE" -demo "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null 2>&1
  echo "$OUT/$name.png"
}

shot 1-thread 4 -tab marvin
shot 2-thread-typing 2 -tab marvin -demoPrompt "What's going on today?"
shot 3-thread-reply 6 -tab marvin -demoPrompt "What's going on today?"
shot 4-activity 4 -tab activity
shot 5-health 4 -tab health
shot 6-mr-review 3 -tab review
shot 7-docs 3 -tab docs
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
