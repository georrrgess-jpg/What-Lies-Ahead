"""First-person model of the Jester's Jinglestar (jinglestar), the melee-slot
flail of Castle Kingdom: a court jester's morningstar. A harlequin-diamond
handle (motley purple and green with gold seams) with a gold pommel bell and
a felt ruff of jester points under a gold cap; a gold chain of LINKS links;
and a star-ball head: a striped motley jingle bell with a gold crown band,
gold star spikes tipped with tiny bells, and three motley ribbons ending in
gold tassel beads.

Melee contract (melee_kit.py): origin at the centre of the fist on the
handle, the handle along +Y with the chain and the head carrying on along +Y
(the model is laid out straight, so the Arsenal, Locker and thumbnails show
it side-on). The viewmodel (scripts/weapons/views/jinglestar_view.gd) poses
the chain and the head itself every frame from a simulated chain, so every
link and the head are their own nodes (not children of one another):

  Handle      the handle, grip wrap, pommel bell, ruff and cap (static)
  Link0..5    the chain's links, pivot at each link's centre, along +Y
  Head        the star-ball, pivot at its eye (where it hangs on the last link),
              the ball beyond it along +Y
  Ribbon<i>_<k>  ribbon i's segment k (pivot at its root, along -Y back over
              the chain), each a child of the one before it, the first a child
              of Head
  ArmR        the fist round the grip (hand_kit grip_hand, ElbowR, GripMain)

Empties: Muzzle and BladeTip (the far side of the ball), SwingPoint (the
ball's near side), ChainAnchor (the cap's eye, where Link0 hangs), CharmPoint
(a lug by the pommel, left side).

    python art/blender/build_weapons_jinglestar.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from melee_kit import *  # noqa: F401,F403
from weapon_kit import _finish_part, _spike  # noqa: E402

STICK_R = 0.02
## The hand at a human size against the handle (hand_kit grip_hand scale).
HAND_SCALE = 0.8
## A firm grip: the fingers press this share of their radius into the handle.
GRIP_SQUEEZE = 0.3
## The thumb's lie before it wraps (hand space): across the near side of the
## handle, leaning towards the head, as on a club.
THUMB_LIE = (1.0, -0.8, -0.4)
## The thumb at a human length.
THUMB_LEN_SCALE = 0.78
HANDLE_Y0 = -0.085
HANDLE_Y1 = 0.3
WRAP_Y0 = -0.08
WRAP_Y1 = 0.07
## The cap's eye (where the chain hangs) and the chain: LINKS links, LINK_PITCH apart.
EYE_Y = 0.322
LINKS = 6
LINK_PITCH = 0.034
## The head: its eye at the end of the chain, the ball's centre HEAD_OFFSET beyond.
HEAD_R = 0.05
HEAD_OFFSET = 0.062
SPIKE_LEN = 0.034
## Ribbons: how many, their segments and each segment's length.
RIBBONS = 3
RIBBON_SEGS = 3
RIBBON_SEG = 0.05


def palette():
    """The shared weapon materials in the jester's motley (weapon_mats reuses them)."""
    mat("Shell", "#8b3cf0", rough=0.35)
    mat("Trim", "#19c48a", rough=0.35)
    mat("GunDark", "#2a1d3a", rough=0.6, metal=0.05)
    mat("GunSteel", "#f6c544", rough=0.22, metal=0.85)
    mat("GunPink", "#ff5c8a", rough=0.4)


