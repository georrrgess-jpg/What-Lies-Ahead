"""First-person viewmodel of the Endless reward primary, the Road Rager
(hubcap_boomerang): a hot-rod pitching machine that flings hubcaps. Also
writes the thrown hubcap on its own (art/models/hubcap_boomerang_cap.glb,
used by scripts/weapons/hubcap_shot.gd).

Same conventions and node contract as build_weapons.py (documented at the top
of weapon_kit.py): origin at the top of the grip, pointing along +Y, its own
palette (set before weapon_mats, so the shared material names stay and every
finish, cell, decal and charm works), built-in sights. Moving parts, driven by
scripts/weapons/views/hubcap_boomerang_view.gd and
scripts/weapons/reloads/hubcap_boomerang_reload.gd:

  Loaded      the hubcap on the launch tray, tipped back to face the player
              (pivot at its centre)
  WheelL/R    the two pitching tyres either side of it (spin on every throw)
  Catcher     the horseshoe magnet on the nose that snaps the hubcap home
  Cell        the hubcap rack on the left flank (its glowing rails) >
              Cap0..1 the spare hubcaps on edge (the rest of the magazine)
  CellHolo    hologram rack for the reload

    python art/blender/build_weapons_hubcap.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403
from weapon_kit import _save  # noqa: E402

SPARES = 2
SPOKES = 6


def palette(shell, trim, dark, steel, pink, steel_metal=0.8):
    """Creates the shared weapon materials in this weapon's colours (weapon_mats reuses them)."""
    mat("Shell", shell, rough=0.3)
    mat("Trim", trim, rough=0.38)
    mat("GunDark", dark, rough=0.6, metal=0.1)
    mat("GunSteel", steel, rough=0.2, metal=steel_metal)
    mat("GunPink", pink, rough=0.34)


def _place(parts, centre, axis, tilt=0.0):
    """Moves parts built round the origin (axis +Z) to `centre`, turning +Z onto `axis` ('x', 'y' or 'z'),
    then tipping it back towards the player by `tilt` degrees (about X)."""
    bpy.context.view_layer.update()
    rot = {"z": Matrix.Identity(4), "x": Matrix.Rotation(math.pi / 2, 4, "Y"), "y": Matrix.Rotation(-math.pi / 2, 4, "X")}[axis]
    move = Matrix.Translation(Vector(centre)) @ Matrix.Rotation(math.radians(tilt), 4, "X")
    for ob in parts:
        ob.matrix_world = move @ rot @ ob.matrix_world
    return parts


def hubcap(prefix, radius, chrome, dark, glow, centre=(0, 0, 0), axis="z", detail=True, tilt=0.0):
    """A chunky chrome hubcap round the origin (axis +Z, face up): a domed dish,
    a ribbed outer rim, six spokes, lug nuts and a glowing centre badge."""
    t = radius * 0.22
    parts = [
        cyl(prefix + "Dish", radius * 0.94, t, (0, 0, 0), segs=28, bevel=t * 0.4, m=chrome, radius_top=radius * 0.72),
        torus(prefix + "Rim", radius * 0.95, radius * 0.07, (0, 0, -t * 0.25), m=chrome, major_segs=28, minor_segs=6),
        cyl(prefix + "Well", radius * 0.62, t * 0.5, (0, 0, t * 0.42), segs=24, bevel=t * 0.15, m=dark),
        cyl(prefix + "Hub", radius * 0.26, t * 0.7, (0, 0, t * 0.6), segs=18, bevel=t * 0.25, m=chrome, radius_top=radius * 0.2),
        cyl(prefix + "Badge", radius * 0.14, t * 0.3, (0, 0, t * 0.95), segs=14, bevel=t * 0.1, m=glow),
    ]
    for i in range(SPOKES):
        a = math.tau * i / SPOKES
        r_mid = radius * 0.47
        parts.append(box(f"{prefix}Spoke{i}", (radius * 0.44, radius * 0.13, t * 0.45), (math.cos(a) * r_mid, math.sin(a) * r_mid, t * 0.55),
                         rot=(0, 0, a), bevel=t * 0.12, m=chrome))
        if detail:
            b = a + math.pi / SPOKES
            parts.append(cyl(f"{prefix}Nut{i}", radius * 0.045, t * 0.4, (math.cos(b) * radius * 0.34, math.sin(b) * radius * 0.34, t * 0.62),
                             segs=6, bevel=0.0, m=dark))
    return _place(parts, centre, axis, tilt)


