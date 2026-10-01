"""Painted PNG props, Thai street set (M2: "it must read as Bangkok").
win_stand, payphone, bus_stop, moo_ping_cart, shop_cat, tire_planter.
Run: python3 props_th.py <name> <out.png>   (or: all <dir>)"""
import math
import os
import sys

import numpy as np
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from paint import *  # noqa: E402,F401,F403

ORANGE = hexc("#F07A1E")
ORANGE_D = hexc("#B4520F")
NAVY = hexc("#1E3F8C")
TOT_BLUE = hexc("#2F6DB5")
YELLOW = hexc("#F2C230")
WHITE = hexc("#F2EFE6")
WOOD_L = hexc("#B07A42")
ZINC = hexc("#9AA4AA")
LEAF = hexc("#4F8A3C")
LEAF_D = hexc("#2F5E26")
SOIL = hexc("#4A3324")
CHAR = hexc("#2A2224")
EMBER = hexc("#FF7A2A")
TAN = hexc("#C9A46A")
GINGER = hexc("#E08A3C")
INK = hexc("#1E1A1F")


def vest(c, gx, gy, z_top, number):
    """Orange win (motorcycle-taxi) vest hanging on the rail, with its number."""
    p, s = c.p, c.ss
    w, hgt = 0.11, 92
    body = [p(gx - w, gy, z_top), p(gx - 0.03, gy, z_top - 6), p(gx, gy, z_top - 22),
            p(gx + 0.03, gy, z_top - 6), p(gx + w, gy, z_top), p(gx + w * 1.12, gy, z_top - hgt),
            p(gx - w * 1.12, gy, z_top - hgt)]
    m = c.mask_poly(body)
    y0 = min(q[1] for q in body)
    c.paint(m, c.grad(ORANGE, 1.12, 0.82, y0, y0 + hgt * s), 1.6, 0.5, tex=0.06)
    # reflective strip + number patch
    c.stroke([p(gx - w * 1.05, gy, z_top - 70), p(gx + w * 1.05, gy, z_top - 70)], 3.0, hexc("#D9DDE0"), 0.9)
    patch = [p(gx - 0.06, gy, z_top - 30), p(gx + 0.06, gy, z_top - 30), p(gx + 0.06, gy, z_top - 58),
             p(gx - 0.06, gy, z_top - 58)]
    c.paint(c.mask_poly(patch), c.flat(WHITE), 0.8, 0)
    c.text(number, p(gx - 0.06, gy, z_top - 30), p(gx + 0.06, gy, z_top - 30), 26, INK)
    # hanger hook
    hx, hy = p(gx, gy, z_top + 6)
    c.stroke([(hx, hy), (hx, hy - 6 * s)], 1.6, STEEL)


