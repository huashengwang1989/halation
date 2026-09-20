#!/bin/bash
# Builds the app icon from Design/RenderIcon.swift.
#
# Two outputs, because macOS 26 and everything before it want different things:
#
#   Design/out/Halation.icns   every macOS. A flattened tile at eight sizes.
#   Design/Halation.icon       macOS 26+. Layers the system lights, blurs and
#                              parallaxes for itself.
#
# The .icns is what `make_app.sh` installs, because SwiftPM has no asset
# catalogue step and `CFBundleIconFile` needs no compilation. The .icon is the
# editable source: open it in Icon Composer to adjust the layer treatments.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
OUT="Design/out"

echo "==> Rendering layers"
swift Design/RenderIcon.swift

echo "==> Building $OUT/Halation.icns"
ICONSET="$OUT/Halation.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"

# iconutil insists on exactly these names. @2x is the same pixel count as the
# next size up, so each render is used twice.
for spec in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" \
            "128 128x128" "256 128x128@2x" "256 256x256" "512 256x256@2x" \
            "512 512x512" "1024 512x512@2x"; do
    set -- $spec
    sips -z "$1" "$1" "$OUT/icon-1024.png" --out "$ICONSET/icon_$2.png" >/dev/null
done

iconutil --convert icns "$ICONSET" --output "$OUT/Halation.icns"
rm -rf "$ICONSET"
echo "    $(du -h "$OUT/Halation.icns" | cut -f1)"

echo "==> Assembling Design/Halation.icon"
BUNDLE="Design/Halation.icon"
rm -rf "$BUNDLE"; mkdir -p "$BUNDLE/Assets"
cp "$OUT/layer-bloom.png" "$BUNDLE/Assets/bloom.png"
cp "$OUT/layer-core.png" "$BUNDLE/Assets/core.png"

# Groups run FRONT TO BACK — the first entry is the topmost layer. This is the
# opposite of how CALayer and every drawing API here stack, and getting it
# backwards is silent: the icon still builds, it just shows the back layer
# tinting everything in front of it.
#
# The bloom has no "shadow" key, and that is deliberate. A group shadow is cast
# from its layers' alpha silhouette, so a soft glow gets a hard circle traced
# round it where the alpha reaches zero. There is no way to switch one off:
# "none", false and opacity 0 are all rejected. Omitting the key is the only
# accepted way to say no shadow.
#
# The core carries no "specular" either: it etches a rim along the layer's alpha
# edge, which on a glow is exactly where it should not be.
#
# Every key below was checked against actool one at a time; the schema is not
# documented anywhere and most plausible spellings are rejected outright. Two
# that cost the most to find: a colour is the string "<space>:r,g,b,a", and a
# linear-gradient takes a bare array of those — not {"colors": [...]}, which
# fails. `groups` is mandatory; layers at the top level are rejected.
cat > "$BUNDLE/icon.json" <<'JSON'
{
  "fill" : {
    "linear-gradient" : [
      "srgb:0.09,0.10,0.16,1.0",
      "srgb:0.03,0.03,0.06,1.0"
    ]
  },
  "groups" : [
    {
      "layers" : [
        { "image-name" : "core.png", "name" : "Core" }
      ],
      "shadow" : { "kind" : "neutral", "opacity" : 0.5 },
      "translucency" : { "enabled" : false, "value" : 0.5 }
    },
    {
      "layers" : [
        { "image-name" : "bloom.png", "name" : "Bloom" }
      ],
      "translucency" : { "enabled" : false, "value" : 0.5 }
    }
  ],
  "supported-platforms" : {
    "squares" : [ "macOS" ]
  }
}
JSON

echo "    $BUNDLE ($(find "$BUNDLE" -type f | wc -l | tr -d ' ') files)"
echo "==> Done"
