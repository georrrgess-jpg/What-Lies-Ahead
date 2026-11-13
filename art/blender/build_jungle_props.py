"""Jungle Expedition props (World 7, Lost Temple): palms, canopy trees, ferns,
elephant-ear plants, bushes, boulders, the ride's track, mine cart, beached
boat and tunnel mouth, the explorer camp (tent, crates, jeep, radio mast, camp
table), tiki torches, bamboo and rope fences and the distant volcano.

Each function builds one prop in a fresh scene and saves
art/blender/jungle_<name>.blend + art/models/jungle_<name>.glb.

    python art/blender/build_jungle_props.py            (all props)
    python art/blender/build_jungle_props.py palm fern  (only these)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from jungle_common import *  # noqa: F401,F403


# ---------------------------------------------------------------------------
# Plants
# ---------------------------------------------------------------------------

def palm_parts(prefix, height=8.0, fronds=9, lean=0.9, seed=1, detail=True):
    rng = random.Random(seed)
    trunk, ring, leaf_m, light = jmat("Bark"), jmat("TrunkDark"), jmat("Leaf"), jmat("LeafLight")
    pts = []
    for i in range(9):
        t = i / 8
        pts.append((lean * t * t, 0.0, height * t))
    parts = [tube(prefix + "Trunk", pts, 0.26, m=trunk, segs=10 if detail else 7, radius_end=0.17)]
    if detail:
        for i in range(1, 8):
            t = i / 8
            parts.append(torus(f"{prefix}Ring{i}", 0.25 - 0.08 * t, 0.035, (lean * t * t, 0, height * t), m=ring, major_segs=10, minor_segs=4))
    top = (lean, 0.0, height)
    parts.append(sphere(prefix + "Crown", 0.32, top, scale=(1, 1, 0.8), m=ring, segs=10, rings=6))
    for i in range(fronds):
        a = math.tau * i / fronds + rng.uniform(-0.15, 0.15)
        parts.append(frond(f"{prefix}Frond{i}", rng.uniform(4.0, 4.8), top, a, lift=rng.uniform(0.35, 0.6),
                           droop=rng.uniform(1.0, 1.4), m=leaf_m if i % 2 else light, leaflets=12 if detail else 7,
                           leaflet_len=1.5, seed=seed * 31 + i))
    if detail:
        for i in range(4):
            a = math.tau * i / 4 + 0.4
            parts.append(sphere(f"{prefix}Coconut{i}", 0.13, (top[0] + math.cos(a) * 0.25, math.sin(a) * 0.25, top[2] - 0.3),
                                m=jmat("TrunkDark"), segs=8, rings=5))
    return parts


def build_palm():
    """Coconut palm, ~8.5 m, leaning a little; origin at the foot of the trunk."""
    reset_scene()
    save("jungle_palm", [merge("Palm", palm_parts("P_"))])


def build_palm_far():
    """Low-detail palm for the forest beyond the arena (MultiMesh)."""
    reset_scene()
    save("jungle_palm_far", [merge("PalmFar", palm_parts("F_", height=9.0, fronds=7, lean=0.6, seed=4, detail=False))])


def canopy_parts(prefix, seed=2, detail=True, height=9.5):
    """Broad rainforest tree: buttress roots, a tall trunk and stacked blobby canopy."""
    rng = random.Random(seed)
    trunk, dark = jmat("Trunk"), jmat("TrunkDark")
    greens = [jmat("Leaf"), jmat("LeafDark"), jmat("LeafLight")]
    parts = [cyl(prefix + "Trunk", 0.85, height, (0, 0, height * 0.5), segs=12 if detail else 8, bevel=0.0, m=trunk, radius_top=0.5)]
    if detail:
        for i in range(5):
            a = math.tau * i / 5 + rng.uniform(-0.2, 0.2)
            parts.append(prism(f"{prefix}Root{i}", [(0, 0), (2.4, 0), (0.5, 2.6), (0, 3.0)], 0.3, (0, 0, 0),
                               rot=(0, 0, a), m=dark, bevel=0.04))
        for i in range(3):
            a = math.tau * i / 3 + 0.5
            parts.append(tube(f"{prefix}Branch{i}", [(0, 0, height * 0.7), (math.cos(a) * 1.6, math.sin(a) * 1.6, height * 0.86),
                                                     (math.cos(a) * 2.6, math.sin(a) * 2.6, height * 0.95)], 0.16, m=trunk, segs=6,
                              radius_end=0.08))
    blobs = 9 if detail else 5
    for i in range(blobs):
        a = math.tau * i / blobs + rng.uniform(-0.3, 0.3)
        r = rng.uniform(1.6, 2.6) if i else 3.0
        d = 0.0 if i == 0 else rng.uniform(1.8, 3.0)
        z = height + (1.4 if i == 0 else rng.uniform(-0.6, 0.8))
        parts.append(sphere(f"{prefix}Canopy{i}", r, (math.cos(a) * d, math.sin(a) * d, z), scale=(1.15, 1.15, 0.7),
                            m=greens[i % 3], segs=12 if detail else 8, rings=7 if detail else 5))
    return parts


def build_canopy_tree():
    """Rainforest giant, ~12 m with a 9 m crown (arena edges and the jungle wall)."""
    reset_scene()
    save("jungle_canopy_tree", [merge("CanopyTree", canopy_parts("C_"))])


def build_canopy_far():
    """Low-detail canopy tree for the forest MultiMesh."""
    reset_scene()
    save("jungle_canopy_far", [merge("CanopyFar", canopy_parts("F_", seed=5, detail=False, height=8.0))])


def build_fern():
    """A fern clump, ~1.3 m tall and 2.4 m across."""
    reset_scene()
    rng = random.Random(3)
    parts = []
    for i in range(9):
        a = math.tau * i / 9 + rng.uniform(-0.2, 0.2)
        parts.append(frond(f"Fern{i}", rng.uniform(1.5, 1.9), (0, 0, 0.12), a, lift=1.1, droop=2.0,
                           m=jmat("LeafLight") if i % 3 == 0 else jmat("Leaf"), leaflets=9, leaflet_len=0.6, seed=i))
    parts.append(sphere("Heart", 0.18, (0, 0, 0.08), scale=(1, 1, 0.6), m=jmat("LeafDark"), segs=8, rings=5))
    save("jungle_fern", [merge("Fern", parts)])


def build_elephant_ear():
    """Elephant-ear plant: big heart-shaped leaves on long stalks, ~2.2 m."""
    reset_scene()
    rng = random.Random(7)
    stalk = jmat("LeafYellow")
    parts = []
    for i in range(7):
        a = math.tau * i / 7 + rng.uniform(-0.2, 0.2)
        h = rng.uniform(1.0, 1.7)
        out = rng.uniform(0.3, 0.6)
        tip = (math.cos(a) * out, math.sin(a) * out, h)
        parts.append(tube(f"Stalk{i}", [(0, 0, 0), (tip[0] * 0.4, tip[1] * 0.4, h * 0.6), tip], 0.035, m=stalk, segs=5))
        parts.append(leaf(f"Ear{i}", rng.uniform(1.0, 1.3), rng.uniform(0.75, 0.95), tip, a, droop=0.9,
                          m=jmat("Leaf") if i % 2 else jmat("LeafDark"), segs=6, curl=0.3))
    save("jungle_elephant_ear", [merge("ElephantEar", parts)])


def build_bush():
    """Flowering shrub, ~1.4 m: clumped leaf balls with pink and orange blooms."""
    reset_scene()
    rng = random.Random(9)
    parts = []
    for i in range(7):
        a = math.tau * i / 7
        d = 0.0 if i == 0 else rng.uniform(0.5, 0.8)
        parts.append(sphere(f"Ball{i}", rng.uniform(0.5, 0.7), (math.cos(a) * d, math.sin(a) * d, 0.55 + rng.uniform(-0.1, 0.25)),
                            scale=(1, 1, 0.8), m=jmat("LeafDark") if i % 2 else jmat("Leaf"), segs=10, rings=6))
    for i in range(10):
        a = rng.uniform(0, math.tau)
        z = rng.uniform(0.6, 1.1)
        r = 0.75 + rng.uniform(-0.1, 0.15)
        m = jmat("Pink", rough=0.5) if i % 2 else jmat("Orange", rough=0.5)
        parts.append(star(f"Bloom{i}", 0.12, 0.04, (math.cos(a) * r, math.sin(a) * r, z), rot=(rng.uniform(-0.5, 0.5), 0, a), m=m))
        parts.append(sphere(f"BloomHeart{i}", 0.04, (math.cos(a) * (r + 0.02), math.sin(a) * (r + 0.02), z), m=jmat("Yellow"), segs=6, rings=4))
    save("jungle_bush", [merge("Bush", parts)])


def build_boulder():
    """Mossy boulder, ~2.4 m across and 1.3 m tall."""
    reset_scene()
    parts = [rock("Rock", 1.3, (0, 0, 0.45), jmat("StoneShade", rough=0.9), seed=4, squash=0.7)]
    parts.append(rock("Moss", 1.05, (0.1, 0.05, 0.75), jmat("Moss", rough=0.9), seed=8, squash=0.42))
    save("jungle_boulder", [merge("Boulder", parts)])


def build_cliff():
    """A cliff buttress, 10 m wide, 9 m tall and 5 m deep, mossy ledges and hanging vines."""
    reset_scene()
    rng = random.Random(12)
    stone, shade, moss = jmat("StoneShade", rough=0.9), jmat("StoneDark", rough=0.9), jmat("Moss", rough=0.9)
    parts = []
    for i in range(14):
        x = rng.uniform(-4.5, 4.5)
        z = rng.uniform(0.5, 8.0)
        r = rng.uniform(1.6, 2.6)
        parts.append(rock(f"Mass{i}", r, (x, rng.uniform(-0.5, 1.5), z), stone if i % 3 else shade, seed=20 + i, squash=1.0))
    for i in range(5):
        parts.append(rock(f"Ledge{i}", rng.uniform(1.2, 1.8), (rng.uniform(-4, 4), -1.0, rng.uniform(2.0, 8.5)), moss, seed=40 + i, squash=0.35))
    for i in range(6):
        parts += drape(f"Vine{i}", (rng.uniform(-4, 4), -1.6, rng.uniform(6.5, 9.0)), rng.uniform(3.0, 5.5), 0.3,
                       jmat("LeafDark"), jmat("Leaf"), seed=60 + i, leaves=4)
    save("jungle_cliff", [merge("Cliff", parts)])


# ---------------------------------------------------------------------------
# Ride: track, cart, boat, tunnel, sign
# ---------------------------------------------------------------------------

def build_track():
    """One 2 m module of mine-cart ride track along X: two rails on three sleepers."""
    reset_scene()
    wood, steel = jmat("TrunkDark", rough=0.9), jmat("Steel", rough=0.35, metal=0.6)
    parts = [box(f"Sleeper{i}", (0.22, 1.5, 0.12), (-0.67 + i * 0.67, 0, 0.06), bevel=0.02, m=wood) for i in range(3)]
    for s in (-1, 1):
        parts.append(box(f"Rail{s}", (2.0, 0.08, 0.1), (0, s * 0.5, 0.17), bevel=0.015, m=steel))
    save("jungle_track", [merge("Track", parts)])


def build_mine_cart():
    """Ride car: a red and gold riveted cart with a padded bench, on wheels. 2.2 x 1.4 x 1.3 m."""
    reset_scene()
    red, dark, gold, steel = jmat("RideRed", rough=0.45), jmat("RideRedDark"), jmat("Gold", rough=0.35, metal=0.5), jmat("SteelDark", metal=0.4)
    parts = [
        box("Body", (2.1, 1.3, 0.8), (0, 0, 0.75), bevel=0.12, segs=3, m=red),
        box("Floor", (1.9, 1.1, 0.1), (0, 0, 0.95), bevel=0.02, m=dark),
        box("Rim", (2.2, 1.4, 0.1), (0, 0, 1.15), bevel=0.05, m=gold),
        box("Bench", (0.5, 1.05, 0.35), (0.45, 0, 1.1), bevel=0.08, m=dark),
        box("BenchBack", (0.14, 1.05, 0.55), (0.75, 0, 1.3), bevel=0.06, m=dark),
        box("LapBar", (0.08, 1.1, 0.08), (0.05, 0, 1.4), bevel=0.03, m=gold),
        box("Chassis", (1.8, 1.0, 0.18), (0, 0, 0.32), bevel=0.04, m=jmat("SteelDark")),
    ]
    for i, x in enumerate((-0.75, 0.75)):
        for s in (-1, 1):
            parts.append(cyl(f"Wheel{i}{s}", 0.22, 0.1, (x, s * 0.5, 0.22), rot=rad(90, 0, 0), segs=14, bevel=0.02, m=steel))
    for i in range(6):
        x = -0.9 + i * 0.36
        parts.append(sphere(f"Rivet{i}", 0.035, (x, -0.66, 0.95), m=gold, segs=6, rings=4))
    parts.append(star("Emblem", 0.16, 0.04, (0, -0.67, 0.68), rot=rad(0, 0, 0), m=gold))
    save("jungle_mine_cart", [merge("MineCart", parts)])


def build_boat():
    """Jungle-cruise launch beached in the lagoon: hull, striped canopy on poles,
    bench seats, a wheel and a life ring. 7 x 2.6 m, canopy 3 m up."""
    reset_scene()
    hull_m, trim, wood = jmat("Teal", rough=0.5), jmat("Cream", rough=0.5), jmat("Bark")
    red, cream = jmat("RideRed", rough=0.6), jmat("Canvas", rough=0.8)
    hull = [(-3.4, 0.4), (-3.0, -0.2), (2.4, -0.25), (3.6, 0.4), (3.6, 1.1), (-3.5, 1.1)]
    parts = [prism("Hull", hull, 2.4, (0, 0, 0), rot=rad(0, 0, 0), m=hull_m, bevel=0.15)]
    # prism extrudes along Y; the outline is (x, z): that is the side profile.
    parts += [
        box("Gunwale", (7.0, 2.6, 0.14), (0.05, 0, 1.15), bevel=0.06, m=trim),
        box("Deck", (6.6, 2.2, 0.1), (0.05, 0, 0.9), bevel=0.02, m=wood),
        box("Stripe", (7.05, 2.45, 0.12), (0.05, 0, 0.8), bevel=0.04, m=red),
    ]
    for i, x in enumerate((-2.6, -0.8, 1.0, 2.6)):
        for s in (-1, 1):
            parts.append(cyl(f"Pole{i}{s}", 0.05, 2.0, (x, s * 1.1, 2.15), segs=8, bevel=0.0, m=trim))
    for i in range(8):
        x = -2.9 + i * 0.75
        parts.append(box(f"Canopy{i}", (0.75, 2.7, 0.08), (x + 0.375, 0, 3.17), bevel=0.02, m=red if i % 2 else cream))
    for i in range(8):
        x = -2.9 + i * 0.75 + 0.375
        parts.append(prism(f"Scallop{i}", [(-0.37, 0), (0.37, 0), (0, -0.22)], 2.72, (x, 0, 3.13), rot=rad(0, 0, 0),
                           m=red if i % 2 else cream))
    for i, x in enumerate((-1.8, -0.2, 1.4)):
        parts.append(box(f"Bench{i}", (0.45, 2.0, 0.35), (x, 0, 1.1), bevel=0.05, m=wood))
    parts += [
        cyl("WheelPost", 0.07, 0.8, (2.8, 0.6, 1.3), segs=8, bevel=0.0, m=wood),
        torus("Wheel", 0.25, 0.04, (2.75, 0.6, 1.75), rot=rad(0, 70, 0), m=wood, major_segs=16, minor_segs=5),
        torus("LifeRing", 0.32, 0.09, (0.2, -1.32, 1.45), rot=rad(90, 0, 0), m=jmat("Orange", rough=0.5), major_segs=18, minor_segs=7),
        box("NamePlate", (1.6, 0.06, 0.32), (-2.2, -1.32, 1.4), bevel=0.03, m=jmat("Gold", rough=0.4)),
        text("Name", "MISS JADE", 0.2, 0.02, (-2.2, -1.36, 1.4), m=jmat("RideRedDark")),
    ]
    save("jungle_boat", [merge("Boat", parts)])


def build_tunnel_mouth():
    """The ride's tunnel mouth: a carved serpent-head arch over the track
    (opening 4 m wide, 4 m tall) set in a mossy rock face 12 m wide."""
    reset_scene()
    stone, shade, moss = jmat("Stone", rough=0.85), jmat("StoneShade", rough=0.9), jmat("Moss", rough=0.9)
    jade = jade_glow()
    rng = random.Random(4)
    parts = []
    # Rock face around the opening (pieces left and right, over the top).
    for i in range(10):
        side = -1 if i % 2 else 1
        parts.append(rock(f"Face{i}", rng.uniform(1.6, 2.4), (side * rng.uniform(3.6, 5.6), rng.uniform(0.6, 1.8), rng.uniform(0.5, 4.5)),
                          shade if i % 3 else stone, seed=80 + i, squash=1.0))
    for i in range(5):
        parts.append(rock(f"Top{i}", rng.uniform(1.5, 2.2), (rng.uniform(-3.5, 3.5), rng.uniform(0.6, 1.6), rng.uniform(5.0, 6.2)), shade,
                          seed=95 + i, squash=0.8))
    # Carved serpent arch.
    parts += [
        box("PillarL", (0.9, 1.0, 4.2), (-2.45, -0.3, 2.1), bevel=0.08, m=stone),
        box("PillarR", (0.9, 1.0, 4.2), (2.45, -0.3, 2.1), bevel=0.08, m=stone),
        box("Lintel", (6.0, 1.1, 1.0), (0, -0.3, 4.6), bevel=0.1, m=stone),
        box("Brow", (2.6, 1.0, 0.9), (0, -0.55, 5.4), bevel=0.2, m=stone),
        sphere("SnoutL", 0.45, (-0.7, -0.95, 5.05), scale=(1, 1, 0.8), m=stone, segs=10, rings=6),
        sphere("SnoutR", 0.45, (0.7, -0.95, 5.05), scale=(1, 1, 0.8), m=stone, segs=10, rings=6),
        sphere("EyeL", 0.22, (-1.0, -1.05, 5.55), m=jade, segs=10, rings=6),
        sphere("EyeR", 0.22, (1.0, -1.05, 5.55), m=jade, segs=10, rings=6),
        box("DarkL", (0.06, 3.0, 4.0), (-2.0, 1.2, 2.0), bevel=0.0, m=jmat("Charcoal")),
        box("DarkR", (0.06, 3.0, 4.0), (2.0, 1.2, 2.0), bevel=0.0, m=jmat("Charcoal")),
        box("DarkTop", (4.0, 3.0, 0.06), (0, 1.2, 4.05), bevel=0.0, m=jmat("Charcoal")),
        box("DarkBack", (4.0, 0.06, 4.1), (0, 2.7, 2.0), bevel=0.0, m=jmat("Charcoal")),
    ]
    for i in range(7):
        x = -2.4 + i * 0.8
        parts.append(cyl(f"Fang{i}", 0.13, 0.5, (x, -0.7, 3.85), rot=rad(180, 0, 0), segs=6, bevel=0.0, m=jmat("Cream"), radius_top=0.01))
    for i in range(8):
        parts += drape(f"Vine{i}", (rng.uniform(-3, 3), -0.9, rng.uniform(4.6, 5.2)), rng.uniform(1.2, 2.6), 0.15,
                       jmat("LeafDark"), jmat("Leaf"), seed=110 + i, leaves=3)
    parts.append(rock("MossCap", 2.8, (0, 0.6, 6.6), moss, seed=120, squash=0.35))
    save("jungle_tunnel_mouth", [merge("TunnelMouth", parts)])


def build_ride_sign():
    """The ride's marquee on two carved posts: 'TEMPLE OF THE JADE IDOL'. 6 m wide, 4.6 m tall."""
    reset_scene()
    wood, stone, gold = jmat("Bark"), jmat("Stone"), jmat("Gold", rough=0.35, metal=0.4)
    parts = [
        box("PostL", (0.5, 0.5, 4.6), (-2.7, 0, 2.3), bevel=0.06, m=stone),
        box("PostR", (0.5, 0.5, 4.6), (2.7, 0, 2.3), bevel=0.06, m=stone),
        box("Board", (5.6, 0.25, 1.5), (0, 0, 3.6), bevel=0.08, m=wood),
        box("Trim", (5.8, 0.2, 1.7), (0, 0.04, 3.6), bevel=0.06, m=gold),
        text("Line1", "TEMPLE OF THE", 0.36, 0.06, (0, -0.16, 3.9), m=jmat("Cream")),
        text("Line2", "JADE IDOL", 0.62, 0.08, (0, -0.16, 3.36), m=jade_glow()),
        sphere("CapL", 0.32, (-2.7, 0, 4.75), m=gold, segs=10, rings=6),
        sphere("CapR", 0.32, (2.7, 0, 4.75), m=gold, segs=10, rings=6),
    ]
    rng = random.Random(6)
    for i in range(4):
        parts += drape(f"Vine{i}", ((-2.75, -2.55, 2.55, 2.75)[i], -0.3, 4.4), rng.uniform(0.6, 1.8), 0.1, jmat("LeafDark"), jmat("Leaf"),
                       seed=130 + i, leaves=3)
    save("jungle_ride_sign", [merge("RideSign", parts)])


