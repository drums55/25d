"""Props for the chapter-1 stretch rooms (DESIGN 12.6): the forecast pavilion,
the rooftop market, the bell-tower temple, the boat rank and the cat's roof.
Run: python3 props_b1.py <name> <out.png>   (or: all <dir>)
Footprints match scripts/world/rooms.gd. Same style as props_2090.py."""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from paint import *  # noqa: E402,F401,F403
from props_2090 import CONCRETE, CONCRETE_D, INK, IRON, JEANS, OLIVE, RED_P, RUST, WATER, WATER_L, WHITE, WOOD_D, WOOD_L  # noqa: E402

GOV_BLUE = hexc("#2E5E9E")
GOV_GREEN = hexc("#2E7A4A")
ORANGE = hexc("#F07A1E")
YELLOW = hexc("#F2C230")
GLASS = hexc("#9ED8E0")
SAFFRON = hexc("#E88A1E")
ZINC = hexc("#A8ACA6")
PAPER = hexc("#EFE6CF")


# --- ศาลาพยากรณ์น้ำ -----------------------------------------------------------------
def forecast_board(out):
    """ป้ายพยากรณ์น้ำประจำวันของลุงหมอน้ำ: whiteboard on an easel, today's call in red."""
    c = Canvas(300, 520, seed=301)
    p = c.p
    c.ground_shadow(0.5, 0.4)
    for x in (-0.18, 0.18):
        c.box(x - 0.015, -0.02, x + 0.015, 0.02, 0, 150, WOOD_D, rim=0.3, outline=1.4)
    c.box(-0.26, -0.03, 0.26, 0.03, 130, 300, WHITE, rim=0.5)
    c.box(-0.27, -0.035, 0.27, 0.035, 296, 308, WOOD, rim=0.3)
    c.text("พยากรณ์น้ำวันนี้", p(-0.22, 0.031, 290), p(0.22, 0.031, 290), 16, INK)
    c.text("น้ำขึ้นแน่นอน", p(-0.22, 0.031, 262), p(0.22, 0.031, 262), 22, RED_P)
    c.text("(ยืนยันแล้ว 3 ครั้ง)", p(-0.22, 0.031, 230), p(0.22, 0.031, 230), 13, INK)
    c.text("ลงชื่อ ลุงหมอน้ำ", p(-0.22, 0.031, 200), p(0.22, 0.031, 200), 11, INK)
    c.stroke([p(-0.2, 0.032, 150), p(0.2, 0.032, 150)], 2.0, RED_P, 0.5)
    c.finish(out)


def goldfish_jar(out):
    """โหลปลาทอง "น้องพยากรณ์": a glass jar on a stand, the fish decides the tide."""
    c = Canvas(240, 400, seed=302)
    p = c.p
    c.ground_shadow(0.5, 0.5)
    c.box(-0.2, -0.2, 0.2, 0.2, 0, 90, WOOD, rim=0.6)
    c.cylinder(0, 0, 0.17, 90, 200, GLASS, spec=0.9, rim=0.3, top_c=WATER_L, outline=1.4, tex=0.0)
    c.glaze(c.mask_ellipse(*p(0, 0, 150), 20 * c.ss, 30 * c.ss), WATER, 0.35)
    c.disc(*p(0.02, 0.0, 150), 13 * c.ss, 8 * c.ss, ORANGE, outline=1.2, rim=0.3)
    c.stroke([p(0.08, 0.0, 150), p(0.14, 0.0, 160), p(0.14, 0.0, 140)], 2.0, ORANGE)
    c.disc(*p(-0.04, 0.0, 154), 2 * c.ss, 2 * c.ss, INK, outline=0.4)
    c.text("น้องพยากรณ์", p(-0.16, 0.201, 60), p(0.16, 0.201, 60), 13, INK)
    c.finish(out)


