"""Zombie body and face kit, shared by every zombie builder.

build_zombie.py (the boardwalk cast and the world outfits of the Tourist and
Lifeguard) and the world casts (build_neon_zombies.py, build_aqua_zombies.py,
build_dune_zombies.py, build_frost_zombies.py) all build their bodies from these
parts, so every enemy shares one body language:

    * tapered, bevelled lofts (superellipse cross-sections) instead of plain boxes:
      a torso that narrows from chest to waist with a slight hunch, limbs that
      taper to wrists and ankles, with ball joints at elbows, knees and ankles;
    * hem lips with torn notches on shirts, sleeves and shorts, belts and cuffs;
    * chunky shoes with a toe spring, boots, flip-flops and bare feet;
    * claw-ish hands: a palm, three curled fingers with claw tips and a thumb;
    * a head (skull, nose, ears) plus a face kit: separate Face_<Outfit>_<Preset>
      meshes (eyes, lids, pupils, brows, mouth, teeth), one of which the game shows
      per zombie (scripts/enemies/zombie.gd picks one at random).

Every part is a rigid piece bound to one bone (`bind`), as build_zombie.skin()
expects. Rest pose landmarks below must match build_zombie.BONES. The character
faces -Y in Blender (+Z in Godot).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import _finish
import bmesh
from mathutils import Matrix, Vector

# Rest-pose landmarks of the shared rig (see build_zombie.BONES).
SHOULDER = (0.37, 0.0, 1.25)
ELBOW = (0.41, 0.0, 0.98)
WRIST = (0.43, 0.0, 0.63)
HIP = (0.16, 0.0, 0.79)
KNEE = (0.16, 0.0, 0.45)
ANKLE = (0.16, 0.0, 0.13)
# The head leans forward a little: a zombie hunch built into the rest pose.
HEAD_Y = -0.03

# Glowing eyes: one colour and strength per world, so they read the same way in
# every level (the night worlds need a little more).
EYE_GLOW = {
    "boardwalk": ("#fbf6c8", 2.0),
    "neon": ("#f2ff8a", 3.0),
    "aqua": ("#fff3a0", 2.0),
    "dune": ("#fbf6c8", 2.0),
    "frost": ("#a8f6ff", 3.0),
}


def glass(name, color, alpha=0.35, emit=0.15, rough=0.05):
    """Transparent tinted glass (visors, bubble helmets), alpha-blended in Godot."""
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = mat(name, color, rough=rough, emit=emit)
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Alpha"].default_value = alpha
    for attr, value in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
        if hasattr(m, attr):
            try:
                setattr(m, attr, value)
            except (TypeError, ValueError):
                pass
    return m


def bind(bone, parts):
    """Tag parts with the bone they follow (same contract as build_zombie.bind)."""
    if not isinstance(parts, (list, tuple)):
        parts = [parts]
    for p in parts:
        p["bone"] = bone
    return list(parts)


def base_materials(world, skin="#a3d14a", skin_dark="#6da336", dark="#2a2230", white="#f7f4f2", eye=None):
    """The materials every zombie uses: tintable skin, glowing eyes, a dark
    (pupils, mouths, belts) and a white (teeth, soles, claws)."""
    eye_hex, eye_emit = eye or EYE_GLOW[world]
    return dict(
        skin=mat("Skin", skin, rough=0.6),
        skin_dark=mat("SkinDark", skin_dark, rough=0.65),
        eye=mat("Eye", eye_hex, rough=0.3, emit=eye_emit),
        dark=mat("ZDark", dark, rough=0.55),
        white=mat("ZWhite", white, rough=0.55),
    )


# ---------------------------------------------------------------------------
# Primitives
# ---------------------------------------------------------------------------

def _frame(axis):
    w = Vector(axis).normalized()
    hint = Vector((1, 0, 0)) if abs(w.x) < 0.9 else Vector((0, 1, 0))
    u = (hint - w * hint.dot(w)).normalized()
    return u, w.cross(u), w


def _section(a, b, n, segs):
    e = 2.0 / n
    out = []
    for k in range(segs):
        t = math.tau * k / segs
        c, s = math.cos(t), math.sin(t)
        out.append((a * math.copysign(abs(c) ** e, c), b * math.copysign(abs(s) ** e, s)))
    return out


def loft(name, rings, m, axis=(0, 0, 1), segs=20, cap0=True, cap1=True, jag=None, smooth=True, skip=None):
    """Skin a list of cross-sections into one mesh.

    rings: [(centre, a, b, n)] in order along `axis`; each section is a superellipse
    with half-sizes a (across) and b (the other way), exponent n (2 = ellipse,
    4 = squircle). cap0/cap1 close the ends with a fan. jag(i, k) returns an extra
    offset along the axis for ring i, vertex k (torn edges); skip(k) leaves out the
    faces between vertices k and k+1 (open garments)."""
    u, v, w = _frame(axis)
    bm = bmesh.new()
    verts = []
    for i, (c, a, b, n) in enumerate(rings):
        c = Vector(c)
        row = []
        for k, (px, py) in enumerate(_section(max(a, 0.002), max(b, 0.002), n, segs)):
            off = jag(i, k) if jag else 0.0
            row.append(bm.verts.new(c + u * px + v * py + w * off))
        verts.append(row)
    for i in range(len(verts) - 1):
        r0, r1 = verts[i], verts[i + 1]
        for k in range(segs):
            if skip and skip(k):
                continue
            k1 = (k + 1) % segs
            bm.faces.new((r0[k], r0[k1], r1[k1], r1[k]))
    if skip:
        bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    if cap0:
        c = bm.verts.new(Vector(rings[0][0]))
        for k in range(segs):
            bm.faces.new((c, verts[0][(k + 1) % segs], verts[0][k]))
    if cap1:
        c = bm.verts.new(Vector(rings[-1][0]))
        for k in range(segs):
            bm.faces.new((c, verts[-1][k], verts[-1][(k + 1) % segs]))
    ob = _finish(name, bm, m, (0, 0, 0), (0, 0, 0), smooth=smooth)
    return add_bevel(ob, 0.0)


def _lerp_keys(keys, t):
    """Smoothstep interpolation of (t, a, b, du, dv) keys."""
    if t <= keys[0][0]:
        return keys[0][1:]
    for k0, k1 in zip(keys, keys[1:]):
        if t <= k1[0]:
            f = (t - k0[0]) / max(1e-6, k1[0] - k0[0])
            f = f * f * (3 - 2 * f)
            return tuple(x + (y - x) * f for x, y in zip(k0[1:], k1[1:]))
    return keys[-1][1:]


def _keys(keys):
    return [tuple(k) + (0.0,) * (5 - len(k)) for k in keys]


def profile(p0, p1, keys, n=3.0, r0=0.05, r1=0.05, mid=6, cap=3):
    """Rings for a tapered rounded blob from p0 to p1.

    keys: [(t, a, b[, du, dv])] half-sizes (and centre offsets across/along the
    other axis) at fractions t of the length. r0/r1 round the ends like a bevel
    (0 = an open, flat end)."""
    p0, p1 = Vector(p0), Vector(p1)
    axis = p1 - p0
    length = axis.length
    u, v, w = _frame(axis)
    keys = _keys(keys)
    stations = []
    if r0 > 0:
        for i in range(cap + 1):
            al = (math.pi / 2) * i / cap
            stations.append((r0 * (1 - math.cos(al)), r0 * (1 - math.sin(al))))
    else:
        stations.append((0.0, 0.0))
    s0, s1 = (r0 if r0 > 0 else 0.0), length - (r1 if r1 > 0 else 0.0)
    for i in range(1, mid):
        stations.append((s0 + (s1 - s0) * i / mid, 0.0))
    if r1 > 0:
        for i in range(cap, -1, -1):
            al = (math.pi / 2) * i / cap
            stations.append((length - r1 * (1 - math.cos(al)), r1 * (1 - math.sin(al))))
    else:
        stations.append((length, 0.0))
    rings = []
    for s, inset in stations:
        a, b, du, dv = _lerp_keys(keys, s / length)
        c = p0 + w * s + u * du + v * dv
        rings.append((c, a - inset, b - inset, n))
    return rings, w


def blob(name, p0, p1, keys, m, n=3.0, r0=0.05, r1=0.05, segs=20, mid=6, cap=3):
    """A tapered, bevelled body part between two points (see `profile`)."""
    rings, w = profile(p0, p1, keys, n, r0, r1, mid, cap)
    return loft(name, rings, m, axis=w, segs=segs, cap0=r0 > 0, cap1=r1 > 0)


def tear_fn(segs, seed, count=3, depth=0.04, width=1.6):
    """Ragged edge: `count` pointed flaps (or notches, with a negative depth)."""
    rng = random.Random(seed)
    spots = [(rng.uniform(0, segs), depth * rng.uniform(0.6, 1.0)) for _ in range(count)]

    def f(k):
        out = 0.0
        for c, d in spots:
            dk = min(abs(k - c), segs - abs(k - c))
            out += d * max(0.0, 1.0 - dk / width)
        return out
    return f


def band(name, top, bottom, a, b, m, n=3.0, thick=0.02, flare=0.0, segs=20, tear=None, a_bot=None, b_bot=None):
    """An open hem band (shirt hem, sleeve, shorts leg, cuff, collar) from `top`
    down to `bottom`: an outer wall with a visible lip at both edges. `flare`
    widens the bottom edge; `tear` (from tear_fn) rags the bottom edge."""
    top, bottom = Vector(top), Vector(bottom)
    ab = (a if a_bot is None else a_bot) + flare
    bb = (b if b_bot is None else b_bot) + flare
    rings = [(top, a - thick, b - thick, n), (top, a, b, n), (bottom, ab, bb, n), (bottom, ab - thick, bb - thick, n)]

    def jag(i, k):
        return tear(k) if (tear and i >= 2) else 0.0
    return loft(name, rings, m, axis=bottom - top, segs=segs, cap0=False, cap1=False, jag=jag)


def dome(name, r, loc, scale, m, tilt=0.0, roll=0.0, segs=14, rings=5):
    """The top half of a sphere, cut by a plane tilted by `tilt` about X (front
    edge down for positive values) and `roll` about Y, then scaled (eyelids)."""
    bm = bmesh.new()
    rows = []
    for i in range(rings + 1):
        el = (math.pi / 2) * i / rings
        if i == rings:
            rows.append([bm.verts.new((0, 0, r))])
            break
        rows.append([bm.verts.new((math.cos(el) * math.cos(math.tau * k / segs) * r,
                                   math.cos(el) * math.sin(math.tau * k / segs) * r, math.sin(el) * r)) for k in range(segs)])
    for i in range(rings - 1):
        for k in range(segs):
            k1 = (k + 1) % segs
            bm.faces.new((rows[i][k], rows[i][k1], rows[i + 1][k1], rows[i + 1][k]))
    top = rows[rings][0]
    for k in range(segs):
        bm.faces.new((rows[rings - 1][k], rows[rings - 1][(k + 1) % segs], top))
    bm.faces.new(list(reversed(rows[0])))
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(roll, 3, "Y") @ Matrix.Rotation(tilt, 3, "X"))
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    return _finish(name, bm, m, loc, (0, 0, 0))


def wrap(ob, target, offset=0.003, mode="OUTSIDE_SURFACE"):
    """Shrinkwrap `ob` onto `target`. OUTSIDE_SURFACE pushes whatever sits inside
    the target out to its surface (pockets, pads); ABOVE_SURFACE lays it flat just
    above the surface (prints)."""
    sw = ob.modifiers.new("Wrap", "SHRINKWRAP")
    sw.target = target
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    sw.wrap_mode = mode
    sw.offset = offset
    # Wrap after the bevel but before the normals pass added by the primitives.
    normals = ob.modifiers.find("WeightedNormal")
    if 0 <= normals < ob.modifiers.find("Wrap"):
        ob.modifiers.move(ob.modifiers.find("Wrap"), normals)
    return ob


def patch(name, target, loc, size, m, rot=(0, 0, 0), bevel=0.012, offset=0.003):
    """A raised panel (pocket, pad, patch): a box pushed out onto `target`."""
    return wrap(box(name, size, loc, rot=rot, bevel=bevel, m=m), target, offset)


def decal(name, target, loc, radius, m, petals=0, offset=0.004, segs=20, squash=1.0, star=False):
    """A flat print laid on `target` near `loc`: a disc, a flower with `petals`
    lobes or a star with `petals` points (star=True), facing away from the body axis."""
    loc = Vector(loc)
    out = Vector((loc.x, loc.y, 0.0))
    out = out.normalized() if out.length > 1e-4 else Vector((0, -1, 0))
    # Start clearly outside: the shrinkwrap offset goes towards the original side.
    loc = loc + out * 0.04
    up = Vector((0, 0, 1))
    side = up.cross(out).normalized()
    bm = bmesh.new()
    centre = bm.verts.new(loc)
    ring = []
    for k in range(segs):
        t = math.tau * k / segs
        if star:
            r = radius * (0.42 + 0.58 * abs(math.cos(petals * t * 0.5)) ** 4)
        else:
            r = radius * (0.72 + 0.28 * math.cos(petals * t)) if petals else radius
        ring.append(bm.verts.new(loc + side * math.cos(t) * r + up * math.sin(t) * r * squash))
    for k in range(segs):
        bm.faces.new((centre, ring[k], ring[(k + 1) % segs]))
    ob = _finish(name, bm, m, (0, 0, 0), (0, 0, 0))
    return wrap(ob, target, offset, mode="ABOVE_SURFACE")


def claw_finger(name, base, side_dir, length, radius, curl, m, nail=None, segs=7):
    """A chunky finger hanging down from `base`, curling forward (-Y) by `curl`
    (0..1), with an optional claw tip."""
    bx, by, bz = base
    pts = []
    for i in range(4):
        t = i / 3
        ang = curl * t * 1.4
        pts.append((bx + side_dir * 0.006 * t, by - math.sin(ang) * length * t * 0.75, bz - math.cos(ang * 0.6) * length * t))
    parts = [tube(name, pts, radius, m=m, segs=segs, radius_end=radius * 0.75)]
    if nail is not None:
        tip, prev = Vector(pts[-1]), Vector(pts[-2])
        d = (tip - prev).normalized()
        parts.append(tube(name + "Claw", [tip - d * 0.01, tip + d * radius * 1.3], radius * 0.7, m=nail, segs=6, radius_end=0.004))
    return parts


# ---------------------------------------------------------------------------
# Body
# ---------------------------------------------------------------------------

class Shape:
    """A vertical profile (torso, skull): (t, a, b, du, dv) keys from z0 to z1
    around a centre line, so garments, hair, straps and prints can follow it."""

    def __init__(self, keys, z0, z1, n=3.2, centre=(0.0, 0.0)):
        self.keys, self.z0, self.z1, self.n, self.centre = _keys(keys), z0, z1, n, centre

    def section(self, z):
        """(a, b, centre_x, centre_y) of the profile at height z."""
        a, b, du, dv = _lerp_keys(self.keys, (z - self.z0) / (self.z1 - self.z0))
        return a, b, self.centre[0] + du, self.centre[1] + dv

    def front(self, x, z, back=False, off=0.0):
        """Y of the front (or back) surface at (x, z), pushed out by `off`."""
        a, b, du, dv = self.section(z)
        a, b = a + off, b + off
        f = max(0.0, 1.0 - abs((x - du) / a) ** self.n) ** (1.0 / self.n)
        return dv + (b * f if back else -b * f)

    def shell(self, name, m, top, bottom, off=0.022, gap=0.0, tear=None, flare=0.0, segs=24, steps=6, lip=0.02, gap_at=0.0):
        """A layer over the profile from `top` down to `bottom` (heights), `off`
        proud of it, open over `gap` degrees centred on the front (gap_at = 0;
        180 = the back), with lips at both edges; `tear` (tear_fn) rags the
        bottom edge. Garments, vests, armour plates, hair."""
        rings = []
        for i in range(steps + 1):
            z = top + (bottom - top) * i / steps
            a, b, du, dv = self.section(z)
            e = off + flare * (i / steps) ** 2
            rings.append(((du, dv, z), a + e, b + e, self.n))
        (c0, a0, b0, n0), (c1, a1, b1, n1) = rings[0], rings[-1]
        rings = [(c0, a0 - lip, b0 - lip, n0)] + rings + [(c1, a1 - lip, b1 - lip, n1)]
        last = len(rings) - 2

        def jag(i, k):
            return tear(k) if (tear and i >= last) else 0.0
        half = math.radians(gap) * 0.5

        def skip(k):
            # The section's +V axis is -Y (front) for a downward loft.
            t = math.tau * (k + 0.5) / segs - math.pi / 2 - math.radians(gap_at)
            return abs(math.atan2(math.sin(t), math.cos(t))) < half
        return loft(name, rings, m, axis=(0, 0, -1), segs=segs, cap0=False, cap1=False, jag=jag, skip=skip if gap > 0 else None)


class Body(Shape):
    """The torso profile made by torso()."""

    def __init__(self, w, d, z0, z1, waist=0.82, belly=0.0, hunch=0.035, chest=1.0, n=3.2):
        hw, hd = w * 0.5, d * 0.5
        self.w, self.d = w, d
        super().__init__([
            (0.0, hw * waist, hd * 0.96, 0.0, 0.0),
            (0.3, hw * (waist + 0.04) + belly * 0.3, hd + belly * 0.6, 0.0, -belly * 0.35),
            (0.62, hw * chest, hd * 1.02, 0.0, hunch * 0.3),
            (0.85, hw * chest * 0.99, hd * 1.04, 0.0, hunch),
            (1.0, hw * 0.86, hd * 0.92, 0.0, hunch * 0.8),
        ], z0, z1, n)


def torso(p, m, w=0.62, d=0.42, z0=0.9, z1=1.44, waist=0.82, belly=0.0, hunch=0.035, n=3.2, hem=None, hem_tear=0, seed=1,
          chest=1.0, bone="Spine"):
    """Spine-bound torso: chest `w` x `d` tapering to `waist` at the bottom, a
    rounded upper back (hunch) and an optional belly. hem = material of a hem lip
    at the bottom edge (with `hem_tear` torn flaps). Returns (parts, Body)."""
    body = Body(w, d, z0, z1, waist, belly, hunch, chest, n)
    hw, hd = w * 0.5, d * 0.5
    parts = [blob(p + "Torso", (0, 0, z0), (0, 0, z1), body.keys, m, n=n, r0=0.04, r1=min(0.16, hd * 0.8), segs=24, mid=8)]
    if hem is not None:
        a, b = hw * waist + 0.012, hd * 0.96 + 0.012
        parts.append(band(p + "Hem", (0, 0, z0 + 0.09), (0, 0, z0 - 0.015), a, b, hem, n=n, thick=0.022, flare=0.012, segs=24,
                          tear=tear_fn(24, seed, hem_tear, 0.045) if hem_tear else None))
    return bind(bone, parts), body


def neck(p, m, w=0.24, z0=1.36, z1=1.47):
    return bind("Spine", [blob(p + "Neck", (0, HEAD_Y * 0.5, z0), (0, HEAD_Y * 0.8, z1), [(0, w * 0.5, w * 0.45), (1, w * 0.46, w * 0.42)], m,
                               n=2.4, r0=0.0, r1=0.02, segs=14, mid=2)])


def hips(p, m, w=0.6, d=0.42, z0=0.74, z1=1.0, belt=None, buckle=None, n=3.0, belt_z=0.97):
    """Hips-bound pelvis (shorts / trousers top) with an optional belt and buckle."""
    hw, hd = w * 0.5, d * 0.5
    parts = [blob(p + "Pelvis", (0, 0, z0), (0, 0, z1), [(0, hw * 0.92, hd * 0.9), (0.5, hw, hd), (1, hw * 0.98, hd * 0.97)], m,
                  n=n, r0=0.07, r1=0.03, segs=24, mid=4)]
    if belt is not None:
        parts.append(band(p + "Belt", (0, 0, belt_z + 0.035), (0, 0, belt_z - 0.035), hw * 0.99 + 0.012, hd * 0.98 + 0.012, belt,
                          n=n, thick=0.02, segs=24))
    if buckle is not None:
        parts.append(box(p + "Buckle", (0.11, 0.03, 0.075), (0, -hd - 0.02, belt_z), bevel=0.012, m=buckle))
    return bind("Hips", parts)


def arm(p, side, m, w=0.17, skin=None, sleeve=None, sleeve_len="short", cuff=None, glove=None, hand=0.0, out=0.0,
        sleeve_tear=0, seed=3, fingers=3, curl=0.55, nail=None, pad=None, shoulder=None):
    """One arm, side = +1 (left, +X) or -1 (right). sleeve_len: "short", "long"
    or "none" (bare / vest). hand enlarges the hand; out pushes the arm sideways
    from its bone (broad builds). pad = material of a shoulder pad."""
    s = "L" if side > 0 else "R"
    skin = skin or m["skin"]
    x = lambda v: side * (v + out)  # noqa: E731
    long_sleeve = sleeve is not None and sleeve_len == "long"
    up_m = sleeve if sleeve is not None and sleeve_len in ("short", "long") else skin
    fore_m = sleeve if long_sleeve else skin
    hw = w * 0.5
    upper = [
        sphere(f"{p}Shoulder{s}", hw * 1.32, (x(0.37), 0, 1.25), scale=(1.0, 1.0, 0.95), m=shoulder or up_m, segs=14, rings=9),
        blob(f"{p}UpperArm{s}", (x(0.38), 0, 1.24), (x(0.41), 0, 0.99), [(0, hw * 1.05, hw * 1.1), (0.4, hw * 1.08, hw * 1.08), (1, hw * 0.86, hw * 0.92)],
             up_m, n=2.6, r0=0.0, r1=0.0, segs=16, mid=4),
    ]
    if sleeve is not None and sleeve_len == "short":
        upper.append(band(f"{p}Sleeve{s}", (x(0.378), 0, 1.3), (x(0.4), 0, 1.07), hw * 1.25, hw * 1.25, sleeve, n=2.6, thick=0.02,
                          flare=0.018, segs=16, tear=tear_fn(16, seed + side, sleeve_tear, 0.04) if sleeve_tear else None))
    if pad is not None:
        upper.append(sphere(f"{p}Pad{s}", hw * 1.65, (x(0.39), 0, 1.3), scale=(1.05, 1.0, 0.72), m=pad, segs=14, rings=8))
    fore = [
        sphere(f"{p}Elbow{s}", hw * 0.98, (x(0.41), 0.0, 0.98), m=fore_m, segs=12, rings=8),
        blob(f"{p}ForeArm{s}", (x(0.41), 0, 0.98), (x(0.43), 0, 0.64), [(0, hw * 0.92, hw * 0.95), (0.35, hw * 1.04, hw * 1.0), (1, hw * 0.74, hw * 0.78)],
             fore_m, n=2.6, r0=0.0, r1=0.0, segs=16, mid=4),
    ]
    if long_sleeve or cuff is not None:
        fore.append(band(f"{p}Cuff{s}", (x(0.425), 0, 0.73), (x(0.43), 0, 0.66), hw * 0.92 + 0.01, hw * 0.95 + 0.01, cuff or sleeve,
                         n=2.6, thick=0.02, flare=0.012, segs=16,
                         tear=tear_fn(16, seed + 7 * side, sleeve_tear, 0.035) if (sleeve_tear and long_sleeve and not cuff) else None))
    fore += hand_parts(f"{p}Hand{s}", side, (x(0.435), -0.005, 0.63), glove or skin, hand, fingers, curl, nail)
    return bind(f"UpperArm.{s}", upper) + bind(f"ForeArm.{s}", fore)


def hand_parts(name, side, wrist, m, size=0.0, fingers=3, curl=0.55, nail=None):
    """A claw-ish zombie hand hanging from `wrist`: palm, curled fingers, thumb."""
    k = 1.0 + size * 4.0
    wx, wy, wz = wrist
    pw, pd, ph = 0.075 * k, 0.05 * k, 0.11 * k
    parts = [blob(name + "Palm", (wx, wy, wz + 0.01), (wx, wy - 0.01 * k, wz - ph), [(0, pw * 0.85, pd * 0.9), (0.6, pw, pd), (1, pw * 0.95, pd * 0.9)],
                  m, n=3.0, r0=0.03 * k, r1=0.035 * k, segs=16, mid=3)]
    fr = 0.026 * k
    for i in range(fingers):
        f = (i - (fingers - 1) / 2) / max(1, (fingers - 1) / 2)
        base = (wx + f * pw * 0.62, wy - 0.012 * k, wz - ph + 0.02 * k)
        parts += claw_finger(f"{name}F{i}", base, f, 0.12 * k * (1.0 - 0.12 * abs(f)), fr, curl, m, nail)
    tx = wx - side * pw * 0.85
    parts.append(tube(name + "Thumb", [(tx, wy - 0.02 * k, wz - 0.03 * k), (tx - side * 0.02 * k, wy - 0.06 * k, wz - 0.08 * k),
                                        (tx - side * 0.005 * k, wy - 0.085 * k, wz - 0.11 * k)], fr * 1.05, m=m, segs=7, radius_end=fr * 0.8))
    return parts


def leg(p, side, m, w=0.19, skin=None, pants=None, pants_len="shorts", hem=None, foot="shoe", shoe=None, sole=None, sock=None,
        lace=None, knee_m=None, tear=0, seed=5, boot_h=0.3, toe=None):
    """One leg. pants_len: "shorts" (bare shins), "long" or "none". foot:
    "shoe" (sneaker), "boot", "flipflop", "bare" or "none" (the caller adds one)."""
    s = "L" if side > 0 else "R"
    skin = skin or m["skin"]
    x = side * 0.16
    hw = w * 0.5
    long_pants = pants is not None and pants_len == "long"
    thigh_m = pants or skin
    shin_m = pants if long_pants else skin
    thigh = [blob(f"{p}Thigh{s}", (x, 0, 0.8), (x, 0, 0.46), [(0, hw * 1.2, hw * 1.2), (0.5, hw * 1.12, hw * 1.12), (1, hw * 0.92, hw * 0.94)],
                  thigh_m, n=2.6, r0=0.0, r1=0.0, segs=16, mid=4)]
    if pants is not None and pants_len == "shorts":
        thigh.append(band(f"{p}ShortsLeg{s}", (x, 0, 0.74), (x + side * 0.01, 0, 0.53), hw * 1.32, hw * 1.32, hem or pants, n=2.6,
                          thick=0.022, flare=0.025, segs=16, tear=tear_fn(16, seed + side, tear, 0.04) if tear else None))
    shin = [
        sphere(f"{p}Knee{s}", hw * 1.0, (x, -0.012, 0.45), m=knee_m or shin_m, segs=12, rings=8),
        blob(f"{p}Shin{s}", (x, 0, 0.45), (x, 0.005, 0.14), [(0, hw * 0.9, hw * 0.92), (0.3, hw * 0.96, hw * 1.0, 0, 0.006), (1, hw * 0.7, hw * 0.72)],
             shin_m, n=2.6, r0=0.0, r1=0.0, segs=16, mid=4),
        sphere(f"{p}Ankle{s}", hw * 0.78, (x, 0.0, 0.135), m=shin_m, segs=10, rings=7),
    ]
    if long_pants:
        shin.append(band(f"{p}TrouserCuff{s}", (x, 0, 0.27), (x, 0.0, 0.17), hw * 0.95, hw * 0.98, hem or pants, n=2.6, thick=0.02,
                         flare=0.03, segs=16, tear=tear_fn(16, seed + 3 * side, tear, 0.035) if tear else None))
    if sock is not None:
        shin.append(band(f"{p}Sock{s}", (x, 0, 0.27), (x, 0, 0.15), hw * 0.85, hw * 0.88, sock, n=2.6, thick=0.015, flare=0.012, segs=16))
    shin += foot_parts(f"{p}Foot{s}", x, foot, w, shoe, sole or m["white"], lace, skin, boot_h, toe)
    return bind(f"Thigh.{s}", thigh) + bind(f"Shin.{s}", shin)


def foot_parts(name, x, kind, w, shoe, sole, lace, skin, boot_h=0.3, toe=None):
    """Shoe / boot / flip-flop / bare foot, toes towards -Y, sole on the ground."""
    parts = []
    hw = max(0.105, w * 0.56)
    if kind in ("shoe", "boot"):
        toe_m = toe or sole
        # Sneaker body: a loft from heel to toe with a toe spring.
        keys = [(0.0, hw * 0.86, 0.075, 0, 0.0), (0.35, hw, 0.08, 0, 0.0), (0.75, hw * 1.02, 0.065, 0, -0.01), (1.0, hw * 0.92, 0.05, 0, 0.0)]
        parts.append(blob(name + "Shoe", (x, 0.09, 0.1), (x, -0.27, 0.085), keys, shoe, n=3.0, r0=0.05, r1=0.05, segs=18, mid=5))
        parts.append(blob(name + "Sole", (x, 0.1, 0.035), (x, -0.29, 0.045), [(0, hw * 0.92, 0.032), (0.4, hw * 1.06, 0.034), (1, hw * 0.98, 0.03)],
                          sole, n=3.4, r0=0.03, r1=0.035, segs=18, mid=4))
        parts.append(sphere(name + "Toe", hw * 0.92, (x, -0.2, 0.075), scale=(1.0, 0.85, 0.55), m=toe_m, segs=12, rings=6))
        if kind == "boot":
            parts.append(blob(name + "Shaft", (x, 0.005, 0.1), (x, 0.0, 0.1 + boot_h), [(0, hw * 0.9, hw * 0.92), (1, hw * 0.86, hw * 0.88)], shoe,
                              n=2.8, r0=0.0, r1=0.02, segs=16, mid=3))
            parts.append(band(name + "BootTop", (x, 0.0, 0.11 + boot_h), (x, 0.0, 0.05 + boot_h), hw * 0.88 + 0.012, hw * 0.9 + 0.012,
                              lace or shoe, n=2.8, thick=0.02, flare=0.01, segs=16))
        else:
            parts.append(band(name + "Collar", (x, 0.02, 0.19), (x, 0.02, 0.13), hw * 0.8, hw * 0.82, shoe, n=2.8, thick=0.02, flare=0.012, segs=16))
            if lace is not None:
                for i in range(3):
                    parts.append(box(f"{name}Lace{i}", (hw * 1.05, 0.03, 0.022), (x, -0.06 - i * 0.05, 0.165 - i * 0.022), rot=rad(-20, 0, 0),
                                     bevel=0.008, m=lace))
    elif kind == "flipflop":
        parts.append(blob(name + "Foot", (x, 0.07, 0.08), (x, -0.23, 0.07), [(0, hw * 0.78, 0.05), (0.6, hw * 0.92, 0.045), (1, hw * 0.86, 0.035)], skin,
                          n=2.8, r0=0.035, r1=0.03, segs=16, mid=4))
        for i in range(3):
            parts.append(sphere(f"{name}Toe{i}", 0.028, (x + (i - 1) * hw * 0.55, -0.235, 0.055), scale=(1, 1.2, 0.85), m=skin, segs=8, rings=5))
        parts.append(blob(name + "Sole", (x, 0.1, 0.02), (x, -0.28, 0.02), [(0, hw * 0.92, 0.02), (0.5, hw * 1.05, 0.02), (1, hw * 0.98, 0.02)], shoe,
                          n=3.4, r0=0.018, r1=0.018, segs=18, mid=3))
        parts.append(tube(name + "Strap", [(x - hw * 0.8, -0.03, 0.04), (x, -0.16, 0.1), (x + hw * 0.8, -0.03, 0.04)], 0.018, m=lace or shoe, segs=6))
    elif kind == "bare":
        parts.append(blob(name + "Foot", (x, 0.07, 0.07), (x, -0.24, 0.06), [(0, hw * 0.8, 0.06), (0.6, hw * 0.96, 0.05), (1, hw * 0.9, 0.04)], skin,
                          n=2.8, r0=0.04, r1=0.035, segs=16, mid=4))
        for i in range(3):
            parts.append(sphere(f"{name}Toe{i}", 0.032, (x + (i - 1) * hw * 0.6, -0.245, 0.04), scale=(1, 1.2, 0.9), m=skin, segs=8, rings=5))
    return parts


# ---------------------------------------------------------------------------
# Head and face
# ---------------------------------------------------------------------------

def _skull_keys(w):
    hw = w * 0.5
    return [(0.0, hw * 0.74, 0.205), (0.2, hw * 0.88, 0.235), (0.45, hw, 0.255), (0.78, hw * 1.0, 0.262), (1.0, hw * 0.94, 0.25)]


SKULL_Z = (1.27, 1.88)


def skull(w):
    """The Shape of a head of width w (for hair, hoods, bands)."""
    return Shape(_skull_keys(w), SKULL_Z[0], SKULL_Z[1], 3.3, (0.0, HEAD_Y))


def hair(p, w, m, style="fringe", seed=2):
    """Head-bound hair: "fringe" (a ragged band round the back, balding on top),
    "mop" (fringe plus a tousled top), "flat" (a short crop) or "tufts"."""
    sk = skull(w)
    parts = []
    rng = random.Random(seed)
    if style in ("fringe", "mop"):
        # A ring of shaggy clumps round the back of the head, ear to ear.
        for i in range(11):
            a = math.radians(-84 + 168 * i / 10)
            # Lowest at the nape, rising above the ears at the sides.
            z = 1.56 + 0.13 * abs(math.sin(a)) ** 2 + rng.uniform(-0.02, 0.03)
            ra, rb, cx, cy = sk.section(z)
            x, y = cx + math.sin(a) * ra * 0.98, cy + math.cos(a) * rb * 0.98
            parts.append(sphere(f"{p}Clump{i}", rng.uniform(0.065, 0.085), (x, y, z), scale=(1.0, 1.0, 1.55),
                                rot=(math.cos(a) * 0.35, -math.sin(a) * 0.35, 0), m=m, segs=9, rings=6))
    if style == "flat":
        parts.append(sk.shell(p + "Crop", m, 1.86, 1.6, off=0.016, gap=110, tear=tear_fn(26, seed, 5, -0.03), segs=26, steps=4, lip=0.018))
        parts.append(sphere(p + "CropTop", w * 0.47, (0, HEAD_Y + 0.02, 1.8), scale=(1.0, 0.86, 0.36), m=m, segs=16, rings=7))
    if style in ("mop", "tufts"):
        for i in range(5 if style == "mop" else 3):
            a = rng.uniform(-1.2, 1.2) + (math.pi / 2 if style == "tufts" else 0.0)
            x, y = math.sin(a) * w * 0.25, HEAD_Y + math.cos(a) * 0.12
            parts.append(cyl(f"{p}Tuft{i}", 0.05, 0.16, (x, y, 1.9), rot=(rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0), segs=6, bevel=0.0,
                             m=m, radius_top=0.012))
    return bind("Head", parts)


def face_y(w, z):
    """Y of the skull's front surface on the centre line at height z."""
    t = (z - SKULL_Z[0]) / (SKULL_Z[1] - SKULL_Z[0])
    _, b, _, _ = _lerp_keys(_keys(_skull_keys(w)), min(1.0, max(0.0, t)))
    return HEAD_Y - b


