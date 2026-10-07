#!/usr/bin/env python3
"""Phone icons from client3d/icons/icon.svg (needs rsvg-convert and magick).

The desktop icon is a rounded tile with a rim and transparent corners; phones
mask the icon themselves, so they get the picture full-bleed instead:

  client3d/icons/icon_ios.png                     1024 px, opaque (App Store)
  client3d/icons/android/icon_192.png             legacy launcher icon
  client3d/icons/android/adaptive_background_432.png  sky, moon, city, street
  client3d/icons/android/adaptive_foreground_432.png  the mug (transparent),
                                                     inside the 66 % safe zone

Usage: python3 tools/make_icons.py
"""
import pathlib
import re
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
ICONS = ROOT / "client3d" / "icons"
SRC = (ICONS / "icon.svg").read_text()

# Pieces of icon.svg (by their comments / elements).
DEFS = re.search(r"<defs>.*?</defs>", SRC, re.S).group(0)
SCENE = re.search(r'<g clip-path="url\(#tile\)">(.*?)\n  </g>\n  <!-- steam -->', SRC, re.S).group(1)
MUG = re.search(r"(  <!-- steam -->.*?)  <!-- tile rim -->", SRC, re.S).group(1)

# Full bleed: the sky fills the whole square and a dark street closes the
# bottom (the tile's rim used to hide the gap under the mug).
SCENE = SCENE.replace('<rect x="64" y="64" width="896" height="896" fill="url(#sky)"/>',
                      '<rect x="0" y="0" width="1024" height="1024" fill="url(#sky)"/>')
STREET = '<rect x="0" y="860" width="1024" height="164" fill="#1c1622"/>'


def svg(view: str, body: str) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}" width="1024" height="1024">'
            f"{DEFS}{body}</svg>")


def render(text: str, out: pathlib.Path, size: int, opaque: bool) -> None:
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
        f.write(text)
    tmp = out.with_suffix(".tmp.png")
    subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), "-o", str(tmp), f.name], check=True)
    cmd = ["magick", str(tmp)]
    if opaque:
        cmd += ["-background", "#1f1a2e", "-alpha", "remove", "-alpha", "off"]
    subprocess.run(cmd + ["-strip", f"PNG32:{out}" if not opaque else f"PNG24:{out}"], check=True)
    tmp.unlink()
    pathlib.Path(f.name).unlink()


FRAME = "64 64 896 896"  # the tile's framing, without its margin
full = svg(FRAME, SCENE + STREET + MUG)
render(full, ICONS / "icon_ios.png", 1024, True)
render(full, ICONS / "android" / "icon_192.png", 192, True)
# Adaptive: the launcher crops to ~66 % of the 108 dp layer, so the mug is
# shrunk around its centre (~ 590, 545) to fit the safe circle.
render(svg(FRAME, SCENE + STREET), ICONS / "android" / "adaptive_background_432.png", 432, True)
render(svg("0 0 1024 1024", f'<g transform="translate(512 512) scale(0.6) translate(-590 -545)">{MUG}</g>'),
       ICONS / "android" / "adaptive_foreground_432.png", 432, False)
print("icons written")