def transistor_radio(out):
    """วิทยุทรานซิสเตอร์ของลุงหมอน้ำ บนลังผลไม้: picks up one station, the last one."""
    c = Canvas(240, 360, seed=303)
    p = c.p
    c.ground_shadow(0.5, 0.5)
    c.box(-0.22, -0.22, 0.22, 0.22, 0, 70, WOOD_L, rim=0.5)
    c.box(-0.18, -0.08, 0.18, 0.08, 70, 150, hexc("#C8A878"), rim=0.7)
    c.disc(*p(-0.06, 0.081, 112), 20 * c.ss, 20 * c.ss, INK, dome=False, outline=1.2)
    c.disc(*p(0.11, 0.081, 125), 7 * c.ss, 7 * c.ss, WHITE, outline=1.0)
    c.disc(*p(0.11, 0.081, 100), 7 * c.ss, 7 * c.ss, WHITE, outline=1.0)
    c.stroke([p(0.15, -0.05, 150), p(0.3, -0.1, 300)], 2.4, STEEL)
    c.text("ส.ว.ท.", p(-0.17, 0.082, 146), p(0.03, 0.082, 146), 8, INK)
    c.finish(out)


def project_sign(n):
    """ป้ายโครงการแก้น้ำท่วมถาวร ระยะที่ n — one per room, the number climbs."""
    def paint(out):
        c = Canvas(320, 520, seed=310 + n)
        p = c.p
        c.ground_shadow(0.4, 0.3)
        for x in (-0.14, 0.14):
            c.box(x - 0.02, -0.02, x + 0.02, 0.02, 0, 200, IRON, rim=0.5, outline=1.4)
        c.box(-0.3, -0.03, 0.3, 0.03, 190, 320, GOV_BLUE, rim=0.8)
        c.box(-0.3, -0.03, 0.3, 0.03, 300, 320, YELLOW, rim=0.3, outline=1.0)
        c.text("โครงการแก้น้ำท่วมถาวร", p(-0.27, 0.031, 290), p(0.27, 0.031, 290), 15, WHITE)
        c.text("ระยะที่ %d" % n, p(-0.27, 0.031, 258), p(0.27, 0.031, 258), 26, YELLOW)
        c.text("งบประมาณ: ป้ายนี้", p(-0.27, 0.031, 215), p(0.27, 0.031, 215), 11, WHITE)
        c.finish(out)
    return paint


def hearing_notice(out):
    """ป้ายประชาพิจารณ์: paper on a board, held by a lot of tape."""
    c = Canvas(260, 460, seed=320)
    p = c.p
    c.ground_shadow(0.4, 0.3)
    c.box(-0.03, -0.03, 0.03, 0.03, 0, 170, WOOD_D, rim=0.4, outline=1.4)
    c.box(-0.24, -0.03, 0.24, 0.03, 160, 290, WOOD, rim=0.6)
    c.box(-0.2, -0.032, 0.2, 0.032, 170, 282, PAPER, rim=0.2, outline=1.0)
    c.text("ประชาพิจารณ์", p(-0.18, 0.033, 276), p(0.18, 0.033, 276), 14, GOV_BLUE)
    c.text("เรื่อง น้ำในซอย", p(-0.18, 0.033, 252), p(0.18, 0.033, 252), 11, INK)
    c.text("10.00 น. บนเรือสำราญ", p(-0.18, 0.033, 232), p(0.18, 0.033, 232), 10, INK)
    c.text("ท่าเรือฝั่งตึก", p(-0.18, 0.033, 214), p(0.18, 0.033, 214), 10, INK)
    c.text("(ตรงกับน้ำขึ้น)", p(-0.18, 0.033, 194), p(0.18, 0.033, 194), 9, RED_P)
    for x, z in ((-0.17, 280), (0.17, 280), (-0.17, 176), (0.17, 176)):
        c.box(x - 0.03, -0.034, x + 0.03, 0.034, z - 6, z + 6, hexc("#D8D0B0"), rim=0.1, outline=0.8)
    c.finish(out)


