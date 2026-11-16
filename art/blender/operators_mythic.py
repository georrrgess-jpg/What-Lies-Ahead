"""The Mythic operator (update 13), built from the same kit as the others (see
build_operators.py, which registers it in OPERATORS):

    fortuna     Madame Fortuna, the fortune teller from the booth at the end of
                the pier: a purple turban with an all-seeing-eye jewel and a
                plume, a crimson velvet coat trimmed with chasing marquee bulbs,
                a stand-up collar, a starry night cape and gold bangles.

Materials beyond the contract in build_operators.py (scripts/cosmetics/operators.gd):
    FxBulb*    marquee bulbs that chase around the coat (operator_bulbs shader)
    FxStar*    a night sky with drifting nebula and twinkling stars (operator_starfield)

The builder returns (kit, pose, idle style) like the others; its pose is a
function (operator_anim.pose_keys calls it with the idle's first frame).
"""
import math

from operator_kit import *  # noqa: F401,F403
from operator_kit import HEAD_C, Kit
from operator_anim import arm, body, _merge

BULKY_HOLD = (0.06, -0.035, -0.015)


def _hat_frame(z=0.15, tilt=-6.0):
    return Matrix.Translation(HEAD_C) @ Euler((math.radians(tilt), 0.0, 0.0), "XYZ").to_matrix().to_4x4() @ Matrix.Translation((0.0, 0.0, z))


