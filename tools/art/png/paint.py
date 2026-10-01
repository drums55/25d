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

    # ---------------- finish ----------------
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
