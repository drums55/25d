"""Painted room backdrops (floor + two back walls) for IsoRoom.

Usage:  python3 tools/art/png/room.py soi_brass|steam_market [out.png]

The image covers exactly IsoRoom.get_backdrop_rect(): x from -grid_w*64 to
+grid_w*64, y from -wall_height to (grid_w+grid_h)*32 (game px), authored at
2x. Image px: X = (room_x + grid_w*64)*2, Y = (room_y + wall_h)*2. The game
stretches the texture onto that rect, so the ratio is what matters.

Room space here: p(gx, gy, z) with gx down-right, gy down-left, z up in
image px (same convention as paint.py but with the origin at the room's top
corner instead of a prop foot).
"""
import math
import os
import sys

import numpy as np
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from paint import (BRASS, BRASS_D, BRASS_L, COPPER, CREAM, LIGHT, OUT, RED, SOOT, STEEL,  # noqa: E402
                   WARM, WOOD, Canvas, hexc)

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "..", "assets", "art", "rooms")


class RoomCanvas(Canvas):
    def __init__(self, gw, gh, wall_h, ss=2, seed=11):
        self.gw, self.gh, self.wall_h = gw, gh, wall_h
        w = gw * 128 * 2
        h = (wall_h + (gw + gh) * 32) * 2
        super().__init__(w, h, ss=ss, seed=seed)

    def p(self, gx, gy, z=0.0):
        s = self.ss
        return ((self.gw * 128 + (gx - gy) * 128) * s, (self.wall_h * 2 + (gx + gy) * 64 - z) * s)

    # wall helpers: side "R" = back-right wall (along gx, gy=0), "L" = back-left (along gy, gx=0)
    def wp(self, side, u, z):
        return self.p(u, 0, z) if side == "R" else self.p(0, u, z)

    def wall_quad(self, side, u0, u1, z0, z1):
        return [self.wp(side, u0, z0), self.wp(side, u1, z0), self.wp(side, u1, z1), self.wp(side, u0, z1)]

    # ---- cropped versions of the heavy whole-canvas ops (room canvases are
    # ~6 Mpx; every element only touches a small window) ----
    def _bbox(self, m, pad):
        ys, xs = np.nonzero(m > 1e-3)
        if ys.size == 0:
            return None
        pad = int(pad * self.ss) + 2
        return (max(0, ys.min() - pad), min(self.H, ys.max() + pad + 1),
                max(0, xs.min() - pad), min(self.W, xs.max() + pad + 1))

    def paint(self, mask, field, outline=2.2, rim=0.0, rim_col=WARM, tex=0.075, ao=None):
        m = np.clip(mask, 0, 1)
        bb = self._bbox(m, max(outline, 4) + 4)
        if bb is None:
            return m
        y0, y1, x0, x1 = bb
        mm = m[y0:y1, x0:x1]
        fld = field[y0:y1, x0:x1] if field.shape[0] == self.H else field
        col = fld * (1.0 + tex * self.tex[y0:y1, x0:x1])[..., None]
        if ao is not None:
            col = col * ao[y0:y1, x0:x1][..., None]
        s = self.ss
        if rim > 0:
            sh = ndimage.shift(mm, (3.2 * s, 2.6 * s), order=1)
            edge = ndimage.gaussian_filter(np.clip(mm - sh, 0, 1), 0.8 * s) * mm
            col = col + (rim_col[None, None, :] - col) * (np.clip(edge * 1.6, 0, 1) * rim)[..., None]
        if outline > 0:
            er = ndimage.binary_erosion(mm > 0.5, iterations=max(1, int(outline * s)))
            ring = np.clip(mm - ndimage.gaussian_filter(er.astype(np.float32), 0.6 * s), 0, 1)
            col = col * (1 - ring[..., None]) + np.array(OUT, np.float32)[None, None, :] / 255.0 * ring[..., None]
        self.rgb[y0:y1, x0:x1] = self.rgb[y0:y1, x0:x1] * (1 - mm[..., None]) + col * mm[..., None]
        self.a[y0:y1, x0:x1] = self.a[y0:y1, x0:x1] + mm * (1 - self.a[y0:y1, x0:x1])
        return m

    def glaze(self, mask, c, alpha):
        m = np.clip(mask, 0, 1)
        bb = self._bbox(m, 1)
        if bb is None:
            return
        y0, y1, x0, x1 = bb
        mm = m[y0:y1, x0:x1] * alpha * (self.a[y0:y1, x0:x1] > 0)
        self.rgb[y0:y1, x0:x1] = self.rgb[y0:y1, x0:x1] * (1 - mm[..., None]) + np.asarray(c)[None, None, :] * mm[..., None]

    def stroke(self, pts, width, c, alpha=1.0):
        m = self.mask_line(pts, width * self.ss) * alpha
        bb = self._bbox(m, 1)
        if bb is None:
            return
        y0, y1, x0, x1 = bb
        mm = m[y0:y1, x0:x1]
        self.rgb[y0:y1, x0:x1] = self.rgb[y0:y1, x0:x1] * (1 - mm[..., None]) + np.asarray(c)[None, None, :] * mm[..., None]
        self.a[y0:y1, x0:x1] = self.a[y0:y1, x0:x1] + mm * (1 - self.a[y0:y1, x0:x1])

    def pipe(self, pts, width, c, spec=0.8, outline=2.0):
        m = self.mask_line(pts, width * self.ss)
        bb = self._bbox(m, width)
        if bb is None:
            return m
        y0, y1, x0, x1 = bb
        cl = (self.mask_line(pts, 1.5 * self.ss) > 0.5)[y0:y1, x0:x1]
        dist, idx = ndimage.distance_transform_edt(~cl, return_indices=True)
        yy, xx = np.mgrid[0:y1 - y0, 0:x1 - x0].astype(np.float32)
        rr = width * self.ss / 2
        nx, ny = (xx - idx[1]) / rr, (yy - idx[0]) / rr
        nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
        lam = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
        col = np.asarray(c)[None, None, :] * (0.4 + 0.8 * lam)[..., None]
        col = col + (WARM[None, None, :] - col) * (lam ** 24 * spec)[..., None]
        full = np.zeros((self.H, self.W, 3), np.float32)
        full[y0:y1, x0:x1] = np.clip(col, 0, 1)
        self.paint(m, full, outline, 0.2, tex=0.03)
        return m

    def disc(self, cx, cy, rx, ry, c, outline=1.8, rim=0.5, dome=True, spec=0.6, tex=0.04):
        m = self.mask_ellipse(cx, cy, rx, ry)
        bb = self._bbox(m, outline + 4)
        if bb is None:
            return m
        y0, y1, x0, x1 = bb
        full = np.zeros((self.H, self.W, 3), np.float32)
        if dome:
            yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
            nx = np.clip((xx - cx) / rx, -1, 1)
            ny = np.clip((yy - cy) / ry, -1, 1)
            nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
            lam = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
            col = np.asarray(c)[None, None, :] * (0.45 + 0.75 * lam)[..., None]
            col = col + (WARM[None, None, :] - col) * (lam ** 30 * spec)[..., None]
            full[y0:y1, x0:x1] = np.clip(col, 0, 1)
        else:
            full = self.grad(c, 1.1, 0.85, cy - ry, cy + ry, cx - rx, cx + rx)
        self.paint(m, full, outline, rim, tex=tex)
        return m

    def noise(self, sigma, seed=3):
        rng = np.random.default_rng(seed)
        n = rng.standard_normal((self.H, self.W)).astype(np.float32)
        n = ndimage.gaussian_filter(n, sigma * self.ss)
        return n / (n.std() + 1e-6)


