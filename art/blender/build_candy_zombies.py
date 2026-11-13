"""Sugar Rush Factory zombies: one rig (the same bones as build_zombie.py, which
this script reuses), three outfits.

    Outfit_Gummy    Gummy Bear: a worker who fell in the gummy vat, set in a
                    tintable gummy-bear shell ("Shirt") with round ears, a fat
                    belly and stubby limbs; the face peers out of the bear's head.
                    A clear sugar glaze (Acc_Gummy_Glaze) makes it glisten.
    Outfit_Taffy    Taffy Puller: a burly factory hand in a tintable shirt, a
                    pink-and-white striped apron, chocolate trousers, boots and
                    big pink rubber gloves; a paper hat, a coil of taffy over the
                    shoulder and a taffy rope in the right fist.
    Outfit_Chef     The Confectioner (alpha): a giant pastry chef in a tintable
                    double-breasted chef's coat, a polka-dot apron and checked
                    trousers, with a towering toque, a curled moustache and a
                    piping bag.

Bodies, heads and faces come from zombie_kit.py; each outfit has several faces
(Face_<Outfit>_<Preset>), one shown per zombie.

Clips (candy_clips): the shared set, plus
    Walk_Gummy   the gummy's springy, squashy waddle (style "Gummy")
    Idle_Gummy   a jelly wobble on the spot
    Whirl        the Taffy Puller's windup: the rope whirled overhead
    Yank         the lash and the hard pull back
    Throw        the Confectioner's overhead heave (gumball volley)
and the heavy stomp, slam and roar for the Confectioner (style "Heavy").

    python art/blender/build_candy_zombies.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from candy_common import *  # noqa: F401,F403
import build_zombie as bz  # noqa: E402
import zombie_anim  # noqa: E402
from zombie_anim import _cs, arms, feet, keyed  # noqa: E402
from zombie_kit import (HEAD_Y, SPARK_EYE, arm, band, base_materials, blob, cap_crown, decal, face_y, faces, glass, hair, head,  # noqa: E402
                        head_band, hips, leg, neck, patch, skull, torso)


def materials():
    m = base_materials("candy", skin="#9ad18a", skin_dark="#68a65c", dark="#2a1a24", white="#fffaf4", eye=(SPARK_EYE, 2.4))
    m.update(
        shirt=mat("Shirt", "#ff4a5e", rough=0.22),
        pink=mat("CandyZPink", "#ff7eb6", rough=0.4),
        pink_deep=mat("CandyZPinkDeep", "#e8508f", rough=0.4),
        cream=mat("CandyZCream", "#fff3e0", rough=0.5),
        choc=mat("CandyZChoc", "#5a3324", rough=0.6),
        mint=mat("CandyZMint", "#7fe3c4", rough=0.45),
        lemon=mat("CandyZLemon", "#ffd23f", rough=0.45),
        lilac=mat("CandyZLilac", "#c9a7ff", rough=0.45),
        gold=mat("CandyZGold", "#ffc94a", rough=0.3, metal=0.6, emit=0.3),
        taffy=mat("CandyZTaffy", "#ff9ec9", rough=0.3, emit=0.2),
        glove=mat("CandyZGlove", "#ff5fa2", rough=0.25),
        steel=mat("CandyZSteel", "#c7c4d6", rough=0.3, metal=0.6),
        glaze=glass("CandyGlaze", "#fff6fb", alpha=0.22, emit=0.12, rough=0.05),
        sugar=mat("CandyZSugar", "#ffffff", rough=0.3, emit=0.35),
    )
    return m


# ---------------------------------------------------------------------------
# Gummy Bear
# ---------------------------------------------------------------------------

def gummy(m):
    """A gummy-bear shell ("Shirt", tinted per zombie): a bear head with round
    ears framing the zombie's face, a fat belly and stubby rounded limbs."""
    p = "G_"
    w = 0.62
    gum = m["shirt"]
    parts = head(p, m, w, ears=False)
    sk = skull(w)
    parts += bz.bind("Head", [
        sk.shell(p + "Hood", gum, 1.99, 1.27, off=0.08, gap=150, segs=28, steps=7, lip=0.06),
        sphere(p + "HoodTop", 0.39, (0, HEAD_Y + 0.05, 1.86), scale=(1.05, 1.0, 0.64), m=gum, segs=18, rings=9),
        sphere(p + "EarL", 0.15, (-0.33, HEAD_Y + 0.06, 2.06), scale=(1.0, 0.6, 1.0), m=gum, segs=14, rings=8),
        sphere(p + "EarR", 0.15, (0.33, HEAD_Y + 0.06, 2.06), scale=(1.0, 0.6, 1.0), m=gum, segs=14, rings=8),
        sphere(p + "Snout", 0.12, (0, face_y(w, 1.4) - 0.07, 1.38), scale=(1.4, 0.7, 0.8), m=gum, segs=12, rings=7),
    ])
    tor, body = torso(p, gum, w=0.9, d=0.66, z0=0.84, z1=1.42, waist=0.96, belly=0.16, hunch=0.06, chest=0.94, n=2.4)
    parts += tor
    parts += neck(p, gum, 0.36)
    parts += bz.bind("Spine", [
        sphere(p + "Belly", 0.3, (0, body.front(0, 1.04) + 0.06, 1.04), scale=(1.05, 0.42, 1.1), m=gum, segs=18, rings=10),
    ])
    parts += hips(p, gum, w=0.84, d=0.62, z0=0.7)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.24, skin=gum, sleeve=gum, sleeve_len="long", glove=gum, fingers=0, hand=0.04, out=0.08, seed=41)
        parts += leg(p, side, m, w=0.27, skin=gum, pants=gum, pants_len="long", foot="bare", tear=0)
        parts += bz.bind(f"Shin.{s}", [sphere(f"{p}Paw{s}", 0.16, (side * 0.17, -0.06, 0.1), scale=(1.0, 1.35, 0.6), m=gum, segs=14, rings=8)])
    return parts


