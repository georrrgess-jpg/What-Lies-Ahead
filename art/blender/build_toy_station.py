"""Toybox Town loadout station and exit portal (World 15, Toy Shop).

    toy_station.glb        "The Toy Chest": a red painted toy chest (5 x 3 m, 1.75 m
                           to the rim) on yellow bun feet, brass corners and stars,
                           under a marquee sign arch on striped posts (top ~7 m).
        Station        the chest body and the sign arch (static)
        Shutter        the lid, pivot on its back hinge, exported closed; the scene
                       opens it to -100 degrees (it stands up behind the chest)
        OpenDressing   the goods in the chest (energy cells, an ammo tin, milk and
                       cookies) and the lit OPEN flag (open only)
        ClosedSign     the "CLOSED" tag hanging on the latch (closed only)
    toy_portal_arch.glb    the exit: the shared portal doorway framed by pillars of
                           letter blocks, a rainbow arch, a gold star and an EXIT board.

    python art/blender/build_toy_station.py [station] [portal]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from toy_common import *  # noqa: F401,F403
import build_world_portals as wp  # noqa: E402

W, D = 5.0, 3.0         # chest body
FEET = 0.25
RIM = 1.75              # top of the body
LID_T = 0.45
HINGE = (0.0, D / 2, RIM)
LID_OPEN = -100.0
SIGN_Z = 5.6


def chest():
    red, yellow, blue, brass = tmat("Red", rough=0.45), tmat("Yellow", rough=0.45), tmat("Blue", rough=0.45), tmat("Brass", rough=0.3, metal=0.5)
    inner = tmat("BlueDark", rough=0.8)
    h = RIM - FEET
    p = []
    # Body as four walls and a floor, so the open chest shows its inside.
    t = 0.22
    p += [box("Front", (W, t, h), (0, -D / 2 + t / 2, FEET + h / 2), bevel=0.06, m=red),
          box("Back", (W, t, h), (0, D / 2 - t / 2, FEET + h / 2), bevel=0.06, m=red),
          box("SideL", (t, D, h), (-W / 2 + t / 2, 0, FEET + h / 2), bevel=0.06, m=red),
          box("SideR", (t, D, h), (W / 2 - t / 2, 0, FEET + h / 2), bevel=0.06, m=red),
          box("Floor", (W - 0.1, D - 0.1, 0.2), (0, 0, FEET + 0.1), bevel=0.03, m=red),
          box("Lining", (W - 2 * t, D - 2 * t, 0.04), (0, 0, FEET + 0.62), bevel=0.0, m=inner),
          box("Plinth", (W + 0.16, D + 0.16, 0.24), (0, 0, FEET + 0.12), bevel=0.06, m=yellow),
          box("RimBand", (W + 0.12, D + 0.12, 0.14), (0, 0, RIM - 0.07), bevel=0.04, m=yellow)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(sphere(f"Foot{sx}{sy}", 0.26, (sx * (W / 2 - 0.35), sy * (D / 2 - 0.35), 0.2), scale=(1, 1, 0.8), m=yellow, segs=12, rings=7))
            p.append(box(f"Corner{sx}{sy}", (0.3, 0.3, h + 0.04), (sx * (W / 2 - 0.08), sy * (D / 2 - 0.08), FEET + h / 2), bevel=0.06, m=brass))
    # Front: a painted panel, three stars and the latch plate.
    p.append(box("Panel", (W - 0.9, 0.06, h - 0.55), (0, -D / 2 - 0.02, FEET + h / 2 + 0.05), bevel=0.04, m=blue))
    for k, x in enumerate((-1.45, 0.0, 1.45)):
        p.append(star(f"Star{k}", 0.38 if k == 1 else 0.28, 0.06, (x, -D / 2 - 0.07, FEET + h / 2 + 0.02), m=yellow))
    p.append(box("Latch", (0.36, 0.08, 0.4), (0, -D / 2 - 0.05, RIM - 0.24), bevel=0.04, m=brass))
    for s in (-1, 1):
        p.append(star(f"SideStar{s}", 0.42, 0.06, (s * (W / 2 + 0.03), 0, FEET + h / 2), rot=(0, 0, math.pi / 2), m=yellow))
    return p


def sign_arch():
    red, white, yellow, blue = tmat("Red", rough=0.45), tmat("White"), tmat("Yellow", rough=0.45), tmat("Blue", rough=0.45)
    p = []
    for s in (-1, 1):
        x = s * (W / 2 + 0.25)
        p.append(cyl(f"Post{s}", 0.17, SIGN_Z + 0.4, (x, D / 2 - 0.1, (SIGN_Z + 0.4) / 2), segs=12, bevel=0.03, m=white))
        for k in range(7):
            p.append(cyl(f"Band{s}{k}", 0.18, 0.32, (x, D / 2 - 0.1, 0.5 + k * 0.85), segs=12, bevel=0.0, m=red))
        p.append(sphere(f"Ball{s}", 0.3, (x, D / 2 - 0.1, SIGN_Z + 0.7), m=yellow, segs=12, rings=7))
    p += [box("Board", (W + 0.3, 0.2, 1.1), (0, D / 2 - 0.1, SIGN_Z), bevel=0.08, m=blue),
          box("BoardTrim", (W + 0.5, 0.14, 1.3), (0, D / 2 - 0.05, SIGN_Z), bevel=0.06, m=yellow),
          text("BoardText", "TOY CHEST", 0.62, 0.08, (0, D / 2 - 0.25, SIGN_Z - 0.02), m=tmat("White")),
          star("TopStar", 0.7, 0.18, (0, D / 2 - 0.1, SIGN_Z + 1.25), m=yellow)]
    bulb_m = tglow("ToyMarquee", "#ffe2a0", 3.0)
    for k in range(11):
        x = -W / 2 + k * W / 10
        p.append(bulb(f"Bulb{k}", 0.07, (x, D / 2 - 0.22, SIGN_Z + 0.68), bulb_m))
    return p


def lid():
    red, yellow, brass = tmat("Red", rough=0.45), tmat("Yellow", rough=0.45), tmat("Brass", rough=0.3, metal=0.5)
    L = D + 0.2
    p = [box("LidTop", (W + 0.2, L, LID_T), (0, -L / 2 + 0.1, LID_T / 2), bevel=0.1, m=red),
         box("LidBand", (W + 0.24, L + 0.04, 0.12), (0, -L / 2 + 0.1, 0.1), bevel=0.03, m=yellow),
         box("LidInner", (W - 0.4, L - 0.5, 0.04), (0, -L / 2 + 0.1, -0.01), bevel=0.0, m=tmat("Blue", rough=0.5)),
         star("LidStar", 0.8, 0.08, (0, -L / 2 + 0.1, LID_T + 0.03), rot=(math.pi / 2, 0, 0), m=yellow),
         box("Hasp", (0.3, 0.1, 0.36), (0, -L + 0.12, 0.05), bevel=0.03, m=brass)]
    for s in (-1, 1):
        p.append(cyl(f"Hinge{s}", 0.1, 0.5, (s * 1.6, 0.05, 0.0), rot=(0, math.pi / 2, 0), segs=10, bevel=0.02, m=brass))
    ob = merge("Shutter", p, pivot=(0, 0, 0))
    ob.location = HINGE
    return ob


def open_dressing():
    cell = tglow("ToyCellGlow", "#7fd8ff", 2.6)
    neon = tglow("ToyNeonOpen", "#ffe066", 3.2)
    z = FEET + 0.66
    p = [box("AmmoTin", (1.0, 0.7, 0.6), (-1.4, -0.3, z + 0.3), bevel=0.06, m=tmat("TinDark", rough=0.4, metal=0.4)),
         box("AmmoStripe", (1.02, 0.72, 0.12), (-1.4, -0.3, z + 0.38), bevel=0.02, m=tmat("Yellow")),
         cyl("Milk", 0.24, 0.8, (0.9, -0.4, z + 0.4), segs=12, bevel=0.04, m=tmat("White")),
         cyl("MilkCap", 0.18, 0.2, (0.9, -0.4, z + 0.9), segs=12, bevel=0.03, m=tmat("Red")),
         cyl("Plate", 0.55, 0.06, (1.55, 0.35, z + 0.05), segs=16, bevel=0.02, m=tmat("White"))]
    for k in range(3):
        p.append(cyl(f"Cookie{k}", 0.25, 0.08, (1.45 + (k % 2) * 0.2, 0.3 + k * 0.08, z + 0.12 + k * 0.08), rot=(0.1 * k, 0, 0), segs=12, bevel=0.02,
                     m=tmat("WoodLight", rough=0.8)))
    for k in range(4):
        p.append(cyl(f"Cell{k}", 0.13, 0.55, (-0.5 + k * 0.32, 0.4, z + 0.28), segs=10, bevel=0.03, m=cell))
    # The OPEN flag on a stick, standing up out of the chest in front of the open lid.
    p += [cyl("FlagStick", 0.05, 2.0, (0, 0.6, z + 1.0), segs=6, bevel=0.0, m=tmat("WoodLight")),
          box("FlagBoard", (1.6, 0.1, 0.6), (0, 0.55, z + 1.85), bevel=0.05, m=tmat("Navy")),
          text("FlagText", "OPEN", 0.42, 0.04, (0, 0.48, z + 1.84), m=neon)]
    return merge("OpenDressing", p)


def closed_sign():
    p = [tube("Loop", [(-0.12, -D / 2 - 0.1, RIM - 0.25), (0, -D / 2 - 0.12, RIM - 0.55), (0.12, -D / 2 - 0.1, RIM - 0.25)], 0.02,
              m=tmat("Ink"), segs=4),
         box("Tag", (1.3, 0.05, 0.42), (0, -D / 2 - 0.13, RIM - 0.78), bevel=0.03, m=tmat("Cream")),
         text("TagText", "CLOSED", 0.24, 0.02, (0, -D / 2 - 0.16, RIM - 0.79), m=tmat("Red"))]
    return merge("ClosedSign", p)


def build_station():
    reset_scene()
    station = merge("Station", chest() + sign_arch())
    save("toy_station", [station, lid(), open_dressing(), closed_sign()])


def build_portal():
    reset_scene()
    cols = ["Red", "Yellow", "Blue", "Green"]
    p = []
    bs = 1.1
    for s in (-1, 1):
        x = s * (wp.OPEN_W + 0.75)
        for k in range(2):
            p += letter_block(f"P{s}{k}", bs, cols[(k + (s > 0) * 2) % 4], loc=(x, 0, k * bs), letters=("EXIT" if k == 0 else "GO!!"))
    rainbow = [tmat("Red", rough=0.4), tmat("Yellow", rough=0.4), tmat("Blue", rough=0.4)]
    for k, m in enumerate(rainbow):
        hw = wp.OPEN_W + 0.25 + k * 0.38
        p.append(tube(f"Arc{k}", wp.arc_only(hw, wp.OPEN_RISE + 0.25 + k * 0.38, steps=28, spring=bs * 2), 0.2, m=m, segs=10))
    top = bs * 2 + wp.OPEN_RISE + 0.25 + 2 * 0.38
    p += [star("Star", 0.85, 0.3, (0, 0, top + 0.75), m=tmat("Yellow", rough=0.35)),
          box("Board", (1.4, 0.12, 0.45), (0, -0.35, top - 0.25), bevel=0.04, m=tmat("Navy")),
          text("BoardText", "EXIT", 0.32, 0.03, (0, -0.42, top - 0.27), m=tglow("ToyExitText", "#ffe066", 2.4))]
    for s in (-1, 1):
        p.append(cyl(f"Pom{s}", 0.25, 0.25, (s * (wp.OPEN_W + 0.75), 0, bs * 2 + 0.12), segs=12, bevel=0.06, m=tmat("White")))
    p.append(wp.backing("Back", tmat("Navy")))
    save("toy_portal_arch", [merge("PortalArch", p)])


if __name__ == "__main__":
    wanted = sys.argv[1:] or ["station", "portal"]
    if "station" in wanted:
        build_station()
    if "portal" in wanted:
        build_portal()
