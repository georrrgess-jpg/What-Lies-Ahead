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
(chunky 2x), Scope (long scope), Periscope (tube with a periscope head), Gem
(crystal crown), Gallery (bulb-ringed hoop), Eye (eyeball), Hex (hexagonal
hood), Brass (vintage 1.4x), Burst (star bezel), Ranger (twin-window box),
Frost (iced tube) and Porthole (bolted brass ring). scripts/weapons/sights/weapon_sights.gd
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
        body=mat("SightBody", "#3a3162", rough=0.42, metal=0.3),
        accent=mat("SightAccent", "#12b5a4", rough=0.36),
        steel=mat("SightSteel", "#8a86a3", rough=0.3, metal=0.75),
        glow=mat("SightGlow", "#ff4a5e", rough=0.3, emit=2.4),
        glass=mat("SightGlassFront", "#14365c", rough=0.08, metal=0.6),
        lens=mat("SightLens", "#9fe8ff", rough=0.1),
        white=mat("SightWhite", "#f4f1ea", rough=0.35),
        vein=mat("SightVein", "#e8263a", rough=0.4),
        brass=mat("SightBrass", "#d4a03a", rough=0.28, metal=0.85),
        ice=mat("SightIce", "#bfefff", rough=0.15, metal=0.1),
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
        tube("ReflexHoop", hoop, 0.0058, m=m["accent"], segs=10),
        box("ReflexFootL", (0.016, 0.02, 0.012), (-0.034, y, 0.02), bevel=0.004, m=m["body"]),
        box("ReflexFootR", (0.016, 0.02, 0.012), (0.034, y, 0.02), bevel=0.004, m=m["body"]),
        box("ReflexBand", (0.055, 0.03, 0.006), (0, 0.026, 0.009), bevel=0.002, m=m["accent"]),
        box("ReflexEmitter", (0.026, 0.012, 0.006), (0, -0.029, 0.0175), bevel=0.002, m=m["body"]),
        sphere("ReflexEmitterGlow", 0.003, (0, -0.0225, 0.0185), m=m["glow"], segs=8, rings=5),
        sphere("ReflexCrownL", 0.0048, (-0.02, y, 0.0645), m=m["steel"], segs=8, rings=5),
        sphere("ReflexCrownR", 0.0048, (0.02, y, 0.0645), m=m["steel"], segs=8, rings=5),
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
            box(f"HoloTrim{side}", (0.0045, 0.005, 0.04), (side * 0.0345, y - 0.0255, 0.047), bevel=0.0015, m=m["accent"]),
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


# --- update 4 optics --------------------------------------------------------

def radial_spikes(prefix, count, axis, y, r0, lengths, width, depth, mats, phase=0.0):
    """Flat triangular spikes round the window (a star bezel or crystal crown)."""
    out = []
    for i in range(count):
        a = phase + math.tau * i / count
        length = lengths[i % len(lengths)]
        d = (math.cos(a), math.sin(a))
        n = (-d[1], d[0])
        pts = [(d[0] * r0 + n[0] * width, axis + d[1] * r0 + n[1] * width), (d[0] * (r0 + length), axis + d[1] * (r0 + length)),
               (d[0] * r0 - n[0] * width, axis + d[1] * r0 - n[1] * width)]
        out.append(prism(f"{prefix}{i}", pts, depth, (0, y, 0), m=mats[i % len(mats)], bevel=0.0012))
    return out


