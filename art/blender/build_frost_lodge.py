"""Frostpeak Resort buildings: the Summit Lodge (A-frame hall, kitchen wing and
the roofed terrace pavilion) and the maintenance shed.

    frost_lodge.glb   origin = front centre of the A-frame at ground level
                      (world (-5, 0, -24) in summit_lodge.tscn); front faces -Y.
                      The terrace deck itself is built in Godot (1.4 m up).
    frost_shed.glb    origin = centre of the shed floor; roller door faces -Y.

    python art/blender/build_frost_lodge.py [lodge] [shed]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from frost_common import *  # noqa: F401,F403

FLOOR = 1.4            # terrace / lodge floor height
HALF_W = 11.0          # A-frame half width at the base
RIDGE = 15.2           # ridge height
DEPTH = 14.0           # hall depth (Y)


def slab(name, a, b, y0, y1, thick, m, bevel=0.08):
    """Box spanning a -> b in the XZ plane (its underside on that line), Y from y0 to y1."""
    ax, az = a
    bx, bz = b
    length = math.hypot(bx - ax, bz - az)
    ang = math.atan2(bz - az, bx - ax)
    nx, nz = -math.sin(ang), math.cos(ang)
    if nz < 0:
        nx, nz = -nx, -nz
    centre = ((ax + bx) / 2 + nx * thick / 2, (y0 + y1) / 2, (az + bz) / 2 + nz * thick / 2)
    return box(name, (length, y1 - y0, thick), centre, rot=(0, -ang, 0), bevel=bevel, m=m)


def gable_top(x):
    """Height of the glass gable's top edge at x."""
    return FLOOR + (HALF_W - 0.4 - abs(x)) / (HALF_W - 0.4) * (RIDGE - 0.8 - FLOOR)


