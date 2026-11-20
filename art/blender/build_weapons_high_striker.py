"""First-person model of the High Striker (high_striker), the melee-slot
strongman mallet: a big carnival-red head with brass bands and a bullseye
target on each face, on a long handle whose top half is painted as the
strongman's scale (green to red, with ticks); a puck rides up the scale to
ring a little brass bell at the top.

Melee contract (melee_kit.py): origin at the centre of the lower hand's grip
on the handle, the handle along +Y with the head at its far end. The head's
axis is Z: its faces strike towards -Z (a slam) and +Z.

  Handle  the handle, grip wrap, knob and the scale (static, pivot at the
          origin)
  Head    child of Handle, pivot at the head's centre
  Puck    child of Handle, the collar on the scale (pivot at its centre):
          slides along +Y from PUCK_Y0 to PUCK_Y1 (local Y in Blender,
          -Z in Godot) to ring the bell
  Bell    child of Handle, pivot on its bracket: shakes when rung
  ArmL    the left hand at the bottom of the grip, by the knob (ElbowL),
          articulated (hand_kit.py: ArmLHand, ArmLIndex1..3, ..., ArmLThumb1..3,
          ArmLGrip)
  ArmR    the right hand up the grip (ElbowR), the same nodes

A right-handed sledge stance: the left hand at the knob, the right GRIP_U up
the shaft, both thumbs towards the head and turned a little towards the
player so they read against the handle; each forearm runs down out of the
frame on its own side (the right one outside the left hand), at about 130
degrees to the handle, so the solver's wrist tilt leaves a small, natural
bend.

Grip anchors (children of Handle): GripLower (the left hand, at the origin)
and GripUpper (the right hand); Y along the handle towards the head, Z
towards the palm.

Empties: Muzzle (the centre of the striking face), BladeTip and SwingPoint
(the far and near edges of the head: the swing trail), BellPoint (in the bell's mouth, for the DING flash), CharmPoint (a
lug by the knob, left side).

    python art/blender/build_weapons_high_striker.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from melee_kit import *  # noqa: F401,F403

HANDLE_R = 0.021
## The gloved hands at a human size against the 42 mm shaft (hand_kit grip_hand scale).
HAND_SCALE = 0.8
KNOB_Y = -0.095
HEAD_Y = 0.83
HEAD_R = 0.078
HEAD_HALF = 0.135
SCALE_Y0 = 0.33
SCALE_Y1 = 0.645
## The puck's travel: rest at the foot of the scale, the top under the bell.
PUCK_Y0 = 0.315
PUCK_Y1 = 0.64
BELL_Y = 0.685
## The right hand's grip, up the shaft from the left (the origin): a hand's width apart.
GRIP_U = 0.2
SCALE_COLOURS = ["#3fd16a", "#a8e03a", "#ffd23f", "#ff9a2e", "#ff3b4f"]


def palette():
    """The shared weapon materials in this weapon's colours (weapon_mats reuses them)."""
    mat("Shell", "#ff2f48", rough=0.3)
    mat("Trim", "#ffdc8f", rough=0.42)
    mat("GunDark", "#2a2238", rough=0.55, metal=0.1)
    mat("GunSteel", "#f2b53a", rough=0.26, metal=0.6)
    mat("GunPink", "#ff5fae", rough=0.36)


