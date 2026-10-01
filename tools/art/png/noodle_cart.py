import math, sys
import numpy as np
from paint import *

W, H = 420, 490
c = Canvas(W, H, ss=3)
p, s = c.p, c.ss
X0, X1, Y0, Y1 = -0.78, 0.78, -0.42, 0.42
RED_D = hexc("#8E2A20")
GREEN, GREEN_L = hexc("#3F7A74"), hexc("#6FA89C")


def wheel(gx, gy, zc, r_cells, r_z, spokes=True):
    """Wheel in the x-z plane at depth gy."""
    def ring(k):
        return [p(gx + math.cos(t) * r_cells * k, gy, zc + math.sin(t) * r_z * k)
                for t in np.linspace(0, 2 * math.pi, 64, endpoint=False)]
    tyre = c.mask_poly(ring(1.0))
    cx, cy = p(gx, gy, zc)
    c.paint(tyre, c.grad(SOOT * 1.3, 1.2, 0.7, cy - r_z * s, cy + r_z * s), 2.2, 0.5)
    rim = c.mask_poly(ring(0.78))
    c.paint(rim, c.grad(STEEL * 0.55, 1.1, 0.8, cy - r_z * s, cy + r_z * s), 1.4, 0.2)
    if spokes:
        for t in np.linspace(0, math.pi, 6, endpoint=False):
            a = p(gx + math.cos(t) * r_cells * 0.76, gy, zc + math.sin(t) * r_z * 0.76)
            b = p(gx - math.cos(t) * r_cells * 0.76, gy, zc - math.sin(t) * r_z * 0.76)
            c.stroke([a, b], 1.6, STEEL * 0.95)
    inner = c.mask_poly(ring(0.62))
    c.glaze(inner, SOOT, 0.25)
    c.disc(cx, cy, 7 * s, 9 * s, BRASS, 1.2, 0.3, spec=1.0)
    # tyre rim light (top-left arc)
    c.stroke([p(gx + math.cos(t) * r_cells * 0.93, gy, zc + math.sin(t) * r_z * 0.93)
              for t in np.linspace(math.radians(110), math.radians(200), 12)], 1.6, WARM * 0.8, 0.6)


c.ground_shadow(1.6, 0.9)

# ---- far wheel (mostly hidden) ----
wheel(-0.45, Y0 - 0.02, 50, 0.21, 50, spokes=False)

# ---- chassis / undercarriage ----
c.box(X0 + 0.06, Y0 + 0.04, X1 - 0.06, Y1 - 0.04, 18, 34, SOOT * 1.4, rim=0.3)
# back legs (prop stand at the handle end)
for gy in (Y0 + 0.08, Y1 - 0.08):
    c.pipe([p(X1 - 0.1, gy, 34), p(X1 - 0.06, gy, 2)], 7, SOOT * 1.6, spec=0.3)

# ---- red body ----
mf, ms, mt = c.box(X0, Y0, X1, Y1, 34, 132, RED, rim=0.7)

# front panel inset with brass trim
def fp(u, z):  # u: 0..1 along the front face (left->right)
    return p(X0 + (X1 - X0) * u, Y1, z)

inset = [fp(0.06, 48), fp(0.94, 48), fp(0.94, 118), fp(0.06, 118)]
c.paint(c.mask_poly(inset), c.grad(RED * 0.82, 1.0, 0.85), 0.0, 0)
c.stroke([fp(0.06, 48), fp(0.94, 48), fp(0.94, 118), fp(0.06, 118), fp(0.06, 48)], 3.0, BRASS_D)
c.stroke([fp(0.06, 118.6), fp(0.94, 118.6)], 1.6, BRASS_L, 0.9)
c.stroke([fp(0.06, 48), fp(0.06, 118)], 1.4, BRASS_L, 0.7)
# cream ornamental stripe with little painted lozenges (no text)
c.paint(c.mask_poly([fp(0.62, 92), fp(0.94, 92), fp(0.94, 104), fp(0.62, 104)]), c.grad(CREAM, 1.0, 0.9), 0.9, 0)
for u in np.linspace(0.66, 0.90, 4):
    cx, cy = fp(u, 98)
    c.paint(c.mask_poly([(cx - 9 * s, cy), (cx, cy - 4 * s), (cx + 9 * s, cy), (cx, cy + 4 * s)]), c.flat(RED), 0, 0)
