"""Shared clip authoring for every zombie rig (all fifteen enemies).

Every zombie model uses the same 11-bone rigid-part rig (built by
build_zombie.build_armature and its neon copy):

    Hips > Spine > Head, Spine > UpperArm.L/R > ForeArm.L/R,
    Hips > Thigh.L/R > Shin.L/R

This module owns all of their motion. It turns short motion descriptions into
baked Blender actions:

  * analytic two-bone IK for legs and arms: planted feet stay put on the
    ground (with a heel/toe rocker, since the feet are welded to the shins)
    and hands reach exact points;
  * parametric gaits (`Gait`): walk/run cycles keyed from foot targets, whose
    natural ground speed is derived from the stride;
  * a clip library: idles, attacks, spit, roar, stagger, hit, deaths (back,
    front, spin, heavy, head pop), emerge and the world specials;
  * one clip set per model file (`boardwalk_clips`, `punk_clips`, ...).

Builders call one function after skinning their meshes:

    zombie_anim.bake(armature, zombie_anim.boardwalk_clips, "zombie")

which writes the actions (exported with the .glb) and
art/models/<name>_clips.tres, a table the game reads for each clip's natural
ground speed, length and event times (strike, release, impact, head pop).

Conventions (armature space, as the builders): +X is the zombie's left, -Y
its front, +Z up, 1 unit = 1 m before the game's body_scale. A *pose spec* is
a dict:

    "Hips", "Spine", ... : (rx, ry, rz) Euler degrees in armature axes,
                           relative to the parent bone (rx > 0 leans an
                           upright bone forward and swings a hanging limb
                           back; ry rolls; rz turns left)
    "hips"               : hips offset (left, forward, up) in metres
    "foot.L" / "foot.R"  : ankle (shin tail) target (left, forward, up); the
                           leg is solved by IK, knee toward "knee.L" (a
                           direction, default forward)
    "hand.L" / "hand.R"  : wrist (forearm tail) target (left, forward, up),
                           elbow toward "elbow.L" (default out, back, down)
    "scale.Head"         : uniform bone scale (the head pop)

Clips are lists of keys `(frame, spec_changes, ease)`; each key only lists
what changes from the key before (see `keyed`).
"""
import math
import os

import bpy  # noqa: F401  (must be imported before mathutils with the PyPI module)
from mathutils import Matrix, Quaternion, Vector

FPS = 24          # clips are authored in 24 fps frames...
SUB = 2           # ...and baked at FPS * SUB samples per second
KEY_FPS = FPS * SUB
HERE = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.normpath(os.path.join(HERE, "..", "models"))

SIDES = (("L", 1.0), ("R", -1.0))
LEG = {"L": ("Thigh.L", "Shin.L"), "R": ("Thigh.R", "Shin.R")}
ARM = {"L": ("UpperArm.L", "ForeArm.L"), "R": ("UpperArm.R", "ForeArm.R")}
# Feet are welded to the shins: heel this far behind the ankle, toe tip this
# far ahead, sole this far below the shin tail (shoe and boot builds agree).
FOOT = (0.13, 0.28, 0.055)
REST_ANKLE = 0.06


def B(left, forward, up):
    """Body coordinates (left, forward, up) -> armature space (front is -Y)."""
    return Vector((left, -forward, up))


def euler_q(rx, ry, rz):
    """Euler degrees (armature axes, XYZ order) -> quaternion."""
    from mathutils import Euler
    return Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_quaternion()


# ---------------------------------------------------------------------------
# Rig: rest data, forward kinematics, two-bone IK
# ---------------------------------------------------------------------------

class Rig:
    """Rest data of a zombie armature with forward kinematics in armature space.

    A bone's world delta W[b] = W[parent] @ q[b]; its head sits at
    pos[parent] + W[parent] @ (rest_head[b] - rest_head[parent]). This is the
    exact convention `bake` keys (rotation = rest^-1 @ q @ rest)."""

    def __init__(self, armature):
        self.head, self.tail, self.parent, self.rest = {}, {}, {}, {}
        for b in armature.data.bones:
            self.head[b.name] = b.head_local.copy()
            self.tail[b.name] = b.tail_local.copy()
            self.parent[b.name] = b.parent.name if b.parent else None
            self.rest[b.name] = b.matrix_local.to_quaternion()
        self.order = []
        while len(self.order) < len(self.head):
            for name, parent in self.parent.items():
                if name not in self.order and (parent is None or parent in self.order):
                    self.order.append(name)
        self.hip_height = self.head["Hips"].z
        thigh, shin = LEG["L"]
        self.leg_length = self.length(thigh) + self.length(shin)

    def length(self, bone):
        return (self.tail[bone] - self.head[bone]).length

    def fk(self, rot, hips):
        """Posed head positions and world delta rotations for `rot` (bone ->
        Quaternion) with the Hips moved by `hips` (armature space)."""
        pos, world = {}, {}
        for b in self.order:
            p = self.parent[b]
            q = rot.get(b, Quaternion())
            if p is None:
                world[b] = q
                pos[b] = self.head[b] + hips
            else:
                world[b] = world[p] @ q
                pos[b] = pos[p] + world[p] @ (self.head[b] - self.head[p])
        return pos, world

    def point(self, pos, world, bone, rest_point):
        """Where a point fixed to `bone` (given at rest) is in the posed rig."""
        return pos[bone] + world[bone] @ (rest_point - self.head[bone])

    def two_bone(self, pos, world, upper, lower, target, pole, rest_pole):
        """Rotations (upper, lower, middle joint) that put `lower`'s tail on
        `target`, bending toward `pole`. `rest_pole` is the bend direction the
        chain's rest frame is measured against (forward for knees, back for
        elbows), so the result is the identity at rest."""
        j = pos[upper]
        l1, l2 = self.length(upper), self.length(lower)
        d = target - j
        dist = min(max(d.length, abs(l1 - l2) + 1e-4), (l1 + l2) * 0.9999)
        dn = d.normalized() if d.length > 1e-6 else Vector((0, 0, -1))
        pp = pole - dn * pole.dot(dn)
        if pp.length < 1e-5:
            pp = Vector((0, -1, 0)) - dn * (-dn.y)
        pp.normalize()
        cos_a = max(-1.0, min(1.0, (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)))
        sin_a = math.sqrt(max(0.0, 1.0 - cos_a * cos_a))
        mid = j + dn * (l1 * cos_a) + pp * (l1 * sin_a)
        end = j + dn * dist
        hinge = dn.cross(pp).normalized()
        rest_d = self.tail[lower] - self.head[upper]
        rest_dn = rest_d.normalized()
        rest_pp = rest_pole - rest_dn * rest_pole.dot(rest_dn)
        rest_hinge = rest_dn.cross(rest_pp.normalized()).normalized()
        w_upper = _frame(hinge, (mid - j).normalized()) @ _frame(rest_hinge, (self.tail[upper] - self.head[upper]).normalized()).inverted()
        w_lower = _frame(hinge, (end - mid).normalized()) @ _frame(rest_hinge, (self.tail[lower] - self.head[lower]).normalized()).inverted()
        wu, wl = w_upper.to_quaternion(), w_lower.to_quaternion()
        parent = self.parent[upper]
        q_upper = world[parent].inverted() @ wu
        q_lower = wu.inverted() @ wl
        return q_upper, q_lower, mid


def _frame(x_axis, y_axis):
    """Rotation matrix with columns (x, y, x cross y), x orthogonalised to y."""
    y = y_axis.normalized()
    x = (x_axis - y * x_axis.dot(y)).normalized()
    z = x.cross(y)
    return Matrix((x, y, z)).transposed()


# ---------------------------------------------------------------------------
# Pose specs
# ---------------------------------------------------------------------------

class Pose:
    """A resolved pose: bone rotations (armature-axes deltas), hips offset and
    bone scales."""

    def __init__(self, rot, hips, scale):
        self.rot, self.hips, self.scale = rot, hips, scale


KNEE_POLE = (0.12, 1.0, 0.0)


def elbow_pole(side):
    return (side * 0.75, -0.55, -0.35)


def resolve(rig, spec, plant=False):
    """Turn a pose spec (see the module notes) into a Pose (FK + IK). With
    `plant`, a foot target at ground height (REST_ANKLE) is a planted foot:
    its ankle rises on the heel/toe rocker as the shin tilts, so the sole
    never sinks into the ground. With spec["flat"] (skis bound to the shins)
    each foot instead goes wherever keeps its shin upright under the knee, so
    the ski lies flat; the feet slide (glide) as the hips move."""
    rot = {}
    for b in rig.order:
        e = spec.get(b)
        rot[b] = euler_q(*e) if e is not None else Quaternion()
    hips = B(*spec.get("hips", (0, 0, 0)))
    pos, world = rig.fk(rot, hips)
    for s, side in SIDES:
        if "foot." + s in spec:
            thigh, shin = LEG[s]
            target = B(*spec["foot." + s])
            if spec.get("flat", 0.0) > 0.5:
                target = _flat_ankle(rig, pos, thigh, shin, target)
            elif plant and target.z <= REST_ANKLE + 0.003:
                target, _, _ = _stance_ankle(rig, pos, world, s, side, -target.y - FOOT[0], target.x, FOOT)
            elif plant:
                # A lifted foot never dips its toe or heel into the ground.
                for _ in range(2):
                    theta, _ = _shin_pitch(rig, pos, world, s, target, side)
                    hb, tf, sd = FOOT
                    low = target.z + min(-tf * math.sin(theta) - sd * math.cos(theta), hb * math.sin(theta) - sd * math.cos(theta))
                    if low >= 0.0:
                        break
                    target = target + Vector((0, 0, -low))
            kp = spec.get("knee." + s, (KNEE_POLE[0] * side, KNEE_POLE[1], KNEE_POLE[2]))
            rot[thigh], rot[shin], _ = rig.two_bone(pos, world, thigh, shin, target, B(*kp), Vector((0, -1, 0)))
    pos, world = rig.fk(rot, hips)
    for s, side in SIDES:
        if "hand." + s in spec:
            upper, fore = ARM[s]
            ep = spec.get("elbow." + s, elbow_pole(side))
            rot[upper], rot[fore], _ = rig.two_bone(pos, world, upper, fore, B(*spec["hand." + s]), B(*ep), Vector((0, 1, 0)))
    scale = {k[6:]: v for k, v in spec.items() if k.startswith("scale.")}
    return Pose(rot, hips, scale)


