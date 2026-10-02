"""Characters from the Quaternius CC0 kits (Universal Base Characters +
Modular Character Outfits), dressed for 25d and rendered with our toon/ink
shader to 8-direction sprite sheets (same output contract as char3d.py).

Run: python3 char_q.py <rider|lung_pradit|je_muay|npc id from NPCS> <out_dir> [--still]
"""
import sys, os, math, json
sys_argv = list(sys.argv)
sys.argv = ["x", "rider", "/tmp/_"]
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "char3d.py")).read().split("if __name__")[0])
sys.argv = sys_argv
from mathutils import Matrix, Vector, Quaternion, Euler

Q = os.environ.get("QDIR", "/tmp/claude-0/-home-claude/3651b142-77c0-5d4d-9e39-ab1b296efb83/scratchpad/q")
UBC = Q + "/ubc/Universal Base Characters[Standard]"
BASE = UBC + "/Base Characters/Godot - UE/"
HAIR = UBC + "/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/"
OUTF = Q + "/Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Modular Parts/"


def import_gltf(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in list(new):
        if o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o)
            new.remove(o)
    return new


def rebind(objs, arm):
    """Move imported meshes onto our armature and drop their own armature."""
    for o in objs:
        if o.type == "MESH":
            mw = o.matrix_world.copy()
            o.parent = arm
            o.matrix_world = mw
            for m in o.modifiers:
                if m.type == "ARMATURE":
                    m.object = arm
    meshes = [o for o in objs if o.type == "MESH"]
    for o in objs:
        if o.type == "ARMATURE" and o != arm:
            bpy.data.objects.remove(o)
    return meshes


def tex_of(mat):
    if mat and mat.use_nodes:
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and "Normal" not in n.image.name and "Rough" not in n.image.name and "ORM" not in n.image.name:
                return n.image
    return None


def toon_tex(name, img, tint="#FFFFFF", rim=0.35, spec=0.0, skin=None):
    m = toon_material(name, tint, rim=rim, spec=spec, term=0.24 if skin else 0.40,
                      shadow=(0.66, 0.46, 0.42) if skin else None)
    if img is not None:
        N, L = m.node_tree.nodes, m.node_tree.links
        t = N.new("ShaderNodeTexImage")
        t.image = img
        if skin is not None:
            # keep the texture's detail (brows, lips, shading) but re-tone it:
            # luminance of the texture x target skin colour
            bw = N.new("ShaderNodeRGBToBW")
            L.new(t.outputs[0], bw.inputs[0])
            lift = N.new("ShaderNodeMapRange")
            lift.inputs["From Min"].default_value = 0.0
            lift.inputs["From Max"].default_value = 0.42
            lift.inputs["To Min"].default_value = 0.0
            lift.inputs["To Max"].default_value = 1.0
            L.new(bw.outputs[0], lift.inputs["Value"])
            sk = N.new("ShaderNodeMix"); sk.data_type = "RGBA"; sk.blend_type = "MULTIPLY"; sk.inputs[0].default_value = 1.0
            sk.inputs[6].default_value = srgb(skin)
            L.new(lift.outputs["Result"], sk.inputs[7])
            mix = [n for n in N if n.type == "MIX" and n.blend_type == "MULTIPLY" and n is not sk][0]
            L.new(sk.outputs[2], mix.inputs[6])
            return m
        mix = [n for n in N if n.type == "MIX" and n.blend_type == "MULTIPLY"][0]
        tm = N.new("ShaderNodeMix"); tm.data_type = "RGBA"; tm.blend_type = "MULTIPLY"; tm.inputs[0].default_value = 1.0
        tm.inputs[7].default_value = srgb(tint)
        L.new(t.outputs[0], tm.inputs[6])
        L.new(tm.outputs[2], mix.inputs[6])
    return m


def add_ink(o, thickness=0.009):
    n = len(o.data.materials)
    o.data.materials.append(INK)
    sol = o.modifiers.new("ink", "SOLIDIFY")
    sol.thickness = thickness; sol.offset = 1.0; sol.use_flip_normals = True
    sol.material_offset = n; sol.use_rim = False


def toonify(o, tint="#FFFFFF", rim=0.35):
    for i, m in enumerate(o.data.materials):
        o.data.materials[i] = toon_tex("T_" + o.name + str(i), tex_of(m), tint, rim)
    add_ink(o)


def make_overlay(body, keys_over, under_key, offset=0.014):
    """Lift the faces painted as `keys_over` into their own garment shell
    (thicker, own ink outline); the body underneath gets `under_key`."""
    names = [m.name.split("_" + body.name)[0] for m in body.data.materials]
    over_idx = {i for i, n in enumerate(names) if n in keys_over}
    if not over_idx:
        return None
    ob = body.copy()
    ob.data = body.data.copy()
    ob.name = body.name + "_" + "_".join(keys_over)
    bpy.context.scene.collection.objects.link(ob)
    import bmesh as _bm
    bm = _bm.new(); bm.from_mesh(ob.data)
    _bm.ops.delete(bm, geom=[f for f in bm.faces if f.material_index not in over_idx], context="FACES")
    bm.to_mesh(ob.data); bm.free()
    disp = ob.modifiers.new("lift", "DISPLACE")
    disp.strength = offset
    disp.mid_level = 0.0
    ob.modifiers.move(ob.modifiers.find("lift"), 0)
    # cloth hides the muscles: relax the surface before lifting it
    sm = ob.modifiers.new("relax", "SMOOTH")
    sm.factor = 0.9
    sm.iterations = 12
    ob.modifiers.move(ob.modifiers.find("relax"), 0)
    # body: overlay faces take the under colour
    if under_key not in names:
        hexcol, rim, spec = PAL[under_key]
        body.data.materials.append(toon_material(under_key + "_" + body.name, hexcol, rim=rim, spec=spec, term=0.22))
        names.append(under_key)
        # keep the ink material last for the solidify offset
        ink_i = [i for i, m in enumerate(body.data.materials) if m.name.startswith("Ink")]
    u = names.index(under_key)
    for p in body.data.polygons:
        if p.material_index in over_idx:
            p.material_index = u
    return ob


def body_section(body, z, band=0.02):
    """Half-extents (x, front y, back y) of the rest-pose body around height z."""
    xs, ys = [], []
    mw = body.matrix_world
    for v in body.data.vertices:
        w = mw @ v.co
        if abs(w.z - z) < band and abs(w.x) < 0.3:
            xs.append(abs(w.x)); ys.append(w.y)
    return (max(xs), min(ys), max(ys)) if xs else (0.15, -0.12, 0.12)


def garment(B, body, name, key, bone, z0, z1, arc=150, pad=0.025, flare=0.0, ink=0.007):
    """Curved cloth panel wrapping the front of the body between heights z0..z1
    (z1 top). Shape follows the body section at each ring; flare widens the hem."""
    import bmesh as _bm
    me = bpy.data.meshes.new(name)
    bm = _bm.new()
    rings = 8
    seg = 16
    grid = []
    for i in range(rings + 1):
        t = i / rings
        z = z1 + (z0 - z1) * t
        hx, fy, by = body_section(body, z)
        cy = (fy + by) / 2
        rx = hx + pad + flare * t
        ry = (by - fy) / 2 + pad + flare * t * 0.6
        row = []
        for j in range(seg + 1):
            a = math.radians(-90 - arc / 2 + arc * j / seg)
            row.append(bm.verts.new((math.cos(a) * rx, cy + math.sin(a) * ry, z)))
        grid.append(row)
    for i in range(rings):
        for j in range(seg):
            bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
    _bm.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me); bm.free()
    obj = B.link(name, me)
    sol = obj.modifiers.new("thick", "SOLIDIFY"); sol.thickness = 0.008; sol.offset = 0
    return B.finish_obj(obj, key, bone, ink)


def full_face_helmet(B, c, r):
    """Full-face shell with a face window, chin bar, visor flipped up, brass pivots."""
    import bmesh as _bm

    def shell(name, rr, keep, key, ink=0.008, thick=0.012):
        me = bpy.data.meshes.new(name)
        bm = _bm.new()
        _bm.ops.create_uvsphere(bm, u_segments=32, v_segments=18, radius=rr)
        dead = []
        for f in bm.faces:
            d = f.calc_center_median().normalized()
            if not keep(d):
                dead.append(f)
        _bm.ops.delete(bm, geom=dead, context="FACES")
        bm.to_mesh(me); bm.free()
        o = B.link(name, me)
        o.location, o.scale = c, (1.0, 1.1, 1.08)
        if thick:
            so = o.modifiers.new("thick", "SOLIDIFY"); so.thickness = thick; so.offset = -1
        return B.finish_obj(o, key, "Head", ink)

    # shell: everything except the face window and the neck hole
    shell("Helmet", r, lambda d: not (d.y < -0.42 and -0.42 < d.z < 0.34) and d.z > -0.8, "helmet")
    # visor flipped up over the forehead
    shell("Visor", r * 1.07, lambda d: d.y < -0.25 and 0.3 < d.z < 0.72 and abs(d.x) < 0.8, "visor", thick=0.006)
    # orange racing stripe over the crown
    shell("Stripe", r * 1.01, lambda d: abs(d.x) < 0.16 and d.z > 0.1, "jacket", ink=0.004, thick=0.003)
    for sx in (1, -1):
        B.cyl("Pivot", c + Vector((sx * r * 1.02, -0.02, 0.05)), 0.024, 0.012, "brass", "Head", rot=(0, math.radians(90), 0), ink=0.004)


