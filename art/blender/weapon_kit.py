"""Shared building blocks for the weapon viewmodels (build_weapons.py and
build_weapons_arsenal.py): materials, detail parts, grips, gloved hands that
wrap those grips, top rails and iron sights, the charm lug, baked vertex
shading and the export.

Node contract of every weapon model (used by scripts/player/weapon_view.gd,
scripts/player/weapon_cosmetics.gd and scripts/cosmetics/weapon_charm.gd):

  Materials   "Shell" (main colour), "Trim" (panels), "Cell" (energy glow),
              "GunDark", "GunSteel", "GunPink", "Holo" (hologram glass,
              replaced in game), arms "Glove", "GlovePlate", "Cuff", "Sleeve"
  Static      Shell
  Animated    Cell, CellHolo and each weapon's own moving parts. Every
              animated part's origin is its pivot (hinge, axle, centre).
  Sights      IronSightRear, IronSightFront: the built-in sights, their own
              nodes so the game can hide them when an optic is fitted.
  Arms        ArmR (firing hand), ArmL (support hand). Origin = centre of
              the grip the hand holds; each has a child empty ElbowR/ElbowL
              half way down the forearm.
  Decal       emblem, hidden unless a decal is equipped
  Empties     Muzzle (barrel tip), EjectPoint, VentPoint (effect anchors),
              SightPoint  on the eye line of the built-in sights, at the rear
                          sight. The line runs parallel to the barrel. Nothing
                          but IronSight* parts rises above it (checked by
                          audit_weapons.py), so the target is never hidden.
              SightMount  centre of the flat top rail, on its top surface:
                          an optic's base sits here (+Y forward, +Z up in
                          Blender = -Z forward, +Y up in Godot). The rail is
                          flat for at least RAIL_FLAT metres around it.
              CharmPoint  eye of the charm lug, CHARM_STANDOFF proud of the
                          weapon's side. Everything a hanging charm can
                          reach lies behind that side (see charm_lug).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from mathutils.bvhtree import BVHTree  # noqa: E402

## How far the charm lug's eye stands out from the weapon's side (WeaponCharm.STANDOFF).
CHARM_STANDOFF = 0.018
## Length of flat rail guaranteed around SightMount.
RAIL_FLAT = 0.1
## Height of the eye line above the top of the rail.
SIGHT_HEIGHT = 0.024


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

def weapon_mats(accent="#33f0ff", holo=None, shell="#f6dfae", trim="#6b35b8", emit=2.6):
    """The shared weapon materials, with this weapon's accent as the Cell glow.
    Pale or saturated accents use a lower `emit` so the hue survives the glow."""
    return dict(
        shell=mat("Shell", shell, rough=0.38),
        trim=mat("Trim", trim, rough=0.36),
        cell=mat("Cell", accent, rough=0.3, emit=emit),
        dark=mat("GunDark", "#241d3a", rough=0.45, metal=0.35),
        steel=mat("GunSteel", "#8a86a3", rough=0.3, metal=0.75),
        pink=mat("GunPink", "#ff3f9f", rough=0.4),
        holo=mat("Holo", holo or accent, rough=0.2, emit=1.5),
        decal=mat("Decal", "#ffd93b", rough=0.4),
        glove=mat("Glove", "#2b2836", rough=0.7),
        plate=mat("GlovePlate", "#4a4560", rough=0.45, metal=0.3),
        cuff=mat("Cuff", "#ff3f9f", rough=0.5),
        sleeve=mat("Sleeve", "#1d1b26", rough=0.8),
    )


# ---------------------------------------------------------------------------
# Small geometry helpers
# ---------------------------------------------------------------------------

def side_profile(name, outline, width, loc, m, bevel=0.01, segs=2):
    """Extrude a side-view outline [(along_barrel, height), ...] across X.

    Lets us draw chamfered slides and shrouds the way they read from the side.
    """
    ob = prism(name, outline, width, (0, 0, 0), m=m, bevel=bevel, segs=segs)
    # prism() puts outline u on X and extrudes along Y; turn it so u runs along Y.
    for v in ob.data.vertices:
        x, y, z = v.co
        v.co = Vector((-y, x, z))
    ob.location = loc
    return ob


def ring(name, radius, minor, y, z=0.0, x=0.0, m=None, segs=20):
    """Torus around the barrel axis (along +Y)."""
    return torus(name, radius, minor, (x, y, z), rot=rad(90, 0, 0), m=m, major_segs=segs, minor_segs=6)


def ycyl(name, radius, length, y, z=0.0, x=0.0, m=None, segs=16, bevel=0.006, radius_top=None):
    """Cylinder lying along the barrel axis, centred at y. radius_top is the front end."""
    return cyl(name, radius, length, (x, y, z), rot=rad(-90, 0, 0), segs=segs, bevel=bevel, m=m, radius_top=radius_top)


def xcyl(name, radius, length, loc, m=None, segs=16, bevel=0.004):
    """Cylinder lying across the weapon (axis X)."""
    return cyl(name, radius, length, loc, rot=rad(0, 90, 0), segs=segs, bevel=bevel, m=m)


def obox(name, size, origin, x_axis, y_axis, bevel=0.01, segs=2, m=None):
    """Rounded box with its local X along x_axis and local Y towards y_axis."""
    ob = box(name, size, (0, 0, 0), bevel=bevel, segs=segs, m=m)
    x = Vector(x_axis).normalized()
    y = Vector(y_axis)
    y = (y - x * y.dot(x)).normalized()
    z = x.cross(y)
    o = Vector(origin)
    ob.matrix_world = Matrix(((x.x, y.x, z.x, o.x), (x.y, y.y, z.y, o.y), (x.z, y.z, z.z, o.z), (0, 0, 0, 1)))
    return ob


def _q0(a, b, c, off, t):
    l1, l2, l3 = b - c, (c + off) * math.pi / 2, a - c
    d = t * (l1 + l2 + l3)
    if d < l1:
        return (a + off, d), (1.0, 0.0)
    d -= l1
    if d < l2:
        ang = d / (c + off)
        return (a - c + (c + off) * math.cos(ang), b - c + (c + off) * math.sin(ang)), (math.cos(ang), math.sin(ang))
    d -= l2
    return (a - c - d, b + off), (0.0, 1.0)


def wrap_point(bar, off, s):
    """Point and outward normal on a rounded rectangle pushed out by `off`.

    bar = (half width a, half depth b, corner radius c). `s` runs round the
    outline: 0 = middle of the +X side, 1 = +Y, 2 = -X, 3 = -Y, 4 = 0 again,
    at an even pace along each quarter.
    """
    a, b, c = bar
    q = int(math.floor(s)) % 4
    t = s - math.floor(s)
    (x, y), (nx, ny) = _q0(a, b, c, off, t) if q % 2 == 0 else _q0(b, a, c, off, t)
    for _ in range(q):
        x, y, nx, ny = -y, x, -ny, nx
    return (x, y), (nx, ny)


def wrap_s(bar, off, s0, length, direction=1, spacing=0.007):
    """`s` values of points every `spacing` metres along the outline from s0 for `length` metres."""
    ds = 0.002 * direction
    out = [s0]
    s = s0
    (px, py), _n = wrap_point(bar, off, s)
    travelled = 0.0
    since = 0.0
    while travelled < length:
        s += ds
        (x, y), _n = wrap_point(bar, off, s)
        step = math.hypot(x - px, y - py)
        travelled += step
        since += step
        px, py = x, y
        if since >= spacing:
            out.append(s)
            since = 0.0
    if since > spacing * 0.3:
        out.append(s)
    return out


def frame(origin, x_axis, y_axis):
    """A local frame: (origin, X, Y, Z) with Z = X x Y."""
    x = Vector(x_axis).normalized()
    y = Vector(y_axis)
    y = (y - x * y.dot(x)).normalized()
    return (Vector(origin), x, y, x.cross(y))


def fpt(fr, x, y, z):
    """Frame coordinates -> weapon space."""
    o, ax, ay, az = fr
    return o + ax * x + ay * y + az * z


def loft(name, sections, m, n=28, bevel=0.006, smooth=True):
    """Hull through rounded-rectangle sections along the barrel (+Y).

    sections: [(y, half_width, half_height, z_centre, corner_radius[, x_centre]), ...]
    Gives tapering, swelling bodies instead of plain boxes.
    """
    bm = bmesh.new()
    rings = []
    for sec in sections:
        y, a, b, zc, c = sec[:5]
        xc = sec[5] if len(sec) > 5 else 0.0
        c = min(c, a * 0.98, b * 0.98)
        ring_verts = []
        for i in range(n):
            (px, pz), _nrm = wrap_point((a, b, c), 0.0, 4.0 * i / n + 0.5 / n)
            ring_verts.append(bm.verts.new((xc + px, y, zc + pz)))
        rings.append(ring_verts)
    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for j in range(n):
            bm.faces.new((r0[j], r1[j], r1[(j + 1) % n], r0[(j + 1) % n]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish_part(name, bm, m, smooth)
    return add_bevel(ob, bevel, 2)


def _finish_part(name, bm, material, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    source_collection().objects.link(ob)
    if material is not None:
        me.materials.append(material)
    return ob


def band(name, fr, bar, off0, off1, s_list, z0, z1, m, bevel=0.009):
    """Solid strip hugging a rounded-rectangle bar (frame coordinates): between
    offsets off0..off1 from its surface and heights z0..z1, along `s_list`.
    z1 may be a function of the frame (x, y) for a top edge that follows something."""
    bm = bmesh.new()
    rows = []
    for s in s_list:
        (ix, iy), _n = wrap_point(bar, off0, s)
        (ox, oy), _n = wrap_point(bar, off1, s)
        top_i = z1(ix, iy) if callable(z1) else z1
        top_o = z1(ox, oy) if callable(z1) else z1
        rows.append([bm.verts.new(fpt(fr, ix, iy, z0)), bm.verts.new(fpt(fr, ox, oy, z0)),
                     bm.verts.new(fpt(fr, ox, oy, top_o)), bm.verts.new(fpt(fr, ix, iy, top_i))])
    for i in range(len(rows) - 1):
        r0, r1 = rows[i], rows[i + 1]
        for j in range(4):
            bm.faces.new((r0[j], r1[j], r1[(j + 1) % 4], r0[(j + 1) % 4]))
    bm.faces.new(rows[0])
    bm.faces.new(list(reversed(rows[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish_part(name, bm, m)
    return add_bevel(ob, bevel, 3)


# ---------------------------------------------------------------------------
# Detail parts
# ---------------------------------------------------------------------------

def bolts(prefix, points, m, axis="x", radius=0.008, height=0.008):
    """Hex bolt heads. axis: the direction they face ("x", "y" or "z")."""
    rot = {"x": rad(0, 90, 0), "y": rad(90, 0, 0), "z": (0, 0, 0)}[axis]
    return [cyl(f"{prefix}{i}", radius, height, p, rot=rot, segs=6, bevel=0.002, m=m) for i, p in enumerate(points)]


def screws(prefix, points, m):
    return bolts(prefix, points, m)


def vent_slots(prefix, x, y0, y1, z, count, m_dark, m_glow, height=0.034, side=-1):
    """A row of slanted vent slots on a weapon side, each with a glow strip inside."""
    out = []
    for i in range(count):
        y = y0 + (y1 - y0) * (i + 0.5) / count
        out.append(box(f"{prefix}Slot{i}", (0.008, 0.014, height), (x, y, z), rot=rad(18, 0, 0), bevel=0.003, m=m_dark))
        out.append(box(f"{prefix}Glow{i}", (0.004, 0.006, height * 0.75), (x + side * 0.003, y, z), rot=rad(18, 0, 0), bevel=0.0, m=m_glow))
    return out


def panel_lines(prefix, x, lines, m, depth=0.0024):
    """Dark seams on a weapon side at `x`: lines = [(y0, z0, y1, z1), ...] (axis-aligned)."""
    out = []
    for i, (y0, z0, y1, z1) in enumerate(lines):
        size = (depth, max(abs(y1 - y0), 0.003), max(abs(z1 - z0), 0.003))
        out.append(box(f"{prefix}{i}", size, (x, (y0 + y1) / 2, (z0 + z1) / 2), bevel=0.0, m=m))
    return out


def fins(prefix, count, radius, y, z, size, m, start=0.0, sweep=0.0):
    """Radial fins around the barrel axis."""
    out = []
    for i in range(count):
        a = start + math.tau * i / count
        out.append(box(f"{prefix}{i}", size, (math.cos(a) * radius, y, z + math.sin(a) * radius),
                       rot=(sweep, math.pi / 2 - a, 0), bevel=min(size) * 0.3, m=m))
    return out


def side_emblem(name, outline, x, y, z, m, depth=0.01):
    """Emblem on the weapon's left side (the side the player sees)."""
    return prism(name, outline, depth, (x, y, z), rot=rad(0, 0, -90), m=m)


