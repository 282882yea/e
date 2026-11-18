"""Generates the pixel-art flowers and the window background for Lunar.

    python3 gen_art.py            # writes ../assets/*.png

Everything is procedural (seeded), so the art can be re-rolled by changing SEED.
"""
import math, os, random
import numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
SEED = 7

# dusky rose ramp, dark -> light (sampled from the reference art)
RAMP = [
    (30, 12, 30), (56, 16, 40), (76, 23, 52), (97, 29, 66), (117, 40, 76),
    (134, 60, 97), (153, 78, 109), (176, 104, 132), (216, 164, 188),
]
YELLOW = (206, 172, 112)
WHITE = (228, 178, 202)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.tone = np.full((h, w), -1.0)       # -1 = empty, else 0..8 ramp index (float)
        self.over = {}                           # (x, y) -> rgb override
        self.stars = []                          # centres of the small blossoms (twinkle anchors)

    def put(self, x, y, t):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.tone[y, x] = t

    def get(self, x, y):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.tone[y, x]
        return -1

    def blob(self, cx, cy, r, base, rng, squash=1.0, light=(0.6, -0.8)):
        """A shaded clump: lighter towards `light`, darker rim on the far side."""
        r2 = r + 1
        for y in range(int(cy - r2), int(cy + r2) + 1):
            for x in range(int(cx - r2), int(cx + r2) + 1):
                dx, dy = (x - cx), (y - cy) / squash
                d = math.hypot(dx, dy)
                if d > r + rng.uniform(-0.45, 0.35):
                    continue
                lit = (dx * light[0] + dy * light[1]) / max(r, 1)
                t = base + lit * 1.5 + rng.uniform(-0.35, 0.35)
                if d > r - 0.9:
                    t -= 1.0 if lit < 0.2 else 0.2
                self.put(x, y, max(0, min(8, t)))

    def image(self):
        img = np.zeros((self.h, self.w, 4), dtype=np.uint8)
        for y in range(self.h):
            for x in range(self.w):
                t = self.tone[y, x]
                if t < 0:
                    continue
                img[y, x, :3] = RAMP[int(round(max(0, min(8, t))))]
                img[y, x, 3] = 255
        for (x, y), c in self.over.items():
            if 0 <= x < self.w and 0 <= y < self.h:
                img[y, x, :3] = c
                img[y, x, 3] = 255
        return Image.fromarray(img, "RGBA")


def petal_flower(cv, cx, cy, R, rng, petals=5, rot=0.0, base=5.2):
    """A big open blossom: wide petals, dark seams, speckled centre."""
    for y in range(int(cy - R - 2), int(cy + R + 3)):
        for x in range(int(cx - R - 2), int(cx + R + 3)):
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            a = math.atan2(dy, dx) - rot
            k = (a / (2 * math.pi) * petals) % 1.0          # 0..1 across one petal
            edge = abs(k - 0.5) * 2                         # 0 centre of petal, 1 seam
            rr = R * (0.72 + 0.28 * math.cos((k - 0.5) * math.pi)) * (1 + 0.05 * math.sin(a * 3))
            if d > rr:
                continue
            t = base + 1.6 * (d / R) - 2.6 * edge ** 3 + rng.uniform(-0.3, 0.3)
            t += 0.9 * (-(dx * -0.5 + dy * 0.8) / R)        # light from the upper right
            if d > rr - 1.0:
                t -= 0.9
            if edge < 0.12 and d > R * 0.3:
                t -= 0.7                                    # vein
            cv.put(x, y, max(1, min(8, t)))
    # centre
    cr = max(2.0, R * 0.26)
    for y in range(int(cy - cr - 1), int(cy + cr + 2)):
        for x in range(int(cx - cr - 1), int(cx + cr + 2)):
            d = math.hypot(x - cx, y - cy)
            if d <= cr:
                cv.put(x, y, 4.2 - 1.5 * (d / cr) + rng.uniform(-0.3, 0.3))
    n = max(5, int(R * 0.9))
    for i in range(n):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(cr * 0.2, cr * 1.25)
        cv.over[(int(round(cx + math.cos(a) * d)), int(round(cy + math.sin(a) * d)))] = \
            YELLOW if rng.random() < 0.7 else RAMP[8]


