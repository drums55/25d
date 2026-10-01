#!/usr/bin/env python3
"""Generates the vector placeholder-plus art (SVG) under assets/art/.

Hand-authored vector art in the Bangkok-steampunk palette, built from a few
isometric primitives so every prop shares the same projection as the game
(2:1 diamond, tile 128x64 at 1x; files are authored at ArtLibrary.ART_SCALE =
2x). Props: origin = bottom centre of the image = footprint centre on the
floor. Characters: cut-out parts for CutoutRig (see assets/art/README.md).

Run:  python3 tools/art/gen_svg.py      (then import: tools\\run.ps1 does it)
"""
import math
import os

S = 2.0  # ART_SCALE
ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art")

# palette
BRASS, BRASS_D, BRASS_L = "#C9A04A", "#8F6B2A", "#E8C878"
COPPER, COPPER_D = "#A8653D", "#6E3F24"
TEAL, TEAL_D, TEAL_L = "#3F7A74", "#27504C", "#5FA39B"
MINT = "#5E8F86"
RED, RED_D = "#C0392B", "#7E2219"
SOOT, SOOT_L = "#2B2629", "#4A4248"
WOOD, WOOD_D, WOOD_L = "#8B5A2B", "#5C3A1A", "#B07A42"
STEEL, STEEL_D = "#9AA3AD", "#5D666F"
SKIN, SKIN_D = "#E8B68A", "#B88560"
CREAM = "#EFE3C8"
OUT = "#1E1A1F"
SW = 3  # outline width


def shade(hexcol, k):
    """Darken (k<1) or lighten (k>1) a hex colour."""
    r, g, b = (int(hexcol[i:i + 2], 16) for i in (1, 3, 5))
    f = lambda c: max(0, min(255, int(c * k)))
    return "#%02X%02X%02X" % (f(r), f(g), f(b))


class Svg:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.parts = []

    def add(self, s):
        self.parts.append(s)

    def poly(self, pts, fill, stroke=OUT, sw=SW, opacity=None):
        d = " ".join("%.1f,%.1f" % p for p in pts)
        op = ' opacity="%s"' % opacity if opacity is not None else ""
        self.add('<polygon points="%s" fill="%s" stroke="%s" stroke-width="%s" '
                 'stroke-linejoin="round"%s/>' % (d, fill, stroke, sw, op))

    def ellipse(self, cx, cy, rx, ry, fill, stroke=OUT, sw=SW):
        self.add('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" stroke="%s" '
                 'stroke-width="%s"/>' % (cx, cy, rx, ry, fill, stroke, sw))

    def circle(self, cx, cy, r, fill, stroke=OUT, sw=SW):
        self.ellipse(cx, cy, r, r, fill, stroke, sw)

    def rect(self, x, y, w, h, fill, stroke=OUT, sw=SW, rx=0):
        self.add('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%s" fill="%s" '
                 'stroke="%s" stroke-width="%s"/>' % (x, y, w, h, rx, fill, stroke, sw))

    def line(self, pts, stroke, sw, cap="round"):
        d = " ".join("%.1f,%.1f" % p for p in pts)
        self.add('<polyline points="%s" fill="none" stroke="%s" stroke-width="%s" '
                 'stroke-linecap="%s" stroke-linejoin="round"/>' % (d, stroke, sw, cap))

    def path(self, d, fill, stroke=OUT, sw=SW):
        self.add('<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>'
                 % (d, fill, stroke, sw))

    def rivets(self, pts, r=3):
        for x, y in pts:
            self.circle(x, y, r, BRASS_L, BRASS_D, 1.5)

    def gauge(self, cx, cy, r):
        self.circle(cx, cy, r, CREAM, BRASS_D, 3)
        self.circle(cx, cy, r + 4, "none", BRASS, 3)
        a = math.radians(-50)
        self.line([(cx, cy), (cx + math.cos(a) * r * 0.75, cy + math.sin(a) * r * 0.75)], RED, 2.5)
        self.circle(cx, cy, 2, OUT, OUT, 1)

    def write(self, name):
        path = os.path.join(ROOT, name + ".svg")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
                    'viewBox="0 0 %d %d">\n' % (self.w, self.h, self.w, self.h))
            f.write("\n".join(self.parts))
            f.write("\n</svg>\n")
        print("wrote", os.path.relpath(path, ROOT))


