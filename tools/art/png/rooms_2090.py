"""Painted backdrops for the กรุงเทพฯ 2090 rooms (scripts/world/rooms.gd).
Usage:  python3 rooms_2090.py all  |  <room id> [out.png]
Same geometry as room.py (RoomCanvas, wall_height 240); the corners outside
the floor become canal water so every room reads as "the city is flooded".
"""
import math
import os
import sys

import numpy as np
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from paint import BRASS, BRASS_L, COPPER, SOOT, STEEL, WARM, WOOD, hexc  # noqa: E402
from room import (RoomCanvas, brick_wall, concrete_floor, doorway, teak_wall,  # noqa: E402
                  tile_floor, wall_edge, zinc_wall)

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "..", "assets", "art", "rooms")
WH = 240
MURK = hexc("#2F5A55")
FLOOD = hexc("#3E5A48")


def flood_line(c, side, length, z=90):
    """Water stain on a wall: darker below the line of last year's flood."""
    m = c.mask_poly(c.wall_quad(side, 0, length, 0, z))
    c.glaze(m, FLOOD, 0.35)
    c.stroke([c.wp(side, 0, z), c.wp(side, length, z)], 3.0, FLOOD * 0.6, 0.7)


def flood_surround(c, gw, gh, seed=21):
    """Canal water in the canvas corners outside the floor's front edges."""
    s = c.ss
    rng = np.random.default_rng(seed)
    xl, yl = c.p(0, gh)
    xb, yb = c.p(gw, gh)
    xr, yr = c.p(gw, 0)
    W, H = c.W, c.H
    water = np.maximum(c.mask_poly([(0, yl), (xb, yb), (0, H)]), c.mask_poly([(xb, yb), (W, yr), (W, H)]))
    field = c.grad(MURK, 0.95, 1.1, min(yl, yr), H)
    field = field * (1 + 0.1 * np.clip(c.noise(25, seed) * 0.7 + c.noise(4, seed + 1) * 0.3, -1, 1))[..., None]
    c.paint(water, field, outline=0, tex=0.04)
    for _ in range(120):
        gx, gy = rng.uniform(-2, gw + 2), rng.uniform(gh + 0.2, gh + 4)
        if rng.random() < 0.5:
            gx, gy = rng.uniform(gw + 0.2, gw + 4), rng.uniform(-2, gh + 2)
        L = rng.uniform(0.15, 0.5)
        c.stroke([c.p(gx, gy), c.p(gx + L, gy)], rng.uniform(1.2, 2.4), hexc("#8FC3B8"), rng.uniform(0.2, 0.45))
    for _ in range(6):
        gx, gy = rng.uniform(1, gw), gh + rng.uniform(0.6, 2.5)
        if rng.random() < 0.5:
            gx, gy = gw + rng.uniform(0.6, 2.5), rng.uniform(1, gh)
        x, y = c.p(gx, gy)
        for k in range(6):
            c.disc(x + rng.uniform(-28, 28) * s, y + rng.uniform(-10, 10) * s, rng.uniform(9, 13) * s,
                   rng.uniform(5, 7) * s, hexc("#4F8A3C"), 1.0, 0.4, spec=0.4)
        c.disc(x, y - 10 * s, 4 * s, 4 * s, hexc("#B48AD8"), 0.6, 0.2)
    # the floor is a platform: a drop face along both front edges
    for a, b in (((0, gh), (gw, gh)), ((gw, 0), (gw, gh))):
        drop = c.mask_poly([c.p(*a, 0), c.p(*b, 0), c.p(*b, -46), c.p(*a, -46)])
        c.paint(drop, c.grad(hexc("#5E564E"), 0.9, 0.6, min(yl, yr), H), 1.6, 0)
    c.glaze(ndimage.gaussian_filter(water * 0 + np.maximum(
        c.mask_poly([c.p(0, gh, -46), c.p(gw, gh, -46), c.p(gw, gh + 0.5, -46), c.p(0, gh + 0.5, -46)]),
        c.mask_poly([c.p(gw, 0, -46), c.p(gw, gh, -46), c.p(gw + 0.5, gh, -46), c.p(gw + 0.5, 0, -46)])), 8 * s) * water,
        SOOT, 0.4)


