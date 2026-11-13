"""Sky Carnival landmarks (World 10, Sky Harbor): the airship Cumulus and its
mooring tower, the big-top tent and its bleachers, the carnival beacon, the
carousel, the sky-ride station and cabin, the hot-air balloon, the cargo lift,
the circus wagon and the far islands of the skyline.

    sky_airship          56 m envelope along Y (Godot -Z = nose), gondola floor at z -10.8
                         below the axis (the axis is the model origin); propellers are
                         separate (sky_propeller, radius 1.7, spinning about Y)
    sky_mooring_tower    16.4 m lattice mast, the nose cone clamp facing +Y
    sky_bigtop           the tent shell (double-sided), radius 9.5, eave 4.2 m, peak 11 m,
                         doorways (5 m) at 0/90/180/270 degrees; ring kerb and sawdust inside
    sky_bleachers        3-step stand, 5.2 x 2.4 m, 1.4 m tall, facing -Y
    sky_beacon           13 m striped lighthouse with a gallery; sky_beacon_lamp spins on top
    sky_carousel         static base (r 5.0) and column; sky_carousel_top spins (canopy, horses)
    sky_ride_station     open sky-ride shed facing -Y (7 x 6 m), bullwheel on top
    sky_ride_cabin       pastel gondola cabin hanging from its grip at the origin
    sky_balloon          hot-air balloon, basket at the origin; envelope gores use the
                         materials SkyBalloonA / SkyBalloonB (recoloured per instance)
    sky_cargo_lift       open lift cage 3.4 x 3.4 m on a winch gantry
    sky_wagon            circus wagon 4.6 x 2.2 m, door open on its -Y side
    sky_far_isle         a distant island: turf top (r 18), cottages, round trees, rock below

    python art/blender/build_sky_landmarks.py [names...]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sky_common import *  # noqa: F401,F403

AIRSHIP_LEN = 56.0
AIRSHIP_R = 7.0


def build_airship():
    reset_scene()
    cream, peach, red, teal, navy = smat("Cream"), smat("Peach"), smat("Red", rough=0.45), smat("Teal", rough=0.45), smat("Navy")
    gold, white = smat("Gold", rough=0.35), smat("White")
    half = AIRSHIP_LEN / 2
    prof = []
    for i in range(17):
        t = i / 16
        z = -half + t * AIRSHIP_LEN
        # Blunt nose (t = 1), long taper to the tail.
        r = AIRSHIP_R * (math.sin(math.pi * min(1.0, t ** 0.75)) ** 0.55) if t < 1 else 0.0
        prof.append((max(r, 0.15), z))
    prof[-1] = (0.6, half)
    env = lathe("Envelope", prof, [cream, peach], segs=28, stripes=2, smooth=True)
    env.rotation_euler = rad(-90, 0, 0)   # lathe axis Z -> -Y: the nose points -Y
    p = [env]
    # Bands round the envelope, a nose cap and the name on both flanks.
    for k, (y, m) in enumerate(((-half + 8.0, red), (-half + 9.0, gold), (half - 12.0, teal))):
        t = (-y + half) / AIRSHIP_LEN
        r = AIRSHIP_R * (math.sin(math.pi * min(1.0, (1 - t) ** 0.75)) ** 0.55) + 0.08
        p.append(torus(f"Band{k}", r, 0.18, (0, y, 0), rot=rad(90, 0, 0), m=m, major_segs=28, minor_segs=5))
    p.append(sphere("NoseCap", 0.9, (0, -half + 0.2, 0), m=gold, segs=12, rings=6))
    for s in (-1, 1):
        t = text(f"Name{s}", "CUMULUS", 3.2, 0.12, (s * (AIRSHIP_R + 0.05), -2.0, 0.6), rot=(math.pi / 2, 0, s * math.pi / 2), m=navy)
        p.append(t)
    # Tail fins: four, red with navy edges.
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        fin = prism(f"Fin{k}", [(0, 0), (6.5, 0), (5.5, 4.8), (1.5, 4.8)], 0.35, (0, 0, 0), rot=(0, 0, 0), m=red if k % 2 else teal, bevel=0.05)
        fin.rotation_euler = (math.pi / 2, a, math.pi / 2)
        fin.location = (math.cos(a) * 2.2, half - 7.5, math.sin(a) * 2.2)
        p.append(fin)
    # Gondola: long cabin under the envelope, a window strip, a stern deck.
    gz = -AIRSHIP_R - 3.8 + 1.8
    p += [box("Gondola", (3.6, 18.0, 3.4), (0, -2.0, gz), bevel=0.4, segs=3, m=cream),
          box("GondolaKeel", (3.0, 17.0, 0.5), (0, -2.0, gz - 1.75), bevel=0.2, m=navy),
          box("GondolaRoof", (3.8, 18.2, 0.3), (0, -2.0, gz + 1.75), bevel=0.12, m=red),
          box("WindowStrip", (3.66, 15.0, 0.9), (0, -2.0, gz + 0.45), bevel=0.1, m=sglow("SkyWindow", "#ffe2a8", 1.6))]
    for k in range(10):
        y = -9.0 + k * 1.55
        for s in (-1, 1):
            p.append(box(f"Mullion{k}{s}", (0.1, 0.18, 0.95), (s * 1.84, y, gz + 0.45), bevel=0.0, m=navy))
    p.append(box("Door", (0.1, 1.4, 2.4), (1.83, 0.5, gz - 0.3), bevel=0.0, m=navy))
    p.append(sphere("Bow", 1.7, (0, -11.0, gz), scale=(1.0, 1.0, 0.95), m=sglow("SkyWindow", "#ffe2a8", 1.6), segs=14, rings=8))
    for k in range(6):
        y = -9.0 + k * 3.2
        for s in (-1, 1):
            p.append(tube(f"Strut{k}{s}", [(s * 1.5, y, gz + 1.8), (s * 2.6, y + 0.4, -AIRSHIP_R * 0.86)], 0.07, m=navy, segs=5))
    # Engine pods on outriggers (the propellers are separate).
    for k, (y, s) in enumerate(((-4.0, -1), (-4.0, 1), (6.0, -1), (6.0, 1))):
        x = s * 6.4
        p += [tube(f"Outrigger{k}", [(s * 1.8, y, gz + 1.0), (x, y, gz + 1.6)], 0.12, m=navy, segs=6),
              cyl(f"Pod{k}", 0.75, 2.6, (x, y, gz + 1.6), rot=rad(90, 0, 0), segs=12, bevel=0.2, m=red, radius_top=0.5),
              sphere(f"PodNose{k}", 0.5, (x, y + 1.35, gz + 1.6), m=gold, segs=10, rings=6)]
    p += pennants("PenL", (0, -half + 3.0, AIRSHIP_R * 0.62), (0, half - 6.0, AIRSHIP_R * 0.95), 26, -0.4, [red, gold, teal], size=0.7)
    save("sky_airship", [merge("Airship", p)])
    reset_scene()
    q = [sphere("Spinner", 0.35, (0, 0, 0), scale=(1, 1.4, 1), m=smat("Gold", rough=0.35), segs=10, rings=6)]
    for k in range(3):
        a = math.tau * k / 3
        q.append(prism(f"Blade{k}", [(0.0, -0.18), (1.7, -0.1), (1.75, 0.12), (0.0, 0.25)], 0.08, (0, 0, 0), rot=(0, -a, 0), m=smat("Navy")))
    save("sky_propeller", [merge("Propeller", q)])


def build_mooring_tower():
    reset_scene()
    white, red, navy, gold = smat("White"), smat("Red", rough=0.45), smat("Navy"), smat("Gold", rough=0.35)
    H = 14.0
    p = [cyl("Plinth", 2.2, 0.6, (0, 0, 0.3), segs=12, bevel=0.06, m=navy, radius_top=1.9)]
    p += truss("Mast", (0, 0, 0.6), (0, 0, H), 1.6, white, chord=0.12, web=0.05, panels=10)
    for k, z in enumerate((4.0, 8.0, 12.0)):
        p.append(box(f"Collar{k}", (1.9, 1.9, 0.25), (0, 0, z), bevel=0.05, m=red))
    p += [cyl("Head", 1.1, 1.2, (0, 0, H + 0.6), segs=12, bevel=0.1, m=red),
          cyl("Cup", 1.0, 1.6, (0, 1.4, H + 0.6), rot=rad(90, 0, 0), segs=14, bevel=0.1, m=gold, radius_top=0.5),
          cyl("Cap", 0.9, 0.9, (0, 0, H + 1.65), segs=12, bevel=0.1, m=navy, radius_top=0.2),
          bulb("Beacon", 0.2, (0, 0, H + 2.25), sglow("SkyRedLamp", "#ff5a5a", 3.0))]
    p += pennants("PenA", (0.2, 0, H + 1.9), (6.0, -4.0, 1.0), 10, 0.6, [red, smat("Gold", rough=0.5), smat("Teal", rough=0.5)], size=0.4)
    p += pennants("PenB", (-0.2, 0, H + 1.9), (-5.0, -4.5, 1.0), 10, 0.6, [red, smat("Gold", rough=0.5), smat("Teal", rough=0.5)], size=0.4)
    save("sky_mooring_tower", [merge("MooringTower", p)])


BIGTOP_R = 9.5
EAVE = 4.2
PEAK = 11.0
DOOR_HALF_DEG = math.degrees(math.asin(2.6 / BIGTOP_R))


def build_bigtop():
    reset_scene()
    red, cream, gold, navy, white = smat("Red", rough=0.55), smat("Canvas", rough=0.7), smat("Gold", rough=0.4), smat("Navy"), smat("White")
    roof = lathe("Roof", [(BIGTOP_R + 0.3, EAVE), (7.0, 6.6), (3.6, 9.2), (0.35, PEAK)], [red, cream], segs=32, stripes=1, smooth=False, cap_top=False, cap_bottom=False)
    double_sided(roof)
    p = [roof]
    # Valance scallops round the eave.
    for k in range(32):
        a = math.tau * (k + 0.5) / 32
        r = BIGTOP_R + 0.32
        sc = cyl(f"Scallop{k}", 0.85, 0.05, (math.cos(a) * r, math.sin(a) * r, EAVE - 0.05), rot=(math.pi / 2, 0, a + math.pi / 2), segs=10, bevel=0.0,
                 m=gold if k % 2 else red)
        p.append(sc)
    # Walls between the four doorways (vertical stripes, double-sided).
    for d in range(4):
        a0 = math.radians(d * 90 + DOOR_HALF_DEG)
        a1 = math.radians(d * 90 + 90 - DOOR_HALF_DEG)
        n = 12
        bm = bmesh.new()
        lo, hi = [], []
        for i in range(n + 1):
            a = a0 + (a1 - a0) * i / n
            r = BIGTOP_R - 0.1
            lo.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, 0.0)))
            hi.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, EAVE + 0.05)))
        for i in range(n):
            f = bm.faces.new((lo[i], lo[i + 1], hi[i + 1], hi[i]))
            f.material_index = i % 2
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        wall = finish_multi(f"Wall{d}", bm, [cream, red], smooth=False)
        double_sided(wall)
        p.append(wall)
    # Poles: the king pole, door poles and a guy rope with stakes outside.
    p += [cyl("KingPole", 0.25, PEAK + 1.6, (0, 0, (PEAK + 1.6) / 2), segs=12, bevel=0.0, m=white),
          sphere("KingBall", 0.35, (0, 0, PEAK + 1.75), m=gold, segs=10, rings=6),
          prism("Flag", [(0, 0), (1.6, -0.35), (0, -0.9)], 0.04, (0.2, 0, PEAK + 1.5), m=red)]
    for k in range(5):
        p.append(cyl(f"KingStripe{k}", 0.27, 0.35, (0, 0, 1.0 + k * 2.0), segs=12, bevel=0.0, m=red))
    for d in range(4):
        for s in (-1, 1):
            a = math.radians(d * 90 + s * DOOR_HALF_DEG)
            x, y = math.cos(a) * (BIGTOP_R - 0.05), math.sin(a) * (BIGTOP_R - 0.05)
            p += [cyl(f"DoorPole{d}{s}", 0.14, EAVE + 0.6, (x, y, (EAVE + 0.6) / 2), segs=8, bevel=0.0, m=gold),
                  sphere(f"DoorBall{d}{s}", 0.17, (x, y, EAVE + 0.7), m=red, segs=8, rings=5)]
        mid = math.radians(d * 90)
        p.append(tube(f"DoorSwag{d}", [(math.cos(mid + math.radians(s * DOOR_HALF_DEG * t)) * BIGTOP_R, math.sin(mid + math.radians(s * DOOR_HALF_DEG * t)) * BIGTOP_R,
                                       EAVE - 0.5 * (1 - abs(t))) for s in (-1,) for t in (1.0, 0.5, 0.0, -0.5, -1.0)], 0.06, m=gold, segs=5))
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        top = (math.cos(a) * (BIGTOP_R + 0.2), math.sin(a) * (BIGTOP_R + 0.2), EAVE)
        stake = (math.cos(a) * (BIGTOP_R + 1.6), math.sin(a) * (BIGTOP_R + 1.6), 0.15)
        p += [tube(f"Guy{k}", [top, stake], 0.025, m=smat("Rope", rough=0.9), segs=4),
              cyl(f"Stake{k}", 0.07, 0.4, stake, segs=6, bevel=0.0, m=smat("WoodDark", rough=0.8))]
    # Inside: sawdust floor, the ring kerb (two gaps) and a star pedestal.
    p.append(disc("Sawdust", BIGTOP_R - 0.2, (0, 0, 0.015), m=smat("WoodLight", rough=0.95), segs=40, thickness=0.03))
    for half in range(2):
        pts = []
        for i in range(17):
            a = math.radians(half * 180 + 20 + 140 * i / 16)
            pts.append((math.cos(a) * 3.6, math.sin(a) * 3.6, 0.28))
        p.append(tube(f"Kerb{half}", pts, 0.28, m=red, segs=8))
        p.append(tube(f"KerbTop{half}", [(x, y, 0.56) for x, y, _ in pts], 0.09, m=gold, segs=6))
    p += [cyl("Pedestal", 0.9, 0.7, (0, 0, 0.35), segs=16, bevel=0.06, m=navy),
          star("PedStar", 0.75, 0.06, (0, 0, 0.72), rot=(0, 0, 0), m=gold)]
    p[-1].rotation_euler = (math.pi / 2, 0, 0)
    save("sky_bigtop", [merge("BigTop", p)])


def build_bleachers():
    reset_scene()
    wood, light, navy = smat("Wood", rough=0.8), smat("WoodLight", rough=0.8), smat("Navy")
    W = 5.2
    p = []
    for k in range(3):
        z = 0.47 * (k + 1)
        y = -0.8 + k * 0.8
        p += [box(f"Seat{k}", (W, 0.8, 0.12), (0, y, z - 0.06), bevel=0.03, m=light if k % 2 else wood),
              box(f"Riser{k}", (W, 0.1, z), (0, y - 0.38, z / 2), bevel=0.02, m=navy)]
    p += [box("Back", (W, 0.12, 1.6), (0, 0.42, 0.8), bevel=0.03, m=navy),
          box("SideL", (0.12, 2.4, 1.45), (-W / 2, 0, 0.72), bevel=0.03, m=smat("Red", rough=0.5)),
          box("SideR", (0.12, 2.4, 1.45), (W / 2, 0, 0.72), bevel=0.03, m=smat("Red", rough=0.5))]
    save("sky_bleachers", [merge("Bleachers", p)])


def build_beacon():
    reset_scene()
    red, white, navy, gold = smat("Red", rough=0.45), smat("White"), smat("Navy"), smat("Gold", rough=0.35)
    prof = [(2.1 - 0.06 * k, k * 1.25) for k in range(10)]
    tower = lathe("Tower", prof, [white, red], segs=18, stripes=None, smooth=True)
    p = [cyl("Base", 2.7, 0.8, (0, 0, 0.4), segs=18, bevel=0.08, m=navy),
         tower,
         box("Door", (1.0, 0.3, 1.9), (0, -2.1, 1.25), bevel=0.05, m=navy),
         cyl("Gallery", 2.3, 0.3, (0, 0, 11.4), segs=18, bevel=0.05, m=navy)]
    for k in range(16):
        a = math.tau * k / 16
        p.append(cyl(f"Rail{k}", 0.04, 0.8, (math.cos(a) * 2.2, math.sin(a) * 2.2, 11.95), segs=4, bevel=0.0, m=white))
    p += [torus("RailTop", 2.2, 0.05, (0, 0, 12.35), m=red, major_segs=24, minor_segs=4),
          cyl("LampRoomBase", 1.3, 0.4, (0, 0, 11.75), segs=16, bevel=0.03, m=white),
          cyl("Roof", 1.55, 1.3, (0, 0, 14.0), segs=16, bevel=0.05, m=red, radius_top=0.15),
          sphere("RoofBall", 0.25, (0, 0, 14.75), m=gold, segs=8, rings=5)]
    for k in range(8):
        a = math.tau * k / 8
        p.append(cyl(f"Glaze{k}", 0.05, 1.4, (math.cos(a) * 1.25, math.sin(a) * 1.25, 12.65), segs=4, bevel=0.0, m=navy))
    for k in range(4):
        p.append(box(f"Window{k}", (0.5, 0.2, 0.8), (0, 0, 3.0 + k * 2.2), rot=(0, 0, k * 1.3), bevel=0.04, m=navy))
        p[-1].location = (math.cos(k * 1.3 - math.pi / 2) * (2.05 - 0.05 * k * 1.7), math.sin(k * 1.3 - math.pi / 2) * (2.05 - 0.05 * k * 1.7), 3.0 + k * 2.2)
    save("sky_beacon", [merge("Beacon", p)])
    reset_scene()
    lamp = sglow("SkyBeaconLamp", "#fff0b8", 4.0)
    q = [cyl("Drum", 0.7, 1.0, (0, 0, 0), segs=12, bevel=0.06, m=lamp),
         cyl("Lens", 0.32, 1.2, (0, 0, 0), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=sglow("SkyBeaconLens", "#ffffff", 6.0))]
    save("sky_beacon_lamp", [merge("BeaconLamp", q)])


def horse(prefix, loc, yaw, m, mane):
    x, y, z = loc
    parts = [box(prefix + "Body", (0.38, 1.1, 0.42), (0, 0, 0), bevel=0.15, m=m),
             box(prefix + "Neck", (0.26, 0.3, 0.6), (0, -0.48, 0.35), rot=(math.radians(-25), 0, 0), bevel=0.1, m=m),
             box(prefix + "Head", (0.24, 0.48, 0.24), (0, -0.7, 0.62), rot=(math.radians(20), 0, 0), bevel=0.08, m=m),
             box(prefix + "Mane", (0.08, 0.36, 0.5), (0, -0.4, 0.45), rot=(math.radians(-25), 0, 0), bevel=0.03, m=mane),
             box(prefix + "Saddle", (0.42, 0.4, 0.08), (0, 0.05, 0.22), bevel=0.03, m=mane),
             tube(prefix + "Tail", [(0, 0.52, 0.05), (0, 0.72, -0.15), (0, 0.78, -0.45)], 0.07, m=mane, segs=5, radius_end=0.03)]
    for i, (lx, ly, rot) in enumerate(((-0.12, -0.38, -0.6), (0.12, -0.38, -0.2), (-0.12, 0.38, 0.5), (0.12, 0.38, 0.25))):
        parts.append(box(f"{prefix}Leg{i}", (0.1, 0.1, 0.55), (lx, ly - math.sin(rot) * 0.25, -0.38), rot=(rot, 0, 0), bevel=0.03, m=m))
    return place(parts, (x, y, z), rot_z=yaw)


def build_carousel():
    reset_scene()
    navy, gold, red, white, teal = smat("Navy"), smat("Gold", rough=0.35), smat("Red", rough=0.45), smat("White"), smat("Teal", rough=0.45)
    p = [cyl("Plinth", 5.0, 0.45, (0, 0, 0.225), segs=32, bevel=0.06, m=navy),
         cyl("PlinthTrim", 5.06, 0.08, (0, 0, 0.42), segs=32, bevel=0.0, m=gold),
         cyl("Column", 0.9, 4.2, (0, 0, 2.5), segs=12, bevel=0.05, m=smat("Sky", rough=0.3))]
    for k in range(12):
        a = math.tau * k / 12
        p.append(box(f"Mirror{k}", (0.42, 0.06, 2.6), (math.cos(a) * 0.93, math.sin(a) * 0.93, 2.6), rot=(0, 0, a + math.pi / 2), bevel=0.02,
                     m=sglow("SkyMirror", "#fff3d0", 0.6) if k % 2 else gold))
    save("sky_carousel", [merge("Carousel", p)])
    reset_scene()
    navy, gold, red, white, teal = smat("Navy"), smat("Gold", rough=0.35), smat("Red", rough=0.45), smat("White"), smat("Teal", rough=0.45)
    q = [cyl("Deck", 4.85, 0.1, (0, 0, 0.5), segs=32, bevel=0.0, m=smat("WoodLight", rough=0.7)),
         lathe("Canopy", [(5.4, 4.5), (3.0, 5.6), (0.3, 6.7)], [red, white], segs=24, stripes=1, smooth=False, cap_top=False, cap_bottom=False),
         cyl("Rounding", 5.3, 0.7, (0, 0, 4.25), segs=32, bevel=0.04, m=teal),
         sphere("Top", 0.4, (0, 0, 6.85), m=gold, segs=10, rings=6)]
    double_sided(q[1])
    bulb_m = sglow("SkyBulb", "#ffe2a0", 3.0)
    for k in range(20):
        a = math.tau * k / 20
        q.append(bulb(f"Bulb{k}", 0.07, (math.cos(a) * 5.36, math.sin(a) * 5.36, 4.25), bulb_m))
    cols = [white, smat("Peach"), smat("Sky"), smat("Lilac"), smat("Mint"), smat("Gold"), smat("Pink"), white]
    manes = [red, teal, navy, gold]
    for k in range(8):
        a = math.tau * k / 8
        r = 3.6 if k % 2 else 2.4
        x, y = math.cos(a) * r, math.sin(a) * r
        q.append(cyl(f"Pole{k}", 0.045, 3.7, (x, y, 2.35), segs=6, bevel=0.0, m=gold))
        q += horse(f"H{k}_", (x, y, 1.45 + 0.25 * (k % 3)), a + math.pi, cols[k], manes[k % len(manes)])
    save("sky_carousel_top", [merge("CarouselTop", q)])


def build_ride_station():
    reset_scene()
    navy, red, white, gold, cream, teal = smat("Navy"), smat("Red", rough=0.45), smat("White"), smat("Gold", rough=0.35), smat("Cream"), smat("Teal", rough=0.45)
    W, D, H = 7.0, 6.0, 4.6
    p = [box("Floor", (W, D, 0.2), (0, 0, 0.1), bevel=0.03, m=smat("WoodLight", rough=0.8)),
         box("Back", (W, 0.3, H), (0, D / 2, H / 2), bevel=0.05, m=cream),
         box("SideL", (0.3, D, H), (-W / 2, 0, H / 2), bevel=0.05, m=cream),
         box("SideR", (0.3, D, H), (W / 2, 0, H / 2), bevel=0.05, m=cream),
         box("BackHole", (2.6, 0.34, 3.2), (0, D / 2, 1.8), bevel=0.0, m=navy),
         box("Roof", (W + 1.0, D + 1.0, 0.35), (0, 0, H + 0.17), bevel=0.08, m=red),
         box("Fascia", (W + 1.1, 0.25, 0.9), (0, -D / 2 - 0.4, H - 0.1), bevel=0.06, m=navy),
         text("Sign", "SKY RIDE", 0.62, 0.06, (0, -D / 2 - 0.55, H - 0.15), m=gold)]
    for s in (-1, 1):
        p += [box(f"Pier{s}", (0.6, 0.6, H), (s * (W / 2 - 0.15), -D / 2 + 0.3, H / 2), bevel=0.06, m=red),
              box(f"Stripe{s}", (0.64, 0.64, 0.3), (s * (W / 2 - 0.15), -D / 2 + 0.3, 1.2), bevel=0.04, m=white)]
    # Bullwheel and the cable mast on the roof.
    p += [cyl("WheelMast", 0.3, 2.4, (0, 0.6, H + 1.4), segs=10, bevel=0.03, m=navy),
          torus("Bullwheel", 2.4, 0.16, (0, 0.6, H + 2.6), rot=(0, 0, 0), m=gold, major_segs=32, minor_segs=6)]
    for k in range(6):
        a = math.pi * k / 6
        p.append(box(f"WheelSpoke{k}", (4.8, 0.1, 0.1), (0, 0.6, H + 2.6), rot=(0, 0, a), bevel=0.0, m=navy))
    p += pennants("Pen", (-W / 2 - 0.3, -D / 2 - 0.55, H + 0.3), (W / 2 + 0.3, -D / 2 - 0.55, H + 0.3), 14, 0.25, [red, gold, teal], size=0.3)
    # Queue rails inside.
    for x in (-1.6, 1.6):
        p.append(tube(f"Queue{x}", [(x, -2.0, 0.95), (x, 1.5, 0.95)], 0.05, m=gold, segs=6))
        for y in (-2.0, 1.5):
            p.append(cyl(f"QPost{x}{y}", 0.05, 0.95, (x, y, 0.48), segs=6, bevel=0.0, m=gold))
    save("sky_ride_station", [merge("RideStation", p)])


def build_ride_cabin():
    reset_scene()
    navy, gold = smat("Navy"), smat("Gold", rough=0.35)
    p = [cyl("Grip", 0.18, 0.4, (0, 0, -0.1), segs=8, bevel=0.03, m=navy),
         tube("Hanger", [(0, 0, -0.2), (0, 0.0, -1.0), (0, 0, -1.6)], 0.06, m=navy, segs=6),
         box("Body", (1.9, 1.6, 1.8), (0, 0, -2.6), bevel=0.35, segs=3, m=smat("Peach")),
         box("Windows", (1.95, 1.65, 0.7), (0, 0, -2.35), bevel=0.25, m=mat("SkyGlass", "#cfeeff", rough=0.1)),
         box("Roof", (2.0, 1.7, 0.25), (0, 0, -1.65), bevel=0.12, m=smat("Red", rough=0.45)),
         box("Skirt", (2.0, 1.7, 0.2), (0, 0, -3.45), bevel=0.08, m=navy),
         sphere("Lamp", 0.1, (0, -0.86, -1.9), m=sglow("SkyBulb", "#ffe2a0", 3.0), segs=6, rings=4)]
    save("sky_ride_cabin", [merge("RideCabin", p)])


def build_balloon():
    reset_scene()
    a_m = mat("SkyBalloonA", "#e8384f", rough=0.5)
    b_m = mat("SkyBalloonB", "#fff3e2", rough=0.5)
    wicker, rope, navy = smat("WoodLight", rough=0.9), smat("Rope", rough=0.9), smat("Navy")
    prof = [(0.9, 3.6), (2.4, 5.0), (3.9, 7.0), (4.6, 9.0), (4.5, 10.6), (3.8, 12.0), (2.4, 13.0), (0.2, 13.5)]
    env = lathe("Envelope", prof, [a_m, b_m], segs=24, stripes=2, smooth=True, cap_bottom=False)
    p = [env, torus("Skirt", 0.95, 0.07, (0, 0, 3.6), m=navy, major_segs=20, minor_segs=4),
         box("Basket", (1.5, 1.5, 1.05), (0, 0, 0.525), bevel=0.12, m=wicker),
         box("BasketRim", (1.62, 1.62, 0.12), (0, 0, 1.06), bevel=0.05, m=smat("WoodDark", rough=0.8)),
         cyl("Burner", 0.28, 0.5, (0, 0, 2.6), segs=10, bevel=0.04, m=smat("Steel", rough=0.3, metal=0.6)),
         sphere("Flame", 0.18, (0, 0, 2.95), scale=(1, 1, 1.6), m=sglow("SkyBurner", "#ffb347", 4.0), segs=8, rings=5)]
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        p.append(tube(f"Rope{k}", [(math.cos(a) * 0.72, math.sin(a) * 0.72, 1.1), (math.cos(a) * 0.9, math.sin(a) * 0.9, 3.6)], 0.03, m=rope, segs=4))
        p.append(tube(f"Frame{k}", [(math.cos(a) * 0.7, math.sin(a) * 0.7, 1.1), (math.cos(a) * 0.25, math.sin(a) * 0.25, 2.4)], 0.03, m=navy, segs=4))
    for k in range(3):
        p.append(cyl(f"Sandbag{k}", 0.16, 0.3, (0.8, -0.4 + k * 0.4, 0.6), rot=rad(90, 0, 0), segs=8, bevel=0.06, m=smat("Canvas", rough=0.9)))
    save("sky_balloon", [merge("Balloon", p)])


def build_cargo_lift():
    reset_scene()
    navy, red, gold, steel = smat("Navy"), smat("Red", rough=0.45), smat("Gold", rough=0.35), smat("SteelDark", rough=0.4, metal=0.4)
    S = 3.4
    p = [box("Platform", (S, S, 0.3), (0, 0, -0.15), bevel=0.04, m=steel)]
    for k in range(6):
        p.append(box(f"Tread{k}", (S - 0.2, 0.08, 0.02), (0, -S / 2 + 0.3 + k * 0.55, 0.01), bevel=0.0, m=gold))
    for x in (-1, 1):
        for y in (-1, 1):
            if y > 0:
                p.append(box(f"Post{x}{y}", (0.16, 0.16, 2.6), (x * (S / 2 - 0.08), y * (S / 2 - 0.08), 1.3), bevel=0.03, m=red))
    p += [box("BackRail", (S, 0.08, 0.08), (0, S / 2 - 0.08, 1.1), bevel=0.0, m=red),
          box("BackTop", (S, 0.16, 0.16), (0, S / 2 - 0.08, 2.6), bevel=0.02, m=red)]
    for s in (-1, 1):
        p.append(box(f"SideRail{s}", (0.08, S, 0.08), (s * (S / 2 - 0.08), 0, 1.1), bevel=0.0, m=red))
    # Gantry over the cage with the winch and the cable.
    p += [box("GantryL", (0.3, 0.3, 5.4), (-S / 2 - 0.3, S / 2 + 0.2, 2.7), bevel=0.04, m=navy),
          box("GantryR", (0.3, 0.3, 5.4), (S / 2 + 0.3, S / 2 + 0.2, 2.7), bevel=0.04, m=navy),
          box("Beam", (S + 1.0, 0.4, 0.4), (0, S / 2 + 0.2, 5.4), bevel=0.05, m=red),
          box("Arm", (0.35, S / 2 + 0.5, 0.35), (0, 0.15, 5.4), bevel=0.05, m=red),
          cyl("Pulley", 0.35, 0.18, (0, -0.2, 5.0), rot=rad(0, 90, 0), segs=12, bevel=0.03, m=gold),
          cyl("Cable", 0.03, 2.4, (0, -0.2, 3.8), segs=4, bevel=0.0, m=steel),
          box("Hook", (0.2, 0.1, 0.4), (0, -0.2, 2.5), bevel=0.03, m=gold),
          cyl("Winch", 0.4, 1.0, (-S / 2 - 0.3, S / 2 + 0.75, 0.6), rot=rad(0, 90, 0), segs=12, bevel=0.04, m=gold),
          box("WinchBase", (1.2, 0.8, 0.4), (-S / 2 - 0.3, S / 2 + 0.75, 0.2), bevel=0.04, m=navy),
          text("Sign", "CARGO", 0.32, 0.04, (0, S / 2 + 0.0, 4.9), m=gold)]
    p[-1].location = (0, S / 2 - 0.02, 4.9)
    save("sky_cargo_lift", [merge("CargoLift", p)])


def build_wagon():
    reset_scene()
    red, gold, navy, cream = smat("Red", rough=0.45), smat("Gold", rough=0.35), smat("Navy"), smat("Cream")
    L, W = 4.6, 2.2
    p = [box("Body", (L, W, 2.2), (0, 0, 1.75), bevel=0.12, m=red),
         box("Roof", (L + 0.3, W + 0.3, 0.2), (0, 0, 2.95), bevel=0.08, m=navy),
         box("Clerestory", (L - 0.6, W - 0.8, 0.4), (0, 0, 3.2), bevel=0.06, m=gold),
         box("DoorHole", (1.1, 0.12, 1.8), (0.9, -W / 2, 1.55), bevel=0.0, m=navy),
         box("Door", (1.1, 0.08, 1.8), (1.45 + 0.45, -W / 2 - 0.5, 1.55), rot=(0, 0, math.radians(60)), bevel=0.02, m=cream),
         text("Label", "BACKSTAGE", 0.32, 0.04, (-0.7, -W / 2 - 0.06, 2.2), m=gold)]
    for k in range(5):
        p.append(box(f"Trim{k}", (0.08, W + 0.04, 2.2), (-L / 2 + 0.1 + k * (L - 0.2) / 4, 0, 1.75), bevel=0.0, m=gold))
    for x in (-1.5, 1.5):
        for s in (-1, 1):
            y = s * (W / 2 + 0.1)
            p += [torus(f"Wheel{x}{s}", 0.6, 0.07, (x, y, 0.62), rot=rad(90, 0, 0), m=gold, major_segs=16, minor_segs=5),
                  cyl(f"WHub{x}{s}", 0.12, 0.16, (x, y, 0.62), rot=rad(90, 0, 0), segs=8, bevel=0.0, m=navy)]
            for k in range(4):
                p.append(box(f"WSpoke{x}{s}{k}", (1.2, 0.04, 0.05), (x, y, 0.62), rot=(0, math.pi * k / 4, 0), bevel=0.0, m=navy))
    p += [box("Step", (1.2, 0.5, 0.12), (0.9, -W / 2 - 0.3, 0.55), bevel=0.02, m=navy),
          box("StepB", (1.2, 0.5, 0.12), (0.9, -W / 2 - 0.6, 0.25), bevel=0.02, m=navy)]
    save("sky_wagon", [merge("Wagon", p)])


def build_far_isle():
    reset_scene()
    rng = random.Random(12)
    R = 18.0
    p = [rock_cone("Rock", R, 26.0, seed=21, rings=8, segs=20),
         cyl("Turf", R, 0.6, (0, 0, 0.3), segs=20, bevel=0.15, m=smat("Grass", rough=0.9))]
    roofs = [smat("Red", rough=0.5), smat("Teal", rough=0.5), smat("Navy"), smat("Peach")]
    walls = [smat("Cream"), smat("White"), smat("Gold", rough=0.6), smat("Sky", rough=0.6)]
    for k in range(6):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(2.0, R * 0.7)
        x, y = math.cos(a) * r, math.sin(a) * r
        s = rng.uniform(0.8, 1.3)
        yaw = rng.uniform(0, math.tau)
        house = [box(f"House{k}", (3.0 * s, 2.4 * s, 2.4 * s), (0, 0, 0.6 + 1.2 * s), bevel=0.08, m=walls[k % 4]),
                 prism(f"HouseRoof{k}", [(-1.75 * s, 0), (1.75 * s, 0), (0, 1.6 * s)], 2.7 * s, (0, 0, 0.6 + 2.4 * s), m=roofs[k % 4], bevel=0.04)]
        p += place(house, (x, y, 0), rot_z=yaw)
    for k in range(14):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(1.0, R * 0.92)
        x, y = math.cos(a) * r, math.sin(a) * r
        s = rng.uniform(0.8, 1.6)
        p += [cyl(f"Trunk{k}", 0.25 * s, 1.6 * s, (x, y, 0.6 + 0.8 * s), segs=6, bevel=0.0, m=smat("WoodDark", rough=0.8)),
              sphere(f"Crown{k}", 1.4 * s, (x, y, 0.6 + 2.4 * s), m=smat("Leaf" if k % 2 else "GrassDark", rough=0.8), segs=8, rings=5)]
    save("sky_far_isle", [merge("FarIsle", p)])


BUILDERS = {
    "airship": build_airship, "mooring_tower": build_mooring_tower, "bigtop": build_bigtop, "bleachers": build_bleachers,
    "beacon": build_beacon, "carousel": build_carousel, "ride_station": build_ride_station, "ride_cabin": build_ride_cabin,
    "balloon": build_balloon, "cargo_lift": build_cargo_lift, "wagon": build_wagon, "far_isle": build_far_isle,
}


if __name__ == "__main__":
    wanted = sys.argv[1:] or list(BUILDERS)
    for key in wanted:
        BUILDERS[key]()
