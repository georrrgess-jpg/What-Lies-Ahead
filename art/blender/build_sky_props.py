"""Sky Carnival props (World 10, Sky Harbor): carnival railings, the plank
bridges with rope netting, the rocky undersides of the islands, game booths,
carts, crates, benches, planters, lamp posts, pinwheels, wind turbines and the
exit-trail lanterns.

Each function builds one prop in a fresh scene and saves
art/blender/sky_<name>.blend + art/models/sky_<name>.glb.

    python art/blender/build_sky_props.py              (all props)
    python art/blender/build_sky_props.py rail bridge  (only these)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sky_common import *  # noqa: F401,F403

BRIDGE_LEN = 6.0
BRIDGE_W = 4.6


def build_rail():
    """Carnival railing module, 2.5 m along X, 1.1 m tall: white posts and
    balusters, a red handrail, a teal mid rail and a navy kick board."""
    reset_scene()
    white, red, teal, navy, gold = smat("White"), smat("Red", rough=0.45), smat("Teal", rough=0.45), smat("Navy"), smat("Gold", rough=0.4)
    p = [cyl("Hand", 0.06, 2.5, (0, 0, 1.05), rot=rad(0, 90, 0), segs=8, bevel=0.0, m=red),
         cyl("Mid", 0.035, 2.5, (0, 0, 0.62), rot=rad(0, 90, 0), segs=6, bevel=0.0, m=teal),
         box("Kick", (2.5, 0.09, 0.2), (0, 0, 0.12), bevel=0.02, m=navy)]
    for x in (-0.625, 0.625):
        p += [box(f"Post{x}", (0.14, 0.14, 1.12), (x, 0, 0.56), bevel=0.03, m=white),
              sphere(f"Cap{x}", 0.09, (x, 0, 1.17), m=gold, segs=8, rings=5)]
    for i in range(10):
        x = -1.125 + i * 0.25
        if abs(abs(x) - 0.625) < 0.05:
            continue
        p.append(cyl(f"Bal{i}", 0.022, 0.84, (x, 0, 0.64), segs=5, bevel=0.0, m=white))
    save("sky_rail", [merge("Rail", p)])


def build_bridge():
    """Plank bridge, 6 m along -Y (Godot +Z) by 4.6 m, deck top at z 0: planks on
    navy stringers, post-and-rope railings with diamond netting, pennants on the
    handropes and a bulb arch over each end."""
    reset_scene()
    wood, light, dark = smat("Wood", rough=0.8), smat("WoodLight", rough=0.8), smat("WoodDark", rough=0.8)
    navy, rope, gold = smat("Navy"), smat("Rope", rough=0.9), smat("Gold", rough=0.4)
    hw = BRIDGE_W / 2
    p = []
    n = 15
    for i in range(n):
        y = -BRIDGE_LEN / 2 + (i + 0.5) * BRIDGE_LEN / n
        p.append(box(f"Plank{i}", (BRIDGE_W - 0.1, BRIDGE_LEN / n - 0.04, 0.16), (0, y, -0.08), bevel=0.02, m=wood if i % 3 else light))
    for x in (-hw + 0.5, hw - 0.5):
        p.append(box(f"Stringer{x}", (0.3, BRIDGE_LEN, 0.5), (x, 0, -0.42), bevel=0.04, m=navy))
    for s in (-1, 1):
        x = s * (hw - 0.05)
        p.append(box(f"Edge{s}", (0.18, BRIDGE_LEN, 0.28), (x, 0, 0.02), bevel=0.03, m=dark))
        posts = [-BRIDGE_LEN / 2 + 0.15 + k * (BRIDGE_LEN - 0.3) / 4 for k in range(5)]
        for k, y in enumerate(posts):
            p += [box(f"Post{s}{k}", (0.18, 0.18, 1.3), (x, y, 0.65), bevel=0.03, m=dark),
                  sphere(f"PostCap{s}{k}", 0.11, (x, y, 1.36), m=gold, segs=8, rings=5)]
        for z, r in ((1.12, 0.05), (0.62, 0.035)):
            pts = [(x, -BRIDGE_LEN / 2 + 0.15 + t * (BRIDGE_LEN - 0.3) / 8, z - 0.06 * math.sin(math.pi * (t % 2) / 2)) for t in range(9)]
            p.append(tube(f"Rope{s}{z}", pts, r, m=rope, segs=6))
        for k in range(4):
            y0, y1 = posts[k], posts[k + 1]
            p.append(tube(f"NetA{s}{k}", [(x, y0, 0.15), (x, y1, 1.08)], 0.02, m=rope, segs=4))
            p.append(tube(f"NetB{s}{k}", [(x, y1, 0.15), (x, y0, 1.08)], 0.02, m=rope, segs=4))
            p.append(tube(f"NetC{s}{k}", [(x, y0, 0.62), (x, (y0 + y1) / 2, 0.15), (x, y1, 0.62)], 0.018, m=rope, segs=4))
        p += pennants(f"Pen{s}", (x, -BRIDGE_LEN / 2 + 0.2, 1.15), (x, BRIDGE_LEN / 2 - 0.2, 1.15), 12, 0.1,
                      [smat("Red", rough=0.5), smat("Gold", rough=0.5), smat("Teal", rough=0.5)], size=0.22)
    # Bulb arches over both ends.
    bulb_m = sglow("SkyBulb", "#ffe2a0", 3.0)
    for e in (-1, 1):
        y = e * (BRIDGE_LEN / 2 - 0.15)
        pts = [(math.cos(math.radians(a)) * (hw - 0.05), y, 1.3 + math.sin(math.radians(a)) * 2.2) for a in range(0, 181, 15)]
        p.append(tube(f"Arch{e}", pts, 0.08, m=smat("Red", rough=0.45), segs=8))
        for k in range(1, 12, 2):
            q = pts[k]
            p.append(bulb(f"ArchBulb{e}{k}", 0.07, (q[0], q[1], q[2] - 0.12), bulb_m))
    save("sky_bridge", [merge("Bridge", p)])


def build_isle_rock():
    """Underside of a floating island, unit size: top radius 1 at z 0, tip at
    z -1 (scaled per island). Banded rock, a turf collar and dangling vines."""
    reset_scene()
    p = [rock_cone("Rock", 1.0, 1.0, seed=4, rings=7, segs=18), grass_lip("Lip", 1.0, seed=5, segs=24, height=0.07)]
    rng = random.Random(8)
    for i in range(10):
        a = math.tau * i / 10 + rng.uniform(-0.2, 0.2)
        r = 0.97
        top = (math.cos(a) * r, math.sin(a) * r, -0.03)
        length = rng.uniform(0.12, 0.3)
        mid = (math.cos(a) * (r + 0.01), math.sin(a) * (r + 0.01), -length * 0.5)
        bot = (math.cos(a) * (r - 0.02), math.sin(a) * (r - 0.02), -length)
        p.append(tube(f"Vine{i}", [top, mid, bot], 0.008, m=smat("Leaf", rough=0.8), segs=4, radius_end=0.003))
    save("sky_isle_rock", [merge("IsleRock", p)])


def build_booth():
    """Ring-toss game booth, 3.2 x 2.0 m, 3.6 m to the sign: striped counter and
    awning, prize shelves, bottle pyramid and rings. Collide with a 3.2 x 2.0 box."""
    reset_scene()
    red, white, navy, gold, teal = smat("Red", rough=0.5), smat("White"), smat("Navy"), smat("Gold", rough=0.4), smat("Teal", rough=0.45)
    cream, wood = smat("Cream"), smat("WoodLight", rough=0.7)
    W, D = 3.2, 2.0
    p = [box("Floor", (W, D, 0.12), (0, 0, 0.06), bevel=0.02, m=smat("WoodDark", rough=0.8)),
         box("Back", (W, 0.12, 2.6), (0, D / 2 - 0.06, 1.3), bevel=0.03, m=navy),
         box("SideL", (0.12, D, 2.6), (-W / 2 + 0.06, 0, 1.3), bevel=0.03, m=cream),
         box("SideR", (0.12, D, 2.6), (W / 2 - 0.06, 0, 1.3), bevel=0.03, m=cream),
         box("Counter", (W + 0.1, 0.5, 0.1), (0, -D / 2 + 0.2, 1.05), bevel=0.03, m=wood)]
    for i in range(8):
        x = -W / 2 + 0.2 + i * 0.4
        p.append(box(f"Front{i}", (0.4, 0.1, 1.0), (x, -D / 2 + 0.02, 0.5), bevel=0.01, m=red if i % 2 == 0 else white))
    for s in (-1, 1):
        p.append(cyl(f"Pole{s}", 0.08, 3.0, (s * (W / 2 - 0.05), -D / 2 + 0.02, 1.5), segs=8, bevel=0.0, m=gold))
    # Awning: sloping stripes and a scalloped valance.
    for i in range(8):
        x = -W / 2 + 0.2 + i * 0.4
        p.append(box(f"Awn{i}", (0.4, 1.1, 0.05), (x, -D / 2 - 0.15, 2.85), rot=(math.radians(-18), 0, 0), bevel=0.0, m=red if i % 2 == 0 else white))
        p.append(cyl(f"Scal{i}", 0.2, 0.05, (x, -D / 2 - 0.68, 2.58), rot=rad(90, 0, 0), segs=12, bevel=0.0, m=red if i % 2 == 0 else white))
    p.append(box("Roof", (W + 0.1, D, 0.12), (0, 0.1, 2.66), bevel=0.03, m=navy))
    # Sign with bulbs.
    p += [box("SignBoard", (2.8, 0.14, 0.62), (0, 0.0, 3.25), bevel=0.05, m=navy),
          box("SignTrim", (2.95, 0.1, 0.74), (0, 0.04, 3.25), bevel=0.04, m=gold),
          text("SignText", "RING TOSS", 0.36, 0.05, (0, -0.1, 3.23), m=smat("Gold", rough=0.3))]
    bulb_m = sglow("SkyBulb", "#ffe2a0", 3.0)
    for k in range(7):
        p.append(bulb(f"SignBulb{k}", 0.06, (-1.3 + k * 0.433, -0.12, 3.62), bulb_m))
    # Prize shelves with plush toys.
    plush = [smat("Pink", rough=0.8), smat("Sky", rough=0.8), smat("Gold", rough=0.8), smat("Mint", rough=0.8), smat("Lilac", rough=0.8)]
    for row, z in enumerate((1.55, 2.15)):
        p.append(box(f"Shelf{row}", (W - 0.3, 0.4, 0.06), (0, D / 2 - 0.3, z), bevel=0.01, m=wood))
        for k in range(6):
            x = -1.15 + k * 0.46
            m = plush[(k + row * 2) % len(plush)]
            p += [sphere(f"Toy{row}{k}", 0.17, (x, D / 2 - 0.32, z + 0.2), scale=(1, 0.9, 1.1), m=m, segs=10, rings=7),
                  sphere(f"ToyEarL{row}{k}", 0.06, (x - 0.1, D / 2 - 0.32, z + 0.37), m=m, segs=6, rings=4),
                  sphere(f"ToyEarR{row}{k}", 0.06, (x + 0.1, D / 2 - 0.32, z + 0.37), m=m, segs=6, rings=4)]
    # Bottles and rings on the counter.
    for k, (x, z) in enumerate(((-0.3, 0), (0.0, 0), (0.3, 0), (-0.15, 0.3), (0.15, 0.3), (0.0, 0.6))):
        p.append(cyl(f"Bottle{k}", 0.08, 0.28, (x, -D / 2 + 0.2, 1.24 + z), segs=8, bevel=0.02, m=teal, radius_top=0.04))
    for k in range(3):
        p.append(torus(f"Ring{k}", 0.12, 0.022, (0.9 + k * 0.12, -D / 2 + 0.15, 1.12 + k * 0.03), m=(red, gold, teal)[k], major_segs=14, minor_segs=4))
    save("sky_booth", [merge("Booth", p)])


def spoked_wheel(prefix, x, y, z, r, m, hub):
    parts = [torus(prefix + "Tyre", r, 0.04, (x, y, z), rot=rad(0, 90, 0), m=m, major_segs=16, minor_segs=5),
             cyl(prefix + "Hub", 0.06, 0.1, (x, y, z), rot=rad(0, 90, 0), segs=8, bevel=0.0, m=hub)]
    for k in range(4):
        a = math.pi * k / 4
        parts.append(box(f"{prefix}Spoke{k}", (0.03, 2 * r, 0.03), (x, y, z), rot=(a, 0, 0), bevel=0.0, m=hub))
    return parts


def build_popcorn():
    """Popcorn cart, 1.7 x 0.9 m on spoked wheels, glass case, striped parasol."""
    reset_scene()
    red, white, gold, navy = smat("Red", rough=0.45), smat("White"), smat("Gold", rough=0.4), smat("Navy")
    p = [box("Body", (1.5, 0.8, 0.7), (0, 0, 0.75), bevel=0.06, m=red),
         box("Trim", (1.56, 0.86, 0.08), (0, 0, 1.1), bevel=0.03, m=gold),
         box("Glass", (1.2, 0.66, 0.7), (0, 0, 1.5), bevel=0.04, m=mat("SkyGlass", "#cfeeff", rough=0.1)),
         box("CaseTop", (1.3, 0.76, 0.08), (0, 0, 1.88), bevel=0.03, m=red),
         text("Label", "POPCORN", 0.2, 0.03, (0, -0.42, 0.78), m=white)]
    rng = random.Random(2)
    for k in range(14):
        p.append(sphere(f"Corn{k}", 0.09, (rng.uniform(-0.5, 0.5), rng.uniform(-0.25, 0.25), 1.22 + rng.uniform(0, 0.12)), m=smat("Cream"), segs=6, rings=4))
    p += spoked_wheel("WL", -0.82, 0.0, 0.42, 0.4, navy, gold) + spoked_wheel("WR", 0.82, 0.0, 0.42, 0.4, navy, gold)
    p += [cyl("Axle", 0.03, 1.7, (0, 0, 0.42), rot=rad(0, 90, 0), segs=6, bevel=0.0, m=navy),
          cyl("Leg", 0.04, 0.4, (0, 0.3, 0.2), segs=6, bevel=0.0, m=navy),
          cyl("Pole", 0.035, 1.1, (0, 0, 2.4), segs=6, bevel=0.0, m=gold),
          tube("Handle", [(0.75, 0.0, 1.0), (1.1, 0.0, 1.05)], 0.03, m=navy, segs=6)]
    p.append(lathe("Parasol", [(1.05, 2.82), (0.6, 2.98), (0.02, 3.2)], [red, white], segs=16, stripes=1, smooth=False))
    p.append(sphere("Finial", 0.06, (0, 0, 3.24), m=gold, segs=6, rings=4))
    save("sky_popcorn", [merge("Popcorn", p)])


def build_balloon_cart():
    """Balloon seller's cart: a striped box on wheels with a tall bunch of balloons."""
    reset_scene()
    teal, white, gold, navy = smat("Teal", rough=0.45), smat("White"), smat("Gold", rough=0.4), smat("Navy")
    p = [box("Body", (1.2, 0.7, 0.6), (0, 0, 0.65), bevel=0.05, m=teal),
         box("Lid", (1.26, 0.76, 0.08), (0, 0, 0.98), bevel=0.03, m=white),
         text("Label", "BALLOONS", 0.14, 0.03, (0, -0.37, 0.66), m=white)]
    for k in range(6):
        p.append(box(f"Stripe{k}", (0.1, 0.72, 0.6), (-0.5 + k * 0.2, 0, 0.65), bevel=0.0, m=white if k % 2 else teal))
    p += spoked_wheel("WL", -0.66, 0.0, 0.35, 0.33, navy, gold) + spoked_wheel("WR", 0.66, 0.0, 0.35, 0.33, navy, gold)
    p += [cyl("Pole", 0.03, 1.2, (0.3, 0.1, 1.6), segs=6, bevel=0.0, m=gold)]
    p += balloon_bunch("BB", (0.3, 0.1, 2.15), count=12, spread=0.55, height=1.0, radius=0.2, seed=4)
    save("sky_balloon_cart", [merge("BalloonCart", p)])


