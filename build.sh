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

echo "🔨 Building ${APP_NAME} (${CONFIG})..."

# Build with SPM
swift build -c "$CONFIG" --package-path "$SCRIPT_DIR"

echo "📦 Creating app bundle..."

# Create .app bundle structure
rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy the binary
cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist
cp "${SCRIPT_DIR}/Resources/Info.plist" "${APP_DIR}/Contents/"

# Create PkgInfo
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# Ad-hoc code sign with entitlements
echo "🔏 Signing app bundle..."
codesign --force --sign - \
    --entitlements "${SCRIPT_DIR}/ScreenAlert.entitlements" \
    "${APP_DIR}"

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
