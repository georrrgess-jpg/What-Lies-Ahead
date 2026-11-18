"""Castle Kingdom faire props (World 14, Royal Faire): pavilions, market stalls,
the half-timbered houses, the jousting stands and tilt barrier, the catapult and
hay targets, the dragon bouncy castle, palisade fences, banners, braziers, the
exit-trail lanterns, trees, the well, the training quintain, carts and clutter.

Each function builds one prop in a fresh scene and saves
art/blender/faire_<name>.blend + art/models/faire_<name>.glb. Origins sit at the
centre of the base; fronts face -Y (Godot +Z).

    python art/blender/build_faire_props.py              (all props)
    python art/blender/build_faire_props.py tent stall   (only these)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from faire_common import *  # noqa: F401,F403


def tent_stripe():
    """The recolourable stripe (the level overrides FaireTentA per prop)."""
    return mat("FaireTentA", FAIRE["Red"], rough=0.6)


def build_tent():
    """Round jousting pavilion, r 2.6 m, walls 2.4 m, striped cone to 5.6 m with a
    pennant; the door flaps are laced shut. Collide with a cylinder r 2.6."""
    reset_scene()
    a, cream, gold = tent_stripe(), fmat("Cream", rough=0.75), fmat("Gold", rough=0.35)
    R = 2.6
    p = [striped_drum("Wall", R, 0.0, 2.4, [a, cream], stripes=2, segs=24),
         cyl("Floor", R - 0.05, 0.08, (0, 0, 0.04), segs=24, bevel=0.0, m=fmat("WoodLight", rough=0.8)),
         striped_cone("Roof", R + 0.35, 2.35, 3.0, [a, cream], stripes=2, segs=24)]
    p += valance("Val", R + 0.32, 2.38, 24, a, gold, drop=0.42)
    p += [cyl("Pole", 0.07, 1.6, (0, 0, 6.1), segs=6, bevel=0.0, m=fmat("Timber")),
          sphere("PoleBall", 0.16, (0, 0, 5.35), m=gold, segs=10, rings=6),
          prism("Pennant", [(0, 0), (1.6, -0.25), (0, -0.5)], 0.04, (0.05, 0, 6.85), m=a)]
    # Laced door flaps on the front.
    p += [box("Flap", (1.2, 0.06, 2.1), (0, -R - 0.02, 1.05), bevel=0.02, m=cream),
          box("FlapSeam", (0.05, 0.08, 2.1), (0, -R - 0.05, 1.05), bevel=0.0, m=a)]
    for k in range(5):
        p.append(torus(f"Lace{k}", 0.07, 0.02, (0, -R - 0.08, 0.4 + k * 0.4), rot=(math.pi / 2, 0, 0), m=gold, major_segs=8, minor_segs=4))
    # Guy ropes and pegs.
    for k in range(6):
        ang = math.tau * (k + 0.5) / 6
        top = (math.cos(ang) * (R + 0.3), math.sin(ang) * (R + 0.3), 2.3)
        peg = (math.cos(ang) * (R + 1.3), math.sin(ang) * (R + 1.3), 0.05)
        p += [tube(f"Guy{k}", [top, peg], 0.015, m=fmat("Rope"), segs=4),
              cyl(f"Peg{k}", 0.05, 0.3, (peg[0], peg[1], 0.1), segs=6, bevel=0.0, m=fmat("Timber"))]
    save("faire_tent", [merge("Tent", p)])


def build_stall():
    """Market stall, 3.2 x 2.0 m: a counter (1 m), four posts, a striped sloping
    awning (2.3 m front, 2.9 m back), a back cloth, a sign and goods (loaves,
    apples, jugs, cheese). Collide with a 3.2 x 2.0 x 1.0 box (the awning
    overhangs the front by 0.6 m)."""
    reset_scene()
    a, cream, wood, timber, gold = tent_stripe(), fmat("Cream", rough=0.75), fmat("WoodLight", rough=0.75), fmat("Timber", rough=0.8), fmat("Gold", rough=0.35)
    W, D = 3.2, 2.0
    p = [box("Counter", (W, 0.7, 1.0), (0, -D / 2 + 0.35, 0.5), bevel=0.04, m=wood),
         box("CounterTop", (W + 0.1, 0.8, 0.08), (0, -D / 2 + 0.35, 1.02), bevel=0.02, m=timber),
         box("Back", (W, 0.06, 2.6), (0, D / 2 - 0.03, 1.3), bevel=0.02, m=cream),
         box("Table", (W - 0.2, 0.6, 0.06), (0, D / 2 - 0.4, 0.8), bevel=0.02, m=wood)]
    for s in (-1, 1):
        p.append(box(f"Side{s}", (0.05, D - 0.3, 1.0), (s * (W / 2 - 0.03), 0.1, 1.55), bevel=0.0, m=cream))
    for k in range(8):
        x = -W / 2 + (k + 0.5) * W / 8
        p.append(box(f"Skirt{k}", (W / 8, 0.05, 0.9), (x, -D / 2 - 0.02, 0.48), bevel=0.0, m=a if k % 2 == 0 else cream))
    for sx in (-1, 1):
        for sy, h in ((-1, 2.3), (1, 2.9)):
            p.append(cyl(f"Post{sx}{sy}", 0.06, h, (sx * (W / 2 - 0.05), sy * (D / 2 - 0.05) - (0.6 if sy < 0 else 0), h / 2), segs=8, bevel=0.0, m=timber))
    # The awning: striped slats from the back top down over the front posts.
    n = 8
    y0, z0, y1, z1 = D / 2, 2.95, -D / 2 - 0.75, 2.25
    ln = math.hypot(y1 - y0, z1 - z0)
    ang = math.atan2(z1 - z0, -(y1 - y0))
    for k in range(n):
        x = -W / 2 - 0.15 + (k + 0.5) * (W + 0.3) / n
        p.append(box(f"Awn{k}", ((W + 0.3) / n, ln, 0.05), (x, (y0 + y1) / 2, (z0 + z1) / 2), rot=(ang, 0, 0), bevel=0.0, m=a if k % 2 == 0 else cream))
    for k in range(10):
        x = -W / 2 - 0.15 + (k + 0.5) * (W + 0.3) / 10
        p.append(prism(f"Tab{k}", [(-0.17, 0), (0.17, 0), (0, -0.28)], 0.03, (x, y1 - 0.02, z1 + 0.02), m=gold if k % 2 else a))
    # The sign over the awning.
    p += [box("Sign", (1.4, 0.08, 0.45), (0, -D / 2 - 0.2, 3.05), bevel=0.03, m=timber),
          box("SignFace", (1.25, 0.1, 0.32), (0, -D / 2 - 0.22, 3.05), bevel=0.02, m=gold)]
    # Goods on the counter and the back table.
    rr = random.Random(11)
    for k in range(4):
        x = -1.2 + k * 0.32
        p.append(sphere(f"Loaf{k}", 0.16, (x, -D / 2 + 0.3, 1.13), scale=(1.4, 0.8, 0.6), m=fmat("Wood", rough=0.7), segs=10, rings=6))
    for k in range(7):
        x, y = 0.35 + rr.uniform(-0.25, 0.25), -D / 2 + 0.35 + rr.uniform(-0.15, 0.15)
        p.append(sphere(f"Apple{k}", 0.08, (x, y, 1.13), m=fmat("Red", rough=0.4) if k % 3 else fmat("Green", rough=0.4), segs=8, rings=5))
    p += [cyl("Basket", 0.32, 0.18, (0.35, -D / 2 + 0.35, 1.1), segs=12, bevel=0.02, m=fmat("Hay", rough=0.8)),
          cyl("Cheese", 0.24, 0.16, (1.15, -D / 2 + 0.35, 1.14), segs=14, bevel=0.03, m=fmat("Yellow", rough=0.6))]
    for k in range(4):
        x = -1.1 + k * 0.7
        p += [cyl(f"Jug{k}", 0.13, 0.32, (x, D / 2 - 0.4, 0.99), segs=10, bevel=0.03, m=fmat("Blue", rough=0.4) if k % 2 else fmat("RoofDark", rough=0.5),
                  radius_top=0.08),
              cyl(f"JugNeck{k}", 0.06, 0.1, (x, D / 2 - 0.4, 1.19), segs=8, bevel=0.0, m=fmat("Cream"))]
    save("faire_stall", [merge("Stall", p)])


def build_house():
    """Half-timbered village house, 6 x 5 m: stone ground floor (3 m), a jettied
    plaster-and-timber upper floor, a steep tiled roof (ridge 9 m) with a
    chimney, shuttered windows, flower boxes and a door with a lamp on every
    side that shows. Collide with a 6 x 5 x 5.5 box (and the roof above)."""
    reset_scene()
    st, plaster, timber = stone(), fmat("Plaster", rough=0.8), fmat("Timber", rough=0.8)
    roof, blue, flower = mat("FaireRoofTile", FAIRE["Roof"], rough=0.7), fmat("Blue", rough=0.5), fmat("Flower", rough=0.5)
    W, D = 6.0, 5.0
    jet = 0.35
    p = [box("Ground", (W, D, 3.0), (0, 0, 1.5), bevel=0.05, m=st),
         box("Upper", (W + jet * 2, D + jet * 2, 2.8), (0, 0, 4.4), bevel=0.04, m=plaster),
         box("Joists", (W + jet * 2 + 0.1, D + jet * 2 + 0.1, 0.22), (0, 0, 3.05), bevel=0.03, m=timber)]
    for face in (-1, 1):
        y = face * (D / 2 + jet + 0.03)
        p += timber_frame(f"Frame{face}", -W / 2 - jet, W / 2 + jet, y, 3.0, 5.8, timber, posts=4)
        for k, x in enumerate((-1.7, 1.7)):
            p += [box(f"Win{face}{k}", (0.9, 0.1, 1.0), (x, y + face * 0.02, 4.5), bevel=0.02, m=fglow("FaireWindowDim", "#f3d79a", 0.5)),
                  box(f"ShutL{face}{k}", (0.45, 0.08, 1.1), (x - 0.7, y + face * 0.05, 4.5), bevel=0.02, m=blue),
                  box(f"ShutR{face}{k}", (0.45, 0.08, 1.1), (x + 0.7, y + face * 0.05, 4.5), bevel=0.02, m=blue),
                  box(f"Box{face}{k}", (1.1, 0.3, 0.22), (x, y + face * 0.18, 3.85), bevel=0.03, m=timber)]
            for j in range(4):
                p.append(sphere(f"Fl{face}{k}{j}", 0.1, (x - 0.38 + j * 0.25, y + face * 0.2, 4.03), m=flower if j % 2 else fmat("Yellow"), segs=6, rings=4))
        # Ground floor: a door and a window.
        dy = face * (D / 2 + 0.02)
        p += [box(f"Door{face}", (1.1, 0.1, 2.1), (-1.4, dy, 1.05), bevel=0.03, m=timber),
              box(f"DoorFrame{face}", (1.4, 0.06, 2.35), (-1.4, dy - face * 0.02, 1.17), bevel=0.02, m=fmat("StoneLight")),
              sphere(f"Knob{face}", 0.06, (-1.0, dy + face * 0.07, 1.05), m=fmat("Gold"), segs=6, rings=4),
              box(f"GWin{face}", (1.0, 0.1, 0.9), (1.4, dy, 1.7), bevel=0.02, m=fglow("FaireWindowDim", "#f3d79a", 0.5)),
              box(f"GWinSill{face}", (1.2, 0.2, 0.1), (1.4, dy + face * 0.06, 1.2), bevel=0.02, m=fmat("StoneLight")),
              box(f"GWinBar{face}", (0.06, 0.12, 0.9), (1.4, dy + face * 0.02, 1.7), bevel=0.0, m=timber),
              box(f"Lamp{face}", (0.2, 0.2, 0.3), (-0.55, dy + face * 0.2, 2.45), bevel=0.03, m=fglow("FaireLamp", "#ffcf6a", 2.0)),
              box(f"LampArm{face}", (0.06, 0.3, 0.06), (-0.55, dy + face * 0.1, 2.65), bevel=0.0, m=fmat("IronDark"))]
    for s in (-1, 1):
        x = s * (W / 2 + jet + 0.03)
        for k in range(3):
            y = -D / 2 - jet + (k + 0.5) * (D + 2 * jet) / 3
            p.append(box(f"SidePost{s}{k}", (0.12, 0.16, 2.8), (x, y, 4.4), bevel=0.02, m=timber))
        p.append(box(f"SideWin{s}", (0.1, 0.8, 0.9), (x + s * 0.02, 0, 4.6), bevel=0.02, m=fglow("FaireWindowDim", "#f3d79a", 0.5)))
    # Steep roof: two slopes (ridge along X) with gable ends in plaster.
    rh, rw = 3.2, D / 2 + jet + 0.45
    for s in (-1, 1):
        ln = math.hypot(rw, rh)
        ang = math.atan2(rh, rw)
        p.append(box(f"Slope{s}", (W + jet * 2 + 0.6, ln, 0.22), (0, s * rw / 2, 5.8 + rh / 2), rot=(s * ang, 0, 0), bevel=0.04, m=roof))
        for k in range(4):
            t = (k + 0.5) / 4
            p.append(box(f"Tile{s}{k}", (W + jet * 2 + 0.62, 0.08, 0.08), (0, s * rw * (1 - t), 5.8 + rh * t + 0.13), bevel=0.02,
                         m=mat("FaireRoofTileDark", FAIRE["RoofDark"], rough=0.7)))
    for s in (-1, 1):
        p.append(prism(f"Gable{s}", [(-rw + 0.25, 0), (rw - 0.25, 0), (0, rh - 0.25)], 0.2, (s * (W / 2 + jet - 0.05), 0, 5.8), rot=(0, 0, math.pi / 2),
                       m=plaster))
        p.append(tube(f"GableBeam{s}", [(s * (W / 2 + jet + 0.06), -rw + 0.3, 5.85), (s * (W / 2 + jet + 0.06), 0, 5.8 + rh - 0.35),
                                         (s * (W / 2 + jet + 0.06), rw - 0.3, 5.85)], 0.08, m=timber, segs=4))
    p += [box("Ridge", (W + jet * 2 + 0.7, 0.3, 0.25), (0, 0, 5.8 + rh + 0.05), bevel=0.05, m=mat("FaireRoofTileDark", FAIRE["RoofDark"], rough=0.7)),
          box("Chimney", (0.8, 0.8, 2.6), (W / 2 - 1.0, 0.9, 7.9), bevel=0.05, m=st),
          box("ChimneyCap", (1.0, 1.0, 0.2), (W / 2 - 1.0, 0.9, 9.25), bevel=0.04, m=fmat("StoneDark"))]
    save("faire_house", [merge("House", p)])


def build_stands():
    """Jousting stands: a royal gallery 12 x 3.5 m, deck at 2.4 m, a front rail,
    striped drapes to the ground, benches and a striped canopy on six poles
    (5.6 m). Collide with a 12 x 3.5 x 2.4 box, rails 1.1 m above the deck."""
    reset_scene()
    a, cream, gold, wood, timber = tent_stripe(), fmat("Cream", rough=0.75), fmat("Gold", rough=0.35), fmat("WoodLight", rough=0.75), fmat("Timber", rough=0.8)
    blue = fmat("Blue", rough=0.5)
    W, D, H = 12.0, 3.5, 2.4
    p = [box("Deck", (W, D, 0.25), (0, 0, H - 0.125), bevel=0.03, m=wood),
         box("Under", (W - 0.2, D - 0.2, H - 0.25), (0, 0, (H - 0.25) / 2), bevel=0.02, m=timber)]
    for k in range(16):
        x = -W / 2 + (k + 0.5) * W / 16
        p.append(box(f"Drape{k}", (W / 16, 0.05, H - 0.2), (x, -D / 2 - 0.03, (H - 0.2) / 2 + 0.05), bevel=0.0, m=blue if k % 2 == 0 else gold))
    for k in range(12):
        x = -W / 2 + (k + 0.5) * W / 12
        p.append(prism(f"DTab{k}", [(-0.25, 0), (0.25, 0), (0, -0.4)], 0.04, (x, -D / 2 - 0.07, H - 0.05), m=a))
    for s in (-1, 1):
        p.append(box(f"SideDrape{s}", (0.05, D, H - 0.2), (s * (W / 2 + 0.02), 0, (H - 0.2) / 2 + 0.05), bevel=0.0, m=cream))
    p += [box("RailF", (W, 0.12, 0.12), (0, -D / 2 + 0.08, H + 1.05), bevel=0.02, m=gold),
          box("RailB", (W, 0.12, 0.12), (0, D / 2 - 0.08, H + 1.05), bevel=0.02, m=gold)]
    for k in range(9):
        x = -W / 2 + 0.1 + k * (W - 0.2) / 8
        for y in (-D / 2 + 0.08, D / 2 - 0.08):
            p.append(box(f"Baluster{k}{y}", (0.1, 0.1, 1.05), (x, y, H + 0.52), bevel=0.0, m=timber))
    for k in range(3):
        p.append(box(f"Bench{k}", (3.0, 0.45, 0.45), (-4.0 + k * 4.0, 0.9, H + 0.22), bevel=0.04, m=timber))
    for k, x in enumerate((-W / 2 + 0.15, 0.0, W / 2 - 0.15)):
        for y in (-D / 2 + 0.15, D / 2 - 0.15):
            p.append(cyl(f"Pole{k}{y}", 0.08, 3.4, (x, y, H + 1.7), segs=8, bevel=0.0, m=gold))
    n = 12
    for k in range(n):
        x = -W / 2 - 0.2 + (k + 0.5) * (W + 0.4) / n
        p.append(box(f"Canopy{k}", ((W + 0.4) / n, D + 0.4, 0.06), (x, 0, H + 3.45), rot=(0.06, 0, 0), bevel=0.0, m=a if k % 2 == 0 else cream))
    for k in range(14):
        x = -W / 2 - 0.2 + (k + 0.5) * (W + 0.4) / 14
        p.append(prism(f"CTab{k}", [(-0.21, 0), (0.21, 0), (0, -0.35)], 0.03, (x, -D / 2 - 0.2, H + 3.36), m=gold if k % 2 else a))
    p += [banner_cloth("Banner", 1.4, 1.6, (0, -D / 2 - 0.12, H - 0.1), fmat("Red", rough=0.55)),
          crown_flat("Crown", (0, -D / 2 - 0.17, H - 1.05), 0.7, gold)]
    save("faire_stands", [merge("Stands", p)])


def build_tilt():
    """Tilt barrier module, 3 m along X: a red-and-white striped board on posts,
    1.3 m tall. Rows of these divide the jousting list."""
    reset_scene()
    red, white, timber = fmat("Red", rough=0.55), fmat("White", rough=0.7), fmat("Timber", rough=0.8)
    p = [box("Post0", (0.18, 0.18, 1.35), (-1.4, 0, 0.675), bevel=0.03, m=timber), box("Post1", (0.18, 0.18, 1.35), (1.4, 0, 0.675), bevel=0.03, m=timber)]
    for k in range(6):
        x = -1.5 + (k + 0.5) * 0.5
        p.append(box(f"Board{k}", (0.5, 0.1, 0.7), (x, 0, 0.85), bevel=0.0, m=red if k % 2 == 0 else white))
    p.append(box("Cap", (3.0, 0.16, 0.1), (0, 0, 1.25), bevel=0.02, m=fmat("Gold", rough=0.4)))
    save("faire_tilt", [merge("Tilt", p)])


def build_palisade():
    """Palisade fence module, 3 m along X: pointed log stakes 2.6 m tall on two
    rails. The faire's outer boundary."""
    reset_scene()
    wood, dark = fmat("Wood", rough=0.85), fmat("Timber", rough=0.85)
    rr = random.Random(5)
    p = []
    for k in range(10):
        x = -1.5 + (k + 0.5) * 0.3
        h = 2.4 + rr.uniform(-0.15, 0.2)
        p += [cyl(f"Log{k}", 0.15, h, (x, 0, h / 2), segs=8, bevel=0.02, m=wood if k % 2 else dark),
              cyl(f"Tip{k}", 0.15, 0.4, (x, 0, h + 0.2), segs=8, bevel=0.0, m=wood if k % 2 else dark, radius_top=0.01)]
    for z in (0.7, 1.9):
        p.append(box(f"Rail{z}", (3.0, 0.14, 0.18), (0, 0.17, z), bevel=0.03, m=dark))
    save("faire_palisade", [merge("Palisade", p)])