def a_frame():
    roof, trim, snow = fmat("Roof", rough=0.7), fmat("RoofTrim", rough=0.7), snow_mat()
    timber, dark = fmat("Timber"), fmat("TimberDark")
    stone = fmat("Stone", rough=0.85)
    glass = glass_mat()
    amber = fglow("FrostBulbAmber", "#ffc46b", 3.0)
    parts = [box("Plinth", (2 * HALF_W + 7.2, DEPTH + 0.4, FLOOR), (3.3, DEPTH / 2 + 0.4, FLOOR / 2), bevel=0.1, m=stone)]
    eave = (HALF_W + 0.7, FLOOR + 0.1)
    apex = (0.0, RIDGE)
    for side, sx in (("L", -1), ("R", 1)):
        a = (sx * eave[0], eave[1])
        parts.append(slab(f"Roof{side}", a, apex, -0.4, DEPTH + 0.6, 0.55, roof))
        # Snow blanket on the roof plane, held back from the eave a little.
        sa = (sx * (HALF_W + 0.2), FLOOR + 0.95)
        parts.append(slab(f"RoofSnow{side}", sa, (sx * 0.4, RIDGE + 0.1), -0.5, DEPTH + 0.7, 0.32, snow, bevel=0.14))
        # Heavy fascia boards along the front edges of the A.
        parts.append(slab(f"Fascia{side}", (sx * (HALF_W + 0.5), FLOOR - 0.2), (0.0, RIDGE + 0.25), -0.75, -0.3, 0.42, dark))
        # Lumpy snow sliding off the eaves.
        for i in range(5):
            y = 1.0 + i * 3.0
            parts.append(sphere(f"EaveSnow{side}{i}", 0.45, (sx * (HALF_W + 0.85), y, FLOOR + 0.55), scale=(1.0, 2.6, 0.75), m=snow, segs=10, rings=6))
        parts += icicles(f"Icicle{side}", (sx * (HALF_W + 0.4), -0.6, FLOOR + 0.6), (sx * 2.2, -0.6, RIDGE - 1.5), 9, 0.7, seed=4 + sx)
    parts.append(sphere("RidgeSnow", 0.6, (0, DEPTH / 2, RIDGE + 0.5), scale=(1.0, DEPTH / 1.1, 0.55), m=snow, segs=10, rings=6))
    # Glass gable with a timber grid, set just behind the roof's front edge.
    outline = [(-(HALF_W - 0.4), FLOOR), (HALF_W - 0.4, FLOOR), (0.0, RIDGE - 0.8)]
    # The game swaps this surface for an interior-mapped room (frost_lodge_interior.gdshader).
    parts.append(prism("Gable", outline, 0.16, (0, 0.6, 0), m=mat("FrostGableGlass", FROST["Glow"], rough=0.25, emit=1.6)))
    for i, x in enumerate((-8.0, -5.4, -2.7, 2.7, 5.4, 8.0)):
        top = gable_top(x)
        parts.append(box(f"MullionV{i}", (0.22, 0.3, top - FLOOR), (x, 0.45, (top + FLOOR) / 2), bevel=0.03, m=timber))
    for j, z in enumerate((4.6, 7.6, 10.6)):
        half = (HALF_W - 0.4) * (1.0 - (z - FLOOR) / (RIDGE - 0.8 - FLOOR))
        parts.append(box(f"MullionH{j}", (2 * half, 0.3, 0.22), (0, 0.45, z), bevel=0.03, m=timber))
    parts.append(box("MullionC", (0.3, 0.32, RIDGE - 0.8 - 4.6), (0, 0.44, (RIDGE - 0.8 + 4.6) / 2), bevel=0.03, m=timber))
    # Front doors and their canopy.
    parts += [
        box("DoorFrame", (3.2, 0.5, 2.9), (0, 0.42, FLOOR + 1.45), bevel=0.05, m=dark),
        box("DoorL", (1.35, 0.4, 2.5), (-0.72, 0.36, FLOOR + 1.25), bevel=0.04, m=timber),
        box("DoorR", (1.35, 0.4, 2.5), (0.72, 0.36, FLOOR + 1.25), bevel=0.04, m=timber),
        box("DoorLightL", (0.8, 0.42, 1.2), (-0.72, 0.34, FLOOR + 1.6), bevel=0.02, m=glass),
        box("DoorLightR", (0.8, 0.42, 1.2), (0.72, 0.34, FLOOR + 1.6), bevel=0.02, m=glass),
    ]
    # Mezzanine balcony across the glass.
    parts += [
        box("Balcony", (12.0, 1.6, 0.3), (0, -0.2, 6.2), bevel=0.06, m=timber),
        box("BalconyRail", (12.0, 0.14, 0.12), (0, -0.95, 7.25), bevel=0.04, m=dark),
    ]
    for i in range(13):
        parts.append(box(f"Baluster{i}", (0.08, 0.08, 0.9), (-5.8 + i * 0.966, -0.95, 6.8), bevel=0.0, m=dark))
    parts += snow_cap("BalconySnow", (11.8, 0.22, 0.08), (0, -0.95, 7.31), drips=10, seed=7)
    for i, x in enumerate((-5.6, 5.6)):
        parts.append(box(f"BalconyBracket{i}", (0.2, 1.2, 0.2), (x, -0.2, 5.75), rot=rad(35, 0, 0), bevel=0.03, m=dark))
    # Collar tie and the carved snowflake emblem near the apex.
    parts.append(box("Collar", (6.4, 0.4, 0.4), (0, -0.55, 11.0), bevel=0.06, m=dark))
    parts.append(star("Emblem", 0.9, 0.18, (0, -0.7, 12.7), m=mat("FrostEmblem", "#bff4ff", rough=0.3, emit=1.6), inner=0.35))
    parts.append(cyl("EmblemDisc", 1.15, 0.14, (0, -0.6, 12.7), rot=rad(90, 0, 0), segs=24, bevel=0.04, m=fmat("Navy")))
    # Stone chimney through the east roof plane.
    parts += [
        box("Chimney", (1.6, 1.6, 9.0), (5.4, 9.0, 12.0), bevel=0.08, m=stone),
        box("ChimneyCap", (2.0, 2.0, 0.3), (5.4, 9.0, 16.6), bevel=0.06, m=fmat("StoneDark")),
    ]
    parts += snow_cap("ChimneySnow", (1.9, 1.9, 0.2), (5.4, 9.0, 16.75), drips=4, seed=8)
    # Bulbs tracing the A.
    for side, sx in (("L", -1), ("R", 1)):
        parts += bulb_row(f"ABulb{side}", (sx * (HALF_W + 0.1), -0.82, FLOOR + 0.6), (sx * 0.5, -0.82, RIDGE - 0.2), 18, 0.09, amber)
    return parts


