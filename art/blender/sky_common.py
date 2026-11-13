"""Shared helpers for the Sky Carnival (World 10, Sky Harbor) asset scripts.

Builds on wla_common (metres, Z up, front faces -Y, chunky bevelled flat-colour
parts) and adds the floating-carnival kit: the sunrise palette, striped lathe
shapes (balloon gores, tents, the airship envelope), the rocky undersides of the
islands, pennant strings and lattice trusses.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import bmesh, Vector, _finish, source_collection  # noqa: F401

# Sky Carnival palette: sunrise pastels with carnival red, teal and navy.
SKY = {
    "Cream": "#fff3e2",
    "White": "#fbf8f4",
    "Peach": "#ffb48a",
    "PeachDark": "#e8895f",
    "Gold": "#ffcf5a",
    "GoldDark": "#d99a2b",
    "Sky": "#8fd0ff",
    "SkyDark": "#4f9bd6",
    "Red": "#e8384f",
    "RedDark": "#a8203a",
    "Teal": "#1fb5b0",
    "TealDark": "#127a7a",
    "Navy": "#2b3a67",
    "NavyDark": "#1b2444",
    "Lilac": "#b49ae8",
    "Mint": "#8fe3b8",
    "Pink": "#ff8fb6",
    "Wood": "#b97a4b",
    "WoodDark": "#7a4a2e",
    "WoodLight": "#d9a36b",
    "Rope": "#e7cf9a",
    "Brass": "#e3b04b",
    "Steel": "#9aa3b5",
    "SteelDark": "#525b73",
    "Stone": "#e7c9a8",
    "StoneDark": "#c79b7a",
    "Rock": "#c98e6e",
    "RockDark": "#9a6656",
    "RockDeep": "#6e4a52",
    "Grass": "#7cc96a",
    "GrassDark": "#4f9a52",
    "Leaf": "#5db85a",
    "Canvas": "#f6ecdc",
}


def smat(name, rough=0.6, metal=0.0, emit=0.0):
    """Material 'Sky<name>' in the palette colour `name`."""
    return mat("Sky" + name, SKY[name], rough=rough, metal=metal, emit=emit)


def sglow(name, color, strength=3.0):
    return mat(name, color, rough=0.35, emit=strength)


def finish_multi(name, bm, mats, smooth=False, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Like wla_common._finish, with one material slot per entry of `mats`
    (faces pick theirs through material_index)."""
    ob = _finish(name, bm, mats[0], loc, rot, smooth=smooth)
    for m in mats[1:]:
        ob.data.materials.append(m)
    return ob


def lathe(name, profile, mats, segs=24, stripes=None, smooth=True, loc=(0, 0, 0), rot=(0, 0, 0), cap_top=True, cap_bottom=True):
    """Surface of revolution about Z from `profile` [(radius, z), ...] (bottom to top).
    Faces take material (sector // stripes) % len(mats): vertical gores. With
    stripes None, each ring band i takes mats[i % len(mats)] instead."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        for i in range(segs):
            a = math.tau * i / segs
            ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segs):
            f = bm.faces.new((rings[k][i], rings[k][(i + 1) % segs], rings[k + 1][(i + 1) % segs], rings[k + 1][i]))
            f.material_index = ((i // stripes) % len(mats)) if stripes else (k % len(mats))
    if cap_bottom and profile[0][0] > 0.001:
        f = bm.faces.new(list(reversed(rings[0])))
        f.material_index = 0
    if cap_top and profile[-1][0] > 0.001:
        f = bm.faces.new(rings[-1])
        f.material_index = 0
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish_multi(name, bm, mats, smooth=smooth, loc=loc, rot=rot)


def double_sided(ob):
    """Duplicate every face flipped, so thin shells read from inside too."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    dup = bmesh.ops.duplicate(bm, geom=list(bm.faces))
    flipped = [g for g in dup["geom"] if isinstance(g, bmesh.types.BMFace)]
    bmesh.ops.reverse_faces(bm, faces=flipped)
    bm.to_mesh(me)
    bm.free()
    return ob


