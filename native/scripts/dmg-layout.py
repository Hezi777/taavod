#!/usr/bin/env python3
"""Write Finder's layout metadata directly into a mounted writable DMG."""

from __future__ import annotations

import argparse
from pathlib import Path

from ds_store import DSStore
from mac_alias import Alias, Bookmark


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("volume", type=Path, help="Mounted writable disk image root")
    parser.add_argument("--app-name", default="Taavod.app")
    parser.add_argument("--window-width", type=int, default=760)
    parser.add_argument("--window-height", type=int, default=580)
    args = parser.parse_args()

    volume = args.volume.resolve(strict=True)
    app = volume / args.app_name
    applications = volume / "Applications"
    background = volume / ".background" / "InstallerBackground.png"
    for required in (app, applications, background):
        if not required.exists():
            raise SystemExit(f"Required DMG item is missing: {required}")

    bounds = "{{120, 120}, {%d, %d}}" % (args.window_width, args.window_height)
    background_alias = Alias.for_file(str(background)).to_bytes()
    background_bookmark = Bookmark.for_file(str(background))
    icon_view = {
        "viewOptionsVersion": 1,
        "backgroundType": 2,
        "backgroundColorRed": 0.027,
        "backgroundColorGreen": 0.031,
        "backgroundColorBlue": 0.043,
        "backgroundImageAlias": background_alias,
        "gridOffsetX": 0.0,
        "gridOffsetY": 0.0,
        "gridSpacing": 100.0,
        "arrangeBy": "none",
        "showIconPreview": False,
        "showItemInfo": False,
        "labelOnBottom": True,
        "textSize": 14.0,
        "iconSize": 128.0,
        "scrollPositionX": 0.0,
        "scrollPositionY": 0.0,
    }
    window = {
        "ShowStatusBar": False,
        "WindowBounds": bounds,
        "ContainerShowSidebar": False,
        "PreviewPaneVisibility": False,
        "SidebarWidth": 180,
        "ShowTabView": False,
        "ShowToolbar": False,
        "ShowPathbar": False,
        "ShowSidebar": False,
    }

    ds_store_path = volume / ".DS_Store"
    with DSStore.open(str(ds_store_path), "w+") as store:
        store["."]["vSrn"] = ("long", 1)
        store["."]["bwsp"] = window
        store["."]["icvp"] = icon_view
        store["."]["icvl"] = ("type", b"icnv")
        store["."]["pBBk"] = background_bookmark
        store[args.app_name]["Iloc"] = (200, 270)
        store["Applications"]["Iloc"] = (560, 270)


if __name__ == "__main__":
    main()