def _flat_ankle(rig, pos, thigh, shin, target):
    """The ankle at `target`'s height and side, moved forward or back so the
    shin stands upright with the knee right above it (skis stay flat)."""
    l1, l2 = rig.length(thigh), rig.length(shin)
    hip = pos[thigh]
    dz = hip.z - (target.z + l2)
    dx = math.sqrt(max(0.0, (l1 * 0.995) ** 2 - dz * dz))
    return Vector((target.x, hip.y - dx, target.z))


def feet(spread=0.16, l_fwd=0.0, r_fwd=0.0, l_up=REST_ANKLE, r_up=REST_ANKLE, r_spread=None):
    """Planted ankle targets for both feet."""
    rs = spread if r_spread is None else r_spread
    return {"foot.L": (spread, l_fwd, l_up), "foot.R": (-rs, r_fwd, r_up)}


def arms(lu, lf, ru, rf, spread=10.0):
    """FK arm pose shorthand: upper/fore swing in degrees (negative = forward),
    `spread` rolls both arms outward."""
    return {"UpperArm.L": (lu, -spread, 0), "ForeArm.L": (lf, 0, 0),
            "UpperArm.R": (ru, spread, 0), "ForeArm.R": (rf, 0, 0)}


def mirror(spec):
    """Left/right mirror of a pose spec (for directional variants)."""
    out = {}
    for k, v in spec.items():
        if k.endswith(".L") or k.endswith(".R"):
            k2 = k[:-1] + ("R" if k.endswith("L") else "L")
        else:
            k2 = k
        if k2 in ("hips",) or k2.startswith(("foot.", "hand.", "knee.", "elbow.")):
            v = (-v[0], v[1], v[2])
        elif isinstance(v, tuple) and len(v) == 3:
            v = (v[0], -v[1], -v[2])
        out[k2] = v
    return out


# ---------------------------------------------------------------------------
# Easing and keyed clips
# ---------------------------------------------------------------------------

def _ease(kind, t):
    if kind == "lin":
        return t
    if kind == "in":
        return t * t
    if kind == "out":
        return 1 - (1 - t) * (1 - t)
    if kind == "snap":       # very fast out: strikes
        return 1 - (1 - t) ** 3
    if kind == "back":       # overshoot then settle
        c = 1.9
        return 1 + (c + 1) * (t - 1) ** 3 + c * (t - 1) ** 2
    if kind == "hold":
        return 0.0
    return t * t * (3 - 2 * t)  # "io"


def _mix(a, b, t):
    if isinstance(a, tuple):
        return tuple(x + (y - x) * t for x, y in zip(a, b))
    return a + (b - a) * t


class Clip:
    """A baked clip: per-frame poses plus metadata for the game's table
    (`speed` m/s at 1x for gaits, event times in seconds)."""

    def __init__(self, name, poses, loop=False, **meta):
        self.name = name + ("-loop" if loop else "")
        self.poses = poses
        self.meta = meta
        self.meta["length"] = round((len(poses) - 1) / KEY_FPS, 4)


def keyed(rig, name, keys, loop=False, plant=True, flat=False, **meta):
    """Dense clip from sparse keys. `keys` is a list of (frame, changes) or
    (frame, changes, ease); each key's spec is the previous key's spec updated
    with `changes`, and the segment arriving at a key uses its ease ("io" by
    default; "lin", "in", "out", "snap", "back", "hold"). Feet targeted at
    ground height are planted (see `resolve`)."""
    specs, frames, eases = [], [], []
    current = {"flat": 1.0} if flat else {}
    for k in keys:
        frame, changes = k[0], k[1]
        ease = k[2] if len(k) > 2 else "io"
        current = dict(current)
        current.update(changes)
        specs.append(current)
        frames.append(frame)
        eases.append(ease)
    for s in specs[1:]:
        missing = set(s) - set(specs[0])
        assert not missing, f"{name}: keys add {missing} not set at the first key"
    poses = []
    for k in range(frames[-1] * SUB + 1):
        f = k / SUB
        i = 0
        while i < len(frames) - 1 and frames[i + 1] < f:
            i += 1
        if f <= frames[0]:
            spec = specs[0]
        else:
            f0, f1 = frames[i], frames[i + 1]
            t = _ease(eases[i + 1], (f - f0) / max(1, f1 - f0))
            a, b = specs[i], specs[i + 1]
            spec = {k: _mix(a[k], b[k], t) for k in a}
        poses.append(resolve(rig, spec, plant))
    return Clip(name, poses, loop=loop, **meta)


# ---------------------------------------------------------------------------
# Gaits: walk and run cycles from foot targets
# ---------------------------------------------------------------------------

class Gait:
    """A walk/run cycle. Each foot is planted for `duty` of the cycle and
    travels `stance` metres back relative to the hips meanwhile, so the clip's
    natural ground speed is stance / (duty * period). The hips drop just
    enough for the legs to reach both ends of the stance (plus `crouch`).

    torso(phase) returns the spec for Hips/Spine/Head/arms (phase 0 = left
    heel strike); `bob` and `bob_style` ("walk": high at mid-stance, "run":
    low at mid-stance, "stomp": drops hard on contact) move the hips up and
    down; `limp` (0-1) drags the right foot; `glide` floats both feet (hover
    boots) and `skate` glides each planted foot forward then pushes it out."""

    def __init__(self, period, duty, stance, lift, torso, front=0.5, width=0.0, crouch=0.0, bob=0.03,
                 bob_style="walk", limp=0.0, glide=0.0, skate=0.0, foot=FOOT, profile=None):
        self.period, self.duty, self.stance, self.lift = period, duty, stance, lift
        self.torso, self.front, self.width, self.crouch = torso, front, width, crouch
        self.bob, self.bob_style, self.limp, self.glide, self.skate = bob, bob_style, limp, glide, skate
        self.foot, self.profile = foot, profile
        self.frames = max(16, round(period * KEY_FPS))
        self.period = self.frames / KEY_FPS

    @property
    def speed(self):
        """Natural ground speed (m/s at 1x, before body_scale)."""
        return self.stance / (self.duty * self.period)

    def bob_at(self, ph):
        d = self.duty / 2
        if self.bob_style == "run":
            return -self.bob * math.cos(4 * math.pi * (ph - d))
        if self.bob_style == "stomp":
            # Each step: the body drops hard just after the heel lands, then
            # slowly heaves back up.
            h = (ph * 2) % 1.0
            k = math.sin(0.5 * math.pi * h / 0.12) if h < 0.12 else 0.5 * (1 + math.cos(math.pi * (h - 0.12) / 0.88))
            return self.bob * (0.5 - k)
        return self.bob * math.cos(4 * math.pi * (ph - d))


def _foot_offsets(theta, foot, toe):
    """Ankle offset (forward, up) from the contact point (heel or toe) for a
    shin pitch `theta` (toe down > 0)."""
    hb, tf, sd = foot
    c, s = math.cos(theta), math.sin(theta)
    if toe:
        return -tf * c + sd * s, tf * s + sd * c
    return hb * c + sd * s, -hb * s + sd * c


def _shin_pitch(rig, pos, world, s, ankle, side):
    thigh, shin = LEG[s]
    kp = B(KNEE_POLE[0] * side, KNEE_POLE[1], KNEE_POLE[2])
    _, _, knee = rig.two_bone(pos, world, thigh, shin, ankle, kp, Vector((0, -1, 0)))
    v = ankle - knee
    return math.atan2(v.y, -v.z), (ankle - pos[thigh]).length   # forward = -y; toe down when knee ahead


def _stance_ankle(rig, pos, world, s, side, heel_f, lat, foot):
    """Ankle on a rolling rigid foot whose heel (toe up) or toe (toe down) is
    fixed at forward position heel_f (toe tip at heel_f + heel + toe)."""
    hb, tf, _ = foot

    def ankle_at(theta):
        toe = theta > 0
        of, ou = _foot_offsets(theta, foot, toe)
        return B(lat, heel_f + (hb + tf if toe else 0.0) + of, ou)

    # The shin pitch the IK gives must equal the pitch the ankle was placed
    # for: bisect on that fixed point (plain iteration oscillates in squats).
    lo, hi = -1.3, 1.3
    g_lo = _shin_pitch(rig, pos, world, s, ankle_at(lo), side)[0] - lo
    for _ in range(22):
        mid = 0.5 * (lo + hi)
        g_mid = _shin_pitch(rig, pos, world, s, ankle_at(mid), side)[0] - mid
        if (g_mid > 0) == (g_lo > 0):
            lo, g_lo = mid, g_mid
        else:
            hi = mid
    theta = 0.5 * (lo + hi)
    ankle = ankle_at(theta)
    _, reach = _shin_pitch(rig, pos, world, s, ankle, side)
    return ankle, theta, reach


def _torso_pose(rig, g, ph, drop):
    spec = g.torso(ph)
    hl = spec.get("hips", (0, 0, 0))
    spec = dict(spec)
    spec["hips"] = (hl[0], hl[1], hl[2] - drop - g.crouch + g.bob_at(ph) + g.glide)
    rot = {b: euler_q(*spec[b]) if b in spec else Quaternion() for b in rig.order}
    pos, world = rig.fk(rot, B(*spec["hips"]))
    return spec, pos, world


