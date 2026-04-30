#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "Xcode not found at $DEVELOPER_DIR"
  echo "Set DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer and retry."
  exit 1
fi

echo "== Xcode =="
xcodebuild -version
echo

echo "== Connected Devices =="
xcrun xctrace list devices || true
echo

IOS_DEVICES="$(xcrun xctrace list devices 2>/dev/null | awk '/== Simulators ==/{exit} /(iPhone|iPad)/ {print}' || true)"
if [[ -z "$IOS_DEVICES" ]]; then
  echo "No physical iPhone/iPad detected. Connect by USB, unlock it, and tap Trust This Computer."
else
  echo "Physical iOS device candidates:"
  echo "$IOS_DEVICES"
fi
echo

echo "== Device Control =="
xcrun devicectl list devices || true
echo

echo "== Code Signing Identities =="
SIGNING_IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
echo "$SIGNING_IDENTITIES"
if ! echo "$SIGNING_IDENTITIES" | grep -q "Apple Development"; then
  echo "No Apple Development signing identity detected. Add your Apple ID in Xcode Settings > Accounts, then select a Team for the StillLight target."
fi
echo

echo "== Unsigned Compile Check =="
"$ROOT_DIR/scripts/build_unsigned.sh" >/tmp/stilllight_unsigned_build.log
tail -n 8 /tmp/stilllight_unsigned_build.log
echo
echo "StillLight compile check finished."
