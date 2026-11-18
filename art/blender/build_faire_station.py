"""Castle Kingdom loadout station and exit portal (World 14, Royal Faire).

    faire_station.glb      "The Royal Armoury": a round blue-and-gold striped
                           pavilion kiosk (radius 2.3 m, walls 2.9 m) with a service
                           window facing -Y, a scalloped valance, a cone roof and a
                           big gold crown on top (the station's landmark, ~8.5 m),
                           shields and a sword rack round it.
        Station        the kiosk (static)
        Shutter        the striped canvas window flap, pivot on its hinge, exported
                       in its closed pose (SHUTTER_CLOSED); the scene opens it to -70
        OpenDressing   the glowing ARMOURY board and the flap's poles (open only)
        ClosedSign     the "BACK SOON" card on the flap (closed only)
    faire_portal_arch.glb  the exit: the shared portal doorway in a stone arch with
                           banner pillars, a crowned keystone and a lit EXIT board.

    python art/blender/build_faire_station.py [station] [portal]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from faire_common import *  # noqa: F401,F403
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


def kiosk():
    blue, gold, cream, red = fmat("Blue", rough=0.5), fmat("Gold", rough=0.35), fmat("Cream", rough=0.7), fmat("Red", rough=0.5)
    st = stone()
    p = [cyl("Plinth", R + 0.4, 0.3, (0, 0, 0.15), segs=28, bevel=0.06, m=st),
         striped_drum("Wall", R, 0.3, WALL_H, [blue, gold], stripes=2, segs=28),
         cyl("Inner", R - 0.08, WALL_H - 0.3, (0, 0, 0.3 + (WALL_H - 0.3) / 2), segs=28, bevel=0.0, m=cream)]
    # The service window: a dark opening behind a wooden counter.
    p += [box("WinBack", (SHUTTER_W - 0.1, 0.3, WIN_TOP - COUNTER_TOP), (0, -R + 0.25, (WIN_TOP + COUNTER_TOP) / 2), bevel=0.0,
              m=fmat("TimberDark", rough=0.8)),
          box("Counter", (SHUTTER_W + 0.3, 0.6, 0.12), (0, -R - 0.12, COUNTER_TOP), bevel=0.03, m=fmat("Wood", rough=0.7)),
          box("WinFrameT", (SHUTTER_W + 0.3, 0.2, 0.18), (0, -R - 0.02, WIN_TOP + 0.05), bevel=0.03, m=gold)]
    for s in (-1, 1):
        p.append(box(f"WinFrame{s}", (0.16, 0.2, WIN_TOP - COUNTER_TOP + 0.2), (s * (SHUTTER_W / 2 + 0.08), -R - 0.02, (WIN_TOP + COUNTER_TOP) / 2),
                     bevel=0.03, m=gold))
    p += valance("Val", R + 0.38, WALL_H + 0.1, 28, red, gold, drop=0.4)
    p += [striped_cone("Roof", R + 0.45, WALL_H + 0.05, 3.2, [blue, cream], stripes=2, segs=28),
          cyl("RoofBand", R + 0.47, 0.18, (0, 0, WALL_H + 0.12), segs=28, bevel=0.03, m=gold)]
    # The crown on top, lit gems; the beacon rises from here.
    cz = WALL_H + 3.0
    p += [cyl("CrownPost", 0.12, 0.7, (0, 0, cz + 0.25), segs=8, bevel=0.0, m=gold),
          cyl("CrownBand", 1.0, 0.55, (0, 0, cz + 0.85), segs=24, bevel=0.06, m=gold),
          cyl("CrownCushion", 0.85, 0.5, (0, 0, cz + 1.15), segs=20, bevel=0.15, m=red)]
    for i in range(6):
        a = math.tau * i / 6
        px, py = math.cos(a) * 0.95, math.sin(a) * 0.95
        p += [cyl(f"CrownPoint{i}", 0.24, 0.8, (px, py, cz + 1.5), segs=6, bevel=0.02, m=gold, radius_top=0.02),
              sphere(f"CrownGem{i}", 0.13, (px, py, cz + 1.95), m=fglow("FaireGem", "#8fd0ff", 2.2), segs=8, rings=5),
              sphere(f"BandGem{i}", 0.11, (math.cos(a + 0.52) * 1.02, math.sin(a + 0.52) * 1.02, cz + 0.85), m=fglow("FaireGemRed", "#ff5a6a", 1.8),
                     segs=8, rings=5)]
    p += [sphere("CrownOrb", 0.25, (0, 0, cz + 1.75), m=gold, segs=12, rings=8),
          cyl("CrossV", 0.07, 0.5, (0, 0, cz + 2.2), segs=6, bevel=0.0, m=gold),
          box("CrossH", (0.36, 0.1, 0.1), (0, 0, cz + 2.25), bevel=0.02, m=gold)]
    # A sign board over the window.
    p += [box("Board", (2.2, 0.12, 0.5), (0, -R - 0.32, WALL_H + 0.5), bevel=0.04, m=blue),
          box("BoardRim", (2.35, 0.08, 0.62), (0, -R - 0.27, WALL_H + 0.5), bevel=0.03, m=gold),
          text("BoardText", "ROYAL ARMOURY", 0.24, 0.03, (0, -R - 0.4, WALL_H + 0.48), m=gold)]
    return p


def goods():
    """Shields on the walls, a sword rack, the energy kegs and the heal (turkey legs)."""
    gold, red, blue, iron = fmat("Gold", rough=0.35), fmat("Red", rough=0.5), fmat("Blue", rough=0.5), fmat("Iron", rough=0.4)
    shield = [(-0.42, 0.5), (0.42, 0.5), (0.42, 0.0), (0, -0.55), (-0.42, 0.0)]
    p = []
    for k, ang in enumerate((60, 120, 200, 340)):
        a = math.radians(ang - 90)
        x, y = math.cos(a) * (R + 0.05), math.sin(a) * (R + 0.05)
        sh = [prism(f"Shield{k}", shield, 0.1, (0, 0, 0), m=red if k % 2 else blue),
              prism(f"ShieldRim{k}", [(sx * 1.12, sz * 1.1) for sx, sz in shield], 0.06, (0, 0.03, 0), m=gold),
              crown_flat(f"ShieldCrown{k}", (0, -0.07, -0.1), 0.42, gold)]
        p += place(sh, (x, y, 1.7), rot_z=a + math.pi / 2)
    rack = [box("RackBar", (1.3, 0.12, 0.12), (0, 0, 1.3), bevel=0.02, m=fmat("Timber")),
            box("RackBase", (1.3, 0.4, 0.12), (0, 0, 0.06), bevel=0.02, m=fmat("Timber"))]
    for k in range(4):
        x = -0.45 + k * 0.3
        rack += [box(f"Blade{k}", (0.08, 0.03, 1.1), (x, 0.05, 0.7), bevel=0.01, m=iron),
                 box(f"Guard{k}", (0.3, 0.06, 0.06), (x, 0.05, 1.28), bevel=0.01, m=gold),
                 sphere(f"Pommel{k}", 0.05, (x, 0.05, 1.5), m=gold, segs=6, rings=4)]
    p += place(rack, (R + 0.55, 0.4, 0), rot_z=math.radians(80))
    y = -R - 0.05
    p += [cyl("KegA", 0.24, 0.42, (-0.85, y + 0.22, COUNTER_TOP + 0.27), rot=(0, math.pi / 2, 0), segs=12, bevel=0.03, m=fmat("Wood")),
          cyl("KegBand", 0.25, 0.08, (-0.85, y + 0.22, COUNTER_TOP + 0.27), rot=(0, math.pi / 2, 0), segs=12, bevel=0.0, m=gold)]
    for k in range(3):
        p.append(cyl(f"Cell{k}", 0.08, 0.3, (0.45 + k * 0.22, y + 0.3, COUNTER_TOP + 0.2), segs=8, bevel=0.02,
                     m=fglow("FaireCellGlow", "#8fd0ff", 2.4)))
    for k in range(2):
        x = -0.25 + k * 0.32
        p += [sphere(f"Leg{k}", 0.13, (x, y + 0.2, COUNTER_TOP + 0.18), scale=(1, 1, 1.4), m=fmat("Wood", rough=0.6), segs=10, rings=6),
              cyl(f"Bone{k}", 0.035, 0.18, (x, y + 0.2, COUNTER_TOP + 0.4), segs=6, bevel=0.0, m=fmat("Cream"))]
    p += [box("CrateA", (0.9, 0.9, 0.8), (-R - 0.3, 1.0, 0.4), rot=(0, 0, 0.3), bevel=0.05, m=fmat("WoodLight")),
          box("CrateB", (0.7, 0.7, 0.6), (-R - 0.2, 1.0, 1.1), rot=(0, 0, 0.1), bevel=0.05, m=fmat("WoodLight")),
          cyl("Barrel", 0.34, 0.85, (R + 0.2, -1.1, 0.43), segs=12, bevel=0.04, m=fmat("Wood"))]
    return p


def shutter():
    L = SHUTTER_LEN
    p = [box("Panel", (SHUTTER_W, 0.06, L), (0, 0.0, -L / 2), bevel=0.02, m=fmat("Cream"))]
    for k in range(6):
        p.append(box(f"Stripe{k}", (SHUTTER_W / 6 - 0.02, 0.07, L - 0.04), (-SHUTTER_W / 2 + (k + 0.5) * SHUTTER_W / 6, -0.005, -L / 2), bevel=0.0,
                     m=fmat("Blue", rough=0.5) if k % 2 == 0 else fmat("Cream")))
    p.append(box("Edge", (SHUTTER_W + 0.06, 0.09, 0.08), (0, -0.01, -L + 0.04), bevel=0.02, m=fmat("Gold", rough=0.35)))
    ob = merge("Shutter", p, pivot=(0, 0, 0))
    ob.location = HINGE
    ob.rotation_euler = (math.radians(SHUTTER_CLOSED), 0, 0)
    return ob


def open_dressing():
    neon = fglow("FaireNeonOpen", "#ffd36a", 3.0)
    p = [box("OpenBack", (1.0, 0.06, 0.32), (0, -R - 0.25, WIN_TOP - 0.25), bevel=0.03, m=fmat("Blue")),
         text("OpenText", "OPEN", 0.22, 0.03, (0, -R - 0.3, WIN_TOP - 0.26), m=neon)]
    a = math.radians(SHUTTER_OPEN)
    d = SHUTTER_LEN - 0.1
    ey, ez = HINGE[1] - d * math.sin(-a), HINGE[2] - d * math.cos(a)
    for i, sx in enumerate((-1, 1)):
        p.append(tube(f"Stay{i}", [(sx * (SHUTTER_W / 2 - 0.2), -R - 0.25, COUNTER_TOP + 0.05), (sx * (SHUTTER_W / 2 - 0.2), ey, ez)], 0.03,
                      m=fmat("Gold", rough=0.35), segs=5))
    return merge("OpenDressing", p)


def closed_sign():
    a = math.radians(SHUTTER_CLOSED)
    d = 0.7
    ny, nz = -math.cos(a), -math.sin(a)
    cy = HINGE[1] + d * math.sin(a) + ny * 0.06
    cz = HINGE[2] - d * math.cos(a) + nz * 0.06
    p = [box("ClosedCard", (1.2, 0.04, 0.34), (0, cy, cz), rot=(a, 0, 0), bevel=0.02, m=fmat("Red")),
         text("ClosedText", "BACK SOON", 0.19, 0.02, (0, cy + ny * 0.03, cz + nz * 0.03 - 0.01), rot=(a, 0, 0), m=fmat("Gold", rough=0.3))]
    return merge("ClosedSign", p)


def build_station():
    reset_scene()
    station = merge("Station", kiosk() + goods())
    save("faire_station", [station, shutter(), open_dressing(), closed_sign()])


def build_portal():
    reset_scene()
    st, light, gold, red, blue = stone(), fmat("StoneLight", rough=0.85), fmat("Gold", rough=0.35), fmat("Red", rough=0.5), fmat("Blue", rough=0.5)
    p = []
    for s in (-1, 1):
        x = s * (wp.OPEN_W + 0.55)
        p += [box(f"Pillar{s}", (0.9, 0.9, 3.8), (x, 0, 1.9), bevel=0.06, m=st),
              box(f"Base{s}", (1.15, 1.15, 0.5), (x, 0, 0.25), bevel=0.06, m=fmat("StoneDark")),
              box(f"Cap{s}", (1.1, 1.1, 0.3), (x, 0, 3.95), bevel=0.05, m=light),
              cyl(f"Pole{s}", 0.06, 2.6, (x, 0, 5.4), segs=6, bevel=0.0, m=gold),
              sphere(f"PoleTop{s}", 0.14, (x, 0, 6.75), m=gold, segs=8, rings=5),
              box(f"Bar{s}", (1.0, 0.08, 0.08), (x, -0.1, 6.4), bevel=0.02, m=gold),
              banner_cloth(f"Banner{s}", 0.85, 1.9, (x, -0.13, 6.35), red if s < 0 else blue),
              crown_flat(f"BannerCrown{s}", (x, -0.17, 5.3), 0.45, gold)]
    hw, rise = wp.OPEN_W + 0.55, wp.OPEN_RISE + 0.55
    for k in range(11):
        a = math.radians(180 * (k + 0.5) / 11)
        p.append(box(f"Voussoir{k}", (0.85, 0.85, 0.6), (math.cos(a) * hw, 0, wp.OPEN_SPRING + math.sin(a) * rise), rot=(0, -(a - math.pi / 2), 0),
                     bevel=0.06, m=light if k % 2 else st))
    top = wp.OPEN_SPRING + rise
    p += [box("Keystone", (1.0, 1.0, 0.95), (0, 0, top + 0.1), bevel=0.07, m=gold),
          crown_flat("KeyCrown", (0, -0.55, top + 0.7), 1.1, gold),
          box("Board", (1.4, 0.12, 0.45), (0, -0.48, wp.OPEN_SPRING + 0.95), bevel=0.04, m=blue),
          text("BoardText", "EXIT", 0.3, 0.03, (0, -0.56, wp.OPEN_SPRING + 0.93), m=fglow("FaireExitText", "#ffd36a", 2.4))]
    p += pennants("Pen", (-hw - 0.2, -0.5, 3.9), (hw + 0.2, -0.5, 3.9), 9, 0.3, [red, gold, blue], size=0.26)
    p.append(wp.backing("Back", fmat("BlueDark")))
    save("faire_portal_arch", [merge("PortalArch", p)])


if __name__ == "__main__":
    wanted = sys.argv[1:] or ["station", "portal"]
    if "station" in wanted:
        build_station()
    if "portal" in wanted:
        build_portal()
