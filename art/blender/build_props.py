"""Pier props for Prize Pier: rail and lamp modules, planters, palms, benches,
booths, the arcade stall, entrance gates and background dressing.

Each function builds one prop in a fresh scene and saves .blend + .glb.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403


def build_rail():
    """3 m rail module running along X. One post per module, so runs tile."""
    reset_scene()
    teal, dark, pink, rope = mat("Teal"), mat("TealDark"), mat("Pink"), mat("Rope", "Cream", rough=0.9)
    parts = [
        box("Post", (0.24, 0.24, 1.22), (0, 0, 0.61), bevel=0.04, m=teal),
        box("PostBase", (0.36, 0.36, 0.14), (0, 0, 0.07), bevel=0.03, m=dark),
        box("PostCap", (0.34, 0.34, 0.1), (0, 0, 1.25), bevel=0.04, m=dark),
        sphere("PostBall", 0.11, (0, 0, 1.38), m=pink),
        box("TopRail", (3.0, 0.16, 0.12), (0, 0, 1.08), bevel=0.04, m=teal),
        box("MidRail", (3.0, 0.1, 0.09), (0, 0, 0.62), bevel=0.03, m=teal),
        box("LowRail", (3.0, 0.1, 0.09), (0, 0, 0.22), bevel=0.03, m=teal),
    ]
    # Rope swags draped between posts.
    for i, (x0, x1) in enumerate(((-1.5, 0.0), (0.0, 1.5))):
        pts = []
        for s in range(9):
            t = s / 8.0
            pts.append((x0 + (x1 - x0) * t, -0.13, 0.98 - 0.2 * math.sin(math.pi * t)))
        parts.append(tube(f"Rope{i}", pts, 0.028, m=rope, segs=6))
    save("rail", [merge("Rail", parts)])


def build_lamp_post():
    """Boardwalk lamp: teal pole, curved arm reaching +X, amber lantern, star banner."""
    reset_scene()
    teal, dark, pink = mat("Teal"), mat("TealDark"), mat("Pink")
    amber = glow("BulbAmber", "#ffc24a", 3.0)
    yellow = mat("Yellow")
    parts = [
        cyl("Base", 0.26, 0.5, (0, 0, 0.25), segs=12, bevel=0.05, m=dark, radius_top=0.2),
        cyl("Collar", 0.2, 0.12, (0, 0, 0.56), segs=12, m=teal),
        cyl("Pole", 0.105, 4.6, (0, 0, 2.8), segs=10, bevel=0.0, m=teal),
        sphere("PoleTop", 0.14, (0, 0, 5.12), m=dark),
    ]
    arm = [(0, 0, 4.7)] + arc_points(0.62, 180, 20, 10, centre=(0.62, 0, 4.7))
    parts.append(tube("Arm", arm, 0.07, m=teal, segs=8))
    lx, lz = 0.62 + math.cos(math.radians(20)) * 0.62, 4.7 + math.sin(math.radians(20)) * 0.62
    parts += [
        cyl("Shade", 0.42, 0.26, (lx, 0, lz - 0.12), segs=14, bevel=0.03, m=teal, radius_top=0.12),
        cyl("ShadeRim", 0.44, 0.06, (lx, 0, lz - 0.26), segs=14, bevel=0.02, m=dark),
        sphere("Lantern", 0.27, (lx, 0, lz - 0.42), scale=(1, 1, 0.9), m=amber, segs=12, rings=8),
        bulb("LanternGlow", 0.24, (lx, 0, lz - 0.42), amber),
        # Banner bracket and banner (hangs in the XZ plane, below the arm).
        box("BannerBar", (0.74, 0.05, 0.05), (0.42, 0, 4.18), bevel=0.01, m=dark),
        box("Banner", (0.62, 0.035, 1.25), (0.44, 0, 3.52), bevel=0.012, m=pink),
        prism("BannerTail", [(-0.31, 0.0), (0.31, 0.0), (0.31, -0.3), (0.0, -0.12), (-0.31, -0.3)], 0.035,
              (0.44, 0, 2.9), m=pink),
        star("BannerStarF", 0.22, 0.03, (0.44, -0.03, 3.55), m=yellow),
        star("BannerStarB", 0.22, 0.03, (0.44, 0.03, 3.55), m=yellow),
    ]
    save("lamp_post", [merge("LampPost", parts)])


def _flower(prefix, loc, petal_m, centre_m, r=0.11):
    parts = []
    for i in range(5):
        a = math.tau * i / 5
        parts.append(sphere(f"{prefix}P{i}", r, (loc[0] + math.cos(a) * r * 0.95, loc[1] + math.sin(a) * r * 0.95, loc[2]),
                            scale=(1, 1, 0.45), m=petal_m, segs=8, rings=5))
    parts.append(sphere(f"{prefix}C", r * 0.55, (loc[0], loc[1], loc[2] + r * 0.25), m=centre_m, segs=8, rings=5))
    return parts


def build_planter():
    """Pink-and-teal planter box (3.2 x 1.5 m) with leafy shrubs and hibiscus."""
    reset_scene()
    pink, teal, dark = mat("Pink"), mat("Teal"), mat("PinkDark")
    soil = mat("Soil", "#3a2622", rough=0.95)
    leaf, leaf2 = mat("Green", rough=0.7), mat("GreenLight", rough=0.7)
    petal, centre = mat("PinkLight"), mat("Yellow")
    parts = [
        box("Body", (3.2, 1.5, 0.62), (0, 0, 0.33), bevel=0.07, segs=3, m=teal),
        box("Rim", (3.36, 1.66, 0.2), (0, 0, 0.72), bevel=0.07, segs=3, m=pink),
        box("Foot", (3.3, 1.6, 0.12), (0, 0, 0.06), bevel=0.04, m=dark),
        box("Soil", (3.0, 1.3, 0.08), (0, 0, 0.8), bevel=0.0, m=soil),
    ]
    import random
    rng = random.Random(7)
    for i in range(11):
        x, y = rng.uniform(-1.3, 1.3), rng.uniform(-0.45, 0.45)
        r = rng.uniform(0.28, 0.42)
        parts.append(sphere(f"Bush{i}", r, (x, y, 0.9 + r * 0.45), scale=(1.15, 1.0, 0.75),
                            m=leaf if i % 2 else leaf2, segs=10, rings=6))
    for i in range(7):
        x, y = rng.uniform(-1.35, 1.35), rng.uniform(-0.55, 0.55)
        parts += _flower(f"Flower{i}", (x, y, 1.28 + rng.uniform(0, 0.14)), petal, centre)
    save("planter", [merge("Planter", parts)])


def build_palm():
    """Palm tree, about 7 m tall, with a gentle lean."""
    reset_scene()
    trunk_m, ring_m = mat("PalmTrunk", "#8c5a3a", rough=0.85), mat("PalmRing", "#6e4129", rough=0.9)
    leaf, leaf2 = mat("PalmLeaf", "#2f9a4a", rough=0.65), mat("PalmLeafLight", "#63c24a", rough=0.65)
    nut = mat("Coconut", "#5a3620", rough=0.8)
    height, lean = 6.4, 0.9
    spine = [(lean * (t ** 1.8), 0, height * t) for t in [i / 10 for i in range(11)]]
    parts = [tube("Trunk", spine, 0.3, m=trunk_m, segs=10, radius_end=0.17)]
    for i in range(1, 10):
        x, _, z = spine[i]
        parts.append(torus(f"Ring{i}", 0.3 - 0.013 * i, 0.035, (x, 0, z), m=ring_m, major_segs=10, minor_segs=5))
    top = Vector(spine[-1])
    for i in range(3):
        a = math.tau * i / 3
        parts.append(sphere(f"Nut{i}", 0.17, (top.x + math.cos(a) * 0.2, math.sin(a) * 0.2, top.z - 0.12), m=nut, segs=8, rings=6))
    # Fronds: arched, tapering blades radiating from the crown.
    fronds = 9
    for i in range(fronds):
        a = math.tau * i / fronds + 0.2
        length = 3.0 + 0.4 * math.sin(i * 2.3)
        droop = 1.5 + 0.35 * math.cos(i * 1.7)
        bm_pts = []
        for s in range(9):
            t = s / 8.0
            out = length * t
            z = 0.55 * math.sin(t * math.pi * 0.55) - droop * t * t
            bm_pts.append((top.x + math.cos(a) * out, math.sin(a) * out, top.z + z))
        blade = tube(f"Frond{i}", bm_pts, 0.5, m=leaf if i % 2 else leaf2, segs=6, radius_end=0.04)
        # Flatten the tube into a blade.
        blade.scale = (1, 1, 1)
        for v in blade.data.vertices:
            idx = min(8, v.index // 6)
            c = Vector(bm_pts[idx])
            d = Vector(v.co) - c
            radial = Vector((math.cos(a), math.sin(a), 0))
            side = Vector((-math.sin(a), math.cos(a), 0))
            v.co = c + side * d.dot(side) + radial * d.dot(radial) * 0.3 + Vector((0, 0, d.z * 0.16 - abs(d.dot(side)) * 0.35))
        parts.append(blade)
    save("palm", [merge("Palm", parts)])


def build_bench():
    """Pink slatted bench, 2.2 m wide, facing -Y."""
    reset_scene()
    pink, dark = mat("Pink"), mat("PurpleDark")
    parts = []
    for i in range(4):
        parts.append(box(f"Seat{i}", (2.2, 0.13, 0.06), (0, -0.25 + i * 0.16, 0.48), bevel=0.02, m=pink))
    for i in range(3):
        parts.append(box(f"Back{i}", (2.2, 0.06, 0.15), (0, 0.33, 0.66 + i * 0.19), rot=rad(-8, 0, 0), bevel=0.02, m=pink))
    for x in (-0.95, 0.95):
        parts += [
            box(f"Leg{x}", (0.1, 0.62, 0.1), (x, 0, 0.42), bevel=0.02, m=dark),
            box(f"LegF{x}", (0.1, 0.1, 0.44), (x, -0.26, 0.22), bevel=0.02, m=dark),
            box(f"LegB{x}", (0.1, 0.1, 1.1), (x, 0.3, 0.55), rot=rad(-8, 0, 0), bevel=0.02, m=dark),
            box(f"Arm{x}", (0.12, 0.6, 0.07), (x, -0.02, 0.72), bevel=0.02, m=dark),
        ]
    save("bench", [merge("Bench", parts)])


def _awning(prefix, width, depth, z_back, z_front, y_back, y_front, stripes, m_a, m_b, thickness=0.1):
    """Striped awning sloping from the back edge down to the front edge."""
    parts = []
    w = width / stripes
    length = math.hypot(y_front - y_back, z_front - z_back)
    angle = math.atan2(z_front - z_back, y_front - y_back)
    for i in range(stripes):
        x = -width / 2 + w * (i + 0.5)
        parts.append(box(f"{prefix}{i:02d}", (w + 0.005, length, thickness),
                         (x, (y_back + y_front) / 2, (z_back + z_front) / 2), rot=(angle, 0, 0),
                         bevel=0.025, m=m_a if i % 2 == 0 else m_b))
        # Scalloped valance on the front edge.
        parts.append(cyl(f"{prefix}Scallop{i:02d}", w / 2, 0.06, (x, y_front - 0.01, z_front - 0.06), rot=rad(90, 0, 0),
                         segs=12, bevel=0.01, m=m_a if i % 2 == 0 else m_b))
    return parts


def build_booth():
    """Midway game booth, 4.6 m wide, striped awning, prizes on the back wall. Front faces -Y."""
    reset_scene()
    teal, pink, cream, dark = mat("Teal"), mat("Pink"), mat("Cream"), mat("PurpleDark")
    amber = glow("BulbAmber", "#ffc24a", 3.0)
    yellow, wood = mat("Yellow"), mat("Wood")
    w, d = 4.6, 3.2
    parts = [
        box("Floor", (w, d, 0.12), (0, 0, 0.06), bevel=0.03, m=wood),
        box("Counter", (w, 0.5, 1.0), (0, -d / 2 + 0.25, 0.6), bevel=0.06, m=teal),
        box("CounterTop", (w + 0.16, 0.66, 0.1), (0, -d / 2 + 0.25, 1.14), bevel=0.04, m=pink),
        box("CounterStripe", (w + 0.02, 0.52, 0.16), (0, -d / 2 + 0.25, 0.45), bevel=0.02, m=cream),
        box("BackWall", (w - 0.3, 0.12, 3.0), (0, d / 2 - 0.16, 1.6), bevel=0.04, m=dark),
        # Outside of the back wall: teal with a pink band, like the sides.
        box("BackSkin", (w, 0.1, 3.0), (0, d / 2 - 0.05, 1.6), bevel=0.04, m=teal),
        box("BackBand", (w + 0.02, 0.12, 0.2), (0, d / 2 - 0.05, 2.75), bevel=0.03, m=pink),
        box("SideL", (0.2, d, 3.0), (-w / 2 + 0.1, 0, 1.6), bevel=0.04, m=teal),
        box("SideR", (0.2, d, 3.0), (w / 2 - 0.1, 0, 1.6), bevel=0.04, m=teal),
        # A roof over the whole stall, tucked under the header and the awning.
        box("Roof", (w + 0.2, d + 0.1, 0.16), (0, 0.05, 3.18), bevel=0.05, m=pink),
        box("Ceiling", (w - 0.4, d - 0.4, 0.04), (0, 0, 3.09), bevel=0.0, m=cream),
        box("Header", (w + 0.3, 0.3, 0.7), (0, -d / 2 - 0.15, 3.55), bevel=0.08, m=pink),
        star("HeaderStar", 0.34, 0.1, (0, -d / 2 - 0.34, 3.56), m=yellow),
    ]
    for x in (-w / 2 + 0.12, w / 2 - 0.12):
        parts.append(box(f"Post{x}", (0.22, 0.22, 3.1), (x, -d / 2 + 0.11, 1.65), bevel=0.04, m=pink))
    parts += _awning("Awning", w + 0.5, 1.5, 3.3, 2.75, -d / 2 + 0.1, -d / 2 - 1.25, 9, pink, cream)
    parts += bulb_row("HeaderBulb", (-w / 2, -d / 2 - 0.34, 3.86), (w / 2, -d / 2 - 0.34, 3.86), 12, 0.075, amber)
    parts += bulb_row("HeaderBulbLow", (-w / 2, -d / 2 - 0.34, 3.25), (w / 2, -d / 2 - 0.34, 3.25), 12, 0.075, amber)
    # Prizes: rows of colourful balls and stars on shelves.
    prize_colors = [mat("PinkLight"), mat("Yellow"), mat("BlueLight"), mat("PurpleLight"), mat("Orange")]
    for row in range(2):
        z = 1.75 + row * 0.75
        parts.append(box(f"Shelf{row}", (w - 0.5, 0.4, 0.07), (0, d / 2 - 0.4, z - 0.2), bevel=0.02, m=cream))
        for i in range(8):
            x = -w / 2 + 0.6 + i * ((w - 1.2) / 7)
            m = prize_colors[(i + row) % len(prize_colors)]
            if (i + row) % 3 == 0:
                parts.append(star(f"Prize{row}{i}", 0.2, 0.12, (x, d / 2 - 0.42, z + 0.02), m=m))
            else:
                parts.append(sphere(f"Prize{row}{i}", 0.19, (x, d / 2 - 0.42, z), m=m, segs=10, rings=7))
    save("booth", [merge("Booth", parts)])


def _gate(name, label):
    """Entrance arch: two teal posts 7.2 m apart carrying a lit pink sign beam."""
    reset_scene()
    teal, dark, pink, cream = mat("Teal"), mat("TealDark"), mat("Pink"), mat("Cream")
    amber = glow("BulbAmber", "#ffc24a", 3.0)
    yellow, hot = mat("Yellow"), mat("PinkDark")
    parts = []
    for x in (-3.6, 3.6):
        parts += [
            box(f"Post{x}", (0.9, 0.9, 4.4), (x, 0, 2.2), bevel=0.1, segs=3, m=teal),
            box(f"PostBase{x}", (1.15, 1.15, 0.5), (x, 0, 0.25), bevel=0.08, m=dark),
            box(f"PostBand{x}", (0.98, 0.98, 0.3), (x, 0, 3.1), bevel=0.05, m=pink),
            box(f"PostCap{x}", (1.1, 1.1, 0.3), (x, 0, 4.5), bevel=0.08, m=pink),
            sphere(f"PostBall{x}", 0.34, (x, 0, 4.95), m=amber, segs=12, rings=8),
        ]
    parts += [
        box("Beam", (8.6, 0.6, 1.25), (0, 0, 5.0), bevel=0.18, segs=3, m=pink),
        box("BeamFace", (7.4, 0.66, 0.9), (0, 0, 5.0), bevel=0.1, m=hot),
        box("BeamTop", (8.8, 0.72, 0.16), (0, 0, 5.7), bevel=0.06, m=cream),
        star("CrestF", 0.62, 0.2, (0, -0.2, 6.25), m=yellow),
        cyl("CrestDisc", 0.82, 0.3, (0, 0, 6.25), rot=rad(90, 0, 0), segs=20, bevel=0.06, m=pink),
        star("CrestB", 0.62, 0.2, (0, 0.2, 6.25), m=yellow),
    ]
    parts.append(text("LabelF", label, 0.62, 0.1, (0, -0.36, 4.98), m=cream))
    parts.append(text("LabelB", label, 0.62, 0.1, (0, 0.36, 4.98), rot=(0, 0, math.pi), m=cream))
    for y in (-0.36, 0.36):
        parts += bulb_row(f"BulbTop{y}", (-4.0, y, 5.52), (4.0, y, 5.52), 17, 0.085, amber)
        parts += bulb_row(f"BulbLow{y}", (-4.0, y, 4.48), (4.0, y, 4.48), 17, 0.085, amber)
    save(name, [merge("Gate", parts)])


def build_gate_entrance():
    _gate("gate_entrance", "PRIZE PIER")


def build_gate_ride():
    _gate("gate_ride", "FERRIS WHEEL")


def build_gatehouse():
    """Ticket building that closes the pier entrance: 12 m wide, two ticket
    windows either side of a covered gateway with turnstiles, shut by a
    lattice gate on the pier side (-Y). The beach side (+Y) is open, signed
    and has steps down to the sand."""
    reset_scene()
    teal, pink, cream, dark = mat("Teal"), mat("Pink"), mat("Cream"), mat("Dark")
    amber = glow("BulbAmber", "#ffc24a", 3.0)
    warm = glow("TicketWarm", "#ffd68a", 1.1)
    hot, yellow, wood = mat("PinkDark"), mat("Yellow"), mat("Wood")
    metal = mat("GateMetal", "GreyLight", rough=0.35, metal=0.6)
    gw = 5.0          # gateway width
    parts = [
        box("Lintel", (gw + 0.2, 3.0, 1.6), (0, 1.5, 4.4), bevel=0.15, segs=3, m=teal),
        box("PassageFloor", (gw, 3.2, 0.06), (0, 1.5, 0.03), bevel=0.0, m=wood),
        box("PassageLight", (gw - 1.4, 1.6, 0.05), (0, 1.5, 3.58), bevel=0.0, m=warm),
        box("DoorFrame", (5.6, 0.3, 0.4), (0, -0.1, 3.75), bevel=0.08, m=pink),
        box("Roof", (12.6, 3.6, 0.5), (0, 1.5, 5.4), bevel=0.15, m=pink),
        box("Sign", (7.0, 0.4, 1.3), (0, -0.1, 6.3), bevel=0.2, segs=3, m=hot),
        text("SignText", "TICKETS", 0.8, 0.12, (0, -0.36, 6.28), m=cream),
        text("SignTextBack", "PRIZE PIER", 0.7, 0.12, (0, 0.16, 6.28), rot=(0, 0, math.pi), m=cream),
        text("GateNote", "CLOSED", 0.22, 0.04, (0, -0.05, 1.8), m=cream),
        box("GateNotePlate", (1.3, 0.06, 0.42), (0, 0.0, 1.8), bevel=0.03, m=hot),
    ]
    for x in (-1, 1):
        cx = x * (gw / 2 + 1.75)
        parts += [
            box(f"Wing{x}", (3.5, 3.0, 5.2), (cx, 1.5, 2.6), bevel=0.15, segs=3, m=teal),
            box(f"Plinth{x}", (3.65, 3.2, 0.5), (x * (gw / 2 + 1.825), 1.5, 0.25), bevel=0.08, m=hot),
            box(f"DoorPost{x}", (0.4, 0.34, 3.6), (x * 2.8, -0.1, 1.8), bevel=0.08, m=pink),
            box(f"BackPost{x}", (0.4, 0.34, 3.6), (x * 2.8, 3.1, 1.8), bevel=0.08, m=pink),
        ]
        # A lit ticket window with a half-drawn blind, a mullion and a sill.
        wx = x * 4.4
        parts += [
            box(f"Window{x}", (1.7, 0.1, 1.4), (wx, -0.03, 2.5), bevel=0.03, m=warm),
            box(f"WindowFrame{x}", (1.95, 0.14, 0.14), (wx, -0.05, 3.25), bevel=0.03, m=cream),
            box(f"Blind{x}", (1.7, 0.08, 0.45), (wx, -0.09, 2.98), bevel=0.02, m=cream),
            box(f"Mullion{x}", (0.08, 0.1, 1.4), (wx, -0.08, 2.5), bevel=0.0, m=dark),
            box(f"WindowSill{x}", (2.1, 0.4, 0.16), (wx, -0.1, 1.68), bevel=0.05, m=cream),
        ]
        parts += _awning(f"WinAwning{x}", 2.3, 0.9, 3.75, 3.35, -0.02, -0.85, 5, pink, cream, 0.07)
        for p in parts[-10:]:
            p.location.x += wx
    # Steps down from the gateway to the sand on the beach side.
    parts += [
        box("StepUpper", (gw, 0.5, 0.45), (0, 3.8, -0.425), bevel=0.04, m=wood),
        box("StepLower", (gw, 0.5, 0.25), (0, 4.3, -0.525), bevel=0.04, m=wood),
    ]
    # Turnstiles across the gateway.
    for i, tx in enumerate((-1.6, 0.0, 1.6)):
        parts += [
            cyl(f"Turnstile{i}", 0.14, 1.0, (tx, 1.6, 0.5), segs=12, bevel=0.03, m=metal),
            sphere(f"TurnstileHub{i}", 0.16, (tx, 1.6, 1.0), m=pink, segs=10, rings=6),
        ]
        for k in range(3):
            a = math.tau * k / 3 + 0.4
            parts.append(box(f"TurnstileArm{i}{k}", (0.55, 0.06, 0.06), (tx + math.cos(a) * 0.3, 1.6 + math.sin(a) * 0.3, 0.92),
                             rot=(0, 0, a), bevel=0.0, m=metal))
    # The lattice gate, shut, on the pier side.
    parts += [
        box("GateTop", (gw, 0.1, 0.12), (0, 0.06, 3.5), bevel=0.02, m=metal),
        box("GateMid", (gw, 0.1, 0.1), (0, 0.06, 1.8), bevel=0.02, m=metal),
        box("GateLow", (gw, 0.1, 0.12), (0, 0.06, 0.14), bevel=0.02, m=metal),
    ]
    for i in range(17):
        parts.append(box(f"GateBar{i:02d}", (0.05, 0.05, 3.4), (-gw / 2 + 0.2 + i * (gw - 0.4) / 16, 0.06, 1.8), bevel=0.0, m=metal))
    parts += bulb_row("SignBulbT", (-3.3, -0.36, 6.85), (3.3, -0.36, 6.85), 14, 0.09, amber)
    parts += bulb_row("SignBulbB", (-3.3, -0.36, 5.72), (3.3, -0.36, 5.72), 14, 0.09, amber)
    parts.append(star("SignStarL", 0.4, 0.14, (-2.9, -0.36, 6.28), m=yellow))
    parts.append(star("SignStarR", 0.4, 0.14, (2.9, -0.36, 6.28), m=yellow))
    save("gatehouse", [merge("Gatehouse", parts)])


def build_service_door():
    """Roll-up service door at the bottom of the ramp, 6.4 m wide, facing -Y,
    in the front of the maintenance shed it belongs to (7.4 x 5 m, behind +Y)."""
    reset_scene()
    teal, dark, yellow, grey = mat("TealDark"), mat("Dark"), mat("Yellow"), mat("Grey", rough=0.5, metal=0.3)
    body, roof, cream, hot = mat("Teal"), mat("PinkDark"), mat("Cream"), mat("Pink")
    lamp = glow("ShedLamp", "#ffd68a", 2.5)
    parts = [
        box("Frame", (6.6, 0.5, 3.9), (0, 0.25, 1.95), bevel=0.08, m=teal),
        box("Opening", (5.2, 0.3, 3.0), (0, -0.02, 1.5), bevel=0.03, m=dark),
        box("Roller", (5.5, 0.5, 0.5), (0, -0.05, 3.2), bevel=0.12, m=grey),
        box("ShedBody", (7.4, 5.0, 4.4), (0, 3.0, 2.2), bevel=0.1, segs=3, m=body),
        box("ShedBase", (7.6, 5.2, 0.4), (0, 3.0, 0.2), bevel=0.05, m=teal),
        box("ShedRoof", (8.0, 5.7, 0.35), (0, 2.95, 4.55), bevel=0.1, m=roof),
        box("ShedSign", (3.8, 0.2, 0.62), (0, 0.42, 5.05), bevel=0.08, m=hot),
        text("ShedSignText", "STAFF ONLY", 0.36, 0.06, (0, 0.3, 5.03), m=cream),
        box("LampHood", (0.6, 0.34, 0.16), (0, 0.32, 4.2), bevel=0.04, m=dark),
        box("LampGlow", (0.46, 0.2, 0.06), (0, 0.3, 4.1), bevel=0.0, m=lamp),
    ]
    for x in (-1, 1):
        parts += [
            box(f"SideWindow{x}", (0.1, 1.4, 0.9), (x * 3.71, 3.0, 2.6), bevel=0.02, m=mat("ShopGlass", "#3b2f63", rough=0.15, metal=0.2)),
            box(f"SideSill{x}", (0.2, 1.6, 0.1), (x * 3.74, 3.0, 2.1), bevel=0.02, m=cream),
        ]
    for i in range(9):
        parts.append(box(f"Hazard{i}", (0.34, 0.06, 0.34), (-2.9 + i * 0.725, -0.03, 3.62), rot=rad(0, 45, 0), bevel=0.0,
                         m=yellow if i % 2 == 0 else dark))
    for i in range(3):
        parts.append(box(f"Slat{i}", (5.2, 0.08, 0.16), (0, -0.14, 2.9 - i * 0.24), bevel=0.03, m=grey))
    save("service_door", [merge("ServiceDoor", parts)])


def build_arcade():
    """Open-front arcade stall, 14 m wide x 8 m deep. Zombies emerge from the dim interior. Front faces -Y."""
    reset_scene()
    teal, pink, cream, dark = mat("Teal"), mat("Pink"), mat("Cream"), mat("PurpleDark")
    inner = mat("ArcadeInner", "#2a1552", rough=0.9)
    amber = glow("BulbAmber", "#ffc24a", 3.0)
    hot, yellow = mat("PinkDark"), mat("Yellow")
    w, d, h = 14.0, 8.0, 5.2
    parts = [
        box("Back", (w - 0.6, 0.3, h), (0, d / 2 - 0.25, h / 2), bevel=0.06, m=inner),
        # Outside of the back wall (seen from the beach and the wheel): teal, banded, signed.
        box("BackSkin", (w, 0.12, h), (0, d / 2 - 0.06, h / 2), bevel=0.06, m=teal),
        box("BackBand", (w + 0.04, 0.16, 0.3), (0, d / 2 - 0.06, h - 1.0), bevel=0.04, m=pink),
        box("BackBase", (w + 0.04, 0.16, 0.5), (0, d / 2 - 0.06, 0.25), bevel=0.04, m=hot),
        text("BackSign", "ARCADE", 0.9, 0.1, (0, d / 2 + 0.02, h - 2.0), rot=(0, 0, math.pi), m=cream),
        box("SideL", (0.4, d, h), (-w / 2 + 0.2, 0, h / 2), bevel=0.06, m=teal),
        box("SideR", (0.4, d, h), (w / 2 - 0.2, 0, h / 2), bevel=0.06, m=teal),
        box("Roof", (w + 0.6, d + 0.6, 0.45), (0, 0, h + 0.2), bevel=0.12, m=pink),
        box("Ceiling", (w - 0.8, d - 0.6, 0.1), (0, 0, h - 0.08), bevel=0.0, m=inner),
        box("Header", (w + 0.4, 0.6, 1.5), (0, -d / 2 - 0.1, h - 0.45), bevel=0.2, segs=3, m=hot),
        box("HeaderTrim", (w + 0.6, 0.7, 0.2), (0, -d / 2 - 0.1, h - 1.25), bevel=0.06, m=cream),
        text("Sign", "ARCADE", 1.0, 0.16, (0, -d / 2 - 0.44, h - 0.42), m=cream),
        star("SignStarL", 0.5, 0.16, (-3.6, -d / 2 - 0.44, h - 0.4), m=yellow),
        star("SignStarR", 0.5, 0.16, (3.6, -d / 2 - 0.44, h - 0.4), m=yellow),
    ]
    for x in (-w / 2 + 0.5, w / 2 - 0.5):
        parts.append(box(f"Column{x}", (0.9, 0.9, h - 1.2), (x, -d / 2 + 0.45, (h - 1.2) / 2), bevel=0.1, segs=3, m=pink))
        parts.append(box(f"ColumnBase{x}", (1.1, 1.1, 0.5), (x, -d / 2 + 0.45, 0.25), bevel=0.08, m=hot))
    parts += bulb_row("SignBulbT", (-w / 2, -d / 2 - 0.44, h + 0.2), (w / 2, -d / 2 - 0.44, h + 0.2), 26, 0.1, amber)
    parts += bulb_row("SignBulbB", (-w / 2, -d / 2 - 0.44, h - 1.1), (w / 2, -d / 2 - 0.44, h - 1.1), 26, 0.1, amber)
    # Cabinets along the back wall with glowing screens.
    screens = [glow("ScreenCyan", "#33f0ff", 2.2), glow("ScreenPink", "#ff5cc0", 2.2), glow("ScreenAmber", "#ffc45a", 2.2)]
    bodies = [mat("Purple"), mat("Blue"), mat("Magenta")]
    for i in range(6):
        x = -w / 2 + 1.6 + i * ((w - 3.2) / 5)
        y = d / 2 - 1.0
        parts += [
            box(f"Cab{i}", (1.1, 1.0, 2.3), (x, y, 1.15), bevel=0.08, m=bodies[i % 3]),
            box(f"CabHood{i}", (1.16, 0.6, 0.5), (x, y - 0.3, 2.35), bevel=0.08, m=bodies[(i + 1) % 3]),
            box(f"CabScreen{i}", (0.84, 0.06, 0.66), (x, y - 0.5, 1.62), rot=rad(-12, 0, 0), bevel=0.03, m=screens[i % 3]),
            box(f"CabPanel{i}", (1.0, 0.45, 0.1), (x, y - 0.6, 1.1), rot=rad(-20, 0, 0), bevel=0.03, m=cream),
            sphere(f"CabStick{i}", 0.07, (x - 0.2, y - 0.62, 1.22), m=mat("Red")),
        ]
    # Along each side wall: claw machines between two more cabinets, facing in.
    glass = mat("ClawGlass", "#bfefff", rough=0.08, emit=0.35)
    neon = [glow("NeonPink", "#ff5cc0", 2.4), glow("NeonCyan", "#33f0ff", 2.4)]
    for side, rot_z in ((-1, math.pi / 2), (1, -math.pi / 2)):
        x = side * (w / 2 - 0.4 - 0.6)
        for k, y in enumerate((-2.2, -0.9, 0.4, 1.7)):
            unit = _claw_machine(f"Side{side}{k}", bodies[k % 3], glass, screens[k % 3]) if k in (1, 2) \
                else _cabinet(f"Side{side}{k}", bodies[(k + 1) % 3], bodies[k % 3], screens[(k + 2) % 3], cream)
            parts += place(unit, (x, y, 0), rot_z=rot_z)
        parts.append(box(f"NeonStrip{side}", (0.08, d - 1.6, 0.1), (side * (w / 2 - 0.44), -0.2, h - 1.0), bevel=0.02, m=neon[side > 0]))
    save("arcade", [merge("Arcade", parts)])


def _cabinet(prefix, body, hood, screen, panel):
    """Upright arcade cabinet at the origin, facing -Y (1.1 x 1.0 m)."""
    return [
        box(f"{prefix}Cab", (1.1, 1.0, 2.3), (0, 0, 1.15), bevel=0.08, m=body),
        box(f"{prefix}Hood", (1.16, 0.6, 0.5), (0, -0.3, 2.35), bevel=0.08, m=hood),
        box(f"{prefix}Screen", (0.84, 0.06, 0.66), (0, -0.5, 1.62), rot=rad(-12, 0, 0), bevel=0.03, m=screen),
        box(f"{prefix}Panel", (1.0, 0.45, 0.1), (0, -0.6, 1.1), rot=rad(-20, 0, 0), bevel=0.03, m=panel),
        sphere(f"{prefix}Stick", 0.07, (-0.2, -0.62, 1.22), m=mat("Red")),
    ]


def _claw_machine(prefix, body, glass, marquee):
    """Claw crane at the origin, facing -Y: cabinet, open case lit from a back
    pane, prizes and the claw, marquee on top."""
    parts = [
        box(f"{prefix}Base", (1.15, 1.1, 0.95), (0, 0, 0.475), bevel=0.07, m=body),
        box(f"{prefix}BackPane", (1.05, 0.05, 1.05), (0, 0.5, 1.5), bevel=0.0, m=glass),
        box(f"{prefix}Top", (1.2, 1.15, 0.32), (0, 0, 2.18), bevel=0.06, m=body),
        box(f"{prefix}Marquee", (0.9, 0.06, 0.2), (0, -0.59, 2.18), bevel=0.02, m=marquee),
        box(f"{prefix}Chute", (0.36, 0.08, 0.3), (0.3, -0.56, 0.62), bevel=0.03, m=mat("Dark")),
        cyl(f"{prefix}Claw", 0.06, 0.4, (0, 0, 1.85), segs=8, bevel=0.0, m=mat("GreyLight")),
    ]
    for i, (px, py) in enumerate(((-0.52, -0.5), (0.52, -0.5), (-0.52, 0.5), (0.52, 0.5))):
        parts.append(box(f"{prefix}Corner{i}", (0.08, 0.08, 1.06), (px, py, 1.5), bevel=0.02, m=body))
    for i, (px, py, c) in enumerate(((-0.25, -0.2, "PinkLight"), (0.2, 0.15, "Yellow"), (-0.1, 0.25, "BlueLight"))):
        parts.append(sphere(f"{prefix}Prize{i}", 0.17, (px, py, 1.15), m=mat(c), segs=10, rings=6))
    return parts


def build_surfboards():
    """Two surfboards leaning on the rail (lean toward +Y)."""
    reset_scene()
    parts = []
    specs = [(-0.42, "Yellow", "Pink"), (0.42, "PinkLight", "White")]
    for i, (x, body, stripe) in enumerate(specs):
        lean = rad(-10 - i * 3, 0, 4 - i * 8)
        parts.append(sphere(f"Board{i}", 1.0, (x, 0, 1.22), scale=(0.3, 0.055, 1.22), rot=lean, m=mat(body), segs=16, rings=12))
        parts.append(sphere(f"Stripe{i}", 1.0, (x, -0.012, 1.22), scale=(0.07, 0.058, 1.2), rot=lean, m=mat(stripe), segs=10, rings=12))
    save("surfboards", [merge("Surfboards", parts)])


def build_life_ring():
    """Life ring hanging on the rail, facing -Y (origin at its centre)."""
    reset_scene()
    white, red = mat("White"), mat("Red")
    parts = [torus("Ring", 0.3, 0.095, rot=rad(90, 0, 0), m=white, major_segs=28, minor_segs=8)]
    for i in range(4):
        a = math.radians(45 + i * 90)
        parts.append(torus(f"Band{i}", 0.3, 0.102, rot=rad(90, 0, 0), m=red, major_segs=5, minor_segs=8,
                           arc=math.radians(34), start=a - math.radians(17)))
    save("life_ring", [merge("LifeRing", parts)])


def build_coaster():
    """Background roller coaster: a rolling pink track on white supports (scenery only)."""
    reset_scene()
    track_m, support_m, teal = mat("Pink"), mat("White"), mat("TealLight")
    amber = glow("BulbAmber", "#ffc24a", 3.0)
    parts = []
    pts = []
    for i in range(61):
        t = i / 60.0
        x = -34 + 68 * t
        z = 7.5 + 5.5 * math.sin(t * math.pi * 3.2 + 0.6) + 3.0 * math.sin(t * math.pi * 1.1)
        y = 2.5 * math.sin(t * math.pi * 2.0)
        pts.append((x, y, max(2.5, z)))
    for side in (-0.55, 0.55):
        parts.append(tube(f"Rail{side}", [(x, y + side, z) for x, y, z in pts], 0.16, m=track_m, segs=6))
    parts.append(tube("Spine", [(x, y, z - 0.45) for x, y, z in pts], 0.24, m=teal, segs=6))
    for i in range(0, 61, 4):
        x, y, z = pts[i]
        parts.append(box(f"Support{i}", (0.32, 0.32, z), (x, y, z / 2 - 0.3), bevel=0.04, m=support_m))
        if i % 8 == 0:
            parts.append(box(f"Brace{i}", (0.2, 2.6, 0.2), (x, y, z * 0.5), bevel=0.03, m=support_m))
        parts.append(bulb(f"Bulb{i}", 0.2, (x, y, z + 0.35), amber))
    # Flags on the two highest crests.
    for i in (9, 46):
        x, y, z = pts[i]
        parts.append(cyl(f"Mast{i}", 0.06, 2.4, (x, y, z + 1.4), segs=6, bevel=0.0, m=support_m))
        parts.append(prism(f"Flag{i}", [(0, 0), (1.1, 0.3), (0, 0.6)], 0.05, (x + 0.05, y, z + 1.9), m=track_m))
    save("coaster", [merge("Coaster", parts)])


def build_portal_arch():
    """The exit portal's frame: a chunky lit arch. Opening about 2.9 m wide x 3.5 m tall, faces -Y."""
    reset_scene()
    purple, pink, teal, dark = mat("Purple"), mat("Pink"), mat("Teal"), mat("PurpleDark")
    amber = glow("BulbAmber", "#ffc24a", 3.0)
    cyan = glow("PortalCyan", "#33f0ff", 3.0)
    arch_r, spring = 1.75, 2.0
    parts = []
    for x in (-arch_r, arch_r):
        parts += [
            box(f"Pillar{x}", (0.62, 0.8, spring), (x, 0, spring / 2), bevel=0.1, segs=3, m=purple),
            box(f"Base{x}", (0.9, 1.05, 0.45), (x, 0, 0.225), bevel=0.08, m=teal),
            box(f"Band{x}", (0.7, 0.88, 0.22), (x, 0, spring - 0.1), bevel=0.05, m=pink),
        ]
    arch = arc_points(arch_r, 0, 180, 20, centre=(0, 0, spring))
    parts.append(tube("Arch", arch, 0.36, m=purple, segs=10))
    parts.append(tube("ArchInner", arc_points(arch_r - 0.3, 0, 180, 20, centre=(0, -0.2, spring)), 0.09, m=cyan, segs=6))
    for x in (-arch_r + 0.3, arch_r - 0.3):
        parts.append(box(f"Strip{x}", (0.1, 0.1, spring - 0.5), (x, -0.36, spring / 2 + 0.2), bevel=0.03, m=cyan))
    for i in range(13):
        a = math.radians(i * 15)
        parts.append(bulb(f"Bulb{i:02d}", 0.1, (math.cos(a) * (arch_r + 0.05), -0.4, spring + math.sin(a) * (arch_r + 0.05)), amber))
    parts += [
        cyl("KeyDisc", 0.5, 0.5, (0, -0.05, spring + arch_r + 0.2), rot=rad(90, 0, 0), segs=18, bevel=0.08, m=pink),
        star("KeyStar", 0.34, 0.16, (0, -0.32, spring + arch_r + 0.2), m=mat("Yellow")),
        box("Back", (3.4, 0.12, spring + arch_r - 0.3), (0, 0.32, (spring + arch_r - 0.3) / 2), bevel=0.0, m=dark),
    ]
    parts += portal_back(spring + arch_r - 0.3, purple, pink, teal, cyan, amber)
    save("portal_arch", [merge("PortalArch", parts)])