def shophouse_wall(c, side, length, wall_h, plaster, door_u=None, seed=1):
    """A row of Bangkok shophouse ground floors along one back wall."""
    s = c.ss
    rng = np.random.default_rng(seed)
    H = wall_h * 2  # image px
    k_face = 1.0 if side == "L" else 0.78  # the right wall faces away from the light
    # plaster, stained low down
    face = c.mask_poly(c.wall_quad(side, 0, length, 0, H))
    ytop = min(q[1] for q in c.wall_quad(side, 0, length, 0, H))
    ybot = max(q[1] for q in c.wall_quad(side, 0, length, 0, H))
    field = c.grad(plaster, k_face * 1.08, k_face * 0.78, ytop, ybot)
    stain = np.clip(c.noise(40, seed + 7) * 0.6 + c.noise(12, seed + 8) * 0.2, -1, 1)
    field = field * (1 + 0.07 * stain)[..., None]
    c.paint(face, field, outline=0, tex=0.05)
    # grime band + brass steam pipe along the base
    base = c.mask_poly(c.wall_quad(side, 0, length, 0, 46))
    c.glaze(base, SOOT, 0.22)
    c.pipe([c.wp(side, 0, 30), c.wp(side, length, 30)], 9, COPPER, spec=0.7)
    for u in np.arange(0.5, length, 1.0):
        x, y = c.wp(side, u, 30)
        c.disc(x, y, 7 * s, 7 * s, BRASS, 1.0, 0.3)
    # units: shutter, window, signboard, aircon
    u = 0.15
    unit_w = 2.9
    i = 0
    while u + unit_w <= length + 0.01:
        u0, u1 = u, u + unit_w
        # pilaster between units
        c.prism_wall(side, u1 - 0.12, u1 + 0.12, 0, H - 20, plaster * 0.92)
        is_door = door_u is not None and u0 <= door_u <= u1
        # roll-up shutter (steel) or alley opening where the game draws the door
        su0, su1 = u0 + 0.35, u0 + 1.75
        if is_door:
            op0, op1 = door_u - 0.5, door_u + 0.5
            c.paint(c.mask_poly(c.wall_quad(side, op0, op1, 0, 300)), c.flat(SOOT * 0.6), 2.0)
            c.paint(c.mask_poly(c.wall_quad(side, op0 - 0.1, op1 + 0.1, 300, 330)), c.flat(BRASS_D), 1.6, 0.5)
            su0, su1 = u0 + 0.3, min(op0 - 0.15, u0 + 1.3) if op0 - 0.15 > u0 + 0.6 else (op1 + 0.15, u1 - 0.3)
            if isinstance(su1, tuple):
                su0, su1 = su1
        shut_h = 250
        shutter_col = [hexc("#5B6B74"), hexc("#7A6450"), hexc("#4F6A62"), hexc("#6E5A6A")][i % 4]
        sm = c.mask_poly(c.wall_quad(side, su0, su1, 0, shut_h))
        c.paint(sm, c.grad(shutter_col * k_face, 1.05, 0.8, ytop, ybot), 2.0, 0.3, tex=0.08)
        for z in range(18, shut_h - 10, 22):
            c.stroke([c.wp(side, su0 + 0.03, z), c.wp(side, su1 - 0.03, z)], 1.6, shutter_col * 0.55 * k_face, 0.9)
        c.stroke([c.wp(side, su0, shut_h - 6), c.wp(side, su1, shut_h - 6)], 3.0, WARM * 0.9, 0.35)
        # signboard above the shutter
        sb = c.mask_poly(c.wall_quad(side, su0 - 0.05, su1 + 0.05, shut_h + 14, shut_h + 84))
        sign_col = [RED, hexc("#2F5FD0"), hexc("#D1A126"), hexc("#3F7A74")][i % 4]
        c.paint(sb, c.grad(sign_col * k_face, 1.1, 0.85, ytop, ybot), 2.0, 0.6, tex=0.06)
        for k in range(2):
            z = shut_h + 36 + k * 24
            c.stroke([c.wp(side, su0 + 0.2, z), c.wp(side, su1 - 0.2 - rng.uniform(0, 0.6), z)], 6.0, CREAM, 0.85)
        # barred window on the upper part
        wu0, wu1 = u0 + 1.95, u0 + 2.65
        wm = c.mask_poly(c.wall_quad(side, wu0, wu1, 120, 300))
        c.paint(wm, c.grad(hexc("#1E2A33"), 1.3, 0.8, ytop, ybot), 2.2, 0.0)
        c.glaze(c.mask_poly(c.wall_quad(side, wu0 + 0.05, wu1 - 0.05, 200, 295)), WARM, 0.18)
        for k in range(4):
            uu = wu0 + 0.14 * (k + 1)
            c.stroke([c.wp(side, uu, 122), c.wp(side, uu, 298)], 2.2, STEEL * 0.8)
        c.stroke([c.wp(side, wu0 - 0.04, 300), c.wp(side, wu1 + 0.04, 300)], 5, plaster * 0.7)
        c.stroke([c.wp(side, wu0 - 0.04, 118), c.wp(side, wu1 + 0.04, 118)], 5, plaster * 0.7)
        # air-con box with brass pipe
        if i % 2 == 0:
            au0, au1 = u0 + 1.95, u0 + 2.55
            am = c.mask_poly(c.wall_quad(side, au0, au1, 330, 400))
            c.paint(am, c.grad(CREAM * 0.9 * k_face, 1.05, 0.8, ytop, ybot), 2.0, 0.5)
            for z in range(340, 395, 11):
                c.stroke([c.wp(side, au0 + 0.04, z), c.wp(side, au1 - 0.04, z)], 1.4, SOOT, 0.35)
            c.pipe([c.wp(side, au1, 345), c.wp(side, au1 + 0.12, 345), c.wp(side, au1 + 0.12, 40)], 6, COPPER, spec=0.6)
        else:
            # lantern on a bracket
            lx, ly = c.wp(side, u0 + 2.3, 360)
            c.stroke([c.wp(side, u0 + 2.3, 400), (lx, ly)], 4, SOOT)
            c.disc(lx, ly + 8 * s, 11 * s, 14 * s, BRASS_L, 1.6, 0.4, spec=1.0)
            c.glaze(c.mask_ellipse(lx, ly + 10 * s, 40 * s, 40 * s), WARM, 0.12)
        u += unit_w
        i += 1
    # cables sagging along the top of the wall
    for k in range(3):
        pts = [c.wp(side, uu, H - 8 - k * 9 - 14 * math.sin(math.pi * (uu / length)) ) for uu in np.linspace(0, length, 24)]
        c.stroke(pts, 1.8, SOOT, 0.9)


