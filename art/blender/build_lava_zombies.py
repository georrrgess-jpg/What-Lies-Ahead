"""Volcano Isle zombies (World 9, Lava Lagoon): the shared rig (build_zombie.py),
three outfits.

    Outfit_Dancer     Fire Dancer: bare-chested luau fire dancer with a tintable
                      sarong ("Shirt") over a straw grass skirt, a flower lei,
                      shell anklets and a feathered headband; a fire poi in
                      each hand (Acc_Dancer_Poi)
    Outfit_Bartender  Tiki Bartender: tintable Hawaiian shirt with hibiscus
                      prints, white apron, bow tie, slacks; a carved tiki mask
                      pushed up on the forehead and a coconut in hand
    Outfit_Kahuna     Kahuna Krakatoa (the alpha): a hulking chief in a feathered
                      cape ("Shirt"), a towering carved tiki headdress, a shell
                      necklace, ember arm bands and a grass skirt

Clips (lava_clips below, built from zombie_anim): the shared set, the Fire
Dancer's crouched spin-up ("Tuck") before its dash, the Bartender's two-handed
overhead coconut heave ("Throw") and the Kahuna's stomp and slam ("_Heavy").

    python art/blender/build_lava_zombies.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lava_common import *  # noqa: F401,F403
import build_zombie as bz  # noqa: E402
import zombie_anim  # noqa: E402
from zombie_anim import (attack, attack_heavy, flail_sprint, gait, idle, roar, shamble, stagger, stomp, throw, tuck,  # noqa: E402
                         hit_head, deaths, emerge)
from zombie_kit import (HEAD_Y, SPARK_EYE, cap_crown, head_band, arm, band, base_materials, blob, face_y, faces, hair,  # noqa: E402
                        head, hips, leg, neck, patch, skull, torso, decal)


def materials():
    m = base_materials("lava", skin="#9ccf6a", skin_dark="#6a9a44", dark="#1e1824", white="#f6f2ec", eye=(SPARK_EYE, 2.6))
    m.update(
        shirt=mat("Shirt", "#ff4f9a", rough=0.5),
        straw=mat("LavaZStraw", "#d6a85a", rough=0.85),
        straw_dark=mat("LavaZStrawDark", "#9a7034", rough=0.85),
        flower=mat("LavaZFlower", "#ff5fa8", rough=0.5),
        petal=mat("LavaZPetal", "#ffd23f", rough=0.5),
        leaf=mat("LavaZLeaf", "#2f9a52", rough=0.7),
        fire=mat("LavaZFire", "#ffa02a", rough=0.3, emit=4.0),
        chain=mat("LavaZChain", "#8b8a9c", rough=0.3, metal=0.7),
        wood=mat("LavaZWood", "#8a5530", rough=0.7),
        wood_dark=mat("LavaZWoodDark", "#55311f", rough=0.7),
        teal=mat("LavaZTeal", "#22c6b8", rough=0.5),
        apron=mat("LavaZApron", "#f3ece0", rough=0.7),
        slacks=mat("LavaZSlacks", "#2b2a3c", rough=0.7),
        coconut=mat("LavaZCoconut", "#5a3a22", rough=0.8),
        shell=mat("LavaZShell", "#fff0d4", rough=0.4),
        ember=mat("LavaZEmber", "#ff5a1a", rough=0.4, emit=2.4),
        red=mat("LavaZRed", "#e2343f", rough=0.6),
    )
    return m


def grass_skirt(p, m, z_top, z_bottom, radius, count=22, seed=4, bone="Hips", flare=0.12):
    """A ring of straw strands hanging from the waist."""
    rng = random.Random(seed)
    parts = []
    for i in range(count):
        a = math.tau * i / count + rng.uniform(-0.05, 0.05)
        r0, r1 = radius, radius + flare
        top = (math.cos(a) * r0, math.sin(a) * r0 * 0.82, z_top)
        bot = (math.cos(a) * r1, math.sin(a) * r1 * 0.82, z_bottom + rng.uniform(-0.05, 0.04))
        parts.append(tube(f"{p}Straw{i:02d}", [top, bot], 0.05, m=m["straw"] if i % 3 else m["straw_dark"], segs=4, radius_end=0.02))
    return bz.bind(bone, parts)


def lei(p, m, z, radius, count=12, bone="Spine", tilt=18):
    """A flower lei round the neck: alternating pink and yellow blossoms."""
    parts = []
    for i in range(count):
        a = math.tau * i / count
        x, y = math.cos(a) * radius, math.sin(a) * radius * 0.8
        zz = z - (0.06 if y < 0 else 0.0) - math.sin(math.radians(tilt)) * max(0.0, -y) * 0.6
        parts.append(sphere(f"{p}Lei{i:02d}", 0.06, (x, y, zz), scale=(1, 1, 0.75), m=m["flower"] if i % 2 else m["petal"], segs=8, rings=5))
    return bz.bind(bone, parts)


# ---------------------------------------------------------------------------
# Fire Dancer
# ---------------------------------------------------------------------------

def dancer(m):
    p = "D_"
    w = 0.54
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "mop", 21)
    parts += bz.bind("Head", [head_band(p + "Band", w, 1.86, 1.78, m["teal"], off=0.035, thick=0.025)] +
                     [prism(f"{p}Feather{i}", [(-0.05, 0), (0.05, 0), (0.03, 0.34), (0, 0.38), (-0.03, 0.34)], 0.03,
                            (math.sin(math.radians(a)) * 0.3, math.cos(math.radians(a)) * 0.28, 1.86),
                            rot=(0, math.radians(a * 0.4), 0), m=(m["flower"], m["petal"], m["teal"])[i % 3])
                      for i, a in enumerate((-50, -25, 0, 25, 50))])
    tor, body = torso(p, m["skin"], w=0.56, d=0.36, z0=0.92, hunch=0.04, n=3.0)
    parts += tor
    parts += neck(p, m["skin"], 0.22)
    parts += lei(p, m, 1.42, 0.25)
    parts += bz.bind("Spine", [band(p + "Sash", (0, 0, 1.02), (0, 0, 0.94), 0.29, 0.2, m["shirt"], n=2.6, thick=0.02, flare=0.01, segs=20)])
    parts += hips(p, m["shirt"], w=0.52, d=0.38, belt=m["teal"])
    parts += grass_skirt(p, m, 0.92, 0.5, 0.27, count=20, seed=6)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.15, sleeve_len="none", seed=41)
        parts += bz.bind(f"ForeArm.{s}", [torus(f"{p}Cuff{s}", 0.075, 0.025, (side * 0.56, 0, 0.88), rot=rad(0, 90, 0), m=m["petal"],
                                                major_segs=10, minor_segs=4)])
        parts += leg(p, side, m, w=0.17, pants_len="none", foot="bare", tear=0)
        parts += bz.bind(f"Shin.{s}", [torus(f"{p}Anklet{s}{i}", 0.085, 0.025, (side * 0.16, 0, 0.2 + i * 0.05), m=m["shell"],
                                             major_segs=10, minor_segs=4) for i in range(2)])
    return parts


def poi(name, x, m):
    """A fire poi hanging from the hand: chain and a blazing wick ball."""
    return [cyl(name + "Chain", 0.012, 0.42, (x, -0.06, 0.5), segs=5, bevel=0.0, m=m["chain"]),
            sphere(name + "Ball", 0.11, (x, -0.06, 0.25), m=m["wood_dark"], segs=10, rings=6),
            sphere(name + "Flame", 0.16, (x, -0.06, 0.3), scale=(1, 1, 1.5), m=m["fire"], segs=10, rings=6)]


def dancer_accessories(m):
    p = "DA_"
    acc = {
        "Acc_Dancer_Poi": bz.bind("ForeArm.L", poi(p + "PoiL", 0.6, m)) + bz.bind("ForeArm.R", poi(p + "PoiR", -0.6, m)),
        "Acc_Dancer_Flower": bz.bind("Head", flower(p + "Hib", (0.28, HEAD_Y - 0.05, 1.78), 0.11, m=m["flower"], centre=m["petal"])),
        "Acc_Dancer_Paint": bz.bind("Head", [box(p + "StripeL", (0.12, 0.02, 0.03), (-0.17, face_y(0.54, 1.5) - 0.01, 1.5), bevel=0.0, m=m["ember"]),
                                              box(p + "StripeR", (0.12, 0.02, 0.03), (0.17, face_y(0.54, 1.5) - 0.01, 1.5), bevel=0.0, m=m["ember"])]),
    }
    acc.update(faces("Dancer", m, 0.54, ("Grin", "Snarl", "Gape"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Tiki Bartender
# ---------------------------------------------------------------------------

def bartender(m):
    p = "B_"
    w = 0.6
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "fringe", 23)
    tor, body = torso(p, m["shirt"], w=0.74, d=0.5, z0=0.88, belly=0.08, hunch=0.04, n=2.8, hem=m["shirt"])
    parts += tor
    parts += neck(p, m["skin"], 0.25)
    t = tor[0]
    prints = []
    rng = random.Random(9)
    for i in range(9):
        a = rng.uniform(-1.3, 1.3)
        z = rng.uniform(0.98, 1.36)
        x = math.sin(a) * 0.3
        prints.append(decal(f"{p}Print{i}", t, (x, body.front(x, z), z), 0.055, m["petal"] if i % 2 else m["apron"], petals=5))
    for i in range(5):
        x = rng.uniform(-0.25, 0.25)
        z = rng.uniform(1.0, 1.35)
        prints.append(decal(f"{p}PrintB{i}", t, (x, body.front(x, z, back=True), z), 0.055, m["petal"], petals=5))
    parts += bz.bind("Spine", prints + [
        patch(p + "Apron", t, (0, body.front(0, 1.0), 1.0), (0.46, 0.04, 0.3), m["apron"], bevel=0.01),
        box(p + "BowL", (0.1, 0.05, 0.08), (-0.06, body.front(0, 1.4) - 0.06, 1.42), rot=(0, 0, 0.3), bevel=0.02, m=m["red"]),
        box(p + "BowR", (0.1, 0.05, 0.08), (0.06, body.front(0, 1.4) - 0.06, 1.42), rot=(0, 0, -0.3), bevel=0.02, m=m["red"]),
        box(p + "Collar", (0.36, 0.08, 0.06), (0, body.front(0, 1.44) - 0.02, 1.45), bevel=0.02, m=m["shirt"]),
    ])
    parts += hips(p, m["slacks"], w=0.66, d=0.46, belt=m["dark"])
    parts += bz.bind("Hips", [box(p + "ApronLow", (0.5, 0.04, 0.5), (0, -0.25, 0.68), bevel=0.02, m=m["apron"]),
                              box(p + "Towel", (0.12, 0.03, 0.3), (0.28, -0.24, 0.78), bevel=0.01, m=m["teal"])])
    for side in (1, -1):
        parts += arm(p, side, m, w=0.18, sleeve=m["shirt"], sleeve_len="short", seed=43)
        parts += leg(p, side, m, w=0.2, pants=m["slacks"], pants_len="long", foot="shoe", shoe=m["dark"], sole=m["white"], lace=m["white"], tear=0)
    return parts


def bartender_accessories(m):
    p = "BA_"
    w = 0.6
    mask_y = HEAD_Y - 0.1
    mask = [box(p + "Mask", (0.46, 0.12, 0.42), (0, mask_y - 0.2, 2.02), rot=rad(-35, 0, 0), bevel=0.05, m=m["wood"])]
    mask += [cyl(f"{p}MaskEye{s}", 0.06, 0.05, (s * 0.1, mask_y - 0.3, 2.1), rot=rad(55, 0, 0), segs=10, bevel=0.0, m=m["teal"]) for s in (-1, 1)]
    mask += [box(p + "MaskMouth", (0.26, 0.05, 0.06), (0, mask_y - 0.33, 1.94), rot=rad(-35, 0, 0), bevel=0.01, m=m["wood_dark"])]
    acc = {
        "Acc_Bartender_Mask": bz.bind("Head", mask),
        "Acc_Bartender_Flower": bz.bind("Head", flower(p + "Hib", (-0.31, HEAD_Y, 1.72), 0.1, m=m["flower"], centre=m["petal"])),
        "Acc_Bartender_Coconut": bz.bind("ForeArm.R", [sphere(p + "Nut", 0.13, (-0.6, -0.1, 0.5), m=m["coconut"], segs=10, rings=7),
                                                       cyl(p + "Straw", 0.01, 0.22, (-0.58, -0.12, 0.66), rot=(0.3, 0, 0), segs=4, bevel=0.0, m=m["flower"])]),
        "Acc_Bartender_Lei": lei(p, m, 1.44, 0.3),
    }
    acc.update(faces("Bartender", m, w, ("Grin", "Clench", "Gape"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Kahuna Krakatoa (the alpha)
# ---------------------------------------------------------------------------

def kahuna(m):
    p = "K_"
    w = 0.66
    parts = head(p, m, w)
    tor, body = torso(p, m["skin"], w=1.0, d=0.66, z0=0.86, z1=1.48, waist=0.86, belly=0.12, hunch=0.12, chest=1.06, n=2.8)
    parts += tor
    parts += neck(p, m["skin"], 0.42, z1=1.48)
    # Feathered cape over the back and shoulders (tinted "Shirt").
    cape = [blob(p + "Mantle", (-0.56, 0.12, 1.44), (0.56, 0.12, 1.44), [(0, 0.1, 0.12), (0.3, 0.2, 0.17), (0.7, 0.2, 0.17), (1, 0.1, 0.12)],
                 m["shirt"], n=2.4, r0=0.06, r1=0.06, segs=16, mid=6)]
    for i in range(11):
        x = -0.5 + i * 0.1
        cape.append(prism(f"{p}Cape{i}", [(-0.07, 0), (0.07, 0), (0.05, -0.62), (0, -0.7), (-0.05, -0.62)], 0.05, (x, 0.34, 1.46),
                          rot=(math.radians(-12), 0, 0), m=m["shirt"] if i % 3 else m["petal"]))
    parts += bz.bind("Spine", cape + [
        torus(p + "Necklace", 0.38, 0.03, (0, -0.02, 1.4), rot=rad(20, 0, 0), m=m["shell"], major_segs=18, minor_segs=4),
    ] + [cyl(f"{p}Tooth{i}", 0.035, 0.14, (math.cos(a) * 0.36, -math.sin(a) * 0.3 - 0.05, 1.3 - 0.03 * abs(i - 3)), rot=(0, 0, 0), segs=5,
             bevel=0.0, m=m["shell"], radius_top=0.005) for i, a in enumerate([math.radians(40 + k * 17) for k in range(7)])])
    parts += hips(p, m["wood_dark"], w=0.9, d=0.62, z0=0.72, belt=m["teal"])
    parts += grass_skirt(p, m, 0.86, 0.38, 0.44, count=26, seed=8, flare=0.16)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.3, sleeve_len="none", hand=0.1, out=0.14, curl=0.8, seed=47)
        parts += leg(p, side, m, w=0.3, pants_len="none", foot="bare", tear=0)
        parts += bz.bind(f"UpperArm.{s}", [torus(f"{p}ArmBand{s}", 0.17, 0.035, (side * 0.56, 0, 1.12), rot=rad(0, 90, 0), m=m["ember"],
                                                 major_segs=14, minor_segs=5)])
        parts += bz.bind(f"ForeArm.{s}", [torus(f"{p}Wrist{s}", 0.14, 0.035, (side * 0.6, 0, 0.78), rot=rad(0, 90, 0), m=m["shell"],
                                                major_segs=14, minor_segs=5)])
    return parts


def kahuna_accessories(m):
    p = "KA_"
    w = 0.66
    crest = [box(p + "Crest", (0.62, 0.36, 0.7), (0, HEAD_Y + 0.05, 2.25), bevel=0.08, m=m["wood"]),
             box(p + "CrestBrow", (0.68, 0.14, 0.12), (0, HEAD_Y - 0.15, 2.36), bevel=0.04, m=m["wood_dark"]),
             box(p + "CrestMouth", (0.4, 0.08, 0.1), (0, HEAD_Y - 0.16, 2.08), bevel=0.03, m=m["ember"])]
    crest += [cyl(f"{p}CrestEye{s}", 0.08, 0.06, (s * 0.15, HEAD_Y - 0.16, 2.24), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=m["ember"]) for s in (-1, 1)]
    for i in range(5):
        a = -40 + i * 20
        crest.append(prism(f"{p}Plume{i}", [(-0.07, 0), (0.07, 0), (0.05, 0.55), (0, 0.62), (-0.05, 0.55)], 0.05,
                           (math.sin(math.radians(a)) * 0.3, HEAD_Y + 0.1, 2.56), rot=(0, math.radians(a), 0),
                           m=(m["flower"], m["petal"], m["teal"])[i % 3]))
    acc = {
        "Acc_Kahuna_Crest": bz.bind("Head", crest),
        "Acc_Kahuna_Bomb": bz.bind("ForeArm.R", [sphere(p + "Bomb", 0.17, (-0.62, -0.1, 0.46), m=m["ember"], segs=10, rings=7)]),
    }
    acc.update(faces("Kahuna", m, w, ("Snarl", "Gape", "Clench"), tongue=m["red"]))
    return acc


def lava_clips(rig):
    """lava_zombies.glb: Fire Dancer (Run, Tuck for the spin-up), Bartender (Walk,
    Throw), Kahuna (style "Heavy": stomp, slam, roar, throw)."""
    return [idle(rig), gait(rig, "Walk", shamble()), gait(rig, "Run", flail_sprint()), tuck(rig),
            idle(rig, "Idle_Heavy", heavy=True), gait(rig, "Walk_Heavy", stomp()), attack(rig), attack_heavy(rig),
            throw(rig), roar(rig), stagger(rig), hit_head(rig), *deaths(rig), emerge(rig),
            stagger(rig, "Stagger_Heavy", heavy=True), emerge(rig, "Emerge_Heavy", heavy=True)]


def build():
    scene = reset_scene()
    scene.render.fps = bz.FPS
    m = materials()
    armature = bz.build_armature()
    meshes = [
        bz.skin("Outfit_Dancer", dancer(m), armature),
        bz.skin("Outfit_Bartender", bartender(m), armature),
        bz.skin("Outfit_Kahuna", kahuna(m), armature),
    ]
    accessories = {}
    accessories.update(dancer_accessories(m))
    accessories.update(bartender_accessories(m))
    accessories.update(kahuna_accessories(m))
    for name, parts in accessories.items():
        meshes.append(bz.skin(name, parts, armature))
    zombie_anim.bake(armature, lava_clips, "lava_zombies")
    bz.save_zombie("lava_zombies", [armature] + meshes)


if __name__ == "__main__":
    build()
