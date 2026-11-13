"""Megamall Midnight props (World 6, Midnight Mall): the Moonfall Fountain, the
escalators, the Galaxy Carousel, kiddie rides, food-court stalls and tables,
palms in planters, benches, retail carts, security gates, the glass elevator
cab, mannequins and window displays, shelving, the directory board, bins,
exit and emergency lights, the cinema doors and the exit-portal arch.

Each function builds one prop in a fresh scene and saves
art/blender/mall_<name>.blend + art/models/mall_<name>.glb.

    python art/blender/build_mall_props.py              (all props)
    python art/blender/build_mall_props.py fountain cart  (only these)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mall_common import *  # noqa: F401,F403
import build_world_portals as wp  # noqa: E402


def ring_wall(name, r_in, r_out, z0, z1, m, segs=48):
    """A round wall (annulus extruded from z0 to z1), bevelled."""
    bm = bmesh.new()
    rings = []
    for r, z in ((r_out, z0), (r_out, z1), (r_in, z1), (r_in, z0)):
        rings.append([bm.verts.new((math.cos(math.tau * i / segs) * r, math.sin(math.tau * i / segs) * r, z)) for i in range(segs)])
    for k in range(4):
        a, b = rings[k], rings[(k + 1) % 4]
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = bpy.data.objects.new(name, bpy.data.meshes.new(name))
    source_collection().objects.link(ob)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.materials.append(m)
    for p in ob.data.polygons:
        p.use_smooth = True
    return add_bevel(ob, 0.05, 2)


def sheet(name, r, z_top, drop, m, segs=32):
    """An open cylinder of falling water (no caps) from z_top down by drop."""
    bm = bmesh.new()
    top = [bm.verts.new((math.cos(math.tau * i / segs) * r, math.sin(math.tau * i / segs) * r, z_top)) for i in range(segs)]
    bot = [bm.verts.new((math.cos(math.tau * i / segs) * (r + 0.12), math.sin(math.tau * i / segs) * (r + 0.12), z_top - drop))
           for i in range(segs)]
    for i in range(segs):
        j = (i + 1) % segs
        bm.faces.new((top[i], top[j], bot[j], bot[i]))
    ob = bpy.data.objects.new(name, bpy.data.meshes.new(name))
    source_collection().objects.link(ob)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.materials.append(m)
    return ob


def bowl(name, r_top, r_bottom, z, h, m):
    return cyl(name, r_bottom, h, (0, 0, z + h / 2), segs=36, bevel=0.06, m=m, radius_top=r_top)


# ---------------------------------------------------------------------------
# The Moonfall Fountain (landmark): three basins under a chrome moon
# ---------------------------------------------------------------------------

def build_fountain():
    """Three stacked basins, falling water sheets, a crescent-ringed moon globe
    on top and a ring of coloured lights in the pool (separate "Lights" object,
    its MallFountainLight surface colour-cycled by the level). ~5.6 m tall,
    7.8 m across."""
    reset_scene()
    terr, pink, cream = mmat("Terrazzo", 0.35), mmat("TerrazzoPink", 0.35), mmat("Cream", 0.4)
    teal, navy = mmat("Teal", 0.35), mmat("Navy", 0.4)
    ch, w = chrome(), water()
    moon = mat("MallMoonGlobe", MALL["Moon"], rough=0.3, emit=0.9)
    ring_m = neon("Pink", MALL["Pink"], 2.6)
    p = [
        ring_wall("BasinWall", 3.45, 3.9, 0.0, 0.62, pink, segs=56),
        torus("BasinLip", 3.68, 0.2, (0, 0, 0.64), m=cream, major_segs=56, minor_segs=10),
        ring_wall("BasinStep", 3.9, 4.15, 0.0, 0.22, terr, segs=56),
        cyl("PoolFloor", 3.5, 0.1, (0, 0, 0.05), segs=40, bevel=0.0, m=navy),
        cyl("PoolWater", 3.5, 0.04, (0, 0, 0.44), segs=48, bevel=0.0, m=w),
        # Middle tier.
        cyl("Pedestal1", 0.75, 1.3, (0, 0, 0.75), segs=24, bevel=0.06, m=teal),
        torus("Pedestal1Band", 0.78, 0.06, (0, 0, 1.2), m=ch, major_segs=32, minor_segs=6),
        bowl("Bowl1", 2.15, 0.8, 1.35, 0.55, cream),
        torus("Bowl1Lip", 2.12, 0.09, (0, 0, 1.92), m=ch, major_segs=48, minor_segs=8),
        cyl("Bowl1Water", 2.02, 0.03, (0, 0, 1.86), segs=40, bevel=0.0, m=w),
        sheet("Bowl1Sheet", 2.2, 1.9, 1.45, w),
        # Top tier.
        cyl("Pedestal2", 0.42, 1.1, (0, 0, 2.4), segs=20, bevel=0.05, m=pink),
        bowl("Bowl2", 1.2, 0.45, 2.85, 0.4, cream),
        torus("Bowl2Lip", 1.18, 0.07, (0, 0, 3.26), m=ch, major_segs=40, minor_segs=8),
        cyl("Bowl2Water", 1.1, 0.03, (0, 0, 3.2), segs=32, bevel=0.0, m=w),
        sheet("Bowl2Sheet", 1.24, 3.24, 1.3, w),
        # The moon on its stalk, ringed like a planet, a crescent star on top.
        cyl("Stalk", 0.16, 1.0, (0, 0, 3.6), segs=12, bevel=0.03, m=ch),
        sphere("Moon", 0.85, (0, 0, 4.6), m=moon, segs=28, rings=16),
        torus("MoonRing", 1.35, 0.07, (0, 0, 4.6), rot=rad(22, -14, 0), m=ring_m, major_segs=48, minor_segs=8),
        torus("MoonRingB", 1.55, 0.035, (0, 0, 4.6), rot=rad(22, -14, 0), m=ch, major_segs=48, minor_segs=6),
        star("MoonStar", 0.32, 0.08, (0, 0, 5.7), rot=rad(0, 0, 0), m=mat("MallStarGold", MALL["Yellow"], rough=0.3, emit=1.2)),
    ]
    # Craters on the moon.
    rng = random.Random(4)
    for i in range(7):
        a, b = rng.uniform(0, math.tau), rng.uniform(-0.9, 0.9)
        n = Vector((math.cos(a) * math.cos(b), math.sin(a) * math.cos(b), math.sin(b)))
        p.append(sphere(f"Crater{i}", rng.uniform(0.12, 0.2), tuple(Vector((0, 0, 4.6)) + n * 0.8), scale=(1, 1, 0.4),
                        rot=n.to_track_quat("Z", "Y").to_euler(), m=mat("MallCrater", "#e8d6a0", rough=0.5, emit=0.5), segs=10, rings=5))
    # Jets arcing from the basin lip into the pool, and a central plume.
    for i in range(8):
        a = math.tau * (i + 0.5) / 8
        c, s = math.cos(a), math.sin(a)
        pts = [(c * 3.35, s * 3.35, 0.7), (c * 2.9, s * 2.9, 1.5), (c * 2.4, s * 2.4, 1.15), (c * 2.2, s * 2.2, 0.5)]
        p.append(tube(f"Jet{i}", pts, 0.05, m=w, segs=6, radius_end=0.08))
    for i in range(4):
        a = math.tau * i / 4
        p.append(tube(f"Spout{i}", [(math.cos(a) * 0.3, math.sin(a) * 0.3, 5.0), (math.cos(a) * 0.9, math.sin(a) * 0.9, 5.25),
                                    (math.cos(a) * 1.1, math.sin(a) * 1.1, 3.4)], 0.035, m=w, segs=6, radius_end=0.06))
    fountain = merge("Fountain", p)
    lights_m = mat("MallFountainLight", "#ff6fd0", rough=0.3, emit=3.0)
    lp = []
    for i in range(16):
        a = math.tau * i / 16
        lp.append(cyl(f"Lamp{i}", 0.13, 0.08, (math.cos(a) * 3.2, math.sin(a) * 3.2, 0.12), segs=10, bevel=0.0, m=lights_m))
    for i in range(10):
        a = math.tau * i / 10
        lp.append(cyl(f"BowlLamp{i}", 0.08, 0.05, (math.cos(a) * 1.6, math.sin(a) * 1.6, 1.36), segs=8, bevel=0.0, m=lights_m))
    lights = merge("Lights", lp)
    save("mall_fountain", [fountain, lights])


# ---------------------------------------------------------------------------
# Escalator: 10 m run, 5 m rise, rising toward +Y (north in the level)
# ---------------------------------------------------------------------------

ESC_RUN = 10.0
ESC_RISE = 5.0
ESC_STEP_W = 2.3
ESC_GLASS_X = 1.25
ESC_SIDE_X = 1.5


def _side_prism(name, x0, x1, top_off, m):
    """The solid side cladding: a parallelogram under the incline down to the floor."""
    outline = [(-1.2, 0.0), (ESC_RUN + 0.05, 0.0), (ESC_RUN + 0.05, ESC_RISE + top_off),
               (0.0, top_off), (-1.2, top_off)]
    ob = prism(name, outline, abs(x1 - x0), m=m)
    # prism extrudes along Y with the outline in XZ: turn it so the outline's x runs along +Y.
    ob.rotation_euler = (0, 0, math.radians(90))
    ob.location = ((x0 + x1) / 2, 0, 0)
    return ob


def build_escalator(out_of_order=False):
    """Chrome-and-teal escalator with glass balustrades, black handrails, a neon
    strip under each rail and solid side cladding down to the floor. The steps
    are visual; the level walks on an invisible ramp along them."""
    reset_scene()
    ch, dark, rub = chrome(), chrome_dark(), mmat("Rubber", 0.5)
    clad = mmat("Teal", 0.35) if not out_of_order else mmat("Violet", 0.4)
    step_m = mat("MallStep", "#3a3a4a", rough=0.4, metal=0.5)
    edge = mat("MallStepEdge", MALL["Yellow"], rough=0.4)
    gl = glass()
    strip = neon("Teal", "#3ff0e0", 2.6) if not out_of_order else mat("MallNeonOff", "#4a3a5a", rough=0.4)
    slope = math.atan2(ESC_RISE, ESC_RUN)
    length = math.hypot(ESC_RUN, ESC_RISE)
    p = []
    # Steps (sawtooth) between flat comb plates.
    n = 25
    for k in range(n):
        y0 = ESC_RUN * k / n
        z = ESC_RISE * (k + 0.5) / n + 0.06
        p.append(box(f"Step{k:02d}", (ESC_STEP_W, ESC_RUN / n + 0.01, 0.3), (0, y0 + ESC_RUN / n / 2, z - 0.15), bevel=0.01, m=step_m))
        p.append(box(f"StepEdge{k:02d}", (ESC_STEP_W, 0.04, 0.02), (0, y0 + 0.03, z + 0.005), bevel=0.0, m=edge))
    p.append(box("CombLow", (ESC_STEP_W + 0.1, 1.2, 0.04), (0, -0.6, 0.02), bevel=0.01, m=dark))
    p.append(box("CombHigh", (ESC_STEP_W + 0.1, 0.8, 0.04), (0, ESC_RUN + 0.4, ESC_RISE + 0.02), bevel=0.01, m=dark))
    for s in (-1, 1):
        # Side cladding: the incline body down to the floor.
        p.append(_side_prism(f"Clad{s}", s * ESC_STEP_W / 2, s * ESC_SIDE_X, 0.25, clad))
        # Inner skirt (chrome) and outer deck (chrome) along the incline.
        mid = (0, ESC_RUN / 2, ESC_RISE / 2)
        p.append(box(f"Skirt{s}", (0.06, length + 0.1, 0.45), (s * (ESC_STEP_W / 2 + 0.03), mid[1], mid[2] + 0.2),
                     rot=(slope, 0, 0), bevel=0.01, m=ch))
        p.append(box(f"Deck{s}", (ESC_SIDE_X - ESC_GLASS_X + 0.1, length + 0.1, 0.12),
                     (s * (ESC_GLASS_X + ESC_SIDE_X) / 2, mid[1], mid[2] + 0.42), rot=(slope, 0, 0), bevel=0.02, m=ch))
        # Glass balustrade along the incline plus flat runs at both ends.
        p.append(box(f"Glass{s}", (0.04, length + 0.3, 0.9), (s * ESC_GLASS_X, mid[1], mid[2] + 0.95), rot=(slope, 0, 0), bevel=0.0, m=gl))
        p.append(box(f"GlassLow{s}", (0.04, 1.3, 0.9), (s * ESC_GLASS_X, -0.65, 0.95), bevel=0.0, m=gl))
        p.append(box(f"GlassHigh{s}", (0.04, 0.9, 0.9), (s * ESC_GLASS_X, ESC_RUN + 0.45, ESC_RISE + 0.95), bevel=0.0, m=gl))
        # Handrail: low flat run, incline, high flat run, with round newel ends.
        rail = [(s * ESC_GLASS_X, -1.25, 1.12), (s * ESC_GLASS_X, -0.1, 1.42), (s * ESC_GLASS_X, ESC_RUN - 0.1, ESC_RISE + 1.42),
                (s * ESC_GLASS_X, ESC_RUN + 0.9, ESC_RISE + 1.42)]
        p.append(tube(f"Rail{s}", rail, 0.055, m=rub, segs=8))
        p.append(tube(f"Strip{s}", [(s * (ESC_GLASS_X + 0.1), -0.6, 0.5), (s * (ESC_GLASS_X + 0.1), ESC_RUN - 0.4, ESC_RISE + 0.5)],
                      0.025, m=strip, segs=6))
        p.append(box(f"NewelCap{s}", (0.3, 0.7, 0.55), (s * ESC_GLASS_X, -1.0, 0.28), bevel=0.12, m=ch))
    if out_of_order:
        red = mmat("Red", 0.5)
        yel = mmat("Yellow", 0.5)
        # A sign on a post at the foot of the right balustrade (the steps stay walkable).
        x = ESC_GLASS_X
        p += [
            cyl("SignPost", 0.03, 1.5, (x, -1.25, 1.05), segs=6, bevel=0.0, m=red),
            box("SignBoard", (0.9, 0.05, 0.55), (x, -1.3, 1.85), bevel=0.03, m=yel),
            box("SignStripe", (0.92, 0.06, 0.08), (x, -1.3, 1.52), bevel=0.0, m=red),
            text("SignText", "OUT OF\nORDER", 0.15, 0.02, (x, -1.34, 1.87), m=mmat("Charcoal", 0.6)),
        ]
    save("mall_escalator_dead" if out_of_order else "mall_escalator", [merge("Escalator", p)])


def build_escalator_dead():
    build_escalator(True)


# ---------------------------------------------------------------------------
# Galaxy Carousel: a static plinth and a spinning ride
# ---------------------------------------------------------------------------

def build_carousel():
    """Kiddie carousel: rockets and ringed planets on brass poles under a
    striped canopy rimmed with bulbs. "Base" stays still; "Spin" turns."""
    reset_scene()
    pink, teal, cream, navy, vio = mmat("Pink", 0.45), mmat("Teal", 0.45), mmat("Cream", 0.5), mmat("Navy", 0.4), mmat("Violet", 0.45)
    ch, gold = chrome(), mat("MallBrass", "#e8b54a", rough=0.25, metal=0.8)
    bulb_m = glow("MallBulbWarm", "#ffd27a", 3.0)
    base = merge("Base", [
        cyl("Plinth", 3.1, 0.32, (0, 0, 0.16), segs=40, bevel=0.06, m=navy),
        torus("PlinthLip", 3.05, 0.07, (0, 0, 0.32), m=gold, major_segs=48, minor_segs=6),
        cyl("Core", 0.55, 3.6, (0, 0, 2.0), segs=20, bevel=0.04, m=cream),
    ])
    p = [cyl("Deck", 2.85, 0.12, (0, 0, 0.4), segs=40, bevel=0.03, m=mat("MallDeck", "#d9c6ff", rough=0.5))]
    # Canopy: a shallow cone of alternating panels, a scalloped valance and bulbs.
    p.append(cyl("Canopy", 3.1, 0.95, (0, 0, 4.2), segs=48, bevel=0.05, m=pink, radius_top=0.15))
    for i in range(12):
        a0 = math.tau * i / 12
        c, s = math.cos(a0), math.sin(a0)
        p.append(tube(f"Rib{i}", [(c * 3.12, s * 3.12, 3.74), (c * 0.2, s * 0.2, 4.68)], 0.07, m=cream, segs=6))
        p.append(sphere(f"Scallop{i}", 0.42, (math.cos(a0 + 0.26) * 3.05, math.sin(a0 + 0.26) * 3.05, 3.45), scale=(1, 0.25, 0.6),
                        rot=(0, 0, a0 + 0.26 + math.pi / 2), m=teal if i % 2 else vio, segs=10, rings=5))
    p.append(cyl("CanopyRim", 3.15, 0.25, (0, 0, 3.62), segs=48, bevel=0.04, m=teal))
    p.append(star("TopStar", 0.45, 0.1, (0, 0, 5.05), m=mat("MallStarGold", MALL["Yellow"], rough=0.3, emit=1.2)))
    p.append(cyl("TopSpike", 0.06, 0.5, (0, 0, 4.7), segs=8, bevel=0.0, m=gold))
    for i in range(24):
        a = math.tau * i / 24
        p.append(bulb(f"Bulb{i:02d}", 0.06, (math.cos(a) * 3.2, math.sin(a) * 3.2, 3.62), bulb_m))
    # Riders: rockets and planets on poles.
    rng = random.Random(9)
    for i in range(6):
        a = math.tau * i / 6
        c, s = math.cos(a), math.sin(a)
        x, y = c * 2.15, s * 2.15
        h = 1.25 + 0.25 * (i % 2)
        p.append(cyl(f"Pole{i}", 0.04, 3.1, (x, y, 2.0), segs=8, bevel=0.0, m=gold))
        body_m = [pink, teal, vio][i % 3]
        if i % 2 == 0:
            # A rocket facing along the direction of travel (counter-clockwise).
            q = rad(90, 0, 0)
            p.append(cyl(f"Rocket{i}", 0.3, 1.0, (x, y, h), rot=(q[0], 0, a), segs=16, bevel=0.06, m=body_m))
            tip = Vector((x, y, h)) + Vector((-s, c, 0)) * 0.75
            p.append(cyl(f"RocketNose{i}", 0.3, 0.5, tuple(tip), rot=(q[0], 0, a), segs=16, bevel=0.0, m=cream, radius_top=0.02))
            for k in range(3):
                fa = math.tau * k / 3
                fin = Vector((x, y, h)) + Vector((s, -c, 0)) * 0.4 + Vector((math.cos(fa) * c, math.cos(fa) * s, math.sin(fa))) * 0.25
                p.append(box(f"Fin{i}{k}", (0.06, 0.3, 0.3), tuple(fin), rot=(fa, 0, a), bevel=0.02, m=cream))
            p.append(cushion(f"Saddle{i}", (0.34, 0.5, 0.12), (x, y, h + 0.3), mmat("Red", 0.5), rot=(0, 0, a)))
        else:
            p.append(sphere(f"Planet{i}", 0.42, (x, y, h + 0.1), m=body_m, segs=16, rings=10))
            p.append(torus(f"PlanetRing{i}", 0.62, 0.05, (x, y, h + 0.1), rot=(0.4, 0.2 * rng.uniform(-1, 1), a), m=gold,
                           major_segs=28, minor_segs=6))
            p.append(cushion(f"Seat{i}", (0.34, 0.4, 0.1), (x, y, h + 0.52), mmat("Yellow", 0.5), rot=(0, 0, a)))
    # Two benches (planet "chariots") between riders.
    for i in range(3):
        a = math.tau * (i + 0.5) / 3 + 0.5
        x, y = math.cos(a) * 1.5, math.sin(a) * 1.5
        p.append(cushion(f"Bench{i}", (0.9, 0.45, 0.45), (x, y, 0.7), teal, rot=(0, 0, a + math.pi / 2)))
    spin = merge("Spin", p)
    save("mall_carousel", [base, spin])


# ---------------------------------------------------------------------------
# Kiddie rides and small furniture
# ---------------------------------------------------------------------------

def build_kiddie_rocket():
    """Coin-op rocket ride on a sprung base."""
    reset_scene()
    red, cream, teal, yel = mmat("Red", 0.4), mmat("Cream", 0.5), mmat("Teal", 0.4), mmat("Yellow", 0.45)
    ch = chrome()
    q = rad(90, 0, 0)
    p = [
        cyl("Base", 0.75, 0.3, (0, 0, 0.15), segs=24, bevel=0.06, m=mmat("Navy", 0.4)),
        cyl("CoinBox", 0.18, 0.3, (0, -0.62, 0.45), segs=12, bevel=0.03, m=ch),
        cyl("Spring", 0.12, 0.3, (0, 0, 0.42), segs=10, bevel=0.0, m=ch),
        cyl("Body", 0.42, 1.5, (0, 0.1, 0.95), rot=(q[0], 0, 0), segs=20, bevel=0.08, m=red),
        cyl("Nose", 0.42, 0.7, (0, -1.0, 0.95), rot=(q[0], 0, 0), segs=20, bevel=0.0, m=cream, radius_top=0.03),
        cyl("Exhaust", 0.3, 0.25, (0, 0.95, 0.95), rot=(q[0], 0, 0), segs=16, bevel=0.03, m=ch, radius_top=0.38),
        cushion("Seat", (0.42, 0.5, 0.16), (0, 0.2, 1.42), teal),
        cyl("Window", 0.16, 0.06, (0.4, -0.35, 1.05), rot=(0, math.radians(90), 0), segs=14, bevel=0.0, m=glow("MallPorthole", "#7fe8ff", 1.4)),
        cyl("WindowB", 0.16, 0.06, (-0.4, -0.35, 1.05), rot=(0, math.radians(90), 0), segs=14, bevel=0.0, m=glow("MallPorthole", "#7fe8ff", 1.4)),
        box("Handle", (0.5, 0.06, 0.06), (0, -0.25, 1.55), bevel=0.02, m=ch),
    ]
    for k in range(3):
        a = math.tau * k / 3 + math.pi / 2
        p.append(box(f"Fin{k}", (0.06, 0.45, 0.4), (math.cos(a) * 0.45, 0.6, 0.95 + math.sin(a) * 0.45), rot=(0, -a + math.pi / 2, 0),
                     bevel=0.03, m=yel))
    save("mall_kiddie_rocket", [merge("KiddieRocket", p)])


def build_kiddie_car():
    """Coin-op space buggy ride."""
    reset_scene()
    body, cream, teal = mmat("Violet", 0.4), mmat("Cream", 0.5), mmat("Teal", 0.4)
    ch, rub = chrome(), mmat("Rubber", 0.6)
    p = [
        cyl("Base", 0.8, 0.25, (0, 0, 0.125), segs=24, bevel=0.05, m=mmat("Navy", 0.4)),
        box("Body", (0.9, 1.5, 0.45), (0, 0, 0.55), bevel=0.2, segs=3, m=body),
        box("Hood", (0.8, 0.5, 0.2), (0, -0.55, 0.85), bevel=0.08, m=body),
        cushion("Seat", (0.6, 0.45, 0.35), (0, 0.3, 0.9), teal),
        box("Fin", (0.06, 0.5, 0.45), (0, 0.6, 1.05), bevel=0.03, m=cream),
        sphere("Bubble", 0.4, (0, -0.15, 1.0), scale=(1.0, 0.9, 0.7), m=glass()),
        tube("Wheel", [(0, -0.7, 1.0), (0, -0.55, 1.15)], 0.03, m=ch, segs=6),
        torus("SteerWheel", 0.14, 0.025, (0, -0.52, 1.18), rot=rad(60, 0, 0), m=rub, major_segs=16, minor_segs=5),
    ]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(cyl(f"Tyre{sx}{sy}", 0.22, 0.18, (sx * 0.5, sy * 0.5, 0.42), rot=(0, math.radians(90), 0), segs=16, bevel=0.05, m=rub))
            p.append(cyl(f"Hub{sx}{sy}", 0.1, 0.2, (sx * 0.5, sy * 0.5, 0.42), rot=(0, math.radians(90), 0), segs=10, bevel=0.0, m=ch))
    p.append(bulb("Light", 0.07, (0, -0.8, 0.7), glow("MallBulbWarm", "#ffd27a", 3.0)))
    save("mall_kiddie_car", [merge("KiddieCar", p)])


def build_palm():
    """Round terrazzo planter with a palm, ~4 m tall."""
    reset_scene()
    planter, rim = mmat("TerrazzoPink", 0.4), mmat("Cream", 0.45)
    leaf, leaf2, trunk = mmat("Leaf", 0.6), mmat("LeafDark", 0.6), mmat("Trunk", 0.8)
    p = [
        cyl("Planter", 0.9, 0.8, (0, 0, 0.4), segs=28, bevel=0.06, m=planter, radius_top=1.0),
        torus("Rim", 0.98, 0.07, (0, 0, 0.8), m=rim, major_segs=32, minor_segs=6),
        cyl("Soil", 0.92, 0.04, (0, 0, 0.77), segs=24, bevel=0.0, m=mat("MallSoil", "#4a3326", rough=0.9)),
    ]
    pts = []
    for i in range(7):
        t = i / 6
        pts.append((0.25 * math.sin(t * 1.6), 0.08 * t, 0.8 + t * 2.6))
    for i in range(6):
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        p.append(cyl(f"Trunk{i}", 0.17 - i * 0.012, 0.5, tuple((a + b) / 2), rot=(0, math.atan2(b.x - a.x, b.z - a.z), 0), segs=10,
                     bevel=0.04, m=trunk, radius_top=0.14 - i * 0.012))
    top = Vector(pts[-1])
    for i in range(9):
        a = math.tau * i / 9 + 0.2
        c, s = math.cos(a), math.sin(a)
        frond = [tuple(top), tuple(top + Vector((c * 0.7, s * 0.7, 0.35))), tuple(top + Vector((c * 1.4, s * 1.4, 0.2))),
                 tuple(top + Vector((c * 1.85, s * 1.85, -0.35)))]
        p.append(blob_leaf(f"Frond{i}", frond, leaf if i % 2 else leaf2))
    for i in range(3):
        a = math.tau * i / 3
        p.append(sphere(f"Nut{i}", 0.1, tuple(top + Vector((math.cos(a) * 0.17, math.sin(a) * 0.17, -0.12))), m=trunk, segs=8, rings=5))
    save("mall_palm", [merge("Palm", p)])


def blob_leaf(name, points, m):
    """A flat, tapering frond swept along points (wide in the middle)."""
    pts = [Vector(q) for q in points]
    bm = bmesh.new()
    n = 9
    rows = []
    for i in range(n):
        t = i / (n - 1)
        seg = min(int(t * (len(pts) - 1)), len(pts) - 2)
        u = t * (len(pts) - 1) - seg
        c = pts[seg].lerp(pts[seg + 1], u)
        d = (pts[seg + 1] - pts[seg]).normalized()
        side = d.cross(Vector((0, 0, 1))).normalized()
        w = 0.34 * math.sin(math.pi * min(1.0, t * 1.1 + 0.05))
        droop = Vector((0, 0, -0.06 * math.sin(math.pi * t)))
        rows.append((bm.verts.new(c - side * w + droop), bm.verts.new(c + Vector((0, 0, 0.03))), bm.verts.new(c + side * w + droop)))
    for i in range(n - 1):
        a, b = rows[i], rows[i + 1]
        bm.faces.new((a[0], a[1], b[1], b[0]))
        bm.faces.new((a[1], a[2], b[2], b[1]))
    ob = bpy.data.objects.new(name, bpy.data.meshes.new(name))
    source_collection().objects.link(ob)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.materials.append(m)
    sol = ob.modifiers.new("Solid", "SOLIDIFY")
    sol.thickness = 0.03
    return ob


def build_bench():
    """Chrome-framed bench with a teal cushion (2.2 m)."""
    reset_scene()
    ch, teal, pink = chrome(), mmat("Teal", 0.5), mmat("Pink", 0.5)
    p = [
        cushion("Seat", (2.2, 0.6, 0.16), (0, 0, 0.46), teal),
        cushion("Back", (2.2, 0.14, 0.42), (0, 0.27, 0.78), pink, rot=rad(-8, 0, 0)),
    ]
    for x in (-0.9, 0.9):
        p.append(tube(f"Leg{x}", [(x, -0.25, 0.0), (x, -0.25, 0.38), (x, 0.25, 0.38), (x, 0.3, 0.0)], 0.035, m=ch, segs=8))
        p.append(tube(f"Arm{x}", [(x * 1.18, -0.28, 0.38), (x * 1.18, -0.28, 0.62), (x * 1.18, 0.28, 0.62)], 0.03, m=ch, segs=8))
    save("mall_bench", [merge("Bench", p)])


def build_table_set():
    """Food-court table with four bucket chairs, a tray and two cups."""
    reset_scene()
    ch, top = chrome(), mat("MallTableTop", "#f6e9ff", rough=0.35)
    seat = mmat("Pink", 0.45)
    p = [
        cyl("Top", 0.62, 0.06, (0, 0, 0.75), segs=28, bevel=0.02, m=top),
        torus("Edge", 0.62, 0.03, (0, 0, 0.75), m=mmat("Teal", 0.4), major_segs=28, minor_segs=5),
        cyl("Stem", 0.06, 0.72, (0, 0, 0.38), segs=10, bevel=0.0, m=ch),
        cyl("Foot", 0.32, 0.05, (0, 0, 0.025), segs=20, bevel=0.015, m=ch),
        box("Tray", (0.42, 0.3, 0.03), (0.12, 0.05, 0.795), bevel=0.01, m=mmat("Orange", 0.5)),
        cyl("CupA", 0.05, 0.16, (0.0, -0.25, 0.86), segs=10, bevel=0.01, m=mmat("Red", 0.5), radius_top=0.06),
        cyl("CupB", 0.05, 0.16, (-0.3, 0.1, 0.86), segs=10, bevel=0.01, m=mmat("Yellow", 0.5), radius_top=0.06),
    ]
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        c, s = math.cos(a), math.sin(a)
        x, y = c * 0.95, s * 0.95
        p.append(cyl(f"ChairStem{i}", 0.04, 0.42, (x, y, 0.21), segs=8, bevel=0.0, m=ch))
        p.append(cyl(f"ChairSeat{i}", 0.24, 0.1, (x, y, 0.46), segs=16, bevel=0.04, m=seat))
        bx, by = c * 1.18, s * 1.18
        p.append(box(f"ChairBack{i}", (0.42, 0.08, 0.36), (bx, by, 0.7), rot=(math.radians(-10), 0, a + math.pi / 2), bevel=0.04, m=seat))
    save("mall_table_set", [merge("TableSet", p)])


def build_bin():
    """Round chrome litter bin with a teal band."""
    reset_scene()
    ch, teal = chrome(), mmat("Teal", 0.4)
    p = [
        cyl("Body", 0.32, 0.9, (0, 0, 0.45), segs=20, bevel=0.03, m=ch),
        torus("Band", 0.33, 0.04, (0, 0, 0.7), m=teal, major_segs=20, minor_segs=5),
        sphere("Lid", 0.33, (0, 0, 0.9), scale=(1, 1, 0.45), m=teal, segs=16, rings=8),
        box("Slot", (0.3, 0.1, 0.08), (0, -0.28, 0.98), bevel=0.02, m=mmat("Charcoal", 0.6)),
    ]
    save("mall_bin", [merge("Bin", p)])


# ---------------------------------------------------------------------------
# Retail cart, security gate, directory, signage
# ---------------------------------------------------------------------------

def build_cart():
    """A retail cart: wheeled counter under a striped canopy with plush toys and
    a spinner rack. The stripes use MallAccent (tinted per cart by the level)."""
    reset_scene()
    accent, cream, ch, wood = mat("MallAccent", MALL["Pink"], rough=0.5), mmat("Cream", 0.5), chrome(), mmat("Wood", 0.6)
    p = [
        box("Counter", (2.2, 1.0, 0.95), (0, 0, 0.58), bevel=0.06, m=wood),
        box("CounterTop", (2.3, 1.1, 0.06), (0, 0, 1.08), bevel=0.02, m=cream),
        box("Kick", (2.0, 0.9, 0.12), (0, 0, 0.1), bevel=0.02, m=mmat("Charcoal", 0.6)),
    ]
    for sx in (-1, 1):
        p.append(cyl(f"Wheel{sx}", 0.16, 0.1, (sx * 0.8, -0.5, 0.16), rot=(0, math.radians(90), 0), segs=14, bevel=0.03, m=mmat("Rubber", 0.6)))
        p.append(tube(f"Post{sx}", [(sx * 1.05, -0.45, 1.1), (sx * 1.05, -0.45, 2.3)], 0.03, m=ch, segs=8))
        p.append(tube(f"PostB{sx}", [(sx * 1.05, 0.45, 1.1), (sx * 1.05, 0.45, 2.3)], 0.03, m=ch, segs=8))
    for i in range(6):
        p.append(box(f"Stripe{i}", (0.42, 1.3, 0.06), (-1.05 + 0.42 * i + 0.21, 0, 2.38), rot=rad(0, 0, 0), bevel=0.02,
                     m=accent if i % 2 == 0 else cream))
        p.append(sphere(f"Scallop{i}", 0.21, (-1.05 + 0.42 * i + 0.21, -0.65, 2.3), scale=(1, 0.3, 0.6), m=accent if i % 2 == 0 else cream,
                        segs=10, rings=5))
    # Goods: plush moons and stars, sunglasses stand.
    rng = random.Random(3)
    cols = ["#ff86c4", "#7fe8ff", "#ffd23f", "#b48cff", "#8ff5c8"]
    for i in range(7):
        x = -0.9 + i * 0.3
        c = mat(f"MallPlush{i % 5}", cols[i % 5], rough=0.8)
        p.append(sphere(f"Plush{i}", 0.13, (x, rng.uniform(-0.25, 0.25), 1.24), scale=(1, 0.9, 1.1), m=c, segs=10, rings=6))
    p.append(cyl("Spinner", 0.04, 0.9, (0.7, 0.1, 1.55), segs=8, bevel=0.0, m=ch))
    for k in range(4):
        p.append(box(f"Shades{k}", (0.22, 0.04, 0.07), (0.7 + math.cos(k * 1.57) * 0.13, 0.1 + math.sin(k * 1.57) * 0.13, 1.3 + k * 0.15),
                     rot=(0, 0, k * 1.57), bevel=0.02, m=mmat("Charcoal", 0.3)))
    save("mall_cart", [merge("Cart", p)])


def build_security_gate():
    """A pair of anti-theft pedestals (2.6 m apart) with glowing edges."""
    reset_scene()
    gl = glass("MallGateGlass", "#bfe8ff", alpha=0.35, emit=0.2)
    ch, glow_m = chrome(), neon("Teal", "#3ff0e0", 2.6)
    p = []
    for sx in (-1.3, 1.3):
        p += [
            box(f"Foot{sx}", (0.3, 0.5, 0.08), (sx, 0, 0.04), bevel=0.02, m=ch),
            box(f"Panel{sx}", (0.08, 0.42, 1.5), (sx, 0, 0.83), bevel=0.03, m=gl),
            box(f"EdgeF{sx}", (0.1, 0.04, 1.5), (sx, -0.22, 0.83), bevel=0.0, m=glow_m),
            box(f"EdgeB{sx}", (0.1, 0.04, 1.5), (sx, 0.22, 0.83), bevel=0.0, m=glow_m),
            box(f"Cap{sx}", (0.12, 0.5, 0.08), (sx, 0, 1.6), bevel=0.03, m=ch),
        ]
    save("mall_security_gate", [merge("SecurityGate", p)])


def build_directory():
    """Mall directory pylon: rounded chrome frame, a glowing floor plan with a
    YOU ARE HERE star and a moon logo on top. Double-sided."""
    reset_scene()
    ch, navy = chrome(), mmat("Navy", 0.4)
    screen = mat("MallDirectoryScreen", "#2b3a8a", rough=0.3, emit=0.8)
    p = [
        box("Frame", (1.3, 0.3, 2.3), (0, 0, 1.25), bevel=0.12, segs=3, m=ch),
        box("Foot", (1.0, 0.5, 0.12), (0, 0, 0.06), bevel=0.04, m=navy),
        cyl("Logo", 0.35, 0.12, (0, 0, 2.62), rot=rad(90, 0, 0), segs=24, bevel=0.03, m=mat("MallMoonGlobe", MALL["Moon"], rough=0.3, emit=0.9)),
    ]
    colours = ["#ff4fa8", "#3ff0e0", "#ffb547", "#8a5cff", "#8ff5c8"]
    for side in (-1, 1):
        y = side * 0.16
        p.append(box(f"Screen{side}", (1.05, 0.03, 1.8), (0, y, 1.3), bevel=0.0, m=screen))
        rng = random.Random(7 + side)
        for i in range(10):
            c = mat(f"MallMapBlock{i % 5}", colours[i % 5], rough=0.4, emit=1.0)
            p.append(box(f"Block{side}{i}", (rng.uniform(0.15, 0.32), 0.02, rng.uniform(0.12, 0.28)),
                         (rng.uniform(-0.35, 0.35), y + side * 0.02, rng.uniform(0.7, 1.95)), bevel=0.0, m=c))
        p.append(star(f"Here{side}", 0.08, 0.02, (0.05, y + side * 0.035, 1.15), rot=(0, 0, 0), m=mat("MallStarGold", MALL["Yellow"], rough=0.3, emit=1.2)))
        p.append(text(f"Title{side}", "DIRECTORY", 0.13, 0.02, (0, y + side * 0.03, 2.08), rot=(0, 0, 0 if side < 0 else math.pi),
                      m=mmat("White", 0.4, emit=1.0)))
    save("mall_directory", [merge("Directory", p)])


def build_exit_sign():
    """Wall-mounted green EXIT box (faces -Y)."""
    reset_scene()
    p = [
        box("Box", (0.9, 0.12, 0.34), (0, 0, 0), bevel=0.03, m=mmat("Charcoal", 0.5)),
        box("Face", (0.8, 0.02, 0.26), (0, -0.065, 0), bevel=0.0, m=glow("MallExitGreen", "#3fff8a", 2.2)),
        text("Text", "EXIT", 0.17, 0.02, (0.06, -0.08, -0.005), m=mmat("White", 0.4, emit=1.5)),
        prism("Arrow", [(-0.36, 0.0), (-0.24, 0.08), (-0.24, -0.08)], 0.02, (0, -0.08, 0), m=mmat("White", 0.4, emit=1.5)),
    ]
    save("mall_exit_sign", [merge("ExitSign", p)])


def build_emergency_light():
    """Twin-head emergency lamp box (faces -Y); its lamps use MallEmergency."""
    reset_scene()
    lamp = mat("MallEmergency", "#ff4a3a", rough=0.3, emit=2.0)
    p = [box("Box", (0.5, 0.14, 0.2), (0, 0, 0), bevel=0.03, m=mmat("Cream", 0.5))]
    for sx in (-0.17, 0.17):
        p.append(sphere(f"Head{sx}", 0.09, (sx, -0.12, -0.04), scale=(1, 1, 0.8), m=lamp, segs=10, rings=6))
    save("mall_emergency_light", [merge("EmergencyLight", p)])


# ---------------------------------------------------------------------------
# Window displays and store fittings
# ---------------------------------------------------------------------------

def mannequin_parts(prefix, pose, outfit, accent):
    """A smooth, faceless mannequin. pose 0 = hand on hip, 1 = waving."""
    skin = mat("MallMannequin", "#f2ece6", rough=0.35)
    ch = chrome()
    p = [
        cyl(prefix + "Base", 0.25, 0.04, (0, 0, 0.02), segs=20, bevel=0.01, m=ch),
        cyl(prefix + "Rod", 0.025, 0.85, (0, 0.03, 0.45), segs=6, bevel=0.0, m=ch),
        sphere(prefix + "Head", 0.12, (0, 0, 1.68), scale=(0.9, 1.0, 1.15), m=skin, segs=14, rings=8),
        cyl(prefix + "Neck", 0.045, 0.14, (0, 0, 1.53), segs=8, bevel=0.0, m=skin),
        box(prefix + "Torso", (0.36, 0.2, 0.5), (0, 0, 1.22), bevel=0.09, segs=3, m=outfit),
        box(prefix + "Hips", (0.34, 0.2, 0.22), (0, 0, 0.92), bevel=0.08, segs=3, m=accent),
    ]
    for s in (-1, 1):
        p.append(cyl(f"{prefix}Leg{s}", 0.07, 0.86, (s * 0.09, 0, 0.45), segs=10, bevel=0.03, m=accent if pose == 0 else skin))
        if pose == 1 and s > 0:
            p.append(tube(f"{prefix}Arm{s}", [(s * 0.2, 0, 1.42), (s * 0.34, 0, 1.6), (s * 0.36, -0.05, 1.86)], 0.045, m=skin, segs=8))
        elif s > 0:
            p.append(tube(f"{prefix}Arm{s}", [(s * 0.2, 0, 1.42), (s * 0.34, 0.03, 1.2), (s * 0.2, 0.0, 1.0)], 0.045, m=skin, segs=8))
        else:
            p.append(tube(f"{prefix}Arm{s}", [(s * 0.2, 0, 1.42), (s * 0.26, -0.02, 1.15), (s * 0.27, -0.06, 0.92)], 0.045, m=skin, segs=8))
    return p


def build_mannequins():
    """Two dressed mannequins on a low plinth (a window display)."""
    reset_scene()
    plinth = mmat("Navy", 0.4)
    p = [box("Plinth", (2.2, 1.0, 0.25), (0, 0, 0.125), bevel=0.05, m=plinth),
         box("PlinthLip", (2.24, 1.04, 0.04), (0, 0, 0.25), bevel=0.01, m=neon("Pink", MALL["Pink"], 2.4))]
    a = place(mannequin_parts("A_", 0, mmat("Pink", 0.6), mmat("Navy", 0.6)), (-0.5, 0, 0.25), 0.2)
    b = place(mannequin_parts("B_", 1, mmat("Teal", 0.6), mmat("Cream", 0.6)), (0.5, 0.05, 0.25), -0.25)
    p += a + b
    p.append(box("Bag", (0.3, 0.12, 0.3), (0.95, -0.3, 0.42), bevel=0.03, m=mmat("Yellow", 0.6)))
    save("mall_mannequins", [merge("Mannequins", p)])


def build_display_toys():
    """Toy-store window: plush bear, a tin robot, a rocket and block stacks."""
    reset_scene()
    p = [box("Plinth", (2.2, 0.9, 0.35), (0, 0, 0.175), bevel=0.05, m=mmat("Violet", 0.5))]
    bear = mat("MallBear", "#c98a5a", rough=0.8)
    p += [
        sphere("BearBody", 0.32, (-0.6, 0, 0.66), scale=(1, 0.9, 1.05), m=bear, segs=14, rings=8),
        sphere("BearHead", 0.24, (-0.6, -0.05, 1.08), m=bear, segs=14, rings=8),
        sphere("BearEarL", 0.08, (-0.78, -0.02, 1.27), m=bear, segs=8, rings=5),
        sphere("BearEarR", 0.08, (-0.42, -0.02, 1.27), m=bear, segs=8, rings=5),
        sphere("BearSnout", 0.09, (-0.6, -0.25, 1.04), m=mmat("Cream", 0.7), segs=8, rings=5),
        torus("BearBow", 0.1, 0.04, (-0.6, -0.22, 0.86), rot=rad(90, 0, 0), m=mmat("Pink", 0.5), major_segs=12, minor_segs=5),
    ]
    tin = mat("MallTinRobot", "#9fb4d8", rough=0.25, metal=0.7)
    p += [
        box("RobotBody", (0.36, 0.28, 0.42), (0.15, 0, 0.6), bevel=0.04, m=tin),
        box("RobotHead", (0.28, 0.24, 0.24), (0.15, 0, 0.95), bevel=0.04, m=tin),
        box("RobotVisor", (0.22, 0.02, 0.08), (0.15, -0.13, 0.97), bevel=0.0, m=glow("MallRobotEye", "#ff5a6a", 2.0)),
        cyl("RobotAntenna", 0.015, 0.2, (0.15, 0, 1.15), segs=6, bevel=0.0, m=tin),
        sphere("RobotBall", 0.04, (0.15, 0, 1.26), m=glow("MallRobotEye", "#ff5a6a", 2.0), segs=8, rings=5),
        box("RobotArmL", (0.08, 0.08, 0.3), (-0.07, 0, 0.62), bevel=0.02, m=tin),
        box("RobotArmR", (0.08, 0.08, 0.3), (0.37, 0, 0.62), bevel=0.02, m=tin),
    ]
    p += [
        cyl("RocketBody", 0.13, 0.55, (0.7, 0.05, 0.65), segs=14, bevel=0.03, m=mmat("Red", 0.4)),
        cyl("RocketNose", 0.13, 0.25, (0.7, 0.05, 1.05), segs=14, bevel=0.0, m=mmat("Cream", 0.5), radius_top=0.01),
    ]
    cols = ["Pink", "Teal", "Yellow", "Violet"]
    for i in range(6):
        p.append(box(f"Block{i}", (0.16, 0.16, 0.16), (0.55 + (i % 3) * 0.17, -0.3, 0.43 + (i // 3) * 0.17), bevel=0.02, m=mmat(cols[i % 4], 0.5)))
    save("mall_display_toys", [merge("DisplayToys", p)])


def build_display_tech():
    """Gadget-store window: a wall of glowing TV screens over boxed consoles."""
    reset_scene()
    p = [box("Plinth", (2.2, 0.9, 0.35), (0, 0, 0.175), bevel=0.05, m=mmat("Charcoal", 0.5))]
    shell = mat("MallTvShell", "#3a3a52", rough=0.4)
    screens = [mat(f"MallTvScreen{i}", c, rough=0.2, emit=1.6) for i, c in enumerate(("#3ff0e0", "#ff4fa8", "#8a5cff", "#ffb547"))]
    k = 0
    for row in range(2):
        for col in range(3):
            x, z = -0.7 + col * 0.7, 0.75 + row * 0.55
            p.append(box(f"Tv{k}", (0.62, 0.3, 0.48), (x, 0.2, z), bevel=0.05, m=shell))
            p.append(box(f"Screen{k}", (0.52, 0.02, 0.38), (x, 0.04, z), bevel=0.0, m=screens[(k + row) % 4]))
            k += 1
    for i in range(4):
        p.append(box(f"BoxA{i}", (0.42, 0.3, 0.2), (-0.75 + i * 0.5, -0.25, 0.45), bevel=0.02, m=mat(f"MallGameBox{i % 2}",
                                                                                                   ("#ffd23f", "#e2343f")[i % 2], rough=0.5)))
    save("mall_display_tech", [merge("DisplayTech", p)])


def build_shelf():
    """A store shelving unit (2 m) stocked with colourful boxes."""
    reset_scene()
    frame = mmat("Cream", 0.5)
    p = [box("Back", (2.0, 0.08, 2.0), (0, 0.26, 1.0), bevel=0.02, m=frame)]
    for z in (0.15, 0.7, 1.25, 1.8):
        p.append(box(f"Board{z}", (2.0, 0.5, 0.05), (0, 0.02, z), bevel=0.01, m=frame))
    rng = random.Random(12)
    cols = ["#ff86c4", "#7fe8ff", "#ffd23f", "#b48cff", "#8ff5c8", "#ff7a2a"]
    k = 0
    for z in (0.15, 0.7, 1.25):
        x = -0.92
        while x < 0.85:
            w = rng.uniform(0.18, 0.34)
            h = rng.uniform(0.2, 0.42)
            p.append(box(f"Good{k}", (w - 0.03, 0.34, h), (x + w / 2, 0.0, z + 0.025 + h / 2), bevel=0.015,
                         m=mat(f"MallGoods{k % 6}", cols[k % 6], rough=0.6)))
            x += w
            k += 1
    save("mall_shelf", [merge("Shelf", p)])


def build_stall():
    """Food-court stall front, 6 m wide and 4 m deep: counter, menu boards
    glowing on the back wall, a fascia with a neon trim (MallAccent, tinted
    per stall), a drinks fridge and a fryer. Faces -Y; the level adds the
    stall's name above it."""
    reset_scene()
    accent, cream, ch = mat("MallAccent", MALL["Pink"], rough=0.45), mmat("Cream", 0.5), chrome()
    dark = mmat("Charcoal", 0.6)
    tile = mat("MallStallTile", "#f3e6e0", rough=0.4)
    menu = mat("MallMenuBoard", "#ffe9b0", rough=0.3, emit=1.4)
    p = [
        box("Counter", (5.0, 0.8, 1.05), (0, -1.6, 0.525), bevel=0.05, m=accent),
        box("CounterTop", (5.2, 0.95, 0.07), (0, -1.6, 1.08), bevel=0.02, m=ch),
        box("CounterBand", (5.02, 0.02, 0.12), (0, -2.01, 0.85), bevel=0.0, m=cream),
        box("BackWall", (6.0, 0.2, 3.5), (0, 1.9, 1.75), bevel=0.02, m=tile),
        box("Floor", (6.0, 4.0, 0.04), (0, 0, 0.02), bevel=0.0, m=mat("MallStallFloor", "#c9b8b0", rough=0.6)),
        box("Ceiling", (6.0, 4.0, 0.12), (0, 0, 3.54), bevel=0.0, m=cream),
        box("Fridge", (1.1, 0.7, 2.0), (2.2, 1.4, 1.0), bevel=0.05, m=ch),
        box("FridgeGlass", (0.95, 0.02, 1.7), (2.2, 1.04, 1.05), bevel=0.0, m=glow("MallFridgeGlow", "#bff6ff", 1.1)),
        box("Fryer", (1.4, 0.7, 0.95), (-1.6, 1.4, 0.475), bevel=0.04, m=ch),
        box("Hood", (1.6, 0.9, 0.5), (-1.6, 1.35, 2.85), bevel=0.05, m=ch),
        box("Register", (0.4, 0.35, 0.25), (1.6, -1.6, 1.25), bevel=0.04, m=dark),
        box("RegisterScreen", (0.3, 0.02, 0.18), (1.6, -1.8, 1.32), rot=rad(-15, 0, 0), bevel=0.0, m=glow("MallTvScreen0", "#3ff0e0", 1.6)),
        box("NapkinBox", (0.2, 0.2, 0.2), (-1.8, -1.6, 1.21), bevel=0.03, m=mmat("White", 0.5)),
    ]
    for i in range(3):
        x = -1.6 + i * 1.6
        p.append(box(f"Menu{i}", (1.4, 0.06, 0.7), (x, 1.76, 2.55), bevel=0.02, m=menu))
    p.append(box("Fascia", (6.0, 0.4, 0.8), (0, -2.0, 3.98), bevel=0.04, m=dark))
    p.append(box("FasciaTrim", (6.0, 0.06, 0.08), (0, -2.22, 3.62), bevel=0.0, m=mat("MallNeonAccent", MALL["Pink"], rough=0.3, emit=2.6)))
    p.append(box("FasciaTrimTop", (6.0, 0.06, 0.08), (0, -2.22, 4.34), bevel=0.0, m=mat("MallNeonAccent", MALL["Pink"], rough=0.3, emit=2.6)))
    for sx in (-1, 1):
        p.append(box(f"Pillar{sx}", (0.3, 0.4, 3.6), (sx * 2.85, -1.9, 1.8), bevel=0.05, m=cream))
        p.append(box(f"SideWall{sx}", (0.2, 4.0, 3.5), (sx * 2.9, 0, 1.75), bevel=0.0, m=tile))
    # Trays of food on the counter.
    for i, c in enumerate(("#ffb547", "#e2343f", "#8ff5c8")):
        p.append(box(f"TrayFood{i}", (0.35, 0.25, 0.08), (-0.9 + i * 0.6, -1.6, 1.16), bevel=0.02, m=mat(f"MallFood{i}", c, rough=0.6)))
    save("mall_stall", [merge("Stall", p)])


