"""Shared helpers for the Frostpeak Resort (World 5) asset scripts.

Builds on wla_common (same conventions: metres, Z up, front faces -Y, chunky
bevelled flat-colour parts) and adds the winter kit: the resort palette,
snow caps that drape over edges, lumpy snow mounds, icicles and window glass.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import bmesh, Vector  # noqa: F401

# Frostpeak palette: warm timber and amber light against lavender snow and icy blues.
FROST = {
    "Snow": "#e4e4fa",
    "SnowShade": "#bdbbea",
    "Timber": "#7a4a36",
    "TimberDark": "#4a2c26",
    "TimberLight": "#9c6646",
    "Log": "#8a5a3c",
    "LogEnd": "#d8b07a",
    "Stone": "#6c678c",
    "StoneDark": "#4b4768",
    "Roof": "#3a2b48",
    "RoofTrim": "#24192e",
    "Red": "#e2343f",
    "RedDark": "#9c1f2c",
    "Navy": "#20285a",
    "Ice": "#7fd2ff",
    "IceDeep": "#2f7fc0",
    "Amber": "#ffb547",
    "Glow": "#ffc46b",
    "Pine": "#1d5446",
    "PineLight": "#2c7258",
    "PineDark": "#123a33",
    "Steel": "#8b91ab",
    "SteelDark": "#3a3a52",
    "Charcoal": "#26232f",
    "Yellow": "#ffd23f",
    "Cyan": "#5ee8ff",
    "Cream": "#fff2dc",
    "White": "#f6f6ff",
    "Orange": "#ff7a2a",
    "Green": "#3fc46a",
}


def fmat(name, rough=0.65, metal=0.0, emit=0.0, color=None):
    """Material from the frost palette (or an explicit hex colour)."""
    return mat("Frost" + name if color is None else name, FROST.get(name, color) if color is None else color,
               rough=rough, metal=metal, emit=emit)


def fglow(name, color, strength=3.0):
    return mat(name, color, rough=0.35, emit=strength)


def snow_mat():
    return mat("FrostSnow", FROST["Snow"], rough=0.8)


def glass_mat():
    """Warm lit window glass (emissive amber)."""
    return mat("FrostWindow", FROST["Glow"], rough=0.25, emit=2.2)


def ice_mat():
    """Translucent ice (alpha-blended in Godot)."""
    name = "FrostIceShell"
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = mat(name, "#9fe0ff", rough=0.12, emit=0.35)
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Alpha"].default_value = 0.55
    try:
        m.surface_render_method = "BLENDED"
    except Exception:
        pass
    try:
        m.blend_method = "BLEND"
    except Exception:
        pass
    return m


def snow_cap(name, size, loc, rot=(0, 0, 0), drips=6, seed=1, m=None):
    """A soft slab of snow lying on a surface, with blobby drips over the long edges.
    size = (x, y, thickness); loc is the centre of the slab's underside."""
    m = m or snow_mat()
    rng = random.Random(seed)
    sx, sy, sz = size
    parts = [box(name, (sx, sy, sz), (loc[0], loc[1], loc[2] + sz * 0.5), rot=rot, bevel=min(sz * 0.48, 0.25), segs=3, m=m)]
    rmat = Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X")
    for i in range(drips):
        t = (i + 0.5) / drips - 0.5
        side = 1 if i % 2 else -1
        r = sz * rng.uniform(0.55, 0.9)
        local = Vector((t * sx * 0.9 + rng.uniform(-0.1, 0.1) * sx / drips, side * sy * 0.5, sz * 0.35))
        p = Vector(loc) + rmat @ local
        parts.append(sphere(f"{name}Drip{i}", r, tuple(p), scale=(1.4, 0.8, 1.0), m=m, segs=8, rings=5))
    return parts


