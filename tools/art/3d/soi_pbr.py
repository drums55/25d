"""Look test round 2 (2026-10-19, owner: "texture, model — ใช้ 3D แบบ Blender"):
the same soi as room3d.py but built the Blender way — PBR materials from
Poly Haven CC0 textures, CC0 models (Poly Haven, KayKit), a sun + sky HDRI,
real cast shadows / AO, denoised Cycles render. Same room geometry as the
engine (RoomCanvas: cell (gx, gy) -> ((gx-gy)*64, (gx+gy)*32) at 1x, art at 2x).

Run (bpy 4.2):  ASSETS=<dir with ph/ and kits/> QDIR=<quaternius dir> python3 soi_pbr.py <out.png> [pct] [--hero]
"""
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Euler, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.environ.get("ASSETS", "/tmp/claude-0/-home-user-25d/37f09004-7fa2-5722-9eab-dc516f5036fd/scratchpad")
PH = A + "/ph"
KAY = A + "/kits/city-builder-bits/8567487/KayKit_City_Builder_Bits_1.0_FREE/Assets/gltf/"
ELEV = math.radians(30.0)
CHAR_PX = 360.0
PPU = CHAR_PX / (1.75 * math.cos(ELEV))
CELL = 256.0 / (math.sqrt(2.0) * PPU)
SUN = Vector((0.85, -0.4, 1.1)).normalized()      # toward the sun: screen right-front, high (fronts lit, shadows fall up-left)


def P(gx, gy, z=0.0):
    return Vector((gx * CELL, -gy * CELL, z))


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c) + (1.0,)


# ---------------------------------------------------------------------------
# materials
# ---------------------------------------------------------------------------
MATS = {}
IMGS = {}


def img(name):
    if name not in IMGS:
        IMGS[name] = bpy.data.images.load(os.path.join(PH, name))
        if "diff" not in name:
            IMGS[name].colorspace_settings.name = "Non-Color"
    return IMGS[name]


def pbr(key, tex=None, tint="#FFFFFF", scale=1.0, rough=None, metal=0.0, nstr=1.0, spec=0.5, alpha=1.0, emit=0.0, gain=1.0):
    """Principled material; tex = Poly Haven texture stem (uses <tex>_diff/_nor_gl/_rough jpg), UV-mapped."""
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    bsdf = N["Principled BSDF"]
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Specular IOR Level"].default_value = spec
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = srgb(tint)
        bsdf.inputs["Emission Strength"].default_value = emit
    if tex:
        tc = N.new("ShaderNodeTexCoord")
        mp = N.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (scale, scale, scale)
        L.new(tc.outputs["UV"], mp.inputs["Vector"])
        d = N.new("ShaderNodeTexImage"); d.image = img(tex + "_diff.jpg")
        L.new(mp.outputs[0], d.inputs["Vector"])
        mix = N.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"; mix.inputs[0].default_value = 1.0
        L.new(d.outputs["Color"], mix.inputs[6]); mix.inputs[7].default_value = tuple(c * gain for c in srgb(tint)[:3]) + (1.0,)
        L.new(mix.outputs[2], bsdf.inputs["Base Color"])
        r = N.new("ShaderNodeTexImage"); r.image = img(tex + "_rough.jpg")
        L.new(mp.outputs[0], r.inputs["Vector"])
        if rough is None:
            L.new(r.outputs["Color"], bsdf.inputs["Roughness"])
        else:
            bsdf.inputs["Roughness"].default_value = rough
        n = N.new("ShaderNodeTexImage"); n.image = img(tex + "_nor_gl.jpg")
        L.new(mp.outputs[0], n.inputs["Vector"])
        nm = N.new("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = nstr
        L.new(n.outputs["Color"], nm.inputs["Color"]); L.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    else:
        bsdf.inputs["Base Color"].default_value = srgb(tint)
        bsdf.inputs["Roughness"].default_value = 0.5 if rough is None else rough
    MATS[key] = m
    return m


def water_material():
    m = bpy.data.materials.new("Water")
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    b = N["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.02, 0.16, 0.17, 1)
    b.inputs["Roughness"].default_value = 0.06
    b.inputs["Specular IOR Level"].default_value = 0.6
    tc = N.new("ShaderNodeTexCoord")
    n1 = N.new("ShaderNodeTexNoise"); n1.inputs["Scale"].default_value = 1.6; n1.inputs["Detail"].default_value = 6
    n1.inputs["Distortion"].default_value = 0.4
    mp = N.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (1.0, 2.6, 1.0)
    L.new(tc.outputs["Object"], mp.inputs["Vector"]); L.new(mp.outputs[0], n1.inputs["Vector"])
    bump = N.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.35; bump.inputs["Distance"].default_value = 0.08
    L.new(n1.outputs["Fac"], bump.inputs["Height"]); L.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


# ---------------------------------------------------------------------------
# geometry
# ---------------------------------------------------------------------------
def _link(name, me):
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def cube_uv(me, scale=1.0):
    """Per-face planar UVs on the dominant axis, in metres * scale (tiling textures without unwrapping)."""
    bm = bmesh.new(); bm.from_mesh(me)
    uv = bm.loops.layers.uv.new()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        i, j = [(1, 2), (0, 2), (0, 1)][ax]
        for l in f.loops:
            l[uv].uv = (l.vert.co[i] * scale, l.vert.co[j] * scale)
    bm.to_mesh(me); bm.free()


def finish(o, mat, bevel=0.0, smooth=False, uvscale=1.0):
    cube_uv(o.data, uvscale)
    o.data.materials.append(mat)
    if bevel:
        b = o.modifiers.new("bev", "BEVEL"); b.width = bevel; b.segments = 3; b.harden_normals = True
        smooth = True
    for p in o.data.polygons:
        p.use_smooth = smooth
    return o


def box(name, loc, size, mat, rot=(0, 0, 0), bevel=0.02, **kw):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bm.to_mesh(me); bm.free()
    o = _link(name, me)
    o.location, o.rotation_euler = loc, rot
    return finish(o, mat, bevel=bevel, **kw)


def cyl(name, loc, r, depth, mat, rot=(0, 0, 0), seg=24, r2=None, **kw):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    bm.to_mesh(me); bm.free()
    o = _link(name, me)
    o.location, o.rotation_euler = loc, rot
    return finish(o, mat, smooth=True, **kw)


def sphere(name, loc, r, mat, scale=(1, 1, 1), cut=None, **kw):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=r)
    if cut is not None:   # dome: keep z >= cut * r
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < cut * r - 1e-6], context="VERTS")
    bm.to_mesh(me); bm.free()
    o = _link(name, me)
    o.location, o.scale = loc, scale
    return finish(o, mat, smooth=True, **kw)