def kitchen_wing():
    """Lower wing east of the hall (x 11..17.5) with the open kitchen doorway."""
    logs, dark = fmat("TimberLight"), fmat("TimberDark")
    roof, snow = fmat("Roof", rough=0.7), snow_mat()
    glass = glass_mat()
    x0, x1, y0, y1 = 11.0, 17.5, 0.6, 10.0
    top = 6.2
    cx = (x0 + x1) / 2
    parts = [
        box("WingBack", (x1 - x0, 0.4, top - FLOOR), (cx, y1, (top + FLOOR) / 2), bevel=0.05, m=logs),
        box("WingSide", (0.4, y1 - y0, top - FLOOR), (x1, (y0 + y1) / 2, (top + FLOOR) / 2), bevel=0.05, m=logs),
        # Front wall in three pieces around the doorway (x 12.5..14.5, up to 3.8).
        box("WingFrontA", (1.5, 0.4, top - FLOOR), (11.75, y0, (top + FLOOR) / 2), bevel=0.04, m=logs),
        box("WingFrontB", (3.0, 0.4, top - FLOOR), (16.0, y0, (top + FLOOR) / 2), bevel=0.04, m=logs),
        box("WingLintel", (2.0, 0.4, top - 3.8), (13.5, y0, (top + 3.8) / 2), bevel=0.04, m=logs),
        box("DoorJambL", (0.2, 0.5, 2.5), (12.4, y0 - 0.05, FLOOR + 1.25), bevel=0.03, m=dark),
        box("DoorJambR", (0.2, 0.5, 2.5), (14.6, y0 - 0.05, FLOOR + 1.25), bevel=0.03, m=dark),
        box("DoorHead", (2.6, 0.5, 0.2), (13.5, y0 - 0.05, 3.85), bevel=0.03, m=dark),
        # The door, swung open against the wall.
        box("DoorLeaf", (0.12, 1.9, 2.3), (14.75, y0 - 1.0, FLOOR + 1.17), bevel=0.03, m=fmat("Red", rough=0.5)),
        box("DoorPane", (0.14, 0.9, 0.7), (14.75, y0 - 1.0, FLOOR + 1.75), bevel=0.02, m=glass),
        # Warm kitchen glimpsed through the door.
        box("KitchenBackWall", (4.2, 0.2, 3.0), (13.5, 4.3, FLOOR + 1.5), bevel=0.0, m=fglow("FrostKitchenGlow", "#ffb062", 1.6)),
        box("KitchenShelf", (3.0, 0.4, 0.1), (13.5, 4.0, FLOOR + 1.8), bevel=0.02, m=dark),
        box("KitchenCounter", (3.2, 0.7, 1.0), (13.5, 3.9, FLOOR + 0.5), bevel=0.04, m=fmat("Steel", metal=0.6, rough=0.3)),
        box("KitchenFloor", (4.2, 3.8, 0.05), (13.5, 2.5, FLOOR + 0.02), bevel=0.0, m=mat("FrostTile", "#7a6a8e")),
        box("KitchenCeiling", (4.2, 3.8, 0.1), (13.5, 2.5, FLOOR + 2.9), bevel=0.0, m=dark),
        box("KitchenSideW", (0.2, 3.8, 3.0), (11.5, 2.5, FLOOR + 1.5), bevel=0.0, m=logs),
        box("KitchenSideE", (0.2, 3.8, 3.0), (15.5, 2.5, FLOOR + 1.5), bevel=0.0, m=logs),
        # Sign and lamp over the door.
        box("SignBoard", (2.2, 0.12, 0.5), (13.5, y0 - 0.26, 4.35), bevel=0.04, m=fmat("Navy")),
        text("SignText", "KITCHEN", 0.3, 0.03, (13.5, y0 - 0.34, 4.35), m=fmat("White")),
        bulb("DoorLamp", 0.14, (13.5, y0 - 0.4, 4.8), fglow("FrostLantern", "#ffc46b", 3.2)),
    ]
    parts += window("WingWin", 1.4, 1.2, (16.1, y0 - 0.22, 3.2), mullions=(2, 2))
    # Log banding on the walls.
    for j in range(7):
        z = FLOOR + 0.4 + j * 0.65
        parts.append(box(f"LogBandSide{j}", (0.5, y1 - y0, 0.12), (x1 + 0.02, (y0 + y1) / 2, z), bevel=0.05, m=dark))
    # Shed roof sloping down to the front.
    parts.append(slab("WingRoof", (x0 - 0.2, top + 0.6), (x1 + 0.6, top + 0.6), -0.9, y1 + 0.5, 0.4, roof))
    parts += snow_cap("WingSnow", (x1 - x0 + 0.6, y1 - y0 + 1.2, 0.35), (cx + 0.2, (y0 + y1) / 2 - 0.4, top + 1.0), drips=8, seed=9)
    parts += icicles("WingIcicle", (x0 + 0.2, -0.95, top + 0.55), (x1 + 0.4, -0.95, top + 0.55), 10, 0.6, seed=11)
    parts += [
        box("Vent", (0.8, 0.8, 1.4), (15.6, 6.5, top + 1.5), bevel=0.06, m=fmat("Steel", metal=0.6, rough=0.3)),
        sphere("VentSnow", 0.5, (15.6, 6.5, top + 2.25), scale=(1, 1, 0.4), m=snow, segs=8, rings=4),
    ]
    return parts


