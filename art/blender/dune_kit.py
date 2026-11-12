"""Modelling kit for World 4, Dune Spaceport (shared by the build_dune_*.py scripts).

Re-exports the primitives of wla_common (box, cyl, sphere, tube, prism, text,
bulb, merge, save, ...) and adds what a retro-futurist desert spaceport needs:
a sand / rust / white-and-teal palette, beams between two points (lattice
towers, trusses), lathed surfaces of revolution (rocket hulls, tanks, dishes),
hazard-stripe bands and corrugated panels.

Conventions are those of wla_common: metres, Z up, a prop's front faces -Y
(Godot +Z), origin at the centre of the base.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import _finish  # noqa: F401
import bmesh
from mathutils import Matrix, Vector

# Golden-hour spaceport: sand and rust, white and teal spacecraft panels, hazard stripes.
DUNE = {
    "Sand": "#e2b27a",
    "SandDark": "#c08652",
    "SandLight": "#f2d2a2",
    "Rust": "#d0582c",
    "RustDark": "#8f3a22",
    "RustLight": "#f07e48",
    "Hull": "#f3efe6",
    "HullShade": "#d9d3c6",
    "Teal": "#21a89f",
    "TealDark": "#156f6c",
    "TealLight": "#73dccf",
    "Hazard": "#ffc21f",
    "HazardDark": "#2b2530",
    "Concrete": "#bfae96",
    "ConcreteDark": "#8c7d6a",
    "ConcreteLight": "#d9cab2",
    "Steel": "#7f8a96",
    "SteelDark": "#454d5a",
    "SteelLight": "#b9c2cb",
    "Navy": "#283a63",
    "Red": "#e2402e",
    "Copper": "#c77b3a",
    "Rubber": "#2a2629",
    "Glass": "#8fdcec",
    "Window": "#ffd486",
    "Interior": "#2a2230",
}


def dmat(name, color=None, rough=0.6, metal=0.0, emit=0.0, emit_color=None):
    """Material from the Dune palette (key) or a hex colour. Names are shared per file."""
    key = color if color is not None else name
    hex_value = DUNE.get(key, key)
    return mat(name, hex_value, rough=rough, metal=metal, emit=emit, emit_color=emit_color)


def dglow(name, color, strength=2.5):
    return dmat(name, color, rough=0.35, emit=strength)


def make_flat(ob):
    """Marks every edge sharp, so an unbevelled part keeps crisp flat shading."""
    for e in ob.data.edges:
        e.use_edge_sharp = True
    return ob


def fbox(name, size, loc=(0, 0, 0), rot=(0, 0, 0), m=None):
    """Unbevelled flat-shaded box (thin trims, lattice members, decals)."""
    return make_flat(box(name, size, loc, rot, bevel=0.0, m=m))


def beam(name, p0, p1, width, depth=None, m=None, bevel=0.0, roll=0.0):
    """Box beam running from p0 to p1 (lattice members, struts, girders)."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    length = d.length
    depth = width if depth is None else depth
    ob = box(name, (width, depth, length), (0, 0, 0), bevel=bevel, m=m)
    if bevel <= 0.0:
        make_flat(ob)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = q @ Matrix.Rotation(roll, 4, "Z").to_quaternion()
    ob.location = (a + b) * 0.5
    return ob


def rod(name, p0, p1, radius, m=None, segs=8):
    """Round strut between two points."""
    return tube(name, [p0, p1], radius, m=m, segs=segs)


