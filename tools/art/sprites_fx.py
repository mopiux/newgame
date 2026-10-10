"""Small effects: projectiles, embers, sparks, glow textures, impacts."""
import math

from PIL import Image

from palette import PAL
from pixel import SheetBuilder, grid, blank, recolor


def mirror(half_rows):
    return [r + r[::-1] for r in half_rows]


BOLT_A = [
    "..0000..",
    ".0yYYy0.",
    "0yYllYy0",
    "0YlwwlY0",
    "0YlwwlY0",
    "0yYllYy0",
    ".0yYYy0.",
    "..0000..",
]
BOLT_B = [
    "........",
    "..0yy0..",
    ".0YllY0.",
    ".ylwwly.",
    ".ylwwly.",
    ".0YllY0.",
    "..0yy0..",
    "........",
]

ORB_A = [
    "..0000..",
    ".0pPPp0.",
    "0pPmmPp0",
    "0PmMMmP0",
    "0PmMMmP0",
    "0pPmmPp0",
    ".0pPPp0.",
    "..0000..",
]
ORB_B = [
    "........",
    "..0pp0..",
    ".0PmmP0.",
    ".pmMMmp.",
    ".pmMMmp.",
    ".0PmmP0.",
    "..0pp0..",
    "........",
]

EMBER = [
    ["......", "..yY..", ".yYlY.", ".Ylwy.", "..Yy..", "......"],
    ["......", "..Yy..", ".YlwY.", ".yYly.", "..yY..", "......"],
    ["......", "..yy..", ".yYYy.", ".yYYy.", "..yy..", "......"],
]

SPARK = [
    ["...0...", "..0T0..", ".0TwT0.", "0TwwwT0", ".0TwT0.", "..0T0..", "...0..."],
    ["...0...", "..0t0..", ".0tTt0.", "0tTwTt0", ".0tTt0.", "..0t0..", "...0..."],
    ["...0...", "..0T0..", ".0TlT0.", "0TlwlT0", ".0TlT0.", "..0T0..", "...0..."],
]


def _impact_frames(colors):
    frames = []
    for i, r in enumerate((2, 4, 6, 7)):
        img = blank(16, 16)
        px = img.load()
        for y in range(16):
            for x in range(16):
                d = math.hypot(x - 7.5, y - 7.5)
                if r - 1.6 < d < r + 0.4:
                    px[x, y] = PAL[colors[min(i, len(colors) - 1)]]
                elif i == 0 and d < r:
                    px[x, y] = PAL["w"]
        frames.append(img)
    return frames


def build_fx():
    sheets = []
    sb = SheetBuilder("bolt", 8, 8)
    sb.add("fly", [grid(BOLT_A), grid(BOLT_B)], fps=14)
    sheets.append(sb)

    sb = SheetBuilder("bolt_blue", 8, 8)
    blue = {"y": "t", "Y": "T", "l": "T", "w": "w"}
    sb.add("fly", [recolor(grid(BOLT_A), blue), recolor(grid(BOLT_B), blue)], fps=14)
    sheets.append(sb)

    sb = SheetBuilder("orb", 8, 8)
    sb.add("fly", [grid(ORB_A), grid(ORB_B)], fps=10)
    sheets.append(sb)

    sb = SheetBuilder("orb_ember", 8, 8)
    ember = {"p": "r", "P": "o", "m": "O", "M": "Y"}
    sb.add("fly", [recolor(grid(ORB_A), ember), recolor(grid(ORB_B), ember)], fps=10)
    sheets.append(sb)

    sb = SheetBuilder("ember", 6, 6)
    sb.add("idle", [grid(f) for f in EMBER], fps=8)
    sheets.append(sb)

    sb = SheetBuilder("spark", 7, 7)
    sb.add("idle", [grid(f) for f in SPARK], fps=6)
    sheets.append(sb)

    sb = SheetBuilder("impact", 16, 16)
    sb.add("warm", _impact_frames(["w", "l", "Y", "y"]), fps=24, loop=False)
    sb.add("dark", _impact_frames(["M", "m", "P", "p"]), fps=24, loop=False)
    sb.add("cold", _impact_frames(["w", "T", "t", "C"]), fps=24, loop=False)
    sheets.append(sb)
    return sheets


def glow_textures():
    """Soft radial gradients used with additive blending for light halos."""
    out = {}
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - size / 2 + 0.5, y - size / 2 + 0.5) / (size / 2)
            a = max(0.0, 1.0 - d)
            a = a * a
            px[x, y] = (255, 255, 255, int(a * 255))
    out["glow"] = img
    # pixel-stepped variant for small emissive halos
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    px = img.load()
    for y in range(32):
        for x in range(32):
            d = math.hypot(x - 15.5, y - 15.5) / 16
            a = max(0.0, 1.0 - d)
            a = round(a * a * 4) / 4
            px[x, y] = (255, 255, 255, int(a * 200))
    out["glow_px"] = img
    # 1x1 white for solid rects
    out["white"] = Image.new("RGBA", (4, 4), (255, 255, 255, 255))
    # soft shadow ellipse
    img = Image.new("RGBA", (16, 6), (0, 0, 0, 0))
    px = img.load()
    for y in range(6):
        for x in range(16):
            d = ((x - 7.5) / 8) ** 2 + ((y - 2.5) / 3) ** 2
            if d < 1:
                px[x, y] = (11, 10, 18, 110 if d < 0.55 else 60)
    out["shadow"] = img
    return out