def star(cv, x, y, rng, big=False):
    """Small four-petal blossom with a bright centre."""
    x, y = int(round(x)), int(round(y))
    arms = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    for ax, ay in arms:
        cv.put(x + ax, y + ay, 5.6)
        if big:
            cv.put(x + 2 * ax, y + 2 * ay, 4.6)
    for ax, ay in [(1, 1), (-1, 1), (1, -1), (-1, -1)]:
        cv.put(x + ax, y + ay, 3.2 if not big else 4.0)
    cv.put(x, y, 8)
    cv.over[(x, y)] = WHITE
    if 1 <= x < cv.w - 1 and 1 <= y < cv.h - 1:
        cv.stars.append([x, y])


def strand(cv, x0, y0, length, rng, r0=4.6, r1=1.3, sway=3.0, base=3.3, lean=0.0):
    """One hanging raceme: clumps shrinking towards the tip."""
    phase = rng.uniform(0, 6.28)
    freq = rng.uniform(0.045, 0.08)
    y = y0
    tips = []
    while y < y0 + length:
        k = (y - y0) / length
        r = r0 + (r1 - r0) * (k ** 0.85)
        x = x0 + lean * (y - y0) + math.sin(phase + (y - y0) * freq) * sway * (0.3 + k)
        n = 2 if r > 3 else 1
        for _ in range(n):
            ox = rng.uniform(-r * 0.75, r * 0.75)
            oy = rng.uniform(-1, 1)
            cv.blob(x + ox, y + oy, r * rng.uniform(0.7, 1.05), base + rng.uniform(-0.9, 0.9), rng,
                    squash=rng.uniform(0.85, 1.2))
        tips.append((x, y, r))
        y += max(1.6, r * rng.uniform(0.75, 1.1))
    return tips


def sparkle(cv, rng, density=0.03, lo=6.2, hi=8):
    ys, xs = np.where(cv.tone >= 0)
    for x, y in zip(xs, ys):
        if rng.random() < density:
            cv.tone[y, x] = rng.uniform(lo, hi)


def erode_specks(cv, rng, p=0.18):
    """Punch a few holes along the silhouette so the edge reads as petals, not a blob."""
    t = cv.tone
    for y in range(1, cv.h - 1):
        for x in range(1, cv.w - 1):
            if t[y, x] < 0:
                continue
            empty = sum(1 for ax, ay in ((1, 0), (-1, 0), (0, 1), (0, -1)) if t[y + ay, x + ax] < 0)
            if empty >= 2 and rng.random() < p:
                t[y, x] = -1


def flowers_left(rng):
    """Top-left: one big blossom in the corner, a cascade hugging the left edge.
    Kept narrow: it hangs over the sidebar icons but must stay clear of the labels."""
    W, H = 28, 80
    cv = Canvas(W, H)
    # cascade first so the blossom sits on top
    specs = [  # x0, y0, length, r0, sway, lean
        (3, 6, 70, 4.8, 1.6, 0.00), (7, 5, 64, 5.0, 2.0, 0.03), (12, 8, 56, 4.8, 2.2, 0.05),
        (16, 10, 46, 4.4, 2.2, 0.06), (20, 9, 32, 3.8, 1.8, 0.05), (5, 30, 46, 4.0, 2.0, 0.02),
        (10, 34, 38, 3.8, 2.2, 0.05), (15, 40, 26, 3.4, 2.0, 0.05),
    ]
    tips = []
    for x0, y0, L, r0, sw, lean in specs:
        tips.append(strand(cv, x0, y0, L, rng, r0=r0, r1=1.8, sway=sw, lean=lean, base=2.9)[-1])
    erode_specks(cv, rng)
    sparkle(cv, rng, 0.009, lo=5.4, hi=7.0)
    for x, y, r in tips:
        star(cv, x, y + 1, rng, big=rng.random() < 0.4)
    for _ in range(3):
        ys, xs = np.where(cv.tone >= 0)
        i = rng.randrange(len(xs))
        if ys[i] > 26:
            star(cv, xs[i], ys[i], rng)
    petal_flower(cv, 11, 10, 10, rng, petals=5, rot=0.5, base=4.9)
    return cv