def gummy_accessories(m):
    p = "GA_"
    rng = random.Random(6)
    sugar = []
    for i in range(16):
        a, z = rng.uniform(0, math.tau), rng.uniform(0.95, 1.38)
        sugar.append(box(f"{p}Sugar{i}", (0.035, 0.035, 0.035), (math.cos(a) * 0.46, math.sin(a) * 0.34 - 0.02, z),
                         rot=(rng.uniform(0, 1), rng.uniform(0, 1), rng.uniform(0, 1)), bevel=0.0, m=m["sugar"]))
    acc = {
        "Acc_Gummy_Glaze": bz.bind("Spine", [
            sphere(p + "GlazeBelly", 0.5, (0, 0.0, 1.12), scale=(1.0, 0.76, 0.72), m=m["glaze"], segs=20, rings=12),
        ]) + bz.bind("Head", [
            sphere(p + "GlazeHead", 0.42, (0, HEAD_Y + 0.08, 1.86), scale=(1.1, 1.05, 0.72), m=m["glaze"], segs=18, rings=10),
        ]),
        "Acc_Gummy_Sugar": bz.bind("Spine", sugar),
        "Acc_Gummy_Cap": bz.bind("Head", [
            cyl(p + "Cap", 0.2, 0.16, (0.12, HEAD_Y + 0.02, 2.2), rot=rad(0, 18, 0), segs=16, bevel=0.03, m=m["cream"]),
            cyl(p + "CapBand", 0.205, 0.05, (0.115, HEAD_Y + 0.02, 2.15), rot=rad(0, 18, 0), segs=16, bevel=0.0, m=m["pink"]),
        ]),
        "Acc_Gummy_Badge": bz.bind("Spine", [
            box(p + "Badge", (0.16, 0.03, 0.2), (-0.22, -0.4, 1.28), rot=rad(0, 0, -8), bevel=0.02, m=m["cream"]),
            box(p + "BadgeStripe", (0.165, 0.035, 0.05), (-0.22, -0.405, 1.34), rot=rad(0, 0, -8), bevel=0.0, m=m["pink_deep"]),
        ]),
    }
    acc.update(faces("Gummy", m, 0.62, ("Grin", "Gape", "Snarl"), tongue=m["pink_deep"]))
    return acc


