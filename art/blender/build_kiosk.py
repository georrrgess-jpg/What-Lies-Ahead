"""The Prize Kiosk: the round star-and-seagull stall at the centre of Prize Pier.

Exports three nodes: Kiosk (the stall), Seagull (the giant gull on the roof)
and Plaza (painted deck markings around it). Front faces -Y (Godot +Z).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403


def _eyes(prefix, y, z, spread, r, white, dark):
    out = []
    for i, x in enumerate((-spread, spread)):
        out.append(sphere(f"{prefix}Eye{i}", r, (x, y, z), m=white, segs=8, rings=6))
        out.append(sphere(f"{prefix}Pupil{i}", r * 0.5, (x, y - r * 0.7, z), m=dark, segs=6, rings=4))
    return out


def plush_octopus(prefix):
    pink, white, dark = mat("PinkLight"), mat("White"), mat("Dark")
    parts = [sphere(prefix + "Head", 0.3, (0, 0, 0.36), scale=(1, 1, 0.95), m=pink, segs=12, rings=8)]
    for i in range(6):
        a = math.tau * i / 6 + 0.3
        parts.append(sphere(f"{prefix}Leg{i}", 0.11, (math.cos(a) * 0.24, math.sin(a) * 0.24, 0.1), m=pink, segs=8, rings=5))
    return parts + _eyes(prefix, -0.26, 0.42, 0.11, 0.06, white, dark)


def plush_shark(prefix):
    blue, white, dark = mat("Blue"), mat("White"), mat("Dark")
    parts = [
        sphere(prefix + "Body", 0.3, (0, 0, 0.3), scale=(1.5, 0.95, 0.95), m=blue, segs=12, rings=8),
        sphere(prefix + "Belly", 0.27, (0, -0.06, 0.22), scale=(1.4, 0.9, 0.7), m=white, segs=12, rings=8),
        cyl(prefix + "Fin", 0.13, 0.26, (0, 0, 0.66), segs=8, bevel=0.0, m=blue, radius_top=0.01),
        cyl(prefix + "Tail", 0.12, 0.24, (0.5, 0, 0.34), rot=rad(0, 70, 0), segs=8, bevel=0.0, m=blue, radius_top=0.01),
    ]
    for i in range(4):
        parts.append(cyl(f"{prefix}Tooth{i}", 0.035, 0.07, (-0.22 + i * 0.1, -0.27, 0.2), rot=rad(180, 0, 0), segs=5,
                         bevel=0.0, m=white, radius_top=0.0))
    return parts + _eyes(prefix, -0.25, 0.38, 0.2, 0.05, white, dark)


def plush_bear(prefix):
    brown, cream, dark = mat("Brown"), mat("Cream"), mat("Dark")
    parts = [
        sphere(prefix + "Body", 0.24, (0, 0, 0.24), scale=(1, 0.9, 1), m=brown, segs=10, rings=7),
        sphere(prefix + "Head", 0.21, (0, -0.02, 0.58), m=brown, segs=10, rings=7),
        sphere(prefix + "Muzzle", 0.1, (0, -0.19, 0.54), m=cream, segs=8, rings=5),
        sphere(prefix + "Nose", 0.035, (0, -0.28, 0.57), m=dark, segs=6, rings=4),
    ]
    for i, x in enumerate((-0.16, 0.16)):
        parts.append(sphere(f"{prefix}Ear{i}", 0.08, (x, 0, 0.76), m=brown, segs=8, rings=5))
        parts.append(sphere(f"{prefix}Arm{i}", 0.09, (x * 1.6, -0.06, 0.3), m=brown, segs=8, rings=5))
        parts.append(sphere(f"{prefix}Eyeb{i}", 0.03, (x * 0.5, -0.2, 0.64), m=dark, segs=6, rings=4))
    return parts


def plush_star(prefix):
    yellow, dark = mat("Yellow"), mat("Dark")
    parts = [star(prefix + "Star", 0.34, 0.16, (0, 0, 0.36), m=yellow, bevel=0.03)]
    for i, x in enumerate((-0.08, 0.08)):
        parts.append(sphere(f"{prefix}Eye{i}", 0.03, (x, -0.09, 0.4), m=dark, segs=6, rings=4))
    return parts


def build_seagull():
    """Giant gull, about 2.6 m long, looking toward +X."""
    white, grey, orange, dark = mat("White"), mat("GullGrey", "#8d93a6"), mat("Orange"), mat("Dark")
    parts = [
        sphere("GullBody", 0.62, (0, 0, 1.0), scale=(1.75, 1.0, 1.0), rot=rad(0, -12, 0), m=white, segs=18, rings=12),
        sphere("GullChest", 0.5, (0.5, 0, 1.12), scale=(1.1, 1.0, 1.05), m=white, segs=14, rings=10),
        sphere("GullHead", 0.4, (0.95, 0, 1.78), m=white, segs=14, rings=10),
        cyl("GullNeck", 0.3, 0.6, (0.8, 0, 1.45), rot=rad(0, 25, 0), segs=12, bevel=0.0, m=white, radius_top=0.26),
        cyl("GullBeak", 0.14, 0.62, (1.5, 0, 1.72), rot=rad(0, 98, 0), segs=10, bevel=0.0, m=orange, radius_top=0.03),
        sphere("GullBeakTip", 0.06, (1.78, 0, 1.64), m=orange, segs=6, rings=4),
        sphere("GullTail", 0.4, (-1.15, 0, 1.25), scale=(1.2, 0.75, 0.3), rot=rad(0, -25, 0), m=grey, segs=10, rings=6),
        sphere("GullTailTip", 0.22, (-1.5, 0, 1.4), scale=(1.2, 0.8, 0.3), rot=rad(0, -25, 0), m=dark, segs=8, rings=5),
    ]
    for i, y in enumerate((-1, 1)):
        parts += [
            sphere(f"GullWing{i}", 0.6, (-0.15, y * 0.55, 1.12), scale=(1.55, 0.26, 0.72), rot=rad(0, -14, 0), m=grey, segs=14, rings=8),
            sphere(f"GullEye{i}", 0.06, (1.1, y * 0.33, 1.86), m=dark, segs=8, rings=5),
            cyl(f"GullLeg{i}", 0.05, 0.5, (0.15, y * 0.24, 0.3), segs=8, bevel=0.0, m=orange),
            sphere(f"GullFoot{i}", 0.16, (0.25, y * 0.24, 0.07), scale=(1.4, 1.0, 0.3), m=orange, segs=8, rings=5),
        ]
    return parts


def build():
    reset_scene()
    teal, tdark, pink, hot = mat("Teal"), mat("TealDark"), mat("Pink"), mat("PinkDark")
    cream, yellow, purple = mat("Cream"), mat("Yellow"), mat("PurpleDark")
    amber = glow("BulbAmber", "#ffb030", 1.9)
    lamp = glow("LampWarm", "#ffc860", 1.7)
    S = 32  # radial segments for the big cylinders

    k = [
        cyl("Plinth", 4.55, 0.3, (0, 0, 0.15), segs=S, bevel=0.06, m=hot),
        cyl("CounterWall", 4.2, 1.1, (0, 0, 0.85), segs=S, bevel=0.03, m=teal),
        cyl("CounterBand", 4.26, 0.22, (0, 0, 0.55), segs=S, bevel=0.03, m=tdark),
        cyl("CounterTop", 4.46, 0.18, (0, 0, 1.47), segs=S, bevel=0.06, m=pink),
        cyl("Core", 2.7, 2.3, (0, 0, 2.6), segs=24, bevel=0.03, m=purple),
        cyl("Shelf", 3.15, 0.08, (0, 0, 2.5), segs=24, bevel=0.02, m=cream),
        # Roof.
        cyl("RoofRimLow", 5.05, 0.14, (0, 0, 3.66), segs=S, bevel=0.04, m=yellow),
        cyl("RoofRim", 4.98, 0.5, (0, 0, 3.95), segs=S, bevel=0.1, m=pink),
        cyl("RoofCone", 4.88, 2.5, (0, 0, 5.43), segs=S, bevel=0.0, m=teal, radius_top=1.45),
        cyl("RoofDrum", 1.5, 0.42, (0, 0, 6.85), segs=20, bevel=0.08, m=pink),
        cyl("RoofCap", 1.3, 0.28, (0, 0, 7.17), segs=20, bevel=0.06, m=yellow, radius_top=1.0),
    ]
    # Pilasters around the counter and posts holding the roof.
    for i in range(16):
        a = math.tau * (i + 0.5) / 16
        k += place([box(f"Pilaster{i:02d}", (0.3, 0.12, 0.98), (0, -4.22, 0.86), bevel=0.04, m=pink)], rot_z=a)
    for i in range(8):
        a = math.tau * (i + 0.5) / 8
        k += place([cyl(f"Post{i}", 0.12, 2.2, (0, -4.12, 2.62), segs=10, bevel=0.0, m=cream),
                    cyl(f"PostCollar{i}", 0.17, 0.14, (0, -4.12, 1.64), segs=10, bevel=0.03, m=pink)], rot_z=a)
    # Roof ribs and rim bulbs.
    slope = math.atan2(2.5, 4.88 - 1.45)
    for i in range(12):
        a = math.tau * i / 12
        k += place([box(f"Rib{i:02d}", (0.22, 4.25, 0.14), (0, -3.165, 5.46), rot=(slope, 0, 0), bevel=0.04, m=cream)], rot_z=a)
    k += bulb_ring("RimBulb", 5.02, 30, 3.95, 0.11, amber)
    k += bulb_ring("DrumBulb", 1.53, 12, 6.85, 0.08, amber)
    # Scalloped valance under the rim, alternating colours.
    for i in range(36):
        a = math.tau * i / 36
        k += place([cyl(f"Scallop{i:02d}", 0.44, 0.1, (0, -4.99, 3.62), rot=rad(90, 0, 0), segs=14, bevel=0.02,
                        m=cream if i % 2 else pink)], rot_z=a)
    # Warm lamps under the canopy.
    for i in range(8):
        a = math.tau * i / 8
        k += place([sphere(f"Lamp{i}", 0.17, (0, -3.6, 3.35), m=lamp, segs=8, rings=6)], rot_z=a)
    # Prizes: one ring on the counter, one on the shelf.
    makers = [plush_octopus, plush_star, plush_shark, plush_bear]
    for ring, (radius, z, count, offset) in enumerate(((3.72, 1.56, 20, 0), (2.92, 2.54, 14, 2))):
        for i in range(count):
            a = math.tau * i / count
            parts = makers[(i + offset) % 4](f"Prize{ring}_{i:02d}_")
            k += place(parts, (math.sin(a) * radius, -math.cos(a) * radius, z), rot_z=a, scale=1.15)
    # Star signs on the roof: front and back.
    for i, a in enumerate((0.0, math.pi)):
        sign = [
            cyl(f"SignDisc{i}", 1.3, 0.3, (0, 0, 0), rot=rad(90, 0, 0), segs=24, bevel=0.08, m=hot),
            star(f"SignStar{i}", 1.05, 0.2, (0, -0.2, 0), m=pink, bevel=0.03),
            star(f"SignStarInner{i}", 0.62, 0.2, (0, -0.28, 0), m=yellow, bevel=0.03),
        ]
        sign += bulb_ring(f"SignBulb{i}_", 1.18, 14, -0.2, 0.085, amber, plane="XZ")
        for ob in sign:
            ob.matrix_world = Matrix.Rotation(-0.42, 4, "X") @ ob.matrix_basis
        k += place(sign, (math.sin(a) * 3.45, -math.cos(a) * 3.45, 5.55), rot_z=a)

    gull = place(build_seagull(), (0, 0, 7.25), scale=1.25)

    plaza = [
        disc("PlazaRing", 7.7, m=pink, inner=6.3),
        disc("PlazaBand", 6.3, m=mat("PlazaInner", "#b0356f", rough=0.7), inner=4.5),
        disc("PlazaEdge", 7.95, m=cream, inner=7.7),
        star("PlazaStar", 1.25, 0.03, (0, -9.6, 0.03), rot=rad(-90, 0, 0), m=yellow),
        star("PlazaStarBack", 1.25, 0.03, (0, 9.6, 0.03), rot=rad(-90, 0, 180), m=yellow),
    ]
    for ob in plaza[:3]:
        ob.location.z = 0.012

    exports = [merge("Kiosk", k), merge("Seagull", gull, pivot=(0, 0, 7.25)), merge("Plaza", plaza)]
    save("kiosk", exports)


if __name__ == "__main__":
    build()
