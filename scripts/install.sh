#!/bin/sh
# curl -fsSL https://raw.githubusercontent.com/greguezono/mini-notch/main/scripts/install.sh | sh
set -eu

REPO="https://github.com/greguezono/mini-notch"
REF="${MININOTCH_REF:-main}"
DEST="/Applications/MiniNotch.app"
LOCAL_IDENTITY="6D27E24D6528BC12546692D5D62CC4578BBAEC95"

fail() { echo "error: $*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "MiniNotch only runs on macOS"
major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$major" -ge 26 ] || fail "macOS 26 or later required (found $(sw_vers -productVersion))"
xcode-select -p >/dev/null 2>&1 || fail "Xcode command-line tools missing. Run: xcode-select --install"
command -v git >/dev/null 2>&1 || fail "git not found"
command -v swift >/dev/null 2>&1 || fail "swift not found"

if [ -z "${MININOTCH_SIGN_IDENTITY:-}" ]; then
  if security find-certificate -a -Z 2>/dev/null | grep -q "$LOCAL_IDENTITY"; then
    MININOTCH_SIGN_IDENTITY="$LOCAL_IDENTITY"
  else
    MININOTCH_SIGN_IDENTITY="-"
  fi
fi
export MININOTCH_SIGN_IDENTITY

WORK="$(mktemp -d -t mininotch-install)"
trap 'rm -rf "$WORK"' EXIT INT TERM

echo "Cloning $REPO ($REF)..."
git clone --quiet --depth 1 --branch "$REF" "$REPO" "$WORK/src"

echo "Building (this takes about a minute on first run)..."
bash "$WORK/src/scripts/build-app.sh" >/dev/null

if pgrep -xq MiniNotch; then
  osascript -e 'quit app "MiniNotch"' >/dev/null 2>&1 || true
  sleep 1
fi
rm -rf "$DEST"
cp -R "$WORK/src/build/MiniNotch.app" "$DEST"
codesign --verify --strict "$DEST"

open "$DEST"
echo "Installed $DEST"
if [ "$MININOTCH_SIGN_IDENTITY" = "-" ]; then
  echo "Signed ad-hoc: macOS will ask for Accessibility and Automation again after each reinstall."
fi