def flowers_right(rng):
    """Top-right: large blossom in the corner and a broad cascade down the right edge."""
    W, H = 46, 116
    cv = Canvas(W, H)
    specs = [
        (43, 16, 94, 5.6, 1.8, -0.01), (38, 18, 92, 5.8, 2.6, -0.03), (33, 20, 88, 5.6, 2.8, -0.05),
        (28, 24, 80, 5.4, 2.8, -0.06), (23, 28, 68, 5.0, 2.6, -0.07), (18, 32, 52, 4.6, 2.4, -0.08),
        (13, 38, 34, 4.0, 2.0, -0.08), (41, 54, 56, 5.0, 2.0, -0.02), (36, 56, 54, 4.8, 2.4, -0.04),
        (31, 60, 48, 4.6, 2.4, -0.05), (26, 64, 38, 4.2, 2.2, -0.06), (21, 70, 24, 3.6, 2.0, -0.06),
    ]
    tips = []
    for x0, y0, L, r0, sw, lean in specs:
        tips.append(strand(cv, x0, y0, L, rng, r0=r0, r1=2.2, sway=sw, lean=lean, base=2.9)[-1])
    erode_specks(cv, rng)
    sparkle(cv, rng, 0.009, lo=5.4, hi=7.0)
    for x, y, r in tips:
        star(cv, x, y + 1, rng, big=rng.random() < 0.5)
    for _ in range(4):
        ys, xs = np.where(cv.tone >= 0)
        i = rng.randrange(len(xs))
        if ys[i] > 40:
            star(cv, xs[i], ys[i], rng)
    petal_flower(cv, 29, 14, 15, rng, petals=5, rot=0.25, base=5.0)
    return cv


def petal_sprite(rng):
    """One loose petal, used for the falling-petal animation."""
    cv = Canvas(7, 6)
    shape = ["..xxx..", ".xxxxx.", "xxxxxxx", "xxxxxx.", ".xxxx..", "..xx..."]
    for y, row in enumerate(shape):
        for x, c in enumerate(row):
            if c == "x":
                cv.put(x, y, 5.4 + (3 - y) * 0.5 + (x - 3) * 0.25)
    return cv.image()


def glow(shape, size, color, alpha, sigma):
    """size=(w,h) image with a blurred blob described by `shape` (PIL draw callback)."""
    from PIL import ImageDraw
    m = Image.new("L", size, 0)
    shape(ImageDraw.Draw(m))
    m = m.filter(ImageFilter.GaussianBlur(sigma))
    layer = Image.new("RGBA", size, color + (0,))
    layer.putalpha(m.point(lambda v: int(v * alpha)))
    return layer


def background(rng):
    """Smooth dark-plum backdrop: corner glow and soft bokeh. Kept low-res on purpose,
    it is all gradients, so it upscales cleanly and stays small enough to embed."""
    W, H = 384, 232
    s = W / 1024.0
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    top = np.array([16, 8, 17], np.float32)
    bot = np.array([12, 7, 13], np.float32)
    k = (yy / H)[..., None]
    base = top * (1 - k) + bot * k
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB").convert("RGBA")

    def ell(cx, cy, rx, ry):
        return lambda d: d.ellipse([(cx - rx) * s, (cy - ry) * s, (cx + rx) * s, (cy + ry) * s], fill=255)

    blobs = [  # design-space coords (1024x620): shape, colour, alpha, blur
        (ell(40, 0, 200, 96), (112, 48, 86), 0.85, 46),          # top-left corner glow (behind logo)
        (ell(360, 6, 220, 30), (96, 44, 84), 0.40, 30),          # fades along the top bar
        (ell(990, 60, 80, 150), (112, 38, 84), 0.50, 55),        # behind the right cascade
        (ell(617, 290, 46, 190), (150, 44, 96), 0.42, 34),       # pink seam between the two columns
        (ell(620, 480, 400, 20), (150, 48, 100), 0.34, 24),      # and under the first row of cards
        (ell(520, 360, 150, 110), (120, 36, 82), 0.34, 70),      # bokeh behind the cards
        (ell(820, 440, 170, 120), (104, 34, 96), 0.34, 80),
        (ell(330, 540, 150, 80), (96, 30, 70), 0.30, 70),
        (ell(760, 150, 120, 70), (70, 34, 104), 0.30, 60),       # violet
        (ell(30, 400, 60, 70), (110, 40, 76), 0.30, 40),         # low on the sidebar edge
    ]
    for shape, color, alpha, sigma in blobs:
        img = Image.alpha_composite(img, glow(shape, (W, H), color, alpha, sigma * s))

    arr = np.asarray(img).astype(np.float32)[..., :3]
    vx = (xx / W - 0.5) * 2
    vy = (yy / H - 0.5) * 2
    vig = 1.0 - 0.28 * np.clip(vx * vx * 0.5 + np.clip(vy, 0, 1) ** 2 * 0.9, 0, 1.4)
    arr *= vig[..., None]
    # one level of dither: the gradients are so dark that plain rounding shows as bands
    dither = np.random.default_rng(SEED).random((H, W, 1)).astype(np.float32)
    return Image.fromarray(np.clip(np.floor(arr + dither), 0, 255).astype(np.uint8), "RGB")


