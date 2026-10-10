"""Lumbre palette: cold indigo darkness vs. warm lantern light.

One character per colour so sprites can be written as ASCII grids.
The same values are mirrored in src/core/palette.gd for runtime effects.
"""


def _hex(h: str) -> tuple[int, int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


HEX = {
    # night ramp (outline -> bone white)
    "0": "#0b0a12",
    "1": "#161427",
    "2": "#231f3a",
    "3": "#34304f",
    "4": "#4a4766",
    "5": "#6b6a86",
    "6": "#9493a8",
    "7": "#c9c6d1",
    "8": "#f2eee6",
    # fire ramp
    "r": "#3f1d1f",
    "R": "#6e2b25",
    "o": "#a6402a",
    "O": "#d9622b",
    "y": "#f29a38",
    "Y": "#ffc85a",
    "l": "#ffe9a3",
    "w": "#fff8e0",
    # wood / wax / skin ramp
    "b": "#3b2a26",
    "B": "#5c4033",
    "n": "#85614a",
    "N": "#b58b65",
    "x": "#d9b98f",
    "X": "#efdcb8",
    # sewer moss ramp
    "g": "#1d2b26",
    "G": "#2f4a3a",
    "e": "#4f7350",
    "E": "#86a86a",
    # spectral teal ramp
    "c": "#1b3045",
    "C": "#2d5b73",
    "t": "#4f9bb0",
    "T": "#9fe0e6",
    # penumbra ramp
    "p": "#2b1838",
    "P": "#4e2459",
    "m": "#8a3b7d",
    "M": "#d46aa6",
    # brass ramp (lantern, UI frames)
    "k": "#4a3320",
    "K": "#7a5a2c",
    "h": "#b8893e",
    "H": "#e8c170",
}

PAL = {k: _hex(v) for k, v in HEX.items()}
OUTLINE = PAL["0"]