def win_stand(out):
    """วินมอเตอร์ไซค์: zinc roof on brass-banded posts, bench, rack of numbered
    orange vests, blue district sign, and the job board pinned to the post."""
    c = Canvas(420, 660, seed=41)
    p, s = c.p, c.ss
    c.ground_shadow(1.6, 0.6)
    # posts (back pair carries the vest rail, front pair the roof edge)
    for gx, gy in ((-0.74, -0.24), (0.74, -0.24)):
        c.pipe([p(gx, gy, 0), p(gx, gy, 334)], 9, STEEL * 0.8, spec=0.8)
        for z in (60, 200):
            bx, by = p(gx, gy, z)
            c.disc(bx, by, 6 * s, 3 * s, BRASS, 1.0, 0.3, dome=False)
    # copper steam pipe up the left post + gauge
    c.pipe([p(-0.68, -0.22, 0), p(-0.68, -0.22, 300), p(-0.4, -0.22, 316)], 6, COPPER, spec=0.7)
    gx_, gy_ = p(-0.68, -0.18, 130)
    c.gauge(gx_, gy_, 9)
    # vest rail + vests
    c.pipe([p(-0.74, -0.2, 244), p(0.74, -0.2, 244)], 5, BRASS, spec=1.0)
    for i, (gx, n) in enumerate(zip(np.linspace(-0.56, 0.56, 5), ["12", "07", "23", "31", "05"])):
        vest(c, gx, -0.19, 238, n)
    # wooden bench with steel legs, a helmet resting on it
    for gx in (-0.6, 0.6):
        for gy in (0.04, 0.26):
            c.pipe([p(gx, gy, 0), p(gx, gy, 44)], 4, STEEL * 0.7, spec=0.5)
    c.box(-0.68, 0.0, 0.68, 0.3, 44, 54, WOOD_L, rim=0.8)
    for k in range(1, 5):
        c.stroke([p(-0.68 + k * 0.27, 0.0, 54), p(-0.68 + k * 0.27, 0.3, 54)], 1.2, WOOD * 0.7, 0.7)
    hx, hy = p(0.32, 0.16, 54)
    c.disc(hx, hy - 12 * s, 17 * s, 15 * s, TEAL, 1.6, 0.6, spec=0.9)
    c.paint(c.mask_ellipse(hx + 4 * s, hy - 14 * s, 9 * s, 6 * s), c.flat(SOOT * 1.3), 1.0, 0)
    # job board on the right post: cork + pinned job slips + "บอร์ดงาน" header
    c.box(0.78, -0.2, 0.84, 0.24, 120, 230, WOOD * 0.9, rim=0.4)
    # +x face reads from +gy (screen left) to -gy (screen right/up)
    q0, q1 = p(0.84, 0.22, 226), p(0.84, -0.18, 226)
    c.text("บอร์ดงาน", q0, q1, 20, YELLOW)
    rng = np.random.default_rng(3)
    for k in range(5):
        gy0 = -0.16 + (k % 3) * 0.13
        z0 = 196 - (k // 3) * 40 - rng.uniform(0, 6)
        slip = [p(0.845, gy0, z0), p(0.845, gy0 + 0.11, z0 - 3), p(0.845, gy0 + 0.11, z0 - 32),
                p(0.845, gy0, z0 - 29)]
        c.paint(c.mask_poly(slip), c.flat(CREAM * (0.92 + 0.08 * rng.random())), 0.8, 0)
        for line in range(3):
            c.stroke([p(0.846, gy0 + 0.015, z0 - 9 - line * 7), p(0.846, gy0 + 0.09, z0 - 10 - line * 7)],
                     1.0, INK, 0.55)
        px_, py_ = p(0.846, gy0 + 0.055, z0 - 3)
        c.disc(px_, py_, 2.5 * s, 2.5 * s, RED, 0.6, 0)
    # corrugated zinc roof
    c.box(-0.86, -0.36, 0.86, 0.36, 334, 342, ZINC, rim=0.9, top_k=1.05)
    for k in range(18):
        gx = -0.84 + k * 0.1
        c.stroke([p(gx, -0.36, 342), p(gx, 0.36, 342)], 1.6, ZINC * 0.7, 0.6)
    # blue district sign on top: "วินซอยทองเหลือง" / "จุดจอดรถจักรยานยนต์รับจ้าง"
    c.box(-0.8, -0.03, 0.8, 0.03, 342, 420, NAVY, rim=0.6)
    c.text("วินซอยทองเหลือง", p(-0.74, 0.03, 414), p(0.74, 0.03, 414), 44, WHITE)
    c.text("จุดจอดรถจักรยานยนต์รับจ้าง", p(-0.7, 0.03, 368), p(0.7, 0.03, 368), 20, YELLOW)
    # brass steam whistle on the roof
    wx, wy = p(0.6, -0.2, 342)
    c.pipe([(wx, wy), (wx, wy - 22 * s)], 7, BRASS, spec=1.0)
    c.disc(wx, wy - 22 * s, 6 * s, 3 * s, BRASS_L, 1.0, 0.3)
    c.finish(out)


def payphone(out):
    """ตู้โทรศัพท์สาธารณะ: blue steel booth, glass panes, yellow top band, a
    brass coin phone inside."""
    c = Canvas(240, 600, seed=42)
    p, s = c.p, c.ss
    c.ground_shadow(0.55, 0.55)
    c.box(-0.26, -0.26, 0.26, 0.26, 0, 8, SOOT * 1.6, rim=0.3)
    mf, ms, _ = c.box(-0.25, -0.25, 0.25, 0.25, 8, 300, TOT_BLUE, rim=0.8)
    # phone inside, seen through the front glass
    ph = [p(-0.08, 0.25, 200), p(0.1, 0.25, 200), p(0.1, 0.25, 140), p(-0.08, 0.25, 140)]
    c.paint(c.mask_poly(ph), c.grad(BRASS, 1.15, 0.8), 1.4, 0.6)
    hx0, hy0 = p(-0.06, 0.25, 192)
    c.pipe([(hx0, hy0), (hx0, hy0 + 40 * s)], 6, SOOT * 1.3, spec=0.6)
    c.stroke([p(0.0, 0.25, 186), p(0.08, 0.25, 186)], 2.0, SOOT, 0.8)
    for r in range(3):
        for col in range(3):
            bx, by = p(0.0 + col * 0.03, 0.25, 176 - r * 9)
            c.disc(bx, by, 2 * s, 2 * s, CREAM, 0.5, 0)
    # coiled cord
    c.stroke([p(-0.06, 0.25, 160 + 4 * math.sin(k)) for k in np.linspace(0, 12, 20)], 1.4, SOOT, 0.8)
    # glass panes (front + side) with reflections
    for face, lo, hi in (("front", -0.21, 0.21), ("side", -0.21, 0.21)):
        if face == "front":
            g = [p(lo, 0.25, 40), p(hi, 0.25, 40), p(hi, 0.25, 270), p(lo, 0.25, 270)]
        else:
            g = [p(0.25, hi, 40), p(0.25, lo, 40), p(0.25, lo, 270), p(0.25, hi, 270)]
        m = c.mask_poly(g)
        c.glaze(m, hexc("#9FD3E0"), 0.28)
        c.ink_ring(m, 1.2)
        x0, y0 = g[0]
        x1, y1 = g[3]
        c.stroke([(x0 + 8 * s, y0 - 30 * s), (x1 + 18 * s, y1 + 20 * s)], 5.0, WHITE, 0.25)
    # yellow band + roof cap + text
    c.box(-0.27, -0.27, 0.27, 0.27, 300, 336, YELLOW, rim=0.8)
    c.text("โทรศัพท์", p(-0.25, 0.27, 332), p(0.25, 0.27, 332), 28, NAVY)
    c.text("สาธารณะ", p(0.27, 0.25, 332), p(0.27, -0.25, 332), 28, NAVY)
    c.box(-0.29, -0.29, 0.29, 0.29, 336, 346, TOT_BLUE * 0.8, rim=0.8)
    # steampunk: copper line running up the side + brass coin sign
    c.pipe([p(0.26, -0.18, 8), p(0.26, -0.18, 300)], 5, COPPER, spec=0.7)
    sx, sy = p(0.0, 0.26, 222)
    c.disc(sx, sy, 15 * s, 9 * s, BRASS_L, 1.2, 0.4, dome=False)
    c.text("1 บาท", (sx - 13 * s, sy - 7 * s), (sx + 13 * s, sy - 7 * s), 13, INK)
    c.finish(out)


def bus_stop(out):
    """ป้ายรถเมล์: blue plate on a steel pole with the route numbers."""
    c = Canvas(240, 600, seed=43)
    p, s = c.p, c.ss
    c.ground_shadow(0.35, 0.35)
    c.cylinder(0, 0, 0.09, 0, 10, CONCRETE if "CONCRETE" in globals() else STEEL * 0.6, spec=0.2)
    c.pipe([p(0, 0, 0), p(0, 0, 360)], 8, STEEL * 0.85, spec=0.9)
    c.box(-0.36, -0.02, 0.36, 0.02, 250, 352, NAVY, rim=0.7)
    c.text("ป้ายหยุดรถประจำทาง", p(-0.33, 0.02, 346), p(0.33, 0.02, 346), 20, WHITE)
    c.text("BUS STOP", p(-0.2, 0.02, 322), p(0.2, 0.02, 322), 12, YELLOW)
    strip = [p(-0.32, 0.021, 304), p(0.32, 0.021, 304), p(0.32, 0.021, 258), p(-0.32, 0.021, 258)]
    c.paint(c.mask_poly(strip), c.flat(WHITE), 0.8, 0)
    c.text("8   73   503", p(-0.3, 0.022, 300), p(0.3, 0.022, 300), 36, RED)
    # brass cap + a steam-era timetable plate further down
    tx, ty = p(0, 0, 360)
    c.disc(tx, ty, 7 * s, 4 * s, BRASS, 1.0, 0.4)
    c.box(-0.12, 0.0, 0.12, 0.03, 150, 210, BRASS, rim=0.7)
    c.text("มาเมื่อมา", p(-0.11, 0.03, 196), p(0.11, 0.03, 196), 18, INK)
    c.finish(out)


def moo_ping_cart(out):
    """หมูปิ้ง: steel cart, charcoal grill with skewers and embers, sticky-rice
    basket, hand fan, smoke, price sign."""
    c = Canvas(380, 520, seed=44)
    p, s = c.p, c.ss
    c.ground_shadow(1.0, 0.6)
    c.wheel(-0.32, 0.29, 26, 0.14, 26, spokes=True)
    c.box(-0.5, -0.28, 0.5, 0.28, 34, 112, STEEL * 0.95, rim=0.8)
    c.wheel(0.32, 0.29, 26, 0.14, 26, spokes=True)
    # price sign on the front
    c.paint(c.mask_poly([p(-0.4, 0.281, 100), p(0.1, 0.281, 100), p(0.1, 0.281, 60), p(-0.4, 0.281, 60)]),
            c.flat(YELLOW), 1.0, 0)
    c.text("หมูปิ้ง 10.-", p(-0.38, 0.282, 98), p(0.08, 0.282, 98), 34, RED)
    # charcoal grill trough with glowing embers
    c.box(-0.46, -0.24, 0.12, 0.24, 112, 128, CHAR, rim=0.3)
    em = c.mask_poly([p(-0.42, -0.2, 128), p(0.08, -0.2, 128), p(0.08, 0.2, 128), p(-0.42, 0.2, 128)])
    c.glaze(em, EMBER, 0.6)
    c.glaze(ndimage.gaussian_filter(em, 6 * s), hexc("#FFD27A"), 0.25)
    for k in range(9):
        gx = -0.4 + k * 0.06
        c.stroke([p(gx, -0.21, 130), p(gx, 0.21, 130)], 1.0, STEEL, 0.8)
    # skewers of grilled pork
    for k in range(7):
        gx = -0.38 + k * 0.07
        c.stroke([p(gx, 0.26, 134), p(gx, -0.18, 134)], 1.2, WOOD_L)
        for j in range(3):
            mx, my = p(gx, 0.14 - j * 0.11, 136)
            c.disc(mx, my, 6 * s, 4 * s, hexc("#8E3B1E"), 0.8, 0.4, spec=0.8)
    # sticky rice basket (กระติ๊บ) + lid
    c.cylinder(0.3, 0.0, 0.11, 112, 156, TAN, spec=0.2, rim=0.4)
    for z in range(118, 156, 8):
        bx, by = p(0.3, 0.0, z)
        c.stroke([(bx - 14 * s, by), (bx + 14 * s, by)], 1.0, TAN * 0.7, 0.6)
    c.frustum(0.12, 0.05, 156, 172, TAN * 0.9, cx=0.3, cy=0.0)
    # hand fan resting on the cart
    fx, fy = p(0.25, 0.22, 112)
    c.disc(fx, fy - 8 * s, 14 * s, 8 * s, hexc("#D8C48E"), 1.0, 0.3, dome=False)
    c.stroke([(fx, fy - 8 * s), (fx + 12 * s, fy + 2 * s)], 2.0, WOOD)
    # smoke
    sx, sy = p(-0.16, 0.0, 132)
    smoke = np.zeros_like(c.a)
    for k in range(10):
        t = k / 9
        m = c.mask_ellipse(sx + 18 * s * math.sin(t * 3.0), sy - 150 * s * t, (14 + 22 * t) * s, (10 + 14 * t) * s)
        smoke = np.maximum(smoke, m * (0.5 - 0.35 * t))
    smoke = ndimage.gaussian_filter(smoke, 8 * s)
    c.rgb = c.rgb * (1 - smoke[..., None]) + hexc("#D8D4CC")[None, None, :] * smoke[..., None]
    c.a = np.maximum(c.a, smoke)
    # brass handlebar
    c.pipe([p(-0.5, -0.25, 100), p(-0.62, -0.25, 112), p(-0.62, 0.25, 112), p(-0.5, 0.25, 100)], 5, BRASS)
    c.finish(out)


def shop_cat(out):
    """แมวร้านชำ: fat ginger cat asleep on a stack of red/yellow soda crates."""
    c = Canvas(240, 440, seed=45)
    p, s = c.p, c.ss
    c.ground_shadow(0.6, 0.6)
    for z0, col in ((0, RED), (58, YELLOW)):
        mf, ms, mt = c.box(-0.28, -0.28, 0.28, 0.28, z0, z0 + 58, col, rim=0.7)
        for k in range(1, 4):
            gx = -0.28 + k * 0.14
            c.stroke([p(gx, 0.28, z0 + 8), p(gx, 0.28, z0 + 50)], 2.4, col * 0.6, 0.7)
            c.stroke([p(0.28, gx, z0 + 8), p(0.28, gx, z0 + 50)], 2.4, col * 0.6, 0.7)
    c.text("น้ำแดง", p(-0.24, 0.281, 108), p(0.24, 0.281, 108), 20, WHITE)
    # bottle caps peeking out of the top crate
    for gx in (-0.16, 0.0, 0.16):
        for gy in (-0.16, 0.0, 0.16):
            bx, by = p(gx, gy, 118)
            c.disc(bx, by, 5 * s, 3 * s, STEEL, 0.6, 0.2, spec=0.8)
    # the cat
    cx, cy = p(0.0, 0.02, 126)
    body = c.mask_ellipse(cx, cy - 12 * s, 42 * s, 20 * s)
    c.paint(body, c.cyl_field(GINGER, cx, 42 * s, 0.3), 1.8, 0.7, tex=0.1)
    for k in range(4):
        c.stroke([(cx - 24 * s + k * 14 * s, cy - 30 * s), (cx - 20 * s + k * 14 * s, cy - 14 * s)], 3.0, ORANGE_D, 0.7)
    hx, hy = cx - 38 * s, cy - 16 * s
    c.disc(hx, hy, 18 * s, 15 * s, GINGER, 1.6, 0.7, spec=0.2)
    for ex in (-12, 4):
        c.paint(c.mask_poly([(hx + ex * s, hy - 10 * s), (hx + (ex + 8) * s, hy - 12 * s), (hx + (ex + 3) * s, hy - 26 * s)]),
                c.flat(GINGER * 0.95), 1.2, 0.5)
    for ex in (-8, 6):
        c.stroke([(hx + ex * s - 4 * s, hy), (hx + ex * s, hy + 2 * s), (hx + ex * s + 4 * s, hy)], 1.4, INK)
    c.disc(hx - 1 * s, hy + 6 * s, 2.5 * s, 2 * s, hexc("#E7838A"), 0.5, 0)
    for k in (-1, 1):
        c.stroke([(hx - 6 * s, hy + 6 * s), (hx - 22 * s, hy + 4 * s + k * 3 * s)], 0.8, WHITE, 0.8)
    tail = [(cx + 38 * s, cy - 10 * s), (cx + 52 * s, cy - 2 * s), (cx + 44 * s, cy + 10 * s), (cx + 20 * s, cy + 8 * s)]
    c.stroke(tail, 7.0, GINGER * 0.9)
    c.stroke(tail, 1.2, ORANGE_D, 0.5)
    # "Z" for the sleeping cat
    c.text("z", (hx - 10 * s, hy - 52 * s), (hx + 6 * s, hy - 52 * s), 16, WHITE, 0.8)
    c.finish(out)


def tire_planter(out):
    """ยางรถยนต์ทาสีปลูกต้นไม้: two painted tyres stacked, zig-zag top, basil
    and red ixora flowers."""
    c = Canvas(220, 400, seed=46)
    p, s = c.p, c.ss
    c.ground_shadow(0.6, 0.6)
    c.cylinder(0, 0, 0.28, 0, 44, WHITE * 0.92, spec=0.3, rim=0.5)
    c.band(0, 0, 0.28, 18, 26, RED * 0.95, spec=0.4)
    c.cylinder(0, 0, 0.25, 44, 84, RED, spec=0.3, rim=0.5)
    tx, ty = p(0, 0, 84)
    rx, ry = 0.25 * 128 * s, 0.25 * 64 * s
    # zig-zag cut rim
    pts = []
    for k in range(25):
        a = math.pi * k / 24
        r = 1.0 if k % 2 == 0 else 0.86
        pts.append((tx - math.cos(a) * rx * r, ty + math.sin(a) * ry * r - (6 * s if k % 2 == 0 else 0)))
    c.stroke(pts, 2.2, WHITE, 0.9)
    soil = c.mask_ellipse(tx, ty, rx * 0.82, ry * 0.82)
    c.paint(soil, c.flat(SOIL), 1.2, 0, tex=0.2)
    rng = np.random.default_rng(9)
    for k in range(14):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0, 0.6)
        bx, by = tx + math.cos(a) * rx * r, ty + math.sin(a) * ry * r
        h = rng.uniform(40, 90) * s
        c.stroke([(bx, by), (bx + rng.uniform(-10, 10) * s, by - h)], 2.0, LEAF_D)
        lx, ly = bx + rng.uniform(-10, 10) * s, by - h
        c.disc(lx, ly, rng.uniform(7, 11) * s, rng.uniform(4, 6) * s, LEAF, 1.0, 0.4, spec=0.3)
    for k in range(5):
        a = rng.uniform(0, 2 * math.pi)
        fx, fy = tx + math.cos(a) * rx * 0.4, ty - rng.uniform(60, 95) * s
        for j in range(4):
            c.disc(fx + math.cos(j * 1.57) * 4 * s, fy + math.sin(j * 1.57) * 3 * s, 3.2 * s, 3.2 * s, RED, 0.5, 0.2)
    c.finish(out)


