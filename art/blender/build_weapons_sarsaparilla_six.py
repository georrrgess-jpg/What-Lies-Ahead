"""First-person viewmodel of the Sarsaparilla Six (update 23 secondary, Gold
Rush Gulch): a saloon soda-pop six-shooter. A turquoise frame with gold
filigree scrolls, a cherry-red vent-ribbed barrel, ivory grip panels, an
amber glass sarsaparilla bottle strapped under the barrel (glowing soda with
fizz bubbles in it, a red crown cap on its neck) and an open brass cage
cylinder that shows its six rounds: little glass soda bottles lying neck
back, each with a crown cap the hammer pops. The sixth is the "Last Call":
a gold star cap and cherry-red soda.

Same conventions and node contract as build_weapons.py (documented at the
top of weapon_kit.py): origin at the top of the grip, pointing along +Y, its
own palette (set before weapon_mats, so the shared material names stay and
every finish, cell, decal and charm works). Its moving parts are driven by
scripts/weapons/views/sarsaparilla_six_view.gd and the reload by
scripts/weapons/reloads/sarsaparilla_six_reload.gd:

  Cylinder    the cage cylinder (turns about the barrel axis, -60 degrees a shot)
    Round0..5 the six bottle rounds (Round0 under the hammer at rest, then
              round the cylinder the way it turns; Round5 is the Last Call)
      Cap0..5   each round's crown cap (popped off when it is fired)
      Soda0..5  each round's soda (gone once it is fired)
    Halo5     the Last Call's red ring, lit while it is the next round
  CellHolo    the reload's hologram speed-loader (hidden)
  Cell        the soda in the bottle under the barrel
  Bubble0..6  fizz bubbles in that soda (the view drifts them up and along)
  Hammer      turns about its pin (cocked back, falls on a shot)
  Trigger     the trigger

    python art/blender/build_weapons_sarsaparilla_six.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403
from sky_common import lathe  # noqa: E402

ROUNDS = 6
BUBBLES = 7
## The cylinder: its pivot (on the barrel axis line's axle), radius, plates and chamber circle.
CYL_C = (0.0, 0.023, 0.025)
CYL_R = 0.037
CYL_Y0, CYL_Y1 = -0.006, 0.052
CHAMBER_R = 0.0235
ROUND_R = 0.0092
## The bottle under the barrel (axis height) and the barrel (axis height, radius).
BOTTLE_Z = 0.013
BOTTLE_X = -0.009
BARREL_Z = CYL_C[2] + CHAMBER_R
BARREL_R = 0.0145
RAIL_TOP = 0.074
HAMMER_PIN = (0.0, -0.053, 0.036)
## The fan hand's virtual bar: just over the cocked hammer spur, across the back of the frame.
FAN_BAR = (0.0, -0.072, 0.089)


def palette():
    """Gulch Turquoise frame, Cherry trim, walnut dark, brass metal, ivory panels."""
    mat("Shell", "#2fb7b0", rough=0.34)
    mat("Trim", "#d8323a", rough=0.36)
    mat("GunDark", "#3b2420", rough=0.5, metal=0.15)
    mat("GunSteel", "#d9a33a", rough=0.3, metal=0.7)
    mat("GunPink", "#fbe9c8", rough=0.42)


def glass(name, color, alpha):
    """Translucent tinted glass (exported with alpha blending)."""
    m = mat(name, color, rough=0.12, metal=0.0)
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Alpha"].default_value = alpha
    m.diffuse_color = (*m.diffuse_color[:3], alpha)
    if hasattr(m, "surface_render_method"):
        m.surface_render_method = "BLENDED"
    if hasattr(m, "blend_method"):
        m.blend_method = "BLEND"
    return m


def ylathe(name, profile, m, x=0.0, z=0.0, segs=24):
    """A surface of revolution along +Y: profile [(radius, y), ...] back to front."""
    y0 = profile[0][1]
    return lathe(name, [(r, y - y0) for r, y in profile], [m], segs=segs, loc=(x, y0, z), rot=rad(-90, 0, 0))


def scroll(name, x, centre, r0, r1, start, sweep, m, steps=22, radius=0.0011):
    """One gold filigree curl on a flat side at x: a spiral in the YZ plane
    from radius r0 at angle `start` to r1 after `sweep` degrees."""
    cy, cz = centre
    pts = []
    for i in range(steps + 1):
        t = i / steps
        a = math.radians(start + sweep * t)
        r = r0 + (r1 - r0) * t
        pts.append((x, cy + math.cos(a) * r, cz + math.sin(a) * r))
    return tube(name, pts, radius, m=m, segs=6, radius_end=radius * 0.6)


def filigree(prefix, x, m):
    """The saloon scrollwork on one flank of the frame: a pair of facing curls
    on the recoil shield, a vine along the frame's foot and a curl by the barrel."""
    s = 1.0 if x > 0 else -1.0
    parts = [
        scroll(prefix + "CurlA", x, (-0.03, 0.044), 0.016, 0.003, 200, 520, m),
        scroll(prefix + "CurlB", x, (-0.03, 0.008), 0.014, 0.003, 160, -500, m),
        scroll(prefix + "CurlC", x + s * 0.0016, (0.071, 0.03), 0.009, 0.002, 270, 440, m, steps=18),
        tube(prefix + "Vine", [(x, -0.05, -0.016), (x, -0.03, -0.021), (x, -0.012, -0.018)], 0.0011, m=m, segs=6),
    ]
    for k, (y, z) in enumerate(((-0.044, -0.012), (-0.022, -0.014))):
        parts.append(sphere(f"{prefix}Leaf{k}", 0.0026, (x, y, z), scale=(0.4, 1.4, 0.8), m=m, segs=8, rings=4))
    parts.append(sphere(prefix + "Stud", 0.0032, (x + s * 0.0006, -0.03, 0.026), scale=(0.5, 1, 1), m=m, segs=10, rings=6))
    return parts


