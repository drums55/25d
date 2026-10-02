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


def _room(gw, gh, seed):
    return RoomCanvas(gw, gh, WH, ss=1, seed=seed)


def home(out):
    gw, gh = 10, 8
    c = _room(gw, gh, 31)
    plaster_wall(c, "R", gw, hexc("#6E9A8E"), windows=(3.0,), poster=(6.6, "ปลดหนี้ใน 7 วัน!", hexc("#C0392B")), seed=31)
    plaster_wall(c, "L", gh, hexc("#6E9A8E"), windows=(4.2,), seed=32)
    wall_edge(c, gw, gh, WH)
    plank_floor(c, gw, gh, hexc("#8B6038"), seed=33)
    flood_surround(c, gw, gh, seed=34)
    c.finish(out, sil=0)


def pier(out):
    gw, gh = 12, 9
    c = _room(gw, gh, 41)
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
    zinc_wall(c, "R", gw, WH, hexc("#C8642E"), seed=51)
    zinc_wall(c, "L", gh, WH, hexc("#D2703A"), seed=52)
    wall_edge(c, gw, gh, WH)
    plank_floor(c, gw, gh, hexc("#9A6A3E"), seed=53)
    flood_surround(c, gw, gh, seed=54)
    c.finish(out, sil=0)


def stilts(out):
    gw, gh = 12, 9
    c = _room(gw, gh, 61)
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