# firebox door under the pot (glowing grate) on the left of the front face
fb = [fp(0.36, 54), fp(0.58, 54), fp(0.58, 88), fp(0.36, 88)]
c.paint(c.mask_poly(fb), c.flat(SOOT * 1.1), 1.6, 0)
gl = [fp(0.39, 58), fp(0.55, 58), fp(0.55, 80), fp(0.39, 80)]
gx_, gy_ = fp(0.47, 68)
glow_field = c.flat(hexc("#FFB347"))
glow_field = glow_field * (0.75 + 0.5 * np.clip(1 - np.hypot(c.xx - gx_, c.yy - gy_) / (30 * s), 0, 1))[..., None]
c.paint(c.mask_poly(gl), np.clip(glow_field, 0, 1), 0.8, 0, tex=0.15)
for u in np.linspace(0.405, 0.535, 5):
    c.stroke([fp(u, 58), fp(u, 80)], 1.6, SOOT)
c.stroke([fp(0.36, 88), fp(0.58, 88)], 2.0, BRASS)
# orange spill light on the face below the firebox
spill = c.mask_ellipse(gx_, gy_ + 26 * s, 34 * s, 16 * s)
c.glaze(ndimage.gaussian_filter(spill * mf, 6 * s), hexc("#FF9A3C"), 0.35)
# gauge on the front face
gx2, gy2 = fp(0.24, 104)
c.gauge(gx2, gy2, 9)
# rivets along trims
c.rivets([fp(u, 126) for u in np.linspace(0.04, 0.96, 9)], 2.6)
c.rivets([fp(u, 40) for u in np.linspace(0.04, 0.96, 9)], 2.4)
# side (+x) face: handle bar + trim
c.stroke([p(X1, Y0 + 0.05, 126), p(X1, Y1 - 0.05, 126)], 2.0, BRASS_D)
c.rivets([p(X1, gy, 126) for gy in np.linspace(Y0 + 0.08, Y1 - 0.08, 5)], 2.4)
for gy in (Y0 + 0.12, Y1 - 0.12):
    c.pipe([p(X1, gy, 112), p(X1 + 0.22, gy, 112), p(X1 + 0.26, gy, 116)], 6, STEEL * 0.9)
c.pipe([p(X1 + 0.25, Y0 + 0.08, 116), p(X1 + 0.25, Y1 - 0.08, 116)], 8, COPPER, spec=0.9)

# ---- stainless counter top ----
c.box(X0 - 0.03, Y0 - 0.03, X1 + 0.03, Y1 + 0.03, 132, 142, STEEL, rim=1.0, top_k=1.05, front_k=0.95, side_k=0.6)
# brushed-steel streaks on the top
for i in range(10):
    t = c.rng.uniform(-0.35, 0.35)
    a = p(X0 + 0.1, t, 142)
    b = p(X1 - 0.1, t, 142)
    c.stroke([a, b], 0.8, (1, 1, 1), 0.12)

# ---- glass display case (right half, back) ----
gx0, gx1, gy0, gy1, z0, z1 = 0.08, 0.72, -0.40, 0.02, 142, 214
# back panes (darker), contents (noodle bundles), then front glass
back = [p(gx0, gy0, z0), p(gx1, gy0, z0), p(gx1, gy0, z1), p(gx0, gy0, z1)]
c.paint(c.mask_poly(back), c.grad(hexc("#3B4A4D"), 1.0, 0.8), 1.4, 0)
for i, gx in enumerate(np.linspace(gx0 + 0.1, gx1 - 0.12, 4)):
    col = [hexc("#F1E2B0"), hexc("#E9C46A"), hexc("#F4ECD8"), hexc("#D9A441")][i]
    bx, by = p(gx, -0.2, 160)
    c.disc(bx, by, 17 * s, 9 * s, col, 1.2, 0.4, spec=0.2)
    c.disc(bx, by - 8 * s, 14 * s, 7 * s, col * 1.05, 1.0, 0.3, spec=0.2)
glass = [p(gx0, gy1, z0), p(gx1, gy1, z0), p(gx1, gy0, z0), p(gx1, gy0, z1), p(gx1, gy1, z1), p(gx0, gy1, z1)]
gm = c.mask_poly([p(gx0, gy1, z0), p(gx1, gy1, z0), p(gx1, gy1, z1), p(gx0, gy1, z1)])
gs = c.mask_poly([p(gx1, gy1, z0), p(gx1, gy0, z0), p(gx1, gy0, z1), p(gx1, gy1, z1)])
gt = c.mask_poly([p(gx0, gy0, z1), p(gx1, gy0, z1), p(gx1, gy1, z1), p(gx0, gy1, z1)])
c.glaze(gm, hexc("#BFE3E0"), 0.22)
c.glaze(gs, hexc("#7FA8A6"), 0.32)
c.paint(gt, c.grad(hexc("#A9CFCB"), 1.1, 0.9), 1.4, 0.8)
c.a = np.maximum(c.a, gm * 0.0)  # (glass stays over existing paint)
# glass reflections (diagonal streaks)
for k, w in ((0.25, 5), (0.38, 2)):
    a1 = p(gx0 + (gx1 - gx0) * k, gy1, z1 - 4)
    b1 = p(gx0 + (gx1 - gx0) * (k - 0.12), gy1, z0 + 6)
    c.stroke([a1, b1], w, (1, 1, 1), 0.35)
