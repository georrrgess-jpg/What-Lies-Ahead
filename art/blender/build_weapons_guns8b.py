"""First-person viewmodels for two update-8 sidearms: the Shutterbug (flash
camera) and the Balloon Darter (dart pistol).

Same conventions and node contract as build_weapons.py (documented at the top
of weapon_kit.py): origin at the top of the grip, pointing along +Y, each with
its own palette (set before weapon_mats, so the shared material names stay and
every finish, cell, decal and charm works), built-in sights and accent ("Cell")
colour. Their extra moving parts are driven by view scripts
(scripts/weapons/views/, WeaponData.view_script) and reload scripts
(scripts/weapons/reloads/):

  shutterbug      icy  Cell (the flash wheel on the left flank) > Bulb0..7 (one
                       flashbulb per shot; the wheel turns the next one to the
                       top), CellHolo, Iris (shutter blades in the lens, snap
                       on every shot), Focus (focus ring, turns as the player
                       aims), Winder (film lever on top, cocked after a shot)
  balloon_darter  lime Cell (the dart clip under the barrel) > Tail0..5 (dart
                       tails showing the clip's count), CellHolo, Dart (the
                       dart loaded in the top channel), Plunger (air pump at
                       the back, snaps on every shot), Needle (helium gauge),
                       BalloonHolo (a balloon blown up on the muzzle in the
                       reload, hidden until then)

    python art/blender/build_weapons_guns8b.py [weapon_id ...]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403

BULBS = 8
TAILS = 6


def palette(shell, trim, dark, steel, pink, steel_metal=0.6):
    """Creates the shared weapon materials in this weapon's colours (weapon_mats reuses them)."""
    mat("Shell", shell, rough=0.36)
    mat("Trim", trim, rough=0.4)
    mat("GunDark", dark, rough=0.5, metal=0.2)
    mat("GunSteel", steel, rough=0.28, metal=steel_metal)
    mat("GunPink", pink, rough=0.38)


# ---------------------------------------------------------------------------
# Shutterbug: flash camera
# ---------------------------------------------------------------------------