class Iso:
    """Image-space projection for a prop. origin = bottom centre of image."""

    def __init__(self, w, h):
        self.ox, self.oy = w / 2.0, h

    def p(self, gx, gy, z=0.0):
        return (self.ox + (gx - gy) * 64 * S, self.oy + (gx + gy) * 32 * S - z * S)

    def box(self, svg, x0, y0, x1, y1, z0, z1, col, outline=True):
        """Axis-aligned iso box between cell coords, z in 1x pixels."""
        o = OUT if outline else "none"
        p = self.p
        # left face (x0 edge: from (x0,y0) to (x0,y1))
        svg.poly([p(x0, y1, z0), p(x1, y1, z0), p(x1, y1, z1), p(x0, y1, z1)], shade(col, 0.72), o)
        svg.poly([p(x1, y1, z0), p(x1, y0, z0), p(x1, y0, z1), p(x1, y1, z1)], shade(col, 0.52), o)
        svg.poly([p(x0, y0, z1), p(x1, y0, z1), p(x1, y1, z1), p(x0, y1, z1)], col, o)

    def cylinder(self, svg, cx, cy, r, z0, z1, col, outline=True):
        """Vertical cylinder centred on cell (cx, cy); r in cells."""
        o = OUT if outline else "none"
        (bx, by) = self.p(cx, cy, z0)
        (tx, ty) = self.p(cx, cy, z1)
        rx, ry = r * 64 * S * 1.0, r * 32 * S
        svg.add('<defs><linearGradient id="g%d" x1="0" x2="1"><stop offset="0" stop-color="%s"/>'
                '<stop offset="0.45" stop-color="%s"/><stop offset="1" stop-color="%s"/>'
                '</linearGradient></defs>' % (id(svg) % 9999 + int(z1), shade(col, 0.55), shade(col, 1.08), shade(col, 0.6)))
        gid = "g%d" % (id(svg) % 9999 + int(z1))
        svg.path("M%.1f,%.1f L%.1f,%.1f A%.1f,%.1f 0 0,0 %.1f,%.1f L%.1f,%.1f A%.1f,%.1f 0 0,0 %.1f,%.1f Z"
                 % (tx - rx, ty, bx - rx, by, rx, ry, bx + rx, by, tx + rx, ty, rx, ry, tx - rx, ty),
                 "url(#%s)" % gid, o)
        svg.ellipse(tx, ty, rx, ry, col, o)


# ----------------------------------------------------------------------------
# props
# ----------------------------------------------------------------------------

def noodle_cart():
    W, H = 420, 330
    svg, iso = Svg(W, H), Iso(W, H)
    fx, fy = 1.6, 0.9
    # wheels
    for gx in (-0.55, 0.45):
        wx, wy = iso.p(gx, fy / 2 + 0.02, 10)
        svg.ellipse(wx, wy, 26, 30, SOOT_L, OUT)
        svg.ellipse(wx, wy, 10, 12, BRASS, BRASS_D)
    # body
    iso.box(svg, -fx / 2, -fy / 2, fx / 2, fy / 2, 18, 68, RED)
    # steel counter top
    iso.box(svg, -fx / 2, -fy / 2, fx / 2, fy / 2, 68, 74, STEEL)
    # boiler pot (brass) at back-left
    iso.cylinder(svg, -0.42, -0.05, 0.28, 74, 112, BRASS)
    # lid handle
    lx, ly = iso.p(-0.42, -0.05, 112)
    svg.circle(lx, ly - 4, 7, BRASS_D, OUT)
    # noodle bowls stack front-right
    for i, z in enumerate((74, 80, 86)):
        bx, by = iso.p(0.45, 0.1, z)
        svg.ellipse(bx, by, 22 - i, 11 - i * 0.5, CREAM, OUT, 2.5)
    # pipe from boiler down to the side (steam feed)
    p1 = iso.p(-0.42, -0.4, 100)
    p2 = iso.p(-0.9, -0.4, 100)
    p3 = iso.p(-0.9, -0.4, 20)
    svg.line([p1, p2, p3], COPPER_D, 10)
    svg.line([p1, p2, p3], COPPER, 6)
    # gauge on the front face
    gx, gy = iso.p(0.0, fy / 2, 50)
    svg.gauge(gx, gy, 12)
    # rivets along the top rim
    svg.rivets([iso.p(x, fy / 2, 70) for x in (-0.6, -0.3, 0.0, 0.3, 0.6)])
    # umbrella pole + canopy
    px, py = iso.p(0.1, -0.3, 74)
    svg.line([(px, py), (px, py - 120)], STEEL_D, 6)
    cx, cy = px, py - 120
    svg.path("M%.1f,%.1f Q%.1f,%.1f %.1f,%.1f Q%.1f,%.1f %.1f,%.1f Z"
             % (cx - 150, cy + 36, cx, cy - 40, cx + 150, cy + 36, cx, cy + 60, cx - 150, cy + 36),
             TEAL, OUT)
    for k in (-100, -50, 0, 50, 100):
        svg.line([(cx + k, cy + 36 - abs(k) * 0.12 + 10), (cx, cy - 36)], TEAL_D, 2.5)
    svg.write("props/noodle_cart")