def delivery_box(B, arm):
    """Big insulated food box worn as a backpack: teal box, orange lid band,
    reflective strip, brass corners, a little steam chimney + gauge (keeps food hot)."""
    chest = bone_world(arm, "spine_03")
    hx, fy, by = body_section(BODY, chest.z - 0.05)
    c = Vector((0, by + 0.17, chest.z - 0.06))
    W, D, H = 0.46, 0.3, 0.46
    B.box("Box", c, (W, D, H), "box", "spine_03", bevel=0.025, ink=0.009)
    B.box("Lid", c + Vector((0, 0, H / 2 - 0.045)), (W + 0.012, D + 0.012, 0.09), "box_lid", "spine_03", bevel=0.02, ink=0.006)
    B.box("BoxStrip", c + Vector((0, 0, -0.06)), (W + 0.008, D + 0.008, 0.035), "reflect", "spine_03", bevel=0.006, ink=0.0)
    for sx in (1, -1):
        for sz in (1, -1):
            B.box("Corner", c + Vector((sx * (W / 2 - 0.01), D / 2 - 0.01, sz * (H / 2 - 0.01))), (0.05, 0.05, 0.05), "brass", "spine_03", bevel=0.01, ink=0.004)
        # shoulder straps
        B.box("Strap", Vector((sx * 0.155, fy + 0.0, chest.z + 0.07)), (0.045, 0.018, 0.36), "belt", "spine_03", rot=(math.radians(-8), 0, 0), bevel=0.006, ink=0.005)
    ch = c + Vector((W / 2 - 0.08, 0.04, H / 2))
    B.cyl("Chimney", ch + Vector((0, 0, 0.06)), 0.022, 0.12, "brass", "spine_03", ink=0.005)
    B.cyl("ChimCap", ch + Vector((0, 0, 0.125)), 0.034, 0.02, "steel", "spine_03", ink=0.004)
    B.cyl("BoxGauge", c + Vector((W / 2 + 0.008, 0.02, 0.06)), 0.045, 0.02, "brass", "spine_03", rot=(0, math.radians(90), 0))
    B.cyl("BoxGaugeFace", c + Vector((W / 2 + 0.02, 0.02, 0.06)), 0.034, 0.006, "eye_white", "spine_03", rot=(0, math.radians(90), 0), ink=0.0)


def finish_body(body, overlays):
    for keys_over, under in overlays:
        ob = make_overlay(body, keys_over, under)
        if ob is not None:
            # the copy inherited the body's ink-less material list; give it its own ink
            add_ink(ob, 0.008)
    add_ink(body, 0.010)


def trim_above(o, zmax):
    """Cut a boot down to a low shoe: drop faces above zmax (world, rest pose)."""
    import bmesh as _bm
    mw = o.matrix_world
    bm = _bm.new(); bm.from_mesh(o.data)
    _bm.ops.delete(bm, geom=[f for f in bm.faces if (mw @ f.calc_center_median()).z > zmax], context="FACES")
    bm.to_mesh(o.data); bm.free()


def dominant_bone(o, v):
    best, bw = None, 0.0
    for g in v.groups:
        if g.weight > bw:
            best, bw = o.vertex_groups[g.group].name, g.weight
    return best


def paint_regions(o, region_fn, keep_tex_regions=("skin",)):
    """Split the base body into flat-colour toon materials by bone + height."""
    img = tex_of(o.data.materials[0])
    if LIGHT_SKIN.get(o.name[:20]):
        img = bpy.data.images.load(LIGHT_SKIN[o.name[:20]])
    import bmesh as _bm
    bm = _bm.new(); bm.from_mesh(o.data)
    _bm.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    bm.to_mesh(o.data); bm.free()
    keys = []
    face_key = []
    for p in o.data.polygons:
        names = [dominant_bone(o, o.data.vertices[i]) for i in p.vertices]
        bone = max(set(names), key=names.count)
        k = region_fn(bone, Vector(p.center))
        face_key.append(k)
        if k not in keys:
            keys.append(k)
    if "hide" in keys:
        import bmesh as _bm
        bm = _bm.new(); bm.from_mesh(o.data)
        bm.faces.ensure_lookup_table()
        _bm.ops.delete(bm, geom=[bm.faces[i] for i, k in enumerate(face_key) if k == "hide"], context="FACES")
        bm.to_mesh(o.data); bm.free()
        face_key = [k for k in face_key if k != "hide"]
        keys.remove("hide")
    o.data.materials.clear()
    for k in keys:
        if k in keep_tex_regions:
            o.data.materials.append(toon_tex("skin_" + o.name, img, "#FFFFFF", 0.35, skin=SKIN_TONE))
        else:
            hexcol, rim, spec = PAL[k]
            o.data.materials.append(toon_material(k + "_" + o.name, hexcol, rim=rim, spec=spec, term=0.22))
    for p, k in zip(o.data.polygons, face_key):
        p.material_index = keys.index(k)
        p.use_smooth = True


# ---------------------------------------------------------------------------
# posing in armature space (robust to bone rolls)
# ---------------------------------------------------------------------------

def arm_axis(arm, world_vec):
    return (arm.matrix_world.inverted().to_3x3() @ Vector(world_vec)).normalized()


def rot_bone(arm, name, world_axis, deg):
    """Rotate a pose bone about a world axis through its head."""
    pb = arm.pose.bones[name]
    bpy.context.view_layer.update()
    M = pb.matrix.copy()
    head = M.to_translation()
    R = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, arm_axis(arm, world_axis)) @ Matrix.Translation(-head)
    pb.matrix = R @ M
    bpy.context.view_layer.update()


def aim_bone(arm, name, world_dir):
    pb = arm.pose.bones[name]
    bpy.context.view_layer.update()
    M = pb.matrix.copy()
    cur = (M.to_3x3() @ Vector((0, 1, 0))).normalized()
    tgt = arm_axis(arm, world_dir)
    q = cur.rotation_difference(tgt)
    head = M.to_translation()
    pb.matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ M
    bpy.context.view_layer.update()


ORDER = ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
         "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r",
         "thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r"]
FINGER_SIGN = float(os.environ.get('FSIGN', '1'))
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)   # model faces -Y; its left is +X
WAI_IN = 0.45  # how far the forearms turn in for the wai (wider shoulders = more)
RIDE_DROP = float(os.environ.get("RIDE_DROP", "-0.3"))
## The rider's extra animation: sitting on the bike (BoatRide).
RIDE = (4, 8)
## Special moments get their own move (owner 2026-10-02): extra animations per character.
EXTRA_ANIMS = {
    # the endings (Main.ENDING_SCENES)
    "rider": {"ride": (4, 8), "cheer": (8, 10), "shrug": (6, 6), "sit_sad": (6, 4), "phone": (6, 5)},
    "nuad": {"dance": (8, 8)},        # พี่หนวด dancing to the steam radio
    "jum": {"shout": (6, 8)},         # ป้าจุ๋ม waking the soi with the megaphone
    "pa_nok": {"wai": (6, 5)},        # the wedding on the noodle boat
    "lung_table3": {"wai": (6, 5)},
}


def base_pose(arm, akimbo=False, weapon=False):
    """T-pose -> relaxed A-pose with a light contrapposto."""
    for pb in arm.pose.bones:
        keep = pb.scale.copy()
        pb.matrix_basis = Matrix.Identity(4)
        pb.scale = keep
    bpy.context.view_layer.update()
    for s, sx in (("l", 1), ("r", -1)):
        aim_bone(arm, "upperarm_" + s, (sx * 0.22, 0.04, -1))
        aim_bone(arm, "lowerarm_" + s, (sx * 0.12, -0.18, -1))
        aim_bone(arm, "hand_" + s, (sx * 0.08, -0.12, -1))
        # curl fingers into a loose fist
        for f in ("index", "middle", "ring", "pinky"):
            for k, a in ((1, 45), (2, 55), (3, 35)):
                pb = arm.pose.bones["%s_0%d_%s" % (f, k, s)]
                pb.rotation_mode = "QUATERNION"
                pb.rotation_quaternion = Quaternion(Vector((0, 0, 1)), math.radians(FINGER_SIGN * a))
        bpy.context.view_layer.update()
    if akimbo:
        aim_bone(arm, "upperarm_r", (-0.75, 0.2, -0.65))
        aim_bone(arm, "lowerarm_r", (0.55, -0.05, -0.8))