def holo_copy(parts, suffix="Holo"):
    """Duplicate parts with the hologram material (for the 'print-in' reload)."""
    out = []
    holo = mat("Holo")
    for ob in parts:
        dup = ob.copy()
        dup.data = ob.data.copy()
        dup.name = ob.name + suffix
        dup.data.materials.clear()
        dup.data.materials.append(holo)
        source_collection().objects.link(dup)
        out.append(dup)
    return out


def top_rail(prefix, y0, y1, z_top, M, width=0.04, x=0.0, pitch=0.022):
    """Flat accessory rail along the top: a dark bar with steel cross teeth
    whose tops are all at z_top (an optic's base sits on them)."""
    parts = [box(prefix + "Bar", (width, y1 - y0, 0.012), (x, (y0 + y1) / 2, z_top - 0.009), bevel=0.003, m=M["dark"])]
    count = max(2, int((y1 - y0 - 0.006) / pitch))
    for i in range(count):
        y = y0 + 0.008 + (y1 - y0 - 0.016) * i / (count - 1)
        parts.append(box(f"{prefix}Tooth{i}", (width + 0.006, 0.011, 0.007), (x, y, z_top - 0.0035), bevel=0.002, m=M["steel"]))
    return parts


def charm_lug(wall_x, y, z, M, out=-1.0):
    """A little bracket with a ring that stands CHARM_STANDOFF proud of the
    weapon's side (at x = wall_x), for a charm to hang from.

    Returns (parts, CharmPoint location). The side must be flat (nothing
    beyond wall_x) within a charm's reach below and around the lug:
    audit_weapons.py checks it.
    """
    x_eye = wall_x + out * CHARM_STANDOFF
    parts = [
        box("CharmLugPlate", (0.006, 0.034, 0.026), (wall_x + out * 0.002, y, z + 0.004), bevel=0.002, m=M["steel"]),
        box("CharmLugArm", (CHARM_STANDOFF + 0.004, 0.012, 0.01), ((wall_x + x_eye) / 2, y, z + 0.006), bevel=0.003, m=M["steel"]),
        torus("CharmLugRing", 0.0085, 0.0026, (x_eye, y, z - 0.004), rot=rad(0, 90, 0), m=M["steel"], major_segs=14, minor_segs=5),
        sphere("CharmLugCap", 0.0065, (x_eye, y, z + 0.006), m=M["cell"], segs=8, rings=5),
    ]
    parts += bolts("CharmLugBolt", [(wall_x + out * 0.005, y - 0.011, z + 0.004), (wall_x + out * 0.005, y + 0.011, z + 0.004)], M["dark"], radius=0.0035, height=0.004)
    # The charm's own split ring (radius 6 mm, hanging below its origin) links through ours.
    return parts, (x_eye, y, z - 0.008)