def periscope(m):
    """A short tube with a periscope column rising from its front, head facing forward."""
    axis = 0.05
    profile = [(-0.03, 0.031), (-0.022, 0.031), (-0.018, 0.0285), (0.022, 0.0285), (0.026, 0.031), (0.03, 0.031)]
    body = [
        box("PeriBase", (0.042, 0.06, 0.016), (0, 0, 0.008), bevel=0.005, m=m["body"]),
        box("PeriSaddle", (0.028, 0.03, 0.012), (0, 0, 0.019), bevel=0.004, m=m["body"]),
        lathe("PeriTube", profile, axis, m["body"], 0.0255, 0.0255, segs=24, inner_wall=True),
        torus("PeriRingA", 0.031, 0.0032, (0, -0.027, axis), rot=rad(90, 0, 0), m=m["accent"], major_segs=24, minor_segs=6),
        box("PeriColumn", (0.02, 0.018, 0.05), (0, 0.016, axis + 0.05), bevel=0.006, m=m["accent"]),
        box("PeriHead", (0.028, 0.038, 0.022), (0, 0.02, axis + 0.083), bevel=0.007, m=m["body"]),
        box("PeriHeadGlass", (0.02, 0.004, 0.012), (0, 0.039, axis + 0.083), bevel=0.0015, m=m["glass"]),
        box("PeriHeadBrow", (0.03, 0.01, 0.004), (0, 0.033, axis + 0.096), bevel=0.0015, m=m["accent"]),
        sphere("PeriLamp", 0.0035, (0, 0.0005, axis + 0.083), m=m["glow"], segs=8, rings=5),
    ]
    for i, z in enumerate((axis + 0.035, axis + 0.055)):
        body.append(torus(f"PeriBand{i}", 0.0125, 0.002, (0, 0.016, z), m=m["steel"], major_segs=16, minor_segs=5))
    body += knob("PeriSide", (0.028, -0.004, axis), "x", m["steel"], m["accent"], radius=0.008, height=0.01)
    body += clamp_bolts("PeriBolt", (-0.018, 0.018), 0.05, 0.009, m["steel"])
    return optic("Periscope", body, (0.0265, 0.0265), (0, -0.012, axis), (0, -0.2, axis), m)


def gem(m):
    """A crown of crystals round a round window, with a big gem on top."""
    axis = 0.046
    y = -0.012
    body = [
        box("GemBase", (0.05, 0.08, 0.016), (0, 0.008, 0.008), bevel=0.005, m=m["body"]),
        box("GemNeck", (0.03, 0.02, 0.012), (0, y, 0.018), bevel=0.004, m=m["body"]),
        torus("GemBezel", 0.03, 0.0045, (0, y, axis), rot=rad(90, 0, 0), m=m["steel"], major_segs=32, minor_segs=6),
        torus("GemBezelBack", 0.0295, 0.003, (0, y + 0.008, axis), rot=rad(90, 0, 0), m=m["body"], major_segs=32, minor_segs=6),
        cyl("GemTop", 0.0105, 0.016, (0, y, axis + 0.05), segs=6, bevel=0.0015, m=m["accent"], radius_top=0.0045),
        cyl("GemTopPoint", 0.0105, 0.012, (0, y, axis + 0.036), rot=rad(180, 0, 0), segs=6, bevel=0.0012, m=m["accent"], radius_top=0.001),
        sphere("GemSpark", 0.003, (0, y - 0.006, axis + 0.05), m=m["glow"], segs=8, rings=5),
    ]
    body += radial_spikes("GemCrystal", 10, axis, y, 0.031, (0.013, 0.008), 0.0055, 0.01, (m["accent"], m["steel"]), phase=math.pi / 10)
    body += clamp_bolts("GemBolt", (0.004, 0.03), 0.058, 0.008, m["steel"])
    return optic("Gem", body, (0.0265, 0.0265), (0, y - 0.004, axis), (0, -0.21, axis), m)


