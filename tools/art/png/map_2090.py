"""The travel map: ซอยส่งไว drawn by hand on a folded, water-stained sheet
(owner 2026-10-02: "หน้าเลือกที่ไป = แผนที่แบบ Monkey Island").
Run: python3 map_2090.py <out_dir>      (default assets/art/ui/ -> map.png, map_pin.png)

Ink + coloured pencil, top-down with the buildings sketched sideways the way a
rider would doodle them. Every place of the whole soi is drawn (15, DESIGN 12)
with NO names: the game lays the names and pins on top (MapView) only for places
the rider knows, so unknown ones are just buildings on paper. บ้านเลขที่ 0 is a
smudge where something was rubbed out. Painted at 2560x1600 for a 1920x1200
design space; PLACES below are fractions of the sheet and must match
Rooms.TRAVEL[...]["map"] (test_map checks)."""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy.ndimage import gaussian_filter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "..")
FONT_HAND = os.path.join(ROOT, "assets/fonts/Sriracha-Regular.ttf")
FONT_SIGN = os.path.join(ROOT, "assets/fonts/Mali-SemiBold.ttf")
W, H = 2560, 1600
K = W / 1920  # design coordinates are 1920x1200
SS = 2  # supersampling

PAPER = (236, 224, 196)
PAPER_DARK = (214, 196, 160)
INK = (46, 36, 48)
INK_SOFT = (46, 36, 48, 150)
RED = (190, 46, 40)
WATER = (122, 160, 192)
WATER_INK = (58, 86, 128)
GREEN = (116, 150, 92)
ORANGE = (222, 140, 68)
GREY = (140, 136, 130)
ZINC = (168, 170, 164)

# id -> (fx, fy): where each place sits on the sheet (fractions of 1920x1200).
# The six the bike can reach today carry the same numbers in rooms.gd.
PLACES = {
    "home": (0.17, 0.70),
    "pier": (0.26, 0.835),
    "boat_rank": (0.37, 0.90),
    "noodle_boat": (0.45, 0.62),
    "roof_market": (0.60, 0.76),
    "stilts": (0.22, 0.46),
    "cat_roof": (0.31, 0.32),
    "boat_garage": (0.55, 0.42),
    "temple": (0.78, 0.56),
    "old_gate": (0.68, 0.27),
    "station": (0.71, 0.18),
    "kiao_raft": (0.86, 0.80),
    "hall": (0.42, 0.21),
    "condo": (0.89, 0.37),
    "guard_post": (0.52, 0.12),
}


def k(v):
    return v * K * SS


def P(fx, fy):
    return (fx * W * SS, fy * H * SS)


def rng(seed):
    return np.random.default_rng(seed)


def font(path, size):
    return ImageFont.truetype(path, int(k(size)))


def layer():
    return Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))


def noise(w, h, seed, blur=2.0):
    n = gaussian_filter(rng(seed).standard_normal((h, w)), blur)
    return n / max(1e-6, np.abs(n).max())


# --- strokes ---------------------------------------------------------------------
def wobble(pts, seed, jitter=1.4, steps=8):
    """Resample a polyline with pen wobble (design px jitter)."""
    r = rng(seed)
    out = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        for i in range(steps):
            t = i / steps
            out.append((x0 + (x1 - x0) * t + r.normal(0, k(jitter)), y0 + (y1 - y0) * t + r.normal(0, k(jitter))))
    out.append(pts[-1])
    return out


def ink(draw, pts, width=2.6, color=INK, seed=1, jitter=1.2, closed=False):
    pts = list(pts)
    if closed:
        pts = pts + [pts[0]]
    draw.line(wobble(pts, seed, jitter), fill=color, width=max(1, int(k(width))), joint="curve")


def ink_poly(draw, pts, width=2.6, color=INK, seed=1):
    ink(draw, pts, width, color, seed, closed=True)


def ink_ellipse(draw, cx, cy, rx, ry, width=2.4, color=INK, seed=1, n=28):
    pts = [(cx + rx * math.cos(a), cy + ry * math.sin(a)) for a in np.linspace(0, 2 * math.pi, n)]
    ink(draw, pts, width, color, seed, jitter=0.8)


