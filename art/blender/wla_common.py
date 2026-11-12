"""Shared modelling helpers for the What Lies Ahead asset scripts.

Every asset script in this folder builds chunky, bevelled, flat-coloured
models from code, then writes two files:

    art/blender/<name>.blend   editable source (parts keep live modifiers)
    art/models/<name>.glb      engine-ready export for Godot

Run a script with Blender's Python (4.2+ / 5.x):

    blender --background --python art/blender/build_props.py
    # or, with the `bpy` module from PyPI:
    python art/blender/build_props.py

Conventions
    * 1 unit = 1 metre, Z up in Blender (exported Y up).
    * Props sit on the ground with their origin at the centre of their base.
    * A prop's "front" faces -Y in Blender, which is +Z in Godot.
    * Weapons point along +Y in Blender, which is -Z (camera forward) in Godot.
    * Colours below are sRGB hex; they are converted to linear for Blender.
"""

import math
import os

import bpy  # must be imported before bmesh/mathutils when using the PyPI module
import bmesh
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.normpath(os.path.join(HERE, "..", "models"))

# Boardwalk Breakout palette (sunset pier: wood, teal rails, pink trim, amber bulbs).
PALETTE = {
    "Wood": "#8a4a36",
    "WoodDark": "#5c3128",
    "WoodLight": "#b06a48",
    "Teal": "#0e9f8e",
    "TealDark": "#0a6a60",
    "TealLight": "#3fcfb6",
    "Pink": "#ff3f9f",
    "PinkLight": "#ff86c4",
    "PinkDark": "#c41f74",
    "Magenta": "#e0218a",
    "Amber": "#ffb62e",
    "Yellow": "#ffd93b",
    "Orange": "#ff8a2a",
    "Cream": "#fff0d4",
    "White": "#f7f4f2",
    "Purple": "#6b35b8",
    "PurpleDark": "#3d1f73",
    "PurpleLight": "#9a6be0",
    "Dark": "#1c1830",
    "Grey": "#8f8c9c",
    "GreyLight": "#c9c6d2",
    "Red": "#e8263a",
    "Blue": "#3a7be0",
    "BlueLight": "#7fb4f5",
    "Green": "#3fa34a",
    "GreenLight": "#7ccf4f",
    "GreenDark": "#256b3a",
    "Brown": "#7a4a2c",
    "Sand": "#ecc08c",
    "Cyan": "#33f0ff",
}


# ---------------------------------------------------------------------------
# Scene / materials
# ---------------------------------------------------------------------------

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    return scene


