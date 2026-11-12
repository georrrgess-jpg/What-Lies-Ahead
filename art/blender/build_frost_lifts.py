"""Frostpeak Resort lifts: the chairlift landing, towers and chairs, and the
gondola station, towers and cabins. The cable loop and the moving carriers
are assembled in Godot (tools/build_summit_lodge.gd + scripts/props/frost_lift.gd).

    frost_lift_station.glb    chairlift landing; origin = floor centre, front (-Y) faces the plaza.
                              Bull wheel centre at (0, 1.6, 5.2), radius 2.3 (cable lines at x = +-2.3).
    frost_lift_tower.glb      sheave line at 9.5 m, lines at x = +-2.3.
    frost_lift_chair.glb      origin = cable grip; seat hangs 2.4 m below, faces -Y (travel).
    frost_gondola_station.glb origin = floor centre, front (-Y) open bay; wheel at (0, 1.5, 5.6), radius 1.9.
    frost_gondola_tower.glb   sheave line at 12 m, lines at x = +-1.9.
    frost_gondola_cabin.glb   origin = cable grip; cabin hangs below, faces -Y.

    python art/blender/build_frost_lifts.py [lift_station] [lift_tower] [lift_chair] [gondola_station] ...
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from frost_common import *  # noqa: F401,F403


def steel():
    return mat("FrostLiftSteel", "#3c4a7a", rough=0.4, metal=0.45)


def bull_wheel(prefix, radius, loc):
    """Horizontal bull wheel with spokes, plus a drive housing on top."""
    s, dark = steel(), fmat("SteelDark", rough=0.4, metal=0.5)
    x, y, z = loc
    parts = [
        torus(prefix + "Rim", radius, 0.12, (x, y, z), m=dark, major_segs=32, minor_segs=6),
        cyl(prefix + "Hub", 0.45, 0.5, (x, y, z), segs=14, bevel=0.05, m=s),
    ]
    for i in range(8):
        a = math.tau * i / 8
        parts.append(box(f"{prefix}Spoke{i}", (radius, 0.1, 0.1), (x + math.cos(a) * radius / 2, y + math.sin(a) * radius / 2, z),
                         rot=(0, 0, a), bevel=0.0, m=dark))
    return parts


def build_lift_station():
    """Chairlift top landing: steel terminal over the bull wheel, canopy on four
    posts, operator booth and a snowy unload ramp toward the plaza."""
    reset_scene()
    s, dark = steel(), fmat("SteelDark", rough=0.4, metal=0.5)
    roof, snow = fmat("Roof", rough=0.7), snow_mat()
    timber, glass = fmat("Timber"), glass_mat()
    red, white = fmat("Red", rough=0.45), fmat("White")
    wheel_y, wheel_z = 1.6, 5.2
    parts = [
        box("Ramp", (8.0, 6.0, 0.5), (0, -1.0, 0.25), bevel=0.1, m=mat("FrostRampSnow", "#d6d5f6", rough=0.8)),
        box("RampLip", (8.2, 0.4, 0.3), (0, -4.0, 0.15), bevel=0.1, m=snow),
        cyl("Column", 0.55, wheel_z - 0.6, (0, wheel_y + 0.4, (wheel_z - 0.6) / 2), segs=14, bevel=0.05, m=s),
        box("ColumnFoot", (1.8, 1.8, 0.5), (0, wheel_y + 0.4, 0.25), bevel=0.1, m=fmat("StoneDark")),
        # Terminal housing (the hood over the wheel).
        box("Housing", (5.6, 6.2, 1.4), (0, wheel_y + 0.6, wheel_z + 1.0), bevel=0.4, segs=3, m=red),
        box("HousingStripe", (5.7, 6.3, 0.24), (0, wheel_y + 0.6, wheel_z + 0.6), bevel=0.06, m=white),
        box("HousingNose", (5.0, 0.6, 1.0), (0, wheel_y - 2.7, wheel_z + 0.9), bevel=0.3, segs=3, m=red),
        text("HousingText", "SUMMIT EXPRESS", 0.36, 0.04, (0, wheel_y - 3.04, wheel_z + 1.15), m=white),
        box("HousingLampBar", (4.0, 0.2, 0.12), (0, wheel_y - 3.02, wheel_z + 0.38), bevel=0.04, m=fglow("FrostLiftLamp", "#bff4ff", 2.2)),
    ]
    parts += bull_wheel("Wheel", 2.3, (0, wheel_y, wheel_z))
    parts += snow_cap("HousingSnow", (5.2, 5.8, 0.3), (0, wheel_y + 0.6, wheel_z + 1.65), drips=8, seed=31)
    # Canopy on four posts (posts at x = +-4.6, y = -3.4 / +3.4).
    for i, (x, y) in enumerate(((-4.6, -3.4), (4.6, -3.4), (-4.6, 3.4), (4.6, 3.4))):
        parts += [
            box(f"Post{i}", (0.4, 0.4, 7.0), (x, y, 3.5), bevel=0.06, m=s),
            box(f"PostFoot{i}", (0.7, 0.7, 0.4), (x, y, 0.2), bevel=0.08, m=fmat("StoneDark")),
        ]
    parts += [
        box("CanopyFrameF", (9.8, 0.3, 0.4), (0, -3.4, 7.0), bevel=0.06, m=dark),
        box("CanopyFrameB", (9.8, 0.3, 0.4), (0, 3.4, 7.0), bevel=0.06, m=dark),
        box("Canopy", (10.6, 8.2, 0.3), (0, 0, 7.35), bevel=0.08, m=roof),
    ]
    parts += snow_cap("CanopySnow", (10.4, 8.0, 0.35), (0, 0, 7.5), drips=10, seed=33)
    parts += icicles("CanopyIcicle", (-5.2, -4.15, 7.2), (5.2, -4.15, 7.2), 14, 0.55, seed=34)
    parts += bulb_row("CanopyBulb", (-5.0, -4.2, 7.08), (5.0, -4.2, 7.08), 12, 0.08, fglow("FrostBulbAmber", "#ffc46b", 3.0))
    # Operator booth on the north side.
    bx, by = 3.6, 1.8
    parts += [
        box("Booth", (1.9, 1.9, 2.5), (bx, by, 1.75), bevel=0.08, m=timber),
        box("BoothRoof", (2.4, 2.4, 0.25), (bx, by, 3.1), bevel=0.08, m=roof),
        box("BoothBase", (2.0, 2.0, 0.5), (bx, by, 0.25), bevel=0.06, m=fmat("StoneDark")),
    ]
    parts += window("BoothWin", 1.3, 0.9, (bx, by - 0.98, 2.2), mullions=(2, 1))
    parts += window("BoothWinS", 1.3, 0.9, (bx - 0.98, by, 2.2), mullions=(2, 1), rot_z=0.0)
    parts += snow_cap("BoothSnow", (2.2, 2.2, 0.22), (bx, by, 3.2), drips=4, seed=35)
    # 'UNLOAD HERE' board and a fence along the ramp edge.
    parts += [
        box("UnloadPost", (0.14, 0.14, 2.4), (-3.4, -3.0, 1.2), bevel=0.02, m=dark),
        box("UnloadBoard", (1.6, 0.08, 0.6), (-3.4, -3.08, 2.4), bevel=0.03, m=fmat("Yellow")),
        text("UnloadText", "UNLOAD", 0.26, 0.03, (-3.4, -3.14, 2.4), m=fmat("Charcoal")),
    ]
    save("frost_lift_station", [merge("LiftStation", parts)])


def tower(name, height, half_span, prefix):
    s, dark = steel(), fmat("SteelDark", rough=0.4, metal=0.5)
    parts = [
        cyl(prefix + "Column", 0.42, height - 0.6, (0, 0, (height - 0.6) / 2), segs=10, bevel=0.0, m=s, radius_top=0.28),
        box(prefix + "Foot", (1.6, 1.6, 0.8), (0, 0, 0.4), bevel=0.1, m=fmat("StoneDark")),
        box(prefix + "Crossarm", (half_span * 2 + 0.6, 0.4, 0.4), (0, 0, height - 0.4), bevel=0.06, m=dark),
        box(prefix + "Ladder", (0.3, 0.06, height - 1.5), (0, -0.4, (height - 1.5) / 2 + 0.6), bevel=0.0, m=dark),
    ]
    for i, sx in enumerate((-1, 1)):
        parts += [
            box(f"{prefix}Sheave{i}", (0.3, 2.2, 0.3), (sx * half_span, 0, height - 0.12), bevel=0.08, m=fmat("Yellow")),
            cyl(f"{prefix}WheelA{i}", 0.2, 0.18, (sx * half_span, -0.7, height - 0.1), rot=rad(0, 90, 0), segs=10, bevel=0.0, m=dark),
            cyl(f"{prefix}WheelB{i}", 0.2, 0.18, (sx * half_span, 0.7, height - 0.1), rot=rad(0, 90, 0), segs=10, bevel=0.0, m=dark),
        ]
        parts += snow_cap(f"{prefix}SheaveSnow{i}", (0.34, 1.8, 0.1), (sx * half_span, 0, height + 0.03), drips=0)
    parts += snow_cap(prefix + "ArmSnow", (half_span * 2, 0.44, 0.12), (0, 0, height - 0.2), drips=4, seed=7)
    parts.append(bulb(prefix + "Beacon", 0.12, (0, 0, height + 0.05), fglow("FrostTowerLamp", "#ff5a4a", 3.0)))
    save(name, [merge(prefix + "Tower", parts)])


def build_lift_tower():
    reset_scene()
    tower("frost_lift_tower", 9.5, 2.3, "LT")


def build_gondola_tower():
    reset_scene()
    tower("frost_gondola_tower", 12.0, 1.9, "GT")


def build_lift_chair():
    """Quad chair hanging 2.4 m below its grip; faces -Y (direction of travel)."""
    reset_scene()
    s, dark = steel(), fmat("SteelDark", rough=0.4, metal=0.5)
    seat = mat("FrostChairSeat", "#ffb21f", rough=0.5)
    back = mat("FrostChairBack", "#e2343f", rough=0.5)
    parts = [
        box("Grip", (0.3, 0.6, 0.3), (0, 0, -0.1), bevel=0.08, m=dark),
        tube("Hanger", [(0, 0, -0.2), (0, 0.15, -1.2), (0, 0.35, -2.0), (0, 0.35, -2.25)], 0.06, m=s, segs=8),
        box("Frame", (2.1, 0.12, 0.12), (0, 0.35, -2.3), bevel=0.03, m=s),
        box("Seat", (2.0, 0.6, 0.14), (0, 0.05, -2.42), bevel=0.06, m=seat),
        box("Back", (2.0, 0.12, 0.7), (0, 0.38, -2.02), rot=rad(-8, 0, 0), bevel=0.05, m=back),
        tube("Bar", [(-0.95, 0.35, -1.75), (-0.95, -0.45, -1.6), (0.95, -0.45, -1.6), (0.95, 0.35, -1.75)], 0.03, m=dark, segs=6),
        box("FootRest", (1.2, 0.3, 0.05), (0, -0.55, -2.7), bevel=0.02, m=dark),
        tube("FootStrut", [(0, -0.45, -1.62), (0, -0.55, -2.68)], 0.025, m=dark, segs=5),
    ]
    for i in range(3):
        parts.append(box(f"Divider{i}", (0.06, 0.5, 0.08), (-0.5 + i * 0.5, 0.05, -2.32), bevel=0.02, m=dark))
    parts += snow_cap("SeatSnow", (1.8, 0.45, 0.06), (0, 0.05, -2.35), drips=4, seed=41)
    save("frost_lift_chair", [merge("LiftChair", parts)])


def build_gondola_station():
    """Gondola terminal: open bay to the plaza (x -4..4), cabins swing round the
    wheel inside, cables leave through the open back."""
    reset_scene()
    s, dark = steel(), fmat("SteelDark", rough=0.4, metal=0.5)
    roof, snow = fmat("Roof", rough=0.7), snow_mat()
    timber, stone = fmat("Timber"), fmat("Stone", rough=0.85)
    cyan = fglow("FrostGondolaSign", "#5ee8ff", 2.4)
    w, d, h = 12.0, 9.0, 7.6
    parts = [
        box("Floor", (w, d, 0.3), (0, 0, 0.15), bevel=0.05, m=fmat("StoneDark")),
        box("SideA", (0.6, d, h), (-w / 2, 0, h / 2), bevel=0.06, m=stone),
        box("SideB", (0.6, d, h), (w / 2, 0, h / 2), bevel=0.06, m=stone),
        box("BackLow", (w, 0.6, 3.6), (0, d / 2, 1.8), bevel=0.06, m=stone),
        box("PierA", (1.6, 0.8, h), (-5.0, -d / 2 + 0.4, h / 2), bevel=0.06, m=timber),
        box("PierB", (1.6, 0.8, h), (5.0, -d / 2 + 0.4, h / 2), bevel=0.06, m=timber),
        box("Header", (w + 0.4, 0.9, 1.4), (0, -d / 2 + 0.4, h - 0.3), bevel=0.08, m=fmat("Navy")),
        text("Sign", "GONDOLA", 0.85, 0.08, (0, -d / 2 - 0.12, h - 0.3), m=cyan),
        box("Ceiling", (w - 0.8, d - 0.6, 0.2), (0, 0, h - 0.9), bevel=0.0, m=dark),
        box("CeilingGlow", (4.0, 0.5, 0.06), (0, -1.5, h - 1.04), bevel=0.0, m=fglow("FrostStationLight", "#e8f4ff", 2.0)),
        box("CeilingGlowB", (4.0, 0.5, 0.06), (0, 2.0, h - 1.04), bevel=0.0, m=fglow("FrostStationLight", "#e8f4ff", 2.0)),
        box("Turnstile", (2.8, 0.6, 1.0), (0, -2.8, 0.8), bevel=0.08, m=fmat("Red", rough=0.5)),
    ]
    parts += bull_wheel("Wheel", 1.9, (0, 1.5, 5.6))
    parts.append(cyl("WheelMount", 0.3, 1.1, (0, 1.5, 6.2), segs=10, bevel=0.0, m=s))
    # Roof: broad gable with deep snow.
    ridge = h + 2.6
    for side, sx in (("A", -1), ("B", 1)):
        length = math.hypot(w / 2 + 0.9, ridge - h)
        ang = math.atan2(ridge - h, w / 2 + 0.9)
        parts.append(box(f"Roof{side}", (length, d + 1.6, 0.35), (sx * (w / 4 + 0.45), 0, (h + ridge) / 2 + 0.2), rot=(0, sx * ang, 0), bevel=0.06, m=roof))
        parts.append(box(f"RoofSnow{side}", (length - 0.4, d + 1.4, 0.35), (sx * (w / 4 + 0.35), 0, (h + ridge) / 2 + 0.52), rot=(0, sx * ang, 0), bevel=0.15, m=snow))
    parts += icicles("StationIcicle", (-w / 2 - 0.6, -d / 2 - 0.75, h + 0.15), (w / 2 + 0.6, -d / 2 - 0.75, h + 0.15), 16, 0.6, seed=51)
    parts += bulb_row("StationBulb", (-w / 2, -d / 2 - 0.1, h - 1.1), (w / 2, -d / 2 - 0.1, h - 1.1), 14, 0.08, fglow("FrostBulbAmber", "#ffc46b", 3.0))
    for i, x in enumerate((-w / 2 - 0.1, w / 2 + 0.1)):
        parts += window(f"SideWin{i}", 2.2, 1.4, (x, 0.5, 3.4), mullions=(2, 1), rot_z=math.pi / 2 if i else -math.pi / 2)
    save("frost_gondola_station", [merge("GondolaStation", parts)])


def build_gondola_cabin():
    """Red eight-seat cabin hanging from its grip; warm-lit windows; faces -Y."""
    reset_scene()
    s, dark = steel(), fmat("SteelDark", rough=0.4, metal=0.5)
    red, white = fmat("Red", rough=0.4), fmat("White")
    glass = mat("FrostCabinGlass", "#ffd79a", rough=0.2, emit=1.4)
    top = -1.3
    parts = [
        box("Grip", (0.3, 0.7, 0.3), (0, 0, -0.1), bevel=0.08, m=dark),
        tube("Hanger", [(0, 0, -0.2), (0, 0, top + 0.1)], 0.07, m=s, segs=8),
        box("RoofCap", (1.5, 1.4, 0.25), (0, 0, top - 0.1), bevel=0.1, m=dark),
        box("Body", (1.9, 1.7, 2.0), (0, 0, top - 1.2), bevel=0.35, segs=3, m=red),
        box("Stripe", (1.94, 1.74, 0.2), (0, 0, top - 1.95), bevel=0.08, m=white),
        box("WinF", (1.5, 0.08, 0.75), (0, -0.84, top - 0.95), bevel=0.06, m=glass),
        box("WinB", (1.5, 0.08, 0.75), (0, 0.84, top - 0.95), bevel=0.06, m=glass),
        box("WinL", (0.08, 1.3, 0.75), (-0.94, 0, top - 0.95), bevel=0.06, m=glass),
        box("WinR", (0.08, 1.3, 0.75), (0.94, 0, top - 0.95), bevel=0.06, m=glass),
        box("Floor", (1.7, 1.5, 0.15), (0, 0, top - 2.25), bevel=0.06, m=dark),
    ]
    parts += snow_cap("RoofSnow", (1.3, 1.2, 0.12), (0, 0, top + 0.03), drips=3, seed=61)
    save("frost_gondola_cabin", [merge("GondolaCabin", parts)])


BUILDERS = {
    "lift_station": build_lift_station, "lift_tower": build_lift_tower, "lift_chair": build_lift_chair,
    "gondola_station": build_gondola_station, "gondola_tower": build_gondola_tower, "gondola_cabin": build_gondola_cabin,
}


if __name__ == "__main__":
    wanted = [a for a in sys.argv[1:] if a in BUILDERS] or list(BUILDERS)
    for key in wanted:
        BUILDERS[key]()
