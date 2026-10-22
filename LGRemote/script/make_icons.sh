#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .icon-work
for variant in Light Dark; do
  iconset=".icon-work/AppIcon${variant}.iconset"
  mkdir -p "$iconset"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "Assets/AppIcon${variant}.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "Assets/AppIcon${variant}.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  python3 script/pack_icns.py "$iconset" "Assets/AppIcon${variant}.icns"
done
cp Assets/AppIconLight.icns Assets/AppIcon.icns