def pose_frame(arm, kind, t, weapon=False, akimbo=False, hunch=False):
    base_pose(arm, akimbo=akimbo)
    if hunch:
        rot_bone(arm, "spine_02", X, -10)
        rot_bone(arm, "neck_01", X, 8)
    s = math.sin(2 * math.pi * t)
    c = math.cos(2 * math.pi * t)
    bob = 0.0
    if kind == "idle":
        b = math.sin(2 * math.pi * t)
        rot_bone(arm, "pelvis", Y, 4)          # hip drop toward the relaxed leg
        rot_bone(arm, "spine_02", Y, -6)
        rot_bone(arm, "spine_03", X, 1.5 * b)
        rot_bone(arm, "Head", Y, 5)
        rot_bone(arm, "thigh_l", X, -8)
        rot_bone(arm, "calf_l", X, 14)
        rot_bone(arm, "upperarm_l", X, -2 * b)
        if weapon:
            rot_bone(arm, "lowerarm_r", X, -12)
        bob = -0.004 * (1 - b)
    elif kind == "walk":
        sw = 26 * s
        rot_bone(arm, "thigh_l", X, -sw)
        rot_bone(arm, "thigh_r", X, sw)
        rot_bone(arm, "calf_l", X, max(0, 38 * math.sin(2 * math.pi * t + 1.3)))
        rot_bone(arm, "calf_r", X, max(0, -38 * math.sin(2 * math.pi * t + 1.3)))
        rot_bone(arm, "upperarm_l", X, sw * 0.8)
        rot_bone(arm, "upperarm_r", X, -sw * (0.4 if weapon else 0.8))
        rot_bone(arm, "lowerarm_l", X, -15)
        rot_bone(arm, "lowerarm_r", X, -18)
        rot_bone(arm, "spine_01", X, -5)
        rot_bone(arm, "spine_02", Z, 5 * s)
        bob = -0.022 * abs(c)
    elif kind == "dance":
        # รำวงลูกทุ่ง, 4th take (owner: "swinging from the hips while the hands and
        # shoulders stay fixed" - the hips and the spine were counter-rotating).
        # Now the WHOLE upper body leans side to side with the beat, the shoulders
        # bounce, and the hands swap: one up by the face, the other down by the hip.
        # Feet stay flat; the knees dip together twice a loop.
        ground = feet_z(arm)
        sway = math.sin(2 * math.pi * t)
        dip = 0.5 - 0.5 * math.cos(4 * math.pi * t)
        rot_bone(arm, "pelvis", Y, 5 * sway)
        rot_bone(arm, "spine_01", Y, 5 * sway)
        rot_bone(arm, "spine_02", Y, 6 * sway)
        rot_bone(arm, "spine_03", Z, 12 * sway)
        rot_bone(arm, "spine_03", X, -4 * dip)
        rot_bone(arm, "Head", Y, -5 * sway)
        for sx, side in ((1, "l"), (-1, "r")):
            hi = 0.5 + 0.5 * sway * sx  # 1 = this hand up by the face
            aim_bone(arm, "upperarm_" + side, (sx * (0.4 + 0.25 * hi), -0.35 - 0.1 * hi, -0.9 + 1.0 * hi))
            aim_bone(arm, "lowerarm_" + side, (sx * (0.35 - 0.2 * hi), -0.85 + 0.5 * hi, 0.05 + 0.95 * hi))
            aim_bone(arm, "hand_" + side, (sx * (0.6 - 0.4 * hi), 0.1, 0.6 + 0.4 * hi))
        open_hands(arm)
        for side in ("l", "r"):
            rot_bone(arm, "thigh_" + side, X, -12 * dip)
            rot_bone(arm, "calf_" + side, X, 24 * dip)
            rot_bone(arm, "foot_" + side, X, -12 * dip)
        bob = ground - feet_z(arm)
    elif kind == "cheer":
        # ไรเดอร์ห้าดาว: jumping with both arms up (wrench and all)
        ground = feet_z(arm)
        hop = max(0.0, s)
        for sx, side in ((1, "l"), (-1, "r")):
            aim_bone(arm, "upperarm_" + side, (sx * 0.4, -0.1, 0.9))
            aim_bone(arm, "lowerarm_" + side, (sx * (0.15 + 0.1 * c), -0.1, 1.0))
        open_hands(arm)
        rot_bone(arm, "Head", X, -10)
        for side in ("l", "r"):
            rot_bone(arm, "thigh_" + side, X, -14 * (1 - hop))
            rot_bone(arm, "calf_" + side, X, 26 * (1 - hop) + 10 * hop)
        bob = ground - feet_z(arm) + 0.09 * hop
    elif kind == "shrug":
        # รอดแบบเปียก: soaked, palms up, laughing it off
        rot_bone(arm, "Head", Y, 8 * s)
        rot_bone(arm, "Head", X, -5)
        rot_bone(arm, "spine_03", X, -3 * abs(s))
        for sx, side in ((1, "l"), (-1, "r")):
            aim_bone(arm, "upperarm_" + side, (sx * 0.5, -0.2, -0.85 + 0.1 * abs(s)))
            aim_bone(arm, "lowerarm_" + side, (sx * 0.5, -0.8, 0.45 + 0.1 * abs(s)))
            aim_bone(arm, "hand_" + side, (sx * 0.9, -0.3, 0.35))
        open_hands(arm)
    elif kind == "sit_sad":
        # ซอยจมทั้งคืน: sitting on a roof, hugging the knees, head down
        for sx, side in ((1, "l"), (-1, "r")):
            aim_bone(arm, "thigh_" + side, (sx * 0.15, -0.8, 0.55))
            aim_bone(arm, "calf_" + side, (sx * 0.05, 0.25, -1.0))
            aim_bone(arm, "foot_" + side, (0, -1.0, -0.1))
            aim_bone(arm, "upperarm_" + side, (sx * 0.25, -0.65, -0.5))
            aim_bone(arm, "lowerarm_" + side, (-sx * 0.75, -0.45, 0.25))
        rot_bone(arm, "spine_01", X, -14)
        rot_bone(arm, "spine_02", X, -10 - 2 * s)
        rot_bone(arm, "Head", X, 22)
        bpy.context.view_layer.update()
        bob = 0.16 - arm.pose.bones["pelvis"].head.z
    elif kind == "phone":
        # ขายกล่อง: alone, staring at five stars on the phone
        rot_bone(arm, "Head", X, 18)
        rot_bone(arm, "spine_02", X, -4)
        aim_bone(arm, "upperarm_r", (-0.15, -0.35, -0.9))
        aim_bone(arm, "lowerarm_r", (0.3, -0.75, 0.6))
        aim_bone(arm, "hand_r", (0.2, -0.6, 0.7))
        aim_bone(arm, "upperarm_l", (0.2, 0.1, -1.0))
        rot_bone(arm, "spine_03", X, 1.0 * s)
    elif kind == "shout":
        # ป้าจุ๋ม on top of the water tank: megaphone at her mouth, other hand on her hip,
        # leaning back and shaking with every word
        rot_bone(arm, "spine_02", X, 6 + 3 * abs(s))
        rot_bone(arm, "Head", X, -8 - 4 * abs(s))
        rot_bone(arm, "spine_03", Z, 3 * s)
        aim_bone(arm, "upperarm_r", (-0.45, -0.6, -0.15))
        aim_bone(arm, "lowerarm_r", (0.55, -0.35, 0.75))
        aim_bone(arm, "hand_r", (0.4, -0.6, 0.6))
        aim_bone(arm, "upperarm_l", (0.75, 0.2, -0.65))
        aim_bone(arm, "lowerarm_l", (-0.55, -0.05, -0.8))
    elif kind == "wai":
        # the wedding: hands pressed together at the chest, bowing a little
        b = 0.5 - 0.5 * c
        rot_bone(arm, "spine_02", X, -4 - 6 * b)
        rot_bone(arm, "Head", X, 6 + 6 * b)
        for sx, side in ((1, "l"), (-1, "r")):
            aim_bone(arm, "upperarm_" + side, (sx * 0.25, -0.3, -0.9))
            aim_bone(arm, "lowerarm_" + side, (-sx * WAI_IN, -0.6, 0.68))
            aim_bone(arm, "hand_" + side, (-sx * 0.05, -0.15, 1.0))
        open_hands(arm)
    elif kind == "ride":
        # sitting astride the เรือเตอร์ไซค์: thighs forward, shins down, leaning
        # into the bars; the engine shakes the rider a little
        for sx, side in ((1, "l"), (-1, "r")):
            aim_bone(arm, "thigh_" + side, (sx * 0.22, -1.0, float(os.environ.get("TZ", "0.3"))))
            aim_bone(arm, "calf_" + side, (sx * 0.05, -0.15, -1.0))
            aim_bone(arm, "foot_" + side, (0, -1.0, -0.2))
        rot_bone(arm, "spine_01", X, -10)
        rot_bone(arm, "spine_02", X, -6 + 1.2 * s)
        rot_bone(arm, "Head", X, 8)
        for sx, side in ((1, "l"), (-1, "r")):
            aim_bone(arm, "upperarm_" + side, (sx * 0.3, -0.75, -0.55))
            aim_bone(arm, "lowerarm_" + side, (sx * 0.05, -0.95, -0.1))
            aim_bone(arm, "hand_" + side, (sx * 0.05, -1.0, -0.15))
        bob = RIDE_DROP + 0.004 * s
    else:  # attack (weapon only)
        if t < 0.34:
            u = t / 0.34
            up, fa, tw = 170 * u, -40 * u, 18 * u
        elif t < 0.6:
            u = (t - 0.34) / 0.26
            up, fa, tw = 170 - 150 * u, -40 + 35 * u, 18 - 40 * u
        else:
            u = (t - 0.6) / 0.4
            up, fa, tw = 20 - 20 * u, -5 + 5 * u, -22 + 22 * u
        rot_bone(arm, "spine_02", Z, tw)
        rot_bone(arm, "upperarm_r", X, -up)
        rot_bone(arm, "lowerarm_r", X, fa)
        rot_bone(arm, "upperarm_l", X, -25)
        rot_bone(arm, "lowerarm_l", X, -50)
        rot_bone(arm, "thigh_l", X, -16)
        rot_bone(arm, "thigh_r", X, 10)
        rot_bone(arm, "calf_r", X, 12)
        bob = -0.02
    root = arm.pose.bones["root"] if "root" in arm.pose.bones else None
    arm.location.z = bob
    return bob


