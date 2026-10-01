"""Painted PNG props, modern Bangkok set (rider game, P1).
Run: python3 props_bkk.py <name> <out.png>   (or: all <dir>)
Footprints match scripts/world/location_templates.gd."""
import math
import os
import sys

import numpy as np
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from paint import *  # noqa: E402,F401,F403

GREEN = hexc("#18A957")
GREEN_D = hexc("#0E6E39")
ORANGE = hexc("#F07A1E")
YELLOW = hexc("#F2C230")
WHITE = hexc("#F2EFE6")
INK = hexc("#1E1A1F")
CHROME = hexc("#C9D1D6")
PLASTIC_RED = hexc("#D93A2E")
PLASTIC_BLUE = hexc("#2F6DB5")
GLASS = hexc("#A9D8E6")
WOOD_L = hexc("#B07A42")
LEAF = hexc("#4F8A3C")
LEAF_D = hexc("#2F5E26")
TERRACOTTA = hexc("#B5603A")
BEIGE = hexc("#D8C9A8")
GREY = hexc("#7D8389")
DARK = hexc("#3A3D42")


def leaves(c, cx, cy, n, r, seed=0, col=LEAF):
    rng = np.random.default_rng(seed)
    s = c.ss
    for k in range(n):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.2, 1.0) * r
        x, y = cx + math.cos(a) * d * s, cy + math.sin(a) * d * 0.6 * s - rng.uniform(0, r) * 0.5 * s
        c.disc(x, y, rng.uniform(8, 14) * s, rng.uniform(5, 9) * s,
               col * rng.uniform(0.8, 1.2), 1.0, 0.4, spec=0.3)


def scooter(c, box=False):
    """Step-through scooter along gx (front wheel at +gx)."""
    p, s = c.p, c.ss
    c.wheel(-0.42, 0.0, 30, 0.12, 30, spokes=False)
    # body: floor board + rear cowl + front apron
    c.prism([(-0.5, -0.12), (0.1, -0.12), (0.1, 0.12), (-0.5, 0.12)], 30, 70, hexc("#D9D9D9"), smooth=True)
    c.prism([(-0.55, -0.13), (-0.15, -0.13), (-0.15, 0.13), (-0.55, 0.13)], 60, 120, PLASTIC_RED * 0.95, smooth=True)
    c.box(-0.5, -0.12, -0.12, 0.12, 120, 132, INK, rim=0.4)  # seat
    c.wheel(0.42, 0.0, 30, 0.12, 30, spokes=False)
    c.prism([(0.18, -0.1), (0.34, -0.1), (0.34, 0.1), (0.18, 0.1)], 40, 150, PLASTIC_RED, smooth=True)
    c.pipe([p(0.3, 0.0, 150), p(0.32, 0.0, 190)], 6, DARK)
    c.pipe([p(0.32, -0.22, 192), p(0.32, 0.22, 192)], 5, DARK)
    hx, hy = p(0.36, 0.0, 170)
    c.disc(hx, hy, 9 * s, 7 * s, hexc("#FFF1B8"), 1.0, 0.6, spec=1.0)
    for gy in (-0.22, 0.22):
        mx, my = p(0.3, gy, 205)
        c.disc(mx, my, 6 * s, 4 * s, CHROME, 1.0, 0.4)
    if box:
        c.box(-0.62, -0.2, -0.22, 0.2, 132, 230, GREEN, rim=0.9, top_k=1.2)
        c.paint(c.mask_poly([p(-0.6, 0.2, 200), p(-0.24, 0.2, 200), p(-0.24, 0.2, 168), p(-0.6, 0.2, 168)]),
                c.flat(WHITE), 0.8, 0)
        c.text("ส่งไว", p(-0.58, 0.201, 198), p(-0.26, 0.201, 198), 28, GREEN_D)
        c.text("5 ดาว", p(-0.21, 0.19, 226), p(-0.21, -0.19, 226), 16, YELLOW)


def rider_bike(out):
    """รถไรเดอร์: red step-through scooter + green delivery box."""
    c = Canvas(440, 500, seed=60)
    c.ground_shadow(1.2, 0.6)
    scooter(c, box=True)
    c.finish(out)


