"""First-person viewmodels for the update-7 primaries (unlocked by player level).

Same conventions and node contract as build_weapons.py and
build_weapons_arsenal.py (the contract is documented at the top of
weapon_kit.py): origin at the top of the grip, pointing along +Y. Each
weapon has its own palette (set before weapon_mats, so the shared material
names stay and every finish, cell, decal and charm works), built-in sights,
and moving parts that its mode (scripts/weapons/modes/) and reload script
(scripts/weapons/reloads/) drive:

  drum_popper  Gumball Drum Popper (after references/concept-gumball-drum-popper.webp):
               Drum (turns a chamber per shot, swapped on reload) > Cell
               (gumballs), CellHolo, Pump > ArmL (fore-pump, kicks per shot),
               carry handle = IronSightRear
  whirligig    Whirligig prize-wheel minigun: Barrels (wheel and six barrels,
               spin up), Ticker (flapper on the wheel's pegs), Cell (heat
               canister), CellHolo
  riptide      Riptide Harpoon: Harpoon (spear in the muzzle), Reel (line
               spool), Cell (air tank), CellHolo

    python art/blender/build_weapons_new1.py [weapon_id ...]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403
from wla_common import _finish  # noqa: E402


def palette(shell, trim, dark, steel, pink, steel_metal=0.55):
    """Creates the shared weapon materials in this weapon's colours (weapon_mats reuses them)."""
    mat("Shell", shell, rough=0.34)
    mat("Trim", trim, rough=0.4)
    mat("GunDark", dark, rough=0.45, metal=0.2)
    mat("GunSteel", steel, rough=0.3, metal=steel_metal)
    mat("GunPink", pink, rough=0.36)


