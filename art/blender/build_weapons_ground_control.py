"""First-person viewmodel of Ground Control (ground_control), the radar-ping
primary: a compact purple blaster with a giant white satellite dish for a
muzzle, a fold-out blue solar wing on its right flank, a round radar screen
on its left flank and a whip antenna with a blinking pink beacon.

Same conventions and node contract as build_weapons.py (documented at the top
of weapon_kit.py): origin at the top of the grip, pointing along +Y, its own
palette (set before weapon_mats, so the shared material names stay and every
finish, cell, decal and charm works), built-in sights. Moving parts, driven by
scripts/weapons/views/ground_control_view.gd and
scripts/weapons/reloads/ground_control_reload.gd:

  Dish        the white parabolic dish, struts and pink feed horn (pivot at
              the dish's neck): kicks on every ping
  DishCore    the glowing face inside the dish (its own material "DishCore",
              lime, turned pink by an overcharge)
  Wing1..3    the solar tiles, built open (an accordion chain, each the
              child of the last, pivot on its inner hinge); the view folds
              them shut and opens one per charge step
  Beacon      the pink ball on the whip antenna (blinks faster with charge)
  RadarScreen the round screen (material "RadarScreen", replaced in game by
              the radar sweep shader)
  Cell        the signal-bar meter on the left flank > Bar0..4 (the ammo)
  CellHolo    hologram signal bars for the reload
  SatHolo     the hologram satellite that drifts down into the dish

    python art/blender/build_weapons_ground_control.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403

BARS = 5
WING_TILES = 4
TILE = (0.038, 0.084, 0.005)


def palette(shell, trim, dark, steel, pink):
    """Creates the shared weapon materials in this weapon's colours (weapon_mats reuses them)."""
    mat("Shell", shell, rough=0.32)
    mat("Trim", trim, rough=0.3)
    mat("GunDark", dark, rough=0.55, metal=0.15)
    mat("GunSteel", steel, rough=0.25, metal=0.6)
    mat("GunPink", pink, rough=0.34)


def solar_tile(prefix, centre, M, blue):
    """One solar tile: a dark frame with a blue cell face and silver grid lines."""
    x, y, z = centre
    sx, sy, sz = TILE
    parts = [
        box(prefix + "Frame", (sx, sy, sz), (x, y, z), bevel=0.0015, m=M["dark"]),
        box(prefix + "Face", (sx - 0.006, sy - 0.006, 0.0016), (x, y, z + sz * 0.5), bevel=0.0004, m=blue),
    ]
    for i in (-1, 1):
        parts.append(box(f"{prefix}GridY{i}", (sx - 0.006, 0.0014, 0.0008), (x, y + i * sy / 6, z + sz * 0.5 + 0.0009), bevel=0.0, m=M["steel"]))
    parts.append(box(prefix + "GridX", (0.0014, sy - 0.006, 0.0008), (x, y, z + sz * 0.5 + 0.0009), bevel=0.0, m=M["steel"]))
    return parts