def parked_scooter(out):
    c = Canvas(440, 460, seed=61)
    c.ground_shadow(1.2, 0.6)
    scooter(c, box=False)
    c.finish(out)


def food_counter(out):
    """เคาน์เตอร์ร้านข้าวมันไก่: steel counter + glass cabinet with hanging chickens + menu."""
    c = Canvas(780, 560, seed=62)
    p, s = c.p, c.ss
    c.ground_shadow(2.6, 0.7)
    c.box(-1.3, -0.35, 1.3, 0.35, 0, 90, CHROME, rim=0.9)
    for k in range(5):
        x = -1.2 + k * 0.6
        c.stroke([p(x, 0.351, 85), p(x, 0.351, 8)], 1.0, GREY, 0.5)
    # glass cabinet on the left half: red frame, hanging chickens, glass panes
    c.box(-1.2, -0.3, 0.1, 0.3, 90, 96, PLASTIC_RED, rim=0.6)
    for gx, gy in ((-1.18, -0.28), (0.08, -0.28)):
        c.pipe([p(gx, gy, 96), p(gx, gy, 200)], 4, PLASTIC_RED)
    for k in range(4):
        x = -1.05 + k * 0.32
        c.stroke([p(x, 0.0, 200), p(x, 0.0, 180)], 1.4, CHROME)
        cx, cy = p(x, 0.0, 164)
        c.disc(cx, cy, 20 * s, 15 * s, hexc("#E9C27A"), 1.4, 0.5, spec=0.7)
    front = c.mask_poly([p(-1.2, 0.3, 96), p(0.1, 0.3, 96), p(0.1, 0.3, 200), p(-1.2, 0.3, 200)])
    side = c.mask_poly([p(0.1, 0.3, 96), p(0.1, -0.3, 96), p(0.1, -0.3, 200), p(0.1, 0.3, 200)])
    for m in (front, side):
        c.glaze(m, GLASS, 0.22)
        c.ink_ring(m, 1.2)
    c.stroke([p(-0.9, 0.301, 190), p(-0.5, 0.301, 120)], 4.0, WHITE, 0.25)
    for gx, gy in ((-1.18, 0.28), (0.08, 0.28)):
        c.pipe([p(gx, gy, 96), p(gx, gy, 200)], 4, PLASTIC_RED)
    c.box(-1.22, -0.32, 0.12, 0.32, 200, 236, PLASTIC_RED, rim=0.7)
    c.text("ข้าวมันไก่ 50.-", p(-1.16, 0.321, 232), p(0.06, 0.321, 232), 28, WHITE)
    # pot + chopping board + sauce bottles on the right
    c.cylinder(0.65, -0.05, 0.2, 90, 150, CHROME * 0.9, spec=0.9)
    c.box(0.3, 0.05, 0.6, 0.3, 90, 96, WOOD_L, rim=0.4)
    for k, col in enumerate((PLASTIC_RED, YELLOW, hexc("#6B3F1D"))):
        c.cylinder(1.0 + k * 0.08, 0.15, 0.03, 90, 130, col, spec=0.6)
    c.finish(out)


def steel_table(out):
    """โต๊ะสแตนเลส + เก้าอี้พลาสติกแดง + ชุดเครื่องปรุง."""
    c = Canvas(380, 420, seed=63)
    p, s = c.p, c.ss
    c.ground_shadow(1.0, 1.0)
    for gx, gy in ((-0.62, 0.0), (0.0, -0.62)):
        stool(c, gx, gy)
    for gx, gy in ((-0.36, -0.36), (0.36, -0.36), (-0.36, 0.36), (0.36, 0.36)):
        c.pipe([p(gx, gy, 0), p(gx, gy, 70)], 4, CHROME * 0.8)
    c.box(-0.42, -0.42, 0.42, 0.42, 70, 76, CHROME, rim=1.0, top_k=1.25)
    for k, col in enumerate((hexc("#E6D9B0"), PLASTIC_RED, hexc("#6B3F1D"), YELLOW)):
        c.cylinder(-0.12 + k * 0.08, 0.0, 0.03, 76, 100, col, spec=0.5)
    tx, ty = p(0.2, 0.2, 80)
    c.disc(tx, ty, 16 * s, 8 * s, WHITE, 1.0, 0.4, dome=False)
    for gx, gy in ((0.62, 0.0), (0.0, 0.62)):
        stool(c, gx, gy)
    c.finish(out)


