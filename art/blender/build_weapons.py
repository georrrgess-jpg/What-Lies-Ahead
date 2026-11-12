"""First-person viewmodels for the three energy weapons, with gloved arms.

Each weapon is modelled around its own origin (top of the grip), pointing
along +Y (Godot -Z, camera forward). Exported nodes follow the contract used
by scripts/player/weapon_view.gd and scripts/player/weapon_cosmetics.gd:

  Materials   "Shell" (main colour), "Trim" (panels), "Cell" (energy glow),
              "GunDark" (metal), "Holo" (hologram glass, replaced in game)
  Static      Shell
  Animated    Cell, CellHolo, Slide, Hammer, Panel, Vents, Barrels, Pump,
              Drum, Capsules, CapsulesHolo   (only the ones a weapon has)
              Every animated part's origin is its pivot (hinge, axle, centre),
              so reloads are simple rotations/offsets in the part's own space.
  Arms        ArmR, ArmL (dark glove, pink cuff)
  Decal       emblem, hidden unless a decal is equipped
  Empties     Muzzle (barrel tip), SightPoint (eye line when aimed),
              EjectPoint (where spent cells fly from), VentPoint (steam origin)

*Holo parts are hidden copies of the energy cell; the game shows them with a
hologram shader while a new cell "prints" in during the reload.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403


def mats():
    return dict(
        shell=mat("Shell", "#f6dfae", rough=0.38),
        trim=mat("Trim", "#6b35b8", rough=0.36),
        cell=mat("Cell", "#33f0ff", rough=0.3, emit=2.6),
        dark=mat("GunDark", "#241d3a", rough=0.45, metal=0.35),
        steel=mat("GunSteel", "#8a86a3", rough=0.3, metal=0.75),
        pink=mat("GunPink", "#ff3f9f", rough=0.4),
        holo=mat("Holo", "#5ff4ff", rough=0.2, emit=1.5),
        decal=mat("Decal", "#ffd93b", rough=0.4),
    )


def arm(prefix, grip, toward, thumb_side=-1.0, underhand=False):
    """A chunky gloved fist at `grip` with a forearm leading off-screen toward `toward`."""
    glove = mat("Glove", "#2b2836", rough=0.7)
    cuff = mat("Cuff", "#ff3f9f", rough=0.5)
    sleeve = mat("Sleeve", "#1d1b26", rough=0.8)
    plate = mat("GlovePlate", "#4a4560", rough=0.45, metal=0.3)
    c = Vector(grip)
    d = (Vector(toward) - c).normalized()
    parts = [sphere(prefix + "Fist", 0.08, c, scale=(1.0, 1.1, 1.2), m=glove, segs=14, rings=10),
             sphere(prefix + "Knuckles", 0.05, (c.x, c.y + 0.05, c.z + 0.02), scale=(1.5, 0.8, 1.0), m=glove, segs=10, rings=6),
             # Armoured knuckle plate with a little status light.
             box(prefix + "KnucklePlate", (0.09, 0.03, 0.05), (c.x, c.y + 0.075, c.z + 0.03), bevel=0.012, m=plate)]
    if underhand:
        for i in range(4):
            parts.append(box(f"{prefix}Finger{i}", (0.03, 0.03, 0.075), (c.x - thumb_side * 0.058, c.y - 0.05 + i * 0.034, c.z + 0.035),
                             bevel=0.012, m=glove))
        parts.append(box(prefix + "Thumb", (0.032, 0.05, 0.07), (c.x + thumb_side * 0.058, c.y + 0.01, c.z + 0.03), bevel=0.013, m=glove))
    else:
        for i in range(4):
            parts.append(box(f"{prefix}Finger{i}", (0.1, 0.034, 0.03), (c.x, c.y + 0.058, c.z + 0.05 - i * 0.033),
                             bevel=0.012, m=glove))
        parts.append(box(prefix + "Thumb", (0.034, 0.075, 0.034), (c.x + thumb_side * 0.055, c.y + 0.03, c.z + 0.055),
                         rot=rad(25, 0, 0), bevel=0.013, m=glove))
    parts += [
        tube(prefix + "Wrist", [c + d * 0.02, c + d * 0.08], 0.066, m=glove, segs=12),
        tube(prefix + "Cuff", [c + d * 0.06, c + d * 0.19], 0.096, m=cuff, segs=14),
        tube(prefix + "CuffRim", [c + d * 0.185, c + d * 0.205], 0.09, m=glove, segs=14),
        tube(prefix + "CuffLight", [c + d * 0.11, c + d * 0.13], 0.099, m=mat("Cell"), segs=14),
        tube(prefix + "Forearm", [c + d * 0.2, c + d * 0.9], 0.078, m=sleeve, segs=12, radius_end=0.1),
    ]
    return parts


def side_profile(name, outline, width, loc, m, bevel=0.01):
    """Extrude a side-view outline [(along_barrel, height), ...] across X.

    Lets us draw chamfered slides and shrouds the way they read from the side.
    """
    ob = prism(name, outline, width, (0, 0, 0), m=m, bevel=bevel)
    # prism() puts outline u on X and extrudes along Y; turn it so u runs along Y.
    for v in ob.data.vertices:
        x, y, z = v.co
        v.co = Vector((-y, x, z))
    ob.location = loc
    return ob


def vent_slots(prefix, x, y0, y1, z, count, m_dark, m_glow, height=0.034, side=-1):
    """A row of slanted vent slots on a weapon side, each with a glow strip inside."""
    out = []
    for i in range(count):
        y = y0 + (y1 - y0) * (i + 0.5) / count
        out.append(box(f"{prefix}Slot{i}", (0.008, 0.014, height), (x, y, z), rot=rad(18, 0, 0), bevel=0.003, m=m_dark))
        out.append(box(f"{prefix}Glow{i}", (0.004, 0.006, height * 0.75), (x + side * 0.003, y, z), rot=rad(18, 0, 0), bevel=0.0, m=m_glow))
    return out


def screws(prefix, points, m):
    return [cyl(f"{prefix}{i}", 0.008, 0.01, p, rot=rad(0, 90, 0), segs=8, bevel=0.002, m=m) for i, p in enumerate(points)]


def frame_sight(prefix, y, z, m_frame, m_base, m_glow):
    """Hoop sight from the reference weapon, with a glowing front dot."""
    return [
        box(prefix + "Base", (0.075, 0.06, 0.03), (0, y, z), bevel=0.01, m=m_base),
        box(prefix + "L", (0.016, 0.03, 0.07), (-0.042, y, z + 0.045), bevel=0.006, m=m_frame),
        box(prefix + "R", (0.016, 0.03, 0.07), (0.042, y, z + 0.045), bevel=0.006, m=m_frame),
        box(prefix + "Top", (0.1, 0.03, 0.016), (0, y, z + 0.085), bevel=0.006, m=m_frame),
        sphere(prefix + "Dot", 0.007, (0, y + 0.012, z + 0.045), m=m_glow, segs=8, rings=5),
    ]


def side_emblem(name, outline, x, y, z, m, depth=0.01):
    """Emblem on the weapon's left side (the side the player sees)."""
    return prism(name, outline, depth, (x, y, z), rot=rad(0, 0, -90), m=m)