# ---------------------------------------------------------------------------
# Explorer camp
# ---------------------------------------------------------------------------

def build_tent():
    """Canvas ridge tent with its front flaps tied open, guy ropes and a
    lantern inside. 3 m long, 2.6 m wide, 2.2 m tall; front faces -Y."""
    reset_scene()
    canvas, dark, rope_m, wood = jmat("Canvas", rough=0.85), jmat("CanvasDark", rough=0.85), jmat("Rope"), jmat("TrunkDark")
    half = 1.3
    h = 2.2
    parts = [
        prism("Body", [(-half, 0), (half, 0), (0.05, h), (-0.05, h)], 3.0, (0, 0.2, 0), m=canvas, bevel=0.03),
        prism("Door", [(-half * 0.55, 0.0), (half * 0.55, 0.0), (0, h * 0.75)], 0.04, (0, -1.32, 0.01), m=jmat("Charcoal")),
        prism("FlapL", [(-half * 0.95, 0.0), (-half * 0.55, 0.0), (-0.05, h * 0.92)], 0.05, (0, -1.38, 0), m=dark),
        prism("FlapR", [(half * 0.55, 0.0), (half * 0.95, 0.0), (0.05, h * 0.92)], 0.05, (0, -1.38, 0), m=dark),
        cyl("PoleF", 0.04, h + 0.3, (0, -1.4, (h + 0.3) / 2), segs=6, bevel=0.0, m=wood),
        cyl("PoleB", 0.04, h + 0.3, (0, 1.75, (h + 0.3) / 2), segs=6, bevel=0.0, m=wood),
        box("Ridge", (0.12, 3.2, 0.1), (0, 0.2, h + 0.02), bevel=0.03, m=dark),
        bulb("Lantern", 0.09, (0, -0.4, 1.3), m=jglow("JungleLanternGlow", "#ffc25a", 3.0)),
    ]
    for s in (-1, 1):
        parts.append(rope(f"GuyF{s}", (0, -1.4, h + 0.25), (s * 1.0, -2.4, 0.02), 0.05, rope_m, radius=0.015))
        parts.append(rope(f"GuyB{s}", (0, 1.75, h + 0.25), (s * 1.0, 2.75, 0.02), 0.05, rope_m, radius=0.015))
        parts.append(box(f"Stake{s}", (0.05, 0.05, 0.25), (s * 1.0, -2.4, 0.1), bevel=0.0, m=wood))
    save("jungle_tent", [merge("Tent", parts)])


