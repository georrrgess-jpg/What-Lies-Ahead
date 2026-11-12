"""Hall dressing for Tidal Tunnels (Abyss Aquarium): warm, colourful set pieces
that break up the blue halls and double as cover.

Each function builds one prop in a fresh scene and writes
art/blender/<name>.blend + art/models/<name>.glb. Front faces -Y (Godot +Z),
origin at the centre of the base.

    aqua_coral_display   1.8 x 0.9 m museum plinth (0.8 m) topped with a bright
                         coral garden, brass rail and a lit info plaque
    aqua_planter         1.4 x 0.7 m lobby planter with big tropical leaves and
                         coral-orange flowers
    aqua_janitor_cart    night-shift cleaning cart (1.5 x 0.65 m) with a yellow
                         mop bucket, spray bottles and a wet-floor sign beside it
    aqua_rope_barrier    3 m run of brass stanchions with red velvet rope, along X
    aqua_life_ring       wall plaque with an orange-and-white life ring (faces -Y,
                         origin at the plaque centre)
    aqua_feed_pallet     pallet of fish-food sacks and two blue drums (1.4 x 1.2 m)

    python art/blender/build_aqua_dressing.py [name ...]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aqua_common import *  # noqa: F401,F403


def build_coral_display():
    reset_scene()
    # Few materials on purpose (each one is a draw call per instance).
    navy = amat("Navy", rough=0.5)
    brass = amat("Brass", rough=0.35, metal=0.6)
    led = aglow("DisplayLed", "#ffb04a", 2.6)
    sand = amat("Sand", rough=0.9)
    rock_m = amat("RockLight", rough=0.85)
    pink, coral, yellow = amat("Pink", rough=0.55), amat("Coral", rough=0.55), amat("Yellow", rough=0.55)
    violet, lime = amat("CoralViolet", "#9b5cff", rough=0.55), amat("CoralLime", "#9fe04a", rough=0.55)
    orange, teal = amat("Orange", rough=0.55), amat("TealLight", rough=0.55)
    navy_l, rock_d, tip_p, tip_y, cream, plaque_glow = navy, rock_m, pink, yellow, yellow, led
    L, D, H = 1.8, 0.9, 0.8
    parts = [
        box("Plinth", (L, D, H - 0.1), (0, 0, (H - 0.1) / 2), bevel=0.06, segs=2, m=navy),
        box("Kick", (L + 0.08, D + 0.08, 0.1), (0, 0, 0.05), bevel=0.03, m=navy_l),
        box("Cap", (L + 0.1, D + 0.1, 0.1), (0, 0, H - 0.05), bevel=0.04, m=brass),
        box("LedF", (L - 0.2, 0.02, 0.04), (0, -D / 2 - 0.01, H - 0.16), bevel=0.0, m=led),
        box("LedB", (L - 0.2, 0.02, 0.04), (0, D / 2 + 0.01, H - 0.16), bevel=0.0, m=led),
        box("Bed", (L - 0.1, D - 0.1, 0.08), (0, 0, H + 0.04), bevel=0.03, m=sand),
        # Info plaque on the front, tilted up, with a warm backlit face.
        box("Plaque", (0.62, 0.06, 0.3), (0.45, -D / 2 - 0.05, H - 0.38), rot=rad(-15, 0, 0), bevel=0.02, m=brass),
        box("PlaqueFace", (0.54, 0.02, 0.22), (0.45, -D / 2 - 0.085, H - 0.375), rot=rad(-15, 0, 0), bevel=0.0, m=plaque_glow),
        text("PlaqueText", "REEF", 0.1, 0.012, (0.45, -D / 2 - 0.1, H - 0.39), rot=(-math.radians(15), 0, 0), m=navy),
    ]
    top = H + 0.08
    parts += rock("RockA", (-0.5, 0.12, top), 0.28, rock_m, seed=3, squash=0.65)
    parts += rock("RockB", (0.48, 0.16, top), 0.24, rock_d, seed=5, squash=0.65)
    parts += rock("RockC", (0.0, 0.2, top), 0.2, rock_m, seed=11, squash=0.55)
    parts += coral_branch("Stag", (-0.55, 0.08, top + 0.12), 0.62, pink, seed=2, tip=tip_p)
    parts += coral_branch("StagB", (-0.12, 0.22, top + 0.08), 0.45, coral, seed=12, tip=tip_y)
    parts += coral_branch("StagY", (0.55, 0.14, top + 0.12), 0.55, yellow, seed=7, tip=tip_y)
    parts += coral_fan("Fan", (0.22, 0.3, top + 0.08), 0.34, violet, yaw=0.15, seed=4)
    parts += coral_fan("FanB", (-0.8, 0.3, top), 0.22, orange, yaw=-0.3, seed=13)
    parts += coral_brain("Brain", (0.2, -0.12, top + 0.06), 0.17, lime, seed=6)
    parts += coral_tubes("Tubes", (-0.25, -0.18, top), 0.36, orange, coral, seed=8)
    parts += coral_tubes("TubesB", (0.82, 0.25, top), 0.28, violet, pink, seed=14)
    parts += coral_table("Table", (0.68, -0.2, top), 0.17, teal, seed=9)
    parts += anemone("Anemone", (-0.75, -0.22, top), 0.13, coral, cream, seed=10)
    parts += anemone("AnemoneB", (0.45, -0.28, top), 0.1, pink, cream, seed=15)
    parts += starfish("Star", (-0.05, -0.32, top + 0.02), 0.09, orange, yaw=0.6)
    parts += starfish("StarB", (0.82, -0.32, top + 0.02), 0.07, pink, yaw=1.6)
    # Brass guard rail round the top on short posts.
    for i, (x, y) in enumerate(((-L / 2 + 0.05, -D / 2 + 0.05), (L / 2 - 0.05, -D / 2 + 0.05), (L / 2 - 0.05, D / 2 - 0.05), (-L / 2 + 0.05, D / 2 - 0.05))):
        parts.append(cyl(f"RailPost{i}", 0.02, 0.22, (x, y, top + 0.11), segs=8, bevel=0.0, m=brass))
    for i, (a, b) in enumerate((((-L / 2 + 0.05, -D / 2 + 0.05), (L / 2 - 0.05, -D / 2 + 0.05)),
                                ((L / 2 - 0.05, D / 2 - 0.05), (-L / 2 + 0.05, D / 2 - 0.05)))):
        parts.append(tube(f"Rail{i}", [(a[0], a[1], top + 0.22), (b[0], b[1], top + 0.22)], 0.018, m=brass, segs=6))
    save("aqua_coral_display", [merge("CoralDisplay", parts)])


def _leaf(name, length, width, base, yaw, pitch, m):
    """A chunky tropical leaf: a pointed flat blade on a short stalk, tilted out."""
    half = width / 2
    outline = [(0.0, 0.0), (half * 0.8, length * 0.25), (half, length * 0.55), (half * 0.55, length * 0.85), (0.0, length),
               (-half * 0.55, length * 0.85), (-half, length * 0.55), (-half * 0.8, length * 0.25)]
    blade = prism(name, outline, 0.02, (0, 0, 0), rot=rad(90, 0, 0), m=m, bevel=0.008)
    blade.matrix_world = Matrix.Translation(base) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(-pitch, 4, "X") @ blade.matrix_basis
    return blade


def build_planter():
    reset_scene()
    navy, teal = amat("NavyLight", rough=0.5), amat("Teal", rough=0.5)
    soil = amat("Soil", "#3a2a24", rough=0.95)
    leaf_a, leaf_b = amat("LeafGreen", "#2f9e4a", rough=0.6), amat("LeafLime", "#7cc93c", rough=0.6)
    flower_o, flower_p = amat("FlowerOrange", "#ff7a2f", rough=0.5), amat("FlowerPink", "#ff4f9a", rough=0.5)
    leaf_c, stem, flower_y = leaf_a, leaf_a, flower_o
    L, D, H = 1.4, 0.7, 0.6
    parts = [
        box("Tub", (L, D, H), (0, 0, H / 2), bevel=0.1, segs=3, m=navy),
        box("Band", (L + 0.03, D + 0.03, 0.08), (0, 0, H - 0.14), bevel=0.03, m=teal),
        box("Soil", (L - 0.14, D - 0.14, 0.05), (0, 0, H - 0.02), bevel=0.02, m=soil),
    ]
    r = rng(31)
    leaves = (leaf_a, leaf_b, leaf_c)
    for i in range(14):
        x = r.uniform(-L / 2 + 0.25, L / 2 - 0.25)
        y = r.uniform(-D / 2 + 0.18, D / 2 - 0.18)
        length = r.uniform(0.55, 0.95)
        stalk_h = r.uniform(0.15, 0.55)
        yaw = r.uniform(0, math.tau)
        pitch = r.uniform(0.35, 0.9)
        parts.append(tube(f"Stalk{i}", [(x, y, H - 0.02), (x, y, H + stalk_h)], 0.018, m=stem, segs=5))
        parts.append(_leaf(f"Leaf{i}", length, length * 0.42, (x, y, H + stalk_h), yaw, pitch, leaves[i % 3]))
    # Bird-of-paradise style flowers: a beak of orange petals and a pink spathe on a tall stem.
    for i, (x, y, h) in enumerate(((-0.35, -0.1, 1.15), (0.3, 0.12, 1.3), (0.05, -0.18, 1.0))):
        parts.append(tube(f"FStem{i}", [(x, y, H), (x + 0.04, y, H + h)], 0.016, m=stem, segs=5))
        top = (x + 0.04, y, H + h)
        parts.append(prism(f"Spathe{i}", [(0.0, 0.0), (0.24, 0.03), (0.02, 0.07)], 0.05, top, rot=rad(90, 0, 40 * i), m=flower_p))
        for k in range(3):
            petal = prism(f"Petal{i}{k}", [(0.0, 0.0), (0.05, 0.03), (0.12, 0.2), (0.0, 0.06)], 0.025,
                          (top[0], top[1], top[2] + 0.04), rot=rad(90, 0, 40 * i + 30 * k - 20), m=flower_o if k != 1 else flower_y)
            parts.append(petal)
    save("aqua_planter", [merge("Planter", parts)])


def build_janitor_cart():
    reset_scene()
    grey = amat("CartGrey", "#5a6b86", rough=0.5)
    yellow = amat("SubYellow", rough=0.45)
    black = amat("Dark", rough=0.6)
    steel = amat("Chrome", rough=0.25, metal=0.8)
    white = amat("White", rough=0.5)
    spray_p, spray_g, spray_b = amat("SprayPink", "#ff5fa8", rough=0.4), amat("SprayGreen", "#4fe08a", rough=0.4), amat("SprayBlue", "#4fa8ff", rough=0.4)
    grey_d, yellow_d, bag, mop = grey, yellow, black, white
    parts = []
    # Cart frame: two shelves on posts, a bag hoop at one end.
    for z, name in ((0.25, "ShelfLo"), (0.78, "ShelfHi")):
        parts.append(box(name, (0.95, 0.6, 0.06), (0.25, 0, z), bevel=0.02, m=grey))
    for i, (x, y) in enumerate(((-0.2, -0.27), (0.7, -0.27), (-0.2, 0.27), (0.7, 0.27))):
        parts.append(cyl(f"Post{i}", 0.025, 0.85, (x, y, 0.5), segs=8, bevel=0.0, m=grey_d))
        parts.append(sphere(f"Caster{i}", 0.06, (x, y, 0.06), m=black, segs=8, rings=5))
    parts.append(tube("Handle", [(0.72, -0.25, 0.85), (0.8, -0.2, 1.0), (0.8, 0.2, 1.0), (0.72, 0.25, 0.85)], 0.02, m=steel, segs=6))
    parts.append(sphere("Bag", 0.27, (0.25, 0.0, 0.5), scale=(1.15, 0.85, 0.85), m=bag, segs=12, rings=8))
    parts.append(box("Tray", (0.9, 0.55, 0.12), (0.25, 0, 0.87), bevel=0.03, m=yellow))
    for i, (x, m) in enumerate(((0.0, spray_p), (0.18, spray_g), (0.36, spray_b))):
        parts.append(cyl(f"Spray{i}", 0.05, 0.2, (x, -0.1, 1.03), segs=10, bevel=0.015, m=m))
        parts.append(box(f"Nozzle{i}", (0.05, 0.08, 0.06), (x, -0.13, 1.16), bevel=0.01, m=white))
    parts.append(box("Towels", (0.25, 0.3, 0.12), (0.5, 0.1, 0.99), bevel=0.03, m=spray_g))
    # Mop bucket with wringer on its own castors at the -X end.
    bx = -0.5
    parts += [
        box("Bucket", (0.5, 0.42, 0.42), (bx, 0, 0.29), bevel=0.06, segs=2, m=yellow),
        box("BucketRim", (0.54, 0.46, 0.05), (bx, 0, 0.5), bevel=0.02, m=yellow_d),
        box("Water", (0.44, 0.36, 0.02), (bx, 0, 0.47), bevel=0.0, m=grey),
        box("Wringer", (0.2, 0.4, 0.22), (bx + 0.12, 0, 0.6), bevel=0.04, m=grey_d),
        tube("WringLever", [(bx + 0.12, 0.18, 0.7), (bx + 0.2, 0.18, 1.05)], 0.02, m=steel, segs=6),
        tube("MopHandle", [(bx - 0.1, 0.05, 0.45), (bx - 0.18, 0.12, 1.45)], 0.018, m=spray_b, segs=6),
        sphere("MopHeadBall", 0.12, (bx - 0.09, 0.04, 0.48), scale=(1.0, 1.0, 0.7), m=mop, segs=10, rings=6),
    ]
    for i, (x, y) in enumerate(((bx - 0.2, -0.17), (bx + 0.2, -0.17), (bx - 0.2, 0.17), (bx + 0.2, 0.17))):
        parts.append(sphere(f"BCaster{i}", 0.04, (x, y, 0.04), m=black, segs=6, rings=4))
    # Yellow A-frame wet-floor sign beside the cart: two boards leaning together.
    sx, sy = -0.55, -0.5
    for s_ in (-1, 1):
        face = [box(f"SignBoard{s_}", (0.36, 0.03, 0.62), (0, 0, 0.31), bevel=0.015, m=yellow),
                box(f"SignStripe{s_}", (0.3, 0.012, 0.06), (0, 0.022 * s_, 0.18), bevel=0.0, m=black),
                prism(f"SignIcon{s_}", [(-0.07, 0.0), (0.07, 0.0), (0.0, 0.12)], 0.012, (0, 0.022 * s_, 0.36), m=black)]
        frame = Matrix.Translation((sx, sy, 0)) @ Matrix.Rotation(math.radians(12 * s_), 4, "X") @ Matrix.Translation((0, 0.13 * s_, 0))
        for ob in face:
            ob.matrix_world = frame @ ob.matrix_basis
        parts += face
    save("aqua_janitor_cart", [merge("JanitorCart", parts)])


def build_rope_barrier():
    reset_scene()
    brass = amat("Brass", rough=0.35, metal=0.6)
    navy = amat("Navy", rough=0.5)
    rope = amat("VelvetRope", "#c8203f", rough=0.8)
    parts = []
    xs = (-1.5, 0.0, 1.5)
    for i, x in enumerate(xs):
        parts += [
            cyl(f"Foot{i}", 0.17, 0.05, (x, 0, 0.025), segs=16, bevel=0.015, m=navy),
            cyl(f"Post{i}", 0.03, 0.9, (x, 0, 0.47), segs=10, bevel=0.0, m=brass),
            sphere(f"Knob{i}", 0.055, (x, 0, 0.94), m=brass, segs=10, rings=6),
        ]
    for i in range(2):
        a, b = xs[i], xs[i + 1]
        pts = []
        for k in range(9):
            t = k / 8
            pts.append((a + (b - a) * t, 0.0, 0.86 - 0.2 * math.sin(math.pi * t)))
        parts.append(tube(f"Rope{i}", pts, 0.025, m=rope, segs=6))
    save("aqua_rope_barrier", [merge("RopeBarrier", parts)])


def build_life_ring():
    reset_scene()
    navy, brass = amat("NavyLight", rough=0.5), amat("Brass", rough=0.35, metal=0.6)
    orange, white = amat("Orange", rough=0.5), amat("White", rough=0.5)
    rope = white
    parts = [box("Plaque", (0.95, 0.06, 1.15), (0, 0.03, 0), bevel=0.03, m=navy),
             box("PlaqueTrim", (0.99, 0.04, 0.06), (0, 0.0, -0.6), bevel=0.01, m=brass)]
    for i in range(8):
        a0 = 45.0 * i
        pts = [(math.cos(math.radians(a0 + k * 11.25)) * 0.34, -0.08, 0.06 + math.sin(math.radians(a0 + k * 11.25)) * 0.34)
               for k in range(5)]
        parts.append(tube(f"RingArc{i}", pts, 0.09, m=orange if i % 2 == 0 else white, segs=8, cap=False))
    for i in range(4):
        a = math.radians(45 + 90 * i)
        parts.append(torus(f"Grab{i}", 0.1, 0.012, (math.cos(a) * 0.34, -0.17, 0.06 + math.sin(a) * 0.34),
                           rot=rad(0, 0, 0), m=rope, major_segs=10, minor_segs=4))
    parts.append(text("Label", "RESCUE", 0.09, 0.01, (0, -0.005, -0.42), m=white))
    save("aqua_life_ring", [merge("LifeRing", parts)])


def build_feed_pallet():
    reset_scene()
    wood = amat("PalletWood", "#b98a52", rough=0.8)
    sack = amat("SackCream", "#efe2c2", rough=0.9)
    orange, navy = amat("Orange", rough=0.5), amat("Navy", rough=0.5)
    drum = amat("DrumBlue", "#2f6fd8", rough=0.45)
    wood_d, sack_d, drum_band, white = wood, sack, navy, sack
    parts = []
    for i in range(3):
        parts.append(box(f"Skid{i}", (1.4, 0.1, 0.1), (-0.15, -0.45 + i * 0.45, 0.05), bevel=0.01, m=wood_d))
    for i in range(7):
        parts.append(box(f"Board{i}", (0.16, 1.2, 0.04), (-0.78 + i * 0.21, 0, 0.12), bevel=0.008, m=wood))
    r = rng(17)
    k = 0
    for layer in range(2):
        for j in range(2):
            x = -0.5 + j * 0.62 + r.uniform(-0.03, 0.03)
            y = -0.25 + layer * 0.08 + r.uniform(-0.03, 0.03)
            z = 0.26 + layer * 0.26
            parts.append(box(f"Sack{k}", (0.58, 0.42, 0.26), (x, y if layer == 0 else -y * 0.2, z), rot=rad(0, 0, r.uniform(-6, 6)),
                             bevel=0.1, segs=3, m=sack if k % 2 == 0 else sack_d))
            k += 1
    for j in range(2):
        x = -0.5 + j * 0.62
        parts.append(sphere(f"Logo{j}", 0.07, (x, -0.47, 0.55), scale=(1.5, 0.15, 0.9), m=orange, segs=10, rings=6))
        parts.append(prism(f"LogoTail{j}", [(0.0, 0.0), (0.08, 0.06), (0.08, -0.06)], 0.015, (x + 0.1, -0.475, 0.55), rot=rad(90, 0, 0), m=orange))
    for i, y in enumerate((-0.27, 0.27)):
        parts.append(cyl(f"Drum{i}", 0.27, 0.86, (0.42, y, 0.57), segs=18, bevel=0.03, m=drum))
        for b in (0.32, 0.82):
            parts.append(cyl(f"DrumBand{i}{b}", 0.278, 0.04, (0.42, y, 0.14 + b), segs=18, bevel=0.0, m=drum_band))
        parts.append(cyl(f"DrumCap{i}", 0.06, 0.02, (0.5, y, 1.01), segs=8, bevel=0.0, m=white))
    parts.append(text("Stencil", "FISH FOOD", 0.08, 0.01, (-0.2, -0.49, 0.32), m=navy))
    save("aqua_feed_pallet", [merge("FeedPallet", parts)])


BUILDERS = {
    "coral_display": build_coral_display, "planter": build_planter, "janitor_cart": build_janitor_cart,
    "rope_barrier": build_rope_barrier, "life_ring": build_life_ring, "feed_pallet": build_feed_pallet,
}

if __name__ == "__main__":
    for key in sys.argv[1:] or list(BUILDERS):
        BUILDERS[key]()
