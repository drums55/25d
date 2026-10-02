"""Props for the chapter-2 stretch (DESIGN 12.7): the company's guard post on the
sea wall, the third-floor condo, พี่เบิ้ม's livestream boat, น้องบอย's signs.
Run: python3 props_b2.py <name> <out.png>   (or: all <dir>)"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from paint import *  # noqa: E402,F401,F403
from props_2090 import CONCRETE, CONCRETE_D, INK, IRON, JEANS, RED_P, RUST, WATER, WATER_L, WHITE, WOOD_D, WOOD_L  # noqa: E402
from props_b1 import GLASS, GOV_BLUE, ORANGE, PAPER, YELLOW, ZINC  # noqa: E402

COMPANY = hexc("#2E5E9E")
COMPANY_L = hexc("#7FB0E8")
LED = hexc("#4AE0C8")


# --- ป้อมยามกำแพงกันทะเล -------------------------------------------------------------
def guard_booth(out):
    """ตู้ยามของบริษัท: glass box with a counter window, a lamp, the logo."""
    c = Canvas(400, 560, seed=401)
    p = c.p
    c.ground_shadow(1.2, 1.0)
    c.box(-0.6, -0.5, 0.6, 0.5, 0, 120, CONCRETE, rim=0.6)
    c.box(-0.58, -0.48, 0.58, 0.48, 120, 300, COMPANY, rim=0.8)
    # window on the front-left face (+gy): glass + the counter slot
    win = c.mask_poly([p(-0.45, 0.482, 280), p(0.1, 0.482, 280), p(0.1, 0.482, 170), p(-0.45, 0.482, 170)])
    c.paint(win, c.grad(GLASS, 1.1, 0.85), outline=1.6, tex=0.0)
    c.glaze(c.mask_poly([p(-0.4, 0.484, 270), p(-0.15, 0.484, 270), p(-0.3, 0.484, 180), p(-0.45, 0.484, 180)]), WHITE, 0.3)
    c.box(-0.5, 0.48, 0.15, 0.56, 160, 172, CONCRETE, rim=0.5, outline=1.4)
    c.text("ติดต่อ", p(-0.44, 0.483, 164), p(0.06, 0.483, 164), 9, WHITE)
    c.box(-0.62, -0.52, 0.62, 0.52, 300, 320, hexc("#1E3A6E"), rim=0.5)
    c.text("บจ.ป้องกันภัย", p(0.16, 0.483, 262), p(0.56, 0.483, 262), 10, WHITE)
    c.text("ขอบคุณที่เป็นแก้มลิง", p(0.14, 0.483, 236), p(0.58, 0.483, 236), 7, COMPANY_L)
    c.cylinder(0.45, -0.3, 0.04, 320, 380, IRON)
    c.disc(*p(0.45, -0.3, 384), 10 * c.ss, 7 * c.ss, hexc("#FFE6A8"), outline=1.0, spec=1.0)
    c.finish(out)


def barrier_arm(out):
    """ไม้กั้นหน้าป้อม: red and white, counterweight, down."""
    c = Canvas(520, 360, seed=402)
    p = c.p
    c.ground_shadow(1.6, 0.5)
    c.box(-0.75, -0.15, -0.55, 0.15, 0, 110, IRON, rim=0.6)
    c.disc(*p(-0.65, 0.0, 110), 16 * c.ss, 9 * c.ss, hexc("#2A2E30"), outline=1.2)
    for k in range(8):
        x0 = -0.55 + k * 0.17
        c.box(x0, -0.03, x0 + 0.17, 0.03, 92, 108, RED_P if k % 2 else WHITE, rim=0.4, outline=1.0)
    c.box(-0.85, -0.05, -0.75, 0.05, 86, 116, IRON, rim=0.5)
    c.disc(*p(0.84, 0.0, 100), 6 * c.ss, 4 * c.ss, RED_P, outline=0.6, spec=1.0)
    c.finish(out)


def survey_kiosk(out):
    """ตู้แบบสอบถามความพึงพอใจ: five big star buttons, the fifth worn smooth."""
    c = Canvas(300, 480, seed=403)
    p = c.p
    c.ground_shadow(0.5, 0.4)
    c.box(-0.08, -0.08, 0.08, 0.08, 0, 150, IRON, rim=0.5)
    c.box(-0.3, -0.06, 0.3, 0.06, 150, 290, WHITE, rim=0.7)
    c.text("พึงพอใจแค่ไหน?", p(-0.27, 0.061, 280), p(0.27, 0.061, 280), 11, COMPANY)
    for k in range(5):
        col = YELLOW if k < 5 else WHITE
        c.disc(*p(-0.22 + k * 0.11, 0.062, 236), 8 * c.ss, 8 * c.ss, col, outline=0.8, spec=0.6)
    c.disc(*p(0.22, 0.063, 236), 6 * c.ss, 6 * c.ss, hexc("#D8C060"), outline=0.4, spec=0.3)
    c.text("กด 5 ดาวรับโบรชัวร์", p(-0.27, 0.061, 200), p(0.27, 0.061, 200), 8, INK)
    c.text("(ปุ่ม 1-4 ไม่ทำงาน)", p(-0.27, 0.061, 182), p(0.27, 0.061, 182), 7, hexc("#8A8A8A"))
    c.finish(out)


def company_atm(out):
    """ตู้ ATM ของบริษัทบนกำแพง: withdrawals in interest only."""
    c = Canvas(300, 520, seed=404)
    p = c.p
    c.ground_shadow(0.6, 0.5)
    c.box(-0.3, -0.25, 0.3, 0.25, 0, 240, hexc("#D8DCE0"), rim=0.8)
    c.box(-0.32, -0.27, 0.32, 0.27, 240, 262, COMPANY, rim=0.5)
    scr = c.mask_poly([p(-0.22, 0.252, 220), p(0.22, 0.252, 220), p(0.22, 0.252, 150), p(-0.22, 0.252, 150)])
    c.paint(scr, c.grad(hexc("#1E3A6E"), 1.0, 0.8), outline=1.4, tex=0.0)
    c.text("ถอนได้เฉพาะ", p(-0.2, 0.253, 212), p(0.2, 0.253, 212), 8, LED)
    c.text("ดอกเบี้ย", p(-0.2, 0.253, 192), p(0.2, 0.253, 192), 11, LED)
    for k in range(3):
        for j in range(4):
            c.box(-0.2 + j * 0.11, 0.25, -0.12 + j * 0.11, 0.26, 128 - k * 16, 138 - k * 16, WHITE, rim=0.2, outline=0.8)
    c.box(-0.2, 0.25, 0.2, 0.27, 60, 72, hexc("#2A2E30"), rim=0.3, outline=1.0)
    c.finish(out)


def brochure_stand(out):
    """แท่นโบรชัวร์ "โครงการพื้นที่รับน้ำชุมชน": blue leaflets with a smiling family."""
    c = Canvas(240, 400, seed=405)
    p = c.p
    c.ground_shadow(0.5, 0.4)
    c.box(-0.04, -0.04, 0.04, 0.04, 0, 130, IRON, rim=0.5)
    c.box(-0.26, -0.1, 0.26, 0.1, 130, 150, IRON, rim=0.6)
    for k in range(3):
        c.box(-0.2 + k * 0.14, -0.08, -0.1 + k * 0.14, 0.08, 150, 230 - k * 8, COMPANY_L, rim=0.5, outline=1.2)
        c.disc(*p(-0.15 + k * 0.14, 0.081, 206 - k * 8), 5 * c.ss, 5 * c.ss, YELLOW, outline=0.6)
    c.text("ฟรี", p(-0.2, 0.101, 146), p(0.2, 0.101, 146), 9, WHITE)
    c.finish(out)


# --- คอนโดชั้น 3 ------------------------------------------------------------------
def shelter_sign(out):
    """ป้ายศูนย์พักพิง: arrow pointing down, to the basement."""
    c = Canvas(300, 500, seed=406)
    p = c.p
    c.ground_shadow(0.4, 0.3)
    for x in (-0.14, 0.14):
        c.box(x - 0.02, -0.02, x + 0.02, 0.02, 0, 180, IRON, rim=0.5, outline=1.4)
    c.box(-0.3, -0.03, 0.3, 0.03, 170, 300, hexc("#2E7A4A"), rim=0.8)
    c.text("ศูนย์พักพิง", p(-0.27, 0.031, 290), p(0.27, 0.031, 290), 18, WHITE)
    c.text("ชั้นใต้ดิน", p(-0.27, 0.031, 254), p(0.27, 0.031, 254), 14, WHITE)
    c.stroke([p(0.0, 0.032, 236), p(0.0, 0.032, 196)], 5.0, YELLOW)
    c.stroke([p(-0.08, 0.032, 212), p(0.0, 0.032, 194), p(0.08, 0.032, 212)], 5.0, YELLOW)
    c.finish(out)


def parcel_pile(out):
    """กองพัสดุหน้าห้องคุณหญิง: ordered every day, nobody but the rider arrives."""
    c = Canvas(360, 400, seed=407)
    p = c.p
    c.ground_shadow(1.0, 0.8)
    rng = np.random.default_rng(407)
    for k, (gx, gy, w, d, h) in enumerate(((-0.3, 0.1, 0.4, 0.3, 60), (0.15, 0.15, 0.35, 0.35, 70), (-0.05, -0.2, 0.45, 0.25, 50),
                                            (-0.2, 0.05, 0.3, 0.25, 55), (0.1, -0.05, 0.3, 0.3, 60))):
        z0 = 0 if k < 3 else (60 if k == 3 else 70)
        col = (hexc("#C8A070"), hexc("#B89060"), hexc("#D8B080"))[k % 3]
        c.box(gx - w / 2, gy - d / 2, gx + w / 2, gy + d / 2, z0, z0 + h, col, rim=0.6)
        c.stroke([p(gx - w / 2, gy, z0 + h), p(gx + w / 2, gy, z0 + h)], 2.0, hexc("#8A6A3A"), 0.8)
        c.stroke([p(gx, gy - d / 2, z0 + h), p(gx, gy + d / 2, z0 + h)], 2.0, hexc("#8A6A3A"), 0.8)
    c.box(0.05, 0.25, 0.25, 0.3, 70, 120, ORANGE, rim=0.3, outline=1.0)
    c.text("ส่งไว", p(0.06, 0.301, 112), p(0.24, 0.301, 112), 7, WHITE)
    c.finish(out)


def poodle_float(out):
    """พุดเดิ้ลบนห่วงยาง: the condo's last resident who can still get out."""
    c = Canvas(240, 300, seed=408)
    p = c.p
    c.ground_shadow(0.6, 0.6)
    c.disc(*p(0, 0, 10), 44 * c.ss, 24 * c.ss, hexc("#F08080"), outline=1.6, rim=0.6, spec=0.5)
    c.disc(*p(0, 0, 14), 20 * c.ss, 11 * c.ss, hexc("#3E7F8C"), outline=0.8, dome=False)
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        c.disc(*p(0.22 * math.cos(a), 0.14 * math.sin(a), 12), 7 * c.ss, 4 * c.ss, WHITE, outline=0.6)
    fur = hexc("#F2EEE4")
    c.disc(*p(0.0, 0.0, 40), 22 * c.ss, 18 * c.ss, fur, outline=1.6, rim=0.5)
    c.disc(*p(0.06, 0.0, 70), 16 * c.ss, 16 * c.ss, fur, outline=1.6, rim=0.5)
    c.disc(*p(0.14, 0.0, 78), 7 * c.ss, 7 * c.ss, fur, outline=1.2, rim=0.4)
    c.disc(*p(0.16, 0.0, 74), 3 * c.ss, 3 * c.ss, INK, outline=0.4)
    c.disc(*p(0.08, 0.0, 80), 2 * c.ss, 2 * c.ss, INK, outline=0.3)
    c.torus = None
    c.stroke([p(-0.1, 0.0, 90), p(-0.14, 0.0, 100)], 5.0, fur)
    c.disc(*p(0.06, 0.0, 92), 6 * c.ss, 5 * c.ss, RED_P, outline=0.6)
    c.finish(out)


