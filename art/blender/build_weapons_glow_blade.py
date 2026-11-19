"""First-person viewmodel of the Glow Blade (glow_blade), the default melee
weapon: a premium neon switchblade. A black handle between magenta scales
with inlaid light strips and LED pips, a knurled butt, gold bolsters front
and back, glowing arcade T-molding down both edges, a flip-button with an
LED, a coin slot, a chrome pocket clip and an arcade joystick for a pommel;
a clip-point blade with a satin spine flat (fuller, neon spine line and a
hologram lightning etching), a bright bevel down to a glowing edge core
(Cell, so a cell cosmetic recolours it) under a translucent glow halo.

Built the way build_weapons.py builds guns (see the node contract at the top
of weapon_kit.py) so finishes and charms work, but held like a knife. It is
modelled standing (handle along +Z, the right hand's fist round it, the edge
on the +Y side where the fingers close) and then laid down like a gun
(lay_down): the blade points along +Y like a barrel, the edge down, so the
Arsenal, Locker and thumbnails show it side-on like every weapon. The view
(view_rotation_degrees) stands it back up in the hand. No sights, no decal.
Moving parts, driven by scripts/weapons/views/glow_blade_view.gd:

  Knife       everything but the hand (pivot at the grip centre): the inspect
              tricks toss and roll it out of the fist
  Blade       the blade (child of Knife; pivot on the hinge pin, axis X):
              rotated -165 degrees about X it lies folded along the handle's
              front; the view flicks it open on equip
  BladeEdge   the glow halo along the edge (child of Blade; the view gives it
              an additive, translucent glow in the edge core's Cell colour)
  Buttons     the flip-button and its LED (child of Knife; pressed in as the
              blade flicks)

Empties: Muzzle and BladeTip (the point of the blade, child of Blade),
SwingPoint (middle of the edge, where the view draws the swing trail; child of
Blade), CharmPoint (child of Knife), ElbowR.

    python art/blender/build_weapons_glow_blade.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403

## Handle: half width (X), half depth (Y), bottom and top (Z). The fist
## covers it down to about -0.084; the butt below shows the knurled grip,
## the rear bolster and the pocket clip.
HX = 0.0135
HY = 0.02
H_BOTTOM = -0.106
H_TOP = 0.05
## The hinge pin (Y, Z) and the blade's length from it.
HINGE = (0.003, 0.06)
BLADE_LEN = 0.218
## Blade thickness: the spine's flats, the bevel's, the glowing edge halo's.
SPINE_W = 0.0062
GRIND_W = 0.0036
EDGE_W = 0.0016
## The edge line, hinge to tip [(y, z)], and the grind line (where the bevel
## meets the flat) inside it.
EDGE = [(0.0172, 0.03), (0.0182, 0.07), (0.018, 0.11), (0.0162, 0.15), (0.0112, 0.188), (0.003, BLADE_LEN)]
GRIND = [(0.0082, 0.036), (0.0088, 0.07), (0.0088, 0.11), (0.0068, 0.148), (0.0028, 0.184), (0.003, BLADE_LEN)]
## The spine from the tip back to the tang (a clip point).
SPINE = [(-0.0045, 0.2), (-0.0105, 0.172), (-0.013, 0.15), (-0.013, 0.02), (-0.012, -0.009)]


def palette():
    """The shared weapon materials in this weapon's colours."""
    mat("Shell", "#141019", rough=0.38, metal=0.25)
    mat("Trim", "#b4148c", rough=0.3, metal=0.15)
    mat("GunDark", "#0c0a12", rough=0.55, metal=0.3)
    mat("GunSteel", "#f5b83a", rough=0.24, metal=0.8)
    mat("GunPink", "#ff3f9f", rough=0.36)


def offset_line(line, dy):
    """`line` pushed `dy` along Y (toward the edge side), its tip kept."""
    return [(y + dy, z) for y, z in line[:-1]] + [line[-1]]


def lay_down(groups, empties):
    """Turns the standing model -90 degrees about X (the blade to +Y, the edge down)."""
    rot = Matrix.Rotation(math.radians(-90.0), 4, "X")
    bpy.context.view_layer.update()
    for parts, _pivot, _parent in groups.values():
        for p in parts:
            p.matrix_world = rot @ p.matrix_world
    turned = {k: (parts, tuple(rot @ Vector(pivot)), parent) for k, (parts, pivot, parent) in groups.items()}
    placed = {k: (tuple(rot @ Vector(loc)), parent) for k, (loc, parent) in empties.items()}
    return turned, placed