def build_fence():
    """Low post-and-rail field fence module, 3 m along X, 1.1 m tall."""
    reset_scene()
    wood, dark = fmat("WoodLight", rough=0.8), fmat("Timber", rough=0.8)
    p = [box("Post0", (0.16, 0.16, 1.15), (-1.42, 0, 0.575), bevel=0.03, m=dark), box("Post1", (0.16, 0.16, 1.15), (1.42, 0, 0.575), bevel=0.03, m=dark)]
    for z in (0.45, 0.95):
        p.append(box(f"Rail{z}", (3.0, 0.1, 0.14), (0, 0, z), bevel=0.02, m=wood))
    save("faire_fence", [merge("Fence", p)])


def build_banner():
    """Banner pole, 6 m: a gilded pole with a crossbar and a long swallowtail
    banner (FaireBanner: recoloured per pole) with a crown, on a stone foot."""
    reset_scene()
    gold, cloth = fmat("Gold", rough=0.35), mat("FaireBanner", FAIRE["Blue"], rough=0.6)
    p = [cyl("Foot", 0.35, 0.4, (0, 0, 0.2), segs=10, bevel=0.04, m=fmat("StoneDark")),
         cyl("Pole", 0.07, 6.0, (0, 0, 3.0), segs=8, bevel=0.0, m=gold),
         sphere("Top", 0.16, (0, 0, 6.1), m=gold, segs=10, rings=6),
         box("Bar", (1.4, 0.1, 0.1), (0, -0.12, 5.6), bevel=0.02, m=gold),
         banner_cloth("Cloth", 1.2, 3.0, (0, -0.15, 5.55), cloth),
         crown_flat("Crown", (0, -0.2, 4.0), 0.6, gold)]
    save("faire_banner", [merge("Banner", p)])


