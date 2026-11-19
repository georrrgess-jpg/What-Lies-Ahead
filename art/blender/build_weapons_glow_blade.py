"""First-person viewmodel of the Glow Blade (glow_blade), the default melee
weapon: a neon switchblade. A slim black handle with arcade-cabinet trim
(glowing T-molding down both edges, purple side scales, a gold bolster with
two arcade buttons and a coin slot, an arcade joystick for a pommel) and a
dark steel clip-point blade with a glowing edge, flicked open on a hinge.

Built the way build_weapons.py builds guns (see the node contract at the top
of weapon_kit.py) so finishes and charms work, but held like a knife. It is
modelled standing (handle along +Z, the right hand's fist round it, the edge
on the +Y side where the fingers close) and then laid down like a gun
(lay_down): the blade points along +Y like a barrel, the edge down, so the
Arsenal, Locker and thumbnails show it side-on like every weapon. The view
(view_rotation_degrees) stands it back up in the hand. No sights, no cell, no
decal.
Moving parts, driven by scripts/weapons/views/glow_blade_view.gd:

  Blade       the blade and its glowing edge (pivot on the hinge pin, axis X):
              rotated -165 degrees about X it lies folded along the handle's
              front; the view flicks it open on equip
  BladeEdge   the glowing edge (child of Blade; the view gives it an
              additive, translucent glow material)
  Buttons     the two arcade buttons (pressed in as the blade flicks)

Empties: Muzzle and BladeTip (the point of the blade, child of Blade),
SwingPoint (middle of the edge, where the view draws the swing trail; child of
Blade), CharmPoint, ElbowR.

    python art/blender/build_weapons_glow_blade.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403

## Handle: half width (X), half depth (Y), bottom and top (Z).
HX = 0.0135
HY = 0.02
H_BOTTOM = -0.08
H_TOP = 0.05
## The hinge pin (Y, Z) and the blade's length from it.
HINGE = (0.003, 0.06)
BLADE_LEN = 0.205


def palette():
    """The shared weapon materials in this weapon's colours."""
    mat("Shell", "#17141f", rough=0.42, metal=0.2)
    mat("Trim", "#5a2bd6", rough=0.34)
    mat("GunDark", "#0f0d16", rough=0.5, metal=0.3)
    mat("GunSteel", "#f2b632", rough=0.28, metal=0.7)
    mat("GunPink", "#ff3f9f", rough=0.36)


def blade_profile(scale=1.0, front=0.0):
    """The clip-point blade's side view [(y, z)] from the hinge, pushed out
    `front` metres along the edge side."""
    pts = [(-0.011, -0.008), (0.012 + front, -0.008), (0.0155 + front, 0.022), (0.0158 + front, 0.112),
           (0.0136 + front, 0.152), (0.0092 + front, 0.182), (0.003 + front * 0.6, BLADE_LEN), (-0.0035, 0.19),
           (-0.009, 0.165), (-0.011, 0.142)]
    return [(y * scale, z * scale) for y, z in pts]


def lay_down(groups, empties):
    """Turns the standing model -90 degrees about X (the blade to +Y, the edge down)."""
    rot = Matrix.Rotation(math.radians(-90.0), 4, "X")
    for parts, _pivot, _parent in groups.values():
        for p in parts:
            p.matrix_world = rot @ p.matrix_world
    turned = {k: (parts, tuple(rot @ Vector(pivot)), parent) for k, (parts, pivot, parent) in groups.items()}
    placed = {k: (tuple(rot @ Vector(loc)), parent) for k, (loc, parent) in empties.items()}
    return turned, placed