def _prism_wall(self, side, u0, u1, z0, z1, col):
    m = self.mask_poly(self.wall_quad(side, u0, u1, z0, z1))
    yt = min(q[1] for q in self.wall_quad(side, u0, u1, z0, z1))
    self.paint(m, self.grad(col, 1.1, 0.85, yt, yt + z1 * self.ss), 1.6, 0.4, tex=0.08)


RoomCanvas.prism_wall = _prism_wall


def concrete_floor(c, gw, gh, base, seed=5):
    s = c.ss
    floor = c.mask_poly([c.p(0, 0), c.p(gw, 0), c.p(gw, gh), c.p(0, gh)])
    yt = c.p(0, 0)[1]
    yb = c.p(gw, gh)[1]
    field = c.grad(base, 1.0, 0.82, yt, yb)
    n = np.clip(c.noise(45, seed) * 0.65 + c.noise(10, seed + 1) * 0.25, -1, 1)
    field = field * (1 + 0.08 * n)[..., None]
    c.paint(floor, field, outline=0, tex=0.06)
    # slab joints every 2 cells (both axes)
    for k in range(2, gw, 2):
        c.stroke([c.p(k, 0), c.p(k, gh)], 2.2, base * 0.55, 0.55)
    for k in range(2, gh, 2):
        c.stroke([c.p(0, k), c.p(gw, k)], 2.2, base * 0.55, 0.55)
    # drain channel along the middle of the gy axis with a grate
    du = gw * 0.5
    c.stroke([c.p(du - 0.12, 0.3), c.p(du - 0.12, gh - 0.3)], 10, base * 0.6, 0.9)
    c.stroke([c.p(du + 0.12, 0.3), c.p(du + 0.12, gh - 0.3)], 10, base * 0.6, 0.9)
    for v in np.arange(0.6, gh - 0.4, 0.35):
        c.stroke([c.p(du - 0.1, v), c.p(du + 0.1, v)], 2.0, SOOT, 0.55)
    # cracks + stains
    rng = np.random.default_rng(seed + 9)
    for _ in range(14):
        gx, gy = rng.uniform(0.5, gw - 0.5), rng.uniform(0.5, gh - 0.5)
        pts = [c.p(gx, gy)]
        for _k in range(rng.integers(2, 5)):
            gx += rng.uniform(-0.6, 0.6)
            gy += rng.uniform(-0.6, 0.6)
            pts.append(c.p(gx, gy))
        c.stroke(pts, 1.6, base * 0.5, 0.7)
    for _ in range(9):
        gx, gy = rng.uniform(0.6, gw - 0.6), rng.uniform(0.6, gh - 0.6)
        x, y = c.p(gx, gy)
        m = ndimage.gaussian_filter(c.mask_ellipse(x, y, rng.uniform(40, 120) * s, rng.uniform(20, 60) * s), 6 * s)
        c.glaze(m * floor, SOOT if rng.random() < 0.6 else COPPER * 0.7, rng.uniform(0.08, 0.2))
    # manhole
    x, y = c.p(gw * 0.3, gh * 0.72)
    c.disc(x, y, 54 * s, 27 * s, STEEL * 0.55, 2.0, 0.2, dome=False)
    for k in range(5):
        c.stroke([(x - 40 * s + k * 20 * s, y - 14 * s), (x - 30 * s + k * 20 * s, y + 14 * s)], 1.6, SOOT, 0.6)
    # ambient occlusion where the floor meets the back walls
    ao = np.maximum(c.mask_poly([c.p(0, 0), c.p(gw, 0), c.p(gw, 0.9), c.p(0, 0.9)]),
                    c.mask_poly([c.p(0, 0), c.p(0, gh), c.p(0.9, gh), c.p(0.9, 0)]))
    ao = ndimage.gaussian_filter(ao, 24 * s) * floor
    c.glaze(ao, SOOT, 0.45)
    # warm lantern pools on the floor
    for gx, gy in ((gw * 0.25, 0.9), (gw * 0.75, 0.9), (0.9, gh * 0.4)):
        x, y = c.p(gx, gy)
        m = ndimage.gaussian_filter(c.mask_ellipse(x, y + 30 * s, 150 * s, 70 * s), 30 * s)
        c.glaze(m * floor, WARM, 0.10)