# steel frame edges
frame = [[p(gx0, gy1, z0), p(gx0, gy1, z1)], [p(gx1, gy1, z0), p(gx1, gy1, z1)], [p(gx1, gy0, z0), p(gx1, gy0, z1)],
         [p(gx0, gy1, z1), p(gx1, gy1, z1), p(gx1, gy0, z1), p(gx0, gy0, z1), p(gx0, gy1, z1)],
         [p(gx0, gy1, z0), p(gx1, gy1, z0), p(gx1, gy0, z0)]]
for f in frame:
    c.stroke(f, 4.2, OUT_ := np.array(OUT) / 255.0)
    c.stroke(f, 2.0, BRASS_L * 0.95)

# ---- brass soup pot (same spot as the steam vent in soi_brass.tscn) ----
PX, PY, PR = -0.42, -0.05, 0.28
c.cylinder(PX, PY, PR, 142, 216, BRASS, spec=0.9, rim=0.7, top_c=BRASS * 0.95)
c.band(PX, PY, PR, 150, 158, COPPER, spec=1.0)
c.band(PX, PY, PR, 196, 204, COPPER, spec=1.0)
# rivets on bands
for z in (154, 200):
    pts = []
    for t in np.linspace(math.radians(20), math.radians(160), 7):
        pts.append(p(PX + math.cos(t) * PR * 0.72 + math.sin(t) * PR * 0.72 * 0.0, PY + math.sin(t) * PR * 0.98, z))
    # front arc of the cylinder in screen space
    tx, ty = p(PX, PY, z)
    pts = [(tx + math.cos(t) * PR * 128 * s * 1.0, ty + math.sin(t) * PR * 64 * s) for t in np.linspace(math.radians(25), math.radians(155), 7)]
    c.rivets(pts, 2.4)
# lid (low dome) + knob
lx, ly = p(PX, PY, 216)
lid = c.mask_ellipse(lx, ly - 4 * s, PR * 128 * s * 0.92, PR * 64 * s * 0.92 + 6 * s)
c.disc(lx, ly - 4 * s, PR * 128 * s * 0.94, PR * 64 * s * 0.94 + 7 * s, BRASS * 1.02, 2.0, 0.8, spec=0.9)
c.disc(lx, ly - 11 * s, PR * 128 * s * 0.45, PR * 64 * s * 0.45 + 3 * s, BRASS * 0.9, 1.4, 0.5, spec=0.8)
c.disc(lx, ly - 16 * s, 8 * s, 6 * s, SOOT * 1.5, 1.4, 0.4, spec=0.5)
# pot gauge (front-left of the pot)
gpx, gpy = p(PX, PY, 182)
c.pipe([(gpx - 22 * s, gpy + 14 * s), (gpx - 34 * s, gpy + 14 * s)], 5, BRASS_D)
c.gauge(gpx - 40 * s, gpy + 12 * s, 11, angle=35)
# copper feed pipe: from the pot round to the left side, down into the body
q1 = p(PX - 0.1, PY + 0.28, 176)
q2 = p(X0 - 0.12, PY + 0.28, 176)
q3 = p(X0 - 0.12, PY + 0.28, 96)
q4 = p(X0 - 0.01, PY + 0.28, 96)
c.pipe([p(PX - 0.2, PY + 0.2, 176), q1], 9, COPPER)
c.pipe([q1, q2, q3, q4], 9, COPPER, spec=1.0)
for q in (q2, q3):
    c.disc(q[0], q[1], 7 * s, 7 * s, BRASS, 1.2, 0.3, spec=0.9)
# small red valve wheel on the pipe
vx, vy = (q2[0] + q3[0]) / 2, (q2[1] + q3[1]) / 2 - 6 * s
ring_m = np.clip(c.mask_ellipse(vx - 4 * s, vy, 6 * s, 11 * s) - c.mask_ellipse(vx - 4 * s, vy, 3.5 * s, 7.5 * s), 0, 1)
c.paint(ring_m, c.grad(RED, 1.2, 0.8, vy - 11 * s, vy + 11 * s), 1.2, 0.5)

