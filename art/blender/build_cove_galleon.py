"""The galleon Barnacle Queen, Pirate Cove's landmark (World 13, Skull Harbor).

    cove_galleon.glb   a 34 m three-masted ride galleon, origin at quay level
                       (the waterline is at z -1.3), bow toward -Y:
        Galleon        hull, decks, castles, masts, yards, rigging, figurehead,
                       stern gallery and lanterns (static)
        Sails          the striped sails and the jib (static, its own mesh so
                       the level can sway it gently)
        GunPort*       empties at the muzzles of the gun ports (port side -X,
                       starboard +X), aimed outward: where the broadside fires
    The main deck (z 3.4, y -10.2 .. 8.2) is walkable; the port bulwark has two
    gangway openings (GANGWAYS) for the gangplanks from the quay. The level
    generator rebuilds the same plan (HALF_BEAM, plan()) for its colliders.

    python art/blender/build_cove_galleon.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cove_common import *  # noqa: F401,F403
from cove_common import _finish, bmesh, Vector  # noqa: F401

HALF_L = 17.0
HALF_BEAM = 4.75
DECK_Z = 3.4
FORE_Z = 5.0          # forecastle deck
QUARTER_Z = 5.6       # quarterdeck
FORE_END = -10.2      # forecastle front wall (y)
QUARTER_START = 8.2   # quarterdeck front wall (y)
GANGWAYS = ((-6.5, 3.0), (4.0, 3.0))   # (centre y, width) on the port (-X) side
STEP = 0.5
# Vertical stations of the hull side: (z, width factor, material key).
BANDS = [(None, 0.12, "RedDark"), (-1.0, 0.76, "RedDark"), (-0.2, 0.93, "WoodDark"), (1.9, 1.0, "Gold"), (2.1, 1.0, "Cream"),
         (3.0, 0.985, "Gold"), (3.2, 0.975, "Wood"), ("top", 0.94, None)]


def plan(y):
    """Half-beam of the hull at y (bow -HALF_L, stern +HALF_L)."""
    s = (y + HALF_L) / (2 * HALF_L)
    if s < 0.35:
        return max(0.06, HALF_BEAM * math.sin(s / 0.35 * math.pi / 2) ** 0.8)
    if s > 0.8:
        return HALF_BEAM * (1.0 - 0.28 * ((s - 0.8) / 0.2) ** 1.5)
    return HALF_BEAM


def sheer(y):
    """Height of the bulwark top at y."""
    s = (y + HALF_L) / (2 * HALF_L)
    z = 4.5
    if s < 0.3:
        z += 1.2 * ((0.3 - s) / 0.3) ** 2
    if s > 0.75:
        z += 1.9 * ((s - 0.75) / 0.25) ** 1.5
    return z


def keel(y):
    s = (y + HALF_L) / (2 * HALF_L)
    return -3.0 + (3.6 * ((0.14 - s) / 0.14) ** 2 if s < 0.14 else 0.0)


def in_gangway(y, side):
    if side > 0:
        return False
    return any(abs(y - c) < w * 0.5 - 0.01 for c, w in GANGWAYS)


def stations():
    n = int(round(2 * HALF_L / STEP))
    return [-HALF_L + STEP * i for i in range(n + 1)]


def hull():
    keys = sorted({b[2] for b in BANDS if b[2]})
    mats = [cmat(k, rough=0.55) for k in keys]
    bm = bmesh.new()
    ys = stations()
    rings = {}
    for side in (-1, 1):
        cols = []
        for y in ys:
            b = plan(y)
            col = []
            for z, f, _ in BANDS:
                zz = keel(y) if z is None else (sheer(y) if z == "top" else max(z, keel(y) + 0.05))
                col.append(bm.verts.new((side * b * f, y, zz)))
            cols.append(col)
        rings[side] = cols
        for i in range(len(ys) - 1):
            for k in range(len(BANDS) - 1):
                if k == len(BANDS) - 2 and in_gangway((ys[i] + ys[i + 1]) * 0.5, side):
                    continue
                a, b2 = cols[i][k], cols[i + 1][k]
                c, d = cols[i + 1][k + 1], cols[i][k + 1]
                f = bm.faces.new((a, b2, c, d) if side > 0 else (a, d, c, b2))
                f.material_index = keys.index(BANDS[k][2])
    # Keel seam and the transom (stern face).
    for i in range(len(ys) - 1):
        f = bm.faces.new((rings[-1][i][0], rings[-1][i + 1][0], rings[1][i + 1][0], rings[1][i][0]))
        f.material_index = keys.index("RedDark")
    last = len(ys) - 1
    transom = [rings[1][last][k] for k in range(len(BANDS))] + [rings[-1][last][k] for k in reversed(range(len(BANDS)))]
    f = bm.faces.new(transom)
    f.material_index = keys.index("WoodDark")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish_multi("Hull", bm, mats, smooth=False)


def inner_bulwarks():
    """The inside of the bulwarks (red), the cap rail along the top."""
    red = cmat("RedDark", rough=0.6)
    parts = []
    ys = stations()
    for side in (-1, 1):
        bm = bmesh.new()
        prev = None
        run = []
        for y in ys:
            b = plan(y) * 0.94 - 0.16
            x = side * max(b, 0.05)
            pair = (bm.verts.new((x, y, DECK_Z)), bm.verts.new((x, y, sheer(y) - 0.02)))
            if prev is not None and not in_gangway(y - STEP * 0.5, side):
                f = bm.faces.new((prev[0], pair[0], pair[1], prev[1]) if side < 0 else (prev[0], prev[1], pair[1], pair[0]))
                f.material_index = 0
            prev = pair
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        for f in bm.faces:
            if f.normal.x * side > 0:
                f.normal_flip()
        parts.append(_finish(f"InnerBulwark{side}", bm, red, (0, 0, 0), (0, 0, 0), smooth=False))
        # Cap rail, broken at the gangways.
        for y in ys:
            if in_gangway(y, side) or y == ys[-1]:
                if len(run) > 1:
                    parts.append(tube(f"CapRail{side}_{len(parts)}", run, 0.13, m=cmat("WoodLight", rough=0.6), segs=6))
                run = []
                continue
            run.append((side * plan(y) * 0.955, y, sheer(y) + 0.04))
        if len(run) > 1:
            parts.append(tube(f"CapRail{side}_end", run, 0.13, m=cmat("WoodLight", rough=0.6), segs=6))
    # Transom rail.
    parts.append(tube("CapRailStern", [(-plan(HALF_L) * 0.95, HALF_L, sheer(HALF_L) + 0.04), (plan(HALF_L) * 0.95, HALF_L, sheer(HALF_L) + 0.04)], 0.13,
                      m=cmat("WoodLight", rough=0.6), segs=6))
    return parts


def deck_poly(y0, y1, z, inset=0.2):
    ys = [y for y in stations() if y0 <= y <= y1]
    if ys[0] > y0:
        ys.insert(0, y0)
    if ys[-1] < y1:
        ys.append(y1)
    right = [(plan(y) * 0.94 - inset, y) for y in ys]
    left = [(-x, y) for x, y in reversed(right)]
    pts = right + left
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, z)) for x, y in pts]
    bm.faces.new(vs)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    return bm


def decks():
    plank, seam = cmat("Plank", rough=0.8), cmat("WoodDark", rough=0.8)
    parts = [_finish("MainDeck", deck_poly(-HALF_L + 0.6, HALF_L - 0.1, DECK_Z, 0.1), plank, (0, 0, 0), (0, 0, 0), smooth=False)]
    # Plank seams along the length of the main deck.
    for k in range(-6, 7):
        x = k * 0.62
        y0, y1 = FORE_END, QUARTER_START
        if abs(x) < plan(y0) * 0.94 - 0.3:
            parts.append(box(f"Seam{k}", (0.03, y1 - y0, 0.012), (x, (y0 + y1) / 2, DECK_Z + 0.006), bevel=0.0, m=seam))
    # Raised forecastle and quarterdeck: their decks, front walls and balustrades.
    for name, y0, y1, z, front in (("Fore", -HALF_L + 0.8, FORE_END, FORE_Z, FORE_END), ("Quarter", QUARTER_START, HALF_L - 0.1, QUARTER_Z, QUARTER_START)):
        parts.append(_finish(name + "Deck", deck_poly(y0, y1, z, 0.12), plank, (0, 0, 0), (0, 0, 0), smooth=False))
        hw = plan(front) * 0.94 - 0.16
        parts.append(box(name + "Wall", (hw * 2, 0.3, z - DECK_Z), (0, front, (z + DECK_Z) / 2), bevel=0.03, m=cmat("WoodLight", rough=0.7)))
        parts.append(box(name + "WallTrim", (hw * 2 + 0.02, 0.34, 0.16), (0, front, z - 0.08), bevel=0.02, m=cmat("Gold", rough=0.4)))
        face = -1 if name == "Quarter" else 1
        yb = front + face * 0.2
        # Balustrade along the edge of the raised deck.
        parts.append(box(name + "BalRail", (hw * 2, 0.14, 0.12), (0, front, z + 1.0), bevel=0.03, m=cmat("WoodLight", rough=0.6)))
        n = int(hw * 2 / 0.38)
        for k in range(n + 1):
            x = -hw + 0.1 + (hw * 2 - 0.2) * k / n
            parts.append(cyl(f"{name}Baluster{k}", 0.055, 0.95, (x, front, z + 0.5), segs=6, bevel=0.0, m=cmat("Cream")))
        # Doors and windows in the castle walls.
        door_x = (0.0,) if name == "Fore" else (-2.0, 2.0)
        for k, dx in enumerate(door_x):
            parts += [box(f"{name}Door{k}", (1.1, 0.08, min(1.9, z - DECK_Z - 0.2)), (dx, yb, DECK_Z + min(1.9, z - DECK_Z - 0.2) / 2), bevel=0.03,
                          m=cmat("Red", rough=0.6)),
                      sphere(f"{name}Knob{k}", 0.06, (dx + 0.38, yb + face * 0.06, DECK_Z + 0.9), m=cmat("Brass", rough=0.3, metal=0.5), segs=6, rings=4)]
        if name == "Quarter":
            for k, dx in enumerate((-3.4, 0.0, 3.4)):
                parts += [box(f"QWin{k}", (0.8, 0.06, 0.6), (dx, yb, DECK_Z + 1.4), bevel=0.02, m=cglow("CoveWindowGlow", "#ffc77a", 1.6)),
                          box(f"QWinFrame{k}", (0.95, 0.04, 0.75), (dx, yb - face * 0.02, DECK_Z + 1.4), bevel=0.02, m=cmat("Gold", rough=0.4))]
        else:
            for k, dx in enumerate((-2.2, 2.2)):
                parts += [cyl(f"FWin{k}", 0.3, 0.06, (dx, yb, DECK_Z + 0.9), rot=rad(90, 0, 0), segs=12, bevel=0.0, m=cglow("CoveWindowGlow", "#ffc77a", 1.6)),
                          torus(f"FWinRim{k}", 0.3, 0.05, (dx, yb, DECK_Z + 0.9), rot=rad(90, 0, 0), m=cmat("Brass", rough=0.35, metal=0.4), major_segs=12,
                                minor_segs=4)]
    # Hatch grating, capstan and the ship's wheel.
    parts += [box("Hatch", (2.4, 2.0, 0.16), (0, -2.0, DECK_Z + 0.08), bevel=0.04, m=cmat("WoodDark")),
              box("HatchGrate", (2.0, 1.6, 0.04), (0, -2.0, DECK_Z + 0.17), bevel=0.0, m=cmat("WoodDeep"))]
    parts += [cyl("Capstan", 0.42, 0.9, (0, 6.4, DECK_Z + 0.45), segs=12, bevel=0.05, m=cmat("WoodLight")),
              cyl("CapstanTop", 0.55, 0.12, (0, 6.4, DECK_Z + 0.95), segs=12, bevel=0.03, m=cmat("Brass", rough=0.35, metal=0.4))]
    wheel_c = (0, 11.0, QUARTER_Z + 1.35)
    parts += [box("WheelStand", (0.3, 0.3, 1.0), (0, 11.15, QUARTER_Z + 0.5), bevel=0.04, m=cmat("WoodDark")),
              torus("Wheel", 0.75, 0.06, wheel_c, rot=rad(90, 0, 0), m=cmat("WoodLight"), major_segs=20, minor_segs=5),
              cyl("WheelHub", 0.15, 0.2, wheel_c, rot=rad(90, 0, 0), segs=10, bevel=0.02, m=cmat("Brass", rough=0.35, metal=0.5))]
    for k in range(8):
        a = math.tau * k / 8
        parts.append(cyl(f"Spoke{k}", 0.035, 1.9, wheel_c, rot=(math.pi / 2, a, 0), segs=5, bevel=0.0, m=cmat("WoodLight")))
    return parts


MASTS = [  # (y, base z, top z, yards [(z, half width)])
    (-7.0, DECK_Z, 24.5, [(12.0, 6.0), (17.8, 4.7), (22.2, 3.2)]),
    (0.5, DECK_Z, 28.5, [(12.8, 6.6), (19.8, 5.1), (24.8, 3.5)]),
    (9.6, QUARTER_Z, 21.5, [(13.0, 4.6), (17.8, 3.6)]),
]


def masts():
    wood, dark = cmat("WoodLight", rough=0.6), cmat("WoodDark", rough=0.6)
    parts = []
    for i, (y, z0, z1, yards) in enumerate(MASTS):
        parts.append(cyl(f"Mast{i}", 0.34, z1 - z0, (0, y, (z0 + z1) / 2), segs=12, bevel=0.03, m=wood, radius_top=0.15))
        parts.append(cyl(f"MastCollar{i}", 0.48, 0.3, (0, y, z0 + 0.15), segs=12, bevel=0.05, m=dark))
        parts.append(sphere(f"MastTop{i}", 0.24, (0, y, z1 + 0.1), m=cmat("Gold", rough=0.35), segs=10, rings=6))
        for k, (z, hw) in enumerate(yards):
            parts.append(cyl(f"Yard{i}{k}", 0.17, hw * 2 + 0.6, (0, y - 0.35, z), rot=rad(0, 90, 0), segs=8, bevel=0.02, m=dark, radius_top=0.17))
            for s in (-1, 1):
                parts.append(cyl(f"YardTip{i}{k}{s}", 0.12, 0.25, (s * (hw + 0.35), y - 0.35, z), rot=rad(0, 90, 0), segs=8, bevel=0.02, m=cmat("Gold")))
        # Shrouds: three lines a side from the lower yard down to the rail.
        top = yards[0][0] - 0.4
        for s in (-1, 1):
            for k, dy in enumerate((-1.3, 0.0, 1.3)):
                yy = y + dy + 0.6
                parts.append(rope(f"Shroud{i}{s}{k}", [(s * 0.3, y, top), (s * plan(yy) * 0.97, yy, sheer(yy) + 0.1)], 0.035, segs=4))
            # Ratlines across the shrouds.
            for r in range(1, 9):
                t = r / 9
                a = Vector((s * 0.3, y, top)).lerp(Vector((s * plan(y - 0.7) * 0.97, y - 0.7, sheer(y - 0.7) + 0.1)), t)
                b = Vector((s * 0.3, y, top)).lerp(Vector((s * plan(y + 1.9) * 0.97, y + 1.9, sheer(y + 1.9) + 0.1)), t)
                parts.append(rope(f"Ratline{i}{s}{r}", [a, b], 0.02, segs=3))
    # Crow's nest on the main mast.
    y = MASTS[1][0]
    parts += [cyl("Nest", 1.05, 0.9, (0, y, 13.8), segs=14, bevel=0.04, m=cmat("WoodDark")),
              torus("NestRim", 1.05, 0.08, (0, y, 14.25), m=cmat("Gold", rough=0.35), major_segs=16, minor_segs=4),
              cyl("NestFloor", 1.1, 0.12, (0, y, 13.35), segs=14, bevel=0.03, m=cmat("WoodLight"))]
    # Stays between the mast tops and to the bowsprit.
    bow_tip = (0, -HALF_L - 8.6, 8.8)
    parts += [rope("StayFore", [(0, MASTS[0][0], MASTS[0][2] - 0.6), bow_tip], 0.04),
              rope("StayMain", [(0, MASTS[1][0], MASTS[1][2] - 0.6), (0, MASTS[0][0], MASTS[0][2] - 1.5)], 0.04),
              rope("StayMizzen", [(0, MASTS[2][0], MASTS[2][2] - 0.6), (0, MASTS[1][0], 20.5)], 0.04),
              rope("Backstay", [(0, MASTS[2][0], MASTS[2][2] - 0.6), (0, HALF_L - 0.3, sheer(HALF_L) + 0.2)], 0.04)]
    # Bowsprit and its jib boom.
    parts.append(tube("Bowsprit", [(0, -HALF_L + 2.5, 4.9), (0, -HALF_L - 9.0, 9.0)], 0.28, m=wood, segs=10, radius_end=0.12))
    # The pirate flag on the main top, and pennants on the others.
    parts += skull_flag("Flag", (0.9, MASTS[1][0], MASTS[1][2] - 0.3), width=1.9, height=1.2, yaw=0.0)
    for i in (0, 2):
        y, _, z1, _ = MASTS[i]
        parts.append(prism(f"Pennant{i}", [(0, 0.25), (2.2, 0.0), (0, -0.25)], 0.03, (0.15, y, z1 - 0.4), m=cmat("Red", rough=0.7)))
    return parts


def sails():
    parts = []
    mats = [cmat("Red", rough=0.75), cmat("Sail", rough=0.8)]
    for i, (y, z0, z1, yards) in enumerate(MASTS):
        for k, (z, hw) in enumerate(yards):
            bottom = yards[k - 1][0] + 0.35 if k > 0 else (z0 + 2.6 if i != 2 else z0 + 2.2)
            parts.append(sail(f"Sail{i}{k}", hw * 2 - 0.2, z - bottom - 0.2, (0, y - 0.55, z - 0.15), billow=0.5 + 0.15 * hw / 6, stripes=5,
                              mats=mats, taper=-0.08 if k == 0 else 0.1))
    # The jib: a triangle from the bowsprit to the fore mast.
    bm = bmesh.new()
    a = bm.verts.new((0, -HALF_L - 7.6, 8.3))
    b = bm.verts.new((0, MASTS[0][0] - 0.6, 18.5))
    c = bm.verts.new((0, -HALF_L - 0.6, 6.3))
    f = bm.faces.new((a, b, c))
    f.material_index = 1
    jib = finish_multi("Jib", bm, mats, smooth=False)
    double_sided(jib)
    parts.append(jib)
    return parts


def figurehead():
    bone, black = cmat("Bone", rough=0.5), cmat("Black", rough=0.7)
    eye = cglow("CoveSkullEye", "#ffb83a", 4.0)
    c = (0, -HALF_L - 0.75, 4.5)
    p = [sphere("SkullHead", 1.2, c, scale=(1.0, 0.95, 0.92), m=bone, segs=16, rings=10),
         box("SkullJaw", (1.1, 0.7, 0.5), (0, c[1] - 0.25, c[2] - 0.82), bevel=0.18, m=bone),
         box("SkullNose", (0.2, 0.1, 0.26), (0, c[1] - 0.92, c[2] - 0.2), rot=(0, 0, 0), bevel=0.04, m=black)]
    for s in (-1, 1):
        p += [sphere(f"Socket{s}", 0.27, (s * 0.36, c[1] - 0.76, c[2] + 0.12), scale=(1, 0.5, 1), m=black, segs=10, rings=6),
              sphere(f"Eye{s}", 0.12, (s * 0.36, c[1] - 0.88, c[2] + 0.12), m=eye, segs=8, rings=5)]
    for k in range(6):
        x = -0.4 + k * 0.16
        p.append(box(f"Tooth{k}", (0.12, 0.08, 0.16), (x, c[1] - 0.6, c[2] - 0.55), bevel=0.03, m=cmat("Cream")))
    # Gold scrollwork along the bow (trailboards) and a crossed-bones plate.
    for s in (-1, 1):
        p.append(tube(f"Trail{s}", [(s * 0.3, -HALF_L + 0.2, 3.6), (s * 1.6, -HALF_L + 3.0, 3.3), (s * 2.6, -HALF_L + 5.0, 3.4)], 0.09,
                      m=cmat("Gold", rough=0.35), segs=6))
        p.append(box(f"CrossBone{s}", (2.0, 0.2, 0.22), (0, c[1] + 0.2, c[2] - 1.35), rot=(0, s * 0.55, 0), bevel=0.08, m=bone))
    return p


def stern_and_ports():
    gold, glow = cmat("Gold", rough=0.4), cglow("CoveWindowGlow", "#ffc77a", 1.6)
    p = []
    yb = HALF_L + 0.06
    bw = plan(HALF_L) * 0.9
    for row, z in enumerate((3.9, 5.9)):
        n = 5 if row == 0 else 4
        for k in range(n):
            x = -bw * 0.75 + bw * 1.5 * (k + 0.5) / n
            p += [box(f"Gallery{row}{k}", (0.7, 0.06, 0.9), (x, yb, z), bevel=0.02, m=glow),
                  box(f"GalleryFrame{row}{k}", (0.86, 0.04, 1.06), (x, yb - 0.02, z), bevel=0.02, m=gold)]
        p.append(box(f"GalleryBalcony{row}", (bw * 1.7, 0.5, 0.14), (0, yb + 0.25, z - 0.62), bevel=0.04, m=cmat("WoodLight")))
    p += [box("NameBoard", (4.2, 0.1, 0.55), (0, yb + 0.02, 2.6), bevel=0.04, m=cmat("Navy")),
          text("NameText", "BARNACLE QUEEN", 0.36, 0.04, (0, yb + 0.09, 2.58), rot=(0, 0, math.pi), m=gold)]
    for k, x in enumerate((-bw * 0.8, 0.0, bw * 0.8)):
        z = sheer(HALF_L) + 0.3
        p.append(cyl(f"SternLampPost{k}", 0.06, 0.9, (x, HALF_L - 0.2, z + 0.4), segs=6, bevel=0.0, m=cmat("Iron")))
        p += lantern(f"SternLamp{k}", (x, HALF_L - 0.2, z + 0.85), scale=2.0 if k == 1 else 1.6)
    # Gun ports along both sides, with muzzles poking out.
    empties = []
    for side in (-1, 1):
        for k in range(7):
            y = -8.4 + k * 2.6
            if side < 0 and in_gangway(y, -1):
                continue
            x = side * (plan(y) + 0.03)
            p += [box(f"Port{side}{k}", (0.08, 0.7, 0.62), (x, y, 2.55), bevel=0.02, m=cmat("Black")),
                  box(f"PortLid{side}{k}", (0.07, 0.8, 0.12), (x + side * 0.05, y, 2.95), bevel=0.02, m=cmat("Red")),
                  cyl(f"Muzzle{side}{k}", 0.16, 0.7, (x + side * 0.3, y, 2.5), rot=rad(0, 90, 0), segs=10, bevel=0.03, m=cmat("Iron", rough=0.4, metal=0.5)),
                  torus(f"MuzzleRing{side}{k}", 0.17, 0.04, (x + side * 0.62, y, 2.5), rot=rad(0, 90, 0), m=cmat("Iron", rough=0.4, metal=0.5),
                        major_segs=10, minor_segs=4)]
            empties.append(("GunPort%s%d" % ("P" if side < 0 else "S", k), (x + side * 0.7, y, 2.5)))
    # Lanterns on the bulwarks by the gangways and amidships.
    for k, (x, y) in enumerate(((-plan(-8.0) * 0.95, -8.0), (-plan(6.0) * 0.95, 6.0), (plan(-2.0) * 0.95, -2.0))):
        p.append(cyl(f"RailLampPost{k}", 0.05, 0.6, (x, y, sheer(y) + 0.4), segs=6, bevel=0.0, m=cmat("Iron")))
        p += lantern(f"RailLamp{k}", (x, y, sheer(y) + 0.7), scale=1.3)
    # The anchor hanging at the starboard bow.
    ax, ay = plan(-13.0) + 0.25, -13.0
    p += [cyl("AnchorShank", 0.09, 2.0, (ax, ay, 2.2), segs=8, bevel=0.0, m=cmat("Iron")),
          torus("AnchorArms", 0.7, 0.09, (ax, ay, 1.6), rot=(math.pi / 2, 0, math.pi / 2), m=cmat("Iron"), major_segs=14, minor_segs=5, arc=math.pi,
                start=math.pi),
          cyl("AnchorStock", 0.07, 1.2, (ax, ay, 3.1), rot=rad(90, 0, 0), segs=6, bevel=0.0, m=cmat("WoodDark")),
          rope("AnchorRope", [(ax, ay, 3.3), (ax - 0.15, ay - 0.6, 4.4)], 0.05)]
    return p, empties


def build():
    reset_scene()
    hull_parts = [hull()] + inner_bulwarks() + decks() + masts() + figurehead()
    extra, empties = stern_and_ports()
    galleon = merge("Galleon", hull_parts + extra)
    sail_ob = merge("Sails", sails())
    objs = [galleon, sail_ob]
    for name, loc in empties:
        objs.append(empty(name, loc))
    save("cove_galleon", objs)


if __name__ == "__main__":
    build()
