"""First-person viewmodels for the three energy weapons, with gloved arms.

Each weapon is modelled around its own origin (top of the grip), pointing
along +Y (Godot -Z, camera forward). Exported nodes follow one contract used
by the game (scripts/player/weapon_view.gd and weapon_cosmetics.gd):

    Shell          static body. Materials: "Shell" (main), "Trim" (panels), "Cell" (lights)
    Cell           the energy cell (moves during reloads)
    Slide / Pump   the weapon's other moving part
    Decal          emblem, hidden unless the decal reward is equipped
    ArmR / ArmL    gloved arms (dark glove, pink cuff)
    Muzzle         empty at the barrel tip

All moving parts share the weapon origin as their pivot, so the game can
animate them with simple offsets.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403


def mats():
    return dict(
        shell=mat("Shell", "#fff0d4", rough=0.42),
        trim=mat("Trim", "#6b35b8", rough=0.4),
        cell=mat("Cell", "#33f0ff", rough=0.3, emit=2.6),
        dark=mat("GunDark", "#241d3a", rough=0.5),
        decal=mat("Decal", "#ffd93b", rough=0.4),
    )


def arm(prefix, grip, toward, thumb_side=-1.0, underhand=False):
    """A chunky gloved fist at `grip` with a forearm leading off-screen toward `toward`."""
    glove = mat("Glove", "#2b2836", rough=0.7)
    cuff = mat("Cuff", "#ff3f9f", rough=0.5)
    sleeve = mat("Sleeve", "#1d1b26", rough=0.8)
    c = Vector(grip)
    d = (Vector(toward) - c).normalized()
    parts = [sphere(prefix + "Fist", 0.066, c, scale=(1.0, 1.1, 1.2), m=glove, segs=14, rings=10)]
    if underhand:
        # Cradling from below: fingers curl up the far side, thumb up the near side.
        for i in range(4):
            parts.append(box(f"{prefix}Finger{i}", (0.03, 0.03, 0.075), (c.x - thumb_side * 0.058, c.y - 0.05 + i * 0.034, c.z + 0.035),
                             bevel=0.012, m=glove))
        parts.append(box(prefix + "Thumb", (0.032, 0.05, 0.07), (c.x + thumb_side * 0.058, c.y + 0.01, c.z + 0.03), bevel=0.013, m=glove))
    else:
        # Wrapping a grip: four fingers stacked on the front, thumb on the inside.
        for i in range(4):
            parts.append(box(f"{prefix}Finger{i}", (0.1, 0.034, 0.03), (c.x, c.y + 0.058, c.z + 0.05 - i * 0.033),
                             bevel=0.012, m=glove))
        parts.append(box(prefix + "Thumb", (0.034, 0.075, 0.034), (c.x + thumb_side * 0.055, c.y + 0.03, c.z + 0.055),
                         rot=rad(25, 0, 0), bevel=0.013, m=glove))
    parts += [
        tube(prefix + "Wrist", [c + d * 0.02, c + d * 0.15], 0.052, m=glove, segs=10),
        tube(prefix + "Cuff", [c + d * 0.13, c + d * 0.215], 0.073, m=cuff, segs=12),
        tube(prefix + "Forearm", [c + d * 0.2, c + d * 0.85], 0.062, m=sleeve, segs=10, radius_end=0.085),
    ]
    return parts


def frame_sight(prefix, y, z, m_frame, m_base):
    """The hoop sight from the reference weapon."""
    return [
        box(prefix + "Base", (0.075, 0.06, 0.03), (0, y, z), bevel=0.01, m=m_base),
        box(prefix + "L", (0.016, 0.03, 0.07), (-0.042, y, z + 0.045), bevel=0.006, m=m_frame),
        box(prefix + "R", (0.016, 0.03, 0.07), (0.042, y, z + 0.045), bevel=0.006, m=m_frame),
        box(prefix + "Top", (0.1, 0.03, 0.016), (0, y, z + 0.085), bevel=0.006, m=m_frame),
    ]


def finish(name, groups, muzzle, slide_child_decal=False):
    exports = {}
    for key in ("Shell", "Cell", "Slide", "Pump", "ArmR", "ArmL"):
        if key in groups:
            exports[key] = merge(key, groups[key])
    decal_parent = exports.get("Slide") if slide_child_decal else None
    exports["Decal"] = merge("Decal", groups["Decal"], parent=decal_parent)
    exports["Muzzle"] = empty("Muzzle", muzzle)
    save(name, list(exports.values()))


def side_emblem(name, outline, x, y, z, m, depth=0.01):
    """Emblem on the weapon's left side (the side the player sees)."""
    return prism(name, outline, depth, (x, y, z), rot=rad(0, 0, -90), m=m)


