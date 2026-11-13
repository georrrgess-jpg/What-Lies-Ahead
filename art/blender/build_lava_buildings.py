"""Volcano Isle buildings and scenery (World 9, Lava Lagoon): the observatory,
the funicular station, the lava-tube cave, the staff hut, the jungle-trail gate,
the giant Kahuna head, basalt cliffs, offshore islets and Mount Kahuna itself.

    python art/blender/build_lava_buildings.py                    (all)
    python art/blender/build_lava_buildings.py volcano observatory (only these)

Surfaces named LavaMolten are swapped by the level for the animated lava shader.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lava_common import *  # noqa: F401,F403
import build_lava_props as blp  # noqa: E402
from wla_common import _finish  # noqa: E402

OBS_R = 4.5        # observatory drum radius
OBS_H = 4.6        # drum height
DOOR_W = 2.8       # entrance gaps the zombies walk out of (observatory, funicular, hut)


def ring_wall(prefix, radius, height, thick, gap_deg, m, segs=20, z0=0.0):
    """A round wall of box segments, open over `gap_deg` facing -Y."""
    parts = []
    step = 360.0 / segs
    for i in range(segs):
        a = -90.0 + step * (i + 0.5)
        off = (a + 90.0 + 180.0) % 360.0 - 180.0
        if abs(off) < gap_deg / 2:
            continue
        r = math.radians(a)
        chord = 2 * radius * math.sin(math.radians(step / 2)) + 0.05
        parts.append(box(f"{prefix}{i}", (chord, thick, height), (math.cos(r) * radius, math.sin(r) * radius, z0 + height / 2),
                         rot=(0, 0, r + math.pi / 2), bevel=0.04, m=m))
    return parts


def build_observatory():
    """The Kahuna Observatory: a basalt drum (r 4.5 m) with a door facing -Y,
    a copper-teal dome with its slit open toward the volcano (+Y) and the
    telescope poking out. Dark inside, lit red by the console."""
    reset_scene()
    stone, dark, light = lmat("BasaltLight", rough=0.8), lmat("BasaltDark", rough=0.9), lmat("Cream", rough=0.6)
    dome_m = mat("LavaDome", "#3fa89a", rough=0.35, metal=0.4)
    rib_m = lmat("Brass", rough=0.35, metal=0.6)
    gap = math.degrees(2 * math.asin((DOOR_W / 2 + 0.2) / OBS_R))
    p = ring_wall("Drum", OBS_R, OBS_H, 0.5, gap, stone, segs=24)
    p += ring_wall("Band", OBS_R + 0.08, 0.35, 0.56, gap, dark, segs=24, z0=OBS_H - 0.6)
    p += ring_wall("Plinth", OBS_R + 0.15, 0.5, 0.6, gap, dark, segs=24)
    # Interior: dark floor and a back wall, a red-lit console.
    p += [cyl("Floor", OBS_R - 0.2, 0.1, (0, 0, 0.05), segs=24, bevel=0.0, m=dark),
          cyl("Ceiling", OBS_R, 0.2, (0, 0, OBS_H - 0.1), segs=24, bevel=0.0, m=dark),
          box("Console", (1.6, 0.8, 1.0), (0, 2.6, 0.5), bevel=0.05, m=lmat("SteelDark")),
          box("Screen", (1.2, 0.08, 0.6), (0, 2.2, 1.25), rot=(math.radians(-20), 0, 0), bevel=0.02, m=lglow("LavaScreen", "#ff5a3a", 1.6)),
          cyl("Pier", 0.6, 2.8, (0, 0.8, 1.4), segs=12, bevel=0.04, m=lmat("Steel", metal=0.5))]
    # Door frame with carved posts and a lintel sign.
    hw = DOOR_W / 2
    front = -OBS_R + 0.1
    p += [box("JambL", (0.5, 0.9, 3.4), (-hw - 0.25, front, 1.7), bevel=0.06, m=lmat("TikiDark")),
          box("JambR", (0.5, 0.9, 3.4), (hw + 0.25, front, 1.7), bevel=0.06, m=lmat("TikiDark")),
          box("Lintel", (DOOR_W + 1.4, 1.0, 0.7), (0, front, 3.6), bevel=0.06, m=lmat("TikiDark")),
          box("SignBack", (DOOR_W + 1.0, 0.1, 0.46), (0, front - 0.52, 3.6), bevel=0.03, m=lmat("Teal")),
          text("Sign", "OBSERVATORY", 0.3, 0.04, (0, front - 0.6, 3.58), m=light)]
    p += tiki_face("JF0", 0.42, 0.9, (-hw - 0.25, front - 0.45, 2.2), style=1)
    p += tiki_face("JF1", 0.42, 0.9, (hw + 0.25, front - 0.45, 2.2), style=1)
    # Dome: a hemisphere with ribs, the slit along +Y, telescope out of it.
    dome = sphere("Dome", OBS_R + 0.15, (0, 0, OBS_H), m=dome_m, segs=28, rings=14)
    bm = bmesh.new()
    bm.from_mesh(dome.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.01], context="VERTS")
    bm.to_mesh(dome.data)
    bm.free()
    p.append(dome)
    for k in range(8):
        a = math.tau * k / 8 + math.pi / 8
        pts = [(math.cos(a) * math.cos(t) * (OBS_R + 0.22), math.sin(a) * math.cos(t) * (OBS_R + 0.22), OBS_H + math.sin(t) * (OBS_R + 0.22))
               for t in [i * math.pi / 2 / 8 for i in range(9)]]
        p.append(tube(f"Rib{k}", pts, 0.07, m=rib_m, segs=6))
    p.append(box("Slit", (1.0, OBS_R * 1.2, 0.3), (0, OBS_R * 0.45, OBS_H + OBS_R * 0.78), rot=(math.radians(-42), 0, 0), bevel=0.02, m=dark))
    p += [cyl("Scope", 0.42, 4.6, (0, 2.4, OBS_H + 3.0), rot=(math.radians(-50), 0, 0), segs=14, bevel=0.04, m=light),
          cyl("ScopeBand", 0.46, 0.4, (0, 3.6, OBS_H + 4.0), rot=(math.radians(-50), 0, 0), segs=14, bevel=0.03, m=rib_m),
          cyl("ScopeLens", 0.36, 0.06, (0, 4.15, OBS_H + 4.48), rot=(math.radians(-50), 0, 0), segs=14, bevel=0.0, m=lglow("LavaLens", "#7fe6ff", 1.5))]
    p += [bulb(f"DoorLamp{s}", 0.14, (s * (hw + 0.25), front - 0.5, 3.15), lglow("LavaLantern", "#ffb04a", 3.0)) for s in (-1, 1)]
    save("lava_observatory", [merge("Observatory", p)])


def build_funicular():
    """Funicular station: a 7 x 8 m platform shed open to -Y, a red car waiting
    at the platform, the track climbing away along +Y up the volcano's flank."""
    reset_scene()
    wood, dark, steel = lmat("Tiki"), lmat("TikiDark"), lmat("SteelDark", metal=0.4)
    p = []
    hw, depth, h = 3.5, 8.0, 4.4
    p += [box("WallL", (0.4, depth, h), (-hw, depth / 2 - 0.5, h / 2), bevel=0.05, m=lmat("BasaltLight", rough=0.8)),
          box("WallR", (0.4, depth, h), (hw, depth / 2 - 0.5, h / 2), bevel=0.05, m=lmat("BasaltLight", rough=0.8)),
          box("Back", (2 * hw, 0.4, 1.2), (0, depth - 0.5, 3.8), bevel=0.05, m=lmat("BasaltLight", rough=0.8)),
          box("Floor", (2 * hw, depth, 0.1), (0, depth / 2 - 0.5, 0.05), bevel=0.0, m=lmat("BasaltDark")),
          box("Header", (2 * hw + 0.6, 0.6, 0.8), (0, -0.5, h - 0.2), bevel=0.05, m=dark)]
    p += thatch_hip("Roof", 2 * hw, depth, 2.0, h + 0.1, seed=8, loc=(0, depth / 2 - 0.5, 0))
    p += [box("SignBack", (4.6, 0.12, 0.6), (0, -0.85, h - 0.2), bevel=0.04, m=lmat("Ember")),
          text("Sign", "SUMMIT TRAM", 0.38, 0.05, (0, -0.93, h - 0.22), m=lmat("Cream"))]
    # Track: two rails on sleepers, climbing at ~22 degrees from the back of the shed.
    ang = math.radians(22)
    for s in (-0.75, 0.75):
        p.append(tube(f"Rail{s}", [(s, -0.2, 0.25), (s, depth - 0.8, 0.25), (s, depth + 40 * math.cos(ang), 0.25 + 40 * math.sin(ang))], 0.08, m=steel, segs=6))
    for k in range(18):
        y = 0.4 + k * 0.6 if k < 12 else depth - 0.8 + (k - 11) * 2.6 * math.cos(ang)
        z = 0.15 if k < 12 else 0.15 + (k - 11) * 2.6 * math.sin(ang)
        p.append(box(f"Sleeper{k}", (2.0, 0.25, 0.14), (0, y, z), rot=(ang if k >= 12 else 0, 0, 0), bevel=0.02, m=dark))
    for k in range(4):
        y = depth + 6 + k * 9 * math.cos(ang)
        z = 6 * math.sin(ang) + k * 9 * math.sin(ang)
        p.append(box(f"Trestle{k}", (2.2, 0.5, z + 2.0), (0, y, (z - 2.0) / 2 + 0.1), bevel=0.05, m=lmat("BasaltLight")))
    # The car: stepped cabin, red with cream windows band.
    car = []
    red, cream = lmat("Red", rough=0.45), lmat("Cream")
    for k in range(3):
        car.append(box(f"Cab{k}", (2.4, 1.5, 2.2), (0, 1.6 + k * 1.5, 1.45 + k * 0.45), bevel=0.12, m=red))
        car.append(box(f"Win{k}", (2.46, 1.2, 0.7), (0, 1.6 + k * 1.5, 1.85 + k * 0.45), bevel=0.05, m=lglow("LavaCabWindow", "#ffcf7a", 1.2)))
        car.append(box(f"Roof{k}", (2.6, 1.6, 0.15), (0, 1.6 + k * 1.5, 2.6 + k * 0.45), bevel=0.04, m=cream))
    p += car
    p += [bulb(f"Lamp{s}", 0.15, (s * (hw - 0.4), -0.6, h - 0.8), lglow("LavaLantern", "#ffb04a", 3.0)) for s in (-1, 1)]
    save("lava_funicular", [merge("Funicular", p)])


