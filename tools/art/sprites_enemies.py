"""Creatures of the Penumbra. Every enemy has a readable silhouette and
emissive eyes so it can be spotted in the dark before it is seen."""
import math
import random

from PIL import Image

from palette import PAL
from pixel import SheetBuilder, grid, blank, paste, flip_h, recolor, shift


def mirror(half_rows):
    return [r + r[::-1] for r in half_rows]


def squash_wings(img, factor, root_y, body_cols=(6, 10)):
    """Flap animation helper: vertically scales everything outside body_cols."""
    w, h = img.size
    out = blank(w, h)
    left = img.crop((0, 0, body_cols[0], h))
    right = img.crop((body_cols[1], 0, w, h))
    body = img.crop((body_cols[0], 0, body_cols[1], h))
    nh = max(1, int(round(h * factor)))
    for part, x in ((left, 0), (right, body_cols[1])):
        scaled = part.resize((part.width, nh), Image.NEAREST)
        y = int(round(root_y - root_y * factor))
        out.alpha_composite(scaled, (x, max(0, y)))
    out.alpha_composite(body, (body_cols[0], 0))
    return out


# --- Ash moth --------------------------------------------------------------
MOTH_HALF = [
    "........",
    ".000..0.",
    "05660..0",
    "056O6003",
    "0566603Y",
    "05666037",
    ".0556033",
    "..000037",
    "..056033",
    ".05O6037",
    ".0566037",
    "..055033",
    "...00003",
    ".......0",
    "........",
    "........",
]


def _moth_frame(wing):
    """Ash moth drawn with shaded blobs: rounded forewings with ember
    eyespots, smaller hindwings, a fuzzy body and glowing eyes."""
    from draw import Canvas
    c = Canvas(16, 16)
    lift = 1.0 - wing  # 0 = wings spread, 1 = folded
    for side in (-1, 1):
        cx = 8 + side * (4.2 - lift * 1.5)
        c.blob(cx, 6.0 + lift * 1.5, 3.6 - lift * 0.8, 3.4 * (0.45 + 0.55 * wing), ["3", "4", "5", "6"])
        c.blob(8 + side * 2.6, 10.5, 2.2, 2.0 * (0.5 + 0.5 * wing), ["3", "4", "5"])
        c.set(int(round(cx)), int(round(6.0 + lift * 1.5)), "O")
    c.blob(8, 8.5, 1.4, 4.2, ["2", "3", "4"], dither=False)
    c.set(7, 5, "Y")
    c.set(8, 5, "Y")
    c.set(6, 3, "N")
    c.set(9, 3, "N")
    c.set(5, 2, "N")
    c.set(10, 2, "N")
    return c.outlined()


def build_moth():
    sb = SheetBuilder("moth", 16, 16, origin=(8, 9), emissive="YO")
    a = _moth_frame(1.0)
    b = _moth_frame(0.65)
    cc = _moth_frame(0.3)
    sb.add("fly", [a, b, cc, b], fps=14)
    return sb


# --- Shade -----------------------------------------------------------------
SHADE_HALF = [
    "........",
    "........",
    ".....000",
    "....0122",
    "...01222",
    "...0122P",
    "..0122TP",
    "..0122P2",
    "..01222P",
    ".01222P2",
    ".0122222",
    ".012P222",
]


def build_shade():
    sb = SheetBuilder("shade", 16, 16, origin=(8, 12), emissive="T")
    frames = []
    for f in range(4):
        rows = mirror(SHADE_HALF)
        img = blank(16, 16)
        paste(img, grid(rows), 0, 0)
        px = img.load()
        # wavering tendrils for the bottom 4 rows
        for y in range(12, 16):
            for x in range(1, 15):
                phase = math.sin((x * 1.3) + f * 1.6 + y * 0.7)
                width_ok = abs(x - 7.5) < 7 - (y - 12) * 1.2
                if width_ok and phase > -0.2 + (y - 12) * 0.35:
                    px[x, y] = PAL["2" if phase > 0.5 else "1"]
        # outline bottom
        frames.append(img)
    sb.add("float", frames, fps=7)
    lunge = [shift(frames[0], 0, -1), frames[1]]
    sb.add("lunge", lunge, fps=10)
    return sb