def steam_tuktuk():
    W, H = 470, 330
    svg, iso = Svg(W, H), Iso(W, H)
    fx, fy = 1.8, 1.0
    for gx, gy in ((-0.6, 0.45), (0.65, 0.45), (0.65, -0.45)):
        wx, wy = iso.p(gx, gy, 12)
        svg.ellipse(wx, wy, 24, 28, SOOT_L, OUT)
        svg.ellipse(wx, wy, 9, 11, BRASS, BRASS_D)
    iso.box(svg, -fx / 2, -fy / 2, fx / 2, fy / 2, 22, 60, TEAL)
    # cabin (rear 60%)
    iso.box(svg, -0.9, -0.5, 0.25, 0.5, 60, 118, TEAL)
    # open window (front side)
    a, b = iso.p(-0.75, 0.5, 70), iso.p(0.1, 0.5, 70)
    c, d = iso.p(0.1, 0.5, 108), iso.p(-0.75, 0.5, 108)
    svg.poly([a, b, c, d], SOOT, OUT)
    # roof
    iso.box(svg, -0.95, -0.55, 0.3, 0.55, 118, 126, BRASS)
    # boiler on the back
    iso.cylinder(svg, -0.95, 0.0, 0.22, 60, 112, COPPER)
    cx, cy = iso.p(-0.95, 0.0, 112)
    svg.circle(cx, cy - 10, 8, BRASS, OUT)
    svg.line([(cx, cy - 18), (cx, cy - 40)], STEEL_D, 7)
    # front hood + headlamp
    iso.box(svg, 0.25, -0.35, 0.9, 0.35, 60, 80, TEAL_D)
    hx, hy = iso.p(0.9, 0.0, 70)
    svg.circle(hx, hy, 12, BRASS_L, BRASS_D)
    svg.circle(hx, hy, 6, CREAM, "none", 0)
    svg.gauge(*iso.p(0.5, 0.35, 72), 9)
    svg.rivets([iso.p(x, 0.5, 115) for x in (-0.8, -0.5, -0.2, 0.1)])
    svg.write("props/steam_tuk_tuk")


