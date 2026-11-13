"""Abyss Aquarium zombies: one rig, three outfits, the shared clips.

    Outfit_Diver   Deep Diver: tintable drysuit, air tank, flippers. Wears
                   Acc_Diver_Helmet (brass diving helmet with glowing visor
                   eyes), which the game hides when its visor is shot out.
    Outfit_Octo    Mascot Inker: a staffer in a pink octopus mascot costume (big
                   cartoon-eyed head, tentacle skirt); Acc_Octo_InkSac glows
                   before it spits.
    Outfit_Jelly   Jelly Head: lean visitor in a raincoat and boots under
                   Acc_Jelly_Hat, a glowing jellyfish hat that charges an
                   electric aura.

Bodies, heads and faces come from zombie_kit.py; rig and bone names from
build_zombie.py; clips from zombie_anim.aqua_clips (the Diver's waddle and shove,
the Inker's squelch and Spit, the Jelly's sprint, plus the shared set), so
EnemyData can use this model with the shared zombie script.
Each outfit has several faces (Face_<Outfit>_<Preset>); the game shows one per
zombie. Materials named "Shirt", "Skin" and "SkinDark" are tinted per zombie by
the game. Faces -Y in Blender (+Z in Godot).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aqua_common import *  # noqa: F401,F403
from build_zombie import FPS, bind, build_armature, save_zombie, skin  # noqa: E402
import zombie_anim  # noqa: E402
from zombie_kit import (HEAD_Y, arm, band, base_materials, blob, decal, face_y, faces, hair, hair_top, head, hips, leg, neck,  # noqa: E402
                        patch, skull, tear_fn, torso)


def materials():
    m = base_materials("aqua", skin="#9fcf4a", skin_dark="#6aa236")
    m.update(
        shirt=mat("Shirt", "#ff7a1f", rough=0.55),
        brass=mat("HelmetBrass", "#e0a83a", rough=0.3, metal=0.7),
        brass_dark=mat("HelmetBrassDark", "#9a6a1e", rough=0.35, metal=0.6),
        visor=mat("Visor", "#7ff4ff", rough=0.1, emit=0.9),
        visor_eye=mat("VisorEye", "#ffe45a", rough=0.2, emit=4.0),
        tank=mat("AirTank", "#ffd23a", rough=0.4, emit=0.15),
        fin=mat("Flipper", "#1f8fff", rough=0.5),
        torch=mat("TorchGlow", "#fff1b0", rough=0.2, emit=4.0),
        octo_light=mat("OctoLight", "#ffb3dd", rough=0.55),
        polo=mat("StaffPolo", "#1fa3b5", rough=0.6),
        ink=mat("InkSac", "#6a2bff", rough=0.3, emit=1.2),
        badge=mat("Badge", "#ffd93b", rough=0.4),
        coat_trim=mat("RaincoatTrim", "#ff8a2a", rough=0.5),
        boot=mat("Boot", "#ff3f6a", rough=0.5),
        jeans=mat("Jeans", "#3456a8", rough=0.7),
        jelly=mat("JellyHat", "#ff5fd0", rough=0.2, emit=1.1),
        jelly_ten=mat("JellyTentacle", "#a865ff", rough=0.2, emit=1.6),
        jelly_rim=mat("JellyRim", "#ffd1f6", rough=0.2, emit=1.8),
        sea=mat("Seaweed", "#2fbf6a", rough=0.6),
    )
    return m


# ---------------------------------------------------------------------------
# Deep Diver
# ---------------------------------------------------------------------------

def diver(m):
    """Tintable drysuit with harness and weight belt, air tank, flippers.
    Seven materials."""
    p = "D_"
    suit, dark, white = m["shirt"], m["dark"], m["white"]
    parts = head(p, m, 0.6)
    parts += hair(p, 0.6, dark, "flat", 8) + hair_top(p, 0.6, dark, "flat", 8)
    tor, body = torso(p, suit, w=0.76, d=0.5, z0=0.9, belly=0.05, hunch=0.05)
    parts += tor
    parts += neck(p, dark, 0.3)
    harness = [
        band(p + "NeckSeal", (0, 0.0, 1.46), (0, 0.0, 1.37), 0.2, 0.18, dark, n=2.6, thick=0.025, flare=0.02, segs=20),
        body.shell(p + "ChestStrap", dark, 1.23, 1.18, off=0.016, segs=24, steps=1, lip=0.01),
        patch(p + "Zip", tor[0], (0, body.front(0, 1.14), 1.14), (0.05, 0.04, 0.46), white, bevel=0.01),
        patch(p + "Gauge", tor[0], (0.16, body.front(0.16, 1.05), 1.05), (0.14, 0.05, 0.14), white, bevel=0.03),
        decal(p + "GaugeFace", tor[0], (0.16, body.front(0.16, 1.05), 1.05), 0.045, m["visor"], offset=0.03, segs=14),
        # Air tank on the back, with a chrome valve and hose.
        cyl(p + "Tank", 0.17, 0.75, (0, 0.42, 1.12), segs=18, bevel=0.06, m=m["tank"]),
        band(p + "TankBand", (0, 0.42, 1.22), (0, 0.42, 1.14), 0.175, 0.175, dark, n=2.0, thick=0.02, segs=18),
        cyl(p + "Valve", 0.07, 0.14, (0, 0.42, 1.56), segs=10, bevel=0.02, m=white),
        box(p + "ValveKnob", (0.16, 0.04, 0.04), (0, 0.42, 1.6), bevel=0.01, m=white),
        tube(p + "Hose", [(0.06, 0.42, 1.6), (0.25, 0.28, 1.64), (0.3, 0.0, 1.52)], 0.03, m=dark, segs=6),
    ]
    for side in (1, -1):
        x = side * 0.2
        harness.append(tube(f"{p}Strap{side}", [(x, body.front(x, 1.42, back=True, off=0.02), 1.42), (x, 0.0, 1.47),
                                                (x, body.front(x, 1.42, off=0.03), 1.4), (x, body.front(x, 1.15, off=0.03), 1.15),
                                                (x, body.front(x, 0.97, off=0.03), 0.97)], 0.03, m=dark, segs=6))
    parts += bind("Spine", harness)
    parts += hips(p, suit, w=0.7, d=0.5, belt=dark, buckle=white)
    parts += bind("Hips", [box(f"{p}Lead{i}", (0.12, 0.08, 0.1), (math.cos(a) * 0.37, math.sin(a) * 0.28, 0.965), rot=(0, 0, a), bevel=0.02,
                               m=dark) for i, a in enumerate((0.5, 1.2, 1.95, 2.6, 3.7, 4.4, 5.0, 5.7))])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        lx = side * 0.16
        parts += arm(p, side, m, w=0.2, sleeve=suit, sleeve_len="long", cuff=dark, glove=dark, nail=white, seed=11)
        parts += leg(p, side, m, w=0.22, pants=suit, pants_len="long", foot="none", tear=0)
        parts += bind(f"Shin.{s}", [
            blob(f"{p}Bootie{s}", (lx, 0.08, 0.1), (lx, -0.2, 0.08), [(0, 0.12, 0.07), (0.6, 0.13, 0.06), (1, 0.12, 0.05)], dark, n=3.0, r0=0.04,
                 r1=0.04, segs=16, mid=3),
            blob(f"{p}Fin{s}", (lx, -0.12, 0.035), (lx, -0.66, 0.02), [(0, 0.13, 0.02), (0.6, 0.18, 0.017), (1, 0.2, 0.012)], m["fin"], n=4.0,
                 r0=0.012, r1=0.012, segs=16, mid=4),
            box(f"{p}FinRibA{s}", (0.03, 0.5, 0.045), (lx - 0.12, -0.42, 0.04), rot=rad(0, 0, -side * 3), bevel=0.01, m=dark),
            box(f"{p}FinRibB{s}", (0.03, 0.5, 0.045), (lx + 0.12, -0.42, 0.04), rot=rad(0, 0, side * 3), bevel=0.01, m=dark),
        ])
    return parts


def diver_accessories(m):
    p = "DA_"
    brass, bd = m["brass"], m["brass_dark"]
    helmet = [
        sphere(p + "Dome", 0.44, (0, HEAD_Y, 1.64), scale=(1.0, 1.0, 1.02), m=brass, segs=22, rings=12),
        cyl(p + "Collar", 0.42, 0.14, (0, 0, 1.3), segs=22, bevel=0.04, m=bd),
        cyl(p + "Breast", 0.5, 0.12, (0, 0, 1.22), segs=22, bevel=0.05, m=brass, radius_top=0.42),
        torus(p + "VisorRing", 0.2, 0.045, (0, HEAD_Y - 0.41, 1.64), rot=rad(90, 0, 0), m=bd, major_segs=24, minor_segs=6),
        cyl(p + "Visor", 0.19, 0.04, (0, HEAD_Y - 0.4, 1.64), rot=rad(90, 0, 0), segs=22, bevel=0.0, m=m["visor"]),
        box(p + "GrilleH", (0.36, 0.03, 0.02), (0, HEAD_Y - 0.435, 1.59), bevel=0.0, m=bd),
        cyl(p + "TopValve", 0.06, 0.12, (0, HEAD_Y, 2.1), segs=10, bevel=0.02, m=bd),
    ]
    # Glowing eyes behind the visor: the readable "face" of the diver.
    for side in (-1, 1):
        helmet.append(sphere(f"{p}Eye{side}", 0.05, (side * 0.085, HEAD_Y - 0.44, 1.68), scale=(1.0, 0.35, 1.25), m=m["visor_eye"], segs=8, rings=5))
        helmet += [
            torus(f"{p}SideRing{side}", 0.11, 0.03, (side * 0.41, HEAD_Y - 0.05, 1.66), rot=rad(0, 90, 0), m=bd, major_segs=16, minor_segs=5),
            cyl(f"{p}SidePort{side}", 0.1, 0.03, (side * 0.41, HEAD_Y - 0.05, 1.66), rot=rad(0, 90, 0), segs=12, bevel=0.0, m=m["visor"]),
        ]
    for i in range(8):
        a = math.tau * i / 8
        helmet.append(sphere(f"{p}Bolt{i}", 0.03, (math.cos(a) * 0.47, math.sin(a) * 0.47, 1.26), m=bd, segs=6, rings=4))
    torch = [
        cyl(p + "TorchBody", 0.06, 0.24, (0.56, -0.1, 1.33), rot=rad(80, 0, 0), segs=10, bevel=0.02, m=m["dark"]),
        cyl(p + "TorchLens", 0.065, 0.02, (0.56, -0.23, 1.31), rot=rad(80, 0, 0), segs=10, bevel=0.0, m=m["torch"]),
    ]
    knife = [box(p + "Sheath", (0.07, 0.05, 0.28), (0.31, -0.12, 0.6), bevel=0.02, m=m["dark"]),
             box(p + "Handle", (0.05, 0.05, 0.1), (0.31, -0.12, 0.78), bevel=0.02, m=m["fin"])]
    star = []
    for i in range(5):
        a = math.tau * i / 5 + math.pi / 2
        star.append(tube(f"{p}StarArm{i}", [(-0.2, -0.28, 1.02), (-0.2 + math.cos(a) * 0.09, -0.29, 1.02 + math.sin(a) * 0.09)], 0.03, m=m["boot"],
                         segs=6, radius_end=0.012))
    weed = [tube(f"{p}Weed{i}", [(0.3 + i * 0.03, -0.1 + i * 0.08, 1.46), (0.38 + i * 0.02, -0.18 + i * 0.1, 1.3), (0.33 + i * 0.03, -0.24 + i * 0.1, 1.12),
                                 (0.38, -0.22 + i * 0.1, 0.98)], 0.022, m=m["sea"], segs=5, radius_end=0.01) for i in range(3)]
    bag = [sphere(p + "Bag", 0.13, (-0.34, -0.1, 0.8), scale=(0.8, 1.0, 1.25), m=m["polo"], segs=12, rings=8),
           sphere(p + "Shell", 0.05, (-0.38, -0.2, 0.85), scale=(1.0, 0.6, 0.8), m=m["octo_light"], segs=8, rings=5)]
    acc = {
        "Acc_Diver_Helmet": bind("Head", helmet),
        "Acc_Diver_Torch": bind("Spine", torch),
        "Acc_Diver_Knife": bind("Thigh.L", knife),
        "Acc_Diver_Starfish": bind("Spine", star),
        "Acc_Diver_Seaweed": bind("Spine", weed),
        "Acc_Diver_Bag": bind("Hips", bag),
    }
    acc.update(faces("Diver", m, 0.6, ("Gape", "Snarl", "Derp"), tongue=m["boot"]))
    return acc


# ---------------------------------------------------------------------------
# Mascot Inker (octopus costume)
# ---------------------------------------------------------------------------

def tentacle(name, a, m, sucker, length=0.6, z0=0.82, r0=0.22):
    """A tapered costume tentacle hanging from the waist ring, curling outward at the tip."""
    c, s = math.cos(a), math.sin(a)
    pts = []
    for k in range(7):
        t = k / 6
        rr = r0 + 0.08 * t + 0.2 * t ** 3
        pts.append((c * rr, s * rr, z0 - length * t + 0.16 * t ** 4))
    parts = [tube(name, pts, 0.085, m=m, segs=10, radius_end=0.03)]
    for k in range(1, 5):
        t = k / 5.5
        rr = r0 + 0.08 * t + 0.2 * t ** 3 + 0.06 - 0.02 * t
        parts.append(sphere(f"{name}S{k}", 0.024, (c * rr, s * rr, z0 - length * t + 0.16 * t ** 4), m=sucker, segs=6, rings=4))
    return parts


def octo(m):
    """A staffer in an octopus mascot costume: a big round cartoon-eyed head on
    top, a face ring framing the zombie's own face, a round body with a light
    belly and a tentacle skirt. The costume is "Shirt" (tinted). Seven materials."""
    p = "O_"
    w = 0.58
    body_m, light, white, dark = m["shirt"], m["octo_light"], m["white"], m["dark"]
    parts = head(p, m, w)
    sk = skull(w)
    # Mascot head: a big glossy dome above the face, with cartoon eyes and cheeks.
    parts += bind("Head", [
        sphere(p + "Hood", 0.54, (0, HEAD_Y + 0.1, 2.02), scale=(1.06, 1.06, 1.0), m=body_m, segs=24, rings=14),
        sk.shell(p + "HoodSides", body_m, 1.86, 1.42, off=0.05, gap=150, segs=26, steps=5, lip=0.04),
        torus(p + "FaceRing", 0.31, 0.045, (0, face_y(w, 1.6) + 0.03, 1.6), rot=rad(90, 0, 0), m=light, major_segs=28, minor_segs=8),
        sphere(p + "Spot1", 0.08, (0.36, HEAD_Y - 0.05, 2.25), scale=(1, 0.5, 1), rot=rad(0, 0, -30), m=light, segs=10, rings=6),
        sphere(p + "Spot2", 0.06, (-0.4, HEAD_Y + 0.12, 2.3), scale=(1, 0.5, 1), rot=rad(0, 0, 30), m=light, segs=10, rings=6),
        sphere(p + "Spot3", 0.07, (0.08, HEAD_Y + 0.05, 2.55), scale=(1, 1, 0.45), m=light, segs=10, rings=6),
    ])
    for side in (-1, 1):
        parts += bind("Head", [
            sphere(f"{p}CosEye{side}", 0.16, (side * 0.22, HEAD_Y - 0.4, 2.12), scale=(1, 0.55, 1.15), m=white, segs=16, rings=9),
            sphere(f"{p}CosPupil{side}", 0.075, (side * 0.2, HEAD_Y - 0.48, 2.09), scale=(1, 0.45, 1.15), m=dark, segs=10, rings=6),
            sphere(f"{p}CosShine{side}", 0.025, (side * 0.17, HEAD_Y - 0.515, 2.14), m=white, segs=6, rings=4),
            box(f"{p}Lash{side}", (0.14, 0.04, 0.035), (side * 0.25, HEAD_Y - 0.36, 2.31), rot=rad(0, side * 18, 0), bevel=0.012, m=dark),
            sphere(f"{p}Cheek{side}", 0.07, (side * 0.4, HEAD_Y - 0.3, 1.92), scale=(1, 0.4, 0.7), rot=rad(0, 0, side * 40), m=light, segs=10, rings=6),
        ])
    tor, body = torso(p, body_m, w=0.74, d=0.56, z0=0.86, waist=0.9, belly=0.08, hunch=0.03, n=2.6)
    parts += tor
    parts += neck(p, body_m, 0.28)
    parts += bind("Spine", [
        decal(p + "Belly", tor[0], (0, body.front(0, 1.1), 1.1), 0.21, light, squash=1.25, segs=26),
        patch(p + "Badge", tor[0], (0.17, body.front(0.17, 1.3), 1.3), (0.15, 0.04, 0.1), white, bevel=0.012),
        decal(p + "BadgeStripe", tor[0], (0.17, body.front(0.17, 1.33), 1.33), 0.045, m["polo"], squash=0.3, offset=0.03, segs=12),
    ])
    parts += hips(p, m["polo"], w=0.6, d=0.44)
    parts += bind("Hips", [cyl(p + "Skirt", 0.4, 0.26, (0, 0, 0.86), segs=22, bevel=0.08, m=body_m, radius_top=0.38)])
    for i in range(8):
        a = math.tau * (i + 0.5) / 8
        parts += bind("Hips", tentacle(f"{p}Ten{i}", a, body_m, light))
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.19, sleeve=body_m, sleeve_len="long", cuff=light, nail=white, seed=13)
        parts += bind(f"UpperArm.{s}", [sphere(f"{p}ArmSucker{s}{i}", 0.026, (side * (0.47 - i * 0.01), -0.07, 1.16 - i * 0.07), scale=(1, 0.6, 1),
                                               m=light, segs=6, rings=4) for i in range(3)])
        parts += leg(p, side, m, w=0.2, pants=m["polo"], pants_len="long", foot="shoe", shoe=dark, sole=white, lace=white, tear=0)
    return parts


def octo_accessories(m):
    p = "OA_"
    acc = {
        "Acc_Octo_InkSac": bind("Spine", [
            sphere(p + "Sac", 0.15, (0, -0.37, 0.98), scale=(1.1, 0.6, 1.0), m=m["ink"], segs=12, rings=8),
            torus(p + "SacRim", 0.13, 0.025, (0, -0.41, 0.98), rot=rad(90, 0, 0), m=m["shirt"], major_segs=16, minor_segs=5),
        ]),
        "Acc_Octo_Lanyard": bind("Spine", [
            tube(p + "Cord", [(-0.12, -0.26, 1.4), (-0.05, -0.35, 1.22), (0.05, -0.36, 1.14)], 0.012, m=m["polo"], segs=5),
            box(p + "Card", (0.1, 0.02, 0.13), (0.05, -0.37, 1.08), bevel=0.01, m=m["white"]),
        ]),
        "Acc_Octo_Bow": bind("Head", [
            sphere(p + "BowL", 0.1, (-0.12, HEAD_Y + 0.12, 2.6), scale=(1.3, 0.6, 0.9), m=m["badge"], segs=8, rings=5),
            sphere(p + "BowR", 0.1, (0.12, HEAD_Y + 0.12, 2.6), scale=(1.3, 0.6, 0.9), m=m["badge"], segs=8, rings=5),
            sphere(p + "BowKnot", 0.055, (0, HEAD_Y + 0.1, 2.6), m=m["badge"], segs=8, rings=5),
        ]),
        "Acc_Octo_SailorHat": bind("Head", [
            cyl(p + "Hat", 0.2, 0.12, (0.12, HEAD_Y + 0.05, 2.6), rot=rad(0, 12, 0), segs=18, bevel=0.03, m=m["white"], radius_top=0.18),
            cyl(p + "HatBrim", 0.25, 0.04, (0.11, HEAD_Y + 0.05, 2.54), rot=rad(0, 12, 0), segs=18, bevel=0.015, m=m["white"]),
            cyl(p + "HatBand", 0.205, 0.04, (0.115, HEAD_Y + 0.05, 2.58), rot=rad(0, 12, 0), segs=18, bevel=0.01, m=m["polo"]),
        ]),
    }
    acc.update(faces("Octo", m, 0.58, ("Grin", "Gape", "Derp"), tongue=m["shirt"]))
    return acc


# ---------------------------------------------------------------------------
# Jelly Head (raincoat kid with a glowing jellyfish hat)
# ---------------------------------------------------------------------------

def jelly(m):
    """Lean visitor in a tintable raincoat with a hood, shorts and rubber boots.
    Eight materials."""
    p = "J_"
    coat, trim = m["shirt"], m["coat_trim"]
    parts = head(p, m, 0.56)
    parts += hair(p, 0.56, m["dark"], "fringe", 9)
    tor, body = torso(p, coat, w=0.56, d=0.42, z0=0.98, hunch=0.04)
    parts += tor
    parts += neck(p, m["skin"], 0.22)
    over = body.shell(p + "Coat", coat, 1.0, 0.74, off=0.03, flare=0.07, tear=tear_fn(24, 9, 1, 0.04), segs=24, steps=3)
    parts += bind("Spine", [
        over,
        patch(p + "Placket", tor[0], (0, body.front(0, 1.12), 1.12), (0.07, 0.04, 0.5), trim, bevel=0.01),
        sphere(p + "Hood", 0.26, (0, 0.23, 1.42), scale=(1.3, 0.8, 0.7), m=coat, segs=14, rings=8),
        band(p + "Collar", (0, 0.0, 1.47), (0, 0.0, 1.38), 0.17, 0.16, coat, n=2.6, thick=0.025, flare=0.03, segs=20),
    ] + [sphere(f"{p}Button{i}", 0.026, (0.075, body.front(0.075, 1.28 - i * 0.14) - 0.012, 1.28 - i * 0.14), m=trim, segs=8, rings=5)
         for i in range(4)]
        + [patch(f"{p}Pocket{side}", over, (side * 0.17, body.front(side * 0.17, 0.86, off=0.05), 0.86), (0.13, 0.04, 0.1), trim, bevel=0.015)
           for side in (1, -1)])
    parts += hips(p, m["jeans"], w=0.5, d=0.4)
    for side in (1, -1):
        parts += arm(p, side, m, w=0.17, sleeve=coat, sleeve_len="long", cuff=trim, nail=m["white"], seed=15)
        parts += leg(p, side, m, w=0.17, pants=m["jeans"], pants_len="shorts", foot="boot", shoe=m["boot"], sole=m["dark"], lace=m["boot"],
                     boot_h=0.26, tear=1, seed=16)
    return parts


def jelly_accessories(m):
    p = "JA_"
    hat = [sphere(p + "Bell", 0.41, (0, HEAD_Y + 0.02, 1.88), scale=(1.0, 1.0, 0.72), m=m["jelly"], segs=22, rings=11),
           torus(p + "Rim", 0.39, 0.05, (0, HEAD_Y + 0.02, 1.76), m=m["jelly_rim"], major_segs=30, minor_segs=6)]
    for i in range(5):
        a = math.tau * i / 5
        hat.append(sphere(f"{p}Gonad{i}", 0.07, (math.cos(a) * 0.17, HEAD_Y + 0.02 + math.sin(a) * 0.17, 2.08), scale=(1, 1, 0.5),
                          m=m["jelly_rim"], segs=8, rings=5))
    for i in range(12):
        a = math.tau * i / 12
        if -0.6 < math.sin(a) < 0.0 and abs(math.cos(a)) < 0.6:
            continue        # keep the face clear
        x, y = math.cos(a) * 0.38, HEAD_Y + 0.02 + math.sin(a) * 0.38
        out = 0.06 * (1 if i % 2 else -1)
        hat.append(tube(f"{p}Ten{i}", [(x, y, 1.76), (x * 1.08 + out, y * 1.08, 1.45), (x * 1.0, y * 1.0 - out, 1.15)],
                        0.022, m=m["jelly_ten"], segs=5, radius_end=0.01))
    frog = [sphere(p + "Frog", 0.2, (0, 0.33, 1.14), scale=(1.1, 0.6, 1.0), m=m["sea"], segs=14, rings=8)]
    for side in (-1, 1):
        frog += [sphere(f"{p}FrogEye{side}", 0.07, (side * 0.1, 0.36, 1.33), m=m["white"], segs=8, rings=5),
                 sphere(f"{p}FrogPupil{side}", 0.03, (side * 0.1, 0.42, 1.34), m=m["dark"], segs=6, rings=4),
                 box(f"{p}FrogStrap{side}", (0.05, 0.42, 0.05), (side * 0.15, 0.1, 1.38), bevel=0.015, m=m["sea"])]
    gx = -0.435
    umbrella = [cyl(p + "Brolly", 0.07, 0.55, (gx, -0.08, 0.32), rot=rad(-6, 0, 0), segs=8, bevel=0.02, m=m["coat_trim"], radius_top=0.025),
                torus(p + "BrollyHook", 0.05, 0.012, (gx, -0.06, 0.6), rot=rad(0, 90, 0), m=m["dark"], major_segs=12, minor_segs=4, arc=math.pi)]
    duck = [sphere(p + "Duck", 0.06, (0.17, -0.27, 0.92), scale=(1.2, 1.0, 0.85), m=m["badge"], segs=10, rings=6),
            sphere(p + "DuckHead", 0.04, (0.19, -0.31, 0.98), m=m["badge"], segs=8, rings=5),
            sphere(p + "DuckBeak", 0.02, (0.19, -0.35, 0.975), scale=(1.2, 1.2, 0.6), m=m["coat_trim"], segs=6, rings=4)]
    acc = {
        "Acc_Jelly_Hat": bind("Head", hat),
        "Acc_Jelly_Backpack": bind("Spine", frog),
        "Acc_Jelly_Umbrella": bind("ForeArm.R", umbrella),
        "Acc_Jelly_Duck": bind("Spine", duck),
    }
    acc.update(faces("Jelly", m, 0.56, ("Grin", "Gape", "Derp", "Sleepy"), tongue=m["boot"]))
    return acc


def build():
    scene = reset_scene()
    scene.render.fps = FPS
    m = materials()
    armature = build_armature()
    meshes = [
        skin("Outfit_Diver", diver(m), armature),
        skin("Outfit_Octo", octo(m), armature),
        skin("Outfit_Jelly", jelly(m), armature),
    ]
    for group in (diver_accessories(m), octo_accessories(m), jelly_accessories(m)):
        for name, parts in group.items():
            meshes.append(skin(name, parts, armature))
    zombie_anim.bake(armature, zombie_anim.aqua_clips, "aqua_zombies")
    save_zombie("aqua_zombies", [armature] + meshes)


if __name__ == "__main__":
    build()
