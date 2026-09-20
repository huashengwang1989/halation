#!/usr/bin/env python3
"""Writes the .DS_Store that gives the disk image its window layout.

Finder is not involved, and that is the point.

The obvious way to lay out a DMG is to mount it and drive Finder with
AppleScript, which is what nearly every guide and every DMG tool still does. It
no longer works. On macOS 26 Finder accepts the settings — read `icon size` back
straight after setting it and it answers 128 — and then writes a .DS_Store built
from default state anyway: iconSize 48, arrangeBy name, no background. The
window bounds survive and the icon positions survive; everything in the icon
view options is dropped. osascript reports success throughout, so the failure is
silent and shows up only when someone opens the finished image.

Writing the records ourselves avoids all of that, and costs nothing else: it
needs no Automation permission, prompts nobody, and works on a CI box with no
one logged in.

Requires the `ds-store` and `mac_alias` packages, which are build-time only and
are never shipped in the app:

    pip install ds-store mac_alias

Run against the mounted read-write image, before it is compressed:

    make_dmg_layout.py /Volumes/Halation
"""
import sys
from pathlib import Path

from ds_store import DSStore
from mac_alias import Alias

# Shared with Design/RenderDMGBackground.swift, which draws the chevron at the
# midpoint of the two icon positions below. Change one and change the other.
WINDOW_WIDTH, WINDOW_HEIGHT = 640, 400
ICON_SIZE = 128
ICON_Y = 190
POSITIONS = {"Halation.app": (160, ICON_Y), "Applications": (480, ICON_Y)}
BACKGROUND = ".background/background.tiff"


def main(volume: str) -> int:
    root = Path(volume)
    if not root.is_dir():
        print(f"{volume} is not mounted", file=sys.stderr)
        return 1

    # Top-left of the window on screen. Only the size matters — the position is
    # where it opens the first time, and Finder moves it afterwards.
    bounds = f"{{{{200, 120}}, {{{WINDOW_WIDTH}, {WINDOW_HEIGHT}}}}}"

    icon_view = {
        "viewOptionsVersion": 1,
        "arrangeBy": "none",          # "name" re-sorts and discards our positions
        "iconSize": float(ICON_SIZE),
        "textSize": 13.0,
        "labelOnBottom": True,
        "showIconPreview": True,
        "showItemInfo": False,
        "gridSpacing": 100.0,
        "gridOffsetX": 0.0,
        "gridOffsetY": 0.0,
        "scrollPositionX": 0.0,
        "scrollPositionY": 0.0,
        "backgroundColorRed": 1.0,
        "backgroundColorGreen": 1.0,
        "backgroundColorBlue": 1.0,
    }

    background = root / BACKGROUND
    if background.is_file():
        # 2 means "picture". Finder wants both an alias and the plain path: the
        # alias is what it actually resolves, and old builds read the path.
        icon_view["backgroundType"] = 2
        icon_view["backgroundImageAlias"] = Alias.for_file(str(background)).to_bytes()
    else:
        icon_view["backgroundType"] = 0
        print(f"    no background at {BACKGROUND}; using a plain window")

    with DSStore.open(str(root / ".DS_Store"), "w+") as store:
        store["."]["bwsp"] = {
            "WindowBounds": bounds,
            "ShowToolbar": False,
            "ShowStatusBar": False,
            "ShowPathbar": False,
            "ShowSidebar": False,
            "ContainerShowSidebar": False,
            "ShowTabView": False,
            "SidebarWidth": 0,
        }
        store["."]["icvp"] = icon_view
        # "icnv" is what Finder reads to decide the view; without it a window can
        # open in list view with every icon setting above quietly unused.
        # ds_store infers the type for records it knows; for the rest it wants
        # an explicit ("type-code", value) pair, and raises otherwise.
        store["."]["vSrn"] = ("long", 1)
        store["."]["icvl"] = ("type", "icnv")

        for name, (x, y) in POSITIONS.items():
            store[name]["Iloc"] = (x, y)

    print(f"    {ICON_SIZE}pt icons, {WINDOW_WIDTH}×{WINDOW_HEIGHT} window, "
          f"{'background image' if background.is_file() else 'plain background'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/Volumes/Halation"))
