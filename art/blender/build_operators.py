"""Operators: the playable characters (user skins) shown in the Locker, on the
player card and on the main menu.

Every operator is a chunky toy figure on the same simple rig, exported as
art/models/operator_<id>.glb with two clips:

    Idle-loop   breathing, weight shift and a slow look around (3 s loop)
    Pose        a one-shot flourish played when the operator is equipped

The body is built from rigid parts, each bound to one bone (toy style, no
deforming joints), like the zombies. Operators face -Y in Blender (+Z in
Godot) and stand on the origin, about 1.9 m tall.

Material naming contract (see scripts/cosmetics/operators.gd):
    FxHolo*    replaced by the hologram shader (albedo = tint)
    FxGold*    replaced by the sparkling gold shader
    FxGlass*   replaced by a clear glass shader (helmets, visors, globes)
Everything else keeps its flat colour.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403

FPS = 24

BONES = [
    # name, head, tail, parent
    ("Hips", (0, 0, 0.84), (0, 0, 1.0), None),
    ("Spine", (0, 0, 1.0), (0, 0, 1.36), "Hips"),
    ("Head", (0, 0, 1.38), (0, 0, 1.9), "Spine"),
    ("UpperArm.L", (0.33, 0, 1.3), (0.37, 0, 1.04), "Spine"),
    ("ForeArm.L", (0.37, 0, 1.04), (0.39, 0, 0.78), "UpperArm.L"),
    ("UpperArm.R", (-0.33, 0, 1.3), (-0.37, 0, 1.04), "Spine"),
    ("ForeArm.R", (-0.37, 0, 1.04), (-0.39, 0, 0.78), "UpperArm.R"),
    ("Thigh.L", (0.13, 0, 0.84), (0.13, 0, 0.48), "Hips"),
    ("Shin.L", (0.13, 0, 0.48), (0.13, 0, 0.08), "Thigh.L"),
    ("Thigh.R", (-0.13, 0, 0.84), (-0.13, 0, 0.48), "Hips"),
    ("Shin.R", (-0.13, 0, 0.48), (-0.13, 0, 0.08), "Thigh.R"),
]

HEAD_Z = 1.62       # centre of the head
FACE_Y = -0.228     # front surface of the head


# ---------------------------------------------------------------------------
# Rig plumbing (same approach as build_zombie.py)
# ---------------------------------------------------------------------------

def build_armature():
    data = bpy.data.armatures.new("OperatorRig")
    ob = bpy.data.objects.new("Armature", data)
    export_collection().objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, tail, parent in BONES:
        eb = data.edit_bones.new(name)
        eb.head, eb.tail = head, tail
        eb.roll = 0.0
        if parent:
            eb.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return ob


def bind(bone, parts):
    """Tag parts with the bone they follow."""
    if not isinstance(parts, (list, tuple)):
        parts = [parts]
    for p in parts:
        p["bone"] = bone
    return list(parts)


def skin(name, parts, armature):
    """Bake + join parts into one skinned mesh, each part weighted to its bone."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    target = bpy.data.objects.new(name, bpy.data.meshes.new(name))
    export_collection().objects.link(target)
    temps = []
    for ob in parts:
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        tmp = bpy.data.objects.new(ob.name + "_bake", me)
        export_collection().objects.link(tmp)
        tmp.matrix_world = ob.matrix_world.copy()
        vg = tmp.vertex_groups.new(name=ob["bone"])
        vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
        temps.append(tmp)
    bpy.context.view_layer.update()
    with bpy.context.temp_override(active_object=target, object=target,
                                   selected_objects=[target] + temps,
                                   selected_editable_objects=[target] + temps):
        bpy.ops.object.join()
    for p in target.data.polygons:
        p.use_smooth = True
    mod = target.modifiers.new("Armature", "ARMATURE")
    mod.object = armature
    target.parent = armature
    return target


def set_pose(armature, frame, pose, hips_loc=(0, 0, 0)):
    """Key every bone at `frame`. `pose` maps bone -> (rx, ry, rz) in degrees in
    armature axes (X = lean forward +, Y = roll / splay, Z = turn left +)."""
    for pb in armature.pose.bones:
        rest = pb.bone.matrix_local.to_quaternion()
        rx, ry, rz = pose.get(pb.name, (0, 0, 0))
        q = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_quaternion()
        pb.rotation_quaternion = rest.inverted() @ q @ rest
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        if pb.name == "Hips":
            pb.location = rest.inverted() @ Vector(hips_loc)
            pb.keyframe_insert("location", frame=frame)


def arms(lu, lf, ru, rf, l_spread=9, r_spread=9):
    """Arm shorthand: (forward swing, splay) per upper arm; forearm (bend, splay).
    Negative swing = forward. Positive splay = outward/up for either side."""
    return {
        "UpperArm.L": (lu[0], -(l_spread + lu[1]), 0), "ForeArm.L": (lf[0], -lf[1], 0),
        "UpperArm.R": (ru[0], r_spread + ru[1], 0), "ForeArm.R": (rf[0], rf[1], 0),
    }


def idle_pose(phase, look=8.0):
    s, c = math.sin(phase * math.tau), math.cos(phase * math.tau)
    b = math.sin(phase * math.tau * 2.0)
    p = {
        "Hips": (0, 1.5 * s, 2.5 * s),
        "Spine": (1.5 + 1.2 * b, -1.0 * s, -3.0 * s),
        "Head": (-1.0 + 1.5 * b, 2.0 * c, look * math.sin(phase * math.tau + 0.6)),
        "Thigh.L": (-1, -2, -4), "Thigh.R": (1, 2, 4),
        "Shin.L": (2, 0, 0), "Shin.R": (1, 0, 0),
    }
    p.update(arms((-3 + 2 * s, 0), (-14 - 3 * b, 0), (-3 - 2 * s, 0), (-14 - 3 * b, 0)))
    return p, (0, 0, -0.006 + 0.006 * b)


def clip_idle():
    return "Idle-loop", [(round(i * 72 / 8), *idle_pose(i / 8)) for i in range(9)]


def clip_pose(style):
    """One-shot flourish: 'wave', 'pump' (fist pump) or 'flex'."""
    rest, rest_hips = idle_pose(0.0)

    def merged(extra, spine=(0, 0, 0), head=(0, 0, 0), hips=(0, 0, 0)):
        p = dict(rest)
        p.update(extra)
        p["Spine"] = tuple(a + b for a, b in zip(rest["Spine"], spine))
        p["Head"] = tuple(a + b for a, b in zip(rest["Head"], head))
        p["Hips"] = tuple(a + b for a, b in zip(rest["Hips"], hips))
        return p

    keys = [(0, rest, rest_hips)]
    if style == "wave":
        up = lambda fore: {"UpperArm.R": (-10, 150, 0), "ForeArm.R": (0, fore, 0)}
        keys += [
            (8, merged(up(10), spine=(-2, 0, -8), head=(-6, -6, -10)), (0, 0, 0.0)),
            (14, merged(up(38), spine=(-2, 0, -8), head=(-6, -6, -10)), (0, 0, 0.0)),
            (20, merged(up(-6), spine=(-2, 0, -8), head=(-6, -6, -10)), (0, 0, 0.0)),
            (26, merged(up(38), spine=(-2, 0, -8), head=(-6, -6, -10)), (0, 0, 0.0)),
            (32, merged(up(10), spine=(-2, 0, -8), head=(-6, -6, -10)), (0, 0, 0.0)),
        ]
    elif style == "pump":
        pump = lambda up, fore: {"UpperArm.R": (up, 14, 0), "ForeArm.R": (fore, 0, 0)}
        keys += [
            (6, merged(pump(12, -30), spine=(4, 0, 4), head=(4, 0, 0)), (0, 0, -0.01)),
            (12, merged(pump(-72, -98), spine=(-5, 0, -6), head=(-8, 0, -6)), (0, 0, 0.02)),
            (17, merged(pump(-64, -92), spine=(-3, 0, -6), head=(-6, 0, -6)), (0, 0, 0.0)),
            (22, merged(pump(-74, -100), spine=(-5, 0, -6), head=(-8, 0, -6)), (0, 0, 0.02)),
            (32, merged(pump(-70, -96), spine=(-4, 0, -6), head=(-7, 0, -6)), (0, 0, 0.01)),
        ]
    else:  # flex
        flex = {"UpperArm.L": (-6, -88, 0), "ForeArm.L": (0, -100, 0), "UpperArm.R": (-6, 88, 0), "ForeArm.R": (0, 100, 0)}
        keys += [
            (8, merged(flex, spine=(-6, 0, 0), head=(-10, 0, 0)), (0, 0, 0.03)),
            (14, merged(flex, spine=(-8, 0, 6), head=(-10, 0, 10)), (0, 0, 0.04)),
            (22, merged(flex, spine=(-8, 0, -6), head=(-10, 0, -10)), (0, 0, 0.04)),
            (30, merged(flex, spine=(-6, 0, 0), head=(-10, 0, 0)), (0, 0, 0.03)),
        ]
    keys.append((44, rest, rest_hips))
    return "Pose", keys


