"""First-person viewmodel of the Strike Zone (update 13 primary, player level
38): a glossy bowling-alley launcher. A violet body with a maple lane deck on
top (board lines and three glowing lane arrows), a ball-return hood over the
chamber at the front with chase lights round its rim and a little bowling
pin for a front sight, a second ball-return hood on the left flank holding
the spare ball, and a pin-shaped vertical foregrip. Also writes the rolling
ball on its own (art/models/strike_zone_ball.glb, used by
scripts/weapons/strike_zone_ball.gd).

Same conventions and node contract as build_weapons.py (documented at the top
of weapon_kit.py): origin at the top of the grip, pointing along +Y, its own
palette (set before weapon_mats, so the shared material names stay and every
finish, cell, decal and charm works). The balls keep their own materials
(Ball*), so they read as bowling balls under any finish. Moving parts, driven
by scripts/weapons/views/strike_zone_view.gd and
scripts/weapons/reloads/strike_zone_reload.gd:

  Ball        the loaded ball in the chamber under the front hood (pivot at
              its centre, finger holes up and towards the player)
  Spare       the second ball of the magazine, in the side ball return
  Kicker      the pink kicker pad behind the chamber ball (pivot at the pad):
              it cocks back while the shot winds up and slams forward
  Arrow0..2   the three glowing lane arrows on the deck (the wind-up meter)
  Cell        the side ball return's glowing rails and cradle ring
  RailHolo    the reload's hologram ball-return rail, which curls up from
              under the gun and over into the chamber (RAIL_PATH, hidden)
  SpareHolo   the hologram spare ball that prints into the side return

RAIL_PATH (the ball's centre along the hologram rail) is copied in Godot axes
into strike_zone_reload.gd (Godot x, y, z = Blender x, z, -y).

    python art/blender/build_weapons_strike_zone.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403
from weapon_kit import _save  # noqa: E402
from wla_common import _finish  # noqa: E402

BALL_R = 0.05
BALL_C = (0.0, 0.258, 0.044)       # chamber ball centre
SPARE_C = (-0.106, 0.12, 0.03)     # spare ball centre (side ball return)
RAIL_TOP = 0.112
# The ball's centre along the hologram rail, from under the gun up the left
# flank and over the deck's front edge into the chamber.
RAIL_PATH = [(-0.12, 0.24, -0.28), (-0.16, 0.235, -0.16), (-0.165, 0.23, -0.04), (-0.135, 0.225, 0.07),
             (-0.07, 0.215, 0.14), (-0.015, 0.21, 0.13), (0.0, 0.245, 0.06), BALL_C]
# The hood over the chamber: a tunnel from HOOD_Y0 to HOOD_Y1 (relative to the ball).
HOOD_INNER = 0.06
HOOD_THICK = 0.008
HOOD_Y0 = 0.012
HOOD_Y1 = 0.084


def palette():
    """Alley Violet shell, Maple Lane trim, chrome steel, Pin Pink (weapon_mats reuses them)."""
    mat("Shell", "#5b37e8", rough=0.22)
    mat("Trim", "#f0b968", rough=0.34)
    mat("GunDark", "#1f1a38", rough=0.5, metal=0.2)
    mat("GunSteel", "#d3d6e8", rough=0.18, metal=0.8)
    mat("GunPink", "#ff3f9f", rough=0.28)


def ball_mats():
    """The balls' own glossy materials: hot pink marbled with violet and pearl."""
    return dict(
        shell=mat("BallShell", "#ff2f8a", rough=0.1, metal=0.05),
        swirl=mat("BallSwirl", "#7a3cff", rough=0.12, metal=0.05),
        pearl=mat("BallPearl", "#ffd6f2", rough=0.12),
        hole=mat("BallHole", "#160f24", rough=0.7),
    )