def build_crates():
    """Carnival freight: two stacked crates with star stencils, a barrel and a rope coil (1.9 x 1.3 m)."""
    reset_scene()
    wood, dark, navy, gold, red = smat("WoodLight", rough=0.75), smat("WoodDark", rough=0.8), smat("Navy"), smat("Gold", rough=0.4), smat("Red", rough=0.5)
    p = []
    for k, (x, y, z, s, yaw) in enumerate(((-0.35, 0.0, 0.0, 1.0, 0.0), (0.55, -0.05, 0.0, 0.8, 0.25), (-0.3, 0.05, 1.0, 0.7, -0.2))):
        h = s
        p += [box(f"Crate{k}", (s, s, h), (x, y, z + h / 2), rot=(0, 0, yaw), bevel=0.05, m=wood)]
        for zz in (0.12, h - 0.12):
            p.append(box(f"Band{k}{zz}", (s + 0.03, s + 0.03, 0.08), (x, y, z + zz), rot=(0, 0, yaw), bevel=0.01, m=navy))
        st = star(f"Star{k}", s * 0.22, 0.02, (x - math.sin(yaw) * 0.0, y - s / 2 - 0.01, z + h / 2), rot=(0, 0, yaw), m=red if k % 2 else gold)
        p.append(st)
    p += [cyl("Barrel", 0.32, 0.8, (0.75, 0.55, 0.4), segs=12, bevel=0.04, m=red),
          torus("BarrelHoopA", 0.33, 0.025, (0.75, 0.55, 0.15), m=gold, major_segs=16, minor_segs=4),
          torus("BarrelHoopB", 0.33, 0.025, (0.75, 0.55, 0.65), m=gold, major_segs=16, minor_segs=4),
          torus("Coil", 0.25, 0.07, (0.65, -0.55, 0.08), m=smat("Rope", rough=0.9), major_segs=16, minor_segs=6)]
    save("sky_crates", [merge("Crates", p)])


