"""The Arsenal's workbench booth: the 3D diorama behind the Arsenal page.

A carnival repair booth on Prize Pier: a plank workbench, a pegboard wall with
wrenches and a blueprint monitor under a striped awning, a work lamp on an arm,
the weapon stand (base and turntable) and bench clutter: an enamel mug, a roll
of tape, a screwdriver, a cloth and a little scope tester. Behind it the pier
deck, its railing with bulbs and a gull. Everything is sized for the Arsenal's
camera, which looks almost level across the bench from 2.6 m.

Exports (art/models/menu_booth.glb), bench top at height 0, camera side -Y:
  Booth            everything static
  BlueprintScreen  the monitor's screen (the game draws the selected weapon on it)
  StandFork        one cradle fork, origin on its pad's top face, long axis X
                   (the game places two under the weapon and sets their height)
  StandCollar      the collar a fork's post enters the turntable through
  Gull             the seagull on the railing (origin at its feet)

The turntable's top is TURNTABLE_TOP above the bench; arsenal_page.gd uses the
same number.

    $BPY art/blender/build_menu_booth.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403

TURNTABLE_TOP = 0.085
DECK_Z = -0.95
# The work lamp's shade (x, y, z): arsenal_page.gd puts its light there.
LAMP = (-0.42, 0.3, 0.62)


def build_bench():
    wood, wood_dark = mat("BenchWood", "#74425c"), mat("BenchWoodDark", "#5a3350")
    parts = []
    for i in range(7):
        parts.append(box(f"Plank{i}", (4.4, 0.235, 0.08), (0.0, -0.72 + i * 0.24, -0.04), bevel=0.012,
                         m=wood if i % 2 == 0 else wood_dark))
    parts.append(box("Apron", (4.4, 0.06, 0.34), (0.0, -0.8, -0.24), bevel=0.012, m=mat("BenchApron", "#43263f")))
    for i, x in enumerate((-2.0, -0.7, 0.7, 2.0)):
        parts.append(cyl(f"ApronBolt{i}", 0.022, 0.02, (x, -0.835, -0.14), rot=rad(90, 0, 0), segs=10, bevel=0.005, m=mat("Cream")))
    return parts


def build_wall():
    teal, tdark = mat("BoothTeal", "#1f8f8a"), mat("BoothTealDark", "#135e5f")
    peg, cream, metal = mat("Pegboard", "#473a6e"), mat("Cream"), mat("ToolSteel", "#b8b4c4", rough=0.35, metal=0.6)
    hole = mat("PegHole", "#231b3d")
    parts = [
        box("Pegboard", (1.36, 0.05, 0.68), (-0.98, 0.62, 0.42), bevel=0.01, m=peg),
        box("PostL", (0.11, 0.11, 0.95), (-1.72, 0.6, 0.4), bevel=0.02, m=teal),
        box("PostR", (0.11, 0.11, 0.95), (-0.26, 0.6, 0.4), bevel=0.02, m=teal),
        box("Beam", (1.6, 0.11, 0.11), (-0.99, 0.6, 0.82), bevel=0.02, m=teal),
        box("Sill", (1.6, 0.16, 0.06), (-0.99, 0.56, 0.05), bevel=0.015, m=tdark),
        cyl("BenchCan", 0.05, 0.12, (-1.0, 0.36, 0.06), segs=14, bevel=0.01, m=mat("Purple")),
        box("BenchBox", (0.16, 0.12, 0.08), (-1.2, 0.34, 0.04), rot=rad(0, 0, 14), bevel=0.012, m=mat("Amber")),
        # Blueprint monitor.
        box("MonitorFrame", (0.56, 0.07, 0.37), (-0.72, 0.57, 0.46), bevel=0.03, m=tdark),
        box("MonitorArm", (0.1, 0.05, 0.1), (-0.72, 0.61, 0.46), bevel=0.01, m=teal),
    ]
    for i, (x, z) in enumerate(((-1.72, 0.82), (-0.26, 0.82), (-1.72, 0.14), (-0.26, 0.14))):
        parts.append(cyl(f"FrameRivet{i}", 0.026, 0.02, (x, 0.54, z), rot=rad(90, 0, 0), segs=10, bevel=0.006, m=cream))
    for ix in range(13):
        for iz in range(6):
            x, z = -1.58 + ix * 0.1, 0.16 + iz * 0.1
            if -1.05 < x < -0.4 and 0.24 < z < 0.68:
                continue  # behind the monitor
            parts.append(cyl(f"Hole{ix}_{iz}", 0.011, 0.012, (x, 0.593, z), rot=rad(90, 0, 0), segs=6, bevel=0.0, m=hole))
    # Two open-end wrenches hanging on pegs.
    for i, (x, length) in enumerate(((-1.3, 0.36), (-1.14, 0.28))):
        z = 0.66 - length * 0.5
        parts += [
            box(f"Wrench{i}Handle", (0.04, 0.016, length), (x, 0.582, z), bevel=0.006, m=metal),
            cyl(f"Wrench{i}Peg", 0.012, 0.05, (x, 0.575, 0.67), rot=rad(90, 0, 0), segs=8, bevel=0.0, m=cream),
        ]
        for end, sign in (("Top", 1), ("Bottom", -1)):
            zc = z + sign * (length * 0.5 + 0.018)
            for side in (-1, 1):
                parts.append(box(f"Wrench{i}{end}Jaw{side}", (0.022, 0.016, 0.062), (x + side * 0.026, 0.582, zc + sign * 0.016),
                                 rot=rad(0, -sign * side * 16, 0), bevel=0.005, m=metal))
            parts.append(box(f"Wrench{i}{end}Neck", (0.074, 0.016, 0.034), (x, 0.582, zc - sign * 0.02), bevel=0.005, m=metal))
    return parts

def build_awning():
    pink, cream = mat("AwningPink", "#e23a82"), mat("Cream")
    parts = []
    slope = math.radians(-22)
    for i in range(9):
        x = -1.87 + i * 0.22
        m = pink if i % 2 == 0 else cream
        parts.append(box(f"Stripe{i}", (0.222, 0.92, 0.035), (x, 0.17, 0.955), rot=(slope, 0, 0), bevel=0.008, m=m))
        # Scalloped valance along the front edge.
        parts.append(cyl(f"Scallop{i}", 0.111, 0.03, (x, -0.262, 0.715), rot=rad(90, 0, 0), segs=14, bevel=0.006, m=m))
        parts.append(box(f"Valance{i}", (0.222, 0.03, 0.09), (x, -0.262, 0.76), bevel=0.004, m=m))
    parts.append(box("AwningBar", (2.05, 0.05, 0.05), (-0.99, -0.24, 0.785), bevel=0.01, m=mat("BoothTealDark", "#135e5f")))
    return parts

def build_lamp():
    """Work lamp on an arm from the booth's right post, clear of the turntable."""
    teal, tdark = mat("BoothTeal", "#1f8f8a"), mat("BoothTealDark", "#135e5f")
    warm = glow("LampBulb", "#ffd27a", 4.0)
    x, y = LAMP[0], LAMP[1]
    return [
        tube("LampArm", [(-0.26, 0.56, 0.78), (-0.3, 0.44, 0.83), (x + 0.02, y + 0.03, 0.8), (x, y, LAMP[2] + 0.1)], 0.016, m=tdark, segs=8),
        cyl("LampCap", 0.055, 0.06, (x, y, LAMP[2] + 0.085), segs=14, bevel=0.012, m=tdark),
        cyl("LampShade", 0.17, 0.12, (x, y, LAMP[2]), segs=20, bevel=0.01, m=teal, radius_top=0.06),
        cyl("LampRim", 0.178, 0.022, (x, y, LAMP[2] - 0.064), segs=20, bevel=0.007, m=mat("Cream")),
        sphere("LampGlow", 0.065, (x, y, LAMP[2] - 0.045), m=warm, segs=12, rings=8),
    ]

