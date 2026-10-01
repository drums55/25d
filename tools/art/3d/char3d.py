"""3D toon characters rendered to 8-direction sprite sheets (Hades approach:
3D model + painted-look shader + ink outline, rendered to 2D).

Run (cloud, bpy 4.2):  python3 char3d.py <name> <out_dir> [--still]
Output per character (art at 2x, like the props):
  <out>/<anim>.png   sprite sheet: rows = 8 directions in Iso.Dir order
                     (E, SE, S, SW, W, NW, N, NE), columns = frames
  <out>/sprites.json frame size, pivot (feet), fps + frame count per anim
"""
import bpy, bmesh, math, json, os, sys
from mathutils import Vector, Matrix, Euler

FRAME_W, FRAME_H = 320, 480
PIVOT = (160, 448)               # feet in the frame (px)
CHAR_PX = 360.0                  # 1.75 m tall standing -> 360 px (2x art)
ELEV = math.radians(30.0)        # 2:1 iso
PPU = CHAR_PX / (1.75 * math.cos(ELEV))   # px per world unit in the image plane
ANIMS = {"idle": (6, 6), "walk": (8, 12), "attack": (6, 18)}   # frames, fps
DIRS = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
LIGHT = Vector((-0.78, -0.25, 0.58)).normalized()   # screen top-left, toward camera
OUTLINE = (0.118, 0.102, 0.122)


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c) + (1.0,)


# ---------------------------------------------------------------------------
# scene
# ---------------------------------------------------------------------------

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 12
    sc.cycles.use_denoising = False
    sc.cycles.max_bounces = 0
    sc.cycles.transparent_max_bounces = 16
    sc.cycles.filter_width = 1.2
    sc.render.film_transparent = True
    sc.render.resolution_x, sc.render.resolution_y = FRAME_W, FRAME_H
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.0
    sc.world = world
    # camera: orthographic, 30 deg down, looking toward +Y
    cam_d = bpy.data.cameras.new("Cam")
    cam_d.type = "ORTHO"
    cam_d.sensor_fit = "VERTICAL"
    cam_d.ortho_scale = FRAME_H / PPU
    cam = bpy.data.objects.new("Cam", cam_d)
    sc.collection.objects.link(cam)
    fwd = Vector((0, math.cos(ELEV), -math.sin(ELEV)))
    up = Vector((0, math.sin(ELEV), math.cos(ELEV)))
    # feet (origin) must land on PIVOT: frame centre is (PIVOT_y - H/2) px above it
    target = up * ((PIVOT[1] - FRAME_H / 2) / PPU) + Vector((0, 0, 0))
    cam.location = target - fwd * 30
    cam.rotation_euler = Euler((math.radians(90) - ELEV, 0, 0), "XYZ")
    cam_d.shift_x = (FRAME_W / 2 - PIVOT[0]) / FRAME_H
    sc.camera = cam
    return sc