def build_cave():
    """Lava-tube cave mouth: a rough basalt arch 7 m wide and 5.5 m tall opening
    to -Y, a dark tunnel behind and glowing seams in the floor."""
    reset_scene()
    rng = random.Random(9)
    b, light, dark = lmat("Basalt", rough=0.85), lmat("BasaltLight", rough=0.85), lmat("BasaltDark", rough=0.9)
    p = []
    for i in range(15):
        a = math.radians(-8 + 196 * i / 14)
        x, z = math.cos(a) * 4.6, math.sin(a) * 5.4
        p.append(rock(f"Arch{i}", rng.uniform(1.3, 1.8), (x, rng.uniform(-0.4, 0.4), max(z, 0.4)), seed=30 + i,
                      m=(b, light)[i % 2], scale=(1.0, 1.4, 1.0), jitter=0.22))
    for i in range(10):
        a = math.radians(-20 + 220 * i / 9)
        x, z = math.cos(a) * 5.0, math.sin(a) * 5.8
        p.append(rock(f"Back{i}", 2.0, (x, 4.5, max(z, 0.6)), seed=60 + i, m=dark, scale=(1.0, 2.2, 1.0), jitter=0.2))
    p += [box("TunnelFloor", (7.0, 10.0, 0.1), (0, 4.0, 0.0), bevel=0.0, m=dark),
          box("TunnelBack", (8.0, 0.5, 7.0), (0, 9.0, 3.5), bevel=0.0, m=dark)]
    for k in range(5):
        p.append(box(f"Seam{k}", (rng.uniform(0.6, 1.6), 0.12, 0.05), (rng.uniform(-2.5, 2.5), 1.0 + k * 1.6, 0.04), rot=(0, 0, rng.uniform(-0.6, 0.6)),
                     bevel=0.0, m=ember_mat()))
    p += [rock("Lump0", 1.2, (-4.8, -1.0, 0.5), seed=81, m=b), rock("Lump1", 1.0, (5.0, -0.8, 0.4), seed=83, m=light)]
    save("lava_cave", [merge("Cave", p)])


