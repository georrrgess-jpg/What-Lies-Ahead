"""Frostpeak Resort zombies: one rig (the same bones and clips as
build_zombie.py, which this script reuses), three outfits.

    Outfit_Skier    Ski Racer: skin-tight race suit, helmet with a glowing
                    visor, chunky ski boots, crossed skis on the back
    Outfit_Yeti     Yeti brute: a zombie in a shaggy blue yeti costume with
                    horns, fur mitts and a big zipper down the back
    Outfit_Frozen   Frozen Tourist: puffy jacket and bobble hat, encased in
                    translucent ice (the ice is the Acc_Frozen_Ice mesh, which
                    the game hides when the shell shatters)

Clips: the shared Idle-loop, Walk-loop, Run-loop, Attack, Hit, Die plus
    Tuck-loop   the Ski Racer's crouched downhill tuck (telegraph and rush)
    Throw       the Yeti's two-handed overhead snowball heave

Eyes glow (emissive) so the zombies read against the snow at night.
Materials named Skin / SkinDark / Shirt are tinted per zombie by the game.

    python art/blender/build_frost_zombies.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from frost_common import *  # noqa: F401,F403
import build_zombie as bz


def suit_limbs(prefix, m, suit, arm_w, leg_w, boot, hand=0.0, arm_out=0.0):
    """Arms and legs in one material (suits, costumes), with chunky boots."""
    limb_m = dict(m, skin=suit)
    parts = []
    for side in (1, -1):
        parts += bz.limb_parts(prefix, side, limb_m, arm_w=arm_w, leg_w=leg_w, sleeve=None, shorts=suit, shoe=boot,
                               sock=False, hand=hand, arm_out=arm_out)
    return parts


def recolour(parts, names, material):
    """Swap the material of the parts whose names end with any of `names`."""
    for ob in parts:
        if any(ob.name.endswith(n) for n in names):
            ob.data.materials.clear()
            ob.data.materials.append(material)


# ---------------------------------------------------------------------------
# Ski Racer
# ---------------------------------------------------------------------------

def skier(m):
    p = "S_"
    suit, panel, navy = m["shirt"], m["white"], m["navy"]
    parts = bz.head_parts(p, 0.54, m)
    parts += bz.bind("Head", [
        sphere(p + "Helmet", 0.31, (0, 0.04, 1.76), scale=(1.05, 1.05, 0.72), m=navy, segs=16, rings=9),
        box(p + "HelmetStripe", (0.1, 0.62, 0.08), (0, 0.02, 1.95), bevel=0.03, m=m["accent"]),
        box(p + "Visor", (0.6, 0.12, 0.16), (0, -0.25, 1.64), bevel=0.06, segs=3, m=m["visor"]),
        box(p + "VisorStrap", (0.64, 0.5, 0.07), (0, 0.04, 1.64), bevel=0.03, m=navy),
        box(p + "ChinGuard", (0.3, 0.12, 0.08), (0, -0.24, 1.3), bevel=0.03, m=navy),
    ])
    parts += bz.bind("Spine", [
        box(p + "Torso", (0.5, 0.36, 0.56), (0, 0, 1.13), bevel=0.12, segs=4, m=suit),
        box(p + "Waist", (0.46, 0.34, 0.2), (0, 0, 0.96), bevel=0.08, segs=3, m=suit),
        box(p + "PanelL", (0.12, 0.38, 0.5), (0.2, 0, 1.12), rot=rad(0, 18, 0), bevel=0.04, m=panel),
        box(p + "PanelR", (0.08, 0.38, 0.5), (-0.22, 0, 1.12), rot=rad(0, -18, 0), bevel=0.03, m=navy),
        box(p + "Collar", (0.3, 0.28, 0.12), (0, 0, 1.4), bevel=0.05, m=navy),
        box(p + "Bib", (0.36, 0.03, 0.34), (0, -0.19, 1.13), bevel=0.02, m=panel),
        box(p + "BibBack", (0.36, 0.03, 0.34), (0, 0.19, 1.13), bevel=0.02, m=panel),
        text(p + "BibNum", "07", 0.2, 0.02, (0, -0.205, 1.12), m=navy),
        text(p + "BibNumBack", "07", 0.2, 0.02, (0, 0.205, 1.12), rot=(0, 0, math.pi), m=navy),
    ])
    parts += bz.bind("Hips", [
        box(p + "Hips", (0.48, 0.36, 0.28), (0, 0, 0.84), bevel=0.08, segs=3, m=suit),
        box(p + "Belt", (0.5, 0.38, 0.06), (0, 0, 0.955), bevel=0.02, m=navy),
    ])
    limbs = suit_limbs(p, m, suit, 0.15, 0.17, m["boot"])
    parts += limbs
    for side, s in ((1, "L"), (-1, "R")):
        x = side * 0.16
        parts += bz.bind(f"Shin.{s}", [
            box(f"{p}BootCuff{s}", (0.26, 0.34, 0.34), (x, -0.02, 0.27), bevel=0.07, segs=3, m=m["boot"]),
            box(f"{p}BootBuckle{s}", (0.27, 0.06, 0.04), (x, -0.2, 0.3), bevel=0.01, m=navy),
        ])
        parts += bz.bind(f"ForeArm.{s}", [
            box(f"{p}Glove{s}", (0.21, 0.18, 0.24), (side * 0.43, -0.01, 0.58), bevel=0.07, segs=3, m=navy),
            box(f"{p}Cuff{s}", (0.2, 0.2, 0.08), (side * 0.43, 0, 0.71), bevel=0.03, m=m["accent"]),
        ])
        parts += bz.bind(f"Thigh.{s}", [box(f"{p}Stripe{s}", (0.03, 0.08, 0.3), (side * 0.275, 0, 0.64), bevel=0.0, m=panel)])
    return parts


def skier_accessories(m):
    p = "SA_"
    ski = m["ski"]
    return {
        "Acc_Skier_Skis": bz.bind("Spine", [
            box(p + "SkiA", (0.09, 0.04, 1.75), (0, 0.27, 1.05), rot=rad(0, 24, 0), bevel=0.015, m=ski),
            box(p + "SkiB", (0.09, 0.04, 1.75), (0, 0.3, 1.05), rot=rad(0, -24, 0), bevel=0.015, m=ski),
            box(p + "SkiTipA", (0.1, 0.12, 0.08), (-0.36, 0.22, 1.86), rot=rad(-40, 24, 0), bevel=0.02, m=ski),
            box(p + "SkiTipB", (0.1, 0.12, 0.08), (0.36, 0.25, 1.86), rot=rad(-40, -24, 0), bevel=0.02, m=ski),
            box(p + "SkiStrap", (0.5, 0.06, 0.06), (0, 0.24, 1.05), bevel=0.02, m=m["navy"]),
        ]),
        "Acc_Skier_Poles": bz.bind("Spine", [
            cyl(p + "PoleA", 0.022, 1.3, (0.12, 0.24, 1.05), rot=rad(14, 8, 0), segs=6, bevel=0.0, m=m["steel"]),
            cyl(p + "PoleB", 0.022, 1.3, (-0.12, 0.24, 1.05), rot=rad(14, -8, 0), segs=6, bevel=0.0, m=m["steel"]),
            cyl(p + "BasketA", 0.07, 0.02, (0.03, 0.08, 0.43), rot=rad(14, 8, 0), segs=8, bevel=0.0, m=m["navy"]),
            cyl(p + "BasketB", 0.07, 0.02, (-0.03, 0.08, 0.43), rot=rad(14, -8, 0), segs=8, bevel=0.0, m=m["navy"]),
        ]),
        "Acc_Skier_Medal": bz.bind("Spine", [
            cyl(p + "Medal", 0.07, 0.02, (0.0, -0.215, 1.31), rot=rad(90, 0, 0), segs=12, bevel=0.0, m=m["gold"]),
            tube(p + "Ribbon", [(-0.1, -0.15, 1.42), (0.0, -0.21, 1.33), (0.1, -0.15, 1.42)], 0.015, m=m["accent"], segs=5),
        ]),
    }


# ---------------------------------------------------------------------------
# Yeti costume brute
# ---------------------------------------------------------------------------

def fur_clumps(prefix, bone, centre, radii, count, m, seed, size=0.11):
    rng = random.Random(seed)
    out = []
    for i in range(count):
        a = rng.uniform(0, math.tau)
        z = rng.uniform(-1, 1)
        r = math.sqrt(1 - z * z)
        pos = (centre[0] + math.cos(a) * r * radii[0], centre[1] + math.sin(a) * r * radii[1], centre[2] + z * radii[2])
        out.append(sphere(f"{prefix}{i:02d}", size * rng.uniform(0.75, 1.25), pos, scale=(1, 1, 1.4), m=m, segs=7, rings=5))
    return bz.bind(bone, out)


def yeti(m):
    p = "Y_"
    fur, light, dark = m["fur"], m["fur_light"], m["fur_dark"]
    parts = bz.head_parts(p, 0.62, m)
    parts += bz.bind("Head", [
        sphere(p + "Hood", 0.43, (0, 0.2, 1.68), scale=(1.22, 0.95, 1.15), m=fur, segs=16, rings=10),
        torus(p + "HoodRim", 0.36, 0.1, (0, -0.16, 1.56), rot=rad(90, 0, 0), m=light, major_segs=20, minor_segs=7),
        tube(p + "HornL", [(-0.3, 0.05, 1.95), (-0.48, 0.0, 2.15), (-0.5, -0.08, 2.32)], 0.08, m=m["horn"], segs=8, radius_end=0.02),
        tube(p + "HornR", [(0.3, 0.05, 1.95), (0.48, 0.0, 2.15), (0.5, -0.08, 2.32)], 0.08, m=m["horn"], segs=8, radius_end=0.02),
        sphere(p + "EarL", 0.1, (-0.5, 0.15, 1.72), scale=(0.6, 1, 1.3), m=fur, segs=8, rings=5),
        sphere(p + "EarR", 0.1, (0.5, 0.15, 1.72), scale=(0.6, 1, 1.3), m=fur, segs=8, rings=5),
    ])
    parts += fur_clumps(p + "HoodFur", "Head", (0, 0.2, 1.72), (0.5, 0.38, 0.45), 12, fur, 3)
    parts += bz.bind("Spine", [
        box(p + "Torso", (0.96, 0.64, 0.66), (0, 0, 1.12), bevel=0.24, segs=4, m=fur),
        sphere(p + "Belly", 0.32, (0, -0.2, 1.0), scale=(1.15, 0.7, 1.1), m=light, segs=12, rings=8),
        box(p + "Neck", (0.42, 0.36, 0.14), (0, 0, 1.42), bevel=0.06, m=fur),
        box(p + "Zip", (0.05, 0.04, 0.6), (0, 0.33, 1.12), bevel=0.01, m=m["steel"]),
        box(p + "ZipPull", (0.06, 0.05, 0.12), (0, 0.35, 1.38), bevel=0.01, m=m["steel"]),
    ])
    parts += fur_clumps(p + "BodyFur", "Spine", (0, 0, 1.12), (0.5, 0.34, 0.34), 22, fur, 5, size=0.13)
    parts += fur_clumps(p + "ShoulderFur", "Spine", (0, 0, 1.36), (0.52, 0.28, 0.08), 8, dark, 6, size=0.14)
    parts += bz.bind("Hips", [box(p + "Hips", (0.86, 0.6, 0.34), (0, 0, 0.84), bevel=0.14, segs=3, m=fur)])
    parts += fur_clumps(p + "HipFur", "Hips", (0, 0, 0.8), (0.45, 0.32, 0.12), 12, dark, 7, size=0.12)
    limb_m = dict(m, white=m["claw"])
    for side in (1, -1):
        parts += bz.limb_parts(p, side, dict(limb_m, skin=fur), arm_w=0.26, leg_w=0.26, sleeve=None, shorts=fur, shoe=dark,
                               sock=False, arm_out=0.08, hand=0.08)
        s = "L" if side > 0 else "R"
        parts += fur_clumps(f"{p}ArmFur{s}", f"UpperArm.{s}", (side * 0.48, 0, 1.12), (0.12, 0.12, 0.12), 5, fur, 8 + side, size=0.1)
        parts += fur_clumps(f"{p}ThighFur{s}", f"Thigh.{s}", (side * 0.17, 0, 0.62), (0.15, 0.15, 0.1), 5, fur, 10 + side, size=0.1)
    return parts


def yeti_accessories(m):
    p = "YA_"
    return {
        "Acc_Yeti_Scarf": bz.bind("Spine", [
            torus(p + "Scarf", 0.3, 0.1, (0, 0, 1.43), m=m["red"], major_segs=18, minor_segs=7),
            box(p + "ScarfTail", (0.16, 0.06, 0.5), (0.2, -0.33, 1.2), rot=rad(8, 0, 12), bevel=0.03, m=m["red"]),
            box(p + "ScarfStripe", (0.17, 0.07, 0.06), (0.21, -0.34, 1.05), rot=rad(8, 0, 12), bevel=0.01, m=m["white"]),
        ]),
        "Acc_Yeti_Tag": bz.bind("Spine", [
            box(p + "Tag", (0.26, 0.03, 0.16), (0.24, -0.33, 1.3), rot=rad(0, 0, -10), bevel=0.02, m=m["white"]),
            text(p + "TagText", "STAFF", 0.06, 0.01, (0.24, -0.35, 1.3), rot=(0, 0, math.radians(-10)), m=m["navy"]),
        ]),
    }


# ---------------------------------------------------------------------------
# Frozen Tourist
# ---------------------------------------------------------------------------

def frozen(m):
    p = "F_"
    jacket, quilt, pants = m["shirt"], m["quilt"], m["pants"]
    parts = bz.head_parts(p, 0.62, m)
    parts += bz.bind("Head", [box(p + "HairBack", (0.52, 0.12, 0.2), (0, 0.24, 1.5), bevel=0.05, m=m["hair"])])
    parts += bz.bind("Spine", [
        box(p + "Jacket", (0.78, 0.54, 0.62), (0, 0, 1.12), bevel=0.2, segs=4, m=jacket),
        box(p + "Collar", (0.5, 0.42, 0.16), (0, 0, 1.42), bevel=0.07, m=jacket),
        box(p + "Zip", (0.04, 0.04, 0.56), (0, -0.28, 1.12), bevel=0.01, m=m["steel"]),
        torus(p + "Scarf", 0.27, 0.08, (0, 0, 1.44), m=m["scarf"], major_segs=18, minor_segs=6),
        box(p + "ScarfTail", (0.14, 0.05, 0.42), (-0.16, -0.3, 1.22), rot=rad(6, 0, -10), bevel=0.02, m=m["scarf"]),
    ])
    for i, z in enumerate((0.92, 1.1, 1.28)):
        parts += bz.bind("Spine", [box(f"{p}Quilt{i}", (0.8, 0.56, 0.05), (0, 0, z), bevel=0.02, m=quilt)])
    parts += bz.bind("Hips", [
        box(p + "Pants", (0.68, 0.48, 0.3), (0, 0, 0.84), bevel=0.1, segs=3, m=pants),
        box(p + "JacketHem", (0.8, 0.56, 0.1), (0, 0, 0.98), bevel=0.04, m=jacket),
    ])
    limbs = []
    for side in (1, -1):
        limbs += bz.limb_parts(p, side, dict(m, skin=jacket), arm_w=0.2, leg_w=0.22, sleeve=jacket, shorts=pants,
                               shoe=m["boot"], sock=False)
    recolour(limbs, ("ShinL", "ShinR", "KneeL", "KneeR", "AnkleL", "AnkleR"), pants)
    recolour(limbs, ("HandL", "HandR", "ThumbL", "ThumbR", "FingerL0", "FingerL1", "FingerL2", "FingerR0", "FingerR1", "FingerR2"), m["mitten"])
    parts += limbs
    for side, s in ((1, "L"), (-1, "R")):
        parts += bz.bind(f"Shin.{s}", [box(f"{p}BootFur{s}", (0.3, 0.34, 0.1), (side * 0.16, -0.02, 0.24), bevel=0.04, m=m["white"])])
    return parts


def crystal(name, size, loc, rot, m):
    """A sharp-edged ice block (no bevel: the facets catch the light)."""
    return box(name, size, loc, rot=rot, bevel=0.0, m=m)


def shard(name, radius, length, loc, rot, m):
    return cyl(name, radius, length, loc, rot=rot, segs=5, bevel=0.0, m=m, radius_top=0.01)


def frozen_accessories(m):
    p = "FA_"
    ice = m["ice"]
    acc = {
        "Acc_Frozen_Ice": (
            bz.bind("Spine", [
                crystal(p + "Torso", (0.98, 0.72, 0.78), (0.02, 0, 1.12), rad(4, -3, 6), ice),
                shard(p + "ShardA", 0.1, 0.55, (0.42, 0.12, 1.5), rad(-20, 35, 0), ice),
                shard(p + "ShardB", 0.08, 0.45, (-0.38, 0.18, 1.52), rad(-25, -40, 0), ice),
                shard(p + "ShardC", 0.09, 0.5, (0.1, 0.36, 1.45), rad(-55, 0, 0), ice),
            ])
            + bz.bind("Hips", [crystal(p + "Hips", (0.86, 0.66, 0.42), (0, 0.02, 0.82), rad(0, 4, -5), ice)])
            + bz.bind("Head", [
                crystal(p + "HeadPlate", (0.34, 0.62, 0.56), (0.27, 0.04, 1.62), rad(0, -12, 8), ice),
                shard(p + "HeadShard", 0.09, 0.45, (0.18, 0.08, 1.95), rad(0, -25, 0), ice),
            ])
            + bz.bind("Thigh.L", [crystal(p + "ThighL", (0.36, 0.4, 0.38), (0.17, 0, 0.6), rad(0, 0, 6), ice)])
            + bz.bind("Thigh.R", [crystal(p + "ThighR", (0.36, 0.4, 0.38), (-0.17, 0, 0.6), rad(0, 0, -4), ice)])
            + bz.bind("UpperArm.L", [crystal(p + "ArmL", (0.3, 0.32, 0.36), (0.42, 0, 1.12), rad(0, 8, 0), ice)])
        ),
        "Acc_Frozen_Beanie": bz.bind("Head", [
            sphere(p + "Beanie", 0.31, (0, 0.02, 1.76), scale=(1.0, 1.0, 0.8), m=m["beanie"], segs=14, rings=8),
            cyl(p + "BeanieCuff", 0.32, 0.1, (0, 0.02, 1.73), segs=16, bevel=0.03, m=m["white"]),
            sphere(p + "Pompom", 0.1, (0, 0.02, 2.04), m=m["white"], segs=8, rings=6),
        ]),
        "Acc_Frozen_Earmuffs": bz.bind("Head", [
            sphere(p + "MuffL", 0.1, (-0.33, 0.02, 1.58), scale=(0.7, 1, 1), m=m["beanie"], segs=10, rings=6),
            sphere(p + "MuffR", 0.1, (0.33, 0.02, 1.58), scale=(0.7, 1, 1), m=m["beanie"], segs=10, rings=6),
            tube(p + "MuffBand", [(-0.32, 0.02, 1.64), (-0.2, 0.02, 1.88), (0.2, 0.02, 1.88), (0.32, 0.02, 1.64)], 0.025, m=m["steel"], segs=5),
        ]),
        "Acc_Frozen_Camera": bz.bind("Spine", [
            box(p + "CamBody", (0.22, 0.09, 0.14), (0.08, -0.33, 1.06), bevel=0.025, m=m["camera"]),
            cyl(p + "CamLens", 0.045, 0.07, (0.1, -0.39, 1.05), rot=rad(90, 0, 0), segs=12, bevel=0.01, m=m["camera_lens"]),
        ]),
    }
    return acc


# ---------------------------------------------------------------------------
# Extra clips
# ---------------------------------------------------------------------------

def clip_tuck():
    """Downhill tuck: crouched, chest over the knees, fists forward; a slight bob."""
    def pose(phase):
        s = math.sin(phase * math.tau)
        p = {
            "Hips": (34, 0, 0), "Spine": (30 + 3 * s, 0, 0), "Head": (-48, 0, 0),
            "Thigh.L": (-62, 0, 0), "Thigh.R": (-62, 0, 0), "Shin.L": (86, 0, 0), "Shin.R": (86, 0, 0),
        }
        p.update(bz.arms(-62, -60, -62, -60, spread=6))
        return p, (0, -0.05, -0.3 + 0.015 * s)
    return "Tuck-loop", [(round(i * 12 / 4), *pose(i / 4)) for i in range(5)]


def clip_throw():
    """Two-handed overhead heave: rear back (frames 0-12), release at ~15, follow through."""
    legs = {"Thigh.L": (-18, 0, 0), "Thigh.R": (14, 0, 0), "Shin.L": (14, 0, 0), "Shin.R": (18, 0, 0)}

    def pose(spine, head, upper, fore, hips=4, spread=10):
        p = {"Hips": (hips, 0, 0), "Spine": (spine, 0, 0), "Head": (head, 0, 0)}
        p.update(legs)
        p.update(bz.arms(upper, fore, upper, fore, spread=spread))
        return p
    return "Throw", [
        (0, pose(12, -8, -40, -20), (0, 0, -0.02)),
        (7, pose(-14, -22, -165, -70, hips=-4, spread=-20), (0, 0.06, 0.02)),
        (12, pose(-20, -26, -175, -80, hips=-6, spread=-24), (0, 0.08, 0.03)),
        (15, pose(38, 6, -70, -6, hips=12, spread=8), (0, -0.14, -0.05)),
        (20, pose(30, 0, -40, -12, hips=9, spread=10), (0, -0.1, -0.04)),
        (28, pose(12, -8, -40, -20), (0, 0, -0.02)),
    ]


def build_animations(armature):
    ad = armature.animation_data_create()
    makers = (bz.clip_idle, bz.clip_walk, bz.clip_run, bz.clip_attack, bz.clip_hit, bz.clip_die, clip_tuck, clip_throw)
    for make in makers:
        name, keys = make()
        action = bpy.data.actions.new(name)
        ad.action = action
        for frame, pose, hips_loc in keys:
            bz.set_pose(armature, frame, pose, hips_loc)
        track = ad.nla_tracks.new()
        track.name = name
        track.strips.new(name, 0, action)
        ad.action = None
    for pb in armature.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)


def build():
    scene = reset_scene()
    scene.render.fps = bz.FPS
    m = dict(
        skin=mat("Skin", "#8fc7b0", rough=0.6),
        skin_dark=mat("SkinDark", "#5f9a86", rough=0.65),
        eye=mat("FrostEye", "#a8f6ff", rough=0.3, emit=3.2),
        pupil=mat("Pupil", "#1c2030", rough=0.4),
        mouth=mat("Mouth", "#2a1a30", rough=0.7),
        teeth=mat("Teeth", "#fff3d6", rough=0.4),
        white=mat("White", "#f6f6ff", rough=0.6),
        hair=mat("Hair", "#4a2c26", rough=0.8),
        shirt=mat("Shirt", "#e0218a", rough=0.45),
        navy=mat("FrostNavy", "#1c2250", rough=0.35),
        accent=mat("FrostAccent", "#ffd23f", rough=0.5),
        visor=mat("FrostVisor", "#ff5a2a", rough=0.15, emit=1.5),
        boot=mat("FrostBoot", "#f2f2ff", rough=0.35),
        ski=mat("FrostRaceSki", "#ff3f4f", rough=0.35),
        steel=mat("FrostZSteel", "#b8bccc", rough=0.3, metal=0.6),
        gold=mat("FrostGold", "#ffcf3f", rough=0.3, metal=0.6, emit=0.4),
        fur=mat("FrostFur", "#3a7be0", rough=0.85),
        fur_light=mat("FrostFurLight", "#8ec2ff", rough=0.85),
        fur_dark=mat("FrostFurDark", "#24508f", rough=0.9),
        horn=mat("FrostHorn", "#fff0d4", rough=0.5),
        claw=mat("FrostClaw", "#fff0d4", rough=0.5),
        red=mat("FrostScarfRed", "#e2343f", rough=0.7),
        quilt=mat("FrostQuilt", "#3b1f5e", rough=0.6),
        pants=mat("FrostPants", "#232a5c", rough=0.65),
        mitten=mat("FrostMitten", "#ffd23f", rough=0.7),
        scarf=mat("FrostScarf", "#3fd4c4", rough=0.7),
        beanie=mat("FrostBeanie", "#ff7a2a", rough=0.75),
        camera=mat("Camera", "#26232f", rough=0.45),
        camera_lens=mat("CameraLens", "#5fd9ff", rough=0.15, emit=0.4),
        ice=ice_mat(),
    )
    yeti_m = dict(m, eye=mat("FrostEyeAmber", "#ffb43a", rough=0.3, emit=1.8))
    armature = bz.build_armature()
    meshes = [
        bz.skin("Outfit_Skier", skier(m), armature),
        bz.skin("Outfit_Yeti", yeti(yeti_m), armature),
        bz.skin("Outfit_Frozen", frozen(m), armature),
    ]
    accessories = {}
    accessories.update(skier_accessories(m))
    accessories.update(yeti_accessories(m))
    accessories.update(frozen_accessories(m))
    for name, parts in accessories.items():
        meshes.append(bz.skin(name, parts, armature))
    build_animations(armature)
    save("frost_zombies", [armature] + meshes, animations=True)


if __name__ == "__main__":
    build()
