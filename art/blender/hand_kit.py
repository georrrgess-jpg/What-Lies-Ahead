"""Articulated gloved hands for the weapon models, and the grip solver that
closes them round a handle (melee_kit.py re-exports everything here; the guns
keep weapon_kit.py's rigid hands unless a build script opts in).

A hand is a chain of nodes, each with its pivot on its joint, so the game can
open and close it (scripts/weapons/hand_rig.gd):

  Arm<S>               the forearm, cuff and sleeve (S = R or L); origin = the
                       centre of the grip, unturned (the old contract)
    Elbow<S>           empty half way down the forearm
    Arm<S>Hand         the palm, back plate and knuckle roll; pivot = wrist
      Arm<S>PalmPoint  empty on the middle of the palm's face
      Arm<S>Grip       empty on the handle's axis at the hand's grip, turned
                       like the weapon's grip anchor (Grip*)
      Arm<S>Index1     proximal phalanx, pivot on the knuckle
        Arm<S>Index2   middle phalanx
          Arm<S>Index3 distal phalanx (GloveTip)
            Arm<S>IndexTip  empty at the finger's tip (likewise each finger, ThumbTip)
      Arm<S>Middle1..3, Arm<S>Ring1..3, Arm<S>Pinky1..3
      Arm<S>ThumbBase  the ball of the thumb; turned to oppose the fingers
        Arm<S>Thumb1..3
    Arm<S>...Kit<Shape> glove shapes, children of the node they ride on

Every phalanx node is oriented the same way: local +Y (Blender; -Z in Godot)
runs along the bone towards the tip, +Z (Godot +Y) is the back of the finger
(the nail side) and X is the hinge. A phalanx's rest turn relative to its
parent is a pure flex about that hinge: rotation_x = -flex. Zero is the open,
straight hand; the build-time grip solver picks each flex so the phalanx
touches the handle without cutting into it, so the exported rest pose IS the
grip. The fingers' knuckle nodes (…1) also spread about their local Z.

Left hands are built mirrored (the thumb on local +X) with right-handed node
frames, so the same flex/spread numbers work on both.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403
from weapon_kit import GAP, FINGER_R, _kit, _spike, _ring, _back_kits, _knuckle_kits, _forearm  # noqa: E402

FINGERS = ("Index", "Middle", "Ring", "Pinky")
PITCH = 2 * FINGER_R + 0.0012
## Per finger: across the knuckles (pitches towards the thumb), knuckle height
## along the palm, the three phalanx lengths and the root radius.
FINGER_SPECS = {
    "Index": (1.5, 0.086, (0.044, 0.030, 0.025), FINGER_R),
    "Middle": (0.5, 0.089, (0.048, 0.032, 0.026), FINGER_R),
    "Ring": (-0.5, 0.086, (0.046, 0.030, 0.025), FINGER_R * 0.97),
    "Pinky": (-1.5, 0.079, (0.038, 0.025, 0.022), FINGER_R * 0.9),
}
TAPER = (1.0, 0.95, 0.9, 0.86)
KNUCKLE_Z = -0.0015
MAX_FLEX = (100.0, 110.0, 90.0)
THUMB_LEN = (0.036, 0.030, 0.025)
THUMB_R = (0.0145, 0.0138, 0.013, 0.0122)
THUMB_FLEX = (75.0, 85.0, 85.0)
## The palm slab in hand space: half width, wrist end, knuckle end, palm face, back.
PALM_X = 0.053
PALM_Y = (0.006, 0.092)
PALM_Z = (-0.0155, 0.0135)
## The ball of the thumb (hand space, x towards the thumb).
THUMB_BASE = (0.039, 0.032, -0.010)


# ---------------------------------------------------------------------------
# Handle shapes (signed distance: < 0 inside)
# ---------------------------------------------------------------------------

def cylinder_sdf(centre, axis, radius):
    """An endless round handle."""
    c, a = Vector(centre), Vector(axis).normalized()

    def sdf(p):
        d = Vector(p) - c
        return (d - a * d.dot(a)).length - radius
    return sdf


def box_sdf(centre, x_axis, y_axis, half, corner=0.0):
    """A rounded box (half sizes along x_axis, y_axis and their cross product)."""
    c = Vector(centre)
    x = Vector(x_axis).normalized()
    y = Vector(y_axis)
    y = (y - x * y.dot(x)).normalized()
    z = x.cross(y)
    hx, hy, hz = (h - corner for h in half)

    def sdf(p):
        d = Vector(p) - c
        q = Vector((abs(d.dot(x)) - hx, abs(d.dot(y)) - hy, abs(d.dot(z)) - hz))
        outside = Vector((max(q.x, 0.0), max(q.y, 0.0), max(q.z, 0.0))).length
        return outside + min(max(q.x, q.y, q.z), 0.0) - corner
    return sdf


def capsule_sdf(a, b, radius):
    a, b = Vector(a), Vector(b)
    ab = b - a
    ll = max(ab.length_squared, 1e-12)

    def sdf(p):
        t = min(1.0, max(0.0, (Vector(p) - a).dot(ab) / ll))
        return (Vector(p) - (a + ab * t)).length - radius
    return sdf


# ---------------------------------------------------------------------------
# Solver
# ---------------------------------------------------------------------------

def _rx(deg):
    return Matrix.Rotation(math.radians(deg), 4, "X")


def _clearance(W, length, r0, r1, obstacles, t0=0.12):
    """Least gap between a phalanx (node matrix W, along local +Y) and the obstacles."""
    best = 1e9
    for i in range(9):
        t = t0 + (1.0 - t0) * i / 8
        p = W @ Vector((0.0, length * t, 0.0))
        r = r0 + (r1 - r0) * t
        for sdf in obstacles:
            best = min(best, sdf(p) - r)
    return best


def _curl(W0, length, r0, r1, obstacles, max_flex, t0=0.12):
    """Flex (degrees) that brings a phalanx at W0 down onto the obstacles:
    the first angle, from straight, at which it touches (GAP clear), or
    max_flex if it never does. A phalanx that is already touching straight
    is lifted (negative flex) until it clears."""
    def gap(th):
        return _clearance(W0 @ _rx(-th), length, r0, r1, obstacles, t0) - GAP
    if gap(0.0) <= 0.0:
        th = 0.0
        while th > -45.0 and gap(th) <= 0.0:
            th -= 1.0
        return th
    prev = 0.0
    th = 1.0
    while th <= max_flex:
        if gap(th) <= 0.0:
            lo, hi = prev, th
            for _ in range(18):
                mid = (lo + hi) / 2
                if gap(mid) > 0.0:
                    lo = mid
                else:
                    hi = mid
            return lo
        prev = th
        th += 1.0
    return max_flex


def _chain(W_parent, offset, lengths, radii, max_flex, obstacles, flex=None, first_t0=0.12, splay=0.0):
    """Solves a three-phalanx chain (the knuckle first turned `splay` degrees
    about the back-of-hand axis). Returns [(matrix, flex), ...]."""
    out = []
    W = W_parent @ Matrix.Translation(Vector(offset)) @ Matrix.Rotation(math.radians(splay), 4, "Z")
    for j, L in enumerate(lengths):
        if flex is not None and flex[j] is not None:
            th = flex[j]
        else:
            th = _curl(W, L, radii[j], radii[j + 1], obstacles, max_flex[j], first_t0 if j == 0 else 0.12)
        Wj = W @ _rx(-th)
        out.append((Wj, th))
        W = Wj @ Matrix.Translation(Vector((0.0, L, 0.0)))
    return out


def _frame_matrix(origin, x, y, z):
    m = Matrix.Identity(4)
    for i in range(3):
        m[i][0], m[i][1], m[i][2], m[i][3] = x[i], y[i], z[i], origin[i]
    return m


def _basis_from(along, dorsal):
    """(x, y, z) of a phalanx frame: y along the bone, z the nail side."""
    y = Vector(along).normalized()
    z = Vector(dorsal)
    z = (z - y * z.dot(y)).normalized()
    return y.cross(z), y, z


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------

def _p(W, x, y, z):
    return W @ Vector((x, y, z))


def _axes(W):
    return (W.col[0].xyz.normalized(), W.col[1].xyz.normalized(), W.col[2].xyz.normalized())


def _phalanx(name, W, length, r0, r1, M, k, thumb=False):
    """One phalanx (node matrix W): a tapered tube, a ball on its joint so a
    curled joint stays closed, the tip on the last one, and its glove parts."""
    X, Y, Z = _axes(W)
    m = M["tip"] if k == 3 else M["glove"]
    a, b = _p(W, 0, 0, 0), _p(W, 0, length, 0)
    parts = [tube(name + "Tube", [a, (a + b) / 2, b], r0, m=m, segs=12, radius_end=r1, cap=False),
             sphere(name + "Joint", r0 * (1.12 if thumb and k == 1 else 1.02), a, m=M["glove"] if k < 3 else m, segs=12, rings=8)]
    if k == 3:
        parts.append(sphere(name + "Tip", r1, b, m=m, segs=12, rings=7))
        claw = (Y * 0.55 + Z).normalized()
        parts += _kit("Claws", [_spike(name + "Claw", b, claw, r1 * 0.62, 0.016 + r1 * 0.4, M["plate"])])
        parts += _kit("Fingerless", [_ring(name + "Hem", _p(W, 0, 0.003, 0), Y, r0 + 0.0004, 0.0013, M["glove"], segs=16)])
    if k == 1 and not thumb:
        parts.append(obox(name + "Guard", (0.022, r0 * 1.7, 0.006), _p(W, 0, length * 0.45, r0 + 0.0012), Y, X, bevel=0.0025, m=M["plate"]))
        top = _p(W, 0, length * 0.45, r0 + 0.0043)
        parts += _kit("Studs", [_spike(name + "Stud", top - Z * 0.001, Z, 0.0062, 0.009, M["plate"], segs=4, x_hint=X)])
        parts += _kit("Circuit", [sphere(name + "Led", 0.0032, top + Z * 0.0004, m=M["cell"], segs=8, rings=5)])
    if k == 2:
        parts += _kit("Gauntlet", [obox(name + "Plate", (0.0135, r0 * 1.55, 0.0045), _p(W, 0, length * 0.5, r0 + 0.0022), Y, X,
                                        bevel=0.0018, m=M["plate"])])
        parts += _kit("Tape", [_ring(f"{name}Tape{j}", _p(W, 0, length * 0.5 + 0.0032 * j, 0), Y, (r0 + r1) / 2 + 0.0002, 0.0014, M["plate"],
                                     segs=12, minor_segs=4) for j in (-1, 1)])
    return parts


def _palm(prefix, W, ts, M, stagger=0.0):
    """The palm slab, the thenar pad and the back of the hand (hand space W);
    `stagger` moves each knuckle along the palm by its x times this, a
    padded metacarpal reaching out to it."""
    X, Y, Z = _axes(W)
    (y0, y1), (z0, z1) = PALM_Y, PALM_Z
    y1 = y1 - min(0.022, abs(stagger) * PALM_X)
    parts = [obox(prefix + "Palm", (PALM_X * 2, y1 - y0, z1 - z0), _p(W, 0, (y0 + y1) / 2, (z0 + z1) / 2), X, Y, bevel=0.012, segs=3,
                  m=M["glove"])]
    for f in FINGERS:
        across, ky, _l, r = FINGER_SPECS[f]
        x = ts * across * PITCH
        k = (x, ky + x * stagger, KNUCKLE_Z)
        parts.append(tube(f"{prefix}{f}Bone", [_p(W, x * 0.9, y1 - 0.03, KNUCKLE_Z), _p(W, *k)], 0.0138, m=M["glove"], segs=12, radius_end=r * 1.04))
    parts += [
             # Heel of the hand, rounding the wrist end into the cuff.
             tube(prefix + "Heel", [_p(W, -PALM_X * 0.55, 0.018, -0.002), _p(W, PALM_X * 0.55, 0.018, -0.002)], 0.0165, m=M["glove"], segs=12),
             # Thenar: the muscle under the thumb, from the heel to the ball of the thumb.
             tube(prefix + "Thenar", [_p(W, ts * 0.012, 0.016, -0.006), _p(W, *(THUMB_BASE[0] * ts, THUMB_BASE[1], THUMB_BASE[2]))], 0.0158,
                  m=M["glove"], segs=12, radius_end=0.0168)]
    bp = _p(W, 0, 0.052, z1 + 0.0012)
    parts.append(obox(prefix + "BackPlate", (0.07, 0.048, 0.007), bp, X, Y, bevel=0.003, m=M["plate"]))
    parts.append(sphere(prefix + "PlateLight", 0.006, bp + Z * 0.0045, m=M["cell"], segs=8, rings=5))
    parts += _back_kits(prefix, bp + Z * 0.0035, Z, Y, X, 0.045, 0.06, M)
    knuckles = []
    for f in FINGERS:
        across, ky, _l, _r = FINGER_SPECS[f]
        knuckles.append((_p(W, ts * across * PITCH, ky + ts * across * PITCH * stagger, KNUCKLE_Z), Z))
    parts += _knuckle_kits(prefix, knuckles, M)
    return parts


# ---------------------------------------------------------------------------
# The hand on a handle
# ---------------------------------------------------------------------------

def grip_hand(side, centre, axis, forearm, M, handle, tilt=None, roll=0.0, contact_y=None,
              thumb_dir=(0.2, -0.86, -0.46), thumb_flex=None, finger_flex=None, extra_obstacles=(), scale=1.0):
    """An articulated hand closed round a handle by the grip solver.

    side      "R" or "L"
    centre    the grip point on the handle's axis (weapon space); the arm's origin
    axis      the handle's direction towards the thumb (both thumbs point along it)
    forearm   direction from the wrist towards the elbow (weapon space)
    handle    list of signed-distance functions (cylinder_sdf, box_sdf, ...): what
              the palm rests on and the fingers close round
    tilt      degrees the knuckle line leans off square to the handle (the handle
              runs diagonally across the palm, the wrist towards -axis); None
              takes 60 % of the angle that would leave the wrist straight, at most 35
    roll      degrees the palm turns round the handle (away from facing the forearm)
    contact_y where along the palm (from the wrist) it touches the handle; None
              tries 0.046..0.086 and keeps the one whose fingers hug the handle best
    thumb_dir the thumb's lie before it curls, in hand space (x towards the thumb's
              side, y along the palm, z the back of the hand)
    thumb_flex / finger_flex: fixed flex angles (None = solve)
    scale     the hand's size against the handle (1 = the kit's chunky glove; about
              0.8 is a human hand on a tool handle). The hand is solved and built at
              the kit's size round the handle enlarged by 1/scale, then shrunk onto
              the real handle about `centre`; the forearm keeps the kit's size.
    Returns dict(groups=..., empties=..., anchor=Matrix): groups and empties in
    finish() form (parents before children), anchor = the grip anchor's matrix
    (Y along the handle towards the thumbs, Z towards the palm).
    """
    s = 1.0 if side == "R" else -1.0
    ts = -s
    P = "Arm" + side
    c = Vector(centre)
    a = Vector(axis).normalized()
    f = Vector(forearm).normalized()
    f_perp = f - a * a.dot(f)
    if f_perp.length < 1e-4:
        f_perp = a.orthogonal()
    yh = -f_perp.normalized()
    n = (yh.cross(a) * s).normalized()
    if roll:
        R = Matrix.Rotation(math.radians(roll) * s, 3, a)
        n, yh = (R @ n).normalized(), (R @ yh).normalized()
    if tilt is None:
        ideal = math.degrees(math.atan2(max(0.0, -f.dot(a)), max(1e-4, f.dot(-yh))))
        tilt = min(35.0, 0.6 * ideal)
    th = math.radians(tilt)
    yh = (yh * math.cos(th) + a * math.sin(th)).normalized()
    xh = yh.cross(n).normalized()
    if scale != 1.0:
        handle = [_enlarged(sdf, c, scale) for sdf in handle]
        extra_obstacles = [_enlarged(sdf, c, scale) for sdf in extra_obstacles]
    obstacles = list(handle) + list(extra_obstacles)
    # The fingers close square round the handle however the palm lies on it:
    # each knuckle turns (splay) so its hinge runs along the handle, and the
    # knuckles stagger along the palm (index furthest out on a tilted hand)
    # so they all sit the same way round it.
    ax = a if xh.dot(a) >= 0.0 else -a
    splay = math.degrees(math.atan2(xh.cross(ax).dot(n), xh.dot(ax)))
    tangent = n.cross(a)
    across = yh.dot(tangent)
    stagger = -xh.dot(tangent) / (across if abs(across) > 1e-3 else 1e-3)

    def place(cy):
        """Rests the palm on the handle with its point cy along the palm over the
        centre (slid out along n until the palm face clears by GAP), curls the
        fingers joint by joint onto the handle; scores how far they stand off it."""
        W = _frame_matrix(c, xh, yh, n)
        W = Matrix.Translation(c - _p(W, 0, cy, PALM_Z[0])) @ W
        samples = [(x * PALM_X * 0.9, y, PALM_Z[0] + 0.004) for x in (-1, -0.5, 0, 0.5, 1) for y in (0.02, 0.04, cy, 0.075, 0.088)]
        least = min(min(sdf(_p(W, *q)) for sdf in handle) for q in samples) - 0.004
        W = Matrix.Translation(n * (GAP - least)) @ W
        fingers = {}
        score = 0.0
        for f_name in FINGERS:
            across, ky, lens, r = FINGER_SPECS[f_name]
            radii = [r * t for t in TAPER]
            fixed = finger_flex.get(f_name) if finger_flex else None
            x = ts * across * PITCH
            chain = _chain(W, (x, ky + x * stagger, KNUCKLE_Z), lens, radii, MAX_FLEX, obstacles, fixed, first_t0=0.3, splay=splay)
            fingers[f_name] = (chain, lens, radii)
            for j, (Wj, _th) in enumerate(chain):
                # Worst stand-off along the phalanx (0 where it rests on the handle).
                lift = max(min(sdf(_p(Wj, 0, lens[j] * t, 0)) for sdf in obstacles) - radii[j] - GAP for t in (0.0, 0.5, 1.0))
                score += lift * (1.0 if j < 2 else 0.6)
        return W, fingers, score

    if contact_y is None:
        W, fingers, _score = min((place(0.046 + 0.004 * i) for i in range(11)), key=lambda r: r[2])
    else:
        W, fingers, _score = place(contact_y)
    groups = {}
    hand_parts = _palm(P, W, ts, M, stagger)
    # Thumb: from the ball of the thumb the other way round, onto the handle or the index finger.
    tb = _p(W, ts * THUMB_BASE[0], THUMB_BASE[1], THUMB_BASE[2])
    td = Vector(thumb_dir)
    along = (_axes(W)[0] * (ts * td.x) + _axes(W)[1] * td.y + _axes(W)[2] * td.z).normalized()
    # The thumb's nail faces away from the handle.
    away = tb - (c + a * a.dot(tb - c))
    away = away - along * away.dot(along)
    if away.length < 1e-4:
        away = n
    bx, by, bz = _basis_from(along, away)
    W_tb = _frame_matrix(tb, bx, by, bz)
    finger_caps = []
    for f_name in ("Index", "Middle"):
        chain, lens, radii = fingers[f_name]
        for j, (Wj, _th) in enumerate(chain):
            finger_caps.append(capsule_sdf(_p(Wj, 0, 0, 0), _p(Wj, 0, lens[j], 0), radii[j]))
    thumb = _chain(W_tb, (0, 0, 0), THUMB_LEN, THUMB_R, THUMB_FLEX, obstacles + finger_caps, thumb_flex, first_t0=0.45)

    groups[P] = ([], c, None)
    groups[P + "Hand"] = (hand_parts, W, P)
    report = []
    tips = {}
    for f_name in FINGERS:
        chain, lens, radii = fingers[f_name]
        parent = P + "Hand"
        for j, (Wj, flex) in enumerate(chain):
            key = f"{P}{f_name}{j + 1}"
            groups[key] = (_phalanx(key, Wj, lens[j], radii[j], radii[j + 1], M, j + 1), Wj, parent)
            parent = key
        report.append(f"{f_name} " + "/".join(f"{fl:.0f}" for _w, fl in chain))
        tips[f"{P}{f_name}Tip"] = (chain[-1][0] @ Matrix.Translation((0, lens[-1], 0)), parent)
    groups[P + "ThumbBase"] = ([sphere(P + "ThumbBall", THUMB_R[0] * 1.16, tb, m=M["glove"], segs=12, rings=8)], W_tb, P + "Hand")
    parent = P + "ThumbBase"
    for j, (Wj, flex) in enumerate(thumb):
        key = f"{P}Thumb{j + 1}"
        groups[key] = (_phalanx(key, Wj, THUMB_LEN[j], THUMB_R[j], THUMB_R[j + 1], M, j + 1, thumb=True), Wj, parent)
        parent = key
    tips[P + "ThumbTip"] = (thumb[-1][0] @ Matrix.Translation((0, THUMB_LEN[-1], 0)), parent)
    report.append("Thumb " + "/".join(f"{fl:.0f}" for _w, fl in thumb))
    anchor = _frame_matrix(c, a.cross(n), a, n)
    empties = {P + "Grip": (anchor, P + "Hand"),
               P + "PalmPoint": (W @ Matrix.Translation((0, 0.05, PALM_Z[0])), P + "Hand"), **tips}
    if scale != 1.0:
        _shrink(groups, empties, c, scale)
    wrist = c + (_p(W, 0, 0, 0) - c) * scale
    arm_parts, elbow = _forearm(P, wrist, wrist + f, M)
    groups[P] = (arm_parts, c, None)
    empties["Elbow" + side] = (elbow, P)
    bend = math.degrees(f.angle(-yh))
    print(f"[hand] {P}: tilt {tilt:.0f}, wrist bend {bend:.0f}, stand-off {_score * 1000:.1f} mm; flex " + ", ".join(report))
    return dict(groups=groups, empties=empties, anchor=anchor)


def _enlarged(sdf, c, scale):
    """The shape `sdf` grown by 1/scale about c (distances grow with it)."""
    return lambda p: sdf(c + (p - c) * scale) / scale


def _shrink(groups, empties, c, scale):
    """Scales a built hand by `scale` about c: every part's mesh, and every node
    and empty position (node turns are kept, so the rig's joints stay rigid)."""
    S = Matrix.Translation(c) @ Matrix.Scale(scale, 4) @ Matrix.Translation(-c)

    def moved(m):
        if isinstance(m, Matrix):
            out = m.to_3x3().normalized().to_4x4()
            out.translation = c + (m.translation - c) * scale
            return out
        return c + (Vector(m) - c) * scale
    for key, (parts, pivot, parent) in list(groups.items()):
        for ob in parts:
            ob.matrix_world = S @ ob.matrix_world
        groups[key] = (parts, moved(pivot), parent)
    for key, (loc, parent) in list(empties.items()):
        empties[key] = (moved(loc), parent)


def add_hand(groups, empties, built, anchor_name, anchor_parent):
    """Adds a grip_hand() result to a weapon's groups/empties, with its grip
    anchor `anchor_name` (GripMain / GripUpper / GripLower) on `anchor_parent`."""
    groups.update(built["groups"])
    empties.update(built["empties"])
    empties[anchor_name] = (built["anchor"], anchor_parent)
