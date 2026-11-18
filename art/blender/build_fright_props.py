"""Fright Fair props (World 11, Ghost Train): one kit, art/models/fright_kit.glb,
whose top-level objects are the separate props (the level generator picks them
by name). Origins at the centre of the base, fronts facing -Y (Godot +Z).

    Fence        wrought-iron fence module, 2.5 m along X, 2.3 m tall, a brick
                 pier with a green orb at its -X end
    FenceLow     low iron railing module, 2.0 m along X, 1.1 m tall
    Lamp         crooked iron lamp post (3.9 m) with a hanging orange lantern
    Pumpkin      one carved jack-o'-lantern (0.7 m)
    PumpkinPile  a hay bale heaped with pumpkins (1.6 x 0.9 m)
    GraveA/B/C   gravestones: rounded slab, cross, obelisk
    TreeA/B      twisted dead trees (6 m, 8 m)
    Coffins      two upright coffins and a crate (1.8 x 1.0 m, 2.1 m tall)
    Booth        "SKULL TOSS" game booth (3.2 x 2.0 m)
    AppleCart    toxic candy-apple cart (1.8 x 0.9 m)
    GooBarrel    a barrel of glowing goo (0.9 m)
    GhostCar     a ghost-train car on its bogie (2.4 x 1.3 m)
    Bench        iron park bench (1.8 m)
    Track        ghost-train track module, 2.0 m along X (0.12 m tall)
    Hedge        clipped hedge block, 2.0 x 0.9 m, 1.6 m tall
    ExitLantern  a pumpkin on a post (1.6 m) glowing "FrightExitGlow"
    LanternO/G   paper lanterns for the lantern strings (orange, green)
    Bat          a flat bat for the flocks round the moon

    python art/blender/build_fright_props.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fright_common import *  # noqa: F401,F403


def fence():
    iron, brick, cap = fmat("Iron", rough=0.5, metal=0.4), fmat("Brick", rough=0.9), fmat("Stone", rough=0.85)
    p = iron_spears("F", 2.0, 2.05, iron, spacing=0.2, x0=-1.0)
    p += [box("RailLo", (2.0, 0.06, 0.06), (0, 0, 0.3), bevel=0.01, m=iron),
          box("RailHi", (2.0, 0.06, 0.06), (0, 0, 1.75), bevel=0.01, m=iron)]
    for k in range(4):
        x = -0.75 + k * 0.5
        p.append(torus(f"Curl{k}", 0.13, 0.02, (x, 0, 1.95), rot=rad(90, 0, 0), m=iron, major_segs=12, minor_segs=4))
    p += [box("Pier", (0.5, 0.5, 2.3), (-1.25, 0, 1.15), bevel=0.04, m=brick),
          box("PierBand", (0.54, 0.54, 0.1), (-1.25, 0, 0.5), bevel=0.02, m=fmat("BrickDark", rough=0.9)),
          box("PierCap", (0.64, 0.64, 0.14), (-1.25, 0, 2.37), bevel=0.04, m=cap),
          bulb("PierOrb", 0.13, (-1.25, 0, 2.58), bulb_green(), halo=False)]
    return merge("Fence", p)


def fence_low():
    iron = fmat("Iron", rough=0.5, metal=0.4)
    p = iron_spears("L", 2.0, 0.95, iron, spacing=0.25, x0=-1.0)
    p += [box("Hand", (2.0, 0.08, 0.06), (0, 0, 0.92), bevel=0.02, m=iron),
          box("Kick", (2.0, 0.06, 0.06), (0, 0, 0.18), bevel=0.01, m=iron),
          box("Post", (0.12, 0.12, 1.1), (-1.0, 0, 0.55), bevel=0.02, m=iron),
          sphere("Knob", 0.08, (-1.0, 0, 1.14), m=fmat("Gold", rough=0.4, metal=0.5), segs=8, rings=5)]
    return merge("FenceLow", p)


def lamp():
    iron = fmat("Iron", rough=0.5, metal=0.4)
    p = [cyl("Base", 0.22, 0.3, (0, 0, 0.15), segs=8, bevel=0.03, m=iron, radius_top=0.14),
         tube("Post", [(0, 0, 0.3), (0.04, 0, 1.6), (-0.03, 0, 2.8), (0.02, 0, 3.6)], 0.06, m=iron, segs=8, radius_end=0.045)]
    curl = [(0.02, 0, 3.6), (0.2, 0, 3.85), (0.45, 0, 3.88), (0.62, 0, 3.75), (0.62, 0, 3.6)]
    p.append(tube("Arm", curl, 0.035, m=iron, segs=6))
    p.append(torus("Scroll", 0.1, 0.02, (0.18, 0, 3.45), rot=rad(90, 0, 0), m=iron, major_segs=12, minor_segs=4))
    p += [box("LanternTop", (0.3, 0.3, 0.06), (0.62, 0, 3.52), bevel=0.02, m=iron),
          cyl("LanternRoof", 0.22, 0.16, (0.62, 0, 3.6), segs=4, bevel=0.0, m=iron, radius_top=0.02),
          box("LanternGlass", (0.22, 0.22, 0.32), (0.62, 0, 3.32), bevel=0.02, m=fglow("FrightLampGlass", "#ffb04a", 2.6)),
          box("LanternFoot", (0.28, 0.28, 0.05), (0.62, 0, 3.14), bevel=0.02, m=iron),
          bulb("LanternBulb", 0.07, (0.62, 0, 3.32), bulb_orange())]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box(f"Bar{sx}{sy}", (0.03, 0.03, 0.34), (0.62 + sx * 0.12, sy * 0.12, 3.32), bevel=0.0, m=iron))
    p += pumpkin("Pk", (0.0, -0.05, 0.3), r=0.16, seed=3)
    return merge("Lamp", p)


def pumpkin_single():
    return merge("Pumpkin", pumpkin("P", (0, 0, 0), r=0.36, seed=5))


def pumpkin_pile():
    hay, band = fmat("Hay", rough=0.95), fmat("WoodDark", rough=0.9)
    p = [box("Bale", (1.5, 0.8, 0.6), (0, 0, 0.3), bevel=0.08, m=hay)]
    for x in (-0.45, 0.45):
        p.append(box(f"Twine{x}", (0.05, 0.84, 0.64), (x, 0, 0.3), bevel=0.01, m=band))
    p += pumpkin("A", (-0.42, -0.08, 0.6), r=0.3, seed=7)
    p += pumpkin("B", (0.35, 0.05, 0.6), r=0.36, seed=8, carved=False)
    p += pumpkin("C", (0.02, 0.15, 1.1), r=0.24, seed=9, yaw=0.3)
    p += pumpkin("D", (0.95, -0.25, 0.0), r=0.26, seed=10, carved=False)
    p += pumpkin("E", (-0.95, -0.2, 0.0), r=0.2, seed=11, yaw=-0.4)
    return merge("PumpkinPile", p)


def graves():
    out = []
    for kind, name, h in ((0, "GraveA", 0.95), (1, "GraveB", 1.15), (2, "GraveC", 1.25)):
        p = gravestone(name[-1], (0, 0, 0), kind=kind, h=h, seed=kind + 3)
        out.append(merge(name, p))
    return out


def trees():
    return [merge("TreeA", dead_tree("TA", (0, 0, 0), height=6.0, seed=4)),
            merge("TreeB", dead_tree("TB", (0, 0, 0), height=8.5, seed=9))]


def coffin(prefix, loc, yaw, lean):
    wood, dark, bone = fmat("Wood", rough=0.8), fmat("WoodDark", rough=0.85), fmat("Bone", rough=0.6)
    pts = [(-0.22, 0.0), (0.22, 0.0), (0.34, 1.35), (0.24, 1.9), (-0.24, 1.9), (-0.34, 1.35)]
    p = [prism(prefix + "Box", pts, 0.34, (0, 0, 0), m=wood, bevel=0.03),
         prism(prefix + "Lid", [(x * 0.86, z * 0.96 + 0.04) for x, z in pts], 0.06, (0, -0.19, 0), m=dark, bevel=0.01),
         box(prefix + "CrossV", (0.07, 0.03, 0.6), (0, -0.23, 1.25), bevel=0.01, m=bone),
         box(prefix + "CrossH", (0.32, 0.03, 0.07), (0, -0.23, 1.38), bevel=0.01, m=bone)]
    for ob in p:
        ob.rotation_euler = (math.radians(-lean), 0, 0)
    return place(p, loc=loc, rot_z=yaw)


def coffins():
    p = coffin("A", (-0.45, 0.15, 0.0), 0.15, 8.0) + coffin("B", (0.4, 0.2, 0.0), -0.2, 6.0)
    p += [box("Crate", (0.8, 0.7, 0.7), (0.35, -0.2, 0.35), rot=(0, 0, 0.3), bevel=0.05, m=fmat("WoodLight", rough=0.8)),
          text("CrateText", "FRAGILE", 0.12, 0.02, (0.25, -0.52, 0.4), rot=(0, 0, 0.3), m=fmat("Crimson", rough=0.6))]
    return merge("Coffins", p)


def booth():
    purple, ink, bone, orange, wood = fmat("Purple", rough=0.5), fmat("Ink"), fmat("Bone", rough=0.6), fmat("Orange", rough=0.5), fmat("WoodDark", rough=0.8)
    W, D = 3.2, 2.0
    p = [box("Floor", (W, D, 0.12), (0, 0, 0.06), bevel=0.02, m=wood),
         box("Back", (W, 0.12, 2.6), (0, D / 2 - 0.06, 1.3), bevel=0.03, m=ink),
         box("SideL", (0.12, D, 2.6), (-W / 2 + 0.06, 0, 1.3), bevel=0.03, m=fmat("Violet")),
         box("SideR", (0.12, D, 2.6), (W / 2 - 0.06, 0, 1.3), bevel=0.03, m=fmat("Violet")),
         box("Counter", (W + 0.1, 0.5, 0.1), (0, -D / 2 + 0.2, 1.05), bevel=0.03, m=fmat("WoodLight", rough=0.7))]
    for i in range(8):
        x = -W / 2 + 0.2 + i * 0.4
        p.append(box(f"Front{i}", (0.4, 0.1, 1.0), (x, -D / 2 + 0.02, 0.5), bevel=0.01, m=purple if i % 2 == 0 else ink))
    for s in (-1, 1):
        p.append(tube(f"Pole{s}", [(s * (W / 2 - 0.05), -D / 2 + 0.02, 0.1), (s * (W / 2 - 0.08), -D / 2 + 0.02, 3.05)], 0.07, m=fmat("Iron", metal=0.4), segs=8))
    # Scalloped striped awning.
    for i in range(8):
        x = -W / 2 + 0.2 + i * 0.4
        p.append(box(f"Awn{i}", (0.4, 1.3, 0.06), (x, -D / 2 + 0.25, 2.85), rot=(math.radians(18), 0, 0), bevel=0.01, m=purple if i % 2 else orange))
        p.append(cyl(f"Scal{i}", 0.2, 0.04, (x, -D / 2 - 0.37, 2.6), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=purple if i % 2 else orange))
    p += [box("Sign", (2.6, 0.14, 0.6), (0, -D / 2 + 0.6, 3.4), bevel=0.04, m=ink),
          box("SignTrim", (2.75, 0.1, 0.72), (0, -D / 2 + 0.64, 3.4), bevel=0.04, m=orange),
          text("SignText", "SKULL TOSS", 0.32, 0.05, (0, -D / 2 + 0.5, 3.38), m=fglow("FrightSignGreen", "#7dff6a", 2.2))]
    for k in range(6):
        p.append(bulb(f"SignBulb{k}", 0.055, (-1.25 + k * 0.5, -D / 2 + 0.5, 3.74), bulb_green()))
    # Prize shelves of skulls and the target skulls on the back wall.
    for row in range(2):
        z = 1.55 + row * 0.55
        p.append(box(f"Shelf{row}", (W - 0.4, 0.3, 0.05), (0, D / 2 - 0.3, z), bevel=0.01, m=wood))
        for k in range(5):
            x = -1.1 + k * 0.55
            p += [sphere(f"Skull{row}{k}", 0.14, (x, D / 2 - 0.3, z + 0.16), scale=(1, 1, 1.05), m=bone, segs=10, rings=7),
                  sphere(f"SEyeL{row}{k}", 0.035, (x - 0.05, D / 2 - 0.43, z + 0.18), m=ink, segs=6, rings=4),
                  sphere(f"SEyeR{row}{k}", 0.035, (x + 0.05, D / 2 - 0.43, z + 0.18), m=ink, segs=6, rings=4)]
    return merge("Booth", p)


def apple_cart():
    wood, orange, ink, iron = fmat("WoodLight", rough=0.75), fmat("Orange", rough=0.5), fmat("Ink"), fmat("Iron", metal=0.4)
    apple = fglow("FrightApple", "#8cff4a", 1.2)
    p = [box("Body", (1.6, 0.8, 0.7), (0, 0, 0.75), bevel=0.06, m=fmat("Crimson", rough=0.5)),
         box("Trim", (1.66, 0.84, 0.08), (0, 0, 1.12), bevel=0.02, m=fmat("Gold", rough=0.4)),
         box("Tray", (1.5, 0.7, 0.06), (0, 0, 1.17), bevel=0.02, m=wood)]
    for s in (-1, 1):
        p += [cyl(f"Wheel{s}", 0.36, 0.08, (s * 0.55, -0.44, 0.36), rot=rad(90, 0, 0), segs=14, bevel=0.02, m=ink),
              cyl(f"Hub{s}", 0.1, 0.1, (s * 0.55, -0.48, 0.36), rot=rad(90, 0, 0), segs=8, bevel=0.01, m=fmat("Gold", rough=0.4))]
        p.append(cyl(f"Pole{s}", 0.04, 1.3, (s * 0.72, 0, 1.8), segs=6, bevel=0.0, m=iron))
    canopy = lathe("Canopy", [(1.15, 2.4), (0.6, 2.75), (0.05, 2.95)], [orange, ink], segs=12, stripes=1, smooth=False, cap_bottom=False, cap_top=False)
    double_sided(canopy)
    p.append(canopy)
    rng = random.Random(4)
    for k in range(12):
        x = -0.6 + (k % 6) * 0.24
        y = -0.15 + (k // 6) * 0.3
        p += [sphere(f"Apple{k}", 0.09, (x, y, 1.29), m=apple, segs=8, rings=6),
              cyl(f"Stick{k}", 0.012, 0.22, (x, y, 1.44), rot=(rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 0), segs=4, bevel=0.0, m=fmat("Bone"))]
    p.append(text("CartText", "APPLES", 0.2, 0.03, (0, -0.42, 0.78), m=fmat("Bone", rough=0.5)))
    return merge("AppleCart", p)


def goo_barrel():
    wood, iron = fmat("Wood", rough=0.8), fmat("Iron", metal=0.4)
    p = [cyl("Barrel", 0.42, 0.9, (0, 0, 0.45), segs=14, bevel=0.04, m=wood),
         cyl("Goo", 0.36, 0.06, (0, 0, 0.9), segs=14, bevel=0.0, m=fglow("FrightGoo", "#6cff6a", 2.0))]
    for z in (0.15, 0.75):
        p.append(torus(f"Hoop{z}", 0.43, 0.025, (0, 0, z), m=iron, major_segs=16, minor_segs=4))
    for k in range(3):
        a = k * 2.1
        p.append(sphere(f"Drip{k}", 0.06, (math.cos(a) * 0.4, math.sin(a) * 0.4, 0.82 - k * 0.08), scale=(1, 1, 1.6), m=fglow("FrightGoo", "#6cff6a", 2.0),
                        segs=6, rings=4))
    return merge("GooBarrel", p)


def ghost_car():
    body, ink, bone, iron = fmat("Plum", rough=0.45), fmat("Ink"), fmat("Bone", rough=0.55), fmat("Iron", metal=0.4)
    p = [box("Bogie", (1.0, 2.0, 0.22), (0, 0, 0.18), bevel=0.04, m=iron),
         box("Tub", (1.25, 2.3, 0.75), (0, 0, 0.7), bevel=0.12, m=body),
         box("Rim", (1.3, 2.35, 0.08), (0, 0, 1.08), bevel=0.03, m=fmat("Gold", rough=0.4)),
         box("Seat", (1.05, 0.5, 0.5), (0, 0.55, 1.0), bevel=0.08, m=fmat("Crimson", rough=0.6)),
         box("SeatB", (1.05, 0.5, 0.5), (0, -0.25, 1.0), bevel=0.08, m=fmat("Crimson", rough=0.6)),
         box("BarL", (1.1, 0.05, 0.05), (0, -0.62, 1.32), bevel=0.01, m=iron)]
    for sy in (-0.7, 0.7):
        for sx in (-0.5, 0.5):
            p.append(cyl(f"Wheel{sx}{sy}", 0.16, 0.1, (sx, sy, 0.16), rot=rad(0, 90, 0), segs=10, bevel=0.01, m=ink))
    # Skull nose on the front (-Y) and bat wings down the sides.
    p += [sphere("Skull", 0.42, (0, -1.25, 0.85), scale=(1, 0.8, 0.95), m=bone, segs=14, rings=9),
          box("Jaw", (0.5, 0.3, 0.2), (0, -1.33, 0.52), bevel=0.06, m=bone)]
    for s in (-1, 1):
        p += [sphere(f"Socket{s}", 0.12, (s * 0.16, -1.54, 0.92), scale=(1, 0.5, 1.1), m=ink, segs=8, rings=5),
              bulb(f"Eye{s}", 0.06, (s * 0.16, -1.6, 0.92), bulb_green())]
        wing = [(0.0, 0.0), (0.9, 0.15), (1.5, 0.6), (1.2, 0.45), (0.95, 0.75), (0.65, 0.42), (0.35, 0.7), (0.1, 0.35)]
        w = prism(f"Wing{s}", [(x - 0.7, z) for x, z in wing], 0.04, (s * 0.64, 0.0, 0.62), rot=(0, 0, math.pi / 2), m=ink)
        p.append(w)
    for k in range(4):
        p.append(box(f"Tooth{k}", (0.08, 0.05, 0.1), (-0.15 + k * 0.1, -1.47, 0.6), bevel=0.01, m=fmat("BoneDark")))
    return merge("GhostCar", p)


def bench():
    iron, wood = fmat("Iron", metal=0.4), fmat("Wood", rough=0.8)
    p = []
    for k in range(3):
        p.append(box(f"Slat{k}", (1.8, 0.12, 0.05), (0, -0.15 + k * 0.15, 0.46), bevel=0.015, m=wood))
    for k in range(2):
        p.append(box(f"Back{k}", (1.8, 0.05, 0.12), (0, 0.24, 0.65 + k * 0.18), rot=(math.radians(-10), 0, 0), bevel=0.015, m=wood))
    for x in (-0.8, 0.8):
        p.append(tube(f"Leg{x}", [(x, -0.25, 0.0), (x, -0.2, 0.44), (x, 0.2, 0.44), (x, 0.25, 0.0)], 0.03, m=iron, segs=5))
        p.append(tube(f"BackLeg{x}", [(x, 0.2, 0.44), (x, 0.27, 0.95)], 0.03, m=iron, segs=5))
        p.append(torus(f"Arm{x}", 0.12, 0.02, (x, -0.1, 0.6), rot=rad(90, 0, 90), m=iron, major_segs=10, minor_segs=4))
    return merge("Bench", p)


def track():
    steel, wood = fmat("IronLight", rough=0.35, metal=0.7), fmat("WoodDark", rough=0.9)
    p = []
    for k in range(4):
        p.append(box(f"Sleeper{k}", (0.22, 1.5, 0.08), (-0.75 + k * 0.5, 0, 0.04), bevel=0.015, m=wood))
    for y in (-0.5, 0.5):
        p.append(box(f"Rail{y}", (2.0, 0.08, 0.06), (0, y, 0.11), bevel=0.01, m=steel))
    p.append(box("Bus", (2.0, 0.06, 0.05), (0, 0, 0.1), bevel=0.01, m=fmat("Crimson", rough=0.5)))
    return merge("Track", p)


def hedge():
    rng = random.Random(12)
    leaf, dark = fmat("Hedge", rough=0.95), fmat("Moss", rough=0.95)
    p = [box("Core", (1.9, 0.8, 1.45), (0, 0, 0.72), bevel=0.25, m=leaf)]
    for k in range(10):
        x = -0.8 + (k % 5) * 0.4 + rng.uniform(-0.05, 0.05)
        z = 0.5 + (k // 5) * 0.75 + rng.uniform(-0.1, 0.1)
        for s in (-1, 1):
            p.append(sphere(f"Puff{k}{s}", rng.uniform(0.24, 0.3), (x, s * 0.36, z), scale=(1.1, 0.6, 1.0), m=dark if (k + s) % 3 == 0 else leaf, segs=8, rings=5))
    return merge("Hedge", p)


def exit_lantern():
    iron = fmat("Iron", metal=0.4)
    p = [cyl("Base", 0.18, 0.12, (0, 0, 0.06), segs=8, bevel=0.02, m=iron),
         tube("Post", [(0, 0, 0.1), (0.03, 0, 0.7), (0, 0, 1.25)], 0.04, m=iron, segs=6),
         cyl("Cup", 0.16, 0.08, (0, 0, 1.25), segs=10, bevel=0.01, m=iron)]
    p += pumpkin("X", (0, 0, 1.28), r=0.2, seed=13, glow=exit_glow())
    return merge("ExitLantern", p)


def lanterns():
    out = []
    for name, color in (("LanternO", "#ff9a2e"), ("LanternG", "#7dff6a")):
        g = fglow(f"Fright{name}Glow", color, 2.4)
        cap = fmat("Ink")
        p = [sphere(name + "Paper", 0.16, (0, 0, -0.2), scale=(1, 1, 1.25), m=g, segs=10, rings=6),
             cyl(name + "Top", 0.08, 0.05, (0, 0, -0.01), segs=8, bevel=0.0, m=cap),
             cyl(name + "Bot", 0.08, 0.04, (0, 0, -0.4), segs=8, bevel=0.0, m=cap)]
        out.append(merge(name, p))
    return out


def bat():
    ink = fmat("Night", rough=0.8)
    wing = [(0.0, 0.0), (0.35, 0.12), (0.6, 0.02), (0.5, -0.05), (0.42, -0.02), (0.3, -0.08), (0.18, -0.03), (0.05, -0.08)]
    p = [sphere("Body", 0.07, (0, 0, 0), scale=(1, 1.4, 1), m=ink, segs=8, rings=5)]
    for s in (-1, 1):
        outline = [(s * x, z) for x, z in wing]
        p.append(prism(f"Wing{s}", outline if s > 0 else list(reversed(outline)), 0.01, (0, 0, 0), rot=(math.pi / 2, 0, 0), m=ink))
        p.append(cyl(f"Ear{s}", 0.025, 0.06, (s * 0.03, -0.02, 0.07), segs=4, bevel=0.0, m=ink, radius_top=0.0))
    return merge("Bat", p)


def build():
    reset_scene()
    objects = [fence(), fence_low(), lamp(), pumpkin_single(), pumpkin_pile()] + graves() + trees()
    objects += [coffins(), booth(), apple_cart(), goo_barrel(), ghost_car(), bench(), track(), hedge(), exit_lantern()] + lanterns() + [bat()]
    save("fright_kit", objects)


if __name__ == "__main__":
    build()
