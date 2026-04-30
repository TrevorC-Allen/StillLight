#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "Xcode not found at $DEVELOPER_DIR"
  echo "Set DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer and retry."
  exit 1
fi

cd "$ROOT_DIR"

xcodebuild \
  -project StillLight.xcodeproj \
  -target StillLight \
  -configuration Debug \
  -sdk "${SDK:-iphoneos}" \
  CODE_SIGNING_ALLOWED=NO \
  build