def build_pulse_pistol():
    reset_scene()
    M = mats()
    grip_rot = rad(-14, 0, 0)
    shell = [
        box("Frame", (0.078, 0.27, 0.07), (0, 0.115, 0.0), bevel=0.02, m=M["trim"]),
        box("FramePanel", (0.084, 0.13, 0.036), (0, 0.15, -0.004), bevel=0.012, m=M["shell"]),
        box("Grip", (0.07, 0.092, 0.17), (0, -0.012, -0.1), rot=grip_rot, bevel=0.022, m=M["trim"]),
        box("GripPad", (0.076, 0.06, 0.11), (0, -0.016, -0.1), rot=grip_rot, bevel=0.015, m=M["dark"]),
        box("Guard", (0.022, 0.1, 0.014), (0, 0.075, -0.085), bevel=0.005, m=M["dark"]),
        box("GuardFront", (0.022, 0.014, 0.06), (0, 0.122, -0.06), bevel=0.005, m=M["dark"]),
        box("Trigger", (0.014, 0.014, 0.04), (0, 0.062, -0.055), rot=rad(15, 0, 0), bevel=0.004, m=M["cell"]),
        cyl("Barrel", 0.027, 0.06, (0, 0.27, 0.065), rot=rad(90, 0, 0), segs=12, bevel=0.006, m=M["dark"]),
        box("UnderLight", (0.03, 0.07, 0.022), (0, 0.2, -0.042), bevel=0.008, m=M["cell"]),
    ]
    slide = [
        box("SlideBody", (0.088, 0.3, 0.082), (0, 0.11, 0.07), bevel=0.026, segs=3, m=M["shell"]),
        box("SlideVent", (0.034, 0.13, 0.014), (0, 0.14, 0.113), bevel=0.005, m=M["cell"]),
        box("SlideRear", (0.092, 0.06, 0.088), (0, -0.015, 0.07), bevel=0.02, m=M["trim"]),
        box("SightRear", (0.05, 0.02, 0.022), (0, -0.02, 0.122), bevel=0.006, m=M["dark"]),
        box("SightFront", (0.014, 0.02, 0.022), (0, 0.235, 0.118), bevel=0.005, m=M["cell"]),
    ]
    for i in range(3):
        slide.append(box(f"SlideGroove{i}", (0.094, 0.012, 0.05), (0, 0.02 + i * 0.024, 0.07), bevel=0.004, m=M["dark"]))
    cell = [
        box("CellBody", (0.05, 0.066, 0.19), (0, -0.012, -0.115), rot=grip_rot, bevel=0.014, m=M["dark"]),
        box("CellBase", (0.078, 0.1, 0.03), (0, -0.035, -0.2), rot=grip_rot, bevel=0.012, m=M["cell"]),
    ]
    decal = [side_emblem("Emblem", star_outline(0.03), -0.048, 0.15, 0.072, M["decal"])]
    groups = dict(
        Shell=shell, Slide=slide, Cell=cell, Decal=decal,
        ArmR=arm("R", (0.0, -0.02, -0.105), (0.16, -0.62, -0.42), thumb_side=-1.0),
        ArmL=arm("L", (-0.03, 0.01, -0.175), (-0.42, -0.42, -0.52), thumb_side=-1.0, underhand=True),
    )
    finish("pulse_pistol", groups, (0, 0.31, 0.065), slide_child_decal=True)


