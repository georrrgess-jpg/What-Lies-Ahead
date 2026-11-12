"""Boardwalk zombie: one rig, two outfit silhouettes, six animation clips.

    Outfit_Tourist     wide Tourist Shambler (floral shirt, cargo shorts)
    Outfit_Lifeguard   lean Lifeguard Runner (tank top, red shorts, red cap)
    Outfit_Bruiser     hulking Boardwalk Bruiser (vest, board shorts, huge fists)

Optional accessory meshes (Acc_<Outfit>_<Name>) are switched on per zombie by
the game, using the accessory slots in each EnemyData resource, so one rig
gives many different-looking zombies.

All meshes are skinned to the same armature and share its clips, authored in
zombie_anim.py (boardwalk_clips): Idle, Walk (shamble), Run (sprint), the
"_Heavy" set for the Bruiser, attacks, Roar, Stagger, Hit_Head, Die_* and Emerge.

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
import zombie_anim  # noqa: E402

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


def limb_parts(prefix, side, m, arm_w, leg_w, sleeve=None, shorts=None, shoe=None, sock=True, band=None, flipflop=False,
               arm_out=0.0, hand=0.0):
    """One arm and one leg. side = +1 (left, +X) or -1 (right).
    arm_out pushes the arm away from the body; hand enlarges the fist."""
    s = "L" if side > 0 else "R"
    skin_m = m["skin"]
    ax, lx = side * (0.41 + arm_out), side * 0.16
    o = side * arm_out
    upper = [box(f"{prefix}UpperArm{s}", (arm_w, arm_w + 0.02, 0.3), (side * 0.395 + o, 0, 1.1), bevel=0.06, segs=3, m=skin_m),
             sphere(f"{prefix}Shoulder{s}", arm_w * 0.66, (side * 0.37 + o, 0, 1.25), m=sleeve or skin_m, segs=10, rings=7)]
    if sleeve:
        upper.append(box(f"{prefix}Sleeve{s}", (arm_w + 0.07, arm_w + 0.09, 0.2), (side * 0.385 + o, 0, 1.19), bevel=0.06, segs=3, m=sleeve))
    hw = arm_w + 0.05 + hand
    fore = [
        box(f"{prefix}ForeArm{s}", (arm_w - 0.01, arm_w + 0.01, 0.32), (side * 0.42 + o, 0, 0.82), bevel=0.055, segs=3, m=skin_m),
        sphere(f"{prefix}Elbow{s}", arm_w * 0.64, (side * 0.41 + o, 0, 0.98), m=skin_m, segs=10, rings=7),
        box(f"{prefix}Hand{s}", (hw, 0.13 + hand, 0.19 + hand), (side * 0.43 + o, -0.01, 0.6 - hand * 0.4), bevel=0.055, segs=3, m=skin_m),
        box(f"{prefix}Thumb{s}", (0.05, 0.055, 0.1), (side * 0.43 + o - side * (hw * 0.5 + 0.01), -0.04, 0.62), bevel=0.02, m=skin_m),
    ]
    for i in range(3):
        fore.append(box(f"{prefix}Finger{s}{i}", (0.055 + hand * 0.3, 0.06 + hand * 0.3, 0.11 + hand * 0.3),
                        (side * 0.43 + o + (i - 1) * (0.068 + hand * 0.3), -0.02, 0.475 - hand * 0.8),
                        rot=rad(-12, 0, 0), bevel=0.02, m=skin_m))
    if band:
        fore.append(box(f"{prefix}Band{s}", (arm_w + 0.02, arm_w + 0.04, 0.06), (side * 0.425 + o, 0, 0.71), bevel=0.02, m=band))
    thigh = [box(f"{prefix}Thigh{s}", (leg_w + 0.07, leg_w + 0.1, 0.32), (lx, 0, 0.63), bevel=0.07, segs=3, m=shorts or skin_m)]
    shin = [
        box(f"{prefix}Shin{s}", (leg_w, leg_w + 0.02, 0.34), (lx, 0, 0.33), bevel=0.06, segs=3, m=skin_m),
        sphere(f"{prefix}Knee{s}", leg_w * 0.62, (lx, -0.01, 0.46), m=skin_m, segs=10, rings=7),
        sphere(f"{prefix}Ankle{s}", leg_w * 0.5, (lx, -0.01, 0.16), m=skin_m, segs=8, rings=6),
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


def tourist_accessories(m):
    p = "TA_"
    acc = {}
    # Backwards cap (pink brim and button so it reads from the front too).
    acc["Acc_Tourist_Cap"] = bind("Head", [
        sphere(p + "Cap", 0.33, (0, 0.02, 1.76), scale=(1.0, 0.92, 0.62), m=m["cap"], segs=14, rings=8),
        box(p + "CapBrim", (0.38, 0.28, 0.05), (0, 0.37, 1.72), rot=rad(-12, 0, 0), bevel=0.02, m=m["cap_trim"]),
        box(p + "CapBand", (0.64, 0.5, 0.06), (0, 0.02, 1.775), bevel=0.02, m=m["cap_trim"]),
        sphere(p + "CapButton", 0.045, (0, 0.02, 1.965), m=m["cap_trim"], segs=8, rings=5),
        box(p + "HairFront", (0.4, 0.1, 0.12), (0, -0.23, 1.8), rot=rad(12, 0, 0), bevel=0.04, m=m["hair"]),
    ])
    # Teal bucket hat.
    acc["Acc_Tourist_Bucket"] = bind("Head", [
        cyl(p + "BucketCrown", 0.3, 0.24, (0, 0, 1.88), segs=18, bevel=0.06, m=m["bucket"], radius_top=0.26),
        cyl(p + "BucketBrim", 0.46, 0.05, (0, 0, 1.76), segs=20, bevel=0.02, m=m["bucket"], radius_top=0.4),
        cyl(p + "BucketBand", 0.305, 0.06, (0, 0, 1.8), segs=18, bevel=0.015, m=m["cap_trim"]),
    ])
    # Big curly hair, with pink sunglasses pushed up on top (like the reference).
    curls = []
    rng = random.Random(11)
    for i in range(16):
        a = math.tau * i / 16
        r = rng.uniform(0.07, 0.1)
        curls.append(sphere(f"{p}Curl{i}", r, (math.cos(a) * 0.27, math.sin(a) * 0.24 + 0.02, 1.8 + rng.uniform(-0.03, 0.04)), m=m["hair_red"], segs=8, rings=6))
    for i in range(7):
        a = math.tau * i / 7
        curls.append(sphere(f"{p}Top{i}", 0.11, (math.cos(a) * 0.14, math.sin(a) * 0.13 + 0.03, 1.9), m=m["hair_red"], segs=8, rings=6))
    for side in (-1, 1):
        curls.append(sphere(f"{p}Side{side}", 0.1, (side * 0.32, 0.06, 1.55), scale=(0.7, 1.0, 1.6), m=m["hair_red"], segs=8, rings=6))
    acc["Acc_Tourist_Hair"] = bind("Head", curls)
    acc["Acc_Tourist_Shades"] = bind("Head", [
        box(p + "ShadeBar", (0.5, 0.04, 0.04), (0, -0.2, 1.9), rot=rad(-35, 0, 0), bevel=0.012, m=m["cap_trim"]),
        sphere(p + "ShadeL", 0.09, (-0.13, -0.21, 1.88), scale=(1.2, 0.35, 0.8), rot=rad(-35, 0, 0), m=m["lens"], segs=10, rings=6),
        sphere(p + "ShadeR", 0.09, (0.13, -0.21, 1.88), scale=(1.2, 0.35, 0.8), rot=rad(-35, 0, 0), m=m["lens"], segs=10, rings=6),
    ])
    # Camera on a strap.
    acc["Acc_Tourist_Camera"] = bind("Spine", [
        box(p + "CamBody", (0.22, 0.09, 0.14), (0.06, -0.27, 1.06), bevel=0.025, m=m["camera"]),
        cyl(p + "CamLens", 0.045, 0.07, (0.08, -0.33, 1.05), rot=rad(90, 0, 0), segs=12, bevel=0.01, m=m["camera_lens"]),
        box(p + "CamFlash", (0.05, 0.02, 0.03), (0.0, -0.32, 1.11), bevel=0.006, m=m["white"]),
        tube(p + "CamStrapL", [(-0.02, -0.25, 1.1), (-0.12, -0.24, 1.34), (-0.12, -0.05, 1.42)], 0.016, m=m["camera"], segs=6),
        tube(p + "CamStrapR", [(0.15, -0.25, 1.1), (0.14, -0.24, 1.34), (0.13, -0.05, 1.42)], 0.016, m=m["camera"], segs=6),
    ])
    return acc


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

def lifeguard_accessories(m):
    p = "LA_"
    red = m["red"]
    return {
        "Acc_Lifeguard_Whistle": bind("Spine", [
            cyl(p + "Whistle", 0.035, 0.07, (0.1, -0.2, 1.3), rot=rad(0, 90, 0), segs=8, bevel=0.008, m=m["buckle"]),
            tube(p + "Cord", [(0.06, -0.19, 1.3), (-0.06, -0.17, 1.38), (-0.08, -0.05, 1.43)], 0.012, m=m["white"], segs=5),
        ]),
        "Acc_Lifeguard_Shades": bind("Head", [
            box(p + "ShadeBar", (0.44, 0.04, 0.035), (0, -0.33, 1.79), rot=rad(14, 0, 0), bevel=0.01, m=m["white"]),
            sphere(p + "ShadeL", 0.08, (-0.11, -0.34, 1.785), scale=(1.25, 0.3, 0.75), rot=rad(14, 0, 0), m=m["lens_mirror"], segs=10, rings=6),
            sphere(p + "ShadeR", 0.08, (0.11, -0.34, 1.785), scale=(1.25, 0.3, 0.75), rot=rad(14, 0, 0), m=m["lens_mirror"], segs=10, rings=6),
        ]),
        "Acc_Lifeguard_Zinc": bind("Head", [
            sphere(p + "Zinc", 0.05, (0, -0.29, 1.5), scale=(1.2, 0.5, 0.8), m=m["white"], segs=8, rings=5),
        ]),
        # Red rescue tube slung across the back.
        "Acc_Lifeguard_Tube": bind("Spine", [
            box(p + "Tube", (0.16, 0.12, 0.78), (0.02, 0.25, 1.1), rot=rad(0, 32, 0), bevel=0.06, segs=3, m=red),
            box(p + "TubeText", (0.1, 0.13, 0.4), (0.02, 0.255, 1.1), rot=rad(0, 32, 0), bevel=0.02, m=m["white"]),
            tube(p + "TubeStrap", [(0.2, -0.17, 1.36), (0.16, 0.0, 1.42), (0.15, 0.2, 1.38)], 0.02, m=m["white"], segs=5),
        ]),
    }


def bruiser(m):
    """Boardwalk Bruiser: hulking, slow, takes a beating. Same rig, wider build."""
    p = "B_"
    vest, shorts, stripe = m["vest"], m["board"], m["board_stripe"]
    parts = head_parts(p, 0.66, m)
    parts += bind("Head", [
        box(p + "Headband", (0.68, 0.54, 0.08), (0, 0, 1.73), bevel=0.03, m=m["cap_trim"]),
        box(p + "BandKnot", (0.1, 0.1, 0.1), (0.0, 0.27, 1.72), bevel=0.03, m=m["cap_trim"]),
        box(p + "BandTailA", (0.06, 0.16, 0.05), (0.06, 0.34, 1.66), rot=rad(-30, 0, 20), bevel=0.015, m=m["cap_trim"]),
        box(p + "BandTailB", (0.06, 0.16, 0.05), (-0.06, 0.34, 1.64), rot=rad(-40, 0, -20), bevel=0.015, m=m["cap_trim"]),
        box(p + "Mohawk", (0.08, 0.36, 0.12), (0, -0.02, 1.86), bevel=0.035, m=m["hair"]),
    ])
    parts += bind("Spine", [
        box(p + "Torso", (0.84, 0.54, 0.6), (0, 0, 1.12), bevel=0.17, segs=4, m=m["skin"]),
        box(p + "Pecs", (0.7, 0.2, 0.2), (0, -0.22, 1.2), bevel=0.08, segs=3, m=m["skin_dark"]),
        box(p + "VestL", (0.22, 0.56, 0.58), (0.33, 0, 1.12), bevel=0.08, segs=3, m=vest),
        box(p + "VestR", (0.22, 0.56, 0.58), (-0.33, 0, 1.12), bevel=0.08, segs=3, m=vest),
        box(p + "VestBack", (0.84, 0.12, 0.56), (0, 0.23, 1.12), bevel=0.06, m=vest),
        text(p + "Label", "BEACH", 0.11, 0.02, (0, 0.3, 1.2), rot=(0, 0, math.pi), m=m["white"]),
        box(p + "Neck", (0.34, 0.3, 0.12), (0, 0, 1.41), bevel=0.05, m=m["skin"]),
        sphere(p + "Belly", 0.3, (0, -0.15, 0.98), scale=(1.15, 0.9, 0.8), m=m["skin"], segs=12, rings=8),
        sphere(p + "Navel", 0.025, (0, -0.42, 0.97), m=m["skin_dark"], segs=6, rings=4),
    ])
    parts += bind("Hips", [
        box(p + "Shorts", (0.74, 0.5, 0.32), (0, 0, 0.84), bevel=0.1, segs=3, m=shorts),
        box(p + "Waistband", (0.75, 0.51, 0.06), (0, 0, 0.965), bevel=0.02, m=stripe),
    ])
    for side in (1, -1):
        parts += limb_parts(p, side, m, arm_w=0.24, leg_w=0.24, sleeve=None, shorts=shorts, shoe=m["flipflop"],
                            band=m["cap_trim"], flipflop=True, arm_out=0.08, hand=0.07)
        s = "L" if side > 0 else "R"
        parts += bind(f"Thigh.{s}", [box(f"{p}Stripe{s}", (0.04, 0.1, 0.32), (side * 0.32, 0, 0.64), bevel=0.0, m=stripe)])
    return parts


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
        bucket=mat("Bucket", "#1fb8a6", rough=0.65),
        hair_red=mat("HairCurly", "#9b3b2a", rough=0.8),
        lens=mat("Lens", "#2a1f3d", rough=0.15, metal=0.3),
        lens_mirror=mat("LensMirror", "#ffb84a", rough=0.15, metal=0.6),
        camera=mat("Camera", "#26232f", rough=0.45),
        camera_lens=mat("CameraLens", "#5fd9ff", rough=0.15, emit=0.4),
        vest=mat("Vest", "#6b35b8", rough=0.6),
        board=mat("BoardShorts", "#14a3a0", rough=0.65),
        board_stripe=mat("BoardStripe", "#ffd93b", rough=0.6),
    )
    armature = build_armature()
    meshes = [
        skin("Outfit_Tourist", tourist(m), armature),
        skin("Outfit_Lifeguard", lifeguard(m), armature),
        skin("Outfit_Bruiser", bruiser(m), armature),
    ]
    for name, parts in list(tourist_accessories(m).items()) + list(lifeguard_accessories(m).items()):
        meshes.append(skin(name, parts, armature))
    zombie_anim.bake(armature, zombie_anim.boardwalk_clips, "zombie")
    save("zombie", [armature] + meshes, animations=True)


if __name__ == "__main__":
    build()