def _leg_state(rig, g, s, side, ph, drop):
    """Ankle target for one leg at cycle phase `ph` (stance only; None in swing)
    and the leg's reach ratio."""
    off = 0.0 if s == "L" else 0.5
    p = (ph + off) % 1.0
    if p >= g.duty:
        return None, 0.0
    u = p / g.duty
    lat = side * (abs(rig.head[LEG[s][0]].x) + g.width)
    # Skating: the planted foot glides along with the body (it only falls
    # back by stance * (1 - skate)) and pushes out sideways.
    travel = g.stance * (1 - g.skate)
    heel_f = travel * g.front - u * travel - g.foot[0]
    if g.skate:
        lat += side * g.skate * 0.22 * u * u
    spec, pos, world = _torso_pose(rig, g, ph, drop)
    ankle, _, reach = _stance_ankle(rig, pos, world, s, side, heel_f, lat, g.foot)
    if g.glide:
        ankle = ankle + Vector((0, 0, g.glide))
    return ankle, reach / rig.leg_length


def _auto_drop(rig, g):
    """Smallest hips drop that keeps every planted leg slightly bent."""
    def worst(drop):
        w = 0.0
        for i in range(g.frames):
            ph = i / g.frames
            for s, side in SIDES:
                _, r = _leg_state(rig, g, s, side, ph, drop)
                w = max(w, r)
        return w
    lo, hi = 0.0, 0.45
    if worst(lo) <= 0.975:
        return lo
    for _ in range(14):
        mid = (lo + hi) / 2
        if worst(mid) > 0.975:
            lo = mid
        else:
            hi = mid
    return hi


def _swing(p0, p1, slope, u):
    """From p0 to p1 over u in [0, 1] with d/du = slope throughout the first
    5% and the last 20% (the foot peels off, and comes down, at rest relative
    to the ground) and the rest of the travel eased in and out between."""
    w = min(1.0, max(0.0, (u - 0.05) / 0.75))
    s5 = w * w * w * (w * (6 * w - 15) + 10)
    return p0 + slope * u + (p1 - p0 - slope) * s5


def gait(rig, name, g, **meta):
    """Bake a looping gait clip. Its natural ground speed (m/s at 1x, before
    body_scale) is stored as meta["speed"]."""
    drop = _auto_drop(rig, g)
    n = g.frames
    # Ankle positions at lift-off and touchdown for each leg, for the swings.
    ends = {}
    for s, side in SIDES:
        off = 0.0 if s == "L" else 0.5
        td_ph = (0.0 - off) % 1.0
        lo_ph = (g.duty - 1e-6 - off) % 1.0
        ends[s] = (_leg_state(rig, g, s, side, lo_ph, drop)[0], _leg_state(rig, g, s, side, td_ph, drop)[0])
    v = g.speed
    t_swing = (1 - g.duty) * g.period
    poses = []
    for i in range(n + 1):
        ph = (i % n) / n
        spec, pos, world = _torso_pose(rig, g, ph, drop)
        for s, side in SIDES:
            ankle, _ = _leg_state(rig, g, s, side, ph, drop)
            if ankle is None:
                off = 0.0 if s == "L" else 0.5
                p = (ph + off) % 1.0
                u = (p - g.duty) / (1 - g.duty)
                a0, a1 = ends[s]
                # The swing foot leaves and meets the ground at rest relative
                # to the ground (body-frame slope -v at both ends), with the
                # forward travel eased in and out (smootherstep).
                slope = -v * t_swing * (1 - g.skate)
                fwd = _swing(-a0.y, -a1.y, slope, u)
                lift = g.lift * (1 - (g.limp if s == "R" else 0.0))
                bump = math.sin(math.pi * u ** 0.75)
                up = a0.z + (a1.z - a0.z) * u + lift * bump
                lat = a0.x + (a1.x - a0.x) * u
                if g.skate:
                    lat -= side * g.skate * 0.2 * math.sin(math.pi * u)
                ankle = B(lat, fwd, up)
                # Keep the toe and heel clear of the ground through the swing.
                need = g.glide + 0.035 * math.sqrt(math.sin(math.pi * u))
                for _ in range(3):
                    theta, _ = _shin_pitch(rig, pos, world, s, ankle, side)
                    hb, tf, sd = g.foot
                    low = min(-tf * math.sin(theta) - sd * math.cos(theta), hb * math.sin(theta) - sd * math.cos(theta))
                    clear = ankle.z + low - need
                    if clear >= 0:
                        break
                    ankle = ankle + Vector((0, 0, -clear))
            spec["foot." + s] = (ankle.x, -ankle.y, ankle.z)
        poses.append(resolve(rig, spec))
    meta = dict(meta)
    meta.setdefault("speed", round(v, 4))
    if g.profile:
        meta["profile"] = g.profile
    print(f"[anim]   {name}: {g.frames} frames, stance {g.stance:.2f} m, hips drop {drop + g.crouch:.3f} m, "
          f"ground speed {v:.2f} m/s")
    return Clip(name, poses, loop=True, **meta)


# ---------------------------------------------------------------------------
# Baking
# ---------------------------------------------------------------------------

def bake(armature, clipset, model_name):
    """Key every clip of `clipset(rig)` as its own action (stored on an NLA
    track so all are exported), leave the rig at rest and write the clip table
    art/models/<model_name>_clips.tres. Returns the clips. The scene is set
    to KEY_FPS so the export samples every baked pose."""
    rig = Rig(armature)
    clips = clipset(rig)
    bpy.context.scene.render.fps = KEY_FPS
    ad = armature.animation_data_create()
    for clip in clips:
        action = bpy.data.actions.new(clip.name)
        ad.action = action
        for frame, pose in enumerate(clip.poses):
            _key_pose(armature, frame, pose)
        track = ad.nla_tracks.new()
        track.name = clip.name
        track.strips.new(clip.name, 0, action)
        ad.action = None
    for pb in armature.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
    write_table(model_name, clips)
    return clips


def _key_pose(armature, frame, pose):
    for pb in armature.pose.bones:
        rest = pb.bone.matrix_local.to_quaternion()
        q = pose.rot.get(pb.name, Quaternion())
        pb.rotation_quaternion = rest.inverted() @ q @ rest
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        s = pose.scale.get(pb.name, 1.0)
        pb.scale = (s, s, s)
        pb.keyframe_insert("scale", frame=frame)
        if pb.parent is None:
            pb.location = rest.inverted() @ pose.hips
            pb.keyframe_insert("location", frame=frame)


def write_table(model_name, clips):
    """art/models/<model_name>_clips.tres: a Resource whose "clips" metadata
    maps each clip's name in Godot to {length, speed?, profile?, strike?, ...}
    (Godot's importer drops the "-loop" suffix and marks the clip looping)."""
    lines = ["[gd_resource type=\"Resource\" format=3]", "", "[resource]"]
    entries = []
    for c in clips:
        fields = []
        for k in sorted(c.meta):
            v = c.meta[k]
            if isinstance(v, (list, tuple)):
                v = "[" + ", ".join(f"{x:.4g}" for x in v) + "]"
            else:
                v = f"{v:.4g}"
            fields.append(f"\"{k}\": {v}")
        entries.append(f"\"{c.name.removesuffix('-loop')}\": {{{', '.join(fields)}}}")
    lines.append("metadata/clips = {\n" + ",\n".join(entries) + "\n}")
    path = os.path.join(MODELS_DIR, model_name + "_clips.tres")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    speeds = ", ".join(f"{c.name}={c.meta['speed']:.2f}" for c in clips if "speed" in c.meta)
    print(f"[anim] {model_name}: {len(clips)} clips; ground speeds {speeds}")


# ---------------------------------------------------------------------------
# Gait styles
# ---------------------------------------------------------------------------

def _cs(ph, shift=0.0):
    a = math.tau * (ph - shift)
    return math.cos(a), math.sin(a)


def arms_reach(lift=0.0, sway=8.0):
    """Classic zombie reach: both arms out front, swaying out of step."""
    def fn(ph):
        c, s = _cs(ph)
        return arms(-76 - lift + sway * c, -14 - 8 * s, -62 - lift - sway * c, -24 + 8 * s, spread=8)
    return fn


def arms_pump(swing=45.0, bend=-85.0, base=-12.0):
    """Athletic arm pump (elbows bent), opposite to the legs."""
    def fn(ph):
        c, _ = _cs(ph)
        return arms(base + swing * c, bend + 10 * c, base - swing * c, bend - 10 * c, spread=14)
    return fn


def arms_heavy(swing=18.0):
    """Big arms hanging off the shoulders, swinging with the stride."""
    def fn(ph):
        c, s = _cs(ph)
        return arms(-16 + swing * c, -28 - 6 * s, -16 - swing * c, -28 + 6 * s, spread=16)
    return fn


def walker(duty, lean=14.0, hips_pitch=6.0, yaw=7.0, roll=4.0, sway=0.03, twist=1.6, head=-10.0, loll=6.0,
           arms_fn=None, lurch=0.0, shoulder_roll=0.0):
    """Torso for walks: pelvis turns with the leading leg, drops on the swing
    side and shifts over the planted foot; the chest counter-twists; the head
    lolls a beat behind (a zombie tell). `lurch` dips toward the right leg."""
    arms_fn = arms_fn or arms_reach()
    mid = duty / 2

    def torso(ph):
        c, s = _cs(ph)
        cm, _ = _cs(ph, mid)
        cl, sl = _cs(ph, 0.08)
        dip = lurch * max(0.0, -cm)
        spec = {
            "Hips": (hips_pitch + 2 * dip, -roll * cm - 4 * dip, -yaw * c),
            "Spine": (lean + 3 * dip, 0.5 * roll * cm + shoulder_roll * cm + 3 * dip, yaw * twist * c),
            "Head": (head - (lean - 12) * 0.6, loll * cl + 4 * dip, 0.6 * loll * sl),
            "hips": (sway * cm, 0.0, -0.02 * dip),
        }
        spec.update(arms_fn(ph))
        return spec
    return torso