def spirit_house():
    W, H = 220, 360
    svg, iso = Svg(W, H), Iso(W, H)
    # pedestal
    iso.cylinder(svg, 0, 0, 0.14, 0, 70, STEEL_D)
    iso.box(svg, -0.3, -0.3, 0.3, 0.3, 70, 80, BRASS_D)
    # house body
    iso.box(svg, -0.26, -0.26, 0.26, 0.26, 80, 118, BRASS)
    # dark doorway with gear inside
    a, b = iso.p(-0.2, 0.26, 84), iso.p(0.2, 0.26, 84)
    c, d = iso.p(0.2, 0.26, 114), iso.p(-0.2, 0.26, 114)
    svg.poly([a, b, c, d], SOOT, OUT)
    gx, gy = ((a[0] + c[0]) / 2, (a[1] + c[1]) / 2)
    gear(svg, gx, gy, 12, COPPER)
    # tiered roof
    for i, (half, z0, z1) in enumerate(((0.36, 118, 128), (0.26, 128, 140), (0.14, 140, 160))):
        iso.box(svg, -half, -half, half, half, z0, z1, RED if i % 2 == 0 else RED_D)
    # spire
    sx, sy = iso.p(0, 0, 160)
    svg.poly([(sx - 10, sy), (sx + 10, sy), (sx, sy - 40)], BRASS_L, OUT)
    # tiny pipe chimney + offering cups
    px, py = iso.p(0.2, -0.2, 160)
    svg.line([(px, py), (px, py - 22)], COPPER, 6)
    for k in (-0.22, 0.0, 0.22):
        cx, cy = iso.p(k, 0.42, 80)
        svg.ellipse(cx, cy, 7, 4, RED, OUT, 2)
    svg.write("props/spirit_house")


def gear(svg, cx, cy, r, col, teeth=8):
    pts = []
    for i in range(teeth * 2):
        a = math.pi * 2 * i / (teeth * 2)
        rr = r if i % 2 == 0 else r * 0.72
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    svg.poly(pts, col, OUT, 2)
    svg.circle(cx, cy, r * 0.3, shade(col, 0.6), OUT, 2)


def power_pole():
    W, H = 160, 720
    svg, iso = Svg(W, H), Iso(W, H)
    cx, cy = iso.p(0, 0, 0)
    svg.ellipse(cx, cy, 18, 9, SOOT_L, OUT)
    svg.rect(cx - 9, cy - 660, 18, 660, "#6F6763", OUT)
    svg.rect(cx - 9, cy - 660, 6, 660, "#8A817C", "none", 0)
    # cross arms + insulators
    for y in (cy - 640, cy - 590):
        svg.rect(cx - 60, y - 5, 120, 10, SOOT_L, OUT)
        for k in (-48, -16, 16, 48):
            svg.rect(cx + k - 4, y - 18, 8, 13, CREAM, OUT, 2)
    # tangled cables
    for i, y in enumerate((cy - 630, cy - 620, cy - 600, cy - 580)):
        svg.path("M%d,%d Q%d,%d %d,%d" % (cx - 70, y, cx + (i - 1) * 30, y + 50 + i * 12, cx + 70, y + 4),
                 "none", OUT, 2)
    # brass transformer can
    svg.rect(cx + 12, cy - 560, 30, 60, BRASS, OUT, 3)
    svg.rivets([(cx + 20, cy - 550), (cx + 34, cy - 550), (cx + 20, cy - 510), (cx + 34, cy - 510)])
    # lamp arm + lantern
    svg.line([(cx, cy - 480), (cx + 50, cy - 500)], STEEL_D, 6)
    svg.rect(cx + 40, cy - 500, 22, 30, BRASS_L, OUT, 4)
    svg.rect(cx + 44, cy - 494, 14, 18, "#FFF2B0", "none", 0)
    svg.write("props/power_pole")


def water_tank():
    W, H = 300, 440
    svg, iso = Svg(W, H), Iso(W, H)
    # legs
    for gx, gy in ((-0.35, -0.35), (0.35, -0.35), (0.35, 0.35), (-0.35, 0.35)):
        x, y = iso.p(gx, gy, 0)
        svg.line([(x, y), (x, y - 70 * S)], STEEL_D, 8)
    iso.box(svg, -0.45, -0.45, 0.45, 0.45, 70, 78, WOOD_D)
    iso.cylinder(svg, 0, 0, 0.42, 78, 180, COPPER)
    # bands
    for z in (100, 140):
        x, y = iso.p(0, 0, z)
        svg.ellipse(x, y, 0.42 * 64 * S, 0.42 * 32 * S, "none", BRASS_D, 5)
    # hatch + valve + pipe down
    hx, hy = iso.p(0, 0, 180)
    svg.ellipse(hx, hy - 6, 22, 11, BRASS, OUT)
    vx, vy = iso.p(0.42, 0.0, 90)
    svg.line([(vx, vy), (vx + 22, vy + 10), (vx + 22, vy + 150)], COPPER_D, 9)
    svg.line([(vx, vy), (vx + 22, vy + 10), (vx + 22, vy + 150)], COPPER, 5)
    svg.circle(vx + 22, vy + 30, 9, RED, OUT)
    svg.gauge(*iso.p(0.0, 0.42, 150), 11)
    svg.write("props/water_tank")


