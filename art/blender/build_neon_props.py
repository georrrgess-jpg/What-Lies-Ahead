"""Rooftop props for Neon Skyline (World 2): roof access door, freight elevator,
service hatch, helipad markings, water tower, skylight, AC unit, vent, crates,
antenna mast, satellite dish, terrace billboard frame, rooftop sign, blade
signs, sky-bridge canopy and the two floating holograms.

Each function builds one prop in a fresh scene and saves .blend + .glb.
Material conventions (NeonHalo_*, NeonHolo*, Blink*, Spin*) are described in
neon_common.py; the level script applies them at runtime.

    python art/blender/build_neon_props.py [prop ...]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from neon_common import *  # noqa: F401,F403


def _common():
    return dict(
        concrete=nmat("Concrete", rough=0.85), concrete_dark=nmat("ConcreteDark", rough=0.9),
        concrete_light=nmat("ConcreteLight", rough=0.8), steel=nmat("Steel", rough=0.4, metal=0.6),
        steel_dark=nmat("SteelDark", rough=0.45, metal=0.5), steel_light=nmat("SteelLight", rough=0.35, metal=0.7),
        hazard=nmat("Hazard", rough=0.5), ink=nmat("Ink", rough=0.6),
        cyan=neon_glow("NeonCyan", "#2ef2ff"), magenta=neon_glow("NeonMagenta", "#ff2fae"),
        violet=neon_glow("NeonViolet", "#a066ff"), amber=neon_glow("NeonAmber", "#ffb43a"),
        lime=neon_glow("NeonLime", "#b6ff3a"), red=neon_glow("NeonRed", "#ff3a4a", 4.0),
        white=nmat("White", rough=0.5),
    )


def hazard_stripes(prefix, width, height, loc, m_a, m_b, count=6, depth=0.03):
    """Diagonal-looking hazard band made of alternating blocks (faces -Y)."""
    out = []
    w = width / count
    for i in range(count):
        out.append(box(f"{prefix}{i}", (w + 0.002, depth, height), (loc[0] - width / 2 + w * (i + 0.5), loc[1], loc[2]),
                       rot=(0, math.radians(18), 0), bevel=0.0, m=m_a if i % 2 == 0 else m_b))
    return out


# ---------------------------------------------------------------------------
# Entrances
# ---------------------------------------------------------------------------

def build_roof_door():
    """Stairwell bulkhead, 6 (x) by 3.5 (y) by 3.2 m, door on the -Y face."""
    reset_scene()
    c = _common()
    door_m = nmat("DoorRed", "#a8303f", rough=0.45, metal=0.3)
    inner = neon_glow("DoorSpill", "#ffd28a", 2.2)
    parts = [
        box("Block", (6.0, 3.5, 3.0), (0, 0, 1.5), bevel=0.05, m=c["concrete"]),
        box("Coping", (6.2, 3.7, 0.18), (0, 0, 3.08), bevel=0.04, m=c["concrete_light"]),
        box("Plinth", (6.1, 3.6, 0.2), (0, 0, 0.1), bevel=0.03, m=c["concrete_dark"]),
        # Door: frame, slightly open leaf, warm light spilling through the gap.
        box("DoorFrame", (1.5, 0.12, 2.45), (0.8, -1.76, 1.25), bevel=0.02, m=c["steel_dark"]),
        box("DoorGap", (1.2, 0.05, 2.2), (0.8, -1.79, 1.12), bevel=0.0, m=inner),
        box("DoorLeaf", (1.22, 0.07, 2.22), (0.62, -1.98, 1.12), rot=(0, 0, math.radians(-28)), bevel=0.02, m=door_m),
        box("DoorWindow", (0.4, 0.08, 0.5), (0.5, -2.07, 1.6), rot=(0, 0, math.radians(-28)), bevel=0.01, m=inner),
        box("DoorBar", (0.9, 0.08, 0.06), (0.62, -2.07, 1.05), rot=(0, 0, math.radians(-28)), bevel=0.01, m=c["steel_light"]),
        box("Step", (1.8, 0.5, 0.12), (0.8, -1.98, 0.06), bevel=0.02, m=c["concrete_dark"]),
        # Canopy over the door with a caged lamp.
        box("Canopy", (2.1, 0.8, 0.1), (0.8, -2.1, 2.75), rot=(math.radians(-8), 0, 0), bevel=0.02, m=c["steel"]),
        box("CanopyArmL", (0.06, 0.8, 0.06), (0.0, -2.1, 2.6), rot=(math.radians(-35), 0, 0), bevel=0.0, m=c["steel_dark"]),
        box("CanopyArmR", (0.06, 0.8, 0.06), (1.6, -2.1, 2.6), rot=(math.radians(-35), 0, 0), bevel=0.0, m=c["steel_dark"]),
        neon_bulb("DoorLamp", 0.12, (0.8, -1.9, 2.55), "#ffc070", 3.0),
        # Sign: ROOF ACCESS in green exit-style glow.
        box("SignPlate", (1.7, 0.08, 0.42), (-1.3, -1.79, 2.45), bevel=0.02, m=c["ink"]),
        sign_text("SignText", "ROOF ACCESS", 0.22, 0.03, (-1.3, -1.84, 2.45), m=c["lime"]),
        # Neon graffiti tag on the wall.
        sign_text("Tag", "ZED", 0.7, 0.03, (-1.6, -1.77, 1.2), rot=(0, math.radians(-8), 0), m=c["magenta"]),
        box("TagUnderline", (1.4, 0.03, 0.06), (-1.6, -1.77, 0.75), rot=(0, math.radians(-8), 0), bevel=0.0, m=c["cyan"]),
        # Roof clutter: vent box, pipe, cable tray.
        box("VentBox", (1.4, 1.0, 0.7), (-1.6, 0.6, 3.5), bevel=0.04, m=c["steel"]),
        box("VentGrille", (1.2, 0.05, 0.45), (-1.6, 0.08, 3.5), bevel=0.0, m=c["steel_dark"]),
        cyl("Pipe", 0.12, 3.6, (2.85, 1.2, 1.9), segs=10, bevel=0.0, m=c["steel_light"]),
        cyl("PipeCap", 0.2, 0.2, (2.85, 1.2, 3.75), segs=10, bevel=0.03, m=c["steel_dark"]),
        box("Meter", (0.5, 0.25, 0.7), (2.2, -1.85, 1.3), bevel=0.04, m=c["steel_dark"]),
        box("MeterLed", (0.06, 0.02, 0.06), (2.3, -1.99, 1.5), bevel=0.0, m=c["red"]),
    ]
    for i, x in enumerate((-2.6, -0.2, 2.6)):
        parts.append(box(f"Rib{i}", (0.12, 3.52, 2.98), (x, 0, 1.5), bevel=0.02, m=c["concrete_light"]))
    save("neon_roof_door", [merge("RoofDoor", parts)])


def build_freight_elevator():
    """Freight elevator head house, 5 x 5 x 4.6 m, doors on the -Y face."""
    reset_scene()
    c = _common()
    shaft = nmat("ElevatorPaint", "#3b3f6a", rough=0.6, metal=0.2)
    light = neon_glow("CarLight", "#fff1c2", 2.6)
    parts = [
        box("Shaft", (5.0, 5.0, 4.0), (0, 0, 2.0), bevel=0.05, m=shaft),
        box("MachineRoom", (3.6, 3.4, 1.2), (0, 0.6, 4.6), bevel=0.05, m=c["concrete"]),
        box("RoofSlab", (5.2, 5.2, 0.18), (0, 0, 4.05), bevel=0.04, m=c["concrete_light"]),
        # Door opening with the lit car inside and half-open doors.
        box("Opening", (3.2, 0.1, 3.0), (0, -2.5, 1.55), bevel=0.0, m=light),
        box("DoorL", (0.9, 0.12, 3.0), (-1.15, -2.58, 1.55), bevel=0.02, m=c["steel"]),
        box("DoorR", (0.9, 0.12, 3.0), (1.15, -2.58, 1.55), bevel=0.02, m=c["steel"]),
        box("Header", (3.8, 0.3, 0.5), (0, -2.6, 3.3), bevel=0.04, m=c["steel_dark"]),
        box("Sill", (3.6, 0.5, 0.08), (0, -2.65, 0.04), bevel=0.01, m=c["steel_light"]),
        box("JambL", (0.3, 0.3, 3.2), (-1.75, -2.6, 1.6), bevel=0.03, m=c["steel_dark"]),
        box("JambR", (0.3, 0.3, 3.2), (1.75, -2.6, 1.6), bevel=0.03, m=c["steel_dark"]),
        # Status panel and the floor indicator.
        box("Panel", (0.35, 0.1, 0.7), (2.15, -2.55, 1.4), bevel=0.02, m=c["ink"]),
        box("PanelUp", (0.14, 0.03, 0.14), (2.15, -2.62, 1.6), bevel=0.0, m=c["lime"]),
        box("PanelDown", (0.14, 0.03, 0.14), (2.15, -2.62, 1.25), bevel=0.0, m=c["red"]),
        box("Indicator", (1.4, 0.08, 0.32), (0, -2.77, 3.3), bevel=0.02, m=c["ink"]),
        sign_text("IndicatorText", "R  >", 0.22, 0.02, (0, -2.82, 3.3), m=c["amber"]),
        # Machine room details: cable drum, louvres, warning beacon.
        cyl("Drum", 0.5, 1.2, (0, -0.6, 4.7), rot=(0, math.radians(90), 0), segs=16, bevel=0.03, m=c["steel_light"]),
        cyl("BeaconBase", 0.2, 0.15, (1.3, 0.6, 5.28), segs=12, bevel=0.02, m=c["steel_dark"]),
        neon_bulb("BlinkBeacon", 0.16, (1.3, 0.6, 5.48), "#ffb43a", 4.0),
    ]
    parts += hazard_stripes("HazardTop", 3.6, 0.22, (0, -2.66, 3.62), c["hazard"], c["ink"], 9)
    parts += hazard_stripes("HazardSill", 3.6, 0.12, (0, -2.92, 0.12), c["hazard"], c["ink"], 9)
    for i in range(5):
        parts.append(box(f"Louvre{i}", (1.6, 0.06, 0.08), (-1.0, -1.12, 4.25 + i * 0.16), rot=(math.radians(25), 0, 0), bevel=0.0, m=c["steel_dark"]))
    for i, x in enumerate((-2.5, 2.5)):
        for j, y in enumerate((-2.5, 2.5)):
            parts.append(box(f"Corner{i}{j}", (0.25, 0.25, 4.0), (x, y, 2.0), bevel=0.03, m=c["steel_dark"]))
    save("neon_freight_elevator", [merge("FreightElevator", parts)])


def build_hatch():
    """Floor service hatch, 1.6 m square, lid flipped open, light inside."""
    reset_scene()
    c = _common()
    parts = [
        box("Curb", (1.6, 1.6, 0.12), (0, 0, 0.06), bevel=0.02, m=c["steel_dark"]),
        box("Glow", (1.2, 1.2, 0.04), (0, 0, 0.1), bevel=0.0, m=neon_glow("HatchGlow", "#9fffd0", 2.4)),
        box("Lid", (1.5, 0.06, 1.5), (0, 0.78, 0.8), rot=(math.radians(-12), 0, 0), bevel=0.02, m=c["steel"]),
        box("LidRibA", (1.4, 0.08, 0.06), (0, 0.76, 0.6), rot=(math.radians(-12), 0, 0), bevel=0.0, m=c["steel_light"]),
        box("LidRibB", (1.4, 0.08, 0.06), (0, 0.76, 1.1), rot=(math.radians(-12), 0, 0), bevel=0.0, m=c["steel_light"]),
        cyl("RungTop", 0.025, 1.1, (0, 0.45, 0.1), rot=(0, math.radians(90), 0), segs=6, bevel=0.0, m=c["steel_light"]),
    ]
    parts += hazard_stripes("Stripe", 1.6, 0.13, (0, -0.84, 0.06), c["hazard"], c["ink"], 8, depth=0.04)
    save("neon_hatch", [merge("Hatch", parts)])


# ---------------------------------------------------------------------------
# Helipad and the hub's surroundings
# ---------------------------------------------------------------------------

def build_helipad():
    """Painted helipad around the vending hub: rings, chevrons, LZ number and a
    ring of flush landing lights (cyan halos)."""
    reset_scene()
    c = _common()
    yellow = nmat("PadYellow", "#ffcf3a", rough=0.6)
    white = nmat("PadWhite", "#e8e6f4", rough=0.6)
    pad = nmat("PadDark", "#2a2840", rough=0.7)
    parts = [
        disc("PadBase", 7.2, m=pad, inner=3.0, thickness=0.006),
        disc("OuterRing", 7.0, m=yellow, inner=6.65, thickness=0.012),
        disc("InnerRing", 4.6, m=white, inner=4.4, thickness=0.012),
    ]
    # Dashed ring between.
    for i in range(24):
        a = math.tau * i / 24
        parts.append(box(f"Dash{i:02d}", (0.12, 0.7, 0.012), (math.cos(a) * 5.6, math.sin(a) * 5.6, 0.012),
                         rot=(0, 0, a), bevel=0.0, m=white))
    # Approach chevrons (north and south) and the LZ number in front.
    for k, base in enumerate((-1, 1)):
        for j in range(3):
            for side in (-1, 1):
                parts.append(box(f"Chev{k}{j}{side}", (1.0, 0.22, 0.012), (side * 0.35, base * (8.0 + j * 0.9), 0.012),
                                 rot=(0, 0, math.radians(side * base * 35)), bevel=0.0, m=yellow))
    lz = sign_text("LZ", "LZ-07", 0.9, 0.01, (0, -5.6, 0.014), rot=(math.radians(-90), 0, 0), m=white)
    parts.append(lz)
    for i in range(16):
        a = math.tau * (i + 0.5) / 16
        parts.append(cyl(f"LightBase{i:02d}", 0.12, 0.04, (math.cos(a) * 7.35, math.sin(a) * 7.35, 0.02), segs=10, bevel=0.0, m=c["steel_dark"]))
        parts.append(neon_bulb(f"Light{i:02d}", 0.07, (math.cos(a) * 7.35, math.sin(a) * 7.35, 0.07), "#36f0ff", 4.0, halo_scale=5.5))
    for ob in parts:
        ob.location.z += 0.0
    save("neon_helipad", [merge("Helipad", parts)])


def build_water_tower():
    """Rooftop water tower: stave tank with hoops on a braced steel stand, a
    catwalk ring, ladder and a violet neon band with a moon-cat logo."""
    reset_scene()
    c = _common()
    wood = nmat("TankWood", "#6a4a5e", rough=0.85)
    wood_dark = nmat("TankWoodDark", "#4a3248", rough=0.9)
    hoop = nmat("Hoop", "#2a2838", rough=0.4, metal=0.6)
    roof = nmat("TankRoof", "#3a3456", rough=0.7)
    parts = []
    leg_r = 1.9 * math.sqrt(2)
    legs = [(math.cos(a) * leg_r, math.sin(a) * leg_r) for a in (math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4)]
    for i, (x, y) in enumerate(legs):
        parts.append(box(f"Leg{i}", (0.3, 0.3, 4.4), (x * 0.92, y * 0.92, 2.2), rot=(0, 0, math.pi / 4), bevel=0.03, m=c["steel_dark"]))
        parts.append(box(f"Foot{i}", (0.6, 0.6, 0.15), (x * 0.92, y * 0.92, 0.075), bevel=0.02, m=c["concrete_dark"]))
    for k in range(4):
        a, b = legs[k], legs[(k + 1) % 4]
        for z0, z1 in ((0.4, 2.2), (2.2, 4.0)):
            parts.append(tube(f"Brace{k}_{z0}", [(a[0] * 0.92, a[1] * 0.92, z0), (b[0] * 0.92, b[1] * 0.92, z1)], 0.05, m=c["steel"], segs=5, cap=False))
            parts.append(tube(f"BraceB{k}_{z0}", [(b[0] * 0.92, b[1] * 0.92, z0), (a[0] * 0.92, a[1] * 0.92, z1)], 0.05, m=c["steel"], segs=5, cap=False))
        parts.append(tube(f"Ring{k}", [(a[0] * 0.92, a[1] * 0.92, 2.2), (b[0] * 0.92, b[1] * 0.92, 2.2)], 0.06, m=c["steel"], segs=5, cap=False))
    parts += [
        cyl("Deck", 2.75, 0.15, (0, 0, 4.4), segs=28, bevel=0.03, m=c["steel_dark"]),
        torus("Railing", 2.7, 0.04, (0, 0, 5.4), m=c["steel"], major_segs=36, minor_segs=5),
        cyl("Tank", 2.2, 3.7, (0, 0, 6.35), segs=28, bevel=0.04, m=wood),
        cyl("TankRoof", 2.4, 1.2, (0, 0, 8.8), segs=28, bevel=0.03, m=roof, radius_top=0.25),
        cyl("Finial", 0.18, 0.4, (0, 0, 9.55), segs=10, bevel=0.03, m=c["steel_dark"]),
        neon_bulb("BlinkTop", 0.13, (0, 0, 9.85), "#ff3a4a", 4.0),
    ]
    for i in range(10):
        a = math.tau * i / 10
        parts.append(cyl(f"Post{i}", 0.03, 1.0, (math.cos(a) * 2.7, math.sin(a) * 2.7, 4.95), segs=5, bevel=0.0, m=c["steel"]))
    for i, z in enumerate((4.8, 5.9, 7.0, 8.0)):
        parts.append(torus(f"Hoop{i}", 2.24, 0.05, (0, 0, z), m=hoop, major_segs=36, minor_segs=5))
    for i in range(28):
        a = math.tau * i / 28
        parts.append(box(f"Stave{i:02d}", (0.04, 0.05, 3.6), (math.cos(a) * 2.205, math.sin(a) * 2.205, 6.35), rot=(0, 0, a), bevel=0.0, m=wood_dark))
    # Neon band and logo facing -Y (the plaza, once rotated in the level).
    parts.append(torus("NeonBand", 2.27, 0.06, (0, 0, 7.55), m=c["violet"], major_segs=48, minor_segs=6))
    logo = [
        sign_text("LogoText", "MOON", 0.62, 0.05, (0, -2.25, 6.6), m=c["magenta"]),
        sign_text("LogoText2", "CAT", 0.62, 0.05, (0, -2.25, 5.85), m=c["cyan"]),
    ]
    parts += logo
    # Ladder up one leg.
    lx, ly = legs[3][0] * 0.92 + 0.3, legs[3][1] * 0.92
    for side in (-0.22, 0.22):
        parts.append(box(f"LadderRail{side}", (0.05, 0.05, 4.4), (lx, ly + side, 2.2), bevel=0.0, m=c["steel_light"]))
    for k in range(13):
        parts.append(box(f"Rung{k}", (0.04, 0.44, 0.04), (lx, ly, 0.3 + k * 0.32), bevel=0.0, m=c["steel_light"]))
    save("neon_water_tower", [merge("WaterTower", parts)])


def build_skylight():
    """Glass-roofed skylight, 3.2 x 2.2 m, lit from below."""
    reset_scene()
    c = _common()
    glass = nmat("SkyGlass", "#7ab8ff", rough=0.08, metal=0.2, emit=0.9)
    parts = [
        box("Curb", (3.2, 2.2, 0.55), (0, 0, 0.275), bevel=0.04, m=c["concrete_light"]),
        box("Rim", (3.0, 2.0, 0.08), (0, 0, 0.59), bevel=0.02, m=c["steel_dark"]),
    ]
    # Pitched glass with mullions.
    for side in (-1, 1):
        parts.append(box(f"Pane{side}", (2.9, 1.08, 0.04), (0, side * 0.46, 0.84), rot=(math.radians(side * 26), 0, 0), bevel=0.0, m=glass))
        for i in range(5):
            x = -1.4 + i * 0.7
            parts.append(box(f"Mullion{side}{i}", (0.06, 1.1, 0.06), (x, side * 0.46, 0.87), rot=(math.radians(side * 26), 0, 0), bevel=0.0, m=c["steel_dark"]))
    parts.append(box("Ridge", (3.0, 0.1, 0.1), (0, 0, 1.1), bevel=0.02, m=c["steel_dark"]))
    for x in (-1.45, 1.45):
        parts.append(prism(f"Gable{x}", [(-1.0, 0.6), (1.0, 0.6), (0.0, 1.1)], 0.06, (x, 0, 0), rot=(0, 0, math.radians(90)), m=c["steel_dark"]))
    save("neon_skylight", [merge("Skylight", parts)])


def build_ac_unit():
    """Rooftop condenser: 2.6 x 1.8 x 1.4 m with two fans, louvres and pipes."""
    reset_scene()
    c = _common()
    body_m = nmat("ACBody", "#8a8fae", rough=0.45, metal=0.4)
    parts = [
        box("Body", (2.6, 1.8, 1.25), (0, 0, 0.72), bevel=0.06, m=body_m),
        box("Skid", (2.7, 1.6, 0.12), (0, 0, 0.06), bevel=0.02, m=c["steel_dark"]),
        box("TopPlate", (2.5, 1.7, 0.06), (0, 0, 1.37), bevel=0.02, m=c["steel"]),
        box("Badge", (0.5, 0.03, 0.16), (-0.8, -0.91, 1.05), bevel=0.01, m=c["cyan"]),
        box("Led", (0.05, 0.03, 0.05), (1.05, -0.91, 1.15), bevel=0.0, m=c["lime"]),
    ]
    for i, x in enumerate((-0.62, 0.62)):
        parts += [
            cyl(f"FanRing{i}", 0.58, 0.1, (x, 0, 1.43), segs=24, bevel=0.02, m=c["steel_dark"]),
            cyl(f"FanHub{i}", 0.12, 0.08, (x, 0, 1.45), segs=10, bevel=0.01, m=c["steel_light"]),
            cyl(f"FanHole{i}", 0.5, 0.04, (x, 0, 1.43), segs=24, bevel=0.0, m=c["ink"]),
        ]
        for b in range(5):
            a = math.tau * b / 5 + i
            parts.append(box(f"Blade{i}{b}", (0.42, 0.12, 0.02), (x + math.cos(a) * 0.25, math.sin(a) * 0.25, 1.46),
                             rot=(math.radians(18), 0, a), bevel=0.0, m=c["steel_light"]))
        for g in range(4):
            parts.append(torus(f"Grille{i}{g}", 0.15 + g * 0.11, 0.008, (x, 0, 1.49), m=c["steel"], major_segs=20, minor_segs=4))
    for k in range(9):
        parts.append(box(f"Louvre{k}", (0.06, 1.82, 0.9), (-1.12 + k * 0.28, 0, 0.7), bevel=0.0, m=c["steel"]))
    parts.append(tube("PipeA", [(1.3, 0.4, 0.4), (1.55, 0.4, 0.4), (1.55, 0.4, 0.05)], 0.06, m=c["steel_light"], segs=8))
    parts.append(tube("PipeB", [(1.3, 0.1, 0.3), (1.6, 0.1, 0.3), (1.6, 0.1, 0.05)], 0.045, m=nmat("Copper", "#c0705a", rough=0.35, metal=0.7), segs=8))
    save("neon_ac_unit", [merge("ACUnit", parts)])


def build_vent():
    """Cluster of vent stacks with mushroom caps and a turbine."""
    reset_scene()
    c = _common()
    parts = [
        box("Base", (1.2, 1.2, 0.2), (0, 0, 0.1), bevel=0.03, m=c["concrete_light"]),
        cyl("StackA", 0.22, 1.3, (-0.25, -0.2, 0.85), segs=14, bevel=0.0, m=c["steel"]),
        cyl("CapA", 0.36, 0.14, (-0.25, -0.2, 1.62), segs=14, bevel=0.04, m=c["steel_dark"], radius_top=0.1),
        cyl("StackB", 0.16, 0.9, (0.3, 0.25, 0.65), segs=12, bevel=0.0, m=c["steel_light"]),
        cyl("CapB", 0.27, 0.1, (0.3, 0.25, 1.15), segs=12, bevel=0.03, m=c["steel_dark"], radius_top=0.08),
        cyl("TurbineNeck", 0.14, 0.4, (0.32, -0.3, 0.4), segs=12, bevel=0.0, m=c["steel"]),
        sphere("SpinTurbine", 0.26, (0.32, -0.3, 0.78), scale=(1, 1, 0.8), m=c["steel_light"], segs=12, rings=6),
    ]
    save("neon_vent", [merge("Vent", parts)])


def build_crates():
    """Stacked shipping crates with glowing labels, a drum and a tarp bundle."""
    reset_scene()
    c = _common()
    crate_a = nmat("CrateBlue", "#2f4fa0", rough=0.6)
    crate_b = nmat("CrateRed", "#9c2f56", rough=0.6)
    drum = nmat("Drum", "#2f8a7a", rough=0.5, metal=0.3)
    parts = [
        box("CrateA", (1.1, 1.1, 0.8), (-0.6, 0, 0.4), bevel=0.04, m=crate_a),
        box("CrateB", (1.0, 1.0, 0.7), (-0.55, 0.05, 1.15), rot=(0, 0, math.radians(8)), bevel=0.04, m=crate_b),
        box("CrateC", (0.9, 0.9, 0.7), (0.45, -0.1, 0.35), rot=(0, 0, math.radians(-6)), bevel=0.04, m=crate_b),
        box("LabelA", (0.5, 0.02, 0.16), (-0.6, -0.56, 0.5), bevel=0.0, m=c["cyan"]),
        box("LabelB", (0.4, 0.02, 0.14), (-0.55, -0.47, 1.22), rot=(0, 0, math.radians(8)), bevel=0.0, m=c["amber"]),
        cyl("Drum", 0.3, 0.9, (0.75, 0.32, 0.45), segs=14, bevel=0.02, m=drum),
        torus("DrumHoopA", 0.305, 0.02, (0.75, 0.32, 0.3), m=c["steel_dark"], major_segs=16, minor_segs=4),
        torus("DrumHoopB", 0.305, 0.02, (0.75, 0.32, 0.65), m=c["steel_dark"], major_segs=16, minor_segs=4),
    ]
    for ob in parts[:3]:
        pass
    for i, (x, z) in enumerate(((-0.6, 0.4), (0.45, 0.35))):
        for side in (-1, 1):
            parts.append(box(f"Slat{i}{side}", (0.06, 1.12, 0.06), (x + side * 0.4, 0, z), bevel=0.0, m=c["steel_dark"]))
    save("neon_crates", [merge("Crates", parts)])


def build_antenna():
    """9 m lattice mast with panels, a small dish and a blinking red beacon."""
    reset_scene()
    c = _common()
    mast = lattice("Mast", 8.4, 0.22, c["steel_light"], rod=0.035)
    mast += [
        box("BasePlate", (0.8, 0.8, 0.12), (0, 0, 0.06), bevel=0.02, m=c["concrete_dark"]),
        box("PanelA", (0.22, 0.12, 0.9), (0.3, 0, 6.5), bevel=0.02, m=c["white"]),
        box("PanelB", (0.22, 0.12, 0.9), (-0.2, 0.25, 6.5), rot=(0, 0, math.radians(120)), bevel=0.02, m=c["white"]),
        sphere("Dish", 0.32, (0, -0.35, 5.2), scale=(1, 0.35, 1), m=c["white"], segs=12, rings=6),
        cyl("Top", 0.03, 1.0, (0, 0, 8.9), segs=6, bevel=0.0, m=c["steel_dark"]),
    ]
    beacon = neon_bulb("BlinkBeacon", 0.12, (0, 0, 9.45), "#ff3a4a", 5.0, halo_scale=6.0)
    mid = neon_bulb("BlinkMid", 0.08, (0.22, 0, 4.4), "#ff3a4a", 4.0)
    save("neon_antenna", [merge("Antenna", mast), merge("BlinkBeacon", [beacon], pivot=(0, 0, 9.45)),
                          merge("BlinkMid", [mid], pivot=(0.22, 0, 4.4))])


def build_dish():
    """Satellite dish on a pole and tripod."""
    reset_scene()
    c = _common()
    parts = [
        box("Base", (1.2, 1.2, 0.15), (0, 0, 0.075), bevel=0.03, m=c["concrete_light"]),
        cyl("Pole", 0.07, 1.2, (0, 0, 0.75), segs=8, bevel=0.0, m=c["steel"]),
        sphere("Dish", 0.7, (0, -0.15, 1.5), scale=(1, 0.3, 1), rot=(math.radians(-30), 0, 0), m=c["white"], segs=16, rings=8),
        cyl("Arm", 0.025, 0.7, (0, -0.45, 1.65), rot=(math.radians(-60), 0, 0), segs=6, bevel=0.0, m=c["steel_dark"]),
        box("Lnb", (0.1, 0.12, 0.1), (0, -0.75, 1.8), bevel=0.02, m=c["steel_dark"]),
        box("LnbLed", (0.03, 0.02, 0.03), (0, -0.82, 1.82), bevel=0.0, m=c["lime"]),
    ]
    save("neon_dish", [merge("Dish", parts)])


# ---------------------------------------------------------------------------
# Signs
# ---------------------------------------------------------------------------

def build_billboard():
    """Frame for the terrace billboard. The animated screen is a quad added by
    the level (9.6 x 4.8 m, centred 6.6 m up, 0.35 m in front of the origin).
    Front faces -Y. Posts run down past the roof edge to facade brackets."""
    reset_scene()
    c = _common()
    frame_m = nmat("BillboardFrame", "#262a44", rough=0.4, metal=0.6)
    parts = []
    cz = 6.6
    w, h = 10.0, 5.2
    parts += [
        box("Back", (w, 0.3, h), (0, 0.25, cz), bevel=0.05, m=c["steel_dark"]),
        box("FrameTop", (w + 0.3, 0.5, 0.25), (0, 0, cz + h / 2), bevel=0.05, m=frame_m),
        box("FrameBottom", (w + 0.3, 0.5, 0.25), (0, 0, cz - h / 2), bevel=0.05, m=frame_m),
        box("FrameL", (0.25, 0.5, h), (-w / 2, 0, cz), bevel=0.05, m=frame_m),
        box("FrameR", (0.25, 0.5, h), (w / 2, 0, cz), bevel=0.05, m=frame_m),
        box("TrimTop", (w + 0.2, 0.06, 0.07), (0, -0.27, cz + h / 2 - 0.05), bevel=0.0, m=c["magenta"]),
        box("TrimBottom", (w + 0.2, 0.06, 0.07), (0, -0.27, cz - h / 2 + 0.05), bevel=0.0, m=c["cyan"]),
        # Catwalk under the screen.
        box("Catwalk", (w, 0.9, 0.08), (0, -0.4, cz - h / 2 - 0.35), bevel=0.01, m=c["steel"]),
        box("CatwalkRail", (w, 0.05, 0.05), (0, -0.82, cz - h / 2 + 0.55), bevel=0.0, m=c["steel_light"]),
    ]
    for i in range(9):
        x = -w / 2 + 0.6 + i * (w - 1.2) / 8
        parts.append(box(f"CatwalkPost{i}", (0.05, 0.05, 0.9), (x, -0.82, cz - h / 2 + 0.1), bevel=0.0, m=c["steel_light"]))
    # Lamps on arms lighting the screen.
    for i in range(4):
        x = -3.6 + i * 2.4
        parts += [
            tube(f"LampArm{i}", [(x, 0.0, cz + h / 2 + 0.1), (x, -0.9, cz + h / 2 + 0.6)], 0.035, m=c["steel_dark"], segs=6),
            box(f"LampHead{i}", (0.3, 0.25, 0.16), (x, -0.95, cz + h / 2 + 0.55), rot=(math.radians(35), 0, 0), bevel=0.03, m=c["steel_dark"]),
            neon_bulb(f"Lamp{i}", 0.09, (x, -1.0, cz + h / 2 + 0.47), "#fff2d0", 3.0),
        ]
    # Two posts and a cross brace, down to below the roof line (facade brackets).
    for x in (-4.0, 4.0):
        parts += [
            box(f"Post{x}", (0.35, 0.35, cz - h / 2 + 7.0), (x, 0.4, (cz - h / 2 - 7.0) / 2 + 0.0), bevel=0.04, m=frame_m),
            box(f"Bracket{x}", (0.25, 1.0, 0.25), (x, 0.0, -1.5), bevel=0.03, m=frame_m),
            box(f"BracketB{x}", (0.25, 1.0, 0.25), (x, 0.0, -5.0), bevel=0.03, m=frame_m),
        ]
    parts.append(tube("Brace", [(-4.0, 0.4, 0.6), (4.0, 0.4, 3.6)], 0.06, m=c["steel"], segs=6))
    parts.append(tube("BraceB", [(4.0, 0.4, 0.6), (-4.0, 0.4, 3.6)], 0.06, m=c["steel"], segs=6))
    # Brand cap on top.
    parts.append(box("Cap", (2.6, 0.3, 0.7), (3.4, 0.0, cz + h / 2 + 0.45), bevel=0.05, m=c["ink"]))
    parts.append(sign_text("CapText", "ZAP!", 0.5, 0.04, (3.4, -0.18, cz + h / 2 + 0.45), m=c["red"]))
    save("neon_billboard", [merge("Billboard", parts)])


def build_rooftop_sign():
    """Giant KAIJU NOODLE BAR sign on scaffolding, 16 m wide, facing -Y."""
    reset_scene()
    c = _common()
    face = neon_glow("SignFaceOrange", "#ff6a2a", 3.4)
    face2 = neon_glow("SignFaceCyan", "#2ef2ff", 3.0)
    side = nmat("SignSide", "#1c1828", rough=0.5)
    parts = []
    parts += tube_letters("Kaiju", "KAIJU", 3.6, (0, -0.2, 3.7), face, side, depth=0.35)
    parts += tube_letters("Noodle", "NOODLE BAR", 1.3, (0, -0.2, 1.25), face2, side, depth=0.25)
    # Scaffold behind.
    for i in range(7):
        x = -7.2 + i * 2.4
        parts.append(box(f"Upright{i}", (0.14, 0.14, 6.2), (x, 0.45, 3.1), bevel=0.0, m=c["steel_dark"]))
        parts.append(tube(f"Diag{i}", [(x, 0.45, 0.2), (x + 2.4 if i < 6 else x, 0.45, 3.0)], 0.04, m=c["steel"], segs=5, cap=False))
    for z in (0.3, 2.4, 5.6):
        parts.append(box(f"Rail{z}", (14.8, 0.12, 0.12), (0, 0.45, z), bevel=0.0, m=c["steel_dark"]))
    # Bulb chase along the bottom.
    for i in range(16):
        parts.append(neon_bulb(f"Chase{i:02d}", 0.09, (-7.0 + i * 14.0 / 15, -0.25, 0.25), "#ffcf5a", 3.0))
    save("neon_rooftop_sign", [merge("RooftopSign", parts)])


def _blade(name, words, colors, height, plate_hex):
    reset_scene()
    c = _common()
    plate = nmat("BladePlate", plate_hex, rough=0.5)
    parts = [
        cyl("Pole", 0.12, 2.2, (0, 0, 1.1), segs=10, bevel=0.0, m=c["steel_dark"]),
        box("BasePlate", (0.6, 0.6, 0.1), (0, 0, 0.05), bevel=0.02, m=c["steel_dark"]),
        box("Blade", (0.32, 1.3, height), (0, 0, 2.2 + height / 2), bevel=0.06, m=plate),
        box("BladeCap", (0.4, 1.4, 0.2), (0, 0, 2.2 + height + 0.1), bevel=0.04, m=c["steel_dark"]),
    ]
    step = height / len(words)
    for i, (ch, col) in enumerate(zip(words, colors)):
        z = 2.2 + height - step * (i + 0.5)
        g = neon_glow(f"Blade{col}", col, 3.4)
        for s in (-1, 1):
            letter = sign_text(f"Ch{i}{s}", ch, step * 0.72, 0.04, (s * 0.19, 0, z), rot=(0, 0, math.radians(90 * s)), m=g)
            parts.append(letter)
    for i in range(int(height / 0.5)):
        z = 2.35 + i * 0.5
        for y in (-0.62, 0.62):
            parts.append(neon_bulb(f"Edge{i}{y}", 0.05, (0.0, y * 1.07, z), "#ffd27a", 3.0, halo_scale=4.0))
    save(name, [merge("BladeSign", parts)])


def build_blade_sign():
    _blade("neon_blade_sign", "HOTEL", ["#ff2fae"] * 5, 5.6, "#201a36")


def build_blade_sign_b():
    _blade("neon_blade_sign_b", "24H", ["#b6ff3a", "#b6ff3a", "#2ef2ff"], 3.6, "#16223a")


# ---------------------------------------------------------------------------
# Sky-bridge canopy and holograms
# ---------------------------------------------------------------------------

def build_skybridge():
    """Arched canopy over the 4.5 m wide, 8 m long sky-bridge. Origin at the
    south end at deck level; the bridge runs along +Y (Godot -Z) and climbs
    1.2 m. Glowing ribs, a glass roof and a lit name plate."""
    reset_scene()
    c = _common()
    glass = nmat("BridgeGlass", "#5aa0ff", rough=0.05, metal=0.3, emit=0.25)
    parts = []
    length, rise, half = 8.0, 1.2, 2.25
    ribs = 6
    for i in range(ribs):
        y = length * i / (ribs - 1)
        z0 = rise * i / (ribs - 1)
        pts = [(half * math.cos(a), y, z0 + 1.05 + 2.3 * math.sin(a) ** 0.8) for a in [math.pi * k / 12 for k in range(13)]]
        pts = [(x, yy, max(z0 + 1.05, z)) for x, yy, z in pts]
        parts.append(tube(f"Rib{i}", pts, 0.07, m=c["steel_dark"], segs=6, cap=True))
        parts.append(tube(f"RibGlow{i}", [(x, yy - 0.08, z) for x, yy, z in pts], 0.03, m=c["cyan"], segs=5, cap=True))
        for s in (-1, 1):
            parts.append(box(f"RibPost{i}{s}", (0.14, 0.14, 1.1), (s * half, y, z0 + 0.55), bevel=0.02, m=c["steel_dark"]))
    # Glass roof panels between ribs (flattened arch segments).
    for i in range(ribs - 1):
        y0, y1 = length * i / (ribs - 1), length * (i + 1) / (ribs - 1)
        zc = rise * (i + 0.5) / (ribs - 1)
        for k in range(6):
            a0, a1 = math.pi * k / 6, math.pi * (k + 1) / 6
            xa, za = half * math.cos(a0), zc + 1.05 + 2.3 * math.sin(a0) ** 0.8
            xb, zb = half * math.cos(a1), zc + 1.05 + 2.3 * math.sin(a1) ** 0.8
            mid = ((xa + xb) / 2, (y0 + y1) / 2, (za + zb) / 2)
            wlen = math.hypot(xb - xa, zb - za)
            ang = math.atan2(zb - za, xb - xa)
            parts.append(box(f"Glass{i}{k}", (wlen, y1 - y0 - 0.12, 0.03), mid, rot=(0, -ang, 0), bevel=0.0, m=glass))
    # Name plate over the south portal.
    parts.append(box("Plate", (2.6, 0.12, 0.45), (0, -0.05, 3.15), bevel=0.03, m=c["ink"]))
    parts.append(sign_text("PlateText", "SKYWALK 7", 0.26, 0.03, (0, -0.13, 3.15), m=c["magenta"]))
    save("neon_skybridge", [merge("SkyBridgeCanopy", parts)])


def build_holo_koi():
    """Giant holographic koi (hologram material), ~8 m long, swimming in place."""
    reset_scene()
    holo = mat("NeonHoloKoi", "#ff5ac8", rough=1.0)
    holo2 = mat("NeonHoloKoiFin", "#5af2ff", rough=1.0)
    parts = [
        sphere("Body", 1.0, (0, 0, 0), scale=(2.6, 0.9, 1.0), m=holo, segs=20, rings=12),
        sphere("Head", 0.85, (2.2, 0, 0.05), scale=(1.0, 0.85, 0.9), m=holo, segs=16, rings=10),
        cyl("Tail", 0.9, 1.6, (-3.2, 0, 0), rot=(0, math.radians(90), 0), segs=4, bevel=0.0, m=holo2, radius_top=0.05),
        prism("TailFin", [(-1.0, -1.2), (0.0, 0.0), (-1.0, 1.2), (-0.4, 0.0)], 0.08, (-3.6, 0, 0), m=holo2),
        prism("DorsalFin", [(-1.2, 0.0), (0.8, 0.0), (-0.6, 1.0)], 0.06, (0.2, 0, 0.85), m=holo2),
    ]
    for s in (-1, 1):
        parts.append(prism(f"Pectoral{s}", [(0.0, 0.0), (0.9, -0.2), (0.4, -0.9)], 0.05, (1.2, s * 0.75, -0.4),
                           rot=(math.radians(s * 50), 0, 0), m=holo2))
        parts.append(tube(f"Whisker{s}", [(3.0, s * 0.3, -0.2), (3.6, s * 0.8, -0.5), (3.9, s * 1.2, -1.0)], 0.04, m=holo2, segs=5))
    save("neon_holo_koi", [merge("SpinKoi", parts)])


def build_holo_can():
    """Holographic ZAP COLA can with a lightning bolt, slowly turning."""
    reset_scene()
    holo = mat("NeonHoloCan", "#ff3a6a", rough=1.0)
    holo2 = mat("NeonHoloBolt", "#ffe45a", rough=1.0)
    parts = [
        cyl("Can", 1.2, 4.2, (0, 0, 2.6), segs=24, bevel=0.15, m=holo),
        cyl("Lid", 1.0, 0.25, (0, 0, 4.85), segs=24, bevel=0.06, m=holo2),
        prism("Bolt", [(-0.2, 1.2), (-0.7, 0.0), (-0.1, 0.0), (-0.4, -1.3), (0.6, 0.3), (0.0, 0.3), (0.3, 1.2)], 0.15,
              (0, -1.22, 2.6), m=holo2),
        torus("Ring", 1.9, 0.06, (0, 0, 0.4), m=holo2, major_segs=40, minor_segs=5),
    ]
    save("neon_holo_can", [merge("SpinCan", parts, pivot=(0, 0, 0))])


ALL = {
    "roof_door": build_roof_door, "freight_elevator": build_freight_elevator, "hatch": build_hatch,
    "helipad": build_helipad, "water_tower": build_water_tower, "skylight": build_skylight,
    "ac_unit": build_ac_unit, "vent": build_vent, "crates": build_crates, "antenna": build_antenna,
    "dish": build_dish, "billboard": build_billboard, "rooftop_sign": build_rooftop_sign,
    "blade_sign": build_blade_sign, "blade_sign_b": build_blade_sign_b, "skybridge": build_skybridge,
    "holo_koi": build_holo_koi, "holo_can": build_holo_can,
}


if __name__ == "__main__":
    wanted = [a for a in sys.argv[1:] if a in ALL] or list(ALL)
    for key in wanted:
        ALL[key]()
