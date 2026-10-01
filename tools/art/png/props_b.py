"""Painted PNG props, part B: steam_bike, brass_automaton, boiler, gear_stall,
crate, sign.  Run: python3 props_b.py <name> <out.png>"""
import math, sys
import numpy as np
from paint import *

WOOD_D = hexc("#5C3A1A")
WOOD_L = hexc("#B07A42")
GOLD_CANVAS = hexc("#D9A93A")
CHALK = hexc("#E9E4D4")


def umbrella(c, ux, uy, z_base, rim_z, apex_z, R, col_a, col_b, rib=None, fringe=None):
    p, s = c.p, c.ss
    c.pipe([p(ux, uy, z_base), p(ux, uy, apex_z - 8)], 6, STEEL * 0.8, spec=0.6)
    ax, ay = p(ux, uy, apex_z)
    cx, cy = p(ux, uy, rim_z)
    rx, ry = R * 128 * s, R * 64 * s
    N = 8
    off = math.radians(11)
    rim = lambda t: (cx + math.cos(t) * rx, cy + math.sin(t) * ry)
    order = sorted(range(N), key=lambda i: math.sin(2 * math.pi * (i + 0.5) / N + off))
    for i in order:
        t0, t1 = 2 * math.pi * i / N + off, 2 * math.pi * (i + 1) / N + off
        tm = (t0 + t1) / 2
        arc = [rim(t) for t in np.linspace(t0, t1, 10)]
        arc = [(x, y + math.sin(math.pi * k / 9) * 7 * s) for k, (x, y) in enumerate(arc)]
        poly = [(ax, ay)] + arc
        nx, ny = math.cos(tm) * 0.55, math.sin(tm) * 0.275 - 0.5
        lam = max(0.0, nx * LIGHT[0] + ny * LIGHT[1] + 0.75 * LIGHT[2])
        base = col_a if i % 2 == 0 else col_b
        ys = [q[1] for q in poly]
        c.paint(c.mask_poly(poly), c.grad(base * (0.55 + 0.75 * lam), 1.12, 0.86, min(ys), max(ys)), 1.6,
                0.6 if lam > 0.5 else 0.15, tex=0.08)
    rib = col_a * 0.45 if rib is None else rib
    for i in range(N):
        t = 2 * math.pi * i / N + off
        if math.sin(t) > -0.3:
            x, y = rim(t)
            c.stroke([(ax, ay), (x, y)], 1.6, rib, 0.8)
            c.disc(x, y + 1 * s, 2.6 * s, 2.6 * s, BRASS, 0.6, 0, spec=1.0)
    if fringe is not None:
        for t in np.linspace(math.radians(15), math.radians(165), 22):
            x, y = rim(t)
            c.stroke([(x, y + 4 * s), (x, y + 13 * s)], 2.2, fringe, 0.9)
    c.disc(ax, ay - 5 * s, 6 * s, 6 * s, BRASS, 1.2, 0.4, spec=1.0)


