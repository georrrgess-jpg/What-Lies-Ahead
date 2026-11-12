"""The loadout station for Summit Lodge: a red timber ski-rental hut, kitted out
like a real rental counter.

    frost_station.glb    origin = centre of the hut's footprint; counter faces -Y.
        Station        the hut and everything around it: the 'SKI RENTAL' ridge sign,
                       a counter with a till, service bell, goggle stand, cocoa urn and
                       mugs; helmets, goggles, boots and skis inside under two pendant
                       lamps; stickers on the counter front; bunting and eave lights;
                       snowboards and a trail map on the west wall, a ski rack on the
                       east wall, a snowman in a helmet with a pole barrel, energy-cell
                       crates, an A-frame chalkboard, firewood and a sled at the back.
        Shutter        the service shutter, pivot on its hinge, exported in its closed
                       pose (hanging over the window). scenes/props/frost_station.tscn
                       swings it up into an awning while the station is open.
        OpenDressing   the neon OPEN sign, the window light strip and the awning stays
                       (shown only while the station is open).
        ClosedSign     the CLOSED plank on the shutter (shown only while closed).

    Footprint ~6 x 4.4 m (inside the Body collider in scenes/props/frost_station.tscn);
    the ridge sits at 5.1 m, where the level's string lights tie on.

    python art/blender/build_frost_station.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from frost_common import *  # noqa: F401,F403
from mathutils import Euler, Matrix, Vector

HW, HD, WALL, BASE, RIDGE = 2.3, 1.9, 3.1, 0.35, 5.1
HINGE = (0.0, -2.12, 2.95)        # shutter hinge line (Blender coordinates)
SHUTTER_LEN = 1.62
SHUTTER_CLOSED = -18.0             # degrees about X; the scene opens it to -70
SHUTTER_OPEN = -70.0
COUNTER_TOP = 1.62


def xform(parts, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Move a group of parts as one rigid piece (rotate XYZ about the origin, then translate)."""
    m = Matrix.Translation(Vector(loc)) @ Euler(rot, "XYZ").to_matrix().to_4x4()
    for ob in parts:
        ob.matrix_world = m @ ob.matrix_basis
    return parts


def strut(name, p0, p1, size, m, bevel=0.0, segs=2):
    """Box of cross-section `size` = (x, y) running from p0 to p1."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    ob = box(name, (size[0], size[1], d.length), (0, 0, 0), bevel=bevel, segs=segs, m=m)
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    ob.location = (a + b) * 0.5
    return ob


def disc_v(name, radius, loc, m, depth=0.02, segs=16):
    """Flat round decal standing upright, facing -Y."""
    return cyl(name, radius, depth, loc, rot=rad(90, 0, 0), segs=segs, bevel=0.0, m=m)


class Kit:
    """The hut's shared materials."""

    def __init__(self):
        self.red = mat("FrostHutRed", "#c8323c", rough=0.55)
        self.red_dark = mat("FrostHutRedDark", "#8e2232", rough=0.6)
        self.cream = fmat("Cream", rough=0.6)
        self.timber, self.dark = fmat("Timber"), fmat("TimberDark")
        self.light_wood = fmat("TimberLight")
        self.roof, self.snow, self.stone = fmat("Roof", rough=0.7), snow_mat(), fmat("Stone", rough=0.85)
        self.charcoal = fmat("Charcoal", rough=0.5)
        self.steel = fmat("Steel", rough=0.3, metal=0.6)
        self.navy = fmat("Navy")
        self.inside = mat("FrostHutInside", "#c4875a", rough=0.7, emit=0.35)
        self.chalk = mat("FrostChalk", "#1e2a2a", rough=0.9)
        self.amber = fglow("FrostBulbAmber", "#ffc46b", 3.0)
        self.cyan = fglow("FrostSignCyanGlow", "#7ff0ff", 2.6)
        self.lens = [fglow("FrostLensFire", "#ff9a3a", 1.1), fglow("FrostLensIce", "#6fe8ff", 1.1)]
        gear = (("Red", "#e2343f"), ("Cyan", "#3fd4ff"), ("Yellow", "#ffd23f"), ("Purple", "#8a4fe0"),
                ("Green", "#3fc46a"), ("Pink", "#ff4fa0"))
        self.gear = [mat("FrostGear" + n, h, rough=0.4) for n, h in gear]

    def g(self, i):
        return self.gear[i % len(self.gear)]


# ---------------------------------------------------------------------------
# Gear
# ---------------------------------------------------------------------------

def helmet(prefix, k, shell, lens, loc, rot_z=0.0, scale=1.0):
    """Ski helmet with goggles strapped across the front, facing -Y."""
    strap = torus(prefix + "Strap", 0.172, 0.018, (0, 0, -0.03), m=k.charcoal, major_segs=12, minor_segs=3)
    strap.scale = (1.0, 1.1, 1.0)
    parts = [
        sphere(prefix + "Shell", 0.17, (0, 0, 0), scale=(1.0, 1.1, 0.88), m=shell, segs=12, rings=8),
        strap,
        box(prefix + "GogFrame", (0.25, 0.07, 0.1), (0, -0.17, -0.03), bevel=0.04, segs=1, m=k.charcoal),
        box(prefix + "GogLens", (0.21, 0.05, 0.075), (0, -0.2, -0.03), bevel=0.03, segs=1, m=lens),
        fbox_(prefix + "Vent", (0.03, 0.2, 0.03), (0, 0.0, 0.15), k.charcoal),
    ]
    return place(parts, loc, rot_z, scale)


def fbox_(name, size, loc, m, rot=(0, 0, 0)):
    """Unbevelled box (trims, decals, stripes)."""
    return box(name, size, loc, rot=rot, bevel=0.0, m=m)


def goggles(prefix, k, lens, loc, rot_z=0.0):
    """Goggles hanging from a peg by their strap, facing -Y."""
    parts = [
        box(prefix + "Frame", (0.24, 0.05, 0.1), (0, 0, 0), bevel=0.04, segs=1, m=k.charcoal),
        box(prefix + "Lens", (0.2, 0.04, 0.075), (0, -0.025, 0), bevel=0.03, segs=1, m=lens),
        torus(prefix + "Strap", 0.1, 0.012, (0, 0.02, 0.1), rot=rad(90, 0, 0), m=k.charcoal, major_segs=10, minor_segs=3),
        cyl(prefix + "Peg", 0.018, 0.12, (0, 0.06, 0.19), rot=rad(90, 0, 0), segs=6, bevel=0.0, m=k.dark),
    ]
    return place(parts, loc, rot_z)


