"""Characters from the Quaternius CC0 kits (Universal Base Characters +
Modular Character Outfits), dressed for 25d and rendered with our toon/ink
shader to 8-direction sprite sheets (same output contract as char3d.py).

Run: python3 char_q.py <rider|lung_pradit|je_muay> <out_dir> [--still]
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
    m = toon_material(name, tint, rim=rim, spec=spec)
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


def finish_body(body, overlays):
    for keys_over, under in overlays:
        ob = make_overlay(body, keys_over, under)
        if ob is not None:
            # the copy inherited the body's ink-less material list; give it its own ink
            add_ink(ob, 0.008)
    add_ink(body, 0.010)


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


def pose_frame(arm, kind, t, weapon=False, akimbo=False):
    base_pose(arm, akimbo=akimbo)
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


def build(name):
    global PAL, INK
    sc = reset()
    INK = outline_material()
    PAL = PALETTES[name]
    B = Builder(PAL)
    B.ink = INK
    female = name == "je_muay"
    objs = import_gltf(BASE + ("Superhero_Female_FullBody.gltf" if female else "Superhero_Male_FullBody.gltf"))
    arm = [o for o in objs if o.type == "ARMATURE"][0]
    arm.rotation_mode = "XYZ"
    body = [o for o in objs if o.type == "MESH" and o.name.lower().startswith("superhero")][0]
    global BODY, SKIN_TONE
    BODY = body
    SKIN_TONE = SKIN_TONES[name]
    tex_dir = UBC + "/Base Characters/Textures/"
    LIGHT_SKIN[body.name[:20]] = tex_dir + ("T_Superhero_Female_Light_BaseColor.png" if female else "T_Superhero_Male_Ligh.png")
    for o in objs:
        if o.type == "MESH" and o is not body:
            toonify(o)
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
                return "shirt"
            if bone.startswith(("thigh", "calf", "foot", "ball")) or bone == "pelvis" or p.z < 0.98:
                return "pants"
            if 1.12 < p.z < 1.16 or 1.21 < p.z < 1.25:
                return "reflect"
            return "vest"
        paint_regions(body, region)
        finish_body(body, [(("vest", "reflect"), "shirt")])
        parts = import_gltf(OUTF + "Male_Ranger_Feet_Boots.gltf") + import_gltf(OUTF + "Male_Ranger_Acc_Pauldron.gltf")
        for o in rebind(parts, arm):
            if True:
                toonify(o, "#B08A5A" if "Pauldron" in o.name else "#FFFFFF")
        opts = dict(weapon=True)
    elif name == "lung_pradit":
        def region(bone, p):
            if bone in ("Head", "neck_01") or bone.startswith(("hand", "index", "middle", "ring", "pinky", "thumb", "lowerarm")):
                return "skin"
            if bone.startswith(("foot", "ball")):
                return "skin"
            if bone.startswith(("thigh", "calf")) or bone == "pelvis" or p.z < 0.98:
                return "pants"
            return "shirt"
        paint_regions(body, region)
        finish_body(body, [])
    else:
        def region(bone, p):
            if bone in ("Head", "neck_01") or bone.startswith(("hand", "index", "middle", "ring", "pinky", "thumb", "lowerarm")):
                return "skin"
            if bone.startswith(("foot", "ball")):
                return "shoe"
            if bone.startswith(("thigh", "calf")) or bone == "pelvis" or p.z < 0.95:
                return "pants"
            return "blouse"
        paint_regions(body, region)
        finish_body(body, [])
        opts = dict(akimbo=True)
    return sc, arm, B, opts


def accessories(name, B, arm):
    head = bone_world(arm, "Head")
    top = bone_world(arm, "Head", tail=True)
    neck = bone_world(arm, "neck_01")
    hc = head + Vector((0, 0.0, 0.11))
    if name == "rider":
        B.sphere("Helmet", hc + Vector((0, 0.02, 0.03)), 0.135, "helmet", "Head", scale=(1.0, 1.1, 0.85), cut=0.05)
        B.torus("Brim", hc + Vector((0, 0.02, 0.037)), 0.133, 0.01, "brass", "Head", scale=(1.0, 1.1, 1.0))
        B.torus("GStrap", hc + Vector((0, 0.02, 0.07)), 0.125, 0.008, "strap", "Head", rot=(math.radians(-14), 0, 0), scale=(1.0, 1.08, 1.0))
        for sx in (1, -1):
            g = hc + Vector((sx * 0.048, -0.1, 0.1))
            B.torus("Goggle", g, 0.03, 0.011, "brass", "Head", rot=(math.radians(58), 0, 0))
            B.sphere("Lens", g + Vector((0, 0.004, -0.002)), 0.029, "lens", "Head", scale=(1, 0.45, 1), rot=(math.radians(-32), 0, 0), ink=0.0)
        B.torus("Scarf", neck + Vector((0, 0.0, 0.03)), 0.07, 0.028, "scarf", "neck_01", ink=0.007)
        B.sphere("Knot", neck + Vector((0.04, -0.075, 0.0)), 0.035, "scarf", "neck_01", ink=0.006)
        B.cyl("ScarfTail", neck + Vector((0.07, -0.085, -0.12)), 0.04, 0.22, "scarf", "spine_03", r2=0.006,
              rot=(math.radians(-12), math.radians(-18), 0), scale=(1.0, 0.3, 1.0), ink=0.006)
        B.torus("Belt", bone_world(arm, "pelvis") + Vector((0, 0, 0.07)), 0.16, 0.02, "belt", "pelvis", scale=(1.0, 0.72, 1.0), ink=0.006)
        B.cyl("Gauge", bone_world(arm, "pelvis") + Vector((0.12, -0.09, 0.06)), 0.032, 0.02, "brass", "pelvis", rot=(math.radians(90), 0, math.radians(30)))
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
        for s in ("l", "r"):
            f = bone_world(arm, "foot_" + s)
            B.box("Sandal", Vector((f.x, f.y - 0.05, 0.01)), (0.11, 0.27, 0.02), "sandal", "foot_" + s, bevel=0.006)
    else:
        B.cyl("Pin", top + Vector((0, 0.0, 0.0)), 0.006, 0.22, "brass", "Head", rot=(0, math.radians(70), 0))
        garment(B, BODY, "Apron", "apron", "pelvis", 0.6, 1.0, arc=140, pad=0.03, flare=0.05)
        for s_ in ("l", "r"):
            f = bone_world(arm, "foot_" + s_)
            B.box("Shoe", Vector((f.x, f.y - 0.06, 0.035)), (0.1, 0.26, 0.07), "shoe", "foot_" + s_, bevel=0.03)
        for sx in (1, -1):
            B.torus("Hoop", head + Vector((sx * 0.075, 0.0, 0.06)), 0.022, 0.004, "brass", "Head", rot=(0, math.radians(90), 0), ink=0.0)
    attach_rigid(B.parts, arm)


PALETTES["rider"].update({"shirt": ("#24423F", 0.45, 0), "pants": ("#1F1D24", 0.45, 0), "glove": ("#3A2A22", 0.3, 0.2),
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
    for anim, (n, fps) in ANIMS.items():
        if anim == "attack" and not opts.get("weapon"):
            continue
        ranges[anim] = (frame, n, fps)
        for i in range(n):
            pose_frame(arm, anim, i / n, weapon=opts.get("weapon", False), akimbo=opts.get("akimbo", False))
            key_all(arm, frame + i)
        frame += n
    tmp = os.path.join(out, "_frames")
    os.makedirs(tmp, exist_ok=True)
    dirs = [2, 1, 0, 6] if still else range(8)
    for anim, (f0, n, fps) in ranges.items():
        for d in dirs:
            arm.rotation_euler = (0, 0, yaw_for(d))
            idx = range(n) if not still else ([0] if anim == "idle" else [0, n // 2])
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
