"""Fright Fair landmarks (World 11, Ghost Train): one kit,
art/models/fright_landmarks.glb, whose top-level objects are the big pieces
(the level generator picks them by name and builds matching colliders from
the dimensions below). Origins at the centre of the base, fronts facing -Y.

    SkullRide     the ghost-train façade: 30 m wide (x -15..15), its front on
                  y = 0 and its back at y 6, wings 7.5 m tall with corner towers,
                  and in the middle a 12 m grinning skull whose open mouth
                  (MOUTH_W wide, MOUTH_H tall, at ground level) is the ride's
                  tunnel (TUNNEL_D deep, black inside); glowing green eyes and a
                  GHOST TRAIN marquee.
    Carousel      the carousel's static base: a 5.6 m radius deck 0.45 m tall
                  with a centre column.
    CarouselTop   the turning part: canopy, valance, bulbs and eight skeletal
                  horses on brass poles (spins about its origin).
    MirrorHall    a crooked hall of mirrors, footprint x -5..5, y -7..7, walls
                  5 m (0.3 thick); doors (2.4 x 2.9) east at y -3, north at
                  x 1.5 and west at y 0; inside a partition on y 0 from x -1.6
                  to 5 and funhouse mirrors on the walls.
    Crypt         a stone mausoleum, 4.4 x 4.4 m, its open doorway (2.0 x 2.6)
                  facing -Y, 3.4 m deep inside.
    FairGate      the fair's front gate: two striped towers at x +-4.6 (1.4 m
                  square, 7.5 m) and the lit FRIGHT FAIR arch over the 7.8 m gap.
    Manor         the haunted manor for the backdrop (about 40 x 16 m, towers
                  to 30 m), lit windows.

    python art/blender/build_fright_landmarks.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fright_common import *  # noqa: F401,F403

MOUTH_W = 4.6
MOUTH_H = 3.6
TUNNEL_D = 7.0
SKULL_Z = 7.6


def skull_ride():
    bone, bone_d, ink, night = fmat("Bone", rough=0.55), fmat("BoneDark", rough=0.6), fmat("Ink", rough=0.8), fmat("Night", rough=0.9)
    violet, plum, orange, iron = fmat("Violet", rough=0.75), fmat("Plum", rough=0.7), fmat("Orange", rough=0.5), fmat("Iron", metal=0.4)
    green = fglow("FrightEyeGlow", "#7dff6a", 4.0)
    win = fglow("FrightWindowGreen", "#5aff9a", 1.6)
    p = []
    # Wings: board walls either side of the skull, a crooked spiked parapet.
    for s in (-1, 1):
        x0, x1 = s * 4.2, s * 15.0
        cx, w = (x0 + x1) / 2, abs(x1 - x0)
        p += [box(f"Wing{s}", (w, 6.0, 6.8), (cx, 3.0, 3.4), bevel=0.06, m=violet),
              box(f"WingBase{s}", (w + 0.2, 6.2, 0.6), (cx, 3.0, 0.3), bevel=0.05, m=night),
              box(f"WingTrim{s}", (w + 0.2, 6.2, 0.25), (cx, 3.0, 6.9), bevel=0.05, m=orange)]
        for k in range(int(w / 1.2)):
            x = x0 + s * (0.6 + k * 1.2)
            h = 0.6 + 0.35 * ((k * 7) % 3)
            p.append(box(f"Board{s}{k}", (0.12, 0.14, 6.6), (x, -0.06, 3.4), bevel=0.02, m=plum))
            p.append(cyl(f"Spike{s}{k}", 0.16, h, (x, 0.2, 7.0 + h / 2), segs=4, bevel=0.0, m=night, radius_top=0.0))
        # Arched green windows and a bat on each wing.
        for k, wx in enumerate((s * 7.0, s * 10.6)):
            p += [box(f"Win{s}{k}", (1.6, 0.12, 2.2), (wx, -0.08, 3.6), bevel=0.04, m=win),
                  cyl(f"WinTop{s}{k}", 0.8, 0.12, (wx, -0.08, 4.7), rot=rad(90, 0, 0), segs=16, bevel=0.0, m=win),
                  box(f"WinFrame{s}{k}", (1.9, 0.1, 2.5), (wx, -0.02, 3.55), bevel=0.04, m=ink),
                  box(f"WinBar{s}{k}", (0.1, 0.16, 2.6), (wx, -0.14, 3.9), bevel=0.0, m=ink),
                  box(f"WinSill{s}{k}", (2.1, 0.4, 0.15), (wx, -0.2, 2.4), bevel=0.03, m=orange)]
        # Corner tower with a witch-hat roof and a lantern.
        tx = s * 14.0
        p += [box(f"Tower{s}", (3.2, 3.2, 10.0), (tx, 2.0, 5.0), bevel=0.08, m=plum),
              box(f"TowerBand{s}", (3.4, 3.4, 0.3), (tx, 2.0, 9.9), bevel=0.05, m=orange),
              cyl(f"TowerRoof{s}", 2.6, 5.5, (tx, 2.0, 12.8), segs=8, bevel=0.0, m=night, radius_top=0.05, rot=(0, 0, math.pi / 8)),
              cyl(f"TowerFlagPole{s}", 0.05, 1.6, (tx, 2.0, 16.2), segs=6, bevel=0.0, m=iron),
              prism(f"TowerFlag{s}", [(0, 0), (1.0, 0.3), (0, 0.6)], 0.04, (tx, 2.0, 16.4), m=fmat("Green", rough=0.5)),
              box(f"TowerWin{s}", (1.0, 0.12, 1.6), (tx, 0.36, 7.4), bevel=0.04, m=win),
              cyl(f"TowerWinTop{s}", 0.5, 0.12, (tx, 0.36, 8.2), rot=rad(90, 0, 0), segs=12, bevel=0.0, m=win)]
        # A skeletal hand gripping the parapet.
        hx = s * 5.6
        p.append(box(f"Palm{s}", (0.9, 0.6, 0.25), (hx, -0.1, 7.15), bevel=0.08, m=bone))
        for f in range(4):
            fx = hx - 0.33 + f * 0.22
            p.append(tube(f"Finger{s}{f}", [(fx, -0.3, 7.2), (fx, -0.55, 7.0), (fx, -0.6, 6.6)], 0.06, m=bone, segs=5, radius_end=0.045))
    # The skull: cranium, brow, cheekbones, sockets with glowing eyes, nose.
    cz = SKULL_Z
    p += [sphere("Cranium", 5.0, (0, 1.2, cz), scale=(1.0, 0.78, 0.92), m=bone, segs=28, rings=16),
          sphere("Brow", 1.6, (-1.9, -2.2, cz + 0.6), scale=(1.4, 0.55, 0.55), m=bone, segs=14, rings=8),
          sphere("BrowR", 1.6, (1.9, -2.2, cz + 0.6), scale=(1.4, 0.55, 0.55), m=bone, segs=14, rings=8)]
    for s in (-1, 1):
        p += [sphere(f"Cheek{s}", 1.5, (s * 3.0, -1.6, cz - 2.4), scale=(1.0, 0.8, 0.75), m=bone, segs=14, rings=8),
              sphere(f"Socket{s}", 1.25, (s * 1.85, -2.85, cz - 0.4), scale=(1.0, 0.45, 1.05), m=night, segs=16, rings=10),
              sphere(f"Eye{s}", 0.62, (s * 1.85, -3.05, cz - 0.45), scale=(1, 0.6, 1), m=green, segs=12, rings=8),
              bulb(f"EyeBulb{s}", 0.3, (s * 1.85, -3.3, cz - 0.45), green),
              sphere(f"Temple{s}", 1.8, (s * 3.6, 0.4, cz - 0.6), scale=(0.7, 1.0, 1.0), m=bone_d, segs=12, rings=8)]
    p.append(prism("Nose", [(-0.55, 0.0), (0.55, 0.0), (0.0, 1.1)], 0.5, (0, -3.2, cz - 2.9), m=night))
    p.append(prism("NoseBridge", [(-0.2, 0.0), (0.2, 0.0), (0.0, -0.5)], 0.5, (0, -3.15, cz - 1.8), m=bone_d))
    # Upper jaw over the mouth and its teeth.
    p += [box("Maxilla", (6.6, 3.0, 1.6), (0, -0.9, MOUTH_H + 0.8), bevel=0.4, m=bone)]
    nt = 7
    for k in range(nt):
        x = -MOUTH_W / 2 + (k + 0.5) * MOUTH_W / nt
        p.append(box(f"Tooth{k}", (MOUTH_W / nt - 0.08, 0.5, 0.75), (x, -2.25, MOUTH_H - 0.3), bevel=0.12, m=bone if k % 2 else bone_d))
    # Lower jaw: two sides of the open mouth reaching the ground, with teeth.
    for s in (-1, 1):
        jx = s * (MOUTH_W / 2 + 0.8)
        p += [box(f"Jaw{s}", (1.6, 3.2, MOUTH_H + 0.4), (jx, -0.7, (MOUTH_H + 0.4) / 2), bevel=0.3, m=bone),
              box(f"JawTooth{s}", (0.45, 0.45, 0.65), (s * (MOUTH_W / 2 + 0.25), -2.2, 0.32), bevel=0.1, m=bone_d),
              box(f"JawTooth2{s}", (0.45, 0.45, 0.55), (s * (MOUTH_W / 2 + 0.25), -2.2, 1.0), bevel=0.1, m=bone)]
    # The tunnel: black walls, ceiling and back, open at the front.
    hw = MOUTH_W / 2
    p += [box("TunnelL", (0.3, TUNNEL_D, MOUTH_H), (-hw - 0.15, TUNNEL_D / 2 - 2.2, MOUTH_H / 2), bevel=0.0, m=night),
          box("TunnelR", (0.3, TUNNEL_D, MOUTH_H), (hw + 0.15, TUNNEL_D / 2 - 2.2, MOUTH_H / 2), bevel=0.0, m=night),
          box("TunnelTop", (MOUTH_W + 0.6, TUNNEL_D, 0.3), (0, TUNNEL_D / 2 - 2.2, MOUTH_H + 0.15), bevel=0.0, m=night),
          box("TunnelBack", (MOUTH_W + 0.6, 0.3, MOUTH_H), (0, TUNNEL_D - 2.2, MOUTH_H / 2), bevel=0.0, m=night),
          box("TunnelFloor", (MOUTH_W, TUNNEL_D, 0.04), (0, TUNNEL_D / 2 - 2.2, 0.02), bevel=0.0, m=ink)]
    for k in range(5):
        p.append(bulb(f"TunnelBulb{k}", 0.08, (0, -1.0 + k * 1.3, MOUTH_H - 0.1), bulb_green()))
    # The marquee over the skull.
    p += [box("Marquee", (11.0, 0.3, 1.8), (0, -1.2, cz + 5.8), bevel=0.08, m=night),
          box("MarqueeTrim", (11.4, 0.2, 2.2), (0, -1.1, cz + 5.8), bevel=0.06, m=orange),
          text("MarqueeText", "GHOST TRAIN", 1.15, 0.12, (0, -1.42, cz + 5.75), m=fglow("FrightSignGreen", "#7dff6a", 2.2))]
    for k in range(14):
        x = -5.2 + k * 0.8
        p.append(bulb(f"MarqueeBulb{k}", 0.09, (x, -1.42, cz + 6.75), bulb_orange() if k % 2 else bulb_green()))
        p.append(bulb(f"MarqueeBulbB{k}", 0.09, (x, -1.42, cz + 4.85), bulb_green() if k % 2 else bulb_orange()))
    for s in (-1, 1):
        p.append(cyl(f"MarqueePole{s}", 0.12, 4.0, (s * 4.8, -0.6, cz + 3.8), segs=8, bevel=0.0, m=iron))
    # The back of the building (seen from the platform ends) and a roof.
    p += [box("Back", (30.0, 0.3, 7.0), (0, 6.0, 3.5), bevel=0.04, m=night),
          box("Roof", (30.0, 6.4, 0.3), (0, 3.0, 6.85), bevel=0.04, m=night)]
    return merge("SkullRide", p)


def skeletal_horse(prefix, x, y, z, yaw):
    bone, crim, gold, ink = fmat("Bone", rough=0.5), fmat("Crimson", rough=0.5), fmat("Gold", rough=0.35, metal=0.4), fmat("Night")
    p = [sphere(prefix + "Ribs", 0.32, (0, 0, 0.0), scale=(1.0, 2.0, 0.95), m=bone, segs=12, rings=8)]
    for k in range(4):
        p.append(torus(f"{prefix}Rib{k}", 0.31, 0.035, (0, -0.32 + k * 0.22, 0.0), rot=rad(90, 0, 0), m=ink, major_segs=12, minor_segs=4))
    p += [tube(prefix + "Neck", [(0, -0.5, 0.15), (0, -0.75, 0.55), (0, -0.85, 0.75)], 0.1, m=bone, segs=6),
          sphere(prefix + "Head", 0.2, (0, -0.95, 0.82), scale=(0.75, 1.5, 0.8), m=bone, segs=10, rings=7),
          box(prefix + "Saddle", (0.55, 0.55, 0.12), (0, 0.05, 0.3), bevel=0.04, m=crim),
          tube(prefix + "Tail", [(0, 0.62, 0.05), (0, 0.85, -0.1), (0, 0.95, -0.35)], 0.05, m=ink, segs=5)]
    for s in (-1, 1):
        p += [sphere(f"{prefix}Eye{s}", 0.05, (s * 0.12, -1.1, 0.88), m=fglow("FrightEyeGlow", "#7dff6a", 4.0), segs=6, rings=4),
              tube(f"{prefix}LegF{s}", [(s * 0.16, -0.45, -0.1), (s * 0.18, -0.65, -0.35), (s * 0.18, -0.75, -0.62)], 0.045, m=bone, segs=5),
              tube(f"{prefix}LegB{s}", [(s * 0.16, 0.45, -0.1), (s * 0.18, 0.6, -0.4), (s * 0.18, 0.52, -0.62)], 0.045, m=bone, segs=5)]
    p.append(cyl(prefix + "Pole", 0.04, 3.2, (0, 0, 0.45), segs=8, bevel=0.0, m=gold))
    return place(p, loc=(x, y, z), rot_z=yaw)


def carousel():
    wood, orange, purple, ink, gold = fmat("WoodDark", rough=0.8), fmat("Orange", rough=0.5), fmat("Purple", rough=0.5), fmat("Night"), fmat("Gold", rough=0.35, metal=0.4)
    base = [cyl("Deck", 5.6, 0.45, (0, 0, 0.225), segs=40, bevel=0.06, m=wood),
            torus("DeckTrim", 5.6, 0.08, (0, 0, 0.42), m=orange, major_segs=48, minor_segs=5),
            cyl("Column", 0.9, 4.6, (0, 0, 2.3), segs=16, bevel=0.05, m=purple),
            cyl("ColumnBand", 0.95, 0.3, (0, 0, 1.0), segs=16, bevel=0.02, m=gold)]
    for k in range(16):
        a = math.tau * k / 16
        base.append(box(f"Step{k}", (0.8, 0.3, 0.12), (math.cos(a) * 5.75, math.sin(a) * 5.75, 0.06), rot=(0, 0, a), bevel=0.02, m=orange if k % 2 else purple))
    top = [lathe("Canopy", [(6.1, 4.6), (4.0, 5.6), (1.2, 6.6), (0.1, 7.0)], [purple, orange], segs=16, stripes=1, smooth=False, cap_bottom=False),
           cyl("Ceiling", 6.0, 0.1, (0, 0, 4.55), segs=32, bevel=0.0, m=ink),
           cyl("Finial", 0.25, 1.2, (0, 0, 7.5), segs=8, bevel=0.0, m=gold, radius_top=0.02),
           sphere("Orb", 0.35, (0, 0, 7.1), m=fglow("FrightEyeGlow", "#7dff6a", 4.0), segs=10, rings=7)]
    double_sided(top[0])
    for k in range(24):
        a = math.tau * (k + 0.5) / 24
        top.append(cyl(f"Valance{k}", 0.6, 0.05, (math.cos(a) * 6.15, math.sin(a) * 6.15, 4.4), rot=(math.pi / 2, 0, a + math.pi / 2), segs=10, bevel=0.0,
                       m=orange if k % 2 else purple))
        top.append(bulb(f"Bulb{k}", 0.08, (math.cos(a) * 6.2, math.sin(a) * 6.2, 4.75), bulb_orange() if k % 3 else bulb_green()))
    for k in range(8):
        a = math.tau * k / 8
        r = 4.0 if k % 2 else 2.9
        top += skeletal_horse(f"H{k}_", math.cos(a) * r, math.sin(a) * r, 1.35 + 0.25 * (k % 2), a)
    return [merge("Carousel", base), merge("CarouselTop", top)]


def mirror_hall():
    wall, wall_b, roof, ink = fmat("Plum", rough=0.7), fmat("VioletLight", rough=0.7), fmat("Night", rough=0.9), fmat("Ink")
    gold, orange, carpet = fmat("Gold", rough=0.35, metal=0.4), fmat("Orange", rough=0.5), fmat("CrimsonDark", rough=0.9)
    mirror = mat("FrightMirror", "#cfc6ff", rough=0.08, metal=0.85, emit=0.35)
    H, T = 5.0, 0.3
    p = [box("Floor", (10.0, 14.0, 0.06), (0, 0, 0.03), bevel=0.0, m=carpet)]
    # Walls with door gaps: (axis, fixed, from, to, door centre or None).
    walls = [("y", -7.0, -5.0, 5.0, None), ("y", 7.0, -5.0, 5.0, 1.5), ("x", 5.0, -7.0, 7.0, -3.0), ("x", -5.0, -7.0, 7.0, 0.0),
             ("y", 0.0, -1.6, 5.0, None)]
    dw, dh = 2.4, 2.9
    for i, (axis, fixed, a0, a1, door) in enumerate(walls):
        spans = [(a0, a1)] if door is None else [(a0, door - dw / 2), (door + dw / 2, a1)]
        h = H if i < 4 else 3.4
        for j, (s0, s1) in enumerate(spans):
            c, ln = (s0 + s1) / 2, s1 - s0
            size = (ln + T, T, h) if axis == "y" else (T, ln + T, h)
            loc = (c, fixed, h / 2) if axis == "y" else (fixed, c, h / 2)
            p.append(box(f"Wall{i}{j}", size, loc, bevel=0.04, m=wall if i % 2 else wall_b))
        if door is not None:
            size = (dw, T, H - dh) if axis == "y" else (T, dw, H - dh)
            loc = (door, fixed, dh + (H - dh) / 2) if axis == "y" else (fixed, door, dh + (H - dh) / 2)
            p.append(box(f"Lintel{i}", size, loc, bevel=0.04, m=wall))
            fsize = (dw + 0.4, T + 0.12, 0.25) if axis == "y" else (T + 0.12, dw + 0.4, 0.25)
            floc = (door, fixed, dh + 0.12) if axis == "y" else (fixed, door, dh + 0.12)
            p.append(box(f"DoorFrame{i}", fsize, floc, bevel=0.04, m=orange))
    # Funhouse mirrors on the inner faces, wavy gold frames.
    rng = random.Random(6)
    spots = [((x, -6.8), math.pi) for x in (-3.5, -1.0, 1.5, 3.8)] + [((x, -0.2), 0.0) for x in (0.2, 2.6)] + [((x, 0.2), math.pi) for x in (0.6, 3.2)]
    spots += [((x, 6.8), 0.0) for x in (-3.5, -1.0, 3.8)] + [((-4.8, y), math.pi / 2) for y in (-4.5, 3.5, 5.5)] + [((4.8, y), -math.pi / 2) for y in (-5.8, 1.2, 4.5)]
    for k, ((x, y), yaw) in enumerate(spots):
        h = rng.uniform(2.0, 2.6)
        w = rng.uniform(0.9, 1.3)
        part = [box(f"Glass{k}", (w, 0.05, h), (0, 0, 0.5 + h / 2), bevel=0.02, m=mirror),
                box(f"Frame{k}", (w + 0.2, 0.06, h + 0.2), (0, 0.03, 0.5 + h / 2), bevel=0.04, m=gold),
                sphere(f"Crest{k}", 0.22, (0, 0.0, 0.62 + h), scale=(1.4, 0.3, 1.0), m=gold, segs=10, rings=6)]
        p += place(part, loc=(x, y, 0), rot_z=yaw)
    # Inside: a striped dado round the walls and a row of bulbs under the ceiling.
    for k in range(9):
        y = -6.4 + k * 1.6
        for sx in (-1, 1):
            p.append(box(f"Dado{sx}{k}", (0.04, 0.7, 1.1), (sx * 4.83, y, 0.6), bevel=0.0, m=orange if k % 2 else ink))
    for k in range(7):
        x = -4.2 + k * 1.4
        for sy in (-1, 1):
            p.append(box(f"DadoY{sy}{k}", (0.7, 0.04, 1.1), (x, sy * 6.83, 0.6), bevel=0.0, m=orange if k % 2 else ink))
    for k in range(6):
        p.append(bulb(f"CeilBulb{k}", 0.09, (-3.5 + (k % 3) * 3.5, -3.5 if k < 3 else 3.5, H - 0.15), bulb_green() if k % 2 else bulb_orange()))
    # The crooked roof: a leaning gable over a ceiling, a cupola and a big eye window.
    p += [box("Ceiling", (10.4, 14.4, 0.2), (0, 0, H + 0.1), bevel=0.0, m=ink)]
    roof_l = box("RoofL", (6.2, 15.0, 0.3), (-2.6, 0, H + 1.5), rot=(0, math.radians(32), 0), bevel=0.05, m=roof)
    roof_r = box("RoofR", (6.2, 15.0, 0.3), (2.6, 0, H + 1.5), rot=(0, math.radians(-38), 0), bevel=0.05, m=roof)
    p += [roof_l, roof_r]
    for s in (-1, 1):
        p.append(prism(f"Gable{s}", [(-5.0, 0.0), (5.0, 0.0), (0.3, 3.4)], 0.3, (0, s * 7.0, H), m=wall_b))
    p += [box("Cupola", (1.6, 1.6, 1.8), (0.4, 2.0, H + 3.6), rot=(0, math.radians(-8), 0.2), bevel=0.06, m=wall),
          cyl("CupolaRoof", 1.3, 1.6, (0.55, 2.0, H + 5.2), rot=(0, math.radians(-8), 0.2), segs=4, bevel=0.0, m=roof, radius_top=0.02)]
    # The front (south, -Y) gable: a big painted eye and the sign.
    p += [sphere("EyeWhite", 1.2, (0.2, -7.25, H + 1.2), scale=(1.4, 0.15, 0.8), m=fmat("Bone"), segs=16, rings=8),
          sphere("EyeIris", 0.55, (0.2, -7.4, H + 1.2), scale=(1, 0.15, 1), m=fglow("FrightEyeGlow", "#7dff6a", 4.0), segs=12, rings=6),
          sphere("EyePupil", 0.25, (0.2, -7.48, H + 1.2), scale=(1, 0.15, 1), m=ink, segs=10, rings=5),
          box("Sign", (7.0, 0.25, 1.2), (0, -7.3, H - 0.8), rot=(0, math.radians(4), 0), bevel=0.05, m=ink),
          text("SignText", "HALL OF MIRRORS", 0.62, 0.08, (0, -7.48, H - 0.85), rot=(0, math.radians(4), 0), m=fglow("FrightSignOrange", "#ffa040", 2.0))]
    for k in range(9):
        p.append(bulb(f"SignBulb{k}", 0.07, (-3.2 + k * 0.8, -7.48, H - 0.15 + 0.06 * (k - 4) * 0.1), bulb_green()))
    # Stripes painted on the outside walls.
    for k in range(6):
        y = -6.0 + k * 2.4
        for s in (-1, 1):
            p.append(box(f"Stripe{s}{k}", (0.06, 0.5, H - 0.4), (s * 5.17, y, H / 2), bevel=0.0, m=orange))
    return merge("MirrorHall", p)


def crypt():
    stone, dark, ink, bone = fmat("Stone", rough=0.9), fmat("StoneDark", rough=0.9), fmat("Night"), fmat("Bone")
    W, D, H = 4.4, 4.4, 3.6
    p = [box("Plinth", (W + 0.6, D + 0.6, 0.3), (0, 0, 0.15), bevel=0.04, m=dark),
         box("Back", (W, 0.4, H), (0, D / 2 - 0.2, H / 2 + 0.3), bevel=0.04, m=stone),
         box("SideL", (0.4, D, H), (-W / 2 + 0.2, 0, H / 2 + 0.3), bevel=0.04, m=stone),
         box("SideR", (0.4, D, H), (W / 2 - 0.2, 0, H / 2 + 0.3), bevel=0.04, m=stone),
         box("Front", (W, 0.4, H - 2.6), (0, -D / 2 + 0.2, 2.6 + (H - 2.6) / 2 + 0.3), bevel=0.04, m=stone),
         box("Roof", (W + 0.5, D + 0.5, 0.35), (0, 0, H + 0.45), bevel=0.06, m=dark),
         prism("Pediment", [(-(W + 0.4) / 2, 0), ((W + 0.4) / 2, 0), (0, 1.3)], 0.4, (0, -D / 2 - 0.05, H + 0.6), m=stone),
         box("Inside", (W - 0.8, D - 0.8, 0.05), (0, 0, 0.32), bevel=0.0, m=ink),
         box("InsideBack", (W - 0.8, 0.05, H - 0.2), (0, D / 2 - 0.42, H / 2 + 0.3), bevel=0.0, m=ink),
         box("Ceil", (W - 0.6, D - 0.6, 0.06), (0, 0, H + 0.26), bevel=0.0, m=ink)]
    for s in (-1, 1):
        p += [cyl(f"Column{s}", 0.22, H, (s * 1.45, -D / 2 - 0.2, H / 2 + 0.3), segs=12, bevel=0.03, m=stone),
              box(f"Door{s}", (1.0, 0.1, 2.5), (s * 1.45, -D / 2 - 0.55, 1.55), rot=(0, 0, s * math.radians(70)), bevel=0.03, m=fmat("Iron", metal=0.4))]
    p += [sphere("Skull", 0.32, (0, -D / 2 - 0.3, H + 1.05), scale=(1, 0.8, 0.95), m=bone, segs=12, rings=8),
          text("Name", "R.I.P.", 0.34, 0.04, (0, -D / 2 - 0.02, 3.2), m=dark),
          bulb("Glow", 0.12, (0, 0.6, 2.6), bulb_green())]
    return merge("Crypt", p)


def fair_gate():
    orange, ink, purple, gold, bone = fmat("Orange", rough=0.5), fmat("Night"), fmat("Purple", rough=0.5), fmat("Gold", rough=0.35, metal=0.4), fmat("Bone")
    p = []
    for s in (-1, 1):
        x = s * 4.6
        for k in range(6):
            p.append(box(f"Band{s}{k}", (1.4, 1.4, 1.2), (x, 0, 0.6 + k * 1.2), bevel=0.06, m=orange if k % 2 == 0 else ink))
        p += [box(f"Cap{s}", (1.7, 1.7, 0.3), (x, 0, 7.35), bevel=0.06, m=gold),
              cyl(f"Spire{s}", 1.0, 2.4, (x, 0, 8.7), segs=4, bevel=0.0, m=purple, radius_top=0.02, rot=(0, 0, math.pi / 4)),
              sphere(f"Ball{s}", 0.28, (x, 0, 10.0), m=fglow("FrightEyeGlow", "#7dff6a", 4.0), segs=10, rings=6)]
        p += pumpkin(f"Pk{s}", (x, -0.75, 7.5), r=0.36, seed=20 + s)
    arch = arc_points(4.6, 0, 180, 24, centre=(0, 0, 6.0), plane="XZ")
    pts = [(x, y, 6.0 + (z - 6.0) * 0.45) for x, y, z in arch]
    p.append(tube("Arch", pts, 0.22, m=purple, segs=10))
    p += [box("Board", (6.6, 0.3, 1.3), (0, -0.1, 7.6), bevel=0.06, m=ink),
          box("BoardTrim", (6.9, 0.2, 1.55), (0, 0.0, 7.6), bevel=0.05, m=orange),
          text("BoardText", "FRIGHT FAIR", 0.86, 0.1, (0, -0.32, 7.56), m=fglow("FrightSignGreen", "#7dff6a", 2.2)),
          sphere("Skull", 0.7, (0, -0.1, 8.75), scale=(1, 0.8, 0.95), m=bone, segs=14, rings=9)]
    for s in (-1, 1):
        p.append(bulb(f"SkullEye{s}", 0.11, (s * 0.24, -0.62, 8.75), fglow("FrightEyeGlow", "#7dff6a", 4.0)))
    for k in range(len(pts)):
        if k % 2 == 0:
            x, y, z = pts[k]
            p.append(bulb(f"ArchBulb{k}", 0.09, (x, y - 0.24, z), bulb_orange() if k % 4 else bulb_green()))
    return merge("FairGate", p)


def manor():
    wall, roof, ink, trim = fmat("Violet", rough=0.85), fmat("Night", rough=0.9), fmat("Ink"), fmat("StoneDark", rough=0.9)
    lit_o, lit_g = fglow("FrightWindowOrange", "#ffb24a", 2.2), fglow("FrightWindowGreen", "#5aff9a", 1.6)
    rng = random.Random(31)
    p = [box("Main", (22.0, 12.0, 14.0), (0, 0, 7.0), bevel=0.2, m=wall),
         box("MainBand", (22.4, 12.4, 0.6), (0, 0, 14.0), bevel=0.1, m=trim),
         prism("MainRoof", [(-11.5, 0), (11.5, 0), (2.0, 8.0)], 12.6, (0, 0, 14.2), m=roof),
         box("Porch", (8.0, 3.0, 4.0), (0, -7.4, 2.0), bevel=0.1, m=trim),
         prism("PorchRoof", [(-4.5, 0), (4.5, 0), (0, 2.2)], 3.4, (0, -7.4, 4.0), m=roof)]
    for s, (tx, th, tw) in ((-1, (-13.0, 22.0, 6.0)), (1, (12.5, 18.0, 5.0))):
        p += [box(f"Tower{s}", (tw, tw, th), (tx, 0.5, th / 2), bevel=0.15, m=wall),
              cyl(f"Spire{s}", tw * 0.78, th * 0.55, (tx, 0.5, th + th * 0.275), segs=8, bevel=0.0, m=roof, radius_top=0.05,
                  rot=(rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06), 0.4)),
              box(f"TowerWin{s}", (1.6, 0.2, 2.6), (tx, 0.5 - tw / 2 - 0.05, th - 4.0), bevel=0.05, m=lit_g if s < 0 else lit_o)]
    p += [box("Chimney", (1.6, 1.6, 6.0), (6.0, 2.0, 21.0), rot=(0, 0.12, 0), bevel=0.1, m=trim),
          box("ChimneyB", (1.4, 1.4, 5.0), (-5.0, -1.5, 20.0), rot=(0, -0.1, 0), bevel=0.1, m=trim)]
    for row in range(3):
        for col in range(6):
            x = -8.5 + col * 3.4
            z = 2.6 + row * 4.2
            if row == 0 and abs(x) < 4:
                continue
            on = rng.random() < 0.55
            p += [box(f"Win{row}{col}", (1.4, 0.2, 2.2), (x, -6.05, z), bevel=0.04, m=(lit_o if rng.random() < 0.7 else lit_g) if on else ink),
                  box(f"WinFrame{row}{col}", (1.7, 0.15, 2.5), (x, -6.0, z), bevel=0.04, m=trim)]
    p += [box("Door", (1.8, 0.2, 2.8), (0, -8.95, 1.4), bevel=0.04, m=lit_o)]
    return merge("Manor", p)


def build():
    reset_scene()
    objects = [skull_ride()] + carousel() + [mirror_hall(), crypt(), fair_gate(), manor()]
    save_glb("fright_landmarks", objects)


if __name__ == "__main__":
    build()
