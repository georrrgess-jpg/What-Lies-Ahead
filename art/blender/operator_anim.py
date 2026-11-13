"""Rig solving and animation clips for the operators (see build_operators.py).

Poses are written as small "specs": per-bone rotations in armature axes
(X = lean forward +, Y = roll, Z = turn left +) plus optional IK goals

    "hips_loc": offset of the hips
    "foot.L" / "foot.R": dict(pos=ankle, yaw, pitch, roll)      (legs always use IK,
                          so planted feet stay planted while the hips move)
    "hand.L" / "hand.R": dict(pos=wrist, rot=Quaternion, pole)  (two-handed holds)

solve() turns a spec into local bone rotations; clips are either procedural
(a spec per frame: Idle, Run, AimIdle, Fire) or keyed (Pose, Wave, Victory).

Clips exported for every operator:
    Idle-loop      5 s   weight shift, breathing, looking around
    Pose           one-shot signature flourish (a different one per operator)
    Run-loop       0.6 s in place; feet do not slide at RUN_SPEED m/s
    AimIdle-loop   3 s   two-handed weapon hold at the shoulder (see WeaponSocket)
    Fire           0.5 s recoil beat that starts and ends on AimIdle's first frame
    Victory        jump and fist pumps, back to idle
    Wave           friendly wave, back to idle
"""
import math

from operator_kit import *  # noqa: F401,F403
from operator_kit import BONES, HAND_X, HAND_Y, HAND_Z, WRIST, ELBOW, SHOULDER, ANKLE, SOCKET, hand_point, sx, weapon_socket_matrix

FPS = 30
RUN_SPEED = 2.8          # m/s the Run-loop's planted feet travel at
RUN_LEN = 0.6
IDLE_LEN = 5.0
AIM_LEN = 3.0
IDENT = Quaternion()

LOWER = {"Hips", "Thigh.L", "Shin.L", "Foot.L", "Thigh.R", "Shin.R", "Foot.R"}


class Rig:
    def __init__(self, extra_bones=()):
        bones = list(BONES) + list(extra_bones)
        self.head = {n: Vector(h) for n, h, _t, _p in bones}
        self.parent = {n: p for n, _h, _t, p in bones}
        self.order = [n for n, _h, _t, _p in bones]


class Solved:
    def __init__(self):
        self.q, self.D, self.P = {}, {}, {}
        self.hips_loc = Vector((0, 0, 0))
        self.reach_error = 0.0


def eq(rx, ry, rz):
    return Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_quaternion()


def as_q(v):
    return v if isinstance(v, Quaternion) else eq(*v)


def mirror_q(q):
    return Quaternion((q.w, q.x, -q.y, -q.z))


def _frame(b, w):
    n = b.cross(w)
    if n.length < 1e-6:
        n = b.orthogonal()
    n.normalize()
    return Matrix((n, n.cross(b), b)).transposed()


def two_bone(root, target, l1, l2, pole):
    v = target - root
    d = v.length
    dc = min(max(d, abs(l1 - l2) + 1e-4), (l1 + l2) * 0.9995)
    u = v / d if d > 1e-9 else Vector((0, 0, -1))
    cos_a = min(max((l1 * l1 + dc * dc - l2 * l2) / (2 * l1 * dc), -1.0), 1.0)
    sin_a = math.sqrt(max(0.0, 1.0 - cos_a * cos_a))
    w = pole - u * pole.dot(u)
    if w.length < 1e-6:
        w = u.orthogonal()
    w.normalize()
    return root + (u * cos_a + w * sin_a) * l1, root + u * dc, w, max(0.0, d - dc)