def runner(lean=20.0, hips_pitch=14.0, yaw=9.0, head=-26.0, arms_fn=None):
    """Torso for runs: leaning hard into the sprint, shoulders counter-rotating."""
    arms_fn = arms_fn or arms_pump()

    def torso(ph):
        c, s = _cs(ph)
        spec = {"Hips": (hips_pitch, 3 * c, -yaw * c), "Spine": (lean, -2 * c, yaw * 1.7 * c),
                "Head": (head, 4 * s, -yaw * 0.6 * c), "hips": (0.012 * c, 0.0, 0.0)}
        spec.update(arms_fn(ph))
        return spec
    return torso


def shamble():
    """Tourist Shambler: lurching, one foot dragging, arms reaching."""
    d = 0.58
    return Gait(0.7, d, 0.84, 0.11, walker(d, lean=15, yaw=8, roll=5, sway=0.035, loll=8, lurch=1.0), front=0.48,
                bob=0.035, limp=0.55, crouch=0.02)


def flail_sprint():
    """Runners: forward-leaning sprint with a flight phase and a heel kick,
    arms clawing and flailing."""
    def arms_fn(ph):
        c, s = _cs(ph)
        return arms(-62 + 32 * c, -34 + 14 * s, -62 - 32 * c, -34 - 14 * s, spread=12)
    return Gait(0.42, 0.36, 0.82, 0.16, runner(lean=22, arms_fn=arms_fn), front=0.2, bob=0.03, bob_style="run")


def stomp():
    """Big enemies (Bruiser, Yeti): slow, wide, heavy steps that drop the body
    on every contact, shoulders rolling."""
    d = 0.62
    return Gait(0.96, d, 0.92, 0.12, walker(d, lean=10, hips_pitch=5, yaw=6, roll=3, sway=0.05, loll=3,
                                             head=-6, arms_fn=arms_heavy(20), shoulder_roll=4),
                front=0.48, width=0.07, bob=0.07, bob_style="stomp")


def charge():
    """Heavy charge: a lumbering run, head down, arms pumping wide."""
    return Gait(0.55, 0.42, 0.94, 0.14, runner(lean=24, hips_pitch=12, yaw=7, head=-14,
                                               arms_fn=arms_pump(36, -70, -20)),
                front=0.25, width=0.06, bob=0.05, bob_style="run")


def swagger():
    """Neon Punk: a cocky bouncing strut, chin up, spray can swinging low."""
    d = 0.58

    def arms_fn(ph):
        c, s = _cs(ph)
        return arms(-58 + 10 * c, -22 - 8 * s, -12 - 22 * c, -36 + 6 * s, spread=12)
    return Gait(0.7, d, 0.86, 0.12, walker(d, lean=10, yaw=10, roll=6, sway=0.04, head=-14, loll=7,
                                           arms_fn=arms_fn, shoulder_roll=5), front=0.5, bob=0.04)


def glide():
    """Hover Courier: floats on its hover boots in long, easy skating strides,
    leaning into the glide with the arms swept back. The feet never touch
    down (the boots hover), so there is nothing to slip."""
    def arms_fn(ph):
        c, s = _cs(ph)
        return arms(28 + 18 * c, -30, 28 - 18 * c, -30, spread=24)
    return Gait(0.75, 0.55, 2.0, 0.08, runner(lean=18, hips_pitch=12, yaw=6, head=-24, arms_fn=arms_fn),
                front=0.5, bob=0.025, glide=0.1, skate=0.55, crouch=0.04)


def waddle():
    """Deep Diver: flippers slap down in short, wide, rocking steps."""
    d = 0.55

    def arms_fn(ph):
        c, s = _cs(ph)
        return arms(-30 + 10 * c, -40, -30 - 10 * c, -40, spread=30)
    # Flippers: the tip reaches 0.75 m ahead of the ankle, so the steps are
    # short and stiff-kneed, the fins slap down ahead and lift off before the
    # shin can tip them into the floor; the body rocks side to side instead.
    return Gait(0.5, d, 0.5, 0.14, walker(d, lean=8, yaw=5, roll=11, sway=0.08, loll=3, head=-6,
                                          arms_fn=arms_fn), front=0.8, width=0.08, bob=0.03, foot=(0.13, 0.75, 0.05))


def squelch():
    """Mascot Inker: a soft, bouncy squelch, knees bent, swaying wide."""
    d = 0.56

    def arms_fn(ph):
        c, s = _cs(ph)
        return arms(-50 + 14 * c, -30 - 14 * s, -50 - 14 * c, -30 + 14 * s, spread=22)
    return Gait(0.62, d, 0.78, 0.12, walker(d, lean=6, yaw=6, roll=7, sway=0.05, loll=9, head=-6, arms_fn=arms_fn),
                front=0.5, bob=0.06, bob_style="run", crouch=0.06)


def trudge():
    """Hazmat worker: a stiff, wide trudge in a bulky suit, arms held out."""
    d = 0.62

    def arms_fn(ph):
        c, _ = _cs(ph)
        return arms(-36 + 12 * c, -30, -36 - 12 * c, -30, spread=22)
    return Gait(0.84, d, 0.84, 0.1, walker(d, lean=8, yaw=5, roll=4, sway=0.05, loll=4, head=-6, arms_fn=arms_fn),
                front=0.5, width=0.05, bob=0.05, bob_style="stomp")


def march():
    """Jetpack Mechanic: a purposeful, hunched work-boot march."""
    d = 0.58

    def arms_fn(ph):
        c, s = _cs(ph)
        return arms(-44 + 22 * c, -38 - 6 * s, -40 - 22 * c, -42 + 6 * s, spread=12)
    return Gait(0.7, d, 0.86, 0.12, walker(d, lean=16, yaw=8, roll=4, sway=0.035, loll=5, head=-12, arms_fn=arms_fn),
                front=0.5, bob=0.035)


def stiff_shuffle():
    """Frozen Tourist: short, stiff, scraping steps, arms locked forward."""
    d = 0.64

    def arms_fn(ph):
        c, _ = _cs(ph)
        return arms(-82 + 4 * c, -6, -76 - 4 * c, -8, spread=6)
    return Gait(0.62, d, 0.6, 0.06, walker(d, lean=6, yaw=4, roll=7, sway=0.045, loll=2, head=-4, arms_fn=arms_fn,
                                           lurch=0.6), front=0.5, bob=0.02, limp=0.3)


def skate(rig, name="Run_Skier", speed=3.75):
    """Ski Racer's skating stride on skis bound to its shins: crouched, butt
    back, each ski in turn pushes out to the side and glides back while the
    arms swing across; the shins stay upright so the skis lie flat. The skis
    glide, so the clip's ground speed is simply the racer's own pace."""
    n = 18
    keys = []
    for i in range(n + 1):
        ph = i / n
        c, s_ = _cs(ph)
        push_l = max(0.0, s_)            # left ski out during the first half
        push_r = max(0.0, -s_)
        lift_l = max(0.0, -s_) ** 2 * 0.05
        lift_r = max(0.0, s_) ** 2 * 0.05
        keys.append((i, {"Hips": (20, -4 * s_, -8 * c), "Spine": (24, 3 * s_, 12 * c), "Head": (-38, 0, -5 * c),
                         "hips": (0.05 * s_, -0.1, -0.12 + 0.02 * abs(c)),
                         "foot.L": (0.16 + 0.22 * push_l, 0.0, REST_ANKLE + lift_l),
                         "foot.R": (-0.16 - 0.22 * push_r, 0.0, REST_ANKLE + lift_r),
                         **arms(-30 + 40 * c, -50, -30 - 40 * c, -50, spread=18)}, "lin"))
    return keyed(rig, name, keys, loop=True, flat=True, speed=speed)

def riot_stomp():
    """Riot Bruiser: heavy stomp behind the shield, baton arm swinging."""
    d = 0.62

    def arms_fn(ph):
        c, _ = _cs(ph)
        return {"UpperArm.L": (-58 + 4 * c, 0, -38), "ForeArm.L": (-62, 0, -10),
                "UpperArm.R": (-30 - 14 * c, 14, 0), "ForeArm.R": (-50, 0, 0)}
    return Gait(0.92, d, 0.88, 0.12, walker(d, lean=8, yaw=5, roll=3, sway=0.05, loll=2, head=-6, arms_fn=arms_fn,
                                           shoulder_roll=3), front=0.48, width=0.06, bob=0.065, bob_style="stomp")


def riot_charge():
    """Riot Bruiser enraged run: shield up, baton pumping."""
    def arms_fn(ph):
        c, _ = _cs(ph)
        return {"UpperArm.L": (-68, 0, -38), "ForeArm.L": (-62, 0, -10),
                "UpperArm.R": (-20 + 30 * c, 16, 0), "ForeArm.R": (-60, 0, 0)}
    return Gait(0.55, 0.42, 0.9, 0.14, runner(lean=18, hips_pitch=12, yaw=5, head=-16, arms_fn=arms_fn),
                front=0.25, width=0.06, bob=0.05, bob_style="run")


# ---------------------------------------------------------------------------
# Stances shared by the one-shot clips
# ---------------------------------------------------------------------------

def ready(heavy=False, hands=True):
    """Neutral fighting stance: knees soft, one foot forward. With `hands`, the
    arms are IK hand targets (reaching forward); otherwise FK."""
    if heavy:
        s = {"Hips": (6, 0, 0), "Spine": (10, 0, 0), "Head": (-8, 0, 0), "hips": (0, 0, -0.06),
             **feet(0.24, 0.1, -0.1)}
        s.update({"hand.L": (0.42, 0.34, 0.86), "hand.R": (-0.42, 0.3, 0.84)} if hands
                 else arms(-24, -30, -20, -34, spread=16))
    else:
        s = {"Hips": (6, 0, 0), "Spine": (12, 0, 0), "Head": (-10, 0, 0), "hips": (0, 0, -0.04),
             **feet(0.18, 0.08, -0.08)}
        s.update({"hand.L": (0.3, 0.55, 1.08), "hand.R": (-0.3, 0.48, 1.02)} if hands
                 else arms(-64, -18, -54, -24, spread=10))
    return s