def build_staff_hut():
    """Bamboo staff hut, 6 x 5 m under a thatch roof, its doorway (2.8 m) facing -Y."""
    reset_scene()
    bam, dark = lmat("Bamboo", rough=0.5), lmat("TikiDark")
    hw, hd, h = 3.0, 2.5, 3.0
    p = []
    for side, size, loc in (("Back", (2 * hw, 0.3, h), (0, hd, h / 2)), ("L", (0.3, 2 * hd, h), (-hw, 0, h / 2)),
                            ("R", (0.3, 2 * hd, h), (hw, 0, h / 2)),
                            ("FrontL", (hw - DOOR_W / 2, 0.3, h), (-(hw + DOOR_W / 2) / 2, -hd, h / 2)),
                            ("FrontR", (hw - DOOR_W / 2, 0.3, h), ((hw + DOOR_W / 2) / 2, -hd, h / 2)),
                            ("Lintel", (DOOR_W, 0.3, 0.5), (0, -hd, h - 0.25))):
        p.append(box("Wall" + side, size, loc, bevel=0.04, m=bam))
    for k in range(13):
        x = -hw + k * (2 * hw / 12)
        for y in (-hd - 0.17, hd + 0.17):
            if abs(x) > DOOR_W / 2 or y > 0:
                p.append(cyl(f"Pole{k}{y > 0}", 0.07, h, (x, y, h / 2), segs=6, bevel=0.0, m=lmat("BambooDark")))
    p += [box("Floor", (2 * hw, 2 * hd, 0.1), (0, 0, 0.05), bevel=0.0, m=lmat("BasaltDark")),
          box("Inside", (2 * hw - 0.4, 0.1, h - 0.2), (0, hd - 0.2, h / 2), bevel=0.0, m=lmat("TikiDark"))]
    p += thatch_hip("Roof", 2 * hw, 2 * hd, 1.8, h, seed=11)
    p += [box("Sign", (1.8, 0.08, 0.4), (0, -hd - 0.2, h + 0.05), bevel=0.02, m=lmat("Cream")),
          text("SignText", "STAFF ONLY", 0.2, 0.02, (0, -hd - 0.25, h + 0.04), m=lmat("Red")),
          bulb("Lamp", 0.14, (DOOR_W / 2 + 0.3, -hd - 0.3, h - 0.4), lglow("LavaLantern", "#ffb04a", 3.0))]
    p += [box("Crate", (0.9, 0.9, 0.8), (-hw + 0.8, -hd + 0.9, 0.4), bevel=0.04, m=lmat("TikiLight"))]
    save("lava_staff_hut", [merge("StaffHut", p)])