def build_animations(armature, pose_style):
    ad = armature.animation_data_create()
    for name, keys in (clip_idle(), clip_pose(pose_style)):
        action = bpy.data.actions.new(name)
        ad.action = action
        for frame, pose, hips_loc in keys:
            set_pose(armature, frame, pose, hips_loc)
        track = ad.nla_tracks.new()
        track.name = name
        track.strips.new(name, 0, action)
        ad.action = None
    for pb in armature.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)


# ---------------------------------------------------------------------------
# Shared body parts
# ---------------------------------------------------------------------------

def head_base(p, skin_m, w=0.5, h=0.5, d=0.46, ears=True):
    parts = [
        box(p + "Skull", (w, d, h), (0, 0, HEAD_Z), bevel=0.18, segs=4, m=skin_m),
        cyl(p + "Neck", 0.1, 0.1, (0, 0, 1.36), segs=14, bevel=0.02, m=skin_m),
    ]
    if ears:
        for side in (-1, 1):
            parts.append(sphere(f"{p}Ear{side}", 0.065, (side * (w * 0.5 + 0.005), 0.01, HEAD_Z - 0.02), scale=(0.5, 0.8, 1.05),
                                m=skin_m, segs=10, rings=7))
    return bind("Head", parts)


def face(p, iris="#3a2a1e", brow="#3d2318", mouth="smile", blush=True, brows=True, eye_y=0.03, spread=0.105, nose=True):
    """Big friendly toy eyes, brows, a nose bump and a smile on the head front."""
    white = mat("EyeWhite", "#fffaf2", rough=0.25)
    iris_m = mat("Iris_" + iris.strip("#"), iris, rough=0.25)
    pupil = mat("Pupil", "#120c18", rough=0.2)
    shine = mat("EyeShine", "#ffffff", rough=0.1, emit=0.6)
    brow_m = mat("Brow_" + brow.strip("#"), brow, rough=0.7)
    mouth_m = mat("Mouth", "#5a1a2e", rough=0.5)
    z = HEAD_Z + eye_y
    parts = []
    for side in (-1, 1):
        x = side * spread
        parts += [
            sphere(f"{p}Eye{side}", 0.058, (x, FACE_Y + 0.02, z), scale=(0.9, 0.42, 1.18), m=white, segs=14, rings=9),
            sphere(f"{p}Iris{side}", 0.037, (x + side * 0.004, FACE_Y - 0.002, z - 0.008), scale=(1, 0.4, 1.15), m=iris_m, segs=12, rings=8),
            sphere(f"{p}Pupil{side}", 0.021, (x + side * 0.004, FACE_Y - 0.01, z - 0.008), scale=(1, 0.4, 1.1), m=pupil, segs=10, rings=6),
            sphere(f"{p}Shine{side}", 0.0095, (x + side * 0.016, FACE_Y - 0.016, z + 0.014), m=shine, segs=8, rings=5),
        ]
        if brows:
            parts.append(box(f"{p}Brow{side}", (0.1, 0.035, 0.03), (x, FACE_Y + 0.004, z + 0.092), rot=rad(0, side * 10, 0), bevel=0.012, m=brow_m))
        if blush:
            parts.append(sphere(f"{p}Blush{side}", 0.034, (side * 0.15, FACE_Y + 0.012, HEAD_Z - 0.065), scale=(1.2, 0.3, 0.75),
                                m=mat("Blush", "#ff8fa6", rough=0.6), segs=10, rings=6))
    if nose:
        parts.append(sphere(p + "Nose", 0.03, (0, FACE_Y - 0.012, HEAD_Z - 0.035), scale=(1.0, 0.75, 0.85), m=bpy.data.materials.get("Skin"), segs=10, rings=7))
    if mouth == "smile":
        parts.append(torus(p + "Smile", 0.048, 0.011, (0, FACE_Y + 0.006, HEAD_Z - 0.09), rot=rad(90, 0, 0), m=mouth_m,
                           major_segs=16, minor_segs=6, arc=math.radians(130), start=math.radians(205)))
    elif mouth == "grin":
        parts.append(prism(p + "Grin", [(-0.065, 0.0), (0.065, 0.0), (0.04, -0.04), (-0.04, -0.04)], 0.03, (0, FACE_Y + 0.008, HEAD_Z - 0.075),
                           m=mouth_m, bevel=0.012))
        parts.append(box(p + "Teeth", (0.1, 0.02, 0.016), (0, FACE_Y - 0.004, HEAD_Z - 0.081), bevel=0.006, m=white))
    elif mouth == "smirk":
        parts.append(torus(p + "Smirk", 0.042, 0.01, (0.015, FACE_Y + 0.006, HEAD_Z - 0.085), rot=rad(90, 0, 0), m=mouth_m,
                           major_segs=14, minor_segs=6, arc=math.radians(90), start=math.radians(240)))
    return bind("Head", parts)


def torso(p, top_m, w=0.54, d=0.34, h=0.42, belly=None):
    parts = [box(p + "Chest", (w, d, h), (0, 0, 1.16), bevel=0.12, segs=3, m=top_m)]
    if belly:
        parts.append(box(p + "Belly", (w * 0.86, d * 0.95, 0.16), (0, 0, 1.0), bevel=0.06, segs=3, m=belly))
    return bind("Spine", parts)


def pelvis(p, m_pants, w=0.46, belt=None, buckle=None):
    parts = [box(p + "Pelvis", (w, 0.32, 0.2), (0, 0, 0.9), bevel=0.08, segs=3, m=m_pants)]
    if belt:
        parts.append(box(p + "Belt", (w + 0.03, 0.35, 0.06), (0, 0, 0.985), bevel=0.02, m=belt))
    if buckle:
        parts.append(box(p + "Buckle", (0.1, 0.03, 0.07), (0, -0.18, 0.985), bevel=0.012, m=buckle))
    return bind("Hips", parts)


def arm(p, side, upper_m, fore_m, hand_m, shoulder_m=None, cuff_m=None, mitten=False, puff=0.0, elbow_m=None):
    """One arm. side = +1 (left, +X) or -1 (right). puff fattens sleeves."""
    s = "L" if side > 0 else "R"
    x = side * 0.36
    upper = [
        sphere(f"{p}Shoulder{s}", 0.105 + puff, (side * 0.325, 0, 1.29), m=shoulder_m or upper_m, segs=14, rings=9),
        box(f"{p}UpperArm{s}", (0.15 + puff, 0.16 + puff, 0.26), (x, 0, 1.16), bevel=0.06, segs=3, m=upper_m),
    ]
    fore = [
        sphere(f"{p}Elbow{s}", 0.074 + puff * 0.6, (side * 0.372, 0, 1.04), m=elbow_m or fore_m, segs=12, rings=8),
        box(f"{p}ForeArm{s}", (0.14 + puff, 0.15 + puff, 0.22), (side * 0.38, 0, 0.92), bevel=0.055, segs=3, m=fore_m),
    ]
    if cuff_m:
        fore.append(box(f"{p}Cuff{s}", (0.165 + puff, 0.175 + puff, 0.06), (side * 0.385, 0, 0.83), bevel=0.02, m=cuff_m))
    hx = side * 0.39
    if mitten:
        fore += [
            box(f"{p}Mitt{s}", (0.16, 0.15, 0.17), (hx, -0.005, 0.735), bevel=0.06, segs=3, m=hand_m),
            box(f"{p}MittThumb{s}", (0.055, 0.07, 0.09), (hx - side * 0.07, -0.05, 0.75), rot=rad(0, side * 15, 0), bevel=0.025, m=hand_m),
        ]
    else:
        fore += [
            box(f"{p}Palm{s}", (0.15, 0.125, 0.13), (hx, -0.005, 0.745), bevel=0.05, segs=3, m=hand_m),
            box(f"{p}Fingers{s}", (0.145, 0.11, 0.08), (hx, 0.0, 0.66), rot=rad(-8, 0, 0), bevel=0.035, segs=3, m=hand_m),
            box(f"{p}Thumb{s}", (0.05, 0.06, 0.085), (hx - side * 0.068, -0.05, 0.725), rot=rad(0, side * 12, 0), bevel=0.022, m=hand_m),
        ]
    return bind(f"UpperArm.{s}", upper) + bind(f"ForeArm.{s}", fore)