def brick_wall(c, side, length, wall_h, brick, mortar, door_u=None, seed=2):
    s = c.ss
    H = wall_h * 2
    k_face = 1.0 if side == "L" else 0.78
    quad = c.wall_quad(side, 0, length, 0, H)
    face = c.mask_poly(quad)
    yt, yb = min(q[1] for q in quad), max(q[1] for q in quad)
    field = c.grad(mortar, k_face * 1.05, k_face * 0.8, yt, yb)
    c.paint(face, field, outline=0, tex=0.05)
    rng = np.random.default_rng(seed)
    bh, bw = 26, 0.42
    row = 0
    for z in range(0, H - bh, bh + 4):
        off = (row % 2) * bw / 2
        u = -off
        while u < length:
            u0, u1 = max(u, 0), min(u + bw, length)
            if u1 - u0 > 0.05 and not (door_u is not None and u1 > door_u - 0.55 and u0 < door_u + 0.55 and z < 300):
                m = c.mask_poly(c.wall_quad(side, u0 + 0.015, u1 - 0.015, z + 2, z + bh - 2))
                tone = brick * (0.85 + 0.3 * rng.random()) * k_face
                c.paint(m, c.grad(tone, 1.06, 0.9, yt, yb), 1.2, 0.25 if rng.random() < 0.3 else 0, tex=0.1)
            u += bw + 0.03
        row += 1
    if door_u is not None:
        c.paint(c.mask_poly(c.wall_quad(side, door_u - 0.5, door_u + 0.5, 0, 300)), c.flat(SOOT * 0.6), 2.0)
        c.paint(c.mask_poly(c.wall_quad(side, door_u - 0.62, door_u + 0.62, 300, 334)), c.flat(WOOD * 0.8), 1.8, 0.4)
    # grime low, soot high around lanterns; pipes + lanterns
    c.glaze(c.mask_poly(c.wall_quad(side, 0, length, 0, 60)), SOOT, 0.3)
    c.pipe([c.wp(side, 0, 36), c.wp(side, length, 36)], 9, COPPER, spec=0.7)
    for u in np.arange(0.5, length, 1.0):
        x, y = c.wp(side, u, 36)
        c.disc(x, y, 7 * s, 7 * s, BRASS, 1.0, 0.3)
    for u in np.arange(1.2, length, 2.5):
        lx, ly = c.wp(side, u, 380)
        c.stroke([c.wp(side, u, 420), (lx, ly)], 4, SOOT)
        c.disc(lx, ly + 8 * s, 11 * s, 14 * s, BRASS_L, 1.6, 0.4, spec=1.0)
        c.glaze(c.mask_ellipse(lx, ly + 10 * s, 50 * s, 50 * s), WARM, 0.14)
        c.glaze(ndimage.gaussian_filter(c.mask_ellipse(lx, ly - 40 * s, 30 * s, 40 * s), 10 * s), SOOT, 0.3)
    # a poster / banner
    bm = c.mask_poly(c.wall_quad(side, length * 0.55, length * 0.55 + 0.9, 150, 290))
    c.paint(bm, c.grad(CREAM * 0.9 * k_face, 1.05, 0.85, yt, yb), 1.8, 0.3)
    for k in range(4):
        z = 170 + k * 28
        c.stroke([c.wp(side, length * 0.55 + 0.12, z), c.wp(side, length * 0.55 + 0.9 - 0.1 - 0.2 * (k % 2), z)], 5.0, RED * 0.9, 0.8)