def build_bench():
    """Park bench, 1.8 m: white scroll frame, red slats."""
    reset_scene()
    white, red = smat("White"), smat("Red", rough=0.5)
    p = []
    for s in (-1, 1):
        x = s * 0.8
        p += [box(f"LegF{s}", (0.08, 0.08, 0.45), (x, -0.2, 0.22), bevel=0.02, m=white),
              box(f"LegB{s}", (0.08, 0.08, 0.95), (x, 0.22, 0.47), bevel=0.02, m=white),
              box(f"Arm{s}", (0.08, 0.5, 0.06), (x, 0.0, 0.68), bevel=0.02, m=white),
              torus(f"Scroll{s}", 0.12, 0.025, (x, -0.24, 0.6), rot=rad(0, 90, 0), m=white, major_segs=12, minor_segs=4)]
    for k in range(3):
        p.append(box(f"Seat{k}", (1.8, 0.13, 0.05), (0, -0.18 + k * 0.15, 0.46), bevel=0.02, m=red))
    for k in range(2):
        p.append(box(f"BackSlat{k}", (1.8, 0.05, 0.13), (0, 0.24, 0.65 + k * 0.2), bevel=0.02, m=red))
    save("sky_bench", [merge("Bench", p)])


def build_planter():
    """Flower box 1.6 x 0.8 m, 0.7 m tall: wood with teal trim, tulips and leaves."""
    reset_scene()
    p = [box("Box", (1.6, 0.8, 0.55), (0, 0, 0.275), bevel=0.05, m=smat("Wood", rough=0.8)),
         box("Trim", (1.68, 0.88, 0.08), (0, 0, 0.55), bevel=0.03, m=smat("Teal", rough=0.5)),
         box("Soil", (1.45, 0.65, 0.06), (0, 0, 0.58), bevel=0.0, m=smat("WoodDark", rough=0.9))]
    rng = random.Random(6)
    cols = [smat("Red", rough=0.5), smat("Pink", rough=0.5), smat("Gold", rough=0.5), smat("Lilac", rough=0.5), smat("White")]
    for k in range(14):
        x, y = rng.uniform(-0.65, 0.65), rng.uniform(-0.25, 0.25)
        h = rng.uniform(0.25, 0.45)
        p += [cyl(f"Stem{k}", 0.015, h, (x, y, 0.6 + h / 2), segs=4, bevel=0.0, m=smat("GrassDark", rough=0.8)),
              sphere(f"Tulip{k}", 0.07, (x, y, 0.6 + h + 0.04), scale=(1, 1, 1.3), m=cols[k % len(cols)], segs=8, rings=5)]
    for k in range(8):
        x = -0.6 + k * 0.17
        p.append(sphere(f"Leaf{k}", 0.13, (x, rng.uniform(-0.2, 0.2), 0.66), scale=(1, 0.6, 0.5), m=smat("Leaf", rough=0.8), segs=8, rings=5))
    save("sky_planter", [merge("Planter", p)])


