"""Pirate Cove zombies (World 13, Skull Harbor): the shared rig (build_zombie.py),
three outfits.

    Outfit_Deckhand   Deckhand: a lean pirate in a tintable striped jersey
                      ("Shirt" with cream hoops), a red sash, rolled navy
                      trousers and boots; a knotted bandana (Acc_Deckhand_Bandana),
                      an eye patch (Acc_Deckhand_Patch) and a cutlass in the
                      right hand (Acc_Deckhand_Cutlass)
    Outfit_Monkey     Powder Monkey: a small, quick ship's boy in a tintable
                      shirt ("Shirt") under a short striped waistcoat, knee
                      breeches, bare shins and soot smudges; a knit cap
                      (Acc_Monkey_Cap), a powder keg strapped to the back
                      (Acc_Monkey_Pack) and the lit keg it throws (Acc_Monkey_Keg,
                      shown by the game during the wind-up)
    Outfit_Barnacle   Captain Barnacle (the alpha): a hulking pirate captain in a
                      long frock coat ("Shirt") crusted with barnacles, gold
                      buttons and braid, a black beard in braids, a hook for a
                      left hand; a huge tricorn with a skull badge and a plume
                      (Acc_Barnacle_Tricorn) and a ship's anchor in the right
                      hand (Acc_Barnacle_Anchor)

Faces: two presets per outfit (Face_<Outfit>_<Preset>).

Clips (cove_clips below, from zombie_anim): the shared set, the Deckhand's
sprint and Tuck (the lunge crouch), the Monkey's shamble and overhead Throw
(the keg heave), the Captain's stomp, slam and roar ("_Heavy").

    python art/blender/build_cove_zombies.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cove_common import *  # noqa: F401,F403
import build_zombie as bz  # noqa: E402
import zombie_anim  # noqa: E402
from zombie_anim import (attack, attack_heavy, flail_sprint, gait, idle, roar, shamble, stagger, stomp, throw, tuck, hit_head,  # noqa: E402
                         deaths, emerge)
from zombie_kit import (HEAD_Y, SPARK_EYE, cap_crown, head_band, arm, band, base_materials, blob, decal, face_y, faces, hair,  # noqa: E402
                        head, hips, leg, neck, patch, torso)


def materials():
    m = base_materials("cove", skin="#9fd16a", skin_dark="#6a9a44", dark="#22202c", white="#fbf6ec", eye=(SPARK_EYE, 2.6))
    m.update(
        shirt=mat("Shirt", "#d8333f", rough=0.55),
        stripe=mat("CoveZStripe", "#fff1dc", rough=0.6),
        navy=mat("CoveZNavy", "#23304f", rough=0.6),
        red=mat("CoveZRed", "#c42a38", rough=0.5),
        black=mat("CoveZBlack", "#1d1c26", rough=0.6),
        gold=mat("CoveZGold", "#ffc24a", rough=0.35, metal=0.3),
        steel=mat("CoveZSteel", "#cfd6e2", rough=0.25, metal=0.7),
        brass=mat("CoveZBrass", "#e3a93b", rough=0.3, metal=0.6),
        wood=mat("CoveZWood", "#b5733f", rough=0.75),
        wood_dark=mat("CoveZWoodDark", "#6e3f24", rough=0.75),
        iron=mat("CoveZIron", "#3b3f4c", rough=0.45, metal=0.5),
        teal=mat("CoveZTeal", "#1fa89e", rough=0.5),
        barnacle=mat("CoveZBarnacle", "#d9d2c0", rough=0.8),
        barnacle_dark=mat("CoveZBarnacleDark", "#8a9a8e", rough=0.8),
        soot=mat("CoveZSoot", "#3a3438", rough=0.9),
        fuse=mat("CoveZFuse", "#ffb43a", rough=0.3, emit=3.0),
        feather=mat("CoveZFeather", "#ff6a4a", rough=0.6),
        beard=mat("CoveZBeard", "#2a2028", rough=0.85),
    )
    return m


def keg(name, loc, m, scale=1.0, lit=True):
    """A small powder keg (banded, a skull daub) with its fuse."""
    x, y, z = loc
    k = scale
    prof = [(0.13 * k, -0.15 * k), (0.16 * k, 0.0), (0.13 * k, 0.15 * k)]
    body = lathe(name + "Body", prof, [m["wood"]], segs=12, smooth=True)
    body.location = (x, y, z)
    parts = [body]
    for i, hz in enumerate((-0.09, 0.09)):
        parts.append(torus(f"{name}Hoop{i}", 0.155 * k, 0.014 * k, (x, y, z + hz * k), m=m["iron"], major_segs=12, minor_segs=4))
    parts.append(sphere(name + "Daub", 0.05 * k, (x, y - 0.15 * k, z), scale=(1, 0.3, 1), m=m["stripe"], segs=8, rings=5))
    parts.append(tube(name + "Fuse", [(x, y, z + 0.15 * k), (x + 0.03 * k, y, z + 0.22 * k), (x + 0.07 * k, y - 0.01 * k, z + 0.26 * k)], 0.012 * k,
                      m=m["black"], segs=5))
    if lit:
        parts.append(sphere(name + "Spark", 0.035 * k, (x + 0.075 * k, y - 0.01 * k, z + 0.275 * k), m=m["fuse"], segs=6, rings=4))
    return parts


# ---------------------------------------------------------------------------
# Deckhand
# ---------------------------------------------------------------------------

def deckhand(m):
    p = "D_"
    w = 0.57
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "fringe", 41)
    tor, body = torso(p, m["shirt"], w=0.64, d=0.42, z0=0.9, hunch=0.05, n=3.0, hem=m["stripe"])
    parts += tor
    parts += neck(p, m["skin"], 0.23)
    t = tor[0]
    hoops = []
    for i, z in enumerate((1.08, 1.2, 1.32)):
        hoops.append(band(f"{p}Hoop{i}", (0, 0, z + 0.03), (0, 0, z - 0.03), 0.3 * (0.86 + 0.14 * (z - 0.9) / 0.54) + 0.012, 0.215, m["stripe"],
                          n=3.0, thick=0.012, segs=24))
    parts += bz.bind("Spine", hoops + [
        patch(p + "Collar", t, (0, body.front(0, 1.4), 1.4), (0.24, 0.03, 0.08), m["stripe"], bevel=0.01),
    ])
    parts += hips(p, m["navy"], w=0.6, d=0.42, belt=m["red"])
    parts += bz.bind("Hips", [box(p + "SashTail", (0.1, 0.05, 0.28), (0.24, -0.18, 0.84), rot=(0, 0.25, 0), bevel=0.02, m=m["red"]),
                              box(p + "SashKnot", (0.12, 0.06, 0.09), (0.22, -0.22, 0.97), bevel=0.03, m=m["red"])])
    for side in (1, -1):
        parts += arm(p, side, m, w=0.17, sleeve=m["shirt"], sleeve_len="short", cuff=None, seed=61)
        parts += leg(p, side, m, w=0.19, pants=m["navy"], pants_len="long", hem=m["stripe"], foot="boot", shoe=m["black"], sole=m["dark"], tear=2)
    return parts


def deckhand_accessories(m):
    p = "DA_"
    w = 0.57
    bandana = [cap_crown(p + "Bandana", w, m["red"], rim=1.78, top=1.98, off=0.04),
               box(p + "Knot", (0.1, 0.08, 0.08), (0.0, 0.3, 1.86), bevel=0.03, m=m["red"]),
               box(p + "TailA", (0.06, 0.04, 0.22), (0.05, 0.33, 1.74), rot=(0.4, 0.2, 0), bevel=0.015, m=m["red"]),
               box(p + "TailB", (0.06, 0.04, 0.2), (-0.05, 0.34, 1.75), rot=(0.5, -0.25, 0), bevel=0.015, m=m["red"])]
    for i in range(5):
        a = math.tau * i / 5
        bandana.append(sphere(f"{p}Dot{i}", 0.025, (math.cos(a) * 0.2, face_y(w, 1.9) + 0.06 + math.sin(a) * 0.05, 1.9 + 0.03 * math.sin(a * 2)),
                              m=m["stripe"], segs=6, rings=4))
    gy = face_y(w, 1.66) - 0.03
    patch_parts = [head_band(p + "PatchBand", w, 1.71, 1.68, m["black"], off=0.03, thick=0.012),
                   cyl(p + "Patch", 0.075, 0.03, (0.12, gy - 0.02, 1.65), rot=rad(80, 0, 0), segs=12, bevel=0.01, m=m["black"])]
    # The cutlass: grip in the right fist, a curved blade sweeping forward.
    hx, hy, hz = -0.44, -0.04, 0.56
    blade = tube(p + "Blade", [(0.0, -0.12 - 0.12 * i, 0.016 * i * i) for i in range(8)], 0.07, m=m["steel"], segs=6, radius_end=0.025)
    blade.scale = (0.28, 1.0, 1.0)
    blade.location = (hx, hy, hz)
    cutlass = [cyl(p + "Grip", 0.03, 0.18, (hx, hy, hz), rot=rad(90, 0, 0), segs=8, bevel=0.0, m=m["wood_dark"]),
               torus(p + "Guard", 0.075, 0.02, (hx, hy - 0.1, hz - 0.02), rot=rad(0, 90, 0), m=m["brass"], major_segs=10, minor_segs=4, arc=math.pi,
                     start=math.pi),
               sphere(p + "Pommel", 0.04, (hx, hy + 0.1, hz), m=m["brass"], segs=8, rings=5), blade]
    acc = {
        "Acc_Deckhand_Bandana": bz.bind("Head", bandana),
        "Acc_Deckhand_Patch": bz.bind("Head", patch_parts),
        "Acc_Deckhand_Cutlass": bz.bind("ForeArm.R", cutlass),
    }
    acc.update(faces("Deckhand", m, w, ("Grin", "Snarl"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Powder Monkey
# ---------------------------------------------------------------------------

def monkey(m):
    p = "M_"
    w = 0.58
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "fringe", 43)
    tor, body = torso(p, m["shirt"], w=0.56, d=0.38, z0=0.92, hunch=0.06, n=3.0)
    parts += tor
    parts += neck(p, m["skin"], 0.22)
    t = tor[0]
    vest = []
    for s in (-1, 1):
        x = s * 0.17
        vest.append(patch(f"{p}Vest{s}", t, (x, body.front(x, 1.18), 1.18), (0.16, 0.03, 0.42), m["teal"], bevel=0.01))
        for k in range(3):
            xx = s * (0.12 + 0.05 * k)
            vest.append(patch(f"{p}VestStripe{s}{k}", t, (xx, body.front(xx, 1.18) - 0.004, 1.18), (0.02, 0.02, 0.4), m["stripe"], bevel=0.003))
    vest += [sphere(f"{p}Button{i}", 0.022, (0.06, body.front(0.06, 1.28 - i * 0.12) - 0.012, 1.28 - i * 0.12), m=m["brass"], segs=6, rings=4)
             for i in range(3)]
    parts += bz.bind("Spine", vest)
    parts += hips(p, m["navy"], w=0.56, d=0.4, belt=m["dark"], buckle=m["brass"])
    for side in (1, -1):
        parts += arm(p, side, m, w=0.16, sleeve=m["shirt"], sleeve_len="long", cuff=m["stripe"], seed=63)
        parts += leg(p, side, m, w=0.18, pants=m["navy"], pants_len="shorts", hem=m["stripe"], foot="shoe", shoe=m["wood_dark"], sole=m["dark"],
                     tear=1)
    parts += bz.bind("Spine", [decal(f"{p}Soot{i}", t, (x, body.front(x, z), z), 0.05, m["soot"], squash=0.8)
                               for i, (x, z) in enumerate(((-0.12, 1.3), (0.15, 1.05), (-0.05, 0.98)))])
    return parts


def monkey_accessories(m):
    p = "MA_"
    w = 0.58
    cap = [cap_crown(p + "Cap", w, m["teal"], rim=1.76, top=1.99, off=0.04),
           head_band(p + "CapRoll", w, 1.8, 1.74, m["navy"], off=0.06, thick=0.03)]
    pack = keg(p + "Pack", (0.0, 0.33, 1.2), m, scale=1.7, lit=False)
    pack += [band(p + "StrapL", (0.0, 0.0, 1.42), (0.0, 0.0, 1.36), 0.3, 0.215, m["dark"], n=3.0, thick=0.015, segs=20)]
    held = keg(p + "Held", (-0.36, -0.14, 0.5), m, scale=1.6, lit=True)
    acc = {
        "Acc_Monkey_Cap": bz.bind("Head", cap),
        "Acc_Monkey_Pack": bz.bind("Spine", pack),
        "Acc_Monkey_Keg": bz.bind("ForeArm.R", held),
    }
    acc.update(faces("Monkey", m, w, ("Grin", "Gape"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Captain Barnacle (the alpha)
# ---------------------------------------------------------------------------

def barnacle(m):
    p = "B_"
    w = 0.68
    parts = head(p, m, w)
    tor, body = torso(p, m["shirt"], w=1.02, d=0.68, z0=0.84, z1=1.48, waist=0.9, belly=0.16, hunch=0.1, chest=1.04, n=2.8, hem=m["gold"])
    parts += tor
    parts += neck(p, m["skin"], 0.4, z1=1.48)
    t = tor[0]
    coat = []
    for i in range(4):
        z = 1.32 - i * 0.14
        for s in (-1, 1):
            x = s * 0.2
            coat.append(sphere(f"{p}Button{i}{s}", 0.04, (x, body.front(x, z) - 0.015, z), m=m["gold"], segs=8, rings=5))
    coat += [patch(p + "Waistcoat", t, (0, body.front(0, 1.15), 1.15), (0.26, 0.03, 0.5), m["stripe"], bevel=0.01),
             band(p + "Sash", (0, 0, 1.0), (0, 0, 0.92), 0.52, 0.36, m["red"], n=2.8, thick=0.02, segs=24)]
    for s in (-1, 1):
        coat += [box(f"{p}Epaulette{s}", (0.28, 0.26, 0.07), (s * 0.52, 0.0, 1.47), bevel=0.03, m=m["gold"])]
        coat += [cyl(f"{p}Fringe{s}{k}", 0.016, 0.11, (s * (0.42 + 0.05 * k), -0.12, 1.4), segs=4, bevel=0.0, m=m["gold"]) for k in range(5)]
    # Barnacle crust on the shoulders and the coat.
    spots = ((0.38, 1.3, 0.05), (0.3, 1.18, 0.04), (0.42, 1.12, 0.035), (-0.36, 1.06, 0.05), (-0.28, 0.98, 0.04), (0.18, 0.95, 0.035),
             (-0.42, 1.25, 0.04))
    for i, (x, z, r) in enumerate(spots):
        y = body.front(x, z) - 0.01
        coat.append(cyl(f"{p}Barnacle{i}", r, r * 1.1, (x, y, z), rot=rad(90, 0, 0), segs=8, bevel=0.0, m=m["barnacle"], radius_top=r * 0.55))
        coat.append(cyl(f"{p}BarnacleTip{i}", r * 0.45, r * 0.3, (x, y - r * 0.55, z), rot=rad(90, 0, 0), segs=6, bevel=0.0, m=m["barnacle_dark"]))
    parts += bz.bind("Spine", coat)
    parts += bz.bind("Hips", [blob(p + "Tails", (0, 0.05, 0.36), (0, 0.05, 0.86), [(0, 0.52, 0.37), (0.5, 0.5, 0.37), (1, 0.47, 0.36)], m["shirt"],
                                   n=2.6, r0=0.04, r1=0.03, segs=22, mid=4)])
    parts += hips(p, m["navy"], w=0.9, d=0.62, z0=0.7, belt=m["black"], buckle=m["gold"])
    # The beard: dark braids with gold rings.
    beard = []
    for i, (x, y, z, r) in enumerate(((0, -0.1, 1.42, 0.18), (-0.16, -0.06, 1.47, 0.13), (0.16, -0.06, 1.47, 0.13), (0, -0.16, 1.32, 0.13))):
        beard.append(sphere(f"{p}Beard{i}", r, (x, HEAD_Y + y - 0.22, z), m=m["beard"], segs=10, rings=7))
    for s in (-1, 1):
        bx = s * 0.09
        beard.append(tube(f"{p}Braid{s}", [(bx, HEAD_Y - 0.42, 1.3), (bx * 1.2, HEAD_Y - 0.45, 1.15), (bx * 1.1, HEAD_Y - 0.43, 1.02)], 0.045, m=m["beard"],
                          segs=8, radius_end=0.03))
        beard.append(torus(f"{p}BraidRing{s}", 0.05, 0.015, (bx * 1.15, HEAD_Y - 0.45, 1.12), m=m["gold"], major_segs=10, minor_segs=4))
    parts += bz.bind("Head", beard)
    for side in (1, -1):
        hand_m = m["skin"] if side < 0 else m["steel"]
        parts += arm(p, side, m, w=0.3, sleeve=m["shirt"], sleeve_len="long", cuff=m["gold"], hand=0.1 if side < 0 else -0.05, out=0.15, curl=0.8,
                     seed=67, glove=hand_m)
        parts += leg(p, side, m, w=0.3, pants=m["navy"], pants_len="long", foot="boot", shoe=m["black"], sole=m["dark"], tear=0)
    # The hook on the left wrist (over the small steel hand).
    parts += bz.bind("ForeArm.L", [cyl(p + "HookCuff", 0.09, 0.12, (0.6, -0.005, 0.6), segs=12, bevel=0.02, m=m["wood_dark"]),
                                   torus(p + "Hook", 0.1, 0.03, (0.6, -0.08, 0.42), rot=rad(90, 0, 90), m=m["steel"], major_segs=14, minor_segs=5,
                                         arc=math.pi * 1.3, start=-math.pi * 0.5)])
    return parts


def barnacle_accessories(m):
    p = "BA_"
    w = 0.68
    hat = [cap_crown(p + "Crown", w, m["black"], rim=1.78, top=2.1, off=0.05)]
    # Tricorn brim: three upturned flaps round the crown.
    for i in range(3):
        a = math.tau * i / 3 - math.pi / 2
        cx, cy = math.cos(a) * 0.4, HEAD_Y + math.sin(a) * 0.4
        hat.append(box(f"{p}Flap{i}", (0.62, 0.08, 0.26), (cx, cy, 1.98), rot=(math.radians(-20), 0, a + math.pi / 2), bevel=0.04, m=m["black"]))
        hat.append(box(f"{p}FlapTrim{i}", (0.64, 0.085, 0.04), (cx * 1.03, cy * 1.03, 2.1), rot=(math.radians(-20), 0, a + math.pi / 2), bevel=0.01,
                       m=m["gold"]))
    fy = face_y(w, 2.0) - 0.18
    hat += [sphere(p + "BadgeSkull", 0.08, (0, fy, 2.02), scale=(1, 0.4, 1), m=m["stripe"], segs=8, rings=5),
            box(p + "BadgeBones", (0.22, 0.03, 0.04), (0, fy - 0.01, 1.95), rot=(0, 0.5, 0), bevel=0.01, m=m["stripe"]),
            box(p + "BadgeBones2", (0.22, 0.03, 0.04), (0, fy - 0.01, 1.95), rot=(0, -0.5, 0), bevel=0.01, m=m["stripe"]),
            tube(p + "Plume", [(0.25, HEAD_Y + 0.2, 2.1), (0.42, HEAD_Y + 0.35, 2.4), (0.36, HEAD_Y + 0.55, 2.6)], 0.07, m=m["feather"], segs=8,
                 radius_end=0.02)]
    # The anchor, held in the right fist, hanging down and forward.
    hx, hy, hz = -0.62, -0.12, 0.5
    anchor = [cyl(p + "Shank", 0.06, 1.3, (hx, hy - 0.05, hz - 0.45), segs=10, bevel=0.0, m=m["iron"]),
              torus(p + "Ring", 0.12, 0.035, (hx, hy - 0.05, hz + 0.25), rot=rad(90, 0, 90), m=m["iron"], major_segs=12, minor_segs=4),
              cyl(p + "Stock", 0.05, 0.7, (hx, hy - 0.05, hz + 0.05), rot=rad(0, 90, 0), segs=8, bevel=0.0, m=m["wood_dark"]),
              torus(p + "Arms", 0.42, 0.06, (hx, hy - 0.05, hz - 0.95), rot=rad(90, 0, 90), m=m["iron"], major_segs=16, minor_segs=5, arc=math.pi,
                    start=math.pi)]
    for s in (-1, 1):
        anchor.append(prism(f"{p}Fluke{s}", [(-0.1, 0), (0.1, 0), (0, 0.2)], 0.05, (hx, hy - 0.05 + s * 0.42, hz - 0.88), rot=(0, 0, 0),
                            m=m["iron"]))
    anchor += [cyl(f"{p}Crust{i}", 0.04, 0.04, (hx + 0.05, hy - 0.05 + dy, hz - 0.6 + dz), rot=rad(0, 90, 0), segs=6, bevel=0.0, m=m["barnacle"],
                   radius_top=0.02) for i, (dy, dz) in enumerate(((0.0, 0.0), (0.03, 0.2), (-0.02, -0.25)))]
    acc = {
        "Acc_Barnacle_Tricorn": bz.bind("Head", hat),
        "Acc_Barnacle_Anchor": bz.bind("ForeArm.R", anchor),
    }
    acc.update(faces("Barnacle", m, w, ("Snarl", "Gape"), tongue=m["red"]))
    return acc


def cove_clips(rig):
    """cove_zombies.glb: Deckhand (Run, Tuck), Monkey (Walk, Throw),
    Captain (style "Heavy": stomp, slam, roar)."""
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
        bz.skin("Outfit_Deckhand", deckhand(m), armature),
        bz.skin("Outfit_Monkey", monkey(m), armature),
        bz.skin("Outfit_Barnacle", barnacle(m), armature),
    ]
    accessories = {}
    accessories.update(deckhand_accessories(m))
    accessories.update(monkey_accessories(m))
    accessories.update(barnacle_accessories(m))
    for name, parts in accessories.items():
        meshes.append(bz.skin(name, parts, armature))
    zombie_anim.bake(armature, cove_clips, "cove_zombies")
    bz.save_zombie("cove_zombies", [armature] + meshes)


if __name__ == "__main__":
    build()