# --- ตลาดน้ำบนดาดฟ้า --------------------------------------------------------------
def fish_grill(out):
    """เตาย่างปลาทูของลุงปลาทู: clay stove, grill, three fish, smoke."""
    c = Canvas(320, 400, seed=330)
    p = c.p
    c.ground_shadow(0.9, 0.6)
    c.box(-0.4, -0.25, 0.4, 0.25, 0, 70, hexc("#8A4A2A"), rim=0.6)
    c.box(-0.42, -0.27, 0.42, 0.27, 70, 82, IRON, rim=0.4, outline=1.4)
    for k in range(7):
        x = -0.36 + k * 0.12
        c.stroke([p(x, -0.25, 82), p(x, 0.25, 82)], 1.8, IRON)
    for k, x in enumerate((-0.25, 0.0, 0.25)):
        c.disc(*p(x, 0.0, 86), 24 * c.ss, 11 * c.ss, hexc("#B07A42"), outline=1.4, rim=0.5)
        c.disc(*p(x, 0.0, 88), 14 * c.ss, 6 * c.ss, hexc("#D9A066"), outline=0.6, rim=0.2)
        c.stroke([p(x + 0.14, 0.0, 86), p(x + 0.2, 0.0, 92), p(x + 0.2, 0.0, 80)], 2.0, hexc("#B07A42"))
    for k in range(3):
        x = -0.2 + k * 0.2
        c.stroke([p(x, 0, 100), p(x + 0.05, 0, 140), p(x - 0.03, 0, 180)], 4.0, hexc("#D8D8D0"), 0.35)
    c.disc(*p(-0.35, 0.26, 30), 10 * c.ss, 10 * c.ss, RED_P, outline=1.0)  # embers glow
    c.finish(out)


def dry_goods_stall(out):
    """แผงของแห้งเจ๊หมวย: a table of sacks and jars under hanging bags (nothing dry)."""
    c = Canvas(360, 480, seed=331)
    p = c.p
    c.ground_shadow(1.0, 0.7)
    c.box(-0.5, -0.3, 0.5, 0.3, 0, 80, WOOD, rim=0.6)
    for k, (x, col) in enumerate(((-0.32, hexc("#C8B088")), (-0.05, hexc("#B89868")), (0.25, hexc("#D0B890")))):
        c.disc(*p(x, -0.05, 80), 26 * c.ss, 20 * c.ss, col, outline=1.6, rim=0.5)
        c.disc(*p(x, -0.05, 112), 14 * c.ss, 9 * c.ss, col * 0.8, outline=1.0, rim=0.3)
    c.cylinder(0.3, 0.18, 0.08, 80, 130, GLASS, spec=0.9, rim=0.3, top_c=WATER_L, tex=0.0)
    c.cylinder(0.1, 0.2, 0.07, 80, 120, hexc("#C0392B"), spec=0.6)
    for x in (-0.45, 0.45):
        c.box(x - 0.02, -0.3, x + 0.02, -0.26, 80, 300, WOOD_D, rim=0.3, outline=1.2)
    c.stroke([p(-0.45, -0.28, 300), p(0.45, -0.28, 300)], 2.4, WOOD_D)
    for k in range(5):
        x = -0.36 + k * 0.18
        c.box(x - 0.05, -0.29, x + 0.05, -0.27, 230, 290, (YELLOW, RED_P, OLIVE, ORANGE, JEANS)[k], rim=0.3, outline=1.0)
    c.text("ของแห้ง", p(-0.3, 0.301, 60), p(0.3, 0.301, 60), 14, WHITE)
    c.text("(ไม่เคยแห้ง)", p(-0.3, 0.301, 36), p(0.3, 0.301, 36), 9, PAPER)
    c.finish(out)


def lottery_stand(out):
    """แผงลอตเตอรี่ของหุ่น: a red tray stand with the lucky number taped up."""
    c = Canvas(280, 460, seed=332)
    p = c.p
    c.ground_shadow(0.6, 0.4)
    c.box(-0.03, -0.03, 0.03, 0.03, 0, 110, IRON, rim=0.4, outline=1.4)
    c.box(-0.3, -0.2, 0.3, 0.2, 110, 130, RED_P, rim=0.7)
    for k in range(4):
        for j in range(2):
            c.box(-0.27 + k * 0.14, -0.17 + j * 0.2, -0.16 + k * 0.14, -0.02 + j * 0.2, 130, 134, PAPER, rim=0.1, outline=0.8)
    c.box(-0.26, -0.21, 0.26, -0.19, 130, 250, WHITE, rim=0.4)
    c.text("ถูกแน่", p(-0.22, -0.189, 240), p(0.22, -0.189, 240), 16, RED_P)
    c.text("69", p(-0.22, -0.189, 212), p(0.22, -0.189, 212), 30, RED_P)
    c.text("บจ.ป้องกันภัย", p(-0.22, -0.189, 160), p(0.22, -0.189, 160), 9, INK)
    c.finish(out)


