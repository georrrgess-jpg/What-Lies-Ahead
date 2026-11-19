"""First-person model of the Ticket Flipper (ticket_flipper), the melee-slot
butterfly knife: two prize-ticket handles (cherry tickets with cream labels,
perforated ends and gold star stamps) on gold tang pins, a chrome clip-point
blade punched with a row of ticket holes, and a neon edge.

Melee contract (melee_kit.py): origin at the centre of the fist on the
closed-up handles, the blade along +Y with its edge down (-Z). The handles
are channels open towards each other: open, they meet in a solid bar; shut,
the blade lies in their channels. Their pins are crossed (the held handle's
pin is above the seam, the free handle's below), so a 180 degree turn of each
handle about its own pin swaps them over without either one cutting the
other. Nothing rises over the top face of the bar but the free handle (the
thumb lies along the right-hand top edge), so flips go over the top.

  HandleA   the held handle (underneath; pivot on its pin, axis X)
  Blade     child of HandleA, pivot on HandleA's pin (axis X): Blade.x 180
            folds it back into the channels
  HandleB   child of Blade, pivot on its own pin (axis X): the free handle.
            Shut relative to the blade at HandleB.x -180 (with Blade.x 180)
  Latch     child of HandleA, pivot on its pin at the butt (axis X): the
            gold bail that clips over HandleB's butt; turn it -150 to free B
  ArmR      the fist round both handles (ElbowR)
  Cell      not a separate node: the neon edge and the latch gem use the
            "Cell" material (tinted by an equipped cell)

Empties: Tip (blade tip) and TrailBase (blade root) on the Blade,
CharmPoint (a lug on HandleA's butt, left side).

    python art/blender/build_weapons_ticket_flipper.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from melee_kit import *  # noqa: F401,F403

## Handles: half thickness (X), each handle's height (Z), the open seam, wall thicknesses.
HALF_T = 0.0125
HANDLE_H = 0.021
SEAM = 0.0004
WALL_X = 0.003
WALL_Z = 0.0032
## The bar the fist wraps (half height).
BAR_B = SEAM + HANDLE_H
## Pivot line (front of the handles) and the butt.
PIV_Y = 0.085
BUTT_Y = -0.08
## Crossed pins: HandleA's above the seam, HandleB's below.
PIN_P = 0.0026
BLADE_TIP_Y = 0.222
## Everything but the fist is drawn at real size and then scaled up by this
## much, so the knife reads in the big first-person glove.
SCALE = 1.2


def palette():
    """The shared weapon materials in this weapon's colours (weapon_mats reuses them)."""
    mat("Shell", "#ff3f6c", rough=0.34)
    mat("Trim", "#fff0c9", rough=0.45)
    mat("GunDark", "#2a2238", rough=0.5, metal=0.15)
    mat("GunSteel", "#f7c04a", rough=0.28, metal=0.55)
    mat("GunPink", "#ff8fc0", rough=0.38)


