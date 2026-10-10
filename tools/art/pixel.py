"""Small pixel-art toolkit used by build_art.py.

Every sprite in Lumbre is authored as ASCII grids that index the project
palette (palette.py). Helpers here turn grids into images, add outlines,
compose layers and pack frames into sprite sheets.
"""
from __future__ import annotations

import random
from typing import Iterable, Sequence

from PIL import Image

from palette import PAL, OUTLINE

TRANSPARENT = (0, 0, 0, 0)


def grid(rows: Sequence[str], pal: dict | None = None) -> Image.Image:
    """Builds an RGBA image from ASCII rows. '.' and ' ' are transparent."""
    pal = pal or PAL
    width = max(len(r) for r in rows)
    for i, r in enumerate(rows):
        if len(r) != width:
            raise ValueError(f"row {i} has width {len(r)}, expected {width}: {r!r}")
    img = Image.new("RGBA", (width, len(rows)), TRANSPARENT)
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in ". ":
                continue
            if ch not in pal:
                raise KeyError(f"unknown palette key {ch!r} at {x},{y}")
            px[x, y] = pal[ch]
    return img


def blank(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), TRANSPARENT)


def paste(dst: Image.Image, src: Image.Image, x: int, y: int) -> Image.Image:
    """Alpha-composites src over dst at integer coordinates (in place)."""
    dst.alpha_composite(src, (x, y)) if x >= 0 and y >= 0 else _paste_clipped(dst, src, x, y)
    return dst


def _paste_clipped(dst: Image.Image, src: Image.Image, x: int, y: int) -> None:
    sx, sy = max(0, -x), max(0, -y)
    crop = src.crop((sx, sy, src.width, src.height))
    dst.alpha_composite(crop, (max(0, x), max(0, y)))


def outline(img: Image.Image, color=OUTLINE, diagonal: bool = False) -> Image.Image:
    """Adds a 1px outline around opaque pixels. The image must already have
    one pixel of transparent margin wherever the outline should appear."""
    out = img.copy()
    src = img.load()
    dst = out.load()
    w, h = img.size
    dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if diagonal:
        dirs += [(1, 1), (-1, 1), (1, -1), (-1, -1)]
    for y in range(h):
        for x in range(w):
            if src[x, y][3] != 0:
                continue
            for dx, dy in dirs:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] != 0:
                    dst[x, y] = color
                    break
    return out


def flip_h(img: Image.Image) -> Image.Image:
    return img.transpose(Image.FLIP_LEFT_RIGHT)


def shift(img: Image.Image, dx: int, dy: int) -> Image.Image:
    out = blank(*img.size)
    out.alpha_composite(img.crop((max(0, -dx), max(0, -dy), img.width - max(0, dx), img.height - max(0, dy))), (max(0, dx), max(0, dy)))
    return out


def recolor(img: Image.Image, mapping: dict) -> Image.Image:
    """Swaps palette colours (keys/values are palette chars or RGBA tuples)."""
    def c(v):
        return PAL[v] if isinstance(v, str) else v
    table = {c(k): c(v) for k, v in mapping.items()}
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p in table:
                px[x, y] = table[p]
    return out


def silhouette(img: Image.Image, color) -> Image.Image:
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y][3]:
                px[x, y] = color
    return out


def hstack(frames: Iterable[Image.Image]) -> Image.Image:
    frames = list(frames)
    w = sum(f.width for f in frames)
    h = max(f.height for f in frames)
    out = blank(w, h)
    x = 0
    for f in frames:
        out.alpha_composite(f, (x, 0))
        x += f.width
    return out


def pad(img: Image.Image, w: int, h: int, anchor: str = "bottom") -> Image.Image:
    """Centers img horizontally inside a w*h canvas, aligned to the bottom or center."""
    out = blank(w, h)
    x = (w - img.width) // 2
    y = h - img.height if anchor == "bottom" else (h - img.height) // 2
    out.alpha_composite(img, (x, y))
    return out


def noise_choice(rng: random.Random, options: Sequence, weights: Sequence[float] | None = None):
    return rng.choices(options, weights=weights, k=1)[0]


def dither_pick(x: int, y: int, level: float) -> bool:
    """4x4 Bayer ordered dither: returns True when (x, y) is 'on' for level 0..1."""
    bayer = (0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5)
    return (bayer[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0 < level


class SheetBuilder:
    """Collects named animations of equal-size frames into one PNG strip-grid
    plus JSON metadata consumed by the game's SpriteLibrary."""

    def __init__(self, name: str, fw: int, fh: int, origin: tuple[int, int] | None = None,
                 emissive: str = ""):
        self.name = name
        # palette chars whose pixels also go to a companion "<name>_glow.png"
        # drawn above the darkness layer (glowing eyes, embers, flames)
        self.emissive = emissive
        self.fw = fw
        self.fh = fh
        self.origin = origin or (fw // 2, fh // 2)
        self.frames: list[Image.Image] = []
        self.anims: dict[str, dict] = {}

    def add(self, anim: str, frames: Sequence[Image.Image], fps: float = 8.0, loop: bool = True):
        idx = []
        for f in frames:
            if f.size != (self.fw, self.fh):
                f = pad(f, self.fw, self.fh)
            self.frames.append(f)
            idx.append(len(self.frames) - 1)
        self.anims[anim] = {"frames": idx, "fps": fps, "loop": loop}
        return self

    def build(self) -> tuple[Image.Image, dict]:
        cols = min(len(self.frames), max(1, 256 // self.fw))
        rows = (len(self.frames) + cols - 1) // cols
        sheet = blank(cols * self.fw, rows * self.fh)
        for i, f in enumerate(self.frames):
            sheet.alpha_composite(f, ((i % cols) * self.fw, (i // cols) * self.fh))
        meta = {
            "file": f"{self.name}.png",
            "glow": f"{self.name}_glow.png" if self.emissive else "",
            "frame_w": self.fw,
            "frame_h": self.fh,
            "columns": cols,
            "origin": list(self.origin),
            "anims": self.anims,
        }
        self.glow_image = None
        if self.emissive:
            colors = {PAL[c] for c in self.emissive}
            glow = blank(*sheet.size)
            src, dst = sheet.load(), glow.load()
            for y in range(sheet.height):
                for x in range(sheet.width):
                    if src[x, y] in colors:
                        dst[x, y] = src[x, y]
            self.glow_image = glow
        return sheet, meta