def pavilion():
    """Roofed half of the terrace (x -11..2, y -6.6..-0.5) with pendant lanterns and a glass windbreak."""
    roof, snow = fmat("Roof", rough=0.7), snow_mat()
    timber, dark = fmat("Timber"), fmat("TimberDark")
    lantern = fglow("FrostLantern", "#ffc46b", 3.2)
    x0, x1, yf, yb = -11.0, 2.0, -6.6, -0.5
    eave, ridge = FLOOR + 3.5, FLOOR + 5.2
    cx = (x0 + x1) / 2
    yc = (yf + yb) / 2
    parts = []
    for i, x in enumerate((-10.6, -6.2, -1.8, 1.8)):
        parts += [
            box(f"PostF{i}", (0.34, 0.34, eave - FLOOR), (x, yf + 0.2, (eave + FLOOR) / 2), bevel=0.05, m=timber),
            box(f"PostFBase{i}", (0.5, 0.5, 0.3), (x, yf + 0.2, FLOOR + 0.15), bevel=0.05, m=dark),
            box(f"BraceF{i}", (0.16, 0.9, 0.16), (x, yf + 0.6, eave - 0.35), rot=rad(-45, 0, 0), bevel=0.02, m=dark),
        ]
    for i, x in enumerate((-10.6, 1.8)):
        parts.append(box(f"PostB{i}", (0.34, 0.34, eave - FLOOR), (x, yb - 0.2, (eave + FLOOR) / 2), bevel=0.05, m=timber))
    parts += [
        box("BeamF", (x1 - x0 + 0.4, 0.36, 0.36), (cx, yf + 0.2, eave + 0.1), bevel=0.05, m=dark),
        box("BeamB", (x1 - x0 + 0.4, 0.36, 0.36), (cx, yb - 0.2, eave + 0.1), bevel=0.05, m=dark),
        box("RidgeBeam", (x1 - x0 + 0.6, 0.3, 0.3), (cx, yc, ridge - 0.1), bevel=0.05, m=dark),
    ]
    # Gable roof (ridge along X).
    for side, (ya, yb2) in (("F", (yf - 0.7, yc)), ("B", (yb + 0.5, yc))):
        sgn = -1 if side == "F" else 1
        length = math.hypot(yc - ya, ridge - eave)
        ang = math.atan2(ridge - eave, abs(yc - ya))
        centre = (cx, (ya + yc) / 2, (eave + ridge) / 2 + 0.25)
        parts.append(box(f"Roof{side}", (x1 - x0 + 1.0, length, 0.3), centre, rot=(sgn * -ang, 0, 0), bevel=0.06, m=roof))
        parts.append(box(f"RoofSnow{side}", (x1 - x0 + 0.8, length - 0.4, 0.28), (cx, (ya + yc) / 2 + sgn * 0.1, (eave + ridge) / 2 + 0.5),
                         rot=(sgn * -ang, 0, 0), bevel=0.12, m=snow))
    parts += icicles("PavIcicle", (x0 - 0.2, yf - 0.75, eave + 0.05), (x1 + 0.2, yf - 0.75, eave + 0.05), 16, 0.55, seed=13)
    parts += bulb_row("PavBulb", (x0 - 0.2, yf - 0.85, eave - 0.05), (x1 + 0.2, yf - 0.85, eave - 0.05), 16, 0.08, lantern)
    for i, x in enumerate((-8.4, -4.0, 0.0)):
        parts += [
            cyl(f"PendantCord{i}", 0.015, 0.9, (x, yc, eave - 0.1), segs=4, bevel=0.0, m=dark),
            cyl(f"PendantShade{i}", 0.3, 0.25, (x, yc, eave - 0.6), segs=12, bevel=0.02, m=dark, radius_top=0.1),
            bulb(f"Pendant{i}", 0.16, (x, yc, eave - 0.8), lantern),
        ]
    # Glass windbreak on the west end.
    frost_glass = mat("FrostWindbreak", "#cfe6ff", rough=0.15, emit=0.35)
    parts += [
        box("WindbreakGlass", (0.08, yb - yf - 0.6, 2.0), (x0 + 0.2, yc, FLOOR + 1.2), bevel=0.0, m=frost_glass),
        box("WindbreakTop", (0.2, yb - yf - 0.4, 0.14), (x0 + 0.2, yc, FLOOR + 2.27), bevel=0.04, m=dark),
        box("WindbreakBottom", (0.2, yb - yf - 0.4, 0.2), (x0 + 0.2, yc, FLOOR + 0.12), bevel=0.04, m=dark),
    ]
    for i in range(4):
        parts.append(box(f"WindbreakPost{i}", (0.14, 0.14, 2.2), (x0 + 0.2, yf + 0.3 + i * (yb - yf - 0.6) / 3, FLOOR + 1.1), bevel=0.02, m=dark))
    parts += snow_cap("WindbreakSnow", (0.2, yb - yf - 0.5, 0.08), (x0 + 0.2, yc, FLOOR + 2.34), drips=0)
    return parts


