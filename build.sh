#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

APP_NAME="AudioMerger"
BUNDLE_DIR="$APP_NAME.app"
MACOS_DIR="$BUNDLE_DIR/Contents/MacOS"
RESOURCES_DIR="$BUNDLE_DIR/Contents/Resources"
CACHE_DIR="/tmp/swiftcache"
PLUGIN_DIR="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"

echo "==> Building $APP_NAME for macOS (arm64)..."

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$CACHE_DIR"

# Copy Info.plist
cp Info.plist "$BUNDLE_DIR/Contents/Info.plist"

# Collect all swift source files
SWIFT_FILES=(
    Sources/Models/AudioTrack.swift
    Sources/Models/MergeMode.swift
    Sources/Utilities/TimeFormatter.swift
    Sources/Utilities/DemoAudioGenerator.swift
    Sources/AudioEngine/WaveformGenerator.swift
    Sources/AudioEngine/AudioCompositionBuilder.swift
    Sources/AudioEngine/AudioPlayerController.swift
    Sources/AudioEngine/AudioExporter.swift
    Sources/Views/TrackRowView.swift
    Sources/Views/TimelineView.swift
    Sources/Views/TransportBarView.swift
    Sources/Views/ExportSheetView.swift
    Sources/Views/SequentialTrackListView.swift
    Sources/Views/ContentView.swift
    Sources/main.swift
)

echo "Compiling ${#SWIFT_FILES[@]} Swift source files..."

swiftc -parse-as-library \
    -module-cache-path "$CACHE_DIR" \
    -plugin-path "$PLUGIN_DIR" \
    -O \
    "${SWIFT_FILES[@]}" \
    -o "$MACOS_DIR/$APP_NAME"

chmod +x "$MACOS_DIR/$APP_NAME"
codesign --force --deep --sign - "$BUNDLE_DIR" 2>/dev/null || true

echo "==> Build completed successfully!"
echo "App bundle: $(pwd)/$BUNDLE_DIR"