def solve(rig, spec, override=None):
    """Spec -> Solved (local rotations q, accumulated rotations D, joint positions P)."""
    out = Solved()
    q, D, P = out.q, out.D, out.P
    out.hips_loc = Vector(spec.get("hips_loc", (0, 0, 0)))
    head, parent = rig.head, rig.parent
    for name in rig.order:
        par = parent[name]
        Dp = D[par] if par else IDENT
        P[name] = (P[par] + Dp @ (head[name] - head[par])) if par else head[name] + out.hips_loc
        if name in D:
            q[name] = Dp.inverted() @ D[name]
            continue
        base, _, s = name.partition(".")
        if override is not None and name in override:
            q[name] = override[name]
            D[name] = Dp @ q[name]
        elif base == "Thigh" and ("foot." + s) in spec:
            side = 1 if s == "L" else -1
            goal = spec["foot." + s]
            yaw = goal.get("yaw", 0.0)
            pole = goal.get("pole")
            if pole is None:
                pole = Quaternion((0, 0, 1), math.radians(yaw * 0.6)) @ Vector((0.1 * side, -1.0, 0.05))
            shin, foot = "Shin." + s, "Foot." + s
            b0u, b0l = head[shin] - head[name], head[foot] - head[shin]
            mid, end, w, err = two_bone(P[name], Vector(goal["pos"]), b0u.length, b0l.length, Vector(pole).normalized())
            w0 = Vector((0, -1, 0))
            D[name] = (_frame((mid - P[name]).normalized(), w) @ _frame(b0u.normalized(), w0).transposed()).to_quaternion()
            D[shin] = (_frame((end - mid).normalized(), w) @ _frame(b0l.normalized(), w0).transposed()).to_quaternion()
            D[foot] = (Quaternion((0, 0, 1), math.radians(yaw)) @ Quaternion((1, 0, 0), math.radians(goal.get("pitch", 0.0)))
                       @ Quaternion((0, 1, 0), math.radians(goal.get("roll", 0.0))))
            q[name] = Dp.inverted() @ D[name]
            out.reach_error = max(out.reach_error, err)
        elif base == "UpperArm" and ("hand." + s) in spec:
            side = 1 if s == "L" else -1
            goal = spec["hand." + s]
            pole = goal.get("pole") or Vector((0.5 * side, 0.6, -0.6))
            fore, hand = "ForeArm." + s, "Hand." + s
            b0u, b0l = head[fore] - head[name], head[hand] - head[fore]
            mid, end, w, err = two_bone(P[name], Vector(goal["pos"]), b0u.length, b0l.length, Vector(pole).normalized())
            w0 = Vector((0, 1, 0))
            D[name] = (_frame((mid - P[name]).normalized(), w) @ _frame(b0u.normalized(), w0).transposed()).to_quaternion()
            D[fore] = (_frame((end - mid).normalized(), w) @ _frame(b0l.normalized(), w0).transposed()).to_quaternion()
            D[hand] = goal["rot"]
            q[name] = Dp.inverted() @ D[name]
            out.reach_error = max(out.reach_error, err)
        else:
            q[name] = as_q(spec.get(name, (0, 0, 0)))
            D[name] = Dp @ q[name]
    return out


# ---------------------------------------------------------------------------
# Pose vocabulary
# ---------------------------------------------------------------------------

UP_L = (ELBOW - SHOULDER).normalized()
HINGE_L = Vector((-UP_L.z, 0.0, UP_L.x))
CURL = {"relaxed": (20, 30), "open": (3, 5), "fist": (82, 96), "grip": (58, 72), "loose": (50, 58), "flat": (0, 0), "cup": (38, 46)}


def fingers(side, curl="relaxed", thumb=(8, 0)):
    """Finger curl (knuckle, middle joint) in degrees or a CURL name; thumb = (close, lift)."""
    a, b = CURL[curl] if isinstance(curl, str) else curl
    out = {"Fingers.L": Quaternion((0, 1, 0), math.radians(a)), "Fingers2.L": Quaternion((0, 1, 0), math.radians(b)),
           "Thumb.L": Quaternion(HAND_Z, -math.radians(thumb[0])) @ Quaternion(HAND_X, -math.radians(thumb[1]))}
    return out if side > 0 else {k[:-1] + "R": mirror_q(v) for k, v in out.items()}


def arm(side, out=0.25, fwd=0.05, up=-1.0, bend=18.0, twist=0.0, wrist=(0, 0, 0), curl="relaxed", thumb=(8, 0)):
    """FK arm: the upper arm points along (out, fwd, up), the elbow bends by `bend`,
    `twist` turns the bend inward (+) or outward (-), wrist = (rx, ry, rz) for a left hand."""
    d = Vector((out, -fwd, up)).normalized()
    pose = {"UpperArm.L": UP_L.rotation_difference(d) @ Quaternion(UP_L, math.radians(twist)),
            "ForeArm.L": Quaternion(HINGE_L, -math.radians(bend)), "Hand.L": eq(*wrist)}
    if side < 0:
        pose = {k[:-1] + "R": mirror_q(v) for k, v in pose.items()}
    pose.update(fingers(side, curl, thumb))
    return pose


def hand_basis(side):
    """Rest (fingers, palm normal) directions of a hand."""
    return sx(side, -HAND_Z), sx(side, -HAND_X)


def hand_rot(side, fingers_dir, palm_dir):
    """Rotation that points the hand's fingers along fingers_dir with the palm facing palm_dir."""
    f0, n0 = hand_basis(side)
    f1 = Vector(fingers_dir).normalized()
    n1 = Vector(palm_dir)
    n1 = (n1 - f1 * n1.dot(f1)).normalized()
    m0 = Matrix((f0, n0, f0.cross(n0))).transposed()
    m1 = Matrix((f1, n1, f1.cross(n1))).transposed()
    return (m1 @ m0.transposed()).to_quaternion()


