#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
NATIVE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
APP_SOURCE="$NATIVE_DIR/build/Build/Products/Release/Taavod.app"
OUTPUT_DIR="$NATIVE_DIR/output"
DMG_NAME="Taavod-1.0.0-arm64.dmg"

for tool in hdiutil codesign swiftc python3 ditto; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf '%s\n' "$tool is required to package Taavod." >&2
    exit 1
  }
done
python3 -c 'import ds_store, mac_alias' >/dev/null 2>&1 || {
  printf "%s\n" "Python packages ds-store and mac-alias are required for Finder layout metadata." >&2
  exit 1
}
[ -d "$APP_SOURCE" ] || {
  printf 'Release app not found: %s\nBuild the Taavod Release scheme first.\n' "$APP_SOURCE" >&2
  exit 1
}

mkdir -p "$OUTPUT_DIR"
OUTPUT="$OUTPUT_DIR/$DMG_NAME"
[ ! -e "$OUTPUT" ] || {
  printf 'Refusing to replace existing file: %s\n' "$OUTPUT" >&2
  exit 1
}

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/taavod-dmg.XXXXXX")
STAGE="$WORK_DIR/stage"
MOUNT="$WORK_DIR/mount"
RW_DMG="$WORK_DIR/Taavod-rw.dmg"
BG="$WORK_DIR/InstallerBackground.png"
BG_TOOL="$WORK_DIR/installer-background"
DEVICE=""

cleanup() {
  if [ -n "$DEVICE" ]; then
    hdiutil detach "$DEVICE" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$STAGE/.background" "$MOUNT"
ditto "$APP_SOURCE" "$STAGE/Taavod.app"
codesign --force --deep --sign - --timestamp=none "$STAGE/Taavod.app"
ln -s /Applications "$STAGE/Applications"
swiftc -O "$SCRIPT_DIR/InstallerBackground.swift" -o "$BG_TOOL"
"$BG_TOOL" "$BG"
cp "$BG" "$STAGE/.background/InstallerBackground.png"

hdiutil create -quiet -srcfolder "$STAGE" -volname Taavod -fs HFS+ -format UDRW "$RW_DMG"
ATTACH_PLIST="$WORK_DIR/attach.plist"
hdiutil attach -plist -nobrowse -mountpoint "$MOUNT" "$RW_DMG" > "$ATTACH_PLIST"
DEVICE=$(python3 - "$ATTACH_PLIST" "$MOUNT" <<'PYTHON'
import plistlib
import sys
from pathlib import Path
with open(sys.argv[1], "rb") as source:
    entities = plistlib.load(source)["system-entities"]
mount = Path(sys.argv[2]).resolve()
for entity in entities:
    if entity.get("mount-point") and Path(entity["mount-point"]).resolve() == mount:
        print(entity["dev-entry"])
        break
PYTHON
)
[ -n "$DEVICE" ] || {
  printf '%s\n' 'Could not mount the writable disk image.' >&2
  exit 1
}
python3 "$SCRIPT_DIR/dmg-layout.py" "$MOUNT"
hdiutil detach "$DEVICE" -quiet
DEVICE=""
PACKED_DMG="$WORK_DIR/$DMG_NAME"
hdiutil convert -quiet "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$PACKED_DMG"
hdiutil verify "$PACKED_DMG"
[ ! -e "$OUTPUT" ] || {
  printf 'Refusing to replace existing file: %s\n' "$OUTPUT" >&2
  exit 1
}
mv -n "$PACKED_DMG" "$OUTPUT"
[ ! -e "$PACKED_DMG" ] || {
  printf 'Refusing to replace existing file: %s\n' "$OUTPUT" >&2
  exit 1
}
printf 'Created %s\nThis app is ad-hoc signed and is not notarized.\n' "$OUTPUT"