def tile_floor(c, gw, gh, tile_a, tile_b, seed=4):
    s = c.ss
    floor = c.mask_poly([c.p(0, 0), c.p(gw, 0), c.p(gw, gh), c.p(0, gh)])
    yt = c.p(0, 0)[1]
    yb = c.p(gw, gh)[1]
    c.paint(floor, c.grad(tile_b * 0.8, 1.0, 0.85, yt, yb), outline=0, tex=0.1)
    rng = np.random.default_rng(seed)
    for gx in range(gw):
        for gy in range(gh):
            col = tile_a if (gx + gy) % 2 == 0 else tile_b
            col = col * (0.9 + 0.2 * rng.random())
            m = c.mask_poly([c.p(gx + 0.04, gy + 0.04), c.p(gx + 0.96, gy + 0.04), c.p(gx + 0.96, gy + 0.96), c.p(gx + 0.04, gy + 0.96)])
            c.paint(m, c.grad(col, 1.04, 0.92, yt, yb), 1.4, 0.2 if rng.random() < 0.25 else 0, tex=0.12)
    for _ in range(10):
        gx, gy = rng.uniform(0.6, gw - 0.6), rng.uniform(0.6, gh - 0.6)
        x, y = c.p(gx, gy)
        m = ndimage.gaussian_filter(c.mask_ellipse(x, y, rng.uniform(40, 110) * s, rng.uniform(20, 55) * s), 6 * s)
        c.glaze(m * floor, SOOT, rng.uniform(0.08, 0.18))
    ao = np.maximum(c.mask_poly([c.p(0, 0), c.p(gw, 0), c.p(gw, 0.9), c.p(0, 0.9)]),
                    c.mask_poly([c.p(0, 0), c.p(0, gh), c.p(0.9, gh), c.p(0.9, 0)]))
    c.glaze(ndimage.gaussian_filter(ao, 24 * s) * floor, SOOT, 0.45)
    for gx, gy in ((gw * 0.3, 0.9), (gw * 0.7, 0.9), (0.9, gh * 0.5)):
        x, y = c.p(gx, gy)
        c.glaze(ndimage.gaussian_filter(c.mask_ellipse(x, y + 30 * s, 150 * s, 70 * s), 30 * s) * floor, WARM, 0.12)