def harlequin(name, radius, y0, y1, around, rows, m_a, m_b, m_seam):
    """A round shaft along +Y tiled with harlequin diamonds: `around` diamonds
    round it, `rows` up it, the rows alternating m_a / m_b (each diamond's
    four neighbours are the other colour), with thin m_seam ridges along every
    diamond edge."""
    bm = bmesh.new()
    half = math.pi / around
    step = (y1 - y0) / rows
    rings = []
    for k in range(rows * 2 + 1):
        y = y0 + step * 0.5 * k
        off = half if k % 2 else 0.0
        rings.append([bm.verts.new((math.cos(off + 2 * half * j) * radius, y, math.sin(off + 2 * half * j) * radius)) for j in range(around)])
    faces = []
    # Diamond centred on ring k (odd), point j: top ring k+1 j, bottom ring k-1 j, sides ring k j and j-1.
    for k in range(1, rows * 2, 2):
        for j in range(around):
            top = rings[k + 1][j]
            bot = rings[k - 1][j]
            left = rings[k][(j - 1) % around]
            right = rings[k][j]
            faces.append((bm.faces.new((bot, right, top, left)), 0))
    # Half diamonds along the ends close the shaft (between ring 0 / ring 1 and the last two).
    for k in (0, rows * 2 - 1):
        a, b = rings[k], rings[k + 1]
        for j in range(around):
            if k == 0:
                faces.append((bm.faces.new((a[j], a[(j + 1) % around], b[j])), 1))
            else:
                faces.append((bm.faces.new((a[j], b[(j + 1) % around], b[j])), 1))
    # Diamonds centred on even rings (between the odd-ring diamonds) fill the rest.
    for k in range(2, rows * 2 - 1, 2):
        for j in range(around):
            top = rings[k + 1][j]
            bot = rings[k - 1][j]
            left = rings[k][j]
            right = rings[k][(j + 1) % around]
            faces.append((bm.faces.new((bot, right, top, left)), 1))
    for f, idx in faces:
        f.material_index = idx
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish_part(name, bm, m_a)
    ob.data.materials.append(m_b)
    for p in ob.data.polygons:
        p.use_smooth = False
    # Gold seams along every diamond edge: thin helical ridges either way round.
    seams = [ob]
    for sgn in (-1, 1):
        for j in range(around):
            pts = []
            for k in range(rows * 2 + 1):
                a = 2 * half * j + sgn * half * k
                pts.append((math.cos(a) * (radius + 0.0006), y0 + step * 0.5 * k, math.sin(a) * (radius + 0.0006)))
            seams.append(tube(f"{name}Seam{sgn}{j}", pts, 0.0011, m=m_seam, segs=5))
    return seams


def bell(name, radius, centre, axis, M, slot=True):
    """A gold jingle bell: a ball with a raised girdle and a slit mouth, axis along `axis`."""
    a = Vector(axis).normalized()
    c = Vector(centre)
    parts = [sphere(name, radius, c, m=M["steel"], segs=20, rings=12)]
    girdle = torus(name + "Girdle", radius * 1.0, radius * 0.11, m=M["steel"], major_segs=24, minor_segs=6)
    _orient(girdle, c, a)
    parts.append(girdle)
    if slot:
        # The mouth: a dark slit across the far half, ending in two round holes.
        far = c + a * radius * 0.45
        side = a.orthogonal().normalized()
        up = a.cross(side).normalized()
        parts.append(obox(name + "Slit", (radius * 1.3, radius * 0.16, radius * 0.5), far + a * radius * 0.25, side, up, bevel=0.0008, m=M["dark"]))
        for s in (-1, 1):
            parts.append(sphere(name + f"Hole{s}", radius * 0.17, far + side * s * radius * 0.62 + a * radius * 0.28, m=M["dark"], segs=10, rings=6))
    return parts


def _orient(ob, centre, axis):
    """Turns an object built round +Z so its Z runs along `axis`, centred on `centre`."""
    z = Vector(axis).normalized()
    x = z.orthogonal().normalized()
    y = z.cross(x)
    ob.matrix_world = Matrix(((x.x, y.x, z.x, centre[0]), (x.y, y.y, z.y, centre[1]), (x.z, y.z, z.z, centre[2]), (0, 0, 0, 1)))
    return ob


def link(name, y, turned, M):
    """One oval chain link centred at (0, y, 0) along +Y, its loop in the XY
    plane (turned: in the YZ plane), long enough to hang in its neighbours."""
    ob = torus(name, 0.012, 0.0036, m=M["steel"], major_segs=18, minor_segs=6)
    ob.scale = (0.8, 1.55, 1.0)
    ob.rotation_euler = rad(0, 90 if turned else 0, 0)
    ob.location = (0, y, 0)
    return ob