def build_brazier():
    """Standing iron brazier, 1.6 m, with a glowing coal bowl and flame."""
    reset_scene()
    iron = fmat("IronDark", rough=0.5)
    p = [cyl("Bowl", 0.45, 0.35, (0, 0, 1.45), segs=12, bevel=0.03, m=iron, radius_top=0.55),
         cyl("Coals", 0.45, 0.06, (0, 0, 1.6), segs=12, bevel=0.0, m=fglow("FaireCoal", "#ff7a2a", 2.5)),
         sphere("Flame", 0.35, (0, 0, 1.95), scale=(1, 1, 1.5), m=fglow("FaireFlame", "#ffb347", 3.5), segs=10, rings=6),
         cyl("Ring", 0.3, 0.06, (0, 0, 0.5), segs=10, bevel=0.0, m=iron)]
    for k in range(3):
        a = math.tau * k / 3
        p.append(tube(f"Leg{k}", [(math.cos(a) * 0.5, math.sin(a) * 0.5, 0.0), (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.5),
                                  (math.cos(a) * 0.42, math.sin(a) * 0.42, 1.35)], 0.05, m=iron, segs=5))
    save("faire_brazier", [merge("Brazier", p)])


def build_exit_lantern():
    """Exit-trail lantern post, 2.2 m: a timber post with a gold-capped hanging
    lantern (glass FaireExitGlow, lit by faire_exit_lantern.gd) and a pennant."""
    reset_scene()
    timber, gold, iron = fmat("Timber", rough=0.8), fmat("Gold", rough=0.35), fmat("IronDark", rough=0.5)
    p = [cyl("Post", 0.08, 2.2, (0, 0, 1.1), segs=8, bevel=0.0, m=timber),
         box("Arm", (0.7, 0.08, 0.08), (0.3, 0, 2.1), bevel=0.0, m=iron),
         cyl("Cap", 0.2, 0.18, (0.55, 0, 1.75), segs=8, bevel=0.02, m=gold, radius_top=0.05),
         cyl("Glass", 0.15, 0.36, (0.55, 0, 1.48), segs=8, bevel=0.0, m=fglow("FaireExitGlow", "#ffd36a", 1.0)),
         cyl("Base", 0.18, 0.08, (0.55, 0, 1.27), segs=8, bevel=0.0, m=gold),
         tube("Hook", [(0.55, 0, 1.84), (0.55, 0, 2.08)], 0.02, m=iron, segs=4),
         prism("Pennant", [(0, 0), (0.6, -0.12), (0, -0.24)], 0.03, (0.04, 0, 2.15), rot=(0, 0, math.pi / 2), m=fmat("Red", rough=0.55)),
         cyl("Foot", 0.25, 0.15, (0, 0, 0.075), segs=8, bevel=0.03, m=fmat("StoneDark"))]
    save("faire_exit_lantern", [merge("ExitLantern", p)])


