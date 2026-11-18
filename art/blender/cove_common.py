"""Shared helpers for the Pirate Cove (World 13, Skull Harbor) asset scripts.

Builds on wla_common (metres, Z up, front faces -Y, chunky bevelled flat-colour
parts) and the lathe / multi-material helpers of sky_common, and adds the
harbour kit: the sunset-harbour palette, striped billowing sails, planked
decks, rope lines, barrels and lanterns.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import bmesh, Vector, _finish  # noqa: F401
from sky_common import finish_multi, lathe, double_sided  # noqa: F401

# Pirate Cove palette: warm ship timber, red-and-cream sails, brass, teal paint,
# sandstone and the black-and-bone of the pirate flags.
COVE = {
    "Wood": "#b5733f",
    "WoodDark": "#7a4528",
    "WoodDeep": "#4e2a1c",
    "WoodLight": "#dca36a",
    "Plank": "#c98b52",
    "Red": "#d8333f",
    "RedDark": "#9c1f2e",
    "Cream": "#fff1dc",
    "Sail": "#fbefd8",
    "Gold": "#ffc24a",
    "Brass": "#e3a93b",
    "Teal": "#1fa89e",
    "TealDark": "#0f6f6e",
    "Navy": "#23304f",
    "Black": "#20202a",
    "Iron": "#3b3f4c",
    "IronLight": "#6c7284",
    "Bone": "#f3e8d0",
    "Rope": "#e2c48a",
    "Stone": "#d9b48a",
    "StoneDark": "#a8795a",
    "Sand": "#f0cf98",
    "Rock": "#a8704f",
    "RockDark": "#734a3f",
    "RockDeep": "#64404a",
    "Grass": "#6aae4e",
    "GrassDark": "#4c8a4a",
    "Leaf": "#4fae5c",
    "Thatch": "#e0b060",
    "ThatchDark": "#b8843e",
    "Coral": "#ff7a5c",
    "Green": "#2f9a6a",
}


def cmat(name, rough=0.6, metal=0.0, emit=0.0):
    """Material 'Cove<name>' in the palette colour `name`."""
    return mat("Cove" + name, COVE[name], rough=rough, metal=metal, emit=emit)


def cglow(name, color, strength=3.0):
    return mat(name, color, rough=0.35, emit=strength)


def rope(name, points, radius=0.03, segs=5):
    return tube(name, points, radius, m=cmat("Rope", rough=0.9), segs=segs)


def sag_points(a, b, sag, steps=8):
    """Points of a rope hung from a to b, sagging `sag` metres at the middle."""
    a, b = Vector(a), Vector(b)
    return [a.lerp(b, i / steps) - Vector((0, 0, sag * 4 * (i / steps) * (1 - i / steps))) for i in range(steps + 1)]


def sail(name, width, height, centre, billow=0.6, stripes=6, mats=None, yaw=0.0, taper=0.12, segs_y=6):
    """A square sail hung from a yard: width along X, height down from the top
    edge at `centre`, bellied forward (-Y) by `billow`, in vertical stripes
    (two-sided, so it reads from behind)."""
    mats = mats or [cmat("Red", rough=0.7), cmat("Sail", rough=0.75)]
    bm = bmesh.new()
    cols = stripes * 2
    grid = []
    for j in range(segs_y + 1):
        v = j / segs_y
        half = width * 0.5 * (1.0 - taper * v)
        row = []
        for i in range(cols + 1):
            u = i / cols
            x = -half + 2 * half * u
            bulge = billow * math.sin(math.pi * u) * (0.35 + 0.65 * math.sin(math.pi * min(1.0, v * 1.1 + 0.05)))
            row.append(bm.verts.new((x, -bulge, -height * v)))
        grid.append(row)
    for j in range(segs_y):
        for i in range(cols):
            f = bm.faces.new((grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1]))
            f.material_index = (i * stripes // cols) % len(mats)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = finish_multi(name, bm, mats, smooth=True)
    double_sided(ob)
    ob.location = centre
    ob.rotation_euler = (0, 0, yaw)
    return ob


def lantern(prefix, loc, m_glass=None, scale=1.0):
    """A hanging ship's lantern: brass cap and base, glowing glass, a ring."""
    x, y, z = loc
    s = scale
    glass = m_glass or cglow("CoveLanternGlow", "#ffcf7a", 3.2)
    brass = cmat("Brass", rough=0.35, metal=0.4)
    return [cyl(prefix + "Base", 0.13 * s, 0.06 * s, (x, y, z), segs=8, bevel=0.01, m=brass),
            cyl(prefix + "Glass", 0.1 * s, 0.24 * s, (x, y, z + 0.15 * s), segs=8, bevel=0.0, m=glass),
            cyl(prefix + "Cap", 0.13 * s, 0.1 * s, (x, y, z + 0.32 * s), segs=8, bevel=0.01, m=brass, radius_top=0.04 * s),
            torus(prefix + "Ring", 0.05 * s, 0.012 * s, (x, y, z + 0.42 * s), rot=rad(90, 0, 0), m=brass, major_segs=8, minor_segs=4)]