def portal_back(height, frame_m, band_m, box_m, glow_m, bulb_m=None):
    """The machine side of a portal (seen by walking round it): a framed
    panel with ribs, a glowing core, conduits down to a power box and a row
    of bulbs. Sits on the +Y face of the arch's back panel (y = 0.38)."""
    y = 0.4
    parts = [
        box("BackFrameTop", (3.2, 0.14, 0.2), (0, y, height - 0.12), bevel=0.04, m=frame_m),
        box("BackFrameL", (0.2, 0.14, height - 0.5), (-1.3, y, height / 2 + 0.1), bevel=0.04, m=frame_m),
        box("BackFrameR", (0.2, 0.14, height - 0.5), (1.3, y, height / 2 + 0.1), bevel=0.04, m=frame_m),
        cyl("BackCoreRing", 0.62, 0.16, (0, y + 0.02, 2.25), rot=rad(90, 0, 0), segs=20, bevel=0.04, m=band_m),
        cyl("BackCore", 0.46, 0.2, (0, y + 0.04, 2.25), rot=rad(90, 0, 0), segs=20, bevel=0.04, m=box_m),
        torus("BackCoreGlow", 0.3, 0.05, (0, y + 0.15, 2.25), rot=rad(90, 0, 0), m=glow_m, major_segs=20, minor_segs=6),
        cyl("BackCoreEye", 0.12, 0.08, (0, y + 0.15, 2.25), rot=rad(90, 0, 0), segs=12, bevel=0.02, m=glow_m),
        box("BackPowerBox", (1.5, 0.34, 0.8), (0, y + 0.1, 0.62), bevel=0.06, m=box_m),
        box("BackPowerBand", (1.56, 0.36, 0.14), (0, y + 0.1, 0.84), bevel=0.03, m=band_m),
        box("BackPowerLight", (0.5, 0.06, 0.12), (0, y + 0.29, 0.5), bevel=0.02, m=glow_m),
    ]
    for i, z in enumerate((1.3, 3.0)):
        parts.append(box(f"BackRib{i}", (2.5, 0.1, 0.12), (0, y, z), bevel=0.03, m=frame_m))
    for i, x in enumerate((-0.42, 0.42)):
        parts.append(tube(f"BackConduit{i}", [(x, y + 0.12, 1.0), (x, y + 0.12, 1.55), (x * 0.6, y + 0.1, 1.9)], 0.06, m=band_m, segs=6))
    if bulb_m is not None:
        parts += bulb_row("BackBulb", (-1.05, y + 0.08, height - 0.4), (1.05, y + 0.08, height - 0.4), 6, 0.08, bulb_m)
    return parts