def boot(prefix, k, shell, cuff, loc, rot_z=0.0):
    """One chunky ski boot, toe toward -Y."""
    parts = [
        fbox_(prefix + "Sole", (0.13, 0.32, 0.05), (0, -0.02, 0.025), k.charcoal),
        box(prefix + "Shell", (0.13, 0.28, 0.16), (0, -0.02, 0.13), bevel=0.05, segs=1, m=shell),
        box(prefix + "Cuff", (0.14, 0.16, 0.2), (0, 0.05, 0.29), bevel=0.04, segs=1, m=cuff),
        fbox_(prefix + "Buckle0", (0.145, 0.03, 0.025), (0, -0.04, 0.2), k.steel),
        fbox_(prefix + "Buckle1", (0.15, 0.03, 0.025), (0, 0.0, 0.33), k.steel),
    ]
    return place(parts, loc, rot_z)


def ski_pair(prefix, k, m, base, top, curl, gap=0.09):
    """Two skis standing on their tails from `base` up to `top`, tips curled toward
    `curl`, with a binding on each."""
    a, b = Vector(base), Vector(top)
    d = (b - a).normalized()
    out = Vector(curl)
    out = (out - d * out.dot(d)).normalized()
    side = out.cross(d).normalized()
    parts = []
    for i, s in enumerate((-0.5, 0.5)):
        off = side * (s * gap)
        parts.append(strut(f"{prefix}{i}", a + off, b + off, (0.075, 0.025), m, bevel=0.01, segs=1))
        tip_base = b + off
        parts.append(strut(f"{prefix}{i}Tip", tip_base, tip_base + d * 0.08 + out * 0.07, (0.075, 0.025), m, bevel=0.01, segs=1))
        mid = a.lerp(b, 0.42) + off + out * 0.03
        parts.append(strut(f"{prefix}{i}Bind", mid - d * 0.1, mid + d * 0.1, (0.06, 0.05), k.charcoal, bevel=0.015, segs=1))
    return parts


def snowboard(prefix, k, m, stripe, base, top, normal):
    """A board leaning from `base` to `top`; the graphic and bindings face `normal`."""
    a, b = Vector(base), Vector(top)
    d = (b - a).normalized()
    n = Vector(normal)
    n = (n - d * n.dot(d)).normalized()
    side = d.cross(n).normalized()
    board = box(prefix + "Deck", (0.03, 0.29, (b - a).length), (0, 0, 0), bevel=0.11, segs=3, m=m)
    # Orient: local Z -> d, local X -> n, local Y -> side.
    basis = Matrix((n, side, d)).transposed().to_4x4()
    centre = (a + b) * 0.5
    parts = [board, fbox_(prefix + "Stripe", (0.012, 0.1, (b - a).length * 0.7), (-0.02, 0, 0), stripe)]
    for i, t in enumerate((-0.22, 0.22)):
        parts.append(box(f"{prefix}Bind{i}", (0.06, 0.24, 0.1), (-0.04, 0, t), bevel=0.025, segs=1, m=k.charcoal))
    # Graphics and bindings sit on the -X face; flip so they face `normal`.
    flip = Matrix.Rotation(math.pi, 4, "Z")
    m4 = Matrix.Translation(centre) @ basis @ flip
    for ob in parts:
        ob.matrix_world = m4 @ ob.matrix_basis
    return parts


def mug(prefix, k, m, loc, cocoa=True):
    parts = [
        cyl(prefix + "Body", 0.055, 0.11, (0, 0, 0.055), segs=10, bevel=0.0, m=m),
        torus(prefix + "Handle", 0.035, 0.011, (0.058, 0, 0.06), rot=rad(90, 0, 0), m=m, major_segs=8, minor_segs=3),
    ]
    if cocoa:
        parts.append(cyl(prefix + "Cocoa", 0.046, 0.01, (0, 0, 0.106), segs=10, bevel=0.0, m=k.dark))
    return place(parts, loc)


def logs_pile(prefix, k, loc):
    """Firewood stacked against a wall (logs along Y, end grain out), snow on top."""
    bark, grain = fmat("Log"), fmat("LogEnd")
    parts = []
    for r, (z, xs) in enumerate(((0.16, (-0.48, -0.16, 0.16, 0.48)), (0.43, (-0.32, 0.0, 0.32)), (0.7, (-0.16, 0.16)))):
        for i, x in enumerate(xs):
            yaw = math.radians((i - 1) * 3)
            parts.append(cyl(f"{prefix}{r}{i}", 0.15, 0.9, (x, 0, z), rot=(math.pi / 2, 0, yaw), segs=9, bevel=0.0, m=bark))
            parts.append(cyl(f"{prefix}{r}{i}End", 0.12, 0.92, (x, 0, z), rot=(math.pi / 2, 0, yaw), segs=9, bevel=0.0, m=grain))
    parts += snow_cap(prefix + "Snow", (0.95, 0.8, 0.08), (0, 0, 0.82), drips=3, seed=11)
    return place(parts, loc)


# ---------------------------------------------------------------------------
# The hut
# ---------------------------------------------------------------------------