def no_parking_sign(out):
    """ป้าย "ห้ามจอดเรือบนดาดฟ้า": red ring on a pole, the usual."""
    c = Canvas(220, 480, seed=333)
    p = c.p
    c.ground_shadow(0.3, 0.3)
    c.box(-0.02, -0.02, 0.02, 0.02, 0, 240, IRON, rim=0.5, outline=1.4)
    c.disc(*p(0, 0.03, 290), 40 * c.ss, 40 * c.ss, WHITE, dome=False, outline=1.8)
    c.disc(*p(0, 0.03, 290), 40 * c.ss, 40 * c.ss, RED_P, dome=False, outline=0)
    c.disc(*p(0, 0.031, 290), 30 * c.ss, 30 * c.ss, WHITE, dome=False, outline=0)
    c.stroke([p(-0.16, 0.032, 262), p(0.16, 0.032, 318)], 7.0, RED_P)
    c.stroke([p(-0.12, 0.032, 282), p(0.12, 0.032, 282)], 3.0, INK)
    c.stroke([p(-0.09, 0.032, 282), p(-0.05, 0.032, 296), p(0.07, 0.032, 296), p(0.12, 0.032, 282)], 2.6, INK)
    c.text("ห้ามจอดเรือบนดาดฟ้า", p(-0.3, 0.03, 236), p(0.3, 0.03, 236), 9, INK)
    c.finish(out)


# --- วัดหอระฆัง -------------------------------------------------------------------
def bell_tower(out):
    """หอระฆังที่เหลือจากวัดจมน้ำ: four posts, a red tiered roof, the bell and its
    rope, and thirty years of water marks on the front post."""
    c = Canvas(520, 760, seed=340)
    p = c.p
    c.ground_shadow(1.2, 1.2)
    c.box(-0.55, -0.55, 0.55, 0.55, 0, 30, CONCRETE, rim=0.6)
    for gx, gy in ((-0.42, -0.42), (0.42, -0.42), (0.42, 0.42), (-0.42, 0.42)):
        c.cylinder(gx, gy, 0.06, 30, 380, hexc("#8A3A2A"), spec=0.4, rim=0.5)
    c.box(-0.5, -0.5, 0.5, 0.5, 380, 400, hexc("#6E2A20"), rim=0.5)
    c.frustum(0.6, 0.3, 400, 470, RED_P, rim=0.8)
    c.frustum(0.36, 0.14, 470, 530, RED_P, rim=0.8)
    c.frustum(0.14, 0.02, 530, 580, hexc("#E2B54A"), rim=0.6)
    c.stroke([p(0, 0, 380), p(0, 0, 300)], 3.0, hexc("#6E4A2A"))
    c.frustum(0.12, 0.2, 230, 300, BRASS, rim=0.9)
    c.disc(*p(0, 0, 230), 26 * c.ss, 10 * c.ss, BRASS_D, outline=1.2, rim=0.3)
    c.stroke([p(0.18, 0.0, 240), p(0.2, 0.0, 120), p(0.16, 0.0, 60)], 2.6, hexc("#C8A070"))
    # water marks: a notch and a year every few lines up the front-left post
    for k in range(9):
        z = 40 + k * 22
        c.stroke([p(-0.48, 0.42, z), p(-0.36, 0.42, z)], 1.6, INK if k % 3 else RED_P, 0.8)
    c.text("2060", p(-0.5, 0.49, 70), p(-0.3, 0.49, 70), 7, INK)
    c.text("2090", p(-0.5, 0.49, 240), p(-0.3, 0.49, 240), 7, RED_P)
    c.finish(out)