def steam_bike(out):
    c = Canvas(380, 420, seed=41)
    p, s = c.p, c.ss
    c.ground_shadow(1.4, 0.7)
    WR, WZ = 0.22, 40
    RX, FX = -0.46, 0.5
    # rear rack + red delivery box (far up-left), drawn first
    c.box(-0.76, -0.24, -0.44, 0.24, 96, 170, RED, rim=0.9)
    c.box(-0.78, -0.26, -0.42, 0.26, 170, 178, RED * 0.78, rim=0.8)
    c.stroke([p(-0.44, 0.24, 102), p(-0.44, 0.24, 166)], 1.4, RED * 0.6, 0.8)
    lx, ly = p(-0.6, 0.24, 136)
    c.paint(c.mask_poly([(lx - 18 * s, ly - 4 * s), (lx + 18 * s, ly + 5 * s), (lx + 18 * s, ly - 25 * s), (lx - 18 * s, ly - 34 * s)]), c.flat(CREAM), 1.0, 0)
    c.gear(lx, ly - 15 * s, 10 * s, RED * 0.9, teeth=8, flat=1.0, hole=0.35, outline=0.8)
    c.rivets([p(gx, 0.24, z) for gx in (-0.74, -0.46) for z in (104, 162)], 2.0)
    c.pipe([p(-0.76, 0.2, 96), p(-0.46, 0.2, 92), p(RX, 0.0, WZ)], 4, SOOT * 1.6)
    # wheels
    c.wheel(RX, 0.0, WZ, WR, WZ, axis="x")
    c.wheel(FX, 0.0, WZ, WR, WZ, axis="x")
    c.pipe([p(RX + math.cos(t) * 0.27, 0, WZ + math.sin(t) * 50) for t in np.linspace(0.2, math.pi * 0.62, 10)], 6, SOOT * 1.6)
    c.pipe([p(FX + math.cos(t) * 0.27, 0, WZ + math.sin(t) * 50) for t in np.linspace(math.pi * 0.35, math.pi - 0.2, 10)], 6, COPPER * 0.8)
    # fork + frame
    c.pipe([p(FX, 0.0, WZ), p(0.38, 0.0, 156)], 8, STEEL * 0.8, spec=0.8)
    c.pipe([p(RX, 0, WZ), p(-0.08, 0, 66), p(0.36, 0, 120)], 9, COPPER, spec=1.0)
    c.pipe([p(RX, 0, WZ), p(-0.24, 0, 116), p(0.36, 0, 132)], 8, COPPER * 0.92, spec=1.0)
    # engine block + exhaust
    c.box(-0.16, -0.1, 0.14, 0.1, 48, 98, SOOT * 1.5, rim=0.5)
    for gx in (-0.06, 0.06):
        c.disc(*p(gx, 0.1, 76), 6 * s, 9 * s, STEEL, 1.0, 0.3, spec=0.8)
    c.pipe([p(0.06, 0.1, 56), p(-0.3, 0.16, 50), p(-0.64, 0.16, 62)], 7, BRASS * 0.85, spec=1.0)
    # little boiler behind the seat + tall chimney
    c.cylinder(-0.34, 0.0, 0.1, 96, 176, BRASS, spec=1.0, rim=0.8, top_c=BRASS * 0.9)
    c.band(-0.34, 0.0, 0.1, 112, 118, COPPER)
    c.band(-0.34, 0.0, 0.1, 156, 162, COPPER)
    c.gauge(*c.cyl_pt(-0.34, 0.0, 0.1, 0.1, 136), 7, angle=40)
    bx, by = p(-0.34, 0.0, 176)
    c.pipe([(bx, by), (bx, by - 48 * s)], 8, SOOT * 1.8, spec=0.4)
    c.disc(bx, by - 48 * s, 7 * s, 3 * s, SOOT * 1.3, 1.2, 0.3, dome=False)
    c.disc(bx, by - 22 * s, 5.5 * s, 2.2 * s, BRASS, 0.8, 0.2, dome=False)
    # seat
    seat = [(-0.24, -0.1), (0.04, -0.09), (0.1, 0.0), (0.04, 0.09), (-0.24, 0.1)]
    c.prism(seat, 128, 142, SOOT * 1.7, rim=0.8, smooth=True)
    # copper tank between seat and bars
    tank = [(0.1, -0.1), (0.3, -0.08), (0.36, 0.0), (0.3, 0.08), (0.1, 0.1)]
    c.prism(tank, 120, 150, COPPER, top_c=COPPER * 1.12, rim=1.0, smooth=True)
    c.disc(*p(0.22, 0.0, 152), 5 * s, 3 * s, BRASS, 1.0, 0.4)
    # handlebar + brass headlamp
    c.pipe([p(0.4, -0.24, 166), p(0.4, 0.24, 166)], 6, STEEL * 0.8, spec=0.8)
    for gy in (-0.24, 0.24):
        c.pipe([p(0.4, gy, 166), p(0.38, gy * 1.15, 168)], 7, SOOT * 1.6)
    lx, ly = p(0.48, 0.03, 140)
    c.disc(lx, ly, 13 * s, 14 * s, BRASS, 1.6, 0.7, spec=1.0)
    c.disc(lx + 2 * s, ly + 1 * s, 8 * s, 9 * s, hexc("#FFF4C8"), 0.8, 0.0, spec=1.0)
    c.glaze(ndimage.gaussian_filter(c.mask_ellipse(lx + 4 * s, ly, 16 * s, 16 * s), 4 * s), hexc("#FFE08A"), 0.25)
    # kickstand
    c.pipe([p(-0.1, 0.06, 56), p(-0.18, 0.22, 2)], 4, SOOT * 1.6)
    c.finish(out)


