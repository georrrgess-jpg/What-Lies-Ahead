"""Castle Kingdom zombies (World 14, Royal Faire): the shared rig (build_zombie.py),
three outfits in faire_zombies.glb.

    Outfit_Knight       Armored Knight: a toy tin knight in a tintable tabard
                        ("Shirt") over steel, pauldrons and a gorget, a steel helm
                        with the visor raised; a big heater shield held in front
                        (Acc_Knight_Shield, the head guard) and a sword in the
                        right hand; a plume (Acc_Knight_Plume) on some
    Outfit_Jester       Jester: a tintable motley tunic ("Shirt") with gold and
                        red diamonds, a ruff, a bell belt, odd-coloured hose and
                        curled shoes; a three-pointed belled hat (Acc_Jester_Hat)
                        and a bauble sceptre on the hip (Acc_Jester_Bauble)
    Outfit_BlackKnight  The Black Knight (the alpha): a hulking knight in black
                        plate with gold trim and a red tabard ("Shirt"); a horned
                        great helm with a red plume (Acc_BKnight_Helm) and a
                        greatsword (Acc_BKnight_Sword)

Faces: two presets per outfit (Face_<Outfit>_<Preset>).

Clips (faire_clips below): the shared set; the Knight's style "Knight" (shielded
stomp and rush, sword bash, "Drum_Knight": the sword rapped on the shield rim,
the charge telegraph, and "Recover_Knight": the shield swung wide after it); the
Jester's swagger and overhead Throw (the pin toss); the Black Knight's "Heavy"
stomp, charge, slam and roar.

    python art/blender/build_faire_zombies.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from faire_common import *  # noqa: F401,F403
import build_zombie as bz  # noqa: E402
import zombie_anim  # noqa: E402
import build_city_zombies_b as cz  # noqa: E402
from zombie_anim import (_cs, attack, attack_heavy, attack_riot, charge, deaths, emerge, flail_sprint, gait, hit_head, idle,  # noqa: E402
                         riot_charge, riot_stomp, roar, shamble, stagger, stomp, swagger, throw)
from zombie_kit import (HEAD_Y, SPARK_EYE, arm, band, base_materials, blob, cap_crown, face_y, faces, head, head_band, hips, leg,  # noqa: E402
                        neck, patch, skull, torso)


def materials():
    m = base_materials("faire", skin="#a8d36a", skin_dark="#6f9e44", dark="#22222e", white="#fbf8f2", eye=(SPARK_EYE, 2.6))
    m.update(
        shirt=mat("Shirt", "#d8343f", rough=0.55),
        steel=mat("FaireZSteel", "#b7bfcf", rough=0.3, metal=0.55),
        steel_dark=mat("FaireZSteelDark", "#6f7789", rough=0.35, metal=0.5),
        black=mat("FaireZBlack", "#202129", rough=0.45, metal=0.2),
        gold=mat("FaireZGold", "#f2c14e", rough=0.3, metal=0.4),
        red=mat("FaireZRed", "#d8343f", rough=0.5),
        blue=mat("FaireZBlue", "#2f5bd3", rough=0.5),
        yellow=mat("FaireZYellow", "#ffd23f", rough=0.5),
        green=mat("FaireZGreen", "#3fae5a", rough=0.5),
        purple=mat("FaireZPurple", "#7b4fc9", rough=0.5),
        ruff=mat("FaireZRuff", "#fbf8f2", rough=0.7),
        leather=mat("FaireZLeather", "#7a4a2e", rough=0.7),
        plume=mat("FaireZPlume", "#ff5a6a", rough=0.8),
        plume_w=mat("FaireZPlumeW", "#fbf8f2", rough=0.8),
        glow=mat("FaireZEyeGlow", "#ff4a3a", rough=0.3, emit=3.0),
    )
    return m


# ---------------------------------------------------------------------------
# Armored Knight
# ---------------------------------------------------------------------------

def knight(m):
    p = "K_"
    w = 0.6
    steel, dark = m["steel"], m["steel_dark"]
    parts = head(p, m, w, ears=False)
    sk = skull(w)
    fy = face_y(w, 1.6)
    parts += bz.bind("Head", [
        sk.shell(p + "Helm", steel, 1.98, 1.42, off=0.06, gap=120, segs=28, steps=6, lip=0.04),
        cap_crown(p + "HelmTop", w, steel, rim=1.84, top=2.08, off=0.06, segs=28),
        head_band(p + "HelmBand", w, 1.86, 1.8, m["gold"], off=0.075, thick=0.02),
        # The visor is up: a slotted steel plate folded onto the brow.
        box(p + "VisorUp", (0.62, 0.22, 0.05), (0, fy - 0.03, 2.0), rot=rad(-58, 0, 0), bevel=0.02, m=steel),
        box(p + "VisorSlit", (0.46, 0.04, 0.03), (0, fy - 0.09, 2.04), rot=rad(-58, 0, 0), bevel=0.0, m=m["dark"]),
        sphere(p + "VisorRivetL", 0.035, (0.29, HEAD_Y - 0.08, 1.92), m=m["gold"], segs=6, rings=4),
        sphere(p + "VisorRivetR", 0.035, (-0.29, HEAD_Y - 0.08, 1.92), m=m["gold"], segs=6, rings=4),
    ])
    tor, body = torso(p, m["shirt"], w=0.78, d=0.5, z0=0.86, z1=1.46, waist=0.86, belly=0.04, hunch=0.04, chest=1.03)
    parts += tor
    parts += neck(p, steel, 0.3, z1=1.46)
    t = tor[0]
    plates = [
        band(p + "Gorget", (0, 0, 1.5), (0, 0, 1.4), 0.26, 0.21, steel, n=2.6, thick=0.03, segs=24),
        body.shell(p + "TabardTrim", m["gold"], 1.0, 0.96, off=0.03, segs=28, steps=1, lip=0.012),
        crown_flat(p + "Crest", (0, body.front(0, 1.22) - 0.03, 1.1), 0.24, m["gold"], depth=0.03),
        box(p + "Belt", (0.6, 0.06, 0.08), (0, body.front(0, 0.98) - 0.02, 0.98), bevel=0.02, m=m["leather"]),
    ]
    for side in (1, -1):
        plates += [
            sphere(f"{p}Pauldron{side}", 0.22, (side * 0.43, 0.0, 1.36), scale=(1.1, 1.0, 0.7), m=steel, segs=16, rings=8),
            sphere(f"{p}PauldronRim{side}", 0.23, (side * 0.45, 0.0, 1.31), scale=(1.12, 1.02, 0.25), m=m["gold"], segs=16, rings=6),
        ]
    parts += bz.bind("Spine", plates)
    parts += hips(p, steel, w=0.72, d=0.5, belt=m["leather"], buckle=m["gold"], belt_z=0.965)
    parts += bz.bind("Hips", [blob(p + "Skirt", (0, 0.0, 0.62), (0, 0.0, 0.9), [(0, 0.44, 0.31), (1, 0.4, 0.29)], m["shirt"],
                                   n=2.8, r0=0.02, r1=0.02, segs=22, mid=3)])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.22, sleeve=dark, sleeve_len="long", cuff=steel, glove=steel, hand=0.06, out=0.06, nail=steel, seed=71)
        parts += leg(p, side, m, w=0.22, pants=dark, pants_len="long", foot="boot", shoe=steel, sole=m["dark"], lace=steel, knee_m=steel,
                     boot_h=0.3, tear=0)
        parts += bz.bind(f"Shin.{s}", [box(f"{p}Greave{s}", (0.17, 0.08, 0.3), (side * 0.16, -0.13, 0.42), bevel=0.04, m=steel)])
    parts += bz.bind("ForeArm.R", [
        box(p + "Blade", (0.06, 0.02, 0.85), (-0.5, -0.2, 0.2), rot=rad(70, 0, 0), bevel=0.01, m=m["steel"]),
        box(p + "Guard", (0.28, 0.06, 0.06), (-0.5, 0.0, 0.62), rot=rad(70, 0, 0), bevel=0.02, m=m["gold"]),
        sphere(p + "Pommel", 0.05, (-0.5, 0.12, 0.66), m=m["gold"], segs=8, rings=5),
    ])
    return parts


def knight_accessories(m):
    """The heater shield, held in front and bound to the spine (its top edge is
    the head guard), and the helm's plume."""
    p = "KS_"
    y = -0.66
    zc = 0.98
    hw, top, bottom = 0.47, 0.6, -0.62
    outline = [(-hw, top), (hw, top), (hw, 0.05), (hw * 0.55, -0.38), (0, bottom), (-hw * 0.55, -0.38), (-hw, 0.05)]
    rim = [(x * 1.1, z * 1.07 + 0.01) for x, z in outline]
    shield = [prism(p + "Face", outline, 0.08, (0.05, y, zc), m=m["blue"]),
              prism(p + "Rim", rim, 0.05, (0.05, y + 0.04, zc), m=m["gold"]),
              prism(p + "Band", [(-hw, 0.18), (hw, 0.18), (hw, 0.02), (-hw, 0.02)], 0.03, (0.05, y - 0.05, zc + 0.1), m=m["yellow"]),
              crown_flat(p + "Crown", (0.05, y - 0.06, zc - 0.25), 0.34, m["gold"], depth=0.03),
              box(p + "Grip", (0.1, 0.18, 0.1), (0.2, y + 0.12, zc), bevel=0.02, m=m["leather"])]
    pa = "KP_"
    w = 0.6
    plume = []
    for k in range(5):
        t = k / 4
        plume.append(sphere(f"{pa}Puff{k}", 0.11 - t * 0.02, (0, HEAD_Y + 0.05 + t * 0.32, 2.12 + math.sin(t * 2.4) * 0.16 - t * 0.05), m=m["plume"] if k % 2 == 0 else m["plume_w"],
                            scale=(0.8, 1.2, 1.0), segs=10, rings=6))
    plume.append(cyl(pa + "Holder", 0.05, 0.1, (0, HEAD_Y + 0.02, 2.08), segs=8, bevel=0.0, m=m["gold"]))
    acc = {
        "Acc_Knight_Shield": bz.bind("Spine", shield),
        "Acc_Knight_Plume": bz.bind("Head", plume),
    }
    acc.update(faces("Knight", m, w, ("Snarl", "Gape"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Jester
# ---------------------------------------------------------------------------

def jester(m):
    p = "J_"
    w = 0.56
    parts = head(p, m, w)
    tor, body = torso(p, m["shirt"], w=0.6, d=0.42, z0=0.9, hunch=0.06, n=3.0, hem=m["shirt"])
    parts += tor
    parts += neck(p, m["skin"], 0.23)
    t = tor[0]
    deco = []
    for k, (x, z, col) in enumerate(((-0.13, 1.28, "gold"), (0.13, 1.28, "yellow"), (0.0, 1.12, "gold"), (-0.13, 0.98, "yellow"), (0.13, 0.98, "gold"))):
        deco.append(patch(f"{p}Diamond{k}", t, (x, body.front(x, z), z), (0.12, 0.02, 0.12), m[col], rot=(0, math.radians(45), 0), bevel=0.005))
    for k in range(10):
        a = math.tau * k / 10
        deco.append(sphere(f"{p}Ruff{k}", 0.075, (math.cos(a) * 0.22, math.sin(a) * 0.17 + 0.0, 1.46), scale=(1.0, 1.0, 0.6), m=m["ruff"], segs=8, rings=5))
    parts += bz.bind("Spine", deco)
    parts += hips(p, m["purple"], w=0.56, d=0.4, belt=m["gold"])
    parts += bz.bind("Hips", [sphere(f"{p}Bell{k}", 0.045, (-0.22 + k * 0.11, -0.2, 0.9), m=m["gold"], segs=8, rings=5) for k in range(5)])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.16, sleeve=m["shirt"] if side > 0 else m["yellow"], sleeve_len="long", cuff=m["gold"], seed=73)
        parts += leg(p, side, m, w=0.17, pants=m["yellow"] if side > 0 else m["purple"], pants_len="long", foot="shoe", shoe=m["red"],
                     sole=m["gold"], lace=m["gold"], tear=0)
        x = side * 0.13
        parts += bz.bind(f"Shin.{s}", [tube(f"{p}Curl{s}", [(x, -0.18, 0.06), (x, -0.32, 0.1), (x, -0.36, 0.2), (x, -0.3, 0.26)], 0.04, m=m["red"],
                                            segs=6, radius_end=0.012),
                                       sphere(f"{p}CurlBell{s}", 0.035, (x, -0.3, 0.29), m=m["gold"], segs=6, rings=4)])
    return parts


def jester_accessories(m):
    p = "JA_"
    w = 0.56
    cols = [m["red"], m["yellow"], m["blue"]]
    hat = [cap_crown(p + "Cap", w, m["purple"], rim=1.76, top=2.02, off=0.035),
           head_band(p + "Band", w, 1.8, 1.74, m["gold"], off=0.05, thick=0.025)]
    for k, ang in enumerate((-60, 0, 60)):
        a = math.radians(ang)
        dx, dy = math.sin(a), math.cos(a) * 0.5
        base = (dx * 0.12, HEAD_Y + dy * 0.1, 1.98)
        pts = [base, (dx * 0.35, HEAD_Y + dy * 0.3, 2.25), (dx * 0.6, HEAD_Y + dy * 0.45, 2.22), (dx * 0.72, HEAD_Y + dy * 0.5, 2.02)]
        hat.append(tube(f"{p}Point{k}", pts, 0.13, m=cols[k], segs=10, radius_end=0.03))
        hat.append(sphere(f"{p}Bell{k}", 0.07, (pts[-1][0], pts[-1][1], pts[-1][2] - 0.06), m=m["gold"], segs=10, rings=6))
    bauble = [cyl(p + "Stick", 0.025, 0.55, (0.36, -0.05, 0.75), rot=rad(0, 20, 0), segs=6, bevel=0.0, m=m["leather"]),
              sphere(p + "Head", 0.09, (0.45, -0.05, 1.03), m=m["skin"], segs=10, rings=6),
              cyl(p + "HeadCap", 0.09, 0.1, (0.45, -0.05, 1.12), segs=8, bevel=0.0, m=m["red"], radius_top=0.02)]
    acc = {
        "Acc_Jester_Hat": bz.bind("Head", hat),
        "Acc_Jester_Bauble": bz.bind("Hips", bauble),
    }
    acc.update(faces("Jester", m, w, ("Grin", "Gape"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# The Black Knight (the alpha)
# ---------------------------------------------------------------------------

def black_knight(m):
    p = "B_"
    w = 0.66
    black, gold = m["black"], m["gold"]
    parts = head(p, m, w, ears=False)
    tor, body = torso(p, m["shirt"], w=1.0, d=0.66, z0=0.84, z1=1.48, waist=0.9, belly=0.08, hunch=0.1, chest=1.04, n=2.8, hem=m["shirt"])
    parts += tor
    parts += neck(p, black, 0.4, z1=1.48)
    plates = [band(p + "Gorget", (0, 0, 1.54), (0, 0, 1.42), 0.36, 0.3, black, n=2.6, thick=0.04, segs=24),
              body.shell(p + "TabardTrim", gold, 1.0, 0.95, off=0.035, segs=28, steps=1, lip=0.012),
              star(p + "Crest", 0.16, 0.03, (0, body.front(0, 1.2) - 0.035, 1.2), rot=(math.pi / 2, 0, 0), m=black)]
    for side in (1, -1):
        plates += [sphere(f"{p}Pauldron{side}", 0.32, (side * 0.58, 0.0, 1.4), scale=(1.1, 1.0, 0.72), m=black, segs=16, rings=8),
                   sphere(f"{p}PauldronRim{side}", 0.33, (side * 0.6, 0.0, 1.33), scale=(1.12, 1.02, 0.22), m=gold, segs=16, rings=6)]
        for k in range(3):
            plates.append(cyl(f"{p}Spike{side}{k}", 0.05, 0.22, (side * (0.5 + k * 0.1), 0.0, 1.6 - k * 0.02), segs=6, bevel=0.0, m=gold, radius_top=0.005))
    parts += bz.bind("Spine", plates)
    parts += bz.bind("Hips", [blob(p + "Skirt", (0, 0.05, 0.5), (0, 0.05, 0.9), [(0, 0.56, 0.4), (1, 0.5, 0.38)], m["shirt"],
                                   n=2.6, r0=0.03, r1=0.03, segs=22, mid=3)])
    parts += hips(p, black, w=0.9, d=0.62, z0=0.7, belt=gold, buckle=gold)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.3, sleeve=black, sleeve_len="long", cuff=gold, glove=black, hand=0.1, out=0.14, curl=0.8, nail=gold, seed=77)
        parts += leg(p, side, m, w=0.3, pants=black, pants_len="long", foot="boot", shoe=black, sole=m["dark"], knee_m=gold, tear=0)
    return parts


def black_knight_accessories(m):
    p = "BA_"
    w = 0.66
    black, gold = m["black"], m["gold"]
    sk = skull(w)
    fy = face_y(w, 1.6)
    helm = [sk.shell(p + "Helm", black, 2.0, 1.4, off=0.07, gap=110, segs=28, steps=6, lip=0.05),
            cap_crown(p + "HelmTop", w, black, rim=1.86, top=2.14, off=0.07, segs=28),
            head_band(p + "HelmBand", w, 1.88, 1.82, gold, off=0.085, thick=0.025),
            box(p + "Nasal", (0.07, 0.06, 0.34), (0, fy - 0.1, 1.72), bevel=0.02, m=black),
            box(p + "Brow", (0.6, 0.08, 0.08), (0, fy - 0.08, 1.88), bevel=0.02, m=gold)]
    for side in (1, -1):
        helm.append(tube(f"{p}Horn{side}", [(side * 0.32, HEAD_Y, 1.95), (side * 0.55, HEAD_Y - 0.05, 2.1), (side * 0.62, HEAD_Y - 0.12, 2.35)], 0.08,
                         m=m["ruff"], segs=8, radius_end=0.015))
    for k in range(6):
        t = k / 5
        helm.append(sphere(f"{p}Plume{k}", 0.13 - t * 0.03, (0, HEAD_Y + 0.08 + t * 0.42, 2.22 + math.sin(t * 2.6) * 0.18 - t * 0.08), scale=(0.8, 1.2, 1.0),
                           m=m["plume"], segs=10, rings=6))
    sword = [box(p + "Blade", (0.11, 0.035, 1.45), (-0.62, -0.42, 0.05), rot=rad(70, 0, 0), bevel=0.015, m=m["steel"]),
             box(p + "Fuller", (0.03, 0.04, 1.2), (-0.62, -0.44, 0.08), rot=rad(70, 0, 0), bevel=0.0, m=m["steel_dark"]),
             box(p + "Guard", (0.46, 0.09, 0.09), (-0.62, 0.0, 0.58), rot=rad(70, 0, 0), bevel=0.03, m=gold),
             cyl(p + "Grip", 0.04, 0.3, (-0.62, 0.12, 0.62), rot=rad(70, 0, 0), segs=8, bevel=0.0, m=m["leather"]),
             sphere(p + "Pommel", 0.07, (-0.62, 0.26, 0.67), m=gold, segs=8, rings=5)]
    acc = {
        "Acc_BKnight_Helm": bz.bind("Head", helm),
        "Acc_BKnight_Sword": bz.bind("ForeArm.R", sword),
    }
    acc.update(faces("BlackKnight", m, w, ("Snarl", "Gape"), tongue=m["red"]))
    return acc


def faire_clips(rig):
    """faire_zombies.glb: Knight (style "Knight": shielded stomp and rush, sword
    bash, Drum and Recover), Jester (swagger, sprint, Throw), Black Knight
    (style "Heavy": stomp, charge, slam, roar)."""
    def knight_idle_arms(ph):
        _, s = _cs(ph)
        return {**cz.SHIELD_ARM, "UpperArm.L": (-58 + 2 * s, 0, -38), "UpperArm.R": (-20 + 3 * s, 16, 0), "ForeArm.R": (-40, 0, 0)}
    return [idle(rig), gait(rig, "Walk", swagger()), gait(rig, "Run", flail_sprint()), attack(rig), throw(rig), roar(rig),
            idle(rig, "Idle_Knight", heavy=True, arms_fn=knight_idle_arms), gait(rig, "Walk_Knight", riot_stomp()),
            gait(rig, "Run_Knight", riot_charge()), attack_riot(rig, "Attack_Knight"), cz.cop_drum(rig, "Drum_Knight"),
            cz.cop_recover(rig, "Recover_Knight"), stagger(rig, "Stagger_Knight", heavy=True), emerge(rig, "Emerge_Knight", heavy=True),
            idle(rig, "Idle_Heavy", heavy=True), gait(rig, "Walk_Heavy", stomp()), gait(rig, "Run_Heavy", charge()), attack_heavy(rig),
            stagger(rig), hit_head(rig), *deaths(rig), emerge(rig),
            stagger(rig, "Stagger_Heavy", heavy=True), emerge(rig, "Emerge_Heavy", heavy=True)]


def build():
    scene = reset_scene()
    scene.render.fps = bz.FPS
    m = materials()
    armature = bz.build_armature()
    meshes = [
        bz.skin("Outfit_Knight", knight(m), armature),
        bz.skin("Outfit_Jester", jester(m), armature),
        bz.skin("Outfit_BlackKnight", black_knight(m), armature),
    ]
    accessories = {}
    accessories.update(knight_accessories(m))
    accessories.update(jester_accessories(m))
    accessories.update(black_knight_accessories(m))
    for name, parts in accessories.items():
        meshes.append(bz.skin(name, parts, armature))
    zombie_anim.bake(armature, faire_clips, "faire_zombies")
    bz.save_zombie("faire_zombies", [armature] + meshes)


if __name__ == "__main__":
    build()