def alms_boat(out):
    """เรือบิณฑบาตของหลวงพี่: a small paddle boat with alms bowls."""
    c = Canvas(420, 360, seed=341)
    p = c.p
    c.ground_shadow(1.4, 0.5)
    c.prism([(-0.75, -0.18), (0.75, -0.18), (0.9, 0.0), (0.75, 0.18), (-0.75, 0.18), (-0.9, 0.0)], 0, 36, hexc("#7A5A3A"), rim=0.7)
    c.prism([(-0.65, -0.11), (0.65, -0.11), (0.65, 0.11), (-0.65, 0.11)], 36, 40, hexc("#4A3A2A"), rim=0.2, outline=1.2)
    for x in (-0.4, -0.05, 0.3):
        c.disc(*p(x, 0, 44), 14 * c.ss, 7 * c.ss, IRON, outline=1.2, rim=0.5)
        c.disc(*p(x, 0, 46), 9 * c.ss, 4 * c.ss, hexc("#2A2E30"), outline=0.4)
    c.stroke([p(0.5, 0.12, 40), p(0.3, 0.3, 90)], 3.0, WOOD_D)
    c.box(0.55, -0.1, 0.72, 0.1, 40, 48, SAFFRON, rim=0.3, outline=1.0)
    c.finish(out)


def wetland_sign(out):
    """ป้ายราชการ: วัดนี้ขึ้นทะเบียนเป็นพื้นที่ชุ่มน้ำแล้ว."""
    c = Canvas(320, 500, seed=342)
    p = c.p
    c.ground_shadow(0.4, 0.3)
    for x in (-0.14, 0.14):
        c.box(x - 0.02, -0.02, x + 0.02, 0.02, 0, 180, IRON, rim=0.5, outline=1.4)
    c.box(-0.3, -0.03, 0.3, 0.03, 170, 300, GOV_GREEN, rim=0.8)
    c.text("พื้นที่ชุ่มน้ำ", p(-0.27, 0.031, 290), p(0.27, 0.031, 290), 20, WHITE)
    c.text("ขึ้นทะเบียนแล้ว", p(-0.27, 0.031, 254), p(0.27, 0.031, 254), 14, WHITE)
    c.text("(เดิม: วัด)", p(-0.27, 0.031, 224), p(0.27, 0.031, 224), 11, YELLOW)
    c.text("กรมอะไรสักอย่าง", p(-0.27, 0.031, 196), p(0.27, 0.031, 196), 9, WHITE)
    c.finish(out)


def incense_pot(out):
    """กระถางธูปหน้าหอระฆัง: sand, three sticks, one still going."""
    c = Canvas(220, 320, seed=343)
    p = c.p
    c.ground_shadow(0.5, 0.5)
    c.cylinder(0, 0, 0.2, 0, 60, hexc("#8A4A2A"), spec=0.5, rim=0.6, top_c=hexc("#C8B890"))
    for k, (x, y) in enumerate(((-0.05, 0.02), (0.03, -0.04), (0.06, 0.05))):
        c.stroke([p(x, y, 60), p(x + 0.02, y, 150 + k * 10)], 1.6, hexc("#B03020"))
    c.disc(*p(0.08, 0.05, 162), 2 * c.ss, 2 * c.ss, ORANGE, outline=0.4)
    c.stroke([p(0.08, 0.05, 165), p(0.1, 0.05, 190), p(0.06, 0.05, 220)], 2.6, hexc("#D8D8D0"), 0.3)
    c.finish(out)


# --- วินเรือ ------------------------------------------------------------------------
def rank_sign(out):
    """ป้ายวินเรือ: orange like a motorbike rank's, fares by water level."""
    c = Canvas(320, 520, seed=350)
    p = c.p
    c.ground_shadow(0.4, 0.3)
    for x in (-0.14, 0.14):
        c.box(x - 0.02, -0.02, x + 0.02, 0.02, 0, 190, IRON, rim=0.5, outline=1.4)
    c.box(-0.3, -0.03, 0.3, 0.03, 180, 320, ORANGE, rim=0.8)
    c.text("วินเรือซอยส่งไว", p(-0.27, 0.031, 310), p(0.27, 0.031, 310), 18, INK)
    c.text("ค่าโดยสารตามระดับน้ำ", p(-0.27, 0.031, 278), p(0.27, 0.031, 278), 11, INK)
    c.text("น้ำลง 20 · น้ำขึ้น 40", p(-0.27, 0.031, 254), p(0.27, 0.031, 254), 11, INK)
    c.text("น้ำท่วม: ตามใจพี่", p(-0.27, 0.031, 230), p(0.27, 0.031, 230), 11, RED_P)
    c.text("ห้ามแอป", p(-0.27, 0.031, 206), p(0.27, 0.031, 206), 11, INK)
    c.finish(out)


