"""Painted PNG props, part A: spirit_house, power_pole, water_tank, stool_a/b.
Run: python3 props_a.py <name> <out.png>"""
import math, sys
import numpy as np
from paint import *

RED_D = hexc("#7E2219")
GOLD = hexc("#E2B84E")
WHITE = hexc("#F2EFE6")
MARIGOLD = hexc("#F39C1E")
CONCRETE = hexc("#8C8580")


def spirit_house(out):
    c = Canvas(220, 520, seed=21)
    p, s = c.p, c.ss
    c.ground_shadow(0.7, 0.7)
    # steel post on a small footing
    c.cylinder(0, 0, 0.13, 0, 10, SOOT * 1.5, spec=0.3)
    c.cylinder(0, 0, 0.065, 10, 140, STEEL * 0.7, spec=0.9)
    for z in (40, 100):
        c.band(0, 0, 0.065, z, z + 6, BRASS)
    # brass platform with gold rail
    c.box(-0.32, -0.32, 0.32, 0.32, 140, 156, BRASS * 0.85, rim=0.9)
    c.rivets([p(gx, 0.32, 148) for gx in np.linspace(-0.26, 0.26, 5)], 2.0)
    # house body
    c.box(-0.24, -0.24, 0.24, 0.24, 156, 236, BRASS, rim=0.9)
    # columns at the front corners
    for gx in (-0.24, 0.24):
        c.pipe([p(gx, 0.25, 158), p(gx, 0.25, 234)], 5, GOLD, spec=1.0)
    # dark doorway with a turning copper gear inside
    door = [p(-0.15, 0.24, 162), p(0.15, 0.24, 162), p(0.15, 0.24, 218), p(-0.15, 0.24, 218)]
    c.paint(c.mask_poly(door), c.grad(SOOT, 1.0, 0.7), 1.4, 0)
    dx, dy = p(0.0, 0.24, 190)
    c.glaze(ndimage.gaussian_filter(c.mask_ellipse(dx, dy, 16 * s, 18 * s), 4 * s), hexc("#FFB347"), 0.35)
    c.gear(dx, dy, 15 * s, COPPER, teeth=8, flat=0.95, hole=0.3, outline=1.2)
    c.disc(dx, dy, 3 * s, 3 * s, BRASS_L, 0.6, 0)
    # arched door frame
    c.stroke([p(-0.15, 0.24, 162), p(-0.15, 0.24, 218), p(0.0, 0.24, 228), p(0.15, 0.24, 218), p(0.15, 0.24, 162)], 2.4, GOLD)
    # side window (+x face)
    win = [p(0.24, -0.1, 186), p(0.24, 0.1, 186), p(0.24, 0.1, 212), p(0.24, -0.1, 212)]
    c.paint(c.mask_poly(win), c.flat(SOOT * 1.2), 1.2, 0)
    # tiered red roof with gold trim
    c.frustum(0.34, 0.27, 236, 252, RED, rim=0.9)
    c.stroke([p(-0.34, 0.34, 236), p(0.34, 0.34, 236), p(0.34, -0.34, 236)], 2.2, GOLD)
    c.frustum(0.26, 0.17, 252, 276, RED_D * 1.2, rim=0.9)
    c.stroke([p(-0.26, 0.26, 252), p(0.26, 0.26, 252), p(0.26, -0.26, 252)], 2.0, GOLD)
    c.frustum(0.16, 0.0, 276, 318, RED, rim=1.0)
    # gold spire
    sx, sy = p(0, 0, 314)
    c.paint(c.mask_poly([(sx - 6 * s, sy), (sx + 6 * s, sy), (sx, sy - 34 * s)]), c.grad(GOLD, 1.3, 0.8, sy - 34 * s, sy), 1.4, 0.8)
    c.disc(sx, sy - 6 * s, 5 * s, 4 * s, GOLD, 1.0, 0.4, spec=1.0)
    # chofa horns on the lowest roof corners
    for gx, gy in ((-0.34, 0.34), (0.34, 0.34), (0.34, -0.34)):
        x, y = p(gx, gy, 238)
        c.stroke([(x, y), (x - 2 * s, y - 10 * s), (x + 3 * s, y - 16 * s)], 2.4, GOLD)
    # tiny copper chimney on the roof
    cx_, cy_ = p(0.14, -0.14, 268)
    c.pipe([(cx_, cy_), (cx_, cy_ - 30 * s)], 6, COPPER)
    c.disc(cx_, cy_ - 30 * s, 5 * s, 2.5 * s, SOOT * 1.4, 1.0, 0, dome=False)
    # marigold + jasmine garland draped over the doorway
    pts = [p(-0.17, 0.25, 226 - 18 * math.sin(math.pi * t)) for t in np.linspace(0, 1, 9)]
    for i, (x, y) in enumerate(pts):
        c.disc(x, y, 4 * s, 4 * s, MARIGOLD if i % 2 == 0 else WHITE, 0.8, 0.3, spec=0.3)
    # offerings on the platform: red soda bottles with straws, a small vase
    for gx in (-0.22, 0.2):
        bx, by = p(gx, 0.29, 156)
        m = np.maximum(c.mask_poly([(bx - 3 * s, by), (bx + 3 * s, by), (bx + 3 * s, by - 13 * s), (bx - 3 * s, by - 13 * s)]),
                       c.mask_ellipse(bx, by, 3 * s, 1.5 * s))
        c.paint(m, c.cyl_field(hexc("#D62B2B"), bx, 3 * s, 0.9), 1.0, 0.3)
        c.stroke([(bx, by - 13 * s), (bx + 3 * s, by - 22 * s)], 1.0, WHITE)
    vx, vy = p(0.0, 0.3, 156)
    c.disc(vx, vy - 4 * s, 5 * s, 5 * s, CREAM, 1.0, 0.3, spec=0.6)
    c.stroke([(vx, vy - 8 * s), (vx - 2 * s, vy - 20 * s)], 1.2, hexc("#4F8A3C"))
    c.disc(vx - 2 * s, vy - 21 * s, 3 * s, 3 * s, MARIGOLD, 0.6, 0.2)
    c.finish(out)