def blade_parts(M, hy, hzp):
    """The blade, built open (pointing up) from the hinge: a thick spine flat
    with a fuller, a neon spine line and a hologram etching, a thinner bright
    bevel down to the edge, a glowing core along the edge (Cell) and the
    thumb stud. Returns (blade parts, edge halo parts)."""
    steel = mat("BladeSteel", "#9d98b8", rough=0.2, metal=0.85)
    bevel_m = mat("BladeBevel", "#e4e1f2", rough=0.14, metal=0.9)
    etch = mat("BladeEtch", "#ff4fd8", rough=0.3, emit=2.2)
    at = (0, hy, hzp)
    body = [(0.014, -0.009), (0.0172, 0.03)] + GRIND + SPINE
    grind = EDGE + list(reversed(GRIND[:-1]))
    core = offset_line(EDGE, 0.0016) + list(reversed(offset_line(EDGE, -0.0022)[:-1]))
    halo = offset_line(EDGE, 0.0055) + list(reversed(offset_line(EDGE, -0.001)[:-1]))
    parts = [
        side_profile("BladeBody", body, SPINE_W, at, steel, bevel=0.0),
        side_profile("BladeGrind", grind, GRIND_W, at, bevel_m, bevel=0.0),
        side_profile("BladeCore", core, EDGE_W + 0.0006, at, M["cell"], bevel=0.0),
        # A neon line down the spine on both flats, and a dark fuller under it.
        box("SpineGlowR", (0.0008, 0.0026, 0.12), (SPINE_W / 2, hy - 0.0098, hzp + 0.085), bevel=0.0, m=M["cell"]),
        box("SpineGlowL", (0.0008, 0.0026, 0.12), (-SPINE_W / 2, hy - 0.0098, hzp + 0.085), bevel=0.0, m=M["cell"]),
        box("FullerR", (0.0008, 0.0042, 0.075), (SPINE_W / 2, hy - 0.002, hzp + 0.07), bevel=0.0, m=M["dark"]),
        box("FullerL", (0.0008, 0.0042, 0.075), (-SPINE_W / 2, hy - 0.002, hzp + 0.07), bevel=0.0, m=M["dark"]),
        # The tang's thumb stud, for the flick, with glowing caps.
        xcyl("ThumbStud", 0.0034, SPINE_W + 0.009, (0, hy - 0.007, hzp + 0.017), m=M["steel"], segs=12),
        xcyl("ThumbStudCapR", 0.0024, 0.0012, (SPINE_W / 2 + 0.005, hy - 0.007, hzp + 0.017), m=M["cell"], segs=10, bevel=0.0),
        xcyl("ThumbStudCapL", 0.0024, 0.0012, (-SPINE_W / 2 - 0.005, hy - 0.007, hzp + 0.017), m=M["cell"], segs=10, bevel=0.0),
    ]
    # The hologram etching on both flats: a lightning bolt between scan lines.
    bolt = [(0.0, 0.0), (0.006, 0.0), (0.001, 0.016), (0.0065, 0.016), (-0.004, 0.04), (0.0, 0.022), (-0.0055, 0.022)]
    for side, tag in ((1, "R"), (-1, "L")):
        x = side * (SPINE_W / 2 + 0.0002)
        parts.append(side_profile(f"EtchBolt{tag}", [(y - 0.003, z) for y, z in bolt], 0.0005, (x, hy, hzp + 0.112), etch, bevel=0.0))
        for i in range(3):
            parts.append(box(f"EtchLine{tag}{i}", (0.0005, 0.011 - i * 0.003, 0.0011), (x, hy - 0.004 + i * 0.0015, hzp + 0.1 - i * 0.006),
                             bevel=0.0, m=etch))
        parts.append(box(f"EtchTop{tag}", (0.0005, 0.007, 0.0011), (x, hy - 0.003, hzp + 0.162), bevel=0.0, m=etch))
    edge = [side_profile("BladeEdgeGlow", halo, EDGE_W, at, mat("BladeGlow", "#7ff6ff", rough=0.2, emit=4.0), bevel=0.0)]
    return parts, edge


