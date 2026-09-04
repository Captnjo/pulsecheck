#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="PulseCheck"
APP_NAME="PulseCheck"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
DMG_STAGING="$BUILD_DIR/dmg-staging"

# Version comes from the project's MARKETING_VERSION — single source of truth
VERSION=$(xcodebuild -project "$PROJECT_DIR/PulseCheck.xcodeproj" \
    -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
    | awk '/MARKETING_VERSION =/ {print $3; exit}')
if [ -z "$VERSION" ]; then
    echo "Error: could not read MARKETING_VERSION from project"
    exit 1
fi
DMG_NAME="PulseCheck-$VERSION"
echo "==> Building version $VERSION"

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving..."
# Ad-hoc signing ("-") — unsigned binaries can't carry entitlements, which silently
# drops the sandbox and network entitlements the app declares. Ad-hoc keeps them.
xcodebuild archive \
    -project "$PROJECT_DIR/PulseCheck.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="-" \
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

echo "==> Verifying signature and entitlements..."
codesign --verify --deep --strict "$DMG_STAGING/$APP_NAME.app"
codesign -d --entitlements - "$DMG_STAGING/$APP_NAME.app"

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
