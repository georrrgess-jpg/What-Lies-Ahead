"""Neon Rooftops zombies: three models on the shared zombie rig contract.

    neon_punk.glb      Outfit_Punk      Neon Punk (spray-tagger): studded jacket with
                                        neon piping, spray can, mohawk / spikes / beanie
    neon_courier.glb   Outfit_Courier   Hover Courier (leaper): high-vis jacket, visor
                                        helmet, delivery box, glowing hover boots
    neon_riot.glb      Outfit_Riot      Riot Bruiser: plated armour, a helmet with a clear
                                        visor (the face shows through) and a big riot
                                        shield (Acc_Riot_Shield, hidden by the game when
                                        the shield breaks)

Bodies, heads and faces come from zombie_kit.py, and the rig and skinning from
build_zombie.py (bone names Hips, Spine, Head, UpperArm.L/R, ForeArm.L/R, Thigh.L/R,
Shin.L/R), with the clip names zombie.gd expects: Idle-loop, Walk-loop, Run-loop,
Attack, Hit, Die. Each model also carries extra clips its behaviour plays: Spray
(punk), Crouch and Leap (courier). Each outfit has several faces
(Face_<Outfit>_<Preset>); the game shows one per zombie.

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
from build_zombie import FPS, bind, build_armature, skin  # noqa: E402,F401
from zombie_kit import (HEAD_Y, arm, band, base_materials, blob, decal, face_y, faces, glass, hair, head, hips, leg, neck,  # noqa: E402
                        patch, skull, tear_fn, torso, wrap)


def materials():
    m = base_materials("neon", skin="#86d69a", skin_dark="#58a874", dark="#17151f", white="#eeeaf4")
    m.update(
        shirt=mat("Shirt", "#ff3fa4", rough=0.6),
        leather=mat("Leather", "#2a2340", rough=0.35, metal=0.2),
        denim=mat("Denim", "#25285a", rough=0.75),
        pipe_cyan=mat("PipingCyan", "#2ef2ff", rough=0.3, emit=3.0),
        pipe_pink=mat("PipingPink", "#ff2fae", rough=0.3, emit=3.0),
        pipe_lime=mat("PipingLime", "#b6ff3a", rough=0.3, emit=2.6),
        hair_pink=mat("HairPink", "#ff3aa8", rough=0.55, emit=0.8),
        hair_cyan=mat("HairCyan", "#36e8ff", rough=0.55, emit=0.8),
        legging=mat("Leggings", "#232042", rough=0.7),
        box=mat("DeliveryBox", "#ff3d7f", rough=0.5),
        box_logo=mat("DeliveryLogo", "#fff36a", rough=0.4, emit=2.4),
        armor=mat("Armor", "#1f2c5c", rough=0.4, metal=0.3),
        stripe=mat("HazardYellow", "#ffcc2e", rough=0.5, emit=0.6),
        riot_led=mat("RiotLed", "#ff4a2e", rough=0.3, emit=3.5),
        visor_glass=glass("RiotVisorGlass", "#7fdcff", alpha=0.3, emit=0.25),
        shield=mat("ShieldPanel", "#2a3f86", rough=0.25, metal=0.4),
        shield_glow=mat("ShieldGlow", "#3af0ff", rough=0.2, emit=3.2),
    )
    return m


# ---------------------------------------------------------------------------
# Neon Punk
# ---------------------------------------------------------------------------

def punk(m):
    """Studded leather jacket with neon piping over a tintable tank, ripped
    jeans, boots with glowing soles, spray can. Eight materials."""
    p = "P_"
    jacket, cyan, pink, white = m["leather"], m["pipe_cyan"], m["pipe_pink"], m["white"]
    parts = head(p, m, 0.58)
    parts += hair(p, 0.58, jacket, "fringe", 5)
    parts += bind("Head", [
        sphere(p + "EarStud", 0.022, (0.31, HEAD_Y + 0.0, 1.5), m=cyan, segs=8, rings=5),
        torus(p + "Hoop", 0.035, 0.01, (-0.31, HEAD_Y + 0.0, 1.47), rot=rad(0, 90, 0), m=white, major_segs=12, minor_segs=5),
    ])
    tor, body = torso(p, m["shirt"], w=0.56, d=0.38, z0=0.92, belly=0.0, hunch=0.05)
    parts += tor
    parts += neck(p, m["skin"], 0.22)
    over = body.shell(p + "Jacket", jacket, 1.42, 0.86, off=0.03, gap=62, tear=tear_fn(24, 5, 1, 0.04), flare=0.02)
    parts += bind("Spine", [over, body.shell(p + "JacketHem", pink, 0.9, 0.87, off=0.05, gap=62, segs=24, steps=1, lip=0.012)])
    lapels, studs = [], []
    for side in (1, -1):
        x = side * 0.11
        lapels += [
            box(f"{p}Lapel{side}", (0.13, 0.05, 0.2), (side * 0.15, body.front(side * 0.15, 1.36) - 0.03, 1.36), rot=rad(-20, side * 30, side * 10),
                bevel=0.02, m=jacket),
            box(f"{p}Pipe{side}", (0.025, 0.03, 0.46), (x, body.front(x, 1.12) - 0.026, 1.12), bevel=0.006, m=cyan),
        ]
        for i in range(4):
            sx, sz = side * (0.17 + 0.03 * (i % 2)), 1.0 + i * 0.1
            studs.append(sphere(f"{p}Stud{side}{i}", 0.02, (sx, body.front(sx, sz, off=0.03) - 0.006, sz), m=white, segs=6, rings=4))
    parts += bind("Spine", lapels + studs + [
        text(p + "BackTag", "VOID", 0.13, 0.02, (0, body.front(0, 1.12, back=True, off=0.035), 1.12), rot=(0, 0, math.pi), m=pink),
    ])
    parts += hips(p, m["denim"], w=0.52, d=0.4, belt=jacket, buckle=pink)
    parts += bind("Hips", [tube(p + "Chain", [(0.12, -0.21, 0.94), (0.2, -0.2, 0.83), (0.26, -0.06, 0.88)], 0.012, m=white, segs=5)])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.17, sleeve=jacket, sleeve_len="long", cuff=cyan, glove=jacket, nail=white, seed=5)
        parts += leg(p, side, m, w=0.17, pants=m["denim"], pants_len="long", foot="boot", shoe=jacket, sole=pink, lace=white, tear=1, seed=6,
                     boot_h=0.16)
        parts += bind(f"Thigh.{s}", [box(f"{p}Rip{s}", (0.1, 0.03, 0.07), (side * 0.17, -0.12, 0.6), bevel=0.02, m=m["skin"])])
        parts += bind(f"Shin.{s}", [box(f"{p}KneeRip{s}", (0.09, 0.03, 0.06), (side * 0.16, -0.108, 0.44), bevel=0.015, m=m["skin"])])
    # Spray can in the right hand, nozzle forward.
    parts += bind("ForeArm.R", [
        cyl(p + "Can", 0.065, 0.26, (-0.44, -0.1, 0.5), segs=12, bevel=0.01, m=white),
        cyl(p + "CanBand", 0.068, 0.08, (-0.44, -0.1, 0.54), segs=12, bevel=0.005, m=pink),
        cyl(p + "CanCap", 0.03, 0.05, (-0.44, -0.1, 0.65), segs=8, bevel=0.005, m=jacket),
        box(p + "Nozzle", (0.03, 0.05, 0.03), (-0.44, -0.135, 0.67), bevel=0.005, m=pink),
    ])
    return parts


def punk_accessories(m):
    p = "PA_"
    w = 0.58
    spikes = []
    for i in range(7):
        y = HEAD_Y - 0.22 + i * 0.075
        h = 0.2 + 0.09 * math.sin(i / 6 * math.pi)
        spikes.append(cyl(f"{p}Mo{i}", 0.05, h, (0, y, 1.87 + h * 0.5 - 0.05), rot=rad(-15 + i * 5, 0, 0), segs=6, bevel=0.0,
                          m=m["hair_pink"], radius_top=0.008))
    acc = {"Acc_Punk_Mohawk": bind("Head", spikes + [
        box(p + "MoBase", (0.1, 0.5, 0.08), (0, HEAD_Y, 1.87), bevel=0.03, m=m["hair_pink"])])}
    liberty = []
    for i in range(9):
        a = math.tau * i / 9
        x, y = math.cos(a) * 0.17, math.sin(a) * 0.15
        liberty.append(cyl(f"{p}Lib{i}", 0.045, 0.24, (x * 1.3, HEAD_Y + y * 1.3, 1.95), rot=(-y * 2.2, x * 2.2, 0),
                           segs=6, bevel=0.0, m=m["hair_cyan"], radius_top=0.006))
    acc["Acc_Punk_Spikes"] = bind("Head", liberty + [
        sphere(p + "LibCap", 0.28, (0, HEAD_Y, 1.8), scale=(1.05, 1.0, 0.5), m=m["hair_cyan"], segs=12, rings=6)])
    acc["Acc_Punk_Beanie"] = bind("Head", [
        sphere(p + "Beanie", 0.32, (0, HEAD_Y + 0.01, 1.82), scale=(1.02, 0.96, 0.75), m=m["shirt"], segs=14, rings=8),
        band(p + "BeanieBand", (0, HEAD_Y, 1.82), (0, HEAD_Y, 1.72), w * 0.53, 0.285, m["pipe_lime"], n=3.3, thick=0.025, segs=24),
        sphere(p + "Pom", 0.07, (0, HEAD_Y + 0.02, 2.06), m=m["pipe_pink"], segs=8, rings=5),
    ])
    fy = face_y(w, 1.645)
    acc["Acc_Punk_Visor"] = bind("Head", [
        box(p + "VisorBar", (0.58, 0.05, 0.09), (0, fy - 0.055, 1.645), bevel=0.02, m=m["pipe_cyan"]),
        box(p + "VisorArmL", (0.03, 0.28, 0.03), (0.3, HEAD_Y - 0.1, 1.65), bevel=0.008, m=m["leather"]),
        box(p + "VisorArmR", (0.03, 0.28, 0.03), (-0.3, HEAD_Y - 0.1, 1.65), bevel=0.008, m=m["leather"]),
    ])
    acc["Acc_Punk_Chain"] = bind("Spine", [
        tube(p + "Necklace", [(-0.12, -0.17, 1.4), (-0.08, -0.23, 1.28), (0.0, -0.245, 1.24), (0.08, -0.23, 1.28), (0.12, -0.17, 1.4)],
             0.014, m=m["white"], segs=5),
        box(p + "Padlock", (0.06, 0.03, 0.07), (0, -0.255, 1.2), bevel=0.01, m=m["pipe_cyan"]),
    ])
    acc.update(faces("Punk", m, w, ("Snarl", "Grin", "Derp", "Clench"), tongue=m["pipe_pink"]))
    return acc


# ---------------------------------------------------------------------------
# Hover Courier
# ---------------------------------------------------------------------------

def courier(m):
    """High-vis jacket ("Shirt") with reflective bands, visor helmet, leggings,
    hover boots with glowing thrusters. Eight materials."""
    p = "C_"
    w = 0.52
    jacket, white, dark, cyan, pink = m["shirt"], m["white"], m["dark"], m["pipe_cyan"], m["pipe_pink"]
    parts = head(p, m, w)
    fy = face_y(w, 1.74)
    parts += bind("Head", [
        sphere(p + "Helmet", 0.31, (0, HEAD_Y + 0.02, 1.76), scale=(1.0, 1.1, 0.8), m=white, segs=18, rings=9),
        torus(p + "HelmetBand", 0.305, 0.022, (0, HEAD_Y + 0.02, 1.72), m=pink, major_segs=26, minor_segs=5),
        box(p + "Visor", (0.48, 0.07, 0.09), (0, fy - 0.06, 1.75), rot=rad(-8, 0, 0), bevel=0.03, m=cyan),
        box(p + "EarCupL", (0.07, 0.17, 0.17), (w * 0.53, HEAD_Y, 1.6), bevel=0.035, m=dark),
        box(p + "EarCupR", (0.07, 0.17, 0.17), (-w * 0.53, HEAD_Y, 1.6), bevel=0.035, m=dark),
        tube(p + "Mic", [(w * 0.52, HEAD_Y - 0.06, 1.55), (w * 0.4, HEAD_Y - 0.2, 1.46), (w * 0.12, face_y(w, 1.43) - 0.03, 1.42)], 0.012,
             m=dark, segs=5),
    ])
    tor, body = torso(p, jacket, w=0.54, d=0.38, z0=0.88, hunch=0.04, hem=jacket, hem_tear=0)
    parts += tor
    parts += neck(p, m["skin"], 0.2)
    parts += bind("Spine", [
        body.shell(p + "StripeChest", white, 1.24, 1.19, off=0.012, segs=24, steps=1, lip=0.008),
        body.shell(p + "StripeWaist", white, 1.02, 0.97, off=0.012, segs=24, steps=1, lip=0.008),
        patch(p + "Zip", tor[0], (0, body.front(0, 1.12), 1.12), (0.03, 0.03, 0.5), dark, bevel=0.005),
        band(p + "Collar", (0, 0.0, 1.45), (0, 0.0, 1.36), 0.16, 0.15, dark, n=2.6, thick=0.025, flare=0.02, segs=20),
    ] + [box(f"{p}Strap{side}", (0.06, 0.42, 0.54), (side * 0.15, 0.01, 1.16), bevel=0.02, m=dark) for side in (1, -1)])
    parts += hips(p, dark, w=0.5, d=0.38, belt=dark, buckle=pink)
    parts += bind("Hips", [box(p + "Pouch", (0.16, 0.08, 0.12), (0.13, -0.21, 0.9), bevel=0.03, m=pink)])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        lx = side * 0.16
        parts += arm(p, side, m, w=0.15, sleeve=jacket, sleeve_len="long", cuff=white, glove=dark, nail=white, seed=7)
        parts += bind(f"UpperArm.{s}", [band(f"{p}ArmStripe{s}", (side * 0.39, 0, 1.13), (side * 0.395, 0, 1.08), 0.09, 0.09, white, n=2.6,
                                             thick=0.015, segs=16)])
        parts += leg(p, side, m, w=0.15, pants=m["legging"], pants_len="long", foot="boot", shoe=dark, sole=dark, lace=pink, knee_m=white,
                     boot_h=0.2, tear=0)
        parts += bind(f"Shin.{s}", [
            cyl(f"{p}Thruster{s}", 0.1, 0.05, (lx, -0.07, 0.0), segs=16, bevel=0.01, m=cyan),
            torus(f"{p}ThrusterRing{s}", 0.13, 0.025, (lx, -0.07, 0.015), m=dark, major_segs=18, minor_segs=5),
            box(f"{p}Fin{s}", (0.03, 0.18, 0.12), (lx + side * 0.12, 0.06, 0.18), bevel=0.01, m=jacket),
        ])
    return parts


def courier_accessories(m):
    p = "CA_"
    acc = {
        "Acc_Courier_Box": bind("Spine", [
            box(p + "Box", (0.5, 0.36, 0.48), (0, 0.4, 1.12), bevel=0.05, segs=2, m=m["box"]),
            box(p + "BoxLid", (0.52, 0.38, 0.05), (0, 0.4, 1.37), bevel=0.02, m=m["dark"]),
            text(p + "Logo", "BLINK", 0.12, 0.02, (0, 0.585, 1.13), rot=(0, 0, math.pi), m=m["box_logo"]),
            box(p + "LogoBar", (0.36, 0.02, 0.03), (0, 0.585, 1.04), bevel=0.0, m=m["box_logo"]),
        ]),
        "Acc_Courier_Antenna": bind("Spine", [
            cyl(p + "Whip", 0.01, 0.6, (0.2, 0.48, 1.65), rot=rad(-12, 0, 0), segs=5, bevel=0.0, m=m["dark"]),
            sphere(p + "Tip", 0.035, (0.2, 0.54, 1.95), m=m["pipe_cyan"], segs=8, rings=5),
        ]),
        "Acc_Courier_Scarf": bind("Spine", [
            torus(p + "Scarf", 0.15, 0.05, (0, 0.0, 1.4), m=m["pipe_pink"], major_segs=16, minor_segs=6),
            box(p + "ScarfTail", (0.1, 0.05, 0.3), (0.08, 0.18, 1.28), rot=rad(25, 10, 0), bevel=0.02, m=m["pipe_pink"]),
        ]),
        "Acc_Courier_Goggles": bind("Head", [
            band(p + "GoggleBand", (0, HEAD_Y, 1.93), (0, HEAD_Y, 1.88), 0.31, 0.33, m["dark"], n=2.6, thick=0.015, segs=24),
            sphere(p + "GoggleL", 0.07, (-0.1, HEAD_Y - 0.3, 1.92), scale=(1.2, 0.6, 1.0), m=m["pipe_lime"], segs=10, rings=6),
            sphere(p + "GoggleR", 0.07, (0.1, HEAD_Y - 0.3, 1.92), scale=(1.2, 0.6, 1.0), m=m["pipe_lime"], segs=10, rings=6),
        ]),
    }
    acc.update(faces("Courier", m, 0.52, ("Grin", "Gape", "Snarl"), tongue=m["pipe_pink"]))
    return acc


# ---------------------------------------------------------------------------
# Riot Bruiser
# ---------------------------------------------------------------------------

def riot(m):
    """Plated riot armour (the plates are "Shirt", tinted per zombie), a helmet
    with a clear visor over the face, baton. Eight materials."""
    p = "R_"
    w = 0.62
    suit, plate, dark, led, stripe = m["armor"], m["shirt"], m["dark"], m["riot_led"], m["stripe"]
    parts = head(p, m, w, ears=False)
    sk = skull(w)
    fy = face_y(w, 1.6)
    parts += bind("Head", [
        sk.shell(p + "Helmet", suit, 1.96, 1.44, off=0.06, gap=118, segs=28, steps=6, lip=0.04),
        sphere(p + "HelmetTop", 0.37, (0, HEAD_Y + 0.02, 1.86), scale=(1.0, 1.02, 0.6), m=suit, segs=18, rings=9),
        box(p + "HelmetRidge", (0.09, 0.62, 0.07), (0, HEAD_Y + 0.02, 2.06), bevel=0.025, m=plate),
        # Clear visor: the zombie's face shows through.
        dome_visor(p, w, m["visor_glass"]),
        box(p + "VisorTop", (0.62, 0.08, 0.06), (0, fy - 0.09, 1.82), bevel=0.025, m=dark),
        box(p + "VisorLed", (0.44, 0.085, 0.025), (0, fy - 0.093, 1.82), bevel=0.0, m=led),
        box(p + "HingeL", (0.06, 0.12, 0.12), (w * 0.56, HEAD_Y - 0.12, 1.72), bevel=0.025, m=plate),
        box(p + "HingeR", (0.06, 0.12, 0.12), (-w * 0.56, HEAD_Y - 0.12, 1.72), bevel=0.025, m=plate),
        box(p + "ChinGuard", (0.4, 0.1, 0.08), (0, fy - 0.06, 1.3), bevel=0.03, m=dark),
    ])
    tor, body = torso(p, suit, w=0.86, d=0.54, z0=0.9, z1=1.46, waist=0.88, belly=0.04, hunch=0.05, chest=1.03)
    parts += tor
    parts += neck(p, dark, 0.34, z1=1.46)
    plates = [
        body.shell(p + "ChestPlate", plate, 1.4, 1.17, off=0.035, gap=170, gap_at=180, segs=28, steps=3, lip=0.03),
        body.shell(p + "AbPlate", plate, 1.14, 0.98, off=0.03, gap=200, gap_at=180, segs=28, steps=2, lip=0.025),
        body.shell(p + "BackPlate", plate, 1.4, 1.02, off=0.035, gap=190, segs=28, steps=3, lip=0.03),
        box(p + "ChestLed", (0.36, 0.03, 0.035), (0, body.front(0, 1.33, off=0.04) - 0.012, 1.33), bevel=0.0, m=led),
        text(p + "BackText", "SECURITY", 0.085, 0.015, (0, body.front(0, 1.22, back=True, off=0.045), 1.22), rot=(0, 0, math.pi), m=stripe),
        band(p + "Collar", (0, 0.02, 1.5), (0, 0.02, 1.4), 0.26, 0.22, plate, n=2.6, thick=0.03, flare=0.03, segs=22),
    ]
    for side in (1, -1):
        plates += [
            sphere(f"{p}Pad{side}", 0.23, (side * 0.45, 0.0, 1.32), scale=(1.1, 1.0, 0.66), m=plate, segs=16, rings=8),
            sphere(f"{p}PadLow{side}", 0.2, (side * 0.5, 0.0, 1.22), scale=(1.05, 1.0, 0.55), m=suit, segs=14, rings=7),
            box(f"{p}PadStripe{side}", (0.22, 0.38, 0.045), (side * 0.48, 0, 1.4), rot=rad(0, -side * 12, 0), bevel=0.012, m=stripe),
        ]
    parts += bind("Spine", plates)
    parts += hips(p, suit, w=0.76, d=0.52, belt=dark, belt_z=0.965)
    parts += bind("Hips", [
        box(p + "PouchL", (0.16, 0.1, 0.14), (0.25, -0.28, 0.93), bevel=0.03, m=dark),
        box(p + "PouchR", (0.16, 0.1, 0.14), (-0.25, -0.28, 0.93), bevel=0.03, m=dark),
        box(p + "BeltLed", (0.1, 0.02, 0.04), (0, -0.28, 0.965), bevel=0.0, m=led),
    ] + [box(f"{p}Tasset{side}", (0.2, 0.06, 0.2), (side * 0.2, -0.27, 0.84), rot=rad(8, 0, -side * 6), bevel=0.03, m=plate) for side in (1, -1)])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        lx = side * 0.16
        parts += arm(p, side, m, w=0.24, sleeve=suit, sleeve_len="long", cuff=stripe, glove=dark, hand=0.07, out=0.08, nail=dark, seed=9)
        parts += bind(f"ForeArm.{s}", [
            blob(f"{p}Gauntlet{s}", (side * 0.505, -0.01, 0.94), (side * 0.52, -0.02, 0.7), [(0, 0.13, 0.12), (0.5, 0.15, 0.14), (1, 0.13, 0.12)],
                 plate, n=3.0, r0=0.04, r1=0.04, segs=16, mid=3),
            sphere(f"{p}ElbowPad{s}", 0.11, (side * 0.49, 0.03, 0.98), scale=(1.0, 1.0, 0.85), m=plate, segs=12, rings=7),
        ])
        parts += leg(p, side, m, w=0.24, pants=suit, pants_len="long", foot="boot", shoe=dark, sole=dark, lace=stripe, knee_m=plate,
                     boot_h=0.24, tear=0)
        parts += bind(f"Shin.{s}", [blob(f"{p}ShinGuard{s}", (lx, -0.07, 0.42), (lx, -0.06, 0.18), [(0, 0.12, 0.06), (0.5, 0.13, 0.065), (1, 0.11, 0.05)],
                                         plate, n=3.0, r0=0.03, r1=0.03, segs=16, mid=3)])
        parts += bind(f"Thigh.{s}", [box(f"{p}ThighPlate{s}", (0.14, 0.05, 0.2), (lx + side * 0.04, -0.16, 0.64), rot=rad(0, 0, -side * 8),
                                         bevel=0.025, m=plate)])
    parts += bind("ForeArm.R", [
        cyl(p + "Baton", 0.035, 0.62, (-0.52, -0.12, 0.56), rot=rad(70, 0, 0), segs=8, bevel=0.01, m=dark),
        cyl(p + "BatonTip", 0.04, 0.12, (-0.52, -0.4, 0.66), rot=rad(70, 0, 0), segs=8, bevel=0.01, m=led),
    ])
    return parts


def dome_visor(p, w, m):
    """The riot helmet's clear visor: a curved glass shield over the face."""
    sk = skull(w)
    return sk.shell(p + "Visor", m, 1.8, 1.32, off=0.085, gap=230, gap_at=180, segs=28, steps=6, lip=0.0)


