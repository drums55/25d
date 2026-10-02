"""Painted item icons for the bag + things lying on the floor (DESIGN 11.5).
Run: python3 items.py all <dir>   (or: <name> <out.png>)
Each icon is painted with the prop style (paint.py), then trimmed and centred
on a square ICON x ICON canvas. One file per item id in assets/data/puzzles.json;
ArtLibrary.item(id) loads assets/art/items/<id>.png."""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from paint import *  # noqa: E402,F401,F403

ICON = 192
INK = hexc("#1E1A1F")
PAPER = hexc("#EFE6CF")
PINK = hexc("#FF8FC1")
ORANGE = hexc("#F07A1E")
YELLOW = hexc("#F2C230")
GREEN = hexc("#2E8B57")
WIRE = hexc("#B8C0C8")
IRON = hexc("#4A5560")
TAPE = hexc("#222326")


def _canvas(seed):
    return Canvas(360, 380, seed=seed)


def debt_book(c):
    p = c.p
    c.box(-0.32, -0.24, 0.32, 0.24, 0, 10, PAPER, rim=0.4)
    c.box(-0.34, -0.26, 0.34, 0.26, 10, 34, RED, rim=0.8)
    c.text("หนี้", p(-0.25, 0.261, 30), p(0.25, 0.261, 30), 16, PAPER)
    c.disc(*p(0.0, 0.0, 34), 30 * c.ss, 15 * c.ss, PAPER, dome=False)
    c.text("30,000", p(-0.18, 0.0, 36), p(0.18, 0.0, 36), 10, RED)


def gum(c):
    p = c.p
    for k, (dx, dy, r) in enumerate(((0, 0, 40), (-24, -10, 26), (22, -14, 24), (6, -30, 20))):
        x, y = p(0, 0, 30)
        c.disc(x + dx * c.ss, y + dy * c.ss, r * c.ss, r * 0.8 * c.ss, PINK, spec=0.9)


def hanger(c):
    p = c.p
    pts = [p(-0.45, 0.0, 10), p(0.45, 0.0, 10), p(0.0, 0.0, 120), p(-0.45, 0.0, 10)]
    c.pipe(pts, 10, WIRE)
    c.pipe([p(0.0, 0.0, 120), p(0.0, 0.0, 150), p(0.08, 0.0, 168), p(0.15, 0.0, 150)], 10, WIRE)


def hook(c):
    p = c.p
    c.pipe([p(-0.55, 0.3, 10), p(0.5, -0.3, 120)], 6, WIRE)
    x, y = p(0.52, -0.31, 124)
    c.disc(x, y, 22 * c.ss, 18 * c.ss, PINK, spec=0.9)


def float_key(c):
    p = c.p
    c.pipe([p(-0.1, 0.0, 40), p(0.35, 0.0, 40)], 10, BRASS)
    for u in (0.24, 0.31):
        c.pipe([p(u, 0.0, 40), p(u, 0.0, 22)], 7, BRASS)
    x, y = p(-0.18, 0.0, 40)
    c.disc(x, y, 22 * c.ss, 22 * c.ss, BRASS, dome=False)
    c.disc(x, y, 8 * c.ss, 8 * c.ss, INK, dome=False)
    # rubber duck on the ring
    dx, dy = p(-0.38, 0.0, 70)
    c.disc(dx, dy + 10 * c.ss, 30 * c.ss, 22 * c.ss, YELLOW, spec=0.8)
    c.disc(dx - 14 * c.ss, dy - 16 * c.ss, 17 * c.ss, 17 * c.ss, YELLOW, spec=0.8)
    c.disc(dx - 30 * c.ss, dy - 14 * c.ss, 9 * c.ss, 5 * c.ss, ORANGE, dome=False)
    c.disc(dx - 16 * c.ss, dy - 20 * c.ss, 3 * c.ss, 3 * c.ss, INK, outline=0, dome=False)


def air_remote(c):
    p = c.p
    c.box(-0.12, -0.38, 0.12, 0.38, 0, 22, hexc("#D8DCDF"), rim=0.6)
    for k, col in enumerate((RED, hexc("#6E7880"), hexc("#6E7880"), hexc("#6E7880"))):
        x, y = p(0.0, -0.25 + k * 0.15, 22)
        c.disc(x, y, 12 * c.ss, 6 * c.ss, col)
    c.text("COOL", p(-0.1, 0.381, 12), p(0.1, 0.381, 12), 8, INK)