def head(p, m, w=0.6, ears=True, nose=True, skin=None, dark=None):
    """Head-bound skull (with jaw), nose and ears. The face is separate (see faces)."""
    skin = skin or m["skin"]
    dark = dark or m["skin_dark"]
    parts = [blob(p + "Skull", (0, HEAD_Y, SKULL_Z[0]), (0, HEAD_Y, SKULL_Z[1]), _skull_keys(w), skin, n=3.3, r0=0.09, r1=0.15, segs=26, mid=7, cap=4)]
    if nose:
        parts.append(sphere(p + "Nose", 0.05, (0, face_y(w, 1.5) - 0.025, 1.5), scale=(1.15, 0.85, 0.8), m=dark, segs=10, rings=6))
    if ears:
        for side in (-1, 1):
            parts.append(sphere(f"{p}Ear{side}", 0.075, (side * (w * 0.5 + 0.015), HEAD_Y + 0.02, 1.57), scale=(0.55, 1.0, 1.25), m=skin, segs=10, rings=6))
            parts.append(sphere(f"{p}EarIn{side}", 0.04, (side * (w * 0.5 + 0.045), HEAD_Y + 0.0, 1.57), scale=(0.4, 0.9, 1.1), m=dark, segs=8, rings=5))
    return bind("Head", parts)


