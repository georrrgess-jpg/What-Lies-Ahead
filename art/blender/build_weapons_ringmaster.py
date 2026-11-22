"""The Ringmaster (update 24 primary, the hard unlock: player level 50, 15,000
kills and Endless wave 25): a brass, crimson and gold circus-ringmaster
assault rifle with a three-ring spinning drum magazine ringed with marquee
bulbs, gold filigree scrolls, a tasselled sling and a top-hat flash hider.

art/models/ringmaster.glb, the first-person viewmodel. Same conventions and
node contract as build_weapons.py (documented at the top of weapon_kit.py):
origin at the top of the grip, pointing along +Y, its own palette (set before
weapon_mats, so every finish, cell, decal and charm works). Moving parts,
driven by scripts/weapons/views/ringmaster_view.gd and
scripts/weapons/reloads/ringmaster_reload.gd:

  Drum        the drum magazine under the receiver (pivot on its axle, axis
              X): casing, brass rims, the feed neck; the reload drops it
  RingOuter   the outer ring of the drum's faces (child of Drum, same pivot)
  RingMid     the middle ring (child of Drum)
  RingHub     the hub with its gold star (child of Drum)
  BulbO0..11  the outer ring's marquee bulbs, lit (children of RingOuter)
  BulbM0..7   the middle ring's bulbs, lit (children of RingMid)
  DrumHolo    the reload's hologram drum, on the Drum's pivot
  Handle      the brass charging handle on the left flank (pivot at its
              root; it racks back along -Y)
  Hat         the top-hat flash hider (pivot on the bore at the brim)
  Tassel      the gold tassel on the sling swivel left of the receiver,
              behind the grip (pivot at the swivel; it sways)
  Spot        the little brass spotlight under the barrel's front, its lens
              glowing (it sweeps through the Main Event)
  Cell        the gold glow strips

    python art/blender/build_weapons_ringmaster.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403
from weapon_kit import _finish_part  # noqa: E402

## The drum: axle (y, z), casing radius, half width across X.
DRUM_Y = 0.162
DRUM_Z = -0.08
DRUM_R = 0.06
DRUM_HALF = 0.03
## The three rings on each face: (inner, outer) radius.
RING_OUTER = (0.043, 0.0565)
RING_MID = (0.027, 0.04)
RING_HUB = (0.0, 0.024)
BULBS_OUTER = 12
BULBS_MID = 8
BORE_Z = 0.034
RAIL_TOP = 0.098
HANDGUARD_TOP = 0.072
## The charging handle's root on the left flank.
HANDLE = (-0.04, 0.085, 0.05)
## The sling's swivel (left of the receiver, behind the grip) and the top hat's brim.
SWIVEL = (-0.036, -0.14, 0.0)
HAT_Y = 0.43


def palette():
    """Crimson body, gold trim, brass steel, burgundy-black dark, cream accents."""
    mat("Shell", "#b0142f", rough=0.3)
    mat("Trim", "#e9b43c", rough=0.28, metal=0.55)
    mat("GunDark", "#2a0d18", rough=0.45, metal=0.2)
    mat("GunSteel", "#d8a446", rough=0.24, metal=0.8)
    mat("GunPink", "#f8ecd2", rough=0.4)


def annulus(name, r0, r1, half, centre, m, segs=48):
    """A flat ring (or disc when r0 is 0) round the X axis through `centre`
    (y, z), 2 * half wide across X."""
    bm = bmesh.new()
    cy, cz = centre
    rows = []
    for i in range(segs):
        a = math.tau * i / segs
        c, s = math.cos(a), math.sin(a)
        row = []
        for r in (r0, r1):
            for x in (-half, half):
                row.append(bm.verts.new((x, cy + c * max(r, 0.0005), cz + s * max(r, 0.0005))))
        rows.append(row)
    # row = [inner-left, inner-right, outer-left, outer-right]
    quads = [(2, 3), (0, 2), (1, 0), (3, 1)] if r0 > 0 else [(2, 3)]
    for i in range(segs):
        a, b = rows[i], rows[(i + 1) % segs]
        for p, q in quads:
            bm.faces.new((a[p], a[q], b[q], b[p]))
    if r0 <= 0:
        bm.faces.new([row[2] for row in rows])
        bm.faces.new([row[3] for row in reversed(rows)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish_part(name, bm, m)
    return add_bevel(ob, 0.0015, 1)


def scroll(name, x, centre, r0, turns, m, start=0.0, flip=1, radius=0.0016, tail=None):
    """A gold filigree scroll on the flank plane x = `x`: an opening spiral
    round `centre` (y, z) from radius r0 outwards over `turns`, ending in a
    trailing stem towards `tail` (y, z)."""
    cy, cz = centre
    pts = []
    steps = int(18 * turns) + 2
    for i in range(steps):
        t = i / (steps - 1)
        a = start + flip * math.tau * turns * t
        r = r0 * (0.25 + 0.75 * t)
        pts.append((x, cy + math.cos(a) * r, cz + math.sin(a) * r))
    if tail:
        last = Vector(pts[-1])
        end = Vector((x, tail[0], tail[1]))
        for k in range(1, 5):
            p = last.lerp(end, k / 4)
            pts.append((x, p.y, p.z + math.sin(k / 4 * math.pi) * 0.004))
    return tube(name, pts, radius, m=m, segs=6, radius_end=radius * 0.6)


def flank_scrolls(prefix, x, m):
    """The receiver's filigree on one flank: two facing scrolls and a vine between them."""
    side = 1 if x > 0 else -1
    return [
        scroll(prefix + "A", x, (-0.088, 0.032), 0.016, 1.6, m, start=0.5, flip=side, tail=(-0.05, 0.05)),
        scroll(prefix + "B", x, (0.07, 0.024), 0.013, 1.5, m, start=2.6, flip=-side, tail=(0.036, 0.05)),
        tube(prefix + "Vine", [(x, -0.05, 0.05), (x, -0.02, 0.058), (x, 0.0, 0.052), (x, 0.02, 0.058), (x, 0.036, 0.05)], 0.0014,
             m=m, segs=6),
    ]