def build_tree():
    """Round storybook tree, ~5.5 m: a chunky trunk with three leafy blobs."""
    reset_scene()
    leaf, leaf2, bark = fmat("Leaf", rough=0.8), fmat("LeafDark", rough=0.8), fmat("Timber", rough=0.85)
    p = [cyl("Trunk", 0.32, 2.6, (0, 0, 1.3), segs=10, bevel=0.04, m=bark, radius_top=0.22),
         sphere("BlobA", 1.6, (0, 0, 3.6), scale=(1, 1, 0.92), m=leaf, segs=14, rings=9),
         sphere("BlobB", 1.15, (0.9, 0.4, 3.0), m=leaf2, segs=12, rings=8),
         sphere("BlobC", 1.0, (-0.8, -0.5, 4.5), m=leaf, segs=12, rings=8)]
    save("faire_tree", [merge("Tree", p)])


def build_pine():
    """Toy pine, ~7 m: three stacked green cones on a short trunk."""
    reset_scene()
    leaf, leaf2, bark = fmat("GreenDark", rough=0.8), fmat("LeafDark", rough=0.8), fmat("Timber", rough=0.85)
    p = [cyl("Trunk", 0.25, 1.4, (0, 0, 0.7), segs=8, bevel=0.03, m=bark)]
    for k, (r, z, h) in enumerate(((2.0, 1.0, 2.8), (1.6, 2.6, 2.6), (1.15, 4.1, 2.6))):
        p.append(cyl(f"Cone{k}", r, h, (0, 0, z + h / 2), segs=10, bevel=0.05, m=leaf if k % 2 == 0 else leaf2, radius_top=0.05))
    save("faire_pine", [merge("Pine", p)])


