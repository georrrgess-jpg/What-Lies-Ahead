"""Pirate Cove loadout station and exit portal (World 13, Skull Harbor).

    cove_station.glb       "The Salty Chandler": a giant rum barrel turned
                           ship's chandler (radius 2.3 m, walls 2.9 m), a service
                           window facing -Y under a striped scalloped canopy,
                           and above it a crow's nest on a mast with the skull
                           flag (top at ~11 m).
        Station        the kiosk, mast and nest (static)
        Shutter        the striped window shutter, pivot on its hinge, exported in
                       its closed pose (SHUTTER_CLOSED); the scene opens it to -70
        OpenDressing   the glowing OPEN board and the shutter stays (open only)
        ClosedSign     the "GONE FISHIN'" card on the shutter (closed only)
    cove_portal_arch.glb   the exit: the shared portal doorway in a frame of
                           lashed ship's timbers, a ship's wheel crown with a
                           skull lantern, rope coils and a lit EXIT board.

    python art/blender/build_cove_station.py [station] [portal]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cove_common import *  # noqa: F401,F403
from cove_common import bmesh  # noqa: F401
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
NEST_Z = 8.2


def kiosk():
    wood, light, iron, red, cream, gold = (cmat("Wood", rough=0.7), cmat("WoodLight", rough=0.7), cmat("Iron", rough=0.45, metal=0.4),
                                           cmat("Red", rough=0.5), cmat("Cream"), cmat("Gold", rough=0.35))
    p = [cyl("Plinth", R + 0.35, 0.25, (0, 0, 0.125), segs=28, bevel=0.05, m=cmat("StoneDark")),
         cyl("PlinthTrim", R + 0.38, 0.06, (0, 0, 0.26), segs=28, bevel=0.0, m=gold)]
    # Barrel staves (bellied), with the service window cut from the front sector.
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
            r0 = R * (0.9 + 0.1 * math.sin(math.pi * (z0 - 0.25) / (WALL_H - 0.25)))
            r1 = R * (0.9 + 0.1 * math.sin(math.pi * (z1 - 0.25) / (WALL_H - 0.25)))
            vs = [bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)) for a, z, r in ((a0, z0, r0), (a1, z0, r0), (a1, z1, r1), (a0, z1, r1))]
            f = bm.faces.new(vs)
            f.material_index = i % 2
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.xy.dot(f.calc_center_median().xy) < 0:
            f.normal_flip()
    p.append(finish_multi("Wall", bm, [wood, light], smooth=False))
    for k, z in enumerate((0.55, 2.7)):
        r = R * (0.9 + 0.1 * math.sin(math.pi * (z - 0.25) / (WALL_H - 0.25))) + 0.04
        p.append(torus(f"Hoop{k}", r, 0.07, (0, 0, z), m=iron, major_segs=28, minor_segs=5))
    p += [cyl("Inner", R * 0.88, WALL_H - 0.3, (0, 0, WALL_H / 2), segs=24, bevel=0.0, m=cmat("WoodDeep")),
          cyl("Counter", R + 0.12, 0.1, (0, 0, COUNTER_TOP), segs=28, bevel=0.03, m=cmat("Plank", rough=0.7)),
          cyl("Lid", R * 0.95, 0.2, (0, 0, WALL_H + 0.05), segs=28, bevel=0.04, m=wood)]
    canopy = lathe("Canopy", [(R + 0.9, WALL_H + 0.25), (1.4, WALL_H + 0.95), (0.2, WALL_H + 1.5)], [red, cream], segs=20, stripes=1, smooth=False,
                   cap_bottom=False, cap_top=False)
    double_sided(canopy)
    p.append(canopy)
    for k in range(20):
        a = math.tau * (k + 0.5) / 20
        p.append(cyl(f"Scallop{k}", 0.38, 0.04, (math.cos(a) * (R + 0.92), math.sin(a) * (R + 0.92), WALL_H + 0.2), rot=(math.pi / 2, 0, a + math.pi / 2),
                     segs=10, bevel=0.0, m=gold if k % 2 else red))
    p += [box("SignBoard", (3.1, 0.16, 0.56), (0, -R - 0.75, WALL_H + 0.5), rot=(math.radians(-10), 0, 0), bevel=0.05, m=cmat("Navy")),
          box("SignTrim", (3.25, 0.1, 0.68), (0, -R - 0.7, WALL_H + 0.5), rot=(math.radians(-10), 0, 0), bevel=0.04, m=gold),
          text("SignText", "THE SALTY CHANDLER", 0.26, 0.05, (0, -R - 0.85, WALL_H + 0.48), rot=(math.radians(-10), 0, 0), m=gold)]
    bulb_m = cglow("CoveBulb", "#ffd38a", 3.0)
    for k in range(16):
        a = math.tau * k / 16
        p.append(bulb(f"Bulb{k}", 0.07, (math.cos(a) * (R + 0.95), math.sin(a) * (R + 0.95), WALL_H + 0.02), bulb_m))
    # The mast through the canopy, a crow's nest and the flag.
    p += [cyl("Mast", 0.16, NEST_Z + 2.6 - WALL_H, (0, 0, (NEST_Z + 2.6 + WALL_H) / 2), segs=10, bevel=0.0, m=light, radius_top=0.1),
          cyl("Nest", 0.95, 0.85, (0, 0, NEST_Z + 0.4), segs=14, bevel=0.04, m=cmat("WoodDark")),
          torus("NestRim", 0.95, 0.07, (0, 0, NEST_Z + 0.82), m=gold, major_segs=16, minor_segs=4),
          cyl("NestFloor", 1.0, 0.12, (0, 0, NEST_Z - 0.04), segs=14, bevel=0.03, m=light),
          cyl("Yard", 0.09, 3.6, (0, 0.1, NEST_Z + 1.9), rot=rad(0, 90, 0), segs=8, bevel=0.0, m=cmat("WoodDark")),
          sphere("MastBall", 0.17, (0, 0, NEST_Z + 2.65), m=gold, segs=8, rings=5)]
    p += skull_flag("Flag", (0.95, 0, NEST_Z + 2.15), width=1.5, height=0.95, yaw=0.0)
    for k in range(6):
        a = math.tau * k / 6
        p.append(rope(f"Stay{k}", [(math.cos(a) * (R + 0.7), math.sin(a) * (R + 0.7), WALL_H + 0.4), (math.cos(a) * 0.9, math.sin(a) * 0.9, NEST_Z - 0.05)],
                      0.025, segs=4))
    p += lantern("NestLamp", (0.0, -0.95, NEST_Z + 0.95), scale=1.4)
    p.append(box("BackWall", (2.6, 0.1, 1.2), (0, 0.3, COUNTER_TOP + 0.65), bevel=0.02, m=cmat("WoodDeep")))
    return p


def goods():
    glow = cglow("CoveCellGlow", "#5ff0e6", 2.4)
    gold = mat("CoveCoin", "#ffc24a", rough=0.25, metal=0.6, emit=0.35)
    y = -R * 0.9 - 0.05
    p = [box("AmmoA", (0.62, 0.42, 0.34), (-1.0, y + 0.25, COUNTER_TOP + 0.22), bevel=0.04, m=cmat("Iron", rough=0.4)),
         box("AmmoStripe", (0.64, 0.44, 0.08), (-1.0, y + 0.25, COUNTER_TOP + 0.27), bevel=0.01, m=cmat("Gold", rough=0.4))]
    for k in range(3):
        p.append(cyl(f"Cell{k}", 0.08, 0.3, (0.55 + k * 0.2, y + 0.3, COUNTER_TOP + 0.2), segs=8, bevel=0.02, m=glow))
    # The heal: grog in tankards and a basket of oranges.
    for k in range(2):
        x = -0.35 + k * 0.32
        p += [cyl(f"Tankard{k}", 0.11, 0.24, (x, y + 0.2, COUNTER_TOP + 0.17), segs=10, bevel=0.02, m=cmat("WoodLight")),
              cyl(f"Froth{k}", 0.115, 0.05, (x, y + 0.2, COUNTER_TOP + 0.31), segs=10, bevel=0.0, m=cmat("Cream"))]
    for k in range(4):
        p.append(sphere(f"Orange{k}", 0.07, (0.15 + (k % 2) * 0.13, y + 0.22 + (k // 2) * 0.12, COUNTER_TOP + 0.12 + (k // 2) * 0.04),
                        m=mat("CoveOrange", "#ff9a2e", rough=0.6), segs=8, rings=5))
    p += [box("CrateA", (0.9, 0.9, 0.8), (R + 0.35, 1.2, 0.4), rot=(0, 0, 0.4), bevel=0.05, m=cmat("WoodLight", rough=0.75)),
          box("CrateB", (0.7, 0.7, 0.6), (R + 0.25, 1.2, 1.1), rot=(0, 0, 0.2), bevel=0.05, m=cmat("WoodLight", rough=0.75)),
          sphere("CoinHeap", 0.42, (-R - 0.4, 1.0, 0.05), scale=(1.2, 1.0, 0.5), m=gold, segs=12, rings=6)]
    p += barrel("Keg", 0.32, 0.8, (-R - 0.45, -0.2, 0.0), m_wood=cmat("RedDark", rough=0.6))
    return p


def shutter():
    L = SHUTTER_LEN
    p = [box("Panel", (SHUTTER_W, 0.06, L), (0, 0.0, -L / 2), bevel=0.02, m=cmat("Cream"))]
    for k in range(6):
        p.append(box(f"Stripe{k}", (SHUTTER_W / 6 - 0.02, 0.07, L - 0.04), (-SHUTTER_W / 2 + (k + 0.5) * SHUTTER_W / 6, -0.005, -L / 2), bevel=0.0,
                     m=cmat("Red", rough=0.5) if k % 2 == 0 else cmat("Cream")))
    p.append(box("Edge", (SHUTTER_W + 0.06, 0.09, 0.08), (0, -0.01, -L + 0.04), bevel=0.02, m=cmat("Gold", rough=0.35)))
    ob = merge("Shutter", p, pivot=(0, 0, 0))
    ob.location = HINGE
    ob.rotation_euler = (math.radians(SHUTTER_CLOSED), 0, 0)
    return ob


def open_dressing():
    neon = cglow("CoveNeonOpen", "#5ff0e6", 3.2)
    p = [box("OpenBack", (0.9, 0.06, 0.32), (0, -R - 0.25, WIN_TOP - 0.25), bevel=0.03, m=cmat("Navy")),
         text("OpenText", "OPEN", 0.22, 0.03, (0, -R - 0.3, WIN_TOP - 0.26), m=neon)]
    a = math.radians(SHUTTER_OPEN)
    d = SHUTTER_LEN - 0.1
    ey, ez = HINGE[1] - d * math.sin(-a), HINGE[2] - d * math.cos(a)
    for i, sx in enumerate((-1, 1)):
        p.append(tube(f"Stay{i}", [(sx * (SHUTTER_W / 2 - 0.2), -R - 0.25, COUNTER_TOP + 0.05), (sx * (SHUTTER_W / 2 - 0.2), ey, ez)], 0.03,
                      m=cmat("Gold", rough=0.35), segs=5))
    return merge("OpenDressing", p)


def closed_sign():
    a = math.radians(SHUTTER_CLOSED)
    d = 0.7
    ny, nz = -math.cos(a), -math.sin(a)
    cy = HINGE[1] + d * math.sin(a) + ny * 0.06
    cz = HINGE[2] - d * math.cos(a) + nz * 0.06
    p = [box("ClosedCard", (1.3, 0.04, 0.34), (0, cy, cz), rot=(a, 0, 0), bevel=0.02, m=cmat("Navy")),
         text("ClosedText", "GONE FISHIN'", 0.18, 0.02, (0, cy + ny * 0.03, cz + nz * 0.03 - 0.01), rot=(a, 0, 0), m=cmat("Gold", rough=0.3))]
    return merge("ClosedSign", p)


def build_station():
    reset_scene()
    station = merge("Station", kiosk() + goods())
    save("cove_station", [station, shutter(), open_dressing(), closed_sign()])


def build_portal():
    reset_scene()
    wood, dark, gold, red = cmat("Wood", rough=0.7), cmat("WoodDark"), cmat("Gold", rough=0.35), cmat("Red", rough=0.5)
    p = []
    for s in (-1, 1):
        x = s * (wp.OPEN_W + 0.45)
        p += [box(f"Post{s}", (0.6, 0.6, 4.2), (x, 0, 2.1), bevel=0.08, m=wood),
              box(f"PostCap{s}", (0.75, 0.75, 0.25), (x, 0, 4.3), bevel=0.06, m=dark),
              box(f"PostFoot{s}", (0.9, 0.9, 0.4), (x, 0, 0.2), bevel=0.06, m=cmat("StoneDark"))]
        for k, z in enumerate((1.0, 2.6)):
            p.append(torus(f"Lash{s}{k}", 0.4, 0.06, (x, 0, z), m=cmat("Rope", rough=0.9), major_segs=12, minor_segs=4))
            p.append(torus(f"Lash{s}{k}b", 0.4, 0.06, (x, 0, z + 0.16), m=cmat("Rope", rough=0.9), major_segs=12, minor_segs=4))
        p += lantern(f"Lamp{s}", (x + s * 0.55, -0.3, 3.0), scale=1.6)
        p.append(box(f"LampArm{s}", (0.6, 0.08, 0.08), (x + s * 0.3, -0.3, 3.75), bevel=0.0, m=cmat("Iron")))
        p.append(torus(f"Coil{s}", 0.42, 0.1, (x + s * 0.2, -0.75, 0.12), m=cmat("Rope", rough=0.9), major_segs=14, minor_segs=5))
    hw, rise = wp.OPEN_W + 0.45, wp.OPEN_RISE + 0.45
    p.append(tube("Arch", wp.arc_only(hw, rise, steps=24, y=0.0), 0.26, m=wood, segs=10))
    p.append(tube("ArchTrim", wp.arc_only(hw, rise, steps=24, y=-0.24), 0.08, m=gold, segs=6))
    top = wp.OPEN_SPRING + rise
    # Ship's wheel crown with a skull lantern at its hub.
    c = (0, 0.05, top + 0.85)
    p += [torus("Wheel", 1.0, 0.09, c, rot=rad(90, 0, 0), m=cmat("WoodLight"), major_segs=24, minor_segs=6),
          cyl("WheelHub", 0.35, 0.3, c, rot=rad(90, 0, 0), segs=14, bevel=0.04, m=cmat("Brass", rough=0.3, metal=0.5))]
    for k in range(8):
        a = math.tau * k / 8
        p.append(cyl(f"Spoke{k}", 0.05, 2.6, c, rot=(math.pi / 2, a, 0), segs=6, bevel=0.0, m=cmat("WoodLight")))
        p.append(sphere(f"Grip{k}", 0.09, (math.cos(a) * 1.32, c[1], c[2] + math.sin(a) * 1.32), m=cmat("WoodLight"), segs=6, rings=4))
    skull = cmat("Bone", rough=0.5)
    p += [sphere("Skull", 0.3, (0, -0.25, c[2] + 0.02), scale=(1, 0.9, 0.95), m=skull, segs=12, rings=8),
          box("SkullJaw", (0.34, 0.2, 0.16), (0, -0.33, c[2] - 0.24), bevel=0.05, m=skull)]
    for s in (-1, 1):
        p.append(sphere(f"SkullEye{s}", 0.07, (s * 0.11, -0.5, c[2] + 0.05), m=cglow("CoveSkullEye", "#ffb83a", 4.0), segs=6, rings=4))
    p += [box("Board", (1.4, 0.1, 0.45), (0, -0.45, wp.OPEN_SPRING + 1.0), bevel=0.04, m=cmat("Navy")),
          text("BoardText", "EXIT", 0.32, 0.03, (0, -0.52, wp.OPEN_SPRING + 0.98), m=cglow("CoveExitText", "#5ff0e6", 2.4))]
    p += skull_flag("FlagL", (-hw - 0.2, -0.35, 4.9), width=0.8, height=0.5) + skull_flag("FlagR", (hw + 0.2, -0.35, 4.9), width=0.8, height=0.5)
    for s in (-1, 1):
        p.append(cyl(f"FlagStaff{s}", 0.04, 1.3, (s * (hw + 0.2) - s * 0.42, -0.35, 4.75), segs=5, bevel=0.0, m=dark))
    p.append(rope("Swag", sag_points((-hw, -0.3, 3.9), (hw, -0.3, 3.9), 0.35), 0.05))
    p.append(wp.backing("Back", cmat("WoodDeep")))
    save("cove_portal_arch", [merge("PortalArch", p)])


if __name__ == "__main__":
    wanted = sys.argv[1:] or ["station", "portal"]
    if "station" in wanted:
        build_station()
    if "portal" in wanted:
        build_portal()
