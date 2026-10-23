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
# Supply SIGN_IDENTITY for a stable local/developer signature. Ad-hoc signing
# works locally but rebuilding can require granting Accessibility again.
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
codesign --verify --strict "$APP"
echo "Built: $APP"