# ---------------------------------------------------------------------------
# Taffy Puller
# ---------------------------------------------------------------------------

def taffy(m):
    """A burly puller: tinted shirt, striped apron, chocolate trousers, boots,
    pink rubber gloves."""
    p = "T_"
    w = 0.6
    shirt, pink, white = m["shirt"], m["pink"], m["cream"]
    parts = head(p, m, w)
    parts += hair(p, w, m["choc"], "fringe", 23)
    tor, body = torso(p, shirt, w=0.86, d=0.56, z0=0.88, belly=0.08, hunch=0.06, chest=1.04, n=2.8)
    parts += tor
    parts += neck(p, m["skin"], 0.3)
    t = tor[0]
    apron = []
    for i in range(5):
        x = -0.24 + i * 0.12
        apron.append(patch(f"{p}Apron{i}", t, (x, body.front(x, 1.08), 1.08), (0.125, 0.04, 0.5), pink if i % 2 == 0 else white, bevel=0.01))
    apron.append(patch(p + "ApronBib", t, (0, body.front(0, 1.34), 1.34), (0.32, 0.04, 0.14), pink, bevel=0.01))
    for side in (1, -1):
        apron.append(blob(f"{p}Strap{'L' if side > 0 else 'R'}", (side * 0.16, -0.24, 1.4), (side * 0.2, 0.1, 1.46),
                          [(0, 0.02, 0.012), (1, 0.02, 0.012)], pink, n=2.0, r0=0.0, r1=0.0, segs=8, mid=2))
    parts += bz.bind("Spine", apron)
    parts += hips(p, m["choc"], w=0.78, d=0.52, belt=m["choc"], buckle=m["gold"])
    parts += bz.bind("Hips", [box(p + "ApronSkirt", (0.62, 0.04, 0.4), (0, -0.29, 0.8), rot=rad(-6, 0, 0), bevel=0.015, m=pink),
                              box(p + "ApronSkirtStripe", (0.63, 0.045, 0.06), (0, -0.295, 0.66), rot=rad(-6, 0, 0), bevel=0.0, m=white)])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.21, sleeve=shirt, sleeve_len="short", cuff=white, glove=m["glove"], hand=0.07, out=0.06, seed=37)
        parts += leg(p, side, m, w=0.23, pants=m["choc"], pants_len="long", foot="boot", shoe=m["choc"], sole=m["dark"], lace=m["lemon"],
                     boot_h=0.26, tear=0)
        parts += bz.bind(f"UpperArm.{s}", [band(f"{p}SleeveStripe{s}", (side * 0.4, 0, 1.22), (side * 0.4, 0, 1.17), 0.125, 0.125, white, n=2.4,
                                                thick=0.015, flare=0.0, segs=14)])
    return parts


