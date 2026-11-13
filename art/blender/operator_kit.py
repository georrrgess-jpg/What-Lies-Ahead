"""Character kit for the operators (see build_operators.py).

One shared "designer vinyl toy" body: a shaped head with a real face, a lofted
torso (shoulders, chest, waist), tapered limbs with ball joints, hands with
fingers and thumbs, shoes, and clothing built as layers (shells with
thickness, bands, straps and details laid on the surface they sit on).

How the pieces stay clean:
  * Limbs are rigid segments that share a sphere at every joint (the child's
    is a hair smaller), so elbows, knees, wrists and ankles never gap or
    collapse at any angle.
  * The torso (and everything on it) is skinned by height between Hips, Spine
    and Chest, so every layer bends together and nothing slides through.
  * Flat colours are baked into vertex colours together with a soft ambient
    occlusion, so a whole operator is one surface plus its glowing / Fx parts.
    UV.x carries roughness and UV.y metallic for scripts/cosmetics/operators.gd.

Axes: +X is the operator's left, -Y is forward, +Z is up; 1 unit = 1 m.
"""
import math
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import _finish, HERE, MODELS_DIR
from mathutils import Quaternion
from mathutils.bvhtree import BVHTree

# --- rest-pose landmarks (left side; mirror X for the right) -----------------
HIP = Vector((0.115, 0.0, 0.86))
KNEE = Vector((0.12, 0.0, 0.47))
ANKLE = Vector((0.125, 0.0, 0.10))
SHOULDER = Vector((0.305, 0.0, 1.31))
ELBOW = Vector((0.384, 0.0, 1.052))
WRIST = Vector((0.445, 0.0, 0.809))
HEAD_PIVOT = Vector((0.0, 0.005, 1.44))
HEAD_C = Vector((0.0, -0.005, 1.65))
HEAD_R = (0.25, 0.232, 0.232)

# Hand frame (left): x = back of the hand, y = toward the little finger, z = toward the elbow.
_F = (WRIST - ELBOW).normalized()
HAND_X = Vector((-_F.z, 0.0, _F.x))
HAND_Y = Vector((0.0, 1.0, 0.0))
HAND_Z = -_F
KNUCKLE_Z = -0.108
PIP_Z = -0.150
THUMB_BASE = (-0.012, -0.05, -0.034)
FINGER_Y = (-0.0405, -0.0135, 0.0135, 0.0405)
# Where a held grip sits in the fist, and the weapon origin above it (hand frame).
GRIP = Vector((-0.066, 0.0, -0.046))
SOCKET = Vector((-0.066, -0.13, -0.072))
GRIP_RAKE = 15.0      # degrees a weapon grip leans back from its barrel


HAND_SCALE = 1.14     # chunky toy hands; every hand-frame length is given before this scale


def hand_point(side, x, y, z):
    """Hand-frame coordinates -> armature space for the left (+1) or right (-1) hand."""
    p = WRIST + (HAND_X * x + HAND_Y * y + HAND_Z * z) * HAND_SCALE
    return Vector((p.x * side, p.y, p.z))


def sx(side, v):
    return Vector((v[0] * side, v[1], v[2]))


BONES = [
    # name, head, tail, parent
    ("Hips", (0, 0, 0.90), (0, 0, 1.02), None),
    ("Spine", (0, 0, 1.02), (0, 0, 1.20), "Hips"),
    ("Chest", (0, 0, 1.20), (0, 0, 1.38), "Spine"),
    ("Head", tuple(HEAD_PIVOT), (0, 0.005, 1.88), "Chest"),
]
for _side, _s in ((1, ".L"), (-1, ".R")):
    BONES += [
        ("UpperArm" + _s, tuple(sx(_side, SHOULDER)), tuple(sx(_side, ELBOW)), "Chest"),
        ("ForeArm" + _s, tuple(sx(_side, ELBOW)), tuple(sx(_side, WRIST)), "UpperArm" + _s),
        ("Hand" + _s, tuple(sx(_side, WRIST)), tuple(hand_point(_side, 0, 0, KNUCKLE_Z)), "ForeArm" + _s),
        ("Fingers" + _s, tuple(hand_point(_side, 0, 0, KNUCKLE_Z)), tuple(hand_point(_side, 0, 0, PIP_Z)), "Hand" + _s),
        ("Fingers2" + _s, tuple(hand_point(_side, 0, 0, PIP_Z)), tuple(hand_point(_side, 0, 0, PIP_Z - 0.04)), "Fingers" + _s),
        ("Thumb" + _s, tuple(hand_point(_side, *THUMB_BASE)), tuple(hand_point(_side, -0.03, -0.085, -0.075)), "Hand" + _s),
        ("Thigh" + _s, tuple(sx(_side, HIP)), tuple(sx(_side, KNEE)), "Hips"),
        ("Shin" + _s, tuple(sx(_side, KNEE)), tuple(sx(_side, ANKLE)), "Thigh" + _s),
        ("Foot" + _s, tuple(sx(_side, ANKLE)), (0.125 * _side, -0.17, 0.03), "Shin" + _s),
    ]

# Audit / shading regions per bone.
REGION = {"Hips": "torso", "Spine": "torso", "Chest": "torso", "Head": "head"}
for _s in (".L", ".R"):
    REGION.update({"UpperArm" + _s: "upperarm" + _s, "ForeArm" + _s: "forearm" + _s, "Hand" + _s: "hand" + _s,
                   "Fingers" + _s: "hand" + _s, "Fingers2" + _s: "hand" + _s, "Thumb" + _s: "hand" + _s,
                   "Thigh" + _s: "thigh" + _s, "Shin" + _s: "shin" + _s, "Foot" + _s: "foot" + _s})

THIGH_R = (0.096, 0.078)
SHIN_R = (0.076, 0.058)
SHADOW_TINT = (0.42, 0.34, 0.58)


# ---------------------------------------------------------------------------
# Shape helpers
# ---------------------------------------------------------------------------

def frame_from(a, b, x_hint=(1, 0, 0)):
    """4x4 frame at `a` whose +Z points to `b` and whose +X is closest to x_hint."""
    a, b = Vector(a), Vector(b)
    z = (b - a).normalized()
    x = Vector(x_hint)
    x = x - z * x.dot(z)
    if x.length < 1e-6:
        x = z.orthogonal()
    x.normalize()
    y = z.cross(x)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = a
    return m


def _catmull(p0, p1, p2, p3, u):
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3)


def dense_sections(sections, sub):
    """Catmull-Rom resample of [(t, rx, ry, ox, oy, n, gap)] rows."""
    rows = [list(s) + [0.0, 0.0, 2.0, 0.0][len(s) - 3:] for s in sections]
    if sub <= 1:
        return rows
    out = []
    for i in range(len(rows) - 1):
        p0, p1, p2, p3 = rows[max(i - 1, 0)], rows[i], rows[i + 1], rows[min(i + 2, len(rows) - 1)]
        for k in range(sub):
            u = k / sub
            out.append([_catmull(p0[j], p1[j], p2[j], p3[j], u) for j in range(7)])
    out.append(rows[-1])
    return out


def _superellipse(angle, rx, ry, n):
    c, s = math.cos(angle), math.sin(angle)
    e = 2.0 / n
    return rx * math.copysign(abs(c) ** e, c), ry * math.copysign(abs(s) ** e, s)