def toon_material(name, hexcol, rim=0.35, tex=0.06, spec=0.0, term=0.40):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    N = nt.nodes
    L = nt.links
    N.clear()
    out = N.new("ShaderNodeOutputMaterial")
    geo = N.new("ShaderNodeNewGeometry")
    # lambert vs fixed screen-space light
    dot = N.new("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = LIGHT
    L.new(geo.outputs["Normal"], dot.inputs[0])
    ramp = N.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "LINEAR"
    e = ramp.color_ramp.elements
    e[0].position, e[0].color = 0.0, (0.17, 0.12, 0.22, 1)      # near-black shadow shapes
    e[1].position, e[1].color = 1.0, (1.08, 1.03, 0.96, 1)
    k1 = e.new(term); k1.color = (0.22, 0.16, 0.28, 1)
    k2 = e.new(term + 0.015); k2.color = (0.06, 0.05, 0.08, 1)           # ink line on the terminator
    k3 = e.new(term + 0.045); k3.color = (0.06, 0.05, 0.08, 1)
    k4 = e.new(term + 0.06); k4.color = (0.96, 0.92, 0.88, 1)
    mapr = N.new("ShaderNodeMapRange")
    mapr.inputs["From Min"].default_value = -0.35
    mapr.inputs["From Max"].default_value = 1.0
    L.new(dot.outputs["Value"], mapr.inputs["Value"])
    L.new(mapr.outputs["Result"], ramp.inputs["Fac"])
    base = N.new("ShaderNodeRGB"); base.outputs[0].default_value = srgb(hexcol)
    # painted texture: low-frequency noise nudging the base colour
    tc = N.new("ShaderNodeTexCoord")
    noise = N.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 18.0
    noise.inputs["Detail"].default_value = 3.0
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
    # rim light on the lit silhouette
    lw = N.new("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.25
    rimr = N.new("ShaderNodeMapRange")
    rimr.inputs["From Min"].default_value = 0.55
    rimr.inputs["From Max"].default_value = 0.9
    rimr.inputs["To Max"].default_value = min(1.0, rim * 1.8)
    L.new(lw.outputs["Facing"], rimr.inputs["Value"])
    lit = N.new("ShaderNodeMath"); lit.operation = "GREATER_THAN"; lit.inputs[1].default_value = 0.15
    L.new(dot.outputs["Value"], lit.inputs[0])
    rimf = N.new("ShaderNodeMath"); rimf.operation = "MULTIPLY"
    L.new(rimr.outputs["Result"], rimf.inputs[0]); L.new(lit.outputs[0], rimf.inputs[1])
    rimc = N.new("ShaderNodeMix"); rimc.data_type = "RGBA"; rimc.blend_type = "MIX"
    L.new(rimf.outputs[0], rimc.inputs[0])
    L.new(mul2.outputs[0], rimc.inputs[6])
    rimc.inputs[7].default_value = (1.0, 0.78, 0.35, 1)
    col_out = rimc.outputs[2]
    if spec > 0:
        # metal: tight warm highlight
        sp = N.new("ShaderNodeMapRange")
        sp.inputs["From Min"].default_value = 0.78
        sp.inputs["From Max"].default_value = 0.9
        sp.inputs["To Max"].default_value = spec
        L.new(dot.outputs["Value"], sp.inputs["Value"])
        spc = N.new("ShaderNodeMix"); spc.data_type = "RGBA"
        L.new(sp.outputs["Result"], spc.inputs[0]); L.new(col_out, spc.inputs[6])
        spc.inputs[7].default_value = (1.0, 0.93, 0.75, 1)
        col_out = spc.outputs[2]
    em = N.new("ShaderNodeEmission")
    L.new(col_out, em.inputs["Color"])
    L.new(em.outputs[0], out.inputs["Surface"])
    return m


def outline_material():
    m = bpy.data.materials.new("Ink")
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    N.clear()
    out = N.new("ShaderNodeOutputMaterial")
    geo = N.new("ShaderNodeNewGeometry")
    em = N.new("ShaderNodeEmission"); em.inputs["Color"].default_value = srgb("#1E1A1F")
    tr = N.new("ShaderNodeBsdfTransparent")
    mix = N.new("ShaderNodeMixShader")
    L.new(geo.outputs["Backfacing"], mix.inputs[0])
    L.new(em.outputs[0], mix.inputs[1]); L.new(tr.outputs[0], mix.inputs[2])
    L.new(mix.outputs[0], out.inputs["Surface"])
    return m


# ---------------------------------------------------------------------------
# geometry helpers
# ---------------------------------------------------------------------------

class Builder:
    def __init__(self, palette):
        self.mats = {}
        self.palette = palette
        self.ink = outline_material()
        self.parts = []   # (obj, bone)

    def mat(self, key):
        if key not in self.mats:
            hexcol, rim, spec = self.palette[key]
            self.mats[key] = toon_material(key, hexcol, rim=rim, spec=spec)
        return self.mats[key]

    def finish_obj(self, obj, key, bone, ink=0.010, smooth=True):
        obj.data.materials.append(self.mat(key))
        obj.data.materials.append(self.ink)
        if smooth:
            for p in obj.data.polygons:
                p.use_smooth = True
        if ink > 0:
            sol = obj.modifiers.new("ink", "SOLIDIFY")
            sol.thickness = ink
            sol.offset = 1.0
            sol.use_flip_normals = True
            sol.material_offset = 1
            sol.use_rim = False
        self.parts.append((obj, bone))
        return obj

    def link(self, name, me):
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        return obj

    def sphere(self, name, loc, r, key, bone, scale=(1, 1, 1), rot=(0, 0, 0), seg=24, ink=0.010, cut=None):
        me = bpy.data.meshes.new(name)
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=r)
        if cut is not None:   # keep only z >= cut*r (dome)
            geom = [v for v in bm.verts if v.co.z < cut * r - 1e-6]
            bmesh.ops.delete(bm, geom=geom, context="VERTS")
        bm.to_mesh(me); bm.free()
        obj = self.link(name, me)
        obj.location, obj.scale, obj.rotation_euler = loc, scale, rot
        return self.finish_obj(obj, key, bone, ink)

    def cyl(self, name, loc, r, depth, key, bone, rot=(0, 0, 0), scale=(1, 1, 1), seg=20, ink=0.008, r2=None):
        me = bpy.data.meshes.new(name)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=depth)
        bm.to_mesh(me); bm.free()
        obj = self.link(name, me)
        obj.location, obj.rotation_euler, obj.scale = loc, rot, scale
        return self.finish_obj(obj, key, bone, ink)

    def box(self, name, loc, size, key, bone, rot=(0, 0, 0), bevel=0.01, ink=0.008):
        me = bpy.data.meshes.new(name)
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=size, verts=bm.verts)
        bm.to_mesh(me); bm.free()
        obj = self.link(name, me)
        obj.location, obj.rotation_euler = loc, rot
        if bevel:
            b = obj.modifiers.new("bev", "BEVEL"); b.width = bevel; b.segments = 3
        return self.finish_obj(obj, key, bone, ink, smooth=bool(bevel))

    def torus(self, name, loc, R, r, key, bone, rot=(0, 0, 0), scale=(1, 1, 1), ink=0.006):
        me = bpy.data.meshes.new(name)
        bm = bmesh.new()
        seg_u, seg_v = 28, 10
        verts = []
        for i in range(seg_u):
            a = 2 * math.pi * i / seg_u
            row = []
            for j in range(seg_v):
                b = 2 * math.pi * j / seg_v
                row.append(bm.verts.new(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b))))
            verts.append(row)
        for i in range(seg_u):
            for j in range(seg_v):
                bm.faces.new((verts[i][j], verts[(i + 1) % seg_u][j], verts[(i + 1) % seg_u][(j + 1) % seg_v], verts[i][(j + 1) % seg_v]))
        bm.to_mesh(me); bm.free()
        obj = self.link(name, me)
        obj.location, obj.rotation_euler, obj.scale = loc, rot, scale
        return self.finish_obj(obj, key, bone, ink)

    def skin_body(self, name, nodes, edges, region_fn):
        """Skin-modifier body. nodes: {key: (co, (rx, ry))}. region_fn(co) -> material key."""
        me = bpy.data.meshes.new(name)
        keys = list(nodes)
        me.from_pydata([nodes[k][0] for k in keys], [(keys.index(a), keys.index(b)) for a, b in edges], [])
        obj = self.link(name, me)
        sk = obj.modifiers.new("skin", "SKIN")
        sk.use_smooth_shade = True
        sk.branch_smoothing = 0.6
        sd = obj.modifiers.new("sub", "SUBSURF")
        sd.levels = 3
        for i, k in enumerate(keys):
            obj.data.skin_vertices[0].data[i].radius = nodes[k][1]
        obj.data.skin_vertices[0].data[keys.index("pelvis")].use_root = True
        dg = bpy.context.evaluated_depsgraph_get()
        me2 = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
        bpy.data.objects.remove(obj)
        body = self.link(name, me2)
        order = []
        for poly in body.data.polygons:
            k = region_fn(Vector(poly.center))
            if k not in order:
                order.append(k)
        for k in order:
            body.data.materials.append(self.mat(k))
        body.data.materials.append(self.ink)
        for poly in body.data.polygons:
            poly.material_index = order.index(region_fn(Vector(poly.center)))
            poly.use_smooth = True
        sol = body.modifiers.new("ink", "SOLIDIFY")
        sol.thickness = 0.011; sol.offset = 1.0; sol.use_flip_normals = True
        sol.material_offset = len(order); sol.use_rim = False
        return body