def barrel(name, radius, height, loc, m_wood=None, m_hoop=None, segs=12):
    """A bellied barrel with two iron hoops."""
    wood = m_wood or cmat("Wood", rough=0.75)
    hoop = m_hoop or cmat("Iron", rough=0.5, metal=0.4)
    x, y, z = loc
    prof = [(radius * 0.84, 0.0), (radius, height * 0.5), (radius * 0.84, height)]
    body = lathe(name, prof, [wood], segs=segs, smooth=True)
    body.location = (x, y, z)
    parts = [body]
    for k, hz in enumerate((0.18, 0.82)):
        r = radius * (0.84 + 0.16 * math.sin(math.pi * hz)) + 0.01
        parts.append(torus(f"{name}Hoop{k}", r, 0.025, (x, y, z + height * hz), m=hoop, major_segs=segs, minor_segs=4))
    return parts


def skull_flag(prefix, loc, width=1.6, height=1.0, yaw=0.0):
    """A black pirate flag with a bone-white skull and crossed bones, facing -Y."""
    x, y, z = loc
    black, bone = cmat("Black", rough=0.8), cmat("Bone", rough=0.6)
    p = [box(prefix + "Cloth", (width, 0.03, height), (0, 0, 0), bevel=0.0, m=black),
         sphere(prefix + "Skull", height * 0.2, (0, -0.03, height * 0.08), scale=(1, 0.3, 1), m=bone, segs=10, rings=6),
         box(prefix + "Jaw", (height * 0.22, 0.04, height * 0.1), (0, -0.04, -height * 0.1), bevel=0.01, m=bone)]
    for s in (-1, 1):
        p.append(box(f"{prefix}Bone{s}", (height * 0.7, 0.03, height * 0.07), (0, -0.035, -height * 0.18), rot=(0, s * 0.6, 0), bevel=0.01, m=bone))
        p.append(sphere(f"{prefix}Eye{s}", height * 0.05, (s * height * 0.075, -0.07, height * 0.1), m=black, segs=6, rings=4))
    place(p, (x, y, z), yaw)
    return p


def planks(name, size, loc, m_a=None, m_b=None, along="x", gap=0.02, count=None):
    """A planked floor or wall panel: alternating boards (two tones) along an axis."""
    a = m_a or cmat("Plank", rough=0.8)
    b = m_b or cmat("Wood", rough=0.8)
    sx, sy, sz = size
    length = sx if along == "y" else sy
    n = count or max(1, int(round(length / 0.32)))
    out = []
    for k in range(n):
        t = -length * 0.5 + length * (k + 0.5) / n
        w = length / n - gap
        if along == "y":
            out.append(box(f"{name}{k}", (w, sy, sz), (loc[0] + t, loc[1], loc[2]), bevel=0.015, m=a if k % 2 == 0 else b))
        else:
            out.append(box(f"{name}{k}", (sx, w, sz), (loc[0], loc[1] + t, loc[2]), bevel=0.015, m=a if k % 2 == 0 else b))
    return out


def rock_lump(name, size, seed=1, mats=None, segs=10, rings=6, top_grass=True):
    """A faceted sandstone lump (unit-ish, scaled to `size`), base at z 0,
    banded in two rock tones with an optional grassy cap."""
    rng = random.Random(seed)
    mats = mats or [cmat("Rock", rough=0.9), cmat("RockDark", rough=0.9), cmat("Grass", rough=0.9)]
    sx, sy, sz = size
    bm = bmesh.new()
    layers = []
    for k in range(rings + 1):
        t = k / rings
        shrink = 1.0 - 0.55 * t ** 1.6
        z = sz * t
        ring = []
        for i in range(segs):
            a = math.tau * i / segs + rng.uniform(-0.12, 0.12)
            r = shrink * rng.uniform(0.82, 1.08)
            ring.append(bm.verts.new((math.cos(a) * r * sx * 0.5, math.sin(a) * r * sy * 0.5, z + rng.uniform(-0.03, 0.03) * sz * (0 < k < rings))))
        layers.append(ring)
    for k in range(rings):
        for i in range(segs):
            f = bm.faces.new((layers[k][i], layers[k][(i + 1) % segs], layers[k + 1][(i + 1) % segs], layers[k + 1][i]))
            f.material_index = 1 if k % 2 else 0
    top = bm.faces.new(layers[-1])
    top.material_index = 2 if top_grass else 0
    bottom = bm.faces.new(list(reversed(layers[0])))
    bottom.material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish_multi(name, bm, mats, smooth=False)
