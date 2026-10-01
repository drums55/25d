"""Painterly PNG renderer for 25d props (numpy + PIL + scipy).

Hades-like look built procedurally: every part is a mask filled with a lit
colour field (light from the top-left), a dark inner outline, a warm rim light
on the lit edges, ambient occlusion low down, brush-stroke texture, and a
thick dark silhouette outline at the end. Rendered at SS x then downsampled.

Geometry: iso 2:1, 1 cell = 256x128 image px (2x art). p(gx, gy, z) where
+gx goes down-right, +gy goes down-left (front faces lower-left), z = image px
up. Origin (0,0,0) = (W/2, H - FOOT).
"""
import math
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

FOOT = 160
OUT = (30, 26, 31)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32) / 255.0


BRASS, BRASS_L, BRASS_D = hexc("#C9A04A"), hexc("#F2D58A"), hexc("#7A5A22")
COPPER, COPPER_D = hexc("#A8653D"), hexc("#5E331C")
TEAL, MINT = hexc("#3F7A74"), hexc("#5E8F86")
RED = hexc("#C0392B")
SOOT = hexc("#2B2629")
STEEL = hexc("#A7B0B8")
CREAM = hexc("#EFE3C8")
WOOD = hexc("#8B5A2B")
WARM = hexc("#FFE2A8")   # rim / lantern light
LIGHT = np.array([-0.55, -0.62, 0.56])  # screen x (right), screen y (down), toward viewer
LIGHT = LIGHT / np.linalg.norm(LIGHT)