def shell(k):
    """Walls, plinth, roof, gables, ridge sign, icicles and the counter."""
    hw, hd, wall = HW, HD, WALL
    p = [
        box("Plinth", (2 * hw + 0.5, 2 * hd + 0.5, BASE), (0, 0, BASE / 2), bevel=0.08, m=k.stone),
        box("Back", (2 * hw, 0.3, wall), (0, hd, BASE + wall / 2), bevel=0.05, m=k.red),
        box("SideL", (0.3, 2 * hd, wall), (-hw, 0, BASE + wall / 2), bevel=0.05, m=k.red),
        box("SideR", (0.3, 2 * hd, wall), (hw, 0, BASE + wall / 2), bevel=0.05, m=k.red),
        box("FrontLow", (2 * hw, 0.3, 1.15), (0, -hd, BASE + 0.575), bevel=0.05, m=k.red),
        box("FrontTop", (2 * hw, 0.3, 0.55), (0, -hd, BASE + wall - 0.275), bevel=0.05, m=k.red),
        box("FrontPostL", (0.5, 0.3, wall), (-hw + 0.25, -hd, BASE + wall / 2), bevel=0.05, m=k.red),
        box("FrontPostR", (0.5, 0.3, wall), (hw - 0.25, -hd, BASE + wall / 2), bevel=0.05, m=k.red),
        box("Counter", (2 * hw - 0.6, 0.7, 0.12), (0, -hd - 0.15, COUNTER_TOP - 0.06), bevel=0.04, m=k.timber),
        box("CounterLip", (2 * hw - 0.5, 0.08, 0.16), (0, -hd - 0.5, COUNTER_TOP - 0.1), bevel=0.03, m=k.cream),
        # Cream fascia band and skirting.
        box("Fascia", (2 * hw + 0.1, 0.06, 0.12), (0, -hd - 0.17, BASE + wall - 0.06), bevel=0.02, m=k.cream),
        box("Skirt", (2 * hw + 0.1, 2 * hd + 0.1, 0.14), (0, 0, BASE + 0.07), bevel=0.03, m=k.cream),
    ]
    for i, x in enumerate((-1.35, 0.0, 1.35)):
        p.append(cyl(f"Knuckle{i}", 0.035, 0.24, (x, HINGE[1] + 0.02, HINGE[2]), rot=rad(0, 90, 0), segs=8, bevel=0.0, m=k.steel))
    for i, (x, y) in enumerate(((-hw, -hd), (hw, -hd), (-hw, hd), (hw, hd))):
        p.append(box(f"Trim{i}", (0.36, 0.36, wall + 0.1), (x, y, BASE + wall / 2), bevel=0.06, m=k.cream))
    for s, sx in (("L", -1), ("R", 1)):
        p += window(f"SideWin{s}", 0.95, 0.85, (sx * (hw + 0.17), 0.95, 2.35), mullions=(2, 2), rot_z=sx * math.pi / 2)
    # Board-and-batten: vertical battens on the back and side walls.
    for i in range(9):
        x = -2.0 + i * 0.5
        p.append(fbox_(f"BattenB{i}", (0.07, 0.05, wall - 0.2), (x, hd + 0.16, BASE + wall / 2), k.red_dark))
    for s, sx in (("L", -1), ("R", 1)):
        for i, y in enumerate((-1.55, -1.05, -0.55, -0.05, 1.7)):
            p.append(fbox_(f"Batten{s}{i}", (0.05, 0.07, wall - 0.2), (sx * (hw + 0.16), y, BASE + wall / 2), k.red_dark))
    # Steep gable roof, ridge along X, heavy snow.
    for side, sy in (("F", -1), ("B", 1)):
        length = math.hypot(hd + 0.8, RIDGE - (BASE + wall))
        ang = math.atan2(RIDGE - (BASE + wall), hd + 0.8)
        centre = (0, sy * (hd + 0.8) / 2, (BASE + wall + RIDGE) / 2 + 0.15)
        p.append(box(f"Roof{side}", (2 * hw + 1.2, length, 0.25), centre, rot=(-sy * ang, 0, 0), bevel=0.06, m=k.roof))
        p.append(box(f"RoofSnow{side}", (2 * hw + 1.0, length - 0.2, 0.32), (0, centre[1] + sy * 0.05, centre[2] + 0.28),
                     rot=(-sy * ang, 0, 0), bevel=0.14, m=k.snow))
        p += icicles(f"HutIcicle{side}", (-hw - 0.55, sy * (hd + 0.85), BASE + wall - 0.05), (hw + 0.55, sy * (hd + 0.85), BASE + wall - 0.05),
                     12, 0.45, seed=5 + sy)
        # A lip of snow curling over the eave.
        for i in range(7):
            x = -hw - 0.3 + i * (2 * hw + 0.6) / 6
            p.append(sphere(f"EaveSnow{side}{i}", 0.2, (x, sy * (hd + 0.82), BASE + wall + 0.18), scale=(2.2, 0.9, 0.8), m=k.snow, segs=8, rings=5))
    for s, sx in (("L", -1), ("R", 1)):
        tri = prism(f"Gable{s}", [(-hd - 0.15, BASE + wall), (hd + 0.15, BASE + wall), (0.0, RIDGE - 0.1)], 0.3, (0, 0, 0), m=k.red)
        tri.rotation_euler = (0, 0, math.pi / 2)
        tri.location = (sx * hw, 0, 0)
        p.append(tri)
        # Gable crest: a cream snowflake roundel.
        p.append(cyl(f"GableBadge{s}", 0.32, 0.06, (sx * (hw + 0.17), 0, 4.15), rot=rad(0, 90, 0), segs=16, bevel=0.02, m=k.cream))
        p += place([star(f"GableFlake{s}", 0.24, 0.05, (0, 0, 0), m=k.red_dark, inner=0.08)], (sx * (hw + 0.22), 0, 4.15), rot_z=sx * math.pi / 2)
    p.append(sphere("RidgeSnow", 0.32, (0, 0, RIDGE + 0.32), scale=(hw * 3.4, 1.0, 0.6), m=k.snow, segs=12, rings=6))
    # 'SKI RENTAL' sign on the ridge, ringed with bulbs.
    p += [
        box("SignBoard", (4.0, 0.2, 1.0), (0, -0.3, RIDGE + 0.85), bevel=0.08, m=k.navy),
        box("SignFrame", (4.2, 0.16, 1.2), (0, -0.22, RIDGE + 0.85), bevel=0.06, m=k.dark),
        text("SignText", "SKI RENTAL", 0.56, 0.06, (0, -0.44, RIDGE + 0.82), m=k.cyan),
        text("SignTextBack", "SKI RENTAL", 0.56, 0.06, (0, -0.0, RIDGE + 0.82), rot=(0, 0, math.pi), m=k.cyan),
        box("SignStrut", (0.2, 0.2, 0.8), (0, -0.2, RIDGE + 0.1), bevel=0.03, m=k.dark),
    ]
    p += snow_cap("SignSnow", (3.9, 0.24, 0.12), (0, -0.25, RIDGE + 1.45), drips=6, seed=8)
    p += bulb_row("SignBulbTop", (-1.95, -0.42, RIDGE + 1.32), (1.95, -0.42, RIDGE + 1.32), 10, 0.065, k.amber)
    p += bulb_row("SignBulbLow", (-1.95, -0.42, RIDGE + 0.38), (1.95, -0.42, RIDGE + 0.38), 10, 0.065, k.amber)
    # Corner lanterns.
    for i, sx in enumerate((-1, 1)):
        p += [
            box(f"LanternArm{i}", (0.5, 0.08, 0.08), (sx * (hw + 0.3), -hd - 0.1, 3.0), bevel=0.02, m=k.dark),
            box(f"LanternBox{i}", (0.22, 0.22, 0.3), (sx * (hw + 0.5), -hd - 0.1, 2.75), bevel=0.03, m=k.amber),
            cyl(f"LanternCap{i}", 0.2, 0.1, (sx * (hw + 0.5), -hd - 0.1, 2.95), segs=4, bevel=0.0, m=k.dark, radius_top=0.04),
            bulb(f"LanternHalo{i}", 0.15, (sx * (hw + 0.5), -hd - 0.1, 2.75), k.amber),
        ]
    return p