def letter(c):
    p = c.p
    c.box(-0.4, -0.26, 0.4, 0.26, 0, 6, PAPER, rim=0.5)
    c.stroke([p(-0.4, -0.26, 6), p(0.0, 0.0, 6), p(0.4, -0.26, 6)], 2.4, INK, 0.6)
    x, y = p(0.0, 0.02, 7)
    c.disc(x, y, 14 * c.ss, 8 * c.ss, RED, dome=False)


def sauce_packs(c):
    p = c.p
    for k in range(4):
        z = k * 10
        o = (k % 2) * 0.05
        c.box(-0.25 + o, -0.15 + o, 0.25 + o, 0.15 + o, z, z + 9, ORANGE, rim=0.5, outline=1.6)
    c.text("ด้วยรัก", p(-0.18, 0.201, 36), p(0.22, 0.201, 36), 10, PAPER)


def brass_box(c):
    p = c.p
    c.box(-0.3, -0.3, 0.3, 0.3, 0, 90, BRASS, rim=0.9)
    c.box(-0.32, -0.32, 0.32, 0.32, 90, 100, BRASS_D, rim=0.7)
    c.gear(*p(0.0, 0.301, 45), 22 * c.ss, BRASS_D, teeth=9)
    c.rivets([p(x, 0.302, z) for x in (-0.24, 0.24) for z in (12, 78)])


def broken_crank(c):
    p = c.p
    c.pipe([p(-0.4, 0.1, 20), p(0.05, 0.1, 20), p(0.05, 0.1, 90)], 11, IRON)
    c.pipe([p(0.2, -0.15, 20), p(0.45, -0.15, 20)], 11, IRON)
    x, y = p(-0.4, 0.1, 20)
    c.disc(x, y, 16 * c.ss, 16 * c.ss, IRON)


def tape(c):
    _, _, (tx, ty, rx, ry, _bx, _by) = c.cylinder(0, 0, 0.3, 0, 40, TAPE, spec=0.5, top_c=TAPE * 1.4)
    c.disc(tx, ty, rx * 0.5, ry * 0.5, hexc("#B07A42"), dome=False)


def crank(c):
    p = c.p
    c.pipe([p(-0.4, 0.1, 20), p(0.25, 0.1, 20), p(0.25, 0.1, 90)], 11, IRON)
    for u in (-0.05, 0.05, 0.15):
        c.stroke([p(u, 0.1, 10), p(u, 0.1, 30)], 9, TAPE)
    x, y = p(-0.4, 0.1, 20)
    c.disc(x, y, 16 * c.ss, 16 * c.ss, IRON)


def memory_chip(c):
    p = c.p
    c.box(-0.25, -0.25, 0.25, 0.25, 0, 16, hexc("#2F6F6A"), rim=0.7)
    for k in range(5):
        u = -0.2 + k * 0.1
        c.stroke([p(u, 0.25, 4), p(u, 0.38, 0)], 4, BRASS)
        c.stroke([p(0.25, u, 4), p(0.38, u, 0)], 4, BRASS)
    c.text("9", p(-0.08, 0.0, 17), p(0.08, 0.0, 17), 18, BRASS_L)


def debt_list(c):
    p = c.p
    c.box(-0.3, -0.4, 0.3, 0.4, 0, 4, PAPER, rim=0.4)
    for k in range(7):
        g = -0.3 + k * 0.08
        c.stroke([p(-0.22, g, 5), p(0.18, g, 5)], 2.0, INK, 0.6)
    x, y = p(0.12, 0.26, 5)
    c.disc(x, y, 26 * c.ss, 14 * c.ss, RED, dome=False)


def reading_glasses(c):
    p = c.p
    for u in (-0.16, 0.16):
        x, y = p(u, 0.0, 30)
        c.disc(x, y, 34 * c.ss, 26 * c.ss, PINK, dome=False)
        c.disc(x, y, 24 * c.ss, 17 * c.ss, hexc("#BFE3EA"), outline=1.0, dome=False)
    c.stroke([p(-0.06, 0.0, 34), p(0.06, 0.0, 34)], 5, PINK)


