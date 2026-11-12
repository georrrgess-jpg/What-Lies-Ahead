"""Neon Rooftops zombies: three models on the shared zombie rig contract.

    neon_punk.glb      Outfit_Punk      Neon Punk (spray-tagger): studded jacket with
                                        neon piping, spray can, mohawk / spikes / beanie
    neon_courier.glb   Outfit_Courier   Hover Courier (leaper): high-vis jacket, visor
                                        helmet, delivery box, glowing hover boots
    neon_riot.glb      Outfit_Riot      Riot Bruiser: armour, visor helmet and a big
                                        riot shield (Acc_Riot_Shield, hidden by the game
                                        when the shield breaks)

Same rig as art/blender/build_zombie.py (bone names Hips, Spine, Head, UpperArm.L/R,
ForeArm.L/R, Thigh.L/R, Shin.L/R) and the clip names zombie.gd expects:
Idle-loop, Walk-loop, Run-loop, Attack, Hit, Die. Each model also carries extra clips
its behaviour plays: Spray (punk), Crouch and Leap (courier).

Materials named "Shirt", "Skin" and "SkinDark" are tinted per zombie by the game.
Eyes, piping, soles and visors are emissive so the zombies read against the night.
The character faces -Y in Blender (+Z in Godot).

    python art/blender/build_neon_zombies.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403

FPS = 24

BONES = [
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


# ---------------------------------------------------------------------------
# Rig plumbing (same approach as build_zombie.py)
# ---------------------------------------------------------------------------

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


def materials():
    return dict(
        skin=mat("Skin", "#86d69a", rough=0.6),
        skin_dark=mat("SkinDark", "#58a874", rough=0.65),
        eye=mat("EyeGlow", "#f2ff8a", rough=0.3, emit=3.2),
        pupil=mat("Pupil", "#1c1a2a", rough=0.4),
        mouth=mat("Mouth", "#24122a", rough=0.7),
        teeth=mat("Teeth", "#f4f0dc", rough=0.4),
        white=mat("White", "#eeeaf4", rough=0.6),
        dark=mat("Dark", "#17151f", rough=0.55),
        shirt=mat("Shirt", "#ff3fa4", rough=0.6),
        leather=mat("Leather", "#2a2340", rough=0.35, metal=0.2),
        denim=mat("Denim", "#25285a", rough=0.75),
        stud=mat("Stud", "#d8dcff", rough=0.25, metal=0.8),
        pipe_cyan=mat("PipingCyan", "#2ef2ff", rough=0.3, emit=3.0),
        pipe_pink=mat("PipingPink", "#ff2fae", rough=0.3, emit=3.0),
        pipe_lime=mat("PipingLime", "#b6ff3a", rough=0.3, emit=2.6),
        hair_pink=mat("HairPink", "#ff3aa8", rough=0.55, emit=0.8),
        hair_cyan=mat("HairCyan", "#36e8ff", rough=0.55, emit=0.8),
        hair_dark=mat("HairDark", "#2a1f38", rough=0.7),
        boot=mat("Boot", "#1b1824", rough=0.45),
        sole_glow=mat("SoleGlow", "#ff36b0", rough=0.3, emit=3.0),
        can=mat("SprayCan", "#d8dce8", rough=0.25, metal=0.7),
        can_band=mat("SprayBand", "#ff3fa4", rough=0.4, emit=1.5),
        reflect=mat("Reflective", "#f2f4ff", rough=0.2, emit=0.9),
        helmet=mat("Helmet", "#eef0f8", rough=0.3),
        visor=mat("VisorGlow", "#38f0ff", rough=0.1, emit=3.0),
        box=mat("DeliveryBox", "#ff3d7f", rough=0.5),
        box_logo=mat("DeliveryLogo", "#fff36a", rough=0.4, emit=2.4),
        legging=mat("Leggings", "#232042", rough=0.7),
        thruster=mat("ThrusterGlow", "#3af6ff", rough=0.2, emit=4.0),
        metal=mat("Metal", "#5a5e78", rough=0.3, metal=0.8),
        armor=mat("Armor", "#1f2c5c", rough=0.4, metal=0.3),
        armor_light=mat("ArmorLight", "#3f57a0", rough=0.4, metal=0.3),
        stripe=mat("HazardYellow", "#ffcc2e", rough=0.5, emit=0.6),
        riot_led=mat("RiotLed", "#ff4a2e", rough=0.3, emit=3.5),
        riot_visor=mat("RiotVisor", "#1a2a48", rough=0.05, metal=0.6),
        shield=mat("ShieldPanel", "#2a3f86", rough=0.25, metal=0.4),
        shield_glow=mat("ShieldGlow", "#3af0ff", rough=0.2, emit=3.2),
    )


# ---------------------------------------------------------------------------
# Shared body parts
# ---------------------------------------------------------------------------

def head_parts(prefix, width, m, brow=True, ears=True):
    w = width
    parts = [
        box(prefix + "Skull", (w, 0.52, 0.48), (0, 0, 1.6), bevel=0.17, segs=4, m=m["skin"]),
        box(prefix + "Jaw", (w * 0.86, 0.48, 0.24), (0, -0.015, 1.38), bevel=0.09, segs=3, m=m["skin"]),
        box(prefix + "Mouth", (w * 0.52, 0.08, 0.11), (0, -0.235, 1.38), bevel=0.03, m=m["mouth"]),
        sphere(prefix + "Nose", 0.045, (0, -0.27, 1.5), scale=(1.1, 0.8, 0.8), m=m["skin_dark"], segs=8, rings=5),
    ]
    for i, x in enumerate((-0.09, 0.0, 0.09)):
        parts.append(box(f"{prefix}Tooth{i}", (0.055, 0.04, 0.05), (x * (w / 0.6), -0.262, 1.415), bevel=0.012, m=m["teeth"]))
    for i, side in enumerate((-1, 1)):
        x = side * w * 0.235
        parts += [
            sphere(f"{prefix}Eye{i}", 0.1, (x, -0.215, 1.63), scale=(1.0, 0.6, 1.0), m=m["eye"], segs=12, rings=8),
            sphere(f"{prefix}Pupil{i}", 0.022, (x + side * 0.01, -0.28, 1.625), m=m["pupil"], segs=6, rings=4),
            sphere(f"{prefix}EyeBag{i}", 0.09, (x, -0.2, 1.555), scale=(1.1, 0.5, 0.45), m=m["skin_dark"], segs=8, rings=5),
        ]
        if brow:
            parts.append(box(f"{prefix}Brow{i}", (0.2, 0.07, 0.05), (x, -0.24, 1.76), rot=rad(0, side * -16, 0), bevel=0.02, m=m["skin_dark"]))
        if ears:
            parts.append(sphere(f"{prefix}Ear{i}", 0.075, (side * (w * 0.5 + 0.02), 0.02, 1.57), scale=(0.6, 1, 1.2), m=m["skin"], segs=8, rings=6))
    return bind("Head", parts)


def arm_parts(prefix, side, m, arm_w, sleeve=None, cuff=None, glove=None, arm_out=0.0, hand=0.0):
    s = "L" if side > 0 else "R"
    o = side * arm_out
    upper = [box(f"{prefix}UpperArm{s}", (arm_w, arm_w + 0.02, 0.3), (side * 0.395 + o, 0, 1.1), bevel=0.06, segs=3, m=sleeve or m["skin"]),
             sphere(f"{prefix}Shoulder{s}", arm_w * 0.68, (side * 0.37 + o, 0, 1.25), m=sleeve or m["skin"], segs=10, rings=7)]
    hw = arm_w + 0.05 + hand
    hand_m = glove or m["skin"]
    fore = [
        box(f"{prefix}ForeArm{s}", (arm_w - 0.01, arm_w + 0.01, 0.32), (side * 0.42 + o, 0, 0.82), bevel=0.055, segs=3, m=sleeve or m["skin"]),
        sphere(f"{prefix}Elbow{s}", arm_w * 0.64, (side * 0.41 + o, 0, 0.98), m=sleeve or m["skin"], segs=10, rings=7),
        box(f"{prefix}Hand{s}", (hw, 0.13 + hand, 0.19 + hand), (side * 0.43 + o, -0.01, 0.6 - hand * 0.4), bevel=0.055, segs=3, m=hand_m),
        box(f"{prefix}Thumb{s}", (0.05, 0.055, 0.1), (side * 0.43 + o - side * (hw * 0.5 + 0.01), -0.04, 0.62), bevel=0.02, m=m["skin"]),
    ]
    for i in range(3):
        fore.append(box(f"{prefix}Finger{s}{i}", (0.055 + hand * 0.3, 0.06 + hand * 0.3, 0.11 + hand * 0.3),
                        (side * 0.43 + o + (i - 1) * (0.068 + hand * 0.3), -0.02, 0.475 - hand * 0.8),
                        rot=rad(-12, 0, 0), bevel=0.02, m=m["skin"]))
    if cuff:
        fore.append(box(f"{prefix}Cuff{s}", (arm_w + 0.04, arm_w + 0.06, 0.07), (side * 0.425 + o, 0, 0.7), bevel=0.02, m=cuff))
    return bind(f"UpperArm.{s}", upper) + bind(f"ForeArm.{s}", fore)


def leg_parts(prefix, side, m, leg_w, trouser, boot, sole, knee=None, shin_m=None):
    s = "L" if side > 0 else "R"
    lx = side * 0.16
    thigh = [box(f"{prefix}Thigh{s}", (leg_w + 0.06, leg_w + 0.08, 0.34), (lx, 0, 0.62), bevel=0.07, segs=3, m=trouser)]
    shin = [
        box(f"{prefix}Shin{s}", (leg_w, leg_w + 0.02, 0.34), (lx, 0, 0.33), bevel=0.06, segs=3, m=shin_m or trouser),
        sphere(f"{prefix}Knee{s}", leg_w * 0.62, (lx, -0.01, 0.46), m=knee or trouser, segs=10, rings=7),
        box(f"{prefix}Boot{s}", (leg_w + 0.08, 0.44, 0.22), (lx, -0.07, 0.13), bevel=0.07, segs=3, m=boot),
        box(f"{prefix}BootTop{s}", (leg_w + 0.06, leg_w + 0.06, 0.12), (lx, 0, 0.26), bevel=0.04, m=boot),
        box(f"{prefix}Sole{s}", (leg_w + 0.1, 0.47, 0.06), (lx, -0.07, 0.03), bevel=0.02, m=sole),
    ]
    return bind(f"Thigh.{s}", thigh) + bind(f"Shin.{s}", shin)


# ---------------------------------------------------------------------------
# Neon Punk
# ---------------------------------------------------------------------------

def punk(m):
    p = "P_"
    parts = head_parts(p, 0.58, m)
    parts += bind("Head", [
        box(p + "EarRing", (0.03, 0.03, 0.06), (0.31, -0.02, 1.48), bevel=0.01, m=m["pipe_cyan"]),
        torus(p + "Hoop", 0.035, 0.01, (-0.31, -0.02, 1.47), rot=rad(0, 90, 0), m=m["stud"], major_segs=12, minor_segs=5),
    ])
    jacket = m["leather"]
    parts += bind("Spine", [
        box(p + "Tank", (0.5, 0.36, 0.5), (0, 0, 1.12), bevel=0.1, segs=3, m=m["shirt"]),
        box(p + "JacketL", (0.2, 0.42, 0.56), (0.2, 0, 1.13), bevel=0.08, segs=3, m=jacket),
        box(p + "JacketR", (0.2, 0.42, 0.56), (-0.2, 0, 1.13), bevel=0.08, segs=3, m=jacket),
        box(p + "JacketBack", (0.56, 0.12, 0.56), (0, 0.17, 1.13), bevel=0.06, m=jacket),
        box(p + "CollarL", (0.18, 0.1, 0.16), (0.16, -0.17, 1.38), rot=rad(0, 25, 0), bevel=0.03, m=jacket),
        box(p + "CollarR", (0.18, 0.1, 0.16), (-0.16, -0.17, 1.38), rot=rad(0, -25, 0), bevel=0.03, m=jacket),
        box(p + "Neck", (0.22, 0.2, 0.12), (0, 0, 1.4), bevel=0.05, m=m["skin"]),
        # Neon piping down the jacket fronts and across the back.
        box(p + "PipeL", (0.025, 0.02, 0.5), (0.105, -0.215, 1.13), bevel=0.0, m=m["pipe_cyan"]),
        box(p + "PipeR", (0.025, 0.02, 0.5), (-0.105, -0.215, 1.13), bevel=0.0, m=m["pipe_cyan"]),
        box(p + "PipeHem", (0.58, 0.44, 0.03), (0, 0, 0.86), bevel=0.0, m=m["pipe_pink"]),
        box(p + "PipeBack", (0.4, 0.02, 0.03), (0, 0.235, 1.3), bevel=0.0, m=m["pipe_pink"]),
        text(p + "BackTag", "VOID", 0.13, 0.02, (0, 0.24, 1.12), rot=(0, 0, math.pi), m=m["pipe_lime"]),
    ])
    rng = random.Random(5)
    studs = []
    for i in range(8):
        side = 1 if i % 2 else -1
        studs.append(sphere(f"{p}Stud{i}", 0.022, (side * rng.uniform(0.17, 0.28), -0.215, rng.uniform(0.95, 1.36)), m=m["stud"], segs=6, rings=4))
    parts += bind("Spine", studs)
    parts += bind("Hips", [
        box(p + "Jeans", (0.5, 0.38, 0.28), (0, 0, 0.84), bevel=0.08, segs=3, m=m["denim"]),
        box(p + "Belt", (0.52, 0.4, 0.06), (0, 0, 0.955), bevel=0.02, m=m["dark"]),
        box(p + "Buckle", (0.1, 0.03, 0.07), (0, -0.21, 0.955), bevel=0.012, m=m["pipe_pink"]),
        tube(p + "Chain", [(0.12, -0.2, 0.93), (0.2, -0.18, 0.82), (0.25, -0.05, 0.86)], 0.012, m=m["stud"], segs=5),
    ])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm_parts(p, side, m, 0.17, sleeve=jacket, cuff=m["pipe_cyan"], glove=m["dark"])
        parts += leg_parts(p, side, m, 0.17, m["denim"], m["boot"], m["sole_glow"])
        parts += bind(f"Thigh.{s}", [box(f"{p}Rip{s}", (0.1, 0.03, 0.08), (side * 0.17, -0.13, 0.6), bevel=0.02, m=m["skin"])])
    # Spray can in the right hand, nozzle forward.
    parts += bind("ForeArm.R", [
        cyl(p + "Can", 0.065, 0.26, (-0.43, -0.1, 0.56), rot=rad(0, 0, 0), segs=12, bevel=0.01, m=m["can"]),
        cyl(p + "CanBand", 0.068, 0.08, (-0.43, -0.1, 0.6), segs=12, bevel=0.005, m=m["can_band"]),
        cyl(p + "CanCap", 0.03, 0.05, (-0.43, -0.1, 0.71), segs=8, bevel=0.005, m=m["dark"]),
        box(p + "Nozzle", (0.03, 0.05, 0.03), (-0.43, -0.135, 0.73), bevel=0.005, m=m["pipe_pink"]),
    ])
    return parts


def punk_accessories(m):
    p = "PA_"
    spikes = []
    for i in range(7):
        y = -0.2 + i * 0.07
        h = 0.2 + 0.08 * math.sin(i / 6 * math.pi)
        spikes.append(cyl(f"{p}Mo{i}", 0.05, h, (0, y, 1.85 + h * 0.5 - 0.05), rot=rad(-15 + i * 5, 0, 0), segs=6, bevel=0.0,
                          m=m["hair_pink"], radius_top=0.008))
    acc = {"Acc_Punk_Mohawk": bind("Head", spikes + [
        box(p + "MoBase", (0.1, 0.46, 0.08), (0, 0, 1.84), bevel=0.03, m=m["hair_dark"])])}
    liberty = []
    for i in range(9):
        a = math.tau * i / 9
        x, y = math.cos(a) * 0.17, math.sin(a) * 0.15
        liberty.append(cyl(f"{p}Lib{i}", 0.045, 0.24, (x * 1.3, y * 1.3, 1.92), rot=(-y * 2.2, x * 2.2, 0),
                           segs=6, bevel=0.0, m=m["hair_cyan"], radius_top=0.006))
    acc["Acc_Punk_Spikes"] = bind("Head", liberty + [
        sphere(p + "LibCap", 0.27, (0, 0, 1.78), scale=(1.05, 1.0, 0.5), m=m["hair_dark"], segs=12, rings=6)])
    acc["Acc_Punk_Beanie"] = bind("Head", [
        sphere(p + "Beanie", 0.31, (0, 0.01, 1.79), scale=(1.02, 0.96, 0.75), m=m["shirt"], segs=14, rings=8),
        cyl(p + "BeanieBand", 0.3, 0.09, (0, 0.01, 1.76), segs=16, bevel=0.02, m=m["pipe_lime"]),
        sphere(p + "Pom", 0.07, (0, 0.02, 2.02), m=m["pipe_pink"], segs=8, rings=5),
    ])
    acc["Acc_Punk_Visor"] = bind("Head", [
        box(p + "VisorBar", (0.56, 0.05, 0.09), (0, -0.26, 1.645), bevel=0.02, m=m["visor"]),
        box(p + "VisorArmL", (0.03, 0.28, 0.03), (0.29, -0.1, 1.65), bevel=0.008, m=m["dark"]),
        box(p + "VisorArmR", (0.03, 0.28, 0.03), (-0.29, -0.1, 1.65), bevel=0.008, m=m["dark"]),
    ])
    acc["Acc_Punk_Chain"] = bind("Spine", [
        tube(p + "Necklace", [(-0.12, -0.17, 1.38), (-0.08, -0.22, 1.26), (0.0, -0.235, 1.22), (0.08, -0.22, 1.26), (0.12, -0.17, 1.38)],
             0.014, m=m["stud"], segs=5),
        box(p + "Padlock", (0.06, 0.03, 0.07), (0, -0.245, 1.18), bevel=0.01, m=m["pipe_cyan"]),
    ])
    return acc


# ---------------------------------------------------------------------------
# Hover Courier
# ---------------------------------------------------------------------------

def courier(m):
    p = "C_"
    parts = head_parts(p, 0.52, m, brow=False)
    parts += bind("Head", [
        sphere(p + "Helmet", 0.31, (0, 0.02, 1.74), scale=(1.0, 1.08, 0.78), m=m["helmet"], segs=16, rings=9),
        torus(p + "HelmetBand", 0.305, 0.025, (0, 0.02, 1.7), m=m["pipe_pink"], major_segs=24, minor_segs=5),
        box(p + "Visor", (0.5, 0.08, 0.1), (0, -0.25, 1.72), rot=rad(-8, 0, 0), bevel=0.03, m=m["visor"]),
        box(p + "EarCupL", (0.06, 0.16, 0.16), (0.29, 0.0, 1.6), bevel=0.03, m=m["dark"]),
        box(p + "EarCupR", (0.06, 0.16, 0.16), (-0.29, 0.0, 1.6), bevel=0.03, m=m["dark"]),
        box(p + "Mic", (0.02, 0.18, 0.02), (0.27, -0.12, 1.45), rot=rad(0, 0, -10), bevel=0.005, m=m["dark"]),
    ])
    jacket = m["shirt"]
    parts += bind("Spine", [
        box(p + "Jacket", (0.52, 0.38, 0.54), (0, 0, 1.13), bevel=0.11, segs=4, m=jacket),
        box(p + "Zip", (0.03, 0.02, 0.48), (0, -0.195, 1.13), bevel=0.0, m=m["dark"]),
        box(p + "StripeChest", (0.53, 0.39, 0.05), (0, 0, 1.2), bevel=0.01, m=m["reflect"]),
        box(p + "StripeWaist", (0.53, 0.39, 0.05), (0, 0, 0.98), bevel=0.01, m=m["reflect"]),
        box(p + "Neck", (0.2, 0.18, 0.12), (0, 0, 1.4), bevel=0.05, m=m["skin"]),
        box(p + "Collar", (0.32, 0.3, 0.08), (0, 0, 1.38), bevel=0.03, m=m["dark"]),
        box(p + "StrapL", (0.06, 0.4, 0.5), (0.15, -0.0, 1.15), bevel=0.02, m=m["dark"]),
        box(p + "StrapR", (0.06, 0.4, 0.5), (-0.15, -0.0, 1.15), bevel=0.02, m=m["dark"]),
    ])
    parts += bind("Hips", [
        box(p + "Shorts", (0.48, 0.36, 0.26), (0, 0, 0.85), bevel=0.08, segs=3, m=m["dark"]),
        box(p + "Pouch", (0.16, 0.08, 0.12), (0.12, -0.2, 0.9), bevel=0.03, m=m["box"]),
    ])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm_parts(p, side, m, 0.15, sleeve=jacket, cuff=m["reflect"], glove=m["dark"])
        parts += bind(f"UpperArm.{s}", [box(f"{p}ArmStripe{s}", (0.17, 0.19, 0.04), (side * 0.395, 0, 1.08), bevel=0.01, m=m["reflect"])])
        parts += leg_parts(p, side, m, 0.15, m["legging"], m["boot"], m["dark"], knee=m["box"])
        # Hover thrusters under the boots.
        lx = side * 0.16
        parts += bind(f"Shin.{s}", [
            cyl(f"{p}Thruster{s}", 0.11, 0.05, (lx, -0.05, 0.01), segs=14, bevel=0.01, m=m["thruster"]),
            torus(f"{p}ThrusterRing{s}", 0.15, 0.025, (lx, -0.05, 0.02), m=m["metal"], major_segs=16, minor_segs=5),
            box(f"{p}Fin{s}", (0.03, 0.18, 0.12), (lx + side * 0.12, 0.08, 0.16), bevel=0.01, m=m["shirt"]),
        ])
    return parts


def courier_accessories(m):
    p = "CA_"
    return {
        "Acc_Courier_Box": bind("Spine", [
            box(p + "Box", (0.5, 0.36, 0.48), (0, 0.38, 1.12), bevel=0.05, segs=2, m=m["box"]),
            box(p + "BoxLid", (0.52, 0.38, 0.05), (0, 0.38, 1.37), bevel=0.02, m=m["dark"]),
            text(p + "Logo", "BLINK", 0.12, 0.02, (0, 0.565, 1.13), rot=(0, 0, math.pi), m=m["box_logo"]),
            box(p + "LogoBar", (0.36, 0.02, 0.03), (0, 0.565, 1.04), bevel=0.0, m=m["box_logo"]),
        ]),
        "Acc_Courier_Antenna": bind("Spine", [
            cyl(p + "Whip", 0.01, 0.6, (0.2, 0.46, 1.65), rot=rad(-12, 0, 0), segs=5, bevel=0.0, m=m["dark"]),
            sphere(p + "Tip", 0.035, (0.2, 0.52, 1.95), m=m["thruster"], segs=8, rings=5),
        ]),
        "Acc_Courier_Scarf": bind("Spine", [
            torus(p + "Scarf", 0.15, 0.05, (0, 0.0, 1.36), m=m["pipe_pink"], major_segs=16, minor_segs=6),
            box(p + "ScarfTail", (0.1, 0.05, 0.3), (0.08, 0.17, 1.24), rot=rad(25, 10, 0), bevel=0.02, m=m["pipe_pink"]),
        ]),
        "Acc_Courier_Goggles": bind("Head", [
            box(p + "GoggleBand", (0.62, 0.5, 0.05), (0, 0.02, 1.86), bevel=0.02, m=m["dark"]),
            sphere(p + "GoggleL", 0.07, (-0.1, -0.24, 1.88), scale=(1.2, 0.6, 1.0), m=m["pipe_lime"], segs=10, rings=6),
            sphere(p + "GoggleR", 0.07, (0.1, -0.24, 1.88), scale=(1.2, 0.6, 1.0), m=m["pipe_lime"], segs=10, rings=6),
        ]),
    }


# ---------------------------------------------------------------------------
# Riot Bruiser
# ---------------------------------------------------------------------------

def riot(m):
    p = "R_"
    parts = head_parts(p, 0.62, m, brow=False, ears=False)
    parts += bind("Head", [
        sphere(p + "Helmet", 0.36, (0, 0.03, 1.72), scale=(1.0, 1.05, 0.85), m=m["armor"], segs=16, rings=9),
        box(p + "HelmetRidge", (0.08, 0.6, 0.06), (0, 0.02, 2.0), bevel=0.02, m=m["armor_light"]),
        box(p + "Visor", (0.6, 0.06, 0.34), (0, -0.29, 1.6), rot=rad(-6, 0, 0), bevel=0.04, m=m["riot_visor"]),
        box(p + "VisorGlint", (0.5, 0.065, 0.03), (0, -0.295, 1.7), rot=rad(-6, 0, 0), bevel=0.0, m=m["riot_led"]),
        box(p + "VisorHingeL", (0.05, 0.1, 0.1), (0.31, -0.2, 1.68), bevel=0.02, m=m["metal"]),
        box(p + "VisorHingeR", (0.05, 0.1, 0.1), (-0.31, -0.2, 1.68), bevel=0.02, m=m["metal"]),
        box(p + "NeckGuard", (0.62, 0.3, 0.12), (0, 0.18, 1.45), rot=rad(20, 0, 0), bevel=0.04, m=m["armor"]),
    ])
    parts += bind("Spine", [
        box(p + "Torso", (0.86, 0.54, 0.62), (0, 0, 1.12), bevel=0.16, segs=4, m=m["armor"]),
        box(p + "ChestPlate", (0.7, 0.14, 0.42), (0, -0.25, 1.17), bevel=0.07, segs=3, m=m["armor_light"]),
        box(p + "ChestLed", (0.4, 0.02, 0.04), (0, -0.325, 1.32), bevel=0.0, m=m["riot_led"]),
        box(p + "BackPlate", (0.7, 0.12, 0.5), (0, 0.25, 1.15), bevel=0.06, m=m["armor_light"]),
        text(p + "BackText", "SECURITY", 0.085, 0.015, (0, 0.315, 1.2), rot=(0, 0, math.pi), m=m["stripe"]),
        box(p + "Neck", (0.34, 0.3, 0.12), (0, 0, 1.41), bevel=0.05, m=m["skin"]),
        sphere(p + "PadL", 0.21, (0.43, 0, 1.3), scale=(1.1, 1.0, 0.7), m=m["armor_light"], segs=12, rings=7),
        sphere(p + "PadR", 0.21, (-0.43, 0, 1.3), scale=(1.1, 1.0, 0.7), m=m["armor_light"], segs=12, rings=7),
        box(p + "PadStripeL", (0.2, 0.36, 0.04), (0.46, 0, 1.37), bevel=0.01, m=m["stripe"]),
        box(p + "PadStripeR", (0.2, 0.36, 0.04), (-0.46, 0, 1.37), bevel=0.01, m=m["stripe"]),
    ])
    parts += bind("Hips", [
        box(p + "Pants", (0.74, 0.5, 0.32), (0, 0, 0.84), bevel=0.1, segs=3, m=m["armor"]),
        box(p + "Belt", (0.76, 0.52, 0.08), (0, 0, 0.97), bevel=0.02, m=m["dark"]),
        box(p + "PouchL", (0.16, 0.1, 0.14), (0.24, -0.27, 0.95), bevel=0.03, m=m["dark"]),
        box(p + "PouchR", (0.16, 0.1, 0.14), (-0.24, -0.27, 0.95), bevel=0.03, m=m["dark"]),
        box(p + "BeltLed", (0.1, 0.02, 0.04), (0, -0.27, 0.97), bevel=0.0, m=m["riot_led"]),
    ])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm_parts(p, side, m, 0.24, sleeve=m["armor"], cuff=m["stripe"], glove=m["dark"], arm_out=0.08, hand=0.07)
        parts += leg_parts(p, side, m, 0.24, m["armor"], m["boot"], m["dark"], knee=m["armor_light"], shin_m=m["armor_light"])
    # Baton in the right hand.
    parts += bind("ForeArm.R", [
        cyl(p + "Baton", 0.035, 0.62, (-0.51, -0.12, 0.62), rot=rad(70, 0, 0), segs=8, bevel=0.01, m=m["dark"]),
        cyl(p + "BatonTip", 0.04, 0.12, (-0.51, -0.4, 0.72), rot=rad(70, 0, 0), segs=8, bevel=0.01, m=m["riot_led"]),
    ])
    return parts


def riot_shield(m):
    """Big riot shield held in front of the chest (bound to the spine, so it
    always covers the front)."""
    p = "RS_"
    y = -0.62
    parts = [
        box(p + "Panel", (0.86, 0.08, 1.2), (0.05, y, 1.0), bevel=0.06, segs=2, m=m["shield"]),
        box(p + "Window", (0.56, 0.09, 0.22), (0.05, y - 0.005, 1.38), bevel=0.03, m=m["riot_visor"]),
        text(p + "Text", "RIOT", 0.2, 0.03, (0.05, y - 0.05, 0.95), m=m["white"]),
        box(p + "Stripe", (0.7, 0.09, 0.06), (0.05, y - 0.006, 0.75), bevel=0.01, m=m["stripe"]),
        box(p + "Handle", (0.1, 0.18, 0.1), (0.2, y + 0.12, 1.0), bevel=0.02, m=m["dark"]),
    ]
    # Glowing rim.
    for i, (sx, sz, lx, lz) in enumerate(((0.92, 0.05, 0.05, 1.61), (0.92, 0.05, 0.05, 0.39), (0.05, 1.24, -0.41, 1.0), (0.05, 1.24, 0.51, 1.0))):
        parts.append(box(f"{p}Rim{i}", (sx, 0.1, sz), (lx, y, lz), bevel=0.015, m=m["shield_glow"]))
    return {"Acc_Riot_Shield": bind("Spine", parts)}


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------

def set_pose(armature, frame, pose, hips_loc=(0, 0, 0)):
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
    return {
        "UpperArm.L": (left_upper, -spread, 0), "ForeArm.L": (left_fore, 0, 0),
        "UpperArm.R": (right_upper, spread, 0), "ForeArm.R": (right_fore, 0, 0),
    }


def loop(name, frames, steps, make):
    return name, [(round(i * frames / steps), *make(i / steps)) for i in range(steps + 1)]


# --- Neon Punk: swaggering shamble, can held low, tags you from range --------

def punk_clips():
    def walk(phase):
        s, c = math.sin(phase * math.tau), math.cos(phase * math.tau)
        p = {"Hips": (4, 6 * c, 8 * c), "Spine": (10, -5 * c, -12 * c), "Head": (-6, 10 * c, 6 * s),
             "Thigh.L": (-2 - 26 * c, 0, 0), "Thigh.R": (-2 + 26 * c, 0, 0),
             "Shin.L": (8 + 34 * max(0.0, s), 0, 0), "Shin.R": (8 + 34 * max(0.0, -s), 0, 0)}
        p.update(arms(-70 + 8 * c, -18 - 8 * s, -30 - 10 * c, -40 + 6 * s, spread=10))
        return p, (0, 0, -0.03 * abs(c))

    def run(phase):
        s, c = math.sin(phase * math.tau), math.cos(phase * math.tau)
        p = {"Hips": (12, 4 * c, 9 * c), "Spine": (22, 0, -12 * c), "Head": (-20, 5 * c, 0),
             "Thigh.L": (-8 - 42 * c, 0, 0), "Thigh.R": (-8 + 42 * c, 0, 0),
             "Shin.L": (20 + 60 * max(0.0, s), 0, 0), "Shin.R": (20 + 60 * max(0.0, -s), 0, 0)}
        p.update(arms(-60 - 25 * c, -30, -50 + 25 * c, -40, spread=14))
        return p, (0, 0, -0.04 * abs(c) + 0.02)

    def idle(phase):
        s = math.sin(phase * math.tau)
        p = {"Hips": (2, 3 * s, 4 * s), "Spine": (8, -3 * s, 5 * s), "Head": (-6, 9 * s, -5 * s),
             "Thigh.L": (-2, 0, 0), "Thigh.R": (-2, 0, 0), "Shin.L": (5, 0, 0), "Shin.R": (5, 0, 0)}
        p.update(arms(-24 + 4 * s, -24, -30 - 6 * s, -50, spread=12))
        return p, (0, 0, -0.01 + 0.006 * s)

    legs = {"Thigh.L": (-14, 0, 0), "Thigh.R": (12, 0, 0), "Shin.L": (12, 0, 0), "Shin.R": (16, 0, 0)}

    def pose(spine, head, lu, lf, ru, rf, hips=4, spread=12):
        p = {"Hips": (hips, 0, 0), "Spine": (spine, 0, 0), "Head": (head, 0, 0)}
        p.update(legs)
        p.update(arms(lu, lf, ru, rf, spread=spread))
        return p

    attack = ("Attack", [
        (0, pose(12, -6, -68, -16, -40, -30), (0, 0, -0.02)),
        (6, pose(-6, -18, -140, -24, -130, -30, hips=-2, spread=-40), (0, 0.03, 0.02)),
        (11, pose(-10, -22, -150, -28, -150, -28, hips=-4, spread=-46), (0, 0.05, 0.03)),
        (14, pose(42, 8, -40, -4, -36, -6, hips=12, spread=8), (0, -0.2, -0.06)),
        (18, pose(32, 2, -28, -10, -26, -12, hips=9, spread=10), (0, -0.16, -0.05)),
        (24, pose(12, -6, -68, -16, -40, -30), (0, 0, -0.02)),
    ])
    hit = ("Hit", [
        (0, pose(12, -6, -60, -20, -40, -30), (0, 0, -0.02)),
        (3, {**pose(-18, -18, -36, -18, -30, -26), "Spine": (-18, 0, 14)}, (0, 0.05, -0.02)),
        (9, pose(12, -6, -60, -20, -40, -30), (0, 0, -0.02)),
    ])
    # Shake the can (frames 0-19), then hold it out and spray (20-32).
    spray = []
    for f in range(0, 21, 2):
        k = math.sin(f * 1.4)
        p = pose(4, -10, -40, -30, -150 + 18 * k, -40 - 25 * k, hips=2, spread=6)
        p["Spine"] = (2, 0, 10)
        spray.append((f, p, (0, 0, -0.01)))
    for f in (24, 32):
        p = pose(10, -4, -50, -30, -92, -4, hips=4, spread=-4)
        p["Spine"] = (8, 0, 14)
        spray.append((f, p, (0, -0.02, -0.02)))
    return [loop("Idle-loop", 48, 8, idle), loop("Walk-loop", 30, 8, walk), loop("Run-loop", 16, 8, run),
            attack, hit, die_clip(), ("Spray", spray)]


# --- Hover Courier: athletic sprinter, crouch-and-leap -----------------------

def courier_clips():
    def run(phase):
        s, c = math.sin(phase * math.tau), math.cos(phase * math.tau)
        p = {"Hips": (16, 3 * c, 10 * c), "Spine": (24, 0, -14 * c), "Head": (-24, 4 * c, 0),
             "Thigh.L": (-10 - 48 * c, 0, 0), "Thigh.R": (-10 + 48 * c, 0, 0),
             "Shin.L": (24 + 70 * max(0.0, s), 0, 0), "Shin.R": (24 + 70 * max(0.0, -s), 0, 0)}
        # Arms pump (elbows bent), not the classic zombie reach.
        p.update(arms(-10 + 50 * c, -85, -10 - 50 * c, -85, spread=12))
        return p, (0, 0, -0.05 * abs(c) + 0.03)

    def walk(phase):
        s, c = math.sin(phase * math.tau), math.cos(phase * math.tau)
        p = {"Hips": (6, 4 * c, 6 * c), "Spine": (14, -3 * c, -8 * c), "Head": (-10, 6 * c, 4 * s),
             "Thigh.L": (-3 - 28 * c, 0, 0), "Thigh.R": (-3 + 28 * c, 0, 0),
             "Shin.L": (10 + 36 * max(0.0, s), 0, 0), "Shin.R": (10 + 36 * max(0.0, -s), 0, 0)}
        p.update(arms(-76 + 6 * c, -12 - 8 * s, -70 - 6 * c, -18 + 8 * s, spread=10))
        return p, (0, 0, -0.03 * abs(c))

    def idle(phase):
        s = math.sin(phase * math.tau * 2)
        p = {"Hips": (6, 0, 0), "Spine": (12, 0, 4 * s), "Head": (-10, 6 * s, 0),
             "Thigh.L": (-14, 0, 0), "Thigh.R": (-14, 0, 0), "Shin.L": (26, 0, 0), "Shin.R": (26, 0, 0)}
        p.update(arms(-30 + 6 * s, -40, -30 - 6 * s, -40, spread=14))
        return p, (0, 0, -0.05 + 0.025 * abs(s))

    legs = {"Thigh.L": (-16, 0, 0), "Thigh.R": (14, 0, 0), "Shin.L": (14, 0, 0), "Shin.R": (18, 0, 0)}

    def pose(spine, head, upper, fore, hips=6, spread=12):
        p = {"Hips": (hips, 0, 0), "Spine": (spine, 0, 0), "Head": (head, 0, 0)}
        p.update(legs)
        p.update(arms(upper, fore, upper, fore, spread=spread))
        return p

    attack = ("Attack", [
        (0, pose(16, -10, -70, -20), (0, 0, -0.02)),
        (5, pose(-6, -20, -140, -26, hips=-2, spread=-40), (0, 0.04, 0.02)),
        (9, pose(-10, -24, -150, -30, hips=-4, spread=-46), (0, 0.05, 0.03)),
        (12, pose(46, 8, -36, -2, hips=12, spread=8), (0, -0.22, -0.06)),
        (16, pose(36, 2, -24, -10, hips=9, spread=10), (0, -0.18, -0.05)),
        (22, pose(16, -10, -70, -20), (0, 0, -0.02)),
    ])
    hit = ("Hit", [
        (0, pose(16, -10, -60, -24), (0, 0, -0.02)),
        (3, {**pose(-18, -18, -30, -24), "Spine": (-18, 0, 14)}, (0, 0.05, -0.02)),
        (9, pose(16, -10, -60, -24), (0, 0, -0.02)),
    ])
    crouch_pose = {"Hips": (24, 0, 0), "Spine": (30, 0, 0), "Head": (-30, 0, 0),
                   "Thigh.L": (-78, 0, 0), "Thigh.R": (-70, 0, 0), "Shin.L": (118, 0, 0), "Shin.R": (112, 0, 0)}
    crouch_pose.update(arms(45, -20, 45, -20, spread=24))
    crouch = ("Crouch", [(0, {**crouch_pose, "Spine": (10, 0, 0)}, (0, 0, -0.1)), (6, crouch_pose, (0, 0.05, -0.32)),
                         (14, {**crouch_pose, "Head": (-36, 0, 0)}, (0, 0.06, -0.34))])
    leap_pose = {"Hips": (-10, 0, 0), "Spine": (6, 0, 0), "Head": (-14, 0, 0),
                 "Thigh.L": (-90, 0, 0), "Thigh.R": (-40, 0, 0), "Shin.L": (100, 0, 0), "Shin.R": (60, 0, 0)}
    leap_pose.update(arms(-150, -10, -150, -10, spread=-30))
    leap = ("Leap", [(0, {**leap_pose, "Thigh.R": (10, 0, 0), "Shin.R": (10, 0, 0)}, (0, 0, 0.05)), (6, leap_pose, (0, 0, 0.1)),
                     (16, {**leap_pose, "Spine": (20, 0, 0), "Thigh.L": (-60, 0, 0), "Thigh.R": (-60, 0, 0)}, (0, 0, 0.05))])
    return [loop("Idle-loop", 24, 8, idle), loop("Walk-loop", 28, 8, walk), loop("Run-loop", 14, 8, run),
            attack, hit, die_clip(), crouch, leap]


# --- Riot Bruiser: heavy stomp behind the shield, shield bash -----------------

def riot_clips():
    def shield_arm(extra=0):
        return {"UpperArm.L": (-58 + extra, 0, -38), "ForeArm.L": (-62, 0, -10)}

    def walk(phase):
        s, c = math.sin(phase * math.tau), math.cos(phase * math.tau)
        p = {"Hips": (4, 4 * c, 4 * c), "Spine": (10, -4 * c, -6 * c), "Head": (-6, 3 * c, 0),
             "Thigh.L": (-2 - 22 * c, 0, 0), "Thigh.R": (-2 + 22 * c, 0, 0),
             "Shin.L": (8 + 30 * max(0.0, s), 0, 0), "Shin.R": (8 + 30 * max(0.0, -s), 0, 0),
             "UpperArm.R": (-30 + 14 * c, 14, 0), "ForeArm.R": (-50, 0, 0)}
        p.update(shield_arm(4 * c))
        return p, (0, 0, -0.04 * abs(c))

    def run(phase):
        s, c = math.sin(phase * math.tau), math.cos(phase * math.tau)
        p = {"Hips": (14, 3 * c, 6 * c), "Spine": (22, 0, -8 * c), "Head": (-20, 3 * c, 0),
             "Thigh.L": (-8 - 38 * c, 0, 0), "Thigh.R": (-8 + 38 * c, 0, 0),
             "Shin.L": (20 + 55 * max(0.0, s), 0, 0), "Shin.R": (20 + 55 * max(0.0, -s), 0, 0),
             "UpperArm.R": (-20 + 30 * c, 16, 0), "ForeArm.R": (-60, 0, 0)}
        p.update(shield_arm(-10))
        return p, (0, 0, -0.05 * abs(c) + 0.01)

    def idle(phase):
        s = math.sin(phase * math.tau)
        p = {"Hips": (2, 0, 2 * s), "Spine": (8, 0, -2 * s), "Head": (-4, 5 * s, 0),
             "Thigh.L": (-4, 0, 0), "Thigh.R": (2, 0, 0), "Shin.L": (8, 0, 0), "Shin.R": (6, 0, 0),
             "UpperArm.R": (-20 + 3 * s, 16, 0), "ForeArm.R": (-40, 0, 0)}
        p.update(shield_arm(2 * s))
        return p, (0, 0, -0.015 + 0.008 * s)

    legs = {"Thigh.L": (-22, 0, 0), "Thigh.R": (16, 0, 0), "Shin.L": (16, 0, 0), "Shin.R": (18, 0, 0)}

    def pose(spine, head, right_upper, right_fore, hips=4, shield=0, twist=0):
        p = {"Hips": (hips, 0, twist * 0.5), "Spine": (spine, 0, twist), "Head": (head, 0, 0),
             "UpperArm.R": (right_upper, 16, 0), "ForeArm.R": (right_fore, 0, 0)}
        p.update(legs)
        p.update(shield_arm(shield))
        return p

    # Windup: baton raised high behind the shield, leaning back; strike: a
    # lunging shield bash with the baton coming down.
    attack = ("Attack", [
        (0, pose(10, -6, -30, -50), (0, 0, -0.02)),
        (7, pose(-10, -14, -160, -40, hips=-4, shield=10, twist=-6), (0, 0.06, 0.02)),
        (12, pose(-14, -18, -170, -36, hips=-6, shield=12, twist=-8), (0, 0.08, 0.03)),
        (15, pose(30, 6, -60, -10, hips=12, shield=-26, twist=6), (0, -0.26, -0.08)),
        (19, pose(24, 2, -44, -20, hips=9, shield=-18, twist=4), (0, -0.2, -0.06)),
        (26, pose(10, -6, -30, -50), (0, 0, -0.02)),
    ])
    hit = ("Hit", [
        (0, pose(10, -6, -30, -50), (0, 0, -0.02)),
        (3, pose(-12, -14, -20, -30, twist=12, shield=14), (0, 0.06, -0.02)),
        (10, pose(10, -6, -30, -50), (0, 0, -0.02)),
    ])
    return [loop("Idle-loop", 48, 8, idle), loop("Walk-loop", 36, 8, walk), loop("Run-loop", 18, 8, run),
            attack, hit, die_clip()]


def die_clip():
    """Topples onto its back, arms flung wide (as the boardwalk zombies)."""
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


def build_animations(armature, clips):
    ad = armature.animation_data_create()
    for name, keys in clips:
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

def build_one(name, outfit, body, accessories, clips):
    scene = reset_scene()
    scene.render.fps = FPS
    m = materials()
    armature = build_armature()
    meshes = [skin("Outfit_" + outfit, body(m), armature)]
    for acc_name, parts in accessories(m).items():
        meshes.append(skin(acc_name, parts, armature))
    build_animations(armature, clips())
    save(name, [armature] + meshes, animations=True)


def build():
    build_one("neon_punk", "Punk", punk, punk_accessories, punk_clips)
    build_one("neon_courier", "Courier", courier, courier_accessories, courier_clips)
    build_one("neon_riot", "Riot", riot, riot_shield, riot_clips)


if __name__ == "__main__":
    build()