def stool(c, gx, gy, col=PLASTIC_RED):
    """เก้าอี้พลาสติกแดง: round seat on a flared body with a hand hole."""
    c.cylinder(gx, gy, 0.13, 0, 44, col * 0.92, spec=0.4)
    c.cylinder(gx, gy, 0.15, 44, 50, col, spec=0.6)
    hx, hy = c.p(gx, gy + 0.12, 26)
    c.disc(hx, hy, 6 * c.ss, 8 * c.ss, col * 0.45, 0.6, 0, dome=False)


def red_stool(out):
    c = Canvas(160, 260, seed=64)
    c.ground_shadow(0.4, 0.4)
    stool(c, 0, 0)
    c.finish(out)


def market_stall(out):
    """แผงตลาด: trestle table, baskets of veg/fruit, orange umbrella."""
    c = Canvas(540, 660, seed=65)
    p, s = c.p, c.ss
    c.ground_shadow(1.6, 0.9)
    for gx, gy in ((-0.7, -0.38), (0.7, -0.38), (-0.7, 0.38), (0.7, 0.38)):
        c.pipe([p(gx, gy, 0), p(gx, gy, 70)], 4, GREY)
    c.box(-0.78, -0.44, 0.78, 0.44, 70, 78, WOOD_L, rim=0.7)
    rng = np.random.default_rng(3)
    cols = [hexc("#F2A93B"), LEAF, hexc("#D63A2F"), hexc("#E8D35A"), hexc("#7A3E8E")]
    for i in range(3):
        for j in range(2):
            gx, gy = -0.5 + i * 0.5, -0.2 + j * 0.4
            c.cylinder(gx, gy, 0.17, 78, 96, hexc("#C9A46A"), spec=0.1)
            col = cols[(i + j * 3) % len(cols)]
            for k in range(9):
                x, y = p(gx + rng.uniform(-0.1, 0.1), gy + rng.uniform(-0.1, 0.1), 100)
                c.disc(x, y, 9 * s, 7 * s, col * rng.uniform(0.85, 1.15), 1.0, 0.4, spec=0.6)
    c.pipe([p(0.0, 0.0, 78), p(0.0, 0.0, 300)], 5, GREY)
    canopy = [p(math.cos(t) * 1.0, math.sin(t) * 1.0, 290) for t in np.linspace(0, 2 * math.pi, 40)]
    m = c.mask_poly(canopy)
    c.paint(m, c.grad(ORANGE, 1.2, 0.85), 2.0, 0.8)
    for t in np.linspace(0, 2 * math.pi, 8, endpoint=False):
        c.stroke([p(0, 0, 330), p(math.cos(t) * 1.0, math.sin(t) * 1.0, 290)], 1.4, ORANGE * 0.7, 0.8)
    top = c.mask_poly([p(math.cos(t) * 0.5, math.sin(t) * 0.5, 315) for t in np.linspace(0, 2 * math.pi, 30)])
    c.glaze(top, WHITE, 0.15)
    c.finish(out)


def fruit_crates(out):
    """ลังพลาสติกซ้อน + มะม่วง."""
    c = Canvas(300, 380, seed=66)
    p, s = c.p, c.ss
    c.ground_shadow(0.9, 0.9)
    c.box(-0.4, -0.4, 0.4, 0.4, 0, 60, PLASTIC_BLUE, rim=0.6)
    c.box(-0.38, -0.38, 0.38, 0.38, 60, 120, YELLOW * 0.95, rim=0.6)
    rng = np.random.default_rng(4)
    for k in range(14):
        x, y = p(rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 124)
        c.disc(x, y, 12 * s, 8 * s, hexc("#F2B33A") * rng.uniform(0.9, 1.1), 1.0, 0.5, spec=0.7)
    for z in (20, 80):
        c.stroke([p(-0.4, 0.401, z), p(0.4, 0.401, z)], 2.0, INK, 0.3)
    c.finish(out)


