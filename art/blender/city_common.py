"""Modelling kit for Ashfall City, the Endless map (shared by build_city_*.py).

Re-exports the primitives of wla_common / dune_kit (box, cyl, tube, prism, beam,
fbox, text, merge, save, ...) and adds the burnt-out city: an ash-and-ember
palette with saturated accents (hazard yellow, taxi yellow, police red/blue,
neon pink/cyan/lime), jagged broken walls and slabs, rebar, soot and scorch
patches, glass shards, graffiti, tyres and rims.

Conventions are those of wla_common: metres, Z up, a prop's front faces -Y
(Godot +Z), origin at the centre of the base.

Material names are a contract with scripts/props/city_post_import.gd, which
every city_*.glb runs on import:

    City<Key>          plain palette colour; gets the shared grime texture
                       (soot, stains, chips) projected in object space
    CityBrick*         the brick texture, tinted by the colour
    CityConcrete*      the concrete texture, tinted by the colour
    CityNeon_<hex>     neon tube: emissive, flickers (per object, in the shader)
    CityHalo_<hex>     crossed halo quads -> additive glow in that colour
    CityEmber          smouldering embers (pulsing glow)
    CityPoliceRed/Blue police light bar halves (alternating strobe)
    CityFire           fire glow inside wrecks (bright flicker)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dune_kit import *  # noqa: F401,F403
from dune_kit import _finish, make_flat, fbox, beam, rod  # noqa: F401
from wla_common import HALO_SCALE, MODELS_DIR, HERE  # noqa: F401
import bmesh
import bpy
from mathutils import Matrix, Vector

# Ashfall City: ash greys and soot, rust and char, with toy-bright accents that survived.
CITY = {
    "Concrete": "#8a837c",
    "ConcreteDark": "#5a5450",
    "ConcreteLight": "#b3aca2",
    "ConcreteWarm": "#9c8a78",
    "Brick": "#9a4432",
    "BrickDark": "#6a2c24",
    "Plaster": "#c7b49a",
    "PlasterTeal": "#4f8f8a",
    "PlasterPink": "#c46a72",
    "Soot": "#1d1a1d",
    "Char": "#2b2426",
    "CharLight": "#4a3e3c",
    "Rust": "#9a4a26",
    "RustDark": "#5e2c1a",
    "RustLight": "#c4703a",
    "Steel": "#7c818c",
    "SteelDark": "#3c3f48",
    "SteelLight": "#a9aeb8",
    "Asphalt": "#3a3638",
    "Rubber": "#232023",
    "Interior": "#151216",
    "Glass": "#5aa6b8",
    "GlassDark": "#24404c",
    "Wood": "#8a5e3a",
    "WoodDark": "#5a3a26",
    "WoodLight": "#b48552",
    "Hazard": "#ffc21f",
    "HazardDark": "#26222a",
    "Taxi": "#ffb81c",
    "PoliceBlue": "#2a4fb8",
    "PoliceNavy": "#1c2a5a",
    "White": "#e9e4dc",
    "Red": "#d8323a",
    "RedDark": "#8e2026",
    "Orange": "#f06a24",
    "Teal": "#1fa59a",
    "Blue": "#3a6fd0",
    "Green": "#3c8a4a",
    "GreenDark": "#245a34",
    "Violet": "#6a3aa8",
    "Pink": "#e8478a",
    "Tarp": "#2f78c4",
    "Canvas": "#d9c49a",
    "Cream": "#f1e6cf",
    "Bronze": "#7a6a3e",
    "BronzeGreen": "#4f8a72",
    "Gold": "#e0a83a",
}

NEON_PINK = "#ff2fae"
NEON_CYAN = "#2ef2ff"
NEON_LIME = "#b6ff3a"
NEON_AMBER = "#ffb43a"
NEON_RED = "#ff3a4a"
NEON_VIOLET = "#a066ff"
LAMP_WARM = "#ffc46a"
LAMP_EMERGENCY = "#ff4a2a"


def cm(key, rough=0.8, metal=0.0):
    """Palette material 'City<key>' (gets the grime texture on import)."""
    return mat("City" + key, CITY[key], rough=rough, metal=metal)


def neon(color, strength=3.2):
    """Neon tube in `color` (hex); flickers in game."""
    return mat("CityNeon_" + color.lstrip("#"), color, rough=0.3, emit=strength)


def steady(color, strength=3.0):
    """A steady emissive light surface (lamps, lit windows): no flicker, no grime."""
    return mat("CityLit_" + color.lstrip("#"), color, rough=0.35, emit=strength)


def halo_m(color):
    return mat("CityHalo_" + color.lstrip("#"), color, rough=1.0)


def ember_m():
    return mat("CityEmber", "#ff5a1a", rough=0.6, emit=3.0)


def fire_m():
    return mat("CityFire", "#ffa53a", rough=0.5, emit=4.0)


def police_m(side):
    return mat("CityPolice" + side, "#ff2f3f" if side == "Red" else "#2f6bff", rough=0.3, emit=4.0)


def lamp(name, radius, loc, color, strength=3.0, halo=True, lit=None, halo_scale=HALO_SCALE):
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
    ob = _finish(name, bm, lit or steady(color, strength), loc, (0, 0, 0), smooth=True)
    if halo:
        ob.data.materials.append(halo_m(color))
    return ob


# ---------------------------------------------------------------------------
# Shapes
# ---------------------------------------------------------------------------

def slab(name, outline, z0, z1, m=None, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Extrude an XY outline (list of (x, y), counter-clockwise) from z0 to z1. Flat shaded."""
    bm = bmesh.new()
    bot = [bm.verts.new((x, y, z0)) for x, y in outline]
    top = [bm.verts.new((x, y, z1)) for x, y in outline]
    n = len(outline)
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return make_flat(_finish(name, bm, m, loc, rot, smooth=False))


