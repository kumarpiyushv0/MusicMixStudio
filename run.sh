#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

if [ ! -f "MusicMixStudio.app/Contents/MacOS/MusicMixStudio" ]; then
    ./build.sh
fi

echo "Launching Music Mix Studio..."
open "MusicMixStudio.app" 2>/dev/null || ./MusicMixStudio.app/Contents/MacOS/MusicMixStudio &
echo "Music Mix Studio is running!"