def brass_automaton(out):
    c = Canvas(180, 540, seed=42)
    p, s = c.p, c.ss
    c.ground_shadow(0.5, 0.5)
    c.cylinder(0, 0, 0.24, 0, 14, SOOT * 1.6, spec=0.3)
    c.cylinder(0, 0, 0.07, 14, 186, STEEL * 0.7, spec=0.9)
    c.band(0, 0, 0.07, 120, 128, BRASS)
    # barrel torso (tapered stack)
    for i, (z0, z1, r) in enumerate(((180, 196, 0.27), (196, 270, 0.33), (270, 290, 0.29))):
        c.cylinder(0, 0, r, z0, z1, BRASS * (0.92 if i != 1 else 1.0), spec=1.0, rim=0.8, outline=2.0)
    c.band(0, 0, 0.335, 228, 236, COPPER)
    for z in (210, 262):
        tx, ty = p(0, 0, z)
        c.rivets([(tx + math.cos(t) * 0.33 * 128 * s, ty + math.sin(t) * 0.33 * 64 * s) for t in np.linspace(0.3, math.pi - 0.3, 6)], 2.2)
    c.gauge(*p(0.0, 0.33, 248), 14, angle=-60)
    # shoulders + stub arms
    for gx, gy, side in ((-0.34, 0.2, -1), (0.34, -0.2, 1)):
        x, y = p(gx * 0.82, gy * 0.82, 278)
        far = side < 0 and False
        c.disc(x, y, 14 * s, 14 * s, COPPER, 1.6, 0.6, spec=0.9)
        ex, ey = x + side * 12 * s, y + 38 * s
        c.pipe([(x, y), (ex, ey)], 10, COPPER * 0.9, spec=0.9)
        c.disc(ex, ey, 9 * s, 9 * s, STEEL, 1.4, 0.5, spec=1.0)
    # head: brass bucket with a slit visor
    c.cylinder(0, 0, 0.19, 294, 336, BRASS, spec=1.0, rim=0.8, top_c=BRASS * 0.95)
    vis = [c.cyl_pt(0, 0, 0.19, u, 322) for u in np.linspace(-0.85, 0.75, 12)]
    vis += [c.cyl_pt(0, 0, 0.19, u, 312) for u in np.linspace(0.75, -0.85, 12)]
    c.paint(c.mask_poly(vis), c.flat(SOOT), 1.2, 0)
    eye = [c.cyl_pt(0, 0, 0.19, u, 318) for u in np.linspace(-0.6, 0.4, 8)] + [c.cyl_pt(0, 0, 0.19, u, 316) for u in np.linspace(0.4, -0.6, 8)]
    c.glaze(c.mask_poly(eye), hexc("#FF6A3D"), 0.9)
    c.rivets([c.cyl_pt(0, 0, 0.19, u, 302) for u in (-0.6, 0.0, 0.6)], 1.8)
    # antenna + red lamp
    hx, hy = p(0, 0, 336)
    c.pipe([(hx, hy), (hx, hy - 18 * s)], 4, STEEL * 0.7)
    c.glaze(ndimage.gaussian_filter(c.mask_ellipse(hx, hy - 22 * s, 12 * s, 12 * s), 4 * s), hexc("#FF5A3A"), 0.4)
    c.disc(hx, hy - 22 * s, 6 * s, 6 * s, hexc("#E8382B"), 1.2, 0.3, spec=1.0)
    c.finish(out)