def hand_goal(side, point, fingers_dir, palm_dir, anchor=(-0.027, 0.0, -0.065), pole=None):
    """IK goal that puts a spot of the hand (hand-frame `anchor`, default the palm
    centre) at `point` with the given orientation."""
    rot = hand_rot(side, fingers_dir, palm_dir)
    offset = hand_point(side, *anchor) - sx(side, WRIST)
    goal = dict(pos=Vector(point) - rot @ offset, rot=rot)
    if pole is not None:
        goal["pole"] = Vector(pole)
    return goal


def stand(shift=(0, 0, 0), hips=(0, 0, 0), spine=(0, 0, 0), chest=(0, 0, 0), head=(0, 0, 0), width=0.135, toes=10.0):
    return {"hips_loc": Vector(shift), "Hips": hips, "Spine": spine, "Chest": chest, "Head": head,
            "foot.L": dict(pos=Vector((width, 0.0, ANKLE.z)), yaw=toes), "foot.R": dict(pos=Vector((-width, 0.0, ANKLE.z)), yaw=-toes)}


def curve(s, keys):
    """Smooth piecewise interpolation through [(s, value)]."""
    if s <= keys[0][0]:
        return keys[0][1]
    for (s0, v0), (s1, v1) in zip(keys, keys[1:]):
        if s <= s1:
            u = (s - s0) / (s1 - s0)
            u = u * u * (3 - 2 * u)
            return v0 + (v1 - v0) * u
    return keys[-1][1]


# ---------------------------------------------------------------------------
# Procedural clips
# ---------------------------------------------------------------------------

def idle_spec(t, style=None):
    st = dict(bend=20.0, out=0.24, look=1.0, sway=1.0, lean=0.0, chin=0.0, width=0.135, twist=12.0, fwd=0.04)
    st.update(style or {})
    w = math.tau * t / IDLE_LEN
    s1, c1 = math.sin(w), math.cos(w)
    s2 = math.sin(2 * w + 0.6)
    breath = math.sin(2 * w - 0.4)
    sway = st["sway"]
    look = st["look"]
    glance = math.exp(-((t - 3.3) / 0.45) ** 2)
    spec = stand(shift=(0.02 + 0.016 * s1 * sway, 0.004 * s2, -0.012 - 0.004 * breath),
                 hips=(st["lean"] * 0.4, 1.6 + 2.0 * s1 * sway, 2.5 * s1 * sway),
                 spine=(1.0 + st["lean"] * 0.4 + 0.7 * breath, -1.6 * s1 * sway, -1.5 * s1 * sway),
                 chest=(0.6 + st["lean"] * 0.2 + 1.3 * breath, -1.0 * s1 * sway, -2.0 * s1 * sway),
                 head=(-2.0 + st["chin"] - 1.2 * breath + 1.5 * s2, 2.2 * c1, look * (9.0 * math.sin(w + 0.5) + 4.0 * s2 - 16.0 * glance)),
                 width=st["width"])
    spec.update(arm(1, st["out"] + 0.015 * breath, st["fwd"] + 0.03 * s1, -1.0, bend=st["bend"] + 4.0 * s2, twist=st["twist"],
                    wrist=(0, 4 + 3 * s1, 0)))
    spec.update(arm(-1, st["out"] + 0.015 * breath, st["fwd"] - 0.03 * s1, -1.0, bend=st["bend"] + 6.0 - 4.0 * s2, twist=st["twist"],
                    wrist=(0, 4 - 3 * s1, 0)))
    spec["Cape1"] = (3.0 + 2.0 * s2, 0, 2.0 * s1)
    spec["Cape2"] = (2.0 + 3.0 * math.sin(2 * w), 0, 2.0 * c1)
    return spec


_HEEL = Vector((0.0, 0.07, -ANKLE.z))      # pivot points relative to the ankle
_BALL = Vector((0.0, -0.125, -ANKLE.z))
_RUN_FRONT, _STANCE = -0.30, 0.4
_RUN_BACK = _RUN_FRONT + RUN_SPEED * RUN_LEN * _STANCE


def _run_stance(u):
    """Ankle (y, z) and pitch while the foot is on the ground (u = 0..1)."""
    y_flat = _RUN_FRONT + (_RUN_BACK - _RUN_FRONT) * u
    if u < 0.15:
        pitch, pivot = -14.0 * (1.0 - u / 0.15), _HEEL
    elif u > 0.6:
        k = (u - 0.6) / 0.4
        pitch, pivot = 42.0 * k * k, _BALL
    else:
        pitch, pivot = 0.0, _BALL
    v = Quaternion((1, 0, 0), math.radians(pitch)) @ (-pivot)
    return y_flat + pivot.y + v.y, v.z, pitch