def build_hay():
    """A stack of three square hay bales (2.4 x 1.2 m, 1.4 m tall)."""
    reset_scene()
    hay, dark, twine = fmat("Hay", rough=0.9), fmat("HayDark", rough=0.9), fmat("Timber", rough=0.8)
    p = []
    for k, (x, z) in enumerate(((-0.6, 0.35), (0.6, 0.35), (0.0, 1.05))):
        p.append(box(f"Bale{k}", (1.18, 1.18, 0.7), (x, 0, z), bevel=0.1, m=hay if k != 1 else dark))
        for dx in (-0.3, 0.3):
            p.append(box(f"Twine{k}{dx}", (0.05, 1.22, 0.74), (x + dx, 0, z), bevel=0.0, m=twine))
    rr = random.Random(3)
    for k in range(10):
        p.append(box(f"Straw{k}", (0.03, 0.03, 0.3), (rr.uniform(-1.1, 1.1), rr.uniform(-0.55, 0.55), 0.05), rot=(1.4, rr.uniform(0, 3), 0), bevel=0.0, m=hay))
    save("faire_hay", [merge("Hay", p)])


def build_hay_target():
    """Archery butt: a round straw target (red, white and gold rings) on a
    wooden easel, an arrow or two in it, 2.2 m tall."""
    reset_scene()
    timber = fmat("Timber", rough=0.8)
    p = [box("LegA", (0.12, 0.12, 2.3), (-0.6, 0.25, 1.1), rot=(0.18, 0, 0), bevel=0.02, m=timber),
         box("LegB", (0.12, 0.12, 2.3), (0.6, 0.25, 1.1), rot=(0.18, 0, 0), bevel=0.02, m=timber),
         box("LegC", (0.12, 0.12, 2.1), (0, 0.9, 1.0), rot=(-0.38, 0, 0), bevel=0.02, m=timber),
         cyl("Straw", 0.85, 0.35, (0, 0, 1.3), rot=(math.pi / 2, 0, 0), segs=20, bevel=0.06, m=fmat("Hay", rough=0.9))]
    for k, (r, col) in enumerate(((0.75, "White"), (0.58, "Red"), (0.4, "White"), (0.22, "Gold"))):
        p.append(cyl(f"Ring{k}", r, 0.04, (0, -0.18 - k * 0.012, 1.3), rot=(math.pi / 2, 0, 0), segs=24, bevel=0.0, m=fmat(col, rough=0.6)))
    for k, (x, z) in enumerate(((0.15, 1.42), (-0.3, 1.1))):
        p += [cyl(f"Arrow{k}", 0.02, 0.7, (x, -0.5, z), rot=(math.pi / 2 - 0.12, 0, 0), segs=4, bevel=0.0, m=fmat("WoodLight")),
              prism(f"Fletch{k}", [(0, 0), (0.12, 0.08), (0, 0.22)], 0.01, (x, -0.82, z + 0.04), rot=(0, 0, 0), m=fmat("Red"))]
    save("faire_hay_target", [merge("HayTarget", p)])


def build_barrels():
    """A cluster of three barrels (one on its side), 1.9 x 1.3 m."""
    reset_scene()
    wood, iron = fmat("Wood", rough=0.8), fmat("IronDark", rough=0.5)

    def barrel(prefix, loc, rot=(0, 0, 0)):
        prof = [(0.36, 0.0), (0.44, 0.45), (0.36, 0.9)]
        parts = [lathe(prefix + "Body", prof, [wood], segs=14, smooth=True)]
        for z in (0.15, 0.75):
            parts.append(torus(prefix + f"Hoop{z}", 0.4, 0.025, (0, 0, z), m=iron, major_segs=14, minor_segs=4))
        parts.append(cyl(prefix + "Lid", 0.34, 0.03, (0, 0, 0.9), segs=14, bevel=0.0, m=fmat("Timber")))
        for ob in parts:
            ob.matrix_world = Matrix.Translation(Vector(loc)) @ Euler(rot, "XYZ").to_matrix().to_4x4() @ ob.matrix_basis
        return parts

    p = barrel("A", (-0.5, 0.15, 0)) + barrel("B", (0.45, 0.25, 0)) + barrel("C", (0.0, -0.4, 0.42), rot=(0, math.pi / 2, 0.4))
    save("faire_barrels", [merge("Barrels", p)])


