"""Procedural pixel drawing on palette ramps: shaded blobs, polygons,
lines and dithered gradients. Used for larger sprites (bosses, props)
where hand-written ASCII would be impractical."""
import math

from PIL import Image

from palette import PAL
from pixel import blank, dither_pick, outline

# light comes from the upper left
LIGHT_DIR = (-0.55, -0.83)


class Canvas:
    def __init__(self, w, h):
        self.img = blank(w, h)
        self.px = self.img.load()
        self.w = w
        self.h = h

    def set(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = PAL[ch]

    def get_alpha(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y][3]
        return 0

    def blob(self, cx, cy, rx, ry, ramp, light=LIGHT_DIR, rim=True, dither=True, mask=None):
        """Filled ellipse shaded with a ramp (list of palette chars dark->light)."""
        n = len(ramp)
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                d = dx * dx + dy * dy
                if d > 1.0:
                    continue
                if mask and not mask(x, y):
                    continue
                nz = math.sqrt(max(0.0, 1.0 - d))
                lum = -(dx * light[0] + dy * light[1]) * 0.75 + nz * 0.45
                lum = (lum + 0.6) / 1.4
                if rim and d > 0.82 and lum > 0.5:
                    lum -= 0.15
                lum = max(0.0, min(0.999, lum))
                f = lum * n
                i = int(f)
                if dither and i < n - 1 and dither_pick(x, y, f - i) and (f - i) > 0.35:
                    i += 1
                self.set(x, y, ramp[min(i, n - 1)])

    def rect(self, x0, y0, x1, y1, ch):
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.set(x, y, ch)

    def hline(self, x0, x1, y, ch):
        for x in range(x0, x1 + 1):
            self.set(x, y, ch)

    def vline(self, x, y0, y1, ch):
        for y in range(y0, y1 + 1):
            self.set(x, y, ch)

    def line(self, x0, y0, x1, y1, ch):
        steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(steps + 1):
            t = i / max(1, steps)
            self.set(int(round(x0 + (x1 - x0) * t)), int(round(y0 + (y1 - y0) * t)), ch)

    def poly(self, pts, ch):
        """Scanline fill of a polygon."""
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            for i in range(len(pts)):
                (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % len(pts)]
                if (y0 <= y + 0.5 < y1) or (y1 <= y + 0.5 < y0):
                    xs.append(x0 + (y + 0.5 - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for j in range(0, len(xs) - 1, 2):
                for x in range(int(round(xs[j])), int(round(xs[j + 1]))):
                    self.set(x, y, ch)

    def shade_poly(self, pts, ramp, axis="x"):
        """Polygon shaded across its bounding box (left light -> right dark)."""
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        x0, x1 = min(xs), max(xs)
        y0, y1 = min(ys), max(ys)
        tmp = Canvas(self.w, self.h)
        tmp.poly(pts, "8")
        n = len(ramp)
        for y in range(self.h):
            for x in range(self.w):
                if tmp.px[x, y][3]:
                    t = (x - x0) / max(1, x1 - x0) if axis == "x" else (y - y0) / max(1, y1 - y0)
                    t = 1.0 - t
                    f = t * (n - 0.01)
                    i = int(f)
                    if i < n - 1 and dither_pick(x, y, f - i) and (f - i) > 0.4:
                        i += 1
                    self.set(x, y, ramp[min(i, n - 1)])

    def outlined(self, color="0"):
        return outline(self.img, PAL[color])

    def image(self):
        return self.img
