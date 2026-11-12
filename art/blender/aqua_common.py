"""Shared helpers for the Abyss Aquarium asset scripts (build_aqua_*.py).

Builds on wla_common (same conventions: metres, Z up in Blender, a prop's
front faces -Y = Godot +Z, chunky bevelled flat-colour parts) and adds the
aquarium palette plus a few organic primitives (lumpy rocks, coral, ribbons,
portholes, rivet rows).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import _finish  # noqa: F401

import bmesh
from mathutils import Matrix, Vector, noise

# Abyss Aquarium palette: deep blues and teals for the building, warm
# submarine yellows and coral oranges for anything the player should notice.
AQUA = {
    "Navy": "#0d1f3c",
    "NavyDark": "#081428",
    "NavyLight": "#1b3a63",
    "Slate": "#3a4c66",
    "SlateLight": "#6f86a6",
    "Teal": "#0f8f9a",
    "TealDark": "#0a5c66",
    "TealLight": "#41d3d9",
    "Aqua": "#5fe8f0",
    "Cyan": "#3ff0ff",
    "Violet": "#7a3cff",
    "VioletDark": "#3b1d84",
    "Pink": "#ff4fb8",
    "PinkLight": "#ff8fd0",
    "Coral": "#ff6f4f",
    "CoralLight": "#ff9e7a",
    "Orange": "#ff8a2a",
    "SubYellow": "#ffc23a",
    "SubYellowDark": "#d9921c",
    "Yellow": "#ffd93b",
    "Sand": "#e2c595",
    "SandDark": "#b8935f",
    "Rock": "#4a4f66",
    "RockDark": "#2f3247",
    "RockLight": "#6c6f88",
    "Steel": "#8f9db3",
    "SteelDark": "#4b5770",
    "Chrome": "#c9d4e2",
    "Brass": "#d6a446",
    "White": "#f2f6f8",
    "Cream": "#fff0d4",
    "Dark": "#141826",
    "Red": "#ff2a3a",
    "Green": "#2fd16a",
    "Kelp": "#4f8f2c",
    "KelpLight": "#a7c93c",
    "Glass": "#9fe9ff",
}


def amat(name, color=None, rough=0.6, metal=0.0, emit=0.0):
    """Material from the aquarium palette (key or hex); cached by name."""
    if color is None:
        color = AQUA.get(name, name)
    else:
        color = AQUA.get(color, color)
    return mat(name, color, rough=rough, metal=metal, emit=emit, emit_color=color if emit > 0 else None)


def aglow(name, color=None, strength=3.0):
    return amat(name, color, rough=0.3, emit=strength)


def lumpy(name, radius, loc=(0, 0, 0), scale=(1, 1, 1), m=None, seed=0, amount=0.25, subdiv=2, freq=1.6, flat_bottom=None):
    """Noise-displaced icosphere: rocks, brain coral, sponges."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    off = Vector((seed * 3.17, seed * 1.31, seed * 2.07))
    for v in bm.verts:
        n = noise.noise(v.co * freq / radius + off)
        v.co *= 1.0 + n * amount
        v.co.x *= scale[0]
        v.co.y *= scale[1]
        v.co.z *= scale[2]
        if flat_bottom is not None and v.co.z < flat_bottom:
            v.co.z = flat_bottom
    return _finish(name, bm, m, loc, (0, 0, 0))


def porthole(prefix, radius, loc, rot=(0, 0, 0), frame=None, glass=None, rivets=8, depth=0.12):
    """Round window: a ring frame with rivets and a glowing pane. Faces -Y."""
    frame = frame or amat("Brass", rough=0.35, metal=0.6)
    parts = [torus(prefix + "Ring", radius, radius * 0.18, (0, 0, 0), rot=rad(90, 0, 0), m=frame, major_segs=24, minor_segs=6)]
    if glass is not None:
        parts.append(cyl(prefix + "Pane", radius * 0.95, depth * 0.4, (0, depth * 0.3, 0), rot=rad(90, 0, 0), segs=20, bevel=0.0, m=glass))
    for i in range(rivets):
        a = math.tau * i / rivets
        parts.append(sphere(f"{prefix}Rivet{i}", radius * 0.07, (math.cos(a) * radius * 1.22, -radius * 0.08, math.sin(a) * radius * 1.22),
                            m=frame, segs=6, rings=4))
    m = Matrix.Translation(Vector(loc)) @ Euler(rot, "XYZ").to_matrix().to_4x4()
    for ob in parts:
        ob.matrix_world = m @ ob.matrix_basis
    return parts