def build_elevator_cab():
    """The round glass elevator cab: chrome floor and roof discs, glass walls,
    a light ring and a moon badge. Origin at the cab floor centre."""
    reset_scene()
    ch, gl = chrome(), glass("MallCabGlass", "#bfe8ff", alpha=0.3, emit=0.15)
    ring = neon("Pink", MALL["Pink"], 2.6)
    p = [
        cyl("Floor", 1.35, 0.25, (0, 0, 0.12), segs=32, bevel=0.05, m=ch),
        cyl("Roof", 1.35, 0.3, (0, 0, 2.75), segs=32, bevel=0.06, m=ch),
        cyl("RoofDome", 0.9, 0.35, (0, 0, 3.05), segs=24, bevel=0.05, m=mmat("Teal", 0.4), radius_top=0.4),
        torus("LightRing", 1.36, 0.05, (0, 0, 2.6), m=ring, major_segs=40, minor_segs=6),
        torus("FloorRing", 1.36, 0.04, (0, 0, 0.26), m=neon("Teal", "#3ff0e0", 2.6), major_segs=40, minor_segs=6),
        cyl("Walls", 1.28, 2.35, (0, 0, 1.43), segs=32, bevel=0.0, m=gl),
        tube("HandRail", arc_points(1.2, 200, 340, 12, plane="XY", centre=(0, 0, 1.0)), 0.03, m=ch, segs=6),
    ]
    for i in range(6):
        a = math.tau * i / 6
        p.append(cyl(f"Mullion{i}", 0.04, 2.35, (math.cos(a) * 1.3, math.sin(a) * 1.3, 1.43), segs=6, bevel=0.0, m=ch))
    save("mall_elevator_cab", [merge("Cab", p)])