def build_ringmaster():
    reset_scene()
    palette()
    M = weapon_mats("#ffd45a", emit=2.4)
    gold = M["trim"]
    brass = M["steel"]
    cream = M["pink"]
    bulb_lit = mat("MarqueeLit", "#fff0b0", rough=0.25, emit=5.0)
    bulb_dim = mat("MarqueeDim", "#8a6a3a", rough=0.35, metal=0.3)
    velvet = mat("Velvet", "#5a0a1c", rough=0.85)
    hat_black = mat("HatSilk", "#141018", rough=0.32, metal=0.1)
    grip_loc = (0, -0.036, -0.11)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.066, 0.088, 0.182), body_bottom=-0.012)
    fore = (0, 0.335, -0.052)
    dy, dz = DRUM_Y, DRUM_Z
    z_line = RAIL_TOP + SIGHT_HEIGHT

    shell = grip_parts + [
        # Crimson receiver with a gold seam, a brass deck and a dark belly.
        loft("Body", [(-0.15, 0.031, 0.034, 0.03, 0.013), (-0.118, 0.036, 0.042, 0.032, 0.016), (0.13, 0.036, 0.042, 0.032, 0.016),
                      (0.168, 0.032, 0.036, 0.034, 0.014)], M["shell"]),
        box("Seam", (0.0745, 0.27, 0.005), (0, 0.0, 0.012), bevel=0.0015, m=gold),
        box("Deck", (0.06, 0.25, 0.008), (0, -0.005, 0.077), bevel=0.003, m=brass),
        box("Belly", (0.062, 0.2, 0.014), (0, 0.02, -0.008), bevel=0.005, m=M["dark"]),
        box("RailRiser", (0.03, 0.2, 0.014), (0, -0.01, RAIL_TOP - 0.016), bevel=0.003, m=M["dark"]),
        # The magazine well: a brass collar the drum's neck seats in.
        box("MagWell", (0.05, 0.05, 0.02), (0, dy, -0.018), bevel=0.005, m=brass),
        box("MagWellLip", (0.054, 0.054, 0.005), (0, dy, -0.027), bevel=0.002, m=gold),
        # The handguard: crimson, ringed with gold bands, brass vents with star cut-outs.
        loft("Handguard", [(0.165, 0.03, 0.036, 0.036, 0.014), (0.2, 0.031, 0.037, 0.036, 0.015), (0.345, 0.029, 0.035, 0.036, 0.014),
                           (0.365, 0.025, 0.03, 0.036, 0.012)], M["shell"]),
        ring("GuardBand0", 0.0345, 0.0035, 0.2, z=0.036, m=gold, segs=28),
        ring("GuardBand1", 0.0335, 0.0035, 0.338, z=0.036, m=gold, segs=28),
        # The barrel out of the handguard, a brass collar and the top hat.
        ycyl("Barrel", 0.0125, 0.08, 0.39, z=BORE_Z, m=M["dark"], segs=18),
        ring("BarrelCollar", 0.0145, 0.004, 0.372, z=BORE_Z, m=brass, segs=18),
        # Vertical foregrip: a gold-capped cane handle.
        box("ForegripMount", (0.04, 0.05, 0.026), (0, fore[1], -0.002), bevel=0.007, m=M["dark"]),
        cyl("Foregrip", 0.019, 0.1, fore, segs=20, bevel=0.006, m=M["dark"]),
        torus("ForegripBand", 0.0195, 0.003, (0, fore[1], fore[2] + 0.034), m=gold, major_segs=20, minor_segs=5),
        sphere("ForegripKnob", 0.022, (0, fore[1], fore[2] - 0.056), scale=(1, 1, 0.7), m=gold, segs=16, rings=10),
        # The stock: crimson, a gold comb, a brass butt plate with a velvet pad.
        loft("Stock", [(-0.15, 0.028, 0.032, 0.03, 0.012), (-0.2, 0.026, 0.036, 0.018, 0.012), (-0.28, 0.027, 0.052, 0.002, 0.014)],
             M["shell"]),
        box("StockComb", (0.034, 0.12, 0.008), (0, -0.215, 0.054), rot=rad(-9, 0, 0), bevel=0.003, m=gold),
        box("ButtPlate", (0.06, 0.012, 0.11), (0, -0.285, 0.002), bevel=0.005, m=brass),
        box("ButtPad", (0.052, 0.01, 0.098), (0, -0.294, 0.002), bevel=0.004, m=velvet),
        # The rear sling swivel under the stock.
        torus("RearSwivel", 0.008, 0.0022, (0, -0.24, -0.042), rot=rad(0, 90, 0), m=brass, major_segs=14, minor_segs=5),
    ]
    # Star vents along both flanks of the handguard.
    for sx in (1, -1):
        for i in range(3):
            y = 0.23 + i * 0.03
            shell.append(prism(f"Vent{sx}{i}", star_outline(0.0085, 0.0038), 0.004, (sx * 0.03, y, 0.04), rot=rad(0, 0, 90), m=M["dark"]))
        shell += flank_scrolls(f"Scroll{sx}", sx * 0.0372, gold)
        # Gold piping down the stock's flanks.
        shell.append(scroll(f"StockScroll{sx}", sx * 0.0272, (-0.245, 0.012), 0.014, 1.4, gold, start=1.0, flip=sx, tail=(-0.17, 0.03)))
    # The top rail and the built-in sights: a gold aperture ring at the rear, a
    # post between guard ears on the handguard's nose.
    shell += top_rail("TopRail", -0.105, 0.055, RAIL_TOP, M, width=0.028)
    sight_rear, sight_front = sights_ghost_ring(0.0, -0.11, 0.31, RAIL_TOP, HANDGUARD_TOP, z_line, M, radius=0.016)
    shell += bolts("Pin", [(-0.037, -0.11, 0.0), (0.037, 0.11, 0.0), (-0.037, 0.11, 0.0)], brass, radius=0.0045, height=0.004)
    # The charm lug on the stock's left flank near the butt, on a foot out of the stock.
    lug, charm_point = charm_lug(-0.031, -0.275, 0.03, M, out=-1.0)
    shell += lug
    shell.append(box("CharmLugFoot", (0.01, 0.022, 0.016), (-0.028, -0.275, 0.034), bevel=0.003, m=M["dark"]))

    # The drum: crimson casing between brass rims, a feed neck up into the well.
    drum = [
        annulus("DrumCase", DRUM_R - 0.003, DRUM_R + 0.003, DRUM_HALF - 0.002, (dy, dz), M["shell"], segs=56),
        annulus("DrumBack", 0.0, DRUM_R - 0.002, DRUM_HALF - 0.004, (dy, dz), M["dark"], segs=48),
        box("DrumNeck", (0.05, 0.036, 0.04), (0, dy, dz + DRUM_R + 0.008), bevel=0.006, m=brass),
        box("DrumNeckBand", (0.054, 0.04, 0.006), (0, dy, dz + DRUM_R - 0.002), bevel=0.002, m=gold),
        box("DrumLatch", (0.014, 0.012, 0.02), (-0.03, dy + 0.026, dz + DRUM_R + 0.004), bevel=0.003, m=gold),
        xcyl("DrumAxle", 0.008, DRUM_HALF * 2 + 0.012, (0, dy, dz), m=brass, segs=14),
    ]
    for sx in (1, -1):
        drum.append(torus(f"DrumRim{sx}", DRUM_R + 0.001, 0.0042, (sx * DRUM_HALF, dy, dz), rot=rad(0, 90, 0), m=brass,
                          major_segs=56, minor_segs=7))
    # Rivets round the casing.
    for k in range(10):
        a = math.tau * k / 10 + 0.3
        drum.append(xcyl(f"CaseRivet{k}", 0.0032, DRUM_HALF * 2 - 0.006, (0, dy + math.cos(a) * (DRUM_R + 0.0035), dz + math.sin(a) * (DRUM_R + 0.0035)),
                         m=gold, segs=8))

    def ring_face(prefix, r0, r1, base_m, stripe_m, stripes):
        """One ring band through the drum (both faces), with radial stripes on each face."""
        parts = [annulus(prefix + "Band", r0, r1, DRUM_HALF + 0.001, (dy, dz), base_m)]
        rm = (r0 + r1) / 2
        for sx in (1, -1):
            for k in range(stripes):
                a = math.tau * (k + 0.5) / stripes
                parts.append(obox(f"{prefix}Stripe{sx}{k}", (0.0018, r1 - r0 - 0.003, 0.0045),
                                  (sx * (DRUM_HALF + 0.0016), dy + math.cos(a) * rm, dz + math.sin(a) * rm), (1, 0, 0),
                                  (0, math.cos(a), math.sin(a)), bevel=0.0006, m=stripe_m))
        return parts

    ring_outer = ring_face("RingO", RING_OUTER[0], RING_OUTER[1], M["shell"], gold, BULBS_OUTER)
    ring_mid = ring_face("RingM", RING_MID[0], RING_MID[1], gold, M["shell"], BULBS_MID)
    ring_hub = [annulus("HubDisc", 0.0, RING_HUB[1], DRUM_HALF + 0.001, (dy, dz), cream)]
    for sx in (1, -1):
        ring_hub.append(prism(f"HubStar{sx}", star_outline(0.019, 0.0085), 0.003, (sx * (DRUM_HALF + 0.002), dy, dz),
                              rot=rad(0, 0, 90), m=gold))
        ring_hub.append(xcyl(f"HubCap{sx}", 0.0055, 0.004, (sx * (DRUM_HALF + 0.004), dy, dz), m=M["shell"], segs=12))
        ring_hub.append(torus(f"HubRim{sx}", RING_HUB[1], 0.0018, (sx * (DRUM_HALF + 0.001), dy, dz), rot=rad(0, 90, 0), m=brass,
                              major_segs=36, minor_segs=5))

    def bulbs(prefix, count, radius, ring_parts, phase):
        """Sockets in the ring (static to it) and one lit-bulb node per angle (both faces)."""
        lit = {}
        for k in range(count):
            a = math.tau * k / count + phase
            y, z = dy + math.cos(a) * radius, dz + math.sin(a) * radius
            nodes = []
            for sx in (1, -1):
                ring_parts.append(xcyl(f"{prefix}Seat{sx}{k}", 0.0043, 0.003, (sx * (DRUM_HALF + 0.0018), y, z), m=brass, segs=10))
                ring_parts.append(sphere(f"{prefix}Dim{sx}{k}", 0.0031, (sx * (DRUM_HALF + 0.0033), y, z), m=bulb_dim, segs=8, rings=5))
                nodes.append(sphere(f"{prefix}Lit{sx}{k}", 0.0036, (sx * (DRUM_HALF + 0.0036), y, z), m=bulb_lit, segs=10, rings=6))
            lit[f"{prefix}{k}"] = (nodes, (0.0, y, z))
        return lit

    lit_outer = bulbs("BulbO", BULBS_OUTER, (RING_OUTER[0] + RING_OUTER[1]) / 2, ring_outer, 0.0)
    lit_mid = bulbs("BulbM", BULBS_MID, (RING_MID[0] + RING_MID[1]) / 2, ring_mid, math.pi / BULBS_MID)
    holo = holo_copy(drum + ring_outer + ring_mid + ring_hub)

    # The charging handle: a brass rod out of the left flank with a cane-top ball.
    hx, hy, hz = HANDLE
    shell.append(box("HandleSlot", (0.004, 0.07, 0.01), (-0.0365, hy - 0.02, hz), bevel=0.0015, m=M["dark"]))
    handle = [xcyl("HandleRod", 0.0042, 0.022, (hx - 0.006, hy, hz), m=brass, segs=10),
              sphere("HandleBall", 0.0085, (hx - 0.02, hy, hz), m=gold, segs=14, rings=8),
              torus("HandleCollar", 0.0055, 0.0018, (hx + 0.002, hy, hz), rot=rad(0, 90, 0), m=gold, major_segs=12, minor_segs=4)]

    # The top hat: brim at the barrel's end, a silk crown with a crimson band and gold buckle, flash slots.
    crown_len = 0.07
    hat = [
        ycyl("HatBrim", 0.042, 0.006, HAT_Y + 0.003, z=BORE_Z, m=hat_black, segs=36, bevel=0.002),
        ycyl("HatCrown", 0.027, crown_len, HAT_Y + 0.006 + crown_len / 2, z=BORE_Z, m=hat_black, segs=32, bevel=0.003, radius_top=0.029),
        ring("HatBand", 0.0275, 0.0045, HAT_Y + 0.016, z=BORE_Z, m=M["shell"], segs=32),
        box("HatBuckle", (0.012, 0.006, 0.012), (0, HAT_Y + 0.016, BORE_Z + 0.03), bevel=0.002, m=gold),
        ycyl("HatThroat", 0.016, 0.004, HAT_Y + 0.006 + crown_len, z=BORE_Z, m=M["dark"], segs=20, bevel=0.0),
        ring("HatLip", 0.0275, 0.0025, HAT_Y + 0.004 + crown_len, z=BORE_Z, m=gold, segs=32),
    ]
    for k in range(6):
        a = math.tau * k / 6 + math.pi / 6
        hat.append(obox(f"HatSlot{k}", (0.004, 0.032, 0.006), (math.cos(a) * 0.0285, HAT_Y + 0.05, BORE_Z + math.sin(a) * 0.0285),
                        (0, 1, 0), (math.cos(a), 0, math.sin(a)), bevel=0.001, m=M["dark"]))

    # The sling: a gold cord loop from the front swivel, and its tassel.
    sx_, sy_, sz_ = SWIVEL
    shell.append(box("SwivelMount", (0.006, 0.016, 0.012), (sx_ + 0.004, sy_, sz_ + 0.006), bevel=0.002, m=brass))
    tassel = [torus("SwivelRing", 0.0075, 0.0021, (sx_ - 0.002, sy_, sz_ - 0.004), rot=rad(0, 90, 0), m=brass, major_segs=14, minor_segs=5),
              tube("TasselCord", [(sx_ - 0.002, sy_, sz_ - 0.011), (sx_ - 0.004, sy_ - 0.004, sz_ - 0.024), (sx_ - 0.004, sy_ - 0.006, sz_ - 0.034)],
                   0.0022, m=gold, segs=6),
              sphere("TasselKnot", 0.0062, (sx_ - 0.004, sy_ - 0.006, sz_ - 0.038), m=gold, segs=12, rings=8),
              cyl("TasselCap", 0.0058, 0.008, (sx_ - 0.004, sy_ - 0.006, sz_ - 0.046), segs=12, bevel=0.0015, m=M["shell"])]
    for k in range(10):
        a = math.tau * k / 10
        tassel.append(tube(f"TasselStrand{k}", [(sx_ - 0.004 + math.cos(a) * 0.004, sy_ - 0.006 + math.sin(a) * 0.004, sz_ - 0.049),
                                                (sx_ - 0.004 + math.cos(a) * 0.0065, sy_ - 0.006 + math.sin(a) * 0.0065, sz_ - 0.072)],
                           0.0012, m=gold, segs=4, radius_end=0.0008))

    # The spotlight under the barrel's front: a brass can with a glowing lens.
    spot_at = (0.0, 0.395, 0.0)
    spot = [ycyl("SpotCan", 0.011, 0.026, spot_at[1], z=spot_at[2], m=brass, segs=18, bevel=0.002),
            ring("SpotRim", 0.011, 0.0022, spot_at[1] + 0.013, z=spot_at[2], m=gold, segs=18),
            box("SpotYoke", (0.014, 0.012, 0.016), (0, spot_at[1] - 0.004, spot_at[2] + 0.016), bevel=0.003, m=M["dark"]),
            ycyl("SpotLens", 0.0088, 0.003, spot_at[1] + 0.0135, z=spot_at[2], m=M["cell"], segs=18, bevel=0.0)]
    cell = [box("CellStripL", (0.004, 0.11, 0.006), (-0.0368, 0.0, 0.0), bevel=0.001, m=M["cell"]),
            box("CellStripR", (0.004, 0.11, 0.006), (0.0368, 0.0, 0.0), bevel=0.001, m=M["cell"])]

    emblem = star_outline(0.016, 0.007)
    decal = [side_emblem("Emblem", emblem, -0.0315, -0.18, 0.016, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = vertical_hand(fore, 0.019, 0.019, 0.1, M, (-0.3, -0.1, -0.62))
    drum_c = (0, dy, dz)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "Cell": (cell, (0, 0.0, 0.0), None),
        "IronSightRear": (sight_rear, (0, -0.11, RAIL_TOP), None),
        "IronSightFront": (sight_front, (0, 0.31, HANDGUARD_TOP), None),
        "Drum": (drum, drum_c, None),
        "RingOuter": (ring_outer, drum_c, "Drum"),
        "RingMid": (ring_mid, drum_c, "Drum"),
        "RingHub": (ring_hub, drum_c, "Drum"),
        "DrumHolo": (holo, drum_c, None),
        "Handle": (handle, HANDLE, None),
        "Hat": (hat, (0, HAT_Y, BORE_Z), None),
        "Tassel": (tassel, SWIVEL, None),
        "Spot": (spot, spot_at, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    for name, (parts, at) in lit_outer.items():
        groups[name] = (parts, at, "RingOuter")
    for name, (parts, at) in lit_mid.items():
        groups[name] = (parts, at, "RingMid")
    empties = {
        "Muzzle": ((0, HAT_Y + 0.08, BORE_Z), None),
        "SightPoint": ((0, -0.11, z_line), None),
        "SightMount": ((0, -0.025, RAIL_TOP), None),
        "EjectPoint": ((0.04, 0.03, 0.05), None),
        "VentPoint": ((0.03, 0.26, 0.04), None),
        "SpotPoint": ((0, spot_at[1] + 0.016, spot_at[2]), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("ringmaster", groups, empties)


if __name__ == "__main__":
    build_ringmaster()
