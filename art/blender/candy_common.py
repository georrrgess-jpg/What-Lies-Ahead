"""Shared helpers for the Sugar Rush Factory (World 8, Candy Works) asset scripts.

Builds on wla_common (metres, Z up, front faces -Y, chunky bevelled flat-colour
parts) and adds the confectionery kit: the factory palette, candy-cane
striped posts, swirl-striped pipes, wrapped sweets, gumballs and icing trim.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import bmesh, Vector  # noqa: F401
from mathutils import Matrix  # noqa: F401

# Sugar Rush palette: high-key pastels and chocolate browns.
CANDY = {
    "Pink": "#ff7eb6",
    "PinkDeep": "#e8508f",
    "PinkPale": "#ffc4dc",
    "Mint": "#7fe3c4",
    "MintDeep": "#3fb894",
    "Butter": "#ffe08a",
    "Lemon": "#ffd23f",
    "Lilac": "#c9a7ff",
    "LilacDeep": "#8f6ae0",
    "Sky": "#9fd8ff",
    "Cream": "#fff3e0",
    "White": "#fffaf4",
    "Choc": "#7a4630",
    "ChocDark": "#3e2219",
    "ChocLight": "#a8673f",
    "Ginger": "#b8743c",
    "GingerDark": "#8a4f26",
    "Red": "#ff4a5e",
    "RedDeep": "#c8243c",
    "Orange": "#ff9a3c",
    "Pistachio": "#b7e07a",
    "Steel": "#c7c4d6",
    "SteelDark": "#6e6a82",
    "Gold": "#ffc94a",
    "Charcoal": "#2a2233",
}


def cmat(name, rough=0.55, metal=0.0, emit=0.0):
    """Material 'Candy<name>' in the candy palette colour `name`."""
    return mat("Candy" + name, CANDY[name], rough=rough, metal=metal, emit=emit)


def cglow(name, color, strength=2.5):
    return mat(name, color, rough=0.35, emit=strength)


def glass_mat(name="CandyGlass", color="#dff4ff", alpha=0.32, emit=0.15):
    """See-through glass (alpha-blended in Godot)."""
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = mat(name, color, rough=0.08, emit=emit)
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Alpha"].default_value = alpha
    try:
        m.surface_render_method = "BLENDED"
    except Exception:
        pass
    try:
        m.blend_method = "BLEND"
    except Exception:
        pass
    return m


def frosted_mat():
    """Frosted factory window glass, lit by the daylight behind it."""
    return mat("CandyFrosted", "#e8f6ff", rough=0.3, emit=1.1)


GUMBALL_COLORS = ("#ff4a5e", "#ffd23f", "#7fe3c4", "#ff7eb6", "#9fd8ff", "#c9a7ff", "#ff9a3c", "#b7e07a")


def gumball_mats():
    return [mat(f"CandyGumball{i}", c, rough=0.25) for i, c in enumerate(GUMBALL_COLORS)]


def ico(name, radius, loc, m, subdiv=1):
    """Low-poly ball (gumballs, sprinkles)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    ob = bpy.data.objects.new(name, bpy.data.meshes.new(name))
    source_collection().objects.link(ob)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.materials.append(m)
    for p in ob.data.polygons:
        p.use_smooth = True
    ob.location = loc
    return ob


def striped_post(name, radius, height, loc, a, b, bands=8, segs=12):
    """A candy-striped post: alternating colour bands standing on loc."""
    h = height / bands
    return [cyl(f"{name}B{i}", radius, h + 0.002, (loc[0], loc[1], loc[2] + h * (i + 0.5)), segs=segs, bevel=0.0,
                m=a if i % 2 == 0 else b) for i in range(bands)]


def swirl(name, radius, length, loc, rot, a, b, turns=None, segs=10, stripe=0.16):
    """A pipe of colour `a` with a helical stripe of colour `b` wound round it
    (lollipop-striped pipe) lying along its local Z, centred on loc."""
    turns = turns if turns is not None else max(1.0, length / (radius * 4.0))
    rmat = Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X")
    parts = [cyl(name, radius, length, loc, rot=rot, segs=segs * 2, bevel=0.0, m=a)]
    pts = []
    steps = int(turns * 14) + 2
    for i in range(steps + 1):
        t = i / steps
        ang = math.tau * turns * t
        local = Vector((math.cos(ang) * radius * 1.01, math.sin(ang) * radius * 1.01, -length / 2 + length * t))
        pts.append(tuple(Vector(loc) + rmat @ local))
    parts.append(tube(name + "Stripe", pts, radius * stripe, m=b, segs=5))
    return parts


