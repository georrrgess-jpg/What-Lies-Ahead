"""Fright Fair loadout station and exit portal (World 11, Ghost Train).

    fright_station.glb     "Creeps & Treats": a fortune-teller's hexagonal booth
                           (radius 2.3 m, walls 2.9 m) in violet and ink stripes, a
                           service window facing -Y, a crooked witch-hat canopy and,
                           on top, a skeletal claw holding a glowing green crystal
                           ball (the station's landmark, top at ~9 m).
        Station        the booth, canopy and crystal ball (static)
        Shutter        the striped window shutter, pivot on its hinge, exported in
                       its closed pose (SHUTTER_CLOSED); the scene opens it to -70
        OpenDressing   the glowing OPEN board and the shutter stays (open only)
        ClosedSign     the "BACK AT MIDNIGHT" card on the shutter (closed only)
    fright_portal_arch.glb the exit: the shared portal doorway framed by an arch of
                           stacked bones with a grinning skull keystone, pumpkin
                           lanterns on the pillars, bats and a lit EXIT board.

    python art/blender/build_fright_station.py [station] [portal]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fright_common import *  # noqa: F401,F403
import build_world_portals as wp  # noqa: E402

R = 2.3
WALL_H = 2.9
COUNTER_TOP = 1.1
WIN_TOP = 2.45
HINGE = (0.0, -R - 0.12, WIN_TOP + 0.1)
SHUTTER_LEN = 1.4
SHUTTER_W = 2.4
SHUTTER_CLOSED = -10.0
SHUTTER_OPEN = -70.0
BALL_Z = 7.6


def booth():
    violet, ink, orange, gold, night = fmat("Purple", rough=0.5), fmat("Ink"), fmat("Orange", rough=0.5), fmat("Gold", rough=0.35, metal=0.4), fmat("Night")
    bone = fmat("Bone", rough=0.5)
    p = [cyl("Plinth", R + 0.35, 0.25, (0, 0, 0.125), segs=6, bevel=0.05, m=night, rot=(0, 0, math.pi / 6)),
         cyl("PlinthTrim", R + 0.38, 0.06, (0, 0, 0.26), segs=6, bevel=0.0, m=gold, rot=(0, 0, math.pi / 6))]
    win_half = math.radians(36)
    n = 24
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
            f.material_index = (i // 2) % 2
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.xy.dot(f.calc_center_median().xy) < 0:
            f.normal_flip()
    p.append(finish_multi("Wall", bm, [violet, ink], smooth=False))
    p += [cyl("Inner", R - 0.15, WALL_H - 0.3, (0, 0, WALL_H / 2), segs=24, bevel=0.0, m=night),
          cyl("Counter", R + 0.12, 0.1, (0, 0, COUNTER_TOP), segs=24, bevel=0.03, m=fmat("WoodLight", rough=0.7)),
          torus("WallTop", R + 0.05, 0.09, (0, 0, WALL_H), m=gold, major_segs=24, minor_segs=5)]
    # Witch-hat canopy: a striped cone that kinks over at the top.
    canopy = lathe("Canopy", [(R + 0.95, WALL_H + 0.2), (1.5, WALL_H + 1.1), (0.7, WALL_H + 2.1), (0.25, WALL_H + 2.9)], [orange, ink], segs=16, stripes=1,
                   smooth=False, cap_bottom=False, cap_top=True)
    double_sided(canopy)
    p.append(canopy)
    p += [torus("HatBand", 1.32, 0.14, (0, 0, WALL_H + 1.35), m=fmat("Purple", rough=0.45), major_segs=20, minor_segs=5),
          box("HatBuckle", (0.42, 0.12, 0.36), (0, -1.38, WALL_H + 1.35), bevel=0.04, m=gold)]
    for k in range(16):
        a = math.tau * (k + 0.5) / 16
        p.append(cyl(f"Fringe{k}", 0.42, 0.04, (math.cos(a) * (R + 0.98), math.sin(a) * (R + 0.98), WALL_H + 0.14), rot=(math.pi / 2, 0, a + math.pi / 2),
                     segs=3, bevel=0.0, m=orange if k % 2 else ink))
        p.append(bulb(f"Bulb{k}", 0.07, (math.cos(a) * (R + 1.0), math.sin(a) * (R + 1.0), WALL_H + 0.05), bulb_green() if k % 2 else bulb_orange()))
    # The claw and the crystal ball on top.
    top = WALL_H + 2.9
    p.append(tube("Wrist", [(0, 0, top - 0.1), (0.05, 0.05, top + 0.8), (0.0, 0.0, BALL_Z - 1.0)], 0.16, m=bone, segs=8, radius_end=0.2))
    for k in range(5):
        a = math.tau * k / 5
        base = (math.cos(a) * 0.25, math.sin(a) * 0.25, BALL_Z - 1.0)
        mid = (math.cos(a) * 0.95, math.sin(a) * 0.95, BALL_Z - 0.5)
        tip = (math.cos(a) * 0.8, math.sin(a) * 0.8, BALL_Z + 0.25)
        p.append(tube(f"Talon{k}", [base, mid, tip], 0.09, m=bone, segs=6, radius_end=0.04))
    p += [sphere("Ball", 0.9, (0, 0, BALL_Z), m=fglow("FrightBallGlow", "#7dff8a", 2.6), segs=20, rings=12),
          sphere("BallCore", 0.42, (0.1, -0.3, BALL_Z + 0.1), m=fglow("FrightBallCore", "#e8ffe0", 4.0), segs=12, rings=8)]
    # The sign over the window.
    p += [box("SignBoard", (3.2, 0.16, 0.6), (0, -R - 0.75, WALL_H + 0.55), rot=(math.radians(-10), 0, 0), bevel=0.05, m=night),
          box("SignTrim", (3.35, 0.1, 0.72), (0, -R - 0.7, WALL_H + 0.55), rot=(math.radians(-10), 0, 0), bevel=0.04, m=orange),
          text("SignText", "CREEPS & TREATS", 0.3, 0.05, (0, -R - 0.85, WALL_H + 0.53), rot=(math.radians(-10), 0, 0),
               m=fglow("FrightSignGreen", "#7dff6a", 2.2))]
    p += [box("BackWall", (2.6, 0.1, 1.2), (0, 0.3, COUNTER_TOP + 0.65), bevel=0.02, m=night)]
    return p


def goods():
    green = fglow("FrightCellGlow", "#7dff6a", 2.4)
    y = -R - 0.05
    p = [box("AmmoA", (0.62, 0.42, 0.34), (-1.05, y + 0.25, COUNTER_TOP + 0.22), bevel=0.04, m=fmat("Iron", metal=0.4)),
         box("AmmoStripe", (0.64, 0.44, 0.08), (-1.05, y + 0.25, COUNTER_TOP + 0.27), bevel=0.01, m=fmat("Orange", rough=0.5))]
    for k in range(3):
        p.append(cyl(f"Cell{k}", 0.08, 0.3, (0.55 + k * 0.2, y + 0.3, COUNTER_TOP + 0.2), segs=8, bevel=0.02, m=green))
    # Toffee apples (the heal) on sticks.
    for k in range(3):
        x = -0.35 + k * 0.3
        p += [cyl(f"Stick{k}", 0.015, 0.36, (x, y + 0.2, COUNTER_TOP + 0.18), segs=4, bevel=0.0, m=fmat("Bone")),
              sphere(f"Apple{k}", 0.13, (x, y + 0.2, COUNTER_TOP + 0.42), m=fmat("Crimson", rough=0.25), segs=10, rings=6)]
    p += pumpkin("PkA", (R + 0.65, 0.6, 0.0), r=0.34, seed=41, yaw=-0.5)
    p += pumpkin("PkB", (R + 0.4, 1.6, 0.0), r=0.24, seed=42, carved=False)
    p += pumpkin("PkC", (-R - 0.6, 0.9, 0.0), r=0.3, seed=43, yaw=0.5)
    p += [box("Crate", (0.8, 0.8, 0.7), (-R - 0.3, 1.9, 0.35), rot=(0, 0, 0.3), bevel=0.05, m=fmat("WoodLight", rough=0.75)),
          cyl("Candle", 0.08, 0.3, (-R - 0.3, 1.9, 0.85), segs=8, bevel=0.01, m=fmat("Bone")),
          bulb("Flame", 0.06, (-R - 0.3, 1.9, 1.06), bulb_orange())]
    return p


def shutter():
    L = SHUTTER_LEN
    p = [box("Panel", (SHUTTER_W, 0.06, L), (0, 0.0, -L / 2), bevel=0.02, m=fmat("Ink"))]
    for k in range(6):
        p.append(box(f"Stripe{k}", (SHUTTER_W / 6 - 0.02, 0.07, L - 0.04), (-SHUTTER_W / 2 + (k + 0.5) * SHUTTER_W / 6, -0.005, -L / 2), bevel=0.0,
                     m=fmat("Orange", rough=0.5) if k % 2 == 0 else fmat("Ink")))
    p.append(box("Edge", (SHUTTER_W + 0.06, 0.09, 0.08), (0, -0.01, -L + 0.04), bevel=0.02, m=fmat("Gold", rough=0.35, metal=0.4)))
    ob = merge("Shutter", p, pivot=(0, 0, 0))
    ob.location = HINGE
    ob.rotation_euler = (math.radians(SHUTTER_CLOSED), 0, 0)
    return ob


def open_dressing():
    neon = fglow("FrightNeonOpen", "#7dff6a", 3.2)
    p = [box("OpenBack", (0.9, 0.06, 0.32), (0, -R - 0.25, WIN_TOP - 0.25), bevel=0.03, m=fmat("Night")),
         text("OpenText", "OPEN", 0.22, 0.03, (0, -R - 0.3, WIN_TOP - 0.26), m=neon)]
    a = math.radians(SHUTTER_OPEN)
    d = SHUTTER_LEN - 0.1
    ey, ez = HINGE[1] - d * math.sin(-a), HINGE[2] - d * math.cos(a)
    for i, sx in enumerate((-1, 1)):
        p.append(tube(f"Stay{i}", [(sx * (SHUTTER_W / 2 - 0.2), -R - 0.25, COUNTER_TOP + 0.05), (sx * (SHUTTER_W / 2 - 0.2), ey, ez)], 0.03,
                      m=fmat("Gold", rough=0.35, metal=0.4), segs=5))
    return merge("OpenDressing", p)


def closed_sign():
    a = math.radians(SHUTTER_CLOSED)
    d = 0.7
    ny, nz = -math.cos(a), -math.sin(a)
    cy = HINGE[1] + d * math.sin(a) + ny * 0.06
    cz = HINGE[2] - d * math.cos(a) + nz * 0.06
    p = [box("ClosedCard", (1.5, 0.04, 0.34), (0, cy, cz), rot=(a, 0, 0), bevel=0.02, m=fmat("Bone")),
         text("ClosedText", "BACK AT MIDNIGHT", 0.15, 0.02, (0, cy + ny * 0.03, cz + nz * 0.03 - 0.01), rot=(a, 0, 0), m=fmat("Crimson", rough=0.5))]
    return merge("ClosedSign", p)


def build_station():
    reset_scene()
    station = merge("Station", booth() + goods())
    save("fright_station", [station, shutter(), open_dressing(), closed_sign()])


def build_portal():
    reset_scene()
    bone, bone_d, ink, night = fmat("Bone", rough=0.5), fmat("BoneDark", rough=0.6), fmat("Ink"), fmat("Night")
    p = []
    for s in (-1, 1):
        x = s * (wp.OPEN_W + 0.5)
        p += [box(f"Base{s}", (1.2, 1.0, 0.5), (x, 0, 0.25), bevel=0.06, m=fmat("StoneDark", rough=0.9)),
              box(f"Pillar{s}", (0.8, 0.7, 3.4), (x, 0, 2.2), bevel=0.08, m=fmat("Plum", rough=0.7))]
        for k in range(5):
            p.append(cyl(f"Vert{s}{k}", 0.48, 0.32, (x, -0.05, 0.75 + k * 0.62), segs=10, bevel=0.06, m=bone if k % 2 else bone_d))
        p += pumpkin(f"Pk{s}", (x, 0, 3.95), r=0.38, seed=50 + s)
    # Arch of bones: a femur along the curve and vertebra knuckles.
    hw, rise = wp.OPEN_W + 0.5, wp.OPEN_RISE + 0.5
    arc = wp.arc_only(hw, rise, steps=24, y=0.0)
    p.append(tube("Arch", arc, 0.26, m=bone, segs=10))
    for k in range(1, 24, 3):
        x, y, z = arc[k]
        p.append(sphere(f"Knuckle{k}", 0.34, (x, y - 0.05, z), scale=(1, 0.8, 1), m=bone_d, segs=10, rings=6))
    top = wp.OPEN_SPRING + rise
    p += [sphere("Skull", 0.85, (0, -0.1, top + 0.55), scale=(1, 0.8, 0.95), m=bone, segs=18, rings=11),
          box("SkullJaw", (0.9, 0.6, 0.4), (0, -0.3, top - 0.1), bevel=0.15, m=bone)]
    for s in (-1, 1):
        p += [sphere(f"Socket{s}", 0.24, (s * 0.3, -0.72, top + 0.55), scale=(1, 0.5, 1.1), m=night, segs=10, rings=6),
              bulb(f"Eye{s}", 0.11, (s * 0.3, -0.82, top + 0.55), fglow("FrightEyeGlow", "#7dff6a", 4.0))]
        wing = [(0.0, 0.0), (0.9, 0.3), (1.6, 0.0), (1.3, -0.15), (1.05, 0.05), (0.8, -0.2), (0.5, 0.0), (0.2, -0.2)]
        p.append(prism(f"Wing{s}", [(s * (0.7 + x), z) for x, z in wing] if s > 0 else list(reversed([(s * (0.7 + x), z) for x, z in wing])), 0.05,
                       (0, -0.05, top + 0.7), m=ink))
    for k in range(5):
        p.append(box(f"Tooth{k}", (0.12, 0.08, 0.16), (-0.24 + k * 0.12, -0.6, top + 0.05), bevel=0.02, m=bone_d))
    p += [box("Board", (1.3, 0.1, 0.42), (0, -0.45, wp.OPEN_SPRING + 0.95), bevel=0.04, m=night),
          text("BoardText", "EXIT", 0.3, 0.03, (0, -0.52, wp.OPEN_SPRING + 0.93), m=fglow("FrightExitText", "#7dff6a", 2.4))]
    p.append(wp.backing("Back", fmat("Night")))
    save("fright_portal_arch", [merge("PortalArch", p)])


if __name__ == "__main__":
    wanted = sys.argv[1:] or ["station", "portal"]
    if "station" in wanted:
        build_station()
    if "portal" in wanted:
        build_portal()
