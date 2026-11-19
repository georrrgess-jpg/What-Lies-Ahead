"""First-person model of the Swirl Smasher (swirl_smasher), the melee-slot
club: a giant rainbow swirl lollipop on a barber-striped paper stick, with
a cellophane bow tied under the candy and a gumball pommel.

Melee contract (melee_kit.py): origin at the centre of the fist on the
stick, the stick along +Y with the candy at its far end. The candy disc
lies in the XY plane (its faces towards +Z / -Z), so a swing in the
weapon's YZ plane hits with a face and a swing in its XY plane cuts with the
rim. The swirl's arms take "Shell" and "Trim" between fixed candy colours,
so a weapon finish recolours two of the six stripes and the stick ribbon.

  Stick   the stick, grip tape, pommel (static, pivot at the origin)
  Candy   child of Stick, pivot at the disc's centre: wobbles and spins
  Bow     child of Stick, pivot at the knot: flutters
  ArmR    the fist round the stick (ElbowR)

Empties: Muzzle and BladeTip (far rim of the candy), SwingPoint (the candy's
near half, where the swing trail starts),
CharmPoint (a lug by the pommel, left side).

    python art/blender/build_weapons_swirl_smasher.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from melee_kit import *  # noqa: F401,F403
from weapon_kit import _finish_part  # noqa: E402

STICK_R = 0.02
STICK_Y0 = -0.085
STICK_Y1 = 0.5
CANDY_R = 0.2
CANDY_H = 0.04
CANDY_Y = STICK_Y1 + CANDY_R - 0.03
BOW_Y = 0.445
## The swirl: how many turns an arm makes from the centre to the rim.
TURNS = 1.35


def palette():
    """The shared weapon materials in this weapon's colours (weapon_mats reuses them)."""
    mat("Shell", "#ff3b6b", rough=0.18)
    mat("Trim", "#3b8cff", rough=0.18)
    mat("GunDark", "#2a2238", rough=0.55, metal=0.1)
    mat("GunSteel", "#f7c04a", rough=0.3, metal=0.5)
    mat("GunPink", "#ff6fb5", rough=0.35)


def half_height(r):
    """Half thickness of the candy at radius r: a gently domed disc with a round rim."""
    e = CANDY_H * 0.95
    core = CANDY_H * (1.0 - 0.18 * (r / CANDY_R) ** 2)
    if r <= CANDY_R - e:
        return core
    top = CANDY_H * (1.0 - 0.18 * ((CANDY_R - e) / CANDY_R) ** 2)
    u = min(1.0, (r - (CANDY_R - e)) / e)
    return top * math.sqrt(max(0.0, 1.0 - u * u))