def leg(p, side, thigh_m, shin_m, boot_m, sole_m, knee_m=None, boot_h=0.17, boot_cuff=None, sock=None, wide=0.0):
    s = "L" if side > 0 else "R"
    x = side * 0.13
    thigh = [box(f"{p}Thigh{s}", (0.2 + wide, 0.22 + wide, 0.34), (x, 0, 0.66), bevel=0.07, segs=3, m=thigh_m)]
    shin = [
        sphere(f"{p}Knee{s}", 0.092 + wide * 0.5, (x, -0.005, 0.48), m=knee_m or shin_m, segs=12, rings=8),
        box(f"{p}Shin{s}", (0.18 + wide, 0.2 + wide, 0.3), (x, 0, 0.32), bevel=0.06, segs=3, m=shin_m),
        box(f"{p}Boot{s}", (0.22, 0.36, boot_h), (x, -0.05, boot_h / 2 + 0.02), bevel=0.07, segs=3, m=boot_m),
        box(f"{p}Sole{s}", (0.235, 0.375, 0.05), (x, -0.05, 0.025), bevel=0.02, m=sole_m),
    ]
    if sock:
        shin.append(box(f"{p}Sock{s}", (0.19, 0.21, 0.08), (x, 0, 0.21), bevel=0.03, m=sock))
    if boot_cuff:
        shin.append(box(f"{p}BootCuff{s}", (0.235, 0.25, 0.06), (x, -0.005, boot_h + 0.03), bevel=0.025, m=boot_cuff))
    return bind(f"Thigh.{s}", thigh) + bind(f"Shin.{s}", shin)


def stripes_on_box(prefix, bone, size, loc, count, m, axis="z", width=0.02, inset=0.0):
    """Thin bands wrapped around a box (sleeve stripes, quilting...)."""
    out = []
    for i in range(count):
        t = (i + 0.5) / count - 0.5
        if axis == "z":
            out.append(box(f"{prefix}{i}", (size[0] + 0.012, size[1] + 0.012, width), (loc[0], loc[1], loc[2] + t * size[2] * (1 - inset)), bevel=0.006, m=m))
        else:
            out.append(box(f"{prefix}{i}", (width, size[1] + 0.012, size[2] + 0.012), (loc[0] + t * size[0] * (1 - inset), loc[1], loc[2]), bevel=0.006, m=m))
    return bind(bone, out)


