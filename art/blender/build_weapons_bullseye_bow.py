"""First-person model of the Bullseye Longbow (bullseye_bow): a carnival
archery-gallery recurve. A lacquered cherry-red riser and limbs with ivory and
red target-ring inlays, brass limb bolts and tips, a glowing gold string, and
a nocked arrow with red and cream feathers, a neon nock and a brass bullseye
point. The left hand holds the grip, the right hand hooks the string round
the arrow's nock (hand_kit grip_hand, human sized).

Axes (Blender): the arrow along +Y (the barrel), the bow upright along Z,
the bow's plane at x = 0 (a centre-shot riser: above the arrow shelf the
riser is cut away to the right, the sight window). Origin = the arrow rest.

Nodes the game moves (scripts/weapons/views/bullseye_bow_view.gd):
  Shell            riser, grip, shelf, sight bar, limb bolts (static)
  LimbT0..LimbT4   upper limb, a chain of segments, each pivoting on its
                   joint (local X hinge); bending them flexes the limb back
  LimbB0..LimbB4   lower limb, mirrored
  TipT / TipB      empties on the string grooves (children of LimbT4 / LimbB4)
  StringT/StringB  the two halves of the string, pivot on the nocking point,
                   local +Z (Godot +Y) along the half to its tip: the view
                   turns and stretches each onto its tip as the bow draws
  Arrow            the nocked arrow, pivot on its nock (on the string)
  CellHolo         hologram copy of the arrow (the nock's glint)
  Cell             the glowing bullseye cores of the riser medallions
  ArmR             the drawing hand, origin on the nocking point (moves with it)
  ArmL             the bow hand round the grip
Empties: Muzzle (arrow point, child of Arrow), SightPoint / SightMount (the
pin sight on its bar, left of the arrow), CharmPoint, EjectPoint, VentPoint,
Nock (the nocking point, static), Rest (the arrow rest).

    python art/blender/build_weapons_bullseye_bow.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hand_kit import *  # noqa: F401,F403
from weapon_kit import _finish_part, finish, weapon_mats, charm_lug, side_emblem  # noqa: E402
from weapon_kit import xcyl, ycyl, obox, loft  # noqa: E402

HAND_SCALE = 0.8
GRIP_SQUEEZE = 0.3
## The arrow's axis height over the shelf and its length (nock groove to point).
ARROW_Z = 0.006
ARROW_LEN = 0.72
SHAFT_R = 0.0042
## Upper limb centreline (y, z) at brace; the lower limb mirrors it in z.
LIMB_POINTS = [(0.014, 0.185), (0.010, 0.25), (-0.004, 0.31), (-0.026, 0.37), (-0.058, 0.425), (-0.098, 0.472),
               (-0.142, 0.510), (-0.182, 0.540), (-0.208, 0.562), (-0.220, 0.584), (-0.218, 0.606), (-0.206, 0.624)]
## Limb segments (arc length shares): the last one is the stiff recurve curl.
SEGMENTS = (0.0, 0.2, 0.41, 0.61, 0.8, 1.0)
## Where along the limb (arc share) the string leaves the curl's belly.
STRING_U = 0.9
STRING_R = 0.0021
## The pin sight on its bar, left of the arrow: x of the eye line and its height.
SIGHT_X = -0.05
SIGHT_Z = 0.072
SIGHT_BAR_Z = 0.046
MOUNT_Y = 0.005
## The bow arm: wrist to elbow (the bow is held out straight from the left
## shoulder), how far the palm is turned behind the grip and the knuckles lean.
BOW_ARM = (-0.33, -0.94, -0.06)
BOW_ROLL = -32.0
BOW_TILT = 22.0
BOW_SQUEEZE = 0.15
## The bow hand's thumb before it settles on the riser (weapon space): forward past its right side.
BOW_THUMB = (0.62, 0.78, -0.08)
## The drawing arm: wrist to elbow at full draw (in line with the arrow, the
## elbow a little out and up), and the hook (hand space, kit size).
DRAW_ARM = (0.14, -0.98, 0.1)
HOOK_Y = 0.114
HOOK_Z = -0.030
HOOK_DROP = 0.043
## The drawing hand's thumb (weapon space): folded down across the palm.
DRAW_THUMB = (-0.72, 0.42, -0.55)
HOOK_FLEX = {"Index": (12.0, 78.0, 55.0), "Middle": (12.0, 78.0, 55.0), "Ring": (12.0, 80.0, 55.0), "Pinky": (70.0, 92.0, 60.0)}


def palette():
    """Lacquered cherry wood (Shell), ivory inlay (Trim), dark walnut, brass."""
    mat("Shell", "#b5262b", rough=0.22)
    mat("Trim", "#f4e6c4", rough=0.3)
    mat("GunDark", "#3a2216", rough=0.55, metal=0.0)
    mat("GunSteel", "#d9a441", rough=0.26, metal=0.85)
    mat("GunPink", "#ff3f9f", rough=0.35, emit=1.6, emit_color="#ff3f9f")


def catmull(points, steps=10):
    """A smooth curve through `points` (2D tuples): [(y, z), ...] densely sampled."""
    pts = [Vector((p[0], p[1])) for p in points]
    pts = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for k in range(steps):
            t = k / steps
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-2])
    return out


class Curve:
    """The limb's centreline with arc-length lookups, in the bow's plane (y, z)."""

    def __init__(self, points):
        self.pts = catmull(points, 14)
        self.acc = [0.0]
        for a, b in zip(self.pts, self.pts[1:]):
            self.acc.append(self.acc[-1] + (b - a).length)
        self.length = self.acc[-1]

    def at(self, u):
        """(point, tangent) at arc share u (0..1)."""
        s = max(0.0, min(1.0, u)) * self.length
        for i in range(len(self.acc) - 1):
            if self.acc[i + 1] >= s:
                k = (s - self.acc[i]) / max(1e-9, self.acc[i + 1] - self.acc[i])
                a, b = self.pts[i], self.pts[i + 1]
                return a + (b - a) * k, (b - a).normalized()
        return self.pts[-1], (self.pts[-1] - self.pts[-2]).normalized()


def half_width(u):
    return 0.0215 * (1.0 - u) + 0.0085 * u


def half_thick(u):
    return 0.0078 * (1.0 - u) + 0.0042 * u


def to3(p, sign):
    """A (y, z) point of the upper limb onto the limb of `sign` (+1 upper, -1 lower)."""
    return Vector((0.0, p.x, p.y * sign))


def limb_strip(name, curve, u0, u1, sign, m, inset=0.0, rings=10, cols=16):
    """One segment of a limb: a tapering rounded slab along the curve from arc
    share u0 to u1 (cross-section: width along x, thickness across the curve)."""
    bm = bmesh.new()
    loops = []
    for i in range(rings + 1):
        u = u0 + (u1 - u0) * i / rings
        p, t = curve.at(u)
        nrm = Vector((t.y, -t.x))
        w, h = half_width(u) - inset, half_thick(u) - inset
        loop = []
        for j in range(cols):
            a = math.tau * j / cols
            c, s = math.cos(a), math.sin(a)
            # A superellipse: flat faces, rounded edges.
            x = w * math.copysign(abs(c) ** 0.45, c)
            d = h * math.copysign(abs(s) ** 0.45, s)
            q = p + nrm * d
            loop.append(bm.verts.new((x, q.x, q.y * sign)))
        loops.append(loop)
    for i in range(rings):
        for j in range(cols):
            bm.faces.new((loops[i][j], loops[i][(j + 1) % cols], loops[i + 1][(j + 1) % cols], loops[i + 1][j]))
    bm.faces.new(loops[0])
    bm.faces.new(list(reversed(loops[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish_part(name, bm, m)


def inlay(name, curve, u, sign, radius, mats, side=-1.0):
    """A bullseye inlay (concentric discs) on the limb's belly (the string side)."""
    p, t = curve.at(u)
    nrm = Vector((t.y, -t.x))
    if nrm.x > 0:
        nrm = -nrm
    nrm = nrm * -side if side > 0 else nrm
    h = half_thick(u)
    parts = []
    normal3 = Vector((0.0, nrm.x, nrm.y * sign)).normalized()
    centre = to3(p, sign)
    for k, m in enumerate(mats):
        r = radius * (1.0 - k / len(mats))
        ob = cyl(f"{name}{k}", r, 0.0012, (0, 0, 0), segs=24, bevel=0.0, m=m)
        z = normal3
        x = Vector((1.0, 0.0, 0.0))
        y = z.cross(x)
        lift = h + 0.0003 + 0.00045 * k
        o = centre + normal3 * lift
        ob.matrix_world = Matrix(((x.x, y.x, z.x, o.x), (x.y, y.y, z.y, o.y), (x.z, y.z, z.z, o.z), (0, 0, 0, 1)))
        parts.append(ob)
    return parts