def flat_prism(name, outline, depth, loc=(0, 0, 0), rot=(0, 0, 0), m=None):
    """prism() with crisp flat shading (outline in XZ, faces -Y)."""
    return make_flat(prism(name, outline, depth, loc, rot, m=m))


def jagged(rng, x0, x1, base, amp, steps):
    """Points (x, z) along a broken edge from x0 to x1 around height `base`."""
    pts = []
    for i in range(steps + 1):
        t = i / steps
        dz = 0.0 if i in (0, steps) else rng.uniform(-amp, amp * 0.35)
        pts.append((x0 + (x1 - x0) * t + (rng.uniform(-0.15, 0.15) * (x1 - x0) / steps if 0 < i < steps else 0.0), base + dz))
    return pts


def broken_wall(name, width, height, thick, m, seed=1, amp=0.9, steps=7, loc=(0, 0, 0), rot_z=0.0, left_h=None, right_h=None):
    """A wall slab facing -Y whose top edge is broken; base on z = 0, centred on x."""
    rng = random.Random(seed)
    lh = height if left_h is None else left_h
    rh = height if right_h is None else right_h
    top = []
    for i in range(steps + 1):
        t = i / steps
        base = lh + (rh - lh) * t
        dz = 0.0 if i in (0, steps) else rng.uniform(-amp, amp * 0.3)
        top.append((-width / 2 + width * t, base + dz))
    outline = [(-width / 2, 0.0), (width / 2, 0.0)] + list(reversed(top))
    ob = flat_prism(name, outline, thick, (0, 0, 0), m=m)
    place([ob], loc, rot_z)
    return ob


def broken_slab(name, w, d, thick, z, m, seed=1, side="-Y", amp=0.8, steps=6, loc=(0, 0, 0)):
    """A floor slab (w x d, top at z) with one broken, jagged edge on `side`."""
    rng = random.Random(seed)
    hw, hd = w / 2, d / 2
    edge = []
    for i in range(1, steps):
        t = i / steps
        edge.append((-hw + w * t, -hd + rng.uniform(0.0, amp)))
    if side == "-Y":
        outline = [(-hw, -hd)] + edge + [(hw, -hd), (hw, hd), (-hw, hd)]
    else:  # broken on +X
        edge = [(hw - rng.uniform(0.0, amp), -hd + d * i / steps) for i in range(1, steps)]
        outline = [(-hw, -hd), (hw, -hd)] + edge + [(hw, hd), (-hw, hd)]
    return slab(name, outline, z - thick, z, m=m, loc=loc)


def rebar(prefix, base, direction, length, count, spread, seed=1, m=None, radius=0.025):
    """A tuft of bent reinforcing bars sticking out of a broken edge.
    `spread` is the vector between neighbouring bars."""
    m = m or cm("Rust", rough=0.7, metal=0.4)
    rng = random.Random(seed)
    b, d, s = Vector(base), Vector(direction).normalized(), Vector(spread)
    out = []
    for i in range(count):
        p0 = b + s * (i - (count - 1) / 2)
        L = length * rng.uniform(0.55, 1.1)
        bend = Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(-0.45, 0.1))) * L
        p1 = p0 + d * L * 0.55
        p2 = p0 + d * L + bend
        out.append(tube(f"{prefix}{i}", [p0, p1, p2], radius, m=m, segs=4, cap=False))
    return out


def blob(name, radius, loc, m, seed=1, rot=(0, 0, 0), sides=9, squash=(1.0, 1.0), depth=0.012):
    """A thin jittered disc facing -Y (soot stain, scorch, spray patch) centred on loc."""
    rng = random.Random(seed)
    pts = []
    for i in range(sides):
        a = math.tau * i / sides
        r = radius * rng.uniform(0.6, 1.15)
        pts.append((math.cos(a) * r * squash[0], math.sin(a) * r * squash[1]))
    return flat_prism(name, pts, depth, loc, rot, m=m)


def ground_blob(name, radius, loc, m, seed=1, sides=10, squash=(1.0, 1.0)):
    """A scorch / ash patch lying on the ground (top at loc z + 0.015)."""
    rng = random.Random(seed)
    pts = []
    for i in range(sides):
        a = math.tau * i / sides
        r = radius * rng.uniform(0.65, 1.12)
        pts.append((math.cos(a) * r * squash[0], math.sin(a) * r * squash[1]))
    return slab(name, pts, 0.0, 0.015, m=m, loc=loc)