def open_shell(name, radius, loc, opening_deg, m, scale=(1, 1, 1), segs=24, rings=14, thickness=0.025):
    """A hollow sphere (helmet, hood) with a round opening facing -Y, so the
    face inside shows. The rim is closed with a thin wall."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    limit = math.cos(math.radians(opening_deg))
    doomed = [f for f in bm.faces if (f.calc_center_median().normalized()).dot(Vector((0, -1, 0))) > limit]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    ob = bpy.data.objects.new(name, bpy.data.meshes.new(name))
    bm.to_mesh(ob.data)
    bm.free()
    source_collection().objects.link(ob)
    ob.data.materials.append(m)
    ob.location = loc
    solid = ob.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = thickness
    solid.offset = -1.0
    for poly in ob.data.polygons:
        poly.use_smooth = True
    return ob


# ---------------------------------------------------------------------------
# Operators
# ---------------------------------------------------------------------------

def op_boardwalk_ranger():
    """Pier ranger: teal shirt over a dark base layer, badge, khaki shorts,
    ranger hat, whistle. His gloves and sleeves match the default first-person arms."""
    p = "BR_"
    skin_m = mat("Skin", "#e8b08a", rough=0.55)
    shirt = mat("Shirt", "#17a39a", rough=0.6)
    shirt_dark = mat("ShirtDark", "#0e7a73", rough=0.6)
    khaki = mat("Khaki", "#d8b77a", rough=0.7)
    khaki_dark = mat("KhakiDark", "#b08f55", rough=0.7)
    pink = mat("Pink", "#ff3f9f", rough=0.5)
    brown = mat("Leather", "#7a4a2c", rough=0.6)
    gold = mat("Badge", "#ffc94a", rough=0.3, metal=0.6)
    sock = mat("Sock", "#f7f4f2", rough=0.7)
    hair = mat("Hair", "#5a3424", rough=0.8)
    lens = mat("Lens", "#2a1f3d", rough=0.1, metal=0.4)
    glove = mat("Glove", "#2b2836", rough=0.7)
    under = mat("Undershirt", "#1d1b26", rough=0.8)
    parts = head_base(p, skin_m)
    parts += face(p, iris="#2f6f8f", brow="#4a2a1c", mouth="smile")
    parts += bind("Head", [
        box(p + "HairBack", (0.46, 0.14, 0.24), (0, 0.19, HEAD_Z - 0.02), bevel=0.06, m=hair),
        box(p + "Sideburn" + "L", (0.04, 0.12, 0.12), (0.245, 0.02, HEAD_Z - 0.0), bevel=0.02, m=hair),
        box(p + "Sideburn" + "R", (0.04, 0.12, 0.12), (-0.245, 0.02, HEAD_Z - 0.0), bevel=0.02, m=hair),
        # Ranger hat: wide flat brim, pinched crown, pink band.
        cyl(p + "Brim", 0.44, 0.035, (0, 0, HEAD_Z + 0.2), segs=28, bevel=0.012, m=khaki),
        cyl(p + "Crown", 0.24, 0.2, (0, 0, HEAD_Z + 0.3), segs=20, bevel=0.06, m=khaki, radius_top=0.2),
        cyl(p + "Band", 0.245, 0.05, (0, 0, HEAD_Z + 0.245), segs=20, bevel=0.01, m=pink),
        box(p + "Pinch", (0.06, 0.4, 0.06), (0, 0, HEAD_Z + 0.41), bevel=0.025, m=khaki_dark),
        # Aviators resting on the brim.
        sphere(p + "ShadeL", 0.05, (0.075, -0.25, HEAD_Z + 0.235), scale=(1.15, 0.35, 0.85), m=lens, segs=10, rings=6),
        sphere(p + "ShadeR", 0.05, (-0.075, -0.25, HEAD_Z + 0.235), scale=(1.15, 0.35, 0.85), m=lens, segs=10, rings=6),
        box(p + "ShadeBridge", (0.06, 0.02, 0.015), (0, -0.255, HEAD_Z + 0.25), bevel=0.005, m=gold),
    ])
    parts += torso(p, shirt)
    parts += bind("Spine", [
        box(p + "Placket", (0.05, 0.04, 0.38), (0, -0.168, 1.15), bevel=0.012, m=shirt_dark),
        box(p + "PocketL", (0.13, 0.04, 0.12), (0.13, -0.168, 1.24), bevel=0.02, m=shirt_dark),
        box(p + "PocketR", (0.13, 0.04, 0.12), (-0.13, -0.168, 1.24), bevel=0.02, m=shirt_dark),
        prism(p + "Badge", star_outline(0.048, 0.024, 5, 90), 0.025, (0.13, -0.19, 1.24), m=gold, bevel=0.006),
        box(p + "CollarL", (0.16, 0.06, 0.08), (0.1, -0.15, 1.355), rot=rad(0, 28, 0), bevel=0.02, m=shirt_dark),
        box(p + "CollarR", (0.16, 0.06, 0.08), (-0.1, -0.15, 1.355), rot=rad(0, -28, 0), bevel=0.02, m=shirt_dark),
        # Whistle on a pink lanyard.
        tube(p + "Lanyard", [(-0.12, -0.16, 1.37), (-0.07, -0.19, 1.22), (0.0, -0.2, 1.12), (0.07, -0.19, 1.22), (0.12, -0.16, 1.37)], 0.009, m=pink, segs=6),
        cyl(p + "Whistle", 0.025, 0.07, (0.0, -0.215, 1.1), rot=rad(0, 90, 0), segs=12, bevel=0.008, m=gold),
        # Radio on the back of the belt.
        box(p + "Radio", (0.1, 0.06, 0.14), (0.2, 0.17, 0.98), bevel=0.02, m=mat("Radio", "#26232f", rough=0.5)),
        cyl(p + "Antenna", 0.008, 0.12, (0.23, 0.17, 1.11), segs=6, bevel=0.0, m=mat("Radio")),
    ])
    parts += pelvis(p, khaki, belt=brown, buckle=gold)
    parts += bind("Hips", [box(p + "Holster", (0.08, 0.1, 0.12), (-0.25, -0.02, 0.92), bevel=0.02, m=brown)])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, shirt, under, glove, cuff_m=pink, elbow_m=under)
        parts += bind(f"UpperArm.{s}", [box(f"{p}Roll{s}", (0.175, 0.185, 0.07), (side * 0.36, 0, 1.06), bevel=0.025, m=shirt_dark)])
        parts += leg(p, side, khaki, skin_m, brown, mat("Sole", "#3b2a22", rough=0.8), sock=sock, boot_h=0.2, boot_cuff=khaki_dark)
        parts += bind(f"Thigh.{s}", [box(f"{p}CargoPocket{s}", (0.05, 0.14, 0.13), (side * 0.235, 0, 0.66), bevel=0.02, m=khaki_dark)])
    return parts, "pump"


def op_neon_courier():
    """Night-shift bike courier: glowing piping, visor helmet, messenger bag."""
    p = "NC_"
    skin_m = mat("Skin", "#8a5636", rough=0.55)
    jacket = mat("Jacket", "#1f1b33", rough=0.55)
    jacket_hi = mat("JacketPanel", "#3a2f6b", rough=0.5)
    neon_p = mat("NeonPink", "#ff3fa4", rough=0.3, emit=2.6)
    neon_c = mat("NeonCyan", "#35f0ff", rough=0.3, emit=2.6)
    pants = mat("Joggers", "#2c2450", rough=0.65)
    shoe = mat("Sneaker", "#f4f0ff", rough=0.45)
    sole = mat("SneakerSole", "#35f0ff", rough=0.3, emit=1.8)
    helmet = mat("Helmet", "#ff3fa4", rough=0.3)
    visor = mat("FxGlassVisor", "#35f0ff", rough=0.05)
    bag = mat("Bag", "#ffc24a", rough=0.6)
    hair = mat("Hair", "#1a1220", rough=0.85)
    glove = mat("Glove", "#1b1828", rough=0.6)
    parts = head_base(p, skin_m)
    parts += face(p, iris="#2a1a12", brow="#1a1220", mouth="smirk", blush=False)
    parts += bind("Head", [
        # Rounded helmet shell with vents and a wraparound visor.
        sphere(p + "Helmet", 0.3, (0, 0.03, HEAD_Z + 0.19), scale=(1.0, 1.1, 0.62), m=helmet, segs=20, rings=12),
        box(p + "Vent0", (0.04, 0.32, 0.05), (0.08, 0.04, HEAD_Z + 0.37), bevel=0.015, m=jacket),
        box(p + "Vent1", (0.04, 0.32, 0.05), (-0.08, 0.04, HEAD_Z + 0.37), bevel=0.015, m=jacket),
        box(p + "Stripe", (0.025, 0.6, 0.03), (0, 0.03, HEAD_Z + 0.375), bevel=0.01, m=neon_c),
        box(p + "Brim", (0.42, 0.1, 0.04), (0, -0.28, HEAD_Z + 0.15), rot=rad(-12, 0, 0), bevel=0.015, m=helmet),
        sphere(p + "Visor", 0.255, (0, -0.06, HEAD_Z + 0.04), scale=(1.06, 0.78, 0.3), m=visor, segs=20, rings=10),
        sphere(p + "Puff", 0.15, (0, 0.27, HEAD_Z - 0.02), m=hair, segs=14, rings=9),
        torus(p + "PuffTie", 0.06, 0.02, (0, 0.17, HEAD_Z - 0.02), rot=rad(90, 0, 0), m=neon_p, major_segs=14, minor_segs=6),
        box(p + "Strap" + "L", (0.03, 0.04, 0.2), (0.235, -0.03, HEAD_Z - 0.08), bevel=0.01, m=jacket),
        box(p + "Strap" + "R", (0.03, 0.04, 0.2), (-0.235, -0.03, HEAD_Z - 0.08), bevel=0.01, m=jacket),
    ])
    parts += torso(p, jacket)
    parts += bind("Spine", [
        box(p + "Collar", (0.4, 0.3, 0.1), (0, 0.01, 1.35), bevel=0.04, m=jacket_hi),
        box(p + "Zip", (0.025, 0.04, 0.36), (0, -0.17, 1.15), bevel=0.008, m=neon_p),
        box(p + "PanelL", (0.09, 0.04, 0.3), (0.19, -0.165, 1.14), bevel=0.02, m=jacket_hi),
        box(p + "PanelR", (0.09, 0.04, 0.3), (-0.19, -0.165, 1.14), bevel=0.02, m=jacket_hi),
        box(p + "Hem", (0.56, 0.36, 0.05), (0, 0, 0.97), bevel=0.02, m=neon_c),
        # Messenger bag across the back, strap over the chest.
        box(p + "Bag", (0.42, 0.14, 0.3), (0.04, 0.24, 1.08), bevel=0.05, segs=3, m=bag),
        box(p + "BagFlap", (0.43, 0.06, 0.16), (0.04, 0.3, 1.16), bevel=0.03, m=mat("BagFlap", "#ff8a2a", rough=0.6)),
        prism(p + "BagLogo", [(-0.05, 0.0), (0.0, 0.05), (0.05, 0.0), (0.0, -0.05)], 0.02, (0.04, 0.335, 1.15), rot=rad(0, 0, 180), m=neon_p),
        tube(p + "BagStrap", [(0.27, 0.12, 1.33), (0.12, -0.18, 1.26), (-0.08, -0.19, 1.07), (-0.25, -0.12, 0.98)], 0.022, m=neon_p, segs=6),
    ])
    parts += pelvis(p, pants, belt=jacket)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, jacket, jacket, glove, cuff_m=neon_c)
        parts += bind(f"UpperArm.{s}", [box(f"{p}Piping{s}", (0.03, 0.17, 0.25), (side * 0.44, 0, 1.16), bevel=0.01, m=neon_p)])
        parts += leg(p, side, pants, pants, shoe, sole, boot_h=0.15, boot_cuff=jacket_hi)
        parts += bind(f"Thigh.{s}", [box(f"{p}LegStripe{s}", (0.03, 0.06, 0.33), (side * 0.235, 0, 0.66), bevel=0.01, m=neon_c)])
        parts += bind(f"Shin.{s}", [
            box(f"{p}KneePad{s}", (0.17, 0.08, 0.14), (side * 0.13, -0.1, 0.46), bevel=0.04, m=helmet),
            box(f"{p}ShinStripe{s}", (0.03, 0.06, 0.28), (side * 0.225, 0, 0.32), bevel=0.01, m=neon_c),
            box(f"{p}Swoosh{s}", (0.03, 0.2, 0.04), (side * 0.245, -0.05, 0.1), rot=rad(-15, 0, 0), bevel=0.01, m=neon_p),
        ])
    return parts, "wave"


def op_deep_diver():
    """Old-school brass diving helmet, wetsuit, air tank and big flippers."""
    p = "DD_"
    skin_m = mat("Skin", "#f0c4a0", rough=0.55)
    brass = mat("Brass", "#e8a83a", rough=0.28, metal=0.75)
    brass_dark = mat("BrassDark", "#a8661f", rough=0.32, metal=0.7)
    glass = mat("FxGlassPort", "#7fe7ff", rough=0.05)
    suit = mat("Wetsuit", "#1d2f5c", rough=0.5)
    panel = mat("SuitPanel", "#ff8a2a", rough=0.5)
    tank = mat("Tank", "#ffd93b", rough=0.35)
    flipper = mat("Flipper", "#ff8a2a", rough=0.5)
    rubber = mat("Rubber", "#ffd93b", rough=0.55)
    dark = mat("DiveDark", "#1c1830", rough=0.5)
    gauge = mat("GaugeFace", "#eafcff", rough=0.3, emit=0.6)
    parts = head_base(p, skin_m, ears=False)
    parts += face(p, iris="#2f7f6f", brow="#8a4a2a", mouth="smile")
    parts += bind("Head", [
        open_shell(p + "Helmet", 0.36, (0, 0.03, HEAD_Z + 0.03), 33, brass),
        cyl(p + "Collar", 0.33, 0.08, (0, 0.0, 1.36), segs=24, bevel=0.03, m=brass_dark),
        torus(p + "PortRim", 0.19, 0.035, (0, -0.31, HEAD_Z + 0.0), rot=rad(90, 0, 0), m=brass_dark, major_segs=28, minor_segs=8),
        cyl(p + "Port", 0.19, 0.03, (0, -0.3, HEAD_Z + 0.0), rot=rad(90, 0, 0), segs=28, bevel=0.0, m=glass),
        sphere(p + "Valve", 0.06, (0.0, 0.0, HEAD_Z + 0.38), m=brass_dark, segs=12, rings=8),
        cyl(p + "Hose", 0.04, 0.1, (0.0, 0.33, HEAD_Z + 0.08), rot=rad(90, 0, 0), segs=12, bevel=0.01, m=brass_dark),
    ])
    for side in (-1, 1):
        parts += bind("Head", [
            torus(f"{p}SideRim{side}", 0.075, 0.02, (side * 0.335, 0.0, HEAD_Z + 0.02), rot=rad(0, 90, 0), m=brass_dark, major_segs=18, minor_segs=6),
            cyl(f"{p}SidePort{side}", 0.075, 0.02, (side * 0.33, 0.0, HEAD_Z + 0.02), rot=rad(0, 90, 0), segs=18, bevel=0.0, m=glass),
        ])
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        parts += bind("Head", [sphere(f"{p}Bolt{k}", 0.024, (math.cos(a) * 0.335, math.sin(a) * 0.335, 1.4), m=brass, segs=8, rings=5)])
    parts += torso(p, suit)
    parts += bind("Spine", [
        box(p + "ChestPanel", (0.4, 0.04, 0.16), (0, -0.168, 1.24), bevel=0.03, m=panel),
        box(p + "Corselet", (0.62, 0.42, 0.1), (0, 0.0, 1.32), bevel=0.04, m=brass_dark),
        cyl(p + "TankA", 0.11, 0.48, (0.11, 0.27, 1.12), segs=18, bevel=0.05, m=tank),
        cyl(p + "TankB", 0.11, 0.48, (-0.11, 0.27, 1.12), segs=18, bevel=0.05, m=tank),
        box(p + "TankStrap", (0.48, 0.28, 0.05), (0, 0.22, 1.12), bevel=0.02, m=dark),
        cyl(p + "TankValve", 0.035, 0.08, (0.11, 0.27, 1.4), segs=10, bevel=0.01, m=brass_dark),
        tube(p + "AirHose", [(0.11, 0.27, 1.42), (0.05, 0.3, 1.52), (0.0, 0.34, 1.62)], 0.03, m=dark, segs=8),
    ])
    parts += pelvis(p, suit, belt=dark)
    parts += bind("Hips", [box(f"{p}Weight{i}", (0.09, 0.06, 0.08), (-0.18 + i * 0.12, -0.18, 0.985), bevel=0.015, m=mat("Lead", "#5a5670", rough=0.4, metal=0.6))
                            for i in range(4)])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, suit, suit, rubber, cuff_m=panel)
        parts += bind(f"UpperArm.{s}", [box(f"{p}ArmPanel{s}", (0.03, 0.17, 0.2), (side * 0.44, 0, 1.16), bevel=0.01, m=panel)])
        if side > 0:
            parts += bind("ForeArm.L", [
                cyl(p + "Gauge", 0.06, 0.04, (0.46, -0.0, 0.93), rot=rad(0, 90, 0), segs=16, bevel=0.012, m=brass_dark),
                cyl(p + "GaugeFace", 0.045, 0.01, (0.482, 0.0, 0.93), rot=rad(0, 90, 0), segs=16, bevel=0.0, m=gauge),
            ])
        parts += leg(p, side, suit, suit, dark, dark, boot_h=0.14)
        parts += bind(f"Thigh.{s}", [box(f"{p}ThighPanel{s}", (0.03, 0.12, 0.3), (side * 0.235, 0, 0.66), bevel=0.01, m=panel)])
        parts += bind(f"Shin.{s}", [
            prism(f"{p}Fin{s}", [(-0.13, 0.0), (0.13, 0.0), (0.17, -0.42), (0.0, -0.36), (-0.17, -0.42)], 0.03, (side * 0.13, -0.24, 0.035),
                  rot=rad(90, 0, 0), m=flipper, bevel=0.012),
            box(f"{p}FinRib{s}", (0.03, 0.34, 0.03), (side * 0.13, -0.32, 0.055), bevel=0.01, m=rubber),
        ])
    return parts, "wave"


def op_astro_cadet():
    """Launch Pad cadet: white suit, orange panels, bubble helmet, backpack."""
    p = "AC_"
    skin_m = mat("Skin", "#c98a5e", rough=0.55)
    suit = mat("Suit", "#f4f2fa", rough=0.5)
    suit_shade = mat("SuitShade", "#c9c6d8", rough=0.55)
    orange = mat("Orange", "#ff7a2a", rough=0.45)
    glass = mat("FxGlassBubble", "#bfefff", rough=0.05)
    dark = mat("AstroDark", "#2b2840", rough=0.45)
    hair = mat("Hair", "#e0652a", rough=0.8)
    blue = mat("PatchBlue", "#3a7be0", rough=0.5)
    light_r = mat("LightRed", "#ff3f5f", rough=0.3, emit=2.5)
    light_g = mat("LightGreen", "#52f060", rough=0.3, emit=2.5)
    parts = head_base(p, skin_m)
    parts += face(p, iris="#2a1a12", brow="#a8461f", mouth="grin")
    parts += bind("Head", [
        # Orange bob.
        sphere(p + "HairTop", 0.27, (0, 0.03, HEAD_Z + 0.09), scale=(1.0, 1.0, 0.62), m=hair, segs=18, rings=10),
        box(p + "HairBack", (0.5, 0.18, 0.3), (0, 0.15, HEAD_Z - 0.04), bevel=0.08, m=hair),
        box(p + "Fringe", (0.36, 0.08, 0.1), (0.04, -0.2, HEAD_Z + 0.16), rot=rad(0, -8, 0), bevel=0.04, m=hair),
        sphere(p + "Bubble", 0.4, (0, 0.0, HEAD_Z + 0.03), m=glass, segs=24, rings=14),
        torus(p + "Ring", 0.31, 0.05, (0, 0.0, 1.36), m=suit_shade, major_segs=28, minor_segs=8),
        cyl(p + "Antenna", 0.012, 0.2, (0.22, 0.12, HEAD_Z + 0.36), rot=rad(0, 15, 0), segs=6, bevel=0.0, m=dark),
        sphere(p + "AntennaTip", 0.03, (0.245, 0.12, HEAD_Z + 0.46), m=light_r, segs=10, rings=6),
    ])
    parts += torso(p, suit)
    parts += bind("Spine", [
        box(p + "ChestPlate", (0.36, 0.05, 0.22), (0, -0.17, 1.2), bevel=0.04, m=suit_shade),
        box(p + "Button0", (0.05, 0.03, 0.04), (-0.08, -0.2, 1.22), bevel=0.01, m=light_r),
        box(p + "Button1", (0.05, 0.03, 0.04), (0.0, -0.2, 1.22), bevel=0.01, m=light_g),
        box(p + "Button2", (0.05, 0.03, 0.04), (0.08, -0.2, 1.22), bevel=0.01, m=blue),
        box(p + "Display", (0.2, 0.03, 0.06), (0, -0.2, 1.15), bevel=0.01, m=dark),
        box(p + "Waist", (0.56, 0.36, 0.07), (0, 0, 0.99), bevel=0.025, m=orange),
        cyl(p + "Patch", 0.055, 0.02, (0.2, -0.17, 1.3), rot=rad(90, 0, 0), segs=16, bevel=0.005, m=blue),
        prism(p + "PatchStar", star_outline(0.035, 0.016, 5, 90), 0.025, (0.2, -0.18, 1.3), m=mat("Star", "#ffd93b", rough=0.4)),
        # Life-support backpack.
        box(p + "Pack", (0.48, 0.2, 0.46), (0, 0.27, 1.14), bevel=0.07, segs=3, m=suit),
        box(p + "PackBand", (0.5, 0.21, 0.06), (0, 0.27, 1.26), bevel=0.02, m=orange),
        cyl(p + "PackTankL", 0.06, 0.36, (0.15, 0.39, 1.12), segs=14, bevel=0.03, m=suit_shade),
        cyl(p + "PackTankR", 0.06, 0.36, (-0.15, 0.39, 1.12), segs=14, bevel=0.03, m=suit_shade),
        sphere(p + "PackLight", 0.03, (0.0, 0.38, 1.3), m=light_g, segs=8, rings=6),
    ])
    parts += pelvis(p, suit, belt=dark, buckle=orange)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, suit, suit, suit, shoulder_m=orange, cuff_m=orange, puff=0.02)
        parts += leg(p, side, suit, suit, suit_shade, dark, boot_h=0.24, boot_cuff=orange, wide=0.02)
        parts += stripes_on_box(f"{p}KneeBand{s}", f"Shin.{s}", (0.2, 0.22, 0.3), (side * 0.13, 0, 0.42), 1, suit_shade, width=0.05)
    parts += bind("UpperArm.L", [box(p + "Flag", (0.03, 0.12, 0.08), (0.445, 0, 1.2), bevel=0.008, m=blue),
                                 box(p + "FlagStripe", (0.032, 0.12, 0.02), (0.447, 0, 1.2), bevel=0.004, m=light_r)])
    return parts, "pump"


def op_frost_guard():
    """Summit Lodge patroller: quilted parka, fur hood, goggles, knit scarf."""
    p = "FG_"
    skin_m = mat("Skin", "#f2c8a8", rough=0.55)
    parka = mat("Parka", "#4fb4ff", rough=0.55)
    parka_dark = mat("ParkaDark", "#2f7fcf", rough=0.55)
    fur = mat("Fur", "#f7f4f2", rough=0.95)
    scarf = mat("Scarf", "#e8263a", rough=0.8)
    scarf_hi = mat("ScarfStripe", "#f7f4f2", rough=0.8)
    pants = mat("SnowPants", "#3d2f73", rough=0.65)
    boot = mat("SnowBoot", "#7a4a2c", rough=0.6)
    mitt = mat("Mitten", "#e8263a", rough=0.85)
    goggle = mat("GoggleLens", "#ffb62e", rough=0.1, metal=0.5, emit=0.4)
    dark = mat("FrostDark", "#1c1830", rough=0.5)
    parts = head_base(p, skin_m, ears=False)
    parts += face(p, iris="#3a6fbf", brow="#c9a37a", mouth="smile")
    parts += bind("Head", [
        # Hood around the face, fur trim ring.
        open_shell(p + "Hood", 0.35, (0, 0.06, HEAD_Z + 0.03), 52, parka, scale=(1.0, 0.98, 1.06)),
        torus(p + "HoodFur", 0.26, 0.065, (0, -0.215, HEAD_Z + 0.02), rot=rad(90, 0, 0), m=fur, major_segs=28, minor_segs=10),
        # Goggles on the forehead.
        box(p + "GoggleBand", (0.54, 0.4, 0.05), (0, 0.0, HEAD_Z + 0.15), bevel=0.02, m=dark),
        sphere(p + "GoggleL", 0.07, (0.08, -0.255, HEAD_Z + 0.16), scale=(1.2, 0.5, 0.8), m=goggle, segs=12, rings=8),
        sphere(p + "GoggleR", 0.07, (-0.08, -0.255, HEAD_Z + 0.16), scale=(1.2, 0.5, 0.8), m=goggle, segs=12, rings=8),
        sphere(p + "Pom", 0.09, (0, 0.06, HEAD_Z + 0.4), m=fur, segs=12, rings=8),
    ])
    parts += torso(p, parka, w=0.6, d=0.4)
    parts += stripes_on_box(p + "Quilt", "Spine", (0.6, 0.4, 0.42), (0, 0, 1.16), 3, parka_dark, width=0.025, inset=0.15)
    parts += bind("Spine", [
        box(p + "Zip", (0.03, 0.04, 0.4), (0, -0.2, 1.15), bevel=0.01, m=parka_dark),
        # Scarf wrap with a hanging tail.
        torus(p + "ScarfWrap", 0.17, 0.065, (0, 0, 1.37), m=scarf, major_segs=22, minor_segs=8),
        box(p + "ScarfTail", (0.12, 0.05, 0.32), (0.12, -0.22, 1.2), rot=rad(0, -6, 0), bevel=0.03, m=scarf),
        box(p + "ScarfStripe0", (0.125, 0.055, 0.03), (0.125, -0.22, 1.12), rot=rad(0, -6, 0), bevel=0.01, m=scarf_hi),
        box(p + "ScarfStripe1", (0.125, 0.055, 0.03), (0.13, -0.22, 1.2), rot=rad(0, -6, 0), bevel=0.01, m=scarf_hi),
        box(p + "Hem", (0.62, 0.42, 0.08), (0, 0, 0.97), bevel=0.035, m=fur),
        box(p + "Patch", (0.12, 0.03, 0.08), (-0.17, -0.205, 1.26), bevel=0.015, m=mat("PatchRed", "#e8263a", rough=0.6)),
        box(p + "PatchCross", (0.06, 0.035, 0.02), (-0.17, -0.21, 1.26), bevel=0.004, m=fur),
    ])
    parts += pelvis(p, pants, w=0.5)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, parka, parka, mitt, cuff_m=fur, mitten=True, puff=0.04)
        parts += stripes_on_box(f"{p}ArmQuilt{s}", f"UpperArm.{s}", (0.19, 0.2, 0.26), (side * 0.36, 0, 1.16), 2, parka_dark, width=0.02)
        parts += leg(p, side, pants, pants, boot, dark, boot_h=0.24, boot_cuff=fur, wide=0.03)
    return parts, "pump"


def op_surf_rescue():
    """Friendly lifeguard: red rash vest, board shorts, visor, rescue tube."""
    p = "SR_"
    skin_m = mat("Skin", "#b9774d", rough=0.55)
    red = mat("Rash", "#e8263a", rough=0.55)
    red_dark = mat("RashDark", "#b0182a", rough=0.55)
    white = mat("White", "#f7f4f2", rough=0.55)
    shorts = mat("Boardies", "#ffd93b", rough=0.6)
    shorts_hi = mat("BoardiesStripe", "#ff8a2a", rough=0.6)
    visor = mat("Visor", "#f7f4f2", rough=0.5)
    visor_brim = mat("VisorBrim", "#14a3a0", rough=0.45)
    tube_m = mat("RescueTube", "#ff4d3a", rough=0.5)
    hair = mat("Hair", "#ffd27a", rough=0.8)
    zinc = mat("Zinc", "#ffffff", rough=0.6)
    sandal = mat("Sandal", "#14a3a0", rough=0.5)
    parts = head_base(p, skin_m)
    parts += face(p, iris="#1f3a5a", brow="#c9a04a", mouth="grin", blush=False)
    parts += bind("Head", [
        box(p + "Zinc", (0.07, 0.03, 0.035), (0, FACE_Y - 0.035, HEAD_Z - 0.02), bevel=0.012, m=zinc),
        box(p + "ZincL", (0.06, 0.02, 0.02), (0.15, FACE_Y + 0.0, HEAD_Z - 0.04), bevel=0.008, m=zinc),
        box(p + "ZincR", (0.06, 0.02, 0.02), (-0.15, FACE_Y + 0.0, HEAD_Z - 0.04), bevel=0.008, m=zinc),
        # Messy surfer hair spiking out of the visor.
        box(p + "HairBack", (0.48, 0.2, 0.3), (0, 0.13, HEAD_Z + 0.04), bevel=0.08, m=hair),
    ])
    rng = random.Random(4)
    for i in range(9):
        a = math.radians(-70 + i * 18)
        parts += bind("Head", [box(f"{p}Spike{i}", (0.09, 0.09, 0.16), (math.sin(a) * 0.2, math.cos(a) * 0.12 + 0.02, HEAD_Z + 0.24 + rng.uniform(0, 0.04)),
                                   rot=rad(rng.uniform(-25, 10), math.degrees(a) * 0.4, 0), bevel=0.035, m=hair)])
    parts += bind("Head", [
        torus(p + "VisorBand", 0.255, 0.03, (0, 0.0, HEAD_Z + 0.17), m=visor, major_segs=24, minor_segs=6),
        prism(p + "VisorBrim", [(-0.24, 0.0), (0.24, 0.0), (0.18, -0.2), (-0.18, -0.2)], 0.03, (0, -0.23, HEAD_Z + 0.16), rot=rad(-80, 0, 0),
              m=visor_brim, bevel=0.012),
    ])
    parts += torso(p, red)
    parts += bind("Spine", [
        box(p + "Panel", (0.3, 0.04, 0.12), (0, -0.168, 1.24), bevel=0.02, m=white),
        torus(p + "Ring", 0.04, 0.014, (0, -0.19, 1.24), rot=rad(90, 0, 0), m=red, major_segs=16, minor_segs=6),
        box(p + "SideL", (0.04, 0.3, 0.36), (0.27, 0, 1.14), bevel=0.015, m=red_dark),
        box(p + "SideR", (0.04, 0.3, 0.36), (-0.27, 0, 1.14), bevel=0.015, m=red_dark),
        # Rescue tube slung diagonally across the back with a strap over the chest.
        box(p + "Tube", (0.18, 0.12, 0.74), (0.0, 0.25, 1.1), rot=rad(0, 52, 0), bevel=0.05, segs=3, m=tube_m),
        box(p + "TubeText", (0.12, 0.125, 0.1), (0.0, 0.25, 1.1), rot=rad(0, 52, 0), bevel=0.02, m=white),
        tube(p + "TubeStrap", [(0.24, 0.15, 1.35), (0.1, -0.18, 1.24), (-0.1, -0.19, 1.04), (-0.25, -0.1, 0.96)], 0.018, m=mat("Strap", "#1c1830", rough=0.5), segs=6),
        cyl(p + "Whistle", 0.022, 0.06, (0.1, -0.2, 1.18), rot=rad(0, 90, 0), segs=10, bevel=0.006, m=mat("WhistleOrange", "#ff8a2a", rough=0.4)),
    ])
    parts += pelvis(p, shorts)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, red, skin_m, skin_m)
        parts += leg(p, side, shorts, skin_m, sandal, white, boot_h=0.07, knee_m=skin_m, wide=0.0)
        parts += bind(f"Thigh.{s}", [
            box(f"{p}Leg{s}", (0.235, 0.255, 0.3), (side * 0.13, 0, 0.62), bevel=0.07, segs=3, m=shorts),
            box(f"{p}LegStripe{s}", (0.24, 0.26, 0.05), (side * 0.13, 0, 0.52), bevel=0.02, m=shorts_hi),
        ])
        parts += bind(f"Shin.{s}", [box(f"{p}Toes{s}", (0.2, 0.12, 0.07), (side * 0.13, -0.18, 0.09), bevel=0.03, m=skin_m)])
    return parts, "wave"


def op_midway_maestro():
    """Carnival barker: striped blazer, bow tie, straw boater, grand moustache."""
    p = "MM_"
    skin_m = mat("Skin", "#f2c09a", rough=0.55)
    pink = mat("StripePink", "#ff3f9f", rough=0.5)
    cream = mat("StripeCream", "#fff0d4", rough=0.5)
    straw = mat("Straw", "#f2cf7a", rough=0.75)
    band = mat("HatBand", "#6b35b8", rough=0.5)
    pants = mat("Trousers", "#3d1f73", rough=0.6)
    shoe = mat("Shoe", "#1c1830", rough=0.3)
    spat = mat("Spat", "#f7f4f2", rough=0.5)
    tie = mat("BowTie", "#ffd93b", rough=0.4)
    stache = mat("Moustache", "#3d2318", rough=0.7)
    gold = mat("Gold", "#ffc23d", rough=0.25, metal=0.85)
    glove = mat("WhiteGlove", "#fbfaff", rough=0.5)
    shirt = mat("Shirt", "#f7f4f2", rough=0.55)
    parts = head_base(p, skin_m)
    parts += face(p, iris="#2a4a1e", brow="#3d2318", mouth="smile", blush=True)
    parts += bind("Head", [
        # Curly moustache.
        sphere(p + "StacheL", 0.045, (0.05, FACE_Y - 0.03, HEAD_Z - 0.06), scale=(1.4, 0.6, 0.7), m=stache, segs=10, rings=6),
        sphere(p + "StacheR", 0.045, (-0.05, FACE_Y - 0.03, HEAD_Z - 0.06), scale=(1.4, 0.6, 0.7), m=stache, segs=10, rings=6),
        torus(p + "CurlL", 0.025, 0.012, (0.115, FACE_Y - 0.025, HEAD_Z - 0.035), rot=rad(90, 0, 0), m=stache, major_segs=12, minor_segs=5, arc=math.radians(250), start=math.radians(-90)),
        torus(p + "CurlR", 0.025, 0.012, (-0.115, FACE_Y - 0.025, HEAD_Z - 0.035), rot=rad(90, 0, 180), m=stache, major_segs=12, minor_segs=5, arc=math.radians(250), start=math.radians(-90)),
        box(p + "Hair", (0.5, 0.42, 0.12), (0, 0.04, HEAD_Z + 0.2), bevel=0.05, m=stache),
        # Straw boater.
        cyl(p + "Brim", 0.38, 0.03, (0, 0, HEAD_Z + 0.25), segs=28, bevel=0.012, m=straw),
        cyl(p + "Crown", 0.25, 0.14, (0, 0, HEAD_Z + 0.33), segs=24, bevel=0.03, m=straw),
        cyl(p + "Band", 0.255, 0.05, (0, 0, HEAD_Z + 0.3), segs=24, bevel=0.01, m=band),
        prism(p + "Ticket", [(-0.04, 0.0), (0.04, 0.0), (0.04, 0.09), (-0.04, 0.09)], 0.012, (0.2, -0.13, HEAD_Z + 0.31), rot=rad(0, 0, 40), m=mat("TicketGold", "#ffd93b", rough=0.4)),
    ])
    parts += torso(p, pink)
    for i in range(6):
        x = -0.225 + i * 0.09
        parts += bind("Spine", [box(f"{p}Stripe{i}", (0.035, 0.352, 0.43), (x, 0, 1.16), bevel=0.012, m=cream)])
    parts += bind("Spine", [
        prism(p + "Shirt", [(-0.1, 0.2), (0.1, 0.2), (0.0, -0.05)], 0.03, (0, -0.17, 1.17), m=shirt),
        prism(p + "LapelL", [(0.0, 0.2), (0.1, 0.2), (0.12, -0.02), (0.02, -0.06)], 0.035, (0.0, -0.18, 1.17), m=band, bevel=0.008),
        prism(p + "LapelR", [(0.0, 0.2), (-0.1, 0.2), (-0.12, -0.02), (-0.02, -0.06)], 0.035, (0.0, -0.18, 1.17), m=band, bevel=0.008),
        sphere(p + "TieKnot", 0.028, (0, -0.2, 1.34), m=tie, segs=10, rings=6),
        prism(p + "TieL", [(0.0, 0.0), (0.08, 0.04), (0.08, -0.04)], 0.03, (0.0, -0.195, 1.34), m=tie, bevel=0.008),
        prism(p + "TieR", [(0.0, 0.0), (-0.08, 0.04), (-0.08, -0.04)], 0.03, (0.0, -0.195, 1.34), m=tie, bevel=0.008),
        sphere(p + "Button0", 0.018, (0.06, -0.185, 1.08), m=gold, segs=8, rings=5),
        sphere(p + "Button1", 0.018, (0.06, -0.185, 1.0), m=gold, segs=8, rings=5),
        prism(p + "Flower", star_outline(0.035, 0.02, 6, 90), 0.02, (0.18, -0.185, 1.3), m=mat("Carnation", "#ff86c4", rough=0.6)),
    ])
    parts += pelvis(p, pants)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, pink, pink, glove, cuff_m=cream)
        parts += stripes_on_box(f"{p}SleeveStripe{s}", f"UpperArm.{s}", (0.15, 0.16, 0.26), (side * 0.36, 0, 1.16), 3, cream, width=0.03)
        parts += leg(p, side, pants, pants, shoe, shoe, boot_h=0.13, boot_cuff=spat)
    # Cane in the left hand.
    parts += bind("ForeArm.L", [
        cyl(p + "Cane", 0.018, 0.86, (0.39, -0.07, 0.43), segs=10, bevel=0.0, m=mat("Cane", "#1c1830", rough=0.3)),
        sphere(p + "CaneTop", 0.035, (0.39, -0.07, 0.74 + 0.11), m=gold, segs=10, rings=6),
    ])
    return parts, "wave"


def op_glitch():
    """GL1TCH: a hologram operator with a screen for a face and stray voxels."""
    p = "GL_"
    holo = mat("FxHoloBody", "#35f0ff", rough=0.3, emit=1.2)
    holo2 = mat("FxHoloAccent", "#ff3fa4", rough=0.3, emit=1.2)
    frame = mat("GlitchFrame", "#14102a", rough=0.35, metal=0.3)
    screen = mat("Screen", "#0a0816", rough=0.2)
    pixel = mat("ScreenPixel", "#35f0ff", rough=0.2, emit=3.0)
    pixel2 = mat("ScreenPixelPink", "#ff3fa4", rough=0.2, emit=3.0)
    parts = bind("Head", [
        box(p + "Monitor", (0.54, 0.44, 0.46), (0, 0.0, HEAD_Z + 0.01), bevel=0.06, segs=3, m=frame),
        box(p + "Screen", (0.44, 0.04, 0.34), (0, -0.21, HEAD_Z + 0.01), bevel=0.03, m=screen),
        cyl(p + "Neck", 0.08, 0.1, (0, 0, 1.36), segs=12, bevel=0.02, m=holo),
        box(p + "AntennaL", (0.03, 0.03, 0.16), (0.2, 0.05, HEAD_Z + 0.3), rot=rad(0, 20, 0), bevel=0.008, m=frame),
        sphere(p + "AntennaTip", 0.035, (0.235, 0.05, HEAD_Z + 0.39), m=pixel2, segs=8, rings=5),
    ])
    # Pixel eyes (^ ^) and a pixel smile.
    px = 0.034
    eye = [(-1, 0), (0, 1), (1, 0)]
    for side in (-1, 1):
        for i, (u, v) in enumerate(eye):
            parts += bind("Head", [box(f"{p}Eye{side}{i}", (px, 0.02, px), (side * 0.1 + u * px, -0.235, HEAD_Z + 0.06 + v * px), bevel=0.004, m=pixel)])
    for i, (u, v) in enumerate([(-2, 1), (-1, 0), (0, 0), (1, 0), (2, 1)]):
        parts += bind("Head", [box(f"{p}Mouth{i}", (px, 0.02, px), (u * px, -0.235, HEAD_Z - 0.07 + v * px), bevel=0.004, m=pixel2)])
    parts += bind("Spine", [
        box(p + "Chest", (0.5, 0.32, 0.4), (0, 0, 1.17), bevel=0.06, segs=2, m=holo),
        box(p + "Core", (0.14, 0.05, 0.14), (0, -0.16, 1.2), rot=rad(0, 45, 0), bevel=0.02, m=holo2),
        box(p + "SliceA", (0.56, 0.3, 0.04), (0.04, 0.0, 1.06), bevel=0.01, m=holo2),
        box(p + "SliceB", (0.52, 0.34, 0.03), (-0.05, 0.0, 1.29), bevel=0.01, m=holo),
        box(p + "Belt", (0.46, 0.3, 0.05), (0, 0, 0.98), bevel=0.015, m=frame),
    ])
    rng = random.Random(9)
    for i in range(10):
        bone = rng.choice(["Spine", "Head", "Hips"])
        z = {"Spine": 1.2, "Head": HEAD_Z, "Hips": 0.9}[bone] + rng.uniform(-0.15, 0.2)
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.34, 0.46)
        sz = rng.uniform(0.03, 0.06)
        parts += bind(bone, [box(f"{p}Voxel{i}", (sz, sz, sz), (math.cos(a) * r, math.sin(a) * r, z), rot=rad(rng.uniform(0, 45), rng.uniform(0, 45), 0),
                                 bevel=0.004, m=holo if i % 3 else holo2)])
    parts += pelvis(p, holo, w=0.42, belt=None)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, holo, holo, holo2, shoulder_m=frame, cuff_m=frame)
        parts += leg(p, side, holo, holo, frame, holo2, knee_m=frame, boot_h=0.16)
        parts += bind(f"ForeArm.{s}", [box(f"{p}ArmSlice{s}", (0.17, 0.17, 0.03), (side * 0.38 + side * 0.02, 0, 0.95), bevel=0.008, m=holo2)])
        parts += bind(f"Thigh.{s}", [box(f"{p}LegSlice{s}", (0.23, 0.24, 0.03), (side * 0.13 - side * 0.02, 0, 0.62), bevel=0.008, m=holo2)])
    return parts, "flex"


def op_arcade_champion():
    """Arcade Champion: gold suit, purple cape, crown, star shades, title belt."""
    p = "CH_"
    skin_m = mat("Skin", "#a86a42", rough=0.55)
    gold = mat("FxGoldSuit", "#ffc23d", rough=0.25, metal=0.9)
    gold_trim = mat("GoldTrim", "#ffd96a", rough=0.2, metal=0.9)
    purple = mat("Cape", "#6b35b8", rough=0.55)
    purple_in = mat("CapeLining", "#ff3f9f", rough=0.5)
    shades = mat("StarShades", "#ff3f9f", rough=0.2, metal=0.3)
    lens = mat("ShadeLens", "#1c1830", rough=0.1, metal=0.5)
    gem_r = mat("GemRed", "#ff2f5f", rough=0.15, emit=0.8)
    gem_b = mat("GemBlue", "#3fc4ff", rough=0.15, emit=0.8)
    hair = mat("Hair", "#1c1220", rough=0.8)
    shoe = mat("Kick", "#6b35b8", rough=0.4)
    sole = mat("KickSole", "#f7f4f2", rough=0.4)
    parts = head_base(p, skin_m)
    parts += face(p, iris="#2a1a12", brow="#1c1220", mouth="grin", blush=False)
    parts += bind("Head", [
        box(p + "Hair", (0.5, 0.4, 0.14), (0, 0.04, HEAD_Z + 0.2), bevel=0.06, m=hair),
        # Star-shaped shades over the eyes.
        prism(p + "ShadeL", star_outline(0.085, 0.05, 5, 90), 0.03, (0.105, FACE_Y - 0.03, HEAD_Z + 0.035), m=shades, bevel=0.008),
        prism(p + "ShadeR", star_outline(0.085, 0.05, 5, 90), 0.03, (-0.105, FACE_Y - 0.03, HEAD_Z + 0.035), m=shades, bevel=0.008),
        prism(p + "LensL", star_outline(0.06, 0.035, 5, 90), 0.032, (0.105, FACE_Y - 0.036, HEAD_Z + 0.035), m=lens),
        prism(p + "LensR", star_outline(0.06, 0.035, 5, 90), 0.032, (-0.105, FACE_Y - 0.036, HEAD_Z + 0.035), m=lens),
        box(p + "Bridge", (0.05, 0.02, 0.02), (0, FACE_Y - 0.035, HEAD_Z + 0.06), bevel=0.006, m=shades),
        # Crown.
        cyl(p + "CrownBand", 0.21, 0.09, (0, 0.02, HEAD_Z + 0.31), segs=24, bevel=0.015, m=gold),
    ])
    for i in range(5):
        a = math.radians(-90 + (i - 2) * 38)
        x, y = math.cos(a) * 0.2, math.sin(a) * 0.2 + 0.02
        parts += bind("Head", [
            cyl(f"{p}Spike{i}", 0.045, 0.12, (x, y, HEAD_Z + 0.4), segs=8, bevel=0.008, m=gold, radius_top=0.006),
            sphere(f"{p}Pearl{i}", 0.022, (x, y, HEAD_Z + 0.465), m=gold_trim, segs=8, rings=5),
            sphere(f"{p}Gem{i}", 0.024, (math.cos(a) * 0.212, math.sin(a) * 0.212 + 0.02, HEAD_Z + 0.31), scale=(1, 1, 1.25),
                   m=gem_r if i % 2 == 0 else gem_b, segs=8, rings=6),
        ])
    parts += torso(p, gold)
    parts += bind("Spine", [
        box(p + "Lapel", (0.24, 0.04, 0.3), (0, -0.168, 1.2), bevel=0.03, m=purple),
        prism(p + "ChestStar", star_outline(0.07, 0.035, 5, 90), 0.03, (0, -0.19, 1.22), m=gold_trim, bevel=0.006),
        box(p + "Collar", (0.5, 0.34, 0.08), (0, 0.0, 1.35), bevel=0.03, m=purple_in),
        # Cape: hangs from the shoulders down the back.
        prism(p + "Cape", [(-0.3, 0.0), (0.3, 0.0), (0.42, -0.84), (0.0, -0.9), (-0.42, -0.84)], 0.035, (0, 0.2, 1.36), m=purple, bevel=0.012),
        prism(p + "CapeIn", [(-0.28, -0.02), (0.28, -0.02), (0.39, -0.82), (0.0, -0.87), (-0.39, -0.82)], 0.02, (0, 0.18, 1.36), m=purple_in),
        sphere(p + "ClaspL", 0.035, (0.23, -0.12, 1.34), m=gem_r, segs=8, rings=6),
        sphere(p + "ClaspR", 0.035, (-0.23, -0.12, 1.34), m=gem_r, segs=8, rings=6),
    ])
    parts += pelvis(p, gold)
    # Title belt.
    parts += bind("Hips", [
        box(p + "Belt", (0.5, 0.36, 0.09), (0, 0, 0.985), bevel=0.03, m=purple),
        cyl(p + "Plate", 0.11, 0.035, (0, -0.19, 0.985), rot=rad(90, 0, 0), segs=24, bevel=0.01, m=gold_trim),
        prism(p + "PlateStar", star_outline(0.07, 0.034, 5, 90), 0.03, (0, -0.21, 0.985), m=gem_r, bevel=0.006),
        box(p + "SidePlateL", (0.08, 0.03, 0.07), (0.17, -0.18, 0.985), bevel=0.01, m=gold_trim),
        box(p + "SidePlateR", (0.08, 0.03, 0.07), (-0.17, -0.18, 0.985), bevel=0.01, m=gold_trim),
    ])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, gold, gold, gold_trim, shoulder_m=purple, cuff_m=purple)
        parts += leg(p, side, gold, gold, shoe, sole, boot_h=0.17, boot_cuff=gold_trim)
        parts += bind(f"Shin.{s}", [prism(f"{p}KickStar{s}", star_outline(0.045, 0.022, 5, 90), 0.02, (side * 0.245, -0.05, 0.11),
                                          rot=rad(0, 0, side * 90), m=gold_trim)])
    return parts, "flex"


OPERATORS = {
    "boardwalk_ranger": op_boardwalk_ranger,
    "neon_courier": op_neon_courier,
    "deep_diver": op_deep_diver,
    "astro_cadet": op_astro_cadet,
    "frost_guard": op_frost_guard,
    "surf_rescue": op_surf_rescue,
    "midway_maestro": op_midway_maestro,
    "glitch": op_glitch,
    "arcade_champion": op_arcade_champion,
}


def build(op_id):
    scene = reset_scene()
    scene.render.fps = FPS
    armature = build_armature()
    parts, pose_style = OPERATORS[op_id]()
    body = skin("Body", parts, armature)
    build_animations(armature, pose_style)
    save("operator_" + op_id, [armature, body], animations=True)


if __name__ == "__main__":
    only = sys.argv[1:] if len(sys.argv) > 1 else list(OPERATORS)
    for op in only:
        build(op)
