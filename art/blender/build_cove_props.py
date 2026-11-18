"""Pirate Cove props and scenery (World 13, Skull Harbor). Every prop stands on
z 0 with its front toward -Y (+Z in Godot).

    cove_cannon       a cannon on a red wooden carriage (1.0 x 2.2 m)
    cove_crates       a stack of three cargo crates (2.2 x 1.6 m)
    cove_barrels      a cluster of barrels and a keg (1.9 x 1.6 m)
    cove_treasure     an open treasure chest spilling a heap of gold coins
    cove_bollard      an iron mooring bollard with a rope loop
    cove_lamp         a timber lamp post with a hanging ship's lantern (3.6 m)
    cove_rail         a 2.5 m rope railing module (posts at both ends)
    cove_bridge       a 1 m rope-bridge module: planks and rope hand lines
    cove_rowboat      a rowboat with oars (4.2 m)
    cove_sloop        a small single-masted sloop for the harbour (11 m)
    cove_palm         a leaning palm (8 m)
    cove_stall        a market stall with a striped awning ("PARROTS & PIECES")
    cove_flagpole     a tall pole with a skull flag and pennants
    cove_exit_lantern the exit trail lantern (glass "CoveExitGlow")
    cove_cliff        a unit cliff chunk (1 x 1 x 1, scaled in the level)
    cove_cliff_b      a second cliff chunk
    cove_stack        a tall sea stack with a grassy top (unit height)
    cove_fern         a low bush of ferns for the cliff tops

    python art/blender/build_cove_props.py [names...]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cove_common import *  # noqa: F401,F403
from cove_common import _finish, bmesh, Vector  # noqa: F401


def cannon():
    red, dark, iron = cmat("Red", rough=0.55), cmat("WoodDark"), cmat("Iron", rough=0.4, metal=0.5)
    p = [box("CarriageL", (0.16, 1.7, 0.6), (-0.38, 0.1, 0.55), bevel=0.04, m=red),
         box("CarriageR", (0.16, 1.7, 0.6), (0.38, 0.1, 0.55), bevel=0.04, m=red),
         box("Bed", (0.7, 1.6, 0.14), (0, 0.1, 0.32), bevel=0.03, m=dark),
         cyl("Barrel", 0.3, 2.0, (0, -0.35, 0.95), rot=rad(98, 0, 0), segs=14, bevel=0.04, m=iron, radius_top=0.22),
         torus("Lip", 0.24, 0.07, (0, -1.32, 1.08), rot=rad(98, 0, 0), m=iron, major_segs=14, minor_segs=5),
         sphere("Cascabel", 0.14, (0, 0.72, 0.8), m=iron, segs=8, rings=5),
         torus("Band", 0.31, 0.04, (0, 0.2, 0.86), rot=rad(98, 0, 0), m=cmat("Brass", rough=0.35, metal=0.5), major_segs=14, minor_segs=4)]
    for s in (-1, 1):
        for e in (-1, 1):
            p += [cyl(f"Wheel{s}{e}", 0.28, 0.12, (s * 0.52, e * 0.6 + 0.1, 0.28), rot=rad(0, 90, 0), segs=12, bevel=0.03, m=dark),
                  cyl(f"WheelHub{s}{e}", 0.08, 0.16, (s * 0.55, e * 0.6 + 0.1, 0.28), rot=rad(0, 90, 0), segs=8, bevel=0.0, m=iron)]
    # A little pyramid of cannonballs beside it.
    for k, (x, y, z) in enumerate(((0.95, 0.5, 0.15), (1.25, 0.5, 0.15), (1.1, 0.75, 0.15), (1.1, 0.58, 0.38))):
        p.append(sphere(f"Ball{k}", 0.15, (x, y, z), m=iron, segs=10, rings=6))
    return [merge("Cannon", p)]


def crates():
    light, dark, iron = cmat("WoodLight", rough=0.8), cmat("WoodDark"), cmat("Iron")
    p = []
    for k, (x, y, z, s, yaw) in enumerate(((-0.5, 0.0, 0.5, 1.0, 0.1), (0.6, 0.15, 0.45, 0.9, -0.2), (-0.35, 0.05, 1.42, 0.85, 0.35))):
        c = [box(f"Crate{k}", (s, s, s), (0, 0, 0), bevel=0.05, m=light)]
        for e in (-1, 1):
            c.append(box(f"Slat{k}{e}", (s + 0.03, s * 0.16, s + 0.03), (0, e * s * 0.32, 0), bevel=0.02, m=dark))
        c.append(box(f"Strap{k}", (s * 0.14, s + 0.05, s + 0.05), (0, 0, 0), bevel=0.01, m=iron))
        c.append(skull_mark(f"Mark{k}", s))
        place(c, (x, y, z), yaw)
        p += c
    return [merge("Crates", p)]


def skull_mark(name, s):
    """A painted skull stencil on a crate's front face."""
    return sphere(name, s * 0.14, (0, -s * 0.5 - 0.01, s * 0.05), scale=(1, 0.15, 1), m=cmat("Bone", rough=0.7), segs=8, rings=5)