def open_hands(arm, deg=6):
    """Flat hands (dancing, the wai) instead of base_pose's loose fists."""
    for s_ in ("l", "r"):
        for f in ("index", "middle", "ring", "pinky"):
            for k in (1, 2, 3):
                pb = arm.pose.bones["%s_0%d_%s" % (f, k, s_)]
                pb.rotation_quaternion = Quaternion(Vector((0, 0, 1)), math.radians(FINGER_SIGN * deg))
    bpy.context.view_layer.update()


def feet_z(arm):
    """Height of the lower foot (armature space), to keep feet planted."""
    bpy.context.view_layer.update()
    return min(arm.pose.bones[b].head.z for b in ("ball_l", "ball_r") if b in arm.pose.bones)


def key_all(arm, frame):
    for pb in arm.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)
    arm.keyframe_insert("location", frame=frame)


# ---------------------------------------------------------------------------
# accessories (rigid, parented to bones)
# ---------------------------------------------------------------------------

def bone_world(arm, name, tail=False):
    b = arm.data.bones[name]
    return arm.matrix_world @ (b.tail_local if tail else b.head_local)


def attach_rigid(parts, arm):
    bpy.context.view_layer.update()
    for obj, bone in parts:
        if bone is None:
            continue
        mw = obj.matrix_world.copy()
        b = arm.data.bones[bone]
        obj.parent = arm
        obj.parent_type = "BONE"
        obj.parent_bone = bone
        obj.matrix_parent_inverse = (arm.matrix_world @ b.matrix_local @ Matrix.Translation((0, b.length, 0))).inverted()
        obj.matrix_basis = mw


# ---------------------------------------------------------------------------
# characters
# ---------------------------------------------------------------------------

PAL = {}
LIGHT_SKIN = {}
SKIN_TONE = None
SKIN_TONES = {'rider': '#EDC29A', 'lung_pradit': '#D7A273', 'je_muay': '#F6D7B8'}


