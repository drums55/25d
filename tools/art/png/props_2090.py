"""Painted PNG props for กรุงเทพฯ 2090 (DESIGN 11): flooded soi, steam salvage.
Run: python3 props_2090.py <name> <out.png>   (or: all <dir>)
Footprints match scripts/world/rooms.gd."""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from paint import *  # noqa: E402,F401,F403

WOOD_L = hexc("#B07A42")
WOOD_D = hexc("#5C3A1E")
INK = hexc("#1E1A1F")
CONCRETE = hexc("#9A9E9A")
CONCRETE_D = hexc("#6E726F")
IRON = hexc("#4A5560")
RUST = hexc("#9A4A26")
WATER = hexc("#3E7F8C")
WATER_L = hexc("#8FD0D6")
WHITE = hexc("#F2EFE6")
RED_P = hexc("#D93A2E")
OLIVE = hexc("#6B7A3A")
JEANS = hexc("#3B5578")


def steam_radio(out):
    """วิทยุไอน้ำรุ่นคุณปู่: wooden cabinet, brass speaker grill, valve, aerial."""
    c = Canvas(260, 400, seed=201)
    p = c.p
    c.ground_shadow(0.6, 0.5)
    c.box(-0.3, -0.25, 0.3, 0.25, 0, 120, WOOD, rim=0.8)
    c.box(-0.32, -0.27, 0.32, 0.27, 120, 128, WOOD_D, rim=0.6)
    c.disc(*p(0.0, 0.252, 70), 34 * c.ss, 34 * c.ss, BRASS, dome=False)
    c.gear(*p(0.0, 0.253, 70), 22 * c.ss, BRASS_D, teeth=10)
    c.cylinder(0.18, -0.05, 0.05, 128, 160, COPPER)
    c.stroke([p(-0.15, -0.1, 128), p(-0.32, -0.25, 300)], 3.0, STEEL)
    c.disc(*p(-0.32, -0.25, 300), 6 * c.ss, 6 * c.ss, RED)
    c.finish(out)


def wardrobe(out):
    """ตู้เสื้อผ้าไม้ บวมน้ำนิดๆ: two doors, one slightly open."""
    c = Canvas(420, 640, seed=202)
    p = c.p
    c.ground_shadow(1.2, 0.6)
    c.box(-0.6, -0.3, 0.6, 0.3, 0, 400, WOOD_L, rim=0.7)
    c.box(-0.62, -0.32, 0.62, 0.32, 400, 414, WOOD_D, rim=0.6)
    c.stroke([p(0.0, 0.301, 20), p(0.0, 0.301, 390)], 3.0, INK, 0.8)
    for x in (-0.08, 0.08):
        c.disc(*p(x, 0.302, 200), 5 * c.ss, 5 * c.ss, BRASS)
    # water line from the last flood
    c.stroke([p(-0.6, 0.301, 60), p(0.6, 0.301, 60)], 4.0, hexc("#4B3A2A"), 0.6)
    c.finish(out)


def floor_gap(out):
    """ร่องพื้นไม้: two loose planks with the canal glinting below."""
    c = Canvas(380, 260, seed=203)
    p = c.p
    c.ground_shadow(1.0, 0.5, opacity=0.15)
    gap = c.mask_poly([p(-0.5, -0.06, 0), p(0.5, -0.06, 0), p(0.5, 0.06, 0), p(-0.5, 0.06, 0)])
    c.paint(gap, c.flat(hexc("#0E1A1F")), outline=1.2)
    c.glaze(c.mask_ellipse(*p(0.1, 0.0, 0), 18 * c.ss, 4 * c.ss), WATER_L, 0.7)
    c.glaze(c.mask_ellipse(*p(0.32, 0.0, 0), 6 * c.ss, 6 * c.ss), hexc("#F2C230"), 0.9)  # the key
    for y0, y1 in ((-0.25, -0.07), (0.07, 0.25)):
        c.box(-0.5, y0, 0.5, y1, 0, 6, WOOD_L, rim=0.5, outline=1.4)
    c.finish(out)