def loft(name, sections, m, segs=20, sub=2, frame=None, caps=("round", "round"), cap_h=(None, None),
         open_front=False, thickness=0.0, sharp=50.0, light_caps=False):
    """Smooth skin through cross-sections stacked along local +Z.

    sections: [(t, rx, ry[, ox, oy, n, gap_deg])]; n is the superellipse power
    (2 = ellipse, higher = boxier). caps: "round" (dome), "flat" or None per
    end. open_front leaves a slit of 2 * gap_deg facing -Y (jackets); with
    `thickness` the skin becomes a shell (Solidify, outward)."""
    rows = dense_sections(sections, sub)
    bm = bmesh.new()

    def ring(row, scale=1.0, dt=0.0):
        t, rx, ry, ox, oy, n, gap = row
        if open_front:
            a0, a1 = math.radians(-90 + gap), math.radians(270 - gap)
            angles = [a0 + (a1 - a0) * j / segs for j in range(segs + 1)]
        else:
            angles = [math.tau * j / segs for j in range(segs)]
        verts = []
        for a in angles:
            x, y = _superellipse(a, rx * scale, ry * scale, n)
            verts.append(bm.verts.new((x + ox, y + oy, t + dt)))
        return verts

    rings = []
    closed = not open_front
    if caps[0] == "round" and closed:
        h = cap_h[0] if cap_h[0] is not None else min(rows[0][1], rows[0][2])
        for a in ((58, 28) if light_caps else (68, 45, 22)):
            rings.append(ring(rows[0], math.cos(math.radians(a)), -h * math.sin(math.radians(a))))
    rings += [ring(r) for r in rows]
    if caps[1] == "round" and closed:
        h = cap_h[1] if cap_h[1] is not None else min(rows[-1][1], rows[-1][2])
        for a in ((28, 58) if light_caps else (22, 45, 68)):
            rings.append(ring(rows[-1], math.cos(math.radians(a)), h * math.sin(math.radians(a))))
    count = len(rings[0])
    for i in range(len(rings) - 1):
        for j in range(count if closed else count - 1):
            k = (j + 1) % count
            bm.faces.new((rings[i][j], rings[i][k], rings[i + 1][k], rings[i + 1][j]))
    if closed:
        for end, cap in ((0, caps[0]), (-1, caps[1])):
            if cap is None:
                continue
            row = rows[end]
            if cap == "round":
                h = cap_h[0 if end == 0 else 1]
                h = h if h is not None else min(row[1], row[2])
                pole = bm.verts.new((row[3], row[4], row[0] + (h if end else -h)))
                edge = rings[end]
                for j in range(count):
                    k = (j + 1) % count
                    bm.faces.new((edge[k], edge[j], pole) if end == 0 else (edge[j], edge[k], pole))
            else:
                bm.faces.new(list(reversed(rings[0])) if end == 0 else rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish(name, bm, m, (0, 0, 0), (0, 0, 0))
    if frame is not None:
        ob.matrix_basis = frame
    if thickness > 0.0:
        solid = ob.modifiers.new("Solidify", "SOLIDIFY")
        solid.thickness = thickness
        solid.offset = 1.0
        solid.use_even_offset = True
        bev = ob.modifiers.new("Bevel", "BEVEL")
        bev.width = thickness * 0.3
        bev.segments = 2
        bev.limit_method = "ANGLE"
        bev.angle_limit = math.radians(60)
    if sharp:
        ob.data.set_sharp_from_angle(angle=math.radians(sharp))
    return ob


def limb(name, a, b, ra, rb, m, bulge=0.0, segs=14, squash=1.0, n=2.0, x_hint=(1, 0, 0), caps=("round", "round"), light=False):
    """Tapered segment from a to b with domed ends (the domes are the ball joints).
    light=True keeps only the end rings (fingers)."""
    length = (Vector(b) - Vector(a)).length
    secs = []
    for f in ((0.0, 1.0) if light else (0.0, 0.25, 0.5, 0.75, 1.0)):
        r = (ra + (rb - ra) * f) * (1.0 + bulge * 4.0 * f * (1.0 - f))
        secs.append((length * f, r, r * squash, 0.0, 0.0, n))
    return loft(name, secs, m, segs=segs, sub=1, frame=frame_from(a, b, x_hint), caps=caps, light_caps=light,
                cap_h=(ra if caps[0] == "round" else None, rb if caps[1] == "round" else None))


def band(name, a, b, f0, f1, r0, r1, m, segs=16, squash=1.0, n=2.0, x_hint=(1, 0, 0), lip=0.3):
    """A cuff / strap around a limb axis a->b between fractions f0..f1, with softened edges."""
    length = (Vector(b) - Vector(a)).length
    t0, t1 = length * f0, length * f1
    e = (t1 - t0) * lip
    secs = [(t0, r0 * 0.9, r0 * 0.9 * squash, 0, 0, n), (t0 + e * 0.4, r0, r0 * squash, 0, 0, n),
            (t1 - e * 0.4, r1, r1 * squash, 0, 0, n), (t1, r1 * 0.9, r1 * 0.9 * squash, 0, 0, n)]
    return loft(name, secs, m, segs=segs, sub=1, frame=frame_from(a, b, x_hint), caps=("flat", "flat"), sharp=70.0)


def shaped(name, fn, m, segs=28, rings=18, loc=(0, 0, 0)):
    """A sphere whose every direction is mapped through fn(unit Vector) -> point."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = fn(v.co.normalized())
    return _finish(name, bm, m, loc, (0, 0, 0))


def blob(name, radius, loc, m, scale=(1, 1, 1), rot=(0, 0, 0), segs=14, rings=9):
    return sphere(name, radius, loc, scale=scale, rot=rot, m=m, segs=segs, rings=rings)


def head_shape(rx=HEAD_R[0], ry=HEAD_R[1], rz=HEAD_R[2], n=2.5, jaw=0.2, grow=0.0):
    """Rounded head: boxy-soft superellipsoid, narrower toward the chin."""
    e = 2.0 / n

    def fn(d):
        x = rx * math.copysign(abs(d.x) ** e, d.x)
        y = ry * math.copysign(abs(d.y) ** e, d.y)
        z = rz * math.copysign(abs(d.z) ** e, d.z)
        if z < 0.0:
            k = (-z / rz) ** 1.6
            x *= 1.0 - jaw * k
            y *= 1.0 - jaw * 0.4 * k
        p = Vector((x, y, z))
        return p * (1.0 + grow) if grow else p
    return fn


def open_shell(name, radius, loc, opening_deg, m, scale=(1, 1, 1), segs=24, rings=14, thickness=0.02, toward=(0, -1, 0)):
    """A hollow sphere (helmet, hood) with a round opening facing `toward`, so the face inside shows."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    axis = Vector(toward).normalized()
    limit = math.cos(math.radians(opening_deg))
    doomed = [f for f in bm.faces if f.calc_center_median().normalized().dot(axis) > limit]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    ob = _finish(name, bm, m, loc, (0, 0, 0))
    solid = ob.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = thickness
    solid.offset = 1.0
    return ob


def ellipse_outline(cx, cz, rx, rz, count=18, rot=0.0, power=2.0):
    out = []
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    for i in range(count):
        x, z = _superellipse(math.tau * i / count, rx, rz, power)
        out.append((cx + x * c - z * s, cz + x * s + z * c))
    return out


def arc_path(cx, cz, radius, a0, a1, width, steps=10, taper=0.25, rz=None):
    """Points along an arc as (x, z, half_width), thinning to `taper` at both ends."""
    out = []
    for i in range(steps + 1):
        f = i / steps
        a = math.radians(a0 + (a1 - a0) * f)
        w = width * 0.5 * (taper + (1.0 - taper) * math.sin(math.pi * f) ** 0.6)
        out.append((cx + math.cos(a) * radius, cz + math.sin(a) * (radius if rz is None else rz), w))
    return out


def line_path(p0, p1, width, steps=4, taper=1.0):
    out = []
    for i in range(steps + 1):
        f = i / steps
        w = width * 0.5 * (taper + (1.0 - taper) * math.sin(math.pi * f) ** 0.6)
        out.append((p0[0] + (p1[0] - p0[0]) * f, p0[1] + (p1[1] - p0[1]) * f, w))
    return out


class Surface:
    """Ray-cast access to baked parts, for laying details on the surface they sit on."""

    def __init__(self, objects):
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        verts, polys = [], []
        for ob in objects:
            ev = ob.evaluated_get(dg)
            me = ev.to_mesh()
            off = len(verts)
            verts += [ob.matrix_world @ v.co for v in me.vertices]
            polys += [[off + i for i in p.vertices] for p in me.polygons]
            ev.to_mesh_clear()
        self.bvh = BVHTree.FromPolygons(verts, polys)

    def cast(self, origin, direction):
        loc, normal, _i, _d = self.bvh.ray_cast(Vector(origin), Vector(direction).normalized())
        if loc is None:
            loc, normal, _i, _d = self.bvh.find_nearest(Vector(origin))
        return loc, normal

    def projector(self, direction, distance=3.0):
        """(u, v) -> (point, normal): rays along `direction` ("front", "back", "left", "right": u across, v = height;
        "top": u = x, v = y)."""
        def proj(u, v):
            if direction == "front":
                return self.cast((u, -distance, v), (0, 1, 0))
            if direction == "back":
                return self.cast((u, distance, v), (0, -1, 0))
            if direction == "left":
                return self.cast((distance, u, v), (-1, 0, 0))
            if direction == "top":
                return self.cast((u, v, distance), (0, 0, -1))
            return self.cast((-distance, u, v), (1, 0, 0))
        return proj

    def inward(self, point, target):
        return self.cast(point, Vector(target) - Vector(point))


def decal(name, outline, proj, m, lift=0.004, sink=0.006, inset=0.2, dome=0.0):
    """A raised sticker-like shape wrapped onto a surface. `outline` is a list of
    (u, v) that its centre can see (ellipses, stars, rounded rectangles)."""
    bm = bmesh.new()
    n = len(outline)
    cu = sum(p[0] for p in outline) / n
    cv = sum(p[1] for p in outline) / n

    def at(u, v, h):
        loc, nor = proj(u, v)
        return bm.verts.new(loc + nor * h)

    rings = [[at(u, v, -sink) for u, v in outline], [at(u, v, lift * 0.55) for u, v in outline],
             [at(cu + (u - cu) * (1 - inset), cv + (v - cv) * (1 - inset), lift + dome * 0.6) for u, v in outline]]
    if dome > 0.0:
        rings.append([at(cu + (u - cu) * 0.45, cv + (v - cv) * 0.45, lift + dome) for u, v in outline])
    centre = at(cu, cv, lift + dome)
    for i in range(n):
        j = (i + 1) % n
        for a, b in zip(rings, rings[1:]):
            bm.faces.new((a[i], a[j], b[j], b[i]))
        bm.faces.new((rings[-1][i], rings[-1][j], centre))
    _face_outward(bm, proj(cu, cv)[1])
    ob = _finish(name, bm, m, (0, 0, 0), (0, 0, 0))
    ob.data.set_sharp_from_angle(angle=math.radians(55))
    ob["open"] = True      # no underside: left out of the audit's inside tests
    return ob


def _face_outward(bm, normal):
    """Flips an open, consistently wound cap so its top faces along `normal`."""
    bm.normal_update()
    bm.faces.ensure_lookup_table()
    if bm.faces[-1].normal.dot(normal) < 0.0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)