def vest_rack(out):
    """ราวแขวนเสื้อวินส้ม: three numbered vests, one still wet."""
    c = Canvas(320, 420, seed=351)
    p = c.p
    c.ground_shadow(0.9, 0.3)
    for x in (-0.42, 0.42):
        c.box(x - 0.02, -0.02, x + 0.02, 0.02, 0, 250, IRON, rim=0.5, outline=1.4)
    c.stroke([p(-0.42, 0, 250), p(0.42, 0, 250)], 3.0, IRON)
    for k, x in enumerate((-0.26, 0.0, 0.26)):
        c.box(x - 0.1, -0.03, x + 0.1, 0.03, 130, 240, ORANGE if k != 1 else hexc("#C86A1A"), rim=0.5)
        c.text(str(k + 1), p(x - 0.08, 0.031, 215), p(x + 0.08, 0.031, 215), 18, WHITE)
    c.finish(out)


# --- หลังคาแมวส้มโอ -----------------------------------------------------------------
def hoard(out):
    """กองสมบัติของแมวส้มโอ: every shiny thing the soi ever lost, in one glittering pile."""
    c = Canvas(400, 360, seed=360)
    p = c.p
    c.ground_shadow(1.0, 0.8)
    rng = np.random.default_rng(360)
    c.disc(*p(0, 0, 0), 96 * c.ss, 48 * c.ss, hexc("#7A7060"), outline=1.6, rim=0.5, dome=True)
    c.disc(*p(0, 0, 30), 64 * c.ss, 32 * c.ss, hexc("#8A8070"), outline=1.2, rim=0.5, dome=True)
    for k in range(60):
        a, r = rng.uniform(0, 6.283), rng.uniform(0, 1) ** 0.5
        gx, gy = 0.62 * r * math.cos(a), 0.5 * r * math.sin(a)
        z = 6 + (1 - r * r) * 70
        col = (BRASS, STEEL, hexc("#E2B54A"), hexc("#D8D8E0"), RED_P, GLASS, hexc("#FFD070"))[k % 7]
        c.disc(*p(gx, gy, z), rng.uniform(6, 12) * c.ss, rng.uniform(3, 6) * c.ss, col, outline=1.0, rim=0.5, spec=1.0)
    for k in range(6):   # spoons and forks sticking out
        a = k * 1.05 + 0.3
        x0, y0 = 0.3 * math.cos(a), 0.25 * math.sin(a)
        c.stroke([p(x0, y0, 40), p(x0 * 1.9, y0 * 1.9, 70 + k * 6)], 3.2, hexc("#C0C8D0"))
        c.disc(*p(x0 * 1.9, y0 * 1.9, 72 + k * 6), 6 * c.ss, 4 * c.ss, hexc("#D8DEE4"), outline=0.6, spec=1.0)
    c.finish(out)