def upturned_boat(out):
    """เรือคว่ำในอู่ — with a pair of legs sticking out (ช่างแดง)."""
    c = Canvas(700, 420, seed=204)
    p = c.p
    c.ground_shadow(2.2, 0.8)
    hull = [(-1.1, 0.0), (-0.8, -0.38), (0.85, -0.38), (1.1, 0.0), (0.85, 0.38), (-0.8, 0.38)]
    c.prism(hull, 0, 70, hexc("#2F6D8C"), top_c=hexc("#3F86A8"), smooth=True)
    keel = [(-1.0, -0.04), (1.0, -0.04), (1.0, 0.04), (-1.0, 0.04)]
    c.prism(keel, 70, 84, hexc("#E8E2D0"))
    c.stroke([p(-0.8, 0.38, 30), p(0.85, 0.38, 30)], 4.0, RED_P)
    # legs out from under the hull
    for k, dx in enumerate((0.0, 0.14)):
        c.box(0.55 + dx, 0.38, 0.65 + dx, 0.85, 0, 18, JEANS, rim=0.4, outline=1.6)
        c.box(0.55 + dx, 0.82, 0.67 + dx, 0.92, 0, 26, INK, rim=0.3, outline=1.4)
    c.finish(out)


def sluice_gate(out):
    """ประตูระบายน้ำเก่า (น้ำลง): concrete frame, rusty iron door, crank socket."""
    c = Canvas(640, 700, seed=205)
    p = c.p
    c.ground_shadow(2.0, 0.6)
    c.box(-1.0, -0.3, -0.75, 0.3, 0, 420, CONCRETE, rim=0.6)
    c.box(0.75, -0.3, 1.0, 0.3, 0, 420, CONCRETE, rim=0.6)
    c.box(-1.0, -0.3, 1.0, 0.3, 420, 470, CONCRETE_D, rim=0.6)
    c.box(-0.75, -0.12, 0.75, 0.12, 0, 380, IRON, rim=0.5)
    for z in (80, 180, 280):
        c.stroke([p(-0.74, 0.121, z), p(0.74, 0.121, z)], 3.0, RUST, 0.8)
    c.rivets([p(x, 0.122, z) for x in (-0.6, -0.2, 0.2, 0.6) for z in (40, 340)])
    c.disc(*p(0.0, 0.123, 220), 30 * c.ss, 30 * c.ss, BRASS_D, dome=False)
    c.disc(*p(0.0, 0.124, 220), 12 * c.ss, 12 * c.ss, SOOT, dome=False)  # crank socket
    c.text("สถานีสูบน้ำ ๐", p(-0.7, 0.301, 455), p(0.7, 0.301, 455), 26, WHITE)
    # wet line: it spends half the day underwater
    c.glaze(c.mask_poly([p(-1.0, 0.3, 0), p(1.0, 0.3, 0), p(1.0, 0.3, 150), p(-1.0, 0.3, 150)]),
            hexc("#2E4A3A"), 0.35)
    c.finish(out)


def sluice_flooded(out):
    """ประตูระบายน้ำตอนน้ำขึ้น: only the top beam above brown water."""
    c = Canvas(640, 420, seed=206)
    p = c.p
    water = c.mask_ellipse(*p(0, 0, 0), 300 * c.ss, 90 * c.ss)
    c.paint(water, c.grad(WATER, k_top=1.2, k_bot=0.8), outline=1.0, tex=0.12)
    for k in range(5):
        x = -0.8 + k * 0.4
        c.stroke([p(x, 0.2, 2), p(x + 0.25, 0.2, 2)], 3.0, WATER_L, 0.7)
    c.box(-1.0, -0.3, 1.0, 0.3, 120, 170, CONCRETE_D, rim=0.6)
    c.box(-1.0, -0.3, -0.75, 0.3, 0, 120, CONCRETE, rim=0.6)
    c.box(0.75, -0.3, 1.0, 0.3, 0, 120, CONCRETE, rim=0.6)
    c.text("สถานีสูบน้ำ ๐", p(-0.7, 0.301, 155), p(0.7, 0.301, 155), 26, WHITE)
    c.finish(out)


def tide_gauge(out):
    """เสาวัดระดับน้ำ: red/white bands, the top marks are new."""
    c = Canvas(200, 620, seed=207)
    p = c.p
    c.ground_shadow(0.3, 0.3)
    for k in range(10):
        col = RED_P if k % 2 else WHITE
        c.box(-0.08, -0.08, 0.08, 0.08, k * 40, k * 40 + 40, col, rim=0.4, outline=1.4)
    c.text("2090", p(-0.08, 0.081, 380), p(0.08, 0.081, 380), 12, INK)
    c.finish(out)


