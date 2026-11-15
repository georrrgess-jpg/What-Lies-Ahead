"""First-person viewmodels for the update-8 weapons of lane guns8: the Teacup
Twister (vortex launcher, primary) and the Dunk Tank (water pistol, secondary).

Same conventions and node contract as build_weapons.py (documented at the top
of weapon_kit.py): origin at the top of the grip, pointing along +Y, each
weapon in its own palette (set before weapon_mats, so the shared material
names stay and every finish, cell, decal and charm works), built-in sights,
full-detail glove shapes. Moving parts are driven by view scripts
(scripts/weapons/views/) and reload scripts (scripts/weapons/reloads/):

  teacup_twister  Drum (the teacup carousel round the barrel, turns a quarter
                  per shot) > Cup0..3 (the loaded teacup shells), Cell (the
                  glowing hub), CellHolo (hologram cups for the reload);
                  Saucer (the spinning saucer rim on the teacup muzzle), Swirl
                  (candy swirl on the left flank, whirls after each shot)
  dunk_tank       Cell (the water tank hung under the front) > Water (the
                  water column, scaled with the magazine; pivot at its
                  bottom), CellHolo, Pump (pink pump sleeve on the nozzle),
                  Needle (pressure gauge on the left flank), Target (the
                  dunk-tank bullseye on its hinge)

    python art/blender/build_weapons_guns8.py [weapon_id ...]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403

CUPS = 4


def palette(shell, trim, dark, steel, pink, steel_metal=0.55):
    """Creates the shared weapon materials in this weapon's colours (weapon_mats reuses them)."""
    mat("Shell", shell, rough=0.34)
    mat("Trim", trim, rough=0.4)
    mat("GunDark", dark, rough=0.45, metal=0.2)
    mat("GunSteel", steel, rough=0.3, metal=steel_metal)
    mat("GunPink", pink, rough=0.36)


def ycone(name, r0, r1, length, y, z, m, segs=24, x=0.0):
    """A cone along the barrel axis: radius r0 at the back, r1 at the front."""
    return ycyl(name, r0, length, y, z=z, x=x, m=m, segs=segs, bevel=0.003, radius_top=r1)


# ---------------------------------------------------------------------------
# Teacup Twister: vortex launcher
# ---------------------------------------------------------------------------

def teacup(prefix, y, z, x, M, body, handle_side):
    """One loaded teacup shell lying along the barrel, mouth forward: the cup,
    a gold band, the swirl glowing in its mouth and a little handle."""
    parts = [
        ycone(prefix + "Body", 0.017, 0.025, 0.07, y, z, body, segs=16, x=x),
        ycyl(prefix + "Foot", 0.014, 0.012, y - 0.04, z=z, x=x, m=M["steel"], segs=14, bevel=0.002),
        ring(prefix + "Band", 0.0225, 0.0028, y + 0.012, z=z, x=x, m=M["steel"], segs=16),
        ycyl(prefix + "Swirl", 0.019, 0.004, y + 0.034, z=z, x=x, m=M["cell"], segs=14, bevel=0.0),
    ]
    hx, hz = handle_side
    parts.append(torus(prefix + "Handle", 0.012, 0.0032, (x + hx * 0.022, y + 0.002, z + hz * 0.022),
                       rot=(0, math.atan2(hz, hx), math.pi / 2), m=body, major_segs=12, minor_segs=5, arc=math.pi, start=-math.pi / 2))
    return parts