def _shop(name, body_hex, trim_hex, awning_a, awning_b, label, sign_hex):
    """Beach-side shopfront (scenery behind the pier entrance). 9 m wide, front faces -Y."""
    reset_scene()
    body, trim = mat("ShopBody" + name, body_hex, rough=0.8), mat("ShopTrim" + name, trim_hex, rough=0.6)
    a, b = mat(awning_a), mat(awning_b)
    cream, dark = mat("Cream"), mat("Dark")
    sign = mat("ShopSign" + name, sign_hex, rough=0.5)
    glass = mat("ShopGlass", "#3b2f63", rough=0.15, metal=0.2)
    warm = glow("WindowWarm", "#ffd68a", 1.3)
    amber = glow("BulbAmber", "#ffc24a", 3.0)
    w, d, h = 9.0, 7.0, 5.0
    parts = [
        box("Body", (w, d, h), (0, d / 2, h / 2), bevel=0.14, segs=3, m=body),
        box("Base", (w + 0.2, d + 0.2, 0.5), (0, d / 2, 0.25), bevel=0.06, m=trim),
        box("Roof", (w + 0.5, d + 0.5, 0.35), (0, d / 2, h + 0.15), bevel=0.12, m=trim),
        box("Window", (w - 2.8, 0.2, 2.2), (0.6, -0.02, 2.0), bevel=0.06, m=glass),
        box("WindowLight", (w - 3.2, 0.1, 1.7), (0.6, 0.06, 2.0), bevel=0.02, m=warm),
        box("Sill", (w - 2.4, 0.4, 0.14), (0.6, -0.12, 0.86), bevel=0.04, m=cream),
        box("Door", (1.4, 0.2, 2.6), (-w / 2 + 1.2, -0.02, 1.3), bevel=0.05, m=dark),
        box("SignBoard", (w * 0.75, 0.35, 1.2), (0, -0.25, h + 0.95), bevel=0.25, segs=3, m=sign),
        text("SignText", label, 0.72, 0.12, (0, -0.48, h + 0.93), m=cream),
    ]
    parts += _awning("Awning", w + 0.3, 1.6, 3.7, 3.1, -0.05, -1.5, 9, a, b)
    parts += bulb_row("SignBulb", (-w * 0.36, -0.45, h + 1.62), (w * 0.36, -0.45, h + 1.62), 12, 0.08, amber)
    save(name, [merge("Shop", parts)])