def stool(name, col):
    W, H = 110, 130
    svg, iso = Svg(W, H), Iso(W, H)
    for gx, gy in ((-0.15, -0.15), (0.15, -0.15), (0.15, 0.15), (-0.15, 0.15)):
        x, y = iso.p(gx, gy, 0)
        svg.line([(x, y), (x, y - 34 * S)], shade(col, 0.6), 6)
    iso.box(svg, -0.2, -0.2, 0.2, 0.2, 34, 40, col)
    x, y = iso.p(0, 0, 40)
    svg.ellipse(x, y, 8, 4, shade(col, 0.75), "none", 0)
    svg.write("props/" + name)


def steam_bike():
    W, H = 380, 260
    svg, iso = Svg(W, H), Iso(W, H)
    for gx in (-0.5, 0.5):
        wx, wy = iso.p(gx, 0.0, 14)
        svg.ellipse(wx, wy, 30, 34, SOOT, OUT)
        svg.ellipse(wx, wy, 14, 16, BRASS, BRASS_D)
        for k in range(6):
            a = math.pi * 2 * k / 6
            svg.line([(wx, wy), (wx + math.cos(a) * 28, wy + math.sin(a) * 32)], STEEL_D, 2)
    # frame + tank
    a, b = iso.p(-0.5, 0, 14), iso.p(0.5, 0, 14)
    svg.line([a, iso.p(-0.1, 0, 60), iso.p(0.3, 0, 60), b], COPPER_D, 9)
    iso.box(svg, -0.15, -0.12, 0.3, 0.12, 48, 72, COPPER)
    # boiler behind seat + chimney
    iso.cylinder(svg, -0.42, 0.0, 0.14, 30, 70, BRASS)
    bx, by = iso.p(-0.42, 0, 70)
    svg.line([(bx, by), (bx - 6, by - 36)], STEEL_D, 7)
    # seat
    iso.box(svg, -0.3, -0.12, -0.05, 0.12, 72, 80, SOOT)
    # handlebar + headlamp
    hx, hy = iso.p(0.45, 0, 70)
    svg.line([(hx - 10, hy - 8), (hx + 14, hy + 2)], STEEL_D, 6)
    svg.circle(hx + 6, hy + 14, 11, BRASS_L, OUT)
    svg.circle(hx + 6, hy + 14, 5, CREAM, "none", 0)
    # delivery box on the back
    iso.box(svg, -0.72, -0.22, -0.42, 0.22, 24, 66, RED)
    rx, ry = iso.p(-0.57, 0.22, 48)
    svg.circle(rx, ry, 8, CREAM, OUT, 2)
    svg.write("props/steam_bike")


