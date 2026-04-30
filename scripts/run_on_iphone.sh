#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUNDLE_ID="${BUNDLE_ID:-com.trevorcui.StillLight}"
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
  -scheme StillLight \
  -configuration Debug \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath build/DerivedData \
  build

APP_PATH="$(find build/DerivedData/Build/Products/Debug-iphoneos -name StillLight.app -maxdepth 2 -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "Build succeeded, but StillLight.app was not found under build/DerivedData."
  exit 3
fi

xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"