def build_lamp():
    """Lamp post, 3.6 m: navy pole with gold rings, a glowing globe and a pennant."""
    reset_scene()
    navy, gold = smat("Navy"), smat("Gold", rough=0.35)
    p = [cyl("Base", 0.22, 0.4, (0, 0, 0.2), segs=10, bevel=0.04, m=navy, radius_top=0.14),
         cyl("Pole", 0.07, 3.1, (0, 0, 1.95), segs=8, bevel=0.0, m=navy),
         torus("RingA", 0.09, 0.025, (0, 0, 1.2), m=gold, major_segs=12, minor_segs=4),
         torus("RingB", 0.09, 0.025, (0, 0, 2.6), m=gold, major_segs=12, minor_segs=4),
         cyl("Cup", 0.16, 0.14, (0, 0, 3.5), segs=10, bevel=0.02, m=gold, radius_top=0.2),
         bulb("Globe", 0.22, (0, 0, 3.75), sglow("SkyLampGlobe", "#fff1cf", 2.6)),
         sphere("Finial", 0.06, (0, 0, 4.02), m=gold, segs=6, rings=4),
         tube("Arm", [(0, 0, 3.0), (0.45, 0, 3.05), (0.5, 0, 2.95)], 0.025, m=navy, segs=5)]
    p.append(prism("Flag", [(0, 0), (0.55, -0.12), (0, -0.7)], 0.03, (0.06, 0, 2.8), m=smat("Red", rough=0.5)))
    p.append(prism("FlagStripe", [(0, 0), (0.25, -0.05), (0, -0.32)], 0.035, (0.06, 0, 2.6), m=smat("Teal", rough=0.5)))
    save("sky_lamp", [merge("Lamp", p)])