def boiler():
    W, H = 300, 520
    svg, iso = Svg(W, H), Iso(W, H)
    iso.box(svg, -0.5, -0.5, 0.5, 0.5, 0, 14, SOOT_L)
    iso.cylinder(svg, 0, 0, 0.42, 14, 180, COPPER)
    for z in (60, 120):
        x, y = iso.p(0, 0, z)
        svg.ellipse(x, y, 0.42 * 64 * S, 0.42 * 32 * S, "none", BRASS_D, 6)
        svg.rivets([(x + math.cos(a) * 0.42 * 64 * S, y + math.sin(a) * 0.42 * 32 * S)
                    for a in (0.3, 0.9, 1.5, 2.1, 2.7)])
    # dome
    tx, ty = iso.p(0, 0, 180)
    svg.path("M%.1f,%.1f A%.1f,%.1f 0 0,1 %.1f,%.1f Z" % (tx - 0.42 * 64 * S, ty, 54, 30, tx + 0.42 * 64 * S, ty), BRASS, OUT)
    svg.line([(tx, ty - 28), (tx, ty - 60)], STEEL_D, 12)
    svg.line([(tx, ty - 28), (tx, ty - 60)], STEEL, 7)
    # firebox door (front) + gauges + valve wheel
    dx, dy = iso.p(0.0, 0.42, 40)
    svg.rect(dx - 24, dy - 22, 48, 36, SOOT, OUT, 3)
    svg.rect(dx - 16, dy - 14, 32, 18, "#F08A2A", "none", 0)
    svg.gauge(*iso.p(0.0, 0.42, 110), 15)
    svg.gauge(*iso.p(0.0, 0.42, 150), 10)
    wx, wy = iso.p(0.42, 0.0, 100)
    svg.circle(wx + 14, wy, 16, "none", RED, 5)
    svg.line([(wx + 14, wy - 16), (wx + 14, wy + 16)], RED, 3)
    svg.line([(wx - 2, wy), (wx + 30, wy)], RED, 3)
    svg.write("props/boiler")


def gear_stall():
    W, H = 400, 280
    svg, iso = Svg(W, H), Iso(W, H)
    fx, fy = 1.5, 1.0
    iso.box(svg, -fx / 2, -fy / 2, fx / 2, fy / 2, 0, 56, WOOD)
    iso.box(svg, -fx / 2, -fy / 2, fx / 2, fy / 2, 56, 62, WOOD_L)
    # cloth on the front
    a, b = iso.p(-fx / 2, fy / 2, 10), iso.p(fx / 2, fy / 2, 10)
    c, d = iso.p(fx / 2, fy / 2, 56), iso.p(-fx / 2, fy / 2, 56)
    svg.poly([a, b, c, d], RED)
    # gears on the table
    for gx, gy, r, col in ((-0.45, -0.2, 20, BRASS), (-0.1, 0.1, 16, COPPER), (0.3, -0.25, 24, STEEL), (0.45, 0.25, 12, BRASS_L)):
        x, y = iso.p(gx, gy, 62)
        gear(svg, x, y - r * 0.4, r, col)
    # umbrella on a pole
    px, py = iso.p(0.0, -0.4, 62)
    svg.line([(px, py), (px, py - 110)], STEEL_D, 6)
    cx, cy = px, py - 110
    svg.path("M%.1f,%.1f Q%.1f,%.1f %.1f,%.1f Q%.1f,%.1f %.1f,%.1f Z"
             % (cx - 140, cy + 30, cx, cy - 36, cx + 140, cy + 30, cx, cy + 52, cx - 140, cy + 30), BRASS, OUT)
    for k in (-90, -45, 0, 45, 90):
        svg.line([(cx + k, cy + 30 - abs(k) * 0.1 + 8), (cx, cy - 30)], BRASS_D, 2.5)
    svg.write("props/gear_stall")


def crate():
    W, H = 240, 200
    svg, iso = Svg(W, H), Iso(W, H)
    iso.box(svg, -0.45, -0.45, 0.45, 0.45, 0, 60, WOOD)
    for z in (12, 48):
        x1, y1 = iso.p(-0.45, 0.45, z)
        x2, y2 = iso.p(0.45, 0.45, z)
        x3, y3 = iso.p(0.45, -0.45, z)
        svg.line([(x1, y1), (x2, y2), (x3, y3)], WOOD_D, 5)
    svg.rivets([iso.p(x, 0.45, z) for x in (-0.35, 0.35) for z in (12, 48)], 3)
    svg.write("props/crate")


def sign():
    W, H = 180, 300
    svg, iso = Svg(W, H), Iso(W, H)
    x, y = iso.p(0, 0, 0)
    svg.line([(x, y), (x, y - 230)], WOOD_D, 10)
    svg.rect(x - 70, y - 250, 140, 70, BRASS, OUT, 6)
    svg.rect(x - 60, y - 240, 120, 50, SOOT, "none", 0)
    svg.line([(x - 48, y - 225), (x + 48, y - 225)], CREAM, 4)
    svg.line([(x - 40, y - 205), (x + 20, y - 205)], CREAM, 4)
    svg.rivets([(x - 62, y - 244), (x + 62, y - 244), (x - 62, y - 186), (x + 62, y - 186)])
    gear(svg, x + 50, y - 262, 14, COPPER)
    svg.write("props/sign")