def blossoms(rng):
    """Dim oversized pixel blossoms that sit between the backdrop and the UI.
    One art pixel = 3 design px, so the layer is 1024x620 / 3."""
    W, H = 342, 207
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    def big_flower(cx, cy, R, rot, tint, alpha, petals=5):
        cv = Canvas(int(R * 2 + 6), int(R * 2 + 6))
        petal_flower(cv, R + 3, R + 3, R, rng, petals=petals, rot=rot, base=4.4)
        cv.over = {}
        arr = np.asarray(cv.image()).astype(np.float32)
        lum = arr[..., :3].mean(axis=2, keepdims=True) / 255.0
        arr[..., :3] = np.array(tint, np.float32) * (0.55 + 0.9 * lum)
        arr[..., 3] *= alpha
        im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
        out.alpha_composite(im, (int(cx / 3 - im.width / 2), int(cy / 3 - im.height / 2)))

    def bud(cx, cy, w, h, tint, alpha):
        cx, cy = cx / 3, cy / 3
        for y in range(int(cy - h), int(cy + h * 1.3) + 1):
            for x in range(int(cx - w), int(cx + w) + 1):
                k = (y - (cy - h)) / (h * 2.3)
                half = w * math.sin(min(1.0, k * 1.25) * math.pi * 0.5) * (1.0 if k < 0.8 else max(0.0, (1 - k) / 0.2) ** 0.5)
                if abs(x - cx) <= half and 0 <= x < W and 0 <= y < H:
                    shade = 0.8 + 0.5 * (1 - k) - 0.25 * abs(x - cx) / max(w, 1)
                    out.putpixel((x, y), tuple(int(min(255, c * shade)) for c in tint) + (int(255 * alpha),))

    big_flower(830, 100, 11, 0.4, (112, 30, 74), 0.34)
    big_flower(236, 112, 16, 1.1, (100, 28, 66), 0.40)
    big_flower(590, 300, 19, 0.9, (92, 24, 62), 0.26)
    big_flower(930, 520, 21, 0.1, (86, 24, 64), 0.28)
    big_flower(118, 500, 23, 0.7, (70, 20, 52), 0.20)
    big_flower(430, 566, 13, 1.9, (96, 30, 72), 0.24)
    big_flower(716, 236, 10, 2.4, (100, 34, 84), 0.20)
    bud(880, 100, 8, 9, (62, 36, 120), 0.55)
    bud(96, 310, 9, 10, (58, 32, 104), 0.22)
    return out


def glow_ring():
    """Fallback 9-slice outer glow for clients without UIShadow (white, tinted at runtime)."""
    S, pad, rad = 96, 32, 16
    from PIL import ImageDraw
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).rounded_rectangle([pad, pad, S - pad - 1, S - pad - 1], rad, fill=255)
    blur = m.filter(ImageFilter.GaussianBlur(10))
    a = np.asarray(blur).astype(np.float32) * (1 - np.asarray(m).astype(np.float32) / 255.0)
    out = np.zeros((S, S, 4), np.uint8)
    out[..., :3] = 255
    out[..., 3] = np.clip(a * 1.25, 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    import json
    meta = {"sizes": {}, "sparkles": {}}
    for name, cv in (("flowers_left", flowers_left(random.Random(SEED))),
                     ("flowers_right", flowers_right(random.Random(SEED + 1)))):
        cv.image().save(os.path.join(OUT, name + ".png"), optimize=True)
        meta["sizes"][name] = [cv.w, cv.h]
        meta["sparkles"][name] = cv.stars
    with open(os.path.join(OUT, "art.json"), "w") as f:
        json.dump(meta, f)
    petal_sprite(random.Random(SEED)).save(os.path.join(OUT, "petal.png"), optimize=True)
    glow_ring().save(os.path.join(OUT, "glow.png"), optimize=True)
    background(random.Random(SEED + 2)).save(os.path.join(OUT, "background.png"), optimize=True)
    blossoms(random.Random(SEED + 3)).save(os.path.join(OUT, "blossoms.png"), optimize=True)
    for n in sorted(os.listdir(OUT)):
        print(n, os.path.getsize(os.path.join(OUT, n)))


if __name__ == "__main__":
    main()