# ---------------------------------------------------------------------------
# Iron sights. Each returns (rear_parts, front_parts); the eye line is at
# height z_line, x. Rear parts stand on z_rear, front parts on z_front.
# ---------------------------------------------------------------------------

def sights_notch(x, y_rear, y_front, z_rear, z_front, z_line, M, gap=0.016):
    """Pistol sights: square rear notch with two glowing dots, front post with one."""
    h = z_line - z_rear
    rear = [box("RearBase", (0.05, 0.022, h * 0.45), (x, y_rear, z_rear + h * 0.22), bevel=0.004, m=M["dark"])]
    for i, side in enumerate((-1, 1)):
        rear.append(box(f"RearEar{i}", (0.014, 0.02, h * 0.62), (x + side * (gap / 2 + 0.007), y_rear, z_line - h * 0.31), bevel=0.003, m=M["dark"]))
        rear.append(sphere(f"RearDot{i}", 0.0042, (x + side * (gap / 2 + 0.007), y_rear - 0.0095, z_line - 0.007), m=M["cell"], segs=8, rings=5))
    hf = z_line - z_front
    front = [
        box("FrontBase", (0.022, 0.034, hf * 0.4), (x, y_front, z_front + hf * 0.2), bevel=0.004, m=M["dark"]),
        box("FrontPost", (0.011, 0.016, hf * 0.7), (x, y_front, z_line - hf * 0.35), bevel=0.003, m=M["dark"]),
        sphere("FrontDot", 0.0048, (x, y_front - 0.0075, z_line - 0.006), m=M["cell"], segs=8, rings=5),
    ]
    return rear, front


def sights_ghost_ring(x, y_rear, y_front, z_rear, z_front, z_line, M, radius=0.017):
    """Carbine sights: a rear aperture ring and a front post between two guard ears."""
    rear = [
        box("RearBase", (0.044, 0.03, 0.012), (x, y_rear, z_rear + 0.006), bevel=0.004, m=M["dark"]),
        box("RearStem", (0.014, 0.012, max(0.004, z_line - radius - z_rear - 0.008)), (x, y_rear, (z_rear + 0.01 + z_line - radius) / 2), bevel=0.003, m=M["dark"]),
        torus("RearRing", radius, 0.0042, (x, y_rear, z_line), rot=rad(90, 0, 0), m=M["dark"], major_segs=20, minor_segs=6),
        box("RearKnob", (0.012, 0.014, 0.012), (x + 0.03, y_rear, z_rear + 0.012), bevel=0.004, m=M["cell"]),
    ]
    hf = z_line - z_front
    front = [
        box("FrontBase", (0.05, 0.03, 0.012), (x, y_front, z_front + 0.006), bevel=0.004, m=M["dark"]),
        box("FrontPost", (0.009, 0.012, hf - 0.008), (x, y_front, z_front + 0.008 + (hf - 0.008) / 2), bevel=0.002, m=M["steel"]),
        sphere("FrontDot", 0.0045, (x, y_front - 0.006, z_line - 0.005), m=M["cell"], segs=8, rings=5),
    ]
    for i, side in enumerate((-1, 1)):
        front.append(box(f"FrontEar{i}", (0.007, 0.026, hf + 0.004), (x + side * 0.021, y_front, z_front + (hf + 0.004) / 2),
                         rot=rad(0, -side * 12, 0), bevel=0.003, m=M["dark"]))
    return rear, front