def build_ion_carbine():
    reset_scene()
    M = mats()
    shell = [
        box("RearBlock", (0.15, 0.2, 0.2), (0, 0.0, 0.035), bevel=0.04, segs=3, m=M["trim"]),
        box("StockPad", (0.12, 0.06, 0.16), (0, -0.12, 0.03), bevel=0.03, m=M["dark"]),
        box("MidShell", (0.17, 0.3, 0.19), (0, 0.22, 0.035), bevel=0.055, segs=3, m=M["shell"]),
        box("MidRidge", (0.085, 0.27, 0.05), (0, 0.22, 0.14), bevel=0.02, m=M["shell"]),
        box("Cradle", (0.05, 0.25, 0.115), (-0.082, 0.22, 0.02), bevel=0.02, m=M["trim"]),
        box("FrontBlock", (0.18, 0.21, 0.21), (0, 0.455, 0.035), bevel=0.055, segs=3, m=M["trim"]),
        box("FrontWindow", (0.02, 0.11, 0.065), (-0.091, 0.455, 0.045), bevel=0.008, m=M["cell"]),
        box("FrontWindowTop", (0.1, 0.075, 0.02), (0, 0.46, 0.142), bevel=0.008, m=M["cell"]),
        box("FrontCheek", (0.19, 0.06, 0.12), (0, 0.37, 0.02), bevel=0.02, m=M["shell"]),
        cyl("MuzzleRing", 0.058, 0.035, (0, 0.572, 0.035), rot=rad(90, 0, 0), segs=14, bevel=0.008, m=M["shell"]),
        cyl("MuzzleTip", 0.042, 0.07, (0, 0.6, 0.035), rot=rad(90, 0, 0), segs=14, bevel=0.008, m=M["dark"]),
        box("Grip", (0.075, 0.095, 0.2), (0, -0.02, -0.14), rot=rad(-13, 0, 0), bevel=0.024, m=M["dark"]),
        box("Guard", (0.022, 0.12, 0.014), (0, 0.09, -0.11), bevel=0.005, m=M["dark"]),
        box("Trigger", (0.014, 0.014, 0.045), (0, 0.065, -0.085), rot=rad(15, 0, 0), bevel=0.004, m=M["cell"]),
        box("Foregrip", (0.1, 0.14, 0.075), (0, 0.27, -0.09), bevel=0.025, m=M["trim"]),
        box("ForegripPad", (0.106, 0.09, 0.04), (0, 0.27, -0.11), bevel=0.012, m=M["dark"]),
    ]
    shell += frame_sight("Sight", 0.0, 0.15, M["shell"], M["dark"])
    for i, (y, z) in enumerate(((0.1, 0.1), (0.34, 0.1), (0.1, -0.03), (0.34, -0.03))):
        shell.append(sphere(f"Bolt{i}", 0.012, (0.088, y, z), m=M["dark"], segs=8, rings=5))
    cell = [
        cyl("CellTube", 0.04, 0.19, (-0.112, 0.22, 0.03), rot=rad(90, 0, 0), segs=14, bevel=0.0, m=M["cell"]),
        sphere("CellCapA", 0.04, (-0.112, 0.125, 0.03), m=M["cell"], segs=14, rings=8),
        sphere("CellCapB", 0.04, (-0.112, 0.315, 0.03), m=M["cell"], segs=14, rings=8),
        box("CellClampA", (0.03, 0.022, 0.095), (-0.112, 0.15, 0.03), bevel=0.008, m=M["trim"]),
        box("CellClampB", (0.03, 0.022, 0.095), (-0.112, 0.29, 0.03), bevel=0.008, m=M["trim"]),
    ]
    bolt = [(-0.008, 0.045), (0.022, 0.045), (0.006, 0.008), (0.026, 0.008), (-0.014, -0.05), (-0.002, -0.008), (-0.024, -0.008)]
    decal = [side_emblem("Emblem", bolt, -0.079, 0.0, 0.05, M["decal"])]
    groups = dict(
        Shell=shell, Cell=cell, Decal=decal,
        ArmR=arm("R", (0.0, -0.03, -0.15), (0.17, -0.62, -0.44), thumb_side=-1.0),
        ArmL=arm("L", (0.0, 0.27, -0.165), (-0.5, -0.3, -0.56), thumb_side=-1.0, underhand=True),
    )
    finish("ion_carbine", groups, (0, 0.64, 0.035))