def idle(rig, name="Idle", heavy=False, arms_fn=None, flat=False):
    """Breathing sway: chest rises and falls, weight shifts foot to foot, the
    head lolls; feet stay planted (IK). Two-second loop."""
    n = 48
    keys = []
    for i in range(9):
        ph = i / 8
        c, s = _cs(ph)
        b = math.sin(math.tau * ph * 2)        # two breaths per loop
        sp = {"Hips": (4 + 1.5 * b, 2.5 * s, 3 * c), "Spine": (10 + 3 * b, -2 * s, -3 * c),
              "Head": (-6 - 2 * b, 7 * s, -5 * c), "hips": (0.025 * s, 0, -0.035 + 0.01 * b),
              **feet(0.2 if heavy else 0.17, 0.06, -0.04)}
        if arms_fn:
            sp.update(arms_fn(ph))
        elif heavy:
            sp.update(arms(-18 - 4 * b + 3 * c, -28, -14 - 4 * b - 3 * c, -32, spread=16 + 2 * b))
        else:
            sp.update(arms(-30 - 4 * b + 5 * c, -26, -22 - 4 * b - 5 * c, -30, spread=10 + 2 * b))
        keys.append((round(ph * n), sp, "io"))
    return keyed(rig, name, keys, loop=True, flat=flat)


# ---------------------------------------------------------------------------
# Attacks
# ---------------------------------------------------------------------------

STRIKE = 0.55   # zombie.gd ATTACK_STRIKE_FRACTION: the swipe lands here


def _attack_ready(heavy=False):
    r = ready(heavy)
    r.update({"elbow.L": elbow_pole(1), "elbow.R": elbow_pole(-1)})
    return r


def attack(rig, name="Attack", height=1.55, flat=False):
    """Two-handed claw swipe. Windup (frames 0-5): arms flung up and out, body
    coiled back, chin up; held, trembling, to frame 12; strike (55%, frame
    14.3): both hands sweep in and cross at `height` about 0.8 m in front,
    head up at the player; follow-through, then recover. 26 frames."""
    r = _attack_ready()
    # Claws up and out (elbows bent wide, a "W"), chin up but eyes on the player.
    up = {"Hips": (-4, 0, 6), "Spine": (-14, 0, 8), "Head": (-2, 0, 0), "hips": (0, -0.08, -0.03),
          "hand.L": (0.64, 0.04, 1.78), "hand.R": (-0.62, 0.0, 1.76),
          "elbow.L": (1.0, -0.3, -0.7), "elbow.R": (-1.0, -0.3, -0.7), **feet(0.18, 0.12, -0.1)}
    hold = dict(up, **{"Spine": (-17, 0, 10), "Head": (-4, 0, 0), "hand.L": (0.68, -0.02, 1.84),
                       "hand.R": (-0.66, -0.04, 1.82)})
    shake = dict(hold, **{"Spine": (-15, 2, 9), "hand.L": (0.66, 0.0, 1.87)})
    strike = {"Hips": (12, 0, -4), "Spine": (20, 0, -6), "Head": (-24, 0, 0), "hips": (0, 0.14, -0.08),
              "hand.L": (0.14, 0.82, height), "hand.R": (-0.12, 0.8, height - 0.04),
              "elbow.L": (0.8, -0.3, -0.5), "elbow.R": (-0.8, -0.3, -0.5), **feet(0.18, 0.2, -0.12)}
    follow = dict(strike, **{"Spine": (24, 0, -4), "Head": (-26, 0, 0), "hand.L": (-0.1, 0.66, height - 0.25),
                             "hand.R": (0.1, 0.62, height - 0.3)})
    return keyed(rig, name, [
        (0, r), (5, up, "out"), (9, shake), (12, hold), (15, strike, "snap"), (18, follow, "out"), (26, r)],
        flat=flat, strike=round(STRIKE * 26 / FPS, 4))


def attack_heavy(rig, name="Attack_Heavy", height=1.2):
    """Big enemies: double-fist overhead slam. Fists rise together high over
    the head (held), then hammer down in front at `height` with a stomp."""
    r = _attack_ready(heavy=True)
    up = {"Hips": (-6, 0, 0), "Spine": (-18, 0, 0), "Head": (-22, 0, 0), "hips": (0, -0.1, -0.02),
          "hand.L": (0.12, -0.02, 2.18), "hand.R": (-0.12, -0.02, 2.18),
          "elbow.L": (1.0, 0.2, 0.2), "elbow.R": (-1.0, 0.2, 0.2), **feet(0.24, 0.12, -0.12)}
    hold = dict(up, **{"Spine": (-21, 0, 0), "hand.L": (0.1, -0.06, 2.22), "hand.R": (-0.1, -0.06, 2.22)})
    slam = {"Hips": (14, 0, 0), "Spine": (24, 0, 0), "Head": (-28, 0, 0), "hips": (0, 0.16, -0.14),
            "hand.L": (0.12, 0.86, height), "hand.R": (-0.12, 0.86, height),
            "elbow.L": (1.0, -0.2, -0.2), "elbow.R": (-1.0, -0.2, -0.2), **feet(0.26, 0.3, -0.12)}
    follow = dict(slam, **{"Spine": (28, 0, 0), "hips": (0, 0.16, -0.17), "hand.L": (0.14, 0.84, height - 0.2),
                           "hand.R": (-0.14, 0.84, height - 0.2)})
    return keyed(rig, name, [
        (0, r), (7, up, "out"), (13, hold), (17, slam, "snap"), (20, follow, "out"), (30, r)],
        strike=round(STRIKE * 30 / FPS, 4))


def attack_riot(rig, name="Attack", height=1.35):
    """Riot Bruiser: baton raised high behind the shield, then a lunging
    shield bash with the baton coming down at `height`."""
    shield = {"UpperArm.L": (-58, 0, -38), "ForeArm.L": (-62, 0, -10)}
    base = {"Hips": (4, 0, 0), "Spine": (10, 0, 0), "Head": (-6, 0, 0), "hips": (0, 0, -0.05),
            "hand.R": (-0.42, 0.3, 0.95), "elbow.R": elbow_pole(-1), **feet(0.22, 0.12, -0.1), **shield}
    up = dict(base, **{"Hips": (-4, 0, 6), "Spine": (-12, 0, 10), "Head": (-14, 0, 0), "hips": (0, -0.08, -0.03),
                       "hand.R": (-0.36, -0.18, 2.08), "elbow.R": (-1.0, 0.3, 0.2), "UpperArm.L": (-48, 0, -38)})
    hold = dict(up, **{"Spine": (-15, 0, 12), "hand.R": (-0.34, -0.22, 2.12)})
    bash = dict(base, **{"Hips": (12, 0, -6), "Spine": (26, 0, -10), "Head": (-28, 0, 0), "hips": (0, 0.2, -0.1),
                         "hand.R": (-0.06, 0.82, height), "elbow.R": (-1.0, -0.2, -0.2), "UpperArm.L": (-84, 0, -38),
                         **feet(0.22, 0.3, -0.12)})
    follow = dict(bash, **{"Spine": (28, 0, -8), "hand.R": (0.02, 0.7, height - 0.28)})
    return keyed(rig, name, [
        (0, base), (7, up, "out"), (12, hold), (15, bash, "snap"), (19, follow, "out"), (26, base)],
        strike=round(STRIKE * 26 / FPS, 4))


def attack_shove(rig, name="Attack_Shove", height=1.4):
    """Bulky suits (Hazmat, Diver): a two-handed shove. Arms pull back to the
    chest (held), then both palms drive out at `height`."""
    r = _attack_ready()
    coil = {"Hips": (-2, 0, 0), "Spine": (-8, 0, 0), "Head": (-14, 0, 0), "hips": (0, -0.1, -0.06),
            "hand.L": (0.34, 0.12, 1.42), "hand.R": (-0.34, 0.12, 1.42),
            "elbow.L": (1.0, 0.6, -0.4), "elbow.R": (-1.0, 0.6, -0.4), **feet(0.2, 0.14, -0.14)}
    hold = dict(coil, **{"Spine": (-11, 0, 0), "hips": (0, -0.12, -0.07)})
    push = {"Hips": (12, 0, 0), "Spine": (18, 0, 0), "Head": (-22, 0, 0), "hips": (0, 0.18, -0.08),
            "hand.L": (0.24, 0.92, height), "hand.R": (-0.24, 0.92, height),
            "elbow.L": (1.0, -0.1, -0.5), "elbow.R": (-1.0, -0.1, -0.5), **feet(0.2, 0.28, -0.14)}
    follow = dict(push, **{"hand.L": (0.26, 0.88, height - 0.1), "hand.R": (-0.26, 0.88, height - 0.1)})
    return keyed(rig, name, [
        (0, r), (6, coil, "out"), (12, hold), (15, push, "snap"), (19, follow, "out"), (26, r)],
        strike=round(STRIKE * 26 / FPS, 4))


def attack_overhead(rig, name="Attack_Wrench", height=1.45):
    """One-handed overhead strike (the Mechanic's wrench): right arm cocks
    back over the shoulder, then chops down in front at `height`."""
    r = _attack_ready()
    up = {"Hips": (-4, 0, 10), "Spine": (-12, 0, 14), "Head": (-18, 0, -6), "hips": (0, -0.08, -0.03),
          "hand.L": (0.4, 0.45, 1.25), "hand.R": (-0.3, -0.25, 2.05),
          "elbow.L": elbow_pole(1), "elbow.R": (-1.0, 0.4, 0.4), **feet(0.18, 0.14, -0.12)}
    hold = dict(up, **{"Spine": (-15, 0, 16), "hand.R": (-0.28, -0.3, 2.1)})
    chop = {"Hips": (12, 0, -8), "Spine": (22, 0, -14), "Head": (-26, 0, 6), "hips": (0, 0.16, -0.1),
            "hand.L": (0.42, 0.2, 1.0), "hand.R": (-0.04, 0.84, height),
            "elbow.L": elbow_pole(1), "elbow.R": (-1.0, -0.2, -0.3), **feet(0.18, 0.26, -0.12)}
    follow = dict(chop, **{"Spine": (26, 0, -12), "hand.R": (0.08, 0.7, height - 0.32)})
    return keyed(rig, name, [
        (0, r), (6, up, "out"), (12, hold), (15, chop, "snap"), (19, follow, "out"), (26, r)],
        strike=round(STRIKE * 26 / FPS, 4))


