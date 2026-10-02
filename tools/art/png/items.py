"""Painted item icons for the bag + things lying on the floor (DESIGN 11.5).
Run: python3 items.py all <dir>   (or: <name> <out.png>)
Each icon is painted with the prop style (paint.py), then trimmed and centred
on a square ICON x ICON canvas. One file per item id in assets/data/puzzles.json;
ArtLibrary.item(id) loads assets/art/items/<id>.png."""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from paint import *  # noqa: E402,F401,F403

ICON = 192
INK = hexc("#1E1A1F")
PAPER = hexc("#EFE6CF")
PINK = hexc("#FF8FC1")
ORANGE = hexc("#F07A1E")
YELLOW = hexc("#F2C230")
GREEN = hexc("#2E8B57")
WIRE = hexc("#B8C0C8")
IRON = hexc("#4A5560")
TAPE = hexc("#222326")


def _canvas(seed):
    return Canvas(360, 380, seed=seed)


def debt_book(c):
    p = c.p
    c.box(-0.32, -0.24, 0.32, 0.24, 0, 10, PAPER, rim=0.4)
    c.box(-0.34, -0.26, 0.34, 0.26, 10, 34, RED, rim=0.8)
    c.text("หนี้", p(-0.25, 0.261, 30), p(0.25, 0.261, 30), 16, PAPER)
    c.disc(*p(0.0, 0.0, 34), 30 * c.ss, 15 * c.ss, PAPER, dome=False)
    c.text("30,000", p(-0.18, 0.0, 36), p(0.18, 0.0, 36), 10, RED)


def gum(c):
    p = c.p
    for k, (dx, dy, r) in enumerate(((0, 0, 40), (-24, -10, 26), (22, -14, 24), (6, -30, 20))):
        x, y = p(0, 0, 30)
        c.disc(x + dx * c.ss, y + dy * c.ss, r * c.ss, r * 0.8 * c.ss, PINK, spec=0.9)


def hanger(c):
    p = c.p
    pts = [p(-0.45, 0.0, 10), p(0.45, 0.0, 10), p(0.0, 0.0, 120), p(-0.45, 0.0, 10)]
    c.pipe(pts, 10, WIRE)
    c.pipe([p(0.0, 0.0, 120), p(0.0, 0.0, 150), p(0.08, 0.0, 168), p(0.15, 0.0, 150)], 10, WIRE)


def hook(c):
    p = c.p
    c.pipe([p(-0.55, 0.3, 10), p(0.5, -0.3, 120)], 6, WIRE)
    x, y = p(0.52, -0.31, 124)
    c.disc(x, y, 22 * c.ss, 18 * c.ss, PINK, spec=0.9)


def float_key(c):
    p = c.p
    c.pipe([p(-0.1, 0.0, 40), p(0.35, 0.0, 40)], 10, BRASS)
    for u in (0.24, 0.31):
        c.pipe([p(u, 0.0, 40), p(u, 0.0, 22)], 7, BRASS)
    x, y = p(-0.18, 0.0, 40)
    c.disc(x, y, 22 * c.ss, 22 * c.ss, BRASS, dome=False)
    c.disc(x, y, 8 * c.ss, 8 * c.ss, INK, dome=False)
    # rubber duck on the ring
    dx, dy = p(-0.38, 0.0, 70)
    c.disc(dx, dy + 10 * c.ss, 30 * c.ss, 22 * c.ss, YELLOW, spec=0.8)
    c.disc(dx - 14 * c.ss, dy - 16 * c.ss, 17 * c.ss, 17 * c.ss, YELLOW, spec=0.8)
    c.disc(dx - 30 * c.ss, dy - 14 * c.ss, 9 * c.ss, 5 * c.ss, ORANGE, dome=False)
    c.disc(dx - 16 * c.ss, dy - 20 * c.ss, 3 * c.ss, 3 * c.ss, INK, outline=0, dome=False)