def build_cinema_doors():
    """The Starplex cinema lobby front (8 m wide, 4.6 m tall): chrome doors with
    porthole windows, poster light boxes and a marquee canopy with chasing bulbs.
    Faces -Y; the doorway (x +-1.6, 3 m tall) stays open for zombies."""
    reset_scene()
    navy, ch, vio = mmat("Navy", 0.4), chrome(), mmat("Violet", 0.4)
    bulb_m = glow("MallBulbWarm", "#ffd27a", 3.0)
    posters = [mat(f"MallPoster{i}", c, rough=0.3, emit=1.3) for i, c in enumerate(("#ff4fa8", "#3ff0e0", "#ffb547", "#8a5cff"))]
    p = [
        box("WallL", (2.3, 0.4, 4.6), (-2.75, 0, 2.3), bevel=0.04, m=navy),
        box("WallR", (2.3, 0.4, 4.6), (2.75, 0, 2.3), bevel=0.04, m=navy),
        box("Lintel", (3.2, 0.4, 1.6), (0, 0, 3.8), bevel=0.04, m=navy),
        box("Marquee", (8.2, 1.4, 0.5), (0, -0.7, 3.35), bevel=0.08, m=vio),
        box("MarqueeFace", (8.0, 0.04, 0.32), (0, -1.42, 3.35), bevel=0.0, m=mat("MallMarquee", "#fff2dc", rough=0.3, emit=1.0)),
    ]
    for i in range(26):
        p.append(bulb(f"Chase{i:02d}", 0.05, (-4.0 + i * 0.32, -1.46, 3.6), bulb_m))
        p.append(bulb(f"ChaseLow{i:02d}", 0.05, (-4.0 + i * 0.32, -1.46, 3.1), bulb_m))
    for i, sx in enumerate((-3.2, -2.3, 2.3, 3.2)):
        p.append(box(f"PosterFrame{i}", (0.8, 0.1, 1.2), (sx, -0.25, 1.5), bevel=0.03, m=ch))
        p.append(box(f"Poster{i}", (0.66, 0.02, 1.04), (sx, -0.31, 1.5), bevel=0.0, m=posters[i]))
    save("mall_cinema_doors", [merge("CinemaDoors", p)])