# --- Wax slug --------------------------------------------------------------
SLUG = [
    "................",
    "................",
    "................",
    "................",
    "...........0...0",
    "..........0Y0.0Y",
    "...........0x00x",
    "......0000000xx0",
    "....00XXXX8XXXX0",
    "...0XX8XXXXXXxx0",
    "..0X8XXXXXXxxxN0",
    ".0XXXXXxxxxxxNN0",
    "0NxxxxxxxxxNNNN0",
    "0NNNNNNNNNNNNNb0",
    ".0bbbbbbbbbbbb0.",
    "..000000000000..",
]


def build_slug():
    sb = SheetBuilder("slug", 16, 16, origin=(8, 13), emissive="Y")
    base = grid(SLUG)
    frames = [base]
    # stretch / contract crawl
    f2 = blank(16, 16)
    stretched = base.crop((0, 8, 16, 16)).resize((16, 7), Image.NEAREST)
    paste(f2, base.crop((0, 0, 16, 8)), 0, 1)
    paste(f2, stretched, 0, 9)
    frames.append(f2)
    f3 = blank(16, 16)
    squashed = base.crop((0, 8, 16, 16)).resize((16, 9), Image.NEAREST)
    paste(f3, base.crop((0, 0, 16, 8)), 0, -1 + 0)
    paste(f3, squashed, 0, 7)
    frames.append(f3)
    sb.add("crawl", [frames[0], frames[1], frames[0], frames[2]], fps=6)
    small = []
    for fr in (frames[0], frames[1], frames[0], frames[2]):
        s = fr.resize((10, 10), Image.NEAREST)
        img = blank(16, 16)
        paste(img, s, 3, 6)
        small.append(img)
    sb.add("crawl_small", small, fps=8)
    return sb


# --- Moth nest -------------------------------------------------------------
NEST = [
    "................",
    "......0000......",
    "....00nBBn00....",
    "...0nBBnnBBn0...",
    "..0nBbOObBBnB0..",
    "..0BbOyYObBBn0..",
    ".0nBbOYyObBnBB0.",
    ".0BnBbOObBnBbB0.",
    ".0BBnBBBnBBbOb0.",
    ".0nBbBnBBnbOYO0.",
    ".0BbOObBBnbOOb0.",
    "..0bOYObBnBbbB0.",
    "..0BbOObBnBnB0..",
    "...00bbBBBbb00..",
    ".....000000.....",
    "................",
]


def build_nest():
    sb = SheetBuilder("nest", 16, 16, origin=(8, 12), emissive="OYy")
    a = grid(NEST)
    b = recolor(a, {"O": "y", "Y": "l", "y": "Y"})
    c = recolor(a, {"O": "o", "Y": "O", "y": "O"})
    sb.add("pulse", [a, b, a, c], fps=4)
    return sb


# --- Snuffer -----------------------------------------------------------------
SNUFFER = [
    "...........00...",
    "..........0hh0..",
    ".........0hKKh0.",
    "........0kKKKKk0",
    ".........0kkkk0.",
    "....000....0k0..",
    "...0pPP0...0k0..",
    "..0pPPPP0..0k0..",
    "..0P1T1T0..0k0..",
    "..0P1111P0.0k0..",
    "..0pPPPPP00K0...",
    ".0pPPmPPPP0k0...",
    ".0pPPPPPPP0k0...",
    ".0pPPPPPPPp0k0..",
    "0pPPPPPPPPPp0k0.",
    "0pPPPPPPPPPp0k0.",
    "0ppPPPPPPPpp0k0.",
    ".0ppppppppp0.00.",
    "..0p00p00p0.....",
    "...0..0..0......",
]