def air_remote(c):
    p = c.p
    c.box(-0.12, -0.38, 0.12, 0.38, 0, 22, hexc("#D8DCDF"), rim=0.6)
    for k, col in enumerate((RED, hexc("#6E7880"), hexc("#6E7880"), hexc("#6E7880"))):
        x, y = p(0.0, -0.25 + k * 0.15, 22)
        c.disc(x, y, 12 * c.ss, 6 * c.ss, col)
    c.text("COOL", p(-0.1, 0.381, 12), p(0.1, 0.381, 12), 8, INK)


def letter(c):
    p = c.p
    c.box(-0.4, -0.26, 0.4, 0.26, 0, 6, PAPER, rim=0.5)
    c.stroke([p(-0.4, -0.26, 6), p(0.0, 0.0, 6), p(0.4, -0.26, 6)], 2.4, INK, 0.6)
    x, y = p(0.0, 0.02, 7)
    c.disc(x, y, 14 * c.ss, 8 * c.ss, RED, dome=False)


def sauce_packs(c):
    p = c.p
    for k in range(4):
        z = k * 10
        o = (k % 2) * 0.05
        c.box(-0.25 + o, -0.15 + o, 0.25 + o, 0.15 + o, z, z + 9, ORANGE, rim=0.5, outline=1.6)
    c.text("ด้วยรัก", p(-0.18, 0.201, 36), p(0.22, 0.201, 36), 10, PAPER)


def brass_box(c):
    p = c.p
    c.box(-0.3, -0.3, 0.3, 0.3, 0, 90, BRASS, rim=0.9)
    c.box(-0.32, -0.32, 0.32, 0.32, 90, 100, BRASS_D, rim=0.7)
    c.gear(*p(0.0, 0.301, 45), 22 * c.ss, BRASS_D, teeth=9)
    c.rivets([p(x, 0.302, z) for x in (-0.24, 0.24) for z in (12, 78)])


def broken_crank(c):
    p = c.p
    c.pipe([p(-0.4, 0.1, 20), p(0.05, 0.1, 20), p(0.05, 0.1, 90)], 11, IRON)
    c.pipe([p(0.2, -0.15, 20), p(0.45, -0.15, 20)], 11, IRON)
    x, y = p(-0.4, 0.1, 20)
    c.disc(x, y, 16 * c.ss, 16 * c.ss, IRON)


def tape(c):
    _, _, (tx, ty, rx, ry, _bx, _by) = c.cylinder(0, 0, 0.3, 0, 40, TAPE, spec=0.5, top_c=TAPE * 1.4)
    c.disc(tx, ty, rx * 0.5, ry * 0.5, hexc("#B07A42"), dome=False)


def crank(c):
    p = c.p
    c.pipe([p(-0.4, 0.1, 20), p(0.25, 0.1, 20), p(0.25, 0.1, 90)], 11, IRON)
    for u in (-0.05, 0.05, 0.15):
        c.stroke([p(u, 0.1, 10), p(u, 0.1, 30)], 9, TAPE)
    x, y = p(-0.4, 0.1, 20)
    c.disc(x, y, 16 * c.ss, 16 * c.ss, IRON)


def memory_chip(c):
    p = c.p
    c.box(-0.25, -0.25, 0.25, 0.25, 0, 16, hexc("#2F6F6A"), rim=0.7)
    for k in range(5):
        u = -0.2 + k * 0.1
        c.stroke([p(u, 0.25, 4), p(u, 0.38, 0)], 4, BRASS)
        c.stroke([p(0.25, u, 4), p(0.38, u, 0)], 4, BRASS)
    c.text("9", p(-0.08, 0.0, 17), p(0.08, 0.0, 17), 18, BRASS_L)


def debt_list(c):
    p = c.p
    c.box(-0.3, -0.4, 0.3, 0.4, 0, 4, PAPER, rim=0.4)
    for k in range(7):
        g = -0.3 + k * 0.08
        c.stroke([p(-0.22, g, 5), p(0.18, g, 5)], 2.0, INK, 0.6)
    x, y = p(0.12, 0.26, 5)
    c.disc(x, y, 26 * c.ss, 14 * c.ss, RED, dome=False)