def interior(k):
    """What the player sees through the service window: a warm timber room with two
    pendant lamps, helmets on pegs, goggles, a shelf of boots and skis in the corners."""
    p = [
        box("InWallBack", (2 * HW - 0.3, 0.05, WALL - 0.2), (0, HD - 0.18, BASE + WALL / 2), bevel=0.0, m=k.inside),
        box("InWallL", (0.05, 2 * HD - 0.3, WALL - 0.2), (-HW + 0.18, 0, BASE + WALL / 2), bevel=0.0, m=k.inside),
        box("InWallR", (0.05, 2 * HD - 0.3, WALL - 0.2), (HW - 0.18, 0, BASE + WALL / 2), bevel=0.0, m=k.inside),
        box("Ceiling", (2 * HW - 0.3, 2 * HD - 0.3, 0.06), (0, 0, BASE + WALL - 0.12), bevel=0.0, m=k.dark),
    ]
    for i in range(7):
        p.append(fbox_(f"InGroove{i}", (0.03, 0.02, WALL - 0.3), (-1.8 + i * 0.6, HD - 0.21, BASE + WALL / 2), k.light_wood))
    for i, x in enumerate((-1.0, 1.0)):
        p += [
            cyl(f"LampCord{i}", 0.012, 0.42, (x, -0.7, 3.12), segs=5, bevel=0.0, m=k.charcoal),
            cyl(f"LampShade{i}", 0.22, 0.17, (x, -0.7, 2.86), segs=12, bevel=0.0, m=k.g(0), radius_top=0.06),
            bulb(f"LampBulb{i}", 0.07, (x, -0.7, 2.76), k.amber),
        ]
    for i in range(5):
        x = -1.2 + i * 0.6
        p.append(cyl(f"HelmetPeg{i}", 0.02, 0.2, (x, HD - 0.3, 2.6), rot=rad(90, 0, 0), segs=6, bevel=0.0, m=k.dark))
        p += helmet(f"Helmet{i}", k, k.g(i * 2 + 1), k.lens[i % 2], (x, HD - 0.46, 2.72), scale=1.28)
    for i in range(4):
        p += goggles(f"Goggles{i}", k, k.lens[(i + 1) % 2], (-0.9 + i * 0.6, HD - 0.3, 2.24))
    p.append(box("BootShelf", (2.7, 0.4, 0.05), (0, HD - 0.4, 1.66), bevel=0.015, m=k.timber))
    for i, x in enumerate((-1.2, 1.2)):
        p.append(box(f"ShelfBracket{i}", (0.05, 0.3, 0.2), (x, HD - 0.33, 1.56), bevel=0.0, m=k.dark))
    boots = ((k.cream, k.g(1)), (k.g(0), k.charcoal), (k.charcoal, k.g(4)))
    for i, (shell_m, cuff_m) in enumerate(boots):
        x = -0.85 + i * 0.85
        for j, dx in enumerate((-0.09, 0.09)):
            p += boot(f"Boot{i}{j}", k, shell_m, cuff_m, (x + dx, HD - 0.42, 1.685))
    for c, sx in enumerate((-1, 1)):
        for j in range(2):
            y = HD - 0.3 - j * 0.3
            p += ski_pair(f"InSki{c}{j}", k, k.g(c * 3 + j + 2), (sx * 1.66, y - 0.08, BASE + 0.02), (sx * 1.6, y, BASE + 1.98), (0, -1, 0))
    return p


