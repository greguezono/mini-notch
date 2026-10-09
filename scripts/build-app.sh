#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
for input in Package.swift assets/Info.plist assets/MiniNotch.entitlements assets/MiniNotch.icns; do
  test -f "$input" || { echo "Missing input: $input" >&2; exit 1; }
done
# Refuse symlinked output components before writing any build artifacts.
for output in .build build build/MiniNotch.app build/MiniNotch.app/Contents build/MiniNotch.app/Contents/MacOS build/MiniNotch.app/Contents/Resources; do
  test ! -L "$output" || { echo "Unsafe output: $output" >&2; exit 1; }
done
swift build -c release
BIN="$(swift build -c release --show-bin-path)/MiniNotch"
test -f "$BIN" || { echo "Missing executable" >&2; exit 1; }
APP="$ROOT/build/MiniNotch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
for output in "$APP/Contents/MacOS/MiniNotch" "$APP/Contents/Info.plist" "$APP/Contents/Resources/MiniNotch.icns" "$APP/Contents/_CodeSignature" "$APP/Contents/_CodeSignature/CodeResources"; do
  test ! -L "$output" || { echo "Unsafe output: $output" >&2; exit 1; }
done
cp "$BIN" "$APP/Contents/MacOS/MiniNotch"
cp assets/Info.plist "$APP/Contents/Info.plist"
cp assets/MiniNotch.icns "$APP/Contents/Resources/MiniNotch.icns"
# Keep this certificate in the login Keychain: changing it invalidates saved permissions.
codesign --force --sign 6D27E24D6528BC12546692D5D62CC4578BBAEC95 --options runtime --entitlements assets/MiniNotch.entitlements "$APP"
codesign --verify --strict "$APP"
echo "$APP"
