#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

APP_NAME="MusicMixStudio"
BUNDLE_DIR="$APP_NAME.app"
ENTITLEMENTS="MusicMixStudio.entitlements"

APP_CERT="$1"
INSTALLER_CERT="$2"

if [ -z "$APP_CERT" ] || [ -z "$INSTALLER_CERT" ]; then
    echo "=========================================================================="
    echo "  Music Mix Studio - Mac App Store Packaging Script"
    echo "=========================================================================="
    echo "Usage:"
    echo "  ./package_for_appstore.sh \"<Apple Distribution Cert>\" \"<Installer Cert>\""
    echo ""
    echo "Example:"
    echo "  ./package_for_appstore.sh \"Apple Distribution: Your Name (TEAMID)\" \"3rd Party Mac Developer Installer: Your Name (TEAMID)\""
    echo ""
    echo "To list your installed certificates, run:"
    echo "  security find-identity -p codesigning -v"
    echo "=========================================================================="
    exit 1
fi

echo "==> 1. Building release binary with App Store configurations..."
./build.sh

echo "==> 2. Codesigning with Sandboxing & Hardened Runtime..."
codesign --force --deep --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$APP_CERT" \
    "$BUNDLE_DIR"

echo "==> 3. Verifying codesign signature..."
codesign --verify --deep --strict "$BUNDLE_DIR"

echo "==> 4. Building Mac App Store installer package (.pkg)..."
OUTPUT_PKG="MusicMixStudio_AppStore.pkg"
productbuild --component "$BUNDLE_DIR" /Applications \
    --sign "$INSTALLER_CERT" \
    "$OUTPUT_PKG"

echo ""
echo "=========================================================================="
echo "✅ Build & Package Complete!"
echo "📦 Output Package: $(pwd)/$OUTPUT_PKG"
echo ""
echo "Next Steps:"
echo "1. Open the 'Transporter' app on macOS (free from Mac App Store)."
echo "2. Drag and drop '$OUTPUT_PKG' into Transporter."
echo "3. Click 'Deliver' to upload to App Store Connect."
echo "=========================================================================="
