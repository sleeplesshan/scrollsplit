#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="$PWD/dist/ScrollSplit.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ScrollSplit "$APP/Contents/MacOS/ScrollSplit"
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift scripts/icon.swift "$PWD/dist"
iconutil -c icns dist/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
# Keep a stable local/developer identity across updates. A repository-local Git
# setting stays on this Mac; it is never committed or shared with other users.
SIGNING_IDENTITY="${SIGN_IDENTITY:-$(git config --local --get scrollsplit.signingIdentity 2>/dev/null || true)}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
codesign --force --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --strict "$APP"
if [ "$SIGNING_IDENTITY" = "-" ]; then
  echo "Ad-hoc signature: after rebuilding, remove the old Accessibility entry and add the installed app again."
  echo "For stable updates, set SIGN_IDENTITY or git config --local scrollsplit.signingIdentity YOUR_CERTIFICATE."
fi
echo "Built: $APP"