def build_pinwheel():
    """Pinwheel: a 3.2 m striped pole (sky_pinwheel) and its wheel
    (sky_pinwheel_wheel, radius 0.8, in the XZ plane, spinning about Y)."""
    reset_scene()
    p = [cyl("Pole", 0.06, 3.2, (0, 0, 1.6), segs=8, bevel=0.0, m=smat("White")),
         cyl("Foot", 0.18, 0.2, (0, 0, 0.1), segs=10, bevel=0.03, m=smat("Navy"))]
    for k in range(6):
        p.append(cyl(f"Stripe{k}", 0.065, 0.18, (0, 0, 0.4 + k * 0.5), segs=8, bevel=0.0, m=smat("Red", rough=0.5)))
    p.append(cyl("Pin", 0.04, 0.3, (0, -0.15, 3.2), rot=rad(90, 0, 0), segs=6, bevel=0.0, m=smat("Gold", rough=0.4)))
    save("sky_pinwheel", [merge("PinwheelPole", p)])
    reset_scene()
    cols = [smat("Red", rough=0.5), smat("Gold", rough=0.5), smat("Teal", rough=0.5), smat("Pink", rough=0.5)]
    w = []
    for k in range(4):
        a = math.tau * k / 4
        r = 0.8
        pts = [(0, 0), (math.cos(a) * r, math.sin(a) * r), (math.cos(a + 0.9) * r * 0.55, math.sin(a + 0.9) * r * 0.55)]
        w.append(prism(f"Blade{k}", pts, 0.03, (0, 0, 0), m=cols[k], bevel=0.0))
    w.append(sphere("Hub", 0.08, (0, -0.04, 0), m=smat("White"), segs=8, rings=5))
    save("sky_pinwheel_wheel", [merge("PinwheelWheel", w)])