def counter_goods(k):
    y, z = -HD - 0.15, COUNTER_TOP
    p = []
    # Till.
    x = -1.3
    p += [
        box("TillBase", (0.56, 0.46, 0.2), (x, y + 0.05, z + 0.1), bevel=0.04, m=k.g(0)),
        box("TillKeys", (0.5, 0.24, 0.1), (x, y - 0.06, z + 0.23), rot=rad(25, 0, 0), bevel=0.03, m=k.cream),
        box("TillHead", (0.34, 0.12, 0.18), (x + 0.06, y + 0.17, z + 0.38), bevel=0.04, m=k.g(0)),
        fbox_("TillDisplay", (0.26, 0.02, 0.09), (x + 0.06, y + 0.105, z + 0.39), k.cyan),
        fbox_("TillDrawer", (0.48, 0.02, 0.03), (x, y - 0.185, z + 0.08), k.dark),
        cyl("Bell", 0.07, 0.07, (x + 0.55, y - 0.05, z + 0.045), segs=12, bevel=0.03, m=k.g(2), radius_top=0.025),
        sphere("BellKnob", 0.022, (x + 0.55, y - 0.05, z + 0.095), m=k.steel, segs=6, rings=4),
    ]
    # Basket of bobble hats.
    x = -0.5
    p += [
        cyl("Basket", 0.26, 0.2, (x, y, z + 0.1), segs=12, bevel=0.0, m=k.light_wood, radius_top=0.3),
        torus("BasketRim", 0.3, 0.025, (x, y, z + 0.2), m=k.timber, major_segs=12, minor_segs=3),
    ]
    for i, (dx, dy, dz) in enumerate(((-0.12, -0.08, 0.24), (0.1, -0.1, 0.25), (0.0, 0.1, 0.27), (-0.14, 0.12, 0.23), (0.15, 0.1, 0.24), (0.0, -0.02, 0.38))):
        hat = k.g(i * 2 + 1)
        p += [
            sphere(f"Beanie{i}", 0.11, (x + dx, y + dy, z + dz), scale=(1, 1, 0.85), m=hat, segs=10, rings=6),
            cyl(f"BeanieCuff{i}", 0.112, 0.05, (x + dx, y + dy, z + dz - 0.03), segs=10, bevel=0.0, m=k.cream),
            sphere(f"BeaniePom{i}", 0.045, (x + dx, y + dy, z + dz + 0.1), m=k.cream, segs=6, rings=4),
        ]
    # Goggle stand.
    x = 0.12
    p += [
        cyl("StandFoot", 0.12, 0.03, (x, y, z + 0.015), segs=10, bevel=0.0, m=k.dark),
        cyl("StandPost", 0.02, 0.5, (x, y, z + 0.27), segs=6, bevel=0.0, m=k.dark),
        box("StandBar", (0.5, 0.03, 0.03), (x, y, z + 0.5), bevel=0.0, m=k.dark),
    ]
    p += goggles("StandGogA", k, k.lens[0], (x - 0.16, y - 0.04, z + 0.35))
    p += goggles("StandGogB", k, k.lens[1], (x + 0.16, y - 0.04, z + 0.35))
    p += helmet("StandHelmet", k, k.g(5), k.lens[1], (x, y - 0.02, z + 0.66), scale=0.85)
    # Hot-cocoa urn, drip tray and mugs.
    x = 1.3
    p += [
        cyl("UrnFoot", 0.21, 0.05, (x, y + 0.05, z + 0.025), segs=16, bevel=0.015, m=k.charcoal),
        cyl("UrnBody", 0.19, 0.5, (x, y + 0.05, z + 0.3), segs=16, bevel=0.03, m=k.steel),
        cyl("UrnBand", 0.196, 0.15, (x, y + 0.05, z + 0.33), segs=16, bevel=0.0, m=k.g(0)),
        text("UrnLabel", "COCOA", 0.075, 0.012, (x, y - 0.15, z + 0.325), m=k.cream),
        cyl("UrnLid", 0.17, 0.07, (x, y + 0.05, z + 0.585), segs=16, bevel=0.02, m=k.steel, radius_top=0.12),
        sphere("UrnKnob", 0.04, (x, y + 0.05, z + 0.64), m=k.charcoal, segs=8, rings=5),
        box("UrnTap", (0.06, 0.12, 0.05), (x, y - 0.17, z + 0.12), bevel=0.015, m=k.steel),
        box("UrnTapLever", (0.025, 0.025, 0.09), (x, y - 0.21, z + 0.18), bevel=0.0, m=k.charcoal),
        box("DripTray", (0.18, 0.13, 0.02), (x, y - 0.22, z + 0.01), bevel=0.005, m=k.charcoal),
    ]
    for i, (dx, dy, ci) in enumerate(((0.62, -0.08, 0), (0.78, 0.08, 1), (0.82, -0.12, 2), (0.66, 0.1, 4), (1.6, -0.14, 3))):
        p += mug(f"Mug{i}", k, k.g(ci), (dx, y + dy, z), cocoa=i % 2 == 0)
    p += mug("MugStackA", k, k.g(5), (0.62, y - 0.08, z + 0.115), cocoa=False)
    # Mittens pinned to the east post.
    for i, (dx, ry) in enumerate(((1.92, 12), (2.15, -10))):
        hand = k.g(5 if i else 1)
        p += xform([
            box(f"Mitten{i}", (0.13, 0.05, 0.2), (0, 0, 0), bevel=0.05, segs=1, m=hand),
            sphere(f"MittenThumb{i}", 0.04, (0.07, 0, 0.02), scale=(1, 0.8, 1.4), m=hand, segs=6, rings=4),
            fbox_(f"MittenCuff{i}", (0.14, 0.055, 0.05), (0, 0, -0.08), k.cream),
            fbox_(f"MittenPeg{i}", (0.03, 0.06, 0.07), (0, 0.01, 0.1), k.timber),
        ], (dx, -HD - 0.18, 2.2), (0, math.radians(ry), 0))
    # Stickers on the counter front.
    fy = -HD - 0.16
    p += [
        star("StickerStar", 0.15, 0.02, (-1.65, fy, 1.08), m=k.g(2)),
        disc_v("StickerDotA", 0.14, (-1.1, fy, 0.78), k.g(0)),
        disc_v("StickerDotAIn", 0.08, (-1.1, fy - 0.012, 0.78), k.cream),
        star("StickerFlake", 0.17, 0.02, (-0.55, fy, 1.18), m=k.g(1), inner=0.06),
        prism("StickerPeak", [(-0.2, -0.12), (0.2, -0.12), (0.0, 0.16)], 0.02, (0.05, fy, 0.82), m=k.g(3)),
        prism("StickerPeakCap", [(-0.07, 0.07), (0.07, 0.07), (0.0, 0.16)], 0.02, (0.05, fy - 0.012, 0.82), m=k.cream),
        disc_v("StickerDotB", 0.12, (0.6, fy, 1.18), k.g(4)),
        star("StickerStarB", 0.13, 0.02, (1.05, fy, 0.72), m=k.g(5)),
        prism("StickerBolt", [(-0.03, 0.15), (-0.11, -0.01), (-0.01, -0.01), (-0.06, -0.16), (0.1, 0.03), (0.0, 0.03), (0.05, 0.15)],
              0.02, (1.65, fy, 1.12), m=k.g(2)),
        box("StickerPill", (0.42, 0.02, 0.14), (-0.25, fy, 0.55), bevel=0.0, m=k.g(5)),
        box("StickerPillIn", (0.32, 0.02, 0.04), (-0.25, fy - 0.012, 0.55), bevel=0.0, m=k.cream),
    ]
    return p


def bunting(k):
    """Pennant bunting across the fascia and warm bulbs under the front eave."""
    p = []
    n = 13
    a, b = Vector((-HW - 0.05, -HD - 0.22, 3.43)), Vector((HW + 0.05, -HD - 0.22, 3.43))
    pts = []
    for i in range(n + 1):
        t = i / n
        q = a.lerp(b, t)
        q.z -= 0.09 * math.sin(math.pi * t)
        pts.append(q)
    p.append(tube("BuntingCord", pts, 0.012, m=k.charcoal, segs=4))
    for i in range(n):
        q = (pts[i] + pts[i + 1]) * 0.5
        p.append(prism(f"Pennant{i}", [(-0.13, 0.0), (0.13, 0.0), (0.0, -0.28)], 0.02, (q.x, q.y, q.z), m=k.g(i)))
    ea, eb = Vector((-HW - 0.45, -HD - 0.72, 3.42)), Vector((HW + 0.45, -HD - 0.72, 3.42))
    p.append(tube("EaveCord", [ea, (ea + eb) * 0.5 + Vector((0, 0, -0.05)), eb], 0.012, m=k.charcoal, segs=4))
    for i in range(11):
        q = ea.lerp(eb, i / 10)
        q.z -= 0.05 * math.sin(math.pi * i / 10) + 0.06
        p.append(bulb(f"EaveBulb{i:02d}", 0.06, tuple(q), k.amber))
    return p