def power_pole(out):
    c = Canvas(160, 880, seed=22)
    p, s = c.p, c.ss
    c.ground_shadow(0.35, 0.35)
    TOP = 690
    c.cylinder(0, 0, 0.11, 0, 16, CONCRETE * 0.7, spec=0.2)
    # tapered concrete shaft: stack of short cylinders
    n = 12
    for i in range(n):
        z0 = 16 + (TOP - 16) * i / n
        z1 = 16 + (TOP - 16) * (i + 1) / n + 1
        r = 0.085 - 0.03 * i / n
        c.cylinder(0, 0, r, z0, z1, CONCRETE, spec=0.15, rim=0.5, outline=0.0, tex=0.12)
    bx, by = p(0, 0, 0)
    tx, ty = p(0, 0, TOP)
    shaft = c.mask_poly([(bx - 0.085 * 128 * s, by), (bx + 0.085 * 128 * s, by), (tx + 0.055 * 128 * s, ty), (tx - 0.055 * 128 * s, ty)])
    c.ink_ring(shaft, 2.2)
    # grime + stickers band (blank coloured paper, no text)
    for z, col in ((150, hexc("#E8E1C9")), (172, hexc("#D9C46A")), (196, hexc("#B9D3D0"))):
        x, y = p(0, 0, z)
        c.paint(c.mask_poly([(x - 9 * s, y), (x + 5 * s, y + 2 * s), (x + 5 * s, y - 14 * s), (x - 9 * s, y - 16 * s)]), c.flat(col), 0.8, 0)
    c.glaze(ndimage.gaussian_filter(c.mask_poly([(bx - 12 * s, by), (bx + 12 * s, by), (bx + 12 * s, by - 90 * s), (bx - 12 * s, by - 90 * s)]), 10 * s) * shaft, SOOT, 0.35)
    # cross arms with insulators (along grid x)
    for z in (TOP - 30, TOP - 82):
        c.box(-0.44, -0.035, 0.44, 0.035, z - 8, z, SOOT * 1.5, rim=0.6, outline=1.6)
        for gx in (-0.38, -0.14, 0.14, 0.38):
            x, y = p(gx, 0, z)
            c.disc(x, y - 6 * s, 4.5 * s, 3 * s, CREAM, 1.0, 0.3, spec=0.6)
            c.disc(x, y - 11 * s, 3.5 * s, 2.5 * s, CREAM, 1.0, 0.3, spec=0.6)
    # tangled cables: sagging loops between the insulators and around the pole
    rng = np.random.default_rng(3)
    for i in range(9):
        za = TOP - 36 - rng.uniform(0, 60)
        a = p(-0.45, rng.uniform(-0.1, 0.1), za)
        b = p(0.45, rng.uniform(-0.1, 0.1), za + rng.uniform(-20, 20))
        sag = rng.uniform(15, 70) * s
        pts = []
        for t in np.linspace(0, 1, 20):
            x = a[0] + (b[0] - a[0]) * t
            y = a[1] + (b[1] - a[1]) * t + 4 * sag * t * (1 - t) / 1.0 * 0.5
            pts.append((x, y))
        c.stroke(pts, 1.6, (0.08, 0.07, 0.08), 0.95)
    # coil of spare cable on the pole
    cx_, cy_ = p(0, 0, TOP - 200)
    for k in range(4):
        m = np.clip(c.mask_ellipse(cx_, cy_ + k * 3 * s, 16 * s, 8 * s) - c.mask_ellipse(cx_, cy_ + k * 3 * s, 13.5 * s, 6 * s), 0, 1)
        c.paint(m, c.flat((0.1, 0.09, 0.1)), 0.0, 0)
    # brass transformer can on a bracket
    c.pipe([p(0.0, 0.0, TOP - 140), p(0.16, 0.0, TOP - 140)], 5, SOOT * 1.5)
    c.cylinder(0.22, 0.0, 0.075, TOP - 205, TOP - 125, BRASS, spec=1.0, rim=0.8)
    c.band(0.22, 0.0, 0.075, TOP - 190, TOP - 184, COPPER)
    c.band(0.22, 0.0, 0.075, TOP - 148, TOP - 142, COPPER)
    for gx in (0.19, 0.25):
        x, y = p(gx, 0.0, TOP - 125)
        c.disc(x, y - 4 * s, 3 * s, 2.5 * s, CREAM, 0.8, 0.2)
    # street lamp: arm + brass lantern with a warm glow
    c.pipe([p(0, 0, TOP - 260), p(0, 0.3, TOP - 252), p(0, 0.36, TOP - 262)], 5, SOOT * 1.6, spec=0.5)
    lx, ly = p(0, 0.36, TOP - 262)
    c.glaze(ndimage.gaussian_filter(c.mask_ellipse(lx, ly + 18 * s, 30 * s, 30 * s), 10 * s), hexc("#FFD27A"), 0.25)
    c.paint(c.mask_poly([(lx - 11 * s, ly), (lx + 11 * s, ly), (lx + 8 * s, ly + 26 * s), (lx - 8 * s, ly + 26 * s)]),
            c.grad(BRASS, 1.2, 0.85, ly, ly + 26 * s, lx - 11 * s, lx + 11 * s, 0.3), 1.6, 0.8)
    glass = c.mask_poly([(lx - 7 * s, ly + 4 * s), (lx + 7 * s, ly + 4 * s), (lx + 5 * s, ly + 22 * s), (lx - 5 * s, ly + 22 * s)])
    c.paint(glass, c.grad(hexc("#FFF2B0"), 1.1, 0.95), 0.6, 0)
    c.disc(lx, ly - 2 * s, 12 * s, 4 * s, BRASS * 0.9, 1.4, 0.5, dome=False)
    # pole cap
    c.disc(tx, ty, 0.06 * 128 * s, 0.06 * 64 * s + 2 * s, CONCRETE * 0.9, 1.6, 0.6, dome=False)
    c.finish(out)


