"""Ashfall City feature props (the Endless map) and its loadout station.

    city_trap_fire      a burst gas main under a 4 x 4 m grate: the pipe, four burner
                        nozzles, the valve console. Empties Burner0..3 (flames), Console
    city_trap_shock     a generator wired to a 4 x 4 m steel floor grid with four coil
                        posts. Empties Spark0..3 (coil tips), Console
    city_supply_crate   an airdrop crate (node Crate, origin at its base) under its
                        parachute (node Parachute, origin at the crate's top, so it can
                        be detached and blown away). Empty Beacon
    city_station        "ASHFALL SUPPLY": a shipping container turned shop, 5.2 x 2.6 m,
                        service flap on -Y (scenes/props/city_station.tscn):
        Station        the container, sandbags, floodlights, stock (static)
        Shutter        the steel flap, pivot on its top hinge, in its closed pose;
                       the scene swings it to -70 degrees
        OpenDressing   the lit OPEN sign and the flap's props (open only)
        ClosedSign     the BACK SOON board on the flap (closed only)

    python art/blender/build_city_features.py [trap_fire trap_shock supply_crate station]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from city_common import *  # noqa: F401,F403
from city_common import _finish  # noqa: F401
from build_city_gates import posters  # noqa: E402

TRAP = 4.0


def grate(prefix, size, m_frame, m_bar, bars=9):
    """A steel floor grate, size x size, top at z = 0.06."""
    p = [fbox(prefix + "Frame", (size + 0.3, size + 0.3, 0.06), (0, 0, 0.03), m=m_frame),
         fbox(prefix + "Pit", (size - 0.1, size - 0.1, 0.02), (0, 0, 0.065), m=cm("Interior"))]
    for k in range(bars):
        x = -size / 2 + (k + 0.5) * size / bars
        p.append(fbox(f"{prefix}Bar{k}", (0.08, size - 0.1, 0.08), (x, 0, 0.08), m=m_bar))
    for k in range(3):
        y = -size / 2 + (k + 1) * size / 4
        p.append(fbox(f"{prefix}Cross{k}", (size - 0.1, 0.06, 0.06), (0, y, 0.075), m=m_bar))
    return p


def console(prefix, loc, rot_z, lamp_color, label):
    """A hazard-striped control box on a post with a lever and a status lamp (faces -Y)."""
    dark = cm("SteelDark", metal=0.5)
    p = [fbox(prefix + "Post", (0.16, 0.16, 1.0), (0, 0.1, 0.5), m=dark),
         box(prefix + "Box", (0.7, 0.4, 0.6), (0, 0, 1.2), bevel=0.04, segs=1, m=cm("Hazard", rough=0.55)),
         fbox(prefix + "Face", (0.56, 0.03, 0.4), (0, -0.21, 1.22), m=cm("HazardDark")),
         beam(prefix + "Lever", (0.15, -0.25, 1.15), (0.2, -0.45, 1.45), 0.05, m=cm("SteelLight", metal=0.6)),
         sphere(prefix + "Knob", 0.07, (0.2, -0.46, 1.47), m=cm("Red"), segs=8, rings=5),
         lamp(prefix + "Lamp", 0.07, (-0.15, -0.24, 1.3), lamp_color, strength=4.0, lit=neon(lamp_color, 4.0)),
         text(prefix + "Txt", label, 0.09, 0.01, (0, -0.225, 1.1), m=cm("Hazard"))]
    return place(p, loc, rot_z)


def build_trap_fire():
    reset_scene()
    steel, dark = cm("Steel", metal=0.5), cm("SteelDark", metal=0.5)
    gas = cm("Hazard", rough=0.5, metal=0.2)
    p = grate("G", TRAP, dark, steel)
    p.append(ground_blob("Scorch", TRAP * 0.62, (0, 0, -0.005), cm("Char", rough=0.95), seed=7))
    # The main: a fat yellow pipe surfacing at both edges, a manifold under the grate.
    p += [cyl("PipeIn", 0.28, 1.2, (-TRAP / 2 - 0.6, 0, 0.1), rot=(0, math.pi / 2, 0), segs=10, bevel=0.0, m=gas),
          cyl("PipeOut", 0.28, 1.0, (TRAP / 2 + 0.5, 0, 0.1), rot=(0, math.pi / 2, 0), segs=10, bevel=0.0, m=gas),
          cyl("Flange", 0.38, 0.12, (-TRAP / 2 - 0.05, 0, 0.12), rot=(0, math.pi / 2, 0), segs=10, bevel=0.0, m=dark)]
    burners = []
    for k, (x, y) in enumerate(((-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0))):
        p += [cyl(f"Nozzle{k}", 0.13, 0.4, (x, y, 0.2), segs=8, bevel=0.0, m=dark),
              cyl(f"Tip{k}", 0.18, 0.1, (x, y, 0.42), segs=8, bevel=0.0, m=cm("Rust", metal=0.4), radius_top=0.12),
              cyl(f"Glow{k}", 0.1, 0.03, (x, y, 0.47), segs=8, bevel=0.0, m=ember_m())]
        burners.append(socket(f"Burner{k}", (x, y, 0.48)))
    # Valve wheel on the pipe and the console behind it.
    p += [torus("Wheel", 0.3, 0.04, (-TRAP / 2 - 0.8, 0, 0.75), rot=(0, math.pi / 2, 0), m=cm("Red"), major_segs=12, minor_segs=4),
          cyl("Stem", 0.05, 0.5, (-TRAP / 2 - 0.8, 0, 0.45), segs=6, bevel=0.0, m=dark)]
    p += console("Con", (-TRAP / 2 - 0.9, 1.4, 0), math.pi / 2, NEON_AMBER, "GAS")
    p += [fbox("SignPost", (0.08, 0.08, 1.6), (TRAP / 2 + 0.6, -1.6, 0.8), m=dark),
          box("Sign", (0.9, 0.04, 0.6), (TRAP / 2 + 0.6, -1.64, 1.5), bevel=0.01, segs=1, m=cm("Hazard", rough=0.5)),
          text("SignTxt", "GAS MAIN", 0.15, 0.02, (TRAP / 2 + 0.6, -1.68, 1.58), m=cm("HazardDark")),
          text("SignTxt2", "DANGER", 0.13, 0.02, (TRAP / 2 + 0.6, -1.68, 1.38), m=cm("Red"))]
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        p.append(cyl(f"Cone{k}", 0.2, 0.6, (math.cos(a) * (TRAP / 2 + 0.5), math.sin(a) * (TRAP / 2 + 0.5), 0.3), segs=8, bevel=0.0, m=cm("Orange"), radius_top=0.04))
    csave("city_trap_fire", [merge("TrapFire", p), socket("Console", (-TRAP / 2 - 0.9, 1.4, 1.2))] + burners)


def build_trap_shock():
    reset_scene()
    steel, dark = cm("SteelLight", rough=0.35, metal=0.7), cm("SteelDark", metal=0.5)
    p = grate("G", TRAP, dark, steel, bars=11)
    sparks = []
    for k, (x, y) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        cx, cy = x * (TRAP / 2 + 0.25), y * (TRAP / 2 + 0.25)
        p += [box(f"Foot{k}", (0.5, 0.5, 0.2), (cx, cy, 0.1), bevel=0.03, segs=1, m=cm("ConcreteDark")),
              cyl(f"Post{k}", 0.08, 1.8, (cx, cy, 1.1), segs=6, bevel=0.0, m=dark)]
        for j in range(4):
            p.append(cyl(f"Coil{k}{j}", 0.17, 0.08, (cx, cy, 1.25 + j * 0.16), segs=8, bevel=0.0, m=cm("RustLight", metal=0.6)))
        p.append(sphere(f"Ball{k}", 0.16, (cx, cy, 2.1), m=neon(NEON_CYAN, 3.0), segs=8, rings=5))
        sparks.append(socket(f"Spark{k}", (cx, cy, 2.1)))
    # Generator on a pallet at +X with an exhaust and fat cables to the grid.
    gen = [box("Pallet", (1.6, 1.1, 0.15), (0, 0, 0.075), bevel=0.0, m=cm("WoodLight")),
           box("Gen", (1.4, 0.9, 0.9), (0, 0, 0.6), bevel=0.06, segs=1, m=cm("Taxi", rough=0.5)),
           box("GenTop", (1.0, 0.7, 0.2), (0.1, 0, 1.15), bevel=0.04, segs=1, m=dark),
           cyl("Exhaust", 0.07, 0.6, (-0.45, 0.25, 1.35), segs=6, bevel=0.0, m=dark),
           text("GenTxt", "HIGH VOLTAGE", 0.1, 0.01, (0, -0.46, 0.75), m=cm("Soot")),
           fbox("GenBolt", (0.3, 0.02, 0.3), (0, -0.46, 0.5), m=cm("Soot"))]
    for k in range(3):
        gen.append(fbox(f"Vent{k}", (0.03, 0.92, 0.5), (0.55 - k * 0.1, 0, 0.62), m=dark))
    p += place(gen, (TRAP / 2 + 1.6, 0.6, 0))
    for k, (x, y) in enumerate(((TRAP / 2 + 0.9, 0.3), (TRAP / 2 + 0.9, 0.9))):
        p.append(tube(f"Cable{k}", [(x, y, 0.5), (x - 0.3, y, 0.08), (x - 0.9, y - 0.4 * k, 0.06), (TRAP / 2 - 0.2, y - 1.5 * k, 0.1)], 0.05, m=cm("Rubber"), segs=5))
    for k in range(4):
        a, b = k, (k + 1) % 4
        xs = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        pa = (xs[a][0] * (TRAP / 2 + 0.25), xs[a][1] * (TRAP / 2 + 0.25), 1.95)
        pb = (xs[b][0] * (TRAP / 2 + 0.25), xs[b][1] * (TRAP / 2 + 0.25), 1.95)
        mid = ((pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2, 1.7)
        p.append(tube(f"Wire{k}", [pa, mid, pb], 0.015, m=cm("Rust", metal=0.5), segs=3))
    p += console("Con", (-TRAP / 2 - 0.9, -1.2, 0), math.pi / 2, NEON_CYAN, "POWER")
    csave("city_trap_shock", [merge("TrapShock", p), socket("Console", (-TRAP / 2 - 0.9, -1.2, 1.2))] + sparks)


def build_supply_crate():
    reset_scene()
    S = 1.3
    wood, dark = cm("WoodLight"), cm("SteelDark", metal=0.5)
    crate = [box("Body", (S, S, S * 0.85), (0, 0, S * 0.425), bevel=0.05, segs=1, m=cm("GreenDark", rough=0.7))]
    for s in (-1, 1):
        crate += [fbox(f"BandX{s}", (S + 0.04, 0.12, S * 0.85 + 0.04), (0, s * S * 0.3, S * 0.425), m=dark),
                  fbox(f"BandY{s}", (0.12, S + 0.04, S * 0.85 + 0.04), (s * S * 0.3, 0, S * 0.425), m=dark)]
    for s in (-1, 1):
        crate += place(hazard(f"Haz{s}", S - 0.1, 0.16, stripe=0.2, depth=0.02), (0, s * (S / 2 + 0.015), 0.15), rot_z=0 if s < 0 else math.pi)
        crate.append(text(f"Txt{s}", "SUPPLY", 0.2, 0.02, (0, s * (S / 2 + 0.03), S * 0.55), rot=(0, 0, 0 if s < 0 else math.pi), m=cm("Cream")))
    crate += [box("Skid", (S + 0.1, 0.2, 0.12), (0, -S * 0.35, 0.06), bevel=0.02, segs=1, m=wood),
              box("Skid2", (S + 0.1, 0.2, 0.12), (0, S * 0.35, 0.06), bevel=0.02, segs=1, m=wood),
              cyl("BeaconBase", 0.1, 0.08, (0.35, 0.35, S * 0.85 + 0.04), segs=8, bevel=0.0, m=dark),
              lamp("Beacon", 0.08, (0.35, 0.35, S * 0.85 + 0.14), NEON_LIME, strength=4.0, lit=neon(NEON_LIME, 4.0))]
    for k, (x, y) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        crate.append(box(f"Corner{k}", (0.16, 0.16, 0.16), (x * S / 2, y * S / 2, S * 0.85), bevel=0.02, segs=1, m=cm("Hazard")))
    crate_ob = merge("Crate", crate)
    # Parachute: a striped dome on lines, origin at the crate's top centre.
    top = S * 0.85
    chute = []
    R, H = 2.2, 3.4
    gores = 10
    for k in range(gores):
        a0, a1 = math.tau * k / gores, math.tau * (k + 1) / gores
        pts = []
        for j in range(4):
            t = j / 3
            r = R * math.sin(t * math.pi / 2)
            z = H + 1.1 * math.cos(t * math.pi / 2)
            pts.append((r, z))
        quads = []
        for j in range(3):
            r0, z0 = pts[j]
            r1, z1 = pts[j + 1]
            quad = [(math.cos(a0) * r0, math.sin(a0) * r0, z0), (math.cos(a1) * r0, math.sin(a1) * r0, z0),
                    (math.cos(a1) * r1, math.sin(a1) * r1, z1), (math.cos(a0) * r1, math.sin(a0) * r1, z1)]
            quads.append(quad)
        bm = bmesh.new()
        for quad in quads:
            vs = [bm.verts.new(v) for v in quad]
            try:
                bm.faces.new(vs)
            except ValueError:
                pass
        dup = bmesh.ops.duplicate(bm, geom=list(bm.faces))
        bmesh.ops.reverse_faces(bm, faces=[g for g in dup["geom"] if isinstance(g, bmesh.types.BMFace)])
        ob = make_flat(_finish(f"Gore{k}", bm, cm("Orange" if k % 2 else "White", rough=0.85), (0, 0, 0), (0, 0, 0), smooth=False))
        chute.append(ob)
    for k in range(8):
        a = math.tau * k / 8
        edge = (math.cos(a) * R * 0.98, math.sin(a) * R * 0.98, H + 0.1)
        corner = (math.copysign(S * 0.45, math.cos(a)), math.copysign(S * 0.45, math.sin(a)), 0.0)
        chute.append(tube(f"Line{k}", [corner, edge], 0.012, m=cm("Cream"), segs=3, cap=False))
    chute_ob = merge("Parachute", chute)
    chute_ob.location = (0, 0, top)
    csave("city_supply_crate", [crate_ob, chute_ob, socket("Beacon", (0.35, 0.35, top + 0.2))])


# ---------------------------------------------------------------------------
# Station
# ---------------------------------------------------------------------------

L, WD, H = 5.2, 2.6, 2.7
WIN_W, WIN_LO, WIN_HI = 3.4, 1.05, 2.25
HINGE = (0.0, -WD / 2 - 0.06, WIN_HI + 0.05)
FLAP = WIN_HI - WIN_LO + 0.15
FLAP_CLOSED = -6.0
FLAP_OPEN = -70.0


def container_shop():
    body = cm("Blue", rough=0.6, metal=0.2)
    dark = cm("SteelDark", metal=0.5)
    p = [fbox("Floor", (L + 0.6, WD + 1.6, 0.2), (0, -0.4, 0.1), m=cm("ConcreteLight")),
         fbox("Back", (L, 0.12, H), (0, WD / 2, 0.2 + H / 2), m=body),
         fbox("EndL", (0.12, WD, H), (-L / 2, 0, 0.2 + H / 2), m=body),
         fbox("EndR", (0.12, WD, H), (L / 2, 0, 0.2 + H / 2), m=body),
         fbox("Roof", (L + 0.1, WD + 0.1, 0.12), (0, 0, 0.2 + H), m=body),
         fbox("FrontLo", (L, 0.12, WIN_LO), (0, -WD / 2, 0.2 + WIN_LO / 2), m=body),
         fbox("FrontHi", (L, 0.12, H - WIN_HI), (0, -WD / 2, 0.2 + (H + WIN_HI) / 2), m=body),
         fbox("FrontL", ((L - WIN_W) / 2, 0.12, WIN_HI - WIN_LO), (-(L + WIN_W) / 4, -WD / 2, 0.2 + (WIN_LO + WIN_HI) / 2), m=body),
         fbox("FrontR", ((L - WIN_W) / 2, 0.12, WIN_HI - WIN_LO), ((L + WIN_W) / 4, -WD / 2, 0.2 + (WIN_LO + WIN_HI) / 2), m=body),
         fbox("Inside", (L - 0.3, 0.06, H - 0.2), (0, WD / 2 - 0.1, 0.2 + H / 2), m=cm("Interior")),
         box("Counter", (WIN_W + 0.3, 0.6, 0.1), (0, -WD / 2 - 0.2, 0.2 + WIN_LO), bevel=0.02, segs=1, m=cm("Hazard", rough=0.5))]
    for s in (-1, 1):
        for k in range(9):
            y = s * (WD / 2 + 0.02)
            x = -L / 2 + 0.35 + k * (L - 0.7) / 8
            if s < 0 and abs(x) < WIN_W / 2 + 0.1:
                continue
            p.append(fbox(f"Rib{s}{k}", (0.12, 0.08, H - 0.2), (x, y, 0.2 + H / 2), m=body))
        p.append(fbox(f"RailT{s}", (L, 0.14, 0.12), (0, s * (WD / 2 - 0.02), 0.2 + H - 0.06), m=dark))
    p += place(hazard("CounterHaz", WIN_W + 0.3, 0.1, stripe=0.25, depth=0.02), (0, -WD / 2 - 0.51, 0.2 + WIN_LO - 0.02))
    # Shelves of stock behind the counter, lit by a strip lamp.
    for k in range(3):
        p.append(fbox(f"Shelf{k}", (WIN_W, 0.4, 0.05), (0, WD / 2 - 0.35, 0.2 + 1.2 + k * 0.45), m=cm("WoodDark")))
        for j in range(6):
            col = ["Red", "Taxi", "Teal", "GreenDark", "Orange", "Blue"][(j + k) % 6]
            p.append(fbox(f"Stock{k}{j}", (0.36, 0.3, 0.3), (-1.4 + j * 0.56, WD / 2 - 0.35, 0.2 + 1.38 + k * 0.45), m=cm(col, rough=0.6)))
    p.append(fbox("Strip", (WIN_W - 0.2, 0.08, 0.06), (0, -WD / 2 + 0.25, 0.2 + WIN_HI - 0.08), m=steady(LAMP_WARM, 3.0)))
    # Roof sign, antenna, floodlights.
    p += [box("SignBox", (4.4, 0.35, 0.8), (0, -WD / 2 + 0.3, 0.2 + H + 0.55), bevel=0.04, segs=1, m=cm("Soot")),
          text("SignTxt", "ASHFALL SUPPLY", 0.42, 0.06, (0, -WD / 2 + 0.08, 0.2 + H + 0.53), m=neon(NEON_CYAN, 3.6)),
          fbox("SignLegL", (0.1, 0.1, 0.4), (-1.8, -WD / 2 + 0.4, 0.2 + H + 0.1), m=dark),
          fbox("SignLegR", (0.1, 0.1, 0.4), (1.8, -WD / 2 + 0.4, 0.2 + H + 0.1), m=dark),
          cyl("Antenna", 0.03, 2.6, (L / 2 - 0.4, WD / 2 - 0.3, 0.2 + H + 1.3), segs=5, bevel=0.0, m=dark),
          lamp("AntennaLamp", 0.07, (L / 2 - 0.4, WD / 2 - 0.3, 0.2 + H + 2.62), NEON_RED, strength=4.0, lit=neon(NEON_RED, 4.0))]
    for s in (-1, 1):
        p += [box(f"Flood{s}", (0.4, 0.28, 0.3), (s * (L / 2 - 0.3), -WD / 2 - 0.1, 0.2 + H + 0.2), rot=(math.radians(30), 0, 0), bevel=0.03, segs=1, m=dark),
              lamp(f"FloodLamp{s}", 0.11, (s * (L / 2 - 0.3), -WD / 2 - 0.26, 0.2 + H + 0.12), LAMP_WARM, strength=4.0)]
    # Sandbag wall at both ends, ammo crates, a drum.
    for s in (-1, 1):
        for row in range(3):
            for k in range(3 - row):
                p.append(box(f"Bag{s}{row}{k}", (0.62, 0.38, 0.24), (s * (L / 2 + 0.45), -0.9 + k * 0.62 + row * 0.31, 0.32 + row * 0.22),
                             rot=(0, 0, math.pi / 2), bevel=0.1, segs=1, m=cm("Canvas", rough=0.95)))
    p += [box("Ammo", (0.7, 0.45, 0.35), (-1.3, -WD / 2 - 0.25, 0.2 + WIN_LO + 0.23), bevel=0.04, segs=1, m=cm("GreenDark")),
          box("AmmoBand", (0.72, 0.47, 0.08), (-1.3, -WD / 2 - 0.25, 0.2 + WIN_LO + 0.27), bevel=0.01, segs=1, m=cm("Hazard")),
          box("Medkit", (0.5, 0.35, 0.3), (1.25, -WD / 2 - 0.22, 0.2 + WIN_LO + 0.2), bevel=0.04, segs=1, m=cm("White", rough=0.5)),
          fbox("MedCross", (0.2, 0.37, 0.06), (1.25, -WD / 2 - 0.22, 0.2 + WIN_LO + 0.36), m=cm("Red")),
          fbox("MedCross2", (0.06, 0.37, 0.2), (1.25, -WD / 2 - 0.22, 0.2 + WIN_LO + 0.36), m=cm("Red")),
          cyl("Drum", 0.3, 0.9, (L / 2 + 0.4, 1.0, 0.65), segs=10, bevel=0.02, m=cm("Red", rough=0.5)),
          box("CrateA", (0.8, 0.8, 0.7), (-L / 2 - 0.5, 1.0, 0.55), rot=(0, 0, 0.2), bevel=0.04, segs=1, m=cm("WoodLight"))]
    p += graffiti("Tag", "OPEN 24/7*", 0.32, (L / 2 + 0.07, 0.0, 1.6), NEON_PINK, rot_z=math.pi / 2)
    p += place(posters("Post", (0, 0, 0), 0.0, seed=11, count=2), (-L / 2 - 0.07, 0.3, 1.3), rot_z=-math.pi / 2)
    return p


def flap():
    """The steel service flap in its closed pose, built round the hinge."""
    m = cm("SteelLight", rough=0.45, metal=0.5)
    p = [fbox("FlapSheet", (WIN_W + 0.2, 0.05, FLAP), (0, 0, -FLAP / 2), m=m)]
    for k in range(5):
        p.append(fbox(f"FlapRib{k}", (WIN_W + 0.2, 0.08, 0.05), (0, -0.02, -0.15 - k * (FLAP - 0.25) / 4), m=cm("Steel", metal=0.5)))
    p += place(hazard("FlapHaz", WIN_W + 0.2, 0.12, stripe=0.25, depth=0.02), (0, -0.04, -FLAP + 0.07))
    ob = merge("Shutter", p, pivot=(0, 0, 0))
    ob.location = HINGE
    ob.rotation_euler = (math.radians(FLAP_CLOSED), 0, 0)
    return ob


def open_dressing():
    p = [box("OpenBack", (1.0, 0.06, 0.36), (0, -WD / 2 - 0.1, 0.2 + WIN_HI + 0.25), bevel=0.02, segs=1, m=cm("Soot")),
         text("OpenTxt", "OPEN", 0.26, 0.03, (0, -WD / 2 - 0.15, 0.2 + WIN_HI + 0.24), m=neon(NEON_LIME, 3.4))]
    a = math.radians(FLAP_OPEN)
    d = FLAP - 0.1
    ey, ez = HINGE[1] - d * math.sin(-a), HINGE[2] - d * math.cos(a)
    for s in (-1, 1):
        p.append(beam(f"Stay{s}", (s * (WIN_W / 2 - 0.1), -WD / 2 - 0.1, 0.2 + WIN_LO + 0.1), (s * (WIN_W / 2 - 0.1), ey, ez), 0.04, m=cm("SteelDark")))
    return merge("OpenDressing", p)


def closed_sign():
    a = math.radians(FLAP_CLOSED)
    d = FLAP * 0.5
    ny, nz = -math.cos(a), -math.sin(a)
    cy = HINGE[1] + d * math.sin(a) + ny * 0.06
    cz = HINGE[2] - d * math.cos(a) + nz * 0.06
    p = [box("ClosedPlank", (1.5, 0.04, 0.4), (0, cy, cz), rot=(a, 0, 0), bevel=0.02, segs=1, m=cm("Cream")),
         text("ClosedTxt", "BACK SOON", 0.2, 0.02, (0, cy + ny * 0.03, cz + nz * 0.03), rot=(a, 0, 0), m=cm("Red"))]
    return merge("ClosedSign", p)


def build_station():
    reset_scene()
    station = merge("Station", container_shop())
    objs = [station, flap(), open_dressing(), closed_sign()]
    csave("city_station", objs, budget=6000)


BUILDERS = {"trap_fire": build_trap_fire, "trap_shock": build_trap_shock, "supply_crate": build_supply_crate, "station": build_station}

if __name__ == "__main__":
    run(BUILDERS)