def build_beach_shop_a():
    _shop("beach_shop_a", "#ff86c4", "#c41f74", "Teal", "Cream", "SURF", "#12989c")


def build_beach_shop_b():
    _shop("beach_shop_b", "#ffd36b", "#e07b1f", "Pink", "Cream", "TACOS", "#6b35b8")


def build_beach_shop_c():
    _shop("beach_shop_c", "#7fd6cf", "#0b6268", "Orange", "Cream", "ICE CREAM", "#e0218a")


def build_beach_shop_d():
    _shop("beach_shop_d", "#b493ea", "#3d1f73", "Yellow", "Pink", "GIFTS", "#ff3f9f")


def build_popcorn_cart():
    """Popcorn cart with a striped umbrella. Front faces -Y."""
    reset_scene()
    red, white, cream, dark = mat("Red"), mat("White"), mat("Cream"), mat("Dark")
    pop = mat("Popcorn", "#fff2b8", rough=0.9)
    glass = mat("CartGlass", "#cfeeff", rough=0.1)
    yellow, teal = mat("Yellow"), mat("Teal")
    parts = [
        box("Cart", (1.6, 0.9, 0.8), (0, 0, 0.75), bevel=0.08, segs=3, m=red),
        box("CartStripe", (1.62, 0.92, 0.14), (0, 0, 0.75), bevel=0.03, m=white),
        box("Top", (1.7, 1.0, 0.08), (0, 0, 1.18), bevel=0.03, m=yellow),
        box("Glass", (1.2, 0.7, 0.7), (0, 0, 1.56), bevel=0.04, m=glass),
        box("Roof", (1.36, 0.86, 0.12), (0, 0, 1.96), bevel=0.04, m=red),
        text("Label", "POPCORN", 0.2, 0.04, (0, -0.47, 0.98), m=yellow),
        cyl("Pole", 0.035, 1.6, (0, 0, 2.7), segs=8, bevel=0.0, m=white),
    ]
    import random
    rng = random.Random(4)
    for i in range(26):
        parts.append(sphere(f"Pop{i}", 0.07, (rng.uniform(-0.5, 0.5), rng.uniform(-0.28, 0.28), 1.27 + rng.uniform(0, 0.22)), m=pop, segs=6, rings=4))
    for x in (-0.65, 0.65):
        parts.append(cyl(f"Wheel{x}", 0.26, 0.08, (x, -0.47, 0.28), rot=rad(90, 0, 0), segs=16, bevel=0.02, m=dark))
        parts.append(cyl(f"Hub{x}", 0.08, 0.1, (x, -0.49, 0.28), rot=rad(90, 0, 0), segs=10, bevel=0.01, m=yellow))
    for i in range(8):
        a0, a1 = math.tau * i / 8, math.tau * (i + 1) / 8
        tri = [(0, 0), (math.cos(a0) * 1.25, math.sin(a0) * 1.25), (math.cos(a1) * 1.25, math.sin(a1) * 1.25)]
        seg = prism(f"Umbrella{i}", [(x, y) for x, y in tri], 0.04, (0, 0, 3.45), rot=rad(90, 0, 0), m=red if i % 2 else white)
        seg.rotation_euler = Euler((math.radians(0), 0, 0), "XYZ")
        # Lay the slice flat (prism extrudes along Y; rotate so it lies in XY) and droop it slightly.
        for v in seg.data.vertices:
            x, y, z = v.co
            r = math.hypot(x, z)
            v.co = Vector((x, z, y - 0.35 * r))
        parts.append(seg)
    parts.append(sphere("UmbrellaTop", 0.08, (0, 0, 3.52), m=teal))
    save("popcorn_cart", [merge("PopcornCart", parts)])