def build_gate():
    """The jungle-trail gate: two carved posts and a bamboo crossbeam with a sign,
    7 m wide (inner gap 5.6 m), 4.6 m tall, facing -Y."""
    reset_scene()
    p = []
    for s in (-1, 1):
        x = s * 3.1
        p += [box(f"Post{s}", (0.6, 0.6, 4.2), (x, 0, 2.1), bevel=0.06, m=lmat("Tiki")),
              cyl(f"Base{s}", 0.5, 0.4, (x, 0, 0.2), segs=8, bevel=0.04, m=lmat("Basalt"))]
        p += tiki_face(f"PF{s}", 0.55, 1.2, (x, -0.3, 3.2), style=s > 0)
    p += bamboo("Beam", (-3.6, 0, 4.0), (3.6, 0, 4.0), 0.16)
    p += bamboo("Beam2", (-3.4, 0, 4.4), (3.4, 0, 4.4), 0.12)
    p += [box("Sign", (3.4, 0.12, 0.7), (0, -0.25, 3.5), bevel=0.04, m=lmat("TikiDark")),
          text("SignText", "JUNGLE TRAIL", 0.34, 0.04, (0, -0.33, 3.48), m=lmat("Yellow"))]
    for k in range(6):
        p += flower(f"Fl{k}", (-1.5 + k * 0.6, -0.2, 4.2 + 0.08 * (k % 2)), 0.14)
    save("lava_gate", [merge("Gate", p)])