def strip(name, path, proj, m, lift=0.004, sink=0.006):
    """A raised band following `path` [(u, v, half_width)] over a surface."""
    bm = bmesh.new()
    rows = []
    count = len(path)
    for i, (u, v, w) in enumerate(path):
        u0, v0, _ = path[max(i - 1, 0)]
        u1, v1, _ = path[min(i + 1, count - 1)]
        t = Vector((u1 - u0, v1 - v0))
        if t.length < 1e-9:
            t = Vector((1, 0))
        t.normalize()
        nx, nz = -t.y, t.x
        row = []
        for k, h in ((-1.0, -sink), (-1.0, lift * 0.5), (-0.6, lift), (0.6, lift), (1.0, lift * 0.5), (1.0, -sink)):
            loc, nor = proj(u + nx * w * k, v + nz * w * k)
            row.append(bm.verts.new(loc + nor * h))
        rows.append(row)
    for i in range(count - 1):
        a, b = rows[i], rows[i + 1]
        for k in range(5):
            bm.faces.new((a[k], a[k + 1], b[k + 1], b[k]))
        bm.faces.new((a[5], a[0], b[0], b[5]))
    bm.faces.new(rows[0])
    bm.faces.new(list(reversed(rows[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish(name, bm, m, (0, 0, 0), (0, 0, 0))
    ob.data.set_sharp_from_angle(angle=math.radians(55))
    return ob


def ribbon(name, points, normals, width, thick, m):
    """A flat strap through 3D points; `normals` point away from the body."""
    bm = bmesh.new()
    rows = []
    count = len(points)
    for i in range(count):
        p = Vector(points[i])
        t = (Vector(points[min(i + 1, count - 1)]) - Vector(points[max(i - 1, 0)])).normalized()
        nor = Vector(normals[i]).normalized()
        side = t.cross(nor).normalized()
        nor = side.cross(t).normalized()
        w = (width[i] if isinstance(width, (list, tuple)) else width) * 0.5
        rows.append([bm.verts.new(p + side * w * k + nor * h) for k, h in
                     ((-1, -thick), (-1, thick * 0.5), (-0.7, thick), (0.7, thick), (1, thick * 0.5), (1, -thick))])
    for i in range(count - 1):
        a, b = rows[i], rows[i + 1]
        for k in range(5):
            bm.faces.new((a[k], a[k + 1], b[k + 1], b[k]))
        bm.faces.new((a[5], a[0], b[0], b[5]))
    bm.faces.new(rows[0])
    bm.faces.new(list(reversed(rows[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish(name, bm, m, (0, 0, 0), (0, 0, 0))
    ob.data.set_sharp_from_angle(angle=math.radians(55))
    return ob


def rrect(cx, cz, w, h, r=None, steps=3):
    """Rounded-rectangle outline around (cx, cz)."""
    r = min(w, h) * 0.3 if r is None else r
    out = []
    for qx, qz, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for i in range(steps + 1):
            a = math.radians(a0 + 90 * i / steps)
            out.append((cx + qx * (w / 2 - r) + math.cos(a) * r, cz + qz * (h / 2 - r) + math.sin(a) * r))
    return out


def star_at(cx, cz, outer, inner=None, points=5, rotation=90.0):
    return [(cx + x, cz + z) for x, z in star_outline(outer, inner, points, rotation)]


# ---------------------------------------------------------------------------
# The kit
# ---------------------------------------------------------------------------

class Kit:
    """Collects the parts of one operator. Builders add tagged parts; finish()
    in build_operators.py skins, bakes and exports them."""

    def __init__(self, prefix, skin_hex, build=None):
        self.p = prefix
        self.parts = []
        self.b = dict(shoulder=1.0, chest=1.0, waist=1.0, hip=1.0, depth=1.0, belly=0.0, arm=1.0, leg=1.0)
        self.b.update(build or {})
        self.skin_m = mat("Skin", skin_hex, rough=0.55)
        self.extra_bones = []
        self._torso_layers = []
        self._torso_surface = None
        self._head_layers = []
        self._head_surface = None
        self._torso_rows = dense_sections(self.torso_sections(), 4)
        self.shells = []

    # --- bookkeeping ---------------------------------------------------------
    def add(self, parts, bone=None, field=False, tag="", occlude=True, region=None, blend=None):
        """Registers parts. `bone` binds them rigidly; field=True skins them by
        height across Hips / Spine / Chest (everything worn on the torso);
        blend=(upper bone, lower bone, z_high, z_low) fades between two bones by
        height (capes). `region` names the audit / shading group."""
        if not isinstance(parts, (list, tuple)):
            parts = [parts]
        for ob in parts:
            ob["bone"] = bone or (blend[0] if blend else "")
            ob["field"] = bool(field)
            ob["tag"] = tag
            ob["occlude"] = bool(occlude)
            if region:
                ob["region"] = region
            if blend:
                ob["blend"] = "|".join(str(v) for v in blend)
            self.parts.append(ob)
        return list(parts)

    def n(self, name):
        return self.p + name

    # --- torso ---------------------------------------------------------------
    def torso_sections(self):
        b = self.b
        s, c, w, h, d, belly = b["shoulder"], b["chest"], b["waist"], b["hip"], b["depth"], b["belly"]
        return [
            (0.8, 0.205 * h, 0.118 * d, 0, 0.0, 2.7),
            (0.86, 0.226 * h, 0.134 * d, 0, 0.0, 2.6),
            (0.94, 0.216 * h, 0.134 * d * (1 + belly * 0.25), 0, -0.01 * belly, 2.5),
            (1.03, 0.184 * w, 0.118 * d * (1 + belly * 0.6), 0, -0.03 * belly, 2.4),
            (1.14, 0.214 * c, 0.134 * d * (1 + belly * 0.35), 0, -0.006 - 0.02 * belly, 2.4),
            (1.25, 0.248 * s, 0.146 * d, 0, -0.008, 2.5),
            (1.325, 0.243 * s, 0.128 * d, 0, 0.0, 2.6),
            (1.368, 0.125, 0.092, 0, 0.004, 2.2),
        ]

    def torso_at(self, z):
        """(rx, ry, ox, oy, n) of the bare torso at height z."""
        rows = self._torso_rows
        if z <= rows[0][0]:
            return rows[0][1:6]
        for a, b in zip(rows, rows[1:]):
            if a[0] <= z <= b[0]:
                f = (z - a[0]) / max(b[0] - a[0], 1e-9)
                return [a[j] + (b[j] - a[j]) * f for j in range(1, 6)]
        return rows[-1][1:6]

    def outer_grow(self, z):
        return max([g for z0, z1, g in self.shells if z0 <= z <= z1] + [0.0])

    def torso_point(self, z, angle_deg, out=0.0):
        """Point on the outermost torso layer at height z; 270 deg = front, 0 = the left side."""
        rx, ry, ox, oy, n = self.torso_at(z)
        g = self.outer_grow(z) + out
        x, y = _superellipse(math.radians(angle_deg), rx + g, ry + g, n)
        return Vector((x + ox, y + oy, z))

    def torso(self, m, lower_m=None, split_z=0.985):
        """Bare torso (shirt colour). lower_m colours the part below split_z (trousers)."""
        secs = self.torso_sections()
        if lower_m is None:
            parts = [loft(self.n("Torso"), secs, m, segs=24, sub=3, cap_h=(0.035, 0.03))]
        else:
            lo = [s for s in secs if s[0] < split_z] + [(split_z,) + tuple(self.torso_at(split_z))]
            hi = [(split_z - 0.02,) + tuple(self.torso_at(split_z - 0.02))] + [s for s in secs if s[0] > split_z]
            parts = [loft(self.n("Pelvis"), lo, lower_m, segs=24, sub=3, caps=("round", "flat"), cap_h=(0.035, None)),
                     loft(self.n("Torso"), [(r[0], r[1] + 0.004, r[2] + 0.004) + tuple(r[3:]) for r in hi], m, segs=24, sub=3,
                          caps=("flat", "round"), cap_h=(None, 0.03))]
        self._torso_layers += parts
        self._torso_surface = None
        return self.add(parts, field=True, tag="torso")

    def neck(self, m=None, r=0.07):
        return self.add(loft(self.n("Neck"), [(1.33, r * 1.15, r * 1.1), (1.39, r, r * 0.96), (1.5, r, r * 0.96)], m or self.skin_m,
                             segs=14, sub=2), bone="Chest", tag="neck")

    def shell(self, name, z0, z1, m, grow=0.012, thickness=0.012, gap=None, flare=0.0, segs=28, top_in=0.0):
        """A clothing layer hugging the torso between z0 and z1. `gap` gives the
        half-opening in degrees at (bottom, top) for an open front (jackets);
        flare widens the hem; top_in pulls the top edge toward the neck."""
        steps = max(4, int((z1 - z0) / 0.035))
        secs = []
        for i in range(steps + 1):
            f = i / steps
            z = z0 + (z1 - z0) * f
            rx, ry, ox, oy, n = self.torso_at(z)
            g = grow + flare * (1.0 - f) ** 2 - top_in * f ** 3
            row = [z, rx + g, ry + g, ox, oy, n]
            if gap is not None:
                row.append(gap[0] + (gap[1] - gap[0]) * f ** 1.5)
            secs.append(tuple(row))
        ob = loft(self.n(name), secs, m, segs=segs, sub=1, caps=(None, None), open_front=gap is not None, thickness=thickness)
        self.shells.append((z0, z1, grow + thickness + flare * 0.3))
        self._torso_layers.append(ob)
        self._torso_surface = None
        return self.add(ob, field=True, tag="shell")

    def belt(self, z, height, m, grow=0.006, name="Belt"):
        """A band around the outermost layer at height z."""
        g = self.outer_grow(z) + grow
        secs = []
        for dz, k in ((-height / 2, 0.75), (-height / 2 + height * 0.18, 1.0), (height / 2 - height * 0.18, 1.0), (height / 2, 0.75)):
            rx, ry, ox, oy, n = self.torso_at(z + dz)
            secs.append((z + dz, rx + g * k, ry + g * k, ox, oy, n))
        ob = loft(self.n(name), secs, m, segs=28, sub=1, caps=("flat", "flat"), sharp=70.0)
        self.shells.append((z - height / 2, z + height / 2, g))
        self._torso_layers.append(ob)
        self._torso_surface = None
        return self.add(ob, field=True, tag="belt")

    def torso_surface(self):
        if self._torso_surface is None:
            self._torso_surface = Surface(self._torso_layers)
        return self._torso_surface

    def on_torso(self, direction="front"):
        return self.torso_surface().projector(direction)

    def strap(self, name, points, width, m, thick=0.006, lift=0.004):
        """A strap hugging the torso through rough 3D points (each is pulled onto the surface)."""
        surf = self.torso_surface()
        pts, nors = [], []
        for p in points:
            p = Vector(p)
            target = Vector((p.x * 0.3, 0.0, min(max(p.z, 0.95), 1.27)))
            loc, _nor = surf.inward(p + (p - target).normalized() * 0.5, target)
            out = (p - target).normalized()
            pts.append(loc + out * (lift + thick))
            nors.append(out)
        return self.add(ribbon(self.n(name), pts, nors, width, thick, m), field=True, tag="strap")

    # --- head ------------------------------------------------------------------
    def head(self, m=None, ears=True, jaw=0.2, n=2.5, ear_m=None):
        m = m or self.skin_m
        self.head_fn = head_shape(jaw=jaw, n=n)
        skull = shaped(self.n("Head"), self.head_fn, m, segs=28, rings=18, loc=HEAD_C)
        parts = [skull]
        self._head_layers = [skull]
        self._head_surface = None
        if ears:
            for side in (1, -1):
                x = side * (HEAD_R[0] - 0.012)
                parts.append(blob(self.n(f"Ear{side}"), 0.05, (x, 0.015, HEAD_C.z - 0.015), ear_m or m, scale=(0.5, 0.62, 1.0),
                                  rot=rad(0, side * -12, side * 16)))
        return self.add(parts, bone="Head", tag="head")

    def head_radius(self, z):
        """(rx, ry) of the bare head at height z above its centre."""
        best = None
        for i in range(-60, 61):
            a = math.radians(i * 1.5)
            px = self.head_fn(Vector((math.cos(a), 0.0, math.sin(a))))
            if best is None or abs(px.z - z) < abs(best[0].z - z):
                best = (px, self.head_fn(Vector((0.0, math.cos(a), math.sin(a)))))
        return best[0].x, best[1].y

    def head_band(self, name, z0, z1, m, grow=0.012, steps=3, tag="headgear", lip=True):
        """A band hugging the head between heights z0..z1 (above the head centre): hat bands, visors, goggle straps."""
        secs = []
        for i in range(steps + 1):
            z = z0 + (z1 - z0) * i / steps
            rx, ry = self.head_radius(z)
            k = 0.8 if lip and i in (0, steps) else 1.0
            secs.append((z, rx + grow * k, ry + grow * k, 0, 0, 2.5))
        ob = loft(self.n(name), secs, m, segs=28, sub=1, frame=Matrix.Translation(HEAD_C), caps=("flat", "flat"), sharp=70.0)
        return self.add(ob, bone="Head", tag=tag)

    def head_surface(self):
        if self._head_surface is None:
            self._head_surface = Surface(self._head_layers)
        return self._head_surface

    def on_face(self, direction="front"):
        return self.head_surface().projector(direction)

    def face(self, iris="#3a2a1e", brow="#3d2318", mouth="smile", lids=0.18, brow_tilt=8.0, blush="#ff8fa6", eye_z=0.012,
             eye_x=0.098, eye_w=0.082, eye_h=0.098, nose=True, lash="#2a1c22", gaze=(0.0, 0.0), brow_z=0.085, freckles=False,
             mouth_z=-0.105, brow_w=0.1, eyes=True):
        """Big toy eyes with lids, lashes and shine, brows, a nose and a mouth, all
        wrapped onto the head. mouth: smile, grin, smirk, open, flat or none."""
        proj = self.on_face()
        z0 = HEAD_C.z
        white = mat("EyeWhite", "#fffaf2", rough=0.3)
        iris_m = mat("Iris", iris, rough=0.25)
        pupil = mat("Pupil", "#120c18", rough=0.2)
        shine = mat("EyeShine", "#ffffff", rough=0.1, emit=1.2)
        brow_m = mat("Brow", brow, rough=0.7)
        lash_m = mat("Lash", lash, rough=0.6)
        parts = []
        for side in (1, -1):
            x, z = side * eye_x, z0 + eye_z
            gx, gz = x + gaze[0] * 0.012 + side * -0.004, z + gaze[1] * 0.012 - 0.004
            parts += [] if not eyes else [
                decal(self.n(f"Eye{side}"), ellipse_outline(x, z, eye_w / 2, eye_h / 2, 16, power=2.3), proj, white, lift=0.004, dome=0.006),
                decal(self.n(f"Iris{side}"), ellipse_outline(gx, gz, eye_w * 0.36, eye_h * 0.37, 12), proj, iris_m, lift=0.0125, sink=0.0, dome=0.002),
                decal(self.n(f"Pupil{side}"), ellipse_outline(gx, gz, eye_w * 0.2, eye_h * 0.22, 10), proj, pupil, lift=0.0165, sink=0.0, dome=0.001),
                decal(self.n(f"Shine{side}"), ellipse_outline(gx + 0.016, gz + 0.02, 0.0095, 0.0105, 7), proj, shine, lift=0.0195, sink=0.0),
                decal(self.n(f"ShineB{side}"), ellipse_outline(gx - 0.013, gz - 0.018, 0.005, 0.0055, 6), proj, shine, lift=0.0195, sink=0.0),
            ]
            # Upper lid (skin) and lash line give the eyes their expression.
            if not eyes:
                pass
            elif lids > 0.0:
                lid_z = z + eye_h * (0.5 - lids)
                lid = [(x + side * -eye_w * 0.56, lid_z - 0.004), (x + side * eye_w * 0.58, lid_z + 0.006 - side * 0.0)]
                arc = [(x + math.cos(math.radians(a)) * eye_w * 0.56, z + math.sin(math.radians(a)) * eye_h * 0.56) for a in range(0, 181, 20)]
                arc = [p for p in arc if p[1] > lid_z]
                outline = ([lid[1]] + arc + [lid[0]]) if side > 0 else ([lid[0]] + list(reversed(arc)) + [lid[1]])
                if len(outline) >= 4:
                    parts.append(decal(self.n(f"Lid{side}"), outline if side > 0 else list(reversed(outline)), proj, self.skin_m,
                                       lift=0.0215, sink=0.004, inset=0.12))
                parts.append(strip(self.n(f"Lash{side}"), line_path((x - side * eye_w * 0.56, lid_z - 0.004), (x + side * eye_w * 0.62, lid_z + 0.008),
                                                                   0.011, steps=5, taper=0.5), proj, lash_m, lift=0.024, sink=0.004))
            else:
                parts.append(strip(self.n(f"Lash{side}"), arc_path(x, z, eye_w * 0.55, 20 if side > 0 else 160, 160 if side > 0 else 20, 0.01,
                                                                   steps=8, rz=eye_h * 0.55), proj, lash_m, lift=0.008, sink=0.004))
            if brow:
                bz = z0 + brow_z + eye_z
                t = math.radians(brow_tilt)
                p0 = (x - side * brow_w * 0.5, bz - math.sin(t) * brow_w * 0.5)
                p1 = (x + side * brow_w * 0.5, bz + math.sin(t) * brow_w * 0.5)
                pm = (x, bz + 0.012)
                path = [(p0[0], p0[1], 0.012), ((p0[0] + pm[0]) / 2, (p0[1] + pm[1]) / 2 + 0.003, 0.0135), (pm[0], pm[1], 0.013),
                        ((p1[0] + pm[0]) / 2, (p1[1] + pm[1]) / 2 + 0.003, 0.011), (p1[0], p1[1], 0.006)]
                parts.append(strip(self.n(f"Brow{side}"), path, proj, brow_m, lift=0.009, sink=0.004))
            if blush:
                parts.append(decal(self.n(f"Blush{side}"), ellipse_outline(side * 0.158, z0 - 0.058, 0.034, 0.02, 14), proj,
                                   mat("Blush", blush, rough=0.6), lift=0.0025, sink=0.002, inset=0.3))
            if freckles:
                for i, (fx, fz) in enumerate(((0.12, -0.045), (0.145, -0.035), (0.17, -0.048))):
                    parts.append(decal(self.n(f"Freckle{side}{i}"), ellipse_outline(side * fx, z0 + fz, 0.006, 0.006, 8), proj,
                                       mat("Freckle", "#a8623f", rough=0.6), lift=0.004, sink=0.002))
        if nose:
            loc, nor = proj(0.0, z0 - 0.04)
            parts.append(blob(self.n("Nose"), 0.034, loc + nor * 0.004, self.warm_skin(), scale=(1.0, 0.8, 0.82)))
        parts += self.mouth(mouth, mouth_z)
        return self.add(parts, bone="Head", tag="face")

    def warm_skin(self):
        """The skin colour, a little rosier (noses, ears, knuckles)."""
        base = self.skin_m.diffuse_color
        name = "SkinWarm"
        if name not in bpy.data.materials:
            m = self.skin_m.copy()
            m.name = name
            rgb = (min(base[0] * 1.06, 1.0), base[1] * 0.86, base[2] * 0.84)
            m.diffuse_color = (*rgb, 1.0)
            bsdf = next(nd for nd in m.node_tree.nodes if nd.type == "BSDF_PRINCIPLED")
            bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        return bpy.data.materials[name]

    def mouth(self, kind, mz=-0.105, proj=None):
        proj = proj or self.on_face()
        z = HEAD_C.z + mz
        dark = mat("Mouth", "#5a1a2e", rough=0.5)
        teeth = mat("Teeth", "#fffaf2", rough=0.3)
        tongue = mat("Tongue", "#ff6f8a", rough=0.5)
        parts = []
        if kind == "smile":
            parts.append(strip(self.n("Smile"), arc_path(0, z + 0.05, 0.062, 222, 318, 0.016, steps=10), proj, dark, lift=0.006, sink=0.004))
        elif kind == "smirk":
            parts.append(strip(self.n("Smirk"), arc_path(0.012, z + 0.045, 0.056, 236, 318, 0.016, steps=9), proj, dark, lift=0.006, sink=0.004))
        elif kind == "flat":
            parts.append(strip(self.n("MouthLine"), line_path((-0.036, z), (0.036, z + 0.003), 0.014, steps=5, taper=0.4), proj, dark,
                               lift=0.006, sink=0.004))
        elif kind == "open":
            parts.append(decal(self.n("MouthO"), ellipse_outline(0, z, 0.026, 0.022, 14), proj, dark, lift=0.005, sink=0.004))
        elif kind == "grin":
            top = [(0.058 * math.cos(math.radians(a)), z + 0.014 + 0.006 * math.sin(math.radians(a))) for a in range(0, 181, 30)]
            bottom = [(0.058 * math.cos(math.radians(a)), z + 0.014 + 0.046 * math.sin(math.radians(a))) for a in range(200, 341, 20)]
            parts.append(decal(self.n("Grin"), top + bottom, proj, dark, lift=0.005, sink=0.004, inset=0.1))
            parts.append(strip(self.n("TeethTop"), arc_path(0, z + 0.052, 0.062, 232, 308, 0.02, steps=8, taper=0.5, rz=0.045), proj, teeth,
                               lift=0.0085, sink=0.0))
            parts.append(decal(self.n("Tongue"), ellipse_outline(0, z - 0.017, 0.024, 0.011, 12), proj, tongue, lift=0.0085, sink=0.0))
        return parts

    def hair_cap(self, m, hairline, grow=0.045, volume=None, name="Hair", segs=32, rings=8, tag="hair", occlude=True):
        """Moulded hair: the head shape pushed out by `grow`, from the crown down
        to `hairline(azimuth)` (a direction height -1..1; azimuth 0 = front,
        +-pi = back), where it tucks into the head. volume(d) adds thickness."""
        base = self.head_fn
        bm = bmesh.new()

        def point(d, edge=1.0):
            return base(d) * (1.0 + (grow + (volume(d) if volume else 0.0)) * edge)
        top = bm.verts.new(point(Vector((0, 0, 1))))
        cols = []
        for j in range(segs):
            az = -math.pi + math.tau * j / segs
            low = math.asin(min(max(hairline(az), -0.95), 0.95))
            col = []
            for i in range(1, rings + 1):
                el = math.pi / 2 - (math.pi / 2 - low) * i / rings
                d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
                col.append(bm.verts.new(point(d, 1.0 if i < rings else 0.5)))
            col.append(bm.verts.new(base(d) * 0.92))
            cols.append(col)
        centre = bm.verts.new((0, 0, 0))
        for j in range(segs):
            a, b = cols[j], cols[(j + 1) % segs]
            bm.faces.new((top, a[0], b[0]))
            for i in range(rings):
                bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
            bm.faces.new((a[-1], centre, b[-1]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ob = _finish(self.n(name), bm, m, HEAD_C, (0, 0, 0))
        self._head_layers.append(ob)
        self._head_surface = None
        return self.add(ob, bone="Head", tag=tag, occlude=occlude)

    # --- limbs -----------------------------------------------------------------
    def upper_arm(self, side, m, r0=0.08, r1=0.066, bulge=0.05, name="UpperArm"):
        k = self.b["arm"]
        s = "L" if side > 0 else "R"
        return self.add(limb(self.n(name + s), sx(side, SHOULDER), sx(side, ELBOW), r0 * k, r1 * k, m, bulge=bulge),
                        bone="UpperArm." + s, tag="arm")

    def fore_arm(self, side, m, r0=0.0635, r1=0.05, bulge=0.07, name="ForeArm"):
        k = self.b["arm"]
        s = "L" if side > 0 else "R"
        return self.add(limb(self.n(name + s), sx(side, ELBOW), sx(side, WRIST), r0 * k, r1 * min(k, 1.15), m, bulge=bulge),
                        bone="ForeArm." + s, tag="arm")

    def arm_band(self, side, part, f0, f1, m, grow=0.008, name="Band", taper=None):
        """A cuff around the upper arm ("UpperArm") or forearm between fractions f0..f1."""
        k = self.b["arm"]
        s = "L" if side > 0 else "R"
        a, b, ra, rb, bulge = ((SHOULDER, ELBOW, 0.08 * k, 0.066 * k, 0.05) if part == "UpperArm" else
                               (ELBOW, WRIST, 0.0635 * k, 0.05 * min(k, 1.15), 0.07))

        def radius(f):
            return (ra + (rb - ra) * f) * (1.0 + bulge * 4.0 * f * (1.0 - f)) + grow
        r0, r1 = radius(f0), radius(f1)
        if taper:
            r0, r1 = r0 + taper[0], r1 + taper[1]
        return self.add(band(self.n(f"{name}{part}{s}"), sx(side, a), sx(side, b), f0, f1, r0, r1, m), bone=part + "." + s, tag="arm")

    def sleeve(self, side, m, length=0.55, grow=0.009, hem_m=None):
        """A short sleeve over the top of the upper arm, with a hem band."""
        k = self.b["arm"]
        s = "L" if side > 0 else "R"
        a, b = sx(side, SHOULDER), sx(side, SHOULDER.lerp(ELBOW, length))
        parts = [limb(self.n("Sleeve" + s), a, b, 0.08 * k + grow, 0.071 * k + grow, m, bulge=0.04, caps=("round", "flat"))]
        self.add(parts, bone="UpperArm." + s, tag="arm")
        if hem_m:
            self.arm_band(side, "UpperArm", length - 0.09, length + 0.01, hem_m, grow=grow + 0.004, name="Hem")
        return parts

    def hand(self, side, m, plate_m=None, mitten=False, palm_m=None):
        """Wrist ball, palm, four fingers in two segments, and a two-segment thumb.
        Fingers follow the Fingers / Fingers2 bones (curl), the thumb follows Thumb."""
        s = "L" if side > 0 else "R"
        k = HAND_SCALE

        def P(x, y, z):
            return hand_point(side, x, y, z)
        hint = sx(side, HAND_X)
        down = frame_from(P(0, 0, 0), P(0, 0, -1), hint)
        palm_secs = [(0.0, 0.0215 * k, 0.036 * k, 0, 0, 2.6), (0.03 * k, 0.0255 * k, 0.05 * k, 0, 0, 2.8),
                     (0.075 * k, 0.0255 * k, 0.055 * k, 0, 0, 3.0), (0.112 * k, 0.022 * k, 0.054 * k, 0, 0, 3.0)]
        hand_parts = [
            blob(self.n("WristBall" + s), 0.047, P(0, 0, 0), m, segs=10, rings=6),
            loft(self.n("Palm" + s), palm_secs, palm_m or m, segs=12, sub=1, frame=down, caps=("round", "round"), cap_h=(0.02, 0.012),
                 light_caps=True),
        ]
        if plate_m:
            hand_parts.append(loft(self.n("Plate" + s), [(0.03 * k, 0.012, 0.04 * k, 0.02 * k, 0, 3.0), (0.09 * k, 0.012, 0.044 * k, 0.02 * k, 0, 3.0)],
                                   plate_m, segs=10, sub=1, frame=down, caps=("round", "round"), cap_h=(0.006, 0.006), light_caps=True))
        prox, dist = [], []
        if mitten:
            prox.append(loft(self.n("MittA" + s), [(0.0, 0.025 * k, 0.055 * k, 0, 0, 2.8), (0.045 * k, 0.0255 * k, 0.055 * k, 0, 0, 2.8)], m, segs=12,
                             sub=1, frame=frame_from(P(0, 0, KNUCKLE_Z), P(0, 0, PIP_Z), hint), cap_h=(0.022, 0.022)))
            dist.append(loft(self.n("MittB" + s), [(0.0, 0.0245 * k, 0.054 * k, 0, 0, 2.8), (0.03 * k, 0.023 * k, 0.051 * k, 0, 0, 2.6),
                                                   (0.05 * k, 0.018 * k, 0.041 * k, 0, 0, 2.4)],
                             m, segs=12, sub=2, frame=frame_from(P(0, 0, PIP_Z), P(-0.012, 0, PIP_Z - 0.06), hint), cap_h=(0.022, 0.02)))
        else:
            for i, y in enumerate(FINGER_Y):
                r = (0.0138, 0.0142, 0.0138, 0.0125)[i] * k
                d_len = (0.043, 0.049, 0.044, 0.035)[i]
                prox.append(limb(self.n(f"FingerA{i}{s}"), P(0, y, KNUCKLE_Z + 0.004), P(0, y, PIP_Z), r, r * 0.97, m, segs=6, light=True))
                dist.append(limb(self.n(f"FingerB{i}{s}"), P(0, y, PIP_Z), P(-0.012, y, PIP_Z - d_len), r * 0.95, r * 0.86, m, segs=6, light=True))
        t0, t1, t2 = P(*THUMB_BASE), P(-0.026, -0.078, -0.066), P(-0.036, -0.092, -0.104)
        thumb = [limb(self.n("ThumbA" + s), t0, t1, 0.0185 * k, 0.0165 * k, m, segs=7, light=True),
                 limb(self.n("ThumbB" + s), t1, t2, 0.016 * k, 0.014 * k, m, segs=7, light=True)]
        out = self.add(hand_parts, bone="Hand." + s, tag="hand")
        out += self.add(prox, bone="Fingers." + s, tag="hand")
        out += self.add(dist, bone="Fingers2." + s, tag="hand")
        out += self.add(thumb, bone="Thumb." + s, tag="hand")
        return out

    def thigh(self, side, m, r0=THIGH_R[0], r1=THIGH_R[1], bulge=0.04, name="Thigh"):
        k = self.b["leg"]
        s = "L" if side > 0 else "R"
        return self.add(limb(self.n(name + s), sx(side, HIP), sx(side, KNEE), r0 * k, r1 * k, m, bulge=bulge, segs=14),
                        bone="Thigh." + s, tag="leg")

    def shin(self, side, m, r0=SHIN_R[0], r1=SHIN_R[1], bulge=0.1, name="Shin"):
        k = self.b["leg"]
        s = "L" if side > 0 else "R"
        return self.add(limb(self.n(name + s), sx(side, KNEE), sx(side, ANKLE), r0 * k, r1 * min(k, 1.2), m, bulge=bulge, segs=14),
                        bone="Shin." + s, tag="leg")

    def leg_band(self, side, part, f0, f1, m, grow=0.008, name="Band", taper=None):
        k = self.b["leg"]
        s = "L" if side > 0 else "R"
        a, b, ra, rb, bulge = ((HIP, KNEE, THIGH_R[0] * k, THIGH_R[1] * k, 0.04) if part == "Thigh" else
                               (KNEE, ANKLE, SHIN_R[0] * k, SHIN_R[1] * min(k, 1.2), 0.1))

        def radius(f):
            return (ra + (rb - ra) * f) * (1.0 + bulge * 4.0 * f * (1.0 - f)) + grow
        r0, r1 = radius(f0), radius(f1)
        if taper:
            r0, r1 = r0 + taper[0], r1 + taper[1]
        return self.add(band(self.n(f"{name}{part}{s}"), sx(side, a), sx(side, b), f0, f1, r0, r1, m, segs=18), bone=part + "." + s, tag="leg")

    def shorts_leg(self, side, m, length=0.62, grow=0.012, hem_m=None, flare=0.01):
        """A shorts leg over the thigh, ending in a hem above the knee."""
        k = self.b["leg"]
        s = "L" if side > 0 else "R"
        a, b = sx(side, HIP), sx(side, HIP.lerp(KNEE, length))
        r_end = (THIGH_R[0] + (THIGH_R[1] - THIGH_R[0]) * length) * k + grow + flare
        parts = [limb(self.n("Shorts" + s), a, b, THIGH_R[0] * k + grow, r_end, m, bulge=0.02, segs=14, caps=("round", "flat"))]
        self.add(parts, bone="Thigh." + s, tag="leg")
        if hem_m:
            self.leg_band(side, "Thigh", length - 0.08, length + 0.01, hem_m, grow=grow + flare + 0.003, name="Hem")
        return parts

    # Flip-flop: a two-layer foam sole (strap colour under a light footbed),
    # a bare foot with toes and a thong strap. Rows are (t from the heel, half width, half height,
    # centre height); the foot rests on the footbed at FOOTBED.
    FOOTBED = 0.03
    FLIP_SOLE = [(-0.004, 0.05), (0.04, 0.06), (0.125, 0.055), (0.2, 0.066), (0.265, 0.075), (0.31, 0.068), (0.33, 0.05)]
    BARE_FOOT = [(0.03, 0.045, 0.032, 0.06), (0.1, 0.05, 0.042, 0.07), (0.19, 0.056, 0.031, 0.059), (0.265, 0.06, 0.02, 0.048),
                 (0.292, 0.056, 0.016, 0.044)]
    # Toes, big toe first: (offset across, lateral +), t, radius, length scale.
    TOES = [(-0.031, 0.302, 0.0165, 1.35), (-0.007, 0.301, 0.0118, 1.3), (0.012, 0.294, 0.011, 1.25), (0.029, 0.284, 0.0102, 1.2),
            (0.044, 0.271, 0.0094, 1.15)]

    def _flip_flop(self, side, x, m, sole_m, along):
        s = "L" if side > 0 else "R"
        bed = self.FOOTBED
        parts = [along([(t, rx, bed * 0.36, bed * 0.36) for t, rx in self.FLIP_SOLE], m, "Sole", n=3.0, cap_h=(0.014, 0.014)),
                 along([(t, rx - 0.004, bed * 0.17, bed * 0.83) for t, rx in self.FLIP_SOLE], sole_m, "Footbed", n=3.0, cap_h=(0.012, 0.012)),
                 along([(t, rx, rz, cz) for t, rx, rz, cz in self.BARE_FOOT], self.skin_m, "FootSkin", n=2.4, cap_h=(0.03, 0.012))]
        for i, (across, t, r, length) in enumerate(self.TOES):
            parts.append(sphere(self.n(f"Toe{i}{s}"), r, (x + side * across, 0.1 - t, bed - 0.002 + r * 0.85), scale=(1.0, length, 0.85),
                                m=self.skin_m, segs=10, rings=7))
        # The thong: a post between the big toe and the next, then a strap
        # each way over the instep down to the sole at the arch, hugging the foot.
        post_t, post_x = 0.297, -0.019
        top = self._over_foot(side, x, post_t - 0.012, 90.0 + side * 16.0, 0.0085)
        parts.append(limb(self.n("ThongPost" + s), Vector((x + side * post_x, 0.1 - post_t, bed - 0.004)), top, 0.0055, 0.0065, m, segs=8))
        for k, end in enumerate((90.0 + side * 128.0, 90.0 - side * 128.0)):
            a0 = 90.0 + side * 16.0
            pts = []
            for i in range(9):
                u = i / 8.0
                t = post_t - 0.012 + (0.168 - post_t + 0.012) * (u * u * (3 - 2 * u))
                pts.append(self._over_foot(side, x, t, a0 + (end - a0) * u, 0.0085))
            pts[-1].z = max(pts[-1].z, bed + 0.004)
            for i in range(len(pts) - 1):
                parts.append(limb(self.n(f"Thong{k}{i}{s}"), pts[i], pts[i + 1], 0.0075, 0.0075, m, segs=8, squash=0.75))
        return parts

    def _over_foot(self, side, x, t, angle_deg, lift):
        """A point `lift` (m) outside the bare foot's skin at section t, at
        angle_deg round its cross-section (0 = +X, 90 = top)."""
        rows = self.BARE_FOOT
        t = min(max(t, rows[0][0]), rows[-1][0])
        i = max(j for j in range(len(rows) - 1) if rows[j][0] <= t)
        a, b = rows[i], rows[i + 1]
        f = (t - a[0]) / (b[0] - a[0])
        rx, rz, cz = (a[k] + (b[k] - a[k]) * f for k in (1, 2, 3))
        ex, ez = _superellipse(math.radians(angle_deg), rx + lift, rz + lift, 2.4)
        return Vector((x + ex, 0.1 - t, cz + ez))

    def shoe(self, side, m, sole_m, toe_m=None, style="sneaker", lace_m=None, collar_m=None, shaft=0.0, shaft_m=None, heel_m=None,
             stripe_m=None, tongue_m=None):
        """Footwear on the Foot bone. style: sneaker, boot, shoe or sandal. `shaft`
        (m) adds a boot shaft up the shin (bound to the shin)."""
        s = "L" if side > 0 else "R"
        x = ANKLE.x * side
        heel, toe = Vector((x, 0.1, 0.0)), Vector((x, -0.225, 0.0))
        wide = 0.92 if style == "shoe" else 1.0

        def along(secs, mm, name, n=2.7, caps=("round", "round"), cap_h=(0.03, 0.045), sub=2):
            rows = [(t, rx * wide, rz, 0.0, cz, n) for t, rx, rz, cz in secs]
            return loft(self.n(name + s), rows, mm, segs=14, sub=sub, frame=frame_from(heel, toe, (1, 0, 0)), caps=caps, cap_h=cap_h,
                        light_caps=True)
        parts = []
        if style == "sandal":
            parts += self._flip_flop(side, x, m, sole_m, along)
        else:
            tall = 0.012 if style == "boot" else 0.0
            parts.append(along([(0.008, 0.058, 0.02, 0.02), (0.1, 0.069, 0.02, 0.02), (0.22, 0.078, 0.02, 0.02), (0.318, 0.066, 0.019, 0.019)],
                               sole_m, "Sole", n=3.4, cap_h=(0.02, 0.024)))
            parts.append(along([(0.02, 0.052, 0.056 + tall, 0.082 + tall), (0.095, 0.061, 0.058 + tall, 0.084 + tall), (0.185, 0.068, 0.046, 0.074),
                                (0.26, 0.07, 0.039, 0.067), (0.308, 0.061, 0.034, 0.062)], m, "Upper", cap_h=(0.034, 0.042)))
            if toe_m:
                parts.append(along([(0.245, 0.0725, 0.042, 0.066), (0.283, 0.0705, 0.04, 0.064), (0.311, 0.062, 0.036, 0.062)], toe_m, "ToeCap",
                                   cap_h=(0.004, 0.043), caps=("flat", "round"), sub=1))
            if heel_m:
                parts.append(along([(0.012, 0.053, 0.046, 0.07), (0.055, 0.062, 0.05, 0.072), (0.078, 0.063, 0.045, 0.07)], heel_m, "HeelCap",
                                   cap_h=(0.032, 0.004), caps=("round", "flat"), sub=1))
            if tongue_m:
                parts.append(box(self.n("Tongue" + s), (0.07, 0.085, 0.03), (x, -0.04, 0.128 + tall), rot=rad(-24, 0, 0), bevel=0.012, m=tongue_m))
            if lace_m:
                for i in range(3):
                    parts.append(box(self.n(f"Lace{i}{s}"), (0.082, 0.015, 0.014), (x, -0.012 - i * 0.036, 0.146 + tall - i * 0.016), rot=rad(-24, 0, 0),
                                     bevel=0.005, m=lace_m))
            if stripe_m:
                for i, sd in enumerate((1, -1)):
                    parts.append(box(self.n(f"ShoeStripe{i}{s}"), (0.012, 0.1, 0.022), (x + sd * 0.064 * wide, -0.04, 0.078), rot=rad(-24, 0, sd * -4),
                                     bevel=0.005, m=stripe_m))
        out = self.add(parts, bone="Foot." + s, tag="foot")
        if collar_m:
            out += self.add(band(self.n("Collar" + s), sx(side, KNEE), sx(side, ANKLE), 0.84, 0.99, 0.07, 0.074, collar_m, segs=14),
                            bone="Shin." + s, tag="leg")
        if shaft > 0.0:
            f0 = 1.0 - shaft / (KNEE - ANKLE).length
            out += self.add(band(self.n("Shaft" + s), sx(side, KNEE), sx(side, ANKLE), f0, 0.97, SHIN_R[0] * self.b["leg"] + 0.012,
                                 0.074, shaft_m or m, segs=14, lip=0.12), bone="Shin." + s, tag="leg")
        return out


# ---------------------------------------------------------------------------
# Armature, skinning, ambient occlusion and export
# ---------------------------------------------------------------------------

def build_armature(extra_bones=()):
    data = bpy.data.armatures.new("OperatorRig")
    ob = bpy.data.objects.new("Armature", data)
    export_collection().objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, tail, parent in list(BONES) + list(extra_bones):
        eb = data.edit_bones.new(name)
        eb.head, eb.tail = head, tail
        eb.roll = 0.0
        if parent:
            eb.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return ob


def field_weights(z):
    """Height -> (Hips, Spine, Chest) weights for everything worn on the torso."""
    def step(a, b, v):
        k = min(max((v - a) / (b - a), 0.0), 1.0)
        return k * k * (3 - 2 * k)
    chest = step(1.12, 1.27, z)
    hips = 1.0 - step(0.95, 1.07, z)
    spine = max(0.0, 1.0 - chest - hips)
    total = chest + hips + spine
    return hips / total, spine / total, chest / total


def _is_special(material):
    """Materials that stay separate surfaces: Fx* shaders and glowing parts."""
    if material.name.startswith("Fx"):
        return True
    bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    return bsdf.inputs["Emission Strength"].default_value > 0.0


def _material_values(material):
    bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    col = bsdf.inputs["Base Color"].default_value
    return (col[0], col[1], col[2]), bsdf.inputs["Roughness"].default_value, bsdf.inputs["Metallic"].default_value


def skin(name, kit, armature):
    """Bakes every part, moves flat colours into vertex colours (one "OpBody"
    surface), joins them into one skinned mesh and bakes the occlusion.
    Returns (object, info) where info lists per-part data for the audit."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    body = mat("OpBody", "#fdfdfd", rough=0.6)
    target = bpy.data.objects.new(name, bpy.data.meshes.new(name))
    export_collection().objects.link(target)
    temps, info = [], []
    # Godot only turns "vertex colour as albedo" on from a mesh's second surface, so
    # the glowing / Fx materials go first and OpBody after them.
    for ob in kit.parts:
        for m in ob.data.materials:
            if _is_special(m) and m.name not in target.data.materials:
                target.data.materials.append(m)
    target.data.materials.append(body)
    tris_by_tag = defaultdict(int)
    for index, ob in enumerate(kit.parts):
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        me.transform(ob.matrix_world)
        slots = list(me.materials)
        new_slots, remap = [], {}
        colors = [(1.0, 1.0, 1.0)] * len(slots)
        uvs = [(0.6, 0.0)] * len(slots)
        special = [False] * len(slots)
        for i, m in enumerate(slots):
            keep = _is_special(m)
            special[i] = keep
            target_mat = m if keep else body
            if not keep:
                colors[i], rough, metal = _material_values(m)
                uvs[i] = (rough, metal)
            if target_mat not in new_slots:
                new_slots.append(target_mat)
            remap[i] = new_slots.index(target_mat)
        attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        uv = me.uv_layers.new(name="UVMap")
        col_data, uv_data = [], []
        for poly in me.polygons:
            c, u = colors[poly.material_index], uvs[poly.material_index]
            for _ in poly.loop_indices:
                col_data += [c[0], c[1], c[2], 1.0]
                uv_data += [u[0], u[1]]
        attr.data.foreach_set("color", col_data)
        uv.data.foreach_set("uv", uv_data)
        mat_index = [remap[p.material_index] for p in me.polygons]
        me.materials.clear()
        for m in new_slots:
            me.materials.append(m)
        me.polygons.foreach_set("material_index", mat_index)
        part_attr = me.attributes.new("part", "INT", "FACE")
        part_attr.data.foreach_set("value", [index] * len(me.polygons))
        tris_by_tag[ob["tag"]] += sum(len(p.vertices) - 2 for p in me.polygons)
        tmp = bpy.data.objects.new(ob.name + "_bake", me)
        export_collection().objects.link(tmp)
        if ob["field"]:
            groups = [tmp.vertex_groups.new(name=b) for b in ("Hips", "Spine", "Chest")]
            for v in me.vertices:
                for g, w in zip(groups, field_weights(v.co.z)):
                    if w > 0.0:
                        g.add([v.index], w, "REPLACE")
            region = "torso"
        elif ob.get("blend"):
            upper, lower, z_hi, z_lo = ob["blend"].split("|")
            z_hi, z_lo = float(z_hi), float(z_lo)
            groups = [tmp.vertex_groups.new(name=upper), tmp.vertex_groups.new(name=lower)]
            for v in me.vertices:
                f = min(max((z_hi - v.co.z) / (z_hi - z_lo), 0.0), 1.0)
                f = f * f * (3 - 2 * f)
                if f < 1.0:
                    groups[0].add([v.index], 1.0 - f, "REPLACE")
                if f > 0.0:
                    groups[1].add([v.index], f, "REPLACE")
            region = "extra"
        else:
            vg = tmp.vertex_groups.new(name=ob["bone"])
            vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
            region = REGION.get(ob["bone"], ob.get("region", "extra"))
        glass = any(m.name.startswith("FxGlass") for m in new_slots)
        info.append(dict(name=ob.name, bone=ob["bone"], field=bool(ob["field"]), tag=ob["tag"], region=ob.get("region", region),
                         occlude=bool(ob["occlude"]) and not glass, glass=glass or bool(ob.get("open"))))
        temps.append(tmp)
    if os.environ.get("WLA_OPERATOR_STATS"):
        print("[wla] triangles by tag:", dict(sorted(tris_by_tag.items(), key=lambda kv: -kv[1])))
    bpy.context.view_layer.update()
    with bpy.context.temp_override(active_object=target, object=target, selected_objects=[target] + temps,
                                   selected_editable_objects=[target] + temps):
        bpy.ops.object.join()
    for p in target.data.polygons:
        p.use_smooth = True
    bake_occlusion(target.data, info)
    target.data.color_attributes.active_color = target.data.color_attributes["Col"]
    target.data.color_attributes.render_color_index = target.data.color_attributes.find("Col")
    mod = target.modifiers.new("Armature", "ARMATURE")
    mod.object = armature
    target.parent = armature
    return target, info


def _hemisphere(count):
    """Fixed, evenly spread directions over the +Z hemisphere."""
    out = []
    for i in range(count):
        z = 0.12 + 0.86 * (i + 0.5) / count
        a = i * 2.39996323
        r = math.sqrt(max(0.0, 1.0 - z * z))
        out.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
    return out


def bake_occlusion(me, info, strength=0.62, reach=0.17, rays=16):
    """Multiplies a soft, tinted ambient occlusion into the "Col" vertex colours.
    Limbs only shade themselves (they move); the head and torso shade each other."""
    cos = [v.co.copy() for v in me.vertices]
    nors = [v.normal.copy() for v in me.vertices]
    part = [0] * len(me.polygons)
    me.attributes["part"].data.foreach_get("value", part)
    shade_group = {}
    for i, data in enumerate(info):
        r = data["region"]
        shade_group[i] = "core" if r in ("torso", "head") else r.split(".")[-1] + ("arm" if "arm" in r or "hand" in r else "leg")
    polys = defaultdict(list)
    vert_group = [None] * len(cos)
    for p in me.polygons:
        g = shade_group[part[p.index]]
        if info[part[p.index]]["occlude"]:
            polys[g].append(tuple(p.vertices))
        for vi in p.vertices:
            vert_group[vi] = g
    trees = {g: BVHTree.FromPolygons(cos, pl) for g, pl in polys.items() if pl}
    dirs = _hemisphere(rays)
    occ = [0.0] * len(cos)
    for vi, co in enumerate(cos):
        tree = trees.get(vert_group[vi])
        if tree is None:
            continue
        n = nors[vi]
        q = Vector((0, 0, 1)).rotation_difference(n)
        origin = co + n * 0.007
        total = 0.0
        for d in dirs:
            hit = tree.ray_cast(origin, q @ d, reach)
            if hit[0] is not None:
                total += 1.0 - hit[3] / reach
        occ[vi] = total / rays
    # Blur once across edges so the few rays never show as speckle.
    neighbours = defaultdict(list)
    for e in me.edges:
        a, b = e.vertices
        neighbours[a].append(b)
        neighbours[b].append(a)
    for _ in range(2):
        occ = [0.5 * occ[i] + 0.5 * (sum(occ[j] for j in neighbours[i]) / len(neighbours[i])) if neighbours[i] else occ[i]
               for i in range(len(occ))]
    colors = [0.0] * (len(me.loops) * 4)
    me.color_attributes["Col"].data.foreach_get("color", colors)
    for loop in me.loops:
        k = min(1.0, occ[loop.vertex_index] * 1.7) * strength
        # A gentle top-to-bottom falloff grounds the figure.
        k = min(1.0, k + 0.1 * (1.0 - min(max(cos[loop.vertex_index].z / 1.2, 0.0), 1.0)))
        i = loop.index * 4
        for c in range(3):
            # Godot reads vertex colours as sRGB, so they are stored encoded.
            colors[i + c] = _linear_to_srgb(colors[i + c] * (1.0 - k * (1.0 - SHADOW_TINT[c])))
    me.color_attributes["Col"].data.foreach_set("color", colors)


def _linear_to_srgb(c):
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1.0 / 2.4) - 0.055


def socket(name, armature, bone, matrix):
    """An empty parented to a bone at the given armature-space matrix."""
    ob = bpy.data.objects.new(name, None)
    export_collection().objects.link(ob)
    ob.empty_display_size = 0.08
    ob.empty_display_type = "ARROWS"
    ob.parent = armature
    ob.parent_type = "BONE"
    ob.parent_bone = bone
    bpy.context.view_layer.update()
    ob.matrix_world = armature.matrix_world @ matrix
    return ob


def weapon_socket_matrix():
    """Rest-pose frame of the WeaponSocket (right hand): the weapon's +Y (its
    muzzle, -Z in Godot) runs along the fingers, +Z toward the thumb."""
    fingers = sx(-1, -HAND_Z)
    thumb = -HAND_Y
    right = fingers.cross(thumb)
    lean = Quaternion(right, math.radians(GRIP_RAKE))
    forward, up = lean @ fingers, lean @ thumb
    m = Matrix((right, forward, up)).transposed().to_4x4()
    m.translation = hand_point(-1, *SOCKET)
    return m


def export(name, objects):
    """Writes art/blender/<name>.blend and art/models/<name>.glb (skinned, animated, vertex colours)."""
    os.makedirs(MODELS_DIR, exist_ok=True)
    # The exporter reads bone-parented empties (the sockets) from the evaluated
    # pose but writes bones at rest: park on a frame where no clip plays.
    bpy.context.scene.frame_set(-1)
    bpy.context.view_layer.update()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, name + ".blend"), compress=True)
    for ob in bpy.context.scene.objects:
        ob.select_set(False)
    for ob in objects:
        ob.select_set(True)
    path = os.path.join(os.environ.get("WLA_OPERATOR_OUT", MODELS_DIR), name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_apply=False, export_yup=True,
        export_materials="EXPORT", export_tangents=False, export_animations=True, export_animation_mode="ACTIONS",
        export_skins=True, export_force_sampling=True, export_optimize_animation_size=False,
        export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True)
    mesh = next(o for o in objects if o.type == "MESH")
    tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
    print(f"[wla] {name}: {tris} triangles, {len(mesh.data.materials)} surfaces -> {os.path.relpath(path)}")
    return path