def build_limb(curve, sign, M, rings_mats, lacquer, ivory, brass, gold):
    """The limb of `sign`: SEGMENTS chained nodes (name, parts, pivot, parent) and its string groove point."""
    tag = "T" if sign > 0 else "B"
    nodes = []
    parent = "Shell"
    for i in range(len(SEGMENTS) - 1):
        u0, u1 = SEGMENTS[i], SEGMENTS[i + 1]
        lap = 0.012 / curve.length
        parts = [limb_strip(f"Limb{tag}{i}Wood", curve, max(0.0, u0 - lap * 0.4), min(1.0, u1 + lap), sign, lacquer, rings=12)]
        # A gold pinstripe down the belly and an ivory edge on the back.
        stripe = []
        for k in range(9):
            u = u0 + (u1 - u0) * k / 8
            p, t = curve.at(u)
            nrm = Vector((t.y, -t.x))
            if nrm.x > 0:
                nrm = -nrm
            stripe.append(to3(p + nrm * (half_thick(u) + 0.0002), sign))
        parts.append(tube(f"Limb{tag}{i}Stripe", stripe, 0.0014, m=gold, segs=6))
        if i < 3:
            parts += inlay(f"Limb{tag}{i}Ring", curve, (u0 + u1) * 0.5, sign, half_width((u0 + u1) * 0.5) * 0.82, rings_mats)
        if i == len(SEGMENTS) - 2:
            # The brass tip cap over the curl and the string groove nub.
            cap = [limb_strip(f"Limb{tag}TipCap", curve, 0.93, 1.0, sign, brass, inset=-0.0011, rings=5)]
            p, _t = curve.at(1.0)
            cap.append(sphere(f"Limb{tag}TipBead", 0.0062, to3(p, sign), m=brass, segs=12, rings=8))
            cap.append(sphere(f"Limb{tag}TipGlow", 0.0034, to3(p, sign) + Vector((0, 0.004, 0.003 * sign)), m=M["cell"], segs=10, rings=6))
            parts += cap
        p0, _t0 = curve.at(u0)
        nodes.append((f"Limb{tag}{i}", parts, tuple(to3(p0, sign)), parent))
        parent = f"Limb{tag}{i}"
    p, t = curve.at(STRING_U)
    nrm = Vector((t.y, -t.x))
    if nrm.x > 0:
        nrm = -nrm
    groove = to3(p + nrm * half_thick(STRING_U), sign)
    return nodes, groove, parent