def run_foot(side, phase):
    x = 0.1 * side
    if phase < _STANCE:
        y, z, pitch = _run_stance(phase / _STANCE)
    else:
        s = (phase - _STANCE) / (1.0 - _STANCE)
        y0, z0, p0 = _run_stance(1.0)
        y1, z1, p1 = _run_stance(0.0)
        m = RUN_SPEED * RUN_LEN * (1.0 - _STANCE)       # ground speed in swing units
        h00, h10 = 2 * s ** 3 - 3 * s ** 2 + 1, s ** 3 - 2 * s ** 2 + s
        h01, h11 = -2 * s ** 3 + 3 * s ** 2, s ** 3 - s ** 2
        y = h00 * y0 + h10 * m + h01 * y1 + h11 * m
        z = z0 + (z1 - z0) * s + 0.16 * math.sin(math.pi * s ** 0.85) ** 1.3
        pitch = curve(s, [(0.0, p0), (0.22, 60.0), (0.65, 12.0), (1.0, p1)])
    return dict(pos=Vector((x, y, z)), yaw=4.0 * side, pitch=pitch)


def run_spec(t):
    ph = (t / RUN_LEN) % 1.0
    w = math.tau * ph
    spec = {
        "hips_loc": Vector((0.012 * math.sin(w + 0.9), -0.02, -0.078 + 0.028 * math.cos(2 * (w - math.tau * 0.45)))),
        "Hips": (9.0, 2.5 * math.sin(w + 0.9), -8.0 * math.cos(w + 0.2)),
        "Spine": (5.0, -1.5 * math.sin(w + 0.9), 6.0 * math.cos(w + 0.2)),
        "Chest": (4.0, -1.0 * math.sin(w + 0.9), 9.0 * math.cos(w + 0.2)),
        "Head": (-13.0 + 1.5 * math.cos(2 * w), 0.0, -7.0 * math.cos(w + 0.2)),
        "foot.L": run_foot(1, ph), "foot.R": run_foot(-1, (ph + 0.5) % 1.0),
        "Cape1": (34.0 + 5.0 * math.sin(2 * w), 0, 4.0 * math.sin(w)),
        "Cape2": (12.0 + 8.0 * math.sin(2 * w - 1.0), 0, 5.0 * math.sin(w - 0.8)),
    }
    c = math.cos(w)
    spec.update(arm(1, 0.36, 0.08 - 0.72 * c, -1.0, bend=78.0 - 14.0 * c, twist=16.0, curl="loose", thumb=(20, 0)))
    spec.update(arm(-1, 0.36, 0.08 + 0.72 * c, -1.0, bend=78.0 + 14.0 * c, twist=16.0, curl="loose", thumb=(20, 0)))
    return spec


_SOCKET_M = weapon_socket_matrix()
_SOCKET_ROT = _SOCKET_M.to_3x3()
_SOCKET_OFFSET = _SOCKET_M.translation - sx(-1, WRIST)
# Weapon axes (right, forward, up) when aimed straight ahead of the operator.
_AIM_AXES = Matrix(((-1, 0, 0), (0, -1, 0), (0, 0, 1))).transposed()
SUPPORT = Vector((0.0, 0.16, -0.136))       # where the left palm meets the fore-end (weapon space)


def aim_frame(t, kick=0.0):
    """Weapon origin and axes (3x3: right, forward, up) in armature space."""
    b = math.sin(math.tau * t / AIM_LEN)
    b2 = math.sin(2 * math.tau * t / AIM_LEN + 1.0)
    origin = Vector((-0.15 + 0.003 * b2, -0.385 + 0.035 * kick, 1.17 + 0.006 * b + 0.018 * kick))
    rot = (Quaternion((1, 0, 0), -math.radians(1.2 * b + 7.0 * kick)) @ Quaternion((0, 0, 1), math.radians(0.8 * b2))).to_matrix()
    return origin, rot @ _AIM_AXES


def aim_spec(t, kick=0.0):
    b = math.sin(math.tau * t / AIM_LEN)
    origin, axes = aim_frame(t, kick)
    spec = {
        "hips_loc": Vector((0.0, -0.03 + 0.012 * kick, -0.065 + 0.004 * b)),
        "Hips": (5.0 - 2.0 * kick, 0.0, -22.0),
        "Spine": (3.0 - 2.0 * kick, 0.0, -8.0),
        "Chest": (3.0 + 0.8 * b - 3.0 * kick, -2.0, -10.0),
        "Head": (-6.0 + 3.0 * kick, -4.0, 37.0),
        "foot.L": dict(pos=Vector((0.12, -0.17, ANKLE.z)), yaw=-4.0),
        "foot.R": dict(pos=Vector((-0.17, 0.16, ANKLE.z)), yaw=-44.0),
        "Cape1": (8.0, 0, 0.0), "Cape2": (4.0, 0, 0.0),
    }
    rot_r = (axes @ _SOCKET_ROT.transposed()).to_quaternion()
    spec["hand.R"] = dict(pos=origin - rot_r @ _SOCKET_OFFSET, rot=rot_r, pole=Vector((-1.0, 0.1, -0.3)))
    spec["hand.L"] = hand_goal(1, origin + axes @ SUPPORT, axes @ Vector((0.94, 0.34, 0.0)), axes @ Vector((0.0, 0.0, 1.0)),
                               pole=(0.6, 0.05, -0.8))
    spec.update(fingers(-1, (84, 12), thumb=(2, -30)))
    spec.update(fingers(1, (10, 14), thumb=(-12, 0)))
    return spec