def build_crates():
    """Expedition crates: two stencilled wooden boxes and a small one on top. 2 x 1.2 x 1.6 m."""
    reset_scene()
    wood, dark, steel = jmat("Khaki", rough=0.8), jmat("KhakiDark"), jmat("SteelDark", metal=0.4)
    parts = []
    for i, (x, y, z, s) in enumerate(((-0.5, 0, 0.45, 0.9), (0.55, 0.05, 0.45, 0.9), (0.0, 0.0, 1.2, 0.6))):
        parts.append(box(f"Crate{i}", (s, s * 1.15, s), (x, y, z), bevel=0.05, m=wood))
        for k in (-1, 1):
            parts.append(box(f"Slat{i}{k}", (s + 0.02, 0.08, s + 0.02), (x, y + k * s * 0.4, z), bevel=0.02, m=dark))
        parts.append(box(f"Band{i}", (s + 0.03, s * 1.15 + 0.03, 0.06), (x, y, z), bevel=0.01, m=steel))
    parts.append(text("Stencil", "EXPED.", 0.16, 0.01, (-0.5, -0.53, 0.45), m=jmat("RideRedDark")))
    save("jungle_crates", [merge("Crates", parts)])


def build_jeep():
    """Safari jeep, original design: open top with a roll bar, spare wheel,
    zebra-free khaki paint with a red stripe. 4.2 x 2 x 2.1 m; front faces -Y."""
    reset_scene()
    paint, dark, steel, tyre = jmat("Olive", rough=0.5), jmat("KhakiDark"), jmat("Steel", metal=0.5, rough=0.35), jmat("Charcoal", rough=0.8)
    red = jmat("RideRed", rough=0.5)
    glass = mat("JungleJeepGlass", "#9fd8d0", rough=0.1, emit=0.2)
    parts = [
        box("Body", (1.9, 4.0, 0.8), (0, 0, 0.9), bevel=0.14, segs=3, m=paint),
        box("Hood", (1.8, 1.3, 0.3), (0, -1.3, 1.35), bevel=0.1, m=paint),
        box("Stripe", (1.92, 4.02, 0.12), (0, 0, 1.05), bevel=0.04, m=red),
        box("Grille", (1.4, 0.1, 0.5), (0, -2.02, 1.0), bevel=0.04, m=dark),
        box("Bumper", (2.0, 0.22, 0.2), (0, -2.1, 0.6), bevel=0.06, m=steel),
        box("Windshield", (1.7, 0.08, 0.6), (0, -0.6, 1.75), rot=rad(-12, 0, 0), bevel=0.03, m=glass),
        box("ShieldFrame", (1.8, 0.1, 0.08), (0, -0.66, 2.06), rot=rad(-12, 0, 0), bevel=0.02, m=steel),
        box("SeatF", (1.6, 0.5, 0.6), (0, 0.1, 1.45), bevel=0.08, m=jmat("Rust")),
        box("SeatB", (1.6, 0.5, 0.6), (0, 1.2, 1.45), bevel=0.08, m=jmat("Rust")),
        box("Wheel", (0.12, 0.4, 0.06), (-0.4, -0.35, 1.7), rot=rad(-50, 0, 0), bevel=0.02, m=dark),
    ]
    rb = [(-0.85, 1.7, 1.3), (-0.85, 1.7, 2.3), (0.85, 1.7, 2.3), (0.85, 1.7, 1.3)]
    parts.append(tube("RollBar", rb, 0.05, m=steel, segs=8, cap=True))
    for i, y in enumerate((-1.3, 1.3)):
        for s in (-1, 1):
            parts.append(cyl(f"Tyre{i}{s}", 0.45, 0.36, (s * 0.92, y, 0.45), rot=rad(0, 90, 0), segs=16, bevel=0.06, m=tyre))
            parts.append(cyl(f"Hub{i}{s}", 0.2, 0.38, (s * 0.92, y, 0.45), rot=rad(0, 90, 0), segs=10, bevel=0.03, m=steel))
            parts.append(box(f"Arch{i}{s}", (0.3, 1.1, 0.14), (s * 0.95, y, 0.98), bevel=0.05, m=dark))
    parts += [
        cyl("Spare", 0.42, 0.3, (0, 2.15, 1.1), rot=rad(90, 0, 0), segs=16, bevel=0.06, m=tyre),
        cyl("SpareHub", 0.18, 0.32, (0, 2.15, 1.1), rot=rad(90, 0, 0), segs=10, bevel=0.03, m=steel),
        sphere("LampL", 0.14, (-0.6, -2.0, 1.25), m=jglow("JungleJeepLamp", "#fff0c0", 1.6), segs=10, rings=6),
        sphere("LampR", 0.14, (0.6, -2.0, 1.25), m=jglow("JungleJeepLamp", "#fff0c0", 1.6), segs=10, rings=6),
        box("Jerrycan", (0.3, 0.2, 0.45), (0.75, 2.05, 1.3), bevel=0.04, m=red),
    ]
    save("jungle_jeep", [merge("Jeep", parts)])