def ticket_handle(prefix, z_lo, z_hi, back_at_top, M):
    """One channel handle between heights z_lo..z_hi (open towards the seam):
    its two ticket side walls and its back wall, a butt block, the ticket
    labels and perforations on both sides."""
    h = z_hi - z_lo
    zc = (z_lo + z_hi) / 2
    y0, y1 = BUTT_Y, PIV_Y - 0.008
    length = y1 - y0
    yc = (y0 + y1) / 2
    zb = z_hi - WALL_Z / 2 if back_at_top else z_lo + WALL_Z / 2
    parts = [box(prefix + "Back", (HALF_T * 2, length, WALL_Z), (0, yc, zb), bevel=0.0012, m=M["trim"]),
             box(prefix + "Butt", (HALF_T * 2, 0.012, h), (0, y0 + 0.006, zc), bevel=0.0025, m=M["shell"])]
    for side in (-1, 1):
        x = side * (HALF_T - WALL_X / 2)
        parts.append(box(f"{prefix}Wall{side}", (WALL_X, length, h), (x, yc, zc), bevel=0.0012, m=M["shell"]))
        xo = side * (HALF_T + 0.0003)
        # Cream ticket label with a gold star stamp, framed by dashed perforations.
        parts.append(box(f"{prefix}Label{side}", (0.0012, 0.07, h * 0.56), (xo, yc + 0.004, zc), bevel=0.0004, m=M["trim"]))
        parts.append(star(f"{prefix}Stamp{side}", h * 0.22, 0.0014, (xo + side * 0.0006, yc + 0.026, zc), rot=rad(0, 0, -90 * side), m=M["steel"],
                          inner=h * 0.1))
        for k in range(3):
            parts.append(box(f"{prefix}Ink{side}{k}", (0.0013, 0.026 - k * 0.006, 0.0018), (xo + side * 0.0002, yc - 0.012, zc + h * 0.14 - k * 0.0045),
                             bevel=0.0, m=M["shell"]))
        for end in (-1, 1):
            yp = yc + 0.004 + end * 0.043
            for k in range(4):
                zp = z_lo + h * (0.2 + 0.2 * k)
                parts.append(box(f"{prefix}Perf{side}{end}{k}", (0.0012, 0.0024, 0.0024), (xo, yp, zp), bevel=0.0, m=M["dark"]))
        # Ticket notch: a dark half-moon bitten out of the label's front end.
        parts.append(xcyl(f"{prefix}Notch{side}", h * 0.12, 0.0014, (xo + side * 0.0003, y1 - 0.016, zc), m=M["dark"], segs=12, bevel=0.0))
    return parts


def lobes(prefix, pin_z, x_in, x_out, M):
    """The pair of gold bolster plates round a handle's pin (x_in..x_out from the centre each side)."""
    t = x_out - x_in
    parts = []
    for side in (-1, 1):
        x = side * (x_in + t / 2)
        parts.append(xcyl(f"{prefix}Lobe{side}", 0.0092, t, (x, PIV_Y, pin_z), m=M["steel"], segs=24, bevel=0.0006))
        parts.append(box(f"{prefix}Neck{side}", (t, 0.016, 0.0125), (x, PIV_Y - 0.009, pin_z + (-0.003 if pin_z > 0 else 0.003)), bevel=0.0008, m=M["steel"]))
    return parts


def pin(prefix, pin_z, half, M):
    """A gold pin through a handle's lobes with domed heads."""
    parts = [xcyl(prefix + "Shaft", 0.0028, half * 2, (0, PIV_Y, pin_z), m=M["steel"], segs=12, bevel=0.0004)]
    for side in (-1, 1):
        parts.append(sphere(f"{prefix}Head{side}", 0.0042, (side * half, PIV_Y, pin_z), scale=(0.45, 1, 1), m=M["steel"], segs=12, rings=6))
    return parts


