"""Painted UI for กรุงเทพฯ 2090 (owner 2026-10-02: the menus looked like PowerPoint).
Run: python3 ui_2090.py <out_dir>        (writes every piece into assets/art/ui/)

The in-game menu is the rider's debt notebook lying open; buttons are hand-painted
tin signs (ป้ายสังกะสี) like on every Bangkok soi; story cards are paper notes
taped over the screen. Everything is painted with PIL + numpy at SS x and scaled
down. 9-slice pieces (sign_*, note) are 1x with their margins listed in
scripts/ui/ui_kit.gd; the notebook is one fixed picture at NOTE_SCALE x."""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy.ndimage import gaussian_filter

SS = 3
ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "..")
FONT_HAND = os.path.join(ROOT, "assets/fonts/Sriracha-Regular.ttf")
FONT_SIGN = os.path.join(ROOT, "assets/fonts/Mali-SemiBold.ttf")
# notebook: display size in the 1920x1200 viewport, painted 1.5x for the tablet
BOOK_W, BOOK_H = 1520, 1000
BOOK_SCALE = 1.5

PAPER = (239, 230, 207)
INK = (40, 32, 44)
RED_INK = (196, 40, 40)
LINE_BLUE = (120, 150, 196)
COVER = (122, 30, 30)
RIBBON = (226, 98, 30)


def rng(seed):
    return np.random.default_rng(seed)


def noise(w, h, seed, blur=1.5, amp=1.0):
    n = gaussian_filter(rng(seed).standard_normal((h, w)), blur)
    n /= max(1e-6, np.abs(n).max())
    return n * amp


def rgba(color, a=255):
    return tuple(color[:3]) + (a,)


def tint(base, n, k):
    """base RGB + noise field n (-1..1) scaled k -> float image HxWx3."""
    arr = np.empty(n.shape + (3,), np.float32)
    for i in range(3):
        arr[..., i] = base[i] + n * k
    return np.clip(arr, 0, 255)


def to_img(arr, alpha=None):
    a = np.clip(arr, 0, 255).astype(np.uint8)
    im = Image.fromarray(a, "RGB").convert("RGBA")
    if alpha is not None:
        im.putalpha(Image.fromarray(np.clip(alpha, 0, 255).astype(np.uint8), "L"))
    return im


def wobble_line(draw, pts, width, color, seed, jitter=1.5, steps=10):
    r = rng(seed)
    out = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        for k in range(steps):
            t = k / steps
            out.append((x0 + (x1 - x0) * t + r.normal(0, jitter), y0 + (y1 - y0) * t + r.normal(0, jitter)))
    out.append(pts[-1])
    draw.line(out, fill=color, width=int(width), joint="curve")


def rough_rect_mask(w, h, seed, rough=3.0, radius=0):
    """Alpha mask of a slightly ragged rectangle (paper edge)."""
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    if radius:
        d.rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=255)
    else:
        d.rectangle((0, 0, w - 1, h - 1), fill=255)
    a = np.asarray(m, np.float32)
    edge = noise(w, h, seed, 2.0, rough * 40)
    a = gaussian_filter(a, rough) + edge
    return np.clip((a - 100) * 3, 0, 255)


def text(draw, xy, s, font_path, size, color, anchor="la"):
    draw.text(xy, s, font=ImageFont.truetype(font_path, int(size)), fill=color, anchor=anchor)


def shadow(im, off=(0, 10), blur=14, alpha=0.45, pad=40):
    """Paste im over a soft drop shadow on a padded canvas."""
    w, h = im.size
    out = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    a = im.split()[3].point(lambda v: int(v * alpha))
    sh = Image.new("RGBA", im.size, (0, 0, 0, 255))
    sh.putalpha(a)
    out.alpha_composite(sh, (pad + off[0], pad + off[1]))
    out = out.filter(ImageFilter.GaussianBlur(blur))
    out.alpha_composite(im, (pad, pad))
    return out


def save(im, out_dir, name, scale=1.0, ss=SS):
    w, h = im.size
    k = scale / ss
    im = im.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)
    im.save(os.path.join(out_dir, name + ".png"), optimize=True)
    print("wrote", name, im.size)