def wait_bench(out):
    """ม้านั่งไม้ริมคลอง: for waiting out the tide."""
    c = Canvas(420, 300, seed=208)
    p = c.p
    c.ground_shadow(1.2, 0.4)
    for x in (-0.45, 0.45):
        c.box(x - 0.05, -0.15, x + 0.05, 0.15, 0, 40, WOOD_D, rim=0.4)
    c.box(-0.6, -0.2, 0.6, 0.2, 40, 52, WOOD_L, rim=0.7)
    c.box(-0.6, -0.22, 0.6, -0.16, 52, 110, WOOD_L, rim=0.6)
    c.finish(out)


def house_zero_plate(out):
    """ป้ายทองเหลือง "บ้านเลขที่ 0" on the station's inner door."""
    c = Canvas(260, 520, seed=209)
    p = c.p
    c.ground_shadow(0.5, 0.3)
    c.box(-0.04, -0.04, 0.04, 0.04, 0, 220, IRON, rim=0.5)
    c.box(-0.25, -0.05, 0.25, 0.05, 220, 330, BRASS, rim=0.9)
    c.text("บ้านเลขที่", p(-0.2, 0.051, 300), p(0.2, 0.051, 300), 18, BRASS_D)
    c.text("0", p(-0.1, 0.052, 270), p(0.1, 0.052, 270), 44, BRASS_D)
    c.finish(out)


def pump_engine(out):
    """เครื่องสูบน้ำเก่าใต้ซอย: big flywheel, pipes, dead gauges."""
    c = Canvas(640, 680, seed=210)
    p = c.p
    c.ground_shadow(1.8, 1.0)
    c.box(-0.8, -0.45, 0.8, 0.45, 0, 60, CONCRETE_D, rim=0.5)
    c.cylinder(-0.25, 0.0, 0.42, 60, 300, IRON)
    c.band(-0.25, 0.0, 0.43, 150, 170, BRASS)
    c.band(-0.25, 0.0, 0.43, 250, 270, BRASS)
    c.wheel(0.55, 0.1, 200, 0.35, 140, axis="y")
    c.pipe([p(-0.25, 0.0, 300), p(-0.25, 0.0, 420), p(0.6, -0.3, 420)], 22, COPPER)
    c.gauge(*p(-0.25, 0.42, 220), 26 * c.ss, angle=-120)
    c.finish(out)


def rental_bed(out):
    """ที่นอนห้องเช่า: low wooden platform, kapok mattress, rubber-duck blanket."""
    c = Canvas(520, 380, seed=211)
    p = c.p
    c.ground_shadow(1.6, 0.8)
    c.box(-0.8, -0.4, 0.8, 0.4, 0, 22, WOOD_D, rim=0.5)
    c.box(-0.76, -0.36, 0.76, 0.36, 22, 50, hexc("#E9E2D2"), rim=0.7)
    c.box(-0.74, -0.34, -0.42, 0.34, 50, 70, WHITE, rim=0.8)  # pillow
    blanket = c.mask_poly([p(-0.3, -0.37, 52), p(0.78, -0.37, 52), p(0.78, 0.37, 50), p(-0.3, 0.37, 50)])
    c.paint(blanket, c.grad(hexc("#F2C230")), outline=1.6, rim=0.5)
    c.box(-0.3, 0.36, 0.78, 0.38, 22, 52, hexc("#E0B020"), rim=0.3, outline=1.4)
    for gx in (0.0, 0.35, 0.65):
        x, y = p(gx, 0.0, 53)
        c.disc(x, y, 10 * c.ss, 6 * c.ss, hexc("#F07A1E"), outline=1.0, dome=False)
    c.finish(out)