def build_radio_mast():
    """Camp radio mast: a guyed lattice tower, 9 m, with a dish, a whip aerial
    and a red beacon (JungleBeacon). A radio box at its foot."""
    reset_scene()
    steel, dark = jmat("Steel", metal=0.5, rough=0.4), jmat("SteelDark")
    parts = []
    h = 9.0
    for s in range(3):
        a = math.tau * s / 3
        parts.append(cyl(f"Leg{s}", 0.05, h, (math.cos(a) * 0.35, math.sin(a) * 0.35, h / 2), segs=6, bevel=0.0, m=steel))
    for k in range(9):
        z = 0.5 + k * 0.95
        for s in range(3):
            a0, a1 = math.tau * s / 3, math.tau * (s + 1) / 3
            p0 = (math.cos(a0) * 0.35, math.sin(a0) * 0.35, z)
            p1 = (math.cos(a1) * 0.35, math.sin(a1) * 0.35, z + 0.95)
            parts.append(tube(f"Brace{k}{s}", [p0, p1], 0.02, m=steel, segs=4))
    parts += [
        cyl("Whip", 0.025, 2.4, (0, 0, h + 1.2), segs=6, bevel=0.0, m=dark),
        bulb("Beacon", 0.14, (0, 0, h + 0.15), m=jglow("JungleBeacon", "#ff3a2a", 4.0)),
        cyl("Dish", 0.55, 0.12, (0.3, -0.45, 6.4), rot=rad(70, 0, 20), segs=16, bevel=0.03, m=jmat("Cream"), radius_top=0.25),
        box("RadioBox", (0.9, 0.6, 0.8), (0.9, -0.6, 0.4), bevel=0.06, m=jmat("Olive")),
        box("RadioFace", (0.7, 0.05, 0.4), (0.9, -0.92, 0.5), bevel=0.02, m=dark),
        bulb("RadioLamp", 0.05, (1.15, -0.95, 0.65), m=jglow("JungleRadioLamp", "#7dff6a", 3.0), halo=False),
    ]
    for s in range(3):
        a = math.tau * s / 3 + 0.5
        parts.append(rope(f"Guy{s}", (0, 0, h * 0.75), (math.cos(a) * 4.0, math.sin(a) * 4.0, 0.05), 0.15, jmat("Rope"), radius=0.015))
    save("jungle_radio_mast", [merge("RadioMast", parts)])