def rock_cone(name, radius, depth, seed=1, rings=6, segs=14, lip=True):
    """The underside of a floating island: a faceted, banded rock cone hanging
    below z = 0 (top radius `radius`, tip at -depth), with a grass lip on top."""
    rng = random.Random(seed)
    mats = [smat("Rock", rough=0.9), smat("RockDark", rough=0.9), smat("RockDeep", rough=0.9), smat("Grass", rough=0.9)]
    bm = bmesh.new()
    layers = []
    for k in range(rings + 1):
        t = k / rings
        r = radius * (1.0 - t ** 1.35) * rng.uniform(0.92, 1.05) if k < rings else radius * 0.05
        z = -depth * t
        ring = []
        for i in range(segs):
            a = math.tau * i / segs + rng.uniform(-0.08, 0.08)
            rr = r * rng.uniform(0.86, 1.08)
            ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z + rng.uniform(-0.04, 0.04) * depth)))
        layers.append(ring)
    for k in range(rings):
        for i in range(segs):
            f = bm.faces.new((layers[k][(i + 1) % segs], layers[k][i], layers[k + 1][i], layers[k + 1][(i + 1) % segs]))
            f.material_index = 0 if k == 0 else (1 if k % 2 else (2 if k > rings // 2 else 0))
    f = bm.faces.new(layers[0])
    f.material_index = 3 if lip else 0
    tip = bm.faces.new(list(reversed(layers[-1])))
    tip.material_index = 2
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = finish_multi(name, bm, mats, smooth=False)
    return ob


def grass_lip(name, radius, seed=2, segs=20, height=0.35):
    """A ragged turf collar round the rim of an island top."""
    rng = random.Random(seed)
    bm = bmesh.new()
    top, bot = [], []
    for i in range(segs):
        a = math.tau * i / segs
        r = radius * rng.uniform(1.0, 1.05)
        top.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, 0.0)))
        rb = r * rng.uniform(0.94, 1.0)
        bot.append(bm.verts.new((math.cos(a) * rb, math.sin(a) * rb, -height * rng.uniform(0.7, 1.3))))
    for i in range(segs):
        bm.faces.new((top[i], top[(i + 1) % segs], bot[(i + 1) % segs], bot[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.xy.dot(f.calc_center_median().xy) < 0:
            f.normal_flip()
    return _finish(name, bm, smat("GrassDark", rough=0.9), (0, 0, 0), (0, 0, 0), smooth=False)


def pennants(prefix, a, b, count, sag, mats, size=0.32, depth=0.02):
    """A string of triangular flags hung between points a and b (sagging)."""
    a, b = Vector(a), Vector(b)
    parts = [tube(prefix + "Line", [a.lerp(b, i / 8) - Vector((0, 0, sag * 4 * (i / 8) * (1 - i / 8))) for i in range(9)], 0.012,
                  m=smat("Rope"), segs=4)]
    d = (b - a).normalized()
    yaw = math.atan2(d.y, d.x)
    for i in range(count):
        t = (i + 0.5) / count
        p = a.lerp(b, t) - Vector((0, 0, sag * 4 * t * (1 - t)))
        tri = prism(f"{prefix}Flag{i}", [(-size * 0.5, 0), (size * 0.5, 0), (0, -size * 1.2)], depth, (p.x, p.y, p.z), rot=(0, 0, yaw),
                    m=mats[i % len(mats)])
        parts.append(tri)
    return parts


def truss(prefix, p0, p1, width, m, chord=0.08, web=0.04, panels=None):
    """A square lattice truss between p0 and p1 (four chords, zig-zag webs)."""
    p0, p1 = Vector(p0), Vector(p1)
    axis = (p1 - p0)
    length = axis.length
    d = axis.normalized()
    up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    s1 = d.cross(up).normalized()
    s2 = d.cross(s1).normalized()
    hw = width / 2
    corners = [s1 * hw + s2 * hw, -s1 * hw + s2 * hw, -s1 * hw - s2 * hw, s1 * hw - s2 * hw]
    parts = [tube(f"{prefix}Chord{i}", [p0 + c, p1 + c], chord, m=m, segs=6) for i, c in enumerate(corners)]
    n = panels or max(2, int(length / width))
    for k in range(n):
        q0 = p0 + d * (length * k / n)
        q1 = p0 + d * (length * (k + 1) / n)
        for i in range(4):
            c0, c1 = corners[i], corners[(i + 1) % 4]
            a, b = (q0 + c0, q1 + c1) if k % 2 == 0 else (q0 + c1, q1 + c0)
            parts.append(tube(f"{prefix}Web{k}_{i}", [a, b], web, m=m, segs=4))
    return parts


def balloon_bunch(prefix, base, count=7, spread=0.45, height=1.4, radius=0.22, seed=3, mats=None):
    """A bunch of party balloons on strings tied at `base`."""
    rng = random.Random(seed)
    mats = mats or [smat("Red", rough=0.3), smat("Gold", rough=0.3), smat("Teal", rough=0.3), smat("Pink", rough=0.3), smat("Sky", rough=0.3)]
    base = Vector(base)
    parts = []
    for i in range(count):
        a = math.tau * i / count + rng.uniform(-0.3, 0.3)
        r = spread * rng.uniform(0.3, 1.0)
        top = base + Vector((math.cos(a) * r, math.sin(a) * r, height * rng.uniform(0.8, 1.15)))
        parts.append(tube(f"{prefix}String{i}", [base, top], 0.008, m=smat("White"), segs=3))
        parts.append(sphere(f"{prefix}B{i}", radius, (top.x, top.y, top.z + radius * 1.1), scale=(1, 1, 1.18), m=mats[i % len(mats)], segs=10, rings=7))
        parts.append(cyl(f"{prefix}Knot{i}", radius * 0.18, radius * 0.25, (top.x, top.y, top.z + radius * 0.02), segs=6, bevel=0.0,
                         m=mats[i % len(mats)], radius_top=radius * 0.05))
    return parts
