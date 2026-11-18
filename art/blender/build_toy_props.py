"""Toybox Town props (World 15, Toy Shop). You are toy-sized: 1 m here is about
10 cm of shop, so a letter block is 2.4 m and a crayon is 7 m tall.

    toy_block_<colour>     ABC letter block, 2.4 m (Red, Yellow, Blue, Green)
    toy_book_<colour>      a hardback lying flat, 4.2 x 3 x 0.5 m (stairs and ramps)
    toy_gamebox_a / _b     board-game box, 7 x 5 x 1.3 m, printed lid
    toy_crayon_box         an open crayon box with eight giant crayons standing in it
    toy_crayon             one crayon lying on its side (Red wax; 7.4 m)
    toy_ballpit            padded ring wall (r 4.2, 1.2 m) full of coloured balls
    toy_car_red / _blue    toy race car, 2.8 m
    toy_racetrack          flat oval toy track (straights 12 m, bends r 6.5, 3.2 m lane)
    toy_jack_box           jack-in-the-box: the 4.6 m box with its open lid and crank
    toy_jack_pop           the spring and the jester head (bobs on ambient motion)
    toy_dollhouse          two-storey dollhouse, open side -Y (see DOLLHOUSE below)
    toy_train_loco         toy locomotive, 4.4 m, front -Y (Godot +Z)
    toy_train_car_a / _b   open wagon of blocks / lit passenger coach, 3.8 m
    toy_track              elevated track module, 2 m along X (rails, sleepers, girder)
    toy_pier               stacked-block pier under the track, 1.4 m square, 5.4 m tall
    toy_teddy              a sitting teddy bear, ~6 m (shelf scenery)
    toy_robot              a tin robot, ~7 m (shelf scenery)
    toy_rocket             a tin rocket on fins, ~9 m (shelf scenery)
    toy_drum               a toy drum, 4 m (scenery and cover)
    toy_shelf              wall shelf bay: 16 m wide, 5 m deep, 36 m tall, four boards
    toy_pendant            a hanging shop lamp shade with its glowing bulb (6 m wide)
    toy_street_lamp        the gas lamp outside the window (street scenery)
    toy_exit_star          exit nightlight: a block with a glowing star (ToyExitGlow)

    python art/blender/build_toy_props.py [name ...]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from toy_common import *  # noqa: F401,F403
from build_world_portals import xform  # noqa: E402
from wla_common import _finish  # noqa: E402

# Dollhouse (Blender: open side at -Y; X -7..7, Y -4.5..4.5).
DH_W = 14.0
DH_D = 9.0
DH_UPPER = 4.0        # top of the upper floor
DH_EAVE = 8.0
DH_RIDGE = 11.0
DH_WALL = 0.35


def one(name, parts):
    """Bakes `parts` into one export mesh, saves it, and clears the scene for the next model."""
    save(name, [merge(name, parts)])
    reset_scene()


def block(colour):
    one("toy_block_" + colour.lower(), letter_block("B", 2.4, colour))


def book(colour):
    cover = tmat(colour, rough=0.55)
    pages = tmat("Paper", rough=0.8)
    gold = tmat("Brass", rough=0.35, metal=0.4)
    L, W, H = 4.2, 3.0, 0.5
    t = 0.07
    p = [box("CoverBot", (L, W, t), (0, 0, t / 2), bevel=0.03, m=cover),
         box("CoverTop", (L, W, t), (0, 0, H - t / 2), bevel=0.03, m=cover),
         box("Pages", (L - 0.2, W - 0.16, H - 2 * t + 0.02), (0.06, 0, H / 2), bevel=0.02, m=pages),
         cyl("Spine", H / 2, W, (-L / 2 + 0.02, 0, H / 2), rot=(math.pi / 2, 0, 0), segs=12, bevel=0.02, m=cover)]
    for s in (-1, 1):
        p.append(box(f"Band{s}", (0.08, W * 0.98, 0.04), (-L / 2 + 0.6, 0, H if s > 0 else 0.0), bevel=0.01, m=gold))
    p.append(box("Title", (1.6, 0.7, 0.03), (0.4, 0, H + 0.01), bevel=0.01, m=gold))
    one("toy_book_" + colour.lower(), p)


def gamebox(variant):
    lid_c, rim_c, art_c = (("Blue", "Yellow", "Red") if variant == "a" else ("Red", "Cream", "Blue"))
    lid, rim, art, base = tmat(lid_c, rough=0.5), tmat(rim_c, rough=0.5), tmat(art_c, rough=0.5), tmat("White", rough=0.6)
    L, W, H = 7.0, 5.0, 1.3
    p = [box("Base", (L - 0.12, W - 0.12, H - 0.1), (0, 0, (H - 0.1) / 2), bevel=0.04, m=base),
         box("Lid", (L, W, 0.62), (0, 0, H - 0.31), bevel=0.06, m=lid),
         box("Rim", (L - 0.6, W - 0.6, 0.04), (0, 0, H + 0.01), bevel=0.02, m=rim),
         box("Field", (L - 1.0, W - 1.0, 0.05), (0, 0, H + 0.02), bevel=0.02, m=lid)]
    if variant == "a":
        # A snakes-and-ladders style board with a big spiral of dots.
        for k in range(14):
            a = k * 0.62
            r = 0.3 + k * 0.13
            p.append(cyl(f"Dot{k}", 0.22, 0.05, (math.cos(a) * r * 1.3, math.sin(a) * r, H + 0.05), segs=10, bevel=0.0,
                         m=art if k % 2 else rim))
        p.append(star("Star", 0.7, 0.06, (0, 0, H + 0.06), rot=(math.pi / 2, 0, 0), m=rim))
    else:
        # A checkerboard in the middle, a crown in each corner.
        for i in range(4):
            for j in range(4):
                if (i + j) % 2 == 0:
                    p.append(box(f"Sq{i}{j}", (0.7, 0.7, 0.04), (-1.05 + i * 0.7, -1.05 + j * 0.7, H + 0.05), bevel=0.0, m=art))
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.append(star(f"C{sx}{sy}", 0.32, 0.05, (sx * 2.8, sy * 1.8, H + 0.05), rot=(math.pi / 2, 0, 0), m=art))
    # Side label stripes.
    for s in (-1, 1):
        p.append(box(f"Label{s}", (L * 0.6, 0.03, 0.26), (0, s * (W / 2 + 0.005), H - 0.31), bevel=0.0, m=rim))
    one("toy_gamebox_" + variant, p)


def crayon_parts(prefix, colour, loc, length=7.4, r=0.5, rot=(0, 0, 0)):
    """A crayon standing on its flat end at loc (before `rot`, which tips it over)."""
    wax = tmat(colour, rough=0.45)
    paper = tmat(colour + "Dark" if colour + "Dark" in TOY else "Ink", rough=0.7)
    stripe = tmat("Ink", rough=0.7)
    tip = length - 1.2
    parts = [cyl(prefix + "Body", r, tip, (0, 0, tip / 2), segs=14, bevel=0.06, m=wax),
             cyl(prefix + "Wrap", r + 0.04, tip * 0.7, (0, 0, tip * 0.45), segs=14, bevel=0.02, m=paper),
             cyl(prefix + "Cone", r * 0.95, 1.0, (0, 0, tip + 0.5), segs=14, bevel=0.0, m=wax, radius_top=r * 0.25),
             sphere(prefix + "Nub", r * 0.26, (0, 0, tip + 1.0), m=wax, segs=10, rings=6)]
    for k in (0.18, 0.72):
        parts.append(cyl(f"{prefix}Ring{k}", r + 0.06, 0.12, (0, 0, tip * k), segs=14, bevel=0.0, m=stripe))
    parts.append(box(prefix + "Label", (r * 0.9, 0.05, tip * 0.3), (0, -r - 0.05, tip * 0.45), bevel=0.01, m=tmat("Cream")))
    return xform(parts, loc, rot)


def crayon_box():
    green, yellow = tmat("Green", rough=0.55), tmat("Yellow", rough=0.5)
    W, D, H = 6.0, 2.6, 3.2
    p = [box("Back", (W, 0.2, H + 1.0), (0, D / 2 - 0.1, (H + 1.0) / 2), bevel=0.06, m=green),
         box("Front", (W, 0.2, H), (0, -D / 2 + 0.1, H / 2), bevel=0.06, m=green),
         box("SideL", (0.2, D, H), (-W / 2 + 0.1, 0, H / 2), bevel=0.06, m=green),
         box("SideR", (0.2, D, H), (W / 2 - 0.1, 0, H / 2), bevel=0.06, m=green),
         box("Floor", (W, D, 0.2), (0, 0, 0.1), bevel=0.04, m=green),
         box("Chevron", (W * 0.98, 0.04, 0.9), (0, -D / 2 - 0.01, H * 0.62), bevel=0.0, m=yellow),
         text("Brand", "CRAYONS", 0.75, 0.06, (0, -D / 2 - 0.05, H * 0.62), m=tmat("Green", rough=0.55))]
    cols = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Red"]
    rng = random.Random(4)
    for k, c in enumerate(cols):
        x = -W / 2 + 0.55 + k * (W - 1.1) / 7
        length = 7.4 + rng.uniform(-1.2, 0.6)
        p += crayon_parts(f"C{k}", c, (x, rng.uniform(-0.35, 0.35), 0.2), length=length, r=0.36, rot=(rng.uniform(-0.06, 0.06), rng.uniform(-0.08, 0.08), 0))
    one("toy_crayon_box", p)


def crayon_lying():
    # Lying along X, resting on its side (origin under its middle).
    p = crayon_parts("C", "Red", (-3.7, 0, 0.5), length=7.4, r=0.5, rot=(0, math.pi / 2, 0))
    one("toy_crayon", p)


def ballpit():
    rng = random.Random(9)
    R, H = 4.2, 1.2
    p = []
    cols = [tmat(c, rough=0.3) for c in ("Red", "Yellow", "Blue", "Green")]
    n = 12
    for k in range(n):
        a0, a1 = math.tau * k / n, math.tau * (k + 1) / n
        mid = (a0 + a1) / 2
        p.append(box(f"Pad{k}", (2 * R * math.sin(math.pi / n) + 0.05, 0.6, H), (math.cos(mid) * (R - 0.3), math.sin(mid) * (R - 0.3), H / 2),
                     rot=(0, 0, mid + math.pi / 2), bevel=0.2, segs=3, m=cols[k % 4]))
    p.append(cyl("Fill", R - 0.55, 0.7, (0, 0, 0.35), segs=24, bevel=0.0, m=tmat("BlueDark", rough=0.6)))
    for i in range(110):
        a = rng.uniform(0, math.tau)
        r = math.sqrt(rng.uniform(0, 1)) * (R - 0.95)
        p.append(sphere(f"Ball{i}", 0.36, (math.cos(a) * r, math.sin(a) * r, 0.75 + rng.uniform(0, 0.22)), m=cols[i % 4], segs=8, rings=5))
    one("toy_ballpit", p)


def car(colour):
    body, dark, tyre = tmat(colour, rough=0.4), tmat("Ink", rough=0.6), tmat("Ink", rough=0.8)
    white, yellow = tmat("White"), tmat("Yellow", rough=0.4)
    p = [box("Body", (1.3, 2.8, 0.5), (0, 0, 0.55), bevel=0.18, segs=3, m=body),
         box("Nose", (0.9, 0.8, 0.32), (0, -1.5, 0.45), bevel=0.12, m=body),
         box("Cockpit", (0.8, 0.9, 0.4), (0, 0.2, 0.95), bevel=0.15, m=tmat("BlueLight", rough=0.2)),
         box("Wing", (1.5, 0.35, 0.08), (0, 1.35, 1.15), bevel=0.03, m=yellow),
         cyl("Num", 0.28, 0.04, (0.66, 0.1, 0.62), rot=(0, math.pi / 2, 0), segs=14, bevel=0.0, m=white),
         box("Stripe", (0.25, 2.9, 0.04), (0, 0, 0.81), bevel=0.0, m=white)]
    for s in (-1, 1):
        p.append(box(f"Strut{s}", (0.06, 0.08, 0.35), (s * 0.55, 1.35, 0.95), bevel=0.0, m=dark))
        for y in (-0.95, 0.95):
            p.append(cyl(f"Wheel{s}{y}", 0.36, 0.34, (s * 0.72, y, 0.36), rot=(0, math.pi / 2, 0), segs=16, bevel=0.06, m=tyre))
            p.append(cyl(f"Hub{s}{y}", 0.16, 0.36, (s * 0.72, y, 0.36), rot=(0, math.pi / 2, 0), segs=10, bevel=0.02, m=yellow))
    one("toy_car_" + colour.lower(), p)


def racetrack():
    road, white, red = tmat("TinDark", rough=0.7), tmat("White"), tmat("Red", rough=0.5)
    S, R, w = 6.0, 6.5, 3.2      # half straight, bend radius (centre line), lane width
    bm = bmesh.new()
    ring_in, ring_out = [], []

    def centre(t):
        """Stadium centre line, t 0..1."""
        per = 4 * S + 2 * math.pi * R
        d = t * per
        if d < 2 * S:
            return Vector((-S + d, -R, 0)), Vector((0, -1, 0))
        d -= 2 * S
        if d < math.pi * R:
            a = -math.pi / 2 + d / R
            return Vector((S + math.cos(a) * R, math.sin(a) * R, 0)), Vector((math.cos(a), math.sin(a), 0))
        d -= math.pi * R
        if d < 2 * S:
            return Vector((S - d, R, 0)), Vector((0, 1, 0))
        d -= 2 * S
        a = math.pi / 2 + d / R
        return Vector((-S + math.cos(a) * R, math.sin(a) * R, 0)), Vector((math.cos(a), math.sin(a), 0))

    n = 96
    pts = [centre(i / n) for i in range(n)]
    for c, out in pts:
        ring_in.append(bm.verts.new(c - out * w / 2 + Vector((0, 0, 0.06))))
        ring_out.append(bm.verts.new(c + out * w / 2 + Vector((0, 0, 0.06))))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ring_in[i], ring_out[i], ring_out[j], ring_in[j]))
    p = [_finish("Road", bm, road, (0, 0, 0), (0, 0, 0), smooth=False)]
    for i in range(n):
        c, out = pts[i]
        c2, _o = pts[(i + 1) % n]
        mid = (c + c2) / 2
        yaw = math.atan2((c2 - c).y, (c2 - c).x)
        for s in (-1, 1):
            p.append(box(f"Kerb{i}{s}", ((c2 - c).length + 0.02, 0.3, 0.12), tuple(mid + out * s * (w / 2 + 0.12) + Vector((0, 0, 0.06))),
                         rot=(0, 0, yaw), bevel=0.0, m=red if i % 2 else white))
        if i % 3 == 0:
            p.append(box(f"Dash{i}", ((c2 - c).length * 0.6, 0.12, 0.02), tuple(mid + Vector((0, 0, 0.07))), rot=(0, 0, yaw), bevel=0.0, m=white))
    for k in range(8):
        for j in range(2):
            p.append(box(f"Check{k}{j}", (0.4, 0.4, 0.02), (-0.2 + j * 0.4, -R - w / 2 + 0.2 + k * 0.4, 0.075), bevel=0.0,
                         m=white if (k + j) % 2 else tmat("Ink")))
    one("toy_racetrack", p)


def jack_box():
    S = 4.6
    cols = [tmat(c, rough=0.5) for c in ("Red", "Yellow", "Blue", "Green")]
    trim = tmat("Brass", rough=0.35, metal=0.5)
    p = [box("Box", (S, S, S), (0, 0, S / 2), bevel=0.2, m=tmat("Cream"))]
    for k in range(4):
        a = k * math.pi / 2
        nx, ny = -math.sin(a), -math.cos(a)
        p.append(box(f"Side{k}", (S * 0.86, 0.08, S * 0.86), (nx * S / 2, ny * S / 2, S / 2), rot=(0, 0, -a), bevel=0.06, m=cols[k]))
        p.append(star(f"Star{k}", S * 0.22, 0.1, (nx * (S / 2 + 0.06), ny * (S / 2 + 0.06), S / 2), rot=(0, 0, -a), m=tmat("White")))
    # Lid flipped open at the back (+Y), resting at 110 degrees.
    lid = [box("Lid", (S, S, 0.25), (0, -S / 2, 0.12), bevel=0.08, m=cols[0]),
           star("LidStar", S * 0.2, 0.08, (0, -S / 2, 0.28), rot=(math.pi / 2, 0, 0), m=tmat("Yellow"))]
    p += xform(lid, (0, S / 2, S), (math.radians(-110), 0, 0))
    # The crank on the right side.
    p += [cyl("CrankAxle", 0.14, 0.6, (S / 2 + 0.3, 0, S * 0.55), rot=(0, math.pi / 2, 0), segs=10, bevel=0.02, m=trim),
          box("CrankArm", (0.16, 0.2, 1.3), (S / 2 + 0.6, 0, S * 0.55 - 0.5), bevel=0.05, m=trim),
          cyl("CrankKnob", 0.22, 0.5, (S / 2 + 0.85, 0, S * 0.55 - 1.05), rot=(0, math.pi / 2, 0), segs=12, bevel=0.06, m=cols[0])]
    for k in range(4):
        p.append(box(f"Edge{k}", (0.22, 0.22, S + 0.02), ((1 if k % 2 else -1) * S / 2, (1 if k // 2 else -1) * S / 2, S / 2), bevel=0.08, m=trim))
    one("toy_jack_box", p)


def jack_pop():
    """The spring (from the box top at 0) and the jester head on it."""
    spring_m = tmat("Tin", rough=0.3, metal=0.6)
    pts = []
    turns, h, r = 7, 3.4, 0.9
    for i in range(turns * 16 + 1):
        a = math.tau * i / 16
        pts.append((math.cos(a) * r, math.sin(a) * r, 0.2 + h * i / (turns * 16)))
    p = [tube("Spring", pts, 0.12, m=spring_m, segs=6)]
    top = 0.2 + h
    skin, red, blue, yellow, white, ink = tmat("Cream"), tmat("Red", rough=0.4), tmat("Blue", rough=0.5), tmat("Yellow", rough=0.5), tmat("White"), tmat("Ink")
    # Ruff collar.
    for k in range(12):
        a = math.tau * k / 12
        p.append(sphere(f"Ruff{k}", 0.42, (math.cos(a) * 0.95, math.sin(a) * 0.95, top + 0.2), scale=(1, 1, 0.55), m=white if k % 2 else red, segs=10, rings=6))
    hz = top + 1.3
    p += [sphere("Head", 1.05, (0, 0, hz), m=skin, segs=20, rings=12),
          sphere("Nose", 0.24, (0, -1.02, hz - 0.05), m=red, segs=12, rings=8)]
    for s in (-1, 1):
        p += [sphere(f"Eye{s}", 0.16, (s * 0.36, -0.9, hz + 0.28), m=ink, segs=10, rings=6),
              sphere(f"Shine{s}", 0.05, (s * 0.33, -1.03, hz + 0.33), m=white, segs=6, rings=4),
              sphere(f"Cheek{s}", 0.2, (s * 0.6, -0.78, hz - 0.18), scale=(1, 0.5, 0.8), m=tmat("Pink", rough=0.6), segs=10, rings=6)]
    p.append(torus("Smile", 0.42, 0.06, (0, -0.86, hz - 0.3), rot=(math.radians(80), 0, 0), m=red, major_segs=16, minor_segs=5,
                   arc=math.radians(150), start=math.radians(195)))
    # Jester cap: three floppy points with bells.
    p.append(cyl("Band", 1.0, 0.3, (0, 0, hz + 0.75), segs=20, bevel=0.06, m=yellow))
    for k, (a, c) in enumerate(((-0.9, red), (0.0, blue), (0.9, red))):
        tip = Vector((math.sin(a) * 1.7, 0.2, hz + 2.2 - abs(a) * 0.5))
        p.append(tube(f"Point{k}", [(math.sin(a) * 0.5, 0, hz + 0.85), (math.sin(a) * 1.0, 0.1, hz + 1.8), tuple(tip)], 0.5, m=c, segs=10, radius_end=0.08))
        p.append(sphere(f"Bell{k}", 0.2, tuple(tip + Vector((0, 0, -0.15))), m=tmat("Brass", rough=0.3, metal=0.6), segs=10, rings=6))
    one("toy_jack_pop", p)


def dollhouse():
    hw, hd = DH_W / 2, DH_D / 2
    t = DH_WALL
    wall_out = tmat("Pink", rough=0.6)
    trim = tmat("White", rough=0.5)
    roof = tmat("Blue", rough=0.5)
    floor = tmat("WoodLight", rough=0.6)
    paper_a, paper_b, paper_c = tmat("Yellow", rough=0.7), tmat("BlueLight", rough=0.7), tmat("Cream", rough=0.7)
    p = []
    # Back wall (the facade, +Y) with windows and the front door, inner face papered.
    p.append(box("Back", (DH_W, t, DH_EAVE), (0, hd - t / 2, DH_EAVE / 2), bevel=0.06, m=wall_out))
    p.append(box("BackPaperL", (hw - 0.2, 0.04, DH_UPPER - 0.2), (-hw / 2, hd - t - 0.02, DH_UPPER / 2), bevel=0.0, m=paper_a))
    p.append(box("BackPaperR", (hw - 0.2, 0.04, DH_UPPER - 0.2), (hw / 2, hd - t - 0.02, DH_UPPER / 2), bevel=0.0, m=paper_b))
    p.append(box("BackPaperUp", (DH_W - 0.8, 0.04, DH_EAVE - DH_UPPER - 0.3), (0, hd - t - 0.02, (DH_EAVE + DH_UPPER) / 2), bevel=0.0, m=paper_c))
    for s in (-1, 1):
        # Side walls with a window each floor; inner faces papered.
        p.append(box(f"Side{s}", (t, DH_D, DH_EAVE), (s * (hw - t / 2), 0, DH_EAVE / 2), bevel=0.06, m=wall_out))
        p.append(box(f"SidePaper{s}", (0.04, DH_D - 0.6, DH_UPPER - 0.2), (s * (hw - t - 0.02), 0, DH_UPPER / 2), bevel=0.0,
                     m=paper_a if s < 0 else paper_b))
        # Gable ends.
        p.append(prism(f"Gable{s}", [(-hd, DH_EAVE), (hd, DH_EAVE), (0, DH_RIDGE)], t, (s * (hw - t / 2), 0, 0), rot=(0, 0, math.pi / 2), m=wall_out))
        for z in (1.6, DH_UPPER + 1.6):
            p.append(box(f"SideWin{s}{z}", (0.1, 1.6, 1.6), (s * (hw + 0.07), 0, z + 0.4), bevel=0.04, m=tmat("BlueLight", rough=0.2)))
            p.append(box(f"SideWinF{s}{z}", (0.12, 1.9, 1.9), (s * (hw + 0.01), 0, z + 0.4), bevel=0.04, m=trim))
            p.append(box(f"SideBarV{s}{z}", (0.06, 0.12, 1.6), (s * (hw + 0.13), 0, z + 0.4), bevel=0.0, m=trim))
            p.append(box(f"SideBarH{s}{z}", (0.06, 1.6, 0.12), (s * (hw + 0.13), 0, z + 0.4), bevel=0.0, m=trim))
        # Roof slopes: from the eave out front/back up to the ridge.
        ang = math.atan2(DH_RIDGE - DH_EAVE, hd)
        slope = math.hypot(DH_RIDGE - DH_EAVE, hd) + 0.6
        p.append(box(f"Roof{s}", (DH_W + 0.8, slope, 0.3), (0, s * (hd / 2 + 0.15), (DH_EAVE + DH_RIDGE) / 2 + 0.1), rot=(s * -ang, 0, 0), bevel=0.08, m=roof))
    p.append(box("Ridge", (DH_W + 0.9, 0.5, 0.4), (0, 0, DH_RIDGE + 0.25), bevel=0.12, m=trim))
    # Back-facade windows and door (outside, +Y).
    for x in (-4.0, 4.0):
        for z in (1.6, DH_UPPER + 1.6):
            p.append(box(f"Win{x}{z}", (1.8, 0.1, 1.8), (x, hd + 0.07, z + 0.4), bevel=0.04, m=tmat("BlueLight", rough=0.2)))
            p.append(box(f"WinF{x}{z}", (2.1, 0.12, 2.1), (x, hd + 0.01, z + 0.4), bevel=0.04, m=trim))
            p.append(box(f"WinBarV{x}{z}", (0.12, 0.06, 1.8), (x, hd + 0.13, z + 0.4), bevel=0.0, m=trim))
            p.append(box(f"WinBarH{x}{z}", (1.8, 0.06, 0.12), (x, hd + 0.13, z + 0.4), bevel=0.0, m=trim))
            p.append(box(f"Box{x}{z}", (2.0, 0.4, 0.3), (x, hd + 0.2, z - 0.65), bevel=0.06, m=tmat("Green", rough=0.6)))
    p += [box("Door", (1.8, 0.12, 3.0), (0, hd + 0.03, 1.5), bevel=0.05, m=tmat("Red", rough=0.5)),
          box("DoorF", (2.2, 0.14, 3.3), (0, hd + 0.01, 1.62), bevel=0.05, m=trim),
          sphere("Knob", 0.12, (0.6, hd + 0.12, 1.5), m=tmat("Brass", rough=0.3, metal=0.5), segs=8, rings=5),
          box("Step", (2.6, 0.8, 0.25), (0, hd + 0.4, 0.12), bevel=0.05, m=trim),
          star("DoorStar", 0.4, 0.06, (0, hd + 0.08, 4.3), rot=(0, 0, math.pi), m=tmat("Yellow"))]
    # Upper floor slab (with the stairwell slot along the back wall, X < 1).
    p.append(box("UpperA", (hw - 1.0 - t, DH_D - t, 0.3), ((1.0 + hw - t) / 2, -t / 2, DH_UPPER - 0.15), bevel=0.04, m=floor))
    p.append(box("UpperB", (1.0 + hw - t, 6.5 - t, 0.3), ((1.0 - hw + t) / 2, -hd + (6.5 - t) / 2, DH_UPPER - 0.15), bevel=0.04, m=floor))
    p.append(box("UpperEdge", (DH_W, 0.3, 0.5), (0, -hd + 0.15, DH_UPPER - 0.4), bevel=0.06, m=trim))
    # Ground floor: wooden floor boards (flush, visual) and a partition with a doorway.
    p.append(box("Ground", (DH_W - 0.2, DH_D - 0.2, 0.04), (0, 0, 0.02), bevel=0.0, m=floor))
    p.append(box("Partition", (t, hd - t + 1.5, DH_UPPER - 0.3), (2.5, (hd - t - 1.5) / 2, (DH_UPPER - 0.3) / 2), bevel=0.04, m=trim))
    # Stairs along the back wall: from X -6 (floor) up to X +1 (upper floor).
    steps = 15
    for k in range(steps):
        x = -6.0 + (k + 0.5) * 7.0 / steps
        h = DH_UPPER * (k + 1) / steps
        p.append(box(f"Stair{k}", (7.0 / steps + 0.02, 2.0, h), (x, hd - t - 1.0, h / 2), bevel=0.02, m=floor if k % 2 else tmat("Wood")))
    p.append(box("StairRail", (7.4, 0.12, 0.12), (-2.5, hd - t - 2.1, DH_UPPER / 2 + 1.0), rot=(0, -math.atan2(DH_UPPER, 7.0), 0), bevel=0.02, m=trim))
    # Upper-floor railing along the stairwell (Y 2.0 at the slot edge) and the open front.
    for k in range(9):
        x = -hw + t + 0.4 + k * 0.9
        p.append(cyl(f"WellPost{k}", 0.07, 1.1, (x, 2.05, DH_UPPER + 0.55), segs=6, bevel=0.0, m=trim))
    p.append(box("WellRail", (hw - t + 1.0, 0.14, 0.14), ((1.0 - hw + t) / 2, 2.05, DH_UPPER + 1.1), bevel=0.03, m=trim))
    for k in range(15):
        x = -hw + t + 0.3 + k * (DH_W - 2 * t - 0.6) / 14
        p.append(cyl(f"FrontPost{k}", 0.07, 1.1, (x, -hd + 0.2, DH_UPPER + 0.55), segs=6, bevel=0.0, m=trim))
    p.append(box("FrontRail", (DH_W - 2 * t, 0.16, 0.16), (0, -hd + 0.2, DH_UPPER + 1.1), bevel=0.04, m=trim))
    # Furniture: a table and chairs downstairs (left), a sofa (right), a bed upstairs.
    wood = tmat("Wood")
    p += [box("Table", (2.4, 1.6, 0.15), (-3.5, -1.8, 1.05), bevel=0.04, m=tmat("Red", rough=0.5))]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(cyl(f"TLeg{sx}{sy}", 0.09, 1.0, (-3.5 + sx * 1.0, -1.8 + sy * 0.6, 0.5), segs=8, bevel=0.0, m=wood))
    for sx in (-1, 1):
        p += [box(f"Chair{sx}", (0.8, 0.8, 0.12), (-3.5 + sx * 1.7, -1.8, 0.65), bevel=0.03, m=tmat("Yellow")),
              box(f"ChairBack{sx}", (0.12, 0.8, 0.9), (-3.5 + sx * 2.06, -1.8, 1.1), bevel=0.03, m=tmat("Yellow"))]
    p += [box("Sofa", (3.2, 1.2, 0.7), (4.8, -1.0, 0.35), bevel=0.2, m=tmat("Blue", rough=0.7)),
          box("SofaBack", (3.2, 0.4, 1.2), (4.8, -0.4, 0.6), bevel=0.15, m=tmat("Blue", rough=0.7)),
          box("Bed", (3.0, 1.8, 0.6), (4.6, 1.0, DH_UPPER + 0.3), bevel=0.15, m=tmat("White")),
          box("Quilt", (2.2, 1.85, 0.12), (4.2, 1.0, DH_UPPER + 0.62), bevel=0.05, m=tmat("Red", rough=0.7)),
          box("Pillow", (0.6, 1.4, 0.25), (5.7, 1.0, DH_UPPER + 0.7), bevel=0.1, m=tmat("Cream")),
          box("Headboard", (0.2, 1.9, 1.4), (6.2, 1.0, DH_UPPER + 0.7), bevel=0.06, m=wood)]
    # Little framed pictures on the upper back wall.
    for k, x in enumerate((-4.5, -1.5, 3.0)):
        p += [box(f"Frame{k}", (1.2, 0.08, 0.9), (x, hd - t - 0.06, DH_UPPER + 2.2), bevel=0.03, m=tmat("Brass", rough=0.4)),
              box(f"Pic{k}", (1.0, 0.04, 0.7), (x, hd - t - 0.1, DH_UPPER + 2.2), bevel=0.0, m=tmat(("Green", "Blue", "Orange")[k], rough=0.7))]
    one("toy_dollhouse", p)


def train_loco():
    red, blue, yellow, ink, brass = tmat("Red", rough=0.4), tmat("Blue", rough=0.4), tmat("Yellow", rough=0.4), tmat("Ink"), tmat("Brass", rough=0.3, metal=0.5)
    p = [box("Chassis", (1.8, 4.4, 0.35), (0, 0, 0.55), bevel=0.08, m=ink),
         cyl("Boiler", 0.8, 2.6, (0, -0.8, 1.55), rot=(math.pi / 2, 0, 0), segs=18, bevel=0.08, m=blue),
         cyl("Smokebox", 0.84, 0.3, (0, -2.05, 1.55), rot=(math.pi / 2, 0, 0), segs=18, bevel=0.06, m=ink),
         cyl("Funnel", 0.32, 1.0, (0, -1.6, 2.6), segs=12, bevel=0.04, m=ink, radius_top=0.45),
         cyl("FunnelRim", 0.48, 0.14, (0, -1.6, 3.1), segs=12, bevel=0.03, m=brass),
         sphere("Dome", 0.36, (0, -0.6, 2.35), m=brass, segs=12, rings=7),
         box("Cab", (1.9, 1.6, 2.0), (0, 1.3, 1.85), bevel=0.1, m=red),
         box("CabRoof", (2.2, 1.9, 0.2), (0, 1.3, 2.95), bevel=0.06, m=yellow),
         box("Cowcatcher", (1.6, 0.5, 0.4), (0, -2.35, 0.45), rot=(math.radians(-25), 0, 0), bevel=0.05, m=red),
         sphere("Lamp", 0.2, (0, -2.25, 2.0), m=tglow("ToyTrainLamp", "#ffe6a0", 3.0), segs=10, rings=6)]
    for s in (-1, 1):
        p.append(box(f"CabWin{s}", (0.06, 0.8, 0.7), (s * 0.96, 1.3, 2.2), bevel=0.02, m=tglow("ToyTrainWindow", "#ffd27a", 1.6)))
        for k, y in enumerate((-1.6, -0.5, 0.6, 1.6)):
            big = k >= 2
            r = 0.55 if big else 0.42
            p.append(cyl(f"Wheel{s}{k}", r, 0.18, (s * 0.85, y, r), rot=(0, math.pi / 2, 0), segs=16, bevel=0.04, m=red if big else yellow))
            p.append(cyl(f"Hub{s}{k}", r * 0.35, 0.2, (s * 0.86, y, r), rot=(0, math.pi / 2, 0), segs=10, bevel=0.02, m=brass))
        p.append(box(f"Rod{s}", (0.06, 2.3, 0.12), (s * 0.97, 0.05, 0.5), bevel=0.02, m=brass))
    one("toy_train_loco", p)


def train_car(variant):
    ink, yellow, brass = tmat("Ink"), tmat("Yellow", rough=0.4), tmat("Brass", rough=0.3, metal=0.5)
    body_c = tmat("Green", rough=0.45) if variant == "a" else tmat("Red", rough=0.45)
    p = [box("Chassis", (1.7, 3.8, 0.3), (0, 0, 0.55), bevel=0.08, m=ink)]
    if variant == "a":
        p += [box("Tub", (1.9, 3.4, 1.0), (0, 0, 1.2), bevel=0.1, m=body_c),
              box("TubRim", (2.0, 3.5, 0.12), (0, 0, 1.72), bevel=0.04, m=yellow)]
        cols = ["Red", "Blue", "Yellow"]
        for k in range(3):
            p += letter_block(f"Cargo{k}", 0.85, cols[k], loc=(-0.45 + (k % 2) * 0.9, -1.0 + k * 1.0, 1.35), letters="ABC")
    else:
        p += [box("Coach", (1.9, 3.5, 1.8), (0, 0, 1.6), bevel=0.1, m=body_c),
              box("Roof", (2.1, 3.7, 0.22), (0, 0, 2.6), bevel=0.08, m=tmat("Blue", rough=0.4)),
              box("Band", (1.95, 3.55, 0.14), (0, 0, 1.0), bevel=0.03, m=yellow)]
        for s in (-1, 1):
            for k in range(3):
                p.append(box(f"Win{s}{k}", (0.06, 0.7, 0.7), (s * 0.95, -1.1 + k * 1.1, 1.85), bevel=0.02, m=tglow("ToyTrainWindow", "#ffd27a", 1.6)))
    for s in (-1, 1):
        for y in (-1.2, 1.2):
            p.append(cyl(f"Wheel{s}{y}", 0.42, 0.18, (s * 0.8, y, 0.42), rot=(0, math.pi / 2, 0), segs=14, bevel=0.04, m=yellow))
            p.append(cyl(f"Hub{s}{y}", 0.15, 0.2, (s * 0.81, y, 0.42), rot=(0, math.pi / 2, 0), segs=8, bevel=0.02, m=brass))
    p.append(cyl("Coupler", 0.12, 0.6, (0, 2.05, 0.55), rot=(math.pi / 2, 0, 0), segs=8, bevel=0.02, m=brass))
    one("toy_train_car_" + variant, p)


def track():
    """2 m of elevated track along X: girder (blue), sleepers, two rails. Top of rail at z 0."""
    p = [box("Girder", (2.02, 2.4, 0.5), (0, 0, -0.55), bevel=0.06, m=tmat("Blue", rough=0.5)),
         box("GirderLip", (2.02, 2.6, 0.12), (0, 0, -0.26), bevel=0.03, m=tmat("Yellow", rough=0.5))]
    for k in range(3):
        p.append(box(f"Sleeper{k}", (0.32, 2.2, 0.14), (-0.66 + k * 0.66, 0, -0.17), bevel=0.03, m=tmat("WoodDark")))
    for s in (-1, 1):
        p.append(box(f"Rail{s}", (2.02, 0.14, 0.16), (0, s * 0.72, -0.05), bevel=0.02, m=tmat("Tin", rough=0.3, metal=0.6)))
    one("toy_track", p)


def pier():
    cols = ["Red", "Yellow", "Blue", "Green"]
    p = []
    for k in range(4):
        p += letter_block(f"P{k}", 1.35, cols[k], loc=(0, 0, k * 1.35), letters=("A", "B", "C", "D"))
    p.append(box("Cap", (1.8, 1.8, 0.2), (0, 0, 5.5), bevel=0.06, m=tmat("Brass", rough=0.4)))
    one("toy_pier", p)


def teddy():
    fur, light, ink = tmat("Plush", rough=0.95), tmat("PlushLight", rough=0.95), tmat("Ink", rough=0.3)
    p = [sphere("Body", 2.0, (0, 0, 2.2), scale=(1, 0.9, 1.1), m=fur, segs=20, rings=12),
         sphere("Belly", 1.3, (0, -0.95, 2.0), scale=(1, 0.5, 1.1), m=light, segs=16, rings=10),
         sphere("Head", 1.55, (0, -0.2, 5.0), m=fur, segs=20, rings=12),
         sphere("Muzzle", 0.7, (0, -1.5, 4.7), scale=(1, 0.7, 0.8), m=light, segs=14, rings=8),
         sphere("Nose", 0.24, (0, -1.98, 4.9), scale=(1.2, 0.8, 0.8), m=ink, segs=10, rings=6),
         cyl("Ribbon", 1.1, 0.4, (0, -0.1, 3.75), segs=18, bevel=0.1, m=tmat("Red", rough=0.6))]
    for s in (-1, 1):
        p += [sphere(f"Ear{s}", 0.6, (s * 1.2, -0.1, 6.3), scale=(1, 0.6, 1), m=fur, segs=12, rings=8),
              sphere(f"EarIn{s}", 0.36, (s * 1.2, -0.42, 6.25), scale=(1, 0.4, 1), m=light, segs=10, rings=6),
              sphere(f"Eye{s}", 0.2, (s * 0.55, -1.38, 5.4), m=ink, segs=10, rings=6),
              sphere(f"Arm{s}", 0.75, (s * 1.9, -0.6, 2.8), scale=(0.8, 0.8, 1.6), rot=(0.4, s * 0.5, 0), m=fur, segs=12, rings=8),
              sphere(f"Leg{s}", 0.95, (s * 1.1, -1.4, 0.9), scale=(0.9, 1.6, 0.9), m=fur, segs=12, rings=8),
              sphere(f"Pad{s}", 0.6, (s * 1.1, -2.85, 0.95), scale=(1, 0.3, 1), m=light, segs=10, rings=6)]
    p.append(prism("Bow", [(-0.6, -0.4), (0, 0), (-0.6, 0.4), (0.6, 0.4), (0, 0), (0.6, -0.4)], 0.2, (0, -1.2, 3.8), m=tmat("Red", rough=0.6)))
    one("toy_teddy", p)


def robot():
    tin, dark, red, yellow = tmat("Tin", rough=0.3, metal=0.6), tmat("TinDark", rough=0.4, metal=0.5), tmat("Red", rough=0.4), tmat("Yellow", rough=0.4)
    eye = tglow("ToyRobotEye", "#ffcf4a", 2.5)
    p = [box("Legs", (2.6, 1.6, 2.2), (0, 0, 1.1), bevel=0.12, m=dark),
         box("Torso", (3.2, 2.2, 2.8), (0, 0, 3.6), bevel=0.18, m=tin),
         box("Chest", (2.0, 0.1, 1.4), (0, -1.12, 3.8), bevel=0.05, m=red),
         box("Head", (2.2, 1.9, 1.7), (0, 0, 6.0), bevel=0.2, m=tin),
         box("Mouth", (1.2, 0.1, 0.3), (0, -0.98, 5.55), bevel=0.04, m=dark),
         cyl("Antenna", 0.08, 1.0, (0, 0, 7.3), segs=8, bevel=0.0, m=dark),
         sphere("AntennaBall", 0.22, (0, 0, 7.85), m=tglow("ToyRobotBulb", "#ff5a4a", 3.0), segs=10, rings=6)]
    for k in range(3):
        p.append(cyl(f"Dial{k}", 0.2, 0.1, (-0.6 + k * 0.6, -1.18, 3.9), rot=(math.pi / 2, 0, 0), segs=12, bevel=0.02, m=yellow))
    for s in (-1, 1):
        p += [cyl(f"Eye{s}", 0.3, 0.12, (s * 0.5, -0.98, 6.25), rot=(math.pi / 2, 0, 0), segs=14, bevel=0.02, m=eye),
              cyl(f"Ear{s}", 0.35, 0.25, (s * 1.2, 0, 6.0), rot=(0, math.pi / 2, 0), segs=12, bevel=0.04, m=red),
              box(f"Arm{s}", (0.7, 0.7, 2.4), (s * 2.0, -0.1, 3.4), bevel=0.15, m=dark),
              torus(f"Claw{s}", 0.35, 0.12, (s * 2.0, -0.1, 2.0), rot=(math.pi / 2, 0, 0), m=red, major_segs=14, minor_segs=5),
              box(f"Foot{s}", (1.2, 2.0, 0.4), (s * 0.7, -0.3, 0.2), bevel=0.1, m=red)]
    one("toy_robot", p)


def rocket():
    red, white, blue, tin = tmat("Red", rough=0.35), tmat("White", rough=0.4), tmat("Blue", rough=0.4), tmat("Tin", rough=0.3, metal=0.6)
    p = [lathe("Hull", [(0.01, 1.0), (1.2, 1.2), (1.5, 2.5), (1.55, 5.0), (1.2, 7.0), (0.6, 8.4), (0.01, 9.2)], [white, red], segs=20, stripes=None),
         cyl("Nozzle", 0.8, 1.0, (0, 0, 0.7), segs=16, bevel=0.04, m=tin, radius_top=1.1)]
    for k in range(3):
        a = math.tau * k / 3
        p.append(prism(f"Fin{k}", [(0, 0), (1.6, -0.4), (1.6, 0.6), (0, 3.0)], 0.2, (math.cos(a) * 1.3, math.sin(a) * 1.3, 0.6), rot=(0, 0, a), m=blue))
    for k in range(2):
        p.append(cyl(f"Port{k}", 0.4, 0.15, (0, -1.5, 4.0 + k * 1.4), rot=(math.pi / 2, 0, 0), segs=14, bevel=0.03, m=tmat("BlueLight", rough=0.2)))
    one("toy_rocket", p)


def drum():
    red, white, brass = tmat("Red", rough=0.45), tmat("White", rough=0.6), tmat("Brass", rough=0.3, metal=0.5)
    p = [cyl("Shell", 2.0, 2.6, (0, 0, 1.3), segs=24, bevel=0.06, m=red),
         cyl("Skin", 2.05, 0.08, (0, 0, 2.62), segs=24, bevel=0.02, m=white)]
    for z in (0.12, 2.5):
        p.append(torus(f"Hoop{z}", 2.06, 0.12, (0, 0, z), m=tmat("Blue", rough=0.4), major_segs=28, minor_segs=6))
    pts = []
    for k in range(13):
        a = math.tau * k / 12
        pts.append((math.cos(a) * 2.04, math.sin(a) * 2.04, 0.2 if k % 2 == 0 else 2.42))
    p.append(tube("Cord", pts, 0.05, m=brass, segs=5))
    for s in (-1, 1):
        p.append(cyl(f"Stick{s}", 0.07, 3.0, (s * 0.7, 0.3, 2.75), rot=(0, math.radians(s * 80), 0.4), segs=8, bevel=0.0, m=tmat("WoodLight")))
    one("toy_drum", p)


def shelf():
    """A 16 m bay of wall shelving, open front -Y, boards at 7, 15, 23, 31 m."""
    W, D, H = 16.0, 5.0, 36.0
    paint, board, back = tmat("Cream", rough=0.6), tmat("WoodLight", rough=0.6), tmat("BlueDark", rough=0.8)
    p = [box("Back", (W, 0.3, H), (0, D / 2 - 0.15, H / 2), bevel=0.0, m=back)]
    for s in (-1, 1):
        p.append(box(f"Upright{s}", (0.6, D, H), (s * (W / 2 - 0.3), 0, H / 2), bevel=0.1, m=paint))
    for z in (7.0, 15.0, 23.0, 31.0):
        p.append(box(f"Board{z}", (W, D, 0.5), (0, 0, z), bevel=0.08, m=board))
        p.append(box(f"Lip{z}", (W, 0.2, 0.7), (0, -D / 2 + 0.1, z - 0.05), bevel=0.06, m=paint))
    p.append(box("Top", (W + 0.4, D + 0.4, 0.6), (0, 0, H), bevel=0.1, m=paint))
    p.append(box("Plinth", (W, 0.4, 1.0), (0, D / 2 - 0.5, 0.5), bevel=0.06, m=paint))
    one("toy_shelf", p)


def pendant():
    shade = tmat("Green", rough=0.4)
    inner = tglow("ToyLampInner", "#ffe2a8", 1.4)
    bulb_m = tglow("ToyLampBulb", "#fff0c8", 6.0)
    p = [lathe("Shade", [(3.0, 0.0), (2.4, 0.8), (1.0, 2.2), (0.35, 2.6)], [shade], segs=24, stripes=None, cap_bottom=False, cap_top=True),
         lathe("Lining", [(2.92, 0.04), (2.32, 0.82), (0.95, 2.15)], [inner], segs=24, stripes=None, cap_bottom=False, cap_top=False),
         sphere("Bulb", 0.6, (0, 0, 0.5), m=bulb_m, segs=12, rings=8),
         cyl("Cord", 0.08, 30.0, (0, 0, 17.6), segs=6, bevel=0.0, m=tmat("Ink")),
         torus("Rim", 3.0, 0.08, (0, 0, 0.0), m=tmat("Brass", rough=0.3, metal=0.5), major_segs=28, minor_segs=5)]
    double_sided(p[0])
    double_sided(p[1])
    one("toy_pendant", p)


def street_lamp():
    iron = tmat("Ink", rough=0.5)
    glass = tglow("ToyStreetGlow", "#ffd88a", 4.0)
    p = [cyl("Post", 0.18, 7.0, (0, 0, 3.5), segs=10, bevel=0.03, m=iron),
         cyl("Foot", 0.4, 0.8, (0, 0, 0.4), segs=10, bevel=0.05, m=iron),
         box("Lantern", (0.8, 0.8, 1.1), (0, 0, 7.6), bevel=0.05, m=glass),
         cyl("Cap", 0.65, 0.4, (0, 0, 8.35), segs=4, bevel=0.03, m=iron, radius_top=0.1)]
    one("toy_street_lamp", p)


def exit_star():
    glow_m = mat("ToyExitGlow", "#ffd86a", rough=0.35, emit=1.0)
    p = letter_block("E", 0.7, "Blue", letters="EXIT")
    p.append(cyl("Stem", 0.06, 0.5, (0, 0, 0.95), segs=6, bevel=0.0, m=tmat("Brass", rough=0.3, metal=0.5)))
    p.append(star("Star", 0.42, 0.16, (0, 0, 1.5), m=glow_m, inner=0.2))
    one("toy_exit_star", p)


ALL = {
    "blocks": lambda: [block(c) for c in PRIMARIES],
    "books": lambda: [book(c) for c in ("Red", "Blue", "Green", "Yellow")],
    "gameboxes": lambda: [gamebox(v) for v in ("a", "b")],
    "crayon_box": crayon_box,
    "crayon": crayon_lying,
    "ballpit": ballpit,
    "cars": lambda: [car(c) for c in ("Red", "Blue")],
    "racetrack": racetrack,
    "jack": lambda: (jack_box(), jack_pop()),
    "dollhouse": dollhouse,
    "train": lambda: (train_loco(), train_car("a"), train_car("b"), track(), pier()),
    "scenery": lambda: (teddy(), robot(), rocket(), drum(), shelf(), pendant(), street_lamp()),
    "exit": exit_star,
}


if __name__ == "__main__":
    wanted = sys.argv[1:] or list(ALL)
    reset_scene()
    for key in wanted:
        ALL[key]()
