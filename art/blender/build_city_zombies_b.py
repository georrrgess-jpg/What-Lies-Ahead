"""Ashfall City zombies (Endless mode), part 2: the districts' specials and the
boss, on the shared rig (build_zombie.py).

zombie_city_special.glb (three outfits):

    Outfit_Cop       Riot Shield (Precinct 9): a riot cop in a tintable tactical
                     vest ("Shirt") over a navy uniform, helmet with the visor
                     up, knee pads; a tall clear riot shield with a police light
                     bar on its rim (Acc_Cop_Shield, the head guard), a baton;
                     options: a gas mask, a shoulder radio, a helmet light
    Outfit_Crawler   Tunnel Crawler (Metro Line): a starved, long-limbed metro
                     track worker in torn tintable overalls, ribs showing, long
                     claws; a cracked head lamp (Acc_Crawler_Lamp) or goggles
    Outfit_Firebug   Firebug (Neon Market): a scorched street arsonist in a
                     tintable hoodie, a bandolier of lit bottles, ripped jeans;
                     the bottle it throws (Acc_Firebug_Bottle, shown by the
                     game during the wind-up), welding goggles, a jerry can

zombie_city_wrecker.glb:

    Outfit_Wrecker   The Wrecker (the boss): a hulking demolition brute in a hi-vis
                     harness, a dented hard hat with an amber beacon
                     (Acc_Wrecker_Hat), two exhaust stacks on its back, a
                     wrecking ball chained to the right fist (Acc_Wrecker_Ball)
                     and a bulldozer blade strapped to the left forearm
                     (Acc_Wrecker_Blade)

Clips: the Cop's shielded stomp, rush and baton bash, "Drum" (baton on the
shield: the bash telegraph) and "Recover" (shield swung wide after a bash);
the Crawler's own scuttle (style "Crawler": Walk/Run/Idle/Attack/Crouch/Leap and
deaths from the ground); the Firebug's "Throw_Bottle"; the Wrecker's stomp,
charge, slam, roar, heave ("Throw") and "Swing" (the wrecking-ball sweep).

    python art/blender/build_city_zombies_b.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
import build_zombie as bz  # noqa: E402
import zombie_anim  # noqa: E402
from zombie_anim import (Gait, _cs, _legs, attack, attack_heavy, attack_riot, charge, deaths, elbow_pole, emerge,  # noqa: E402
                         feet, flail_sprint, gait, hit_head, idle, keyed, ready, riot_charge, riot_stomp, roar, stagger, stomp,
                         swagger, throw)
from zombie_kit import (HEAD_Y, SPARK_EYE, arm, band, base_materials, blob, cap_crown, decal, face_y, faces, glass, hair,  # noqa: E402
                        hair_top, head, head_band, hips, leg, neck, patch, skull, torso)

FPS = zombie_anim.FPS


def materials():
    m = base_materials("city", skin="#9cc46c", skin_dark="#66903f", dark="#1d1b24", white="#f3f0ea", eye=(SPARK_EYE, 2.8))
    m.update(
        shirt=mat("Shirt", "#2c3550", rough=0.6),
        navy=mat("CityZNavy", "#1f2a4a", rough=0.65),
        black=mat("CityZBlack", "#25232b", rough=0.6),
        gold=mat("CityZGold", "#f2c14a", rough=0.35, metal=0.5),
        police_red=mat("CityZPoliceRed", "#ff2a3c", rough=0.3, emit=4.0),
        police_blue=mat("CityZPoliceBlue", "#2a6cff", rough=0.3, emit=4.0),
        shield_glass=glass("CityZShieldGlass", "#b8e2ff", alpha=0.28, emit=0.12),
        visor_glass=glass("CityZVisorGlass", "#9fd8ff", alpha=0.3, emit=0.2),
        steel=mat("CityZSteel", "#9a9aa6", rough=0.35, metal=0.7),
        steel_dark=mat("CityZSteelDark", "#4a4a56", rough=0.45, metal=0.6),
        iron=mat("CityZIron", "#2e2c34", rough=0.5, metal=0.5),
        rust=mat("CityZRust", "#a0522d", rough=0.8),
        soot=mat("CityZSoot", "#2a2622", rough=0.95),
        ash=mat("CityZAsh", "#8d8a86", rough=0.95),
        ember=mat("CityZEmber", "#ff6a1f", rough=0.4, emit=2.6),
        flame=mat("CityZFlame", "#ffb43a", rough=0.3, emit=5.0),
        lamp=mat("CityZLamp", "#d8ffcf", rough=0.3, emit=4.5),
        amber=mat("CityZAmber", "#ffa21a", rough=0.3, emit=4.5),
        hivis=mat("CityZHiVis", "#d4f02a", rough=0.5, emit=0.25),
        orange=mat("CityZOrange", "#ff7a1a", rough=0.5),
        reflect=mat("CityZReflect", "#e9edf2", rough=0.25, metal=0.4, emit=0.35),
        hat=mat("CityZHardHat", "#ffc21a", rough=0.35),
        hazard=mat("CityZHazard", "#ffcf1f", rough=0.45),
        denim=mat("CityZDenim", "#3a5a8c", rough=0.75),
        cargo=mat("CityZCargo", "#5b5640", rough=0.75),
        leather=mat("CityZLeather", "#5a3622", rough=0.6),
        boot=mat("CityZBoot", "#3a2a22", rough=0.7),
        bottle=mat("CityZBottle", "#4fae5a", rough=0.15, emit=0.2),
        rag=mat("CityZRag", "#e8dcc0", rough=0.9),
        can_red=mat("CityZCanRed", "#d8303a", rough=0.45),
        red=mat("CityZRed", "#e2343f", rough=0.6),
        magenta=mat("CityZMagenta", "#ff3e9a", rough=0.45),
        cyan=mat("CityZCyan", "#20c6d8", rough=0.45),
        lens=mat("CityZGoggleLens", "#4ee6c8", rough=0.15, emit=0.8),
        bone=mat("CityZBone", "#e9e2cc", rough=0.6),
    )
    return m


def soot_marks(p, body, target, m, seed, count=6, z=(0.95, 1.38), back=False):
    """Ash and soot smudges laid on a garment shell (the city burns)."""
    rng = random.Random(seed)
    parts = []
    for i in range(count):
        zz = rng.uniform(*z)
        x = rng.uniform(-0.26, 0.26) * body.w / 0.62
        parts.append(decal(f"{p}Soot{i}", target, (x, body.front(x, zz, back=back), zz), rng.uniform(0.04, 0.07),
                           m["soot"] if i % 3 else m["ash"], squash=rng.uniform(0.55, 0.95)))
    return parts


# ---------------------------------------------------------------------------
# Riot Shield (Precinct 9)
# ---------------------------------------------------------------------------

def cop(m):
    p = "P_"
    w = 0.6
    vest, navy, dark = m["shirt"], m["navy"], m["black"]
    parts = head(p, m, w, ears=False)
    sk = skull(w)
    fy = face_y(w, 1.6)
    parts += bz.bind("Head", [
        sk.shell(p + "Helmet", dark, 1.96, 1.5, off=0.06, gap=120, segs=28, steps=6, lip=0.04),
        cap_crown(p + "HelmetTop", w, dark, rim=1.835, top=2.07, off=0.06, segs=28),
        # The visor is up: a clear shield folded onto the helmet's brow.
        box(p + "VisorUp", (0.6, 0.2, 0.04), (0, fy - 0.02, 1.98), rot=rad(-62, 0, 0), bevel=0.02, m=m["visor_glass"]),
        box(p + "VisorRim", (0.62, 0.05, 0.05), (0, fy + 0.02, 2.04), rot=rad(-62, 0, 0), bevel=0.015, m=dark),
        box(p + "HelmetBand", (0.18, 0.04, 0.06), (0, fy - 0.07, 1.86), bevel=0.012, m=m["police_blue"]),
        text(p + "HelmetNo", "9", 0.12, 0.02, (0, HEAD_Y + 0.33, 1.86), rot=(0, 0, math.pi), m=m["white"]),
        box(p + "ChinStrapL", (0.025, 0.04, 0.22), (w * 0.47, HEAD_Y - 0.08, 1.5), bevel=0.0, m=dark),
        box(p + "ChinStrapR", (0.025, 0.04, 0.22), (-w * 0.47, HEAD_Y - 0.08, 1.5), bevel=0.0, m=dark),
    ])
    tor, body = torso(p, navy, w=0.8, d=0.52, z0=0.88, z1=1.46, waist=0.88, belly=0.05, hunch=0.05, chest=1.03)
    parts += tor
    parts += neck(p, navy, 0.32, z1=1.46)
    plates = [
        body.shell(p + "Vest", vest, 1.42, 0.96, off=0.035, gap=0, segs=28, steps=4, lip=0.03),
        body.shell(p + "VestTrim", m["police_blue"], 1.43, 1.4, off=0.04, segs=28, steps=1, lip=0.012),
        text(p + "BackText", "POLICE", 0.11, 0.02, (0, body.front(0, 1.24, back=True, off=0.05), 1.24), rot=(0, 0, math.pi), m=m["white"]),
        text(p + "FrontText", "POLICE", 0.06, 0.015, (0.13, body.front(0.13, 1.33, off=0.045), 1.33), m=m["white"]),
        star(p + "Badge", 0.055, 0.02, (-0.15, body.front(-0.15, 1.3, off=0.04) - 0.005, 1.3), rot=rad(90, 0, 0), m=m["gold"]),
        box(p + "PouchA", (0.12, 0.07, 0.12), (0.12, body.front(0.12, 1.06, off=0.05), 1.06), bevel=0.02, m=dark),
        box(p + "PouchB", (0.12, 0.07, 0.12), (-0.12, body.front(-0.12, 1.06, off=0.05), 1.06), bevel=0.02, m=dark),
    ]
    for side in (1, -1):
        plates += [
            sphere(f"{p}Pad{side}", 0.21, (side * 0.43, 0.0, 1.32), scale=(1.1, 1.0, 0.66), m=dark, segs=16, rings=8),
            box(f"{p}PadStripe{side}", (0.2, 0.36, 0.04), (side * 0.46, 0, 1.39), rot=rad(0, -side * 12, 0), bevel=0.012, m=m["police_blue"]),
        ]
    plates += soot_marks(p, body, plates[0], m, 61, count=4)
    parts += bz.bind("Spine", plates)
    parts += hips(p, navy, w=0.72, d=0.5, belt=dark, buckle=m["gold"], belt_z=0.965)
    parts += bz.bind("Hips", [
        box(p + "Cuffs", (0.12, 0.08, 0.1), (0.3, -0.18, 0.93), bevel=0.02, m=m["steel"]),
        box(p + "Holster", (0.1, 0.12, 0.2), (-0.36, -0.06, 0.86), bevel=0.025, m=dark),
    ])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.22, sleeve=navy, sleeve_len="long", cuff=dark, glove=dark, hand=0.06, out=0.06, nail=dark, seed=63)
        parts += leg(p, side, m, w=0.22, pants=navy, pants_len="long", foot="boot", shoe=dark, sole=dark, lace=dark, knee_m=dark,
                     boot_h=0.26, tear=0)
        parts += bz.bind(f"Shin.{s}", [box(f"{p}KneePad{s}", (0.17, 0.08, 0.16), (side * 0.16, -0.13, 0.45), bevel=0.04, m=dark)])
    parts += bz.bind("ForeArm.R", [
        cyl(p + "Baton", 0.035, 0.62, (-0.5, -0.14, 0.56), rot=rad(70, 0, 0), segs=8, bevel=0.01, m=dark),
        cyl(p + "BatonGrip", 0.045, 0.06, (-0.48, -0.0, 0.6), rot=rad(70, 0, 0), segs=8, bevel=0.0, m=m["steel"]),
    ])
    return parts


def cop_shield(m):
    """The tall clear riot shield, held in front (bound to the spine like the
    Riot Bruiser's, so its top edge is the head guard): black frame, POLICE
    across it, a red and blue light bar along the top rim."""
    p = "PS_"
    y = -0.64
    zc = 0.93
    hw, hh = 0.46, 0.62     # half width, half height: top edge ~1.55 m before scale
    parts = [
        box(p + "Panel", (hw * 2, 0.05, hh * 2), (0.05, y, zc), bevel=0.04, segs=2, m=m["shield_glass"]),
        text(p + "Text", "POLICE", 0.15, 0.025, (0.05, y - 0.04, zc + 0.18), m=m["white"]),
        box(p + "TextBand", (hw * 2 - 0.08, 0.03, 0.2), (0.05, y - 0.012, zc + 0.2), bevel=0.0, m=m["black"]),
        box(p + "Handle", (0.1, 0.18, 0.1), (0.2, y + 0.12, zc), bevel=0.02, m=m["black"]),
        box(p + "Scuff", (0.2, 0.06, 0.14), (-0.18, y - 0.01, zc - 0.32), rot=rad(0, 20, 0), bevel=0.03, m=m["soot"]),
    ]
    rims = ((hw * 2 + 0.06, 0.05, 0.05, zc - hh), (0.05, hh * 2, 0.05 - hw, zc), (0.05, hh * 2, 0.05 + hw, zc))
    for i, (sx, sz, lx, lz) in enumerate(rims):
        parts.append(box(f"{p}Rim{i}", (sx, 0.08, sz), (lx, y, lz), bevel=0.015, m=m["black"]))
    # The light bar: the top rim, half red, half blue, with a black housing.
    parts += [
        box(p + "Bar", (hw * 2 + 0.06, 0.1, 0.07), (0.05, y, zc + hh), bevel=0.02, m=m["black"]),
        box(p + "BarRed", (hw - 0.04, 0.11, 0.055), (0.05 + hw * 0.5, y - 0.005, zc + hh + 0.01), bevel=0.015, m=m["police_red"]),
        box(p + "BarBlue", (hw - 0.04, 0.11, 0.055), (0.05 - hw * 0.5, y - 0.005, zc + hh + 0.01), bevel=0.015, m=m["police_blue"]),
    ]
    pa = "PA_"
    w = 0.6
    acc = {
        "Acc_Cop_Shield": bz.bind("Spine", parts),
        "Acc_Cop_Mask": bz.bind("Head", [
            sphere(pa + "Mask", 0.2, (0, face_y(w, 1.45) - 0.02, 1.45), scale=(1.15, 0.6, 0.85), m=m["black"], segs=16, rings=8),
            cyl(pa + "Canister", 0.07, 0.1, (0.0, face_y(w, 1.4) - 0.15, 1.38), rot=rad(80, 0, 0), segs=12, bevel=0.015, m=m["steel_dark"]),
            cyl(pa + "CanisterCap", 0.06, 0.02, (0.0, face_y(w, 1.4) - 0.2, 1.37), rot=rad(80, 0, 0), segs=12, bevel=0.0, m=m["police_blue"]),
            torus(pa + "EyeL", 0.07, 0.014, (0.13, face_y(w, 1.6) - 0.05, 1.6), rot=rad(90, 0, 0), m=m["black"], major_segs=12, minor_segs=4),
            torus(pa + "EyeR", 0.07, 0.014, (-0.13, face_y(w, 1.6) - 0.05, 1.6), rot=rad(90, 0, 0), m=m["black"], major_segs=12, minor_segs=4),
        ]),
        "Acc_Cop_Radio": bz.bind("Spine", [
            box(pa + "Radio", (0.09, 0.06, 0.17), (-0.22, -0.3, 1.36), bevel=0.015, m=m["black"]),
            cyl(pa + "Aerial", 0.012, 0.16, (-0.24, -0.3, 1.5), segs=6, bevel=0.0, m=m["black"]),
            box(pa + "RadioLed", (0.035, 0.065, 0.025), (-0.22, -0.33, 1.4), bevel=0.0, m=m["police_red"]),
        ]),
        "Acc_Cop_Lamp": bz.bind("Head", [
            cyl(pa + "Lamp", 0.05, 0.1, (w * 0.5, HEAD_Y - 0.08, 1.86), rot=rad(80, 0, 0), segs=10, bevel=0.012, m=m["black"]),
            cyl(pa + "LampLens", 0.042, 0.02, (w * 0.5, HEAD_Y - 0.14, 1.85), rot=rad(80, 0, 0), segs=10, bevel=0.0, m=m["lamp"]),
        ]),
    }
    acc.update(faces("Cop", m, w, ("Snarl", "Clench", "Gape")))
    return acc


# ---------------------------------------------------------------------------
# Tunnel Crawler (Metro Line)
# ---------------------------------------------------------------------------

def crawler(m):
    p = "T_"
    w = 0.52
    overalls = m["shirt"]
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "mop", 71)
    tor, body = torso(p, m["skin"], w=0.46, d=0.32, z0=0.9, waist=0.74, hunch=0.09, n=2.8)
    parts += tor
    parts += neck(p, m["skin"], 0.18)
    t = tor[0]
    ribs = []
    for side in (1, -1):
        for i in range(3):
            z = 1.14 + i * 0.075
            pts = [(side * x, 0, z - 0.03 * x) for x in (0.05, 0.11, 0.17)]
            ribs.append(tube(f"{p}Rib{side}{i}", [(x, body.front(x, zz) + 0.004, zz) for x, _, zz in pts], 0.011, m=m["skin_dark"], segs=5))
    # Torn overall bib and straps over the bare, starved chest.
    ribs += [
        patch(p + "Bib", t, (0, body.front(0, 1.02), 1.02), (0.3, 0.04, 0.24), overalls, bevel=0.012),
        box(p + "BibPocket", (0.12, 0.03, 0.08), (0.0, body.front(0, 1.05) - 0.02, 1.06), bevel=0.01, m=m["reflect"]),
        box(p + "StrapL", (0.05, 0.4, 0.04), (0.11, -0.02, 1.3), rot=rad(-12, 0, 0), bevel=0.01, m=overalls),
        box(p + "StrapR", (0.05, 0.4, 0.04), (-0.11, -0.02, 1.3), rot=rad(-12, 0, 0), bevel=0.01, m=overalls),
        box(p + "BuckleL", (0.06, 0.03, 0.05), (0.11, body.front(0.11, 1.19) - 0.02, 1.19), bevel=0.0, m=m["steel"]),
        box(p + "BuckleR", (0.06, 0.03, 0.05), (-0.11, body.front(-0.11, 1.19) - 0.02, 1.19), bevel=0.0, m=m["steel"]),
    ]
    ribs += soot_marks(p, body, t, m, 71, count=5, z=(0.95, 1.3))
    # A ridge of knobbly spine down the hunched back.
    for i in range(5):
        z = 0.98 + i * 0.09
        ribs.append(sphere(f"{p}Vert{i}", 0.035, (0, body.front(0, z, back=True) - 0.01, z), scale=(1, 0.8, 0.9), m=m["skin_dark"], segs=8, rings=5))
    parts += bz.bind("Spine", ribs)
    parts += hips(p, overalls, w=0.46, d=0.34, belt=m["reflect"], belt_z=0.95)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.13, sleeve_len="none", hand=0.05, fingers=3, curl=0.25, nail=m["bone"], seed=73)
        parts += leg(p, side, m, w=0.16, pants=overalls, pants_len="long", foot="bare", tear=3, seed=75)
        # Long hooked claws past the fingertips.
        parts += bz.bind(f"ForeArm.{s}", [cyl(f"{p}Claw{s}{i}", 0.018, 0.14, (side * (0.42 + (i - 1) * 0.04), -0.05, 0.43), rot=rad(25, 0, 0),
                                              segs=5, bevel=0.0, m=m["bone"], radius_top=0.002) for i in range(3)])
        parts += bz.bind(f"Shin.{s}", [box(f"{p}Rip{s}", (0.12, 0.04, 0.1), (side * 0.16, -0.08, 0.32), rot=rad(0, 0, side * 20), bevel=0.02,
                                           m=m["skin"])])
    return parts


def crawler_accessories(m):
    p = "TA_"
    w = 0.52
    fy = face_y(w, 1.8)
    acc = {
        "Acc_Crawler_Lamp": bz.bind("Head", [
            head_band(p + "Band", w, 1.82, 1.76, m["black"], off=0.03, thick=0.022),
            cyl(p + "Lamp", 0.07, 0.08, (0, fy - 0.05, 1.79), rot=rad(80, 0, 0), segs=12, bevel=0.015, m=m["hazard"]),
            cyl(p + "LampLens", 0.058, 0.02, (0, fy - 0.1, 1.785), rot=rad(80, 0, 0), segs=12, bevel=0.0, m=m["lamp"]),
            box(p + "Crack", (0.08, 0.012, 0.012), (0.01, fy - 0.112, 1.79), rot=rad(0, 30, 0), bevel=0.0, m=m["dark"]),
        ]),
        "Acc_Crawler_Goggles": bz.bind("Head", [
            head_band(p + "GBand", w, 1.7, 1.65, m["black"], off=0.03, thick=0.02),
            cyl(p + "GogL", 0.075, 0.05, (0.12, face_y(w, 1.66) - 0.03, 1.66), rot=rad(90, 0, 0), segs=12, bevel=0.012, m=m["steel_dark"]),
            cyl(p + "GogR", 0.075, 0.05, (-0.12, face_y(w, 1.66) - 0.03, 1.66), rot=rad(90, 0, 0), segs=12, bevel=0.012, m=m["steel_dark"]),
            cyl(p + "LensL", 0.06, 0.02, (0.12, face_y(w, 1.66) - 0.06, 1.66), rot=rad(90, 0, 0), segs=12, bevel=0.0, m=m["lens"]),
            cyl(p + "LensR", 0.06, 0.02, (-0.12, face_y(w, 1.66) - 0.06, 1.66), rot=rad(90, 0, 0), segs=12, bevel=0.0, m=m["lens"]),
        ]),
        "Acc_Crawler_Hair": hair_top(p, w, m["dark"], "mop", 71),
    }
    acc.update(faces("Crawler", m, w, ("Gape", "Snarl", "Derp"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Firebug (Neon Market)
# ---------------------------------------------------------------------------

def molotov(name, loc, m, tilt=(0, 0, 0), lit=True, scale=1.0):
    x, y, z = loc
    k = scale
    parts = [
        cyl(name + "Glass", 0.045 * k, 0.17 * k, (x, y, z), rot=tilt, segs=10, bevel=0.012, m=m["bottle"]),
        cyl(name + "Neck", 0.02 * k, 0.07 * k, (x, y, z + 0.11 * k), rot=tilt, segs=8, bevel=0.0, m=m["bottle"]),
        cyl(name + "Rag", 0.024 * k, 0.05 * k, (x, y, z + 0.16 * k), rot=tilt, segs=8, bevel=0.0, m=m["rag"]),
    ]
    if lit:
        parts.append(sphere(name + "Flame", 0.045 * k, (x, y, z + 0.21 * k), scale=(1, 1, 1.6), m=m["flame"], segs=8, rings=5))
    return parts


def firebug(m):
    p = "F_"
    w = 0.56
    hoodie = m["shirt"]
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "fringe", 81)
    tor, body = torso(p, hoodie, w=0.6, d=0.4, z0=0.86, hunch=0.05, hem=hoodie, hem_tear=3, seed=81)
    parts += tor
    parts += neck(p, m["skin"], 0.23)
    t = tor[0]
    kit = [
        # The hood down round the shoulders.
        band(p + "Hood", (0, 0.06, 1.5), (0, 0.04, 1.4), 0.24, 0.24, hoodie, n=2.4, thick=0.06, flare=0.05, segs=20),
        box(p + "Pocket", (0.34, 0.04, 0.14), (0, body.front(0, 1.0) - 0.012, 1.0), bevel=0.02, m=hoodie),
        box(p + "PocketGlow", (0.3, 0.02, 0.03), (0, body.front(0, 1.07) - 0.03, 1.07), bevel=0.0, m=m["ember"]),
        # A bandolier of bottles, wicks smouldering.
        tube(p + "Bandolier", [(0.3, -0.05, 1.42), (0.18, body.front(0.18, 1.28) - 0.03, 1.28), (0.0, body.front(0, 1.12) - 0.04, 1.12),
                               (-0.2, body.front(-0.2, 0.98) - 0.03, 0.98), (-0.3, 0.0, 0.94)], 0.03, m=m["leather"], segs=6),
    ]
    for i, (x, z) in enumerate(((0.16, 1.24), (0.05, 1.15), (-0.07, 1.07), (-0.18, 0.99))):
        kit += molotov(f"{p}Mol{i}", (x, body.front(x, z) - 0.07, z - 0.03), m, tilt=rad(0, -40, 0), lit=i % 2 == 0, scale=0.8)
    # Scorch marks and glowing burns on the hoodie.
    kit += soot_marks(p, body, t, m, 81, count=7)
    rng = random.Random(82)
    for i in range(4):
        z = rng.uniform(0.95, 1.35)
        x = rng.uniform(-0.2, 0.2)
        kit.append(decal(f"{p}Burn{i}", t, (x, body.front(x, z, back=True), z), rng.uniform(0.03, 0.05), m["ember"]))
    parts += bz.bind("Spine", kit)
    parts += hips(p, m["denim"], w=0.56, d=0.4, belt=m["black"], buckle=m["steel"])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.16, sleeve=hoodie, sleeve_len="short", sleeve_tear=2, seed=83, nail=m["white"],
                     glove=m["black"] if side > 0 else None)
        parts += leg(p, side, m, w=0.18, pants=m["denim"], pants_len="long", foot="shoe", shoe=m["black"], sole=m["white"], lace=m["red"],
                     tear=3, seed=85)
        parts += bz.bind(f"Thigh.{s}", [box(f"{p}KneeRip{s}", (0.12, 0.03, 0.08), (side * 0.16, -0.11, 0.5), bevel=0.02, m=m["skin"])])
    # A lighter flicking in the left hand.
    parts += bz.bind("ForeArm.L", [
        box(p + "Lighter", (0.05, 0.03, 0.08), (0.45, -0.06, 0.52), bevel=0.01, m=m["steel"]),
        sphere(p + "LighterFlame", 0.03, (0.45, -0.06, 0.6), scale=(1, 1, 1.7), m=m["flame"], segs=8, rings=5),
    ])
    return parts


def firebug_accessories(m):
    p = "FA_"
    w = 0.56
    acc = {
        "Acc_Firebug_Bottle": bz.bind("ForeArm.R", molotov(p + "Held", (-0.44, -0.12, 0.42), m, tilt=rad(0, 0, 0), lit=True, scale=1.35)),
        "Acc_Firebug_Goggles": bz.bind("Head", [
            head_band(p + "Band", w, 1.85, 1.8, m["black"], off=0.03, thick=0.022),
            cyl(p + "GogL", 0.08, 0.06, (0.13, face_y(w, 1.83) - 0.0, 1.86), rot=rad(60, 0, 0), segs=12, bevel=0.012, m=m["steel_dark"]),
            cyl(p + "GogR", 0.08, 0.06, (-0.13, face_y(w, 1.83) - 0.0, 1.86), rot=rad(60, 0, 0), segs=12, bevel=0.012, m=m["steel_dark"]),
            cyl(p + "LensL", 0.065, 0.02, (0.13, face_y(w, 1.83) - 0.03, 1.875), rot=rad(60, 0, 0), segs=12, bevel=0.0, m=m["ember"]),
            cyl(p + "LensR", 0.065, 0.02, (-0.13, face_y(w, 1.83) - 0.03, 1.875), rot=rad(60, 0, 0), segs=12, bevel=0.0, m=m["ember"]),
        ]),
        "Acc_Firebug_Mohawk": bz.bind("Head", [cyl(f"{p}Spike{i}", 0.05, 0.2, (0, HEAD_Y - 0.2 + i * 0.1, 1.95 - abs(i - 2) * 0.02),
                                                    rot=rad(-25 + i * 12, 0, 0), segs=6, bevel=0.0, m=m["magenta"] if i % 2 else m["orange"],
                                                    radius_top=0.008) for i in range(5)]),
        "Acc_Firebug_Can": bz.bind("Spine", [
            box(p + "Can", (0.34, 0.16, 0.42), (0.0, 0.34, 1.12), bevel=0.04, m=m["can_red"]),
            box(p + "CanRidge", (0.36, 0.17, 0.04), (0.0, 0.34, 1.2), bevel=0.012, m=m["can_red"]),
            cyl(p + "Spout", 0.035, 0.12, (0.12, 0.34, 1.38), rot=rad(0, 30, 0), segs=8, bevel=0.0, m=m["black"]),
            box(p + "Handle", (0.2, 0.06, 0.04), (-0.04, 0.34, 1.35), bevel=0.01, m=m["black"]),
            box(p + "StrapA", (0.05, 0.3, 0.04), (0.12, 0.14, 1.36), rot=rad(-25, 0, 0), bevel=0.01, m=m["leather"]),
            box(p + "StrapB", (0.05, 0.3, 0.04), (-0.12, 0.14, 1.36), rot=rad(-25, 0, 0), bevel=0.01, m=m["leather"]),
        ]),
    }
    acc.update(faces("Firebug", m, w, ("Grin", "Derp", "Snarl"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# The Wrecker (boss)
# ---------------------------------------------------------------------------

def hazard_stripes(prefix, size, loc, m, count=5, rot=(0, 0, 0)):
    """A yellow plate with black chevron bars (a hazard panel)."""
    sx, sy, sz = size
    parts = [box(prefix + "Plate", size, loc, rot=rot, bevel=0.02, m=m["hazard"])]
    for i in range(count):
        x = -sx * 0.5 + sx * (i + 0.5) / count
        parts.append(box(f"{prefix}Bar{i}", (sx / count * 0.45, sy + 0.01, sz * 1.2), (loc[0] + x, loc[1], loc[2]), rot=(rot[0], rot[1] + 0.6, rot[2]),
                         bevel=0.0, m=m["black"]))
    return parts


def wrecker(m):
    p = "X_"
    w = 0.6
    parts = head(p, m, w)
    tor, body = torso(p, m["skin"], w=1.14, d=0.74, z0=0.84, z1=1.5, waist=0.86, belly=0.14, hunch=0.16, chest=1.08, n=2.8)
    parts += tor
    parts += neck(p, m["skin"], 0.46, z1=1.5)
    t = tor[0]
    kit = [
        blob(p + "Traps", (-0.52, 0.1, 1.48), (0.52, 0.1, 1.48), [(0, 0.08, 0.12), (0.3, 0.2, 0.18), (0.7, 0.2, 0.18), (1, 0.08, 0.12)],
             m["skin"], n=2.4, r0=0.05, r1=0.05, segs=16, mid=6),
        # Hi-vis harness: crossed straps with reflective bands.
        box(p + "StrapA", (0.16, 0.06, 0.95), (0.0, body.front(0, 1.18) - 0.03, 1.18), rot=rad(0, 32, 0), bevel=0.02, m=m["hivis"]),
        box(p + "StrapB", (0.16, 0.06, 0.95), (0.0, body.front(0, 1.18) - 0.04, 1.18), rot=rad(0, -32, 0), bevel=0.02, m=m["hivis"]),
        box(p + "StrapBandA", (0.165, 0.065, 0.06), (0.16, body.front(0.16, 1.3) - 0.035, 1.3), rot=rad(0, 32, 0), bevel=0.0, m=m["reflect"]),
        box(p + "StrapBandB", (0.165, 0.065, 0.06), (-0.16, body.front(-0.16, 1.3) - 0.045, 1.3), rot=rad(0, -32, 0), bevel=0.0, m=m["reflect"]),
        cyl(p + "Ring", 0.07, 0.04, (0, body.front(0, 1.18) - 0.07, 1.18), rot=rad(90, 0, 0), segs=12, bevel=0.01, m=m["steel"]),
        body.shell(p + "BackPlate", m["hazard"], 1.42, 1.0, off=0.04, gap=200, gap_at=0, segs=26, steps=3, lip=0.03),
        text(p + "BackText", "DEMO", 0.16, 0.03, (0, body.front(0, 1.12, back=True, off=0.08), 1.12), rot=(0, 0, math.pi), m=m["black"]),
    ]
    # Two exhaust stacks over the shoulders, glowing at the tips.
    for side in (1, -1):
        x = side * 0.28
        kit += [
            cyl(f"{p}Stack{side}", 0.08, 0.8, (x, 0.52, 1.62), rot=rad(-8, 0, 0), segs=12, bevel=0.01, m=m["steel_dark"]),
            cyl(f"{p}StackLip{side}", 0.095, 0.06, (x, 0.58, 2.02), rot=rad(-8, 0, 0), segs=12, bevel=0.01, m=m["iron"]),
            cyl(f"{p}StackGlow{side}", 0.07, 0.02, (x, 0.585, 2.05), rot=rad(-8, 0, 0), segs=12, bevel=0.0, m=m["ember"]),
        ]
    kit += [box(p + "Tank", (0.6, 0.26, 0.5), (0, 0.48, 1.2), bevel=0.06, m=m["can_red"]),
            box(p + "TankBand", (0.62, 0.27, 0.06), (0, 0.48, 1.3), bevel=0.01, m=m["iron"])]
    kit += soot_marks(p, body, t, m, 91, count=8, z=(0.95, 1.42))
    parts += bz.bind("Spine", kit)
    parts += hips(p, m["cargo"], w=1.0, d=0.66, z0=0.7, belt=m["black"], belt_z=0.95)
    parts += bz.bind("Hips", hazard_stripes(p + "Belt", (0.5, 0.06, 0.1), (0, -0.35, 0.95), m, count=4))
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.32, out=0.16, hand=0.11, fingers=3, curl=0.8, nail=m["white"], glove=m["leather"], seed=93)
        parts += leg(p, side, m, w=0.32, pants=m["cargo"], pants_len="long", foot="boot", shoe=m["boot"], sole=m["dark"], lace=m["hazard"],
                     toe=m["steel"], tear=2, seed=95, boot_h=0.24)
        parts += bz.bind(f"ForeArm.{s}", [blob(f"{p}Forearm{s}", (side * 0.58, 0, 0.94), (side * 0.6, 0, 0.7),
                                               [(0, 0.15, 0.15), (0.45, 0.2, 0.19), (1, 0.14, 0.14)], m["skin"], n=2.6, r0=0.05, r1=0.05,
                                               segs=16, mid=4)])
        parts += bz.bind(f"UpperArm.{s}", [torus(f"{p}ArmChain{s}{i}", 0.2, 0.03, (side * 0.58, 0, 1.12 - i * 0.07), rot=rad(0, 0, 0),
                                                 m=m["steel"], major_segs=12, minor_segs=4) for i in range(2)])
    return parts


def wrecker_accessories(m):
    p = "XA_"
    w = 0.6
    # The wrecking ball hangs from the right fist on a short chain.
    hx, hy, hz = -0.6, -0.04, 0.5
    ball = [cyl(p + "Cuff", 0.16, 0.18, (hx, hy, 0.72), segs=14, bevel=0.02, m=m["iron"])]
    for i in range(4):
        ball.append(torus(f"{p}Link{i}", 0.06, 0.018, (hx, hy, hz - i * 0.085), rot=rad(0, 90 * (i % 2), 0), m=m["steel"],
                          major_segs=10, minor_segs=4))
    ball += [
        sphere(p + "Ball", 0.34, (hx, hy, 0.0), m=m["iron"], segs=18, rings=12),
        torus(p + "BallBand", 0.33, 0.035, (hx, hy, 0.0), rot=rad(0, 0, 0), m=m["hazard"], major_segs=24, minor_segs=5),
        cyl(p + "BallHook", 0.07, 0.08, (hx, hy, 0.33), segs=10, bevel=0.01, m=m["steel_dark"]),
        box(p + "BallScorch", (0.18, 0.18, 0.12), (hx + 0.15, hy - 0.22, -0.1), rot=rad(20, 30, 0), bevel=0.05, m=m["rust"]),
    ]
    blade = hazard_stripes(p + "Blade", (0.14, 0.95, 0.75), (0.82, -0.12, 0.72), m, count=5, rot=rad(0, 0, 0))
    blade += [box(f"{p}Tooth{i}", (0.1, 0.12, 0.1), (0.86, -0.5 + i * 0.19, 0.31), bevel=0.02, m=m["steel"]) for i in range(5)]
    blade += [box(p + "BladeBrace", (0.2, 0.12, 0.3), (0.66, -0.0, 0.76), bevel=0.03, m=m["iron"]),
              box(p + "BladeDent", (0.15, 0.3, 0.2), (0.89, 0.1, 0.9), rot=rad(0, 0, 0.3), bevel=0.05, m=m["soot"])]
    sk_hat = [
        cap_crown(p + "Hat", w, m["hat"], rim=1.79, top=2.1, off=0.065, lip=0.03),
        band(p + "HatBrim", (0, HEAD_Y, 1.8), (0, HEAD_Y, 1.77), 0.46, 0.4, m["hat"], n=2.6, thick=0.03, flare=0.05, segs=26),
        box(p + "HatDent", (0.2, 0.2, 0.08), (0.14, HEAD_Y - 0.1, 2.05), rot=rad(14, 20, 0), bevel=0.04, m=m["soot"]),
        cyl(p + "BeaconBase", 0.08, 0.05, (0, HEAD_Y + 0.02, 2.12), segs=12, bevel=0.01, m=m["black"]),
        cyl(p + "Beacon", 0.07, 0.12, (0, HEAD_Y + 0.02, 2.2), segs=12, bevel=0.02, m=m["amber"]),
        box(p + "HatSticker", (0.16, 0.02, 0.09), (0.0, HEAD_Y - 0.36, 1.92), rot=rad(-22, 0, 0), bevel=0.0, m=m["red"]),
    ]
    acc = {
        "Acc_Wrecker_Ball": bz.bind("ForeArm.R", ball),
        "Acc_Wrecker_Blade": bz.bind("ForeArm.L", blade),
        "Acc_Wrecker_Hat": bz.bind("Head", sk_hat),
    }
    acc.update(faces("Wrecker", m, w, ("Snarl", "Clench")))
    return acc


# ---------------------------------------------------------------------------
# Clips
# ---------------------------------------------------------------------------

SHIELD_ARM = {"UpperArm.L": (-58, 0, -38), "ForeArm.L": (-62, 0, -10)}


def cop_drum(rig, name="Drum"):
    """The bash telegraph: shield planted, the baton beats on its rim three
    times (frames 5, 11, 17), then the cop leans in ready to rush. 24 frames."""
    base = {"Hips": (6, 0, 0), "Spine": (12, 0, 0), "Head": (-8, 0, 0), "hips": (0, 0, -0.07),
            **feet(0.24, 0.16, -0.14), **SHIELD_ARM, "elbow.R": elbow_pole(-1)}
    up = dict(base, **{"hand.R": (-0.18, 0.3, 1.75), "Spine": (8, 0, 8)})
    hit = dict(base, **{"hand.R": (0.02, 0.62, 1.4), "Spine": (14, 0, -6)})
    keys = [(0, dict(base, **{"hand.R": (-0.42, 0.3, 0.95)}))]
    for k, f in enumerate((5, 11, 17)):
        keys.append((f - 3, up, "out"))
        keys.append((f, hit, "snap"))
    lean = dict(hit, **{"Hips": (16, 0, 0), "Spine": (24, 0, 0), "Head": (-24, 0, 0), "hips": (0, 0.08, -0.12),
                        "hand.R": (-0.3, 0.3, 1.0)})
    keys.append((24, lean, "io"))
    return keyed(rig, name, keys, beats=[round(f / FPS, 4) for f in (5, 11, 17)])


def cop_recover(rig, name="Recover"):
    """After the bash: the shield swings wide to the left (the spine twists
    open, the front exposed), the cop staggers, then brings it back. 30 frames."""
    base = {"Hips": (6, 0, 0), "Spine": (12, 0, 0), "Head": (-8, 0, 0), "hips": (0, 0, -0.05),
            **feet(0.22, 0.12, -0.1), **SHIELD_ARM, "hand.R": (-0.42, 0.3, 0.95), "elbow.R": elbow_pole(-1)}
    wide = dict(base, **{"Hips": (2, 0, 22), "Spine": (-4, 6, 50), "Head": (-14, 0, -30), "hips": (0.04, -0.1, -0.08),
                         "UpperArm.L": (-40, 0, -70), "hand.R": (-0.6, 0.1, 1.1)})
    sway = dict(wide, **{"Spine": (-2, 4, 44), "Head": (-10, 6, -24)})
    return keyed(rig, name, [(0, base), (4, wide, "out"), (12, sway), (20, wide), (30, base, "io")])


def crawl_torso(drag=0.0):
    """Tunnel Crawler torso: pitched almost flat, head craned up at the prey,
    the long arms pawing the floor out of step with the legs."""
    def torso(ph):
        c, s = _cs(ph)
        spec = {"Hips": (48, 4 * c, -6 * c), "Spine": (34, -4 * c, 10 * c), "Head": (-72, 6 * s, -8 * c), "hips": (0.02 * c, -0.16, 0.0)}
        for side, sh in ((1, 0.5), (-1, 0.0)):
            u = (ph + sh) % 1.0
            reach = 0.5 - 0.5 * math.cos(math.tau * u)          # 0 at the back, 1 at the front
            lift = max(0.0, math.sin(math.tau * u)) * (0.22 - drag)
            spec["hand.L" if side > 0 else "hand.R"] = (side * 0.34, 0.3 + 0.36 * reach, 0.1 + lift)
            spec["elbow.L" if side > 0 else "elbow.R"] = (side * 1.0, 0.2, 0.3)
        return spec
    return torso


def crawler_clips(rig):
    """Style "Crawler": a low skittering scuttle and its specials."""
    scuttle = Gait(0.34, 0.42, 0.58, 0.12, crawl_torso(), front=0.42, width=0.08, crouch=0.24, bob=0.025, bob_style="run")
    creep = Gait(0.6, 0.55, 0.5, 0.1, crawl_torso(0.08), front=0.45, width=0.08, crouch=0.22, bob=0.015)
    low = {"Hips": (48, 0, 0), "Spine": (34, 0, 0), "Head": (-72, 0, 0), "hips": (0, -0.16, -0.4),
           **feet(0.24, 0.05, -0.12), "hand.L": (0.34, 0.55, 0.1), "hand.R": (-0.34, 0.5, 0.1),
           "elbow.L": (1.0, 0.2, 0.3), "elbow.R": (-1.0, 0.2, 0.3)}
    idle_keys = []
    for i in range(9):
        _, s = _cs(i / 8)
        idle_keys.append((i * 6, dict(low, **{"Head": (-72 + 4 * s, 10 * s, 0), "hips": (0, -0.16, -0.4 + 0.02 * s),
                                               "hand.L": (0.34, 0.55 + 0.04 * s, 0.1 + 0.03 * max(0, s))}), "io"))
    # The pounce wind-up: rear end up, chest flat on the floor, shaking.
    coil = dict(low, **{"Hips": (62, 0, 0), "Spine": (28, 0, 0), "Head": (-78, 0, 0), "hips": (0, -0.24, -0.46),
                        "hand.L": (0.36, 0.62, 0.08), "hand.R": (-0.36, 0.62, 0.08)})
    crouch_keys = [(0, low), (5, coil, "out")]
    for i in range(6):
        k = 1 if i % 2 else -1
        crouch_keys.append((7 + i * 2, dict(coil, **{"Hips": (62, 0, 3 * k), "Head": (-80, 0, 4 * k)}), "lin"))
    flight = {"Hips": (30, 0, 0), "Spine": (20, 0, 0), "Head": (-50, 0, 0), "hips": (0, 0, -0.1),
              **_legs(40, 70, 50, 80), "hand.L": (0.36, 0.95, 0.75), "hand.R": (-0.36, 0.95, 0.75),
              "elbow.L": (1.0, 0.2, 0.3), "elbow.R": (-1.0, 0.2, 0.3)}
    reach = dict(flight, **{"hand.L": (0.3, 0.9, 0.45), "hand.R": (-0.3, 0.9, 0.45), **_legs(10, 40, 20, 50)})
    # A low two-claw rake from the crouch.
    rear = dict(low, **{"Hips": (36, 0, 0), "Spine": (14, 0, 0), "Head": (-50, 0, 0), "hips": (0, -0.2, -0.34),
                        "hand.L": (0.5, 0.3, 1.0), "hand.R": (-0.5, 0.3, 1.0)})
    rake = dict(low, **{"Hips": (52, 0, 0), "Spine": (40, 0, 0), "Head": (-70, 0, 0), "hips": (0, 0.12, -0.38),
                        "hand.L": (0.12, 0.95, 0.4), "hand.R": (-0.12, 0.95, 0.45)})
    # Deaths: the legs go limp (FK), so they start from the crouch in FK.
    low_fk = {k: v for k, v in low.items() if not k.startswith("foot.")}
    low_fk.update(_legs(-62, 104, -54, 98))
    flop = dict(low_fk, **{"Hips": (80, 0, 10), "Spine": (14, 0, 0), "Head": (-20, 0, 20), "hips": (0, 0.02, -0.66),
                        **_legs(10, 30, 0, 50), "hand.L": (0.6, 0.6, 0.06), "hand.R": (-0.66, 0.3, 0.06)})
    side = dict(flop, **{"Hips": (84, 70, 20), "Head": (-10, 30, 20), "hips": (0.1, 0.02, -0.62)})
    death = [(0, low_fk), (4, dict(low_fk, **{"Head": (-40, 0, 0), "hips": (0, -0.16, -0.32)}), "snap"), (10, flop, "in"),
             (13, dict(flop, **{"hips": (0, 0.02, -0.6)}), "out"), (18, side, "io"), (26, side)]
    pop = [(0, dict(low_fk, **{"scale.Head": 1.0})), (3, dict(low_fk, **{"Head": (-40, 0, 0), "scale.Head": 1.3}), "snap"),
           (7, dict(low_fk, **{"Head": (-36, 8, 0), "scale.Head": 1.75}), "out"), (8, dict(low_fk, **{"scale.Head": 0.001}), "lin"),
           (14, dict(flop, **{"scale.Head": 0.001}), "in"), (20, dict(side, **{"scale.Head": 0.001}), "io"), (26, dict(side, **{"scale.Head": 0.001}))]
    strike = round(zombie_anim.STRIKE * 22 / FPS, 4)
    return [
        keyed(rig, "Idle_Crawler", idle_keys, loop=True),
        gait(rig, "Walk_Crawler", creep), gait(rig, "Run_Crawler", scuttle),
        keyed(rig, "Attack_Crawler", [(0, low), (7, rear, "out"), (11, dict(rear, **{"Head": (-56, 0, 0)})), (13, rake, "snap"),
                                      (16, dict(rake, **{"hips": (0, 0.14, -0.4)}), "out"), (22, low)], strike=strike),
        keyed(rig, "Crouch_Crawler", crouch_keys),
        keyed(rig, "Leap_Crawler", [(0, flight), (8, reach, "io"), (14, dict(reach, **{"hand.L": (0.3, 0.8, 0.2), "hand.R": (-0.3, 0.8, 0.2)}))]),
        keyed(rig, "Stagger_Crawler", [(0, low), (3, dict(low, **{"Hips": (30, 0, -10), "Spine": (14, 0, 0), "Head": (-30, 0, 20),
                                                                "hips": (0, -0.3, -0.32)}), "snap"), (14, low, "io")]),
        keyed(rig, "Emerge_Crawler", [(0, dict(low, **{"hips": (0, -0.16, -0.62), "Head": (-30, 0, 0)})), (10, dict(low, **{"Head": (-86, 0, 0)}), "out"),
                                      (22, low, "io")]),
        keyed(rig, "Die_Back_Crawler", death, floor=True, impact=round(10 / FPS, 4)),
        keyed(rig, "Die_Front_Crawler", death, floor=True, impact=round(10 / FPS, 4)),
        keyed(rig, "Die_Spin_Crawler", death, floor=True, impact=round(10 / FPS, 4)),
        keyed(rig, "Die_HeadPop_Crawler", pop, floor=True, impact=round(14 / FPS, 4), pop=round(7.5 / FPS, 4)),
    ]


def throw_bottle(rig, name="Throw_Bottle"):
    """Firebug: lights the bottle (left hand brings the lighter to it, frames
    0-12), cocks it back over the shoulder (held, shaking), then hurls it
    overhand at frame 21 and follows through. 30 frames."""
    r = ready()
    r.update({"elbow.L": elbow_pole(1), "elbow.R": elbow_pole(-1)})
    light = dict(r, **{"Spine": (6, 0, -10), "Head": (-4, 0, -12), "hand.R": (-0.1, 0.45, 1.25), "hand.L": (0.02, 0.48, 1.22)})
    cock = dict(light, **{"Hips": (-4, 0, 16), "Spine": (-14, 0, 26), "Head": (-16, 0, -10), "hips": (0, -0.1, -0.05),
                          "hand.R": (-0.4, -0.4, 1.95), "elbow.R": (-1.0, 0.3, 0.3), "hand.L": (0.5, 0.5, 1.3), **feet(0.2, 0.2, -0.16)})
    hurl = dict(cock, **{"Hips": (12, 0, -10), "Spine": (26, 0, -18), "Head": (-20, 0, 6), "hips": (0, 0.16, -0.1),
                         "hand.R": (0.05, 0.9, 1.3), "elbow.R": (-1.0, -0.2, -0.2), "hand.L": (0.45, -0.1, 1.0)})
    follow = dict(hurl, **{"Spine": (30, 0, -20), "hand.R": (0.2, 0.6, 0.85)})
    keys = [(0, r), (6, light, "out"), (12, dict(light, **{"Head": (-8, 0, -14)})), (16, cock, "out")]
    keys += [(17, dict(cock, **{"hand.R": (-0.42, -0.42, 1.97)}), "lin"), (19, dict(cock, **{"hand.R": (-0.38, -0.38, 1.93)}), "lin")]
    keys += [(21, hurl, "snap"), (24, follow, "out"), (30, r, "io")]
    return keyed(rig, name, keys, release=round(21 / FPS, 4))


def wrecker_swing(rig, name="Swing"):
    """The Wrecker's sweep: the ball arm goes up and whirls the ball round
    overhead twice (frames 0-24, the telegraph), the body winds back, then the
    arm scythes across the front from right to left at waist height (frames
    26-32) and the brute staggers round with it. 46 frames."""
    r = ready(heavy=True)
    r.update({"elbow.L": elbow_pole(1), "elbow.R": elbow_pole(-1)})
    keys = [(0, r)]
    for i in range(9):
        a = math.tau * i / 4.5
        keys.append((3 + i * 2.5, dict(r, **{"Hips": (-4, 0, -6), "Spine": (-10, 0, -10 + 4 * math.sin(a)), "Head": (-24, 0, 0),
                                                "hand.R": (-0.25 + 0.25 * math.cos(a), 0.2 + 0.25 * math.sin(a), 2.25),
                                                "elbow.R": (-1.0, 0.0, 0.6), "hand.L": (0.55, 0.3, 1.2)}), "lin"))
    wind = dict(r, **{"Hips": (0, 0, 30), "Spine": (2, 0, 40), "Head": (-14, 0, -30), "hips": (0, -0.08, -0.1),
                      "hand.R": (-0.9, -0.35, 1.3), "elbow.R": (-0.6, 0.6, 0.2), "hand.L": (0.6, 0.5, 1.1), **feet(0.3, 0.2, -0.16)})
    mid = dict(wind, **{"Hips": (8, 0, 0), "Spine": (14, 0, 0), "Head": (-14, 0, 0), "hips": (0, 0.06, -0.14),
                        "hand.R": (-0.1, 1.0, 1.05), "elbow.R": (-0.6, -0.2, 0.2)})
    out = dict(mid, **{"Hips": (6, 0, -30), "Spine": (10, 0, -46), "Head": (-10, 0, 20), "hand.R": (0.95, 0.35, 1.15), "elbow.R": (0.2, -0.6, 0.2)})
    keys += [(26, wind, "out"), (29, mid, "lin"), (32, out, "out"), (38, dict(out, **{"Spine": (14, 0, -40)})), (46, r, "io")]
    return keyed(rig, name, keys, strike=round(29 / FPS, 4))


def special_clips(rig):
    """zombie_city_special.glb: the Cop (shielded stomp, rush, bash, Drum,
    Recover), the Crawler (style "Crawler"), the Firebug (swagger, sprint,
    Throw_Bottle)."""
    def cop_idle_arms(ph):
        _, s = _cs(ph)
        return {**SHIELD_ARM, "UpperArm.L": (-58 + 2 * s, 0, -38), "UpperArm.R": (-20 + 3 * s, 16, 0), "ForeArm.R": (-40, 0, 0)}
    return [idle(rig, heavy=True, arms_fn=cop_idle_arms), gait(rig, "Walk", riot_stomp()), gait(rig, "Run", riot_charge()),
            attack_riot(rig), cop_drum(rig), cop_recover(rig),
            gait(rig, "Walk_Firebug", swagger()), gait(rig, "Run_Firebug", flail_sprint()), idle(rig, "Idle_Firebug"),
            attack(rig, "Attack_Firebug"), throw_bottle(rig),
            *crawler_clips(rig),
            stagger(rig, heavy=True), stagger(rig, "Stagger_Firebug"), hit_head(rig), *deaths(rig), emerge(rig, heavy=True),
            emerge(rig, "Emerge_Firebug")]


def wrecker_clips(rig):
    """zombie_city_wrecker.glb: heavy stomp, charge, slam, roar, heave, Swing."""
    return [idle(rig, heavy=True), gait(rig, "Walk", stomp()), gait(rig, "Run", charge()), attack_heavy(rig, "Attack"),
            roar(rig), throw(rig), wrecker_swing(rig), stagger(rig, heavy=True), stagger(rig, "Stagger_Heavy", heavy=True), hit_head(rig),
            *deaths(rig), emerge(rig, heavy=True), emerge(rig, "Emerge_Heavy", heavy=True)]


def build_model(name, outfits, accessory_sets, clips):
    scene = reset_scene()
    scene.render.fps = bz.FPS
    m = materials()
    armature = bz.build_armature()
    meshes = [bz.skin("Outfit_" + outfit, body(m), armature) for outfit, body in outfits]
    for accessories in accessory_sets:
        for acc_name, parts in accessories(m).items():
            meshes.append(bz.skin(acc_name, parts, armature))
    zombie_anim.bake(armature, clips, name)
    bz.save_zombie(name, [armature] + meshes)


def build():
    build_model("zombie_city_special", [("Cop", cop), ("Crawler", crawler), ("Firebug", firebug)],
                [cop_shield, crawler_accessories, firebug_accessories], special_clips)
    build_model("zombie_city_wrecker", [("Wrecker", wrecker)], [wrecker_accessories], wrecker_clips)


if __name__ == "__main__":
    build()