def west_wall(k):
    """Snowboards leaning on the west wall under a piste map."""
    p = []
    for i in range(4):
        y = -1.45 + i * 0.47
        top_z = 1.42 + (i % 2) * 0.1
        p += snowboard(f"Board{i}", k, k.g(i * 2 + 5), k.cream if i % 2 else k.charcoal,
                       (-HW - 0.68, y, 0.03), (-HW - 0.2, y + 0.04, top_z), (-1, 0, 0))
    # Trail map facing -X.
    m = []
    m += [
        box("MapFrame", (1.25, 0.07, 0.92), (0, 0.02, 0), bevel=0.03, m=k.dark),
        box("MapSky", (1.13, 0.04, 0.8), (0, -0.01, 0), bevel=0.0, m=k.g(1)),
        prism("MapPeak", [(-0.55, -0.38), (0.55, -0.38), (0.12, 0.33), (-0.08, 0.15)], 0.03, (0, -0.04, 0), m=k.cream),
        prism("MapPeakShade", [(0.12, 0.33), (0.55, -0.38), (0.2, -0.38)], 0.03, (0, -0.05, 0), m=k.snow),
        fbox_("MapRunGreen", (0.04, 0.02, 0.5), (-0.28, -0.07, -0.08), k.g(4), rot=rad(0, -28, 0)),
        fbox_("MapRunBlue", (0.04, 0.02, 0.6), (0.02, -0.07, -0.05), k.navy, rot=rad(0, 12, 0)),
        fbox_("MapRunBlack", (0.04, 0.02, 0.5), (0.25, -0.07, -0.1), k.charcoal, rot=rad(0, 35, 0)),
        disc_v("MapYouAreHere", 0.035, (-0.4, -0.08, -0.3), k.g(0)),
        box("MapCap", (1.35, 0.16, 0.06), (0, -0.03, 0.49), bevel=0.02, m=k.dark),
    ]
    m += snow_cap("MapSnow", (1.3, 0.14, 0.05), (0, -0.03, 0.52), drips=2, seed=6)
    p += place(m, (-HW - 0.2, -0.75, 2.42), rot_z=-math.pi / 2)
    return p


def east_rack(k):
    """Free-standing ski rack along the east wall."""
    x0 = HW + 0.68
    p = []
    for i, y in enumerate((-1.15, 1.15)):
        p += [
            strut(f"RackLeg{i}A", (x0 + 0.32, y, 0.0), (x0, y, 1.38), (0.1, 0.1), k.timber, bevel=0.025, segs=1),
            strut(f"RackLeg{i}B", (x0 - 0.32, y, 0.0), (x0, y, 1.38), (0.1, 0.1), k.timber, bevel=0.025, segs=1),
        ]
    p += [
        box("RackTop", (0.14, 2.5, 0.12), (x0, 0, 1.38), bevel=0.03, m=k.timber),
        box("RackLowO", (0.08, 2.4, 0.08), (x0 + 0.24, 0, 0.32), bevel=0.02, m=k.dark),
    ]
    p += snow_cap("RackSnow", (0.18, 2.4, 0.07), (x0, 0, 1.44), drips=4, seed=12)
    for i in range(5):
        y = -0.88 + i * 0.44
        p += ski_pair(f"RackSki{i}", k, k.g(i * 5 + 1), (x0 + 0.42, y, 0.02), (x0 + 0.08, y + 0.02, 1.78), (1, 0, 0))
    # Poles hooked over the top rail at the north end.
    for i in range(3):
        y = 1.0 + i * 0.07
        p.append(cyl(f"RackPole{i}", 0.015, 1.25, (x0 + 0.16, y, 0.72), rot=rad(0, -10, 0), segs=5, bevel=0.0, m=k.steel))
    return p