def fire_kick(t):
    tau = 0.042
    k = (t / tau) * math.exp(1.0 - t / tau)
    fade = min(max((0.5 - t) / 0.16, 0.0), 1.0)
    return k * fade * fade * (3 - 2 * fade)


# ---------------------------------------------------------------------------
# Keyed clips
# ---------------------------------------------------------------------------

def _merge(base, *updates):
    out = dict(base)
    for u in updates:
        out.update(u)
    return out


def body(spec, shift=None, hips=None, spine=None, chest=None, head=None):
    """Copy of a standing spec with some body entries replaced."""
    out = dict(spec)
    for key, value in (("hips_loc", shift), ("Hips", hips), ("Spine", spine), ("Chest", chest), ("Head", head)):
        if value is not None:
            out[key] = Vector(value) if key == "hips_loc" else value
    return out


def wave_keys(idle0):
    up = dict(out=1.0, fwd=0.18, up=0.16, twist=-88.0, curl="open", thumb=(-14, 8))
    lean = body(idle0, shift=(0.03, 0, -0.01), spine=(0, -3, -3), chest=(-2, -5, -7), head=(-5, -9, -8))
    left = arm(1, 0.3, 0.02, -1.0, bend=26, twist=14)
    keys = [(0.0, idle0),
            (0.36, _merge(lean, arm(-1, bend=88, wrist=(0, 0, 0), **up), left)),
            (0.62, _merge(lean, arm(-1, bend=54, wrist=(0, -10, 0), **up), left)),
            (0.88, _merge(lean, arm(-1, bend=90, wrist=(0, 10, 0), **up), left)),
            (1.14, _merge(lean, arm(-1, bend=54, wrist=(0, -10, 0), **up), left)),
            (1.4, _merge(lean, arm(-1, bend=86, wrist=(0, 6, 0), **up), left)),
            (1.9, idle0)]
    return keys, 1.9


def victory_keys(idle0):
    def feet(lift=0.0, pitch=0.0, width=0.135):
        return {"foot.L": dict(pos=Vector((width, -0.01 if lift else 0.0, ANKLE.z + lift)), yaw=10.0, pitch=pitch),
                "foot.R": dict(pos=Vector((-width, 0.02 if lift else 0.0, ANKLE.z + lift * 0.86)), yaw=-10.0, pitch=pitch)}
    crouch = _merge(body(idle0, shift=(0, -0.01, -0.13), hips=(10, 0, 0), spine=(8, 0, 0), chest=(6, 0, 0), head=(-10, 0, 0)), feet(),
                    arm(1, 0.3, -0.35, -1.0, bend=70, twist=10, curl="fist", thumb=(30, 0)),
                    arm(-1, 0.3, -0.35, -1.0, bend=70, twist=10, curl="fist", thumb=(30, 0)))
    high = dict(out=0.66, fwd=0.12, up=1.0, bend=14, twist=-40, curl="fist", thumb=(30, 0))
    air = _merge(body(idle0, shift=(0, 0, 0.2), hips=(-4, 0, 0), spine=(-5, 0, 0), chest=(-7, 0, 0), head=(-14, 0, 0)), feet(0.26, 34.0, 0.15),
                 arm(1, **high), arm(-1, **high))
    peak = _merge(body(air, shift=(0, 0, 0.27)), feet(0.34, 40.0, 0.16))
    land = _merge(body(idle0, shift=(0, 0, -0.09), hips=(7, 0, 0), spine=(5, 0, 0), chest=(2, 0, 0), head=(-6, 0, 0)), feet(),
                  arm(1, 0.55, 0.1, 0.75, bend=40, twist=-60, curl="fist", thumb=(30, 0)),
                  arm(-1, 0.55, 0.1, 0.75, bend=40, twist=-60, curl="fist", thumb=(30, 0)))
    pump_up = _merge(body(idle0, shift=(-0.01, 0, 0.0), spine=(-3, 2, 4), chest=(-5, 3, 6), head=(-10, 3, 6)), feet(),
                     arm(-1, 0.6, 0.2, 1.0, bend=24, twist=-50, curl="fist", thumb=(30, 0)),
                     arm(1, 0.34, 0.1, -1.0, bend=95, twist=20, curl="fist", thumb=(30, 0)))
    pump_down = _merge(body(idle0, shift=(-0.01, 0, -0.035), spine=(3, 2, 4), chest=(3, 3, 6), head=(2, 3, 6)), feet(),
                       arm(-1, 0.6, 0.35, -0.1, bend=128, twist=-78, curl="fist", thumb=(30, 0)),
                       arm(1, 0.34, 0.1, -1.0, bend=100, twist=20, curl="fist", thumb=(30, 0)))
    keys = [(0.0, idle0), (0.2, crouch), (0.36, air), (0.5, peak), (0.64, air), (0.8, land), (1.06, pump_up), (1.26, pump_down),
            (1.48, pump_up), (1.7, pump_down), (2.3, idle0)]
    return keys, 2.3


