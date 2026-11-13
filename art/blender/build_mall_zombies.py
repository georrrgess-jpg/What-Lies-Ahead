"""Megamall Midnight zombies: one rig (the same bones as build_zombie.py, which
this script reuses), three outfits.

    Outfit_Walker   Mall Walker: a tintable tracksuit ("Shirt") with white
                    stripes down the sleeves and legs, a sweatband, wristbands
                    and chunky white sneakers. Accessories: fanny pack,
                    step-counter watch (glowing face), sun visor.
    Outfit_Flinger  Food Court Flinger: a striped tintable polo ("Shirt"), a
                    white apron with a pocket, dark trousers and kitchen clogs.
                    Accessories: paper hat, HI! name badge, a stack of trays.
    Outfit_Manager  The Night Manager (alpha): a hulking manager in a tintable
                    blazer ("Shirt"), shirt and tie, slacks and shoes.
                    Accessories: NIGHT MGR badge, a giant key ring, a clipboard
                    and a comb-over.

Clips (mall_clips below): the shared set, plus
    Walk         the Mall Walker's brisk, arm-pumping power walk
    PowerWalk    the burst: a fast, upright race-walk (Walker and Manager)
    Windup       arms pumping on the spot before a burst (the telegraph)
    Lob          the Flinger's one-handed overhand soda lob (release at 15/28)
    *_Heavy      the Manager's stomp, slam, stagger and emerge

Eyes glow (emissive) so the zombies read in the moonlit court and in the
power cut. Materials named Skin / SkinDark / Shirt are tinted by the game.

    python art/blender/build_mall_zombies.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mall_common import *  # noqa: F401,F403
import build_zombie as bz  # noqa: E402
import zombie_anim as za  # noqa: E402
from zombie_kit import (HEAD_Y, cap_crown, head_band, arm, band, base_materials, faces, hair, head, hips, leg, neck,  # noqa: E402
                        patch, torso)


def materials():
    m = base_materials("mall", skin="#9cc9a0", skin_dark="#6a9a72", dark="#22202e", white="#f6f6ff", eye=("#ffeeb0", 2.8))
    m.update(
        shirt=mat("Shirt", "#e0218a", rough=0.5),
        navy=mat("MallZNavy", "#22285a", rough=0.5),
        stripe=mat("MallZStripe", "#f6f6ff", rough=0.5),
        sweat=mat("MallZSweatband", "#3ff0e0", rough=0.6),
        pack=mat("MallZFannyPack", "#ffd23f", rough=0.55),
        watch=mat("MallZWatchFace", "#8ff5c8", rough=0.2, emit=2.0),
        visor=mat("MallZVisor", "#ff7a2a", rough=0.45),
        apron=mat("MallZApron", "#fff6ea", rough=0.6),
        hat=mat("MallZPaperHat", "#ffffff", rough=0.7),
        hat_band=mat("MallZHatBand", "#e2343f", rough=0.6),
        badge=mat("MallZBadge", "#ffd23f", rough=0.4, metal=0.3),
        tray=mat("MallZTray", "#ff7a2a", rough=0.5),
        slacks=mat("MallZSlacks", "#2a2a3a", rough=0.6),
        shirt_white=mat("MallZDressShirt", "#eef0ff", rough=0.5),
        tie=mat("MallZTie", "#ffcf3f", rough=0.45),
        keys=mat("MallZKeys", "#d8dce8", rough=0.25, metal=0.8),
        clip=mat("MallZClipboard", "#a8673f", rough=0.6),
        paper=mat("MallZPaper", "#fff8e8", rough=0.7),
        red=mat("MallZRed", "#e2343f", rough=0.6),
    )
    return m


# ---------------------------------------------------------------------------
# Mall Walker
# ---------------------------------------------------------------------------

def walker(m):
    """Tracksuit ("Shirt") with stripes, sweatband, wristbands, big sneakers."""
    p = "W_"
    w = 0.58
    suit = m["shirt"]
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "fringe", 23)
    parts += bz.bind("Head", [head_band(p + "Sweatband", w, 1.83, 1.76, m["sweat"], off=0.03, thick=0.03)])
    tor, body = torso(p, suit, w=0.6, d=0.42, z0=0.88, hunch=0.03)
    parts += tor
    parts += neck(p, m["skin"], 0.24)
    parts += bz.bind("Spine", [
        patch(p + "Zip", tor[0], (0, body.front(0, 1.14), 1.14), (0.04, 0.04, 0.5), m["stripe"], bevel=0.01),
        band(p + "Collar", (0, 0.0, 1.47), (0, 0.0, 1.39), 0.22, 0.2, suit, n=2.6, thick=0.03, flare=0.02, segs=22),
        patch(p + "Chevron", tor[0], (0.15, body.front(0.15, 1.3), 1.3), (0.12, 0.04, 0.05), m["stripe"], bevel=0.01),
    ])
    parts += hips(p, m["navy"], w=0.56, d=0.42, belt=m["stripe"])
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.17, sleeve=suit, sleeve_len="long", cuff=m["sweat"], seed=41)
        parts += leg(p, side, m, w=0.19, pants=m["navy"], pants_len="long", foot="shoe", shoe=m["white"], sole=m["sweat"],
                     lace=m["dark"], tear=0)
        parts += bz.bind(f"UpperArm.{s}", [box(f"{p}SleeveStripe{s}", (0.03, 0.05, 0.36), (side * 0.47, 0, 1.1), bevel=0.0, m=m["stripe"])])
        parts += bz.bind(f"Thigh.{s}", [box(f"{p}LegStripe{s}", (0.03, 0.06, 0.32), (side * 0.27, 0, 0.62), bevel=0.0, m=m["stripe"])])
        parts += bz.bind(f"Shin.{s}", [box(f"{p}ShinStripe{s}", (0.03, 0.06, 0.3), (side * 0.255, 0, 0.3), bevel=0.0, m=m["stripe"])])
    return parts


def walker_accessories(m):
    p = "WA_"
    acc = {
        "Acc_Walker_Pack": bz.bind("Hips", [
            box(p + "Pack", (0.34, 0.14, 0.15), (0.0, -0.31, 0.86), bevel=0.06, segs=3, m=m["pack"]),
            box(p + "PackZip", (0.28, 0.02, 0.02), (0.0, -0.385, 0.9), bevel=0.0, m=m["dark"]),
            torus(p + "Strap", 0.31, 0.02, (0, 0, 0.87), m=m["dark"], major_segs=24, minor_segs=4),
        ]),
        "Acc_Walker_Watch": bz.bind("ForeArm.L", [
            box(p + "Watch", (0.1, 0.12, 0.09), (0.47, -0.02, 0.72), bevel=0.02, m=m["dark"]),
            box(p + "WatchFace", (0.02, 0.09, 0.07), (0.525, -0.02, 0.72), bevel=0.0, m=m["watch"]),
        ]),
        "Acc_Walker_Visor": bz.bind("Head", [
            head_band(p + "VisorBand", 0.58, 1.86, 1.79, m["visor"], off=0.045, thick=0.03),
            box(p + "VisorBrim", (0.42, 0.24, 0.03), (0, HEAD_Y - 0.36, 1.84), rot=rad(-12, 0, 0), bevel=0.02, m=m["visor"]),
        ]),
    }
    acc.update(faces("Walker", m, 0.58, ("Grin", "Snarl"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Food Court Flinger
# ---------------------------------------------------------------------------

def flinger(m):
    """Striped polo ("Shirt"), white apron with a pocket, trousers, clogs."""
    p = "F_"
    w = 0.6
    polo = m["shirt"]
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "fringe", 29)
    tor, body = torso(p, polo, w=0.68, d=0.48, z0=0.86, belly=0.08, hunch=0.05)
    parts += tor
    parts += neck(p, m["skin"], 0.25)
    stripes = [body.shell(f"{p}Stripe{i}", m["stripe"], z + 0.025, z - 0.025, off=0.008, segs=24, steps=1, lip=0.008)
               for i, z in enumerate((1.0, 1.14, 1.28))]
    parts += bz.bind("Spine", stripes + [
        band(p + "PoloCollar", (0, 0.0, 1.48), (0, 0.0, 1.41), 0.24, 0.22, m["stripe"], n=2.6, thick=0.03, flare=0.04, segs=22),
        patch(p + "Apron", tor[0], (0, body.front(0, 1.0), 1.0), (0.46, 0.05, 0.42), m["apron"], bevel=0.02),
        patch(p + "ApronPocket", tor[0], (0, body.front(0, 0.94) - 0.02, 0.94), (0.24, 0.04, 0.12), m["apron"], bevel=0.015),
        tube(p + "ApronTie", [(-0.3, -0.05, 1.1), (0.0, 0.26, 1.08), (0.3, -0.05, 1.1)], 0.015, m=m["apron"], segs=5),
    ])
    parts += hips(p, m["slacks"], w=0.62, d=0.46, belt=m["dark"])
    parts += bz.bind("Hips", [box(p + "ApronSkirt", (0.5, 0.05, 0.4), (0, -0.25, 0.78), bevel=0.02, m=m["apron"])])
    for side in (1, -1):
        parts += arm(p, side, m, w=0.18, sleeve=polo, sleeve_len="short", cuff=m["stripe"], seed=43)
        parts += leg(p, side, m, w=0.2, pants=m["slacks"], pants_len="long", foot="shoe", shoe=m["dark"], sole=m["white"],
                     lace=m["dark"], tear=0)
    return parts


def flinger_accessories(m):
    p = "FA_"
    acc = {
        "Acc_Flinger_Hat": bz.bind("Head", [
            cap_crown(p + "Hat", 0.6, m["hat"], rim=1.79, top=2.0, off=0.04),
            head_band(p + "HatBand", 0.6, 1.84, 1.79, m["hat_band"], off=0.05, thick=0.03),
            box(p + "HatFin", (0.06, 0.5, 0.2), (0, HEAD_Y + 0.0, 2.02), bevel=0.03, m=m["hat"]),
        ]),
        "Acc_Flinger_Badge": bz.bind("Spine", [
            box(p + "Badge", (0.16, 0.03, 0.1), (0.16, -0.33, 1.33), bevel=0.015, m=m["badge"]),
            text(p + "BadgeText", "HI!", 0.06, 0.01, (0.16, -0.35, 1.33), m=m["red"]),
        ]),
        "Acc_Flinger_Trays": bz.bind("ForeArm.L", [
            box(p + f"Tray{i}", (0.06, 0.42, 0.3), (0.5 + i * 0.03, -0.12, 0.72), rot=rad(0, 0, 0), bevel=0.02, m=m["tray"])
            for i in range(2)
        ]),
    }
    acc.update(faces("Flinger", m, 0.6, ("Gape", "Sleepy"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# The Night Manager (alpha)
# ---------------------------------------------------------------------------

def manager(m):
    """A big manager in a tintable blazer ("Shirt"), white shirt, tie, slacks."""
    p = "M_"
    w = 0.66
    blazer = m["shirt"]
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "fringe", 37)
    tor, body = torso(p, blazer, w=0.98, d=0.64, z0=0.86, z1=1.48, waist=0.9, belly=0.12, hunch=0.08, n=2.8)
    parts += tor
    parts += neck(p, m["shirt_white"], 0.38, z1=1.48)
    front = body.front(0, 1.25)
    parts += bz.bind("Spine", [
        patch(p + "ShirtFront", tor[0], (0, front, 1.3), (0.2, 0.05, 0.36), m["shirt_white"], bevel=0.01),
        box(p + "TieKnot", (0.08, 0.06, 0.07), (0, front - 0.04, 1.43), bevel=0.02, m=m["tie"]),
        box(p + "Tie", (0.09, 0.04, 0.34), (0, front - 0.05, 1.24), rot=rad(-6, 0, 0), bevel=0.02, m=m["tie"]),
        box(p + "LapelL", (0.08, 0.04, 0.34), (0.13, front - 0.02, 1.3), rot=rad(0, 0, -14), bevel=0.02, m=blazer),
        box(p + "LapelR", (0.08, 0.04, 0.34), (-0.13, front - 0.02, 1.3), rot=rad(0, 0, 14), bevel=0.02, m=blazer),
        box(p + "PocketSquare", (0.1, 0.03, 0.05), (-0.26, front + 0.04, 1.3), bevel=0.01, m=m["tie"]),
    ])
    parts += hips(p, m["slacks"], w=0.86, d=0.6, z0=0.72, belt=m["dark"], buckle=m["keys"])
    for side in (1, -1):
        parts += arm(p, side, m, w=0.27, sleeve=blazer, sleeve_len="long", cuff=m["shirt_white"], hand=0.06, out=0.1, seed=47)
        parts += leg(p, side, m, w=0.28, pants=m["slacks"], pants_len="long", foot="shoe", shoe=m["dark"], sole=m["dark"],
                     lace=m["dark"], tear=0)
    return parts


def manager_accessories(m):
    p = "MA_"
    acc = {
        "Acc_Manager_Badge": bz.bind("Spine", [
            box(p + "Badge", (0.26, 0.03, 0.12), (0.26, -0.43, 1.32), bevel=0.02, m=m["badge"]),
            text(p + "BadgeText", "NIGHT MGR", 0.04, 0.01, (0.26, -0.45, 1.32), m=m["navy"]),
        ]),
        "Acc_Manager_Keys": bz.bind("Hips", [
            torus(p + "Ring", 0.12, 0.018, (0.42, -0.1, 0.78), rot=rad(90, 0, 20), m=m["keys"], major_segs=18, minor_segs=5),
        ] + [box(p + f"Key{i}", (0.03, 0.02, 0.16), (0.42 + math.cos(i * 1.1) * 0.1, -0.13, 0.66 + math.sin(i * 1.1) * 0.03),
                 rot=(0, math.radians(-25 + i * 14), 0), bevel=0.005, m=m["keys"]) for i in range(5)]),
        "Acc_Manager_Clipboard": bz.bind("ForeArm.L", [
            box(p + "Board", (0.05, 0.3, 0.4), (0.62, -0.14, 0.74), bevel=0.02, m=m["clip"]),
            box(p + "Sheet", (0.02, 0.26, 0.32), (0.655, -0.14, 0.72), bevel=0.0, m=m["paper"]),
            box(p + "Clip", (0.04, 0.1, 0.05), (0.66, -0.14, 0.94), bevel=0.01, m=m["keys"]),
        ]),
        "Acc_Manager_Combover": bz.bind("Head", [
            cap_crown(p + "Comb", 0.66, m["dark"], rim=1.86, top=2.02, off=0.02),
        ]),
    }
    acc.update(faces("Manager", m, 0.66, ("Snarl",), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Clips
# ---------------------------------------------------------------------------

def power_walk_gait(period, stride, lean=6.0, swing=46.0):
    """Upright race-walking: hips swivel, elbows bent at 90 and pumping hard."""
    d = 0.6
    return za.Gait(period, d, stride, 0.07, za.walker(d, lean=lean, hips_pitch=3, yaw=13, roll=8, sway=0.05, twist=1.2,
                                                      head=-6, loll=2, arms_fn=za.arms_pump(swing, -95, -8), shoulder_roll=3),
                   front=0.5, bob=0.02)


def windup(rig, name="Windup"):
    """Pumping the arms on the spot, bouncing on the toes, before a burst."""
    keys = []
    for i in range(9):
        c, s = za._cs(i / 8)
        keys.append((i * 2, {"Hips": (4, 0, 6 * c), "Spine": (4, 0, -8 * c), "Head": (-6, 0, 0), "hips": (0, 0, 0.03 * abs(s)),
                             **za.feet(0.17, 0.08, -0.08), **za.arms(-8 + 55 * c, -95, -8 - 55 * c, -95, spread=14)}, "io"))
    return za.keyed(rig, name, keys, loop=True)


def lob(rig, name="Lob"):
    """One-handed overhand lob with the right arm: rear back (0-12), release at
    ~15, follow through; the left arm points at the target."""
    def pose(spine, head, ru, rf, lu, lf, hips=4, yaw=0.0, fwd=0.0):
        return {"Hips": (hips, 0, yaw), "Spine": (spine, 0, yaw), "Head": (head, 0, -yaw), "hips": (0, fwd, -0.04),
                **za.feet(0.22, 0.16, -0.14), **za.arms(lu, lf, ru, rf, spread=12)}
    return za.keyed(rig, name, [
        (0, pose(10, -8, -30, -40, -40, -20)),
        (7, pose(-10, -16, -170, -95, -80, -10, hips=-2, yaw=-18, fwd=-0.06), "out"),
        (12, pose(-14, -18, -178, -110, -88, -6, hips=-3, yaw=-22, fwd=-0.08)),
        (15, pose(30, 4, -60, -10, -40, -30, hips=10, yaw=16, fwd=0.1), "snap"),
        (20, pose(24, 0, -30, -30, -30, -30, hips=8, yaw=8, fwd=0.08), "out"),
        (28, pose(10, -8, -30, -40, -40, -20))])


def mall_clips(rig):
    """mall_zombies.glb: Walker (power walk), Flinger (shamble walk, lob),
    Manager (style "Heavy": stomp, slam), PowerWalk and Windup for bursts."""
    return [za.idle(rig), za.gait(rig, "Walk", power_walk_gait(0.62, 0.95)), za.gait(rig, "Run", za.flail_sprint()),
            za.gait(rig, "Walk_Flinger", za.march()), za.gait(rig, "PowerWalk", power_walk_gait(0.42, 1.25, lean=10, swing=58)),
            windup(rig), lob(rig), za.attack(rig), za.attack_heavy(rig), za.roar(rig),
            za.idle(rig, "Idle_Heavy", heavy=True), za.gait(rig, "Walk_Heavy", za.stomp()), *za._common(rig, heavy=True)]


def build():
    scene = reset_scene()
    scene.render.fps = bz.FPS
    m = materials()
    armature = bz.build_armature()
    meshes = [
        bz.skin("Outfit_Walker", walker(m), armature),
        bz.skin("Outfit_Flinger", flinger(m), armature),
        bz.skin("Outfit_Manager", manager(m), armature),
    ]
    accessories = {}
    accessories.update(walker_accessories(m))
    accessories.update(flinger_accessories(m))
    accessories.update(manager_accessories(m))
    for name, parts in accessories.items():
        meshes.append(bz.skin(name, parts, armature))
    za.bake(armature, mall_clips, "mall_zombies")
    bz.save_zombie("mall_zombies", [armature] + meshes)


if __name__ == "__main__":
    build()