# ---------------------------------------------------------------------------
# armature + skinning
# ---------------------------------------------------------------------------

def make_armature(J):
    """J: joint positions. Returns armature object with named bones."""
    arm_d = bpy.data.armatures.new("Rig")
    arm = bpy.data.objects.new("Rig", arm_d)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_d.edit_bones
    spec = [
        ("root", J["pelvis"] + Vector((0, 0, -0.1)), J["pelvis"], None),
        ("spine", J["pelvis"], J["chest"], "root"),
        ("neck", J["chest"], J["neck"], "spine"),
        ("head", J["neck"], J["head_top"], "neck"),
    ]
    for s in ("L", "R"):
        spec += [
            ("upper_arm." + s, J["shoulder." + s], J["elbow." + s], "spine"),
            ("forearm." + s, J["elbow." + s], J["wrist." + s], "upper_arm." + s),
            ("hand." + s, J["wrist." + s], J["hand." + s], "forearm." + s),
            ("thigh." + s, J["hip." + s], J["knee." + s], "root"),
            ("shin." + s, J["knee." + s], J["ankle." + s], "thigh." + s),
            ("foot." + s, J["ankle." + s], J["toe." + s], "shin." + s),
        ]
    for name, h, t, par in spec:
        b = eb.new(name)
        b.head, b.tail = h, t
        # roll so local X stays world X (swing about X = forward/back)
        b.align_roll(Vector((0, -1, 0)) if abs((t - h).normalized().z) > 0.7 else Vector((0, 0, 1)))
        if par:
            b.parent = eb[par]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    return arm


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def skin_to_armature(body, arm, allowed_fn):
    bones = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm.data.bones if b.name != "root"}
    groups = {n: body.vertex_groups.new(name=n) for n in bones}
    for v in body.data.vertices:
        p = v.co
        cand = allowed_fn(p)
        ds = sorted(((seg_dist(p, *bones[n]), n) for n in cand))
        best = ds[:2]
        ws = [1.0 / max(d, 0.005) ** 6 for d, _ in best]
        tot = sum(ws)
        for (d, n), w in zip(best, ws):
            groups[n].add([v.index], w / tot, "REPLACE")
    mod = body.modifiers.new("arm", "ARMATURE")
    mod.object = arm
    # armature must run before the ink solidify
    body.modifiers.move(body.modifiers.find("arm"), 0)
    body.parent = arm


def attach(parts, arm):
    for obj, bone in parts:
        if bone is None:
            continue
        mw = obj.matrix_world.copy()
        obj.parent = arm
        obj.parent_type = "BONE"
        obj.parent_bone = bone
        b = arm.data.bones[bone]
        obj.matrix_parent_inverse = (arm.matrix_world @ b.matrix_local @ Matrix.Translation((0, b.length, 0))).inverted()
        obj.matrix_world = mw


# ---------------------------------------------------------------------------
# animation (keyframes on pose bones; local X = swing forward/back)
# ---------------------------------------------------------------------------

def key_pose(arm, frame, pose, root_z=0.0, root_rot_z=0.0):
    for pb in arm.pose.bones:
        r = pose.get(pb.name, (0, 0, 0))
        pb.rotation_euler = Euler([math.radians(x) for x in r], "XYZ")
        pb.keyframe_insert("rotation_euler", frame=frame)
    root = arm.pose.bones["root"]
    root.location = (0, 0, 0)
    root.location.y = root_z    # bone Y points up for the root
    root.keyframe_insert("location", frame=frame)


