"""First-person viewmodel of the T-Minus Six (update 12 secondary): a stubby
orange rocket pistol wearing a fat red six-rocket pod on its nose, with a
cream radar dish on a mast at its left shoulder.

Same conventions and node contract as build_weapons.py (documented at the top
of weapon_kit.py): origin at the top of the grip, pointing along +Y, its own
palette (set before weapon_mats, so the shared material names stay and every
finish, cell, decal and charm works). Its moving parts are driven by
scripts/weapons/views/t_minus_six_view.gd and the reload by
scripts/weapons/reloads/t_minus_six_reload.gd:

  Cell        the teal fuel-cell tube along the top-right shoulder
  CellHolo    the reload's hologram launch gantry over the pod (hidden)
  Rocket0..5  the six cream mini-rockets in the pod, red nose cones poking
              out of its mouth (the magazine), each with Arm0..5, its teal
              arming ring, lit while the rocket is painted onto a zombie
  Dish        the radar dish (turns about its mast), Bulb its antenna bulb
  Pip0..5     the lit lock pips on the lock screen at the back
  Count0..2   the countdown light strip on the left flank
  Trigger     the fat yellow trigger

    python art/blender/build_weapons_t_minus_six.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403

ROCKETS = 6
COUNT = 3


def palette():
    """Dune Orange shell, Launch Red trim, Bunker Grip dark (weapon_mats reuses them)."""
    mat("Shell", "#f59a36", rough=0.36)
    mat("Trim", "#e83f3f", rough=0.38)
    mat("GunDark", "#2e2a40", rough=0.5, metal=0.2)
    mat("GunSteel", "#b4aec8", rough=0.3, metal=0.6)
    mat("GunPink", "#fff4dc", rough=0.4)


def rocket(i, centre, M, cream):
    """One mini-rocket lying along +Y in its tube: a cream body and a red nose,
    and its arming ring (a separate group, lit when painted)."""
    x, y, z = centre
    parts = [
        ycyl(f"RocketBody{i}", 0.0105, 0.1, y, z=z, x=x, m=cream, segs=14, bevel=0.002),
        ycyl(f"RocketNose{i}", 0.0105, 0.026, y + 0.063, z=z, x=x, m=M["trim"], segs=14, bevel=0.0015, radius_top=0.0018),
        ring(f"RocketBand{i}", 0.0108, 0.0016, y + 0.045, z=z, x=x, m=M["dark"], segs=14),
    ]
    arm = [ring(f"ArmRing{i}", 0.0122, 0.0021, y + 0.05, z=z, x=x, m=M["cell"], segs=16)]
    return parts, arm


def build_t_minus_six():
    reset_scene()
    palette()
    M = weapon_mats("#3ff0d4", emit=2.2)
    cream = mat("Nosecone", "#fff4dc", rough=0.35)
    hazard = mat("Hazard", "#ffd23f", rough=0.4)
    lamp = mat("CountLight", "#ffd23f", rough=0.3, emit=2.4)
    glass = mat("ScreenGlass", "#0e2128", rough=0.1, metal=0.3)
    grip_loc = (0, -0.022, -0.104)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.07, 0.094, 0.185), body_bottom=-0.03)
    # The kit's trigger becomes the fat yellow one, its own part.
    trig = [p for p in grip_parts if p.name in ("Trigger", "TriggerToe")]
    grip_parts = [p for p in grip_parts if p not in trig]
    for p in trig:
        p.data.materials[0] = hazard
        p.scale = (1.5, 1.25, 1.1)
    y_trig = G["trigger"][0]

    rail_top = 0.1
    z_line = rail_top + SIGHT_HEIGHT
    pod_c = (0.0, 0.205, 0.035)
    pod_r = 0.055
    pod_y0, pod_y1 = 0.145, 0.265
    ring_r = 0.03                         # the rockets' circle in the pod
    dish_c = (-0.058, 0.03, 0.092)        # dish pivot (turns about Z)
    tube_c = (0.026, 0.045, 0.087)        # fuel-cell tube on the top-right shoulder
    screen_y = -0.073

    shell = grip_parts + [
        side_profile("Body", [(-0.07, -0.03), (0.152, -0.03), (0.152, 0.074), (0.124, 0.088), (-0.05, 0.088), (-0.07, 0.07)],
                     0.066, (0, 0, 0), M["shell"], bevel=0.01),
        box("Frame", (0.07, 0.17, 0.03), (0, 0.04, -0.02), bevel=0.011, m=M["dark"]),
        box("BodyStripe", (0.068, 0.17, 0.012), (0, 0.04, 0.03), bevel=0.003, m=M["trim"]),
        side_profile("Tail", [(-0.03, 0.02), (-0.03, -0.024), (-0.06, -0.024), (-0.084, -0.006), (-0.084, 0.008), (-0.062, 0.02)],
                     0.054, (0, 0, 0), M["shell"], bevel=0.006),
        box("RearBlock", (0.044, 0.026, 0.014), (0, -0.058, 0.095), bevel=0.004, m=M["dark"]),
        # The pod: a fat red drum with a cream mouth, a hazard band and a breech ring.
        ycyl("Pod", pod_r, pod_y1 - pod_y0, (pod_y0 + pod_y1) / 2, z=pod_c[2], m=M["trim"], segs=36, bevel=0.008),
        ycyl("PodMouth", pod_r - 0.004, 0.008, pod_y1 + 0.002, z=pod_c[2], m=cream, segs=36, bevel=0.003),
        ycyl("PodFace", pod_r - 0.011, 0.004, pod_y1 + 0.006, z=pod_c[2], m=M["dark"], segs=36, bevel=0.001),
        ring("PodLip", pod_r - 0.004, 0.0035, pod_y1 + 0.006, z=pod_c[2], m=M["steel"], segs=36),
        ycyl("PodBreech", pod_r + 0.002, 0.012, pod_y0 + 0.006, z=pod_c[2], m=M["dark"], segs=36, bevel=0.003),
        ycyl("HazardBand", pod_r + 0.0025, 0.024, 0.228, z=pod_c[2], m=hazard, segs=36, bevel=0.002),
        box("PodMount", (0.05, 0.03, 0.05), (0, 0.15, 0.02), bevel=0.008, m=M["dark"]),
        # Radar mast up from the left shoulder.
        tube("DishMast", [(-0.026, dish_c[1], 0.08), (-0.042, dish_c[1], 0.088), (dish_c[0], dish_c[1], dish_c[2] - 0.002)], 0.0042, m=M["steel"], segs=8),
        box("MastFoot", (0.016, 0.02, 0.008), (-0.024, dish_c[1], 0.086), bevel=0.003, m=M["dark"]),
        # Fuel-cell clamps.
        box("TubeClampR", (0.022, 0.01, 0.014), (tube_c[0], tube_c[1] - 0.06, tube_c[2]), bevel=0.003, m=M["dark"]),
        box("TubeClampF", (0.022, 0.01, 0.014), (tube_c[0], tube_c[1] + 0.06, tube_c[2]), bevel=0.003, m=M["dark"]),
        # The lock screen at the back: a framed dark glass with a teal ring and a crosshair.
        box("ScreenFrame", (0.058, 0.006, 0.046), (0, screen_y + 0.004, 0.046), bevel=0.003, m=M["dark"]),
        box("ScreenGlass", (0.05, 0.004, 0.038), (0, screen_y, 0.046), bevel=0.0015, m=glass),
        torus("ScreenRing", 0.012, 0.0014, (0, screen_y - 0.0022, 0.052), rot=rad(90, 0, 0), m=M["cell"], major_segs=24, minor_segs=4),
        box("ScreenCrossH", (0.03, 0.0015, 0.0012), (0, screen_y - 0.0022, 0.052), bevel=0.0, m=M["cell"]),
        box("ScreenCrossV", (0.0012, 0.0015, 0.03), (0, screen_y - 0.0022, 0.052), bevel=0.0, m=M["cell"]),
        # Countdown strip on the left flank: a dark bezel for three lamps.
        box("CountBezel", (0.004, 0.016, 0.056), (-0.034, 0.1, 0.024), bevel=0.0015, m=M["dark"]),
    ]
    for i in range(ROCKETS):
        shell.append(sphere(f"PipBase{i}", 0.0027, (-0.0175 + i * 0.007, screen_y - 0.0015, 0.034), scale=(1, 0.5, 1), m=M["dark"], segs=8, rings=4))
    # Hazard stripes slanted round the band.
    for i in range(12):
        a = math.tau * i / 12
        shell.append(obox(f"HazardStripe{i}", (0.006, 0.026, 0.0016),
                          (math.cos(a) * (pod_r + 0.0035), 0.228, pod_c[2] + math.sin(a) * (pod_r + 0.0035)),
                          (-math.sin(a), 0.6, math.cos(a)), (math.cos(a), 0, math.sin(a)), bevel=0.0, m=M["dark"]))
    # Tube bores round each rocket at the pod's face, and a centre hub.
    for i in range(ROCKETS):
        a = math.radians(90 + 60 * i)
        shell.append(ring(f"Bore{i}", 0.0128, 0.0022, pod_y1 + 0.008, z=pod_c[2] + math.sin(a) * ring_r, x=math.cos(a) * ring_r, m=M["dark"], segs=16))
    shell.append(ycyl("PodHub", 0.009, 0.01, pod_y1 + 0.008, z=pod_c[2], m=M["steel"], segs=14, bevel=0.002))
    shell += top_rail("TopRail", -0.045, 0.075, rail_top, M, width=0.03)
    shell += bolts("Pin", [(-0.034, -0.03, 0.0), (0.034, -0.03, 0.0), (0.034, 0.12, 0.02)], M["steel"], radius=0.005, height=0.006)
    lug, charm_point = charm_lug(pod_r + 0.003, 0.185, pod_c[2], M, out=1.0)
    shell += lug
    sight_rear, sight_front = sights_notch(0.0, -0.058, 0.25, 0.102, pod_c[2] + pod_r + 0.001, z_line, M, gap=0.016)

    # The six rockets, top one first, round the pod.
    rockets = {}
    for i in range(ROCKETS):
        a = math.radians(90 + 60 * i)
        c = (math.cos(a) * ring_r, 0.222, pod_c[2] + math.sin(a) * ring_r)
        parts, arm = rocket(i, c, M, cream)
        rockets[i] = (parts, arm, c)

    # Fuel cell: a glowing teal tube in two clamps.
    tx, ty, tz = tube_c
    cell = [ycyl("FuelTube", 0.0075, 0.15, ty, z=tz, x=tx, m=M["cell"], segs=14, bevel=0.003),
            ycyl("FuelCapR", 0.0085, 0.008, ty - 0.077, z=tz, x=tx, m=M["steel"], segs=14, bevel=0.002),
            ycyl("FuelCapF", 0.0085, 0.008, ty + 0.077, z=tz, x=tx, m=M["steel"], segs=14, bevel=0.002)]

    # The reload's launch gantry: an arch over the pod, rails up from its mouth.
    holo = M["holo"]
    gantry = []
    for side in (-1, 1):
        gantry.append(box(f"GantryPost{side}", (0.006, 0.008, 0.11), (side * 0.066, 0.2, 0.04), bevel=0.0, m=holo))
        gantry.append(obox(f"GantryRail{side}", (0.13, 0.005, 0.005), (side * 0.02, 0.33, 0.1), (0, 0.86, 0.5), (1, 0, 0), bevel=0.0, m=holo))
    gantry.append(box("GantryBeam", (0.138, 0.008, 0.006), (0, 0.2, 0.097), bevel=0.0, m=holo))
    gantry.append(torus("GantryRing", pod_r + 0.008, 0.002, (0, pod_y1 + 0.012, pod_c[2]), rot=rad(90, 0, 0), m=holo, major_segs=36, minor_segs=4))
    for k in range(4):
        gantry.append(box(f"GantryRung{k}", (0.044, 0.004, 0.003), (0, 0.29 + k * 0.03, 0.082 + k * 0.0175), rot=rad(-30, 0, 0), bevel=0.0, m=holo))

    # Radar dish, tilted out over the left flank, with its glowing antenna bulb.
    dx, dy, dz = dish_c
    tilt = rad(0, -32, 0)
    n = (-math.sin(math.radians(32)), 0.0, math.cos(math.radians(32)))
    dish = [
        cyl("DishHub", 0.0055, 0.006, (dx, dy, dz), segs=12, bevel=0.0015, m=M["dark"]),
        cyl("DishBowl", 0.0045, 0.009, (dx + n[0] * 0.007, dy, dz + n[2] * 0.007), rot=tilt, segs=24, bevel=0.0015, m=cream, radius_top=0.02),
        torus("DishRim", 0.0198, 0.0016, (dx + n[0] * 0.0115, dy, dz + n[2] * 0.0115), rot=tilt, m=M["steel"], major_segs=24, minor_segs=4),
        cyl("DishStalk", 0.0013, 0.014, (dx + n[0] * 0.014, dy, dz + n[2] * 0.014), rot=tilt, segs=6, bevel=0.0, m=M["steel"]),
    ]
    for k in range(3):
        a = math.tau * k / 3
        dish.append(tube(f"DishStrut{k}", [(dx + n[0] * 0.012 + math.cos(a) * 0.016 * n[2], dy + math.sin(a) * 0.016, dz + n[2] * 0.012 - math.cos(a) * 0.016 * n[0]),
                                           (dx + n[0] * 0.02, dy, dz + n[2] * 0.02)], 0.0009, m=M["steel"], segs=4))
    bulb_at = (dx + n[0] * 0.022, dy, dz + n[2] * 0.022)
    bulb = [sphere("BulbGlow", 0.004, bulb_at, m=M["cell"], segs=10, rings=6)]

    # Lit lock pips on the screen.
    pips = {}
    for i in range(ROCKETS):
        at = (-0.0175 + i * 0.007, screen_y - 0.0026, 0.034)
        pips[i] = ([sphere(f"PipLit{i}", 0.0025, at, scale=(1, 0.6, 1), m=M["cell"], segs=8, rings=4)], at)
    # Countdown lamps, bottom (Count0) to top.
    lamps = {}
    for i in range(COUNT):
        at = (-0.0365, 0.1, 0.006 + i * 0.018)
        lamps[i] = ([box(f"Lamp{i}", (0.003, 0.011, 0.012), at, bevel=0.001, m=lamp)], at)

    decal = [side_emblem("Emblem", star_outline(0.016, 0.007), -0.034, 0.03, 0.05, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.42, -0.5, -0.36))
    arm_l, elbow_l = cup_hand(G, M, (-0.55, -0.32, -0.32))
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.058, 0.102), None),
        "IronSightFront": (sight_front, (0, 0.25, pod_c[2] + pod_r), None),
        "Cell": (cell, tube_c, None),
        "CellHolo": (gantry, (0, 0.2, pod_c[2]), None),
        "Dish": (dish, dish_c, None),
        "Bulb": (bulb, bulb_at, "Dish"),
        "Trigger": (trig, (0, y_trig, -0.032), None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, grip_loc, None),
    }
    for i, (parts, arm, c) in rockets.items():
        groups[f"Rocket{i}"] = (parts, c, None)
        groups[f"Arm{i}"] = (arm, c, f"Rocket{i}")
    for i, (parts, at) in pips.items():
        groups[f"Pip{i}"] = (parts, at, None)
    for i, (parts, at) in lamps.items():
        groups[f"Count{i}"] = (parts, at, None)
    empties = {
        "Muzzle": ((0, pod_y1 + 0.03, pod_c[2]), None),
        "SightPoint": ((0, -0.058, z_line), None),
        "SightMount": ((0, 0.015, rail_top), None),
        "EjectPoint": ((0, pod_y0, pod_c[2] - pod_r), None),
        "VentPoint": ((tube_c[0], tube_c[1] - 0.08, tube_c[2]), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("t_minus_six", groups, empties)


if __name__ == "__main__":
    build_t_minus_six()
