"""Pirate Cove landmarks and buildings (World 13, Skull Harbor).

    cove_swing.glb       the Kraken Swing: a pirate-ship swinging ride. Two
                         A-frames 8.2 m tall with a kraken's tentacles curling
                         up them, a loading deck and the name board (Base);
                         Boat is the swinging gondola, pivot on the axle
                         (z 8.2), swinging about X (its length along Y).
    cove_lighthouse.glb  a sandstone lighthouse with teal bands on a rock,
                         its keeper's cottage, a gallery and the lantern room;
                         Beam is the pair of light cones (the level spins it).
    cove_tavern.glb      the Rusty Anchor: a two-storey timber tavern, 10 x 7 m,
                         with a veranda, lit windows, the hanging anchor sign.
    cove_hut.glb         a stilt hut: an 8 x 7 m plank platform (top z 0) on
                         stilts, a plank hut (4.2 x 3.6 m, centred 1.3 m back)
                         with a thatched roof, a net, a lantern.
    cove_cave.glb        the sea cave's mouth: a rocky arch round a dark vault
                         10 m deep (front at y 0, opening 6 m wide, 5 m high).
    cove_tunnel.glb      the smugglers' tunnel: a timber-framed mine mouth with
                         its sign and lanterns, a dark vault 8 m deep.
    cove_warehouse.glb   the bonded warehouse: 11 x 9 m, open double doors on
                         the front (4.4 m wide), a dark interior with crates.

    python art/blender/build_cove_landmarks.py [swing] [lighthouse] [tavern] [hut] [cave] [tunnel] [warehouse]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cove_common import *  # noqa: F401,F403
from cove_common import _finish, bmesh, Vector  # noqa: F401

AXLE_Z = 8.2
HUT_BODY_Y = 1.3     # the hut on its 8 x 7 m deck, back of centre (+Y)


def tentacle(name, base, radius, height, turns, r0=0.35, phase=0.0, m=None):
    pts = []
    n = 28
    for i in range(n + 1):
        t = i / n
        a = phase + math.tau * turns * t
        rr = radius * (1.0 + 0.25 * t)
        pts.append((base[0] + math.cos(a) * rr, base[1] + math.sin(a) * rr, base[2] + height * t))
    # Curl the tip outward.
    end = Vector(pts[-1])
    for k in range(1, 5):
        a = phase + math.tau * turns + k * 0.5
        pts.append((end.x + math.cos(a) * 0.25 * k, end.y + math.sin(a) * 0.25 * k, end.z + 0.15 * k))
    return tube(name, pts, r0, m=m or mat("CoveKraken", "#8a4fb0", rough=0.5), segs=10, radius_end=0.05)


def build_swing():
    reset_scene()
    teal, gold, red, wood = cmat("Teal", rough=0.45), cmat("Gold", rough=0.35), cmat("Red", rough=0.5), cmat("Wood")
    bulb_m = cglow("CoveBulb", "#ffd38a", 3.0)
    base = []
    for s in (-1, 1):
        x = s * 2.3
        for e in (-1, 1):
            base.append(tube(f"Leg{s}{e}", [(x, e * 4.6, 0.3), (x, 0, AXLE_Z)], 0.24, m=teal, segs=10))
            base.append(cyl(f"Foot{s}{e}", 0.45, 0.3, (x, e * 4.6, 0.15), segs=10, bevel=0.05, m=gold))
            for k in range(1, 6):
                t = k / 6
                base.append(bulb(f"LegBulb{s}{e}{k}", 0.08, (x + s * 0.25, e * 4.6 * (1 - t), 0.3 + (AXLE_Z - 0.3) * t), bulb_m))
        base.append(box(f"Brace{s}", (0.2, 6.0, 0.24), (x, 0, 2.6), bevel=0.04, m=teal))
        base.append(cyl(f"Hub{s}", 0.55, 0.5, (x, 0, AXLE_Z), rot=rad(0, 90, 0), segs=14, bevel=0.06, m=gold))
    base.append(cyl("Axle", 0.22, 4.6, (0, 0, AXLE_Z), rot=rad(0, 90, 0), segs=10, bevel=0.0, m=cmat("Iron")))
    base += [box("LoadDeck", (5.6, 3.2, 0.3), (0, 0, 0.15), bevel=0.05, m=cmat("Plank")),
             box("LoadDeckTrim", (5.7, 3.3, 0.08), (0, 0, 0.28), bevel=0.02, m=red)]
    km = mat("CoveKraken", "#8a4fb0", rough=0.5)
    base += [tentacle("TentacleA", (2.3, -4.0, 0.2), 0.55, 6.2, 1.6, phase=0.4, m=km),
             tentacle("TentacleB", (-2.3, 4.0, 0.2), 0.55, 5.4, 1.4, phase=2.5, m=km),
             tentacle("TentacleC", (2.3, 4.0, 0.2), 0.5, 3.6, 1.0, r0=0.28, phase=4.0, m=km)]
    for k, (x, y, r) in enumerate(((2.9, -4.4, 0.9), (-2.8, 4.5, 0.9), (2.8, 4.4, 0.7))):
        base.append(sphere(f"KrakenBump{k}", r, (x, y, 0.1), scale=(1, 1, 0.45), m=km, segs=12, rings=6))
    # Name board on the south side of the deck.
    base += [box("Board", (3.6, 0.14, 0.8), (0, -1.9, 1.1), bevel=0.05, m=cmat("Navy")),
             box("BoardTrim", (3.8, 0.1, 0.95), (0, -1.86, 1.1), bevel=0.04, m=gold),
             box("BoardPostL", (0.16, 0.16, 1.4), (-1.6, -1.8, 0.7), bevel=0.03, m=cmat("WoodDark")),
             box("BoardPostR", (0.16, 0.16, 1.4), (1.6, -1.8, 0.7), bevel=0.03, m=cmat("WoodDark")),
             text("BoardText", "KRAKEN SWING", 0.42, 0.05, (0, -1.98, 1.08), m=gold)]
    base_ob = merge("Base", base)
    # The swinging boat (pivot on the axle).
    boat = []
    hull_l, hull_w, z0, z1 = 4.4, 1.3, 1.0, 2.5
    prof = []
    for i in range(13):
        t = i / 12
        y = -hull_l + 2 * hull_l * t
        w = hull_w * math.sin(math.pi * (0.06 + 0.88 * t)) ** 0.5
        prof.append((y, w))
    bm = bmesh.new()
    rows = []
    for y, w in prof:
        rise = 0.6 * (abs(y) / hull_l) ** 2
        rows.append([bm.verts.new((-w, y, z1 + rise)), bm.verts.new((-w * 0.75, y, z0 + rise * 0.6)), bm.verts.new((w * 0.75, y, z0 + rise * 0.6)),
                     bm.verts.new((w, y, z1 + rise))])
    for i in range(len(rows) - 1):
        for k in range(3):
            f = bm.faces.new((rows[i][k], rows[i + 1][k], rows[i + 1][k + 1], rows[i][k + 1]))
            f.material_index = 0 if k != 1 else 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    shell = finish_multi("BoatHull", bm, [red, cmat("WoodDark")], smooth=False)
    double_sided(shell)
    boat.append(shell)
    for i in range(len(prof) - 1):
        y = (prof[i][0] + prof[i + 1][0]) * 0.5
        rise = 0.6 * (abs(y) / hull_l) ** 2
        if 1 <= i <= 10 and i % 2 == 1:
            boat.append(box(f"Bench{i}", (prof[i][1] * 1.5, 0.4, 0.12), (0, y, z0 + rise * 0.6 + 0.6), bevel=0.03, m=cmat("Plank")))
    boat.append(tube("Gunwale", [(prof[k][1] * s, prof[k][0], z1 + 0.6 * (abs(prof[k][0]) / hull_l) ** 2 + 0.05) for s in (1,) for k in range(13)], 0.07,
                     m=gold, segs=6))
    boat.append(tube("GunwaleL", [(-prof[k][1], prof[k][0], z1 + 0.6 * (abs(prof[k][0]) / hull_l) ** 2 + 0.05) for k in range(13)], 0.07, m=gold, segs=6))
    for s in (-1, 1):
        for e in (-1, 1):
            boat.append(tube(f"Arm{s}{e}", [(s * 1.75, 0, AXLE_Z), (s * 1.0, e * 2.6, z1 + 0.1)], 0.12, m=gold, segs=8))
    # Stripy sail on a short mast amidships, a skull at the prow and a lamp at the stern.
    boat.append(cyl("BoatMast", 0.1, 3.4, (0, 0.6, z1 + 1.5), segs=8, bevel=0.0, m=cmat("WoodLight")))
    boat.append(sail("BoatSail", 2.2, 1.9, (0, 0.45, z1 + 3.1), billow=0.3, stripes=3))
    boat.append(sphere("ProwSkull", 0.42, (0, -hull_l - 0.1, z1 + 0.9), scale=(1, 0.9, 0.92), m=cmat("Bone", rough=0.5), segs=12, rings=8))
    for s in (-1, 1):
        boat.append(sphere(f"ProwEye{s}", 0.1, (s * 0.15, -hull_l - 0.45, z1 + 0.95), m=cglow("CoveSkullEye", "#ffb83a", 4.0), segs=6, rings=4))
    boat += lantern("SternLamp", (0, hull_l - 0.1, z1 + 0.65), scale=1.3)
    boat_ob = merge("Boat", boat, pivot=(0, 0, AXLE_Z))
    save("cove_swing", [base_ob, boat_ob])


def build_lighthouse():
    reset_scene()
    stone, band, red = cmat("Stone", rough=0.8), cmat("TealDark", rough=0.6), cmat("Red", rough=0.5)
    p = [rock_lump("Rock", (13.0, 11.0, 3.2), seed=4)]
    prof = [(3.3, 3.0), (3.0, 10.0), (2.6, 17.0), (2.5, 19.0)]
    p.append(lathe("Tower", prof, [stone], segs=20, smooth=False))
    for k, z in enumerate((6.0, 12.0)):
        r = 3.3 - 0.7 * (z - 3.0) / 16
        p.append(lathe(f"Band{k}", [(r + 0.05, z), (r - 0.02, z + 1.2)], [band], segs=20, smooth=False, cap_top=False, cap_bottom=False))
    p += [cyl("Gallery", 3.4, 0.35, (0, 0, 19.2), segs=20, bevel=0.06, m=cmat("WoodDark")),
          torus("GalleryRail", 3.3, 0.06, (0, 0, 20.2), m=cmat("Iron"), major_segs=24, minor_segs=4)]
    for k in range(16):
        a = math.tau * k / 16
        p.append(cyl(f"Rail{k}", 0.04, 0.9, (math.cos(a) * 3.3, math.sin(a) * 3.3, 19.8), segs=4, bevel=0.0, m=cmat("Iron")))
    p += [cyl("LampRoom", 1.7, 2.6, (0, 0, 20.7), segs=12, bevel=0.0, m=cglow("CoveLighthouseGlass", "#fff0b8", 3.5)),
          cyl("LampRoof", 2.1, 1.6, (0, 0, 22.8), segs=12, bevel=0.05, m=red, radius_top=0.2),
          sphere("Finial", 0.3, (0, 0, 23.8), m=cmat("Gold", rough=0.35), segs=8, rings=5)]
    for k in range(6):
        a = math.tau * k / 6
        p.append(box(f"Mullion{k}", (0.12, 0.12, 2.6), (math.cos(a) * 1.72, math.sin(a) * 1.72, 20.7), rot=(0, 0, a), bevel=0.0, m=cmat("Iron")))
    for k, z in enumerate((7.5, 13.5)):
        p.append(box(f"Window{k}", (0.6, 0.2, 1.0), (0, -3.25 + 0.04 * (z - 3), z), bevel=0.04, m=cglow("CoveWindowGlow", "#ffc77a", 1.6)))
    p += [box("Door", (1.2, 0.25, 2.0), (0, -3.3, 4.0), bevel=0.04, m=red)]
    # The keeper's cottage beside it.
    p += [box("Cottage", (4.2, 3.4, 2.6), (4.4, 1.6, 4.3), bevel=0.06, m=cmat("Cream", rough=0.8)),
          prism("CottageRoof", [(-2.4, 0), (2.4, 0), (0, 1.6)], 3.8, (4.4, 1.6, 5.6), m=red, bevel=0.05),
          box("CottageDoor", (0.9, 0.1, 1.7), (4.4, -0.12, 3.85), bevel=0.03, m=cmat("WoodDark")),
          box("CottageWin", (0.8, 0.1, 0.6), (5.8, -0.12, 4.6), bevel=0.02, m=cglow("CoveWindowGlow", "#ffc77a", 1.6)),
          box("Chimney", (0.5, 0.5, 1.2), (5.6, 2.4, 6.9), bevel=0.04, m=cmat("StoneDark"))]
    tower = merge("Lighthouse", p)
    beam = []
    for s in (-1, 1):
        beam.append(cyl(f"Cone{s}", 0.8, 34.0, (0, s * 17.5, 20.7), rot=rad(90, 0, 0), segs=12, bevel=0.0, m=mat("CoveBeam", "#fff2c0", emit=2.0),
                        radius_top=4.5 if s < 0 else 0.8))
    beam_ob = merge("Beam", beam, pivot=(0, 0, 20.7))
    save("cove_lighthouse", [tower, beam_ob])


def build_tavern():
    reset_scene()
    W, D = 10.0, 7.0
    wood, dark, cream, red = cmat("Wood", rough=0.8), cmat("WoodDark", rough=0.8), cmat("Cream", rough=0.8), cmat("RedDark", rough=0.6)
    glow = cglow("CoveWindowGlow", "#ffc77a", 1.6)
    p = [box("Plinth", (W + 0.4, D + 0.4, 0.4), (0, 0, 0.2), bevel=0.05, m=cmat("StoneDark"))]
    p += planks("Ground", (W, D, 3.2), (0, 0, 2.0), m_a=wood, m_b=dark, along="y", count=24)
    p += [box("Upper", (W + 0.3, D + 0.3, 3.0), (0, 0, 5.1), bevel=0.06, m=cream),
          box("Floorbeam", (W + 0.5, D + 0.5, 0.3), (0, 0, 3.6), bevel=0.05, m=dark)]
    # Timber framing on the upper storey (front and back).
    for y in (-(D + 0.3) / 2 - 0.03, (D + 0.3) / 2 + 0.03):
        for k in range(6):
            x = -W / 2 + W * k / 5
            p.append(box(f"Post{y > 0}{k}", (0.25, 0.08, 3.0), (x, y, 5.1), bevel=0.02, m=dark))
        for k in range(5):
            x = -W / 2 + W * (k + 0.5) / 5
            p.append(box(f"Brace{y > 0}{k}", (0.18, 0.08, 2.4), (x, y, 5.1), rot=(0, 0.75 if k % 2 else -0.75, 0), bevel=0.02, m=dark))
    for x in (-(W + 0.3) / 2 - 0.03, (W + 0.3) / 2 + 0.03):
        for k in range(4):
            y = -D / 2 + D * k / 3
            p.append(box(f"SidePost{x > 0}{k}", (0.08, 0.25, 3.0), (x, y, 5.1), bevel=0.02, m=dark))
    # Roof: a steep gable along X with red shingles and a chimney.
    p += [prism("Roof", [(-D / 2 - 0.9, 0), (D / 2 + 0.9, 0), (0, 3.4)], W + 1.2, (0, 0, 6.6), rot=(0, 0, math.pi / 2), m=red, bevel=0.06),
          box("RidgeCap", (W + 1.3, 0.4, 0.3), (0, 0, 10.0), bevel=0.06, m=dark),
          box("Chimney", (0.9, 0.9, 3.0), (W / 2 - 1.4, 1.2, 9.6), bevel=0.05, m=cmat("StoneDark")),
          box("ChimneyCap", (1.1, 1.1, 0.2), (W / 2 - 1.4, 1.2, 11.1), bevel=0.04, m=dark)]
    for g in (-1, 1):
        p.append(prism(f"Gable{g}", [(-D / 2 - 0.15, 0), (D / 2 + 0.15, 0), (0, 3.2)], 0.2, (g * (W / 2 + 0.1), 0, 6.6), rot=(0, 0, math.pi / 2), m=cream))
        p.append(box(f"GableWin{g}", (0.12, 1.0, 0.8), (g * (W / 2 + 0.22), 0, 7.6), bevel=0.03, m=glow))
    # Front (-Y): door, windows, veranda roof on posts, sign.
    fy = -D / 2 - 0.05
    p += [box("Door", (1.6, 0.14, 2.4), (0, fy - 0.02, 1.6), bevel=0.04, m=red),
          box("DoorFrame", (2.0, 0.1, 2.7), (0, fy + 0.02, 1.75), bevel=0.03, m=dark),
          sphere("DoorKnob", 0.07, (0.55, fy - 0.12, 1.55), m=cmat("Brass", rough=0.3, metal=0.5), segs=6, rings=4)]
    for k, x in enumerate((-3.4, -1.9, 1.9, 3.4)):
        p += [box(f"Win{k}", (1.0, 0.1, 1.0), (x, fy - 0.02, 2.0), bevel=0.03, m=glow),
              box(f"WinFrame{k}", (1.2, 0.08, 1.2), (x, fy + 0.01, 2.0), bevel=0.03, m=dark)]
    for k, x in enumerate((-3.5, -1.2, 1.2, 3.5)):
        p += [box(f"UpWin{k}", (1.0, 0.1, 1.1), (x, -(D + 0.3) / 2 - 0.06, 5.2), bevel=0.03, m=glow),
              box(f"Shutter{k}a", (0.45, 0.08, 1.15), (x - 0.75, -(D + 0.3) / 2 - 0.08, 5.2), bevel=0.02, m=cmat("Teal", rough=0.6)),
              box(f"Shutter{k}b", (0.45, 0.08, 1.15), (x + 0.75, -(D + 0.3) / 2 - 0.08, 5.2), bevel=0.02, m=cmat("Teal", rough=0.6))]
    vd = 2.6
    p += [box("VerandaRoof", (W + 0.6, vd + 0.4, 0.2), (0, fy - vd / 2, 3.5), rot=(-0.12, 0, 0), bevel=0.05, m=red),
          box("VerandaBeam", (W + 0.4, 0.25, 0.25), (0, fy - vd, 3.2), bevel=0.04, m=dark)]
    for k in range(5):
        x = -W / 2 + 0.2 + (W - 0.4) * k / 4
        p.append(box(f"VerandaPost{k}", (0.24, 0.24, 2.9), (x, fy - vd, 1.75), bevel=0.04, m=dark))
    p += planks("VerandaFloor", (W + 0.4, vd, 0.16), (0, fy - vd / 2, 0.08), along="y", count=26)
    # The hanging sign: an anchor on a board.
    sx, sy = W / 2 - 0.2, fy - vd - 0.2
    p += [box("SignArm", (1.6, 0.1, 0.1), (sx + 0.6, sy, 3.0), bevel=0.02, m=cmat("Iron")),
          box("SignBoard", (1.3, 0.1, 1.0), (sx + 0.9, sy, 2.25), bevel=0.04, m=cmat("Navy")),
          box("SignTrim", (1.42, 0.08, 1.12), (sx + 0.9, sy + 0.02, 2.25), bevel=0.03, m=cmat("Gold", rough=0.35)),
          torus("SignAnchor", 0.28, 0.05, (sx + 0.9, sy - 0.08, 2.1), rot=(math.pi / 2, 0, 0), m=cmat("Rock", rough=0.5), major_segs=12, minor_segs=4,
                arc=math.pi, start=math.pi),
          box("SignShank", (0.07, 0.06, 0.6), (sx + 0.9, sy - 0.08, 2.3), bevel=0.0, m=cmat("Rock", rough=0.5))]
    p += [box("NameBoard", (5.0, 0.14, 0.7), (0, fy - 0.12, 3.95), bevel=0.04, m=cmat("Navy")),
          text("NameText", "THE RUSTY ANCHOR", 0.42, 0.05, (0, fy - 0.22, 3.93), m=cmat("Gold", rough=0.3))]
    p += lantern("LampL", (-W / 2 + 0.6, fy - vd + 0.1, 2.75), scale=1.4) + lantern("LampR", (W / 2 - 0.6, fy - vd + 0.1, 2.75), scale=1.4)
    save("cove_tavern", [merge("Tavern", p)])


def build_hut():
    reset_scene()
    wood, dark, thatch = cmat("Wood", rough=0.8), cmat("WoodDark", rough=0.8), cmat("Thatch", rough=0.9)
    p = planks("Deck", (8.0, 7.0, 0.25), (0, 0, -0.125), along="y", count=23)
    p += [box("DeckBeamF", (8.2, 0.3, 0.35), (0, -3.5, -0.3), bevel=0.04, m=dark), box("DeckBeamB", (8.2, 0.3, 0.35), (0, 3.5, -0.3), bevel=0.04, m=dark)]
    for x in (-3.8, 0.0, 3.8):
        for y in (-3.3, 3.3):
            p.append(cyl(f"Stilt{x}{y}", 0.2, 4.2, (x, y, -2.2), segs=8, bevel=0.0, m=dark))
    # The hut sits on the back of the deck; the front strip is the walkway.
    by = HUT_BODY_Y
    p += planks("Walls", (4.2, 3.6, 2.6), (0, by, 1.3), m_a=wood, m_b=cmat("WoodLight", rough=0.8), along="y", count=12)
    fy = by - 1.85
    p += [box("Door", (1.0, 0.1, 1.9), (0, fy, 0.95), bevel=0.03, m=cmat("Teal", rough=0.6)),
          box("DoorFrame", (1.3, 0.08, 2.1), (0, fy + 0.03, 1.05), bevel=0.02, m=dark),
          cyl("RoundWin", 0.35, 0.1, (-1.4, fy + 0.01, 1.6), rot=rad(90, 0, 0), segs=12, bevel=0.0, m=cglow("CoveWindowGlow", "#ffc77a", 1.6)),
          torus("RoundWinRim", 0.36, 0.06, (-1.4, fy - 0.01, 1.6), rot=rad(90, 0, 0), m=cmat("Brass", rough=0.35, metal=0.4), major_segs=12, minor_segs=4)]
    roof = lathe("Roof", [(3.4, 2.5), (2.6, 3.2), (0.15, 4.9)], [thatch, cmat("ThatchDark", rough=0.9)], segs=4, stripes=None, smooth=False)
    roof.location = (0, by, 0)
    roof.rotation_euler = (0, 0, math.pi / 4)
    p.append(roof)
    p.append(cyl("RoofTip", 0.12, 0.8, (0, by, 5.2), segs=6, bevel=0.0, m=dark))
    p += skull_flag("Flag", (0.55, by, 5.4), width=0.9, height=0.55, yaw=0.0)
    # A fishing net slung on poles along the back corner, a lantern, a coil of rope.
    p += [cyl("NetPoleA", 0.06, 2.2, (3.4, 0.4, 1.1), segs=6, bevel=0.0, m=dark), cyl("NetPoleB", 0.06, 2.2, (3.4, 3.1, 1.1), segs=6, bevel=0.0, m=dark)]
    p.append(rope("NetTop", sag_points((3.4, 0.4, 2.1), (3.4, 3.1, 2.1), 0.4), 0.03))
    for k in range(4):
        y = 0.7 + k * 0.7
        t = (y - 0.4) / 2.7
        p.append(rope(f"NetDrop{k}", [(3.4, y, 2.1 - 0.4 * 4 * t * (1 - t)), (3.4, y, 0.6)], 0.015, segs=3))
    p += lantern("Lamp", (-2.6, fy + 0.2, 2.1), scale=1.2)
    p.append(cyl("LampPost", 0.05, 2.1, (-2.6, fy + 0.2, 1.05), segs=6, bevel=0.0, m=dark))
    p.append(torus("Coil", 0.35, 0.09, (-3.3, 3.0, 0.1), m=cmat("Rope", rough=0.9), major_segs=14, minor_segs=5))
    save("cove_hut", [merge("Hut", p)])


def build_cave():
    reset_scene()
    dark = mat("CoveCaveDark", "#1d1a24", rough=1.0)
    p = []
    # A dark vault: floor-level box shell open at the front (-Y).
    p += [box("VaultBack", (8.0, 0.6, 7.0), (0, 10.0, 3.0), bevel=0.0, m=dark),
          box("VaultL", (0.6, 10.0, 7.0), (-3.4, 5.0, 3.0), bevel=0.0, m=dark),
          box("VaultR", (0.6, 10.0, 7.0), (3.4, 5.0, 3.0), bevel=0.0, m=dark),
          box("VaultTop", (8.0, 10.0, 0.6), (0, 5.0, 6.0), bevel=0.0, m=dark)]
    # Rocky frame: lumps round the arch.
    rng = random.Random(9)
    for k in range(9):
        a = math.pi * k / 8
        x, z = math.cos(a) * 4.2, max(0.0, math.sin(a) * 5.4)
        r = rng.uniform(1.6, 2.4)
        ob = rock_lump(f"Frame{k}", (r * 1.6, r * 1.4, r * 1.5), seed=20 + k, top_grass=False)
        ob.location = (x * 1.15, -0.2, z - r * 0.4)
        ob.rotation_euler = (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(0, 3))
        p.append(ob)
    # Stalactite teeth along the lip and a lantern hung inside.
    for k in range(6):
        x = -2.4 + k * 0.95
        p.append(cyl(f"Drip{k}", 0.28, 0.9, (x, 0.4, 5.1 + rng.uniform(-0.2, 0.2)), rot=(math.pi, 0, 0), segs=6, bevel=0.0, m=cmat("RockDark", rough=0.9),
                     radius_top=0.02))
    p += lantern("Lamp", (2.2, 1.5, 3.2), scale=1.4)
    p.append(rope("LampRope", [(2.2, 1.5, 3.8), (2.2, 1.5, 5.7)], 0.03))
    save("cove_cave", [merge("Cave", p)])


def build_tunnel():
    reset_scene()
    dark = mat("CoveCaveDark", "#1d1a24", rough=1.0)
    timber = cmat("WoodDark", rough=0.8)
    p = [box("VaultBack", (6.0, 0.6, 5.0), (0, 8.0, 2.3), bevel=0.0, m=dark),
         box("VaultL", (0.6, 8.0, 5.0), (-2.6, 4.0, 2.3), bevel=0.0, m=dark),
         box("VaultR", (0.6, 8.0, 5.0), (2.6, 4.0, 2.3), bevel=0.0, m=dark),
         box("VaultTop", (6.0, 8.0, 0.6), (0, 4.0, 4.6), bevel=0.0, m=dark)]
    for k, y in enumerate((-0.2, 2.6, 5.2)):
        p += [box(f"PostL{k}", (0.45, 0.45, 4.3), (-2.1, y, 2.15), bevel=0.05, m=timber),
              box(f"PostR{k}", (0.45, 0.45, 4.3), (2.1, y, 2.15), bevel=0.05, m=timber),
              box(f"Lintel{k}", (5.0, 0.5, 0.5), (0, y, 4.3), bevel=0.05, m=timber)]
    p += [box("Sign", (4.0, 0.15, 0.7), (0, -0.5, 4.95), bevel=0.04, m=cmat("Wood")),
          text("SignText", "SMUGGLERS' WAY", 0.38, 0.05, (0, -0.6, 4.93), m=cmat("Cream")),
          box("RailL", (0.12, 9.0, 0.1), (-0.6, 3.8, 0.05), bevel=0.0, m=cmat("Iron")),
          box("RailR", (0.12, 9.0, 0.1), (0.6, 3.8, 0.05), bevel=0.0, m=cmat("Iron"))]
    for k in range(9):
        p.append(box(f"Sleeper{k}", (1.7, 0.25, 0.08), (0, -0.4 + k * 1.0, 0.03), bevel=0.0, m=timber))
    p += lantern("LampL", (-2.1, -0.5, 3.2), scale=1.3) + lantern("LampR", (2.1, -0.5, 3.2), scale=1.3)
    # A mine cart of loot just inside.
    p += [box("Cart", (1.5, 1.1, 0.8), (0, 7.0, 0.7), bevel=0.06, m=cmat("Iron")),
          sphere("Loot", 0.6, (0, 7.0, 1.05), scale=(1.1, 0.8, 0.5), m=mat("CoveGoldGlow", "#ffc24a", rough=0.3, emit=0.8), segs=10, rings=5)]
    save("cove_tunnel", [merge("Tunnel", p)])


def build_warehouse():
    reset_scene()
    W, D, H = 11.0, 9.0, 6.0
    stone, dark, red = cmat("Stone", rough=0.85), cmat("WoodDark", rough=0.8), cmat("RedDark", rough=0.6)
    inside = mat("CoveCaveDark", "#1d1a24", rough=1.0)
    door_w, door_h = 4.4, 4.2
    p = [box("Back", (W, 0.5, H), (0, D / 2, H / 2), bevel=0.05, m=stone),
         box("SideL", (0.5, D, H), (-W / 2, 0, H / 2), bevel=0.05, m=stone),
         box("SideR", (0.5, D, H), (W / 2, 0, H / 2), bevel=0.05, m=stone),
         box("FrontL", ((W - door_w) / 2, 0.5, H), (-(W + door_w) / 4, -D / 2, H / 2), bevel=0.05, m=stone),
         box("FrontR", ((W - door_w) / 2, 0.5, H), ((W + door_w) / 4, -D / 2, H / 2), bevel=0.05, m=stone),
         box("FrontTop", (door_w, 0.5, H - door_h), (0, -D / 2, (H + door_h) / 2), bevel=0.05, m=stone),
         box("Inner", (W - 1.2, D - 1.2, H - 0.6), (0, 0.2, (H - 0.6) / 2 + 0.01), bevel=0.0, m=inside)]
    # The inner box is seen from inside only: flip it.
    inner = p[-1]
    me = inner.data
    for poly in me.polygons:
        poly.flip()
    p += [prism("Roof", [(-D / 2 - 0.6, 0), (D / 2 + 0.6, 0), (0, 2.6)], W + 0.8, (0, 0, H), rot=(0, 0, math.pi / 2), m=red, bevel=0.06)]
    for g in (-1, 1):
        p.append(prism(f"Gable{g}", [(-D / 2, 0), (D / 2, 0), (0, 2.4)], 0.3, (g * W / 2, 0, H), rot=(0, 0, math.pi / 2), m=stone))
    # Doors swung open against the front wall, frame, sign, lamps.
    for s in (-1, 1):
        p.append(box(f"Door{s}", (door_w / 2, 0.14, door_h - 0.1), (s * (door_w / 2 + door_w / 4 + 0.1), -D / 2 - 0.35, door_h / 2), bevel=0.04,
                     m=cmat("Teal", rough=0.6)))
        p.append(box(f"DoorBrace{s}", (door_w / 2 - 0.2, 0.06, 0.25), (s * (door_w / 2 + door_w / 4 + 0.1), -D / 2 - 0.44, door_h / 2), rot=(0, s * 0.8, 0),
                     bevel=0.0, m=dark))
    p += [box("DoorHead", (door_w + 0.5, 0.6, 0.45), (0, -D / 2 - 0.1, door_h + 0.1), bevel=0.05, m=dark),
          box("Sign", (6.0, 0.15, 0.8), (0, -D / 2 - 0.35, door_h + 1.0), bevel=0.04, m=cmat("Navy")),
          text("SignText", "BONDED WAREHOUSE", 0.46, 0.05, (0, -D / 2 - 0.45, door_h + 0.98), m=cmat("Gold", rough=0.3))]
    p += lantern("LampL", (-door_w / 2 - 0.6, -D / 2 - 0.4, 3.2), scale=1.4) + lantern("LampR", (door_w / 2 + 0.6, -D / 2 - 0.4, 3.2), scale=1.4)
    # Corner quoins, shuttered windows along the sides and back, a ridge cap
    # and the loading hoist over the doors.
    for sx in (-1, 1):
        for sy in (-1, 1):
            for k in range(5):
                p.append(box(f"Quoin{sx}{sy}{k}", (0.6 if k % 2 else 0.45, 0.6 if k % 2 == 0 else 0.45, 0.5), (sx * W / 2, sy * D / 2, 0.5 + k * 1.15),
                             bevel=0.04, m=cmat("StoneDark", rough=0.85)))
    glow = cglow("CoveWindowGlow", "#ffc77a", 1.6)
    for k, y in enumerate((-2.2, 2.2)):
        for sx in (-1, 1):
            x = sx * (W / 2 + 0.05)
            p += [box(f"SideWin{k}{sx}", (0.1, 1.0, 1.3), (x, y, 3.4), bevel=0.02, m=glow),
                  box(f"SideFrame{k}{sx}", (0.12, 1.2, 1.5), (x - sx * 0.02, y, 3.4), bevel=0.02, m=dark),
                  box(f"SideShutA{k}{sx}", (0.08, 0.5, 1.4), (x + sx * 0.04, y - 0.85, 3.4), bevel=0.02, m=cmat("Teal", rough=0.6)),
                  box(f"SideShutB{k}{sx}", (0.08, 0.5, 1.4), (x + sx * 0.04, y + 0.85, 3.4), bevel=0.02, m=cmat("Teal", rough=0.6))]
    for k, x in enumerate((-3.0, 0.0, 3.0)):
        p += [box(f"BackWin{k}", (1.0, 0.1, 1.3), (x, D / 2 + 0.05, 3.4), bevel=0.02, m=glow),
              box(f"BackFrame{k}", (1.2, 0.12, 1.5), (x, D / 2 + 0.03, 3.4), bevel=0.02, m=dark)]
    p += [box("Ridge", (W + 1.0, 0.45, 0.3), (0, 0, H + 2.6), bevel=0.06, m=dark),
          box("HoistBeam", (0.35, 2.2, 0.35), (0, -D / 2 - 0.9, H + 0.9), bevel=0.04, m=dark),
          box("HoistBrace", (0.2, 1.4, 0.2), (0, -D / 2 - 0.4, H + 0.35), rot=(0.7, 0, 0), bevel=0.02, m=dark),
          cyl("HoistPulley", 0.2, 0.12, (0, -D / 2 - 1.8, H + 0.62), rot=rad(0, 90, 0), segs=10, bevel=0.0, m=cmat("Iron")),
          rope("HoistRope", [(0, -D / 2 - 1.95, H + 0.55), (0, -D / 2 - 1.95, H - 1.3)], 0.03),
          torus("HoistHook", 0.14, 0.035, (0, -D / 2 - 1.95, H - 1.45), rot=rad(90, 0, 90), m=cmat("Iron"), major_segs=10, minor_segs=4,
                arc=math.pi * 1.3, start=-math.pi * 0.4),
          box("HoistNet", (0.9, 0.9, 0.7), (0, -D / 2 - 1.95, H - 2.0), bevel=0.15, m=cmat("Rope", rough=0.9))]
    # Crates and kegs stacked inside, against the walls.
    for k, (x, y, z, sz) in enumerate(((-4.0, 2.5, 0.6, 1.2), (-4.0, 2.5, 1.8, 1.1), (-2.8, 3.3, 0.55, 1.1), (3.9, 2.8, 0.6, 1.2), (3.9, 1.5, 0.6, 1.2),
                                       (3.9, 2.1, 1.8, 1.1))):
        p.append(box(f"Crate{k}", (sz, sz, sz), (x, y, z), bevel=0.06, m=cmat("WoodLight", rough=0.8)))
    for k, (x, y) in enumerate(((-4.2, -1.0), (-4.2, 0.0), (-3.4, -0.5))):
        p += barrel(f"Keg{k}", 0.42, 1.0, (x, y, 0.0))
    save("cove_warehouse", [merge("Warehouse", p)])


ALL = {"swing": build_swing, "lighthouse": build_lighthouse, "tavern": build_tavern, "hut": build_hut, "cave": build_cave, "tunnel": build_tunnel,
       "warehouse": build_warehouse}

if __name__ == "__main__":
    for key in (sys.argv[1:] or list(ALL)):
        ALL[key]()