def build_ground_control():
    reset_scene()
    palette("#7b4bd6", "#e4e8f2", "#23203a", "#c8cede", "#ff5fa2")
    M = weapon_mats("#a8e63c", emit=2.0, shell="#7b4bd6", trim="#e4e8f2")
    white = M["trim"]
    blue = mat("SolarBlue", "#2f6fe0", rough=0.2, metal=0.3, emit=0.35)
    core = mat("DishCore", "#a8e63c", rough=0.3, emit=2.4)
    beacon_m = mat("Beacon", "#ff5fa2", rough=0.3, emit=2.2)
    screen_m = mat("RadarScreen", "#103a1c", rough=0.2, emit=0.6)
    grip_loc = (0, -0.03, -0.115)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.07, 0.092, 0.19), body_bottom=-0.02)
    rail_top = 0.13
    z_line = rail_top + SIGHT_HEIGHT
    axis_z = 0.035                       # the barrel line through the dish
    dish_neck = (0, 0.215, axis_z)
    fore = (0, 0.16, -0.07)
    screen_c = (-0.047, 0.035, 0.048)
    bars_c = (-0.043, -0.075, 0.022)
    hinge_x = 0.04
    wing_y = -0.015
    wing_z = 0.082

    shell = grip_parts + [
        # Compact purple receiver with a white belt and a dark sill.
        box("Body", (0.082, 0.23, 0.092), (0, 0.025, 0.03), bevel=0.026, segs=3, m=M["shell"]),
        box("Belt", (0.086, 0.2, 0.014), (0, 0.03, 0.012), bevel=0.005, m=white),
        box("Sill", (0.084, 0.19, 0.016), (0, 0.03, -0.012), bevel=0.006, m=M["dark"]),
        box("Hump", (0.06, 0.15, 0.03), (0, -0.005, 0.082), bevel=0.012, m=M["shell"]),
        box("RailRiser", (0.032, 0.15, 0.03), (0, 0.005, rail_top - 0.024), bevel=0.005, m=M["dark"]),
        # The neck the dish sits on, with a white collar and a lime ring light.
        ycyl("Neck", 0.024, 0.08, 0.175, z=axis_z, m=M["dark"], segs=20, bevel=0.005),
        ring("NeckCollar", 0.026, 0.005, 0.15, z=axis_z, m=white, segs=20),
        ring("NeckLight", 0.025, 0.0035, 0.195, z=axis_z, m=M["cell"], segs=20),
        box("ForegripMount", (0.05, 0.06, 0.05), (0, fore[1], -0.01), bevel=0.008, m=M["dark"]),
        box("Foregrip", (0.042, 0.05, 0.11), fore, bevel=0.016, m=M["dark"]),
        sphere("ForegripKnob", 0.024, (0, fore[1], fore[2] - 0.07), scale=(1, 1, 0.7), m=white, segs=16, rings=10),
        # Short stock with a white butt cap.
        ycyl("Stock", 0.026, 0.09, -0.135, z=0.015, m=M["dark"], segs=20, bevel=0.006),
        ycyl("Butt", 0.03, 0.02, -0.19, z=0.015, m=white, segs=20, bevel=0.006),
        box("StockNeck", (0.05, 0.05, 0.05), (0, -0.095, 0.02), bevel=0.012, m=M["dark"]),
        # Wing hinge rail on the right flank and the fixed first tile's bracket.
        box("WingRail", (0.008, 0.096, 0.012), (hinge_x - 0.002, wing_y, wing_z - 0.006), bevel=0.003, m=M["steel"]),
        # Radar screen housing on the left flank, tipped up toward the eye.
        cyl("RadarBezel", 0.031, 0.012, screen_c, rot=rad(0, -58, 0), segs=28, bevel=0.003, m=white),
        # Whip antenna on the back left, leaning back.
        cyl("AntennaBase", 0.009, 0.014, (-0.028, -0.07, 0.1), segs=12, bevel=0.002, m=M["dark"]),
        tube("Antenna", [(-0.028, -0.07, 0.104), (-0.034, -0.09, 0.118), (-0.042, -0.115, 0.128)], 0.0028, m=M["steel"], segs=8),
        # Signal-bar meter backplate.
        box("BarsPlate", (0.006, 0.07, 0.04), (bars_c[0] + 0.002, bars_c[1], bars_c[2] + 0.01), bevel=0.002, m=M["dark"]),
    ]
    shell += solar_tile("Wing0", (hinge_x + TILE[0] / 2, wing_y, wing_z), M, blue)
    shell += top_rail("TopRail", -0.07, 0.08, rail_top, M, width=0.03)
    shell += bolts("Pin", [(-0.042, 0.11, 0.0), (0.042, 0.11, 0.0), (0.042, -0.07, 0.045)], M["steel"], radius=0.006, height=0.006)
    lug, charm_point = charm_lug(-0.026, -0.165, 0.004, M)
    shell += lug
    sight_rear, sight_front = sights_notch(0.0, -0.06, 0.13, rail_top, 0.126, z_line, M, gap=0.016)
    shell.append(box("FrontSightBase", (0.028, 0.026, 0.05), (0, 0.13, 0.1), bevel=0.004, m=M["dark"]))

    # The dish: a white parabolic bowl opening forward, a rim, three struts
    # and a pink feed-horn ball out front.
    ny = dish_neck[1]
    dish = [
        ycyl("DishBowl", 0.026, 0.07, ny + 0.035, z=axis_z, m=white, segs=36, bevel=0.003, radius_top=0.094),
        ring("DishRim", 0.094, 0.0075, ny + 0.07, z=axis_z, m=white, segs=36),
        ycyl("DishBack", 0.03, 0.012, ny + 0.004, z=axis_z, m=M["dark"], segs=20, bevel=0.003),
        sphere("Horn", 0.015, (0, ny + 0.142, axis_z), m=M["pink"], segs=16, rings=10),
        ycyl("HornNeck", 0.007, 0.02, ny + 0.128, z=axis_z, m=M["steel"], segs=10, bevel=0.002),
    ]
    for i in range(3):
        a = math.radians(90 + i * 120)
        rim = (math.cos(a) * 0.088, ny + 0.07, axis_z + math.sin(a) * 0.088)
        dish.append(tube(f"Strut{i}", [rim, (math.cos(a) * 0.006, ny + 0.126, axis_z + math.sin(a) * 0.006)], 0.0035, m=M["steel"], segs=8))
    dish_core = [ycyl("DishFace", 0.03, 0.06, ny + 0.042, z=axis_z, m=core, segs=36, bevel=0.0, radius_top=0.086)]

    # Solar wing tiles 1..3, open, each hinged on the last one's outer edge.
    wings = {}
    for k in range(1, WING_TILES):
        hinge = (hinge_x + TILE[0] * k + 0.002 * k, wing_y, wing_z)
        centre = (hinge[0] + TILE[0] / 2, wing_y, wing_z)
        wings[f"Wing{k}"] = (solar_tile(f"Wing{k}", centre, M, blue), hinge, f"Wing{k - 1}" if k > 1 else None)

    beacon = [sphere("BeaconBall", 0.0105, (-0.043, -0.118, 0.131), m=beacon_m, segs=14, rings=8)]
    sa = math.radians(-58)
    nrm = (math.sin(sa), 0.0, math.cos(sa))
    screen = [cyl("RadarGlass", 0.025, 0.003, (screen_c[0] + nrm[0] * 0.006, screen_c[1], screen_c[2] + nrm[2] * 0.006),
                  rot=rad(0, -58, 0), segs=28, bevel=0.0, m=screen_m)]

    bx, by, bz = bars_c
    bars = {}
    for i in range(BARS):
        h = 0.008 + i * 0.0065
        c = (bx - 0.002, by - 0.026 + i * 0.013, bz - 0.006 + h / 2)
        bars[f"Bar{i}"] = ([box(f"Bar{i}Glow", (0.005, 0.009, h), c, bevel=0.0012, m=M["cell"])], c)
    cell_base = [box("BarsFoot", (0.008, 0.07, 0.005), (bx - 0.001, by, bz - 0.009), bevel=0.0015, m=M["steel"])]
    cell_holo = holo_copy(cell_base + [p for parts, _c in bars.values() for p in parts])

    # The hologram satellite (in the dish): a box body, two panel wings and a mini dish.
    sc = (0, ny + 0.05, axis_z)
    sat = [
        box("SatBody", (0.03, 0.03, 0.03), sc, bevel=0.004, m=M["holo"]),
        box("SatWingL", (0.05, 0.018, 0.003), (sc[0] - 0.042, sc[1], sc[2]), bevel=0.001, m=M["holo"]),
        box("SatWingR", (0.05, 0.018, 0.003), (sc[0] + 0.042, sc[1], sc[2]), bevel=0.001, m=M["holo"]),
        cyl("SatDish", 0.004, 0.012, (sc[0], sc[1] + 0.02, sc[2]), rot=rad(-90, 0, 0), segs=14, bevel=0.0, m=M["holo"], radius_top=0.014),
    ]

    lightning = [(-0.006, 0.02), (0.01, 0.004), (0.0, 0.0), (0.008, -0.02), (-0.01, -0.002), (0.0, 0.0)]
    decal = [side_emblem("Emblem", lightning, -0.042, -0.02, 0.05, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = vertical_hand(fore, 0.023, 0.027, 0.11, M, (-0.52, -0.16, -0.46))
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.06, rail_top), None),
        "IronSightFront": (sight_front, (0, 0.13, 0.126), None),
        "Dish": (dish, dish_neck, None),
        "DishCore": (dish_core, dish_neck, "Dish"),
        "Beacon": (beacon, (-0.043, -0.118, 0.131), None),
        "RadarScreen": (screen, screen_c, None),
        "Cell": (cell_base, bars_c, None),
        "CellHolo": (cell_holo, bars_c, None),
        "SatHolo": (sat, sc, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    for name, (parts, hinge, parent) in wings.items():
        groups[name] = (parts, hinge, parent)
    for name, (parts, c) in bars.items():
        groups[name] = (parts, c, "Cell")
    empties = {
        "Muzzle": ((0, ny + 0.16, axis_z), None),
        "SightPoint": ((0, -0.06, z_line), None),
        "SightMount": ((0, 0.005, rail_top), None),
        "EjectPoint": ((bx - 0.02, by, bz + 0.02), None),
        "VentPoint": ((0, ny + 0.07, axis_z + 0.1), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("ground_control", groups, empties)


if __name__ == "__main__":
    build_ground_control()
