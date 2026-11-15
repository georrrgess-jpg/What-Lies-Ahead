"""Ashfall City wrecks (the Endless map): burnt cars, a taxi, a riot van, a bus
and a jackknifed truck. Each saves art/blender/city_<name>.blend and
art/models/city_<name>.glb. Vehicles run along X (front at +X in Blender,
Godot +X too), sit on the ground, origin at the centre of the footprint.

Empties exported with each model (the map places effects there):
    Fire, Fire2   where a city_fire.tscn burns (engine bay, cabin, cargo)
    Light         where a strobe light sits (police van light bar)

    python art/blender/build_city_wrecks.py [car_burnt car_burnt_b taxi_wreck police_van bus_wreck truck_jackknifed]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from city_common import *  # noqa: F401,F403


def wheels(prefix, L, W, r=0.33, burnt=True, missing=(), sag=0.0, wheelbase=0.62):
    """Four wheels (rims if burnt, tyres otherwise) at +-L*wheelbase/2."""
    out = []
    for i, (sx, sy) in enumerate(((1, 1), (1, -1), (-1, 1), (-1, -1))):
        if i in missing:
            continue
        x, y = sx * L * wheelbase / 2, sy * (W / 2 - 0.12)
        z = r - (sag if burnt else 0.0)
        if burnt:
            out.append(rim(f"{prefix}Rim{i}", r * 0.72, 0.2, (x, y, z), rot_z=math.pi / 2, segs=9))
            out.append(cyl(f"{prefix}Hub{i}", r * 0.3, 0.24, (x, y, z), rot=(math.pi / 2, 0, 0), segs=6, bevel=0.0, m=cm("Rust", rough=0.8)))
        else:
            out.append(tyre(f"{prefix}Tyre{i}", r, 0.26, (x, y, z), rot=(0, 0, 0)))
            out.append(cyl(f"{prefix}Hub{i}", r * 0.55, 0.22, (x, y, z), rot=(math.pi / 2, 0, 0), segs=8, bevel=0.0, m=cm("SteelLight", metal=0.5)))
    return out


def open_cabin(prefix, x0, x1, top_x0, top_x1, z0, z1, W, frame_m, interior_m, seed=1, embers=True, glass=None, lite=False):
    """A cabin with its glass blown out: roof, pillars, charred seats inside."""
    rng = random.Random(seed)
    hw = W / 2 - 0.1
    p = [box(prefix + "Roof", (top_x1 - top_x0, W - 0.18, 0.08), ((top_x0 + top_x1) / 2, 0, z1), bevel=0.03, segs=1, m=frame_m)]
    for s in (-1, 1):
        y = s * hw
        p += [beam(f"{prefix}A{s}", (x1, y, z0), (top_x1, y, z1), 0.09, m=frame_m),
              beam(f"{prefix}C{s}", (x0, y, z0), (top_x0, y, z1), 0.12, m=frame_m),
              beam(f"{prefix}B{s}", ((x0 + x1) / 2 - 0.1, y, z0), ((top_x0 + top_x1) / 2 - 0.1, y, z1), 0.08, m=frame_m),
              beam(f"{prefix}Sill{s}", (x0, y, z0 + 0.02), (x1, y, z0 + 0.02), 0.09, m=frame_m)]
    p.append(box(prefix + "Floor", (x1 - x0 - 0.1, W - 0.3, 0.06), ((x0 + x1) / 2, 0, z0 - 0.02), bevel=0.0, m=interior_m))
    if lite:
        return p
    for k, x in enumerate((x1 - 0.55, x0 + 0.45)):
        for s in ((-1, 1) if k == 0 else (0,)):
            w = 0.5 if k == 0 else W - 0.4
            p += [box(f"{prefix}Seat{k}{s}", (0.45, w, 0.18), (x, s * 0.38, z0 + 0.1), bevel=0.04, segs=1, m=interior_m),
                  box(f"{prefix}Back{k}{s}", (0.12, w, 0.5), (x - 0.22, s * 0.38, z0 + 0.38), rot=(0, math.radians(-12), 0), bevel=0.03, segs=1, m=interior_m)]
    p.append(box(prefix + "Dash", (0.3, W - 0.3, 0.2), (x1 - 0.12, 0, z0 + 0.05), bevel=0.03, segs=1, m=interior_m))
    if embers:
        for k in range(4):
            p.append(sphere(f"{prefix}Ember{k}", rng.uniform(0.06, 0.11), (rng.uniform(x0 + 0.2, x1 - 0.3), rng.uniform(-0.5, 0.5), z0 + 0.22),
                            scale=(1.4, 1.0, 0.5), m=ember_m(), segs=6, rings=3))
    if glass is not None:
        # A few shards left in the windscreen frame.
        for k, s in enumerate((-1, 1)):
            p.append(flat_prism(f"{prefix}Shard{k}", [(0, 0), (0.32, 0), (0.05, 0.3)], 0.02,
                                (x1 - 0.04, s * (hw - 0.25), z0 + 0.05), rot=(0, math.atan2(top_x1 - x1, z1 - z0), math.pi / 2), m=glass))
    return p


def car_parts(prefix, L=4.3, W=1.85, paint="Red", burnt=True, seed=1, hood_up=False, missing=(), cabin=(-1.05, 0.75, -0.8, 0.25), lite=False):
    """A compact saloon. Burnt: char body with a band of the old paint at the rear,
    bare rims, an open charred cabin with embers; else a dented intact body."""
    rng = random.Random(seed)
    body_m = cm("CharLight", rough=0.85) if burnt else cm(paint, rough=0.45)
    paint_m = cm(paint, rough=0.55)
    char = cm("Char", rough=0.9)
    sag = 0.1 if burnt else 0.0
    z0 = 0.28 - sag
    p = [box(prefix + "Body", (L, W, 0.6), (0, 0, z0 + 0.3), bevel=0.14, segs=1, m=body_m),
         box(prefix + "Skirt", (L * 0.92, W - 0.08, 0.2), (0, 0, z0 + 0.05), bevel=0.04, segs=1, m=char)]
    # Wheel arches.
    for i, (sx, sy) in enumerate(((1, 1), (1, -1), (-1, 1), (-1, -1))):
        p.append(cyl(f"{prefix}Arch{i}", 0.42, 0.1, (sx * L * 0.31, sy * (W / 2 + 0.005), z0 + 0.12), rot=(math.pi / 2, 0, 0), segs=10,
                     bevel=0.0, m=char))
    if burnt:
        # Rear quarter keeps its paint; soot and rust blooms over the rest.
        p.append(box(prefix + "PaintRear", (L * 0.34, W + 0.02, 0.36), (-L * 0.3, 0, z0 + 0.36), bevel=0.06, segs=1, m=paint_m))
        for k in range(3):
            s = 1 if k % 2 else -1
            p.append(blob(f"{prefix}Rust{k}", rng.uniform(0.18, 0.3), (rng.uniform(-L * 0.4, L * 0.3), s * (W / 2 + 0.012), z0 + rng.uniform(0.2, 0.45)),
                          cm("Rust"), seed=seed * 9 + k, rot=(0, 0, 0 if s < 0 else math.pi)))
    x0, x1, t0, t1 = cabin
    zc0, zc1 = z0 + 0.6, z0 + 1.12
    glass = cm("Glass", rough=0.15, metal=0.3)
    if burnt:
        p += open_cabin(prefix + "Cab", x0, x1, t0, t1, zc0, zc1, W, char, cm("Soot", rough=0.95), seed=seed, glass=glass, lite=lite)
    else:
        p.append(flat_prism(prefix + "Cabin", [(x0, zc0), (x1, zc0), (t1, zc1), (t0, zc1)], W - 0.2, (0, 0, 0), m=body_m))
        p.append(flat_prism(prefix + "WinS", [(x0 + 0.12, zc0 + 0.06), (x1 - 0.12, zc0 + 0.06), (t1 - 0.05, zc1 - 0.06), (t0 + 0.06, zc1 - 0.06)],
                            W - 0.16, (0, 0, 0), m=cm("GlassDark", rough=0.2, metal=0.3)))
        p.append(box(prefix + "Roof", (t1 - t0, W - 0.2, 0.06), ((t0 + t1) / 2, 0, zc1), bevel=0.02, segs=1, m=body_m))
    # Bumpers, lights, grille.
    p += [box(prefix + "BumperF", (0.16, W + 0.04, 0.18), (L / 2 + 0.02, 0, z0 + 0.12), bevel=0.05, segs=1, m=cm("SteelDark", metal=0.4)),
          box(prefix + "BumperR", (0.16, W + 0.04, 0.18), (-L / 2 - 0.02, 0, z0 + 0.12), bevel=0.05, segs=1, m=cm("SteelDark", metal=0.4)),
          box(prefix + "Grille", (0.06, W * 0.5, 0.18), (L / 2 + 0.01, 0, z0 + 0.38), bevel=0.0, m=cm("Soot"))]
    head = cm("White", rough=0.3) if not burnt else cm("Soot")
    for s in (-1, 1):
        p += [box(f"{prefix}Head{s}", (0.06, 0.32, 0.14), (L / 2 + 0.01, s * (W / 2 - 0.25), z0 + 0.42), bevel=0.02, segs=1, m=head),
              box(f"{prefix}Tail{s}", (0.06, 0.3, 0.14), (-L / 2 - 0.01, s * (W / 2 - 0.25), z0 + 0.44), bevel=0.02, segs=1, m=cm("RedDark"))]
    if hood_up:
        p.append(box(prefix + "Hood", (1.25, W - 0.1, 0.06), (L / 2 - 0.62, 0, z0 + 0.62), bevel=0.03, segs=1, m=body_m))
        p[-1].rotation_euler = (0, math.radians(-38), 0)
        p[-1].location = (L / 2 - 0.85, 0, z0 + 0.98)
        p.append(box(prefix + "Engine", (0.8, W - 0.5, 0.25), (L / 2 - 0.65, 0, z0 + 0.6), bevel=0.04, segs=1, m=char))
        for k, (dx, dy) in enumerate(((-0.75, -0.2), (-0.5, 0.25), (-0.4, -0.35))):
            p.append(sphere(f"{prefix}EngineGlow{k}", 0.1, (L / 2 + dx, dy, z0 + 0.74), scale=(1.4, 1.0, 0.45), m=ember_m(), segs=6, rings=3))
    p += wheels(prefix, L, W, burnt=burnt, missing=missing, sag=sag)
    return p


def build_car_burnt():
    """Burnt-out saloon, 4.3 x 1.9 x 1.4 m: charred shell on bare rims, red rear quarter."""
    reset_scene()
    p = car_parts("C_", paint="Red", seed=3)
    xform(p, rot=(math.radians(-2.5), 0, 0))
    csave("city_car_burnt", [merge("CarBurnt", p), socket("Fire", (0.2, 0, 0.9))])


def build_car_burnt_b():
    """Burnt hatchback with its bonnet sprung and the engine still glowing; a
    wheel gone so it slumps on one corner. 4.0 x 1.8 m."""
    reset_scene()
    p = car_parts("D_", L=4.0, W=1.8, paint="Teal", seed=7, hood_up=True, missing=(3,), cabin=(-1.35, 0.55, -1.25, 0.1))
    xform(p, loc=(0, 0, -0.06), rot=(math.radians(3.5), math.radians(-2.5), 0))
    csave("city_car_burnt_b", [merge("CarBurntB", p), socket("Fire", (1.45, 0, 0.9))])


def build_taxi_wreck():
    """Smashed yellow cab, 4.6 x 1.9 m: intact paint under soot, a checker band,
    the roof TAXI sign, a shattered windscreen and a smoking engine."""
    reset_scene()
    L, W = 4.6, 1.9
    p = car_parts("T_", L=L, W=W, paint="Taxi", burnt=False, seed=5, cabin=(-1.1, 0.85, -0.85, 0.3))
    rng = random.Random(5)
    for s in (-1, 1):
        for k in range(14):
            if k % 2 == 0:
                p.append(fbox(f"T_Chk{s}{k}", (0.16, 0.012, 0.09), (-1.1 + k * 0.16, s * (W / 2 + 0.006), 0.54), m=cm("Soot")))
            p.append(fbox(f"T_ChkB{s}{k}", (0.16, 0.012, 0.09), (-1.1 + k * 0.16, s * (W / 2 + 0.006), 0.45),
                          m=cm("Soot") if k % 2 else cm("Taxi", rough=0.45)))
    p += [box("T_SignBase", (0.7, 0.3, 0.06), (-0.25, 0, 1.45), bevel=0.02, segs=1, m=cm("Soot")),
          box("T_Sign", (0.62, 0.22, 0.2), (-0.25, 0, 1.58), bevel=0.04, segs=1, m=steady(NEON_AMBER, 1.6))]
    p.append(text("T_SignTxt", "TAXI", 0.13, 0.02, (-0.25, -0.12, 1.57), m=cm("Soot")))
    # Crumpled front, soot on the bonnet, a crack web on the screen.
    p += [blob("T_Soot", 0.4, (1.6, 0, 0.91), cm("CharLight"), seed=2, rot=(math.radians(90), 0, 0), squash=(1.2, 0.8)),
          box("T_Crumple", (0.5, W - 0.1, 0.25), (L / 2 - 0.2, 0, 0.82), rot=(0, math.radians(-16), 0), bevel=0.05, segs=1, m=cm("Taxi", rough=0.45))]
    for k in range(5):
        a = k * 0.7 + rng.uniform(-0.2, 0.2)
        p.append(beam(f"T_Crack{k}", (0.66, 0.2, 1.08), (0.66 - 0.3 * math.cos(a) * 0.4, 0.2 + math.sin(a) * 0.5, 1.08 + math.cos(a) * 0.25), 0.015,
                      m=cm("White", rough=0.3)))
    csave("city_taxi_wreck", [merge("TaxiWreck", p), socket("Fire", (1.7, 0, 0.95))])


def build_police_van():
    """Riot van, 5.6 x 2.1 x 2.5 m: navy and white with a POLICE band, a red/blue
    light bar (strobes in game), mesh guards on the windscreen, one rear door
    hanging open, a flat tyre."""
    reset_scene()
    L, W, H = 5.6, 2.1, 2.45
    navy, white = cm("PoliceNavy", rough=0.5), cm("White", rough=0.5)
    steel, dark = cm("SteelDark", metal=0.4), cm("Soot")
    p = [box("V_Box", (3.7, W, 2.0), (-0.85, 0, 1.33), bevel=0.12, segs=1, m=white),
         box("V_Cab", (1.75, W, 1.45), (1.9, 0, 1.05), bevel=0.14, segs=1, m=white),
         flat_prism("V_Wind", [(1.0, 1.78), (1.65, 1.78), (2.35, 1.3), (1.0, 1.3)], W - 0.06, (0, 0, 0), m=cm("GlassDark", rough=0.2, metal=0.3)),
         box("V_Skirt", (L - 0.2, W - 0.1, 0.3), (0, 0, 0.35), bevel=0.05, segs=1, m=navy),
         box("V_Band", (3.72, W + 0.03, 0.42), (-0.85, 0, 1.0), bevel=0.04, segs=1, m=navy),
         box("V_BumperF", (0.18, W + 0.05, 0.25), (L / 2 + 0.03, 0, 0.45), bevel=0.05, segs=1, m=steel),
         box("V_Grille", (0.06, 1.1, 0.35), (L / 2 - 0.05, 0, 0.82), bevel=0.0, m=dark)]
    for s in (-1, 1):
        p.append(text(f"V_Txt{s}", "POLICE", 0.34, 0.03, (-0.85, s * (W / 2 + 0.02), 1.0), rot=(0, 0, 0 if s < 0 else math.pi), m=white))
        p.append(box(f"V_Win{s}", (1.6, 0.04, 0.5), (-0.6, s * (W / 2 + 0.005), 1.75), bevel=0.0, m=cm("GlassDark", rough=0.2)))
        for k in range(6):
            p.append(fbox(f"V_Mesh{s}{k}", (0.03, 0.05, 0.5), (-1.35 + k * 0.3, s * (W / 2 + 0.03), 1.75), m=steel))
        p.append(box(f"V_Head{s}", (0.06, 0.34, 0.16), (L / 2 - 0.02, s * 0.7, 0.88), bevel=0.02, segs=1, m=cm("White", rough=0.2)))
    # Windscreen guard bars.
    for k in range(5):
        p.append(beam(f"V_Guard{k}", (2.38, -0.8 + k * 0.4, 1.28), (1.68, -0.8 + k * 0.4, 1.8), 0.04, m=steel))
    # Light bar on the cab roof: red half (+Y) and blue half (-Y).
    p += [box("V_BarBase", (0.36, 1.5, 0.08), (1.75, 0, 1.82), bevel=0.02, segs=1, m=dark),
          box("V_BarRed", (0.3, 0.68, 0.16), (1.75, 0.37, 1.93), bevel=0.04, segs=1, m=police_m("Red")),
          box("V_BarBlue", (0.3, 0.68, 0.16), (1.75, -0.37, 1.93), bevel=0.04, segs=1, m=police_m("Blue"))]
    # Rear doors: one shut, one hanging open; dark inside with a bench.
    p += [box("V_Inside", (0.1, W - 0.2, 1.75), (-2.62, 0, 1.3), bevel=0.0, m=cm("Interior")),
          box("V_DoorL", (0.08, W / 2 - 0.05, 1.8), (-2.74, 0.52, 1.3), bevel=0.03, segs=1, m=white),
          box("V_DoorR", (0.08, W / 2 - 0.05, 1.8), (-3.05, -1.3, 1.3), rot=(0, 0, math.radians(-62)), bevel=0.03, segs=1, m=white),
          box("V_Step", (0.35, W - 0.3, 0.1), (-2.85, 0, 0.45), bevel=0.02, segs=1, m=steel)]
    p += wheels("V_", L, W, r=0.42, burnt=False, wheelbase=0.6)
    xform(p, rot=(math.radians(-2.0), 0, 0))
    csave("city_police_van", [merge("PoliceVan", p), socket("Light", (1.75, 0, 2.1)), socket("Fire", (-1.2, 0, 2.4))])


def build_bus_wreck():
    """City bus, 11 x 2.6 x 3.1 m: teal and orange livery, the middle burnt out
    to the frame, blown windows with shards, an amber route sign."""
    reset_scene()
    L, W = 11.0, 2.6
    teal, orange, char = cm("Teal", rough=0.5), cm("Orange", rough=0.5), cm("Char", rough=0.9)
    soot, steel = cm("Soot", rough=0.95), cm("SteelDark", metal=0.4)
    glass = cm("Glass", rough=0.15, metal=0.3)
    rng = random.Random(11)
    p = [box("B_Lower", (L, W, 0.95), (0, 0, 0.82), bevel=0.15, segs=1, m=teal),
         box("B_Stripe", (L + 0.02, W + 0.02, 0.18), (0, 0, 1.2), bevel=0.04, segs=1, m=orange),
         box("B_Floor", (L - 0.4, W - 0.2, 0.08), (0, 0, 1.3), bevel=0.0, m=soot),
         box("B_Front", (0.14, W, 1.6), (L / 2 - 0.07, 0, 2.1), bevel=0.04, segs=1, m=teal),
         box("B_Back", (0.14, W, 1.6), (-L / 2 + 0.07, 0, 2.1), bevel=0.04, segs=1, m=teal),
         box("B_Sign", (0.08, 1.6, 0.28), (L / 2 + 0.01, 0, 2.75), bevel=0.0, m=steady(NEON_AMBER, 2.2)),
         text("B_SignTxt", "13 DOWNTOWN", 0.18, 0.02, (L / 2 + 0.06, 0, 2.74), rot=(0, 0, math.pi / 2), m=soot),
         box("B_Wind", (0.06, W - 0.3, 1.0), (L / 2 + 0.005, 0, 1.95), bevel=0.0, m=cm("GlassDark", rough=0.2, metal=0.3))]
    # Roof in two pieces with the middle burnt through (charred ribs between).
    p += [box("B_RoofF", (3.6, W, 0.14), (L / 2 - 1.8, 0, 2.95), bevel=0.06, segs=1, m=cm("White", rough=0.5)),
          box("B_RoofR", (3.2, W, 0.14), (-L / 2 + 1.6, 0, 2.95), bevel=0.06, segs=1, m=cm("White", rough=0.5))]
    for k in range(5):
        x = -1.9 + k * 0.85
        p.append(beam(f"B_Rib{k}", (x, -W / 2 + 0.06, 2.9), (x + rng.uniform(-0.1, 0.1), W / 2 - 0.06, 2.9 - rng.uniform(0.0, 0.35)), 0.07, m=char))
    # Window pillars down both sides; burnt zone in the middle.
    for s in (-1, 1):
        y = s * (W / 2 - 0.05)
        for k in range(12):
            x = -L / 2 + 0.5 + k * 0.91
            burnt = -2.3 < x < 2.3
            p.append(fbox(f"B_Pil{s}{k}", (0.12, 0.1, 1.55), (x, y, 2.1), m=char if burnt else teal))
            if not burnt and k < 11 and rng.random() < 0.6:
                p += shards(f"B_Sh{s}{k}", 0.78, 1.2, (x + 0.455, y, 2.1), m=glass, seed=s * 31 + k, rot_z=0 if s < 0 else math.pi)
        p.append(box(f"B_Sill{s}", (L - 0.3, 0.12, 0.1), (0, y, 1.33), bevel=0.0, m=teal))
        p.append(box(f"B_Char{s}", (4.8, 0.04, 0.9), (0, s * (W / 2 + 0.01), 0.85), bevel=0.0, m=char))
        p.append(box(f"B_Door{s}", (1.1, 0.06, 1.9), (3.4, s * (W / 2 + 0.01), 1.4), bevel=0.0, m=cm("GlassDark", rough=0.2)) if s < 0 else
                 box(f"B_Ad{s}", (2.6, 0.04, 0.6), (-2.9, s * (W / 2 + 0.02), 0.8), bevel=0.0, m=cm("Pink", rough=0.6)))
    p.append(text("B_AdTxt", "SMILE CITY", 0.28, 0.02, (-2.9, W / 2 + 0.05, 0.8), rot=(0, 0, math.pi), m=cm("Cream")))
    # Charred seats in the burnt zone, embers smouldering.
    for k in range(5):
        for s in (-1, 1):
            p.append(box(f"B_Seat{k}{s}", (0.45, 0.9, 0.5), (-1.9 + k * 0.9, s * 0.72, 1.6), bevel=0.05, segs=1, m=soot))
    for k in range(6):
        p.append(sphere(f"B_Ember{k}", rng.uniform(0.08, 0.14), (rng.uniform(-2.0, 2.0), rng.uniform(-0.9, 0.9), 1.86), scale=(1.5, 1, 0.5), m=ember_m(), segs=6, rings=3))
    p += [box("B_Bumper", (0.2, W + 0.05, 0.3), (L / 2 + 0.05, 0, 0.45), bevel=0.05, segs=1, m=steel),
          box("B_BumperR", (0.2, W + 0.05, 0.3), (-L / 2 - 0.05, 0, 0.45), bevel=0.05, segs=1, m=steel)]
    for s in (-1, 1):
        p.append(box(f"B_Head{s}", (0.06, 0.4, 0.2), (L / 2 + 0.02, s * 0.9, 0.8), bevel=0.02, segs=1, m=cm("White", rough=0.2)))
    for i, x in enumerate((3.6, -3.2)):
        for s in (-1, 1):
            p.append(tyre(f"B_Tyre{i}{s}", 0.5, 0.34, (x, s * (W / 2 - 0.2), 0.5)) if i == 0 else
                     rim(f"B_Rim{i}{s}", 0.36, 0.26, (x, s * (W / 2 - 0.2), 0.38), rot_z=math.pi / 2))
    xform(p, rot=(math.radians(1.5), 0, 0))
    csave("city_bus_wreck", [merge("BusWreck", p), socket("Fire", (0.0, 0, 1.9)), socket("Fire2", (-1.6, 0.6, 1.9))])


def build_truck_jackknifed():
    """Jackknifed lorry, ~12 x 7 m footprint: the cab swung 55 degrees off a
    hazard-striped box trailer, spilled crates and barrels at its tail."""
    reset_scene()
    red, steel, dark = cm("Red", rough=0.5), cm("SteelDark", metal=0.4), cm("Soot")
    rust = cm("Rust", rough=0.85)
    # Trailer along X, rear at -X.
    T = 8.5
    p = [box("K_Trailer", (T, 2.5, 2.7), (-1.5, 0, 2.05), bevel=0.06, segs=1, m=cm("ConcreteLight", rough=0.6)),
         box("K_Chassis", (T, 1.6, 0.3), (-1.5, 0, 0.6), bevel=0.0, m=steel)]
    for s in (-1, 1):
        for k in range(9):
            p.append(fbox(f"K_Rib{s}{k}", (0.08, 0.06, 2.7), (-1.5 - T / 2 + 0.5 + k * 1.0, s * 1.27, 2.05), m=cm("Steel", metal=0.4)))
        p += place(hazard(f"K_Haz{s}", T - 0.2, 0.32, (0, 0, 0), stripe=0.5), (-1.5, s * 1.29, 0.95), rot_z=0 if s < 0 else math.pi)
        p.append(text(f"K_Txt{s}", "RUBY FREIGHT", 0.5, 0.03, (-1.5, s * 1.3, 2.3), rot=(0, 0, 0 if s < 0 else math.pi), m=red))
    # Rear doors burst open.
    p += [box("K_Inside", (0.1, 2.3, 2.5), (-1.5 - T / 2 + 0.1, 0, 2.05), bevel=0.0, m=cm("Interior")),
          box("K_DoorA", (0.08, 1.2, 2.6), (-1.5 - T / 2 - 0.55, 1.6, 2.05), rot=(0, 0, math.radians(70)), bevel=0.02, segs=1, m=cm("ConcreteLight", rough=0.6)),
          box("K_DoorB", (0.08, 1.2, 2.6), (-1.5 - T / 2 - 0.3, -1.6, 2.05), rot=(0, 0, math.radians(-95)), bevel=0.02, segs=1, m=cm("ConcreteLight", rough=0.6))]
    for i, x in enumerate((-4.6, -5.6)):
        for s in (-1, 1):
            p.append(tyre(f"K_Tyre{i}{s}", 0.5, 0.4, (x, s * 0.9, 0.5)))
    # Cab at the front, swung round the fifth wheel at (2.6, 0).
    cab = [box("K_Cab", (2.3, 2.45, 2.4), (1.3, 0, 1.75), bevel=0.15, segs=1, m=red),
           box("K_CabLow", (2.4, 2.4, 0.6), (1.3, 0, 0.75), bevel=0.06, segs=1, m=steel),
           box("K_Wind", (0.06, 2.1, 1.0), (2.45, 0, 2.25), bevel=0.0, m=cm("GlassDark", rough=0.2, metal=0.3)),
           box("K_Grille", (0.08, 1.6, 0.8), (2.46, 0, 1.2), bevel=0.0, m=cm("SteelLight", metal=0.6)),
           box("K_Bumper", (0.25, 2.5, 0.35), (2.55, 0, 0.55), bevel=0.06, segs=1, m=steel),
           cyl("K_Stack", 0.1, 1.6, (0.15, 1.1, 3.3), segs=8, bevel=0.0, m=cm("SteelLight", metal=0.6))]
    for s in (-1, 1):
        cab.append(tyre(f"K_CabTyre{s}", 0.52, 0.4, (1.7, s * 1.0, 0.5)))
        cab.append(box(f"K_Lamp{s}", (0.06, 0.35, 0.2), (2.5, s * 0.9, 1.0), bevel=0.02, segs=1, m=cm("White", rough=0.2)))
    place(cab, (3.0, 0.1, 0), rot_z=math.radians(55))
    p += cab
    # Spilled cargo.
    rng = random.Random(4)
    for k in range(5):
        x, y = -7.2 + rng.uniform(-1.2, 0.8), rng.uniform(-2.2, 2.2)
        s = rng.uniform(0.7, 1.0)
        p.append(box(f"K_Crate{k}", (s, s, s * 0.85), (x, y, s * 0.42), rot=(0, 0, rng.uniform(0, 1.5)), bevel=0.04, segs=1, m=cm("WoodLight")))
    for k in range(3):
        x, y = -6.4 + k * 0.6, -2.4 + rng.uniform(-0.3, 0.3)
        p.append(cyl(f"K_Barrel{k}", 0.3, 0.9, (x, y, 0.3), rot=(math.pi / 2, 0, rng.uniform(0, 3)), segs=10, bevel=0.03, m=cm("Hazard" if k != 1 else "Blue", rough=0.5)))
    p.append(ground_blob("K_Spill", 1.4, (-6.0, -2.8, 0.0), cm("Soot", rough=0.3), seed=6, squash=(1.3, 0.8)))
    csave("city_truck_jackknifed", [merge("TruckJackknifed", p), socket("Fire", (3.6, 1.0, 2.2)), socket("Fire2", (-6.0, -2.6, 0.2))])


BUILDERS = {
    "car_burnt": build_car_burnt,
    "car_burnt_b": build_car_burnt_b,
    "taxi_wreck": build_taxi_wreck,
    "police_van": build_police_van,
    "bus_wreck": build_bus_wreck,
    "truck_jackknifed": build_truck_jackknifed,
}

if __name__ == "__main__":
    run(BUILDERS)
