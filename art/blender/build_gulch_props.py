"""Gold Rush Gulch props (World 12, Boomtown): street dressing, the coaster cars,
the red-rock mesas and the backdrop. Origins at the centre of the base; fronts
face -Y (+Z in Godot).

    gulch_wagon          covered wagon (4.2 x 1.9, bonnet 3.0 high)
    gulch_hay            two stacked square hay bales (1.6 x 1.0 x 1.2)
    gulch_barrels        three barrels (1.6 x 1.0 x 1.0)
    gulch_crates         stacked crates (1.6 x 1.2 x 1.5)
    gulch_cactus_a/b     saguaro cacti (3.6 / 2.6 high)
    gulch_trough         water trough on legs (2.4 x 0.8 x 0.8)
    gulch_hitch          hitching rail (3.0 x 0.2 x 1.1)
    gulch_lamp           lantern post (3.4 high)
    gulch_fence          split-rail fence module (2.5 m along X, 1.2 high)
    gulch_palisade       pointed log palisade module (2.0 m along X, 3.2 high)
    gulch_windmill       windmill tower (11 m) without its wheel
    gulch_windmill_wheel the wheel (turns about Y in Godot, local Z here)
    gulch_coaster_loco   coaster lead car (2.0 m, along -Y), a toy mine locomotive
    gulch_coaster_car    coaster ore car (2.0 m) heaped with gold
    gulch_tumbleweed     a tumbleweed ball (r 0.5)
    gulch_exit_lantern   exit-route lantern post (2.0 high), glass "GulchExitGlow"
    gulch_boulder        a desert boulder (2.4 x 2.0 x 1.4)
    gulch_cliff          a red-rock cliff wall block (30 x 10 x 16)
    gulch_butte          a tall butte (12 x 12 x 28)
    gulch_mesa_far       a wide far mesa (70 x 30 x 22)
    gulch_coaster_lamp   a marker lamp on the coaster track

    python art/blender/build_gulch_props.py [names...]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gulch_common import *  # noqa: F401,F403
from gulch_common import _finish, bmesh  # noqa: F401


def wheel(prefix, r, loc, m_rim, m_spoke, axis_x=True, spokes=10, width=0.1):
    rot = rad(0, 90, 0) if axis_x else rad(90, 0, 0)
    p = [torus(prefix + "Rim", r, 0.06, loc, rot=rot, m=m_rim, major_segs=24, minor_segs=5),
         cyl(prefix + "Hub", 0.12, width + 0.08, loc, rot=rot, segs=10, bevel=0.02, m=m_spoke)]
    for k in range(spokes):
        a = math.tau * k / spokes
        if axis_x:
            end = (loc[0], loc[1] + math.cos(a) * r, loc[2] + math.sin(a) * r)
        else:
            end = (loc[0] + math.cos(a) * r, loc[1], loc[2] + math.sin(a) * r)
        p.append(tube(f"{prefix}Spoke{k}", [loc, end], 0.025, m=m_spoke, segs=4))
    return p


def half_tube(name, r, length, loc, m, segs=14):
    """An open half-cylinder shell along Y (a wagon bonnet), visible from both sides."""
    bm = bmesh.new()
    rows = []
    for y in (-length / 2, length / 2):
        rows.append([bm.verts.new((math.cos(math.pi * i / segs) * r, y, math.sin(math.pi * i / segs) * r)) for i in range(segs + 1)])
    for i in range(segs):
        bm.faces.new((rows[0][i], rows[0][i + 1], rows[1][i + 1], rows[1][i]))
    return double_sided(_finish(name, bm, m, loc, (0, 0, 0)))


def build_wagon():
    reset_scene()
    wood, dark, canvas = gmat("Wood"), gmat("WoodDark"), gmat("Canvas", rough=0.85)
    red, iron = gmat("Red", rough=0.6), gmat("Iron", rough=0.5)
    p = [box("Bed", (1.8, 4.0, 0.7), (0, 0, 1.05), bevel=0.05, m=wood),
         box("BedTrim", (1.86, 4.06, 0.12), (0, 0, 1.38), bevel=0.03, m=red)]
    for s in (-1, 1):
        for y, r in ((-1.4, 0.55), (1.3, 0.72)):
            p += wheel(f"W{s}{y}", r, (s * 1.0, y, r), red, dark)
    # Canvas bonnet over hoops.
    for k in range(5):
        y = -1.8 + k * 0.9
        p.append(torus(f"Hoop{k}", 1.0, 0.05, (0, y, 1.45), rot=rad(90, 0, 0), m=dark, major_segs=20, minor_segs=4, arc=math.pi))
    p.append(half_tube("Bonnet", 1.02, 3.8, (0, 0, 1.45), canvas))
    p += [tube("Tongue", [(0, -2.0, 0.8), (0, -3.3, 0.55)], 0.06, m=dark, segs=6),
          box("Seat", (1.6, 0.4, 0.12), (0, -1.75, 1.6), bevel=0.03, m=dark),
          cyl("Barrel", 0.28, 0.6, (0.6, 1.9, 1.3), rot=rad(90, 0, 0), segs=12, bevel=0.03, m=wood),
          box("Axle", (2.2, 0.12, 0.12), (0, -1.4, 0.55), bevel=0.0, m=iron),
          box("AxleB", (2.2, 0.12, 0.12), (0, 1.3, 0.72), bevel=0.0, m=iron)]
    save("gulch_wagon", [merge("Wagon", p)])


def bale(prefix, size, loc, rot_z=0.0):
    straw, dark = gmat("Straw", rough=0.95), gmat("StrawDark", rough=0.95)
    sx, sy, sz = size
    p = [box(prefix, size, loc, rot=(0, 0, rot_z), bevel=0.08, m=straw)]
    for s in (-1, 1):
        p.append(box(f"{prefix}Twine{s}", (sx + 0.02, 0.05, sz + 0.02), (loc[0], loc[1] + s * sy * 0.25, loc[2]), bevel=0.0, m=dark))
    return p


def build_hay():
    reset_scene()
    p = bale("BaleA", (1.5, 0.95, 0.55), (0, 0, 0.275)) + bale("BaleB", (1.5, 0.95, 0.55), (0.05, 0.02, 0.825))
    p += bale("BaleC", (1.0, 0.7, 0.45), (0.0, 0.0, 1.33))
    save("gulch_hay", [merge("Hay", p)])


def barrel(prefix, loc, m=None):
    m = m or gmat("Wood")
    iron = gmat("Iron", rough=0.5)
    x, y, z = loc
    p = [lathe(prefix, [(0.3, z), (0.36, z + 0.45), (0.3, z + 0.9)], [m], segs=14, smooth=True)]
    p[0].location = (x, y, 0)
    for k, h in enumerate((0.12, 0.35, 0.55, 0.78)):
        p.append(torus(f"{prefix}Hoop{k}", 0.34 if 0.2 < h < 0.7 else 0.32, 0.025, (x, y, z + h), m=iron, major_segs=14, minor_segs=4))
    p.append(cyl(f"{prefix}Lid", 0.29, 0.03, (x, y, z + 0.9), segs=14, bevel=0.0, m=gmat("WoodDark")))
    return p


def build_barrels():
    reset_scene()
    p = barrel("BarA", (-0.4, 0, 0)) + barrel("BarB", (0.4, 0.05, 0)) + barrel("BarC", (0, -0.1, 0.9), m=gmat("RedDark"))
    p.append(text("XXX", "XXX", 0.16, 0.02, (0.4, -0.37, 0.45), m=gmat("Ink")))
    save("gulch_barrels", [merge("Barrels", p)])


def build_crates():
    reset_scene()
    wood, light, dark = gmat("Wood"), gmat("WoodLight"), gmat("WoodDark")
    p = []
    for i, (size, loc, rz) in enumerate((((0.9, 0.9, 0.8), (-0.35, 0, 0.4), 0.05), ((0.8, 0.8, 0.7), (0.45, 0.1, 0.35), -0.1),
                                         ((0.7, 0.7, 0.6), (-0.2, 0.05, 1.1), 0.2))):
        p.append(box(f"Crate{i}", size, loc, rot=(0, 0, rz), bevel=0.04, m=light))
        for s in (-1, 1):
            b = box(f"Slat{i}{s}", (size[0] + 0.02, 0.06, size[2] * 0.9), (loc[0], loc[1] + s * (size[1] / 2 + 0.0), loc[2]), bevel=0.0, m=dark)
            p.append(b)
        p.append(text(f"Label{i}", "TNT" if i == 1 else "GOLD", 0.16, 0.01, (loc[0], loc[1] - size[1] / 2 - 0.04, loc[2] + 0.1),
                      rot=(0, 0, 0), m=gmat("Red", rough=0.5) if i == 1 else gmat("GoldDark", rough=0.5)))
    save("gulch_crates", [merge("Crates", p)])


def cactus_arm(prefix, base, side, up, out, r, m):
    x, y, z = base
    pts = [(x, y, z), (x + side * out * 0.6, y, z + 0.05), (x + side * out, y, z + 0.35), (x + side * out, y, z + up)]
    p = [tube(prefix, pts, r, m=m, segs=10)]
    p.append(sphere(prefix + "Tip", r, (x + side * out, y, z + up), m=m, segs=10, rings=6))
    return p


def cactus(name, height, arms, seed):
    reset_scene()
    rng = random.Random(seed)
    m, dark = gmat("Cactus", rough=0.7), gmat("CactusDark", rough=0.7)
    r = 0.32
    p = [cyl("Trunk", r, height - r, (0, 0, (height - r) / 2), segs=12, bevel=0.05, m=m),
         sphere("Top", r, (0, 0, height - r), m=m, segs=12, rings=7)]
    for k in range(8):
        a = math.tau * k / 8
        p.append(box(f"Rib{k}", (0.05, 0.05, height - 0.6), (math.cos(a) * r, math.sin(a) * r, (height - 0.6) / 2 + 0.1), rot=(0, 0, a), bevel=0.0, m=dark))
    for i, (side, z, up, out) in enumerate(arms):
        p += cactus_arm(f"Arm{i}", (side * r * 0.8, 0, z), side, up, out, r * 0.7, m)
    p.append(sphere("Flower", 0.12, (0.05, -0.1, height + 0.02), m=gmat("Red", rough=0.5), segs=8, rings=5))
    save(name, [merge("Cactus", p)])


def build_cactus_a():
    cactus("gulch_cactus_a", 3.6, [(-1, 1.3, 1.1, 0.7), (1, 1.8, 0.9, 0.6)], 1)


def build_cactus_b():
    cactus("gulch_cactus_b", 2.6, [(1, 1.0, 0.8, 0.55)], 2)


def build_trough():
    reset_scene()
    wood, dark = gmat("WoodLight"), gmat("WoodDark")
    p = [box("Tub", (2.4, 0.8, 0.5), (0, 0, 0.55), bevel=0.05, m=wood),
         box("Water", (2.2, 0.6, 0.05), (0, 0, 0.72), bevel=0.0, m=gmat("TurqLight", rough=0.1))]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box(f"Leg{sx}{sy}", (0.12, 0.12, 0.35), (sx * 1.05, sy * 0.3, 0.17), bevel=0.02, m=dark))
    for sx in (-1, 0, 1):
        p.append(box(f"Band{sx}", (0.08, 0.84, 0.54), (sx * 0.9, 0, 0.55), bevel=0.0, m=gmat("Iron")))
    save("gulch_trough", [merge("Trough", p)])


def build_hitch():
    reset_scene()
    wood, dark = gmat("Wood"), gmat("WoodDark")
    p = [cyl("Rail", 0.08, 3.0, (0, 0, 1.0), rot=rad(0, 90, 0), segs=10, bevel=0.02, m=wood)]
    for x in (-1.3, 1.3):
        p.append(box(f"Post{x}", (0.18, 0.18, 1.1), (x, 0, 0.55), bevel=0.03, m=dark))
    p.append(torus("Ring", 0.08, 0.015, (0.4, -0.08, 0.92), rot=rad(90, 0, 0), m=gmat("Iron"), major_segs=10, minor_segs=4))
    save("gulch_hitch", [merge("Hitch", p)])


def build_lamp():
    reset_scene()
    dark, iron = gmat("WoodDark"), gmat("Iron", rough=0.5)
    bulb_m = gglow("GulchLampGlow", "#ffd88a", 3.0)
    p = [box("Post", (0.2, 0.2, 3.2), (0, 0, 1.6), bevel=0.03, m=dark),
         box("Arm", (0.9, 0.1, 0.1), (0.4, 0, 3.0), bevel=0.02, m=dark),
         box("Brace", (0.06, 0.06, 0.7), (0.25, 0, 2.7), rot=(0, 0.8, 0), bevel=0.0, m=dark),
         cyl("Cage", 0.17, 0.42, (0.75, 0, 2.65), segs=8, bevel=0.02, m=iron),
         cyl("CageTop", 0.2, 0.08, (0.75, 0, 2.9), segs=8, bevel=0.02, m=iron, radius_top=0.08),
         bulb("Bulb", 0.13, (0.75, 0, 2.65), bulb_m),
         box("Foot", (0.45, 0.45, 0.2), (0, 0, 0.1), bevel=0.03, m=dark)]
    save("gulch_lamp", [merge("Lamp", p)])


def build_fence():
    reset_scene()
    wood, dark = gmat("WoodGrey", rough=0.85), gmat("WoodDark")
    p = [box("Post", (0.18, 0.18, 1.25), (-1.25, 0, 0.62), bevel=0.03, m=dark)]
    for k, z in enumerate((0.45, 0.95)):
        p.append(box(f"Rail{k}", (2.6, 0.1, 0.16), (0, 0, z), rot=(0.0, 0.03 * (k * 2 - 1), 0), bevel=0.02, m=wood))
    save("gulch_fence", [merge("Fence", p)])


def build_palisade():
    reset_scene()
    wood, dark = gmat("Wood"), gmat("WoodDark")
    p = []
    for k in range(5):
        x = -0.8 + k * 0.4
        h = 3.0 + (0.15 if k % 2 else 0.0)
        p.append(cyl(f"Log{k}", 0.2, h, (x, 0, h / 2), segs=8, bevel=0.03, m=wood if k % 2 else dark))
        p.append(cyl(f"Tip{k}", 0.2, 0.4, (x, 0, h + 0.2), segs=8, bevel=0.0, m=wood if k % 2 else dark, radius_top=0.01))
    p.append(box("Band", (2.0, 0.5, 0.18), (0, 0.05, 2.2), bevel=0.02, m=dark))
    save("gulch_palisade", [merge("Palisade", p)])


def build_windmill():
    reset_scene()
    wood, dark, red = gmat("WoodLight"), gmat("WoodDark"), gmat("Red", rough=0.6)
    p = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(tube(f"Leg{sx}{sy}", [(sx * 1.6, sy * 1.6, 0), (sx * 0.35, sy * 0.35, 10.0)], 0.1, m=dark, segs=6))
    for k in range(4):
        z = 1.5 + k * 2.2
        w = 1.6 - (1.25 * z / 10.0)
        for i in range(4):
            a = math.tau * i / 4
            pa = (math.cos(a) * w * 1.414, math.sin(a) * w * 1.414, z)
            pb = (math.cos(a + math.pi / 2) * w * 1.414, math.sin(a + math.pi / 2) * w * 1.414, z)
            p.append(tube(f"Ring{k}{i}", [pa, pb], 0.05, m=wood, segs=4))
    p += [box("Head", (0.5, 1.2, 0.5), (0, 0.2, 10.3), bevel=0.06, m=red),
          prism("Tail", [(0, 0), (0, 1.2), (-0.15, 1.0), (-0.15, 0.2)], 0.04, (0, 1.6, 10.3), rot=rad(0, 0, 90), m=red),
          box("TailBoom", (0.08, 1.4, 0.08), (0, 1.3, 10.3), bevel=0.0, m=dark)]
    p[-2].location = (0, 2.0, 9.8)
    p[-2].rotation_euler = rad(0, 0, 90)
    save("gulch_windmill", [merge("Windmill", p)])
    reset_scene()
    blades = []
    for k in range(14):
        a = math.tau * k / 14
        blades.append(box(f"Blade{k}", (0.32, 0.03, 1.5), (math.cos(a) * 1.05, 0, math.sin(a) * 1.05), rot=(0.3, -a + math.pi / 2, 0), bevel=0.01,
                          m=gmat("Cream", rough=0.6) if k % 2 else gmat("Red", rough=0.6)))
    blades += [torus("WheelRim", 1.8, 0.04, (0, 0, 0), rot=rad(90, 0, 0), m=gmat("Iron"), major_segs=24, minor_segs=4),
               cyl("WheelHub", 0.18, 0.3, (0, 0, 0), rot=rad(90, 0, 0), segs=10, bevel=0.03, m=gmat("Iron"))]
    save("gulch_windmill_wheel", [merge("WindmillWheel", blades)])


def coaster_base(prefix, body_m, trim_m):
    """Chassis and bogies of a 2 m coaster car riding on rails 1.0 m apart (the
    car's origin sits on the rail tops, the car points along -Y)."""
    iron = gmat("Iron", rough=0.45, metal=0.3)
    p = [box(prefix + "Chassis", (1.3, 1.9, 0.2), (0, 0, 0.32), bevel=0.04, m=iron)]
    for y in (-0.6, 0.6):
        for s in (-1, 1):
            p.append(cyl(f"{prefix}Wheel{y}{s}", 0.17, 0.12, (s * 0.5, y, 0.17), rot=rad(0, 90, 0), segs=12, bevel=0.02, m=gmat("Ink", rough=0.5)))
    p.append(box(prefix + "Bumper", (1.0, 0.12, 0.16), (0, 1.0, 0.36), bevel=0.03, m=trim_m))
    return p


def build_coaster():
    reset_scene()
    red, gold, dark = gmat("Red", rough=0.45), gmat("Gold", rough=0.3, metal=0.5), gmat("Ink", rough=0.5)
    p = coaster_base("L", red, gold)
    # A toy steam loco: boiler, smokestack, cab, cowcatcher, headlamp.
    p += [cyl("Boiler", 0.48, 1.3, (0, -0.25, 0.92), rot=rad(90, 0, 0), segs=16, bevel=0.05, m=red),
          cyl("BoilerFront", 0.5, 0.12, (0, -0.92, 0.92), rot=rad(90, 0, 0), segs=16, bevel=0.03, m=gold),
          cyl("Stack", 0.16, 0.6, (0, -0.55, 1.55), segs=12, bevel=0.03, m=dark, radius_top=0.24),
          cyl("StackRim", 0.27, 0.1, (0, -0.55, 1.88), segs=12, bevel=0.02, m=gold),
          box("Cab", (1.2, 0.7, 1.1), (0, 0.6, 1.0), bevel=0.06, m=red),
          box("CabRoof", (1.4, 0.9, 0.12), (0, 0.6, 1.62), bevel=0.04, m=dark),
          box("CabWin", (1.22, 0.4, 0.4), (0, 0.6, 1.2), bevel=0.02, m=gmat("Glass", rough=0.2)),
          prism("Catcher", [(-0.55, 0.0), (0.55, 0.0), (0.0, -0.45)], 0.4, (0, -1.05, 0.28), rot=rad(90, 0, 0), m=gold),
          sphere("Dome", 0.2, (0, 0.0, 1.38), m=gold, segs=10, rings=6),
          bulb("Headlamp", 0.13, (0, -1.0, 1.25), gglow("GulchHeadlamp", "#fff2b8", 4.0))]
    p[-3].location = (0, -1.05, 0.34)
    p[-3].rotation_euler = rad(0, 0, 0)
    for s in (-1, 1):
        p.append(cyl(f"Piston{s}", 0.1, 0.6, (s * 0.55, -0.6, 0.45), rot=rad(90, 0, 0), segs=8, bevel=0.02, m=gold))
    save("gulch_coaster_loco", [merge("CoasterLoco", p)])
    reset_scene()
    red, gold, wood = gmat("Red", rough=0.45), gmat("Gold", rough=0.25, metal=0.6), gmat("Wood")
    p = coaster_base("C", red, gold)
    p += [box("Tub", (1.3, 1.7, 0.8), (0, 0, 0.82), bevel=0.08, m=wood),
          box("Band", (1.34, 1.74, 0.12), (0, 0, 1.08), bevel=0.03, m=red),
          box("BandLow", (1.34, 1.74, 0.1), (0, 0, 0.55), bevel=0.03, m=gmat("Iron"))]
    rng = random.Random(4)
    for k in range(9):
        p.append(sphere(f"Nugget{k}", rng.uniform(0.18, 0.28), (rng.uniform(-0.4, 0.4), rng.uniform(-0.6, 0.6), 1.25 + rng.uniform(0, 0.12)),
                        scale=(1, 1, 0.75), m=gold, segs=6, rings=4))
    save("gulch_coaster_car", [merge("CoasterCar", p)])


def build_tumbleweed():
    reset_scene()
    m = gmat("StrawDark", rough=0.95)
    rng = random.Random(9)
    p = []
    for k in range(9):
        a, b = rng.uniform(0, math.tau), rng.uniform(0, math.pi)
        p.append(torus(f"Twig{k}", rng.uniform(0.38, 0.5), 0.025, (0, 0, 0), rot=(b, a, rng.uniform(0, math.pi)), m=m, major_segs=14, minor_segs=3))
    save("gulch_tumbleweed", [merge("Tumbleweed", p)])


def build_exit_lantern():
    reset_scene()
    dark, iron = gmat("WoodDark"), gmat("Iron", rough=0.5)
    glow = mat("GulchExitGlow", "#ffd070", rough=0.3, emit=2.0)
    p = [box("Post", (0.16, 0.16, 1.7), (0, 0, 0.85), bevel=0.03, m=dark),
         cyl("Cage", 0.16, 0.36, (0, 0, 1.9), segs=8, bevel=0.02, m=iron),
         cyl("Glass", 0.12, 0.3, (0, 0, 1.9), segs=8, bevel=0.0, m=glow),
         cyl("Hat", 0.2, 0.12, (0, 0, 2.13), segs=8, bevel=0.02, m=iron, radius_top=0.06),
         box("Arrow", (0.5, 0.05, 0.16), (0.1, -0.1, 1.35), bevel=0.02, m=gmat("Cream", rough=0.6)),
         box("Foot", (0.4, 0.4, 0.14), (0, 0, 0.07), bevel=0.03, m=dark)]
    save("gulch_exit_lantern", [merge("ExitLantern", p)])


def build_boulder():
    reset_scene()
    p = [mesa("Boulder", subdivide_outline(rounded_rect(2.4, 2.0, 3), 0.5), [(0.6, 1.0), (0.5, 0.9), (0.3, 0.7)], seed=5, jag=0.12)]
    save("gulch_boulder", [merge("Boulder", p)])


def build_cliff():
    reset_scene()
    outline = subdivide_outline(rounded_rect(30.0, 10.0, 4, 3.0), 2.0)
    bands = [(3.0, 1.0), (2.2, 0.97), (0.0, 0.95), (3.4, 0.95), (2.5, 0.93), (0.0, 0.9), (2.6, 0.9), (2.3, 0.88)]
    bands = [b for b in bands if b[0] > 0]
    p = [mesa("Cliff", outline, bands, seed=11, jag=0.6)]
    save("gulch_cliff", [merge("Cliff", p)])


def build_butte():
    reset_scene()
    outline = subdivide_outline(rounded_rect(12.0, 12.0, 4, 4.0), 1.6)
    bands = [(4.0, 1.25), (3.0, 1.1), (4.0, 0.95), (5.0, 0.9), (4.0, 0.86), (4.5, 0.84), (3.5, 0.82)]
    p = [mesa("Butte", outline, bands, seed=13, jag=0.5)]
    save("gulch_butte", [merge("Butte", p)])


def build_mesa_far():
    reset_scene()
    outline = subdivide_outline(rounded_rect(70.0, 30.0, 5, 10.0), 4.0)
    bands = [(5.0, 1.1), (4.0, 1.0), (5.0, 0.95), (4.0, 0.9), (4.0, 0.88)]
    p = [mesa("MesaFar", outline, bands, seed=17, jag=1.4)]
    save("gulch_mesa_far", [merge("MesaFar", p)])


def build_coaster_lamp():
    reset_scene()
    p = [box("Arm", (0.08, 0.08, 0.5), (0, 0, 0.25), bevel=0.0, m=gmat("Iron")),
         bulb("Bulb", 0.11, (0, 0, 0.55), gglow("GulchTrackGlow", "#ffe07a", 4.0))]
    save("gulch_coaster_lamp", [merge("CoasterLamp", p)])


BUILDERS = {
    "wagon": build_wagon, "hay": build_hay, "barrels": build_barrels, "crates": build_crates, "cactus_a": build_cactus_a,
    "cactus_b": build_cactus_b, "trough": build_trough, "hitch": build_hitch, "lamp": build_lamp, "fence": build_fence,
    "palisade": build_palisade, "windmill": build_windmill, "coaster": build_coaster, "tumbleweed": build_tumbleweed,
    "exit_lantern": build_exit_lantern, "boulder": build_boulder, "cliff": build_cliff, "butte": build_butte, "mesa_far": build_mesa_far,
    "coaster_lamp": build_coaster_lamp,
}

if __name__ == "__main__":
    wanted = [a for a in sys.argv[1:] if a in BUILDERS] or list(BUILDERS)
    for key in wanted:
        BUILDERS[key]()