def holo_copy(parts, suffix="Holo"):
    """Duplicate parts with the hologram material (for the 'print-in' reload)."""
    out = []
    holo = mat("Holo")
    for ob in parts:
        dup = ob.copy()
        dup.data = ob.data.copy()
        dup.name = ob.name + suffix
        dup.data.materials.clear()
        dup.data.materials.append(holo)
        source_collection().objects.link(dup)
        out.append(dup)
    return out


def finish(name, groups, empties, decal_parent=None):
    """groups: {node_name: (parts, pivot, parent_name_or_None)}."""
    exports = {}
    for key, (parts, pivot, parent_name) in groups.items():
        if not parts:
            continue
        parent = exports.get(parent_name) if parent_name else None
        exports[key] = merge(key, parts, pivot=pivot, parent=parent)
    for key, (loc, parent_name) in empties.items():
        exports[key] = empty(key, loc, parent=exports.get(parent_name) if parent_name else None)
    save(name, list(exports.values()))


# ---------------------------------------------------------------------------
# Pulse Pistol
# ---------------------------------------------------------------------------

def build_pulse_pistol():
    reset_scene()
    M = mats()
    grip_rot = rad(-14, 0, 0)
    shell = [
        box("Frame", (0.078, 0.27, 0.07), (0, 0.115, 0.0), bevel=0.02, m=M["trim"]),
        box("FramePanel", (0.084, 0.13, 0.036), (0, 0.15, -0.004), bevel=0.012, m=M["shell"]),
        box("Rail", (0.05, 0.12, 0.018), (0, 0.2, -0.044), bevel=0.006, m=M["dark"]),
        box("Light", (0.044, 0.06, 0.03), (0, 0.235, -0.06), bevel=0.01, m=M["dark"]),
        cyl("LightLens", 0.012, 0.012, (0, 0.268, -0.06), rot=rad(90, 0, 0), segs=12, bevel=0.003, m=M["cell"]),
        box("Grip", (0.07, 0.092, 0.17), (0, -0.012, -0.1), rot=grip_rot, bevel=0.022, m=M["trim"]),
        box("GripPad", (0.076, 0.06, 0.11), (0, -0.016, -0.1), rot=grip_rot, bevel=0.015, m=M["dark"]),
        box("Guard", (0.022, 0.1, 0.014), (0, 0.075, -0.085), bevel=0.005, m=M["dark"]),
        box("GuardFront", (0.022, 0.014, 0.06), (0, 0.122, -0.06), bevel=0.005, m=M["dark"]),
        box("Trigger", (0.014, 0.014, 0.04), (0, 0.062, -0.055), rot=rad(15, 0, 0), bevel=0.004, m=M["cell"]),
        cyl("Shroud", 0.03, 0.07, (0, 0.27, 0.065), rot=rad(90, 0, 0), segs=14, bevel=0.006, m=M["dark"]),
        torus("Emitter", 0.026, 0.006, (0, 0.305, 0.065), rot=rad(90, 0, 0), m=M["cell"], major_segs=20, minor_segs=6),
        # Charge-coil window on the side the player sees: three glowing rings.
        box("CoilRecess", (0.01, 0.1, 0.04), (-0.041, 0.13, 0.0), bevel=0.006, m=M["dark"]),
        # Rear capacitor with three ammo pips facing the camera.
        box("Capacitor", (0.07, 0.03, 0.05), (0, -0.045, 0.02), bevel=0.012, m=M["dark"]),
    ]
    for i in range(3):
        shell.append(torus(f"Coil{i}", 0.016, 0.004, (-0.045, 0.1 + i * 0.03, 0.0), rot=rad(0, 90, 0), m=M["cell"], major_segs=14, minor_segs=5))
        shell.append(box(f"Pip{i}", (0.014, 0.008, 0.014), (-0.02 + i * 0.02, -0.062, 0.03), bevel=0.003, m=M["cell"]))
    for i in range(4):
        shell.append(box(f"GripRidge{i}", (0.078, 0.012, 0.008), (0, -0.04 + i * 0.002, -0.06 - i * 0.03), rot=grip_rot, bevel=0.002, m=M["dark"]))
    shell += screws("Screw", [(-0.04, 0.03, -0.01), (-0.04, 0.2, -0.01)], M["steel"])

    slide_outline = [(-0.045, 0.032), (0.258, 0.032), (0.258, 0.085), (0.23, 0.113), (-0.03, 0.113), (-0.048, 0.098)]
    slide = [
        side_profile("SlideBody", slide_outline, 0.088, (0, 0, 0), M["shell"], bevel=0.008),
        box("TopRib", (0.03, 0.25, 0.012), (0, 0.11, 0.118), bevel=0.004, m=M["trim"]),
        box("SightRear", (0.05, 0.02, 0.022), (0, -0.025, 0.124), bevel=0.006, m=M["dark"]),
        box("SightNotch", (0.014, 0.024, 0.014), (0, -0.025, 0.13), bevel=0.0, m=M["cell"]),
        box("SightFront", (0.012, 0.02, 0.022), (0, 0.235, 0.122), bevel=0.005, m=M["dark"]),
        sphere("SightFrontDot", 0.006, (0, 0.224, 0.131), m=M["cell"], segs=8, rings=5),
    ]
    slide += vent_slots("VentL", -0.045, 0.1, 0.22, 0.072, 4, M["dark"], M["cell"])
    slide += vent_slots("VentR", 0.045, 0.1, 0.22, 0.072, 4, M["dark"], M["cell"], side=1)
    for i in range(4):
        slide.append(box(f"Serration{i}", (0.09, 0.006, 0.05), (0, -0.03 + i * 0.012, 0.072), bevel=0.0, m=M["dark"]))

    hammer = [
        box("HammerBody", (0.024, 0.03, 0.03), (0, -0.06, 0.085), bevel=0.006, m=M["dark"]),
        sphere("HammerGlow", 0.008, (0, -0.072, 0.095), m=M["cell"], segs=8, rings=5),
    ]
    cell = [
        box("CellBody", (0.05, 0.066, 0.19), (0, -0.012, -0.115), rot=grip_rot, bevel=0.014, m=M["dark"]),
        box("CellBase", (0.078, 0.1, 0.03), (0, -0.035, -0.2), rot=grip_rot, bevel=0.012, m=M["cell"]),
        box("CellBand", (0.054, 0.07, 0.014), (0, -0.02, -0.15), rot=grip_rot, bevel=0.004, m=M["cell"]),
    ]
    cell_holo = holo_copy(cell)
    decal = [side_emblem("Emblem", star_outline(0.026), -0.048, 0.18, 0.072, M["decal"])]
    cell_pivot = (0, -0.025, -0.15)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "Slide": (slide, (0, 0, 0), None),
        "Hammer": (hammer, (0, -0.05, 0.075), None),
        "Cell": (cell, cell_pivot, None),
        "CellHolo": (cell_holo, cell_pivot, None),
        "Decal": (decal, (0, 0, 0), "Slide"),
        "ArmR": (arm("R", (0.0, -0.02, -0.105), (0.42, -0.5, -0.36), thumb_side=-1.0), (0, 0, 0), None),
        "ArmL": (arm("L", (-0.07, 0.0, -0.14), (-0.55, -0.32, -0.32), thumb_side=-1.0, underhand=True), (0, 0, 0), None),
    }
    empties = {
        "Muzzle": ((0, 0.315, 0.065), None),
        "SightPoint": ((0, -0.03, 0.134), None),
        "EjectPoint": ((0, -0.03, -0.24), None),
        "VentPoint": ((-0.05, 0.16, 0.08), None),
    }
    finish("pulse_pistol", groups, empties)


