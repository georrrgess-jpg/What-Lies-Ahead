"""Abyss Aquarium zombies: one rig, three outfits, the shared six clips.

    Outfit_Diver   Deep Diver: orange drysuit, air tank, flippers. Wears
                   Acc_Diver_Helmet (brass diving helmet with glowing visor
                   eyes), which the game hides when its visor is shot out.
    Outfit_Octo    Mascot Inker: a staffer in a pink octopus costume with a
                   tentacle skirt; Acc_Octo_InkSac glows before it spits.
    Outfit_Jelly   Jelly Head: lean visitor in a yellow raincoat and boots
                   under Acc_Jelly_Hat, a glowing jellyfish hat that charges
                   an electric aura.

Rig and bone names come straight from build_zombie.py and the clips from
zombie_anim.aqua_clips (the Diver's waddle and shove, the Inker's squelch and
Spit, the Jelly's sprint, plus the shared set), so EnemyData can use this
model with the shared zombie script. Materials named "Shirt", "Skin" and "SkinDark" are
tinted per zombie by the game. Faces -Y in Blender (+Z in Godot).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aqua_common import *  # noqa: F401,F403
from build_zombie import FPS, bind, build_armature, head_parts, limb_parts, skin  # noqa: E402
import zombie_anim  # noqa: E402


def materials():
    return dict(
        skin=mat("Skin", "#9fcf4a", rough=0.6),
        skin_dark=mat("SkinDark", "#6aa236", rough=0.65),
        eye=mat("Eye", "#fff3a0", rough=0.3, emit=1.6),
        pupil=mat("Pupil", "#2a2a1e", rough=0.4),
        mouth=mat("Mouth", "#2e1a2c", rough=0.7),
        teeth=mat("Teeth", "#fff3d6", rough=0.4),
        white=mat("White", "#f7f4f2", rough=0.6),
        shirt=mat("Shirt", "#ff7a1f", rough=0.55),
        suit_dark=mat("SuitDark", "#26232f", rough=0.55),
        brass=mat("HelmetBrass", "#e0a83a", rough=0.3, metal=0.7),
        brass_dark=mat("HelmetBrassDark", "#9a6a1e", rough=0.35, metal=0.6),
        copper=mat("Copper", "#c8693a", rough=0.35, metal=0.6),
        visor=mat("Visor", "#7ff4ff", rough=0.1, emit=0.9),
        visor_eye=mat("VisorEye", "#ffe45a", rough=0.2, emit=4.0),
        tank=mat("AirTank", "#ffd23a", rough=0.4, emit=0.15),
        chrome=mat("Chrome", "#d4dce8", rough=0.2, metal=0.8),
        fin=mat("Flipper", "#1f8fff", rough=0.5),
        hose=mat("Hose", "#2b2f3d", rough=0.6),
        lead=mat("Lead", "#5d6370", rough=0.5, metal=0.4),
        torch=mat("TorchGlow", "#fff1b0", rough=0.2, emit=4.0),
        octo=mat("OctoPink", "#ff5fb4", rough=0.55),
        octo_light=mat("OctoLight", "#ffb3dd", rough=0.55),
        octo_dark=mat("OctoDark", "#b02a7a", rough=0.6),
        sucker=mat("Sucker", "#ffe0f0", rough=0.5),
        polo=mat("StaffPolo", "#1fa3b5", rough=0.6),
        ink=mat("InkSac", "#6a2bff", rough=0.3, emit=1.2),
        badge=mat("Badge", "#ffd93b", rough=0.4),
        coat=mat("Raincoat", "#ffd23a", rough=0.45),
        coat_trim=mat("RaincoatTrim", "#ff8a2a", rough=0.5),
        boot=mat("Boot", "#ff3f6a", rough=0.5),
        jeans=mat("Jeans", "#3456a8", rough=0.7),
        jelly=mat("JellyHat", "#ff5fd0", rough=0.2, emit=1.1),
        jelly_ten=mat("JellyTentacle", "#a865ff", rough=0.2, emit=1.6),
        jelly_rim=mat("JellyRim", "#ffd1f6", rough=0.2, emit=1.8),
    )


# ---------------------------------------------------------------------------
# Deep Diver
# ---------------------------------------------------------------------------

def diver(m):
    p = "D_"
    suit, dark = m["shirt"], m["suit_dark"]
    parts = head_parts(p, 0.6, m)
    parts += bind("Spine", [
        box(p + "Torso", (0.74, 0.5, 0.58), (0, 0, 1.13), bevel=0.15, segs=4, m=suit),
        box(p + "Belly", (0.66, 0.48, 0.24), (0, -0.01, 0.97), bevel=0.1, segs=3, m=suit),
        box(p + "Neck", (0.3, 0.28, 0.12), (0, 0, 1.41), bevel=0.05, m=dark),
        box(p + "Zip", (0.05, 0.04, 0.46), (0, -0.255, 1.14), bevel=0.01, m=m["chrome"]),
        box(p + "StrapL", (0.09, 0.53, 0.6), (0.2, 0, 1.13), bevel=0.03, m=dark),
        box(p + "StrapR", (0.09, 0.53, 0.6), (-0.2, 0, 1.13), bevel=0.03, m=dark),
        box(p + "ChestStrap", (0.62, 0.53, 0.07), (0, 0, 1.2), bevel=0.02, m=dark),
        box(p + "Gauge", (0.14, 0.05, 0.14), (0.15, -0.28, 1.05), bevel=0.03, m=m["chrome"]),
        cyl(p + "GaugeFace", 0.05, 0.02, (0.15, -0.31, 1.05), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=m["visor"]),
        # Air tank on the back, with a chrome valve and hoses.
        cyl(p + "Tank", 0.17, 0.75, (0, 0.38, 1.1), segs=16, bevel=0.06, m=m["tank"]),
        cyl(p + "Valve", 0.07, 0.14, (0, 0.38, 1.54), segs=10, bevel=0.02, m=m["chrome"]),
        box(p + "ValveKnob", (0.16, 0.04, 0.04), (0, 0.38, 1.58), bevel=0.01, m=m["chrome"]),
        tube(p + "HoseL", [(0.06, 0.38, 1.58), (0.25, 0.25, 1.62), (0.28, 0.0, 1.5)], 0.03, m=m["hose"], segs=6),
    ])
    parts += bind("Hips", [
        box(p + "Pants", (0.68, 0.48, 0.3), (0, 0, 0.84), bevel=0.09, segs=3, m=suit),
        box(p + "Belt", (0.72, 0.52, 0.08), (0, 0, 0.96), bevel=0.02, m=dark),
        box(p + "Buckle", (0.14, 0.04, 0.1), (0, -0.27, 0.96), bevel=0.02, m=m["chrome"]),
    ] + [box(f"{p}Lead{i}", (0.12, 0.08, 0.1), (math.cos(a) * 0.36, math.sin(a) * 0.27, 0.96), rot=(0, 0, a), bevel=0.02, m=m["lead"])
         for i, a in enumerate((0.5, 1.2, 1.95, 2.6, 3.7, 4.4, 5.0, 5.7))])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += limb_parts(p, side, m, arm_w=0.2, leg_w=0.22, sleeve=suit, shorts=suit, shoe=dark, band=dark, flipflop=True)
        lx = side * 0.16
        parts += bind(f"Shin.{s}", [
            box(f"{p}ShinSuit{s}", (0.25, 0.26, 0.3), (lx, 0, 0.34), bevel=0.07, m=suit),
            box(f"{p}Bootie{s}", (0.27, 0.38, 0.14), (lx, -0.07, 0.09), bevel=0.05, m=dark),
            box(f"{p}Fin{s}", (0.34, 0.62, 0.035), (lx, -0.46, 0.035), rot=rad(-4, 0, 0), bevel=0.012, m=m["fin"]),
            box(f"{p}FinRibA{s}", (0.03, 0.55, 0.05), (lx - 0.12, -0.44, 0.05), bevel=0.01, m=dark),
            box(f"{p}FinRibB{s}", (0.03, 0.55, 0.05), (lx + 0.12, -0.44, 0.05), bevel=0.01, m=dark),
        ])
        parts += bind(f"ForeArm.{s}", [box(f"{p}Glove{s}", (0.27, 0.22, 0.12), (side * 0.43, -0.01, 0.7), bevel=0.04, m=dark)])
    return parts


def diver_accessories(m):
    p = "DA_"
    brass, bd = m["brass"], m["brass_dark"]
    helmet = [
        sphere(p + "Dome", 0.43, (0, 0.0, 1.62), scale=(1.0, 1.0, 1.02), m=brass, segs=20, rings=12),
        cyl(p + "Collar", 0.42, 0.14, (0, 0, 1.3), segs=20, bevel=0.04, m=bd),
        cyl(p + "Breast", 0.5, 0.12, (0, 0, 1.22), segs=20, bevel=0.05, m=brass, radius_top=0.42),
        torus(p + "VisorRing", 0.2, 0.045, (0, -0.4, 1.62), rot=rad(90, 0, 0), m=bd, major_segs=24, minor_segs=6),
        cyl(p + "Visor", 0.19, 0.04, (0, -0.39, 1.62), rot=rad(90, 0, 0), segs=20, bevel=0.0, m=m["visor"]),
        box(p + "GrilleH", (0.36, 0.03, 0.02), (0, -0.425, 1.57), bevel=0.0, m=bd),
        cyl(p + "TopValve", 0.06, 0.12, (0, 0.0, 2.08), segs=10, bevel=0.02, m=m["copper"]),
    ]
    # Glowing eyes behind the visor: the readable "face" of the diver.
    for side in (-1, 1):
        helmet.append(sphere(f"{p}Eye{side}", 0.05, (side * 0.085, -0.43, 1.66), scale=(1.0, 0.35, 1.25), m=m["visor_eye"], segs=8, rings=5))
        helmet += [
            torus(f"{p}SideRing{side}", 0.11, 0.03, (side * 0.4, -0.05, 1.64), rot=rad(0, 90, 0), m=bd, major_segs=16, minor_segs=5),
            cyl(f"{p}SidePort{side}", 0.1, 0.03, (side * 0.4, -0.05, 1.64), rot=rad(0, 90, 0), segs=12, bevel=0.0, m=m["visor"]),
        ]
    for i in range(8):
        a = math.tau * i / 8
        helmet.append(sphere(f"{p}Bolt{i}", 0.03, (math.cos(a) * 0.47, math.sin(a) * 0.47, 1.26), m=m["copper"], segs=6, rings=4))
    torch = [
        cyl(p + "TorchBody", 0.06, 0.24, (0.33, -0.12, 1.3), rot=rad(80, 0, 0), segs=10, bevel=0.02, m=m["suit_dark"]),
        cyl(p + "TorchLens", 0.065, 0.02, (0.33, -0.25, 1.28), rot=rad(80, 0, 0), segs=10, bevel=0.0, m=m["torch"]),
    ]
    knife = [box(p + "Sheath", (0.07, 0.05, 0.28), (0.3, -0.12, 0.6), bevel=0.02, m=m["suit_dark"]),
             box(p + "Handle", (0.05, 0.05, 0.1), (0.3, -0.12, 0.78), bevel=0.02, m=m["fin"])]
    return {
        "Acc_Diver_Helmet": bind("Head", helmet),
        "Acc_Diver_Torch": bind("Spine", torch),
        "Acc_Diver_Knife": bind("Thigh.L", knife),
    }


# ---------------------------------------------------------------------------
# Mascot Inker (octopus costume)
# ---------------------------------------------------------------------------

def tentacle(name, a, m, sucker, length=0.55, z0=0.8, r0=0.2):
    """A tapered costume tentacle hanging from the waist ring, curling outward at the tip."""
    c, s = math.cos(a), math.sin(a)
    pts = []
    for k in range(6):
        t = k / 5
        rr = r0 + 0.08 * t + 0.16 * t ** 3
        pts.append((c * rr, s * rr, z0 - length * t + 0.12 * t ** 4))
    parts = [tube(name, pts, 0.075, m=m, segs=8, radius_end=0.025)]
    for k in range(1, 5):
        t = k / 5
        rr = r0 + 0.08 * t + 0.16 * t ** 3 + 0.05
        parts.append(sphere(f"{name}S{k}", 0.022, (c * rr, s * rr, z0 - length * t + 0.12 * t ** 4), m=sucker, segs=6, rings=4))
    return parts


def octo(m):
    p = "O_"
    body, light, dark = m["shirt"], m["octo_light"], m["octo_dark"]
    parts = head_parts(p, 0.58, m)
    # Costume hood: the octopus head sits over the zombie's own head, face showing.
    parts += bind("Head", [
        sphere(p + "Hood", 0.48, (0, 0.2, 2.0), scale=(1.0, 1.05, 1.12), m=body, segs=20, rings=12),
        sphere(p + "HoodSpot1", 0.07, (0.3, -0.05, 2.22), scale=(1, 0.4, 1), m=light, segs=8, rings=5),
        sphere(p + "HoodSpot2", 0.05, (-0.34, 0.05, 2.3), scale=(1, 0.4, 1), m=light, segs=8, rings=5),
        sphere(p + "HoodSpot3", 0.06, (0.05, 0.0, 2.5), scale=(1, 0.5, 1), m=light, segs=8, rings=5),
    ])
    for side in (-1, 1):
        parts += bind("Head", [
            sphere(f"{p}CosEye{side}", 0.13, (side * 0.2, -0.22, 2.14), scale=(1, 0.6, 1.1), m=m["white"], segs=12, rings=8),
            sphere(f"{p}CosPupil{side}", 0.06, (side * 0.2, -0.29, 2.11), scale=(1, 0.5, 1.1), m=m["suit_dark"], segs=8, rings=5),
            sphere(f"{p}CosShine{side}", 0.02, (side * 0.17, -0.32, 2.16), m=m["white"], segs=6, rings=4),
        ])
    parts += bind("Spine", [
        sphere(p + "Torso", 0.42, (0, 0, 1.12), scale=(0.95, 0.75, 0.85), m=body, segs=18, rings=10),
        box(p + "Polo", (0.4, 0.06, 0.34), (0, -0.3, 1.18), bevel=0.04, m=m["polo"]),
        box(p + "Badge", (0.16, 0.03, 0.1), (0.1, -0.335, 1.26), bevel=0.01, m=m["badge"]),
        box(p + "Neck", (0.26, 0.24, 0.12), (0, 0, 1.41), bevel=0.05, m=m["skin"]),
    ])
    parts += bind("Hips", [
        cyl(p + "Skirt", 0.36, 0.3, (0, 0, 0.86), segs=18, bevel=0.08, m=body, radius_top=0.33),
    ])
    for i in range(8):
        a = math.tau * (i + 0.5) / 8
        parts += bind("Hips", tentacle(f"{p}Ten{i}", a, body if i % 2 else dark, m["sucker"]))
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += limb_parts(p, side, m, arm_w=0.19, leg_w=0.2, sleeve=body, shorts=m["polo"], shoe=m["suit_dark"], band=light)
        # Tentacle cuffs on the arms.
        parts += bind(f"ForeArm.{s}", [cyl(f"{p}Cuff{s}", 0.13, 0.12, (side * 0.42, 0, 0.74), segs=12, bevel=0.03, m=body)])
    return parts


def octo_accessories(m):
    p = "OA_"
    return {
        "Acc_Octo_InkSac": bind("Spine", [
            sphere(p + "Sac", 0.15, (0, -0.33, 0.98), scale=(1.1, 0.6, 1.0), m=m["ink"], segs=12, rings=8),
            torus(p + "SacRim", 0.13, 0.025, (0, -0.37, 0.98), rot=rad(90, 0, 0), m=m["octo_dark"], major_segs=16, minor_segs=5),
        ]),
        "Acc_Octo_Lanyard": bind("Spine", [
            tube(p + "Cord", [(-0.12, -0.24, 1.38), (-0.05, -0.33, 1.2), (0.05, -0.34, 1.12)], 0.012, m=m["polo"], segs=5),
            box(p + "Card", (0.1, 0.02, 0.13), (0.05, -0.35, 1.06), bevel=0.01, m=m["white"]),
        ]),
        "Acc_Octo_Bow": bind("Head", [
            sphere(p + "BowL", 0.09, (-0.1, 0.1, 2.56), scale=(1.3, 0.6, 0.9), m=m["badge"], segs=8, rings=5),
            sphere(p + "BowR", 0.09, (0.1, 0.1, 2.56), scale=(1.3, 0.6, 0.9), m=m["badge"], segs=8, rings=5),
            sphere(p + "BowKnot", 0.05, (0, 0.08, 2.56), m=m["badge"], segs=8, rings=5),
        ]),
    }


# ---------------------------------------------------------------------------
# Jelly Head (raincoat kid with a glowing jellyfish hat)
# ---------------------------------------------------------------------------

def jelly(m):
    p = "J_"
    coat, trim = m["shirt"], m["coat_trim"]
    parts = head_parts(p, 0.56, m)
    parts += bind("Spine", [
        box(p + "Coat", (0.56, 0.42, 0.62), (0, 0, 1.1), bevel=0.13, segs=4, m=coat),
        box(p + "CoatHem", (0.6, 0.46, 0.18), (0, 0, 0.84), bevel=0.07, segs=3, m=coat),
        box(p + "Placket", (0.06, 0.04, 0.66), (0, -0.215, 1.02), bevel=0.01, m=trim),
        box(p + "Neck", (0.22, 0.2, 0.12), (0, 0, 1.41), bevel=0.05, m=m["skin"]),
        sphere(p + "Hood", 0.24, (0, 0.22, 1.4), scale=(1.3, 0.8, 0.7), m=coat, segs=12, rings=8),
    ] + [sphere(f"{p}Button{i}", 0.025, (0.07, -0.225, 1.25 - i * 0.14), m=trim, segs=6, rings=4) for i in range(4)])
    parts += bind("Hips", [box(p + "Shorts", (0.52, 0.4, 0.28), (0, 0, 0.84), bevel=0.08, segs=3, m=m["jeans"])])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += limb_parts(p, side, m, arm_w=0.17, leg_w=0.17, sleeve=coat, shorts=m["jeans"], shoe=m["boot"], band=trim)
        lx = side * 0.16
        parts += bind(f"Shin.{s}", [box(f"{p}Boot{s}", (0.24, 0.27, 0.3), (lx, -0.02, 0.2), bevel=0.06, m=m["boot"])])
        parts += bind(f"UpperArm.{s}", [box(f"{p}Sleeve{s}", (0.24, 0.25, 0.3), (side * 0.4, 0, 1.12), bevel=0.07, m=coat)])
    return parts


def jelly_accessories(m):
    p = "JA_"
    hat = [sphere(p + "Bell", 0.4, (0, 0.02, 1.86), scale=(1.0, 1.0, 0.72), m=m["jelly"], segs=20, rings=10),
           torus(p + "Rim", 0.38, 0.05, (0, 0.02, 1.74), m=m["jelly_rim"], major_segs=28, minor_segs=6)]
    for i in range(5):
        a = math.tau * i / 5
        hat.append(sphere(f"{p}Gonad{i}", 0.07, (math.cos(a) * 0.17, 0.02 + math.sin(a) * 0.17, 2.06), scale=(1, 1, 0.5),
                          m=m["jelly_rim"], segs=8, rings=5))
    for i in range(12):
        a = math.tau * i / 12
        if -0.6 < math.sin(a) < 0.0 and abs(math.cos(a)) < 0.6:
            continue        # keep the face clear
        x, y = math.cos(a) * 0.37, 0.02 + math.sin(a) * 0.37
        out = 0.06 * (1 if i % 2 else -1)
        hat.append(tube(f"{p}Ten{i}", [(x, y, 1.74), (x * 1.08 + out, y * 1.08, 1.45), (x * 1.0, y * 1.0 - out, 1.15)],
                        0.022, m=m["jelly_ten"], segs=5, radius_end=0.01))
    return {"Acc_Jelly_Hat": bind("Head", hat)}


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
    save("aqua_zombies", [armature] + meshes, animations=True)


if __name__ == "__main__":
    build()