def love_letter(c):
    p = c.p
    c.box(-0.4, -0.26, 0.4, 0.26, 0, 6, hexc("#F4B6C2"), rim=0.5)
    c.stroke([p(-0.4, -0.26, 6), p(0.0, 0.0, 6), p(0.4, -0.26, 6)], 2.4, INK, 0.5)
    x, y = p(0.0, 0.03, 7)
    for dx in (-9, 9):
        c.disc(x + dx * c.ss, y - 4 * c.ss, 11 * c.ss, 9 * c.ss, RED, outline=1.0, dome=False)
    c.paint(c.mask_poly([(x - 19 * c.ss, y - 2 * c.ss), (x + 19 * c.ss, y - 2 * c.ss), (x, y + 18 * c.ss)]),
            c.flat(RED), outline=0)


def megaphone(c):
    p = c.p
    x0, y0 = p(-0.3, 0.0, 70)
    x1, y1 = p(0.35, 0.0, 70)
    s = c.ss
    cone = [(x0, y0 - 18 * s), (x1, y1 - 56 * s), (x1, y1 + 56 * s), (x0, y0 + 18 * s)]
    c.paint(c.mask_poly(cone), c.flat(RED), outline=1.0)
    c.disc(x1, y1, 22 * s, 56 * s, hexc("#F4E9D8"), outline=1.0, dome=False)
    c.disc(x1, y1, 12 * s, 34 * s, hexc("#3A2E2A"), dome=False)
    c.box(-0.42, -0.06, -0.28, 0.06, 50, 90, IRON, rim=0.6)
    c.pipe([p(-0.12, 0.0, 66), p(-0.14, 0.0, 30), p(-0.04, 0.0, 26)], 9, INK)
    c.text("ดอก", p(-0.05, -0.12, 70), p(0.2, -0.12, 70), 12, YELLOW)


def ring(c):
    p = c.p
    x, y = p(0.0, 0.0, 60)
    s = c.ss
    pts = []
    for k in range(25):
        a = 2 * math.pi * k / 24
        pts.append((x + math.cos(a) * 52 * s, y + math.sin(a) * 40 * s))
    c.stroke(pts, 14, YELLOW)
    c.stroke(pts[14:20], 5, hexc("#FFF2B0"), 0.8)
    c.disc(x, y - 44 * s, 16 * s, 14 * s, hexc("#9FE3F0"), spec=1.0)
    for dx, dy in ((-30, 30), (20, 34), (40, 10)):
        c.disc(x + dx * s, y + dy * s, 8 * s, 5 * s, hexc("#5B4636"), dome=False)


# --- chapter-1 stretch (DESIGN 12.6) ------------------------------------------------
def platu(c):
    """ปลาทูย่างเสียบไม้ จากเตาลุงปลาทู: the cat's price."""
    p = c.p
    c.stroke([p(-0.3, 0.0, 10), p(0.34, 0.0, 10)], 3.0, hexc("#B07A42"))
    c.disc(*p(0.0, 0.0, 14), 42 * c.ss, 20 * c.ss, hexc("#B88040"), outline=1.6, rim=0.5)
    c.disc(*p(0.0, 0.0, 16), 26 * c.ss, 11 * c.ss, hexc("#D9A066"), outline=0.6, rim=0.2)
    c.stroke([p(0.26, 0.0, 14), p(0.36, 0.0, 26), p(0.36, 0.0, 2)], 2.4, hexc("#B88040"))
    c.disc(*p(-0.2, 0.0, 18), 3 * c.ss, 3 * c.ss, INK, outline=0.4)
    for x in (-0.1, 0.0, 0.1):
        c.stroke([p(x, 0.0, 22), p(x + 0.03, 0.0, 14)], 1.2, hexc("#6E4A2A"), 0.6)