def build_trash_bin():
    reset_scene()
    teal, pink, dark = mat("Teal"), mat("Pink"), mat("TealDark")
    parts = [
        cyl("Bin", 0.32, 0.9, (0, 0, 0.45), segs=16, bevel=0.04, m=teal, radius_top=0.34),
        cyl("Band", 0.35, 0.1, (0, 0, 0.68), segs=16, bevel=0.02, m=dark),
        cyl("Lid", 0.38, 0.14, (0, 0, 0.97), segs=16, bevel=0.05, m=pink, radius_top=0.3),
        sphere("Knob", 0.07, (0, 0, 1.08), m=pink),
    ]
    save("trash_bin", [merge("TrashBin", parts)])


def build_seagull():
    """A gull to perch on rail posts, lamps and roofs (the kiosk mascot at life size, looking toward +X)."""
    reset_scene()
    from build_kiosk import build_seagull as gull_parts
    save("seagull", [merge("Seagull", place(gull_parts(), scale=0.27))])


def build_sailboat():
    """Toy sailing dinghy for the bay (scenery). Bow toward +X, waterline at z = 0."""
    reset_scene()
    white, pink, cream, wood, teal = mat("White"), mat("Pink"), mat("Cream"), mat("Wood"), mat("Teal")
    plan = [(-2.3, -0.8), (0.9, -0.95), (2.9, 0.0), (0.9, 0.95), (-2.3, 0.8)]
    deck = [(x * 0.9, y * 0.82) for x, y in plan]
    parts = [
        prism("Hull", plan, 1.0, (0, 0, 0.15), rot=rad(90, 0, 0), m=white, bevel=0.12, segs=3),
        prism("Stripe", [(x * 1.02, y * 1.03) for x, y in plan], 0.2, (0, 0, 0.42), rot=rad(90, 0, 0), m=pink, bevel=0.04),
        prism("Deck", deck, 0.1, (0, 0, 0.66), rot=rad(90, 0, 0), m=wood),
        box("Cabin", (1.3, 0.9, 0.5), (-1.0, 0, 0.92), bevel=0.1, m=teal),
        cyl("Mast", 0.07, 6.4, (0.4, 0, 3.8), segs=8, bevel=0.0, m=wood),
        box("Boom", (2.9, 0.08, 0.08), (-1.0, 0, 1.45), bevel=0.02, m=wood),
        prism("MainSail", [(0.0, 0.0), (-2.7, 0.0), (0.0, 5.2)], 0.05, (0.28, 0, 1.6), m=cream),
        prism("MainStripe", [(0.0, 1.5), (-1.92, 1.5), (-1.5, 2.3), (0.0, 2.3)], 0.07, (0.28, 0, 1.6), m=pink),
        prism("Jib", [(0.0, 0.0), (2.2, 0.0), (0.0, 4.4)], 0.05, (0.52, 0, 1.2), m=mat("PinkLight")),
        prism("Pennant", [(0.0, 0.0), (-0.7, 0.14), (0.0, 0.28)], 0.03, (0.36, 0, 6.7), m=pink),
    ]
    save("sailboat", [merge("Sailboat", parts)])