def pose_keys(style, idle0):
    """The signature flourish of each operator: (keys, length)."""
    rest_l = arm(1, 0.28, 0.02, -1.0, bend=24, twist=14)
    rest_r = arm(-1, 0.28, 0.02, -1.0, bend=24, twist=14)
    if style == "tip_hat":            # Boardwalk Ranger: two fingers to the hat brim and a nod
        def touch(dz):
            goal = hand_goal(-1, (-0.27, -0.375, 1.775 + dz), (0.4, 0.2, 0.9), (0.45, 0.88, -0.1), anchor=(-0.02, 0.0, -0.2), pole=(-0.7, -0.55, -0.45))
            return _merge({"hand.R": goal}, fingers(-1, (14, 20), thumb=(24, 0)))
        up = _merge(body(idle0, spine=(0, 0, 4), chest=(-2, 0, 6), head=(-4, -3, 8)), touch(0.0), rest_l)
        nod = _merge(body(up, head=(9, -3, 8), chest=(3, 0, 6)), touch(-0.05), rest_l)
        return [(0.0, idle0), (0.42, up), (0.74, nod), (1.05, up), (1.35, up), (1.9, idle0)], 1.9
    if style == "big_wave":           # Surf Rescue: arm high overhead, hand on hip
        hip = arm(1, 0.62, -0.28, -0.72, bend=96, twist=62, curl="fist", thumb=(20, 0))
        hi = dict(out=0.42, fwd=0.1, up=1.0, twist=-70, curl="open", thumb=(-14, 8))
        lean = body(idle0, shift=(-0.03, 0, 0), hips=(0, -3, 0), spine=(0, 4, 0), chest=(-3, 6, 4), head=(-8, 5, 6))
        a = _merge(lean, arm(-1, bend=34, wrist=(0, -14, 0), **hi), hip)
        b = _merge(lean, arm(-1, bend=4, wrist=(0, 12, 0), **hi), hip)
        return [(0.0, idle0), (0.4, a), (0.66, b), (0.92, a), (1.18, b), (1.44, a), (2.0, idle0)], 2.0
    if style == "thumbs_up":          # Neon Courier: leans in with a thumbs up
        out = dict(out=0.22, fwd=1.0, up=-0.12, bend=28, twist=62, curl="fist", thumb=(-30, 46))
        back = _merge(body(idle0, shift=(0.01, 0.01, -0.01), chest=(-2, 0, -6), head=(-3, 0, -4)),
                      arm(-1, 0.3, -0.2, -1.0, bend=96, twist=30, curl="fist", thumb=(-10, 20)), rest_l)
        hit = _merge(body(idle0, shift=(-0.02, -0.03, -0.02), hips=(3, 0, 4), spine=(4, 0, 6), chest=(4, -3, 10), head=(-6, -6, -6)),
                     arm(-1, wrist=(0, 0, 0), **out), arm(1, 0.3, -0.12, -1.0, bend=40, twist=20, curl="loose"))
        hold = _merge(hit, body(hit, head=(-4, -8, -8)), arm(-1, wrist=(0, 0, 8), **out))
        return [(0.0, idle0), (0.28, back), (0.52, hit), (0.8, hold), (1.3, hit), (1.9, idle0)], 1.9
    if style == "knock":              # Deep Diver: raps on the helmet, then an OK
        def rap(gap):
            goal = hand_goal(-1, (-0.36 - gap, -0.1, 1.72), (0.35, 0.1, 0.93), (0.95, 0.2, -0.2), anchor=(-0.03, 0.0, -0.12),
                             pole=(-0.8, -0.35, -0.5))
            return _merge({"hand.R": goal}, fingers(-1, "fist", thumb=(24, 0)))
        a = _merge(body(idle0, chest=(-2, 4, 4), head=(-4, 6, 6)), rap(0.06), rest_l)
        b = _merge(body(idle0, chest=(-2, 4, 4), head=(-2, 8, 6)), rap(0.012), rest_l)
        ok = _merge(body(idle0, chest=(-3, 0, 0), head=(-6, 0, 0)), arm(-1, 0.35, 0.8, 0.1, bend=96, twist=-10, curl="open", thumb=(-10, 20)),
                    rest_l)
        return [(0.0, idle0), (0.4, a), (0.56, b), (0.72, a), (0.88, b), (1.04, a), (1.4, ok), (1.75, ok), (2.3, idle0)], 2.3
    if style == "warm_hands":         # Frost Guard: rubs mittens together and gives a hop
        def rub(dz, dx):
            return _merge(arm(1, 0.16 + dx, 0.62, -0.58 + dz, bend=96, twist=56, wrist=(0, 24, 0), curl=(18, 24), thumb=(10, 0)),
                          arm(-1, 0.16 - dx, 0.62, -0.58 - dz, bend=96, twist=56, wrist=(0, 24, 0), curl=(18, 24), thumb=(10, 0)))
        hunch = body(idle0, shift=(0, 0, -0.03), spine=(5, 0, 0), chest=(6, 0, 0), head=(6, 0, 0))
        hop = body(idle0, shift=(0, 0, 0.0), chest=(-2, 0, 0), head=(-6, 0, 0))
        return [(0.0, idle0), (0.4, _merge(hunch, rub(0.03, 0.0))), (0.6, _merge(hunch, rub(-0.03, 0.0))), (0.8, _merge(hunch, rub(0.03, 0.0))),
                (1.0, _merge(hunch, rub(-0.03, 0.0))), (1.2, _merge(hunch, rub(0.03, 0.0))), (1.5, _merge(hop, rub(0.0, 0.06))),
                (2.1, idle0)], 2.1
    if style == "salute":             # Astro Cadet: crisp salute, heels together
        salute = _merge({"hand.R": hand_goal(-1, (-0.235, -0.18, 1.925), (0.75, 0.15, 0.65), (0.1, -0.9, -0.4), anchor=(-0.01, 0.0, -0.2),
                                            pole=(-0.9, -0.1, -0.4))}, fingers(-1, "flat", thumb=(22, 0)))
        tall = body(idle0, shift=(0, 0, 0.006), hips=(0, 0, 0), spine=(-2, 0, 0), chest=(-4, 0, 0), head=(-3, 0, 0))
        tall = _merge(tall, {"foot.L": dict(pos=Vector((0.118, 0.0, ANKLE.z)), yaw=14.0), "foot.R": dict(pos=Vector((-0.118, 0.0, ANKLE.z)), yaw=-14.0)})
        left = arm(1, 0.2, 0.0, -1.0, bend=6, twist=8, curl=(10, 14))
        sal = _merge(tall, salute, left)
        return [(0.0, idle0), (0.3, sal), (1.3, sal), (1.46, _merge(tall, arm(-1, 0.5, 0.5, -0.4, bend=60, twist=-10, curl="flat"), left)),
                (2.0, idle0)], 2.0
    if style == "ta_da":              # Midway Maestro: arms wide, then a showman's bow
        wide = _merge(body(idle0, shift=(0, 0, 0.0), spine=(-4, 0, 0), chest=(-8, 0, 0), head=(-10, 0, 0)),
                      arm(1, 1.0, 0.25, 0.42, bend=24, twist=-70, curl="open", thumb=(-14, 8)),
                      arm(-1, 1.0, 0.25, 0.42, bend=24, twist=-70, curl="open", thumb=(-14, 8)))
        bow = _merge(body(idle0, shift=(0, 0.05, -0.05), hips=(20, 0, 0), spine=(14, 0, 0), chest=(12, 0, 0), head=(4, 0, 0)),
                     arm(1, 1.0, -0.2, -0.3, bend=20, twist=-20, curl="open", thumb=(-14, 8)),
                     arm(-1, 0.3, 0.5, -0.8, bend=104, twist=58, curl="open", thumb=(0, 0)))
        return [(0.0, idle0), (0.36, wide), (0.8, wide), (1.2, bow), (1.65, bow), (2.3, idle0)], 2.3
    if style == "glitch":             # GL1TCH: snaps between poses like a skipping sprite
        a = _merge(body(idle0, chest=(0, 8, 10), head=(0, -16, 10)), arm(1, 1.0, 0.0, 0.1, bend=92, twist=-88, curl="open"),
                   arm(-1, 1.0, 0.0, -0.1, bend=92, twist=92, curl="open"))
        b = _merge(body(idle0, chest=(0, -8, -10), head=(0, 16, -10)), arm(1, 1.0, 0.0, -0.1, bend=92, twist=92, curl="open"),
                   arm(-1, 1.0, 0.0, 0.1, bend=92, twist=-88, curl="open"))
        c = _merge(body(idle0, shift=(0, 0, 0.01), chest=(-6, 0, 0), head=(-8, 0, 0)),
                   arm(1, 0.7, 0.2, 0.85, bend=30, twist=-60, curl="open"), arm(-1, 0.7, 0.2, 0.85, bend=30, twist=-60, curl="open"))
        return [(0.0, idle0), (0.14, a), (0.5, a), (0.6, b), (0.96, b), (1.06, c), (1.5, c), (1.62, idle0), (1.9, idle0)], 1.9
    # "flex": Arcade Champion's double biceps, chin up
    flex = dict(out=1.0, fwd=0.05, up=0.2, twist=-90, curl="fist", thumb=(30, 0))
    a = _merge(body(idle0, shift=(0, 0, 0.004), spine=(-4, 0, 0), chest=(-8, 0, 0), head=(-12, 0, 0)), arm(1, bend=112, **flex),
               arm(-1, bend=112, **flex))
    b = _merge(body(a, chest=(-8, 3, 8), head=(-12, -4, 14)), arm(1, bend=126, **flex), arm(-1, bend=104, **flex))
    c = _merge(body(a, chest=(-8, -3, -8), head=(-12, 4, -14)), arm(1, bend=104, **flex), arm(-1, bend=126, **flex))
    return [(0.0, idle0), (0.4, a), (0.8, b), (1.2, c), (1.55, a), (2.2, idle0)], 2.2


