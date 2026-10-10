"""Interactive props, NPCs and plaza furniture."""
from palette import PAL
from pixel import SheetBuilder, grid, blank, paste, outline, recolor, flip_h
from draw import Canvas


def mirror(half_rows):
    return [r + r[::-1] for r in half_rows]


PEDESTAL = [
    "................",
    "................",
    "...0000000000...",
    "..0hHHHHHHHHh0..",
    "..0KhhhhhhhhK0..",
    "...0kkkkkkkk0...",
    "....05666650....",
    "....04555540....",
    "....04555540....",
    "....04565540....",
    "....04555540....",
    "....03444430....",
    "...0566666650...",
    "..034444444430..",
    "..022222222220..",
    "...0000000000...",
]


def pedestal():
    return grid(PEDESTAL)


def altar():
    c = Canvas(24, 24)
    # stone block
    c.rect(3, 12, 21, 22, "3")
    c.rect(3, 12, 21, 14, "5")
    c.rect(3, 14, 21, 15, "4")
    c.rect(3, 21, 21, 22, "2")
    c.rect(19, 14, 21, 21, "2")
    # rune
    for (x, y) in ((11, 16), (12, 16), (10, 17), (13, 17), (11, 18), (12, 18), (11, 19), (12, 19)):
        c.set(x, y, "m")
    c.set(11, 17, "M")
    c.set(12, 17, "M")
    # candles with violet flames
    for cx in (6, 17):
        c.rect(cx, 7, cx + 2, 12, "x")
        c.set(cx, 7, "X")
        c.set(cx + 1, 11, "N")
        c.set(cx, 6, "0")
        c.set(cx, 4, "m")
        c.set(cx + 1, 5, "M")
        c.set(cx, 5, "M")
        c.set(cx, 3, "P")
    return c.outlined()


def hatch(final=False):
    c = Canvas(32, 32)
    ring = ["k", "K", "h", "H"] if final else ["2", "3", "4", "5"]
    c.blob(16, 16, 14, 11, ring, dither=False)
    glow = ["y", "Y", "l", "w"] if final else ["c", "C", "t", "T"]
    c.blob(16, 16, 10.5, 7.5, ["0", "1"], dither=False)
    c.blob(16, 18, 7, 4.5, glow, dither=True)
    # ladder rungs
    for y in (11, 14, 17, 20):
        c.hline(13, 19, y, "B")
    c.vline(12, 10, 21, "b")
    c.vline(20, 10, 21, "b")
    return c.outlined()


