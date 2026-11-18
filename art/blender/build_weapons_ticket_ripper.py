"""First-person viewmodel of the Ticket Ripper (ticket_ripper), the level-12
SMG primary: a compact cherry-red arcade prize-ticket gun with a gold
ticket-dispenser drum riding on its back under a purple carry bridge, a
ribbon of tickets spooling out of its left flank and a ticket-punch shroud.

Same conventions and node contract as build_weapons.py (documented at the top
of weapon_kit.py): origin at the top of the grip, pointing along +Y, its own
palette (set before weapon_mats, so the shared material names stay and every
finish, cell, decal and charm works), built-in sights on the bridge so the
drum stays under the eye line. Moving parts, driven by
scripts/weapons/views/ticket_ripper_view.gd and
scripts/weapons/reloads/ticket_ripper_reload.gd:

  Roll        the roll of tickets in the drum (pivot on the drum's axle,
              axis X): it turns as it feeds and its radius shrinks with the
              magazine; the reload throws the spent spool out
  RollHolo    its hologram copy, printed in by the reload
  Rib0..3     the ribbon of tickets hanging out of the feed slot, a chain
              (each the child of the one before, pivot at its top edge);
              Rib3 is the leading ticket the operator tears off
  DrumDoor    the drum's left plate with the counter, hinged at its front
              edge (pivot on the hinge, axis Z): it swings out for the reload
  Pip0..14    the streak lights round the counter (children of DrumDoor)
  Cell        the gold glow strips (energy), CellHolo unused

Empties: Muzzle, EjectPoint (the feed slot), VentPoint, CounterPoint (the
counter face, where the view draws the streak figure), SightPoint,
SightMount, CharmPoint, ElbowR/L.

    python art/blender/build_weapons_ticket_ripper.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403
from weapon_kit import _finish_part  # noqa: E402

PIPS = 15
## The drum: axle (y, z), plate radius, half width across X.
DRUM_Y = -0.008
DRUM_Z = 0.124
DRUM_R = 0.05
DRUM_HALF = 0.033
ROLL_R = 0.043
ROLL_HALF = 0.026
BORE_Z = 0.034
RAIL_TOP = 0.196
## The feed slot on the left flank and the ribbon's tickets.
SLOT = (-0.04, 0.052, 0.062)
TICKET_LEN = 0.04
TICKET_W = 0.032
RIB_ANGLES = [4.0, 30.0, 62.0, 84.0]
RIB_TWISTS = [10.0, 35.0, 62.0, 80.0]


def palette():
    """The shared weapon materials in this weapon's colours (weapon_mats reuses them)."""
    mat("Shell", "#ef2b45", rough=0.32)
    mat("Trim", "#6c3be0", rough=0.36)
    mat("GunDark", "#2a2238", rough=0.55, metal=0.15)
    mat("GunSteel", "#f7c04a", rough=0.3, metal=0.5)
    mat("GunPink", "#ff6fa8", rough=0.36)