def riser(M, lacquer, ivory, walnut, brass, gold, red):
    """The riser: grip, centre-shot sight window, medallions, limb pockets, shelf."""
    sections = [
        (-0.215, 0.0135, 0.024, 0.012, 0.008, 0.0),
        (-0.175, 0.016, 0.029, 0.012, 0.01, 0.0),
        (-0.138, 0.0175, 0.031, 0.006, 0.012, 0.0),
        (-0.108, 0.0165, 0.027, -0.009, 0.012, 0.0),
        (-0.06, 0.0168, 0.028, -0.014, 0.012, 0.0),
        (-0.022, 0.0172, 0.03, -0.008, 0.012, 0.0),
        (-0.004, 0.0175, 0.029, 0.0, 0.01, 0.003),
        (0.012, 0.0115, 0.026, 0.004, 0.008, 0.0255),
        (0.118, 0.0115, 0.026, 0.006, 0.008, 0.0255),
        (0.158, 0.0145, 0.027, 0.01, 0.009, 0.008),
        (0.215, 0.0135, 0.024, 0.012, 0.008, 0.0),
    ]
    # loft() runs along +Y: build it there with (along = z, height = y) and turn it upright.
    body = loft("RiserBody", [(s[0], s[1], s[2], -s[3], s[4], s[5]) for s in sections], lacquer, n=32, bevel=0.002)
    body.rotation_euler = rad(90, 0, 0)
    parts = [body]
    # The leather grip wrap (walnut) with stitched cream seams.
    wrap = loft("GripWrap", [(-0.124, 0.0182, 0.0312, 0.004, 0.012, 0.0), (-0.106, 0.0177, 0.0285, 0.009, 0.012, 0.0),
                             (-0.06, 0.018, 0.0292, 0.014, 0.012, 0.0), (-0.024, 0.0184, 0.0312, 0.008, 0.012, 0.0)], walnut, n=32, bevel=0.0015)
    wrap.rotation_euler = rad(90, 0, 0)
    parts.append(wrap)
    for k in range(6):
        z = -0.115 + k * 0.017
        parts.append(box(f"GripStitch{k}", (0.0026, 0.004, 0.0072), (0.0188, -0.016, z), bevel=0.0008, m=ivory))
    # The arrow shelf: a brass ledge with a felt pad, and a plunger button.
    parts.append(box("Shelf", (0.03, 0.03, 0.006), (0.004, 0.002, -0.0035), bevel=0.0022, m=brass))
    parts.append(box("ShelfPad", (0.016, 0.022, 0.0022), (0.0, 0.002, 0.0006), bevel=0.0008, m=red))
    parts.append(xcyl("Plunger", 0.0035, 0.008, (0.0105, 0.004, 0.009), m=brass, segs=10, bevel=0.0008))
    # Bullseye medallions on both faces of the sight window section and the lower riser.
    for side in (-1, 1):
        for cz, xr in ((0.066, 0.0255), (-0.17, 0.0)):
            face = xr + side * (0.0115 if xr else 0.016)
            if xr and side < 0:
                continue
            for k, (r, m) in enumerate(((0.019, gold), (0.0165, ivory), (0.0125, red), (0.0085, ivory))):
                parts.append(cyl(f"Medal{side}{cz}{k}", r, 0.0012, (face + side * (0.0006 + 0.0005 * k), 0.003, cz), rot=rad(0, 90, 0),
                                 segs=28, bevel=0.0, m=m))
    # Limb pockets: brass caps and bolts where the limbs seat.
    for sign in (-1, 1):
        z = sign * 0.2
        parts.append(obox(f"Pocket{sign}", (0.034, 0.05, 0.026), (0, 0.012, z), (1, 0, 0), (0, 0, 1), bevel=0.006, m=walnut))
        parts.append(xcyl(f"LimbBolt{sign}", 0.008, 0.04, (0, 0.006, z + sign * 0.002), m=brass, segs=16, bevel=0.0015))
        parts.append(obox(f"PocketBand{sign}", (0.0355, 0.0515, 0.004), (0, 0.012, z - sign * 0.011), (1, 0, 0), (0, 0, 1), bevel=0.0014, m=brass))
    # A short stabiliser stub with a gold bullseye cap at the front of the lower riser.
    parts.append(ycyl("Stabiliser", 0.0075, 0.05, 0.052, z=-0.155, m=walnut, segs=16, bevel=0.002))
    parts.append(ycyl("StabCap", 0.0098, 0.008, 0.079, z=-0.155, m=brass, segs=18, bevel=0.0015))
    return parts