def build_snuffer():
    sb = SheetBuilder("snuffer", 16, 20, origin=(7, 18), emissive="TM")
    a = grid(SNUFFER)
    b = shift(a, 0, 1)
    sb.add("idle", [a, b], fps=3)
    atk = recolor(a, {"T": "M", "k": "m", "K": "M", "h": "m", "H": "M"})
    atk2 = recolor(shift(a, 0, -1), {"T": "M", "k": "m", "K": "M"})
    sb.add("attack", [atk, atk2], fps=8)
    return sb


# --- Wax golem ----------------------------------------------------------------
def _golem_frame(bob=0, arms_up=False, lean=0, dazed=False, legs=0):
    """Hulking candle golem: stout wax torso, a candle-stub head with a dead
    wick, long dripping arms and glowing ember eyes."""
    from draw import Canvas
    c = Canvas(24, 26)
    ramp = ["N", "x", "X", "8"]
    by = 15 + bob
    # legs (stubby wax columns)
    for i, lx in enumerate((7, 14)):
        ly = 24 + (legs if i == 0 else -legs)
        c.rect(lx, by + 3, lx + 4, min(26, ly), "N")
        c.rect(lx, by + 3, lx + 2, min(26, ly), "x")
    # torso: wide trapezoid shaded left->right
    torso = [(4 + lean, by - 6), (20 + lean, by - 6), (18 + lean, by + 5), (6 + lean, by + 5)]
    c.shade_poly(torso, ["N", "x", "X"])
    # wax drips over the belly
    for x, h in ((7, 3), (11, 5), (15, 2), (18, 4)):
        c.vline(x + lean, by + 4, by + 4 + h, "x")
        c.set(x + lean, by + 5 + h, "N")
    # head: candle stub with melted rim
    hx = 12 + lean * 2
    c.rect(hx - 4, by - 13, hx + 4, by - 6, "x")
    c.rect(hx - 4, by - 13, hx - 2, by - 6, "X")
    c.hline(hx - 5, hx + 4, by - 13, "8")
    c.set(hx - 5, by - 12, "X")
    c.set(hx + 4, by - 11, "N")
    c.vline(hx, by - 16, by - 14, "0")
    c.set(hx + 1, by - 16, "2")
    eye = "Y" if dazed else "O"
    c.set(hx - 2, by - 10, eye)
    c.set(hx + 2, by - 10, eye)
    c.set(hx - 2, by - 9, "o")
    c.set(hx + 2, by - 9, "o")
    # arms
    if arms_up:
        c.rect(1 + lean, by - 14, 4 + lean, by - 3, "X")
        c.rect(20 + lean, by - 14, 23 + lean, by - 3, "N")
    else:
        c.rect(1 + lean, by - 5, 4 + lean, by + 6, "X")
        c.rect(20 + lean, by - 5, 23 + lean, by + 6, "N")
        c.set(2 + lean, by + 7, "x")
        c.set(21 + lean, by + 7, "N")
    if dazed:
        for (sx, sy) in ((4, 1), (12, 0), (19, 2)):
            c.set(sx, sy, "Y")
            c.set(sx + 1, sy + 1, "l")
    return c.outlined()


def build_golem():
    sb = SheetBuilder("golem", 24, 26, origin=(12, 24), emissive="OY")
    sb.add("walk", [_golem_frame(0, legs=1), _golem_frame(1), _golem_frame(0, legs=-1), _golem_frame(1)], fps=5)
    sb.add("windup", [_golem_frame(-1, arms_up=True), _golem_frame(0, arms_up=True)], fps=8)
    sb.add("charge", [_golem_frame(1, lean=1, legs=1), _golem_frame(1, lean=1, legs=-1)], fps=12)
    sb.add("dazed", [_golem_frame(2, dazed=True), _golem_frame(1, dazed=True)], fps=4)
    return sb