def water_tank(out):
    c = Canvas(300, 600, seed=23)
    p, s = c.p, c.ss
    c.ground_shadow(1.0, 1.0)
    legs = ((-0.36, -0.36), (0.36, -0.36), (0.36, 0.36), (-0.36, 0.36))
    for gx, gy in legs[:1]:
        c.pipe([p(gx, gy, 0), p(gx, gy, 142)], 8, SOOT * 1.7, spec=0.5)
    # cross braces (back)
    c.stroke([p(-0.36, -0.36, 20), p(0.36, -0.36, 120)], 3, SOOT * 1.4)
    c.stroke([p(-0.36, -0.36, 20), p(-0.36, 0.36, 120)], 3, SOOT * 1.4)
    for gx, gy in legs[1:]:
        c.pipe([p(gx, gy, 0), p(gx, gy, 142)], 8, SOOT * 1.8, spec=0.5)
        x, y = p(gx, gy, 0)
        c.disc(x, y, 9 * s, 4.5 * s, SOOT * 1.4, 1.2, 0.2, dome=False)
    c.stroke([p(-0.36, 0.36, 20), p(0.36, 0.36, 120)], 3, SOOT * 1.8)
    c.stroke([p(0.36, 0.36, 20), p(0.36, -0.36, 120)], 3, SOOT * 1.8)
    # wooden platform
    c.box(-0.46, -0.46, 0.46, 0.46, 142, 158, WOOD, rim=0.7)
    for gx in np.linspace(-0.3, 0.3, 4):
        c.stroke([p(gx, 0.46, 143), p(gx, 0.46, 157)], 1.0, WOOD * 0.6, 0.8)
    # copper tank
    R = 0.41
    c.cylinder(0, 0, R, 158, 356, COPPER, spec=0.9, rim=0.7, top_c=COPPER * 1.04)
    # vertical seam rivets
    for z in np.linspace(176, 340, 9):
        tx, ty = p(0, 0, z)
        c.disc(tx - R * 128 * s * 0.55, ty + R * 64 * s * 0.83, 2.2 * s, 2.2 * s, BRASS, 0.8, 0, spec=1.0)
    for z in (196, 300):
        c.band(0, 0, R, z, z + 12, BRASS, spec=1.0)
        tx, ty = p(0, 0, z + 6)
        c.rivets([(tx + math.cos(t) * R * 128 * s, ty + math.sin(t) * R * 64 * s) for t in np.linspace(0.35, math.pi - 0.35, 7)], 2.3)
    # top hatch + vent
    hx, hy = p(0, 0, 356)
    c.disc(hx - 6 * s, hy - 3 * s, 24 * s, 12 * s, BRASS, 1.6, 0.7, spec=0.8)
    c.disc(hx - 6 * s, hy - 6 * s, 9 * s, 4.5 * s, BRASS * 0.8, 1.2, 0.4, spec=0.8)
    vx, vy = p(0.2, -0.18, 356)
    c.pipe([(vx, vy), (vx, vy - 26 * s), (vx + 10 * s, vy - 30 * s)], 7, COPPER)
    # gauge on the front
    c.gauge(*c.cyl_pt(0, 0, R, -0.35, 262), 13, angle=-30)
    # red valve + outlet pipe down the near side
    ox, oy = p(R * 0.75, R * 0.66, 180)
    c.pipe([(ox, oy), (ox + 24 * s, oy + 8 * s), (ox + 24 * s, oy + 150 * s)], 9, COPPER, spec=1.0)
    c.disc(ox + 24 * s, oy + 8 * s, 6 * s, 6 * s, BRASS, 1.2, 0.3)
    vx, vy = ox + 24 * s, oy + 46 * s
    ring = np.clip(c.mask_ellipse(vx, vy, 12 * s, 12 * s) - c.mask_ellipse(vx, vy, 8 * s, 8 * s), 0, 1)
    c.paint(ring, c.grad(RED, 1.25, 0.8, vy - 12 * s, vy + 12 * s), 1.2, 0.6)
    c.stroke([(vx - 10 * s, vy), (vx + 10 * s, vy)], 2.4, RED)
    c.stroke([(vx, vy - 10 * s), (vx, vy + 10 * s)], 2.4, RED)
    c.disc(vx, vy, 3 * s, 3 * s, BRASS, 0.8, 0)
    c.finish(out)