def taffy_accessories(m):
    p = "TA_"
    w = 0.6
    taffy_m = m["taffy"]
    coil = []
    for k in range(3):
        coil.append(torus(f"{p}Coil{k}", 0.5 - k * 0.03, 0.055, (0.0, 0.0, 1.2 + k * 0.03), rot=rad(0, 32, 0), m=taffy_m, major_segs=26, minor_segs=7))
    rope = [(-0.47, -0.02, 0.62)]
    for i in range(1, 9):
        t = i / 8
        rope.append((-0.47 - 0.08 * math.sin(t * 3.0), -0.1 - 0.12 * t, 0.62 - 0.55 * t))
    acc = {
        "Acc_Taffy_Hat": bz.bind("Head", [
            cap_crown(p + "Hat", w, m["cream"], rim=1.76, top=2.12),
            head_band(p + "HatBand", w, 1.83, 1.75, m["pink"], off=0.045, thick=0.025),
        ]),
        "Acc_Taffy_Net": bz.bind("Head", [cap_crown(p + "Net", w, m["lilac"], rim=1.74, top=1.98, off=0.02)]),
        "Acc_Taffy_Coil": bz.bind("Spine", coil),
        "Acc_Taffy_Rope": bz.bind("ForeArm.R", [tube(p + "Rope", rope, 0.05, m=taffy_m, segs=8, radius_end=0.035)]),
        "Acc_Taffy_Badge": bz.bind("Spine", [
            box(p + "Badge", (0.15, 0.03, 0.1), (0.2, -0.33, 1.32), rot=rad(0, 0, 6), bevel=0.02, m=m["lemon"]),
        ]),
    }
    acc.update(faces("Taffy", m, w, ("Snarl", "Grin", "Gape"), tongue=m["pink_deep"]))
    return acc


# ---------------------------------------------------------------------------
# The Confectioner (alpha)
# ---------------------------------------------------------------------------

def chef(m):
    """A giant pastry chef: tinted double-breasted coat, polka-dot apron,
    checked trousers, a pink neckerchief and big white clogs."""
    p = "C_"
    w = 0.66
    coat, cream = m["shirt"], m["cream"]
    parts = head(p, m, w)
    parts += hair(p, w, m["choc"], "mop", 29)
    tor, body = torso(p, coat, w=1.06, d=0.72, z0=0.84, z1=1.48, waist=0.94, belly=0.16, hunch=0.08, chest=1.02, n=2.6)
    parts += tor
    parts += neck(p, m["skin"], 0.4, z1=1.48)
    t = tor[0]
    detail = [
        patch(p + "Apron", t, (0, body.front(0, 1.0), 1.0), (0.56, 0.04, 0.34), m["pink"], bevel=0.015),
        torus(p + "Kerchief", 0.27, 0.07, (0, -0.02, 1.47), m=m["pink_deep"], major_segs=22, minor_segs=7),
        box(p + "KerchiefKnot", (0.14, 0.08, 0.1), (0, -0.3, 1.42), bevel=0.03, m=m["pink_deep"]),
    ]
    for i in range(3):
        for side in (1, -1):
            x = side * 0.13
            z = 1.32 - i * 0.12
            detail.append(cyl(f"{p}Button{side}{i}", 0.03, 0.03, (x, body.front(x, z) - 0.01, z), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=m["gold"]))
    for i, (x, z) in enumerate(((-0.16, 1.08), (0.1, 1.12), (-0.04, 0.96), (0.18, 0.95), (-0.2, 0.9))):
        detail.append(decal(f"{p}Dot{i}", t, (x, body.front(x, z) - 0.02, z), 0.032, cream))
    parts += bz.bind("Spine", detail)
    parts += hips(p, m["lilac"], w=0.96, d=0.66, z0=0.7)
    parts += bz.bind("Hips", [box(p + "ApronSkirt", (0.7, 0.04, 0.46), (0, -0.35, 0.78), rot=rad(-6, 0, 0), bevel=0.015, m=m["pink"])])
    for side in (1, -1):
        parts += arm(p, side, m, w=0.28, sleeve=coat, sleeve_len="long", cuff=cream, glove=m["cream"], hand=0.08, out=0.12, seed=43)
        parts += leg(p, side, m, w=0.3, pants=m["lilac"], pants_len="long", foot="shoe", shoe=cream, sole=m["choc"], lace=m["pink"], tear=0)
    return parts