def build_glow_blade():
    reset_scene()
    palette()
    M = weapon_mats("#ff3fd2", emit=2.4)
    glow = mat("BladeGlow", "#7ff6ff", rough=0.2, emit=4.0)
    blade_m = mat("BladeSteel", "#2c2a3a", rough=0.22, metal=0.85)
    red = mat("ArcadeRed", "#ff2a4a", rough=0.3, emit=0.6)
    cyan_btn = mat("ArcadeCyan", "#2ef2ff", rough=0.3, emit=0.9)
    slot_m = mat("CoinSlot", "#ffcf3a", rough=0.3, emit=2.0)
    hz = (H_TOP + H_BOTTOM) / 2
    hl = H_TOP - H_BOTTOM
    hy, hzp = HINGE

    shell = [
        # The handle: a black core with purple side scales.
        box("HandleCore", (HX * 2, HY * 2, hl), (0, 0, hz), bevel=0.008, m=M["shell"]),
        box("ScaleR", (0.004, HY * 1.55, hl * 0.78), (HX + 0.0005, 0, hz - 0.004), bevel=0.0018, m=M["trim"]),
        box("ScaleL", (0.004, HY * 1.55, hl * 0.78), (-HX - 0.0005, 0, hz - 0.004), bevel=0.0018, m=M["trim"]),
        # The gold bolster round the hinge, and the blade's slot in its front.
        box("Bolster", (HX * 2 + 0.004, HY * 2 + 0.004, 0.026), (0, 0, H_TOP - 0.004), bevel=0.006, m=M["steel"]),
        box("BolsterCap", (HX * 2 + 0.001, HY * 2 - 0.006, 0.008), (0, -0.003, H_TOP + 0.01), bevel=0.0035, m=M["steel"]),
        box("BladeSlot", (0.008, 0.012, hl * 0.8), (0, HY - 0.002, hz + 0.004), bevel=0.002, m=M["dark"]),
        # Coin slot on the bolster's back (the side facing the player).
        box("CoinPlate", (0.02, 0.004, 0.016), (0, -HY - 0.002, H_TOP - 0.004), bevel=0.002, m=M["dark"]),
        box("CoinSlit", (0.0025, 0.0045, 0.01), (0, -HY - 0.0028, H_TOP - 0.004), bevel=0.0, m=slot_m),
        # The butt: a joystick gate plate, a steel stick and a red ball top.
        box("GatePlate", (HX * 2 + 0.006, HY * 2 + 0.006, 0.01), (0, 0, H_BOTTOM - 0.002), bevel=0.004, m=M["dark"]),
        cyl("StickShaft", 0.0048, 0.022, (0, 0, H_BOTTOM - 0.016), segs=12, bevel=0.0, m=M["steel"]),
        cyl("StickBoot", 0.0105, 0.008, (0, 0, H_BOTTOM - 0.009), segs=16, bevel=0.002, m=M["dark"]),
        sphere("StickBall", 0.0145, (0, 0, H_BOTTOM - 0.035), m=red, segs=20, rings=12),
        sphere("StickBallShine", 0.004, (-0.006, -0.009, H_BOTTOM - 0.029), m=mat("Shine", "#ffd0dc", rough=0.1, emit=1.5), segs=8, rings=5),
        # The hinge pin through the bolster, glowing at both ends.
        xcyl("HingePin", 0.0062, HX * 2 + 0.008, (0, hy, hzp), m=M["dark"], segs=16),
        xcyl("HingeGlowR", 0.0042, 0.002, (HX + 0.0046, hy, hzp), m=M["cell"], segs=14, bevel=0.0),
        xcyl("HingeGlowL", 0.0042, 0.002, (-HX - 0.0046, hy, hzp), m=M["cell"], segs=14, bevel=0.0),
    ]
    # Glowing T-molding down the handle's front and back edges, like a cabinet's.
    for side, name in ((1, "Front"), (-1, "Back")):
        shell.append(box(f"Molding{name}", (HX * 2 + 0.0015, 0.003, hl * 0.86), (0, side * (HY + 0.0004), hz - 0.004), bevel=0.001, m=M["cell"]))
    # Rivets in the scales.
    shell += bolts("Rivet", [(HX + 0.003, 0.0, H_BOTTOM + 0.014), (-HX - 0.003, 0.0, H_BOTTOM + 0.014),
                             (HX + 0.003, 0.0, H_TOP - 0.024), (-HX - 0.003, 0.0, H_TOP - 0.024)], M["steel"], radius=0.0032, height=0.003)
    lug, charm_point = charm_lug(-HX - 0.002, 0.0, H_BOTTOM + 0.006, M)
    shell += lug

    # The two arcade buttons on the bolster's left face (the side the player sees).
    buttons = []
    for i, (z, m) in enumerate(((H_TOP - 0.002, red), (H_TOP - 0.002, cyan_btn))):
        y = -0.008 + i * 0.016
        buttons.append(xcyl(f"ButtonRing{i}", 0.0062, 0.003, (-HX - 0.0035, y, z), m=M["dark"], segs=14, bevel=0.0))
        buttons.append(sphere(f"ButtonCap{i}", 0.0048, (-HX - 0.0048, y, z), scale=(0.55, 1, 1), m=m, segs=12, rings=7))

    # The blade, built open (pointing up), from the hinge.
    blade = [
        side_profile("BladeBody", blade_profile(), 0.0058, (0, hy, hzp), blade_m, bevel=0.0012),
        # A neon pink line down the spine on both flats, and a dark fuller.
        box("SpineGlowR", (0.0012, 0.0028, 0.11), (0.0029, hy - 0.0072, hzp + 0.075), bevel=0.0, m=M["cell"]),
        box("SpineGlowL", (0.0012, 0.0028, 0.11), (-0.0029, hy - 0.0072, hzp + 0.075), bevel=0.0, m=M["cell"]),
        box("FullerR", (0.0008, 0.005, 0.08), (0.0029, hy + 0.0, hzp + 0.07), bevel=0.0, m=M["dark"]),
        box("FullerL", (0.0008, 0.005, 0.08), (-0.0029, hy + 0.0, hzp + 0.07), bevel=0.0, m=M["dark"]),
        # The tang's thumb stud, for the flick.
        xcyl("ThumbStud", 0.0032, 0.012, (0, hy - 0.006, hzp + 0.018), m=M["steel"], segs=10),
    ]
    edge = [side_profile("BladeEdgeGlow", blade_profile(front=0.0035), 0.0024, (0, hy, hzp), glow, bevel=0.0)]

    # The right hand round the handle: palm on the back and right side,
    # fingers closing round the front, thumb over the left side.
    fr = frame((0, 0, 0), (1, 0, 0), (0, 1, 0))
    bar = (HX + 0.0045, HY + 0.003, 0.011)
    r = FINGER_R
    pitch = 2 * r + 0.0015
    top_finger = H_TOP - 0.024 - GAP - r
    finger_z = [top_finger - i * pitch for i in range(4)]
    z0 = finger_z[-1] - r - 0.004
    z1 = H_TOP - 0.02
    thumb = dict(z=top_finger + 0.006, length=0.06)
    arm_r, elbow_r = hand("R", fr, bar, M, (0.2, -0.62, -0.12), finger_z, (z0, z1), s_web=2.85, palm_len=0.09,
                          finger_len=0.078, thumb=thumb, wrist_s=3.5, wrist_z=z0 + 0.045)

    tip = (0, hy + 0.003, hzp + BLADE_LEN)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "Buttons": (buttons, (-HX, 0, H_TOP), None),
        "Blade": (blade, (0, hy, hzp), None),
        "BladeEdge": (edge, (0, hy, hzp), "Blade"),
        "ArmR": (arm_r, (0, 0, hz), None),
    }
    empties = {
        "Muzzle": (tip, "Blade"),
        "BladeTip": (tip, "Blade"),
        "SwingPoint": ((0, hy + 0.012, hzp + BLADE_LEN * 0.55), "Blade"),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
    }
    groups, empties = lay_down(groups, empties)
    finish("glow_blade", groups, empties)


if __name__ == "__main__":
    build_glow_blade()