def stool(out, col, seed):
    c = Canvas(110, 290, seed=seed)
    p, s = c.p, c.ss
    c.ground_shadow(0.4, 0.4, opacity=0.32)
    H0 = 70
    legs = [(-0.17, -0.17), (0.17, -0.17), (0.17, 0.17), (-0.17, 0.17)]
    for i in (0, 1, 3, 2):
        gx, gy = legs[i]
        a = p(gx * 0.8, gy * 0.8, H0 - 6)
        b = p(gx, gy, 0)
        c.pipe([a, b], 7, col * (0.8 if i in (0, 1) else 1.0), spec=1.0, outline=1.6)
    # cross ring between the legs
    c.stroke([p(-0.155, 0.155, 22), p(0.155, 0.155, 22), p(0.155, -0.155, 22)], 3.2, col * 0.8)
    # seat: rounded square slab with a skirt
    r = 0.06
    seat = []
    for (cx_, cy_, a0) in ((0.2 - r, 0.2 - r, 0), (-0.2 + r, 0.2 - r, 90), (-0.2 + r, -0.2 + r, 180), (0.2 - r, -0.2 + r, 270)):
        for t in np.linspace(math.radians(a0), math.radians(a0 + 90), 5):
            seat.append((cx_ + math.cos(t) * r, cy_ + math.sin(t) * r))
    c.prism(seat, H0 - 10, H0, col, rim=0.9, smooth=True, outline=1.8)
    # glossy highlight + finger hole
    hx, hy = p(0, 0, H0)
    c.glaze(ndimage.gaussian_filter(c.mask_ellipse(hx - 10 * s, hy - 4 * s, 12 * s, 5 * s), 2.5 * s), (1, 1, 1), 0.35)
    c.paint(c.mask_ellipse(hx + 2 * s, hy + 1 * s, 7 * s, 3.5 * s), c.flat(col * 0.4), 0.8, 0)
    c.finish(out)


if __name__ == "__main__":
    name, out = sys.argv[1], sys.argv[2]
    if name == "stool_a":
        stool(out, hexc("#D3302A"), 31)
    elif name == "stool_b":
        stool(out, hexc("#2F5FD0"), 32)
    else:
        globals()[name](out)
    print("ok", name)
