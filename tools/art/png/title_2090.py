"""Title screen key art: กรุงเทพฯ 2090 at dusk (owner 2026-10-02: "ทำฉากหลังหน้าแรก").
Run: python3 title_2090.py <out.png>     (default assets/art/ui/title_bg.png)

Back to front: dusk sky + low sun, the company's dry glass towers behind the sea
wall, a half-drowned temple prang, the soi's stilt houses with warm windows,
power poles and sagging wires, steam, then the canal with reflections and water
hyacinth. The left third is kept dark for the title and the menu signs; the
rider on the เรือเตอร์ไซค์ is added live by main_menu.gd (it bobs on the water).
Painted at 2560x1600 (the tablet) for a 1920x1200 viewport."""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "..")
FONT_SIGN = os.path.join(ROOT, "assets/fonts/Mali-SemiBold.ttf")
W, H = 2560, 1600
K = W / 1920  # design coordinates are 1920x1200
HORIZON = 760


def k(v):
    return int(v * K)


def rng(seed):
    return np.random.default_rng(seed)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def layer():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def sky(img):
    top, mid, low = (22, 20, 52), (120, 62, 96), (246, 150, 82)
    arr = np.zeros((H, W, 3), np.float32)
    for y in range(H):
        t = y / k(HORIZON)
        if t < 0.55:
            c = lerp(top, mid, t / 0.55)
        elif t <= 1.0:
            c = lerp(mid, low, (t - 0.55) / 0.45)
        else:
            c = low
        arr[y] = c
    img.paste(Image.fromarray(arr.astype(np.uint8)).convert("RGBA"))
    # low sun with a glow
    g = layer()
    d = ImageDraw.Draw(g)
    sx, sy = k(1330), k(640)
    for r, a in ((k(260), 40), (k(170), 70), (k(110), 120)):
        d.ellipse((sx - r, sy - r, sx + r, sy + r), fill=(255, 196, 120, a))
    d.ellipse((sx - k(70), sy - k(70), sx + k(70), sy + k(70)), fill=(255, 226, 170, 255))
    img.alpha_composite(g.filter(ImageFilter.GaussianBlur(k(18))))
    # thin clouds
    c = layer()
    d = ImageDraw.Draw(c)
    r = rng(3)
    for _ in range(14):
        x, y = r.uniform(0, W), r.uniform(k(90), k(520))
        w = r.uniform(k(220), k(560))
        d.ellipse((x - w / 2, y - k(10), x + w / 2, y + k(14)), fill=(255, 170, 140, int(r.uniform(30, 70))))
    img.alpha_composite(c.filter(ImageFilter.GaussianBlur(k(6))))


def towers(img):
    """The dry side: glass towers behind the sea wall, windows lit."""
    t = layer()
    d = ImageDraw.Draw(t)
    r = rng(5)
    x = k(820)
    while x < W:
        w = r.uniform(k(70), k(150))
        top = r.uniform(k(170), k(470))
        col = tuple(int(v) for v in r.uniform([46, 52, 82], [70, 78, 112]))
        d.rectangle((x, top, x + w, k(HORIZON)), fill=col + (255,))
        # windows
        for wy in np.arange(top + k(14), k(HORIZON) - k(40), k(18)):
            for wx in np.arange(x + k(8), x + w - k(8), k(14)):
                if r.random() < 0.42:
                    lit = (255, 214, 140) if r.random() < 0.8 else (150, 230, 255)
                    d.rectangle((wx, wy, wx + k(6), wy + k(8)), fill=lit + (int(r.uniform(140, 255)),))
        if r.random() < 0.4:  # antenna
            d.line((x + w / 2, top, x + w / 2, top - k(40)), fill=col + (255,), width=k(3))
            d.ellipse((x + w / 2 - k(4), top - k(44), x + w / 2 + k(4), top - k(36)), fill=(255, 70, 60, 255))
        x += w + r.uniform(k(6), k(40))
    img.alpha_composite(t)
    # haze over the towers
    hz = layer()
    ImageDraw.Draw(hz).rectangle((0, k(380), W, k(HORIZON)), fill=(246, 150, 110, 40))
    img.alpha_composite(hz.filter(ImageFilter.GaussianBlur(k(30))))
    # the sea wall
    w_ = layer()
    d = ImageDraw.Draw(w_)
    d.rectangle((k(700), k(640), W, k(HORIZON)), fill=(70, 66, 74, 255))
    d.rectangle((k(700), k(632), W, k(646)), fill=(110, 104, 108, 255))
    for x in range(k(720), W, k(120)):
        d.line((x, k(646), x, k(HORIZON)), fill=(56, 52, 60, 255), width=k(3))
    f = ImageFont.truetype(FONT_SIGN, k(30))
    d.text((k(1500), k(668)), "บจ. ป้องกันภัย  •  พื้นที่แห้ง เฉพาะผู้ได้รับอนุญาต", font=f, fill=(228, 196, 120, 230))
    img.alpha_composite(w_)