def _lerp_lower(a, b, u):
    out = {"hips_loc": Vector(a["hips_loc"]).lerp(Vector(b["hips_loc"]), u),
           "Hips": as_q(a["Hips"]).slerp(as_q(b["Hips"]), u)}
    for key in ("foot.L", "foot.R"):
        fa, fb = a[key], b[key]
        out[key] = dict(pos=Vector(fa["pos"]).lerp(Vector(fb["pos"]), u),
                        **{k: fa.get(k, 0.0) + (fb.get(k, 0.0) - fa.get(k, 0.0)) * u for k in ("yaw", "pitch", "roll")})
    return out


def keyed_frames(rig, keys, length):
    """Samples a keyed clip: the legs are re-solved every frame (feet stay put),
    the upper body blends between the solved key poses."""
    solved = [solve(rig, spec) for _t, spec in keys]
    upper = [n for n in rig.order if n not in LOWER]
    frames = []
    for f in range(int(round(length * FPS)) + 1):
        t = min(f / FPS, keys[-1][0])
        i = max(k for k in range(len(keys) - 1) if keys[k][0] <= t)
        t0, t1 = keys[i][0], keys[i + 1][0]
        u = (t - t0) / (t1 - t0)
        u = u * u * (3 - 2 * u)
        override = {n: solved[i].q[n].slerp(solved[i + 1].q[n], u) for n in upper}
        frames.append(solve(rig, _lerp_lower(keys[i][1], keys[i + 1][1], u), override))
    return frames