def house_gate(out):
    """ประตูรั้วบ้าน: sliding iron gate between two pillars + mailbox + bell."""
    c = Canvas(460, 520, seed=67)
    p, s = c.p, c.ss
    c.ground_shadow(1.2, 0.6)
    for gx in (-0.6, 0.6):
        c.box(gx - 0.08, -0.08, gx + 0.08, 0.08, 0, 210, BEIGE, rim=0.6)
        c.box(gx - 0.1, -0.1, gx + 0.1, 0.1, 210, 222, BEIGE * 0.9, rim=0.6)
    c.stroke([p(-0.52, 0.0, 10), p(0.52, 0.0, 10)], 3.0, DARK)
    c.stroke([p(-0.52, 0.0, 180), p(0.52, 0.0, 180)], 3.0, DARK)
    for k in range(13):
        x = -0.5 + k * (1.0 / 12)
        c.stroke([p(x, 0.0, 10), p(x, 0.0, 190)], 2.0, DARK)
        tx, ty = p(x, 0.0, 192)
        c.disc(tx, ty - 3 * s, 3 * s, 4 * s, BRASS, 0.8, 0.3)
    c.box(0.5, 0.08, 0.66, 0.18, 120, 160, PLASTIC_RED, rim=0.5)   # mailbox
    c.text("ตะโกนเอา", p(0.6, 0.081, 112), p(0.6, -0.081, 112), 9, INK)
    bx, by = p(-0.6, 0.09, 140)
    c.disc(bx, by, 6 * s, 6 * s, WHITE, 1.0, 0.3)
    c.finish(out)


def plant_pots(out):
    """กระถางต้นไม้หน้าบ้าน: dragon-pattern pot + plastic pots + plants."""
    c = Canvas(260, 360, seed=68)
    p, s = c.p, c.ss
    c.ground_shadow(0.6, 0.6)
    c.cylinder(-0.12, -0.05, 0.14, 0, 60, TERRACOTTA, spec=0.3)
    cx, cy = p(-0.12, -0.05, 80)
    leaves(c, cx, cy, 16, 34, 1)
    c.cylinder(0.14, 0.12, 0.1, 0, 40, hexc("#2E6FB0"), spec=0.5)
    cx, cy = p(0.14, 0.12, 60)
    leaves(c, cx, cy, 10, 22, 2, LEAF_D)
    c.finish(out)


def guard_desk(out):
    """โต๊ะ รปภ.: podium desk, logbook, walkie-talkie, cap, sign."""
    c = Canvas(540, 460, seed=69)
    p, s = c.p, c.ss
    c.ground_shadow(1.6, 0.7)
    c.box(-0.8, -0.35, 0.8, 0.35, 0, 100, hexc("#4A4E57"), rim=0.7)
    c.box(-0.82, -0.37, 0.82, 0.37, 100, 108, WOOD_L, rim=0.8, top_k=1.2)
    c.paint(c.mask_poly([p(-0.6, 0.351, 90), p(0.3, 0.351, 90), p(0.3, 0.351, 60), p(-0.6, 0.351, 60)]),
            c.flat(WHITE), 0.8, 0)
    c.text("ติดต่อ รปภ.", p(-0.58, 0.352, 88), p(0.28, 0.352, 88), 26, INK)
    bx, by = p(-0.3, 0.0, 110)
    c.disc(bx, by, 34 * s, 16 * s, WHITE, 1.0, 0.3, dome=False)
    c.stroke([(bx - 30 * s, by), (bx + 30 * s, by)], 1.0, PLASTIC_BLUE, 0.6)
    c.box(0.3, -0.05, 0.4, 0.05, 108, 150, INK, rim=0.4)   # walkie talkie
    c.pipe([p(0.35, 0.0, 150), p(0.35, 0.0, 175)], 3, INK)
    cx, cy = p(0.6, 0.1, 112)
    c.disc(cx, cy, 22 * s, 12 * s, hexc("#2A3A5E"), 1.2, 0.4)
    c.finish(out)


