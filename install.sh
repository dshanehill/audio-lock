#!/bin/bash
# Builds Audio Lock from source, installs it in Applications and starts it.
# One-line install:
#   curl -fsSL https://raw.githubusercontent.com/dshanehill/audio-lock/main/install.sh | bash
set -euo pipefail
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Installing Apple's command line tools first. Run this again when that finishes."
  xcode-select --install
  exit 1
fi
SRC="$(mktemp -d)"
curl -fsSL https://github.com/dshanehill/audio-lock/archive/refs/heads/main.tar.gz | tar -xz -C "$SRC" --strip-components 1
bash "$SRC/build.sh"
DEST="/Applications"
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"
pkill -x AudioLock 2>/dev/null || true
rm -rf "$DEST/Audio Lock.app"
cp -R "$SRC/build/Audio Lock.app" "$DEST/"
open "$DEST/Audio Lock.app"
echo "Audio Lock is installed in $DEST and running. It will start at every login."