def _srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgb(value):
    """'#rrggbb' (sRGB) -> linear (r, g, b)."""
    value = value.lstrip("#")
    return tuple(_srgb_to_linear(int(value[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def mat(name, color=None, rough=0.6, metal=0.0, emit=0.0, emit_color=None):
    """Get or create a flat-colour material. `color` is a palette key or hex."""
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    if color is None:
        color = PALETTE[name]
    elif color in PALETTE:
        color = PALETTE[color]
    rgb = hex_rgb(color)
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit > 0.0:
        e = hex_rgb(PALETTE.get(emit_color, emit_color)) if emit_color else rgb
        bsdf.inputs["Emission Color"].default_value = (*e, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = (*rgb, 1.0)
    return m


def glow(name, color=None, strength=2.5):
    """Emissive material for bulbs and energy parts."""
    return mat(name, color, rough=0.35, emit=strength)


# ---------------------------------------------------------------------------
# Object plumbing
# ---------------------------------------------------------------------------

def _finish(name, bm, material, loc, rot, smooth=True, collection=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    (collection or source_collection()).objects.link(ob)
    if material is not None:
        me.materials.append(material if not isinstance(material, str) else mat(material))
    ob.location = loc
    ob.rotation_euler = Euler(rot, "XYZ")
    return ob


def source_collection():
    name = "Source"
    if name not in bpy.data.collections:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
    return bpy.data.collections[name]


def export_collection():
    name = "Export"
    if name not in bpy.data.collections:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
    return bpy.data.collections[name]


def add_bevel(ob, width, segments=2, angle=35.0):
    """Soft toy-like edges: bevel + weighted normals, kept as live modifiers."""
    if width > 0.0:
        b = ob.modifiers.new("Bevel", "BEVEL")
        b.width = width
        b.segments = segments
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(angle)
    w = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    w.keep_sharp = True
    return ob


def place(parts, loc=(0, 0, 0), rot_z=0.0, scale=1.0):
    """Move a group of freshly built parts as one rigid piece (rotate about Z, then translate)."""
    m = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(rot_z, 4, "Z") @ Matrix.Scale(scale, 4)
    for ob in parts:
        ob.matrix_world = m @ ob.matrix_basis
    return parts


def rad(*degrees):
    return tuple(math.radians(d) for d in degrees)


# ---------------------------------------------------------------------------
# Primitives
# ---------------------------------------------------------------------------

def box(name, size, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.04, segs=2, m=None):
    """Rounded box. size = (x, y, z)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    ob = _finish(name, bm, m, loc, rot)
    return add_bevel(ob, min(bevel, min(size) * 0.45), segs)


def cyl(name, radius, height, loc=(0, 0, 0), rot=(0, 0, 0), segs=24, bevel=0.03, m=None, radius_top=None):
    """Cylinder / cone along Z, centred on loc."""
    bm = bmesh.new()
    r2 = radius if radius_top is None else radius_top
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs,
                          radius1=radius, radius2=max(r2, 0.0001), depth=height)
    ob = _finish(name, bm, m, loc, rot)
    return add_bevel(ob, min(bevel, radius * 0.45, height * 0.45), 2)


def sphere(name, radius, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), m=None, segs=16, rings=10):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    return _finish(name, bm, m, loc, rot)


def bulb(name, radius, loc, m=None):
    """Low-poly glowing bulb."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)
    return _finish(name, bm, m, loc, (0, 0, 0))


def torus(name, major, minor, loc=(0, 0, 0), rot=(0, 0, 0), m=None, major_segs=40, minor_segs=8,
          arc=math.tau, start=0.0):
    """Torus in the XY plane (axis Z). `arc` < tau makes an open arc with capped ends."""
    bm = bmesh.new()
    closed = abs(arc - math.tau) < 1e-6
    rings = []
    count = major_segs if closed else major_segs + 1
    for i in range(count):
        a = start + arc * i / major_segs
        centre = Vector((math.cos(a) * major, math.sin(a) * major, 0))
        out = Vector((math.cos(a), math.sin(a), 0))
        ring = []
        for j in range(minor_segs):
            b = math.tau * j / minor_segs
            ring.append(bm.verts.new(centre + out * math.cos(b) * minor + Vector((0, 0, math.sin(b) * minor))))
        rings.append(ring)
    n = len(rings)
    for i in range(n if closed else n - 1):
        r0, r1 = rings[i], rings[(i + 1) % n]
        for j in range(minor_segs):
            bm.faces.new((r0[j], r1[j], r1[(j + 1) % minor_segs], r0[(j + 1) % minor_segs]))
    if not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(name, bm, m, loc, rot)


def tube(name, points, radius, m=None, segs=10, radius_end=None, cap=True, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Round tube swept along a polyline (list of 3D points). Optional taper."""
    pts = [Vector(p) for p in points]
    bm = bmesh.new()
    rings = []
    # Parallel-transport frame so the tube never twists.
    tangent = (pts[1] - pts[0]).normalized()
    up = Vector((0, 0, 1)) if abs(tangent.z) < 0.9 else Vector((1, 0, 0))
    side = tangent.cross(up).normalized()
    up = side.cross(tangent).normalized()
    for i, p in enumerate(pts):
        if i == 0:
            t = (pts[1] - pts[0]).normalized()
        elif i == len(pts) - 1:
            t = (pts[-1] - pts[-2]).normalized()
        else:
            t = ((pts[i + 1] - p).normalized() + (p - pts[i - 1]).normalized()).normalized()
        side = (side - t * side.dot(t)).normalized()
        up = t.cross(side).normalized()
        f = i / (len(pts) - 1)
        r = radius if radius_end is None else radius + (radius_end - radius) * f
        ring = [bm.verts.new(p + (side * math.cos(math.tau * j / segs) + up * math.sin(math.tau * j / segs)) * r)
                for j in range(segs)]
        rings.append(ring)
    for i in range(len(rings) - 1):
        for j in range(segs):
            bm.faces.new((rings[i][j], rings[i + 1][j], rings[i + 1][(j + 1) % segs], rings[i][(j + 1) % segs]))
    if cap:
        bm.faces.new(rings[0])
        bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish(name, bm, m, loc, rot)
    return add_bevel(ob, 0.0)


def arc_points(radius, start_deg, end_deg, steps, centre=(0, 0, 0), plane="XZ"):
    """Points along a circular arc in the XZ (default), XY or YZ plane."""
    out = []
    for i in range(steps + 1):
        a = math.radians(start_deg + (end_deg - start_deg) * i / steps)
        u, v = math.cos(a) * radius, math.sin(a) * radius
        if plane == "XZ":
            out.append((centre[0] + u, centre[1], centre[2] + v))
        elif plane == "XY":
            out.append((centre[0] + u, centre[1] + v, centre[2]))
        else:
            out.append((centre[0], centre[1] + u, centre[2] + v))
    return out


def prism(name, outline, depth, loc=(0, 0, 0), rot=(0, 0, 0), m=None, bevel=0.0, segs=2):
    """Extrude a 2D outline (list of (x, z)) along Y by `depth`, centred on Y.

    The shape faces -Y (the front). Use `rot` to stand it elsewhere.
    """
    bm = bmesh.new()
    front = [bm.verts.new((x, -depth / 2.0, z)) for x, z in outline]
    back = [bm.verts.new((x, depth / 2.0, z)) for x, z in outline]
    n = len(outline)
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], back[i], back[j], front[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish(name, bm, m, loc, rot, smooth=bevel > 0.0)
    if bevel > 0.0:
        add_bevel(ob, bevel, segs)
    return ob


def star_outline(outer, inner=None, points=5, rotation=90.0):
    inner = outer * 0.5 if inner is None else inner
    out = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(rotation) + math.pi * i / points
        out.append((math.cos(a) * r, math.sin(a) * r))
    return out


def star(name, outer, depth, loc=(0, 0, 0), rot=(0, 0, 0), m=None, inner=None, bevel=0.0):
    return prism(name, star_outline(outer, inner), depth, loc, rot, m, bevel)


def disc(name, radius, loc=(0, 0, 0), m=None, inner=0.0, segs=64, thickness=0.02):
    """Flat ring or disc lying on the ground (for painted deck markings)."""
    bm = bmesh.new()
    top, bot = [], []
    for i in range(segs):
        a = math.tau * i / segs
        c, s = math.cos(a), math.sin(a)
        top.append((bm.verts.new((c * radius, s * radius, thickness)),
                    bm.verts.new((c * inner, s * inner, thickness)) if inner > 0 else None))
    if inner > 0:
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((top[i][0], top[j][0], top[j][1], top[i][1]))
    else:
        bm.faces.new([t[0] for t in top])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(name, bm, m, loc, (0, 0, 0), smooth=False)


def text(name, body, size, depth, loc=(0, 0, 0), rot=(0, 0, 0), m=None, align="CENTER"):
    """Extruded sign lettering, converted to a mesh. Faces -Y by default."""
    curve = bpy.data.curves.new(name + "_curve", "FONT")
    curve.body = body
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
    # Text is authored in XY; stand it upright facing -Y.
    ob.rotation_euler = Euler((math.radians(90) + rot[0], rot[1], rot[2]), "XYZ")
    ob.location = loc
    return ob


def bulb_row(prefix, start, end, count, radius, m):
    """Evenly spaced bulbs between two points (inclusive)."""
    a, b = Vector(start), Vector(end)
    out = []
    for i in range(count):
        t = i / max(1, count - 1)
        out.append(bulb(f"{prefix}{i:02d}", radius, a.lerp(b, t), m))
    return out


def bulb_ring(prefix, radius, count, z, bulb_radius, m, centre=(0, 0), plane="XY", phase=0.0):
    out = []
    for i in range(count):
        a = phase + math.tau * i / count
        if plane == "XY":
            p = (centre[0] + math.cos(a) * radius, centre[1] + math.sin(a) * radius, z)
        else:  # XZ plane, z argument is the Y depth
            p = (centre[0] + math.cos(a) * radius, z, centre[1] + math.sin(a) * radius)
        out.append(bulb(f"{prefix}{i:02d}", bulb_radius, p, m))
    return out


# ---------------------------------------------------------------------------
# Baking / export
# ---------------------------------------------------------------------------

def merge(name, objects, pivot=(0, 0, 0), parent=None):
    """Bake modifiers and join `objects` into one export mesh whose origin is `pivot`.

    The source parts are left untouched in the Source collection.
    """
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    target_mesh = bpy.data.meshes.new(name)
    target = bpy.data.objects.new(name, target_mesh)
    export_collection().objects.link(target)
    target.location = pivot
    temps = []
    for ob in objects:
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        tmp = bpy.data.objects.new(ob.name + "_bake", me)
        export_collection().objects.link(tmp)
        tmp.matrix_world = ob.matrix_world.copy()
        temps.append(tmp)
    bpy.context.view_layer.update()
    if temps:
        with bpy.context.temp_override(active_object=target, object=target,
                                       selected_objects=[target] + temps,
                                       selected_editable_objects=[target] + temps):
            bpy.ops.object.join()
    for p in target.data.polygons:
        p.use_smooth = True
    if parent is not None:
        target.parent = parent
        target.matrix_parent_inverse = parent.matrix_world.inverted()
    return target


def empty(name, loc=(0, 0, 0), parent=None, rot=(0, 0, 0)):
    ob = bpy.data.objects.new(name, None)
    export_collection().objects.link(ob)
    ob.empty_display_size = 0.1
    ob.location = loc
    ob.rotation_euler = Euler(rot, "XYZ")
    if parent is not None:
        bpy.context.view_layer.update()
        ob.parent = parent
        ob.matrix_parent_inverse = parent.matrix_world.inverted()
    return ob


def save(name, export_objects, animations=False):
    """Write art/blender/<name>.blend and art/models/<name>.glb."""
    os.makedirs(MODELS_DIR, exist_ok=True)
    bpy.context.view_layer.update()
    blend_path = os.path.join(HERE, name + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path, compress=True)
    for ob in bpy.context.scene.objects:
        ob.select_set(False)
    for ob in export_objects:
        ob.select_set(True)
    glb_path = os.path.join(MODELS_DIR, name + ".glb")
    kwargs = dict(
        filepath=glb_path,
        export_format="GLB",
        use_selection=True,
        export_apply=not animations,
        export_yup=True,
        export_materials="EXPORT",
        export_tangents=False,
        export_animations=animations,
    )
    if animations:
        kwargs.update(export_animation_mode="ACTIONS", export_skins=True,
                      export_force_sampling=True, export_optimize_animation_size=False)
    bpy.ops.export_scene.gltf(**kwargs)
    tris = sum(len(o.data.polygons) for o in export_objects if o.type == "MESH")
    print(f"[wla] {name}: {len(export_objects)} export objects, ~{tris} faces -> {os.path.relpath(glb_path)}")
    return glb_path
