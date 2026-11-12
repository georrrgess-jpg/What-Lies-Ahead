"""Frostpeak Resort props (World 5, Summit Lodge): pines, snowbanks, ski racks,
snowmobiles, fire pits, lanterns, fences, furniture, signs, the snowcat and
the distant peaks.

Each function builds one prop in a fresh scene and saves
art/blender/frost_<name>.blend + art/models/frost_<name>.glb.

    python art/blender/build_frost_props.py            (all props)
    python art/blender/build_frost_props.py pine bench (only these)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from frost_common import *  # noqa: F401,F403


def fir_tier(name, radius, height, z, m, teeth=9, droop=0.28, seed=0):
    """One star-skirted cone tier of a fir tree (apex at z + height)."""
    rng = random.Random(seed)
    bm = bmesh.new()
    apex = bm.verts.new((0, 0, z + height))
    ring = []
    for i in range(teeth * 2):
        a = math.tau * i / (teeth * 2) + rng.uniform(-0.05, 0.05)
        out = i % 2 == 0
        r = radius * (1.0 if out else 0.8)
        dz = -droop if out else 0.05
        ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z + dz)))
    hub = bm.verts.new((0, 0, z + height * 0.18))
    n = len(ring)
    for i in range(n):
        bm.faces.new((ring[i], ring[(i + 1) % n], apex))
        bm.faces.new((ring[(i + 1) % n], ring[i], hub))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = bpy.data.objects.new(name, bpy.data.meshes.new(name))
    source_collection().objects.link(ob)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.materials.append(m)
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def pine_parts(prefix, tiers=4, teeth=9, clumps=True, seed=1):
    rng = random.Random(seed)
    green, light, trunk = fmat("Pine", rough=0.75), fmat("PineLight", rough=0.75), fmat("TimberDark", rough=0.85)
    snow = snow_mat()
    parts = [cyl(prefix + "Trunk", 0.26, 1.8, (0, 0, 0.9), segs=8, bevel=0.0, m=trunk, radius_top=0.2)]
    z = 1.0
    radius = 2.2
    for i in range(tiers):
        h = 2.3 - i * 0.18
        m = green if i % 2 == 0 else light
        parts.append(fir_tier(f"{prefix}Tier{i}", radius, h, z, m, teeth, seed=seed * 10 + i))
        # Snow resting on the upper part of the tier.
        parts.append(fir_tier(f"{prefix}Snow{i}", radius * 0.74, h * 0.62, z + h * 0.36, snow, teeth, droop=0.16, seed=seed * 10 + i + 5))
        if clumps:
            for k in range(3):
                a = math.tau * (k + rng.uniform(0, 1)) / 3
                parts.append(sphere(f"{prefix}Clump{i}{k}", 0.18 * (radius / 2.2) + 0.05,
                                    (math.cos(a) * radius * 0.78, math.sin(a) * radius * 0.78, z + 0.12),
                                    scale=(1.3, 1.3, 0.6), m=snow, segs=6, rings=4))
        z += h * 0.62
        radius *= 0.74
    parts.append(sphere(prefix + "Tuft", 0.2, (0, 0, z + 0.55), scale=(1, 1, 1.3), m=snow, segs=8, rings=5))
    return parts


def build_pine():
    """Snow-laden fir, about 7.5 m tall, 4.4 m across."""
    reset_scene()
    save("frost_pine", [merge("Pine", pine_parts("P_"))])


def build_pine_far():
    """Low-detail fir for the forest on the slopes (one MultiMesh, hundreds of copies)."""
    reset_scene()
    save("frost_pine_far", [merge("PineFar", pine_parts("F_", tiers=3, teeth=6, clumps=False, seed=4))])


def build_snowbank():
    """Chest-high bank of snow, 3.2 x 1.6 m, with a red marker pole stuck in it."""
    reset_scene()
    snow, shade = snow_mat(), mat("FrostSnowShade", FROST["SnowShade"], rough=0.85)
    rng = random.Random(5)
    parts = []
    for i, x in enumerate((-1.0, -0.3, 0.4, 1.05)):
        r = rng.uniform(0.7, 0.85)
        parts.append(sphere(f"Heap{i}", r, (x, rng.uniform(-0.1, 0.1), 0.15), scale=(1.15, 0.95, 1.25), m=snow, segs=14, rings=8))
    parts += [
        sphere("Base", 1.0, (0, 0, 0.0), scale=(1.75, 0.9, 0.45), m=shade, segs=16, rings=8),
        sphere("Crest", 0.5, (0.2, -0.05, 0.95), scale=(1.6, 0.9, 0.55), m=snow, segs=12, rings=6),
    ]
    for i in range(5):
        parts.append(sphere(f"Chunk{i}", rng.uniform(0.12, 0.2), (rng.uniform(-1.5, 1.5), rng.choice((-0.82, 0.82)), 0.08),
                            scale=(1.2, 1, 0.8), m=snow, segs=7, rings=5))
    parts += [
        cyl("Pole", 0.04, 1.8, (1.25, 0.3, 0.8), rot=rad(0, 10, 0), segs=6, bevel=0.0, m=fmat("Red")),
        cyl("PoleBand", 0.045, 0.2, (1.38, 0.3, 1.5), rot=rad(0, 10, 0), segs=6, bevel=0.0, m=fmat("Charcoal")),
    ]
    save("frost_snowbank", [merge("Snowbank", parts)])


def build_ski_rack():
    """Timber ski rack, 3 m long, holding a row of bright skis and two boards."""
    reset_scene()
    wood, dark = fmat("Timber"), fmat("TimberDark")
    colours = [("SkiRed", "#e2343f"), ("SkiCyan", "#3fd4ff"), ("SkiYellow", "#ffd23f"), ("SkiPurple", "#8a4fe0"),
               ("SkiWhite", "#f2f2ff"), ("SkiOrange", "#ff7a2a"), ("SkiGreen", "#3fc46a")]
    parts = []
    for i, x in enumerate((-1.4, 1.4)):
        parts += [
            box(f"Leg{i}A", (0.12, 0.12, 1.5), (x, -0.32, 0.72), rot=rad(-14, 0, 0), bevel=0.03, m=wood),
            box(f"Leg{i}B", (0.12, 0.12, 1.5), (x, 0.32, 0.72), rot=rad(14, 0, 0), bevel=0.03, m=wood),
            box(f"Foot{i}", (0.16, 0.9, 0.1), (x, 0, 0.05), bevel=0.03, m=dark),
        ]
    parts += [
        box("TopRail", (3.0, 0.16, 0.14), (0, 0, 1.44), bevel=0.04, m=wood),
        box("LowRailF", (3.0, 0.1, 0.1), (0, -0.3, 0.3), bevel=0.03, m=dark),
        box("LowRailB", (3.0, 0.1, 0.1), (0, 0.3, 0.3), bevel=0.03, m=dark),
    ]
    parts += snow_cap("TopSnow", (3.0, 0.24, 0.1), (0, 0, 1.5), drips=5, seed=3)
    rng = random.Random(9)
    for i in range(7):
        x = -1.15 + i * 0.38
        name, col = colours[i % len(colours)]
        m = mat(name, col, rough=0.4)
        lean = rng.uniform(10, 16)
        for side, s in (("F", -1), ("B", 1)):
            for k, dx in enumerate((-0.05, 0.05)):
                parts.append(box(f"Ski{i}{side}{k}", (0.08, 0.03, 1.75), (x + dx, s * 0.42, 0.85), rot=rad(s * lean, 0, 0), bevel=0.012, m=m))
            parts.append(box(f"Ski{i}{side}Tip", (0.18, 0.05, 0.12), (x, s * 0.2, 1.68), rot=rad(s * (lean + 40), 0, 0), bevel=0.02, m=m))
    for i, (x, col) in enumerate(((1.65, "#ff3f9f"), (-1.7, "#3fd4ff"))):
        parts.append(box(f"Board{i}", (0.28, 0.05, 1.5), (x, -0.1, 0.78), rot=rad(0, 0, 0), bevel=0.1, segs=3, m=mat(f"Board{i}", col, rough=0.4)))
    save("frost_ski_rack", [merge("SkiRack", parts)])


def build_snowmobile():
    """Red snowmobile, 2.8 m long, front faces -Y."""
    reset_scene()
    red, white, dark = fmat("Red", rough=0.4), fmat("White"), fmat("Charcoal")
    steel = fmat("Steel", rough=0.35, metal=0.5)
    parts = [
        box("Hull", (1.0, 1.7, 0.5), (0, -0.25, 0.55), bevel=0.2, segs=3, m=red),
        box("Nose", (0.9, 0.7, 0.4), (0, -1.05, 0.5), rot=rad(-18, 0, 0), bevel=0.18, segs=3, m=red),
        box("Stripe", (1.02, 1.1, 0.12), (0, -0.4, 0.62), bevel=0.05, m=white),
        box("Seat", (0.62, 1.1, 0.24), (0, 0.55, 0.88), bevel=0.1, segs=3, m=dark),
        box("Tail", (0.9, 0.5, 0.35), (0, 1.0, 0.55), bevel=0.12, m=red),
        box("Track", (0.7, 1.7, 0.36), (0, 0.55, 0.26), bevel=0.15, segs=3, m=dark),
        box("Windshield", (0.8, 0.08, 0.38), (0, -0.55, 1.0), rot=rad(-35, 0, 0), bevel=0.04, m=mat("FrostGlassCyan", "#7fd8ff", rough=0.1, emit=0.25)),
        cyl("Bar", 0.03, 0.9, (0, -0.3, 1.02), rot=rad(0, 90, 0), segs=6, bevel=0.0, m=steel),
        cyl("Stem", 0.04, 0.3, (0, -0.3, 0.86), segs=6, bevel=0.0, m=steel),
        box("Headlight", (0.4, 0.06, 0.14), (0, -1.33, 0.62), rot=rad(-18, 0, 0), bevel=0.04, m=fglow("FrostHeadlight", "#fff3c8", 2.5)),
    ]
    for i, x in enumerate((-0.45, 0.45)):
        parts += [
            box(f"Ski{i}", (0.16, 1.2, 0.06), (x, -1.05, 0.06), bevel=0.03, m=dark),
            box(f"SkiTip{i}", (0.16, 0.25, 0.06), (x, -1.7, 0.14), rot=rad(35, 0, 0), bevel=0.03, m=dark),
            cyl(f"Strut{i}", 0.04, 0.45, (x * 0.85, -0.95, 0.3), segs=6, bevel=0.0, m=steel),
            box(f"Grip{i}", (0.1, 0.1, 0.1), (x * 1.0, -0.3, 1.02), bevel=0.03, m=dark),
        ]
    parts += snow_cap("SeatSnow", (0.5, 0.6, 0.08), (0, 0.75, 1.0), drips=3, seed=2)
    save("frost_snowmobile", [merge("Snowmobile", parts)])


def build_fire_pit():
    """Stone fire ring (1.8 m) with a log teepee and glowing embers (flames are added in Godot)."""
    reset_scene()
    stone, dark = fmat("Stone", rough=0.85), fmat("StoneDark", rough=0.9)
    embers = fglow("FrostEmbers", "#ff6a1f", 3.5)
    rng = random.Random(4)
    parts = [cyl("Bed", 0.72, 0.12, (0, 0, 0.06), segs=16, bevel=0.03, m=mat("FrostAsh", "#2a2230", rough=0.95))]
    for i in range(11):
        a = math.tau * i / 11
        parts.append(box(f"Stone{i}", (0.42, 0.34, 0.4), (math.cos(a) * 0.84, math.sin(a) * 0.84, 0.2),
                         rot=(0, 0, a + rng.uniform(-0.2, 0.2)), bevel=0.12, segs=2, m=stone if i % 3 else dark))
        parts.append(sphere(f"StoneSnow{i}", 0.15, (math.cos(a) * 0.86, math.sin(a) * 0.86, 0.42), scale=(1.3, 1.1, 0.4), m=snow_mat(), segs=6, rings=4))
    for i in range(4):
        a = math.tau * i / 4 + 0.4
        parts += log(f"Log{i}", 0.08, 0.95, (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.4), rot=(math.cos(a + math.pi / 2) * 0.55, math.sin(a + math.pi / 2) * 0.55, 0))
    parts.append(sphere("Embers", 0.42, (0, 0, 0.12), scale=(1, 1, 0.3), m=embers, segs=12, rings=6))
    save("frost_fire_pit", [merge("FirePit", parts)])


def build_fire_table():
    """Stone fire table for the terrace (2.4 x 1.4 m); the flame is added in Godot."""
    reset_scene()
    stone, top = fmat("StoneDark", rough=0.8), fmat("Stone", rough=0.6)
    parts = [
        box("Body", (2.2, 1.2, 0.58), (0, 0, 0.29), bevel=0.08, m=stone),
        box("Top", (2.4, 1.4, 0.12), (0, 0, 0.62), bevel=0.05, m=top),
        box("Trough", (1.5, 0.4, 0.06), (0, 0, 0.68), bevel=0.03, m=mat("FrostAsh", "#2a2230", rough=0.95)),
        box("Glass", (1.4, 0.3, 0.08), (0, 0, 0.7), bevel=0.03, m=fglow("FrostEmbers", "#ff6a1f", 3.5)),
    ]
    save("frost_fire_table", [merge("FireTable", parts)])


def build_lamp():
    """Timber lantern post (3.6 m) with a hanging amber lantern; string lights tie on at 3.3 m."""
    reset_scene()
    wood, dark = fmat("Timber"), fmat("TimberDark")
    iron = fmat("Charcoal", rough=0.5, metal=0.3)
    amber = fglow("FrostLantern", "#ffc46b", 3.2)
    parts = [
        box("Post", (0.2, 0.2, 3.4), (0, 0, 1.7), bevel=0.04, m=wood),
        box("Base", (0.36, 0.36, 0.3), (0, 0, 0.15), bevel=0.05, m=dark),
        box("Arm", (0.9, 0.1, 0.12), (0.4, 0, 3.2), bevel=0.03, m=dark),
        box("Brace", (0.5, 0.08, 0.08), (0.2, 0, 2.95), rot=rad(0, 40, 0), bevel=0.02, m=dark),
        cyl("Hook", 0.015, 0.2, (0.75, 0, 3.05), segs=5, bevel=0.0, m=iron),
        box("LanternTop", (0.32, 0.32, 0.08), (0.75, 0, 2.9), bevel=0.03, m=iron),
        cyl("LanternRoof", 0.24, 0.16, (0.75, 0, 3.0), segs=4, bevel=0.0, m=iron, radius_top=0.04),
        box("LanternGlass", (0.24, 0.24, 0.34), (0.75, 0, 2.68), bevel=0.02, m=amber),
        box("LanternBase", (0.3, 0.3, 0.06), (0.75, 0, 2.49), bevel=0.02, m=iron),
        bulb("LanternHalo", 0.16, (0.75, 0, 2.68), amber),
    ]
    for i, (dx, dy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        parts.append(box(f"Frame{i}", (0.03, 0.03, 0.36), (0.75 + dx * 0.125, dy * 0.125, 2.68), bevel=0.0, m=iron))
    parts += snow_cap("PostSnow", (0.24, 0.24, 0.1), (0, 0, 3.4), drips=0, seed=1)
    parts += snow_cap("ArmSnow", (0.86, 0.14, 0.06), (0.42, 0, 3.26), drips=2, seed=2)
    parts.append(sphere("RoofSnow", 0.12, (0.75, 0, 3.08), scale=(1.3, 1.3, 0.5), m=snow_mat(), segs=8, rings=4))
    save("frost_lamp", [merge("Lamp", parts)])


def build_fence():
    """Split-rail fence module, 2.5 m along X, one post per module (runs tile)."""
    reset_scene()
    wood, dark = fmat("Log"), fmat("TimberDark")
    parts = [
        cyl("Post", 0.1, 1.2, (0, 0, 0.6), segs=8, bevel=0.03, m=dark),
        sphere("PostSnow", 0.12, (0, 0, 1.22), scale=(1.1, 1.1, 0.6), m=snow_mat(), segs=8, rings=4),
    ]
    for i, z in enumerate((0.45, 0.95)):
        parts += log(f"Rail{i}", 0.06, 2.5, (0, 0.02, z), rot=rad(0, 90, 0), m=wood)
    parts += snow_cap("RailSnow", (2.4, 0.13, 0.06), (0, 0.02, 1.0), drips=4, seed=5)
    save("frost_fence", [merge("Fence", parts)])


def build_bench():
    """Half-log bench on two stumps (2 m)."""
    reset_scene()
    parts = [
        box("Seat", (2.0, 0.42, 0.14), (0, 0, 0.46), bevel=0.06, m=fmat("Timber")),
        box("SeatBark", (2.0, 0.44, 0.08), (0, 0, 0.37), bevel=0.04, m=fmat("Log")),
    ]
    for i, x in enumerate((-0.7, 0.7)):
        parts.append(cyl(f"Stump{i}", 0.2, 0.36, (x, 0, 0.18), segs=10, bevel=0.03, m=fmat("Log")))
    parts += snow_cap("Snow", (1.5, 0.3, 0.06), (0.2, 0, 0.53), drips=3, seed=3)
    save("frost_bench", [merge("Bench", parts)])


def build_table():
    """Picnic table with attached benches (long axis along Y, 2.4 m)."""
    reset_scene()
    wood, dark = fmat("Timber"), fmat("TimberDark")
    parts = [box("Top", (0.9, 2.4, 0.08), (0, 0, 0.76), bevel=0.03, m=wood)]
    for i, x in enumerate((-0.7, 0.7)):
        parts.append(box(f"Seat{i}", (0.3, 2.4, 0.07), (x, 0, 0.44), bevel=0.03, m=wood))
    for j, y in enumerate((-0.9, 0.9)):
        parts += [
            box(f"LegA{j}", (0.08, 0.1, 0.9), (-0.32, y, 0.4), rot=rad(0, 30, 0), bevel=0.02, m=dark),
            box(f"LegB{j}", (0.08, 0.1, 0.9), (0.32, y, 0.4), rot=rad(0, -30, 0), bevel=0.02, m=dark),
            box(f"Brace{j}", (1.7, 0.08, 0.08), (0, y, 0.38), bevel=0.02, m=dark),
        ]
    parts += snow_cap("TopSnow", (0.7, 1.9, 0.07), (0, 0.1, 0.8), drips=4, seed=6)
    parts.append(cyl("Mug", 0.06, 0.12, (0.15, -0.6, 0.86), segs=10, bevel=0.01, m=fmat("Red")))
    save("frost_table", [merge("Table", parts)])


def build_heater():
    """Mushroom patio heater (2.4 m) with a glowing element."""
    reset_scene()
    steel, dark = fmat("Steel", rough=0.35, metal=0.6), fmat("SteelDark", rough=0.4, metal=0.4)
    glow_m = fglow("FrostHeaterGlow", "#ff7a3a", 3.0)
    parts = [
        cyl("Base", 0.32, 0.12, (0, 0, 0.06), segs=16, bevel=0.03, m=dark),
        cyl("Tank", 0.2, 0.7, (0, 0, 0.47), segs=14, bevel=0.04, m=steel),
        cyl("Pole", 0.05, 1.4, (0, 0, 1.5), segs=8, bevel=0.0, m=steel),
        cyl("Element", 0.14, 0.32, (0, 0, 2.18), segs=12, bevel=0.02, m=glow_m),
        cyl("Hood", 0.62, 0.2, (0, 0, 2.42), segs=18, bevel=0.03, m=steel, radius_top=0.12),
        sphere("HoodSnow", 0.5, (0, 0, 2.52), scale=(1, 1, 0.25), m=snow_mat(), segs=12, rings=5),
        bulb("ElementHalo", 0.16, (0, 0, 2.18), glow_m),
    ]
    save("frost_heater", [merge("Heater", parts)])


def build_chair():
    """Red Adirondack chair, faces -Y."""
    reset_scene()
    red, dark = fmat("Red", rough=0.5), fmat("RedDark", rough=0.55)
    parts = [box("Seat", (0.66, 0.6, 0.06), (0, 0, 0.36), rot=rad(-8, 0, 0), bevel=0.02, m=red)]
    for i in range(5):
        x = -0.24 + i * 0.12
        parts.append(box(f"Slat{i}", (0.1, 0.05, 0.85), (x, 0.38, 0.72), rot=rad(-20, 0, 0), bevel=0.02, m=red))
    for i, x in enumerate((-0.36, 0.36)):
        parts += [
            box(f"Arm{i}", (0.12, 0.72, 0.04), (x, 0.0, 0.62), bevel=0.02, m=red),
            box(f"LegF{i}", (0.06, 0.06, 0.6), (x, -0.3, 0.3), bevel=0.01, m=dark),
            box(f"LegB{i}", (0.06, 0.06, 0.4), (x, 0.3, 0.2), bevel=0.01, m=dark),
        ]
    parts += snow_cap("SeatSnow", (0.4, 0.3, 0.05), (0, 0.05, 0.4), drips=0, seed=1)
    save("frost_chair", [merge("Chair", parts)])


def build_snowman():
    """Cheerful snowman (1.8 m) with scarf, beanie and stick arms."""
    reset_scene()
    snow = snow_mat()
    coal, carrot = fmat("Charcoal", rough=0.8), mat("FrostCarrot", "#ff8a2a", rough=0.6)
    scarf, hat = fmat("Red", rough=0.7), mat("FrostBeanie", "#3a6fe0", rough=0.75)
    parts = [
        sphere("Base", 0.55, (0, 0, 0.5), scale=(1, 1, 0.92), m=snow, segs=16, rings=10),
        sphere("Middle", 0.4, (0, 0, 1.12), m=snow, segs=14, rings=9),
        sphere("Head", 0.3, (0, 0, 1.6), m=snow, segs=14, rings=9),
        cyl("Nose", 0.06, 0.3, (0, -0.4, 1.58), rot=rad(90, 0, 0), segs=8, bevel=0.0, m=carrot, radius_top=0.002),
        torus("Scarf", 0.27, 0.07, (0, 0, 1.36), m=scarf, major_segs=18, minor_segs=6),
        box("ScarfTail", (0.14, 0.05, 0.4), (0.15, -0.3, 1.18), rot=rad(10, 0, 15), bevel=0.02, m=scarf),
        sphere("Beanie", 0.27, (0, 0, 1.75), scale=(1, 1, 0.8), m=hat, segs=12, rings=7),
        cyl("BeanieCuff", 0.28, 0.1, (0, 0, 1.75), segs=14, bevel=0.03, m=mat("FrostBeanieCuff", "#f6f6ff")),
        sphere("Pompom", 0.08, (0, 0, 2.0), m=mat("FrostBeanieCuff", "#f6f6ff"), segs=8, rings=5),
    ]
    for i, x in enumerate((-0.1, 0.1)):
        parts.append(sphere(f"Eye{i}", 0.035, (x, -0.27, 1.66), m=coal, segs=6, rings=4))
    for i in range(3):
        parts.append(sphere(f"Button{i}", 0.04, (0, -0.39 + i * 0.01, 1.25 - i * 0.16), m=coal, segs=6, rings=4))
    for i, s in enumerate((-1, 1)):
        parts.append(tube(f"Arm{i}", [(s * 0.35, 0, 1.2), (s * 0.7, -0.05, 1.45), (s * 0.85, -0.05, 1.62)], 0.03, m=fmat("TimberDark"), segs=5))
    save("frost_snowman", [merge("Snowman", parts)])


def build_skates():
    """Pond-side bench with two pairs of ice skates."""
    reset_scene()
    wood = fmat("Timber")
    parts = [box("Seat", (1.6, 0.4, 0.08), (0, 0, 0.46), bevel=0.03, m=wood)]
    for i, x in enumerate((-0.65, 0.65)):
        parts.append(box(f"Leg{i}", (0.1, 0.36, 0.42), (x, 0, 0.21), bevel=0.02, m=fmat("TimberDark")))
    for i, (x, col) in enumerate(((-0.35, "#f6f6ff"), (0.3, "#3a3550"))):
        m = mat(f"FrostSkate{i}", col, rough=0.5)
        for k, dy in enumerate((-0.08, 0.08)):
            parts += [
                box(f"Boot{i}{k}", (0.12, 0.26, 0.2), (x + k * 0.15, dy, 0.6), bevel=0.05, m=m),
                box(f"Blade{i}{k}", (0.02, 0.32, 0.05), (x + k * 0.15, dy, 0.48), bevel=0.0, m=fmat("Steel", metal=0.8, rough=0.2)),
            ]
    parts += snow_cap("Snow", (0.6, 0.3, 0.05), (0.45, 0, 0.5), drips=1, seed=2)
    save("frost_skates", [merge("Skates", parts)])


def build_crates():
    """Kitchen supply crates and a milk churn, dusted with snow."""
    reset_scene()
    wood, dark = fmat("TimberLight"), fmat("TimberDark")
    parts = [
        box("CrateA", (0.8, 0.8, 0.7), (-0.35, 0, 0.35), bevel=0.04, m=wood),
        box("CrateB", (0.7, 0.7, 0.6), (0.4, 0.1, 0.3), rot=rad(0, 0, 12), bevel=0.04, m=wood),
        box("CrateC", (0.6, 0.6, 0.5), (-0.3, 0.05, 0.95), rot=rad(0, 0, -8), bevel=0.04, m=wood),
        cyl("Churn", 0.2, 0.6, (0.55, -0.45, 0.3), segs=12, bevel=0.03, m=fmat("Steel", metal=0.6, rough=0.3)),
    ]
    for i, (x, y, z, w) in enumerate(((-0.35, 0, 0.36, 0.8), (0.4, 0.1, 0.3, 0.7))):
        parts.append(box(f"Band{i}", (w + 0.02, w * 0.3, 0.08), (x, y, z), bevel=0.01, m=dark))
    parts += snow_cap("SnowC", (0.55, 0.55, 0.08), (-0.3, 0.05, 1.2), drips=2, seed=4)
    parts += snow_cap("SnowB", (0.6, 0.6, 0.07), (0.4, 0.1, 0.6), drips=2, seed=5)
    save("frost_crates", [merge("Crates", parts)])


def build_logs():
    """Log pile under a snow blanket (2.4 m)."""
    reset_scene()
    parts = []
    rows = ((0.2, (-0.6, -0.2, 0.2, 0.6)), (0.52, (-0.4, 0.0, 0.4)), (0.84, (-0.2, 0.2)))
    for r, (z, xs) in enumerate(rows):
        for i, x in enumerate(xs):
            parts += log(f"Log{r}{i}", 0.19, 2.2, (0, x, z), rot=rad(90, 0, 90 + (i - 1) * 2))
    parts += snow_cap("Snow", (1.0, 2.0, 0.14), (0, 0, 1.0), rot=rad(0, 0, 90), drips=4, seed=8)
    save("frost_logs", [merge("Logs", parts)])


def build_marker():
    """Orange-and-black trail marker pole."""
    reset_scene()
    parts = [cyl("Pole", 0.04, 1.6, (0, 0, 0.8), segs=6, bevel=0.0, m=fmat("Orange"))]
    for i in range(3):
        parts.append(cyl(f"Band{i}", 0.045, 0.14, (0, 0, 0.5 + i * 0.4), segs=6, bevel=0.0, m=fmat("Charcoal")))
    parts.append(box("Flag", (0.02, 0.3, 0.2), (0, 0.15, 1.45), bevel=0.0, m=fglow("FrostReflector", "#ff9a3a", 0.8)))
    save("frost_marker", [merge("Marker", parts)])


def build_trail_lantern():
    """Lantern stake for the lit trail to the exit portal (1.2 m). Its glass uses
    the material 'FrostTrailGlass', which scripts/props/frost_trail_light.gd drives."""
    reset_scene()
    wood, iron = fmat("TimberDark"), fmat("Charcoal", rough=0.5, metal=0.3)
    glass = mat("FrostTrailGlass", "#ffc46b", rough=0.3, emit=1.5)
    parts = [
        box("Stake", (0.1, 0.1, 0.9), (0, 0, 0.45), bevel=0.02, m=wood),
        box("Base", (0.26, 0.26, 0.05), (0, 0, 0.92), bevel=0.02, m=iron),
        box("Glass", (0.2, 0.2, 0.24), (0, 0, 1.07), bevel=0.02, m=glass),
        cyl("Roof", 0.19, 0.12, (0, 0, 1.25), segs=4, bevel=0.0, m=iron, radius_top=0.03),
        sphere("RoofSnow", 0.1, (0, 0, 1.3), scale=(1.3, 1.3, 0.5), m=snow_mat(), segs=8, rings=4),
    ]
    for i, (dx, dy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        parts.append(box(f"Frame{i}", (0.025, 0.025, 0.26), (dx * 0.1, dy * 0.1, 1.07), bevel=0.0, m=iron))
    save("frost_trail_lantern", [merge("TrailLantern", parts)])


def build_run_arch():
    """'SUMMIT RUN' finish arch, 10 m wide, bulbs along the banner."""
    reset_scene()
    wood, dark = fmat("Timber"), fmat("TimberDark")
    red, white = fmat("Red", rough=0.5), fmat("White")
    amber = fglow("FrostBulbAmber", "#ffc46b", 3.0)
    parts = []
    for i, x in enumerate((-4.4, 4.4)):
        parts += [
            box(f"Post{i}", (0.4, 0.4, 4.6), (x, 0, 2.3), bevel=0.06, m=wood),
            box(f"Foot{i}", (0.7, 0.7, 0.4), (x, 0, 0.2), bevel=0.06, m=dark),
        ]
        parts += snow_cap(f"PostSnow{i}", (0.44, 0.44, 0.14), (x, 0, 4.6), drips=0, seed=i)
    parts += [
        box("Beam", (9.4, 0.36, 0.36), (0, 0, 4.3), bevel=0.06, m=dark),
        box("Banner", (7.6, 0.12, 1.2), (0, -0.05, 3.5), bevel=0.05, m=red),
        box("BannerTrim", (7.8, 0.1, 0.12), (0, -0.08, 2.88), bevel=0.02, m=white),
        text("Label", "SUMMIT RUN", 0.78, 0.06, (0, -0.15, 3.42), m=white),
        text("LabelBack", "SUMMIT RUN", 0.78, 0.06, (0, 0.05, 3.42), rot=(0, 0, math.pi), m=white),
    ]
    parts += snow_cap("BeamSnow", (9.0, 0.4, 0.14), (0, 0, 4.48), drips=8, seed=9)
    parts += bulb_row("ArchBulb", (-3.6, -0.14, 4.18), (3.6, -0.14, 4.18), 14, 0.07, amber)
    save("frost_run_arch", [merge("RunArch", parts)])


def build_signpost():
    """Direction post with arrow signs to the lodge, gondola and chairlift."""
    reset_scene()
    wood = fmat("TimberDark")
    signs = [("LODGE", 1.95, 0, "#e2343f"), ("GONDOLA", 1.6, 180, "#2f7fc0"), ("CHAIRLIFT", 1.25, 95, "#2c7258")]
    parts = [box("Post", (0.16, 0.16, 2.6), (0, 0, 1.3), bevel=0.03, m=wood)]
    parts += snow_cap("PostSnow", (0.2, 0.2, 0.1), (0, 0, 2.6), drips=0)
    for i, (label, z, yaw, col) in enumerate(signs):
        board = mat(f"FrostSign{i}", col, rough=0.5)
        piece = [
            prism(f"Arrow{i}", [(-0.05, -0.16), (0.82, -0.16), (1.02, 0.0), (0.82, 0.16), (-0.05, 0.16)], 0.06, (0, 0, z), m=board, bevel=0.015),
            text(f"Label{i}", label, 0.13, 0.02, (0.46, -0.045, z), m=fmat("White")),
            text(f"LabelB{i}", label, 0.13, 0.02, (0.46, 0.045, z), rot=(0, 0, math.pi), m=fmat("White")),
        ]
        parts += place(piece, rot_z=math.radians(yaw))
    save("frost_signpost", [merge("Signpost", parts)])


def build_resort_sign():
    """Big 'FROSTPEAK' resort sign with a mountain logo, timber frame and bulbs."""
    reset_scene()
    wood, dark = fmat("Timber"), fmat("TimberDark")
    navy, white, red = fmat("Navy", rough=0.5), fmat("White"), fmat("Red")
    amber = fglow("FrostBulbAmber", "#ffc46b", 3.0)
    parts = []
    for i, x in enumerate((-2.2, 2.2)):
        parts.append(box(f"Leg{i}", (0.3, 0.3, 3.0), (x, 0, 1.5), bevel=0.05, m=wood))
    parts += [
        box("Board", (4.8, 0.2, 1.5), (0, 0, 2.2), bevel=0.08, m=navy),
        box("Frame", (5.0, 0.16, 1.7), (0, 0.04, 2.2), bevel=0.06, m=dark),
        text("Name", "FROSTPEAK", 0.62, 0.06, (0.35, -0.12, 2.38), m=white),
        text("Sub", "RESORT  ·  EST. 1962", 0.2, 0.04, (0.35, -0.12, 1.78), m=mat("FrostSignCyan", "#5ee8ff", emit=0.8)),
        prism("Logo", [(-0.42, -0.3), (0.0, 0.32), (0.18, 0.06), (0.3, 0.2), (0.5, -0.3)], 0.06, (-1.85, -0.12, 2.2), m=white),
        prism("LogoCap", [(-0.12, 0.14), (0.0, 0.32), (0.1, 0.17)], 0.08, (-1.85, -0.13, 2.2), m=red),
    ]
    parts += snow_cap("TopSnow", (4.8, 0.3, 0.14), (0, 0, 3.05), drips=8, seed=12)
    parts += bulb_row("SignBulb", (-2.3, -0.14, 2.98), (2.3, -0.14, 2.98), 12, 0.065, amber)
    save("frost_resort_sign", [merge("ResortSign", parts)])


def build_telescope():
    """Coin-operated viewing binoculars at the lookout."""
    reset_scene()
    body, dark = mat("FrostViewer", "#2f7fc0", rough=0.4), fmat("Charcoal")
    parts = [
        cyl("Pole", 0.07, 1.0, (0, 0, 0.5), segs=10, bevel=0.0, m=dark),
        cyl("Foot", 0.25, 0.08, (0, 0, 0.04), segs=12, bevel=0.02, m=dark),
        box("Head", (0.5, 0.36, 0.3), (0, 0, 1.15), bevel=0.1, segs=3, m=body),
        cyl("EyeL", 0.07, 0.18, (-0.12, 0.24, 1.18), rot=rad(90, 0, 0), segs=10, bevel=0.02, m=dark),
        cyl("EyeR", 0.07, 0.18, (0.12, 0.24, 1.18), rot=rad(90, 0, 0), segs=10, bevel=0.02, m=dark),
        cyl("LensL", 0.1, 0.12, (-0.12, -0.22, 1.15), rot=rad(90, 0, 0), segs=10, bevel=0.02, m=dark),
        cyl("LensR", 0.1, 0.12, (0.12, -0.22, 1.15), rot=rad(90, 0, 0), segs=10, bevel=0.02, m=dark),
    ]
    parts.append(sphere("Snow", 0.24, (0, 0, 1.3), scale=(1.1, 0.8, 0.3), m=snow_mat(), segs=8, rings=4))
    save("frost_telescope", [merge("Telescope", parts)])


def build_snowcat():
    """Piste groomer: red cab on wide tracks with a front blade (5 m long, faces -Y)."""
    reset_scene()
    red, white, dark = fmat("Red", rough=0.45), fmat("White"), fmat("Charcoal")
    glass = mat("FrostCabGlass", "#ffd08a", rough=0.2, emit=1.2)
    parts = [
        box("Body", (2.4, 3.2, 1.0), (0, 0.2, 1.3), bevel=0.15, m=red),
        box("Cab", (2.0, 1.6, 1.2), (0, -0.4, 2.3), bevel=0.15, m=red),
        box("Glass", (1.9, 1.5, 0.7), (0, -0.42, 2.45), bevel=0.08, m=glass),
        box("Stripe", (2.42, 3.0, 0.16), (0, 0.2, 1.45), bevel=0.04, m=white),
        box("Blade", (3.2, 0.3, 0.9), (0, -2.0, 0.55), rot=rad(-10, 0, 0), bevel=0.08, m=fmat("Yellow")),
        box("Tiller", (2.6, 0.7, 0.5), (0, 2.1, 0.5), bevel=0.1, m=dark),
        cyl("Beacon", 0.1, 0.16, (0, -0.4, 3.0), segs=10, bevel=0.02, m=fglow("FrostBeacon", "#ff9a2a", 3.0)),
    ]
    for i, x in enumerate((-1.25, 1.25)):
        parts.append(box(f"Track{i}", (0.8, 3.6, 0.9), (x, 0.1, 0.45), bevel=0.3, segs=3, m=dark))
    parts += snow_cap("CabSnow", (1.9, 1.5, 0.12), (0, -0.4, 2.9), drips=4, seed=3)
    save("frost_snowcat", [merge("Snowcat", parts)])


def peak_massif(name, seed, summits, size=110.0, height=80.0, grid=20):
    """Faceted mountain massif: a few gaussian summits on a jittered grid that
    falls to nothing at the border. Snow on the high, gentle faces; rock elsewhere."""
    rng = random.Random(seed)
    rock, rock_dark = mat("FrostPeakRock", "#4a4472", rough=0.9), mat("FrostPeakRockDark", "#342f58", rough=0.9)
    snow = mat("FrostPeakSnow", "#d9d8f6", rough=0.85)
    tops = [(0.0, 0.0, height, size * 0.26)]
    for _ in range(summits - 1):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.18, 0.32) * size
        tops.append((math.cos(a) * d, math.sin(a) * d * 0.7, height * rng.uniform(0.5, 0.8), size * rng.uniform(0.14, 0.22)))
    half = size / 2
    step = size / grid
    bm = bmesh.new()
    verts = {}
    for j in range(grid + 1):
        for i in range(grid + 1):
            edge = i in (0, grid) or j in (0, grid)
            x = -half + i * step + (0 if edge else rng.uniform(-0.3, 0.3) * step)
            y = -half + j * step + (0 if edge else rng.uniform(-0.3, 0.3) * step)
            h = 0.0
            for tx, ty, th, tr in tops:
                dist = math.hypot(x - tx, y - ty)
                h = max(h, th * math.exp(-(dist / tr) ** 1.4))
            border = min(i, j, grid - i, grid - j) / (grid * 0.5)
            h *= min(1.0, border * 2.2) ** 0.8
            h += (rng.uniform(-1, 1) * 2.5 * (h / height + 0.2)) if not edge else -6.0
            verts[(i, j)] = bm.verts.new((x, y, h))
    for j in range(grid):
        for i in range(grid):
            a, b, c, d = verts[(i, j)], verts[(i + 1, j)], verts[(i + 1, j + 1)], verts[(i, j + 1)]
            if (i + j) % 2:
                bm.faces.new((a, b, c))
                bm.faces.new((a, c, d))
            else:
                bm.faces.new((a, b, d))
                bm.faces.new((b, c, d))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in (rock, rock_dark, snow):
        me.materials.append(m)
    snow_line = height * 0.38
    for p in me.polygons:
        p.use_smooth = False
        zc = sum(me.vertices[v].co.z for v in p.vertices) / len(p.vertices)
        if zc > snow_line + rng.uniform(-8, 8) and p.normal.z > 0.42:
            p.material_index = 2
        elif p.normal.z < 0.55 or rng.random() < 0.35:
            p.material_index = 1
        if p.normal.z < 0:
            p.flip()
    ob = bpy.data.objects.new(name, me)
    export_collection().objects.link(ob)
    return ob


def build_peak():
    """Distant massif with a dominant summit (~110 m across, 80 m tall)."""
    reset_scene()
    save("frost_peak", [peak_massif("Peak", 17, 3)])


def build_peak_b():
    """A broader, jagged range for the flanks of the valley."""
    reset_scene()
    save("frost_peak_b", [peak_massif("PeakB", 29, 5, size=140.0, height=62.0, grid=22)])


BUILDERS = {
    "pine": build_pine, "pine_far": build_pine_far, "snowbank": build_snowbank, "ski_rack": build_ski_rack,
    "snowmobile": build_snowmobile, "fire_pit": build_fire_pit, "fire_table": build_fire_table, "lamp": build_lamp,
    "fence": build_fence, "bench": build_bench, "table": build_table, "heater": build_heater, "chair": build_chair,
    "snowman": build_snowman, "skates": build_skates, "crates": build_crates, "logs": build_logs, "marker": build_marker, "trail_lantern": build_trail_lantern,
    "run_arch": build_run_arch, "signpost": build_signpost, "resort_sign": build_resort_sign,
    "telescope": build_telescope, "snowcat": build_snowcat, "peak": build_peak, "peak_b": build_peak_b,
}


if __name__ == "__main__":
    wanted = [a for a in sys.argv[1:] if a in BUILDERS] or list(BUILDERS)
    for key in wanted:
        BUILDERS[key]()