def build_kahuna_head():
    """A giant carved basalt tiki head (5.4 m) with glowing ember eyes and mouth,
    facing -Y: the terrace landmark. Base 4 x 3.4 m."""
    reset_scene()
    b, light, dark = lmat("Basalt", rough=0.85), lmat("BasaltLight", rough=0.85), lmat("BasaltDark", rough=0.9)
    molten = ember_mat()
    p = [box("Plinth", (4.2, 3.6, 0.6), (0, 0, 0.3), bevel=0.08, m=dark),
         box("Head", (3.4, 2.8, 4.2), (0, 0, 2.7), bevel=0.35, segs=3, m=b),
         box("Brow", (3.6, 0.8, 0.7), (0, -1.3, 3.75), bevel=0.2, m=light),
         box("Crown", (3.6, 3.0, 0.5), (0, 0, 4.95), bevel=0.15, m=dark)]
    for s in (-1, 1):
        p += [box(f"Socket{s}", (1.0, 0.3, 0.7), (s * 0.85, -1.35, 3.15), bevel=0.1, m=dark),
              box(f"Eye{s}", (0.7, 0.32, 0.38), (s * 0.85, -1.42, 3.12), bevel=0.08, m=molten),
              box(f"Ear{s}", (0.4, 1.2, 2.0), (s * 1.85, 0.0, 2.8), bevel=0.15, m=light)]
    p += [prism("Nose", [(-0.55, -0.6), (0.55, -0.6), (0.2, 0.6), (-0.2, 0.6)], 0.9, (0, -1.55, 2.5), m=light, bevel=0.1),
          box("MouthRim", (2.6, 0.5, 0.95), (0, -1.3, 1.55), bevel=0.15, m=dark),
          box("Mouth", (2.1, 0.4, 0.5), (0, -1.45, 1.55), bevel=0.1, m=molten)]
    for k in range(6):
        p.append(box(f"Tooth{k}", (0.24, 0.3, 0.22), (-0.75 + k * 0.3, -1.55, 1.73), bevel=0.04, m=lmat("Cream")))
    for k in range(5):
        p.append(prism(f"Plume{k}", [(-0.2, 0), (0.2, 0), (0.12, 1.4), (0, 1.6), (-0.12, 1.4)], 0.16, (-1.2 + k * 0.6, 0.3, 5.1),
                       rot=(0, math.radians((k - 2) * -12), 0), m=(lmat("Pink"), lmat("Yellow"), lmat("Teal"))[k % 3], bevel=0.03))
    save("lava_kahuna_head", [merge("KahunaHead", p)])


def build_cliff():
    """A rugged basalt outcrop ~16 m long, 6 m deep, up to ~9 m tall: heaped
    faceted boulders with a few short hexagonal columns at its foot. Long side
    along X, front -Y."""
    reset_scene()
    rng = random.Random(21)
    mats = [lmat("Basalt", rough=0.85), lmat("BasaltLight", rough=0.85), lmat("BasaltDark", rough=0.9)]
    p = []
    for i in range(9):
        x = -6.5 + i * 1.6 + rng.uniform(-0.5, 0.5)
        r = rng.uniform(2.6, 3.8) * (1.0 - abs(x) / 16.0)
        p.append(rock(f"Mass{i}", r, (x, rng.uniform(0.2, 1.2), r * 0.9), seed=40 + i, m=mats[i % 3],
                      scale=(1.2, 1.0, rng.uniform(1.2, 1.9)), jitter=0.3))
    for i in range(7):
        x = rng.uniform(-6.5, 6.5)
        h = rng.uniform(0.8, 2.4)
        p.append(cyl(f"Col{i}", 0.6, h, (x, -2.0 + rng.uniform(-0.3, 0.3), h / 2 - 0.2), segs=6, bevel=0.06, m=mats[rng.randrange(3)]))
    save("lava_cliff", [merge("Cliff", p)])


def build_island():
    """An offshore islet (~40 m wide, 18 m tall) with palms, for the sea horizon."""
    reset_scene()
    rng = random.Random(33)
    p = []
    for i in range(7):
        x = rng.uniform(-14, 14)
        p.append(rock(f"R{i}", rng.uniform(6, 10), (x, rng.uniform(-4, 4), 0), seed=90 + i, m=lmat("Basalt", rough=0.9),
                      scale=(1.3, 1.0, rng.uniform(0.9, 1.9)), jitter=0.25))
    for i in range(3):
        palm = blp.palm_parts(f"P{i}_", height=rng.uniform(7, 10), lean=rng.uniform(0.5, 1.6), seed=40 + i, fronds=7)
        p += place(palm, (rng.uniform(-9, 9), rng.uniform(-3, 3), 6.0), rot_z=rng.uniform(0, math.tau), scale=1.4)
    save("lava_island", [merge("Island", p)])


