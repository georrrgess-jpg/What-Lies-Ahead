"""Shared helpers for the Fright Fair (World 11, Ghost Train) asset scripts.

Builds on wla_common (metres, Z up, front faces -Y, chunky bevelled flat-colour
parts) and sky_common's lathe / multi-material helpers, and adds the haunted
fairground kit: the midnight palette (violet, toxic green, pumpkin orange,
bone white), carved pumpkins, gravestones, twisted dead trees, wrought iron and
the shared "FrightExitGlow" / "FrightBulb" emissive materials.

A kit script saves its parts as separately named objects of one .glb, so a
whole world of small props costs one .blend and one import.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import bmesh, Vector, _finish, source_collection  # noqa: F401
from sky_common import lathe, finish_multi, double_sided  # noqa: F401

# Fright Fair palette: midnight violet, toxic green, pumpkin orange, bone white.
FRIGHT = {
    "Night": "#17112a",
    "Ink": "#221838",
    "Violet": "#3b2366",
    "VioletLight": "#6a45a8",
    "Purple": "#7a3fd0",
    "Plum": "#5a2448",
    "Green": "#6cff6a",
    "GreenDark": "#2f8f4a",
    "Moss": "#4a6a3a",
    "Hedge": "#2c4a3a",
    "Orange": "#ff8a1e",
    "OrangeDark": "#c85a12",
    "Pumpkin": "#f27a1a",
    "Stem": "#5a6a2a",
    "Bone": "#f2ead8",
    "BoneDark": "#c9bda0",
    "Crimson": "#c8304e",
    "CrimsonDark": "#8a1f3a",
    "Gold": "#f0c24a",
    "Iron": "#2a2438",
    "IronLight": "#4a4260",
    "Wood": "#7a4a36",
    "WoodDark": "#4e2e26",
    "WoodLight": "#a06a48",
    "Brick": "#6a3a44",
    "BrickDark": "#4a2834",
    "Stone": "#8f8aa2",
    "StoneDark": "#5e5a72",
    "Moon": "#e8e4ff",
    "Hay": "#d9b45a",
    "Canvas": "#e6dcc4",
}


def fmat(name, rough=0.6, metal=0.0, emit=0.0):
    """Material 'Fright<name>' in the palette colour `name`."""
    return mat("Fright" + name, FRIGHT[name], rough=rough, metal=metal, emit=emit)


def fglow(name, color, strength=3.0):
    return mat(name, color, rough=0.35, emit=strength)


def bulb_green():
    return fglow("FrightBulb", "#9cff8a", 3.2)


def bulb_orange():
    return fglow("FrightBulbOrange", "#ffb24a", 3.0)


def exit_glow():
    """The exit-trail lanterns' glow (scripts/props/fright_exit_lantern.gd swaps it)."""
    return fglow("FrightExitGlow", "#ffa63a", 1.5)


def pumpkin(prefix, loc, r=0.32, carved=True, seed=1, glow=None, squash=0.82, yaw=0.0):
    """A ribbed pumpkin (eight lobes) with a curly stem; carved ones get a
    glowing triangle-eyed grin facing -Y (rotated by `yaw`)."""
    rng = random.Random(seed)
    x, y, z = loc
    parts = []
    body = fmat("Pumpkin", rough=0.55)
    dark = fmat("OrangeDark", rough=0.6)
    for k in range(8):
        a = math.tau * k / 8 + yaw
        parts.append(sphere(f"{prefix}Lobe{k}", r * 0.62, (x + math.cos(a) * r * 0.42, y + math.sin(a) * r * 0.42, z + r * squash),
                            scale=(1.0, 1.0, squash * 1.25), m=body if k % 2 else dark, segs=10, rings=7))
    parts.append(sphere(f"{prefix}Core", r * 0.8, (x, y, z + r * squash), scale=(1, 1, squash * 1.15), m=body, segs=12, rings=8))
    top = z + r * squash * 2.0
    parts.append(tube(f"{prefix}Stem", [(x, y, top - 0.04), (x + 0.03, y + 0.01, top + r * 0.3), (x + r * 0.25 * rng.uniform(0.6, 1.0), y, top + r * 0.38)],
                      r * 0.11, m=fmat("Stem", rough=0.8), segs=6, radius_end=r * 0.05))
    if carved:
        g = glow or fglow("FrightPumpkinGlow", "#ffcf5a", 3.5)
        fy = -r * 0.98
        c, s = math.cos(yaw), math.sin(yaw)

        def at(px, pz):
            return (x + px * c - fy * s, y + px * s + fy * c, z + r * squash + pz)
        for side in (-1, 1):
            parts.append(prism(f"{prefix}Eye{side}", [(-r * 0.16, 0), (r * 0.16, 0), (0, r * 0.26)], 0.05, at(side * r * 0.32, r * 0.12),
                               rot=(0, 0, yaw), m=g))
        parts.append(prism(f"{prefix}Nose", [(-r * 0.08, 0), (r * 0.08, 0), (0, r * 0.14)], 0.05, at(0, -r * 0.05), rot=(0, 0, yaw), m=g))
        mouth = []
        for i in range(9):
            t = i / 8
            px = (t - 0.5) * r * 1.1
            pz = -r * 0.32 - math.sin(t * math.pi) * r * 0.16 + (0.06 * r if i % 2 else 0.0)
            mouth.append((px, pz))
        lower = [(px, pz - r * 0.14 - (0.0 if i % 2 else 0.05 * r)) for i, (px, pz) in enumerate(mouth)]
        outline = mouth + list(reversed(lower))
        parts.append(prism(f"{prefix}Mouth", outline, 0.05, at(0, 0), rot=(0, 0, yaw), m=g))
    return parts