def reading_glasses(c):
    p = c.p
    for u in (-0.16, 0.16):
        x, y = p(u, 0.0, 30)
        c.disc(x, y, 34 * c.ss, 26 * c.ss, PINK, dome=False)
        c.disc(x, y, 24 * c.ss, 17 * c.ss, hexc("#BFE3EA"), outline=1.0, dome=False)
    c.stroke([p(-0.06, 0.0, 34), p(0.06, 0.0, 34)], 5, PINK)


def love_letter(c):
    p = c.p
    c.box(-0.4, -0.26, 0.4, 0.26, 0, 6, hexc("#F4B6C2"), rim=0.5)
    c.stroke([p(-0.4, -0.26, 6), p(0.0, 0.0, 6), p(0.4, -0.26, 6)], 2.4, INK, 0.5)
    x, y = p(0.0, 0.03, 7)
    for dx in (-9, 9):
        c.disc(x + dx * c.ss, y - 4 * c.ss, 11 * c.ss, 9 * c.ss, RED, outline=1.0, dome=False)
    c.paint(c.mask_poly([(x - 19 * c.ss, y - 2 * c.ss), (x + 19 * c.ss, y - 2 * c.ss), (x, y + 18 * c.ss)]),
            c.flat(RED), outline=0)


def megaphone(c):
    p = c.p
    x0, y0 = p(-0.3, 0.0, 70)
    x1, y1 = p(0.35, 0.0, 70)
    s = c.ss
    cone = [(x0, y0 - 18 * s), (x1, y1 - 56 * s), (x1, y1 + 56 * s), (x0, y0 + 18 * s)]
    c.paint(c.mask_poly(cone), c.flat(RED), outline=1.0)
    c.disc(x1, y1, 22 * s, 56 * s, hexc("#F4E9D8"), outline=1.0, dome=False)
    c.disc(x1, y1, 12 * s, 34 * s, hexc("#3A2E2A"), dome=False)
    c.box(-0.42, -0.06, -0.28, 0.06, 50, 90, IRON, rim=0.6)
    c.pipe([p(-0.12, 0.0, 66), p(-0.14, 0.0, 30), p(-0.04, 0.0, 26)], 9, INK)
    c.text("ดอก", p(-0.05, -0.12, 70), p(0.2, -0.12, 70), 12, YELLOW)


def ring(c):
    p = c.p
    x, y = p(0.0, 0.0, 60)
    s = c.ss
    pts = []
    for k in range(25):
        a = 2 * math.pi * k / 24
        pts.append((x + math.cos(a) * 52 * s, y + math.sin(a) * 40 * s))
    c.stroke(pts, 14, YELLOW)
    c.stroke(pts[14:20], 5, hexc("#FFF2B0"), 0.8)
    c.disc(x, y - 44 * s, 16 * s, 14 * s, hexc("#9FE3F0"), spec=1.0)
    for dx, dy in ((-30, 30), (20, 34), (40, 10)):
        c.disc(x + dx * s, y + dy * s, 8 * s, 5 * s, hexc("#5B4636"), dome=False)


ITEMS = {f.__name__: f for f in (debt_book, gum, hanger, hook, float_key, air_remote, letter,
                                 sauce_packs, brass_box, broken_crank, tape, crank, memory_chip,
                                 debt_list, reading_glasses, love_letter, megaphone, ring)}


def render(name, out):
    c = _canvas(abs(hash(name)) % 1000)
    ITEMS[name](c)
    c.finish(out, sil=2.4)
    im = Image.open(out).convert("RGBA")
    box = im.getbbox()
    im = im.crop(box)
    k = min(1.0, (ICON - 16) / max(im.size))
    im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
    sq = Image.new("RGBA", (ICON, ICON), (0, 0, 0, 0))
    sq.paste(im, ((ICON - im.width) // 2, (ICON - im.height) // 2), im)
    sq.save(out)


if __name__ == "__main__":
    name = sys.argv[1]
    if name == "all":
        out_dir = sys.argv[2]
        os.makedirs(out_dir, exist_ok=True)
        for n in ITEMS:
            render(n, os.path.join(out_dir, n + ".png"))
            print("wrote", n)
    else:
        render(name, sys.argv[2])
        print("wrote", name)