def build_lodge():
    reset_scene()
    parts = a_frame() + kitchen_wing() + pavilion()
    save("frost_lodge", [merge("Lodge", parts)])


def build_shed():
    """Corrugated maintenance shed (8.2 x 9 m), roller door up, warm work light inside."""
    reset_scene()
    steel, dark = mat("FrostCorrugated", "#5f6a8e", rough=0.5, metal=0.3), fmat("SteelDark", rough=0.5, metal=0.3)
    roof, snow = fmat("Roof", rough=0.7), snow_mat()
    hazard_y, hazard_k = fmat("Yellow"), fmat("Charcoal")
    w, d, h = 9.0, 8.2, 4.2
    parts = [
        box("Floor", (w, d, 0.2), (0, 0, 0.1), bevel=0.04, m=fmat("StoneDark")),
        box("Back", (w, 0.3, h), (0, d / 2, h / 2), bevel=0.04, m=steel),
        box("SideA", (0.3, d, h), (-w / 2, 0, h / 2), bevel=0.04, m=steel),
        box("SideB", (0.3, d, h), (w / 2, 0, h / 2), bevel=0.04, m=steel),
        box("FrontA", (2.4, 0.3, h), (-w / 2 + 1.2, -d / 2, h / 2), bevel=0.04, m=steel),
        box("FrontB", (2.4, 0.3, h), (w / 2 - 1.2, -d / 2, h / 2), bevel=0.04, m=steel),
        box("FrontTop", (4.4, 0.3, 0.9), (0, -d / 2, h - 0.45), bevel=0.04, m=steel),
        box("DoorRoll", (4.6, 0.6, 0.6), (0, -d / 2 - 0.2, h - 0.75), bevel=0.2, segs=3, m=dark),
        box("Bench", (3.0, 0.8, 0.9), (-1.8, d / 2 - 0.8, 0.45), bevel=0.04, m=fmat("TimberDark")),
        box("SignBoard", (3.0, 0.1, 0.55), (0, -d / 2 - 0.2, h + 0.4), bevel=0.03, m=fmat("Navy")),
        text("SignText", "MAINTENANCE", 0.32, 0.03, (0, -d / 2 - 0.28, h + 0.4), m=fmat("Yellow")),
        bulb("WorkLamp", 0.2, (0, 0, h - 0.4), fglow("FrostLantern", "#ffc46b", 3.2)),
    ]
    parts += _shed_interior(w, d, h)
    # Corrugation ribs.
    for i in range(14):
        x = -w / 2 + 0.4 + i * (w - 0.8) / 13
        parts.append(box(f"RibBack{i}", (0.1, 0.36, h - 0.2), (x, d / 2, h / 2), bevel=0.0, m=dark))
    for i in range(12):
        y = -d / 2 + 0.4 + i * (d - 0.8) / 11
        for s, sx in (("A", -1), ("B", 1)):
            parts.append(box(f"Rib{s}{i}", (0.36, 0.1, h - 0.2), (sx * w / 2, y, h / 2), bevel=0.0, m=dark))
    # Hazard stripes on the door frame.
    for s, sx in (("A", -1), ("B", 1)):
        for i in range(6):
            parts.append(box(f"Hazard{s}{i}", (0.34, 0.34, 0.32), (sx * 2.15, -d / 2 - 0.05, 0.3 + i * 0.62), bevel=0.0,
                             m=hazard_y if i % 2 == 0 else hazard_k))
    # Gable roof with snow.
    ridge = h + 1.6
    for side, sx in (("A", -1), ("B", 1)):
        length = math.hypot(w / 2 + 0.5, ridge - h)
        ang = math.atan2(ridge - h, w / 2 + 0.5)
        parts.append(box(f"Roof{side}", (length, d + 0.8, 0.25), (sx * (w / 4 + 0.25), 0, (h + ridge) / 2 + 0.15), rot=(0, sx * ang, 0), bevel=0.05, m=roof))
        parts.append(box(f"RoofSnow{side}", (length - 0.3, d + 0.6, 0.3), (sx * (w / 4 + 0.2), 0, (h + ridge) / 2 + 0.4), rot=(0, sx * ang, 0), bevel=0.12, m=snow))
    parts += icicles("ShedIcicle", (-w / 2, -d / 2 - 0.45, h + 0.05), (w / 2, -d / 2 - 0.45, h + 0.05), 12, 0.5, seed=21)
    # Tyres and drums by the door.
    for i, (x, y) in enumerate(((-3.6, -d / 2 - 0.8), (3.5, -d / 2 - 0.9))):
        parts.append(torus(f"Tyre{i}", 0.42, 0.18, (x, y, 0.2), m=fmat("Charcoal"), major_segs=16, minor_segs=6))
        parts.append(cyl(f"Drum{i}", 0.32, 0.9, (x + 0.2, y - 0.9, 0.45), segs=12, bevel=0.03, m=fmat("Red", rough=0.5)))
        parts.append(sphere(f"DrumSnow{i}", 0.28, (x + 0.2, y - 0.9, 0.92), scale=(1, 1, 0.35), m=snow, segs=8, rings=4))
    save("frost_shed", [merge("Shed", parts)])