# --- the debt notebook (menu) ----------------------------------------------------
def notebook(out_dir):
    # the notebook is big: 2x supersampling only
    s = 2 * BOOK_SCALE
    W, H = int(BOOK_W * s), int(BOOK_H * s)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # leather cover
    cw, ch = W, int((BOOK_H - 40) * s)
    n = noise(cw, ch, 1, 2.0) + noise(cw, ch, 2, 12.0) * 0.6
    cover = to_img(tint(COVER, n, 26), rough_rect_mask(cw, ch, 3, 2.0, int(30 * s)))
    d = ImageDraw.Draw(cover)
    inset = 16 * s
    for k in range(0, int((cw - 2 * inset) / (18 * s))):
        x = inset + k * 18 * s
        d.line((x, inset, x + 9 * s, inset), fill=(232, 196, 150, 200), width=int(3 * s))
        d.line((x, ch - inset, x + 9 * s, ch - inset), fill=(232, 196, 150, 200), width=int(3 * s))
    canvas.alpha_composite(cover, (0, 0))
    # page stack under the pages (two pages, a few sheets each)
    px0, py0, mid, px1, py1 = 34 * s, 30 * s, W / 2, W - 34 * s, ch - 30 * s
    sd = ImageDraw.Draw(canvas)
    for k in range(4, 0, -1):
        o = k * 4 * s
        sd.rounded_rectangle((px0 + o * 0.3, py0 + o, px1 - o * 0.3, py1 + o * 0.8), 10 * s,
                             fill=(214 - k * 8, 204 - k * 8, 178 - k * 8, 255))
    # the two pages
    pw, ph = int(px1 - px0), int(py1 - py0)
    pn = noise(pw, ph, 5, 1.2) * 0.6 + noise(pw, ph, 6, 30.0) * 0.7
    page = tint(PAPER, pn, 9)
    # spine shading + gutter
    xs = np.arange(pw)[None, :] + px0
    dist = np.abs(xs - mid) / s
    shade = np.clip(1.0 - dist / 90.0, 0, 1) ** 2 * 70 + np.clip(1.0 - dist / 12.0, 0, 1) * 40
    page -= shade[..., None]
    # yellowed outer edges
    edge = np.minimum(np.arange(pw)[None, :], pw - 1 - np.arange(pw)[None, :]) / s
    edge = np.minimum(edge, np.minimum(np.arange(ph)[:, None], ph - 1 - np.arange(ph)[:, None]) / s)
    page -= (np.clip(1.0 - edge / 40.0, 0, 1) ** 2)[..., None] * np.array([10, 22, 48])
    pim = to_img(page, rough_rect_mask(pw, ph, 7, 1.0, int(10 * s)))
    pd = ImageDraw.Draw(pim)
    # ruled lines + red margins
    y = 150 * s - py0
    while y < ph - 40 * s:
        pd.line((20 * s, y, pw - 20 * s, y), fill=rgba(LINE_BLUE, 110), width=max(1, int(1.6 * s)))
        y += 64 * s
    for mx in (130 * s - px0, 840 * s - px0):
        pd.line((mx, 30 * s, mx, ph - 30 * s), fill=rgba(RED_INK, 110), width=int(2 * s))
    # binding stitches
    for k in range(9):
        yy = (60 + k * 100) * s
        pd.line((mid - px0, yy, mid - px0, yy + 40 * s), fill=(90, 70, 60, 200), width=int(3 * s))
    canvas.alpha_composite(pim, (int(px0), int(py0)))
    cd = ImageDraw.Draw(canvas)
    # coffee ring on the right page (drawn on its own layer, then blended)
    r = rng(9)
    cx, cy, rr = 1330 * s, 820 * s, 70 * s
    ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    for k in range(4):
        j = r.normal(0, 2 * s, 2)
        rd.ellipse((cx - rr + j[0], cy - rr * 0.92 + j[1], cx + rr + j[0], cy + rr * 0.92 + j[1]),
                   outline=(140, 90, 40, 60), width=int((2 + k) * s))
    canvas.alpha_composite(ring.filter(ImageFilter.GaussianBlur(1.5 * s)))
    # old debts scribbled faintly at the foot of the right page
    faint = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fd = ImageDraw.Draw(faint)
    text(fd, (880 * s, 842 * s), "เจ๊เกียว 30,000  ดอกลอย 400/วัน", FONT_HAND, 30 * s, rgba(INK, 70))
    text(fd, (890 * s, 882 * s), "จ่ายแล้ว ... 0", FONT_HAND, 30 * s, rgba(RED_INK, 80))
    faint = faint.rotate(1.2, resample=Image.BICUBIC, center=(1060 * s, 860 * s))
    canvas.alpha_composite(faint)
    # ribbon bookmark out of the bottom of the spine
    rb = [(mid + 30 * s, py1 - 40 * s), (mid + 70 * s, py1 - 40 * s), (mid + 76 * s, H - 30 * s),
          (mid + 52 * s, H - 52 * s), (mid + 26 * s, H - 26 * s)]
    cd.polygon(rb, fill=rgba(RIBBON))
    cd.line(rb + [rb[0]], fill=(120, 40, 10, 255), width=int(2.5 * s))
    out = shadow(canvas, (0, int(14 * s)), int(18 * s), 0.55, int(40 * s))
    # keep the picture exactly BOOK_W x BOOK_H (shadow padding cropped back)
    pad = int(40 * s)
    out = out.crop((pad, pad, pad + W, pad + H))
    save(out, out_dir, "notebook", 1.0, 2)


