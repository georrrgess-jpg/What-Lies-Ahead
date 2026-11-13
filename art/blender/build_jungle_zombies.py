"""Jungle Expedition zombies: one rig (the same bones as build_zombie.py, which
this script reuses), two outfits.

    Outfit_Explorer   Lost Explorer: a tintable safari shirt ("Shirt") with
                      patch pockets and epaulettes, khaki shorts, knee socks and
                      boots, a neckerchief and a pith helmet
    Outfit_Overgrown  Overgrown: a hulking guest swallowed by the jungle; a
                      tintable moss body ("Shirt"), the rags of a holiday shirt,
                      vines coiled round the chest and arms, leaves sprouting
                      from the shoulders and back, bark-knuckled fists

Accessories: Acc_Explorer_Satchel, _Binoculars, _Lantern, _Map; Acc_Overgrown_
Flower, _Shrooms, _LeafCrown, and for the alpha (The Idol Keeper)
Acc_Overgrown_IdolMask (a stone idol mask with glowing jade eyes) and
Acc_Overgrown_Headdress. Faces Face_<Outfit>_<Preset> come from zombie_kit.

Clips (jungle_clips below): the shared set; the Explorer's sprint, Crouch and
Leap (its vine-swing leap); the Overgrown's stomp ("_Heavy"), Roar, and Throw
(it rears up and drives both fists into the ground for the vine lash).

    python art/blender/build_jungle_zombies.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from jungle_common import *  # noqa: F401,F403
import jungle_common as jc  # noqa: E402
import build_zombie as bz  # noqa: E402
import zombie_anim as za  # noqa: E402
from zombie_kit import (HEAD_Y, SPARK_EYE, arm, band, base_materials, blob, cap_crown, face_y, faces, hair, head, head_band,  # noqa: E402
                        hips, leg, neck, patch, skull, torso)


def materials():
    m = base_materials("jungle", skin="#9fcf5a", skin_dark="#6a9a3a", dark="#24201c", white="#f7f2e6", eye=(SPARK_EYE, 2.4))
    m.update(
        shirt=mat("Shirt", "#c8a86a", rough=0.7),
        khaki=mat("JungleZKhaki", "#9a7f4a", rough=0.75),
        sock=mat("JungleZSock", "#efe6cf", rough=0.8),
        boot=mat("JungleZBoot", "#5a3a26", rough=0.6),
        helmet=mat("JungleZHelmet", "#f0e2bc", rough=0.6),
        band=mat("JungleZBand", "#7a4a2a", rough=0.6),
        scarf=mat("JungleZScarf", "#d9473a", rough=0.7),
        leather=mat("JungleZLeather", "#8a5a34", rough=0.6),
        brass=mat("JungleZBrass", "#e0b040", rough=0.3, metal=0.6),
        lens=mat("JungleZLens", "#5fd9ff", rough=0.15, emit=0.4),
        lamp=mat("JungleZLamp", "#ffc65a", rough=0.3, emit=3.0),
        paper=mat("JungleZPaper", "#efe1bf", rough=0.8),
        moss=mat("JungleZMoss", "#4f8a34", rough=0.85),
        leaf=mat("JungleZLeaf", "#2f8f4e", rough=0.7),
        leaf_light=mat("JungleZLeafLight", "#6cc04a", rough=0.7),
        vine=mat("JungleZVine", "#2a5a2e", rough=0.8),
        bark=mat("JungleZBark", "#6b4a32", rough=0.85),
        rag=mat("JungleZRag", "#ff7a9a", rough=0.7),
        rag_print=mat("JungleZRagPrint", "#ffd23f", rough=0.7),
        petal=mat("JungleZPetal", "#ff5a9a", rough=0.5),
        pollen=mat("JungleZPollen", "#ffd23f", rough=0.5, emit=0.6),
        cap=mat("JungleZShroom", "#e2563a", rough=0.6),
        stone=mat("JungleZStone", "#c9a27a", rough=0.85),
        stone_dark=mat("JungleZStoneDark", "#8d6b55", rough=0.9),
        gold=mat("JungleZGold", "#f2b33a", rough=0.3, metal=0.6, emit=0.3),
        jade=mat("JungleZJade", "#3dffb0", rough=0.3, emit=3.2),
    )
    return m


# ---------------------------------------------------------------------------
# Lost Explorer
# ---------------------------------------------------------------------------

def explorer(m):
    """Safari shirt ("Shirt") with pockets, khaki shorts, knee socks, boots,
    neckerchief and pith helmet."""
    p = "E_"
    w = 0.56
    shirt, khaki = m["shirt"], m["khaki"]
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "fringe", 23)
    parts += bz.bind("Head", [
        cap_crown(p + "Helmet", w, m["helmet"], rim=1.76, top=2.14, off=0.06),
        jc.torus(p + "Brim", 0.4, 0.05, (0, HEAD_Y, 1.77), m=m["helmet"], major_segs=28, minor_segs=6),
        cyl(p + "BrimDisc", 0.42, 0.03, (0, HEAD_Y, 1.77), segs=28, bevel=0.0, m=m["helmet"]),
    ] + [head_band(p + "HelmetBand", w, 1.86, 1.8, m["band"], off=0.075, thick=0.02)])
    tor, body = torso(p, shirt, w=0.6, d=0.42, z0=0.9, hem=khaki, hunch=0.05)
    parts += tor
    parts += neck(p, m["skin"], 0.24)
    t = tor[0]
    parts += bz.bind("Spine", [
        patch(p + "PocketL", t, (0.14, body.front(0.14, 1.26), 1.26), (0.15, 0.04, 0.14), khaki, bevel=0.015),
        patch(p + "PocketR", t, (-0.14, body.front(-0.14, 1.26), 1.26), (0.15, 0.04, 0.14), khaki, bevel=0.015),
        patch(p + "Placket", t, (0, body.front(0, 1.12), 1.12), (0.05, 0.04, 0.48), khaki, bevel=0.01),
        box(p + "EpauletL", (0.14, 0.12, 0.03), (0.24, 0.0, 1.45), bevel=0.01, m=khaki),
        box(p + "EpauletR", (0.14, 0.12, 0.03), (-0.24, 0.0, 1.45), bevel=0.01, m=khaki),
        jc.torus(p + "Scarf", 0.2, 0.05, (0, -0.02, 1.45), m=m["scarf"], major_segs=18, minor_segs=6),
        prism(p + "ScarfTip", [(-0.09, 0.0), (0.09, 0.0), (0.0, -0.16)], 0.03, (0, body.front(0, 1.38) - 0.03, 1.4), m=m["scarf"]),
    ])
    parts += hips(p, khaki, w=0.56, d=0.4, belt=m["leather"], buckle=m["brass"])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.16, sleeve=shirt, sleeve_len="short", cuff=khaki, seed=41)
        parts += leg(p, side, m, w=0.18, pants=khaki, pants_len="shorts", foot="boot", shoe=m["boot"], sole=m["dark"], sock=m["sock"],
                     lace=m["khaki"], boot_h=0.26, tear=1, seed=43)
    return parts


def explorer_accessories(m):
    p = "EA_"
    acc = {
        "Acc_Explorer_Satchel": bz.bind("Spine", [
            box(p + "Bag", (0.12, 0.3, 0.26), (0.36, 0.0, 0.95), rot=rad(0, 0, 0), bevel=0.04, m=m["leather"]),
            box(p + "Flap", (0.13, 0.31, 0.1), (0.37, 0.0, 1.04), bevel=0.03, m=m["boot"]),
            jc.tube(p + "Strap", [(0.33, 0.0, 1.06), (0.2, -0.22, 1.3), (-0.16, -0.21, 1.48), (-0.24, 0.0, 1.5), (-0.16, 0.2, 1.42), (0.3, 0.12, 1.08)],
                    0.018, m=m["leather"], segs=5),
        ]),
        "Acc_Explorer_Binoculars": bz.bind("Spine", [
            cyl(p + "BinoL", 0.045, 0.14, (0.05, -0.27, 1.23), rot=rad(90, 0, 0), segs=10, bevel=0.01, m=m["dark"]),
            cyl(p + "BinoR", 0.045, 0.14, (-0.05, -0.27, 1.23), rot=rad(90, 0, 0), segs=10, bevel=0.01, m=m["dark"]),
            cyl(p + "BinoLensL", 0.035, 0.01, (0.05, -0.345, 1.23), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=m["lens"]),
            cyl(p + "BinoLensR", 0.035, 0.01, (-0.05, -0.345, 1.23), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=m["lens"]),
            jc.tube(p + "BinoCord", [(0.08, -0.22, 1.27), (0.14, -0.1, 1.42), (0.0, 0.05, 1.47), (-0.14, -0.1, 1.42), (-0.08, -0.22, 1.27)],
                    0.008, m=m["dark"], segs=4),
        ]),
        "Acc_Explorer_Lantern": bz.bind("ForeArm.R", [
            cyl(p + "LanternBase", 0.06, 0.04, (-0.46, -0.08, 0.52), segs=10, bevel=0.01, m=m["brass"]),
            bulb(p + "LanternGlass", 0.055, (-0.46, -0.08, 0.6), m=m["lamp"], halo=False),
            cyl(p + "LanternTop", 0.05, 0.04, (-0.46, -0.08, 0.68), segs=10, bevel=0.01, m=m["brass"], radius_top=0.02),
            jc.torus(p + "LanternHandle", 0.04, 0.008, (-0.46, -0.08, 0.73), rot=rad(90, 0, 0), m=m["brass"], major_segs=10, minor_segs=4),
        ]),
        "Acc_Explorer_Map": bz.bind("ForeArm.L", [
            cyl(p + "MapRoll", 0.035, 0.32, (0.45, -0.1, 0.62), rot=rad(0, 90, 20), segs=8, bevel=0.01, m=m["paper"]),
            cyl(p + "MapTie", 0.04, 0.03, (0.45, -0.1, 0.62), rot=rad(0, 90, 20), segs=8, bevel=0.0, m=m["scarf"]),
        ]),
    }
    acc.update(faces("Explorer", m, 0.56, ("Grin", "Gape", "Derp"), tongue=m["scarf"]))
    return acc


# ---------------------------------------------------------------------------
# Overgrown
# ---------------------------------------------------------------------------

def leaf_tufts(prefix, bone, centre, radii, count, m_a, m_b, seed, size=0.28, keep=None):
    """Broad leaves sprouting outward from an ellipsoid (shoulders, back)."""
    rng = random.Random(seed)
    out = []
    i = 0
    while len(out) < count and i < count * 8:
        i += 1
        a = rng.uniform(0, math.tau)
        z = rng.uniform(-0.3, 1.0)
        r = math.sqrt(max(0.0, 1 - z * z))
        pos = (centre[0] + math.cos(a) * r * radii[0], centre[1] + math.sin(a) * r * radii[1], centre[2] + z * radii[2])
        if keep and not keep(*pos):
            continue
        out.append(jc.leaf(f"{prefix}{len(out):02d}", size * rng.uniform(0.8, 1.25), size * 0.62, pos, a, droop=0.55,
                           m=m_a if len(out) % 2 else m_b, segs=4, curl=0.25))
    return bz.bind(bone, out)


def coil(name, centre, radius, z0, z1, turns, m, thick=0.035, phase=0.0):
    """A vine coiled round a limb or the chest."""
    pts = []
    n = int(turns * 12) + 1
    for i in range(n):
        t = i / (n - 1)
        a = phase + t * turns * math.tau
        pts.append((centre[0] + math.cos(a) * radius[0], centre[1] + math.sin(a) * radius[1], z0 + (z1 - z0) * t))
    return jc.tube(name, pts, thick, m=m, segs=6)


def overgrown(m):
    """A hulking moss-covered brute ("Shirt" is its moss, tinted per zombie)."""
    p = "O_"
    w = 0.62
    moss, vine, rag = m["shirt"], m["vine"], m["rag"]
    parts = head(p, m, w)
    parts += bz.bind("Head", [
        cap_crown(p + "MossCap", w, moss, rim=1.8, top=2.07, off=0.04),
        sphere(p + "BrowMoss", 0.1, (0.2, face_y(w, 1.72) + 0.02, 1.74), scale=(1.4, 0.7, 0.6), m=moss, segs=8, rings=5),
    ])
    parts += leaf_tufts(p + "HeadLeaf", "Head", (0, HEAD_Y + 0.1, 1.95), (0.26, 0.2, 0.1), 5, m["leaf"], m["leaf_light"], 3, size=0.22,
                        keep=lambda x, y, z: y > HEAD_Y - 0.02)
    tor, body = torso(p, moss, w=1.0, d=0.66, z0=0.86, z1=1.48, waist=0.86, belly=0.12, hunch=0.12, chest=1.04, n=2.8)
    parts += tor
    parts += neck(p, moss, 0.42, z1=1.48)
    t = tor[0]
    parts += bz.bind("Spine", [
        # Rags of a holiday shirt, printed with flowers.
        body.shell(p + "Rag", rag, 1.2, 0.92, off=0.02, gap=150, segs=24, steps=4, lip=0.015),
        patch(p + "Print1", t, (0.24, body.front(0.24, 1.08), 1.08), (0.1, 0.03, 0.1), m["rag_print"], bevel=0.02),
        patch(p + "Print2", t, (-0.12, body.front(-0.12, 0.98), 0.98), (0.09, 0.03, 0.09), m["rag_print"], bevel=0.02),
        coil(p + "ChestVine", (0, 0.02), (0.56, 0.4), 0.95, 1.45, 1.4, vine, thick=0.04),
        blob(p + "Traps", (-0.44, 0.08, 1.44), (0.44, 0.08, 1.44), [(0, 0.08, 0.12), (0.3, 0.17, 0.16), (0.7, 0.17, 0.16), (1, 0.08, 0.12)], moss,
             n=2.4, r0=0.05, r1=0.05, segs=16, mid=6),
    ])
    parts += leaf_tufts(p + "BackLeaf", "Spine", (0, 0.18, 1.3), (0.46, 0.3, 0.22), 12, m["leaf"], m["leaf_light"], 5, size=0.34,
                        keep=lambda x, y, z: y > 0.05)
    parts += leaf_tufts(p + "ShoulderLeaf", "Spine", (0, 0.05, 1.5), (0.55, 0.28, 0.06), 8, m["leaf"], m["leaf_light"], 7, size=0.3)
    parts += hips(p, m["khaki"], w=0.88, d=0.6, z0=0.72, belt=vine)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.28, skin=moss, sleeve=moss, sleeve_len="none", glove=m["bark"], hand=0.1, out=0.14, nail=m["bark"],
                     curl=0.8, seed=47)
        parts += leg(p, side, m, w=0.28, skin=moss, pants=m["khaki"], pants_len="shorts", foot="bare", tear=3, seed=49)
        parts += bz.bind(f"UpperArm.{s}", [coil(f"{p}ArmVine{s}", (side * 0.54, 0.0), (0.16, 0.16), 1.0, 1.3, 1.2, vine, thick=0.03, phase=side)])
        parts += bz.bind(f"ForeArm.{s}", [coil(f"{p}ForeVine{s}", (side * 0.56, 0.0), (0.15, 0.15), 0.7, 0.95, 1.0, vine, thick=0.03)])
        parts += bz.bind(f"Shin.{s}", [coil(f"{p}ShinVine{s}", (side * 0.16, 0.0), (0.16, 0.16), 0.12, 0.4, 1.2, vine, thick=0.03)])
    return parts


def overgrown_accessories(m):
    p = "OA_"
    flower = [sphere(p + "FlowerHeart", 0.07, (0.18, HEAD_Y - 0.1, 2.02), m=m["pollen"], segs=10, rings=6)]
    for i in range(6):
        a = math.tau * i / 6
        flower.append(sphere(f"{p}Petal{i}", 0.08, (0.18 + math.cos(a) * 0.1, HEAD_Y - 0.1 + math.sin(a) * 0.03, 2.02 + math.sin(a) * 0.09),
                             scale=(1.0, 0.5, 0.7), rot=(0, a, 0), m=m["petal"], segs=8, rings=5))
    shrooms = []
    for i, (x, y, z, r) in enumerate(((-0.42, 0.1, 1.55, 0.09), (-0.5, 0.0, 1.5, 0.07), (-0.35, 0.18, 1.5, 0.06))):
        shrooms += [cyl(f"{p}Stem{i}", r * 0.35, r * 1.2, (x, y, z), segs=8, bevel=0.0, m=m["white"]),
                    sphere(f"{p}Cap{i}", r, (x, y, z + r * 0.6), scale=(1, 1, 0.55), m=m["cap"], segs=10, rings=6)]
    mask = [
        box(p + "Mask", (0.62, 0.14, 0.62), (0, face_y(0.62, 1.62) - 0.06, 1.62), bevel=0.12, segs=3, m=m["stone"]),
        box(p + "MaskBrow", (0.66, 0.16, 0.12), (0, face_y(0.62, 1.62) - 0.1, 1.78), bevel=0.04, m=m["stone_dark"]),
        sphere(p + "MaskEyeL", 0.075, (0.14, face_y(0.62, 1.66) - 0.15, 1.68), scale=(1.3, 0.5, 0.8), m=m["jade"], segs=10, rings=6),
        sphere(p + "MaskEyeR", 0.075, (-0.14, face_y(0.62, 1.66) - 0.15, 1.68), scale=(1.3, 0.5, 0.8), m=m["jade"], segs=10, rings=6),
        box(p + "MaskMouth", (0.34, 0.05, 0.1), (0, face_y(0.62, 1.48) - 0.12, 1.47), bevel=0.03, m=m["dark"]),
    ]
    for i in range(4):
        x = -0.12 + i * 0.08
        mask.append(cyl(f"{p}MaskTooth{i}", 0.02, 0.06, (x, face_y(0.62, 1.48) - 0.14, 1.5), rot=rad(180, 0, 0), segs=5, bevel=0.0, m=m["white"],
                        radius_top=0.005))
    headdress = [box(p + "Band", (0.7, 0.5, 0.1), (0, HEAD_Y, 1.98), bevel=0.04, m=m["gold"]),
                 cyl(p + "Gem", 0.07, 0.05, (0, face_y(0.62, 1.98) - 0.08, 1.98), rot=rad(90, 0, 0), segs=6, bevel=0.01, m=m["jade"])]
    for i in range(7):
        a = math.radians(-54 + i * 18)
        h = 0.42 if i % 2 else 0.55
        headdress.append(box(f"{p}Feather{i}", (0.1, 0.06, h), (math.sin(a) * (0.2 + h * 0.5), HEAD_Y + 0.08, 2.03 + math.cos(a) * h * 0.5),
                             rot=(0, a, 0), bevel=0.03, m=m["stone"] if i % 2 else m["stone_dark"]))
    acc = {
        "Acc_Overgrown_Flower": bz.bind("Head", flower),
        "Acc_Overgrown_Shrooms": bz.bind("Spine", shrooms),
        "Acc_Overgrown_LeafCrown": leaf_tufts(p + "Crown", "Head", (0, HEAD_Y + 0.05, 2.0), (0.3, 0.26, 0.05), 7, m["leaf_light"], m["leaf"], 11,
                                              size=0.26),
        "Acc_Overgrown_IdolMask": bz.bind("Head", mask),
        "Acc_Overgrown_Headdress": bz.bind("Head", headdress),
    }
    acc.update(faces("Overgrown", m, 0.62, ("Snarl", "Clench", "Gape"), tongue=m["petal"]))
    return acc


def jungle_clips(rig):
    """jungle_zombies.glb: Explorer (sprint, Crouch and Leap), Overgrown (style
    "Heavy": stomp, slam, Roar and the two-fisted Throw for the vine lash)."""
    return [za.idle(rig), za.gait(rig, "Walk", za.shamble()), za.gait(rig, "Run", za.flail_sprint()), za.attack(rig),
            za.crouch(rig), za.leap(rig),
            za.idle(rig, "Idle_Heavy", heavy=True), za.gait(rig, "Walk_Heavy", za.stomp()), za.gait(rig, "Run_Heavy", za.charge()),
            za.attack_heavy(rig), za.roar(rig), za.throw(rig), *za._common(rig, heavy=True)]


def build():
    scene = reset_scene()
    scene.render.fps = bz.FPS
    m = materials()
    armature = bz.build_armature()
    meshes = [
        bz.skin("Outfit_Explorer", explorer(m), armature),
        bz.skin("Outfit_Overgrown", overgrown(m), armature),
    ]
    accessories = {}
    accessories.update(explorer_accessories(m))
    accessories.update(overgrown_accessories(m))
    for name, parts in accessories.items():
        meshes.append(bz.skin(name, parts, armature))
    za.bake(armature, jungle_clips, "jungle_zombies")
    bz.save_zombie("jungle_zombies", [armature] + meshes)


if __name__ == "__main__":
    build()
