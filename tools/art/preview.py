"""Renders a scaled contact sheet of generated sprite sheets for visual review.

Usage: python3 tools/art/preview.py OUT.png [sheet_name ...] [--scale N] [--bg light|dark]
"""
import json
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GFX = os.path.join(ROOT, "assets", "gfx")


def main(argv):
    out = argv[0]
    names = [a for a in argv[1:] if not a.startswith("--")]
    scale = 4
    bg = (24, 22, 40, 255)
    if "--scale" in argv:
        scale = int(argv[argv.index("--scale") + 1])
        names = [n for n in names if n != str(scale)]
    if "--bg" in argv and argv[argv.index("--bg") + 1] == "light":
        bg = (120, 118, 140, 255)
        names = [n for n in names if n != "light"]
    with open(os.path.join(GFX, "sprites.json")) as f:
        meta = json.load(f)
    if not names:
        names = list(meta.keys())
    tiles = []
    for n in names:
        if n in meta:
            img = Image.open(os.path.join(GFX, meta[n]["file"]))
        else:
            img = Image.open(os.path.join(GFX, n if n.endswith(".png") else n + ".png"))
        tiles.append((n, img.resize((img.width * scale, img.height * scale), Image.NEAREST)))
    width = max(t.width for _, t in tiles) + 20
    height = sum(t.height + 18 for _, t in tiles) + 10
    sheet = Image.new("RGBA", (width, height), bg)
    d = ImageDraw.Draw(sheet)
    y = 6
    for n, t in tiles:
        d.text((8, y), n, fill=(255, 220, 160, 255))
        y += 12
        sheet.alpha_composite(t, (8, y))
        y += t.height + 6
    sheet.save(out)


if __name__ == "__main__":
    main(sys.argv[1:])