def sight(M, brass, walnut):
    """The pin sight: a brass bar from the riser's left face across the window,
    a peep at its back (IronSightRear) and a round pin guard with a glowing pin
    at its front (IronSightFront). The eye line runs SIGHT_X, SIGHT_Z along +Y."""
    bar = [
        obox("SightArm", (0.068, 0.016, 0.008), (-0.019, 0.012, SIGHT_BAR_Z), (1, 0, 0), (0, 1, 0), bevel=0.002, m=brass),
        obox("SightBar", (0.014, 0.17, 0.008), (SIGHT_X, 0.035, SIGHT_BAR_Z), (1, 0, 0), (0, 1, 0), bevel=0.002, m=brass),
        obox("SightRail", (0.012, 0.1, 0.004), (SIGHT_X, MOUNT_Y, SIGHT_BAR_Z + 0.006), (1, 0, 0), (0, 1, 0), bevel=0.001, m=walnut),
        xcyl("SightKnob", 0.0046, 0.008, (SIGHT_X - 0.011, 0.1, SIGHT_BAR_Z), m=brass, segs=12, bevel=0.001),
    ]
    rear = [
        obox("PeepPost", (0.006, 0.006, SIGHT_Z - SIGHT_BAR_Z - 0.012), (SIGHT_X, -0.058, (SIGHT_Z + SIGHT_BAR_Z) / 2 - 0.006 + 0.002),
             (1, 0, 0), (0, 1, 0), bevel=0.0015, m=brass),
        torus("PeepRing", 0.0075, 0.0022, (SIGHT_X, -0.058, SIGHT_Z), rot=rad(90, 0, 0), m=walnut, major_segs=18, minor_segs=6),
        obox("PeepFoot", (0.012, 0.014, 0.006), (SIGHT_X, -0.058, SIGHT_BAR_Z + 0.004), (1, 0, 0), (0, 1, 0), bevel=0.0015, m=brass),
    ]
    front = [
        torus("PinGuard", 0.0135, 0.0026, (SIGHT_X, 0.105, SIGHT_Z), rot=rad(90, 0, 0), m=brass, major_segs=24, minor_segs=6),
        obox("PinStem", (0.0024, 0.0024, 0.0115), (SIGHT_X, 0.105, SIGHT_Z - 0.0085), (1, 0, 0), (0, 1, 0), bevel=0.0, m=brass),
        sphere("PinDot", 0.0027, (SIGHT_X, 0.105, SIGHT_Z - 0.0026), m=M["cell"], segs=10, rings=6),
        obox("PinGuardFoot", (0.008, 0.01, 0.012), (SIGHT_X, 0.105, SIGHT_BAR_Z + 0.008), (1, 0, 0), (0, 1, 0), bevel=0.0015, m=brass),
    ]
    return bar, rear, front