def anim_pose(kind, t, weapon=True, akimbo=False):
    """t in [0,1). Returns (pose dict, root bob)."""
    P = {}
    s = math.sin(2 * math.pi * t)
    c = math.cos(2 * math.pi * t)
    if kind == "idle":
        breath = math.sin(2 * math.pi * t)
        # contrapposto: weight on the right leg, left knee relaxed, S-curve
        P["spine"] = (1.5 * breath, 0, 8)
        P["neck"] = (0, 0, -5)
        P["head"] = (-1.0 * breath, 6, -5)
        P["thigh.L"] = (8, 0, -5)
        P["shin.L"] = (12, 0, 0)
        P["foot.L"] = (-6, 0, 0)
        P["thigh.R"] = (-2, 0, 2)
        P["upper_arm.L"] = (4, 0, -6 - 1.5 * breath)
        P["upper_arm.R"] = (10 if weapon else 2, 0, 6 + 1.5 * breath)
        P["forearm.L"] = (16, 0, 0)
        P["forearm.R"] = (10 if weapon else 14, 0, 0)
        bob = -0.006 * (1 - breath) / 2
    elif kind == "walk":
        sw = 28 * s
        P["thigh.L"] = (-sw, 0, 0)
        P["thigh.R"] = (sw, 0, 0)
        P["shin.L"] = (max(0, 40 * math.sin(2 * math.pi * t + 1.2)), 0, 0)
        P["shin.R"] = (max(0, -40 * math.sin(2 * math.pi * t + 1.2)), 0, 0)
        P["foot.L"] = (8 * s, 0, 0)
        P["foot.R"] = (-8 * s, 0, 0)
        P["upper_arm.L"] = (sw * 0.8, 0, -5)
        P["upper_arm.R"] = (-sw * 0.8 * (0.5 if weapon else 1.0), 0, 5)
        P["forearm.L"] = (20, 0, 0)
        P["forearm.R"] = (25, 0, 0)
        P["spine"] = (-6, 0, 4 * s)
        P["head"] = (3, 0, -3 * s)
        bob = -0.025 * abs(c)
    else:  # attack: wind up overhead, smash down in front, recover
        if t < 0.34:
            u = t / 0.34
            ua, fa, sp = 165 * u, -50 * u, (-10 * u, 0, 16 * u)
        elif t < 0.6:
            u = (t - 0.34) / 0.26
            ua, fa, sp = 165 - 140 * u, -50 + 45 * u, (-10 + 28 * u, 0, 16 - 34 * u)
        else:
            u = (t - 0.6) / 0.4
            ua, fa, sp = 25 - 25 * u, -5 - 9 * u, (18 - 18 * u, 0, -18 + 18 * u)
        P["upper_arm.R"] = (ua, 0, 8)
        P["forearm.R"] = (fa, 0, 0)
        P["spine"] = sp
        P["upper_arm.L"] = (-20, 0, -12)
        P["forearm.L"] = (-40, 0, 0)
        P["thigh.L"] = (14, 0, 0)
        P["thigh.R"] = (-12, 0, 0)
        P["shin.R"] = (12, 0, 0)
        bob = -0.02
    if akimbo:
        P["upper_arm.R"] = (-10, 0, 35)
        P["forearm.R"] = (-20, 0, -110)
    return P, bob


# ---------------------------------------------------------------------------
# characters
# ---------------------------------------------------------------------------

def body_joints(h=1.0, shoulder=0.2, hip=0.1):
    J = {
        "pelvis": Vector((0, 0, 0.95 * h)),
        "chest": Vector((0, 0, 1.30 * h)),
        "neck": Vector((0, 0, 1.48 * h)),
        "head_top": Vector((0, 0, 1.78 * h)),
    }
    for s, sx in (("L", 1), ("R", -1)):
        # character faces -Y; its left is +X when seen from the front
        J["shoulder." + s] = Vector((sx * shoulder, 0.0, 1.41 * h))
        J["elbow." + s] = Vector((sx * (shoulder + 0.055), 0.03, 1.17 * h))
        J["wrist." + s] = Vector((sx * (shoulder + 0.085), -0.03, 0.96 * h))
        J["hand." + s] = Vector((sx * (shoulder + 0.095), -0.04, 0.89 * h))
        J["hip." + s] = Vector((sx * hip, 0, 0.90 * h))
        J["knee." + s] = Vector((sx * hip, -0.02, 0.50 * h))
        J["ankle." + s] = Vector((sx * hip, 0.01, 0.09 * h))
        J["toe." + s] = Vector((sx * hip, -0.13, 0.03 * h))
    return J


def build_body(B, J, R, region_fn):
    nodes = {
        "pelvis": (J["pelvis"], R["pelvis"]),
        "waist": (J["pelvis"].lerp(J["chest"], 0.45), R["waist"]),
        "chest": (J["chest"], R["chest"]),
        "neck": (J["neck"], R["neck"]),
        "neck_top": (J["neck"] + Vector((0, 0, 0.06)), R["neck"]),
    }
    edges = [("pelvis", "waist"), ("waist", "chest"), ("chest", "neck"), ("neck", "neck_top")]
    for s in ("L", "R"):
        nodes["shoulder." + s] = (J["shoulder." + s], R["shoulder"])
        nodes["elbow." + s] = (J["elbow." + s], R["elbow"])
        nodes["wrist." + s] = (J["wrist." + s], R["wrist"])
        nodes["hip." + s] = (J["hip." + s], R["hip"])
        nodes["knee." + s] = (J["knee." + s], R["knee"])
        nodes["ankle." + s] = (J["ankle." + s], R["ankle"])
        edges += [("chest", "shoulder." + s), ("shoulder." + s, "elbow." + s), ("elbow." + s, "wrist." + s),
                  ("pelvis", "hip." + s), ("hip." + s, "knee." + s), ("knee." + s, "ankle." + s)]
    return B.skin_body("Body", nodes, edges, region_fn)


def allowed_bones(p):
    x, z = p.x, p.z
    if z > 1.47:
        return ["neck", "head"]
    if abs(x) > 0.17 and z > 0.78:
        s = "L" if x > 0 else "R"
        return ["spine", "upper_arm." + s, "forearm." + s, "hand." + s]
    if z < 0.88:
        s = "L" if x > 0 else "R"
        return ["thigh." + s, "shin." + s, "foot." + s]
    return ["spine", "neck", "thigh.L", "thigh.R"]


HS = 0.95   # stylised big head