# ---------------------------------------------------------------------------
# Ion Carbine
# ---------------------------------------------------------------------------

def build_ion_carbine():
    reset_scene()
    M = mats()
    shell = [
        box("RearBlock", (0.15, 0.2, 0.2), (0, 0.0, 0.035), bevel=0.04, segs=3, m=M["trim"]),
        box("StockPad", (0.13, 0.06, 0.16), (0, -0.12, 0.03), bevel=0.035, m=M["shell"]),
        box("RearSlotFrame", (0.1, 0.02, 0.07), (0, -0.152, 0.05), bevel=0.012, m=M["trim"]),
        box("RearSlot", (0.078, 0.02, 0.042), (0, -0.158, 0.05), bevel=0.012, m=M["cell"]),
        box("MidShell", (0.17, 0.3, 0.19), (0, 0.22, 0.035), bevel=0.055, segs=3, m=M["shell"]),
        box("MidRidge", (0.085, 0.27, 0.05), (0, 0.22, 0.14), bevel=0.02, m=M["shell"]),
        # Cell chamber on the left: dark recess with five glowing coil rings.
        box("Chamber", (0.04, 0.24, 0.12), (-0.078, 0.22, 0.03), bevel=0.02, m=M["dark"]),
        box("FrontBlock", (0.18, 0.21, 0.21), (0, 0.455, 0.035), bevel=0.055, segs=3, m=M["trim"]),
        box("FrontWindow", (0.02, 0.11, 0.065), (-0.091, 0.455, 0.045), bevel=0.008, m=M["cell"]),
        box("FrontCheek", (0.19, 0.06, 0.12), (0, 0.37, 0.02), bevel=0.02, m=M["shell"]),
        cyl("Barrel", 0.034, 0.16, (0, 0.6, 0.035), rot=rad(90, 0, 0), segs=14, bevel=0.006, m=M["dark"]),
        cyl("Brake", 0.052, 0.07, (0, 0.69, 0.035), rot=rad(90, 0, 0), segs=12, bevel=0.012, m=M["shell"]),
        torus("Emitter", 0.034, 0.007, (0, 0.727, 0.035), rot=rad(90, 0, 0), m=M["cell"], major_segs=20, minor_segs=6),
        box("Grip", (0.075, 0.095, 0.2), (0, -0.02, -0.14), rot=rad(-13, 0, 0), bevel=0.024, m=M["dark"]),
        box("Guard", (0.022, 0.12, 0.014), (0, 0.09, -0.11), bevel=0.005, m=M["dark"]),
        box("Trigger", (0.014, 0.014, 0.045), (0, 0.065, -0.085), rot=rad(15, 0, 0), bevel=0.004, m=M["cell"]),
        box("Foregrip", (0.1, 0.14, 0.075), (0, 0.27, -0.09), bevel=0.025, m=M["trim"]),
        box("ForegripPad", (0.106, 0.09, 0.04), (0, 0.27, -0.11), bevel=0.012, m=M["dark"]),
        # Top rail and holographic sight.
        box("TopRail", (0.05, 0.32, 0.02), (0, 0.2, 0.17), bevel=0.005, m=M["dark"]),
        box("HoloBase", (0.07, 0.08, 0.025), (0, 0.06, 0.19), bevel=0.008, m=M["dark"]),
        box("HoloFrameL", (0.012, 0.03, 0.075), (-0.04, 0.08, 0.235), bevel=0.004, m=M["trim"]),
        box("HoloFrameR", (0.012, 0.03, 0.075), (0.04, 0.08, 0.235), bevel=0.004, m=M["trim"]),
        box("HoloFrameT", (0.092, 0.03, 0.012), (0, 0.08, 0.275), bevel=0.004, m=M["trim"]),
        box("HoloPane", (0.068, 0.004, 0.058), (0, 0.085, 0.234), bevel=0.0, m=M["holo"]),
        sphere("HoloDot", 0.006, (0, 0.083, 0.234), m=M["pink"], segs=8, rings=5),
        # Cables along the right side.
        tube("CableR", [(0.08, -0.05, 0.08), (0.1, 0.12, 0.1), (0.1, 0.3, 0.1), (0.085, 0.42, 0.08)], 0.011, m=M["pink"], segs=6),
        tube("CableL", [(-0.07, -0.05, -0.04), (-0.09, 0.08, -0.06), (-0.085, 0.36, -0.05)], 0.009, m=M["cell"], segs=6),
    ]
    for i in range(5):
        shell.append(torus(f"Coil{i}", 0.046, 0.006, (-0.09, 0.15 + i * 0.035, 0.03), rot=rad(90, 0, 0), m=M["cell"], major_segs=16, minor_segs=5))
        shell.append(cyl(f"Fin{i}", 0.048, 0.008, (0, 0.53 + i * 0.022, 0.035), rot=rad(90, 0, 0), segs=14, bevel=0.002, m=M["steel"]))
    for i in range(8):
        shell.append(box(f"RailNotch{i}", (0.054, 0.008, 0.008), (0, 0.06 + i * 0.038, 0.182), bevel=0.0, m=M["steel"]))
    shell += screws("Screw", [(0.088, 0.1, 0.1), (0.088, 0.34, 0.1), (0.088, 0.1, -0.03), (0.088, 0.34, -0.03)], M["steel"])

    # Hinged cage over the cell (hinge along the bottom edge).
    hinge = (-0.1, 0.22, -0.035)
    panel = [box("PanelSpine", (0.012, 0.26, 0.02), (-0.105, 0.22, -0.03), bevel=0.005, m=M["trim"])]
    for i in range(3):
        panel.append(box(f"PanelBar{i}", (0.012, 0.024, 0.13), (-0.108, 0.13 + i * 0.09, 0.03), bevel=0.005, m=M["trim"]))
    panel.append(box("PanelTop", (0.012, 0.26, 0.018), (-0.106, 0.22, 0.095), bevel=0.005, m=M["trim"]))
    panel.append(box("PanelLight", (0.004, 0.2, 0.006), (-0.114, 0.22, 0.095), bevel=0.0, m=M["cell"]))

    vents = []
    for i in range(4):
        vents.append(box(f"VentSlat{i}", (0.06, 0.02, 0.008), (0.03, 0.17 + i * 0.03, 0.137), bevel=0.003, m=M["dark"]))
    cell_parts = [
        cyl("CellTube", 0.036, 0.19, (-0.09, 0.22, 0.03), rot=rad(90, 0, 0), segs=14, bevel=0.0, m=M["cell"]),
        sphere("CellCapA", 0.036, (-0.09, 0.125, 0.03), m=M["cell"], segs=14, rings=8),
        sphere("CellCapB", 0.036, (-0.09, 0.315, 0.03), m=M["cell"], segs=14, rings=8),
        cyl("CellRingA", 0.039, 0.016, (-0.09, 0.16, 0.03), rot=rad(90, 0, 0), segs=14, bevel=0.003, m=M["dark"]),
        cyl("CellRingB", 0.039, 0.016, (-0.09, 0.28, 0.03), rot=rad(90, 0, 0), segs=14, bevel=0.003, m=M["dark"]),
    ]
    cell_holo = holo_copy(cell_parts)
    bolt = [(-0.008, 0.045), (0.022, 0.045), (0.006, 0.008), (0.026, 0.008), (-0.014, -0.05), (-0.002, -0.008), (-0.024, -0.008)]
    decal = [side_emblem("Emblem", bolt, -0.077, 0.0, 0.05, M["decal"])]
    cell_pivot = (-0.09, 0.22, 0.03)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "Panel": (panel, hinge, None),
        "Vents": (vents, (0.0, 0.215, 0.137), None),
        "Cell": (cell_parts, cell_pivot, None),
        "CellHolo": (cell_holo, cell_pivot, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm("R", (0.0, -0.03, -0.15), (0.17, -0.62, -0.44), thumb_side=-1.0), (0, 0, 0), None),
        "ArmL": (arm("L", (-0.02, 0.27, -0.16), (-0.52, -0.16, -0.46), thumb_side=-1.0, underhand=True), (0, 0, 0), None),
    }
    empties = {
        "Muzzle": ((0, 0.74, 0.035), None),
        "SightPoint": ((0, 0.04, 0.234), None),
        "EjectPoint": ((-0.16, 0.22, 0.03), None),
        "VentPoint": ((0.03, 0.215, 0.16), None),
    }
    finish("ion_carbine", groups, empties)