def wall_edge(c, gw, gh, wall_h):
    """Dark corner seam + a bright top edge so the walls read as two planes."""
    H = wall_h * 2
    c.stroke([c.p(0, 0, 0), c.p(0, 0, H)], 4, SOOT, 0.7)
    c.stroke([c.p(0, gh, H), c.p(0, 0, H), c.p(gw, 0, H)], 3, WARM * 0.9, 0.35)


def soi_brass(out):
    gw, gh, wh = 12, 12, 240
    c = RoomCanvas(gw, gh, wh, ss=1)
    mint = hexc("#5E8F86")
    # right wall first (lit less), then left wall overlaps the corner seam
    shophouse_wall(c, "R", gw, wh, mint * 0.95, door_u=5.65, seed=1)
    shophouse_wall(c, "L", gh, wh, mint, seed=2)
    wall_edge(c, gw, gh, wh)
    concrete_floor(c, gw, gh, hexc("#7C736B"))
    c.finish(out, sil=0)


def steam_market(out):
    gw, gh, wh = 10, 8, 240
    c = RoomCanvas(gw, gh, wh, ss=1)
    brick, mortar = hexc("#7A3E2E"), hexc("#4A2A24")
    brick_wall(c, "R", gw, wh, brick, mortar, seed=3)
    brick_wall(c, "L", gh, wh, brick, mortar, door_u=3.65, seed=4)
    wall_edge(c, gw, gh, wh)
    tile_floor(c, gw, gh, hexc("#8A5A3C"), hexc("#6B4530"))
    c.finish(out, sil=0)


ROOMS = {"soi_brass": soi_brass, "steam_market": steam_market}

if __name__ == "__main__":
    name = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, name + ".png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    ROOMS[name](out)
    print("wrote", out)