def gallery(m):
    """Shooting-gallery hoop: a red-and-white ring studded with bulbs, a sign on top."""
    axis = 0.046
    y = -0.01
    body = [
        box("GalBase", (0.05, 0.08, 0.016), (0, 0.008, 0.008), bevel=0.005, m=m["body"]),
        box("GalSign", (0.046, 0.007, 0.014), (0, y, axis + 0.047), bevel=0.003, m=m["white"]),
        box("GalSignTrim", (0.05, 0.006, 0.003), (0, y, axis + 0.039), bevel=0.001, m=m["accent"]),
    ]
    for i in range(8):
        a0 = math.tau * i / 8
        body.append(torus(f"GalRing{i}", 0.032, 0.0048, (0, y, axis), rot=rad(90, 0, 0), m=m["accent"] if i % 2 else m["white"],
                          major_segs=6, minor_segs=6, arc=math.tau / 8, start=a0))
    for i in range(12):
        a = math.tau * i / 12 + math.pi / 12
        body.append(sphere(f"GalBulb{i}", 0.0033, (math.cos(a) * 0.032, y - 0.0045, axis + math.sin(a) * 0.032), m=m["glow"], segs=8, rings=5))
    for k in range(3):
        body.append(sphere(f"GalSignBulb{k}", 0.0026, (-0.014 + k * 0.014, y - 0.004, axis + 0.047), m=m["glow"], segs=8, rings=5))
    for side in (-1, 1):
        body.append(box(f"GalPost{side}", (0.008, 0.014, 0.03), (side * 0.024, y, 0.026), rot=(0, side * -0.35, 0), bevel=0.003, m=m["body"]))
    body += clamp_bolts("GalBolt", (0.004, 0.032), 0.058, 0.008, m["steel"])
    return optic("Gallery", body, (0.0265, 0.0265), (0, y - 0.002, axis), (0, -0.21, axis), m)


def zombie_eye(m):
    """An eyeball: a bulging white tube with green lids, red veins and a glowing iris."""
    axis = 0.052
    profile = [(-0.03, 0.028), (-0.024, 0.034), (-0.01, 0.038), (0.01, 0.038), (0.024, 0.034), (0.03, 0.029)]
    body = [
        box("EyeBase", (0.042, 0.06, 0.016), (0, 0, 0.008), bevel=0.005, m=m["body"]),
        box("EyeSaddle", (0.03, 0.036, 0.012), (0, 0, 0.019), bevel=0.004, m=m["body"]),
        lathe("EyeBall", profile, axis, m["white"], 0.0255, 0.0265, segs=28, inner_wall=True),
        torus("EyeIris", 0.0285, 0.004, (0, 0.03, axis), rot=rad(90, 0, 0), m=m["glow"], major_segs=28, minor_segs=6),
        torus("EyeLidTop", 0.039, 0.0075, (0, -0.004, axis), rot=rad(90, 0, 0), m=m["accent"], major_segs=20, minor_segs=8,
              arc=math.radians(130), start=math.radians(25)),
        torus("EyeLidLow", 0.038, 0.006, (0, -0.002, axis), rot=rad(90, 0, 0), m=m["accent"], major_segs=16, minor_segs=8,
              arc=math.radians(90), start=math.radians(225)),
    ]
    for i in range(5):
        a = math.radians(45 + i * 22.5)
        base = (math.cos(a) * 0.045, -0.004, axis + math.sin(a) * 0.045)
        body.append(cyl(f"EyeLash{i}", 0.0018, 0.008, base, rot=(0, math.radians(90) - a, 0), segs=6, bevel=0.0, m=m["body"], radius_top=0.0004))
    for i, (a, side) in enumerate(((200, 1), (160, 1), (20, -1), (-20, -1))):
        ang = math.radians(a)
        pts = []
        for k in range(5):
            f = k / 4
            r = 0.0383 - 0.002 * abs(f - 0.5)
            yy = 0.02 - f * 0.032
            wob = math.sin(f * 9 + i) * 0.12
            pts.append((math.cos(ang + wob) * r, yy, axis + math.sin(ang + wob) * r))
        body.append(tube(f"EyeVein{i}", pts, 0.0011, m=m["vein"], segs=5))
    body += clamp_bolts("EyeBolt", (-0.018, 0.018), 0.05, 0.009, m["steel"])
    return optic("Eye", body, (0.0265, 0.0265), (0, -0.018, axis), (0, -0.2, axis), m)