def plank_floor(c, gw, gh, wood, seed=12):
    s = c.ss
    rng = np.random.default_rng(seed)
    yt, yb = c.p(0, 0)[1], c.p(gw, gh)[1]
    deck = c.mask_poly([c.p(0, 0), c.p(gw, 0), c.p(gw, gh), c.p(0, gh)])
    c.paint(deck, c.grad(wood, 1.05, 0.88, yt, yb), outline=0, tex=0.08)
    # boards: each row its own tone, so the deck reads as planks not a stain
    for gy in np.arange(0.0, gh, 0.25):
        row = c.mask_poly([c.p(0, gy), c.p(gw, gy), c.p(gw, gy + 0.25), c.p(0, gy + 0.25)])
        c.glaze(row, wood * rng.uniform(0.82, 1.15), 0.5)
        c.stroke([c.p(0, gy), c.p(gw, gy)], 2.2, wood * 0.45, 0.9)
        for gx in np.arange(rng.uniform(0, 1.5), gw, rng.uniform(1.5, 2.6)):
            c.stroke([c.p(gx, gy), c.p(gx, gy + 0.25)], 1.8, wood * 0.45, 0.9)
            x, y = c.p(gx + 0.08, gy + 0.12)
            c.disc(x, y, 1.8 * s, 1.3 * s, SOOT, 0.3, 0)
    for _ in range(4):
        gx, gy = rng.uniform(0.6, gw - 0.6), rng.uniform(0.6, gh - 0.6)
        x, y = c.p(gx, gy)
        m = ndimage.gaussian_filter(c.mask_ellipse(x, y, rng.uniform(40, 90) * s, rng.uniform(20, 40) * s), 6 * s)
        c.glaze(m * deck, FLOOD, rng.uniform(0.05, 0.1))
    ao = np.maximum(c.mask_poly([c.p(0, 0), c.p(gw, 0), c.p(gw, 0.9), c.p(0, 0.9)]),
                    c.mask_poly([c.p(0, 0), c.p(0, gh), c.p(0.9, gh), c.p(0.9, 0)]))
    c.glaze(ndimage.gaussian_filter(ao, 24 * s) * deck, SOOT, 0.4)