def _shed_interior(w, d, h):
    """Workshop inside the shed, seen through the raised door: warm plank
    lining, a pegboard of tools over the bench, shelves of cans and parts, a
    stack of tyres and a ceiling strip light. Kept to the walls, clear of the
    doorway path."""
    lining = mat("FrostShedLining", "#8a5a3e", rough=0.85, emit=0.35)
    dark, steel = fmat("Charcoal"), fmat("SteelDark", rough=0.5, metal=0.3)
    red, yellow, timber = fmat("Red", rough=0.5), fmat("Yellow"), fmat("TimberDark")
    parts = [
        box("LiningBack", (w - 0.8, 0.06, h - 0.3), (0, d / 2 - 0.2, (h - 0.3) / 2), bevel=0.0, m=lining),
        box("LiningA", (0.06, d - 0.6, h - 0.3), (-w / 2 + 0.2, 0, (h - 0.3) / 2), bevel=0.0, m=lining),
        box("LiningB", (0.06, d - 0.6, h - 0.3), (w / 2 - 0.2, 0, (h - 0.3) / 2), bevel=0.0, m=lining),
        box("Ceiling", (w - 0.4, d - 0.4, 0.08), (0, 0, h - 0.1), bevel=0.0, m=dark),
        box("StripLight", (2.4, 0.2, 0.06), (0, 0.6, h - 0.2), bevel=0.0, m=fglow("FrostShedStrip", "#ffe2b0", 2.4)),
        box("Pegboard", (2.8, 0.05, 1.2), (-1.8, d / 2 - 0.26, 1.75), bevel=0.0, m=fmat("Navy")),
    ]
    for k in range(6):
        parts.append(box(f"Tool{k}", (0.12, 0.04, 0.7 - (k % 3) * 0.15), (-3.0 + k * 0.48, d / 2 - 0.3, 1.8), bevel=0.0, m=steel))
    # Shelving on the back wall, east of the bench.
    for k in range(3):
        z = 0.5 + k * 1.0
        parts.append(box(f"Shelf{k}", (2.4, 0.6, 0.06), (2.3, d / 2 - 0.55, z), bevel=0.0, m=timber))
        for j in range(3):
            parts.append(box(f"Can{k}{j}", (0.38, 0.28, 0.5), (1.5 + j * 0.8, d / 2 - 0.55, z + 0.28), bevel=0.04,
                             m=red if (j + k) % 2 else yellow))
    for ex in (-1.2, 1.2):
        parts.append(box(f"ShelfPost{ex}", (0.08, 0.6, 3.0), (2.3 + ex, d / 2 - 0.55, 1.5), bevel=0.0, m=steel))
    # Tyres stacked by the west wall; snow shovels leaning on the east wall.
    for k in range(3):
        parts.append(torus(f"InTyre{k}", 0.42, 0.17, (-w / 2 + 0.8, -1.2, 0.2 + k * 0.32), m=dark, major_segs=16, minor_segs=6))
    for k in range(2):
        parts.append(box(f"Shovel{k}", (0.06, 0.06, 1.4), (w / 2 - 0.45, -1.4 + k * 0.5, 0.75), rot=(0.15, 0, 0), bevel=0.0, m=timber))
        parts.append(box(f"ShovelBlade{k}", (0.08, 0.42, 0.36), (w / 2 - 0.45, -1.5 + k * 0.5, 0.2), bevel=0.02, m=yellow))
    return parts


BUILDERS = {"lodge": build_lodge, "shed": build_shed}


if __name__ == "__main__":
    wanted = [a for a in sys.argv[1:] if a in BUILDERS] or list(BUILDERS)
    for key in wanted:
        BUILDERS[key]()