def build_buoy():
    """Channel marker buoy with a lamp on top. Waterline at z = 0."""
    reset_scene()
    red, white, dark = mat("Red"), mat("White"), mat("TealDark")
    amber = glow("BulbAmber", "#ffc24a", 3.0)
    parts = [
        cyl("Float", 0.75, 0.7, (0, 0, 0.05), segs=14, bevel=0.12, m=red),
        cyl("Body", 0.52, 1.5, (0, 0, 1.0), segs=12, bevel=0.03, m=red, radius_top=0.24),
        cyl("Band", 0.44, 0.34, (0, 0, 0.98), segs=12, bevel=0.02, m=white, radius_top=0.37),
        cyl("Cage", 0.2, 0.3, (0, 0, 1.9), segs=8, bevel=0.03, m=dark),
        bulb("Lamp", 0.17, (0, 0, 2.18), amber),
    ]
    save("buoy", [merge("Buoy", parts)])


def build_lighthouse():
    """Striped lighthouse on a rock, far out in the bay (scenery). About 30 m
    tall; the lamp room's centre is 24.9 m above the waterline (z = 0), where
    the level adds the turning beams."""
    reset_scene()
    white, pink, dark, teal = mat("White"), mat("Pink"), mat("TealDark"), mat("Teal")
    rock = mat("Rock", "#6a4a5e", rough=0.95)
    amber = glow("BulbAmber", "#ffc24a", 3.0)
    glass = glow("LampRoom", "#ffe9a8", 2.0)
    import random
    rng = random.Random(11)
    parts = []
    for i in range(7):
        a = math.tau * i / 7
        r = rng.uniform(4.0, 7.5)
        parts.append(sphere(f"Rock{i}", rng.uniform(3.5, 5.5), (math.cos(a) * r, math.sin(a) * r, rng.uniform(-1.2, 0.4)),
                            scale=(1.3, 1.0, 0.55), rot=(0, 0, a), m=rock, segs=8, rings=5))
    parts.append(sphere("RockTop", 6.5, (0, 0, 0.2), scale=(1.2, 1.1, 0.5), m=rock, segs=10, rings=6))
    # Tower: five tapering bands, alternately white and pink.
    base_r, top_r, h0, h = 3.6, 2.2, 2.4, 21.0
    for i in range(5):
        r0 = base_r + (top_r - base_r) * i / 5
        r1 = base_r + (top_r - base_r) * (i + 1) / 5
        parts.append(cyl(f"Band{i}", r0, h / 5, (0, 0, h0 + h / 5 * (i + 0.5)), segs=16, bevel=0.0,
                         m=white if i % 2 == 0 else pink, radius_top=r1))
    top = h0 + h
    parts += [
        cyl("Plinth", 4.2, 1.0, (0, 0, h0 - 0.3), segs=16, bevel=0.15, m=dark),
        box("Door", (1.2, 0.3, 2.2), (0, -3.5, h0 + 1.2), bevel=0.08, m=dark),
        cyl("Gallery", 3.2, 0.35, (0, 0, top + 0.15), segs=16, bevel=0.06, m=dark),
        torus("GalleryRail", 3.1, 0.07, (0, 0, top + 1.2), m=teal, major_segs=20, minor_segs=5),
        cyl("LampRoom", 1.6, 2.4, (0, 0, top + 1.5), segs=12, bevel=0.05, m=glass),
        cyl("RoofCone", 2.3, 1.9, (0, 0, top + 3.6), segs=14, bevel=0.0, m=pink, radius_top=0.2),
        sphere("RoofBall", 0.35, (0, 0, top + 4.7), m=amber, segs=8, rings=6),
    ]
    for i in range(8):
        a = math.tau * i / 8
        parts.append(cyl(f"RailPost{i}", 0.06, 1.1, (math.cos(a) * 3.1, math.sin(a) * 3.1, top + 0.75), segs=6, bevel=0.0, m=teal))
        parts.append(box(f"Mullion{i}", (0.12, 0.12, 2.4), (math.cos(a) * 1.62, math.sin(a) * 1.62, top + 1.5), rot=(0, 0, a), bevel=0.0, m=dark))
    for i, z in enumerate((h0 + 6.5, h0 + 12.5, h0 + 17.5)):
        parts.append(box(f"Window{i}", (0.8, 0.3, 1.2), (0, -(base_r + (top_r - base_r) * (z - h0) / h) + 0.05, z), bevel=0.06, m=glass))
    save("lighthouse", [merge("Lighthouse", parts)])