def build_volcano():
    """Mount Kahuna: a 520 m wide, 175 m tall stylised cone with gullies, a broken
    crater rim, a molten crater pool and three lava streams down its south face
    (-Y). Faceted; the level places it far to the north."""
    reset_scene()
    rng = random.Random(7)
    rock_m = mat("LavaVolcanoRock", "#241f2c", rough=0.95)
    ash_m = mat("LavaVolcanoAsh", "#3d3342", rough=0.95)
    scorch_m = mat("LavaVolcanoScorch", "#5a2f34", rough=0.9)
    molten = ember_mat()
    R, H, crater = 260.0, 175.0, 34.0
    rings, segs = 26, 72

    def height(r, a):
        t = min(r / R, 1.0)
        cone = H * (1.0 - t) ** 1.55 if r > crater else H * (1.0 - crater / R) ** 1.55 - (crater - r) * 0.55
        gully = math.sin(a * 11.0 + math.sin(a * 3.0) * 2.0) * 4.5 * min(1.0, t * 3.0)
        notch = -14.0 * math.exp(-((a - math.radians(-90)) ** 2) / 0.02) * max(0.0, 1.0 - (r - crater) / 30.0)
        return max(0.0, cone + gully + notch)

    bm = bmesh.new()
    grid = []
    for j in range(rings + 1):
        r = crater * 0.4 + (R - crater * 0.4) * (j / rings) ** 1.2
        row = []
        for i in range(segs):
            a = math.tau * i / segs
            rr = r * (1.0 + rng.uniform(-0.03, 0.03) * (j > 0))
            row.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, height(rr, a) + rng.uniform(-1.5, 1.5) * (0 < j < rings))))
        grid.append(row)
    me = bpy.data.meshes.new("Volcano")
    for j in range(rings):
        for i in range(segs):
            f = bm.faces.new((grid[j][i], grid[j][(i + 1) % segs], grid[j + 1][(i + 1) % segs], grid[j + 1][i]))
            z = sum(v.co.z for v in f.verts) / 4
            f.material_index = 2 if z > H * 0.62 else (1 if (z > H * 0.3 and (i // 3) % 2 == 0) else 0)
    face_up(bm)
    ob = _finish("Volcano", bm, rock_m, (0, 0, 0), (0, 0, 0), smooth=False)
    ob.data.materials.append(ash_m)
    ob.data.materials.append(scorch_m)
    p = [ob]
    top = height(crater * 0.5, 0.0)
    p.append(cyl("CraterPool", crater * 0.75, 2.0, (0, 0, top + 2.0), segs=24, bevel=0.0, m=molten))
    # Lava streams: ribbons following the surface down the south face.
    for k, (a0, wid) in enumerate(((-90.0, 9.0), (-115.0, 6.0), (-62.0, 6.5))):
        pts = []
        for i in range(22):
            t = i / 21
            r = crater * 0.95 + (R * 0.82 - crater) * t
            a = math.radians(a0 + math.sin(t * 5.0 + k) * 6.0 * t)
            pts.append((math.cos(a) * r, math.sin(a) * r, height(r, a) + 1.2))
        p.append(stream(f"Stream{k}", pts, wid, molten))
    save("lava_volcano", [merge("Volcano", p)])


def face_up(bm):
    """Turns every face of an open height surface to face upward."""
    bm.normal_update()
    flip = [f for f in bm.faces if f.normal.z < 0.0]
    if flip:
        bmesh.ops.reverse_faces(bm, faces=flip)


def stream(name, pts, width, m):
    """A flat ribbon along `pts`, narrowing toward the end, slightly crowned."""
    bm = bmesh.new()
    rows = []
    for i, p in enumerate(pts):
        a = Vector(pts[max(i - 1, 0)])
        b = Vector(pts[min(i + 1, len(pts) - 1)])
        d = (b - a)
        d.z = 0
        d.normalize()
        side = Vector((-d.y, d.x, 0))
        w = width * (1.0 - 0.6 * i / (len(pts) - 1)) * 0.5
        c = Vector(p)
        rows.append([bm.verts.new(c - side * w), bm.verts.new(c + Vector((0, 0, 0.6))), bm.verts.new(c + side * w)])
    for i in range(len(rows) - 1):
        for j in range(2):
            bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
    face_up(bm)
    return _finish(name, bm, m, (0, 0, 0), (0, 0, 0), smooth=False)


BUILDERS = {
    "observatory": build_observatory, "funicular": build_funicular, "cave": build_cave, "staff_hut": build_staff_hut,
    "gate": build_gate, "kahuna_head": build_kahuna_head, "cliff": build_cliff, "island": build_island, "volcano": build_volcano,
}


if __name__ == "__main__":
    wanted = [a for a in sys.argv[1:] if a in BUILDERS] or list(BUILDERS)
    for key in wanted:
        BUILDERS[key]()