# ---- rooster bowls stack (front right of the counter) ----
BX, BY = 0.52, 0.22
for i in range(4):
    z = 142 + i * 7
    bx, by = p(BX, BY, z)
    rx, ry = 22 * s - i * 0.3 * s, 11 * s
    body = np.maximum(c.mask_ellipse(bx, by + 4 * s, rx * 0.8, ry * 0.75), c.mask_poly([(bx - rx, by), (bx + rx, by), (bx + rx * 0.8, by + 4 * s), (bx - rx * 0.8, by + 4 * s)]))
    c.paint(body, c.cyl_field(CREAM, bx, rx, 0.4), 1.4, 0.4)
    c.stroke([(bx - rx * 0.85, by + 2 * s), (bx + rx * 0.85, by + 2 * s)], 1.6, RED, 0.9)
bx, by = p(BX, BY, 142 + 3 * 7 + 1)
c.disc(bx, by, 22 * s, 11 * s, CREAM * 0.93, 1.4, 0.4, dome=False)
c.disc(bx, by + 1 * s, 15 * s, 7 * s, CREAM * 0.78, 0.8, 0.0, dome=False)
# ladle hanging on the pot rim
c.pipe([p(PX + 0.18, PY + 0.1, 226), p(PX + 0.32, PY + 0.25, 196)], 3.2, STEEL)

# ---- near wheel (front side) ----
wheel(-0.42, Y1 + 0.05, 50, 0.21, 50)
# axle hub bracket
hx, hy = p(-0.42, Y1, 50)
c.pipe([p(-0.42, Y1 - 0.02, 50), p(-0.42, Y1 + 0.06, 50)], 6, SOOT * 1.6)

# ---- umbrella ----
UX, UY = 0.1, -0.3
c.pipe([p(UX, UY, 142), p(UX, UY, 280)], 6, STEEL * 0.8, spec=0.6)
c.disc(*p(UX, UY, 200), 5 * s, 4 * s, BRASS, 1.0, 0.2, spec=1.0)
ax_, ay_ = p(UX, UY, 300)       # apex
R = 0.72
rz = 250
cx_, cy_ = p(UX, UY, rz)        # rim centre
rx, ry = R * 128 * s, R * 64 * s
N = 8
rim_pts = lambda t: (cx_ + math.cos(t) * rx, cy_ + math.sin(t) * ry)
for i in sorted(range(N), key=lambda i: math.sin(2 * math.pi * (i + 0.5) / N + math.radians(11))):
    t0 = 2 * math.pi * i / N + math.radians(11)
    t1 = 2 * math.pi * (i + 1) / N + math.radians(11)
    tm = (t0 + t1) / 2
    # scalloped panel: apex -> rim arc
    arc = [rim_pts(t) for t in np.linspace(t0, t1, 10)]
    # sag the outer edge a little between ribs
    sag = []
    for k, (x, y) in enumerate(arc):
        f = math.sin(math.pi * k / 9)
        sag.append((x, y + f * 7 * s))
    poly = [(ax_, ay_)] + sag
    # lighting: panel normal tilts outward toward its mid-angle
    nx, ny = math.cos(tm) * 0.55, math.sin(tm) * 0.55 * 0.5 - 0.5
    lam = max(0.0, nx * LIGHT[0] + ny * LIGHT[1] + 0.75 * LIGHT[2])
    base = GREEN if i % 2 == 0 else GREEN_L * 0.92
    k = 0.55 + 0.75 * lam
    m = c.mask_poly(poly)
    xs = [q[0] for q in poly]; ys = [q[1] for q in poly]
    c.paint(m, c.grad(base * k, 1.12, 0.86, min(ys), max(ys)), 1.6, 0.6 if lam > 0.5 else 0.15, tex=0.08)
# ribs
for i in range(N):
    t = 2 * math.pi * i / N + math.radians(11)
    x, y = rim_pts(t)
    if math.sin(t) > -0.3:
        c.stroke([(ax_, ay_), (x, y)], 1.6, hexc("#1F3B38"), 0.8)
        c.disc(x, y + 1 * s, 2.6 * s, 2.6 * s, BRASS, 0.6, 0, spec=1.0)
# valance fringe along the front rim
for t in np.linspace(math.radians(15), math.radians(165), 22):
    x, y = rim_pts(t)
    c.stroke([(x, y + 4 * s), (x, y + 13 * s)], 2.2, CREAM * 0.9, 0.9)
# finial
c.disc(ax_, ay_ - 5 * s, 6 * s, 6 * s, BRASS, 1.2, 0.4, spec=1.0)

c.finish(sys.argv[1] if len(sys.argv) > 1 else "noodle_cart.png")
print("ok")
