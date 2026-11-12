"""Dune Spaceport zombies: the boardwalk rig (build_zombie.py) in spaceport outfits.

    Outfit_Cadet      Space Cadet: white-and-teal spacesuit, glass bubble helmet,
                      life-support pack. Bounds in long, low-gravity hops.
    Outfit_Mechanic   Ground-crew mechanic: tintable coveralls ("Shirt"), hi-vis vest,
                      ear defenders and a twin-tank jetpack.
    Outfit_Hazmat     Irradiated hazmat worker: bulky yellow suit, gas-mask hood with
                      glowing lenses, glowing canisters.

Accessories (Acc_<Outfit>_<Name>, rolled per zombie from EnemyData.accessory_slots):
    Acc_Cadet_Visor, Acc_Cadet_Antenna, Acc_Cadet_Flag
    Acc_Mechanic_Cap, Acc_Mechanic_Goggles, Acc_Mechanic_Wrench
    Acc_Hazmat_Tank, Acc_Hazmat_Geiger

Same bones and clips as build_zombie.py (Idle-loop, Walk-loop, Run-loop, Attack, Hit,
Die), plus three extra clips for the Dune behaviours:
    Bound-loop   the cadet's hopping gait (airborne between 20% and 80% of the cycle)
    Crouch       a deep squat with the arms swept back (leap / jetpack windup)
    Hover-loop   jetpack flight: legs dangling, arms out for balance

The character faces -Y in Blender (+Z in Godot). Materials named "Skin"/"SkinDark"
and "Shirt" are tinted per zombie by the game.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dune_kit import *  # noqa: F401,F403
from build_zombie import (FPS, arms, bind, build_armature, clip_attack, clip_die, clip_hit, clip_idle, clip_run,  # noqa: E402
                          clip_walk, head_parts, set_pose, skin)


def glass_mat(name, color, alpha=0.3, emit=0.15):
    """Transparent tinted glass (exported with alpha blending)."""
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = dmat(name, color, rough=0.05, emit=emit)
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Alpha"].default_value = alpha
    for attr, value in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
        if hasattr(m, attr):
            try:
                setattr(m, attr, value)
            except (TypeError, ValueError):
                pass
    return m


def suit_limbs(prefix, side, m, sleeve, glove, boot, arm_w=0.17, leg_w=0.19, cuff=None, sole=None, bulk=0.0, hand=0.0):
    """One suited arm and leg (gloves and boots, no bare skin)."""
    s = "L" if side > 0 else "R"
    ax, lx = side * 0.41, side * 0.16
    aw, lw = arm_w + bulk, leg_w + bulk
    upper = [box(f"{prefix}UpperArm{s}", (aw, aw + 0.02, 0.32), (side * 0.395, 0, 1.1), bevel=0.07, segs=3, m=sleeve),
             sphere(f"{prefix}Shoulder{s}", aw * 0.72, (side * 0.37, 0, 1.25), m=sleeve, segs=10, rings=7)]
    fore = [box(f"{prefix}ForeArm{s}", (aw - 0.01, aw + 0.01, 0.32), (side * 0.42, 0, 0.82), bevel=0.06, segs=3, m=sleeve),
            sphere(f"{prefix}Elbow{s}", aw * 0.66, (side * 0.41, 0, 0.98), m=sleeve, segs=10, rings=7)]
    hw = aw + 0.06 + hand
    fore += [box(f"{prefix}Glove{s}", (hw, 0.15 + hand, 0.2 + hand), (side * 0.43, -0.01, 0.6 - hand * 0.4), bevel=0.06, segs=3, m=glove),
             box(f"{prefix}Thumb{s}", (0.06, 0.065, 0.11), (side * 0.43 - side * (hw * 0.5 + 0.01), -0.04, 0.62), bevel=0.025, m=glove)]
    for i in range(3):
        fore.append(box(f"{prefix}Finger{s}{i}", (0.06 + hand * 0.3, 0.065, 0.12), (side * 0.43 + (i - 1) * (0.072 + hand * 0.3), -0.02, 0.47 - hand * 0.8),
                        rot=rad(-12, 0, 0), bevel=0.022, m=glove))
    if cuff:
        fore.append(box(f"{prefix}Cuff{s}", (aw + 0.05, aw + 0.07, 0.08), (side * 0.425, 0, 0.7), bevel=0.025, m=cuff))
    thigh = [box(f"{prefix}Thigh{s}", (lw + 0.08, lw + 0.1, 0.34), (lx, 0, 0.63), bevel=0.08, segs=3, m=sleeve)]
    shin = [box(f"{prefix}Shin{s}", (lw + 0.02, lw + 0.04, 0.34), (lx, 0, 0.35), bevel=0.07, segs=3, m=sleeve),
            sphere(f"{prefix}Knee{s}", lw * 0.66, (lx, -0.01, 0.47), m=cuff or sleeve, segs=10, rings=7),
            box(f"{prefix}Boot{s}", (lw + 0.1, 0.46, 0.26), (lx, -0.07, 0.14), bevel=0.08, segs=3, m=boot),
            box(f"{prefix}Sole{s}", (lw + 0.12, 0.48, 0.07), (lx, -0.07, 0.035), bevel=0.025, m=sole or m["dark"])]
    return bind(f"UpperArm.{s}", upper) + bind(f"ForeArm.{s}", fore) + bind(f"Thigh.{s}", thigh) + bind(f"Shin.{s}", shin)


# ---------------------------------------------------------------------------
# Space Cadet
# ---------------------------------------------------------------------------

def cadet(m):
    p = "C_"
    suit, teal, rust = m["suit"], m["teal"], m["rust"]
    parts = head_parts(p, 0.56, m)
    parts += bind("Head", [
        sphere(p + "Bubble", 0.46, (0, -0.03, 1.6), m=m["glass"], segs=20, rings=12),
        box(p + "Glint", (0.16, 0.03, 0.05), (-0.2, -0.43, 1.78), rot=rad(0, 32, 0), bevel=0.015, m=m["glint"]),
        box(p + "GlintB", (0.07, 0.03, 0.04), (-0.27, -0.4, 1.7), rot=rad(0, 32, 0), bevel=0.012, m=m["glint"]),
    ])
    parts += bind("Spine", [
        torus(p + "Collar", 0.33, 0.07, (0, -0.01, 1.33), m=rust, major_segs=20, minor_segs=8),
        box(p + "Torso", (0.64, 0.44, 0.56), (0, 0, 1.12), bevel=0.14, segs=4, m=suit),
        box(p + "ChestPanel", (0.34, 0.08, 0.22), (0, -0.22, 1.15), bevel=0.04, m=m["panel"]),
        box(p + "BtnA", (0.06, 0.04, 0.06), (-0.09, -0.27, 1.17), bevel=0.015, m=m["btn_red"]),
        box(p + "BtnB", (0.06, 0.04, 0.06), (0.0, -0.27, 1.17), bevel=0.015, m=m["btn_yellow"]),
        box(p + "BtnC", (0.06, 0.04, 0.06), (0.09, -0.27, 1.17), bevel=0.015, m=m["btn_teal"]),
        box(p + "Hose", (0.05, 0.05, 0.2), (0.13, -0.23, 1.25), rot=rad(0, 20, 0), bevel=0.02, m=m["dark"]),
        box(p + "Pack", (0.52, 0.3, 0.62), (0, 0.33, 1.12), bevel=0.1, segs=3, m=m["suit_shade"]),
        box(p + "PackStripe", (0.53, 0.31, 0.1), (0, 0.33, 1.3), bevel=0.03, m=teal),
        cyl(p + "TankL", 0.1, 0.56, (-0.17, 0.5, 1.1), segs=12, bevel=0.03, m=rust),
        cyl(p + "TankR", 0.1, 0.56, (0.17, 0.5, 1.1), segs=12, bevel=0.03, m=rust),
        box(p + "Shoulder", (0.7, 0.36, 0.12), (0, 0.0, 1.36), bevel=0.05, m=teal),
    ])
    parts += bind("Hips", [
        box(p + "Pants", (0.6, 0.44, 0.3), (0, 0, 0.84), bevel=0.09, segs=3, m=suit),
        box(p + "Belt", (0.62, 0.46, 0.09), (0, 0, 0.965), bevel=0.03, m=teal),
        box(p + "Buckle", (0.14, 0.04, 0.1), (0, -0.24, 0.965), bevel=0.02, m=rust),
    ])
    for side in (1, -1):
        parts += suit_limbs(p, side, m, suit, rust, m["boot_white"], cuff=teal, sole=rust)
    return parts


def cadet_accessories(m):
    p = "CA_"
    return {
        # Gold sun visor pulled half down inside the bubble.
        "Acc_Cadet_Visor": bind("Head", [
            sphere(p + "Visor", 0.44, (0, -0.04, 1.63), scale=(1.0, 1.0, 0.55), m=m["visor"], segs=18, rings=6),
        ]),
        "Acc_Cadet_Antenna": bind("Spine", [
            cyl(p + "Antenna", 0.018, 0.6, (0.2, 0.42, 1.65), segs=6, bevel=0.0, m=m["steel"]),
            sphere(p + "AntennaTip", 0.05, (0.2, 0.42, 1.97), m=m["btn_red"], segs=8, rings=5),
        ]),
        "Acc_Cadet_Flag": bind("UpperArm.L", [
            box(p + "Patch", (0.04, 0.16, 0.12), (0.49, -0.02, 1.15), bevel=0.012, m=m["btn_teal"]),
            star(p + "PatchStar", 0.05, 0.02, (0.51, -0.02, 1.15), rot=(0, 0, math.pi / 2), m=m["btn_yellow"]),
        ]),
    }


# ---------------------------------------------------------------------------
# Ground-crew mechanic
# ---------------------------------------------------------------------------

def mechanic(m):
    p = "M_"
    coverall, vest, silver = m["shirt"], m["hivis"], m["reflect"]
    parts = head_parts(p, 0.6, m)
    parts += bind("Head", [
        box(p + "Hair", (0.5, 0.12, 0.18), (0, 0.24, 1.52), bevel=0.05, m=m["hair"]),
        box(p + "EarBand", (0.66, 0.1, 0.07), (0, 0.0, 1.88), rot=rad(0, 0, 0), bevel=0.03, m=m["dark"]),
    ])
    for side in (-1, 1):
        parts += bind("Head", [
            cyl(f"{p}EarCup{side}", 0.14, 0.12, (side * 0.34, 0.0, 1.6), rot=(0, math.pi / 2, 0), segs=14, bevel=0.04, m=m["rust"]),
            box(f"{p}EarArm{side}", (0.05, 0.08, 0.26), (side * 0.33, 0.0, 1.76), bevel=0.02, m=m["dark"]),
        ])
    parts += bind("Spine", [
        box(p + "Torso", (0.68, 0.46, 0.56), (0, 0, 1.13), bevel=0.14, segs=4, m=coverall),
        box(p + "Belly", (0.6, 0.44, 0.22), (0, -0.02, 0.98), bevel=0.1, segs=3, m=coverall),
        box(p + "Neck", (0.26, 0.24, 0.12), (0, 0, 1.4), bevel=0.05, m=m["skin"]),
        box(p + "Vest", (0.72, 0.48, 0.42), (0, 0, 1.17), bevel=0.12, segs=3, m=vest),
        box(p + "VestStripe", (0.73, 0.49, 0.06), (0, 0, 1.08), bevel=0.02, m=silver),
        box(p + "VestStripeB", (0.73, 0.49, 0.06), (0, 0, 1.24), bevel=0.02, m=silver),
        box(p + "Collar", (0.5, 0.3, 0.1), (0, -0.04, 1.37), bevel=0.04, m=coverall),
        box(p + "Tag", (0.14, 0.03, 0.08), (0.14, -0.245, 1.3), bevel=0.01, m=m["white"]),
        # Jetpack: frame, twin tanks with nozzles, little fins.
        box(p + "JetFrame", (0.5, 0.12, 0.5), (0, 0.29, 1.15), bevel=0.04, m=m["dark"]),
        cyl(p + "JetTankL", 0.14, 0.62, (-0.15, 0.42, 1.18), segs=14, bevel=0.05, m=m["white"]),
        cyl(p + "JetTankR", 0.14, 0.62, (0.15, 0.42, 1.18), segs=14, bevel=0.05, m=m["white"]),
        cyl(p + "JetBandL", 0.145, 0.12, (-0.15, 0.42, 1.3), segs=14, bevel=0.02, m=m["rust"]),
        cyl(p + "JetBandR", 0.145, 0.12, (0.15, 0.42, 1.3), segs=14, bevel=0.02, m=m["rust"]),
        sphere(p + "JetCapL", 0.14, (-0.15, 0.42, 1.49), scale=(1, 1, 0.6), m=m["rust"], segs=12, rings=6),
        sphere(p + "JetCapR", 0.14, (0.15, 0.42, 1.49), scale=(1, 1, 0.6), m=m["rust"], segs=12, rings=6),
        cyl(p + "NozzleL", 0.07, 0.18, (-0.15, 0.42, 0.8), segs=10, bevel=0.0, m=m["steel"], radius_top=0.1),
        cyl(p + "NozzleR", 0.07, 0.18, (0.15, 0.42, 0.8), segs=10, bevel=0.0, m=m["steel"], radius_top=0.1),
        cyl(p + "BurnerL", 0.055, 0.03, (-0.15, 0.42, 0.7), segs=10, bevel=0.0, m=m["burner"]),
        cyl(p + "BurnerR", 0.055, 0.03, (0.15, 0.42, 0.7), segs=10, bevel=0.0, m=m["burner"]),
        box(p + "FinL", (0.04, 0.16, 0.22), (-0.3, 0.46, 0.98), bevel=0.015, m=m["rust"]),
        box(p + "FinR", (0.04, 0.16, 0.22), (0.3, 0.46, 0.98), bevel=0.015, m=m["rust"]),
        box(p + "StrapL", (0.08, 0.5, 0.06), (-0.2, 0.05, 1.36), bevel=0.02, m=m["dark"]),
        box(p + "StrapR", (0.08, 0.5, 0.06), (0.2, 0.05, 1.36), bevel=0.02, m=m["dark"]),
    ])
    parts += bind("Hips", [
        box(p + "Pants", (0.64, 0.45, 0.3), (0, 0, 0.84), bevel=0.09, segs=3, m=coverall),
        box(p + "Belt", (0.66, 0.47, 0.08), (0, 0, 0.96), bevel=0.02, m=m["dark"]),
        box(p + "Pouch", (0.18, 0.12, 0.16), (0.24, -0.24, 0.9), bevel=0.03, m=m["leather"]),
        box(p + "Rag", (0.1, 0.03, 0.2), (-0.26, -0.24, 0.85), rot=rad(0, 10, 0), bevel=0.012, m=m["rust"]),
    ])
    for side in (1, -1):
        parts += suit_limbs(p, side, m, coverall, m["dark"], m["leather"], arm_w=0.18, leg_w=0.2, cuff=vest, sole=m["dark"])
    return parts


def mechanic_accessories(m):
    p = "MA_"
    return {
        "Acc_Mechanic_Cap": bind("Head", [
            sphere(p + "Cap", 0.32, (0, 0.0, 1.77), scale=(1.0, 0.95, 0.6), m=m["rust"], segs=14, rings=8),
            box(p + "CapBrim", (0.36, 0.26, 0.045), (0, -0.36, 1.74), rot=rad(10, 0, 0), bevel=0.02, m=m["rust"]),
            box(p + "CapPatch", (0.18, 0.04, 0.1), (0, -0.27, 1.82), rot=rad(-18, 0, 0), bevel=0.015, m=m["white"]),
        ]),
        "Acc_Mechanic_Goggles": bind("Head", [
            box(p + "GoggleBand", (0.64, 0.5, 0.06), (0, 0.0, 1.8), bevel=0.02, m=m["dark"]),
            cyl(p + "GoggleL", 0.09, 0.08, (-0.12, -0.27, 1.82), rot=(math.pi / 2, 0, 0), segs=12, bevel=0.02, m=m["visor"]),
            cyl(p + "GoggleR", 0.09, 0.08, (0.12, -0.27, 1.82), rot=(math.pi / 2, 0, 0), segs=12, bevel=0.02, m=m["visor"]),
        ]),
        "Acc_Mechanic_Wrench": bind("ForeArm.R", [
            box(p + "WrenchShaft", (0.06, 0.05, 0.5), (-0.43, -0.12, 0.42), rot=rad(-20, 0, 0), bevel=0.015, m=m["steel"]),
            box(p + "WrenchJaw", (0.14, 0.06, 0.12), (-0.43, -0.2, 0.18), rot=rad(-20, 0, 0), bevel=0.02, m=m["steel"]),
        ]),
    }


# ---------------------------------------------------------------------------
# Hazmat
# ---------------------------------------------------------------------------

def hazmat(m):
    p = "H_"
    suit, shade, tape = m["hazmat"], m["hazmat_shade"], m["tape"]
    parts = bind("Head", [
        box(p + "Hood", (0.68, 0.62, 0.64), (0, 0.02, 1.6), bevel=0.24, segs=4, m=suit),
        box(p + "Mask", (0.5, 0.14, 0.4), (0, -0.27, 1.58), bevel=0.12, segs=3, m=m["rubber"]),
        cyl(p + "LensL", 0.11, 0.06, (-0.12, -0.35, 1.64), rot=(math.pi / 2, 0, 0), segs=16, bevel=0.02, m=m["lens"]),
        cyl(p + "LensR", 0.11, 0.06, (0.12, -0.35, 1.64), rot=(math.pi / 2, 0, 0), segs=16, bevel=0.02, m=m["lens"]),
        torus(p + "LensRimL", 0.11, 0.025, (-0.12, -0.35, 1.64), rot=(math.pi / 2, 0, 0), m=m["dark"], major_segs=14, minor_segs=5),
        torus(p + "LensRimR", 0.11, 0.025, (0.12, -0.35, 1.64), rot=(math.pi / 2, 0, 0), m=m["dark"], major_segs=14, minor_segs=5),
        cyl(p + "Filter", 0.11, 0.16, (0, -0.42, 1.45), rot=(math.radians(70), 0, 0), segs=14, bevel=0.03, m=m["filter"]),
        cyl(p + "FilterCap", 0.115, 0.04, (0, -0.49, 1.42), rot=(math.radians(70), 0, 0), segs=14, bevel=0.01, m=m["dark"]),
        cyl(p + "SideFilter", 0.08, 0.14, (0.3, -0.2, 1.48), rot=(0, math.radians(70), 0), segs=12, bevel=0.03, m=m["glow"]),
        box(p + "HoodSeam", (0.69, 0.04, 0.64), (0, 0.02, 1.6), bevel=0.02, m=tape),
    ])
    parts += bind("Spine", [
        box(p + "Torso", (0.78, 0.52, 0.6), (0, 0, 1.12), bevel=0.18, segs=4, m=suit),
        box(p + "Belly", (0.7, 0.5, 0.26), (0, -0.02, 0.96), bevel=0.12, segs=3, m=suit),
        box(p + "Zip", (0.06, 0.04, 0.5), (0, -0.265, 1.08), bevel=0.012, m=tape),
        box(p + "Badge", (0.2, 0.04, 0.2), (0.18, -0.27, 1.25), bevel=0.03, m=m["white"]),
        cyl(p + "BadgeDot", 0.035, 0.03, (0.18, -0.295, 1.25), rot=(math.pi / 2, 0, 0), segs=10, bevel=0.0, m=m["dark"]),
        box(p + "ChestTape", (0.8, 0.54, 0.06), (0, 0, 1.33), bevel=0.02, m=tape),
    ])
    for i in range(3):
        a = math.radians(90 + i * 120)
        parts += bind("Spine", [box(f"{p}Trefoil{i}", (0.06, 0.03, 0.06), (0.18 + math.cos(a) * 0.06, -0.3, 1.25 + math.sin(a) * 0.06),
                                    rot=(0, -a, 0), bevel=0.0, m=m["dark"])])
    parts += bind("Hips", [
        box(p + "Pants", (0.7, 0.5, 0.32), (0, 0, 0.83), bevel=0.1, segs=3, m=suit),
        box(p + "Belt", (0.72, 0.52, 0.08), (0, 0, 0.96), bevel=0.02, m=m["dark"]),
        cyl(p + "BeltCan", 0.08, 0.2, (-0.3, -0.18, 0.88), segs=12, bevel=0.03, m=m["glow"]),
    ])
    for side in (1, -1):
        parts += suit_limbs(p, side, m, suit, m["rubber"], m["rubber"], arm_w=0.19, leg_w=0.21, cuff=tape, sole=m["dark"], bulk=0.03)
        s = "L" if side > 0 else "R"
        parts += bind(f"Thigh.{s}", [box(f"{p}Knee{s}", (0.3, 0.06, 0.1), (side * 0.16, -0.17, 0.6), bevel=0.02, m=shade)])
    return parts


def hazmat_accessories(m):
    p = "HA_"
    return {
        "Acc_Hazmat_Tank": bind("Spine", [
            cyl(p + "Tank", 0.16, 0.64, (0, 0.36, 1.12), segs=14, bevel=0.06, m=m["white"]),
            cyl(p + "TankBand", 0.165, 0.1, (0, 0.36, 1.26), segs=14, bevel=0.02, m=m["glow"]),
            tube(p + "TankHose", [(0, 0.38, 1.46), (0.2, 0.25, 1.55), (0.28, -0.1, 1.5)], 0.03, m=m["rubber"], segs=6),
        ]),
        "Acc_Hazmat_Geiger": bind("ForeArm.L", [
            box(p + "Geiger", (0.16, 0.24, 0.14), (0.46, -0.16, 0.56), bevel=0.03, m=m["filter"]),
            box(p + "GeigerDial", (0.1, 0.03, 0.08), (0.46, -0.29, 0.58), bevel=0.01, m=m["glow"]),
            box(p + "GeigerWand", (0.04, 0.3, 0.04), (0.46, -0.36, 0.5), bevel=0.01, m=m["dark"]),
        ]),
    }


# ---------------------------------------------------------------------------
# Extra clips
# ---------------------------------------------------------------------------

def clip_bound():
    """Low-gravity hop: squash, push off, float with arms up, land."""
    def pose(spine, thigh, shin, upper, fore, spread, head=-6):
        p = {"Hips": (spine * 0.3, 0, 0), "Spine": (spine, 0, 0), "Head": (head, 0, 0),
             "Thigh.L": (thigh, 0, 0), "Thigh.R": (thigh + 6, 0, 0), "Shin.L": (shin, 0, 0), "Shin.R": (shin + 4, 0, 0)}
        p.update(arms(upper, fore, upper + 6, fore, spread=spread))
        return p
    return "Bound-loop", [
        (0, pose(26, -46, 70, -30, -30, 18), (0, 0, -0.22)),
        (5, pose(4, 6, 6, -110, -20, 30, -14), (0, -0.04, 0.04)),
        (10, pose(10, -24, 40, -130, -14, 38, -10), (0, -0.06, 0.06)),
        (16, pose(14, -36, 52, -70, -24, 20), (0, -0.03, 0.0)),
        (20, pose(26, -46, 70, -30, -30, 18), (0, 0, -0.22)),
    ]


def clip_crouch():
    p = {"Hips": (12, 0, 0), "Spine": (34, 0, 0), "Head": (-24, 0, 0),
         "Thigh.L": (-62, 0, 0), "Thigh.R": (-56, 0, 0), "Shin.L": (88, 0, 0), "Shin.R": (84, 0, 0)}
    p.update(arms(36, -20, 40, -20, spread=24))
    rest = {"Hips": (6, 0, 0), "Spine": (14, 0, 0), "Head": (-8, 0, 0)}
    rest.update(arms(-40, -20, -36, -20, spread=10))
    return "Crouch", [(0, rest, (0, 0, -0.02)), (6, p, (0, 0.04, -0.3)), (12, p, (0, 0.04, -0.32))]


def clip_hover():
    def pose(phase):
        s = math.sin(phase * math.tau)
        p = {"Hips": (4, 0, 3 * s), "Spine": (8, 0, -4 * s), "Head": (-12, 4 * s, 0),
             "Thigh.L": (-14 + 10 * s, 0, 0), "Thigh.R": (-6 - 10 * s, 0, 0), "Shin.L": (24 + 8 * s, 0, 0), "Shin.R": (30 - 8 * s, 0, 0)}
        p.update(arms(-30 + 6 * s, -40, -30 - 6 * s, -40, spread=62))
        return p, (0, 0, 0.02 * s)
    return "Hover-loop", [(round(i * 24 / 8), *pose(i / 8)) for i in range(9)]


def build_animations(armature):
    ad = armature.animation_data_create()
    for make in (clip_idle, clip_walk, clip_run, clip_attack, clip_hit, clip_die, clip_bound, clip_crouch, clip_hover):
        name, keys = make()
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
        white=dmat("Hull", rough=0.45),
        hair=mat("Hair", "#5a3424", rough=0.8),
        dark=dmat("ZDark", "#2b2530", rough=0.6),
        steel=dmat("Steel", rough=0.4, metal=0.5),
        suit=dmat("CadetSuit", "#f1ede4", rough=0.55),
        suit_shade=dmat("CadetPack", "#cfd6d8", rough=0.5),
        teal=dmat("Teal", rough=0.45),
        rust=dmat("Rust", rough=0.55),
        panel=dmat("CadetPanel", "#3a3f58", rough=0.4),
        btn_red=dglow("BtnRed", "#ff4a3a", 1.6),
        btn_yellow=dglow("BtnYellow", "#ffd23a", 1.6),
        btn_teal=dglow("BtnTeal", "#4af2e0", 1.6),
        boot_white=dmat("CadetBoot", "#dfe4e6", rough=0.5),
        glass=glass_mat("HelmetGlass", "#bff4ff", alpha=0.28),
        glint=dglow("HelmetGlint", "#ffffff", 1.4),
        visor=dmat("Visor", "#e8a92a", rough=0.15, metal=0.8),
        shirt=mat("Shirt", "#ff7a2a", rough=0.65),
        hivis=dmat("HiVis", "#d8ff3a", rough=0.6),
        reflect=dmat("Reflect", "#e8eef2", rough=0.25, metal=0.6),
        leather=dmat("Leather", "#5a3a28", rough=0.75),
        burner=dglow("Burner", "#ff9a3a", 2.0),
        hazmat=dmat("Hazmat", "#ffd21f", rough=0.45),
        hazmat_shade=dmat("HazmatShade", "#e0a812", rough=0.5),
        tape=dmat("Tape", "#b9c0c6", rough=0.35, metal=0.5),
        rubber=dmat("RubberBlack", "#26222a", rough=0.55),
        lens=dglow("MaskLens", "#b8ff4a", 2.2),
        filter=dmat("Filter", "#4a4f5a", rough=0.5),
        glow=dglow("RadGlow", "#9dff3a", 2.4),
    )
    armature = build_armature()
    meshes = [
        skin("Outfit_Cadet", cadet(m), armature),
        skin("Outfit_Mechanic", mechanic(m), armature),
        skin("Outfit_Hazmat", hazmat(m), armature),
    ]
    acc = {}
    acc.update(cadet_accessories(m))
    acc.update(mechanic_accessories(m))
    acc.update(hazmat_accessories(m))
    for name, parts in acc.items():
        meshes.append(skin(name, parts, armature))
    build_animations(armature)
    save("dune_zombies", [armature] + meshes, animations=True)


if __name__ == "__main__":
    build()