def barrels():
    p = []
    for k, (x, y, r, h) in enumerate(((-0.45, 0.2, 0.42, 1.05), (0.45, 0.25, 0.42, 1.05), (0.0, -0.45, 0.4, 1.0))):
        p += barrel(f"Barrel{k}", r, h, (x, y, 0))
    p += barrel("Keg", 0.28, 0.6, (0.05, 0.15, 1.05), m_wood=cmat("RedDark", rough=0.6))
    p += [box("Plank", (0.2, 1.4, 0.06), (0.75, -0.3, 0.55), rot=(0.4, 0, 0.3), bevel=0.02, m=cmat("Plank"))]
    return [merge("Barrels", p)]


def treasure():
    gold = mat("CoveCoin", "#ffc24a", rough=0.25, metal=0.6, emit=0.35)
    red, brass, wood = cmat("Red", rough=0.5), cmat("Brass", rough=0.3, metal=0.5), cmat("WoodDark")
    p = [box("Chest", (1.4, 0.9, 0.7), (0, 0, 0.4), bevel=0.06, m=red),
         box("ChestBase", (1.5, 1.0, 0.12), (0, 0, 0.06), bevel=0.03, m=wood),
         box("BandL", (0.12, 0.95, 0.75), (-0.45, 0, 0.4), bevel=0.02, m=brass),
         box("BandR", (0.12, 0.95, 0.75), (0.45, 0, 0.4), bevel=0.02, m=brass),
         box("Lock", (0.2, 0.08, 0.24), (0, -0.48, 0.6), bevel=0.03, m=brass)]
    p.append(box("LidOpen", (1.4, 0.7, 0.14), (0, 0.62, 1.05), rot=(-1.15, 0, 0), bevel=0.05, m=red))
    p.append(box("LidBand", (1.42, 0.12, 0.16), (0, 0.78, 1.38), rot=(-1.15, 0, 0), bevel=0.02, m=brass))
    # The heap: a domed mound of coins in the chest and spilling down the front.
    p.append(sphere("Hoard", 0.62, (0, 0, 0.72), scale=(1.05, 0.68, 0.45), m=gold, segs=14, rings=7))
    p.append(sphere("Spill", 0.8, (0.1, -0.85, 0.0), scale=(1.2, 0.9, 0.32), m=gold, segs=14, rings=7))
    rng = random.Random(5)
    for k in range(14):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.6, 1.4)
        p.append(cyl(f"Coin{k}", 0.08, 0.025, (math.cos(a) * r + 0.1, -0.7 + math.sin(a) * r * 0.6, 0.02), rot=(rng.uniform(-0.3, 0.3), 0, 0), segs=8,
                     bevel=0.0, m=gold))
    for k, (x, y, z, c) in enumerate(((-0.25, -0.1, 1.0, "#e8384f"), (0.3, 0.05, 0.98, "#3fc9e8"), (0.05, -0.55, 0.32, "#5fd36a"))):
        p.append(sphere(f"Gem{k}", 0.1, (x, y, z), m=mat(f"CoveGem{k}", c, rough=0.15, emit=1.2), segs=6, rings=4))
    p.append(cyl("Goblet", 0.1, 0.28, (-0.45, -0.95, 0.24), segs=10, bevel=0.0, m=gold, radius_top=0.14))
    return [merge("Treasure", p)]