def _signpost(name, boards):
    """Fingerpost: a teal post with arrow boards. `boards` is a list of
    (label, palette colour, angle in degrees seen from above with 0 = +X and
    90 = +Y, height). The lettering reads from both sides."""
    reset_scene()
    teal, dark, cream, pink = mat("Teal"), mat("TealDark"), mat("Cream"), mat("Pink")
    parts = [
        cyl("Post", 0.09, 3.5, (0, 0, 1.75), segs=10, bevel=0.0, m=teal),
        cyl("Foot", 0.2, 0.3, (0, 0, 0.15), segs=10, bevel=0.04, m=dark, radius_top=0.14),
        cyl("Cap", 0.14, 0.1, (0, 0, 3.52), segs=10, bevel=0.03, m=dark),
        sphere("Ball", 0.15, (0, 0, 3.68), m=pink, segs=10, rings=6),
    ]
    arrow = [(0.06, -0.19), (1.42, -0.19), (1.72, 0.0), (1.42, 0.19), (0.06, 0.19)]
    for i, (label, color, angle, z) in enumerate(boards):
        size = min(0.2, 1.9 / max(1, len(label)))
        board = [
            prism(f"Board{i}", arrow, 0.07, (0, 0, 0), m=mat(color), bevel=0.02),
            box(f"Clamp{i}", (0.26, 0.2, 0.3), (0, 0, 0), bevel=0.03, m=dark),
            text(f"LabelF{i}", label, size, 0.03, (0.8, -0.045, -0.01), m=cream),
            text(f"LabelB{i}", label, size, 0.03, (0.8, 0.045, -0.01), rot=(0, 0, math.pi), m=cream),
        ]
        parts += place(board, (0, 0, z), rot_z=math.radians(angle))
    save(name, [merge("Signpost", parts)])