def brass_automaton():
    """Training dummy: brass torso on a post, origin at the post foot."""
    W, H = 180, 380
    svg, iso = Svg(W, H), Iso(W, H)
    x, y = iso.p(0, 0, 0)
    svg.ellipse(x, y, 34, 17, SOOT_L, OUT)
    svg.rect(x - 10, y - 180, 20, 180, STEEL_D, OUT)
    # torso barrel
    svg.add('<defs><linearGradient id="at" x1="0" x2="1"><stop offset="0" stop-color="%s"/>'
            '<stop offset="0.5" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient></defs>'
            % (BRASS_D, BRASS_L, BRASS_D))
    svg.path("M%d,%d L%d,%d Q%d,%d %d,%d L%d,%d Q%d,%d %d,%d Z"
             % (x - 52, y - 300, x + 52, y - 300, x + 62, y - 240, x + 48, y - 180, x - 48, y - 180, x - 62, y - 240, x - 52, y - 300),
             "url(#at)", OUT)
    svg.line([(x - 54, y - 250), (x + 54, y - 250)], BRASS_D, 5)
    svg.rivets([(x + k, y - 290) for k in (-36, -12, 12, 36)] + [(x + k, y - 195) for k in (-30, 0, 30)])
    svg.gauge(x, y - 230, 14)
    # shoulders / stub arms
    for sx, dirn in ((x - 60, -1), (x + 60, 1)):
        svg.circle(sx, y - 290, 14, COPPER, OUT)
        svg.line([(sx, y - 290), (sx + dirn * 26, y - 250)], COPPER_D, 10)
        svg.circle(sx + dirn * 26, y - 250, 8, STEEL, OUT)
    # head: brass bucket with slit eyes
    svg.rect(x - 28, y - 350, 56, 46, BRASS, OUT, 8)
    svg.rect(x - 18, y - 334, 36, 7, SOOT, OUT, 2)
    svg.line([(x, y - 350), (x, y - 368)], STEEL_D, 6)
    svg.circle(x, y - 372, 6, RED, OUT)
    svg.write("props/brass_automaton")


# ----------------------------------------------------------------------------
# characters (cut-out parts, facing right)
# ----------------------------------------------------------------------------