def riot_shield(m):
    """The riot shield (always on), plus helmet and kit options for variety."""
    p = "RS_"
    # Top edge at ~1.75 m once scaled: the visor stays visible as a headshot target.
    y = -0.66
    zc = 0.9
    parts = [
        box(p + "Panel", (0.86, 0.08, 1.16), (0.05, y, zc), bevel=0.06, segs=2, m=m["shield"]),
        box(p + "Window", (0.56, 0.09, 0.2), (0.05, y - 0.005, zc + 0.36), bevel=0.03, m=m["visor_glass"]),
        text(p + "Text", "RIOT", 0.2, 0.03, (0.05, y - 0.05, zc - 0.05), m=m["white"]),
        box(p + "Stripe", (0.7, 0.09, 0.06), (0.05, y - 0.006, zc - 0.25), bevel=0.01, m=m["stripe"]),
        box(p + "Handle", (0.1, 0.18, 0.1), (0.2, y + 0.12, zc), bevel=0.02, m=m["dark"]),
    ]
    for i, (sx, sz, lx, lz) in enumerate(((0.92, 0.05, 0.05, zc + 0.59), (0.92, 0.05, 0.05, zc - 0.59),
                                          (0.05, 1.2, -0.41, zc), (0.05, 1.2, 0.51, zc))):
        parts.append(box(f"{p}Rim{i}", (sx, 0.1, sz), (lx, y, lz), bevel=0.015, m=m["shield_glow"]))
    pa = "RA_"
    acc = {
        "Acc_Riot_Shield": bind("Spine", parts),
        "Acc_Riot_Crest": bind("Head", [box(pa + "Crest", (0.06, 0.5, 0.12), (0, HEAD_Y, 2.11), bevel=0.025, m=m["riot_led"])]),
        "Acc_Riot_Lamp": bind("Spine", [
            cyl(pa + "Lamp", 0.07, 0.1, (0.42, -0.12, 1.42), rot=rad(80, 0, 0), segs=12, bevel=0.015, m=m["dark"]),
            cyl(pa + "LampLens", 0.06, 0.02, (0.42, -0.18, 1.41), rot=rad(80, 0, 0), segs=12, bevel=0.0, m=m["shield_glow"]),
        ]),
        "Acc_Riot_Radio": bind("Spine", [
            box(pa + "Radio", (0.09, 0.06, 0.17), (-0.2, -0.33, 1.25), bevel=0.015, m=m["dark"]),
            cyl(pa + "Aerial", 0.012, 0.16, (-0.22, -0.33, 1.4), segs=6, bevel=0.0, m=m["dark"]),
            box(pa + "RadioLed", (0.035, 0.065, 0.025), (-0.2, -0.33, 1.3), bevel=0.0, m=m["riot_led"]),
        ]),
        "Acc_Riot_Cuffs": bind("Hips", [
            torus(pa + "CuffA", 0.05, 0.012, (-0.33, -0.12, 0.92), rot=rad(0, 90, 0), m=m["white"], major_segs=12, minor_segs=4),
            torus(pa + "CuffB", 0.05, 0.012, (-0.33, -0.06, 0.88), rot=rad(0, 90, 0), m=m["white"], major_segs=12, minor_segs=4),
        ]),
    }
    acc.update(faces("Riot", m, 0.62, ("Snarl", "Clench", "Grin")))
    return acc


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
