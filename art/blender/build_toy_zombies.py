"""Toybox Town zombies (World 15, Toy Shop): the shared rig (build_zombie.py),
three outfits, and the wind-up key their behaviours spin.

    Outfit_Soldier   Wind-up Soldier: a tin drummer in a tintable tunic ("Shirt")
                     with white cross belts, gold buttons and cuffs, blue trousers
                     with a red stripe, black boots, painted rosy cheeks; a tall
                     shako with a plume (Acc_Soldier_Shako) and a side drum
                     (Acc_Soldier_Drum)
    Outfit_Plush     Plush Brute: a big stitched teddy brute, fur all over, in
                     tintable dungarees ("Shirt") with a heart patch and buttons, a
                     bear muzzle; round ears (Acc_Plush_Ears) and a ribbon bow
                     (Acc_Plush_Bow)
    Outfit_Toymaker  The Toymaker (the alpha): a hulking old craftsman in a striped
                     shirt ("Shirt") with rolled sleeves under a leather apron full of
                     tools, a white walrus moustache; wild white hair with a loupe
                     (Acc_Toymaker_Loupe) and a toy mallet (Acc_Toymaker_Mallet)
    toy_key.glb      the brass wind-up key the behaviours mount on the Spine bone
                     and turn (shaft along -Z from its origin, bow at the end)

Faces: two presets per outfit (Face_<Outfit>_<Preset>).

Clips (toy_clips below): the shared set, the Soldier's stiff March ("Walk"), the
quick-march burst ("PowerWalk") and "Windup" (standing to attention while the key
turns), the Brute's Crouch and Leap (the bounce), the heavies' stomp (Brute and
Toymaker), the Toymaker's, slam, roar, throw and charge ("_Heavy", "Run").

    python art/blender/build_toy_zombies.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from toy_common import *  # noqa: F401,F403
import build_zombie as bz  # noqa: E402
import zombie_anim  # noqa: E402
import zombie_anim as za  # noqa: E402
from zombie_kit import (HEAD_Y, SPARK_EYE, head_band, arm, band, base_materials, blob, face_y, faces, hair,  # noqa: E402
                        head, hips, leg, neck, patch, torso)


def materials():
    m = base_materials("toy", skin="#a8d06a", skin_dark="#6f9c46", dark="#1e1a2a", white="#fbf7ef", eye=(SPARK_EYE, 2.6))
    m.update(
        shirt=mat("Shirt", "#e2443a", rough=0.5),
        stripe=mat("ToyZWhite", "#fbf7ef", rough=0.55),
        navy=mat("ToyZNavy", "#23305e", rough=0.55),
        blue=mat("ToyZBlue", "#3b6fd1", rough=0.5),
        red=mat("ToyZRed", "#e2443a", rough=0.5),
        gold=mat("ToyZGold", "#f2c23a", rough=0.35, metal=0.4),
        brass=mat("ToyZBrass", "#e0b04a", rough=0.3, metal=0.6),
        black=mat("ToyZBlack", "#1c1a2a", rough=0.4),
        cheek=mat("ToyZCheek", "#f08a9a", rough=0.6),
        fur=mat("ToyZFur", "#c99868", rough=0.95),
        fur_light=mat("ToyZFurLight", "#ecc79c", rough=0.95),
        stitch=mat("ToyZStitch", "#3a2a2a", rough=0.8),
        heart=mat("ToyZHeart", "#f29ab8", rough=0.7),
        leather=mat("ToyZLeather", "#8a5530", rough=0.7),
        wood=mat("ToyZWood", "#e2b27a", rough=0.6),
        hair=mat("ToyZHair", "#f4f0ea", rough=0.9),
        lens=mat("ToyZLens", "#9fd8ff", rough=0.1, emit=0.5),
        plume=mat("ToyZPlume", "#fbf7ef", rough=0.8),
    )
    return m


# ---------------------------------------------------------------------------
# Wind-up Soldier
# ---------------------------------------------------------------------------

def soldier(m):
    p = "S_"
    w = 0.56
    parts = head(p, m, w)
    parts += hair(p, w, m["black"], "flat", 41)
    tor, body = torso(p, m["shirt"], w=0.58, d=0.4, z0=0.9, hunch=0.02, n=3.2, hem=m["shirt"])
    parts += tor
    parts += neck(p, m["skin"], 0.23)
    t = tor[0]
    tunic = [band(p + "Collar", (0, 0, 1.46), (0, 0, 1.4), 0.17, 0.15, m["gold"], n=3.0, thick=0.02, segs=20)]
    # White cross belts, front.
    for s in (1, -1):
        tunic.append(patch(f"{p}Belt{s}", t, (s * 0.08, body.front(s * 0.08, 1.18), 1.18), (0.06, 0.03, 0.56), m["stripe"],
                           rot=(0, s * 0.62, 0), bevel=0.008))
    tunic += [sphere(f"{p}Button{i}", 0.025, (0, body.front(0, 1.34 - i * 0.11) - 0.012, 1.34 - i * 0.11), m=m["gold"], segs=8, rings=5)
              for i in range(4)]
    for s in (1, -1):
        tunic += [box(f"{p}Epaulette{s}", (0.18, 0.2, 0.05), (s * 0.31, 0.0, 1.43), bevel=0.02, m=m["gold"])]
    parts += bz.bind("Spine", tunic)
    parts += hips(p, m["blue"], w=0.54, d=0.4, belt=m["stripe"], buckle=m["gold"])
    # Painted rosy cheeks (a tin soldier's).
    parts += bz.bind("Head", [sphere(f"{p}Cheek{s}", 0.055, (s * 0.17, face_y(w, 1.55) + 0.03, 1.55), scale=(1, 0.35, 0.8), m=m["cheek"],
                                     segs=10, rings=6) for s in (1, -1)])
    for side in (1, -1):
        parts += arm(p, side, m, w=0.15, sleeve=m["shirt"], sleeve_len="long", cuff=m["gold"], seed=61)
        parts += leg(p, side, m, w=0.17, pants=m["blue"], pants_len="long", hem=m["red"], foot="boot", shoe=m["black"], sole=m["black"],
                     tear=0, boot_h=0.36)
    return parts


def soldier_accessories(m):
    p = "SA_"
    w = 0.56
    shako = [cyl(p + "Shako", 0.24, 0.42, (0, HEAD_Y, 2.03), segs=20, bevel=0.03, m=m["black"], radius_top=0.27),
             cyl(p + "ShakoBand", 0.25, 0.07, (0, HEAD_Y, 1.86), segs=20, bevel=0.0, m=m["gold"]),
             cyl(p + "ShakoTop", 0.275, 0.05, (0, HEAD_Y, 2.24), segs=20, bevel=0.01, m=m["red"]),
             box(p + "Peak", (0.34, 0.16, 0.03), (0, HEAD_Y - 0.28, 1.84), rot=(math.radians(-12), 0, 0), bevel=0.01, m=m["black"]),
             star(p + "Badge", 0.08, 0.02, (0, HEAD_Y - 0.25, 2.02), rot=(math.radians(-4), 0, 0), m=m["gold"]),
             sphere(p + "Plume", 0.09, (0, HEAD_Y - 0.16, 2.33), scale=(1, 1, 1.9), m=m["plume"], segs=10, rings=6),
             tube(p + "Strap", [(-0.24, HEAD_Y - 0.05, 1.78), (0, face_y(w, 1.4) + 0.02, 1.4), (0.24, HEAD_Y - 0.05, 1.78)], 0.012, m=m["gold"],
                  segs=4)]
    drum = [cyl(p + "Drum", 0.2, 0.22, (0.3, -0.18, 0.86), rot=(0, 0, 0), segs=16, bevel=0.02, m=m["stripe"]),
            torus(p + "HoopT", 0.205, 0.022, (0.3, -0.18, 0.97), m=m["red"], major_segs=18, minor_segs=4),
            torus(p + "HoopB", 0.205, 0.022, (0.3, -0.18, 0.75), m=m["red"], major_segs=18, minor_segs=4)]
    for k in range(6):
        a = math.tau * k / 6
        drum.append(cyl(f"{p}Cord{k}", 0.008, 0.24, (0.3 + math.cos(a) * 0.205, -0.18 + math.sin(a) * 0.205, 0.86),
                        rot=(0.5 * math.sin(a), 0.5 * math.cos(a), 0), segs=4, bevel=0.0, m=m["gold"]))
    acc = {
        "Acc_Soldier_Shako": bz.bind("Head", shako),
        "Acc_Soldier_Drum": bz.bind("Hips", drum),
    }
    acc.update(faces("Soldier", m, w, ("Grin", "Gape"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Plush Brute
# ---------------------------------------------------------------------------

def plush(m):
    p = "P_"
    w = 0.7
    fur = {**m, "skin": m["fur"], "skin_dark": m["fur_light"]}
    parts = head(p, fur, w, ears=False, nose=False)
    parts += bz.bind("Head", [sphere(p + "Muzzle", 0.17, (0, face_y(w, 1.5) + 0.02, 1.5), scale=(1.25, 0.7, 0.85), m=m["fur_light"], segs=14, rings=8),
                              sphere(p + "Nose", 0.065, (0, face_y(w, 1.5) - 0.09, 1.55), scale=(1.3, 0.8, 0.9), m=m["black"], segs=10, rings=6)])
    tor, body = torso(p, m["fur"], w=0.98, d=0.68, z0=0.86, z1=1.46, waist=0.92, belly=0.16, hunch=0.06, chest=1.02, n=2.6)
    parts += tor
    parts += neck(p, m["fur"], 0.38, z1=1.48)
    t = tor[0]
    # Dungarees bib with straps, a heart patch and stitch lines.
    bib = [patch(p + "Bib", t, (0, body.front(0, 1.12), 1.12), (0.5, 0.03, 0.36), m["shirt"], bevel=0.02),
           patch(p + "Heart", t, (0.12, body.front(0.12, 1.16) - 0.012, 1.16), (0.12, 0.02, 0.1), m["heart"], rot=(0, 0, 0.6), bevel=0.02),
           patch(p + "Belly", t, (0, body.front(0, 0.98), 0.98), (0.6, 0.03, 0.18), m["fur_light"], bevel=0.03)]
    for s in (1, -1):
        bib += [patch(f"{p}Strap{s}", t, (s * 0.2, body.front(s * 0.2, 1.33), 1.33), (0.07, 0.03, 0.28), m["shirt"], bevel=0.01),
                sphere(f"{p}Btn{s}", 0.04, (s * 0.2, body.front(s * 0.2, 1.24) - 0.02, 1.24), m=m["gold"], segs=8, rings=5)]
    for k in range(5):
        z = 1.42 - k * 0.07
        bib.append(box(f"{p}Stitch{k}", (0.012, 0.02, 0.05), (-0.3, body.front(-0.3, z) - 0.008, z), rot=(0, 0.5, 0.0), bevel=0.0, m=m["stitch"]))
    parts += bz.bind("Spine", bib)
    parts += hips(p, m["shirt"], w=0.92, d=0.64, z0=0.7, belt=None)
    for side in (1, -1):
        parts += arm(p, side, fur, w=0.3, sleeve=m["fur"], sleeve_len="none", hand=0.1, out=0.14, curl=0.8, seed=67, fingers=3)
        parts += leg(p, side, fur, w=0.3, pants=m["shirt"], pants_len="long", foot="bare", tear=0)
    return parts


def plush_accessories(m):
    p = "PA_"
    w = 0.7
    ears = []
    for s in (1, -1):
        ears += [sphere(f"{p}Ear{s}", 0.17, (s * 0.31, HEAD_Y + 0.05, 1.98), scale=(1, 0.55, 1), m=m["fur"], segs=12, rings=8),
                 sphere(f"{p}EarIn{s}", 0.1, (s * 0.31, HEAD_Y - 0.03, 1.97), scale=(1, 0.4, 1), m=m["fur_light"], segs=10, rings=6)]
    bow = [prism(p + "Bow", [(-0.22, -0.13), (0, 0), (-0.22, 0.13), (0.22, 0.13), (0, 0), (0.22, -0.13)], 0.06, (0, -0.3, 1.46), m=m["red"]),
           sphere(p + "Knot", 0.05, (0, -0.33, 1.46), m=m["red"], segs=8, rings=5)]
    acc = {
        "Acc_Plush_Ears": bz.bind("Head", ears),
        "Acc_Plush_Bow": bz.bind("Spine", bow),
    }
    acc.update(faces("Plush", m, w, ("Grin", "Snarl"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# The Toymaker (the alpha)
# ---------------------------------------------------------------------------

def toymaker(m):
    p = "T_"
    w = 0.66
    parts = head(p, m, w)
    tor, body = torso(p, m["shirt"], w=1.0, d=0.66, z0=0.84, z1=1.48, waist=0.92, belly=0.16, hunch=0.12, chest=1.02, n=2.8)
    parts += tor
    parts += neck(p, m["skin"], 0.4, z1=1.48)
    t = tor[0]
    shirt = []
    for i in range(6):
        x = -0.3 + i * 0.12
        shirt.append(patch(f"{p}Stripe{i}", t, (x, body.front(x, 1.32), 1.32), (0.035, 0.02, 0.26), m["stripe"], bevel=0.004))
    # The apron: bib, pocket full of tools, straps over the shoulders.
    shirt += [patch(p + "ApronBib", t, (0, body.front(0, 1.12), 1.12), (0.56, 0.035, 0.44), m["leather"], bevel=0.02),
              box(p + "Pocket", (0.34, 0.05, 0.16), (0, body.front(0, 1.04) - 0.04, 1.04), bevel=0.02, m=m["leather"]),
              cyl(p + "Screwdriver", 0.016, 0.22, (-0.1, body.front(-0.1, 1.12) - 0.07, 1.14), segs=6, bevel=0.0, m=m["red"]),
              cyl(p + "Brush", 0.02, 0.2, (0.08, body.front(0.08, 1.12) - 0.07, 1.13), segs=6, bevel=0.0, m=m["wood"]),
              cyl(p + "Pencil", 0.014, 0.24, (0.15, body.front(0.15, 1.12) - 0.07, 1.15), segs=6, bevel=0.0, m=m["gold"])]
    for s in (1, -1):
        shirt.append(patch(f"{p}ApronStrap{s}", t, (s * 0.24, body.front(s * 0.24, 1.38), 1.38), (0.08, 0.03, 0.22), m["leather"], bevel=0.01))
    parts += bz.bind("Spine", shirt)
    parts += bz.bind("Hips", [blob(p + "ApronSkirt", (0, -0.12, 0.42), (0, -0.12, 0.92), [(0, 0.5, 0.36), (0.5, 0.49, 0.36), (1, 0.48, 0.35)],
                                   m["leather"], n=2.6, r0=0.03, r1=0.03, segs=22, mid=4)])
    parts += hips(p, m["navy"], w=0.9, d=0.62, z0=0.7, belt=m["leather"], buckle=m["brass"])
    # The walrus moustache and bushy brows.
    tache = [sphere(f"{p}Tache{s}", 0.11, (s * 0.1, face_y(w, 1.5) - 0.03, 1.49), scale=(1.6, 0.6, 0.6), rot=(0, s * 0.3, 0), m=m["hair"], segs=10,
                    rings=6) for s in (1, -1)]
    tache += [sphere(f"{p}Brow{s}", 0.07, (s * 0.15, face_y(w, 1.72) - 0.02, 1.72), scale=(1.7, 0.6, 0.6), m=m["hair"], segs=8, rings=5)
              for s in (1, -1)]
    parts += bz.bind("Head", tache)
    for side in (1, -1):
        parts += arm(p, side, m, w=0.3, sleeve=m["shirt"], sleeve_len="short", cuff=m["stripe"], hand=0.1, out=0.14, curl=0.8, seed=71)
        parts += leg(p, side, m, w=0.3, pants=m["navy"], pants_len="long", foot="boot", shoe=m["leather"], sole=m["black"], tear=0)
    return parts


def toymaker_accessories(m):
    p = "TA_"
    w = 0.66
    loupe = [head_band(p + "Band", w, 1.82, 1.77, m["leather"], off=0.05, thick=0.02),
             cyl(p + "Loupe", 0.09, 0.16, (0.14, face_y(w, 1.66) - 0.08, 1.66), rot=(math.radians(90), 0, 0), segs=14, bevel=0.01, m=m["brass"]),
             cyl(p + "Lens", 0.075, 0.03, (0.14, face_y(w, 1.66) - 0.165, 1.66), rot=(math.radians(90), 0, 0), segs=14, bevel=0.0, m=m["lens"])]
    for k, (x, z, r) in enumerate(((-0.32, 1.86, 0.16), (0.32, 1.86, 0.16), (-0.2, 2.0, 0.17), (0.2, 2.0, 0.17), (0.0, 2.08, 0.18),
                                    (-0.36, 1.68, 0.12), (0.36, 1.68, 0.12), (0, 1.95, 0.18))):
        loupe.append(sphere(f"{p}Hair{k}", r, (x, HEAD_Y + 0.08, z), m=m["hair"], segs=10, rings=7))
    mallet = [cyl(p + "Handle", 0.035, 0.75, (-0.62, -0.32, 0.5), rot=rad(90, 0, 0), segs=8, bevel=0.01, m=m["wood"]),
              cyl(p + "Head", 0.16, 0.42, (-0.62, -0.72, 0.5), rot=rad(0, 90, 0), segs=14, bevel=0.03, m=m["red"]),
              cyl(p + "Face", 0.165, 0.06, (-0.42, -0.72, 0.5), rot=rad(0, 90, 0), segs=14, bevel=0.01, m=m["gold"]),
              cyl(p + "Face2", 0.165, 0.06, (-0.82, -0.72, 0.5), rot=rad(0, 90, 0), segs=14, bevel=0.01, m=m["gold"])]
    acc = {
        "Acc_Toymaker_Loupe": bz.bind("Head", loupe),
        "Acc_Toymaker_Mallet": bz.bind("ForeArm.R", mallet),
    }
    acc.update(faces("Toymaker", m, w, ("Snarl", "Grin"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# The wind-up key (static model; the behaviours spin it)
# ---------------------------------------------------------------------------

def build_key():
    reset_scene()
    brass, dark = tmat("Brass", rough=0.3, metal=0.6), tmat("YellowDark", rough=0.4, metal=0.4)
    # Blender: shaft along +Y (exported as -Z in Godot) from the origin.
    p = [cyl("Shaft", 0.035, 0.32, (0, 0.16, 0), rot=rad(90, 0, 0), segs=10, bevel=0.01, m=brass),
         cyl("Collar", 0.06, 0.05, (0, 0.03, 0), rot=rad(90, 0, 0), segs=12, bevel=0.01, m=dark),
         box("Stem", (0.07, 0.08, 0.07), (0, 0.33, 0), bevel=0.015, m=brass)]
    for s in (1, -1):
        p.append(torus(f"Bow{s}", 0.1, 0.03, (s * 0.12, 0.36, 0), rot=rad(90, 0, 0), m=brass, major_segs=16, minor_segs=6))
    save("toy_key", [merge("Key", p)])


# ---------------------------------------------------------------------------
# Clips
# ---------------------------------------------------------------------------

def tin_march(period, stance, lift):
    """Stiff tin-soldier march: upright, high knees, straight arms swinging."""
    d = 0.6

    def arms_fn(ph):
        c, _ = za._cs(ph)
        return za.arms(-14 + 34 * c, -6, -14 - 34 * c, -6, spread=8)
    return za.Gait(period, d, stance, lift, za.walker(d, lean=1, hips_pitch=1, yaw=3, roll=2, sway=0.02, twist=0.6, head=0, loll=0,
                                                      arms_fn=arms_fn), front=0.5, bob=0.035)


def windup(rig, name="Windup"):
    """Standing to attention while the key turns: heels together, chin up, a
    small clockwork shudder on every click."""
    keys = []
    for i in range(9):
        c, s = za._cs(i / 8)
        keys.append((i * 2, {"Hips": (0, 0, 2 * s), "Spine": (-2, 0, 0), "Head": (-6, 0, 3 * c), "hips": (0, 0, 0.02 * abs(s)),
                             **za.feet(0.12, 0.0, 0.0), **za.arms(4, -4, 4, -4, spread=6)}, "io"))
    return za.keyed(rig, name, keys, loop=True)


def toy_clips(rig):
    """toy_zombies.glb: Soldier (Walk march, PowerWalk, Windup), Brute (Walk_Heavy,
    Crouch, Leap), Toymaker (style "Heavy": stomp, slam, roar, throw; Run charge)."""
    return [za.idle(rig), za.gait(rig, "Walk", tin_march(0.6, 0.78, 0.16)), za.gait(rig, "PowerWalk", tin_march(0.42, 1.15, 0.2)),
            windup(rig), za.crouch(rig), za.leap(rig),
            za.idle(rig, "Idle_Heavy", heavy=True), za.gait(rig, "Walk_Heavy", za.stomp()), za.gait(rig, "Run", za.charge()),
            za.attack(rig), za.attack_heavy(rig), za.throw(rig), za.roar(rig), *za._common(rig, heavy=True)]


def build():
    scene = reset_scene()
    scene.render.fps = bz.FPS
    m = materials()
    armature = bz.build_armature()
    meshes = [
        bz.skin("Outfit_Soldier", soldier(m), armature),
        bz.skin("Outfit_Plush", plush(m), armature),
        bz.skin("Outfit_Toymaker", toymaker(m), armature),
    ]
    accessories = {}
    accessories.update(soldier_accessories(m))
    accessories.update(plush_accessories(m))
    accessories.update(toymaker_accessories(m))
    for name, parts in accessories.items():
        meshes.append(bz.skin(name, parts, armature))
    zombie_anim.bake(armature, toy_clips, "toy_zombies")
    bz.save_zombie("toy_zombies", [armature] + meshes)


if __name__ == "__main__":
    wanted = sys.argv[1:] or ["zombies", "key"]
    if "zombies" in wanted:
        build()
    if "key" in wanted:
        build_key()