def pencil(img, pts, color, alpha=120, seed=3, grain=0.5):
    """Coloured-pencil fill of a polygon: flat tone with paper grain and a ragged edge."""
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    a = np.asarray(m, np.float32)
    a = gaussian_filter(a, k(1.5)) + noise(img.size[0] // 8, img.size[1] // 8, seed, 1.0).repeat(8, 0).repeat(8, 1)[: a.shape[0], : a.shape[1]] * 90 * grain
    a = np.clip((a - 90) * 2.2, 0, 255) * (alpha / 255.0)
    fill = Image.new("RGBA", img.size, color + (255,))
    fill.putalpha(Image.fromarray(a.astype(np.uint8), "L"))
    img.alpha_composite(fill)


def hatch(draw, pts, spacing=9, angle=35, color=INK_SOFT, width=1.4, seed=5):
    """Pencil hatching inside a polygon (clipped by drawing on a mask)."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    m = Image.new("L", (int(x1 - x0) + 2, int(y1 - y0) + 2), 0)
    ImageDraw.Draw(m).polygon([(x - x0, y - y0) for x, y in pts], fill=255)
    lines = Image.new("RGBA", m.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lines)
    s = k(spacing)
    a = math.radians(angle)
    dx, dy = math.cos(a), math.sin(a)
    diag = math.hypot(*m.size)
    r = rng(seed)
    t = -diag
    while t < diag:
        cx, cy = m.size[0] / 2 - dy * t, m.size[1] / 2 + dx * t
        p0 = (cx - dx * diag + r.normal(0, k(1)), cy - dy * diag + r.normal(0, k(1)))
        p1 = (cx + dx * diag + r.normal(0, k(1)), cy + dy * diag + r.normal(0, k(1)))
        d.line([p0, p1], fill=color, width=max(1, int(k(width))))
        t += s
    lines.putalpha(Image.fromarray(np.minimum(np.asarray(lines.split()[3]), np.asarray(m))))
    draw._image.alpha_composite(lines, (int(x0), int(y0)))


def label(draw, xy, s, size, color=INK, anchor="mm", hand=True):
    draw.text(xy, s, font=font(FONT_HAND if hand else FONT_SIGN, size), fill=color, anchor=anchor)


# --- the sheet -------------------------------------------------------------------
def sheet():
    """Folded, water-stained paper with ragged edges; alpha outside."""
    w, h = W * SS, H * SS
    pad = k(36)
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((pad, pad, w - pad, h - pad), int(k(10)), fill=255)
    a = gaussian_filter(np.asarray(m, np.float32), k(2.5))
    # ragged edge: noise only where the blur has softened the edge (inside the
    # sheet it would punch holes that show the dark screen through)
    edge = noise(w // 8, h // 8, 11, 1.2).repeat(8, 0).repeat(8, 1)[:h, :w] * 150
    a = a + edge * (a < 254)
    alpha = np.clip((a - 110) * 3, 0, 255)
    # tone: paper grain + darker toward the folds and corners
    n = noise(w // 4, h // 4, 12, 2.0).repeat(4, 0).repeat(4, 1)[:h, :w]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = w / 2, h / 2
    vign = 1.0 - 0.18 * (((xx - cx) / cx) ** 2 + ((yy - cy) / cy) ** 2)
    arr = np.empty((h, w, 3), np.float32)
    for i in range(3):
        arr[..., i] = (PAPER[i] + n * 9) * vign
    # water stains: brown tide rings (the sheet lived in a wet bag)
    stain = np.zeros((h, w), np.float32)
    r = rng(13)
    for _ in range(7):
        sx, sy = r.uniform(0.1, 0.9) * w, r.uniform(0.1, 0.9) * h
        rad = r.uniform(0.08, 0.2) * w
        d2 = ((xx - sx) ** 2 + (yy - sy) ** 2) / rad**2
        ring = np.exp(-((np.sqrt(d2) - 1.0) ** 2) * 60) * 0.55 + np.clip(1 - d2, 0, 1) * 0.12
        stain += ring * r.uniform(0.5, 1.0)
    stain = gaussian_filter(stain, k(1.2))
    for i, c in enumerate((150, 118, 70)):
        arr[..., i] = arr[..., i] * (1 - stain * 0.22) + c * stain * 0.22
    # fold creases: one vertical, one horizontal, slightly lighter with a dark edge
    for axis, pos in ((0, w / 2), (1, h / 2)):
        d = np.abs((xx if axis == 0 else yy) - pos)
        crease = np.exp(-(d / k(3)) ** 2) * 0.1 - np.exp(-((d - k(5)) / k(2.5)) ** 2) * 0.04
        arr *= (1 - crease)[..., None]
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    img.putalpha(Image.fromarray(alpha.astype(np.uint8), "L"))
    return img


# --- things on the map -----------------------------------------------------------
def canal(img, draw):
    """คลองซอยส่งไว: the main canal from the bottom-left corner up to the sea wall,
    a side canal to the right. Blue pencil wash with ink banks and ripples."""
    main = [P(0.04, 0.96), P(0.14, 0.88), P(0.30, 0.86), P(0.40, 0.74), P(0.44, 0.60), P(0.50, 0.50), P(0.60, 0.40), P(0.66, 0.30), P(0.70, 0.22), P(0.72, 0.13)]
    side = [P(0.40, 0.74), P(0.56, 0.80), P(0.72, 0.84), P(0.90, 0.78), P(0.98, 0.70)]
    temple_arm = [P(0.60, 0.40), P(0.70, 0.50), P(0.82, 0.58), P(0.98, 0.52)]
    for pts, wd, seed in ((main, 56, 21), (side, 34, 22), (temple_arm, 30, 23)):
        wash = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(wash).line(wobble(pts, seed, 2.0, 6), fill=WATER + (115,), width=int(k(wd)), joint="curve")
        wash = wash.filter(ImageFilter.GaussianBlur(k(1.2)))
        grain = noise(img.size[0] // 8, img.size[1] // 8, seed, 1.0).repeat(8, 0).repeat(8, 1)[: img.size[1], : img.size[0]]
        a = np.asarray(wash.split()[3], np.float32) * (0.75 + grain * 0.35)
        wash.putalpha(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "L"))
        img.alpha_composite(wash)
        # banks: two ink lines offset from the centre line
        for sgn in (-1, 1):
            bank = []
            for i, (x, y) in enumerate(pts):
                x0, y0 = pts[max(0, i - 1)]
                x1, y1 = pts[min(len(pts) - 1, i + 1)]
                nx, ny = -(y1 - y0), (x1 - x0)
                ln = math.hypot(nx, ny) or 1
                bank.append((x + nx / ln * k(wd / 2) * sgn, y + ny / ln * k(wd / 2) * sgn))
            ink(draw, bank, 2.2, WATER_INK, seed + sgn, 1.6)
    # ripples and hyacinth clumps
    r = rng(31)
    for pts in (main, side, temple_arm):
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            for _ in range(3):
                t = r.uniform(0.1, 0.9)
                x, y = x0 + (x1 - x0) * t + r.normal(0, k(6)), y0 + (y1 - y0) * t + r.normal(0, k(6))
                ink(draw, [(x - k(9), y), (x - k(3), y - k(2)), (x + k(3), y), (x + k(9), y - k(2))], 1.4, WATER_INK, int(x), 0.5)
            if r.random() < 0.6:
                t = r.uniform(0.2, 0.8)
                x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                for j in range(4):
                    cx, cy = x + r.normal(0, k(7)), y + r.normal(0, k(5))
                    pencil(img, [(cx + k(4) * math.cos(a), cy + k(3) * math.sin(a)) for a in np.linspace(0, 6.28, 7)], GREEN, 170, seed=int(cx) + j, grain=0.2)


def stilt_house(draw, x, y, w=60, h=38, legs=22, seed=1, roof=ORANGE, img=None):
    """A house on legs, side view: roof, wall, legs in the water."""
    x0, x1, yb, yt = x - k(w / 2), x + k(w / 2), y, y - k(h)
    body = [(x0, yb), (x1, yb), (x1, yt), (x0, yt)]
    if img is not None:
        pencil(img, body, (222, 206, 166), 160, seed)
    ink_poly(draw, body, 2.4, INK, seed)
    roof_pts = [(x0 - k(6), yt), (x, yt - k(h * 0.55)), (x1 + k(6), yt)]
    if img is not None:
        pencil(img, roof_pts, roof, 190, seed + 1)
    ink(draw, roof_pts, 2.6, INK, seed + 1)
    for i in range(3):
        lx = x0 + (x1 - x0) * (0.15 + 0.35 * i)
        ink(draw, [(lx, yb), (lx + k(1), yb + k(legs))], 2.2, INK, seed + 2 + i, 0.6)
    ink(draw, [(x - k(8), y - k(h * 0.55)), (x - k(8), y - k(h * 0.3)), (x + k(4), y - k(h * 0.3)), (x + k(4), y - k(h * 0.55))], 1.6, INK, seed + 7, 0.5, closed=True)


def boat(draw, x, y, w=54, seed=1, roof=False, img=None, color=(214, 150, 92)):
    """A longtail hull seen from the side, bow to the right."""
    x0, x1 = x - k(w / 2), x + k(w / 2)
    hull = [(x0, y - k(8)), (x0 + k(w * 0.15), y + k(6)), (x1 - k(w * 0.2), y + k(6)), (x1 + k(6), y - k(14))]
    if img is not None:
        pencil(img, hull, color, 180, seed)
    ink(draw, hull, 2.4, INK, seed)
    ink(draw, [hull[0], hull[-1]], 1.6, INK, seed + 1, 0.5)
    if roof:
        ink(draw, [(x0 + k(w * 0.2), y - k(8)), (x0 + k(w * 0.2), y - k(26)), (x1 - k(w * 0.25), y - k(26)), (x1 - k(w * 0.25), y - k(8))], 2.0, INK, seed + 2, 0.6)


def pier(draw, x, y, seed=1):
    """Planks on posts jutting into the canal."""
    for i in range(5):
        px = x - k(26) + k(13) * i
        ink(draw, [(px, y - k(10)), (px, y + k(10))], 1.6, INK, seed + i, 0.5)
    ink(draw, [(x - k(32), y - k(10)), (x + k(32), y - k(10))], 2.6, INK, seed + 9, 0.8)
    ink(draw, [(x - k(32), y + k(10)), (x + k(32), y + k(10))], 2.2, INK, seed + 10, 0.8)
    for i in range(3):
        px = x - k(20) + k(20) * i
        ink(draw, [(px, y + k(10)), (px, y + k(22))], 2.0, INK, seed + 20 + i, 0.5)


def umbrella(draw, x, y, r=12, seed=1, color=ORANGE, img=None):
    pts = [(x - k(r), y), (x, y - k(r * 0.9)), (x + k(r), y)]
    if img is not None:
        pencil(img, pts + [(x, y + k(2))], color, 200, seed)
    ink(draw, pts, 2.0, INK, seed)
    ink(draw, [(x - k(r), y), (x + k(r), y)], 1.6, INK, seed + 1, 0.4)
    ink(draw, [(x, y), (x, y + k(r * 1.1))], 1.6, INK, seed + 2, 0.4)


def place_home(img, draw):
    x, y = P(*PLACES["home"])
    # a two-storey rental block whose ground floor is canal: water line across it
    stilt_house(draw, x, y, 70, 64, 10, 101, (176, 120, 96), img)
    ink(draw, [(x - k(44), y - k(18)), (x + k(44), y - k(18))], 2.0, WATER_INK, 102, 1.0)
    hatch(draw, [(x - k(35), y - k(18)), (x + k(35), y - k(18)), (x + k(35), y), (x - k(35), y)], 7, 0, WATER + (120,), 1.2, 103)
    # the window with a plant and a clothesline to the next pole
    ink(draw, [(x + k(35), y - k(50)), (x + k(80), y - k(62))], 1.4, INK, 104, 0.6)
    for i in range(4):
        tx = x + k(42 + i * 9)
        ink(draw, [(tx, y - k(52 + i * 2.4)), (tx, y - k(40 + i * 2.4))], 2.4, (ORANGE, GREEN, RED, WATER)[i], 105 + i, 0.3)


def place_pier(img, draw):
    x, y = P(*PLACES["pier"])
    pier(draw, x, y, 111)
    boat(draw, x + k(44), y + k(20), 36, 112, img=img, color=(120, 160, 190))
    # the soi sign post
    ink(draw, [(x - k(44), y - k(6)), (x - k(44), y - k(40))], 2.4, INK, 113, 0.5)
    ink_poly(draw, [(x - k(58), y - k(40)), (x - k(28), y - k(40)), (x - k(28), y - k(28)), (x - k(58), y - k(28))], 2.0, INK, 114)
    pencil(img, [(x - k(58), y - k(40)), (x - k(28), y - k(40)), (x - k(28), y - k(28)), (x - k(58), y - k(28))], ORANGE, 190, 115)


def place_boat_rank(img, draw):
    x, y = P(*PLACES["boat_rank"])
    for i in range(3):
        boat(draw, x - k(30) + k(28) * i, y + k(6 * (i % 2)), 30, 121 + i, img=img, color=(228, 120, 60))
    umbrella(draw, x, y - k(26), 16, 125, GREEN, img)
    ink(draw, [(x, y - k(26)), (x, y)], 2.0, INK, 126, 0.4)


def place_noodle_boat(img, draw):
    x, y = P(*PLACES["noodle_boat"])
    boat(draw, x, y, 70, 131, img=img, color=(210, 140, 80))
    umbrella(draw, x - k(8), y - k(30), 20, 132, (230, 90, 60), img)
    ink(draw, [(x - k(8), y - k(30)), (x - k(8), y - k(6))], 2.0, INK, 133, 0.4)
    # steam from the pot
    for i in range(3):
        ink(draw, [(x + k(14), y - k(14 + i * 7)), (x + k(18), y - k(18 + i * 7)), (x + k(13), y - k(22 + i * 7))], 1.4, INK_SOFT, 134 + i, 0.5)


def place_roof_market(img, draw):
    x, y = P(*PLACES["roof_market"])
    # a row of shophouses with the market on the flat roof: umbrellas on top
    for i in range(3):
        bx = x - k(46) + k(46) * i
        body = [(bx - k(23), y), (bx + k(23), y), (bx + k(23), y - k(62)), (bx - k(23), y - k(62))]
        pencil(img, body, (214, 192, 150), 170, 141 + i)
        ink_poly(draw, body, 2.4, INK, 141 + i)
        ink(draw, [(bx - k(23), y - k(20)), (bx + k(23), y - k(20))], 1.8, WATER_INK, 144 + i, 0.6)
        ink(draw, [(bx - k(12), y - k(40)), (bx - k(12), y - k(50)), (bx + k(12), y - k(50)), (bx + k(12), y - k(40))], 1.4, INK, 147 + i, 0.4, closed=True)
    for i, col in enumerate((ORANGE, GREEN, RED, (230, 200, 80))):
        umbrella(draw, x - k(60) + k(40) * i, y - k(72), 13, 150 + i, col, img)


def place_stilts(img, draw):
    x, y = P(*PLACES["stilts"])
    stilt_house(draw, x - k(50), y + k(6), 52, 36, 24, 161, ORANGE, img)
    stilt_house(draw, x + k(14), y - k(4), 58, 40, 30, 162, (120, 150, 190), img)
    stilt_house(draw, x + k(76), y + k(10), 48, 34, 20, 163, GREEN, img)
    # the plank walkway
    ink(draw, [(x - k(84), y + k(26)), (x + k(110), y + k(30))], 2.6, INK, 164, 1.0)
    ink(draw, [(x - k(84), y + k(32)), (x + k(110), y + k(36))], 2.0, INK, 165, 1.0)
    for i in range(9):
        px = x - k(80) + k(22) * i
        ink(draw, [(px, y + k(26)), (px, y + k(34))], 1.6, INK, 166 + i, 0.4)


def place_cat_roof(img, draw):
    x, y = P(*PLACES["cat_roof"])
    # a zinc roof seen from above, corrugations, with a cat and a hoard
    roof = [(x - k(44), y - k(16)), (x + k(44), y - k(22)), (x + k(44), y + k(18)), (x - k(44), y + k(24))]
    pencil(img, roof, ZINC, 190, 171)
    ink_poly(draw, roof, 2.4, INK, 171)
    for i in range(1, 8):
        lx = x - k(44) + k(11) * i
        ink(draw, [(lx, y - k(16) - k(6) * (i / 8)), (lx, y + k(24) - k(6) * (i / 8))], 1.2, INK_SOFT, 172 + i, 0.3)
    # the cat: ink blob with ears and a curled tail
    cx, cy = x + k(10), y + k(2)
    ink_ellipse(draw, cx, cy, k(9), k(6), 2.2, INK, 180)
    ink(draw, [(cx - k(9), cy - k(3)), (cx - k(12), cy - k(10)), (cx - k(6), cy - k(6))], 2.0, INK, 181, 0.4)
    ink(draw, [(cx - k(4), cy - k(6)), (cx - k(2), cy - k(11)), (cx + k(1), cy - k(6))], 2.0, INK, 182, 0.4)
    ink(draw, [(cx + k(8), cy), (cx + k(16), cy - k(6)), (cx + k(14), cy - k(12))], 2.0, INK, 183, 0.5)
    # the hoard: a little pile of shiny things
    for i in range(4):
        hx, hy = x - k(24) + k(6) * i, y + k(8) - k(3) * (i % 2)
        ink_ellipse(draw, hx, hy, k(3), k(2), 1.4, INK, 184 + i, 10)


def place_garage(img, draw):
    x, y = P(*PLACES["boat_garage"])
    # the expressway: a grey band on pillars across the sheet, the garage under it
    band = [P(0.36, 0.52), P(0.76, 0.30), P(0.78, 0.335), P(0.38, 0.555)]
    pencil(img, band, GREY, 150, 191)
    ink_poly(draw, band, 2.6, INK, 191)
    ink(draw, [P(0.36, 0.51), P(0.76, 0.29)], 1.4, (255, 255, 255, 170), 192, 0.4)
    for t in np.linspace(0.08, 0.92, 7):
        px = band[3][0] + (band[2][0] - band[3][0]) * t
        py = band[3][1] + (band[2][1] - band[3][1]) * t
        ink(draw, [(px, py), (px, py + k(40))], 2.6, INK, 193 + int(t * 10), 0.5)
    # a hull upside down under it, a crane hook and tyres
    hull = [(x - k(40), y + k(20)), (x + k(40), y + k(20)), (x + k(30), y + k(2)), (x - k(30), y + k(2))]
    pencil(img, hull, (170, 110, 70), 170, 194)
    ink_poly(draw, hull, 2.4, INK, 194)
    for i in range(3):
        ink_ellipse(draw, x + k(52), y + k(18 - i * 7), k(8), k(4), 1.8, INK, 195 + i, 14)


def place_temple(img, draw):
    x, y = P(*PLACES["temple"])
    # the bell tower rising from the water: three tiers and a bell
    for i, (w, h) in enumerate(((44, 20), (34, 20), (24, 18))):
        yb = y - k(20 * i)
        body = [(x - k(w / 2), yb), (x + k(w / 2), yb), (x + k(w / 2) - k(3), yb - k(h)), (x - k(w / 2) + k(3), yb - k(h))]
        pencil(img, body, (236, 214, 150), 170, 201 + i)
        ink_poly(draw, body, 2.2, INK, 201 + i)
    top = y - k(58)
    roof = [(x - k(18), top), (x, top - k(26)), (x + k(18), top)]
    pencil(img, roof, (210, 80, 60), 190, 205)
    ink(draw, roof, 2.4, INK, 205)
    ink(draw, [(x, top - k(26)), (x, top - k(44))], 2.0, INK, 206, 0.4)
    ink_ellipse(draw, x, y - k(48), k(5), k(6), 1.8, INK, 207, 12)
    ink(draw, [(x - k(30), y + k(2)), (x + k(30), y + k(2))], 2.0, WATER_INK, 208, 1.0)
    # a monk's boat beside it
    boat(draw, x + k(50), y + k(8), 28, 209, img=img, color=ORANGE)


def place_old_gate(img, draw):
    x, y = P(*PLACES["old_gate"])
    # a bridge over the canal and the sluice gate under it
    arch = [(x - k(48), y + k(8)), (x - k(30), y - k(16)), (x, y - k(24)), (x + k(30), y - k(16)), (x + k(48), y + k(8))]
    ink(draw, arch, 2.8, INK, 211, 0.9)
    ink(draw, [(x - k(50), y - k(2)), (x + k(50), y - k(2))], 2.2, INK, 212, 0.6)
    for i in range(7):
        bx = x - k(42) + k(14) * i
        ink(draw, [(bx, y - k(2)), (bx, y - k(10))], 1.4, INK, 213 + i, 0.3)
    gate = [(x - k(16), y + k(8)), (x + k(16), y + k(8)), (x + k(16), y + k(28)), (x - k(16), y + k(28))]
    pencil(img, gate, (150, 120, 90), 180, 220)
    ink_poly(draw, gate, 2.4, INK, 220)
    hatch(draw, gate, 6, 90, INK_SOFT, 1.2, 221)
    ink_ellipse(draw, x + k(24), y + k(12), k(6), k(6), 1.8, INK, 222, 10)


def place_station(img, draw):
    x, y = P(*PLACES["station"])
    # บ้านเลขที่ 0: rubbed out. A grey smudge and the ghost of a box.
    sm = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(sm)
    d.ellipse((x - k(46), y - k(26), x + k(46), y + k(22)), fill=(90, 80, 70, 70))
    d.ellipse((x - k(30), y - k(18), x + k(36), y + k(14)), fill=(90, 80, 70, 60))
    img.alpha_composite(sm.filter(ImageFilter.GaussianBlur(k(5))))
    ink(draw, [(x - k(20), y - k(10)), (x + k(18), y - k(12)), (x + k(20), y + k(8)), (x - k(18), y + k(8))], 1.4, (46, 36, 48, 60), 231, 0.8, closed=True)
    label(draw, (x + k(4), y + k(26)), "(ลบไปแล้ว?)", 15, (46, 36, 48, 120))


def place_kiao_raft(img, draw):
    x, y = P(*PLACES["kiao_raft"])
    # a raft house: logs, a hut with a neon-ish sign
    raft = [(x - k(56), y + k(10)), (x + k(56), y + k(10)), (x + k(60), y + k(22)), (x - k(60), y + k(22))]
    pencil(img, raft, (150, 110, 70), 170, 241)
    ink_poly(draw, raft, 2.4, INK, 241)
    for i in range(1, 6):
        lx = x - k(56) + k(19) * i
        ink(draw, [(lx, y + k(10)), (lx, y + k(22))], 1.4, INK_SOFT, 242 + i, 0.3)
    stilt_house(draw, x, y + k(10), 56, 36, 0, 248, (160, 40, 40), img)
    # the sign
    sign = [(x - k(26), y - k(44)), (x + k(26), y - k(44)), (x + k(26), y - k(30)), (x - k(26), y - k(30))]
    pencil(img, sign, (230, 200, 80), 200, 250)
    ink_poly(draw, sign, 1.8, INK, 250)
    label(draw, (x, y - k(37)), "เงินด่วน", 11, RED)
    ink(draw, [(x, y - k(30)), (x, y - k(20))], 1.6, INK, 251, 0.3)


def place_hall(img, draw):
    x, y = P(*PLACES["hall"])
    # the community pavilion: open sala with a flag pole and a notice board
    body = [(x - k(40), y), (x + k(40), y), (x + k(40), y - k(28)), (x - k(40), y - k(28))]
    ink_poly(draw, body, 2.2, INK, 261)
    for i in range(4):
        px = x - k(34) + k(22) * i
        ink(draw, [(px, y), (px, y - k(28))], 1.8, INK, 262 + i, 0.3)
    roof = [(x - k(48), y - k(28)), (x, y - k(56)), (x + k(48), y - k(28))]
    pencil(img, roof, (90, 130, 110), 190, 266)
    ink(draw, roof, 2.6, INK, 266)
    ink(draw, [(x + k(56), y), (x + k(56), y - k(78))], 2.2, INK, 267, 0.4)
    flag = [(x + k(56), y - k(78)), (x + k(80), y - k(72)), (x + k(56), y - k(64))]
    pencil(img, flag, RED, 180, 268)
    ink(draw, flag, 1.8, INK, 268, closed=True)
    # the water forecast board: a gauge that someone keeps repainting
    board = [(x - k(74), y - k(8)), (x - k(54), y - k(8)), (x - k(54), y - k(40)), (x - k(74), y - k(40))]
    pencil(img, board, (240, 232, 200), 200, 269)
    ink_poly(draw, board, 1.8, INK, 269)
    for i in range(4):
        ink(draw, [(x - k(72), y - k(14 + i * 7)), (x - k(56), y - k(14 + i * 7))], 1.2, (RED if i == 1 else INK_SOFT), 270 + i, 0.3)


def place_condo(img, draw):
    x, y = P(*PLACES["condo"])
    body = [(x - k(26), y), (x + k(26), y), (x + k(26), y - k(110)), (x - k(26), y - k(110))]
    pencil(img, body, (200, 206, 214), 170, 281)
    ink_poly(draw, body, 2.4, INK, 281)
    for row in range(6):
        for col in range(2):
            wx, wy = x - k(14) + k(20) * col, y - k(14) - k(16) * row
            ink(draw, [(wx - k(5), wy - k(5)), (wx + k(5), wy - k(5)), (wx + k(5), wy + k(5)), (wx - k(5), wy + k(5))], 1.3, INK, 282 + row * 2 + col, 0.3, closed=True)
    # water line at the second floor; the entrance ramp at the third
    ink(draw, [(x - k(30), y - k(30)), (x + k(30), y - k(30))], 2.0, WATER_INK, 295, 0.8)
    hatch(draw, [(x - k(26), y - k(30)), (x + k(26), y - k(30)), (x + k(26), y), (x - k(26), y)], 7, 0, WATER + (120,), 1.2, 296)
    ink(draw, [(x - k(26), y - k(46)), (x - k(48), y - k(36))], 2.0, INK, 297, 0.5)


def place_guard_post(img, draw):
    x, y = P(*PLACES["guard_post"])
    # the sea wall: a thick hatched band along the top with the company's towers behind
    wall = [P(0.06, 0.055), P(0.96, 0.05), P(0.96, 0.095), P(0.06, 0.10)]
    pencil(img, wall, (168, 160, 150), 180, 301)
    ink_poly(draw, wall, 3.0, INK, 301)
    hatch(draw, wall, 10, 60, INK_SOFT, 1.4, 302)
    for i, (tx, tw, th) in enumerate(((0.16, 28, 40), (0.26, 20, 56), (0.34, 24, 34), (0.62, 22, 60), (0.70, 30, 42), (0.82, 18, 50))):
        bx, by = P(tx, 0.055)
        body = [(bx - k(tw / 2), by), (bx + k(tw / 2), by), (bx + k(tw / 2), by - k(th)), (bx - k(tw / 2), by - k(th))]
        pencil(img, body, (210, 214, 226), 150, 303 + i)
        ink_poly(draw, body, 1.8, INK, 303 + i)
    # the guard post: a box on the wall with a barrier arm and a cone of light
    box = [(x - k(22), y + k(14)), (x + k(22), y + k(14)), (x + k(22), y - k(18)), (x - k(22), y - k(18))]
    pencil(img, box, (120, 160, 200), 170, 311)
    ink_poly(draw, box, 2.4, INK, 311)
    ink(draw, [(x + k(22), y + k(2)), (x + k(60), y - k(10))], 2.6, RED, 312, 0.5)
    for i in range(3):
        ink(draw, [(x + k(30 + i * 10), y - k(1 - i * 3)), (x + k(30 + i * 10), y + k(6 - i * 3))], 2.4, (255, 255, 255, 230), 313 + i, 0.2)
    gx0, gy0 = P(0.485, 0.052)
    gx1, gy1 = P(0.515, 0.10)
    pencil(img, [(gx0, gy0), (gx1, gy0), (gx1, gy1), (gx0, gy1)], PAPER, 255, 316, grain=0.0)
    for gx in (gx0, gx1):
        ink(draw, [(gx, gy0), (gx, gy1)], 2.6, INK, 317 + int(gx), 0.4)
    ink(draw, [(gx0, gy0 + k(4)), (gx1, gy1 - k(4))], 1.6, INK_SOFT, 319, 0.4)
    ink(draw, [(gx0, gy1 - k(4)), (gx1, gy0 + k(4))], 1.6, INK_SOFT, 320, 0.4)


def decorations(img, draw):
    # title (hand written), a compass that is not sure, a government stamp
    label(draw, P(0.58, 0.14), "แผนที่ซอยส่งไว", 44, INK)
    label(draw, P(0.58, 0.18), "(วาดเอง อย่าเชื่อมาก น้ำเปลี่ยนทุกเดือน)", 19, (46, 36, 48, 170))
    cx, cy = P(0.92, 0.17)
    ink_ellipse(draw, cx, cy, k(34), k(34), 2.2, INK, 321)
    ink(draw, [(cx, cy + k(26)), (cx, cy - k(30))], 2.6, INK, 322, 0.5)
    ink(draw, [(cx - k(10), cy - k(16)), (cx, cy - k(30)), (cx + k(10), cy - k(16))], 2.4, RED, 323, 0.5)
    ink(draw, [(cx - k(26), cy), (cx + k(26), cy)], 1.6, INK_SOFT, 324, 0.5)
    label(draw, (cx, cy - k(48)), "เหนือ (มั้ง)", 16, INK)
    # the rubber stamp, slightly rotated, inked unevenly
    st = Image.new("RGBA", (int(k(360)), int(k(120))), (0, 0, 0, 0))
    d = ImageDraw.Draw(st)
    d.rounded_rectangle((k(4), k(4), k(356), k(116)), int(k(10)), outline=(70, 60, 150, 200), width=int(k(4)))
    d.text((k(180), k(36)), "โครงการแก้น้ำท่วมถาวร", font=font(FONT_SIGN, 24), fill=(70, 60, 150, 210), anchor="mm")
    d.text((k(180), k(80)), "ระยะที่ 14  ·  ตรวจแล้ว  ·  2089", font=font(FONT_SIGN, 20), fill=(70, 60, 150, 210), anchor="mm")
    a = np.asarray(st.split()[3], np.float32) * (0.55 + 0.45 * np.clip(noise(st.size[0] // 4, st.size[1] // 4, 44, 1.0).repeat(4, 0).repeat(4, 1)[: st.size[1], : st.size[0]] + 0.6, 0, 1))
    st.putalpha(Image.fromarray(a.astype(np.uint8), "L"))
    st = st.rotate(-7, resample=Image.BICUBIC, expand=True)
    sx, sy = P(0.085, 0.14)
    img.alpha_composite(st, (int(sx), int(sy)))
    # the rider's usual route: a dashed red pencil line along the main canal
    pts = [P(0.26, 0.80), P(0.40, 0.74), P(0.44, 0.60), P(0.50, 0.50), P(0.60, 0.40)]
    r = rng(45)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = 7
        for i in range(n):
            t0, t1 = i / n, (i + 0.5) / n
            ink(draw, [(x0 + (x1 - x0) * t0, y0 + (y1 - y0) * t0), (x0 + (x1 - x0) * t1, y0 + (y1 - y0) * t1)], 2.2, (190, 46, 40, 150), 46 + i + int(x0), 0.6)
    # scribbles: notes a rider would write
    label(draw, P(0.52, 0.24), "น้ำลงถึงจะผ่าน →", 15, (190, 46, 40, 190), "lm")
    label(draw, P(0.63, 0.90), "เจ๊เกียว ↗ อย่าไปตอนสิ้นเดือน", 15, (46, 36, 48, 170), "lm")
    label(draw, P(0.80, 0.47), "ระฆังตีตอนน้ำขึ้น", 14, (46, 36, 48, 150), "lm")
    # a coffee ring near a corner
    cx, cy = P(0.88, 0.93)
    ring = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ring)
    d.ellipse((cx - k(40), cy - k(40), cx + k(40), cy + k(40)), outline=(120, 80, 40, 90), width=int(k(5)))
    img.alpha_composite(ring.filter(ImageFilter.GaussianBlur(k(1.5))))


def pin(out_dir):
    """A red push pin (map_pin.png, 1x = 56x72) for the places you can go."""
    s = 4
    w, h = 56 * s, 72 * s
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # needle, then the head: a flat red disc with a highlight, cast shadow
    d.line([(w * 0.5, h * 0.42), (w * 0.5, h * 0.98)], fill=(80, 80, 90, 255), width=3 * s)
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((w * 0.2, h * 0.5, w * 0.8, h * 0.62), fill=(0, 0, 0, 90))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(2 * s)))
    d.ellipse((w * 0.14, h * 0.08, w * 0.86, h * 0.5), fill=(196, 44, 40, 255), outline=(60, 20, 20, 255), width=2 * s)
    d.ellipse((w * 0.3, h * 0.14, w * 0.5, h * 0.26), fill=(255, 150, 140, 200))
    im = im.resize((56, 72), Image.LANCZOS)
    im.save(os.path.join(out_dir, "map_pin.png"), optimize=True)
    print("wrote map_pin.png", im.size)


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    img = sheet()
    draw = ImageDraw.Draw(img)
    canal(img, draw)
    draw = ImageDraw.Draw(img)
    for fn in (
        place_guard_post,
        place_garage,
        place_home,
        place_pier,
        place_boat_rank,
        place_noodle_boat,
        place_roof_market,
        place_stilts,
        place_cat_roof,
        place_temple,
        place_old_gate,
        place_station,
        place_kiao_raft,
        place_hall,
        place_condo,
    ):
        fn(img, draw)
        draw = ImageDraw.Draw(img)
    decorations(img, draw)
    out = img.resize((W, H), Image.LANCZOS)
    out.save(os.path.join(out_dir, "map.png"), optimize=True)
    print("wrote map.png", out.size)
    pin(out_dir)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets/art/ui"))