def marbled_ball(name, radius, centre, B, segs=36, rings=22):
    """A bowling ball: a UV sphere whose faces are split into a pink shell and
    violet and pearl marbling bands, plus three finger holes on its +Z side,
    leaning back towards -Y (the player)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    for f in bm.faces:
        n = f.calc_center_median().normalized()
        a = math.atan2(n.y, n.x)
        s = math.sin(4.2 * n.z + 2.4 * math.sin(3.0 * a + 1.3 * n.z) + 0.8 * math.sin(5.0 * a))
        f.material_index = 1 if s > 0.62 else (2 if s < -0.86 else 0)
    ob = _finish(name, bm, B["shell"], centre, (0, 0, 0))
    ob.data.materials.append(B["swirl"])
    ob.data.materials.append(B["pearl"])
    parts = [ob]
    # Thumb hole nearest the player, two finger holes beyond it.
    for i, (u, v, r) in enumerate(((0.0, -0.36, 0.0115), (-0.2, 0.08, 0.0095), (0.2, 0.08, 0.0095))):
        n = Vector((u, v, 1.0)).normalized()
        n = Matrix.Rotation(math.radians(-28), 3, "X") @ n
        at = Vector(centre) + n * radius * 0.93
        hole = cyl(f"{name}Hole{i}", r * radius / 0.05, 0.008 * radius / 0.05, tuple(at), segs=14, bevel=0.0, m=B["hole"])
        hole.rotation_euler = n.to_track_quat("Z", "Y").to_euler()
        parts.append(hole)
    return parts


def arch(name, inner, thick, y0, y1, centre, m, spread=200.0, segs=28):
    """A tunnel-shaped hood: part of a tube round the axis through `centre`
    along Y (from y0 to y1, relative), arching `spread` degrees over the top,
    `thick` thick outward (a ball-return hood the ball rolls out of)."""
    bm = bmesh.new()
    a0 = math.radians(90.0 - spread / 2)
    rows = []
    for y in (y0, y1):
        row = []
        for i in range(segs + 1):
            a = a0 + math.radians(spread) * i / segs
            row.append(bm.verts.new((math.cos(a) * inner, y, math.sin(a) * inner)))
        rows.append(row)
    for i in range(segs):
        bm.faces.new((rows[0][i], rows[0][i + 1], rows[1][i + 1], rows[1][i]))
    ob = _finish(name, bm, m, centre, (0, 0, 0))
    sol = ob.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 1.0
    return ob


def pin(prefix, base, height, white, stripe, dot=None):
    """A little bowling pin standing on `base`: a fat belly, a slim neck with
    two stripes and a round head (optionally a glowing dot on its back)."""
    x, y, z = base
    k = height / 0.03
    parts = [
        cyl(prefix + "Foot", 0.0045 * k, 0.003 * k, (x, y, z + 0.0015 * k), segs=14, bevel=0.0008 * k, m=white, radius_top=0.0062 * k),
        sphere(prefix + "Belly", 0.0068 * k, (x, y, z + 0.009 * k), scale=(1, 1, 1.25), m=white, segs=14, rings=10),
        cyl(prefix + "Neck", 0.0036 * k, 0.009 * k, (x, y, z + 0.019 * k), segs=12, bevel=0.0, m=white, radius_top=0.0029 * k),
        cyl(prefix + "Stripe0", 0.0039 * k, 0.0014 * k, (x, y, z + 0.0175 * k), segs=12, bevel=0.0, m=stripe),
        cyl(prefix + "Stripe1", 0.0035 * k, 0.0014 * k, (x, y, z + 0.0205 * k), segs=12, bevel=0.0, m=stripe),
        sphere(prefix + "Head", 0.0043 * k, (x, y, z + 0.0255 * k), scale=(1, 1, 1.1), m=white, segs=12, rings=8),
    ]
    if dot is not None:
        parts.append(sphere(prefix + "Dot", 0.0024 * k, (x, y - 0.0038 * k, z + 0.0262 * k), m=dot, segs=8, rings=5))
    return parts


def lane_arrow(name, centre, size, m):
    """A flat triangular lane arrow pointing forward (+Y), lying on the deck."""
    return cyl(name, size, 0.003, centre, rot=(0, 0, math.pi / 2), segs=3, bevel=0.0, m=m)


def build_strike_zone():
    reset_scene()
    palette()
    M = weapon_mats("#38f2ff", emit=2.0)
    B = ball_mats()
    white = mat("PinWhite", "#f6f2ea", rough=0.3)
    chrome = M["steel"]
    grip_loc = (0, -0.03, -0.115)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.07, 0.092, 0.19), body_bottom=-0.02)
    z_line = RAIL_TOP + SIGHT_HEIGHT
    bx, by, bz = BALL_C
    sx, sy, sz = SPARE_C
    fore = (0, 0.236, -0.088)
    deck_z = 0.075

    shell = grip_parts + [
        # The body: glossy violet, a hot-pink belt line and a dark sill with gutter channels.
        box("Body", (0.104, 0.3, 0.09), (0, 0.045, 0.025), bevel=0.03, segs=3, m=M["shell"]),
        box("BeltLine", (0.108, 0.27, 0.012), (0, 0.04, 0.034), bevel=0.004, m=M["pink"]),
        box("Sill", (0.1, 0.26, 0.016), (0, 0.045, -0.014), bevel=0.006, m=M["dark"]),
        # The lane deck: maple boards with dark seams, a foul line at the back.
        box("Deck", (0.084, 0.27, 0.01), (0, 0.05, deck_z), bevel=0.003, m=M["trim"]),
        box("FoulLine", (0.086, 0.006, 0.0025), (0, -0.075, deck_z + 0.005), bevel=0.0, m=M["pink"]),
        # The chamber: a chin under the ball with a bumper and two guide rails.
        box("Chin", (0.104, 0.15, 0.028), (0, 0.262, -0.02), bevel=0.01, m=M["shell"]),
        box("ChinBumper", (0.11, 0.014, 0.02), (0, 0.338, -0.016), bevel=0.007, m=M["pink"]),
        box("ChamberNeck", (0.09, 0.03, 0.03), (0, 0.205, -0.015), bevel=0.008, m=M["shell"]),
        cyl("KickerPort", 0.027, 0.006, (0, 0.196, bz), rot=rad(90, 0, 0), segs=24, bevel=0.0015, m=M["dark"]),
        box("RailRiser", (0.03, 0.15, 0.018), (0, 0.0, 0.088), bevel=0.004, m=M["dark"]),
        # Rear stock: a padded ball-return block with a dark butt.
        box("Stock", (0.072, 0.11, 0.07), (0, -0.15, 0.02), bevel=0.026, segs=3, m=M["shell"]),
        box("StockBand", (0.076, 0.016, 0.074), (0, -0.13, 0.02), bevel=0.006, m=M["pink"]),
        box("Butt", (0.07, 0.022, 0.072), (0, -0.21, 0.02), bevel=0.012, m=M["dark"]),
        box("ForegripMount", (0.05, 0.06, 0.012), (0, fore[1], -0.036), bevel=0.004, m=M["dark"]),
    ]
    for i in range(5):
        shell.append(box(f"Seam{i}", (0.0012, 0.27, 0.0016), (-0.0336 + i * 0.0168, 0.05, deck_z + 0.005), bevel=0.0, m=M["dark"]))
    # Steel guide rails the chamber ball sits on.
    for side in (-1, 1):
        shell.append(ycyl(f"GuideRail{side}", 0.0055, 0.13, 0.268, z=0.004, x=side * 0.034, m=chrome, segs=12, bevel=0.002))
        shell.append(box(f"HoodPost{side}", (0.012, 0.05, 0.05), (side * 0.066, 0.31, 0.01), bevel=0.004, m=M["dark"]))
        # The body's gutters: dark channels down each flank.
        shell.append(box(f"Gutter{side}", (0.006, 0.24, 0.014), (side * 0.0525, 0.045, 0.01), bevel=0.003, m=M["dark"]))
    # The front hood: a violet tunnel the ball rolls out of, a pink rim
    # towards the player with chase lights, and a bowling pin front sight.
    shell.append(arch("Hood", HOOD_INNER, HOOD_THICK, HOOD_Y0, HOOD_Y1, BALL_C, M["shell"]))
    rim_r = HOOD_INNER + HOOD_THICK * 0.5
    for j, y in enumerate((HOOD_Y0, HOOD_Y1)):
        shell.append(torus(f"HoodRim{j}", rim_r, 0.0055, (bx, by + y, bz), rot=rad(90, 0, 0), m=M["pink"], major_segs=32, minor_segs=7,
                           arc=math.radians(200), start=math.radians(-10)))
    for i in range(7):
        a = math.pi * (0.06 + 0.88 * i / 6)
        shell.append(sphere(f"Chase{i}", 0.0042, (bx + math.cos(a) * rim_r, by + HOOD_Y0 - 0.006, bz + math.sin(a) * rim_r), m=M["cell"], segs=8, rings=5))
    shell.append(box("HoodBadge", (0.036, 0.004, 0.014), (0, by + HOOD_Y1 + 0.003, bz + 0.03), bevel=0.002, m=M["pink"]))
    # The side ball return on the left flank: a pink hood arching over the spare,
    # its chrome brackets.
    shell.append(torus("ReturnHood", 0.058, 0.009, (sx, sy + 0.05, sz), rot=rad(90, 0, 0), m=M["pink"], major_segs=28, minor_segs=7,
                       arc=math.pi * 1.1, start=-math.pi * 0.05))
    shell.append(box("ReturnHoodRoof", (0.11, 0.03, 0.01), (sx + 0.0, sy + 0.038, sz + 0.06), bevel=0.004, m=M["shell"]))
    for i, y in enumerate((sy - 0.045, sy + 0.045)):
        shell.append(box(f"ReturnBracket{i}", (0.03, 0.012, 0.012), (-0.065, y, sz - 0.036), bevel=0.003, m=chrome))
    # Lane arrows (the wind-up meter): three cyan chevron points on the deck.
    arrows = {}
    for i, (x, y) in enumerate(((-0.024, 0.128), (0.0, 0.152), (0.024, 0.128))):
        arrows[f"Arrow{i}"] = ([lane_arrow(f"Arrow{i}Tri", (x, y, deck_z + 0.0065), 0.0105, M["cell"])], (x, y, deck_z + 0.0065))
    # The vertical foregrip: rubber, with a bowling pin's head for a knob.
    shell += [
        box("Foregrip", (0.042, 0.05, 0.11), fore, bevel=0.016, m=M["dark"]),
        sphere("ForegripKnob", 0.027, (0, fore[1], fore[2] - 0.066), scale=(1, 1, 0.75), m=white, segs=16, rings=10),
        cyl("ForegripStripe", 0.0262, 0.006, (0, fore[1], fore[2] - 0.054), segs=20, bevel=0.0, m=M["pink"]),
    ]
    shell += top_rail("TopRail", -0.07, 0.07, RAIL_TOP, M, width=0.03)
    shell += bolts("Pin", [(-0.052, 0.17, 0.05), (0.052, 0.17, 0.05), (0.052, -0.08, 0.05)], chrome, radius=0.005, height=0.005)
    lug, charm_point = charm_lug(-0.036, -0.165, 0.004, M)
    shell += lug
    sight_rear, _front = sights_notch(0.0, -0.058, 0.0, RAIL_TOP, 0.0, z_line, M, gap=0.016)
    for ob in _front:
        bpy.data.objects.remove(ob, do_unlink=True)
    hood_top = bz + HOOD_INNER + HOOD_THICK
    sight_front = pin("FrontPin", (0, by + 0.05, hood_top - 0.003), z_line + 0.004 - hood_top, white, M["pink"], dot=M["cell"])

    ball = marbled_ball("BallCore", BALL_R, BALL_C, B)
    spare = marbled_ball("SpareCore", BALL_R, SPARE_C, B)
    spare_holo = holo_copy([spare[0]])

    kicker = [
        ycyl("KickerPad", 0.022, 0.012, 0.2, z=bz, m=M["pink"], segs=22, bevel=0.004),
        ycyl("KickerFace", 0.016, 0.004, 0.2075, z=bz, m=M["cell"], segs=18, bevel=0.0012),
        ycyl("KickerRod", 0.006, 0.06, 0.167, z=bz, m=chrome, segs=10, bevel=0.001),
    ]
    # The side return's glowing rails, end stop and cradle ring.
    cell = [
        ycyl("ReturnRailL", 0.0045, 0.12, sy, z=sz - 0.04, x=sx - 0.024, m=M["cell"], segs=10, bevel=0.001),
        ycyl("ReturnRailR", 0.0045, 0.12, sy, z=sz - 0.04, x=sx + 0.024, m=M["cell"], segs=10, bevel=0.001),
        box("ReturnStop", (0.056, 0.008, 0.016), (sx, sy + 0.064, sz - 0.032), bevel=0.003, m=M["dark"]),
        box("ReturnSled", (0.056, 0.12, 0.006), (sx, sy, sz - 0.047), bevel=0.002, m=M["dark"]),
    ]
    # The hologram rail: two rails the ball rides on, under its centre path.
    rail_l, rail_r = [], []
    for i, p in enumerate(RAIL_PATH):
        q = Vector(p)
        nxt = Vector(RAIL_PATH[min(i + 1, len(RAIL_PATH) - 1)]) - Vector(RAIL_PATH[max(i - 1, 0)])
        side = nxt.cross(Vector((0, 0, 1)))
        side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
        down = nxt.cross(side).normalized()
        if down.z > 0:
            down = -down
        base = q + down * (BALL_R * 0.72)
        rail_l.append(tuple(base - side * 0.026))
        rail_r.append(tuple(base + side * 0.026))
    rail = [tube("RailL", rail_l[:-1], 0.0045, m=M["holo"], segs=8), tube("RailR", rail_r[:-1], 0.0045, m=M["holo"], segs=8)]
    for i in range(1, len(rail_l) - 1):
        rail.append(tube(f"RailTie{i}", [rail_l[i], rail_r[i]], 0.003, m=M["holo"], segs=6))

    bowl = [(-0.012, 0.02), (0.012, 0.02), (0.016, 0.006), (0.009, -0.004), (0.012, -0.02), (-0.012, -0.02),
            (-0.009, -0.004), (-0.016, 0.006)]
    decal = [side_emblem("Emblem", bowl, -0.074, -0.15, 0.024, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = vertical_hand(fore, 0.021, 0.025, 0.11, M, (-0.52, -0.16, -0.46))
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.058, RAIL_TOP), None),
        "IronSightFront": (sight_front, (0, by + 0.05, hood_top), None),
        "Ball": (ball, BALL_C, None),
        "Spare": (spare, SPARE_C, None),
        "SpareHolo": (spare_holo, SPARE_C, None),
        "Kicker": (kicker, (0, 0.2, bz), None),
        "Cell": (cell, SPARE_C, None),
        "RailHolo": (rail, (0, 0.23, -0.106), None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    for name, (parts, centre) in arrows.items():
        groups[name] = (parts, centre, None)
    empties = {
        "Muzzle": ((0, 0.35, 0.044), None),
        "SightPoint": ((0, -0.058, z_line), None),
        "SightMount": ((0, 0.0, RAIL_TOP), None),
        "EjectPoint": ((sx, sy, sz - 0.05), None),
        "VentPoint": ((0, by + 0.05, bz + 0.07), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("strike_zone", groups, empties)


def build_rolling_ball():
    """The ball in play: radius 0.25 m (WeaponData.projectile_size), finger holes on +Z."""
    reset_scene()
    B = ball_mats()
    parts = marbled_ball("BallCore", 0.25, (0, 0, 0), B, segs=40, rings=24)
    ball = merge("Ball", parts)
    _save("strike_zone_ball", [ball])


BUILDERS = (
    ("strike_zone", build_strike_zone),
    ("strike_zone_ball", build_rolling_ball),
)

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for name, fn in BUILDERS:
        if not only or name in only:
            fn()
