#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

# 1. Build if not already built or needs refresh
if [ ! -f "MusicMixStudio.app/Contents/MacOS/MusicMixStudio" ]; then
    echo "==> Building Music Mix Studio..."
    ./build.sh
fi

# 2. Determine target Applications folder
TARGET_DIR="/Applications"
if [ ! -w "$TARGET_DIR" ]; then
    TARGET_DIR="$HOME/Applications"
    mkdir -p "$TARGET_DIR"
fi

INSTALL_PATH="$TARGET_DIR/Music Mix Studio.app"

echo "==> Installing to $INSTALL_PATH..."
rm -rf "$INSTALL_PATH"
cp -R "MusicMixStudio.app" "$INSTALL_PATH"
xattr -cr "$INSTALL_PATH" 2>/dev/null || true

echo ""
echo "✅ Music Mix Studio has been successfully installed!"
echo "📍 Location: $INSTALL_PATH"
echo "🚀 You can now find and launch it via:"
echo "   • Spotlight (press Cmd + Space and type 'Music Mix Studio')"
echo "   • Launchpad"
echo "   • Finder > Applications"