def lift_door(out):
    """ลิฟต์: steel doors in a frame, floor indicator, rider-ban sign."""
    c = Canvas(480, 640, seed=70)
    p, s = c.p, c.ss
    c.ground_shadow(1.4, 0.6)
    c.box(-0.7, -0.3, 0.7, 0.3, 0, 300, hexc("#8A8F96"), rim=0.7)
    for x0, x1 in ((-0.5, 0.0), (0.0, 0.5)):
        m = c.mask_poly([p(x0, 0.301, 10), p(x1, 0.301, 10), p(x1, 0.301, 250), p(x0, 0.301, 250)])
        c.paint(m, c.grad(CHROME, 1.25, 0.8), 1.2, 0.5)
    c.stroke([p(0.0, 0.302, 10), p(0.0, 0.302, 250)], 2.0, INK, 0.8)
    c.paint(c.mask_poly([p(-0.2, 0.301, 290), p(0.2, 0.301, 290), p(0.2, 0.301, 266), p(-0.2, 0.301, 266)]),
            c.flat(INK), 0.6, 0)
    c.text("▲ 27", p(-0.18, 0.302, 288), p(0.18, 0.302, 288), 20, hexc("#FF5A3A"))
    c.paint(c.mask_poly([p(0.55, 0.301, 200), p(0.69, 0.301, 200), p(0.69, 0.301, 120), p(0.55, 0.301, 120)]),
            c.flat(YELLOW), 0.8, 0)
    c.text("ไรเดอร์", p(0.56, 0.302, 196), p(0.68, 0.302, 196), 14, INK)
    c.text("ห้ามใช้", p(0.56, 0.302, 170), p(0.68, 0.302, 170), 14, PLASTIC_RED)
    c.finish(out)


def parcel_shelf(out):
    """ชั้นวางพัสดุ: steel shelf piled with boxes and bags."""
    c = Canvas(320, 500, seed=71)
    p, s = c.p, c.ss
    c.ground_shadow(0.8, 0.8)
    for gx, gy in ((-0.38, -0.38), (0.38, -0.38), (-0.38, 0.38), (0.38, 0.38)):
        c.pipe([p(gx, gy, 0), p(gx, gy, 260)], 4, GREY)
    rng = np.random.default_rng(6)
    for z in (20, 110, 200):
        c.box(-0.4, -0.4, 0.4, 0.4, z - 6, z, CHROME * 0.85, rim=0.5)
        x = -0.32
        while x < 0.25:
            w = rng.uniform(0.15, 0.28)
            h = rng.uniform(30, 70)
            col = hexc("#C79A5E") if rng.random() < 0.7 else hexc("#F2EFE6")
            c.box(x, -0.3, x + w, 0.3, z, z + h, col * rng.uniform(0.9, 1.1), rim=0.5)
            x += w + 0.03
    c.finish(out)


def reception_desk(out):
    """โต๊ะรีเซปชันออฟฟิศ: curved-ish wood desk, logo panel, bell, plant."""
    c = Canvas(720, 480, seed=72)
    p, s = c.p, c.ss
    c.ground_shadow(2.4, 0.7)
    c.box(-1.2, -0.35, 1.2, 0.35, 0, 110, WOOD_L * 0.9, rim=0.7)
    c.box(-1.22, -0.37, 1.22, 0.37, 110, 118, WHITE, rim=0.9, top_k=1.2)
    c.paint(c.mask_poly([p(-0.5, 0.351, 96), p(0.5, 0.351, 96), p(0.5, 0.351, 40), p(-0.5, 0.351, 40)]),
            c.flat(hexc("#24324A")), 0.8, 0)
    c.text("RECEPTION", p(-0.46, 0.352, 86), p(0.46, 0.352, 86), 22, WHITE)
    c.text("ต้อนรับ (ไรเดอร์รอตรงนี้)", p(-0.46, 0.352, 60), p(0.46, 0.352, 60), 12, YELLOW)
    bx, by = p(0.3, 0.0, 120)
    c.disc(bx, by, 9 * s, 6 * s, BRASS_L, 1.0, 0.5)
    c.box(-0.9, -0.15, -0.6, 0.15, 118, 170, DARK, rim=0.4)  # monitor
    c.cylinder(0.9, -0.1, 0.1, 118, 150, WHITE, spec=0.5)
    cx, cy = p(0.9, -0.1, 175)
    leaves(c, cx, cy, 10, 26, 3)
    c.finish(out)


