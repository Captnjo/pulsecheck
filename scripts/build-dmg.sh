#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="PulseCheck"
APP_NAME="PulseCheck"
DMG_NAME="PulseCheck-1.1"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
DMG_STAGING="$BUILD_DIR/dmg-staging"

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving..."
xcodebuild archive \
    -project "$PROJECT_DIR/PulseCheck.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    -quiet

echo "==> Exporting app from archive..."
APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found in archive"
    exit 1
fi

echo "==> Creating DMG staging area..."
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

echo "==> Building DMG..."
hdiutil create \
    -volname "PulseCheck" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$PROJECT_DIR/$DMG_NAME.dmg"

echo "==> Cleaning up..."
rm -rf "$BUILD_DIR"

echo ""
echo "Done! DMG created at: $PROJECT_DIR/$DMG_NAME.dmg"
