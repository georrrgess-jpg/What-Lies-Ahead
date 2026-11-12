"""Weapon optics: the sights a player can fit to any weapon (Locker > Sights).

    art/models/sights.glb   one empty per optic, "Sight_<Name>". Its origin is
                            the centre of the underside of the base, which sits
                            on the weapon's SightMount; it points along +Y in
                            Blender (-Z, toward the muzzle, in Godot). Children:

        <Name>_Body   the housing. Materials: SightBody, SightAccent (tinted by
                      the sight item), SightSteel, SightGlow (takes the reticle
                      colour), SightGlassFront (objective glass of the scopes).
                      Every material culls back faces: the scopes have no inner
                      wall, so from behind the eye looks straight through them.
        <Name>_Lens   a quad across the window with UVs 0-1, its origin at the
                      lens centre and its local axis on the optic axis. Its
                      material "SightLens" is replaced in game by
                      art/shaders/sight_lens.gdshader (clear glass + reticle).
        <Name>_Eye    empty on the optic axis where the eye sits by default.

Optics: Reflex (open hoop), Holo (boxy hood), Tube (short tube), Prism
(chunky 2x) and Scope (long scope). scripts/weapons/sights/weapon_sights.gd
fits them to weapons; data/cosmetics/sights/*.tres are the items using them.

    python art/blender/build_sights.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import _finish


def sight_mats():
    m = dict(
        body=mat("SightBody", "#322a54", rough=0.42, metal=0.3),
        accent=mat("SightAccent", "#12b5a4", rough=0.36),
        steel=mat("SightSteel", "#8a86a3", rough=0.3, metal=0.75),
        glow=mat("SightGlow", "#ff4a5e", rough=0.3, emit=2.4),
        glass=mat("SightGlassFront", "#14365c", rough=0.08, metal=0.6),
        lens=mat("SightLens", "#9fe8ff", rough=0.1),
    )
    for material in m.values():
        material.use_backface_culling = True
    return m


def lens_quad(name, half_w, half_h, loc, m):
    """The window: a quad facing the eye (-Y) with UVs, origin at its centre."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    verts = [bm.verts.new((cu * half_w, 0.0, cv * half_h)) for cu, cv in corners]
    face = bm.faces.new(verts)
    for loop, (cu, cv) in zip(face.loops, corners):
        loop[uv].uv = ((cu + 1) * 0.5, (cv + 1) * 0.5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if face.normal.y > 0.0:
        face.normal_flip()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    export_collection().objects.link(ob)
    ob.location = loc
    return ob


def lathe(name, profile, axis_z, m, inner_rear, inner_front, segs=24, inner_wall=False, bevel=0.003):
    """A tube around the optic axis (along Y at height axis_z).

    profile: [(y, outer_radius), ...] from the rear (eye) end to the front.
    The ends are capped down to inner_rear / inner_front, leaving the bore
    open. Without inner_wall the tube is a shell seen from outside only.
    """
    bm = bmesh.new()

    def ring(y, r):
        return [bm.verts.new((math.cos(math.tau * j / segs) * r, y, axis_z + math.sin(math.tau * j / segs) * r))
                for j in range(segs)]

    rings = [ring(profile[0][0], inner_rear)] + [ring(y, r) for y, r in profile] + [ring(profile[-1][0], inner_front)]
    if inner_wall:
        rings.append(rings[0])
    for a, b in zip(rings[:-1], rings[1:]):
        for j in range(segs):
            k = (j + 1) % segs
            bm.faces.new((a[j], b[j], b[k], a[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish(name, bm, m, (0, 0, 0), (0, 0, 0))
    return add_bevel(ob, bevel, 2)


def front_glass(name, radius, y, axis_z, m, segs=20):
    """Objective glass: a disc that faces forward only (invisible to the eye behind it)."""
    bm = bmesh.new()
    verts = [bm.verts.new((math.cos(math.tau * j / segs) * radius, y, axis_z + math.sin(math.tau * j / segs) * radius))
             for j in range(segs)]
    face = bm.faces.new(verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if face.normal.y < 0.0:
        face.normal_flip()
    return _finish(name, bm, m, (0, 0, 0), (0, 0, 0), smooth=False)


def knob(prefix, loc, axis, m_body, m_cap, radius=0.011, height=0.014):
    """Adjustment turret: a ridged drum with a coloured cap. axis: "z" (top) or "x" (right side)."""
    x, y, z = loc
    rot = (0, 0, 0) if axis == "z" else rad(0, 90, 0)
    off = (0, 0, height * 0.5) if axis == "z" else (height * 0.5, 0, 0)
    tip = (0, 0, height) if axis == "z" else (height, 0, 0)
    return [
        cyl(prefix + "Drum", radius, height, (x + off[0], y + off[1], z + off[2]), rot=rot, segs=12, bevel=0.002, m=m_body),
        cyl(prefix + "Cap", radius * 0.72, 0.004, (x + tip[0], y + tip[1], z + tip[2]), rot=rot, segs=12, bevel=0.0015, m=m_cap),
    ]


def clamp_bolts(prefix, ys, width, z, m):
    return [cyl(f"{prefix}{i}", 0.0065, width, (0, y, z), rot=rad(0, 90, 0), segs=10, bevel=0.002, m=m)
            for i, y in enumerate(ys)]


def optic(name, body, lens_half, lens_loc, eye, m):
    """Bake one optic under its "Sight_<name>" empty."""
    root = empty("Sight_" + name, (0, 0, 0))
    out = [root, merge(name + "_Body", body, parent=root)]
    lens = lens_quad(name + "_Lens", lens_half[0], lens_half[1], lens_loc, m["lens"])
    lens.parent = root
    out.append(lens)
    out.append(empty(name + "_Eye", eye, parent=root))
    return out


def reflex(m):
    """Open reflex: a low base with a round-barred hoop around the window.

    The window stands at the rear of the base, so from the eye the rest of
    the optic hides behind its sill.
    """
    axis = 0.040
    y = -0.012
    hoop = [(-0.034, y, 0.012), (-0.034, y, 0.05)]
    hoop += [(-0.02 + math.cos(math.radians(a)) * 0.014, y, 0.05 + math.sin(math.radians(a)) * 0.014) for a in (150, 120, 90)]
    hoop += [(0.02 + math.cos(math.radians(a)) * 0.014, y, 0.05 + math.sin(math.radians(a)) * 0.014) for a in (90, 60, 30)]
    hoop += [(0.034, y, 0.05), (0.034, y, 0.012)]
    body = [
        box("ReflexBase", (0.052, 0.086, 0.016), (0, 0.008, 0.008), bevel=0.005, m=m["body"]),
        box("ReflexSill", (0.082, 0.024, 0.012), (0, y, 0.013), bevel=0.005, m=m["body"]),
        tube("ReflexHoop", hoop, 0.0068, m=m["body"], segs=10),
        box("ReflexBand", (0.055, 0.03, 0.006), (0, 0.026, 0.009), bevel=0.002, m=m["accent"]),
        box("ReflexEmitter", (0.026, 0.012, 0.006), (0, -0.029, 0.0175), bevel=0.002, m=m["body"]),
        sphere("ReflexEmitterGlow", 0.003, (0, -0.0225, 0.0185), m=m["glow"], segs=8, rings=5),
        sphere("ReflexCrownL", 0.005, (-0.02, y, 0.0645), m=m["accent"], segs=8, rings=5),
        sphere("ReflexCrownR", 0.005, (0.02, y, 0.0645), m=m["accent"], segs=8, rings=5),
    ]
    for side in (-1, 1):
        body.append(tube(f"ReflexBrace{side}", [(side * 0.034, y, 0.046), (side * 0.03, 0.042, 0.014)], 0.0042, m=m["steel"], segs=8))
    body += clamp_bolts("ReflexBolt", (0.0, 0.036), 0.062, 0.008, m["steel"])
    body += knob("ReflexDial", (0.026, 0.016, 0.012), "x", m["steel"], m["accent"], radius=0.006, height=0.008)
    return optic("Reflex", body, (0.029, 0.023), (0, y, axis), (0, -0.21, axis), m)


def holo(m):
    """Holographic sight: a boxy hood over a square window at the rear of a long base."""
    axis = 0.047
    y = -0.014
    body = [
        box("HoloBase", (0.058, 0.1, 0.022), (0, 0.008, 0.011), bevel=0.006, m=m["body"]),
        cyl("HoloBattery", 0.0105, 0.064, (0, 0.044, 0.0145), rot=rad(0, 90, 0), segs=12, bevel=0.003, m=m["steel"]),
        box("HoloRoof", (0.08, 0.052, 0.011), (0, y, 0.0735), bevel=0.004, m=m["body"]),
        box("HoloBrow", (0.05, 0.006, 0.005), (0, y - 0.0255, 0.0745), bevel=0.0015, m=m["accent"]),
        box("HoloButtonA", (0.012, 0.004, 0.007), (-0.012, -0.0425, 0.012), bevel=0.0015, m=m["glow"]),
        box("HoloButtonB", (0.012, 0.004, 0.007), (0.012, -0.0425, 0.012), bevel=0.0015, m=m["accent"]),
    ]
    for side in (-1, 1):
        body += [
            box(f"HoloWall{side}", (0.011, 0.052, 0.056), (side * 0.0345, y, 0.047), bevel=0.004, m=m["body"]),
            box(f"HoloPlate{side}", (0.004, 0.034, 0.026), (side * 0.041, y, 0.047), bevel=0.0015, m=m["accent"]),
            cyl(f"HoloScrew{side}", 0.004, 0.004, (side * 0.0435, y, 0.047), rot=rad(0, 90, 0), segs=8, bevel=0.001, m=m["steel"]),
        ]
    body += clamp_bolts("HoloBolt", (0.004, 0.03), 0.068, 0.009, m["steel"])
    return optic("Holo", body, (0.03, 0.022), (0, y, axis), (0, -0.21, axis), m)


def tube_dot(m):
    """Short tube sight: a stubby barrel on a clamp; the eye looks down its bore."""
    axis = 0.052
    profile = [(-0.036, 0.0335), (-0.024, 0.0335), (-0.02, 0.0305), (0.02, 0.0305), (0.024, 0.0335), (0.036, 0.0335)]
    body = [
        box("TubeBase", (0.042, 0.06, 0.018), (0, 0, 0.009), bevel=0.005, m=m["body"]),
        box("TubeSaddle", (0.03, 0.03, 0.012), (0, 0, 0.02), bevel=0.004, m=m["body"]),
        lathe("TubeBarrel", profile, axis, m["body"], 0.027, 0.027, segs=24, inner_wall=True),
        torus("TubeRingA", 0.0335, 0.0035, (0, -0.03, axis), rot=rad(90, 0, 0), m=m["accent"], major_segs=24, minor_segs=6),
        torus("TubeRingB", 0.0335, 0.0035, (0, 0.03, axis), rot=rad(90, 0, 0), m=m["accent"], major_segs=24, minor_segs=6),
    ]
    body += knob("TubeTop", (0, 0.002, axis + 0.029), "z", m["steel"], m["accent"], radius=0.009, height=0.011)
    body += knob("TubeSide", (0.029, 0.002, axis), "x", m["steel"], m["glow"], radius=0.009, height=0.011)
    body += clamp_bolts("TubeBolt", (-0.018, 0.018), 0.05, 0.009, m["steel"])
    return optic("Tube", body, (0.028, 0.028), (0, -0.01, axis), (0, -0.2, axis), m)


def prism_scope(m):
    """2x prism: a fat barrel with a flared eyepiece and objective, two turrets.

    The bore widens toward the front, so the far end frames most of the eyepiece.
    """
    axis = 0.06
    profile = [(-0.058, 0.037), (-0.034, 0.037), (-0.028, 0.034), (0.03, 0.036), (0.036, 0.041), (0.062, 0.041)]
    body = [
        box("PrismBase", (0.046, 0.086, 0.02), (0, 0, 0.01), bevel=0.005, m=m["body"]),
        box("PrismNeck", (0.032, 0.05, 0.014), (0, 0.002, 0.024), bevel=0.004, m=m["body"]),
        lathe("PrismBarrel", profile, axis, m["body"], 0.031, 0.036, segs=24, inner_wall=True),
        front_glass("PrismGlass", 0.0356, 0.056, axis, m["glass"]),
        torus("PrismEyeRing", 0.037, 0.004, (0, -0.046, axis), rot=rad(90, 0, 0), m=m["accent"], major_segs=24, minor_segs=6),
        torus("PrismNoseRing", 0.041, 0.0035, (0, 0.049, axis), rot=rad(90, 0, 0), m=m["steel"], major_segs=24, minor_segs=6),
        box("PrismBadge", (0.004, 0.026, 0.014), (-0.0345, 0.002, axis), bevel=0.0015, m=m["glow"]),
    ]
    body += knob("PrismTop", (0, 0.002, axis + 0.033), "z", m["steel"], m["accent"], radius=0.012, height=0.014)
    body += knob("PrismSide", (0.033, 0.002, axis), "x", m["steel"], m["accent"], radius=0.012, height=0.014)
    body += clamp_bolts("PrismBolt", (-0.024, 0.026), 0.054, 0.01, m["steel"])
    return optic("Prism", body, (0.032, 0.032), (0, -0.05, axis), (0, -0.22, axis), m)


def scope(m):
    """Long scope: slim tube in two rings, flared eyepiece, big objective bell."""
    axis = 0.05
    profile = [(-0.142, 0.031), (-0.09, 0.031), (-0.078, 0.021), (0.086, 0.021), (0.108, 0.034), (0.176, 0.034),
               (0.18, 0.0365), (0.192, 0.0365)]
    body = [
        box("ScopeRail", (0.03, 0.15, 0.012), (0, 0.004, 0.006), bevel=0.004, m=m["body"]),
        lathe("ScopeTube", profile, axis, m["body"], 0.0265, 0.031, segs=24),
        front_glass("ScopeGlass", 0.0315, 0.184, axis, m["glass"]),
        box("ScopeTurretBlock", (0.036, 0.032, 0.036), (0, 0.006, axis), bevel=0.008, m=m["body"]),
        torus("ScopeEyeRing", 0.031, 0.004, (0, -0.128, axis), rot=rad(90, 0, 0), m=m["accent"], major_segs=24, minor_segs=6),
        torus("ScopeBellRing", 0.034, 0.0035, (0, 0.12, axis), rot=rad(90, 0, 0), m=m["accent"], major_segs=24, minor_segs=6),
        torus("ScopeZoomRing", 0.0225, 0.004, (0, -0.07, axis), rot=rad(90, 0, 0), m=m["steel"], major_segs=20, minor_segs=6),
        box("ScopeBadge", (0.004, 0.03, 0.008), (-0.0215, 0.05, axis), bevel=0.0015, m=m["glow"]),
    ]
    for i, y in enumerate((-0.045, 0.058)):
        body += [
            box(f"ScopeMount{i}", (0.024, 0.02, 0.03), (0, y, 0.021), bevel=0.004, m=m["body"]),
            torus(f"ScopeRing{i}", 0.0225, 0.0055, (0, y, axis), rot=rad(90, 0, 0), m=m["steel"], major_segs=20, minor_segs=6),
            cyl(f"ScopeRingBolt{i}", 0.004, 0.012, (0.0225, y, axis + 0.017), rot=rad(0, 90, 0), segs=8, bevel=0.001, m=m["steel"]),
        ]
    body += knob("ScopeTop", (0, 0.006, axis + 0.018), "z", m["steel"], m["accent"], radius=0.0115, height=0.016)
    body += knob("ScopeSide", (0.018, 0.006, axis), "x", m["steel"], m["accent"], radius=0.0115, height=0.016)
    return optic("Scope", body, (0.0275, 0.0275), (0, -0.134, axis), (0, -0.32, axis), m)


def check_clear_axis(objects):
    """The middle of every window must be free of housing: no vertex inside 60% of the lens."""
    dg = bpy.context.evaluated_depsgraph_get()
    for ob in objects:
        if not ob.name.endswith("_Body") or ob.name == "Scope_Body":
            # The long scope is never looked through as a model: aimed, the game
            # shows its eyepiece view (see SightRig.scope_view).
            continue
        name = ob.name[:-5]
        lens = bpy.data.objects[name + "_Lens"]
        axis_z = lens.matrix_world.translation.z
        half_w = max(abs(v.co.x) for v in lens.data.vertices) * 0.6
        half_h = max(abs(v.co.z) for v in lens.data.vertices) * 0.6
        me = ob.evaluated_get(dg).to_mesh()
        inside = sum(1 for v in me.vertices if abs(v.co.x) < half_w and abs(v.co.z - axis_z) < half_h)
        ob.evaluated_get(dg).to_mesh_clear()
        print(f"[sights] {name}: {inside} housing vertices inside the window")
        assert inside == 0, name + " has geometry inside its window"


def build_sights():
    reset_scene()
    m = sight_mats()
    exports = []
    for build in (reflex, holo, tube_dot, prism_scope, scope):
        exports += build(m)
    bpy.context.view_layer.update()
    check_clear_axis(exports)
    save("sights", exports)


if __name__ == "__main__":
    build_sights()