def boiler(out):
    c = Canvas(300, 680, seed=43)
    p, s = c.p, c.ss
    c.ground_shadow(1.0, 1.0)
    c.box(-0.5, -0.5, 0.5, 0.5, 0, 28, SOOT * 1.5, rim=0.5)
    c.rivets([p(gx, 0.5, 14) for gx in np.linspace(-0.42, 0.42, 6)], 2.4)
    R = 0.42
    c.cylinder(0, 0, R, 28, 352, COPPER, spec=0.9, rim=0.7, top_c=COPPER)
    for z in (110, 236):
        c.band(0, 0, R, z, z + 14, BRASS, spec=1.0)
        tx, ty = p(0, 0, z + 7)
        c.rivets([(tx + math.cos(t) * R * 128 * s, ty + math.sin(t) * R * 64 * s) for t in np.linspace(0.3, math.pi - 0.3, 8)], 2.6)
    for z in np.linspace(48, 340, 12):
        tx, ty = p(0, 0, z)
        c.disc(tx + R * 128 * s * 0.62, ty + R * 64 * s * 0.78, 2.2 * s, 2.2 * s, BRASS, 0.8, 0, spec=1.0)
    # brass dome
    tx, ty = p(0, 0, 352)
    rx, ry = R * 128 * s, R * 64 * s
    dome = np.maximum(c.mask_ellipse(tx, ty, rx, ry), c.mask_ellipse(tx, ty - 6 * s, rx * 0.98, ry + 20 * s) * (c.yy < ty))
    nx = np.clip((c.xx - tx) / rx, -1, 1)
    ny = np.clip((c.yy - (ty - 6 * s)) / (ry + 20 * s), -1, 1)
    nz = np.sqrt(np.clip(1 - nx ** 2 - ny ** 2, 0, 1))
    lam = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
    col = BRASS[None, None, :] * (0.45 + 0.75 * lam)[..., None]
    col = col + (WARM[None, None, :] - col) * (lam ** 30)[..., None]
    c.paint(dome, np.clip(col, 0, 1), 2.2, 0.8)
    # chimney (top under the SteamVent at z ~420)
    cx_, cy_ = p(0, 0, 372)
    c.pipe([(cx_, cy_), (cx_, cy_ - 48 * s)], 15, SOOT * 1.8, spec=0.5)
    c.disc(cx_, cy_ - 48 * s, 13 * s, 5 * s, SOOT * 1.4, 1.4, 0.4, dome=False)
    c.disc(cx_, cy_ - 48 * s, 8 * s, 3 * s, (0.05, 0.04, 0.05), 0, 0, dome=False)
    c.disc(cx_, cy_ - 20 * s, 10.5 * s, 4 * s, BRASS, 1.0, 0.3, dome=False)
    # firebox door with glow
    def fp(u, z):
        return c.cyl_pt(0, 0, R, u * 1.6, z)
    door = [fp(-0.2, 56), fp(0.2, 56), fp(0.2, 108), fp(-0.2, 108)]
    c.paint(c.mask_poly(door), c.flat(SOOT * 1.2), 1.8, 0.2)
    gl = [fp(-0.15, 62), fp(0.15, 62), fp(0.15, 96), fp(-0.15, 96)]
    gx_, gy_ = fp(0.0, 76)
    f = c.flat(hexc("#FFB347")) * (0.7 + 0.6 * np.clip(1 - np.hypot(c.xx - gx_, c.yy - gy_) / (34 * s), 0, 1))[..., None]
    c.paint(c.mask_poly(gl), np.clip(f, 0, 1), 0.8, 0, tex=0.18)
    for u in np.linspace(-0.11, 0.11, 5):
        c.stroke([fp(u, 62), fp(u, 96)], 1.8, SOOT)
    c.glaze(ndimage.gaussian_filter(c.mask_ellipse(gx_, gy_ + 40 * s, 50 * s, 22 * s), 8 * s), hexc("#FF9A3C"), 0.3)
    # gauges + red valve wheel
    c.gauge(*fp(-0.22, 196), 15, angle=-50)
    c.gauge(*fp(0.2, 296), 10, angle=40)
    vx, vy = c.cyl_pt(0, 0, R, 0.97, 190)
    vx += 16 * s
    c.pipe([(vx - 20 * s, vy), (vx, vy)], 7, BRASS)
    ring = np.clip(c.mask_ellipse(vx, vy, 12 * s, 18 * s) - c.mask_ellipse(vx, vy, 8 * s, 13 * s), 0, 1)
    c.paint(ring, c.grad(RED, 1.25, 0.8, vy - 18 * s, vy + 18 * s), 1.4, 0.6)
    c.stroke([(vx, vy - 15 * s), (vx, vy + 15 * s)], 2.6, RED)
    c.stroke([(vx - 10 * s, vy), (vx + 10 * s, vy)], 2.6, RED)
    c.disc(vx, vy, 3.5 * s, 3.5 * s, BRASS, 0.8, 0)
    # steam pipe snaking down the near side
    q0 = c.cyl_pt(0, 0, R, 0.75, 330)
    q1 = (q0[0] + 26 * s, q0[1] + 6 * s)
    q2 = (q1[0], q1[1] + 210 * s)
    q3 = c.cyl_pt(0, 0, R, 0.8, 40)
    c.pipe([q0, q1, q2, (q3[0] + 26 * s, q3[1] + 30 * s)], 9, COPPER, spec=1.0)
    c.disc(q1[0], q1[1], 7 * s, 7 * s, BRASS, 1.2, 0.3)
    c.finish(out)


