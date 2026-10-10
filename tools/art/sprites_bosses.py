"""The three guardians. Drawn procedurally with shaded blobs."""
import math

from PIL import Image

from palette import PAL
from pixel import SheetBuilder, blank, paste, outline, recolor, shift, flip_h
from draw import Canvas


# --- La Madre Polilla (48x40) ------------------------------------------------
def _moth_half(c, wing_scale, glow):
    # upper wing
    c.blob(13, 15 - 6 * wing_scale, 12, 11 * wing_scale + 1, ["3", "4", "5", "6", "7"])
    # lower wing
    c.blob(16, 27, 8, 6 * max(0.6, wing_scale), ["3", "4", "5", "6"])
    # eyespot
    spot = ["o", "O", "Y"] if not glow else ["O", "Y", "l"]
    c.blob(11, 14 - 5 * wing_scale, 3.2, 3.2 * wing_scale + 0.4, spot, dither=False)
    c.set(11, int(14 - 5 * wing_scale), "0")
    # veins
    for i in range(4):
        x0, y0 = 22, 19
        ang = math.pi * (1.05 + i * 0.13)
        c.line(x0, y0, int(x0 + math.cos(ang) * 14), int(y0 + math.sin(ang) * 11 * wing_scale), "4")


def _moth_mother(wing_scale=1.0, glow=False):
    left = Canvas(24, 40)
    _moth_half(left, wing_scale, glow)
    img = blank(48, 40)
    img.alpha_composite(left.img, (0, 0))
    img.alpha_composite(flip_h(left.img), (24, 0))
    c = Canvas(48, 40)
    c.img = img
    c.px = img.load()
    # body
    c.blob(24, 24, 4.5, 11, ["1", "2", "3", "4"])
    for y in range(16, 34, 3):
        c.hline(21, 27, y, "2")
    # head and fluffy collar
    c.blob(24, 13, 5, 4, ["5", "6", "7", "8"])
    c.blob(24, 10, 3.5, 3, ["2", "3", "4"])
    c.set(22, 10, "Y")
    c.set(26, 10, "Y")
    c.set(22, 9, "l")
    c.set(26, 9, "l")
    # feathery antennae
    for side in (-1, 1):
        for i in range(7):
            x = 24 + side * (2 + i)
            y = 7 - i
            c.set(x, y, "N")
            if i % 2 == 0:
                c.set(x, y - 1, "x")
    return outline(c.img, PAL["0"])


def build_moth_mother():
    sb = SheetBuilder("moth_mother", 48, 40, origin=(24, 34), emissive="OYl")
    a = _moth_mother(1.0)
    b = _moth_mother(0.75)
    cc = _moth_mother(0.5)
    sb.add("fly", [a, b, cc, b], fps=9)
    sb.add("cast", [_moth_mother(1.0, True), _moth_mother(0.9, True)], fps=8)
    return sb


# --- El Gran Apagador (40x48) ---------------------------------------------------
def _snuffer_boss(bell_y=0, arms_up=False, squash=0, eyes="T"):
    c = Canvas(40, 48)
    # robe
    pts = [(12, 18 + squash), (28, 18 + squash), (34, 45), (6, 45)]
    c.shade_poly(pts, ["p", "P", "m"])
    for x in range(8, 33, 4):
        c.vline(x, 40, 45, "p")
    c.hline(6, 33, 45, "1")
    # arms
    if arms_up:
        c.rect(5, 6 + bell_y, 9, 22, "P")
        c.rect(31, 6 + bell_y, 35, 22, "p")
        c.rect(5, 4 + bell_y, 9, 7 + bell_y, "x")
        c.rect(31, 4 + bell_y, 35, 7 + bell_y, "x")
    else:
        c.rect(6, 20 + squash, 10, 34, "P")
        c.rect(30, 20 + squash, 34, 34, "p")
        c.rect(6, 33, 10, 36, "x")
        c.rect(30, 33, 34, 36, "x")
    # face in shadow
    c.blob(20, 18 + squash, 6, 4, ["0", "1"], dither=False)
    c.set(17, 18 + squash, eyes)
    c.set(23, 18 + squash, eyes)
    # bell / snuffer cone on the head
    by = 2 + bell_y + squash
    cone = [(20, by), (31, by + 15), (9, by + 15)]
    c.shade_poly(cone, ["k", "K", "h", "H"])
    c.hline(8, 32, by + 15, "k")
    c.hline(8, 32, by + 16, "K")
    c.set(20, by - 1, "h")
    c.set(20, by - 2, "H")
    return c.outlined()


def build_great_snuffer():
    sb = SheetBuilder("great_snuffer", 40, 48, origin=(20, 45), emissive="TM")
    sb.add("walk", [_snuffer_boss(0), shift(_snuffer_boss(0), 0, 1)], fps=3)
    sb.add("raise", [_snuffer_boss(-4, arms_up=True)], fps=1)
    sb.add("slam", [_snuffer_boss(3, squash=3)], fps=1)
    sb.add("cast", [_snuffer_boss(0, eyes="M"), shift(_snuffer_boss(0, eyes="M"), 0, -1)], fps=6)
    return sb


# --- La Penumbra (56x56) ----------------------------------------------------------
def _penumbra(t, cast=False):
    c = Canvas(56, 56)
    # tendrils
    for i in range(9):
        ang = i / 9.0 * math.tau + t * 0.35
        length = 16 + 5 * math.sin(t * 1.3 + i * 1.7)
        x0, y0 = 28, 30
        for s in range(int(length)):
            k = s / length
            x = x0 + math.cos(ang + math.sin(t + s * 0.25) * 0.4) * (14 + s)
            y = y0 + math.sin(ang + math.sin(t + s * 0.25) * 0.4) * (12 + s) * 0.8
            w = max(0.6, 2.4 * (1 - k))
            c.blob(x, y, w, w, ["0", "1", "p"], dither=False)
    # main mass
    c.blob(28, 30, 17, 15, ["0", "1", "2", "p", "P"])
    c.blob(28, 22, 11, 9, ["1", "2", "p", "P"])
    # cold heart
    heart = ["c", "C", "t", "T", "w"] if not cast else ["C", "t", "T", "w", "w"]
    c.blob(28, 31, 6 + (1 if cast else 0), 6 + (1 if cast else 0), heart, dither=False)
    # eyes
    eye = "M" if cast else "T"
    for (x, y) in ((20, 19), (36, 19), (24, 15), (32, 15), (15, 27), (41, 27)):
        c.set(x, y, eye)
        c.set(x + 1, y, eye)
    return c.outlined("0")


def build_penumbra():
    sb = SheetBuilder("penumbra", 56, 56, origin=(28, 48), emissive="cCtTwM")
    sb.add("idle", [_penumbra(t) for t in (0.0, 1.5, 3.0, 4.5)], fps=5)
    sb.add("cast", [_penumbra(0.7, True), _penumbra(2.2, True)], fps=8)
    return sb