def plaster_wall(c, side, length, plaster, windows=(), poster=None, seed=3):
    """Rendered plaster with flood stains, canal-view windows and a poster."""
    s = c.ss
    H = WH * 2
    k_face = 1.0 if side == "L" else 0.8
    quad = c.wall_quad(side, 0, length, 0, H)
    yt, yb = min(q[1] for q in quad), max(q[1] for q in quad)
    field = c.grad(plaster * k_face, 1.08, 0.82, yt, yb)
    field = field * (1 + 0.07 * np.clip(c.noise(35, seed) * 0.7 + c.noise(6, seed + 1) * 0.3, -1, 1))[..., None]
    c.paint(c.mask_poly(quad), field, outline=0, tex=0.06)
    rng = np.random.default_rng(seed)
    for u in windows:
        frame = c.mask_poly(c.wall_quad(side, u - 0.62, u + 0.62, 180, 400))
        c.paint(frame, c.grad(WOOD * 0.9 * k_face, 1.05, 0.85, yt, yb), 2.0, 0.4)
        glass = c.mask_poly(c.wall_quad(side, u - 0.52, u + 0.52, 192, 388))
        c.paint(glass, c.grad(hexc("#9FC9D6") * k_face, 1.15, 0.7, yt, yb), 1.4, 0)
        # towers behind the sea wall, far away and dry
        for k in range(4):
            uu = u - 0.42 + k * 0.26
            top = 260 + rng.uniform(20, 110)
            m = c.mask_poly(c.wall_quad(side, uu, uu + 0.16, 200, top)) * glass
            c.glaze(m, hexc("#5C6E80"), 0.6)
        wl = c.mask_poly(c.wall_quad(side, u - 0.52, u + 0.52, 192, 236)) * glass
        c.glaze(wl, MURK, 0.7)
        c.stroke([c.wp(side, u, 192), c.wp(side, u, 388)], 3.0, WOOD * 0.6, 0.9)
    if poster:
        u0, text, col = poster
        pm = c.mask_poly(c.wall_quad(side, u0, u0 + 0.9, 170, 320))
        c.paint(pm, c.grad(hexc("#F2EFE6") * k_face, 1.05, 0.9, yt, yb), 1.8, 0.3)
        c.text(text, c.wp(side, u0 + 0.08, 300), c.wp(side, u0 + 0.82, 300), 22, col)
        for k in range(3):
            z = 270 - k * 30
            c.stroke([c.wp(side, u0 + 0.12, z), c.wp(side, u0 + 0.7 - 0.15 * (k % 2), z)], 4.0, col, 0.7)
    flood_line(c, side, length)
    c.pipe([c.wp(side, 0, 440), c.wp(side, length, 440)], 8, COPPER, spec=0.7)
    for u in np.arange(1.0, length, 3.0):
        lx, ly = c.wp(side, u, 420)
        c.disc(lx, ly + 8 * s, 10 * s, 13 * s, BRASS_L, 1.4, 0.4, spec=1.0)
        c.glaze(c.mask_ellipse(lx, ly + 10 * s, 55 * s, 55 * s), WARM, 0.12)


# ---- what is above the back walls (owner 2026-10-02: "ขอบดำเยอะ") --------------
# The camera now zooms each room to fill the screen, so the triangles above the
# two walls are on screen: Bangkok 2090 at dusk behind them — company towers
# behind the sea wall, a half-drowned prang, neighbours' zinc roofs, poles and
# sagging wires. Painted first; walls, floor and water cover the rest.
SKY_TOP = hexc("#2A2650")
SKY_MID = hexc("#7A4A6A")
SKY_LOW = hexc("#E8955A")
HAZE = hexc("#5C6A8C")
NEAR = hexc("#3A3238")


def _lerp_field(c, a, b, y0, y1):
    t = np.clip((c.yy - y0) / max(1.0, y1 - y0), 0, 1)[..., None]
    return np.asarray(a)[None, None, :] * (1 - t) + np.asarray(b)[None, None, :] * t


