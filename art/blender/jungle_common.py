"""Shared helpers for the Jungle Expedition (World 7, Lost Temple) asset scripts.

Builds on wla_common (metres, Z up, fronts face -Y, chunky bevelled flat-colour
parts) and adds the jungle kit: the palette, broad leaves, palm fronds, hanging
vines, carved stone blocks and rope.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import bmesh, Vector, Matrix  # noqa: F401

# Lost Temple palette: lush greens, warm sandstone, teal water, jade glow, torch orange.
JUNGLE = {
    "Leaf": "#2f8f4e",
    "LeafLight": "#6cc04a",
    "LeafDark": "#1d5a3c",
    "LeafYellow": "#a8c83a",
    "Moss": "#6e9e36",
    "Trunk": "#6b4a32",
    "TrunkDark": "#4a3324",
    "Bark": "#8a6a4a",
    "Stone": "#c9a27a",
    "StoneLight": "#e0b98a",
    "StoneShade": "#8d6b55",
    "StoneDark": "#5e4638",
    "Jade": "#3dffb0",
    "JadeDeep": "#14a878",
    "Torch": "#ff9a2e",
    "Flame": "#ffc65a",
    "Khaki": "#c8a86a",
    "KhakiDark": "#8f7444",
    "Canvas": "#efe1bf",
    "CanvasDark": "#cdb98f",
    "RideRed": "#d9473a",
    "RideRedDark": "#9a2a26",
    "Gold": "#f2b33a",
    "Rope": "#b08a55",
    "Bamboo": "#c9b45a",
    "BambooDark": "#8f7e36",
    "Thatch": "#c49a52",
    "ThatchDark": "#8e6a34",
    "Steel": "#7c8590",
    "SteelDark": "#3a4048",
    "Teal": "#2fb3a8",
    "TealDark": "#17656f",
    "Cream": "#fff2dc",
    "Charcoal": "#2a2420",
    "Pink": "#ff5a9a",
    "Orange": "#ff7a2a",
    "Yellow": "#ffd23f",
    "Purple": "#8a4fe0",
    "Olive": "#6f7a3a",
    "Rust": "#a4532e",
    "Lava": "#ff6a1f",
    "Ash": "#4a4448",
    "AshLight": "#6e6468",
}


def jmat(name, rough=0.7, metal=0.0, emit=0.0):
    """Material 'Jungle<name>' in the jungle palette colour `name`."""
    return mat("Jungle" + name, JUNGLE[name], rough=rough, metal=metal, emit=emit)


def jglow(name, color, strength=3.0):
    return mat(name, color, rough=0.35, emit=strength)


def jade_glow():
    """The idol's eyes, the portal inlays: the game recolours none of these."""
    return mat("JungleJadeGlow", JUNGLE["Jade"], rough=0.3, emit=3.2)


def _object(name, bm, m, smooth=False):
    ob = bpy.data.objects.new(name, bpy.data.meshes.new(name))
    source_collection().objects.link(ob)
    bm.to_mesh(ob.data)
    bm.free()
    if m is not None:
        ob.data.materials.append(m)
    for p in ob.data.polygons:
        p.use_smooth = smooth
    return ob


def leaf(name, length, width, base, direction, droop=0.35, m=None, segs=5, curl=0.18, notch=False):
    """A broad leaf blade: a lens-shaped strip from `base` along `direction`
    (xy heading, radians) that arcs up then droops, folded slightly along the
    midrib. Two-sided (the game draws both faces of a flat leaf)."""
    bm = bmesh.new()
    ca, sa = math.cos(direction), math.sin(direction)
    fwd = Vector((ca, sa, 0.0))
    side = Vector((-sa, ca, 0.0))
    rows = []
    for i in range(segs + 1):
        t = i / segs
        w = width * math.sin(math.pi * min(1.0, t * 1.05 + 0.02)) ** 0.8 * 0.5
        if notch and 0.3 < t < 0.85 and i % 2 == 0:
            w *= 0.55
        rise = math.sin(t * math.pi * 0.55) * length * 0.32 - droop * length * t * t
        centre = Vector(base) + fwd * (t * length) + Vector((0, 0, rise))
        fold = Vector((0, 0, curl * w))
        rows.append((bm.verts.new(centre - side * w + fold), bm.verts.new(centre), bm.verts.new(centre + side * w + fold)))
    for i in range(segs):
        a, b = rows[i], rows[i + 1]
        bm.faces.new((a[0], b[0], b[1], a[1]))
        bm.faces.new((a[1], b[1], b[2], a[2]))
    return _object(name, bm, m, smooth=True)