def build_camp_table():
    """Folding table with a spread map, a lantern, a compass and a mug. 1.6 x 0.9 m."""
    reset_scene()
    wood, dark = jmat("Bark"), jmat("TrunkDark")
    parts = [box("Top", (1.6, 0.9, 0.06), (0, 0, 0.82), bevel=0.02, m=wood)]
    for s in (-1, 1):
        parts.append(box(f"LegA{s}", (0.06, 0.8, 0.06), (s * 0.65, 0, 0.42), rot=rad(0, 0, 0), bevel=0.01, m=dark))
        parts[-1].rotation_euler = rad(40, 0, 0)
        parts.append(box(f"LegB{s}", (0.06, 0.8, 0.06), (s * 0.65, 0, 0.42), bevel=0.01, m=dark))
        parts[-1].rotation_euler = rad(-40, 0, 0)
    parts += [
        box("Map", (0.9, 0.6, 0.01), (-0.15, 0, 0.86), rot=rad(0, 0, 6), bevel=0.0, m=jmat("Canvas")),
        box("MapMark", (0.12, 0.12, 0.012), (-0.25, 0.05, 0.866), rot=rad(0, 0, 45), bevel=0.0, m=jmat("RideRed")),
        box("Route", (0.5, 0.025, 0.012), (-0.05, -0.1, 0.866), rot=rad(0, 0, 25), bevel=0.0, m=jmat("RideRedDark")),
        cyl("LanternBase", 0.1, 0.06, (0.55, 0.15, 0.88), segs=10, bevel=0.01, m=dark),
        bulb("LanternGlow", 0.08, (0.55, 0.15, 1.0), m=jglow("JungleLanternGlow", "#ffc25a", 3.0)),
        cyl("LanternTop", 0.08, 0.05, (0.55, 0.15, 1.12), segs=10, bevel=0.01, m=dark),
        cyl("Mug", 0.05, 0.1, (0.45, -0.25, 0.9), segs=10, bevel=0.01, m=jmat("TealDark")),
        cyl("Compass", 0.07, 0.03, (0.2, 0.25, 0.86), segs=12, bevel=0.01, m=jmat("Gold", metal=0.5)),
    ]
    save("jungle_camp_table", [merge("CampTable", parts)])