def prism(name, pts, z0, z1, mat, **kw):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bot = [bm.verts.new((x, y, z0)) for x, y in pts]
    top = [bm.verts.new((x, y, z1)) for x, y in pts]
    bm.faces.new(bot[::-1]); bm.faces.new(top)
    n = len(pts)
    for i in range(n):
        bm.faces.new((bot[i], bot[(i + 1) % n], top[(i + 1) % n], top[i]))
    bm.to_mesh(me); bm.free()
    return finish(_link(name, me), mat, **kw)


def ground(name, pts, mat, z=0.0, **kw):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bm.faces.new([bm.verts.new((x, y, z)) for x, y in pts])
    bm.to_mesh(me); bm.free()
    return finish(_link(name, me), mat, **kw)


def rect_pts(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def import_model(path, loc, yaw=0.0, height=None, scale=None, name=None, pick=None):
    """glTF model -> one parent empty at loc; scaled to `height` (m) or `scale`; base on the ground."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    if pick:
        for o in list(new):
            if o.type == "MESH" and not pick(o.name):
                bpy.data.objects.remove(o); new.remove(o)
    roots = [o for o in new if o.parent is None or o.parent not in new]
    root = bpy.data.objects.new(name or os.path.basename(path), None)
    bpy.context.scene.collection.objects.link(root)
    for o in roots:
        o.parent = root
    bpy.context.view_layer.update()
    pts = []
    for o in new:
        if o.type == "MESH":
            for c in o.bound_box:
                pts.append(o.matrix_world @ Vector(c))
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    s = scale if scale else (height / max(hi.z - lo.z, 1e-6) if height else 1.0)
    root.scale = (s, s, s)
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    root.rotation_euler = (0, 0, yaw)
    off = Vector((centre.x * s, centre.y * s, centre.z * s)); off.rotate(Euler((0, 0, yaw)))
    root.location = Vector(loc) - off
    for o in new:
        if o.type == "MESH":
            for p in o.data.polygons:
                p.use_smooth = True
    return root


def ph(name):
    return os.path.join(PH, "models", name, name + ".gltf")


# ---------------------------------------------------------------------------
# the soi
# ---------------------------------------------------------------------------
def shophouse(gx0, gx1, depth, floors, tint, roofmat, shutter, awning=None, sign=None, seed=0):
    x0, x1 = gx0 * CELL, gx1 * CELL
    y0, y1 = 0.0, depth * CELL
    fh = 2.5
    H = floors * fh
    w = x1 - x0
    wall = pbr("plaster_" + tint, "painted_plaster_wall", tint, scale=0.5)
    trim = pbr("trim", None, "#F3EEE4", rough=0.55)
    box("house", Vector(((x0 + x1) / 2, (y0 + y1) / 2, H / 2)), (w, y1 - y0, H), wall, bevel=0.015)
    for f in range(1, floors):
        box("slab", Vector(((x0 + x1) / 2, y0 - 0.12, f * fh)), (w + 0.1, 0.3, 0.16), pbr("conc_trim", "concrete_floor_painted", "#F0EAE0", 0.6, gain=2.0), bevel=0.015)
        box("rail", Vector(((x0 + x1) / 2, y0 - 0.26, f * fh + 0.45)), (w - 0.3, 0.05, 0.06), pbr("railm", None, "#D8D4CC", rough=0.35, metal=0.8), bevel=0.008)
        for i in range(int(w / 0.26)):
            box("bar", Vector((x0 + 0.2 + i * 0.26, y0 - 0.26, f * fh + 0.25)), (0.03, 0.03, 0.42), pbr("railm"), bevel=0.0)
        nwin = max(1, int(w / 1.2))
        for i in range(nwin):
            wx = x0 + w * (i + 0.5) / nwin
            box("win", Vector((wx, y0 - 0.02, f * fh + 1.45)), (0.72, 0.06, 0.92), pbr("glass", None, "#5A7FA8", rough=0.05, metal=0.6), bevel=0.0)
            box("winfr", Vector((wx, y0 - 0.05, f * fh + 1.45)), (0.84, 0.05, 0.06), trim, bevel=0.005)
            box("winfr", Vector((wx, y0 - 0.05, f * fh + 1.0)), (0.84, 0.05, 0.08), trim, bevel=0.005)
            box("winfr", Vector((wx, y0 - 0.05, f * fh + 1.92)), (0.84, 0.05, 0.06), trim, bevel=0.005)
            for sx in (-0.4, 0.4):
                box("winfr", Vector((wx + sx, y0 - 0.05, f * fh + 1.45)), (0.05, 0.05, 0.96), trim, bevel=0.005)
            if (i + seed) % 2 == 0:
                box("ac", Vector((wx + 0.32, y0 - 0.22, f * fh + 0.55)), (0.42, 0.26, 0.3), pbr("acm", None, "#E9E6DD", rough=0.6), bevel=0.015)
                box("acgrill", Vector((wx + 0.32, y0 - 0.355, f * fh + 0.55)), (0.34, 0.01, 0.22), pbr("acg", None, "#9C9A94", rough=0.7), bevel=0.0)
    # ground floor: dark shop interior, roll-up shutter, shutter box
    box("shop", Vector(((x0 + x1) / 2, y0 + 0.02, (fh - 0.3) / 2)), (w - 0.5, 0.04, fh - 0.3), pbr("shopdark", None, "#8A6E4C", rough=0.9, emit=1.2), bevel=0.0)
    sh_h = (1.1 - shutter) * 1.6
    if sh_h > 0.05:
        box("shutter", Vector(((x0 + x1) / 2, y0 - 0.03, fh - 0.25 - sh_h / 2)), (w - 0.5, 0.04, sh_h),
            pbr("shutter", "corrugated_iron_02", "#D5D9E0", scale=1.4, metal=0.5, rough=0.45, gain=1.6), bevel=0.0, uvscale=1.0)
    box("shbox", Vector(((x0 + x1) / 2, y0 - 0.1, fh - 0.08)), (w - 0.3, 0.24, 0.26), pbr("shboxm", None, "#CFCAC0", rough=0.5), bevel=0.015)
    for sx in (x0 + 0.12, x1 - 0.12):
        box("pillar", Vector((sx, y0 - 0.04, fh / 2)), (0.26, 0.12, fh), wall, bevel=0.01)
    # roof: zinc sheets + a parapet, water tank
    box("roof", Vector(((x0 + x1) / 2, (y0 + y1) / 2, H + 0.06)), (w + 0.16, y1 - y0 + 0.16, 0.12), roofmat, bevel=0.01, uvscale=1.0)
    box("tank", Vector((x1 - 0.5, y1 - 0.6, H + 0.55)), (0.5, 0.5, 0.8), pbr("tank", None, "#3E78B8", rough=0.5), bevel=0.04)
    if awning:
        a = box("awning", Vector(((x0 + x1) / 2, y0 - 0.55, fh + 0.05)), (w - 0.2, 1.1, 0.04), pbr("awn_" + awning, None, awning, rough=0.85),
                rot=(math.radians(14), 0, 0), bevel=0.0)
        for i in range(int((w - 0.2) / 0.45)):
            box("ascal", Vector((x0 + 0.33 + i * 0.45, y0 - 1.08, fh - 0.12)), (0.4, 0.06, 0.16),
                pbr("awn_w", None, "#F4F0E6", rough=0.85) if i % 2 else pbr("awn_" + awning), bevel=0.0)
        for sx in (x0 + 0.3, x1 - 0.3):
            cyl("apole", Vector((sx, y0 - 0.55, fh - 0.25)), 0.02, 1.2, pbr("railm"), rot=(math.radians(-76), 0, 0), seg=8)
    if sign:
        sx, sw, sh, cols = sign
        box("signbox", Vector((x0 + sx, y0 - 0.1, fh + 0.9 - sh / 2 + sh / len(cols) / 2)), (sw + 0.08, 0.08, sh + 0.08), pbr("signbox", None, "#2E2A33", rough=0.4), bevel=0.01)
        for j, c in enumerate(cols):
            box("sign", Vector((x0 + sx, y0 - 0.15, fh + 0.9 - j * sh / len(cols))), (sw, 0.02, sh / len(cols) + 0.005),
                pbr("sign_" + c, None, c, rough=0.3, emit=0.4), bevel=0.0)


def wire(a, b, sag=0.35, n=12, r=0.014):
    mat = pbr("wire", None, "#1C1A1E", rough=0.5)
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        p0 = a.lerp(b, t0) - Vector((0, 0, sag * math.sin(math.pi * t0)))
        p1 = a.lerp(b, t1) - Vector((0, 0, sag * math.sin(math.pi * t1)))
        d = p1 - p0
        o = cyl("wire", (p0 + p1) / 2, r, d.length, mat, seg=6)
        o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()


def power_pole(gx, gy, h=5.4):
    p = P(gx, gy)
    conc = pbr("polec", "concrete_floor_painted", "#D9D3C6", 0.8, gain=1.8)
    cyl("pole", p + Vector((0, 0, h / 2)), 0.11, h, conc, seg=12, r2=0.08)
    box("cross", p + Vector((0, 0, h - 0.25)), (1.3, 0.09, 0.09), pbr("crossm", None, "#7D7668", rough=0.8), bevel=0.005)
    box("cross", p + Vector((0, 0, h - 0.65)), (1.0, 0.09, 0.09), pbr("crossm"), bevel=0.005)
    box("trafo", p + Vector((0.22, 0, h - 1.4)), (0.42, 0.42, 0.7), pbr("trafo", "rusty_metal_02", "#8A8F96", 0.8, metal=0.3), bevel=0.02)
    for i in range(3):
        cyl("ins", p + Vector((-0.5 + 0.5 * i, 0, h - 0.12)), 0.05, 0.14, pbr("ins", None, "#D9D4C7", rough=0.3), seg=8)
    for i in range(3):
        cyl("coil", p + Vector((0.12, 0.1, -1.2 - 0.12 * i + h)), 0.3, 0.05, pbr("wire", None, "#1C1A1E", rough=0.5), rot=(math.radians(90), 0, 0), seg=16)
    return p + Vector((0, 0, h - 0.3))


def motorbike(gx, gy, col, yaw):
    p = P(gx, gy)
    e = Euler((0, 0, yaw))
    def at(v):
        v = Vector(v); v.rotate(e); return p + v
    paint = pbr("paint_" + col, None, col, rough=0.3, metal=0.35)
    rub = pbr("rubber", None, "#232226", rough=0.8)
    chrome = pbr("chrome", None, "#C8CACF", rough=0.25, metal=0.9)
    for x in (-0.55, 0.55):
        cyl("wheel", at((x, 0, 0.26)), 0.26, 0.11, rub, rot=(math.radians(90), 0, yaw), seg=20)
        cyl("hub", at((x, 0, 0.26)), 0.1, 0.13, chrome, rot=(math.radians(90), 0, yaw), seg=12)
    box("tank", at((0.08, 0, 0.62)), (0.55, 0.3, 0.3), paint, rot=(0, 0, yaw), bevel=0.06)
    box("seat", at((-0.3, 0, 0.66)), (0.55, 0.3, 0.16), rub, rot=(0, 0, yaw), bevel=0.04)
    box("engine", at((0.0, 0, 0.38)), (0.5, 0.3, 0.3), chrome, rot=(0, 0, yaw), bevel=0.03)
    box("bar", at((0.5, 0, 0.9)), (0.08, 0.62, 0.05), chrome, rot=(0, 0, yaw), bevel=0.0)
    box("front", at((0.5, 0, 0.72)), (0.14, 0.32, 0.3), paint, rot=(0, 0, yaw), bevel=0.04)
    sphere("lamp", at((0.58, 0, 0.78)), 0.09, pbr("lampg", None, "#F2E6C0", rough=0.1, emit=0.3))


def food_cart(gx, gy, yaw):
    p = P(gx, gy)
    e = Euler((0, 0, yaw))
    def at(v):
        v = Vector(v); v.rotate(e); return p + v
    steel = pbr("steel", None, "#C9CCD2", rough=0.3, metal=0.9)
    box("cart", at((0, 0, 0.55)), (1.5, 0.75, 0.5), steel, rot=(0, 0, yaw), bevel=0.02)
    box("top", at((0, 0, 0.84)), (1.6, 0.85, 0.06), steel, rot=(0, 0, yaw), bevel=0.01)
    box("glass", at((0, 0.0, 1.12)), (1.3, 0.6, 0.5), pbr("cglass", None, "#DDF0F8", rough=0.03, alpha=0.3), rot=(0, 0, yaw), bevel=0.0)
    box("gfr", at((0, 0, 1.39)), (1.34, 0.64, 0.05), pbr("paint_#C9372C", None, "#C9372C", rough=0.3, metal=0.35), rot=(0, 0, yaw), bevel=0.01)
    for x in (-0.55, 0.55):
        cyl("cw", at((x, 0.42, 0.22)), 0.22, 0.06, pbr("rubber", None, "#232226", rough=0.8), rot=(math.radians(90), 0, yaw), seg=16)
    cyl("pole", at((0.45, -0.3, 1.6)), 0.03, 1.7, steel, seg=10)
    cyl("umb", at((0.45, -0.3, 2.45)), 1.35, 0.42, pbr("umb", None, "#F28C28", rough=0.85), seg=16, r2=0.0)
    cyl("umbrim", at((0.45, -0.3, 2.25)), 1.35, 0.05, pbr("umb2", None, "#C96F1A", rough=0.85), seg=16)
    cyl("pot", at((-0.4, 0, 0.98)), 0.2, 0.26, pbr("alu", None, "#B7B7B7", rough=0.4, metal=0.8), seg=16)
    for i in range(3):
        cyl("bowl", at((0.35, -0.2 + i * 0.2, 0.92)), 0.1, 0.08, pbr("melamine", None, "#F4F0E6", rough=0.35), seg=12)


def longtail(gx, gy, yaw, hull="#2F6DB5"):
    p = P(gx, gy, -0.14)
    e = Euler((0, 0, yaw))
    def at(v):
        v = Vector(v); v.rotate(e); return p + v
    L = 4.2
    pts = [(-L / 2, -0.42), (L / 2 - 0.5, -0.5), (L / 2 + 0.4, 0.0), (L / 2 - 0.5, 0.5), (-L / 2, 0.42)]
    wpts = []
    for x, y in pts:
        v = Vector((x, y, 0)); v.rotate(e); wpts.append((p.x + v.x, p.y + v.y))
    prism("hull", wpts, p.z, p.z + 0.5, pbr("hull_" + hull, "wood_planks_dirt", hull, 0.8), bevel=0.02)
    prism("gunwale", wpts, p.z + 0.46, p.z + 0.54, pbr("gunwale", "weathered_planks", "#E5D9B6", 1.0), bevel=0.01)
    box("canopy", at((-0.2, 0, 1.25)), (2.0, 1.25, 0.05), pbr("tarp", None, "#3BA8A0", rough=0.8), rot=(0, 0, yaw), bevel=0.0)
    for x in (-1.1, 0.7):
        for y in (-0.45, 0.45):
            cyl("cpole", at((x, y, 0.85)), 0.025, 0.8, pbr("railm"), seg=8)
    cyl("motor", at((-L / 2 + 0.1, 0, 0.75)), 0.18, 0.5, pbr("engine", None, "#4A4A4E", rough=0.5, metal=0.6), rot=(0, 0, yaw), seg=14)
    cyl("shaft", at((-L / 2 - 0.9, 0, 0.3)), 0.035, 2.2, pbr("chrome"), rot=(0, math.radians(65), yaw), seg=8)
    cyl("flagpole", at((L / 2 + 0.1, 0, 0.95)), 0.015, 0.9, pbr("railm"), seg=6)
    box("flag", at((L / 2 + 0.1, 0.0, 1.25)), (0.02, 0.4, 0.26), pbr("flag", None, "#E8B52E", rough=0.8), rot=(0, 0, yaw), bevel=0.0)


def build(gw, gh, wall_h, pct, hero):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    try:
        sc.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        pass
    sc.cycles.max_bounces = 4
    sc.cycles.diffuse_bounces = 2
    sc.cycles.glossy_bounces = 2
    sc.cycles.transparent_max_bounces = 8
    sc.render.film_transparent = False
    W, H = (gw + gh) * 128, (wall_h + (gw + gh) * 32) * 2
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.render.resolution_percentage = pct
    sc.render.image_settings.file_format = "PNG"
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    sc.view_settings.exposure = 0.15
    # world: sky HDRI
    world = bpy.data.worlds.new("W"); world.use_nodes = True
    N, L = world.node_tree.nodes, world.node_tree.links
    env = N.new("ShaderNodeTexEnvironment"); env.image = bpy.data.images.load(os.path.join(PH, "sky.hdr"))
    L.new(env.outputs[0], N["Background"].inputs[0])
    N["Background"].inputs[1].default_value = 1.0
    sc.world = world
    # sun
    sun_d = bpy.data.lights.new("Sun", "SUN"); sun_d.energy = 4.0; sun_d.angle = math.radians(2.5)
    sun_d.color = (1.0, 0.96, 0.9)
    sun = bpy.data.objects.new("Sun", sun_d); sc.collection.objects.link(sun)
    sun.rotation_euler = SUN.to_track_quat("Z", "Y").to_euler()
    # camera (same as the engine's backdrop rect)
    cam_d = bpy.data.cameras.new("Cam"); cam_d.type = "ORTHO"; cam_d.sensor_fit = "VERTICAL"
    cam_d.ortho_scale = H / PPU
    cam = bpy.data.objects.new("Cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    cx, cy = (gw - gh) * 32, ((gw + gh) * 32 - wall_h) / 2
    tgx, tgy = cx / 128 + cy / 64, cy / 64 - cx / 128
    fwd = Vector((-math.cos(ELEV) / math.sqrt(2), math.cos(ELEV) / math.sqrt(2), -math.sin(ELEV)))
    cam.location = P(tgx, tgy) - fwd * 80
    cam.rotation_euler = Euler((math.radians(90) - ELEV, 0, math.radians(45)), "XYZ")
    cam_d.clip_end = 300

    CANAL = 6.6
    ground("floor", [(-gh * CELL - 6, 1.0), ((gw + 8) * CELL, 1.0), ((gw + 8) * CELL, -CANAL * CELL), (-gh * CELL - 6, -CANAL * CELL)],
           pbr("soi", "concrete_floor_02", "#EDE7DA", 0.3, gain=1.6, nstr=0.5), uvscale=1.0)
    box("drain", P(gw / 2, 1.0, 0.003), ((gw + gh + 4) * CELL, 0.5, 0.006), pbr("asph", "asphalt_02", "#CFC9BD", 0.6, gain=1.6), bevel=0.0)
    for i in range(40):
        box("grate", P(-3 + i * 0.55, 1.0, 0.008), (0.22, 0.5, 0.004), pbr("grate", "rusty_metal_02", "#6E6C66", 1.0, metal=0.5), bevel=0.0)
    # canal
    ground("water", [(-6.0, -CANAL * CELL), ((gw + 8) * CELL, -CANAL * CELL), ((gw + 8) * CELL, -(gh + 6) * CELL), (-6.0, -(gh + 6) * CELL)],
           water_material(), z=-0.14)
    box("edge", P(gw / 2, CANAL - 0.08, 0.0), ((gw + gh + 4) * CELL, 0.26, 0.3), pbr("edge", "concrete_floor_02", "#DCD5C6", 0.5, gain=1.5), bevel=0.015)
    px = 3.2
    box("deck", P(px, CANAL + 1.6, 0.1), (1.7, 2.6, 0.1), pbr("deck", "wood_planks_dirt", "#B08A5E", 0.9), bevel=0.008)
    for (dx, dy) in ((-0.75, 0.4), (0.75, 0.4), (-0.75, 2.9), (0.75, 2.9)):
        cyl("pile", P(px + dx / CELL, CANAL + dy, -0.25), 0.09, 1.0, pbr("pile", "weathered_planks", "#5C4030", 1.0), seg=10)
    cyl("mooring", P(px + 0.95 / CELL, CANAL + 3.1, 0.35), 0.1, 1.0, pbr("pile"), seg=10)
    rnd = random.Random(5)
    for i in range(7):
        gx = rnd.uniform(0, gw); gy = rnd.uniform(CANAL + 0.4, gh + 2.5)
        for j in range(5):
            sphere("hyacinth", P(gx + rnd.uniform(-0.35, 0.35), gy + rnd.uniform(-0.35, 0.35), -0.08), 0.16, pbr("leaf", None, "#5DB54A", rough=0.6),
                   scale=(1, 1, 0.45))
    for gx in (1.0, 6.5, 9.0):
        import_model(ph("old_tyre"), P(gx, CANAL + 0.05, 0.05), yaw=0.0, height=0.62)

    zinc = pbr("zinc", "corrugated_iron_02", "#AEB4BD", scale=1.2, metal=0.5, rough=0.5)
    zinc_rust = pbr("zinc_r", "corrugated_iron_02", "#9A8E80", scale=1.2, metal=0.3, rough=0.7)
    shophouse(-1.0, 3.0, 2.6, 2, "#F2A7B8", zinc, shutter=0.0, awning="#D33A2F", seed=1)
    shophouse(3.0, 7.2, 2.6, 2, "#A8DCCB", zinc_rust, shutter=0.9, sign=(2.1, 2.6, 0.5, ("#F28C28", "#3F8A3A", "#D33A2F")), seed=0)
    shophouse(7.2, 11.6, 2.6, 3, "#F4E1A6", zinc, shutter=0.4, awning="#2F8FB5", seed=1)
    shophouse(11.6, 15.0, 2.6, 2, "#C9CFE8", zinc_rust, shutter=1.0, seed=0)
    # temple side: grass, thin wall with tiles, gate, chedi, sala, trees
    ground("grass", [(-gh * CELL - 8, -gh * CELL - 3), (-0.1, -gh * CELL - 3), (-0.1, 2.0), (-gh * CELL - 8, 2.0)],
           pbr("grass", None, "#6FAE4C", rough=0.9), z=0.001)
    wallpts = rect_pts(-0.55, -gh * CELL - 2, -0.1, 0.9)
    prism("twall", wallpts, 0, 1.5, pbr("twall", "painted_plaster_wall", "#F1E8D8", 0.5), bevel=0.015)
    box("wallcap", Vector((-0.33, (-gh * CELL - 2 + 0.9) / 2, 1.55)), (0.6, gh * CELL + 2.9 + 0.2, 0.12), pbr("gold", None, "#D9A44A", rough=0.35, metal=0.6), bevel=0.015)
    for i in range(9):
        box("wtile", Vector((-0.3, -0.8 - i * 0.85, 0.85)), (0.08, 0.5, 0.5), pbr("tile_red", None, "#E35C3F", rough=0.6), bevel=0.0)
    box("gate", Vector((-0.3, -4.4, 0.8)), (0.5, 1.5, 1.6), pbr("gatew", "weathered_planks", "#8A5D36", 1.0), bevel=0.015)
    box("gatehead", Vector((-0.4, -4.4, 1.95)), (0.7, 2.1, 0.4), pbr("gold"), bevel=0.02)
    cyl("gable", Vector((-0.4, -4.4, 2.5)), 0.9, 0.7, pbr("tile_red"), seg=4, r2=0.0)
    white = pbr("chedi", "painted_plaster_wall", "#F7F3EA", 0.4)
    cyl("chedi", Vector((-3.4, 1.2, 0.8)), 1.3, 1.6, white, seg=24, r2=1.0)
    cyl("chedi2", Vector((-3.4, 1.2, 2.5)), 0.95, 2.0, white, seg=24, r2=0.55)
    cyl("chedi3", Vector((-3.4, 1.2, 4.5)), 0.5, 2.6, pbr("gold"), seg=16, r2=0.0)
    cyl("chedi4", Vector((-3.4, 1.2, 5.9)), 0.12, 0.8, pbr("gold"), seg=8, r2=0.0)
    box("sala", Vector((-4.2, -4.2, 1.3)), (2.6, 2.6, 2.6), pbr("salaw", "weathered_planks", "#C9B48E", 1.0), bevel=0.015)
    cyl("salaroof", Vector((-4.2, -4.2, 3.2)), 2.2, 1.6, pbr("tile_red"), rot=(0, 0, math.radians(45)), seg=4, r2=0.2)
    import_model(ph("jacaranda_tree"), P(-2.6, 5.4), yaw=0.4, height=6.5)
    import_model(ph("island_tree_01"), P(-3.0, 1.2), yaw=1.2, height=5.0)
    # poles and the wire tangle
    a = power_pole(2.2, 4.4)
    b = power_pole(9.3, 3.9)
    for dz in (0.0, -0.25, -0.5):
        wire(a + Vector((0, 0, dz)), b + Vector((0, 0, dz)), sag=0.5 + 0.1 * abs(dz))
    wire(a + Vector((0, 0, -0.1)), Vector((0.4, -0.2, 4.6)), sag=0.3)
    wire(b + Vector((0, 0, -0.1)), Vector((8.4, -0.2, 4.7)), sag=0.3)
    wire(b + Vector((0, 0, -0.4)), Vector((12.5, -0.2, 4.4)), sag=0.3)
    wire(a + Vector((0, 0, -0.3)), Vector((-0.3, -3.2, 2.4)), sag=0.2)
    # street life
    food_cart(6.2, 4.3, math.radians(-30))
    for (x, y) in ((5.2, 5.2), (6.0, 5.6), (7.1, 5.5), (7.6, 4.9)):
        import_model(ph("plastic_monobloc_chair_01"), P(x, y), yaw=rnd.uniform(0, 6.28), height=0.8)
    import_model(ph("outdoor_table_chair_set_01"), P(8.6, 5.4), yaw=0.3, height=0.78)
    for (x, y, c, yaw) in ((9.4, 2.0, "#D33A2F", math.radians(70)), (10.9, 2.6, "#2F6DB5", math.radians(74))):
        motorbike(x, y, c, yaw)
    import_model(ph("potted_plant_01"), P(0.6, 1.4), yaw=0.2, height=1.1)
    import_model(ph("potted_plant_02"), P(1.4, 1.1), yaw=1.0, height=0.9)
    import_model(ph("planter_pot_clay"), P(8.0, 1.3), yaw=0.0, height=0.5)
    import_model(ph("potted_plant_01"), P(3.4, 1.2), yaw=2.0, height=0.8)
    import_model(ph("plastic_crate_01"), P(4.3, 1.5), yaw=0.3, height=0.32)
    import_model(ph("plastic_crate_01"), P(4.3, 1.5, 0.32), yaw=0.5, height=0.32)
    import_model(ph("wooden_crate_01"), P(1.9, 1.7), yaw=0.2, height=0.5)
    import_model(ph("trashbag"), P(4.9, 1.3), yaw=0.0, height=0.55)
    import_model(ph("cardboard_box_01"), P(2.6, 1.3), yaw=0.6, height=0.4)
    import_model(ph("wicker_basket_01"), P(5.1, 4.9), yaw=0.0, height=0.35)
    import_model(ph("street_lamp_01"), P(11.6, 4.6), yaw=math.radians(45), height=4.2)
    import_model(ph("utility_box_01"), P(0.2, 3.0), yaw=math.radians(90), height=1.2)
    for i in range(2):
        cyl("gas", P(11.0, 1.2 + i * 0.4, 0.4), 0.17, 0.8, pbr("gasm", "rusty_metal_02", "#D9A44A", 1.0, metal=0.4), seg=16)
    import_model(KAY + "car_hatchback.gltf", P(11.6, 5.7), yaw=math.radians(-20), height=1.45)
    longtail(2.8, 8.1, math.radians(12))
    longtail(9.5, 8.6, math.radians(-8), hull="#C9372C")
    if hero:
        warrior(P(8.3, 3.8), math.radians(45))
    return sc


# ---------------------------------------------------------------------------
# the hero: a fantasy warlord (Quaternius base + ranger kit, big head), lit by the same sun
# ---------------------------------------------------------------------------
def pbr_img(key, image, tint="#FFFFFF", rough=0.55):
    """Principled with a UV-mapped image (the Quaternius skin texture), tinted."""
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    b = N["Principled BSDF"]
    b.inputs["Roughness"].default_value = rough
    t = N.new("ShaderNodeTexImage"); t.image = image
    mix = N.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"; mix.inputs[0].default_value = 1.0
    L.new(t.outputs["Color"], mix.inputs[6]); mix.inputs[7].default_value = srgb(tint)
    L.new(mix.outputs[2], b.inputs["Base Color"])
    MATS[key] = m
    return m


def clear_material():
    m = bpy.data.materials.new("Clear")
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    N.clear()
    out = N.new("ShaderNodeOutputMaterial")
    tr = N.new("ShaderNodeBsdfTransparent")
    L.new(tr.outputs[0], out.inputs["Surface"])
    return m


def warrior(loc, yaw):
    """A fantasy warlord: Quaternius base body in a dark undersuit, with armour built as
    pieces on top (cuirass from char_q's vest(), pauldrons, belt, tassets, greaves,
    gauntlets, cape, open helmet with crest and horns), sword in hand, banner on the back."""
    ns = {"__name__": "charq", "__file__": os.path.join(HERE, "char_q.py")}
    src = open(os.path.join(HERE, "char_q.py")).read()
    src = src[:src.rindex("\nmain()")]
    argv = sys.argv; sys.argv = ["x", "rider", "/tmp/_"]
    exec(compile(src, "char_q.py", "exec"), ns)
    sys.argv = argv
    objs = ns["import_gltf"](ns["BASE"] + "Superhero_Male_FullBody.gltf")
    arm = [o for o in objs if o.type == "ARMATURE"][0]
    arm.rotation_mode = "XYZ"
    body = [o for o in objs if o.type == "MESH" and o.name.lower().startswith("superhero")][0]
    ns["BODY"] = body
    ns["SKIN_TONE"] = "#E8B98C"
    skin_path = ns["UBC"] + "/Base Characters/Textures/T_Superhero_Male_Ligh.png"
    ns["LIGHT_SKIN"][body.name[:20]] = skin_path
    ns["PAL"] = {"cloth": ("#2E3147", 0.3, 0.0), "glove": ("#3A2E26", 0.3, 0.0)}

    def region(bone, p):
        if bone in ("Head", "neck_01"):
            return "skin"
        if bone.startswith(("hand", "index", "middle", "ring", "pinky", "thumb")):
            return "glove"
        return "cloth"
    ns["paint_regions"](body, region)
    skin_img = bpy.data.images.load(skin_path)
    steel = pbr("steel"); gold = pbr("gold"); red = pbr("cape", None, "#B8262B", rough=0.85)
    leather = pbr("leather", None, "#4A3A2E", rough=0.7); dark = pbr("darkcloth", None, "#2E3147", rough=0.8)
    for i, m in enumerate(body.data.materials):
        n = m.name
        body.data.materials[i] = pbr_img("skin_pbr", skin_img, "#F2CFAE") if n.startswith("skin") else (leather if n.startswith("glove") else dark)
    for o in ns["rebind"](ns["import_gltf"](ns["HAIR"] + "Hair_SimpleParted.gltf"), arm):
        for i in range(len(o.data.materials)):
            o.data.materials[i] = pbr("hair", None, "#2A2224", rough=0.6)
    for o in ns["rebind"](ns["import_gltf"](ns["OUTF"] + "Male_Ranger_Feet_Boots.gltf"), arm):
        for i in range(len(o.data.materials)):
            o.data.materials[i] = leather
    HS = 1.7
    arm.pose.bones["Head"].scale = (HS, HS, HS)
    ns["pose_frame"](arm, "idle", 0.0)
    bpy.context.view_layer.update()

    KEY = {"steel": steel, "gold": gold, "red": red, "leather": leather, "cloth": dark}

    class PB(ns["Builder"]):
        def mat(self, key):
            return KEY[key]
    B = PB({})
    B.ink = clear_material()
    bw = ns["bone_world"]
    # cuirass + gorget (char_q's vest: front/back plates on the torso only + a yoke to the collar)
    ns["vest"](B, body, arm, "steel", z0=1.02)
    # pauldrons on the shoulder joints
    for sfx in ("l", "r"):
        sh = bw(arm, "upperarm_" + sfx)
        B.sphere("Pauldron", sh + Vector((0, 0, 0.03)), 0.1, "gold", "upperarm_" + sfx, scale=(1.2, 1.0, 0.85), cut=-0.15, ink=0)
        B.torus("PauldronRim", sh + Vector((0, 0, 0.0)), 0.1, 0.014, "steel", "upperarm_" + sfx, scale=(1.2, 1.0, 1.0), ink=0)
    # belt + buckle, cloth tassets with a steel plate in front
    pv = bw(arm, "pelvis")
    B.torus("Belt", pv + Vector((0, 0, 0.06)), 0.165, 0.028, "leather", "pelvis", scale=(1.0, 0.74, 1.0), ink=0)
    B.box("Buckle", pv + Vector((0, -0.135, 0.06)), (0.08, 0.025, 0.07), "gold", "pelvis", bevel=0.006, ink=0)
    ns["garment"](B, body, "SkirtF", "red", "pelvis", 0.70, 1.0, arc=170, pad=0.04, flare=0.1, center=-90, ink=0)
    ns["garment"](B, body, "SkirtB", "red", "pelvis", 0.70, 1.0, arc=170, pad=0.04, flare=0.1, center=90, ink=0)
    ns["garment"](B, body, "Tasset", "steel", "pelvis", 0.76, 0.99, arc=70, pad=0.055, flare=0.06, center=-90, ink=0)
    # greaves and gauntlets along the bones (rest pose: legs vertical, arms along X)
    for sfx in ("l", "r"):
        c0, c1 = bw(arm, "calf_" + sfx), bw(arm, "calf_" + sfx, tail=True)
        mid = (c0 + c1) / 2
        B.cyl("Greave", mid + Vector((0, -0.012, 0)), 0.078, (c0 - c1).length * 0.8, "steel", "calf_" + sfx, seg=18, ink=0, r2=0.062)
        a0, a1 = bw(arm, "lowerarm_" + sfx), bw(arm, "lowerarm_" + sfx, tail=True)
        B.cyl("Gauntlet", a0 * 0.35 + a1 * 0.65, 0.062, (a0 - a1).length * 0.6, "steel", "lowerarm_" + sfx,
              rot=(0, math.radians(90), 0), seg=18, ink=0, r2=0.05)
    # cape from the shoulders to the knees
    armz = bw(arm, "upperarm_l").z
    ns["garment"](B, body, "Cape", "red", "spine_03", 0.5, armz - 0.01, arc=150, pad=0.05, flare=0.3, center=90, ink=0)
    # open helmet with a brim, a crest and two horns (on the neck so it keeps its own size)
    head = bw(arm, "Head")
    hc = head + Vector((0, 0.01, 0.12 * HS))
    r = 0.115 * HS
    B.sphere("Helm", hc + Vector((0, 0, 0.01)), r, "steel", "neck_01", scale=(1.0, 1.06, 1.0), cut=-0.15, ink=0)
    B.cyl("Brim", hc + Vector((0, 0, -0.01)), r + 0.012, 0.03, "gold", "neck_01", seg=24, ink=0)
    B.sphere("Plume", hc + Vector((0, 0.03, r + 0.07)), 0.07, "red", "neck_01", scale=(0.5, 1.9, 1.3), ink=0)
    B.sphere("Plume2", hc + Vector((0, 0.13, r + 0.02)), 0.05, "red", "neck_01", scale=(0.5, 1.6, 1.0), ink=0)
    for sx in (-1, 1):
        B.cyl("Horn", hc + Vector((sx * (r + 0.01), 0.0, r * 0.5)), 0.04, 0.34, "gold", "neck_01", rot=(0, sx * math.radians(-45), 0), seg=10, ink=0, r2=0.0)
    # banner on the back, sword in the right hand (T-pose hand frame, blade along -X like char_q's wrench)
    sp = bw(arm, "spine_03")
    B.cyl("Pole", sp + Vector((-0.1, 0.16, 0.6)), 0.015, 2.0, "leather", "spine_03", seg=8, ink=0)
    B.box("Banner", sp + Vector((-0.1, 0.16, 1.1)), (0.012, 0.36, 0.75), "red", "spine_03", bevel=0, ink=0)
    B.box("BannerMark", sp + Vector((-0.1, 0.16, 1.2)), (0.014, 0.22, 0.22), "gold", "spine_03", bevel=0, ink=0)
    hR = bw(arm, "hand_r")
    B.box("Blade", hR + Vector((-0.62, -0.02, 0)), (0.95, 0.012, 0.075), "steel", "hand_r", bevel=0.003, ink=0)
    B.box("Guard", hR + Vector((-0.14, -0.02, 0)), (0.04, 0.05, 0.3), "gold", "hand_r", bevel=0.005, ink=0)
    B.cyl("Grip", hR + Vector((0.02, -0.02, 0)), 0.02, 0.26, "leather", "hand_r", rot=(0, math.radians(90), 0), seg=10, ink=0)
    ns["attach_rigid"](B.parts, arm)
    arm.location = loc
    arm.rotation_euler = (0, 0, yaw)
    bpy.context.view_layer.update()
    return arm


def main():
    out = sys.argv[1]
    pct = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 100
    sc = build(12, 9, 520, pct, "--hero" in sys.argv)
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("rendered", out)


if __name__ == "__main__":
    main()