def firecracker(c):
    """ประทัดงานวัดหนึ่งพวง: red tubes, a fuse."""
    p = c.p
    for k, x in enumerate((-0.16, -0.05, 0.06, 0.17)):
        c.cylinder(x, 0.0, 0.05, 0, 70 + (k % 2) * 10, RED, spec=0.5, rim=0.6, top_c=hexc("#F0C080"))
    c.stroke([p(0.0, 0.0, 80), p(0.1, 0.0, 110), p(0.04, 0.0, 130)], 2.0, hexc("#B8B8A0"))
    c.disc(*p(0.04, 0.0, 132), 4 * c.ss, 4 * c.ss, YELLOW, outline=0.4, spec=1.0)
    c.text("โชค", p(-0.2, 0.051, 50), p(0.2, 0.051, 50), 10, YELLOW)


def sauce_empty(c):
    """ซองน้ำจิ้มไก่เปล่า ที่ป้านกคืนมา: "โต๊ะ 3" written on the back."""
    p = c.p
    c.box(-0.26, -0.18, 0.26, 0.18, 0, 6, hexc("#E8E0D0"), rim=0.3)
    c.box(-0.22, -0.14, 0.22, 0.14, 6, 8, hexc("#F2A23A"), rim=0.1, outline=0.8)
    c.text("โต๊ะ 3", p(-0.2, 0.0, 10), p(0.2, 0.0, 10), 14, RED)
    c.stroke([p(0.2, -0.18, 6), p(0.28, -0.1, 6)], 1.6, INK)


def curler(c):
    """ที่ม้วนผมของป้าจุ๋ม (หายไปตั้งแต่เดือนก่อน): a blue roller with a pin."""
    p = c.p
    c.cylinder(0.0, 0.0, 0.16, 0, 60, hexc("#7FC8E8"), spec=0.6, rim=0.5)
    for k in range(6):
        a = k * 3.1416 / 3
        c.disc(*p(0.16 * math.cos(a) * 0.9, 0.16 * math.sin(a) * 0.9, 60), 3 * c.ss, 2 * c.ss, hexc("#5AA0C8"), outline=0.4)
    c.stroke([p(-0.25, 0.0, 70), p(0.25, 0.0, 70)], 2.0, hexc("#E8E4DC"))


def goldfish(c):
    """น้องพยากรณ์ ปลาทองของลุงหมอน้ำ ในถุงพลาสติก: forecasts by swimming."""
    p = c.p
    c.disc(*p(0.0, 0.0, 40), 40 * c.ss, 48 * c.ss, hexc("#9ED8E0"), outline=1.4, rim=0.3, spec=0.6)
    c.glaze(c.mask_ellipse(*p(0.0, 0.0, 30), 34 * c.ss, 30 * c.ss), hexc("#3E7F8C"), 0.35)
    c.disc(*p(0.02, 0.0, 34), 14 * c.ss, 9 * c.ss, ORANGE, outline=1.2, rim=0.3)
    c.stroke([p(0.1, 0.0, 34), p(0.17, 0.0, 44), p(0.17, 0.0, 24)], 2.0, ORANGE)
    c.disc(*p(-0.05, 0.0, 38), 2 * c.ss, 2 * c.ss, INK, outline=0.4)
    c.stroke([p(-0.05, 0.0, 86), p(0.05, 0.0, 86), p(0.0, 0.0, 100)], 2.0, RED)


def amulet(c):
    """พระเครื่องกันน้ำ (ใบรับประกันไม่ครอบคลุมน้ำท่วม): a brass pendant on a cord."""
    p = c.p
    c.disc(*p(0.0, 0.0, 10), 30 * c.ss, 38 * c.ss, BRASS, outline=1.6, rim=0.6, spec=0.9)
    c.disc(*p(0.0, 0.0, 14), 18 * c.ss, 24 * c.ss, BRASS_D, outline=0.8, rim=0.2)
    c.disc(*p(0.0, 0.0, 16), 8 * c.ss, 10 * c.ss, BRASS, outline=0.6, spec=1.0)
    c.stroke([p(-0.2, 0.0, 60), p(0.0, 0.0, 48), p(0.2, 0.0, 60)], 2.0, hexc("#3A2A22"))


