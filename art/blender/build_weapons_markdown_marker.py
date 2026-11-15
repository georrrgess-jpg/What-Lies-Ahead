"""First-person viewmodel of the Markdown Marker (markdown_marker), the
price-tag labeller pistol: a rounded teal body, a big candy-pink tag-roll
drum on top, a fat yellow scanner nozzle that spits the tags, a pink squeeze
lever under the barrel and a dark rubbery grip with a pop-out cash drawer.

Same conventions and node contract as build_weapons.py (documented at the top
of weapon_kit.py): origin at the top of the grip, pointing along +Y, its own
palette (set before weapon_mats, so the shared material names stay and every
finish, cell, decal and charm works), built-in sights. The drum sits under
the eye line, so the rail rides on a tower at the back and the front sight
on the nozzle's scanner hump. Moving parts, driven by
scripts/weapons/views/markdown_marker_view.gd and
scripts/weapons/reloads/markdown_marker_reload.gd:

  Drum         the pink side plates and the glowing violet hub (axle along X;
               a quarter turn on every shot) >
               Cell      the cream tag roll inside it (the magazine)
               CellHolo  hologram roll for the reload
  ReceiptHolo  the empty roll's last curl of receipt (hidden; the reload
               shows it as a hologram that flutters away)
  Tag          the loaded price tag poking out of the nozzle slot
  Lever        the squeeze lever under the barrel (pivot at its hinge)
  Drawer       the cash drawer in the grip's base (slides out in the reload)
  Pip0..2      the tag-stack lights on the left flank

    python art/blender/build_weapons_markdown_marker.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403

PIPS = 3
ROLL_TAGS = 10


def palette(shell, trim, dark, steel, pink, steel_metal=0.55):
    """Creates the shared weapon materials in this weapon's colours (weapon_mats reuses them)."""
    mat("Shell", shell, rough=0.32)
    mat("Trim", trim, rough=0.36)
    mat("GunDark", dark, rough=0.62, metal=0.05)
    mat("GunSteel", steel, rough=0.26, metal=steel_metal)
    mat("GunPink", pink, rough=0.34)


def tag_roll(prefix, centre, radius, width, cream, pink, core):
    """The tag roll: a cream cylinder along X, pink tags printed round its rim, a violet core."""
    x, y, z = centre
    parts = [
        xcyl(prefix + "Paper", radius, width, centre, m=cream, segs=28, bevel=0.003),
        xcyl(prefix + "Core", radius * 0.36, width + 0.008, centre, m=core, segs=16, bevel=0.002),
    ]
    for i in range(ROLL_TAGS):
        a = math.tau * i / ROLL_TAGS
        parts.append(obox(f"{prefix}Print{i}", (width * 0.7, 0.012, 0.002),
                          (x, y + math.cos(a) * (radius + 0.0006), z + math.sin(a) * (radius + 0.0006)),
                          (1, 0, 0), (0, -math.sin(a), math.cos(a)), bevel=0.0, m=pink))
    return parts


