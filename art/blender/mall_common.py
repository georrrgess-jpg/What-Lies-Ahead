"""Shared helpers for the Megamall Midnight (World 6) asset scripts.

Builds on wla_common (metres, Z up, front faces -Y, chunky bevelled flat-colour
parts) and adds the mall kit: the retro-futurist palette (chrome, terrazzo,
pink and teal neon against midnight navy) and a few recurring pieces.

Material names the level script recolours or swaps at runtime:
    MallWater        fountain water (animated shader in the level)
    MallAccent       a prop's tint colour (food stalls, carts: set per instance)
    MallNeonPink / MallNeonTeal / MallNeonAmber   neon tubes (the power cut dims them)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import bmesh, Vector  # noqa: F401

MALL = {
    "Navy": "#1a2050",
    "NavyDark": "#10142f",
    "Chrome": "#c9d0e0",
    "ChromeDark": "#7d859c",
    "Terrazzo": "#e9dcd2",
    "TerrazzoPink": "#e6a9b8",
    "Cream": "#fff2dc",
    "White": "#f6f6ff",
    "Pink": "#ff4fa8",
    "PinkDark": "#b8256f",
    "Teal": "#1fb8b0",
    "TealDark": "#0e6f74",
    "Mint": "#8ff5c8",
    "Violet": "#7a4cf0",
    "VioletDark": "#3d2490",
    "Amber": "#ffb547",
    "Orange": "#ff7a2a",
    "Yellow": "#ffd23f",
    "Red": "#e2343f",
    "RedDark": "#9c1f2c",
    "Wood": "#a8673f",
    "Leaf": "#2f9a5a",
    "LeafDark": "#1d6b44",
    "Trunk": "#8a6040",
    "Rubber": "#22222e",
    "Charcoal": "#2a2838",
    "Skin": "#f3d9c8",
    "Moon": "#fff2c8",
}


def mmat(name, rough=0.6, metal=0.0, emit=0.0):
    """Material 'Mall<name>' in the mall palette colour `name`."""
    return mat("Mall" + name, MALL[name], rough=rough, metal=metal, emit=emit)


def chrome():
    return mat("MallChrome", MALL["Chrome"], rough=0.18, metal=0.85)


def chrome_dark():
    return mat("MallChromeDark", MALL["ChromeDark"], rough=0.3, metal=0.7)


def neon(name, color, strength=3.2):
    """Emissive neon tube material 'MallNeon<name>'."""
    return mat("MallNeon" + name, color, rough=0.3, emit=strength)


def glass(name="MallGlass", color="#9fd8ff", alpha=0.28, emit=0.08):
    """Alpha-blended glass (balustrades, the elevator, display windows)."""
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = mat(name, color, rough=0.08, emit=emit)
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Alpha"].default_value = alpha
    for attr, value in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
        try:
            setattr(m, attr, value)
        except Exception:
            pass
    return m


def water():
    """Placeholder for the fountain water (the level swaps in a shader)."""
    return mat("MallWater", "#4fd0ff", rough=0.05, emit=0.4)


def neon_tube(name, points, radius, m, segs=8):
    """A neon tube along a polyline, with round caps."""
    return [tube(name, points, radius, m=m, segs=segs)]


def ring_tube(name, radius, z, minor, m, segs=48):
    return torus(name, radius, minor, (0, 0, z), m=m, major_segs=segs, minor_segs=8)


def cushion(name, size, loc, m, rot=(0, 0, 0)):
    """A soft rounded block (seats, kiddie-ride saddles)."""
    return box(name, size, loc, rot=rot, bevel=min(size) * 0.4, segs=3, m=m)