def build_stand():
    teal, tdark = mat("BoothTeal", "#1f8f8a"), mat("BoothTealDark", "#135e5f")
    pink, cream, dark, yellow = mat("Pink"), mat("Cream"), mat("Dark"), mat("Yellow")
    parts = [
        box("StandBase", (0.94, 0.46, 0.045), (0, 0, 0.0225), bevel=0.014, m=teal),
        cyl("Turntable", 0.3, 0.036, (0, 0, 0.065), segs=36, bevel=0.01, m=tdark),
        cyl("TurntableRing", 0.31, 0.012, (0, 0, 0.052), segs=36, bevel=0.004, m=cream),
        box("HazardPlate", (0.56, 0.02, 0.07), (0, -0.236, 0.04), bevel=0.006, m=dark),
    ]
    # Slanted yellow stripes that stay inside the plate.
    stripe = [(0.0, -0.028), (0.045, -0.028), (0.075, 0.028), (0.03, 0.028)]
    for i in range(6):
        parts.append(prism(f"Hazard{i}", stripe, 0.008, (-0.262 + i * 0.09, -0.248, 0.04), m=yellow))
    for i, x in enumerate((-0.4, 0.4)):
        parts += [
            box(f"Foot{i}", (0.14, 0.5, 0.06), (x, 0, 0.03), bevel=0.016, m=tdark),
            cyl(f"FootBoltA{i}", 0.026, 0.022, (x, -0.19, 0.068), segs=10, bevel=0.006, m=pink),
            cyl(f"FootBoltB{i}", 0.026, 0.022, (x, 0.19, 0.068), segs=10, bevel=0.006, m=pink),
        ]
    return parts

