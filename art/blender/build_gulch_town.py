"""Gold Rush Gulch Main Street (World 12, Boomtown): the false-front buildings,
the walk-in saloon, the livery barn, the water tower, the town gate and the
mine and coaster-tunnel mouths.

Every building's origin is the centre of its facade at street level; the facade
faces -Y (+Z in Godot) and the body runs back to +Y = DEPTH. A porch roof on
posts reaches PORCH metres out over the boardwalk (boardwalk top at z 0.2).
tools/build_boomtown.gd uses the same sizes for its colliders.

    gulch_bank.glb      BANK (12 x 9, false front 8.2): terracotta brick, columns, pediment
    gulch_sheriff.glb   SHERIFF (8 x 8, 6.4): turquoise boards, star badge, barred windows
    gulch_store.glb     GENERAL STORE (11 x 9, 7.4): orange boards, curved parapet
    gulch_assay.glb     ASSAY OFFICE (8 x 9, 7.0): cream boards, a giant gold nugget
    gulch_hotel.glb     GRAND HOTEL (14 x 10, 9.0): two storeys, terracotta and cream
    gulch_saloon.glb    THE GOLD PAN SALOON (14 x 10, 9.6): two storeys, walk-in ground
                        floor (bar, tables, piano, chandeliers), a front balcony at 3.6
                        reached by outside stairs; bat-wing doors (SaloonDoorL/R)
    gulch_livery.glb    LIVERY barn (14 x 10, ridge 8.4): open barn doors front and
                        back, stalls and hay inside
    gulch_water_tower.glb  timber tower: a deck at 3.2 (6.4 m square), tank 7.4-11.2
    gulch_gate.glb      the BOOMTOWN arch over Main Street (posts at x +-8.2)
    gulch_mine_mouth.glb   timber mine portal (opening 4.4 x 4.0) with a dark shaft
    gulch_tunnel_mouth.glb coaster tunnel portal (opening 4.2 x 4.4), RUNAWAY MINE TRAIN

    python art/blender/build_gulch_town.py [names...]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gulch_common import *  # noqa: F401,F403

PORCH = 2.4          # porch roof depth over the boardwalk
AWNING_Z = 3.1       # porch roof underside
WALK_Z = 0.2         # boardwalk top


def parapet(prefix, W, F, H, style, m_wall, m_b, trim, hole=None):
    """The false front: a board wall from 0 to F with a shaped top, clapboard
    strips on its face, corner pilasters and cornice trim. `hole` (w, h) leaves
    a doorway open at the centre."""
    hw = W / 2 + 0.1
    if style == "step":
        out = [(-hw, 0), (hw, 0), (hw, F - 1.0), (hw * 0.55, F - 1.0), (hw * 0.55, F), (-hw * 0.55, F), (-hw * 0.55, F - 1.0), (-hw, F - 1.0)]
    elif style == "curve":
        out = [(-hw, 0), (hw, 0), (hw, F - 1.2)]
        for i in range(1, 12):
            a = math.pi * i / 12
            out.append((math.cos(a) * hw, F - 1.2 + math.sin(a) * 1.2))
        out.append((-hw, F - 1.2))
    elif style == "peak":
        out = [(-hw, 0), (hw, 0), (hw, F - 1.4), (0, F), (-hw, F - 1.4)]
    else:
        out = [(-hw, 0), (hw, 0), (hw, F), (-hw, F)]
    if hole:
        out = [(-hw, 0), (-hole[0] / 2, 0), (-hole[0] / 2, hole[1]), (hole[0] / 2, hole[1]), (hole[0] / 2, 0)] + out[1:]
    p = [prism(prefix + "Front", out, 0.3, (0, -0.15, 0), m=m_wall)]
    # Clapboards: thin strips across the face, clipped to the flat part.
    top = F - (1.0 if style == "step" else 1.2 if style == "curve" else 1.4 if style == "peak" else 0.0)
    n = int(top / 0.34)
    for i in range(n):
        z = 0.34 * (i + 0.5)
        m = m_wall if i % 2 else m_b
        if hole and z < hole[1] + 0.15:
            seg = (W - 0.1 - hole[0]) / 2
            for sx in (-1, 1):
                p.append(box(f"{prefix}Clap{i}{sx}", (seg, 0.03, 0.3), (sx * (hole[0] / 2 + seg / 2), -0.31, z), bevel=0.0, m=m))
        else:
            p.append(box(f"{prefix}Clap{i}", (W - 0.1, 0.03, 0.3), (0, -0.31, z), bevel=0.0, m=m))
    for s in (-1, 1):
        p.append(box(f"{prefix}Pilaster{s}", (0.32, 0.12, top), (s * (hw - 0.12), -0.36, top / 2), bevel=0.03, m=trim))
    # Cornice along the top edge of each flat run.
    if style == "step":
        p.append(box(prefix + "CorniceL", (hw * 0.45 + 0.2, 0.3, 0.22), (-hw * 0.775, -0.25, F - 1.0), bevel=0.04, m=trim))
        p.append(box(prefix + "CorniceR", (hw * 0.45 + 0.2, 0.3, 0.22), (hw * 0.775, -0.25, F - 1.0), bevel=0.04, m=trim))
        p.append(box(prefix + "CorniceTop", (hw * 1.1 + 0.2, 0.32, 0.24), (0, -0.25, F), bevel=0.04, m=trim))
    elif style == "flat":
        p.append(box(prefix + "Cornice", (W + 0.5, 0.36, 0.26), (0, -0.25, F), bevel=0.05, m=trim))
        for k in range(int(W / 0.8)):
            p.append(box(f"{prefix}Dentil{k}", (0.16, 0.12, 0.18), (-W / 2 + 0.4 + k * 0.8, -0.42, F - 0.28), bevel=0.01, m=trim))
    elif style == "curve":
        p.append(tube(prefix + "Rim", [(math.cos(math.pi * i / 16) * (hw + 0.02), -0.2, F - 1.2 + math.sin(math.pi * i / 16) * 1.22) for i in range(17)],
                      0.12, m=trim, segs=8))
    else:
        for s in (-1, 1):
            a = math.atan2(1.4, hw)
            p.append(box(f"{prefix}Rake{s}", (math.hypot(hw, 1.4) + 0.2, 0.32, 0.22), (s * hw / 2, -0.25, F - 0.7), rot=(0, s * a, 0), bevel=0.04, m=trim))
    # Body behind the front: walls, a low gable roof and a back wall.
    return p


def body(prefix, W, D, H, m_wall, roof, trim):
    p = [box(prefix + "Body", (W, D, H), (0, D / 2, H / 2), bevel=0.06, m=m_wall),
         prism(prefix + "Roof", [(-W / 2 - 0.25, H - 0.1), (W / 2 + 0.25, H - 0.1), (W / 2 + 0.25, H + 0.05), (0, H + W * 0.16), (-W / 2 - 0.25, H + 0.05)],
               D + 0.3, (0, D / 2 + 0.05, 0), m=roof),
         box(prefix + "Base", (W + 0.1, D + 0.1, 0.3), (0, D / 2, 0.15), bevel=0.03, m=trim)]
    for sx in (-1, 1):
        p.append(box(f"{prefix}Corner{sx}", (0.18, 0.18, H), (sx * W / 2, D, H / 2), bevel=0.03, m=trim))
    # A side window and a back door so no wall is blank or doorless.
    p += [box(prefix + "SideWinL", (0.06, 0.9, 1.1), (-W / 2 - 0.02, D * 0.55, 1.7), bevel=0.0, m=gmat("Glass", rough=0.2)),
          box(prefix + "SideWinLF", (0.1, 1.1, 1.3), (-W / 2 - 0.0, D * 0.55, 1.7), bevel=0.02, m=trim),
          box(prefix + "SideWinR", (0.06, 0.9, 1.1), (W / 2 + 0.02, D * 0.55, 1.7), bevel=0.0, m=gmat("Glass", rough=0.2)),
          box(prefix + "SideWinRF", (0.1, 1.1, 1.3), (W / 2 + 0.0, D * 0.55, 1.7), bevel=0.02, m=trim)]
    p += [box(prefix + "BackDoor", (1.1, 0.08, 2.2), (W * 0.25, D + 0.03, 1.1), bevel=0.02, m=gmat("WoodDark")),
          box(prefix + "BackDoorF", (1.35, 0.06, 2.4), (W * 0.25, D + 0.01, 1.2), bevel=0.02, m=trim),
          box(prefix + "Stovepipe", (0.3, 0.3, 1.6), (-W * 0.3, D * 0.7, H + W * 0.1), bevel=0.05, m=gmat("Iron", rough=0.5))]
    return p


def awning(prefix, W, roof, trim, post, posts=None, z=AWNING_Z):
    """Porch roof on posts over the boardwalk."""
    n = posts or (3 if W > 9 else 2)
    p = [box(prefix + "Awning", (W + 0.2, PORCH + 0.2, 0.14), (0, -PORCH / 2, z + 0.15), rot=(math.radians(-4), 0, 0), bevel=0.03, m=roof),
         box(prefix + "Fascia", (W + 0.24, 0.08, 0.3), (0, -PORCH - 0.05, z + 0.05), bevel=0.02, m=trim),
         box(prefix + "Beam", (W + 0.1, 0.18, 0.2), (0, -PORCH + 0.18, z - 0.05), bevel=0.02, m=post)]
    for k in range(int(W / 0.5)):
        p.append(box(f"{prefix}Rafter{k}", (0.08, PORCH, 0.12), (-W / 2 + 0.25 + k * 0.5, -PORCH / 2, z + 0.02), bevel=0.0, m=post))
    p += post_row(prefix + "Post", -W / 2 + 0.3, W / 2 - 0.3, -PORCH + 0.18, WALK_Z, z - 0.1, n, post)
    return p


def front_openings(prefix, W, wall_y, frame, glass, door_m, shutters=None, door_w=1.4):
    p = door(prefix + "Door", 0, wall_y, w=door_w, h=2.35, m=door_m, frame=frame)
    for s in (-1, 1):
        x = s * (W / 4 + door_w / 4 + 0.25)
        p += window(f"{prefix}Win{s}", x, wall_y, 1.55, w=min(1.6, W * 0.16), h=1.5, frame=frame, glass=glass, shutters=shutters)
    return p


def upper_windows(prefix, W, wall_y, z, count, frame, glass, shutters=None, w=0.9, h=1.2):
    p = []
    for i in range(count):
        x = -W / 2 + W * (i + 0.5) / count
        p += window(f"{prefix}Up{i}", x, wall_y, z, w=w, h=h, frame=frame, glass=glass, shutters=shutters)
    return p


def shop(name, W, D, H, F, style, wall, wall_b, trim, roof, post, sign_text, sign_board, sign_ink, upper=2, shutters=None, extra=None,
         sign_w=None):
    p = parapet("P", W, F, H, style, wall, wall_b, trim)
    p += body("B", W, D, H, wall, roof, trim)
    p += awning("A", W, roof, trim, post)
    p += front_openings("O", W, -0.32, trim, gmat("Glass", rough=0.2), gmat("WoodDark"), shutters)
    sign_z = AWNING_Z + 1.25 if upper == 0 else F - (1.6 if style != "flat" else 1.0)
    if upper:
        p += upper_windows("U", W, -0.32, AWNING_Z + 1.45, upper, trim, gmat("Glass", rough=0.2), shutters)
        sign_z = max(sign_z, AWNING_Z + 3.1)
    sw = sign_w or W * 0.72
    p += sign("S", sign_text, 0, -0.4, sign_z, sw, 0.8, board=sign_board, ink=sign_ink, size=0.5)
    if extra:
        p += extra()
    save(name, [merge(name.split("_", 1)[1].title().replace("_", ""), p)])


# ---------------------------------------------------------------------------
# The shops
# ---------------------------------------------------------------------------

def build_bank():
    reset_scene()
    W, D, H, F = 12.0, 9.0, 6.2, 8.2
    brick, brick_b, cream, roof = gmat("Brick", rough=0.85), gmat("TerraDark", rough=0.85), gmat("Cream", rough=0.6), gmat("WoodDark", rough=0.8)
    gold = gmat("Gold", rough=0.3, metal=0.5)
    p = parapet("P", W, F, H, "peak", brick, brick_b, cream)
    p += body("B", W, D, H, brick, roof, cream)
    # A stone portico in place of a porch: columns and a cornice.
    p += [box("Portico", (W + 0.2, PORCH + 0.2, 0.3), (0, -PORCH / 2, AWNING_Z + 0.2), bevel=0.05, m=cream),
          box("PorticoTrim", (W + 0.3, 0.12, 0.42), (0, -PORCH - 0.04, AWNING_Z + 0.15), bevel=0.04, m=gold)]
    for i in range(4):
        x = -W / 2 + 0.6 + (W - 1.2) * i / 3
        p += [cyl(f"Column{i}", 0.24, AWNING_Z - WALK_Z, (x, -PORCH + 0.3, (AWNING_Z + WALK_Z) / 2), segs=14, bevel=0.03, m=cream),
              box(f"ColBase{i}", (0.62, 0.62, 0.22), (x, -PORCH + 0.3, WALK_Z + 0.11), bevel=0.04, m=cream),
              box(f"ColCap{i}", (0.62, 0.62, 0.2), (x, -PORCH + 0.3, AWNING_Z - 0.08), bevel=0.04, m=cream)]
    p += door("Door", 0, -0.32, w=1.8, h=2.6, m=gmat("TurqDark", rough=0.5), frame=cream, knob=gold)
    for s in (-1, 1):
        x = s * 3.4
        p += window(f"Win{s}", x, -0.32, 1.6, w=1.4, h=1.7, frame=cream, glass=gmat("Glass", rough=0.2))
        for k in range(5):
            p.append(cyl(f"Bar{s}{k}", 0.025, 1.7, (x - 0.56 + k * 0.28, -0.42, 1.6), segs=6, bevel=0.0, m=gmat("Iron", rough=0.4)))
    p += upper_windows("U", W, -0.32, 4.6, 3, cream, gmat("Glass", rough=0.2), w=1.0, h=1.1)
    p += [box("SignBand", (W * 0.7, 0.14, 0.9), (0, -0.4, 6.15), bevel=0.04, m=gmat("TurqDark", rough=0.5)),
          text("SignText", "BANK", 0.72, 0.08, (0, -0.5, 6.1), m=gold),
          cyl("Nugget", 0.42, 0.18, (0, -0.4, 7.4), rot=rad(90, 0, 0), segs=7, bevel=0.06, m=gold)]
    save("gulch_bank", [merge("Bank", p)])


def build_sheriff():
    reset_scene()
    W = 8.0

    def extra():
        star_m = gmat("Gold", rough=0.3, metal=0.5)
        p = [star("Badge", 0.62, 0.12, (0, -0.48, 5.55), rot=(math.pi / 2, 0, 0), m=star_m),
             cyl("BadgeRim", 0.7, 0.08, (0, -0.4, 5.55), rot=rad(90, 0, 0), segs=24, bevel=0.02, m=gmat("Cream", rough=0.6))]
        for s in (-1, 1):
            x = s * (W / 4 + 0.6)
            for k in range(4):
                p.append(cyl(f"Bar{s}{k}", 0.025, 1.5, (x - 0.45 + k * 0.3, -0.42, 1.55), segs=6, bevel=0.0, m=gmat("Iron", rough=0.4)))
        p.append(box("Wanted", (0.7, 0.04, 0.9), (2.8, -0.36, 1.6), rot=(0, 0, 0.05), bevel=0.0, m=gmat("Bone", rough=0.9)))
        p.append(text("WantedText", "WANTED", 0.12, 0.01, (2.8, -0.39, 1.9), m=gmat("Ink")))
        return p
    shop("gulch_sheriff", W, 8.0, 4.8, 6.6, "flat", gmat("Turq", rough=0.65), gmat("TurqDark", rough=0.65), gmat("Cream", rough=0.6),
         gmat("WoodDark", rough=0.8), gmat("WoodLight"), "SHERIFF", gmat("Cream", rough=0.6), gmat("TurqDark", rough=0.5), upper=0,
         extra=extra, sign_w=5.0)


def build_store():
    reset_scene()
    shop("gulch_store", 11.0, 9.0, 5.4, 7.6, "curve", gmat("Orange", rough=0.7), gmat("OrangeDark", rough=0.7), gmat("Cream", rough=0.6),
         gmat("WoodDark", rough=0.8), gmat("WoodLight"), "GENERAL STORE", gmat("Cream", rough=0.6), gmat("RedDark", rough=0.5), upper=2,
         shutters=gmat("TurqDark", rough=0.6))


def build_assay():
    reset_scene()

    def extra():
        gold = gmat("Gold", rough=0.25, metal=0.6)
        p = [sphere("NuggetA", 0.9, (0, -0.2, 7.8), scale=(1.1, 0.5, 0.75), m=gold, segs=8, rings=5),
             sphere("NuggetB", 0.55, (0.7, -0.25, 8.3), scale=(1.0, 0.5, 0.8), m=gold, segs=7, rings=5),
             sphere("NuggetC", 0.45, (-0.7, -0.25, 8.25), scale=(1.0, 0.5, 0.8), m=gold, segs=7, rings=5),
             box("Scale", (0.8, 0.3, 0.06), (0, -0.55, 4.25), bevel=0.02, m=gmat("Iron", rough=0.4))]
        return p
    shop("gulch_assay", 8.0, 9.0, 5.0, 7.0, "step", gmat("Cream", rough=0.7), gmat("Bone", rough=0.7), gmat("TerraDark", rough=0.6),
         gmat("WoodDark", rough=0.8), gmat("Wood"), "ASSAY OFFICE", gmat("TerraDark", rough=0.6), gmat("Gold", rough=0.3, metal=0.4), upper=1,
         shutters=gmat("Terracotta", rough=0.6), extra=extra, sign_w=5.2)


def build_hotel():
    reset_scene()
    W, D, H, F = 14.0, 10.0, 7.4, 9.0
    wall, wall_b, trim, roof = gmat("Terracotta", rough=0.7), gmat("TerraDark", rough=0.7), gmat("Cream", rough=0.6), gmat("WoodDark", rough=0.8)
    post = gmat("Cream", rough=0.6)
    p = parapet("P", W, F, H, "step", wall, wall_b, trim)
    p += body("B", W, D, H, wall, roof, trim)
    p += awning("A", W, roof, trim, post, posts=4)
    p += door("Door", 0, -0.32, w=1.8, h=2.5, m=gmat("TurqDark", rough=0.5), frame=trim)
    for s in (-1, 1):
        for k in (1, 2):
            p += window(f"Win{s}{k}", s * (1.0 + k * 1.9), -0.32, 1.55, w=1.1, h=1.5, frame=trim, glass=gmat("Glass", rough=0.2),
                        shutters=gmat("Turq", rough=0.6))
    p += upper_windows("U", W, -0.32, 4.7, 5, trim, gmat("Glass", rough=0.2), shutters=gmat("Turq", rough=0.6), w=0.9, h=1.3)
    # A sham balcony rail across the upper floor.
    p += [box("BalcRail", (W - 0.6, 0.08, 0.08), (0, -0.75, AWNING_Z + 1.25), bevel=0.0, m=trim)]
    for k in range(int(W / 0.4)):
        p.append(box(f"Baluster{k}", (0.06, 0.06, 0.95), (-W / 2 + 0.5 + k * 0.4, -0.75, AWNING_Z + 0.78), bevel=0.0, m=trim))
    p += sign("S", "GRAND HOTEL", 0, -0.4, F - 1.5, 7.4, 0.9, board=trim, ink=gmat("TurqDark", rough=0.5), size=0.58)
    save("gulch_hotel", [merge("Hotel", p)])


# ---------------------------------------------------------------------------
# The saloon (walk-in ground floor, balcony)
# ---------------------------------------------------------------------------

SALOON_W, SALOON_D, SALOON_H, SALOON_F = 14.0, 10.0, 7.6, 9.6
SALOON_FLOOR = 3.5       # ceiling of the bar room
SALOON_DOOR = 2.4        # front doorway width (centred)
SALOON_DOOR_H = 2.7
SALOON_BACK = (3.0, 1.6, 2.4)  # back door: centre x, width, height
BALCONY_Z = 3.6
BALCONY_D = 2.8
WALL_T = 0.3


def saloon_walls(wall, wall_b, trim):
    W, D, H = SALOON_W, SALOON_D, SALOON_H
    hw = W / 2
    inner = gmat("WoodLight", rough=0.75)
    p = []
    # Front wall with the doorway and two windows (cut as wall pieces round them).
    dw = SALOON_DOOR / 2
    p += [box("FrontL", (hw - dw, WALL_T, H), (-(hw + dw) / 2, WALL_T / 2, H / 2), bevel=0.02, m=wall),
          box("FrontR", (hw - dw, WALL_T, H), ((hw + dw) / 2, WALL_T / 2, H / 2), bevel=0.02, m=wall),
          box("FrontTop", (SALOON_DOOR, WALL_T, H - SALOON_DOOR_H), (0, WALL_T / 2, (H + SALOON_DOOR_H) / 2), bevel=0.02, m=wall)]
    # Back wall with the back door.
    bx, bw, bh = SALOON_BACK
    p += [box("BackL", (bx - bw / 2 + hw, WALL_T, H), ((-hw + bx - bw / 2) / 2, D - WALL_T / 2, H / 2), bevel=0.02, m=wall),
          box("BackR", (hw - bx - bw / 2, WALL_T, H), ((hw + bx + bw / 2) / 2, D - WALL_T / 2, H / 2), bevel=0.02, m=wall),
          box("BackTop", (bw, WALL_T, H - bh), (bx, D - WALL_T / 2, (H + bh) / 2), bevel=0.02, m=wall)]
    for s in (-1, 1):
        p.append(box(f"Side{s}", (WALL_T, D, H), (s * (hw - WALL_T / 2), D / 2, H / 2), bevel=0.02, m=wall))
    # Inner wainscot and wallpaper faces (so the inside reads warm, not painted outside colour).
    paper = gmat("Bone", rough=0.8)
    p += [box("InBack", (W - 0.7, 0.04, SALOON_FLOOR - 0.2), (0, D - WALL_T - 0.03, SALOON_FLOOR / 2 + 0.1), bevel=0.0, m=paper),
          box("InFrontL", (hw - dw - 0.4, 0.04, SALOON_FLOOR - 0.2), (-(hw + dw) / 2 - 0.1, WALL_T + 0.03, SALOON_FLOOR / 2 + 0.1), bevel=0.0, m=paper),
          box("InFrontR", (hw - dw - 0.4, 0.04, SALOON_FLOOR - 0.2), ((hw + dw) / 2 + 0.1, WALL_T + 0.03, SALOON_FLOOR / 2 + 0.1), bevel=0.0, m=paper)]
    for s in (-1, 1):
        p.append(box(f"InSide{s}", (0.04, D - 0.7, SALOON_FLOOR - 0.2), (s * (hw - WALL_T - 0.03), D / 2, SALOON_FLOOR / 2 + 0.1), bevel=0.0, m=paper))
        p.append(box(f"Wainscot{s}", (0.06, D - 0.7, 1.0), (s * (hw - WALL_T - 0.05), D / 2, 0.7), bevel=0.0, m=inner))
    p.append(box("WainscotBack", (W - 0.7, 0.06, 1.0), (0, D - WALL_T - 0.05, 0.7), bevel=0.0, m=inner))
    # Floor, ceiling with beams, roof.
    p += [box("Floor", (W - 0.4, D - 0.4, 0.2), (0, D / 2, 0.1), bevel=0.0, m=gmat("Plank", rough=0.8)),
          box("Ceiling", (W - 0.4, D - 0.4, 0.2), (0, D / 2, SALOON_FLOOR + 0.1), bevel=0.0, m=gmat("WoodDark", rough=0.8))]
    for k in range(5):
        p.append(box(f"Beam{k}", (W - 0.5, 0.22, 0.26), (0, 1.2 + k * 1.9, SALOON_FLOOR - 0.12), bevel=0.02, m=gmat("Wood", rough=0.8)))
    for k in range(int((W - 0.6) / 0.5)):
        p.append(box(f"Board{k}", (0.02, D - 0.5, 0.01), (-W / 2 + 0.45 + k * 0.5, D / 2, 0.205), bevel=0.0, m=gmat("WoodDark", rough=0.8)))
    p.append(prism("Roof", [(-W / 2 - 0.25, H - 0.1), (W / 2 + 0.25, H - 0.1), (W / 2 + 0.25, H + 0.05), (0, H + 2.0), (-W / 2 - 0.25, H + 0.05)],
                   D + 0.3, (0, D / 2 + 0.05, 0), m=gmat("WoodDark", rough=0.8)))
    return p


def saloon_front(wall, wall_b, trim):
    W, F = SALOON_W, SALOON_F
    glass = gmat("Glass", rough=0.2)
    p = parapet("P", W, F, SALOON_H, "step", wall, wall_b, trim, hole=(SALOON_DOOR, SALOON_DOOR_H))
    # Re-open the doorway through the false front: frame it.
    gold = gmat("Gold", rough=0.3, metal=0.4)
    p += [box("DoorFrameT", (SALOON_DOOR + 0.4, 0.2, 0.22), (0, -0.4, SALOON_DOOR_H + 0.11), bevel=0.03, m=trim),
          box("DoorFrameL", (0.2, 0.2, SALOON_DOOR_H), (-SALOON_DOOR / 2 - 0.1, -0.4, SALOON_DOOR_H / 2), bevel=0.03, m=trim),
          box("DoorFrameR", (0.2, 0.2, SALOON_DOOR_H), (SALOON_DOOR / 2 + 0.1, -0.4, SALOON_DOOR_H / 2), bevel=0.03, m=trim)]
    for s in (-1, 1):
        x = s * 4.0
        p += window(f"Win{s}", x, -0.32, 1.6, w=2.0, h=1.6, frame=trim, glass=glass)
        p.append(text(f"WinText{s}", "SALOON" if s < 0 else "DANCE HALL", 0.18, 0.01, (x, -0.38, 1.95), m=gold))
    # Upper floor: doors onto the balcony and windows.
    for i, x in enumerate((-4.8, 0.0, 4.8)):
        p += door(f"Up{i}", x, -0.32, w=1.1, h=2.2, m=gmat("TurqDark", rough=0.5), frame=trim, panels=2)
        for ob in p[-8:]:
            ob.location.z += BALCONY_Z
    for x in (-2.4, 2.4):
        p += window(f"UpWin{x}", x, -0.32, BALCONY_Z + 1.3, w=1.0, h=1.3, frame=trim, glass=glass, shutters=gmat("Turq", rough=0.6))
    p += sign("S", "THE GOLD PAN SALOON", 0, -0.4, F - 1.75, 9.2, 1.0, board=gmat("RedDark", rough=0.5), trim=trim, ink=gold, size=0.6)
    # A gold-pan emblem on the top step.
    p += [cyl("Pan", 0.7, 0.12, (0, -0.42, F - 0.55), rot=rad(90, 0, 0), segs=24, bevel=0.03, m=gmat("Iron", rough=0.4)),
          cyl("PanGold", 0.4, 0.1, (0, -0.5, F - 0.55), rot=rad(90, 0, 0), segs=10, bevel=0.03, m=gold)]
    return p


def saloon_balcony(trim, post):
    W = SALOON_W
    deck = gmat("Plank", rough=0.8)
    p = [box("Balcony", (W + 0.2, BALCONY_D, 0.24), (0, -BALCONY_D / 2, BALCONY_Z - 0.12), bevel=0.03, m=deck),
         box("BalconyFascia", (W + 0.3, 0.1, 0.36), (0, -BALCONY_D - 0.02, BALCONY_Z - 0.18), bevel=0.02, m=trim)]
    for k in range(int(W / 0.5)):
        p.append(box(f"Joist{k}", (0.1, BALCONY_D, 0.18), (-W / 2 + 0.25 + k * 0.5, -BALCONY_D / 2, BALCONY_Z - 0.33), bevel=0.0, m=post))
    # Railing on the front and the north end; the south end opens onto the stairs.
    p.append(box("RailTop", (W, 0.12, 0.1), (0, -BALCONY_D + 0.08, BALCONY_Z + 1.05), bevel=0.02, m=trim))
    p.append(box("RailEnd", (0.12, BALCONY_D, 0.1), (W / 2 - 0.05, -BALCONY_D / 2, BALCONY_Z + 1.05), bevel=0.02, m=trim))
    for k in range(int(W / 0.35)):
        p.append(box(f"Spindle{k}", (0.06, 0.06, 1.0), (-W / 2 + 0.2 + k * 0.35, -BALCONY_D + 0.08, BALCONY_Z + 0.5), bevel=0.0, m=trim))
    for k in range(7):
        p.append(box(f"EndSpindle{k}", (0.06, 0.06, 1.0), (W / 2 - 0.05, -BALCONY_D + 0.3 + k * 0.38, BALCONY_Z + 0.5), bevel=0.0, m=trim))
    p += post_row("Post", -W / 2 + 0.3, W / 2 - 0.3, -BALCONY_D + 0.18, WALK_Z, BALCONY_Z - 0.4, 4, post, radius=0.13)
    # Bunting under the rail.
    for k in range(10):
        x = -W / 2 + 0.7 + k * 1.4
        p.append(prism(f"Swag{k}", [(-0.7, 0), (0.7, 0), (0, -0.45)], 0.03, (x, -BALCONY_D, BALCONY_Z + 0.85),
                       m=gmat("Red", rough=0.6) if k % 3 == 0 else gmat("Cream", rough=0.6) if k % 3 == 1 else gmat("Turq", rough=0.6)))
    return p


def saloon_interior():
    W, D = SALOON_W, SALOON_D
    wood, dark, light = gmat("Wood", rough=0.7), gmat("WoodDark", rough=0.7), gmat("WoodLight", rough=0.7)
    gold = gmat("Gold", rough=0.3, metal=0.5)
    red = gmat("Red", rough=0.6)
    p = []
    # The bar: a long counter parallel to the back wall, a brass foot rail, the back bar and mirror.
    bx0, bx1, by = -5.8, 0.6, D - 2.3
    p += [box("Bar", (bx1 - bx0, 0.7, 1.1), ((bx0 + bx1) / 2, by, 0.2 + 0.55), bevel=0.04, m=dark),
          box("BarTop", (bx1 - bx0 + 0.2, 0.86, 0.08), ((bx0 + bx1) / 2, by, 1.34), bevel=0.02, m=light),
          tube("FootRail", [(bx0, by - 0.45, 0.4), (bx1, by - 0.45, 0.4)], 0.04, m=gold, segs=6)]
    for k in range(6):
        p.append(box(f"BarPanel{k}", (0.9, 0.04, 0.6), (bx0 + 0.55 + k * 1.05, by - 0.37, 0.8), bevel=0.01, m=wood))
    p += [box("BackBar", (6.8, 0.5, 1.0), (-2.6, D - 0.6, 0.7), bevel=0.03, m=dark),
          box("Mirror", (5.6, 0.05, 1.3), (-2.6, D - 0.36, 2.0), bevel=0.0, m=gmat("TurqLight", rough=0.1)),
          box("MirrorFrame", (6.0, 0.06, 1.6), (-2.6, D - 0.34, 2.0), bevel=0.02, m=gold),
          box("Shelf", (6.4, 0.3, 0.06), (-2.6, D - 0.5, 1.45), bevel=0.0, m=light)]
    bottles = [gmat("Green", rough=0.2), gmat("Gold", rough=0.2), gmat("TurqDark", rough=0.2), gmat("RedDark", rough=0.2)]
    for k in range(14):
        x = -5.6 + k * 0.42
        p.append(cyl(f"Bottle{k}", 0.07, 0.34, (x, D - 0.52, 1.65), segs=8, bevel=0.02, m=bottles[k % 4], radius_top=0.04))
    for k in range(5):
        p.append(cyl(f"Glass{k}", 0.05, 0.12, (bx0 + 0.6 + k * 1.2, by, 1.44), segs=8, bevel=0.0, m=gmat("TurqLight", rough=0.1)))
    # Stools at the bar.
    for k in range(4):
        x = bx0 + 0.9 + k * 1.5
        p += [cyl(f"StoolSeat{k}", 0.25, 0.08, (x, by - 0.85, 0.95), segs=12, bevel=0.02, m=red),
              cyl(f"StoolLeg{k}", 0.05, 0.75, (x, by - 0.85, 0.57), segs=6, bevel=0.0, m=dark)]
    # Round tables with chairs.
    for i, (tx, ty) in enumerate(((2.8, 3.0), (4.6, 6.4), (-3.4, 3.6), (0.4, 5.6))):
        p += [cyl(f"Table{i}", 0.7, 0.08, (tx, ty, 1.0), segs=16, bevel=0.02, m=light),
              cyl(f"TableLeg{i}", 0.08, 0.8, (tx, ty, 0.6), segs=8, bevel=0.0, m=dark),
              cyl(f"TableFoot{i}", 0.35, 0.06, (tx, ty, 0.23), segs=12, bevel=0.02, m=dark)]
        for c in range(3):
            a = math.tau * c / 3 + i
            cx, cy = tx + math.cos(a) * 1.05, ty + math.sin(a) * 1.05
            p += [box(f"Chair{i}{c}", (0.45, 0.45, 0.06), (cx, cy, 0.68), rot=(0, 0, a), bevel=0.02, m=wood),
                  box(f"ChairBack{i}{c}", (0.45, 0.06, 0.55), (cx + math.cos(a) * 0.22, cy + math.sin(a) * 0.22, 0.98), rot=(0, 0, a + math.pi / 2),
                      bevel=0.02, m=wood)]
            for lx, ly in ((-0.17, -0.17), (0.17, -0.17), (-0.17, 0.17), (0.17, 0.17)):
                p.append(box(f"ChairLeg{i}{c}{lx}{ly}", (0.05, 0.05, 0.46), (cx + lx, cy + ly, 0.43), bevel=0.0, m=dark))
        p.append(box(f"Cards{i}", (0.3, 0.2, 0.02), (tx + 0.1, ty, 1.05), rot=(0, 0, i), bevel=0.0, m=gmat("White", rough=0.6)))
    # Upright piano against the south (right) wall.
    px = W / 2 - 0.75
    p += [box("Piano", (0.7, 1.7, 1.35), (px, 4.0, 0.2 + 0.68), bevel=0.04, m=gmat("RedDark", rough=0.5)),
          box("Keys", (0.35, 1.5, 0.08), (px - 0.5, 4.0, 1.0), bevel=0.01, m=gmat("White", rough=0.4)),
          box("PianoTop", (0.8, 1.8, 0.08), (px, 4.0, 1.58), bevel=0.02, m=dark),
          box("PianoBench", (0.4, 1.0, 0.5), (px - 1.1, 4.0, 0.45), bevel=0.03, m=dark)]
    # Wagon-wheel chandeliers with bulbs.
    bulb_m = gglow("GulchLampGlow", "#ffd88a", 3.0)
    for i, (cx, cy) in enumerate(((-2.5, 4.5), (3.0, 4.5))):
        p.append(torus(f"Wheel{i}", 0.8, 0.05, (cx, cy, 2.75), m=dark, major_segs=20, minor_segs=5))
        p.append(cyl(f"Chain{i}", 0.02, 0.6, (cx, cy, 3.1), segs=4, bevel=0.0, m=gmat("Iron")))
        for k in range(6):
            a = math.tau * k / 6
            p.append(tube(f"Spoke{i}{k}", [(cx, cy, 2.75), (cx + math.cos(a) * 0.8, cy + math.sin(a) * 0.8, 2.75)], 0.025, m=dark, segs=4))
            p.append(bulb(f"Lamp{i}{k}", 0.08, (cx + math.cos(a) * 0.8, cy + math.sin(a) * 0.8, 2.88), bulb_m))
    # A small stage platform in the back-right corner with a curtain.
    p += [box("Stage", (3.6, 2.6, 0.4), (W / 2 - 2.2, D - 1.7, 0.4), bevel=0.03, m=wood),
          box("Curtain", (3.6, 0.1, 2.9), (W / 2 - 2.2, D - 0.45, 2.0), bevel=0.02, m=gmat("Red", rough=0.8)),
          box("Valance", (3.8, 0.2, 0.4), (W / 2 - 2.2, D - 0.5, 3.25), bevel=0.02, m=gold)]
    return p


def saloon_doors():
    """The two bat-wing doors, pivots on their hinges, hung half open."""
    out = []
    m, trim = gmat("Wood", rough=0.7), gmat("Gold", rough=0.3, metal=0.4)
    for s, name in ((-1, "SaloonDoorL"), (1, "SaloonDoorR")):
        hw = SALOON_DOOR / 2 - 0.05
        p = [box(name + "Leaf", (hw, 0.06, 1.0), (-s * hw / 2, 0, 0.0), bevel=0.02, m=m)]
        for k in range(4):
            p.append(box(f"{name}Slat{k}", (hw - 0.2, 0.07, 0.05), (-s * hw / 2, 0, -0.3 + k * 0.2), bevel=0.0, m=gmat("WoodDark")))
        p.append(box(name + "Cap", (hw, 0.08, 0.08), (-s * hw / 2, 0, 0.5), bevel=0.02, m=trim))
        ob = merge(name, p)
        ob.location = (s * (SALOON_DOOR / 2 - 0.02), -0.2, 1.6)
        ob.rotation_euler = (0, 0, s * math.radians(18))
        out.append(ob)
    return out


def build_saloon():
    reset_scene()
    wall, wall_b, trim = gmat("Red", rough=0.7), gmat("RedDark", rough=0.7), gmat("Cream", rough=0.6)
    p = saloon_walls(wall, wall_b, trim) + saloon_front(wall, wall_b, trim) + saloon_balcony(trim, gmat("WoodLight"))
    p += saloon_interior()
    save("gulch_saloon", [merge("Saloon", p)] + saloon_doors())


# ---------------------------------------------------------------------------
# Livery barn
# ---------------------------------------------------------------------------

LIVERY_W, LIVERY_D, LIVERY_H, LIVERY_RIDGE = 14.0, 10.0, 4.8, 8.4
LIVERY_DOOR = (5.0, 4.2)


def build_livery():
    reset_scene()
    W, D, H, R = LIVERY_W, LIVERY_D, LIVERY_H, LIVERY_RIDGE
    barn, barn_b, trim = gmat("Barn", rough=0.75), gmat("RedDark", rough=0.75), gmat("White", rough=0.6)
    roof = gmat("WoodGrey", rough=0.85)
    hw = W / 2
    dw, dh = LIVERY_DOOR
    p = []
    gable = [(-hw, 0), (hw, 0), (hw, H), (0, R), (-hw, H)]
    hole = [(-dw / 2, 0), (dw / 2, 0), (dw / 2, dh), (-dw / 2, dh)]
    for y, tag in ((0.0, "Front"), (D, "Back")):
        for s in (-1, 1):
            x0, x1 = (-hw, -dw / 2) if s < 0 else (dw / 2, hw)
            p.append(box(f"{tag}Wall{s}", (x1 - x0, WALL_T, H), ((x0 + x1) / 2, y + (WALL_T / 2 if y == 0 else -WALL_T / 2), H / 2), bevel=0.02, m=barn))
        tri = [(-hw, H), (hw, H), (0, R)]
        p.append(prism(f"{tag}Gable", tri, WALL_T, (0, y + (WALL_T / 2 if y == 0 else -WALL_T / 2), 0), m=barn))
        p.append(box(f"{tag}Lintel", (dw, WALL_T, H - dh), (0, y + (WALL_T / 2 if y == 0 else -WALL_T / 2), (H + dh) / 2), bevel=0.02, m=barn))
        sy = -0.04 if y == 0 else D + 0.04
        # White trim: the cross-braced barn-door frames slid open to each side.
        for s in (-1, 1):
            cx = s * (dw / 2 + 1.2)
            p += [box(f"{tag}Slide{s}", (2.4, 0.12, dh), (cx, sy - (0.06 if y == 0 else -0.06), dh / 2), bevel=0.02, m=barn_b)]
            for a in (1, -1):
                p.append(box(f"{tag}X{s}{a}", (math.hypot(2.4, dh) - 0.2, 0.06, 0.14), (cx, sy - (0.13 if y == 0 else -0.13), dh / 2),
                             rot=(0, a * math.atan2(dh, 2.4), 0), bevel=0.0, m=trim))
            p.append(box(f"{tag}SlideFrame{s}", (2.5, 0.08, 0.16), (cx, sy - (0.13 if y == 0 else -0.13), dh), bevel=0.0, m=trim))
        p.append(box(f"{tag}Track", (dw + 5.4, 0.12, 0.14), (0, sy - (0.08 if y == 0 else -0.08), dh + 0.2), bevel=0.02, m=gmat("Iron")))
        p.append(box(f"{tag}DoorTrim", (dw + 0.3, 0.1, 0.18), (0, sy, dh + 0.02), bevel=0.02, m=trim))
        for s in (-1, 1):
            p.append(box(f"{tag}Jamb{s}", (0.18, 0.1, dh), (s * (dw / 2 + 0.05), sy, dh / 2), bevel=0.02, m=trim))
        # Hayloft door and hoist beam.
        p += [box(f"{tag}Loft", (2.0, 0.1, 1.6), (0, sy, H + 1.0), bevel=0.02, m=barn_b),
              box(f"{tag}LoftTrim", (2.2, 0.08, 1.8), (0, sy + (0.02 if y == 0 else -0.02), H + 1.0), bevel=0.02, m=trim),
              box(f"{tag}Hoist", (0.25, 1.4, 0.25), (0, y + (-0.6 if y == 0 else 0.6), R - 0.6), bevel=0.03, m=gmat("WoodDark"))]
    for s in (-1, 1):
        p.append(box(f"Side{s}", (WALL_T, D, H), (s * (hw - WALL_T / 2), D / 2, H / 2), bevel=0.02, m=barn))
        for k in range(3):
            p += window(f"SideWin{s}{k}", 0, 0, 0, w=0.9, h=0.8, frame=trim, glass=gmat("Ink", rough=0.8), sill=False)
            for ob in p[-7:]:
                x, y, z = ob.location
                ob.location = (s * hw + s * 0.02, 2.0 + k * 3.0 + x, 3.1 + z)
                ob.rotation_euler = (0, 0, s * math.pi / 2)
    # Roof: two sloped slabs meeting at the ridge.
    run = math.hypot(hw + 0.5, R - H + 0.4)
    ang = math.atan2(R - H + 0.4, hw + 0.5)
    for s in (-1, 1):
        p.append(box(f"Roof{s}", (run, D + 0.8, 0.2), (s * (hw + 0.5) / 2, D / 2, (R + H - 0.4) / 2 + 0.1), rot=(0, s * ang, 0), bevel=0.04, m=roof))
    p.append(box("Ridge", (0.3, D + 0.9, 0.25), (0, D / 2, R + 0.12), bevel=0.04, m=trim))
    p.append(cyl("Vane", 0.04, 1.4, (0, D / 2, R + 0.8), segs=6, bevel=0.0, m=gmat("Iron")))
    p.append(prism("Rooster", [(-0.4, 0), (0.4, 0), (0.3, 0.3), (0.0, 0.25), (-0.2, 0.5), (-0.35, 0.3)], 0.04, (0, D / 2, R + 1.3), m=gmat("Iron")))
    # Interior: floor of straw, stall partitions along both side walls, hay.
    straw, straw_d = gmat("Straw", rough=0.95), gmat("StrawDark", rough=0.95)
    p.append(box("Straw", (W - 0.6, D - 0.6, 0.04), (0, D / 2, 0.02), bevel=0.0, m=gmat("SandDark", rough=0.95)))
    for s in (-1, 1):
        for k in range(4):
            y = 0.9 + k * 2.75
            p.append(box(f"Stall{s}{k}", (2.4, 0.16, 1.4), (s * (hw - 1.5), y, 0.7), bevel=0.03, m=gmat("Wood")))
            p.append(box(f"StallPost{s}{k}", (0.2, 0.2, 2.4), (s * (hw - 2.6), y, 1.2), bevel=0.03, m=gmat("WoodDark")))
        for k in range(3):
            y = 2.25 + k * 2.75
            p += [box(f"Hay{s}{k}", (1.2, 0.9, 0.6), (s * (hw - 1.0), y, 0.3), rot=(0, 0, 0.1 * k), bevel=0.08, m=straw),
                  box(f"Trough{s}{k}", (0.4, 1.4, 0.5), (s * (hw - 0.55), y, 0.55), bevel=0.04, m=gmat("WoodDark"))]
    p += [box("Beam", (W - 0.4, 0.3, 0.3), (0, D / 2, H - 0.2), bevel=0.03, m=gmat("WoodDark")),
          box("BeamB", (W - 0.4, 0.3, 0.3), (0, 2.0, H - 0.2), bevel=0.03, m=gmat("WoodDark")),
          box("BeamC", (W - 0.4, 0.3, 0.3), (0, D - 2.0, H - 0.2), bevel=0.03, m=gmat("WoodDark")),
          box("Loftfloor", (W - 0.6, D - 0.6, 0.15), (0, D / 2, H + 0.05), bevel=0.0, m=gmat("Wood", rough=0.8))]
    bulb_m = gglow("GulchLampGlow", "#ffd88a", 3.0)
    for y in (2.0, D - 2.0):
        p.append(bulb(f"Lantern{y}", 0.12, (0, y, H - 0.6), bulb_m))
    p += sign("S", "LIVERY", 0, -0.25, H + 2.6, 3.6, 0.7, board=trim, ink=barn_b, size=0.46)
    save("gulch_livery", [merge("Livery", p)])


# ---------------------------------------------------------------------------
# Water tower, gate, mine and tunnel mouths
# ---------------------------------------------------------------------------

TOWER_DECK = 3.2
TOWER_HALF = 3.2


def build_water_tower():
    reset_scene()
    wood, dark, light = gmat("Wood", rough=0.8), gmat("WoodDark", rough=0.8), gmat("WoodLight", rough=0.8)
    iron = gmat("Iron", rough=0.45, metal=0.3)
    p = []
    L = 2.2
    # Legs from the ground through the deck to the tank, with cross braces.
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box(f"Leg{sx}{sy}", (0.34, 0.34, 7.6), (sx * L, sy * L, 3.8), bevel=0.04, m=dark))
    for z0, z1 in ((0.4, TOWER_DECK - 0.3), (TOWER_DECK + 0.3, 7.2)):
        for s_ in (-1, 1):
            for a in (-1, 1):
                p.append(tube(f"BraceX{s_}{a}{z0}", [(s_ * L, -a * L, z0), (s_ * L, a * L, z1)], 0.08, m=wood, segs=6))
                p.append(tube(f"BraceY{s_}{a}{z0}", [(-a * L, s_ * L, z0), (a * L, s_ * L, z1)], 0.08, m=wood, segs=6))
    # The deck (its top at TOWER_DECK) with railings on three sides.
    p.append(box("Deck", (2 * TOWER_HALF, 2 * TOWER_HALF, 0.24), (0, 0, TOWER_DECK - 0.12), bevel=0.03, m=light))
    for k in range(int(2 * TOWER_HALF / 0.5)):
        p.append(box(f"DeckBoard{k}", (0.03, 2 * TOWER_HALF, 0.01), (-TOWER_HALF + 0.25 + k * 0.5, 0, TOWER_DECK + 0.005), bevel=0.0, m=dark))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box(f"DeckPost{sx}{sy}", (0.2, 0.2, TOWER_DECK), (sx * (TOWER_HALF - 0.15), sy * (TOWER_HALF - 0.15), TOWER_DECK / 2), bevel=0.03, m=dark))
    # Railed round, but for the stair opening on the +X side's -Y end (south-west in the level).
    rails = [((-TOWER_HALF, TOWER_HALF), (TOWER_HALF, TOWER_HALF)), ((TOWER_HALF, -TOWER_HALF + 2.2), (TOWER_HALF, TOWER_HALF)),
             ((-TOWER_HALF, -TOWER_HALF), (-TOWER_HALF, TOWER_HALF)), ((-TOWER_HALF, -TOWER_HALF), (TOWER_HALF, -TOWER_HALF))]
    for i, (a, b) in enumerate(rails):
        ax, ay = a
        bx, by = b
        length = math.hypot(bx - ax, by - ay)
        yaw = math.atan2(by - ay, bx - ax)
        p.append(box(f"Rail{i}", (length, 0.1, 0.1), ((ax + bx) / 2, (ay + by) / 2, TOWER_DECK + 1.05), rot=(0, 0, yaw), bevel=0.02, m=light))
        p.append(box(f"RailMid{i}", (length, 0.06, 0.08), ((ax + bx) / 2, (ay + by) / 2, TOWER_DECK + 0.55), rot=(0, 0, yaw), bevel=0.0, m=light))
        for k in range(int(length / 1.2) + 1):
            t = k / max(1, int(length / 1.2))
            p.append(box(f"RailPost{i}{k}", (0.12, 0.12, 1.1), (ax + (bx - ax) * t, ay + (by - ay) * t, TOWER_DECK + 0.55), bevel=0.02, m=dark))
    # The tank: staves, iron hoops, a conical roof, a spout and the town name.
    tz = 7.4
    staves = [gmat("WoodLight", rough=0.8), gmat("Wood", rough=0.8)]
    p.append(lathe("Tank", [(2.4, tz), (2.45, tz + 1.9), (2.4, tz + 3.8)], staves, segs=28, stripes=1, smooth=False))
    p.append(cyl("TankFloor", 2.5, 0.3, (0, 0, tz + 0.1), segs=28, bevel=0.03, m=dark))
    for k in range(4):
        p.append(torus(f"Hoop{k}", 2.47, 0.05, (0, 0, tz + 0.4 + k * 1.0), m=iron, major_segs=28, minor_segs=4))
    p.append(lathe("Cone", [(2.75, tz + 3.75), (0.25, tz + 5.2), (0.05, tz + 5.25)], [gmat("TerraDark", rough=0.7)], segs=28, smooth=False))
    p.append(sphere("Finial", 0.22, (0, 0, tz + 5.35), m=gmat("Gold", rough=0.3, metal=0.5), segs=10, rings=6))
    p += [tube("Spout", [(0, -2.4, tz + 0.6), (0, -3.3, tz - 0.1), (0, -3.5, tz - 1.0)], 0.16, m=iron, segs=8),
          box("SpoutRope", (0.03, 0.03, 2.0), (0.15, -3.4, tz - 2.0), bevel=0.0, m=gmat("Straw"))]
    p.append(box("Ladder", (0.5, 0.06, tz + 3.8 - TOWER_DECK), (0, 2.42, (tz + 3.8 + TOWER_DECK) / 2), bevel=0.0, m=iron))
    # Lettering painted on the tank.
    word = "BOOMTOWN"
    for i, ch in enumerate(word):
        a = math.radians(-90 + (i - (len(word) - 1) / 2) * 11.0)
        x, y = math.cos(a) * 2.48, math.sin(a) * 2.48
        t = text(f"Letter{i}", ch, 0.62, 0.05, (x, y, tz + 1.65), rot=(0, 0, a + math.pi / 2), m=gmat("RedDark", rough=0.5))
        p.append(t)
    save("gulch_water_tower", [merge("WaterTower", p)])


def build_gate():
    reset_scene()
    log, dark, gold = gmat("Wood", rough=0.8), gmat("WoodDark", rough=0.8), gmat("Gold", rough=0.3, metal=0.5)
    X = 8.2
    p = []
    for s in (-1, 1):
        p += [cyl(f"Post{s}", 0.45, 8.0, (s * X, 0, 4.0), segs=12, bevel=0.06, m=log),
              cyl(f"PostCap{s}", 0.55, 0.3, (s * X, 0, 8.15), segs=12, bevel=0.06, m=dark),
              box(f"Footing{s}", (1.6, 1.6, 0.6), (s * X, 0, 0.3), bevel=0.06, m=gmat("RockDark", rough=0.9))]
        p.append(tube(f"Brace{s}", [(s * X, 0, 5.2), (s * (X - 1.8), 0, 7.0)], 0.16, m=log, segs=8))
    p += [cyl("Beam", 0.38, 2 * X + 1.6, (0, 0, 7.0), rot=rad(0, 90, 0), segs=12, bevel=0.05, m=log),
          cyl("BeamTop", 0.3, 2 * X + 1.0, (0, 0, 7.7), rot=rad(0, 90, 0), segs=12, bevel=0.05, m=dark)]
    # The hanging sign on chains.
    p += [box("SignBoard", (8.4, 0.24, 1.5), (0, 0, 5.5), bevel=0.08, m=gmat("RedDark", rough=0.6)),
          box("SignTrim", (8.8, 0.18, 1.8), (0, 0.04, 5.5), bevel=0.06, m=gold),
          text("SignFront", "BOOMTOWN", 1.0, 0.1, (0, -0.15, 5.4), m=gmat("Cream", rough=0.5)),
          text("SignBack", "COME BACK SOON", 0.55, 0.06, (0, 0.15, 5.45), rot=(0, 0, math.pi), m=gmat("RedDark", rough=0.5))]
    for s in (-1, 1):
        p.append(cyl(f"Chain{s}", 0.04, 0.8, (s * 3.6, 0, 6.6), segs=4, bevel=0.0, m=gmat("Iron")))
    # Horseshoes and a lantern on each post.
    bulb_m = gglow("GulchLampGlow", "#ffd88a", 3.0)
    for s in (-1, 1):
        p.append(torus(f"Shoe{s}", 0.42, 0.08, (s * X, -0.46, 6.2), rot=rad(90, 0, 0), m=gold, major_segs=16, minor_segs=5,
                       arc=math.radians(250), start=math.radians(-35)))
        p += [box(f"LampArm{s}", (0.8, 0.08, 0.08), (s * (X - 0.7), -0.3, 4.6), bevel=0.0, m=gmat("Iron")),
              cyl(f"LampCage{s}", 0.16, 0.42, (s * (X - 1.05), -0.3, 4.25), segs=8, bevel=0.02, m=gmat("Iron")),
              bulb(f"LampBulb{s}", 0.12, (s * (X - 1.05), -0.3, 4.25), bulb_m)]
    p += [star("StarL", 0.5, 0.1, (-5.2, -0.16, 5.5), rot=(math.pi / 2, 0, 0), m=gold),
          star("StarR", 0.5, 0.1, (5.2, -0.16, 5.5), rot=(math.pi / 2, 0, 0), m=gold)]
    save("gulch_gate", [merge("Gate", p)])


def timber_portal(prefix, ow, oh, sign_text, sign_w):
    """A mine-timber doorway (opening ow x oh) set against a rock face, sealed
    dark 0.6 m behind the frame, with lanterns and a sign."""
    log, dark = gmat("Wood", rough=0.8), gmat("WoodDark", rough=0.8)
    void = mat("GulchVoid", "#120c0c", rough=1.0)
    p = []
    for s in (-1, 1):
        p += [box(f"{prefix}Post{s}", (0.5, 0.5, oh + 0.5), (s * (ow / 2 + 0.25), 0, (oh + 0.5) / 2), bevel=0.06, m=log),
              box(f"{prefix}Strut{s}", (0.3, 0.3, 1.3), (s * (ow / 2 - 0.25), -0.05, oh - 0.45), rot=(0, s * 0.7, 0), bevel=0.04, m=dark)]
    p += [box(f"{prefix}Lintel", (ow + 1.6, 0.6, 0.6), (0, 0, oh + 0.3), bevel=0.06, m=log),
          box(f"{prefix}Lintel2", (ow + 2.0, 0.5, 0.35), (0, 0.1, oh + 0.78), bevel=0.05, m=dark)]
    # The dark mouth: a black seal just behind the frame (the train and the
    # miners vanish into it) and a short timber set inside the frame.
    p += [box(f"{prefix}Seal", (ow + 0.5, 0.06, oh + 0.3), (0, 0.6, (oh + 0.3) / 2), bevel=0.0, m=void),
          box(f"{prefix}SetL", (0.3, 0.3, oh), (-ow / 2 + 0.15, 0.3, oh / 2), bevel=0.03, m=dark),
          box(f"{prefix}SetR", (0.3, 0.3, oh), (ow / 2 - 0.15, 0.3, oh / 2), bevel=0.03, m=dark),
          box(f"{prefix}SetT", (ow, 0.3, 0.3), (0, 0.3, oh - 0.15), bevel=0.03, m=dark)]
    bulb_m = gglow("GulchLampGlow", "#ffd88a", 3.0)
    for s in (-1, 1):
        p += [cyl(f"{prefix}LampCage{s}", 0.15, 0.4, (s * (ow / 2 + 0.25), -0.42, oh - 0.6), segs=8, bevel=0.02, m=gmat("Iron")),
              bulb(f"{prefix}Lamp{s}", 0.12, (s * (ow / 2 + 0.25), -0.42, oh - 0.6), bulb_m)]
    p += sign(prefix + "Sign", sign_text, 0, -0.35, oh + 1.45, sign_w, 0.75, board=gmat("Cream", rough=0.6), trim=dark,
              ink=gmat("RedDark", rough=0.5), size=0.48)
    return p


def build_mine_mouth():
    reset_scene()
    p = timber_portal("M", 4.4, 4.0, "GOLD MINE", 3.4)
    rail = gmat("Iron", rough=0.4, metal=0.3)
    for s in (-1, 1):
        p.append(box(f"Rail{s}", (0.08, 9.0, 0.1), (s * 0.55, 0.5, 0.05), bevel=0.0, m=rail))
    for k in range(10):
        p.append(box(f"Tie{k}", (1.6, 0.22, 0.06), (0, -3.6 + k * 0.9, 0.03), bevel=0.0, m=gmat("WoodDark")))
    p += [box("Danger", (1.2, 0.08, 0.7), (-3.4, -0.3, 1.6), rot=(0, 0.08, 0), bevel=0.02, m=gmat("Bone", rough=0.8)),
          text("DangerText", "KEEP OUT", 0.18, 0.02, (-3.4, -0.36, 1.6), m=gmat("Red", rough=0.5)),
          box("DangerPost", (0.12, 0.12, 1.6), (-3.4, -0.2, 0.8), bevel=0.02, m=gmat("WoodDark"))]
    save("gulch_mine_mouth", [merge("MineMouth", p)])


def build_tunnel_mouth():
    reset_scene()
    p = timber_portal("T", 4.2, 4.4, "RUNAWAY MINE TRAIN", 5.6)
    p += [box("Stripe", (5.4, 0.1, 0.3), (0, -0.33, 4.6), bevel=0.0, m=gmat("Gold", rough=0.3, metal=0.4))]
    save("gulch_tunnel_mouth", [merge("TunnelMouth", p)])


BUILDERS = {
    "bank": build_bank, "sheriff": build_sheriff, "store": build_store, "assay": build_assay, "hotel": build_hotel,
    "saloon": build_saloon, "livery": build_livery, "tower": build_water_tower, "gate": build_gate,
    "mine": build_mine_mouth, "tunnel": build_tunnel_mouth,
}

if __name__ == "__main__":
    wanted = [a for a in sys.argv[1:] if a in BUILDERS] or list(BUILDERS)
    for key in wanted:
        BUILDERS[key]()
