"""Volcano Isle loadout station and exit portal (World 9, Lava Lagoon).

    lava_station.glb       "Tiki Outfitters": a bamboo hut 4.4 x 3.6 m under a
                           round two-tier thatch roof, a service window facing -Y
                           with a bamboo blind, ammo crates and coconut coolers
                           on the counter, surfboards and a carved sign mast.
        Station        the hut (static)
        Shutter        the bamboo blind, pivot on its hinge, exported in its
                       closed pose (SHUTTER_CLOSED); the scene opens it to -70
        OpenDressing   the glowing OPEN board and the awning stays (open only)
        ClosedSign     the "BACK SOON" plank on the blind (closed only)
    lava_portal_arch.glb   the exit: a tiki gate on the shared portal doorway
                           (scripts/props/exit_portal.gd) with carved totem jambs,
                           a bamboo arch hung with flowers, a carved lintel face,
                           torches and an EXIT board.

    python art/blender/build_lava_station.py [station] [portal]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lava_common import *  # noqa: F401,F403
import build_world_portals as wp  # noqa: E402

HW, HD = 2.2, 1.8                 # half width / depth of the hut
WALL_H = 3.0
COUNTER_TOP = 1.15
HINGE = (0.0, -HD - 0.08, 2.65)
SHUTTER_LEN = 1.45
SHUTTER_CLOSED = -12.0
SHUTTER_OPEN = -70.0


def hut():
    bam, dark, wood = lmat("Bamboo", rough=0.5), lmat("TikiDark"), lmat("Tiki")
    light = lmat("TikiLight")
    p = [box("Floor", (2 * HW + 0.4, 2 * HD + 0.4, 0.25), (0, 0, 0.125), bevel=0.05, m=lmat("BasaltLight", rough=0.8))]
    # Walls: back, sides, and the front below and beside the service window.
    p += [box("Back", (2 * HW, 0.25, WALL_H), (0, HD, WALL_H / 2), bevel=0.04, m=bam),
          box("SideL", (0.25, 2 * HD, WALL_H), (-HW, 0, WALL_H / 2), bevel=0.04, m=bam),
          box("SideR", (0.25, 2 * HD, WALL_H), (HW, 0, WALL_H / 2), bevel=0.04, m=bam),
          box("FrontLow", (2 * HW, 0.25, COUNTER_TOP), (0, -HD, COUNTER_TOP / 2), bevel=0.04, m=bam),
          box("FrontTop", (2 * HW, 0.25, WALL_H - 2.65), (0, -HD, (WALL_H + 2.65) / 2), bevel=0.04, m=bam),
          box("Inside", (2 * HW - 0.3, 0.1, WALL_H - 0.3), (0, HD - 0.2, WALL_H / 2), bevel=0.0, m=dark)]
    for x in (-HW, HW):
        for y in (-HD, HD):
            p.append(cyl(f"Corner{x}{y}", 0.17, WALL_H + 0.2, (x, y, (WALL_H + 0.2) / 2), segs=8, bevel=0.03, m=dark))
    for k in range(10):
        x = -HW + 0.2 + k * (2 * HW - 0.4) / 9
        p.append(cyl(f"Cane{k}", 0.06, COUNTER_TOP - 0.1, (x, -HD - 0.14, (COUNTER_TOP - 0.1) / 2 + 0.05), segs=6, bevel=0.0, m=lmat("BambooDark")))
    p += [box("Counter", (2 * HW + 0.2, 0.7, 0.1), (0, -HD - 0.2, COUNTER_TOP), bevel=0.03, m=light),
          box("CounterLip", (2 * HW + 0.3, 0.08, 0.16), (0, -HD - 0.55, COUNTER_TOP - 0.05), bevel=0.02, m=dark)]
    # Window frame and the blind's hinge rail.
    p += [box("WinL", (0.16, 0.3, 2.65 - COUNTER_TOP), (-HW + 0.3, -HD - 0.05, (2.65 + COUNTER_TOP) / 2), bevel=0.03, m=dark),
          box("WinR", (0.16, 0.3, 2.65 - COUNTER_TOP), (HW - 0.3, -HD - 0.05, (2.65 + COUNTER_TOP) / 2), bevel=0.03, m=dark),
          cyl("HingeRail", 0.06, 2 * HW, (0, HINGE[1] + 0.02, HINGE[2] + 0.02), rot=rad(0, 90, 0), segs=8, bevel=0.0, m=dark)]
    # Roof: two-tier round thatch on top, carved sign mast through it.
    p += thatch_roof("Roof", 3.4, 1.9, WALL_H - 0.15, layers=3, seed=2)
    p += [box("SignMast", (0.36, 0.36, 2.4), (0, 0, WALL_H + 2.2), bevel=0.05, m=dark)]
    p += tiki_face("MastFace", 0.34, 0.9, (0, -0.18, WALL_H + 2.6), style=0)
    p += [box("SignBoard", (3.4, 0.16, 0.66), (0, -HD - 0.9, WALL_H + 0.15), rot=(math.radians(-8), 0, 0), bevel=0.05, m=dark),
          text("SignText", "TIKI OUTFITTERS", 0.34, 0.05, (0, -HD - 1.0, WALL_H + 0.14), rot=(math.radians(-8), 0, 0), m=lmat("Yellow")),
          box("SignPostL", (0.12, 0.12, 0.9), (-1.4, -HD - 0.82, WALL_H - 0.4), bevel=0.02, m=dark),
          box("SignPostR", (0.12, 0.12, 0.9), (1.4, -HD - 0.82, WALL_H - 0.4), bevel=0.02, m=dark)]
    p += [bulb(f"Lamp{s}", 0.14, (s * (HW + 0.25), -HD - 0.3, 2.6), lglow("LavaLantern", "#ffb04a", 3.0)) for s in (-1, 1)]
    return p


def side_masks():
    """Big carved masks on both side walls."""
    p = []
    for s in (-1, 1):
        face = tiki_face(f"Mask{s}", 1.1, 1.4, (0, -0.13, 1.7), wood=lmat("Tiki"), paint=lmat("Teal" if s > 0 else "Pink"), style=1 if s > 0 else 0)
        face.append(box(f"MaskBoard{s}", (1.3, 0.1, 1.7), (0, -0.04, 1.7), bevel=0.05, m=lmat("TikiLight")))
        place(face, (s * (HW + 0.13), 0, 0), rot_z=s * math.pi / 2)
        p += face
    return p


def goods():
    """Counter goods and the stock around the hut."""
    cool, nut = lmat("Teal", rough=0.4), lmat("Coconut")
    p = [box("AmmoA", (0.7, 0.45, 0.35), (-1.2, -HD - 0.25, COUNTER_TOP + 0.22), bevel=0.04, m=lmat("SteelDark")),
         box("AmmoStripe", (0.72, 0.47, 0.08), (-1.2, -HD - 0.25, COUNTER_TOP + 0.26), bevel=0.01, m=lmat("Ember")),
         box("Cooler", (0.6, 0.42, 0.4), (1.15, -HD - 0.22, COUNTER_TOP + 0.25), bevel=0.06, m=cool),
         box("CoolerLid", (0.64, 0.46, 0.08), (1.15, -HD - 0.22, COUNTER_TOP + 0.48), bevel=0.03, m=lmat("White"))]
    for k in range(3):
        x = -0.35 + k * 0.35
        p += [sphere(f"Drink{k}", 0.13, (x, -HD - 0.25, COUNTER_TOP + 0.15), scale=(1, 1, 0.9), m=nut, segs=10, rings=6),
              cyl(f"Straw{k}", 0.012, 0.3, (x + 0.03, -HD - 0.25, COUNTER_TOP + 0.33), rot=(0.25, 0, 0), segs=4, bevel=0.0, m=lmat("Pink")),
              sphere(f"Umb{k}", 0.09, (x + 0.05, -HD - 0.25, COUNTER_TOP + 0.48), scale=(1, 1, 0.35), m=(lmat("Yellow"), lmat("Pink"), lmat("Teal"))[k], segs=8, rings=4)]
    # Surfboards leaning on the east wall, crates by the west wall.
    cols = [lmat("Pink"), lmat("Yellow"), lmat("Teal")]
    for k in range(3):
        p.append(sphere(f"Board{k}", 1.0, (HW + 0.45, -1.0 + k * 0.7, 1.1), scale=(0.08, 0.26, 1.1), rot=(0, math.radians(-10), 0), m=cols[k], segs=12, rings=10))
    p += [box("CrateA", (0.9, 0.9, 0.8), (-HW - 0.7, -0.6, 0.4), bevel=0.05, m=lmat("TikiLight")),
          box("CrateB", (0.7, 0.7, 0.6), (-HW - 0.65, 0.5, 0.3), rot=(0, 0, 0.3), bevel=0.05, m=lmat("TikiLight")),
          text("CrateText", "AMMO", 0.2, 0.02, (-HW - 0.7, -1.07, 0.42), m=lmat("TikiDark"))]
    for k in range(4):
        p.append(sphere(f"Nut{k}", 0.15, (-HW - 0.3 + 0.1 * k, -1.35 - 0.12 * (k % 2), 0.15), m=nut, segs=8, rings=6))
    return p


def shutter():
    """The bamboo blind in its closed pose, built around the hinge."""
    L = SHUTTER_LEN
    p = [box("BlindBack", (2 * HW - 0.5, 0.05, L), (0, 0.0, -L / 2), bevel=0.02, m=lmat("BambooDark"))]
    for k in range(11):
        p.append(cyl(f"Slat{k}", 0.06, 2 * HW - 0.5, (0, -0.05, -0.08 - k * (L - 0.1) / 10), rot=rad(0, 90, 0), segs=6, bevel=0.0,
                     m=lmat("Bamboo", rough=0.5) if k % 3 else lmat("Ember")))
    ob = merge("Shutter", p, pivot=(0, 0, 0))
    ob.location = HINGE
    ob.rotation_euler = (math.radians(SHUTTER_CLOSED), 0, 0)
    return ob


def open_dressing():
    """Glowing OPEN board under the sign and the awning stays (open only)."""
    neon = lglow("LavaNeonOpen", "#2fe6d4", 3.2)
    p = [box("OpenBack", (0.9, 0.06, 0.34), (0, -HD - 0.18, 2.48), bevel=0.03, m=lmat("TikiDark")),
         text("OpenText", "OPEN", 0.24, 0.03, (0, -HD - 0.23, 2.47), m=neon)]
    a = math.radians(SHUTTER_OPEN)
    d = SHUTTER_LEN - 0.1
    ey, ez = HINGE[1] - d * math.sin(-a), HINGE[2] - d * math.cos(a)
    for i, sx in enumerate((-1, 1)):
        p += bamboo(f"Stay{i}", (sx * (HW - 0.35), -HD - 0.4, COUNTER_TOP), (sx * (HW - 0.35), ey, ez), 0.035, joints=False)
    return merge("OpenDressing", p)


def closed_sign():
    a = math.radians(SHUTTER_CLOSED)
    d = 0.75
    ny, nz = -math.cos(a), -math.sin(a)
    cy = HINGE[1] + d * math.sin(a) + ny * 0.1
    cz = HINGE[2] - d * math.cos(a) + nz * 0.1
    p = [box("ClosedPlank", (1.3, 0.05, 0.36), (0, cy, cz), rot=(a, 0, 0), bevel=0.02, m=lmat("Cream")),
         text("ClosedText", "BACK SOON", 0.2, 0.02, (0, cy + ny * 0.035, cz + nz * 0.035 - 0.01), rot=(a, 0, 0), m=lmat("PinkDark"))]
    return merge("ClosedSign", p)


def build_station():
    reset_scene()
    station = merge("Station", hut() + side_masks() + goods())
    save("lava_station", [station, shutter(), open_dressing(), closed_sign()])


def build_portal():
    reset_scene()
    wood, dark, light = lmat("Tiki"), lmat("TikiDark"), lmat("TikiLight")
    p = []
    # Totem jambs: three carved blocks a side.
    for s in (-1, 1):
        x = s * (wp.OPEN_W + 0.45)
        z = 0.0
        for i, h in enumerate((1.0, 0.95, 0.9)):
            m = wood if (i + (s > 0)) % 2 == 0 else light
            p.append(box(f"Jamb{s}{i}", (0.86, 0.9, h - 0.04), (x, 0, z + h / 2), bevel=0.07, m=m))
            p += tiki_face(f"JF{s}{i}", 0.7, h, (x, -0.45, z + h / 2), wood=m, paint=lmat("Teal" if i % 2 else "Yellow"), dark=dark, style=(i + (s > 0)) % 3)
            z += h
    # Arch: a lashed bamboo bundle round the top with a flower garland.
    hw, rise = wp.OPEN_W + 0.45, wp.OPEN_RISE + 0.45
    for k, off in enumerate((-0.18, 0.0, 0.18)):
        pts = wp.arc_only(hw + off * 0.3, rise + off * 0.3, steps=20, y=off)
        p.append(tube(f"Arch{k}", pts, 0.16, m=lmat("Bamboo", rough=0.5), segs=8))
    for i in range(9):
        a = math.radians(180.0 * (i + 0.5) / 9)
        x, z = math.cos(a) * hw, wp.OPEN_SPRING + math.sin(a) * rise
        p.append(torus(f"Lash{i}", 0.3, 0.04, (x, 0, z), rot=(math.pi / 2, 0, -a), m=lmat("Rope", rough=0.9), major_segs=10, minor_segs=4))
    for i in range(13):
        a = math.radians(8 + 164.0 * i / 12)
        x, z = math.cos(a) * (hw - 0.05), wp.OPEN_SPRING + math.sin(a) * (rise - 0.05)
        p += flower(f"Lei{i}", (x, -0.35, z - 0.15), 0.15, m=(lmat("Pink"), lmat("Yellow"), lmat("White"))[i % 3])
        p[-2].rotation_euler = (0, 0, 0)
    # Lintel face and feathers at the crown.
    top = wp.OPEN_SPRING + rise
    p += [box("Lintel", (2.2, 0.8, 1.0), (0, -0.05, top + 0.3), bevel=0.1, m=wood)]
    p += tiki_face("Crown", 1.9, 1.0, (0, -0.45, top + 0.3), wood=wood, paint=lmat("Teal"), dark=dark, style=1)
    for k in range(5):
        p.append(prism(f"Plume{k}", [(-0.14, 0), (0.14, 0), (0.08, 0.9), (0, 1.0), (-0.08, 0.9)], 0.08, (-0.8 + k * 0.4, 0, top + 0.75),
                       rot=(0, math.radians((k - 2) * -14), 0), m=(lmat("Pink"), lmat("Yellow"), lmat("Teal"))[k % 3], bevel=0.02))
    p += [box("Board", (1.3, 0.1, 0.42), (0, -0.62, wp.OPEN_SPRING + 0.95), bevel=0.04, m=dark),
          text("BoardText", "EXIT", 0.3, 0.03, (0, -0.69, wp.OPEN_SPRING + 0.93), m=lglow("LavaExitText", "#2fe6d4", 2.4))]
    # Torches either side.
    for s in (-1, 1):
        x = s * 2.85
        p += bamboo(f"Torch{s}", (x, -0.3, 0), (x, -0.3, 2.4), 0.06)
        p += [cyl(f"TorchBowl{s}", 0.18, 0.26, (x, -0.3, 2.5), segs=10, bevel=0.03, m=dark, radius_top=0.22),
              sphere(f"TorchFlame{s}", 0.17, (x, -0.3, 2.75), scale=(1, 1, 1.7), m=lglow("LavaTorchFlame", "#ffb23a", 4.0), segs=8, rings=6),
              bulb(f"TorchHalo{s}", 0.1, (x, -0.3, 2.8), lglow("LavaTorchFlame", "#ffb23a", 4.0))]
    p.append(wp.backing("Back", lmat("Violet")))
    save("lava_portal_arch", [merge("PortalArch", p)])


if __name__ == "__main__":
    wanted = sys.argv[1:] or ["station", "portal"]
    if "station" in wanted:
        build_station()
    if "portal" in wanted:
        build_portal()
