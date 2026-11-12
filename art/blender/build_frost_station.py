"""The loadout station for Summit Lodge: a red timber ski-rental hut with a
propped-up service shutter, a lit 'SKI RENTAL' sign on the ridge, ski and
snowboard displays on both flanks and lanterns at the corners.

    frost_station.glb    origin = centre of the hut's footprint; counter faces -Y.
    Footprint ~6 x 4.4 m (matches the Body collider in scenes/props/frost_station.tscn).

    python art/blender/build_frost_station.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from frost_common import *  # noqa: F401,F403


def build_station():
    reset_scene()
    red, red_dark = mat("FrostHutRed", "#c8323c", rough=0.55), mat("FrostHutRedDark", "#8e2232", rough=0.6)
    white, timber, dark = fmat("Cream", rough=0.6), fmat("Timber"), fmat("TimberDark")
    roof, snow = fmat("Roof", rough=0.7), snow_mat()
    stone = fmat("Stone", rough=0.85)
    amber = fglow("FrostBulbAmber", "#ffc46b", 3.0)
    lantern = fglow("FrostLantern", "#ffc46b", 3.2)
    glow = fglow("FrostHutInterior", "#ffb766", 1.8)
    cyan = fglow("FrostSignCyanGlow", "#7ff0ff", 2.6)
    hw, hd, wall = 2.3, 1.9, 3.1
    ridge = 5.1
    parts = [
        box("Plinth", (2 * hw + 0.5, 2 * hd + 0.5, 0.35), (0, 0, 0.175), bevel=0.08, m=stone),
        box("Back", (2 * hw, 0.3, wall), (0, hd, 0.35 + wall / 2), bevel=0.05, m=red),
        box("SideL", (0.3, 2 * hd, wall), (-hw, 0, 0.35 + wall / 2), bevel=0.05, m=red),
        box("SideR", (0.3, 2 * hd, wall), (hw, 0, 0.35 + wall / 2), bevel=0.05, m=red),
        # Front: counter below, a wide service opening above it.
        box("FrontLow", (2 * hw, 0.3, 1.15), (0, -hd, 0.35 + 0.575), bevel=0.05, m=red),
        box("FrontTop", (2 * hw, 0.3, 0.55), (0, -hd, 0.35 + wall - 0.275), bevel=0.05, m=red),
        box("FrontPostL", (0.5, 0.3, wall), (-hw + 0.25, -hd, 0.35 + wall / 2), bevel=0.05, m=red),
        box("FrontPostR", (0.5, 0.3, wall), (hw - 0.25, -hd, 0.35 + wall / 2), bevel=0.05, m=red),
        box("Counter", (2 * hw - 0.6, 0.7, 0.12), (0, -hd - 0.15, 1.56), bevel=0.04, m=timber),
        box("Interior", (2 * hw - 0.8, 0.12, 1.4), (0, hd - 0.4, 2.2), bevel=0.0, m=glow),
        box("InteriorShelf", (3.2, 0.4, 0.08), (0, hd - 0.5, 2.0), bevel=0.02, m=dark),
        # Propped shutter forming an awning over the counter.
        box("Shutter", (2 * hw - 0.4, 1.3, 0.1), (0, -hd - 0.62, 3.05), rot=rad(-22, 0, 0), bevel=0.04, m=red_dark),
        box("ShutterStripe", (2 * hw - 0.36, 0.2, 0.12), (0, -hd - 1.18, 2.83), rot=rad(-22, 0, 0), bevel=0.03, m=white),
    ]
    for i, x in enumerate((-hw + 0.6, hw - 0.6)):
        parts.append(tube(f"Prop{i}", [(x, -hd - 0.1, 1.6), (x, -hd - 1.15, 2.78)], 0.035, m=dark, segs=6))
    parts += snow_cap("ShutterSnow", (2 * hw - 0.6, 1.0, 0.1), (0, -hd - 0.62, 3.13), rot=rad(-22, 0, 0), drips=6, seed=3)
    # White corner trims and window boxes.
    for i, (x, y) in enumerate(((-hw, -hd), (hw, -hd), (-hw, hd), (hw, hd))):
        parts.append(box(f"Trim{i}", (0.36, 0.36, wall + 0.1), (x, y, 0.35 + wall / 2), bevel=0.06, m=white))
    for s, sx in (("L", -1), ("R", 1)):
        parts += window(f"SideWin{s}", 1.2, 0.9, (sx * (hw + 0.17), 0.2, 2.2), mullions=(2, 2), rot_z=sx * math.pi / 2)
    # Steep gable roof, ridge along X, heavy snow.
    for side, sy in (("F", -1), ("B", 1)):
        length = math.hypot(hd + 0.8, ridge - (0.35 + wall))
        ang = math.atan2(ridge - (0.35 + wall), hd + 0.8)
        centre = (0, sy * (hd + 0.8) / 2, (0.35 + wall + ridge) / 2 + 0.15)
        parts.append(box(f"Roof{side}", (2 * hw + 1.2, length, 0.25), centre, rot=(-sy * ang, 0, 0), bevel=0.06, m=roof))
        parts.append(box(f"RoofSnow{side}", (2 * hw + 1.0, length - 0.2, 0.32), (0, centre[1] + sy * 0.05, centre[2] + 0.28),
                         rot=(-sy * ang, 0, 0), bevel=0.14, m=snow))
        parts += icicles(f"HutIcicle{side}", (-hw - 0.55, sy * (hd + 0.85), 0.35 + wall - 0.05), (hw + 0.55, sy * (hd + 0.85), 0.35 + wall - 0.05), 10, 0.45, seed=5 + sy)
    # Gable ends.
    for s, sx in (("L", -1), ("R", 1)):
        outline = [(-hd - 0.15, 0.35 + wall), (hd + 0.15, 0.35 + wall), (0.0, ridge - 0.1)]
        tri = prism(f"Gable{s}", outline, 0.3, (0, 0, 0), m=red)
        tri.rotation_euler = (0, 0, math.pi / 2)
        tri.location = (sx * hw, 0, 0)
        parts.append(tri)
    parts.append(sphere("RidgeSnow", 0.32, (0, 0, ridge + 0.32), scale=(hw * 3.4, 1.0, 0.6), m=snow, segs=12, rings=6))
    # 'SKI RENTAL' sign on the ridge, ringed with bulbs.
    parts += [
        box("SignBoard", (4.0, 0.2, 1.0), (0, -0.3, ridge + 0.85), bevel=0.08, m=fmat("Navy")),
        box("SignFrame", (4.2, 0.16, 1.2), (0, -0.22, ridge + 0.85), bevel=0.06, m=dark),
        text("SignText", "SKI RENTAL", 0.56, 0.06, (0, -0.44, ridge + 0.82), m=cyan),
        text("SignTextBack", "SKI RENTAL", 0.56, 0.06, (0, -0.0, ridge + 0.82), rot=(0, 0, math.pi), m=cyan),
        box("SignStrut", (0.2, 0.2, 0.8), (0, -0.2, ridge + 0.1), bevel=0.03, m=dark),
    ]
    parts += snow_cap("SignSnow", (3.9, 0.24, 0.12), (0, -0.25, ridge + 1.45), drips=6, seed=8)
    parts += bulb_row("SignBulbTop", (-1.95, -0.42, ridge + 1.32), (1.95, -0.42, ridge + 1.32), 10, 0.065, amber)
    parts += bulb_row("SignBulbLow", (-1.95, -0.42, ridge + 0.38), (1.95, -0.42, ridge + 0.38), 10, 0.065, amber)
    # Ski and board displays on the flanks.
    colours = ["#e2343f", "#3fd4ff", "#ffd23f", "#8a4fe0", "#3fc46a", "#ff7a2a"]
    for s, sx in (("L", -1), ("R", 1)):
        x = sx * (hw + 0.55)
        parts += [
            box(f"RackRail{s}", (0.14, 2.6, 0.12), (x, 0, 1.9), bevel=0.03, m=dark),
            box(f"RackFoot{s}", (0.5, 2.6, 0.12), (x, 0, 0.42), bevel=0.03, m=dark),
        ]
        for i in range(5):
            y = -1.0 + i * 0.5
            m = mat(f"FrostRentalSki{i}", colours[(i + (0 if sx < 0 else 3)) % len(colours)], rough=0.4)
            if i % 2 == 0:
                parts.append(box(f"Board{s}{i}", (0.06, 0.3, 1.5), (x + sx * 0.08, y, 1.2), rot=rad(0, sx * -8, 0), bevel=0.12, segs=3, m=m))
            else:
                for k, dy in enumerate((-0.06, 0.06)):
                    parts.append(box(f"Ski{s}{i}{k}", (0.04, 0.08, 1.75), (x + sx * 0.06, y + dy, 1.28), rot=rad(0, sx * -8, 0), bevel=0.015, m=m))
    # Corner lanterns and a chalkboard price list.
    for i, sx in enumerate((-1, 1)):
        parts += [
            box(f"LanternArm{i}", (0.5, 0.08, 0.08), (sx * (hw + 0.3), -hd - 0.1, 3.0), bevel=0.02, m=dark),
            box(f"LanternBox{i}", (0.22, 0.22, 0.3), (sx * (hw + 0.5), -hd - 0.1, 2.75), bevel=0.03, m=lantern),
            bulb(f"LanternHalo{i}", 0.15, (sx * (hw + 0.5), -hd - 0.1, 2.75), lantern),
        ]
    parts += [
        box("Chalkboard", (0.9, 0.08, 1.1), (1.5, -hd - 0.95, 0.95), rot=rad(-12, 0, 0), bevel=0.03, m=mat("FrostChalk", "#1e2a2a", rough=0.9)),
        box("ChalkFrame", (1.0, 0.06, 1.2), (1.5, -hd - 0.91, 0.95), rot=rad(-12, 0, 0), bevel=0.03, m=timber),
        text("ChalkText", "SKIS 5\nBOOTS 3\nCOCOA 2", 0.12, 0.01, (1.5, -hd - 1.0, 1.0), rot=(math.radians(-12), 0, 0), m=fmat("White")),
    ]
    save("frost_station", [merge("Station", parts)])


if __name__ == "__main__":
    build_station()
