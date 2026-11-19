"""First-person model of the Ticket Flipper (ticket_flipper), the melee-slot
butterfly knife, built like a premium channel-construction balisong in the
prize-ticket colours: cherry liners skeletonized with windows that show
ticket-stripe inlays (cream on the safe handle, plum on the bite handle),
a cream spacer down each back punched with a perforation row, brass rivets,
gold bolsters round the pivots with glowing washers and star-socket pin
heads, zen-pin heads by the pivots, a gold T-latch with a star cap and its
coil spring, and a clip-point blade: satin flats, a mirror primary grind and
swedge, a fuller with a pink ticket stripe, a perforated spine, a star punched through the tang, a
choil and kicker, and a neon (Cell) edge.

Melee contract (melee_kit.py): origin at the centre of the fist on the
closed-up handles, the blade along +Y with its edge down (-Z). The handles
are channels open towards each other: open, they meet in a solid bar; shut,
the blade lies in their channels. Their pins are crossed (the held handle's
pin is above the seam, the free handle's below), so a 180 degree turn of each
handle about its own pin swaps them over without either one cutting the
other. Nothing rises over the top face of the bar but the free handle (the
thumb lies along the right-hand top edge), so flips go over the top.

  HandleA   the held ("safe") handle (underneath; pivot on its pin, axis X)
  Blade     child of HandleA, pivot on HandleA's pin (axis X): Blade.x 180
            folds it back into the channels
  HandleB   child of Blade, pivot on its own pin (axis X): the free ("bite")
            handle. Shut relative to the blade at HandleB.x -180 (with Blade.x 180)
  Latch     child of HandleA, pivot on its pin at the butt (axis X): the
            gold T-latch that clips over HandleB's butt; turn it -150 to free B
  ArmR      the fist round both handles (ElbowR)
  Cell      not a separate node: the neon edge, the washers and the latch
            star's heart use the "Cell" material (tinted by an equipped cell)

Empties: Muzzle and BladeTip (the point), SwingPoint (middle of the edge) on the Blade,
CharmPoint (a lug on HandleA's butt, left side).

    python art/blender/build_weapons_ticket_flipper.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from melee_kit import *  # noqa: F401,F403

## Handles: half thickness (X), each handle's height (Z), the open seam, wall thicknesses.
HALF_T = 0.0118
HANDLE_H = 0.0205
SEAM = 0.0004
WALL_X = 0.0032
WALL_Z = 0.0034
## The bar the fist wraps (half height).
BAR_B = SEAM + HANDLE_H
## Pivot line (front of the handles) and the butt.
PIV_Y = 0.088
BUTT_Y = -0.09
## The liners stop this far short of the pivot line, so a handle's front
## corner clears the other handle's pin as it turns about its own.
NOSE = 0.0086
## Crossed pins: HandleA's above the seam, HandleB's below.
PIN_P = 0.0028
## Blade: half thickness, the point.
BLADE_HALF = 0.0025
BLADE_TIP_Y = 0.236
## Everything but the fist is drawn at real size and then scaled up by this
## much, so the knife reads in the big first-person glove.
SCALE = 1.25


def palette():
    """The shared weapon materials in this weapon's colours (weapon_mats reuses them)."""
    mat("Shell", "#ff2d63", rough=0.3)
    mat("Trim", "#fff1cf", rough=0.42)
    mat("GunDark", "#25183a", rough=0.5, metal=0.15)
    mat("GunSteel", "#ffbf3a", rough=0.24, metal=0.65)
    mat("GunPink", "#ff7ab8", rough=0.36)


def cut(ob, cutters):
    """Boolean the `cutters` out of `ob`, before its bevel (the cutters stay in the source scene)."""
    for c in cutters:
        md = ob.modifiers.new("Cut", "BOOLEAN")
        md.operation = "DIFFERENCE"
        md.solver = "EXACT"
        md.object = c
        ob.modifiers.move(len(ob.modifiers) - 1, 0)
    return ob


def stadium(y0, y1, zc, h, steps=6):
    """A side outline (y, z) of a slot with round ends."""
    r = h / 2
    pts = []
    for i in range(steps + 1):
        a = -math.pi / 2 + math.pi * i / steps
        pts.append((y1 - r + math.cos(a) * r, zc + math.sin(a) * r))
    for i in range(steps + 1):
        a = math.pi / 2 + math.pi * i / steps
        pts.append((y0 + r + math.cos(a) * r, zc + math.sin(a) * r))
    return pts