def build_props():
    """Bench clutter, set beside the stand where the camera sees it."""
    cream, purple, pink, dark = mat("Cream"), mat("Purple"), mat("Pink"), mat("Dark")
    steel = mat("ToolSteel", "#b8b4c4", rough=0.35, metal=0.6)
    yellow = mat("TapeYellow", "#f0b93a")
    mx, my = -0.64, -0.04
    parts = [
        # Enamel mug with a Ferris-wheel emblem.
        cyl("Mug", 0.078, 0.165, (mx, my, 0.0825), segs=22, bevel=0.012, m=cream),
        torus("MugRim", 0.076, 0.009, (mx, my, 0.165), m=purple, major_segs=22, minor_segs=6),
        cyl("MugCoffee", 0.066, 0.01, (mx, my, 0.158), segs=18, bevel=0.0, m=mat("Coffee", "#3a2018")),
        torus("MugHandle", 0.045, 0.012, (mx - 0.09, my, 0.085), rot=rad(90, 0, 0), m=cream, major_segs=14, minor_segs=6),
        torus("MugWheel", 0.042, 0.006, (mx, my - 0.08, 0.085), rot=rad(90, 0, 0), m=purple, major_segs=18, minor_segs=5),
        # Roll of tape.
        torus("Tape", 0.062, 0.03, (-0.6, -0.3, 0.03), m=yellow, major_segs=24, minor_segs=8),
        cyl("TapeCore", 0.036, 0.05, (-0.6, -0.3, 0.03), segs=16, bevel=0.004, m=mat("Brown")),
        # Screwdriver lying in front of the stand.
        cyl("DriverHandle", 0.024, 0.17, (-0.44, -0.37, 0.024), rot=rad(0, 90, 0), segs=12, bevel=0.01, m=pink),
        cyl("DriverCollar", 0.017, 0.03, (-0.345, -0.37, 0.024), rot=rad(0, 90, 0), segs=10, bevel=0.004, m=dark),
        cyl("DriverShaft", 0.0065, 0.2, (-0.235, -0.37, 0.024), rot=rad(0, 90, 0), segs=8, bevel=0.0, m=steel),
        # Scope tester: a little box with a green screen and three buttons.
        box("Tester", (0.26, 0.2, 0.1), (0.64, 0.24, 0.05), bevel=0.02, m=mat("TesterGrey", "#4a4860")),
        box("TesterFace", (0.22, 0.02, 0.085), (0.64, 0.135, 0.105), rot=rad(-58, 0, 0), bevel=0.006, m=dark),
        box("TesterScreen", (0.12, 0.012, 0.06), (0.6, 0.126, 0.108), rot=rad(-58, 0, 0), bevel=0.004, m=glow("TesterGlow", "#5cf0c0", 2.2)),
    ]
    for i, (x, m) in enumerate(((0.685, mat("Yellow")), (0.715, pink), (0.745, mat("Red")))):
        parts.append(box(f"TesterButton{i}", (0.022, 0.014, 0.022), (x, 0.127, 0.108), rot=rad(-58, 0, 0), bevel=0.004, m=m))
    for i in range(4):
        parts.append(box(f"MugSpoke{i}", (0.076, 0.005, 0.006), (mx, my - 0.08, 0.085), rot=rad(0, i * 45, 0), bevel=0.0, m=purple))
    # Cloth: soft folds resting on the bench.
    cloth = mat("Cloth", "#d2488e")
    for i, (x, y, sx, sy, rz) in enumerate(((0.6, -0.3, 0.17, 0.13, 12), (0.68, -0.36, 0.13, 0.11, -30), (0.54, -0.37, 0.12, 0.09, 40))):
        parts.append(sphere(f"Cloth{i}", 1.0, (x, y, 0.018 + i * 0.006), scale=(sx, sy, 0.026), rot=rad(0, 0, rz), m=cloth, segs=14, rings=8))
    return parts