def arrow(M, nock_at, shaft_m, feather_a, feather_b, brass, crest):
    """The arrow from its nock (nock_at) along +Y: shaft, cresting, three
    feathers, the neon nock and a brass bullseye point."""
    nx, ny, nz = nock_at
    y_tip = ny + ARROW_LEN
    parts = [ycyl("Shaft", SHAFT_R, ARROW_LEN - 0.05, ny + 0.012 + (ARROW_LEN - 0.05) / 2, z=nz, x=nx, m=shaft_m, segs=12, bevel=0.0)]
    for k, (y, w) in enumerate(((0.118, 0.012), (0.136, 0.004), (0.146, 0.004))):
        parts.append(ycyl(f"Crest{k}", SHAFT_R + 0.0003, w, ny + y, z=nz, x=nx, m=crest if k == 0 else M["trim"], segs=12, bevel=0.0))
    # The nock: a glowing neon cap with its string slot.
    parts.append(ycyl("NockBody", SHAFT_R + 0.0006, 0.016, ny + 0.008, z=nz, x=nx, m=M["pink"], segs=12, bevel=0.0008))
    for side in (-1, 1):
        parts.append(box(f"NockEar{side}", (0.0032, 0.007, 0.0046), (nx, ny - 0.0015, nz + side * 0.0034), bevel=0.0009, m=M["pink"]))
    # Three feathers 120 degrees apart, the cock feather (cream) pointing left away from the riser.
    for k in range(3):
        a = math.radians(180 + 120 * k)
        m = feather_b if k == 0 else feather_a
        bm = bmesh.new()
        prof = [(0.022, 0.0005), (0.03, 0.006), (0.05, 0.0125), (0.075, 0.0145), (0.098, 0.011), (0.108, 0.0005)]
        dx, dz = math.cos(a), math.sin(a)
        roots, edges = [], []
        for (y, h) in prof:
            roots.append(bm.verts.new((nx + dx * SHAFT_R, ny + y, nz + dz * SHAFT_R)))
            edges.append(bm.verts.new((nx + dx * (SHAFT_R + h), ny + y + h * 0.35, nz + dz * (SHAFT_R + h))))
        for i in range(len(prof) - 1):
            bm.faces.new((roots[i], roots[i + 1], edges[i + 1], edges[i]))
        ob = _finish_part(f"Feather{k}", bm, m, smooth=False)
        parts.append(ob)
        # A quill line along the feather's root.
        parts.append(tube(f"Quill{k}", [(nx + math.cos(a) * (SHAFT_R + 0.0008), ny + y0, nz + math.sin(a) * (SHAFT_R + 0.0008)) for y0 in (0.024, 0.106)],
                          0.0008, m=M["trim"], segs=5))
    # The point: a brass ferrule, a three-ring bullseye ogive and a glowing tip.
    parts.append(ycyl("Ferrule", SHAFT_R + 0.0008, 0.018, y_tip - 0.04, z=nz, x=nx, m=brass, segs=14, bevel=0.0008))
    parts.append(cyl("PointCone", 0.0062, 0.032, (nx, y_tip - 0.017, nz), rot=rad(-90, 0, 0), segs=16, bevel=0.0, m=brass, radius_top=0.0008))
    parts.append(ycyl("PointRing", 0.0064, 0.003, y_tip - 0.031, z=nz, x=nx, m=M["shell"], segs=16, bevel=0.0))
    parts.append(sphere("PointGlint", 0.0018, (nx, y_tip - 0.001, nz), m=M["cell"], segs=8, rings=5))
    return parts, (nx, y_tip, nz)


