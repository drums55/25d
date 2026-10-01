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
# Props keep this much image below the origin (ArtLibrary.PROP_FOOT_MARGIN) so
# the front corners, wheels and the contact shadow are not clipped.
FOOT = 160
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

    def line_op(self, pts, stroke, sw, opacity):
        d = " ".join("%.1f,%.1f" % p for p in pts)
        self.add('<polyline points="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" '
                 'opacity="%s"/>' % (d, stroke, sw, opacity))

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

    def glow(self, cx, cy, rx, ry, opacity=0.35):
        """Soft white highlight blob (light from top-left)."""
        self.add('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#FFFFFF" opacity="%s"/>'
                 % (cx, cy, rx, ry, opacity))

    def shade_lr(self, x0, y0, w, h, light=0.22, dark=0.22):
        """Vertical rim light on the left and shadow on the right of a part."""
        self.add('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="4" fill="#FFFFFF" opacity="%s"/>'
                 % (x0, y0, w * 0.18, h, light))
        self.add('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="4" fill="#000000" opacity="%s"/>'
                 % (x0 + w * 0.78, y0, w * 0.22, h, dark))

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
        if os.path.exists(os.path.join(ROOT, name + ".png")):
            # painted PNG replaces this placeholder (.svg would win in ArtLibrary)
            print("skip", name, "(png exists)")
            return
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
        self.ox, self.oy = w / 2.0, h - FOOT

    def p(self, gx, gy, z=0.0):
        return (self.ox + (gx - gy) * 64 * S, self.oy + (gx + gy) * 32 * S - z * S)

    def shadow(self, svg, fx, fy, opacity=0.38):
        """Soft contact shadow on the floor under a footprint (draw first)."""
        cx, cy = self.p(0, 0, 0)
        rx = (fx + fy) * 0.5 * 64 * S * 0.75
        ry = (fx + fy) * 0.5 * 32 * S * 0.75
        svg.add('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#000000" opacity="%s"/>'
                % (cx, cy + 4, rx * 1.15, ry * 1.15, opacity * 0.4))
        svg.add('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#000000" opacity="%s"/>'
                % (cx, cy + 2, rx, ry, opacity))

    def box(self, svg, x0, y0, x1, y1, z0, z1, col, outline=True):
        """Axis-aligned iso box between cell coords, z in 1x pixels.
        Light from top-left: top face lit, left face mid, right face dark,
        plus a bright rim on the top-left edges and ambient darkening low."""
        o = OUT if outline else "none"
        p = self.p
        svg.poly([p(x0, y1, z0), p(x1, y1, z0), p(x1, y1, z1), p(x0, y1, z1)], shade(col, 0.72), o)
        svg.poly([p(x1, y1, z0), p(x1, y0, z0), p(x1, y0, z1), p(x1, y1, z1)], shade(col, 0.48), o)
        svg.poly([p(x0, y0, z1), p(x1, y0, z1), p(x1, y1, z1), p(x0, y1, z1)], shade(col, 1.12), o)
        zm = z0 + (z1 - z0) * 0.45
        # ambient occlusion on the lower half of the side faces
        svg.poly([p(x0, y1, z0), p(x1, y1, z0), p(x1, y1, zm), p(x0, y1, zm)], "#000000", "none", 0, 0.18)
        svg.poly([p(x1, y1, z0), p(x1, y0, z0), p(x1, y0, zm), p(x1, y1, zm)], "#000000", "none", 0, 0.18)
        # rim light along the lit edges
        svg.line_op([p(x0, y1, z1), p(x0, y0, z1), p(x1, y0, z1)], "#FFFFFF", 3, 0.55)
        svg.line_op([p(x0, y1, z1), p(x0, y1, z0)], "#FFFFFF", 2, 0.3)

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
        svg.ellipse(tx, ty, rx, ry, shade(col, 1.15), o)
        svg.line_op([(tx - rx * 0.62, ty + 6), (bx - rx * 0.62, by - 10)], "#FFFFFF", rx * 0.16, 0.45)
        svg.add('<path d="M%.1f,%.1f A%.1f,%.1f 0 0,0 %.1f,%.1f L%.1f,%.1f A%.1f,%.1f 0 0,1 %.1f,%.1f Z" '
                'fill="#000000" opacity="0.22"/>' % (bx - rx, by, rx, ry, bx + rx, by, bx + rx, by - (by - ty) * 0.3,
                                                      rx, ry, bx - rx, by - (by - ty) * 0.3))