def build_crates():
    """Two stacked crates and a sack, 1.6 x 1.2 x 1.5 m."""
    reset_scene()
    wood, dark = fmat("WoodLight", rough=0.8), fmat("Timber", rough=0.8)
    p = []
    for k, (x, z, s, r) in enumerate(((-0.25, 0.45, 0.9, 0.1), (0.2, 1.2, 0.6, -0.3))):
        p.append(box(f"Crate{k}", (s, s, s), (x, 0, z if k else s / 2), rot=(0, 0, r), bevel=0.05, m=wood))
        for d in (-1, 1):
            p.append(box(f"Slat{k}{d}", (s + 0.02, s * 0.14, s * 0.14), (x, 0, (z if k else s / 2) + d * s * 0.36), rot=(0, 0, r), bevel=0.02, m=dark))
    p.append(sphere("Sack", 0.35, (0.55, -0.15, 0.3), scale=(1, 0.9, 0.9), m=fmat("Cream", rough=0.9), segs=10, rings=7))
    save("faire_crates", [merge("Crates", p)])


def build_catapult():
    """Toy catapult, 3.4 x 2.0 m: an A-frame on four wheels, the arm cocked
    back with a hay-and-stone ball in its spoon, a winch."""
    reset_scene()
    wood, timber, iron = fmat("Wood", rough=0.8), fmat("Timber", rough=0.8), fmat("IronDark", rough=0.5)
    p = []
    for s in (-1, 1):
        p += [box(f"Rail{s}", (0.25, 3.4, 0.3), (s * 0.85, 0, 0.75), bevel=0.04, m=timber),
              box(f"UpA{s}", (0.2, 0.2, 2.3), (s * 0.85, -0.5, 1.8), rot=(0.35, 0, 0), bevel=0.03, m=wood),
              box(f"UpB{s}", (0.2, 0.2, 2.3), (s * 0.85, 0.5, 1.8), rot=(-0.35, 0, 0), bevel=0.03, m=wood)]
        for y in (-1.2, 1.2):
            wl = wheel(f"Wheel{s}{y}", 0.55, (0, 0, 0), wood, hub=iron)
            for ob in wl:
                ob.matrix_world = Matrix.Translation(Vector((s * 1.08, y, 0.55))) @ Euler((0, 0, math.pi / 2), "XYZ").to_matrix().to_4x4() @ ob.matrix_basis
            p += wl
    p += [box("CrossA", (1.9, 0.25, 0.25), (0, -1.3, 0.75), bevel=0.03, m=timber),
          box("CrossB", (1.9, 0.25, 0.25), (0, 1.3, 0.75), bevel=0.03, m=timber),
          cyl("Axle", 0.12, 1.9, (0, 0, 2.85), rot=(0, math.pi / 2, 0), segs=10, bevel=0.0, m=iron),
          box("Arm", (0.25, 3.2, 0.25), (0, 1.2, 2.3), rot=(-0.38, 0, 0), bevel=0.04, m=wood),
          cyl("Spoon", 0.42, 0.25, (0, 2.6, 1.85), segs=12, bevel=0.04, m=timber, radius_top=0.5),
          sphere("Ball", 0.42, (0, 2.6, 2.25), m=fmat("StoneDark", rough=0.85), segs=12, rings=8),
          cyl("Winch", 0.22, 1.5, (0, -1.0, 1.1), rot=(0, math.pi / 2, 0), segs=10, bevel=0.02, m=timber),
          tube("Rope", [(0, -1.0, 1.3), (0, 0.4, 2.7)], 0.04, m=fmat("Rope"), segs=5),
          box("Counter", (0.9, 0.7, 0.7), (0, -0.3, 3.4), rot=(-0.38, 0, 0), bevel=0.06, m=fmat("Stone"))]
    save("faire_catapult", [merge("Catapult", p)])


def build_well():
    """Village well: a round stone wall (r 1.0, 0.9 m), two posts, a little
    tiled roof, the winding drum, a rope and a bucket. Collide with a cylinder."""
    reset_scene()
    st, timber, roof = stone(), fmat("Timber", rough=0.8), mat("FaireRoofTile", FAIRE["Roof"], rough=0.7)
    p = [lathe("Wall", [(1.0, 0), (1.05, 0.9), (0.75, 0.9), (0.75, 0.1)], [st], segs=18, smooth=False),
         cyl("Water", 0.76, 0.05, (0, 0, 0.5), segs=18, bevel=0.0, m=fmat("Water", rough=0.15)),
         cyl("Rim", 1.08, 0.12, (0, 0, 0.95), segs=18, bevel=0.03, m=fmat("StoneLight"))]
    for s in (-1, 1):
        p.append(box(f"Post{s}", (0.16, 0.16, 2.2), (s * 0.9, 0, 2.0), bevel=0.02, m=timber))
        p.append(box(f"Roof{s}", (2.4, 0.9, 0.1), (0, s * 0.38, 3.15), rot=(s * 0.6, 0, 0), bevel=0.02, m=roof))
    p += [cyl("Drum", 0.15, 1.7, (0, 0, 2.3), rot=(0, math.pi / 2, 0), segs=10, bevel=0.0, m=fmat("Wood")),
          tube("Rope", [(0.1, 0, 2.15), (0.1, 0, 1.5)], 0.02, m=fmat("Rope"), segs=4),
          cyl("Bucket", 0.16, 0.25, (0.1, 0, 1.38), segs=10, bevel=0.02, m=fmat("Wood"), radius_top=0.19),
          tube("Crank", [(0.95, 0, 2.3), (1.1, 0, 2.3), (1.1, 0, 2.05)], 0.03, m=fmat("IronDark"), segs=4)]
    save("faire_well", [merge("Well", p)])


def build_dummy():
    """Training quintain: a post with a turning cross-arm, a shield on one end
    and a sandbag on the other, on a stone base (the level spins the arm)."""
    reset_scene()
    timber = fmat("Timber", rough=0.8)
    p = [cyl("Base", 0.45, 0.3, (0, 0, 0.15), segs=10, bevel=0.04, m=fmat("StoneDark")),
         cyl("Post", 0.1, 2.0, (0, 0, 1.1), segs=8, bevel=0.0, m=timber),
         sphere("Head", 0.28, (0, 0, 2.35), m=fmat("Hay", rough=0.9), segs=10, rings=7),
         box("Arm", (2.4, 0.14, 0.14), (0, 0, 2.0), bevel=0.02, m=timber),
         prism("Shield", [(-0.35, 0.4), (0.35, 0.4), (0.35, -0.05), (0, -0.45), (-0.35, -0.05)], 0.08, (-1.1, -0.1, 1.75), m=fmat("Red", rough=0.5)),
         crown_flat("ShieldCrown", (-1.1, -0.16, 1.68), 0.36, fmat("Gold")),
         tube("BagRope", [(1.1, 0, 2.0), (1.1, 0, 1.55)], 0.02, m=fmat("Rope"), segs=4),
         sphere("Bag", 0.25, (1.1, 0, 1.3), scale=(1, 1, 1.3), m=fmat("Cream", rough=0.9), segs=10, rings=6)]
    save("faire_dummy", [merge("Dummy", p)])