def slab(name, outline, x0, x1, m, bevel=0.0):
    """A side outline extruded across X from x0 to x1."""
    return side_profile(name, outline, abs(x1 - x0), ((x0 + x1) / 2, 0, 0), m, bevel=bevel)


def ticket_handle(prefix, z_lo, z_hi, back_at_top, inlay_m, stripe_m, M):
    """One channel handle between heights z_lo..z_hi (open towards the seam):
    two skeletonized liners with ticket-stripe inlays in their windows, brass
    rivets, a perforated spacer down its back, a gold butt plate."""
    h = z_hi - z_lo
    zc = (z_lo + z_hi) / 2
    y0, y1 = BUTT_Y, PIV_Y - NOSE
    c = 0.0032
    liner = [(y0 + c, z_lo), (y1 - c, z_lo), (y1, z_lo + c), (y1, z_hi - c), (y1 - c, z_hi), (y0 + c, z_hi), (y0, z_hi - c), (y0, z_lo + c)]
    windows = [(y0 + 0.017, y0 + 0.094), (y0 + 0.103, y1 - 0.016)]
    win_h = h * 0.5
    parts = []
    for side in (-1, 1):
        xo = side * HALF_T
        xi = side * (HALF_T - WALL_X)
        wall = slab(f"{prefix}Liner{side}", liner, xi, xo, M["shell"], bevel=0.0009)
        cutters = []
        for i, (wy0, wy1) in enumerate(windows):
            cutters.append(slab(f"{prefix}Win{side}{i}", stadium(wy0, wy1, zc, win_h), side * (HALF_T - 0.0013), side * (HALF_T + 0.002), M["dark"]))
            # The inlay floor of the window: a ticket strip with a stripe down it.
            inlay_x = side * (HALF_T - 0.0013)
            parts.append(slab(f"{prefix}Inlay{side}{i}", stadium(wy0 + 0.0004, wy1 - 0.0004, zc, win_h - 0.0008), inlay_x, inlay_x + side * 0.0005,
                              inlay_m))
            parts.append(slab(f"{prefix}Stripe{side}{i}", stadium(wy0 + 0.0035, wy1 - 0.0035, zc, win_h * 0.28), inlay_x + side * 0.0004,
                              inlay_x + side * 0.0007, stripe_m))
        cut(wall, cutters)
        parts.append(wall)
        # Brass rivets of the channel construction (the front ones are on HandleA's bolsters).
        for k, y in enumerate((y0 + 0.012, (windows[0][1] + windows[1][0]) / 2)):
            parts.append(sphere(f"{prefix}Rivet{side}{k}", 0.0021, (xo, y, zc), scale=(0.5, 1, 1), m=M["steel"], segs=12, rings=6))
        # A gold star stamped on the short window's inlay.
        parts.append(star(f"{prefix}Stamp{side}", win_h * 0.36, 0.0007, (side * (HALF_T - 0.0006), (windows[1][0] + windows[1][1]) / 2, zc),
                          rot=rad(0, 0, -90 * side), m=M["steel"], inner=win_h * 0.16))
    # The spacer down the back, punched with a perforation row.
    zb = z_hi - WALL_Z / 2 if back_at_top else z_lo + WALL_Z / 2
    face = z_hi if back_at_top else z_lo
    length = y1 - y0 - 0.006
    yc = (y0 + y1) / 2 + 0.001
    parts.append(box(prefix + "Spacer", ((HALF_T - WALL_X) * 2 + 0.0008, length, WALL_Z), (0, yc, zb), bevel=0.0009, m=M["trim"]))
    n = 17
    for k in range(n):
        y = y0 + 0.012 + (length - 0.016) * k / (n - 1)
        parts.append(cyl(f"{prefix}Perf{k}", 0.0011, 0.001, (0, y, face), segs=10, bevel=0.0, m=M["dark"]))
    # The butt: a solid block in the channel and a gold plate on its end.
    parts.append(box(prefix + "Butt", ((HALF_T - WALL_X) * 2 + 0.0008, 0.011, h - 0.0008), (0, y0 + 0.0065, zc), bevel=0.0012, m=M["shell"]))
    parts.append(box(prefix + "ButtPlate", (HALF_T * 2 - 0.0016, 0.0024, h - 0.0026), (0, y0 + 0.0003, zc), bevel=0.0009, m=M["steel"]))
    return parts