def frond(name, length, base, direction, lift=0.5, droop=1.1, m=None, leaflets=9, leaflet_len=0.7, seed=0):
    """A palm frond: a rachis arcing out from `base` with paired drooping leaflets."""
    rng = random.Random(seed)
    bm = bmesh.new()
    ca, sa = math.cos(direction), math.sin(direction)
    fwd = Vector((ca, sa, 0.0))
    side = Vector((-sa, ca, 0.0))

    def spine(t):
        return Vector(base) + fwd * (t * length) + Vector((0, 0, lift * length * t - droop * length * t * t * 0.5))

    for i in range(leaflets):
        t = 0.12 + 0.86 * i / max(1, leaflets - 1)
        p = spine(t)
        q = spine(min(1.0, t + 0.06))
        ll = leaflet_len * (1.0 - 0.55 * t) * rng.uniform(0.9, 1.1)
        for s in (-1, 1):
            tip = p + side * s * ll * 0.85 + fwd * ll * 0.35 + Vector((0, 0, -ll * 0.45))
            v0 = bm.verts.new(p)
            v1 = bm.verts.new(q)
            v2 = bm.verts.new(tip)
            bm.faces.new((v0, v1, v2) if s > 0 else (v1, v0, v2))
    # The rachis itself, a thin flat strip.
    prev = None
    for i in range(9):
        t = i / 8
        c = spine(t)
        w = 0.05 * (1 - t) + 0.01
        pair = (bm.verts.new(c - side * w), bm.verts.new(c + side * w))
        if prev:
            bm.faces.new((prev[0], pair[0], pair[1], prev[1]))
        prev = pair
    return _object(name, bm, m)


def vine(name, points, radius, m, leaf_m=None, leaves=6, seed=0, leaf_size=0.22):
    """A hanging vine along a polyline with small leaves along it."""
    parts = [tube(name, points, radius, m=m, segs=6, radius_end=radius * 0.6)]
    if leaf_m is not None and leaves:
        rng = random.Random(seed)
        pts = [Vector(p) for p in points]
        for i in range(leaves):
            k = rng.uniform(0.05, 0.95) * (len(pts) - 1)
            j = int(k)
            p = pts[j].lerp(pts[min(j + 1, len(pts) - 1)], k - j)
            parts.append(leaf(f"{name}Leaf{i}", leaf_size * rng.uniform(0.8, 1.2), leaf_size * 0.6, tuple(p),
                              rng.uniform(0, math.tau), droop=0.8, m=leaf_m, segs=3))
    return parts


def drape(name, top, length, sway, m, leaf_m, seed=0, leaves=5):
    """A vine hanging from `top`, curving gently as it falls `length` metres."""
    rng = random.Random(seed)
    a = rng.uniform(0, math.tau)
    pts = []
    for i in range(6):
        t = i / 5
        pts.append((top[0] + math.cos(a) * sway * math.sin(t * 2.4), top[1] + math.sin(a) * sway * math.sin(t * 2.4), top[2] - t * length))
    return vine(name, pts, 0.035, m, leaf_m, leaves=leaves, seed=seed)


def rock(name, radius, loc, m, seed=0, squash=0.7, detail=1):
    """A chunky faceted boulder (displaced icosphere, flat shaded)."""
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=detail + 1, radius=radius)
    for v in bm.verts:
        n = v.co.normalized()
        v.co = v.co * rng.uniform(0.82, 1.12)
        v.co.z *= squash
        v.co += n * 0.0
    for v in bm.verts:
        if v.co.z < -radius * squash * 0.35:
            v.co.z = -radius * squash * 0.35
    ob = _object(name, bm, m)
    ob.location = loc
    return ob


def carved_block(name, size, loc, m, rot=(0, 0, 0)):
    """A sandstone block with soft edges."""
    return box(name, size, loc, rot=rot, bevel=min(0.08, min(size) * 0.2), segs=2, m=m)


def rope(name, a, b, sag, m, radius=0.03, segs=10):
    """A sagging rope between two points."""
    pa, pb = Vector(a), Vector(b)
    pts = []
    for i in range(segs + 1):
        t = i / segs
        pts.append(tuple(pa.lerp(pb, t) + Vector((0, 0, -sag * 4 * t * (1 - t)))))
    return tube(name, pts, radius, m=m, segs=6)


def flame_glass():
    """Torch flame globe that scripts recolour (JungleTorchGlass)."""
    return mat("JungleTorchGlass", JUNGLE["Flame"], rough=0.3, emit=3.0)
