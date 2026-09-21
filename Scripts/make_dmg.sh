#!/bin/bash
# Builds dist/Halation-<version>.dmg: the app, an Applications symlink, and a
# window laid out so the drag is the obvious thing to do.
#
#   make dmg
#
# A disk image rather than an installer package, because there is nothing to
# install. The app creates its own Python runtime under
# ~/Library/Application Support/Halation on first launch and downloads weights on
# demand, so a .pkg would ask for an admin password in order to do nothing, and
# would leave users no clean way to remove it. Drag in, drag out.
#
# ---------------------------------------------------------------------------
# Signing, which is the part that actually decides whether this works
# ---------------------------------------------------------------------------
# An ad-hoc signature is fine on the machine that built it and useless anywhere
# else: a download carries the quarantine flag, Gatekeeper finds no identity to
# check, and macOS says the app "is damaged and can't be opened" — which is a
# lie about the cause, and the single most common way a first release goes
# wrong. Nothing about the DMG format changes this.
#
# Three tiers, in the order most projects actually move through them:
#
#   1. Unsigned/ad-hoc + instructions. Costs nothing. Every user must right-click
#      → Open, or clear the flag by hand, and some will not get past it. For an
#      AGPL project whose audience builds from source anyway, this is defensible
#      as a starting point.
#
#   2. Developer ID + notarization. $99/year for an Apple Developer account.
#      Opens cleanly with a double-click for everyone. This script does the whole
#      thing when you set the two variables below.
#
#   3. Mac App Store. Not an option here: the app downloads and executes a Python
#      runtime, which sandboxing forbids outright.
#
# For tier 2, once the certificate is in your keychain:
#
#   xcrun notarytool store-credentials halation-notary \
#       --apple-id you@example.com --team-id TEAMID --password APP-SPECIFIC-PW
#
#   CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   BUNDLE_ID="com.yourdomain.halation" \
#   NOTARY_PROFILE=halation-notary \
#   make dmg
#
# The password is an app-specific one from appleid.apple.com, not your Apple ID
# password. store-credentials puts it in the keychain so it stays out of your
# shell history and out of CI logs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/dist/Halation.app"
VOLUME="Halation"
# Local signing configuration, if there is any. Gitignored, so a Developer ID
# never reaches the repository — see Scripts/signing.local.sh.example.
LOCAL_SIGNING="$ROOT/Scripts/signing.local.sh"
# shellcheck source=/dev/null
[ -f "$LOCAL_SIGNING" ] && . "$LOCAL_SIGNING"

IDENTITY="${CODESIGN_IDENTITY:--}"

[ -d "$APP" ] || { echo "No $APP — run 'make app' first."; exit 1; }

VERSION="$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo 1.0)"
DMG="$ROOT/dist/Halation-$VERSION.dmg"
STAGE="$(mktemp -d -t halation-dmg)"
trap 'rm -rf "$STAGE" "$STAGE.rw.dmg"' EXIT

echo "==> Rendering background art"
swift "$ROOT/Design/RenderDMGBackground.swift" | sed 's/^/  /'

echo "==> Staging"
cp -R "$APP" "$STAGE/Halation.app"
ln -s /Applications "$STAGE/Applications"

# The background lives in a dot-directory so Finder hides it: the window must
# show exactly two items, or the drag stops being obvious.
#
# A multi-resolution TIFF rather than a PNG. Finder picks the representation
# matching the display, and given only a 1x PNG it upscales — which on a Retina
# Mac, where most of these will be opened, looks worse than no background.
mkdir -p "$STAGE/.background"
if [ -f "$ROOT/Design/out/dmg-bg.png" ] && [ -f "$ROOT/Design/out/dmg-bg@2x.png" ]; then
  tiffutil -cathidpicheck "$ROOT/Design/out/dmg-bg.png" "$ROOT/Design/out/dmg-bg@2x.png" \
      -out "$STAGE/.background/background.tiff" >/dev/null 2>&1 ||
    cp "$ROOT/Design/out/dmg-bg.png" "$STAGE/.background/background.tiff"
else
  echo "    no background art — run 'swift Design/RenderDMGBackground.swift'"
fi