def pen_circle(out_dir):
    """Red-pen scribble around the open page's name."""
    w, h = 300 * SS, 110 * SS
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = rng(11)
    for loop in range(2):
        pts = []
        a0 = -2.4 + loop * 0.4
        for k in range(48):
            a = a0 + k / 44 * 2 * math.pi
            rx, ry = w * (0.46 - loop * 0.02), h * (0.40 - loop * 0.03)
            pts.append((w / 2 + math.cos(a) * rx + r.normal(0, 1.5 * SS),
                        h / 2 + math.sin(a) * ry + r.normal(0, 1.5 * SS) + loop * 3 * SS))
        d.line(pts, fill=rgba(RED_INK, 230), width=int(4.5 * SS), joint="curve")
    save(im, out_dir, "pen_circle")


def check_boxes(out_dir):
    for name, ticked in (("box", False), ("box_ticked", True)):
        w = 56 * SS
        im = Image.new("RGBA", (w, w), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        m = 10 * SS
        wobble_line(d, [(m, m), (w - m, m + 2), (w - m - 2, w - m), (m + 2, w - m - 1), (m, m)],
                    3.5 * SS, rgba(INK, 235), 13 + ticked)
        if ticked:
            wobble_line(d, [(m + 4 * SS, w * 0.5), (w * 0.45, w - m + 2 * SS), (w - 2 * SS, 2 * SS)],
                        6 * SS, rgba(RED_INK), 17, 1.0)
        save(im, out_dir, name)


def ink_blot(out_dir):
    w = 44 * SS
    im = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    a = np.zeros((w, w), np.float32)
    yy, xx = np.mgrid[0:w, 0:w]
    rr = np.hypot(xx - w / 2, yy - w / 2) / (w * 0.36)
    a = (1.0 - rr + noise(w, w, 21, 3.0, 0.25)) * 900
    col = tint(RED_INK, noise(w, w, 22, 2.0), 20)
    im = to_img(col, np.clip(a, 0, 255))
    save(im, out_dir, "ink_blot")


# --- tin signs (buttons) --------------------------------------------------------
SIGN_W, SIGN_H, SIGN_M = 220, 96, 30
SIGNS = {
    "sign": ((246, 214, 92), (176, 36, 30)),  # yellow enamel, red border
    "sign_pressed": ((222, 182, 70), (140, 26, 22)),
    "sign_hover": ((255, 228, 120), (196, 46, 36)),
    "sign_disabled": ((178, 176, 166), (110, 108, 100)),
    "sign_teal": ((86, 170, 160), (24, 70, 72)),
}


def tin_sign(out_dir, name, face, border, seed):
    w, h = SIGN_W * SS, SIGN_H * SS
    # a little room for the drop shadow inside the 9-slice margins
    pad = 6 * SS
    iw, ih = w - pad * 2, h - pad * 2
    n = noise(iw, ih, seed, 1.5) * 0.7 + noise(iw, ih, seed + 1, 10.0)
    face_arr = tint(face, n, 14)
    # enamel border band
    yy, xx = np.mgrid[0:ih, 0:iw]
    band = np.minimum(np.minimum(xx, iw - 1 - xx), np.minimum(yy, ih - 1 - yy)) / SS
    inner = (band > 5) & (band < 10)
    face_arr[inner] = tint(border, n, 10)[inner]
    face_arr[band <= 5] = np.array(face) * 0.92
    # rust freckles near the edges
    rust = noise(iw, ih, seed + 2, 2.5) > 0.55
    rust &= band < 22
    face_arr[rust] = face_arr[rust] * 0.55 + np.array([140, 70, 30]) * 0.45
    # soft top light, bottom shade (dented tin)
    face_arr *= (1.06 - 0.14 * (yy / ih))[..., None]
    sign = to_img(face_arr, rough_rect_mask(iw, ih, seed + 3, 0.8, int(10 * SS)))
    d = ImageDraw.Draw(sign)
    for cx, cy in ((16, 16), (iw / SS - 16, 16), (16, ih / SS - 16), (iw / SS - 16, ih / SS - 16)):
        r = 4.2 * SS
        d.ellipse((cx * SS - r, cy * SS - r, cx * SS + r, cy * SS + r), fill=(110, 110, 112, 255),
                  outline=(50, 50, 52, 255), width=int(1.2 * SS))
        d.ellipse((cx * SS - r * 0.4, cy * SS - r * 0.6, cx * SS, cy * SS - r * 0.1), fill=(220, 220, 220, 255))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sh = Image.new("RGBA", sign.size, (0, 0, 0, 0))
    sh.putalpha(sign.split()[3].point(lambda v: int(v * 0.5)))
    tmp = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    tmp.alpha_composite(sh, (pad, pad + 3 * SS))
    tmp = tmp.filter(ImageFilter.GaussianBlur(3 * SS))
    out.alpha_composite(tmp)
    out.alpha_composite(sign, (pad, pad))
    save(out, out_dir, name)


# --- paper note (cards) ---------------------------------------------------------
NOTE_W, NOTE_H, NOTE_M = 520, 380, 96


def note(out_dir):
    w, h = NOTE_W * SS, NOTE_H * SS
    pad = 18 * SS
    iw, ih = w - pad * 2, h - pad * 2
    n = noise(iw, ih, 31, 1.2) * 0.5 + noise(iw, ih, 32, 4.0) * 0.5
    arr = tint((242, 234, 214), n, 8)
    yy, xx = np.mgrid[0:ih, 0:iw]
    edge = np.minimum(np.minimum(xx, iw - 1 - xx), np.minimum(yy, ih - 1 - yy)) / SS
    arr -= (np.clip(1.0 - edge / 30.0, 0, 1) ** 2)[..., None] * np.array([8, 20, 44])
    paper = to_img(arr, rough_rect_mask(iw, ih, 33, 2.4))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sh = Image.new("RGBA", paper.size, (0, 0, 0, 0))
    sh.putalpha(paper.split()[3].point(lambda v: int(v * 0.55)))
    tmp = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    tmp.alpha_composite(sh, (pad, pad + 8 * SS))
    tmp = tmp.filter(ImageFilter.GaussianBlur(7 * SS))
    out.alpha_composite(tmp)
    out.alpha_composite(paper, (pad, pad))
    # masking tape on the two top corners (inside the 9-slice corners)
    # (kept inside the 96 px corners, or the 9-slice repeats it along the edge)
    for cx, ang in ((44, 28), (NOTE_W - 44, -28)):
        tw, th = 96 * SS, 36 * SS
        tn = noise(tw, th, 40 + cx, 1.5)
        tape = to_img(tint((226, 214, 170), tn, 10), rough_rect_mask(tw, th, 41 + cx, 1.2) * 0.82)
        tape = tape.rotate(ang, resample=Image.BICUBIC, expand=True)
        out.alpha_composite(tape, (int(cx * SS - tape.width / 2), int(30 * SS - tape.height / 2)))
    save(out, out_dir, "note")


# --- menu button: the closed debt notebook ---------------------------------------
def notebook_icon(out_dir):
    w, h = 132 * SS, 132 * SS
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bw, bh = 96 * SS, 112 * SS
    n = noise(bw, bh, 51, 1.6) + noise(bw, bh, 52, 8.0) * 0.6
    book = to_img(tint(COVER, n, 24), rough_rect_mask(bw, bh, 53, 1.2, int(8 * SS)))
    d = ImageDraw.Draw(book)
    # pages peeking on the right, elastic band, label
    d.rectangle((bw - 7 * SS, 6 * SS, bw - 3 * SS, bh - 6 * SS), fill=(236, 226, 200, 255))
    d.rectangle((bw - 26 * SS, 0, bw - 18 * SS, bh), fill=(30, 26, 30, 255))
    d.rounded_rectangle((14 * SS, 30 * SS, bw - 34 * SS, 64 * SS), 4 * SS, fill=(240, 232, 210, 255))
    text(d, ((14 + bw / SS - 34) / 2 * SS, 47 * SS), "หนี้", FONT_HAND, 26 * SS, rgba(RED_INK), "mm")
    book = book.rotate(-8, resample=Image.BICUBIC, expand=True)
    out = shadow(book, (0, 4 * SS), 5 * SS, 0.6, 10 * SS)
    im.alpha_composite(out, ((w - out.width) // 2, (h - out.height) // 2))
    save(im, out_dir, "menu_book")


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    notebook(out_dir)
    pen_circle(out_dir)
    check_boxes(out_dir)
    ink_blot(out_dir)
    for k, (name, (face, border)) in enumerate(SIGNS.items()):
        tin_sign(out_dir, name, face, border, 60 + k * 7 if name != "sign_pressed" else 60)
    note(out_dir)
    notebook_icon(out_dir)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets/art/ui"))