def build_clips(rig, pose_style, idle_style=None):
    """name -> list of Solved frames, for every clip of one operator."""
    clips = {}
    clips["Idle-loop"] = [solve(rig, idle_spec(f / FPS, idle_style)) for f in range(int(IDLE_LEN * FPS) + 1)]
    idle0 = idle_spec(0.0, idle_style)
    keys, length = pose_keys(pose_style, idle0)
    clips["Pose"] = keyed_frames(rig, keys, length)
    clips["Run-loop"] = [solve(rig, run_spec(f / FPS)) for f in range(int(round(RUN_LEN * FPS)) + 1)]
    clips["AimIdle-loop"] = [solve(rig, aim_spec(f / FPS)) for f in range(int(AIM_LEN * FPS) + 1)]
    clips["Fire"] = [solve(rig, aim_spec(0.0, fire_kick(f / FPS))) for f in range(int(0.5 * FPS) + 1)]
    keys, length = victory_keys(idle0)
    clips["Victory"] = keyed_frames(rig, keys, length)
    keys, length = wave_keys(idle0)
    clips["Wave"] = keyed_frames(rig, keys, length)
    return clips


def bake_clips(armature, clips):
    """Writes the solved frames as Blender actions (one NLA track per clip)."""
    ad = armature.animation_data_create()
    rest = {pb.name: pb.bone.matrix_local.to_quaternion() for pb in armature.pose.bones}
    for name, frames in clips.items():
        action = bpy.data.actions.new(name)
        ad.action = action
        last = {}
        for f, sol in enumerate(frames):
            for pb in armature.pose.bones:
                r = rest[pb.name]
                q = r.inverted() @ sol.q[pb.name] @ r
                if pb.name in last and last[pb.name].dot(q) < 0.0:
                    q.negate()
                last[pb.name] = q
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=f)
                if pb.name == "Hips":
                    pb.location = r.inverted() @ sol.hips_loc
                    pb.keyframe_insert("location", frame=f)
        track = ad.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, action)
        # Nothing plays outside the strips, so frame -1 is the rest pose (see export()).
        strip.extrapolation = "NOTHING"
        ad.action = None
    for pb in armature.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