def condo_window(out):
    """หน้าต่างคอนโดชั้น 3: the sea wall and the dry towers behind it, water below."""
    c = Canvas(400, 520, seed=409)
    p = c.p
    c.ground_shadow(1.0, 0.3)
    c.box(-0.6, -0.04, 0.6, 0.04, 60, 330, hexc("#D8DCE0"), rim=0.6)
    view = c.mask_poly([p(-0.54, 0.041, 318), p(0.54, 0.041, 318), p(0.54, 0.041, 72), p(-0.54, 0.041, 72)])
    c.paint(view, c.grad(hexc("#7A4A6A"), 1.0, 0.9), outline=1.4, tex=0.0)
    low = c.mask_poly([p(-0.54, 0.042, 190), p(0.54, 0.042, 190), p(0.54, 0.042, 72), p(-0.54, 0.042, 72)])
    c.paint(low, c.grad(WATER, 1.0, 0.9), outline=0, tex=0.02)
    wall = c.mask_poly([p(-0.54, 0.043, 210), p(0.54, 0.043, 210), p(0.54, 0.043, 190), p(-0.54, 0.043, 190)])
    c.paint(wall, c.grad(hexc("#50545C"), 1.0, 0.9), outline=0.8, tex=0.02)
    for k, (x0, w, h) in enumerate(((-0.45, 0.12, 80), (-0.25, 0.1, 100), (-0.08, 0.14, 70), (0.14, 0.1, 110), (0.34, 0.14, 90))):
        t = c.mask_poly([p(x0, 0.044, 210), p(x0 + w, 0.044, 210), p(x0 + w, 0.044, 210 + h), p(x0, 0.044, 210 + h)])
        c.paint(t, c.grad(hexc("#5C6A8C"), 1.0, 0.9), outline=0.6, tex=0.0)
    c.stroke([p(0.0, 0.045, 320), p(0.0, 0.045, 72)], 3.0, hexc("#B8BCC0"))
    c.finish(out)