def bolster(prefix, pin_z, x_in, x_out, body_lo, body_hi, M, r=0.0096):
    """Gold bolster plates round a handle's pin (x_in..x_out from the centre
    each side), flowing back into the handle body between body_lo..body_hi,
    with a glowing washer and a domed star-socket pin head."""
    outline = []
    for i in range(15):
        a = math.radians(-100 + 200 * i / 14)
        outline.append((PIV_Y + math.cos(a) * r, pin_z + math.sin(a) * r))
    back = PIV_Y - 0.026
    lo, hi = min(body_lo, pin_z - r), max(body_hi, pin_z + r)
    tail = [(PIV_Y - 0.012, hi), (back + 0.004, body_hi if pin_z < body_hi else hi), (back, (body_lo + body_hi) / 2),
            (back + 0.004, body_lo if pin_z > body_lo else lo), (PIV_Y - 0.012, lo)]
    # The arc runs from below the pin round the front to above it; the tail closes it back along the body.
    outline += tail
    parts = []
    for side in (-1, 1):
        x0, x1 = side * x_in, side * x_out
        parts.append(slab(f"{prefix}Bolster{side}", outline, x0, x1, M["steel"], bevel=0.0007))
    return parts


def pin_head(prefix, pin_z, x, M, washer=True):
    """A domed gold pin head at |x| (both sides) with a dark star socket, on a glowing washer."""
    parts = []
    for side in (-1, 1):
        xs = side * x
        if washer:
            parts.append(xcyl(f"{prefix}Washer{side}", 0.0058, 0.0008, (xs + side * 0.0003, PIV_Y, pin_z), m=M["cell"], segs=24, bevel=0.0002))
        parts.append(sphere(f"{prefix}Head{side}", 0.0043, (xs + side * 0.0008, PIV_Y, pin_z), scale=(0.42, 1, 1), m=M["steel"], segs=16, rings=8))
        parts.append(star(f"{prefix}Socket{side}", 0.0022, 0.0008, (xs + side * 0.0024, PIV_Y, pin_z), rot=rad(0, 0, 90), m=M["dark"], inner=0.001))
    return parts