def bollard():
    iron = cmat("Iron", rough=0.45, metal=0.4)
    p = [cyl("Post", 0.24, 0.7, (0, 0, 0.35), segs=12, bevel=0.04, m=iron),
         cyl("Head", 0.33, 0.18, (0, 0, 0.75), segs=12, bevel=0.05, m=iron),
         torus("Loop", 0.3, 0.06, (0, 0, 0.45), m=cmat("Rope", rough=0.9), major_segs=14, minor_segs=5)]
    return [merge("Bollard", p)]


def lamp():
    dark = cmat("WoodDark")
    p = [box("Post", (0.24, 0.24, 3.4), (0, 0, 1.7), bevel=0.04, m=dark),
         box("Foot", (0.5, 0.5, 0.3), (0, 0, 0.15), bevel=0.05, m=cmat("StoneDark")),
         box("Arm", (0.12, 1.0, 0.12), (0, -0.4, 3.2), bevel=0.02, m=dark),
         box("Brace", (0.08, 0.6, 0.08), (0, -0.2, 2.95), rot=(0.75, 0, 0), bevel=0.0, m=dark),
         rope("Hang", [(0, -0.8, 3.15), (0, -0.8, 2.85)], 0.02)]
    p += lantern("Lantern", (0, -0.8, 2.3), scale=1.5)
    return [merge("Lamp", p)]


def rail():
    dark = cmat("WoodDark")
    p = [box("PostA", (0.18, 0.18, 1.15), (-1.25, 0, 0.575), bevel=0.03, m=dark),
         sphere("KnobA", 0.11, (-1.25, 0, 1.18), m=cmat("Brass", rough=0.35, metal=0.4), segs=8, rings=5)]
    p.append(rope("RopeTop", sag_points((-1.25, 0, 1.0), (1.25, 0, 1.0), 0.12), 0.045, segs=6))
    p.append(rope("RopeLow", sag_points((-1.25, 0, 0.55), (1.25, 0, 0.55), 0.08), 0.04, segs=6))
    return [merge("Rail", p)]


def bridge():
    p = [box("Plank", (0.92, 2.0, 0.08), (0, 0, -0.04), bevel=0.02, m=cmat("Plank"))]
    for s in (-1, 1):
        p.append(rope(f"Hand{s}", [(-0.5, s * 1.05, 1.0), (0.5, s * 1.05, 1.0)], 0.045, segs=6))
        p.append(rope(f"Low{s}", [(-0.5, s * 1.0, 0.03), (0.5, s * 1.0, 0.03)], 0.04, segs=6))
        p.append(rope(f"Drop{s}", [(0.0, s * 1.05, 1.0), (0.0, s * 1.0, 0.03)], 0.02, segs=3))
    return [merge("Bridge", p)]