def debt_board(out):
    """กระดานหนี้ติดผนัง: cork board on two legs, notes, red figures."""
    c = Canvas(300, 520, seed=212)
    p = c.p
    c.ground_shadow(0.5, 0.3)
    for x in (-0.2, 0.2):
        c.box(x - 0.02, -0.02, x + 0.02, 0.02, 0, 160, WOOD_D, rim=0.3, outline=1.4)
    c.box(-0.25, -0.05, 0.25, 0.05, 140, 300, hexc("#B88A5A"), rim=0.7)
    c.box(-0.21, 0.05, 0.21, 0.06, 150, 290, hexc("#C9A06A"), rim=0.2, outline=1.0)
    c.text("หนี้", p(-0.18, 0.061, 280), p(0.18, 0.061, 280), 18, RED_P)
    c.text("30,000", p(-0.18, 0.061, 245), p(0.18, 0.061, 245), 16, RED_P)
    c.box(0.04, 0.06, 0.18, 0.065, 160, 210, hexc("#FFF4A0"), rim=0.1, outline=1.0)  # sticky note
    c.box(-0.18, 0.06, -0.04, 0.065, 170, 215, hexc("#A0E0FF"), rim=0.1, outline=1.0)
    c.finish(out)


def boat_noodle_stall(out):
    """แผงก๋วยเตี๋ยวเรือ: big brass pot on a wooden stand, bowls, chilli jars."""
    c = Canvas(520, 520, seed=213)
    p = c.p
    c.ground_shadow(1.6, 0.9)
    c.box(-0.8, -0.45, 0.8, 0.45, 0, 80, WOOD_L, rim=0.6)
    c.box(-0.82, -0.47, 0.82, 0.47, 80, 88, WOOD_D, rim=0.5)
    _, _, (tx, ty, rx, ry, _bx, _by) = c.cylinder(-0.3, 0.0, 0.32, 88, 190, BRASS, spec=0.9)
    c.disc(tx, ty, rx * 0.86, ry * 0.86, hexc("#6B3A1E"), outline=1.2, dome=False)  # the broth
    for k in range(3):
        c.stroke([(tx - 30 * c.ss + k * 30 * c.ss, ty - 20 * c.ss), (tx - 20 * c.ss + k * 30 * c.ss, ty - 70 * c.ss)],
                 6.0, hexc("#F2EFE6"), 0.35)  # steam
    for k in range(3):
        x, y = p(0.35, -0.25 + k * 0.22, 88)
        c.disc(x, y, 22 * c.ss, 11 * c.ss, WHITE, dome=False)
        c.disc(x, y, 15 * c.ss, 7 * c.ss, hexc("#3E7F8C"), outline=0.8, dome=False)
    for k, col in enumerate((RED_P, hexc("#F2C230"), OLIVE)):
        c.cylinder(0.7, -0.3 + k * 0.2, 0.05, 88, 118, col, spec=0.8)
    c.text("ก๋วยเตี๋ยวเรือ", p(-0.7, 0.451, 60), p(0.7, 0.451, 60), 26, WHITE)
    c.finish(out)


def kiao_desk(out):
    """โต๊ะเจ๊เกียว: red lacquer desk, gold trim, abacus, three calculators."""
    c = Canvas(700, 460, seed=214)
    p = c.p
    c.ground_shadow(2.4, 0.7)
    c.box(-1.2, -0.35, 1.2, 0.35, 0, 90, hexc("#8E2A24"), rim=0.7)
    c.box(-1.22, -0.37, 1.22, 0.37, 90, 100, BRASS, rim=0.8)
    c.text("เงินด่วน ดอกไม่ด่วน", p(-1.0, 0.351, 66), p(1.0, 0.351, 66), 30, BRASS_L)
    for k in range(3):
        c.box(-0.9 + k * 0.3, -0.15, -0.72 + k * 0.3, 0.1, 100, 108, hexc("#2B2629"), rim=0.4, outline=1.4)
    c.box(0.3, -0.2, 0.9, 0.15, 100, 104, WOOD_D, rim=0.3)
    for k in range(5):
        c.stroke([p(0.32, -0.15 + k * 0.07, 106), p(0.88, -0.15 + k * 0.07, 106)], 2.0, BRASS_D, 0.9)
        for j in range(4):
            x, y = p(0.4 + j * 0.13, -0.15 + k * 0.07, 108)
            c.disc(x, y, 4 * c.ss, 3 * c.ss, RED_P, outline=0.6)
    c.finish(out)


PROPS = {f.__name__: f for f in (steam_radio, wardrobe, floor_gap, upturned_boat, sluice_gate,
                                 sluice_flooded, tide_gauge, wait_bench, house_zero_plate,
                                 pump_engine, rental_bed, debt_board, boat_noodle_stall, kiao_desk)}

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
