"""First-person viewmodel of the Popcorn Popper (popcorn_popper): a red-and-
white striped popcorn cart on a blaster frame. A glass dome full of popcorn
(the ammo) sits on the back, a silver kettle with a heat dial on the front,
a striped cart awning on brass posts carries the sights over both, and the
shots leave through a striped popper horn.

Same conventions and node contract as build_weapons.py (documented at the top
of weapon_kit.py): origin at the top of the grip, pointing along +Y, its own
palette (set before weapon_mats, so the shared material names stay and every
finish, cell, decal and charm works). Moving parts, driven by
scripts/weapons/views/popcorn_popper_view.gd and
scripts/weapons/reloads/popcorn_popper_reload.gd:

  Lid           the kettle lid (pivot on its hinge at the front rim, axis +X):
                rattles as the kettle heats and jams, flips open to reload
  HeatNeedle    the dial's needle (pivot at the dial centre, turning about
                the dial's normal, DIAL_NORMAL): cold to jam over NEEDLE_SWEEP
  Kernels       the kernels in the kettle, seen while the lid is open
  PopLayer0..7  the popcorn in the dome, in layers from the bottom (pivot at
                each layer's centre): one layer per POPCORN_PER_LAYER kernels
  Cell          the glowing heater ring in the kettle's floor
  CellHolo      its hologram copy
  ScoopHolo     the hologram kernel scoop (pivot at its handle grip)
  PourHolo      the hologram kernel stream (pivot at its top, hanging -Z)
  ButterHolo    the hologram butter pump (pivot at its nozzle tip)
  DrizzleHolo   the hologram butter drizzle (pivot at its top, hanging -Z)

    python art/blender/build_weapons_popcorn_popper.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403
from weapon_kit import _finish_part  # noqa: E402

LAYERS = 8
## The dome (axis x, y), its glass base and its glass: (height above DOME_Z, radius).
DOME_X = -0.027
DOME_Y = -0.05
DOME_Z = 0.09
DOME_PROFILE = [(0.0, 0.043), (0.045, 0.044), (0.063, 0.04), (0.077, 0.03), (0.086, 0.016), (0.09, 0.0)]
## The kettle (axis x, y), its floor and rim heights.
KET_X = -0.026
KET_Y = 0.07
KET_Z = 0.083
RIM_Z = KET_Z + 0.047
KET_R = 0.033
## The heat dial on the kettle's back-left, facing the player.
DIAL_NORMAL = (-0.62, -0.56, 0.55)
DIAL_R = 0.0125
DECK_Z = 0.083
RAIL_TOP = 0.234
POST_Y = (-0.112, 0.16)
## The lid hinges on the kettle's front rim and flips forward, so the player sees into the kettle.
HINGE_Y = KET_Y + KET_R + 0.002
## The steam whistle up the kettle's right side (x, y).
WHISTLE = (KET_X + KET_R + 0.0055, KET_Y - 0.016)
## Hologram size.
HOLO_SCALE = 1.4


def palette():
    """The shared weapon materials in this weapon's colours (weapon_mats reuses them)."""
    mat("Shell", "#e8323f", rough=0.32)
    mat("Trim", "#fff3dc", rough=0.4)
    mat("GunDark", "#23203b", rough=0.5, metal=0.15)
    mat("GunSteel", "#f2b53c", rough=0.3, metal=0.55)
    mat("GunPink", "#3fc4ff", rough=0.36)


def glass_mat(name, color, alpha, emit=0.1):
    """See-through glass (alpha-blended in Godot)."""
    m = mat(name, color, rough=0.06, emit=emit)
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Alpha"].default_value = alpha
    for attr, value in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
        try:
            setattr(m, attr, value)
        except Exception:
            pass
    return m