def build_high_striker():
    reset_scene()
    palette()
    M = weapon_mats("#ffe14a", emit=2.2)
    wood = mat("Wood", "#d8955a", rough=0.55)
    grain = mat("WoodGrain", "#b06a38", rough=0.6)
    bands = [mat(f"Scale{i}", c, rough=0.3) for i, c in enumerate(SCALE_COLOURS)]

    # Handle: wood with a little taper, a cream leather grip, a red knob, the painted scale.
    length = HEAD_Y - KNOB_Y
    handle = [
        ycyl("Wood", HANDLE_R, length, (KNOB_Y + HEAD_Y) / 2, m=wood, segs=22, bevel=0.003, radius_top=HANDLE_R * 0.93),
        ycyl("Grip", HANDLE_R + 0.0035, 0.36, 0.1, m=M["trim"], segs=22, bevel=0.003),
        ring("GripEnd0", HANDLE_R + 0.004, 0.0035, -0.08, m=M["steel"], segs=22),
        ring("GripEnd1", HANDLE_R + 0.004, 0.0035, 0.28, m=M["steel"], segs=22),
        sphere("Knob", 0.034, (0, KNOB_Y - 0.012, 0), scale=(1, 0.8, 1), m=M["shell"], segs=20, rings=12),
        ring("KnobBand", 0.03, 0.004, KNOB_Y - 0.004, m=M["steel"], segs=22),
        ycyl("KnobCap", 0.012, 0.01, KNOB_Y - 0.04, m=M["cell"], segs=14, bevel=0.002),
    ]
    for k in range(4):
        a = 0.6 + k * 1.6
        handle.append(box(f"Grain{k}", (0.0016, 0.05 + 0.02 * (k % 2), 0.0035),
                          (math.cos(a) * (HANDLE_R - 0.0004), 0.3 + 0.012 * k, math.sin(a) * (HANDLE_R - 0.0004)),
                          rot=(0, 0, 0), bevel=0.0, m=grain))
    # Spiral stitching on the grip.
    handle.append(spiral_band("Stitch", HANDLE_R + 0.0035, 0.0012, -0.075, 0.275, 6.0, M["shell"], segs=6))
    # The scale: five painted bands, ticks on the side the player sees, a gold rail along the top.
    seg = (SCALE_Y1 - SCALE_Y0) / len(bands)
    for i, m in enumerate(bands):
        y = SCALE_Y0 + seg * (i + 0.5)
        r = HANDLE_R * (1.0 - 0.07 * (y - KNOB_Y) / length) + 0.0012
        handle.append(ycyl(f"Band{i}", r, seg - 0.002, y, m=m, segs=22, bevel=0.0012))
        for t in range(3):
            yt = SCALE_Y0 + seg * i + seg * (0.25 + 0.25 * t)
            w = 0.012 if t == 1 else 0.007
            handle.append(box(f"Tick{i}{t}", (0.004, 0.0025, w), (-r - 0.0006, yt, 0.0), bevel=0.0, m=M["dark"]))
            handle.append(box(f"TickR{i}{t}", (0.004, 0.0025, w), (r + 0.0006, yt, 0.0), bevel=0.0, m=M["dark"]))
    for i in range(len(bands) + 1):
        handle.append(ring(f"BandSeam{i}", HANDLE_R + 0.0012, 0.0016, SCALE_Y0 + seg * i, m=M["steel"], segs=20))
    handle.append(box("Rail", (0.006, SCALE_Y1 - SCALE_Y0 + 0.03, 0.004), (0, (SCALE_Y0 + SCALE_Y1) / 2 + 0.01, HANDLE_R + 0.002),
                      bevel=0.0012, m=M["steel"]))
    # The bell's bracket, standing up off the top of the handle.
    handle.append(box("BellPost", (0.012, 0.014, 0.05), (0, BELL_Y + 0.006, HANDLE_R + 0.022), bevel=0.003, m=M["steel"]))
    handle.append(ring("BellCollar", HANDLE_R + 0.0025, 0.004, BELL_Y + 0.004, m=M["steel"], segs=20))

    # Head: a red barrel along Z with brass bands, rivets, a gold star each side and a bullseye on each face.
    head = [
        cyl("HeadBody", HEAD_R, HEAD_HALF * 2 - 0.02, (0, HEAD_Y, 0), segs=30, bevel=0.012, m=M["shell"]),
        cyl("HeadCore", HEAD_R * 0.96, HEAD_HALF * 2, (0, HEAD_Y, 0), segs=30, bevel=0.01, m=M["shell"]),
        ycyl("Eye", HANDLE_R + 0.006, 0.03, HEAD_Y - HEAD_R + 0.008, m=M["steel"], segs=20, bevel=0.004),
    ]
    for side in (-1, 1):
        zf = side * HEAD_HALF
        head.append(torus(f"BandEnd{side}", HEAD_R + 0.001, 0.0085, (0, HEAD_Y, zf - side * 0.022), m=M["steel"], major_segs=32, minor_segs=8))
        head.append(torus(f"BandMid{side}", HEAD_R + 0.001, 0.005, (0, HEAD_Y, side * 0.045), m=M["steel"], major_segs=32, minor_segs=6))
        for k in range(8):
            a = math.tau * k / 8
            head.append(sphere(f"Rivet{side}{k}", 0.0045, (math.cos(a) * (HEAD_R + 0.009), HEAD_Y + math.sin(a) * (HEAD_R + 0.009), zf - side * 0.022),
                               m=M["steel"], segs=8, rings=5))
        # Bullseye target: cream, red, cream, gold centre.
        for j, (rr, m) in enumerate([(HEAD_R * 0.9, M["trim"]), (HEAD_R * 0.68, M["shell"]), (HEAD_R * 0.46, M["trim"]), (HEAD_R * 0.24, M["shell"]),
                                     (HEAD_R * 0.1, M["steel"])]):
            head.append(cyl(f"Target{side}{j}", rr, 0.006, (0, HEAD_Y, zf + side * (0.002 + j * 0.0016)), segs=30, bevel=0.0015, m=m))
        head.append(star(f"Star{side}", 0.03, 0.006, (side * (HEAD_R - 0.002), HEAD_Y, 0), rot=rad(0, 0, 90 * side), m=M["steel"], inner=0.014))
        head.append(sphere(f"StarGem{side}", 0.0065, (side * (HEAD_R + 0.003), HEAD_Y, 0), scale=(0.5, 1, 1), m=M["cell"], segs=10, rings=6))

    # Puck: a chunky collar riding the scale, a striker tab on top, a glowing face.
    py = PUCK_Y0
    puck = [
        ycyl("PuckBody", HANDLE_R + 0.011, 0.026, py, m=M["pink"], segs=24, bevel=0.005),
        ring("PuckGlow", HANDLE_R + 0.0105, 0.0026, py + 0.0135, m=M["cell"], segs=24),
        ring("PuckBand", HANDLE_R + 0.0115, 0.0025, py, m=M["steel"], segs=24),
        box("PuckTab", (0.012, 0.022, 0.016), (0, py + 0.006, HANDLE_R + 0.013), bevel=0.004, m=M["steel"]),
        sphere("PuckNose", 0.0055, (0, py + 0.018, HANDLE_R + 0.015), m=M["cell"], segs=10, rings=6),
    ]

    # Bell: a brass dome on the bracket, its mouth facing back down the scale (the puck's way up).
    bell_c = (0, BELL_Y, HANDLE_R + 0.048)
    bell = [
        cyl("BellDome", 0.029, 0.034, (bell_c[0], bell_c[1] + 0.006, bell_c[2]), rot=rad(-90, 0, 0), segs=24, bevel=0.008, m=M["steel"],
            radius_top=0.012),
        torus("BellLip", 0.029, 0.0038, (bell_c[0], bell_c[1] - 0.011, bell_c[2]), rot=rad(90, 0, 0), m=M["steel"], major_segs=24, minor_segs=6),
        sphere("BellKnob", 0.0075, (bell_c[0], bell_c[1] + 0.027, bell_c[2]), m=M["steel"], segs=10, rings=6),
        sphere("BellClapper", 0.0075, (bell_c[0], bell_c[1] - 0.008, bell_c[2] - 0.008), m=M["dark"], segs=10, rings=6),
        sphere("BellShine", 0.0045, (bell_c[0] - 0.021, bell_c[1] + 0.002, bell_c[2] + 0.01), m=M["cell"], segs=8, rings=5),
    ]

    lug, charm_point = melee_lug(-HANDLE_R - 0.003, KNOB_Y + 0.008, 0.0, M)
    handle += lug

    # Articulated hands closed round the grip wrap (and its stitching) by the grip solver
    # (hand_kit.py). The forearm directions are the hold's (high_striker.tres) "down and out of
    # the frame" turned into the model: the left straight down past the knob, the right down
    # and out to the right, clear of the left hand.
    shaft = [cylinder_sdf((0, 0, 0), (0, 1, 0), HANDLE_R + 0.0035 + 0.0012)]
    # Human-sized hands (HAND_SCALE). The lower (left) hand's forearm runs down along the
    # handle, a little right and towards the camera, so the back of the hand and its knuckles
    # face the player (and the arm stays out of the frame through the swings) and
    # the fingers wrap round the far side, as on a real axe or sledge grip; the upper (right)
    # hand comes in from the right, turned 50 degrees over the top (roll) so its back faces
    # the player too and its fingers curl under the shaft.
    lower = grip_hand("L", (0, 0, 0), (0, 1, 0), (0.154, -0.964, 0.218), M, shaft, scale=HAND_SCALE)
    upper = grip_hand("R", (0, GRIP_U, 0), (0, 1, 0), (0.74, -0.578, -0.344), M, shaft, roll=50.0, scale=HAND_SCALE)
    groups = {
        "Handle": (handle, (0, 0, 0), None),
        "Head": (head, (0, HEAD_Y, 0), "Handle"),
        "Puck": (puck, (0, py, 0), "Handle"),
        "Bell": (bell, (0, BELL_Y + 0.004, HANDLE_R + 0.004), "Handle"),
    }
    empties = {
        "Muzzle": ((0, HEAD_Y, -HEAD_HALF - 0.01), "Head"),
        "BladeTip": ((0, HEAD_Y + HEAD_R, 0), "Head"),
        "SwingPoint": ((0, HEAD_Y - HEAD_R, 0), "Head"),
        "BellPoint": ((bell_c[0], bell_c[1] - 0.008, bell_c[2]), "Bell"),
        "CharmPoint": (charm_point, "Handle"),
    }
    add_hand(groups, empties, lower, "GripLower", "Handle")
    add_hand(groups, empties, upper, "GripUpper", "Handle")
    finish("high_striker", groups, empties)


if __name__ == "__main__":
    build_high_striker()