def bottle_round(i, M, amber, cap_m, soda_m):
    """One round: a little glass soda bottle lying along +Y with its neck to
    the back, its crown cap on the neck and its soda inside. Returns (glass
    parts, cap parts, soda parts, centre)."""
    a = math.radians(90 + 60 * i)
    x = CYL_C[0] + math.cos(a) * CHAMBER_R
    z = CYL_C[2] + math.sin(a) * CHAMBER_R
    r = ROUND_R
    body = [ylathe(f"RoundGlass{i}", [(0.0045, 0.004), (0.0052, 0.007), (0.0052, 0.012), (r * 0.98, 0.021), (r, 0.024),
                                       (r, 0.045), (r * 0.86, 0.0478)], amber, x=x, z=z, segs=18)]
    cap = [ycyl(f"CapTop{i}", 0.0064, 0.0034, -0.0002, z=z, x=x, m=cap_m, segs=18, bevel=0.0008),
           ring(f"CapCrimp{i}", 0.0062, 0.0011, 0.0028, z=z, x=x, m=cap_m, segs=18)]
    for k in range(10):
        ca = math.tau * k / 10
        cap.append(box(f"CapFlute{i}_{k}", (0.0022, 0.0034, 0.0016),
                       (x + math.cos(ca) * 0.0066, 0.0014, z + math.sin(ca) * 0.0066), rot=(0, ca, 0), bevel=0.0, m=cap_m))
    soda = [ycyl(f"RoundSoda{i}", r * 0.74, 0.024, 0.034, z=z, x=x, m=soda_m, segs=14, bevel=0.002)]
    return body, cap, soda, (x, 0.024, z)