def build_pier():
    teal, tdark, wood = mat("BoothTeal", "#1f8f8a"), mat("BoothTealDark", "#135e5f"), mat("Wood")
    amber = glow("PierBulb", "#ffc24a", 3.2)
    parts = [box("Deck", (44.0, 16.0, 0.2), (4.0, 7.2, DECK_Z - 0.1), bevel=0.0, m=wood)]
    for i in range(1, 16):
        parts.append(box(f"DeckGap{i:02d}", (44.0, 0.05, 0.02), (4.0, i * 0.95, DECK_Z + 0.004), bevel=0.0, m=mat("WoodDark")))
    rail_y = 7.0
    for i in range(15):
        x = -12.0 + i * 2.4
        parts += [
            box(f"RailPost{i:02d}", (0.16, 0.16, 1.25), (x, rail_y, DECK_Z + 0.625), bevel=0.03, m=teal),
            sphere(f"RailBulb{i:02d}", 0.09, (x, rail_y, DECK_Z + 1.36), m=amber, segs=10, rings=6),
        ]
    for i, z in enumerate((1.12, 0.62)):
        parts.append(box(f"Rail{i}", (34.0, 0.09, 0.09), (4.8, rail_y, DECK_Z + z), bevel=0.02, m=tdark))
    return parts


def build_fork():
    """Cradle fork: origin on the pad's top face, pad long axis along X."""
    tdark, pink = mat("BoothTealDark", "#135e5f"), mat("Pink")
    steel = mat("ToolSteel", "#b8b4c4", rough=0.35, metal=0.6)
    return [
        box("Pad", (0.07, 0.11, 0.014), (0, 0, -0.007), bevel=0.005, m=mat("Rubber", "#221c30", rough=0.9)),
        box("Yoke", (0.052, 0.094, 0.03), (0, 0, -0.029), bevel=0.008, m=tdark),
        cyl("Post", 0.013, 0.5, (0, 0, -0.293), segs=10, bevel=0.0, m=steel),
        cyl("KnobA", 0.015, 0.014, (0, -0.054, -0.029), rot=rad(90, 0, 0), segs=10, bevel=0.004, m=pink),
        cyl("KnobB", 0.015, 0.014, (0, 0.054, -0.029), rot=rad(90, 0, 0), segs=10, bevel=0.004, m=pink),
    ]


def build_gull():
    """A small gull, origin at its feet, looking toward -X."""
    white, grey, orange, dark = mat("White"), mat("GullGrey", "#8d93a6"), mat("Orange"), mat("Dark")
    parts = [
        sphere("GullBody", 0.13, (0, 0, 0.2), scale=(1.5, 0.95, 0.95), m=white, segs=14, rings=9),
        sphere("GullHead", 0.085, (-0.16, 0, 0.36), m=white, segs=12, rings=8),
        cyl("GullBeak", 0.03, 0.12, (-0.27, 0, 0.35), rot=rad(0, -95, 0), segs=8, bevel=0.0, m=orange, radius_top=0.006),
        sphere("GullTail", 0.08, (0.22, 0, 0.23), scale=(1.4, 0.7, 0.3), rot=rad(0, 20, 0), m=grey, segs=8, rings=5),
    ]
    for i, y in enumerate((-1, 1)):
        parts += [
            sphere(f"GullWing{i}", 0.12, (0.03, y * 0.105, 0.22), scale=(1.45, 0.25, 0.7), rot=rad(0, 10, 0), m=grey, segs=12, rings=7),
            sphere(f"GullEye{i}", 0.014, (-0.2, y * 0.068, 0.385), m=dark, segs=6, rings=4),
            cyl(f"GullLeg{i}", 0.01, 0.1, (0.0, y * 0.045, 0.05), segs=6, bevel=0.0, m=orange),
        ]
    return parts


def build():
    reset_scene()
    static = build_bench() + build_wall() + build_awning() + build_lamp() + build_stand() + build_props() + build_pier()
    booth = merge("Booth", static)
    screen = merge("BlueprintScreen", [box("Screen", (0.48, 0.012, 0.29), (-0.72, 0.531, 0.46), bevel=0.0,
                                           m=glow("BlueprintGlow", "#2ad8e8", 1.5))], pivot=(-0.72, 0.525, 0.46))
    fork = merge("StandFork", build_fork())
    collar = merge("StandCollar", [cyl("Collar", 0.03, 0.03, (0, 0, 0.015), segs=14, bevel=0.006, m=mat("Pink")),
                                   cyl("CollarLip", 0.036, 0.008, (0, 0, 0.004), segs=14, bevel=0.002, m=mat("Cream"))])
    gull = merge("Gull", build_gull())
    save("menu_booth", [booth, screen, fork, collar, gull])


if __name__ == "__main__":
    build()