def hex_hood(m):
    """A hexagonal neon hood: six panels round the window, lit along the rear edge."""
    axis = 0.047
    y = -0.012
    apothem = 0.03
    side = 2 * apothem * math.tan(math.radians(30))
    body = [box("HexBase", (0.056, 0.09, 0.02), (0, 0.008, 0.01), bevel=0.006, m=m["body"])]
    for i in range(6):
        a = math.radians(30 + 60 * i)
        c = (math.cos(a) * (apothem + 0.004), axis + math.sin(a) * (apothem + 0.004))
        tilt = math.radians(90) - a
        body.append(box(f"HexPanel{i}", (side + 0.0062, 0.04, 0.008), (c[0], y, c[1]), rot=(0, tilt, 0), bevel=0.0025,
                        m=m["accent"] if i % 2 else m["body"]))
        cr = (math.cos(a) * (apothem + 0.0005), axis + math.sin(a) * (apothem + 0.0005))
        body.append(box(f"HexNeon{i}", (side * 0.9, 0.003, 0.002), (cr[0], y - 0.02, cr[1]), rot=(0, tilt, 0), bevel=0.0006, m=m["glow"]))
    for s_ in (-1, 1):
        body.append(box(f"HexLeg{s_}", (0.008, 0.026, 0.012), (s_ * 0.016, y, 0.022), bevel=0.003, m=m["body"]))
    body += clamp_bolts("HexBolt", (0.006, 0.034), 0.064, 0.01, m["steel"])
    return optic("Hex", body, (0.022, 0.02), (0, y - 0.006, axis), (0, -0.21, axis), m)


def brass_scope(m):
    """Vintage 1.4x: a slim brass tube with knurled rings, flared eyepiece and bell."""
    axis = 0.058
    profile = [(-0.07, 0.035), (-0.052, 0.035), (-0.046, 0.0305), (0.04, 0.0305), (0.05, 0.0375), (0.074, 0.0375)]
    body = [
        box("BrassRail", (0.03, 0.09, 0.012), (0, 0.002, 0.006), bevel=0.004, m=m["body"]),
        lathe("BrassTube", profile, axis, m["brass"], 0.0265, 0.0275, segs=28, inner_wall=True),
        front_glass("BrassGlass", 0.028, 0.07, axis, m["glass"]),
        torus("BrassEyeCup", 0.035, 0.004, (0, -0.069, axis), rot=rad(90, 0, 0), m=m["accent"], major_segs=28, minor_segs=6),
        torus("BrassBell", 0.0375, 0.004, (0, 0.073, axis), rot=rad(90, 0, 0), m=m["accent"], major_segs=28, minor_segs=6),
        box("BrassPlate", (0.004, 0.03, 0.01), (-0.0315, 0.0, axis), bevel=0.0015, m=m["steel"]),
    ]
    for i in range(5):
        body.append(torus(f"BrassKnurl{i}", 0.0355, 0.0016, (0, -0.064 + i * 0.0035, axis), rot=rad(90, 0, 0), m=m["steel"], major_segs=24, minor_segs=4))
    for i, yy in enumerate((-0.03, 0.026)):
        body += [
            box(f"BrassMount{i}", (0.022, 0.016, 0.028), (0, yy, 0.02), bevel=0.004, m=m["body"]),
            torus(f"BrassRing{i}", 0.0335, 0.004, (0, yy, axis), rot=rad(90, 0, 0), m=m["brass"], major_segs=24, minor_segs=6),
        ]
    body += knob("BrassTop", (0, -0.002, axis + 0.03), "z", m["brass"], m["accent"], radius=0.01, height=0.012)
    return optic("Brass", body, (0.026, 0.026), (0, -0.066, axis), (0, -0.24, axis), m)