def build_turbine():
    """Wind turbine for the far islands: a 10 m white tower with a nacelle
    (sky_turbine) and a three-blade rotor of radius 4.2 (sky_turbine_rotor,
    in the XZ plane, spinning about Y)."""
    reset_scene()
    white, red = smat("White"), smat("Red", rough=0.5)
    p = [cyl("Tower", 0.45, 10.0, (0, 0, 5.0), segs=12, bevel=0.0, m=white, radius_top=0.28),
         cyl("Band", 0.4, 0.4, (0, 0, 2.0), segs=12, bevel=0.0, m=red),
         box("Nacelle", (0.8, 1.8, 0.8), (0, 0.3, 10.2), bevel=0.2, m=white),
         cyl("Nose", 0.36, 0.5, (0, -0.75, 10.2), rot=rad(90, 0, 0), segs=12, bevel=0.06, m=red, radius_top=0.1)]
    save("sky_turbine", [merge("Turbine", p)])
    reset_scene()
    white, red = smat("White"), smat("Red", rough=0.5)
    r = []
    for k in range(3):
        a = math.tau * k / 3 + math.pi / 2
        blade = prism(f"Blade{k}", [(0.0, -0.2), (4.2, -0.06), (4.2, 0.06), (0.0, 0.32)], 0.08, (0, 0, 0), rot=(0, -a, 0), m=white)
        tip = prism(f"Tip{k}", [(3.4, -0.08), (4.2, -0.06), (4.2, 0.06), (3.4, 0.14)], 0.1, (0, 0, 0), rot=(0, -a, 0), m=red)
        r += [blade, tip]
    r.append(sphere("Hub", 0.3, (0, 0, 0), m=white, segs=10, rings=6))
    save("sky_turbine_rotor", [merge("TurbineRotor", r)])