# NPCs of the flooded soi (owner 2026-10-02: every character dressed differently).
# body: which base; arms: "bare" (tank top) / "short" (short sleeves) / "long";
# legs: "long" / "short" (shorts, bare shins) / "skirt" (ผ้าถุง to the ankle);
# feet: Quaternius part (trimmed to shoes); scale: 1 = adult.
NPCS = {
    "nuad": dict(female=False, hair=["Hair_Buzzed.gltf"], hair_tint="#1A1618", skin="#B98058",
                 arms="bare", legs="long", feet="Male_Peasant_Feet.gltf", feet_tint="#5A4632",
                 pal={"torso": ("#1E1C22", 0.35, 0), "legs": ("#3B5578", 0.35, 0), "gold": ("#E2B54A", 0.6, 1.0),
                      "shade": ("#141218", 0.6, 1.0)}),
    "lung_table3": dict(female=False, hair=["Hair_Buzzed.gltf", "Hair_Beard.gltf"], hair_tint="#E8E4DC",
                        skin="#C99068", arms="short", legs="long", feet="Male_Peasant_Feet.gltf",
                        feet_tint="#3A2E26", hunch=True,
                        pal={"torso": ("#F2EEE4", 0.3, 0), "legs": ("#7A6448", 0.3, 0), "frame": ("#2A2224", 0.3, 0.4),
                             "hanky": ("#E58FB0", 0.3, 0), "garland": ("#F4F0E6", 0.4, 0),
                             "marigold": ("#F2A23A", 0.4, 0), "thread": ("#F8F6F0", 0.5, 0.3)}),
    "pa_nok": dict(female=True, hair=["Hair_Buns.gltf"], hair_tint="#BDB6AE", skin="#D9A57C",
                   arms="short", legs="skirt", feet="Female_Peasant_Feet.gltf", feet_tint="#2E2A30",
                   pal={"torso": ("#C0392B", 0.35, 0), "legs": ("#2E5E4E", 0.3, 0), "apron": ("#F2EEE4", 0.3, 0),
                        "band": ("#E8B83A", 0.4, 0), "garland": ("#F4F0E6", 0.4, 0),
                        "marigold": ("#F2A23A", 0.4, 0), "thread": ("#F8F6F0", 0.5, 0.3)}),
    "jum": dict(female=True, hair=["Hair_Buns.gltf"], hair_tint="#141016", skin="#E8B890",
                arms="short", legs="skirt", feet="Female_Peasant_Feet.gltf", feet_tint="#C0392B",
                pal={"torso": ("#F2A23A", 0.35, 0), "legs": ("#7A3A8A", 0.3, 0), "flower": ("#E8457A", 0.4, 0),
                     "gold": ("#E2B54A", 0.6, 1.0), "phone": ("#2B2629", 0.5, 0.8), "curler": ("#7FC8E8", 0.4, 0.4),
                     "megaphone": ("#D93A2E", 0.5, 0.6), "bell": ("#F2EEE6", 0.4, 0.3)}),
    "keng": dict(female=False, hair=["Hair_SimpleParted.gltf"], hair_tint="#141016", skin="#E0AE84",
                 arms="short", legs="short", feet="Male_Peasant_Feet.gltf", feet_tint="#E8E4DC", scale=0.78,
                 pal={"torso": ("#3A6FD8", 0.4, 0), "legs": ("#2B2629", 0.3, 0), "headset": ("#1E1C22", 0.5, 0.6),
                      "led": ("#4AE0C8", 0.6, 1.0)}),
    "chang_daeng": dict(female=False, hair=["Hair_Buzzed.gltf"], hair_tint="#2A2224", skin="#C08860",
                        arms="long", legs="long", feet="Male_Ranger_Feet_Boots.gltf", feet_tint="#FFFFFF",
                        pal={"torso": ("#B8322A", 0.35, 0), "legs": ("#B8322A", 0.35, 0), "cap": ("#2B2629", 0.35, 0.1),
                             "lens": ("#F0A13A", 0.6, 1.0), "grease": ("#2B2629", 0.2, 0)}),
    "kiao": dict(female=True, hair=["Hair_Long.gltf"], hair_tint="#100C10", skin="#F2CDA8",
                 arms="short", legs="long", feet="Female_Peasant_Feet.gltf", feet_tint="#1A1619",
                 pal={"torso": ("#B8221E", 0.4, 0.2), "legs": ("#1E1C22", 0.35, 0), "gold": ("#E2B54A", 0.6, 1.0),
                      "trim": ("#E2B54A", 0.5, 0.6)}),
    # chapter-1 stretch (DESIGN 12.5)
    "lung_mor_nam": dict(female=False, hair=["Hair_SimpleParted.gltf", "Hair_Beard.gltf"], hair_tint="#DEDAD2",
                         skin="#C99068", arms="short", legs="long", feet="Male_Peasant_Feet.gltf",
                         feet_tint="#4A3A2A", hunch=True,
                         pal={"torso": ("#D8D0B8", 0.3, 0), "legs": ("#5A5A62", 0.3, 0), "vest": ("#6B7A3A", 0.35, 0),
                              "hat": ("#C8A868", 0.35, 0), "frame": ("#2A2224", 0.3, 0.4), "pen": ("#D93A2E", 0.5, 0.6)}),
    "ple": dict(female=True, hair=["Hair_BuzzedFemale.gltf"], hair_tint="#1A1618", skin="#C98A5E",
                arms="short", legs="long", feet="Female_Peasant_Feet.gltf", feet_tint="#1A1619",
                pal={"torso": ("#2B2629", 0.35, 0), "legs": ("#3B5578", 0.35, 0), "vest": ("#F07A1E", 0.4, 0),
                     "badge": ("#F2EEE4", 0.3, 0), "whistle": ("#C0C8D0", 0.5, 0.9)}),
    "luang_pee": dict(female=False, hair=[], hair_tint="#C99068", skin="#C99068",
                      arms="bare", legs="skirt", feet="Male_Peasant_Feet.gltf", feet_tint="#C99068",
                      pal={"torso": ("#E88A1E", 0.35, 0), "legs": ("#E88A1E", 0.35, 0), "sash": ("#C8641A", 0.35, 0),
                           "bowl": ("#2A2E30", 0.5, 0.6), "glass": ("#2A2224", 0.3, 0.4)}),
    # chapter-2 stretch (DESIGN 12.5 / 12.7)
    "beam": dict(female=False, hair=["Hair_SimpleParted.gltf"], hair_tint="#2A2224", skin="#F0C8A0",
                 arms="long", legs="long", feet="Male_Ranger_Feet_Boots.gltf", feet_tint="#1A1619",
                 pal={"torso": ("#F2EEE4", 0.3, 0), "legs": ("#2A3550", 0.4, 0.1), "vest": ("#2E5E9E", 0.4, 0.2),
                      "lanyard": ("#E8762D", 0.4, 0), "card": ("#F2EEE4", 0.3, 0), "smile": ("#F2EEE4", 0.5, 0.3)}),
    "ton": dict(female=False, hair=["Hair_Buzzed.gltf"], hair_tint="#1A1618", skin="#C98A5E",
                arms="short", legs="long", feet="Male_Ranger_Feet_Boots.gltf", feet_tint="#1A1619", scale=0.95,
                pal={"torso": ("#8A8E96", 0.35, 0), "legs": ("#2A3550", 0.4, 0.1), "cap": ("#2E5E9E", 0.4, 0.1),
                     "card": ("#F2EEE4", 0.3, 0)}),
    "boy": dict(female=False, hair=["Hair_SimpleParted.gltf"], hair_tint="#141016", skin="#E0AE84",
                arms="short", legs="long", feet="Male_Peasant_Feet.gltf", feet_tint="#4A3A2A",
                pal={"torso": ("#C8B890", 0.35, 0), "legs": ("#5A5A62", 0.3, 0), "cap": ("#C8B890", 0.35, 0),
                     "sign": ("#2E5E9E", 0.4, 0.1), "sign_top": ("#F2C230", 0.4, 0), "pole": ("#4A5560", 0.4, 0.5)}),
    "la_or": dict(female=True, hair=["Hair_Buns.gltf"], hair_tint="#E8E4DC", skin="#F2D8C0",
                  arms="long", legs="skirt", feet="Female_Peasant_Feet.gltf", feet_tint="#F2EEE4",
                  pal={"torso": ("#7A3A8A", 0.4, 0.2), "legs": ("#7A3A8A", 0.4, 0.2), "pearl": ("#F8F4EE", 0.5, 0.9),
                       "hat": ("#F2EEE4", 0.35, 0), "ribbon": ("#C0392B", 0.4, 0), "shade": ("#141218", 0.6, 1.0)}),
    "berm": dict(female=False, hair=["Hair_Buzzed.gltf"], hair_tint="#1A1618", skin="#C08860",
                 arms="bare", legs="short", feet="Male_Ranger_Feet_Boots.gltf", feet_tint="#F2EEE4",
                 pal={"torso": ("#1E1C22", 0.35, 0), "legs": ("#3B5578", 0.35, 0), "cap": ("#D93A2E", 0.4, 0.1),
                      "phone": ("#2B2629", 0.5, 0.8), "screen": ("#4AE0C8", 0.6, 1.0), "stick": ("#C0C8D0", 0.5, 0.8),
                      "gold": ("#E2B54A", 0.6, 1.0)}),
    "wan": dict(female=True, hair=["Hair_Buns.gltf"], hair_tint="#141016", skin="#EFC6A0",
                arms="long", legs="long", feet="Female_Peasant_Feet.gltf", feet_tint="#141218",
                pal={"torso": ("#2A3550", 0.4, 0.1), "legs": ("#2A3550", 0.4, 0.1), "collar": ("#F2EEE4", 0.3, 0),
                     "badge": ("#E8762D", 0.4, 0), "card": ("#F2EEE4", 0.3, 0)}),
}


def npc_region(spec):
    arms, legs = spec["arms"], spec["legs"]

    def region(bone, p):
        if bone in ("Head", "neck_01") or bone.startswith(("hand", "index", "middle", "ring", "pinky", "thumb")):
            return "skin"
        if bone.startswith("lowerarm"):
            return "torso" if arms == "long" else "skin"
        if bone.startswith("upperarm"):
            if arms == "bare":
                # the strap still covers the top of the shoulder (joint at z 1.456;
                # owner 2026-10-02: "เสื้อกล้าม/กั๊กทุกคนใส่ไม่ถึงไหล่")
                return "torso" if p.z > 1.40 else "skin"
            if arms == "short" and p.z < 1.28:
                return "skin"
            return "torso"
        if bone.startswith("ball") or p.z < 0.06:
            return "hide"
        if bone.startswith("calf") and legs == "short":
            return "skin"
        if bone.startswith(("thigh", "calf")) or bone == "pelvis" or p.z < 0.97:
            return "legs"
        return "torso"
    return region


def wedding_dress(B, arm, neck, hc):
    """Thai wedding: a jasmine-and-marigold garland and the มงคลแฝด thread crown
    (only drawn in the "wai" animation)."""
    B.torus("Onlywai_Garland", neck + Vector((0, -0.07, -0.13)), 0.13, 0.026, "garland", "spine_03",
            scale=(1.0, 1.3, 1.0), rot=(math.radians(-50), 0, 0), ink=0.004)
    B.sphere("Onlywai_Tassel", neck + Vector((0, -0.17, -0.3)), 0.036, "marigold", "spine_03", ink=0.004)
    B.torus("Onlywai_Mongkol", hc + Vector((0, 0.0, 0.05)), 0.112, 0.008, "thread", "Head",
            scale=(1.0, 1.1, 1.0), ink=0.003)