# ---------------------------------------------------------------------------
# Loadout station: the Guest Services kiosk
# ---------------------------------------------------------------------------

STATION_HINGE = (0.0, -2.32, 2.55)
STATION_CLOSED = 0.0
STATION_OPEN = -72.0


def build_station():
    """Guest Services: a round two-tier info kiosk under a flying-saucer canopy
    on a chrome column, with a spinning hologram moon on top, monitors,
    brochure racks and a counter ring. Nodes:
        Station       the kiosk
        Shutter       the front service shutter, pivot on its hinge (closed pose)
        OpenDressing  neon OPEN sign and the counter goods (shown while open)
        ClosedSign    a CLOSED board (shown while closed)
        SpinMoon      the hologram moon (the level turns it)"""
    reset_scene()
    pink, teal, cream, navy, vio = mmat("Pink", 0.4), mmat("Teal", 0.4), mmat("Cream", 0.45), mmat("Navy", 0.4), mmat("Violet", 0.4)
    ch = chrome()
    neon_p, neon_t = neon("Pink", MALL["Pink"], 3.0), neon("Teal", "#3ff0e0", 3.0)
    bulb_m = glow("MallBulbWarm", "#ffd27a", 3.0)
    screen = mat("MallTvScreen0", "#3ff0e0", rough=0.2, emit=1.6)
    p = [
        cyl("Plinth", 2.9, 0.18, (0, 0, 0.09), segs=48, bevel=0.05, m=navy),
        ring_wall("Counter", 1.95, 2.35, 0.18, 1.1, teal, segs=48),
        torus("CounterTop", 2.15, 0.24, (0, 0, 1.12), m=cream, major_segs=48, minor_segs=8),
        torus("CounterNeon", 2.37, 0.035, (0, 0, 0.75), m=neon_p, major_segs=48, minor_segs=6),
        torus("KickNeon", 2.37, 0.03, (0, 0, 0.3), m=neon_t, major_segs=48, minor_segs=6),
        cyl("Column", 0.45, 3.2, (0, 0, 1.6), segs=24, bevel=0.04, m=ch),
        cyl("InnerDesk", 0.95, 0.9, (0, 0, 0.6), segs=32, bevel=0.05, m=vio),
        # Saucer canopy.
        cyl("SaucerLow", 2.6, 0.35, (0, 0, 3.35), segs=48, bevel=0.1, m=cream, radius_top=3.1),
        cyl("SaucerUp", 3.1, 0.45, (0, 0, 3.75), segs=48, bevel=0.1, m=pink, radius_top=1.6),
        torus("SaucerRim", 3.1, 0.09, (0, 0, 3.53), m=neon_t, major_segs=56, minor_segs=6),
        cyl("SaucerDome", 1.6, 0.6, (0, 0, 4.25), segs=36, bevel=0.15, m=teal, radius_top=0.7),
        cyl("Mast", 0.08, 0.9, (0, 0, 4.9), segs=8, bevel=0.0, m=ch),
    ]
    for i in range(28):
        a = math.tau * i / 28
        p.append(bulb(f"Bulb{i:02d}", 0.07, (math.cos(a) * 2.75, math.sin(a) * 2.75, 3.15), bulb_m))
    # Monitors on swing arms, brochure racks and a sign band round the column.
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        c, s = math.cos(a), math.sin(a)
        p.append(box(f"Monitor{i}", (0.6, 0.12, 0.42), (c * 1.35, s * 1.35, 1.7), rot=(math.radians(-10), 0, a + math.pi / 2), bevel=0.04, m=navy))
        p.append(box(f"MonitorScreen{i}", (0.5, 0.02, 0.32), (c * 1.42, s * 1.42, 1.7), rot=(math.radians(-10), 0, a + math.pi / 2), bevel=0.0,
                     m=screen))
        p.append(tube(f"MonitorArm{i}", [(c * 0.45, s * 0.45, 1.9), (c * 1.3, s * 1.3, 1.75)], 0.03, m=ch, segs=6))
        p.append(box(f"Rack{i}", (0.7, 0.25, 0.6), (math.cos(a + 0.78) * 2.62, math.sin(a + 0.78) * 2.62, 0.5),
                     rot=(0, 0, a + 0.78 + math.pi / 2), bevel=0.04, m=ch))
        for k in range(3):
            p.append(box(f"Brochure{i}{k}", (0.18, 0.04, 0.26), (math.cos(a + 0.78) * 2.75 + 0, math.sin(a + 0.78) * 2.75, 0.68),
                         rot=(math.radians(-12), 0, a + 0.78 + math.pi / 2 + (k - 1) * 0.0), bevel=0.0,
                         m=[pink, teal, mmat("Yellow", 0.5)][k]))
    for i, word in enumerate(("GUEST", "SERVICES")):
        a = math.pi * i
        p.append(text(f"Band{i}", word, 0.28, 0.04, (math.sin(a) * 2.95, -math.cos(a) * 2.95, 3.33), rot=(0, 0, a), m=mmat("White", 0.4, emit=1.2)))
    # Side signs at +-90 degrees.
    for i in (1, -1):
        p.append(text(f"BandSide{i}", "INFO", 0.3, 0.04, (i * 2.95, 0, 3.33), rot=(0, 0, i * math.pi / 2), m=mmat("White", 0.4, emit=1.2)))
    station = merge("Station", p)

    # Hologram moon (turned by the level), on the mast.
    moon = merge("SpinMoon", [
        sphere("Holo", 0.55, (0, 0, 5.85), m=mat("MallHoloMoon", "#bff6ff", rough=0.2, emit=1.8), segs=20, rings=12),
        torus("HoloRing", 0.9, 0.04, (0, 0, 5.85), rot=rad(18, 0, 0), m=neon_p, major_segs=40, minor_segs=6),
    ], pivot=(0, 0, 5.85))

    # Front service shutter: hangs from the hinge down to the counter top.
    hy, hz = STATION_HINGE[1], STATION_HINGE[2]
    length = hz - 1.25
    sp = [box("ShutterPanel", (2.2, 0.06, length), (0, hy, hz - length / 2), bevel=0.02, m=navy)]
    for k in range(int(length / 0.18)):
        sp.append(box(f"ShutterSlat{k}", (2.18, 0.02, 0.05), (0, hy - 0.04, hz - 0.12 - k * 0.18), bevel=0.0, m=vio))
    sp.append(box("ShutterBar", (2.26, 0.1, 0.1), (0, hy - 0.02, hz - length + 0.05), bevel=0.03, m=ch))
    shutter = merge("Shutter", sp, pivot=STATION_HINGE)
    # A canopy arch carries the shutter's hinge across the front.
    hinge_frame = [box("HingeBeam", (2.5, 0.16, 0.16), (0, hy, hz + 0.08), bevel=0.04, m=ch)]
    for sx in (-1.18, 1.18):
        hinge_frame.append(box(f"HingePost{sx}", (0.1, 0.1, hz - 0.18), (sx, hy, 0.18 + (hz - 0.18) / 2), bevel=0.02, m=ch))
    frame = merge("ShutterFrame", hinge_frame)

    open_d = merge("OpenDressing", [
        box("OpenBack", (1.0, 0.06, 0.38), (0, -2.0, 2.05), bevel=0.04, m=navy),
        text("OpenText", "OPEN", 0.27, 0.03, (0, -2.05, 2.04), m=neon("Mint", "#8ff5c8", 3.4)),
        cyl("OpenChainL", 0.01, 0.32, (-0.4, -2.0, 2.4), segs=4, bevel=0.0, m=ch),
        cyl("OpenChainR", 0.01, 0.32, (0.4, -2.0, 2.4), segs=4, bevel=0.0, m=ch),
        box("Goods0", (0.3, 0.22, 0.2), (-0.6, -2.15, 1.32), bevel=0.03, m=pink),
        box("Goods1", (0.25, 0.2, 0.32), (0.55, -2.12, 1.38), bevel=0.03, m=teal),
        cyl("Goods2", 0.1, 0.24, (0.15, -2.15, 1.34), segs=12, bevel=0.02, m=mmat("Yellow", 0.5)),
    ])
    closed = merge("ClosedSign", [
        box("ClosedBoard", (1.1, 0.04, 0.34), (0, hy - 0.07, hz - 0.6), bevel=0.02, m=cream),
        text("ClosedText", "CLOSED", 0.2, 0.02, (0, hy - 0.1, hz - 0.61), m=mmat("Red", 0.5)),
    ])
    save("mall_station", [station, moon, shutter, frame, open_d, closed])