# --- Gloom eye -----------------------------------------------------------------
def _eye_frame(state, t=0):
    from draw import Canvas
    c = Canvas(18, 18)
    c.blob(9, 9, 8, 7.5, ["p", "P", "m"])
    if state == "closed":
        c.blob(9, 9, 5.5, 3.5, ["P", "m", "M"], dither=False)
        c.hline(4, 13, 9, "p")
    else:
        c.blob(9, 9, 5.5, 4.5, ["7", "X", "8"], dither=False)
        iris = ["c", "C", "t"] if state == "open" else ["m", "M", "w"]
        c.blob(9 + t, 9, 3, 3, iris, dither=False)
        c.set(9 + t, 9, "0")
        c.set(10 + t, 9, "0")
        c.set(8 + t, 8, "w")
    # little tendrils
    for (x, y) in ((1, 14), (16, 14), (3, 16), (14, 16)):
        c.set(x, y, "p")
    return c.outlined()


def build_eye():
    sb = SheetBuilder("eye", 18, 18, origin=(9, 15), emissive="tCMw")
    sb.add("open", [_eye_frame("open", 0), _eye_frame("open", -1), _eye_frame("open", 0), _eye_frame("open", 1)], fps=3)
    sb.add("charge", [_eye_frame("charge", 0), _eye_frame("charge", 1)], fps=12)
    sb.add("closed", [_eye_frame("closed")], fps=1)
    return sb


# --- Mimic (false lantern) ------------------------------------------------------
MIMIC_TOP_OPEN = [
    "..000000000000..",
    ".0XmXmXmXmXmX0..",
    "0m0000000000m0..",
    "0mmMMmmmmMMmm0..",
    ".0X0X0X0X0X0X0..",
]


def build_mimic():
    from sprites_world import BRAZIER_BASE
    sb = SheetBuilder("mimic", 16, 20, origin=(8, 16), emissive="OM")
    dormant = grid(BRAZIER_BASE)
    paste(dormant, grid(["...0021232120...", "....00000000...."]), 0, 6)
    # two barely visible eyes on the bowl
    px = dormant.load()
    px[6, 9] = PAL["r"]
    px[9, 9] = PAL["r"]
    sb.add("dormant", [dormant], fps=1)
    frames = []
    for i in range(4):
        img = grid(BRAZIER_BASE)
        p2 = img.load()
        p2[6, 9] = PAL["O"]
        p2[9, 9] = PAL["O"]
        mouth = grid(MIMIC_TOP_OPEN)
        paste(img, mouth, 0, 2 + (i % 2))
        # scuttling legs
        if i % 2:
            img = shift(img, 1 if i == 1 else -1, 0)
        frames.append(img)
    sb.add("awake", frames, fps=10)
    return sb


# --- Ash wraith -----------------------------------------------------------------
def _wraith_frame(t):
    from draw import Canvas
    c = Canvas(18, 22)
    c.blob(9, 6, 5, 5, ["3", "4", "5", "6"])
    # hood shadow and eyes
    c.blob(9, 7, 3, 2.5, ["0", "1"], dither=False)
    c.set(8, 7, "Y")
    c.set(10, 7, "Y")
    # tattered robe
    pts = [(4, 9), (14, 9), (16, 18), (12, 16), (9, 21), (6, 16), (2, 18)]
    c.shade_poly([(x + (1 if (i % 2 and t % 2) else 0), y) for i, (x, y) in enumerate(pts)], ["2", "3", "4", "5"])
    # ember core
    c.set(9, 12, "O")
    c.set(9, 13, "Y")
    c.set(8, 13, "O")
    c.set(10, 13, "o")
    return c.outlined()


def build_wraith():
    sb = SheetBuilder("wraith", 18, 22, origin=(9, 20), emissive="YO")
    sb.add("float", [_wraith_frame(0), shift(_wraith_frame(1), 0, -1), _wraith_frame(0), shift(_wraith_frame(1), 0, 1)], fps=5)
    return sb