def swirl_arm(name, a0, a1, m, rings=30, cols=5):
    """One arm of the swirl: the band between angles a0..a1 (radians at the
    centre), wound TURNS times out to the rim, top and bottom faces."""
    bm = bmesh.new()
    radii = [CANDY_R * (0.03 + 0.97 * (1.0 - (1.0 - i / rings) ** 1.6)) for i in range(rings + 1)]
    top, bot = [], []
    for r in radii:
        twist = math.tau * TURNS * (r / CANDY_R) ** 0.85
        h = half_height(r)
        row_t, row_b = [], []
        for j in range(cols + 1):
            a = a0 + (a1 - a0) * j / cols + twist
            x, y = math.cos(a) * r, math.sin(a) * r
            row_t.append(bm.verts.new((x, y, h)))
            row_b.append(bm.verts.new((x, y, -h)))
        top.append(row_t)
        bot.append(row_b)
    for i in range(rings):
        for j in range(cols):
            bm.faces.new((top[i][j], top[i][j + 1], top[i + 1][j + 1], top[i + 1][j]))
            bm.faces.new((bot[i][j], bot[i + 1][j], bot[i + 1][j + 1], bot[i][j + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish_part(name, bm, m)
    ob.location = (0, CANDY_Y, 0)
    return ob


def build_swirl_smasher():
    reset_scene()
    palette()
    M = weapon_mats("#ffe14a", emit=2.0)
    cream = mat("Cream", "#fff6ea", rough=0.25)
    colours = [M["shell"], mat("CandyOrange", "#ff9a2e", rough=0.18), mat("CandyYellow", "#ffe04a", rough=0.18),
               mat("CandyLime", "#72e04a", rough=0.18), M["trim"], mat("CandyGrape", "#a35cff", rough=0.18)]
    paper = mat("StickPaper", "#fff8ee", rough=0.6)
    cello = mat("Cellophane", "#ffd2ee", rough=0.06, metal=0.3, emit=0.3, emit_color="#ff7ac8")

    # Candy: six coloured arms with thin cream arms between them, and a cream bead in the middle.
    candy = []
    n = len(colours)
    share = math.tau / n
    for i, m in enumerate(colours):
        a = share * i
        candy.append(swirl_arm(f"Arm{i}", a, a + share * 0.8, m))
        candy.append(swirl_arm(f"Cream{i}", a + share * 0.8, a + share, cream, cols=2))
    candy.append(sphere("Bead", 0.016, (0, CANDY_Y, 0), scale=(1, 1, CANDY_H / 0.016 * 1.02), m=cream, segs=16, rings=8))
    # A few sugar-crystal glints on each face.
    for i in range(7):
        a = 1.3 + i * 2.2
        r = CANDY_R * (0.3 + 0.08 * (i % 5))
        for side in (-1, 1):
            p = (math.cos(a * side) * r, CANDY_Y + math.sin(a * side) * r, side * (half_height(r) + 0.0008))
            candy.append(sphere(f"Glint{i}{side}", 0.0035, p, scale=(1, 1, 0.35), m=M["cell"], segs=8, rings=4))

    # Stick: paper with a barber ribbon, grip tape under the fist, a gumball pommel.
    stick = [
        ycyl("Paper", STICK_R, STICK_Y1 - STICK_Y0 + 0.02, (STICK_Y0 + STICK_Y1) / 2 + 0.01, m=paper, segs=20, bevel=0.003),
        spiral_band("Ribbon", STICK_R - 0.0008, 0.0052, 0.075, STICK_Y1 - 0.01, 5.5, M["trim"]),
        ycyl("Tape", STICK_R + 0.0028, 0.15, -0.0075, m=M["dark"], segs=20, bevel=0.002),
        ring("TapeEnd0", STICK_R + 0.003, 0.0035, 0.066, m=M["shell"], segs=20),
        ring("TapeEnd1", STICK_R + 0.003, 0.0035, -0.081, m=M["shell"], segs=20),
        sphere("Gumball", 0.034, (0, STICK_Y0 - 0.022, 0), m=M["shell"], segs=20, rings=12),
        ring("GumballCollar", STICK_R + 0.004, 0.005, STICK_Y0 - 0.002, m=M["steel"], segs=20),
        ring("GumballGlow", 0.0345, 0.0025, STICK_Y0 - 0.022, m=M["cell"], segs=24),
    ]
    for i in range(6):
        a = i * 1.1
        stick.append(sphere(f"Speck{i}", 0.006, (math.cos(a) * 0.031, STICK_Y0 - 0.022 + math.sin(a * 1.7) * 0.016, math.sin(a) * 0.031),
                            m=colours[(i + 1) % n], segs=8, rings=5))
    for k in range(10):
        y = -0.068 + k * 0.0145
        stick.append(ring(f"TapeRib{k}", STICK_R + 0.0032, 0.0011, y, m=M["steel"] if k % 3 == 0 else M["dark"], segs=18))

    # Bow: a pink tie round the stick, a knot, two cellophane loops and two notched tails.
    by = BOW_Y
    bow = [
        ring("Tie", STICK_R + 0.0015, 0.0045, by, m=M["pink"], segs=20),
        sphere("Knot", 0.017, (0, by, 0), scale=(1.15, 0.8, 1.0), m=cello, segs=14, rings=8),
    ]
    for side in (-1, 1):
        loop = torus(f"Loop{side}", 0.044, 0.0085, (side * 0.05, by + 0.006, 0), rot=rad(0, side * 18, side * 12), m=cello,
                     major_segs=28, minor_segs=8)
        loop.scale = (1.0, 0.62, 1.9)
        bow.append(loop)
        bow.append(sphere(f"LoopPinch{side}", 0.011, (side * 0.012, by, 0), scale=(1.2, 0.8, 1.4), m=cello, segs=12, rings=6))
        tail_dir = Vector((side * 0.45, -1.0, -0.25)).normalized()
        centre = Vector((side * 0.012, by, 0)) + tail_dir * 0.05
        bow.append(obox(f"Tail{side}", (0.085, 0.03, 0.0035), centre, tail_dir, (0, 0, 1), bevel=0.0012, m=cello))
        bow.append(obox(f"TailEdge{side}", (0.087, 0.0042, 0.004), centre + Vector((0, 0, 0.015)), tail_dir, (0, 0, 1), bevel=0.001, m=M["pink"]))

    lug, charm_point = melee_lug(-STICK_R - 0.002, STICK_Y0 + 0.004, 0.0, M)
    stick += lug

    bar = (STICK_R + 0.003, STICK_R + 0.003, STICK_R + 0.0025)
    arm_r, elbow_r = fist("R", (0, 0, 0), (0, 1, 0), (1, 0, 0), bar, M, (0.26, -0.6, -0.5), -0.056, 0.058,
                          palm_s=(3.6, 0.075), finger_len=0.09, thumb="wrap", wrist=(0.2, 0.035, 0.046))
    groups = {
        "Stick": (stick, (0, 0, 0), None),
        "Candy": (candy, (0, CANDY_Y, 0), "Stick"),
        "Bow": (bow, (0, by, 0), "Stick"),
        "ArmR": (arm_r, (0, 0, 0), None),
    }
    empties = {
        "Muzzle": ((0, CANDY_Y + CANDY_R, 0), "Candy"),
        "BladeTip": ((0, CANDY_Y + CANDY_R, 0), "Candy"),
        "SwingPoint": ((0, CANDY_Y - CANDY_R * 0.4, 0), "Candy"),
        "CharmPoint": (charm_point, "Stick"),
        "ElbowR": (elbow_r, "ArmR"),
    }
    finish("swirl_smasher", groups, empties)


if __name__ == "__main__":
    build_swirl_smasher()
