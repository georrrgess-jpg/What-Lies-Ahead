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
Shin.L/R); the clips come from zombie_anim.py (punk_clips, courier_clips, riot_clips):
Idle, Walk, Run, Attack, Stagger, Hit_Head, the Die_* variants and Emerge, plus the
extras each behaviour plays: Spray (punk), Crouch and Leap (courier). Each outfit has several faces
(Face_<Outfit>_<Preset>); the game shows one per zombie.

Materials named "Shirt", "Skin" and "SkinDark" are tinted per zombie by the game.
Eyes, piping, soles and visors are emissive so the zombies read against the night.
The character faces -Y in Blender (+Z in Godot).

    python art/blender/build_neon_zombies.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
import zombie_anim  # noqa: E402
from build_zombie import FPS, bind, build_armature, save_zombie, skin  # noqa: E402,F401
from zombie_kit import (HEAD_Y, cap_crown, head_band, arm, band, base_materials, blob, face_y, faces, glass, hair, head, hips, leg, neck,  # noqa: E402
                        patch, skull, tear_fn, torso)


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
        cap_crown(p + "Beanie", w, m["shirt"], rim=1.74, top=2.05),
        head_band(p + "BeanieBand", w, 1.815, 1.72, m["pipe_lime"], off=0.04, thick=0.025),
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
        cap_crown(p + "Helmet", w, white, rim=1.715, top=2.0, off=0.045, segs=28),
        head_band(p + "HelmetBand", w, 1.75, 1.71, pink, off=0.052, thick=0.018),
        box(p + "Visor", (0.48, 0.07, 0.09), (0, fy - 0.06, 1.75), rot=rad(-8, 0, 0), bevel=0.03, m=cyan),
        box(p + "EarCupL", (0.07, 0.17, 0.17), (w * 0.53, HEAD_Y, 1.6), bevel=0.035, m=dark),
        box(p + "EarCupR", (0.07, 0.17, 0.17), (-w * 0.53, HEAD_Y, 1.6), bevel=0.035, m=dark),
        tube(p + "Mic", [(w * 0.52, HEAD_Y - 0.06, 1.55), (w * 0.4, HEAD_Y - 0.2, 1.46), (w * 0.2, face_y(w, 1.43) - 0.06, 1.39)], 0.012,
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
            torus(p + "Scarf", 0.15, 0.05, (0, 0.0, 1.37), rot=rad(24, 0, 0), m=m["pipe_pink"], major_segs=16, minor_segs=6),
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
        cap_crown(p + "HelmetTop", w, suit, rim=1.835, top=2.08, off=0.06, segs=28),
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


def build_one(name, outfit, body, accessories, clips):
    scene = reset_scene()
    scene.render.fps = FPS
    m = materials()
    armature = build_armature()
    meshes = [skin("Outfit_" + outfit, body(m), armature)]
    for acc_name, parts in accessories(m).items():
        meshes.append(skin(acc_name, parts, armature))
    zombie_anim.bake(armature, clips, name)
    save_zombie(name, [armature] + meshes)


def build():
    build_one("neon_punk", "Punk", punk, punk_accessories, zombie_anim.punk_clips)
    build_one("neon_courier", "Courier", courier, courier_accessories, zombie_anim.courier_clips)
    build_one("neon_riot", "Riot", riot, riot_shield, zombie_anim.riot_clips)


if __name__ == "__main__":
    build()