def _turban(k, purple, purple_dark, gold, bulb, white, iris, cream, pink):
    """A puffed, wrapped turban with a band of bulbs, the eye jewel and a plume."""
    f = _hat_frame(0.105, -7.0)
    secs = [(0.0, 0.252, 0.238, 0, 0, 2.2), (0.05, 0.29, 0.272, 0, 0, 2.2), (0.12, 0.292, 0.274, 0, 0.004, 2.15),
            (0.2, 0.25, 0.236, 0, 0.012, 2.1), (0.25, 0.17, 0.162, 0, 0.018, 2.0)]
    parts = [loft(k.n("Turban"), secs, purple, segs=32, sub=3, frame=f, caps=("flat", "round"), cap_h=(None, 0.06))]
    # Wraps: tilted folds crossing at the front.
    for i, (z, tilt, roll) in enumerate(((0.07, 13.0, 8.0), (0.13, -11.0, -8.0), (0.185, 9.0, 6.0))):
        rx = 0.29 if z < 0.15 else 0.262
        fold = f @ Matrix.Translation((0, 0.006, z)) @ Euler((math.radians(tilt), math.radians(roll), 0.0), "XYZ").to_matrix().to_4x4()
        parts.append(torus(k.n(f"Wrap{i}"), rx * 0.985, 0.022, (0, 0, 0), m=purple_dark, major_segs=36, minor_segs=8))
        parts[-1].matrix_world = fold @ Matrix.Diagonal((1.0, 0.94, 1.0, 1.0))
    parts.append(loft(k.n("TurbanBand"), [(0.0, 0.258, 0.244, 0, 0, 2.2), (0.008, 0.262, 0.248, 0, 0, 2.2), (0.036, 0.27, 0.256, 0, 0, 2.2),
                                          (0.044, 0.266, 0.252, 0, 0, 2.2)], gold, segs=32, sub=1, frame=f, caps=("flat", "flat"), sharp=70))
    for i in range(16):
        a = math.tau * (i + 0.5) / 16 - math.pi / 2
        if abs(math.atan2(math.sin(a + math.pi / 2), math.cos(a + math.pi / 2))) < 0.42:
            continue                     # leave the front for the jewel
        p = Vector((math.cos(a) * 0.272, math.sin(a) * 0.258, 0.022))
        parts.append(blob(k.n(f"BandBulb{i}"), 0.0125, f @ p, bulb, segs=8, rings=6))
    # The all-seeing eye: a gold almond with a glowing iris, a sunburst behind.
    eye = f @ Matrix.Translation((0, -0.29, 0.085)) @ Euler((math.radians(90 - 10), 0, 0), "XYZ").to_matrix().to_4x4()
    for i in range(9):
        a = math.radians(-90 + 22.5 * i)
        ray = eye @ Matrix.Translation((math.cos(a) * 0.075, math.sin(a) * 0.075 + 0.0, -0.012)) @ Euler((0, 0, a), "XYZ").to_matrix().to_4x4()
        parts.append(box(k.n(f"Ray{i}"), (0.05, 0.016, 0.01), (0, 0, 0), bevel=0.004, m=gold))
        parts[-1].matrix_world = ray
    parts.append(blob(k.n("EyeSetting"), 1.0, (0, 0, 0), gold, segs=20, rings=10))
    parts[-1].matrix_world = eye @ Matrix.Diagonal((0.07, 0.044, 0.026, 1.0))
    parts.append(blob(k.n("EyeWhite"), 1.0, (0, 0, 0), white, segs=18, rings=9))
    parts[-1].matrix_world = eye @ Matrix.Translation((0, 0, 0.008)) @ Matrix.Diagonal((0.056, 0.034, 0.022, 1.0))
    parts.append(blob(k.n("EyeIris"), 0.021, eye @ Vector((0, 0, 0.022)), iris, scale=(1, 1, 0.55), segs=12, rings=7))
    parts.append(blob(k.n("EyeLid"), 1.0, (0, 0, 0), purple_dark, segs=16, rings=8))
    parts[-1].matrix_world = eye @ Matrix.Translation((0, 0.026, 0.01)) @ Matrix.Diagonal((0.06, 0.016, 0.024, 1.0))
    # Plume: three feathers fanning up from behind the jewel.
    for i, (lean, roll, h) in enumerate(((-16.0, 0.0, 0.42), (-12.0, 24.0, 0.33), (-12.0, -24.0, 0.33))):
        base = f @ Matrix.Translation((0, -0.255, 0.15)) @ Euler((math.radians(lean), math.radians(roll), 0), "XYZ").to_matrix().to_4x4()
        rows = [(0.0, 0.014, 0.009, 0, 0, 2.0), (h * 0.3, 0.052, 0.014, 0, 0.012, 2.0), (h * 0.7, 0.06, 0.014, 0, 0.04, 2.0),
                (h, 0.026, 0.009, 0, 0.08, 2.0)]
        parts.append(loft(k.n(f"Feather{i}"), rows, cream, segs=14, sub=2, frame=base, caps=("round", "round"), cap_h=(0.01, 0.02)))
        parts.append(blob(k.n(f"FeatherTip{i}"), 0.04, base @ Vector((0, 0.072, h * 0.9)), pink, scale=(1.0, 0.42, 1.4), segs=10, rings=6))
    parts.append(blob(k.n("PlumeKnot"), 0.034, f @ Vector((0, -0.262, 0.15)), gold, segs=10, rings=7))
    k.add(parts, bone="Head", tag="headgear")


def _hairline(front, temple, side, back):
    from operator_anim import curve

    def fn(az):
        return curve(abs(az), [(0.0, front), (0.75, front), (1.15, temple), (1.6, side), (2.3, back), (math.pi, back)])
    return fn


def _veil(k, m, gold):
    """A scarf falling from the back of the turban to the nape, fringed with coins."""
    secs = []
    for z in (-0.17, -0.12, -0.06, 0.0, 0.06, 0.11):
        rx, ry = k.head_radius(z)
        g = 0.034 + 0.012 * (0.11 - z)
        secs.append((z, rx + g, ry + g, 0.0, 0.006, 2.4, 112.0))
    f = Matrix.Translation(HEAD_C)
    parts = [loft(k.n("Veil"), secs, m, segs=30, sub=2, frame=f, caps=(None, None), open_front=True, thickness=0.008)]
    rx, ry = k.head_radius(-0.17)
    for i in range(11):
        a = math.radians(26 + 128 * i / 10)          # round the back (+Y)
        out = Vector((math.cos(a), math.sin(a), 0.0))
        p = HEAD_C + Vector((out.x * (rx + 0.044), out.y * (ry + 0.044) + 0.006, -0.19))
        parts.append(cyl(k.n(f"Coin{i}"), 0.017, 0.005, p, rot=(math.pi / 2, 0.0, a + math.pi / 2), segs=12, bevel=0.0015, m=gold))
    k.add(parts, bone="Head", tag="headgear")