# ---------------------------------------------------------------------------
# Exit portal arch: a chrome-and-neon mall exit with a moon keystone
# ---------------------------------------------------------------------------

def build_portal_arch():
    """Retro mall exit: chrome jambs with neon pink and teal tubes following the
    doorway, a big moon keystone, star rivets and a lit EXIT box. Faces -Y."""
    reset_scene()
    ch, navy, cream = chrome(), mmat("Navy", 0.4), mmat("Cream", 0.45)
    pink, teal = neon("Pink", MALL["Pink"], 3.2), neon("Teal", "#3ff0e0", 3.2)
    p = []
    for s in (-1, 1):
        p.append(box(f"Jamb{s}", (0.7, 0.8, 2.3), (s * (wp.OPEN_W + 0.38), 0, 1.15), bevel=0.12, segs=3, m=navy))
        p.append(box(f"JambFace{s}", (0.5, 0.06, 2.1), (s * (wp.OPEN_W + 0.38), -0.42, 1.15), bevel=0.02, m=ch))
        p.append(box(f"Foot{s}", (0.95, 1.0, 0.18), (s * (wp.OPEN_W + 0.38), 0, 0.09), bevel=0.05, m=ch))
    for i in range(11):
        a = 180.0 * (i + 0.5) / 11
        p.append(wp.block_on_arc(f"Vous{i}", wp.OPEN_W + 0.38, wp.OPEN_RISE + 0.38, a, (0.55, 0.8, 0.62), navy if i % 2 else cream, bevel=0.08))
    for k, (grow, m) in enumerate(((0.08, pink), (0.62, teal))):
        pts = wp.arch_path(wp.OPEN_W + grow, wp.OPEN_RISE + grow, steps=28, base=0.15, y=-0.46)
        p.append(tube(f"Neon{k}", pts, 0.045, m=m, segs=8))
    p.append(sphere("Moon", 0.48, (0, -0.2, wp.OPEN_SPRING + wp.OPEN_RISE + 0.75), m=mat("MallMoonGlobe", MALL["Moon"], rough=0.3, emit=0.9),
                    segs=20, rings=12))
    p.append(torus("MoonRing", 0.72, 0.045, (0, -0.2, wp.OPEN_SPRING + wp.OPEN_RISE + 0.75), rot=rad(70, 15, 0), m=pink,
                   major_segs=36, minor_segs=6))
    p.append(box("ExitBox", (1.3, 0.2, 0.42), (0, -0.48, wp.OPEN_SPRING + wp.OPEN_RISE + 0.05), bevel=0.04, m=mmat("Charcoal", 0.5)))
    p.append(text("ExitText", "EXIT", 0.3, 0.03, (0, -0.6, wp.OPEN_SPRING + wp.OPEN_RISE + 0.04), m=glow("MallExitGreen", "#3fff8a", 2.6)))
    for s in (-1, 1):
        for z in (0.5, 1.2, 1.9):
            p.append(star(f"Rivet{s}{z}", 0.09, 0.03, (s * (wp.OPEN_W + 0.38), -0.47, z), m=mat("MallStarGold", MALL["Yellow"], rough=0.3, emit=1.2)))
    p.append(wp.backing("Back", navy, y=0.3))
    save("mall_portal_arch", [merge("PortalArch", p)])


BUILDERS = {
    "fountain": build_fountain, "escalator": build_escalator, "escalator_dead": build_escalator_dead,
    "carousel": build_carousel, "kiddie_rocket": build_kiddie_rocket, "kiddie_car": build_kiddie_car,
    "palm": build_palm, "bench": build_bench, "table_set": build_table_set, "bin": build_bin, "cart": build_cart,
    "security_gate": build_security_gate, "directory": build_directory, "exit_sign": build_exit_sign,
    "emergency_light": build_emergency_light, "mannequins": build_mannequins, "display_toys": build_display_toys,
    "display_tech": build_display_tech, "shelf": build_shelf, "stall": build_stall, "elevator_cab": build_elevator_cab,
    "cinema_doors": build_cinema_doors, "station": build_station, "portal_arch": build_portal_arch,
}


if __name__ == "__main__":
    wanted = [a for a in sys.argv[1:] if a in BUILDERS] or list(BUILDERS)
    for key in wanted:
        BUILDERS[key]()