def spit(rig, name="Spit"):
    """Mascot Inker ranged attack: leans back gulping (the ink sac swells),
    wobbling, then thrusts the head forward and spits at frame 22 (0.92 s,
    the volley's windup), arms flung back."""
    r = ready(hands=False)
    gulp = dict(r, **{"Hips": (-4, 0, 0), "Spine": (-14, 0, 0), "Head": (-28, 0, 0), "hips": (0, -0.06, -0.02),
                      **arms(-40, -50, -40, -50, spread=40)})
    wob1 = dict(gulp, **{"Spine": (-10, 3, 0), "Head": (-22, -6, 0), **arms(-46, -56, -36, -46, spread=44)})
    wob2 = dict(gulp, **{"Spine": (-18, -3, 0), "Head": (-32, 6, 0), **arms(-36, -46, -46, -56, spread=48)})
    loaded = dict(gulp, **{"Spine": (-20, 0, 0), "Head": (-34, 0, 0), **arms(-30, -60, -30, -60, spread=52)})
    thrust = dict(r, **{"Hips": (12, 0, 0), "Spine": (24, 0, 0), "Head": (6, 0, 0), "hips": (0, 0.12, -0.08),
                        **arms(20, -30, 20, -30, spread=30)})
    return keyed(rig, name, [
        (0, r), (6, gulp, "out"), (10, wob1), (14, wob2), (18, wob1), (21, loaded), (23, thrust, "snap"),
        (27, dict(thrust, Head=(0, 0, 0))), (34, r)], release=round(22 / FPS, 4))


def roar(rig, name="Roar"):
    """Charge telegraph (Bruiser): chest out, arms thrown wide, head back
    roaring and shaking, then dropping into the charge. 17 frames."""
    r = _attack_ready(heavy=True)
    wide = {"Hips": (-6, 0, 0), "Spine": (-16, 0, 0), "Head": (-30, 0, 0), "hips": (0, -0.06, -0.04),
            "hand.L": (0.86, 0.22, 1.5), "hand.R": (-0.86, 0.22, 1.5),
            "elbow.L": (0.2, 0.0, -1.0), "elbow.R": (-0.2, 0.0, -1.0), **feet(0.26, 0.08, -0.12)}
    keys = [(0, r), (4, wide, "out")]
    for i, f in enumerate((6, 8, 10, 12)):
        k = 1 if i % 2 == 0 else -1
        keys.append((f, dict(wide, **{"Head": (-32, 0, 8 * k), "Spine": (-17, 2 * k, 2 * k),
                                       "hand.L": (0.88, 0.22, 1.53 + 0.03 * k), "hand.R": (-0.88, 0.22, 1.53 - 0.03 * k)}),
                     "lin"))
    lunge = dict(r, **{"Hips": (12, 0, 0), "Spine": (22, 0, 0), "Head": (-20, 0, 0), "hips": (0, 0.08, -0.1),
                       "hand.L": (0.46, 0.3, 0.9), "hand.R": (-0.46, 0.3, 0.9)})
    keys.append((17, lunge, "io"))
    return keyed(rig, name, keys)


# ---------------------------------------------------------------------------
# Full-body hit reactions (light hits are an additive layer in the game)
# ---------------------------------------------------------------------------

def stagger(rig, name="Stagger", heavy=False, flat=False):
    """Heavy hit / interrupted windup: jolted upright, arms flung up, one
    stumbling step back, hunch, recover. 15 frames (0.6 s)."""
    r = ready(heavy, hands=False)
    k = 0.6 if heavy else 1.0
    w = 0.24 if heavy else 0.18
    jolt = dict(r, **{"Hips": (-10 * k, 0, 6 * k), "Spine": (-22 * k, 4, 10 * k), "Head": (-28 * k, 6, 0),
                      "hips": (0, -0.06 * k, -0.02), **arms(-110 * k, -30, -96 * k, -40, spread=-30 * k)})
    lift = dict(jolt, **{"foot.R": (-w, -0.12, 0.2)})
    step = dict(jolt, **{"Hips": (10, 0, 4), "Spine": (24, 0, 6), "Head": (-30, 0, 0), "hips": (0, -0.2 * k, -0.1),
                         "foot.R": (-w, -0.34 * k, REST_ANKLE), **arms(-40, -40, -30, -50, spread=18)})
    settle = dict(r, **{"hips": (0, -0.1 * k, -0.06), "foot.R": (-w, -0.24 * k, REST_ANKLE)})
    return keyed(rig, name, [(0, r), (3, jolt, "snap"), (6, lift), (9, step, "in"), (12, settle), (15, r)], flat=flat)


def hit_head(rig, name="Hit_Head"):
    """Head snaps back hard (a shot-out visor). 8 frames."""
    r = ready(hands=False)
    snap = dict(r, **{"Head": (-45, 8, 6), "Spine": (-6, 0, 0), "hips": (0, -0.04, -0.04),
                      **arms(-84, -30, -76, -36, spread=-6)})
    return keyed(rig, name, [(0, r), (2, snap, "snap"), (8, r)])


# ---------------------------------------------------------------------------
# Deaths. Each records `impact` (the body hits the ground: the game squashes
# the model); Die_HeadPop also records `pop` (the head bursts: confetti).
# ---------------------------------------------------------------------------

def _legs(thigh_l, shin_l, thigh_r, shin_r):
    return {"Thigh.L": (thigh_l, 0, 0), "Shin.L": (shin_l, 0, 0), "Thigh.R": (thigh_r, 0, 0), "Shin.R": (shin_r, 0, 0)}


def _stand_fk(heavy=False):
    s = {"Hips": (6, 0, 0), "Spine": (12, 0, 0), "Head": (-10, 0, 0), "hips": (0, 0, -0.04), **_legs(-8, 14, 6, 10)}
    s.update(arms(-24, -30, -20, -34, spread=16) if heavy else arms(-60, -20, -50, -26, spread=10))
    return s


def die_back(rig, name="Die_Back"):
    """Knocked backward: recoil, knees buckle, topple onto the back (impact
    at frame 13, with a bounce), arms flung wide. 26 frames."""
    s = _stand_fk()
    recoil = dict(s, **{"Hips": (-14, 0, 0), "Spine": (-22, 0, 0), "Head": (-30, 0, 0), "hips": (0, -0.08, -0.02),
                        **arms(-140, -20, -130, -26, spread=-34), **_legs(-14, 20, 4, 18)})
    buckle = dict(recoil, **{"Hips": (-46, 0, 0), "Spine": (-14, 0, 0), "Head": (-16, 0, 0), "hips": (0, -0.3, -0.34),
                             **_legs(-30, 70, -20, 80), **arms(-160, -14, -150, -20, spread=-50)})
    down = dict(buckle, **{"Hips": (-86, 0, 0), "Spine": (-6, 0, 0), "Head": (14, 0, 0), "hips": (0, -0.62, -0.52),
                           **_legs(-8, 34, 4, 22), **arms(-170, -10, -165, -10, spread=-80)})
    bounce = dict(down, **{"Hips": (-78, 0, 0), "hips": (0, -0.6, -0.47), "Head": (6, 0, 0), **_legs(-22, 46, -8, 30)})
    rest = dict(down, **{"Hips": (-88, 0, 0), "Head": (18, 0, 6), **_legs(-4, 18, 8, 12)})
    return keyed(rig, name, [(0, s), (4, recoil, "snap"), (9, buckle, "in"), (13, down, "in"), (16, bounce, "out"),
                             (19, rest, "in"), (26, rest)], impact=round(13 / FPS, 4))


def die_front(rig, name="Die_Front"):
    """Faceplant: the head drops, knees hit the ground, then the body pitches
    forward flat on its face (impact frame 15), arms out front. 26 frames."""
    s = _stand_fk()
    slump = dict(s, **{"Hips": (10, 0, 0), "Spine": (30, 0, 0), "Head": (30, 0, 0), "hips": (0, 0.04, -0.08),
                       **arms(-20, -10, -14, -16, spread=6), **_legs(-14, 26, 4, 20)})
    knees = dict(slump, **{"Hips": (16, 0, 0), "Spine": (26, 0, 0), "Head": (20, 0, 0), "hips": (0, 0.16, -0.44),
                           **_legs(-72, 120, -60, 114), **arms(-46, -20, -40, -24, spread=10)})
    down = dict(knees, **{"Hips": (84, 0, 0), "Spine": (6, 0, 0), "Head": (-30, 0, 4), "hips": (0, 0.42, -0.56),
                          **_legs(-6, 10, 2, 14), **arms(-170, -6, -160, -8, spread=20)})
    bounce = dict(down, **{"Hips": (76, 0, 0), "hips": (0, 0.42, -0.5), **_legs(-16, 40, -10, 34)})
    rest = dict(down, **{"Hips": (88, 0, 0), "Head": (-34, 0, 8), **_legs(4, 30, 8, 24)})
    return keyed(rig, name, [(0, s), (5, slump, "out"), (10, knees, "in"), (15, down, "in"), (18, bounce, "out"),
                             (21, rest, "in"), (26, rest)], impact=round(15 / FPS, 4))