# ---------------------------------------------------------------------------
# Scatter Blaster
# ---------------------------------------------------------------------------

def build_scatter_blaster():
    reset_scene()
    M = mats()
    hinge = (0, 0.215, -0.01)
    shell = [
        box("Body", (0.21, 0.27, 0.18), (0, 0.04, 0.03), bevel=0.05, segs=3, m=M["trim"]),
        box("TopPlate", (0.18, 0.2, 0.05), (0, 0.06, 0.125), bevel=0.02, m=M["shell"]),
        box("Stock", (0.15, 0.13, 0.14), (0, -0.14, 0.02), bevel=0.04, m=M["shell"]),
        box("RearSlotFrame", (0.11, 0.02, 0.07), (0, -0.207, 0.035), bevel=0.012, m=M["trim"]),
        box("RearSlot", (0.085, 0.02, 0.042), (0, -0.213, 0.035), bevel=0.012, m=M["cell"]),
        box("Grip", (0.08, 0.1, 0.2), (0, -0.05, -0.13), rot=rad(-14, 0, 0), bevel=0.024, m=M["dark"]),
        box("Guard", (0.022, 0.11, 0.014), (0, 0.05, -0.1), bevel=0.005, m=M["dark"]),
        box("Trigger", (0.014, 0.014, 0.045), (0, 0.03, -0.075), rot=rad(15, 0, 0), bevel=0.004, m=M["cell"]),
        box("SideLight", (0.02, 0.12, 0.03), (-0.106, 0.04, 0.07), bevel=0.008, m=M["cell"]),
        cyl("HingePin", 0.022, 0.24, hinge, rot=rad(0, 90, 0), segs=14, bevel=0.005, m=M["steel"]),
        box("Breech", (0.2, 0.03, 0.14), (0, 0.19, 0.04), bevel=0.02, m=M["dark"]),
        box("DrumSeat", (0.12, 0.09, 0.04), (0, -0.03, 0.105), bevel=0.012, m=M["dark"]),
        box("ShieldL", (0.012, 0.18, 0.1), (-0.11, 0.06, 0.03), bevel=0.006, m=M["shell"]),
        box("ShieldR", (0.012, 0.18, 0.1), (0.11, 0.06, 0.03), bevel=0.006, m=M["shell"]),
    ]
    for i in range(3):
        shell.append(box(f"ShieldSlit{i}", (0.006, 0.03, 0.06), (-0.118, 0.01 + i * 0.05, 0.03), bevel=0.002, m=M["cell"]))
    shell += screws("Screw", [(0.106, -0.04, 0.09), (0.106, 0.12, 0.09)], M["steel"])

    barrels = []
    for i, x in enumerate((-0.058, 0.058)):
        barrels += [
            cyl(f"Barrel{i}", 0.056, 0.36, (x, 0.39, 0.045), rot=rad(90, 0, 0), segs=16, bevel=0.01, m=M["shell"]),
            cyl(f"MuzzleRing{i}", 0.064, 0.05, (x, 0.565, 0.045), rot=rad(90, 0, 0), segs=16, bevel=0.012, m=M["dark"]),
            cyl(f"Bore{i}", 0.04, 0.02, (x, 0.592, 0.045), rot=rad(90, 0, 0), segs=12, bevel=0.0, m=M["cell"]),
            tube(f"PlasmaTube{i}", [(x * 1.95, 0.25, 0.03), (x * 1.95, 0.53, 0.03)], 0.01, m=M["cell"], segs=6),
        ]
        for k in range(3):
            barrels.append(box(f"HeatVent{i}{k}", (0.02, 0.03, 0.01), (x, 0.32 + k * 0.07, 0.1), bevel=0.003, m=M["dark"]))
    barrels += [
        box("Band", (0.25, 0.055, 0.15), (0, 0.49, 0.045), bevel=0.03, m=M["trim"]),
        box("BandRear", (0.24, 0.05, 0.14), (0, 0.25, 0.045), bevel=0.03, m=M["trim"]),
        sphere("Bead", 0.016, (0, 0.52, 0.125), m=M["cell"], segs=8, rings=6),
        box("RibTop", (0.03, 0.3, 0.014), (0, 0.39, 0.105), bevel=0.004, m=M["dark"]),
    ]
    pump = [box("PumpBody", (0.2, 0.17, 0.075), (0, 0.36, -0.05), bevel=0.028, m=M["shell"])]
    for i in range(4):
        pump.append(box(f"PumpRidge{i}", (0.206, 0.02, 0.05), (0, 0.305 + i * 0.037, -0.056), bevel=0.007, m=M["dark"]))
    drum_pivot = (0, -0.03, 0.165)
    drum = [
        cyl("DrumBody", 0.055, 0.14, drum_pivot, rot=rad(0, 90, 0), segs=16, bevel=0.012, m=M["cell"]),
        cyl("DrumCapA", 0.061, 0.03, (-0.08, -0.03, 0.165), rot=rad(0, 90, 0), segs=16, bevel=0.008, m=M["trim"]),
        cyl("DrumCapB", 0.061, 0.03, (0.08, -0.03, 0.165), rot=rad(0, 90, 0), segs=16, bevel=0.008, m=M["trim"]),
    ]
    for k in range(6):
        a = math.tau * k / 6
        drum.append(box(f"DrumRib{k}", (0.13, 0.012, 0.012), (0, -0.03 + math.cos(a) * 0.056, 0.165 + math.sin(a) * 0.056),
                        rot=(a, 0, 0), bevel=0.003, m=M["trim"]))
    capsule_pivot = (0, 0.2, 0.045)
    capsules = []
    for i, x in enumerate((-0.058, 0.058)):
        capsules += [
            cyl(f"Capsule{i}", 0.034, 0.07, (x, 0.2, 0.045), rot=rad(90, 0, 0), segs=12, bevel=0.01, m=M["cell"]),
            cyl(f"CapsuleRim{i}", 0.04, 0.014, (x, 0.17, 0.045), rot=rad(90, 0, 0), segs=12, bevel=0.003, m=M["steel"]),
        ]
    capsules_holo = holo_copy(capsules)
    teeth = [(-0.065, 0.022), (0.065, 0.022), (0.065, 0.0), (0.049, -0.028), (0.033, 0.0), (0.016, -0.028), (0.0, 0.0),
             (-0.016, -0.028), (-0.033, 0.0), (-0.049, -0.028), (-0.065, 0.0)]
    decal = [side_emblem("Emblem", teeth, -0.117, 0.06, -0.01, M["decal"])]
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "Barrels": (barrels, hinge, None),
        "Pump": (pump, (0, 0.36, -0.05), "Barrels"),
        "Drum": (drum, drum_pivot, None),
        "Capsules": (capsules, capsule_pivot, None),
        "CapsulesHolo": (capsules_holo, capsule_pivot, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm("R", (0.0, -0.06, -0.14), (0.17, -0.62, -0.44), thumb_side=-1.0), (0, 0, 0), None),
        "ArmL": (arm("L", (-0.02, 0.36, -0.12), (-0.52, -0.12, -0.46), thumb_side=-1.0, underhand=True), (0, 0, 0), "Barrels"),
    }
    empties = {
        "Muzzle": ((0, 0.6, 0.045), "Barrels"),
        "SightPoint": ((0, 0.05, 0.155), None),
        "EjectPoint": ((0, 0.2, 0.1), None),
        "VentPoint": ((0, 0.39, 0.12), "Barrels"),
    }
    finish("scatter_blaster", groups, empties)


if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for name, fn in (("pulse_pistol", build_pulse_pistol), ("ion_carbine", build_ion_carbine), ("scatter_blaster", build_scatter_blaster)):
        if not only or name in only:
            fn()
