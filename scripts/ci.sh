#!/bin/sh
# Release gate: run before every TestFlight / App Store upload (and in CI).
#
#   ./scripts/ci.sh                         # iPhone 17 simulator
#   SIM="iPad Air 11-inch (M4)" ./scripts/ci.sh
#
# Fails on: network code, invalid plists, any compiler warning in a Release build,
# or any failing unit / UI test.
set -eu
cd "$(dirname "$0")/.."

SIM="${SIM:-iPhone 17}"
PROJECT=KidsColoring.xcodeproj
SCHEME=KidsColoring
OUT=build/ci
mkdir -p "$OUT"

echo "▸ Offline check"
./scripts/check-no-network.sh

echo "▸ Plists"
plutil -lint Resources/PrivacyInfo.xcprivacy Config/Info.plist

echo "▸ Release build (no warnings allowed)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$OUT/release" CODE_SIGNING_ALLOWED=NO \
  clean build > "$OUT/release.log" 2>&1 || { tail -40 "$OUT/release.log"; exit 1; }
# Tool chatter from appintentsmetadataprocessor is not a compiler warning.
if grep -E "(error|warning):" "$OUT/release.log" | grep -v appintents; then
  echo "error: the Release build has warnings"
  exit 1
fi

echo "▸ Tests on $SIM"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath "$OUT/debug" \
  test > "$OUT/test.log" 2>&1 || { grep -E "error:|failed" "$OUT/test.log" | tail -40; exit 1; }
if grep -E "(error|warning):" "$OUT/test.log" | grep -v -E "appintents|IDELaunch"; then
  echo "error: the test build has warnings"
  exit 1
fi

echo "✓ All checks passed"