def parking_ticket(c):
    """ใบเสร็จค่าปรับจอดเรือในที่ห้ามจอด (ดาดฟ้า): the fine scales with the water."""
    p = c.p
    c.box(-0.22, -0.3, 0.22, 0.3, 0, 4, PAPER, rim=0.2)
    c.text("ใบสั่ง", p(-0.18, 0.0, 8), p(0.18, 0.0, 8), 12, hexc("#2E5E9E"))
    for k in range(4):
        c.stroke([p(-0.16, -0.2 + k * 0.1, 5), p(0.16, -0.2 + k * 0.1, 5)], 1.2, INK, 0.5)
    c.disc(*p(0.1, 0.18, 6), 8 * c.ss, 8 * c.ss, RED, outline=0.6, dome=False)


# --- chapter-2 stretch (DESIGN 12.7) ------------------------------------------------
def survey_form(c):
    """แบบสอบถามความพึงพอใจของบริษัท: five empty stars, the fifth pre-ticked."""
    p = c.p
    c.box(-0.26, -0.32, 0.26, 0.32, 0, 4, PAPER, rim=0.2)
    c.text("พึงพอใจ?", p(-0.2, 0.0, 8), p(0.2, 0.0, 8), 10, hexc("#2E5E9E"))
    for k in range(5):
        c.disc(*p(-0.18 + k * 0.09, 0.08, 6), 5 * c.ss, 5 * c.ss, YELLOW if k == 4 else PAPER, outline=0.8)
    for k in range(3):
        c.stroke([p(-0.2, 0.18 + k * 0.05, 5), p(0.2, 0.18 + k * 0.05, 5)], 1.0, INK, 0.4)


def brochure(c):
    """โบรชัวร์ "โครงการพื้นที่รับน้ำชุมชน": a smiling family, and a map with one soi painted blue."""
    p = c.p
    c.box(-0.26, -0.32, 0.26, 0.32, 0, 4, hexc("#7FB0E8"), rim=0.3)
    c.box(-0.2, -0.26, 0.2, -0.02, 4, 6, PAPER, rim=0.1, outline=0.8)
    c.disc(*p(-0.1, -0.14, 8), 5 * c.ss, 5 * c.ss, YELLOW, outline=0.6)
    c.disc(*p(0.04, -0.14, 8), 5 * c.ss, 5 * c.ss, YELLOW, outline=0.6)
    c.box(-0.2, 0.04, 0.2, 0.28, 4, 6, hexc("#C8D8C0"), rim=0.1, outline=0.8)
    c.box(-0.12, 0.1, 0.0, 0.22, 6, 8, hexc("#2E5E9E"), rim=0.1, outline=0.6)
    c.text("ภาพประกอบ", p(-0.2, 0.0, 10), p(0.2, 0.0, 10), 7, INK)


def son_note(c):
    """โน้ตจากน้องต้นถึงแม่ เขียนหลังแบบสอบถาม: "ไม่ได้กลับเพราะกะ ไม่ใช่เพราะไม่คิดถึง"."""
    p = c.p
    c.box(-0.26, -0.32, 0.26, 0.32, 0, 4, PAPER, rim=0.2)
    for k in range(5):
        c.stroke([p(-0.2, -0.2 + k * 0.1, 5), p(0.14 + (k % 2) * 0.06, -0.2 + k * 0.1, 5)], 1.2, hexc("#2E5E9E"), 0.8)
    c.disc(*p(0.14, 0.24, 6), 5 * c.ss, 4 * c.ss, RED, outline=0.5)


def adapter(c):
    """สายแปลงหัวต่อของลูกชายพี่เปิ้ล: company plug on one end, a game pad plug on the other."""
    p = c.p
    c.stroke([p(-0.3, 0.1, 10), p(-0.1, -0.1, 14), p(0.1, 0.1, 10), p(0.3, -0.05, 12)], 3.0, hexc("#2B2629"))
    c.box(-0.4, 0.04, -0.28, 0.16, 4, 20, hexc("#2E5E9E"), rim=0.5)
    c.box(0.28, -0.12, 0.4, 0.02, 4, 20, hexc("#3A6FD8"), rim=0.5)
    c.disc(*p(0.34, -0.05, 22), 2 * c.ss, 2 * c.ss, hexc("#4AE0C8"), outline=0.3, spec=1.0)


