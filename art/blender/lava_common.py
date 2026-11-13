"""Shared helpers for the Volcano Isle (World 9, Lava Lagoon) asset scripts.

Builds on wla_common (metres, Z up, front faces -Y, chunky bevelled flat-colour
parts) and adds the island kit: the dusk-resort palette, faceted basalt rocks,
layered thatch, carved tiki faces, palm fronds and bamboo.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import bmesh, Vector, _finish  # noqa: F401

# Volcano Isle palette: black basalt and tiki wood, ember orange, teal and hibiscus pink.
LAVA = {
    "Basalt": "#2a2530",
    "BasaltLight": "#4a4250",
    "BasaltDark": "#17141c",
    "Tiki": "#8a5530",
    "TikiDark": "#55311f",
    "TikiLight": "#b57a44",
    "Thatch": "#c99a52",
    "ThatchDark": "#8d6534",
    "Bamboo": "#d6b25e",
    "BambooDark": "#9a7a34",
    "Rope": "#e2c487",
    "Teal": "#22c6b8",
    "TealDark": "#127a78",
    "Pink": "#ff4f9a",
    "PinkDark": "#c22a6c",
    "Ember": "#ff6a1f",
    "Lava": "#ffb23a",
    "Yellow": "#ffd23f",
    "Cream": "#fff0d4",
    "Leaf": "#2f9a52",
    "LeafDark": "#1c6a40",
    "LeafLight": "#5cc85a",
    "Palm": "#6b4a32",
    "PalmDark": "#4a3224",
    "Coconut": "#5a3a22",
    "Steel": "#8b8a9c",
    "SteelDark": "#3c3946",
    "Brass": "#e0a53c",
    "Violet": "#5b3a9a",
    "White": "#f6f2ec",
    "Red": "#e2343f",
    "Sand": "#3b3540",
}


def lmat(name, rough=0.65, metal=0.0, emit=0.0):
    """Material 'Lava<name>' in the island palette colour `name`."""
    return mat("Lava" + name, LAVA[name], rough=rough, metal=metal, emit=emit)


def lglow(name, color, strength=3.0):
    return mat(name, color, rough=0.35, emit=strength)


def ember_mat():
    """Glowing lava (the level swaps surfaces named LavaMolten for its animated shader)."""
    return mat("LavaMolten", "#ff7a1f", rough=0.4, emit=4.0)


def rock(name, radius, loc, seed=1, m=None, scale=(1, 1, 1), rot_z=0.0, jitter=0.28, subdiv=1):
    """A faceted basalt rock: a jittered icosphere, flat shaded."""
    m = m or lmat("Basalt", rough=0.85)
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    for v in bm.verts:
        v.co *= 1.0 + rng.uniform(-jitter, jitter * 0.6)
        v.co.x *= scale[0]
        v.co.y *= scale[1]
        v.co.z *= scale[2]
        if v.co.z < -radius * scale[2] * 0.35:
            v.co.z = -radius * scale[2] * 0.35
    return _finish(name, bm, m, loc, (0, 0, rot_z), smooth=False)


def thatch_cone(name, radius, height, z, m, teeth=16, droop=0.18, seed=0, ring=1.0):
    """A cone of thatch with a ragged fringe (apex at z + height)."""
    rng = random.Random(seed)
    bm = bmesh.new()
    apex = bm.verts.new((0, 0, z + height))
    pts = []
    for i in range(teeth * 2):
        a = math.tau * i / (teeth * 2) + rng.uniform(-0.03, 0.03)
        out = i % 2 == 0
        r = radius * (1.0 if out else 0.93) * ring
        dz = -droop * rng.uniform(0.6, 1.2) if out else 0.02
        pts.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z + dz)))
    hub = bm.verts.new((0, 0, z + height * 0.25))
    n = len(pts)
    for i in range(n):
        bm.faces.new((pts[i], pts[(i + 1) % n], apex))
        bm.faces.new((pts[(i + 1) % n], pts[i], hub))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(name, bm, m, (0, 0, 0), (0, 0, 0), smooth=False)


def thatch_roof(prefix, radius, height, z, layers=3, seed=1, loc=(0, 0, 0)):
    """Layered round thatch roof (tiers alternate light and dark straw) with a finial."""
    light, dark = lmat("Thatch", rough=0.9), lmat("ThatchDark", rough=0.9)
    parts = []
    for i in range(layers):
        t = i / layers
        r = radius * (1.0 - t * 0.55)
        h = height * (1.0 - t * 0.6)
        parts.append(thatch_cone(f"{prefix}Tier{i}", r, h, z + height * t * 0.55, light if i % 2 == 0 else dark,
                                 teeth=14 + 4 * (layers - i), droop=0.16 + 0.04 * (layers - i), seed=seed * 7 + i))
    parts.append(cyl(prefix + "Finial", 0.08, 0.6, (0, 0, z + height + 0.15), segs=8, bevel=0.0, m=lmat("TikiDark")))
    return place(parts, loc)


def thatch_hip(prefix, w, d, h, z, seed=1, loc=(0, 0, 0), overhang=0.5):
    """A hipped thatch roof over a w x d footprint: a squashed four-sided cone with a ragged eave."""
    light, dark = lmat("Thatch", rough=0.9), lmat("ThatchDark", rough=0.9)
    rng = random.Random(seed)
    parts = []
    for k, (scale, m, lift) in enumerate(((1.0, light, 0.0), (0.72, dark, h * 0.32))):
        bm = bmesh.new()
        hw, hd = (w / 2 + overhang) * scale, (d / 2 + overhang) * scale
        ridge = max(hw - hd, 0.0) * 0.8
        top = [bm.verts.new((-ridge, 0, z + h + lift * 0.2)), bm.verts.new((ridge, 0, z + h + lift * 0.2))]
        edge = []
        steps = 10
        corners = [(-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)]
        for c in range(4):
            x0, y0 = corners[c]
            x1, y1 = corners[(c + 1) % 4]
            for s in range(steps):
                t = s / steps
                drop = (0.22 if s % 2 == 0 else 0.0) * rng.uniform(0.6, 1.2)
                edge.append(bm.verts.new((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z + lift - drop)))
        n = len(edge)
        for i in range(n):
            a, b = edge[i], edge[(i + 1) % n]
            apex = top[0] if (a.co.x + b.co.x) < 0 else top[1]
            bm.faces.new((a, b, apex))
        # Fill the gap between the two apexes on the long sides.
        mid_front = edge[steps // 2]
        mid_back = edge[2 * steps + steps // 2]
        bm.faces.new((top[0], mid_front, top[1]))
        bm.faces.new((top[1], mid_back, top[0]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        parts.append(_finish(f"{prefix}Hip{k}", bm, m, (0, 0, 0), (0, 0, 0), smooth=False))
    return place(parts, loc)


def tiki_face(prefix, width, height, loc, wood=None, paint=None, dark=None, style=0, depth=0.12):
    """A carved tiki face on a surface facing -Y, centred at `loc`: heavy brow,
    big oval eyes, a broad nose and a wide mouth with teeth. Style 0 grins,
    1 roars (open square mouth), 2 frowns."""
    wood = wood or lmat("Tiki")
    paint = paint or lmat("Yellow")
    dark = dark or lmat("TikiDark")
    x, y, z = loc
    w, h = width, height
    p = [
        box(prefix + "Brow", (w * 0.92, depth, h * 0.12), (x, y - depth * 0.4, z + h * 0.3), bevel=0.04, m=wood),
        cyl(prefix + "EyeL", w * 0.16, depth * 0.6, (x - w * 0.22, y - depth * 0.35, z + h * 0.14), rot=rad(90, 0, 0), segs=14, bevel=0.01, m=paint),
        cyl(prefix + "EyeR", w * 0.16, depth * 0.6, (x + w * 0.22, y - depth * 0.35, z + h * 0.14), rot=rad(90, 0, 0), segs=14, bevel=0.01, m=paint),
        cyl(prefix + "PupilL", w * 0.07, depth * 0.62, (x - w * 0.22, y - depth * 0.45, z + h * 0.13), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=dark),
        cyl(prefix + "PupilR", w * 0.07, depth * 0.62, (x + w * 0.22, y - depth * 0.45, z + h * 0.13), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=dark),
        prism(prefix + "Nose", [(-w * 0.13, -h * 0.12), (w * 0.13, -h * 0.12), (w * 0.05, h * 0.12), (-w * 0.05, h * 0.12)], depth * 1.4,
              (x, y - depth * 0.55, z - h * 0.02), m=wood, bevel=0.02),
    ]
    if style == 1:
        p += [box(prefix + "Mouth", (w * 0.62, depth * 0.5, h * 0.24), (x, y - depth * 0.2, z - h * 0.27), bevel=0.03, m=dark),
              box(prefix + "Tongue", (w * 0.3, depth * 0.55, h * 0.08), (x, y - depth * 0.24, z - h * 0.34), bevel=0.02, m=lmat("Red"))]
        for i in range(4):
            p.append(box(f"{prefix}Tooth{i}", (w * 0.09, depth * 0.6, h * 0.07), (x - w * 0.21 + i * w * 0.14, y - depth * 0.3, z - h * 0.18),
                         bevel=0.01, m=lmat("Cream")))
    else:
        sag = -1 if style == 2 else 1
        p.append(box(prefix + "Mouth", (w * 0.72, depth * 0.5, h * 0.12), (x, y - depth * 0.2, z - h * 0.27), bevel=0.03, m=dark))
        p.append(box(prefix + "Lip", (w * 0.8, depth * 0.9, h * 0.05), (x, y - depth * 0.45, z - h * (0.2 if sag > 0 else 0.34)), bevel=0.02, m=wood))
        for i in range(5):
            p.append(box(f"{prefix}Tooth{i}", (w * 0.08, depth * 0.6, h * 0.06), (x - w * 0.24 + i * w * 0.12, y - depth * 0.3, z - h * 0.25),
                         bevel=0.01, m=lmat("Cream")))
    return p


def frond(name, base, yaw, length, droop=0.55, width=0.42, m=None, seed=1, leaflets=9):
    """A palm frond from `base`: a drooping midrib with paired leaflets (flat shaded)."""
    m = m or lmat("Leaf", rough=0.7)
    rng = random.Random(seed)
    bm = bmesh.new()
    dirx, diry = math.cos(yaw), math.sin(yaw)
    rib = []
    steps = leaflets + 1
    for i in range(steps + 1):
        t = i / steps
        out = t * length
        z = base[2] + math.sin(t * math.pi * 0.55) * length * 0.28 - t * t * length * droop
        rib.append(Vector((base[0] + dirx * out, base[1] + diry * out, z)))
    side = Vector((-diry, dirx, 0))
    for i in range(1, steps):
        t = i / steps
        lw = width * math.sin(t * math.pi) * rng.uniform(0.85, 1.1) + 0.05
        for s in (-1, 1):
            a = bm.verts.new(rib[i - 1] + side * 0.02 * s)
            b = bm.verts.new(rib[i + 1] + side * 0.02 * s)
            tip = bm.verts.new(rib[i] + side * s * lw + Vector((dirx, diry, 0)) * lw * 0.35 + Vector((0, 0, -lw * 0.55)))
            bm.faces.new((a, b, tip) if s > 0 else (b, a, tip))
    for i in range(steps):
        a = bm.verts.new(rib[i] + side * 0.03)
        b = bm.verts.new(rib[i] - side * 0.03)
        c = bm.verts.new(rib[i + 1] - side * 0.02)
        d = bm.verts.new(rib[i + 1] + side * 0.02)
        bm.faces.new((a, b, c, d))
    ob = _finish(name, bm, m, (0, 0, 0), (0, 0, 0), smooth=False)
    # Leaves are seen from both sides: make them double-sided with a solidify-free trick
    # (the Godot import keeps cull_back, so duplicate flipped faces).
    me = ob.data
    bm2 = bmesh.new()
    bm2.from_mesh(me)
    dup = bmesh.ops.duplicate(bm2, geom=list(bm2.faces))
    flipped = [g for g in dup["geom"] if isinstance(g, bmesh.types.BMFace)]
    bmesh.ops.reverse_faces(bm2, faces=flipped)
    bm2.to_mesh(me)
    bm2.free()
    return ob


def bamboo(name, p0, p1, radius, m=None, joints=True):
    """A bamboo pole between two points with knuckle rings."""
    m = m or lmat("Bamboo", rough=0.5)
    dark = lmat("BambooDark", rough=0.5)
    a, b = Vector(p0), Vector(p1)
    parts = [tube(name, [a, b], radius, m=m, segs=8)]
    if joints:
        n = max(1, int((b - a).length / 0.45))
        for i in range(1, n):
            q = a.lerp(b, i / n)
            parts.append(tube(f"{name}J{i}", [q - (b - a).normalized() * 0.025, q + (b - a).normalized() * 0.025], radius * 1.18, m=dark, segs=8))
    return parts


def flower(name, loc, radius=0.12, m=None, centre=None):
    """A hibiscus-style five-petal flower facing up."""
    m = m or lmat("Pink", rough=0.5)
    centre = centre or lmat("Yellow")
    return [star(name, radius, 0.03, loc, rot=rad(90, 0, 0), m=m, inner=radius * 0.55),
            sphere(name + "C", radius * 0.25, (loc[0], loc[1], loc[2] + 0.02), m=centre, segs=6, rings=4)]