def prang(img):
    """A half-drowned temple prang (Wat Arun-like) on the left, in silhouette."""
    p = layer()
    d = ImageDraw.Draw(p)
    cx, base = k(980), k(HORIZON + 20)
    col = (44, 30, 52, 255)
    tiers = [(k(150), k(70)), (k(118), k(70)), (k(90), k(70)), (k(66), k(60)), (k(44), k(60)), (k(26), k(50))]
    y = base
    for hw, hgt in tiers:
        d.polygon([(cx - hw, y), (cx - hw * 0.86, y - hgt), (cx + hw * 0.86, y - hgt), (cx + hw, y)], fill=col)
        d.rectangle((cx - hw * 0.9, y - k(8), cx + hw * 0.9, y - k(4)), fill=(90, 60, 70, 255))
        y -= hgt
    d.polygon([(cx - k(16), y), (cx, y - k(110)), (cx + k(16), y)], fill=col)
    # warm rim light from the sun side
    rim = p.filter(ImageFilter.GaussianBlur(k(2)))
    img.alpha_composite(p)
    edge = layer()
    ImageDraw.Draw(edge).polygon([(cx + k(150), base), (cx + k(26), base - k(330)), (cx + k(4), y - k(100)), (cx + k(30), base - k(330)),
                                  (cx + k(160), base)], fill=(255, 150, 90, 70))
    img.alpha_composite(edge.filter(ImageFilter.GaussianBlur(k(6))))
    del rim


