#!/bin/bash
set -euo pipefail

# ─── ScreenAlert Build Script ───────────────────────────────────────────────
# Builds the Swift package and creates a proper macOS .app bundle.
#
# Usage:
#   ./build.sh          # Debug build
#   ./build.sh release  # Release build (optimized)
#   ./build.sh run      # Build and run
# ────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ScreenAlert"
BUNDLE_NAME="${APP_NAME}.app"
CONFIG="${1:-debug}"

if [ "$CONFIG" = "run" ]; then
    CONFIG="debug"
    RUN_AFTER=true
else
    RUN_AFTER=false
fi

BUILD_DIR="${SCRIPT_DIR}/.build/${CONFIG}"
APP_DIR="${SCRIPT_DIR}/build/${BUNDLE_NAME}"
SPARKLE_FRAMEWORK="${SCRIPT_DIR}/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"

echo "🔨 Building ${APP_NAME} (${CONFIG})..."

# Build with SPM
swift build -c "$CONFIG" --package-path "$SCRIPT_DIR"

echo "📦 Creating app bundle..."

# Create .app bundle structure
rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
mkdir -p "${APP_DIR}/Contents/Frameworks"

# Copy the binary
cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Copy Sparkle framework (preserve symlinks)
cp -a "$SPARKLE_FRAMEWORK" "${APP_DIR}/Contents/Frameworks/"

# Copy Info.plist
cp "${SCRIPT_DIR}/Resources/Info.plist" "${APP_DIR}/Contents/"

# Inject version from git tag
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")
# Remove 'v' prefix if present (e.g. v1.0.0 -> 1.0.0)
VERSION="${VERSION#v}"
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "1")

echo "🏷️  Versioning: ${VERSION} (Build ${BUILD_NUMBER})"

# Use plutil to update the plist (macOS only)
if command -v plutil &> /dev/null; then
    plutil -replace CFBundleShortVersionString -string "$VERSION" "${APP_DIR}/Contents/Info.plist"
    plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "${APP_DIR}/Contents/Info.plist"
else
    # Fallback for Linux/other environments (though this script is macOS specific)
    sed -i '' "s/1.0.0/${VERSION}/g" "${APP_DIR}/Contents/Info.plist"
    sed -i '' "s/>1</>${BUILD_NUMBER}</g" "${APP_DIR}/Contents/Info.plist"
fi

# Create PkgInfo
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# Code sign with persistent certificate (to preserve TCC) or fallback to ad-hoc
IDENTITY="ScreenAlert App Signing"

if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
    echo "🔏 Signing with identity: $IDENTITY..."
    # Sign Sparkle framework first
    codesign --force --sign "$IDENTITY" --options runtime \
        "${APP_DIR}/Contents/Frameworks/Sparkle.framework"
    # Sign main app
    codesign --force --sign "$IDENTITY" --options runtime \
        --entitlements "${SCRIPT_DIR}/ScreenAlert.entitlements" \
        "${APP_DIR}"
else
    echo "⚠️  Signing identity '$IDENTITY' not found in keychain!"
    echo "⚠️  Falling back to ad-hoc signing. TCC permissions will be lost on next update."
    codesign --force --sign - \
        "${APP_DIR}/Contents/Frameworks/Sparkle.framework"
    codesign --force --sign - \
        --entitlements "${SCRIPT_DIR}/ScreenAlert.entitlements" \
        "${APP_DIR}"
fi

echo ""
echo "✅ Build complete: ${APP_DIR}"
echo ""

# Install to /Applications
INSTALL_DIR="/Applications/${BUNDLE_NAME}"
echo "📲 Installing to ${INSTALL_DIR}..."
rm -rf "$INSTALL_DIR"
cp -R "$APP_DIR" "$INSTALL_DIR"
echo "✅ Installed to /Applications"

if [ "$RUN_AFTER" = true ]; then
    echo "🚀 Launching ${APP_NAME}..."
    open "$INSTALL_DIR"
fi
