"""Castle Kingdom castle pieces (World 14, Royal Faire): the keep (the world's
landmark), the round towers, the gatehouse, the wall-walk parapet module, the
drawbridge and the windmill on the hill.

    faire_keep.glb          the King's keep: 14 x 10 m, 16 m walls, four corner
                            turrets with blue cone roofs, a centre tower with a
                            red spire (top ~32 m), the great door, lit windows,
                            hanging banners. Collide with a 14 x 10 x 16 box.
    faire_tower.glb         round corner tower, r 3 m, wall 10 m, crenellated
                            top round a blue cone roof (top ~17 m) and a flag.
    faire_gatehouse.glb     9 x 4.4 x 9 m gate block with a 4.6 m arched passage
                            (top 5.5 m), the raised portcullis, two front drum
                            towers with red roofs, the royal arms over the arch.
    faire_parapet.glb       wall-walk parapet module, 3 m along X: a 0.75 m wall
                            and two merlons (top 1.55 m), 0.6 m thick.
    faire_drawbridge.glb    5 x 7 m plank bridge (hinge at y 0, out along -Y),
                            iron straps and the chains up to the gatehouse.
    faire_windmill.glb      white-and-timber windmill on a stone base (cap ~13 m),
                            the sails' hub at (0, -2.6, 9.6).
    faire_windmill_sails.glb  four lattice sails, radius 7 m, lying in the XY
                            plane round the origin (the level stands them up and
                            turns them).

    python art/blender/build_faire_castle.py [keep] [tower] ...
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from faire_common import *  # noqa: F401,F403


def window_glow():
    return fglow("FaireWindow", "#ffd98a", 1.4)


def arch_window(prefix, x, y, z, w, h, frame, glow, face=-1, rot_z=0.0):
    """An arched window (faces -Y, or +Y with face 1) with a stone frame."""
    outline = [(-w / 2, 0), (w / 2, 0), (w / 2, h - w / 2)] + \
              [(math.cos(math.radians(a)) * w / 2, h - w / 2 + math.sin(math.radians(a)) * w / 2) for a in range(20, 180, 20)] + \
              [(-w / 2, h - w / 2)]
    big = [(px * 1.35, pz * 1.12 - 0.08) for px, pz in outline]
    parts = [prism(prefix + "Frame", big, 0.12, (x, y + face * 0.04, z), rot=(0, 0, rot_z), m=frame),
             prism(prefix + "Pane", outline, 0.1, (x, y + face * 0.08, z), rot=(0, 0, rot_z), m=glow)]
    return parts


def build_tower():
    reset_scene()
    st, dark, light = stone(), fmat("StoneDark", rough=0.85), fmat("StoneLight", rough=0.85)
    slit, blue = fmat("Slit"), fmat("Blue", rough=0.5)
    R = 3.0
    p = [cyl("Body", R, 10.4, (0, 0, 5.2), segs=28, bevel=0.05, m=st),
         cyl("Batter", R + 0.4, 1.6, (0, 0, 0.8), segs=28, bevel=0.06, m=dark, radius_top=R + 0.05),
         cyl("Course", R + 0.08, 0.25, (0, 0, 6.0), segs=28, bevel=0.03, m=light),
         cyl("Machicolation", R + 0.35, 0.6, (0, 0, 10.1), segs=28, bevel=0.06, m=light),
         cyl("ParapetWall", R + 0.35, 0.7, (0, 0, 10.75), segs=28, bevel=0.05, m=st)]
    for k in range(16):
        a = math.tau * (k + 0.5) / 16
        p.append(box(f"Corbel{k}", (0.32, 0.4, 0.4), (math.cos(a) * (R + 0.15), math.sin(a) * (R + 0.15), 9.65), rot=(0, 0, a), bevel=0.05, m=dark))
    p += merlons_ring("Merlon", R + 0.18, 11.1, 12, height=0.8, width=0.95, depth=0.42, m=st)
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        for z in (3.2, 7.6):
            p.append(box(f"Slit{k}{z}", (0.2, 0.16, 1.0), (math.cos(a) * (R - 0.03), math.sin(a) * (R - 0.03), z), rot=(0, 0, a + math.pi / 2),
                         bevel=0.04, m=slit))
    p += arch_window("Win", 0, -R + 0.02, 7.0, 0.8, 1.5, light, window_glow())
    roof = cone_roof("Roof", R - 0.1, 10.9, 6.4, blue, flag=2.2, flag_m=fmat("Red", rough=0.5))
    p += roof
    save("faire_tower", [merge("Tower", p)])


def build_keep():
    reset_scene()
    st, dark, light = stone(), fmat("StoneDark", rough=0.85), fmat("StoneLight", rough=0.85)
    blue, red, gold = fmat("Blue", rough=0.5), fmat("Red", rough=0.5), fmat("Gold", rough=0.35)
    glow = window_glow()
    W, D, H = 14.0, 10.0, 16.0
    p = [box("Body", (W, D, H), (0, 0, H / 2), bevel=0.08, m=st),
         box("Plinth", (W + 0.6, D + 0.6, 1.4), (0, 0, 0.7), bevel=0.08, m=dark),
         box("CourseA", (W + 0.16, D + 0.16, 0.3), (0, 0, 5.6), bevel=0.04, m=light),
         box("CourseB", (W + 0.16, D + 0.16, 0.3), (0, 0, 11.2), bevel=0.04, m=light),
         box("Cornice", (W + 0.5, D + 0.5, 0.5), (0, 0, H - 0.1), bevel=0.06, m=light)]
    p += merlons_line("MerF", -W / 2 + 1.6, W / 2 - 1.6, -D / 2 + 0.05, H + 0.15, 6, height=0.9, depth=0.5, m=st)
    p += merlons_line("MerB", -W / 2 + 1.6, W / 2 - 1.6, D / 2 - 0.05, H + 0.15, 6, height=0.9, depth=0.5, m=st)
    for s in (-1, 1):
        for i in range(3):
            y = -D / 2 + 2.0 + i * 3.0
            p.append(box(f"MerS{s}{i}", (0.5, 1.4, 0.9), (s * (W / 2 - 0.05), y, H + 0.6), bevel=0.06, m=st))
    # Corner turrets with blue cone roofs and flags.
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        tx, ty = sx * W / 2, sy * D / 2
        tp = [cyl(f"Turret{i}", 1.9, 19.0, (0, 0, 9.5), segs=20, bevel=0.05, m=st),
              cyl(f"TurretRing{i}", 2.15, 0.5, (0, 0, 18.9), segs=20, bevel=0.05, m=light)]
        tp += merlons_ring(f"TurMer{i}_", 1.95, 19.1, 8, height=0.7, width=0.7, depth=0.35, m=st)
        tp += cone_roof(f"TurRoof{i}", 1.85, 19.0, 6.5, blue, flag=2.0, flag_m=red if i % 2 == 0 else gold)
        for z in (7.0, 13.0):
            tp.append(box(f"TurSlit{i}{z}", (0.18, 0.14, 0.9), (0, -1.88 * sy, z), bevel=0.03, m=fmat("Slit")))
        p += place(tp, (tx, ty, 0))
    # The centre tower and its red spire.
    p += [box("Centre", (6.0, 6.0, 7.5), (0, 0.5, H + 3.75), bevel=0.06, m=st),
          box("CentreCornice", (6.4, 6.4, 0.4), (0, 0.5, H + 7.4), bevel=0.05, m=light)]
    for k, (x, y) in enumerate(((-1.6, -2.5), (1.6, -2.5), (-1.6, 3.5), (1.6, 3.5))):
        p.append(box(f"CenMer{k}", (1.1, 0.4, 0.7), (x, y, H + 7.95), bevel=0.05, m=st))
    p += place(pyramid_roof("Spire", 2.9, H + 7.6, 8.5, red), (0, 0.5, 0))
    p += [sphere("SpireBall", 0.35, (0, 0.5, H + 16.2), m=gold, segs=12, rings=8),
          cyl("SpirePole", 0.07, 3.4, (0, 0.5, H + 17.9), segs=6, bevel=0.0, m=fmat("IronDark")),
          prism("SpireFlag", [(0, 0), (2.4, -0.4), (2.0, -0.85), (2.4, -1.3), (0, -1.5)], 0.05, (0.06, 0.5, H + 19.5), m=blue),
          star("SpireFlagStar", 0.32, 0.07, (1.0, 0.44, H + 18.75), rot=(math.pi / 2, 0, 0), m=gold)]
    for k in range(3):
        x = -1.6 + k * 1.6
        p += arch_window(f"CenWin{k}", x, -2.5, H + 3.0, 0.7, 1.6, light, glow)
    # The great door: an arched oak door with iron straps in a stone surround.
    dw, dh = 3.6, 5.0
    door = [(-dw / 2, 0), (dw / 2, 0), (dw / 2, dh - dw / 2)] + \
           [(math.cos(math.radians(a)) * dw / 2, dh - dw / 2 + math.sin(math.radians(a)) * dw / 2) for a in range(15, 180, 15)] + \
           [(-dw / 2, dh - dw / 2)]
    p.append(prism("Door", door, 0.2, (0, -D / 2 - 0.02, 0.0), m=fmat("Timber", rough=0.8)))
    for k in range(6):
        a = math.radians(180 * (k + 0.5) / 6)
        r = dw / 2 + 0.42
        p.append(box(f"Voussoir{k}", (0.75, 0.5, 0.62), (math.cos(a) * r, -D / 2 - 0.12, dh - dw / 2 + math.sin(a) * r), rot=(0, -(a - math.pi / 2), 0),
                     bevel=0.06, m=light))
    for s in (-1, 1):
        p.append(box(f"Jamb{s}", (0.62, 0.5, dh - dw / 2), (s * (dw / 2 + 0.42), -D / 2 - 0.12, (dh - dw / 2) / 2), bevel=0.06, m=light))
    for z in (1.0, 2.4, 3.8):
        p.append(box(f"Strap{z}", (dw - 0.2, 0.08, 0.16), (0, -D / 2 - 0.15, z), bevel=0.02, m=fmat("IronDark")))
        for k in range(5):
            p.append(sphere(f"Stud{z}{k}", 0.06, (-1.2 + k * 0.6, -D / 2 - 0.2, z), m=fmat("Iron"), segs=6, rings=4))
    p.append(box("DoorSeam", (0.06, 0.08, dh - 0.3), (0, -D / 2 - 0.13, (dh - 0.3) / 2), bevel=0.0, m=fmat("TimberDark")))
    p += [torus(f"Ring{s}", 0.18, 0.04, (s * 0.35, -D / 2 - 0.2, 2.0), rot=(math.pi / 2, 0, 0), m=fmat("Iron"), major_segs=12, minor_segs=4)
          for s in (-1, 1)]
    # Windows: two rows on the front and back, one on each side.
    for face in (-1, 1):
        y = face * D / 2
        for k, x in enumerate((-4.6, 4.6)):
            p += arch_window(f"WinA{face}{k}", x, y, 7.0, 1.0, 2.2, light, glow, face=face)
        for k, x in enumerate((-4.6, -1.6, 1.6, 4.6) if face > 0 else (-4.6, 4.6)):
            p += arch_window(f"WinB{face}{k}", x, y, 12.2, 0.9, 2.0, light, glow, face=face)
    for s in (-1, 1):
        for k, y in enumerate((-2.0, 2.0)):
            p += place(arch_window(f"WinS{s}{k}", 0, 0, 9.0, 0.9, 2.0, light, glow), (s * W / 2, y, 0), rot_z=s * math.pi / 2)
    # The rose window over the door and the hanging banners.
    p += [cyl("Rose", 1.25, 0.2, (0, -D / 2 - 0.05, 12.4), rot=(math.pi / 2, 0, 0), segs=24, bevel=0.04, m=light),
          cyl("RoseGlass", 1.0, 0.24, (0, -D / 2 - 0.06, 12.4), rot=(math.pi / 2, 0, 0), segs=24, bevel=0.0, m=fglow("FaireRose", "#8fb8ff", 1.2))]
    for k in range(8):
        a = math.tau * k / 8
        p.append(box(f"RoseBar{k}", (0.08, 0.08, 1.0), (math.cos(a) * 0.5, -D / 2 - 0.2, 12.4 + math.sin(a) * 0.5), rot=(0, -a + math.pi / 2, 0),
                     bevel=0.0, m=light))
    for k, x in enumerate((-2.6, 2.6)):
        p += [banner_cloth(f"Banner{k}", 1.5, 6.5, (x, -D / 2 - 0.08, 15.2), red if k == 0 else blue),
              box(f"BannerRod{k}", (1.9, 0.12, 0.12), (x, -D / 2 - 0.12, 15.25), bevel=0.03, m=gold),
              crown_flat(f"BannerCrown{k}", (x, -D / 2 - 0.13, 12.0), 0.9, gold)]
    # Torches either side of the door.
    for s in (-1, 1):
        p += [box(f"Sconce{s}", (0.2, 0.3, 0.4), (s * 3.0, -D / 2 - 0.15, 3.2), bevel=0.03, m=fmat("IronDark")),
              cyl(f"TorchCup{s}", 0.18, 0.3, (s * 3.0, -D / 2 - 0.35, 3.55), segs=10, bevel=0.02, m=fmat("Iron"), radius_top=0.24),
              sphere(f"Flame{s}", 0.2, (s * 3.0, -D / 2 - 0.35, 3.85), scale=(1, 1, 1.6), m=fglow("FaireFlame", "#ffb347", 3.5), segs=10, rings=6)]
    save("faire_keep", [merge("Keep", p)])


def build_gatehouse():
    reset_scene()
    st, dark, light = stone(), fmat("StoneDark", rough=0.85), fmat("StoneLight", rough=0.85)
    red, gold, blue, iron = fmat("Red", rough=0.5), fmat("Gold", rough=0.35), fmat("Blue", rough=0.5), fmat("IronDark", rough=0.5)
    W, D, H = 9.0, 4.4, 9.0
    hw, spring, r = 2.3, 3.2, 2.3
    p = []
    for s in (-1, 1):
        p.append(box(f"Pier{s}", (W / 2 - hw, D, H), (s * (W / 2 + hw) / 2, 0, H / 2), bevel=0.06, m=st))
    p.append(box("Lintel", (2 * hw + 0.1, D, H - 5.9), (0, 0, (H + 5.9) / 2), bevel=0.06, m=st))
    span = [(hw, spring)] + [(math.cos(math.radians(a)) * r, spring + math.sin(math.radians(a)) * r) for a in range(12, 180, 12)] + \
           [(-hw, spring), (-hw, 5.95), (hw, 5.95)]
    p.append(prism("Spandrel", span, D, (0, 0, 0), m=st))
    for face in (-1, 1):
        for k in range(9):
            a = math.radians(180 * (k + 0.5) / 9)
            rr = r + 0.3
            p.append(box(f"Arch{face}{k}", (0.7, 0.2, 0.55), (math.cos(a) * rr, face * (D / 2 + 0.06), spring + math.sin(a) * rr),
                         rot=(0, -(a - math.pi / 2), 0), bevel=0.05, m=light))
    p += [box("CourseF", (W + 0.2, 0.2, 0.3), (0, -D / 2 - 0.05, 6.4), bevel=0.04, m=light),
          box("CourseB", (W + 0.2, 0.2, 0.3), (0, D / 2 + 0.05, 6.4), bevel=0.04, m=light),
          box("Cornice", (W + 0.4, D + 0.4, 0.4), (0, 0, H - 0.1), bevel=0.05, m=light)]
    p += merlons_line("MerF", -W / 2, W / 2, -D / 2 + 0.1, H + 0.1, 6, height=0.9, depth=0.5, m=st)
    p += merlons_line("MerB", -W / 2, W / 2, D / 2 - 0.1, H + 0.1, 6, height=0.9, depth=0.5, m=st)
    # The raised portcullis: its teeth hang in the top of the arch.
    for k in range(11):
        x = -2.0 + k * 0.4
        p += [box(f"Bar{k}", (0.1, 0.1, 1.7), (x, -0.9, 5.0), bevel=0.01, m=iron),
              cyl(f"Tooth{k}", 0.07, 0.25, (x, -0.9, 4.05), segs=6, bevel=0.0, m=iron, radius_top=0.01)]
    for z in (4.5, 5.2):
        p.append(box(f"Rail{z}", (4.4, 0.1, 0.1), (0, -0.9, z), bevel=0.01, m=iron))
    # Front drum towers with red roofs.
    for s in (-1, 1):
        tp = [cyl(f"Drum{s}", 2.0, 10.6, (0, 0, 5.3), segs=22, bevel=0.05, m=st),
              cyl(f"DrumBatter{s}", 2.35, 1.4, (0, 0, 0.7), segs=22, bevel=0.06, m=dark, radius_top=2.05),
              cyl(f"DrumRing{s}", 2.25, 0.45, (0, 0, 10.4), segs=22, bevel=0.05, m=light)]
        tp += merlons_ring(f"DrumMer{s}_", 2.05, 10.6, 9, height=0.7, width=0.75, depth=0.38, m=st)
        tp += cone_roof(f"DrumRoof{s}", 1.9, 10.6, 5.0, red, flag=1.8, flag_m=blue)
        for z in (3.0, 7.0):
            tp.append(box(f"DrumSlit{s}{z}", (0.18, 0.14, 0.9), (0, -1.98, z), bevel=0.03, m=fmat("Slit")))
        p += place(tp, (s * 4.6, -D / 2 - 0.4, 0))
    # The royal arms over the arch and banners on the drum towers.
    arms = [(-0.7, 0.6), (0.7, 0.6), (0.7, -0.2), (0, -0.8), (-0.7, -0.2)]
    p += [prism("Arms", arms, 0.15, (0, -D / 2 - 0.12, 7.4), m=blue),
          prism("ArmsRim", [(x * 1.15, z * 1.12) for x, z in arms], 0.1, (0, -D / 2 - 0.06, 7.4), m=gold)]
    p.append(crown_flat("ArmsCrown", (0, -D / 2 - 0.22, 7.5), 0.8, gold))
    for s in (-1, 1):
        p += [banner_cloth(f"Banner{s}", 1.2, 3.8, (s * 4.6, -D / 2 - 2.45, 9.4), red if s < 0 else blue),
              box(f"BannerRod{s}", (1.5, 0.1, 0.1), (s * 4.6, -D / 2 - 2.5, 9.45), bevel=0.02, m=gold)]
    save("faire_gatehouse", [merge("Gatehouse", p)])


def build_parapet():
    reset_scene()
    st, light = stone(), fmat("StoneLight", rough=0.85)
    p = [box("Wall", (3.0, 0.6, 0.75), (0, 0, 0.375), bevel=0.04, m=st),
         box("Coping", (3.0, 0.7, 0.12), (0, 0, 0.78), bevel=0.03, m=light)]
    for x in (-0.75, 0.75):
        p.append(box(f"Merlon{x}", (0.95, 0.6, 0.72), (x, 0, 1.2), bevel=0.06, m=st))
    save("faire_parapet", [merge("Parapet", p)])


def build_drawbridge():
    reset_scene()
    wood, light, dark, iron = fmat("Wood", rough=0.8), fmat("WoodLight", rough=0.8), fmat("Timber", rough=0.8), fmat("IronDark", rough=0.5)
    W, L = 5.0, 7.0
    p = []
    n = 10
    for i in range(n):
        x = -W / 2 + (i + 0.5) * W / n
        p.append(box(f"Plank{i}", (W / n - 0.04, L, 0.3), (x, -L / 2, -0.15), bevel=0.03, m=wood if i % 3 else light))
    for y in (-0.8, -3.5, -6.2):
        p.append(box(f"Strap{y}", (W + 0.05, 0.22, 0.08), (0, y, 0.02), bevel=0.02, m=iron))
    for s in (-1, 1):
        p.append(box(f"Edge{s}", (0.25, L, 0.45), (s * (W / 2 + 0.05), -L / 2, -0.05), bevel=0.04, m=dark))
        p.append(tube(f"Chain{s}", [(s * 2.35, -L + 0.3, 0.25), (s * 2.5, 0.8, 6.3)], 0.07, m=iron, segs=6))
        for k in range(8):
            t = (k + 0.5) / 8
            pos = (s * (2.35 + 0.15 * t), -L + 0.3 + (L + 0.5) * t, 0.25 + 6.05 * t)
            p.append(torus(f"Link{s}{k}", 0.12, 0.035, pos, rot=(0.7, 0, math.pi / 2 * (k % 2)), m=iron, major_segs=8, minor_segs=4))
        p.append(box(f"Eye{s}", (0.3, 0.3, 0.3), (s * 2.35, -L + 0.3, 0.2), bevel=0.04, m=iron))
    save("faire_drawbridge", [merge("Drawbridge", p)])


def build_windmill():
    reset_scene()
    plaster, timber, st, dark = fmat("Plaster", rough=0.8), fmat("Timber", rough=0.8), stone(), fmat("StoneDark", rough=0.85)
    roof, gold, blue = fmat("Roof", rough=0.7), fmat("Gold", rough=0.35), fmat("Blue", rough=0.5)
    body = lathe("Body", [(3.0, 1.2), (2.5, 6.0), (2.05, 9.6)], [plaster], segs=20, smooth=True, cap_bottom=False)
    p = [body, cyl("Base", 3.4, 1.3, (0, 0, 0.65), segs=20, bevel=0.06, m=st),
         cyl("BaseCap", 3.5, 0.2, (0, 0, 1.32), segs=20, bevel=0.04, m=dark)]
    for k, (r0, z) in enumerate(((2.8, 3.4), (2.3, 7.6))):
        p.append(torus(f"Band{k}", r0, 0.09, (0, 0, z), m=timber, major_segs=24, minor_segs=6))
    for k in range(8):
        a = math.tau * k / 8
        p.append(tube(f"Rib{k}", [(math.cos(a) * 3.0, math.sin(a) * 3.0, 1.3), (math.cos(a) * 2.06, math.sin(a) * 2.06, 9.6)], 0.08, m=timber, segs=4))
    p += [cyl("CapRing", 2.35, 0.4, (0, 0, 9.75), segs=20, bevel=0.05, m=timber),
          sphere("Cap", 2.45, (0, 0, 9.9), scale=(1, 1, 1.25), m=roof, segs=20, rings=10)]
    p += [cyl("Finial", 0.08, 1.2, (0, 0, 13.4), segs=6, bevel=0.0, m=timber), sphere("FinialBall", 0.22, (0, 0, 14.0), m=gold, segs=10, rings=6)]
    # The hub out front and a little door with a canopy.
    p += [box("HubBlock", (1.0, 1.6, 1.0), (0, -2.0, 9.6), bevel=0.08, m=timber),
          cyl("Axle", 0.32, 0.8, (0, -2.8, 9.6), rot=(math.pi / 2, 0, 0), segs=12, bevel=0.03, m=fmat("IronDark"))]
    door = [(-0.6, 0), (0.6, 0), (0.6, 1.6)] + [(math.cos(math.radians(a)) * 0.6, 1.6 + math.sin(math.radians(a)) * 0.6) for a in range(30, 180, 30)] + [(-0.6, 1.6)]
    p += [prism("Door", door, 0.12, (0, -2.98, 1.3), m=blue),
          box("DoorStep", (1.6, 0.6, 0.2), (0, -3.5, 1.2), bevel=0.04, m=dark),
          box("Canopy", (1.8, 0.8, 0.12), (0, -3.25, 3.6), rot=(0.35, 0, 0), bevel=0.03, m=roof)]
    for k, (a, z) in enumerate(((60, 5.0), (-60, 5.0), (180, 6.8))):
        ar = math.radians(a - 90)
        rr = 2.5 - (z - 6.0) * 0.12
        p.append(box(f"Window{k}", (0.6, 0.2, 0.8), (math.cos(ar) * rr, math.sin(ar) * rr, z), rot=(0, 0, ar + math.pi / 2), bevel=0.04,
                     m=fglow("FaireWindow", "#ffd98a", 1.4)))
        p.append(box(f"Shutter{k}", (0.9, 0.16, 0.9), (math.cos(ar) * (rr - 0.03), math.sin(ar) * (rr - 0.03), z), rot=(0, 0, ar + math.pi / 2),
                     bevel=0.03, m=blue))
    save("faire_windmill", [merge("Windmill", p)])


def build_sails():
    reset_scene()
    timber, canvas, red = fmat("Timber", rough=0.8), fmat("Cream", rough=0.8), fmat("Red", rough=0.6)
    p = [cyl("Hub", 0.5, 0.5, (0, 0, 0), segs=12, bevel=0.06, m=fmat("Wood", rough=0.7)),
         sphere("HubCap", 0.36, (0, 0, 0.3), m=fmat("Gold", rough=0.35), segs=10, rings=6)]
    for k in range(4):
        a = math.tau * k / 4
        d = Vector((math.cos(a), math.sin(a), 0))
        s = Vector((-d.y, d.x, 0))
        p.append(tube(f"Stock{k}", [d * 0.3, d * 7.0], 0.12, m=timber, segs=6))
        p.append(tube(f"Edge{k}", [d * 1.4 + s * 1.3, d * 7.0 + s * 1.3], 0.06, m=timber, segs=4))
        for j in range(7):
            q = d * (1.4 + j * 0.93)
            p.append(tube(f"Bar{k}{j}", [q, q + s * 1.3], 0.05, m=timber, segs=4))
        mid = d * 4.2 + s * 0.68
        p.append(box(f"Cloth{k}", (5.4, 1.2, 0.04), (mid.x, mid.y, -0.05), rot=(0, 0, a), bevel=0.0, m=canvas if k % 2 == 0 else red))
    save("faire_windmill_sails", [merge("Sails", p)])


BUILDERS = {"keep": build_keep, "tower": build_tower, "gatehouse": build_gatehouse, "parapet": build_parapet,
            "drawbridge": build_drawbridge, "windmill": build_windmill, "sails": build_sails}

if __name__ == "__main__":
    for key in sys.argv[1:] or list(BUILDERS):
        BUILDERS[key]()
