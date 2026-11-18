"""Shared helpers for the Toybox Town (World 15, Toy Shop) asset scripts.

Builds on wla_common (metres, Z up, front faces -Y, chunky bevelled flat-colour
parts) and sky_common's lathe and double-sided shells, and adds the toy-shop
palette: primary red, yellow and blue, warm wood and cream, and the letter
block that most of the world is built from.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import bmesh, Vector, _finish, source_collection  # noqa: F401
from sky_common import double_sided, finish_multi, lathe  # noqa: F401

# Toybox Town palette: nursery primaries, warm wood, cream and a night navy.
TOY = {
    "Red": "#e2443a",
    "RedDark": "#a8282a",
    "Yellow": "#f2c23a",
    "YellowDark": "#d1952a",
    "Blue": "#3b6fd1",
    "BlueDark": "#2a4c96",
    "BlueLight": "#8fb6f0",
    "Green": "#4fae5a",
    "GreenDark": "#2f7a44",
    "Orange": "#f08a2e",
    "Pink": "#f29ab8",
    "Purple": "#8a5bc9",
    "Cream": "#f6ead2",
    "White": "#fbf7ef",
    "Wood": "#c98d55",
    "WoodDark": "#8a5530",
    "WoodLight": "#e2b27a",
    "Brass": "#e0b04a",
    "Tin": "#b9c2cf",
    "TinDark": "#6e7a8c",
    "Navy": "#23305e",
    "Ink": "#1c1a2a",
    "Plush": "#b07850",
    "PlushLight": "#e2b88c",
    "Felt": "#3f8a5a",
    "Paper": "#f3e6cc",
}


def tmat(name, rough=0.55, metal=0.0, emit=0.0):
    """Material 'Toy<name>' in the palette colour `name`."""
    return mat("Toy" + name, TOY[name], rough=rough, metal=metal, emit=emit)


def tglow(name, color, strength=3.0):
    return mat(name, color, rough=0.35, emit=strength)


PRIMARIES = ("Red", "Yellow", "Blue", "Green")
LETTERS = {"Red": "ABC", "Yellow": "TOY", "Blue": "XYZ", "Green": "123"}


def letter_block(prefix, size, colour, loc=(0, 0, 0), rot_z=0.0, letters=None):
    """A wooden ABC block: cream body with a coloured inset panel and a raised
    letter on each side face and on top. Origin at the centre of its base."""
    body = tmat("Cream", rough=0.6)
    panel = tmat(colour, rough=0.5)
    ink = tmat("White" if colour in ("Blue", "Red", "Green") else "Blue", rough=0.5)
    letters = letters or LETTERS[colour]
    s = size
    x0, y0, z0 = loc
    parts = [box(prefix + "Body", (s, s, s), (x0, y0, z0 + s / 2), rot=(0, 0, rot_z), bevel=s * 0.06, m=body)]
    inset = s * 0.8
    for k in range(4):
        a = rot_z + k * math.pi / 2
        nx, ny = -math.sin(a), -math.cos(a)
        cx, cy = x0 + nx * s / 2, y0 + ny * s / 2
        parts.append(box(f"{prefix}Panel{k}", (inset, s * 0.04, inset), (cx, cy, z0 + s / 2), rot=(0, 0, -a), bevel=s * 0.02, m=panel))
        parts.append(text(f"{prefix}Letter{k}", letters[k % len(letters)], s * 0.55, s * 0.05,
                          (cx + nx * s * 0.03, cy + ny * s * 0.03, z0 + s / 2), rot=(0, 0, -a), m=ink))
    parts.append(box(prefix + "TopPanel", (inset, inset, s * 0.04), (x0, y0, z0 + s), rot=(0, 0, rot_z), bevel=s * 0.02, m=panel))
    parts.append(star(prefix + "TopStar", s * 0.26, s * 0.05, (x0, y0, z0 + s + s * 0.03), rot=(math.pi / 2, 0, rot_z), m=ink))
    return parts