def rowboat():
    wood, dark = cmat("Teal", rough=0.6), cmat("WoodDark")
    bm = bmesh.new()
    rows = []
    rims = []
    for i in range(11):
        t = i / 10
        y = -2.1 + 4.2 * t
        w = 0.75 * math.sin(math.pi * (0.04 + 0.92 * t)) ** 0.55
        rise = 0.25 * ((2 * t - 1) ** 2)
        rows.append([bm.verts.new((-w, y, 0.7 + rise)), bm.verts.new((-w * 0.55, y, 0.08 + rise * 0.4)), bm.verts.new((w * 0.55, y, 0.08 + rise * 0.4)),
                     bm.verts.new((w, y, 0.7 + rise))])
        rims.append((w, y, 0.72 + rise))
    for i in range(10):
        for k in range(3):
            f = bm.faces.new((rows[i][k], rows[i + 1][k], rows[i + 1][k + 1], rows[i][k + 1]))
            f.material_index = 0 if k != 1 else 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    hull = finish_multi("Hull", bm, [wood, dark], smooth=False)
    double_sided(hull)
    p = [hull, box("Seat0", (1.2, 0.3, 0.08), (0, -0.6, 0.5), bevel=0.02, m=cmat("Plank")),
         box("Seat1", (1.3, 0.3, 0.08), (0, 0.6, 0.5), bevel=0.02, m=cmat("Plank"))]
    for s in (-1, 1):
        p.append(tube(f"Oar{s}", [(s * 0.6, 0.2, 0.75), (s * 2.2, 0.6, 0.15)], 0.04, m=cmat("WoodLight"), segs=5))
        p.append(box(f"Blade{s}", (0.6, 0.18, 0.04), (s * 2.3, 0.62, 0.12), rot=(0, s * -0.3, 0.25 * s), bevel=0.01, m=cmat("Red")))
    for s in (-1, 1):
        p.append(tube(f"Gunwale{s}", [(s * w, y, z) for w, y, z in rims], 0.05, m=cmat("Cream"), segs=5))
    return [merge("Rowboat", p)]


def sloop():
    bm = bmesh.new()
    rows = []
    for i in range(15):
        t = i / 14
        y = -5.5 + 11.0 * t
        w = 1.9 * math.sin(math.pi * (0.03 + 0.85 * t)) ** 0.6 if t < 0.95 else 1.4
        rise = 0.9 * (1 - t) ** 2
        rows.append([bm.verts.new((-w, y, 1.6 + rise)), bm.verts.new((-w * 0.6, y, -0.6 + rise * 0.3)), bm.verts.new((w * 0.6, y, -0.6 + rise * 0.3)),
                     bm.verts.new((w, y, 1.6 + rise))])
    for i in range(14):
        for k in range(3):
            f = bm.faces.new((rows[i][k], rows[i + 1][k], rows[i + 1][k + 1], rows[i][k + 1]))
            f.material_index = 0 if k != 1 else 1
    f = bm.faces.new([rows[14][k] for k in range(4)])
    f.material_index = 0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    hull = finish_multi("Hull", bm, [cmat("Navy", rough=0.6), cmat("RedDark")], smooth=False)
    double_sided(hull)
    p = [hull, box("Deck", (2.6, 9.0, 0.1), (0, 0.6, 1.4), bevel=0.0, m=cmat("Plank")),
         cyl("Mast", 0.16, 12.0, (0, -0.8, 7.4), segs=8, bevel=0.0, m=cmat("WoodLight"), radius_top=0.08),
         cyl("Boom", 0.1, 6.0, (0, 2.2, 2.6), rot=rad(90, 0, 0), segs=6, bevel=0.0, m=cmat("WoodDark")),
         box("Cabin", (1.8, 2.4, 0.9), (0, 2.6, 1.85), bevel=0.06, m=cmat("Cream"))]
    bm = bmesh.new()
    a = bm.verts.new((0, -0.7, 2.7))
    b = bm.verts.new((0, -0.7, 12.8))
    c = bm.verts.new((0, 5.0, 2.7))
    fa = bm.faces.new((a, b, c))
    fa.material_index = 0
    d = bm.verts.new((0, -5.6, 2.2))
    e = bm.verts.new((0, -0.9, 11.6))
    g = bm.verts.new((0, -1.0, 2.6))
    fb = bm.faces.new((d, e, g))
    fb.material_index = 1
    sails = finish_multi("Sails", bm, [cmat("Sail", rough=0.8), cmat("Red", rough=0.7)], smooth=False)
    double_sided(sails)
    p.append(sails)
    p += skull_flag("Flag", (0.0, -0.8, 13.6), width=0.9, height=0.55, yaw=math.pi / 2)
    p += lantern("Lamp", (0, 5.2, 2.2), scale=1.4)
    return [merge("Sloop", p)]