def head_common(B, J, skin_key, eye_key="eye", brow_key="hair", nose=True, scale=1.0, cool=False):
    hc = J["neck"] + Vector((0, 0, 0.17))
    B.sphere("Head", hc, 0.125 * scale, skin_key, "head", scale=(0.95, 1.0, 1.08))
    # jaw / chin forward
    B.sphere("Jaw", hc + Vector((0, -0.04, -0.065)), 0.085 * scale, skin_key, "head", scale=(0.92 if cool else 1.0, 1.0, 0.85 if cool else 0.8), ink=0.0)
    if nose:
        B.sphere("Nose", hc + Vector((0, -0.125, -0.01)), 0.022, skin_key, "head", scale=(0.8, 1.0, 1.1), ink=0.004)
    for sx in (1, -1):
        B.sphere("Ear", hc + Vector((sx * 0.118, 0.01, -0.005)), 0.03, skin_key, "head", scale=(0.5, 0.8, 1.1), ink=0.004)
        B.sphere("EyeW", hc + Vector((sx * 0.047, -0.106, 0.012)), 0.027, "eye_white", "head", scale=(1.0, 0.5, 0.85), ink=0.0)
        B.sphere("Eye", hc + Vector((sx * 0.047, -0.117, 0.010)), 0.018, eye_key, "head", scale=(1.0, 0.5, 1.2), ink=0.0)
        B.box("Brow", hc + Vector((sx * 0.048, -0.110, 0.045 if cool else 0.052)), (0.058, 0.014, 0.016 if cool else 0.012), brow_key, "head",
              rot=(0, sx * math.radians(18 if cool else -8), 0), bevel=0.004, ink=0.0)
    if cool:
        # upper lids flatten the eyes into a focused look
        for sx in (1, -1):
            B.box("Lid", hc + Vector((sx * 0.047, -0.118, 0.03)), (0.06, 0.012, 0.018), skin_key, "head", bevel=0.004, ink=0.0)
        B.box("Mouth", hc + Vector((-0.012, -0.112, -0.062)), (0.034, 0.01, 0.007), "mouth", "head", rot=(0, math.radians(10), 0), bevel=0.003, ink=0.0)
        B.box("Scar", hc + Vector((-0.07, -0.098, -0.02)), (0.006, 0.01, 0.035), "mouth", "head", rot=(0, math.radians(20), 0), bevel=0.002, ink=0.0)
    else:
        B.box("Mouth", hc + Vector((0, -0.112, -0.062)), (0.04, 0.01, 0.008), "mouth", "head", bevel=0.003, ink=0.0)
    return hc


def boots(B, J, key, sole="sole", h=0.13):
    for s in ("L", "R"):
        a = J["ankle." + s]
        B.box("Boot", Vector((a.x, a.y - 0.04, 0.06)), (0.11, 0.24, 0.12), key, "foot." + s, bevel=0.035)
        B.box("Sole", Vector((a.x, a.y - 0.045, 0.012)), (0.115, 0.25, 0.024), sole, "foot." + s, bevel=0.008)
        B.cyl("BootTop", Vector((a.x, a.y, 0.15)), 0.065, h, key, "shin." + s)


def hands(B, J, key, size=0.052):
    for s in ("L", "R"):
        B.sphere("Hand", J["hand." + s], size * 1.15, key, "hand." + s, scale=(0.8, 1.0, 1.15))


PALETTES = {
    "rider": {
        "skin": ("#E2A878", 0.3, 0), "shirt": ("#24423F", 0.45, 0), "vest": ("#E8762D", 0.35, 0),
        "pants": ("#1F1D24", 0.45, 0), "boot": ("#5E3A22", 0.4, 0.2), "sole": ("#2B2629", 0.1, 0),
        "helmet": ("#2F5F5A", 0.45, 0.6), "brass": ("#C9A04A", 0.5, 0.9), "lens": ("#F0A13A", 0.6, 1.0),
        "strap": ("#5A3A22", 0.2, 0), "hair": ("#1E1A1C", 0.3, 0.2), "eye": ("#140F12", 0, 0),
        "eye_white": ("#F2EEE6", 0, 0), "mouth": ("#7A3A2E", 0, 0), "reflect": ("#E3E8EA", 0.5, 0.5),
        "belt": ("#4A2E1A", 0.2, 0), "wrench_red": ("#C0392B", 0.4, 0.5), "steel": ("#A7B0B8", 0.5, 0.9),
        "scarf": ("#B8322A", 0.4, 0), "vest_d": ("#A84E1C", 0.3, 0), "glove": ("#3A2A22", 0.3, 0.2),
    },
    "lung_pradit": {
        "skin": ("#C98E62", 0.3, 0), "shirt": ("#EFEBE2", 0.3, 0), "apron": ("#3C5A8A", 0.3, 0),
        "pants": ("#6B4A32", 0.3, 0), "sandal": ("#2E6E8E", 0.2, 0), "sole": ("#2B2629", 0.1, 0),
        "cap": ("#7A5232", 0.35, 0.1), "hair": ("#E6E2DA", 0.3, 0), "eye": ("#140F12", 0, 0),
        "eye_white": ("#F2EEE6", 0, 0), "mouth": ("#6A3A2E", 0, 0), "brass": ("#C9A04A", 0.5, 0.9),
    },
    "je_muay": {
        "skin": ("#EBC09A", 0.3, 0), "blouse": ("#E58FB0", 0.35, 0), "apron": ("#EFE3C8", 0.3, 0),
        "pants": ("#4A2A55", 0.3, 0), "shoe": ("#2B2629", 0.3, 0.3), "sole": ("#1A1619", 0.1, 0),
        "hair": ("#17131A", 0.35, 0.3), "eye": ("#140F12", 0, 0), "eye_white": ("#F2EEE6", 0, 0),
        "mouth": ("#B8322A", 0, 0), "brass": ("#C9A04A", 0.5, 0.9),
    },
}