# hdiutil will not grow a read-write image, and the Finder pass below writes a
# .DS_Store into it, so ask for meaningfully more room than the payload needs.
SIZE_KB=$(( $(du -sk "$STAGE" | cut -f1) + 20000 ))

# macOS 26 deprecated hdiutil in favour of `diskutil image` and prints a warning
# for each call. hdiutil still works and is the only one of the two that exists
# on earlier systems, so the warnings are noise and the tool stays.
echo "==> Creating read-write image"
rm -f "$STAGE.rw.dmg" "$DMG"
hdiutil create -srcfolder "$STAGE" -volname "$VOLUME" -fs HFS+ \
    -format UDRW -size "${SIZE_KB}k" "$STAGE.rw.dmg" >/dev/null

MOUNT="$(hdiutil attach "$STAGE.rw.dmg" -nobrowse -noautoopen |
         grep -o '/Volumes/.*' | head -1)"

# Finder is what persists icon positions, and it needs Automation permission to
# be driven. Best effort on purpose: if it is refused, or nobody is logged in
# because this is CI, the image is still correct — just arranged by name rather
# than placed.
# The layout is written straight into the volume's .DS_Store rather than driven
# through Finder — see the comment at the top of make_dmg_layout.py for why the
# AppleScript approach everyone documents no longer works on macOS 26.
#
# That script needs two build-time packages. They are kept in a throwaway venv
# under .build rather than installed globally, because nothing else here wants
# them and they never ship in the app.
echo "==> Laying out the window"
LAYOUT_PY="python3"
if ! python3 -c "import ds_store, mac_alias" >/dev/null 2>&1; then
  VENV="$ROOT/.build/dmg-tools"
  if [ ! -x "$VENV/bin/python" ]; then
    echo "    fetching ds-store and mac_alias (once)"
    python3 -m venv "$VENV" >/dev/null 2>&1 || true
    "$VENV/bin/pip" install --quiet ds-store mac_alias >/dev/null 2>&1 || true
  fi
  LAYOUT_PY="$VENV/bin/python"
fi

if "$LAYOUT_PY" -c "import ds_store, mac_alias" >/dev/null 2>&1; then
  "$LAYOUT_PY" "$ROOT/Scripts/make_dmg_layout.py" "$MOUNT"
else
  echo "    ds-store unavailable and could not be fetched; the image will open"
  echo "    with Finder's default window. Everything else about it is fine."
fi

sync
# "Resource busy" here is routine — Finder is often still holding the volume it
# was just asked to look at.
for _ in 1 2 3 4 5; do
    hdiutil detach "$MOUNT" >/dev/null 2>&1 && break
    sleep 1
done
hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true

echo "==> Compressing"
hdiutil convert "$STAGE.rw.dmg" -format UDZO -imagekey zlib-level=9 \
    -o "$DMG" >/dev/null

# The DMG is signed as well as the app. Gatekeeper checks the container the user
# actually double-clicks, and an unsigned one throws its own warning even when
# the app inside is spotless.
if [ "$IDENTITY" != "-" ]; then
    echo "==> Signing the image"
    codesign --force --sign "$IDENTITY" --timestamp "$DMG"
fi

if [ -n "${NOTARY_PROFILE:-}" ] && [ "$IDENTITY" != "-" ]; then
    echo "==> Notarizing (a few minutes; Apple scans it server-side)"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    # Stapling writes the ticket into the image so it validates offline. Without
    # it, a user who is first offline sees the same warning as an unnotarized
    # app — the check silently falls back to asking Apple.
    xcrun stapler staple "$DMG"
    echo "==> Verifying as Gatekeeper will see it"
    spctl --assess --type open --context context:primary-signature -v "$DMG" 2>&1 | sed 's/^/    /'
fi

echo
echo "==> $DMG  ($(du -h "$DMG" | cut -f1))"
if [ "$IDENTITY" = "-" ]; then
cat <<'NOTE'

    Ad-hoc signed. This opens on the machine that built it and will be blocked
    on any machine that downloads it — macOS will claim the app "is damaged",
    which is misleading: it means unsigned, not corrupt. Either tell users to
    right-click the app and choose Open, or read the signing notes at the top of
    this script and do tier 2.
NOTE
fi