# Face presets. eyes: size of the left/right eyeball (1 = normal) and their
# height offsets; pupils: (x, z) offsets in eye radii and pupil size; lids: tilt
# of the upper lids in degrees (None = no lid; more = droopier) and their roll
# (angry > 0); brows: (left, right) tilt in degrees (inner end down > 0) and
# heights; mouth: grin, gape, snarl, clench, ooh or buck.
FACE_PRESETS = {
    "Grin": dict(eyes=(1.0, 1.0), dz=(0.0, 0.0), pupils=((0.25, 0.05), (-0.25, 0.05)), psize=1.0, lids=(-38, -38), roll=6,
                 brows=(10, 10), bz=(0.0, 0.0), mouth="grin"),
    "Gape": dict(eyes=(1.18, 0.82), dz=(0.01, -0.02), pupils=((0.35, -0.2), (-0.1, 0.35)), psize=0.9, lids=(None, -12), roll=0,
                 brows=(-16, -10), bz=(0.03, 0.0), mouth="gape"),
    "Snarl": dict(eyes=(0.92, 0.92), dz=(0.0, 0.0), pupils=((0.0, 0.0), (0.0, 0.0)), psize=0.7, lids=(-20, -20), roll=22,
                  brows=(24, 24), bz=(-0.01, -0.01), mouth="snarl"),
    "Derp": dict(eyes=(1.12, 0.78), dz=(-0.01, 0.025), pupils=((-0.35, 0.0), (0.35, -0.1)), psize=1.0, lids=(-30, -5), roll=0,
                 brows=(-6, 14), bz=(0.035, -0.01), mouth="buck"),
    "Sleepy": dict(eyes=(1.0, 0.95), dz=(0.0, 0.0), pupils=((0.15, -0.15), (-0.05, -0.2)), psize=1.0, lids=(12, 4), roll=-4,
                   brows=(-4, -8), bz=(-0.02, -0.01), mouth="ooh"),
    "Clench": dict(eyes=(1.08, 1.08), dz=(0.0, 0.0), pupils=((0.0, 0.1), (0.0, 0.1)), psize=0.55, lids=(None, None), roll=0,
                   brows=(-14, -14), bz=(0.04, 0.04), mouth="clench"),
}