def build_tiki_torch():
    """Bamboo tiki torch, 2.2 m, with a woven cup and a flame globe (lit by the
    level's fire quads and light)."""
    reset_scene()
    bamboo, dark, thatch = jmat("Bamboo"), jmat("BambooDark"), jmat("Thatch")
    parts = [cyl("Pole", 0.06, 2.0, (0, 0, 1.0), segs=8, bevel=0.0, m=bamboo)]
    for i in range(4):
        parts.append(torus(f"Node{i}", 0.064, 0.015, (0, 0, 0.4 + i * 0.45), m=dark, major_segs=10, minor_segs=4))
    parts += [
        cyl("Cup", 0.16, 0.3, (0, 0, 2.08), segs=10, bevel=0.03, m=thatch, radius_top=0.2),
        torus("Weave", 0.19, 0.03, (0, 0, 2.12), m=dark, major_segs=12, minor_segs=4),
    ]
    save("jungle_tiki_torch", [merge("TikiTorch", parts)])


def build_trail_torch():
    """Exit-route torch stake (1.3 m) with a glass flame globe, JungleTorchGlass,
    that the exit script recolours jade when the portal opens."""
    reset_scene()
    bamboo, dark = jmat("Bamboo"), jmat("BambooDark")
    parts = [
        cyl("Pole", 0.045, 1.1, (0, 0, 0.55), segs=8, bevel=0.0, m=bamboo),
        torus("Node", 0.05, 0.012, (0, 0, 0.6), m=dark, major_segs=10, minor_segs=4),
        cyl("Cup", 0.1, 0.12, (0, 0, 1.14), segs=10, bevel=0.02, m=dark, radius_top=0.13),
        sphere("Globe", 0.12, (0, 0, 1.3), scale=(1, 1, 1.35), m=flame_glass(), segs=10, rings=7),
    ]
    save("jungle_trail_torch", [merge("TrailTorch", parts)])