def water_dispenser(out):
    """ตู้กดน้ำ: white cabinet, blue water bottle on top, two taps."""
    c = Canvas(230, 480, seed=73)
    p, s = c.p, c.ss
    c.ground_shadow(0.6, 0.6)
    c.box(-0.22, -0.22, 0.22, 0.22, 0, 200, WHITE, rim=0.8)
    c.cylinder(0, 0, 0.17, 200, 300, hexc("#7FC4E8"), spec=0.9, rim=0.8)
    c.glaze(c.mask_poly([p(-0.1, 0.1, 210), p(0.05, 0.15, 210), p(0.05, 0.15, 290), p(-0.1, 0.1, 290)]), WHITE, 0.25)
    for gx, col in ((-0.08, PLASTIC_BLUE), (0.08, PLASTIC_RED)):
        tx, ty = p(gx, 0.221, 150)
        c.disc(tx, ty, 6 * s, 6 * s, col, 1.0, 0.4)
    c.text("น้ำดื่ม", p(-0.2, 0.221, 120), p(0.2, 0.221, 120), 16, PLASTIC_BLUE)
    c.finish(out)


def sofa(out):
    """โซฟาล็อบบี้: grey-blue two-seater with a sign 'สำหรับผู้พักอาศัย'."""
    c = Canvas(540, 400, seed=74)
    p, s = c.p, c.ss
    c.ground_shadow(1.6, 0.8)
    col = hexc("#4C5E80")
    c.box(-0.8, -0.4, 0.8, 0.4, 0, 45, col, rim=0.6)
    c.box(-0.8, -0.4, 0.8, -0.18, 45, 110, col * 0.95, rim=0.7)
    for gx in (-0.8, 0.62):
        c.box(gx, -0.4, gx + 0.18, 0.4, 45, 80, col * 1.05, rim=0.7)
    for gx in (-0.6, 0.0):
        c.box(gx, -0.18, gx + 0.58, 0.36, 45, 60, col * 1.15, rim=0.8)
    c.paint(c.mask_poly([p(-0.1, -0.18, 104), p(0.3, -0.18, 104), p(0.3, -0.18, 84), p(-0.1, -0.18, 84)]),
            c.flat(WHITE), 0.6, 0)
    c.text("ผู้พักอาศัย", p(-0.08, -0.179, 102), p(0.28, -0.179, 102), 14, INK)
    c.finish(out)


def fuel_pump(out, col=PLASTIC_RED, label="ดีเซล"):
    """หัวจ่ายน้ำมัน: cabinet with price display, hose and nozzle."""
    c = Canvas(250, 540, seed=75)
    p, s = c.p, c.ss
    c.ground_shadow(0.6, 0.6)
    c.box(-0.3, -0.3, 0.3, 0.3, 0, 14, GREY, rim=0.4)
    c.box(-0.22, -0.22, 0.22, 0.22, 14, 250, WHITE, rim=0.8)
    c.box(-0.23, -0.23, 0.23, 0.23, 250, 290, col, rim=0.8)
    c.paint(c.mask_poly([p(-0.18, 0.221, 230), p(0.18, 0.221, 230), p(0.18, 0.221, 170), p(-0.18, 0.221, 170)]),
            c.flat(INK), 0.6, 0)
    c.text("38.50", p(-0.16, 0.222, 224), p(0.16, 0.222, 224), 18, hexc("#7CFF8A"))
    c.text(label, p(-0.16, 0.222, 196), p(0.16, 0.222, 196), 14, hexc("#7CFF8A"))
    c.pipe([p(0.22, 0.1, 150), p(0.32, 0.18, 90), p(0.26, 0.24, 40), p(0.22, 0.22, 120)], 4, INK)
    nx, ny = p(0.23, 0.2, 130)
    c.disc(nx, ny, 8 * s, 5 * s, col, 1.0, 0.4)
    c.finish(out)


def fuel_pump_green(out):
    fuel_pump(out, GREEN, "แก๊สโซฮอล์ 95")


