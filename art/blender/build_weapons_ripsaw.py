"""First-person viewmodel of the Toxic Ripsaw (after references/concept-toxic-ripsaw.png):
a slime-pellet shotgun with a chain saw bar out front.

Same conventions and node contract as build_weapons.py (documented at the top
of weapon_kit.py): origin at the top of the grip, pointing along +Y, the
concept's palette set before weapon_mats (lime Shell, orange Trim, navy
GunDark, grey GunSteel, pink GunPink, yellow-green slime as the Cell glow),
so every finish, decal, sight and charm works. Its moving parts are driven by
scripts/weapons/views/ripsaw_view.gd and scripts/weapons/reloads/ripsaw_reload.gd:

  Tooth0..21   the chain: one candy-cut tooth and its two link plates each,
               pivot on the bar's edge. The view script runs them round the
               bar (CHAIN_* below) and hides the turn inside the receiver.
  Sprocket     nose sprocket (axis X), turns with the chain
  Cell         the slime rack on the left flank (four canisters) >
               Slime0..3 (the slime in each canister, pivot at its floor,
               drained by the saw's fuel), Bubble0..7 (rising in the slime)
  CellHolo     hologram rack for the reload
  Pump         ribbed under-pump > ArmL (the support hand rides it)
  GaugeNeedle  needle on the engine gauge (left side), follows the rev
  PullHandle   pink pull-start handle on top, PullCord (its cord, hidden
               inside the receiver until the equip flourish pulls it out)
  D-handle     the big grey carry handle: optics sit on its rail, the
               shotgun's bead sights stand at its ends (IronSight*)

    python art/blender/build_weapons_ripsaw.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403

# The chain path (Blender Y forward, Z up), mirrored in ripsaw_view.gd: a top
# run from CHAIN_START to the nose sprocket's centre, a half turn of radius
# CHAIN_R round the nose, and the bottom run back. Both ends lie inside the
# receiver, where a tooth wraps round unseen.
CHAIN_START = 0.325
NOSE_Y = 0.585
BAR_Z = 0.058
CHAIN_R = 0.058
TEETH = 22
CANISTERS = 4
BUBBLES_PER = 2

RW = 0.046            # receiver half width


def recolour(parts, names, m):
    """Gives the parts whose name starts with one of `names` the material `m`."""
    for p in parts:
        if any(p.name.startswith(n) for n in names) and p.data.materials:
            p.data.materials[0] = m


def stadium(r, y0, y1, steps=10):
    """Side outline (Y, Z offsets) of a bar with round ends of radius r centred at y0 and y1."""
    out = []
    for i in range(steps + 1):
        a = -math.pi / 2 + math.pi * i / steps
        out.append((y1 + math.cos(a) * r, math.sin(a) * r))
    for i in range(steps + 1):
        a = math.pi / 2 + math.pi * i / steps
        out.append((y0 + math.cos(a) * r, math.sin(a) * r))
    return out


def chain_length():
    return 2.0 * (NOSE_Y - CHAIN_START) + math.pi * CHAIN_R


def chain_point(u):
    """Point on the chain path at distance u, its outward normal and its travel direction (Y, Z)."""
    run = NOSE_Y - CHAIN_START
    arc = math.pi * CHAIN_R
    if u < run:
        return (CHAIN_START + u, BAR_Z + CHAIN_R), (0.0, 1.0), (1.0, 0.0)
    if u < run + arc:
        a = (u - run) / CHAIN_R
        n = (math.sin(a), math.cos(a))
        return (NOSE_Y + n[0] * CHAIN_R, BAR_Z + n[1] * CHAIN_R), n, (math.cos(a), -math.sin(a))
    v = u - run - arc
    return (NOSE_Y - v, BAR_Z - CHAIN_R), (0.0, -1.0), (-1.0, 0.0)


def tooth(i, u, M, link_m):
    """One chain tooth (a chunky fin leaning into its travel) and its two link plates."""
    (py, pz), (ny, nz), (ty, tz) = chain_point(u)

    def at(t, h):
        return (py + ty * t + ny * h, pz + tz * t + nz * h)

    fin = [at(-0.011, -0.004), at(0.011, -0.004), at(0.011, 0.006), at(0.0055, 0.0205), at(-0.0025, 0.022), at(-0.011, 0.0135)]
    parts = [side_profile(f"ToothFin{i}", fin, 0.024, (0, 0, 0), M["trim"], bevel=0.0028, segs=2)]
    # Link plates on the bar's sides (the concept's dashed line), aligned with the travel.
    ly, lz = at(0.0, -0.011)
    angle = math.atan2(tz, ty)
    for k, side in enumerate((-1, 1)):
        parts.append(box(f"ToothLink{i}{k}", (0.0026, 0.0135, 0.0048), (side * 0.0136, ly, lz), rot=(angle, 0, 0), bevel=0.001, m=link_m))
    return parts, (0.0, py, pz)


def build_ripsaw():
    reset_scene()
    # Concept palette: lime, green, grey, orange, yellow-green, pink, navy.
    mat("Shell", "#8ee03c", rough=0.34)
    mat("Trim", "#ff9324", rough=0.38)
    mat("GunDark", "#28204a", rough=0.45, metal=0.2)
    mat("GunSteel", "#9097b4", rough=0.3, metal=0.35)
    mat("GunPink", "#ff4f9e", rough=0.36)
    M = weapon_mats("#b4f52a", emit=1.25)
    deep = mat("ShellDeep", "#4fb52a", rough=0.4)
    light = mat("ShellLight", "#dcff6a", rough=0.3, emit=0.35)
    trim_deep = mat("TrimDeep", "#c9561a", rough=0.45)
    glint = mat("Glint", "#ffffff", rough=0.1, emit=0.8)
    bubble_m = mat("SlimeBubble", "#f4ffc8", rough=0.2, emit=1.2)
    bore = mat("Bore", "#120c22", rough=0.9)
    engine = mat("EngineBody", "#3a3070", rough=0.4, metal=0.2)

    rail_top = 0.2595
    z_line = rail_top + SIGHT_HEIGHT
    grip_loc = (0.0, 0.0, -0.1)
    pump_c = (0.0, 0.225, -0.062)
    rack_y = 0.172
    rack_z = 0.08
    cyl_c = (0.0, -0.1, 0.092)         # rear engine cylinder
    gauge_c = (0.0, -0.004, 0.085)

    grip_m = dict(M, dark=M["trim"], cell=M["pink"])
    grip_parts, G = grip("", grip_loc, grip_m, tilt=-14, size=(0.066, 0.086, 0.17), body_bottom=-0.015, guard_len=0.1)
    recolour(grip_parts, ["Guard"], M["steel"])
    recolour(grip_parts, ["GripStud", "GripPanel"], trim_deep)

    shell = grip_parts + [
        # Lime receiver, its darker belly band and a highlight along the top.
        loft("Receiver", [(-0.094, 0.04, 0.07, 0.064, 0.03), (-0.078, RW, 0.0785, 0.0635, 0.032),
                          (0.342, RW, 0.0785, 0.0635, 0.032), (0.358, 0.04, 0.072, 0.0635, 0.03)], M["shell"]),
        box("Belly", (2 * RW + 0.003, 0.43, 0.04), (0, 0.133, 0.006), bevel=0.012, m=deep),
        box("TopShine", (0.01, 0.36, 0.004), (-0.022, 0.13, 0.1415), bevel=0.0015, m=light),
        # Engine: dark ribbed cylinder at the back with an orange cap.
        ycyl("EngineCyl", 0.048, 0.1, cyl_c[1], z=cyl_c[2], m=engine, segs=24, bevel=0.008),
        ycyl("EngineCap", 0.038, 0.022, cyl_c[1] - 0.058, z=cyl_c[2], m=M["trim"], segs=24, bevel=0.008),
        ycyl("EngineBoss", 0.014, 0.01, cyl_c[1] - 0.072, z=cyl_c[2], m=M["trim"], segs=12, bevel=0.003),
        # Gauge (round engine cap through the receiver): orange rims, navy face, lime hub.
        xcyl("GaugeFace", 0.027, 2 * RW + 0.006, gauge_c, m=M["dark"], segs=24, bevel=0.003),
        xcyl("GaugeHub", 0.0068, 2 * RW + 0.012, gauge_c, m=M["cell"], segs=12, bevel=0.002),
        # Grommet the pull cord runs out of.
        cyl("PullGrommet", 0.009, 0.008, (0, gauge_c[1], 0.1425), segs=14, bevel=0.003, m=M["steel"]),
        # Orange fin sight on the nose (decorative, below the eye line) with pink dots.
        side_profile("NoseFin", [(0.272, 0.138), (0.31, 0.138), (0.302, 0.163), (0.28, 0.163)], 0.016, (0, 0, 0), M["trim"], bevel=0.003),
        # Bar mount under the nose and the slime barrel under the receiver.
        box("BarMount", (0.096, 0.11, 0.03), (0, 0.337, -0.02), bevel=0.008, m=M["trim"]),
        box("BarHanger", (0.014, 0.022, 0.03), (0, 0.345, -0.045), bevel=0.004, m=M["dark"]),
        ycyl("SlimeBarrel", 0.0115, 0.25, 0.265, z=pump_c[2], m=M["steel"], segs=16),
        ycyl("Nozzle", 0.0165, 0.024, 0.39, z=pump_c[2], m=M["trim"], segs=18, bevel=0.005),
        ring("NozzleGlow", 0.0135, 0.0032, 0.4, z=pump_c[2], m=M["cell"]),
        ycyl("NozzleBore", 0.0095, 0.006, 0.4, z=pump_c[2], m=bore, segs=12, bevel=0.0),
        # The bar: orange body, navy inner panel with lime studs.
        side_profile("Bar", [(y, BAR_Z + z) for y, z in stadium(CHAIN_R, 0.31, NOSE_Y, 12)], 0.026, (0, 0, 0), M["trim"], bevel=0.004),
        side_profile("BarPanel", [(y, BAR_Z + z) for y, z in stadium(0.036, 0.33, NOSE_Y - 0.01, 10)], 0.032, (0, 0, 0), M["dark"], bevel=0.003),
        # Stock: a grey hook curving down off the engine, with a rubber end.
        tube("Stock", [(0, -0.115, 0.07), (0, -0.155, 0.056), (0, -0.182, 0.03), (0, -0.196, -0.005), (0, -0.194, -0.035),
                       (0, -0.184, -0.054), (0, -0.168, -0.064)], 0.015, m=M["steel"], segs=12),
        ycyl("StockCap", 0.0175, 0.016, -0.164, z=-0.065, m=M["trim"], segs=16, bevel=0.005),
    ]
    for i in range(5):
        shell.append(torus(f"EngineRib{i}", 0.0482, 0.0028, (0, cyl_c[1] - 0.034 + i * 0.017, cyl_c[2]), rot=rad(90, 0, 0), m=M["dark"],
                           major_segs=20, minor_segs=4))
    for i in range(4):
        shell.append(xcyl(f"BarStud{i}", 0.0056, 0.036, (0, 0.39 + i * 0.042, BAR_Z), m=M["cell"], segs=12, bevel=0.0015))
    for k, side in enumerate((-1, 1)):
        x = side * (RW + 0.004)
        shell += [
            torus(f"GaugeRim{k}", 0.0285, 0.0068, (x, gauge_c[1], gauge_c[2]), rot=rad(0, 90, 0), m=M["trim"], major_segs=20, minor_segs=5),
            sphere(f"NoseDot{k}", 0.0042, (side * 0.0085, 0.29, 0.152), m=M["pink"], segs=8, rings=5),
        ]
        # Three slanted dark-green slashes on the nose.
        for i in range(3):
            shell.append(box(f"Slash{k}{i}", (0.003, 0.0075, 0.05), (side * (RW + 0.0003), 0.302 + i * 0.015, 0.084), rot=rad(-20, 0, 0),
                             bevel=0.0, m=deep))
        # Rivets.
        for i, (y, z) in enumerate(((-0.07, 0.04), (0.052, 0.108), (0.338, 0.104), (0.338, 0.03))):
            shell.append(cyl(f"Rivet{k}{i}", 0.0045, 0.004, (side * (RW + 0.0005), y, z), rot=rad(0, 90, 0), segs=10, bevel=0.0012, m=M["dark"]))
        # Stock rivets.
        for i, (y, z) in enumerate(((-0.176, 0.04), (-0.195, -0.008), (-0.188, -0.048))):
            shell.append(sphere(f"StockRivet{k}{i}", 0.003, (side * 0.0138, y, z), m=M["dark"], segs=6, rings=4))
    # The D-handle: a grey loop over the receiver whose flat top carries the rail.
    corner = 0.024
    top_z = 0.238
    handle = [(0, 0.04, 0.13), (0, 0.04, top_z - corner)]
    handle += [(0, 0.04 + corner - math.cos(math.radians(a)) * corner, top_z - corner + math.sin(math.radians(a)) * corner) for a in range(15, 90, 15)]
    handle += [(0, 0.04 + corner, top_z), (0, 0.214 - corner, top_z)]
    handle += [(0, 0.214 - corner + math.sin(math.radians(a)) * corner, top_z - corner + math.cos(math.radians(a)) * corner) for a in range(15, 90, 15)]
    handle += [(0, 0.214, top_z - corner), (0, 0.214, 0.13)]
    shell.append(tube("DHandle", handle, 0.0135, m=M["steel"], segs=12))
    shell.append(box("DHandleShine", (0.006, 0.12, 0.003), (-0.006, 0.127, top_z + 0.0125), bevel=0.001, m=glint))
    for i, y in enumerate((0.04, 0.214)):
        shell.append(cyl(f"DHandleFoot{i}", 0.019, 0.01, (0, y, 0.142), segs=16, bevel=0.003, m=M["dark"]))
    shell += top_rail("TopRail", 0.072, 0.183, rail_top, dict(M, dark=M["steel"]), width=0.026, pitch=0.02)
    lug, charm_point = charm_lug(-0.048, 0.368, -0.02, M)
    shell += lug
    sight_rear, sight_front = sights_bead(0.0, 0.052, 0.203, 0.247, 0.247, z_line, M)

    # The slime rack on the left flank (Cell): navy plate, shelf and top bar,
    # four canisters with grey caps; the slime and its bubbles are their own nodes.
    rx = -(RW + 0.002)
    rack = [
        box("RackPlate", (0.008, 0.2, 0.068), (rx, rack_y, rack_z), bevel=0.006, m=M["dark"]),
        box("RackShelf", (0.022, 0.196, 0.006), (rx - 0.008, rack_y, rack_z - 0.031), bevel=0.002, m=M["dark"]),
        box("RackTop", (0.022, 0.196, 0.006), (rx - 0.008, rack_y, rack_z + 0.031), bevel=0.002, m=M["dark"]),
    ]
    can_x = -0.0525
    can_ys = [rack_y - 0.069 + 0.046 * i for i in range(CANISTERS)]
    slimes = {}
    bubbles = {}
    for i, y in enumerate(can_ys):
        rack += [
            cyl(f"CanCore{i}", 0.0118, 0.044, (can_x, y, 0.076), segs=16, bevel=0.0, m=M["dark"]),
            cyl(f"CanCap{i}", 0.0158, 0.008, (can_x, y, 0.102), segs=14, bevel=0.0025, m=M["steel"]),
            cyl(f"CanBase{i}", 0.0158, 0.005, (can_x, y, 0.0515), segs=14, bevel=0.0, m=M["steel"]),
        ]
        slimes[f"Slime{i}"] = ([cyl(f"SlimeBody{i}", 0.0138, 0.044, (can_x, y, 0.076), segs=14, bevel=0.002, m=M["cell"]),
                                box(f"SlimeGlint{i}", (0.002, 0.003, 0.03), (can_x - 0.0128, y - 0.0068, 0.078), bevel=0.0, m=glint)],
                               (can_x, y, 0.054))
        for j in range(BUBBLES_PER):
            loc = (can_x - 0.0118, y + (0.004 if j == 0 else -0.003), 0.064 + 0.016 * j)
            bubbles[f"Bubble{i * BUBBLES_PER + j}"] = ([sphere(f"BubbleBall{i}{j}", 0.0036 if j == 0 else 0.0028, loc, m=bubble_m, segs=8, rings=5)], loc)
    rack_holo = holo_copy(rack[:1] + [parts[0] for parts, _p in slimes.values()])
    # The right flank carries a matching fixed rack (full slime, part of the Shell).
    for p in [box("RackPlateR", (0.008, 0.2, 0.068), (-rx, rack_y, rack_z), bevel=0.006, m=M["dark"]),
              box("RackShelfR", (0.022, 0.196, 0.006), (-rx + 0.008, rack_y, rack_z - 0.031), bevel=0.002, m=M["dark"]),
              box("RackTopR", (0.022, 0.196, 0.006), (-rx + 0.008, rack_y, rack_z + 0.031), bevel=0.002, m=M["dark"])]:
        shell.append(p)
    for i, y in enumerate(can_ys):
        shell += [cyl(f"CanSlimeR{i}", 0.0138, 0.044, (-can_x, y, 0.076), segs=12, bevel=0.002, m=M["cell"]),
                  cyl(f"CanCapR{i}", 0.0158, 0.008, (-can_x, y, 0.102), segs=12, bevel=0.0025, m=M["steel"]),
                  cyl(f"CanBaseR{i}", 0.0158, 0.005, (-can_x, y, 0.0515), segs=12, bevel=0.0, m=M["steel"])]

    # Chain teeth, evenly round the path.
    teeth = {}
    pitch = chain_length() / TEETH
    for i in range(TEETH):
        parts, pivot = tooth(i, (i + 0.5) * pitch, M, trim_deep)
        teeth[f"Tooth{i}"] = (parts, pivot)
    sprocket_c = (0.0, NOSE_Y, BAR_Z)
    sprocket = [
        xcyl("SprocketDisc", 0.043, 0.036, sprocket_c, m=M["steel"], segs=24, bevel=0.004),
        xcyl("SprocketHub", 0.03, 0.04, sprocket_c, m=M["trim"], segs=20, bevel=0.003),
        xcyl("SprocketCentre", 0.0105, 0.046, sprocket_c, m=M["cell"], segs=14, bevel=0.002),
    ]
    for k, side in enumerate((-1, 1)):
        sprocket.append(torus(f"SprocketRim{k}", 0.0385, 0.0042, (side * 0.018, NOSE_Y, BAR_Z), rot=rad(0, 90, 0), m=M["steel"],
                              major_segs=24, minor_segs=5))
        for i in range(8):
            a = math.tau * i / 8
            sprocket.append(box(f"Spoke{k}{i}", (0.003, 0.0042, 0.019), (side * 0.0205, NOSE_Y + math.cos(a) * 0.02, BAR_Z + math.sin(a) * 0.02),
                                rot=(a - math.pi / 2, 0, 0), bevel=0.0, m=M["dark"]))

    # Under-pump (lime, ribbed at both ends) on the slime barrel.
    pump = [box("PumpBody", (0.064, 0.13, 0.04), pump_c, bevel=0.014, m=M["shell"])]
    for i, dy in enumerate((-0.0625, -0.057, 0.057, 0.0625)):
        pump.append(box(f"PumpRib{i}", (0.067, 0.0045, 0.043), (0, pump_c[1] + dy, pump_c[2]), bevel=0.002, segs=1, m=deep))

    # Gauge needle and the pull-start handle with its cord.
    needle = [box("Needle", (0.002, 0.0032, 0.019), (-(RW + 0.0062), gauge_c[1], gauge_c[2] + 0.009), bevel=0.0006, m=M["pink"])]
    pull_base = (0.0, gauge_c[1], 0.147)
    pull = [cyl("PullStem", 0.0042, 0.026, (0, gauge_c[1], 0.159), segs=8, bevel=0.001, m=M["pink"]),
            xcyl("PullBar", 0.0074, 0.054, (0, gauge_c[1], 0.175), m=M["pink"], segs=12, bevel=0.003)]
    cord = [cyl("Cord", 0.0018, 0.05, (0, gauge_c[1], pull_base[2] - 0.025), segs=6, bevel=0.0, m=M["dark"])]

    decal = [side_emblem("Emblem", star_outline(0.016, 0.007), -(RW + 0.0016), 0.22, 0.006, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = support_hand(pump_c, 0.035, 0.023, M, (-0.6, 0.25, -0.45), corner=0.014, finger_len=0.025, thumb_len=0.03)

    rack_c = (rx, rack_y, rack_z)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, 0.052, 0.247), None),
        "IronSightFront": (sight_front, (0, 0.203, 0.247), None),
        "Cell": (rack, rack_c, None),
        "CellHolo": (rack_holo, rack_c, None),
        "Sprocket": (sprocket, sprocket_c, None),
        "Pump": (pump, pump_c, None),
        "GaugeNeedle": (needle, (-(RW + 0.0062), gauge_c[1], gauge_c[2]), None),
        "PullHandle": (pull, pull_base, None),
        "PullCord": (cord, pull_base, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, pump_c, "Pump"),
    }
    for name, (parts, pivot) in slimes.items():
        groups[name] = (parts, pivot, "Cell")
    for name, (parts, pivot) in bubbles.items():
        groups[name] = (parts, pivot, "Cell")
    for name, (parts, pivot) in teeth.items():
        groups[name] = (parts, pivot, None)
    empties = {
        "Muzzle": ((0, 0.404, pump_c[2]), None),
        "SightPoint": ((0, 0.052, z_line), None),
        "SightMount": ((0, 0.1275, rail_top), None),
        "EjectPoint": ((rx - 0.03, rack_y, rack_z), None),
        "VentPoint": ((0, cyl_c[1] - 0.082, cyl_c[2]), None),
        "SawPoint": ((0, NOSE_Y + CHAIN_R + 0.02, BAR_Z), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    print(f"[ripsaw] chain length {chain_length():.4f}, pitch {pitch:.4f}, eye line {z_line:.4f}")
    finish("toxic_ripsaw", groups, empties)


if __name__ == "__main__":
    build_ripsaw()
