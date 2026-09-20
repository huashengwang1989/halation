#!/bin/bash
# Assembles the SwiftPM executable into a launchable VideoGen.app.
#
# SwiftPM cannot emit an app bundle directly, so we build the executable and wrap
# it. Xcode can also open Package.swift directly if you prefer working there.
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/VideoGen.app"

cd "$ROOT"
echo "==> Building ($CONFIG)"
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/VideoGen" "$APP/Contents/MacOS/VideoGen"

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
    <key>CFBundleName</key>                  <string>VideoGen</string>
    <key>CFBundleDisplayName</key>           <string>VideoGen</string>
    <key>CFBundleIdentifier</key>            <string>com.local.videogen</string>
    <key>CFBundleExecutable</key>            <string>VideoGen</string>
    <key>CFBundlePackageType</key>           <string>APPL</string>
    <key>CFBundleShortVersionString</key>    <string>1.0</string>
    <key>CFBundleVersion</key>               <string>1</string>
    <key>LSMinimumSystemVersion</key>        <string>26.0</string>
    <key>NSHighResolutionCapable</key>       <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Runs MiniMax H3 locally. Weights are licensed separately by MiniMax.</string>
    <!-- The app reads weights from ~/Documents/AI Models and writes clips to Movies. -->
    <key>NSDocumentsFolderUsageDescription</key>
    <string>VideoGen stores and reads AI model weights in a shared folder inside Documents.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>VideoGen needs access if you choose a model or output folder on the Desktop.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>VideoGen needs access if you choose a model or output folder in Downloads.</string>
    <key>LSApplicationCategoryType</key>     <string>public.app-category.video</string>
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
for LPROJ in "$ROOT"/Sources/VideoGen/Resources/Localizations/*.lproj; do
  [ -d "$LPROJ" ] || continue
  DEST="$APP/Contents/Resources/$(basename "$LPROJ")"
  mkdir -p "$DEST"
  cp "$LPROJ"/*.strings "$DEST/"
done

# Ad-hoc signature: enough for local use, and required for the app to keep its
# TCC permissions across rebuilds. Replace with a Developer ID to distribute.
echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$APP" 2>/dev/null || \
  echo "    (codesign failed; the app will still run locally)"

echo "==> Done: $APP"