def build_scatter_blaster():
    reset_scene()
    M = mats()
    shell = [
        box("Body", (0.21, 0.27, 0.18), (0, 0.04, 0.03), bevel=0.05, segs=3, m=M["trim"]),
        box("TopPlate", (0.18, 0.2, 0.05), (0, 0.06, 0.125), bevel=0.02, m=M["shell"]),
        box("Stock", (0.15, 0.13, 0.14), (0, -0.14, 0.02), bevel=0.04, m=M["dark"]),
        box("Band", (0.25, 0.055, 0.15), (0, 0.44, 0.045), bevel=0.03, m=M["trim"]),
        box("BandRear", (0.24, 0.05, 0.14), (0, 0.2, 0.045), bevel=0.03, m=M["trim"]),
        box("Grip", (0.08, 0.1, 0.2), (0, -0.05, -0.13), rot=rad(-14, 0, 0), bevel=0.024, m=M["dark"]),
        box("Guard", (0.022, 0.11, 0.014), (0, 0.05, -0.1), bevel=0.005, m=M["dark"]),
        box("Trigger", (0.014, 0.014, 0.045), (0, 0.03, -0.075), rot=rad(15, 0, 0), bevel=0.004, m=M["cell"]),
        sphere("Bead", 0.016, (0, 0.47, 0.125), m=M["cell"], segs=8, rings=6),
        box("SideLight", (0.02, 0.12, 0.03), (-0.106, 0.04, 0.07), bevel=0.008, m=M["cell"]),
    ]
    for i, x in enumerate((-0.058, 0.058)):
        shell += [
            cyl(f"Barrel{i}", 0.056, 0.38, (x, 0.33, 0.045), rot=rad(90, 0, 0), segs=16, bevel=0.01, m=M["shell"]),
            cyl(f"MuzzleRing{i}", 0.064, 0.05, (x, 0.515, 0.045), rot=rad(90, 0, 0), segs=16, bevel=0.012, m=M["dark"]),
            cyl(f"Bore{i}", 0.04, 0.02, (x, 0.542, 0.045), rot=rad(90, 0, 0), segs=12, bevel=0.0, m=M["cell"]),
        ]
    pump = [
        box("PumpBody", (0.2, 0.17, 0.075), (0, 0.31, -0.05), bevel=0.028, m=M["shell"]),
    ]
    for i in range(4):
        pump.append(box(f"PumpRidge{i}", (0.206, 0.02, 0.05), (0, 0.255 + i * 0.037, -0.056), bevel=0.007, m=M["dark"]))
    cell = [
        cyl("Drum", 0.062, 0.15, (0, -0.03, 0.18), rot=rad(0, 90, 0), segs=16, bevel=0.012, m=M["cell"]),
        cyl("DrumCapA", 0.068, 0.03, (-0.085, -0.03, 0.18), rot=rad(0, 90, 0), segs=16, bevel=0.008, m=M["trim"]),
        cyl("DrumCapB", 0.068, 0.03, (0.085, -0.03, 0.18), rot=rad(0, 90, 0), segs=16, bevel=0.008, m=M["trim"]),
        box("DrumSeat", (0.12, 0.09, 0.04), (0, -0.03, 0.125), bevel=0.012, m=M["dark"]),
    ]
    teeth = [(-0.065, 0.022), (0.065, 0.022), (0.065, 0.0), (0.049, -0.028), (0.033, 0.0), (0.016, -0.028), (0.0, 0.0),
             (-0.016, -0.028), (-0.033, 0.0), (-0.049, -0.028), (-0.065, 0.0)]
    decal = [side_emblem("Emblem", teeth, -0.109, 0.06, -0.01, M["decal"])]
    groups = dict(
        Shell=shell, Pump=pump, Cell=cell, Decal=decal,
        ArmR=arm("R", (0.0, -0.06, -0.14), (0.17, -0.62, -0.44), thumb_side=-1.0),
        ArmL=arm("L", (0.0, 0.31, -0.125), (-0.5, -0.26, -0.56), thumb_side=-1.0, underhand=True),
    )
    finish("scatter_blaster", groups, (0, 0.58, 0.045))


if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for name, fn in (("pulse_pistol", build_pulse_pistol), ("ion_carbine", build_ion_carbine), ("scatter_blaster", build_scatter_blaster)):
        if not only or name in only:
            fn()