def starburst(m):
    """A ring with a star of long and short spikes round it."""
    axis = 0.046
    y = -0.01
    body = [
        box("BurstBase", (0.05, 0.08, 0.016), (0, 0.008, 0.008), bevel=0.005, m=m["body"]),
        box("BurstPost", (0.016, 0.02, 0.016), (0, y, 0.021), bevel=0.004, m=m["body"]),
        torus("BurstRing", 0.0305, 0.004, (0, y, axis), rot=rad(90, 0, 0), m=m["accent"], major_segs=32, minor_segs=6),
        torus("BurstGlowRing", 0.0285, 0.0016, (0, y - 0.004, axis), rot=rad(90, 0, 0), m=m["glow"], major_segs=32, minor_segs=5),
    ]
    body += radial_spikes("BurstSpike", 8, axis, y, 0.032, (0.02, 0.011), 0.006, 0.007, (m["accent"], m["steel"]), phase=math.pi / 8)
    body += clamp_bolts("BurstBolt", (0.004, 0.032), 0.058, 0.008, m["steel"])
    return optic("Burst", body, (0.0265, 0.0265), (0, y - 0.002, axis), (0, -0.21, axis), m)


def rangefinder(m):
    """A wide box with two windows: the sight on the axis, a second lens to its left."""
    axis = 0.05
    y = -0.004
    depth = 0.05
    body = [
        box("RangeBase", (0.05, 0.08, 0.016), (0, 0.006, 0.008), bevel=0.005, m=m["body"]),
        box("RangeTop", (0.104, depth, 0.011), (-0.021, y, axis + 0.0235), bevel=0.004, m=m["body"]),
        box("RangeBottom", (0.104, depth, 0.011), (-0.021, y, axis - 0.0235), bevel=0.004, m=m["body"]),
        box("RangeRight", (0.009, depth, 0.058), (0.0285, y, axis), bevel=0.003, m=m["body"]),
        box("RangeMiddle", (0.009, depth, 0.058), (-0.0285, y, axis), bevel=0.003, m=m["accent"]),
        box("RangeLeft", (0.04, depth, 0.036), (-0.052, y, axis), bevel=0.004, m=m["body"]),
        front_glass("RangeSecond", 0.012, y + depth / 2 + 0.0005, axis, m["glass"]),
        box("RangeDisplay", (0.03, 0.002, 0.005), (-0.05, y - depth / 2 - 0.0008, axis + 0.01), bevel=0.0006, m=m["glow"]),
        box("RangeBand", (0.105, depth + 0.001, 0.004), (-0.021, y, axis + 0.0302), bevel=0.0012, m=m["accent"]),
        box("RangeFoot", (0.03, 0.03, 0.012), (0, y, 0.02), bevel=0.004, m=m["body"]),
    ]
    # The second window's glass sits in the left module (offset along x).
    body[6].location = (-0.052, 0, 0)
    for i, x in enumerate((-0.062, -0.047)):
        body += knob(f"RangeButton{i}", (x, y + 0.01, axis + 0.029), "z", m["steel"], m["accent"] if i else m["glow"], radius=0.0045, height=0.005)
    body += clamp_bolts("RangeBolt", (-0.014, 0.026), 0.058, 0.009, m["steel"])
    return optic("Ranger", body, (0.0225, 0.017), (0, y - 0.014, axis), (0, -0.21, axis), m)