def lottery_ticket(c):
    """ลอตเตอรี่ของบริษัท เลขท้าย 69: every ticket, every draw."""
    p = c.p
    c.box(-0.3, -0.16, 0.3, 0.16, 0, 4, PAPER, rim=0.2)
    c.box(-0.3, -0.16, 0.3, -0.08, 4, 5, RED, rim=0.1, outline=0.6)
    c.text("ถูกแน่", p(-0.26, 0.0, 9), p(0.26, 0.0, 9), 7, RED)
    c.text("69", p(-0.26, 0.0, 5), p(0.26, 0.0, 5), 14, INK)


def blank_sign(c):
    """ป้ายโครงการแผ่นเปล่าจากน้องบอย: blue board, nothing printed yet."""
    p = c.p
    c.box(-0.3, -0.22, 0.3, 0.22, 0, 8, hexc("#2E5E9E"), rim=0.5)
    c.box(-0.3, -0.22, 0.3, -0.16, 8, 10, YELLOW, rim=0.2, outline=0.6)


def charcoal(c):
    """ถ่านไม้จากเตาป้านก: for rubbing marks off a post."""
    p = c.p
    for k, (x, y) in enumerate(((-0.12, 0.0), (0.08, 0.06), (0.0, -0.1))):
        c.disc(*p(x, y, 10 + k * 6), 16 * c.ss, 9 * c.ss, hexc("#2A2628"), outline=1.2, rim=0.3, spec=0.2)
    c.disc(*p(-0.08, 0.02, 20), 3 * c.ss, 2 * c.ss, hexc("#F07A1E"), outline=0.3, spec=1.0)


def rubbing_kit(c):
    """ป้ายเปล่า + ถ่าน = ชุดลอกลาย."""
    p = c.p
    c.box(-0.3, -0.22, 0.3, 0.22, 0, 8, hexc("#2E5E9E"), rim=0.5)
    c.disc(*p(0.14, 0.08, 14), 12 * c.ss, 7 * c.ss, hexc("#2A2628"), outline=1.0, rim=0.3)
    c.text("ลอกลาย", p(-0.26, 0.0, 10), p(0.1, 0.0, 10), 8, PAPER)


def water_marks(c):
    """ลอกลายขีดระดับน้ำ 30 ปีจากเสาหอระฆัง: thirty lines, the same step every year."""
    p = c.p
    c.box(-0.26, -0.34, 0.26, 0.34, 0, 4, PAPER, rim=0.2)
    for k in range(10):
        c.stroke([p(-0.14, 0.28 - k * 0.06, 5), p(0.1, 0.28 - k * 0.06, 5)], 1.6, hexc("#2A2628"), 0.9 if k % 3 else 1.0)
    c.text("2090", p(0.08, 0.0, 9), p(0.26, 0.0, 9), 5, RED)


ITEMS = {f.__name__: f for f in (debt_book, gum, hanger, hook, float_key, air_remote, letter,
                                 sauce_packs, brass_box, broken_crank, tape, crank, memory_chip,
                                 debt_list, reading_glasses, love_letter, megaphone, ring, platu, firecracker, sauce_empty, curler, goldfish, amulet, parking_ticket, survey_form, brochure, son_note, adapter, lottery_ticket, blank_sign, charcoal, rubbing_kit, water_marks)}


def render(name, out):
    c = _canvas(abs(hash(name)) % 1000)
    ITEMS[name](c)
    c.finish(out, sil=2.4)
    im = Image.open(out).convert("RGBA")
    box = im.getbbox()
    im = im.crop(box)
    k = min(1.0, (ICON - 16) / max(im.size))
    im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
    sq = Image.new("RGBA", (ICON, ICON), (0, 0, 0, 0))
    sq.paste(im, ((ICON - im.width) // 2, (ICON - im.height) // 2), im)
    sq.save(out)


if __name__ == "__main__":
    name = sys.argv[1]
    if name == "all":
        out_dir = sys.argv[2]
        os.makedirs(out_dir, exist_ok=True)
        for n in ITEMS:
            render(n, os.path.join(out_dir, n + ".png"))
            print("wrote", n)
    else:
        render(name, sys.argv[2])
        print("wrote", name)