def faces(outfit, m, w=0.6, presets=("Grin", "Gape", "Snarl"), tongue=None, eye_z=1.62, scale=1.0, lid=None, brow=None):
    """One Face_<outfit>_<preset> part list per preset (Head-bound).
    Materials: m["eye"], m["dark"] (pupils, mouth), m["white"] (teeth),
    lid / brow (default SkinDark), tongue (default SkinDark)."""
    return {f"Face_{outfit}_{name}": bind("Head", face_parts(f"F{outfit[:3]}{name}_", FACE_PRESETS[name], m, w, tongue, eye_z, scale, lid, brow))
            for name in presets}


def face_parts(p, f, m, w, tongue=None, eye_z=1.62, k=1.0, lid=None, brow=None):
    eye, dark, white = m["eye"], m["dark"], m["white"]
    lid = lid or m["skin_dark"]
    brow = brow or m["skin_dark"]
    tongue = tongue or m["skin_dark"]
    parts = []
    er = 0.1 * k * (w / 0.6) ** 0.5
    for i, side in enumerate((1, -1)):
        size = f["eyes"][i]
        r = er * size
        ez = eye_z + f["dz"][i]
        ex = side * w * 0.235
        fy = face_y(w, ez)
        ey = fy + r * 0.38
        sc = (1.0, 0.6, 1.1)
        parts.append(sphere(f"{p}Eye{i}", r, (ex, ey, ez), scale=sc, m=eye, segs=14, rings=9))
        px, pz = f["pupils"][i]
        pr = r * 0.26 * f["psize"]
        parts.append(sphere(f"{p}Pupil{i}", pr, (ex + side * px * r * 0.55, ey - r * 0.6 + 0.004, ez + pz * r * 0.6), scale=(1, 0.45, 1),
                            m=dark, segs=8, rings=5))
        tilt = f["lids"][i]
        if tilt is not None:
            parts.append(dome(f"{p}Lid{i}", r * 1.07, (ex, ey, ez), (sc[0], sc[1] * 1.08, sc[2]), lid, tilt=math.radians(tilt),
                              roll=math.radians(-side * f["roll"]), segs=14, rings=4))
        parts.append(sphere(f"{p}Bag{i}", r * 0.78, (ex + side * r * 0.08, fy + 0.016, ez - r * 0.92), scale=(1.0, 0.4, 0.3), m=lid, segs=10, rings=5))
        bt = f["brows"][i]
        parts.append(box(f"{p}Brow{i}", (r * 2.1, 0.07, 0.055 * k), (ex, face_y(w, ez + r * 1.4) - 0.005, ez + r * 1.35 + f["bz"][i]),
                         rot=rad(0, -side * bt, 0), bevel=0.022, m=brow))
    parts += mouth_parts(p, f["mouth"], m, w, tongue, k)
    return parts