def cat_som_o(out):
    """แมวส้มโอ: an orange tabby the size of a fruit crate, sitting up and judging."""
    c = Canvas(300, 360, seed=363)
    p = c.p
    c.ground_shadow(0.6, 0.5)
    fur, dark, pale = hexc("#E8872A"), hexc("#B8601A"), hexc("#F7D9A8")
    c.disc(*p(0.0, 0.0, 50), 46 * c.ss, 40 * c.ss, fur, outline=2.0, rim=0.6, spec=0.3)          # body
    c.disc(*p(0.02, 0.05, 20), 34 * c.ss, 18 * c.ss, pale, outline=0.8, rim=0.2, spec=0.2)        # belly
    for k in range(3):                                                                              # stripes
        c.stroke([p(-0.2 + k * 0.1, -0.05, 60 + k * 8), p(-0.12 + k * 0.1, 0.0, 30 + k * 8)], 3.0, dark, 0.8)
    c.disc(*p(0.0, 0.0, 118), 32 * c.ss, 28 * c.ss, fur, outline=2.0, rim=0.6, spec=0.3)          # head
    for sx in (-1, 1):                                                                              # ears
        x, y = p(0.0, 0.0, 140)
        c.stroke([(x + sx * 18 * c.ss, y + 6 * c.ss), (x + sx * 30 * c.ss, y - 22 * c.ss), (x + sx * 8 * c.ss, y - 8 * c.ss)], 4.0, fur)
        c.stroke([(x + sx * 20 * c.ss, y + 2 * c.ss), (x + sx * 26 * c.ss, y - 14 * c.ss)], 2.0, hexc("#F0A0A0"))
    x, y = p(0.0, 0.0, 118)
    for sx in (-1, 1):                                                                              # eyes
        c.disc(x + sx * 12 * c.ss, y - 2 * c.ss, 7 * c.ss, 8 * c.ss, hexc("#7FD070"), outline=0.8, spec=0.0)
        c.disc(x + sx * 12 * c.ss, y - 2 * c.ss, 2 * c.ss, 7 * c.ss, INK, outline=0.0, spec=0.0)
    c.disc(x, y + 8 * c.ss, 4 * c.ss, 3 * c.ss, hexc("#F0A0A0"), outline=0.6)                       # nose
    for sx in (-1, 1):                                                                              # whiskers
        for dy in (-2, 4):
            c.stroke([(x + sx * 10 * c.ss, y + (8 + dy) * c.ss), (x + sx * 42 * c.ss, y + (2 + dy * 2) * c.ss)], 1.2, pale, 0.9)
    c.stroke([p(0.28, 0.1, 20), p(0.42, 0.12, 60), p(0.36, 0.1, 100)], 9.0, fur)                     # tail
    c.stroke([p(0.42, 0.12, 60), p(0.36, 0.1, 100)], 3.0, dark, 0.6)
    for sx in (-0.14, 0.14):                                                                       # front paws
        c.disc(*p(sx, 0.12, 6), 12 * c.ss, 7 * c.ss, pale, outline=1.2, rim=0.3)
    c.finish(out)


def tv_antenna(out):
    """เสาอากาศทีวีบนหลังคา: nobody has had a signal since 2070."""
    c = Canvas(260, 520, seed=361)
    p = c.p
    c.ground_shadow(0.3, 0.3)
    c.box(-0.02, -0.02, 0.02, 0.02, 0, 300, IRON, rim=0.5, outline=1.4)
    for k in range(5):
        z = 180 + k * 28
        w = 0.3 - k * 0.04
        c.stroke([p(-w, 0, z), p(w, 0, z)], 2.2, STEEL)
    c.stroke([p(0, -0.25, 300), p(0, 0.25, 300)], 2.2, STEEL)
    c.disc(*p(0.1, 0.0, 190), 5 * c.ss, 3 * c.ss, INK, outline=0.6)  # a bird, probably
    c.finish(out)


def roof_vent(out):
    """ปล่องระบายอากาศหมุนได้บนหลังคา: the cat's favourite seat."""
    c = Canvas(220, 320, seed=362)
    p = c.p
    c.ground_shadow(0.5, 0.5)
    c.cylinder(0, 0, 0.16, 0, 70, ZINC, spec=0.7, rim=0.6)
    c.frustum(0.22, 0.1, 70, 120, ZINC, rim=0.8)
    for k in range(8):
        a = k * math.pi / 4
        c.stroke([p(0.1 * math.cos(a), 0.1 * math.sin(a), 80), p(0.2 * math.cos(a), 0.2 * math.sin(a), 110)], 1.6, hexc("#7A7E7A"))
    c.finish(out)


PROPS = {f.__name__: f for f in (forecast_board, goldfish_jar, transistor_radio, hearing_notice, fish_grill,
                                 dry_goods_stall, lottery_stand, no_parking_sign, bell_tower, alms_boat,
                                 wetland_sign, incense_pot, rank_sign, vest_rack, hoard, tv_antenna, roof_vent, cat_som_o)}
for _n in (14, 15, 16, 17):
    PROPS["project_sign_%d" % _n] = project_sign(_n)

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
