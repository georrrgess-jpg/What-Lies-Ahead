"""Sky Carnival zombies (World 10, Sky Harbor): the shared rig (build_zombie.py),
three outfits.

    Outfit_Diver     Sky Diver: a tintable jumpsuit ("Shirt") with a white chest
                     stripe, harness straps and a round skydiving helmet; a packed
                     parachute on the back (Acc_Diver_Pack), goggles (Acc_Diver_Goggles)
    Outfit_Vendor    Balloon Vendor: a tintable striped vendor jacket ("Shirt") with
                     a bow tie and a coin apron, navy trousers; a straw boater
                     (Acc_Vendor_Boater) and a big bunch of balloons tied to the left
                     shoulder strap (Acc_Vendor_Balloons)
    Outfit_Captain   Captain Cumulus (the alpha): a hulking airship captain in a long
                     double-breasted coat ("Shirt") with gold buttons and epaulettes, a
                     cloud-white beard; a peaked cap with goggles (Acc_Captain_Cap) and
                     a brass spyglass (Acc_Captain_Spyglass)

Faces: two presets per outfit (Face_<Outfit>_<Preset>).

Clips (sky_clips below, from zombie_anim): the shared set, the Diver's sprint,
Crouch (dive windup) and Hover (the canopy descent), the Vendor's shamble and
overhead Throw, and the Captain's stomp, slam and roar ("_Heavy").

    python art/blender/build_sky_zombies.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sky_common import *  # noqa: F401,F403
import build_zombie as bz  # noqa: E402
import zombie_anim  # noqa: E402
from zombie_anim import (attack, attack_heavy, crouch, flail_sprint, gait, hover, idle, roar, shamble, stagger, stomp,  # noqa: E402
                         throw, hit_head, deaths, emerge)
from zombie_kit import (HEAD_Y, SPARK_EYE, cap_crown, head_band, arm, band, base_materials, blob, face_y, faces, hair,  # noqa: E402
                        head, hips, leg, neck, patch, torso)


def materials():
    m = base_materials("sky", skin="#a6d46a", skin_dark="#6f9e44", dark="#1e2238", white="#fbf8f4", eye=(SPARK_EYE, 2.6))
    m.update(
        shirt=mat("Shirt", "#ff8a5c", rough=0.5),
        stripe=mat("SkyZStripe", "#fbf8f4", rough=0.6),
        navy=mat("SkyZNavy", "#2b3a67", rough=0.6),
        strap=mat("SkyZStrap", "#1e2238", rough=0.6),
        gold=mat("SkyZGold", "#ffcf5a", rough=0.35, metal=0.3),
        red=mat("SkyZRed", "#e8384f", rough=0.5),
        teal=mat("SkyZTeal", "#1fb5b0", rough=0.5),
        straw=mat("SkyZStraw", "#e7c27a", rough=0.8),
        lens=mat("SkyZLens", "#8fd0ff", rough=0.1, emit=0.4),
        canvas=mat("SkyZCanvas", "#f6ecdc", rough=0.8),
        beard=mat("SkyZBeard", "#fff6ee", rough=0.9),
        brass=mat("SkyZBrass", "#e3b04b", rough=0.3, metal=0.6),
        pink=mat("SkyZPink", "#ff8fb6", rough=0.35),
        sky=mat("SkyZSky", "#8fd0ff", rough=0.35),
        lilac=mat("SkyZLilac", "#b49ae8", rough=0.35),
    )
    return m


# ---------------------------------------------------------------------------
# Sky Diver
# ---------------------------------------------------------------------------

def diver(m):
    p = "D_"
    w = 0.56
    parts = head(p, m, w)
    parts += bz.bind("Head", [cap_crown(p + "Helmet", w, m["shirt"], rim=1.72, top=2.0, off=0.035),
                              head_band(p + "HelmetRim", w, 1.75, 1.7, m["stripe"], off=0.05, thick=0.02)])
    tor, body = torso(p, m["shirt"], w=0.6, d=0.4, z0=0.9, hunch=0.05, n=3.0)
    parts += tor
    parts += neck(p, m["skin"], 0.23)
    t = tor[0]
    parts += bz.bind("Spine", [
        band(p + "ChestStripe", (0, 0, 1.3), (0, 0, 1.2), 0.31, 0.21, m["stripe"], n=3.0, thick=0.015, segs=22),
        patch(p + "StrapL", t, (0.12, body.front(0.12, 1.15), 1.15), (0.06, 0.03, 0.5), m["strap"], bevel=0.01),
        patch(p + "StrapR", t, (-0.12, body.front(-0.12, 1.15), 1.15), (0.06, 0.03, 0.5), m["strap"], bevel=0.01),
        box(p + "Buckle", (0.12, 0.04, 0.08), (0, body.front(0, 1.0) - 0.03, 1.0), bevel=0.015, m=m["gold"]),
        box(p + "Altimeter", (0.1, 0.04, 0.12), (0.14, body.front(0.14, 1.32) - 0.03, 1.32), bevel=0.02, m=m["navy"]),
    ])
    parts += hips(p, m["shirt"], w=0.56, d=0.4, belt=m["strap"], buckle=m["gold"])
    for side in (1, -1):
        parts += arm(p, side, m, w=0.16, sleeve=m["shirt"], sleeve_len="long", cuff=m["stripe"], seed=51)
        parts += leg(p, side, m, w=0.18, pants=m["shirt"], pants_len="long", hem=m["stripe"], foot="boot", shoe=m["navy"], sole=m["dark"], tear=0)
    return parts


def diver_accessories(m):
    p = "DA_"
    w = 0.56
    pack = [box(p + "Pack", (0.5, 0.24, 0.56), (0, 0.32, 1.18), bevel=0.06, m=m["canvas"]),
            box(p + "PackFlap", (0.52, 0.26, 0.12), (0, 0.32, 1.44), bevel=0.04, m=m["red"]),
            box(p + "PackBand", (0.52, 0.26, 0.06), (0, 0.32, 1.08), bevel=0.02, m=m["teal"]),
            torus(p + "Ripcord", 0.04, 0.012, (0.2, -0.12, 1.06), rot=rad(90, 0, 0), m=m["red"], major_segs=10, minor_segs=4)]
    goggles = [head_band(p + "GoggleBand", w, 1.79, 1.75, m["strap"], off=0.045, thick=0.015)]
    gy = face_y(w, 1.8) - 0.05
    goggles += [cyl(f"{p}Lens{s}", 0.075, 0.06, (s * 0.12, gy, 1.8), rot=rad(80, 0, 0), segs=12, bevel=0.01, m=m["lens"]) for s in (-1, 1)]
    goggles += [torus(f"{p}LensRim{s}", 0.075, 0.015, (s * 0.12, gy - 0.02, 1.8), rot=rad(80, 0, 0), m=m["gold"], major_segs=12, minor_segs=4)
                for s in (-1, 1)]
    acc = {
        "Acc_Diver_Pack": bz.bind("Spine", pack),
        "Acc_Diver_Goggles": bz.bind("Head", goggles),
    }
    acc.update(faces("Diver", m, w, ("Grin", "Gape"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Balloon Vendor
# ---------------------------------------------------------------------------

def vendor(m):
    p = "V_"
    w = 0.6
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "fringe", 31)
    tor, body = torso(p, m["shirt"], w=0.74, d=0.5, z0=0.88, belly=0.1, hunch=0.04, n=2.8, hem=m["shirt"])
    parts += tor
    parts += neck(p, m["skin"], 0.25)
    t = tor[0]
    stripes = []
    for i in range(5):
        x = -0.24 + i * 0.12
        stripes.append(patch(f"{p}Stripe{i}", t, (x, body.front(x, 1.15), 1.15), (0.045, 0.02, 0.5), m["stripe"], bevel=0.005))
    parts += bz.bind("Spine", stripes + [
        box(p + "BowL", (0.1, 0.05, 0.08), (-0.06, body.front(0, 1.4) - 0.06, 1.42), rot=(0, 0, 0.3), bevel=0.02, m=m["red"]),
        box(p + "BowR", (0.1, 0.05, 0.08), (0.06, body.front(0, 1.4) - 0.06, 1.42), rot=(0, 0, -0.3), bevel=0.02, m=m["red"]),
        box(p + "Collar", (0.38, 0.08, 0.06), (0, body.front(0, 1.44) - 0.02, 1.45), bevel=0.02, m=m["stripe"]),
    ] + [sphere(f"{p}Button{i}", 0.025, (0, body.front(0, 1.3 - i * 0.12) - 0.01, 1.3 - i * 0.12), m=m["gold"], segs=6, rings=4) for i in range(3)])
    parts += hips(p, m["navy"], w=0.68, d=0.48, belt=m["dark"])
    parts += bz.bind("Hips", [box(p + "Apron", (0.5, 0.05, 0.36), (0, -0.25, 0.78), bevel=0.03, m=m["teal"]),
                              box(p + "Pocket", (0.3, 0.04, 0.14), (0, -0.28, 0.76), bevel=0.02, m=m["gold"])])
    for side in (1, -1):
        parts += arm(p, side, m, w=0.18, sleeve=m["shirt"], sleeve_len="long", cuff=m["stripe"], seed=53)
        parts += leg(p, side, m, w=0.2, pants=m["navy"], pants_len="long", foot="shoe", shoe=m["dark"], sole=m["white"], lace=m["white"], tear=0)
    return parts


def vendor_accessories(m):
    p = "VA_"
    w = 0.6
    boater = [cyl(p + "Brim", 0.4, 0.03, (0, HEAD_Y, 1.86), segs=24, bevel=0.01, m=m["straw"]),
              cyl(p + "Crown", 0.25, 0.18, (0, HEAD_Y, 1.96), segs=24, bevel=0.02, m=m["straw"]),
              cyl(p + "HatBand", 0.255, 0.06, (0, HEAD_Y, 1.92), segs=24, bevel=0.0, m=m["red"])]
    cols = [m["red"], m["gold"], m["teal"], m["pink"], m["sky"], m["lilac"]]
    # Tied to a ring on the left shoulder strap; the bunch floats up and back over that shoulder.
    base = (0.3, 0.12, 1.42)
    bunch = [torus(p + "Ring", 0.05, 0.015, base, rot=rad(90, 0, 0), m=m["gold"], major_segs=10, minor_segs=4)]
    tops = [(0.45, 0.3, 2.55), (0.25, 0.5, 2.7), (0.65, 0.5, 2.45), (0.2, 0.15, 2.4), (0.45, 0.35, 2.9), (0.75, 0.25, 2.75)]
    for i, top in enumerate(tops):
        bunch.append(tube(f"{p}String{i}", [base, top], 0.006, m=m["white"], segs=3))
        bunch.append(sphere(f"{p}B{i}", 0.2, (top[0], top[1], top[2] + 0.22), scale=(1, 1, 1.18), m=cols[i], segs=10, rings=7))
    acc = {
        "Acc_Vendor_Boater": bz.bind("Head", boater),
        "Acc_Vendor_Balloons": bz.bind("Spine", bunch),
    }
    acc.update(faces("Vendor", m, w, ("Grin", "Snarl"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Captain Cumulus (the alpha)
# ---------------------------------------------------------------------------

def captain(m):
    p = "C_"
    w = 0.66
    parts = head(p, m, w)
    tor, body = torso(p, m["shirt"], w=1.0, d=0.66, z0=0.84, z1=1.48, waist=0.9, belly=0.14, hunch=0.1, chest=1.04, n=2.8, hem=m["shirt"])
    parts += tor
    parts += neck(p, m["skin"], 0.4, z1=1.48)
    t = tor[0]
    coat = []
    for i in range(4):
        z = 1.32 - i * 0.14
        for s in (-1, 1):
            x = s * 0.17
            coat.append(sphere(f"{p}Button{i}{s}", 0.035, (x, body.front(x, z) - 0.015, z), m=m["gold"], segs=8, rings=5))
    coat += [patch(p + "Lapel", t, (0, body.front(0, 1.36), 1.36), (0.3, 0.03, 0.18), m["stripe"], bevel=0.01),
             band(p + "Sash", (0, 0, 1.0), (0, 0, 0.92), 0.5, 0.35, m["red"], n=2.8, thick=0.02, segs=24)]
    for s in (-1, 1):
        coat += [box(f"{p}Epaulette{s}", (0.26, 0.24, 0.07), (s * 0.5, 0.0, 1.47), bevel=0.03, m=m["gold"])]
        coat += [cyl(f"{p}Fringe{s}{k}", 0.015, 0.1, (s * (0.4 + 0.05 * k), -0.11, 1.4), segs=4, bevel=0.0, m=m["gold"]) for k in range(5)]
    parts += bz.bind("Spine", coat)
    # Coat tails over the hips.
    parts += bz.bind("Hips", [blob(p + "Tails", (0, 0.05, 0.4), (0, 0.05, 0.86), [(0, 0.5, 0.36), (0.5, 0.48, 0.36), (1, 0.46, 0.35)], m["shirt"],
                                   n=2.6, r0=0.04, r1=0.03, segs=22, mid=4)])
    parts += hips(p, m["navy"], w=0.9, d=0.62, z0=0.7, belt=m["dark"], buckle=m["gold"])
    # The beard: a cloud of white puffs.
    beard = []
    for i, (x, y, z, r) in enumerate(((0, -0.1, 1.42, 0.17), (-0.15, -0.06, 1.47, 0.13), (0.15, -0.06, 1.47, 0.13), (0, -0.16, 1.32, 0.13),
                                      (-0.1, -0.12, 1.36, 0.11), (0.1, -0.12, 1.36, 0.11), (-0.2, 0.0, 1.55, 0.09), (0.2, 0.0, 1.55, 0.09))):
        beard.append(sphere(f"{p}Beard{i}", r, (x, HEAD_Y + y - 0.2, z), m=m["beard"], segs=10, rings=7))
    parts += bz.bind("Head", beard)
    for side in (1, -1):
        parts += arm(p, side, m, w=0.3, sleeve=m["shirt"], sleeve_len="long", cuff=m["gold"], hand=0.1, out=0.14, curl=0.8, seed=57)
        parts += leg(p, side, m, w=0.3, pants=m["navy"], pants_len="long", foot="boot", shoe=m["dark"], sole=m["dark"], tear=0)
    return parts


def captain_accessories(m):
    p = "CA_"
    w = 0.66
    cap = [cap_crown(p + "Crown", w, m["navy"], rim=1.75, top=2.08, off=0.05),
           cyl(p + "Top", 0.4, 0.14, (0, HEAD_Y + 0.02, 2.1), segs=24, bevel=0.04, m=m["stripe"]),
           head_band(p + "Band", w, 1.82, 1.75, m["gold"], off=0.06, thick=0.02),
           box(p + "Peak", (0.44, 0.24, 0.04), (0, HEAD_Y - 0.36, 1.76), rot=(math.radians(-14), 0, 0), bevel=0.02, m=m["dark"]),
           star(p + "Badge", 0.09, 0.03, (0, face_y(w, 1.9) - 0.07, 1.92), rot=(math.pi / 2, 0, 0), m=m["gold"])]
    gy = HEAD_Y + 0.05
    cap += [cyl(f"{p}Goggle{s}", 0.08, 0.07, (s * 0.13, gy - 0.28, 2.0), rot=rad(60, 0, 0), segs=12, bevel=0.01, m=m["lens"]) for s in (-1, 1)]
    cap += [torus(f"{p}GoggleRim{s}", 0.08, 0.018, (s * 0.13, gy - 0.31, 1.99), rot=rad(60, 0, 0), m=m["brass"], major_segs=12, minor_segs=4)
            for s in (-1, 1)]
    spy = [cyl(p + "Spy", 0.06, 0.6, (-0.62, -0.25, 0.5), rot=rad(90, 0, 0), segs=12, bevel=0.01, m=m["brass"], radius_top=0.045),
           cyl(p + "SpyRing", 0.07, 0.06, (-0.62, -0.5, 0.5), rot=rad(90, 0, 0), segs=12, bevel=0.01, m=m["dark"])]
    acc = {
        "Acc_Captain_Cap": bz.bind("Head", cap),
        "Acc_Captain_Spyglass": bz.bind("ForeArm.R", spy),
    }
    acc.update(faces("Captain", m, w, ("Snarl", "Gape"), tongue=m["red"]))
    return acc


def sky_clips(rig):
    """sky_zombies.glb: Diver (Run, Crouch, Hover), Vendor (Walk, Throw),
    Captain (style "Heavy": stomp, slam, roar)."""
    return [idle(rig), gait(rig, "Walk", shamble()), gait(rig, "Run", flail_sprint()), crouch(rig), hover(rig),
            idle(rig, "Idle_Heavy", heavy=True), gait(rig, "Walk_Heavy", stomp()), attack(rig), attack_heavy(rig),
            throw(rig), roar(rig), stagger(rig), hit_head(rig), *deaths(rig), emerge(rig),
            stagger(rig, "Stagger_Heavy", heavy=True), emerge(rig, "Emerge_Heavy", heavy=True)]


def build():
    scene = reset_scene()
    scene.render.fps = bz.FPS
    m = materials()
    armature = bz.build_armature()
    meshes = [
        bz.skin("Outfit_Diver", diver(m), armature),
        bz.skin("Outfit_Vendor", vendor(m), armature),
        bz.skin("Outfit_Captain", captain(m), armature),
    ]
    accessories = {}
    accessories.update(diver_accessories(m))
    accessories.update(vendor_accessories(m))
    accessories.update(captain_accessories(m))
    for name, parts in accessories.items():
        meshes.append(bz.skin(name, parts, armature))
    zombie_anim.bake(armature, sky_clips, "sky_zombies")
    bz.save_zombie("sky_zombies", [armature] + meshes)


if __name__ == "__main__":
    build()