# ----------------------------------------------------------------------------
# props
# ----------------------------------------------------------------------------

def noodle_cart():
    W, H = 420, 330 + FOOT
    svg, iso = Svg(W, H), Iso(W, H)
    iso.shadow(svg, 1.6, 0.9)
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
    """Classic Bangkok tuk-tuk (blue body, red cowl, standing windshield, black
    rounded roof, twin headlamps, single front wheel, red bench, white rails)
    with a brass boiler on the tail. Front points down-left (+y)."""
    W, H = 500, 420 + FOOT
    svg, iso = Svg(W, H), Iso(W, H)
    iso.shadow(svg, 1.0, 1.8)
    p = iso.p
    BLUE, BLUE_D, BLUE_L = "#2B4C8C", "#1B3160", "#3F67B5"
    TRED, TRED_D = "#C8372D", "#8A2219"
    ROOF, ROOF_L = "#26262B", "#3C3C44"
    YEL = "#E8C23A"
    WHITE = "#EDEDEA"

    def wheel(gx, gy, r):
        wx, wy = p(gx, gy, 14)
        svg.ellipse(wx, wy, r * 0.62, r, SOOT, OUT)
        svg.ellipse(wx, wy, r * 0.3, r * 0.5, STEEL, STEEL_D, 2)
        svg.glow(wx - r * 0.2, wy - r * 0.5, r * 0.15, r * 0.3, 0.3)

    def q(a, b, c):
        return "M%.1f,%.1f Q%.1f,%.1f %.1f,%.1f" % (a + b + c)

    # far rear wheel, boiler on the tail
    wheel(-0.55, -0.5, 30)
    iso.cylinder(svg, 0.0, -1.0, 0.18, 30, 92, COPPER)
    bx, by = p(0.0, -1.0, 92)
    svg.line([(bx, by - 2), (bx, by - 120)], STEEL_D, 11)
    svg.line([(bx, by - 2), (bx, by - 120)], STEEL, 6)
    svg.ellipse(bx, by - 120, 9, 4, SOOT, OUT, 2)
    # chassis + rear cargo box
    iso.box(svg, -0.5, -0.9, 0.5, 0.6, 18, 30, BLUE_D)
    iso.box(svg, -0.5, -0.9, 0.5, -0.05, 30, 62, BLUE)
    # bench + backrest
    iso.box(svg, -0.4, -0.78, 0.4, -0.3, 62, 84, TRED)
    iso.box(svg, -0.4, -0.78, 0.4, -0.68, 84, 118, TRED_D)
    # white side rails on the cargo box (near side = +x face)
    for z in (74, 86):
        svg.line([p(0.5, -0.9, z), p(0.5, -0.05, z)], WHITE, 4)
    for gy in (-0.9, -0.48, -0.05):
        svg.line([p(0.5, gy, 62), p(0.5, gy, 86)], WHITE, 4)
    # driver seat
    iso.box(svg, -0.18, 0.02, 0.18, 0.34, 30, 56, SOOT)
    # ---- front cowl: blue rounded nose, red hood, windshield ----
    fl_b, fr_b = p(-0.5, 0.45, 30), p(0.5, 0.45, 30)      # cowl base rear corners
    fl_t, fr_t = p(-0.5, 0.45, 72), p(0.5, 0.45, 72)
    nl_b, nr_b = p(-0.34, 0.95, 26), p(0.34, 0.95, 26)    # nose base corners
    nl_t, nr_t = p(-0.34, 0.95, 72), p(0.34, 0.95, 72)
    nose_ctrl_b = p(0.0, 1.22, 26)
    nose_ctrl_t = p(0.0, 1.22, 72)
    # near side (+x face) of the cowl
    svg.poly([fr_b, nr_b, nr_t, fr_t], shade(BLUE, 0.5))
    # front nose face (curved)
    svg.path("M%.1f,%.1f L%.1f,%.1f Q%.1f,%.1f %.1f,%.1f L%.1f,%.1f Q%.1f,%.1f %.1f,%.1f Z"
             % (nl_b + nl_t + nose_ctrl_t + nr_t + nr_b + nose_ctrl_b + nl_b), BLUE, OUT)
    # far side (-x face) sliver
    svg.poly([fl_b, nl_b, nl_t, fl_t], shade(BLUE, 0.78))
    # red hood (top) with a bulged front edge
    svg.path("M%.1f,%.1f L%.1f,%.1f Q%.1f,%.1f %.1f,%.1f L%.1f,%.1f Z"
             % (fl_t + nl_t + nose_ctrl_t + nr_t + fr_t), TRED, OUT)
    svg.line_op([fl_t, nl_t], "#FFFFFF", 3, 0.5)
    # headlamps on the nose
    for gx in (-0.17, 0.17):
        hx, hy = p(gx, 1.02, 50)
        svg.ellipse(hx, hy, 13, 15, WHITE, OUT)
        svg.ellipse(hx, hy, 8, 10, YEL, "none", 0)
        svg.glow(hx - 3, hy - 4, 3, 3, 0.8)
    # brass gauge on the near side of the cowl
    svg.gauge(*p(0.5, 0.7, 52), 9)
    # windshield: standing panel from the hood front edge, tilting back
    ws = [p(-0.36, 0.92, 72), p(0.36, 0.92, 72), p(0.34, 0.74, 124), p(-0.34, 0.74, 124)]
    svg.poly(ws, TRED, OUT)
    glass = [p(-0.29, 0.9, 78), p(0.29, 0.9, 78), p(0.27, 0.76, 118), p(-0.27, 0.76, 118)]
    svg.poly(glass, "#4C5A6E", OUT, 2)
    svg.poly([glass[0], glass[1], (glass[1][0] - 20, glass[1][1] - 30), (glass[0][0] + 10, glass[0][1] - 30)],
             "#FFFFFF", "none", 0, 0.18)
    vis = [p(-0.22, 0.78, 108), p(0.22, 0.78, 108), p(0.22, 0.78, 100), p(-0.22, 0.78, 100)]
    svg.poly(vis, YEL, OUT, 2)
    # handlebar peeking over the hood
    hx, hy = p(0.0, 0.5, 72)
    svg.line([(hx, hy), (hx + 4, hy - 26)], STEEL_D, 6)
    svg.line([(hx - 26, hy - 32), (hx + 30, hy - 22)], STEEL, 6)
    # roof posts (white) rear corners + middle
    for gx, gy in ((-0.5, -0.9), (0.5, -0.9), (0.5, -0.05), (-0.5, -0.05)):
        svg.line([p(gx, gy, 62), p(gx, gy, 124)], WHITE, 5)
    # near rear wheel + front wheel with fork
    wheel(0.55, -0.5, 30)
    fx, fy = p(0.0, 1.0, 14)
    svg.line([p(0.0, 0.95, 40), (fx, fy)], STEEL_D, 8)
    wheel(0.0, 1.0, 32)
    svg.line([p(0.06, 1.0, 40), (fx + 8, fy)], STEEL, 4)
    # black rounded roof slab
    r = 0.12
    c1, c2, c3, c4 = p(-0.54, -0.98, 124), p(0.54, -0.98, 124), p(0.54, 0.86, 124), p(-0.54, 0.86, 124)
    e1, e2, e3, e4 = p(-0.54, -0.98, 132), p(0.54, -0.98, 132), p(0.54, 0.86, 132), p(-0.54, 0.86, 132)

    def rounded(a, b, c, d, z):
        pts = []
        corners = [(-0.54, -0.98), (0.54, -0.98), (0.54, 0.86), (-0.54, 0.86)]
        path = ""
        for k in range(4):
            gx, gy = corners[k]
            nx, ny = corners[(k + 1) % 4]
            px_, py_ = corners[k - 1]
            # move the corner inward along both neighbouring edges
            ax = gx + (px_ - gx) * (r / abs(px_ - gx) if px_ != gx else 0) if px_ != gx else gx
            ay = gy + (py_ - gy) * (r / abs(py_ - gy) if py_ != gy else 0) if py_ != gy else gy
            bx_ = gx + (nx - gx) * (r / abs(nx - gx) if nx != gx else 0) if nx != gx else gx
            by_ = gy + (ny - gy) * (r / abs(ny - gy) if ny != gy else 0) if ny != gy else gy
            A, C, B = p(ax, ay, z), p(gx, gy, z), p(bx_, by_, z)
            path += ("M%.1f,%.1f " % A if k == 0 else "L%.1f,%.1f " % A) + "Q%.1f,%.1f %.1f,%.1f " % (C + B)
        return path + "Z"

    # roof side faces (thickness)
    svg.poly([c4, c3, e3, e4], ROOF, OUT)
    svg.poly([c3, c2, e2, e3], shade(ROOF, 0.8), OUT)
    svg.path(rounded(e1, e2, e3, e4, 132), ROOF_L, OUT)
    svg.line_op([p(-0.46, 0.76, 132), p(-0.46, -0.88, 132), p(0.42, -0.88, 132)], "#FFFFFF", 4, 0.35)
    # roof light bar
    lx, ly = p(0.0, 0.55, 132)
    svg.ellipse(lx, ly - 4, 20, 9, YEL, OUT, 2)
    svg.write("props/steam_tuk_tuk")