def character(folder, skin=SKIN, shirt=TEAL, vest="#D8752D", hat="helmet", wrench=True,
              trousers=SOOT, hair=SOOT):
    d = "characters/%s/" % folder
    # head 100x120, pivot bottom centre (neck)
    s = Svg(100, 120)
    s.ellipse(50, 70, 32, 36, skin, OUT)          # face
    if hat == "helmet":
        s.path("M18,62 A32,34 0 0,1 82,62 L82,52 A34,30 0 0,0 18,52 Z", TEAL, OUT)
        s.path("M16,56 A34,38 0 0,1 84,56 Z", TEAL_D, OUT)
        s.ellipse(50, 24, 30, 16, TEAL, OUT)
        s.rect(78, 50, 10, 16, BRASS, OUT, 3)
        for cx in (36, 64):                        # goggles up on the helmet
            s.circle(cx, 44, 11, BRASS, OUT)
            s.circle(cx, 44, 6, TEAL_L, "none", 0)
        s.line([(47, 44), (53, 44)], BRASS_D, 4)
    elif hat == "cap":                             # flat cap + grey moustache (old vendor)
        s.path("M16,58 A34,36 0 0,1 84,58 Z", hair, OUT)
        s.path("M14,58 L92,58 L96,66 L14,64 Z", shade(hair, 1.3), OUT)
        s.path("M58,88 q10,-6 20,0 q-10,8 -20,0 Z", "#D9D4C7", OUT, 2)
        s.ellipse(50, 44, 8, 3, "none", "none", 0)
    elif hat == "bun":                             # hair bun + brass hairpin (market lady)
        s.path("M16,60 A34,38 0 0,1 84,60 Z", hair, OUT)
        s.circle(40, 26, 14, hair, OUT)
        s.line([(28, 18), (56, 30)], BRASS, 4)
        s.path("M70,54 q8,10 6,24", "none", hair, 6)
    s.circle(62, 74, 3.5, OUT, OUT, 1)              # eye (3/4 right)
    s.line([(66, 88), (74, 86)], OUT, 2.5)          # mouth
    s.path("M74,68 l5,6 -5,4", "none", shade(skin, 0.8), 2)   # nose
    s.rect(44, 102, 14, 16, shade(skin, 0.8), OUT, 4)         # neck
    s.write(d + "head")

    # torso 110x130, pivot bottom centre (hips)
    s = Svg(110, 130)
    s.path("M22,18 L88,18 L96,110 L14,110 Z", shirt, OUT)       # shirt
    if vest:
        s.path("M30,18 L80,18 L84,110 L26,110 Z", vest, OUT)    # vest / apron
        s.path("M34,18 L48,18 L46,110 L36,110 Z", shade(vest, 0.85), "none", 0)
    s.rect(30, 56, 50, 10, BRASS_D, OUT, 2)          # belt
    s.rect(48, 54, 14, 14, BRASS, OUT, 2)
    s.rivets([(40, 30), (70, 30), (40, 92), (70, 92)])
    s.line([(24, 20), (18, 60)], SOOT, 6)            # bag strap
    if wrench:
        s.rect(86, 40, 18, 44, SOOT, OUT, 4)         # small brass gauge pack on the back-side
        s.gauge(95, 62, 7)
    s.write(d + "torso")

    # arms 40x112, pivot top centre (shoulder)
    for name, col, with_wrench in (("arm_l", shade(shirt, 0.75), False), ("arm_r", shirt, wrench)):
        s = Svg(40 if not with_wrench else 60, 112 if not with_wrench else 180)
        ox = 0 if not with_wrench else 10
        if with_wrench:  # big pipe wrench held in the hand, pointing down
            s.line([(ox + 20, 92), (ox + 20, 168)], STEEL_D, 11)
            s.line([(ox + 20, 92), (ox + 20, 168)], STEEL, 6)
            s.path("M%d,150 l-14,0 l0,-10 l14,0 Z" % (ox + 20), STEEL, OUT)
            s.rect(ox + 6, 160, 28, 14, STEEL_D, OUT, 3)
            s.rect(ox + 12, 104, 16, 16, SOOT, OUT, 2)
        s.path("M%d,4 L%d,4 L%d,70 L%d,70 Z" % (ox + 8, ox + 32, ox + 30, ox + 10), col, OUT)
        s.rect(ox + 8, 66, 24, 14, BRASS_D, OUT, 3)  # cuff
        s.ellipse(ox + 20, 92, 13, 15, SKIN, OUT)    # hand
        s.write(d + name)

    # legs 44x136, pivot top centre (hip)
    for name, col in (("leg_l", shade(trousers, 1.3)), ("leg_r", trousers)):
        s = Svg(44, 136)
        s.path("M8,2 L36,2 L34,96 L10,96 Z", col, OUT)
        s.rect(6, 94, 32, 16, WOOD_D, OUT, 3)        # boot cuff
        s.path("M8,108 L36,108 L42,130 L4,130 Z", WOOD_D, OUT)  # boot
        s.rect(10, 126, 32, 6, SOOT, OUT, 1)
        s.write(d + name)


if __name__ == "__main__":
    noodle_cart()
    steam_tuktuk()
    spirit_house()
    power_pole()
    water_tank()
    stool("stool_a", RED)
    stool("stool_b", "#2F5FD0")
    steam_bike()
    boiler()
    gear_stall()
    crate()
    sign()
    character("rider")
    character("lung_pradit", skin="#D8A878", shirt=CREAM, vest="#3C5A8A", hat="cap", wrench=False,
              trousers="#4A3B30", hair="#BDB7AA")
    character("je_muay", skin="#F0C8A0", shirt="#D96C8C", vest="#F2E6D0", hat="bun", wrench=False,
              trousers="#3A3550", hair="#1C1418")
    brass_automaton()