def chef_accessories(m):
    p = "CA_"
    w = 0.66
    cream = m["cream"]
    toque = [cyl(p + "ToqueBand", 0.36, 0.3, (0, HEAD_Y + 0.02, 1.98), segs=24, bevel=0.03, m=cream)]
    for i in range(7):
        a = math.tau * i / 7
        toque.append(sphere(f"{p}Puff{i}", 0.2, (math.cos(a) * 0.2, HEAD_Y + 0.02 + math.sin(a) * 0.2, 2.45), scale=(1, 1, 1.5), m=cream, segs=12, rings=7))
    toque.append(cyl(p + "ToqueCore", 0.32, 0.5, (0, HEAD_Y + 0.02, 2.36), segs=20, bevel=0.06, m=cream))
    toque.append(sphere(p + "ToqueTop", 0.3, (0, HEAD_Y + 0.02, 2.68), scale=(1.1, 1.1, 0.6), m=cream, segs=14, rings=7))
    stache = []
    for side in (1, -1):
        pts = [(0, face_y(w, 1.44) - 0.06, 1.44), (side * 0.1, face_y(w, 1.44) - 0.05, 1.42), (side * 0.2, face_y(w, 1.44) - 0.0, 1.46),
               (side * 0.24, face_y(w, 1.44) + 0.03, 1.53)]
        stache.append(tube(f"{p}Stache{side}", pts, 0.045, m=m["choc"], segs=8, radius_end=0.015))
    acc = {
        "Acc_Chef_Toque": bz.bind("Head", toque),
        "Acc_Chef_Stache": bz.bind("Head", stache),
        "Acc_Chef_Piping": bz.bind("ForeArm.R", [
            cyl(p + "Bag", 0.13, 0.42, (-0.5, -0.14, 0.42), rot=rad(16, 0, 0), segs=14, bevel=0.03, m=m["cream"], radius_top=0.04),
            cyl(p + "Nozzle", 0.04, 0.12, (-0.5, -0.08, 0.2), rot=rad(16, 0, 0), segs=10, bevel=0.0, m=m["steel"], radius_top=0.012),
            sphere(p + "Icing", 0.1, (-0.5, -0.15, 0.6), scale=(1, 1, 0.7), m=m["pink"], segs=12, rings=7),
        ]),
    }
    acc.update(faces("Chef", m, w, ("Snarl", "Grin"), tongue=m["pink_deep"]))
    return acc


# ---------------------------------------------------------------------------
# Clips
# ---------------------------------------------------------------------------

def jelly_waddle():
    """Gummy Bear: short springy steps on stubby legs, the body bouncing and
    swaying wide like jelly, arms bobbing out to the sides."""
    d = 0.56

    def arms_fn(ph):
        c, s = _cs(ph)
        return arms(-24 + 12 * s, -30 + 10 * c, -24 - 12 * s, -30 - 10 * c, spread=26)
    return zombie_anim.Gait(0.56, d, 0.6, 0.12, zombie_anim.walker(d, lean=6, yaw=6, roll=10, sway=0.07, loll=9, head=-4, arms_fn=arms_fn),
                            front=0.5, width=0.06, bob=0.08, bob_style="run", crouch=0.04)


def jelly_idle(rig, name="Idle_Gummy"):
    keys = []
    for i in range(9):
        c, s = _cs(i / 8)
        keys.append((i * 3, {"Hips": (4, 0, 4 * s), "Spine": (6 + 3 * c, 5 * s, -3 * s), "Head": (-6, 6 * s, 4 * c),
                             "hips": (0.02 * s, 0, -0.03 + 0.03 * c), **feet(0.2, 0.02, -0.02), **arms(-20 + 8 * c, -28, -20 - 8 * c, -28, spread=26)}, "io"))
    return keyed(rig, name, keys, loop=True)


