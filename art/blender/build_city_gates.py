"""Ashfall City district gates (the Endless map): three styles, each a static
frame and a door that moves away when the district is bought.

    city_gate_shutter_frame / _door     roll-up shop shutter in a broken concrete arch
                                        (open_style "shutter")
    city_gate_fence_frame / _door       stacked shipping containers and a padlocked
                                        chain-link rolling gate in two leaves (open_style "slide")
    city_gate_barricade_frame / _door   wrecked cars, scaffold poles and a STAY OUT sheet;
                                        the plank barricade topples over (open_style "topple")

Frame and door share one origin: the centre of the opening on the ground. The
opening spans X; the gate plane is X-Z at Y = 0 (Godot: the X-Y plane at
z = 0), both faces are dressed. Door models hold their moving parts as child
nodes with the pivot at the node origin (scripts/props/city_gate_door.gd
animates them):
    shutter    Leaf          pivot at the top of the opening; scales to nothing upwards
    fence      LeafL, LeafR  in front of the gate (Blender y = -1.7, Godot z = +1.7);
                             slide 3.1 m outwards along X
    barricade  Leaf          pivot on the ground at its back edge; topples backwards
                             (Godot rotation.x to -90 degrees, falling towards -Z)

    python art/blender/build_city_gates.py [shutter fence barricade]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from city_common import *  # noqa: F401,F403
import build_city_wrecks as wrecks  # noqa: E402

SHUTTER_W, SHUTTER_H = 6.0, 4.2
FENCE_W, FENCE_H, FENCE_Y = 6.6, 3.4, -1.7
BARRICADE_W, BARRICADE_H = 6.4, 2.7


def posters(prefix, loc, rot_z, seed=1, count=3):
    """Torn bills pasted on a wall facing -Y."""
    rng = random.Random(seed)
    cols = ["Cream", "Pink", "Taxi", "Teal", "White"]
    out = []
    for k in range(count):
        w, h = rng.uniform(0.45, 0.7), rng.uniform(0.6, 0.9)
        x, z = rng.uniform(-0.25, 0.25), k * 0.55 + rng.uniform(-0.1, 0.1)
        torn = [(-w / 2, -h / 2), (w / 2, -h / 2 + rng.uniform(0, 0.2)), (w / 2 - rng.uniform(0, 0.15), h / 2), (-w / 2, h / 2 - rng.uniform(0.1, 0.3))]
        out.append(flat_prism(f"{prefix}{k}", torn, 0.01, (x, -0.006 * (k + 1), z), rot=(0, rng.uniform(-0.15, 0.15), 0), m=cm(rng.choice(cols), rough=0.9)))
        out.append(fbox(f"{prefix}{k}Ink", (w * 0.6, 0.012, 0.08), (x, -0.006 * (k + 1) - 0.006, z + h * 0.2), m=cm("Soot")))
    return place(out, loc, rot_z)


def rubble(prefix, loc, seed=1, count=5, spread=1.0, m=None):
    """Broken concrete chunks on the ground."""
    rng = random.Random(seed)
    m = m or cm("ConcreteDark", rough=0.9)
    out = []
    for k in range(count):
        s = rng.uniform(0.18, 0.42)
        out.append(box(f"{prefix}{k}", (s * 1.4, s, s * 0.8), (loc[0] + rng.uniform(-spread, spread), loc[1] + rng.uniform(-spread * 0.6, spread * 0.6), loc[2] + s * 0.3),
                       rot=(rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), rng.uniform(0, 3)), bevel=0.03, segs=1, m=m))
    return out


def cage_lamp(prefix, loc, color=LAMP_EMERGENCY, facing=-1):
    """Caged bulkhead lamp on a wall facing `facing` Y."""
    x, y, z = loc
    p = [box(prefix + "Base", (0.32, 0.08, 0.32), (x, y, z), bevel=0.02, segs=1, m=cm("SteelDark", metal=0.4)),
         lamp(prefix + "Bulb", 0.11, (x, y + facing * 0.13, z), color, strength=4.0)]
    for k in range(3):
        p.append(fbox(f"{prefix}Bar{k}", (0.025, 0.25, 0.025), (x - 0.12 + k * 0.12, y + facing * 0.13, z + 0.13), m=cm("SteelDark", metal=0.4)))
    return p


# ---------------------------------------------------------------------------
# Shutter
# ---------------------------------------------------------------------------

def shutter_frame():
    W, H = SHUTTER_W, SHUTTER_H
    conc, dark, light = cm("ConcreteWarm"), cm("ConcreteDark"), cm("ConcreteLight")
    D = 1.3
    px = W / 2 + 0.6
    p = []
    for s in (-1, 1):
        x = s * px
        p += [box(f"Pier{s}", (1.2, D, 5.5), (x, 0, 2.75), bevel=0.05, segs=1, m=conc),
              box(f"Plinth{s}", (1.4, D + 0.2, 0.45), (x, 0, 0.225), bevel=0.04, segs=1, m=dark),
              fbox(f"Guide{s}", (0.14, 0.24, H), (s * (W / 2 + 0.05), 0, H / 2), m=cm("SteelDark", metal=0.5))]
        for f in (-1, 1):
            p += place(hazard(f"Haz{s}{f}", 1.2, 0.9, stripe=0.3), (x, f * (D / 2 + 0.02), 0.95), rot_z=0 if f < 0 else math.pi)
    # Lintel, broken at its right end, rebar sticking out; cornice on top.
    p.append(box("Lintel", (2 * px - 0.6, D, 1.3), (-0.3, 0, H + 0.65), bevel=0.05, segs=1, m=conc))
    p.append(box("Cornice", (2 * px - 1.2, D + 0.3, 0.25), (-0.6, 0, H + 1.42), bevel=0.04, segs=1, m=light))
    p += rebar("RebarL", (px + 0.4, 0, H + 0.75), (1, 0, 0.6), 0.9, 4, (0, 0.28, 0), seed=3)
    p += rebar("RebarT", (px - 0.2, 0, H + 1.35), (0.3, 0, 1), 0.7, 3, (0, 0.35, 0), seed=7)
    # Shop name ghosted on the lintel: a broken neon tube sign on the front, a painted one at the back.
    p += [box("SignBack", (4.6, 0.1, 0.8), (-0.3, -D / 2 - 0.05, H + 0.7), bevel=0.03, segs=1, m=cm("Soot")),
          text("SignNeon", "LUCKY MART", 0.55, 0.06, (-0.3, -D / 2 - 0.13, H + 0.68), m=neon(NEON_PINK, 3.4)),
          text("SignBackTxt", "LOADING", 0.5, 0.04, (0, D / 2 + 0.03, H + 0.7), rot=(0, 0, math.pi), m=cm("Cream", rough=0.7))]
    for f in (-1, 1):
        p += cage_lamp(f"Lamp{f}", (-px, f * (D / 2 + 0.05), H + 0.2), facing=f)
    # Wear: soot blooms, graffiti, posters, rubble at the base.
    p += graffiti("TagL", "ZED", 0.45, (-px, -D / 2 - 0.02, 2.6), NEON_LIME)
    p += graffiti("TagR", "RUN", 0.42, (px, D / 2 + 0.02, 2.4), "#2ef2ff", rot_z=math.pi)
    p += posters("PostF", (px, -D / 2 - 0.01, 2.1), 0.0, seed=3)
    p += posters("PostB", (-px, D / 2 + 0.01, 2.0), math.pi, seed=8, count=2)
    p += rubble("RubF", (px + 0.6, -1.3, 0), seed=1, count=4)
    p += rubble("RubB", (px + 0.3, 1.2, 0), seed=2, count=3)
    return merge("Frame", p)


def shutter_leaf():
    """Corrugated roll-up shutter hanging from its top edge (pivot at z = H)."""
    W, H = SHUTTER_W, SHUTTER_H
    steel, rib = cm("Steel", rough=0.55, metal=0.4), cm("SteelLight", rough=0.5, metal=0.4)
    p = [fbox("Sheet", (W, 0.05, H), (0, 0, -H / 2), m=steel)]
    n = 18
    for k in range(n):
        z = -H + 0.3 + k * (H - 0.35) / (n - 1)
        p.append(fbox(f"Rib{k:02d}", (W, 0.1, 0.06), (0, 0, z), m=rib))
    p += [box("Bottom", (W, 0.16, 0.22), (0, 0, -H + 0.11), bevel=0.03, segs=1, m=cm("SteelDark", metal=0.5))]
    for f in (-1, 1):
        p += place(hazard(f"Haz{f}", W - 0.1, 0.18, stripe=0.35, depth=0.02), (0, f * 0.085, -H + 0.11), rot_z=0 if f < 0 else math.pi)
    # Padlock and hasp at the foot, front.
    p += [box("Hasp", (0.24, 0.06, 0.32), (0, -0.11, -H + 0.32), bevel=0.01, segs=1, m=cm("SteelDark", metal=0.6)),
          box("Lock", (0.2, 0.1, 0.18), (0, -0.17, -H + 0.2), bevel=0.03, segs=1, m=cm("Gold", rough=0.35, metal=0.7)),
          torus("Shackle", 0.07, 0.018, (0, -0.17, -H + 0.31), rot=(math.pi / 2, 0, 0), m=cm("SteelLight", metal=0.7), major_segs=8, minor_segs=4,
                arc=math.pi)]
    # Paint: a big tag on the front, a warning stencil on the back, rust runs.
    p += graffiti("Tag", "KEEP OUT", 0.62, (0.4, -0.07, -H * 0.55), NEON_PINK)
    p += graffiti("TagB", "NO WAY", 0.55, (-0.6, 0.07, -H * 0.5), "#ffc21f", rot_z=math.pi)
    for k, (x, z) in enumerate(((-2.2, -1.2), (1.9, -2.8), (-1.0, -3.3))):
        p.append(blob(f"Rust{k}", 0.3, (x, -0.06, z), cm("RustDark"), seed=k + 3, squash=(0.3, 1.8)))
    leaf = merge("Leaf", p)
    leaf.location = (0, 0, H)
    return leaf


def build_shutter():
    reset_scene()
    frame = shutter_frame()
    leaf = shutter_leaf()
    csave_split("city_gate_shutter", {"city_gate_shutter_frame": [frame], "city_gate_shutter_door": [leaf]})


# ---------------------------------------------------------------------------
# Fence + containers
# ---------------------------------------------------------------------------

def container(prefix, color, loc, rot_z=0.0, L=3.0, Wd=2.44, H=2.6, doors_at=-1, label=None):
    """A 10 ft shipping container, length along Y, doors on the `doors_at` Y end."""
    body = cm(color, rough=0.7)
    dark = cm("SteelDark", metal=0.4)
    p = [box(prefix + "Body", (Wd, L, H), (0, 0, H / 2), bevel=0.04, segs=1, m=body)]
    for s in (-1, 1):
        for k in range(7):
            y = -L / 2 + 0.3 + k * (L - 0.6) / 6
            p.append(fbox(f"{prefix}Rib{s}{k}", (0.08, 0.14, H - 0.25), (s * (Wd / 2 + 0.02), y, H / 2), m=body))
        p.append(fbox(f"{prefix}Rail{s}", (0.1, L, 0.14), (s * (Wd / 2 - 0.03), 0, H - 0.07), m=dark))
        p.append(fbox(f"{prefix}Sill{s}", (0.1, L, 0.14), (s * (Wd / 2 - 0.03), 0, 0.07), m=dark))
    yd = doors_at * (L / 2 + 0.03)
    p += [fbox(prefix + "DoorL", (Wd / 2 - 0.08, 0.05, H - 0.25), (-Wd / 4, yd, H / 2), m=body),
          fbox(prefix + "DoorR", (Wd / 2 - 0.08, 0.05, H - 0.25), (Wd / 4, yd, H / 2), m=body)]
    for k, x in enumerate((-0.85, -0.35, 0.35, 0.85)):
        p.append(fbox(f"{prefix}Bar{k}", (0.05, 0.08, H - 0.3), (x, yd + doors_at * 0.04, H / 2), m=dark))
    if label:
        p.append(text(prefix + "Label", label, 0.36, 0.03, (0, yd + doors_at * 0.05, H - 0.45), rot=(0, 0, 0 if doors_at < 0 else math.pi), m=cm("White", rough=0.6)))
    return place(p, loc, rot_z)


def barbed(prefix, x0, x1, y, z, m=None):
    """A barbed-wire coil (a stretched helix) along X."""
    m = m or cm("SteelLight", rough=0.4, metal=0.7)
    pts = []
    turns = int(abs(x1 - x0) / 0.5)
    for i in range(turns * 4 + 1):
        a = math.tau * i / 4 + 0.4
        t = i / (turns * 4)
        pts.append((x0 + (x1 - x0) * t, y + math.cos(a) * 0.22, z + math.sin(a) * 0.22))
    return [tube(prefix, pts, 0.012, m=m, segs=3, cap=False)]


def fence_frame():
    W = FENCE_W
    p = []
    cx = W / 2 + 1.22
    p += container("CL0", "Rust", (-cx, 0, 0), label="ASHCO")
    p += container("CL1", "Teal", (-cx + 0.12, 0.1, 2.6), rot_z=math.radians(4), label="ASHCO")
    p += container("CR0", "Blue", (cx, 0, 0), label="RUBY")
    p += container("CR1", "Red", (cx - 0.1, -0.12, 2.6), rot_z=math.radians(-3), doors_at=1)
    # Gantry beam over the top with razor wire and a floodlight, the QUARANTINE board.
    steel, dark = cm("Steel", metal=0.5), cm("SteelDark", metal=0.5)
    p += [beam("Gantry", (-cx, FENCE_Y + 0.3, 5.35), (cx, FENCE_Y + 0.3, 5.35), 0.3, m=dark),
          beam("GantryB", (-cx, 1.2, 5.3), (cx, 1.2, 5.3), 0.22, m=dark),
          box("Board", (3.6, 0.1, 0.9), (0, FENCE_Y + 0.15, 4.7), bevel=0.02, segs=1, m=cm("Hazard", rough=0.6)),
          text("BoardTxt", "QUARANTINE", 0.42, 0.04, (0, FENCE_Y + 0.08, 4.72), m=cm("HazardDark")),
          box("BoardB", (3.0, 0.1, 0.7), (0, 1.25, 4.75), bevel=0.02, segs=1, m=cm("White", rough=0.6)),
          text("BoardBTxt", "ZONE B", 0.4, 0.04, (0, 1.31, 4.76), rot=(0, 0, math.pi), m=cm("Red"))]
    p += barbed("Wire", -cx, cx, FENCE_Y + 0.3, 5.75)
    p += [box("Flood", (0.5, 0.3, 0.35), (2.2, FENCE_Y - 0.05, 5.15), rot=(math.radians(25), 0, 0), bevel=0.03, segs=1, m=dark),
          lamp("FloodLamp", 0.14, (2.2, FENCE_Y - 0.22, 5.06), LAMP_WARM, strength=4.0)]
    # Ground track the leaves roll on, end stops, posts at both ends of the run.
    p.append(fbox("Track", (2 * (W / 2 + 3.2), 0.12, 0.06), (0, FENCE_Y, 0.03), m=dark))
    for s in (-1, 1):
        p += [box(f"Post{s}", (0.2, 0.2, FENCE_H + 0.4), (s * (W / 2 + 0.05), FENCE_Y + 0.2, (FENCE_H + 0.4) / 2), bevel=0.03, segs=1, m=steel),
              box(f"Stop{s}", (0.2, 0.3, 0.3), (s * (W / 2 + 3.2), FENCE_Y, 0.15), bevel=0.03, segs=1, m=cm("Hazard", rough=0.6))]
    p += graffiti("Tag", "ASH", 0.5, (-cx + 1.23, 0.4, 1.4), NEON_PINK, rot_z=-math.pi / 2)
    p += rubble("Rub", (-cx - 0.2, FENCE_Y - 0.8, 0), seed=4, count=3)
    return merge("Frame", p)


def fence_leaf(name, side):
    """One chain-link leaf, 3.35 x 3.4 m, its meeting edge at x = 0 and its body
    towards `side` (-1 left, +1 right); pivot at the meeting edge on the ground."""
    w, h = FENCE_W / 2 + 0.05, FENCE_H
    steel, dark = cm("Steel", rough=0.4, metal=0.6), cm("SteelDark", metal=0.5)
    wire = cm("SteelLight", rough=0.4, metal=0.6)
    xs = lambda u: side * u  # noqa: E731
    p = [beam("Top", (xs(0.05), 0, h), (xs(w), 0, h), 0.08, m=steel),
         beam("Bot", (xs(0.05), 0, 0.25), (xs(w), 0, 0.25), 0.08, m=steel),
         beam("Mid", (xs(0.05), 0, h * 0.55), (xs(w), 0, h * 0.55), 0.05, m=steel),
         beam("Edge", (xs(0.05), 0, 0.2), (xs(0.05), 0, h + 0.05), 0.1, m=steel),
         beam("Far", (xs(w), 0, 0.2), (xs(w), 0, h + 0.05), 0.08, m=steel),
         beam("Brace", (xs(0.1), 0, 0.3), (xs(w - 0.05), 0, h - 0.05), 0.05, m=steel)]
    # Chain-link: two sets of diagonal wires.
    step = 0.42
    for k in range(-9, 17):
        x0 = k * step
        a, b = (x0, 0.28), (x0 + (h - 0.3), h - 0.02)
        for d, (pa, pb) in enumerate(((a, b), ((x0 + (h - 0.3), 0.28), (x0, h - 0.02)))):
            ax, az = pa
            bx, bz = pb
            # Clip the segment to 0.05 .. w.
            lo, hi = 0.07, w - 0.02
            if max(ax, bx) < lo or min(ax, bx) > hi:
                continue
            t0 = 0.0 if lo <= ax <= hi else ((lo if ax < lo else hi) - ax) / (bx - ax)
            t1 = 1.0 if lo <= bx <= hi else ((lo if bx < lo else hi) - ax) / (bx - ax)
            if t1 - t0 < 0.02:
                continue
            p0 = (xs(ax + (bx - ax) * t0), 0, az + (bz - az) * t0)
            p1 = (xs(ax + (bx - ax) * t1), 0, az + (bz - az) * t1)
            p.append(beam(f"W{d}_{k}", p0, p1, 0.018, m=wire))
    p += barbed("Coil", xs(0.1), xs(w), 0, h + 0.28)
    for k, u in enumerate((0.5, w - 0.5)):
        p += [cyl(f"Wheel{k}", 0.13, 0.08, (xs(u), 0, 0.13), rot=(math.pi / 2, 0, 0), segs=8, bevel=0.0, m=dark),
              fbox(f"Fork{k}", (0.1, 0.12, 0.2), (xs(u), 0, 0.2), m=dark)]
    if side < 0:
        # Chain wrapped round both edges and a fat padlock (on the left leaf), the DANGER plate.
        for k in range(5):
            p.append(torus(f"Chain{k}", 0.05, 0.014, (0.0, -0.06, 1.25 + k * 0.08), rot=(math.pi / 2 * (k % 2), 0, math.pi / 2), m=wire, major_segs=6, minor_segs=3))
        p += [box("Lock", (0.18, 0.09, 0.2), (0.0, -0.1, 1.1), bevel=0.03, segs=1, m=cm("Gold", rough=0.35, metal=0.7)),
              box("Plate", (1.0, 0.04, 0.62), (xs(1.6), -0.05, 1.7), bevel=0.02, segs=1, m=cm("White", rough=0.5)),
              box("PlateBand", (1.0, 0.045, 0.2), (xs(1.6), -0.055, 1.92), bevel=0.0, m=cm("Red", rough=0.5)),
              text("PlateTxt", "DANGER", 0.2, 0.02, (xs(1.6), -0.08, 1.62), m=cm("Soot"))]
    else:
        p += [box("Plate", (1.0, 0.04, 0.62), (xs(1.7), 0.05, 1.7), bevel=0.02, segs=1, m=cm("Hazard", rough=0.5)),
              text("PlateTxt", "NO ENTRY", 0.17, 0.02, (xs(1.7), 0.08, 1.7), rot=(0, 0, math.pi), m=cm("Soot"))]
    leaf = merge(name, p)
    leaf.location = (0, FENCE_Y, 0)
    return leaf


def build_fence():
    reset_scene()
    frame = fence_frame()
    left, right = fence_leaf("LeafL", -1), fence_leaf("LeafR", 1)
    csave_split("city_gate_fence", {"city_gate_fence_frame": [frame], "city_gate_fence_door": [left, right]})


# ---------------------------------------------------------------------------
# Barricade
# ---------------------------------------------------------------------------

def tape(prefix, p0, p1, sag=0.15):
    """Police tape: a thin yellow ribbon with black marks, sagging between two points."""
    a, b = Vector(p0), Vector(p1)
    mid = (a + b) / 2 + Vector((0, 0, -sag))
    out = [beam(prefix + "A", a, mid, 0.08, depth=0.01, m=cm("Hazard", rough=0.6)),
           beam(prefix + "B", mid, b, 0.08, depth=0.01, m=cm("Hazard", rough=0.6))]
    for k, t in enumerate((0.25, 0.75)):
        q = (a.lerp(mid, t * 2) if t < 0.5 else mid.lerp(b, (t - 0.5) * 2))
        d = (b - a).normalized()
        out.append(beam(f"{prefix}M{k}", q - d * 0.12, q + d * 0.12, 0.05, depth=0.016, m=cm("Soot")))
    return out


def scaffold_pole(prefix, x, y, h):
    m = cm("SteelLight", rough=0.45, metal=0.6)
    return [cyl(prefix, 0.07, h, (x, y, h / 2), segs=8, bevel=0.0, m=m),
            box(prefix + "Foot", (0.4, 0.4, 0.1), (x, y, 0.05), bevel=0.02, segs=1, m=cm("WoodDark"))]


def barricade_frame():
    W = BARRICADE_W
    p = []
    # Left: a burnt car rolled onto its side, roof facing the opening.
    car = wrecks.car_parts("CL_", paint="Blue", seed=12, lite=True)
    xform(car, (0, 0, 0), (math.pi / 2, 0, 0))
    xform(car, (-W / 2 - 0.95, 0.3, 0.92), (0, 0, math.pi / 2))
    p += car
    # Right: a burnt hatchback nosed into the gap, a stack of tyres.
    car_b = wrecks.car_parts("CR_", L=4.0, W=1.8, paint="Taxi", seed=14, hood_up=True, cabin=(-1.35, 0.55, -1.25, 0.1), lite=True)
    xform(car_b, (W / 2 + 1.0, 0.2, 0), (0, 0, math.radians(100)))
    p += car_b
    for k in range(4):
        p.append(tyre(f"Tyre{k}", 0.42, 0.28, (-W / 2 - 0.9, -1.9, 0.14 + k * 0.27), rot=(0, 0, 0)))
    # Scaffold poles 5 m tall with a cross tube and the hanging STAY OUT sheet.
    h = 5.2
    for s in (-1, 1):
        p += scaffold_pole(f"Pole{s}", s * (W / 2 + 0.1), 0.0, h)
    p += [cyl("Cross", 0.06, W + 0.6, (0, 0, h - 0.25), rot=(0, math.pi / 2, 0), segs=8, bevel=0.0, m=cm("SteelLight", metal=0.6))]
    sheet = [(-2.4, 0.0), (-0.8, 0.12), (0.7, -0.05), (2.4, 0.06), (2.3, -1.3), (1.2, -1.45), (0.0, -1.25), (-1.3, -1.5), (-2.35, -1.3)]
    p.append(flat_prism("Sheet", sheet, 0.04, (0, 0, h - 0.32), m=cm("Cream", rough=0.95)))
    p.append(text("SheetTxt", "STAY OUT", 0.6, 0.02, (0, -0.04, h - 0.95), m=cm("Red")))
    p.append(text("SheetTxtB", "STAY OUT", 0.6, 0.02, (0, 0.04, h - 0.95), rot=(0, 0, math.pi), m=cm("RedDark")))
    for k in range(3):
        p.append(torus(f"Clip{k}", 0.08, 0.02, (-2.0 + k * 2.0, 0, h - 0.28), rot=(0, math.pi / 2, 0), m=cm("SteelDark", metal=0.6), major_segs=6, minor_segs=3))
    # Police tape strung between the poles and the cars.
    p += tape("TapeA", (-W / 2 - 0.1, -0.1, 2.9), (W / 2 + 0.1, -0.1, 3.1), sag=0.3)
    p += tape("TapeB", (-W / 2 - 0.1, 0.1, 3.5), (-W / 2 - 1.8, 0.2, 1.8), sag=0.2)
    p += tape("TapeC", (W / 2 + 0.1, 0.1, 3.4), (W / 2 + 1.6, -1.2, 1.4), sag=0.2)
    # Sandbags at the pole feet, a scorch on the ground.
    for s in (-1, 1):
        for k in range(3):
            p.append(box(f"Bag{s}{k}", (0.6, 0.38, 0.22), (s * (W / 2 + 0.2) + (k % 2) * 0.1 * s, -0.55 + k * 0.4, 0.11 + (k == 1) * 0.2),
                         rot=(0, 0, 0.2 * k), bevel=0.09, segs=1, m=cm("Canvas", rough=0.95)))
    p.append(ground_blob("Scorch", 1.6, (W / 2 + 1.0, -0.4, 0.0), cm("Soot"), seed=3))
    return merge("Frame", p)


def barricade_leaf():
    """Planks, pallets, a corrugated sheet and a ROAD CLOSED board, ~6.4 x 2.7 m;
    pivot on the ground at its back edge (y = +0.25)."""
    W, H = BARRICADE_W, BARRICADE_H
    wood, dark, light = cm("Wood"), cm("WoodDark"), cm("WoodLight")
    rng = random.Random(21)
    p = []
    # Uprights and a plank wall.
    for k, x in enumerate((-2.9, -1.0, 1.0, 2.9)):
        p.append(box(f"Up{k}", (0.18, 0.18, H), (x, 0.08, H / 2), bevel=0.02, segs=1, m=dark))
    for k in range(9):
        z = 0.3 + k * 0.27
        tilt = rng.uniform(-0.04, 0.04)
        m = (wood, light, dark)[k % 3]
        p.append(box(f"Plank{k}", (W - rng.uniform(0.0, 0.8), 0.05, 0.22), (rng.uniform(-0.25, 0.25), -0.04, z), rot=(0, tilt, 0), bevel=0.01, segs=1, m=m))
    for k, (x, a) in enumerate(((-2.0, 0.6), (1.8, -0.55))):
        p.append(box(f"Diag{k}", (2.6, 0.06, 0.24), (x, -0.1, 1.3), rot=(0, a, 0), bevel=0.01, segs=1, m=light))
    # A rusty corrugated sheet patching the middle, a pallet leaning at the base.
    p += place(corrugated("Corr", 1.8, 1.7, pitch=0.3, depth=0.03, m=cm("Rust"), m_rib=cm("RustLight")), (0.2, -0.12, 0.45))
    p += [box("PalletT", (1.2, 0.12, 1.0), (-1.9, -0.25, 0.55), rot=(math.radians(-14), 0, 0), bevel=0.01, segs=1, m=light)]
    for k in range(3):
        p.append(fbox(f"PalletS{k}", (1.2, 0.14, 0.12), (-1.9, -0.33, 0.15 + k * 0.4), m=dark))
    # ROAD CLOSED board on the front, striped orange and white.
    p += [box("Board", (2.2, 0.06, 0.6), (1.7, -0.14, 2.2), rot=(0, 0.06, 0), bevel=0.02, segs=1, m=cm("White", rough=0.6))]
    for k in range(5):
        p.append(flat_prism(f"BoardS{k}", [(-0.12, -0.3), (0.12, -0.3), (0.32, 0.3), (0.08, 0.3)], 0.02, (0.9 + k * 0.42, -0.18, 2.2), m=cm("Orange", rough=0.6)))
    p += [box("Label", (1.4, 0.03, 0.22), (1.7, -0.2, 2.2), bevel=0.0, m=cm("White", rough=0.6)),
          text("LabelTxt", "ROAD CLOSED", 0.15, 0.02, (1.7, -0.22, 2.2), m=cm("Soot"))]
    p += graffiti("Tag", "X", 0.9, (-1.0, -0.12, 1.7), NEON_LIME)
    p += graffiti("TagB", "BACK OFF", 0.4, (0.0, 0.14, 1.5), NEON_PINK, rot_z=math.pi)
    leaf = merge("Leaf", p)
    leaf.data.transform(Matrix.Translation(Vector((0, -0.25, 0))))
    leaf.location = (0, 0.25, 0)
    return leaf


def build_barricade():
    reset_scene()
    frame = barricade_frame()
    leaf = barricade_leaf()
    fire = socket("Fire", (BARRICADE_W / 2 + 1.0, 0.2, 0.9))
    csave_split("city_gate_barricade", {"city_gate_barricade_frame": [frame, fire], "city_gate_barricade_door": [leaf]})


BUILDERS = {"shutter": build_shutter, "fence": build_fence, "barricade": build_barricade}

if __name__ == "__main__":
    run(BUILDERS)
