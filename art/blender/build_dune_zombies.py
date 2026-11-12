"""Dune Spaceport zombies: the shared zombie rig (build_zombie.py) in spaceport outfits.

    Outfit_Cadet      Space Cadet: white spacesuit with strong tintable accent panels
                      ("Shirt"), orange gloves and boots, glass bubble helmet,
                      life-support pack. Bounds in long, low-gravity hops.
    Outfit_Mechanic   Ground-crew mechanic: tintable coveralls ("Shirt"), hi-vis vest,
                      ear defenders and a twin-tank jetpack.
    Outfit_Hazmat     Irradiated hazmat worker: bulky tintable suit ("Shirt"), hood,
                      glowing canisters. Its gas masks are its faces.

Accessories (Acc_<Outfit>_<Name>, rolled per zombie from EnemyData.accessory_slots):
    Acc_Cadet_Visor, Acc_Cadet_Antenna, Acc_Cadet_Flag, Acc_Cadet_Pennant
    Acc_Mechanic_Cap, Acc_Mechanic_Goggles, Acc_Mechanic_Wrench, Acc_Mechanic_Rag
    Acc_Hazmat_Tank, Acc_Hazmat_Geiger, Acc_Hazmat_Sign, Acc_Hazmat_Barrel
Faces: Face_<Outfit>_<Preset> (zombie_kit.py; the Hazmat's are gas masks), one
shown per zombie.

Same bones as build_zombie.py; the clips come from zombie_anim.dune_clips (the
Mechanic's march and wrench chop, the Hazmat trudge and shove, the shared set),
plus three extra clips for the Dune behaviours:
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
from build_zombie import FPS, bind, build_armature, save_zombie, skin  # noqa: E402
import zombie_anim  # noqa: E402
from zombie_kit import (HEAD_Y, head_band, arm, band, base_materials, blob, faces, glass, hair, head, hips, leg, neck,  # noqa: E402
                        patch, skull, tear_fn, torso)


def materials():
    m = base_materials("dune")
    m.update(
        suit=dmat("CadetSuit", "#f1ede4", rough=0.55),
        shirt=mat("Shirt", "#ff5a2a", rough=0.55),
        rust=dmat("Rust", "#e8622a", rough=0.5),
        glow=dglow("CadetGlow", "#ffd23a", 1.8),
        glass=glass("HelmetGlass", "#bff4ff", alpha=0.22),
        visor=glass("VisorGold", "#ffb02e", alpha=0.55, emit=0.6, rough=0.15),
        hivis=dmat("HiVis", "#d8ff3a", rough=0.6),
        burner=dglow("Burner", "#ff9a3a", 2.0),
        glow_rad=dglow("RadGlow", "#9dff3a", 2.4),
        lens=dglow("MaskLens", "#b8ff4a", 2.2),
        filter=dmat("Filter", "#4a4f5a", rough=0.5),
        steel=dmat("Steel", rough=0.4, metal=0.5),
    )
    return m


# ---------------------------------------------------------------------------
# Space Cadet
# ---------------------------------------------------------------------------

def cadet(m):
    """White suit, tintable accent panels ("Shirt"), orange gloves and boots,
    bubble helmet, life-support pack. Eight materials."""
    p = "C_"
    w = 0.56
    suit, acc, rust, dark, glow = m["suit"], m["shirt"], m["rust"], m["dark"], m["glow"]
    parts = head(p, m, w)
    parts += bind("Head", [
        sphere(p + "Bubble", 0.47, (0, HEAD_Y - 0.02, 1.62), m=m["glass"], segs=24, rings=14),
        box(p + "Glint", (0.16, 0.03, 0.05), (-0.2, HEAD_Y - 0.44, 1.8), rot=rad(0, 32, 0), bevel=0.015, m=glow),
    ])
    tor, body = torso(p, suit, w=0.66, d=0.46, z0=0.9, belly=0.04, hunch=0.04)
    parts += tor
    parts += neck(p, suit, 0.26)
    t = tor[0]
    parts += bind("Spine", [
        torus(p + "Collar", 0.34, 0.075, (0, -0.01, 1.34), m=acc, major_segs=24, minor_segs=8),
        body.shell(p + "ChestPanel", acc, 1.36, 1.0, off=0.02, gap=220, gap_at=180, segs=28, steps=4, lip=0.015),
        patch(p + "Console", t, (0, body.front(0, 1.16, off=0.02), 1.16), (0.3, 0.07, 0.18), dark, bevel=0.035),
        box(p + "BtnA", (0.06, 0.04, 0.06), (-0.08, body.front(-0.08, 1.16, off=0.02) - 0.04, 1.17), bevel=0.015, m=glow),
        box(p + "BtnB", (0.06, 0.04, 0.06), (0.02, body.front(0.02, 1.16, off=0.02) - 0.04, 1.17), bevel=0.015, m=acc),
        box(p + "BtnC", (0.06, 0.04, 0.06), (0.11, body.front(0.11, 1.16, off=0.02) - 0.04, 1.14), bevel=0.015, m=glow),
        tube(p + "Hose", [(0.14, body.front(0.14, 1.22, off=0.02) - 0.02, 1.22), (0.22, body.front(0.22, 1.3) - 0.03, 1.33),
                          (0.24, -0.1, 1.38)], 0.028, m=dark, segs=6),
        # Life-support pack with a stripe and twin tanks.
        box(p + "Pack", (0.54, 0.3, 0.64), (0, 0.36, 1.12), bevel=0.1, segs=3, m=suit),
        box(p + "PackStripe", (0.55, 0.31, 0.1), (0, 0.36, 1.3), bevel=0.03, m=acc),
        cyl(p + "TankL", 0.1, 0.56, (-0.17, 0.53, 1.1), segs=14, bevel=0.03, m=rust),
        cyl(p + "TankR", 0.1, 0.56, (0.17, 0.53, 1.1), segs=14, bevel=0.03, m=rust),
        box(p + "PackLight", (0.08, 0.04, 0.05), (0, 0.52, 1.42), bevel=0.012, m=glow),
    ])
    parts += hips(p, suit, w=0.62, d=0.46, belt=acc, buckle=rust)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        lx = side * 0.16
        parts += arm(p, side, m, w=0.18, sleeve=suit, sleeve_len="long", cuff=acc, glove=rust, pad=acc, seed=21)
        parts += leg(p, side, m, w=0.2, pants=suit, pants_len="long", foot="boot", shoe=rust, sole=dark, lace=acc, knee_m=acc, boot_h=0.2, tear=0)
        parts += bind(f"Thigh.{s}", [box(f"{p}ThighPocket{s}", (0.05, 0.15, 0.14), (side * 0.27, 0, 0.64), bevel=0.02, m=acc)])
    return parts


def cadet_accessories(m):
    p = "CA_"
    acc = {
        # A thin gold sun-visor band inside the bubble, above the eyes.
        "Acc_Cadet_Visor": bind("Head", [
            skull(0.56).shell(p + "Visor", m["visor"], 1.84, 1.76, off=0.1, gap=200, gap_at=180, segs=28, steps=1, lip=0.0),
        ]),
        "Acc_Cadet_Antenna": bind("Spine", [
            cyl(p + "Antenna", 0.018, 0.6, (0.2, 0.46, 1.65), segs=6, bevel=0.0, m=m["steel"]),
            sphere(p + "AntennaTip", 0.05, (0.2, 0.46, 1.97), m=m["glow"], segs=8, rings=5),
        ]),
        "Acc_Cadet_Flag": bind("UpperArm.L", [
            box(p + "Patch", (0.04, 0.16, 0.12), (0.5, -0.02, 1.15), bevel=0.012, m=m["shirt"]),
            star(p + "PatchStar", 0.05, 0.02, (0.525, -0.02, 1.15), rot=(0, 0, math.pi / 2), m=m["glow"]),
        ]),
        "Acc_Cadet_Pennant": bind("Spine", [
            cyl(p + "Pole", 0.012, 0.7, (-0.2, 0.5, 1.7), segs=6, bevel=0.0, m=m["steel"]),
            box(p + "Flag", (0.02, 0.26, 0.16), (-0.2, 0.63, 1.95), bevel=0.01, m=m["shirt"]),
            star(p + "FlagStar", 0.045, 0.024, (-0.21, 0.63, 1.95), rot=(0, 0, math.pi / 2), m=m["glow"]),
        ]),
    }
    acc.update(faces("Cadet", m, 0.56, ("Grin", "Gape", "Derp", "Sleepy")))
    return acc


# ---------------------------------------------------------------------------
# Ground-crew mechanic
# ---------------------------------------------------------------------------

def mechanic(m):
    """Tintable coveralls, hi-vis vest with silver bands, ear defenders, a
    twin-tank jetpack (nozzles where dune_jetpack_hop.gd expects them). Eight
    materials."""
    p = "M_"
    w = 0.6
    coverall, vest, white, dark, rust = m["shirt"], m["hivis"], m["white"], m["dark"], m["rust"]
    parts = head(p, m, w, ears=False)
    parts += hair(p, w, dark, "fringe", 14)
    parts += bind("Head", [band(p + "EarBand", (0, HEAD_Y, 1.93), (0, HEAD_Y, 1.87), w * 0.53 + 0.02, 0.2, dark, n=2.6, thick=0.02, segs=22)])
    for side in (-1, 1):
        parts += bind("Head", [
            cyl(f"{p}EarCup{side}", 0.14, 0.12, (side * (w * 0.5 + 0.05), HEAD_Y, 1.6), rot=(0, math.pi / 2, 0), segs=16, bevel=0.04, m=rust),
            box(f"{p}EarArm{side}", (0.05, 0.08, 0.28), (side * (w * 0.5 + 0.04), HEAD_Y, 1.78), bevel=0.02, m=dark),
        ])
    tor, body = torso(p, coverall, w=0.7, d=0.47, z0=0.9, belly=0.05, hunch=0.05)
    parts += tor
    parts += neck(p, m["skin"], 0.26)
    hv = body.shell(p + "Vest", vest, 1.38, 0.98, off=0.026, gap=40, segs=24, steps=4, tear=tear_fn(24, 14, 1, 0.03))
    parts += bind("Spine", [
        hv,
        body.shell(p + "VestStripeA", white, 1.11, 1.06, off=0.04, gap=40, segs=24, steps=1, lip=0.012),
        body.shell(p + "VestStripeB", white, 1.27, 1.22, off=0.04, gap=40, segs=24, steps=1, lip=0.012),
        band(p + "Collar", (0, -0.02, 1.46), (0, -0.02, 1.37), 0.2, 0.18, coverall, n=2.6, thick=0.025, flare=0.03, segs=20),
        patch(p + "Tag", tor[0], (0.15, body.front(0.15, 1.3), 1.3), (0.12, 0.04, 0.07), white, bevel=0.01),
        # Jetpack: frame, twin tanks with nozzles, little fins.
        box(p + "JetFrame", (0.5, 0.12, 0.5), (0, 0.31, 1.15), bevel=0.04, m=dark),
        cyl(p + "JetTankL", 0.14, 0.62, (-0.15, 0.44, 1.18), segs=16, bevel=0.05, m=white),
        cyl(p + "JetTankR", 0.14, 0.62, (0.15, 0.44, 1.18), segs=16, bevel=0.05, m=white),
        cyl(p + "JetBandL", 0.145, 0.12, (-0.15, 0.44, 1.3), segs=16, bevel=0.02, m=rust),
        cyl(p + "JetBandR", 0.145, 0.12, (0.15, 0.44, 1.3), segs=16, bevel=0.02, m=rust),
        sphere(p + "JetCapL", 0.14, (-0.15, 0.44, 1.49), scale=(1, 1, 0.6), m=rust, segs=14, rings=6),
        sphere(p + "JetCapR", 0.14, (0.15, 0.44, 1.49), scale=(1, 1, 0.6), m=rust, segs=14, rings=6),
        cyl(p + "NozzleL", 0.07, 0.18, (-0.15, 0.42, 0.8), segs=12, bevel=0.0, m=dark, radius_top=0.1),
        cyl(p + "NozzleR", 0.07, 0.18, (0.15, 0.42, 0.8), segs=12, bevel=0.0, m=dark, radius_top=0.1),
        cyl(p + "BurnerL", 0.055, 0.03, (-0.15, 0.42, 0.7), segs=12, bevel=0.0, m=m["burner"]),
        cyl(p + "BurnerR", 0.055, 0.03, (0.15, 0.42, 0.7), segs=12, bevel=0.0, m=m["burner"]),
        box(p + "FinL", (0.04, 0.16, 0.22), (-0.3, 0.48, 0.98), bevel=0.015, m=rust),
        box(p + "FinR", (0.04, 0.16, 0.22), (0.3, 0.48, 0.98), bevel=0.015, m=rust),
    ] + [tube(f"{p}Strap{side}", [(side * 0.2, 0.27, 1.38), (side * 0.2, 0.05, 1.46), (side * 0.2, body.front(side * 0.2, 1.38, off=0.04), 1.38),
                                  (side * 0.2, body.front(side * 0.2, 1.12, off=0.04), 1.12)], 0.025, m=dark, segs=6) for side in (1, -1)])
    parts += hips(p, coverall, w=0.66, d=0.47, belt=dark, buckle=white)
    parts += bind("Hips", [
        box(p + "Pouch", (0.18, 0.12, 0.16), (0.25, -0.25, 0.9), bevel=0.03, m=dark),
        box(p + "Rag", (0.1, 0.03, 0.22), (-0.27, -0.25, 0.85), rot=rad(0, 10, 0), bevel=0.012, m=rust),
    ])
    for side in (1, -1):
        parts += arm(p, side, m, w=0.18, sleeve=coverall, sleeve_len="long", cuff=vest, glove=dark, seed=23, sleeve_tear=1)
        parts += leg(p, side, m, w=0.2, pants=coverall, pants_len="long", foot="boot", shoe=dark, sole=dark, lace=rust, boot_h=0.16, tear=1,
                     seed=24)
    return parts


def mechanic_accessories(m):
    p = "MA_"
    w = 0.6
    acc = {
        "Acc_Mechanic_Cap": bind("Head", [
            sphere(p + "Cap", 0.33, (0, HEAD_Y, 1.8), scale=(1.0, 0.95, 0.6), m=m["rust"], segs=16, rings=8),
            box(p + "CapBrim", (0.36, 0.26, 0.045), (0, HEAD_Y - 0.37, 1.77), rot=rad(10, 0, 0), bevel=0.02, m=m["rust"]),
            box(p + "CapPatch", (0.18, 0.04, 0.1), (0, HEAD_Y - 0.28, 1.86), rot=rad(-18, 0, 0), bevel=0.015, m=m["white"]),
        ]),
        "Acc_Mechanic_Goggles": bind("Head", [
            head_band(p + "GoggleBand", w, 1.85, 1.79, m["dark"], off=0.012, thick=0.02),
            cyl(p + "GoggleL", 0.09, 0.08, (-0.12, HEAD_Y - 0.28, 1.83), rot=(math.pi / 2, 0, 0), segs=14, bevel=0.02, m=m["lens"]),
            cyl(p + "GoggleR", 0.09, 0.08, (0.12, HEAD_Y - 0.28, 1.83), rot=(math.pi / 2, 0, 0), segs=14, bevel=0.02, m=m["lens"]),
        ]),
        "Acc_Mechanic_Wrench": bind("ForeArm.R", [
            box(p + "WrenchShaft", (0.06, 0.05, 0.5), (-0.44, -0.12, 0.36), rot=rad(-20, 0, 0), bevel=0.015, m=m["steel"]),
            box(p + "WrenchJaw", (0.14, 0.06, 0.12), (-0.44, -0.2, 0.12), rot=rad(-20, 0, 0), bevel=0.02, m=m["steel"]),
        ]),
        "Acc_Mechanic_Rag": bind("Head", [
            sphere(p + "Bandana", 0.32, (0, HEAD_Y + 0.01, 1.76), scale=(1.0, 0.94, 0.62), m=m["rust"], segs=16, rings=8),
            box(p + "Knot", (0.1, 0.08, 0.08), (0, HEAD_Y + 0.29, 1.68), bevel=0.025, m=m["rust"]),
        ]),
    }
    acc.update(faces("Mechanic", m, 0.6, ("Grin", "Snarl", "Clench", "Derp")))
    return acc


# ---------------------------------------------------------------------------
# Hazmat
# ---------------------------------------------------------------------------

def hazmat(m):
    """Bulky tintable suit ("Shirt") with taped seams, hood, glowing canister.
    The mask is the face (Face_Hazmat_*)."""
    p = "H_"
    w = 0.68
    suit, tape, rubber = m["shirt"], m["white"], m["dark"]
    parts = bind("Head", [
        blob(p + "Hood", (0, HEAD_Y + 0.02, 1.27), (0, HEAD_Y + 0.02, 1.94), [(0, 0.3, 0.27), (0.4, 0.35, 0.31), (0.8, 0.35, 0.31), (1, 0.32, 0.29)],
             suit, n=3.2, r0=0.08, r1=0.2, segs=26, mid=6),
        band(p + "HoodTape", (0, HEAD_Y + 0.02, 1.38), (0, HEAD_Y + 0.02, 1.31), 0.315, 0.285, tape, n=3.2, thick=0.02, flare=0.01, segs=26),
    ])
    tor, body = torso(p, suit, w=0.8, d=0.54, z0=0.88, belly=0.08, hunch=0.05, n=2.8)
    parts += tor
    parts += neck(p, suit, 0.34)
    parts += bind("Spine", [
        patch(p + "Zip", tor[0], (0, body.front(0, 1.08), 1.08), (0.06, 0.04, 0.5), tape, bevel=0.012),
        patch(p + "Badge", tor[0], (0.18, body.front(0.18, 1.25), 1.25), (0.2, 0.05, 0.2), tape, bevel=0.03),
        body.shell(p + "ChestTape", tape, 1.36, 1.31, off=0.016, segs=24, steps=1, lip=0.01),
        body.shell(p + "WaistTape", tape, 1.0, 0.95, off=0.02, segs=24, steps=1, lip=0.01),
    ])
    for i in range(3):
        a = math.radians(90 + i * 120)
        x, z = 0.18 + math.cos(a) * 0.055, 1.25 + math.sin(a) * 0.055
        parts += bind("Spine", [box(f"{p}Trefoil{i}", (0.06, 0.03, 0.06), (x, body.front(x, z) - 0.035, z), rot=(0, -a, 0), bevel=0.0, m=rubber)])
    parts += hips(p, suit, w=0.72, d=0.52, belt=rubber, belt_z=0.965)
    parts += bind("Hips", [cyl(p + "BeltCan", 0.08, 0.2, (-0.31, -0.19, 0.88), segs=12, bevel=0.03, m=m["glow_rad"])])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.22, sleeve=suit, sleeve_len="long", cuff=tape, glove=rubber, hand=0.02, seed=25)
        parts += leg(p, side, m, w=0.24, pants=suit, pants_len="long", foot="boot", shoe=rubber, sole=rubber, lace=tape, boot_h=0.26, tear=0)
        parts += bind(f"Thigh.{s}", [box(f"{p}KneePatch{s}", (0.2, 0.05, 0.14), (side * 0.16, -0.15, 0.58), bevel=0.03, m=tape)])
    return parts


def hazmat_masks(m):
    """The Hazmat's faces: three gas masks (round lenses, a visor window that
    shows the zombie behind it, a cyclops lens with twin filters)."""
    p = "HM_"
    fy = HEAD_Y - 0.32
    rubber, lens, filt = m["dark"], m["lens"], m["filter"]

    def mask_base(q):
        return [box(q + "Mask", (0.5, 0.14, 0.42), (0, fy + 0.04, 1.58), bevel=0.12, segs=3, m=rubber)]

    twin = mask_base(p + "A")
    for side in (-1, 1):
        twin += [cyl(f"{p}ALens{side}", 0.11, 0.06, (side * 0.12, fy - 0.03, 1.64), rot=(math.pi / 2, 0, 0), segs=16, bevel=0.02, m=lens),
                 torus(f"{p}ARim{side}", 0.11, 0.025, (side * 0.12, fy - 0.035, 1.64), rot=(math.pi / 2, 0, 0), m=filt, major_segs=16, minor_segs=5)]
    twin += [cyl(p + "AFilter", 0.11, 0.16, (0, fy - 0.1, 1.45), rot=(math.radians(70), 0, 0), segs=14, bevel=0.03, m=filt),
             cyl(p + "ACap", 0.115, 0.04, (0, fy - 0.17, 1.42), rot=(math.radians(70), 0, 0), segs=14, bevel=0.01, m=rubber),
             cyl(p + "ASide", 0.08, 0.14, (0.3, fy + 0.12, 1.48), rot=(0, math.radians(70), 0), segs=12, bevel=0.03, m=m["glow_rad"])]
    window = [box(p + "BFrame", (0.54, 0.12, 0.34), (0, fy + 0.06, 1.62), bevel=0.1, segs=3, m=rubber),
              box(p + "BWindow", (0.44, 0.06, 0.24), (0, fy + 0.0, 1.63), bevel=0.08, segs=3, m=m["glass"]),
              cyl(p + "BFilterL", 0.07, 0.14, (0.15, fy - 0.02, 1.4), rot=(math.radians(70), 0, math.radians(-20)), segs=12, bevel=0.02, m=filt),
              cyl(p + "BFilterR", 0.07, 0.14, (-0.15, fy - 0.02, 1.4), rot=(math.radians(70), 0, math.radians(20)), segs=12, bevel=0.02, m=filt),
              box(p + "BChin", (0.3, 0.1, 0.12), (0, fy + 0.04, 1.42), bevel=0.04, m=rubber)]
    # The zombie behind the window: two glowing eyes and a grin.
    for side in (-1, 1):
        window.append(sphere(f"{p}BEye{side}", 0.06, (side * 0.1, fy + 0.06, 1.65), scale=(1, 0.5, 1.15), m=lens, segs=10, rings=6))
    window.append(box(p + "BMouth", (0.18, 0.03, 0.05), (0, fy + 0.07, 1.57), bevel=0.015, m=m["white"]))
    cyclops = mask_base(p + "C") + [
        cyl(p + "CLens", 0.15, 0.07, (0, fy - 0.03, 1.64), rot=(math.pi / 2, 0, 0), segs=20, bevel=0.025, m=lens),
        torus(p + "CRim", 0.15, 0.03, (0, fy - 0.04, 1.64), rot=(math.pi / 2, 0, 0), m=filt, major_segs=20, minor_segs=5),
        cyl(p + "CFilterL", 0.085, 0.16, (0.2, fy - 0.04, 1.46), rot=(math.radians(60), math.radians(-25), 0), segs=12, bevel=0.03, m=filt),
        cyl(p + "CFilterR", 0.085, 0.16, (-0.2, fy - 0.04, 1.46), rot=(math.radians(60), math.radians(25), 0), segs=12, bevel=0.03, m=filt),
        cyl(p + "CGlowL", 0.06, 0.03, (0.23, fy - 0.11, 1.42), rot=(math.radians(60), math.radians(-25), 0), segs=12, bevel=0.0, m=m["glow_rad"]),
        cyl(p + "CGlowR", 0.06, 0.03, (-0.23, fy - 0.11, 1.42), rot=(math.radians(60), math.radians(25), 0), segs=12, bevel=0.0, m=m["glow_rad"]),
    ]
    return {"Face_Hazmat_Twin": bind("Head", twin), "Face_Hazmat_Window": bind("Head", window), "Face_Hazmat_Cyclops": bind("Head", cyclops)}


def hazmat_accessories(m):
    p = "HA_"
    acc = {
        "Acc_Hazmat_Tank": bind("Spine", [
            cyl(p + "Tank", 0.16, 0.64, (0, 0.4, 1.12), segs=16, bevel=0.06, m=m["white"]),
            cyl(p + "TankBand", 0.165, 0.1, (0, 0.4, 1.26), segs=16, bevel=0.02, m=m["glow_rad"]),
            tube(p + "TankHose", [(0, 0.42, 1.46), (0.2, 0.27, 1.56), (0.29, -0.1, 1.52)], 0.03, m=m["dark"], segs=6),
        ]),
        "Acc_Hazmat_Geiger": bind("ForeArm.L", [
            box(p + "Geiger", (0.16, 0.24, 0.14), (0.47, -0.16, 0.54), bevel=0.03, m=m["filter"]),
            box(p + "GeigerDial", (0.1, 0.03, 0.08), (0.47, -0.29, 0.56), bevel=0.01, m=m["glow_rad"]),
            box(p + "GeigerWand", (0.04, 0.3, 0.04), (0.47, -0.36, 0.48), bevel=0.01, m=m["dark"]),
        ]),
        "Acc_Hazmat_Sign": bind("Spine", [
            prism(p + "Sign", [(-0.22, -0.18), (0.22, -0.18), (0.0, 0.2)], 0.03, (0, 0.33, 1.2), rot=(0, 0, math.pi), m=m["glow"], bevel=0.01),
            box(p + "SignMark", (0.04, 0.035, 0.14), (0, 0.35, 1.2), bevel=0.01, m=m["dark"]),
        ]),
        "Acc_Hazmat_Barrel": bind("ForeArm.R", [
            cyl(p + "Barrel", 0.12, 0.26, (-0.45, -0.14, 0.42), segs=16, bevel=0.03, m=m["glow"]),
            torus(p + "BarrelRing", 0.122, 0.015, (-0.45, -0.14, 0.47), m=m["dark"], major_segs=16, minor_segs=4),
            cyl(p + "BarrelGoo", 0.1, 0.02, (-0.45, -0.14, 0.555), segs=14, bevel=0.0, m=m["glow_rad"]),
        ]),
    }
    acc.update(hazmat_masks(m))
    return acc


def build():
    scene = reset_scene()
    scene.render.fps = FPS
    m = materials()
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
    zombie_anim.bake(armature, zombie_anim.dune_clips, "dune_zombies")
    save_zombie("dune_zombies", [armature] + meshes)


if __name__ == "__main__":
    build()
