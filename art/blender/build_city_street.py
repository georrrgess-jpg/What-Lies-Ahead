"""Ashfall City street props (the Endless map). Each saves
art/blender/city_<name>.blend and art/models/city_<name>.glb; origin at the
centre of the base, front faces -Y (Godot +Z).

    streetlight      7.2 m lamp post, arm over the road (+X); bulb flickers; empty Light
    traffic_light    5.6 m mast arm with a stuck red signal; empty Light
    barrier_jersey   2.0 x 0.6 x 0.85 m concrete jersey barrier with hazard bands
    dumpster         1.9 x 1.1 m, lid thrown open, bags spilling
    hydrant          0.85 m fire hydrant
    billboard_torn   8 x 4 m billboard 6 m up on two legs, the poster in tatters
    bus_stop         4.2 x 1.6 m shelter, cracked panels, lit ad, bench
    newsstand        2.6 x 2 m kiosk, shutter half down, magazines, NEWS sign
    rubble_a/_b      concrete rubble piles (2.6 m / 5 m across)
    debris           flat scatter: paper, cans, a plank, a tyre (2.5 m)
    statue_toppled   the square's centrepiece: plinth 5 x 5 m and the bronze founder lying broken
    subway_entrance  METRO stairs: 3.6 m wide, descending along +Y from y = 0 to y = 7.2,
                     z = 0 to -4.2 (the map opens the ground behind the origin)
    market_stall     3 x 2 m stall, torn tarp, crates, string lights
    neon_sign_a      wall-mounted vertical HOTEL blade sign (mount at y = +0.1 on a wall)
    neon_sign_b      wall-mounted NOODLES sign with a bowl icon
    police_barrier   2.2 m POLICE LINE sawhorse with a strobing light

    python art/blender/build_city_street.py [names...]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from city_common import *  # noqa: F401,F403
from build_city_gates import rubble as chunks, posters  # noqa: E402

STEEL = lambda: cm("SteelDark", rough=0.5, metal=0.5)  # noqa: E731


def build_streetlight():
    reset_scene()
    pole = cm("Teal", rough=0.5, metal=0.3)
    p = [cyl("Base", 0.28, 0.6, (0, 0, 0.3), segs=8, bevel=0.03, m=STEEL()),
         cyl("Pole", 0.12, 7.0, (0, 0, 3.6), segs=8, bevel=0.0, m=pole, radius_top=0.08),
         tube("Arm", [(0, 0, 6.8), (0.4, 0, 7.25), (1.2, 0, 7.35), (2.0, 0, 7.25)], 0.06, m=pole, segs=6),
         box("Head", (0.9, 0.38, 0.18), (2.1, 0, 7.15), bevel=0.06, segs=1, m=STEEL()),
         lamp("Bulb", 0.13, (2.1, 0, 7.02), LAMP_WARM, strength=4.0, lit=neon(LAMP_WARM, 4.0))]
    p += place(hazard("Haz", 0.8, 0.3, stripe=0.25), (0, -0.13, 0.9))
    p += place(posters("Post", (0, 0, 0), 0.0, seed=5, count=2), (0, -0.14, 1.6))
    csave("city_streetlight", [merge("Streetlight", p), socket("Light", (2.1, 0, 6.8))])


def build_traffic_light():
    reset_scene()
    pole = cm("Taxi", rough=0.5, metal=0.3)
    p = [cyl("Base", 0.3, 0.4, (0, 0, 0.2), segs=8, bevel=0.03, m=STEEL()),
         cyl("Pole", 0.13, 5.6, (0, 0, 2.9), segs=8, bevel=0.0, m=pole),
         cyl("Arm", 0.09, 4.0, (2.0, 0, 5.4), rot=(0, math.pi / 2, 0), segs=6, bevel=0.0, m=pole),
         box("Box", (0.42, 0.36, 1.25), (3.6, 0, 4.6), bevel=0.05, segs=1, m=STEEL()),
         box("Ped", (0.32, 0.3, 0.6), (0, -0.2, 2.6), bevel=0.04, segs=1, m=STEEL())]
    for k, (col, lit) in enumerate(((NEON_RED, True), (NEON_AMBER, False), ("#3aff7a", False))):
        z = 5.0 - k * 0.38
        m = neon(col, 4.0) if lit else cm("Soot", rough=0.3)
        p += [cyl(f"Lens{k}", 0.13, 0.06, (3.6, -0.2, z), rot=(math.pi / 2, 0, 0), segs=10, bevel=0.0, m=m),
              box(f"Visor{k}", (0.32, 0.16, 0.04), (3.6, -0.27, z + 0.15), bevel=0.0, m=STEEL())]
    p.append(lamp("Halo", 0.08, (3.6, -0.25, 5.0), NEON_RED, strength=4.0, lit=neon(NEON_RED, 4.0)))
    p.append(fbox("Walk", (0.24, 0.04, 0.2), (0, -0.36, 2.7), m=neon("#ff7a2a", 2.5)))
    csave("city_traffic_light", [merge("TrafficLight", p), socket("Light", (3.6, -0.3, 5.0))])


def build_barrier_jersey():
    reset_scene()
    prof = [(-0.3, 0.0), (0.3, 0.0), (0.3, 0.08), (0.17, 0.3), (0.1, 0.85), (-0.1, 0.85), (-0.17, 0.3), (-0.3, 0.08)]
    body = flat_prism("Body", prof, 2.0, rot=(0, 0, math.pi / 2), m=cm("ConcreteLight"))
    p = [body]
    for s in (-1, 1):
        p += place(hazard(f"Haz{s}", 1.9, 0.22, stripe=0.3, depth=0.02), (0, s * 0.19, 0.55), rot_z=0 if s < 0 else math.pi)
        for k in range(2):
            p[-1 - k].rotation_euler.x += s * 0.0
    p += [box("Chip", (0.3, 0.25, 0.2), (0.85, -0.05, 0.78), rot=(0.4, 0.3, 0.2), bevel=0.0, m=cm("ConcreteDark")),
          box("Lift", (0.06, 0.6, 0.06), (0.0, 0, 0.88), bevel=0.0, m=cm("Rust"))]
    csave("city_barrier_jersey", [merge("Jersey", p)])


def build_dumpster():
    reset_scene()
    green, dark = cm("Green", rough=0.6, metal=0.2), cm("GreenDark", rough=0.6)
    p = [box("Bin", (1.9, 1.1, 1.05), (0, 0, 0.65), bevel=0.05, segs=1, m=green),
         box("Rim", (2.0, 1.2, 0.1), (0, 0, 1.2), bevel=0.02, segs=1, m=dark),
         box("Inside", (1.75, 0.95, 0.05), (0, 0, 1.1), bevel=0.0, m=cm("Interior"))]
    lid = box("Lid", (1.95, 0.05, 1.15), (0, 0, 0), bevel=0.02, segs=1, m=dark)
    lid.location = (0, 0.7, 1.75)
    lid.rotation_euler = (math.radians(-15), 0, 0)
    p.append(lid)
    for s in (-1, 1):
        for t in (-1, 1):
            p.append(cyl(f"Wheel{s}{t}", 0.1, 0.06, (s * 0.8, t * 0.45, 0.1), rot=(0, math.pi / 2, 0), segs=6, bevel=0.0, m=cm("Rubber")))
    p += [text("Txt", "CITY WASTE", 0.18, 0.02, (0, -0.56, 0.75), m=cm("White")),
          sphere("Bag0", 0.38, (0.4, 0.0, 1.3), scale=(1.1, 0.9, 0.8), m=cm("Soot", rough=0.4), segs=8, rings=5),
          sphere("Bag1", 0.32, (-0.3, -0.1, 1.28), scale=(1, 1, 0.8), m=cm("Tarp", rough=0.4), segs=8, rings=5),
          sphere("Bag2", 0.36, (1.3, -0.6, 0.25), scale=(1, 1, 0.7), m=cm("Soot", rough=0.4), segs=8, rings=5)]
    p.append(blob("Rust", 0.25, (-0.6, -0.56, 0.5), cm("Rust"), seed=3, squash=(0.5, 1.4)))
    csave("city_dumpster", [merge("Dumpster", p)])


def build_hydrant():
    reset_scene()
    red, cap = cm("Red", rough=0.45, metal=0.2), cm("Cream", rough=0.5)
    p = [cyl("Base", 0.2, 0.08, (0, 0, 0.04), segs=10, bevel=0.0, m=red),
         cyl("Body", 0.14, 0.55, (0, 0, 0.35), segs=10, bevel=0.02, m=red),
         sphere("Dome", 0.15, (0, 0, 0.64), scale=(1, 1, 0.7), m=red, segs=10, rings=5),
         cyl("Nut", 0.04, 0.1, (0, 0, 0.75), segs=5, bevel=0.0, m=cap),
         cyl("Collar", 0.17, 0.06, (0, 0, 0.58), segs=10, bevel=0.0, m=cap)]
    for k, a in enumerate((0.0, math.pi)):
        p.append(cyl(f"Out{k}", 0.06, 0.16, (math.cos(a) * 0.17, math.sin(a) * 0.17, 0.42), rot=(0, math.pi / 2, a), segs=8, bevel=0.0, m=cap))
    p.append(cyl("Front", 0.08, 0.14, (0, -0.17, 0.4), rot=(math.pi / 2, 0, 0), segs=8, bevel=0.0, m=cap))
    csave("city_hydrant", [merge("Hydrant", p)])


def build_billboard_torn():
    reset_scene()
    steel = STEEL()
    rng = random.Random(9)
    p = []
    for s in (-1, 1):
        p += [cyl(f"Leg{s}", 0.22, 6.2, (s * 2.4, 0.2, 3.1), segs=8, bevel=0.0, m=steel),
              box(f"Foot{s}", (0.9, 0.9, 0.4), (s * 2.4, 0.2, 0.2), bevel=0.04, segs=1, m=cm("ConcreteDark"))]
    p += [box("Frame", (8.2, 0.3, 4.2), (0, 0.15, 8.1), bevel=0.04, segs=1, m=steel),
          fbox("Board", (7.8, 0.1, 3.8), (0, -0.02, 8.1), m=cm("Soot")),
          fbox("Walk", (8.0, 0.9, 0.08), (0, -0.6, 5.95), m=steel),
          fbox("Rail", (8.0, 0.05, 0.05), (0, -1.03, 6.85), m=steel)]
    for k in range(5):
        p.append(fbox(f"RailPost{k}", (0.05, 0.05, 0.9), (-4.0 + k * 2.0, -1.03, 6.4), m=steel))
    # Poster in strips: some intact (the ad), some torn short, some gone.
    cols = ["Pink", "Pink", "Cream", "Teal", "Cream", "Taxi", "Pink", "Cream"]
    for k in range(8):
        x = -3.9 + 0.4875 + k * 0.975
        r = rng.random()
        if k in (2, 5):
            continue
        h = 3.8 if r < 0.5 else rng.uniform(1.4, 2.8)
        p.append(fbox(f"Strip{k}", (0.97, 0.02, h), (x, -0.08, 10.0 - h / 2), m=cm(cols[k], rough=0.85)))
        if h < 3.8:
            p.append(flat_prism(f"Flap{k}", [(-0.45, 0), (0.45, 0), (0.1, -0.7)], 0.02, (x, -0.2, 10.0 - h), rot=(0.5, 0, rng.uniform(-0.3, 0.3)), m=cm(cols[k], rough=0.85)))
    p += [text("Ad", "SMILE", 1.1, 0.04, (-1.4, -0.12, 8.9), m=cm("White")),
          text("Ad2", "CITY", 0.8, 0.04, (2.2, -0.12, 7.4), m=cm("Soot"))]
    for k in range(3):
        x = -2.8 + k * 2.8
        p += [beam(f"SpotArm{k}", (x, -0.6, 6.0), (x, -1.2, 6.3), 0.06, m=steel),
              box(f"Spot{k}", (0.3, 0.3, 0.25), (x, -1.25, 6.35), rot=(0.7, 0, 0), bevel=0.03, segs=1, m=steel)]
    p.append(lamp("SpotLit", 0.1, (-2.8, -1.35, 6.45), LAMP_WARM, strength=3.0, lit=neon(LAMP_WARM, 3.0)))
    csave("city_billboard_torn", [merge("Billboard", p)])


def build_bus_stop():
    reset_scene()
    steel, glass = cm("Steel", rough=0.4, metal=0.5), cm("Glass", rough=0.15, metal=0.3)
    p = [fbox("Slab", (4.4, 1.8, 0.1), (0, 0, 0.05), m=cm("ConcreteLight")),
         box("Roof", (4.4, 1.7, 0.16), (0, 0.05, 2.6), rot=(math.radians(-4), 0, 0), bevel=0.04, segs=1, m=cm("Teal", rough=0.5)),
         fbox("Back", (4.0, 0.05, 0.25), (0, 0.72, 0.4), m=steel)]
    for k, x in enumerate((-2.05, 0.0, 2.05)):
        p.append(fbox(f"Post{k}", (0.1, 0.1, 2.55), (x, 0.75, 1.3), m=steel))
        p.append(fbox(f"PostF{k}", (0.1, 0.1, 2.5), (x, -0.7, 1.3), m=steel) if k != 1 else fbox("PostF1", (0.01, 0.01, 0.01), (x, 0.7, 2.5), m=steel))
    # Back glass: one pane intact, one smashed to shards; side pane intact.
    p += [fbox("Pane0", (1.95, 0.03, 1.9), (-1.02, 0.75, 1.4), m=glass)]
    p += place(shards("Sh", 1.9, 1.9, (0, 0, 0), m=glass, seed=4), (1.02, 0.75, 1.4))
    p.append(fbox("Side", (0.03, 1.3, 1.9), (2.05, 0.05, 1.4), m=glass))
    # Lit ad panel at the -X end, bench, route sign.
    p += [box("AdBox", (0.25, 1.4, 2.0), (-2.15, 0.05, 1.4), bevel=0.03, segs=1, m=steel),
          fbox("Ad", (0.04, 1.2, 1.8), (-2.29, 0.05, 1.4), m=steady("#ff8ac4", 1.6)),
          text("AdTxt", "SMILE", 0.28, 0.02, (-2.32, 0.05, 1.6), rot=(0, 0, -math.pi / 2), m=cm("Soot")),
          box("Bench", (2.6, 0.45, 0.08), (0.4, 0.4, 0.5), bevel=0.02, segs=1, m=cm("WoodLight")),
          fbox("BenchLegA", (0.08, 0.4, 0.45), (-0.7, 0.4, 0.25), m=steel),
          fbox("BenchLegB", (0.08, 0.4, 0.45), (1.5, 0.4, 0.25), m=steel),
          cyl("SignPole", 0.05, 2.8, (2.6, -0.6, 1.4), segs=6, bevel=0.0, m=steel),
          cyl("Sign", 0.32, 0.04, (2.6, -0.6, 2.75), rot=(math.pi / 2, 0, 0), segs=12, bevel=0.0, m=cm("Red")),
          text("SignTxt", "13", 0.3, 0.02, (2.6, -0.64, 2.74), m=cm("White"))]
    p += graffiti("Tag", "ZZZ", 0.35, (-1.0, 0.72, 0.9), NEON_LIME)
    csave("city_bus_stop", [merge("BusStop", p)])


def build_newsstand():
    reset_scene()
    green, cream = cm("GreenDark", rough=0.6), cm("Cream", rough=0.7)
    p = [box("Body", (2.6, 2.0, 2.3), (0, 0, 1.15), bevel=0.06, segs=1, m=green),
         box("Roof", (3.0, 2.4, 0.2), (0, 0, 2.4), bevel=0.05, segs=1, m=cm("Soot")),
         box("SignBox", (2.4, 0.3, 0.5), (0, -0.95, 2.75), bevel=0.04, segs=1, m=cm("Soot")),
         text("Sign", "NEWS", 0.4, 0.05, (0, -1.12, 2.74), m=neon(NEON_AMBER)),
         fbox("Opening", (2.1, 0.05, 1.0), (0, -1.0, 1.55), m=cm("Interior")),
         fbox("Shutter", (2.1, 0.08, 0.5), (0, -1.02, 1.85), m=cm("Steel", metal=0.4)),
         box("Counter", (2.4, 0.5, 0.08), (0, -1.15, 1.02), bevel=0.02, segs=1, m=cream)]
    rng = random.Random(3)
    cols = ["Pink", "Taxi", "Teal", "Red", "Cream", "Blue"]
    for k in range(9):
        p.append(fbox(f"Mag{k}", (0.28, 0.02, 0.38), (-1.1 + k * 0.27, -1.03, 0.65 + rng.uniform(-0.05, 0.05)), rot=(0.1, 0, rng.uniform(-0.1, 0.1)), m=cm(rng.choice(cols), rough=0.8)))
    for k in range(4):
        p.append(fbox(f"Paper{k}", (0.5, 0.35, 0.03), (rng.uniform(-1.6, 1.6), -1.6 + rng.uniform(-0.5, 0.3), 0.015), rot=(0, 0, rng.uniform(0, 3)), m=cm("Cream", rough=0.9)))
    p += graffiti("Tag", "OK?", 0.5, (1.31, 0.0, 1.2), NEON_PINK, rot_z=math.pi / 2)
    p += place(posters("Post", (0, 0, 0), 0.0, seed=7, count=2), (-0.6, 1.01, 0.8), rot_z=math.pi)
    csave("city_newsstand", [merge("Newsstand", p)])


def rubble_pile(prefix, radius, height, seed, count):
    rng = random.Random(seed)
    mats = [cm("Concrete"), cm("ConcreteDark"), cm("ConcreteLight"), cm("Brick")]
    p = [ground_blob(prefix + "Dust", radius * 1.15, (0, 0, 0), cm("CharLight", rough=0.95), seed=seed)]
    p.append(make_flat(sphere(prefix + "Mound", radius * 0.85, (0, 0, 0), scale=(1.0, 0.85, height / radius), m=cm("ConcreteDark", rough=0.95), segs=8, rings=4)))
    for k in range(count):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.0, radius * 0.85)
        s = rng.uniform(0.25, 0.7) * radius * 0.5
        z = max(0.1, height * (1 - r / radius) * 0.8)
        p.append(box(f"{prefix}C{k}", (s * 1.6, s, s * 0.6), (math.cos(a) * r, math.sin(a) * r, z), rot=(rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), rng.uniform(0, 3)),
                     bevel=0.03, segs=1, m=rng.choice(mats)))
    return p


def build_rubble_a():
    reset_scene()
    p = rubble_pile("A", 1.3, 0.9, 5, 9)
    p += rebar("Rb", (0.2, 0.1, 0.6), (0.3, -0.2, 1), 0.9, 4, (0.15, 0.1, 0), seed=3)
    csave("city_rubble_a", [merge("RubbleA", p)])


def build_rubble_b():
    reset_scene()
    p = rubble_pile("B", 2.5, 1.6, 9, 14)
    wall = broken_wall("WallChunk", 2.6, 2.2, 0.3, cm("Brick"), seed=4, amp=0.7, steps=5)
    wall.rotation_euler = (math.radians(-28), 0, math.radians(20))
    wall.location = (-0.4, 0.3, 0.4)
    p.append(wall)
    p.append(fbox("Slab", (2.4, 1.6, 0.25), (1.0, -0.5, 0.7), rot=(0.25, -0.3, 0.4), m=cm("Concrete")))
    p += rebar("Rb", (1.8, -0.9, 0.9), (1, -0.3, 0.5), 1.0, 5, (0, 0.25, 0), seed=11)
    csave("city_rubble_b", [merge("RubbleB", p)])


def build_debris():
    reset_scene()
    rng = random.Random(13)
    p = []
    for k in range(8):
        p.append(fbox(f"Paper{k}", (rng.uniform(0.2, 0.4), rng.uniform(0.25, 0.35), 0.01), (rng.uniform(-1.2, 1.2), rng.uniform(-1.0, 1.0), 0.006),
                      rot=(0, 0, rng.uniform(0, 3)), m=cm(rng.choice(["Cream", "White", "Pink"]), rough=0.9)))
    for k in range(4):
        p.append(cyl(f"Can{k}", 0.035, 0.12, (rng.uniform(-1.0, 1.0), rng.uniform(-0.9, 0.9), 0.035), rot=(math.pi / 2, 0, rng.uniform(0, 3)), segs=6, bevel=0.0,
                     m=cm(rng.choice(["Red", "Teal", "Taxi"]), rough=0.4, metal=0.4)))
    p += [box("Plank", (1.6, 0.2, 0.05), (0.3, 0.6, 0.03), rot=(0, 0.05, 0.4), bevel=0.0, m=cm("WoodLight")),
          torus("Tyre", 0.27, 0.1, (-0.8, -0.2, 0.1), m=cm("Rubber", rough=0.95), major_segs=12, minor_segs=4),
          box("Brick0", (0.22, 0.1, 0.07), (0.9, -0.6, 0.035), rot=(0, 0, 0.6), bevel=0.0, m=cm("Brick")),
          box("Brick1", (0.22, 0.1, 0.07), (1.05, -0.45, 0.035), rot=(0, 0, 1.6), bevel=0.0, m=cm("Brick")),
          ground_blob("Ash", 1.3, (0, 0, 0), cm("CharLight", rough=0.95), seed=13, squash=(1.2, 0.9))]
    csave("city_debris", [merge("Debris", p)])


def figure(prefix, m, scale=1.0):
    """A heroic standing figure (~4.4 m at scale 1) in a long coat, the right arm
    raising a torch; built standing, feet at the origin, facing -Y."""
    p = [cyl(prefix + "LegL", 0.22, 1.6, (-0.24, 0, 0.8), segs=8, bevel=0.0, m=m),
         cyl(prefix + "LegR", 0.22, 1.6, (0.24, 0, 0.8), segs=8, bevel=0.0, m=m),
         cyl(prefix + "Coat", 0.62, 1.7, (0, 0, 1.75), segs=10, bevel=0.0, m=m, radius_top=0.42),
         cyl(prefix + "Chest", 0.45, 0.9, (0, 0, 2.95), segs=10, bevel=0.0, m=m, radius_top=0.5),
         sphere(prefix + "Head", 0.3, (0, -0.02, 3.75), scale=(1, 1, 1.15), m=m, segs=10, rings=6),
         cyl(prefix + "Hat", 0.33, 0.12, (0, 0, 4.05), segs=10, bevel=0.0, m=m),
         tube(prefix + "ArmR", [(0.5, 0, 3.3), (0.75, -0.05, 3.8), (0.8, -0.1, 4.45)], 0.12, m=m, segs=6),
         tube(prefix + "ArmL", [(-0.5, 0, 3.3), (-0.62, -0.15, 2.7), (-0.5, -0.3, 2.35)], 0.12, m=m, segs=6),
         cyl(prefix + "Torch", 0.09, 0.5, (0.8, -0.1, 4.7), segs=6, bevel=0.0, m=m),
         cyl(prefix + "Cup", 0.2, 0.28, (0.8, -0.1, 5.05), segs=8, bevel=0.0, m=cm("Gold", rough=0.35, metal=0.7), radius_top=0.28),
         box(prefix + "Book", (0.32, 0.12, 0.42), (-0.48, -0.36, 2.3), bevel=0.02, segs=1, m=m)]
    return xform(p, scale=scale)


def build_statue_toppled():
    """The founder's statue, pulled down: a stepped plinth with its bronze plaque,
    the empty feet still bolted on top, the figure lying broken beside it."""
    reset_scene()
    stone, light = cm("ConcreteLight"), cm("Cream", rough=0.7)
    bronze = cm("BronzeGreen", rough=0.5, metal=0.5)
    p = [box("Step0", (5.4, 5.4, 0.35), (0, 0, 0.175), bevel=0.05, segs=1, m=stone),
         box("Step1", (4.4, 4.4, 0.35), (0, 0, 0.525), bevel=0.05, segs=1, m=stone),
         box("Block", (2.6, 2.6, 2.2), (0, 0, 1.8), bevel=0.06, segs=1, m=light),
         box("Cap", (3.0, 3.0, 0.3), (0, 0, 3.05), bevel=0.05, segs=1, m=stone),
         box("Plaque", (1.5, 0.06, 0.7), (0, -1.33, 1.9), bevel=0.02, segs=1, m=cm("Bronze", rough=0.4, metal=0.6)),
         text("PlaqueTxt", "OUR FOUNDER", 0.16, 0.02, (0, -1.37, 2.0), m=cm("Gold", rough=0.4, metal=0.6)),
         text("PlaqueTxt2", "1899 - 1961", 0.12, 0.02, (0, -1.37, 1.75), m=cm("Gold", rough=0.4, metal=0.6))]
    # Broken-off feet and shins left on the cap.
    p += [cyl("StumpL", 0.22, 0.6, (-0.24, 0, 3.5), segs=8, bevel=0.0, m=bronze),
          cyl("StumpR", 0.22, 0.35, (0.24, 0, 3.38), segs=8, bevel=0.0, m=bronze)]
    p += rebar("Rods", (0, 0, 3.6), (0.2, 0.3, 1), 0.5, 3, (0.15, 0, 0), seed=2, m=cm("SteelDark"))
    # The figure, lying face down across the square (head towards -X), the head rolled off.
    body = figure("F", bronze)
    body = [o for o in body if not o.name.startswith(("FHead", "FHat"))]
    xform(body, (0, 0, 0), (math.radians(-90), 0, math.radians(90)))
    xform(body, (-1.8, -3.9, 0.55), (0, math.radians(4), math.radians(8)))
    p += body
    p += [sphere("Head", 0.33, (-6.2, -5.4, 0.36), scale=(1, 1.15, 1), m=bronze, segs=10, rings=6),
          cyl("Hat", 0.36, 0.13, (-6.25, -5.7, 0.5), rot=(1.2, 0.3, 0), segs=10, bevel=0.0, m=bronze)]
    p += [ground_blob("Crack", 2.2, (-3.0, -4.0, 0.0), cm("ConcreteDark", rough=0.95), seed=5, squash=(1.6, 0.6))]
    p += chunks("Chip", (-1.0, -3.0, 0), seed=9, count=5, spread=1.2, m=stone)
    p += graffiti("Tag", "LIAR", 0.5, (0, 1.32, 2.0), NEON_PINK, rot_z=math.pi)
    p += graffiti("Tag2", "RIP", 0.45, (1.32, 0.0, 1.9), NEON_LIME, rot_z=math.pi / 2)
    csave("city_statue_toppled", [merge("Statue", p)])


def build_subway_entrance():
    """METRO stairs down: a stair flight 3.6 m wide from z = 0 (y = 0) to z = -4.2
    (y = 7.2) between tiled walls, railings round the opening at street level,
    a lit green METRO sign on two posts, a landing at the bottom."""
    reset_scene()
    tile, dark = cm("Cream", rough=0.6), cm("ConcreteDark")
    green = cm("Green", rough=0.5)
    W, run, drop, n = 3.6, 7.2, 4.2, 18
    p = []
    for k in range(n):
        y0 = k * run / n
        z = -(k + 1) * drop / n
        p.append(fbox(f"Step{k}", (W, run / n + 0.02, 0.18), (0, y0 + run / (2 * n), z + 0.09), m=dark if k % 2 else cm("Concrete")))
        p.append(fbox(f"Riser{k}", (W, 0.04, drop / n), (0, y0, z + drop / (2 * n)), m=cm("ConcreteDark")))
    p.append(fbox("Landing", (W + 0.6, 3.0, 0.2), (0, run + 1.5, -drop - 0.1), m=dark))
    for s in (-1, 1):
        x = s * (W / 2 + 0.15)
        side = [(0.0, 0.0), (run + 3.0, 0.0), (run + 3.0, -drop - 0.2), (run, -drop - 0.2), (0.0, -0.4)]
        wall = flat_prism(f"Wall{s}", [(y, z) for y, z in side], 0.3, m=tile)
        wall.rotation_euler = (0, 0, math.pi / 2)
        wall.location = (x, 0, 0)
        p.append(wall)
        band = flat_prism(f"Band{s}", [(0.0, -1.0), (run + 3.0, -drop - 1.0), (run + 3.0, -drop - 0.7), (0.0, -0.7)], 0.32, m=green)
        band.rotation_euler = (0, 0, math.pi / 2)
        band.location = (x - s * 0.005, 0, 0.0)
        p.append(band)
        # Railings round the opening at street level.
        p += [fbox(f"RailTop{s}", (0.06, run + 0.4, 0.06), (x, run / 2, 1.0), m=green),
              fbox(f"RailMid{s}", (0.04, run + 0.4, 0.04), (x, run / 2, 0.55), m=green)]
        for k in range(5):
            p.append(fbox(f"RailPost{s}{k}", (0.06, 0.06, 1.0), (x, k * run / 4, 0.5), m=green))
        p.append(tube(f"Hand{s}", [(x - s * 0.25, 0.3, 0.9), (x - s * 0.25, run, -drop + 0.9)], 0.03, m=cm("SteelLight", metal=0.6), segs=5))
    p += [fbox("RailBack", (W + 0.4, 0.06, 0.06), (0, run + 0.2, 1.0), m=green),
          fbox("BackWall", (W + 0.6, 0.3, 4.0), (0, run + 3.1, -drop + 1.8), m=tile),
          fbox("Ceiling", (W + 0.6, 3.2, 0.3), (0, run + 1.6, -0.15), m=cm("ConcreteDark"))]
    # METRO sign on two posts at the head of the stairs.
    for s in (-1, 1):
        p.append(cyl(f"SignPost{s}", 0.07, 3.0, (s * 1.2, -0.3, 1.5), segs=6, bevel=0.0, m=green))
    p += [box("SignBox", (2.8, 0.3, 0.7), (0, -0.3, 3.1), bevel=0.04, segs=1, m=cm("GreenDark")),
          text("SignTxt", "METRO", 0.5, 0.05, (0, -0.48, 3.08), m=steady("#7affb0", 2.6)),
          cyl("Globe", 0.3, 0.1, (1.75, -0.3, 3.1), rot=(math.pi / 2, 0, 0), segs=12, bevel=0.0, m=steady("#7affb0", 2.6)),
          text("GlobeTxt", "M", 0.35, 0.03, (1.75, -0.37, 3.08), m=cm("GreenDark")),
          lamp("Lamp", 0.12, (0, run + 1.5, -0.45), LAMP_EMERGENCY, strength=4.0, lit=neon(LAMP_EMERGENCY, 4.0))]
    p += graffiti("Tag", "DOWN", 0.5, (-W / 2 + 0.02, 3.0, -1.2), NEON_PINK, rot_z=-math.pi / 2)
    csave("city_subway_entrance", [merge("SubwayEntrance", p), socket("Light", (0, run + 1.5, -1.0))])


def build_market_stall():
    reset_scene()
    wood, dark = cm("WoodLight"), cm("WoodDark")
    rng = random.Random(17)
    p = [box("Counter", (3.0, 1.0, 0.9), (0, -0.3, 0.45), bevel=0.04, segs=1, m=wood),
         fbox("CounterTop", (3.1, 1.1, 0.08), (0, -0.3, 0.94), m=dark)]
    for s in (-1, 1):
        for t in (-1, 1):
            p.append(fbox(f"Post{s}{t}", (0.1, 0.1, 2.5), (s * 1.45, t * 0.9, 1.25), m=dark))
    tarp = [(-1.7, -1.4), (1.7, -1.4), (1.7, 1.1), (0.6, 1.1), (0.1, 0.4), (-0.5, 1.1), (-1.7, 1.1)]
    roof = slab("Tarp", tarp, 0.0, 0.04, m=cm("Tarp", rough=0.85))
    roof.location = (0, 0, 2.55)
    roof.rotation_euler = (math.radians(-10), 0, 0)
    p.append(roof)
    p.append(flat_prism("TarpFlap", [(-1.7, 0), (1.7, 0), (1.2, -0.5), (0.3, -0.25), (-0.6, -0.55)], 0.03, (0, -1.38, 2.75), m=cm("Tarp", rough=0.85)))
    cols = ["Orange", "Red", "Taxi", "GreenDark"]
    for k in range(5):
        x = -1.1 + k * 0.55
        p.append(box(f"Crate{k}", (0.45, 0.35, 0.25), (x, -0.4, 1.1), rot=(0, 0, rng.uniform(-0.2, 0.2)), bevel=0.02, segs=1, m=dark))
        for j in range(3):
            p.append(sphere(f"Fruit{k}{j}", 0.07, (x - 0.12 + j * 0.12, -0.42, 1.25), m=cm(cols[k % 4], rough=0.5), segs=6, rings=4))
    for k in range(3):
        p.append(box(f"Stack{k}", (0.6, 0.45, 0.4), (1.9, 0.2 - k * 0.1, 0.2 + k * 0.4), rot=(0, 0, k * 0.3), bevel=0.02, segs=1, m=wood))
    for k in range(5):
        x = -1.4 + k * 0.7
        p.append(lamp(f"Bulb{k}", 0.06, (x, -1.35, 2.4 - 0.1 * math.sin(k * 0.7 * math.pi / 1.4)), LAMP_WARM, strength=3.0, lit=neon(LAMP_WARM, 3.0)))
    p.append(tube("Wire", [(-1.45, -1.35, 2.5), (-0.7, -1.35, 2.38), (0.0, -1.35, 2.35), (0.7, -1.35, 2.38), (1.45, -1.35, 2.5)], 0.01, m=cm("Soot"), segs=3))
    p += [box("Board", (1.2, 0.04, 0.5), (0, -0.82, 0.55), bevel=0.01, segs=1, m=cm("Soot")),
          text("BoardTxt", "FRESH!", 0.22, 0.02, (0, -0.86, 0.55), m=cm("Cream"))]
    p.append(ground_blob("Scorch", 1.0, (0.8, -1.2, 0.0), cm("CharLight", rough=0.95), seed=4))
    csave("city_market_stall", [merge("MarketStall", p)])


def build_neon_sign_a():
    """Vertical HOTEL blade sign on a wall bracket; the wall is the plane y = +0.1."""
    reset_scene()
    p = [box("Bracket", (0.1, 0.9, 0.1), (0, -0.35, 4.6), bevel=0.0, m=STEEL()),
         box("BracketB", (0.1, 0.9, 0.1), (0, -0.35, 0.4), bevel=0.0, m=STEEL()),
         box("Blade", (0.3, 1.1, 4.6), (0, -1.0, 2.5), bevel=0.06, segs=1, m=cm("PoliceNavy", rough=0.5))]
    for k, ch in enumerate("HOTEL"):
        for s in (-1, 1):
            p.append(text(f"L{k}{s}", ch, 0.72, 0.06, (s * 0.17, -1.0, 4.25 - k * 0.86), rot=(0, 0, s * math.pi / 2), m=neon(NEON_PINK, 4.0)))
    for s in (-1, 1):
        for t in (-1, 1):
            p.append(fbox(f"Edge{s}{t}", (0.03, 0.03, 4.5), (s * 0.16, -1.0 + t * 0.53, 2.5), m=neon(NEON_CYAN, 1.6)))
    csave("city_neon_sign_a", [merge("NeonSignA", p)])


def build_neon_sign_b():
    """NOODLES sign with a steaming bowl, on a wall at y = +0.1 (faces -Y)."""
    reset_scene()
    p = [box("Back", (3.4, 0.2, 1.2), (0, 0.0, 0), bevel=0.06, segs=1, m=cm("Soot")),
         text("Txt", "NOODLES", 0.6, 0.06, (0.35, -0.14, -0.02), m=neon(NEON_AMBER, 3.6)),
         torus("Bowl", 0.28, 0.035, (-1.2, -0.13, -0.1), rot=(math.pi / 2, 0, 0), m=neon(NEON_RED, 3.4), major_segs=12, minor_segs=4, arc=math.pi, start=math.pi),
         fbox("Rim", (0.6, 0.04, 0.05), (-1.2, -0.13, -0.1), m=neon(NEON_RED, 3.4))]
    for k in range(3):
        x = -1.35 + k * 0.15
        p.append(tube(f"Steam{k}", [(x, -0.13, 0.05), (x + 0.05, -0.13, 0.2), (x - 0.04, -0.13, 0.35), (x + 0.03, -0.13, 0.48)], 0.02, m=neon(NEON_CYAN, 2.8), segs=4))
    p += [box("Arm", (0.08, 0.5, 0.08), (-1.4, 0.3, 0.7), bevel=0.0, m=STEEL()),
          box("ArmB", (0.08, 0.5, 0.08), (1.4, 0.3, 0.7), bevel=0.0, m=STEEL())]
    p = xform(p, (0, -0.35, 3.5))
    csave("city_neon_sign_b", [merge("NeonSignB", p)])


def build_police_barrier():
    reset_scene()
    blue, white = cm("PoliceBlue", rough=0.5), cm("White", rough=0.5)
    p = []
    for s in (-1, 1):
        for t in (-1, 1):
            p.append(beam(f"Leg{s}{t}", (s * 1.0, t * 0.35, 0.0), (s * 1.0, 0.0, 1.0), 0.07, m=cm("SteelDark")))
    p += [fbox("Plank", (2.2, 0.06, 0.32), (0, -0.04, 0.85), m=white)]
    for k in range(6):
        p.append(fbox(f"Stripe{k}", (0.18, 0.07, 0.32), (-0.95 + k * 0.38, -0.04, 0.85), m=blue))
    p += [fbox("Plank2", (2.2, 0.06, 0.2), (0, -0.04, 0.4), m=blue),
          text("Txt", "POLICE LINE", 0.14, 0.02, (0, -0.09, 0.4), m=white),
          box("LightBase", (0.2, 0.2, 0.08), (0.8, 0, 1.05), bevel=0.0, m=cm("Soot")),
          cyl("Light", 0.09, 0.18, (0.8, 0, 1.17), segs=8, bevel=0.0, m=police_m("Blue"))]
    csave("city_police_barrier", [merge("PoliceBarrier", p)])


BUILDERS = {
    "streetlight": build_streetlight,
    "traffic_light": build_traffic_light,
    "barrier_jersey": build_barrier_jersey,
    "dumpster": build_dumpster,
    "hydrant": build_hydrant,
    "billboard_torn": build_billboard_torn,
    "bus_stop": build_bus_stop,
    "newsstand": build_newsstand,
    "rubble_a": build_rubble_a,
    "rubble_b": build_rubble_b,
    "debris": build_debris,
    "statue_toppled": build_statue_toppled,
    "subway_entrance": build_subway_entrance,
    "market_stall": build_market_stall,
    "neon_sign_a": build_neon_sign_a,
    "neon_sign_b": build_neon_sign_b,
    "police_barrier": build_police_barrier,
}

if __name__ == "__main__":
    run(BUILDERS)