# --- พี่เบิ้ม / น้องบอย ---------------------------------------------------------------
def live_boat(out):
    """เรือไลฟ์สดของพี่เบิ้ม: a longtail with an LED sign, ring light, speakers."""
    c = Canvas(560, 480, seed=410)
    p = c.p
    c.ground_shadow(2.0, 0.8)
    hull = [(-1.0, -0.3), (1.0, -0.3), (1.25, 0.0), (1.0, 0.3), (-1.0, 0.3), (-1.15, 0.0)]
    c.prism(hull, 0, 50, hexc("#1E1C22"), rim=0.7)
    c.prism([(-0.85, -0.2), (0.85, -0.2), (0.85, 0.2), (-0.85, 0.2)], 50, 54, hexc("#3A3238"), rim=0.2, outline=1.2)
    for x in (-0.6, 0.6):
        c.box(x - 0.08, -0.22, x + 0.08, -0.14, 54, 150, hexc("#2A2E30"), rim=0.5)
    c.box(-0.72, -0.24, 0.72, -0.12, 150, 230, hexc("#101014"), rim=0.6)
    c.text("จอมบุญ ช่วยได้ทุกเรื่อง", p(-0.68, -0.119, 218), p(0.68, -0.119, 218), 12, LED)
    c.text("โอนมาที่เบอร์นี้ 08x-xxx-xxxx", p(-0.68, -0.119, 190), p(0.68, -0.119, 190), 8, hexc("#FF6060"))
    c.text("(ยกเว้นเรื่องเงิน)", p(-0.68, -0.119, 168), p(0.68, -0.119, 168), 7, LED)
    c.cylinder(0.3, 0.15, 0.03, 54, 160, STEEL)
    c.disc(*p(0.3, 0.15, 166), 22 * c.ss, 22 * c.ss, hexc("#F8F4EE"), dome=False, outline=1.4)
    c.disc(*p(0.3, 0.15, 166), 12 * c.ss, 12 * c.ss, hexc("#1E1C22"), dome=False, outline=0.6)
    for x in (-0.3, 0.0):
        c.box(x - 0.1, 0.08, x + 0.1, 0.24, 54, 120, hexc("#2B2629"), rim=0.6)
        c.disc(*p(x, 0.242, 90), 10 * c.ss, 10 * c.ss, hexc("#4A4E52"), dome=False, outline=1.0)
    c.finish(out)