def build_rider(B):
    J = body_joints(shoulder=0.235, hip=0.1)
    # heroic V: broad chest, narrow waist, longer legs
    J["knee.L"].z = J["knee.R"].z = 0.49
    R = {"pelvis": (0.13, 0.1), "waist": (0.12, 0.09), "chest": (0.215, 0.13), "neck": (0.055, 0.055),
         "shoulder": (0.075, 0.075), "elbow": (0.055, 0.055), "wrist": (0.045, 0.045),
         "hip": (0.092, 0.092), "knee": (0.066, 0.066), "ankle": (0.054, 0.054)}

    def region(p):
        if p.z > 1.47:
            return "skin"
        if abs(p.x) > 0.225 and p.z > 0.8:
            return "shirt"
        if p.z < 0.93:
            return "pants"
        if 1.085 < p.z < 1.125 or 1.175 < p.z < 1.215:
            return "reflect"
        if p.y > 0.07 and 1.25 < p.z < 1.38 and abs(p.x) < 0.085:
            return "reflect"
        return "vest"
    body = build_body(B, J, R, region)
    hc = head_common(B, J, "skin", brow_key="hair", cool=True)
    # messy hair: back mass + spiky fringe poking out under the helmet
    B.sphere("Hair", hc + Vector((0, 0.03, 0.0)), 0.128, "hair", "head", scale=(0.98, 1.0, 1.02), ink=0.0)
    for x, ry in ((-0.06, -18), (-0.02, -6), (0.02, 6), (0.06, 18)):
        B.cyl("Spike", hc + Vector((x, -0.112, 0.06)), 0.024, 0.055, "hair", "head", r2=0.003,
              rot=(math.radians(160), math.radians(ry), 0), ink=0.004)
    # half helmet + brim + rivets, goggles pushed up with amber lenses
    B.sphere("Helmet", hc + Vector((0, 0.02, 0.075)), 0.14, "helmet", "head", scale=(1.0, 1.08, 0.88), cut=0.05)
    B.torus("Brim", hc + Vector((0, 0.02, 0.083)), 0.138, 0.011, "brass", "head", scale=(1.0, 1.08, 1.0))
    B.torus("GStrap", hc + Vector((0, 0.02, 0.12)), 0.128, 0.009, "strap", "head", rot=(math.radians(-14), 0, 0), scale=(1.0, 1.06, 1.0))
    for sx in (1, -1):
        g = hc + Vector((sx * 0.05, -0.09, 0.16))
        B.torus("Goggle", g, 0.033, 0.012, "brass", "head", rot=(math.radians(58), 0, 0))
        B.sphere("Lens", g + Vector((0, 0.004, -0.002)), 0.032, "lens", "head", scale=(1, 0.45, 1), rot=(math.radians(-32), 0, 0), ink=0.0)
    # red bandana knotted at the neck
    B.torus("Scarf", J["neck"] + Vector((0, -0.005, -0.015)), 0.065, 0.03, "scarf", "spine", scale=(1.0, 1.0, 0.9), ink=0.007)
    B.sphere("ScarfTip", J["neck"] + Vector((0.03, -0.07, -0.06)), 0.045, "scarf", "spine", scale=(0.8, 0.35, 1.2), rot=(0, math.radians(-20), 0), ink=0.006)
    # vest: high collar, front zip, reflective strips, chest pocket, shoulder pads
    B.torus("Collar", J["neck"] + Vector((0, 0.01, -0.05)), 0.085, 0.024, "vest_d", "spine", scale=(1.15, 1.0, 1.0), ink=0.007)
    B.box("Zip", Vector((0.0, -0.125, 1.16)), (0.014, 0.01, 0.38), "vest_d", "spine", bevel=0.003, ink=0.0)
    B.box("Pocket", Vector((0.1, -0.122, 1.27)), (0.07, 0.014, 0.06), "vest_d", "spine", rot=(0, 0, math.radians(-16)), bevel=0.006, ink=0.004)
    # --- silhouette breakers (from the reference study) ---
    # long red scarf tails flowing back and to the side
    n = J["neck"]
    # knot at the front-left of the neck, two wide tails swept out to the side and back
    B.sphere("Knot", n + Vector((0.05, -0.06, -0.05)), 0.035, "scarf", "spine", ink=0.006)
    for k, (rx, ry, L, w) in enumerate(((60, -55, 0.36, 0.06), (48, -75, 0.28, 0.05))):
        B.cyl("ScarfTail", n + Vector((0.12 + 0.03 * k, -0.02 + 0.04 * k, -0.1 - 0.03 * k)), w, L, "scarf", "spine", r2=0.008,
              rot=(math.radians(rx), math.radians(ry), 0), scale=(1.0, 0.28, 1.0), ink=0.006)
    # spiky hair poking out behind the helmet
    for x, rz in ((-0.07, -30), (0.0, 0), (0.07, 30)):
        B.cyl("BackSpike", hc + Vector((x, 0.12, -0.01)), 0.03, 0.09, "hair", "head", r2=0.002,
              rot=(math.radians(-70), 0, math.radians(rz)), ink=0.004)
    # brass shoulder guard on the weapon side only (layered plates)
    sR = J["shoulder.R"]
    for k in range(3):
        B.sphere("Guard", sR + Vector((0.025, 0.0, 0.04 - k * 0.04)), 0.09 - k * 0.012, "brass", "upper_arm.R",
                 scale=(0.95, 1.0, 0.4), rot=(0, math.radians(-25), 0), cut=0.0, ink=0.007)
    # leather bandolier across the chest with a brass gauge pouch
    B.box("Strap", Vector((0.0, -0.125, 1.2)), (0.045, 0.02, 0.5), "belt", "spine", rot=(0, math.radians(38), 0), bevel=0.006, ink=0.005)
    B.box("Strap2", Vector((0.0, 0.125, 1.2)), (0.045, 0.02, 0.5), "belt", "spine", rot=(0, math.radians(-38), 0), bevel=0.006, ink=0.005)
    B.cyl("StrapGauge", Vector((-0.07, -0.142, 1.28)), 0.035, 0.022, "brass", "spine", rot=(math.radians(90), 0, 0))
    B.cyl("StrapGaugeFace", Vector((-0.07, -0.155, 1.28)), 0.026, 0.005, "eye_white", "spine", rot=(math.radians(90), 0, 0), ink=0.0)
    # bandage wraps on the free forearm
    for k in range(3):
        w = J["elbow.L"].lerp(J["wrist.L"], 0.35 + 0.2 * k)
        B.torus("Wrap", w, 0.05, 0.012, "eye_white", "forearm.L", rot=(math.radians(8), 0, 0), ink=0.003)
    # belt, buckle, gauge, pouch
    B.torus("Belt", Vector((0, 0, 0.96)), 0.142, 0.022, "belt", "spine", scale=(1.0, 0.78, 1.0), ink=0.006)
    B.box("Buckle", Vector((0, -0.115, 0.96)), (0.055, 0.016, 0.045), "brass", "spine", bevel=0.006)
    B.cyl("Gauge", Vector((-0.12, -0.08, 0.95)), 0.034, 0.022, "brass", "spine", rot=(math.radians(90), 0, math.radians(-35)))
    B.cyl("GaugeFace", Vector((-0.126, -0.092, 0.95)), 0.025, 0.006, "eye_white", "spine", rot=(math.radians(90), 0, math.radians(-35)), ink=0.0)
    B.box("Pouch", Vector((0.14, -0.04, 0.9)), (0.06, 0.07, 0.08), "belt", "spine", bevel=0.012)
    boots(B, J, "boot", h=0.18)
    for s in ("L", "R"):
        a = J["ankle." + s]
        B.torus("BootStrap", Vector((a.x, a.y, 0.17)), 0.068, 0.009, "brass", "shin." + s, ink=0.003)
    hands(B, J, "glove")
    # big pipe wrench (handle down, jaw forward)
    hR = J["hand.R"]
    B.cyl("WHandle", hR + Vector((0, -0.03, -0.2)), 0.026, 0.58, "wrench_red", "hand.R", rot=(math.radians(-12), 0, 0))
    B.box("WJaw", hR + Vector((0, -0.1, -0.52)), (0.08, 0.18, 0.08), "steel", "hand.R", bevel=0.014)
    B.box("WHook", hR + Vector((0, -0.18, -0.44)), (0.075, 0.055, 0.15), "steel", "hand.R", bevel=0.012)
    B.cyl("WNut", hR + Vector((0, -0.09, -0.42)), 0.038, 0.085, "brass", "hand.R", rot=(0, math.radians(90), 0))
    return J, body, dict(weapon=True)


