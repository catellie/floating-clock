#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export CLEAN_CORE_CONFIG=1
BUILD_DIR="$(mktemp -d /tmp/floating-clock-build.XXXXXX)"
APP="${1:-$PWD/Floating Clock.app}"
xcrun swiftc -warnings-as-errors -module-cache-path "$BUILD_DIR/module-cache" \
  ClockMath.swift ClockMathTests.swift -o "$BUILD_DIR/ClockMathTests"
"$BUILD_DIR/ClockMathTests"
xcrun swiftc -warnings-as-errors -module-cache-path "$BUILD_DIR/module-cache" \
  TimeZoneDot.swift TimeZoneDotTests.swift -o "$BUILD_DIR/TimeZoneDotTests"
"$BUILD_DIR/TimeZoneDotTests"
xcrun swiftc -O -warnings-as-errors -target arm64-apple-macosx13.0 \
  -module-cache-path "$BUILD_DIR/module-cache" -framework Cocoa \
  ClockMath.swift TimeZoneDot.swift main.swift -o "$BUILD_DIR/FloatingClock"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
mv "$BUILD_DIR/FloatingClock" "$APP/Contents/MacOS/FloatingClock"
/usr/bin/codesign --force --sign - "$APP"
/usr/bin/codesign --verify --strict "$APP"
printf '\nBuilt %s\nDouble-click the app to launch. Use the clock menu-bar icon for settings.\n' "$APP"