def ruff(prefix, y, M, m_cream):
    """The jester's ruff under the cap: eight felt points round the handle,
    alternating motley colours, each tipped with a gold bead, flaring down."""
    parts = []
    n = 8
    for i in range(n):
        a = math.tau * i / n
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        tip_dir = (out * 0.85 + Vector((0, -0.52, 0))).normalized()
        base = Vector((0, y, 0)) + out * (STICK_R + 0.004)
        m = M["shell"] if i % 2 == 0 else M["trim"]
        parts.append(_spike(f"{prefix}Point{i}", base, tip_dir, 0.012, 0.04, m, segs=6))
        parts.append(sphere(f"{prefix}Bead{i}", 0.0045, base + tip_dir * 0.042, m=M["steel"], segs=8, rings=5))
    parts.append(ycyl(prefix + "Collar", STICK_R + 0.006, 0.012, y + 0.002, m=m_cream, segs=20, bevel=0.003))
    return parts


def head_parts(M, m_cream):
    """The star-ball round its centre (0, 0, 0), its eye towards -Y: a motley
    bell striped in eight lobes, a gold crown band, six gold star spikes tipped
    with tiny bells, the eye's collar, and a big gold star boss on each face."""
    parts = []
    # The ball: eight lobes, alternating colours (a jester's ball).
    lobes = 8
    for i in range(lobes):
        a0 = math.tau * i / lobes
        bm = bmesh.new()
        rings_n, cols = 12, 4
        south = bm.verts.new((0, -HEAD_R, 0))
        north = bm.verts.new((0, HEAD_R, 0))
        grid = []
        for r_i in range(1, rings_n):
            v = math.pi * r_i / rings_n
            row = []
            for c_i in range(cols + 1):
                u = a0 + (math.tau / lobes) * c_i / cols
                rr = HEAD_R * (1.0 + 0.06 * math.sin(math.pi * c_i / cols) * math.sin(v))
                row.append(bm.verts.new((math.cos(u) * math.sin(v) * rr, -math.cos(v) * rr, math.sin(u) * math.sin(v) * rr)))
            grid.append(row)
        for c_i in range(cols):
            bm.faces.new((south, grid[0][c_i + 1], grid[0][c_i]))
            bm.faces.new((north, grid[-1][c_i], grid[-1][c_i + 1]))
        for r_i in range(rings_n - 2):
            for c_i in range(cols):
                bm.faces.new((grid[r_i][c_i], grid[r_i][c_i + 1], grid[r_i + 1][c_i + 1], grid[r_i + 1][c_i]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        parts.append(_finish_part(f"Lobe{i}", bm, M["shell"] if i % 2 == 0 else M["trim"]))
    # The crown band round the equator, with gold rivet beads.
    band_ = torus("Crown", HEAD_R * 1.04, 0.0045, m=M["steel"], major_segs=32, minor_segs=6)
    band_.rotation_euler = rad(90, 0, 0)
    parts.append(band_)
    for i in range(8):
        a = math.tau * (i + 0.5) / 8
        parts.append(sphere(f"Rivet{i}", 0.0035, (math.cos(a) * HEAD_R * 1.07, 0, math.sin(a) * HEAD_R * 1.07), m=M["steel"], segs=8, rings=5))
    # Star spikes: six round the waist, one out of the far end.
    dirs = []
    for i in range(6):
        a = math.tau * i / 6 + 0.26
        tilt = 0.28 if i % 2 else -0.18
        dirs.append(Vector((math.cos(a), tilt, math.sin(a))).normalized())
    dirs.append(Vector((0, 1, 0)))
    for i, d in enumerate(dirs):
        base = d * HEAD_R * 0.9
        parts.append(_spike(f"Spike{i}", base, d, 0.014, SPIKE_LEN, M["steel"], segs=8))
        tip = d * (HEAD_R * 0.9 + SPIKE_LEN + 0.004)
        parts.append(sphere(f"SpikeBell{i}", 0.0062, tip, m=M["steel"], segs=10, rings=6))
        parts.append(torus(f"SpikeBellGirdle{i}", 0.0062, 0.0011, tip, m=M["dark"], major_segs=12, minor_segs=4))
        _orient(parts[-1], tip, d)
    # A gold star boss on each flat face (+-Z), the jester's emblem.
    for s in (-1, 1):
        pts = []
        for k in range(10):
            a = math.tau * k / 10 + math.pi / 2
            r = 0.022 if k % 2 == 0 else 0.009
            pts.append((math.cos(a) * r, math.sin(a) * r))
        parts.append(prism(f"Star{s}", pts, 0.006, loc=(0, 0.004, s * HEAD_R * 1.03), rot=rad(90, 0, 0), m=M["cell"], bevel=0.0012))
    # The eye's collar and ring at the near pole, where it hangs on the last link.
    parts.append(ycyl("EyeCollar", 0.016, 0.012, -HEAD_R - 0.002, m=m_cream, segs=16, bevel=0.003))
    eye = torus("Eye", 0.0095, 0.0032, (0, -HEAD_OFFSET + 0.006, 0), m=M["steel"], major_segs=16, minor_segs=6)
    eye.rotation_euler = rad(0, 90, 0)
    parts.append(eye)
    return parts


def ribbon_segment(name, length, width, m, m_edge, taper=1.0, tassel=None, M=None):
    """A ribbon segment from its root (0, 0, 0) down -Y: a thin strip with a
    gold edge, `taper` of its width at the far end, a tassel bead on the last."""
    w0, w1 = width, width * taper
    pts = [(-w0 / 2, 0.0), (w0 / 2, 0.0), (w1 / 2, -length), (-w1 / 2, -length)]
    bm = bmesh.new()
    t = 0.0016
    top = [bm.verts.new((x, y, t)) for x, y in pts]
    bot = [bm.verts.new((x, y, -t)) for x, y in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((top[i], top[j], bot[j], bot[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    parts = [_finish_part(name, bm, m)]
    parts.append(tube(name + "Edge", [(-w0 / 2, 0, 0), (-w1 / 2, -length, 0)], 0.0012, m=m_edge, segs=5))
    parts.append(tube(name + "Edge2", [(w0 / 2, 0, 0), (w1 / 2, -length, 0)], 0.0012, m=m_edge, segs=5))
    if tassel:
        parts.append(sphere(name + "Bead", 0.0058, (0, -length - 0.003, 0), m=M["steel"], segs=10, rings=6))
        for k in range(5):
            a = -0.5 + k * 0.25
            parts.append(tube(name + f"Thread{k}", [(0, -length - 0.006, 0), (math.sin(a) * 0.006, -length - 0.022, math.cos(a) * 0.003)],
                              0.0011, m=tassel, segs=4))
    return parts


def build_jinglestar():
    reset_scene()
    palette()
    M = weapon_mats("#ffd257", emit=2.2)
    cream = mat("Felt", "#fff1d6", rough=0.7)
    pink = M["pink"]

    # Handle: harlequin diamonds above the grip, the grip wrap, the pommel bell.
    handle = harlequin("Motley", STICK_R, WRAP_Y1 + 0.004, HANDLE_Y1 - 0.004, 6, 5, M["shell"], M["trim"], M["steel"])
    handle += [
        ycyl("Core", STICK_R - 0.0008, HANDLE_Y1 - HANDLE_Y0, (HANDLE_Y0 + HANDLE_Y1) / 2, m=M["dark"], segs=20, bevel=0.002),
        ycyl("Wrap", STICK_R + 0.0028, WRAP_Y1 - WRAP_Y0, (WRAP_Y0 + WRAP_Y1) / 2, m=M["dark"], segs=20, bevel=0.002),
        ring("WrapEnd0", STICK_R + 0.0034, 0.0036, WRAP_Y1, m=M["steel"], segs=20),
        ring("WrapEnd1", STICK_R + 0.0034, 0.0036, WRAP_Y0, m=M["steel"], segs=20),
        ring("TopBand", STICK_R + 0.002, 0.003, HANDLE_Y1 - 0.004, m=M["steel"], segs=20),
    ]
    for k in range(9):
        y = WRAP_Y0 + 0.012 + k * 0.0155
        handle.append(ring(f"WrapRib{k}", STICK_R + 0.0031, 0.0011, y, m=M["shell"] if k % 2 else M["trim"], segs=18))
    # Pommel: a gold collar and a big jingle bell.
    handle.append(ycyl("PommelCollar", STICK_R + 0.004, 0.012, HANDLE_Y0 - 0.002, m=M["steel"], segs=20, bevel=0.003))
    handle += bell("PommelBell", 0.03, (0, HANDLE_Y0 - 0.034, 0), (0, -1, 0), M)
    # The ruff and the cap with its eye.
    handle += ruff("Ruff", HANDLE_Y1 - 0.012, M, cream)
    handle.append(sphere("Cap", 0.022, (0, HANDLE_Y1 + 0.004, 0), scale=(1, 0.7, 1), m=M["steel"], segs=18, rings=10))
    eye = torus("CapEye", 0.008, 0.003, (0, EYE_Y - 0.004, 0), m=M["steel"], major_segs=16, minor_segs=6)
    eye.rotation_euler = rad(0, 90, 0)
    handle.append(eye)

    lug, charm_point = melee_lug(-STICK_R - 0.002, HANDLE_Y0 + 0.006, 0.0, M)
    handle += lug

    # The chain: links hanging one from the next straight out of the cap's eye.
    groups = {"Handle": (handle, (0, 0, 0), None)}
    for i in range(LINKS):
        y = EYE_Y + LINK_PITCH * (i + 0.5)
        groups[f"Link{i}"] = ([link(f"LinkMesh{i}", y, i % 2 == 0, M)], (0, y, 0), None)

    # The head beyond the last link: its eye on the chain's end.
    head_eye = EYE_Y + LINK_PITCH * LINKS
    centre = head_eye + HEAD_OFFSET
    hp = head_parts(M, cream)
    for ob in hp:
        ob.matrix_world = Matrix.Translation((0, centre, 0)) @ ob.matrix_world
    groups["Head"] = (hp, (0, head_eye, 0), None)

    # Ribbons: tied at the eye collar, laid back along the chain (-Y) in a fan.
    colours = [M["shell"], M["trim"], pink]
    for i in range(RIBBONS):
        a = math.tau * i / RIBBONS + 0.4
        root = Vector((math.cos(a) * 0.012, centre - HEAD_R - 0.004, math.sin(a) * 0.012))
        parent = "Head"
        for k in range(RIBBON_SEGS):
            name = f"Ribbon{i}_{k}"
            last = k == RIBBON_SEGS - 1
            seg = ribbon_segment(name + "Mesh", RIBBON_SEG, 0.016 * (1.0 - 0.18 * k), colours[i], M["steel"], taper=0.82,
                                 tassel=M["steel"] if last else None, M=M)
            pivot = root + Vector((0, -RIBBON_SEG * k, 0))
            for ob in seg:
                ob.matrix_world = Matrix.Translation(pivot) @ Matrix.Rotation(a, 4, "Y") @ ob.matrix_world
            groups[name] = (seg, pivot, parent)
            parent = name

    # The articulated hand closed round the grip wrap (hand_kit.py), at a human size,
    # exactly as the Swirl Smasher: the hold (jinglestar.tres: 0.34, -0.27, -0.62 at
    # 62, 14, -18 degrees) with the right elbow at 0.68, -0.42, -0.08 in view space
    # puts the forearm back towards the camera, down and to the right (pose.py: 130
    # degrees to the handle). The thumb wraps the near side, the fingertips the far side.
    grip = [cylinder_sdf((0, 0, 0), (0, 1, 0), STICK_R + 0.0028 + 0.0012)]
    hand = grip_hand("R", (0, 0, 0), (0, 1, 0), (0.070, -0.636, 0.768), M, grip, scale=HAND_SCALE, squeeze=GRIP_SQUEEZE,
                     thumb_wrap=True, thumb_dir=THUMB_LIE, thumb_len=THUMB_LEN_SCALE)
    far = centre + HEAD_R + SPIKE_LEN
    empties = {
        "Muzzle": ((0, far, 0), "Head"),
        "BladeTip": ((0, far, 0), "Head"),
        "SwingPoint": ((0, centre - HEAD_R * 0.5, 0), "Head"),
        "ChainAnchor": ((0, EYE_Y, 0), "Handle"),
        "CharmPoint": (charm_point, "Handle"),
    }
    add_hand(groups, empties, hand, "GripMain", "Handle")
    finish("jinglestar", groups, empties)


if __name__ == "__main__":
    build_jinglestar()