def spirit_house():
    W, H = 220, 360 + FOOT
    svg, iso = Svg(W, H), Iso(W, H)
    iso.shadow(svg, 0.7, 0.7)
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
    W, H = 160, 720 + FOOT
    svg, iso = Svg(W, H), Iso(W, H)
    iso.shadow(svg, 0.35, 0.35)
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
    W, H = 300, 440 + FOOT
    svg, iso = Svg(W, H), Iso(W, H)
    iso.shadow(svg, 1.0, 1.0)
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
    W, H = 110, 130 + FOOT
    svg, iso = Svg(W, H), Iso(W, H)
    iso.shadow(svg, 0.4, 0.4)
    for gx, gy in ((-0.15, -0.15), (0.15, -0.15), (0.15, 0.15), (-0.15, 0.15)):
        x, y = iso.p(gx, gy, 0)
        svg.line([(x, y), (x, y - 34 * S)], shade(col, 0.6), 6)
    iso.box(svg, -0.2, -0.2, 0.2, 0.2, 34, 40, col)
    x, y = iso.p(0, 0, 40)
    svg.ellipse(x, y, 8, 4, shade(col, 0.75), "none", 0)
    svg.write("props/" + name)


def steam_bike():
    W, H = 380, 260 + FOOT
    svg, iso = Svg(W, H), Iso(W, H)
    iso.shadow(svg, 1.4, 0.7)
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
    W, H = 300, 520 + FOOT
    svg, iso = Svg(W, H), Iso(W, H)
    iso.shadow(svg, 1.0, 1.0)
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
    W, H = 400, 280 + FOOT
    svg, iso = Svg(W, H), Iso(W, H)
    iso.shadow(svg, 1.5, 1.0)
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
    W, H = 240, 200 + FOOT
    svg, iso = Svg(W, H), Iso(W, H)
    iso.shadow(svg, 0.9, 0.9)
    iso.box(svg, -0.45, -0.45, 0.45, 0.45, 0, 60, WOOD)
    for z in (12, 48):
        x1, y1 = iso.p(-0.45, 0.45, z)
        x2, y2 = iso.p(0.45, 0.45, z)
        x3, y3 = iso.p(0.45, -0.45, z)
        svg.line([(x1, y1), (x2, y2), (x3, y3)], WOOD_D, 5)
    svg.rivets([iso.p(x, 0.45, z) for x in (-0.35, 0.35) for z in (12, 48)], 3)
    svg.write("props/crate")