def npc_accessories(name, B, arm, head, top, neck, hc):
    pelvis = bone_world(arm, "pelvis")
    if NPCS[name]["legs"] == "skirt":
        # ผ้าถุง: a tube of cloth from the waist to the ankles
        garment(B, BODY, "Skirt", "legs", "pelvis", 0.1, 0.98, arc=360, pad=0.03, flare=0.07)
    if name == "nuad":
        B.box("Mustache", hc + Vector((0, -0.118, -0.055)), (0.1, 0.03, 0.022), "hair", "Head", bevel=0.01, ink=0.004)
        for sx in (1, -1):
            B.box("Shade", hc + Vector((sx * 0.042, -0.122, 0.0)), (0.06, 0.012, 0.03), "shade", "Head", bevel=0.006, ink=0.003)
        B.torus("Chain", neck + Vector((0, -0.01, -0.04)), 0.075, 0.009, "gold", "spine_03", scale=(1.0, 1.0, 0.75), ink=0.0)
    elif name == "lung_table3":
        wedding_dress(B, arm, neck, hc)
        for sx in (1, -1):
            B.torus("Glass", hc + Vector((sx * 0.042, -0.122, 0.005)), 0.026, 0.004, "frame", "Head",
                    rot=(math.radians(90), 0, 0), ink=0.0)
        B.box("Hanky", bone_world(arm, "hand_l") + Vector((0.02, -0.03, -0.06)), (0.06, 0.02, 0.09), "hanky", "hand_l", bevel=0.01)
        B.sphere("Belly", pelvis + Vector((0, -0.05, 0.2)), 0.14, "torso", "spine_01", scale=(1.0, 0.75, 0.9), ink=0.008)
    elif name == "pa_nok":
        wedding_dress(B, arm, neck, hc)
        garment(B, BODY, "Apron", "apron", "pelvis", 0.42, 1.0, arc=140, pad=0.035, flare=0.04)
        B.torus("Band", hc + Vector((0, 0.005, 0.015)), 0.112, 0.014, "band", "Head", scale=(1.0, 1.12, 1.0), ink=0.004)
    elif name == "jum":
        B.sphere("Flower", hc + Vector((0.09, -0.02, 0.06)), 0.035, "flower", "Head", ink=0.004)
        for k, sx in enumerate((1, -1)):
            B.cyl("Curler", hc + Vector((sx * 0.06, 0.07, 0.07)), 0.022, 0.07, "curler", "Head",
                  rot=(0, math.radians(90), 0), ink=0.004)
            B.torus("Hoop", head + Vector((sx * 0.075, 0.0, 0.06)), 0.022, 0.004, "gold", "Head", rot=(0, math.radians(90), 0), ink=0.0)
        # พี่หนวด's debt megaphone, held at the mouth (on the head bone so it stays put)
        mouth = hc + Vector((0, -0.12, -0.06))
        B.cyl("Onlyshout_Mega", mouth + Vector((0, -0.12, 0)), 0.04, 0.2, "megaphone", "Head",
              rot=(math.radians(90), 0, 0), r2=0.1, ink=0.006)
        B.torus("Onlyshout_Bell", mouth + Vector((0, -0.22, 0)), 0.1, 0.012, "bell", "Head",
                rot=(math.radians(90), 0, 0), ink=0.004)
        B.cyl("Onlyshout_Grip", mouth + Vector((-0.02, -0.1, -0.08)), 0.018, 0.1, "phone", "Head", ink=0.004)
        hR = bone_world(arm, "hand_r")
        B.box("Notshout_Phone", hR + Vector((-0.06, -0.03, 0)), (0.05, 0.012, 0.1), "phone", "hand_r", bevel=0.006)
    elif name == "keng":
        B.torus("Headset", hc + Vector((0, 0.0, -0.005)), 0.118, 0.012, "headset", "Head", rot=(0, math.radians(90), 0),
                scale=(1.0, 1.0, 1.15), ink=0.004)
        for sx in (1, -1):
            B.cyl("Cup", hc + Vector((sx * 0.118, 0.0, 0.0)), 0.045, 0.03, "headset", "Head", rot=(0, math.radians(90), 0))
            B.cyl("Led", hc + Vector((sx * 0.135, 0.0, 0.0)), 0.02, 0.006, "led", "Head", rot=(0, math.radians(90), 0), ink=0.0)
    elif name == "chang_daeng":
        B.sphere("Cap", hc + Vector((0, 0.01, 0.06)), 0.118, "cap", "Head", scale=(1.0, 1.08, 0.8), cut=0.1)
        B.box("Visor", hc + Vector((0, 0.14, 0.072)), (0.14, 0.11, 0.012), "cap", "Head", rot=(math.radians(8), 0, 0), bevel=0.02)
        for sx in (1, -1):
            B.cyl("Goggle", hc + Vector((sx * 0.045, -0.105, 0.075)), 0.03, 0.03, "lens", "Head", rot=(math.radians(80), 0, 0))
        B.box("Rag", pelvis + Vector((0.12, -0.09, 0.0)), (0.05, 0.02, 0.14), "grease", "pelvis", bevel=0.01)
    elif name == "kiao":
        B.torus("Necklace", neck + Vector((0, -0.01, -0.05)), 0.08, 0.008, "gold", "spine_03", scale=(1.0, 1.0, 0.75), ink=0.0)
        B.torus("Collar", neck + Vector((0, 0.005, -0.01)), 0.07, 0.014, "trim", "spine_03", scale=(1.0, 1.0, 0.6), ink=0.004)
        for sx, side in ((1, "l"), (-1, "r")):
            B.torus("Bangle", bone_world(arm, "hand_" + side), 0.04, 0.01, "gold", "lowerarm_" + side,
                    rot=(0, math.radians(90), 0), ink=0.0)
            B.torus("Hoop", head + Vector((sx * 0.075, 0.0, 0.06)), 0.026, 0.005, "gold", "Head", rot=(0, math.radians(90), 0), ink=0.0)
    elif name == "lung_mor_nam":
        # a field vest full of pockets, a woven palm-leaf hat, reading glasses and a red pen
        garment(B, BODY, "Vest", "vest", "spine_02", 1.0, 1.36, arc=200, pad=0.03)
        B.cyl("Hat", hc + Vector((0, 0.0, 0.07)), 0.2, 0.012, "hat", "Head", r2=0.19, ink=0.004)
        B.cyl("HatTop", hc + Vector((0, 0.0, 0.1)), 0.11, 0.07, "hat", "Head", r2=0.07, ink=0.004)
        for sx in (1, -1):
            B.torus("Glass", hc + Vector((sx * 0.042, -0.122, 0.005)), 0.026, 0.004, "frame", "Head",
                    rot=(math.radians(90), 0, 0), ink=0.0)
        hx, fy, by = body_section(BODY, neck.z - 0.22)
        B.cyl("Pen", Vector((0.07, fy - 0.03, neck.z - 0.2)), 0.008, 0.12, "pen", "spine_03", ink=0.003)
    elif name == "ple":
        # the orange rank vest with her number, a whistle on a cord
        garment(B, BODY, "Vest", "vest", "spine_02", 1.0, 1.36, arc=200, pad=0.03)
        hx, fy, by = body_section(BODY, neck.z - 0.2)
        B.box("Badge", Vector((0.0, fy - 0.035, neck.z - 0.22)), (0.09, 0.012, 0.09), "badge", "spine_03", bevel=0.006, ink=0.004)
        B.torus("Cord", neck + Vector((0, -0.01, -0.03)), 0.07, 0.005, "whistle", "spine_03", scale=(1.0, 1.0, 0.8), ink=0.0)
        B.cyl("Whistle", neck + Vector((0, -0.09, -0.12)), 0.014, 0.05, "whistle", "spine_03", rot=(0, math.radians(90), 0), ink=0.004)
    elif name == "luang_pee":
        # the robe's sash over the left shoulder, glasses, the alms bowl in the left hand
        B.torus("Sash", neck + Vector((0.06, 0.0, -0.1)), 0.17, 0.03, "sash", "spine_03",
                rot=(math.radians(60), math.radians(30), 0), scale=(1.0, 1.0, 1.4), ink=0.005)
        for sx in (1, -1):
            B.torus("Glass", hc + Vector((sx * 0.042, -0.122, 0.005)), 0.024, 0.004, "glass", "Head",
                    rot=(math.radians(90), 0, 0), ink=0.0)
        B.sphere("Bowl", bone_world(arm, "hand_l") + Vector((0.0, -0.02, -0.08)), 0.09, "bowl", "hand_l",
                 scale=(1.0, 1.0, 0.8), rot=(math.pi, 0, 0), cut=0.2, ink=0.006)
    elif name == "beam":
        # company vest over a white shirt, a lanyard with the badge, and the smile that never stops
        garment(B, BODY, "Vest", "vest", "spine_02", 1.0, 1.36, arc=200, pad=0.03)
        hx, fy, by = body_section(BODY, neck.z - 0.2)
        B.torus("Lanyard", neck + Vector((0, -0.01, -0.03)), 0.075, 0.006, "lanyard", "spine_03", scale=(1.0, 1.0, 1.6), ink=0.0)
        B.box("Badge", Vector((0.0, fy - 0.03, neck.z - 0.26)), (0.07, 0.012, 0.09), "card", "spine_03", bevel=0.006, ink=0.004)
        B.torus("Smile", hc + Vector((0, -0.118, -0.05)), 0.04, 0.008, "smile", "Head", rot=(math.radians(90), 0, 0),
                scale=(1.0, 0.5, 1.0), ink=0.003)
    elif name == "ton":
        B.sphere("Cap", hc + Vector((0, 0.01, 0.06)), 0.118, "cap", "Head", scale=(1.0, 1.08, 0.8), cut=0.1)
        B.box("Visor", hc + Vector((0, -0.14, 0.072)), (0.14, 0.11, 0.012), "cap", "Head", rot=(math.radians(-8), 0, 0), bevel=0.02)
        hx, fy, by = body_section(BODY, neck.z - 0.2)
        B.box("Badge", Vector((0.06, fy - 0.03, neck.z - 0.22)), (0.06, 0.012, 0.07), "card", "spine_03", bevel=0.006, ink=0.004)
    elif name == "boy":
        # the sign department: khaki cap, and the next project sign under one arm
        B.sphere("Cap", hc + Vector((0, 0.01, 0.06)), 0.118, "cap", "Head", scale=(1.0, 1.08, 0.8), cut=0.1)
        B.box("Visor", hc + Vector((0, -0.14, 0.072)), (0.14, 0.11, 0.012), "cap", "Head", rot=(math.radians(-8), 0, 0), bevel=0.02)
        hL = bone_world(arm, "hand_l")
        B.cyl("Pole", hL + Vector((0.0, 0.0, 0.1)), 0.012, 0.9, "pole", "hand_l", ink=0.004)
        B.box("Sign", hL + Vector((0.0, -0.02, 0.62)), (0.3, 0.02, 0.2), "sign", "hand_l", bevel=0.006, ink=0.005)
        B.box("SignTop", hL + Vector((0.0, -0.02, 0.73)), (0.3, 0.02, 0.03), "sign_top", "hand_l", bevel=0.004, ink=0.0)
    elif name == "la_or":
        # a wide sun hat with a ribbon, pearls, sunglasses
        B.cyl("Hat", hc + Vector((0, 0.0, 0.08)), 0.26, 0.014, "hat", "Head", r2=0.25, ink=0.005)
        B.cyl("HatTop", hc + Vector((0, 0.0, 0.13)), 0.125, 0.1, "hat", "Head", r2=0.11, ink=0.005)
        B.torus("Ribbon", hc + Vector((0, 0.0, 0.1)), 0.125, 0.02, "ribbon", "Head", scale=(1.0, 1.0, 0.6), ink=0.003)
        B.torus("Pearls", neck + Vector((0, -0.01, -0.05)), 0.085, 0.012, "pearl", "spine_03", scale=(1.0, 1.0, 0.8), ink=0.0)
        for sx in (1, -1):
            B.box("Shade", hc + Vector((sx * 0.044, -0.122, 0.0)), (0.062, 0.012, 0.034), "shade", "Head", bevel=0.008, ink=0.003)
    elif name == "berm":
        # cap on backwards, gold chain, the phone on a selfie stick in the right hand
        B.sphere("Cap", hc + Vector((0, 0.01, 0.06)), 0.118, "cap", "Head", scale=(1.0, 1.08, 0.8), cut=0.1)
        B.box("Visor", hc + Vector((0, 0.14, 0.072)), (0.14, 0.11, 0.012), "cap", "Head", rot=(math.radians(8), 0, 0), bevel=0.02)
        B.torus("Chain", neck + Vector((0, -0.01, -0.05)), 0.09, 0.012, "gold", "spine_03", scale=(1.0, 1.0, 0.8), ink=0.0)
        hR = bone_world(arm, "hand_r")
        B.cyl("Stick", hR + Vector((-0.25, -0.02, 0.0)), 0.012, 0.5, "stick", "hand_r", rot=(0, math.radians(90), 0), ink=0.004)
        B.box("Phone", hR + Vector((-0.52, -0.02, 0.0)), (0.07, 0.012, 0.13), "phone", "hand_r", bevel=0.006, ink=0.004)
        B.box("Screen", hR + Vector((-0.52, -0.03, 0.0)), (0.058, 0.004, 0.11), "screen", "hand_r", bevel=0.002, ink=0.0)
    elif name == "wan":
        B.torus("Collar", neck + Vector((0, 0.005, -0.01)), 0.072, 0.016, "collar", "spine_03", scale=(1.0, 1.0, 0.6), ink=0.004)
        hx, fy, by = body_section(BODY, neck.z - 0.18)
        B.box("Badge", Vector((0.0, fy - 0.012, neck.z - 0.2)), (0.07, 0.012, 0.09), "card", "spine_03", bevel=0.006, ink=0.004)
        B.box("BadgeLogo", Vector((0.0, fy - 0.02, neck.z - 0.18)), (0.04, 0.006, 0.02), "badge", "spine_03", bevel=0.002, ink=0.0)


