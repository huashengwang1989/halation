#!/bin/bash
# Assembles the SwiftPM executable into a launchable Halation.app.
#
# SwiftPM cannot emit an app bundle directly, so we build the executable and wrap
# it. Xcode can also open Package.swift directly if you prefer working there.
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/Halation.app"

cd "$ROOT"
echo "==> Building ($CONFIG)"
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/Halation" "$APP/Contents/MacOS/Halation"

# Bundle.module resolves relative to the executable's directory, so the resource
# bundle goes beside the binary as well as into Resources.
for BUNDLE in "$BIN_DIR"/*.bundle; do
  [ -e "$BUNDLE" ] || continue
  cp -R "$BUNDLE" "$APP/Contents/Resources/"
  cp -R "$BUNDLE" "$APP/Contents/MacOS/"
done

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                  <string>Halation</string>
    <key>CFBundleDisplayName</key>           <string>Halation</string>
    <key>CFBundleIdentifier</key>            <string>com.local.halation</string>
    <key>CFBundleExecutable</key>            <string>Halation</string>
    <key>CFBundlePackageType</key>           <string>APPL</string>
    <key>CFBundleShortVersionString</key>    <string>1.0</string>
    <key>CFBundleVersion</key>               <string>1</string>
    <key>LSMinimumSystemVersion</key>        <string>26.0</string>
    <key>NSHighResolutionCapable</key>       <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Huasheng Wang. AGPL-3.0. Model weights are downloaded, not included, and are licensed separately by their publishers.</string>
    <!-- The app reads weights from ~/Documents/AI Models and writes clips to Movies. -->
    <key>NSDocumentsFolderUsageDescription</key>
    <string>Halation stores and reads AI model weights in a shared folder inside Documents.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>Halation needs access if you choose a model or output folder on the Desktop.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>Halation needs access if you choose a model or output folder in Downloads.</string>
    <key>LSApplicationCategoryType</key>     <string>public.app-category.video</string>
    <!-- Both, deliberately. macOS 26 reads CFBundleIconName and renders the
         layered icon out of Assets.car; earlier systems know only
         CFBundleIconFile and take the flattened .icns. -->
    <key>CFBundleIconName</key>              <string>Halation</string>
    <key>CFBundleIconFile</key>              <string>Halation</string>
    <!-- The languages AppKit may localize its own chrome into come from the
         .lproj folders copied in below; this only names the fallback. Listing them
         again in CFBundleLocalizations just duplicates every entry in
         Bundle.main.localizations. -->
    <key>CFBundleDevelopmentRegion</key>     <string>en</string>
</dict>
</plist>
PLIST

# CFBundleLocalizations alone is not enough: CFBundle only treats a language as
# available when the bundle carries a populated .lproj, and that is what decides
# whether AppKit mirrors the window for a right-to-left language. The app reads
# its strings from the SwiftPM resource bundle at runtime; this copy is what makes
# the *main* bundle count as localized.
for LPROJ in "$ROOT"/Sources/Halation/Resources/Localizations/*.lproj; do
  [ -d "$LPROJ" ] || continue
  DEST="$APP/Contents/Resources/$(basename "$LPROJ")"
  mkdir -p "$DEST"
  cp "$LPROJ"/*.strings "$DEST/"
done

echo "==> Icon"
ICON_SRC="$ROOT/Design/out/Halation.icns"
if [ -f "$ICON_SRC" ]; then
  cp "$ICON_SRC" "$APP/Contents/Resources/Halation.icns"
  echo "    Halation.icns (all systems)"
else
  echo "    no .icns yet — run Scripts/make_icon.sh"
fi

# The layered icon is compiled by actool, which ships with Xcode. Without it the
# app still has an icon, just the flat one, so a missing toolchain is a
# downgrade rather than a build failure.
if [ -d "$ROOT/Design/Halation.icon" ] && xcrun --find actool >/dev/null 2>&1; then
  if xcrun actool "$ROOT/Design/Halation.icon" \
        --compile "$APP/Contents/Resources" \
        --app-icon Halation --platform macosx \
        --minimum-deployment-target 26.0 \
        --output-partial-info-plist "$(mktemp -t halicon)" >/dev/null 2>&1; then
    # actool also drops its own thin .icns beside the catalogue; ours covers
    # more sizes, so put it back.
    [ -f "$ICON_SRC" ] && cp "$ICON_SRC" "$APP/Contents/Resources/Halation.icns"
    echo "    Assets.car (layered, macOS 26+)"
  else
    echo "    actool could not compile the layered icon; flat icon only"
  fi
fi

# Ad-hoc signature: enough for local use, and required for the app to keep its
# TCC permissions across rebuilds. Replace with a Developer ID to distribute.
echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$APP" 2>/dev/null || \
  echo "    (codesign failed; the app will still run locally)"

echo "==> Done: $APP"
