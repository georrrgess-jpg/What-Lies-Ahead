"""The giant pink Ferris wheel on the left skyline of Prize Pier.

Exports Stand (frame and platform), Wheel (origin at the hub, so it can spin)
and twelve Gondola_NN nodes parented to the wheel with their origins on the
rim, so the game can keep them hanging upright. The wheel lies in the XZ
plane; its axle runs along Y (Godot Z).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403

R = 13.0
HUB_Z = 16.5
HALF = 1.35
GONDOLAS = 12


def build():
    reset_scene()
    pink, hot, light = mat("Pink"), mat("PinkDark"), mat("PinkLight")
    cream, teal, tdark, wood = mat("Cream"), mat("Teal"), mat("TealDark"), mat("Wood")
    yellow = mat("Yellow")
    amber = glow("BulbAmber", "#ffb030", 1.9)
    white = glow("BulbWhite", "#ffe6b0", 1.7)

    # --- Stand -------------------------------------------------------------
    stand = [
        box("Platform", (24.0, 9.0, 0.8), (0, 0, -0.4), bevel=0.08, m=wood),
        box("PlatformTrim", (24.3, 9.3, 0.3), (0, 0, -0.05), bevel=0.08, m=teal),
        cyl("Axle", 0.55, 2 * HALF + 2.6, (0, 0, HUB_Z), rot=rad(90, 0, 0), segs=14, bevel=0.08, m=tdark),
    ]
    for y in (-HALF - 1.0, HALF + 1.0):
        for x in (-7.5, 7.5):
            stand.append(tube(f"Leg{x}{y}", [(x, y * 1.25, 0), (0, y, HUB_Z)], 0.5, m=hot, segs=8, radius_end=0.36))
            stand.append(box(f"Foot{x}{y}", (1.6, 1.4, 0.6), (x, y * 1.25, 0.3), bevel=0.1, m=teal))
            stand += bulb_row(f"LegBulb{x}{y}", (x * 0.92, y * 1.24 - (0.55 if y < 0 else -0.55), HUB_Z * 0.08),
                              (x * 0.08, y - (0.5 if y < 0 else -0.5), HUB_Z * 0.92), 9, 0.16, amber)
        stand.append(box(f"Tie{y}", (9.0, 0.36, 0.36), (0, y * 1.15, HUB_Z * 0.4), bevel=0.06, m=hot))
        stand.append(cyl(f"Bearing{y}", 1.0, 0.5, (0, y, HUB_Z), rot=rad(90, 0, 0), segs=16, bevel=0.1, m=teal))
    # Little boarding hut and steps so the base reads as a ride.
    stand += [
        box("Hut", (3.2, 2.6, 2.6), (-9.0, -2.4, 1.3), bevel=0.12, m=teal),
        box("HutRoof", (3.8, 3.2, 0.4), (-9.0, -2.4, 2.8), bevel=0.12, m=pink),
        box("HutWindow", (1.6, 0.1, 1.0), (-9.0, -3.72, 1.6), bevel=0.04, m=mat("Dark")),
        box("Ramp", (5.0, 2.2, 0.3), (0, -2.8, 0.6), rot=rad(8, 0, 0), bevel=0.05, m=wood),
    ]

    # --- Wheel -------------------------------------------------------------
    wheel = []
    for y in (-HALF, HALF):
        c = (0, y, HUB_Z)
        wheel += [
            torus(f"Rim{y}", R, 0.3, c, rot=rad(90, 0, 0), m=pink, major_segs=48, minor_segs=8),
            torus(f"RimInner{y}", R * 0.64, 0.17, c, rot=rad(90, 0, 0), m=light, major_segs=40, minor_segs=6),
            torus(f"RimHub{y}", R * 0.3, 0.14, c, rot=rad(90, 0, 0), m=light, major_segs=28, minor_segs=6),
        ]
        for i in range(GONDOLAS * 2):
            a = math.tau * i / (GONDOLAS * 2)
            tip = (math.cos(a) * R, y, HUB_Z + math.sin(a) * R)
            wheel.append(tube(f"Spoke{y}{i:02d}", [c, tip], 0.15 if i % 2 == 0 else 0.09, m=hot if i % 2 == 0 else cream, segs=6))
        out = y - 0.36 if y < 0 else y + 0.36
        wheel += bulb_ring(f"RimBulb{y}", R, 48, out, 0.2, white, centre=(0, HUB_Z), plane="XZ")
        wheel += bulb_ring(f"MidBulb{y}", R * 0.64, 24, out, 0.16, amber, centre=(0, HUB_Z), plane="XZ")
        # Hub: cream disc with the big star.
        face = y - 0.35 if y < 0 else y + 0.35
        wheel.append(cyl(f"HubDisc{y}", 2.5, 0.5, (0, y, HUB_Z), rot=rad(90, 0, 0), segs=28, bevel=0.1, m=hot))
        wheel.append(cyl(f"HubFace{y}", 2.1, 0.3, (0, face, HUB_Z), rot=rad(90, 0, 0), segs=28, bevel=0.06, m=pink))
        wheel.append(star(f"HubStar{y}", 1.6, 0.3, (0, face + (-0.12 if y < 0 else 0.12), HUB_Z), m=cream, bevel=0.04))
        wheel += bulb_ring(f"HubBulb{y}", 2.3, 16, face + (-0.2 if y < 0 else 0.2), 0.14, amber, centre=(0, HUB_Z), plane="XZ")
    for i in range(GONDOLAS):
        a = math.tau * i / GONDOLAS
        p = (math.cos(a) * R, 0, HUB_Z + math.sin(a) * R)
        wheel.append(cyl(f"CrossBar{i:02d}", 0.13, 2 * HALF, p, rot=rad(90, 0, 0), segs=8, bevel=0.0, m=cream))

    # --- Gondolas ----------------------------------------------------------
    cabin_colors = [("Yellow", "Orange"), ("PinkLight", "Pink"), ("PurpleLight", "Purple"), ("TealLight", "Teal")]
    gondola_parts = []
    for i in range(GONDOLAS):
        a = math.tau * i / GONDOLAS
        px, pz = math.cos(a) * R, HUB_Z + math.sin(a) * R
        body, trim = (mat(c) for c in cabin_colors[i % len(cabin_colors)])
        parts = [
            box(f"G{i:02d}Hanger", (0.14, 1.9, 0.9), (px, 0, pz - 0.45), bevel=0.03, m=cream),
            box(f"G{i:02d}Roof", (2.3, 2.0, 0.28), (px, 0, pz - 0.95), bevel=0.1, m=trim),
            box(f"G{i:02d}Cabin", (2.0, 1.75, 1.15), (px, 0, pz - 2.25), bevel=0.2, segs=3, m=body),
            box(f"G{i:02d}Band", (2.06, 1.81, 0.24), (px, 0, pz - 1.8), bevel=0.06, m=trim),
        ]
        for sx in (-0.85, 0.85):
            for sy in (-0.72, 0.72):
                parts.append(cyl(f"G{i:02d}Pole{sx}{sy}", 0.06, 0.8, (px + sx, sy, pz - 1.4), segs=6, bevel=0.0, m=cream))
        gondola_parts.append((i, (px, 0, pz), parts))

    stand_ob = merge("Stand", stand)
    wheel_ob = merge("Wheel", wheel, pivot=(0, 0, HUB_Z))
    exports = [stand_ob, wheel_ob]
    for i, pivot, parts in gondola_parts:
        exports.append(merge(f"Gondola_{i:02d}", parts, pivot=pivot, parent=wheel_ob))
    save("ferris_wheel", exports)


if __name__ == "__main__":
    build()