def blade_parts(M, satin, mirror):
    """The clip-point blade on its tang: satin flats with a fuller and a
    perforated spine, a mirror grind (a wedge to the edge) and swedge, a
    star through the tang, the choil and kicker, the neon edge."""
    py = PIV_Y
    tip = (BLADE_TIP_Y, 0.0016)
    # The edge (choil to point) and the grind line above it.
    edge = [(py + 0.027, -0.0146), (0.15, -0.0158), (0.182, -0.0146), (0.207, -0.0108), (0.224, -0.0056), tip]
    grind = [(py + 0.027, -0.0064), (0.15, -0.0074), (0.182, -0.0062), (0.207, -0.0032), (0.224, 0.0002), tip]
    clip = [(0.19, 0.0126), (0.205, 0.0108), (0.219, 0.0072), (0.229, 0.0040), tip]
    # The swedge's lower line, from the spine down to where the grind line meets it.
    swedge_line = [(0.19, 0.0126), (0.2, 0.0094), (0.214, 0.0062), grind[-2]]
    flat = [(py - 0.0055, 0.0118), (py + 0.004, 0.0128), (0.17, 0.0128)] + swedge_line + list(reversed(grind[:-2])) + [
        edge[0], (py + 0.022, -0.0126), (py + 0.018, -0.0108), (py + 0.0135, -0.0112), (py + 0.0095, -0.0152), (py + 0.003, -0.0153),
        (py - 0.006, -0.0118), (py - 0.0105, -0.006), (py - 0.012, 0.0), (py - 0.0105, 0.006)]
    body = side_profile("BladeBody", flat, BLADE_HALF * 2, (0, 0, 0), satin, bevel=0.0005)
    # Mirror grind: a wedge from full thickness at the grind line to a thin edge.
    g_out = grind[:-1] + [tip] + list(reversed(edge[:-1]))
    g = side_profile("Grind", g_out, BLADE_HALF * 2, (0, 0, 0), mirror, bevel=0.0003)
    n = len(g_out)
    thin = set(range(len(grind), n))
    for v in g.data.vertices:
        if v.index % n in thin:
            v.co.x *= 0.24
    # Swedge: a thin mirror bevel along the clip.
    sw = clip + [grind[-2]] + list(reversed(swedge_line[1:-1]))
    swedge = side_profile("Swedge", sw, BLADE_HALF * 2, (0, 0, 0), mirror, bevel=0.0003)
    m = len(sw)
    for v in swedge.data.vertices:
        if v.index % m in range(1, len(clip)):
            v.co.x *= 0.3
    # Fuller, spine perforations and the star punched through the tang.
    cutters = []
    for side in (-1, 1):
        cutters.append(slab(f"Fuller{side}", stadium(0.122, 0.178, 0.0034, 0.0036), side * (BLADE_HALF - 0.001), side * (BLADE_HALF + 0.002), M["dark"]))
    for i in range(7):
        cutters.append(xcyl(f"PerfCut{i}", 0.00155, 0.02, (0, 0.121 + i * 0.0087, 0.0089), m=M["dark"], segs=12, bevel=0.0))
    cutters.append(star("StarCut", 0.0062, 0.02, (0, py + 0.019, 0.0005), rot=rad(0, 0, 90), m=M["dark"], inner=0.0028))
    cut(body, cutters)
    parts = [body, g, swedge]
    # The fuller's floor: a pink ticket stripe.
    for side in (-1, 1):
        parts.append(slab(f"FullerFloor{side}", stadium(0.1225, 0.1775, 0.0034, 0.0032), side * (BLADE_HALF - 0.0011), side * (BLADE_HALF - 0.0009),
                          M["pink"]))
    # The neon edge: a glowing strip along the edge to the point.
    neon = [(x, z - 0.0004) for x, z in edge] + [(tip[0] - 0.006, tip[1] - 0.0004)] + [(x, z + 0.0021) for x, z in reversed(edge[:-1])]
    parts.append(side_profile("NeonEdge", neon, 0.0015, (0, 0, 0), M["cell"], bevel=0.0003))
    # Tang pin: the stop pin the handles' noses close on.
    parts.append(xcyl("TangPin", 0.0016, BLADE_HALF * 2 + 0.0024, (0, py - 0.0075, 0.0), m=M["steel"], segs=12, bevel=0.0003))
    return parts


def latch_parts(pivot, M):
    """The gold T-latch on HandleA's butt: hub on its pin with a coil spring
    each side, an arm up behind the butts, a hook over HandleB's butt and a
    star cap with a glowing heart."""
    lx, ly, lz = pivot
    arm_len = BAR_B * 2 - 0.006 + 0.0045
    back = ly - 0.0092
    parts = [
        box("LatchArm", (0.0068, 0.0036, arm_len), (0, back, lz + arm_len / 2 - 0.002), bevel=0.0012, m=M["steel"]),
        box("LatchHook", (0.0068, 0.0125, 0.0034), (0, ly - 0.0046, lz + arm_len - 0.0026), bevel=0.0011, m=M["steel"]),
        box("LatchHub", (0.005, 0.0085, 0.0075), (0, ly - 0.004, lz), bevel=0.0018, m=M["steel"]),
        star("LatchStar", 0.0068, 0.0016, (0, back - 0.0024, lz + arm_len * 0.48), rot=rad(0, 0, 0), m=M["steel"], inner=0.0031, bevel=0.0004),
        star("LatchHeart", 0.0034, 0.0012, (0, back - 0.0034, lz + arm_len * 0.48), rot=rad(0, 0, 0), m=M["cell"], inner=0.0016),
    ]
    # The coil spring between the arm and HandleB's butt plate that snaps the latch shut.
    pts = []
    zs = lz + arm_len * 0.8
    for i in range(43):
        a = math.tau * 3.5 * i / 42
        pts.append((math.cos(a) * 0.0017, back + 0.0016 + 0.0026 * i / 42, zs + math.sin(a) * 0.0017))
    parts.append(tube("LatchSpring", pts, 0.0004, m=M["steel"], segs=6))
    return parts