def gear_stall(out):
    c = Canvas(400, 440, seed=44)
    p, s = c.p, c.ss
    c.ground_shadow(1.5, 1.0)
    X0, X1, Y0, Y1 = -0.75, 0.75, -0.5, 0.5
    # table legs (back first)
    for gx, gy in ((X0 + 0.06, Y0 + 0.06), (X1 - 0.06, Y0 + 0.06)):
        c.pipe([p(gx, gy, 0), p(gx, gy, 108)], 8, WOOD_D)
    c.box(X0, Y0, X1, Y1, 92, 108, WOOD, rim=0.6)
    for gx, gy in ((X1 - 0.06, Y1 - 0.06), (X0 + 0.06, Y1 - 0.06)):
        c.pipe([p(gx, gy, 0), p(gx, gy, 108)], 8, WOOD * 0.9)
    # table top planks
    c.box(X0 - 0.03, Y0 - 0.03, X1 + 0.03, Y1 + 0.03, 108, 118, WOOD_L, rim=0.9)
    for gy in np.linspace(Y0 + 0.2, Y1 - 0.2, 4):
        c.stroke([p(X0, gy, 118), p(X1, gy, 118)], 0.9, WOOD_D, 0.6)
    # red cloth draped over the front with a brass-fringed hem
    cloth = []
    for u in np.linspace(0, 1, 30):
        cloth.append(p(X0 + (X1 - X0) * u, Y1 + 0.04, 18 + 5 * math.sin(u * 22)))
    cloth += [p(X1, Y1 + 0.04, 118), p(X0, Y1 + 0.04, 118)]
    cm = c.mask_poly(cloth)
    xl, _ = p(X0, Y1, 0)
    xr, _ = p(X1, Y1, 0)
    fold = 1 + 0.12 * np.sin((c.xx - xl) / (xr - xl + 1) * 2 * math.pi * 7)
    c.paint(cm, np.clip(c.grad(RED, 1.0, 0.75) * fold[..., None], 0, 1), 2.0, 0.5, tex=0.1)
    c.stroke([p(X0 + (X1 - X0) * u, Y1 + 0.04, 18 + 5 * math.sin(u * 22)) for u in np.linspace(0, 1, 30)], 2.4, BRASS)
    # side cloth on +x
    side = [p(X1 + 0.03, Y1, 118), p(X1 + 0.03, Y0 + 0.2, 118), p(X1 + 0.03, Y0 + 0.2, 30), p(X1 + 0.03, Y1, 18)]
    c.paint(c.mask_poly(side), c.grad(RED * 0.55, 1.0, 0.8), 2.0, 0)
    # gears: heaps lying flat + a few standing
    rng = np.random.default_rng(7)
    items = []
    for _ in range(16):
        gx, gy = rng.uniform(X0 + 0.15, X1 - 0.15), rng.uniform(Y0 + 0.12, Y1 - 0.1)
        items.append((gx + gy, gx, gy))
    items.sort()
    cols = [BRASS, COPPER, STEEL * 0.85, BRASS * 1.1]
    for k, (_, gx, gy) in enumerate(items):
        x, y = p(gx, gy, 118 + rng.uniform(0, 8))
        r = rng.uniform(9, 20) * s
        c.gear(x, y, r, cols[k % 4], teeth=int(rng.integers(7, 12)), flat=0.5)
    for gx, gy, r, col in ((-0.35, -0.2, 30, BRASS), (0.42, -0.25, 24, COPPER), (0.05, 0.05, 18, STEEL * 0.9)):
        x, y = p(gx, gy, 118)
        c.gear(x, y - r * s, r * s, col, teeth=10, flat=1.0, hole=0.28, outline=1.6)
    # gold canvas umbrella
    umbrella(c, 0.05, -0.3, 118, 202, 236, 0.78, GOLD_CANVAS, GOLD_CANVAS * 0.82, rib=BRASS_D, fringe=RED)
    c.finish(out)