def stilt_houses(img):
    """The soi: stilt houses with zinc roofs and lit windows, poles and wires."""
    h = layer()
    d = ImageDraw.Draw(h)
    r = rng(11)
    x = k(-40)
    roofs = []
    while x < W + k(40):
        w = r.uniform(k(150), k(250))
        floor = k(HORIZON + 40) + r.uniform(-k(10), k(30))
        top = floor - r.uniform(k(110), k(170))
        wall = tuple(int(v) for v in r.uniform([70, 46, 40], [112, 70, 58]))
        # stilts
        for sx in np.linspace(x + k(10), x + w - k(10), 4):
            d.rectangle((sx, floor, sx + k(6), floor + k(70)), fill=(40, 28, 26, 255))
        d.rectangle((x, top, x + w, floor), fill=wall + (255,))
        # zinc roof
        peak = top - r.uniform(k(40), k(70))
        d.polygon([(x - k(14), top + k(6)), (x + w / 2, peak), (x + w + k(14), top + k(6))], fill=(92, 98, 104, 255))
        for gx in np.arange(x - k(10), x + w + k(10), k(12)):
            d.line((gx, top + k(4), x + w / 2 + (gx - x - w / 2) * 0.1, peak + k(4)), fill=(70, 76, 82, 255), width=1)
        roofs.append((x + w / 2, peak))
        # windows with warm light
        for wx in np.arange(x + k(16), x + w - k(40), k(54)):
            if r.random() < 0.8:
                d.rectangle((wx, top + k(26), wx + k(30), top + k(60)), fill=(255, 196, 110, 255))
                d.line((wx + k(15), top + k(26), wx + k(15), top + k(60)), fill=wall + (255,), width=k(3))
        # waterline stain
        d.rectangle((x, floor - k(18), x + w, floor), fill=tuple(int(v * 0.7) for v in wall) + (255,))
        x += w + r.uniform(k(10), k(60))
    # glow around the lit windows
    glow = h.copy().filter(ImageFilter.GaussianBlur(k(14)))
    img.alpha_composite(glow, (0, 0))
    img.alpha_composite(h)
    # power poles + sagging wires
    pw = layer()
    d = ImageDraw.Draw(pw)
    poles = [k(x_) for x_ in (160, 640, 1080, 1560, 1980)]
    for px in poles:
        d.rectangle((px - k(6), k(470), px + k(6), k(HORIZON + 110)), fill=(30, 24, 30, 255))
        d.rectangle((px - k(40), k(492), px + k(40), k(500)), fill=(30, 24, 30, 255))
    for a, b in zip(poles, poles[1:]):
        for dy, sag in ((0, 60), (8, 80), (16, 52), (24, 96)):
            pts = []
            for t in np.linspace(0, 1, 30):
                pts.append((a + (b - a) * t, k(496 + dy) + math.sin(math.pi * t) * k(sag)))
            d.line(pts, fill=(24, 20, 26, 255), width=k(2))
    # a neon sign hanging on the wires
    nx, ny = k(820), k(600)
    d.rectangle((nx, ny, nx + k(150), ny + k(54)), fill=(30, 20, 36, 255))
    f = ImageFont.truetype(FONT_SIGN, k(34))
    neon = layer()
    nd = ImageDraw.Draw(neon)
    nd.text((nx + k(16), ny + k(4)), "ส่งไว", font=f, fill=(255, 90, 170, 255))
    img.alpha_composite(pw)
    img.alpha_composite(neon.filter(ImageFilter.GaussianBlur(k(8))))
    img.alpha_composite(neon)
    # steam from a few roofs
    st = layer()
    sd = ImageDraw.Draw(st)
    for rx, ry in roofs[1::3]:
        for j in range(4):
            rr = k(18 + j * 10)
            sd.ellipse((rx - rr + j * k(14), ry - k(40) - j * k(34) - rr, rx + rr + j * k(14), ry - k(40) - j * k(34) + rr),
                       fill=(235, 230, 240, 70 - j * 12))
    img.alpha_composite(st.filter(ImageFilter.GaussianBlur(k(6))))


def water(img):
    """The canal: reflections of everything above, ripples, water hyacinth."""
    top = k(HORIZON + 40)
    above = img.crop((0, top - (H - top), W, top)).transpose(Image.FLIP_TOP_BOTTOM)
    above = above.resize((W, H - top)).filter(ImageFilter.GaussianBlur(k(3)))
    arr = np.asarray(above).astype(np.float32)
    # ripple: shift rows sideways
    rows = arr.shape[0]
    r = rng(17)
    out = np.empty_like(arr)
    for y in range(rows):
        shift = int(math.sin(y * 0.09) * k(6) + r.normal(0, k(2)))
        out[y] = np.roll(arr[y], shift, axis=0)
    # darken + teal tint, deeper toward the viewer
    t = np.linspace(0.0, 1.0, rows)[:, None, None]
    teal = np.array([18, 52, 64], np.float32)
    out[..., :3] = out[..., :3] * (0.55 - 0.3 * t) + teal * (0.45 + 0.3 * t)
    out[..., 3] = 255
    wimg = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
    img.paste(wimg, (0, top))
    d = ImageDraw.Draw(img)
    for _ in range(260):
        y = r.uniform(top + k(6), H)
        x = r.uniform(0, W)
        ln = r.uniform(k(20), k(90)) * (0.5 + (y - top) / (H - top))
        d.line((x, y, x + ln, y), fill=(150, 210, 210, int(r.uniform(30, 90))), width=max(1, k(2)))
    # sun path on the water
    sp = layer()
    sd = ImageDraw.Draw(sp)
    for _ in range(90):
        y = r.uniform(top, H)
        w = r.uniform(k(30), k(140)) * (0.4 + (y - top) / (H - top))
        x = k(1330) + r.normal(0, k(60) + (y - top) * 0.25)
        sd.line((x - w / 2, y, x + w / 2, y), fill=(255, 190, 120, int(r.uniform(60, 150))), width=k(3))
    img.alpha_composite(sp.filter(ImageFilter.GaussianBlur(k(1))))
    # water hyacinth clumps
    hy = layer()
    hd = ImageDraw.Draw(hy)
    for _ in range(26):
        y = r.uniform(top + k(40), H - k(20))
        x = r.uniform(0, W)
        s = 0.6 + (y - top) / (H - top)
        for j in range(5):
            ox, oy = r.normal(0, k(18) * s), r.normal(0, k(5) * s)
            rr = k(14) * s
            hd.ellipse((x + ox - rr, y + oy - rr * 0.5, x + ox + rr, y + oy + rr * 0.5),
                       fill=(48 + int(r.uniform(0, 30)), 110, 60, 255))
        if r.random() < 0.4:
            hd.ellipse((x - k(5) * s, y - k(16) * s, x + k(5) * s, y - k(6) * s), fill=(186, 150, 230, 255))
    img.alpha_composite(hy)


