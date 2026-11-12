"""Shared helpers for the Neon Rooftops asset scripts (build_neon_*.py).

Builds on wla_common (primitives, merge, save) and adds the night-city palette
and the material conventions Neon Skyline's level script understands:

    NeonHalo_<hex>   crossed halo quads -> additive glow in that colour
    NeonHolo...      hologram surfaces  -> additive scanline hologram shader
    Blink*           objects whose name starts with "Blink" blink on and off
    Spin*            objects whose name starts with "Spin" turn slowly
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import HALO_SCALE

NEON = {
    "Concrete": "#3a3650",
    "ConcreteDark": "#262338",
    "ConcreteLight": "#5a5672",
    "Steel": "#4c5068",
    "SteelDark": "#24232f",
    "SteelLight": "#8a8ea8",
    "Rust": "#7a3a3a",
    "Hazard": "#ffc62e",
    "Ink": "#141220",
    "Cyan": "#2ef2ff",
    "Magenta": "#ff2fae",
    "Violet": "#9a5bff",
    "Amber": "#ffb43a",
    "Lime": "#b6ff3a",
    "Red": "#ff3a4a",
    "White": "#f2f0ff",
}


def nmat(name, color=None, rough=0.6, metal=0.0, emit=0.0):
    """Material from the neon palette (key) or a hex colour."""
    if color is None:
        color = NEON[name]
    elif color in NEON:
        color = NEON[color]
    return mat(name, color, rough=rough, metal=metal, emit=emit)


def neon_glow(name, color, strength=3.0):
    """Emissive neon tube / LED material."""
    return nmat(name, color, rough=0.3, emit=strength)


def halo_mat(color):
    """Halo placeholder; the level swaps it for an additive glow of `color`."""
    return mat("NeonHalo_" + color.lstrip("#"), color, rough=1.0)


def neon_bulb(name, radius, loc, color, strength=3.0, halo=True, halo_scale=HALO_SCALE):
    """Low-poly glowing bulb plus three crossed halo quads in its colour."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)
    if halo:
        uv = bm.loops.layers.uv.new("UVMap")
        h = radius * halo_scale
        corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        for axis in range(3):
            verts = []
            for cu, cv in corners:
                co = [0.0, 0.0, 0.0]
                co[(axis + 1) % 3] = cu * h
                co[(axis + 2) % 3] = cv * h
                verts.append(bm.verts.new(co))
            face = bm.faces.new(verts)
            face.material_index = 1
            for loop, (cu, cv) in zip(face.loops, corners):
                loop[uv].uv = ((cu + 1) * 0.5, (cv + 1) * 0.5)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    source_collection().objects.link(ob)
    me.materials.append(neon_glow("Bulb_" + color.lstrip("#"), color, strength))
    if halo:
        me.materials.append(halo_mat(color))
    ob.location = loc
    return ob


FONT_PATH = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "fonts", "LilitaOne-Regular.ttf"))


def sign_text(name, body, size, depth, loc=(0, 0, 0), rot=(0, 0, 0), m=None, align="CENTER"):
    """Extruded lettering in the game's display font (Lilita One), as a mesh.
    Faces -Y by default, like wla_common.text()."""
    curve = bpy.data.curves.new(name + "_curve", "FONT")
    curve.body = body
    if os.path.exists(FONT_PATH):
        curve.font = bpy.data.fonts.load(FONT_PATH, check_existing=True)
    curve.size = size
    curve.extrude = depth / 2.0
    curve.align_x = align
    curve.align_y = "CENTER"
    curve.resolution_u = 3
    tmp = bpy.data.objects.new(name + "_tmp", curve)
    bpy.context.scene.collection.objects.link(tmp)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    bpy.data.curves.remove(curve)
    me.name = name
    ob = bpy.data.objects.new(name, me)
    source_collection().objects.link(ob)
    if m is not None:
        me.materials.append(m)
    ob.rotation_euler = Euler((math.radians(90) + rot[0], rot[1], rot[2]), "XYZ")
    ob.location = loc
    return ob


def tube_letters(prefix, body, size, loc, face_m, side_m, depth=0.25):
    """Chunky sign letters facing -Y: a dark extruded body with a glowing face."""
    back = sign_text(prefix + "Body", body, size, depth, loc, m=side_m)
    front = sign_text(prefix + "Face", body, size, 0.04, (loc[0], loc[1] - depth * 0.5 - 0.02, loc[2]), m=face_m)
    return [back, front]


def frame_box(prefix, size, loc, bar, m):
    """Open rectangular frame (12 bars) of outer `size` centred on `loc`."""
    sx, sy, sz = size
    x, y, z = loc
    out = []
    for i, (dx, dy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        out.append(box(f"{prefix}V{i}", (bar, bar, sz), (x + dx * (sx - bar) / 2, y + dy * (sy - bar) / 2, z), bevel=0.01, m=m))
    for i, dz in enumerate((-1, 1)):
        zz = z + dz * (sz - bar) / 2
        for j, dy in enumerate((-1, 1)):
            out.append(box(f"{prefix}X{i}{j}", (sx, bar, bar), (x, y + dy * (sy - bar) / 2, zz), bevel=0.01, m=m))
        for j, dx in enumerate((-1, 1)):
            out.append(box(f"{prefix}Y{i}{j}", (bar, sy, bar), (x + dx * (sx - bar) / 2, y, zz), bevel=0.01, m=m))
    return out


def lattice(prefix, height, width, m, rod=0.05, steps=None):
    """Triangular lattice mast along +Z, base at the origin."""
    steps = steps or max(4, int(height / 0.9))
    out = []
    corners = [(math.cos(a) * width, math.sin(a) * width) for a in (math.pi / 2, math.pi / 2 + math.tau / 3, math.pi / 2 + 2 * math.tau / 3)]
    for i, (cx, cy) in enumerate(corners):
        out.append(cyl(f"{prefix}Leg{i}", rod, height, (cx, cy, height / 2), segs=6, bevel=0.0, m=m))
    for s in range(steps):
        z0 = height * s / steps
        z1 = height * (s + 1) / steps
        for i in range(3):
            a = corners[i]
            b = corners[(i + 1) % 3]
            p0 = (a[0], a[1], z0) if s % 2 == 0 else (b[0], b[1], z0)
            p1 = (b[0], b[1], z1) if s % 2 == 0 else (a[0], a[1], z1)
            out.append(tube(f"{prefix}Brace{s}_{i}", [p0, p1], rod * 0.6, m=m, segs=5, cap=False))
    return out