def _collar(k, velvet_dark, gold, bulb):
    """A tall fan collar standing behind the head, its rim lined with bulbs."""
    rows = []
    for i in range(9):
        a = math.radians(205 - 230 * i / 8)          # around the back, from the left shoulder to the right
        rows.append(Vector((math.cos(a) * 0.255, math.sin(a) * 0.205 + 0.07, 1.44)))
    out = [(r - Vector((0, 0.07, 1.44))).normalized() for r in rows]
    nors = [(o + Vector((0, 0, -0.5))).normalized() for o in out]
    parts = [ribbon(k.n("Collar"), rows, nors, 0.15, 0.007, velvet_dark)]
    rim = [r + o * 0.03 + Vector((0, 0, 0.066)) for r, o in zip(rows, out)]
    parts.append(tube(k.n("CollarRim"), rim, 0.01, m=gold, segs=8))
    for i in range(1, 8):
        p = rows[i] + out[i] * 0.04 + Vector((0, 0, 0.07))
        parts.append(blob(k.n(f"CollarBulb{i}"), 0.014, p, bulb, segs=8, rings=6))
    k.add(parts, bone="Chest", tag="collar")


def _cape(k, star, lining, gold):
    """A long night-sky cape on two bones, gold edged."""
    rows = [(1.36, 0.155, 0.5), (1.29, 0.178, 0.56), (1.18, 0.198, 0.62), (1.05, 0.21, 0.68), (0.92, 0.222, 0.73), (0.79, 0.24, 0.77),
            (0.66, 0.262, 0.8), (0.55, 0.282, 0.8), (0.47, 0.296, 0.76)]
    normals = [(0, 1, 0.1)] * len(rows)
    cape = [ribbon(k.n("Cape"), [(0, y, z) for z, y, _w in rows], normals, [w for _z, _y, w in rows], 0.008, star),
            ribbon(k.n("CapeLining"), [(0, y - 0.011, z + 0.004) for z, y, _w in rows], [(0, -1, -0.1)] * len(rows), [w - 0.035 for _z, _y, w in rows], 0.004,
                   lining)]
    hem = [(-0.37 + 0.074 * i, 0.304, 0.468) for i in range(11)]
    cape.append(tube(k.n("CapeHem"), hem, 0.011, m=gold, segs=8))
    k.add(cape, tag="cape", region="cape", blend=("Cape1", "Cape2", 1.1, 0.9))


