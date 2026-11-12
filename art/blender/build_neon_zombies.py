"""Neon Rooftops zombies: three models on the shared zombie rig contract.

    neon_punk.glb      Outfit_Punk      Neon Punk (spray-tagger): studded jacket with
                                        neon piping, spray can, mohawk / spikes / beanie
    neon_courier.glb   Outfit_Courier   Hover Courier (leaper): high-vis jacket, visor
                                        helmet, delivery box, glowing hover boots
    neon_riot.glb      Outfit_Riot      Riot Bruiser: armour, visor helmet and a big
                                        riot shield (Acc_Riot_Shield, hidden by the game
                                        when the shield breaks)

Same rig as art/blender/build_zombie.py (bone names Hips, Spine, Head, UpperArm.L/R,
ForeArm.L/R, Thigh.L/R, Shin.L/R). The clips come from zombie_anim.py (punk_clips,
courier_clips, riot_clips): Idle, Walk, Run, Attack, Stagger, Hit_Head, the Die_*
variants and Emerge, plus the extras each behaviour plays: Spray (punk), Crouch and
Leap (courier).

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
import zombie_anim  # noqa: E402

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
    # Top edge at ~1.75 m once scaled: the visor stays visible as a headshot target.
    y = -0.62
    zc = 0.9
    parts = [
        box(p + "Panel", (0.86, 0.08, 1.16), (0.05, y, zc), bevel=0.06, segs=2, m=m["shield"]),
        box(p + "Window", (0.56, 0.09, 0.2), (0.05, y - 0.005, zc + 0.36), bevel=0.03, m=m["riot_visor"]),
        text(p + "Text", "RIOT", 0.2, 0.03, (0.05, y - 0.05, zc - 0.05), m=m["white"]),
        box(p + "Stripe", (0.7, 0.09, 0.06), (0.05, y - 0.006, zc - 0.25), bevel=0.01, m=m["stripe"]),
        box(p + "Handle", (0.1, 0.18, 0.1), (0.2, y + 0.12, zc), bevel=0.02, m=m["dark"]),
    ]
    # Glowing rim.
    for i, (sx, sz, lx, lz) in enumerate(((0.92, 0.05, 0.05, zc + 0.59), (0.92, 0.05, 0.05, zc - 0.59),
                                          (0.05, 1.2, -0.41, zc), (0.05, 1.2, 0.51, zc))):
        parts.append(box(f"{p}Rim{i}", (sx, 0.1, sz), (lx, y, lz), bevel=0.015, m=m["shield_glow"]))
    return {"Acc_Riot_Shield": bind("Spine", parts)}


# ---------------------------------------------------------------------------

def build_one(name, outfit, body, accessories, clips):
    scene = reset_scene()
    scene.render.fps = FPS
    m = materials()
    armature = build_armature()
    meshes = [skin("Outfit_" + outfit, body(m), armature)]
    for acc_name, parts in accessories(m).items():
        meshes.append(skin(acc_name, parts, armature))
    zombie_anim.bake(armature, clips, name)
    save(name, [armature] + meshes, animations=True)


def build():
    build_one("neon_punk", "Punk", punk, punk_accessories, zombie_anim.punk_clips)
    build_one("neon_courier", "Courier", courier, courier_accessories, zombie_anim.courier_clips)
    build_one("neon_riot", "Riot", riot, riot_shield, zombie_anim.riot_clips)


if __name__ == "__main__":
    build()