def tire_stack(out):
    """กองยางร้านซ่อม."""
    c = Canvas(260, 400, seed=76)
    p, s = c.p, c.ss
    c.ground_shadow(0.6, 0.6)
    for k in range(4):
        c.cylinder(0.02 * (k % 2), 0.0, 0.24, k * 34, k * 34 + 30, SOOT * 1.4, spec=0.3, top_c=SOOT * 1.1)
        tx, ty = p(0.02 * (k % 2), 0.0, k * 34 + 30)
        c.disc(tx, ty, 26 * s, 13 * s, SOOT * 0.6, 0.6, 0, dome=False)
    c.text("ปะยาง", p(-0.22, 0.24, 166), p(0.22, 0.24, 166), 18, YELLOW)
    c.finish(out)


def trash_bin(out):
    """ถังขยะ กทม.: green wheelie bin."""
    c = Canvas(200, 340, seed=77)
    p, s = c.p, c.ss
    c.ground_shadow(0.5, 0.5)
    c.frustum(0.2, 0.22, 0, 130, GREEN, cx=0, cy=0)
    c.box(-0.24, -0.24, 0.24, 0.24, 130, 140, GREEN_D, rim=0.6)
    c.text("ขยะทั่วไป", p(-0.18, 0.221, 100), p(0.18, 0.221, 100), 14, WHITE)
    c.finish(out)


def tool_bench(out):
    """โต๊ะเครื่องมืออู่: steel bench, vice, wrenches on a pegboard."""
    c = Canvas(500, 520, seed=78)
    p, s = c.p, c.ss
    c.ground_shadow(1.5, 1.0)
    c.box(-0.75, -0.5, 0.75, 0.5, 0, 90, hexc("#5A6068"), rim=0.6)
    c.box(-0.77, -0.52, 0.77, 0.52, 90, 98, WOOD_L, rim=0.8)
    c.box(-0.75, -0.5, 0.75, -0.44, 98, 260, hexc("#C9B48A"), rim=0.5)
    for k in range(6):
        x = -0.6 + k * 0.22
        c.stroke([p(x, -0.43, 240), p(x, -0.43, 170 - (k % 3) * 15)], 3.0, CHROME)
    c.box(0.3, -0.1, 0.5, 0.1, 98, 130, hexc("#2F6DB5"), rim=0.6)  # vice
    c.box(-0.4, 0.0, -0.1, 0.25, 98, 120, PLASTIC_RED, rim=0.6)   # toolbox
    c.finish(out)


def minimart(out):
    """ร้านสะดวกซื้อ (ไม่ใช่แบรนด์จริง): shop front wall piece with stripes + glass door."""
    c = Canvas(720, 640, seed=79)
    p, s = c.p, c.ss
    c.ground_shadow(2.4, 0.5)
    c.box(-1.2, -0.25, 1.2, 0.25, 0, 300, WHITE, rim=0.6)
    for z, col in ((300, GREEN), (284, ORANGE), (268, PLASTIC_RED)):
        c.box(-1.21, -0.26, 1.21, 0.26, z - 16, z, col, rim=0.6)
    c.text("ร้านสะดวกซื้อ 24 ชม.", p(-1.0, 0.261, 330), p(1.0, 0.261, 330), 30, GREEN_D)
    glass = c.mask_poly([p(-0.9, 0.251, 10), p(0.9, 0.251, 10), p(0.9, 0.251, 240), p(-0.9, 0.251, 240)])
    c.glaze(glass, GLASS, 0.5)
    c.ink_ring(glass, 1.4)
    c.stroke([p(0.0, 0.252, 10), p(0.0, 0.252, 240)], 2.0, INK, 0.8)
    c.text("ไรเดอร์รับของจุดนี้", p(-0.8, 0.252, 200), p(-0.1, 0.252, 200), 14, PLASTIC_RED)
    c.finish(out)


PROPS = {f.__name__: f for f in (rider_bike, parked_scooter, food_counter, steel_table, red_stool,
                                 market_stall, fruit_crates, house_gate, plant_pots, guard_desk,
                                 lift_door, parcel_shelf, reception_desk, water_dispenser, sofa,
                                 fuel_pump, fuel_pump_green, tire_stack, trash_bin, tool_bench, minimart)}

if __name__ == "__main__":
    name = sys.argv[1]
    if name == "all":
        out_dir = sys.argv[2]
        for n, f in PROPS.items():
            f(os.path.join(out_dir, n + ".png"))
            print("wrote", n)
    else:
        PROPS[name](sys.argv[2])
        print("wrote", name)
