"""Classic Bangkok tuk-tuk (blue body, red cowl+hood, standing windshield,
black rounded roof, twin headlamps, single front wheel, red bench, white
rails) with a copper boiler + chimney on the tail. Front faces down-left (+y).
Chimney top sits under the SteamVent in soi_brass.tscn (image x 378)."""
import math, sys
import numpy as np
from paint import *

W, H = 500, 580
c = Canvas(W, H, ss=3, seed=11)
p, s = c.p, c.ss
BLUE, BLUE_D = hexc("#2F55A0"), hexc("#1B3160")
TRED = hexc("#C8372D")
ROOF, ROOF_L = hexc("#2A2A30"), hexc("#45454F")
YEL = hexc("#F2C94C")
WHITE = hexc("#EDEDEA")

c.ground_shadow(1.0, 1.8)

# ---- far rear wheel ----
c.wheel(-0.56, -0.5, 30, 0.12, 30, axis="y")

# ---- tail boiler + chimney (behind the body) ----
BX, BY, BR = 0.14, -1.06, 0.27
c.cylinder(BX, BY, BR, 56, 196, COPPER, spec=0.9, rim=0.7, top_c=COPPER * 1.05)
c.band(BX, BY, BR, 76, 86, BRASS, spec=1.0)
c.band(BX, BY, BR, 150, 160, BRASS, spec=1.0)
for z in (81, 155):
    tx, ty = p(BX, BY, z)
    c.rivets([(tx + math.cos(t) * BR * 128 * s, ty + math.sin(t) * BR * 64 * s)
              for t in np.linspace(math.radians(25), math.radians(155), 6)], 2.3)
dx, dy = p(BX, BY, 196)
c.disc(dx, dy - 6 * s, BR * 128 * s * 0.8, BR * 64 * s * 0.8 + 8 * s, BRASS, 1.8, 0.7, spec=0.9)
cx0, cy0 = p(0.0, -1.0, 208)
c.pipe([(cx0, cy0 + 8 * s), (cx0, cy0 - 96 * s)], 13, SOOT * 1.8, spec=0.5)
c.band  # (chimney rings)
for k in (30, 70):
    c.disc(cx0, cy0 - k * s, 9.5 * s, 4 * s, BRASS, 1.0, 0.3, dome=False)
c.disc(cx0, cy0 - 98 * s, 12 * s, 5 * s, SOOT * 1.4, 1.4, 0.4, dome=False)
c.disc(cx0, cy0 - 98 * s, 7 * s, 2.6 * s, (0.05, 0.04, 0.05), 0.0, 0.0, dome=False)
# pressure gauge on the boiler's near side


# ---- chassis ----
c.box(-0.5, -0.9, 0.5, 0.6, 36, 60, SOOT * 1.4, rim=0.3)

# ---- rear passenger body ----
c.box(-0.5, -0.9, 0.5, -0.05, 60, 124, BLUE, rim=0.8, side_k=0.5)
# brass trim + rivets along the near side and the front of the cargo box
c.stroke([p(0.5, -0.9, 116), p(0.5, -0.05, 116)], 2.6, BRASS_D)
c.stroke([p(0.5, -0.9, 117.5), p(0.5, -0.05, 117.5)], 1.2, BRASS_L, 0.8)
c.rivets([p(0.5, gy_, 70) for gy_ in np.linspace(-0.85, -0.1, 7)], 2.2)
c.rivets([p(gx_, -0.05, 70) for gx_ in np.linspace(-0.45, 0.45, 6)], 2.2)
# copper steam feed from the tail boiler along the near side to the engine
c.pipe([p(0.5, -1.0, 74), p(0.53, -0.9, 74), p(0.53, 0.3, 74), p(0.4, 0.42, 52)], 9, COPPER, spec=1.0)
for gy_ in (-0.6, -0.2):
    c.disc(*p(0.53, gy_, 74), 6.5 * s, 7 * s, BRASS, 1.2, 0.3, spec=0.9)
c.gauge(*p(0.5, -0.7, 100), 10, angle=60)
# red pinstripe on the side
c.stroke([p(0.5, -0.55, 104), p(0.5, -0.09, 104)], 3.0, TRED, 0.95)

# ---- red bench + backrest ----
c.box(-0.42, -0.84, 0.42, -0.70, 124, 230, TRED * 0.85, rim=0.6, top_k=1.0)
c.box(-0.42, -0.72, 0.42, -0.26, 124, 148, TRED, rim=0.8)
# tufted seams on the backrest front
for gx_ in np.linspace(-0.3, 0.3, 4):
    c.stroke([p(gx_, -0.70, 140), p(gx_, -0.70, 222)], 1.2, TRED * 0.55, 0.8)

# ---- driver seat ----
c.box(-0.18, 0.04, 0.18, 0.34, 60, 108, SOOT * 1.6, rim=0.6)

# ---- front wheel + fork (under the nose) ----
c.pipe([p(0.0, 0.92, 70), p(0.0, 0.98, 30)], 8, STEEL * 0.7)
c.wheel(0.0, 0.98, 32, 0.12, 32, axis="y")

# ---- front cowl: blue rounded nose, red hood ----
nose = [(-0.5, 0.45), (0.5, 0.45), (0.42, 0.68), (0.30, 0.86)]
for t in np.linspace(math.radians(20), math.radians(160), 9):
    nose.append((math.cos(t) * 0.30, 0.86 + math.sin(t) * 0.17))