def cane(name, radius, height, loc, hook=0.35, rot_z=0.0, a=None, b=None):
    """A candy cane standing on loc with a hook at the top facing +X (before rot_z)."""
    a = a or cmat("White", rough=0.3)
    b = b or cmat("Red", rough=0.3)
    parts = []
    bands = max(4, int(height / (radius * 3.0)))
    hstep = height / bands
    for i in range(bands):
        parts.append(cyl(f"{name}S{i}", radius, hstep + 0.002, (0, 0, hstep * (i + 0.5)), segs=10, bevel=0.0, m=a if i % 2 == 0 else b))
    for i in range(6):
        a0 = math.pi - math.pi * i / 6
        a1 = math.pi - math.pi * (i + 1) / 6
        pts = [(hook + math.cos(x) * hook, 0, height + math.sin(x) * hook) for x in (a0, (a0 + a1) / 2, a1)]
        parts.append(tube(f"{name}H{i}", pts, radius, m=a if i % 2 else b, segs=10))
    return place(parts, loc, rot_z)


def wrapped(name, radius, loc, rot_z, body, twist):
    """A wrapped bonbon: an oval sweet with a pleated twist at each end."""
    parts = [sphere(name, radius, (0, 0, 0), scale=(1.35, 1.0, 1.0), m=body, segs=14, rings=8)]
    for s in (-1, 1):
        parts.append(cyl(f"{name}T{s}", radius * 0.25, radius * 0.5, (s * radius * 1.55, 0, 0), rot=rad(0, 90, 0), segs=8, bevel=0.0, m=twist))
        # The pleated end flares away from the sweet.
        parts.append(cyl(f"{name}F{s}", radius * 0.2, radius * 0.45, (s * radius * 2.0, 0, 0), rot=rad(0, 90 * s, 0), segs=8, bevel=0.0,
                         m=twist, radius_top=radius * 0.75))
    return place(parts, loc, rot_z)


def lollipop(name, radius, stick, loc, a, b, rot_z=0.0, thick=0.25):
    """A flat swirl lollipop on a stick, facing -Y."""
    white = cmat("White", rough=0.4)
    parts = [cyl(name + "Stick", radius * 0.07, stick, (0, 0, stick / 2), segs=8, bevel=0.0, m=white)]
    cz = stick + radius * 0.95
    parts.append(cyl(name + "Disc", radius, radius * thick, (0, 0, cz), rot=rad(90, 0, 0), segs=28, bevel=radius * 0.08, m=a))
    pts = []
    for i in range(60):
        t = i / 59
        ang = t * math.tau * 2.6
        r = radius * 0.92 * t
        pts.append((math.cos(ang) * r, -radius * thick * 0.5 - 0.004, cz + math.sin(ang) * r))
    parts.append(tube(name + "Swirl", pts, radius * 0.085, m=b, segs=6))
    pts_b = [(x, -y, z) for x, y, z in pts]
    parts.append(tube(name + "SwirlB", pts_b, radius * 0.085, m=b, segs=6))
    return place(parts, loc, rot_z)


def icing_drips(name, start, end, count, length, seed=3, m=None, y_out=0.0):
    """A wavy icing line with rounded drips hanging from start -> end."""
    m = m or cmat("White", rough=0.4)
    rng = random.Random(seed)
    a, b = Vector(start), Vector(end)
    out = [tube(name + "Line", [tuple(a.lerp(b, i / 12) + Vector((0, y_out, 0.03 * math.sin(i * 1.9)))) for i in range(13)], 0.05, m=m, segs=6)]
    for i in range(count):
        p = a.lerp(b, (i + rng.uniform(0.25, 0.75)) / count) + Vector((0, y_out, 0))
        ln = length * rng.uniform(0.4, 1.0)
        out.append(cyl(f"{name}D{i}", 0.045, ln, (p.x, p.y, p.z - ln * 0.5), segs=6, bevel=0.0, m=m))
        out.append(sphere(f"{name}T{i}", 0.06, (p.x, p.y, p.z - ln), m=m, segs=8, rings=5))
    return out