def lathe(name, profile, centre, m, segs=24, smooth=True):
    """Surface of revolution about +Z through `centre`: profile [(z, radius), ...], capped."""
    bm = bmesh.new()
    rings = []
    cx, cy, cz = centre
    for z, r in profile:
        rings.append([bm.verts.new((cx + math.cos(math.tau * i / segs) * r, cy + math.sin(math.tau * i / segs) * r, cz + z)) for i in range(segs)])
    for i in range(len(rings) - 1):
        for j in range(segs):
            bm.faces.new((rings[i][j], rings[i][(j + 1) % segs], rings[i + 1][(j + 1) % segs], rings[i + 1][j]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish_part(name, bm, m, smooth)


def dome_radius(h):
    for (h0, r0), (h1, r1) in zip(DOME_PROFILE, DOME_PROFILE[1:]):
        if h <= h1:
            return r0 + (r1 - r0) * (h - h0) / (h1 - h0)
    return 0.0


def puff(name, c, r, m, rnd):
    """One popped kernel: a lumpy cluster of two or three lobes."""
    parts = [sphere(name, r, c, scale=(1.0, 0.95, 0.85), m=m, segs=7, rings=4)]
    for k in range(rnd.choice((1, 2))):
        a = rnd.uniform(0, math.tau)
        off = (math.cos(a) * r * 0.7, math.sin(a) * r * 0.7, rnd.uniform(-0.2, 0.5) * r)
        parts.append(sphere(f"{name}L{k}", r * rnd.uniform(0.6, 0.78), (c[0] + off[0], c[1] + off[1], c[2] + off[2]), m=m, segs=6, rings=4))
    return parts


def popcorn_layers(pop, butter):
    """LAYERS of popcorn stacked in the dome: a ring of puffs round a filler core."""
    rnd = random.Random(19)
    layers = {}
    step = 0.0095
    for li in range(LAYERS):
        h = 0.006 + li * step
        z = DOME_Z + h
        room = dome_radius(h + 0.005) - 0.011
        parts = [sphere(f"Core{li}", max(0.008, room * 0.85), (DOME_X, DOME_Y, z), scale=(1, 1, 0.42), m=pop, segs=12, rings=5)]
        count = max(3, int(math.tau * room / 0.016))
        turn = rnd.uniform(0, math.tau)
        for i in range(count):
            a = turn + math.tau * i / count
            c = (DOME_X + math.cos(a) * room, DOME_Y + math.sin(a) * room, z + rnd.uniform(-0.002, 0.003))
            parts += puff(f"Pop{li}_{i}", c, rnd.uniform(0.0085, 0.0105), butter if rnd.random() < 0.3 else pop, rnd)
        if li == LAYERS - 1:
            # The heap's crown.
            for i in range(3):
                a = turn + math.tau * i / 3
                parts += puff(f"Crown{i}", (DOME_X + math.cos(a) * 0.008, DOME_Y + math.sin(a) * 0.008, z + 0.003), 0.008, pop, rnd)
        layers[f"PopLayer{li}"] = (parts, (DOME_X, DOME_Y, z))
    return layers


def dial(M, glow):
    """The heat dial: a brass bezel, a cream face with cold/warm/hot zones, and its needle."""
    n = Vector(DIAL_NORMAL).normalized()
    centre = Vector((KET_X, KET_Y, KET_Z + 0.022)) + Vector((n.x, n.y, 0)).normalized() * (KET_R + 0.004)
    up = (Vector((0, 0, 1)) - n * n.z).normalized()
    side = up.cross(n).normalized()
    face_c = centre + n * 0.003

    def on_face(u, v, lift=0.0):
        p = face_c + side * u + up * v + n * lift
        return (p.x, p.y, p.z)

    rot = n.to_track_quat("Z", "Y").to_euler()
    parts = [
        cyl("DialBack", DIAL_R + 0.003, 0.006, tuple(centre), rot=rot, segs=20, bevel=0.0015, m=M["steel"]),
        cyl("DialFace", DIAL_R, 0.0015, on_face(0, 0, 0.0005), rot=rot, segs=20, bevel=0.0, m=M["trim"]),
        torus("DialBezel", DIAL_R + 0.0015, 0.0016, on_face(0, 0, 0.001), rot=rot, m=M["steel"], major_segs=20, minor_segs=5),
    ]
    zones = [(-125, -40, mat("DialCold", "#3fb4ff", rough=0.4, emit=0.6)), (-40, 40, mat("DialWarm", "#ffd23f", rough=0.4, emit=0.6)),
             (40, 125, mat("DialHot", "#ff4a1f", rough=0.4, emit=0.8))]
    for i, (a0, a1, m) in enumerate(zones):
        steps = 4
        for k in range(steps):
            a = math.radians(a0 + (a1 - a0) * (k + 0.5) / steps)
            r = DIAL_R * 0.78
            parts.append(box(f"DialZone{i}_{k}", (0.0042, 0.0012, 0.0026), on_face(math.sin(a) * r, math.cos(a) * r, 0.0012),
                             rot=_face_rot(n, side, up, a), bevel=0.0, m=m))
    needle = [
        box("NeedleBlade", (0.0016, 0.0008, DIAL_R * 0.85), on_face(0, DIAL_R * 0.38, 0.0022), rot=_face_rot(n, side, up, 0.0), bevel=0.0, m=M["dark"]),
        cyl("NeedleHub", 0.0022, 0.002, on_face(0, 0, 0.0024), rot=rot, segs=10, bevel=0.0, m=glow),
    ]
    return parts, needle, on_face(0, 0, 0.0022)


def _face_rot(n, side, up, a):
    """Euler rotation of a mark on the dial face, turned `a` (radians) from up toward side."""
    v = up * math.cos(a) + side * math.sin(a)
    x = n.cross(v).normalized()
    return Matrix((x, n, v)).transposed().to_euler()


def kettle(M, silver, glow, kernel):
    """The kettle, its lid (hinged at the front rim), the heater ring and the kernels."""
    cx, cy = KET_X, KET_Y
    pot = [
        lathe("Pot", [(0.0, 0.025), (0.004, 0.03), (0.03, KET_R), (0.044, KET_R - 0.0005), (0.047, KET_R + 0.0015),
                      (0.047, KET_R - 0.003), (0.012, KET_R - 0.005)], (cx, cy, KET_Z), silver, segs=32),
        torus("PotBandRed", KET_R + 0.0012, 0.0032, (cx, cy, KET_Z + 0.03), m=M["shell"], major_segs=32, minor_segs=6),
        torus("PotBandWhite", KET_R + 0.0008, 0.0024, (cx, cy, KET_Z + 0.022), m=M["trim"], major_segs=32, minor_segs=6),
        lathe("PotStand", [(0.0, 0.03), (0.003, 0.03), (0.006, 0.024)], (cx, cy, DECK_Z - 0.001), M["steel"], segs=28),
        # The hinge knuckles on the left rim and the brass whistle on the back right.
        xcyl("HingeKnuckle0", 0.0035, 0.01, (cx - 0.014, HINGE_Y, RIM_Z + 0.002), m=M["steel"], segs=10, bevel=0.001),
        xcyl("HingeKnuckle1", 0.0035, 0.01, (cx + 0.014, HINGE_Y, RIM_Z + 0.002), m=M["steel"], segs=10, bevel=0.001),
        cyl("Whistle", 0.0042, 0.04, (WHISTLE[0], WHISTLE[1], RIM_Z - 0.004), segs=12, bevel=0.001, m=M["steel"]),
        cyl("WhistleCap", 0.0058, 0.007, (WHISTLE[0], WHISTLE[1], RIM_Z + 0.019), segs=12, bevel=0.0015, m=M["shell"]),
        box("WhistleClip", (0.008, 0.006, 0.006), (WHISTLE[0] - 0.004, WHISTLE[1], RIM_Z - 0.012), bevel=0.001, m=M["steel"]),
        # The chute that feeds popped kernels down into the chamber.
        tube("Chute", [(cx + KET_R - 0.002, cy, KET_Z + 0.012), (cx + KET_R + 0.01, cy, KET_Z + 0.004), (cx + KET_R + 0.014, cy, DECK_Z - 0.004)],
             0.0055, m=M["steel"], segs=10),
    ]
    lid = [
        lathe("LidDome", [(0.0, KET_R + 0.001), (0.003, KET_R + 0.0005), (0.011, 0.026), (0.017, 0.015), (0.0195, 0.0)], (cx, cy, RIM_Z), silver, segs=32),
        torus("LidRim", KET_R + 0.001, 0.0016, (cx, cy, RIM_Z + 0.001), m=M["shell"], major_segs=32, minor_segs=5),
        cyl("LidKnobStem", 0.003, 0.006, (cx, cy, RIM_Z + 0.021), segs=10, bevel=0.0, m=M["steel"]),
        sphere("LidKnob", 0.0058, (cx, cy, RIM_Z + 0.027), m=M["shell"], segs=12, rings=8),
        xcyl("HingeLeaf", 0.003, 0.016, (cx, HINGE_Y, RIM_Z + 0.002), m=M["steel"], segs=10, bevel=0.001),
    ]
    heater = [torus(f"Heater{i}", 0.02 - i * 0.007, 0.0022, (cx, cy, KET_Z + 0.0135), m=M["cell"], major_segs=22, minor_segs=5) for i in range(2)]
    rnd = random.Random(7)
    kernels = []
    for i in range(16):
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.random()) * (KET_R - 0.011)
        kernels.append(sphere(f"Kernel{i}", 0.0042, (cx + math.cos(a) * r, cy + math.sin(a) * r, KET_Z + 0.017 + rnd.uniform(0, 0.004)),
                              scale=(1.0, 0.8, 0.7), rot=(rnd.uniform(0, 3), rnd.uniform(0, 3), 0), m=kernel, segs=8, rings=5))
    return pot, lid, heater, kernels


def awning(M):
    """The cart awning under the sight rail: striped roof, scalloped valance and two brass posts."""
    y0, y1 = POST_Y[0] - 0.008, POST_Y[1] + 0.008
    roof_z = RAIL_TOP - 0.019
    count = 10
    seg = (y1 - y0) / count
    parts = []
    for i in range(count):
        y = y0 + seg * (i + 0.5)
        m = M["shell"] if i % 2 == 0 else M["trim"]
        parts.append(box(f"Roof{i}", (0.038, seg, 0.008), (0, y, roof_z), bevel=0.0015, m=m))
        for side in (-1, 1):
            parts.append(cyl(f"Scallop{side}{i}", seg * 0.42, 0.003, (side * 0.0185, y, roof_z - 0.005), rot=rad(0, 90, 0), segs=12, bevel=0.0008, m=m))
    for j, y in enumerate(POST_Y):
        h = roof_z - 0.004 - DECK_Z
        parts.append(cyl(f"Post{j}", 0.0055, h, (0, y, DECK_Z + h / 2), segs=12, bevel=0.0015, m=M["steel"]))
        for k in range(3):
            parts.append(torus(f"PostBand{j}{k}", 0.0062, 0.0014, (0, y, DECK_Z + h * (0.25 + 0.25 * k)), m=M["shell"] if k % 2 == 0 else M["trim"],
                               major_segs=12, minor_segs=4))
        parts.append(cyl(f"PostFoot{j}", 0.009, 0.005, (0, y, DECK_Z + 0.0025), segs=14, bevel=0.0015, m=M["steel"]))
    return parts


def wheel(M, x, y, z, r):
    """A little spoked cart wheel on the flank."""
    rot = rad(0, 90, 0)
    parts = [torus("WheelTyre", r, 0.0035, (x, y, z), rot=rot, m=M["shell"], major_segs=24, minor_segs=6),
             cyl("WheelHub", 0.006, 0.008, (x - 0.002, y, z), rot=rot, segs=12, bevel=0.0015, m=M["steel"])]
    for i in range(6):
        a = math.tau * i / 6
        parts.append(box(f"Spoke{i}", (0.0025, 0.0028, r * 0.92), (x, y + math.sin(a) * r * 0.46, z + math.cos(a) * r * 0.46),
                         rot=(-a, 0, 0), bevel=0.0, m=M["trim"]))
    return parts


## Where each hologram rests (its pivot): the scoop's cup over the kettle's
## left rim, the stream's top at the cup's lip, the pump's nozzle tip and the
## drizzle's top under it.
SCOOP_HOME = (KET_X - 0.006, KET_Y, RIM_Z + 0.04)
POUR_HOME = (KET_X + 0.008, KET_Y, RIM_Z + 0.03)
BUTTER_HOME = (KET_X - 0.002, KET_Y + 0.008, RIM_Z + 0.046)


def _at(parts, home):
    for p in parts:
        p.location = Vector(p.location) * HOLO_SCALE + Vector(home)
        p.scale = (HOLO_SCALE, HOLO_SCALE, HOLO_SCALE)
    return parts


def holo_parts(M):
    """The reload's hologram scoop, kernel stream, butter pump and drizzle,
    each built about its pivot and moved to its home."""
    h = M["holo"]
    # A scoop lying along X, open toward the kettle (+X), its handle out left.
    scoop = [
        cyl("ScoopCup", 0.015, 0.026, (0.0, 0.0, 0.0), rot=rad(0, 90, 0), segs=16, bevel=0.002, m=h, radius_top=0.012),
        box("ScoopHandle", (0.032, 0.007, 0.006), (-0.028, 0.0, 0.002), bevel=0.002, m=h),
    ]
    for i in range(5):
        a = math.tau * i / 5
        scoop.append(sphere(f"ScoopKernel{i}", 0.0045, (0.006, math.cos(a) * 0.007, 0.008 + math.sin(a) * 0.003), scale=(1, 0.8, 0.7), m=h, segs=6, rings=4))
    pour = [cyl("PourStream", 0.0045, 0.05, (0, 0, -0.025), segs=10, bevel=0.0, m=h, radius_top=0.006)]
    for i in range(6):
        pour.append(sphere(f"PourKernel{i}", 0.0035, ((i % 2 - 0.5) * 0.004, 0.0, -0.006 - i * 0.008), m=h, segs=6, rings=4))
    # A pump bottle standing behind its nozzle, the nozzle tip on the pivot.
    butter = [
        cyl("PumpBottle", 0.011, 0.034, (0.0, -0.02, -0.012), segs=14, bevel=0.003, m=h),
        cyl("PumpHead", 0.006, 0.012, (0.0, -0.02, 0.011), segs=10, bevel=0.002, m=h),
        box("PumpArm", (0.006, 0.022, 0.005), (0.0, -0.009, 0.016), bevel=0.002, m=h),
        cyl("PumpNozzle", 0.0028, 0.014, (0.0, 0.0, 0.007), segs=8, bevel=0.0, m=h),
    ]
    drizzle_pts = [(math.sin(i * 1.3) * 0.004, math.cos(i * 0.9) * 0.002, -i * 0.005) for i in range(10)]
    drizzle = [tube("DrizzleRibbon", drizzle_pts, 0.0024, m=h, segs=8, radius_end=0.0016)]
    return _at(scoop, SCOOP_HOME), _at(pour, POUR_HOME), _at(butter, BUTTER_HOME), _at(drizzle, BUTTER_HOME)


def build_popcorn_popper():
    reset_scene()
    palette()
    M = weapon_mats("#ffd23f", emit=2.2)
    silver = mat("Kettle", "#e4e8f2", rough=0.3, metal=0.35)
    glass = glass_mat("DomeGlass", "#eaf6ff", alpha=0.13, emit=0.0)
    pop = mat("Popcorn", "#fff6e2", rough=0.7, emit=0.35)
    butter = mat("PopcornButter", "#ffd35a", rough=0.55, emit=0.3)
    kernel = mat("KernelYellow", "#ffb52e", rough=0.4)
    grip_loc = (0, -0.03, -0.115)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.07, 0.092, 0.19), body_bottom=-0.02)
    bore_z = 0.04
    fore = (0, 0.215, -0.062)

    shell = grip_parts + [
        # Cart-red receiver on a navy belly, cream stripes wrapped round it.
        loft("Body", [(-0.118, 0.042, 0.04, 0.034, 0.018), (-0.07, 0.046, 0.043, 0.033, 0.02), (0.13, 0.046, 0.043, 0.033, 0.02),
                      (0.195, 0.04, 0.036, 0.036, 0.016)], M["shell"]),
        box("Belly", (0.092, 0.25, 0.02), (0, 0.035, -0.012), bevel=0.008, m=M["dark"]),
        box("Deck", (0.084, 0.29, 0.008), (0, 0.03, DECK_Z - 0.004), bevel=0.003, m=M["steel"]),
        # Brass barrel and the striped popper horn with its glowing butter core.
        ycyl("Barrel", 0.022, 0.07, 0.225, z=bore_z, m=M["steel"], segs=18),
        ring("BarrelBand", 0.0235, 0.004, 0.205, z=bore_z, m=M["dark"], segs=18),
        ycyl("Horn", 0.025, 0.066, 0.29, z=bore_z, m=M["shell"], segs=24, radius_top=0.046),
        ring("HornLip", 0.0455, 0.0055, 0.323, z=bore_z, m=M["steel"], segs=24),
        ycyl("HornCore", 0.032, 0.005, 0.32, z=bore_z, m=M["cell"], segs=20, bevel=0.0),
        ycyl("HornBore", 0.013, 0.008, 0.322, z=bore_z, m=mat("Bore", "#3a1020", rough=0.9), segs=14, bevel=0.0),
        # Rounded navy foregrip with a blue knob.
        box("ForegripMount", (0.05, 0.06, 0.04), (0, fore[1], 0.0), bevel=0.01, m=M["dark"]),
        box("Foregrip", (0.044, 0.05, 0.11), fore, bevel=0.02, m=M["dark"]),
        sphere("ForegripKnob", 0.026, (0, fore[1], fore[2] - 0.062), scale=(1, 1, 0.6), m=M["pink"], segs=14, rings=8),
        # Short cream stock with a red butt pad.
        box("StockNeck", (0.05, 0.06, 0.05), (0, -0.135, 0.022), bevel=0.012, m=M["dark"]),
        box("Stock", (0.052, 0.05, 0.07), (0, -0.17, 0.014), bevel=0.016, m=M["trim"]),
        box("ButtPad", (0.05, 0.012, 0.074), (0, -0.198, 0.014), bevel=0.006, m=M["shell"]),
        box("ButtStripe", (0.053, 0.03, 0.01), (0, -0.172, 0.034), bevel=0.003, m=M["shell"]),
        # The dome's brass base and crown.
        lathe("DomeBase", [(0.0, 0.047), (0.004, 0.048), (0.007, 0.045)], (DOME_X, DOME_Y, DECK_Z), M["steel"], segs=32),
        torus("DomeFoot", 0.046, 0.002, (DOME_X, DOME_Y, DOME_Z - 0.001), m=M["shell"], major_segs=32, minor_segs=5),
    ]
    # Cream stripes round the receiver, between the deck and the belly.
    for i, y in enumerate((-0.095, -0.06, -0.025, 0.01, 0.045, 0.08, 0.115, 0.15)):
        shell.append(loft(f"Stripe{i}", [(y - 0.008, 0.0466, 0.0432, 0.033, 0.02), (y + 0.008, 0.0466, 0.0432, 0.033, 0.02)], M["trim"], n=24, bevel=0.0))
    pot, lid, heater, kernels = kettle(M, silver, M["cell"], kernel)
    shell += pot + awning(M) + wheel(M, -0.05, -0.035, 0.028, 0.024)
    shell += top_rail("TopRail", -0.1, 0.15, RAIL_TOP, M, width=0.03)
    shell += vent_slots("Vent", 0.047, 0.03, 0.09, 0.03, 3, M["dark"], M["cell"], height=0.03, side=1)
    shell += bolts("Pin", [(0.047, -0.08, 0.05), (-0.047, 0.15, 0.06)], M["steel"], radius=0.006, height=0.006)
    dial_parts, needle, needle_pivot = dial(M, M["cell"])
    shell += dial_parts
    lug, charm_point = charm_lug(-0.027, -0.17, 0.004, M)
    shell += lug
    sight_rear, sight_front = sights_notch(0.0, -0.09, 0.138, RAIL_TOP, RAIL_TOP, RAIL_TOP + SIGHT_HEIGHT, M, gap=0.016)
    heater_holo = holo_copy(heater)
    dome = [lathe("DomeGlass", DOME_PROFILE, (DOME_X, DOME_Y, DOME_Z), glass, segs=36)]
    scoop, pour, butter_pump, drizzle = holo_parts(M)

    emblem = [(-0.012, -0.004), (-0.008, -0.012), (0.0, -0.014), (0.008, -0.012), (0.012, -0.004), (0.01, 0.006), (0.004, 0.012),
              (-0.004, 0.012), (-0.01, 0.006)]
    decal = [side_emblem("Emblem", emblem, -0.047, 0.098, 0.03, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = vertical_hand(fore, 0.023, 0.027, 0.11, M, (-0.52, -0.16, -0.46))
    hinge = (KET_X, HINGE_Y, RIM_Z + 0.002)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "Dome": (dome, (DOME_X, DOME_Y, DOME_Z), None),
        "IronSightRear": (sight_rear, (0, -0.09, RAIL_TOP), None),
        "IronSightFront": (sight_front, (0, 0.138, RAIL_TOP), None),
        "Lid": (lid, hinge, None),
        "HeatNeedle": (needle, needle_pivot, None),
        "Kernels": (kernels, (KET_X, KET_Y, KET_Z + 0.018), None),
        "Cell": (heater, (KET_X, KET_Y, KET_Z + 0.0135), None),
        "CellHolo": (heater_holo, (KET_X, KET_Y, KET_Z + 0.0135), None),
        "ScoopHolo": (scoop, SCOOP_HOME, None),
        "PourHolo": (pour, POUR_HOME, None),
        "ButterHolo": (butter_pump, BUTTER_HOME, None),
        "DrizzleHolo": (drizzle, BUTTER_HOME, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    for name, (parts, centre) in popcorn_layers(pop, butter).items():
        groups[name] = (parts, centre, None)
    empties = {
        "Muzzle": ((0, 0.328, bore_z), None),
        "SightPoint": ((0, -0.09, RAIL_TOP + SIGHT_HEIGHT), None),
        "SightMount": ((0, 0.025, RAIL_TOP), None),
        "EjectPoint": ((KET_X, KET_Y, RIM_Z + 0.01), None),
        "VentPoint": ((WHISTLE[0], WHISTLE[1], RIM_Z + 0.025), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("popcorn_popper", groups, empties)


if __name__ == "__main__":
    build_popcorn_popper()