def build(name):
    global PAL, INK
    sc = reset()
    INK = outline_material()
    npc = NPCS.get(name)
    if npc:
        PAL = dict(PALETTES["je_muay" if npc["female"] else "lung_pradit"])
        PAL.update(npc["pal"])
        PAL["hair"] = (npc["hair_tint"], 0.3, 0.2)
    else:
        PAL = PALETTES[name]
    B = Builder(PAL)
    B.ink = INK
    female = npc["female"] if npc else name == "je_muay"
    objs = import_gltf(BASE + ("Superhero_Female_FullBody.gltf" if female else "Superhero_Male_FullBody.gltf"))
    arm = [o for o in objs if o.type == "ARMATURE"][0]
    arm.rotation_mode = "XYZ"
    body = [o for o in objs if o.type == "MESH" and o.name.lower().startswith("superhero")][0]
    global BODY, SKIN_TONE
    BODY = body
    SKIN_TONE = npc["skin"] if npc else SKIN_TONES[name]
    tex_dir = UBC + "/Base Characters/Textures/"
    LIGHT_SKIN[body.name[:20]] = tex_dir + ("T_Superhero_Female_Light_BaseColor.png" if female else "T_Superhero_Male_Ligh.png")
    for o in objs:
        if o.type == "MESH" and o is not body:
            toonify(o)
    if npc:
        for hf in npc["hair"]:
            for o in rebind(import_gltf(HAIR + hf), arm):
                toonify(o, npc["hair_tint"])
        paint_regions(body, npc_region(npc))
        finish_body(body, [])
        for o in rebind(import_gltf(OUTF + npc["feet"]), arm):
            if "Boots" not in npc["feet"]:
                trim_above(o, 0.12)
            toonify(o, npc["feet_tint"])
        global WAI_IN
        WAI_IN = 0.36 if npc["female"] else 0.55
        if npc.get("scale"):
            arm.scale = (npc["scale"],) * 3
            bpy.context.view_layer.update()  # accessories read bone positions
        return sc, arm, B, dict(akimbo=npc["female"] and name == "kiao", hunch=npc.get("hunch", False))
    hair = {"rider": "Hair_Buzzed.gltf", "lung_pradit": "Hair_Beard.gltf", "je_muay": "Hair_Buns.gltf"}[name]
    tints = {"rider": "#2A2224", "lung_pradit": "#E8E4DC", "je_muay": "#1C1620"}
    hobjs = import_gltf(HAIR + hair)
    if name == "lung_pradit":
        hobjs += import_gltf(HAIR + "Hair_Buzzed.gltf")
    for o in rebind(hobjs, arm):
        toonify(o, tints[name])
    opts = {}
    if name == "rider":
        def region(bone, p):
            if bone in ("Head", "neck_01"):
                return "skin"
            if bone.startswith(("hand", "index", "middle", "ring", "pinky", "thumb")):
                return "glove"
            if bone.startswith(("upperarm", "lowerarm")):
                if p.z < 0.93:
                    return "cuff"
                return "reflect" if (1.10 < p.z < 1.14 or 1.19 < p.z < 1.23) else "jacket"
            if bone.startswith(("thigh", "calf", "foot", "ball")) or bone == "pelvis" or p.z < 0.98:
                return "pants"
            # unzipped: the T-shirt shows through a front opening that widens downward
            if p.y < -0.03 and abs(p.x) < 0.05 + max(0.0, 1.4 - p.z) * 0.09:
                return "tee"
            if 1.10 < p.z < 1.14 or 1.19 < p.z < 1.23:
                return "reflect"
            return "jacket"
        paint_regions(body, region)
        finish_body(body, [(("jacket", "reflect", "cuff"), "tee")])
        parts = import_gltf(OUTF + "Male_Ranger_Feet_Boots.gltf")
        for o in rebind(parts, arm):
            if True:
                toonify(o, "#B08A5A" if "Pauldron" in o.name else "#FFFFFF")
        opts = dict(weapon=True)
    elif name == "lung_pradit":
        def region(bone, p):
            if bone in ("Head", "neck_01") or bone.startswith(("hand", "index", "middle", "ring", "pinky", "thumb", "lowerarm")):
                return "skin"
            if bone.startswith("ball") or p.z < 0.06:
                return "hide"
            if bone.startswith(("thigh", "calf")) or bone == "pelvis" or p.z < 0.98:
                return "pants"
            return "shirt"
        paint_regions(body, region)
        finish_body(body, [])
        for o in rebind(import_gltf(OUTF + "Male_Peasant_Feet.gltf"), arm):
            trim_above(o, 0.11)
            toonify(o, "#7A5A3A")
    else:
        def region(bone, p):
            if bone in ("Head", "neck_01") or bone.startswith(("hand", "index", "middle", "ring", "pinky", "thumb", "lowerarm")):
                return "skin"
            if bone.startswith("ball") or p.z < 0.06:
                return "hide"
            if bone.startswith(("thigh", "calf")) or bone == "pelvis" or p.z < 0.95:
                return "pants"
            return "blouse"
        paint_regions(body, region)
        finish_body(body, [])
        for o in rebind(import_gltf(OUTF + "Female_Peasant_Feet.gltf"), arm):
            trim_above(o, 0.12)
            toonify(o, "#3A2E36")
        opts = dict(akimbo=True)
    return sc, arm, B, opts