def build_cart():
    """Two-wheeled hay cart, 3.2 x 1.7 m, heaped with hay, shafts resting down."""
    reset_scene()
    wood, timber = fmat("Wood", rough=0.8), fmat("Timber", rough=0.8)
    p = [box("Bed", (1.6, 2.4, 0.15), (0, 0.2, 0.85), bevel=0.03, m=wood)]
    for s in (-1, 1):
        p += [box(f"Side{s}", (0.08, 2.4, 0.5), (s * 0.78, 0.2, 1.15), bevel=0.02, m=timber),
              tube(f"Shaft{s}", [(s * 0.55, -0.9, 0.85), (s * 0.5, -2.2, 0.15)], 0.06, m=timber, segs=5)]
        wl = wheel(f"Wheel{s}", 0.65, (0, 0, 0), wood, hub=fmat("IronDark"))
        for ob in wl:
            ob.matrix_world = Matrix.Translation(Vector((s * 0.95, 0.4, 0.65))) @ Euler((0, 0, math.pi / 2), "XYZ").to_matrix().to_4x4() @ ob.matrix_basis
        p += wl
    p += [box("Front", (1.6, 0.08, 0.5), (0, -1.0, 1.15), bevel=0.02, m=timber),
          sphere("HayHeap", 0.95, (0, 0.25, 1.3), scale=(0.85, 1.25, 0.6), m=fmat("Hay", rough=0.9), segs=12, rings=8)]
    save("faire_cart", [merge("Cart", p)])


def build_bench():
    """A plank bench, 1.8 m."""
    reset_scene()
    wood, timber = fmat("WoodLight", rough=0.8), fmat("Timber", rough=0.8)
    p = [box("Seat", (1.8, 0.4, 0.08), (0, 0, 0.46), bevel=0.02, m=wood)]
    for x in (-0.7, 0.7):
        p.append(box(f"Leg{x}", (0.1, 0.36, 0.44), (x, 0, 0.22), bevel=0.02, m=timber))
    save("faire_bench", [merge("Bench", p)])


def build_dragon():
    """The dragon bouncy castle, 7 x 6 m: a puffy green bouncing floor with
    striped corner turrets, inflated walls, a big friendly dragon rising at the
    back (head ~7.5 m), wings and a curled tail. Collide with a 7 x 6 x 2.6 box
    and a post under the neck."""
    reset_scene()
    green, green2, yellow, red, white = fmat("Green", rough=0.4), fmat("GreenDark", rough=0.4), fmat("Yellow", rough=0.4), fmat("Red", rough=0.4), fmat("White", rough=0.4)
    purple = fmat("Purple", rough=0.4)
    W, D = 7.0, 6.0
    p = [box("Floor", (W, D, 0.7), (0, 0, 0.35), bevel=0.3, segs=3, m=green2)]
    # Puffy walls (three sides; the front is the open entrance with a low step).
    for s in (-1, 1):
        p.append(box(f"WallS{s}", (0.7, D - 1.2, 2.2), (s * (W / 2 - 0.35), 0, 1.6), bevel=0.32, segs=3, m=green))
    p.append(box("WallB", (W - 1.2, 0.7, 2.6), (0, D / 2 - 0.35, 1.8), bevel=0.32, segs=3, m=green))
    p.append(box("Step", (W - 1.6, 0.8, 0.45), (0, -D / 2 - 0.2, 0.22), bevel=0.2, segs=3, m=yellow))
    for k in range(5):
        x = -2.4 + k * 1.2
        p.append(sphere(f"Puff{k}", 0.5, (x, -D / 2 + 0.3, 0.95), scale=(1.1, 0.8, 0.7), m=red if k % 2 else yellow, segs=12, rings=8))
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        x, y = sx * (W / 2 - 0.45), sy * (D / 2 - 0.45)
        p.append(cyl(f"Turret{i}", 0.6, 3.2, (x, y, 1.6), segs=16, bevel=0.25, m=yellow))
        for k in range(3):
            p.append(torus(f"TBand{i}{k}", 0.62, 0.12, (x, y, 0.9 + k * 0.9), m=red, major_segs=16, minor_segs=6))
        p.append(cyl(f"TCone{i}", 0.75, 1.3, (x, y, 3.85), segs=16, bevel=0.15, m=red, radius_top=0.08))
        p.append(sphere(f"TBall{i}", 0.2, (x, y, 4.6), m=yellow, segs=10, rings=6))
    # The dragon: body behind the back wall, neck up and over, a big head.
    neck = [(0, D / 2 + 0.4, 1.8), (0, D / 2 + 0.2, 3.5), (0, D / 2 - 0.4, 5.2), (0, D / 2 - 1.1, 6.3)]
    p.append(tube("Neck", neck, 0.85, m=green, segs=14, radius_end=0.6))
    p.append(sphere("Body", 1.8, (0, D / 2 + 0.7, 1.6), scale=(1.3, 1.0, 0.9), m=green, segs=16, rings=10))
    p.append(sphere("Belly", 1.2, (0, D / 2 + 0.2, 2.2), scale=(1.0, 0.8, 1.2), m=yellow, segs=14, rings=8))
    hx, hy, hz = 0, D / 2 - 1.6, 6.8
    p += [sphere("Head", 1.1, (hx, hy, hz), scale=(1.0, 1.25, 0.9), m=green, segs=16, rings=10),
          sphere("Snout", 0.75, (hx, hy - 1.0, hz - 0.25), scale=(1.0, 1.0, 0.75), m=green, segs=14, rings=8),
          sphere("Nostril0", 0.12, (hx - 0.3, hy - 1.7, hz - 0.05), m=green2, segs=8, rings=5),
          sphere("Nostril1", 0.12, (hx + 0.3, hy - 1.7, hz - 0.05), m=green2, segs=8, rings=5),
          box("Smile", (0.9, 0.1, 0.1), (hx, hy - 1.6, hz - 0.55), bevel=0.04, m=fmat("RedDark"))]
    for s in (-1, 1):
        p += [sphere(f"Eye{s}", 0.32, (hx + s * 0.5, hy - 0.6, hz + 0.45), m=white, segs=12, rings=8),
              sphere(f"Pupil{s}", 0.15, (hx + s * 0.52, hy - 0.86, hz + 0.47), m=fmat("Slit"), segs=10, rings=6),
              cyl(f"Horn{s}", 0.2, 0.9, (hx + s * 0.55, hy + 0.4, hz + 1.0), rot=(-0.5, s * 0.3, 0), segs=10, bevel=0.05, m=yellow, radius_top=0.04)]
        wing = [(0, 0), (2.6, 1.4), (3.4, 0.2), (2.6, -0.2), (2.0, -1.2), (1.2, -0.6), (0.4, -1.2)]
        pts = [(s * x, z) for x, z in wing]
        p.append(prism(f"Wing{s}", pts if s > 0 else list(reversed(pts)), 0.3, (s * 1.4, D / 2 + 0.6, 3.6), rot=(0, 0, 0), m=purple))
    for k in range(5):
        p.append(cyl(f"Spike{k}", 0.25, 0.6, (0, D / 2 + 0.55 - k * 0.35, 2.9 + k * 0.85), rot=(-0.4, 0, 0), segs=8, bevel=0.06, m=red, radius_top=0.03))
    tail = [(1.8, D / 2 + 1.6, 0.9), (3.2, D / 2 + 2.0, 0.7), (4.0, D / 2 + 1.0, 0.6), (3.6, D / 2 + 0.2, 1.0)]
    p.append(tube("Tail", tail, 0.5, m=green, segs=12, radius_end=0.15))
    p.append(cyl("TailTip", 0.3, 0.6, (3.6, D / 2 + 0.2, 1.3), segs=6, bevel=0.05, m=red, radius_top=0.02))
    p += pennants("Pen", (-W / 2 + 0.45, -D / 2 + 0.45, 3.0), (W / 2 - 0.45, -D / 2 + 0.45, 3.0), 10, 0.3, [red, yellow, fmat("Blue")], size=0.3)
    save("faire_dragon", [merge("Dragon", p)])


