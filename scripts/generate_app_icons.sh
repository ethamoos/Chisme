#!/usr/bin/env bash
set -euo pipefail

# Script to generate AppIcon images and an .icns from a high-resolution source image
# Usage: ./scripts/generate_app_icons.sh "Assets.xcassets/Chisme.icon/Assets/chisme 2.jpg"

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
DEST="$ROOT_DIR/Assets.xcassets/AppIcon.appiconset"
ICONSET="$ROOT_DIR/AppIcon.iconset"

pick_source() {
  # If user supplied a path, use it
  if [ -n "${1-}" ]; then
    echo "$1"
    return 0
  fi
  # Try to auto-detect a high-res source inside Assets.xcassets (search recursively)
  local base="$ROOT_DIR/Assets.xcassets"
  if [ -d "$base" ]; then
    # prefer files containing "chisme" then pick the largest by filesize if possible
    candidate=$(find "$base" -type f \( -iname "*chisme*" -o -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) -print0 | xargs -0 ls -1 -S 2>/dev/null | head -n1 || true)
    if [ -n "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  fi
  return 1
}

SRC=$(pick_source "${1-}") || {
  echo "Error: No source image found. Provide a source image path as the first argument." >&2
  echo "Example: ./scripts/generate_app_icons.sh \"Assets.xcassets/Chisme.icon/Assets/chisme 2.jpg\"" >&2
  exit 1
}

echo "Using source image: $SRC"
echo "Destination iconset: $DEST"

mkdir -p "$DEST"
rm -f "$DEST"/AppIcon-*.png || true

echo "Generating PNG sizes..."
sizes=("16 16" "32 32" "32 32" "64 64" "128 128" "256 256" "256 256" "512 512" "512 512" "1024 1024")
filenames=(
  "AppIcon-16x16.png"
  "AppIcon-16x16@2x.png"
  "AppIcon-32x32.png"
  "AppIcon-32x32@2x.png"
  "AppIcon-128x128.png"
  "AppIcon-128x128@2x.png"
  "AppIcon-256x256.png"
  "AppIcon-256x256@2x.png"
  "AppIcon-512x512.png"
  "AppIcon-512x512@2x.png"
)

for i in "${!filenames[@]}"; do
  fname=${filenames[$i]}
  dims=${sizes[$i]}
  width=${dims%% *}
  height=${dims##* }
  out="$DEST/$fname"
  echo "  -> $fname ($width x $height)"
  if ! sips -z "$height" "$width" "$SRC" --out "$out" >/dev/null 2>&1; then
    echo "Error: sips failed to create $out from $SRC" >&2
    exit 1
  fi
done

echo "Preparing iconset for iconutil (copying from appiconset)..."
rm -rf "$ICONSET" || true
mkdir -p "$ICONSET"

# Map appiconset filenames to iconset filenames and copy the generated PNGs into the iconset
declare -a map_src=(
  "AppIcon-16x16.png"
  "AppIcon-16x16@2x.png"
  "AppIcon-32x32.png"
  "AppIcon-32x32@2x.png"
  "AppIcon-128x128.png"
  "AppIcon-128x128@2x.png"
  "AppIcon-256x256.png"
  "AppIcon-256x256@2x.png"
  "AppIcon-512x512.png"
  "AppIcon-512x512@2x.png"
)
declare -a map_dst=(
  "icon_16x16.png"
  "icon_16x16@2x.png"
  "icon_32x32.png"
  "icon_32x32@2x.png"
  "icon_128x128.png"
  "icon_128x128@2x.png"
  "icon_256x256.png"
  "icon_256x256@2x.png"
  "icon_512x512.png"
  "icon_512x512@2x.png"
)

for i in "${!map_src[@]}"; do
  src_name=${map_src[$i]}
  dst_name=${map_dst[$i]}
  src_path="$DEST/$src_name"
  dst_path="$ICONSET/$dst_name"
  echo "  -> $dst_name <= $src_name"
  if [ -f "$src_path" ]; then
    cp "$src_path" "$dst_path"
  else
    echo "Warning: expected $src_path not found; iconset may be incomplete" >&2
  fi
done

echo "Iconset files:"
ls -la "$ICONSET"

if command -v iconutil >/dev/null 2>&1; then
  echo "Running iconutil to create AppIcon.icns..."
  if ! iconutil -c icns "$ICONSET" -o "$DEST/AppIcon.icns" 2> "$ROOT_DIR/scripts/iconutil.log"; then
    echo "iconutil failed. See log: $ROOT_DIR/scripts/iconutil.log" >&2
    echo "Contents of iconset:" >&2
    ls -la "$ICONSET" >&2
    exit 1
  fi
  echo "Created $DEST/AppIcon.icns"
else
  echo "iconutil not available on this machine. AppIcon.icns not created."
  echo "Xcode will still generate the .icns when you Archive if the 1024@2x PNG exists in the asset catalog."
fi

echo "Done. Please open Xcode, Clean Build Folder, then Archive the app to ensure the .icns is embedded in the bundle."