def skyline(c, gw, gh, seed=51, night=False):
    s = c.ss
    rng = np.random.default_rng(seed)
    W = c.W
    horizon = max(gw, gh) * 64 * s          # the walls' low ends: everything below is covered
    ones = np.ones((c.H, c.W), np.float32)
    sky = _lerp_field(c, SKY_TOP, SKY_MID, 0, horizon * 0.55)
    low = _lerp_field(c, SKY_MID, SKY_LOW, horizon * 0.55, horizon * 1.1)
    t = np.clip((c.yy - horizon * 0.55) / max(1.0, horizon * 0.55), 0, 1)[..., None]
    c.paint(ones, sky * (1 - t) + low * t, outline=0, tex=0.03)
    # the low sun, left of centre, and its haze
    sx, sy = W * 0.36, horizon * 0.72
    c.glaze(c.mask_ellipse(sx, sy, 170 * s, 170 * s), hexc("#FFD9A0"), 0.25)
    c.glaze(c.mask_ellipse(sx, sy, 60 * s, 60 * s), hexc("#FFF0C8"), 0.9)
    c.glaze(c.mask_poly([(0, horizon * 0.6), (W, horizon * 0.6), (W, horizon * 1.2), (0, horizon * 1.2)]), SKY_LOW, 0.25)
    # company towers behind the sea wall: flat hazy slabs, lit windows
    base = horizon * 0.95
    x = -40 * s
    while x < W:
        tw = rng.uniform(60, 150) * s
        th = rng.uniform(140, 420) * s
        tower = c.mask_poly([(x, base), (x + tw, base), (x + tw, base - th), (x, base - th)])
        c.paint(tower, c.grad(HAZE, 1.05, 0.9, base - th, base), outline=0, tex=0.02)
        for _ in range(int(th * tw / (2600 * s * s))):
            wx, wy = x + rng.uniform(6, tw - 10), base - rng.uniform(10, th - 8)
            c.stroke([(wx, wy), (wx + 5 * s, wy)], 2.0 * s, hexc("#FFE6A8"), rng.uniform(0.3, 0.8))
        x += tw + rng.uniform(10, 50) * s
    # the sea wall: a dark band with the company's lamps
    wall = c.mask_poly([(0, base - 30 * s), (W, base - 36 * s), (W, base + 20 * s), (0, base + 20 * s)])
    c.paint(wall, c.grad(hexc("#50545C"), 1.0, 0.8, base - 36 * s, base + 20 * s), outline=0, tex=0.05)
    for lx in np.arange(40 * s, W, 170 * s):
        c.disc(lx, base - 44 * s, 5 * s, 5 * s, hexc("#FFE6A8"), 0.6, 0.0, spec=1.0)
    # the drowned prang (left) in the haze
    px, pb = W * 0.17, base - 20 * s
    for k, (hw, hh) in enumerate(((70, 90), (52, 90), (36, 90), (20, 110))):
        y0 = pb - k * 85 * s
        tier = c.mask_poly([(px - hw * s, y0), (px + hw * s, y0), (px + (hw - 10) * s, y0 - hh * s), (px - (hw - 10) * s, y0 - hh * s)])
        c.paint(tier, c.grad(hexc("#6E6484"), 1.0, 0.9, y0 - hh * s, y0), outline=0, tex=0.03)
    # neighbours: zinc roofs and a water tank, nearer and darker
    for rx, rw, rh in ((W * 0.04, 260, 90), (W * 0.62, 300, 110), (W * 0.84, 220, 80)):
        ry = horizon * 0.98
        roof = c.mask_poly([(rx, ry), (rx + rw * s, ry), (rx + rw * s * 0.5, ry - rh * s)])
        c.paint(roof, c.grad(NEAR, 1.1, 0.9, ry - rh * s, ry), outline=0, tex=0.05)
        for i in range(1, 7):
            u = i / 7
            c.stroke([(rx + rw * s * u * 0.5, ry - rh * s * u), (rx + rw * s * u * 0.5, ry)], 1.2 * s, hexc("#55505A"), 0.5)
    tx, ty = W * 0.74, horizon * 0.9
    c.paint(c.mask_poly([(tx, ty), (tx + 70 * s, ty), (tx + 70 * s, ty - 90 * s), (tx, ty - 90 * s)]),
            c.grad(NEAR, 1.05, 0.9, ty - 90 * s, ty), outline=0, tex=0.04)
    c.stroke([(tx + 10 * s, ty), (tx + 10 * s, ty + 60 * s)], 3 * s, NEAR)
    c.stroke([(tx + 60 * s, ty), (tx + 60 * s, ty + 60 * s)], 3 * s, NEAR)
    # power poles and sagging wires across the sky
    poles = [(W * 0.09, horizon * 0.45), (W * 0.50, horizon * 0.35), (W * 0.91, horizon * 0.5)]
    for x0, y0 in poles:
        c.stroke([(x0, y0), (x0, y0 + horizon)], 5 * s, NEAR)
        c.stroke([(x0 - 36 * s, y0 + 12 * s), (x0 + 36 * s, y0 + 12 * s)], 4 * s, NEAR)
    for (xa, ya), (xb, yb) in zip(poles, poles[1:]):
        for k in range(3):
            pts = []
            for i in range(13):
                u = i / 12
                sag = math.sin(u * math.pi) * (60 + k * 14) * s
                pts.append((xa + (xb - xa) * u, ya + 12 * s + (yb - ya) * u + sag - k * 6 * s))
            c.stroke(pts, 1.4 * s, NEAR, 0.8)
    # birds, and one of พี่เบิ้ม's drones
    for _ in range(7):
        bx, by = rng.uniform(0.1, 0.9) * W, rng.uniform(0.05, 0.3) * horizon
        c.stroke([(bx - 8 * s, by), (bx, by - 4 * s), (bx + 8 * s, by)], 1.4 * s, NEAR, 0.8)
    dx, dy = W * 0.3, horizon * 0.2
    c.stroke([(dx - 14 * s, dy), (dx + 14 * s, dy)], 2 * s, NEAR)
    c.disc(dx, dy + 4 * s, 5 * s, 4 * s, NEAR, 0.6, 0.0)
    c.disc(dx, dy + 6 * s, 2 * s, 2 * s, hexc("#FF4040"), 0.4, 0.0, spec=1.0)