def build_bird():
    """A tiny cartoon bird (two wing wedges and a body), ~0.6 m wingspan."""
    reset_scene()
    m = fmat("White", rough=0.6)
    p = [sphere("Body", 0.12, (0, 0, 0), scale=(1, 1.8, 0.8), m=m, segs=8, rings=5),
         prism("WingL", [(0, 0.1), (0.32, 0.0), (0.0, -0.1)], 0.02, (0.05, 0, 0.03), rot=(math.pi / 2, 0.3, 0), m=m),
         prism("WingR", [(0, 0.1), (-0.32, 0.0), (0.0, -0.1)], 0.02, (-0.05, 0, 0.03), rot=(math.pi / 2, -0.3, 0), m=m)]
    save("faire_bird", [merge("Bird", p)])


def build_maypole():
    """The maypole: a 9 m striped pole on a stone foot, a flower crown with gold
    bells at the top and eight ribbons fanned out to stakes 3.4 m round it (the
    level turns the whole pole slowly). Collide with the foot (r 0.6)."""
    reset_scene()
    white, gold = fmat("White", rough=0.6), fmat("Gold", rough=0.35)
    ribbons = [fmat("Red", rough=0.55), fmat("Blue", rough=0.55), fmat("Gold", rough=0.45), fmat("Green", rough=0.55)]
    p = [cyl("Foot", 0.6, 0.5, (0, 0, 0.25), segs=12, bevel=0.05, m=fmat("StoneDark")),
         cyl("Pole", 0.14, 9.0, (0, 0, 4.5), segs=10, bevel=0.0, m=white)]
    for k in range(9):
        p.append(cyl(f"Stripe{k}", 0.145, 0.35, (0, 0, 0.9 + k * 0.9), rot=(0.25, 0, 0), segs=10, bevel=0.0, m=ribbons[k % 2]))
    p += [torus("Crown", 0.55, 0.16, (0, 0, 8.6), m=fmat("LeafDark", rough=0.8), major_segs=18, minor_segs=6),
          sphere("Top", 0.25, (0, 0, 9.15), m=gold, segs=10, rings=6)]
    for k in range(10):
        a = math.tau * k / 10
        p.append(sphere(f"Bloom{k}", 0.12, (math.cos(a) * 0.55, math.sin(a) * 0.55, 8.75), m=fmat("Flower") if k % 2 else fmat("Yellow"), segs=8, rings=5))
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        top = (math.cos(a) * 0.5, math.sin(a) * 0.5, 8.4)
        bot = (math.cos(a) * 3.4, math.sin(a) * 3.4, 0.35)
        mid = ((top[0] + bot[0]) / 2, (top[1] + bot[1]) / 2, (top[2] + bot[2]) / 2 - 0.35)
        p.append(tube(f"Ribbon{k}", [top, mid, bot], 0.05, m=ribbons[k % 4], segs=4))
        p += [cyl(f"Stake{k}", 0.06, 0.5, (bot[0], bot[1], 0.25), segs=6, bevel=0.0, m=fmat("Timber")),
              sphere(f"Bell{k}", 0.09, (top[0] * 1.1, top[1] * 1.1, 8.25), m=gold, segs=8, rings=5)]
    save("faire_maypole", [merge("Maypole", p)])


BUILDERS = {"tent": build_tent, "stall": build_stall, "house": build_house, "stands": build_stands, "tilt": build_tilt,
            "palisade": build_palisade, "fence": build_fence, "banner": build_banner, "brazier": build_brazier,
            "exit_lantern": build_exit_lantern, "tree": build_tree, "pine": build_pine, "hay": build_hay,
            "hay_target": build_hay_target, "barrels": build_barrels, "crates": build_crates, "catapult": build_catapult,
            "well": build_well, "dummy": build_dummy, "cart": build_cart, "bench": build_bench, "dragon": build_dragon,
            "bird": build_bird, "maypole": build_maypole}

if __name__ == "__main__":
    for key in sys.argv[1:] or list(BUILDERS):
        BUILDERS[key]()