def build_exit_lantern():
    """Exit-trail lantern post, 1.5 m: a navy post with a caged lantern whose
    glass ("SkyExitGlow") the level drives (scripts/props/sky_exit_lantern.gd)."""
    reset_scene()
    navy, gold = smat("Navy"), smat("Gold", rough=0.35)
    p = [cyl("Foot", 0.18, 0.16, (0, 0, 0.08), segs=10, bevel=0.03, m=navy),
         cyl("Post", 0.05, 1.2, (0, 0, 0.7), segs=8, bevel=0.0, m=navy),
         cyl("Glass", 0.14, 0.3, (0, 0, 1.45), segs=10, bevel=0.03, m=mat("SkyExitGlow", "#ffd27a", rough=0.3, emit=1.0)),
         cyl("CapTop", 0.19, 0.08, (0, 0, 1.64), segs=10, bevel=0.02, m=gold, radius_top=0.08),
         cyl("CapBottom", 0.17, 0.06, (0, 0, 1.27), segs=10, bevel=0.02, m=gold),
         sphere("Knob", 0.05, (0, 0, 1.72), m=gold, segs=6, rings=4)]
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        p.append(cyl(f"Bar{k}", 0.015, 0.32, (math.cos(a) * 0.15, math.sin(a) * 0.15, 1.45), segs=4, bevel=0.0, m=gold))
    save("sky_exit_lantern", [merge("ExitLantern", p)])


BUILDERS = {
    "rail": build_rail, "bridge": build_bridge, "isle_rock": build_isle_rock, "booth": build_booth,
    "popcorn": build_popcorn, "balloon_cart": build_balloon_cart, "crates": build_crates, "bench": build_bench,
    "planter": build_planter, "lamp": build_lamp, "pinwheel": build_pinwheel, "turbine": build_turbine,
    "exit_lantern": build_exit_lantern,
}


if __name__ == "__main__":
    wanted = sys.argv[1:] or list(BUILDERS)
    for key in wanted:
        BUILDERS[key]()
