"""First-person viewmodel of the Yo-Yo Loco (update 13 secondary): a stubby
grape-purple wrist launcher whose rear guard arches back over the wrist, a
lime yo-yo riding in a fork on its nose and a glowing string spool on its
left flank (the side the player sees). Also writes the thrown yo-yo on its own
(art/models/yoyo_loco_yoyo.glb, used by scripts/weapons/yoyo_loco_shot.gd).

Same conventions and node contract as build_weapons.py (documented at the top
of weapon_kit.py): origin at the top of the grip, pointing along +Y, its own
palette (set before weapon_mats, so the shared material names stay and every
finish, cell, decal and charm works), built-in sights. Moving parts, driven by
scripts/weapons/views/yoyo_loco_view.gd and
scripts/weapons/reloads/yoyo_loco_reload.gd:

  Yoyo        the loaded yo-yo in the fork (pivot at its axle, axle along X)
  Spool       the string reel on the left flank (pivot at its axle, along X) >
              Cell      the glowing string wound on it (the magazine)
              CellHolo  the hologram string the reload rewinds
  Tether      the string from the port in the nose to the yo-yo (pivot at the
              port, TETHER long along +Y; the reload stretches it to the yo-yo)

    python art/blender/build_weapons_yoyo_loco.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403
from weapon_kit import _save  # noqa: E402

YOYO_C = (0.0, 0.2, 0.046)       # the loaded yo-yo's axle centre
YOYO_R = 0.048
PORT = (0.0, 0.137, 0.046)         # where the string leaves the nose
TETHER = YOYO_C[1] - PORT[1]
SPOOL_C = (-0.05, 0.03, 0.026)


def palette():
    """Grape purple shell, Loco Lime trim, midnight dark (weapon_mats reuses them)."""
    mat("Shell", "#6b3cf0", rough=0.34)
    mat("Trim", "#b8ff3a", rough=0.36)
    mat("GunDark", "#22193a", rough=0.5, metal=0.2)
    mat("GunSteel", "#c8c2dc", rough=0.28, metal=0.65)
    mat("GunPink", "#ff4fae", rough=0.38)


def yoyo(prefix, radius, lime, rim, core, glow, sticker, centre=(0, 0, 0)):
    """A chunky toy yo-yo round its axle (along X): two lime halves with a
    purple rim and a pink star sticker on each face, a glowing string groove."""
    half = radius * 0.42
    gap = radius * 0.16
    parts = [xcyl(prefix + "Groove", radius * 0.42, gap + 0.002, centre, m=glow, segs=20, bevel=0.0)]
    for side in (-1, 1):
        x = centre[0] + side * (gap / 2 + half / 2)
        parts += [
            xcyl(f"{prefix}Half{side}", radius, half, (x, centre[1], centre[2]), m=lime, segs=28, bevel=radius * 0.18),
            torus(f"{prefix}Rim{side}", radius * 0.93, radius * 0.11, (x + side * half * 0.1, centre[1], centre[2]), rot=rad(0, 90, 0),
                  m=rim, major_segs=28, minor_segs=6),
            xcyl(f"{prefix}Cap{side}", radius * 0.5, half * 0.3, (x + side * half * 0.5, centre[1], centre[2]), m=core, segs=20, bevel=radius * 0.05),
            star(f"{prefix}Star{side}", radius * 0.34, half * 0.16, (x + side * half * 0.66, centre[1], centre[2]),
                 rot=rad(0, 0, 90), m=sticker, inner=radius * 0.15),
        ]
    return parts


def wrist_mount(arm, elbow, M):
    """The launcher's strap-on cuff round the firing forearm, just behind the
    glove's cuff: a purple band with a lime light and a string guide on top."""
    heel = next(p for p in arm if p.name == "RHeel")
    c = heel.location.copy()
    d = (Vector(elbow) - c).normalized()
    up = (Vector((0, 0, 1)) - d * d.z).normalized()
    return [
        tube("MountBand", [c + d * 0.235, c + d * 0.292], 0.072, m=M["shell"], segs=18),
        tube("MountLight", [c + d * 0.256, c + d * 0.27], 0.0745, m=M["cell"], segs=18),
        sphere("MountGuide", 0.011, c + d * 0.263 + up * 0.074, m=M["trim"], segs=10, rings=6),
    ]