def palm():
    trunk_m, leaf, leaf_dark = cmat("WoodLight", rough=0.8), cmat("Leaf", rough=0.7), cmat("GrassDark", rough=0.7)
    pts = []
    for i in range(9):
        t = i / 8
        pts.append((1.6 * t ** 1.6, 0.0, 7.6 * t))
    p = [tube("Trunk", pts, 0.26, m=trunk_m, segs=8, radius_end=0.16)]
    for i in range(1, 8):
        t = i / 8
        p.append(torus(f"Ring{i}", 0.26 - 0.1 * t, 0.04, (1.6 * t ** 1.6, 0, 7.6 * t), m=cmat("WoodDark"), major_segs=8, minor_segs=4))
    top = Vector((1.6, 0.0, 7.6))
    for k in range(8):
        a = math.tau * k / 8 + 0.2
        d = Vector((math.cos(a), math.sin(a), 0))
        tip = top + d * 3.6 + Vector((0, 0, -1.6 - 0.4 * (k % 2)))
        mid = top + d * 1.9 + Vector((0, 0, 0.5))
        bm = bmesh.new()
        side = Vector((-d.y, d.x, 0)) * 0.55
        vs = [bm.verts.new(top), bm.verts.new(mid + side), bm.verts.new(tip), bm.verts.new(mid - side)]
        bm.faces.new(vs)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ob = _finish(f"Frond{k}", bm, leaf if k % 2 == 0 else leaf_dark, (0, 0, 0), (0, 0, 0), smooth=False)
        double_sided(ob)
        p.append(ob)
    for k in range(3):
        a = math.tau * k / 3
        p.append(sphere(f"Coconut{k}", 0.2, (1.6 + math.cos(a) * 0.25, math.sin(a) * 0.25, 7.3), m=cmat("WoodDark"), segs=8, rings=5))
    return [merge("Palm", p)]


def stall():
    wood, red, cream = cmat("Wood"), cmat("Red", rough=0.6), cmat("Cream", rough=0.7)
    p = [box("Counter", (2.6, 1.0, 1.0), (0, 0, 0.5), bevel=0.05, m=wood),
         box("CounterTop", (2.8, 1.15, 0.1), (0, 0, 1.05), bevel=0.03, m=cmat("WoodLight"))]
    for x in (-1.3, 1.3):
        for y in (-0.5, 0.5):
            p.append(box(f"Post{x}{y}", (0.12, 0.12, 2.5), (x, y, 1.25), bevel=0.02, m=cmat("WoodDark")))
    for k in range(7):
        x = -1.5 + 3.0 * (k + 0.5) / 7
        p.append(box(f"Awning{k}", (3.0 / 7 + 0.005, 1.6, 0.08), (x, -0.15, 2.6), rot=(-0.25, 0, 0), bevel=0.0, m=red if k % 2 == 0 else cream))
    for k in range(7):
        x = -1.5 + 3.0 * (k + 0.5) / 7
        p.append(prism(f"Scallop{k}", [(-0.2, 0), (0.2, 0), (0, -0.25)], 0.03, (x, -0.95, 2.42), m=red if k % 2 == 0 else cream))
    p += [box("Sign", (2.4, 0.08, 0.45), (0, -0.62, 1.45), bevel=0.03, m=cmat("Navy")),
          text("SignText", "PARROTS & PIECES", 0.2, 0.03, (0, -0.68, 1.44), m=cmat("Gold", rough=0.35))]
    # Wares: a parrot on a perch, maps, a spyglass, coins.
    p += [cyl("Perch", 0.03, 0.9, (0.9, 0.0, 1.5), segs=6, bevel=0.0, m=cmat("WoodDark")),
          box("PerchBar", (0.5, 0.05, 0.05), (0.9, 0.0, 1.95), bevel=0.0, m=cmat("WoodDark")),
          sphere("Parrot", 0.16, (0.9, 0.0, 2.15), scale=(0.8, 0.9, 1.2), m=cmat("Red", rough=0.5), segs=8, rings=6),
          sphere("ParrotHead", 0.1, (0.9, -0.05, 2.38), m=cmat("Red", rough=0.5), segs=8, rings=5),
          prism("ParrotBeak", [(-0.04, 0), (0.04, 0), (0, -0.08)], 0.05, (0.9, -0.14, 2.36), m=cmat("Gold")),
          prism("ParrotWing", [(-0.08, 0.15), (0.08, 0.15), (0, -0.2)], 0.04, (0.9, 0.12, 2.1), m=cmat("Teal")),
          box("Map", (0.6, 0.45, 0.02), (-0.6, 0.0, 1.12), rot=(0, 0, 0.2), bevel=0.0, m=cmat("Sand")),
          cyl("Spyglass", 0.05, 0.6, (0.0, 0.1, 1.16), rot=rad(0, 90, 20), segs=8, bevel=0.0, m=cmat("Brass", rough=0.3, metal=0.5))]
    return [merge("Stall", p)]