def string_half(name, start, end, glow, serving):
    """One half of the string from the nocking point to its tip groove, its
    node turned so local +Z runs along it."""
    a, b = Vector(start), Vector(end)
    d = (b - a).normalized()
    parts = [tube(name + "Strand", [a, a + (b - a) * 0.5, b], STRING_R, m=glow, segs=8),
             tube(name + "Serving", [a, a + d * 0.07], STRING_R * 1.55, m=serving, segs=8)]
    x = Vector((1.0, 0.0, 0.0))
    y = d.cross(x)
    piv = Matrix(((x.x, y.x, d.x, a.x), (x.y, y.y, d.y, a.y), (x.z, y.z, d.z, a.z), (0, 0, 0, 1)))
    return parts, piv


def hand_dir(side, axis, forearm, roll, tilt, world):
    """A weapon-space direction in grip_hand's hand space (x towards the thumb's
    side, y along the palm, z the back of the hand), for its thumb_dir."""
    s = 1.0 if side == "R" else -1.0
    a = Vector(axis).normalized()
    f = Vector(forearm).normalized()
    yh = -(f - a * a.dot(f)).normalized()
    n = (yh.cross(a) * s).normalized()
    if roll:
        R = Matrix.Rotation(math.radians(roll) * s, 3, a)
        n, yh = (R @ n).normalized(), (R @ yh).normalized()
    th = math.radians(tilt)
    yh = (yh * math.cos(th) + a * math.sin(th)).normalized()
    xh = yh.cross(n).normalized()
    w = Vector(world).normalized()
    return (-s * w.dot(xh), w.dot(yh), w.dot(n))


