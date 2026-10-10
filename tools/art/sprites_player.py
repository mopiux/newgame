"""The lamplighter (player) and the lantern."""
from pixel import SheetBuilder, grid, blank, paste, flip_h, recolor

# --- Body (rows 0-15) ------------------------------------------------------
FRONT = [
    "................",
    "......0000......",
    ".....045540.....",
    "....04555540....",
    "...0455555540...",
    "...0566666650...",
    "...0563333650...",
    "...056Y11Y650...",
    "...0563113650...",
    "...0oOOOOOOo0...",
    "..04oOyOOOOo40..",
    "..045oOOOOo540..",
    "..0455oOo55540..",
    "..0455Oo555540..",
    "..034555555430..",
    "...0334444330...",
]

BACK = [
    "................",
    "......0000......",
    ".....045540.....",
    "....04555540....",
    "...0455555540...",
    "...0455665540...",
    "...0455555540...",
    "...0445555440...",
    "...0344554430...",
    "...0oOOOOOOo0...",
    "..04oOOyOOOo40..",
    "..0455oOo55540..",
    "..04555O555540..",
    "..04555o555540..",
    "..034555555430..",
    "...0334444330...",
]

SIDE = [
    "................",
    "......00000.....",
    ".....0455550....",
    "....045555550...",
    "...04555556650..",
    "..045555563330..",
    "..0455555631Y0..",
    "..045555556310..",
    "...0455555660...",
    "..0oOOOOOOOo0...",
    ".0oOo45555O540..",
    "..0o0455555540..",
    "....0455555540..",
    "....0455555540..",
    "....0345555430..",
    "....0334444330..",
]

# --- Legs (rows 16-19) -----------------------------------------------------
LEGS_FRONT_IDLE = [
    "....0BB00BB0....",
    "....0bB00Bb0....",
    "....0bb00bb0....",
    "....00000000....",
]
LEGS_FRONT_A = [
    "....0BB00BB0....",
    "....0bb00Bb0....",
    "....00000bb0....",
    "........0000....",
]
LEGS_FRONT_B = [
    "....0BB00BB0....",
    "....0bB00bb0....",
    "....0bb00000....",
    "....0000........",
]
LEGS_SIDE_IDLE = [
    ".....0BB0BB0....",
    ".....0bB0Bb0....",
    ".....0bb0bb00...",
    ".....00000000...",
]
LEGS_SIDE_A = [
    "....0BB00BB0....",
    "...0bB0..0Bb0...",
    "..0bb0....0bb0..",
    "..000.....0000..",
]
LEGS_SIDE_B = [
    ".....0BBBB0.....",
    ".....0bBBb0.....",
    "....0bb00bb0....",
    "....000..0000...",
]


def _compose(body_rows, leg_rows, bob: int = 0, squash: bool = False):
    img = blank(16, 20)
    legs = grid(leg_rows)
    paste(img, legs, 0, 16)
    body = grid(body_rows)
    paste(img, body, 0, bob)
    return img


def _hurt(img):
    return recolor(img, {"3": "8", "4": "8", "5": "8", "2": "7", "o": "8", "O": "8", "y": "8"})


def build_player() -> SheetBuilder:
    sb = SheetBuilder("player", 16, 20, origin=(8, 17))
    for name, body, idle, a, b in (
        ("down", FRONT, LEGS_FRONT_IDLE, LEGS_FRONT_A, LEGS_FRONT_B),
        ("up", BACK, LEGS_FRONT_IDLE, LEGS_FRONT_A, LEGS_FRONT_B),
        ("side", SIDE, LEGS_SIDE_IDLE, LEGS_SIDE_A, LEGS_SIDE_B),
    ):
        sb.add(f"idle_{name}", [_compose(body, idle, 0), _compose(body, idle, 1)], fps=2.5)
        sb.add(f"run_{name}", [
            _compose(body, a, 0),
            _compose(body, idle, 1),
            _compose(body, b, 0),
            _compose(body, idle, 1),
        ], fps=10)
        sb.add(f"hurt_{name}", [_hurt(_compose(body, idle, 0))], fps=1, loop=False)
    # dash: crouched forward silhouette, reuse side frame shifted
    sb.add("dash_side", [_compose(SIDE, LEGS_SIDE_A, 2)], fps=1, loop=False)
    sb.add("dash_down", [_compose(FRONT, LEGS_FRONT_IDLE, 2)], fps=1, loop=False)
    sb.add("dash_up", [_compose(BACK, LEGS_FRONT_IDLE, 2)], fps=1, loop=False)
    # extinguished: collapse frames
    dead = []
    for i in range(4):
        img = blank(16, 20)
        body = grid(FRONT)
        cut = 16 - i * 3
        part = body.crop((0, 0, 16, cut))
        paste(img, part, 0, 20 - cut)
        dead.append(img)
    ash = grid([
        "................",
        "................",
        "....00000000....",
        "...0334444330...",
        "..023333333320..",
        "...0000000000...",
    ])
    final = blank(16, 20)
    paste(final, ash, 0, 14)
    dead.append(final)
    sb.add("dead", dead, fps=8, loop=False)
    return sb


LANTERN = [
    "...00...",
    "..0kk0..",
    ".0hHHh0.",
    "0kYlwYk0",
    "0kylwyk0",
    "0kyYYyk0",
    ".0Khhk0.",
    "..0000..",
]
LANTERN_B = [
    "...00...",
    "..0kk0..",
    ".0hHHh0.",
    "0kyYlyk0",
    "0kYwlYk0",
    "0kyYYyk0",
    ".0Khhk0.",
    "..0000..",
]
LANTERN_LOW = [
    "...00...",
    "..0kk0..",
    ".0hHHh0.",
    "0k1221k0",
    "0k2oO2k0",
    "0k2yo2k0",
    ".0Khhk0.",
    "..0000..",
]


def build_lantern() -> SheetBuilder:
    sb = SheetBuilder("lantern", 8, 8, origin=(4, 1))
    sb.add("burn", [grid(LANTERN), grid(LANTERN_B)], fps=6)
    sb.add("low", [grid(LANTERN_LOW), grid(LANTERN)], fps=3)
    return sb