def well():
    c = Canvas(32, 28)
    # front wall of the well
    c.rect(4, 14, 28, 25, "4")
    for y in range(14, 25):
        off = 3 if (y // 3) % 2 else 0
        for x in range(4, 28):
            if (y % 3 == 0) or ((x + off) % 6 == 0):
                c.set(x, y, "2")
            elif y % 3 == 1:
                c.set(x, y, "5")
    c.rect(4, 24, 28, 25, "2")
    # rim (top ellipse) and dark water
    c.blob(16, 14, 13, 5, ["3", "4", "5", "6"], dither=False)
    c.blob(16, 14, 10, 3.2, ["0", "1", "c"], dither=False)
    c.set(14, 14, "T")
    c.set(18, 13, "t")
    # posts and beam
    c.rect(5, 2, 7, 14, "B")
    c.vline(5, 2, 13, "n")
    c.rect(25, 2, 27, 14, "B")
    c.vline(25, 2, 13, "n")
    c.rect(4, 2, 28, 4, "n")
    c.hline(4, 27, 2, "N")
    # rope and bucket
    c.vline(16, 4, 9, "x")
    c.rect(14, 9, 19, 12, "B")
    c.hline(14, 18, 9, "N")
    return c.outlined()


def notice_board():
    c = Canvas(24, 28)
    c.rect(3, 6, 5, 27, "b")
    c.rect(19, 6, 21, 27, "b")
    c.rect(1, 4, 23, 20, "B")
    c.rect(2, 5, 22, 19, "n")
    c.hline(1, 22, 4, "N")
    # papers
    for (x, y, w, h) in ((4, 7, 6, 7), (12, 6, 7, 5), (11, 12, 5, 6), (17, 12, 4, 5)):
        c.rect(x, y, x + w, y + h, "X")
        c.hline(x, x + w - 1, y + h - 1, "x")
        for ly in range(y + 1, y + h - 1, 2):
            c.hline(x + 1, x + w - 2, ly, "5")
        c.set(x + w // 2, y, "o")
    # little roof
    c.poly([(0, 4), (12, 0), (24, 4)], "R")
    c.hline(0, 23, 4, "o")
    return c.outlined()


LAMP_HEAD_UNLIT = [
    "....0000....",
    "...0hHHh0...",
    "..0kkkkkk0..",
    "..0k1221k0..",
    "..0k2332k0..",
    "..0k2332k0..",
    "..0k1221k0..",
    "..0kkkkkk0..",
    "...0hhhh0...",
    "....0kk0....",
]
LAMP_HEAD_LIT = [
    "....0000....",
    "...0hHHh0...",
    "..0kkkkkk0..",
    "..0kYllYk0..",
    "..0klwwlk0..",
    "..0kYwwYk0..",
    "..0kyYYyk0..",
    "..0kkkkkk0..",
    "...0hhhh0...",
    "....0kk0....",
]
LAMP_HEAD_LIT2 = [
    "....0000....",
    "...0hHHh0...",
    "..0kkkkkk0..",
    "..0kyYYyk0..",
    "..0kYwlYk0..",
    "..0klwwlk0..",
    "..0kyYlyk0..",
    "..0kkkkkk0..",
    "...0hhhh0...",
    "....0kk0....",
]


def _lamp(head_rows):
    img = blank(16, 34)
    paste(img, grid(head_rows), 2, 0)
    c = Canvas(16, 34)
    c.img = img
    c.px = img.load()
    c.rect(7, 10, 9, 31, "2")
    c.vline(7, 10, 30, "3")
    c.rect(5, 30, 11, 33, "2")
    c.hline(5, 10, 30, "4")
    c.hline(6, 9, 18, "4")
    return outline(c.img, PAL["0"])


def build_props_sheets():
    sheets = []
    sb = SheetBuilder("lamp_post", 16, 34, origin=(8, 31), emissive="Yylw")
    sb.add("unlit", [_lamp(LAMP_HEAD_UNLIT)], fps=1)
    sb.add("lit", [_lamp(LAMP_HEAD_LIT), _lamp(LAMP_HEAD_LIT2)], fps=4)
    sheets.append(sb)

    sb = SheetBuilder("lighthouse", 32, 60, origin=(16, 56), emissive="Yylw")
    sb.add("unlit", [_lighthouse(False)], fps=1)
    sb.add("lit", [_lighthouse(True, 0), _lighthouse(True, 1)], fps=3)
    sheets.append(sb)

    sb = SheetBuilder("cerero", 24, 26, origin=(12, 24), emissive="Yylw")
    sb.add("idle", [_cerero(0), _cerero(1)], fps=2)
    sheets.append(sb)
    return sheets


def _lighthouse(lit, frame=0):
    c = Canvas(32, 60)
    # tapered tower with red/white bands
    for y in range(20, 57):
        t = (y - 20) / 37.0
        half = int(6 + t * 5)
        for x in range(16 - half, 16 + half):
            band = ((y - 20) // 6) % 2 == 0
            col = "X" if band else "o"
            if x < 16 - half + 2:
                col = "8" if band else "O"
            elif x >= 16 + half - 3:
                col = "x" if band else "R"
            c.set(x, y, col)
    c.rect(4, 55, 28, 58, "3")
    c.hline(4, 27, 55, "5")
    # gallery
    c.rect(7, 18, 25, 21, "2")
    c.hline(7, 24, 18, "4")
    # lantern room
    c.rect(10, 8, 22, 18, "k")
    if lit:
        c.rect(11, 9, 21, 17, "Y")
        c.rect(12 + frame, 10, 19 + frame, 16, "l")
        c.rect(14 + frame, 11, 17 + frame, 15, "w")
    else:
        c.rect(11, 9, 21, 17, "2")
        c.rect(12, 10, 15, 16, "3")
    for x in (13, 16, 19):
        c.vline(x, 9, 16, "k")
    # roof
    c.poly([(8, 8), (16, 1), (24, 8)], "R")
    c.hline(8, 23, 8, "o")
    c.set(16, 0, "h")
    # door and window
    c.rect(14, 47, 18, 55, "b")
    c.rect(15, 32, 17, 35, "Y" if lit else "1")
    return c.outlined()


CERERO_A = [
    "..........0.............",
    ".........0Y0............",
    ".........0l0............",
    ".........0x0............",
    "........0xXx0...........",
    "......00NNNNN00.........",
    ".....0NxxxxxxxN0........",
    ".....0x0xxxx0xN0........",
    ".....0xxxNNxxxN0........",
    ".....0NxxRRxxN0.........",
    "......0NNxxNN0..........",
    "....00XXXXXXXX00........",
    "...0XXXnnnnnnXXX0..0....",
    "..0XXXnnnnnnnnXXX00Y0...",
    "..0XX0nnNNNNnn0XX0xl0...",
    "..0xX0nnnnnnnn0Xx0xx0...",
    "..0xx0nnnnnnnn0xxxxx0...",
    "...00nnnnNNnnnn0000x0...",
    ".....0nnnnnnnnn0..0x0...",
    ".....0nnnnnnnnn0..000...",
    ".....0BnnnnnnnB0........",
    "......0BBBBBBB0.........",
    "......0b0...0b0.........",
    "......0b0...0b0.........",
    ".....0bb0...0bb0........",
    ".....0000...0000........",
]


def _cerero(frame):
    img = grid(CERERO_A)
    if frame == 1:
        img = recolor(img, {"Y": "y", "l": "Y"})
    return img


WINDOW_DARK = [
    "................",
    "..000000000000..",
    "..0bBBBBBBBBb0..",
    "..0B12210122B0..",
    "..0B21120211B0..",
    "..0B12210122B0..",
    "..0bBBBBBBBBb0..",
    "..0B12210122B0..",
    "..0B21120211B0..",
    "..0B11110111B0..",
    "..0bBBBBBBBBb0..",
    ".0nNNNNNNNNNNn0.",
    ".00000000000000.",
    "................",
    "................",
    "................",
]


def window(lit):
    img = grid(WINDOW_DARK)
    if lit:
        img = recolor(img, {"1": "y", "2": "Y"})
    return img


BENCH = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    ".00000000000000.",
    "0NNNNNNNNNNNNNN0",
    "0nnnnnnnnnnnnnn0",
    "00000000000000000"[:16],
    "0NNNNNNNNNNNNNN0",
    "0BBBBBBBBBBBBBB0",
    ".0b0........0b0.",
    ".0b0........0b0.",
    ".000........000.",
]

PLANTER = [
    "................",
    "....M.....m.....",
    "...MmM...mMm.M..",
    "..e.M.e.e.m.MmM.",
    ".eEe.eEe.EeE.M..",
    "..eEeEeEeEeEe...",
    ".eEeEeEeEeEeEe..",
    ".00000000000000.",
    ".0NNNNNNNNNNNN0.",
    ".0nNnnnnnnnnnn0.",
    ".0nnnnnnnnnNnn0.",
    ".0BBBBBBBBBBBB0.",
    ".00000000000000.",
    "................",
    "................",
    "................",
]


def statue():
    c = Canvas(20, 36)
    # plinth
    c.rect(2, 26, 18, 35, "4")
    c.hline(2, 17, 26, "6")
    c.rect(2, 33, 18, 35, "3")
    c.rect(4, 28, 16, 31, "5")
    # cloaked figure in stone
    c.blob(10, 17, 5, 9, ["4", "5", "6", "7"])
    c.blob(10, 6, 3.5, 3.5, ["4", "5", "6", "7"])
    c.blob(10, 7, 2, 1.6, ["2", "3"], dither=False)
    # raised arm with a real burning lantern
    c.rect(14, 4, 16, 14, "5")
    c.rect(14, 0, 17, 4, "k")
    c.set(15, 1, "Y")
    c.set(15, 2, "l")
    c.set(16, 2, "Y")
    return c.outlined()


def build_plaza_props():
    out = {
        "window_dark": window(False),
        "window_lit": window(True),
        "bench": grid(BENCH),
        "planter": grid(PLANTER),
        "statue": statue(),
    }
    return out


def reliquary(opened):
    c = Canvas(24, 22)
    # stone plinth
    c.rect(2, 16, 22, 21, "4")
    c.hline(2, 21, 16, "6")
    c.rect(2, 20, 22, 21, "3")
    # brass-bound casket
    c.rect(4, 8, 20, 16, "B")
    c.rect(4, 8, 20, 10, "n")
    for x in (4, 11, 12, 19):
        c.vline(x, 8, 15, "k")
    c.hline(4, 19, 12, "h")
    if opened:
        c.rect(5, 3, 19, 8, "b")
        c.hline(5, 18, 3, "n")
        c.rect(7, 8, 17, 10, "Y")
        c.hline(8, 16, 8, "l")
    else:
        c.rect(4, 5, 20, 8, "n")
        c.hline(4, 19, 5, "N")
        c.rect(10, 10, 14, 14, "h")
        c.set(11, 11, "0")
        c.set(12, 12, "0")
    return c.outlined()
