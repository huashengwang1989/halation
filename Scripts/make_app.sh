#!/bin/bash
# Assembles the SwiftPM executable into a launchable Halation.app.
#
# SwiftPM cannot emit an app bundle directly, so we build the executable and wrap
# it. Xcode can also open Package.swift directly if you prefer working there.
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/Halation.app"

# Version the bundle advertises. Defaults to the most recent git tag so a
# release is stamped by tagging it rather than by editing this file.
#
# The `|| true` is load-bearing under `set -e`: an assignment takes the exit
# status of its command substitution, and `git describe` exits 128 in a repo
# with no tags — which is every repo until the first release.
GIT_TAG="$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null || true)"
VERSION="${VERSION:-${GIT_TAG#v}}"
VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)}"

# Signing identity. Ad-hoc by default, which is right for local use: it costs
# nothing and it keeps the app's TCC permissions across rebuilds. Distribution
# needs a real one — see Scripts/make_dmg.sh, which explains the whole path.
#
#   CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make dmg
IDENTITY="${CODESIGN_IDENTITY:--}"

# com.local.* is fine until the app is signed, at which point the identifier has
# to be one you own or notarization has nothing to tie the signature to.
BUNDLE_ID="${BUNDLE_ID:-com.local.halation}"

# The minimum macOS the bundle admits to. The source builds for Sequoia, but the
# *appearance* follows the compiled deployment target, not this string — see
# .agent/verified-facts.md. Lowering this alone does not produce a Sequoia build.
MIN_MACOS="${MIN_MACOS:-26.0}"

cd "$ROOT"

# Verified rather than regenerated. Silently rebuilding the .strings files here
# would make every local build correct while the files in the commit stayed
# stale — the drift would survive all the way to whoever cloned the repo.
# Captured rather than piped: a pipeline takes the exit status of its *last*
# command, so piping this through grep would report grep's success and let a
# failing check through silently.
echo "==> Checking localisations"
if ! CHECK_OUTPUT="$(python3 "$ROOT/Scripts/check_translations.py")"; then
  printf '%s\n' "$CHECK_OUTPUT"
  echo "    run: python3 Scripts/build_strings.py"
  exit 1
fi
printf '  %s\n' "$(printf '%s\n' "$CHECK_OUTPUT" | tail -1)"

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
    <key>CFBundleIdentifier</key>            <string>__BUNDLE_ID__</string>
    <key>CFBundleExecutable</key>            <string>Halation</string>
    <key>CFBundlePackageType</key>           <string>APPL</string>
    <key>CFBundleShortVersionString</key>    <string>__VERSION__</string>
    <key>CFBundleVersion</key>               <string>__BUILD__</string>
    <key>LSMinimumSystemVersion</key>        <string>__MIN_MACOS__</string>
    <key>NSHighResolutionCapable</key>       <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Huasheng. AGPL-3.0. Model weights are downloaded, not included, and are licensed separately by their publishers.</string>
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

# Substituted after the heredoc rather than interpolated inside it, because the
# plist is quoted to stop the shell touching anything else in it.
python3 - "$APP/Contents/Info.plist" "$VERSION" "$BUILD" "$MIN_MACOS" "$BUNDLE_ID" <<'SUBST'
import sys
path, version, build, minos, bundle_id = sys.argv[1:6]
text = open(path).read()
for key, value in (("__VERSION__", version), ("__BUILD__", build),
                   ("__MIN_MACOS__", minos), ("__BUNDLE_ID__", bundle_id)):
    text = text.replace(key, value)
open(path, "w").write(text)
SUBST
echo "    version $VERSION ($BUILD), minimum macOS $MIN_MACOS, id $BUNDLE_ID"

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

# A Developer ID signature needs the hardened runtime, or notarization rejects
# the app outright. An ad-hoc one must *not* have it: the flag is meaningless
# without a real identity and only makes local debugging harder.
#
# --deep is deprecated and signs inside out in an order Apple no longer trusts.
# Nested code is signed first and explicitly instead; this bundle has none today
# beyond the resource bundles, but the loop costs nothing and is the part people
# forget when they later add a helper tool.
if [ "$IDENTITY" = "-" ]; then
  echo "==> Signing (ad-hoc — local use only)"
  SIGN_ARGS=(--force --sign -)
else
  echo "==> Signing ($IDENTITY)"
  SIGN_ARGS=(--force --sign "$IDENTITY" --options runtime --timestamp
             --entitlements "$ROOT/Scripts/entitlements.plist")
fi

# Nested code is signed first, innermost outwards, because a signature covers
# the seal of everything beneath it. Note these are *directories*: a .bundle is
# signed as a unit, not as the files inside it, which is why matching on the
# executable bit finds nothing and the outer signature then fails with
# "code object is not signed at all".
while IFS= read -r NESTED; do
  [ -n "$NESTED" ] || continue
  codesign "${SIGN_ARGS[@]}" "$NESTED" >/dev/null 2>&1 ||
    echo "    could not sign $(basename "$NESTED")"
done < <(find "$APP/Contents" -depth \( -name "*.bundle" -o -name "*.framework" \
                                      -o -name "*.app" -o -name "*.dylib" \) 2>/dev/null)

if codesign "${SIGN_ARGS[@]}" "$APP"; then
  codesign --verify --strict --verbose=2 "$APP" 2>&1 | sed 's/^/    /'
else
  echo "    codesign failed; the app will still run on this machine"
fi

echo "==> Done: $APP"