def die_spin(rig, name="Die_Spin"):
    """Spun round by the shot: twists half a turn with the arms flung out,
    crumples to the knees and drops onto its back (impact frame 17)."""
    s = _stand_fk()
    twist = dict(s, **{"Hips": (-6, 0, 100), "Spine": (-10, 8, 40), "Head": (-16, 10, 20), "hips": (0.04, -0.06, -0.06),
                       **arms(-80, -10, -70, -14, spread=70), **_legs(-20, 30, 10, 26)})
    crumple = dict(twist, **{"Hips": (-10, 10, 170), "Spine": (10, 14, 10), "Head": (20, 10, 0),
                             "hips": (0.08, -0.1, -0.4), **arms(-40, -30, -30, -40, spread=40), **_legs(-66, 110, -50, 104)})
    # Flat on its back, arms flung out along the ground.
    down = dict(crumple, **{"Hips": (-84, 12, 190), "Spine": (-4, 6, 0), "Head": (10, 20, 10),
                            "hips": (0.18, 0.4, -0.54), **arms(-6, -10, 8, -20, spread=76), **_legs(-24, 50, -10, 30)})
    bounce = dict(down, **{"Hips": (-76, 10, 190), "hips": (0.18, 0.4, -0.49)})
    rest = dict(down, **{"Hips": (-88, 14, 190), "Head": (16, 24, 10)})
    return keyed(rig, name, [(0, s), (6, twist, "out"), (11, crumple, "io"), (17, down, "in"), (20, bounce, "out"),
                             (23, rest, "in"), (28, rest)], impact=round(17 / FPS, 4))


def die_heavy(rig, name="Die_Heavy"):
    """Big enemies: reels a step back, drops heavily to the knees (first thud,
    frame 12), sways, then falls forward like a tree (impact frame 27)."""
    s = _stand_fk(heavy=True)
    reel = dict(s, **{"Hips": (-10, 0, 8), "Spine": (-16, 0, 10), "Head": (-24, 0, 0), "hips": (0, -0.12, -0.04),
                      **arms(-60, -40, -46, -44, spread=30), **_legs(-24, 30, 14, 20)})
    knees = dict(reel, **{"Hips": (6, 0, 0), "Spine": (-4, 0, 0), "Head": (-16, 0, 0), "hips": (0, 0.06, -0.48),
                          **arms(-10, -20, -6, -24, spread=26), **_legs(-84, 124, -76, 120)})
    sway = dict(knees, **{"Hips": (10, -4, 0), "Spine": (12, -4, 0), "Head": (14, -8, 0)})
    tip = dict(sway, **{"Hips": (40, 0, 0), "Spine": (14, 0, 0), "Head": (0, 0, 0), "hips": (0, 0.2, -0.5),
                        **arms(-60, -10, -50, -10, spread=20)})
    down = dict(tip, **{"Hips": (86, 0, 0), "Spine": (4, 0, 0), "Head": (-30, 0, 6), "hips": (0, 0.46, -0.56),
                        **_legs(-10, 20, -4, 26), **arms(-150, -10, -140, -14, spread=40)})
    bounce = dict(down, **{"Hips": (80, 0, 0), "hips": (0, 0.46, -0.52)})
    rest = dict(down, **{"Hips": (88, 0, 0)})
    return keyed(rig, name, [(0, s), (6, reel, "out"), (12, knees, "in"), (17, sway), (21, tip, "in"), (27, down, "in"),
                             (30, bounce, "out"), (33, rest, "in"), (36, rest)], impact=round(27 / FPS, 4),
                 thud=round(12 / FPS, 4))


def die_headpop(rig, name="Die_HeadPop"):
    """Headshot kill: the head jerks back and inflates, wobbling, until it
    pops at frame 8.5 (`pop`: confetti in the game); the body flails, drops
    to its knees and topples forward (impact frame 24)."""
    s = _stand_fk()
    s["scale.Head"] = 1.0
    jerk = dict(s, **{"Head": (-34, 0, 0), "Spine": (-8, 0, 0), "scale.Head": 1.22,
                      **arms(-110, -20, -100, -26, spread=-20)})
    swell = dict(jerk, **{"Head": (-26, 8, 6), "scale.Head": 1.62, **arms(-130, -30, -126, -34, spread=-36)})
    popped = dict(swell, **{"scale.Head": 0.001})
    flail = dict(popped, **{"Spine": (4, 0, 0), "hips": (0, -0.02, -0.08), **arms(-150, -40, -60, -20, spread=-40),
                            **_legs(-20, 30, 4, 20)})
    knees = dict(flail, **{"Hips": (10, 0, 0), "Spine": (20, 0, 0), "hips": (0, 0.1, -0.46),
                           **arms(-30, -20, -24, -24, spread=12), **_legs(-80, 120, -72, 116)})
    down = dict(knees, **{"Hips": (84, 0, 0), "Spine": (6, 0, 0), "hips": (0, 0.44, -0.56),
                          **arms(-160, -10, -150, -10, spread=24), **_legs(-6, 14, 2, 18)})
    bounce = dict(down, **{"Hips": (77, 0, 0), "hips": (0, 0.44, -0.51)})
    rest = dict(down, **{"Hips": (88, 0, 0)})
    keys = [(0, s), (2, dict(jerk, **{"scale.Head": 1.05}), "snap"), (4, jerk, "out"), (6, swell, "out"),
            (7, dict(swell, **{"scale.Head": 1.5})), (8, dict(swell, **{"scale.Head": 1.75})), (9, popped, "lin"),
            (13, flail, "out"), (18, knees, "in"), (24, down, "in"), (27, bounce, "out"), (30, rest, "in"), (32, rest)]
    return keyed(rig, name, keys, impact=round(24 / FPS, 4), pop=round(8.5 / FPS, 4))


def deaths(rig):
    """The death set: Die_Back, Die_Front, Die_Spin, Die_Heavy, Die_HeadPop."""
    return [die_back(rig), die_front(rig), die_spin(rig), die_heavy(rig), die_headpop(rig)]


# ---------------------------------------------------------------------------
# Entrance
# ---------------------------------------------------------------------------

def emerge(rig, name="Emerge", heavy=False, flat=False):
    """Spawn entrance: starts low, one knee and both hands down as if hauling
    itself up over an edge, pushes up, rises with a head shake and lifts its
    arms into the reach. 22 frames (0.92 s), ends in the ready stance."""
    w = 0.22 if heavy else 0.18
    low = {"Hips": (40, 0, 0), "Spine": (34, 0, 0), "Head": (-56, 0, 0), "hips": (0, 0.06, -0.46),
           "foot.L": (w, 0.22, REST_ANKLE), "foot.R": (-w, -0.32, 0.14),
           "hand.L": (0.3, 0.62, 0.08), "hand.R": (-0.3, 0.58, 0.1),
           "elbow.L": (1.0, -0.2, 0.0), "elbow.R": (-1.0, -0.2, 0.0)}
    push = dict(low, **{"Hips": (30, 0, -6), "Spine": (30, 0, -4), "Head": (-50, 0, 0), "hips": (0, 0.04, -0.34),
                        "hand.L": (0.32, 0.6, 0.06), "hand.R": (-0.3, 0.56, 0.08), "foot.R": (-w, -0.24, REST_ANKLE)})
    rise = dict(push, **{"Hips": (10, 0, 0), "Spine": (14, 0, 0), "Head": (-20, 0, 0), "hips": (0, 0.02, -0.12),
                         "foot.R": (-w, -0.1, REST_ANKLE), "hand.L": (0.42, 0.3, 0.7), "hand.R": (-0.42, 0.26, 0.66),
                         "elbow.L": elbow_pole(1), "elbow.R": elbow_pole(-1)})
    shake1 = dict(rise, **{"Head": (-14, 12, 14), "Spine": (10, 0, 4), "hips": (0, 0, -0.05),
                           "hand.L": (0.34, 0.5, 1.0), "hand.R": (-0.34, 0.44, 0.96)})
    shake2 = dict(shake1, **{"Head": (-14, -12, -14), "Spine": (12, 0, -4)})
    end = dict(shake2, **{"Head": (-10, 0, 0), "Spine": (12, 0, 0), "Hips": (6, 0, 0), "hips": (0, 0, -0.04),
                          "foot.L": (w, 0.06, REST_ANKLE), "foot.R": (-w, -0.06, REST_ANKLE),
                          "hand.L": (0.3, 0.55, 1.08), "hand.R": (-0.3, 0.48, 1.02)})
    return keyed(rig, name, [(0, low), (3, low), (8, push, "in"), (13, rise, "out"), (16, shake1), (19, shake2),
                             (22, end, "io")], flat=flat)


# ---------------------------------------------------------------------------
# World specials
# ---------------------------------------------------------------------------

def spray(rig, name="Spray"):
    """Neon Punk: shake the can (frames 0-19), then hold it out and spray."""
    base = {"Hips": (4, 0, 0), "Spine": (2, 0, 10), "Head": (-10, 0, 0), "hips": (0, 0, -0.04),
            **feet(0.18, 0.1, -0.08), **arms(-40, -30, -60, -36, spread=8)}
    keys = [(0, base)]
    for f in range(2, 21, 2):
        k = math.sin(f * 1.4)
        keys.append((f, arms(-40, -30, -150 + 18 * k, -40 - 25 * k, spread=6), "lin"))
    aim = {"Spine": (8, 0, 14), "Head": (-4, 0, 0), **arms(-50, -30, -92, -4, spread=-4)}
    keys += [(24, aim), (32, aim)]
    return keyed(rig, name, keys)


def crouch(rig, name="Crouch", depth=1.0):
    """Leap windup (Courier, Cadet, Mechanic): sinks into a deep squat, arms
    swept back, head up at the target; feet stay planted."""
    st = {"Hips": (6, 0, 0), "Spine": (14, 0, 0), "Head": (-8, 0, 0), "hips": (0, 0, -0.03),
          **feet(0.2, 0.04, -0.04), **arms(-40, -20, -36, -20, spread=10)}
    low = {"Hips": (20 + 6 * depth, 0, 0), "Spine": (26 + 6 * depth, 0, 0), "Head": (-32 - 6 * depth, 0, 0),
           "hips": (0, 0.05, -0.3 * depth), **arms(42, -20, 44, -20, spread=24)}
    deeper = {"Head": (-38 - 6 * depth, 0, 0), "hips": (0, 0.06, -0.33 * depth)}
    return keyed(rig, name, [(0, st), (6, low, "out"), (14, deeper)])