class Canvas:
    def __init__(self, w, h, ss=3, seed=7):
        self.w, self.h, self.ss = w, h, ss
        self.W, self.H = w * ss, h * ss
        self.rgb = np.zeros((self.H, self.W, 3), np.float32)
        self.a = np.zeros((self.H, self.W), np.float32)
        self.rng = np.random.default_rng(seed)
        yy, xx = np.mgrid[0:self.H, 0:self.W].astype(np.float32)
        self.xx, self.yy = xx, yy
        self.tex = self._brush_texture()

    # ---------------- geometry ----------------
    def p(self, gx, gy, z=0.0):
        s = self.ss
        return ((self.w / 2 + (gx - gy) * 128) * s, (self.h - FOOT + (gx + gy) * 64 - z) * s)

    def P(self, x, y):
        """Plain image coords (1x art px) -> SS coords."""
        return (x * self.ss, y * self.ss)

    def mask_poly(self, pts):
        im = Image.new("L", (self.W, self.H), 0)
        ImageDraw.Draw(im).polygon([(float(x), float(y)) for x, y in pts], fill=255)
        return np.asarray(im, np.float32) / 255.0

    def mask_ellipse(self, cx, cy, rx, ry):
        im = Image.new("L", (self.W, self.H), 0)
        ImageDraw.Draw(im).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
        return np.asarray(im, np.float32) / 255.0

    def mask_line(self, pts, width):
        im = Image.new("L", (self.W, self.H), 0)
        d = ImageDraw.Draw(im)
        d.line([(float(x), float(y)) for x, y in pts], fill=255, width=int(width), joint="curve")
        for x, y in (pts[0], pts[-1]):
            d.ellipse([x - width / 2, y - width / 2, x + width / 2, y + width / 2], fill=255)
        return np.asarray(im, np.float32) / 255.0

    # ---------------- texture ----------------
    def _brush_texture(self):
        n = self.rng.standard_normal((self.H, self.W)).astype(np.float32)
        a = ndimage.gaussian_filter(n, sigma=(1.2 * self.ss, 7 * self.ss))   # horizontal-ish strokes
        b = ndimage.gaussian_filter(n[::-1], sigma=(9 * self.ss, 1.5 * self.ss))  # vertical strokes
        c = ndimage.gaussian_filter(self.rng.standard_normal((self.H, self.W)).astype(np.float32), 18 * self.ss)
        t = a / (a.std() + 1e-6) * 0.5 + b / (b.std() + 1e-6) * 0.35 + c / (c.std() + 1e-6) * 0.6
        return t / t.std()

    # ---------------- painting ----------------
    def paint(self, mask, field, outline=2.2, rim=0.0, rim_col=WARM, tex=0.075, ao=None):
        """Composite a part. field: HxWx3 colour (already lit). outline in 1x px."""
        m = np.clip(mask, 0, 1)
        if m.max() <= 0:
            return m
        col = field * (1.0 + tex * self.tex)[..., None]
        if ao is not None:
            col = col * ao[..., None]
        if rim > 0:
            # lit edge: inside the mask but the mask shifted toward the light is empty
            s = self.ss
            sh = ndimage.shift(m, (3.2 * s, 2.6 * s), order=1)  # content moved down-right
            edge = np.clip(m - sh, 0, 1)
            edge = ndimage.gaussian_filter(edge, 0.8 * s) * m
            col = col + (rim_col[None, None, :] - col) * (np.clip(edge * 1.6, 0, 1) * rim)[..., None]
        if outline > 0:
            er = ndimage.binary_erosion(m > 0.5, iterations=max(1, int(outline * self.ss)))
            ring = np.clip(m - ndimage.gaussian_filter(er.astype(np.float32), 0.6 * self.ss), 0, 1)
            col = col * (1 - ring[..., None]) + np.array(OUT, np.float32)[None, None, :] / 255.0 * ring[..., None]
        self.rgb = self.rgb * (1 - m[..., None]) + col * m[..., None]
        self.a = self.a + m * (1 - self.a)
        return m

    # colour fields
    def flat(self, c):
        return np.broadcast_to(np.asarray(c, np.float32), (self.H, self.W, 3)).copy()

    def grad(self, c, k_top=1.1, k_bot=0.8, y0=None, y1=None, x0=None, x1=None, kx=0.12):
        """Vertical gradient (lighter top) + slight left-lit horizontal falloff."""
        y0 = 0 if y0 is None else y0
        y1 = self.H if y1 is None else y1
        t = np.clip((self.yy - y0) / max(1, y1 - y0), 0, 1)
        k = k_top + (k_bot - k_top) * t
        if x0 is not None:
            u = np.clip((self.xx - x0) / max(1, x1 - x0), 0, 1)
            k = k * (1 + kx * (0.5 - u) * 2)
        return np.clip(np.asarray(c)[None, None, :] * k[..., None], 0, 1)

    def cyl_field(self, c, cx, rx, spec=0.0, amb=0.42, spec_col=None):
        """Vertical cylinder shading around screen x=cx with half-width rx."""
        u = np.clip((self.xx - cx) / rx, -1, 1)
        nz = np.sqrt(np.clip(1 - u * u, 0, 1))
        lam = np.clip(u * LIGHT[0] + nz * LIGHT[2], 0, 1)
        k = amb + (1.15 - amb) * lam
        col = np.asarray(c)[None, None, :] * k[..., None]
        if spec > 0:
            hv = LIGHT + np.array([0, 0, 1.0])
            hv = hv / np.linalg.norm(hv)
            sp = np.clip(u * hv[0] + nz * hv[2], 0, 1) ** 28 * spec
            sc = WARM if spec_col is None else spec_col
            col = col + (sc[None, None, :] - col) * np.clip(sp, 0, 1)[..., None]
        # reflected warm bounce on the shadow side edge
        bounce = np.clip((u - 0.78) / 0.22, 0, 1) * 0.18
        col = col + (hexc("#C98A55")[None, None, :] - col) * bounce[..., None]
        return np.clip(col, 0, 1)

    # ---------------- primitives ----------------
    def box(self, x0, y0, x1, y1, z0, z1, c, rim=0.8, outline=2.2, top_k=1.12, front_k=0.86, side_k=0.55, tex=0.05):
        p = self.p
        # +y face (front, faces lower-left) and +x face (faces lower-right)
        front = [p(x0, y1, z0), p(x1, y1, z0), p(x1, y1, z1), p(x0, y1, z1)]
        side = [p(x1, y1, z0), p(x1, y0, z0), p(x1, y0, z1), p(x1, y1, z1)]
        top = [p(x0, y0, z1), p(x1, y0, z1), p(x1, y1, z1), p(x0, y1, z1)]
        ytop = min(q[1] for q in top)
        ybot = max(q[1] for q in front + side)
        xl = min(q[0] for q in front)
        xr = max(q[0] for q in side)
        hz = (z1 - z0) * self.ss
        mf = self.mask_poly(front)
        ms = self.mask_poly(side)
        mt = self.mask_poly(top)
        aof = self._ao_z(z0, z1, x0, y1)
        self.paint(mf, self.grad(c, front_k * 1.08, front_k * 0.82, ybot - hz - 60 * self.ss, ybot, xl, xr), outline, rim * 0.5, ao=aof, tex=tex)
        self.paint(ms, self.grad(c, side_k * 1.05, side_k * 0.8, ybot - hz - 60 * self.ss, ybot), outline, 0, ao=aof, tex=tex)
        self.paint(mt, self.grad(c, top_k * 1.06, top_k * 0.94, ytop, ytop + 140 * self.ss, xl, xr, 0.1), outline, rim, tex=tex)
        return mf, ms, mt

    def _ao_z(self, z0, z1, gx, gy):
        """Darken the lowest ~35% of a vertical face (ambient occlusion)."""
        _, ybase = self.p(gx, gy, z0)
        # approximate: use distance above the bottom edge in screen px along y
        hz = (z1 - z0) * self.ss
        t = np.clip((ybase + 80 * self.ss - self.yy) / max(1.0, hz * 0.5 + 1), 0, 1)
        return 0.78 + 0.22 * t

    def cylinder(self, cx, cy, r, z0, z1, c, spec=0.7, rim=0.6, top_c=None, outline=2.2, tex=0.05):
        bx, by = self.p(cx, cy, z0)
        tx, ty = self.p(cx, cy, z1)
        rx, ry = r * 128 * self.ss, r * 64 * self.ss
        body = np.maximum(self.mask_poly([(tx - rx, ty), (tx + rx, ty), (bx + rx, by), (bx - rx, by)]),
                          self.mask_ellipse(bx, by, rx, ry))
        f = self.cyl_field(c, bx, rx, spec)
        ao = 0.8 + 0.2 * np.clip((by + ry - self.yy) / max(1, (by - ty) * 0.4), 0, 1)
        self.paint(body, f, outline, rim, ao=ao, tex=tex)
        tc = c * 1.12 if top_c is None else top_c
        top = self.mask_ellipse(tx, ty, rx, ry)
        self.paint(top, self.grad(tc, 1.12, 0.86, ty - ry, ty + ry, tx - rx, tx + rx, 0.2), outline, rim, tex=tex)
        return body, top, (tx, ty, rx, ry, bx, by)

    def band(self, cx, cy, r, z0, z1, c, spec=0.9):
        """Metal belt around a cylinder (no top cap)."""
        bx, by = self.p(cx, cy, z0)
        tx, ty = self.p(cx, cy, z1)
        rx, ry = r * 128 * self.ss * 1.02, r * 64 * self.ss * 1.02
        m = np.clip(np.maximum(self.mask_poly([(tx - rx, ty), (tx + rx, ty), (bx + rx, by), (bx - rx, by)]),
                               self.mask_ellipse(bx, by, rx, ry)) - self.mask_ellipse(tx, ty, rx, ry), 0, 1)
        self.paint(m, self.cyl_field(c, bx, rx, spec), 1.6, 0.4)

    def pipe(self, pts, width, c, spec=0.8, outline=2.0):
        """Tube along a polyline (SS coords); shaded across its width."""
        m = self.mask_line(pts, width * self.ss)
        # distance field to the centreline gives a tube normal
        cl = self.mask_line(pts, 1.5 * self.ss) > 0.5
        dist, idx = ndimage.distance_transform_edt(~cl, return_indices=True)
        dx = self.xx - idx[1]
        dy = self.yy - idx[0]
        rr = width * self.ss / 2
        nx, ny = dx / rr, dy / rr
        nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
        lam = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
        k = 0.4 + 0.8 * lam
        col = np.asarray(c)[None, None, :] * k[..., None]
        sp = np.clip(lam, 0, 1) ** 24 * spec
        col = col + (WARM[None, None, :] - col) * sp[..., None]
        self.paint(m, np.clip(col, 0, 1), outline, 0.2, tex=0.03)
        return m

    def disc(self, cx, cy, rx, ry, c, outline=1.8, rim=0.5, dome=True, spec=0.6, tex=0.04):
        m = self.mask_ellipse(cx, cy, rx, ry)
        if dome:
            nx = np.clip((self.xx - cx) / rx, -1, 1)
            ny = np.clip((self.yy - cy) / ry, -1, 1)
            nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
            lam = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
            col = np.asarray(c)[None, None, :] * (0.45 + 0.75 * lam)[..., None]
            col = col + (WARM[None, None, :] - col) * (lam ** 30 * spec)[..., None]
        else:
            col = self.grad(c, 1.1, 0.85, cy - ry, cy + ry, cx - rx, cx + rx)
        self.paint(m, np.clip(col, 0, 1), outline, rim, tex=tex)
        return m

    def stroke(self, pts, width, c, alpha=1.0):
        """Unshaded painted line (details, scratches)."""
        m = self.mask_line(pts, width * self.ss) * alpha
        self.rgb = self.rgb * (1 - m[..., None]) + np.asarray(c)[None, None, :] * m[..., None]
        self.a = self.a + m * (1 - self.a)

    def glaze(self, mask, c, alpha):
        """Translucent colour over existing paint (light, shadow, glow)."""
        m = np.clip(mask, 0, 1) * alpha * (self.a > 0)
        self.rgb = self.rgb * (1 - m[..., None]) + np.asarray(c)[None, None, :] * m[..., None]

    def rivets(self, pts, r=3.2):
        for x, y in pts:
            self.disc(x, y, r * self.ss, r * self.ss, BRASS, outline=1.0, rim=0.0, spec=1.0)

    def gauge(self, cx, cy, r, angle=-40):
        s = self.ss
        self.disc(cx, cy, (r + 4) * s, (r + 4) * s, BRASS, 1.6, 0.6)
        self.disc(cx, cy, r * s, r * s, CREAM, 1.2, 0.0, dome=False)
        for k in range(-3, 4):
            a = math.radians(-90 + k * 30)
            self.stroke([(cx + math.cos(a) * r * 0.72 * s, cy + math.sin(a) * r * 0.72 * s),
                         (cx + math.cos(a) * r * 0.9 * s, cy + math.sin(a) * r * 0.9 * s)], 1.2, SOOT)
        a = math.radians(angle - 90)
        self.stroke([(cx, cy), (cx + math.cos(a) * r * 0.75 * s, cy + math.sin(a) * r * 0.75 * s)], 1.8, RED)
        self.disc(cx, cy, 1.8 * s, 1.8 * s, SOOT, 0.5, 0)
        # glass glint
        self.glaze(self.mask_ellipse(cx - r * 0.35 * s, cy - r * 0.4 * s, r * 0.3 * s, r * 0.18 * s), (1, 1, 1), 0.55)

    def ground_shadow(self, fx, fy, opacity=0.38):
        """Soft contact shadow under the footprint (call first). Same size as
        the .svg props bake in, so painted and vector props match."""
        cx, cy = self.p(0, 0, 0)
        r = (fx + fy) * 0.5 * 128 * 0.75 * self.ss
        m = np.maximum(self.mask_ellipse(cx, cy + 4 * self.ss, r * 1.15, r * 0.575) * 0.4,
                       self.mask_ellipse(cx, cy + 2 * self.ss, r, r * 0.5))
        m = ndimage.gaussian_filter(m, 3 * self.ss) * opacity
        self.a = np.maximum(self.a, m)   # black: premultiplied rgb stays 0

    def ink_ring(self, mask, outline):
        """Dark outline just inside a mask (for parts painted in pieces)."""
        m = np.clip(mask, 0, 1)
        er = ndimage.binary_erosion(m > 0.5, iterations=max(1, int(outline * self.ss)))
        ring = np.clip(m - ndimage.gaussian_filter(er.astype(np.float32), 0.6 * self.ss), 0, 1)
        self.glaze(ring, np.array(OUT, np.float32) / 255.0, 1.0)

    def cyl_pt(self, cx, cy, r, u, z):
        """Screen point on the visible (near) surface of a vertical cylinder at
        horizontal fraction u in [-1, 1] (0 = straight toward the camera)."""
        x, y = self.p(cx, cy, z)
        return (x + u * r * 128 * self.ss, y + math.sqrt(max(0.0, 1 - u * u)) * r * 64 * self.ss)

    def wheel(self, gx, gy, zc, r_cells, r_z, axis="x", spokes=True):
        """Wheel standing on its rim. axis="x": wheel plane is x-z (rolls along
        x); axis="y": plane y-z (rolls along y)."""
        p, s = self.p, self.ss

        def at(t, k):
            dx = math.cos(t) * r_cells * k
            return p(gx + (dx if axis == "x" else 0), gy + (dx if axis == "y" else 0), zc + math.sin(t) * r_z * k)

        def ring(k):
            return [at(t, k) for t in np.linspace(0, 2 * math.pi, 64, endpoint=False)]
        cx, cy = p(gx, gy, zc)
        self.paint(self.mask_poly(ring(1.0)), self.grad(SOOT * 1.3, 1.2, 0.7, cy - r_z * s, cy + r_z * s), 2.2, 0.5)
        self.paint(self.mask_poly(ring(0.74)), self.grad(STEEL * 0.55, 1.1, 0.8, cy - r_z * s, cy + r_z * s), 1.4, 0.2)
        if spokes:
            for t in np.linspace(0, math.pi, 6, endpoint=False):
                self.stroke([at(t, 0.72), at(t + math.pi, 0.72)], 1.6, STEEL * 0.95)
        self.glaze(self.mask_poly(ring(0.58)), SOOT, 0.25)
        hr = max(5.0, r_z * 0.18)
        self.disc(cx, cy, hr * s * 0.8, hr * s, BRASS, 1.2, 0.3, spec=1.0)
        self.stroke([at(t, 0.92) for t in np.linspace(math.radians(110), math.radians(200), 12)], 1.6, WARM * 0.8, 0.6)

    def prism(self, poly, z0, z1, c, top_c=None, rim=0.7, outline=2.2, side_only=False, smooth=False):
        """Vertical extrusion of a convex grid-space polygon (list of (gx, gy),
        any winding). Faces lit by their outward normal; top on top."""
        p, s = self.p, self.ss
        cxg = sum(q[0] for q in poly) / len(poly)
        cyg = sum(q[1] for q in poly) / len(poly)
        n = len(poly)
        sides = None
        ytop = min(p(*q, z1)[1] for q in poly)
        ybot = max(p(*q, z0)[1] for q in poly)
        for i in range(n):
            a, b = poly[i], poly[(i + 1) % n]
            ex, ey = b[0] - a[0], b[1] - a[1]
            nx, ny = ey, -ex
            mx, my = (a[0] + b[0]) / 2 - cxg, (a[1] + b[1]) / 2 - cyg
            if nx * mx + ny * my < 0:
                nx, ny = -nx, -ny
            L = math.hypot(nx, ny) or 1
            nx, ny = nx / L, ny / L
            if nx + ny <= 0.02:
                continue
            k = 0.705 + 0.155 * (ny - nx)
            face = [p(*a, z0), p(*b, z0), p(*b, z1), p(*a, z1)]
            ao = self._ao_z(z0, z1, *a)
            fm = self.mask_poly(face)
            sides = fm if sides is None else np.maximum(sides, fm)
            self.paint(fm, self.grad(c, k * 1.08, k * 0.82, ytop, ybot), 0.0 if smooth else outline,
                       rim * 0.4 if ny > nx else 0, ao=ao)
        if smooth and sides is not None:
            self.ink_ring(sides, outline)
        if not side_only:
            tc = c if top_c is None else top_c
            top = [p(*q, z1) for q in poly]
            ty0 = min(q[1] for q in top)
            self.paint(self.mask_poly(top), self.grad(tc, 1.16, 1.0, ty0, ty0 + 120 * s), outline, rim)

    def frustum(self, h0, h1, z0, z1, c, top_c=None, rim=0.8, outline=2.2, cx=0.0, cy=0.0):
        """Square frustum centred on (cx, cy): half-size h0 at z0 -> h1 at z1
        (h1 = 0 gives a pyramid). Lit like box()."""
        p = self.p
        b = [(cx - h0, cy - h0), (cx + h0, cy - h0), (cx + h0, cy + h0), (cx - h0, cy + h0)]
        t = [(cx - h1, cy - h1), (cx + h1, cy - h1), (cx + h1, cy + h1), (cx - h1, cy + h1)]
        ys = [p(*q, z0)[1] for q in b] + [p(*q, z1)[1] for q in t]
        y0, y1 = min(ys), max(ys)
        # +y face (front) and +x face (side): slanted, so lighter than walls
        front = [p(*b[3], z0), p(*b[2], z0), p(*t[2], z1), p(*t[3], z1)]
        side = [p(*b[2], z0), p(*b[1], z0), p(*t[1], z1), p(*t[2], z1)]
        back_l = [p(*b[0], z0), p(*b[3], z0), p(*t[3], z1), p(*t[0], z1)]
        back_r = [p(*b[1], z0), p(*b[0], z0), p(*t[0], z1), p(*t[1], z1)]
        slope = (h0 - h1) > 0.02
        if slope:  # the far faces are visible from above when the faces slope in
            self.paint(self.mask_poly(back_r), self.grad(c, 1.08, 0.95, y0, y1), outline, rim)
            self.paint(self.mask_poly(back_l), self.grad(c, 1.15, 1.0, y0, y1), outline, rim)
        self.paint(self.mask_poly(front), self.grad(c, 0.98, 0.78, y0, y1), outline, rim * 0.5)
        self.paint(self.mask_poly(side), self.grad(c, 0.66, 0.52, y0, y1), outline, 0)
        if h1 > 0.005:
            top = [p(*q, z1) for q in t]
            tc = c if top_c is None else top_c
            self.paint(self.mask_poly(top), self.grad(tc, 1.15, 1.0, min(q[1] for q in top), max(q[1] for q in top) + 1),
                       outline, rim)

    def gear(self, cx, cy, r, col, teeth=9, flat=0.5, hole=0.32, outline=1.6):
        """Gear seen lying flat (flat = y squash; 1 = facing the camera)."""
        pts = []
        n = teeth * 4
        for i in range(n):
            a = 2 * math.pi * i / n
            rr = r if (i % 4) in (1, 2) else r * 0.78
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * flat))
        m = np.clip(self.mask_poly(pts) - self.mask_ellipse(cx, cy, r * hole, r * hole * flat), 0, 1)
        nx = np.clip((self.xx - cx) / r, -1, 1)
        col_f = self.grad(col, 1.2, 0.8, cy - r * flat, cy + r * flat, cx - r, cx + r, 0.3)
        self.paint(m, col_f, outline, 0.7, tex=0.05)
        # thickness lip for flat-lying gears
        if flat < 0.8:
            lip = np.clip(ndimage.shift(m, (3.5 * self.ss, 0), order=0) - m, 0, 1)
            self.paint(lip, self.flat(np.asarray(col) * 0.5), 0.6, 0)

    # ---------------- finish ----------------
    def text(self, txt, p0, p1, height, c, alpha=1.0, size=140, align="center"):
        """Flat-painted text on a face. p0 -> p1 (SS coords) is the top edge of
        the text box along the face; `height` is the box height in 1x px
        (straight down on screen, i.e. vertical faces). Thai shapes correctly
        (PIL with raqm + Kanit)."""
        from PIL import ImageFont
        import os as _os
        font = ImageFont.truetype(_os.path.join(_os.path.dirname(__file__), "..", "..", "..",
                                                "assets", "fonts", "Kanit-Medium.ttf"), size)
        l, t, r, b = font.getbbox(txt)
        tw, th = r - l, b - t
        timg = Image.new("L", (tw + 8, th + 8), 0)
        ImageDraw.Draw(timg).text((4 - l, 4 - t), txt, font=font, fill=255)
        tw, th = timg.size
        ux, uy = p1[0] - p0[0], p1[1] - p0[1]
        L = math.hypot(ux, uy)
        H = height * self.ss
        k = min(L / tw, H / th)
        ex, ey = ux / L, uy / L
        off = (L - tw * k) * (0.5 if align == "center" else 0.0)
        ox = p0[0] + ex * off
        oy = p0[1] + ey * off + (H - th * k) * 0.5
        # output (X, Y) = o + x*k*e + y*k*(0, 1)  ->  inverse for PIL AFFINE
        m = np.array([[k * ex, 0.0], [k * ey, k]])
        inv = np.linalg.inv(m)
        cx = -(inv[0, 0] * ox + inv[0, 1] * oy)
        cy = -(inv[1, 0] * ox + inv[1, 1] * oy)
        warped = timg.transform((self.W, self.H), Image.AFFINE,
                                (inv[0, 0], inv[0, 1], cx, inv[1, 0], inv[1, 1], cy), resample=Image.BILINEAR)
        mm = np.asarray(warped, np.float32) / 255.0 * alpha
        self.rgb = self.rgb * (1 - mm[..., None]) + np.asarray(c)[None, None, :] * mm[..., None]
        self.a = self.a + mm * (1 - self.a)

    def finish(self, path, sil=2.6):
        s = self.ss
        a = self.a
        solid = a > 0.5
        dil = ndimage.binary_dilation(solid, iterations=int(sil * s))
        ring = ndimage.gaussian_filter(dil.astype(np.float32), 0.7 * s)
        outc = np.array(OUT, np.float32) / 255.0
        rgb = self.rgb + outc[None, None, :] * (ring * (1 - a))[..., None]   # premultiplied
        alpha = a + ring * (1 - a)
        un = rgb / np.maximum(alpha, 1e-4)[..., None]
        un = np.clip((un - 0.5) * 1.06 + 0.5, 0, 1)
        rgba = np.dstack([un * alpha[..., None], alpha])
        ss = self.ss
        small = rgba.reshape(self.h, ss, self.w, ss, 4).mean(axis=(1, 3))
        al = small[..., 3:4]
        col = np.where(al > 1e-3, small[..., :3] / np.maximum(al, 1e-3), 0)
        out = np.dstack([np.clip(col, 0, 1), np.clip(al, 0, 1)])
        out[out[..., 3] < 2 / 255.0] = 0
        Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(path)
        return path