def mouth_parts(p, kind, m, w, tongue, k=1.0):
    dark, white = m["dark"], m["white"]
    mz = 1.405
    fy = face_y(w, mz)
    mw = w * 0.5 * k
    parts = []

    def tooth(name, x, z, sx=0.05, sz=0.05, rot=0.0):
        return box(name, (sx * k, 0.035, sz * k), (x, fy - 0.012, z), rot=rad(0, rot, 0), bevel=0.012, m=white)

    if kind in ("grin", "clench", "buck"):
        h = 0.115 if kind == "clench" else 0.1
        parts.append(box(p + "Mouth", (mw, 0.07, h * k), (0, fy + 0.02, mz), bevel=0.035, segs=3, m=dark))
        if kind == "grin":
            for i, x in enumerate((-0.11, -0.04, 0.035, 0.11)):
                if i != 2:
                    parts.append(tooth(f"{p}T{i}", x * mw / 0.3, mz + 0.022 * k, 0.055, 0.05))
            parts.append(tooth(p + "TL", 0.06 * mw / 0.3, mz - 0.028 * k, 0.05, 0.04))
        elif kind == "clench":
            for i in range(5):
                x = (i - 2) * 0.053 * mw / 0.3
                parts.append(tooth(f"{p}T{i}", x, mz + 0.026 * k, 0.046, 0.045))
                parts.append(tooth(f"{p}B{i}", x + 0.01, mz - 0.026 * k, 0.046, 0.04))
        else:
            parts.append(tooth(p + "BuckL", -0.032, mz + 0.012 * k, 0.058, 0.08))
            parts.append(tooth(p + "BuckR", 0.032, mz + 0.012 * k, 0.058, 0.08))
            parts.append(tooth(p + "TL", 0.1 * mw / 0.3, mz - 0.03 * k, 0.045, 0.035))
    elif kind == "gape":
        parts.append(sphere(p + "Mouth", 0.1 * k, (0.01, fy + 0.03, mz - 0.01), scale=(1.15, 0.5, 1.15), m=dark, segs=14, rings=8))
        parts.append(sphere(p + "Tongue", 0.06 * k, (0.015, fy - 0.0, mz - 0.06 * k), scale=(1.25, 0.5, 0.65), m=tongue, segs=10, rings=6))
        parts.append(tooth(p + "T0", -0.035, mz + 0.075 * k, 0.045, 0.045))
        parts.append(tooth(p + "T1", 0.05, mz + 0.072 * k, 0.04, 0.05))
    elif kind == "snarl":
        parts.append(box(p + "Mouth", (mw * 1.02, 0.07, 0.1 * k), (0.01, fy + 0.02, mz), rot=rad(0, -9, 0), bevel=0.035, segs=3, m=dark))
        for i, side in enumerate((-1, 1)):
            x = side * 0.075 * mw / 0.3 + 0.01
            zt = mz + 0.035 * k + side * 0.012
            parts.append(cyl(f"{p}Fang{i}", 0.024 * k, 0.075 * k, (x, fy - 0.016, zt - 0.03 * k), rot=rad(180, 0, 0), segs=8, bevel=0.0,
                             m=white, radius_top=0.004))
        for i in range(3):
            x = (i - 1) * 0.05 * mw / 0.3
            parts.append(tooth(f"{p}B{i}", x, mz - 0.03 * k + (i - 1) * 0.008, 0.045, 0.04, rot=-9))
        parts.append(box(p + "Lip", (mw * 0.42, 0.05, 0.035), (0.08 * mw / 0.3, fy - 0.004, mz + 0.068 * k), rot=rad(0, -16, 0), bevel=0.015,
                         m=m["skin_dark"]))
    elif kind == "ooh":
        parts.append(sphere(p + "Mouth", 0.062 * k, (0.02, fy + 0.025, mz - 0.01), scale=(1.0, 0.5, 1.25), m=dark, segs=12, rings=7))
        parts.append(tooth(p + "T0", 0.02, mz + 0.045 * k, 0.04, 0.035))
    return parts