def sign():
    W, H = 180, 300 + FOOT
    svg, iso = Svg(W, H), Iso(W, H)
    iso.shadow(svg, 0.5, 0.3)
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
    W, H = 180, 380 + FOOT
    svg, iso = Svg(W, H), Iso(W, H)
    iso.shadow(svg, 0.5, 0.5)
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
              trousers=SOOT, hair=SOOT, female=False):
    d = "characters/%s/" % folder
    # head 100x120, pivot bottom centre (neck)
    s = Svg(100, 120)
    if female:                                     # long hair behind the head
        s.path("M22,50 Q10,110 24,118 L80,118 Q94,110 80,50 Z", hair, OUT)
    s.ellipse(50, 70, 32, 36, skin, OUT)          # face
    s.add('<ellipse cx="50" cy="70" rx="32" ry="36" fill="url(#faceShade)"/>')
    s.add('<defs><linearGradient id="faceShade" x1="0" x2="1"><stop offset="0" stop-color="#FFFFFF" '
          'stop-opacity="0.25"/><stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0"/>'
          '<stop offset="1" stop-color="#000000" stop-opacity="0.22"/></linearGradient></defs>')
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
        s.path("M18,66 Q20,80 26,86", "none", hair, 5)      # grey sideburn
        s.path("M16,58 A34,36 0 0,1 84,58 Z", WOOD, OUT)     # flat cap
        s.path("M14,58 L92,58 L98,68 L14,64 Z", WOOD_D, OUT)
        s.glow(40, 36, 14, 6, 0.25)
        s.path("M58,88 q10,-6 20,0 q-10,8 -20,0 Z", "#D9D4C7", OUT, 2)
        s.ellipse(50, 44, 8, 3, "none", "none", 0)
    elif hat == "bun":                             # bangs + high bun + brass hairpin (market lady)
        s.path("M16,62 A34,40 0 0,1 84,62 L84,56 Q70,66 56,54 Q44,70 16,60 Z", hair, OUT)
        s.circle(44, 22, 15, hair, OUT)
        s.glow(40, 18, 6, 4, 0.3)
        s.line([(26, 12), (60, 28)], BRASS, 4)
        s.circle(26, 12, 4, RED, OUT, 1.5)
        s.circle(82, 78, 5, "none", BRASS, 2.5)      # hoop earring
    if female:
        s.ellipse(62, 74, 4, 5, OUT, OUT, 1)        # bigger eye + lashes
        s.line([(58, 67), (54, 63)], OUT, 2)
        s.line([(64, 66), (64, 61)], OUT, 2)
        s.path("M64,89 q6,-3 11,0 q-5,5 -11,0 Z", RED, RED_D, 1.5)   # lips
        s.glow(70, 80, 6, 3, 0.25)                  # blush/cheek highlight
    else:
        s.circle(62, 74, 3.5, OUT, OUT, 1)          # eye (3/4 right)
        s.line([(66, 88), (74, 86)], OUT, 2.5)      # mouth
    s.path("M74,68 l5,6 -5,4", "none", shade(skin, 0.8), 2)   # nose
    s.rect(44, 102, 14, 16, shade(skin, 0.8), OUT, 4)         # neck
    s.write(d + "head")

    # torso 110x130, pivot bottom centre (hips)
    s = Svg(110, 130)
    if female:                                       # blouse with waist + apron skirt
        s.path("M24,18 L86,18 L80,62 L92,112 L18,112 L30,62 Z", shirt, OUT)
        s.path("M30,18 L80,18 L74,60 L36,60 Z", shade(shirt, 1.1), "none", 0)
        s.path("M34,64 L76,64 L86,112 L24,112 Z", vest, OUT)   # apron
        s.path("M48,64 L62,64 L62,22 L48,22 Z", vest, OUT)     # apron bib
        s.line([(40, 86), (70, 86)], shade(vest, 0.8), 2)
        s.rect(30, 60, 50, 8, BRASS_D, OUT, 2)       # belt
        s.rect(49, 58, 12, 12, BRASS, OUT, 2)
        s.shade_lr(22, 18, 68, 94, 0.2, 0.2)
    else:
        s.path("M22,18 L88,18 L96,110 L14,110 Z", shirt, OUT)       # shirt
        if vest:
            s.path("M30,18 L80,18 L84,110 L26,110 Z", vest, OUT)    # vest / apron
            s.path("M34,18 L48,18 L46,110 L36,110 Z", shade(vest, 0.85), "none", 0)
        s.rect(30, 56, 50, 10, BRASS_D, OUT, 2)      # belt
        s.rect(48, 54, 14, 14, BRASS, OUT, 2)
        s.rivets([(40, 30), (70, 30), (40, 92), (70, 92)])
        s.line([(24, 20), (18, 60)], SOOT, 6)        # bag strap
        s.shade_lr(22, 18, 70, 92, 0.2, 0.2)
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
        s.ellipse(ox + 20, 92, 13, 15, skin, OUT)    # hand
        s.shade_lr(ox + 8, 4, 24, 66, 0.22, 0.25)
        s.glow(ox + 15, 86, 4, 5, 0.3)
        s.write(d + name)

    # legs 44x136, pivot top centre (hip)
    for name, col in (("leg_l", shade(trousers, 1.3)), ("leg_r", trousers)):
        s = Svg(44, 136)
        s.path("M8,2 L36,2 L34,96 L10,96 Z", col, OUT)
        s.rect(6, 94, 32, 16, WOOD_D, OUT, 3)        # boot cuff
        s.path("M8,108 L36,108 L42,130 L4,130 Z", WOOD_D, OUT)  # boot
        s.rect(10, 126, 32, 6, SOOT, OUT, 1)
        s.shade_lr(8, 2, 28, 94, 0.2, 0.25)
        s.glow(14, 112, 4, 3, 0.3)
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
    character("je_muay", skin="#F2CBA6", shirt="#D96C8C", vest="#F2E6D0", hat="bun", wrench=False,
              trousers="#5A3A6A", hair="#1C1418", female=True)
    brass_automaton()