def front_props(k):
    """The snowman with the pole barrel (west corner), cell crates (east corner) and
    the A-frame chalkboard."""
    p = []
    # Snowman in a helmet, waving a pole.
    s = [
        sphere("ManBase", 0.44, (0, 0, 0.4), scale=(1, 1, 0.92), m=k.snow, segs=14, rings=9),
        sphere("ManMid", 0.32, (0, 0, 0.92), m=k.snow, segs=12, rings=8),
        sphere("ManHead", 0.24, (0, 0, 1.32), m=k.snow, segs=12, rings=8),
        cyl("ManNose", 0.05, 0.24, (0, -0.32, 1.3), rot=rad(90, 0, 0), segs=8, bevel=0.0, m=mat("FrostCarrot", "#ff8a2a", rough=0.6), radius_top=0.002),
        torus("ManScarf", 0.22, 0.06, (0, 0, 1.12), m=k.g(0), major_segs=16, minor_segs=5),
        box("ManScarfTail", (0.12, 0.05, 0.34), (0.12, -0.25, 0.96), rot=rad(10, 0, 15), bevel=0.02, m=k.g(0)),
    ]
    for i, x in enumerate((-0.08, 0.08)):
        s.append(sphere(f"ManEye{i}", 0.03, (x, -0.22, 1.36), m=k.charcoal, segs=6, rings=4))
    for i in range(3):
        s.append(sphere(f"ManButton{i}", 0.035, (0, -0.31 + i * 0.01, 1.0 - i * 0.14), m=k.charcoal, segs=6, rings=4))
    s += helmet("ManHelmet", k, k.g(1), k.lens[0], (0, 0.0, 1.47), scale=1.25)
    s.append(tube("ManArmL", [(-0.28, 0, 0.98), (-0.55, -0.05, 1.12), (-0.68, -0.05, 1.3)], 0.025, m=k.dark, segs=5))
    s.append(tube("ManArmR", [(0.28, 0, 0.98), (0.52, -0.08, 0.92), (0.62, -0.1, 0.86)], 0.025, m=k.dark, segs=5))
    s.append(cyl("ManPole", 0.016, 1.3, (0.64, -0.1, 0.62), rot=rad(0, 6, 0), segs=6, bevel=0.0, m=k.steel))
    s.append(cyl("ManPoleGrip", 0.028, 0.16, (0.67, -0.1, 1.24), rot=rad(0, 6, 0), segs=8, bevel=0.0, m=k.g(3)))
    s.append(cyl("ManPoleBasket", 0.07, 0.015, (0.62, -0.1, 0.12), segs=10, bevel=0.0, m=k.charcoal))
    p += place(s, (-2.62, -2.68, 0.0), rot_z=math.radians(-12))
    # Pole barrel beside him.
    bx, by = -2.95, -1.95
    p += [
        cyl("Barrel", 0.24, 0.62, (bx, by, 0.31), segs=12, bevel=0.03, m=k.timber),
        cyl("BarrelHoopA", 0.25, 0.05, (bx, by, 0.12), segs=12, bevel=0.0, m=k.charcoal),
        cyl("BarrelHoopB", 0.25, 0.05, (bx, by, 0.5), segs=12, bevel=0.0, m=k.charcoal),
        cyl("BarrelFill", 0.21, 0.03, (bx, by, 0.6), segs=12, bevel=0.0, m=k.snow),
    ]
    rng = random.Random(4)
    for i in range(6):
        a = math.tau * i / 6 + 0.3
        base = Vector((bx + math.cos(a) * 0.08, by + math.sin(a) * 0.08, 0.3))
        top = Vector((bx + math.cos(a) * 0.3, by + math.sin(a) * 0.3, 1.32 + rng.uniform(-0.06, 0.06)))
        p.append(tube(f"BarrelPole{i}", [base, top], 0.015, m=k.steel, segs=5))
        p.append(cyl(f"BarrelGrip{i}", 0.028, 0.15, tuple(top), segs=6, bevel=0.0, m=k.g(i)))
    # Energy-cell crates (east corner).
    c = [
        box("CrateA", (0.78, 0.6, 0.5), (0, 0, 0.25), bevel=0.04, m=k.light_wood),
        fbox_("CrateABand", (0.8, 0.62, 0.07), (0, 0, 0.33), k.dark),
        fbox_("CrateAHole", (0.66, 0.48, 0.02), (0, 0, 0.5), k.charcoal),
        prism("CrateABolt", [(-0.03, 0.15), (-0.11, -0.01), (-0.01, -0.01), (-0.06, -0.16), (0.1, 0.03), (0.0, 0.03), (0.05, 0.15)],
              0.02, (0, -0.31, 0.18), m=k.g(2)),
        box("CrateB", (0.56, 0.5, 0.42), (0.62, 0.32, 0.21), rot=rad(0, 0, 14), bevel=0.04, m=k.light_wood),
        fbox_("CrateBBand", (0.58, 0.52, 0.06), (0.62, 0.32, 0.28), k.dark, rot=rad(0, 0, 14)),
        box("CrateC", (0.46, 0.4, 0.32), (0.58, 0.3, 0.58), rot=rad(0, 0, -6), bevel=0.035, m=k.light_wood),
    ]
    c += snow_cap("CrateCSnow", (0.42, 0.36, 0.06), (0.58, 0.3, 0.74), rot=rad(0, 0, -6), drips=2, seed=9)
    for i in range(6):
        cx, cy = -0.22 + (i % 3) * 0.22, -0.11 + (i // 3) * 0.22
        c += [
            cyl(f"Cell{i}", 0.07, 0.3, (cx, cy, 0.58), segs=10, bevel=0.0, m=k.cyan),
            cyl(f"CellCap{i}", 0.075, 0.05, (cx, cy, 0.75), segs=10, bevel=0.0, m=k.steel),
        ]
    p += place(c, (2.62, -2.55, 0.0), rot_z=math.radians(12))
    # A-frame chalkboard: two boards leaning together, chalk on the front one.
    ch = []
    tilt = math.radians(13)
    for side, sy in (("F", -1), ("B", 1)):
        board = [
            box(f"Chalk{side}Frame", (0.82, 0.05, 1.08), (0, 0, 0), bevel=0.025, m=k.timber),
            box(f"Chalk{side}Face", (0.7, 0.03, 0.94), (0, sy * 0.02, 0), bevel=0.0, m=k.chalk),
        ]
        ch += xform(board, (0, sy * 0.13, 0.53), (sy * tilt, 0, 0))
    up = Vector((0, math.sin(tilt), math.cos(tilt)))
    out = Vector((0, -math.cos(tilt), math.sin(tilt)))
    centre = Vector((0, -0.13, 0.53))

    def on_board(u, v):
        return tuple(centre + Vector((u, 0, 0)) + up * v + out * 0.045)

    ch += [
        text("ChalkText", "HOT COCOA\nCELLS\nSWAPS", 0.1, 0.008, on_board(-0.06, 0.2), rot=(-tilt, 0, 0), m=k.cream),
        prism("ChalkBolt", [(-0.03, 0.12), (-0.09, -0.01), (-0.01, -0.01), (-0.05, -0.12), (0.08, 0.02), (0.0, 0.02), (0.04, 0.12)],
              0.01, on_board(0.25, 0.08), rot=(-tilt, 0, 0), m=k.g(2)),
        star("ChalkFlake", 0.09, 0.01, on_board(0.22, -0.18), rot=(-tilt, 0, 0), m=k.g(1), inner=0.03),
        star("ChalkStar", 0.07, 0.01, on_board(-0.24, -0.2), rot=(-tilt, 0, 0), m=k.g(2)),
        fbox_("ChalkLine", (0.5, 0.01, 0.015), on_board(0.0, -0.3), k.g(5), rot=(-tilt, 0, 0)),
    ]
    p += place(ch, (1.45, -3.05, 0.0), rot_z=math.radians(-14))
    return p


def back_props(k):
    p = logs_pile("Firewood", k, (-1.1, HD + 0.75, 0.0))
    # Sled stood against the back wall: lengthwise slats on red runners that curl over at the top.
    sled = [box("SledBar0", (0.56, 0.06, 0.07), (0, 0.0, 0.3), bevel=0.015, segs=1, m=k.dark),
            box("SledBar1", (0.56, 0.06, 0.07), (0, 0.0, 1.05), bevel=0.015, segs=1, m=k.dark)]
    for i, x in enumerate((-0.17, 0.0, 0.17)):
        sled.append(box(f"SledSlat{i}", (0.13, 0.04, 1.1), (x, 0.05, 0.7), bevel=0.015, segs=1, m=k.light_wood))
    for i, x in enumerate((-0.26, 0.26)):
        sled.append(tube(f"SledRunner{i}", [(x, -0.06, 0.08), (x, -0.06, 1.2), (x, 0.0, 1.36), (x, 0.1, 1.38), (x, 0.16, 1.28)],
                         0.03, m=k.g(0), segs=6))
    p += xform(sled, (1.2, HD + 0.62, 0.0), rad(18, 0, 0))
    # Drifts against the plinth.
    for i, (x, y, sx, rz) in enumerate(((-2.45, 2.25, 1.2, 0.4), (2.5, 2.2, 1.0, -0.5), (0.4, 2.3, 1.4, 0.0),
                                         (-2.8, -0.9, 0.9, 1.57), (2.75, 1.65, 0.8, 1.57), (-0.6, -2.3, 0.8, 0.0))):
        p.append(sphere(f"Drift{i}", 0.5, (x, y, 0.04), scale=(sx * 1.4, 0.7, 0.42), rot=(0, 0, rz), m=k.snow, segs=10, rings=6))
    return p


def shutter(k):
    """The service shutter in its closed pose: a timber panel hanging from the hinge.
    Built around the hinge; the export object is rotated to SHUTTER_CLOSED."""
    L = SHUTTER_LEN
    p = [
        box("ShutterPanel", (3.9, 0.08, L), (0, -0.04, -L / 2), bevel=0.03, m=k.red_dark),
        box("ShutterEdge", (3.94, 0.1, 0.12), (0, -0.05, -L + 0.06), bevel=0.03, m=k.cream),
    ]
    for i in range(3):
        p.append(fbox_(f"ShutterSlat{i}", (3.86, 0.02, 0.04), (0, -0.085, -0.3 - i * 0.42), k.red))
    for i in range(4):
        p.append(fbox_(f"ShutterUnder{i}", (0.42, 0.02, L - 0.1), (-1.5 + i * 1.0, 0.005, -L / 2), k.cream))
    # Roundel with a mountain and a snowflake.
    p += [
        cyl("ShutterBadge", 0.42, 0.04, (0, -0.1, -0.78), rot=rad(90, 0, 0), segs=24, bevel=0.0, m=k.cream),
        prism("ShutterPeak", [(-0.3, -0.18), (0.3, -0.18), (0.05, 0.22), (-0.05, 0.12)], 0.03, (0, -0.125, -0.82), m=k.g(1)),
        prism("ShutterPeakCap", [(-0.07, 0.1), (0.1, 0.11), (0.05, 0.22)], 0.03, (0, -0.14, -0.82), m=k.snow),
        star("ShutterFlakeL", 0.2, 0.03, (-1.3, -0.11, -0.78), m=k.cream, inner=0.07),
        star("ShutterFlakeR", 0.2, 0.03, (1.3, -0.11, -0.78), m=k.cream, inner=0.07),
    ]
    ob = merge("Shutter", p, pivot=(0, 0, 0))
    ob.location = HINGE
    ob.rotation_euler = (math.radians(SHUTTER_CLOSED), 0, 0)
    return ob


def open_dressing(k):
    """Neon OPEN sign hung in the window, a light strip under the lintel and the
    awning stays (only shown while the station is open)."""
    neon = fglow("FrostNeonOpen", "#ff4f6a", 3.4)
    p = [
        box("OpenBack", (0.86, 0.05, 0.36), (-1.0, -1.93, 2.6), bevel=0.03, m=k.navy),
        text("OpenText", "OPEN", 0.24, 0.03, (-1.0, -1.97, 2.59), m=neon),
        fbox_("OpenRimT", (0.8, 0.02, 0.025), (-1.0, -1.965, 2.75), k.cyan),
        fbox_("OpenRimB", (0.8, 0.02, 0.025), (-1.0, -1.965, 2.45), k.cyan),
        cyl("OpenChainL", 0.008, 0.14, (-1.3, -1.93, 2.84), segs=4, bevel=0.0, m=k.charcoal),
        cyl("OpenChainR", 0.008, 0.14, (-0.7, -1.93, 2.84), segs=4, bevel=0.0, m=k.charcoal),
        fbox_("WindowLight", (3.5, 0.04, 0.04), (0, -1.72, 2.86), k.amber),
    ]
    # Stays from the counter ends up to the raised awning.
    a = math.radians(SHUTTER_OPEN)
    d = 1.38
    ey, ez = HINGE[1] + d * math.sin(a), HINGE[2] - d * math.cos(a) - 0.05
    for i, sx in enumerate((-1, 1)):
        p.append(tube(f"Stay{i}", [(sx * 1.75, -HD - 0.45, COUNTER_TOP), (sx * 1.75, ey, ez)], 0.03, m=k.dark, segs=6))
    return merge("OpenDressing", p)


def closed_sign(k):
    """A CLOSED plank nailed to the closed shutter."""
    a = math.radians(SHUTTER_CLOSED)
    d = 0.78
    # Point on the shutter face d below the hinge, pushed out along its normal.
    ny, nz = -math.cos(a), -math.sin(a)
    cy = HINGE[1] - 0.08 * math.cos(a) + d * math.sin(a) + ny * 0.03
    cz = HINGE[2] - 0.08 * math.sin(a) - d * math.cos(a) + nz * 0.03
    p = [
        box("ClosedPlank", (1.15, 0.05, 0.36), (0, cy, cz), rot=(a, 0, 0), bevel=0.02, m=k.cream),
        text("ClosedText", "CLOSED", 0.22, 0.02, (0, cy + ny * 0.035, cz + nz * 0.035 - 0.01), rot=(a, 0, 0), m=k.red_dark),
    ]
    return merge("ClosedSign", p)


def build_station():
    reset_scene()
    k = Kit()
    parts = shell(k) + interior(k) + counter_goods(k) + bunting(k) + west_wall(k) + east_rack(k) + front_props(k) + back_props(k)
    station = merge("Station", parts)
    save("frost_station", [station, shutter(k), open_dressing(k), closed_sign(k)])


if __name__ == "__main__":
    build_station()