def crate(out):
    c = Canvas(240, 360, seed=45)
    p, s = c.p, c.ss
    c.ground_shadow(0.9, 0.9)
    H = 124
    c.box(-0.43, -0.43, 0.43, 0.43, 0, H, WOOD, rim=0.8, tex=0.12)
    # plank seams
    for z in np.linspace(H / 4, H * 3 / 4, 3):
        c.stroke([p(-0.43, 0.43, z), p(0.43, 0.43, z), p(0.43, -0.43, z)], 1.1, WOOD_D, 0.7)
    for gy in np.linspace(-0.3, 0.3, 3):
        c.stroke([p(-0.43, gy, H), p(0.43, gy, H)], 1.1, WOOD_D, 0.7)
    # diagonal brace on the front
    c.stroke([p(-0.36, 0.43, 12), p(0.38, 0.43, H - 12)], 9, WOOD_D * 1.2)
    c.stroke([p(-0.36, 0.43, 12), p(0.38, 0.43, H - 12)], 5, WOOD_L * 0.95)
    # iron edge straps on every visible edge
    STRAP = SOOT * 1.9
    edges = [[p(-0.43, 0.43, 0), p(-0.43, 0.43, H)], [p(0.43, 0.43, 0), p(0.43, 0.43, H)], [p(0.43, -0.43, 0), p(0.43, -0.43, H)],
             [p(-0.43, 0.43, H), p(0.43, 0.43, H), p(0.43, -0.43, H), p(-0.43, -0.43, H), p(-0.43, 0.43, H)],
             [p(-0.43, 0.43, 2), p(0.43, 0.43, 2), p(0.43, -0.43, 2)]]
    for e in edges:
        c.stroke(e, 7.5, np.array(OUT) / 255.0)
        c.stroke(e, 5.0, STRAP)
        c.stroke(e, 1.2, STEEL, 0.5)
    c.rivets([p(gx, 0.43, z) for gx in (-0.36, 0.4) for z in (12, H - 12)] +
             [p(0.43, gy, z) for gy in (-0.36, 0.4) for z in (12, H - 12)] +
             [p(gx, 0.43, H / 2) for gx in (-0.36, 0.4)], 3.0)
    # brass gear stencil plate on the side
    gx, gy = p(0.43, 0.0, H / 2)
    c.paint(c.mask_poly([(gx - 18 * s, gy - 12 * s), (gx + 14 * s, gy - 28 * s), (gx + 14 * s, gy - 4 * s), (gx - 18 * s, gy + 12 * s)]),
            c.grad(BRASS * 0.7, 1.1, 0.8), 1.2, 0.3)
    c.gear(gx - 2 * s, gy - 8 * s, 9 * s, BRASS_L, teeth=8, flat=1.0, hole=0.35, outline=0.8)
    c.finish(out)


