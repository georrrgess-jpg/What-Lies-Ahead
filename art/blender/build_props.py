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
    amber = glow("BulbAmber", "#ffb030", 1.9)
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
    amber = glow("BulbAmber", "#ffb030", 1.9)
    yellow, wood = mat("Yellow"), mat("Wood")
    w, d = 4.6, 3.2
    parts = [
        box("Floor", (w, d, 0.12), (0, 0, 0.06), bevel=0.03, m=wood),
        box("Counter", (w, 0.5, 1.0), (0, -d / 2 + 0.25, 0.6), bevel=0.06, m=teal),
        box("CounterTop", (w + 0.16, 0.66, 0.1), (0, -d / 2 + 0.25, 1.14), bevel=0.04, m=pink),
        box("CounterStripe", (w + 0.02, 0.52, 0.16), (0, -d / 2 + 0.25, 0.45), bevel=0.02, m=cream),
        box("BackWall", (w, 0.2, 3.0), (0, d / 2 - 0.1, 1.6), bevel=0.04, m=dark),
        box("SideL", (0.2, d, 3.0), (-w / 2 + 0.1, 0, 1.6), bevel=0.04, m=teal),
        box("SideR", (0.2, d, 3.0), (w / 2 - 0.1, 0, 1.6), bevel=0.04, m=teal),
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
    amber = glow("BulbAmber", "#ffb030", 1.9)
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
    """Ticket building that closes the pier entrance. 12 m wide, dark doorway facing -Y."""
    reset_scene()
    teal, pink, cream, dark = mat("Teal"), mat("Pink"), mat("Cream"), mat("Dark")
    amber = glow("BulbAmber", "#ffb030", 1.9)
    hot, yellow = mat("PinkDark"), mat("Yellow")
    parts = [
        box("Body", (12.0, 3.0, 5.2), (0, 1.5, 2.6), bevel=0.15, segs=3, m=teal),
        box("Plinth", (12.3, 3.2, 0.5), (0, 1.5, 0.25), bevel=0.08, m=hot),
        box("Doorway", (5.0, 0.4, 3.6), (0, -0.05, 1.8), bevel=0.05, m=dark),
        box("DoorFrame", (5.6, 0.3, 0.4), (0, -0.1, 3.75), bevel=0.08, m=pink),
        box("Roof", (12.6, 3.6, 0.5), (0, 1.5, 5.4), bevel=0.15, m=pink),
        box("Sign", (7.0, 0.4, 1.3), (0, -0.1, 6.3), bevel=0.2, segs=3, m=hot),
        text("SignText", "TICKETS", 0.8, 0.12, (0, -0.36, 6.28), m=cream),
    ]
    for x in (-2.8, 2.8):
        parts.append(box(f"DoorPost{x}", (0.4, 0.34, 3.6), (x, -0.1, 1.8), bevel=0.08, m=pink))
    for x in (-4.4, 4.4):
        parts += [
            box(f"Window{x}", (1.8, 0.2, 1.5), (x, -0.02, 2.5), bevel=0.06, m=dark),
            box(f"WindowSill{x}", (2.1, 0.4, 0.16), (x, -0.1, 1.68), bevel=0.05, m=cream),
        ]
        parts += _awning(f"WinAwning{x}", 2.3, 0.9, 3.75, 3.35, -0.02, -0.85, 5, pink, cream, 0.07)
        for p in parts[-10:]:
            p.location.x += x
    parts += bulb_row("SignBulbT", (-3.3, -0.36, 6.85), (3.3, -0.36, 6.85), 14, 0.09, amber)
    parts += bulb_row("SignBulbB", (-3.3, -0.36, 5.72), (3.3, -0.36, 5.72), 14, 0.09, amber)
    parts.append(star("SignStarL", 0.4, 0.14, (-2.9, -0.36, 6.28), m=yellow))
    parts.append(star("SignStarR", 0.4, 0.14, (2.9, -0.36, 6.28), m=yellow))
    save("gatehouse", [merge("Gatehouse", parts)])


def build_service_door():
    """Roll-up service door at the bottom of the ramp. 6.4 m wide, faces -Y."""
    reset_scene()
    teal, dark, yellow, grey = mat("TealDark"), mat("Dark"), mat("Yellow"), mat("Grey", rough=0.5, metal=0.3)
    parts = [
        box("Frame", (6.6, 0.5, 3.9), (0, 0.25, 1.95), bevel=0.08, m=teal),
        box("Opening", (5.2, 0.3, 3.0), (0, -0.02, 1.5), bevel=0.03, m=dark),
        box("Roller", (5.5, 0.5, 0.5), (0, -0.05, 3.2), bevel=0.12, m=grey),
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
    amber = glow("BulbAmber", "#ffb030", 1.9)
    hot, yellow = mat("PinkDark"), mat("Yellow")
    w, d, h = 14.0, 8.0, 5.2
    parts = [
        box("Back", (w, 0.4, h), (0, d / 2 - 0.2, h / 2), bevel=0.06, m=inner),
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
    save("arcade", [merge("Arcade", parts)])


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
    amber = glow("BulbAmber", "#ffb030", 1.9)
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
    amber = glow("BulbAmber", "#ffb030", 1.9)
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
    save("portal_arch", [merge("PortalArch", parts)])


if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    builders = {k[6:]: v for k, v in list(globals().items()) if k.startswith("build_")}
    for name, fn in builders.items():
        if not only or name in only:
            fn()
