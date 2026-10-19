"""Look test (2026-10-19, owner: "เท่" = Kingshot-style toon 3D): one present-day
Bangkok soi rendered from 3D primitives with the character toon shader, as a
room backdrop the engine can use directly.

Run (bpy 4.2):  python3 room3d.py <out.png> [gw gh wall_h_px]
Geometry = RoomCanvas (room.py): cell (gx, gy) -> screen ((gx-gy)*64, (gx+gy)*32)
at 1x; art at 2x. World: 1 cell = CELL m, x = gx, y = -gy, z up; camera ortho,
30 deg down, yaw 45 so grid diagonals land on the screen axes.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Euler
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char3d
from char3d import srgb, outline_material, PPU, ELEV

CELL = 256.0 / (math.sqrt(2.0) * PPU)        # a 128x64 tile (2x: 256x128) in metres
LIGHT = Vector((-0.375, -0.728, 0.58)).normalized()   # char3d.LIGHT turned by the camera yaw
SHADOW_DIR = Vector((-0.45, -0.89, 0.0)).normalized()   # cast toward the viewer-left (reads as contact shade)


def P(gx, gy, z=0.0):
    return Vector((gx * CELL, -gy * CELL, z))


# ---------------------------------------------------------------------------
# materials: flat chunky toon (sunlit / cool shade), ink outline hull
# ---------------------------------------------------------------------------
MATS = {}
INK = None


def env_material(hexcol, rim=0.25, tex=0.05, shade=(0.52, 0.56, 0.74), term=0.42, alpha=1.0):
    key = (hexcol, rim, tex, shade, term, alpha)
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new("E" + hexcol)
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    N.clear()
    out = N.new("ShaderNodeOutputMaterial")
    geo = N.new("ShaderNodeNewGeometry")
    dot = N.new("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = LIGHT
    L.new(geo.outputs["Normal"], dot.inputs[0])
    mapr = N.new("ShaderNodeMapRange")
    mapr.inputs["From Min"].default_value = -0.3
    mapr.inputs["From Max"].default_value = 1.0
    L.new(dot.outputs["Value"], mapr.inputs["Value"])
    ramp = N.new("ShaderNodeValToRGB")
    e = ramp.color_ramp.elements
    e[0].position, e[0].color = 0.0, (shade[0] * 0.8, shade[1] * 0.8, shade[2] * 0.8, 1)
    e[1].position, e[1].color = 1.0, (1.06, 1.03, 0.98, 1)
    k1 = e.new(term); k1.color = shade + (1,)
    k2 = e.new(term + 0.06); k2.color = (0.98, 0.96, 0.93, 1)
    L.new(mapr.outputs["Result"], ramp.inputs["Fac"])
    base = N.new("ShaderNodeRGB"); base.outputs[0].default_value = srgb(hexcol)
    tc = N.new("ShaderNodeTexCoord")
    noise = N.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 2.5
    noise.inputs["Detail"].default_value = 2.0
    L.new(tc.outputs["Object"], noise.inputs["Vector"])
    nmap = N.new("ShaderNodeMapRange")
    nmap.inputs["To Min"].default_value = 1 - tex
    nmap.inputs["To Max"].default_value = 1 + tex
    L.new(noise.outputs["Fac"], nmap.inputs["Value"])
    mul1 = N.new("ShaderNodeMix"); mul1.data_type = "RGBA"; mul1.blend_type = "MULTIPLY"
    mul1.inputs[0].default_value = 1.0
    L.new(base.outputs[0], mul1.inputs[6]); L.new(ramp.outputs["Color"], mul1.inputs[7])
    mul2 = N.new("ShaderNodeVectorMath"); mul2.operation = "SCALE"
    L.new(mul1.outputs[2], mul2.inputs[0]); L.new(nmap.outputs["Result"], mul2.inputs["Scale"])
    # warm rim on lit silhouettes
    lw = N.new("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.3
    rimr = N.new("ShaderNodeMapRange")
    rimr.inputs["From Min"].default_value = 0.6
    rimr.inputs["From Max"].default_value = 0.95
    rimr.inputs["To Max"].default_value = rim
    L.new(lw.outputs["Facing"], rimr.inputs["Value"])
    rimc = N.new("ShaderNodeMix"); rimc.data_type = "RGBA"
    L.new(rimr.outputs["Result"], rimc.inputs[0])
    L.new(mul2.outputs[0], rimc.inputs[6])
    rimc.inputs[7].default_value = (1.0, 0.85, 0.5, 1)
    em = N.new("ShaderNodeEmission")
    L.new(rimc.outputs[2], em.inputs["Color"])
    if alpha < 1.0:
        tr = N.new("ShaderNodeBsdfTransparent")
        mix = N.new("ShaderNodeMixShader")
        mix.inputs[0].default_value = alpha
        L.new(tr.outputs[0], mix.inputs[1]); L.new(em.outputs[0], mix.inputs[2])
        L.new(mix.outputs[0], out.inputs["Surface"])
    else:
        L.new(em.outputs[0], out.inputs["Surface"])
    MATS[key] = m
    return m


def shadow_material():
    m = bpy.data.materials.new("Shadow")
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    N.clear()
    out = N.new("ShaderNodeOutputMaterial")
    em = N.new("ShaderNodeEmission"); em.inputs["Color"].default_value = (0.08, 0.10, 0.22, 1)
    tr = N.new("ShaderNodeBsdfTransparent")
    mix = N.new("ShaderNodeMixShader"); mix.inputs[0].default_value = 0.3
    L.new(tr.outputs[0], mix.inputs[1]); L.new(em.outputs[0], mix.inputs[2])
    L.new(mix.outputs[0], out.inputs["Surface"])
    return m


# ---------------------------------------------------------------------------
# primitives (metres, world)
# ---------------------------------------------------------------------------
def _link(name, me):
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def finish(o, hexcol, ink=0.018, bevel=0.0, smooth=False, rim=0.25, shade=None, alpha=1.0):
    kw = {"rim": rim, "alpha": alpha}
    if shade:
        kw["shade"] = shade
    o.data.materials.append(env_material(hexcol, **kw))
    if bevel:
        b = o.modifiers.new("bev", "BEVEL"); b.width = bevel; b.segments = 3
        smooth = True
    for p in o.data.polygons:
        p.use_smooth = smooth
    if ink > 0:
        o.data.materials.append(INK)
        sol = o.modifiers.new("ink", "SOLIDIFY")
        sol.thickness = ink; sol.offset = 1.0; sol.use_flip_normals = True
        sol.material_offset = 1; sol.use_rim = False
    return o


def box(name, loc, size, hexcol, rot=(0, 0, 0), bevel=0.03, ink=0.018, **kw):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bm.to_mesh(me); bm.free()
    o = _link(name, me)
    o.location, o.rotation_euler = loc, rot
    return finish(o, hexcol, ink=ink, bevel=bevel, **kw)


def cyl(name, loc, r, depth, hexcol, rot=(0, 0, 0), seg=16, ink=0.015, r2=None, **kw):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    bm.to_mesh(me); bm.free()
    o = _link(name, me)
    o.location, o.rotation_euler = loc, rot
    return finish(o, hexcol, ink=ink, smooth=True, **kw)


def sphere(name, loc, r, hexcol, scale=(1, 1, 1), ink=0.018, **kw):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=r)
    bm.to_mesh(me); bm.free()
    o = _link(name, me)
    o.location, o.scale = loc, scale
    return finish(o, hexcol, ink=ink, smooth=True, **kw)


def prism(name, pts, z0, z1, hexcol, ink=0.018, bevel=0.0, **kw):
    """Extruded polygon (pts in world xy)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bot = [bm.verts.new((x, y, z0)) for x, y in pts]
    top = [bm.verts.new((x, y, z1)) for x, y in pts]
    bm.faces.new(bot[::-1]); bm.faces.new(top)
    n = len(pts)
    for i in range(n):
        bm.faces.new((bot[i], bot[(i + 1) % n], top[(i + 1) % n], top[i]))
    bm.to_mesh(me); bm.free()
    o = _link(name, me)
    return finish(o, hexcol, ink=ink, bevel=bevel, **kw)


