"""Shared helpers for the Gold Rush Gulch (World 12, Boomtown) asset scripts.

Builds on wla_common (metres, Z up, front faces -Y, chunky bevelled flat-colour
parts) and adds the Wild West kit: the high-noon palette, layered red-rock
mesas with stepped strata, plank runs and the false-front building shell used by
every shop on Main Street.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import bmesh, Vector, _finish  # noqa: F401
from sky_common import finish_multi, lathe, double_sided  # noqa: F401

# Gold Rush Gulch palette: sun-bleached orange and terracotta, red rock, gold, turquoise.
GULCH = {
    "Cream": "#fbe9c8",
    "Bone": "#f3dcb4",
    "Sand": "#e8b878",
    "SandDark": "#c98f55",
    "Orange": "#f28a3c",
    "OrangeDark": "#c9652a",
    "Terracotta": "#d0643f",
    "TerraDark": "#a4472e",
    "Red": "#d23b2f",
    "RedDark": "#97261f",
    "Barn": "#b8382c",
    "Rock": "#b5452c",
    "RockLight": "#cf6238",
    "RockDark": "#8a2f1f",
    "RockPale": "#df8a4c",
    "RockTop": "#c9784a",
    "Gold": "#ffc93c",
    "GoldDark": "#d99a22",
    "Turq": "#2fb7b0",
    "TurqDark": "#1d7f80",
    "TurqLight": "#7fded3",
    "Wood": "#a8693f",
    "WoodDark": "#6e4128",
    "WoodLight": "#cf9560",
    "WoodGrey": "#9c8672",
    "Plank": "#b87a49",
    "Iron": "#4a4650",
    "IronLight": "#7a7480",
    "Ink": "#2b2230",
    "Glass": "#2c5d6a",
    "Green": "#5fa23e",
    "GreenDark": "#3f7a2e",
    "Cactus": "#4f9a48",
    "CactusDark": "#356e35",
    "Straw": "#f0c860",
    "StrawDark": "#c99a38",
    "Canvas": "#f6ead2",
    "Brick": "#c2553c",
    "White": "#fbf7ee",
    "Blue": "#3f7fd0",
}


def gmat(name, rough=0.7, metal=0.0, emit=0.0):
    """Material 'Gulch<name>' in the palette colour `name`."""
    return mat("Gulch" + name, GULCH[name], rough=rough, metal=metal, emit=emit)


def gglow(name, color, strength=3.0):
    return mat(name, color, rough=0.35, emit=strength)


def jitter_outline(points, amount, seed):
    """Copy of a closed 2D outline with each point pushed out/in by up to `amount`."""
    rng = random.Random(seed)
    cx = sum(p[0] for p in points) / len(points)
    cy = sum(p[1] for p in points) / len(points)
    out = []
    for x, y in points:
        d = Vector((x - cx, y - cy, 0))
        k = 1.0 + rng.uniform(-amount, amount) / max(d.length, 0.01)
        out.append((cx + (x - cx) * k, cy + (y - cy) * k))
    return out


def rounded_rect(w, d, steps=5, corner=None):
    """Closed outline of a w x d rectangle with rounded corners (counter-clockwise)."""
    r = corner if corner is not None else min(w, d) * 0.3
    pts = []
    for cx, cy, a0 in ((w / 2 - r, d / 2 - r, 0), (-w / 2 + r, d / 2 - r, 90), (-w / 2 + r, -d / 2 + r, 180), (w / 2 - r, -d / 2 + r, 270)):
        for i in range(steps + 1):
            a = math.radians(a0 + 90 * i / steps)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def subdivide_outline(points, step):
    """Inserts points along each edge so no edge is longer than `step`."""
    out = []
    n = len(points)
    for i in range(n):
        a, b = Vector((*points[i], 0)), Vector((*points[(i + 1) % n], 0))
        k = max(1, int((b - a).length / step))
        for j in range(k):
            p = a.lerp(b, j / k)
            out.append((p.x, p.y))
    return out


def mesa(name, outline, bands, seed=1, jag=0.35, mats=None, top_mat=None):
    """A layered red-rock mesa: `outline` (closed (x, y) loop) stacked in `bands`
    [(height, scale), ...] from the ground up. Each band is a near-vertical wall;
    where the scale changes a ledge steps in. Bands alternate the strata colours.
    Returns one object with a flat top."""
    rng = random.Random(seed)
    mats = mats or [gmat("Rock", rough=0.9), gmat("RockLight", rough=0.9), gmat("RockDark", rough=0.9), gmat("RockPale", rough=0.9)]
    top_mat = top_mat or gmat("RockTop", rough=0.95)
    all_mats = mats + [top_mat]
    cx = sum(p[0] for p in outline) / len(outline)
    cy = sum(p[1] for p in outline) / len(outline)
    noise = [rng.uniform(-jag, jag) for _ in outline]
    bm = bmesh.new()
    rings = []
    z = 0.0
    prev = None
    for k, (h, s) in enumerate(bands):
        wob = [rng.uniform(-jag, jag) * 0.6 for _ in outline]
        ring_lo, ring_hi = [], []
        for i, (x, y) in enumerate(outline):
            d = Vector((x - cx, y - cy, 0))
            r = d.length
            u = d.normalized() if r > 0.01 else Vector((1, 0, 0))
            rr = r * s + noise[i] + wob[i]
            ring_lo.append(bm.verts.new((cx + u.x * rr, cy + u.y * rr, z)))
            rr2 = r * s * 0.985 + noise[i] + wob[i] * 0.5
            ring_hi.append(bm.verts.new((cx + u.x * rr2, cy + u.y * rr2, z + h)))
        n = len(outline)
        if prev is not None:
            for i in range(n):
                f = bm.faces.new((prev[i], prev[(i + 1) % n], ring_lo[(i + 1) % n], ring_lo[i]))
                f.material_index = len(mats)
        for i in range(n):
            f = bm.faces.new((ring_lo[i], ring_lo[(i + 1) % n], ring_hi[(i + 1) % n], ring_hi[i]))
            f.material_index = k % len(mats)
        prev = ring_hi
        rings.append((ring_lo, ring_hi))
        z += h
    f = bm.faces.new(prev)
    f.material_index = len(mats)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish_multi(name, bm, all_mats, smooth=False)


def planks(prefix, size, loc, m_a, m_b, axis="X", gap=0.02, width=0.3, bevel=0.015):
    """A panel of boards (size x, y, z) with alternating tones, boards running along `axis`."""
    parts = []
    sx, sy, sz = size
    if axis == "X":
        n = max(1, int(round(sz / width)))
        h = sz / n
        for i in range(n):
            parts.append(box(f"{prefix}{i}", (sx, sy, h - gap), (loc[0], loc[1], loc[2] - sz / 2 + h * (i + 0.5)), bevel=bevel,
                             m=m_a if i % 2 == 0 else m_b))
    else:
        n = max(1, int(round(sx / width)))
        w = sx / n
        for i in range(n):
            parts.append(box(f"{prefix}{i}", (w - gap, sy, sz), (loc[0] - sx / 2 + w * (i + 0.5), loc[1], loc[2]), bevel=bevel,
                             m=m_a if i % 2 == 0 else m_b))
    return parts


def window(prefix, x, y, z, w=1.0, h=1.3, frame=None, glass=None, shutters=None, sill=True):
    """A framed sash window on a wall facing -Y at depth y, centred at (x, z)."""
    frame = frame or gmat("Cream", rough=0.6)
    glass = glass or gmat("Glass", rough=0.2)
    p = [box(prefix + "Glass", (w, 0.06, h), (x, y - 0.02, z), bevel=0.0, m=glass),
         box(prefix + "FrameT", (w + 0.2, 0.12, 0.1), (x, y - 0.05, z + h / 2 + 0.05), bevel=0.02, m=frame),
         box(prefix + "FrameB", (w + 0.2, 0.12, 0.1), (x, y - 0.05, z - h / 2 - 0.05), bevel=0.02, m=frame),
         box(prefix + "FrameL", (0.1, 0.12, h), (x - w / 2 - 0.05, y - 0.05, z), bevel=0.02, m=frame),
         box(prefix + "FrameR", (0.1, 0.12, h), (x + w / 2 + 0.05, y - 0.05, z), bevel=0.02, m=frame),
         box(prefix + "Mullion", (0.05, 0.08, h), (x, y - 0.04, z), bevel=0.0, m=frame),
         box(prefix + "Transom", (w, 0.08, 0.05), (x, y - 0.04, z + h * 0.1), bevel=0.0, m=frame)]
    if sill:
        p.append(box(prefix + "Sill", (w + 0.36, 0.22, 0.08), (x, y - 0.1, z - h / 2 - 0.12), bevel=0.02, m=frame))
    if shutters is not None:
        for s in (-1, 1):
            p.append(box(f"{prefix}Shutter{s}", (w * 0.45, 0.06, h + 0.1), (x + s * (w / 2 + w * 0.25 + 0.12), y - 0.05, z), bevel=0.02, m=shutters))
    return p


def door(prefix, x, y, w=1.3, h=2.3, m=None, frame=None, knob=None, panels=2):
    """A closed panelled door (single or double leaf) on a wall facing -Y."""
    m = m or gmat("WoodDark")
    frame = frame or gmat("Cream", rough=0.6)
    knob = knob or gmat("Gold", rough=0.3, metal=0.4)
    p = [box(prefix + "Leaf", (w, 0.1, h), (x, y - 0.03, h / 2), bevel=0.02, m=m),
         box(prefix + "FrameT", (w + 0.3, 0.14, 0.14), (x, y - 0.05, h + 0.07), bevel=0.02, m=frame),
         box(prefix + "FrameL", (0.14, 0.14, h), (x - w / 2 - 0.07, y - 0.05, h / 2), bevel=0.02, m=frame),
         box(prefix + "FrameR", (0.14, 0.14, h), (x + w / 2 + 0.07, y - 0.05, h / 2), bevel=0.02, m=frame)]
    for i in range(panels):
        for s in ((-1, 1) if w > 1.1 else (0,)):
            px = x + s * w * 0.24
            pw = w * 0.36 if w > 1.1 else w * 0.7
            p.append(box(f"{prefix}Panel{i}{s}", (pw, 0.04, h * 0.32), (px, y - 0.09, h * (0.28 + 0.4 * i)), bevel=0.01, m=frame))
    if w > 1.1:
        p.append(box(prefix + "Split", (0.04, 0.05, h), (x, y - 0.09, h / 2), bevel=0.0, m=frame))
    p.append(sphere(prefix + "Knob", 0.05, (x + w * 0.38, y - 0.12, 1.05), m=knob, segs=8, rings=5))
    return p


def sign(prefix, text_body, x, y, z, w, h, board=None, trim=None, ink=None, size=None, depth=0.04):
    """A painted signboard with raised lettering on a wall facing -Y."""
    board = board or gmat("Cream", rough=0.6)
    trim = trim or gmat("WoodDark")
    ink = ink or gmat("RedDark", rough=0.5)
    size = size or h * 0.6
    return [box(prefix + "Trim", (w + 0.18, 0.1, h + 0.18), (x, y + 0.02, z), bevel=0.03, m=trim),
            box(prefix + "Board", (w, 0.12, h), (x, y - 0.03, z), bevel=0.03, m=board),
            text(prefix + "Text", text_body, size, depth, (x, y - 0.11, z - size * 0.06), m=ink)]


def post_row(prefix, x0, x1, y, z0, z1, count, m, radius=0.11):
    """Square porch posts from z0 to z1 at depth y between x0 and x1."""
    out = []
    for i in range(count):
        x = x0 + (x1 - x0) * i / max(1, count - 1)
        out.append(box(f"{prefix}{i}", (radius * 2, radius * 2, z1 - z0), (x, y, (z0 + z1) / 2), bevel=0.03, m=m))
        out.append(box(f"{prefix}Cap{i}", (radius * 2 + 0.1, radius * 2 + 0.1, 0.1), (x, y, z1 - 0.05), bevel=0.02, m=m))
    return out