def rivet_row(prefix, a, b, count, radius, m):
    a, b = Vector(a), Vector(b)
    return [sphere(f"{prefix}{i:02d}", radius, a.lerp(b, i / max(1, count - 1)), m=m, segs=6, rings=4) for i in range(count)]


def ribbon(name, points, widths, m=None, twist=0.0, normal=(1, 0, 0)):
    """Flat strip through `points` (list of xyz), width per point, in the plane
    spanned by the path and `normal` rotated by `twist` radians per metre."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rows = []
    length = 0.0
    prev = None
    for i, p in enumerate(points):
        p = Vector(p)
        if prev is not None:
            length += (p - prev).length
        prev = p
        ang = twist * length
        side = Vector(normal)
        side = Vector((side.x * math.cos(ang) - side.y * math.sin(ang), side.x * math.sin(ang) + side.y * math.cos(ang), side.z))
        w = widths[i] * 0.5
        rows.append((bm.verts.new(p - side * w), bm.verts.new(p + side * w)))
    n = len(rows)
    for i in range(n - 1):
        f = bm.faces.new((rows[i][0], rows[i][1], rows[i + 1][1], rows[i + 1][0]))
        for loop, (u, v) in zip(f.loops, ((0, i / (n - 1)), (1, i / (n - 1)), (1, (i + 1) / (n - 1)), (0, (i + 1) / (n - 1)))):
            loop[uv].uv = (u, v)
    return _finish(name, bm, m, (0, 0, 0), (0, 0, 0), smooth=True)


def ring_points(radius, count, z=0.0, phase=0.0, centre=(0, 0)):
    return [(centre[0] + math.cos(phase + math.tau * i / count) * radius,
             centre[1] + math.sin(phase + math.tau * i / count) * radius, z) for i in range(count)]


def capsule_x(name, radius, length, loc=(0, 0, 0), m=None, segs=16):
    """Capsule lying along X (submarine hulls, pipes with rounded ends)."""
    body = cyl(name, radius, length, loc, rot=rad(0, 90, 0), segs=segs, bevel=0.0, m=m)
    ends = [sphere(name + "EndA", radius, (loc[0] - length / 2, loc[1], loc[2]), m=m, segs=segs, rings=8),
            sphere(name + "EndB", radius, (loc[0] + length / 2, loc[1], loc[2]), m=m, segs=segs, rings=8)]
    return [body] + ends


def frame_rect(prefix, w, h, depth, thick, loc, m, bottom=False):
    """Rectangular door/window frame in the XZ plane (facing -Y), bottom at loc z."""
    x, y, z = loc
    parts = [
        box(prefix + "L", (thick, depth, h), (x - w / 2 - thick / 2, y, z + h / 2), bevel=0.02, m=m),
        box(prefix + "R", (thick, depth, h), (x + w / 2 + thick / 2, y, z + h / 2), bevel=0.02, m=m),
        box(prefix + "T", (w + thick * 2, depth, thick), (x, y, z + h + thick / 2), bevel=0.02, m=m),
    ]
    if bottom:
        parts.append(box(prefix + "B", (w + thick * 2, depth, thick), (x, y, z - thick / 2), bevel=0.02, m=m))
    return parts


def rng(seed):
    return random.Random(seed)


def annulus(name, r_in, r_out, height, z=0.0, m=None, segs=48, bevel=0.02):
    """Flat ring (counter tops, trims): a thick washer centred on z."""
    bm = bmesh.new()
    rings = []
    for (r, h) in ((r_out, -height / 2), (r_out, height / 2), (r_in, height / 2), (r_in, -height / 2)):
        rings.append([bm.verts.new((math.cos(math.tau * i / segs) * r, math.sin(math.tau * i / segs) * r, h)) for i in range(segs)])
    for k in range(4):
        a, b = rings[k], rings[(k + 1) % 4]
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish(name, bm, m, (0, 0, z), (0, 0, 0))
    return add_bevel(ob, min(bevel, height * 0.4, (r_out - r_in) * 0.4), 2, angle=50)


# ---------------------------------------------------------------------------
# Reef life (used by the coral tank in the rotunda and the display tanks)
# ---------------------------------------------------------------------------

def coral_branch(prefix, loc, height, m, seed=0, tip=None):
    """Branching staghorn coral: a few forking tubes with rounded tips."""
    r = rng(seed)
    parts = []
    x0, y0, z0 = loc
    for i in range(r.randint(4, 6)):
        a = r.uniform(0, math.tau)
        lean = r.uniform(0.15, 0.55)
        h = height * r.uniform(0.6, 1.0)
        pts = []
        for k in range(5):
            t = k / 4
            bend = lean * t * t
            pts.append((x0 + math.cos(a) * bend * h, y0 + math.sin(a) * bend * h, z0 + t * h))
        rad_ = height * 0.07
        parts.append(tube(f"{prefix}B{i}", pts, rad_, m=m, segs=6, radius_end=rad_ * 0.7))
        parts.append(sphere(f"{prefix}T{i}", rad_ * 0.95, pts[-1], m=tip or m, segs=6, rings=4))
        if r.random() < 0.7:
            mid = pts[2]
            b = a + r.uniform(-1.2, 1.2)
            end = (mid[0] + math.cos(b) * h * 0.35, mid[1] + math.sin(b) * h * 0.35, mid[2] + h * 0.35)
            parts.append(tube(f"{prefix}S{i}", [mid, end], rad_ * 0.7, m=m, segs=6, radius_end=rad_ * 0.55))
            parts.append(sphere(f"{prefix}ST{i}", rad_ * 0.7, end, m=tip or m, segs=6, rings=4))
    return parts


def coral_fan(prefix, loc, size, m, yaw=0.0, seed=0):
    """Sea fan: a flat, slightly lumpy fan on a short stem."""
    r = rng(seed)
    outline = []
    for i in range(13):
        a = math.pi * i / 12
        rr = size * (0.75 + 0.25 * r.random())
        outline.append((math.cos(a) * rr * 0.9, math.sin(a) * rr * 1.05 + size * 0.12))
    outline.append((0.0, 0.0))
    fan = prism(prefix + "Fan", outline, size * 0.05, (0, 0, 0), m=m, bevel=size * 0.02)
    stem = cyl(prefix + "Stem", size * 0.05, size * 0.2, (0, 0, size * 0.04), segs=6, bevel=0.0, m=m)
    return place([fan, stem], loc, rot_z=yaw)


def coral_brain(prefix, loc, radius, m, seed=0, groove=None):
    parts = [lumpy(prefix + "Brain", radius, loc, (1.0, 1.0, 0.72), m=m, seed=seed, amount=0.12, subdiv=2, freq=3.0,
                   flat_bottom=-radius * 0.15)]
    if groove is not None:
        for k in range(3):
            parts.append(torus(f"{prefix}G{k}", radius * (0.45 + 0.22 * k), radius * 0.05,
                               (loc[0], loc[1], loc[2] + radius * (0.58 - 0.2 * k)), m=groove, major_segs=18, minor_segs=4))
    return parts


def coral_tubes(prefix, loc, height, m, inner, seed=0):
    """Tube sponge cluster: open-topped cylinders."""
    r = rng(seed)
    parts = []
    for i in range(r.randint(3, 5)):
        a = r.uniform(0, math.tau)
        d = r.uniform(0.0, height * 0.22)
        h = height * r.uniform(0.55, 1.0)
        rad_ = height * r.uniform(0.09, 0.13)
        x, y = loc[0] + math.cos(a) * d, loc[1] + math.sin(a) * d
        parts.append(cyl(f"{prefix}Tube{i}", rad_, h, (x, y, loc[2] + h / 2), segs=10, bevel=rad_ * 0.3, m=m, radius_top=rad_ * 1.15))
        parts.append(cyl(f"{prefix}Hole{i}", rad_ * 0.8, 0.02, (x, y, loc[2] + h + 0.002), segs=10, bevel=0.0, m=inner))
    return parts


def coral_table(prefix, loc, radius, m, seed=0):
    plate = lumpy(prefix + "Plate", radius, (loc[0], loc[1], loc[2] + radius * 0.55), (1.0, 1.0, 0.12), m=m, seed=seed,
                  amount=0.18, subdiv=2, freq=2.0)
    stem = cyl(prefix + "Stem", radius * 0.14, radius * 0.55, (loc[0], loc[1], loc[2] + radius * 0.27), segs=8, bevel=0.0, m=m)
    return [plate, stem]


def anemone(prefix, loc, radius, m, tip, seed=0):
    r = rng(seed)
    parts = [cyl(prefix + "Foot", radius * 0.6, radius * 0.5, (loc[0], loc[1], loc[2] + radius * 0.25), segs=12, bevel=radius * 0.15,
                 m=m, radius_top=radius * 0.75)]
    n = 14
    for i in range(n):
        a = math.tau * i / n + r.uniform(-0.1, 0.1)
        ring = 0.35 + 0.35 * (i % 2)
        base = (loc[0] + math.cos(a) * radius * ring, loc[1] + math.sin(a) * radius * ring, loc[2] + radius * 0.5)
        out = radius * r.uniform(0.6, 0.9)
        pts = [base,
               (base[0] + math.cos(a) * out * 0.4, base[1] + math.sin(a) * out * 0.4, base[2] + out * 0.6),
               (base[0] + math.cos(a) * out * 0.9, base[1] + math.sin(a) * out * 0.9, base[2] + out * 0.85)]
        parts.append(tube(f"{prefix}Ten{i}", pts, radius * 0.08, m=m, segs=5, radius_end=radius * 0.05))
        parts.append(sphere(f"{prefix}Tip{i}", radius * 0.07, pts[-1], m=tip, segs=5, rings=3))
    return parts


def starfish(prefix, loc, radius, m, yaw=0.0):
    s = star(prefix + "Star", radius, radius * 0.25, (0, 0, 0), rot=rad(-90, 0, 0), m=m, inner=radius * 0.42, bevel=radius * 0.08)
    return place([s], (loc[0], loc[1], loc[2] + radius * 0.1), rot_z=yaw)


def urchin(prefix, loc, radius, m, spike):
    parts = [sphere(prefix + "Body", radius, loc, scale=(1, 1, 0.8), m=m, segs=10, rings=6)]
    for i, p in enumerate(ring_points(radius * 0.95, 10, 0.0) + ring_points(radius * 0.7, 7, radius * 0.5, 0.3) + [(0, 0, radius * 0.8)]):
        d = Vector(p).normalized() if Vector(p).length > 0 else Vector((0, 0, 1))
        a = Vector(loc) + Vector(p)
        b = a + d * radius * 1.3
        parts.append(tube(f"{prefix}Sp{i}", [a, b], radius * 0.08, m=spike, segs=4, radius_end=0.004))
    return parts


def rock(prefix, loc, radius, m, seed=0, squash=0.7):
    return [lumpy(prefix + "Rock", radius, loc, (1.15, 0.95, squash), m=m, seed=seed, amount=0.28, subdiv=2, freq=1.4,
                  flat_bottom=-radius * 0.3)]
