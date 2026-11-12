"""Boardwalk zombie: one rig, two outfit silhouettes, six animation clips.

    Outfit_Tourist     wide Tourist Shambler (floral shirt, cargo shorts, backwards cap)
    Outfit_Lifeguard   lean Lifeguard Runner (tank top, red shorts, red cap)

Both meshes are skinned to the same armature and share its clips:
    Idle-loop, Walk-loop, Run-loop, Attack, Hit, Die

The body is built from chunky rigid parts, each bound to a single bone (toy
style, no deforming joints). The character faces -Y in Blender (+Z in Godot).
Materials named "Shirt" can be tinted per zombie by the game.
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
    ("Hips", (0, 0, 0.78), (0, 0, 0.98), None),
    ("Spine", (0, 0, 0.98), (0, 0, 1.3), "Hips"),
    ("Head", (0, 0, 1.32), (0, 0, 1.8), "Spine"),
    ("UpperArm.L", (0.36, 0, 1.26), (0.41, 0, 0.98), "Spine"),
    ("ForeArm.L", (0.41, 0, 0.98), (0.43, 0, 0.62), "UpperArm.L"),
    ("UpperArm.R", (-0.36, 0, 1.26), (-0.41, 0, 0.98), "Spine"),
    ("ForeArm.R", (-0.41, 0, 0.98), (-0.43, 0, 0.62), "UpperArm.R"),
    ("Thigh.L", (0.16, 0, 0.78), (0.16, 0, 0.45), "Hips"),
    ("Shin.L", (0.16, 0, 0.45), (0.16, 0, 0.06), "Thigh.L"),
    ("Thigh.R", (-0.16, 0, 0.78), (-0.16, 0, 0.45), "Hips"),
    ("Shin.R", (-0.16, 0, 0.45), (-0.16, 0, 0.06), "Thigh.R"),
]


def build_armature():
    data = bpy.data.armatures.new("ZombieRig")
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


# ---------------------------------------------------------------------------
# Body
# ---------------------------------------------------------------------------

def head_parts(prefix, width, m):
    skin_m, dark, eye, pupil, mouth, teeth = m["skin"], m["skin_dark"], m["eye"], m["pupil"], m["mouth"], m["teeth"]
    w = width
    parts = [
        box(prefix + "Skull", (w, 0.52, 0.48), (0, 0, 1.6), bevel=0.17, segs=4, m=skin_m),
        box(prefix + "Jaw", (w * 0.86, 0.48, 0.24), (0, -0.015, 1.38), bevel=0.09, segs=3, m=skin_m),
        box(prefix + "Mouth", (w * 0.5, 0.08, 0.11), (0, -0.235, 1.38), rot=rad(0, 0, 0), bevel=0.03, m=mouth),
        sphere(prefix + "Nose", 0.045, (0, -0.27, 1.5), scale=(1.1, 0.8, 0.8), m=dark, segs=8, rings=5),
    ]
    for i, x in enumerate((-0.085, 0.0, 0.085)):
        parts.append(box(f"{prefix}Tooth{i}", (0.055, 0.04, 0.05), (x * (w / 0.6), -0.262, 1.415), bevel=0.012, m=teeth))
    parts.append(box(prefix + "ToothLow", (0.06, 0.04, 0.045), (0.05, -0.262, 1.345), bevel=0.012, m=teeth))
    for i, side in enumerate((-1, 1)):
        x = side * w * 0.235
        parts += [
            sphere(f"{prefix}Eye{i}", 0.105, (x, -0.215, 1.63), scale=(1.0, 0.6, 1.1), m=eye, segs=12, rings=8),
            sphere(f"{prefix}Pupil{i}", 0.02, (x + side * 0.01, -0.283, 1.625), m=pupil, segs=6, rings=4),
            box(f"{prefix}Brow{i}", (0.2, 0.07, 0.05), (x, -0.24, 1.765), rot=rad(0, side * -14, 0), bevel=0.02, m=dark),
            sphere(f"{prefix}Ear{i}", 0.075, (side * (w * 0.5 + 0.02), 0.02, 1.57), scale=(0.6, 1, 1.2), m=skin_m, segs=8, rings=6),
            sphere(f"{prefix}EyeBag{i}", 0.09, (x, -0.2, 1.555), scale=(1.1, 0.5, 0.45), m=dark, segs=8, rings=5),
        ]
    return bind("Head", parts)


def limb_parts(prefix, side, m, arm_w, leg_w, sleeve=None, shorts=None, shoe=None, sock=True, band=None, flipflop=False):
    """One arm and one leg. side = +1 (left, +X) or -1 (right)."""
    s = "L" if side > 0 else "R"
    skin_m = m["skin"]
    ax, lx = side * 0.41, side * 0.16
    upper = [box(f"{prefix}UpperArm{s}", (arm_w, arm_w + 0.02, 0.3), (side * 0.395, 0, 1.1), bevel=0.06, segs=3, m=skin_m),
             sphere(f"{prefix}Shoulder{s}", arm_w * 0.62, (side * 0.37, 0, 1.25), m=sleeve or skin_m, segs=10, rings=7)]
    if sleeve:
        upper.append(box(f"{prefix}Sleeve{s}", (arm_w + 0.07, arm_w + 0.09, 0.2), (side * 0.385, 0, 1.19), bevel=0.06, segs=3, m=sleeve))
    fore = [
        box(f"{prefix}ForeArm{s}", (arm_w - 0.01, arm_w + 0.01, 0.32), (side * 0.42, 0, 0.82), bevel=0.055, segs=3, m=skin_m),
        sphere(f"{prefix}Elbow{s}", arm_w * 0.56, (side * 0.41, 0, 0.98), m=skin_m, segs=10, rings=7),
        box(f"{prefix}Hand{s}", (arm_w + 0.05, 0.13, 0.19), (side * 0.43, -0.01, 0.6), bevel=0.055, segs=3, m=skin_m),
        box(f"{prefix}Thumb{s}", (0.05, 0.055, 0.1), (side * 0.43 - side * (arm_w * 0.5 + 0.03), -0.04, 0.62), bevel=0.02, m=skin_m),
    ]
    for i in range(3):
        fore.append(box(f"{prefix}Finger{s}{i}", (0.055, 0.06, 0.11), (side * 0.43 + (i - 1) * 0.068, -0.02, 0.475),
                        rot=rad(-12, 0, 0), bevel=0.02, m=skin_m))
    if band:
        fore.append(box(f"{prefix}Band{s}", (arm_w + 0.02, arm_w + 0.04, 0.06), (side * 0.425, 0, 0.71), bevel=0.02, m=band))
    thigh = [box(f"{prefix}Thigh{s}", (leg_w + 0.07, leg_w + 0.1, 0.32), (lx, 0, 0.63), bevel=0.07, segs=3, m=shorts or skin_m)]
    shin = [
        box(f"{prefix}Shin{s}", (leg_w, leg_w + 0.02, 0.34), (lx, 0, 0.33), bevel=0.06, segs=3, m=skin_m),
        sphere(f"{prefix}Knee{s}", leg_w * 0.58, (lx, -0.01, 0.46), m=skin_m, segs=10, rings=7),
    ]
    if flipflop:
        shin += [
            box(f"{prefix}Foot{s}", (leg_w + 0.03, 0.34, 0.1), (lx, -0.08, 0.11), bevel=0.04, m=skin_m),
            box(f"{prefix}Sole{s}", (leg_w + 0.07, 0.42, 0.05), (lx, -0.08, 0.035), bevel=0.02, m=shoe),
            box(f"{prefix}Strap{s}", (leg_w + 0.05, 0.05, 0.05), (lx, -0.16, 0.15), bevel=0.02, m=shoe),
        ]
    else:
        if sock:
            shin.append(box(f"{prefix}Sock{s}", (leg_w + 0.02, leg_w + 0.04, 0.13), (lx, 0, 0.23), bevel=0.04, m=m["white"]))
        shin += [
            box(f"{prefix}Shoe{s}", (leg_w + 0.07, 0.44, 0.17), (lx, -0.08, 0.115), bevel=0.07, segs=3, m=shoe),
            box(f"{prefix}Sole{s}", (leg_w + 0.085, 0.455, 0.055), (lx, -0.08, 0.035), bevel=0.02, m=m["white"]),
            box(f"{prefix}Toe{s}", (leg_w + 0.075, 0.12, 0.09), (lx, -0.27, 0.09), bevel=0.04, m=m["white"]),
        ]
    return bind(f"UpperArm.{s}", upper) + bind(f"ForeArm.{s}", fore) + bind(f"Thigh.{s}", thigh) + bind(f"Shin.{s}", shin)


def tourist(m):
    p = "T_"
    shirt, dots, shorts = m["shirt"], m["shirt_dots"], m["shorts"]
    parts = head_parts(p, 0.62, m)
    parts += bind("Head", [
        # Backwards cap with a tuft of hair poking out the front.
        sphere(p + "Cap", 0.33, (0, 0.02, 1.76), scale=(1.0, 0.92, 0.62), m=m["cap"], segs=14, rings=8),
        box(p + "CapBrim", (0.36, 0.26, 0.045), (0, 0.36, 1.72), rot=rad(-12, 0, 0), bevel=0.02, m=m["cap"]),
        box(p + "CapBand", (0.64, 0.5, 0.06), (0, 0.02, 1.775), bevel=0.02, m=m["cap_trim"]),
        sphere(p + "CapButton", 0.04, (0, 0.02, 1.965), m=m["cap_trim"], segs=8, rings=5),
        box(p + "HairFront", (0.4, 0.1, 0.12), (0, -0.23, 1.8), rot=rad(12, 0, 0), bevel=0.04, m=m["hair"]),
        box(p + "HairBack", (0.52, 0.12, 0.2), (0, 0.24, 1.5), bevel=0.05, m=m["hair"]),
    ])
    parts += bind("Spine", [
        box(p + "Torso", (0.7, 0.46, 0.56), (0, 0, 1.13), bevel=0.14, segs=4, m=shirt),
        box(p + "Belly", (0.62, 0.44, 0.24), (0, -0.02, 0.98), bevel=0.1, segs=3, m=shirt),
        box(p + "Tee", (0.22, 0.06, 0.46), (0, -0.215, 1.12), bevel=0.02, m=m["white"]),
        box(p + "CollarL", (0.17, 0.07, 0.1), (0.13, -0.215, 1.36), rot=rad(0, 30, 0), bevel=0.02, m=shirt),
        box(p + "CollarR", (0.17, 0.07, 0.1), (-0.13, -0.215, 1.36), rot=rad(0, -30, 0), bevel=0.02, m=shirt),
        box(p + "Neck", (0.26, 0.24, 0.12), (0, 0, 1.4), bevel=0.05, m=m["skin"]),
    ])
    # Hibiscus print: flattened blobs on the shirt surface.
    rng = random.Random(3)
    spots = []
    for i in range(9):
        x = rng.choice((-1, 1)) * rng.uniform(0.17, 0.3)
        z = rng.uniform(0.95, 1.33)
        spots.append(sphere(f"{p}PrintF{i}", 0.05, (x, -0.232, z), scale=(1, 0.25, 1), m=dots, segs=7, rings=4))
    for i in range(10):
        spots.append(sphere(f"{p}PrintB{i}", 0.055, (rng.uniform(-0.28, 0.28), 0.232, rng.uniform(0.95, 1.33)), scale=(1, 0.25, 1), m=dots, segs=7, rings=4))
    for i in range(6):
        side = -1 if i % 2 else 1
        spots.append(sphere(f"{p}PrintS{i}", 0.05, (side * 0.352, rng.uniform(-0.14, 0.14), rng.uniform(0.95, 1.2)), scale=(0.25, 1, 1), m=dots, segs=7, rings=4))
    parts += bind("Spine", spots)
    parts += bind("Hips", [
        box(p + "Shorts", (0.66, 0.45, 0.3), (0, 0, 0.84), bevel=0.09, segs=3, m=shorts),
        box(p + "Belt", (0.68, 0.47, 0.07), (0, 0, 0.955), bevel=0.02, m=m["belt"]),
        box(p + "Buckle", (0.1, 0.03, 0.08), (0, -0.24, 0.955), bevel=0.012, m=m["buckle"]),
    ])
    for side in (1, -1):
        parts += limb_parts(p, side, m, arm_w=0.19, leg_w=0.21, sleeve=shirt, shorts=shorts, shoe=m["shoe"], band=m["cap_trim"])
        s = "L" if side > 0 else "R"
        parts += bind(f"Thigh.{s}", [box(f"{p}Pocket{s}", (0.06, 0.2, 0.17), (side * 0.3, 0, 0.62), bevel=0.02, m=m["shorts_dark"])])
    return parts


def lifeguard(m):
    p = "L_"
    red, tank = m["red"], m["tank"]
    parts = head_parts(p, 0.54, m)
    parts += bind("Head", [
        sphere(p + "Cap", 0.3, (0, 0.0, 1.77), scale=(1.0, 0.95, 0.62), m=red, segs=14, rings=8),
        box(p + "CapBrim", (0.34, 0.26, 0.045), (0, -0.35, 1.75), rot=rad(10, 0, 0), bevel=0.02, m=red),
        box(p + "CapPatch", (0.2, 0.04, 0.13), (0, -0.265, 1.83), rot=rad(-18, 0, 0), bevel=0.015, m=m["white"]),
        box(p + "CapCrossH", (0.12, 0.03, 0.035), (0, -0.287, 1.835), rot=rad(-18, 0, 0), bevel=0.0, m=red),
        box(p + "CapCrossV", (0.035, 0.03, 0.1), (0, -0.287, 1.835), rot=rad(-18, 0, 0), bevel=0.0, m=red),
        box(p + "Hair", (0.46, 0.1, 0.16), (0, 0.23, 1.52), bevel=0.04, m=m["hair"]),
    ])
    parts += bind("Spine", [
        box(p + "Torso", (0.5, 0.36, 0.56), (0, 0, 1.13), bevel=0.11, segs=4, m=tank),
        box(p + "Waist", (0.46, 0.34, 0.2), (0, 0, 0.96), bevel=0.08, segs=3, m=tank),
        box(p + "Chest", (0.3, 0.3, 0.14), (0, 0, 1.38), bevel=0.05, m=m["skin"]),
        box(p + "Neck", (0.22, 0.2, 0.12), (0, 0, 1.41), bevel=0.05, m=m["skin"]),
        box(p + "StrapL", (0.11, 0.37, 0.14), (0.15, 0, 1.38), bevel=0.04, m=tank),
        box(p + "StrapR", (0.11, 0.37, 0.14), (-0.15, 0, 1.38), bevel=0.04, m=tank),
        box(p + "CrossH", (0.19, 0.03, 0.06), (0, -0.185, 1.08), bevel=0.0, m=red),
        box(p + "CrossV", (0.06, 0.03, 0.19), (0, -0.185, 1.08), bevel=0.0, m=red),
        text(p + "Label", "LIFEGUARD", 0.062, 0.012, (0, -0.186, 1.24), m=red),
        # Whistle on a cord.
        cyl(p + "Whistle", 0.035, 0.07, (0.1, -0.2, 1.3), rot=rad(0, 90, 0), segs=8, bevel=0.008, m=m["buckle"]),
    ])
    parts += bind("Hips", [
        box(p + "Shorts", (0.5, 0.37, 0.3), (0, 0, 0.84), bevel=0.08, segs=3, m=red),
        box(p + "Waistband", (0.51, 0.38, 0.06), (0, 0, 0.955), bevel=0.02, m=m["white"]),
    ])
    for side in (1, -1):
        parts += limb_parts(p, side, m, arm_w=0.15, leg_w=0.16, sleeve=None, shorts=red, shoe=m["flipflop"], band=red, flipflop=True)
        s = "L" if side > 0 else "R"
        parts += bind(f"Thigh.{s}", [box(f"{p}Stripe{s}", (0.03, 0.08, 0.3), (side * 0.275, 0, 0.64), bevel=0.0, m=m["white"])])
    return parts


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------

def set_pose(armature, frame, pose, hips_loc=(0, 0, 0)):
    """Key every bone at `frame`. `pose` maps bone -> (rx, ry, rz) in degrees,
    expressed in armature axes (X = lean forward +, Y = roll, Z = turn left +)."""
    for pb in armature.pose.bones:
        rest = pb.bone.matrix_local.to_quaternion()
        rx, ry, rz = pose.get(pb.name, (0, 0, 0))
        q = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_quaternion()
        pb.rotation_quaternion = rest.inverted() @ q @ rest
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        if pb.name == "Hips":
            pb.location = rest.inverted() @ Vector(hips_loc)
            pb.keyframe_insert("location", frame=frame)


def arms(left_upper, left_fore, right_upper, right_fore, spread=10):
    """Arm pose shorthand: forward swing (degrees, negative = forward)."""
    return {
        "UpperArm.L": (left_upper, -spread, 0), "ForeArm.L": (left_fore, 0, 0),
        "UpperArm.R": (right_upper, spread, 0), "ForeArm.R": (right_fore, 0, 0),
    }


def clip_walk():
    """Shamble: stiff legs, lolling head, both arms reaching forward."""
    def pose(phase):  # phase 0..1
        s, c = math.sin(phase * math.tau), math.cos(phase * math.tau)
        p = {
            "Hips": (6, 5 * c, 6 * c),
            "Spine": (15, -4 * c, -9 * c),
            "Head": (-8, 9 * c, 5 * s),
            "Thigh.L": (-3 - 25 * c, 0, 0), "Thigh.R": (-3 + 25 * c, 0, 0),
            "Shin.L": (10 + 34 * max(0.0, s), 0, 0), "Shin.R": (10 + 34 * max(0.0, -s), 0, 0),
        }
        p.update(arms(-74 + 6 * c, -14 - 8 * s, -58 - 8 * c, -24 + 8 * s, spread=8))
        return p, (0, 0, -0.035 * abs(c))
    return "Walk-loop", [(round(i * 32 / 8), *pose(i / 8)) for i in range(9)]


def clip_run():
    """Sprint: leaning in, long strides, arms clawing ahead."""
    def pose(phase):
        s, c = math.sin(phase * math.tau), math.cos(phase * math.tau)
        p = {
            "Hips": (14, 4 * c, 9 * c),
            "Spine": (26, 0, -13 * c),
            "Head": (-26, 5 * c, 0),
            "Thigh.L": (-8 - 44 * c, 0, 0), "Thigh.R": (-8 + 44 * c, 0, 0),
            "Shin.L": (22 + 62 * max(0.0, s), 0, 0), "Shin.R": (22 + 62 * max(0.0, -s), 0, 0),
        }
        p.update(arms(-78 - 20 * c, -24 + 16 * c, -78 + 20 * c, -24 - 16 * c, spread=12))
        return p, (0, 0, -0.05 * abs(c) + 0.02)
    return "Run-loop", [(round(i * 16 / 8), *pose(i / 8)) for i in range(9)]


def clip_idle():
    def pose(phase):
        s = math.sin(phase * math.tau)
        p = {"Hips": (3, 2 * s, 0), "Spine": (11, -3 * s, 3 * s), "Head": (-4, 7 * s, -4 * s),
             "Thigh.L": (-2, 0, 0), "Thigh.R": (-2, 0, 0), "Shin.L": (6, 0, 0), "Shin.R": (6, 0, 0)}
        p.update(arms(-22 + 4 * s, -22, -16 - 4 * s, -26, spread=10))
        return p, (0, 0, -0.01 + 0.006 * s)
    return "Idle-loop", [(round(i * 48 / 8), *pose(i / 8)) for i in range(9)]


def clip_attack():
    """Obvious windup (arms overhead, leaning back) then a two-handed swipe at frame 13."""
    legs = {"Thigh.L": (-14, 0, 0), "Thigh.R": (12, 0, 0), "Shin.L": (12, 0, 0), "Shin.R": (16, 0, 0)}
    def pose(spine, head, upper, fore, hips=4, spread=12):
        p = {"Hips": (hips, 0, 0), "Spine": (spine, 0, 0), "Head": (head, 0, 0)}
        p.update(legs)
        p.update(arms(upper, fore, upper, fore, spread=spread))
        return p
    return "Attack", [
        (0, pose(14, -8, -68, -16), (0, 0, -0.02)),
        (8, pose(-20, -16, -168, -38, hips=-6, spread=18), (0, 0.03, 0.0)),
        (11, pose(-24, -18, -175, -42, hips=-8, spread=20), (0, 0.04, 0.0)),
        (14, pose(40, 6, -52, -4, hips=10, spread=4), (0, -0.06, -0.05)),
        (18, pose(32, 2, -34, -10, hips=8, spread=6), (0, -0.05, -0.04)),
        (24, pose(14, -8, -68, -16), (0, 0, -0.02)),
    ]


def clip_hit():
    legs = {"Thigh.L": (-10, 0, 0), "Thigh.R": (10, 0, 0), "Shin.L": (12, 0, 0), "Shin.R": (14, 0, 0)}
    def pose(spine, head, upper, twist):
        p = {"Hips": (4, 0, twist), "Spine": (spine, 0, twist), "Head": (head, 0, 0)}
        p.update(legs)
        p.update(arms(upper, -18, upper + 8, -22, spread=14))
        return p
    return "Hit", [
        (0, pose(14, -8, -68, 0), (0, 0, -0.02)),
        (3, pose(-18, -16, -38, 12), (0, 0.05, -0.02)),
        (9, pose(14, -8, -68, 0), (0, 0, -0.02)),
    ]


def clip_die():
    """Topples onto its back, arms flung wide."""
    def pose(hips, spine, head, upper, fore, thigh, shin, spread):
        p = {"Hips": (hips, 0, 0), "Spine": (spine, 0, 0), "Head": (head, 0, 0),
             "Thigh.L": (thigh, 0, 0), "Thigh.R": (thigh + 8, 0, 0), "Shin.L": (shin, 0, 0), "Shin.R": (shin + 6, 0, 0)}
        p.update(arms(upper, fore, upper - 10, fore, spread=spread))
        return p
    return "Die", [
        (0, pose(4, 12, -8, -62, -16, -4, 10, 10), (0, 0, -0.02)),
        (5, pose(-22, -24, -22, -125, -30, 8, 14, 40), (0, 0.06, -0.02)),
        (12, pose(-78, -6, -12, -150, -20, -22, 26, 55), (0, 0.2, -0.46)),
        (16, pose(-92, 0, -6, -165, -10, -10, 14, 62), (0, 0.22, -0.6)),
        (19, pose(-88, 0, -4, -160, -12, -4, 10, 62), (0, 0.22, -0.56)),
        (22, pose(-90, 0, -4, -162, -12, -6, 10, 62), (0, 0.22, -0.58)),
    ]


def build_animations(armature):
    ad = armature.animation_data_create()
    for make in (clip_idle, clip_walk, clip_run, clip_attack, clip_hit, clip_die):
        name, keys = make()
        action = bpy.data.actions.new(name)
        ad.action = action
        for frame, pose, hips_loc in keys:
            set_pose(armature, frame, pose, hips_loc)
        # Store the clip on its own NLA track so every clip is exported.
        track = ad.nla_tracks.new()
        track.name = name
        track.strips.new(name, 0, action)
        ad.action = None
    # Leave the rig in its rest pose.
    for pb in armature.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)


# ---------------------------------------------------------------------------

def build():
    scene = reset_scene()
    scene.render.fps = FPS
    m = dict(
        skin=mat("Skin", "#a3d14a", rough=0.6),
        skin_dark=mat("SkinDark", "#6da336", rough=0.65),
        eye=mat("Eye", "#fbf6c8", rough=0.3, emit=0.55),
        pupil=mat("Pupil", "#2a2a1e", rough=0.4),
        mouth=mat("Mouth", "#2e1a2c", rough=0.7),
        teeth=mat("Teeth", "#fff3d6", rough=0.4),
        white=mat("White", "#f7f4f2", rough=0.6),
        hair=mat("Hair", "#5a3424", rough=0.8),
        shirt=mat("Shirt", "#ff4f9c", rough=0.65),
        shirt_dots=mat("ShirtDots", "#fff0d4", rough=0.65),
        shorts=mat("Shorts", "#c58a55", rough=0.75),
        shorts_dark=mat("ShortsDark", "#a06c3e", rough=0.75),
        belt=mat("Belt", "#4a2c20", rough=0.6),
        buckle=mat("Buckle", "#ffc94a", rough=0.35, metal=0.4),
        cap=mat("Cap", "#f7f4f2", rough=0.6),
        cap_trim=mat("CapTrim", "#ff3f9f", rough=0.6),
        shoe=mat("Shoe", "#ff3f9f", rough=0.55),
        red=mat("LifeguardRed", "#e8263a", rough=0.6),
        tank=mat("Tank", "#f7f4f2", rough=0.65),
        flipflop=mat("FlipFlop", "#ffd93b", rough=0.6),
    )
    armature = build_armature()
    tourist_ob = skin("Outfit_Tourist", tourist(m), armature)
    lifeguard_ob = skin("Outfit_Lifeguard", lifeguard(m), armature)
    build_animations(armature)
    save("zombie", [armature, tourist_ob, lifeguard_ob], animations=True)


if __name__ == "__main__":
    build()