def lathe(name, profile, m=None, segs=32, loc=(0, 0, 0), rot=(0, 0, 0), sharp=35.0, cap=True):
    """Surface of revolution about Z from a (radius, z) profile listed bottom to top.

    Corners sharper than `sharp` degrees get split normals; a radius of 0 at an
    end closes it with a point, otherwise `cap` closes it with a flat disc.
    """
    bm = bmesh.new()
    pts = [Vector((r, 0, z)) for r, z in profile]
    # Split the profile at sharp corners so each run shades smoothly on its own.
    runs, run = [], [pts[0]]
    for i in range(1, len(pts)):
        run.append(pts[i])
        if 0 < i < len(pts) - 1:
            a = (pts[i] - pts[i - 1]).normalized()
            b = (pts[i + 1] - pts[i]).normalized()
            if math.degrees(a.angle(b, 0.0)) > sharp:
                runs.append(run)
                run = [pts[i]]
    runs.append(run)
    for run in runs:
        rings = []
        for p in run:
            ring = []
            for j in range(segs):
                ang = math.tau * j / segs
                ring.append(bm.verts.new((math.cos(ang) * p.x, math.sin(ang) * p.x, p.z)))
            rings.append(ring)
        for i in range(len(rings) - 1):
            for j in range(segs):
                k = (j + 1) % segs
                quad = (rings[i][j], rings[i][k], rings[i + 1][k], rings[i + 1][j])
                try:
                    bm.faces.new(quad)
                except ValueError:
                    pass
    if cap:
        for p, top in ((pts[0], False), (pts[-1], True)):
            if p.x > 1e-4:
                ring = [bm.verts.new((math.cos(math.tau * j / segs) * p.x, math.sin(math.tau * j / segs) * p.x, p.z))
                        for j in range(segs)]
                bm.faces.new(ring if top else list(reversed(ring)))
    bmesh.ops.remove_doubles(bm, verts=[v for v in bm.verts if v.co.xy.length < 1e-4], dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish(name, bm, m, loc, rot, smooth=True)
    return ob


def hazard_band(prefix, length, height, loc=(0, 0, 0), rot_z=0.0, depth=0.04, stripe=0.5,
                yellow=None, black=None, slant=0.5):
    """Flat panel of diagonal yellow/black stripes, facing -Y, centred on loc."""
    yellow = yellow or dmat("Hazard")
    black = black or dmat("HazardDark")
    parts = [fbox(prefix + "Back", (length, depth, height), (0, 0, 0), m=black)]
    n = int(length / stripe) + 2
    sl = height * slant
    x0 = -length / 2
    for i in range(n):
        if i % 2:
            continue
        a = x0 + i * stripe
        outline = [(a, -height / 2), (a + stripe, -height / 2), (a + stripe + sl, height / 2), (a + sl, height / 2)]
        clipped = [(min(max(x, -length / 2), length / 2), z) for x, z in outline]
        if abs(clipped[1][0] - clipped[0][0]) < 1e-3 and abs(clipped[2][0] - clipped[3][0]) < 1e-3:
            continue
        parts.append(make_flat(prism(f"{prefix}S{i:02d}", clipped, depth * 0.6, (0, -depth * 0.45, 0), m=yellow)))
    return place(parts, loc, rot_z)


def hazard_ring(prefix, radius, z, height, count=16, yellow=None, black=None, segs=48, thick=0.04):
    """Alternating yellow/black blocks wrapped around a cylinder."""
    yellow = yellow or dmat("Hazard")
    black = black or dmat("HazardDark")
    parts = [cyl(prefix + "Base", radius, height, (0, 0, z), segs=segs, bevel=0.0, m=black)]
    seg_len = math.tau * (radius + thick) / count
    for i in range(0, count, 2):
        a = math.tau * (i + 0.5) / count
        b = box(f"{prefix}Y{i:02d}", (seg_len * 0.98, thick * 2, height * 1.01), (0, -(radius + thick * 0.2), 0),
                bevel=0.0, m=yellow)
        make_flat(b)
        parts += place([b], (0, 0, z), rot_z=a + math.pi / 2)
    return parts


def corrugated(prefix, width, height, loc=(0, 0, 0), rot_z=0.0, pitch=0.3, depth=0.06, m=None, m_rib=None):
    """Corrugated wall panel facing -Y: a flat sheet with raised vertical ribs."""
    m_rib = m_rib or m
    parts = [box(prefix + "Sheet", (width, depth, height), (0, 0, height / 2), bevel=0.0, m=m)]
    n = int(width / pitch)
    for i in range(n):
        x = -width / 2 + pitch * (i + 0.5)
        parts.append(box(f"{prefix}Rib{i:03d}", (pitch * 0.42, depth * 1.6, height), (x, -depth * 0.6, height / 2),
                         bevel=pitch * 0.12, segs=1, m=m_rib))
    return place(parts, loc, rot_z)


def ring_of(prefix, maker, count, radius, z=0.0, phase=0.0):
    """Calls maker(name) -> [parts] built at +X and rotates copies around Z."""
    out = []
    for i in range(count):
        a = phase + math.tau * i / count
        parts = maker(f"{prefix}{i:02d}")
        for ob in parts:
            ob.matrix_world = Matrix.Rotation(a, 4, "Z") @ Matrix.Translation((radius, 0, z)) @ ob.matrix_basis
        out += parts
    return out


def window_strip(prefix, count, spacing, size, loc, rot_z=0.0, m_frame=None, m_glass=None):
    """A row of framed windows facing -Y."""
    parts = []
    w, h = size
    for i in range(count):
        x = (i - (count - 1) / 2) * spacing
        parts.append(box(f"{prefix}Frame{i:02d}", (w + 0.16, 0.12, h + 0.16), (x, 0, 0), bevel=0.04, m=m_frame))
        parts.append(fbox(f"{prefix}Glass{i:02d}", (w, 0.08, h), (x, -0.05, 0), m=m_glass))
    return place(parts, loc, rot_z)


def save_split(blend_name, groups):
    """Writes art/blender/<blend_name>.blend once and one art/models/<name>.glb per
    group ({glb name: [export objects]}), for parts the level places independently."""
    os.makedirs(MODELS_DIR, exist_ok=True)
    bpy.context.view_layer.update()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, blend_name + ".blend"), compress=True)
    for name, objects in groups.items():
        for ob in bpy.context.scene.objects:
            ob.select_set(False)
        for ob in objects:
            ob.select_set(True)
        path = os.path.join(MODELS_DIR, name + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                                  export_yup=True, export_materials="EXPORT", export_tangents=False, export_animations=False)
        tris = sum(len(o.data.polygons) for o in objects if o.type == "MESH")
        print(f"[wla] {name}: {len(objects)} export objects, ~{tris} faces -> {os.path.relpath(path)}")
