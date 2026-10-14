#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
for arch in arm64 x86_64; do
  xcrun swiftc -O -target "$arch-apple-macosx13.0" -module-cache-path build/module-cache Audio.swift main.swift -o "build/helper-$arch"
done
lipo -create build/helper-arm64 build/helper-x86_64 -output build/lid-microphone
strip -S build/lid-microphone
# Developer ID is optional for local builds; required for a notarized public release.
if [ -n "${SIGNING_IDENTITY:-}" ]; then
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp build/lid-microphone
else
  codesign --force --sign - --options runtime --timestamp=none build/lid-microphone
fi
python3 package.py