def underground(c, gw, gh, seed=52):
    """The pump station is under the soi: wet concrete and pipes above the walls."""
    s = c.ss
    rng = np.random.default_rng(seed)
    ones = np.ones((c.H, c.W), np.float32)
    c.paint(ones, c.grad(hexc("#2A2E30"), 1.0, 0.75, 0, c.H), outline=0, tex=0.08)
    for k in range(4):
        y = rng.uniform(0.05, 0.45) * max(gw, gh) * 64 * s
        c.pipe([(0, y), (c.W, y + rng.uniform(-40, 40) * s)], rng.uniform(14, 26) * s, hexc("#4A4E52"), spec=0.5)
    for _ in range(30):
        x, y = rng.uniform(0, c.W), rng.uniform(0, 0.5) * max(gw, gh) * 64 * s
        c.stroke([(x, y), (x + rng.uniform(-3, 3) * s, y + rng.uniform(20, 90) * s)], 1.5 * s, hexc("#1E2224"), 0.5)


def _room(gw, gh, seed):
    return RoomCanvas(gw, gh, WH, ss=1, seed=seed)


def home(out):
    gw, gh = 10, 8
    c = _room(gw, gh, 31)
    skyline(c, gw, gh, seed=81)
    plaster_wall(c, "R", gw, hexc("#6E9A8E"), windows=(3.0,), poster=(6.6, "ปลดหนี้ใน 7 วัน!", hexc("#C0392B")), seed=31)
    plaster_wall(c, "L", gh, hexc("#6E9A8E"), windows=(4.2,), seed=32)
    wall_edge(c, gw, gh, WH)
    plank_floor(c, gw, gh, hexc("#8B6038"), seed=33)
    flood_surround(c, gw, gh, seed=34)
    c.finish(out, sil=0)


def pier(out):
    gw, gh = 12, 9
    c = _room(gw, gh, 41)
    skyline(c, gw, gh, seed=91)
    teak_wall(c, "R", gw, WH, sign="ท่าเรือซอยส่งไว", seed=41)
    teak_wall(c, "L", gh, WH, door_u=2.4, seed=42)
    flood_line(c, "R", gw)
    flood_line(c, "L", gh)
    wall_edge(c, gw, gh, WH)
    plank_floor(c, gw, gh, hexc("#7E5634"), seed=43)
    flood_surround(c, gw, gh, seed=44)
    c.apply_door_pools()
    c.finish(out, sil=0)


def noodle_boat(out):
    gw, gh = 10, 7
    c = _room(gw, gh, 51)
    skyline(c, gw, gh, seed=101)
    zinc_wall(c, "R", gw, WH, hexc("#C8642E"), seed=51)
    zinc_wall(c, "L", gh, WH, hexc("#D2703A"), seed=52)
    wall_edge(c, gw, gh, WH)
    plank_floor(c, gw, gh, hexc("#9A6A3E"), seed=53)
    flood_surround(c, gw, gh, seed=54)
    c.finish(out, sil=0)


