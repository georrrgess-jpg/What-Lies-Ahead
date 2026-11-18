"""Gold Rush Gulch loadout station and exit portal (World 12, Boomtown).

    gulch_station.glb      "Prospector Supply": a big covered supply wagon (bed 4.8 x 2.2)
                           with a sales window on its -Y side, a striped fly over the
                           counter and a gold-pan sign on the bonnet.
        Station        the wagon, goods and fly (static)
        Shutter        the side flap, pivot on its hinge at the bed rail, exported
                       closed (upright); the scene opens it to +90 about X (a counter)
        OpenDressing   the goods on the counter and the OPEN sign (open only)
        ClosedSign     "GONE PANNING" card on the flap (closed only)
    gulch_portal_arch.glb  the exit: the shared portal doorway framed as a gold-mine
                           shaft: square timbers, raked struts, a lintel with a gold
                           nugget crown, lanterns, rails and an EXIT board.

    python art/blender/build_gulch_station.py [station] [portal]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gulch_common import *  # noqa: F401,F403
from gulch_common import _finish, bmesh  # noqa: F401
import build_world_portals as wp  # noqa: E402

BED_L, BED_W = 4.8, 2.2
BED_Z0, BED_Z1 = 0.75, 1.5
WIN_Z0, WIN_Z1 = 1.5, 2.6
WIN_HALF = 1.5
HINGE = (0.0, -BED_W / 2 - 0.08, WIN_Z0)
BONNET_R = 1.25
BONNET_Z = 2.55


def half_tube_x(name, r, length, loc, m, segs=16):
    """Open half-cylinder shell along X (the bonnet), visible from both sides."""
    bm = bmesh.new()
    rows = []
    for x in (-length / 2, length / 2):
        rows.append([bm.verts.new((x, math.cos(math.pi * i / segs) * r, math.sin(math.pi * i / segs) * r)) for i in range(segs + 1)])
    for i in range(segs):
        f = bm.faces.new((rows[0][i], rows[0][i + 1], rows[1][i + 1], rows[1][i]))
        f.material_index = 0
    return double_sided(_finish(name, bm, m, loc, (0, 0, 0)))


def wheel(prefix, r, loc, rim, spoke, spokes=12):
    p = [torus(prefix + "Rim", r, 0.08, loc, rot=rad(90, 0, 0), m=rim, major_segs=28, minor_segs=6),
         cyl(prefix + "Hub", 0.16, 0.3, loc, rot=rad(90, 0, 0), segs=12, bevel=0.03, m=spoke)]
    for k in range(spokes):
        a = math.tau * k / spokes
        p.append(tube(f"{prefix}Spoke{k}", [loc, (loc[0] + math.cos(a) * r, loc[1], loc[2] + math.sin(a) * r)], 0.035, m=spoke, segs=5))
    return p


def wagon():
    wood, dark, light = gmat("Wood"), gmat("WoodDark"), gmat("WoodLight")
    red, gold, canvas = gmat("Red", rough=0.55), gmat("Gold", rough=0.3, metal=0.5), gmat("Canvas", rough=0.85)
    turq = gmat("Turq", rough=0.55)
    p = [box("Bed", (BED_L, BED_W, BED_Z1 - BED_Z0), (0, 0, (BED_Z0 + BED_Z1) / 2), bevel=0.06, m=red),
         box("BedRail", (BED_L + 0.1, BED_W + 0.1, 0.12), (0, 0, BED_Z1), bevel=0.03, m=gold)]
    for k in range(6):
        p.append(box(f"BedPlank{k}", (0.04, BED_W + 0.02, BED_Z1 - BED_Z0 - 0.1), (-BED_L / 2 + 0.4 + k * 0.8, 0, (BED_Z0 + BED_Z1) / 2), bevel=0.0, m=dark))
    for x, r in ((-1.65, 0.7), (1.55, 0.82)):
        for s in (-1, 1):
            p += wheel(f"W{x}{s}", r, (x, s * (BED_W / 2 + 0.12), r), red, dark)
    # Wooden box walls above the bed: back and ends full, the front framing the window.
    wall_h = WIN_Z1 - BED_Z1
    p += [box("BackWall", (BED_L, 0.12, wall_h), (0, BED_W / 2 - 0.06, BED_Z1 + wall_h / 2), bevel=0.02, m=light),
          box("EndL", (0.12, BED_W, wall_h), (-BED_L / 2 + 0.06, 0, BED_Z1 + wall_h / 2), bevel=0.02, m=light),
          box("EndR", (0.12, BED_W, wall_h), (BED_L / 2 - 0.06, 0, BED_Z1 + wall_h / 2), bevel=0.02, m=light),
          box("FrontL", (BED_L / 2 - WIN_HALF, 0.12, wall_h), (-(BED_L / 2 + WIN_HALF) / 2, -BED_W / 2 + 0.06, BED_Z1 + wall_h / 2), bevel=0.02, m=light),
          box("FrontR", (BED_L / 2 - WIN_HALF, 0.12, wall_h), ((BED_L / 2 + WIN_HALF) / 2, -BED_W / 2 + 0.06, BED_Z1 + wall_h / 2), bevel=0.02, m=light),
          box("Inside", (2 * WIN_HALF, 0.1, wall_h), (0, 0.3, BED_Z1 + wall_h / 2), bevel=0.0, m=dark),
          box("Counter", (2 * WIN_HALF + 0.2, 0.5, 0.08), (0, -BED_W / 2 + 0.3, WIN_Z0 + 0.02), bevel=0.02, m=dark)]
    # The bonnet on hoops, with a striped band and a rolled-up front skirt.
    p.append(half_tube_x("Bonnet", BONNET_R, BED_L - 0.2, (0, 0, BONNET_Z), canvas))
    for k in range(6):
        x = -BED_L / 2 + 0.2 + k * (BED_L - 0.4) / 5
        p.append(torus(f"Hoop{k}", BONNET_R + 0.03, 0.05, (x, 0, BONNET_Z), rot=rad(0, 90, 0), m=dark, major_segs=24, minor_segs=4,
                       arc=math.pi, start=0.0))
        p[-1].rotation_euler = rad(90, 0, 90)
    for k in range(5):
        a = math.pi * (0.3 + 0.1 * k)
        p.append(box(f"Stripe{k}", (BED_L - 0.25, 0.06, 0.18), (0, math.cos(a) * (BONNET_R + 0.02), BONNET_Z + math.sin(a) * (BONNET_R + 0.02)),
                     rot=(a, 0, 0), bevel=0.0, m=red if k % 2 == 0 else turq))
    p.append(cyl("Roll", 0.16, BED_L - 0.3, (0, -BONNET_R + 0.05, BONNET_Z + 0.05), rot=rad(0, 90, 0), segs=12, bevel=0.03, m=canvas))
    # The striped fly over the counter on two poles.
    for k in range(8):
        x = -2.1 + k * 0.6
        p.append(box(f"Fly{k}", (0.6, 1.8, 0.05), (x + 0.3, -BED_W / 2 - 0.85, 3.05), rot=(math.radians(-12), 0, 0), bevel=0.0,
                     m=gmat("Orange", rough=0.7) if k % 2 == 0 else gmat("Cream", rough=0.7)))
    for k in range(16):
        x = -2.1 + k * 0.3
        p.append(prism(f"Scallop{k}", [(-0.15, 0), (0.15, 0), (0, -0.2)], 0.03, (x + 0.15, -BED_W / 2 - 1.73, 2.86),
                       m=gmat("Orange", rough=0.7) if k % 2 == 0 else gmat("Cream", rough=0.7)))
    for s in (-1, 1):
        p.append(cyl(f"FlyPole{s}", 0.06, 2.9, (s * 2.15, -BED_W / 2 - 1.7, 1.45), segs=8, bevel=0.0, m=dark))
    # The sign on the bonnet: a gold pan with a nugget and lettering.
    p += [box("SignBoard", (3.6, 0.16, 0.6), (0, -0.2, BONNET_Z + BONNET_R + 0.55), bevel=0.05, m=gmat("RedDark", rough=0.5)),
          box("SignTrim", (3.8, 0.12, 0.74), (0, -0.16, BONNET_Z + BONNET_R + 0.55), bevel=0.04, m=gold),
          text("SignText", "PROSPECTOR SUPPLY", 0.3, 0.05, (0, -0.32, BONNET_Z + BONNET_R + 0.52), m=gmat("Cream", rough=0.5)),
          box("SignLegL", (0.1, 0.1, 0.7), (-1.2, -0.2, BONNET_Z + BONNET_R), bevel=0.0, m=dark),
          box("SignLegR", (0.1, 0.1, 0.7), (1.2, -0.2, BONNET_Z + BONNET_R), bevel=0.0, m=dark),
          cyl("Pan", 0.6, 0.12, (0, -0.25, BONNET_Z + BONNET_R + 1.45), rot=rad(90, 0, 0), segs=24, bevel=0.03, m=gmat("IronLight", rough=0.4)),
          sphere("PanNugget", 0.3, (0, -0.35, BONNET_Z + BONNET_R + 1.45), scale=(1.1, 0.6, 0.8), m=gold, segs=8, rings=5)]
    # Tongue and yoke.
    p += [tube("Tongue", [(-BED_L / 2, 0, 0.9), (-BED_L / 2 - 1.6, 0, 0.5)], 0.08, m=dark, segs=6),
          box("Yoke", (0.12, 1.4, 0.12), (-BED_L / 2 - 1.5, 0, 0.55), bevel=0.02, m=dark)]
    return p


def goods():
    wood, light, dark = gmat("Wood"), gmat("WoodLight"), gmat("WoodDark")
    gold = gmat("Gold", rough=0.3, metal=0.5)
    p = []
    # Barrels and crates round the wagon.
    for i, (x, y) in enumerate(((2.9, -0.5), (2.9, 0.4), (-2.9, 0.8))):
        p += [lathe(f"Barrel{i}", [(0.32, 0), (0.38, 0.45), (0.32, 0.9)], [wood], segs=14),
              torus(f"BarrelHoop{i}", 0.37, 0.025, (x, y, 0.25), m=gmat("Iron"), major_segs=14, minor_segs=4),
              torus(f"BarrelHoopB{i}", 0.37, 0.025, (x, y, 0.65), m=gmat("Iron"), major_segs=14, minor_segs=4)]
        p[-3].location = (x, y, 0)
    p += [box("CrateA", (0.9, 0.9, 0.8), (-2.9, -0.4, 0.4), rot=(0, 0, 0.2), bevel=0.04, m=light),
          box("CrateB", (0.7, 0.7, 0.6), (-2.85, -0.35, 1.1), rot=(0, 0, -0.1), bevel=0.04, m=light),
          text("CrateText", "PICKS", 0.15, 0.02, (-2.95, -0.86, 0.45), rot=(0, 0, 0.2), m=gmat("RedDark"))]
    # Pickaxe and shovel leaning on the wagon end.
    p += [tube("PickHandle", [(2.6, 1.1, 0.0), (2.45, 1.1, 1.35)], 0.04, m=dark, segs=6),
          box("PickHead", (0.9, 0.08, 0.1), (2.45, 1.1, 1.35), rot=(0, 0.15, 0), bevel=0.02, m=gmat("IronLight")),
          tube("ShovelHandle", [(2.65, 0.75, 0.25), (2.48, 0.7, 1.5)], 0.035, m=dark, segs=6),
          box("ShovelBlade", (0.3, 0.05, 0.4), (2.66, 0.76, 0.2), bevel=0.02, m=gmat("IronLight"))]
    # Sacks of flour and a gold nugget heap by the counter.
    for i, (x, y) in enumerate(((-1.9, -1.55), (-1.4, -1.65))):
        p.append(sphere(f"Sack{i}", 0.35, (x, y, 0.32), scale=(1, 0.85, 1.0), m=gmat("Canvas", rough=0.9), segs=10, rings=7))
    rng = random.Random(3)
    for k in range(7):
        p.append(sphere(f"Heap{k}", rng.uniform(0.14, 0.22), (1.8 + rng.uniform(-0.3, 0.3), -1.6 + rng.uniform(-0.2, 0.2), 0.12 + (0.15 if k > 4 else 0)),
                        scale=(1, 1, 0.8), m=gold, segs=6, rings=4))
    bulb_m = gglow("GulchLampGlow", "#ffd88a", 3.0)
    p += [box("LampHook", (0.06, 0.4, 0.06), (1.9, -BED_W / 2 - 1.7, 2.75), bevel=0.0, m=gmat("Iron")),
          cyl("LampCage", 0.14, 0.34, (1.9, -BED_W / 2 - 1.85, 2.5), segs=8, bevel=0.02, m=gmat("Iron")),
          bulb("LampBulb", 0.11, (1.9, -BED_W / 2 - 1.85, 2.5), bulb_m)]
    return p


def shutter():
    L = WIN_Z1 - WIN_Z0
    W = 2 * WIN_HALF
    p = [box("Panel", (W, 0.08, L), (0, 0, L / 2), bevel=0.02, m=gmat("Turq", rough=0.55))]
    for k in range(4):
        p.append(box(f"Board{k}", (0.05, 0.1, L - 0.1), (-W / 2 + W * (k + 1) / 5, -0.01, L / 2), bevel=0.0, m=gmat("TurqDark", rough=0.55)))
    p += [box("EdgeT", (W + 0.06, 0.12, 0.1), (0, -0.01, L - 0.05), bevel=0.02, m=gmat("Gold", rough=0.35)),
          box("EdgeB", (W + 0.06, 0.12, 0.1), (0, -0.01, 0.05), bevel=0.02, m=gmat("Gold", rough=0.35))]
    ob = merge("Shutter", p, pivot=(0, 0, 0))
    ob.location = HINGE
    return ob


def open_dressing():
    neon = gglow("GulchNeonOpen", "#ffd84a", 3.2)
    gold = gmat("Gold", rough=0.3, metal=0.5)
    c = (0, -BED_W / 2 - 0.08 - (WIN_Z1 - WIN_Z0) / 2, WIN_Z0 + 0.08)
    p = [box("OpenBack", (1.1, 0.06, 0.34), (0, -BED_W / 2 + 0.2, WIN_Z1 - 0.3), bevel=0.03, m=gmat("Ink")),
         text("OpenText", "OPEN", 0.24, 0.03, (0, -BED_W / 2 + 0.15, WIN_Z1 - 0.31), m=neon)]
    # Goods on the lowered counter: ammo tins, glowing cells, a jar of jerky.
    p += [box("Ammo", (0.5, 0.36, 0.3), (-1.0, c[1], c[2] + 0.15), bevel=0.04, m=gmat("IronLight", rough=0.4)),
          box("AmmoBand", (0.52, 0.38, 0.07), (-1.0, c[1], c[2] + 0.2), bevel=0.01, m=gold)]
    cell = gglow("GulchCellGlow", "#5ff0e6", 2.4)
    for k in range(3):
        p.append(cyl(f"Cell{k}", 0.07, 0.28, (0.45 + k * 0.2, c[1], c[2] + 0.14), segs=8, bevel=0.02, m=cell))
    p += [cyl("Jar", 0.14, 0.3, (-0.3, c[1], c[2] + 0.15), segs=10, bevel=0.03, m=gmat("TurqLight", rough=0.1)),
          cyl("JarLid", 0.15, 0.06, (-0.3, c[1], c[2] + 0.32), segs=10, bevel=0.02, m=gmat("Red"))]
    for s in (-1, 1):
        p.append(tube(f"Chain{s}", [(s * (WIN_HALF - 0.15), -BED_W / 2 - 0.05, WIN_Z1 - 0.05), (s * (WIN_HALF - 0.15), c[1] - 0.5, c[2])], 0.015,
                      m=gmat("Iron"), segs=4))
    return merge("OpenDressing", p)


def closed_sign():
    y = HINGE[1] - 0.07
    p = [box("ClosedCard", (1.5, 0.04, 0.4), (0, y, HINGE[2] + 0.55), bevel=0.02, m=gmat("Bone", rough=0.8)),
         text("ClosedText", "GONE PANNING", 0.17, 0.02, (0, y - 0.03, HINGE[2] + 0.54), m=gmat("RedDark", rough=0.5))]
    return merge("ClosedSign", p)


def build_station():
    reset_scene()
    station = merge("Station", wagon() + goods())
    save("gulch_station", [station, shutter(), open_dressing(), closed_sign()])


def build_portal():
    reset_scene()
    log, dark = gmat("Wood", rough=0.8), gmat("WoodDark", rough=0.8)
    gold = gmat("Gold", rough=0.25, metal=0.6)
    p = []
    X = wp.OPEN_W + 0.35
    top = wp.OPEN_SPRING + wp.OPEN_RISE
    for s in (-1, 1):
        p += [box(f"Post{s}", (0.6, 0.6, top + 0.6), (s * X, 0, (top + 0.6) / 2), bevel=0.07, m=log),
              box(f"Foot{s}", (0.9, 0.9, 0.3), (s * X, 0, 0.15), bevel=0.05, m=gmat("RockDark", rough=0.9)),
              box(f"Strut{s}", (0.3, 0.3, 1.6), (s * (X - 0.55), -0.05, top - 0.35), rot=(0, s * 0.75, 0), bevel=0.04, m=dark)]
    p += [box("Lintel", (2 * X + 1.4, 0.7, 0.6), (0, 0, top + 0.6), bevel=0.07, m=log),
          box("Lintel2", (2 * X + 1.8, 0.55, 0.35), (0, 0.05, top + 1.05), bevel=0.05, m=dark)]
    # The doorway's elliptical top framed in planks behind the posts.
    p.append(tube("Arch", wp.arc_only(wp.OPEN_W + 0.12, wp.OPEN_RISE + 0.12, steps=20, y=0.15), 0.12, m=dark, segs=8))
    # A crown of gold nuggets and a hanging EXIT board.
    rng = random.Random(7)
    for k in range(9):
        x = -1.6 + k * 0.4
        p.append(sphere(f"Nugget{k}", rng.uniform(0.18, 0.3), (x, 0.0, top + 1.35 + rng.uniform(0, 0.15)), scale=(1, 0.8, 0.75), m=gold, segs=7, rings=5))
    p += [box("Board", (1.5, 0.1, 0.5), (0, -0.42, top + 0.05), bevel=0.04, m=gmat("RedDark", rough=0.5)),
          text("BoardText", "EXIT", 0.34, 0.03, (0, -0.5, top + 0.03), m=gglow("GulchExitText", "#ffd84a", 2.6))]
    for s in (-1, 1):
        p.append(cyl(f"BoardChain{s}", 0.02, 0.35, (s * 0.6, -0.42, top + 0.4), segs=4, bevel=0.0, m=gmat("Iron")))
    bulb_m = gglow("GulchLampGlow", "#ffd88a", 3.0)
    for s in (-1, 1):
        p += [cyl(f"LampCage{s}", 0.15, 0.4, (s * (X + 0.45), -0.35, 2.6), segs=8, bevel=0.02, m=gmat("Iron")),
              bulb(f"Lamp{s}", 0.12, (s * (X + 0.45), -0.35, 2.6), bulb_m),
              box(f"LampArm{s}", (0.4, 0.06, 0.06), (s * (X + 0.3), -0.3, 2.85), bevel=0.0, m=gmat("Iron"))]
    # Rails running through the doorway.
    for s in (-1, 1):
        p.append(box(f"Rail{s}", (0.08, 3.6, 0.1), (s * 0.55, -0.6, 0.05), bevel=0.0, m=gmat("Iron", rough=0.4)))
    for k in range(5):
        p.append(box(f"Tie{k}", (1.6, 0.22, 0.06), (0, -2.2 + k * 0.8, 0.03), bevel=0.0, m=dark))
    p.append(wp.backing("Back", mat("GulchVoid", "#120c0c", rough=1.0)))
    save("gulch_portal_arch", [merge("PortalArch", p)])


if __name__ == "__main__":
    wanted = sys.argv[1:] or ["station", "portal"]
    if "station" in wanted:
        build_station()
    if "portal" in wanted:
        build_portal()