def ground_poly(name, pts, hexcol, z=0.0, ink=0.0, **kw):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bm.faces.new([bm.verts.new((x, y, z)) for x, y in pts])
    bm.to_mesh(me); bm.free()
    o = _link(name, me)
    return finish(o, hexcol, ink=ink, **kw)


SHADOW = None


def _hull(pts):
    pts = sorted(set(pts))
    if len(pts) < 3:
        return pts
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for q in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], q) <= 0:
            lo.pop()
        lo.append(q)
    for q in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], q) <= 0:
            up.pop()
        up.append(q)
    return lo[:-1] + up[:-1]


def shadow(pts, h, z=0.004, k=0.35, grow=0.18):
    """Fake cast shadow: hull of the footprint (grown a little) and the footprint pushed along the light."""
    global SHADOW
    d = SHADOW_DIR * (min(h, 3.0) * k)
    cx = sum(x for x, _ in pts) / len(pts); cy = sum(y for _, y in pts) / len(pts)
    g = []
    for x, y in pts:
        vx, vy = x - cx, y - cy
        n = math.hypot(vx, vy) or 1.0
        g.append((x + vx / n * grow, y + vy / n * grow))
    hull = _hull(g + [(x + d.x, y + d.y) for x, y in g])
    me = bpy.data.meshes.new("shadow")
    bm = bmesh.new()
    bm.faces.new([bm.verts.new((x, y, z)) for x, y in hull])
    bm.to_mesh(me); bm.free()
    o = _link("shadow", me)
    if SHADOW is None:
        SHADOW = shadow_material()
    o.data.materials.append(SHADOW)
    return o