def snow_mound(name, radius, height, loc, seed=1, lumps=7, m=None):
    """Lumpy pile of snow (a few squashed spheres)."""
    m = m or snow_mat()
    rng = random.Random(seed)
    parts = [sphere(name, radius, loc, scale=(1.0, 1.0, height / radius), m=m, segs=14, rings=8)]
    for i in range(lumps):
        a = math.tau * i / lumps + rng.uniform(-0.3, 0.3)
        r = radius * rng.uniform(0.35, 0.6)
        d = radius * rng.uniform(0.45, 0.75)
        parts.append(sphere(f"{name}Lump{i}", r, (loc[0] + math.cos(a) * d, loc[1] + math.sin(a) * d, loc[2]),
                            scale=(1.0, 1.0, height / radius * rng.uniform(0.7, 1.0)), m=m, segs=10, rings=6))
    return parts


def icicles(name, start, end, count, length, seed=3, m=None):
    """A row of icicles hanging from the line start -> end."""
    m = m or mat("FrostIcicle", "#bfeaff", rough=0.15, emit=0.25)
    rng = random.Random(seed)
    a, b = Vector(start), Vector(end)
    out = []
    for i in range(count):
        p = a.lerp(b, (i + rng.uniform(0.2, 0.8)) / count)
        ln = length * rng.uniform(0.4, 1.0)
        out.append(cone_down(f"{name}{i:02d}", 0.05 * rng.uniform(0.8, 1.2), ln, (p.x, p.y, p.z), m))
    return out


def cone_down(name, radius, length, top, m):
    """Downward-pointing cone hanging from `top`."""
    return cyl(name, 0.002, length, (top[0], top[1], top[2] - length * 0.5), segs=6, bevel=0.0, m=m, radius_top=radius)


def window(name, w, h, loc, depth=0.08, frame_m=None, glass_m=None, mullions=(1, 1), rot_z=0.0, frost=True):
    """A lit window facing -Y: frame, glowing glass, mullions and a frosty sill."""
    frame_m = frame_m or fmat("TimberDark")
    glass_m = glass_m or glass_mat()
    parts = [
        box(name + "Frame", (w + 0.16, depth, h + 0.16), loc, bevel=0.03, m=frame_m),
        box(name + "Glass", (w, depth + 0.02, h), (loc[0], loc[1] - 0.01, loc[2]), bevel=0.0, m=glass_m),
    ]
    cols, rows = mullions
    for i in range(1, cols):
        x = loc[0] - w / 2 + w * i / cols
        parts.append(box(f"{name}MullV{i}", (0.05, depth + 0.05, h), (x, loc[1] - 0.02, loc[2]), bevel=0.0, m=frame_m))
    for j in range(1, rows):
        z = loc[2] - h / 2 + h * j / rows
        parts.append(box(f"{name}MullH{j}", (w, depth + 0.05, 0.05), (loc[0], loc[1] - 0.02, z), bevel=0.0, m=frame_m))
    if frost:
        parts.append(box(name + "Sill", (w + 0.3, depth + 0.16, 0.08), (loc[0], loc[1] - 0.06, loc[2] - h / 2 - 0.1), bevel=0.02, m=frame_m))
        parts.append(box(name + "SillSnow", (w + 0.26, depth + 0.14, 0.07), (loc[0], loc[1] - 0.07, loc[2] - h / 2 - 0.03), bevel=0.03, m=snow_mat()))
    if rot_z:
        place(parts, rot_z=rot_z)
    return parts


def log(name, radius, length, loc, rot, m=None):
    """A bark log lying along its local Z axis (rotate with `rot`), with pale end grain."""
    m = m or fmat("Log")
    end_m = fmat("LogEnd")
    rmat = Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X")
    parts = [cyl(name, radius, length, loc, rot=rot, segs=10, bevel=0.03, m=m)]
    for i, s in enumerate((-1, 1)):
        p = Vector(loc) + rmat @ Vector((0, 0, s * length * 0.5))
        parts.append(cyl(f"{name}End{i}", radius * 0.82, 0.02, tuple(p), rot=rot, segs=10, bevel=0.0, m=end_m))
    return parts
