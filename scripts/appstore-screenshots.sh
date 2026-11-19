#!/bin/sh
# Captures App Store screenshots on the two required sizes:
#   iPhone 6.9" (1320 × 2868) and iPad 13" (2064 × 2752), portrait.
#
#   ./scripts/appstore-screenshots.sh
#   IPHONE="iPhone 17 Pro Max" IPAD="iPad Pro 13-inch (M5)" ./scripts/appstore-screenshots.sh
#
# Output: AppStore/screenshots/iphone-6.9/ and AppStore/screenshots/ipad-13/
set -eu
cd "$(dirname "$0")/.."

IPHONE="${IPHONE:-iPhone 18 Pro Max}"
IPAD="${IPAD:-iPad Pro 13-inch (M5)}"
OUT_ROOT="$PWD/AppStore/screenshots"

capture() {
  name="$1"; folder="$2"
  udid=$(xcrun simctl list devices available | grep -F "    $name (" | tail -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  [ -n "$udid" ] || { echo "error: no simulator named '$name'"; exit 1; }
  echo "▸ $name ($udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b > /dev/null
  xcrun simctl ui "$udid" appearance light
  xcrun simctl status_bar "$udid" override --time "9:41" --dataNetwork wifi --wifiMode active \
    --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100
  out="$OUT_ROOT/$folder"
  rm -rf "$out"; mkdir -p "$out"
  TEST_RUNNER_APPSTORE_SHOT_DIR="$out" xcodebuild -project KidsColoring.xcodeproj -scheme KidsColoring \
    -destination "id=$udid" -derivedDataPath build/appstore \
    -only-testing:KidsColoringUITests/AppStoreScreenshotsUITests test > "build/appstore-$folder.log" 2>&1 \
    || { grep -E "error|failed" "build/appstore-$folder.log" | tail -20; exit 1; }
  xcrun simctl status_bar "$udid" clear
  for f in "$out"/*.png; do
    echo "  $(basename "$f")  $(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/ {printf "%s ", $2}')"
  done
}

mkdir -p build
capture "$IPHONE" iphone-6.9
capture "$IPAD" ipad-13
echo "✓ Screenshots in $OUT_ROOT"