def build_lung(B):
    J = body_joints(h=0.96, shoulder=0.205)
    R = {"pelvis": (0.16, 0.13), "waist": (0.16, 0.13), "chest": (0.17, 0.12), "neck": (0.05, 0.05),
         "shoulder": (0.062, 0.062), "elbow": (0.046, 0.046), "wrist": (0.04, 0.04),
         "hip": (0.085, 0.085), "knee": (0.06, 0.06), "ankle": (0.045, 0.045)}

    def region(p):
        if p.z > 1.40:
            return "skin"
        if abs(p.x) > 0.19 and p.z > 0.8:
            return "shirt" if p.z > 1.22 else "skin"
        if p.z < 0.88:
            return "pants"
        if p.y < -0.06 and p.z < 1.27 and abs(p.x) < 0.16:
            return "apron"
        return "shirt"
    body = build_body(B, J, R, region)
    hc = head_common(B, J, "skin", brow_key="hair")
    B.sphere("Hair", hc + Vector((0, 0.035, -0.02)), 0.126, "hair", "head", scale=(0.99, 1.0, 0.9), ink=0.0)
    # cap: dome + visor forward
    B.sphere("Cap", hc + Vector((0, 0.005, 0.035)), 0.135, "cap", "head", scale=(1.0, 1.05, 0.9), cut=0.0)
    B.box("Visor", hc + Vector((0, -0.15, 0.04)), (0.16, 0.12, 0.014), "cap", "head", rot=(math.radians(-10), 0, 0), bevel=0.02)
    B.sphere("Button", hc + Vector((0, 0.005, 0.158)), 0.014, "cap", "head")
    # moustache
    for sx in (1, -1):
        B.sphere("Stache", hc + Vector((sx * 0.03, -0.118, -0.04)), 0.03, "hair", "head", scale=(1.3, 0.6, 0.55), rot=(0, sx * math.radians(18), 0), ink=0.004)
    # apron strap + skirt over the thighs
    B.torus("ApronStrap", J["neck"] + Vector((0, -0.02, -0.04)), 0.07, 0.008, "apron", "spine", rot=(math.radians(25), 0, 0), ink=0.003)
    B.box("ApronSkirt", Vector((0, -0.12, 0.74)), (0.3, 0.02, 0.36), "apron", "root", bevel=0.01, ink=0.006)
    B.box("Pocket", Vector((0, -0.138, 1.08)), (0.12, 0.012, 0.08), "apron", "spine", bevel=0.005, ink=0.005)
    # sandals (feet bare)
    for s in ("L", "R"):
        a = J["ankle." + s]
        B.box("Foot", Vector((a.x, a.y - 0.05, 0.05)), (0.09, 0.22, 0.07), "skin", "foot." + s, bevel=0.03)
        B.box("Sandal", Vector((a.x, a.y - 0.05, 0.01)), (0.105, 0.25, 0.02), "sandal", "foot." + s, bevel=0.006)
        B.box("Strap", Vector((a.x, a.y - 0.1, 0.06)), (0.1, 0.02, 0.03), "sandal", "foot." + s, bevel=0.006, ink=0.003)
    hands(B, J, "skin", size=0.05)
    return J, body, dict(weapon=False)