def build_bullseye_bow():
    reset_scene()
    palette()
    M = weapon_mats("#ffd23f", emit=2.4)
    lacquer = M["shell"]
    ivory = M["trim"]
    walnut = M["dark"]
    brass = M["steel"]
    gold = mat("BowGold", "#ffcc4a", rough=0.25, metal=0.9)
    red = mat("TargetRed", "#e0242e", rough=0.3)
    glow = mat("BowString", "#ffd35c", rough=0.4, emit=1.1, emit_color="#ffc23a")
    serving = mat("BowServing", "#2a1a14", rough=0.6)
    shaft_m = mat("ArrowShaft", "#efe2c8", rough=0.45)
    feather_a = mat("FeatherRed", "#e8323a", rough=0.7)
    feather_b = mat("FeatherCream", "#fff3dc", rough=0.7)

    curve = Curve(LIMB_POINTS)
    rings_mats = [gold, ivory, red, ivory, red]
    groups = {"Shell": (riser(M, lacquer, ivory, walnut, brass, gold, red), (0, 0, 0), None)}
    tips = {}
    for sign in (1, -1):
        nodes, groove, last = build_limb(curve, sign, M, rings_mats, lacquer, ivory, brass, gold)
        for name, parts, pivot, parent in nodes:
            groups[name] = (parts, pivot, parent)
        tips[sign] = (groove, last)
    string_y = tips[1][0].y
    nock = (0.0, string_y, ARROW_Z)
    bar, rear, front = sight(M, brass, walnut)
    groups["Shell"][0].extend(bar)
    groups["IronSightRear"] = (rear, (SIGHT_X, -0.058, SIGHT_BAR_Z), None)
    groups["IronSightFront"] = (front, (SIGHT_X, 0.105, SIGHT_BAR_Z), None)
    for sign, key in ((1, "StringT"), (-1, "StringB")):
        parts, piv = string_half(key, nock, tips[sign][0], glow, serving)
        groups[key] = (parts, piv, None)
    # A brass nocking-point bead just above the nock.
    groups["StringT"][0].append(sphere("NockBead", STRING_R * 2.2, (0, string_y, ARROW_Z + SHAFT_R + 0.0045), scale=(1, 1, 1.5), m=brass, segs=10, rings=6))
    arrow_parts, tip = arrow(M, nock, shaft_m, feather_a, feather_b, brass, red)
    groups["Arrow"] = (arrow_parts, nock, None)
    holo = [ycyl("HoloShaft", SHAFT_R * 1.6, ARROW_LEN - 0.02, nock[1] + (ARROW_LEN - 0.02) / 2 + 0.01, z=ARROW_Z, m=M["holo"], segs=10, bevel=0.0)]
    groups["CellHolo"] = (holo, nock, None)
    # The glowing bullseye cores (Cell): one on each medallion.
    cell = []
    for side, x, z in ((1, 0.0255 + 0.0115, 0.066), (1, 0.016, -0.17), (-1, -0.016, -0.17)):
        cell.append(cyl(f"Core{side}{z}", 0.0045, 0.0014, (x + side * 0.0028, 0.003, z), rot=rad(0, 90, 0), segs=20, bevel=0.0, m=M["cell"]))
    groups["Cell"] = (cell, (0.03, 0.003, 0.0), None)
    decal = [side_emblem("Emblem", star_outline(0.011, 0.0048), 0.0175, -0.004, -0.196, M["decal"], depth=0.003)]
    groups["Decal"] = (decal, (0, 0, 0), None)
    lug, charm_point = charm_lug(SIGHT_X - 0.007, 0.07, SIGHT_BAR_Z - 0.002, M, out=-1.0)
    groups["Shell"][0].extend(lug)

    # The bow hand: an archer's grip. The palm sits behind the grip (the bow
    # presses into the pad of the thumb), the knuckles lean about 35 degrees off
    # the riser, the fingers close loosely round its left side and the thumb
    # lies forward along its right side. The forearm runs straight back to the
    # left shoulder (the bow arm is held out straight).
    grip = [box_sdf((0.0, -0.011, -0.067), (1, 0, 0), (0, 1, 0), (0.0182, 0.0298, 0.06), corner=0.014)]
    hand_l = grip_hand("L", (0.0, -0.011, -0.07), (0, 0.06, 1), BOW_ARM, M, grip, scale=HAND_SCALE, squeeze=BOW_SQUEEZE,
                       roll=BOW_ROLL, tilt=BOW_TILT, thumb_dir=hand_dir("L", (0, 0.06, 1), BOW_ARM, BOW_ROLL, BOW_TILT, BOW_THUMB), thumb_len=0.85)
    # The drawing hand: a three-under hook. The back of the hand is flat and in
    # line with the forearm, which runs back along the arrow to the right elbow
    # (a little out and up); the index, middle and ring fingers hook the string
    # just under the nock (the string in their last joint), the little finger
    # is tucked and the thumb folded down along the palm.
    f = Vector(DRAW_ARM).normalized()
    up = Vector((0.0, 0.0, 1.0))
    back = (f - up * up.dot(f)).normalized()
    dorsal = (-back).cross(up).normalized()
    # Hand space (kit size): the string lies HOOK_Y along the hand from the
    # wrist and HOOK_Z under the knuckles; the hand's middle line runs
    # HOOK_DROP under the arrow so the index finger sits just under the nock.
    plane_z = -0.0155 - 0.0016
    string_at = Vector((0.0, string_y, ARROW_Z - HOOK_DROP))
    hook_c = string_at - dorsal * ((HOOK_Z - plane_z) * HAND_SCALE)
    hook = [lambda p, c=hook_c, n=dorsal: (p - c).dot(n)]
    hand_r = grip_hand("R", tuple(hook_c), (0, 0, 1), DRAW_ARM, M, hook, scale=HAND_SCALE, squeeze=0.0, tilt=0.0, contact_y=HOOK_Y,
                       finger_flex=HOOK_FLEX, thumb_dir=hand_dir("R", (0, 0, 1), DRAW_ARM, 0.0, 0.0, DRAW_THUMB), thumb_flex=(8.0, 30.0, 30.0),
                       thumb_len=0.8)
    empties = {
        "Muzzle": (tip, "Arrow"),
        "SightPoint": ((SIGHT_X, -0.058, SIGHT_Z), None),
        "SightMount": ((SIGHT_X, MOUNT_Y, SIGHT_BAR_Z + 0.008), None),
        "EjectPoint": ((0.0, string_y, ARROW_Z), None),
        "VentPoint": ((0.03, 0.01, 0.066), None),
        "CharmPoint": (charm_point, None),
        "Nock": (nock, None),
        "Rest": ((0.0, 0.002, ARROW_Z), None),
        "TipT": (tips[1][0], tips[1][1]),
        "TipB": (tips[-1][0], tips[-1][1]),
    }
    add_hand(groups, empties, hand_l, "GripMain", "Shell")
    add_hand(groups, empties, hand_r, "GripString", "Shell")
    finish("bullseye_bow", groups, empties)


if __name__ == "__main__":
    build_bullseye_bow()
