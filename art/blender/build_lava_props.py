"""Volcano Isle props (World 9, Lava Lagoon): palms, tiki totems and torches,
basalt boulders, planters, crates, loungers, parasols, bamboo railings, the
tiki bar, surf racks, signposts, the stone bridges and the exit-trail torches.

Each function builds one prop in a fresh scene and saves
art/blender/lava_<name>.blend + art/models/lava_<name>.glb.

    python art/blender/build_lava_props.py              (all props)
    python art/blender/build_lava_props.py palm totem   (only these)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lava_common import *  # noqa: F401,F403

# Stone bridge over the lava river: run along -Y (Godot +Z) from the high end to the foot.
BRIDGE_W = 4.0
BRIDGE_RUN = 8.5
BRIDGE_RISE = 2.0


def palm_parts(prefix, height=7.0, lean=1.4, seed=1, fronds=11):
    rng = random.Random(seed)
    trunk_m, ring_m = lmat("Palm", rough=0.85), lmat("PalmDark", rough=0.85)
    pts = []
    for i in range(9):
        t = i / 8
        pts.append((lean * t * t, 0.0, height * t))
    parts = [tube(prefix + "Trunk", pts, 0.26, m=trunk_m, segs=9, radius_end=0.17)]
    for i in range(1, 15):
        t = i / 15
        x = lean * t * t
        parts.append(cyl(f"{prefix}Ring{i}", 0.27 - 0.09 * t, 0.07, (x, 0, height * t), rot=(0, math.atan2(2 * lean * t, height), 0),
                         segs=9, bevel=0.0, m=ring_m))
    top = (lean, 0.0, height)
    green, dark, light = lmat("Leaf", rough=0.7), lmat("LeafDark", rough=0.7), lmat("LeafLight", rough=0.7)
    for k in range(fronds):
        yaw = math.tau * k / fronds + rng.uniform(-0.15, 0.15)
        m = (green, dark, light)[k % 3]
        parts.append(frond(f"{prefix}Frond{k}", top, yaw, rng.uniform(2.6, 3.4), droop=rng.uniform(0.45, 0.7), m=m, seed=seed * 31 + k))
    for k in range(4):
        a = math.tau * k / 4 + 0.4
        parts.append(sphere(f"{prefix}Nut{k}", 0.16, (lean + math.cos(a) * 0.22, math.sin(a) * 0.22, height - 0.22), m=lmat("Coconut"), segs=8, rings=6))
    return parts


def build_palm():
    """Leaning coconut palm, ~7.6 m tall; trunk base at the origin."""
    reset_scene()
    save("lava_palm", [merge("Palm", palm_parts("P_"))])


def build_palm_b():
    """Taller, straighter palm for the groves and the skyline."""
    reset_scene()
    save("lava_palm_b", [merge("PalmB", palm_parts("Q_", height=9.0, lean=0.7, seed=5, fronds=12))])


def build_totem():
    """Carved tiki totem, 3.4 m: three stacked faces, a winged crest, painted bands.
    Footprint ~0.9 m; collide with a 0.5 m cylinder."""
    reset_scene()
    wood, dark, light = lmat("Tiki", rough=0.75), lmat("TikiDark", rough=0.75), lmat("TikiLight", rough=0.75)
    teal, yellow = lmat("Teal", rough=0.5), lmat("Yellow", rough=0.5)
    p = [cyl("Base", 0.5, 0.3, (0, 0, 0.15), segs=10, bevel=0.04, m=lmat("Basalt", rough=0.85))]
    z = 0.3
    for i, (h, style, paint) in enumerate(((1.05, 1, teal), (0.95, 0, yellow), (0.9, 2, teal))):
        p.append(box(f"Block{i}", (0.78, 0.7, h), (0, 0, z + h / 2), bevel=0.08, segs=3, m=wood if i % 2 == 0 else light))
        p += tiki_face(f"F{i}", 0.7, h, (0, -0.35, z + h / 2), wood=wood if i % 2 == 0 else light, paint=paint, dark=dark, style=style)
        p += place(tiki_face(f"B{i}", 0.7, h, (0, -0.35, z + h / 2), wood=wood if i % 2 == 0 else light, paint=paint, dark=dark,
                             style=(style + 1) % 3), rot_z=math.pi)
        p.append(box(f"Band{i}", (0.84, 0.76, 0.06), (0, 0, z + h - 0.03), bevel=0.02, m=dark))
        z += h
    # Crest: flared wings and a crown of feathers.
    p += [
        prism("WingL", [(0, 0), (0.75, 0.3), (0.8, 0.6), (0, 0.4)], 0.16, (0.32, 0, z - 0.55), m=dark, bevel=0.03),
        prism("WingR", [(0, 0), (-0.75, 0.3), (-0.8, 0.6), (0, 0.4)], 0.16, (-0.32, 0, z - 0.55), m=dark, bevel=0.03),
        box("Cap", (0.86, 0.78, 0.16), (0, 0, z + 0.08), bevel=0.05, m=dark),
    ]
    for k, (x, c) in enumerate(((-0.24, lmat("Pink")), (0.0, yellow), (0.24, teal))):
        p.append(prism(f"Feather{k}", [(-0.09, 0), (0.09, 0), (0.05, 0.55), (0, 0.62), (-0.05, 0.55)], 0.06, (x, 0, z + 0.16),
                       rot=(0, math.radians(-x * 40), 0), m=c, bevel=0.02))
    save("lava_totem", [merge("Totem", p)])


def torch_parts(prefix, height, glow_m):
    p = bamboo(prefix + "Pole", (0, 0, 0), (0, 0, height - 0.25), 0.055)
    p += [
        cyl(prefix + "Bowl", 0.17, 0.26, (0, 0, height - 0.12), segs=10, bevel=0.03, m=lmat("TikiDark"), radius_top=0.21),
        torus(prefix + "Wrap", 0.075, 0.025, (0, 0, height - 0.3), m=lmat("Rope", rough=0.9), major_segs=10, minor_segs=5),
        cyl(prefix + "Fuel", 0.18, 0.04, (0, 0, height + 0.01), segs=10, bevel=0.0, m=glow_m),
    ]
    return p


def build_torch():
    """Bamboo tiki torch, 2.5 m (the level adds the flame at the top)."""
    reset_scene()
    save("lava_torch", [merge("Torch", torch_parts("T_", 2.5, lglow("LavaTorchCoal", "#ff8a2a", 3.0)))])


def build_exit_torch():
    """Short torch stake for the trail to the portal; its bowl glows through the
    'LavaExitGlow' surface (driven by scripts/props/lava_exit_torch.gd)."""
    reset_scene()
    p = torch_parts("E_", 1.3, lglow("LavaExitGlow", "#ff9a3a", 2.0))
    p.append(sphere("E_Flame", 0.09, (0, 0, 1.38), scale=(1, 1, 1.5), m=mat("LavaExitGlow")))
    save("lava_exit_torch", [merge("ExitTorch", p)])


def build_boulder():
    """Basalt boulder pile, ~2.6 x 1.6 m, 1.4 m tall (chest-high cover)."""
    reset_scene()
    b, light = lmat("Basalt", rough=0.85), lmat("BasaltLight", rough=0.85)
    p = [rock("A", 0.95, (0.35, 0, 0.55), seed=3, m=b, scale=(1.1, 0.85, 0.95)),
         rock("B", 0.75, (-0.7, 0.1, 0.4), seed=5, m=light, scale=(1.0, 0.9, 0.9)),
         rock("C", 0.45, (1.1, -0.4, 0.22), seed=7, m=b)]
    save("lava_boulder", [merge("Boulder", p)])


def build_boulder_b():
    """A tall basalt column cluster, ~1.8 m wide, 2.4 m tall."""
    reset_scene()
    b, light, dark = lmat("Basalt", rough=0.85), lmat("BasaltLight", rough=0.85), lmat("BasaltDark", rough=0.85)
    p = []
    for i, (x, y, h, r) in enumerate(((0, 0, 2.4, 0.42), (0.6, 0.2, 1.8, 0.38), (-0.55, 0.25, 1.5, 0.4), (0.15, -0.55, 1.1, 0.36), (-0.4, -0.45, 0.7, 0.34))):
        p.append(cyl(f"Col{i}", r, h, (x, y, h / 2), segs=6, bevel=0.05, m=(b, light, dark)[i % 3]))
    save("lava_boulder_b", [merge("BoulderB", p)])


def build_pebble():
    """A small basalt rock for pool rims and scatter (MultiMesh)."""
    reset_scene()
    save("lava_pebble", [merge("Pebble", [rock("R", 0.5, (0, 0, 0.3), seed=11, m=lmat("Basalt", rough=0.85), scale=(1.2, 1.0, 0.8))])])


def build_planter():
    """Basalt planter (1.6 x 1.6 x 0.7 m) of monstera leaves and hibiscus."""
    reset_scene()
    rng = random.Random(4)
    stone, soil = lmat("BasaltLight", rough=0.85), lmat("BasaltDark", rough=0.9)
    p = [box("Box", (1.6, 1.6, 0.7), (0, 0, 0.35), bevel=0.08, m=stone),
         box("Soil", (1.4, 1.4, 0.05), (0, 0, 0.68), bevel=0.0, m=soil),
         box("Lip", (1.7, 1.7, 0.08), (0, 0, 0.72), bevel=0.03, m=lmat("Basalt"))]
    for k in range(9):
        a = math.tau * k / 9 + rng.uniform(-0.2, 0.2)
        p.append(frond(f"Leaf{k}", (0, 0, 0.7), a, rng.uniform(0.8, 1.2), droop=0.2, width=0.34,
                       m=(lmat("Leaf"), lmat("LeafDark"), lmat("LeafLight"))[k % 3], seed=k + 3, leaflets=4))
    for k in range(5):
        a = math.tau * k / 5 + 0.3
        p += flower(f"Fl{k}", (math.cos(a) * 0.5, math.sin(a) * 0.5, 1.0 + 0.1 * (k % 2)), 0.13)
    save("lava_planter", [merge("Planter", p)])


def build_crates():
    """Bamboo-strapped supply crates, a rum barrel and coconuts (~1.8 x 1.2 x 1.3 m)."""
    reset_scene()
    wood, dark, bam = lmat("TikiLight"), lmat("TikiDark"), lmat("Bamboo", rough=0.5)
    p = [box("CrateA", (1.0, 1.0, 0.8), (-0.35, 0, 0.4), bevel=0.05, m=wood),
         box("CrateB", (0.8, 0.8, 0.55), (-0.4, 0.05, 1.08), rot=(0, 0, 0.2), bevel=0.05, m=wood)]
    for i, (x, z, w, h) in enumerate(((-0.35, 0.4, 1.0, 0.8), (-0.4, 1.08, 0.8, 0.55))):
        p.append(box(f"Strap{i}", (w + 0.04, 0.12, h + 0.04), (x, 0, z), rot=(0, 0, 0.2 if i else 0), bevel=0.01, m=bam))
        p.append(text(f"Stamp{i}", "LAVA" if i == 0 else "RUM", 0.18, 0.02, (x, -w / 2 - 0.02, z), rot=(0, 0, 0.2 if i else 0), m=dark))
    p += [cyl("Barrel", 0.4, 0.95, (0.55, 0.05, 0.475), segs=14, bevel=0.04, m=wood),
          torus("Hoop0", 0.405, 0.03, (0.55, 0.05, 0.2), m=dark, major_segs=14, minor_segs=4),
          torus("Hoop1", 0.405, 0.03, (0.55, 0.05, 0.75), m=dark, major_segs=14, minor_segs=4)]
    for k in range(4):
        p.append(sphere(f"Nut{k}", 0.15, (0.35 + 0.22 * (k % 2), -0.5 + 0.1 * k, 0.14), m=lmat("Coconut"), segs=8, rings=6))
    save("lava_crates", [merge("Crates", p)])


def build_lounger():
    """Wooden sun lounger with a striped towel (0.8 x 2.0 m)."""
    reset_scene()
    wood, dark = lmat("TikiLight"), lmat("TikiDark")
    p = [box("Bed", (0.75, 1.3, 0.08), (0, 0.25, 0.38), bevel=0.02, m=wood),
         box("Back", (0.75, 0.7, 0.08), (0, -0.62, 0.62), rot=(math.radians(-45), 0, 0), bevel=0.02, m=wood)]
    for x in (-0.33, 0.33):
        for y in (-0.55, 0.85):
            p.append(box(f"Leg{x}{y}", (0.06, 0.06, 0.36), (x, y, 0.18), bevel=0.01, m=dark))
    for i in range(4):
        p.append(box(f"Towel{i}", (0.6, 0.3, 0.03), (0, 0.65 - i * 0.3, 0.435), bevel=0.01, m=(lmat("Teal"), lmat("Cream"))[i % 2]))
    save("lava_lounger", [merge("Lounger", p)])


def build_parasol():
    """Thatch beach parasol on a bamboo pole (2.7 m, 1.5 m radius)."""
    reset_scene()
    p = bamboo("Pole", (0, 0, 0), (0, 0, 2.5), 0.06)
    p += thatch_roof("Roof", 1.5, 0.75, 1.95, layers=2, seed=3)
    save("lava_parasol", [merge("Parasol", p)])


def build_rail():
    """One 2.5 m module of bamboo railing (1.1 m), drawn along X (MultiMesh runs)."""
    reset_scene()
    p = []
    for x in (-1.25, 0.0):
        p += bamboo(f"Post{x}", (x + 0.06, 0, 0), (x + 0.06, 0, 1.15), 0.07, joints=False)
        p.append(sphere(f"Cap{x}", 0.08, (x + 0.06, 0, 1.16), m=lmat("BambooDark"), segs=8, rings=4))
    for z in (0.5, 1.02):
        p += bamboo(f"Rail{z}", (-1.25, 0, z), (1.25, 0, z), 0.05, joints=False)
    for k in range(4):
        x = -1.0 + k * 0.62
        p.append(torus(f"Lash{k}", 0.065, 0.016, (x if k % 2 else -1.19, 0, 1.02), rot=rad(0, 90, 0), m=lmat("Rope", rough=0.9),
                       major_segs=8, minor_segs=4))
    save("lava_rail", [merge("Rail", p)])


def build_kerb():
    """2.5 m module of the lava-river bank wall: a rough basalt parapet 0.95 m tall,
    0.7 m thick, glowing at its foot. Along X; MultiMesh runs."""
    reset_scene()
    rng = random.Random(12)
    b, light = lmat("Basalt", rough=0.85), lmat("BasaltLight", rough=0.85)
    p = [box("Core", (2.5, 0.6, 0.85), (0, 0, 0.42), bevel=0.06, m=b)]
    for k in range(4):
        x = -0.95 + k * 0.63 + rng.uniform(-0.08, 0.08)
        p.append(rock(f"Cap{k}", 0.38, (x, rng.uniform(-0.05, 0.05), 0.82), seed=20 + k, m=light if k % 2 else b, scale=(1.1, 0.95, 0.45), jitter=0.2))
    save("lava_kerb", [merge("Kerb", p)])


def build_bar():
    """The 'Lava Lounge' tiki bar: an open pavilion 7 x 4.6 m under a hipped thatch
    roof (eaves at 3.1 m), a U-shaped bamboo counter open to the north, shelves of
    glowing bottles, stools and a carved sign. Collision is set by the level."""
    reset_scene()
    wood, dark, bam = lmat("Tiki"), lmat("TikiDark"), lmat("Bamboo", rough=0.5)
    p = []
    for x in (-3.3, 3.3):
        for y in (-2.1, 2.1):
            p.append(box(f"Post{x}{y}", (0.28, 0.28, 3.2), (x, y, 1.6), bevel=0.05, m=dark))
            p += tiki_face(f"PF{x}{y}", 0.26, 0.6, (x, y - 0.15, 2.5), wood=wood, paint=lmat("Teal"), dark=dark, style=int(x > 0))
    p += [box("BeamF", (6.9, 0.24, 0.3), (0, -2.1, 3.1), bevel=0.04, m=dark), box("BeamB", (6.9, 0.24, 0.3), (0, 2.1, 3.1), bevel=0.04, m=dark),
          box("BeamL", (0.24, 4.4, 0.3), (-3.3, 0, 3.1), bevel=0.04, m=dark), box("BeamR", (0.24, 4.4, 0.3), (3.3, 0, 3.1), bevel=0.04, m=dark)]
    p += thatch_hip("Roof", 6.6, 4.2, 1.9, 3.2, seed=4)
    # U counter: front (south, -Y) and two sides; barkeep space behind it.
    top = lmat("TikiLight")
    for name, size, loc in (("CounterF", (5.4, 0.7, 1.1), (0, -1.2, 0.55)), ("CounterL", (0.7, 2.0, 1.1), (-2.35, 0.15, 0.55)),
                            ("CounterR", (0.7, 2.0, 1.1), (2.35, 0.15, 0.55))):
        p.append(box(name, size, loc, bevel=0.05, m=bam))
        p.append(box(name + "Top", (size[0] + 0.16, size[1] + 0.16, 0.08), (loc[0], loc[1], 1.14), bevel=0.03, m=top))
    for i in range(12):
        p.append(cyl(f"Slat{i}", 0.05, 1.0, (-2.55 + i * 0.465, -1.56, 0.52), segs=6, bevel=0.0, m=lmat("BambooDark")))
    p += tiki_face("CF", 0.8, 0.8, (0, -1.6, 0.55), wood=wood, paint=lmat("Yellow"), dark=dark, style=0)
    # Back shelf with glowing bottles and a sign above it.
    p += [box("Shelf", (4.4, 0.4, 1.6), (0, 1.9, 1.5), bevel=0.04, m=dark),
          box("ShelfBoard0", (4.3, 0.42, 0.05), (0, 1.75, 1.3), bevel=0.0, m=top),
          box("ShelfBoard1", (4.3, 0.42, 0.05), (0, 1.75, 1.85), bevel=0.0, m=top)]
    glass = [lglow("LavaBottlePink", "#ff4f9a", 2.2), lglow("LavaBottleTeal", "#2fe6d4", 2.2), lglow("LavaBottleAmber", "#ffb23a", 2.2)]
    for row, z in enumerate((1.33, 1.88)):
        for k in range(9):
            x = -1.9 + k * 0.48
            p.append(cyl(f"Bottle{row}{k}", 0.07, 0.3, (x, 1.7, z + 0.15), segs=8, bevel=0.01, m=glass[(k + row) % 3]))
            p.append(cyl(f"Neck{row}{k}", 0.03, 0.1, (x, 1.7, z + 0.35), segs=6, bevel=0.0, m=glass[(k + row) % 3]))
    p += [box("SignBoard", (3.0, 0.12, 0.6), (0, -2.25, 2.75), bevel=0.05, m=dark),
          text("SignText", "LAVA LOUNGE", 0.36, 0.05, (0, -2.33, 2.74), m=lglow("LavaSignNeon", "#ff7a3a", 2.6))]
    for k in range(4):
        x = -1.8 + k * 1.2
        p += [cyl(f"Stool{k}", 0.24, 0.08, (x, -2.0, 0.8), segs=10, bevel=0.02, m=top),
              cyl(f"StoolLeg{k}", 0.06, 0.78, (x, -2.0, 0.39), segs=6, bevel=0.0, m=dark)]
    for k in range(3):
        p += [cyl(f"Coco{k}", 0.12, 0.2, (-1.0 + k * 0.9, -1.25, 1.28), segs=8, bevel=0.02, m=lmat("Coconut")),
              cyl(f"Straw{k}", 0.012, 0.3, (-0.95 + k * 0.9, -1.25, 1.42), rot=(0.3, 0, 0), segs=4, bevel=0.0, m=lmat("Pink"))]
    p += bulb_row("Bulb", (-3.2, -2.25, 3.0), (3.2, -2.25, 3.0), 8, 0.07, lglow("LavaBulb", "#ffc46b", 3.0))
    save("lava_bar", [merge("Bar", p)])


def build_surf_rack():
    """A bamboo rack of four surfboards (2.4 x 0.8 m, 2.3 m tall)."""
    reset_scene()
    p = []
    for x in (-1.1, 1.1):
        p += bamboo(f"Post{x}", (x, 0, 0), (x, 0, 1.6), 0.06, joints=False)
    p += bamboo("Bar", (-1.15, 0, 1.4), (1.15, 0, 1.4), 0.05, joints=False)
    p += bamboo("BarLow", (-1.15, 0.0, 0.35), (1.15, 0.0, 0.35), 0.05, joints=False)
    cols = [lmat("Teal"), lmat("Pink"), lmat("Yellow"), lmat("Ember")]
    for k in range(4):
        x = -0.75 + k * 0.5
        p.append(sphere(f"Board{k}", 1.0, (x, -0.1 + 0.07 * k, 1.1), scale=(0.24, 0.05, 1.12), rot=(math.radians(-8), 0, 0), m=cols[k], segs=14, rings=10))
        p.append(box(f"Stripe{k}", (0.05, 0.11, 1.6), (x, -0.1 + 0.07 * k, 1.1), rot=(math.radians(-8), 0, 0), bevel=0.0, m=lmat("White")))
    save("lava_surf_rack", [merge("SurfRack", p)])


def build_signpost():
    """Carved signpost: arrows to the beach, the springs and the observatory (3 m)."""
    reset_scene()
    dark, wood, cream = lmat("TikiDark"), lmat("TikiLight"), lmat("Cream")
    p = [cyl("Post", 0.1, 3.0, (0, 0, 1.5), segs=8, bevel=0.02, m=dark)]
    for k, (label, yaw, z) in enumerate((("BEACH", 0.4, 2.55), ("SPRINGS", -1.4, 2.15), ("OBSERVATORY", 2.6, 1.75))):
        w = 0.18 * len(label) * 0.62 + 0.4
        outline = [(0, -0.15), (w, -0.15), (w + 0.25, 0), (w, 0.15), (0, 0.15)]
        parts = [prism(f"Arrow{k}", outline, 0.07, (0, 0, z), m=wood, bevel=0.02),
                 text(f"Label{k}", label, 0.17, 0.02, (0.18 + w / 2 - 0.1, -0.05, z - 0.06), m=cream)]
        for ob in parts:
            ob.matrix_world = Matrix.Rotation(yaw, 4, "Z") @ ob.matrix_world
        p += parts
    p += flower("Fl", (0, 0, 3.02), 0.16)
    save("lava_signpost", [merge("Signpost", p)])


def build_bridge():
    """Stone stair-bridge over the lava river: 4 m wide, rising 2 m over an 8.5 m
    run. The high end is at the origin, the foot BRIDGE_RUN along -Y (Godot +Z).
    Steps, basalt balustrades with lantern posts, an arch underneath."""
    reset_scene()
    b, light, dark = lmat("Basalt", rough=0.85), lmat("BasaltLight", rough=0.85), lmat("BasaltDark", rough=0.85)
    p = []
    steps = 12
    rise, tread = BRIDGE_RISE / steps, BRIDGE_RUN / steps
    for k in range(steps):
        h = BRIDGE_RISE - rise * k
        y = -tread * (k + 0.5)
        p.append(box(f"Step{k}", (BRIDGE_W, tread + 0.02, 0.3), (0, y, h - 0.15), bevel=0.03, m=light if k % 2 else b))
    # Arch body beneath the steps (spans the channel in the middle).
    outline = []
    for i in range(13):
        t = i / 12
        y = -BRIDGE_RUN * t
        outline.append((y, BRIDGE_RISE * (1 - t) - 0.3))
    for i in range(13):
        t = 1 - i / 12
        y = -BRIDGE_RUN * t
        arch = max(0.0, math.sin(math.pi * (t - 0.15) / 0.55)) if 0.15 < t < 0.7 else 0.0
        outline.append((y, -1.2 + arch * 1.4))
    p.append(prism("Body", outline, BRIDGE_W - 0.2, (0, 0, 0), rot=(0, 0, math.pi / 2), m=dark))
    # Balustrades: sloped parapets with lantern posts.
    for s in (-1, 1):
        x = s * (BRIDGE_W / 2 + 0.15)
        length = math.hypot(BRIDGE_RUN, BRIDGE_RISE)
        ang = math.atan2(BRIDGE_RISE, BRIDGE_RUN)
        p.append(box(f"Parapet{s}", (0.34, length + 0.3, 1.0), (x, -BRIDGE_RUN / 2, BRIDGE_RISE / 2 + 0.25), rot=(ang, 0, 0), bevel=0.06, m=b))
        p.append(box(f"Coping{s}", (0.44, length + 0.4, 0.12), (x, -BRIDGE_RUN / 2, BRIDGE_RISE / 2 + 0.8), rot=(ang, 0, 0), bevel=0.03, m=light))
        for k, t in enumerate((0.0, 1.0)):
            ny = 0.25 if t == 0.0 else -BRIDGE_RUN - 0.25
            z = BRIDGE_RISE * (1 - t)
            p += [box(f"Newel{s}{k}", (0.5, 0.5, 1.5), (x, ny, z + 0.6), bevel=0.06, m=dark),
                  bulb(f"Lamp{s}{k}", 0.13, (x, ny, z + 1.48), lglow("LavaLantern", "#ffb04a", 3.0))]
    save("lava_bridge", [merge("Bridge", p)])


def build_spring_steps():
    """Wooden spa steps and a rail for the edge of a hot spring (1.6 m)."""
    reset_scene()
    wood, dark = lmat("TikiLight"), lmat("TikiDark")
    p = [box(f"Step{k}", (1.4, 0.4, 0.2), (0, -0.4 * k, 0.6 - 0.2 * k), bevel=0.03, m=wood) for k in range(3)]
    p += [tube("Rail", [(0.75, 0.2, 0.7), (0.75, 0.2, 1.5), (0.75, -0.6, 1.5), (0.75, -1.0, 0.9)], 0.035, m=lmat("Steel", metal=0.6), segs=6)]
    p.append(box("Sign", (0.6, 0.06, 0.3), (-0.5, 0.25, 1.1), bevel=0.02, m=dark))
    p.append(text("SignText", "HOT", 0.16, 0.02, (-0.5, 0.21, 1.1), m=lglow("LavaSignNeon", "#ff7a3a", 2.6)))
    save("lava_spring_steps", [merge("SpringSteps", p)])


BUILDERS = {
    "palm": build_palm, "palm_b": build_palm_b, "totem": build_totem, "torch": build_torch, "exit_torch": build_exit_torch,
    "boulder": build_boulder, "boulder_b": build_boulder_b, "pebble": build_pebble, "planter": build_planter,
    "crates": build_crates, "lounger": build_lounger, "parasol": build_parasol, "rail": build_rail, "kerb": build_kerb,
    "bar": build_bar, "surf_rack": build_surf_rack, "signpost": build_signpost, "bridge": build_bridge,
    "spring_steps": build_spring_steps,
}


if __name__ == "__main__":
    wanted = [a for a in sys.argv[1:] if a in BUILDERS] or list(BUILDERS)
    for key in wanted:
        BUILDERS[key]()
