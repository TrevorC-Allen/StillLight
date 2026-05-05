#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUNDLE_ID="${BUNDLE_ID:-com.trevorcui.StillLight}"
BUILD_ROOT="${BUILD_ROOT:-/tmp/StillLightBuild}"
OBJ_ROOT="${OBJ_ROOT:-/tmp/StillLightObj}"
DEVICE_ID="${1:-}"
DEVICECTL_RETRIES="${DEVICECTL_RETRIES:-3}"

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

run_devicectl_with_retry() {
  local label="$1"
  shift

  local attempt=1
  local log_file
  local status
  while [[ "$attempt" -le "$DEVICECTL_RETRIES" ]]; do
    log_file="$(mktemp -t "stilllight-${label}.XXXXXX")"
    if "$@" >"$log_file" 2>&1; then
      if ! grep -Eqi "ERROR:|DeviceLocked|device is locked|could not be mounted" "$log_file"; then
        cat "$log_file"
        rm -f "$log_file"
        return 0
      fi
      status=1
    else
      status=$?
    fi

    cat "$log_file"
    if [[ "$attempt" -lt "$DEVICECTL_RETRIES" ]] && grep -Eqi "Connection reset|Connection was invalidated|No provider was found|Transport error|DeviceLocked|device is locked|could not be mounted" "$log_file"; then
      echo
      if grep -Eqi "DeviceLocked|device is locked|could not be mounted" "$log_file"; then
        echo "devicectl $label failed because the iPhone is locked. Retrying ($((attempt + 1))/$DEVICECTL_RETRIES)..."
      else
        echo "devicectl $label failed because the device connection was reset. Retrying ($((attempt + 1))/$DEVICECTL_RETRIES)..."
      fi
      echo "Keep the iPhone unlocked and connected."
      rm -f "$log_file"
      sleep 2
      attempt=$((attempt + 1))
      continue
    fi

    rm -f "$log_file"
    return "$status"
  done
}

if ! run_devicectl_with_retry install xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"; then
  echo
  echo "StillLight built successfully, but installation failed."
  echo "Unlock the iPhone, keep it on the Home Screen, reconnect USB if needed, then run:"
  echo "  scripts/run_on_iphone.sh $DEVICE_ID"
  exit 4
fi

LAUNCH_LOG="$(mktemp -t stilllight-launch.XXXXXX)"
if ! run_devicectl_with_retry launch xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID" >"$LAUNCH_LOG" 2>&1; then
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