def drum_shell(name, centre, radius, thick, half, a0, a1, m, segs=28):
    """A curved band round the X axis through `centre` (angles in degrees,
    0 = +Y forward, 90 = up), `thick` deep and 2 * half wide."""
    bm = bmesh.new()
    cy, cz = centre
    rows = []
    for i in range(segs + 1):
        a = math.radians(a0 + (a1 - a0) * i / segs)
        c, s = math.cos(a), math.sin(a)
        row = []
        for r in (radius, radius + thick):
            for x in (-half, half):
                row.append(bm.verts.new((x, cy + c * r, cz + s * r)))
        rows.append(row)
    # row = [inner-left, inner-right, outer-left, outer-right]
    quads = [(0, 1), (1, 3), (3, 2), (2, 0)]
    for i in range(segs):
        r0, r1 = rows[i], rows[i + 1]
        for a, b in quads:
            bm.faces.new((r0[a], r0[b], r1[b], r1[a]))
    bm.faces.new((rows[0][0], rows[0][2], rows[0][3], rows[0][1]))
    bm.faces.new((rows[-1][0], rows[-1][1], rows[-1][3], rows[-1][2]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish_part(name, bm, m)
    return add_bevel(ob, 0.003, 2)


def ticket(prefix, top, angle, twist, M, card_m, band_m, lead=False):
    """One ticket of the ribbon hanging from `top` (its top edge centre),
    leaning `angle` degrees down from straight out to the left and twisted
    `twist` degrees about its length, so the lower tickets turn their faces
    to the player."""
    a = math.radians(angle)
    d = Vector((-math.cos(a), 0.0, -math.sin(a)))
    n = Vector((-math.sin(a), 0.0, math.cos(a)))
    tw = math.radians(twist)
    w = Vector((0.0, 1.0, 0.0)) * math.cos(tw) + n * math.sin(tw)
    t = Vector(top)
    centre = t + d * (TICKET_LEN / 2)
    parts = [obox(prefix + "Card", (TICKET_LEN - 0.002, TICKET_W, 0.0024), centre, d, w, bevel=0.0008, m=card_m)]
    # A cream band across the card and a dark punch hole.
    parts.append(obox(prefix + "Band", (0.007, TICKET_W + 0.0004, 0.003), centre + d * (TICKET_LEN * 0.22), d, w, bevel=0.0006, m=band_m))
    parts.append(obox(prefix + "Hole", (0.006, 0.006, 0.0032), centre - d * (TICKET_LEN * 0.2), d, w, bevel=0.0, m=M["dark"]))
    if lead:
        # The leading ticket's torn, zig-zag bottom edge.
        for i in range(4):
            off = -TICKET_W / 2 + TICKET_W * (i + 0.5) / 4
            parts.append(obox(f"{prefix}Tooth{i}", (0.0045, 0.0045, 0.0024), t + d * (TICKET_LEN - 0.001) + w * off, d, w, bevel=0.0, m=card_m))
    return parts, tuple(t + d * (TICKET_LEN + 0.0015))


def bridge_post(prefix, y, M):
    """A purple post holding the sight bridge up beside the drum, with a gold band."""
    z0 = 0.074
    z1 = RAIL_TOP - 0.024
    h = z1 - z0
    return [
        box(prefix + "Body", (0.03, 0.02, h), (0, y, z0 + h / 2), bevel=0.006, m=M["trim"]),
        box(prefix + "Band", (0.034, 0.024, 0.008), (0, y, z0 + h * 0.3), bevel=0.003, m=M["steel"]),
        sphere(prefix + "Rivet", 0.0045, (-0.016, y, z0 + h * 0.72), m=M["cell"], segs=8, rings=5),
    ]


def build_ticket_ripper():
    reset_scene()
    palette()
    M = weapon_mats("#ffd23f", emit=2.2)
    ticket_m = mat("Ticket", "#fff1cf", rough=0.55)
    card_m = mat("TicketCard", "#ff7aa8", rough=0.5)
    stripe_m = mat("TicketStripe", "#ff4f7b", rough=0.5)
    face_m = mat("CounterFace", "#1a1030", rough=0.25, emit=0.35, emit_color="#3a1050")
    pip_m = mat("PipLit", "#ffd23f", rough=0.3, emit=3.0)
    grip_loc = (0, -0.04, -0.108)
    grip_parts, G = grip("", grip_loc, M, tilt=-12, size=(0.064, 0.086, 0.178), body_bottom=-0.012)
    fore = (0, 0.19, -0.056)
    dy, dz = DRUM_Y, DRUM_Z

    shell = grip_parts + [
        # Short, chunky cherry receiver with a purple belly and a gold seam.
        loft("Body", [(-0.118, 0.034, 0.036, 0.034, 0.016), (-0.07, 0.039, 0.044, 0.034, 0.02), (0.11, 0.039, 0.044, 0.034, 0.02),
                      (0.15, 0.034, 0.036, 0.036, 0.016)], M["shell"]),
        box("Belly", (0.07, 0.22, 0.018), (0, 0.02, -0.006), bevel=0.007, m=M["trim"]),
        box("Seam", (0.081, 0.2, 0.006), (0, 0.02, 0.05), bevel=0.002, m=M["steel"]),
        box("TopDeck", (0.066, 0.2, 0.008), (0, 0.01, 0.076), bevel=0.003, m=M["dark"]),
        # The drum: gold side plates on a dark axle, a red hood round its back and bottom.
        xcyl("DrumPlateR", DRUM_R + 0.003, 0.006, (DRUM_HALF, dy, dz), m=M["steel"], segs=36),
        xcyl("DrumAxle", 0.012, DRUM_HALF * 2 + 0.014, (0, dy, dz), m=M["dark"], segs=16),
        drum_shell("DrumHood", (dy, dz), DRUM_R - 0.003, 0.006, DRUM_HALF - 0.003, 150.0, 395.0, M["shell"]),
        drum_shell("DrumStrap", (dy, dz), DRUM_R + 0.002, 0.004, 0.006, 60.0, 150.0, M["trim"], segs=10),
        # Its stand: the drum sits in a purple cradle on the deck.
        box("Cradle", (0.06, 0.08, 0.026), (0, dy, 0.083), bevel=0.008, m=M["trim"]),
        # Feed slot on the left flank (the ribbon comes out of it), with a pink lip.
        box("SlotLip", (0.008, 0.04, 0.014), (SLOT[0] + 0.002, SLOT[1], SLOT[2] + 0.002), bevel=0.003, m=M["pink"]),
        box("SlotMouth", (0.004, 0.034, 0.005), (SLOT[0] - 0.002, SLOT[1], SLOT[2] + 0.001), bevel=0.001, m=M["dark"]),
        # Short barrel in a gold ticket-punch shroud, a purple slotted muzzle box.
        ycyl("Barrel", 0.015, 0.11, 0.2, z=BORE_Z, m=M["dark"], segs=16),
        ycyl("Shroud", 0.026, 0.1, 0.19, z=BORE_Z, m=M["steel"], segs=20),
        ring("ShroudBand0", 0.027, 0.0035, 0.143, z=BORE_Z, m=M["trim"], segs=20),
        ring("ShroudBand1", 0.027, 0.0035, 0.237, z=BORE_Z, m=M["trim"], segs=20),
        box("MuzzleBox", (0.05, 0.04, 0.044), (0, 0.262, BORE_Z), bevel=0.009, m=M["trim"]),
        box("MuzzleSlotT", (0.036, 0.042, 0.006), (0, 0.262, BORE_Z + 0.012), bevel=0.001, m=M["dark"]),
        box("MuzzleSlotB", (0.036, 0.042, 0.006), (0, 0.262, BORE_Z - 0.012), bevel=0.001, m=M["dark"]),
        ycyl("MuzzleBore", 0.011, 0.006, 0.282, z=BORE_Z, m=mat("Bore", "#3a1020", rough=0.9), segs=14, bevel=0.0),
        ring("MuzzleGlow", 0.014, 0.0025, 0.283, z=BORE_Z, m=M["cell"], segs=16),
        # Stubby vertical foregrip with a pink cap.
        box("ForegripMount", (0.044, 0.05, 0.03), (0, fore[1], -0.006), bevel=0.008, m=M["dark"]),
        box("Foregrip", (0.04, 0.046, 0.1), fore, bevel=0.018, m=M["dark"]),
        sphere("ForegripKnob", 0.019, (0, fore[1], fore[2] - 0.056), scale=(1, 1, 0.55), m=M["pink"], segs=14, rings=8),
        # A short rear cap (no stock: it is an SMG) with a purple ticket-tray lip.
        box("RearCap", (0.086, 0.07, 0.074), (0, -0.14, 0.034), bevel=0.012, m=M["trim"]),
        box("RearLip", (0.084, 0.012, 0.012), (0, -0.172, 0.064), bevel=0.004, m=M["pink"]),
        box("RearStripe", (0.084, 0.071, 0.008), (0, -0.14, 0.012), bevel=0.002, m=M["steel"]),
        # The sight bridge over the drum.
        box("BridgeBeam", (0.028, 0.2, 0.012), (0, dy, RAIL_TOP - 0.018), bevel=0.004, m=M["trim"]),
    ]
    shell += bridge_post("PostRear", dy - 0.078, M)
    shell += bridge_post("PostFront", dy + 0.078, M)
    shell += top_rail("TopRail", dy - 0.085, dy + 0.09, RAIL_TOP, M, width=0.028)
    # The drum's left plate is a door hinged at its front edge: the counter on
    # it (a dark face under a pink bezel) and the streak sockets round it.
    door = [
        xcyl("DrumPlateL", DRUM_R + 0.003, 0.006, (-DRUM_HALF, dy, dz), m=M["steel"], segs=36),
        xcyl("CounterFace", 0.026, 0.004, (-DRUM_HALF - 0.004, dy, dz), m=face_m, segs=28),
        torus("CounterBezel", 0.027, 0.0026, (-DRUM_HALF - 0.005, dy, dz), rot=rad(0, 90, 0), m=M["pink"], major_segs=28, minor_segs=5),
        # Its inside face: a purple disc with a gold star, seen when the door swings open.
        xcyl("DoorInner", DRUM_R - 0.004, 0.002, (-DRUM_HALF + 0.002, dy, dz), m=M["trim"], segs=32),
        star("DoorStar", 0.018, 0.002, (-DRUM_HALF + 0.003, dy, dz), rot=rad(0, 0, 90), m=M["steel"], inner=0.008),
        box("DoorLatch", (0.008, 0.012, 0.016), (-DRUM_HALF - 0.003, dy - DRUM_R + 0.004, dz), bevel=0.003, m=M["trim"]),
    ]
    door += [xcyl(f"DoorHinge{i}", 0.0045, 0.006, (-DRUM_HALF - 0.001, dy + DRUM_R + 0.002, dz + z), m=M["dark"], segs=10)
             for i, z in enumerate((-0.03, 0.03))]
    pip_at = []
    for i in range(PIPS):
        a = math.radians(225.0 - 270.0 * i / (PIPS - 1))
        c = (-DRUM_HALF - 0.0045, dy + math.cos(a) * 0.0405, dz + math.sin(a) * 0.0405)
        pip_at.append(c)
        door.append(xcyl(f"PipSeat{i}", 0.0048, 0.003, (c[0] + 0.001, c[1], c[2]), m=M["dark"], segs=10))
    # Ticket-punch holes down the shroud's left and top.
    for i in range(4):
        y = 0.155 + i * 0.022
        shell.append(xcyl(f"PunchL{i}", 0.0055, 0.006, (-0.024, y, BORE_Z), m=M["dark"], segs=10))
        shell.append(cyl(f"PunchT{i}", 0.0055, 0.006, (0, y, BORE_Z + 0.024), segs=10, bevel=0.0, m=M["dark"]))
    # Gold glow strips (Cell) along the flanks, and a glowing ticket window on the drum strap.
    cell = [box("CellStripL", (0.004, 0.1, 0.008), (-0.0395, -0.03, 0.018), bevel=0.001, m=M["cell"]),
            box("CellStripR", (0.004, 0.1, 0.008), (0.0395, -0.03, 0.018), bevel=0.001, m=M["cell"])]
    shell += vent_slots("Vent", 0.039, 0.06, 0.11, 0.022, 3, M["dark"], M["cell"], height=0.026, side=1)
    shell += bolts("Pin", [(-0.04, -0.075, 0.04), (0.04, 0.09, 0.012), (-0.04, 0.12, 0.012)], M["steel"], radius=0.005, height=0.005)
    lug, charm_point = charm_lug(-0.043, -0.166, 0.03, M)
    shell += lug
    sight_rear, sight_front = sights_notch(0.0, dy - 0.075, dy + 0.08, RAIL_TOP, RAIL_TOP, RAIL_TOP + SIGHT_HEIGHT, M, gap=0.016)

    # The roll: cream tickets wound on a dark core, pink edges, notches that show it turning.
    roll = [xcyl("RollBody", ROLL_R, ROLL_HALF * 2, (0, dy, dz), m=ticket_m, segs=32)]
    for side in (-1, 1):
        roll.append(torus(f"RollEdge{side}", ROLL_R - 0.0015, 0.0022, (side * (ROLL_HALF - 0.001), dy, dz), rot=rad(0, 90, 0), m=stripe_m,
                          major_segs=32, minor_segs=5))
        for k in range(6):
            a = math.tau * k / 6
            roll.append(box(f"RollMark{side}{k}", (0.003, 0.012, 0.004), (side * (ROLL_HALF + 0.0005), dy + math.cos(a) * 0.028, dz + math.sin(a) * 0.028),
                            rot=(a, 0, 0), bevel=0.0, m=stripe_m))
    roll.append(xcyl("RollCore", 0.0145, ROLL_HALF * 2 + 0.002, (0, dy, dz), m=M["steel"], segs=16))
    roll_holo = holo_copy(roll)

    # The ribbon: four tickets hanging from the slot, each hinged on the one before.
    ribs = []
    top = (SLOT[0] - 0.003, SLOT[1], SLOT[2])
    for i, (ang, tw) in enumerate(zip(RIB_ANGLES, RIB_TWISTS)):
        parts, end = ticket(f"Rib{i}", top, ang, tw, M, card_m, ticket_m, lead=(i == len(RIB_ANGLES) - 1))
        ribs.append((parts, top))
        top = end

    pips = {f"Pip{i}": ([xcyl(f"Pip{i}Lamp", 0.0042, 0.004, (c[0] - 0.0015, c[1], c[2]), m=pip_m, segs=10)], c) for i, c in enumerate(pip_at)}

    emblem = [(-0.016, -0.009), (0.016, -0.009), (0.016, -0.003), (0.012, 0.0), (0.016, 0.003), (0.016, 0.009),
              (-0.016, 0.009), (-0.016, 0.003), (-0.012, 0.0), (-0.016, -0.003)]
    decal = [side_emblem("Emblem", emblem, -0.041, 0.0, 0.03, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = vertical_hand(fore, 0.021, 0.024, 0.1, M, (-0.52, -0.16, -0.46))
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "Cell": (cell, (0, -0.03, 0.018), None),
        "IronSightRear": (sight_rear, (0, dy - 0.075, RAIL_TOP), None),
        "IronSightFront": (sight_front, (0, dy + 0.08, RAIL_TOP), None),
        "DrumDoor": (door, (-DRUM_HALF, dy + DRUM_R + 0.003, dz), None),
        "Roll": (roll, (0, dy, dz), None),
        "RollHolo": (roll_holo, (0, dy, dz), None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    for i, (parts, pivot) in enumerate(ribs):
        groups[f"Rib{i}"] = (parts, pivot, f"Rib{i - 1}" if i > 0 else None)
    for name, (parts, centre) in pips.items():
        groups[name] = (parts, centre, "DrumDoor")
    empties = {
        "Muzzle": ((0, 0.288, BORE_Z), None),
        "SightPoint": ((0, dy - 0.075, RAIL_TOP + SIGHT_HEIGHT), None),
        "SightMount": ((0, dy, RAIL_TOP), None),
        "EjectPoint": ((SLOT[0] - 0.006, SLOT[1], SLOT[2]), None),
        "VentPoint": ((0.03, 0.19, BORE_Z), None),
        "CounterPoint": ((-DRUM_HALF - 0.0075, dy, dz), "DrumDoor"),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("ticket_ripper", groups, empties)


if __name__ == "__main__":
    build_ticket_ripper()