def handle_parts(M):
    """The handle: a black core between magenta scales with inlaid light
    strips and LED pips and a knurled butt, gold bolsters front and back,
    arcade T-molding down both edges, a coin slot, a pocket clip and an
    arcade joystick for a pommel. Returns (parts, charm point)."""
    red = mat("ArcadeRed", "#ff2a4a", rough=0.25, emit=0.6)
    slot_m = mat("CoinSlot", "#ffcf3a", rough=0.3, emit=2.0)
    chrome = mat("Chrome", "#d9d6e8", rough=0.12, metal=0.95)
    hz = (H_TOP + H_BOTTOM) / 2
    hl = H_TOP - H_BOTTOM
    hy, hzp = HINGE
    scale_z0, scale_z1 = H_BOTTOM + 0.016, H_TOP - 0.026
    sz = (scale_z0 + scale_z1) / 2
    sl = scale_z1 - scale_z0
    parts = [
        box("HandleCore", (HX * 2, HY * 2, hl), (0, 0, hz), bevel=0.007, m=M["shell"]),
        box("BladeSlot", (0.008, 0.012, hl * 0.82), (0, HY - 0.002, hz + 0.006), bevel=0.002, m=M["dark"]),
        # Front bolster round the hinge, rear bolster at the butt (gold).
        box("Bolster", (HX * 2 + 0.005, HY * 2 + 0.005, 0.03), (0, 0, H_TOP - 0.006), bevel=0.0065, m=M["steel"]),
        box("BolsterCap", (HX * 2 + 0.001, HY * 2 - 0.006, 0.008), (0, -0.003, H_TOP + 0.011), bevel=0.0035, m=M["steel"]),
        box("BolsterRear", (HX * 2 + 0.005, HY * 2 + 0.005, 0.016), (0, 0, H_BOTTOM + 0.006), bevel=0.0055, m=M["steel"]),
        # Coin slot on the bolster's back.
        box("CoinPlate", (0.02, 0.004, 0.016), (0, -HY - 0.003, H_TOP - 0.006), bevel=0.002, m=M["dark"]),
        box("CoinSlit", (0.0025, 0.0045, 0.01), (0, -HY - 0.0038, H_TOP - 0.006), bevel=0.0, m=slot_m),
        # Pommel: a joystick gate plate, a chrome stick, a lit ring and a red ball top.
        box("GatePlate", (HX * 2 + 0.002, HY * 2 + 0.002, 0.006), (0, 0, H_BOTTOM - 0.004), bevel=0.0025, m=M["dark"]),
        cyl("StickShaft", 0.0045, 0.02, (0, 0, H_BOTTOM - 0.014), segs=12, bevel=0.0, m=chrome),
        cyl("StickBoot", 0.0098, 0.007, (0, 0, H_BOTTOM - 0.009), segs=16, bevel=0.002, m=M["dark"]),
        torus("StickRing", 0.0098, 0.0014, (0, 0, H_BOTTOM - 0.0125), m=M["cell"], major_segs=18, minor_segs=5),
        sphere("StickBall", 0.0128, (0, 0, H_BOTTOM - 0.031), m=red, segs=20, rings=12),
        sphere("StickBallShine", 0.0036, (-0.0055, -0.008, H_BOTTOM - 0.026), m=mat("Shine", "#ffd0dc", rough=0.1, emit=1.5), segs=8, rings=5),
        # The hinge pin through the bolster, glowing at both ends.
        xcyl("HingePin", 0.0062, HX * 2 + 0.009, (0, hy, hzp), m=M["dark"], segs=16),
        xcyl("HingeGlowR", 0.0042, 0.002, (HX + 0.0052, hy, hzp), m=M["cell"], segs=14, bevel=0.0),
        xcyl("HingeGlowL", 0.0042, 0.002, (-HX - 0.0052, hy, hzp), m=M["cell"], segs=14, bevel=0.0),
    ]
    for side, tag in ((1, "R"), (-1, "L")):
        x = side * (HX + 0.0012)
        # The scale, its inlaid light strip (a lit groove in a dark channel),
        # three LED pips, and the knurled ribs across the butt.
        parts.append(box(f"Scale{tag}", (0.0042, HY * 1.6, sl), (x, 0, sz), bevel=0.0016, m=M["trim"]))
        parts.append(box(f"Channel{tag}", (0.0012, 0.0056, sl * 0.86), (x + side * 0.0019, -0.004, sz + 0.002), bevel=0.0, m=M["dark"]))
        parts.append(box(f"LightStrip{tag}", (0.0014, 0.0024, sl * 0.82), (x + side * 0.0022, -0.004, sz + 0.002), bevel=0.0, m=M["cell"]))
        for i in range(3):
            parts.append(sphere(f"Pip{tag}{i}", 0.0016, (x + side * 0.0022, 0.009, scale_z1 - 0.008 - i * 0.006), m=M["pink"], segs=8, rings=5))
        for i in range(6):
            parts.append(box(f"Knurl{tag}{i}", (0.0014, HY * 1.45, 0.0018), (x + side * 0.0021, 0.002, scale_z0 + 0.003 + i * 0.0036),
                             bevel=0.0005, m=M["dark"]))
    # Glowing T-molding down the handle's front and back edges, like a cabinet's.
    for side, name in ((1, "Front"), (-1, "Back")):
        parts.append(box(f"Molding{name}", (HX * 2 + 0.0015, 0.003, hl * 0.74), (0, side * (HY + 0.0004), hz + 0.001), bevel=0.001, m=M["cell"]))
    # The pocket clip down the right side of the butt, on two screws.
    clip_z0, clip_z1 = H_BOTTOM + 0.002, H_BOTTOM + 0.05
    clip_x = HX + 0.0048
    parts += [
        box("ClipFoot", (0.0024, 0.011, 0.012), (clip_x - 0.0006, -0.006, clip_z0 + 0.006), bevel=0.0012, m=chrome),
        box("ClipArm", (0.0016, 0.0085, clip_z1 - clip_z0), (clip_x + 0.0006, -0.006, (clip_z0 + clip_z1) / 2), bevel=0.0007, m=chrome),
        sphere("ClipTip", 0.0034, (clip_x + 0.0006, -0.006, clip_z1), scale=(0.5, 1.0, 1.0), m=chrome, segs=10, rings=6),
    ]
    parts += bolts("ClipScrew", [(clip_x + 0.0012, -0.006, clip_z0 + 0.003), (clip_x + 0.0012, -0.006, clip_z0 + 0.0095)], M["steel"],
                   radius=0.0018, height=0.0016)
    parts += bolts("Rivet", [(-HX - 0.0034, 0.009, H_BOTTOM + 0.032), (-HX - 0.0034, 0.009, H_TOP - 0.03),
                             (HX + 0.0034, 0.009, H_TOP - 0.03)], M["steel"], radius=0.0026, height=0.003)
    lug, charm_point = charm_lug(-HX - 0.003, -0.006, H_BOTTOM + 0.008, M)
    return parts + lug, charm_point