def sign(out):
    c = Canvas(180, 460, seed=46)
    p, s = c.p, c.ss
    c.ground_shadow(0.5, 0.3)
    # post
    c.cylinder(0, 0, 0.1, 0, 10, SOOT * 1.5, spec=0.2)
    c.pipe([p(0, 0, 8), p(0, 0, 230)], 11, WOOD, spec=0.3)
    # board (plane x-z, faces lower-left), brass frame + dark slate
    Z0, Z1, A = 166, 236, 0.42
    def bp(u, z, d=0.0):
        return p(-A + 2 * A * u, d, z)
    # thickness on the +x edge and top
    c.paint(c.mask_poly([bp(1, Z0, 0.02), bp(1, Z0, -0.04), bp(1, Z1, -0.04), bp(1, Z1, 0.02)]), c.flat(BRASS_D), 1.6, 0)
    c.paint(c.mask_poly([bp(0, Z1, 0.02), bp(1, Z1, 0.02), bp(1, Z1, -0.04), bp(0, Z1, -0.04)]), c.grad(BRASS_L, 1.0, 0.9), 1.6, 0.6)
    frame = [bp(0, Z0, 0.02), bp(1, Z0, 0.02), bp(1, Z1, 0.02), bp(0, Z1, 0.02)]
    c.paint(c.mask_poly(frame), c.grad(BRASS, 1.2, 0.8), 2.2, 0.8)
    slate = [bp(0.08, Z0 + 9, 0.02), bp(0.92, Z0 + 9, 0.02), bp(0.92, Z1 - 9, 0.02), bp(0.08, Z1 - 9, 0.02)]
    c.paint(c.mask_poly(slate), c.grad(SOOT * 1.1, 1.15, 0.8), 1.2, 0, tex=0.15)
    # chalk lines (no real text)
    for u0, u1, z in ((0.16, 0.84, Z1 - 22), (0.16, 0.62, Z1 - 38), (0.16, 0.74, Z1 - 54)):
        c.stroke([bp(u0, z, 0.02), bp(u1, z, 0.02)], 2.4, CHALK, 0.85)
    c.rivets([bp(u, z, 0.02) for u in (0.04, 0.96) for z in (Z0 + 5, Z1 - 5)], 2.4)
    # decorative gears on the top corner
    gx, gy = bp(0.86, Z1 + 6, 0.0)
    c.gear(gx, gy - 4 * s, 16 * s, COPPER, teeth=9, flat=1.0, hole=0.3, outline=1.4)
    c.gear(gx - 22 * s, gy + 2 * s, 9 * s, BRASS, teeth=7, flat=1.0, hole=0.3, outline=1.0)
    c.finish(out)


if __name__ == "__main__":
    globals()[sys.argv[1]](sys.argv[2])
    print("ok", sys.argv[1])