def build_yoyo_loco():
    reset_scene()
    palette()
    M = weapon_mats("#c8ff3a", emit=2.0)
    lime = mat("YoyoLime", "#b8ff3a", rough=0.3)
    star_m = mat("YoyoStar", "#ff4fae", rough=0.35)
    grip_loc = (0, -0.024, -0.104)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.07, 0.092, 0.185), body_bottom=-0.03)
    rail_top = 0.098
    z_line = rail_top + SIGHT_HEIGHT
    yx, yy, yz = YOYO_C
    sx, sy, sz = SPOOL_C

    shell = grip_parts + [
        side_profile("Body", [(-0.07, -0.03), (0.118, -0.03), (0.136, -0.006), (0.136, 0.058), (0.116, 0.08), (-0.04, 0.08), (-0.07, 0.062)],
                     0.064, (0, 0, 0), M["shell"], bevel=0.012),
        box("Frame", (0.068, 0.17, 0.026), (0, 0.03, -0.022), bevel=0.01, m=M["dark"]),
        box("BodyStripe", (0.066, 0.15, 0.012), (0, 0.04, 0.034), bevel=0.003, m=M["trim"]),
        box("RailRiser", (0.03, 0.12, 0.018), (0, 0.01, rail_top - 0.015), bevel=0.004, m=M["dark"]),
        # The nose: a dark collar round the string port, and the fork that holds the yo-yo.
        ycyl("Nose", 0.024, 0.016, 0.136, z=yz, m=M["dark"], segs=20, bevel=0.004),
        ycyl("PortRing", 0.011, 0.006, 0.145, z=yz, m=M["steel"], segs=16, bevel=0.002),
    ]
    for side in (-1, 1):
        px = side * (YOYO_R * 0.42 * 2 + YOYO_R * 0.16 / 2 + 0.012)
        shell += [
            box(f"Prong{side}", (0.01, 0.085, 0.024), (px, 0.166, yz), bevel=0.004, m=M["shell"]),
            box(f"ProngTip{side}", (0.012, 0.026, 0.034), (px, 0.204, yz), bevel=0.005, m=M["trim"]),
            xcyl(f"AxleCup{side}", 0.009, 0.008, (px - side * 0.009, yy, yz), m=M["steel"], segs=14, bevel=0.002),
        ]
    # The spool's housing on the left flank (the side the player sees).
    shell += [
        xcyl("SpoolBack", 0.033, 0.006, (-0.034, sy, sz), m=M["dark"], segs=28, bevel=0.002),
        torus("SpoolGuard", 0.034, 0.0035, (sx - 0.004, sy, sz), rot=rad(0, 90, 0), m=M["steel"], major_segs=28, minor_segs=5),
    ]
    shell += top_rail("TopRail", -0.045, 0.065, rail_top, M, width=0.03)
    shell += bolts("Pin", [(-0.033, 0.09, 0.0), (0.033, 0.09, -0.006), (-0.033, -0.05, 0.04)], M["steel"], radius=0.005, height=0.006)
    lug, charm_point = charm_lug(0.032, -0.03, -0.004, M, out=1.0)
    shell += lug
    sight_rear, sight_front = sights_notch(0.0, -0.052, 0.112, rail_top, 0.08, z_line, M, gap=0.016)

    loaded = yoyo("Yoyo", YOYO_R, lime, M["shell"], M["dark"], M["cell"], star_m, YOYO_C)
    # The string reel: a steel drum with lime spokes; the wound string (Cell) and its hologram.
    spool = [xcyl("SpoolDrum", 0.012, 0.016, SPOOL_C, m=M["steel"], segs=18, bevel=0.002),
             xcyl("SpoolFace", 0.031, 0.004, (sx - 0.009, sy, sz), m=M["trim"], segs=28, bevel=0.0015),
             xcyl("SpoolKnob", 0.007, 0.012, (sx - 0.016, sy, sz), m=M["pink"], segs=12, bevel=0.002)]
    for i in range(3):
        a = math.tau * i / 3
        spool.append(obox(f"SpoolSpoke{i}", (0.004, 0.044, 0.006), (sx - 0.012, sy + math.cos(a) * 0.013, sz + math.sin(a) * 0.013),
                          (0, math.cos(a), math.sin(a)), (1, 0, 0), bevel=0.001, m=M["dark"]))
    wound = [xcyl("StringCoil", 0.024, 0.013, (sx + 0.001, sy, sz), m=M["cell"], segs=24, bevel=0.003)]
    wound_holo = holo_copy([xcyl("StringCoilShape", 0.027, 0.015, (sx + 0.001, sy, sz), segs=24, bevel=0.003)])
    tether = [ycyl("TetherLine", 0.0022, TETHER, PORT[1] + TETHER / 2, z=PORT[2], m=M["cell"], segs=6, bevel=0.0)]
    # The string runs back from the port along the left side into the spool.
    shell.append(tube("StringRun", [(-0.006, 0.134, yz), (-0.026, 0.11, yz + 0.002), (sx + 0.006, sy + 0.022, sz + 0.012)], 0.0018, m=M["cell"], segs=6))

    decal = [side_emblem("Emblem", star_outline(0.014, 0.006), -0.0325, -0.042, 0.052, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.42, -0.5, -0.36))
    arm_r += wrist_mount(arm_r, elbow_r, M)
    arm_l, elbow_l = cup_hand(G, M, (-0.55, -0.32, -0.32))
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.052, rail_top), None),
        "IronSightFront": (sight_front, (0, 0.112, 0.08), None),
        "Yoyo": (loaded, YOYO_C, None),
        "Spool": (spool, SPOOL_C, None),
        "Cell": (wound, SPOOL_C, "Spool"),
        "CellHolo": (wound_holo, SPOOL_C, "Spool"),
        "Tether": (tether, PORT, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, grip_loc, None),
    }
    empties = {
        "Muzzle": ((0, yy + 0.05, yz), None),
        "SightPoint": ((0, -0.052, z_line), None),
        "SightMount": ((0, 0.01, rail_top), None),
        "EjectPoint": ((sx - 0.012, sy, sz + 0.03), None),
        "VentPoint": ((0, 0.145, yz), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("yoyo_loco", groups, empties)


def build_thrown_yoyo():
    """The yo-yo in flight: radius 0.11 m (YoyoLocoShot.RADIUS), axle along X."""
    reset_scene()
    lime = mat("YoyoLime", "#b8ff3a", rough=0.3, emit=0.35)
    rim = mat("YoyoRim", "#6b3cf0", rough=0.34)
    core = mat("YoyoCore", "#22193a", rough=0.5)
    glow = mat("YoyoGlow", "#c8ff3a", rough=0.3, emit=2.6)
    sticker = mat("YoyoStar", "#ff4fae", rough=0.35, emit=0.6)
    parts = yoyo("Thrown", 0.11, lime, rim, core, glow, sticker)
    _save("yoyo_loco_yoyo", [merge("Yoyo", parts)])


BUILDERS = (
    ("yoyo_loco", build_yoyo_loco),
    ("yoyo_loco_yoyo", build_thrown_yoyo),
)

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for name, fn in BUILDERS:
        if not only or name in only:
            fn()
