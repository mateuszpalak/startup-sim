#!/usr/bin/env python3
"""Phone icons from <client>/icons/icon.svg for both clients, client/ (2D)
and client3d/ (needs rsvg-convert and magick).

The desktop icon is a rounded tile with a rim and transparent corners; phones
mask the icon themselves, so they get the picture full-bleed instead:

  <client>/icons/icon_ios.png                     1024 px, opaque (App Store)
  <client>/icons/android/icon_192.png             legacy launcher icon
  <client>/icons/android/adaptive_background_432.png  sky, moon, city, street
  <client>/icons/android/adaptive_foreground_432.png  the mug (transparent),
                                                     inside the 66 % safe zone

Usage: python3 tools/make_icons.py
"""
import pathlib
import re
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent


def svg(defs: str, view: str, body: str) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}" width="1024" height="1024">'
            f"{defs}{body}</svg>")


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


def make(icons: pathlib.Path) -> None:
    src = (icons / "icon.svg").read_text()
    # Pieces of icon.svg (by their comments / elements).
    defs = re.search(r"<defs>.*?</defs>", src, re.S).group(0)
    scene = re.search(r'<g clip-path="url\(#tile\)">(.*?)\n  </g>\n  <!-- steam -->', src, re.S).group(1)
    mug = re.search(r"(  <!-- steam -->.*?)  <!-- tile rim -->", src, re.S).group(1)
    # Full bleed: the sky fills the whole square and a dark street closes the
    # bottom (the tile's rim used to hide the gap under the mug).
    scene = scene.replace('<rect x="64" y="64" width="896" height="896" fill="url(#sky)"/>',
                          '<rect x="0" y="0" width="1024" height="1024" fill="url(#sky)"/>')
    street = '<rect x="0" y="860" width="1024" height="164" fill="#1c1622"/>'
    frame = "64 64 896 896"  # the tile's framing, without its margin
    full = svg(defs, frame, scene + street + mug)
    render(full, icons / "icon_ios.png", 1024, True)
    render(full, icons / "android" / "icon_192.png", 192, True)
    # Adaptive: the launcher crops to ~66 % of the 108 dp layer, so the mug is
    # shrunk around its centre (~ 590, 545) to fit the safe circle.
    render(svg(defs, frame, scene + street), icons / "android" / "adaptive_background_432.png", 432, True)
    render(svg(defs, "0 0 1024 1024", f'<g transform="translate(512 512) scale(0.6) translate(-590 -545)">{mug}</g>'),
           icons / "android" / "adaptive_foreground_432.png", 432, False)


for client in ("client", "client3d"):
    (ROOT / client / "icons" / "android").mkdir(exist_ok=True)
    make(ROOT / client / "icons")
print("icons written")