def longtail_boat(out):
    """เรือหางยาวไอน้ำ: long narrow hull along gx (bow at +gx), three-colour
    ribbons on the raised bow, garland, plank seats, brass boiler at the stern
    and the long-tail propeller shaft."""
    c = Canvas(640, 500, seed=47)
    p, s = c.p, c.ss
    # dark water shadow + foam
    cx, cy = p(0, 0, 0)
    c.a = np.maximum(c.a, ndimage.gaussian_filter(c.mask_ellipse(cx, cy + 6 * s, 230 * s, 70 * s), 10 * s) * 0.3)
    hull = [(-1.5, -0.22), (0.9, -0.3), (1.5, 0.0), (0.9, 0.3), (-1.5, 0.22)]
    c.prism(hull, -12, 34, hexc("#5A3A22"), top_c=hexc("#3A2618"), rim=0.8, smooth=True)
    # painted stripes on the visible (+y, +x) sides
    for z, col in ((26, hexc("#E8E1CF")), (18, hexc("#C0392B")), (12, hexc("#2F5FD0"))):
        c.stroke([p(-1.5, 0.22, z), p(0.9, 0.3, z), p(1.5, 0.0, z)], 2.6, col, 0.95)
    for gx in (-0.9, -0.4, 0.1, 0.6):
        c.box(gx - 0.05, -0.22, gx + 0.05, 0.22, 24, 30, WOOD_L, rim=0.5)
    # raised bow post + ribbons + garland
    bx, by = p(1.5, 0.0, 34)
    tip = (bx + 34 * s, by - 60 * s)
    c.stroke([(bx, by), (bx + 18 * s, by - 34 * s), tip], 9, hexc("#5A3A22"))
    for k, col in enumerate((hexc("#E66AA0"), YELLOW, hexc("#3FAE5A"))):
        rib = [(tip[0] - 2 * s, tip[1] + (4 + k * 5) * s), (tip[0] - 30 * s - k * 6 * s, tip[1] + (30 + k * 10) * s),
               (tip[0] - 14 * s - k * 4 * s, tip[1] + (44 + k * 12) * s)]
        c.stroke(rib, 5.0, col, 0.95)
    for k in range(7):
        t = k / 6
        gx_, gy_ = tip[0] - 6 * s - t * 20 * s, tip[1] + 10 * s + math.sin(t * math.pi) * 14 * s
        c.disc(gx_, gy_, 4 * s, 4 * s, hexc("#F39C1E") if k % 2 == 0 else WHITE, 0.6, 0.3)
    # stern boiler + chimney + gauge
    c.cylinder(-1.25, 0.0, 0.14, 30, 104, BRASS, spec=1.0)
    for z in (50, 84):
        c.band(-1.25, 0.0, 0.14, z, z + 5, COPPER)
    hx, hy = p(-1.25, 0.0, 104)
    c.pipe([(hx, hy), (hx, hy - 40 * s)], 8, STEEL * 0.8)
    gx_, gy_ = p(-1.25, 0.15, 70)
    c.gauge(gx_, gy_, 8)
    # long tail: shaft from the engine down-back into the water + propeller
    a, b = p(-1.4, 0.0, 70), p(-2.3, 0.0, -6)
    c.pipe([a, b], 7, STEEL * 0.9, spec=0.9)
    c.gear(b[0], b[1], 13 * s, BRASS, teeth=3, flat=0.2, hole=0.3, outline=1.2)
    c.stroke([(b[0] - 20 * s, b[1] + 8 * s), (b[0] + 16 * s, b[1] + 12 * s)], 3, hexc("#CFE8E2"), 0.6)
    # foam along the hull
    c.stroke([p(-1.4, 0.26, -10), p(0.9, 0.34, -10), p(1.55, 0.02, -10)], 3.0, hexc("#CFE8E2"), 0.55)
    c.finish(out)


