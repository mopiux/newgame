#!/usr/bin/env python3
"""Builds every pixel-art asset of Lumbre into assets/gfx.

Deterministic: running it twice produces identical files. Run from anywhere:
    python3 tools/art/build_art.py

Outputs:
  assets/gfx/<sheet>.png (+ <sheet>_glow.png for emissive pixels)
  assets/gfx/<image>.png for single images (tilesets, props, UI)
  assets/gfx/sprites.json  animation metadata read by SpriteLibrary
  assets/gfx/tilesets.json biome rim colours read by RoomBuilder
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import sprites_bosses  # noqa: E402
import sprites_enemies  # noqa: E402
import sprites_fx  # noqa: E402
import sprites_player  # noqa: E402
import sprites_props  # noqa: E402
import sprites_relics  # noqa: E402
import sprites_world  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "gfx")


def collect():
    """Returns (sheets, images, extra_meta)."""
    sheets = [
        sprites_player.build_player(),
        sprites_player.build_lantern(),
        sprites_enemies.build_moth(),
        sprites_enemies.build_shade(),
        sprites_enemies.build_slug(),
        sprites_enemies.build_nest(),
        sprites_enemies.build_snuffer(),
        sprites_enemies.build_golem(),
        sprites_enemies.build_eye(),
        sprites_enemies.build_mimic(),
        sprites_enemies.build_wraith(),
        sprites_bosses.build_moth_mother(),
        sprites_bosses.build_great_snuffer(),
        sprites_bosses.build_penumbra(),
    ]
    sheets += sprites_props.build_props_sheets()
    sheets += sprites_fx.build_fx()
    images = {}
    images.update(sprites_fx.glow_textures())
    tiles, tile_meta = sprites_world.build_tilesets()
    images.update(tiles)
    prop_sheets, prop_images = sprites_world.build_props()
    sheets += prop_sheets
    images.update(prop_images)
    images.update(sprites_relics.build_relic_icons())
    images["pedestal"] = sprites_props.pedestal()
    images["altar"] = sprites_props.altar()
    images["hatch"] = sprites_props.hatch(False)
    images["hatch_final"] = sprites_props.hatch(True)
    images["well"] = sprites_props.well()
    images["notice_board"] = sprites_props.notice_board()
    images["icon"] = make_icon()
    return sheets, images, {"tilesets": tile_meta}


def make_icon():
    """64x64 application icon: the lantern on a night disc."""
    from PIL import Image
    from palette import PAL
    from pixel import grid
    icon = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    px = icon.load()
    for y in range(64):
        for x in range(64):
            d = ((x - 31.5) ** 2 + (y - 31.5) ** 2) ** 0.5
            if d < 31:
                px[x, y] = PAL["1"] if d > 29 else (PAL["2"] if d > 18 else PAL["3"])
    lantern = grid(sprites_player.LANTERN).resize((48, 48), Image.NEAREST)
    icon.alpha_composite(lantern, (8, 6))
    return icon


def main():
    os.makedirs(OUT, exist_ok=True)
    sheets, images, extra = collect()
    meta = {}
    for sb in sheets:
        img, m = sb.build()
        img.save(os.path.join(OUT, m["file"]))
        if sb.glow_image is not None:
            sb.glow_image.save(os.path.join(OUT, m["glow"]))
        if sb.name in meta:
            raise ValueError(f"duplicate sheet {sb.name}")
        meta[sb.name] = m
    for name, img in images.items():
        img.save(os.path.join(OUT, name + ".png"))
    with open(os.path.join(OUT, "sprites.json"), "w") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
    with open(os.path.join(OUT, "tilesets.json"), "w") as f:
        json.dump(extra["tilesets"], f, indent=1, sort_keys=True)
    print(f"built {len(meta)} sheets and {len(images)} images into {OUT}")


if __name__ == "__main__":
    main()