def whirl(rig, name="Whirl"):
    """Taffy Puller windup: planted wide, leaning back, the left hand aiming
    forward while the right whirls the rope round overhead."""
    keys = []
    n = 8
    for i in range(n + 1):
        c, s = _cs(i / n)
        keys.append((i * 2, {"Hips": (-4, 0, 6), "Spine": (-10, 0, 10 + 4 * s), "Head": (-6, 0, -10),
                             "hips": (0, -0.04, -0.06), **feet(0.26, 0.14, -0.12),
                             "UpperArm.L": (-78, -10, 0), "ForeArm.L": (-10, 0, 0),
                             "UpperArm.R": (-150 + 22 * c, 22 + 26 * s, 0), "ForeArm.R": (-30 - 20 * s, 0, 0)}, "lin"))
    return keyed(rig, name, keys, loop=True)


def yank(rig, name="Yank"):
    """The lash (frames 0-4: the arm snaps forward) and the pull (4-14: both
    fists haul back, the body leaning away), then recover."""
    base = {"Hips": (-4, 0, 6), "Spine": (-10, 0, 10), "Head": (-6, 0, -10), "hips": (0, -0.04, -0.06), **feet(0.26, 0.14, -0.12),
            "UpperArm.L": (-78, -10, 0), "ForeArm.L": (-10, 0, 0), "UpperArm.R": (-150, 30, 0), "ForeArm.R": (-30, 0, 0)}
    lash = {"Spine": (22, 0, -6), "Hips": (10, 0, -4), "Head": (-18, 0, 0), "hips": (0, 0.08, -0.08),
            "UpperArm.R": (-95, 6, 0), "ForeArm.R": (-6, 0, 0), "UpperArm.L": (-60, -12, 0)}
    haul = {"Spine": (-22, 0, 4), "Hips": (-10, 0, 2), "Head": (-2, 0, 0), "hips": (0, -0.12, -0.1),
            "UpperArm.R": (-20, 20, 0), "ForeArm.R": (-100, 0, 0), "UpperArm.L": (-30, -16, 0), "ForeArm.L": (-95, 0, 0)}
    rest = {"Spine": (8, 0, 0), "Hips": (4, 0, 0), "Head": (-8, 0, 0), "hips": (0, 0, -0.03),
            "UpperArm.R": (-30, 10, 0), "ForeArm.R": (-40, 0, 0), "UpperArm.L": (-30, -10, 0), "ForeArm.L": (-40, 0, 0)}
    return keyed(rig, name, [(0, base), (4, lash, "snap"), (8, haul, "out"), (14, haul), (22, rest, "io")])


def candy_clips(rig):
    """candy_zombies.glb: Taffy Puller (march, whirl, yank), Gummy Bear (style
    "Gummy": jelly waddle), the Confectioner (style "Heavy": stomp, slam,
    roar, throw)."""
    return [zombie_anim.idle(rig), zombie_anim.gait(rig, "Walk", zombie_anim.march()), zombie_anim.gait(rig, "Run", zombie_anim.flail_sprint()),
            zombie_anim.gait(rig, "Walk_Gummy", jelly_waddle()), jelly_idle(rig),
            zombie_anim.attack(rig), whirl(rig), yank(rig),
            zombie_anim.idle(rig, "Idle_Heavy", heavy=True), zombie_anim.gait(rig, "Walk_Heavy", zombie_anim.stomp()),
            zombie_anim.attack_heavy(rig), zombie_anim.roar(rig), zombie_anim.throw(rig), *zombie_anim._common(rig, heavy=True)]


def build():
    scene = reset_scene()
    scene.render.fps = bz.FPS
    m = materials()
    armature = bz.build_armature()
    meshes = [
        bz.skin("Outfit_Gummy", gummy(m), armature),
        bz.skin("Outfit_Taffy", taffy(m), armature),
        bz.skin("Outfit_Chef", chef(m), armature),
    ]
    accessories = {}
    accessories.update(gummy_accessories(m))
    accessories.update(taffy_accessories(m))
    accessories.update(chef_accessories(m))
    for name, parts in accessories.items():
        meshes.append(bz.skin(name, parts, armature))
    zombie_anim.bake(armature, candy_clips, "candy_zombies")
    bz.save_zombie("candy_zombies", [armature] + meshes)


if __name__ == "__main__":
    build()
