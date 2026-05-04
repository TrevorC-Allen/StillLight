#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUNDLE_ID="${BUNDLE_ID:-com.trevorcui.StillLight}"
BUILD_ROOT="${BUILD_ROOT:-/tmp/StillLightBuild}"
OBJ_ROOT="${OBJ_ROOT:-/tmp/StillLightObj}"
DEVICE_ID="${1:-}"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "Xcode not found at $DEVELOPER_DIR"
  echo "Set DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer and retry."
  exit 1
fi

if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(xcrun xctrace list devices 2>/dev/null \
    | awk '/== Simulators ==/{exit} /(iPhone|iPad)/ {print}' \
    | sed -E 's/.*\\(([0-9A-Fa-f-]{24,})\\)$/\\1/' \
    | head -n 1 || true)"
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "No physical iPhone/iPad device id found."
  echo "Connect your iPhone, unlock it, trust this Mac, then run:"
  echo "  scripts/check_ios_device.sh"
  exit 2
fi

cd "$ROOT_DIR"

xcodebuild \
  -project StillLight.xcodeproj \
  -target StillLight \
  -configuration Debug \
  -sdk iphoneos \
  SYMROOT="$BUILD_ROOT" \
  OBJROOT="$OBJ_ROOT" \
  build

APP_PATH="$BUILD_ROOT/Debug-iphoneos/StillLight.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded, but $APP_PATH does not exist."
  exit 3
fi

xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

LAUNCH_LOG="$(mktemp -t stilllight-launch.XXXXXX)"
if ! xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID" >"$LAUNCH_LOG" 2>&1; then
  cat "$LAUNCH_LOG"
  if grep -qi "Locked" "$LAUNCH_LOG"; then
    echo
    echo "StillLight was installed, but iOS refused to launch it because the device is locked."
    echo "Unlock the iPhone and run again:"
    echo "  scripts/run_on_iphone.sh $DEVICE_ID"
  fi
  rm -f "$LAUNCH_LOG"
  exit 4
fi

cat "$LAUNCH_LOG"
rm -f "$LAUNCH_LOG"