def build_glow_blade():
    reset_scene()
    palette()
    M = weapon_mats("#2ef0ff", emit=2.6)
    hz = (H_TOP + H_BOTTOM) / 2
    hy, hzp = HINGE
    shell, charm_point = handle_parts(M)

    # The flip-button on the bolster's left face (the side the player sees):
    # a gold-ringed pink cap with an LED beside it.
    led = mat("ButtonLed", "#ff5ad8", rough=0.2, emit=3.0)
    buttons = [
        xcyl("FlipRing", 0.0068, 0.003, (-HX - 0.0038, -0.004, H_TOP - 0.006), m=M["steel"], segs=18, bevel=0.0008),
        sphere("FlipCap", 0.0052, (-HX - 0.0052, -0.004, H_TOP - 0.006), scale=(0.5, 1, 1), m=M["pink"], segs=14, rings=8),
        sphere("FlipLed", 0.0019, (-HX - 0.0042, 0.0085, H_TOP - 0.006), scale=(0.6, 1, 1), m=led, segs=8, rings=5),
    ]
    blade, edge = blade_parts(M, hy, hzp)

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
    arm_r, elbow_r = hand("R", fr, bar, M, (0.1, -0.45, -0.75), finger_z, (z0, z1), s_web=2.85, palm_len=0.09,
                          finger_len=0.078, thumb=thumb, wrist_s=3.5, wrist_z=z0 + 0.045)

    tip = (0, EDGE[-1][0], hzp + BLADE_LEN)
    groups = {
        "Knife": ([box("KnifeCore", (0.004, 0.004, 0.004), (0, 0, hz), bevel=0.0, m=M["dark"])], (0, 0, 0), None),
        "Shell": (shell, (0, 0, 0), "Knife"),
        "Buttons": (buttons, (-HX, 0, H_TOP), "Knife"),
        "Blade": (blade, (0, hy, hzp), "Knife"),
        "BladeEdge": (edge, (0, hy, hzp), "Blade"),
        "ArmR": (arm_r, (0, 0, hz), None),
    }
    empties = {
        "Muzzle": (tip, "Blade"),
        "BladeTip": (tip, "Blade"),
        "SwingPoint": ((0, hy + 0.014, hzp + BLADE_LEN * 0.5), "Blade"),
        "CharmPoint": (charm_point, "Knife"),
        "ElbowR": (elbow_r, "ArmR"),
    }
    groups, empties = lay_down(groups, empties)
    finish("glow_blade", groups, empties)


if __name__ == "__main__":
    build_glow_blade()