def sights_bead(x, y_rear, y_front, z_rear, z_front, z_line, M):
    """Shotgun sights: a shallow V notch at the rear, a big glowing bead on a tower at the front."""
    h = z_line - z_rear
    rear = [box("RearBase", (0.048, 0.024, max(0.004, h - 0.012)), (x, y_rear, z_rear + (h - 0.012) / 2), bevel=0.004, m=M["dark"])]
    for i, side in enumerate((-1, 1)):
        rear.append(box(f"RearWing{i}", (0.02, 0.02, 0.016), (x + side * 0.016, y_rear, z_line - 0.008), rot=rad(0, side * 28, 0), bevel=0.003, m=M["dark"]))
    hf = z_line - z_front
    front = [sphere("FrontBead", 0.011, (x, y_front, z_line - 0.011), m=M["cell"], segs=12, rings=8),
             box("FrontStem", (0.01, 0.014, max(0.004, hf - 0.02)), (x, y_front, z_front + (hf - 0.02) / 2), bevel=0.003, m=M["steel"])]
    for i, side in enumerate((-1, 1)):
        lean = math.degrees(math.atan2(0.03, max(0.01, hf - 0.02)))
        front.append(box(f"FrontLeg{i}", (0.008, 0.02, (hf - 0.02) * 1.12), (x + side * 0.016, y_front, z_front + (hf - 0.02) / 2),
                         rot=rad(0, side * lean, 0), bevel=0.003, m=M["dark"]))
    return rear, front


def sights_fork(x, y_rear, y_front, z_rear, z_front, z_line, M):
    """Arc Coil sights: a two-prong fork with glowing tips, and a ball on a stalk."""
    h = z_line - z_rear
    rear = [box("RearBase", (0.046, 0.022, 0.01), (x, y_rear, z_rear + 0.005), bevel=0.003, m=M["dark"])]
    for i, side in enumerate((-1, 1)):
        rear.append(cyl(f"RearProng{i}", 0.0048, h - 0.006, (x + side * 0.015, y_rear, z_rear + 0.006 + (h - 0.006) / 2), segs=8, bevel=0.0, m=M["steel"]))
        rear.append(sphere(f"RearTip{i}", 0.0062, (x + side * 0.015, y_rear, z_line), m=M["cell"], segs=10, rings=6))
    hf = z_line - z_front
    front = [
        box("FrontBase", (0.03, 0.022, 0.01), (x, y_front, z_front + 0.005), bevel=0.003, m=M["dark"]),
        cyl("FrontStalk", 0.004, hf - 0.012, (x, y_front, z_front + 0.006 + (hf - 0.012) / 2), segs=8, bevel=0.0, m=M["steel"]),
        sphere("FrontBall", 0.007, (x, y_front, z_line - 0.007), m=M["cell"], segs=10, rings=6),
    ]
    return rear, front


def sights_leaf(x, y_rear, y_front, z_rear, z_front, z_line, M):
    """Launcher sights: a ladder leaf with a peep ring, and a ring on a post."""
    h = z_line - z_rear
    rear = [box("RearHinge", (0.044, 0.02, 0.012), (x, y_rear, z_rear + 0.006), bevel=0.004, m=M["dark"])]
    for i, side in enumerate((-1, 1)):
        rear.append(box(f"RearRail{i}", (0.006, 0.008, h + 0.014), (x + side * 0.017, y_rear, z_rear + (h + 0.014) / 2), bevel=0.002, m=M["steel"]))
    for i in range(3):
        rear.append(box(f"RearRung{i}", (0.034, 0.006, 0.004), (x, y_rear, z_rear + 0.018 + i * (h - 0.036) / 2), bevel=0.0, m=M["cell" if i == 1 else "steel"]))
    rear.append(torus("RearPeep", 0.0105, 0.0032, (x, y_rear, z_line), rot=rad(90, 0, 0), m=M["dark"], major_segs=16, minor_segs=5))
    rear.append(box("RearTop", (0.04, 0.008, 0.005), (x, y_rear, z_line + 0.0165), bevel=0.002, m=M["steel"]))
    hf = z_line - z_front
    front = [
        box("FrontBase", (0.03, 0.022, 0.01), (x, y_front, z_front + 0.005), bevel=0.003, m=M["dark"]),
        box("FrontPost", (0.008, 0.01, hf - 0.02), (x, y_front, z_front + (hf - 0.02) / 2 + 0.002), bevel=0.002, m=M["steel"]),
        torus("FrontRing", 0.012, 0.003, (x, y_front, z_line), rot=rad(90, 0, 0), m=M["cell"], major_segs=16, minor_segs=5),
    ]
    return rear, front