nose += [(-0.30, 0.86), (-0.42, 0.68)]
c.prism(nose, 44, 136, BLUE, side_only=True, rim=0.8, smooth=True)
hood = [(x * 1.03, 0.45 + (y - 0.45) * 1.03) for x, y in nose]
c.prism(hood, 136, 148, TRED, top_c=TRED * 1.05, rim=1.0)
# chrome bumper strip on the nose
c.stroke([p(0.30 * math.cos(t), 0.86 + 0.17 * math.sin(t), 60) for t in np.linspace(math.radians(15), math.radians(165), 14)],
         4.0, STEEL)
# twin headlamps
for gx_ in (-0.16, 0.16):
    hx, hy = p(gx_, 1.0, 104)
    c.disc(hx, hy, 15 * s, 16 * s, STEEL, 1.8, 0.6, spec=1.0)
    c.disc(hx, hy, 10.5 * s, 11.5 * s, hexc("#FFF4C8"), 1.0, 0.0, spec=1.0)
    c.glaze(ndimage.gaussian_filter(c.mask_ellipse(hx, hy, 13 * s, 14 * s), 5 * s), YEL, 0.35)
# brass gauge on the near side of the cowl
c.gauge(*p(0.47, 0.6, 100), 9, angle=-20)

# ---- windshield (standing, tilted back) ----
ws = [p(-0.38, 0.84, 148), p(0.38, 0.84, 148), p(0.36, 0.70, 246), p(-0.36, 0.70, 246)]
c.paint(c.mask_poly(ws), c.grad(TRED * 0.9, 1.1, 0.85), 2.2, 0.6)
gl = [p(-0.31, 0.83, 156), p(0.31, 0.83, 156), p(0.29, 0.71, 238), p(-0.29, 0.71, 238)]
c.paint(c.mask_poly(gl), c.grad(hexc("#4C5E78"), 1.25, 0.8), 1.4, 0.0, tex=0.04)
# reflections
for k, w in ((0.2, 7), (0.32, 3)):
    a1 = p(-0.29 + 0.58 * k, 0.83, 158)
    b1 = p(-0.29 + 0.58 * (k + 0.18), 0.71, 236)
    c.stroke([a1, b1], w, (1, 1, 1), 0.3)
# yellow visor strip
c.paint(c.mask_poly([p(-0.24, 0.73, 222), p(0.24, 0.73, 222), p(0.24, 0.73, 232), p(-0.24, 0.73, 232)]), c.flat(YEL), 1.2, 0)
# handlebar peeking over the hood
hx, hy = p(0.0, 0.55, 150)
c.pipe([(hx, hy), (hx + 4 * s, hy - 24 * s)], 6, STEEL * 0.7)
c.pipe([(hx - 28 * s, hy - 32 * s), (hx + 30 * s, hy - 20 * s)], 6, STEEL)

# ---- roof posts (white) ----
for gx_, gy_ in ((-0.5, -0.9), (0.5, -0.9), (-0.5, -0.05), (0.5, -0.05)):
    c.pipe([p(gx_, gy_, 124), p(gx_, gy_, 248)], 5, WHITE, spec=0.5)

# ---- white side rails (near side) ----
for z in (154, 178):
    c.pipe([p(0.5, -0.9, z), p(0.5, -0.05, z)], 4.5, WHITE, spec=0.5)
for gy_ in (-0.9, -0.48, -0.05):
    c.pipe([p(0.5, gy_, 124), p(0.5, gy_, 178)], 4.5, WHITE, spec=0.5)

# ---- near rear wheel + mudguard ----
c.wheel(0.56, -0.5, 30, 0.12, 30, axis="y")
guard = [p(0.56, -0.5 + math.cos(t) * 0.15, 30 + math.sin(t) * 38) for t in np.linspace(0.15, math.pi - 0.15, 14)]
c.pipe(guard, 7, BLUE_D, spec=0.4)

# ---- black rounded roof ----
r = 0.12
X0, X1, Y0, Y1 = -0.55, 0.55, -0.98, 0.86
roof = []
for (cxr, cyr, a0) in ((X1 - r, Y1 - r, 0), (X0 + r, Y1 - r, 90), (X0 + r, Y0 + r, 180), (X1 - r, Y0 + r, 270)):
    for t in np.linspace(math.radians(a0), math.radians(a0 + 90), 6):
        roof.append((cxr + math.cos(t) * r, cyr + math.sin(t) * r))
c.prism(roof, 248, 262, ROOF, top_c=ROOF_L, rim=1.0)
# soft dome highlight + seam
c.glaze(ndimage.gaussian_filter(c.mask_poly([p(-0.42, 0.7, 262), p(-0.42, -0.86, 262), p(0.0, -0.86, 262), p(0.0, 0.7, 262)]), 8 * s),
        (1, 1, 1), 0.10)
c.stroke([p(0.0, -0.94, 262), p(0.0, 0.82, 262)], 1.2, (0, 0, 0), 0.35)
# amber roof light at the front
lx, ly = p(0.0, 0.62, 262)
c.disc(lx, ly - 4 * s, 20 * s, 9 * s, YEL, 1.6, 0.6, spec=1.0)

c.finish(sys.argv[1] if len(sys.argv) > 1 else "steam_tuk_tuk.png")
print("ok")