def build_teacup_twister():
    reset_scene()
    palette("#fff0f6", "#8a4fd8", "#2a2140", "#e3b55a", "#ff5fa8", steel_metal=0.6)
    M = weapon_mats("#ff7ad9", emit=1.8)
    mint = mat("Mint", "#7fe8cf", rough=0.4)
    bore_z = 0.045
    rail_top = 0.116
    z_line = rail_top + SIGHT_HEIGHT
    fore = (0, 0.46, -0.036)
    drum_c = (0, 0.25, bore_z)
    drum_r = 0.052
    swirl_c = (-0.052, 0.035, 0.032)
    saucer_y = 0.592
    grip_loc = (0, -0.05, -0.12)
    grip_parts, G = grip("", grip_loc, M, tilt=-15, size=(0.07, 0.09, 0.18), body_bottom=-0.03)
    shell = grip_parts + [
        # China-white receiver over a lavender keel, with mint and pink candy bands.
        box("Receiver", (0.084, 0.27, 0.1), (0, 0.01, 0.028), bevel=0.03, m=M["shell"]),
        box("Keel", (0.08, 0.2, 0.032), (0, 0.0, -0.014), bevel=0.012, m=M["trim"]),
        box("RailRiser", (0.04, 0.22, 0.016), (0, 0.01, 0.097), bevel=0.004, m=M["dark"]),
        box("BandMint", (0.088, 0.03, 0.09), (0, 0.11, 0.03), bevel=0.012, m=mint),
        box("BandPink", (0.088, 0.016, 0.086), (0, -0.09, 0.03), bevel=0.006, m=M["pink"]),
        # Barrel through the carousel, ending in the teacup muzzle.
        ycyl("Barrel", 0.03, 0.4, 0.34, z=bore_z, m=M["trim"], segs=22),
        ring("BarrelBandA", 0.031, 0.0045, 0.37, z=bore_z, m=M["steel"], segs=22),
        ring("BarrelBandB", 0.031, 0.0045, 0.52, z=bore_z, m=M["steel"], segs=22),
        ycyl("DrumPlateR", 0.082, 0.012, drum_c[1] - 0.078, z=bore_z, m=M["trim"], segs=28, bevel=0.004),
        ycyl("DrumPlateF", 0.082, 0.012, drum_c[1] + 0.078, z=bore_z, m=M["trim"], segs=28, bevel=0.004),
        ring("DrumPlateRimR", 0.082, 0.004, drum_c[1] - 0.078, z=bore_z, m=M["steel"], segs=28),
        ring("DrumPlateRimF", 0.082, 0.004, drum_c[1] + 0.078, z=bore_z, m=M["steel"], segs=28),
        ycone("CupMuzzle", 0.034, 0.068, 0.075, 0.55, bore_z, M["pink"], segs=28),
        ycyl("CupLip", 0.07, 0.008, 0.588, z=bore_z, m=M["shell"], segs=28, bevel=0.003),
        ycyl("CupBore", 0.054, 0.006, 0.59, z=bore_z, m=mat("Bore", "#1a1230", rough=0.9), segs=24, bevel=0.0),
        ring("CupGlow", 0.058, 0.0035, 0.592, z=bore_z, m=M["cell"], segs=28),
        torus("CupHandle", 0.026, 0.0075, (-0.062, 0.548, bore_z), rot=(0, math.pi / 2, 0), m=M["pink"],
              major_segs=16, minor_segs=6, arc=math.pi * 1.1, start=math.pi * 0.95),
        # Handguard and its neck under the barrel.
        box("Foregrip", (0.07, 0.11, 0.046), fore, bevel=0.014, m=M["trim"]),
        box("ForegripNeck", (0.012, 0.05, 0.034), (0, fore[1], 0.0), bevel=0.003, m=M["steel"]),
        box("ForegripCap", (0.074, 0.012, 0.05), (0, fore[1] + 0.06, fore[2]), bevel=0.004, m=M["pink"]),
        # Short stock with a gold butt and a pink ticket fin.
        box("Stock", (0.05, 0.15, 0.07), (0, -0.19, 0.0), bevel=0.014, m=M["shell"]),
        box("Butt", (0.052, 0.016, 0.08), (0, -0.27, 0.0), bevel=0.006, m=M["steel"]),
        side_profile("TicketFin", [(-0.25, 0.032), (-0.14, 0.032), (-0.19, 0.062), (-0.255, 0.066)], 0.008, (0, 0, 0), M["pink"], bevel=0.003),
        # The swirl's axle boss on the left wall.
        xcyl("SwirlBoss", 0.016, 0.012, (-0.044, swirl_c[1], swirl_c[2]), m=M["dark"], segs=14),
    ]
    for i in range(3):
        shell.append(box(f"StockStripe{i}", (0.052, 0.012, 0.072), (0, -0.23 + i * 0.03, 0.0), bevel=0.002, m=mint if i % 2 == 0 else M["pink"]))
    for i in range(4):
        shell.append(box(f"Porthole{i}", (0.004, 0.016, 0.016), (0.043, -0.06 + i * 0.035, 0.05), rot=rad(45, 0, 0), bevel=0.0, m=M["cell"]))
        a = math.tau * i / 4 + math.pi / 4
        shell.append(sphere(f"PlateBulb{i}", 0.006, (math.cos(a) * 0.07, drum_c[1] + 0.086, bore_z + math.sin(a) * 0.07), m=M["cell"], segs=8, rings=5))
    for i in range(6):
        a = math.tau * i / 6
        shell.append(sphere(f"LipBead{i}", 0.0055, (math.cos(a) * 0.072, 0.585, bore_z + math.sin(a) * 0.072), m=M["steel"], segs=8, rings=5))
    shell += top_rail("TopRail", -0.1, 0.12, rail_top, M, width=0.034, pitch=0.036)
    shell += bolts("Pin", [(-0.042, -0.07, 0.0), (0.042, -0.07, 0.0), (0.042, 0.06, 0.0)], M["steel"], radius=0.006, height=0.007)
    lug, charm_point = charm_lug(-0.027, -0.2, 0.022, M)
    shell += lug
    sight_rear, sight_front = sights_ghost_ring(0.0, -0.08, 0.5, rail_top, bore_z + 0.03, z_line, M)

    # The carousel: a scalloped hub with four teacup shells round the barrel.
    dx, dy, dz = drum_c
    drum = [
        ycyl("DrumHub", 0.036, 0.13, dy, z=dz, m=M["dark"], segs=20),
        prism("DrumStarR", star_outline(0.07, 0.05, points=8, rotation=22.5), 0.008, loc=(0, dy - 0.06, dz), m=M["pink"], bevel=0.002),
        prism("DrumStarF", star_outline(0.07, 0.05, points=8, rotation=22.5), 0.008, loc=(0, dy + 0.06, dz), m=M["pink"], bevel=0.002),
    ]
    hub = [ring("HubGlowR", 0.037, 0.004, dy - 0.03, z=dz, m=M["cell"], segs=20),
           ring("HubGlowF", 0.037, 0.004, dy + 0.03, z=dz, m=M["cell"], segs=20)]
    cups = {}
    holo_src = []
    for k in range(CUPS):
        a = math.tau * k / CUPS + math.pi / 4
        cx, cz = math.cos(a) * drum_r, dz + math.sin(a) * drum_r
        body = M["shell"] if k % 2 == 0 else mint
        parts = teacup(f"Cup{k}", dy + 0.004, cz, cx, M, body, (math.cos(a), math.sin(a)))
        cups[f"Cup{k}"] = (parts, (cx, dy, cz))
        holo_src.append(parts[0])
    cell_holo = holo_copy(holo_src)

    # Saucer rim on the muzzle: spins with every shot like the ride's floor.
    saucer = [torus("SaucerRing", 0.077, 0.0065, (0, saucer_y, bore_z), rot=rad(90, 0, 0), m=M["steel"], major_segs=32, minor_segs=6)]
    for i in range(8):
        a = math.tau * i / 8
        saucer.append(sphere(f"SaucerBulb{i}", 0.006, (math.cos(a) * 0.077, saucer_y - 0.003, bore_z + math.sin(a) * 0.077),
                             m=M["cell"] if i % 2 == 0 else M["shell"], segs=8, rings=5))
    # Candy swirl on the left flank.
    sx, sy, sz = swirl_c
    swirl = [xcyl("SwirlDisc", 0.026, 0.006, swirl_c, m=M["shell"], segs=24),
             xcyl("SwirlHub", 0.007, 0.01, (sx - 0.004, sy, sz), m=M["cell"], segs=10)]
    for i in range(4):
        a0 = math.tau * i / 4
        pts = []
        for s in range(8):
            u = s / 7
            ang = a0 + u * 2.2
            r = 0.005 + u * 0.019
            pts.append((sx - 0.0035, sy + math.cos(ang) * r, sz + math.sin(ang) * r))
        swirl.append(tube(f"SwirlArm{i}", pts, 0.0034, m=M["pink"] if i % 2 == 0 else M["trim"], segs=6, radius_end=0.0018))

    cup_outline = [(-0.014, 0.012), (0.014, 0.012), (0.01, -0.01), (-0.01, -0.01)]
    decal = [side_emblem("Emblem", cup_outline, -0.0425, -0.05, 0.035, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = support_hand(fore, 0.035, 0.023, M, (-0.6, 0.25, -0.45), corner=0.014, finger_len=0.025, thumb_len=0.03)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.08, rail_top), None),
        "IronSightFront": (sight_front, (0, 0.5, bore_z + 0.03), None),
        "Drum": (drum, drum_c, None),
        "Cell": (hub, drum_c, "Drum"),
        "CellHolo": (cell_holo, drum_c, "Drum"),
        "Saucer": (saucer, (0, saucer_y, bore_z), None),
        "Swirl": (swirl, swirl_c, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    for name, (parts, centre) in cups.items():
        groups[name] = (parts, centre, "Drum")
    empties = {
        "Muzzle": ((0, 0.6, bore_z), None),
        "SightPoint": ((0, -0.08, z_line), None),
        "SightMount": ((0, 0.03, rail_top), None),
        "EjectPoint": ((0, dy, bore_z - 0.07), None),
        "VentPoint": ((0, 0.585, bore_z + 0.06), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("teacup_twister", groups, empties)


# ---------------------------------------------------------------------------
# Dunk Tank: water pistol
# ---------------------------------------------------------------------------

def build_dunk_tank():
    reset_scene()
    palette("#4cc3ff", "#ffd23f", "#1d2a4a", "#cdd6e4", "#ff4f7b", steel_metal=0.5)
    M = weapon_mats("#5ff0ff", emit=1.6)
    white = mat("TargetWhite", "#fbf7ee", rough=0.4)
    grip_loc = (0, -0.014, -0.112)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.068, 0.09, 0.185), body_bottom=-0.035)
    rail_top = 0.112
    z_line = rail_top + SIGHT_HEIGHT
    bore_z = 0.058
    tank_c = (0, 0.2, -0.098)           # centre of the water tank under the front
    tank_r = 0.029
    tank_h = 0.1
    gauge_c = (-0.0435, 0.0, 0.062)
    target_c = (-0.044, 0.14, 0.066)
    pump_y = 0.285

    shell = grip_parts + [
        box("Frame", (0.074, 0.25, 0.07), (0, 0.105, 0.0), bevel=0.02, m=M["trim"]),
        box("FrameNose", (0.06, 0.05, 0.05), (0, 0.235, 0.012), bevel=0.016, m=M["trim"]),
        side_profile("Receiver", [(-0.052, 0.03), (0.238, 0.03), (0.238, 0.08), (0.224, 0.1), (-0.036, 0.1), (-0.054, 0.085)],
                     0.086, (0, 0, 0), M["shell"], bevel=0.012),
        side_profile("Beavertail", [(-0.02, 0.012), (-0.02, -0.03), (-0.05, -0.03), (-0.08, -0.014), (-0.08, 0.0), (-0.06, 0.012)],
                     0.056, (0, 0, 0), M["trim"], bevel=0.006),
        box("RearPlate", (0.066, 0.008, 0.05), (0, -0.054, 0.062), bevel=0.003, m=M["dark"]),
        # Nozzle: a dark shroud, a long steel spout and a pink tip.
        ycyl("Shroud", 0.026, 0.05, 0.255, z=bore_z, m=M["dark"], segs=18),
        ycyl("Spout", 0.0115, 0.13, 0.33, z=bore_z, m=M["steel"], segs=14),
        ring("SpoutBand", 0.013, 0.003, 0.36, z=bore_z, m=M["cell"], segs=14),
        ycone("SpoutTip", 0.016, 0.0085, 0.026, 0.405, bore_z, M["pink"], segs=16),
        ycyl("SpoutHole", 0.005, 0.004, 0.4185, z=bore_z, m=mat("Bore", "#0b1a2a", rough=0.9), segs=10, bevel=0.0),
        # Tank yoke under the front, a feed pipe up into the frame.
        box("TankYoke", (0.05, 0.07, 0.014), (tank_c[0], tank_c[1], tank_c[2] + tank_h / 2 + 0.012), bevel=0.004, m=M["dark"]),
        ycyl("FeedPipe", 0.008, 0.04, tank_c[1] + 0.04, z=-0.03, m=M["steel"], segs=10),
        # Gauge housing and the bullseye's hinge on the left flank.
        xcyl("GaugeBezel", 0.019, 0.008, gauge_c, m=M["steel"], segs=24),
        xcyl("GaugeFace", 0.0155, 0.004, (gauge_c[0] - 0.0045, gauge_c[1], gauge_c[2]), m=white, segs=22),
        box("TargetHinge", (0.006, 0.012, 0.012), (target_c[0] + 0.004, target_c[1], target_c[2] + 0.028), bevel=0.002, m=M["steel"]),
        box("RightPanel", (0.006, 0.12, 0.034), (0.045, 0.12, 0.066), bevel=0.003, m=M["dark"]),
    ]
    for i in range(4):
        shell.append(box(f"RightSlit{i}", (0.004, 0.016, 0.022), (0.0485, 0.075 + i * 0.03, 0.066), rot=rad(18, 0, 0), bevel=0.0, m=M["cell"]))
    for i in range(5):
        a = math.radians(200 - i * 35)
        shell.append(box(f"GaugeTick{i}", (0.002, 0.0035, 0.0012), (gauge_c[0] - 0.007, gauge_c[1] + math.cos(a) * 0.0115, gauge_c[2] + math.sin(a) * 0.0115),
                         rot=(a, 0, 0), bevel=0.0, m=M["pink"] if i == 4 else M["dark"]))
    for i in range(3):
        shell.append(box(f"Pip{i}", (0.012, 0.006, 0.012), (-0.017 + i * 0.017, -0.0585, 0.05), bevel=0.003, m=M["cell"]))
    shell += top_rail("TopRail", 0.012, 0.19, rail_top, M, width=0.032)
    shell += bolts("Pin", [(-0.0395, 0.03, -0.02), (0.0395, 0.03, -0.02), (0.0395, 0.2, 0.01)], M["steel"], radius=0.006, height=0.007)
    lug, charm_point = charm_lug(0.037, 0.2, -0.014, M, out=1.0)
    shell += lug
    sight_rear, sight_front = sights_notch(0.0, -0.03, 0.212, 0.1, 0.1, z_line, M, gap=0.015)

    # The water tank: caps, a cage of four rods and the glowing water inside.
    tx, ty, tz = tank_c
    top_z, bot_z = tz + tank_h / 2, tz - tank_h / 2
    tank = [
        cyl("TankCapTop", tank_r + 0.004, 0.012, (tx, ty, top_z), segs=22, bevel=0.003, m=M["pink"]),
        cyl("TankCapBottom", tank_r + 0.004, 0.014, (tx, ty, bot_z), segs=22, bevel=0.004, m=M["pink"]),
        cyl("TankValve", 0.009, 0.014, (tx, ty, bot_z - 0.012), segs=12, bevel=0.002, m=M["trim"]),
        torus("TankBand", tank_r + 0.0015, 0.0028, (tx, ty, tz), m=M["trim"], major_segs=24, minor_segs=5),
    ]
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        tank.append(cyl(f"TankRod{i}", 0.0032, tank_h, (tx + math.cos(a) * tank_r, ty + math.sin(a) * tank_r, tz), segs=8, bevel=0.0, m=M["steel"]))
    water_h = tank_h - 0.016
    water_base = (tx, ty, bot_z + 0.007)
    water = [cyl("WaterColumn", tank_r - 0.003, water_h, (tx, ty, water_base[2] + water_h / 2), segs=22, bevel=0.002, m=M["cell"])]
    for i in range(3):
        water.append(sphere(f"Bubble{i}", 0.004 - i * 0.0006, (tx + 0.012 - i * 0.01, ty - 0.012 + i * 0.008, water_base[2] + 0.02 + i * 0.022),
                            m=white, segs=8, rings=5))
    tank_holo = holo_copy(tank[:2] + water[:1])

    # Pump sleeve on the spout, the gauge needle and the dunk-tank bullseye.
    pump = [ycyl("PumpSleeve", 0.019, 0.05, pump_y, z=bore_z, m=M["pink"], segs=18, bevel=0.004)]
    for i in range(4):
        pump.append(ring(f"PumpRib{i}", 0.0195, 0.0028, pump_y - 0.018 + i * 0.012, z=bore_z, m=M["trim"], segs=18))
    gx, gy, gz = gauge_c
    needle = [box("NeedleBar", (0.0025, 0.0022, 0.012), (gx - 0.008, gy, gz + 0.005), bevel=0.0, m=M["pink"]),
              xcyl("NeedleHub", 0.003, 0.004, (gx - 0.008, gy, gz), m=M["dark"], segs=8)]
    target = []
    for i, (r, m) in enumerate(((0.024, white), (0.018, M["pink"]), (0.012, white), (0.006, M["pink"]))):
        target.append(xcyl(f"Ring{i}", r, 0.004, (target_c[0] - 0.001 - i * 0.0012, target_c[1], target_c[2]), m=m, segs=24))
    target.append(box("TargetArm", (0.004, 0.006, 0.026), (target_c[0] + 0.002, target_c[1], target_c[2] + 0.016), bevel=0.001, m=M["steel"]))

    drop = [(0.0, 0.016), (0.008, 0.002), (0.006, -0.008), (0.0, -0.012), (-0.006, -0.008), (-0.008, 0.002)]
    decal = [side_emblem("Emblem", drop, -0.0435, 0.2, 0.065, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.42, -0.5, -0.36))
    arm_l, elbow_l = cup_hand(G, M, (-0.55, -0.32, -0.32))
    hinge = (target_c[0], target_c[1], target_c[2] + 0.028)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.03, 0.1), None),
        "IronSightFront": (sight_front, (0, 0.212, 0.1), None),
        "Cell": (tank, tank_c, None),
        "Water": (water, water_base, "Cell"),
        "CellHolo": (tank_holo, tank_c, None),
        "Pump": (pump, (0, pump_y, bore_z), None),
        "Needle": (needle, (gx - 0.008, gy, gz), None),
        "Target": (target, hinge, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, grip_loc, None),
    }
    empties = {
        "Muzzle": ((0, 0.42, bore_z), None),
        "SightPoint": ((0, -0.03, z_line), None),
        "SightMount": ((0, 0.1, rail_top), None),
        "EjectPoint": ((tx, ty, bot_z - 0.02), None),
        "VentPoint": ((0, 0.41, bore_z + 0.02), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("dunk_tank", groups, empties)


BUILDERS = (
    ("teacup_twister", build_teacup_twister),
    ("dunk_tank", build_dunk_tank),
)

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for name, fn in BUILDERS:
        if not only or name in only:
            fn()
