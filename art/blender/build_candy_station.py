"""The loadout station and the exit portal frame for Candy Works.

    candy_station.glb    origin = centre of the stall's footprint; counter faces -Y.
        Station        the Sweet Shop: a pink-and-white striped candy stall with a
                       mint counter, jars of gumballs and bonbons, a till, a scale,
                       cotton-candy cones, a SWEET SHOP marquee with bulbs, a giant
                       swirl lollipop on the roof, energy-cell crates and sacks.
        Shutter        the striped service shutter, pivot on its hinge, exported
                       closed; scenes/props/candy_station.tscn swings it up into
                       an awning while the station is open.
        OpenDressing   the neon OPEN sign and the awning stays (shown while open).
        ClosedSign     the CLOSED plaque on the shutter (shown while closed).
    candy_portal_arch.glb  the Golden Wrapper: the shared portal doorway (1.45 m
                       half-width, spring 2.25 m, top 3.75 m) framed by two
                       striped candy pillars and a giant wrapped-sweet arch with
                       twisted ends, gumdrops and an EXIT plaque. Faces -Y.

    python art/blender/build_candy_station.py [station] [portal]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from candy_common import *  # noqa: F401,F403
from mathutils import Vector  # noqa: E402

HW, HD, WALL = 2.4, 1.9, 3.0
HINGE = (0.0, -2.1, 2.9)
SHUTTER_LEN = 1.55
SHUTTER_CLOSED = -18.0
SHUTTER_OPEN = -70.0
COUNTER_TOP = 1.15


def shell():
    pink, white, mint, mint_d = cmat("Pink", rough=0.45), cmat("White", rough=0.4), cmat("Mint", rough=0.45), cmat("MintDeep", rough=0.45)
    butter, choc = cmat("Butter", rough=0.45), cmat("ChocDark", rough=0.6)
    p = [box("Floor", (HW * 2 + 0.4, HD * 2 + 0.4, 0.3), (0, 0, 0.15), bevel=0.06, m=choc)]
    # Striped walls: vertical boards alternating pink and white (back and sides).
    n = 12
    for i in range(n):
        x = -HW + (i + 0.5) * HW * 2 / n
        p.append(box(f"BackBoard{i}", (HW * 2 / n + 0.005, 0.14, WALL), (x, HD - 0.07, 0.3 + WALL / 2), bevel=0.02, m=pink if i % 2 == 0 else white))
    for s in (-1, 1):
        for i in range(8):
            y = -HD + (i + 0.5) * HD * 2 / 8
            p.append(box(f"Side{s}{i}", (0.14, HD * 2 / 8 + 0.005, WALL), (s * (HW - 0.07), y, 0.3 + WALL / 2), bevel=0.02,
                         m=pink if i % 2 == 0 else white))
    # Front: counter base and the window frame (open window above the counter).
    p += [
        box("CounterBase", (HW * 2, 0.5, COUNTER_TOP - 0.3), (0, -HD + 0.25, 0.3 + (COUNTER_TOP - 0.3) / 2), bevel=0.06, m=mint),
        box("CounterTop", (HW * 2 + 0.3, 0.8, 0.1), (0, -HD + 0.2, COUNTER_TOP + 0.05), bevel=0.04, m=butter),
        box("Lintel", (HW * 2, 0.3, 0.5), (0, -HD + 0.15, 0.3 + WALL - 0.25), bevel=0.05, m=pink),
        box("PostL", (0.3, 0.3, WALL), (-HW + 0.15, -HD + 0.15, 0.3 + WALL / 2), bevel=0.05, m=white),
        box("PostR", (0.3, 0.3, WALL), (HW - 0.15, -HD + 0.15, 0.3 + WALL / 2), bevel=0.05, m=white),
        box("Kick", (HW * 2 + 0.1, 0.1, 0.25), (0, -HD - 0.03, 0.42), bevel=0.02, m=mint_d),
    ]
    # Polka dots on the counter front.
    for i in range(7):
        p.append(cyl(f"Dot{i}", 0.12, 0.03, (-HW + 0.5 + i * 0.63, -HD - 0.01, 0.75 + 0.12 * (i % 2)), rot=rad(90, 0, 0), segs=14, bevel=0.0,
                     m=(cmat("Lemon", rough=0.4), white, cmat("Lilac", rough=0.4))[i % 3]))
    # Roof: a scalloped slab with a frosting lip and gumdrops.
    top = 0.3 + WALL
    p += [
        box("Roof", (HW * 2 + 0.7, HD * 2 + 0.7, 0.35), (0, 0, top + 0.17), bevel=0.12, m=choc),
        box("Frosting", (HW * 2 + 0.6, HD * 2 + 0.6, 0.18), (0, 0, top + 0.42), bevel=0.08, m=cmat("PinkPale", rough=0.4)),
    ]
    p += icing_drips("RoofDripF", (-HW - 0.35, -HD - 0.36, top + 0.32), (HW + 0.35, -HD - 0.36, top + 0.32), 12, 0.35, seed=2,
                     m=cmat("PinkPale", rough=0.4))
    gum = gumball_mats()
    for i in range(8):
        x = -HW + 0.1 + i * (HW * 2 - 0.2) / 7
        p.append(sphere(f"Gumdrop{i}", 0.18, (x, -HD - 0.2, top + 0.58), scale=(1, 1, 0.85), m=gum[i % len(gum)], segs=12, rings=7))
    return p


def marquee():
    """SWEET SHOP marquee on the roof and the giant lollipop behind it."""
    top = 0.3 + WALL + 0.5
    butter, pinkd, pink = cmat("Butter", rough=0.45), cmat("PinkDeep", rough=0.4), cmat("Pink", rough=0.4)
    bulb_m = cglow("CandyBulbWarm", "#ffe9a8", 3.0)
    p = [
        box("Marquee", (4.0, 0.25, 1.0), (0, -HD + 0.6, top + 0.55), bevel=0.12, m=butter),
        box("MarqueeEdge", (4.2, 0.2, 1.2), (0, -HD + 0.66, top + 0.55), bevel=0.12, m=pink),
        text("MarqueeText", "SWEET SHOP", 0.48, 0.06, (0, -HD + 0.44, top + 0.53), m=pinkd),
    ]
    for i in range(14):
        x = -1.9 + i * 3.8 / 13
        p.append(bulb(f"MarqueeBulb{i:02d}", 0.06, (x, -HD + 0.45, top + 1.08), bulb_m))
    p += lollipop("Pop", 1.15, 1.1, (0, HD - 0.9, top - 0.05), cmat("Pink", rough=0.35), cmat("White", rough=0.35))
    return p


def counter_goods():
    """Jars, a till, a scale and cotton candy on the counter; shelves inside."""
    glass = glass_mat("CandyJarGlass", "#eaf8ff", alpha=0.3, emit=0.1)
    gum = gumball_mats()
    lilac, cream, choc = cmat("Lilac", rough=0.45), cmat("Cream"), cmat("ChocDark", rough=0.6)
    gold = cmat("Gold", rough=0.3, metal=0.6)
    y = -HD + 0.2
    z = COUNTER_TOP + 0.1
    p = []
    rng = random.Random(3)
    for k, x in enumerate((-1.7, -1.15, 1.25)):
        p.append(cyl(f"Jar{k}", 0.24, 0.55, (x, y, z + 0.28), segs=18, bevel=0.04, m=glass))
        p.append(cyl(f"JarLid{k}", 0.26, 0.1, (x, y, z + 0.6), segs=18, bevel=0.03, m=(cmat("Pink", rough=0.4), cmat("Mint", rough=0.4), lilac)[k]))
        for i in range(9):
            a, r = rng.uniform(0, math.tau), rng.uniform(0, 0.14)
            p.append(ico(f"JarBall{k}{i}", 0.075, (x + math.cos(a) * r, y + math.sin(a) * r, z + 0.09 + (i // 3) * 0.13), gum[(i + k) % len(gum)]))
    p += [
        box("Till", (0.55, 0.45, 0.32), (0.35, y + 0.05, z + 0.16), bevel=0.06, m=lilac),
        box("TillTop", (0.5, 0.3, 0.12), (0.35, y + 0.12, z + 0.38), rot=rad(-20, 0, 0), bevel=0.03, m=cream),
        cyl("ScalePan", 0.22, 0.04, (-0.45, y, z + 0.3), segs=18, bevel=0.01, m=gold),
        box("ScaleBody", (0.3, 0.3, 0.26), (-0.45, y, z + 0.13), bevel=0.04, m=cmat("Red", rough=0.4)),
    ]
    floss = mat("CandyFloss", "#ffb6d9", rough=0.9)
    for i, x in enumerate((1.75, 1.95)):
        p.append(cyl(f"Cone{i}", 0.05, 0.35, (x, y + 0.1 * i, z + 0.17), segs=8, bevel=0.0, m=cream, radius_top=0.02))
        p.append(sphere(f"Floss{i}", 0.2, (x, y + 0.1 * i, z + 0.48), scale=(1, 1, 1.15), m=floss, segs=12, rings=8))
    # Back shelves with candy boxes.
    for j, sz in enumerate((1.6, 2.3)):
        p.append(box(f"Shelf{j}", (HW * 2 - 0.6, 0.45, 0.06), (0, HD - 0.4, sz), bevel=0.02, m=cream))
        for i in range(6):
            p.append(box(f"ShelfBox{j}{i}", (0.42, 0.32, 0.38), (-1.6 + i * 0.64, HD - 0.4, sz + 0.22), bevel=0.03,
                         m=(cmat("Pink", rough=0.5), cmat("Mint", rough=0.5), lilac, cmat("Butter", rough=0.5))[(i + j) % 4]))
    # Cell crates and sugar sacks around the stall (the energy top-up).
    cell = cglow("CandyCell", "#7ff0ff", 2.2)
    for i, (x, yy, r) in enumerate(((-HW - 0.55, -0.6, 10), (HW + 0.55, 0.4, -14))):
        p.append(box(f"CellCrate{i}", (0.8, 0.8, 0.6), (x, yy, 0.3), rot=rad(0, 0, r), bevel=0.05, m=cmat("Ginger", rough=0.7)))
        for k in range(3):
            p.append(cyl(f"Cell{i}{k}", 0.08, 0.3, (x - 0.2 + k * 0.2, yy, 0.72), segs=10, bevel=0.02, m=cell))
    p += cane("CaneL", 0.07, 2.2, (-HW - 0.25, -HD + 0.1, 0.0), hook=0.18, rot_z=math.pi)
    p += cane("CaneR", 0.07, 2.2, (HW + 0.25, -HD + 0.1, 0.0), hook=0.18, rot_z=0.0)
    return p


def shutter():
    L = SHUTTER_LEN
    pink, white = cmat("Pink", rough=0.45), cmat("White", rough=0.4)
    p = []
    for i in range(10):
        x = -2.1 + (i + 0.5) * 4.2 / 10
        p.append(box(f"ShutterStripe{i}", (0.42, 0.08, L), (x, -0.04, -L / 2), bevel=0.02, m=pink if i % 2 == 0 else white))
    p.append(box("ShutterEdge", (4.26, 0.1, 0.12), (0, -0.05, -L + 0.06), bevel=0.03, m=cmat("Butter", rough=0.45)))
    for i in range(10):
        x = -2.1 + (i + 0.5) * 4.2 / 10
        p.append(sphere(f"ShutterScallop{i}", 0.21, (x, -0.05, -L - 0.02), scale=(1, 0.3, 0.6), m=pink if i % 2 else white, segs=10, rings=5))
    ob = merge("Shutter", p, pivot=(0, 0, 0))
    ob.location = HINGE
    ob.rotation_euler = (math.radians(SHUTTER_CLOSED), 0, 0)
    return ob


def open_dressing():
    neon = cglow("CandyNeonOpen", "#ff4f9a", 3.4)
    p = [
        box("OpenBack", (0.9, 0.05, 0.36), (-1.2, -HD + 0.35, 2.45), bevel=0.03, m=cmat("ChocDark", rough=0.6)),
        text("OpenText", "OPEN", 0.24, 0.03, (-1.2, -HD + 0.31, 2.44), m=neon),
    ]
    a = math.radians(SHUTTER_OPEN)
    d = 1.35
    ey, ez = HINGE[1] + d * math.sin(a), HINGE[2] - d * math.cos(a) - 0.05
    for i, sx in enumerate((-1, 1)):
        p.append(tube(f"Stay{i}", [(sx * 1.9, -HD - 0.15, COUNTER_TOP + 0.1), (sx * 1.9, ey, ez)], 0.03, m=cmat("Gold", rough=0.3, metal=0.6), segs=6))
    return merge("OpenDressing", p)


def closed_sign():
    a = math.radians(SHUTTER_CLOSED)
    d = 0.75
    ny, nz = -math.cos(a), -math.sin(a)
    cy = HINGE[1] - 0.08 * math.cos(a) + d * math.sin(a) + ny * 0.03
    cz = HINGE[2] - 0.08 * math.sin(a) - d * math.cos(a) + nz * 0.03
    p = [
        box("ClosedPlaque", (1.2, 0.05, 0.38), (0, cy, cz), rot=(a, 0, 0), bevel=0.04, m=cmat("Cream")),
        text("ClosedText", "CLOSED", 0.22, 0.02, (0, cy + ny * 0.035, cz + nz * 0.035 - 0.01), rot=(a, 0, 0), m=cmat("PinkDeep", rough=0.4)),
    ]
    return merge("ClosedSign", p)


def build_station():
    reset_scene()
    station = merge("Station", shell() + marquee() + counter_goods())
    save("candy_station", [station, shutter(), open_dressing(), closed_sign()])


# ---------------------------------------------------------------------------
# Exit portal: the Golden Wrapper
# ---------------------------------------------------------------------------

OPEN_W = 1.45
OPEN_SPRING = 2.25
OPEN_RISE = 1.5


def opening_outline(grow=0.05, base=-0.2, steps=24):
    w, r = OPEN_W + grow, OPEN_RISE + grow
    out = [(-w, base)]
    for i in range(steps + 1):
        a = math.pi - math.pi * i / steps
        out.append((math.cos(a) * w, OPEN_SPRING + math.sin(a) * r))
    out.append((w, base))
    return out


def build_portal():
    reset_scene()
    gold, gold_l = cmat("Gold", rough=0.3, metal=0.6), mat("CandyWrapperGold", "#ffe27a", rough=0.25, metal=0.5, emit=0.25)
    white, red, pink, mint = cmat("White", rough=0.35), cmat("Red", rough=0.35), cmat("Pink", rough=0.4), cmat("Mint", rough=0.4)
    choc = cmat("ChocDark", rough=0.6)
    gum = gumball_mats()
    p = []
    # Striped pillars (jambs) on chocolate plinths.
    for s in (-1, 1):
        x = s * 1.95
        p.append(box(f"Plinth{s}", (1.1, 1.0, 0.5), (x, 0, 0.25), bevel=0.08, m=choc))
        p += striped_post(f"Pillar{s}", 0.42, 3.1, (x, 0, 0.5), white, red, bands=9, segs=18)
        p.append(cyl(f"Cap{s}", 0.55, 0.3, (x, 0, 3.75), segs=20, bevel=0.08, m=gold))
        p.append(sphere(f"Drop{s}", 0.45, (x, 0, 4.15), scale=(1, 1, 0.85), m=mint if s < 0 else pink, segs=16, rings=8))
    # The wrapper arch: a fat golden band over the doorway with pleats.
    pts = []
    for i in range(25):
        a = math.pi - math.pi * i / 24
        pts.append((math.cos(a) * (OPEN_W + 0.5), 0.0, OPEN_SPRING + 0.35 + math.sin(a) * (OPEN_RISE + 0.45)))
    p.append(tube("Wrapper", pts, 0.42, m=gold_l, segs=14))
    for i in range(1, 24, 2):
        p.append(tube(f"Pleat{i}", [pts[i], pts[i + 1]], 0.45, m=gold, segs=14))
    # Twisted wrapper ends flaring out from the pillar caps.
    for s in (-1, 1):
        base = Vector((s * 2.3, 0, 4.0))
        for k in range(3):
            a = math.radians(30 + k * 25)
            tip = base + Vector((s * math.cos(a) * 1.2, 0, math.sin(a) * 0.8))
            p.append(cyl(f"Twist{s}{k}", 0.08, 1.2, tuple((base + tip) / 2), rot=(0, -s * (math.pi / 2 - a), 0), segs=10, bevel=0.0,
                         m=gold_l, radius_top=0.32))
    # Gumdrops studded round the arch.
    for i in range(9):
        a = math.pi - math.pi * (i + 0.5) / 9
        q = (math.cos(a) * (OPEN_W + 0.5), -0.42, OPEN_SPRING + 0.35 + math.sin(a) * (OPEN_RISE + 0.45))
        p.append(sphere(f"Stud{i}", 0.16, q, scale=(1, 0.7, 1), m=gum[i % len(gum)], segs=10, rings=6))
    # EXIT plaque on the keystone.
    top = OPEN_SPRING + 0.35 + OPEN_RISE + 0.45
    p += [box("Plaque", (1.5, 0.12, 0.55), (0, -0.48, top + 0.1), bevel=0.06, m=pink),
          text("PlaqueText", "EXIT", 0.34, 0.04, (0, -0.56, top + 0.08), m=white)]
    p.append(prism("Back", opening_outline(0.12, 0.0), 0.1, (0, 0.32, 0), m=mat("CandyPortalBack", "#2a1730", rough=0.9)))
    save("candy_portal_arch", [merge("PortalArch", p)])


ALL = {"station": build_station, "portal": build_portal}


if __name__ == "__main__":
    wanted = [a for a in sys.argv[1:] if a in ALL] or list(ALL)
    for key in wanted:
        ALL[key]()
