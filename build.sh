#!/bin/bash
# Builds build/Audio Lock.app (Apple silicon + Intel).
set -euo pipefail
cd "$(dirname "$0")"
APP="build/Audio Lock.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS"
for ARCH in arm64 x86_64; do
  swiftc -O -target "$ARCH-apple-macos13.0" Sources/*.swift -o "build/AudioLock-$ARCH" \
    -framework Cocoa -framework CoreAudio -framework ServiceManagement
done
lipo -create build/AudioLock-arm64 build/AudioLock-x86_64 -output "$APP/Contents/MacOS/AudioLock"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"
