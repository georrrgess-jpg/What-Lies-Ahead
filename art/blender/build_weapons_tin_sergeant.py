"""The Tin Sergeant (update 23 primary, player level 35, Toybox Town): a
painted toy-chest launcher that fires wind-up tin soldiers. Two models:

art/models/tin_sergeant.glb, the first-person viewmodel. Same conventions and
node contract as build_weapons.py (documented at the top of weapon_kit.py):
origin at the top of the grip, pointing along +Y, its own palette (set before
weapon_mats, so every finish, cell, decal and charm works). A royal-blue toy
chest with gold corner brackets and white cross belts on its flanks, a red
lid carrying the rail, a brass bugle for a barrel, a toy side drum for a stock
and a drumstick foregrip. Moving parts, driven by
scripts/weapons/views/tin_sergeant_view.gd and
scripts/weapons/reloads/tin_sergeant_reload.gd:

  Hatch       the red trapdoor in the chest's front deck (pivot on its right
              hinge, built open; it closes by turning +HATCH_OPEN about Y)
  Soldier     the loaded tin soldier standing in the hatch (pivot at his
              feet), his right arm SoldierArm a child (pivot at the shoulder)
  CellHolo    the reload's hologram soldier, on the Soldier's pivot
  Key         the big brass wind-up key on the left flank (turns about X)
  Flag        the "Fall in!" pennant on the right edge of the lid (pivot at
              the pole's foot; it lies along the lid and stands up on aim)
  Lamp0..5    the squad lamps along the lid's left edge: one per soldier out
  Cell        the glowing ring in the bugle's bell and the lid's rank stripe

art/models/tin_soldier.glb, the soldier in the field (scripts/weapons/
tin_soldier.gd), SOLDIER_H tall, facing +Y (Godot -Z), its own materials so
it reads as a toy soldier under any finish:

  Body        tunic, belt, cross belts, buttons, epaulettes, head and shako
              (pivot at the hips)
  LegL, LegR  white trousers and black boots (pivots at the hips, swing about X)
  ArmL        the swinging left arm (pivot at the shoulder)
  ArmR        the right arm at "shoulder arms" with the rifle (pivot at the shoulder)
  Key         the wind-up key on his back (pivot at the shaft's root, turns
              about Y in Blender, Z in Godot)

    python art/blender/build_weapons_tin_sergeant.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403
from weapon_kit import _save  # noqa: E402

LAMPS = 6
# The soldier in the field (metres, scripts/weapons/tin_soldier.gd MODEL_HEIGHT).
SOLDIER_H = 0.62
# The mini soldier standing in the hatch, and where his feet are.
MINI_H = 0.098
MINI_FEET = (-0.018, 0.132, 0.04)
# The hatch: centre on the deck, half size, how far it is open (degrees about Y).
HATCH_C = (-0.018, 0.132, 0.11)
HATCH_HALF = 0.027
HATCH_OPEN = 172.0
# The wind-up key on the left flank: its hub.
KEY_HUB = (-0.056, 0.02, 0.035)
RAIL_TOP = 0.13
DECK_Z = 0.11


def palette():
    """Royal Blue chest, Guardsman Red trim, navy dark, brass steel, gold accents."""
    mat("Shell", "#2f5fd0", rough=0.3)
    mat("Trim", "#e2443a", rough=0.32)
    mat("GunDark", "#1d2348", rough=0.48, metal=0.15)
    mat("GunSteel", "#e3b14c", rough=0.26, metal=0.75)
    mat("GunPink", "#f6ead2", rough=0.4)


def soldier_mats():
    """The tin soldier's own paint: blue tunic, white trousers, black shako and
    boots, gold buttons, a red plume and a pink tin face."""
    return dict(
        tunic=mat("TinTunic", "#2f5fd0", rough=0.28, metal=0.25),
        white=mat("TinWhite", "#f7f3ea", rough=0.35, metal=0.1),
        black=mat("TinBlack", "#16141f", rough=0.25, metal=0.3),
        gold=mat("TinGold", "#f2c23a", rough=0.22, metal=0.8, emit=0.25),
        red=mat("TinRed", "#e2443a", rough=0.3, metal=0.2, emit=0.35),
        skin=mat("TinSkin", "#f4c7a8", rough=0.4, metal=0.1),
        cheek=mat("TinCheek", "#f07a8a", rough=0.5),
        wood=mat("TinWood", "#9a5a2e", rough=0.5),
        steel=mat("TinSteel", "#c9d0dc", rough=0.2, metal=0.85),
        brass=mat("TinBrass", "#e0b04a", rough=0.2, metal=0.85, emit=0.2),
    )


def transform_parts(parts, matrix):
    """Moves built parts by a 4x4 matrix (their mesh stays in their own space)."""
    bpy.context.view_layer.update()
    for p in parts:
        p.matrix_world = matrix @ p.matrix_world
    return parts


def tin_soldier(prefix, s, T, rifle=True):
    """A tin soldier `s` tall, feet on the origin, facing +Y. Returns
    {part: (parts, pivot)} for Body, LegL, LegR, ArmL, ArmR and Key."""
    def p(x, y, z):
        return (x * s, y * s, z * s)

    hip_z, sh_z = 0.43, 0.69
    body = [
        box(prefix + "Tunic", p(0.25, 0.16, 0.3), p(0, 0, 0.56), bevel=0.04 * s, segs=3, m=T["tunic"]),
        box(prefix + "Tails", p(0.24, 0.15, 0.08), p(0, -0.01, 0.42), bevel=0.025 * s, m=T["tunic"]),
        box(prefix + "Belt", p(0.262, 0.172, 0.04), p(0, 0, 0.46), bevel=0.012 * s, m=T["white"]),
        box(prefix + "Buckle", p(0.06, 0.02, 0.045), p(0, 0.088, 0.46), bevel=0.008 * s, m=T["gold"]),
        box(prefix + "Collar", p(0.15, 0.13, 0.04), p(0, 0, 0.715), bevel=0.015 * s, m=T["red"]),
    ]
    for side in (1, -1):
        body.append(obox(f"{prefix}CrossBelt{side}", p(0.045, 0.012, 0.36), p(side * 0.0, 0.083, 0.585), (side * 0.55, 0, 1), (0, 1, 0),
                         bevel=0.004 * s, m=T["white"]))
        body.append(obox(f"{prefix}CrossBeltB{side}", p(0.045, 0.012, 0.36), p(side * 0.0, -0.083, 0.585), (side * 0.55, 0, 1), (0, 1, 0),
                         bevel=0.004 * s, m=T["white"]))
        body.append(box(f"{prefix}Epaulette{side}", p(0.09, 0.12, 0.03), p(side * 0.125, 0, 0.71), bevel=0.012 * s, m=T["gold"]))
        for k in range(3):
            body.append(cyl(f"{prefix}Fringe{side}{k}", 0.008 * s, 0.035 * s, p(side * 0.17, -0.04 + k * 0.04, 0.69), segs=6, bevel=0.0, m=T["gold"]))
    for i in range(3):
        body.append(sphere(f"{prefix}Button{i}", 0.016 * s, p(0, 0.083, 0.64 - i * 0.065), m=T["gold"], segs=8, rings=5))
    # The head: a round tin face with rosy cheeks, two dot eyes and a waxed moustache.
    head_z = 0.8
    body += [
        cyl(prefix + "Neck", 0.04 * s, 0.05 * s, p(0, 0, 0.74), segs=10, bevel=0.0, m=T["skin"]),
        sphere(prefix + "Head", 0.088 * s, p(0, 0, head_z), scale=(1, 0.95, 1.05), m=T["skin"], segs=16, rings=10),
        sphere(prefix + "Nose", 0.017 * s, p(0, 0.085, head_z - 0.005), m=T["cheek"], segs=8, rings=5),
    ]
    for side in (1, -1):
        body.append(sphere(f"{prefix}Eye{side}", 0.012 * s, p(side * 0.032, 0.078, head_z + 0.022), m=T["black"], segs=8, rings=5))
        body.append(sphere(f"{prefix}Cheek{side}", 0.02 * s, p(side * 0.055, 0.07, head_z - 0.01), scale=(1, 0.4, 0.8), m=T["cheek"], segs=8, rings=5))
        body.append(tube(f"{prefix}Tache{side}", [p(0, 0.088, head_z - 0.027), p(side * 0.03, 0.09, head_z - 0.032), p(side * 0.055, 0.082, head_z - 0.018),
                                                  p(side * 0.062, 0.074, head_z - 0.002)], 0.011 * s, m=T["black"], segs=6, radius_end=0.004 * s))
    # The shako: a tall black drum with a gold band and plate, a peak, a chin strap and a red plume.
    body += [
        cyl(prefix + "Shako", 0.082 * s, 0.17 * s, p(0, 0, 0.94), segs=18, bevel=0.012 * s, m=T["black"], radius_top=0.094 * s),
        cyl(prefix + "ShakoBand", 0.086 * s, 0.022 * s, p(0, 0, 0.87), segs=18, bevel=0.0, m=T["gold"]),
        cyl(prefix + "ShakoTop", 0.097 * s, 0.018 * s, p(0, 0, 1.025), segs=18, bevel=0.004 * s, m=T["red"]),
        star(prefix + "ShakoPlate", 0.034 * s, 0.01 * s, p(0, 0.088, 0.945), rot=rad(4, 0, 0), m=T["gold"]),
        box(prefix + "Peak", p(0.15, 0.06, 0.014), p(0, 0.085, 0.862), rot=rad(-14, 0, 0), bevel=0.006 * s, m=T["black"]),
        tube(prefix + "Strap", [p(-0.082, 0.0, 0.87), p(-0.05, 0.06, 0.745), p(0.05, 0.06, 0.745), p(0.082, 0.0, 0.87)], 0.007 * s, m=T["gold"], segs=5),
        sphere(prefix + "Plume", 0.04 * s, p(0, 0.02, 1.08), scale=(1, 1, 1.5), m=T["red"], segs=12, rings=8),
        sphere(prefix + "Pompom", 0.022 * s, p(0, 0.02, 1.035), m=T["white"], segs=8, rings=5),
    ]
    legs = {}
    for side, nm in ((1, "LegR"), (-1, "LegL")):
        x = side * 0.065
        legs[nm] = ([
            cyl(f"{prefix}{nm}Thigh", 0.056 * s, 0.32 * s, p(x, 0, hip_z - 0.16), segs=12, bevel=0.01 * s, m=T["white"]),
            cyl(f"{prefix}{nm}Stripe", 0.0575 * s, 0.24 * s, p(x + side * 0.01, 0, hip_z - 0.2), segs=12, bevel=0.0, m=T["white"]),
            cyl(f"{prefix}{nm}Boot", 0.06 * s, 0.15 * s, p(x, 0, 0.075), segs=12, bevel=0.012 * s, m=T["black"]),
            box(f"{prefix}{nm}Toe", p(0.1, 0.13, 0.06), p(x, 0.04, 0.03), bevel=0.025 * s, m=T["black"]),
        ], p(x, 0, hip_z))
    arms = {}
    for side, nm in ((-1, "ArmL"), (1, "ArmR")):
        x = side * 0.165
        parts = [
            sphere(f"{prefix}{nm}Shoulder", 0.048 * s, p(x, 0, sh_z - 0.01), m=T["tunic"], segs=10, rings=6),
            cyl(f"{prefix}{nm}Sleeve", 0.042 * s, 0.24 * s, p(x, 0, sh_z - 0.13), segs=10, bevel=0.01 * s, m=T["tunic"]),
            cyl(f"{prefix}{nm}Cuff", 0.046 * s, 0.035 * s, p(x, 0, sh_z - 0.25), segs=10, bevel=0.004 * s, m=T["red"]),
            sphere(f"{prefix}{nm}Hand", 0.038 * s, p(x, 0, sh_z - 0.29), m=T["white"], segs=10, rings=6),
        ]
        if nm == "ArmR" and rifle:
            # Shoulder arms: the rifle stands against the shoulder, butt in the hand.
            lean = rad(-8, 0, 0)
            parts += [
                box(f"{prefix}RifleStock", p(0.03, 0.06, 0.2), p(x + 0.02, 0.03, sh_z - 0.25), rot=lean, bevel=0.01 * s, m=T["wood"]),
                cyl(f"{prefix}RifleBarrel", 0.014 * s, 0.38 * s, p(x + 0.02, 0.0, sh_z + 0.03), rot=lean, segs=8, bevel=0.0, m=T["steel"]),
                cyl(f"{prefix}RifleBand", 0.018 * s, 0.02 * s, p(x + 0.02, 0.012, sh_z - 0.06), rot=lean, segs=8, bevel=0.0, m=T["brass"]),
                cyl(f"{prefix}Bayonet", 0.007 * s, 0.12 * s, p(x + 0.02, -0.025, sh_z + 0.27), rot=lean, segs=6, bevel=0.0, m=T["steel"],
                    radius_top=0.001 * s),
            ]
        arms[nm] = (parts, p(x, 0, sh_z))
    # The wind-up key on his back: a shaft out of the back and a two-loop bow.
    key_root = p(0, -0.08, 0.6)
    key = [
        cyl(prefix + "KeyCollar", 0.03 * s, 0.03 * s, p(0, -0.09, 0.6), rot=rad(90, 0, 0), segs=12, bevel=0.005 * s, m=T["brass"]),
        cyl(prefix + "KeyShaft", 0.016 * s, 0.1 * s, p(0, -0.14, 0.6), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=T["brass"]),
        box(prefix + "KeyStem", p(0.05, 0.03, 0.04), p(0, -0.19, 0.6), bevel=0.01 * s, m=T["brass"]),
    ]
    for side in (1, -1):
        key.append(torus(f"{prefix}KeyBow{side}", 0.055 * s, 0.017 * s, p(side * 0.075, -0.2, 0.6), rot=rad(90, 0, 0), m=T["brass"],
                         major_segs=16, minor_segs=6))
    out = {"Body": (body, p(0, 0, hip_z)), "Key": (key, key_root)}
    out.update(legs)
    out.update(arms)
    return out


# ---------------------------------------------------------------------------
# The viewmodel
# ---------------------------------------------------------------------------

def build_tin_sergeant():
    reset_scene()
    palette()
    M = weapon_mats("#ffd24a", emit=2.2)
    T = soldier_mats()
    white = mat("ChestWhite", "#f7f3ea", rough=0.35)
    lamp = mat("LampLit", "#ffe65a", rough=0.3, emit=4.5)
    gold = M["steel"]
    grip_loc = (0, -0.03, -0.115)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.07, 0.092, 0.19), body_bottom=-0.02)
    z_line = RAIL_TOP + SIGHT_HEIGHT
    fore = (0, 0.2, -0.09)
    hx, hy, hz = HATCH_C
    bugle_z = 0.03

    chest_y0, chest_y1 = -0.08, 0.18
    chest_c = (chest_y0 + chest_y1) / 2
    chest_l = chest_y1 - chest_y0
    shell = grip_parts + [
        # The toy chest: royal blue, a red lid over its back two thirds, a dark plinth.
        box("Chest", (0.108, chest_l, 0.13), (0, chest_c, 0.045), bevel=0.012, segs=2, m=M["shell"]),
        box("Plinth", (0.112, chest_l + 0.006, 0.012), (0, chest_c, -0.013), bevel=0.005, m=M["dark"]),
        box("Lid", (0.114, 0.165, 0.01), (0, -0.003, DECK_Z + 0.002), bevel=0.004, m=M["trim"]),
        box("LidLip", (0.116, 0.005, 0.012), (0, 0.08, DECK_Z + 0.002), bevel=0.002, m=gold),
        box("RailRiser", (0.032, 0.15, 0.012), (0, -0.005, RAIL_TOP - 0.015), bevel=0.003, m=M["dark"]),
        # The hatch's dark well and its gold frame.
        box("HatchWell", (2 * HATCH_HALF, 2 * HATCH_HALF, 0.004), (hx, hy, DECK_Z + 0.0005), bevel=0.0, m=M["dark"]),
        # The bugle: a brass tube out of the chest's front with a flared bell.
        ycyl("BugleMount", 0.032, 0.02, chest_y1 + 0.008, z=bugle_z, m=M["dark"], segs=24, bevel=0.004),
        ycyl("BugleTube", 0.019, 0.1, chest_y1 + 0.06, z=bugle_z, m=gold, segs=24, bevel=0.0),
        ycyl("BugleBell", 0.021, 0.07, chest_y1 + 0.142, z=bugle_z, m=gold, segs=32, bevel=0.0, radius_top=0.05),
        ring("BugleLip", 0.05, 0.0045, chest_y1 + 0.177, z=bugle_z, m=gold, segs=40),
        ycyl("BugleThroat", 0.043, 0.004, chest_y1 + 0.172, z=bugle_z, m=M["dark"], segs=32, bevel=0.0),
        ring("BugleBand0", 0.0215, 0.004, chest_y1 + 0.03, z=bugle_z, m=M["trim"], segs=24),
        ring("BugleBand1", 0.0215, 0.004, chest_y1 + 0.09, z=bugle_z, m=M["trim"], segs=24),
        # The stock: a toy side drum lying along the gun, white with red hoops and gold cords.
        ycyl("Drum", 0.026, 0.04, -0.1, z=0.015, m=white, segs=28, bevel=0.004),
        ring("DrumHoop0", 0.027, 0.0045, -0.081, z=0.015, m=M["trim"], segs=28),
        ring("DrumHoop1", 0.027, 0.0045, -0.119, z=0.015, m=M["trim"], segs=28),
        ycyl("DrumHead", 0.023, 0.003, -0.121, z=0.015, m=M["dark"], segs=28, bevel=0.0),
        # The drumstick foregrip with a red knob.
        box("ForegripMount", (0.034, 0.04, 0.05), (0, fore[1], -0.012), bevel=0.006, m=M["dark"]),
        cyl("Foregrip", 0.018, 0.12, fore, segs=18, bevel=0.006, m=white),
        sphere("ForegripKnob", 0.02, (0, fore[1], fore[2] - 0.072), m=M["trim"], segs=16, rings=10),
    ]
    for k in range(8):
        a = math.tau * k / 8 + 0.2
        y0, y1 = -0.083, -0.117
        shell.append(tube(f"DrumCord{k}", [(math.cos(a) * 0.0265, y0, 0.015 + math.sin(a) * 0.0265),
                                            (math.cos(a + 0.39) * 0.0265, (y0 + y1) / 2, 0.015 + math.sin(a + 0.39) * 0.0265),
                                            (math.cos(a + 0.78) * 0.0265, y1, 0.015 + math.sin(a + 0.78) * 0.0265)], 0.0015, m=gold, segs=4))
    # Gold corner brackets on the chest, white cross belts and a buckle on each flank.
    for sx in (1, -1):
        for sy, y in ((1, chest_y1), (-1, chest_y0)):
            for z in (-0.012, DECK_Z - 0.012):
                shell.append(box(f"Bracket{sx}{sy}{z:.2f}", (0.012, 0.022, 0.022), (sx * 0.052, y - sy * 0.009, z), bevel=0.004, m=gold))
        flank = sx * 0.0545
        for lean in (1, -1):
            shell.append(obox(f"Belt{sx}{lean}", (0.003, 0.016, 0.17), (flank, 0.05, 0.045), (0, lean * 0.95, 0.62), (sx, 0, 0), bevel=0.001,
                              m=white))
        shell.append(box(f"Buckle{sx}", (0.006, 0.026, 0.026), (flank + sx * 0.002, 0.05, 0.045), bevel=0.004, m=gold))
        shell.append(prism(f"BuckleStar{sx}", star_outline(0.0085, 0.0038), 0.003, (flank + sx * 0.0045, 0.05, 0.045), rot=rad(0, 0, 90),
                           m=M["trim"]))
    # Lamp sockets along the lid's left edge (one per soldier out).
    lamps = {}
    for i in range(LAMPS):
        at = (-0.046, -0.062 + 0.022 * i, DECK_Z + 0.008)
        shell.append(cyl(f"LampSocket{i}", 0.0072, 0.004, (at[0], at[1], at[2] - 0.001), segs=12, bevel=0.0, m=M["dark"]))
        lamps[f"Lamp{i}"] = ([sphere(f"LampGlow{i}", 0.0058, at, scale=(1, 1, 0.75), m=lamp, segs=10, rings=6)], at)
    shell += top_rail("TopRail", -0.072, 0.062, RAIL_TOP, M, width=0.03)
    shell += bolts("Pin", [(0.054, -0.05, 0.0), (0.054, 0.14, 0.0)], M["dark"], radius=0.005, height=0.004)
    # The charm hangs off the chest's front right corner, ahead of the hands.
    lug, charm_point = charm_lug(0.064, 0.15, 0.02, M, out=1.0)
    shell += lug
    shell.append(box("CharmLugFoot", (0.012, 0.02, 0.016), (0.058, 0.15, 0.024), bevel=0.003, m=M["dark"]))
    # Rear aperture on the lid, a brass post with a gold ball on the deck's front edge.
    sight_rear, sight_front = sights_ghost_ring(0.0, -0.07, 0.174, RAIL_TOP, DECK_Z, z_line, M)

    # The key on the left flank: a collar on the chest, the shaft, a two-loop bow.
    kx, ky, kz = KEY_HUB
    shell.append(xcyl("KeyBoss", 0.018, 0.006, (kx + 0.002, ky, kz), m=M["dark"], segs=20))
    key = [xcyl("KeyShaft", 0.0065, 0.03, (kx - 0.015, ky, kz), m=gold, segs=12),
           box("KeyStem", (0.01, 0.016, 0.014), (kx - 0.031, ky, kz), bevel=0.003, m=gold)]
    for side in (1, -1):
        key.append(torus(f"KeyBow{side}", 0.018, 0.0055, (kx - 0.034, ky + side * 0.024, kz), rot=rad(0, 90, 0), m=gold,
                         major_segs=20, minor_segs=7))

    # The hatch, built closed then swung open about its right hinge.
    hinge = Vector((hx + HATCH_HALF, hy, DECK_Z + 0.002))
    hatch = [box("HatchDoor", (2 * HATCH_HALF, 2 * HATCH_HALF, 0.005), (hx, hy, DECK_Z + 0.0045), bevel=0.0015, m=M["trim"]),
             prism("HatchStar", star_outline(0.014, 0.0062), 0.002, (hx, hy, DECK_Z + 0.0075), rot=rad(90, 0, 0), m=gold),
             box("HatchHandle", (0.006, 0.014, 0.004), (hx - HATCH_HALF + 0.006, hy, DECK_Z + 0.008), bevel=0.0015, m=gold)]
    for k in (-1, 1):
        shell.append(cyl(f"HatchHinge{k}", 0.0035, 0.012, (hinge.x, hy + k * 0.018, hinge.z), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=gold))
    swing = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(-HATCH_OPEN), 4, "Y") @ Matrix.Translation(-hinge)
    transform_parts(hatch, swing)

    # The mini soldier in the hatch, his back to the player (his key shows).
    mini = tin_soldier("Mini", MINI_H, T, rifle=False)
    feet = Matrix.Translation(MINI_FEET)
    mini_parts = []
    for nm in ("Body", "LegL", "LegR", "ArmL", "Key"):
        mini_parts += transform_parts(mini[nm][0], feet)
    arm_parts = transform_parts(mini["ArmR"][0], feet)
    arm_pivot = tuple(feet @ Vector(mini["ArmR"][1]))
    holo = holo_copy(mini_parts + arm_parts)

    # The "Fall in!" pennant: a brass pole lying along the lid's right edge, a red swallowtail flag.
    flag_foot = (0.06, -0.045, DECK_Z + 0.002)
    fx, fy, fz = flag_foot
    flag = [ycyl("FlagPole", 0.0026, 0.1, fy + 0.05, z=fz, x=fx, m=gold, segs=8, bevel=0.0),
            sphere("FlagFinial", 0.005, (fx, fy + 0.101, fz), m=gold, segs=10, rings=6),
            prism("FlagCloth", [(0.0, 0.0), (0.052, 0.0), (0.04, -0.013), (0.052, -0.026), (0.0, -0.026)], 0.0016,
                  (fx + 0.0025, fy + 0.046, fz - 0.003), rot=rad(0, 0, 90), m=M["trim"]),
            prism("FlagStar", star_outline(0.0065, 0.003), 0.0018, (fx + 0.004, fy + 0.066, fz - 0.016), rot=rad(0, 0, 90), m=gold)]
    shell.append(box("FlagClip", (0.008, 0.012, 0.01), (fx - 0.002, fy, fz - 0.004), bevel=0.002, m=M["dark"]))

    # The bugle's bell glows inside (the energy cell), and a rank stripe on the lid.
    cell = [ring("BellGlow", 0.04, 0.0045, chest_y1 + 0.168, z=bugle_z, m=M["cell"], segs=36),
            box("RankStripe", (0.004, 0.11, 0.004), (0.046, -0.005, DECK_Z + 0.008), bevel=0.0015, m=M["cell"])]

    decal = [side_emblem("Emblem", star_outline(0.016, 0.007), -0.056, 0.125, 0.04, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = vertical_hand(fore, 0.021, 0.021, 0.12, M, (-0.52, -0.16, -0.46))
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.07, RAIL_TOP), None),
        "IronSightFront": (sight_front, (0, 0.174, DECK_Z), None),
        "Hatch": (hatch, tuple(hinge), None),
        "Soldier": (mini_parts, MINI_FEET, None),
        "SoldierArm": (arm_parts, arm_pivot, "Soldier"),
        "CellHolo": (holo, MINI_FEET, None),
        "Key": (key, KEY_HUB, None),
        "Flag": (flag, flag_foot, None),
        "Cell": (cell, (0, chest_y1 + 0.168, bugle_z), None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    for name, (parts, at) in lamps.items():
        groups[name] = (parts, at, None)
    empties = {
        "Muzzle": ((0, chest_y1 + 0.185, bugle_z), None),
        "SightPoint": ((0, -0.07, z_line), None),
        "SightMount": ((0, 0.008, RAIL_TOP), None),
        "EjectPoint": ((hx, hy, DECK_Z + 0.03), None),
        "VentPoint": ((kx - 0.03, ky, kz), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("tin_sergeant", groups, empties)


# ---------------------------------------------------------------------------
# The soldier in the field
# ---------------------------------------------------------------------------

def build_tin_soldier():
    reset_scene()
    T = soldier_mats()
    parts = tin_soldier("", SOLDIER_H, T)
    exports = {}
    for nm in ("Body", "LegL", "LegR", "ArmL", "ArmR", "Key"):
        exports[nm] = merge(nm, parts[nm][0], pivot=parts[nm][1])
    _save("tin_soldier", list(exports.values()))


BUILDERS = (
    ("tin_sergeant", build_tin_sergeant),
    ("tin_soldier", build_tin_soldier),
)

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for name, fn in BUILDERS:
        if not only or name in only:
            fn()