def build_ticket_flipper():
    reset_scene()
    palette()
    M = weapon_mats("#3ff0ff", emit=2.6)
    satin = mat("BladeSteel", "#c3c9de", rough=0.4, metal=0.55)
    mirror = mat("BladeMirror", "#ffffff", rough=0.1, metal=0.5)

    # HandleA underneath (spacer at the bottom), HandleB on top (the bite handle, dark inlays).
    handle_a = ticket_handle("A", -BAR_B, -SEAM, False, M["trim"], M["pink"], M)
    handle_b = ticket_handle("B", SEAM, BAR_B, True, M["dark"], M["trim"], M)
    # HandleA's bolsters sit outside the bar, HandleB's inside its walls, so they never meet as they turn.
    handle_a += bolster("A", PIN_P, HALF_T, HALF_T + 0.0024, -BAR_B + 0.001, -SEAM, M)
    handle_a.append(xcyl("APinShaft", 0.0028, (HALF_T + 0.0024) * 2, (0, PIV_Y, PIN_P), m=M["steel"], segs=12, bevel=0.0003))
    handle_a += pin_head("APin", PIN_P, HALF_T + 0.0024, M)
    for side in (-1, 1):
        handle_b.append(xcyl(f"BLobe{side}", 0.0088, 0.0015, (side * 0.0076, PIV_Y, -PIN_P), m=M["steel"], segs=24, bevel=0.0004))
    handle_b.append(xcyl("BPinShaft", 0.0027, 0.0166, (0, PIV_Y, -PIN_P), m=M["steel"], segs=12, bevel=0.0003))
    # Latch pin through HandleA's butt.
    latch_pivot = (0, BUTT_Y + 0.004, -BAR_B + 0.006)
    handle_a.append(xcyl("LatchPin", 0.0021, HALF_T * 2 + 0.0016, latch_pivot, m=M["steel"], segs=12, bevel=0.0003))

    blade = blade_parts(M, satin, mirror)
    latch = latch_parts(latch_pivot, M)

    lug, charm_point = melee_lug(-HALF_T, BUTT_Y + 0.006, -BAR_B + 0.0052, M)
    handle_a += lug
    for side in (-1, 1):
        handle_a.append(sphere(f"ABolsterRivet{side}", 0.0021, (side * (HALF_T + 0.0024), PIV_Y - 0.017, -0.011), scale=(0.5, 1, 1), m=M["steel"],
                               segs=12, rings=6))

    k = SCALE
    up = Matrix.Scale(k, 4)
    bpy.context.view_layer.update()
    # Everything drawn so far (the cutters too) goes up to first-person size.
    for ob in list(source_collection().objects):
        ob.matrix_world = up @ ob.matrix_world
    charm_point = tuple(Vector(charm_point) * k)
    bar = (HALF_T * k, BAR_B * k, 0.007)
    arm_r, elbow_r = fist("R", (0, 0, 0), (0, 1, 0), (1, 0, 0), bar, M, (0.24, -0.62, -0.5), -0.056, 0.058,
                          palm_s=(3.82, 0.08), finger_len=0.066, wrist=(0.15, 0.035, 0.046))
    groups = {
        "HandleA": (handle_a, (0, PIV_Y * k, PIN_P * k), None),
        "Blade": (blade, (0, PIV_Y * k, PIN_P * k), "HandleA"),
        "HandleB": (handle_b, (0, PIV_Y * k, -PIN_P * k), "Blade"),
        "Latch": (latch, tuple(Vector(latch_pivot) * k), "HandleA"),
        "ArmR": (arm_r, (0, 0, 0), None),
    }
    empties = {
        "Muzzle": ((0, BLADE_TIP_Y * k, 0.0016 * k), "Blade"),
        "BladeTip": ((0, BLADE_TIP_Y * k, 0.0016 * k), "Blade"),
        "SwingPoint": ((0, 0.155 * k, -0.012 * k), "Blade"),
        "CharmPoint": (charm_point, "HandleA"),
        "ElbowR": (elbow_r, "ArmR"),
    }
    finish("ticket_flipper", groups, empties)


if __name__ == "__main__":
    build_ticket_flipper()