def op_fortuna():
    """Madame Fortuna: the fortune teller from the booth at the end of the pier."""
    k = Kit("MF_", "#e0a07c", dict(waist=0.95, hip=1.05, chest=1.02))
    k.extra_bones = [("Cape1", (0, 0.16, 1.34), (0, 0.2, 1.0), "Chest"), ("Cape2", (0, 0.2, 1.0), (0, 0.27, 0.5), "Cape1")]
    velvet = mat("Velvet", "#de1f4f", rough=0.62)
    velvet_dark = mat("VelvetDark", "#a3123c", rough=0.62)
    midnight = mat("Midnight", "#251a63", rough=0.6)
    purple = mat("TurbanSilk", "#6a35d0", rough=0.45)
    purple_dark = mat("TurbanFold", "#4b22a3", rough=0.5)
    gold = mat("Gold", "#ffc23d", rough=0.25, metal=0.85)
    gold_hi = mat("GoldTrim", "#ffd96a", rough=0.2, metal=0.9)
    cream = mat("Plume", "#fff1dc", rough=0.7)
    pink = mat("PlumeTip", "#ff3fa4", rough=0.5)
    white = mat("EyeJewelWhite", "#fffaf2", rough=0.25)
    iris = mat("EyeJewelIris", "#35f0ff", rough=0.15, emit=3.0)
    orb = mat("OrbGlow", "#7ff6ff", rough=0.1, emit=2.4)
    bulb = mat("FxBulbWarm", "#ffd36a", rough=0.2, emit=2.5)
    star = mat("FxStarCape", "#1d1650", rough=0.4)
    hair = mat("Hair", "#2d1846", rough=0.7)
    slipper = mat("Slipper", "#ffc23d", rough=0.3, metal=0.6)
    sole = mat("SlipperSole", "#a3123c", rough=0.6)

    k.head()
    k.face(iris="#7a2fd0", brow="#2d1846", mouth="smirk", lids=0.24, brow_tilt=-12, blush="#ff7fa0", lash="#1c1030")
    k.hair_cap(hair, _hairline(0.64, 0.3, 0.02, -0.3), grow=0.03, volume=lambda d: 0.03 * max(0.0, d.y))
    k.neck()
    _turban(k, purple, purple_dark, gold, bulb, white, iris, cream, pink)
    _veil(k, purple_dark, gold)
    for side in (1, -1):
        x = side * 0.236
        k.add([torus(k.n(f"Hoop{side}"), 0.04, 0.008, (x + side * 0.008, 0.012, HEAD_C.z - 0.09), rot=rad(0, 90, 0), m=gold, major_segs=20, minor_segs=6),
               blob(k.n(f"HoopStud{side}"), 0.013, (x + side * 0.01, 0.012, HEAD_C.z - 0.045), gold_hi, segs=8, rings=6)], bone="Head", tag="head")
    k.add(torus(k.n("Choker"), 0.079, 0.011, (0, 0.0, 1.405), m=gold, major_segs=24, minor_segs=6), bone="Chest", tag="neck")
    k.add(blob(k.n("ChokerGem"), 0.018, (0, -0.092, 1.385), orb, segs=10, rings=7), bone="Chest", tag="neck")

    k.torso(midnight, lower_m=midnight, split_z=0.95)
    gap = (17.0, 24.0)
    k.shell("Coat", 0.89, 1.355, velvet, grow=0.014, thickness=0.016, gap=gap, flare=0.04)
    front = k.on_torso("front")
    for side in (1, -1):
        _detail_lapel = strip(k.n(f"Lapel{side}"), [(side * 0.03, 0.88, 0.012), (side * 0.045, 1.02, 0.016), (side * 0.06, 1.16, 0.024),
                                                     (side * 0.09, 1.27, 0.03), (side * 0.12, 1.34, 0.022)], front, gold_hi, lift=0.007)
        k.add(_detail_lapel, field=True, tag="detail")
    k.add([decal(k.n("Brooch"), ellipse_outline(0, 1.22, 0.036, 0.036, 16), front, gold, lift=0.006, dome=0.004),
           decal(k.n("BroochOrb"), ellipse_outline(0, 1.224, 0.024, 0.024, 14), front, orb, lift=0.014, sink=0.0, dome=0.012)]
          + [decal(k.n(f"DressStar{i}"), star_at(x, z, 0.016, 0.007), front, gold_hi, lift=0.005, sink=0.0, dome=0.002)
             for i, (x, z) in enumerate(((0.0, 1.1), (-0.012, 1.02), (0.016, 0.9)))], field=True, tag="detail")
    k.belt(0.985, 0.06, gold, grow=0.004, name="Sash")
    k.add([decal(k.n("Moon"), ellipse_outline(0, 0.985, 0.04, 0.04, 16), k.on_torso("front"), gold_hi, lift=0.012, dome=0.004),
           decal(k.n("MoonBite"), ellipse_outline(0.016, 0.993, 0.032, 0.032, 16), k.on_torso("front"), midnight, lift=0.017, sink=0.0, dome=0.002)],
          field=True, tag="detail")
    # Marquee bulbs round the hem and up both edges of the opening.
    bulbs = []
    for i in range(22):
        a = 270.0 + gap[0] + 4.0 + (360.0 - 2 * gap[0] - 8.0) * i / 21
        p = k.torso_point(0.918, a, 0.004)
        bulbs.append(blob(k.n(f"HemBulb{i}"), 0.015, p, bulb, segs=8, rings=6))
    for side in (1, -1):
        for i, z in enumerate((0.97, 1.04, 1.11, 1.18, 1.25, 1.31)):
            g = gap[0] + (gap[1] - gap[0]) * ((z - 0.89) / 0.465) ** 1.5
            p = k.torso_point(z, 270.0 + side * (g + 5.0), 0.002)
            bulbs.append(blob(k.n(f"EdgeBulb{side}{i}"), 0.0125, p, bulb, segs=8, rings=6))
    k.add(bulbs, field=True, tag="detail")
    _collar(k, velvet_dark, gold, bulb)
    _cape(k, star, velvet, gold)
    for side in (1, -1):
        p = k.torso_point(1.33, 270 + side * 58, 0.014)
        k.add(blob(k.n(f"Clasp{side}"), 0.03, p, orb, segs=10, rings=6), bone="Chest", tag="gear")

    def limbs(side, s):
        k.upper_arm(side, velvet)
        k.arm_band(side, "UpperArm", -0.08, 0.2, velvet_dark, grow=0.02, name="Puff", taper=(0.012, 0.0))
        k.fore_arm(side, velvet)
        for i, f0 in enumerate((0.42, 0.52, 0.62)):
            k.arm_band(side, "ForeArm", f0, f0 + 0.06, gold if i != 1 else gold_hi, grow=0.01, name=f"Bangle{i}")
        k.arm_band(side, "ForeArm", 0.74, 0.93, gold_hi, grow=0.012, name="Cuff", taper=(0.0, 0.01))
        k.hand(side, midnight, plate_m=gold)
        k.thigh(side, midnight)
        k.shin(side, midnight)
        k.leg_band(side, "Shin", 0.5, 0.8, midnight, grow=0.024, name="Gather", taper=(-0.01, 0.0))
        k.leg_band(side, "Shin", 0.8, 0.92, gold, grow=0.012, name="Anklet")
        k.shoe(side, slipper, sole, toe_m=velvet, style="shoe", heel_m=velvet)
    for side in (1, -1):
        limbs(side, "L" if side > 0 else "R")
    return k, crystal_gaze, dict(bend=24, out=0.31, lean=-1.5, chin=-3.0, look=0.8, sway=0.9, aim=BULKY_HOLD)


