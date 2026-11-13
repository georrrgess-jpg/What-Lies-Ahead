"""Frostpeak Resort zombies: one rig (the same bones as build_zombie.py, which
this script reuses), three outfits.

    Outfit_Skier    Ski Racer: skin-tight tintable race suit, helmet with a glowing
                    visor, chunky ski boots; skis on its feet (Acc_Skier_Skis)
    Outfit_Yeti     Yeti brute: a hulking zombie in a shaggy tintable yeti costume
                    ("Shirt") with horns, a hood that frames its face, fur mitts
                    and a big zipper down the back
    Outfit_Frozen   Frozen Tourist: puffy jacket and bobble hat, encased in blue
                    ice (the ice is the Acc_Frozen_Ice mesh, which the game hides
                    when the shell shatters)

Bodies, heads and faces come from zombie_kit.py; each outfit has several faces
(Face_<Outfit>_<Preset>), one shown per zombie.

Clips (zombie_anim.frost_clips): the Frozen Tourist's stiff shuffle, the Ski
Racer's skate, the Yeti's stomp and slam ("_Heavy"), the shared set, plus
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
import zombie_anim  # noqa: E402
from zombie_kit import (HEAD_Y, cap_crown, head_band, arm, band, base_materials, blob, face_y, faces, glass, hair, head, hips, leg, neck,  # noqa: E402
                        patch, skull, torso)


def materials():
    m = base_materials("frost", skin="#8fc7b0", skin_dark="#5f9a86", dark="#1c2030", white="#f6f6ff")
    m.update(
        shirt=mat("Shirt", "#e0218a", rough=0.45),
        navy=mat("FrostNavy", "#1c2250", rough=0.35),
        accent=mat("FrostAccent", "#ffd23f", rough=0.5),
        visor=mat("FrostVisor", "#ff5a2a", rough=0.15, emit=1.5),
        ski=mat("FrostRaceSki", "#ff3f4f", rough=0.35),
        steel=mat("FrostZSteel", "#b8bccc", rough=0.3, metal=0.6),
        gold=mat("FrostGold", "#ffcf3f", rough=0.3, metal=0.6, emit=0.4),
        fur_light=mat("FrostFurLight", "#dfeeff", rough=0.85),
        horn=mat("FrostHorn", "#fff0d4", rough=0.5),
        red=mat("FrostScarfRed", "#e2343f", rough=0.7),
        pants=mat("FrostPants", "#232a5c", rough=0.65),
        mitten=mat("FrostMitten", "#ffd23f", rough=0.7),
        scarf=mat("FrostScarf", "#3fd4c4", rough=0.7),
        beanie=mat("FrostBeanie", "#ff7a2a", rough=0.75),
        lens=mat("CameraLens", "#5fd9ff", rough=0.15, emit=0.4),
        ice=glass("FrozenIceShell", "#3f9dff", alpha=0.62, emit=0.55, rough=0.12),
        ice_edge=glass("FrozenIceEdge", "#b8ecff", alpha=0.75, emit=0.9, rough=0.1),
    )
    return m


# ---------------------------------------------------------------------------
# Ski Racer
# ---------------------------------------------------------------------------

def skier(m):
    """Skin-tight race suit ("Shirt") with white and navy panels, helmet with a
    glowing visor, bib 07, chunky ski boots. Seven materials."""
    p = "S_"
    w = 0.54
    suit, white, navy = m["shirt"], m["white"], m["navy"]
    parts = head(p, m, w)
    sk = skull(w)
    fy = face_y(w, 1.66)
    parts += bz.bind("Head", [
        sk.shell(p + "Helmet", navy, 1.92, 1.5, off=0.04, gap=140, segs=26, steps=5, lip=0.03),
        cap_crown(p + "HelmetTop", w, navy, rim=1.805, top=2.03, off=0.04, segs=28),
        box(p + "HelmetStripe", (0.1, 0.64, 0.08), (0, HEAD_Y + 0.02, 2.0), bevel=0.03, m=m["accent"]),
        box(p + "Visor", (0.58, 0.1, 0.13), (0, fy - 0.07, 1.72), rot=rad(-6, 0, 0), bevel=0.05, segs=3, m=m["visor"]),
        box(p + "ChinGuard", (0.3, 0.1, 0.07), (0, face_y(w, 1.3) - 0.06, 1.262), bevel=0.03, m=navy),
    ])
    tor, body = torso(p, suit, w=0.52, d=0.37, z0=0.9, hunch=0.05)
    parts += tor
    parts += neck(p, navy, 0.22)
    t = tor[0]
    parts += bz.bind("Spine", [
        body.shell(p + "PanelL", white, 1.4, 0.94, off=0.012, gap=300, gap_at=-90, segs=24, steps=4, lip=0.01),
        patch(p + "Bib", t, (0, body.front(0, 1.13), 1.13), (0.34, 0.04, 0.32), white, bevel=0.02),
        patch(p + "BibBack", t, (0, body.front(0, 1.13, back=True), 1.13), (0.34, 0.04, 0.32), white, bevel=0.02),
        text(p + "BibNum", "07", 0.2, 0.02, (0, body.front(0, 1.12) - 0.03, 1.12), m=navy),
        text(p + "BibNumBack", "07", 0.2, 0.02, (0, body.front(0, 1.12, back=True) + 0.03, 1.12), rot=(0, 0, math.pi), m=navy),
    ])
    parts += hips(p, suit, w=0.5, d=0.37, belt=navy)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        x = side * 0.16
        parts += arm(p, side, m, w=0.15, sleeve=suit, sleeve_len="long", cuff=m["accent"], glove=navy, seed=31)
        parts += leg(p, side, m, w=0.17, pants=suit, pants_len="long", foot="boot", shoe=white, sole=navy, lace=m["accent"], boot_h=0.24, tear=0)
        parts += bz.bind(f"Shin.{s}", [box(f"{p}BootBuckle{s}{i}", (0.24, 0.05, 0.035), (x, -0.13, 0.2 + i * 0.09), bevel=0.01, m=navy)
                                       for i in range(2)])
        parts += bz.bind(f"Thigh.{s}", [box(f"{p}Stripe{s}", (0.03, 0.08, 0.3), (side * 0.255, 0, 0.64), bevel=0.0, m=white)])
    return parts


def ski(name, x, m, tip):
    """A race ski under the boot (Shin-bound), its tip curled up."""
    return [
        blob(name, (x, 0.42, 0.012), (x, -0.62, 0.012), [(0, 0.05, 0.016), (0.5, 0.055, 0.016), (1, 0.06, 0.016)], m, n=4.0, r0=0.012, r1=0.0,
             segs=14, mid=4),
        tube(name + "Tip", [(x, -0.62, 0.012), (x, -0.72, 0.03), (x, -0.78, 0.08)], 0.018, m=m, segs=6, radius_end=0.012),
        box(name + "TipPlate", (0.12, 0.12, 0.022), (x, -0.73, 0.045), rot=rad(28, 0, 0), bevel=0.008, m=m),
        box(name + "Binding", (0.13, 0.2, 0.04), (x, -0.08, 0.03), bevel=0.012, m=tip),
    ]


def skier_accessories(m):
    p = "SA_"
    skis = bz.bind("Shin.L", ski(p + "SkiL", 0.16, m["ski"], m["navy"])) + bz.bind("Shin.R", ski(p + "SkiR", -0.16, m["ski"], m["navy"]))
    poles = []
    for side, s in ((1, "L"), (-1, "R")):
        gx = side * 0.435
        poles += bz.bind(f"ForeArm.{s}", [
            cyl(f"{p}Pole{s}", 0.018, 1.0, (gx, -0.07, 0.2), rot=rad(12, 0, 0), segs=6, bevel=0.0, m=m["steel"]),
            cyl(f"{p}Basket{s}", 0.07, 0.02, (gx, 0.0, -0.22), rot=rad(12, 0, 0), segs=10, bevel=0.0, m=m["navy"]),
            cyl(f"{p}Grip{s}", 0.03, 0.1, (gx, -0.08, 0.56), rot=rad(12, 0, 0), segs=8, bevel=0.01, m=m["navy"]),
        ])
    acc = {
        "Acc_Skier_Skis": skis,
        "Acc_Skier_Poles": poles,
        "Acc_Skier_Medal": bz.bind("Spine", [
            cyl(p + "Medal", 0.07, 0.02, (0.0, -0.235, 1.2), rot=rad(90, 0, 0), segs=14, bevel=0.0, m=m["gold"]),
            tube(p + "Ribbon", [(-0.17, -0.08, 1.42), (0.0, -0.225, 1.26), (0.17, -0.08, 1.42)], 0.015, m=m["accent"], segs=5),
        ]),
        "Acc_Skier_Goggles": bz.bind("Head", [
            box(p + "Goggles", (0.44, 0.08, 0.12), (0, HEAD_Y - 0.25, 1.9), rot=rad(-25, 0, 0), bevel=0.04, m=m["accent"]),
            box(p + "GoggleLens", (0.38, 0.06, 0.09), (0, HEAD_Y - 0.28, 1.9), rot=rad(-25, 0, 0), bevel=0.03, m=m["lens"]),
        ]),
    }
    acc.update(faces("Skier", m, 0.54, ("Grin", "Snarl", "Gape"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Yeti costume brute
# ---------------------------------------------------------------------------

def fur_clumps(prefix, bone, centre, radii, count, m, seed, size=0.11, keep=None):
    """Shaggy fur tufts scattered over an ellipsoid; keep(x, y, z) filters them
    (the face stays clear)."""
    rng = random.Random(seed)
    out = []
    i = 0
    while len(out) < count and i < count * 6:
        i += 1
        a = rng.uniform(0, math.tau)
        z = rng.uniform(-1, 1)
        r = math.sqrt(1 - z * z)
        pos = (centre[0] + math.cos(a) * r * radii[0], centre[1] + math.sin(a) * r * radii[1], centre[2] + z * radii[2])
        if keep and not keep(*pos):
            continue
        out.append(sphere(f"{prefix}{len(out):02d}", size * rng.uniform(0.75, 1.25), pos, scale=(1, 1, 1.45),
                          rot=(rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 0), m=m, segs=8, rings=5))
    return bz.bind(bone, out)


def yeti(m):
    """A hulking zombie in a shaggy yeti costume ("Shirt", tinted): hood with horns
    framing the face, white belly and face rim, fur mitts with claws."""
    p = "Y_"
    w = 0.64
    fur, light, horn = m["shirt"], m["fur_light"], m["horn"]
    parts = head(p, m, w, ears=False)
    sk = skull(w)
    parts += bz.bind("Head", [
        sk.shell(p + "Hood", fur, 1.98, 1.3, off=0.07, gap=138, segs=28, steps=7, lip=0.05),
        sphere(p + "HoodTop", 0.4, (0, HEAD_Y + 0.05, 1.88), scale=(1.0, 0.98, 0.62), m=fur, segs=18, rings=9),
        torus(p + "FaceRim", 0.31, 0.065, (0, face_y(w, 1.58) + 0.04, 1.59), rot=rad(90, 0, 0), m=light, major_segs=28, minor_segs=8),
        tube(p + "HornL", [(-0.3, HEAD_Y + 0.06, 1.98), (-0.48, HEAD_Y + 0.0, 2.18), (-0.5, HEAD_Y - 0.09, 2.36)], 0.085, m=horn, segs=8, radius_end=0.02),
        tube(p + "HornR", [(0.3, HEAD_Y + 0.06, 1.98), (0.48, HEAD_Y + 0.0, 2.18), (0.5, HEAD_Y - 0.09, 2.36)], 0.085, m=horn, segs=8, radius_end=0.02),
        sphere(p + "EarL", 0.11, (-0.47, HEAD_Y + 0.12, 1.74), scale=(0.6, 1, 1.3), m=fur, segs=8, rings=5),
        sphere(p + "EarR", 0.11, (0.47, HEAD_Y + 0.12, 1.74), scale=(0.6, 1, 1.3), m=fur, segs=8, rings=5),
    ])
    # Hood tufts on the crown and back only: the face stays clear.
    parts += fur_clumps(p + "HoodFur", "Head", (0, HEAD_Y + 0.12, 1.78), (0.42, 0.32, 0.3), 12, fur, 3,
                        keep=lambda x, y, z: y > HEAD_Y + 0.04 or z > 1.98)
    tor, body = torso(p, fur, w=1.04, d=0.68, z0=0.86, z1=1.48, waist=0.86, belly=0.1, hunch=0.12, chest=1.06, n=2.8)
    parts += tor
    parts += neck(p, fur, 0.44, z1=1.48)
    parts += bz.bind("Spine", [
        sphere(p + "Belly", 0.3, (0, body.front(0, 1.04) + 0.07, 1.04), scale=(1.05, 0.42, 1.15), m=light, segs=18, rings=10),
        patch(p + "Zip", tor[0], (0, body.front(0, 1.12, back=True), 1.12), (0.05, 0.04, 0.62), m["white"], bevel=0.01),
        box(p + "ZipPull", (0.06, 0.05, 0.12), (0, body.front(0, 1.4, back=True) + 0.04, 1.4), bevel=0.01, m=m["white"]),
        # Hulking shoulder mass.
        blob(p + "Traps", (-0.44, 0.08, 1.44), (0.44, 0.08, 1.44), [(0, 0.08, 0.12), (0.3, 0.17, 0.16), (0.7, 0.17, 0.16), (1, 0.08, 0.12)], fur,
             n=2.4, r0=0.05, r1=0.05, segs=16, mid=6),
    ])
    parts += fur_clumps(p + "BodyFur", "Spine", (0, 0.03, 1.16), (0.54, 0.38, 0.32), 22, fur, 5, size=0.14,
                        keep=lambda x, y, z: y > -0.1 or abs(x) > 0.3)
    parts += fur_clumps(p + "ShoulderFur", "Spine", (0, 0.06, 1.44), (0.56, 0.3, 0.08), 12, fur, 6, size=0.15)
    parts += hips(p, fur, w=0.9, d=0.62, z0=0.72)
    parts += fur_clumps(p + "HipFur", "Hips", (0, 0, 0.8), (0.47, 0.33, 0.1), 12, fur, 7, size=0.12)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.3, skin=fur, sleeve=fur, sleeve_len="long", glove=fur, hand=0.1, out=0.14, nail=horn, curl=0.8, seed=33)
        parts += leg(p, side, m, w=0.3, skin=fur, pants=fur, pants_len="long", foot="bare", tear=0)
        parts += fur_clumps(f"{p}ArmFur{s}", f"UpperArm.{s}", (side * 0.54, 0, 1.12), (0.14, 0.14, 0.14), 6, fur, 8 + side, size=0.11)
        parts += fur_clumps(f"{p}ForeFur{s}", f"ForeArm.{s}", (side * 0.56, 0, 0.82), (0.14, 0.14, 0.12), 5, fur, 12 + side, size=0.1)
        parts += fur_clumps(f"{p}ThighFur{s}", f"Thigh.{s}", (side * 0.17, 0, 0.62), (0.17, 0.17, 0.1), 6, fur, 10 + side, size=0.11)
        parts += bz.bind(f"Shin.{s}", [cyl(f"{p}Claw{s}{i}", 0.025, 0.07, (side * 0.16 + (i - 1) * 0.06, -0.27, 0.04), rot=rad(-90, 0, 0), segs=6,
                                           bevel=0.0, m=horn, radius_top=0.004) for i in range(3)])
    return parts


def yeti_accessories(m):
    p = "YA_"
    acc = {
        # Worn low, round the neck and chest: the mouth stays clear.
        "Acc_Yeti_Scarf": bz.bind("Spine", [
            torus(p + "Scarf", 0.42, 0.09, (0, 0.0, 1.3), rot=rad(22, 0, 0), m=m["red"], major_segs=22, minor_segs=7),
            box(p + "ScarfTail", (0.16, 0.06, 0.46), (0.26, -0.47, 1.0), rot=rad(8, 0, 12), bevel=0.03, m=m["red"]),
            box(p + "ScarfStripe", (0.17, 0.07, 0.06), (0.27, -0.48, 0.86), rot=rad(8, 0, 12), bevel=0.01, m=m["white"]),
        ]),
        "Acc_Yeti_Tag": bz.bind("Spine", [
            box(p + "Tag", (0.26, 0.03, 0.16), (-0.24, -0.4, 1.22), rot=rad(0, 0, 10), bevel=0.02, m=m["white"]),
            text(p + "TagText", "STAFF", 0.06, 0.01, (-0.24, -0.42, 1.22), rot=(0, 0, math.radians(10)), m=m["navy"]),
        ]),
        "Acc_Yeti_Beanie": bz.bind("Head", [
            sphere(p + "Beanie", 0.2, (0, HEAD_Y + 0.02, 2.12), scale=(1.0, 1.0, 0.75), m=m["beanie"], segs=14, rings=8),
            sphere(p + "Pom", 0.07, (0, HEAD_Y + 0.02, 2.28), m=m["white"], segs=8, rings=6),
        ]),
        "Acc_Yeti_Goggles": bz.bind("Head", [
            box(p + "Goggles", (0.5, 0.08, 0.13), (0, HEAD_Y - 0.25, 1.96), rot=rad(-30, 0, 0), bevel=0.04, m=m["accent"]),
            box(p + "GoggleLens", (0.44, 0.06, 0.1), (0, HEAD_Y - 0.28, 1.96), rot=rad(-30, 0, 0), bevel=0.035, m=m["visor"]),
        ]),
        "Acc_Yeti_Snowball": bz.bind("ForeArm.R", [sphere(p + "Snowball", 0.14, (-0.58, -0.12, 0.42), m=m["white"], segs=14, rings=9)]),
    }
    acc.update(faces("Yeti", m, 0.64, ("Snarl", "Clench", "Gape"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Frozen Tourist
# ---------------------------------------------------------------------------

def frozen(m):
    """Puffy quilted jacket ("Shirt"), scarf, ski pants, mittens, snow boots."""
    p = "F_"
    w = 0.62
    jacket = m["shirt"]
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "fringe", 17)
    tor, body = torso(p, jacket, w=0.8, d=0.56, z0=0.86, belly=0.06, hunch=0.04, n=2.6)
    parts += tor
    parts += neck(p, m["skin"], 0.26)
    puff = [body.shell(f"{p}Quilt{i}", jacket, z + 0.05, z - 0.05, off=0.015 + 0.012 * (i % 2), segs=24, steps=2, lip=0.02)
            for i, z in enumerate((0.95, 1.07, 1.19, 1.31))]
    parts += bz.bind("Spine", puff + [
        patch(p + "Zip", tor[0], (0, body.front(0, 1.12), 1.12), (0.04, 0.05, 0.56), m["white"], bevel=0.01),
        torus(p + "Scarf", 0.27, 0.08, (0, -0.01, 1.44), m=m["scarf"], major_segs=20, minor_segs=7),
        box(p + "ScarfTail", (0.14, 0.05, 0.42), (-0.16, body.front(-0.16, 1.24) - 0.05, 1.24), rot=rad(6, 0, -10), bevel=0.02, m=m["scarf"]),
        band(p + "Collar", (0, 0.0, 1.47), (0, 0.0, 1.38), 0.26, 0.24, jacket, n=2.6, thick=0.03, flare=0.03, segs=22),
    ])
    parts += hips(p, m["pants"], w=0.68, d=0.48)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.21, sleeve=jacket, sleeve_len="long", cuff=m["white"], glove=m["mitten"], fingers=0, seed=35)
        parts += leg(p, side, m, w=0.22, pants=m["pants"], pants_len="long", foot="boot", shoe=m["white"], sole=m["dark"], lace=m["white"],
                     boot_h=0.2, tear=0)
        parts += bz.bind(f"UpperArm.{s}", [band(f"{p}ArmPuff{s}", (side * 0.39, 0, 1.18), (side * 0.4, 0, 1.08), 0.13, 0.13, jacket, n=2.4,
                                                thick=0.02, flare=0.01, segs=16)])
        parts += bz.bind(f"Shin.{s}", [sphere(f"{p}BootFur{s}", 0.13, (side * 0.16, 0.0, 0.33), scale=(1.0, 1.0, 0.42), m=m["white"], segs=14, rings=7)])
    return parts


def crystal(name, size, loc, rot, m):
    """A sharp-edged ice block (no bevel: the facets catch the light)."""
    return box(name, size, loc, rot=rot, bevel=0.0, m=m)


def shard(name, radius, length, loc, rot, m):
    return cyl(name, radius, length, loc, rot=rot, segs=5, bevel=0.0, m=m, radius_top=0.01)


def frozen_accessories(m):
    p = "FA_"
    ice, edge = m["ice"], m["ice_edge"]
    acc = {
        "Acc_Frozen_Ice": (
            bz.bind("Spine", [
                crystal(p + "Torso", (1.0, 0.76, 0.8), (0.02, 0, 1.12), rad(4, -3, 6), ice),
                shard(p + "ShardA", 0.11, 0.6, (0.42, 0.12, 1.52), rad(-20, 35, 0), edge),
                shard(p + "ShardB", 0.09, 0.5, (-0.4, 0.18, 1.54), rad(-25, -40, 0), edge),
                shard(p + "ShardC", 0.1, 0.55, (0.1, 0.38, 1.47), rad(-55, 0, 0), edge),
                shard(p + "ShardD", 0.08, 0.42, (-0.3, -0.3, 1.38), rad(30, -20, 10), edge),
            ])
            + bz.bind("Hips", [crystal(p + "Hips", (0.88, 0.68, 0.42), (0, 0.02, 0.82), rad(0, 4, -5), ice),
                               shard(p + "HipShard", 0.08, 0.4, (0.36, -0.2, 0.86), rad(40, 30, 0), edge)])
            + bz.bind("Head", [
                crystal(p + "HeadPlate", (0.34, 0.64, 0.58), (0.28, HEAD_Y + 0.04, 1.64), rad(0, -12, 8), ice),
                shard(p + "HeadShard", 0.1, 0.5, (0.18, HEAD_Y + 0.08, 1.98), rad(0, -25, 0), edge),
            ])
            + bz.bind("Thigh.L", [crystal(p + "ThighL", (0.38, 0.42, 0.4), (0.17, 0, 0.6), rad(0, 0, 6), ice)])
            + bz.bind("Thigh.R", [crystal(p + "ThighR", (0.38, 0.42, 0.4), (-0.17, 0, 0.6), rad(0, 0, -4), ice)])
            + bz.bind("UpperArm.L", [crystal(p + "ArmL", (0.32, 0.34, 0.38), (0.42, 0, 1.12), rad(0, 8, 0), ice)])
            + bz.bind("ForeArm.R", [crystal(p + "ForeR", (0.26, 0.28, 0.3), (-0.43, 0, 0.8), rad(0, -6, 4), ice)])
        ),
        "Acc_Frozen_Beanie": bz.bind("Head", [
            cap_crown(p + "Beanie", 0.62, m["beanie"], rim=1.74, top=2.06),
            head_band(p + "BeanieCuff", 0.62, 1.81, 1.715, m["white"], off=0.04, thick=0.03),
            sphere(p + "Pompom", 0.1, (0, HEAD_Y + 0.02, 2.08), m=m["white"], segs=10, rings=7),
        ]),
        "Acc_Frozen_Earmuffs": bz.bind("Head", [
            sphere(p + "MuffL", 0.1, (-0.34, HEAD_Y + 0.02, 1.58), scale=(0.7, 1, 1), m=m["beanie"], segs=10, rings=6),
            sphere(p + "MuffR", 0.1, (0.34, HEAD_Y + 0.02, 1.58), scale=(0.7, 1, 1), m=m["beanie"], segs=10, rings=6),
            tube(p + "MuffBand", [(-0.33, HEAD_Y + 0.02, 1.64), (-0.2, HEAD_Y + 0.02, 1.92), (0.2, HEAD_Y + 0.02, 1.92), (0.33, HEAD_Y + 0.02, 1.64)],
                 0.025, m=m["steel"], segs=5),
        ]),
        "Acc_Frozen_Camera": bz.bind("Spine", [
            box(p + "CamBody", (0.22, 0.09, 0.14), (0.08, -0.36, 1.06), bevel=0.025, m=m["dark"]),
            cyl(p + "CamLens", 0.045, 0.07, (0.1, -0.42, 1.05), rot=rad(90, 0, 0), segs=12, bevel=0.01, m=m["lens"]),
        ]),
    }
    acc.update(faces("Frozen", m, 0.62, ("Gape", "Clench", "Sleepy"), tongue=m["red"]))
    return acc


def build():
    scene = reset_scene()
    scene.render.fps = bz.FPS
    m = materials()
    armature = bz.build_armature()
    meshes = [
        bz.skin("Outfit_Skier", skier(m), armature),
        bz.skin("Outfit_Yeti", yeti(m), armature),
        bz.skin("Outfit_Frozen", frozen(m), armature),
    ]
    accessories = {}
    accessories.update(skier_accessories(m))
    accessories.update(yeti_accessories(m))
    accessories.update(frozen_accessories(m))
    for name, parts in accessories.items():
        meshes.append(bz.skin(name, parts, armature))
    zombie_anim.bake(armature, zombie_anim.frost_clips, "frost_zombies")
    bz.save_zombie("frost_zombies", [armature] + meshes)


if __name__ == "__main__":
    build()