def leap(rig, name="Leap"):
    """Courier in flight: knee tucked, arms thrown up, then reaching down."""
    p = {"Hips": (-10, 0, 0), "Spine": (6, 0, 0), "Head": (-14, 0, 0), "hips": (0, 0, 0.05),
         **_legs(-90, 100, 10, 10), **arms(-150, -10, -150, -10, spread=-30)}
    return keyed(rig, name, [(0, p), (6, {**_legs(-90, 100, -40, 60), "hips": (0, 0, 0.1)}),
                             (16, {"Spine": (20, 0, 0), **_legs(-60, 60, -60, 60), "hips": (0, 0, 0.05)})])


def hover(rig, name="Hover"):
    """Jetpack flight: legs dangling and kicking, arms out for balance."""
    keys = []
    for i in range(9):
        _, s = _cs(i / 8)
        keys.append((i * 3, {"Hips": (4, 0, 3 * s), "Spine": (8, 0, -4 * s), "Head": (-12, 4 * s, 0),
                             "hips": (0, 0, 0.02 * s), **_legs(-14 + 10 * s, 24 + 8 * s, -6 - 10 * s, 30 - 8 * s),
                             **arms(-30 + 6 * s, -40, -30 - 6 * s, -40, spread=62)}, "io"))
    return keyed(rig, name, keys, loop=True)


def bound(rig, name="Bound", contact_speed=1.5):
    """Space Cadet low-gravity bound. Contact from 80% to 20% of the loop
    (both feet planted together; the game lifts the model in between): land,
    absorb, push off; in the air the legs tuck and swing through, arms up.
    The planted feet travel at `contact_speed`; the clip's `profile` tells the
    game to move the cadet slowly on the ground and fast in the air."""
    n = 22
    on_ground = 0.45                      # speed factor while planted (profile)
    s_len = contact_speed * 0.4 * n / FPS
    keys = []
    for i in range(n + 1):
        k = ((i % n) / n + 0.2) % 1.0     # 0 at touchdown (80%), 0.4 at take-off (20%)
        if k < 0.4:
            u = k / 0.4
            fwd = s_len / 2 - u * s_len
            squat = math.sin(math.pi * u)
            sp = {"Hips": (10 + 16 * squat, 0, 0), "Spine": (10 + 16 * squat, 0, 0), "Head": (-14 - 16 * squat, 0, 0),
                  "hips": (0, 0, -0.08 - 0.22 * squat), **feet(0.17, fwd, fwd - 0.08),
                  **arms(-20 + 40 * squat, -30, -16 + 40 * squat, -30, spread=18)}
        else:
            u = (k - 0.4) / 0.6
            air = math.sin(math.pi * u)
            fwd = -s_len / 2 + u * s_len - 0.2 * air
            sp = {"Hips": (10, 0, 0), "Spine": (10 - 4 * air, 0, 0), "Head": (-14, 0, 0),
                  "hips": (0, 0, -0.08 + 0.04 * air), **feet(0.17, fwd + 0.05, fwd - 0.05, REST_ANKLE + 0.18 * air,
                                                              REST_ANKLE + 0.14 * air),
                  **arms(-20 - 90 * air, -30 + 10 * air, -16 - 100 * air, -30 + 10 * air, spread=18 + 12 * air)}
        keys.append((i, sp, "lin"))
    profile = [on_ground if ((j / 16 + 0.2) % 1.0) < 0.4 else (1 - 0.4 * on_ground) / 0.6 for j in range(16)]
    return keyed(rig, name, keys, loop=True, speed=round(contact_speed / on_ground, 4), profile=profile)


def tuck(rig, name="Tuck"):
    """Ski Racer's downhill tuck: crouched, chest over the knees, fists
    forward, feet side by side (the skis glide), a slight bob."""
    keys = []
    for i in range(5):
        _, s = _cs(i / 4)
        keys.append((i * 3, {"Hips": (40, 0, 0), "Spine": (28 + 3 * s, 0, 0), "Head": (-52, 0, 0),
                             "hips": (0, -0.14, -0.3 + 0.015 * s), **feet(0.15, 0.0, 0.0),
                             **arms(-62, -60, -62, -60, spread=6)}, "io"))
    return keyed(rig, name, keys, loop=True, flat=True)


def throw(rig, name="Throw"):
    """Yeti's two-handed overhead heave: rear back (frames 0-12), release at
    ~15, follow through; feet planted."""
    def pose(spine, head, upper, fore, hips=4, spread=10, fwd=0.0):
        return {"Hips": (hips, 0, 0), "Spine": (spine, 0, 0), "Head": (head, 0, 0), "hips": (0, fwd, -0.06),
                **feet(0.24, 0.14, -0.12), **arms(upper, fore, upper, fore, spread=spread)}
    return keyed(rig, name, [
        (0, pose(12, -8, -40, -20)), (7, pose(-14, -22, -165, -70, hips=-4, spread=-20, fwd=-0.08), "out"),
        (12, pose(-20, -26, -175, -80, hips=-6, spread=-24, fwd=-0.1)),
        (15, pose(38, 6, -70, -6, hips=12, spread=8, fwd=0.12), "snap"),
        (20, pose(30, 0, -40, -12, hips=9, spread=10, fwd=0.1), "out"), (28, pose(12, -8, -40, -20))])


# ---------------------------------------------------------------------------
# Clip sets, one per model file
# ---------------------------------------------------------------------------

def _common(rig, heavy=False):
    clips = [stagger(rig), hit_head(rig), *deaths(rig), emerge(rig)]
    if heavy:
        clips += [stagger(rig, "Stagger_Heavy", heavy=True), emerge(rig, "Emerge_Heavy", heavy=True)]
    return clips


def boardwalk_clips(rig):
    """zombie.glb: Tourist (shamble), Lifeguard (sprint), Bruiser (style "Heavy")."""
    return [idle(rig), gait(rig, "Walk", shamble()), gait(rig, "Run", flail_sprint()),
            idle(rig, "Idle_Heavy", heavy=True), gait(rig, "Walk_Heavy", stomp()), gait(rig, "Run_Heavy", charge()),
            attack(rig), attack_heavy(rig), roar(rig), *_common(rig, heavy=True)]


def punk_clips(rig):
    """neon_punk.glb: swagger walk, spray tag."""
    def punk_idle_arms(ph):
        _, s = _cs(ph)
        return arms(-24 + 4 * s, -24, -30 - 6 * s, -50, spread=12)
    return [idle(rig, arms_fn=punk_idle_arms), gait(rig, "Walk", swagger()), gait(rig, "Run", flail_sprint()),
            attack(rig), spray(rig), *_common(rig)]


def courier_clips(rig):
    """neon_courier.glb: hover-glide run, crouch and leap."""
    return [idle(rig), gait(rig, "Walk", march()), gait(rig, "Run", glide()), attack(rig),
            crouch(rig), leap(rig), *_common(rig)]


def riot_clips(rig):
    """neon_riot.glb: shielded stomp, shield bash; heavy staggers and deaths."""
    def riot_idle_arms(ph):
        _, s = _cs(ph)
        return {"UpperArm.L": (-58 + 2 * s, 0, -38), "ForeArm.L": (-62, 0, -10),
                "UpperArm.R": (-20 + 3 * s, 16, 0), "ForeArm.R": (-40, 0, 0)}
    return [idle(rig, heavy=True, arms_fn=riot_idle_arms), gait(rig, "Walk", riot_stomp()),
            gait(rig, "Run", riot_charge()), attack_riot(rig), stagger(rig, heavy=True), hit_head(rig),
            *deaths(rig), emerge(rig, heavy=True)]


def aqua_clips(rig):
    """aqua_zombies.glb: Diver (style "Diver": waddle, shove), Octo (style
    "Octo": squelch walk, spit), Jelly (sprint)."""
    return [idle(rig), gait(rig, "Walk", shamble()), gait(rig, "Walk_Diver", waddle()),
            gait(rig, "Walk_Octo", squelch()), gait(rig, "Run", flail_sprint()), attack(rig),
            attack_shove(rig, "Attack_Diver"), spit(rig), *_common(rig)]


def dune_clips(rig):
    """dune_zombies.glb: Mechanic (style "Mechanic": march, wrench), Hazmat
    (style "Hazmat": trudge, shove), Cadet (bound); Crouch/Hover for leaps."""
    return [idle(rig), gait(rig, "Walk", march()), gait(rig, "Walk_Hazmat", trudge()), gait(rig, "Run", flail_sprint()),
            bound(rig), crouch(rig), hover(rig), attack(rig), attack_overhead(rig, "Attack_Mechanic"),
            attack_shove(rig, "Attack_Hazmat"), *_common(rig)]


def frost_clips(rig):
    """frost_zombies.glb: Frozen Tourist (stiff shuffle), Ski Racer (style
    "Skier": skate, tuck), Yeti (style "Heavy": stomp, slam, throw)."""
    return [idle(rig), gait(rig, "Walk", stiff_shuffle()), gait(rig, "Run", flail_sprint()),
            skate(rig), skate(rig, "Walk_Skier"), tuck(rig), idle(rig, "Idle_Skier", flat=True),
            attack(rig, "Attack_Skier", flat=True),
            stagger(rig, "Stagger_Skier", flat=True), emerge(rig, "Emerge_Skier", flat=True),
            idle(rig, "Idle_Heavy", heavy=True),
            gait(rig, "Walk_Heavy", stomp()), attack(rig), attack_heavy(rig), throw(rig), *_common(rig, heavy=True)]