def sights_frame(x, y_rear, y_front, z_rear, z_front, z_line, M, m_frame=None):
    """Cryo Beam sights: an open square window at the rear, a needle at the front."""
    m_frame = m_frame or M["trim"]
    w, hh = 0.03, 0.02
    rear = [
        box("RearBase", (0.05, 0.026, max(0.004, z_line - hh - z_rear)), (x, y_rear, (z_rear + z_line - hh) / 2), bevel=0.004, m=M["dark"]),
        box("RearL", (0.007, 0.014, hh * 2 + 0.007), (x - w, y_rear, z_line), bevel=0.002, m=m_frame),
        box("RearR", (0.007, 0.014, hh * 2 + 0.007), (x + w, y_rear, z_line), bevel=0.002, m=m_frame),
        box("RearT", (w * 2 + 0.007, 0.014, 0.007), (x, y_rear, z_line + hh), bevel=0.002, m=m_frame),
        box("RearTickL", (0.008, 0.004, 0.003), (x - w + 0.007, y_rear, z_line), bevel=0.0, m=M["cell"]),
        box("RearTickR", (0.008, 0.004, 0.003), (x + w - 0.007, y_rear, z_line), bevel=0.0, m=M["cell"]),
    ]
    hf = z_line - z_front
    front = [
        box("FrontBase", (0.026, 0.024, 0.01), (x, y_front, z_front + 0.005), bevel=0.003, m=M["dark"]),
        cyl("FrontNeedle", 0.0042, hf - 0.008, (x, y_front, z_front + 0.008 + (hf - 0.008) / 2), segs=8, bevel=0.0, m=M["steel"], radius_top=0.0018),
        sphere("FrontTip", 0.0048, (x, y_front, z_line - 0.0048), m=M["cell"], segs=10, rings=6),
    ]
    return rear, front


def sights_globe(x, y_rear, y_front, z_rear, z_front, z_line, M):
    """Rail Lancer sights: a dark rear aperture and a glowing front ring with fine cross wires."""
    rear = [
        box("RearMount", (0.032, 0.03, max(0.004, z_line - 0.02 - z_rear)), (x, y_rear, (z_rear + z_line - 0.02) / 2), bevel=0.004, m=M["dark"]),
        torus("RearRing", 0.0185, 0.0045, (x, y_rear, z_line), rot=rad(90, 0, 0), m=M["dark"], major_segs=20, minor_segs=6),
    ]
    front = [
        box("FrontMount", (0.026, 0.026, max(0.004, z_line - 0.024 - z_front)), (x, y_front, (z_front + z_line - 0.024) / 2), bevel=0.004, m=M["dark"]),
        torus("FrontRing", 0.0225, 0.004, (x, y_front, z_line), rot=rad(90, 0, 0), m=M["cell"], major_segs=22, minor_segs=6),
    ]
    # Cross wires stop short of the centre, so the aim point itself stays open.
    for i, (dx, dz) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1))):
        size = (0.012, 0.002, 0.0016) if dx else (0.0016, 0.002, 0.012)
        front.append(box(f"FrontWire{i}", size, (x + dx * 0.0145, y_front, z_line + dz * 0.0145), bevel=0.0, m=M["cell"]))
    return rear, front


# ---------------------------------------------------------------------------
# Grip, trigger and guard
# ---------------------------------------------------------------------------

def grip(prefix, loc, M, tilt=-14.0, size=(0.072, 0.094, 0.19), body_bottom=-0.02, guard_len=0.1,
         panel="trim", web_drop=0.0):
    """Rubberised pistol grip with textured side panels, back-strap ridges, a
    base cap, a round-bar trigger guard hung from the body underside
    (`body_bottom`) and a glowing trigger.

    Returns (parts, info). `info` describes the grip for firing_hand():
    the grip frame, the bar the hand wraps and where the fingers may go.
    """
    sx, sy, sz = size
    th = math.radians(tilt)
    fr = frame(loc, (1, 0, 0), (0, math.cos(th), math.sin(th)))
    r = (th, 0, 0)

    def g(x, y, z):
        return tuple(fpt(fr, x, y, z))

    parts = [
        box(prefix + "GripCore", size, loc, rot=r, bevel=0.022, m=M["dark"]),
        box(prefix + "GripCap", (sx + 0.007, sy + 0.007, 0.016), g(0, 0, -sz / 2 + 0.002), rot=r, bevel=0.006, m=M["steel"]),
        box(prefix + "GripCapLight", (sx * 0.5, 0.004, 0.005), g(0, -sy / 2 - 0.0035, -sz / 2 + 0.003), rot=r, bevel=0.0, m=M["cell"]),
    ]
    for i, side in enumerate((-1, 1)):
        parts.append(box(f"{prefix}GripPanel{i}", (0.006, sy * 0.6, sz * 0.56), g(side * (sx / 2 - 0.0005), 0.002, 0.004), rot=r, bevel=0.0025, m=M[panel]))
        for row in range(4):
            for col in range(2):
                parts.append(box(f"{prefix}GripStud{i}{row}{col}", (0.004, 0.013, 0.013),
                                 g(side * (sx / 2 + 0.003), -0.012 + col * 0.026, -0.036 + row * 0.027),
                                 rot=(th + math.radians(45), 0, 0), bevel=0.0, m=M["dark"]))
    for i in range(5):
        parts.append(box(f"{prefix}BackRidge{i}", (sx * 0.62, 0.007, 0.011), g(0, -sy / 2 - 0.001, -0.05 + i * 0.026), rot=r, bevel=0.002, m=M["steel"]))

    # Front face of the grip (frame y = sy/2) at a given weapon height.
    def front_y(zw):
        zl = (zw - loc[2] - (sy / 2) * math.sin(th)) / math.cos(th)
        return loc[1] + (sy / 2) * math.cos(th) - zl * math.sin(th)

    z_strap = body_bottom - 0.047
    y0 = front_y(z_strap)
    y1 = y0 + guard_len
    guard = [(0, y0 - 0.01, z_strap), (0, y1 - 0.034, z_strap)]
    for k in range(1, 6):
        a = math.radians(-90 + 18 * k)
        guard.append((0, y1 - 0.034 + math.cos(a) * 0.034, z_strap + 0.034 + math.sin(a) * 0.034))
    guard.append((0, y1, body_bottom + 0.006))
    y_trig = y0 + guard_len * 0.42
    z_trig = body_bottom - 0.027
    parts += [
        tube(prefix + "Guard", guard, 0.0065, m=M["dark"], segs=8),
        box(prefix + "Trigger", (0.012, 0.011, 0.034), (0, y_trig, body_bottom - 0.016), rot=rad(14, 0, 0), bevel=0.004, m=M["cell"]),
        box(prefix + "TriggerToe", (0.012, 0.016, 0.01), (0, y_trig + 0.008, body_bottom - 0.035), rot=rad(-20, 0, 0), bevel=0.004, m=M["cell"]),
        box(prefix + "TriggerHousing", (0.03, 0.03, 0.012), (0, y_trig - 0.004, body_bottom - 0.002), bevel=0.004, m=M["dark"]),
    ]
    a, b, c = sx / 2 + 0.0055, sy / 2 + 0.0045, 0.024
    reach = b + 0.0015 + 0.013
    # Highest the wrapped fingers may sit: just under the guard strap where it meets the grip.
    z_fingers = (z_strap - 0.0065 - loc[2] - reach * math.sin(th)) / math.cos(th) - 0.002
    # Top of the palm: it follows the underside of the body (a level plane in weapon space).
    z_top = body_bottom - web_drop - 0.004

    def web(x, y):
        return (z_top - loc[2] - y * math.sin(th)) / math.cos(th)

    info = dict(frame=fr, bar=(a, b, c), z_fingers=z_fingers, web=web, z_floor=-sz / 2 + 0.014,
                trigger=(y_trig, z_trig), tilt=th, loc=loc, size=size)
    return parts, info