def frost(m):
    """A frosted tube with ice fins round its middle and a snow cap."""
    axis = 0.052
    profile = [(-0.03, 0.0315), (-0.022, 0.0315), (-0.018, 0.029), (0.022, 0.029), (0.026, 0.0315), (0.03, 0.0315)]
    body = [
        box("FrostBase", (0.042, 0.06, 0.016), (0, 0, 0.008), bevel=0.005, m=m["body"]),
        box("FrostSaddle", (0.028, 0.03, 0.012), (0, 0, 0.019), bevel=0.004, m=m["body"]),
        lathe("FrostTube", profile, axis, m["ice"], 0.026, 0.026, segs=24, inner_wall=True),
        sphere("FrostCap", 0.016, (0.002, 0.0, axis + 0.029), scale=(1.3, 1.9, 0.42), m=m["white"], segs=14, rings=8),
        torus("FrostRingA", 0.0315, 0.003, (0, -0.027, axis), rot=rad(90, 0, 0), m=m["accent"], major_segs=24, minor_segs=6),
        torus("FrostRingB", 0.0315, 0.003, (0, 0.027, axis), rot=rad(90, 0, 0), m=m["accent"], major_segs=24, minor_segs=6),
    ]
    for i in range(10):
        a = math.tau * i / 10 + math.pi / 10
        if math.sin(a) > 0.6:
            continue
        d = (math.cos(a), math.sin(a))
        length = 0.013 if i % 2 else 0.009
        tip = (d[0] * (0.029 + length), 0.0, axis + d[1] * (0.029 + length))
        body.append(prism(f"FrostFin{i}", [(d[0] * 0.028 - d[1] * 0.006, axis + d[1] * 0.028 + d[0] * 0.006), (tip[0], tip[2]),
                                           (d[0] * 0.028 + d[1] * 0.006, axis + d[1] * 0.028 - d[0] * 0.006)], 0.012, (0, 0, 0), m=m["ice"], bevel=0.0012))
    for i, x in enumerate((-0.016, -0.004, 0.01)):
        body.append(cyl(f"FrostIcicle{i}", 0.0028, 0.012 - i * 0.002, (x, 0.029, axis - 0.03 - 0.005), segs=6, bevel=0.0, m=m["ice"], radius_top=0.0003))
        body[-1].rotation_euler = rad(180, 0, 0)
    body += clamp_bolts("FrostBolt", (-0.018, 0.018), 0.05, 0.009, m["steel"])
    return optic("Frost", body, (0.0265, 0.0265), (0, -0.012, axis), (0, -0.2, axis), m)


def porthole(m):
    """A bolted brass porthole on a stand, hinged on its right."""
    axis = 0.046
    y = -0.008
    body = [
        box("PortBase", (0.05, 0.08, 0.016), (0, 0.008, 0.008), bevel=0.005, m=m["body"]),
        box("PortStand", (0.022, 0.018, 0.014), (0, y + 0.004, 0.019), bevel=0.004, m=m["body"]),
        torus("PortRing", 0.032, 0.0068, (0, y, axis), rot=rad(90, 0, 0), m=m["brass"], major_segs=36, minor_segs=8),
        torus("PortLip", 0.027, 0.0024, (0, y - 0.005, axis), rot=rad(90, 0, 0), m=m["accent"], major_segs=32, minor_segs=5),
        box("PortHinge", (0.008, 0.012, 0.016), (0.041, y, axis), bevel=0.003, m=m["brass"]),
        cyl("PortHingePin", 0.0025, 0.022, (0.045, y, axis), segs=8, bevel=0.0006, m=m["steel"]),
        box("PortLatch", (0.01, 0.008, 0.006), (-0.041, y - 0.002, axis), bevel=0.002, m=m["steel"]),
    ]
    for i in range(8):
        a = math.tau * i / 8 + math.pi / 8
        body.append(sphere(f"PortBolt{i}", 0.0034, (math.cos(a) * 0.032, y - 0.0068, axis + math.sin(a) * 0.032), m=m["steel"], segs=8, rings=5))
    body += clamp_bolts("PortBolt", (0.004, 0.032), 0.058, 0.008, m["steel"])
    return optic("Porthole", body, (0.0255, 0.0255), (0, y - 0.003, axis), (0, -0.21, axis), m)


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
    for build in (reflex, holo, tube_dot, prism_scope, scope, periscope, gem, gallery, zombie_eye, hex_hood, brass_scope, starburst,
                  rangefinder, frost, porthole):
        exports += build(m)
    bpy.context.view_layer.update()
    check_clear_axis(exports)
    save("sights", exports)


if __name__ == "__main__":
    build_sights()