def build_muay(B):
    J = body_joints(h=0.93, shoulder=0.18, hip=0.095)
    R = {"pelvis": (0.155, 0.12), "waist": (0.12, 0.09), "chest": (0.15, 0.11), "neck": (0.042, 0.042),
         "shoulder": (0.055, 0.055), "elbow": (0.042, 0.042), "wrist": (0.035, 0.035),
         "hip": (0.08, 0.08), "knee": (0.055, 0.055), "ankle": (0.042, 0.042)}

    def region(p):
        if p.z > 1.36:
            return "skin"
        if abs(p.x) > 0.17 and p.z > 0.75:
            return "blouse" if p.z > 1.12 else "skin"
        if p.z < 0.84:
            return "pants"
        if p.y < -0.05 and p.z < 1.2 and abs(p.x) < 0.13:
            return "apron"
        return "blouse"
    body = build_body(B, J, R, region)
    hc = head_common(B, J, "skin", brow_key="hair", scale=0.96)
    B.sphere("Hair", hc + Vector((0, 0.03, 0.01)), 0.128, "hair", "head", scale=(1.02, 1.0, 1.03), ink=0.0)
    B.sphere("Bangs", hc + Vector((0, -0.04, 0.07)), 0.11, "hair", "head", scale=(1.05, 0.8, 0.55), ink=0.006)
    B.sphere("Bun", hc + Vector((0, 0.02, 0.17)), 0.07, "hair", "head", scale=(1.0, 1.0, 0.9))
    B.cyl("Pin", hc + Vector((0, 0.02, 0.19)), 0.007, 0.24, "brass", "head", rot=(0, math.radians(70), 0))
    for sx in (1, -1):
        B.torus("Hoop", hc + Vector((sx * 0.12, 0.0, -0.07)), 0.025, 0.004, "brass", "head", rot=(0, math.radians(90), 0), ink=0.0)
        B.box("Lash", hc + Vector((sx * 0.048, -0.118, 0.03)), (0.045, 0.01, 0.008), "hair", "head", bevel=0.003, ink=0.0)
    B.box("ApronSkirt", Vector((0, -0.11, 0.70)), (0.27, 0.02, 0.32), "apron", "root", bevel=0.01, ink=0.006)
    for s in ("L", "R"):
        a = J["ankle." + s]
        B.box("Shoe", Vector((a.x, a.y - 0.04, 0.04)), (0.09, 0.21, 0.07), "shoe", "foot." + s, bevel=0.03)
        B.box("Sole", Vector((a.x, a.y - 0.045, 0.01)), (0.095, 0.22, 0.02), "sole", "foot." + s, bevel=0.006)
    hands(B, J, "skin", size=0.045)
    B.torus("Bangle", J["wrist.L"] + Vector((0, 0, 0.02)), 0.045, 0.007, "brass", "forearm.L", ink=0.0)
    return J, body, dict(weapon=False, akimbo=True)


BUILDERS = {"rider": build_rider, "lung_pradit": build_lung, "je_muay": build_muay}


# ---------------------------------------------------------------------------
# render
# ---------------------------------------------------------------------------

def yaw_for(dir_index):
    """Screen-space direction (y down) -> ground yaw. Model faces -Y at yaw 0."""
    th = math.radians(45 * dir_index)
    gx, gy = math.cos(th), -2.0 * math.sin(th)
    return math.atan2(gy, gx) + math.pi / 2


def main():
    name, out = sys.argv[1], sys.argv[2]
    still = "--still" in sys.argv
    os.makedirs(out, exist_ok=True)
    sc = reset()
    B = Builder(PALETTES[name])
    J, body, opts = BUILDERS[name](B)
    # stylised big head: scale every head piece about the neck
    for obj, bone in B.parts:
        if bone == "head":
            obj.location = J["neck"] + (obj.location - J["neck"]) * HS
            obj.scale = obj.scale * HS
    J["head_top"] = J["neck"] + (J["head_top"] - J["neck"]) * HS
    arm = make_armature(J)
    skin_to_armature(body, arm, allowed_bones)
    attach(B.parts, arm)
    # build actions
    frame = 1
    ranges = {}
    for anim, (n, fps) in ANIMS.items():
        if anim == "attack" and not opts.get("weapon"):
            continue
        ranges[anim] = (frame, n, fps)
        for i in range(n):
            pose, bob = anim_pose(anim, i / n, weapon=opts.get("weapon", False), akimbo=opts.get("akimbo", False))
            key_pose(arm, frame + i, pose, bob)
        frame += n
    tmp = os.path.join(out, "_frames")
    os.makedirs(tmp, exist_ok=True)
    dirs = [2, 0, 1, 6] if still else range(8)
    anims = {k: ranges[k] for k in ("idle", "walk", "attack") if k in ranges} if still else ranges
    for anim, (f0, n, fps) in anims.items():
        for d in dirs:
            arm.rotation_euler = (0, 0, yaw_for(d))
            for i in (range(n) if not still else ([0] if anim == "idle" else [0, n // 4, n // 2])):
                sc.frame_set(f0 + i)
                sc.render.filepath = os.path.join(tmp, "%s_%d_%02d.png" % (anim, d, i))
                bpy.ops.render.render(write_still=True)
    meta = {"frame_size": [FRAME_W, FRAME_H], "pivot": list(PIVOT), "art_scale": 2,
            "directions": DIRS, "anims": {a: {"frames": r[1], "fps": r[2]} for a, r in ranges.items()}}
    with open(os.path.join(out, "sprites.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print("rendered", name)


if __name__ == "__main__":
    main()
