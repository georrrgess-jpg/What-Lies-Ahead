"""Shared helpers for the Castle Kingdom (World 14, Royal Faire) asset scripts.

Builds on wla_common (metres, Z up, front faces -Y, chunky bevelled flat-colour
parts) and sky_common's lathe and pennant helpers, and adds the storybook-faire
kit: the morning palette, crenellations, cone roofs with finials and flags,
striped canvas and half-timber framing.

Surfaces the level generator re-dresses by material name:
    FaireStone      castle stone (world-projected block texture in the level)
    FaireTentA      the coloured stripe of a tent or awning (recoloured per prop)
    FaireBanner     a banner's cloth (recoloured per prop)
    FaireExitGlow   the exit-trail lanterns' glass (lit by faire_exit_lantern.gd)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import bmesh, Vector, _finish  # noqa: F401
from sky_common import double_sided, finish_multi, lathe  # noqa: F401

# Castle Kingdom palette: royal blue and banner red, gold trim, cream canvas,
# grey toy stone, spring greens and warm timber.
FAIRE = {
    "Stone": "#bdb8c6",
    "StoneDark": "#8f8a9e",
    "StoneLight": "#dcd8e2",
    "Slit": "#2a2638",
    "Blue": "#2f5bd3",
    "BlueDark": "#1f3c95",
    "BlueLight": "#6f9cf2",
    "Red": "#d8343f",
    "RedDark": "#9c1f2e",
    "Gold": "#f2c14e",
    "GoldDark": "#c48a26",
    "Cream": "#f6ecd6",
    "White": "#fbf8f2",
    "Plaster": "#f7efdc",
    "Timber": "#7a4a2e",
    "TimberDark": "#4f2f1f",
    "Wood": "#b47a48",
    "WoodLight": "#d9a66b",
    "Roof": "#c9583a",
    "RoofDark": "#9a3d2a",
    "Thatch": "#e0b764",
    "Grass": "#78c25a",
    "GrassDark": "#4f9a46",
    "Leaf": "#5fb34f",
    "LeafDark": "#3f8a3c",
    "Hay": "#ecc66a",
    "HayDark": "#c99a3e",
    "Iron": "#4a4d5c",
    "IronDark": "#2c2e38",
    "Green": "#3fae5a",
    "GreenDark": "#2a7d45",
    "Yellow": "#ffd23f",
    "Purple": "#7b4fc9",
    "Orange": "#ff8c3a",
    "Rope": "#e2c991",
    "Water": "#4fa8d8",
    "Flower": "#ff7aa8",
}


def fmat(name, rough=0.65, metal=0.0, emit=0.0):
    """Material 'Faire<name>' in the palette colour `name`."""
    return mat("Faire" + name, FAIRE[name], rough=rough, metal=metal, emit=emit)


def fglow(name, color, strength=3.0):
    return mat(name, color, rough=0.35, emit=strength)


def stone():
    """The castle stone (re-dressed with the block texture in the level)."""
    return mat("FaireStone", FAIRE["Stone"], rough=0.85)


def merlons_ring(prefix, radius, z, count, height=0.9, width=0.85, depth=0.5, m=None, phase=0.0):
    """Crenellations round a circle: `count` merlons standing on z."""
    m = m or stone()
    out = []
    for i in range(count):
        a = math.tau * (i + phase) / count
        out.append(box(f"{prefix}{i}", (width, depth, height), (math.cos(a) * radius, math.sin(a) * radius, z + height / 2),
                       rot=(0, 0, a + math.pi / 2), bevel=0.06, m=m))
    return out


def merlons_line(prefix, x0, x1, y, z, count, height=0.9, depth=0.5, m=None):
    """Crenellations along X between x0 and x1 (count merlons, gaps between)."""
    m = m or stone()
    step = (x1 - x0) / count
    return [box(f"{prefix}{i}", (step * 0.55, depth, height), (x0 + step * (i + 0.5), y, z + height / 2), bevel=0.06, m=m)
            for i in range(count)]


def cone_roof(prefix, radius, z, height, m, trim=None, segs=20, flag=None, flag_m=None, finial=None):
    """A conical turret roof standing on z with a gold band, a finial ball and an
    optional pennant flag on a pole."""
    trim = trim or fmat("Gold", rough=0.35)
    parts = [cyl(prefix + "Cone", radius, height, (0, 0, z + height / 2), segs=segs, bevel=0.04, m=m, radius_top=0.04),
             cyl(prefix + "Band", radius * 1.02, 0.22, (0, 0, z + 0.11), segs=segs, bevel=0.03, m=trim),
             sphere(prefix + "Ball", max(0.14, radius * 0.08), (0, 0, z + height + 0.05), m=finial or trim, segs=10, rings=6)]
    if flag:
        pole_h = flag
        top = z + height
        parts.append(cyl(prefix + "Pole", 0.05, pole_h, (0, 0, top + pole_h / 2), segs=6, bevel=0.0, m=fmat("IronDark")))
        fl = flag_m or fmat("Red", rough=0.55)
        w = 0.5 + pole_h * 0.45
        parts.append(prism(prefix + "Flag", [(0, 0), (w, -0.22), (w * 0.82, -0.42), (0, -0.62)], 0.04,
                           (0.04, 0, top + pole_h - 0.05), rot=(0, 0, 0), m=fl))
    return parts


def pyramid_roof(prefix, half, z, height, m, trim=None):
    """A square pyramid roof (half width `half`) on z with a gold band."""
    trim = trim or fmat("Gold", rough=0.35)
    return [cyl(prefix + "Pyr", half * 1.414, height, (0, 0, z + height / 2), rot=(0, 0, math.pi / 4), segs=4, bevel=0.03, m=m,
                radius_top=0.03),
            box(prefix + "Band", (half * 2 + 0.1, half * 2 + 0.1, 0.22), (0, 0, z + 0.11), bevel=0.03, m=trim)]


def striped_cone(name, radius, z, height, mats, stripes=2, segs=24):
    """A striped tent cone (gores alternate through `mats`)."""
    profile = [(radius, z), (radius * 0.55, z + height * 0.45), (0.0, z + height)]
    return lathe(name, profile, mats, segs=segs, stripes=stripes, smooth=False, cap_bottom=True)


def striped_drum(name, radius, z0, z1, mats, stripes=2, segs=24):
    """A striped tent wall (an open-ended drum, gores through `mats`)."""
    ob = lathe(name, [(radius, z0), (radius, z1)], mats, segs=segs, stripes=stripes, smooth=False, cap_top=False, cap_bottom=False)
    return double_sided(ob)


def valance(prefix, radius, z, count, m_a, m_b, drop=0.35):
    """Scalloped tent valance: little hanging tabs round a circle under z."""
    out = []
    for i in range(count):
        a = math.tau * (i + 0.5) / count
        w = math.tau * radius / count
        out.append(prism(f"{prefix}{i}", [(-w / 2, 0), (w / 2, 0), (w * 0.3, -drop * 0.8), (0, -drop), (-w * 0.3, -drop * 0.8)], 0.03,
                         (math.cos(a) * radius, math.sin(a) * radius, z), rot=(0, 0, a + math.pi / 2), m=m_a if i % 2 == 0 else m_b))
    return out


def timber_frame(prefix, x0, x1, y, z0, z1, m, posts=4, braces=True, thick=0.16):
    """Half-timber framing on a wall face at depth y (facing -Y when y < 0)."""
    out = [box(f"{prefix}Sill", (x1 - x0, thick, thick), ((x0 + x1) / 2, y, z0 + thick / 2), bevel=0.02, m=m),
           box(f"{prefix}Head", (x1 - x0, thick, thick), ((x0 + x1) / 2, y, z1 - thick / 2), bevel=0.02, m=m)]
    for k in range(posts + 1):
        x = x0 + (x1 - x0) * k / posts
        x = min(max(x, x0 + thick / 2), x1 - thick / 2)
        out.append(box(f"{prefix}Post{k}", (thick, thick, z1 - z0), (x, y, (z0 + z1) / 2), bevel=0.02, m=m))
    if braces:
        for k in range(posts):
            xa = x0 + (x1 - x0) * k / posts
            xb = x0 + (x1 - x0) * (k + 1) / posts
            if k % 2 == 0:
                out.append(tube(f"{prefix}Brace{k}", [(xa + 0.1, y, z0 + 0.1), (xb - 0.1, y, z1 - 0.1)], thick * 0.45, m=m, segs=4))
            else:
                out.append(tube(f"{prefix}Brace{k}", [(xa + 0.1, y, z1 - 0.1), (xb - 0.1, y, z0 + 0.1)], thick * 0.45, m=m, segs=4))
    return out


def banner_cloth(name, w, h, loc, m, tails=True, rot=(0, 0, 0)):
    """A hanging banner (faces -Y) whose bottom is cut into a swallowtail."""
    outline = [(-w / 2, 0), (w / 2, 0), (w / 2, -h), (0, -h + (h * 0.18 if tails else 0)), (-w / 2, -h)]
    return prism(name, outline, 0.05, loc, rot=rot, m=m)


def crown(prefix, loc, size, m, gem=None):
    """A little gold crown: a band with five points and jewel balls."""
    x, y, z = loc
    parts = [cyl(prefix + "Band", size, size * 0.5, (x, y, z + size * 0.25), segs=16, bevel=0.03, m=m)]
    for i in range(5):
        a = math.tau * i / 5
        px, py = x + math.cos(a) * size * 0.92, y + math.sin(a) * size * 0.92
        parts.append(cyl(f"{prefix}Point{i}", size * 0.2, size * 0.6, (px, py, z + size * 0.75), segs=6, bevel=0.0, m=m, radius_top=0.01))
        parts.append(sphere(f"{prefix}Gem{i}", size * 0.12, (px, py, z + size * 1.08), m=gem or fmat("Red", rough=0.3), segs=8, rings=5))
    return parts


def wheel(prefix, radius, loc, m, hub=None, spokes=8, width=0.14):
    """A wooden spoked wheel in the XZ plane (axle along Y)."""
    x, y, z = loc
    parts = [torus(prefix + "Rim", radius, width * 0.5, loc, rot=(math.pi / 2, 0, 0), m=m, major_segs=24, minor_segs=6),
             cyl(prefix + "Hub", radius * 0.2, width * 1.6, loc, rot=(math.pi / 2, 0, 0), segs=10, bevel=0.02, m=hub or m)]
    for k in range(spokes):
        a = math.tau * k / spokes
        parts.append(tube(f"{prefix}Spoke{k}", [(x, y, z), (x + math.cos(a) * radius * 0.95, y, z + math.sin(a) * radius * 0.95)],
                          width * 0.25, m=m, segs=4))
    return parts


def rng(seed):
    return random.Random(seed)


def crown_flat(name, loc, size, m, depth=0.06):
    """A flat crown emblem (faces -Y) for banners and shields; `size` is its width."""
    w, h = size / 2, size * 0.62
    outline = [(-w, 0), (w, 0), (w, h), (w * 0.6, h * 0.55), (w * 0.3, h * 1.05), (0, h * 0.6), (-w * 0.3, h * 1.05), (-w * 0.6, h * 0.55), (-w, h)]
    return prism(name, outline, depth, loc, m=m)


def pennants(prefix, a, b, count, sag, mats, size=0.32, depth=0.02):
    """A string of triangular flags hung between points a and b (sagging)."""
    a, b = Vector(a), Vector(b)
    parts = [tube(prefix + "Line", [a.lerp(b, i / 8) - Vector((0, 0, sag * 4 * (i / 8) * (1 - i / 8))) for i in range(9)], 0.012,
                  m=fmat("Rope"), segs=4)]
    d = (b - a).normalized()
    yaw = math.atan2(d.y, d.x)
    for i in range(count):
        t = (i + 0.5) / count
        p = a.lerp(b, t) - Vector((0, 0, sag * 4 * t * (1 - t)))
        parts.append(prism(f"{prefix}Flag{i}", [(-size * 0.5, 0), (size * 0.5, 0), (0, -size * 1.2)], depth, (p.x, p.y, p.z), rot=(0, 0, yaw),
                           m=mats[i % len(mats)]))
    return parts
