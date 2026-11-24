#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

if [ ! -f "AudioMerger.app/Contents/MacOS/AudioMerger" ]; then
    ./build.sh
fi

echo "Launching AudioMerger..."
open AudioMerger.app 2>/dev/null || ./AudioMerger.app/Contents/MacOS/AudioMerger &
echo "AudioMerger is running!"