def soi_life(img):
    """Laundry lines between the houses and a longtail boat on the canal."""
    l = layer()
    d = ImageDraw.Draw(l)
    r = rng(23)
    colors = [(214, 70, 60), (240, 200, 80), (80, 150, 210), (240, 240, 230), (232, 118, 45), (120, 190, 120)]
    for x0 in (k(60), k(560), k(1240), k(1700)):
        x1 = x0 + k(170)
        y0 = k(HORIZON - 70)
        pts = [(x0 + (x1 - x0) * t, y0 + math.sin(math.pi * t) * k(18)) for t in np.linspace(0, 1, 20)]
        d.line(pts, fill=(30, 26, 30, 255), width=k(2))
        for t in np.linspace(0.12, 0.88, 5):
            cx = x0 + (x1 - x0) * t
            cy = y0 + math.sin(math.pi * t) * k(18)
            c = colors[int(r.integers(0, len(colors)))]
            w, h = k(r.uniform(16, 26)), k(r.uniform(22, 34))
            d.rectangle((cx - w / 2, cy, cx + w / 2, cy + h), fill=c + (255,))
    img.alpha_composite(l)
    # longtail boat (silhouette with a warm lamp), right of centre
    b = layer()
    d = ImageDraw.Draw(b)
    bx, by = k(1520), k(940)
    d.polygon([(bx - k(220), by - k(8)), (bx + k(200), by - k(18)), (bx + k(250), by - k(60)),
               (bx + k(170), by + k(12)), (bx - k(200), by + k(14))], fill=(36, 26, 30, 255))
    d.line((bx - k(220), by - k(8), bx - k(330), by + k(40)), fill=(36, 26, 30, 255), width=k(5))
    d.ellipse((bx - k(40), by - k(70), bx - k(20), by - k(50)), fill=(255, 200, 110, 255))
    d.line((bx - k(30), by - k(50), bx - k(30), by - k(10)), fill=(36, 26, 30, 255), width=k(3))
    glow = b.filter(ImageFilter.GaussianBlur(k(10)))
    img.alpha_composite(glow)
    img.alpha_composite(b)


def menu_shade(img):
    """Keep the left side dark enough for the title and the signs."""
    g = np.zeros((H, W), np.float32)
    xs = np.linspace(0, 1, W)[None, :]
    g[:] = np.clip(1.0 - xs / 0.46, 0, 1) ** 1.2 * 235
    ys = np.linspace(0, 1, H)[:, None]
    g += np.clip(ys - 0.85, 0, 1) * 400  # bottom edge
    shade = Image.fromarray(np.clip(g, 0, 230).astype(np.uint8), "L")
    dark = Image.new("RGBA", (W, H), (10, 8, 16, 255))
    dark.putalpha(shade)
    img.alpha_composite(dark)


def main(out):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    sky(img)
    towers(img)
    prang(img)
    stilt_houses(img)
    water(img)
    soi_life(img)
    menu_shade(img)
    img.convert("RGB").save(out, quality=92) if out.endswith(".jpg") else img.convert("RGB").save(out, optimize=True)
    print("wrote", out, img.size)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets/art/ui/title_bg.png"))