def crystal_gaze(idle0):
    """Pose: hands circle an unseen crystal ball while she peers in, then she
    raises a hand to the spirits and opens the other to the viewer:
    "I see... you, winning."
    """
    def ball(dx, dz, head_yaw):
        hunch = body(idle0, shift=(0, -0.01, -0.03), spine=(4, 0, 0), chest=(5, 0, 0), head=(14, head_yaw, 0))
        return _merge(hunch,
                      arm(1, 0.62 + dx, 0.85, -0.3 + dz, bend=74, twist=46, wrist=(0, 0, 10), curl="cup", thumb=(4, 0)),
                      arm(-1, 0.62 - dx, 0.85, -0.3 - dz, bend=74, twist=46, wrist=(0, 0, 10), curl="cup", thumb=(4, 0)))
    spirits = arm(1, 0.95, 0.25, 0.3, bend=64, twist=-80, wrist=(0, -10, 0), curl="open", thumb=(-14, 8))
    reveal = _merge(body(idle0, shift=(0, -0.03, 0.0), hips=(2, 0, 0), spine=(3, 0, -4), chest=(-2, 0, -8), head=(-6, 6, -6)), spirits,
                    arm(-1, 0.42, 1.0, 0.12, bend=12, twist=-30, wrist=(0, -10, 0), curl="open", thumb=(-14, 8)))
    hold = _merge(body(reveal, head=(-8, 4, -8), chest=(-3, 0, -9)), spirits,
                  arm(-1, 0.46, 1.0, 0.16, bend=10, twist=-34, wrist=(0, -14, 0), curl="open", thumb=(-14, 8)))
    return [(0.0, idle0), (0.36, ball(0.0, 0.05, 0)), (0.62, ball(0.05, 0.0, 6)), (0.88, ball(0.0, -0.05, 0)), (1.14, ball(-0.05, 0.0, -6)),
            (1.4, ball(0.0, 0.05, 0)), (1.72, reveal), (2.3, hold), (2.9, idle0)], 2.9


OPERATORS_MYTHIC = {
    "fortuna": op_fortuna,
}