def fan_hand(M):
    """The off hand that fans the hammer (ArmLFist, shown only while fanning):
    a glove laid palm down over the back of the frame, fingers draped over its
    right side, thumb on the left, the forearm coming from the lower left.
    Built as a support hand cupping a thin flat bar across the hammer spur's
    top, then turned over (palm down) about the bar. Returns (parts, centre)."""
    c = Vector(FAN_BAR)
    toward = (-0.3, -0.12, 0.95)       # before the turn: (left, back, down) after it
    parts, _elbow = support_hand(tuple(c), 0.021, 0.006, M, toward, corner=0.005, prefix="LF", finger_len=0.07,
                                palm_len=0.1, length=0.1, thumb_len=0.06)
    turn = Matrix.Translation(c) @ Matrix.Rotation(math.pi, 4, "X") @ Matrix.Translation(-c)
    for ob in parts:
        ob.matrix_world = turn @ ob.matrix_world
    return parts, tuple(c)


def build_sarsaparilla_six():
    reset_scene()
    palette()
    M = weapon_mats("#ffa53a", emit=1.8)
    gold = mat("Filigree", "#ffc93c", rough=0.25, metal=0.75)
    amber = glass("AmberGlass", "#9a4a12", 0.55)
    cap_red = mat("CapRed", "#e8323a", rough=0.3, metal=0.35)
    cap_gold = mat("CapGold", "#ffd23f", rough=0.22, metal=0.6, emit=0.6)
    cherry = mat("LastCallGlow", "#ff3d6e", rough=0.3, emit=2.4)
    label = mat("Label", "#fbe9c8", rough=0.6)
    fizz = mat("Fizz", "#fff4d6", rough=0.2, emit=1.6)
    walnut = M["dark"]

    grip_loc = (0, -0.032, -0.1)
    grip_parts, G = grip("", grip_loc, M, tilt=-20, size=(0.064, 0.086, 0.172), body_bottom=-0.028, panel="pink")
    trig = [p for p in grip_parts if p.name in ("Trigger", "TriggerToe")]
    grip_parts = [p for p in grip_parts if p not in trig]
    for p in trig:
        p.data.materials[0] = M["steel"]
        p.name = "Gold" + p.name     # the export node takes the name "Trigger"
    y_trig = G["trigger"][0]
    z_line = RAIL_TOP + SIGHT_HEIGHT
    cx, cy, cz = CYL_C

    shell = grip_parts + [
        # The frame: recoil shield and hammer housing behind the cylinder, its foot
        # under it, the top strap over it (the flat rail an optic sits on) and the front.
        side_profile("FrameRear", [(-0.066, -0.028), (-0.012, -0.028), (-0.012, RAIL_TOP), (-0.046, RAIL_TOP), (-0.05, 0.062),
                                   (-0.062, 0.034), (-0.072, 0.0)], 0.04, (0, 0, 0), M["shell"], bevel=0.007),
        box("FrameFoot", (0.04, 0.08, 0.016), (0, 0.026, -0.02), bevel=0.005, m=M["shell"]),
        box("TopStrap", (0.03, 0.082, 0.011), (0, 0.025, RAIL_TOP - 0.0055), bevel=0.003, m=M["shell"]),
        side_profile("FrameFront", [(0.06, -0.028), (0.074, -0.028), (0.082, -0.012), (0.082, RAIL_TOP), (0.06, RAIL_TOP)],
                     0.044, (0, 0, 0), M["shell"], bevel=0.006),
        box("StrapLine", (0.031, 0.06, 0.0016), (0, 0.025, RAIL_TOP - 0.009), bevel=0.0, m=gold),
        box("FootStripe", (0.041, 0.06, 0.004), (0, 0.026, -0.016), bevel=0.001, m=M["trim"]),
        box("ShieldPlate", (0.042, 0.006, 0.07), (0, -0.0135, 0.026), bevel=0.003, m=M["steel"]),
        # The cylinder's axle pin through the front of the frame.
        ycyl("AxlePin", 0.004, 0.012, 0.084, z=cz, m=M["steel"], segs=10, bevel=0.001),
        # Barrel: cherry red with brass rings, a vent rib on top and a brass crown.
        ycyl("Barrel", BARREL_R, 0.172, 0.166, z=BARREL_Z, m=M["trim"], segs=28, bevel=0.003),
        ring("BarrelRingRear", BARREL_R + 0.001, 0.0022, 0.088, z=BARREL_Z, m=M["steel"], segs=28),
        ring("BarrelRingMid", BARREL_R + 0.0008, 0.0016, 0.2, z=BARREL_Z, m=gold, segs=28),
        ring("MuzzleCrown", BARREL_R - 0.0005, 0.003, 0.252, z=BARREL_Z, m=M["steel"], segs=28),
        ycyl("MuzzleBore", 0.0078, 0.004, 0.2545, z=BARREL_Z, m=walnut, segs=18, bevel=0.0),
        box("VentRib", (0.011, 0.172, 0.0105), (0, 0.166, RAIL_TOP - 0.00525), bevel=0.002, m=M["trim"]),
    ]
    for k in range(6):
        shell.append(box(f"RibVent{k}", (0.0116, 0.012, 0.0045), (0, 0.098 + k * 0.026, RAIL_TOP - 0.0058), bevel=0.0, m=walnut))
    # The bottle's straps: brass bands round it, clamped up to the barrel.
    for k, y in enumerate((0.112, 0.162)):
        shell.append(ring(f"BottleBand{k}", 0.0172, 0.0019, y, z=BOTTLE_Z, x=BOTTLE_X, m=M["steel"], segs=26))
        shell.append(box(f"BandClamp{k}", (0.008, 0.009, 0.014), (BOTTLE_X / 2, y, (BOTTLE_Z + BARREL_Z) / 2 + 0.002), bevel=0.002, m=M["steel"]))
    # Amber bottle: glass, a cream label with a cherry stripe, a red crown cap on its neck.
    shell.append(ylathe("BottleGlass", [(0.011, 0.082), (0.0158, 0.085), (0.0165, 0.092), (0.0165, 0.168), (0.015, 0.18),
                                         (0.0104, 0.196), (0.0068, 0.207), (0.0066, 0.222), (0.0079, 0.2255), (0.0079, 0.229)],
                        amber, x=BOTTLE_X, z=BOTTLE_Z, segs=28))
    shell.append(ylathe("BottleLabel", [(0.0168, 0.124), (0.0168, 0.151)], label, x=BOTTLE_X, z=BOTTLE_Z, segs=28))
    shell.append(ylathe("LabelStripe", [(0.0171, 0.133), (0.0171, 0.142)], M["trim"], x=BOTTLE_X, z=BOTTLE_Z, segs=28))
    shell.append(star("LabelStar", 0.0055, 0.002, (BOTTLE_X - 0.0172, 0.1375, BOTTLE_Z), rot=rad(0, 0, -90), m=gold, inner=0.0024))
    shell.append(ycyl("BottleCap", 0.0088, 0.0055, 0.2315, z=BOTTLE_Z, x=BOTTLE_X, m=cap_red, segs=20, bevel=0.0012))
    for k in range(12):
        ca = math.tau * k / 12
        shell.append(box(f"BottleCapFlute{k}", (0.0026, 0.0048, 0.0018),
                         (BOTTLE_X + math.cos(ca) * 0.009, 0.2302, BOTTLE_Z + math.sin(ca) * 0.009), rot=(0, ca, 0), bevel=0.0, m=cap_red))
    # Gold filigree on both flanks, a gold star on the recoil shield's top.
    shell += filigree("FiligreeL", -0.0206, gold) + filigree("FiligreeR", 0.0206, gold)
    shell += bolts("Pin", [(-0.0205, -0.056, 0.0), (0.0205, -0.056, 0.0), (-0.0225, 0.072, -0.016), (0.0225, 0.072, -0.016)],
                   M["steel"], radius=0.0042, height=0.004)
    # A brass butt cap under the grip.
    shell.append(box("ButtCap", (0.07, 0.095, 0.012), tuple(fpt(G["frame"], 0, 0, -0.172 / 2 - 0.002)), rot=(math.radians(-20), 0, 0),
                     bevel=0.005, m=M["steel"]))
    lug, charm_point = charm_lug(0.013, 0.162, BOTTLE_Z + 0.004, M, out=1.0)
    shell += lug
    sight_rear, sight_front = sights_notch(0.0, -0.04, 0.238, RAIL_TOP, RAIL_TOP, z_line, M, gap=0.015)

    # The cylinder: a brass cage of two plates, an axle hub and six bars between the rounds.
    cylinder = [
        ycyl("CylRearPlate", CYL_R, 0.008, CYL_Y0, z=cz, m=M["steel"], segs=36, bevel=0.002),
        ycyl("CylFrontPlate", CYL_R, 0.008, CYL_Y1, z=cz, m=M["steel"], segs=36, bevel=0.002),
        ring("CylRearRim", CYL_R, 0.0016, CYL_Y0 - 0.004, z=cz, m=M["trim"], segs=36),
        ring("CylFrontRim", CYL_R, 0.0016, CYL_Y1 + 0.004, z=cz, m=M["trim"], segs=36),
        ycyl("CylHub", 0.0085, CYL_Y1 - CYL_Y0, (CYL_Y0 + CYL_Y1) / 2, z=cz, m=walnut, segs=14, bevel=0.001),
        ycyl("CylStar", 0.012, 0.004, CYL_Y1 + 0.005, z=cz, m=gold, segs=6, bevel=0.0),
    ]
    for k in range(ROUNDS):
        a = math.radians(120 + 60 * k)
        bx, bz = cx + math.cos(a) * (CYL_R - 0.004), cz + math.sin(a) * (CYL_R - 0.004)
        cylinder.append(ycyl(f"CylBar{k}", 0.0036, CYL_Y1 - CYL_Y0, (CYL_Y0 + CYL_Y1) / 2, z=bz, x=bx, m=M["steel"], segs=10, bevel=0.001))
        # A chamber hole round each round's neck in the rear plate.
        ra = math.radians(90 + 60 * k)
        cylinder.append(ring(f"CylChamber{k}", 0.0072, 0.0014, CYL_Y0 + 0.0042, z=cz + math.sin(ra) * CHAMBER_R,
                             x=cx + math.cos(ra) * CHAMBER_R, m=walnut, segs=16))
    rounds = {}
    for i in range(ROUNDS):
        last = i == ROUNDS - 1
        rounds[i] = bottle_round(i, M, amber, cap_gold if last else cap_red, cherry if last else M["cell"])
    gx, _gy, gz = rounds[ROUNDS - 1][3]
    halo = [torus("LastCallRing", ROUND_R + 0.0028, 0.0011, (gx, 0.03, gz), rot=rad(90, 0, 0), m=cherry, major_segs=20, minor_segs=4),
            star("LastCallStar", 0.0046, 0.0012, (gx, -0.0021, gz), rot=rad(0, 0, 0), m=cherry, inner=0.002)]

    # The soda in the bottle (the cell) and its fizz.
    cell = [ylathe("BottleSoda", [(0.0095, 0.086), (0.0132, 0.09), (0.0136, 0.168), (0.012, 0.18), (0.0078, 0.192)],
                   M["cell"], x=BOTTLE_X, z=BOTTLE_Z, segs=22)]
    bubbles = {}
    for k in range(BUBBLES):
        y = 0.095 + k * 0.0135
        x = BOTTLE_X + 0.006 * math.sin(k * 2.3)
        z = BOTTLE_Z + 0.004 * math.cos(k * 1.7) + 0.002
        bubbles[k] = ([sphere(f"FizzBubble{k}", 0.0016 + 0.0007 * (k % 3), (x, y, z), m=fizz, segs=8, rings=5)], (x, y, z))

    # The hammer: a cherry body on its pin, a knurled brass spur curling back (modelled down, on the cap).
    hx, hy, hz = HAMMER_PIN
    hammer = [
        box("HammerBody", (0.015, 0.018, 0.036), (0, hy - 0.002, hz + 0.014), rot=rad(-12, 0, 0), bevel=0.004, m=M["trim"]),
        box("HammerNose", (0.006, 0.012, 0.006), (0, hy + 0.008, BARREL_Z - 0.001), bevel=0.0015, m=M["steel"]),
        tube("HammerSpur", [(0, hy - 0.004, hz + 0.026), (0, hy - 0.01, hz + 0.04), (0, hy - 0.018, hz + 0.047), (0, hy - 0.027, hz + 0.049)],
             0.0062, m=M["trim"], segs=12, radius_end=0.0058),
        xcyl("HammerPin", 0.0045, 0.016, HAMMER_PIN, m=M["steel"], segs=12),
    ]
    for k in range(4):
        hammer.append(box(f"SpurKnurl{k}", (0.013, 0.0022, 0.0016), (0, hy - 0.011 - k * 0.0045, hz + 0.0468 + min(k, 2) * 0.001),
                          rot=rad(-20 + 8 * k, 0, 0), bevel=0.0, m=M["steel"]))

    # The reload's hologram speed-loader: six rounds in a star clip with a knob.
    holo = M["holo"]
    loader = [ycyl("LoaderPlate", 0.03, 0.005, -0.008, z=cz, m=holo, segs=24, bevel=0.0),
              ycyl("LoaderKnob", 0.0085, 0.02, -0.021, z=cz, m=holo, segs=14, bevel=0.002)]
    for i in range(ROUNDS):
        a = math.radians(90 + 60 * i)
        lx, lz = cx + math.cos(a) * CHAMBER_R, cz + math.sin(a) * CHAMBER_R
        loader.append(ycyl(f"LoaderRound{i}", ROUND_R, 0.03, 0.026, z=lz, x=lx, m=holo, segs=14, bevel=0.002))
        loader.append(ycyl(f"LoaderCap{i}", 0.0065, 0.004, 0.0, z=lz, x=lx, m=holo, segs=14, bevel=0.0))

    decal = [side_emblem("Emblem", star_outline(0.011, 0.005), -0.0212, -0.03, 0.026, M["decal"], depth=0.004)]
    arm_r, elbow_r = firing_hand(G, M, (0.42, -0.5, -0.36))
    arm_l, elbow_l = cup_hand(G, M, (-0.55, -0.32, -0.32))
    fan, fan_c = fan_hand(M)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.04, RAIL_TOP), None),
        "IronSightFront": (sight_front, (0, 0.238, RAIL_TOP), None),
        "Cylinder": (cylinder, CYL_C, None),
        "Cell": (cell, (BOTTLE_X, 0.14, BOTTLE_Z), None),
        "CellHolo": (loader, CYL_C, None),
        "Hammer": (hammer, HAMMER_PIN, None),
        "Trigger": (trig, (0, y_trig, -0.03), None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, grip_loc, None),
        "ArmLFist": (fan, fan_c, None),
    }
    for i, (body, cap, soda, c) in rounds.items():
        groups[f"Round{i}"] = (body, c, "Cylinder")
        groups[f"Cap{i}"] = (cap, (c[0], 0.0, c[2]), f"Round{i}")
        groups[f"Soda{i}"] = (soda, c, f"Round{i}")
    groups["Halo5"] = (halo, rounds[ROUNDS - 1][3], "Cylinder")
    for k, (parts, at) in bubbles.items():
        groups[f"Bubble{k}"] = (parts, at, None)
    empties = {
        "Muzzle": ((0, 0.272, BARREL_Z), None),
        "SightPoint": ((0, -0.04, z_line), None),
        "SightMount": ((0, 0.02, RAIL_TOP), None),
        "EjectPoint": ((-0.04, cy, cz), None),
        "VentPoint": ((BOTTLE_X, 0.238, BOTTLE_Z), None),
        "FanPoint": ((0, hy - 0.026, hz + 0.054), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("sarsaparilla_six", groups, empties)


if __name__ == "__main__":
    build_sarsaparilla_six()