def accessories(name, B, arm):
    head = bone_world(arm, "Head")
    top = bone_world(arm, "Head", tail=True)
    neck = bone_world(arm, "neck_01")
    hc = head + Vector((0, 0.0, 0.11))
    if name in NPCS:
        npc_accessories(name, B, arm, head, top, neck, hc)
    elif name == "rider":
        full_face_helmet(B, hc + Vector((0, 0.012, 0.0)), 0.152)
        # fold-down collar: band round the back of the neck + two lapels opening at the front
        B.torus("Collar", neck + Vector((0, 0.012, -0.012)), 0.082, 0.02, "jacket", "spine_03", scale=(1.1, 1.0, 0.7), ink=0.007)
        hx, fy, by = body_section(BODY, neck.z - 0.08)
        for sx in (1, -1):
            B.box("Lapel", Vector((sx * 0.07, fy - 0.022, neck.z - 0.07)), (0.075, 0.016, 0.13), "jacket", "spine_03",
                  rot=(math.radians(-14), sx * math.radians(-28), 0), bevel=0.008, ink=0.006)
        B.torus("Belt", bone_world(arm, "pelvis") + Vector((0, 0, 0.07)), 0.16, 0.02, "belt", "pelvis", scale=(1.0, 0.72, 1.0), ink=0.006)
        B.cyl("Gauge", bone_world(arm, "pelvis") + Vector((0.12, -0.09, 0.06)), 0.032, 0.02, "brass", "pelvis", rot=(math.radians(90), 0, math.radians(30)))
        delivery_box(B, arm)
        # the ending where the box was sold: five stars glowing on the phone
        B.box("Onlyphone_Phone", hc + Vector((0.03, -0.26, -0.17)), (0.07, 0.012, 0.13), "steel", "Head",
              rot=(math.radians(-35), 0, 0), bevel=0.008, ink=0.004)
        B.box("Onlyphone_Screen", hc + Vector((0.03, -0.268, -0.167)), (0.058, 0.004, 0.11), "lens", "Head",
              rot=(math.radians(-35), 0, 0), bevel=0.002, ink=0.0)
        # wrench built in the T-pose hand frame: handle along the hand (-X at rest), jaw toward the front (-Y)
        hR = bone_world(arm, "hand_r")
        ry = (0, math.radians(90), 0)
        B.cyl("WHandle", hR + Vector((-0.2, -0.02, 0)), 0.022, 0.56, "wrench_red", "hand_r", rot=ry)
        B.box("WJaw", hR + Vector((-0.5, -0.08, 0)), (0.075, 0.17, 0.075), "steel", "hand_r", bevel=0.014)
        B.box("WHook", hR + Vector((-0.42, -0.16, 0)), (0.15, 0.05, 0.07), "steel", "hand_r", bevel=0.012)
        B.cyl("WNut", hR + Vector((-0.4, -0.07, 0)), 0.036, 0.08, "brass", "hand_r")
    elif name == "lung_pradit":
        for bn, sc_ in (("spine_03", (0.9, 1.0, 0.9)), ("upperarm_l", (1.0, 0.85, 0.85)), ("upperarm_r", (1.0, 0.85, 0.85)),
                        ("spine_01", (1.12, 1.0, 1.15))):
            arm.pose.bones[bn].scale = sc_
        B.sphere("Cap", hc + Vector((0, 0.015, 0.06)), 0.118, "cap", "Head", scale=(1.0, 1.08, 0.8), cut=0.1)
        B.box("Visor", hc + Vector((0, -0.14, 0.072)), (0.14, 0.11, 0.012), "cap", "Head", rot=(math.radians(-8), 0, 0), bevel=0.02)
        B.sphere("Belly", bone_world(arm, "pelvis") + Vector((0, -0.05, 0.2)), 0.15, "shirt", "spine_01", scale=(1.0, 0.75, 0.9), ink=0.008)
        garment(B, BODY, "ApronBib", "apron", "spine_02", 1.0, 1.27, arc=80, pad=0.03)
        garment(B, BODY, "ApronSkirt", "apron", "pelvis", 0.52, 1.0, arc=140, pad=0.035, flare=0.03)
        for sx in (1, -1):
            B.cyl("ApronStrap", bone_world(arm, "neck_01") + Vector((sx * 0.06, -0.06, -0.08)), 0.008, 0.16, "apron", "spine_03",
                  rot=(math.radians(-20), math.radians(sx * 20), 0), ink=0.004)
    else:
        B.cyl("Pin", top + Vector((0, 0.0, 0.0)), 0.006, 0.22, "brass", "Head", rot=(0, math.radians(70), 0))
        garment(B, BODY, "Apron", "apron", "pelvis", 0.6, 1.0, arc=140, pad=0.03, flare=0.05)
        for sx in (1, -1):
            B.torus("Hoop", head + Vector((sx * 0.075, 0.0, 0.06)), 0.022, 0.004, "brass", "Head", rot=(0, math.radians(90), 0), ink=0.0)
    attach_rigid(B.parts, arm)


PALETTES["rider"].update({"tee": ("#3A3F46", 0.35, 0), "jacket": ("#E8762D", 0.4, 0), "cuff": ("#2B2629", 0.3, 0), "visor": ("#2B3A46", 0.6, 1.0),
                          "box": ("#2F6F6A", 0.4, 0), "box_lid": ("#E8762D", 0.4, 0),
                          "shirt": ("#24423F", 0.45, 0), "pants": ("#1F1D24", 0.45, 0), "glove": ("#3A2A22", 0.3, 0.2),
                          "scarf": ("#B8322A", 0.4, 0), "helmet": ("#2F5F5A", 0.45, 0.6), "lens": ("#F0A13A", 0.6, 1.0),
                          "vest": ("#E8762D", 0.4, 0), "reflect": ("#E3E8EA", 0.5, 0.4)})
PALETTES["lung_pradit"].update({"apron": ("#3C5A8A", 0.3, 0), "pants": ("#4B4A3A", 0.35, 0)})


def main():
    name, out = sys.argv[1], sys.argv[2]
    still = "--still" in sys.argv
    os.makedirs(out, exist_ok=True)
    sc, arm, B, opts = build(name)
    accessories(name, B, arm)
    ranges, frame = {}, 1
    anims = dict(ANIMS)
    anims.update(EXTRA_ANIMS.get(name, {}))
    only = os.environ.get("ONLY")
    if only:
        anims = {k: v for k, v in anims.items() if k in only.split(",")}
    for anim, (n, fps) in anims.items():
        if anim == "attack" and not opts.get("weapon"):
            continue
        ranges[anim] = (frame, n, fps)
        for i in range(n):
            pose_frame(arm, anim, i / n, weapon=opts.get("weapon", False), akimbo=opts.get("akimbo", False),
                       hunch=opts.get("hunch", False))
            key_all(arm, frame + i)
        frame += n
    tmp = os.path.join(out, "_frames")
    os.makedirs(tmp, exist_ok=True)
    dirs = [2, 1, 0, 6] if still else range(8)
    # on the bike the backpack box and the wrench come off (the bike has its own box)
    box_parts = {"Box", "Lid", "BoxStrip", "Corner", "Strap", "Chimney", "ChimCap", "BoxGauge", "BoxGaugeFace"}
    wrench = {"WHandle", "WJaw", "WHook", "WNut"}
    # parts put away for an animation: on the bike the backpack box (the bike has
    # its own) and the wrench; hands busy with a phone or hugging knees: no wrench
    put_away = {"ride": box_parts | wrench, "phone": wrench, "sit_sad": wrench, "shrug": wrench}
    for anim, (f0, n, fps) in ranges.items():
        for o in bpy.data.objects:
            base = o.name.split(".")[0]
            if base in box_parts | wrench:
                o.hide_render = base in put_away.get(anim, ())
            elif base.startswith("Only"):
                # "Only<anim>_..." props exist for one animation (megaphone, garland),
                # "Not<anim>_..." ones are put away for it (the phone while shouting)
                o.hide_render = base[4:].split("_")[0] != anim
            elif base.startswith("Not"):
                o.hide_render = base[3:].split("_")[0] == anim
        for d in dirs:
            arm.rotation_euler = (0, 0, yaw_for(d))
            idx = range(n) if not still else ([0] if anim in ("idle", "ride") else [0, n // 2])
            if still and anim == "walk":
                idx = []
            for i in idx:
                sc.frame_set(f0 + i)
                sc.render.filepath = os.path.join(tmp, "%s_%d_%02d.png" % (anim, d, i))
                bpy.ops.render.render(write_still=True)
    meta = {"frame_size": [FRAME_W, FRAME_H], "pivot": list(PIVOT), "art_scale": 2,
            "directions": DIRS, "anims": {a: {"frames": r[1], "fps": r[2]} for a, r in ranges.items()}}
    with open(os.path.join(out, "sprites.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print("rendered", name)


main()