def stilts(out):
    gw, gh = 12, 9
    c = _room(gw, gh, 61)
    skyline(c, gw, gh, seed=111)
    teak_wall(c, "R", gw, WH, seed=61)
    teak_wall(c, "L", gh, WH, seed=62)
    flood_line(c, "R", gw, z=120)
    flood_line(c, "L", gh, z=120)
    wall_edge(c, gw, gh, WH)
    plank_floor(c, gw, gh, hexc("#8A6A48"), seed=63)
    flood_surround(c, gw, gh, seed=64)
    c.finish(out, sil=0)


def boat_garage(out):
    gw, gh = 12, 9
    c = _room(gw, gh, 71)
    skyline(c, gw, gh, seed=121)
    zinc = hexc("#6F7A80")
    zinc_wall(c, "R", gw, WH, zinc, seed=71)
    zinc_wall(c, "L", gh, WH, zinc * 1.05, seed=72)
    flood_line(c, "R", gw)
    flood_line(c, "L", gh)
    wall_edge(c, gw, gh, WH)
    concrete_floor(c, gw, gh, hexc("#5E5B5C"), seed=73)
    flood_surround(c, gw, gh, seed=74)
    c.finish(out, sil=0)


def old_gate(out):
    gw, gh = 12, 8
    c = _room(gw, gh, 81)
    skyline(c, gw, gh, seed=131)
    brick_wall(c, "R", gw, WH, hexc("#6E716E"), hexc("#3E423F"), seed=81)
    brick_wall(c, "L", gh, WH, hexc("#6A6D6A"), hexc("#3A3E3B"), seed=82)
    flood_line(c, "R", gw, z=260)
    flood_line(c, "L", gh, z=260)
    wall_edge(c, gw, gh, WH)
    concrete_floor(c, gw, gh, hexc("#666A66"), seed=83)
    flood_surround(c, gw, gh, seed=84)
    c.finish(out, sil=0)


def station(out):
    gw, gh = 10, 8
    c = _room(gw, gh, 91)
    underground(c, gw, gh, seed=141)
    brick_wall(c, "R", gw, WH, hexc("#2E4A4E"), hexc("#1A2A2C"), seed=91)
    brick_wall(c, "L", gh, WH, hexc("#2C474A"), hexc("#182628"), seed=92)
    flood_line(c, "R", gw, z=200)
    flood_line(c, "L", gh, z=200)
    wall_edge(c, gw, gh, WH)
    tile_floor(c, gw, gh, hexc("#3A4446"), hexc("#2E3638"), seed=93)
    c.finish(out, sil=0)


def kiao_raft(out):
    gw, gh = 10, 8
    c = _room(gw, gh, 101)
    skyline(c, gw, gh, seed=151)
    red = hexc("#8E2A24")
    plaster_wall(c, "R", gw, red, windows=(7.6,), poster=(2.6, "เงินด่วน", BRASS), seed=101)
    plaster_wall(c, "L", gh, red, windows=(3.0,), poster=(5.4, "ดอกไม่ด่วน", BRASS), seed=102)
    for side, length in (("R", gw), ("L", gh)):
        c.stroke([c.wp(side, 0, 150), c.wp(side, length, 150)], 6.0, BRASS, 0.9)
    wall_edge(c, gw, gh, WH)
    tile_floor(c, gw, gh, hexc("#7A2E26"), hexc("#B08A3A"), seed=103)
    flood_surround(c, gw, gh, seed=104)
    c.finish(out, sil=0)


ROOMS = {f.__name__: f for f in (home, pier, noodle_boat, stilts, boat_garage, old_gate, station, kiao_raft)}

if __name__ == "__main__":
    name = sys.argv[1]
    names = list(ROOMS) if name == "all" else [name]
    for n in names:
        out = sys.argv[2] if (len(sys.argv) > 2 and name != "all") else os.path.join(ROOT, n + ".png")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        ROOMS[n](out)
        print("wrote", out)