# ---------------------------------------------------------------------------
# Gloved hands
# ---------------------------------------------------------------------------

GAP = 0.0016           # clearance between a glove and what it holds
FINGER_R = 0.0125
PALM_THICK = 0.027


def _finger(name, fr, bar, s_list, z, M, radius=FINGER_R, z_end=None, plate=True):
    """One finger curled round the bar at height z (frame coordinates)."""
    pts = []
    for i, s in enumerate(s_list):
        (x, y), _n = wrap_point(bar, GAP + radius, s)
        zz = z if z_end is None else z + (z_end - z) * i / max(1, len(s_list) - 1)
        pts.append(fpt(fr, x, y, zz))
    parts = [tube(name, pts, radius, m=M["glove"], segs=8, radius_end=radius * 0.86),
             sphere(name + "Tip", radius * 0.87, pts[-1], m=M["glove"], segs=8, rings=5)]
    if plate and len(pts) > 4:
        # Armoured knuckle guard on the first joint.
        k = min(2, len(pts) - 2)
        (x, y), (nx, ny) = wrap_point(bar, GAP + radius * 2 + 0.0015, s_list[k])
        centre = fpt(fr, x, y, z)
        tangent = pts[k + 1] - pts[k - 1]
        parts.append(obox(name + "Guard", (0.022, radius * 1.7, 0.006), centre, tangent, fr[3], bevel=0.0025, m=M["plate"]))
    return parts


def _forearm(prefix, start, toward, M, length=0.95, heel=0.036):
    """Wrist, cuff with a light band, armour band and sleeve leading off-screen."""
    c = Vector(start)
    d = (Vector(toward) - c).normalized()
    parts = [
        sphere(prefix + "Heel", heel, c, m=M["glove"], segs=14, rings=9),
        tube(prefix + "Wrist", [c, c + d * 0.1], heel * 0.94, m=M["glove"], segs=14, radius_end=0.046),
        tube(prefix + "Cuff", [c + d * 0.085, c + d * 0.125, c + d * 0.2], 0.064, m=M["cuff"], segs=16, radius_end=0.074),
        tube(prefix + "CuffRim", [c + d * 0.193, c + d * 0.215], 0.069, m=M["glove"], segs=16),
        tube(prefix + "CuffLight", [c + d * 0.13, c + d * 0.147], 0.0725, m=M["cell"], segs=16),
        tube(prefix + "Forearm", [c + d * 0.21, c + d * length], 0.06, m=M["sleeve"], segs=14, radius_end=0.09),
        tube(prefix + "Bracer", [c + d * 0.3, c + d * 0.37], 0.0695, m=M["plate"], segs=14, radius_end=0.0735),
        tube(prefix + "BracerLight", [c + d * 0.326, c + d * 0.336], 0.074, m=M["cell"], segs=14),
    ]
    return parts, tuple(c + d * 0.45)