def build_ticket_flipper():
    reset_scene()
    palette()
    M = weapon_mats("#3ff0ff", emit=2.6)
    blade_m = mat("BladeSteel", "#eef1ff", rough=0.24, metal=0.55)
    hole_m = mat("TicketHole", "#1a1030", rough=0.6)

    # HandleA underneath (back wall at the bottom), HandleB on top.
    handle_a = ticket_handle("A", -BAR_B, -SEAM, False, M)
    handle_b = ticket_handle("B", SEAM, BAR_B, True, M)
    # HandleA's bolsters sit outside the bar, HandleB's inside its walls, so they never meet as they turn.
    handle_a += lobes("A", PIN_P, HALF_T, HALF_T + 0.0022, M) + pin("APin", PIN_P, HALF_T + 0.0026, M)
    handle_b += lobes("B", -PIN_P, 0.0068, HALF_T - WALL_X - 0.0003, M) + pin("BPin", -PIN_P, HALF_T - WALL_X - 0.0003, M)
    # Latch pin through HandleA's butt.
    latch_pivot = (0, BUTT_Y + 0.004, -BAR_B + 0.006)
    handle_a.append(xcyl("LatchPin", 0.0022, HALF_T * 2 + 0.003, latch_pivot, m=M["steel"], segs=10, bevel=0.0003))

    # Blade: tang between the pins, a straight spine, a clip point, a gentle belly.
    py = PIV_Y
    outline = [(py - 0.013, 0.0), (py - 0.011, 0.0095), (py - 0.004, 0.0125), (py + 0.012, 0.0128), (0.172, 0.0128), (0.19, 0.0118),
               (BLADE_TIP_Y, 0.0012), (0.205, -0.0072), (0.18, -0.0125), (0.14, -0.0148), (py + 0.022, -0.0145), (py + 0.014, -0.0118),
               (py + 0.01, -0.0085), (py + 0.004, -0.0108), (py - 0.004, -0.0122), (py - 0.011, -0.0095)]
    blade = [side_profile("BladeBody", outline, 0.005, (0, 0, 0), blade_m, bevel=0.0012)]
    # The swedge: a thinner bright bevel along the clip.
    blade.append(side_profile("Swedge", [(0.168, 0.0128), (0.19, 0.0118), (BLADE_TIP_Y - 0.002, 0.0016), (0.2, 0.004), (0.17, 0.0105)], 0.0058,
                              (0, 0, 0), M["steel"], bevel=0.0006))
    # The neon edge: a glowing strip along the belly to the point.
    edge = [(py + 0.022, -0.0145), (0.14, -0.0148), (0.18, -0.0125), (0.205, -0.0072), (BLADE_TIP_Y, 0.0012),
            (BLADE_TIP_Y - 0.006, 0.0012), (0.198, -0.0044), (0.176, -0.0088), (0.14, -0.0108), (py + 0.026, -0.0106)]
    blade.append(side_profile("NeonEdge", edge, 0.0054, (0, 0, -0.0004), M["cell"], bevel=0.0005))
    # Ticket perforations punched along the spine, and a big ticket hole near the root.
    for i in range(6):
        y = py + 0.03 + i * 0.0105
        blade.append(xcyl(f"Perf{i}", 0.0021, 0.0058, (0, y, 0.0072), m=hole_m, segs=10, bevel=0.0))
    blade.append(xcyl("TicketHole", 0.0052, 0.0058, (0, py + 0.024, -0.002), m=hole_m, segs=16, bevel=0.0))
    for side in (-1, 1):
        blade.append(torus(f"HoleRing{side}", 0.0058, 0.0009, (side * 0.0028, py + 0.024, -0.002), rot=rad(0, 90, 0), m=M["cell"],
                           major_segs=18, minor_segs=4))
        # "ADMIT ONE" style etched bars on each flat.
        for k in range(3):
            blade.append(box(f"Etch{side}{k}", (0.0006, 0.024 - k * 0.006, 0.0013), (side * 0.0027, 0.158 - k * 0.002, 0.0035 - k * 0.0034),
                             bevel=0.0, m=M["steel"]))

    # Latch: a gold bail on HandleA's butt that hooks over HandleB's butt.
    lx, ly, lz = latch_pivot
    arm_len = BAR_B * 2 - 0.006 + 0.004
    latch = [
        box("LatchArm", (0.006, 0.004, arm_len), (0, ly - 0.0085, lz + arm_len / 2 - 0.002), bevel=0.0012, m=M["steel"]),
        box("LatchHook", (0.006, 0.012, 0.0035), (0, ly - 0.004, lz + arm_len - 0.0025), bevel=0.001, m=M["steel"]),
        box("LatchHub", (0.0085, 0.008, 0.008), (0, ly - 0.004, lz), bevel=0.002, m=M["steel"]),
        sphere("LatchGem", 0.0026, (0, ly - 0.0108, lz + arm_len * 0.5), scale=(1, 0.5, 1), m=M["cell"], segs=10, rings=6),
    ]

    lug, charm_point = melee_lug(-HALF_T, BUTT_Y + 0.0075, -BAR_B + 0.005, M)
    handle_a += lug

    k = SCALE
    up = Matrix.Scale(k, 4)
    bpy.context.view_layer.update()
    for ob in handle_a + handle_b + blade + latch:
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
        "Tip": ((0, BLADE_TIP_Y * k, 0.0012 * k), "Blade"),
        "TrailBase": ((0, (PIV_Y + 0.02) * k, 0.0), "Blade"),
        "CharmPoint": (charm_point, "HandleA"),
        "ElbowR": (elbow_r, "ArmR"),
    }
    finish("ticket_flipper", groups, empties)


if __name__ == "__main__":
    build_ticket_flipper()