def build_bamboo_fence():
    """2.5 m module of bamboo fence along X: two posts, lashed rails and a row of canes."""
    reset_scene()
    bamboo, dark, rope_m = jmat("Bamboo"), jmat("BambooDark"), jmat("Rope")
    parts = []
    for s in (-1, 1):
        parts.append(cyl(f"Post{s}", 0.08, 1.4, (s * 1.2, 0, 0.7), segs=8, bevel=0.0, m=dark))
    for z in (0.45, 0.95):
        parts.append(cyl(f"Rail{z}", 0.045, 2.5, (0, 0, z), rot=rad(0, 90, 0), segs=6, bevel=0.0, m=bamboo))
    for i in range(9):
        x = -1.0 + i * 0.25
        h = 1.05 + 0.1 * math.sin(i * 1.7)
        parts.append(cyl(f"Cane{i}", 0.035, h, (x, 0.05, h / 2), segs=6, bevel=0.0, m=bamboo))
    for s in (-1, 1):
        parts.append(torus(f"Lash{s}", 0.09, 0.02, (s * 1.2, 0, 0.95), m=rope_m, major_segs=8, minor_segs=4))
    save("jungle_bamboo_fence", [merge("BambooFence", parts)])


def build_rope_rail():
    """2 m module of rope-bridge railing along X: a post and two sagging ropes."""
    reset_scene()
    wood, rope_m = jmat("TrunkDark"), jmat("Rope")
    parts = [
        cyl("Post", 0.07, 1.15, (-1.0, 0, 0.58), segs=8, bevel=0.0, m=wood),
        sphere("Knot", 0.08, (-1.0, 0, 1.15), m=rope_m, segs=8, rings=5),
        rope("RopeTop", (-1.0, 0, 1.05), (1.0, 0, 1.05), 0.12, rope_m, radius=0.03),
        rope("RopeLow", (-1.0, 0, 0.55), (1.0, 0, 0.55), 0.08, rope_m, radius=0.025),
    ]
    for i in range(3):
        x = -0.5 + i * 0.5
        parts.append(cyl(f"Drop{i}", 0.012, 0.5, (x, 0, 0.75), segs=4, bevel=0.0, m=rope_m))
    save("jungle_rope_rail", [merge("RopeRail", parts)])