def hand(prefix, fr, bar, M, toward, finger_z, band_z, s_web, palm_len, finger_len, thumb=None,
         wrist_s=None, wrist_z=None, wrist_out=0.045, extra_fingers=(), finger_r=FINGER_R,
         finger_bar=None, finger_s=None, finger_dir=1):
    """A chunky glove wrapped round a rounded-rectangle bar (grip, handguard...).

    Works in the frame `fr` (see wrap_point for `s`): the palm is a band from
    s_web for palm_len metres between the heights band_z = (z0, z1; z1 may be
    a function of frame x, y), the fingers continue round the bar from its
    end at the heights in finger_z, and the thumb leaves the web the other
    way. Nothing is closer to the bar than GAP, so the glove never cuts into
    what it holds.

    thumb: dict(z=, length=, lean=) wraps back from the web, or dict(points=[...])
           frame-space points for a thumb laid somewhere else.
    extra_fingers: [(name, [weapon-space points], radius)] e.g. the trigger finger.
    finger_bar / finger_s / finger_dir: wrap the fingers round a different
           (bigger) bar, from a given start, the other way round.
    Returns (parts, elbow_point).
    """
    z0, z1 = band_z
    palm_s = wrap_s(bar, GAP + PALM_THICK / 2, s_web, palm_len)
    parts = [band(prefix + "Palm", fr, bar, GAP, GAP + PALM_THICK, palm_s, z0, z1, M["glove"])]
    # Back-of-hand armour plate over the middle of the palm.
    mid = palm_s[len(palm_s) // 3: len(palm_s) - 2]
    if len(mid) > 2:
        (mx, my), _n = wrap_point(bar, GAP + PALM_THICK, mid[len(mid) // 2])
        top = z1(mx, my) if callable(z1) else z1
        lo, hi = z0 + (top - z0) * 0.22, top - (top - z0) * 0.22
        parts.append(band(prefix + "BackPlate", fr, bar, GAP + PALM_THICK - 0.002, GAP + PALM_THICK + 0.006, mid, lo, hi, M["plate"], bevel=0.003))
        (lx, ly), _n = wrap_point(bar, GAP + PALM_THICK + 0.0065, mid[len(mid) // 2])
        parts.append(sphere(prefix + "PlateLight", 0.006, fpt(fr, lx, ly, (lo + hi) / 2), m=M["cell"], segs=8, rings=5))
    fbar = finger_bar or bar
    start = finger_s if finger_s is not None else palm_s[-1] - 0.06
    fs = wrap_s(fbar, GAP + finger_r, start, finger_len + 0.012, direction=finger_dir)
    for i, z in enumerate(finger_z):
        # Outer fingers are a touch shorter.
        cut = 0 if i in (0, 1) else (1 if i == 2 else 2)
        parts += _finger(f"{prefix}Finger{i}", fr, fbar, fs[: len(fs) - cut], z, M, radius=finger_r)
    for name, pts, radius in extra_fingers:
        parts += [tube(prefix + name, [Vector(p) for p in pts], radius, m=M["glove"], segs=10, radius_end=radius * 0.88),
                  sphere(prefix + name + "Tip", radius * 0.89, pts[-1], m=M["glove"], segs=10, rings=6)]
    if thumb:
        tr = thumb.get("radius", 0.0145)
        if "points" in thumb:
            tpts = [fpt(fr, *p) for p in thumb["points"]]
        else:
            ts = wrap_s(bar, GAP + tr, s_web + 0.05, thumb.get("length", 0.075), direction=-1)
            tpts = []
            for i, s in enumerate(ts):
                (x, y), _n = wrap_point(bar, GAP + tr, s)
                tz = thumb["z"](x, y) if callable(thumb["z"]) else thumb["z"]
                tpts.append(fpt(fr, x, y, tz + thumb.get("lean", 0.0) * i / max(1, len(ts) - 1)))
        parts += [tube(prefix + "Thumb", tpts, tr, m=M["glove"], segs=10, radius_end=tr * 0.84),
                  sphere(prefix + "ThumbTip", tr * 0.85, tpts[-1], m=M["glove"], segs=10, rings=6),
                  sphere(prefix + "ThumbBase", tr * 1.02, tpts[0], m=M["glove"], segs=10, rings=6)]
    ws = wrist_s if wrist_s is not None else s_web + 0.75
    (wx, wy), _n = wrap_point(bar, GAP + wrist_out, ws)
    if wrist_z is None:
        wrist_z = (z0 + (z1(wx, wy) if callable(z1) else z1)) / 2
    arm_parts, elbow = _forearm(prefix, fpt(fr, wx, wy, wrist_z), toward, M)
    return parts + arm_parts, elbow


def firing_hand(G, M, toward, prefix="R"):
    """The right hand on a grip built by grip(): three fingers wrapped under the
    trigger guard, the index finger on the trigger, thumb round the left side."""
    fr, bar = G["frame"], G["bar"]
    r = FINGER_R
    pitch = 2 * r + 0.0015
    z_mid = G["z_fingers"] - GAP - r
    finger_z = [z_mid, z_mid - pitch, z_mid - 2 * pitch]
    z0 = max(G["z_floor"], finger_z[-1] - r - 0.005)
    web = G["web"]
    y_trig, z_trig = G["trigger"]
    a, b, _c = bar
    ri = 0.0105
    root = fpt(fr, a + GAP + 0.014, b * 0.35, min(web(a, b * 0.35) - 0.014, z_mid + pitch + 0.004))
    yt = y_trig + 0.0175 + GAP + ri
    index = [root, Vector((a + GAP + ri, G["loc"][1] + b + 0.02, z_trig + 0.004)), Vector((0.03, yt, z_trig)), Vector((-0.003, yt, z_trig))]
    thumb = dict(z=lambda x, y: web(x, y) - 0.0165, length=0.085)
    return hand(prefix, fr, bar, M, toward, finger_z, (z0, web), s_web=2.8, palm_len=0.132, finger_len=0.12,
                thumb=thumb, wrist_s=3.42, wrist_z=z0 + 0.05, extra_fingers=[("Index", index, ri)])


def support_hand(centre, half_width, half_height, M, toward, corner=0.022, prefix="L", finger_len=0.085,
                 palm_len=0.115, s_web=2.42, thumb_len=0.07, length=0.104, thumb_lean=-0.03):
    """The left hand cupping a handguard from below: palm under it, fingers up
    its right side, thumb up the left side (the side the player sees).

    The handguard is a bar along the barrel: `centre`, half_width (X) and
    half_height (Z); it must be clear for `length` metres along the barrel.
    """
    fr = frame(centre, (1, 0, 0), (0, 0, 1))      # frame Z = -Y (towards the player)
    bar = (half_width, half_height, min(corner, half_width * 0.9, half_height * 0.9))
    r = FINGER_R
    pitch = 2 * r + 0.0012
    finger_z = [-1.5 * pitch, -0.5 * pitch, 0.5 * pitch, 1.5 * pitch]
    half = length / 2
    thumb = dict(z=-half + 0.03, length=thumb_len, lean=thumb_lean)
    return hand(prefix, fr, bar, M, toward, finger_z, (-half, half), s_web=s_web, palm_len=palm_len,
                finger_len=finger_len, thumb=thumb, wrist_s=s_web + 0.38, wrist_z=half - 0.035, wrist_out=0.047)


def vertical_hand(centre, half_width, half_depth, height, M, toward, tilt=0.0, prefix="L"):
    """The left hand on a vertical foregrip: palm on its left and back, fingers
    round the front, thumb round the back."""
    th = math.radians(tilt)
    fr = frame(centre, (-1, 0, 0), (0, math.cos(th), math.sin(th)))    # frame Z points down the grip
    bar = (half_width + 0.002, half_depth + 0.002, 0.014)
    r = FINGER_R
    pitch = 2 * r + 0.0012
    top = -height / 2 + 0.024
    finger_z = [top + r + 0.004 + i * pitch for i in range(4)]
    thumb = dict(z=top + 0.016, length=0.042)
    return hand(prefix, fr, bar, M, toward, finger_z, (top, finger_z[-1] + r + 0.004), s_web=2.8, palm_len=0.118,
                finger_len=0.07, thumb=thumb, wrist_s=3.42, wrist_z=top + 0.07)


def cup_hand(G, M, toward, prefix="L"):
    """The left hand of a two-handed pistol hold: its palm on the left side of
    the grip under the firing hand's thumb, its fingers wrapped over the
    firing hand's fingers, its thumb forward along the top of the palm."""
    fr, bar = G["frame"], G["bar"]
    a0, b0, c0 = bar
    r = FINGER_R
    pitch = 2 * r + 0.0012
    web = G["web"]
    z_mid = G["z_fingers"] - GAP - r

    # Under the firing hand's thumb (which lies 0.0165 below the web line).
    def top(x, y):
        return web(x, y) - 0.0165 - 0.0145 - 0.0025

    finger_z = [z_mid - i * pitch for i in range(4)]
    z0 = max(G["z_floor"] - 0.006, finger_z[-1] - r - 0.003)
    grow = GAP + 2 * FINGER_R + 0.003
    big = (a0 + grow, b0 + grow, c0 + grow * 0.9)
    x_thumb = -(a0 + GAP + PALM_THICK + 0.0135 - 0.005)
    thumb = dict(points=[(x_thumb, y, top(x_thumb, y) - 0.0125) for y in (-0.028, -0.005, 0.02, 0.042)], radius=0.0135)
    return hand(prefix, fr, bar, M, toward, finger_z, (z0, top), s_web=1.74, palm_len=0.088, finger_len=0.1,
                thumb=thumb, wrist_s=2.3, wrist_z=z0 + 0.04, wrist_out=0.058,
                finger_bar=big, finger_s=1.97, finger_dir=-1)


# ---------------------------------------------------------------------------
# Baked shading
# ---------------------------------------------------------------------------

def _hemisphere(count):
    """Fixed, cosine-weighted directions about +Z."""
    out = []
    golden = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(count):
        u = (i + 0.5) / count
        r = math.sqrt(u)
        a = golden * i
        out.append(Vector((r * math.cos(a), r * math.sin(a), math.sqrt(1.0 - u))))
    return out


def bake_shading(targets, occluders, rays=14, reach=0.075, strength=0.5, gradient=0.1):
    """Paint soft ambient occlusion and a slight top-to-bottom gradient into the
    vertex colours of `targets` (the game multiplies them into the albedo of
    every flat finish; shader finishes ignore them)."""
    bm = bmesh.new()
    lo, hi = 1e9, -1e9
    for ob in occluders:
        me = ob.data
        base = len(bm.verts)
        mw = ob.matrix_world
        for v in me.vertices:
            co = mw @ v.co
            bm.verts.new(co)
            lo, hi = min(lo, co.z), max(hi, co.z)
        bm.verts.ensure_lookup_table()
        for p in me.polygons:
            try:
                bm.faces.new([bm.verts[base + i] for i in p.vertices])
            except ValueError:
                pass
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    dirs = _hemisphere(rays)
    for ob in targets:
        me = ob.data
        mw = ob.matrix_world
        nm = mw.to_3x3()
        shade = []
        for v in me.vertices:
            n = (nm @ v.normal).normalized()
            p = mw @ v.co + n * 0.0015
            up = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
            t = n.cross(up).normalized()
            bt = n.cross(t)
            hit = 0.0
            for d in dirs:
                w = t * d.x + bt * d.y + n * d.z
                _loc, _nrm, _idx, dist = tree.ray_cast(p, w, reach)
                if dist is not None:
                    hit += 1.0 - dist / reach
            ao = 1.0 - strength * min(1.0, hit / rays * 1.6)
            g = 1.0 - gradient * (1.0 - min(1.0, max(0.0, (p.z - lo) / max(1e-6, hi - lo))))
            shade.append(ao * g)
        attr = me.color_attributes.get("Shade") or me.color_attributes.new("Shade", "FLOAT_COLOR", "POINT")
        for i, s in enumerate(shade):
            attr.data[i].color = (s, s, s, 1.0)
        me.color_attributes.active_color = attr
        me.color_attributes.render_color_index = me.color_attributes.find("Shade")


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

def finish(name, groups, empties, shading=True):
    """Merge, shade and export a weapon.

    groups:  {node_name: (parts, pivot, parent_name_or_None)}
    empties: {node_name: (location, parent_name_or_None)}
    """
    exports = {}
    for key, (parts, pivot, parent_name) in groups.items():
        if not parts:
            continue
        parent = exports.get(parent_name) if parent_name else None
        exports[key] = merge(key, parts, pivot=pivot, parent=parent)
    for key, (loc, parent_name) in empties.items():
        exports[key] = empty(key, loc, parent=exports.get(parent_name) if parent_name else None)
    bpy.context.view_layer.update()
    if shading:
        meshes = {k: ob for k, ob in exports.items() if ob.type == "MESH" and not k.endswith("Holo") and k != "Decal"}
        body = [ob for k, ob in meshes.items() if not k.startswith("Arm")]
        bake_shading(body, body)
        arms = [ob for k, ob in meshes.items() if k.startswith("Arm")]
        if arms:
            bake_shading(arms, body + arms, strength=0.42, gradient=0.0)
    _save(name, list(exports.values()))
    return exports


def _save(name, export_objects):
    """Write art/blender/<name>.blend and art/models/<name>.glb (with vertex colours)."""
    os.makedirs(MODELS_DIR, exist_ok=True)
    bpy.context.view_layer.update()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, name + ".blend"), compress=True)
    for ob in bpy.context.scene.objects:
        ob.select_set(False)
    for ob in export_objects:
        ob.select_set(True)
    glb_path = os.path.join(MODELS_DIR, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_materials="EXPORT", export_tangents=False,
                              export_animations=False, export_vertex_color="ACTIVE",
                              export_active_vertex_color_when_no_material=True)
    tris = 0
    for o in export_objects:
        if o.type == "MESH":
            tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
    surfaces = sum(len(o.data.materials) for o in export_objects if o.type == "MESH")
    print(f"[wla] {name}: {len(export_objects)} nodes, {tris} triangles, {surfaces} surfaces -> {os.path.relpath(glb_path)}")
    return glb_path