def flagpole():
    p = [cyl("Pole", 0.1, 9.0, (0, 0, 4.5), segs=8, bevel=0.0, m=cmat("WoodDark"), radius_top=0.06),
         cyl("Foot", 0.4, 0.5, (0, 0, 0.25), segs=10, bevel=0.05, m=cmat("StoneDark")),
         sphere("Top", 0.14, (0, 0, 9.05), m=cmat("Gold", rough=0.35), segs=8, rings=5)]
    p += skull_flag("Flag", (1.1, 0, 8.2), width=2.0, height=1.3, yaw=math.pi / 2)
    return [merge("Flagpole", p)]


def exit_lantern():
    glass = cglow("CoveExitGlow", "#ffcf7a", 2.5)
    p = [box("Post", (0.14, 0.14, 1.4), (0, 0, 0.7), bevel=0.02, m=cmat("WoodDark")),
         box("Arm", (0.08, 0.4, 0.08), (0, -0.15, 1.45), bevel=0.0, m=cmat("WoodDark"))]
    p += lantern("Lantern", (0, -0.3, 0.95), m_glass=glass, scale=1.3)
    return [merge("ExitLantern", p)]


def cliff(seed, name):
    ob = rock_lump(name, (1.0, 1.0, 1.0), seed=seed, segs=12, rings=7)
    return [merge(name, [ob])]


def stack():
    ob = rock_lump("Stack", (1.0, 1.0, 1.0), seed=31, segs=10, rings=9)
    return [merge("Stack", [ob])]


def fern():
    rng = random.Random(7)
    p = []
    for k in range(9):
        a = math.tau * k / 9 + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        tip = d * rng.uniform(0.9, 1.3) + Vector((0, 0, rng.uniform(0.5, 0.9)))
        side = Vector((-d.y, d.x, 0)) * 0.22
        bm = bmesh.new()
        vs = [bm.verts.new((0, 0, 0.05)), bm.verts.new(d * 0.5 + side + Vector((0, 0, 0.45))), bm.verts.new(tip), bm.verts.new(d * 0.5 - side + Vector((0, 0, 0.45)))]
        bm.faces.new(vs)
        ob = _finish(f"Leaf{k}", bm, cmat("Leaf", rough=0.7) if k % 2 else cmat("GrassDark", rough=0.7), (0, 0, 0), (0, 0, 0), smooth=False)
        double_sided(ob)
        p.append(ob)
    return [merge("Fern", p)]


ALL = {
    "cove_cannon": cannon, "cove_crates": crates, "cove_barrels": barrels, "cove_treasure": treasure, "cove_bollard": bollard,
    "cove_lamp": lamp, "cove_rail": rail, "cove_bridge": bridge, "cove_rowboat": rowboat, "cove_sloop": sloop, "cove_palm": palm,
    "cove_stall": stall, "cove_flagpole": flagpole, "cove_exit_lantern": exit_lantern,
    "cove_cliff": lambda: cliff(11, "Cliff"), "cove_cliff_b": lambda: cliff(17, "CliffB"), "cove_stack": stack, "cove_fern": fern,
}

if __name__ == "__main__":
    for key in (sys.argv[1:] or list(ALL)):
        reset_scene()
        save(key, ALL[key]())
