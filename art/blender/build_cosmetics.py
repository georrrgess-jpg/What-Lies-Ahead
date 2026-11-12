"""Cosmetic props: weapon charms and sticker decal emblems.

    cosmetic_charms.glb   one node per charm, "Charm_<name>". Each charm's
                          origin is its hanging ring, and the trinket hangs
                          down from it (-Z in Blender, -Y in Godot) with its
                          front facing -Y (Godot +Z). The game swings it from
                          the weapon's CharmPoint (scripts/cosmetics/weapon_charm.gd).
    cosmetic_decals.glb   one node per emblem, "Emblem_<name>": a two-layer
                          sticker (materials "DecalEdge" behind, "DecalFill"
                          on top, optional "DecalInk" details) facing -X like
                          the weapons' own emblems, centred on its origin and
                          normalised to 1 unit across; the game scales it to
                          the weapon's Decal node (scripts/player/weapon_cosmetics.gd).

Charm materials keep their own colours. Materials whose names start with
"FxGlass" are swapped for a glass shader in game.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403


# ---------------------------------------------------------------------------
# Charms
# ---------------------------------------------------------------------------

def charm_mats():
    return dict(
        ring=mat("CharmRing", "#c9c6d2", rough=0.25, metal=0.85),
        yellow=mat("CharmYellow", "#ffd93b", rough=0.35),
        orange=mat("CharmOrange", "#ff8a2a", rough=0.4),
        black=mat("CharmBlack", "#1c1830", rough=0.3),
        white=mat("CharmWhite", "#f7f4f2", rough=0.35),
        pink=mat("CharmPink", "#ff3f9f", rough=0.4),
        red=mat("CharmRed", "#e8263a", rough=0.4),
        cream=mat("CharmCream", "#fff0d4", rough=0.5),
        waffle=mat("CharmWaffle", "#d9934a", rough=0.6),
        waffle_dark=mat("CharmWaffleDark", "#a8652e", rough=0.6),
        gold=mat("CharmGold", "#ffc23d", rough=0.22, metal=0.9),
        gold_dark=mat("CharmGoldDark", "#d18a1c", rough=0.3, metal=0.85),
        green=mat("CharmGreen", "#8fd14a", rough=0.6),
        green_dark=mat("CharmGreenDark", "#4f8f2f", rough=0.6),
        blue=mat("CharmBlue", "#3a7be0", rough=0.3),
        cyan=mat("CharmCyan", "#33f0ff", rough=0.3, emit=1.6),
        flame=mat("CharmFlame", "#ffb62e", rough=0.4, emit=2.4),
        neon=mat("CharmNeon", "#ff4fb0", rough=0.3, emit=2.2),
        neon_core=mat("CharmNeonCore", "#ffd6ef", rough=0.3, emit=2.8),
        glass=mat("FxGlassCharm", "#bfefff", rough=0.05),
        gem_red=mat("CharmGemRed", "#ff2f5f", rough=0.15, emit=0.6),
        gem_blue=mat("CharmGemBlue", "#3fc4ff", rough=0.15, emit=0.6),
        tree=mat("CharmTree", "#2f9f5a", rough=0.6),
        purple=mat("CharmPurple", "#8a4fe0", rough=0.4),
    )


def hanger(prefix, m, drop=0.02):
    """Split ring plus two chain links: the trinket starts at z = -drop."""
    return [
        torus(prefix + "Ring", 0.0062, 0.0016, (0, 0, -0.0062), rot=rad(90, 0, 0), m=m["ring"], major_segs=14, minor_segs=5),
        torus(prefix + "LinkA", 0.0042, 0.0013, (0, 0, -0.0128), rot=rad(90, 0, 90), m=m["ring"], major_segs=10, minor_segs=4),
        torus(prefix + "LinkB", 0.0042, 0.0013, (0, 0, -0.0175), rot=rad(90, 0, 0), m=m["ring"], major_segs=10, minor_segs=4),
        sphere(prefix + "Bead", 0.0026, (0, 0, -drop + 0.001), m=m["ring"], segs=8, rings=5),
    ]


def charm_duck(m):
    p = "Duck"
    z = -0.05
    parts = hanger(p, m)
    parts += [
        sphere(p + "Body", 0.02, (0, 0.004, z - 0.006), scale=(1.0, 1.25, 0.78), m=m["yellow"], segs=16, rings=10),
        sphere(p + "Tail", 0.009, (0, 0.027, z + 0.004), scale=(0.9, 1.0, 1.2), rot=rad(-30, 0, 0), m=m["yellow"], segs=10, rings=6),
        sphere(p + "Head", 0.0135, (0, -0.01, z + 0.018), m=m["yellow"], segs=14, rings=9),
        sphere(p + "Beak", 0.0075, (0, -0.024, z + 0.014), scale=(1.2, 1.1, 0.55), m=m["orange"], segs=10, rings=6),
        sphere(p + "Tuft", 0.004, (0, -0.008, z + 0.032), scale=(0.6, 1.3, 1.4), m=m["yellow"], segs=8, rings=5),
    ]
    for side in (-1, 1):
        parts += [
            sphere(f"{p}Eye{side}", 0.0028, (side * 0.0075, -0.021, z + 0.022), m=m["black"], segs=8, rings=5),
            sphere(f"{p}Shine{side}", 0.0009, (side * 0.0068, -0.0236, z + 0.0235), m=m["white"], segs=6, rings=4),
            sphere(f"{p}Wing{side}", 0.011, (side * 0.018, 0.006, z - 0.004), scale=(0.35, 1.0, 0.7), rot=rad(-15, 0, 0), m=m["yellow"], segs=10, rings=6),
            sphere(f"{p}Cheek{side}", 0.0032, (side * 0.0105, -0.0165, z + 0.0155), scale=(1, 0.4, 0.7), m=m["orange"], segs=6, rings=4),
        ]
    return parts


def charm_dice(m):
    p = "Dice"
    s = 0.03
    c = (0, 0, -0.02 - s * 0.62)
    die = box(p + "Cube", (s, s, s), (0, 0, 0), bevel=0.0075, segs=3, m=m["white"])
    pips = []
    half = s / 2 + 0.0004

    def pip(name, pos):
        pips.append(sphere(p + name, 0.0032, pos, scale=(1, 1, 1), m=m["pink"], segs=8, rings=5))

    # Front (-Y) shows 5, right (+X) shows 3, top (+Z) shows 1, left 2, back 6, bottom 4.
    o = s * 0.27
    for i, (u, v) in enumerate(((0, 0), (-o, -o), (o, o), (-o, o), (o, -o))):
        pip(f"F{i}", (u, -half, v))
    for i, (u, v) in enumerate(((0, 0), (-o, -o), (o, o))):
        pip(f"R{i}", (half, u, v))
    pip("T0", (0, 0, half))
    for i, (u, v) in enumerate(((-o, -o), (o, o))):
        pip(f"L{i}", (-half, u, v))
    for i, (u, v) in enumerate(((-o, -o), (-o, 0), (-o, o), (o, -o), (o, 0), (o, o))):
        pip(f"B{i}", (u, half, v))
    for i, (u, v) in enumerate(((-o, -o), (o, o), (-o, o), (o, -o))):
        pip(f"D{i}", (u, v, -half))
    cube = [die] + pips
    for ob in cube:
        ob.matrix_world = Matrix.Translation(Vector(c)) @ Matrix.Rotation(math.radians(18), 4, "Z") @ Matrix.Rotation(math.radians(12), 4, "X") @ ob.matrix_basis
    return hanger(p, m) + cube


def charm_soft_serve(m):
    p = "Cone"
    top = -0.022
    parts = hanger(p, m)
    parts += [
        sphere(p + "Cherry", 0.0062, (0, 0, top - 0.004), m=m["red"], segs=12, rings=8),
        sphere(p + "Swirl0", 0.0085, (0, 0, top - 0.013), scale=(1, 1, 0.8), m=m["pink"], segs=14, rings=8),
        torus(p + "Swirl1", 0.0085, 0.0058, (0, 0, top - 0.02), m=m["pink"], major_segs=16, minor_segs=8),
        torus(p + "Swirl2", 0.0115, 0.0066, (0, 0, top - 0.029), m=m["cream"], major_segs=18, minor_segs=8),
        torus(p + "Swirl3", 0.013, 0.0066, (0, 0, top - 0.037), m=m["pink"], major_segs=18, minor_segs=8),
        cyl(p + "Rim", 0.0165, 0.006, (0, 0, top - 0.044), segs=18, bevel=0.002, m=m["waffle_dark"]),
        cyl(p + "Cone", 0.015, 0.042, (0, 0, top - 0.068), segs=16, bevel=0.002, m=m["waffle"], radius_top=0.0015),
    ]
    # Turn the cone the right way up: wide end at the top.
    parts[-1].rotation_euler = rad(180, 0, 0)
    for i in range(4):
        a = i * 45
        parts.append(box(f"{p}Grid{i}", (0.0018, 0.032, 0.0018), (0, 0, top - 0.064), rot=rad(0, 70 if i % 2 else -70, a), bevel=0.0, m=m["waffle_dark"]))
    for i in range(5):
        a = math.tau * i / 5
        parts.append(box(f"{p}Sprinkle{i}", (0.0055, 0.0016, 0.0016), (math.cos(a) * 0.012, math.sin(a) * 0.012 - 0.002, top - 0.03 + (i % 2) * 0.006),
                         rot=rad(0, 30 * i, a * 57), bevel=0.0006, m=[m["yellow"], m["cyan"], m["white"]][i % 3]))
    return parts


def charm_starfish(m):
    p = "Star"
    r = 0.024
    c = (0, 0, -0.02 - r * 0.92)
    parts = hanger(p, m)
    body = prism(p + "Body", star_outline(r, r * 0.45, 5, 90), 0.009, c, m=m["orange"], bevel=0.0035, segs=3)
    parts.append(body)
    for i in range(5):
        a = math.radians(90) + math.tau * i / 5
        for k, f in enumerate((0.35, 0.62)):
            parts.append(sphere(f"{p}Dot{i}{k}", 0.0022 - k * 0.0005, (c[0] + math.cos(a) * r * f, -0.0048, c[2] + math.sin(a) * r * f),
                                scale=(1, 0.5, 1), m=m["cream"], segs=6, rings=4))
    for side in (-1, 1):
        parts.append(sphere(f"{p}Eye{side}", 0.0026, (side * 0.0045, -0.0052, c[2] + 0.002), m=m["black"], segs=8, rings=5))
    parts.append(torus(p + "Smile", 0.0035, 0.0009, (0, -0.0052, c[2] - 0.0035), rot=rad(90, 0, 0), m=m["black"], major_segs=10, minor_segs=4,
                       arc=math.pi * 0.8, start=math.pi * 1.1))
    return parts


def charm_rocket(m):
    p = "Rocket"
    parts = hanger(p, m)
    z = -0.022
    parts += [
        cyl(p + "Nose", 0.0095, 0.016, (0, 0, z - 0.008), segs=16, bevel=0.001, m=m["red"], radius_top=0.0008),
        cyl(p + "Body", 0.0095, 0.03, (0, 0, z - 0.031), segs=16, bevel=0.002, m=m["white"]),
        cyl(p + "Band", 0.0099, 0.004, (0, 0, z - 0.02), segs=16, bevel=0.001, m=m["red"]),
        cyl(p + "Nozzle", 0.0075, 0.006, (0, 0, z - 0.049), segs=12, bevel=0.001, m=m["black"], radius_top=0.0058),
        cyl(p + "Flame", 0.005, 0.014, (0, 0, z - 0.06), segs=12, bevel=0.0, m=m["flame"], radius_top=0.0001),
        cyl(p + "Window", 0.0042, 0.003, (0, -0.0092, z - 0.028), rot=rad(90, 0, 0), segs=14, bevel=0.0008, m=m["ring"]),
        cyl(p + "Glass", 0.0031, 0.002, (0, -0.0105, z - 0.028), rot=rad(90, 0, 0), segs=14, bevel=0.0006, m=m["cyan"]),
    ]
    parts[-3].rotation_euler = rad(180, 0, 0)
    for i in range(3):
        a = math.tau * i / 3 + math.pi / 2
        fin = prism(f"{p}Fin{i}", [(0, 0), (0.009, -0.009), (0.009, -0.016), (0, -0.012)], 0.0022, (0, 0, 0), m=m["red"], bevel=0.0008)
        fin.matrix_world = Matrix.Translation((math.cos(a) * 0.008, math.sin(a) * 0.008, z - 0.036)) @ Matrix.Rotation(a - math.pi / 2, 4, "Z")
        parts.append(fin)
    return parts


def charm_ticket(m):
    p = "Ticket"
    w, h = 0.05, 0.028
    c = (0, 0, -0.02 - h / 2 - 0.002)
    parts = hanger(p, m)
    parts += [
        box(p + "Stub", (w, 0.0045, h), c, bevel=0.002, m=m["gold"]),
        box(p + "Inner", (w - 0.008, 0.005, h - 0.008), c, bevel=0.0015, m=m["gold_dark"]),
        prism(p + "Star", star_outline(0.0082, 0.0038, 5, 90), 0.0024, (c[0] - 0.006, -0.0034, c[2]), m=m["pink"], bevel=0.0006),
        torus(p + "Hole", 0.0028, 0.0009, (0, -0.0024, c[2] + h / 2 - 0.004), rot=rad(90, 0, 0), m=m["gold_dark"], major_segs=10, minor_segs=4),
    ]
    for i in range(3):
        parts.append(box(f"{p}Line{i}", (0.012, 0.0024, 0.0018), (c[0] + 0.012, -0.0034, c[2] + 0.005 - i * 0.005), bevel=0.0005, m=m["pink"]))
    for side in (-1, 1):
        parts.append(cyl(f"{p}Notch{side}", 0.0042, 0.0062, (side * w / 2, 0, c[2]), rot=rad(90, 0, 0), segs=12, bevel=0.0005, m=m["black"]))
    return parts


def charm_life_ring(m):
    p = "Buoy"
    r = 0.017
    c = (0, 0, -0.02 - r - 0.006)
    parts = hanger(p, m)
    for i in range(4):
        parts.append(torus(f"{p}Seg{i}", r, 0.0065, c, rot=rad(90, 0, 0), m=m["red"] if i % 2 == 0 else m["white"],
                           major_segs=8, minor_segs=8, arc=math.pi / 2, start=math.pi / 4 + i * math.pi / 2))
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        parts.append(torus(f"{p}Rope{i}", 0.0072, 0.0012, (c[0] + math.cos(a) * r, 0, c[2] + math.sin(a) * r), rot=rad(0, -math.degrees(a), 0),
                           m=m["cream"], major_segs=10, minor_segs=4))
    return parts


def charm_token(m):
    p = "Token"
    r = 0.019
    c = (0, 0, -0.02 - r - 0.001)
    parts = hanger(p, m)
    parts += [
        cyl(p + "Coin", r, 0.0055, c, rot=rad(90, 0, 0), segs=24, bevel=0.0018, m=m["gold"]),
        torus(p + "RimF", r - 0.0022, 0.0012, (c[0], -0.0028, c[2]), rot=rad(90, 0, 0), m=m["gold_dark"], major_segs=24, minor_segs=4),
        torus(p + "RimB", r - 0.0022, 0.0012, (c[0], 0.0028, c[2]), rot=rad(90, 0, 0), m=m["gold_dark"], major_segs=24, minor_segs=4),
        prism(p + "StarF", star_outline(0.0105, 0.0048, 5, 90), 0.0024, (c[0], -0.0028, c[2]), m=m["gold_dark"], bevel=0.0006),
        prism(p + "StarB", star_outline(0.0105, 0.0048, 5, 90), 0.0024, (c[0], 0.0028, c[2]), m=m["gold_dark"], bevel=0.0006),
    ]
    return parts


def charm_plush(m):
    p = "Plush"
    s = 0.036
    c = (0, 0, -0.02 - s * 0.5)
    parts = hanger(p, m)
    parts += [
        box(p + "Head", (s, s * 0.85, s * 0.92), c, bevel=0.012, segs=4, m=m["green"]),
        box(p + "Stitch", (0.0016, s * 0.87, s * 0.5), (c[0] + 0.004, 0, c[2] + s * 0.25), bevel=0.0, m=m["green_dark"]),
        sphere(p + "Tuft", 0.006, (0.004, 0, c[2] + s * 0.5), scale=(0.6, 0.6, 1.4), rot=rad(0, 25, 0), m=m["green_dark"], segs=8, rings=5),
        # Button eye.
        cyl(p + "Button", 0.0065, 0.0025, (0.0085, -s * 0.43, c[2] + 0.004), rot=rad(90, 0, 0), segs=14, bevel=0.0008, m=m["pink"]),
        # Stitched mouth.
        box(p + "Mouth", (0.02, 0.0016, 0.0016), (0, -s * 0.43, c[2] - 0.009), bevel=0.0, m=m["black"]),
    ]
    for i in range(2):
        parts.append(sphere(f"{p}Hole{i}", 0.0011, (0.0085 + (i - 0.5) * 0.004, -s * 0.43 - 0.0014, c[2] + 0.004), m=m["black"], segs=6, rings=4))
    for k in (-1, 1):
        parts.append(box(f"{p}X{k}", (0.011, 0.0016, 0.0022), (-0.0085, -s * 0.43, c[2] + 0.004), rot=rad(0, k * 45, 0), bevel=0.0, m=m["black"]))
    for i in range(4):
        parts.append(box(f"{p}Tick{i}", (0.0016, 0.0016, 0.006), (-0.0075 + i * 0.005, -s * 0.43, c[2] - 0.009), bevel=0.0, m=m["black"]))
    for side in (-1, 1):
        parts.append(sphere(f"{p}Ear{side}", 0.0055, (side * s * 0.52, 0, c[2] + 0.002), scale=(0.6, 0.8, 1.0), m=m["green"], segs=8, rings=5))
    return parts


def charm_snow_globe(m):
    p = "Globe"
    r = 0.016
    c = (0, 0, -0.02 - r - 0.002)
    parts = hanger(p, m)
    parts += [
        sphere(p + "Glass", r, c, m=m["glass"], segs=20, rings=12),
        cyl(p + "Base", r * 0.95, 0.009, (0, 0, c[2] - r * 0.92 - 0.003), segs=18, bevel=0.0025, m=m["red"], radius_top=r * 0.75),
        cyl(p + "Band", r * 0.97, 0.0028, (0, 0, c[2] - r * 0.92 - 0.0065), segs=18, bevel=0.0008, m=m["gold"]),
        sphere(p + "Snow", r * 0.8, (0, 0, c[2] - r * 0.62), scale=(1, 1, 0.32), m=m["white"], segs=14, rings=6),
        cyl(p + "Tree", 0.0062, 0.016, (0, 0, c[2] - 0.0015), segs=10, bevel=0.0, m=m["tree"], radius_top=0.0006),
        prism(p + "TreeStar", star_outline(0.0024, 0.0011, 5, 90), 0.0012, (0, 0, c[2] + 0.0072), m=m["yellow"]),
    ]
    for i, (x, y, z) in enumerate(((0.008, -0.006, 0.006), (-0.009, 0.002, 0.004), (0.004, 0.008, -0.002), (-0.005, -0.008, 0.009), (0.01, 0.004, -0.004))):
        parts.append(sphere(f"{p}Flake{i}", 0.0011, (x, y, c[2] + z), m=m["white"], segs=6, rings=4))
    return parts


def heart_outline(size, steps=28):
    pts = []
    for i in range(steps):
        t = math.tau * i / steps
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 17.0 * size, y / 17.0 * size))
    return pts


def charm_neon_heart(m):
    p = "Heart"
    s = 0.022
    c = (0, 0, -0.02 - s * 0.74)
    parts = hanger(p, m)
    parts += [
        prism(p + "Tube", heart_outline(s), 0.008, c, m=m["neon"], bevel=0.003, segs=3),
        prism(p + "Core", heart_outline(s * 0.62), 0.0095, c, m=m["neon_core"], bevel=0.0015),
    ]
    return parts


def charm_crown(m):
    p = "Crown"
    r = 0.016
    zc = -0.02 - 0.024
    parts = hanger(p, m)
    parts += [
        cyl(p + "Band", r, 0.012, (0, 0, zc - 0.008), segs=20, bevel=0.002, m=m["gold"]),
        torus(p + "RimLow", r, 0.0018, (0, 0, zc - 0.014), m=m["gold_dark"], major_segs=20, minor_segs=5),
        sphere(p + "Cushion", r * 0.85, (0, 0, zc - 0.002), scale=(1, 1, 0.7), m=m["purple"], segs=14, rings=8),
        sphere(p + "Orb", 0.0045, (0, 0, zc + 0.012), m=m["gold"], segs=10, rings=6),
    ]
    for i in range(6):
        a = math.tau * i / 6
        parts.append(cyl(f"{p}Point{i}", 0.0048, 0.014, (math.cos(a) * r * 0.92, math.sin(a) * r * 0.92, zc + 0.004), segs=8, bevel=0.0008,
                         m=m["gold"], radius_top=0.0008))
        parts.append(sphere(f"{p}Tip{i}", 0.0022, (math.cos(a) * r * 0.92, math.sin(a) * r * 0.92, zc + 0.0115), m=m["gold"], segs=8, rings=5))
        parts.append(sphere(f"{p}Gem{i}", 0.0028, (math.cos(a + 0.52) * (r + 0.0006), math.sin(a + 0.52) * (r + 0.0006), zc - 0.008),
                            scale=(1, 1, 1.3), m=m["gem_red"] if i % 2 else m["gem_blue"], segs=8, rings=5))
    return parts


CHARMS = {
    "Duck": charm_duck,
    "Dice": charm_dice,
    "SoftServe": charm_soft_serve,
    "Starfish": charm_starfish,
    "Rocket": charm_rocket,
    "Ticket": charm_ticket,
    "LifeRing": charm_life_ring,
    "Token": charm_token,
    "Plush": charm_plush,
    "SnowGlobe": charm_snow_globe,
    "NeonHeart": charm_neon_heart,
    "Crown": charm_crown,
}


def build_charms():
    reset_scene()
    m = charm_mats()
    exports = []
    for i, (name, make) in enumerate(CHARMS.items()):
        parts = make(m)
        node = merge("Charm_" + name, parts, pivot=(0, 0, 0))
        # Spread them out in the .blend so they can be inspected side by side.
        node.location = (i * 0.07, 0, 0)
        exports.append(node)
    bpy.context.view_layer.update()
    # The game places each charm itself, so export them at the origin.
    for node in exports:
        node.location = (0, 0, 0)
    save("cosmetic_charms", exports)


# ---------------------------------------------------------------------------
# Decal emblems
# ---------------------------------------------------------------------------

def offset_outline(pts, d, max_miter=2.2):
    """Grow a closed outline outward by d (miter joins, clamped)."""
    n = len(pts)
    area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    sign = 1.0 if area > 0 else -1.0   # outward normal side for this winding
    out = []
    for i in range(n):
        p0, p1, p2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % n])
        e0 = (p1 - p0).normalized()
        e1 = (p2 - p1).normalized()
        n0 = Vector((e0.y, -e0.x)) * sign
        n1 = Vector((e1.y, -e1.x)) * sign
        bis = (n0 + n1)
        if bis.length < 1e-6:
            bis = n0
        bis.normalize()
        k = min(max_miter, 1.0 / max(0.2, bis.dot(n1)))
        q = p1 + bis * d * k
        out.append((q.x, q.y))
    return out


def sticker(name, fills, details=(), edge=0.07):
    """Edge plates behind, fills on top, ink details on top of the fills. Faces
    -Y while building; turned to face -X (like the weapons' emblems) at the end."""
    fill_m = mat("DecalFill", "#ffd93b", rough=0.35)
    edge_m = mat("DecalEdge", "#1c1830", rough=0.5)
    ink_m = mat("DecalInk", "#1c1830", rough=0.4)
    parts = []
    extent = []
    for i, outline in enumerate(fills):
        grown = offset_outline(outline, edge)
        extent += grown
        parts.append(prism(f"{name}Edge{i}", grown, 0.06, (0, 0.02, 0), m=edge_m, bevel=0.02))
        parts.append(prism(f"{name}Fill{i}", outline, 0.06, (0, -0.012, 0), m=fill_m, bevel=0.018))
    for i, d in enumerate(details):
        kind = d[0]
        if kind == "poly":
            parts.append(prism(f"{name}Ink{i}", d[1], 0.03, (0, -0.045, 0), m=ink_m, bevel=0.008))
            extent += d[1]
        elif kind == "dot":
            (cx, cz), r = d[1], d[2]
            parts.append(cyl(f"{name}Ink{i}", r, 0.03, (cx, -0.045, cz), rot=rad(90, 0, 0), segs=16, bevel=0.008, m=ink_m))
            extent += [(cx - r, cz - r), (cx + r, cz + r)]
        elif kind == "arc":
            # (centre, radius, thickness, start_deg, arc_deg)
            (cx, cz), r, t, a0, arc = d[1], d[2], d[3], d[4], d[5]
            parts.append(torus(f"{name}Ink{i}", r, t, (cx, -0.045, cz), rot=rad(90, 0, 0), m=ink_m, major_segs=18, minor_segs=5,
                               arc=math.radians(arc), start=math.radians(a0)))
    # Normalise: 1 unit across the larger of width/height, centred.
    xs = [p[0] for p in extent]
    zs = [p[1] for p in extent]
    span = max(max(xs) - min(xs), max(zs) - min(zs))
    cx, cz = (max(xs) + min(xs)) / 2, (max(zs) + min(zs)) / 2
    for ob in parts:
        ob.matrix_world = (Matrix.Rotation(math.radians(-90), 4, "Z") @ Matrix.Scale(1.0 / span, 4)
                           @ Matrix.Translation((-cx, 0, -cz)) @ ob.matrix_basis)
    return parts


def circle(r, steps=24, cx=0.0, cz=0.0, a0=0.0, a1=360.0):
    return [(cx + math.cos(math.radians(a0 + (a1 - a0) * i / steps)) * r, cz + math.sin(math.radians(a0 + (a1 - a0) * i / steps)) * r)
            for i in range(steps + (0 if a1 - a0 >= 360 else 1))]


def emblem_shapes():
    s = {}
    s["Heart"] = ([heart_outline(1.0)], [])
    s["Bolt"] = ([[(-0.15, 1.0), (0.55, 1.0), (0.18, 0.18), (0.62, 0.18), (-0.35, -1.0), (-0.05, -0.1), (-0.52, -0.1)]], [])
    flame = [(0.0, -0.95), (0.55, -0.7), (0.72, -0.15), (0.55, 0.35), (0.42, 0.05), (0.3, 0.55), (0.12, 1.0),
             (-0.12, 0.45), (-0.3, 0.7), (-0.42, 0.2), (-0.6, 0.38), (-0.72, -0.2), (-0.55, -0.7)]
    s["Flame"] = ([flame], [("poly", [(0.0, -0.75), (0.3, -0.55), (0.35, -0.15), (0.15, 0.2), (0.0, 0.0), (-0.18, 0.25), (-0.35, -0.2), (-0.3, -0.55)])])
    s["Smiley"] = ([circle(1.0, 28)], [("dot", (-0.33, 0.28), 0.14), ("dot", (0.33, 0.28), 0.14), ("arc", (0, 0.05), 0.55, 0.1, 200, 140)])
    crown = [(-0.95, -0.6), (0.95, -0.6), (0.95, 0.15), (1.05, 0.7), (0.5, 0.2), (0.0, 0.85), (-0.5, 0.2), (-1.05, 0.7), (-0.95, 0.15)]
    s["Crown"] = ([crown], [("poly", [(-0.8, -0.45), (0.8, -0.45), (0.8, -0.28), (-0.8, -0.28)]), ("dot", (0, -0.05), 0.12)])
    toes = [circle(0.21, 14, x, z) for x, z in ((-0.68, 0.3), (-0.25, 0.66), (0.25, 0.66), (0.68, 0.3))]
    s["Paw"] = ([circle(0.55, 20, 0.0, -0.35)] + toes, [])
    shell = [(0.0, -0.95), (0.38, -0.82), (0.32, -0.62)]
    for i in range(41):
        ang = math.radians(-12 + 204 * i / 40)
        r = 1.0 - 0.07 * abs(math.sin((ang - math.pi / 2) * 4.5))
        shell.append((math.cos(ang) * r, -0.55 + math.sin(ang) * r * 1.05))
    shell += [(-0.32, -0.62), (-0.38, -0.82)]
    ridges = []
    for k in range(5):
        ang = math.radians(28 + 31 * k)
        d = Vector((math.cos(ang), math.sin(ang)))
        n = Vector((-d.y, d.x)) * 0.045
        a0, a1 = Vector((0, -0.62)) + d * 0.18, Vector((0, -0.6)) + d * 0.82
        ridges.append(("poly", [tuple(a0 - n), tuple(a1 - n * 1.4), tuple(a1 + n * 1.4), tuple(a0 + n)]))
    s["Shell"] = ([shell], ridges)
    s["Planet"] = ([circle(0.62, 24)], [("poly", [(-1.15, -0.2), (1.1, 0.32), (1.12, 0.45), (-1.13, -0.07)])])
    flake = []
    for k in range(3):
        ang = math.radians(90 + 60 * k)
        d = Vector((math.cos(ang), math.sin(ang)))
        n = Vector((-d.y, d.x)) * 0.13
        flake.append([tuple(d + n), tuple(-d + n), tuple(-d - n), tuple(d - n)])
    for k in range(6):
        ang = math.radians(90 + 60 * k)
        d = Vector((math.cos(ang), math.sin(ang)))
        for side in (-1, 1):
            b_dir = Vector((math.cos(ang + side * 0.8), math.sin(ang + side * 0.8)))
            n = Vector((-b_dir.y, b_dir.x)) * 0.09
            root = d * 0.55
            flake.append([tuple(root + n), tuple(root + b_dir * 0.38 + n), tuple(root + b_dir * 0.38 - n), tuple(root - n)])
    s["Snowflake"] = (flake, [("dot", (0, 0), 0.16)])
    s["Diamond"] = ([[(0.0, -1.0), (0.85, 0.2), (0.55, 0.62), (-0.55, 0.62), (-0.85, 0.2)]],
                    [("poly", [(-0.3, 0.45), (0.3, 0.45), (0.5, 0.22), (-0.5, 0.22)])])
    s["Star"] = ([star_outline(1.0, 0.48, 5, 90)], [])
    s["Skull"] = ([[(-0.55, -0.95), (0.55, -0.95), (0.6, -0.45), (0.95, -0.1), (0.95, 0.35), (0.7, 0.8), (0.0, 1.0), (-0.7, 0.8), (-0.95, 0.35), (-0.95, -0.1), (-0.6, -0.45)]],
                  [("dot", (-0.38, 0.1), 0.24), ("dot", (0.38, 0.1), 0.24), ("poly", [(0.0, -0.18), (0.1, -0.36), (-0.1, -0.36)]),
                   ("poly", [(-0.32, -0.62), (-0.22, -0.62), (-0.22, -0.88), (-0.32, -0.88)]), ("poly", [(0.05, -0.62), (-0.05, -0.62), (-0.05, -0.88), (0.05, -0.88)]),
                   ("poly", [(0.22, -0.62), (0.32, -0.62), (0.32, -0.88), (0.22, -0.88)])])
    return s


def build_decals():
    reset_scene()
    exports = []
    for name, (fills, details) in emblem_shapes().items():
        parts = sticker(name, fills, details)
        exports.append(merge("Emblem_" + name, parts, pivot=(0, 0, 0)))
    save("cosmetic_decals", exports)


if __name__ == "__main__":
    build_charms()
    build_decals()