def tyre(prefix, centre, radius, height, M):
    """A small fat tyre on a vertical axle: rubber, a chrome hub and tread blocks."""
    x, y, z = centre
    parts = [
        torus(prefix + "Rubber", radius - height * 0.32, height * 0.48, (x, y, z), m=M["dark"], major_segs=24, minor_segs=8),
        cyl(prefix + "Hub", radius * 0.55, height * 0.9, (x, y, z), segs=18, bevel=0.003, m=M["steel"]),
        cyl(prefix + "Axle", radius * 0.2, height * 1.15, (x, y, z), segs=10, bevel=0.002, m=M["cell"]),
    ]
    for i in range(10):
        a = math.tau * i / 10
        parts.append(box(f"{prefix}Tread{i}", (0.006, 0.012, height * 0.8), (x + math.cos(a) * (radius + 0.001), y + math.sin(a) * (radius + 0.001), z),
                         rot=(0, 0, a), bevel=0.0015, m=M["dark"]))
    return parts


def build_hubcap_boomerang():
    reset_scene()
    palette("#ff5a2c", "#ffc832", "#23202a", "#d6dae6", "#ff2f55")
    M = weapon_mats("#ff8a26", emit=2.2)
    chrome = M["steel"]
    grip_loc = (0, -0.03, -0.115)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.07, 0.092, 0.19), body_bottom=-0.02)
    rail_top = 0.106
    z_line = rail_top + SIGHT_HEIGHT
    tray_z = 0.072
    cap_c = (0, 0.29, tray_z + 0.022)      # the loaded hubcap, tipped back on the tray
    cap_r = 0.068
    wheel_x = cap_r + 0.03
    wheel_c = (wheel_x, 0.29, tray_z + 0.022)
    rack_c = (-0.066, 0.04, 0.028)          # spare hubcaps on edge, left flank
    magnet_c = (0, 0.385, tray_z + 0.022)
    fore = (0, 0.215, -0.072)

    shell = grip_parts + [
        # Hot-rod body: candy orange-red, a hazard-yellow belt line and a dark sill.
        box("Body", (0.092, 0.24, 0.1), (0, 0.03, 0.03), bevel=0.026, segs=3, m=M["shell"]),
        box("BeltLine", (0.096, 0.22, 0.016), (0, 0.03, 0.044), bevel=0.005, m=M["trim"]),
        box("Sill", (0.094, 0.2, 0.02), (0, 0.03, -0.008), bevel=0.008, m=M["dark"]),
        box("Hood", (0.07, 0.1, 0.012), (0, 0.1, 0.084), bevel=0.005, m=M["shell"]),
        box("RailRiser", (0.036, 0.16, 0.018), (0, 0.01, rail_top - 0.017), bevel=0.004, m=M["dark"]),
        # Launch tray out front: a steel plate between two fenders, a foregrip mount below.
        box("Tray", (0.17, 0.2, 0.014), (0, 0.28, tray_z), bevel=0.005, m=M["dark"]),
        box("TrayLip", (0.12, 0.012, 0.016), (0, 0.186, tray_z + 0.01), bevel=0.004, m=chrome),
        box("TrayNeck", (0.07, 0.07, 0.07), (0, 0.17, 0.035), bevel=0.012, m=M["shell"]),
        box("ForegripMount", (0.056, 0.07, 0.07), (0, fore[1], 0.03), bevel=0.008, m=M["dark"]),
        # Chrome front bumper under the nose, with two red tail-light studs.
        box("Bumper", (0.19, 0.016, 0.018), (0, 0.384, tray_z - 0.012), bevel=0.007, m=chrome),
        # Muffler stock with a chrome end can and a tail light.
        ycyl("Muffler", 0.026, 0.1, -0.15, z=0.015, m=chrome, segs=20, bevel=0.006),
        ring("MufflerBandA", 0.027, 0.0035, -0.12, z=0.015, m=M["dark"], segs=20),
        ring("MufflerBandB", 0.027, 0.0035, -0.18, z=0.015, m=M["dark"], segs=20),
        ycyl("Butt", 0.029, 0.018, -0.205, z=0.015, m=M["dark"], segs=20, bevel=0.006),
        ycyl("TailLight", 0.012, 0.006, -0.215, z=0.015, m=M["pink"], segs=16, bevel=0.002),
        box("StockNeck", (0.05, 0.05, 0.05), (0, -0.095, 0.02), bevel=0.012, m=M["dark"]),
        # The rack's saddle on the left flank.
        box("RackSaddle", (0.012, 0.13, 0.05), (-0.05, rack_c[1], rack_c[2]), bevel=0.004, m=M["dark"]),
    ]
    # Two exhaust stacks up the right flank, glowing inside.
    for i, y in enumerate((0.0, 0.06)):
        pts = [(0.046, y, -0.004), (0.062, y - 0.01, 0.012), (0.068, y - 0.03, 0.05), (0.068, y - 0.05, 0.076)]
        shell.append(tube(f"Exhaust{i}", pts, 0.009, m=chrome, segs=12))
        shell.append(ring(f"ExhaustTip{i}", 0.0105, 0.003, 0.0, z=0.0, m=chrome, segs=14))
        shell[-1].location = (0.068, y - 0.052, 0.079)
        shell[-1].rotation_euler = (0.0, 0.0, 0.0)
        shell.append(cyl(f"ExhaustGlow{i}", 0.0075, 0.004, (0.068, y - 0.051, 0.077), segs=12, bevel=0.0, m=M["cell"]))
    # Hazard stripes on both flanks of the body.
    for side in (-1, 1):
        for i in range(5):
            shell.append(box(f"Hazard{side}{i}", (0.004, 0.014, 0.034), (side * 0.0475, -0.04 + i * 0.03, 0.012),
                             rot=rad(32, 0, 0), bevel=0.0, m=M["trim"] if i % 2 == 0 else M["dark"]))
    # Fenders over the pitching tyres.
    for side in (-1, 1):
        shell.append(box(f"Fender{side}", (0.05, 0.09, 0.01), (side * wheel_x, 0.29, tray_z + 0.05), bevel=0.004, m=M["shell"]))
        shell.append(box(f"FenderStrut{side}", (0.008, 0.012, 0.05), (side * (wheel_x + 0.02), 0.29, tray_z + 0.026), bevel=0.002, m=chrome))
        shell.append(sphere(f"Headlight{side}", 0.011, (side * 0.065, 0.392, tray_z - 0.012), scale=(1, 0.6, 1), m=M["cell"], segs=10, rings=6))
    # Vertical foregrip: a rubber gear-stick boot with a chrome knob.
    shell += [
        box("Foregrip", (0.042, 0.05, 0.12), fore, bevel=0.016, m=M["dark"]),
        sphere("ForegripKnob", 0.025, (0, fore[1], fore[2] - 0.078), scale=(1, 1, 0.7), m=chrome, segs=16, rings=10),
    ]
    shell += top_rail("TopRail", -0.07, 0.08, rail_top, M, width=0.032)
    shell += bolts("Pin", [(-0.047, 0.12, 0.0), (0.047, 0.12, 0.0), (0.047, -0.07, 0.04)], chrome, radius=0.006, height=0.006)
    lug, charm_point = charm_lug(-0.026, -0.165, 0.004, M)
    shell += lug
    sight_rear, sight_front = sights_notch(0.0, -0.06, 0.14, rail_top, 0.09, z_line, M, gap=0.016)
    shell.append(box("FrontSightBase", (0.03, 0.03, 0.01), (0, 0.14, 0.088), bevel=0.003, m=M["dark"]))

    loaded = hubcap("Loaded", cap_r, chrome, M["dark"], M["cell"], cap_c, "z", tilt=24.0)
    wheel_l = tyre("WheelL", (-wheel_c[0], wheel_c[1], wheel_c[2]), 0.03, 0.03, M)
    wheel_r = tyre("WheelR", wheel_c, 0.03, 0.03, M)

    # The horseshoe magnet on the nose: red U opening forward, steel tips.
    mx, my, mz = magnet_c
    magnet = [torus("MagnetU", 0.034, 0.011, (mx, my - 0.004, mz), m=M["pink"], major_segs=20, minor_segs=7,
                    arc=math.pi, start=math.pi)]
    for i, side in enumerate((-1, 1)):
        magnet.append(ycyl(f"MagnetArm{i}", 0.011, 0.022, my + 0.007, z=mz, x=side * 0.034, m=M["pink"], segs=10, bevel=0.002))
        magnet.append(ycyl(f"MagnetTip{i}", 0.0115, 0.012, my + 0.024, z=mz, x=side * 0.034, m=chrome, segs=10, bevel=0.002))
    magnet.append(box("MagnetMount", (0.02, 0.03, 0.012), (mx, my - 0.04, mz - 0.006), bevel=0.003, m=M["dark"]))

    # The rack: two glowing rails holding the spare hubcaps on edge.
    rx, ry, rz = rack_c
    rack = [
        box("RackRailLow", (0.03, 0.12, 0.006), (rx - 0.004, ry, rz - 0.032), bevel=0.002, m=M["cell"]),
        box("RackRailHigh", (0.006, 0.12, 0.006), (rx - 0.022, ry, rz + 0.03), bevel=0.002, m=M["cell"]),
        box("RackPostF", (0.03, 0.006, 0.07), (rx - 0.006, ry + 0.06, rz), bevel=0.002, m=M["dark"]),
        box("RackPostR", (0.03, 0.006, 0.07), (rx - 0.006, ry - 0.06, rz), bevel=0.002, m=M["dark"]),
    ]
    spares = {}
    for k in range(SPARES):
        c = (rx - 0.004 - k * 0.016, ry + 0.02 - k * 0.04, rz)
        spares[f"Cap{k}"] = (hubcap(f"Cap{k}", 0.034, chrome, M["dark"], M["cell"], c, "x", detail=False), c)
    rack_holo = holo_copy(rack[:2] + [p for p in spares["Cap0"][0][:2]])

    bolt = [(-0.008, 0.02), (0.012, 0.004), (0.002, 0.0), (0.01, -0.02), (-0.012, -0.002), (-0.002, 0.0)]
    decal = [side_emblem("Emblem", bolt, -0.047, -0.065, 0.05, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = vertical_hand(fore, 0.023, 0.027, 0.12, M, (-0.52, -0.16, -0.46))
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.06, rail_top), None),
        "IronSightFront": (sight_front, (0, 0.14, 0.09), None),
        "Loaded": (loaded, cap_c, None),
        "WheelL": (wheel_l, (-wheel_c[0], wheel_c[1], wheel_c[2]), None),
        "WheelR": (wheel_r, wheel_c, None),
        "Catcher": (magnet, (mx, my - 0.04, mz), None),
        "Cell": (rack, rack_c, None),
        "CellHolo": (rack_holo, rack_c, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    for name, (parts, centre) in spares.items():
        groups[name] = (parts, centre, "Cell")
    empties = {
        "Muzzle": ((0, 0.41, tray_z + 0.022), None),
        "SightPoint": ((0, -0.06, z_line), None),
        "SightMount": ((0, 0.005, rail_top), None),
        "EjectPoint": ((rx - 0.03, ry, rz - 0.03), None),
        "VentPoint": ((0.068, -0.02, 0.085), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("hubcap_boomerang", groups, empties)


def build_thrown_cap():
    """The hubcap in flight: radius 0.2 m (WeaponData.projectile_size), face up."""
    reset_scene()
    chrome = mat("CapChrome", "#e3e6f0", rough=0.16, metal=0.85)
    dark = mat("CapDark", "#2a2633", rough=0.5, metal=0.2)
    glow = mat("CapGlow", "#ff8a26", rough=0.3, emit=2.6)
    parts = hubcap("Cap", 0.2, chrome, dark, glow)
    cap = merge("Cap", parts)
    _save("hubcap_boomerang_cap", [cap])


BUILDERS = (
    ("hubcap_boomerang", build_hubcap_boomerang),
    ("hubcap_boomerang_cap", build_thrown_cap),
)

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for name, fn in BUILDERS:
        if not only or name in only:
            fn()