def build_signpost_a():
    """Stands in the planter behind the kiosk: portal east, Ferris wheel west, prizes south."""
    _signpost("signpost_a", [("PORTAL", "Purple", 10, 3.15), ("FERRIS WHEEL", "Pink", 196, 2.7), ("PRIZES", "Orange", 270, 2.25)])


def build_signpost_b():
    """Stands in the planter by the pier entrance: prizes ahead, portal beyond, arcade west, beach behind."""
    _signpost("signpost_b", [("PRIZES", "Orange", 96, 3.15), ("PORTAL", "Purple", 62, 2.7), ("ARCADE", "Pink", 178, 2.25), ("BEACH", "Teal", 270, 1.8)])


def build_beach_umbrella():
    """Striped beach umbrella over a towel (scenery on the sand)."""
    reset_scene()
    pink, white, wood, teal, yellow = mat("Pink"), mat("White"), mat("Wood"), mat("TealLight"), mat("Yellow")
    parts = [
        cyl("Pole", 0.05, 2.5, (0, 0, 1.25), rot=rad(0, 8, 0), segs=6, bevel=0.0, m=wood),
        box("Towel", (2.0, 0.9, 0.04), (0.5, -0.5, 0.02), rot=rad(0, 0, 20), bevel=0.0, m=teal),
        box("TowelStripe", (0.3, 0.92, 0.045), (0.5, -0.5, 0.022), rot=rad(0, 0, 20), bevel=0.0, m=yellow),
        sphere("Ball", 0.3, (-0.9, 0.5, 0.3), m=yellow, segs=10, rings=6),
        sphere("Finial", 0.08, (0.35, 0, 2.62), m=wood, segs=6, rings=4),
    ]
    for i in range(8):
        a0, a1 = math.tau * i / 8, math.tau * (i + 1) / 8
        seg = prism(f"Panel{i}", [(0.0, 0.0), (math.cos(a0) * 1.7, math.sin(a0) * 1.7), (math.cos(a1) * 1.7, math.sin(a1) * 1.7)],
                    0.05, (0.33, 0, 2.5), m=pink if i % 2 else white)
        # The prism stands in XZ: lay it flat and let it droop toward the rim.
        for v in seg.data.vertices:
            x, y, z = v.co
            v.co = Vector((x, z, y - 0.26 * math.hypot(x, z)))
        parts.append(seg)
    save("beach_umbrella", [merge("BeachUmbrella", parts)])


if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    builders = {k[6:]: v for k, v in list(globals().items()) if k.startswith("build_")}
    for name, fn in builders.items():
        if not only or name in only:
            fn()