def build_markdown_marker():
    reset_scene()
    palette("#22c7c7", "#ffd23f", "#2b2440", "#b9b3d6", "#ff4fa3")
    M = weapon_mats("#8a5cff", emit=2.4)
    cream = mat("TagCream", "#fff4e0", rough=0.5)
    coin = mat("Coin", "#ffc93c", rough=0.22, metal=0.8)
    grip_size = (0.068, 0.09, 0.18)
    grip_tilt = -16.0
    grip_loc = (0, -0.02, -0.1)
    grip_parts, G = grip("", grip_loc, M, tilt=grip_tilt, size=grip_size, body_bottom=-0.02, panel="dark")
    rail_top = 0.152
    z_line = rail_top + SIGHT_HEIGHT
    drum_c = (0, 0.092, 0.121)
    drum_r = 0.05
    mouth_z = 0.042
    lever_c = (0, 0.196, -0.024)

    shell = grip_parts + [
        # The labeller body: a rounded teal slab, high at the back, a saddle under the drum.
        side_profile("Body", [(-0.078, -0.02), (0.205, -0.02), (0.218, 0.0), (0.218, 0.056), (0.2, 0.064), (0.036, 0.064),
                              (0.022, 0.09), (-0.052, 0.09), (-0.078, 0.066)], 0.07, (0, 0, 0), M["shell"], bevel=0.014, segs=3),
        box("Belly", (0.074, 0.2, 0.016), (0, 0.07, -0.012), bevel=0.006, m=M["dark"]),
        box("RearCap", (0.074, 0.008, 0.05), (0, -0.08, 0.04), bevel=0.003, m=M["dark"]),
        # The rail tower at the back (the drum stays under the eye line).
        box("Tower", (0.032, 0.11, 0.064), (0, -0.04, 0.112), bevel=0.01, m=M["dark"]),
        box("TowerBand", (0.034, 0.012, 0.03), (0, 0.006, 0.1), bevel=0.004, m=M["trim"]),
        # The drum's yoke: two teal arms up to the axle.
        box("YokeBase", (0.08, 0.07, 0.01), (0, drum_c[1], 0.066), bevel=0.004, m=M["dark"]),
        # The tag strip running from the roll down into the nozzle.
        box("Strip", (0.03, 0.06, 0.003), (0, 0.16, 0.074), rot=rad(-20, 0, 0), bevel=0.0, m=cream),
        box("StripGuide", (0.04, 0.026, 0.008), (0, 0.19, 0.068), bevel=0.003, m=M["dark"]),
        # The fat yellow scanner nozzle, its dark slot and a violet scan line.
        box("Nozzle", (0.08, 0.075, 0.06), (0, 0.24, mouth_z), bevel=0.018, segs=3, m=M["trim"]),
        box("NozzleLip", (0.09, 0.018, 0.07), (0, 0.276, mouth_z), bevel=0.012, segs=3, m=M["trim"]),
        box("Slot", (0.058, 0.01, 0.012), (0, 0.283, mouth_z), bevel=0.003, m=mat("Bore", "#140f22", rough=0.9)),
        box("ScanLine", (0.05, 0.004, 0.003), (0, 0.2855, mouth_z - 0.017), bevel=0.0, m=M["cell"]),
        box("ScanHump", (0.03, 0.03, 0.05), (0, 0.24, 0.09), bevel=0.008, m=M["trim"]),
        # The lever's hinge block under the front of the body.
        box("LeverHinge", (0.03, 0.026, 0.02), (0, lever_c[1], lever_c[2] + 0.006), bevel=0.005, m=M["dark"]),
        # The window on the left flank (the tag-stack pips sit in it).
        box("WindowFrame", (0.006, 0.07, 0.03), (-0.035, 0.035, 0.045), bevel=0.003, m=M["dark"]),
        box("Window", (0.004, 0.056, 0.008), (-0.0375, 0.035, 0.034), bevel=0.001, m=M["cell"]),
        box("RightPanel", (0.006, 0.1, 0.026), (0.035, 0.07, 0.035), bevel=0.003, m=M["trim"]),
        # "SALE" in cream on the nozzle's left side.
        text("Sale", "SALE", 0.018, 0.0016, (-0.0405, 0.24, mouth_z - 0.006), rot=rad(90, 0, -90), m=cream),
    ]
    for side in (-1, 1):
        shell.append(box(f"Yoke{side}", (0.006, 0.03, 0.06), (side * 0.042, drum_c[1], 0.094), bevel=0.002, m=M["shell"]))
        shell.append(xcyl(f"YokeBoss{side}", 0.009, 0.006, (side * 0.042, drum_c[1], drum_c[2]), m=M["steel"], segs=12))
    for i in range(PIPS):
        shell.append(box(f"PipSocket{i}", (0.003, 0.012, 0.012), (-0.0375, 0.015 + i * 0.02, 0.052), bevel=0.001, m=M["dark"]))
    for i in range(4):
        shell.append(box(f"Rib{i}", (0.076, 0.006, 0.006), (0, -0.04 + i * 0.022, 0.0), bevel=0.002, m=M["trim"]))
    shell += top_rail("TopRail", -0.074, 0.03, rail_top, M, width=0.03)
    shell += bolts("Pin", [(-0.036, -0.04, 0.01), (0.036, -0.04, 0.01), (0.036, 0.15, 0.02)], M["steel"], radius=0.0055, height=0.006)
    lug, charm_point = charm_lug(0.046, 0.245, 0.03, M, out=1.0)
    shell += lug
    sight_rear, sight_front = sights_notch(0.0, -0.086, 0.248, rail_top, 0.115, z_line, M, gap=0.015)

    # The drum: pink plates either side of the roll, glowing hubs with cream spokes.
    dx, dy, dz = drum_c
    drum = []
    for side in (-1, 1):
        drum.append(xcyl(f"Plate{side}", drum_r, 0.008, (side * 0.029, dy, dz), m=M["pink"], segs=32, bevel=0.003))
        drum.append(torus(f"PlateRim{side}", drum_r - 0.002, 0.0028, (side * 0.0335, dy, dz), rot=rad(0, 90, 0), m=cream, major_segs=32, minor_segs=5))
        drum.append(xcyl(f"Hub{side}", 0.017, 0.004, (side * 0.0345, dy, dz), m=M["cell"], segs=20, bevel=0.0012))
        for k in range(4):
            a = math.tau * k / 4
            drum.append(obox(f"Spoke{side}{k}", (0.003, 0.014, 0.0035), (side * 0.037, dy + math.cos(a) * 0.009, dz + math.sin(a) * 0.009),
                             (1, 0, 0), (0, math.cos(a), math.sin(a)), bevel=0.0, m=cream))
    roll = tag_roll("Roll", drum_c, 0.043, 0.048, cream, M["pink"], M["cell"])
    roll_holo = holo_copy(roll[:2])

    # The empty roll's receipt curl (shown only in the reload, as a hologram).
    curl = [(0.0, dy, dz + 0.012)]
    for k in range(1, 15):
        a = k * 0.55
        r = 0.01 + k * 0.0026
        curl.append((0.0, dy + math.sin(a) * r, dz + 0.012 + math.cos(a) * r))
    holo = mat("Holo")
    receipt = []
    for i in range(len(curl) - 1):
        p0, p1 = Vector(curl[i]), Vector(curl[i + 1])
        seg = p1 - p0
        receipt.append(obox(f"Receipt{i}", (0.034, seg.length + 0.002, 0.0025), tuple((p0 + p1) * 0.5), (1, 0, 0), tuple(seg.normalized()),
                            bevel=0.0, m=holo))

    # The loaded tag in the slot, and the squeeze lever.
    loaded = [box("TagBody", (0.032, 0.02, 0.0026), (0, 0.29, mouth_z), bevel=0.0008, m=cream),
              box("TagStripe", (0.024, 0.006, 0.003), (0, 0.293, mouth_z), bevel=0.0, m=M["pink"])]
    lx, ly, lz = lever_c
    lever = [tube("LeverBar", [(lx, ly, lz), (lx, ly - 0.002, lz - 0.04), (lx, ly - 0.014, lz - 0.078), (lx, ly - 0.034, lz - 0.1)],
                  0.0085, m=M["pink"], segs=10),
             xcyl("LeverPin", 0.006, 0.034, lever_c, m=M["steel"], segs=10),
             sphere("LeverPad", 0.012, (lx, ly - 0.036, lz - 0.102), scale=(1, 1.3, 0.8), m=M["dark"], segs=12, rings=8)]

    # The cash drawer under the grip cap: an open tray with coins and a yellow front.
    sx, sy, sz = grip_size
    th = math.radians(grip_tilt)
    gf = frame(grip_loc, (1, 0, 0), (0, math.cos(th), math.sin(th)))

    def g(x, y, z):
        return tuple(fpt(gf, x, y, z))

    dz0 = -sz / 2 - 0.021
    drawer_c = g(0, 0, dz0)
    r_tilt = (th, 0, 0)
    drawer = [
        box("DrawerFloor", (sx - 0.006, sy - 0.006, 0.004), g(0, 0, dz0 - 0.009), rot=r_tilt, bevel=0.001, m=M["dark"]),
        box("DrawerFront", (sx + 0.004, 0.01, 0.026), g(0, sy / 2 - 0.003, dz0), rot=r_tilt, bevel=0.003, m=M["trim"]),
        box("DrawerBack", (sx - 0.006, 0.005, 0.02), g(0, -sy / 2 + 0.006, dz0), rot=r_tilt, bevel=0.001, m=M["dark"]),
        box("DrawerKnob", (0.016, 0.006, 0.006), g(0, sy / 2 + 0.002, dz0), rot=r_tilt, bevel=0.002, m=cream),
    ]
    for side in (-1, 1):
        drawer.append(box(f"DrawerSide{side}", (0.004, sy - 0.006, 0.02), g(side * (sx / 2 - 0.005), 0, dz0), rot=r_tilt, bevel=0.001, m=M["dark"]))
    for i, (cx, cy) in enumerate(((-0.014, -0.02), (0.012, -0.012), (-0.004, 0.012), (0.016, 0.022), (-0.018, 0.024))):
        drawer.append(cyl(f"Coin{i}", 0.009, 0.004, g(cx, cy, dz0 - 0.005 + 0.003 * (i % 2)), rot=r_tilt, segs=14, bevel=0.001, m=coin))

    pips = {}
    for i in range(PIPS):
        c = (-0.0385, 0.015 + i * 0.02, 0.052)
        pips[f"Pip{i}"] = ([box(f"PipLight{i}", (0.003, 0.009, 0.009), c, bevel=0.001, m=M["cell"])], c)

    decal = [side_emblem("Emblem", star_outline(0.016, 0.007), -0.035, -0.03, 0.04, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.42, -0.5, -0.36))
    arm_l, elbow_l = cup_hand(G, M, (-0.55, -0.32, -0.32))
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.086, rail_top), None),
        "IronSightFront": (sight_front, (0, 0.248, 0.115), None),
        "Drum": (drum, drum_c, None),
        "Cell": (roll, drum_c, "Drum"),
        "CellHolo": (roll_holo, drum_c, "Drum"),
        "ReceiptHolo": (receipt, (0, dy, dz + 0.012), None),
        "Tag": (loaded, (0, 0.29, mouth_z), None),
        "Lever": (lever, lever_c, None),
        "Drawer": (drawer, drawer_c, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, grip_loc, None),
    }
    for name, (parts, pivot) in pips.items():
        groups[name] = (parts, pivot, None)
    empties = {
        "Muzzle": ((0, 0.296, mouth_z), None),
        "SightPoint": ((0, -0.086, z_line), None),
        "SightMount": ((0, -0.022, rail_top), None),
        "EjectPoint": ((0, dy, dz + drum_r), None),
        "VentPoint": (g(0, sy / 2 + 0.01, dz0), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("markdown_marker", groups, empties)


BUILDERS = (
    ("markdown_marker", build_markdown_marker),
)

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for name, fn in BUILDERS:
        if not only or name in only:
            fn()