def shards(prefix, w, h, loc, m=None, seed=1, rot_z=0.0):
    """Cracked glass left in a window frame of w x h (facing -Y): triangles from the corners."""
    m = m or cm("Glass", rough=0.15, metal=0.3)
    rng = random.Random(seed)
    out = []
    corners = [(-w / 2, -h / 2, 1, 1), (w / 2, -h / 2, -1, 1), (w / 2, h / 2, -1, -1), (-w / 2, h / 2, 1, -1)]
    for k, (cx, cz, sx, sz) in enumerate(corners):
        if rng.random() < 0.35:
            continue
        a = rng.uniform(0.25, 0.7) * w
        b = rng.uniform(0.25, 0.8) * h
        out.append(flat_prism(f"{prefix}{k}", [(cx, cz), (cx + sx * a, cz), (cx, cz + sz * b)], 0.02, m=m))
    return place(out, loc, rot_z)


def graffiti(prefix, body, size, loc, color, rot_z=0.0, outline="#1d1a1d", depth=0.02):
    """Spray-painted lettering facing -Y with a dark outline behind it."""
    face = mat("CityPaint_" + color.lstrip("#"), color, rough=0.6)
    back = mat("CityPaint_" + outline.lstrip("#"), outline, rough=0.6)
    a = text(prefix + "Ink", body, size, depth, (0, -depth * 0.6, 0), m=face)
    b = text(prefix + "Rim", body, size * 1.08, depth * 0.5, (0, 0, -size * 0.03), m=back)
    return place([a, b], loc, rot_z)


def tyre(name, radius, width, loc, rot=(0, 0, math.pi / 2), m=None, segs=12):
    m = m or cm("Rubber", rough=0.95)
    return torus(name, radius - width * 0.3, width * 0.42, loc, rot=(math.pi / 2, 0, rot[2]), m=m, major_segs=segs, minor_segs=4)


def rim(name, radius, width, loc, rot_z=0.0, m=None, segs=10):
    """A bare steel wheel rim (the tyre burnt away), axle along X after rot_z."""
    m = m or cm("SteelDark", rough=0.5, metal=0.6)
    return make_flat(cyl(name, radius, width, loc, rot=(0, math.pi / 2, rot_z), segs=segs, bevel=0.0, m=m))


def hazard(prefix, length, height, loc=(0, 0, 0), rot_z=0.0, depth=0.04, stripe=0.45, slant=0.5):
    return hazard_band(prefix, length, height, loc, rot_z, depth=depth, stripe=stripe,
                       yellow=cm("Hazard", rough=0.6), black=cm("HazardDark", rough=0.6), slant=slant)


def tris_of(objects):
    return sum(len(p.vertices) - 2 for o in objects if o.type == "MESH" for p in o.data.polygons)


def csave(name, export_objects, budget=3000):
    """save() plus a triangle count against the kit budget."""
    path = save(name, export_objects)
    n = tris_of(export_objects)
    flag = "" if n <= budget else f"  OVER BUDGET ({budget})"
    print(f"[city] {name}: {n} tris{flag}")
    return path


def csave_split(blend_name, groups, budget=3000):
    """One .blend, one .glb per group (gate frames and doors)."""
    save_split(blend_name, groups)
    for name, objects in groups.items():
        n = tris_of(objects)
        flag = "" if n <= budget else f"  OVER BUDGET ({budget})"
        print(f"[city] {name}: {n} tris{flag}")


def run(builders):
    """Command line: build every prop, or only those named."""
    wanted = sys.argv[1:] or list(builders)
    for key in wanted:
        builders[key]()


def xform(parts, loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0):
    """Move a group of parts as one rigid piece: scale, rotate (XYZ Euler, radians), translate."""
    from mathutils import Euler
    m = Matrix.Translation(Vector(loc)) @ Euler(rot, "XYZ").to_matrix().to_4x4() @ Matrix.Scale(scale, 4)
    for ob in parts:
        ob.matrix_world = m @ ob.matrix_basis
    return parts


def socket(name, loc, parent=None):
    """An empty exported with the model: the map puts fire / sparks / lights there."""
    return empty(name, loc, parent=parent)


FONT_PATH = os.path.normpath(os.path.join(HERE, "..", "fonts", "LilitaOne-Regular.ttf"))


def text(name, body, size, depth, loc=(0, 0, 0), rot=(0, 0, 0), m=None, align="CENTER"):
    """Extruded lettering in the game's display font (Lilita One), low resolution
    to keep signs cheap. Faces -Y by default, like wla_common.text()."""
    from mathutils import Euler
    curve = bpy.data.curves.new(name + "_curve", "FONT")
    curve.body = body
    if os.path.exists(FONT_PATH):
        curve.font = bpy.data.fonts.load(FONT_PATH, check_existing=True)
    curve.size = size
    curve.extrude = depth / 2.0
    curve.align_x = align
    curve.align_y = "CENTER"
    curve.resolution_u = 1
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