# ---------------------------------------------------------------------------
# Backdrop
# ---------------------------------------------------------------------------

def build_volcano():
    """Distant smoking volcano: a faceted cone 120 m across and 70 m tall with
    jungle on its lower slopes, a glowing crater rim and a smoke column."""
    reset_scene()
    rng = random.Random(21)
    bm = bmesh.new()
    rings = 7
    segs = 20
    verts = []
    for r in range(rings + 1):
        t = r / rings
        radius = 60.0 * (1 - t) + 7.0 * t
        z = 70.0 * (1 - (1 - t) ** 1.6)
        ring = []
        for s in range(segs):
            a = math.tau * s / segs
            jitter = rng.uniform(0.9, 1.08) if r < rings else 1.0
            ring.append(bm.verts.new((math.cos(a) * radius * jitter, math.sin(a) * radius * jitter, z + (rng.uniform(-2, 2) if 0 < r < rings else 0))))
        verts.append(ring)
    for r in range(rings):
        for s in range(segs):
            f = bm.faces.new((verts[r][s], verts[r][(s + 1) % segs], verts[r + 1][(s + 1) % segs], verts[r + 1][s]))
            f.material_index = 0 if r < 2 else (1 if r < rings - 1 else 2)
    ob = bpy.data.objects.new("Cone", bpy.data.meshes.new("Cone"))
    source_collection().objects.link(ob)
    bm.to_mesh(ob.data)
    bm.free()
    for m in (jmat("LeafDark", rough=0.95), jmat("Ash", rough=0.95), jmat("AshLight", rough=0.95)):
        ob.data.materials.append(m)
    parts = [ob]
    parts.append(torus("Rim", 7.2, 1.2, (0, 0, 70.2), m=jglow("JungleLavaGlow", JUNGLE["Lava"], 2.6), major_segs=20, minor_segs=5))
    smoke = jmat("Ash", rough=1.0)
    for i in range(4):
        z = 74 + i * 7
        parts.append(sphere(f"Smoke{i}", 6.5 - i * 1.2, (i * 4.0, i * 1.5, z), scale=(1, 1, 0.7), m=smoke, segs=10, rings=6))
    save("jungle_volcano", [merge("Volcano", parts)])


ALL = {
    "palm": build_palm, "palm_far": build_palm_far, "canopy_tree": build_canopy_tree, "canopy_far": build_canopy_far,
    "fern": build_fern, "elephant_ear": build_elephant_ear, "bush": build_bush, "boulder": build_boulder, "cliff": build_cliff,
    "track": build_track, "mine_cart": build_mine_cart, "boat": build_boat, "tunnel_mouth": build_tunnel_mouth,
    "ride_sign": build_ride_sign, "tent": build_tent, "crates": build_crates, "jeep": build_jeep, "radio_mast": build_radio_mast,
    "camp_table": build_camp_table, "tiki_torch": build_tiki_torch, "trail_torch": build_trail_torch,
    "bamboo_fence": build_bamboo_fence, "rope_rail": build_rope_rail, "volcano": build_volcano,
}


if __name__ == "__main__":
    wanted = [a for a in sys.argv[1:] if a in ALL] or list(ALL)
    for key in wanted:
        ALL[key]()
