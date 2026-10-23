#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
NATIVE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

command -v xcodegen >/dev/null 2>&1 || {
  printf '%s\n' 'xcodegen is required. Install XcodeGen, then rerun this script.' >&2
  exit 1
}

cd "$NATIVE_DIR"
xcodegen generate
xcodebuild \
  -project Taavod.xcodeproj \
  -scheme Taavod \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build
