"""The Jack Pot (update 13 secondary): a candy-striped mortar pistol that lobs
spring-loaded jack-in-the-box mines. Two models:

art/models/jack_pot.glb, the first-person viewmodel. Same conventions and
node contract as build_weapons.py (documented at the top of weapon_kit.py):
origin at the top of the grip, pointing along +Y, its own palette (set
before weapon_mats, so every finish, cell, decal and charm works). Its moving
parts are driven by scripts/weapons/views/jack_pot_view.gd and the reload by
scripts/weapons/reloads/jack_pot_reload.gd:

  Box         the loaded jack-in-the-box sitting lid-first in the launch cup
              (the magazine), Lid its hinged lid (child of Box)
  CellHolo    the reload's hologram box (hidden), on the Box's pivot
  Cell        the glowing mint launch ring round the cup's base
  Crank       the music-box crank on the left flank (turns about X)
  Drum        the brass pinned music-box cylinder under its comb (turns about Y)
  Bulb0..2    the lamps on the top-left edge: one lit per box out in the field
  Trigger     the fat yellow trigger

art/models/jack_pot_box.glb, the mine itself at world scale (about 34 cm),
driven by scripts/weapons/jack_pot_box.gd:

  Box         the box: blue sides with stars, yellow corner posts
  Lid         the red lid (pivot on its back hinge), Lamp the star lamp on it
  Crank       the brass wind-up crank on its right side (turns about X)
  Spring      the coil (origin at its foot, stretched along Z in the game)
  Clown       the clown's head and ruff (origin at its neck), with its
              Arm (a little coil reaching forward, stretched along +Y) and
              Glove (the boxing glove at the arm's end) as children

    python art/blender/build_weapons_jack_pot.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403

BULBS = 3
# The launch cup leans up this far (degrees) from the barrel line.
CUP_TILT = 22.0
# The crank's throw: its knob turns on this radius round the hub
# (scripts/weapons/reloads/jack_pot_reload.gd KNOB).
CRANK_R = 0.044
# The mine's spring and arm at rest (metres, at the world box's scale).
BOX_SIZE = 0.34


def palette():
    """Candy cream shell, candy-apple red trim, grape dark, brass steel, sunshine accents."""
    mat("Shell", "#fff1e2", rough=0.34)
    mat("Trim", "#ee2f52", rough=0.34)
    mat("GunDark", "#3b2356", rough=0.48, metal=0.15)
    mat("GunSteel", "#e2ad48", rough=0.3, metal=0.7)
    mat("GunPink", "#ffcf3a", rough=0.4)


def transform_parts(parts, matrix):
    """Moves built parts by a 4x4 matrix (their mesh stays in their own space)."""
    bpy.context.view_layer.update()
    for p in parts:
        p.matrix_world = matrix @ p.matrix_world
    return parts


def jack_box(prefix, s, mats, lamp=None, hole=None):
    """A jack-in-the-box of size `s`, bottom centre at the origin, lid up (+Z),
    front +Y. Returns (body parts, lid parts, crank parts, lamp parts,
    hinge point, crank hub)."""
    blue, red, yellow, white, brass = mats
    h = s * 0.86
    body = [box(f"{prefix}Body", (s * 0.92, s * 0.92, h), (0, 0, h / 2), bevel=s * 0.03, m=blue)]
    for i, (x, y) in enumerate(((1, 1), (1, -1), (-1, 1), (-1, -1))):
        body.append(cyl(f"{prefix}Post{i}", s * 0.065, h, (x * s * 0.46, y * s * 0.46, h / 2), segs=10, bevel=s * 0.02, m=yellow))
    for z, nm in ((s * 0.035, "Foot"), (h - s * 0.03, "Rim")):
        body.append(box(f"{prefix}{nm}X", (s * 1.0, s * 0.96, s * 0.07), (0, 0, z), bevel=s * 0.02, m=yellow if nm == "Rim" else red))
    # A star on every side, a white dot in each corner.
    for k in range(4):
        a = math.radians(90 * k)
        nx, ny = math.cos(a), math.sin(a)
        face = s * 0.462
        body.append(prism(f"{prefix}Star{k}", star_outline(s * 0.22, s * 0.1), s * 0.02,
                          (nx * face, ny * face, h * 0.5), rot=rad(0, 0, 90 * k - 90), m=yellow))
        for j, (u, v) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
            tx, ty = -ny, nx
            body.append(cyl(f"{prefix}Dot{k}{j}", s * 0.045, s * 0.02,
                            (nx * face + tx * u * s * 0.3, ny * face + ty * u * s * 0.3, h * 0.5 + v * s * 0.27),
                            rot=rad(-90, 0, 90 * k - 90), segs=10, bevel=0.0, m=white))
    body.append(cyl(f"{prefix}Hole", s * 0.3, s * 0.01, (0, 0, h + s * 0.003), segs=20, bevel=0.0, m=hole or blue))
    hinge = (0, -s * 0.5, h)
    lid = [box(f"{prefix}LidTop", (s * 1.02, s * 1.02, s * 0.12), (0, 0, h + s * 0.06), bevel=s * 0.035, m=red),
           box(f"{prefix}LidBand", (s * 1.03, s * 1.03, s * 0.035), (0, 0, h + s * 0.02), bevel=s * 0.012, m=yellow)]
    lamp_parts = []
    if lamp is not None:
        lamp_parts = [prism(f"{prefix}LampStar", star_outline(s * 0.2, s * 0.09), s * 0.05, (0, 0, h + s * 0.13), rot=rad(90, 0, 0), m=lamp)]
    else:
        lid.append(prism(f"{prefix}LidStar", star_outline(s * 0.2, s * 0.09), s * 0.04, (0, 0, h + s * 0.13), rot=rad(90, 0, 0), m=yellow))
    lid.append(box(f"{prefix}Latch", (s * 0.16, s * 0.06, s * 0.1), (0, s * 0.51, h + s * 0.02), bevel=s * 0.02, m=brass))
    hub = (s * 0.5, 0.0, h * 0.5)
    crank = [cyl(f"{prefix}CrankHub", s * 0.07, s * 0.08, (s * 0.5, 0, h * 0.5), rot=rad(0, 90, 0), segs=12, bevel=s * 0.015, m=brass),
             box(f"{prefix}CrankArm", (s * 0.05, s * 0.07, s * 0.3), (s * 0.55, 0, h * 0.5 + s * 0.13), bevel=s * 0.02, m=brass),
             cyl(f"{prefix}CrankKnob", s * 0.05, s * 0.14, (s * 0.62, 0, h * 0.5 + s * 0.26), rot=rad(0, 90, 0), segs=10, bevel=s * 0.015, m=red),
             sphere(f"{prefix}CrankBall", s * 0.06, (s * 0.7, 0, h * 0.5 + s * 0.26), m=red, segs=10, rings=6)]
    return body, lid, crank, lamp_parts, hinge, hub


# ---------------------------------------------------------------------------
# The viewmodel
# ---------------------------------------------------------------------------

def body_stripes(prefix, side_x, y0, y1, z0, z1, width, pitch, m, depth=0.002):
    """Candy stripes slanted 45 degrees across a flat side (x = side_x), each
    clipped to the rectangle y0..y1, z0..z1."""
    parts = []
    out = 1.0 if side_x > 0 else -1.0
    c = y0 - z1 + pitch * 0.5
    i = 0
    while c < y1 - z0:
        # The stripe is the line y - z = c inside the rectangle.
        ya, yb = max(y0, z0 + c), min(y1, z1 + c)
        if yb - ya > width:
            length = (yb - ya) * math.sqrt(2) - width
            mid_y = (ya + yb) / 2
            mid = (side_x + out * depth / 2, mid_y, mid_y - c)
            parts.append(obox(f"{prefix}{i}", (length, width, depth), mid, (0, 1, 1), (0, -1, 1), bevel=0.0, m=m))
            i += 1
        c += pitch
    return parts


def build_jack_pot():
    reset_scene()
    palette()
    M = weapon_mats("#58f5c0", emit=2.2)
    blue = mat("JackBlue", "#3270ff", rough=0.35)
    yellow = M["pink"]
    white = mat("JackWhite", "#fff8ee", rough=0.4)
    lamp = mat("BulbLit", "#ffe65a", rough=0.3, emit=3.0)
    grip_loc = (0, -0.022, -0.104)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.07, 0.094, 0.185), body_bottom=-0.03)
    trig = [p for p in grip_parts if p.name in ("Trigger", "TriggerToe")]
    grip_parts = [p for p in grip_parts if p not in trig]
    for p in trig:
        p.data.materials[0] = M["pink"]
        p.scale = (1.5, 1.25, 1.1)
        p.name = "Fat" + p.name     # the export node takes the name "Trigger"
    y_trig = G["trigger"][0]

    rail_top = 0.1
    z_line = rail_top + SIGHT_HEIGHT
    tilt = math.radians(CUP_TILT)
    axis = Vector((0, math.cos(tilt), math.sin(tilt)))
    up_n = Vector((0, -math.sin(tilt), math.cos(tilt)))
    cup_base = Vector((0, 0.148, 0.03))
    cup_len, cup_r = 0.075, 0.054
    cup_c = cup_base + axis * (cup_len / 2)
    cup_top = cup_base + axis * cup_len
    cup_rot = rad(-(90 - CUP_TILT), 0, 0)
    crank_hub = (-0.037, 0.06, 0.036)
    drum_c = (-0.047, -0.032, 0.052)
    side = 0.035

    shell = grip_parts + [
        side_profile("Body", [(-0.062, -0.03), (0.16, -0.03), (0.16, 0.02), (0.12, 0.07), (0.075, 0.09), (-0.062, 0.09)],
                     side * 2, (0, 0, 0), M["shell"], bevel=0.01),
        # The back is a narrow neck, so the sight picture stays clear.
        side_profile("BodyRear", [(-0.092, -0.03), (-0.055, -0.03), (-0.055, 0.09), (-0.075, 0.09), (-0.092, 0.07)],
                     0.042, (0, 0, 0), M["trim"], bevel=0.008),
        box("Frame", (0.072, 0.2, 0.026), (0, 0.035, -0.021), bevel=0.01, m=M["dark"]),
        # The launch cup: a fat candy-striped mortar leaning up, a gold lip and a dark bore.
        cyl("Cup", cup_r, cup_len, tuple(cup_c), rot=cup_rot, segs=40, bevel=0.008, m=M["shell"]),
        torus("CupLip", cup_r + 0.001, 0.0055, tuple(cup_top), rot=cup_rot, m=M["steel"], major_segs=40, minor_segs=8),
        cyl("CupBore", cup_r - 0.008, 0.004, tuple(cup_top - axis * 0.001), rot=cup_rot, segs=40, bevel=0.0, m=M["dark"]),
        cyl("CupFoot", cup_r - 0.006, 0.012, tuple(cup_base + axis * 0.004), rot=cup_rot, segs=40, bevel=0.004, m=M["dark"]),
        box("CupMount", (0.06, 0.06, 0.045), (0, 0.13, 0.008), bevel=0.01, m=M["dark"]),
        # The music box on the left flank: brass end plates, a steel comb over the drum.
        box("CombBase", (0.012, 0.074, 0.01), (drum_c[0] + 0.002, drum_c[1], drum_c[2] + 0.021), bevel=0.003, m=M["steel"]),
        box("DrumPlateR", (0.016, 0.006, 0.03), (drum_c[0] + 0.004, drum_c[1] - 0.039, drum_c[2] + 0.004), bevel=0.002, m=M["steel"]),
        box("DrumPlateF", (0.016, 0.006, 0.03), (drum_c[0] + 0.004, drum_c[1] + 0.039, drum_c[2] + 0.004), bevel=0.002, m=M["steel"]),
        box("DrumBed", (0.008, 0.084, 0.034), (-0.038, drum_c[1], drum_c[2]), bevel=0.003, m=M["dark"]),
        # The crank's gear boss on the flank.
        cyl("CrankBoss", 0.016, 0.006, (crank_hub[0] - 0.001, crank_hub[1], crank_hub[2]), rot=rad(0, 90, 0), segs=20, bevel=0.002, m=M["dark"]),
        # Bulb sockets on the top-left edge, a pink accent stripe down the top.
        box("BulbBed", (0.014, 0.07, 0.006), (-0.026, -0.02, 0.089), bevel=0.002, m=M["dark"]),
    ]
    for k in range(9):
        shell.append(box(f"CombTooth{k}", (0.003, 0.0045, 0.012), (drum_c[0], drum_c[1] - 0.028 + k * 0.007, drum_c[2] + 0.017),
                         bevel=0.0008, m=M["steel"]))
    for i in range(BULBS):
        shell.append(sphere(f"BulbSocket{i}", 0.0058, (-0.026, -0.044 + 0.024 * i, 0.091), scale=(1, 1, 0.7), m=M["dark"], segs=10, rings=6))
    # Candy stripes: slanted across both flanks, and spiralling round the cup.
    shell += body_stripes("StripeL", -side, -0.058, 0.07, -0.02, 0.078, 0.011, 0.034, M["trim"])
    for k in range(4):
        pts = []
        for j in range(13):
            t = j / 12
            a = math.tau * k / 4 + t * math.pi * 0.9
            pts.append(tuple(cup_base + axis * (0.006 + t * (cup_len - 0.013)) + (Vector((1, 0, 0)) * math.cos(a) + up_n * math.sin(a)) * (cup_r + 0.0005)))
        shell.append(tube(f"CupStripe{k}", pts, 0.0062, m=M["trim"], segs=8))
    shell += top_rail("TopRail", -0.052, 0.062, rail_top, M, width=0.03)
    shell += bolts("Pin", [(-0.036, -0.06, 0.0), (0.036, -0.06, 0.0), (0.036, 0.12, 0.0)], M["steel"], radius=0.005, height=0.006)
    lug, charm_point = charm_lug(0.064, 0.13, 0.035, M, out=1.0)
    shell += lug
    shell.append(box("CharmLugFoot", (0.034, 0.02, 0.016), (0.046, 0.13, 0.039), bevel=0.004, m=M["dark"]))
    rim_top = cup_top + up_n * cup_r
    sight_rear, sight_front = sights_notch(0.0, -0.075, rim_top.y, 0.09, rim_top.z - 0.002, z_line, M, gap=0.016)

    # The mini box in the cup: lid first, along the cup's axis.
    s = 0.058
    body, lid, crank_mini, _lamp, hinge, _hub = jack_box("Mini", s, (blue, M["trim"], yellow, white, M["steel"]))
    box_c = cup_base + axis * 0.0735
    place_box = Matrix.Translation(box_c) @ Matrix.Rotation(-(math.pi / 2 - tilt), 4, "X") @ Matrix.Translation((0, 0, -s * 0.47))
    transform_parts(body + crank_mini + lid, place_box)
    hinge_at = place_box @ Vector(hinge)
    holo = holo_copy(body + lid, "Holo")

    # The launch ring round the cup's foot glows (the energy cell).
    cell = [torus("LaunchRing", cup_r + 0.002, 0.004, tuple(cup_base + axis * 0.012), rot=cup_rot, m=M["cell"], major_segs=40, minor_segs=6),
            box("RearLamp", (0.022, 0.004, 0.01), (0, -0.0915, 0.045), bevel=0.0015, m=M["cell"])]

    # The music-box crank: a hub, an arm and a long knob sticking out to the left.
    hx, hy, hz = crank_hub
    crank = [cyl("CrankHub", 0.011, 0.016, (hx - 0.012, hy, hz), rot=rad(0, 90, 0), segs=16, bevel=0.003, m=M["steel"]),
             obox("CrankArm", (0.006, 0.012, 0.056), (hx - 0.02, hy, hz + 0.022), (1, 0, 0), (0, 1, 0), bevel=0.003, m=M["steel"]),
             cyl("CrankKnobStem", 0.0045, 0.022, (hx - 0.031, hy, hz + CRANK_R), rot=rad(0, 90, 0), segs=10, bevel=0.0, m=M["steel"]),
             cyl("CrankKnob", 0.008, 0.026, (hx - 0.052, hy, hz + CRANK_R), rot=rad(0, 90, 0), segs=14, bevel=0.003, m=M["trim"]),
             sphere("CrankKnobEnd", 0.0095, (hx - 0.066, hy, hz + CRANK_R), m=M["trim"], segs=12, rings=8)]
    # The pinned brass drum.
    dx, dy, dz = drum_c
    drum = [ycyl("DrumCore", 0.0105, 0.07, dy, z=dz, x=dx, m=M["steel"], segs=18, bevel=0.002)]
    for k in range(22):
        a = k * 2.399
        drum.append(sphere(f"DrumPin{k}", 0.0016, (dx + math.cos(a) * 0.0108, dy - 0.03 + (k * 7 % 9) * 0.0075, dz + math.sin(a) * 0.0108),
                           m=M["pink"], segs=6, rings=4))

    bulbs = {}
    for i in range(BULBS):
        at = (-0.026, -0.044 + 0.024 * i, 0.0915)
        bulbs[i] = ([sphere(f"BulbGlow{i}", 0.0052, at, scale=(1, 1, 0.75), m=lamp, segs=10, rings=6)], at)

    decal = [prism("Emblem", star_outline(0.016, 0.007), 0.01, (side + 0.001, 0.0, 0.03), rot=rad(0, 0, 90), m=M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.42, -0.5, -0.36))
    arm_l, elbow_l = cup_hand(G, M, (-0.55, -0.32, -0.32))
    box_pivot = tuple(box_c)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.075, rail_top), None),
        "IronSightFront": (sight_front, tuple(rim_top), None),
        "Box": (body + crank_mini, box_pivot, None),
        "Lid": (lid, tuple(hinge_at), "Box"),
        "CellHolo": (holo, box_pivot, None),
        "Cell": (cell, tuple(cup_base), None),
        "Crank": (crank, crank_hub, None),
        "Drum": (drum, drum_c, None),
        "Trigger": (trig, (0, y_trig, -0.032), None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, grip_loc, None),
    }
    for i, (parts, at) in bulbs.items():
        groups[f"Bulb{i}"] = (parts, at, None)
    empties = {
        "Muzzle": (tuple(cup_top + axis * 0.03), None),
        "SightPoint": ((0, -0.075, z_line), None),
        "SightMount": ((0, 0.005, rail_top), None),
        "EjectPoint": (tuple(cup_top + axis * 0.01), None),
        "VentPoint": ((drum_c[0] - 0.012, drum_c[1], drum_c[2] + 0.02), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("jack_pot", groups, empties)


# ---------------------------------------------------------------------------
# The mine
# ---------------------------------------------------------------------------

def coil(name, radius, wire, height, turns, m, z0=0.0, axis="Z", steps_per_turn=14, origin=(0, 0, 0)):
    """A helical spring from z0 up `height` (or along +Y with axis='Y'), about `origin`."""
    pts = []
    n = int(turns * steps_per_turn)
    for i in range(n + 1):
        t = i / n
        a = t * turns * math.tau
        u, v, w = math.cos(a) * radius, math.sin(a) * radius, z0 + t * height
        p = (u, v, w) if axis == "Z" else (u, w, v)
        pts.append((p[0] + origin[0], p[1] + origin[1], p[2] + origin[2]))
    return tube(name, pts, wire, m=m, segs=8)


def build_jack_pot_box():
    reset_scene()
    s = BOX_SIZE
    blue = mat("JackBlue", "#3270ff", rough=0.35)
    red = mat("JackRed", "#ff3355", rough=0.3)
    yellow = mat("JackYellow", "#ffd23a", rough=0.35)
    white = mat("JackWhite", "#fff8ee", rough=0.4)
    brass = mat("JackBrass", "#e8b04a", rough=0.28, metal=0.7)
    lamp = mat("JackLamp", "#ff6ad5", rough=0.3, emit=2.6)
    steel = mat("JackSteel", "#d8dbe8", rough=0.25, metal=0.8)
    face = mat("ClownFace", "#fffaf2", rough=0.45)
    ink = mat("ClownInk", "#1e1430", rough=0.4)
    cheek = mat("ClownCheek", "#ff8ab8", rough=0.5)
    hair = mat("ClownHair", "#3ddc84", rough=0.6)
    purple = mat("ClownHat", "#8a3bd1", rough=0.4)
    nose = mat("ClownNose", "#ff2244", rough=0.15)
    body, lid, crank, lamp_parts, hinge, hub = jack_box("", s, (blue, red, yellow, white, brass), lamp=lamp, hole=ink)
    h = s * 0.86

    spring_h = s * 0.62
    spring = [coil("SpringCoil", s * 0.2, s * 0.03, spring_h, 6, steel, z0=0.0)]
    # The clown, built with its neck at the origin, facing +Y.
    clown = [sphere("Head", s * 0.36, (0, 0, s * 0.42), m=face, segs=24, rings=14),
             sphere("Nose", s * 0.1, (0, s * 0.34, s * 0.4), m=nose, segs=14, rings=8),
             torus("Smile", s * 0.17, s * 0.025, (0, s * 0.3, s * 0.3), rot=rad(80, 0, 0), m=nose, major_segs=18, minor_segs=6,
                   arc=math.pi * 0.8, start=math.pi * 1.1)]
    for side in (-1, 1):
        clown.append(sphere(f"Eye{side}", s * 0.055, (side * s * 0.12, s * 0.31, s * 0.54), scale=(1, 0.6, 1.3), m=ink, segs=10, rings=6))
        clown.append(sphere(f"Shine{side}", s * 0.018, (side * s * 0.11, s * 0.345, s * 0.57), m=white, segs=6, rings=4))
        clown.append(sphere(f"Cheek{side}", s * 0.07, (side * s * 0.22, s * 0.26, s * 0.36), scale=(1, 0.5, 0.8), m=cheek, segs=10, rings=6))
        for k in range(3):
            clown.append(sphere(f"Hair{side}{k}", s * 0.12, (side * s * (0.33 + 0.03 * (k % 2)), -s * 0.05 + k * s * 0.06, s * (0.5 + 0.1 * k)),
                                m=hair, segs=10, rings=6))
    clown.append(cyl("Hat", s * 0.2, s * 0.4, (0, -s * 0.03, s * 0.92), rot=rad(-12, 0, 8), segs=18, bevel=0.0, m=purple, radius_top=s * 0.02))
    clown.append(torus("HatBand", s * 0.18, s * 0.025, (0, -s * 0.01, s * 0.77), rot=rad(-12, 0, 8), m=yellow, major_segs=20, minor_segs=6))
    clown.append(sphere("Pompom", s * 0.08, (s * 0.025, -s * 0.075, s * 1.12), m=yellow, segs=10, rings=6))
    for k in range(12):
        a = math.tau * k / 12
        clown.append(sphere(f"Ruff{k}", s * 0.11, (math.cos(a) * s * 0.27, math.sin(a) * s * 0.27, s * 0.06), scale=(1, 1, 0.6),
                            m=red if k % 2 else yellow, segs=10, rings=6))
    arm_base = (0, s * 0.22, s * 0.1)
    arm_len = s * 0.3
    arm = [coil("ArmCoil", s * 0.06, s * 0.018, arm_len, 4, steel, z0=0.0, axis="Y", origin=arm_base)]
    glove_at = (0, arm_base[1] + arm_len, arm_base[2])
    glove = [cyl("Cuff", s * 0.1, s * 0.1, (glove_at[0], glove_at[1] + s * 0.04, glove_at[2]), rot=rad(-90, 0, 0), segs=16, bevel=s * 0.02, m=white),
             sphere("Fist", s * 0.17, (glove_at[0], glove_at[1] + s * 0.22, glove_at[2]), scale=(1.0, 1.1, 0.95), m=red, segs=18, rings=10),
             sphere("Thumb", s * 0.07, (glove_at[0] + s * 0.14, glove_at[1] + s * 0.17, glove_at[2] + s * 0.07), scale=(0.9, 1.4, 0.9), m=red, segs=10, rings=6),
             torus("Lace", s * 0.08, s * 0.012, (glove_at[0], glove_at[1] + s * 0.1, glove_at[2] + s * 0.1), rot=rad(0, 0, 0), m=white, major_segs=12, minor_segs=4)]

    floor_z = s * 0.06
    exports = {
        "Box": merge("Box", body, pivot=(0, 0, 0)),
    }
    exports["Lid"] = merge("Lid", lid, pivot=hinge)
    exports["Lamp"] = merge("Lamp", lamp_parts, pivot=(0, 0, h + s * 0.13), parent=exports["Lid"])
    exports["Crank"] = merge("Crank", crank, pivot=hub)
    transform_parts(spring, Matrix.Translation((0, 0, floor_z)))
    exports["Spring"] = merge("Spring", spring, pivot=(0, 0, floor_z))
    transform_parts(clown + arm + glove, Matrix.Translation((0, 0, floor_z + spring_h)))
    exports["Clown"] = merge("Clown", clown, pivot=(0, 0, floor_z + spring_h))
    exports["Arm"] = merge("Arm", arm, pivot=(0, arm_base[1], floor_z + spring_h + arm_base[2]), parent=exports["Clown"])
    exports["Glove"] = merge("Glove", glove, pivot=(0, glove_at[1], floor_z + spring_h + glove_at[2]), parent=exports["Clown"])
    save("jack_pot_box", list(exports.values()))


if __name__ == "__main__":
    build_jack_pot()
    build_jack_pot_box()