def dragon_jar(out):
    """โอ่งมังกร (Ratchaburi dragon jar): glazed brown jar, yellow dragon,
    wooden lid with a coconut-shell dipper."""
    c = Canvas(220, 420, seed=48)
    p, s = c.p, c.ss
    c.ground_shadow(0.6, 0.6)
    bx, by = p(0, 0, 0)
    body = np.maximum(c.mask_ellipse(bx, by - 62 * s, 62 * s, 62 * s), c.mask_ellipse(bx, by - 6 * s, 36 * s, 12 * s))
    glaze = hexc("#6E3B1E")
    c.paint(body, c.cyl_field(glaze, bx, 62 * s, 1.0, spec_col=hexc("#FFE6B0")), 2.2, 0.6, tex=0.05)
    # shoulder band + dragon
    c.stroke([(bx - 52 * s, by - 96 * s), (bx + 52 * s, by - 96 * s)], 3.0, hexc("#D9A441"), 0.9)
    pts = [(bx - 44 * s + k * 8 * s, by - 62 * s + 14 * s * math.sin(k * 0.9)) for k in range(12)]
    c.stroke(pts, 7.0, hexc("#E8B13A"))
    c.stroke(pts, 1.4, hexc("#7A4A12"), 0.8)
    hx_, hy_ = pts[-1]
    c.disc(hx_ + 4 * s, hy_ - 2 * s, 9 * s, 7 * s, hexc("#E8B13A"), 1.2, 0.4)
    c.disc(hx_ + 7 * s, hy_ - 4 * s, 1.6 * s, 1.6 * s, INK, 0.3, 0)
    for k in range(5):
        x, y = pts[k * 2 + 1]
        c.disc(x, y - 6 * s, 2.2 * s, 2.2 * s, hexc("#7A4A12"), 0.3, 0)
    # mouth + wooden lid + coconut dipper
    c.disc(bx, by - 120 * s, 36 * s, 12 * s, glaze * 0.8, 1.6, 0.4, dome=False)
    c.disc(bx, by - 124 * s, 40 * s, 13 * s, WOOD_L, 1.6, 0.6, dome=False)
    c.disc(bx + 8 * s, by - 132 * s, 14 * s, 9 * s, hexc("#6B4A2A"), 1.2, 0.5, spec=0.5)
    c.stroke([(bx + 18 * s, by - 134 * s), (bx + 44 * s, by - 146 * s)], 3.0, WOOD)
    c.finish(out)