def gravestone(prefix, loc, kind=0, h=1.0, yaw=0.0, seed=1):
    """A chunky gravestone on a small plinth: 0 rounded slab, 1 cross, 2 obelisk."""
    x, y, z = loc
    stone, darks = fmat("Stone", rough=0.9), fmat("StoneDark", rough=0.9)
    p = [box(f"{prefix}Plinth", (0.8, 0.45, 0.16), (0, 0, 0.08), bevel=0.03, m=darks)]
    if kind == 0:
        p += [box(f"{prefix}Slab", (0.62, 0.18, h * 0.75), (0, 0, 0.16 + h * 0.375), bevel=0.05, m=stone),
              cyl(f"{prefix}Top", 0.31, 0.18, (0, 0, 0.16 + h * 0.75), rot=rad(90, 0, 0), segs=16, bevel=0.04, m=stone),
              text(f"{prefix}RIP", "RIP", 0.18, 0.02, (0, -0.1, 0.16 + h * 0.6), m=darks)]
    elif kind == 1:
        p += [box(f"{prefix}Upright", (0.18, 0.18, h), (0, 0, 0.16 + h * 0.5), bevel=0.04, m=stone),
              box(f"{prefix}Arm", (0.62, 0.18, 0.18), (0, 0, 0.16 + h * 0.7), bevel=0.04, m=stone)]
    else:
        p += [cyl(f"{prefix}Obelisk", 0.22, h * 1.1, (0, 0, 0.16 + h * 0.55), segs=4, bevel=0.03, m=stone, radius_top=0.12),
              cyl(f"{prefix}Point", 0.12, 0.2, (0, 0, 0.16 + h * 1.2), segs=4, bevel=0.0, m=stone, radius_top=0.01)]
    rng = random.Random(seed)
    tilt = rng.uniform(-0.12, 0.12)
    return place(p, loc=(x, y, z), rot_z=yaw + tilt)


def dead_tree(prefix, loc, height=6.0, seed=1, m=None):
    """A twisted, leafless tree: a tapering trunk with forking branches."""
    rng = random.Random(seed)
    m = m or fmat("Ink", rough=0.9)
    x, y, z = loc
    parts = []
    trunk = [(x, y, z - 0.2)]
    for i in range(1, 6):
        t = i / 5
        trunk.append((x + rng.uniform(-0.35, 0.35) * t, y + rng.uniform(-0.35, 0.35) * t, z + height * 0.62 * t))
    parts.append(tube(f"{prefix}Trunk", trunk, height * 0.07, m=m, segs=8, radius_end=height * 0.035))
    parts.append(cyl(f"{prefix}Root", height * 0.11, 0.4, (x, y, z), segs=8, bevel=0.03, m=m, radius_top=height * 0.06))

    def branch(name, start, direction, length, radius, depth):
        pts = [start]
        d = Vector(direction).normalized()
        p0 = Vector(start)
        for k in range(3):
            d = (d + Vector((rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), rng.uniform(-0.1, 0.25)))).normalized()
            p0 = p0 + d * length / 3
            pts.append(tuple(p0))
        parts.append(tube(name, pts, radius, m=m, segs=6, radius_end=radius * 0.35))
        if depth > 0:
            for j in range(2):
                branch(f"{name}_{j}", pts[2 + j % 2], (d.x + rng.uniform(-0.8, 0.8), d.y + rng.uniform(-0.8, 0.8), d.z + 0.3), length * 0.55,
                       radius * 0.55, depth - 1)
    top = trunk[-1]
    for k in range(4):
        a = math.tau * k / 4 + rng.uniform(-0.4, 0.4)
        start = trunk[3 + k % 3] if k < 3 else top
        branch(f"{prefix}Branch{k}", start, (math.cos(a), math.sin(a), 0.6), height * 0.45, height * 0.035, 1)
    return parts


def iron_spears(prefix, length, height, m, spacing=0.22, y=0.0, x0=None):
    """A row of wrought-iron bars with spear tips along X, centred on x = 0."""
    parts = []
    n = max(2, int(length / spacing))
    start = -length / 2 if x0 is None else x0
    for i in range(n + 1):
        x = start + i * length / n
        parts.append(cyl(f"{prefix}Bar{i}", 0.022, height, (x, y, height / 2), segs=5, bevel=0.0, m=m))
        parts.append(cyl(f"{prefix}Tip{i}", 0.05, 0.14, (x, y, height + 0.07), segs=4, bevel=0.0, m=m, radius_top=0.0))
    return parts