def build_shutterbug():
    reset_scene()
    palette("#f6ecd6", "#3d5ce0", "#1e1a2e", "#c2bfd6", "#ff4f8b")
    M = weapon_mats("#bdeeff", emit=2.0)
    lens_m = mat("LensGlass", "#16264a", rough=0.08, metal=0.4)
    grip_loc = (0, -0.014, -0.112)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.068, 0.09, 0.185), body_bottom=-0.035)
    rail_top = 0.112
    z_line = rail_top + SIGHT_HEIGHT
    lens_z = 0.026
    body_y0, body_y1 = -0.03, 0.16
    wheel_c = (-0.06, 0.098, 0.034)       # flash wheel axle (across the weapon, axis X)
    wheel_r = 0.034
    wind_c = (0.028, -0.006, 0.0985)      # film lever pivot (turns about Z)

    body_len = body_y1 - body_y0
    body_mid = (body_y0 + body_y1) / 2
    shell = grip_parts + [
        # The camera body: cream top and bottom, a leatherette wrap round the middle.
        box("Body", (0.084, body_len, 0.122), (0, body_mid, 0.026), bevel=0.016, m=M["shell"]),
        box("BodyWrap", (0.088, body_len - 0.03, 0.07), (0, body_mid, 0.024), bevel=0.006, m=M["trim"]),
        box("TopPlate", (0.072, body_len - 0.012, 0.014), (0, body_mid, 0.09), bevel=0.005, m=M["steel"]),
        box("BasePlate", (0.08, body_len - 0.02, 0.01), (0, body_mid, -0.036), bevel=0.004, m=M["steel"]),
        box("RearPlate", (0.07, 0.008, 0.08), (0, body_y0 - 0.002, 0.03), bevel=0.003, m=M["dark"]),
        # The lens: a stepped barrel, a chrome bezel, deep blue glass and a glowing ring.
        ycyl("LensMount", 0.042, 0.016, body_y1 + 0.006, z=lens_z, m=M["steel"], segs=28, bevel=0.004),
        ycyl("LensBarrel", 0.036, 0.046, body_y1 + 0.036, z=lens_z, m=M["dark"], segs=28, bevel=0.004),
        ycyl("LensHood", 0.034, 0.012, body_y1 + 0.064, z=lens_z, m=M["steel"], segs=28, bevel=0.003, radius_top=0.039),
        ring("LensGlow", 0.0285, 0.0028, body_y1 + 0.066, z=lens_z, m=M["cell"], segs=28),
        ycyl("LensGlass", 0.026, 0.004, body_y1 + 0.058, z=lens_z, m=lens_m, segs=28, bevel=0.0),
        sphere("LensGlint", 0.0055, (0.011, body_y1 + 0.061, lens_z + 0.011), scale=(1, 0.3, 1), m=M["shell"], segs=8, rings=5),
        # The flash wheel's arm out of the left flank, and a chrome reflector collar.
        xcyl("WheelAxle", 0.008, 0.016, (-0.048, wheel_c[1], wheel_c[2]), m=M["dark"], segs=12),
        box("WheelBracket", (0.006, 0.05, 0.03), (-0.0445, wheel_c[1], wheel_c[2]), bevel=0.003, m=M["steel"]),
        # Top: shutter button, a recording light, the film counter and the winder's boss.
        cyl("ShutterButton", 0.0075, 0.008, (0.029, 0.12, 0.1), segs=14, bevel=0.002, m=M["pink"]),
        cyl("ShutterCollar", 0.011, 0.004, (0.029, 0.12, 0.096), segs=16, bevel=0.0015, m=M["steel"]),
        sphere("ReadyLight", 0.0045, (-0.028, 0.112, 0.098), m=M["cell"], segs=10, rings=6),
        box("Counter", (0.014, 0.014, 0.004), (-0.029, 0.136, 0.098), bevel=0.0015, m=M["dark"]),
        cyl("WindBoss", 0.009, 0.006, (wind_c[0], wind_c[1], 0.095), segs=14, bevel=0.002, m=M["dark"]),
        # Strap lugs and a pink strap stub on the right.
        box("StrapLug", (0.006, 0.014, 0.014), (0.045, 0.142, 0.06), bevel=0.003, m=M["steel"]),
        box("StrapStub", (0.004, 0.03, 0.012), (0.049, 0.122, 0.06), rot=rad(18, 0, 0), bevel=0.002, m=M["pink"]),
        # Right flank: a vent grille for the flash capacitor.
        box("RightPanel", (0.005, 0.07, 0.03), (0.044, 0.07, 0.024), bevel=0.003, m=M["dark"]),
    ]
    for i in range(5):
        shell.append(box(f"RightSlit{i}", (0.004, 0.008, 0.022), (0.0465, 0.046 + i * 0.012, 0.024), bevel=0.0, m=M["cell"]))
    for i in range(6):
        a = math.tau * i / 6
        shell.append(box(f"LensRib{i}", (0.006, 0.012, 0.004), (math.cos(a) * 0.036, body_y1 + 0.052, lens_z + math.sin(a) * 0.036),
                         rot=(0, -a, 0), bevel=0.0, m=M["steel"]))
    for i in range(4):
        for side in (-1, 1):
            shell.append(sphere(f"WrapStud{i}{side}", 0.003, (side * 0.0445, 0.0 + i * 0.03, 0.05), scale=(0.5, 1, 1), m=M["dark"], segs=6, rings=4))
    shell += top_rail("TopRail", 0.0, 0.128, rail_top, M, width=0.032)
    shell += bolts("Pin", [(-0.0425, 0.02, -0.02), (0.0425, 0.02, -0.02), (0.0425, 0.14, 0.0)], M["steel"], radius=0.005, height=0.006)
    lug, charm_point = charm_lug(0.044, 0.004, -0.014, M, out=1.0)
    shell += lug
    sight_rear, sight_front = sights_frame(0.0, -0.016, 0.148, 0.097, 0.097, z_line, M, m_frame=M["dark"])

    # Focus ring round the lens barrel: a knurled pink band, turned as the player aims.
    focus = [ycyl("FocusBand", 0.039, 0.016, body_y1 + 0.03, z=lens_z, m=M["pink"], segs=28, bevel=0.003)]
    for i in range(16):
        a = math.tau * i / 16
        focus.append(box(f"FocusKnurl{i}", (0.004, 0.017, 0.004), (math.cos(a) * 0.0395, body_y1 + 0.03, lens_z + math.sin(a) * 0.0395),
                         rot=(0, -a, 0), bevel=0.0, m=M["dark"]))
    focus.append(box("FocusTab", (0.008, 0.012, 0.01), (-0.04, body_y1 + 0.03, lens_z - 0.02), bevel=0.003, m=M["cell"]))

    # Shutter iris inside the hood: six blades, a quick twist on every shot.
    iris = []
    for i in range(6):
        a = math.tau * i / 6
        iris.append(obox(f"IrisBlade{i}", (0.02, 0.0016, 0.012),
                         (math.cos(a) * 0.022, body_y1 + 0.0615, lens_z + math.sin(a) * 0.022),
                         (-math.sin(a + 0.5), 0, math.cos(a + 0.5)), (0, 1, 0), bevel=0.0, m=M["steel"]))

    # Film winder: a lever lying on the top plate, pointing back over the right.
    wx, wy, wz = wind_c
    winder = [cyl("WindHub", 0.0065, 0.006, (wx, wy, wz), segs=12, bevel=0.0015, m=M["steel"]),
              box("WindLever", (0.006, 0.03, 0.004), (wx + 0.006, wy - 0.014, wz + 0.001), rot=rad(0, 0, 22), bevel=0.0015, m=M["steel"]),
              cyl("WindTip", 0.0048, 0.008, (wx + 0.0115, wy - 0.028, wz + 0.003), segs=10, bevel=0.0015, m=M["pink"])]

    # The flash wheel: a drum on the left flank turning about X, a bulb in a
    # chrome cup on its rim every 45 degrees; the one facing forward fires.
    cx, cy, cz = wheel_c
    wheel = [
        xcyl("WheelDrum", wheel_r, 0.014, (cx, cy, cz), m=M["steel"], segs=32, bevel=0.003),
        xcyl("WheelFace", wheel_r - 0.008, 0.004, (cx - 0.008, cy, cz), m=M["trim"], segs=32, bevel=0.0015),
        torus("WheelRim", wheel_r - 0.001, 0.0026, (cx - 0.0075, cy, cz), rot=rad(0, 90, 0), m=M["pink"], major_segs=32, minor_segs=5),
        xcyl("WheelHub", 0.009, 0.006, (cx - 0.011, cy, cz), m=M["dark"], segs=14),
        sphere("WheelHubCap", 0.0055, (cx - 0.014, cy, cz), m=M["cell"], segs=10, rings=6),
    ]
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        wheel.append(box(f"WheelSpoke{i}", (0.002, 0.004, wheel_r - 0.016), (cx - 0.0105, cy + math.cos(a) * (wheel_r - 0.008) / 2,
                         cz + math.sin(a) * (wheel_r - 0.008) / 2), rot=(a - math.pi / 2, 0, 0), bevel=0.0, m=M["shell"]))
    bulbs = {}
    for k in range(BULBS):
        a_deg = 360.0 * k / BULBS
        a = math.radians(a_deg)
        dy, dz = math.cos(a), math.sin(a)
        cup_at = (cx, cy + dy * (wheel_r + 0.003), cz + dz * (wheel_r + 0.003))
        wheel.append(cyl(f"Cup{k}", 0.0085, 0.008, cup_at, rot=rad(a_deg - 90, 0, 0), segs=12, bevel=0.002, m=M["dark"], radius_top=0.0105))
        b_at = (cx, cy + dy * (wheel_r + 0.011), cz + dz * (wheel_r + 0.011))
        c_at = (cx, cy + dy * (wheel_r + 0.013), cz + dz * (wheel_r + 0.013))
        bulbs[f"Bulb{k}"] = ([sphere(f"BulbGlass{k}", 0.0072, b_at, scale=(1, 1, 1.2), rot=rad(a_deg - 90, 0, 0), m=M["cell"], segs=10, rings=7),
                              sphere(f"BulbCore{k}", 0.003, c_at, m=M["shell"], segs=6, rings=4)], b_at)
    wheel_holo = holo_copy(wheel[:3])

    decal = [side_emblem("Emblem", star_outline(0.016, 0.007), -0.044, 0.0, 0.024, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.42, -0.5, -0.36))
    arm_l, elbow_l = cup_hand(G, M, (-0.55, -0.32, -0.32))
    top_bulb = (cx, cy + wheel_r + 0.02, cz)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.016, 0.097), None),
        "IronSightFront": (sight_front, (0, 0.148, 0.097), None),
        "Cell": (wheel, wheel_c, None),
        "CellHolo": (wheel_holo, wheel_c, None),
        "Focus": (focus, (0, body_y1 + 0.03, lens_z), None),
        "Iris": (iris, (0, body_y1 + 0.0615, lens_z), None),
        "Winder": (winder, wind_c, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, grip_loc, None),
    }
    for name, (parts, pivot) in bulbs.items():
        groups[name] = (parts, pivot, "Cell")
    empties = {
        "Muzzle": ((0, body_y1 + 0.07, lens_z), None),
        "SightPoint": ((0, -0.016, z_line), None),
        "SightMount": ((0, 0.064, rail_top), None),
        "EjectPoint": ((cx - 0.01, cy, cz - wheel_r), None),
        "VentPoint": ((0.05, 0.07, 0.03), None),
        "FlashPoint": (top_bulb, None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("shutterbug", groups, empties)


# ---------------------------------------------------------------------------
# Balloon Darter: dart pistol
# ---------------------------------------------------------------------------

def dart(prefix, y0, length, z, M, x=0.0, vane_m=None):
    """A dart lying along +Y from y0: steel needle, pink barrel, three vanes at the back."""
    vane_m = vane_m or M["cell"]
    parts = [
        ycyl(prefix + "Needle", 0.0022, length * 0.32, y0 + length * 0.84, z=z, x=x, m=M["steel"], segs=8, bevel=0.0, radius_top=0.0006),
        ycyl(prefix + "Barrel", 0.0048, length * 0.42, y0 + length * 0.47, z=z, x=x, m=M["pink"], segs=10, bevel=0.0015),
        ycyl(prefix + "Shaft", 0.0026, length * 0.3, y0 + length * 0.15, z=z, x=x, m=M["shell"], segs=8, bevel=0.0),
    ]
    for i in range(3):
        a = math.radians(90 + 120 * i)
        parts.append(obox(f"{prefix}Vane{i}", (0.011, length * 0.22, 0.0014),
                          (x + math.cos(a) * 0.0062, y0 + length * 0.1, z + math.sin(a) * 0.0062),
                          (math.cos(a), 0, math.sin(a)), (0, 1, 0), bevel=0.0, m=vane_m))
    return parts


def build_balloon_darter():
    reset_scene()
    palette("#fff0d4", "#ff7a32", "#2a1f3d", "#a3a0b8", "#ff3fa4")
    M = weapon_mats("#9dff3c", emit=1.9)
    grip_loc = (0, -0.022, -0.104)
    grip_parts, G = grip("", grip_loc, M, tilt=-16, size=(0.068, 0.092, 0.185), body_bottom=-0.03)
    rail_top = 0.112
    z_line = rail_top + SIGHT_HEIGHT
    bore_z = 0.06
    chan_z = 0.094                         # the loaded dart's axis in the top channel
    tank_c = (-0.058, 0.09, 0.034)         # helium tank (along the barrel)
    tank_r = 0.019
    clip_c = (0, 0.19, -0.056)            # dart clip under the barrel
    plunger_c = (0, -0.072, 0.07)

    shell = grip_parts + [
        side_profile("Receiver", [(-0.062, -0.02), (0.232, -0.02), (0.248, 0.02), (0.248, 0.08), (0.226, 0.086), (-0.044, 0.086), (-0.064, 0.07)],
                     0.064, (0, 0, 0), M["shell"], bevel=0.009),
        box("Frame", (0.07, 0.18, 0.034), (0, 0.055, -0.018), bevel=0.012, m=M["trim"]),
        side_profile("Beavertail", [(-0.03, 0.02), (-0.03, -0.024), (-0.058, -0.024), (-0.086, -0.008), (-0.086, 0.006), (-0.062, 0.02)],
                     0.054, (0, 0, 0), M["trim"], bevel=0.006),
        box("Stripe", (0.068, 0.2, 0.01), (0, 0.1, 0.03), bevel=0.003, m=M["trim"]),
        # The open channel the loaded dart lies in, between two orange cheeks.
        box("ChannelFloor", (0.02, 0.17, 0.006), (0, 0.15, chan_z - 0.008), bevel=0.002, m=M["dark"]),
        box("CheekL", (0.008, 0.17, 0.022), (-0.017, 0.15, chan_z - 0.002), bevel=0.003, m=M["trim"]),
        box("CheekR", (0.008, 0.17, 0.022), (0.017, 0.15, chan_z - 0.002), bevel=0.003, m=M["trim"]),
        # Long slim barrel with cooling rings and a flared, glowing muzzle.
        ycyl("Barrel", 0.013, 0.13, 0.31, z=bore_z, m=M["steel"], segs=16, bevel=0.003),
        ycyl("MuzzleFlare", 0.016, 0.022, 0.384, z=bore_z, m=M["trim"], segs=18, bevel=0.003, radius_top=0.022),
        ring("MuzzleGlow", 0.0195, 0.0026, 0.396, z=bore_z, m=M["cell"], segs=20),
        ycyl("Bore", 0.009, 0.006, 0.394, z=bore_z, m=mat("Bore", "#120c22", rough=0.9), segs=12, bevel=0.0),
        box("BarrelLug", (0.03, 0.04, 0.03), (0, 0.262, 0.036), bevel=0.008, m=M["trim"]),
        # The plunger's sleeve at the back, and the clip well under the front.
        ycyl("PlungerSleeve", 0.018, 0.024, -0.062, z=plunger_c[2], m=M["dark"], segs=16, bevel=0.003),
        box("ClipWell", (0.05, 0.08, 0.018), (0, clip_c[1], -0.022), bevel=0.006, m=M["dark"]),
        # Tank cradle on the left flank, with the gauge at its back end.
        box("TankBracketR", (0.026, 0.014, 0.028), (-0.042, tank_c[1] - 0.05, tank_c[2]), bevel=0.005, m=M["steel"]),
        box("TankBracketF", (0.026, 0.014, 0.028), (-0.042, tank_c[1] + 0.05, tank_c[2]), bevel=0.005, m=M["steel"]),
        xcyl("GaugeStem", 0.006, 0.016, (-0.038, -0.004, 0.048), m=M["dark"], segs=10),
        xcyl("GaugeBody", 0.016, 0.01, (-0.05, -0.004, 0.048), m=M["steel"], segs=20),
        xcyl("GaugeFace", 0.013, 0.004, (-0.0565, -0.004, 0.048), m=M["shell"], segs=20),
        box("GaugeRed", (0.0015, 0.006, 0.006), (-0.0585, -0.004 - 0.008, 0.048 - 0.006), bevel=0.0, m=M["pink"]),
        box("GaugeGreen", (0.0015, 0.006, 0.006), (-0.0585, -0.004 + 0.008, 0.048 - 0.006), bevel=0.0, m=M["cell"]),
        box("RightPanel", (0.006, 0.11, 0.03), (0.033, 0.1, 0.05), bevel=0.003, m=M["dark"]),
    ]
    for i in range(4):
        shell.append(ring(f"BarrelRing{i}", 0.0145, 0.0024, 0.262 + 0.028 * i, z=bore_z, m=M["dark"], segs=16))
        shell.append(box(f"RightSlit{i}", (0.004, 0.014, 0.02), (0.0365, 0.065 + i * 0.024, 0.05), rot=rad(18, 0, 0), bevel=0.0, m=M["cell"]))
    for i in range(3):
        shell.append(box(f"Pip{i}", (0.011, 0.006, 0.011), (-0.015 + i * 0.015, -0.066, 0.032), bevel=0.002, m=M["cell"]))
    shell += top_rail("TopRail", -0.03, 0.07, rail_top, M, width=0.03)
    shell.append(box("RailRiser", (0.028, 0.1, 0.014), (0, 0.02, rail_top - 0.02), bevel=0.003, m=M["trim"]))
    shell += bolts("Pin", [(-0.032, -0.03, 0.0), (0.032, -0.03, 0.0), (0.032, 0.2, 0.02)], M["steel"], radius=0.0055, height=0.006)
    lug, charm_point = charm_lug(0.032, 0.17, -0.002, M, out=1.0)
    shell += lug
    sight_rear, sight_front = sights_notch(0.0, -0.046, 0.238, 0.086, 0.086, z_line, M, gap=0.015)

    # Helium tank: a lime-glowing bottle with a pink valve, in the left cradle.
    tx, ty, tz = tank_c
    tank = [
        ycyl("TankBody", tank_r, 0.1, ty, z=tz, x=tx, m=M["shell"], segs=18, bevel=0.006),
        ycyl("TankBand0", tank_r + 0.0015, 0.012, ty - 0.03, z=tz, x=tx, m=M["cell"], segs=18, bevel=0.002),
        ycyl("TankBand1", tank_r + 0.0015, 0.012, ty + 0.03, z=tz, x=tx, m=M["cell"], segs=18, bevel=0.002),
        sphere("TankDome", tank_r, (tx, ty + 0.05, tz), scale=(1, 0.6, 1), m=M["shell"], segs=16, rings=8),
        ycyl("TankValve", 0.007, 0.016, ty + 0.066, z=tz, x=tx, m=M["pink"], segs=10, bevel=0.002),
        tube("TankHose", [(tx, ty - 0.05, tz), (tx + 0.002, ty - 0.07, tz + 0.006), (-0.05, -0.004 + 0.012, 0.048)], 0.0035, m=M["dark"], segs=6),
    ]
    shell += tank

    # Gauge needle: sweeps from the green end to the red as the clip empties.
    needle_c = (-0.059, -0.004, 0.048)
    needle = [box("NeedleArm", (0.0016, 0.0016, 0.011), (needle_c[0], needle_c[1], needle_c[2] + 0.0045), bevel=0.0, m=M["dark"]),
              xcyl("NeedleHub", 0.0022, 0.002, needle_c, m=M["pink"], segs=8)]

    # The loaded dart, and the air plunger behind it.
    loaded = dart("Dart", 0.08, 0.13, chan_z, M)
    px, py, pz = plunger_c
    plunger = [ycyl("PlungerRod", 0.006, 0.03, py + 0.004, z=pz, m=M["steel"], segs=10, bevel=0.0),
               ycyl("PlungerKnob", 0.014, 0.012, py - 0.012, z=pz, m=M["pink"], segs=16, bevel=0.004),
               ycyl("PlungerCap", 0.009, 0.004, py - 0.019, z=pz, m=M["cell"], segs=12, bevel=0.0015)]

    # Dart clip: an open rack under the barrel, its darts showing on the left.
    qx, qy, qz = clip_c
    clip = [box("ClipFront", (0.04, 0.008, 0.054), (qx, qy + 0.034, qz), bevel=0.003, m=M["trim"]),
            box("ClipRear", (0.04, 0.008, 0.054), (qx, qy - 0.034, qz), bevel=0.003, m=M["trim"]),
            box("ClipSpine", (0.006, 0.07, 0.054), (qx + 0.017, qy, qz), bevel=0.002, m=M["dark"]),
            box("ClipBase", (0.044, 0.078, 0.008), (qx, qy, qz - 0.03), bevel=0.003, m=M["steel"]),
            box("ClipTab", (0.016, 0.02, 0.006), (qx, qy, qz - 0.036), bevel=0.002, m=M["cell"])]
    tails = {}
    for k in range(TAILS):
        col, row = k // 3, k % 3
        x = -0.007 + col * 0.012
        z = qz + 0.017 - row * 0.016
        tails[f"Tail{k}"] = (dart(f"Tail{k}", qy - 0.029, 0.058, z, M, x=x), (x, qy, z))
    clip_holo = holo_copy(clip[:4])

    # The reload's balloon, blown up on the muzzle (hidden until then).
    my = 0.398
    balloon = [sphere("BalloonSkin", 0.024, (0, my + 0.028, bore_z), scale=(0.9, 1.15, 0.9), m=M["pink"], segs=16, rings=10),
               sphere("BalloonKnot", 0.005, (0, my + 0.002, bore_z), m=M["pink"], segs=8, rings=5),
               sphere("BalloonShine", 0.006, (0.012, my + 0.036, bore_z + 0.012), scale=(0.6, 1, 1), m=M["shell"], segs=8, rings=5)]

    decal = [side_emblem("Emblem", star_outline(0.018, 0.008), -0.032, 0.17, 0.05, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.42, -0.5, -0.36))
    arm_l, elbow_l = cup_hand(G, M, (-0.55, -0.32, -0.32))
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.046, 0.086), None),
        "IronSightFront": (sight_front, (0, 0.238, 0.086), None),
        "Cell": (clip, clip_c, None),
        "CellHolo": (clip_holo, clip_c, None),
        "Dart": (loaded, (0, 0.08, chan_z), None),
        "Plunger": (plunger, plunger_c, None),
        "Needle": (needle, needle_c, None),
        "BalloonHolo": (balloon, (0, my, bore_z), None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, grip_loc, None),
    }
    for name, (parts, pivot) in tails.items():
        groups[name] = (parts, pivot, "Cell")
    empties = {
        "Muzzle": ((0, my, bore_z), None),
        "SightPoint": ((0, -0.046, z_line), None),
        "SightMount": ((0, 0.02, rail_top), None),
        "EjectPoint": ((0, qy, qz - 0.04), None),
        "VentPoint": ((0, py - 0.03, pz), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("balloon_darter", groups, empties)


BUILDERS = (
    ("shutterbug", build_shutterbug),
    ("balloon_darter", build_balloon_darter),
)

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for name, fn in BUILDERS:
        if not only or name in only:
            fn()