def pier_sign(out):
    """ป้ายท่าเรือ: white board on two posts + orange express-boat flag."""
    c = Canvas(260, 560, seed=49)
    p, s = c.p, c.ss
    c.ground_shadow(0.6, 0.2)
    for gx in (-0.26, 0.26):
        c.pipe([p(gx, 0, 0), p(gx, 0, 250)], 7, STEEL * 0.8, spec=0.8)
    c.box(-0.34, -0.02, 0.34, 0.02, 170, 270, WHITE, rim=0.6)
    c.text("ท่าเรือ", p(-0.3, 0.02, 264), p(0.3, 0.02, 264), 40, NAVY)
    c.text("คลองไอน้ำ", p(-0.3, 0.02, 222), p(0.3, 0.02, 222), 30, NAVY)
    c.text("เรือออกเมื่อคนเต็ม", p(-0.3, 0.02, 190), p(0.3, 0.02, 190), 14, RED)
    fx, fy = p(0.3, 0, 270)
    c.pipe([(fx, fy), (fx, fy - 120 * s)], 4, BRASS)
    c.paint(c.mask_poly([(fx, fy - 120 * s), (fx + 64 * s, fy - 104 * s), (fx, fy - 82 * s)]), c.flat(ORANGE), 1.4, 0.5)
    c.finish(out)


PROPS = {f.__name__: f for f in (win_stand, payphone, bus_stop, moo_ping_cart, shop_cat, tire_planter,
                                 longtail_boat, dragon_jar, pier_sign)}

if __name__ == "__main__":
    name = sys.argv[1]
    if name == "all":
        out_dir = sys.argv[2]
        for n, f in PROPS.items():
            f(os.path.join(out_dir, n + ".png"))
            print("wrote", n)
    else:
        PROPS[name](sys.argv[2])
        print("wrote", name)
