"""First-person viewmodels for the two carnival sidearms of update 7.

Same conventions and node contract as build_weapons.py (documented at the top
of weapon_kit.py): origin at the top of the grip, pointing along +Y, cream and
purple shell, each with its own silhouette, built-in sights and accent
("Cell") colour. Their extra moving parts are driven by view scripts
(scripts/weapons/views/, WeaponData.view_script) and reload scripts
(scripts/weapons/reloads/):

  sparkler    gold   Cell (fuse canister on the left flank) > FuseSeg0..7 (the
                     fuse, burning down with the magazine), CellHolo, Pinwheel
                     (Catherine wheel, spins with the trigger), Flint (lighter
                     wheel at the back, turns every shot), ArmL > MatchHolo >
                     MatchFlame, MatchTip (the match struck in the reload)
  ring_toss   pink   Ring (the loaded hoop lying in the cradle), Cell (the ring
                     stack in the magazine cage) > Stack0..3, CellHolo, Flipper
                     (the paddle that flings the ring), Hooks (the cradle's
                     catch hooks)

    python art/blender/build_weapons_new2.py [weapon_id ...]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403
from weapon_kit import GAP, PALM_THICK  # noqa: E402

FUSE_SEGMENTS = 8
STACK_RINGS = 4
## Share of faces the hidden glove shapes keep (each weapon ships both arms
## with every GLOVE_KITS shape; thinning them keeps a sidearm near 0.5 MiB).
KIT_DETAIL = 0.4


def lean_arm(parts, ratio=KIT_DETAIL):
    """Thins the glove-shape parts of an arm (weapon_kit hand()) with a
    collapse decimation, applied when finish() merges them."""
    for p in parts:
        if p.get("glove_kit"):
            mod = p.modifiers.new("Lean", "DECIMATE")
            mod.ratio = ratio
    return parts


def match_parts(G, M):
    """The match the support hand strikes in the Sparkler's reload, held up
    between the thumb and the side of the hand (hidden until then). Returns
    (match parts, flame parts, tip location, pivot)."""
    fr, bar = G["frame"], G["bar"]
    a0 = bar[0]
    web = G["web"]
    x_thumb = -(a0 + GAP + PALM_THICK + 0.0135 - 0.005)
    y = 0.05
    z = web(x_thumb, y) - 0.0165 - 0.0145 - 0.0025 - 0.0125
    base = fpt(fr, x_thumb - 0.004, y, z)
    up = Vector((-0.12, 0.3, 1.0)).normalized()
    head = base + up * 0.075
    wood = mat("MatchWood", "#e2b07a", rough=0.7)
    red = mat("MatchHead", "#e8304a", rough=0.5)
    flame_m = mat("Flame", "#ffb43a", rough=0.4, emit=3.0)
    core_m = mat("FlameCore", "#fff3c0", rough=0.4, emit=4.0)
    stick = tube("MatchStick", [tuple(base - up * 0.012), tuple(head)], 0.0032, m=wood, segs=6)
    knob = sphere("MatchKnob", 0.0058, tuple(head + up * 0.002), scale=(1, 1, 1.25), m=red, segs=10, rings=6)
    tip = head + up * 0.016
    flame = [sphere("FlameOuter", 0.009, tuple(tip + up * 0.004), scale=(1, 1, 1.9), m=flame_m, segs=10, rings=7),
             sphere("FlameInner", 0.005, tuple(tip), scale=(1, 1, 1.6), m=core_m, segs=8, rings=5)]
    return [stick, knob], flame, tuple(tip), tuple(base)


# ---------------------------------------------------------------------------
# Sparkler: full-auto firework machine pistol
# ---------------------------------------------------------------------------

def build_sparkler():
    reset_scene()
    M = weapon_mats("#ffc93a", emit=2.2)
    grip_loc = (0, -0.014, -0.112)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.068, 0.09, 0.185), body_bottom=-0.035)
    rail_top = 0.112
    z_line = rail_top + SIGHT_HEIGHT
    bore_z = 0.058
    can_c = (-0.07, 0.1, 0.063)          # fuse canister: centre (x, y, z), along the barrel
    can_r = 0.019
    can_len = 0.13
    wheel_c = (-0.05, 0.205, 0.063)      # pinwheel on the left of the nose
    flint_c = (0, -0.064, 0.072)         # lighter wheel at the back

    shell = grip_parts + [
        box("Frame", (0.074, 0.25, 0.07), (0, 0.105, 0.0), bevel=0.02, m=M["trim"]),
        box("FrameNose", (0.06, 0.05, 0.05), (0, 0.235, 0.012), bevel=0.016, m=M["trim"]),
        side_profile("Receiver", [(-0.052, 0.03), (0.238, 0.03), (0.238, 0.08), (0.224, 0.1), (-0.036, 0.1), (-0.054, 0.085)],
                     0.082, (0, 0, 0), M["shell"], bevel=0.008),
        side_profile("Beavertail", [(-0.02, 0.012), (-0.02, -0.03), (-0.05, -0.03), (-0.08, -0.014), (-0.08, 0.0), (-0.06, 0.012)],
                     0.056, (0, 0, 0), M["trim"], bevel=0.006),
        box("ReceiverBelt", (0.086, 0.18, 0.01), (0, 0.11, 0.046), bevel=0.003, m=M["trim"]),
        box("RearPlate", (0.066, 0.008, 0.05), (0, -0.054, 0.062), bevel=0.003, m=M["dark"]),
        # Barrel: short shroud and a star crown with glowing points.
        ycyl("Shroud", 0.026, 0.05, 0.262, z=bore_z, m=M["dark"], segs=16),
        ring("ShroudBand", 0.027, 0.004, 0.25, z=bore_z, m=M["steel"]),
        prism("Crown", star_outline(0.036, 0.019, points=6, rotation=90.0), 0.014, loc=(0, 0.292, bore_z), m=M["trim"], bevel=0.003),
        ring("Emitter", 0.016, 0.0045, 0.3, z=bore_z, m=M["cell"]),
        ycyl("Bore", 0.012, 0.008, 0.299, z=bore_z, m=mat("Bore", "#120c22", rough=0.9), segs=12, bevel=0.0),
        # Canister cradle on the left flank: two brackets and a heat shield.
        box("CanBracketR", (0.03, 0.014, 0.03), (-0.052, can_c[1] - can_len / 2 + 0.004, can_c[2]), bevel=0.005, m=M["shell"]),
        box("CanBracketF", (0.03, 0.014, 0.03), (-0.052, can_c[1] + can_len / 2 - 0.004, can_c[2]), bevel=0.005, m=M["shell"]),
        box("CanShield", (0.006, can_len - 0.02, 0.032), (-0.044, can_c[1], can_c[2]), bevel=0.002, m=M["dark"]),
        # Match striker on the left of the frame.
        box("Striker", (0.005, 0.1, 0.016), (-0.0385, 0.11, -0.012), bevel=0.0015, m=M["dark"]),
        # Pinwheel axle and the flint wheel's fork.
        xcyl("WheelAxle", 0.006, 0.014, (wheel_c[0] + 0.007, wheel_c[1], wheel_c[2]), m=M["steel"], segs=10),
        box("WheelMount", (0.012, 0.02, 0.026), (-0.0405, wheel_c[1], wheel_c[2]), bevel=0.004, m=M["shell"]),
        box("FlintForkL", (0.006, 0.018, 0.03), (-0.016, flint_c[1] + 0.004, flint_c[2]), bevel=0.002, m=M["dark"]),
        box("FlintForkR", (0.006, 0.018, 0.03), (0.016, flint_c[1] + 0.004, flint_c[2]), bevel=0.002, m=M["dark"]),
        box("FlintStone", (0.012, 0.01, 0.01), (0, flint_c[1] + 0.004, flint_c[2] - 0.02), bevel=0.002, m=M["pink"]),
        # Right side: vent slits and the charm lug.
        box("RightPanel", (0.006, 0.12, 0.034), (0.043, 0.12, 0.066), bevel=0.003, m=M["dark"]),
    ]
    for i in range(7):
        shell.append(box(f"StrikerRib{i}", (0.003, 0.004, 0.017), (-0.0412, 0.066 + i * 0.0145, -0.012), bevel=0.0, m=M["steel"]))
    for i in range(4):
        shell.append(box(f"RightSlit{i}", (0.004, 0.016, 0.022), (0.0465, 0.075 + i * 0.03, 0.066), rot=rad(18, 0, 0), bevel=0.0, m=M["cell"]))
    for i in range(6):
        a = math.radians(90 + 60 * i)
        shell.append(sphere(f"CrownTip{i}", 0.0042, (math.cos(a) * 0.033, 0.292, bore_z + math.sin(a) * 0.033), m=M["cell"], segs=8, rings=5))
    for i in range(3):
        shell.append(box(f"Pip{i}", (0.012, 0.006, 0.012), (-0.017 + i * 0.017, -0.0585, 0.05), bevel=0.003, m=M["cell"]))
    shell += top_rail("TopRail", 0.012, 0.19, rail_top, M, width=0.032)
    shell += bolts("Pin", [(-0.0375, 0.03, -0.02), (0.0375, 0.03, -0.02), (0.0375, 0.2, 0.01)], M["steel"], radius=0.006, height=0.007)
    lug, charm_point = charm_lug(0.037, 0.2, -0.014, M, out=1.0)
    shell += lug
    sight_rear, sight_front = sights_notch(0.0, -0.03, 0.212, 0.1, 0.1, z_line, M, gap=0.015)

    # Fuse canister: a purple drum with a charred groove wound round it; the
    # glowing fuse (eight segments) lies in the groove.
    cx, cy, cz = can_c
    y0, y1 = cy - can_len / 2 + 0.012, cy + can_len / 2 - 0.012
    canister = [
        ycyl("CanBody", can_r, can_len - 0.016, cy, z=cz, x=cx, m=M["trim"], segs=18, bevel=0.004),
        ycyl("CanCapR", can_r + 0.004, 0.012, cy - can_len / 2 + 0.006, z=cz, x=cx, m=M["steel"], segs=18, bevel=0.003),
        ycyl("CanCapF", can_r + 0.004, 0.012, cy + can_len / 2 - 0.006, z=cz, x=cx, m=M["steel"], segs=18, bevel=0.003),
        ycyl("CanNose", 0.008, 0.012, cy + can_len / 2 + 0.004, z=cz, x=cx, m=M["cell"], segs=10, bevel=0.002),
    ]
    turns = 2.5
    steps = 96
    helix = []
    for i in range(steps + 1):
        t = i / steps
        a = math.radians(-30) + turns * math.tau * t
        helix.append((cx + math.cos(a) * (can_r + 0.002), y0 + (y1 - y0) * t, cz + math.sin(a) * (can_r + 0.002)))
    canister.append(tube("CanGroove", helix, 0.0034, m=M["dark"], segs=6))
    fuse = {}
    per = steps // FUSE_SEGMENTS
    for k in range(FUSE_SEGMENTS):
        pts = helix[k * per: (k + 1) * per + 1]
        lifted = [(cx + (p[0] - cx) * 1.12, p[1], cz + (p[2] - cz) * 1.12) for p in pts]
        mid = lifted[len(lifted) // 2]
        fuse[f"FuseSeg{k}"] = ([tube(f"FuseCord{k}", lifted, 0.0042, m=M["cell"], segs=6)], mid)
    fuse_front = helix[-1]
    fuse_front = (cx + (fuse_front[0] - cx) * 1.12, fuse_front[1], cz + (fuse_front[2] - cz) * 1.12)
    canister_holo = holo_copy(canister[:4])

    # Pinwheel: a Catherine wheel of six swirled vanes round a glowing hub.
    wx, wy, wz = wheel_c
    wheel = [xcyl("WheelHub", 0.009, 0.012, (wx - 0.004, wy, wz), m=M["cell"], segs=12),
             torus("WheelRim", 0.027, 0.0026, (wx, wy, wz), rot=rad(0, 90, 0), m=M["steel"], major_segs=24, minor_segs=5)]
    for i in range(6):
        a0 = math.tau * i / 6
        pts = []
        for s in range(7):
            u = s / 6
            a = a0 + u * 1.3
            r = 0.008 + u * 0.018
            pts.append((wx - 0.002, wy + math.cos(a) * r, wz + math.sin(a) * r))
        wheel.append(tube(f"WheelVane{i}", pts, 0.0042 - 0.0012 * 0, m=M["cell"] if i % 2 == 0 else M["pink"], segs=6, radius_end=0.0022))
    # Flint wheel: knurled, turned by every shot.
    fx, fy, fz = flint_c
    flint = [xcyl("FlintWheel", 0.013, 0.022, flint_c, m=M["steel"], segs=14)]
    for i in range(10):
        a = math.tau * i / 10
        flint.append(box(f"FlintKnurl{i}", (0.024, 0.004, 0.004), (fx, fy + math.cos(a) * 0.0135, fz + math.sin(a) * 0.0135),
                         rot=(a, 0, 0), bevel=0.0, m=M["dark"]))

    decal = [side_emblem("Emblem", star_outline(0.02, 0.009), -0.0375, 0.188, 0.004, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.42, -0.5, -0.36))
    arm_l, elbow_l = cup_hand(G, M, (-0.55, -0.32, -0.32))
    lean_arm(arm_r)
    lean_arm(arm_l)
    match, flame, match_tip, match_base = match_parts(G, M)
    print(f"[sparkler] match tip {tuple(round(v, 4) for v in match_tip)} fuse front {tuple(round(v, 4) for v in fuse_front)}")

    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.03, 0.1), None),
        "IronSightFront": (sight_front, (0, 0.212, 0.1), None),
        "Cell": (canister, can_c, None),
        "CellHolo": (canister_holo, can_c, None),
        "Pinwheel": (wheel, wheel_c, None),
        "Flint": (flint, flint_c, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, grip_loc, None),
        "MatchHolo": (match, match_base, "ArmL"),
        "MatchFlame": (flame, match_tip, "MatchHolo"),
    }
    for name, (parts, pivot) in fuse.items():
        groups[name] = (parts, pivot, "Cell")
    empties = {
        "Muzzle": ((0, 0.306, bore_z), None),
        "SightPoint": ((0, -0.03, z_line), None),
        "SightMount": ((0, 0.1, rail_top), None),
        "EjectPoint": ((cx - 0.02, cy, cz + 0.02), None),
        "VentPoint": ((0.05, 0.12, 0.07), None),
        "FuseFront": (fuse_front, None),
        "FlintPoint": ((0, fy - 0.012, fz + 0.008), None),
        "MatchTip": (match_tip, "MatchHolo"),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("sparkler", groups, empties)


# ---------------------------------------------------------------------------
# Ring Toss: hoop launcher
# ---------------------------------------------------------------------------

def hoop(name, radius, z, y, m, minor=0.0065, x=0.0):
    """A flat ring (axis Z) like a ring-toss hoop."""
    return torus(name, radius, minor, (x, y, z), m=m, major_segs=24, minor_segs=6)


def build_ring_toss():
    reset_scene()
    M = weapon_mats("#ff4fc4", emit=1.9)
    grip_loc = (0, -0.034, -0.1)
    grip_parts, G = grip("", grip_loc, M, tilt=-17, size=(0.072, 0.094, 0.185), body_bottom=-0.028)
    rail_top = 0.124
    z_line = rail_top + SIGHT_HEIGHT
    mag_c = (0, 0.298, 0.0)               # magazine cage axis (vertical) and cradle centre
    cradle_z = 0.088
    hoop_r = 0.04
    stack_top = 0.052
    pitch = 0.019

    shell = grip_parts + [
        box("Frame", (0.07, 0.2, 0.04), (0, 0.06, -0.008), bevel=0.016, m=M["trim"]),
        side_profile("Receiver", [(-0.07, 0.012), (0.232, 0.012), (0.232, 0.084), (0.212, 0.106), (-0.05, 0.106), (-0.072, 0.09)],
                     0.07, (0, 0, 0), M["shell"], bevel=0.009),
        side_profile("Beavertail", [(-0.03, 0.02), (-0.03, -0.022), (-0.06, -0.022), (-0.088, -0.006), (-0.088, 0.008), (-0.064, 0.02)],
                     0.054, (0, 0, 0), M["trim"], bevel=0.006),
        box("ReceiverStripe", (0.074, 0.2, 0.012), (0, 0.09, 0.05), bevel=0.003, m=M["pink"]),
        box("RearPlate", (0.058, 0.008, 0.06), (0, -0.074, 0.058), bevel=0.003, m=M["dark"]),
        # Neck that carries the cradle out in front of the receiver.
        box("Neck", (0.05, 0.05, 0.03), (0, 0.245, 0.065), bevel=0.01, m=M["trim"]),
        # The cradle: a dark dish the loaded hoop lies in, with a pink lip.
        cyl("CradleDish", hoop_r + 0.012, 0.012, (0, mag_c[1], cradle_z - 0.012), segs=28, bevel=0.004, m=M["dark"]),
        torus("CradleLip", hoop_r + 0.012, 0.004, (0, mag_c[1], cradle_z - 0.006), m=M["pink"], major_segs=28, minor_segs=6),
        cyl("CradlePeg", 0.009, 0.016, (0, mag_c[1], cradle_z - 0.002), segs=12, bevel=0.003, m=M["steel"]),
        # Magazine cage below the cradle: four posts and two bands round the stack.
        cyl("CageFoot", hoop_r + 0.012, 0.012, (0, mag_c[1], -0.04), segs=28, bevel=0.004, m=M["trim"]),
        torus("CageBand", hoop_r + 0.013, 0.0035, (0, mag_c[1], 0.012), m=M["steel"], major_segs=28, minor_segs=6),
    ]
    for i, a in enumerate((45, 135, 225, 315)):
        r = math.radians(a)
        px, py = math.cos(r) * (hoop_r + 0.012), mag_c[1] + math.sin(r) * (hoop_r + 0.012)
        shell.append(cyl(f"CagePost{i}", 0.0045, 0.11, (px, py, 0.023), segs=8, bevel=0.0015, m=M["dark"]))
    for i in range(3):
        shell.append(box(f"Pip{i}", (0.011, 0.008, 0.011), (-0.015 + i * 0.015, -0.079, 0.06), bevel=0.002, m=M["cell"]))
        shell.append(box(f"SideSlit{i}", (0.004, 0.024, 0.012), (-0.0355, 0.06 + i * 0.04, 0.072), rot=rad(16, 0, 0), bevel=0.0, m=M["cell"]))
    shell += top_rail("TopRail", 0.02, 0.19, rail_top, M, width=0.032)
    shell += bolts("Pin", [(-0.0355, -0.04, 0.03), (0.0355, -0.04, 0.03), (-0.0355, 0.16, 0.0), (0.0355, 0.16, 0.0)], M["steel"], radius=0.006, height=0.007)
    lug, charm_point = charm_lug(-0.035, 0.19, 0.03, M)
    shell += lug
    sight_rear, sight_front = sights_ghost_ring(0.0, -0.03, 0.212, 0.106, 0.106, z_line, M, radius=0.015)

    # The loaded hoop and the flipper paddle behind it.
    ring_parts = [hoop("Hoop", hoop_r, cradle_z, mag_c[1], M["cell"], minor=0.0068),
                  hoop("HoopBand", hoop_r, cradle_z + 0.0005, mag_c[1], M["pink"], minor=0.0045, x=0.0)]
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        ring_parts.append(box(f"HoopStripe{i}", (0.012, 0.016, 0.0145), (math.cos(a) * hoop_r, mag_c[1] + math.sin(a) * hoop_r, cradle_z),
                              rot=(0, 0, a), bevel=0.003, m=M["shell"]))
    flip_pivot = (0, mag_c[1] - hoop_r - 0.024, cradle_z - 0.01)
    flipper = [box("FlipperArm", (0.016, 0.03, 0.01), (0, flip_pivot[1] + 0.01, flip_pivot[2] + 0.006), bevel=0.003, m=M["steel"]),
               box("FlipperPad", (0.036, 0.008, 0.016), (0, flip_pivot[1] + 0.022, flip_pivot[2] + 0.012), bevel=0.003, m=M["pink"])]
    hooks = []
    for i, side in enumerate((-1, 1)):
        hooks.append(tube(f"Hook{i}", [(side * (hoop_r + 0.014), mag_c[1] + 0.02, cradle_z - 0.012),
                                       (side * (hoop_r + 0.016), mag_c[1] + 0.03, cradle_z + 0.006),
                                       (side * (hoop_r + 0.004), mag_c[1] + 0.034, cradle_z + 0.014)], 0.0034, m=M["steel"], segs=6))
        hooks.append(sphere(f"HookTip{i}", 0.0045, (side * (hoop_r + 0.003), mag_c[1] + 0.034, cradle_z + 0.014), m=M["cell"], segs=8, rings=5))

    # The ring stack in the cage (each ring its own node, shown by the magazine count).
    spine = [cyl("StackSpine", 0.006, 0.1, (0, mag_c[1], 0.0), segs=8, bevel=0.002, m=M["steel"]),
             cyl("StackFloor", hoop_r + 0.004, 0.008, (0, mag_c[1], -0.03), segs=24, bevel=0.003, m=M["steel"])]
    stack = {}
    for k in range(STACK_RINGS):
        z = stack_top - k * pitch
        stack[f"Stack{k}"] = ([hoop(f"StackHoop{k}", hoop_r - 0.002, z, mag_c[1], M["cell"], minor=0.0062),
                               hoop(f"StackBand{k}", hoop_r - 0.002, z + 0.0005, mag_c[1], M["pink"], minor=0.0042)], (0, mag_c[1], z))
    stack_holo = holo_copy(spine + [parts[0] for parts, _c in stack.values()])

    decal = [side_emblem("Emblem", star_outline(0.022, 0.01), -0.0355, 0.0, 0.05, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.42, -0.5, -0.36))
    arm_l, elbow_l = cup_hand(G, M, (-0.55, -0.32, -0.32))
    lean_arm(arm_r)
    lean_arm(arm_l)
    stack_c = (0, mag_c[1], 0.0)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.03, 0.106), None),
        "IronSightFront": (sight_front, (0, 0.212, 0.106), None),
        "Ring": (ring_parts, (0, mag_c[1], cradle_z), None),
        "Flipper": (flipper, flip_pivot, None),
        "Hooks": (hooks, (0, mag_c[1] + 0.02, cradle_z - 0.012), None),
        "Cell": (spine, stack_c, None),
        "CellHolo": (stack_holo, stack_c, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, grip_loc, None),
    }
    for name, (parts, centre) in stack.items():
        groups[name] = (parts, centre, "Cell")
    empties = {
        "Muzzle": ((0, mag_c[1] + hoop_r + 0.02, cradle_z + 0.004), None),
        "SightPoint": ((0, -0.03, z_line), None),
        "SightMount": ((0, 0.105, rail_top), None),
        "EjectPoint": ((0, mag_c[1], -0.05), None),
        "VentPoint": ((0, mag_c[1], cradle_z + 0.02), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("ring_toss", groups, empties)


BUILDERS = (
    ("sparkler", build_sparkler),
    ("ring_toss", build_ring_toss),
)

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for name, fn in BUILDERS:
        if not only or name in only:
            fn()
