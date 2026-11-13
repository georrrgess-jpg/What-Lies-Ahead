"""Sky Carnival loadout station and exit portal (World 10, Sky Harbor).

    sky_station.glb        "Cloud Nine Supply": a round striped kiosk (radius 2.3 m,
                           walls 2.9 m) with a service window facing -Y, a scalloped
                           canopy and, tethered above it, a red-and-cream hot-air
                           balloon (the station's landmark, top at ~12 m).
        Station        the kiosk and balloon (static)
        Shutter        the striped window shutter, pivot on its hinge, exported in
                       its closed pose (SHUTTER_CLOSED); the scene opens it to -70
        OpenDressing   the glowing OPEN board and the shutter stays (open only)
        ClosedSign     the "BACK SOON" card on the shutter (closed only)
    sky_portal_arch.glb    the exit: the shared portal doorway framed by striped
                           pillars with balloon bunches, a sunburst crown, a cloud
                           cartouche and a lit EXIT board.

    python art/blender/build_sky_station.py [station] [portal]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sky_common import *  # noqa: F401,F403
import build_world_portals as wp  # noqa: E402

R = 2.3                 # kiosk radius
WALL_H = 2.9
COUNTER_TOP = 1.1
WIN_TOP = 2.45
HINGE = (0.0, -R - 0.12, WIN_TOP + 0.1)
SHUTTER_LEN = 1.4
SHUTTER_W = 2.4
SHUTTER_CLOSED = -10.0
SHUTTER_OPEN = -70.0
BALLOON_Z = 7.0         # bottom of the envelope


def kiosk():
    red, cream, navy, gold, teal = smat("Red", rough=0.45), smat("Cream"), smat("Navy"), smat("Gold", rough=0.35), smat("Teal", rough=0.45)
    p = [cyl("Plinth", R + 0.35, 0.25, (0, 0, 0.125), segs=28, bevel=0.05, m=navy),
         cyl("PlinthTrim", R + 0.38, 0.06, (0, 0, 0.26), segs=28, bevel=0.0, m=gold)]
    # Striped wall with the service window cut out of the front (-Y) sector.
    win_half = math.radians(36)
    n = 28
    bm = bmesh.new()
    for i in range(n):
        a0 = math.tau * i / n - math.pi / 2
        a1 = math.tau * (i + 1) / n - math.pi / 2
        mid = (a0 + a1) / 2 + math.pi / 2
        in_window = abs(math.atan2(math.sin(mid), math.cos(mid))) < win_half
        spans = [(0.25, COUNTER_TOP), (WIN_TOP, WALL_H)] if in_window else [(0.25, WALL_H)]
        for z0, z1 in spans:
            vs = [bm.verts.new((math.cos(a) * R, math.sin(a) * R, z)) for a, z in ((a0, z0), (a1, z0), (a1, z1), (a0, z1))]
            f = bm.faces.new(vs)
            f.material_index = i % 2
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.xy.dot(f.calc_center_median().xy) < 0:
            f.normal_flip()
    p.append(finish_multi("Wall", bm, [red, cream], smooth=False))
    p += [cyl("Inner", R - 0.15, WALL_H - 0.3, (0, 0, WALL_H / 2), segs=24, bevel=0.0, m=navy),
          cyl("Counter", R + 0.12, 0.1, (0, 0, COUNTER_TOP), segs=28, bevel=0.03, m=smat("WoodLight", rough=0.7)),
          torus("WallTop", R + 0.05, 0.09, (0, 0, WALL_H), m=gold, major_segs=28, minor_segs=5)]
    # Canopy: a scalloped striped cone.
    canopy = lathe("Canopy", [(R + 0.9, WALL_H + 0.25), (1.4, WALL_H + 0.95), (0.2, WALL_H + 1.5)], [red, cream], segs=20, stripes=1, smooth=False,
                   cap_bottom=False, cap_top=False)
    double_sided(canopy)
    p.append(canopy)
    for k in range(20):
        a = math.tau * (k + 0.5) / 20
        p.append(cyl(f"Scallop{k}", 0.38, 0.04, (math.cos(a) * (R + 0.92), math.sin(a) * (R + 0.92), WALL_H + 0.2), rot=(math.pi / 2, 0, a + math.pi / 2),
                     segs=10, bevel=0.0, m=gold if k % 2 else red))
    # Sign over the window.
    p += [box("SignBoard", (2.9, 0.16, 0.56), (0, -R - 0.75, WALL_H + 0.5), rot=(math.radians(-10), 0, 0), bevel=0.05, m=navy),
          box("SignTrim", (3.05, 0.1, 0.68), (0, -R - 0.7, WALL_H + 0.5), rot=(math.radians(-10), 0, 0), bevel=0.04, m=gold),
          text("SignText", "CLOUD NINE SUPPLY", 0.27, 0.05, (0, -R - 0.85, WALL_H + 0.48), rot=(math.radians(-10), 0, 0), m=smat("Gold", rough=0.3))]
    bulb_m = sglow("SkyBulb", "#ffe2a0", 3.0)
    for k in range(16):
        a = math.tau * k / 16
        p.append(bulb(f"Bulb{k}", 0.07, (math.cos(a) * (R + 0.95), math.sin(a) * (R + 0.95), WALL_H + 0.02), bulb_m))
    # Tethered balloon above, ropes down to the canopy rim.
    a_m, b_m = smat("Red", rough=0.5), smat("Cream")
    prof = [(0.8, BALLOON_Z), (2.0, BALLOON_Z + 1.0), (2.9, BALLOON_Z + 2.4), (3.1, BALLOON_Z + 3.4), (2.7, BALLOON_Z + 4.4), (1.6, BALLOON_Z + 5.0),
            (0.2, BALLOON_Z + 5.3)]
    p.append(lathe("Envelope", prof, [a_m, b_m], segs=20, stripes=1, smooth=True, cap_bottom=False))
    p += [torus("EnvBand", 3.12, 0.1, (0, 0, BALLOON_Z + 3.4), m=teal, major_segs=28, minor_segs=4),
          torus("EnvSkirt", 0.82, 0.07, (0, 0, BALLOON_Z), m=navy, major_segs=16, minor_segs=4),
          cyl("Mast", 0.1, BALLOON_Z - WALL_H - 1.2, (0, 0, (BALLOON_Z + WALL_H + 1.2) / 2), segs=8, bevel=0.0, m=gold)]
    for k in range(6):
        a = math.tau * k / 6
        p.append(tube(f"Tether{k}", [(math.cos(a) * (R + 0.6), math.sin(a) * (R + 0.6), WALL_H + 0.4), (math.cos(a) * 0.8, math.sin(a) * 0.8, BALLOON_Z)],
                      0.025, m=smat("Rope", rough=0.9), segs=4))
    p += [box("BackWall", (2.6, 0.1, 1.2), (0, 0.3, COUNTER_TOP + 0.65), bevel=0.02, m=navy)]
    return p


def goods():
    teal_glow = sglow("SkyCellGlow", "#5ff0e6", 2.4)
    pink, cream, gold, navy = smat("Pink", rough=0.8), smat("Cream"), smat("Gold", rough=0.35), smat("Navy")
    y = -R - 0.05
    p = [box("AmmoA", (0.62, 0.42, 0.34), (-1.05, y + 0.25, COUNTER_TOP + 0.22), bevel=0.04, m=smat("SteelDark", rough=0.4)),
         box("AmmoStripe", (0.64, 0.44, 0.08), (-1.05, y + 0.25, COUNTER_TOP + 0.27), bevel=0.01, m=smat("Gold", rough=0.4))]
    for k in range(3):
        p.append(cyl(f"Cell{k}", 0.08, 0.3, (0.55 + k * 0.2, y + 0.3, COUNTER_TOP + 0.2), segs=8, bevel=0.02, m=teal_glow))
    # Cotton-candy clouds on sticks (the heal).
    for k in range(3):
        x = -0.35 + k * 0.3
        p += [cyl(f"Stick{k}", 0.015, 0.4, (x, y + 0.2, COUNTER_TOP + 0.2), segs=4, bevel=0.0, m=cream),
              sphere(f"Candy{k}", 0.15, (x, y + 0.2, COUNTER_TOP + 0.48), scale=(1, 1, 0.85), m=pink if k != 1 else smat("Sky", rough=0.8), segs=10, rings=6)]
    # Freight round the kiosk.
    p += [box("CrateA", (0.9, 0.9, 0.8), (R + 0.3, 1.2, 0.4), rot=(0, 0, 0.4), bevel=0.05, m=smat("WoodLight", rough=0.75)),
          box("CrateB", (0.7, 0.7, 0.6), (R + 0.2, 1.2, 1.1), rot=(0, 0, 0.2), bevel=0.05, m=smat("WoodLight", rough=0.75)),
          star("CrateStar", 0.2, 0.02, (R + 0.55, 0.85, 0.42), rot=(math.pi / 2, 0, 0.4 + math.pi / 2), m=smat("Red", rough=0.5)),
          cyl("Barrel", 0.32, 0.8, (-R - 0.35, 1.0, 0.4), segs=12, bevel=0.04, m=smat("Teal", rough=0.45))]
    p += balloon_bunch("Bunch", (-R - 0.35, 1.0, 0.85), count=6, spread=0.35, height=0.9, radius=0.18, seed=7)
    return p


def shutter():
    L = SHUTTER_LEN
    p = [box("Panel", (SHUTTER_W, 0.06, L), (0, 0.0, -L / 2), bevel=0.02, m=smat("Cream"))]
    for k in range(6):
        p.append(box(f"Stripe{k}", (SHUTTER_W / 6 - 0.02, 0.07, L - 0.04), (-SHUTTER_W / 2 + (k + 0.5) * SHUTTER_W / 6, -0.005, -L / 2), bevel=0.0,
                     m=smat("Red", rough=0.45) if k % 2 == 0 else smat("Cream")))
    p.append(box("Edge", (SHUTTER_W + 0.06, 0.09, 0.08), (0, -0.01, -L + 0.04), bevel=0.02, m=smat("Gold", rough=0.35)))
    ob = merge("Shutter", p, pivot=(0, 0, 0))
    ob.location = HINGE
    ob.rotation_euler = (math.radians(SHUTTER_CLOSED), 0, 0)
    return ob


def open_dressing():
    neon = sglow("SkyNeonOpen", "#5ff0e6", 3.2)
    p = [box("OpenBack", (0.9, 0.06, 0.32), (0, -R - 0.25, WIN_TOP - 0.25), bevel=0.03, m=smat("Navy")),
         text("OpenText", "OPEN", 0.22, 0.03, (0, -R - 0.3, WIN_TOP - 0.26), m=neon)]
    a = math.radians(SHUTTER_OPEN)
    d = SHUTTER_LEN - 0.1
    ey, ez = HINGE[1] - d * math.sin(-a), HINGE[2] - d * math.cos(a)
    for i, sx in enumerate((-1, 1)):
        p.append(tube(f"Stay{i}", [(sx * (SHUTTER_W / 2 - 0.2), -R - 0.25, COUNTER_TOP + 0.05), (sx * (SHUTTER_W / 2 - 0.2), ey, ez)], 0.03,
                      m=smat("Gold", rough=0.35), segs=5))
    return merge("OpenDressing", p)


def closed_sign():
    a = math.radians(SHUTTER_CLOSED)
    d = 0.7
    ny, nz = -math.cos(a), -math.sin(a)
    cy = HINGE[1] + d * math.sin(a) + ny * 0.06
    cz = HINGE[2] - d * math.cos(a) + nz * 0.06
    p = [box("ClosedCard", (1.2, 0.04, 0.34), (0, cy, cz), rot=(a, 0, 0), bevel=0.02, m=smat("Navy")),
         text("ClosedText", "BACK SOON", 0.19, 0.02, (0, cy + ny * 0.03, cz + nz * 0.03 - 0.01), rot=(a, 0, 0), m=smat("Gold", rough=0.3))]
    return merge("ClosedSign", p)


def build_station():
    reset_scene()
    station = merge("Station", kiosk() + goods())
    save("sky_station", [station, shutter(), open_dressing(), closed_sign()])


def build_portal():
    reset_scene()
    red, cream, navy, gold, teal = smat("Red", rough=0.45), smat("Cream"), smat("Navy"), smat("Gold", rough=0.35), smat("Teal", rough=0.45)
    p = []
    # Striped pillars with gold caps and balloon bunches.
    for s in (-1, 1):
        x = s * (wp.OPEN_W + 0.5)
        p.append(cyl(f"Pillar{s}", 0.42, 3.6, (x, 0, 1.8), segs=14, bevel=0.06, m=cream))
        for k in range(5):
            p.append(cyl(f"Band{s}{k}", 0.44, 0.22, (x, 0, 0.5 + k * 0.7), segs=14, bevel=0.0, m=red if k % 2 == 0 else teal))
        p += [cyl(f"Base{s}", 0.6, 0.4, (x, 0, 0.2), segs=14, bevel=0.06, m=navy),
              cyl(f"Cap{s}", 0.55, 0.25, (x, 0, 3.7), segs=14, bevel=0.06, m=gold),
              sphere(f"Ball{s}", 0.3, (x, 0, 4.1), m=gold, segs=10, rings=6)]
        p += balloon_bunch(f"BB{s}", (x + s * 0.2, -0.1, 4.2), count=6, spread=0.45, height=1.0, radius=0.22, seed=3 + s)
    # Arch: a gold tube with a cloud cartouche and a sunburst crown.
    hw, rise = wp.OPEN_W + 0.5, wp.OPEN_RISE + 0.5
    p.append(tube("Arch", wp.arc_only(hw, rise, steps=24, y=0.0), 0.2, m=gold, segs=10))
    top = wp.OPEN_SPRING + rise
    for k in range(13):
        a = math.radians(180.0 * k / 12)
        length = 1.3 if k % 2 == 0 else 0.9
        x0, z0 = math.cos(a) * 0.9, top + 0.5 + math.sin(a) * 0.9
        p.append(prism(f"Ray{k}", [(-0.12, 0), (0.12, 0), (0, length)], 0.08, (x0, 0.05, z0), rot=(0, math.pi / 2 - a, 0),
                       m=gold if k % 2 == 0 else smat("Peach")))
    p.append(cyl("Sun", 0.95, 0.2, (0, 0.0, top + 0.5), rot=rad(90, 0, 0), segs=20, bevel=0.05, m=smat("Gold", rough=0.3)))
    for k, (x, z, r) in enumerate(((-0.75, top - 0.05, 0.55), (0.0, top + 0.05, 0.7), (0.75, top - 0.05, 0.55), (-0.35, top + 0.35, 0.5), (0.4, top + 0.3, 0.5))):
        p.append(sphere(f"Cloud{k}", r, (x, -0.12, z), scale=(1, 0.5, 0.8), m=smat("White"), segs=12, rings=7))
    p += [box("Board", (1.3, 0.1, 0.42), (0, -0.45, wp.OPEN_SPRING + 0.95), bevel=0.04, m=navy),
          text("BoardText", "EXIT", 0.3, 0.03, (0, -0.52, wp.OPEN_SPRING + 0.93), m=sglow("SkyExitText", "#5ff0e6", 2.4))]
    p += pennants("Pen", (-hw - 0.1, -0.2, 3.7), (hw + 0.1, -0.2, 3.7), 9, 0.35, [red, gold, teal], size=0.26)
    p.append(wp.backing("Back", smat("NavyDark")))
    save("sky_portal_arch", [merge("PortalArch", p)])


if __name__ == "__main__":
    wanted = sys.argv[1:] or ["station", "portal"]
    if "station" in wanted:
        build_station()
    if "portal" in wanted:
        build_portal()
