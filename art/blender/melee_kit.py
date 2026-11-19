"""Shared pieces of the melee weapon models (build_weapons_<id>.py for the
knives, clubs and mallets of the melee slot).

Same node contract as the guns (weapon_kit.py) where it applies: the shared
material names ("Shell", "Trim", "Cell", "GunDark", "GunSteel", "GunPink",
arms "Glove", "GloveTip", "GlovePlate", "Cuff", "Sleeve"), so every weapon
finish, prize print, charm and gloves cosmetic works on them. Melee models
have no sights, rail, magazine or muzzle. Their contract:

  Origin      the centre of the main hand's grip on the handle; the weapon's
              working end (blade tip, club head) points along +Y (Blender),
              -Z in Godot, its striking edge or face towards -Z (Blender).
  ArmR        the main hand (a fist round the handle), with ElbowR;
              ArmL / ElbowL on two-handed weapons.
  Muzzle      empty at the striking point (hit FX).
  BladeTip    empty at the far end of the striking part, SwingPoint nearer
              the hand: MeleeView draws the swing smear between them.
  CharmPoint  the eye of a charm lug near the pommel.
  Animated    each weapon's own moving parts (origin = pivot), named in its
              build script.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403
from weapon_kit import GAP, FINGER_R, _digit  # noqa: E402


def fist(prefix, centre, forward, right, bar, M, toward, z_back, z_front, palm_s=(3.85, 0.075), finger_len=0.085,
         thumb=None, wrist=(0.1, 0.04, 0.05)):
    """A gloved fist round a handle running along `forward` through `centre`.

    Works in a frame whose X is `right`, Y = forward x right (the underside
    of the handle) and Z = `forward`, so `s` (weapon_kit.wrap_point) runs
    0 = right side, 1 = underside, 2 = left side, 3 = top. The palm wraps
    from palm_s[0] for palm_s[1] metres (down the right side), the fingers
    carry on under the handle and up its left side, between z_back and
    z_front along it (the index finger in front).
    thumb: None lays it along the top right edge, pointing forward (it stays
           outside the handle's width, so a part may turn over the top);
           "wrap" wraps it over the top towards the left.
    wrist: (s, z from z_back, offset out of the bar) where the wrist leaves.
    Returns (parts, elbow_point).
    """
    fwd = Vector(forward).normalized()
    x = Vector(right).normalized()
    fr = frame(centre, x, fwd.cross(x))
    a, b, _c = bar
    r = FINGER_R
    pitch = 2 * r + 0.0012
    finger_z = [z_front - r - 0.004 - i * pitch for i in range(4)]
    z0 = min(z_back, finger_z[-1] - r - 0.004)
    if thumb == "wrap":
        th = dict(z=z_front - 0.03, length=0.07, lean=0.012)
    else:
        rt = 0.0135
        tx, ty = a + GAP + rt * 0.8, -b + rt * 0.45
        th = dict(points=[(tx + 0.004, ty + 0.006, z0 + 0.03), (tx + 0.001, ty, z0 + 0.055), (tx, ty - 0.002, z_front - 0.01),
                          (tx - 0.002, ty - 0.001, z_front + 0.016)], radius=rt)
    ws, wz, wout = wrist
    return hand(prefix, fr, bar, M, toward, finger_z, (z0, z_front), s_web=palm_s[0], palm_len=palm_s[1],
                finger_len=finger_len, thumb=th, wrist_s=ws, wrist_z=z0 + wz, wrist_out=wout)


def spiral_band(name, radius, minor, y0, y1, turns, m, x=0.0, z=0.0, segs=8, phase=0.0, steps_per_turn=24):
    """A round ribbon wound `turns` times round a stick along +Y (radius = stick + ribbon)."""
    n = max(4, int(turns * steps_per_turn))
    pts = []
    for i in range(n + 1):
        t = i / n
        a = phase + math.tau * turns * t
        pts.append((x + math.cos(a) * radius, y0 + (y1 - y0) * t, z + math.sin(a) * radius))
    return tube(name, pts, minor, m=m, segs=segs)


def melee_lug(x, y, z, M, out=-1.0):
    """A small ring on a stalk sticking out of the left of a handle, for a charm.
    Returns (parts, charm_point)."""
    eye = (x + out * CHARM_STANDOFF, y, z)
    parts = [
        cyl("LugStalk", 0.004, CHARM_STANDOFF, (x + out * CHARM_STANDOFF * 0.5, y, z), rot=rad(0, 90, 0), segs=10, bevel=0.001, m=M["steel"]),
        torus("LugRing", 0.0065, 0.0018, eye, rot=rad(90, 0, 0), m=M["steel"], major_segs=16, minor_segs=5),
    ]
    return parts, eye