def rect_pts(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


# ---------------------------------------------------------------------------
# the soi
# ---------------------------------------------------------------------------
def shophouse(gx0, gx1, depth, floors, col, trim, roof, shutter, sign=None, awning=None, seed=0):
    """A shophouse along the back-right wall (gy from 0 to -depth, i.e. behind the floor edge)."""
    x0, x1 = gx0 * CELL, gx1 * CELL
    y0, y1 = 0.0, depth * CELL          # world y >= 0 is behind the back-right wall
    fh = 2.5
    H = floors * fh
    w = x1 - x0
    body = box("house", Vector(((x0 + x1) / 2, (y0 + y1) / 2, H / 2)), (w, y1 - y0, H), col, bevel=0.02)
    shadow(rect_pts(x0, y0, x1, y1), H)
    # floor slab bands + balcony on upper floors
    for f in range(1, floors):
        box("slab", Vector(((x0 + x1) / 2, y0 - 0.12, f * fh)), (w + 0.1, 0.3, 0.16), trim, bevel=0.02)
        # balcony rail
        box("rail", Vector(((x0 + x1) / 2, y0 - 0.26, f * fh + 0.45)), (w - 0.3, 0.05, 0.06), trim, bevel=0.01, ink=0.012)
        for i in range(int(w / 0.28)):
            box("bar", Vector((x0 + 0.2 + i * 0.28, y0 - 0.26, f * fh + 0.25)), (0.035, 0.035, 0.42), trim, bevel=0.0, ink=0.01)
        # windows
        nwin = max(1, int(w / 1.2))
        for i in range(nwin):
            wx = x0 + w * (i + 0.5) / nwin
            box("win", Vector((wx, y0 - 0.02, f * fh + 1.45)), (0.7, 0.06, 0.9), "#5A7FA8", bevel=0.0, ink=0.014,
                shade=(0.45, 0.5, 0.7))
            box("winfr", Vector((wx, y0 - 0.04, f * fh + 1.0)), (0.8, 0.04, 0.06), trim, bevel=0.0, ink=0.01)
            box("winfr", Vector((wx, y0 - 0.04, f * fh + 1.92)), (0.8, 0.04, 0.06), trim, bevel=0.0, ink=0.01)
            # air-con unit under every other window
            if (i + seed) % 2 == 0:
                box("ac", Vector((wx + 0.3, y0 - 0.22, f * fh + 0.55)), (0.42, 0.26, 0.3), "#E9E6DD", bevel=0.02, ink=0.012)
    # ground floor: roll-up shutter + door
    box("shutter", Vector(((x0 + x1) / 2, y0 - 0.03, fh - 0.55 + shutter * 0.5)), (w - 0.5, 0.05, 1.1 - shutter), "#8E96A6",
        bevel=0.0, ink=0.014, shade=(0.5, 0.55, 0.72))
    for i in range(8):
        box("shline", Vector(((x0 + x1) / 2, y0 - 0.06, fh - 0.1 - i * (1.1 - shutter) / 8)), (w - 0.5, 0.01, 0.015),
            "#6B7384", bevel=0.0, ink=0.0)
    box("shbox", Vector(((x0 + x1) / 2, y0 - 0.08, fh - 0.02)), (w - 0.3, 0.2, 0.22), trim, bevel=0.02)
    box("shop", Vector(((x0 + x1) / 2, y0 - 0.0, (fh - 0.55 + shutter * 0.5) / 2 - 0.1)), (w - 0.5, 0.04, fh - 1.1 + shutter * 0.5 + 0.5),
        "#2E2A33", bevel=0.0, ink=0.0)
    # roof: zinc sheets with a low parapet
    box("roof", Vector(((x0 + x1) / 2, (y0 + y1) / 2, H + 0.08)), (w + 0.16, y1 - y0 + 0.16, 0.16), roof, bevel=0.02)
    for i in range(int(w / 0.3)):
        box("ridge", Vector((x0 + 0.15 + i * 0.3, (y0 + y1) / 2, H + 0.18)), (0.06, y1 - y0 + 0.1, 0.05), roof, bevel=0.0, ink=0.0)
    box("tank", Vector((x1 - 0.5, y1 - 0.6, H + 0.55)), (0.5, 0.5, 0.8), "#4F86C6", bevel=0.05)
    if awning:
        a = box("awning", Vector(((x0 + x1) / 2, y0 - 0.55, fh + 0.05)), (w - 0.2, 1.1, 0.07), awning, rot=(math.radians(14), 0, 0),
                bevel=0.0, ink=0.016)
        shadow(rect_pts(x0 + 0.1, y0 - 1.1, x1 - 0.1, y0), 0.5, z=0.006, k=0.3)
        for i in range(int((w - 0.2) / 0.45)):
            box("ascal", Vector((x0 + 0.33 + i * 0.45, y0 - 1.08, fh - 0.12)), (0.4, 0.09, 0.16), "#F4F0E6" if i % 2 else awning,
                bevel=0.0, ink=0.012)
    if sign:
        sx, sw, sh, cols = sign
        for j, c in enumerate(cols):
            box("sign", Vector((x0 + sx, y0 - 0.14, fh + 0.9 - j * sh / len(cols))), (sw, 0.1, sh / len(cols) + 0.01), c,
                bevel=0.0, ink=0.0 if j else 0.016)
        box("signbox", Vector((x0 + sx, y0 - 0.12, fh + 0.9 - sh / 2 + sh / len(cols) / 2)), (sw + 0.08, 0.06, sh + 0.08), "#2E2A33",
            bevel=0.0, ink=0.0)


def power_pole(gx, gy, h=5.2):
    p = P(gx, gy)
    cyl("pole", p + Vector((0, 0, h / 2)), 0.1, h, "#B9B4A6", seg=10, r2=0.08)
    box("cross", p + Vector((0, 0, h - 0.25)), (1.2, 0.08, 0.08), "#8C8578", bevel=0.0)
    box("cross", p + Vector((0, 0, h - 0.6)), (0.9, 0.08, 0.08), "#8C8578", bevel=0.0)
    box("trafo", p + Vector((0.2, 0, h - 1.3)), (0.4, 0.4, 0.6), "#6E6A66", bevel=0.03)
    for i in range(3):
        cyl("ins", p + Vector((-0.5 + 0.5 * i, 0, h - 0.12)), 0.05, 0.14, "#D9D4C7", seg=8, ink=0.0)
    shadow([(p.x - 0.1, p.y - 0.1), (p.x + 0.1, p.y - 0.1), (p.x + 0.1, p.y + 0.1), (p.x - 0.1, p.y + 0.1)], h, k=0.9)
    return p + Vector((0, 0, h - 0.3))


def wire(a, b, sag=0.35, n=10, r=0.018):
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        p0 = a.lerp(b, t0) - Vector((0, 0, sag * math.sin(math.pi * t0)))
        p1 = a.lerp(b, t1) - Vector((0, 0, sag * math.sin(math.pi * t1)))
        d = p1 - p0
        o = cyl("wire", (p0 + p1) / 2, r, d.length, "#2A2730", seg=6, ink=0.0)
        o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()


def motorbike(gx, gy, col, yaw):
    p = P(gx, gy)
    e = Euler((0, 0, yaw))
    def at(v):
        v = Vector(v); v.rotate(e); return p + v
    for x in (-0.55, 0.55):
        cyl("wheel", at((x, 0, 0.26)), 0.26, 0.12, "#2B2A2E", rot=(math.radians(90), 0, yaw), seg=14, ink=0.014)
        cyl("hub", at((x, 0, 0.26)), 0.1, 0.14, "#BDBDBD", rot=(math.radians(90), 0, yaw), seg=10, ink=0.0)
    box("tank", at((0.08, 0, 0.62)), (0.55, 0.3, 0.3), col, rot=(0, 0, yaw), bevel=0.06)
    box("seat", at((-0.3, 0, 0.66)), (0.55, 0.3, 0.16), "#2B2A2E", rot=(0, 0, yaw), bevel=0.04)
    box("engine", at((0.0, 0, 0.38)), (0.5, 0.3, 0.3), "#6E6E72", rot=(0, 0, yaw), bevel=0.03)
    box("bar", at((0.5, 0, 0.9)), (0.08, 0.6, 0.06), "#4A4A4E", rot=(0, 0, yaw), bevel=0.0, ink=0.012)
    box("front", at((0.5, 0, 0.72)), (0.14, 0.32, 0.3), col, rot=(0, 0, yaw), bevel=0.04)
    shadow([(q.x, q.y) for q in (at((-0.8, -0.2, 0)), at((0.8, -0.2, 0)), at((0.8, 0.2, 0)), at((-0.8, 0.2, 0)))], 0.8, k=0.5)


def food_cart(gx, gy, yaw):
    p = P(gx, gy)
    e = Euler((0, 0, yaw))
    def at(v):
        v = Vector(v); v.rotate(e); return p + v
    box("cart", at((0, 0, 0.55)), (1.5, 0.75, 0.5), "#E7E3DA", rot=(0, 0, yaw), bevel=0.03)
    box("top", at((0, 0, 0.84)), (1.6, 0.85, 0.08), "#C9C3B6", rot=(0, 0, yaw), bevel=0.02)
    box("glass", at((0, 0.0, 1.12)), (1.3, 0.6, 0.5), "#BFE3F2", rot=(0, 0, yaw), bevel=0.02, ink=0.012, alpha=0.75)
    box("gfr", at((0, 0, 1.39)), (1.34, 0.64, 0.05), "#C9372C", rot=(0, 0, yaw), bevel=0.01)
    for x in (-0.55, 0.55):
        cyl("cw", at((x, 0.42, 0.22)), 0.22, 0.06, "#2B2A2E", rot=(math.radians(90), 0, yaw), seg=12, ink=0.012)
    cyl("pole", at((0.45, -0.3, 1.6)), 0.03, 1.6, "#9A9A9A", seg=8, ink=0.0)
    cyl("umb", at((0.45, -0.3, 2.4)), 1.35, 0.42, "#F28C28", seg=12, r2=0.0, ink=0.02)
    cyl("umbrim", at((0.45, -0.3, 2.2)), 1.35, 0.06, "#C96F1A", seg=12, ink=0.0)
    shadow([(q.x, q.y) for q in (at((-0.9, -1.0, 0)), at((1.6, -1.0, 0)), at((1.6, 0.5, 0)), at((-0.9, 0.5, 0)))], 1.3, k=0.6)
    # pots, bowls
    cyl("pot", at((-0.4, 0, 0.98)), 0.2, 0.26, "#B7B7B7", seg=12, ink=0.012)
    cyl("potlid", at((-0.4, 0, 1.13)), 0.22, 0.05, "#9A9A9A", seg=12, ink=0.0)
    for i in range(3):
        cyl("bowl", at((0.35 + 0.0, -0.2 + i * 0.2, 0.92)), 0.1, 0.08, "#F4F0E6", seg=10, ink=0.01)


def stool(gx, gy, col):
    p = P(gx, gy)
    cyl("stool", p + Vector((0, 0, 0.42)), 0.17, 0.06, col, seg=12, ink=0.014)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        cyl("leg", p + Vector((0.12 * math.cos(a), 0.12 * math.sin(a), 0.2)), 0.02, 0.4, col, seg=6, ink=0.0)


def plant_pot(gx, gy, size=1.0, leaf="#4E9A3C"):
    p = P(gx, gy)
    cyl("pot", p + Vector((0, 0, 0.2 * size)), 0.2 * size, 0.4 * size, "#B5603A", seg=12, r2=0.15 * size, ink=0.014)
    for i in range(4):
        a = i * math.pi / 2 + 0.4
        sphere("leaf", p + Vector((0.16 * size * math.cos(a), 0.16 * size * math.sin(a), 0.55 * size)), 0.17 * size, leaf,
               scale=(1, 1, 1.3))
    sphere("leaf", p + Vector((0, 0, 0.72 * size)), 0.17 * size, "#68B04A", scale=(1, 1, 1.4))


def tree(gx, gy, h=4.6):
    p = P(gx, gy)
    cyl("trunk", p + Vector((0, 0, h * 0.35)), 0.22, h * 0.7, "#6B4A33", seg=10, r2=0.16, ink=0.02)
    for (dx, dy, dz, r, c) in ((0, 0, h * 0.8, 1.5, "#3F8A3A"), (1.1, 0.4, h * 0.68, 1.1, "#4E9E42"), (-1.0, -0.3, h * 0.7, 1.15, "#4E9E42"),
                               (0.3, -0.9, h * 0.6, 0.95, "#5EB04C"), (-0.3, 0.9, h * 0.62, 0.95, "#3F8A3A"), (0.2, 0.2, h * 0.98, 1.0, "#6CC257")):
        sphere("canopy", p + Vector((dx, dy, dz)), r, c, scale=(1, 1, 0.78), ink=0.024)
    shadow([(p.x - 1.6, p.y - 1.3), (p.x + 1.6, p.y - 1.3), (p.x + 1.6, p.y + 1.3), (p.x - 1.6, p.y + 1.3)], h * 0.5, k=0.5)


def longtail(gx, gy, yaw, hull="#2F6DB5"):
    p = P(gx, gy, -0.12)
    e = Euler((0, 0, yaw))
    def at(v):
        v = Vector(v); v.rotate(e); return p + v
    L = 4.2
    pts = [(-L / 2, -0.42), (L / 2 - 0.5, -0.5), (L / 2 + 0.4, 0.0), (L / 2 - 0.5, 0.5), (-L / 2, 0.42)]
    wpts = []
    for x, y in pts:
        v = Vector((x, y, 0)); v.rotate(e); wpts.append((p.x + v.x, p.y + v.y))
    prism("hull", wpts, p.z, p.z + 0.5, hull, ink=0.02)
    prism("gunwale", wpts, p.z + 0.46, p.z + 0.54, "#E5D9B6", ink=0.012)
    # canopy over the middle
    box("canopy", at((-0.2, 0, 1.25)), (2.0, 1.25, 0.08), "#3BA8A0", rot=(0, 0, yaw), bevel=0.0)
    for x in (-1.1, 0.7):
        for y in (-0.45, 0.45):
            cyl("cpole", at((x, y, 0.85)), 0.03, 0.8, "#D9D4C7", seg=6, ink=0.0)
    cyl("motor", at((-L / 2 + 0.1, 0, 0.75)), 0.18, 0.5, "#4A4A4E", rot=(0, 0, yaw), seg=10)
    cyl("shaft", at((-L / 2 - 0.9, 0, 0.3)), 0.04, 2.2, "#8A8A8A", rot=(0, math.radians(65), yaw), seg=6, ink=0.0)
    # bow flags
    cyl("flagpole", at((L / 2 + 0.1, 0, 0.95)), 0.02, 0.9, "#D9D4C7", seg=6, ink=0.0)
    box("flag", at((L / 2 + 0.1, 0.0, 1.25)), (0.03, 0.4, 0.26), "#E8B52E", rot=(0, 0, yaw), bevel=0.0, ink=0.012)


def canal(gw, gh, gy0):
    """Water in the band gy >= gy0 (front-left of the floor), concrete edge, pier planks."""
    # water: whole band, lighter ripple bars
    x0, x1 = -gh * CELL * 0.0 - 4.0, gw * CELL + 6.0
    ground_poly("water", [(x0, -gy0 * CELL), (x1, -gy0 * CELL), (x1, -(gh + 6) * CELL), (x0, -(gh + 6) * CELL)], "#2E8E9B", z=-0.12,
                shade=(0.6, 0.72, 0.8), rim=0.0)
    import random
    rnd = random.Random(5)
    for i in range(60):
        gx = rnd.uniform(-2, gw + 2); gy = rnd.uniform(gy0 + 0.3, gh + 4)
        w = rnd.uniform(0.3, 0.9)
        box("ripple", P(gx, gy, -0.11), (w, 0.05, 0.004), "#67C3CD", rot=(0, 0, math.radians(45)), bevel=0.0, ink=0.0, rim=0.0)
    # water hyacinth clumps
    for i in range(7):
        gx = rnd.uniform(0, gw); gy = rnd.uniform(gy0 + 0.4, gh + 2.5)
        for j in range(4):
            sphere("hyacinth", P(gx + rnd.uniform(-0.3, 0.3), gy + rnd.uniform(-0.3, 0.3), -0.05), 0.16, "#5DB54A",
                   scale=(1, 1, 0.5), ink=0.012)
    # concrete edge
    box("edge", P(gw / 2, gy0 - 0.08, 0.0), ((gw + gh + 4) * CELL, 0.25, 0.3), "#B9B2A3", rot=(0, 0, 0), bevel=0.02)
    # pier: a plank deck sticking into the water on piles
    px = 3.2
    deck = box("deck", P(px, gy0 + 1.6, 0.1), (1.7, 2.6, 0.1), "#9C6B3F", bevel=0.01, ink=0.016)
    deck.rotation_euler = (0, 0, 0)
    for i in range(8):
        box("groove", P(px, gy0 + 0.35 + i * 0.4, 0.152), (1.7, 0.03, 0.01), "#6E4A2A", bevel=0.0, ink=0.0, rim=0.0)
    for (dx, dy) in ((-0.75, 0.4), (0.75, 0.4), (-0.75, 2.9), (0.75, 2.9)):
        cyl("pile", P(px + dx / CELL, gy0 + dy, -0.25), 0.09, 1.0, "#5C4030", seg=8)
    cyl("mooring", P(px + 0.95 / CELL, gy0 + 3.1, 0.35), 0.1, 1.0, "#6B4A33", seg=8)
    # tyre fenders on the edge
    for gx in (1.0, 6.5, 9.0):
        cyl("tyre", P(gx, gy0 + 0.05, 0.1), 0.3, 0.14, "#2B2A2E", rot=(math.radians(90), 0, 0), seg=14, ink=0.014)


def build(gw, gh, wall_h):
    global INK
    sc = char3d.reset()
    INK = outline_material()
    W, H = (gw + gh) * 128, (wall_h + (gw + gh) * 32) * 2
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.cycles.samples = 10
    cam = sc.camera
    cam.data.ortho_scale = H / PPU
    cam.data.shift_x = 0.0
    cx, cy = (gw - gh) * 32, ((gw + gh) * 32 - wall_h) / 2
    tgx, tgy = cx / 128 + cy / 64, cy / 64 - cx / 128
    fwd = Vector((-math.cos(ELEV) / math.sqrt(2), math.cos(ELEV) / math.sqrt(2), -math.sin(ELEV)))
    cam.location = P(tgx, tgy) - fwd * 60
    cam.rotation_euler = Euler((math.radians(90) - ELEV, 0, math.radians(45)), "XYZ")
    # sky colour behind everything (the backdrop must cover its rect)
    sc.render.film_transparent = False
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = srgb("#9ED4EE")
    sc.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0

    CANAL = 6.6
    # concrete soi floor with a darker drain strip and painted edge
    ground_poly("floor", [(-gh * CELL - 6, 1.0), ((gw + 8) * CELL, 1.0), ((gw + 8) * CELL, -CANAL * CELL), (-gh * CELL - 6, -CANAL * CELL)],
                "#C8C1B0", shade=(0.62, 0.66, 0.8), rim=0.0)
    for i in range(14):
        box("crack", P(1 + i * 0.9, 2.5 + (i % 3) * 1.2, 0.002), (0.9, 0.03, 0.002), "#AFA897", rot=(0, 0, math.radians(90)), bevel=0.0, ink=0.0, rim=0.0)
    box("drain", P(gw / 2, 1.0, 0.003), ((gw + gh + 4) * CELL, 0.5, 0.004), "#B3AC9C", bevel=0.0, ink=0.0, rim=0.0)
    for i in range(40):
        box("grate", P(-3 + i * 0.55, 1.0, 0.006), (0.22, 0.5, 0.004), "#8E8878", bevel=0.0, ink=0.0, rim=0.0)
    canal(gw, gh, CANAL)

    # back-right: three shophouses (pink / mint / cream) + a taller one off the edge
    shophouse(-1.0, 3.0, 2.6, 2, "#F2A7B8", "#F7F2E8", "#8A97A8", shutter=0.0, awning="#D33A2F", seed=1)
    shophouse(3.0, 7.2, 2.6, 2, "#A8DCCB", "#F7F2E8", "#7E8B9C", shutter=0.9,
              sign=(2.1, 2.6, 0.5, ("#F28C28", "#3F8A3A", "#D33A2F")), seed=0)
    shophouse(7.2, 11.6, 2.6, 3, "#F4E1A6", "#F7F2E8", "#8A97A8", shutter=0.4, awning="#2F8FB5", seed=1)
    shophouse(11.6, 15.0, 2.6, 2, "#C9CFE8", "#F7F2E8", "#7E8B9C", shutter=1.0, seed=0)
    # back-left: temple wall with a gate, the rain tree, a chedi behind
    ground_poly("grass", [(-gh * CELL - 8, -gh * CELL - 3), (-0.1, -gh * CELL - 3), (-0.1, 2.0), (-gh * CELL - 8, 2.0)], "#7FBF5A",
                z=0.001, shade=(0.5, 0.62, 0.7), rim=0.0)
    wallpts = rect_pts(-0.55, -gh * CELL - 2, -0.1, 0.9)
    prism("twall", wallpts, 0, 1.5, "#F1E8D8", bevel=0.02)
    shadow(wallpts, 1.5)
    box("wallcap", Vector((-0.33, (-gh * CELL - 2 + 0.9) / 2, 1.55)), (0.6, gh * CELL + 2.9 + 0.2, 0.12), "#D9A44A", bevel=0.02)
    for i in range(9):
        box("wtile", Vector((-0.3, -0.8 - i * 0.85, 0.85)), (0.08, 0.5, 0.5), "#E35C3F", bevel=0.0, ink=0.012)
    # gate in the wall (the exit to the temple)
    box("gate", Vector((-0.3, -4.4, 0.8)), (0.5, 1.5, 1.6), "#8A5D36", bevel=0.02)
    box("gatehead", Vector((-0.4, -4.4, 1.95)), (0.7, 2.1, 0.4), "#D9A44A", bevel=0.03)
    cyl("gable", Vector((-0.4, -4.4, 2.5)), 0.9, 0.7, "#E35C3F", rot=(0, 0, 0), seg=4, r2=0.0, ink=0.018)
    tree(-2.6, 5.2)
    # chedi inside the temple grounds, seen over the wall
    cyl("chedi", Vector((-3.4, 1.2, 0.8)), 1.3, 1.6, "#F5F0E4", seg=16, r2=1.0, ink=0.022)
    cyl("chedi2", Vector((-3.4, 1.2, 2.5)), 0.95, 2.0, "#F5F0E4", seg=16, r2=0.55, ink=0.022)
    cyl("chedi3", Vector((-3.4, 1.2, 4.5)), 0.5, 2.6, "#F0D27A", seg=12, r2=0.0, ink=0.022)
    cyl("chedi4", Vector((-3.4, 1.2, 5.9)), 0.12, 0.8, "#F0D27A", seg=8, r2=0.0, ink=0.0)
    # a second, smaller house behind the wall on the far left so the corner is not empty
    box("sala", Vector((-4.2, -4.2, 1.3)), (2.6, 2.6, 2.6), "#D9C9A8", bevel=0.02)
    shadow(rect_pts(-5.5, -5.5, -2.9, -2.9), 2.6)
    cyl("salaroof", Vector((-4.2, -4.2, 3.2)), 2.2, 1.6, "#B5543A", rot=(0, 0, math.radians(45)), seg=4, r2=0.2, ink=0.02)

    # power poles + the famous Bangkok wire tangle
    a = power_pole(2.2, 4.4)
    b = power_pole(9.3, 3.9)
    for dz in (0.0, -0.25, -0.5):
        wire(a + Vector((0, 0, dz)), b + Vector((0, 0, dz)), sag=0.5 + 0.1 * abs(dz))
    wire(a + Vector((0, 0, -0.1)), Vector((0.4, -0.2, 4.6)), sag=0.3)
    wire(b + Vector((0, 0, -0.1)), Vector((8.4, -0.2, 4.7)), sag=0.3)
    wire(b + Vector((0, 0, -0.4)), Vector((12.5, -0.2, 4.4)), sag=0.3)
    wire(a + Vector((0, 0, -0.3)), Vector((-0.3, -3.2, 2.4)), sag=0.2)
    # bundle hanging off pole a (the ball of spare cable)
    for i in range(3):
        cyl("coil", a + Vector((0.1, 0.1, -1.2 - 0.12 * i)), 0.3, 0.05, "#2A2730", rot=(math.radians(90), 0, 0), seg=12, ink=0.0)

    # street life
    food_cart(6.2, 4.3, math.radians(-30))
    for (x, y, c) in ((5.2, 5.2, "#D33A2F"), (6.0, 5.6, "#2F6DB5"), (7.1, 5.5, "#D33A2F"), (7.6, 4.9, "#F2C43D")):
        stool(x, y, c)
    for (x, y, c, yaw) in ((9.4, 2.0, "#D33A2F", math.radians(70)), (10.9, 2.6, "#2F6DB5", math.radians(74))):
        motorbike(x, y, c, yaw)
    for (x, y, s) in ((0.6, 1.4, 1.0), (1.4, 1.1, 0.8), (8.0, 1.3, 0.9), (3.4, 1.2, 0.7)):
        plant_pot(x, y, s)
    # bins, a cat on the wall, a cooler, gas cylinders
    cyl("bin", P(4.2, 1.5, 0.45), 0.3, 0.9, "#3F8A3A", seg=12, r2=0.26)
    cyl("binlid", P(4.2, 1.5, 0.92), 0.32, 0.06, "#2E6E2C", seg=12, ink=0.0)
    box("cooler", P(1.9, 1.6, 0.3), (0.6, 0.45, 0.6), "#2F6DB5", bevel=0.04)
    box("coolerlid", P(1.9, 1.6, 0.63), (0.64, 0.49, 0.08), "#F4F0E6", bevel=0.02)
    for i in range(2):
        cyl("gas", P(11.0, 1.2 + i * 0.4, 0.4), 0.17, 0.8, "#D9A44A", seg=10)
    sphere("cat", Vector((-0.42, -2.6, 2.17)), 0.17, "#F0A85A", scale=(1.6, 1.0, 0.9))
    sphere("cathead", Vector((-0.42, -2.9, 2.25)), 0.12, "#F0A85A")
    # a parked tuk-tuk-ish pickup near the right edge
    box("truck", P(11.4, 5.6, 0.75), (2.4, 1.3, 0.9), "#F4F0E6", rot=(0, 0, math.radians(-20)), bevel=0.05)
    box("cab", P(12.0, 5.8, 1.35), (1.0, 1.25, 0.9), "#F4F0E6", rot=(0, 0, math.radians(-20)), bevel=0.06)
    box("load", P(11.1, 5.5, 1.32), (1.3, 1.1, 0.3), "#5DB54A", rot=(0, 0, math.radians(-20)), bevel=0.04)
    for dx in (-0.9, 0.9):
        cyl("tw", P(11.4 + dx * 0.9 / CELL, 5.6 + dx * 0.35 / CELL, 0.3), 0.3, 1.4, "#2B2A2E", rot=(math.radians(90), 0, math.radians(-20)), seg=12, ink=0.012)
    # boats on the canal
    longtail(2.8, 8.1, math.radians(12))
    longtail(9.5, 8.6, math.radians(-8), hull="#C9372C")
    return sc, (W, H)


def main():
    out = sys.argv[1]
    gw, gh, wall_h = (int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (12, 9, 520)
    sc, (W, H) = build(gw, gh, wall_h)
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("rendered", out, W, H)


if __name__ == "__main__":
    main()