def drone(out):
    """โดรนของพี่เบิ้ม ลอยอยู่สูง: four rotors and a red light."""
    c = Canvas(260, 420, seed=411)
    p = c.p
    c.ground_shadow(0.3, 0.3, opacity=0.15)
    z = 220
    c.box(-0.08, -0.08, 0.08, 0.08, z, z + 14, hexc("#2B2629"), rim=0.6)
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        c.stroke([p(0, 0, z + 7), p(sx * 0.2, sy * 0.2, z + 7)], 2.4, hexc("#4A4E52"))
        c.disc(*p(sx * 0.2, sy * 0.2, z + 10), 14 * c.ss, 7 * c.ss, hexc("#B8C0C8"), outline=0.6, dome=False)
    c.disc(*p(0, 0.08, z + 4), 4 * c.ss, 4 * c.ss, RED_P, outline=0.4, spec=1.0)
    c.disc(*p(0.0, 0.0, z - 6), 5 * c.ss, 5 * c.ss, hexc("#1E1C22"), outline=0.6)
    c.finish(out)


def sign_stack(out):
    """ป้ายโครงการกองหนึ่งของน้องบอย: next year's numbers, ready to go."""
    c = Canvas(320, 360, seed=412)
    p = c.p
    c.ground_shadow(0.9, 0.6)
    for k in range(5):
        c.box(-0.4 + k * 0.02, -0.25 + k * 0.01, 0.4 + k * 0.02, 0.25 + k * 0.01, k * 8, k * 8 + 8, GOV_BLUE, rim=0.4, outline=1.0)
    c.box(-0.3, -0.26, 0.3, -0.24, 40, 48, YELLOW, rim=0.2, outline=0.8)
    c.text("ระยะที่ 18", p(-0.3, 0.26, 36), p(0.3, 0.26, 36), 10, YELLOW)
    c.text("19  20  21 ...", p(-0.3, 0.26, 20), p(0.3, 0.26, 20), 8, WHITE)
    c.finish(out)


PROPS = {f.__name__: f for f in (guard_booth, barrier_arm, survey_kiosk, company_atm, brochure_stand, shelter_sign,
                                 parcel_pile, poodle_float, condo_window, live_boat, drone, sign_stack)}

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
