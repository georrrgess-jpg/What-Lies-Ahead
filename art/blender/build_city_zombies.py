"""Ashfall City zombies (Endless mode), part 1: the city's rank and file on the
shared rig (build_zombie.py), three outfits in zombie_city_crowd.glb.

    Outfit_Commuter  City Shambler: an office commuter in a rumpled, singed suit
                     jacket ("Shirt", tinted per zombie) over a white shirt and a
                     loose tie, a lanyard ID badge, soot smudges; options: cracked
                     glasses, a briefcase, a takeaway coffee, a combover
    Outfit_Courier   City Runner: a bike courier in a tintable windbreaker with
                     reflective bands, cycling shorts over leggings, high-tops;
                     options: a bike helmet or a backwards cap, headphones, a
                     messenger bag or a food-delivery box on the back
    Outfit_Worker    City Bruiser: a hulking construction worker in a hi-vis vest
                     with reflective stripes over a tintable work shirt, jeans,
                     steel-toe boots and a tool belt; options: a hard hat, ear
                     defenders, a dust mask, a length of rebar in the fist

Everything carries the city's marks: ash and soot smudges, singed hems.

Clips (city_crowd_clips): the shared set, the Commuter's shamble, the
Courier's flailing sprint and the Worker's stomp, charge and slam ("_Heavy").

    python art/blender/build_city_zombies.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
import build_zombie as bz  # noqa: E402
import zombie_anim  # noqa: E402
from zombie_anim import (attack, attack_heavy, charge, flail_sprint, gait, idle, roar, shamble, stagger, stomp,  # noqa: E402
                         hit_head, deaths, emerge)
from zombie_kit import (HEAD_Y, SPARK_EYE, cap_crown, head_band, arm, band, base_materials, blob, decal, face_y, faces,  # noqa: E402
                        hair, hair_top, head, hips, leg, neck, patch, skull, tear_fn, torso)


def materials():
    m = base_materials("city", skin="#9cc46c", skin_dark="#66903f", dark="#1d1b24", white="#f3f0ea", eye=(SPARK_EYE, 2.8))
    m.update(
        shirt=mat("Shirt", "#4a5470", rough=0.6),
        cotton=mat("CityZCotton", "#ece8df", rough=0.7),
        tie=mat("CityZTie", "#d8343f", rough=0.5),
        slacks=mat("CityZSlacks", "#2c2d36", rough=0.7),
        soot=mat("CityZSoot", "#2a2622", rough=0.95),
        ash=mat("CityZAsh", "#8d8a86", rough=0.95),
        ember=mat("CityZEmber", "#ff6a1f", rough=0.4, emit=2.2),
        leather=mat("CityZLeather", "#5a3622", rough=0.6),
        brass=mat("CityZBrass", "#e0b048", rough=0.35, metal=0.5),
        lens=glass_mat(),
        cup=mat("CityZCup", "#f2ede2", rough=0.6),
        sleeve=mat("CityZCupSleeve", "#9a6a3e", rough=0.8),
        reflect=mat("CityZReflect", "#e9edf2", rough=0.25, metal=0.4, emit=0.35),
        black=mat("CityZBlack", "#25232b", rough=0.6),
        cyan=mat("CityZCyan", "#20c6d8", rough=0.45),
        magenta=mat("CityZMagenta", "#ff3e9a", rough=0.45),
        hivis=mat("CityZHiVis", "#d4f02a", rough=0.5, emit=0.25),
        orange=mat("CityZOrange", "#ff7a1a", rough=0.5),
        denim=mat("CityZDenim", "#3a5a8c", rough=0.75),
        denim_dark=mat("CityZDenimDark", "#2a4068", rough=0.75),
        boot=mat("CityZBoot", "#7a4a28", rough=0.7),
        steel=mat("CityZSteel", "#9a9aa6", rough=0.35, metal=0.7),
        rust=mat("CityZRust", "#a0522d", rough=0.8),
        hat=mat("CityZHardHat", "#ffc21a", rough=0.35),
        red=mat("CityZRed", "#e2343f", rough=0.6),
    )
    return m


def glass_mat():
    from zombie_kit import glass
    return glass("CityZLens", "#bfe6ff", alpha=0.35, emit=0.1)


def soot_marks(p, body, target, m, seed, count=6, z=(0.95, 1.38), back=False):
    """Ash and soot smudges laid on a garment shell (the city burns)."""
    rng = random.Random(seed)
    parts = []
    for i in range(count):
        zz = rng.uniform(*z)
        x = rng.uniform(-0.26, 0.26) * body.w / 0.62
        colour = m["soot"] if i % 3 else m["ash"]
        parts.append(decal(f"{p}Soot{i}", target, (x, body.front(x, zz, back=back), zz), rng.uniform(0.045, 0.075), colour,
                           squash=rng.uniform(0.6, 1.0)))
    return parts


# ---------------------------------------------------------------------------
# The Commuter (city_shambler)
# ---------------------------------------------------------------------------

def commuter(m):
    p = "C_"
    w = 0.6
    jacket = m["shirt"]
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "fringe", 31)
    tor, body = torso(p, jacket, w=0.68, d=0.46, z0=0.84, belly=0.05, hunch=0.05, hem=jacket, hem_tear=3, seed=31)
    parts += tor
    parts += neck(p, m["skin"], 0.25)
    t = tor[0]
    fz = 1.3
    front = body.front(0, fz)
    shirt = [
        # The white shirt and tie show in the jacket's open V.
        patch(p + "ShirtV", t, (0, body.front(0, 1.25), 1.25), (0.2, 0.04, 0.36), m["cotton"], bevel=0.01),
        box(p + "Tie", (0.075, 0.04, 0.3), (0.02, front - 0.035, 1.2), rot=rad(0, 4, 4), bevel=0.012, m=m["tie"]),
        box(p + "TieKnot", (0.08, 0.05, 0.06), (0, body.front(0, 1.4) - 0.04, 1.4), bevel=0.015, m=m["tie"]),
        box(p + "TieTip", (0.075, 0.04, 0.07), (0.035, front - 0.034, 1.03), rot=rad(0, 45, 4), bevel=0.01, m=m["tie"]),
        box(p + "CollarL", (0.12, 0.05, 0.06), (0.07, body.front(0, 1.43) - 0.025, 1.44), rot=rad(0, -25, 0), bevel=0.015, m=m["cotton"]),
        box(p + "CollarR", (0.12, 0.05, 0.06), (-0.07, body.front(0, 1.43) - 0.025, 1.44), rot=rad(0, 25, 0), bevel=0.015, m=m["cotton"]),
    ]
    for side in (1, -1):
        # Lapels folding back from the V.
        shirt.append(box(f"{p}Lapel{side}", (0.07, 0.04, 0.3), (side * 0.13, body.front(side * 0.13, 1.27) - 0.02, 1.27),
                         rot=rad(0, side * 18, 0), bevel=0.012, m=jacket))
        shirt.append(cyl(f"{p}Button{side}", 0.02, 0.02, (side * 0.06, body.front(side * 0.06, 0.98) - 0.008, 0.98),
                         rot=rad(90, 0, 0), segs=8, bevel=0.0, m=m["dark"]))
    # A lanyard with an ID badge, and a scorched pocket square.
    shirt += [
        tube(p + "Lanyard", [(0.12, -0.12, 1.43), (0.1, front - 0.03, 1.22), (0.0, front - 0.05, 1.12),
                             (-0.1, front - 0.03, 1.22), (-0.12, -0.12, 1.43)], 0.012, m=m["cyan"], segs=5),
        box(p + "Badge", (0.11, 0.02, 0.14), (0.0, front - 0.06, 1.06), bevel=0.01, m=m["white"]),
        box(p + "BadgeStripe", (0.11, 0.022, 0.035), (0.0, front - 0.062, 1.11), bevel=0.0, m=m["cyan"]),
        box(p + "Pocket", (0.08, 0.03, 0.05), (0.2, body.front(0.2, 1.32) - 0.012, 1.33), bevel=0.01, m=m["ember"]),
    ]
    shirt += soot_marks(p, body, t, m, 31)
    shirt += soot_marks(p + "B", body, t, m, 32, count=4, back=True)
    parts += bz.bind("Spine", shirt)
    parts += hips(p, m["slacks"], w=0.62, d=0.44, belt=m["black"], buckle=m["brass"])
    for side in (1, -1):
        parts += arm(p, side, m, w=0.17, sleeve=jacket, sleeve_len="long", cuff=m["cotton"], sleeve_tear=1, seed=33, nail=m["white"])
        parts += leg(p, side, m, w=0.19, pants=m["slacks"], pants_len="long", foot="shoe", shoe=m["black"], sole=m["dark"],
                     lace=m["black"], tear=1, seed=35)
    return parts


def commuter_accessories(m):
    p = "CA_"
    w = 0.6
    fy = face_y(w, 1.63)
    case = [
        box(p + "Case", (0.12, 0.42, 0.32), (-0.47, -0.02, 0.38), bevel=0.03, m=m["leather"]),
        box(p + "CaseLid", (0.13, 0.43, 0.04), (-0.47, -0.02, 0.53), bevel=0.012, m=m["black"]),
        tube(p + "CaseHandle", [(-0.47, -0.1, 0.55), (-0.47, -0.08, 0.62), (-0.47, 0.04, 0.62), (-0.47, 0.06, 0.55)], 0.015, m=m["black"], segs=5),
        box(p + "Clasp", (0.13, 0.05, 0.04), (-0.47, -0.02, 0.49), bevel=0.0, m=m["brass"]),
        box(p + "CaseScorch", (0.125, 0.12, 0.08), (-0.47, 0.09, 0.3), bevel=0.02, m=m["soot"]),
    ]
    cup = [
        cyl(p + "Cup", 0.05, 0.16, (0.44, -0.12, 0.56), rot=rad(0, 0, 0), segs=12, bevel=0.01, m=m["cup"], radius_top=0.058),
        cyl(p + "CupSleeve", 0.058, 0.06, (0.44, -0.12, 0.56), segs=12, bevel=0.0, m=m["sleeve"]),
        cyl(p + "CupLid", 0.062, 0.025, (0.44, -0.12, 0.65), segs=12, bevel=0.008, m=m["black"]),
    ]
    acc = {
        "Acc_Commuter_Glasses": bz.bind("Head", [
            torus(p + "LensL", 0.07, 0.012, (0.14, fy - 0.03, 1.63), rot=rad(90, 0, 0), m=m["black"], major_segs=14, minor_segs=4),
            torus(p + "LensR", 0.07, 0.012, (-0.14, fy - 0.03, 1.63), rot=rad(90, 0, 0), m=m["black"], major_segs=14, minor_segs=4),
            cyl(p + "GlassL", 0.064, 0.008, (0.14, fy - 0.03, 1.63), rot=rad(90, 0, 0), segs=12, bevel=0.0, m=m["lens"]),
            box(p + "Crack", (0.1, 0.012, 0.012), (-0.14, fy - 0.04, 1.64), rot=rad(0, 35, 0), bevel=0.0, m=m["white"]),
            box(p + "Bridge", (0.08, 0.015, 0.015), (0, fy - 0.035, 1.64), bevel=0.0, m=m["black"]),
            box(p + "ArmL", (0.02, 0.3, 0.02), (0.29, HEAD_Y - 0.12, 1.65), bevel=0.0, m=m["black"]),
            box(p + "ArmR", (0.02, 0.3, 0.02), (-0.29, HEAD_Y - 0.12, 1.65), bevel=0.0, m=m["black"]),
        ]),
        "Acc_Commuter_Case": bz.bind("ForeArm.R", case),
        "Acc_Commuter_Coffee": bz.bind("ForeArm.L", cup),
        "Acc_Commuter_Combover": bz.bind("Head", [
            skull(w).shell(p + "Comb", m["dark"], 1.86, 1.74, off=0.012, gap=150, segs=26, steps=2, lip=0.012),
        ] + [box(f"{p}Strand{i}", (0.42, 0.035, 0.025), (0.0, HEAD_Y - 0.1 + i * 0.07, 1.89 - abs(i - 1.5) * 0.012),
                 rot=rad(0, 4, 0), bevel=0.01, m=m["dark"]) for i in range(4)]),
    }
    acc.update(faces("Commuter", m, w, ("Gape", "Sleepy", "Derp"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# The Courier (city_runner)
# ---------------------------------------------------------------------------

def courier(m):
    p = "K_"
    w = 0.54
    coat = m["shirt"]
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "mop", 41)
    tor, body = torso(p, coat, w=0.54, d=0.38, z0=0.86, hunch=0.04, hem=coat, hem_tear=2, seed=41)
    parts += tor
    parts += neck(p, m["skin"], 0.22)
    t = tor[0]
    jacket = [
        body.shell(p + "BandChest", m["reflect"], 1.27, 1.22, off=0.018, segs=24, steps=1, lip=0.01),
        body.shell(p + "BandWaist", m["reflect"], 0.99, 0.95, off=0.018, segs=24, steps=1, lip=0.01),
        band(p + "Collar", (0, 0.0, 1.48), (0, 0.0, 1.38), 0.17, 0.16, coat, n=2.6, thick=0.03, flare=0.03, segs=20),
        box(p + "Zip", (0.025, 0.02, 0.56), (0.0, body.front(0, 1.15) - 0.006, 1.15), bevel=0.0, m=m["black"]),
        text(p + "BackText", "RUSH", 0.1, 0.015, (0, body.front(0, 1.15, back=True, off=0.025), 1.15), rot=(0, 0, math.pi), m=m["reflect"]),
    ]
    jacket += soot_marks(p, body, t, m, 41, count=5)
    parts += bz.bind("Spine", jacket)
    parts += hips(p, m["black"], w=0.5, d=0.37, belt=m["cyan"])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.15, sleeve=coat, sleeve_len="long", cuff=m["reflect"], sleeve_tear=1, seed=43, nail=m["white"],
                     glove=m["black"] if side < 0 else None)
        parts += leg(p, side, m, w=0.165, pants=m["black"], pants_len="shorts", foot="shoe", shoe=m["magenta"] if side > 0 else m["cyan"],
                     sole=m["white"], lace=m["white"], sock=m["white"], tear=1, seed=45)
        # Leggings under the cycling shorts, with a knee pad.
        parts += bz.bind(f"Shin.{s}", [blob(f"{p}Legging{s}", (side * 0.16, 0, 0.45), (side * 0.16, 0.005, 0.27),
                                            [(0, 0.085, 0.087), (1, 0.07, 0.072)], m["dark"], n=2.6, r0=0.0, r1=0.0, segs=14, mid=2)])
        parts += bz.bind(f"Thigh.{s}", [box(f"{p}ShortStripe{s}", (0.03, 0.1, 0.18), (side * 0.255, 0, 0.66), bevel=0.0, m=m["cyan"])])
    return parts


def courier_accessories(m):
    p = "KA_"
    w = 0.54
    helmet = [cap_crown(p + "Helmet", w, m["cyan"], rim=1.76, top=2.03, off=0.045, lip=0.03)]
    for i in range(3):
        helmet.append(box(f"{p}Vent{i}", (0.06, 0.32, 0.04), ((i - 1) * 0.12, HEAD_Y + 0.02, 2.02 - abs(i - 1) * 0.03), bevel=0.015, m=m["black"]))
    helmet += [
        box(p + "Visor", (0.4, 0.12, 0.035), (0, HEAD_Y - 0.31, 1.86), rot=rad(-14, 0, 0), bevel=0.012, m=m["black"]),
        box(p + "StrapL", (0.02, 0.03, 0.22), (w * 0.47, HEAD_Y - 0.06, 1.6), bevel=0.0, m=m["black"]),
        box(p + "StrapR", (0.02, 0.03, 0.22), (-w * 0.47, HEAD_Y - 0.06, 1.6), bevel=0.0, m=m["black"]),
        box(p + "HelmetScorch", (0.2, 0.2, 0.05), (0.13, HEAD_Y + 0.12, 2.0), rot=rad(10, 20, 0), bevel=0.03, m=m["soot"]),
    ]
    cap = [cap_crown(p + "Cap", w, m["magenta"]),
           box(p + "CapBrim", (0.32, 0.24, 0.045), (0, HEAD_Y + 0.33, 1.76), rot=rad(14, 0, 0), bevel=0.02, m=m["black"])]
    phones = [
        tube(p + "Band", [(w * 0.5, HEAD_Y + 0.02, 1.62), (w * 0.4, HEAD_Y + 0.12, 1.58), (0, HEAD_Y + 0.2, 1.46),
                          (-w * 0.4, HEAD_Y + 0.12, 1.58), (-w * 0.5, HEAD_Y + 0.02, 1.62)], 0.02, m=m["black"], segs=6),
        cyl(p + "CupL", 0.08, 0.06, (w * 0.52, HEAD_Y, 1.6), rot=rad(0, 90, 0), segs=12, bevel=0.015, m=m["black"]),
        cyl(p + "CupR", 0.08, 0.06, (-w * 0.52, HEAD_Y, 1.6), rot=rad(0, 90, 0), segs=12, bevel=0.015, m=m["black"]),
        cyl(p + "PadL", 0.05, 0.065, (w * 0.53, HEAD_Y, 1.6), rot=rad(0, 90, 0), segs=10, bevel=0.0, m=m["cyan"]),
        cyl(p + "PadR", 0.05, 0.065, (-w * 0.53, HEAD_Y, 1.6), rot=rad(0, 90, 0), segs=10, bevel=0.0, m=m["cyan"]),
    ]
    bag = [
        box(p + "Bag", (0.46, 0.14, 0.3), (0.06, 0.27, 1.0), rot=rad(0, -8, 0), bevel=0.05, m=m["orange"]),
        box(p + "BagFlap", (0.47, 0.15, 0.14), (0.06, 0.27, 1.1), rot=rad(0, -8, 0), bevel=0.04, m=m["black"]),
        box(p + "BagReflect", (0.3, 0.155, 0.03), (0.06, 0.275, 1.04), rot=rad(0, -8, 0), bevel=0.0, m=m["reflect"]),
        tube(p + "Strap", [(-0.2, 0.2, 1.05), (-0.24, 0.0, 1.22), (-0.12, -0.22, 1.33), (0.12, -0.24, 1.2), (0.24, -0.1, 1.02)], 0.03,
             m=m["black"], segs=6),
    ]
    box_pack = [
        box(p + "Box", (0.5, 0.42, 0.5), (0, 0.42, 1.18), bevel=0.04, m=m["orange"]),
        box(p + "BoxLid", (0.52, 0.44, 0.06), (0, 0.42, 1.44), bevel=0.02, m=m["black"]),
        box(p + "BoxLogo", (0.3, 0.02, 0.2), (0, 0.635, 1.2), bevel=0.0, m=m["white"]),
        box(p + "BoxDent", (0.2, 0.06, 0.16), (0.16, 0.63, 1.04), rot=rad(0, 15, 10), bevel=0.02, m=m["soot"]),
        box(p + "StrapL", (0.06, 0.28, 0.04), (0.16, 0.12, 1.4), rot=rad(-20, 0, 0), bevel=0.01, m=m["black"]),
        box(p + "StrapR", (0.06, 0.28, 0.04), (-0.16, 0.12, 1.4), rot=rad(-20, 0, 0), bevel=0.01, m=m["black"]),
    ]
    acc = {
        "Acc_Courier_Helmet": bz.bind("Head", helmet),
        "Acc_Courier_Cap": bz.bind("Head", cap),
        "Acc_Courier_Phones": bz.bind("Head", phones),
        "Acc_Courier_Bag": bz.bind("Spine", bag),
        "Acc_Courier_Box": bz.bind("Spine", box_pack),
        "Acc_Courier_Hair": hair_top(p, w, m["dark"], "tufts", 41),
    }
    acc.update(faces("Courier", m, w, ("Gape", "Snarl", "Grin"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# The Worker (city_bruiser)
# ---------------------------------------------------------------------------

def worker(m):
    p = "W_"
    w = 0.64
    tee = m["shirt"]
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "flat", 51)
    tor, body = torso(p, tee, w=0.92, d=0.58, z0=0.88, z1=1.46, waist=0.9, belly=0.1, hunch=0.07, chest=1.05, hem=tee, hem_tear=2, seed=51)
    parts += tor
    parts += neck(p, m["skin"], 0.38, z1=1.46)
    t = tor[0]
    vest = body.shell(p + "Vest", m["hivis"], 1.4, 0.92, off=0.03, gap=70, tear=tear_fn(24, 51, 2, 0.05), segs=26, steps=4)
    kit = [
        vest,
        body.shell(p + "VestBandA", m["reflect"], 1.16, 1.1, off=0.038, gap=74, segs=26, steps=1, lip=0.01),
        body.shell(p + "VestBandB", m["reflect"], 1.03, 0.97, off=0.038, gap=74, segs=26, steps=1, lip=0.01),
        text(p + "BackText", "CREW", 0.13, 0.02, (0, body.front(0, 1.26, back=True, off=0.045), 1.26), rot=(0, 0, math.pi), m=m["dark"]),
        # Trapezius hump: the head sinks between the shoulders.
        blob(p + "Traps", (-0.37, 0.06, 1.43), (0.37, 0.06, 1.43), [(0, 0.06, 0.1), (0.3, 0.13, 0.12), (0.7, 0.13, 0.12), (1, 0.06, 0.1)],
             tee, n=2.4, r0=0.04, r1=0.04, segs=14, mid=6),
        box(p + "Pencil", (0.02, 0.02, 0.16), (0.24, body.front(0.24, 1.3) - 0.03, 1.32), rot=rad(0, 10, 0), bevel=0.0, m=m["hat"]),
    ]
    for side in (1, -1):
        kit.append(box(f"{p}VestStrap{side}", (0.17, 0.66, 0.08), (side * 0.29, 0.03, 1.44), rot=rad(0, -side * 8, 0), bevel=0.03, m=m["hivis"]))
        kit.append(box(f"{p}StrapBand{side}", (0.06, 0.67, 0.085), (side * 0.29, 0.03, 1.445), rot=rad(0, -side * 8, 0), bevel=0.0, m=m["reflect"]))
    kit += soot_marks(p, body, t, m, 51, count=7)
    parts += bz.bind("Spine", kit)
    parts += hips(p, m["denim"], w=0.82, d=0.56, z1=1.0, belt=m["leather"], buckle=m["steel"], belt_z=0.96)
    # Tool belt: pouches, a hammer, a tape measure.
    parts += bz.bind("Hips", [
        box(p + "PouchL", (0.2, 0.13, 0.2), (0.32, -0.2, 0.86), rot=rad(0, 0, 20), bevel=0.035, m=m["leather"]),
        box(p + "PouchR", (0.2, 0.13, 0.2), (-0.32, -0.2, 0.86), rot=rad(0, 0, -20), bevel=0.035, m=m["leather"]),
        cyl(p + "HammerGrip", 0.025, 0.3, (-0.4, -0.12, 0.8), rot=rad(0, 12, 0), segs=8, bevel=0.0, m=m["dark"]),
        box(p + "HammerHead", (0.18, 0.05, 0.05), (-0.42, -0.12, 0.96), bevel=0.012, m=m["steel"]),
        cyl(p + "Tape", 0.06, 0.05, (0.42, -0.07, 0.87), rot=rad(0, 90, 0), segs=12, bevel=0.01, m=m["hat"]),
    ])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.26, out=0.1, hand=0.08, sleeve=tee, sleeve_len="short", sleeve_tear=1, seed=53, nail=m["white"],
                     glove=m["leather"], fingers=3, curl=0.75)
        parts += leg(p, side, m, w=0.26, pants=m["denim"], pants_len="long", hem=m["denim_dark"], foot="boot", shoe=m["boot"], sole=m["dark"],
                     lace=m["hat"], toe=m["steel"], tear=1, seed=55, boot_h=0.22)
        # Popeye forearms.
        parts += bz.bind(f"ForeArm.{s}", [blob(f"{p}Forearm{s}", (side * 0.52, 0, 0.93), (side * 0.54, 0, 0.7),
                                               [(0, 0.12, 0.12), (0.45, 0.16, 0.15), (1, 0.11, 0.11)], m["skin"], n=2.6, r0=0.05, r1=0.05,
                                               segs=16, mid=4)])
        parts += bz.bind(f"Shin.{s}", [box(f"{p}KneePatch{s}", (0.16, 0.04, 0.14), (side * 0.16, -0.14, 0.45), bevel=0.03, m=m["denim_dark"])])
    return parts


def worker_accessories(m):
    p = "WA_"
    w = 0.64
    acc = {
        "Acc_Worker_HardHat": bz.bind("Head", [
            cap_crown(p + "Hat", w, m["hat"], rim=1.79, top=2.08, off=0.06, lip=0.03),
            band(p + "HatBrim", (0, HEAD_Y, 1.8), (0, HEAD_Y, 1.77), 0.44, 0.38, m["hat"], n=2.6, thick=0.03, flare=0.04, segs=26),
            box(p + "HatRidge", (0.08, 0.5, 0.06), (0, HEAD_Y, 2.06), bevel=0.025, m=m["hat"]),
            box(p + "HatSticker", (0.14, 0.02, 0.08), (0.0, HEAD_Y - 0.34, 1.9), rot=rad(-22, 0, 0), bevel=0.0, m=m["red"]),
            box(p + "HatScorch", (0.2, 0.18, 0.06), (-0.14, HEAD_Y + 0.12, 2.0), rot=rad(10, -25, 0), bevel=0.03, m=m["soot"]),
        ]),
        "Acc_Worker_Muffs": bz.bind("Head", [
            tube(p + "MuffBand", [(w * 0.52, HEAD_Y, 1.62), (w * 0.45, HEAD_Y - 0.02, 1.86), (0, HEAD_Y - 0.03, 1.98),
                                  (-w * 0.45, HEAD_Y - 0.02, 1.86), (-w * 0.52, HEAD_Y, 1.62)], 0.025, m=m["dark"], segs=6),
            cyl(p + "MuffL", 0.11, 0.09, (w * 0.54, HEAD_Y, 1.6), rot=rad(0, 90, 0), segs=14, bevel=0.025, m=m["red"]),
            cyl(p + "MuffR", 0.11, 0.09, (-w * 0.54, HEAD_Y, 1.6), rot=rad(0, 90, 0), segs=14, bevel=0.025, m=m["red"]),
        ]),
        "Acc_Worker_Mask": bz.bind("Head", [
            sphere(p + "Mask", 0.15, (0, face_y(w, 1.43) - 0.03, 1.43), scale=(1.15, 0.55, 0.8), m=m["black"], segs=14, rings=8),
            cyl(p + "FilterL", 0.06, 0.06, (0.13, face_y(w, 1.41) - 0.06, 1.4), rot=rad(90, 0, -35), segs=12, bevel=0.012, m=m["orange"]),
            cyl(p + "FilterR", 0.06, 0.06, (-0.13, face_y(w, 1.41) - 0.06, 1.4), rot=rad(90, 0, 35), segs=12, bevel=0.012, m=m["orange"]),
            box(p + "MaskStrap", (w * 1.02, 0.03, 0.03), (0, HEAD_Y + 0.02, 1.48), bevel=0.0, m=m["dark"]),
        ]),
        "Acc_Worker_Rebar": bz.bind("ForeArm.R", [
            tube(p + "Rebar", [(-0.56, -0.05, 0.62), (-0.57, -0.15, 0.36), (-0.6, -0.42, 0.1), (-0.62, -0.62, -0.05)], 0.03, m=m["rust"], segs=6),
        ] + [torus(f"{p}Rib{i}", 0.032, 0.008, (-0.57 - i * 0.008, -0.1 - i * 0.1, 0.42 - i * 0.12), rot=rad(60, 0, 0), m=m["rust"],
                   major_segs=8, minor_segs=3) for i in range(4)]),
    }
    acc.update(faces("Worker", m, w, ("Snarl", "Clench", "Gape"), tongue=m["red"]))
    return acc


def city_crowd_clips(rig):
    """zombie_city_crowd.glb: Commuter (shamble), Courier (sprint), Worker
    (style "Heavy": stomp, charge, slam, roar)."""
    return [idle(rig), gait(rig, "Walk", shamble()), gait(rig, "Run", flail_sprint()),
            idle(rig, "Idle_Heavy", heavy=True), gait(rig, "Walk_Heavy", stomp()), gait(rig, "Run_Heavy", charge()),
            attack(rig), attack_heavy(rig), roar(rig), stagger(rig), hit_head(rig), *deaths(rig), emerge(rig),
            stagger(rig, "Stagger_Heavy", heavy=True), emerge(rig, "Emerge_Heavy", heavy=True)]


def build():
    scene = reset_scene()
    scene.render.fps = bz.FPS
    m = materials()
    armature = bz.build_armature()
    meshes = [
        bz.skin("Outfit_Commuter", commuter(m), armature),
        bz.skin("Outfit_Courier", courier(m), armature),
        bz.skin("Outfit_Worker", worker(m), armature),
    ]
    accessories = {}
    accessories.update(commuter_accessories(m))
    accessories.update(courier_accessories(m))
    accessories.update(worker_accessories(m))
    for name, parts in accessories.items():
        meshes.append(bz.skin(name, parts, armature))
    zombie_anim.bake(armature, city_crowd_clips, "zombie_city_crowd")
    bz.save_zombie("zombie_city_crowd", [armature] + meshes)


if __name__ == "__main__":
    build()