def xring(name, r_out, r_in, width, loc, m, segs=32):
    """Hollow cylinder (a tyre) round the X axis."""
    bm = bmesh.new()
    rows = []
    for x in (-width / 2, width / 2):
        for r in (r_out, r_in):
            rows.append([bm.verts.new((x, math.cos(math.tau * i / segs) * r, math.sin(math.tau * i / segs) * r)) for i in range(segs)])
    o0, i0, o1, i1 = rows
    for a, b in ((o0, o1), (i1, i0), (i0, o0), (o1, i1)):
        for j in range(segs):
            k = (j + 1) % segs
            bm.faces.new((a[j], a[k], b[k], b[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish(name, bm, m, loc, (0, 0, 0))
    return add_bevel(ob, min(0.004, (r_out - r_in) * 0.3), 2)


def sector(name, r_in, r_out, a0, a1, depth, y, z, m, steps=4):
    """A wedge of a wheel round the barrel axis (+Y), `depth` thick."""
    inner = [(math.cos(a0 + (a1 - a0) * i / steps) * r_in, math.sin(a0 + (a1 - a0) * i / steps) * r_in) for i in range(steps + 1)]
    outer = [(math.cos(a1 - (a1 - a0) * i / steps) * r_out, math.sin(a1 - (a1 - a0) * i / steps) * r_out) for i in range(steps + 1)]
    return prism(name, inner + outer, depth, (0, y, z), m=m)


# ---------------------------------------------------------------------------
# Gumball Drum Popper: semi-auto, drum-fed ricochet gumballs
# ---------------------------------------------------------------------------

def build_drum_popper():
    reset_scene()
    # Concept palette: blue, navy, grey, orange, yellow, pink.
    palette("#4a5cf0", "#ff962e", "#1f2678", "#9aa0b8", "#ff4f9e", steel_metal=0.35)
    M = weapon_mats("#ffd93b", emit=1.5)
    gums = [mat("GumPink", "#ff5fb4", rough=0.2, emit=0.25), mat("GumYellow", "#ffd640", rough=0.2, emit=0.25),
            mat("GumCyan", "#3fe2ff", rough=0.2, emit=0.25), mat("GumGreen", "#58f07a", rough=0.2, emit=0.25)]
    glint = mat("Glint", "#ffffff", rough=0.1, emit=0.8)
    bore_z = 0.018
    rail_top = 0.084
    z_line = rail_top + SIGHT_HEIGHT
    rear_y = -0.088
    drum_c = (0, 0.185, -0.122)
    pump_c = (0, 0.345, -0.056)
    grip_loc = (0, 0.0, -0.105)
    grip_parts, G = grip("", grip_loc, dict(M, dark=M["trim"]), tilt=-14, size=(0.068, 0.088, 0.17), body_bottom=-0.03, guard_len=0.06)
    shell = grip_parts + [
        # Blue receiver with a navy riser under the rail, orange end blocks.
        box("Receiver", (0.084, 0.44, 0.097), (0, 0.11, 0.0185), bevel=0.022, m=M["shell"]),
        box("Belly", (0.07, 0.4, 0.01), (0, 0.11, -0.031), bevel=0.004, m=M["dark"]),
        box("RailRiser", (0.042, 0.33, 0.008), (0, 0.165, 0.069), bevel=0.003, m=M["dark"]),
        box("RearBlock", (0.094, 0.078, 0.11), (0, -0.142, 0.012), bevel=0.024, m=M["trim"]),
        box("FrontBlock", (0.096, 0.104, 0.1), (0, 0.372, 0.02), bevel=0.022, m=M["trim"]),
        # Grey bumper muzzle: tube, yellow band, rubber ring, pink glow in the bore.
        ycyl("MuzzleTube", 0.034, 0.07, 0.455, z=bore_z, m=M["steel"], segs=20),
        ring("MuzzleBand", 0.0345, 0.0045, 0.437, z=bore_z, m=M["cell"]),
        ycyl("Bumper", 0.042, 0.024, 0.494, z=bore_z, m=M["dark"], segs=20, bevel=0.009),
        ring("BumperGlow", 0.026, 0.0035, 0.505, z=bore_z, m=M["pink"]),
        ycyl("Bore", 0.025, 0.006, 0.503, z=bore_z, m=mat("Bore", "#120c22", rough=0.9), segs=16, bevel=0.0),
        sphere("BoreDot", 0.008, (0, 0.503, bore_z), m=M["pink"], segs=10, rings=6),
        # Fore-pump guide rod and the neck the drum hangs from.
        ycyl("PumpRod", 0.007, 0.15, 0.345, z=-0.045, m=M["steel"], segs=10),
        box("DrumNeck", (0.03, 0.05, 0.02), (0, drum_c[1], -0.04), bevel=0.005, m=M["dark"]),
        # Grey L stock off the rear block, with a rubber butt.
        tube("Stock", [(0, -0.17, -0.012), (0, -0.24, -0.012), (0, -0.258, -0.03), (0, -0.258, -0.095)], 0.016, m=M["steel"], segs=12),
        box("ButtPad", (0.046, 0.022, 0.07), (0, -0.268, -0.075), bevel=0.008, m=M["dark"]),
    ]
    shell += top_rail("TopRail", 0.0, 0.33, rail_top, M, width=0.034, pitch=0.04)
    for side in (-1, 1):
        x = side * 0.0425
        s = "L" if side < 0 else "R"
        shell += [
            # Yellow light strip under the rail and the navy side panel with three pink dots.
            box(f"Light{s}", (0.004, 0.3, 0.007), (x, 0.17, 0.052), bevel=0.0, m=M["cell"]),
            box(f"Panel{s}", (0.004, 0.22, 0.048), (x, 0.207, 0.022), bevel=0.002, m=M["dark"]),
            box(f"PanelBar{s}", (0.004, 0.075, 0.009), (x + side * 0.002, 0.262, 0.022), bevel=0.0, m=M["cell"]),
        ]
        for i, y in enumerate((0.127, 0.155, 0.183)):
            shell.append(sphere(f"PanelDot{s}{i}", 0.0065, (x + side * 0.0015, y, 0.022), m=M["pink"], segs=8, rings=5))
        # Five slanted navy vents with yellow tips at the back.
        for i in range(5):
            y = -0.075 + i * 0.024
            shell.append(box(f"Vent{s}{i}", (0.004, 0.011, 0.04), (x, y, 0.016), rot=rad(-22, 0, 0), bevel=0.0, m=M["dark"]))
            shell.append(box(f"VentTip{s}{i}", (0.0045, 0.011, 0.008), (x, y + 0.0065, 0.033), rot=rad(-22, 0, 0), bevel=0.0, m=M["cell"]))
        # Grooves across the orange blocks.
        for i, z in enumerate((0.047, 0.027, 0.007, -0.013)):
            shell.append(box(f"RearGroove{s}{i}", (0.003, 0.05, 0.004), (side * 0.047, -0.142, z), bevel=0.0, m=M["dark"]))
        for i, z in enumerate((0.048, 0.026, 0.004)):
            shell.append(box(f"FrontGroove{s}{i}", (0.003, 0.064, 0.004), (side * 0.048, 0.372, z), bevel=0.0, m=M["dark"]))
    lug, charm_point = charm_lug(-0.047, -0.15, 0.04, M)
    shell += lug

    # Carry handle: the rear sight (hidden when an optic is fitted).
    rear = []
    for i, side in enumerate((-1, 1)):
        x = side * 0.019
        rear.append(tube(f"HandleSide{i}", [(x, rear_y - 0.008, 0.066), (x, rear_y - 0.003, 0.124), (x, rear_y + 0.006, 0.131), (x, 0.016, 0.131),
                                            (x, 0.025, 0.124), (x, 0.032, 0.066)], 0.0075, m=M["steel"], segs=8))
    rear += [
        box("HandleTop", (0.046, 0.014, 0.01), (0, rear_y, 0.131), bevel=0.004, m=M["steel"]),
        box("HandleTopF", (0.046, 0.014, 0.01), (0, 0.022, 0.131), bevel=0.004, m=M["steel"]),
        tube("HandleGrip", [(0, rear_y, 0.134), (0, 0.022, 0.134)], 0.0085, m=M["steel"], segs=10),
        torus("RearRing", 0.0125, 0.0035, (0, rear_y, z_line), rot=rad(90, 0, 0), m=M["steel"], major_segs=20, minor_segs=6),
        box("RearStem", (0.01, 0.01, z_line - 0.0125 - 0.067), (0, rear_y, (z_line - 0.0125 + 0.067) / 2), bevel=0.003, m=M["steel"]),
        sphere("RearDotL", 0.0035, (-0.0125, rear_y - 0.004, z_line), m=M["cell"], segs=8, rings=5),
        sphere("RearDotR", 0.0035, (0.0125, rear_y - 0.004, z_line), m=M["cell"], segs=8, rings=5),
    ]
    front = [
        side_profile("FrontFin", [(0.352, 0.066), (0.394, 0.066), (0.383, z_line - 0.008), (0.371, z_line - 0.008)], 0.012, (0, 0, 0), M["trim"], bevel=0.003),
        sphere("FrontDot", 0.0045, (0, 0.375, z_line - 0.0045), m=M["cell"], segs=10, rings=6),
    ]

    # The drum: orange tyre with bumps, open windows each side, navy back plate, gold hub.
    cy, cz = drum_c[1], drum_c[2]
    drum = [
        xring("DrumWall", 0.074, 0.062, 0.058, drum_c, M["trim"], segs=28),
        xcyl("DrumPlate", 0.063, 0.004, drum_c, m=M["dark"], segs=24, bevel=0.0),
        xcyl("DrumHub", 0.017, 0.066, drum_c, m=M["trim"], segs=12),
        xcyl("DrumHubGold", 0.009, 0.07, drum_c, m=M["cell"], segs=12, bevel=0.002),
    ]
    for i, side in enumerate((-1, 1)):
        drum.append(torus(f"DrumRim{i}", 0.067, 0.0065, (side * 0.029, cy, cz), rot=rad(0, 90, 0), m=M["trim"], major_segs=28, minor_segs=5))
        drum.append(torus(f"DrumGlint{i}", 0.05, 0.0018, (side * 0.032, cy, cz), rot=rad(0, 90, 0), m=glint, major_segs=10, minor_segs=4,
                          arc=math.radians(55), start=math.radians(115)))
    for k in range(14):
        a = math.tau * k / 14
        drum.append(xcyl(f"DrumBump{k}", 0.0075, 0.046, (0, cy + math.cos(a) * 0.077, cz + math.sin(a) * 0.077), m=M["trim"], segs=8, bevel=0.0))
    balls = []
    spots = [(0.032, k * math.tau / 8 + 0.2) for k in range(8)] + [(0.052, k * math.tau / 13) for k in range(13)]
    order = [0, 2, 1, 3, 2, 0, 3, 1, 1, 3, 0, 2, 3, 1, 2, 0, 0, 2, 3, 1, 2]
    # A full window on the side the player sees, the outer ring on the far side.
    for i, side in enumerate((-1, 1)):
        for j, (r, a) in enumerate(spots):
            if side > 0 and r < 0.04:
                continue
            balls.append(sphere(f"Gum{i}_{j}", 0.0105, (side * 0.0135, cy + math.cos(a) * r, cz + math.sin(a) * r),
                                m=gums[(order[j] + i) % 4], segs=8, rings=4))
    # The hologram drum is a lighter copy: tyre, rims and the outer ring of gumballs.
    holo = mat("Holo")
    drum_holo = [xring("HoloWall", 0.074, 0.062, 0.058, drum_c, holo, segs=20)]
    drum_holo += [torus(f"HoloRim{i}", 0.067, 0.0065, (side * 0.029, cy, cz), rot=rad(0, 90, 0), m=holo, major_segs=20, minor_segs=4)
                  for i, side in enumerate((-1, 1))]
    drum_holo += [sphere(f"HoloGum{j}", 0.0105, (-0.0135, cy + math.cos(a) * r, cz + math.sin(a) * r), m=holo, segs=6, rings=4)
                  for j, (r, a) in enumerate(spots) if r > 0.04]

    pump = [box("PumpBody", (0.068, 0.13, 0.048), pump_c, bevel=0.016, m=M["trim"])]
    for i in range(7):
        pump.append(box(f"PumpRib{i}", (0.074, 0.008, 0.054), (0, pump_c[1] - 0.054 + i * 0.018, pump_c[2]), bevel=0.003, segs=1, m=M["trim"]))
    star = [(math.cos(math.radians(90 + 36 * i)) * (0.022 if i % 2 == 0 else 0.009), math.sin(math.radians(90 + 36 * i)) * (0.022 if i % 2 == 0 else 0.009))
            for i in range(10)]
    decal = [side_emblem("Emblem", star, -0.0425, 0.066, 0.022, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = support_hand(pump_c, 0.037, 0.027, M, (-0.52, -0.12, -0.46), corner=0.016, finger_len=0.05, thumb_len=0.05)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (rear, (0, rear_y, rail_top), None),
        "IronSightFront": (front, (0, 0.375, 0.066), None),
        "Drum": (drum, drum_c, None),
        "Cell": (balls, drum_c, "Drum"),
        "CellHolo": (drum_holo, drum_c, None),
        "Pump": (pump, pump_c, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, pump_c, "Pump"),
    }
    empties = {
        "Muzzle": ((0, 0.51, bore_z), None),
        "SightPoint": ((0, rear_y, z_line), None),
        "SightMount": ((0, 0.17, rail_top), None),
        "EjectPoint": ((-0.045, cy, cz + 0.02), None),
        "VentPoint": ((0, 0.372, 0.075), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("drum_popper", groups, empties)


# ---------------------------------------------------------------------------
# Whirligig: rotary prize-wheel minigun
# ---------------------------------------------------------------------------

def build_whirligig():
    reset_scene()
    palette("#fff0d4", "#e5384f", "#2b2140", "#aeb0c4", "#ff4fa3", steel_metal=0.6)
    M = weapon_mats("#ffc53d", emit=2.0)
    wheel_mats = [M["trim"], M["shell"], mat("WheelBlue", "#3a8dff", rough=0.35), M["pink"]]
    rail_top = 0.11
    z_line = rail_top + SIGHT_HEIGHT
    wheel_y = 0.3
    wheel_r = 0.104
    spin_c = (0, 0.2, 0.0)
    fore = (0, 0.085, -0.075)
    grip_loc = (0, -0.03, -0.125)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.074, 0.094, 0.18), body_bottom=-0.048)
    shell = grip_parts + [
        # Cream receiver in red carnival stripes, a gold bulb marquee along the top.
        box("Receiver", (0.11, 0.27, 0.13), (0, -0.01, 0.017), bevel=0.035, m=M["shell"]),
        box("RailRiser", (0.045, 0.2, 0.02), (0, 0.0, 0.092), bevel=0.005, m=M["dark"]),
        box("RearCap", (0.1, 0.03, 0.11), (0, -0.152, 0.017), bevel=0.02, m=M["dark"]),
        # Motor hub the spinning wheel and barrels turn in.
        ycyl("Hub", 0.052, 0.05, 0.145, z=0.0, m=M["trim"], segs=24, bevel=0.01),
        ring("HubBand", 0.053, 0.005, 0.158, z=0.0, m=M["cell"], segs=24),
        # Ticker bracket out over the wheel, carrying the front sight.
        box("TickerArm", (0.014, 0.17, 0.01), (0, 0.19, 0.118), bevel=0.003, m=M["dark"]),
        box("TickerFoot", (0.03, 0.03, 0.04), (0, 0.11, 0.101), bevel=0.005, m=M["dark"]),
        # Handguard under the front of the receiver.
        box("Handguard", (0.05, 0.11, 0.044), fore, bevel=0.014, m=M["trim"]),
        box("HandguardCap", (0.056, 0.012, 0.05), (0, fore[1] + 0.06, fore[2]), bevel=0.005, m=M["dark"]),
        # Heat canister clamps on the left flank.
        box("CanClampR", (0.03, 0.012, 0.04), (-0.07, -0.035, 0.005), bevel=0.004, m=M["dark"]),
        box("CanClampF", (0.03, 0.012, 0.04), (-0.07, 0.075, 0.005), bevel=0.004, m=M["dark"]),
    ]
    shell += top_rail("TopRail", -0.09, 0.11, rail_top, M, width=0.034, pitch=0.04)
    for i in range(5):
        shell.append(box(f"Stripe{i}", (0.1135, 0.025, 0.1335), (0, -0.12 + i * 0.05, 0.017), bevel=0.034, m=M["trim"]))
    for side in (-1, 1):
        for i in range(9):
            shell.append(sphere(f"Marquee{side}{i}", 0.0068, (side * 0.05, -0.125 + i * 0.03, 0.08), m=M["cell"], segs=8, rings=4))
    shell += vent_slots("Vent", 0.0565, -0.1, -0.03, 0.0, 3, M["dark"], M["cell"], side=1)
    lug, charm_point = charm_lug(-0.0567, -0.125, 0.058, M)
    shell += lug
    sight_rear, sight_front = sights_bead(0.0, -0.08, 0.215, rail_top, 0.123, z_line, M)

    # The wheel and the six barrels turn together (Barrels).
    spinner = [
        ycyl("ClampRear", 0.047, 0.02, 0.178, z=0.0, m=M["dark"], segs=24),
        ycyl("ClampMid", 0.044, 0.016, 0.39, z=0.0, m=M["dark"], segs=24),
        ycyl("ClampFront", 0.046, 0.022, 0.49, z=0.0, m=M["trim"], segs=24),
        ycyl("Axle", 0.012, 0.34, 0.33, z=0.0, m=M["steel"], segs=10),
        ycyl("WheelHub", 0.046, 0.026, wheel_y, z=0.0, m=M["dark"], segs=24),
        torus("WheelRim", wheel_r, 0.006, (0, wheel_y, 0.0), rot=rad(90, 0, 0), m=M["steel"], major_segs=40, minor_segs=5),
        star("Jackpot", 0.015, 0.004, (0, wheel_y - 0.0115, 0.078), m=M["cell"]),
    ]
    for k in range(6):
        a = math.tau * k / 6 + math.pi / 6
        x, z = math.cos(a) * 0.03, math.sin(a) * 0.03
        spinner.append(ycyl(f"Barrel{k}", 0.0105, 0.33, 0.345, z=z, x=x, m=M["steel"], segs=8, bevel=0.0))
        spinner.append(ycyl(f"BarrelTip{k}", 0.0125, 0.008, 0.508, z=z, x=x, m=M["cell"], segs=8, bevel=0.0))
    segs = 12
    for k in range(segs):
        a0 = math.tau * k / segs + math.pi / 2 - math.pi / segs
        spinner.append(sector(f"Wedge{k}", 0.047, wheel_r - 0.003, a0, a0 + math.tau / segs, 0.02, wheel_y, 0.0, wheel_mats[k % 4]))
        a = a0
        spinner.append(sphere(f"Bulb{k}", 0.0078, (math.cos(a) * wheel_r, wheel_y, math.sin(a) * wheel_r), m=M["cell"], segs=8, rings=5))
        spinner.append(ycyl(f"Peg{k}", 0.0028, 0.018, wheel_y - 0.018, z=math.sin(a) * (wheel_r - 0.01), x=math.cos(a) * (wheel_r - 0.01),
                            m=M["steel"], segs=6, bevel=0.0))
    ticker_pivot = (0, 0.27, 0.118)
    ticker = [
        ycyl("TickerPin", 0.004, 0.012, 0.27, z=0.118, m=M["steel"], segs=8),
        box("TickerFlap", (0.012, 0.005, 0.026), (0, 0.276, 0.105), rot=rad(-14, 0, 0), bevel=0.002, m=M["pink"]),
        sphere("TickerTip", 0.0042, (0, 0.279, 0.093), m=M["pink"], segs=8, rings=5),
    ]
    can_c = (-0.075, 0.02, 0.005)
    canister = [
        ycyl("CanCore", 0.022, 0.12, can_c[1], z=can_c[2], x=can_c[0], m=M["cell"], segs=16),
        ycyl("CanCapR", 0.025, 0.016, can_c[1] - 0.064, z=can_c[2], x=can_c[0], m=M["steel"], segs=16),
        ycyl("CanCapF", 0.025, 0.016, can_c[1] + 0.064, z=can_c[2], x=can_c[0], m=M["steel"], segs=16),
    ]
    for i in range(3):
        canister.append(ycyl(f"CanBand{i}", 0.0235, 0.006, can_c[1] - 0.03 + i * 0.03, z=can_c[2], x=can_c[0], m=M["dark"], segs=16, bevel=0.0))
    canister_holo = holo_copy(canister[:3])
    decal = [side_emblem("Emblem", star_outline(0.018, 0.008), -0.057, -0.045, 0.0, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = support_hand(fore, 0.025, 0.022, M, (-0.52, -0.12, -0.46), corner=0.012, finger_len=0.045, thumb_len=0.045)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.08, rail_top), None),
        "IronSightFront": (sight_front, (0, 0.215, 0.123), None),
        "Barrels": (spinner, spin_c, None),
        "Ticker": (ticker, ticker_pivot, None),
        "Cell": (canister, can_c, None),
        "CellHolo": (canister_holo, can_c, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    empties = {
        "Muzzle": ((0, 0.525, 0.0), None),
        "SightPoint": ((0, -0.08, z_line), None),
        "SightMount": ((0, 0.01, rail_top), None),
        "EjectPoint": ((-0.105, 0.02, 0.005), None),
        "VentPoint": ((0, 0.145, 0.06), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("whirligig", groups, empties)


# ---------------------------------------------------------------------------
# Riptide Harpoon: charged harpoon launcher that reels its catch in
# ---------------------------------------------------------------------------

def build_riptide():
    reset_scene()
    palette("#22b3b8", "#203a78", "#1a1d33", "#d7a64a", "#ff6178", steel_metal=0.65)
    M = weapon_mats("#62f4ff", emit=1.5)
    wood = mat("Wood", "#b67a45", rough=0.7)
    rope = mat("Rope", "#ecdcae", rough=0.8)
    white = mat("RingWhite", "#f6f4ee", rough=0.45)
    spear_m = mat("Spear", "#d9e2ec", rough=0.25, metal=0.7)
    bore_z = 0.045
    rail_top = 0.1
    z_line = rail_top + SIGHT_HEIGHT
    fore = (0, 0.42, 0.0)
    reel_c = (-0.065, 0.03, 0.03)
    tank_c = (0, 0.3, -0.012)
    grip_loc = (0, -0.05, -0.12)
    grip_parts, G = grip("", grip_loc, M, tilt=-15, size=(0.07, 0.09, 0.18), body_bottom=-0.03)
    shell = grip_parts + [
        # Teal receiver over a navy keel, a long barrel with brass bands.
        box("Receiver", (0.08, 0.25, 0.11), (0, 0.0, 0.025), bevel=0.03, m=M["shell"]),
        box("Keel", (0.082, 0.2, 0.034), (0, 0.0, -0.012), bevel=0.012, m=M["trim"]),
        box("RailRiser", (0.04, 0.2, 0.012), (0, 0.0, 0.084), bevel=0.004, m=M["dark"]),
        ycyl("Barrel", 0.03, 0.42, 0.33, z=bore_z, m=M["shell"], segs=22),
        ring("BandA", 0.031, 0.005, 0.14, z=bore_z, m=M["steel"], segs=22),
        ring("BandB", 0.031, 0.005, 0.37, z=bore_z, m=M["steel"], segs=22),
        ycyl("Crown", 0.037, 0.032, 0.528, z=bore_z, m=M["steel"], segs=22, bevel=0.008),
        ring("CrownGlow", 0.026, 0.0035, 0.545, z=bore_z, m=M["cell"], segs=20),
        ycyl("Bore", 0.022, 0.006, 0.543, z=bore_z, m=mat("Bore", "#0e1424", rough=0.9), segs=16, bevel=0.0),
        # Tank straps and the wooden foregrip (boardwalk planks).
        box("StrapR", (0.012, 0.016, 0.07), (0, 0.24, 0.016), bevel=0.003, m=M["steel"]),
        box("StrapF", (0.012, 0.016, 0.07), (0, 0.36, 0.016), bevel=0.003, m=M["steel"]),
        box("Foregrip", (0.05, 0.11, 0.048), fore, bevel=0.012, m=wood),
        # Plank stock with a brass butt and a coral fin.
        box("Stock", (0.05, 0.15, 0.07), (0, -0.19, 0.0), bevel=0.014, m=wood),
        box("Butt", (0.056, 0.016, 0.08), (0, -0.27, 0.0), bevel=0.006, m=M["steel"]),
        side_profile("TailFin", [(-0.24, 0.032), (-0.15, 0.032), (-0.2, 0.06), (-0.25, 0.064)], 0.008, (0, 0, 0), M["pink"], bevel=0.003),
        # Reel axle boss on the left wall.
        xcyl("ReelBoss", 0.016, 0.02, (-0.045, reel_c[1], reel_c[2]), m=M["dark"], segs=12),
    ]
    for i in range(3):
        shell.append(box(f"Plank{i}", (0.052, 0.15, 0.003), (0, -0.19, -0.022 + i * 0.022), bevel=0.0, m=M["dark"]))
        shell.append(box(f"GripPlank{i}", (0.052, 0.11, 0.003), (0, fore[1], fore[2] - 0.016 + i * 0.016), bevel=0.0, m=M["dark"]))
    # Life ring round the barrel, coral and white quarters.
    for k in range(8):
        shell.append(torus(f"LifeRing{k}", 0.045, 0.012, (0, 0.17, bore_z), rot=rad(90, 0, 0), m=M["pink"] if k % 2 == 0 else white,
                           major_segs=5, minor_segs=7, arc=math.tau / 8, start=math.tau * k / 8 + math.pi / 8))
    shell += top_rail("TopRail", -0.09, 0.11, rail_top, M, width=0.034, pitch=0.04)
    for i in range(4):
        shell.append(box(f"Porthole{i}", (0.004, 0.016, 0.016), (0.041, -0.06 + i * 0.04, 0.045), rot=rad(45, 0, 0), bevel=0.0, m=M["cell"]))
    lug, charm_point = charm_lug(-0.04, -0.1, 0.058, M)
    shell += lug
    sight_rear, sight_front = sights_globe(0.0, -0.08, 0.5, rail_top, bore_z + 0.03, z_line, M)

    reel = [
        xcyl("Spool", 0.022, 0.032, reel_c, m=wood, segs=16),
        xcyl("FlangeIn", 0.042, 0.005, (reel_c[0] + 0.017, reel_c[1], reel_c[2]), m=M["steel"], segs=24),
        xcyl("FlangeOut", 0.042, 0.005, (reel_c[0] - 0.017, reel_c[1], reel_c[2]), m=M["steel"], segs=24),
        box("CrankArm", (0.006, 0.01, 0.05), (reel_c[0] - 0.023, reel_c[1], reel_c[2] + 0.02), bevel=0.002, m=M["steel"]),
        xcyl("CrankKnob", 0.008, 0.018, (reel_c[0] - 0.033, reel_c[1], reel_c[2] + 0.042), m=M["pink"], segs=10),
    ]
    for i in range(4):
        reel.append(torus(f"Wrap{i}", 0.027, 0.0045, (reel_c[0] - 0.011 + i * 0.0073, reel_c[1], reel_c[2]), rot=rad(0, 90, 0), m=rope,
                          major_segs=14, minor_segs=4))
    harpoon = [
        ycyl("Shaft", 0.0065, 0.2, 0.52, z=bore_z, m=spear_m, segs=8),
        ycyl("Head", 0.021, 0.068, 0.652, z=bore_z, m=M["cell"], segs=10, bevel=0.002, radius_top=0.0015),
        ycyl("Collar", 0.011, 0.012, 0.616, z=bore_z, m=M["steel"], segs=10),
    ]
    for i, side in enumerate((-1, 1)):
        harpoon.append(box(f"Barb{i}", (0.005, 0.034, 0.009), (side * 0.021, 0.628, bore_z), rot=rad(0, 0, side * 30), bevel=0.001, m=M["cell"]))
    tank = [
        ycyl("TankCore", 0.022, 0.13, tank_c[1], z=tank_c[2], m=M["cell"], segs=16),
        ycyl("TankCapR", 0.025, 0.018, tank_c[1] - 0.072, z=tank_c[2], m=M["steel"], segs=16),
        ycyl("TankCapF", 0.025, 0.018, tank_c[1] + 0.072, z=tank_c[2], m=M["steel"], segs=16),
        ycyl("TankValve", 0.008, 0.02, tank_c[1] + 0.09, z=tank_c[2], m=M["pink"], segs=8),
    ]
    tank_holo = holo_copy(tank[:3])
    anchor = [(-0.003, 0.02), (0.003, 0.02), (0.003, -0.006), (0.014, -0.002), (0.004, -0.016), (-0.004, -0.016), (-0.014, -0.002), (-0.003, -0.006)]
    decal = [side_emblem("Emblem", anchor, -0.0255, -0.19, 0.004, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = support_hand(fore, 0.025, 0.024, M, (-0.52, -0.1, -0.46), corner=0.012, finger_len=0.045, thumb_len=0.045)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.08, rail_top), None),
        "IronSightFront": (sight_front, (0, 0.5, bore_z + 0.03), None),
        "Harpoon": (harpoon, (0, 0.53, bore_z), None),
        "Reel": (reel, reel_c, None),
        "Cell": (tank, tank_c, None),
        "CellHolo": (tank_holo, tank_c, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    empties = {
        "Muzzle": ((0, 0.55, bore_z), None),
        "SightPoint": ((0, -0.08, z_line), None),
        "SightMount": ((0, 0.01, rail_top), None),
        "EjectPoint": ((0, 0.3, -0.04), None),
        "VentPoint": ((0, 0.38, -0.012), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("riptide", groups, empties)


BUILDERS = (
    ("drum_popper", build_drum_popper),
    ("whirligig", build_whirligig),
    ("riptide", build_riptide),
)

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for name, fn in BUILDERS:
        if not only or name in only:
            fn()
