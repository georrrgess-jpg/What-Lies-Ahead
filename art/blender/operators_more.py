"""The second crew of operators (update 4), built from the same kit as the
first nine (see build_operators.py, which registers them in OPERATORS):

    pixel_pal       kid in an 8-bit bunny mascot onesie (Prize Pier arcade)
    windup          Wind-Up Wally, a tin clockwork toy robot with a key on its back
    stunt_ace       Wall-of-Death daredevil in a starred jumpsuit and moto helmet
    halfpipe        Neon Skyline skater: beanie, big headphones, hoodie, board on the back
    top_dog         hot-dog stand hero: paper cap, striped shirt, apron, condiment holsters
    tide_keeper     aquarium keeper: sou'wester, bib waders, a fish-tank backpack
    mech_jockey     mech pilot: flight suit, shoulder armour, headset with an eyepiece
    cosmic_sheriff  space cowboy: ringed-planet hat, vest, sash, ray-gun holster, chaps
    timber_jack     lumberjack: trapper hat, beard, buffalo check, puffer vest, axe

Each builder returns (kit, pose style, idle style) like the ones in build_operators.py.
"""
import math

from operator_kit import *  # noqa: F401,F403
from operator_kit import HEAD_C, SHOULDER, ELBOW, WRIST, HIP, KNEE, ANKLE, Kit, sx

BULKY_HOLD = (0.06, -0.035, -0.015)


def _both(fn):
    for side in (1, -1):
        fn(side, "L" if side > 0 else "R")


def _detail(k, parts):
    return k.add(parts, field=True, tag="detail")


def _hairline(front=0.55, temple=0.2, side=-0.1, back=-0.42):
    from operator_anim import curve

    def fn(az):
        return curve(abs(az), [(0.0, front), (0.75, front), (1.15, temple), (1.6, side), (2.3, back), (math.pi, back)])
    return fn


def _hat_frame(z=0.15, tilt=-6.0, roll=0.0, y=0.0):
    return (Matrix.Translation(HEAD_C) @ Euler((math.radians(tilt), math.radians(roll), 0.0), "XYZ").to_matrix().to_4x4()
            @ Matrix.Translation((0.0, y, z)))


def _back_y(k, z, out=0.0):
    return k.torso_point(z, 90, out).y


def _straps(k, m, width=0.045, z_low=1.08, name="Strap"):
    for side in (1, -1):
        pts = [(side * 0.13, -0.3, z_low), (side * 0.14, -0.3, 1.22), (side * 0.15, -0.2, 1.345), (side * 0.15, 0.0, 1.38),
               (side * 0.15, 0.2, 1.345), (side * 0.14, 0.3, 1.22)]
        k.strap(f"{name}{side}", pts, width, m)


def _hand_on_hip_idle(**kw):
    out = dict(bend=20, out=0.27)
    out.update(kw)
    return out


# ---------------------------------------------------------------------------

def op_pixel_pal():
    """An 8-bit bunny mascot onesie: hood with tall stepped pixel ears and big
    mascot eyes, the kid's face peeking out, a pixel-heart belly screen, a
    coin pouch, a pom tail and paw boots."""
    k = Kit("PP_", "#f2c09a", dict(belly=0.35, waist=1.1, hip=1.06, arm=1.08, leg=1.04, depth=1.04))
    pink = mat("Onesie", "#ff6fb5", rough=0.85)
    pink_dark = mat("OnesieDark", "#e0418f", rough=0.85)
    cyan = mat("OnesieCyan", "#4fe3ff", rough=0.75)
    cream = mat("Cream", "#fff1dc", rough=0.85)
    purple = mat("Purple", "#6b35b8", rough=0.6)
    screen = mat("BellyScreen", "#1a1436", rough=0.2)
    heart = mat("PixelHeart", "#ff3f7f", rough=0.3, emit=2.2)
    black = mat("MascotPupil", "#14101e", rough=0.2)
    white = mat("MascotEye", "#ffffff", rough=0.25)
    hair = mat("Hair", "#4a2c1a", rough=0.75)
    gold = mat("Coin", "#ffc23d", rough=0.3, metal=0.7)

    k.head(ears=False)
    k.face(iris="#6b35b8", brow="#4a2c1a", mouth="open", lids=0.04, brow_tilt=-10, blush="#ff7fa0", freckles=True)
    k.hair_cap(hair, _hairline(0.48, 0.32, 0.1, -0.1), grow=0.03)
    k.neck(pink, r=0.075)
    c = HEAD_C + Vector((0, 0.035, 0.055))
    radius, opening = 0.3, 50.0
    rim_r = radius * math.sin(math.radians(opening))
    rim_y = c.y - radius * math.cos(math.radians(opening))
    hood = [open_shell(k.n("Hood"), radius, c, opening, pink, scale=(1.0, 1.0, 0.92), thickness=0.03),
            torus(k.n("HoodRim"), rim_r + 0.018, 0.04, (0, rim_y, c.z), rot=rad(90, 0, 0), m=cyan, major_segs=28, minor_segs=8)]
    # Mascot eyes on the top of the hood, looking forward.
    for side in (1, -1):
        e = c + Vector((side * 0.115, -0.2, 0.235))
        hood += [blob(k.n(f"MEye{side}"), 0.068, e, white, scale=(1.0, 0.62, 1.1), rot=rad(-38, 0, 0)),
                 blob(k.n(f"MPupil{side}"), 0.036, e + Vector((side * -0.008, -0.032, -0.006)), black, scale=(1.0, 0.5, 1.15), rot=rad(-38, 0, 0)),
                 blob(k.n(f"MShine{side}"), 0.012, e + Vector((side * -0.0, -0.05, 0.02)), white, segs=8, rings=5)]
    # Stepped pixel ears: three blocks each, leaning out a little.
    for side in (1, -1):
        base = c + Vector((side * 0.13, 0.03, radius * 0.86))
        for i, (w, h, dx) in enumerate(((0.12, 0.12, 0.0), (0.105, 0.11, 0.012), (0.085, 0.1, 0.028))):
            p = base + Vector((side * dx, 0, 0.055 + i * 0.105))
            hood.append(box(k.n(f"Ear{side}{i}"), (w, 0.07, h), p, rot=rad(0, side * -8, 0), bevel=0.018, m=pink))
            hood.append(box(k.n(f"EarIn{side}{i}"), (w * 0.52, 0.02, h * 0.7), p + Vector((side * 0.002, -0.034, 0)), rot=rad(0, side * -8, 0), bevel=0.008,
                            m=cyan))
    k.add(hood, bone="Head", tag="headgear")

    k.torso(pink, lower_m=pink)
    front = k.on_torso("front")
    _detail(k, [decal(k.n("Belly"), rrect(0, 1.09, 0.25, 0.22, 0.04), front, cream, lift=0.004),
                decal(k.n("Screen"), rrect(0, 1.13, 0.16, 0.12, 0.02), front, screen, lift=0.009, sink=0.0)])
    px = 0.018
    heart_cells = [(-2, 1), (-1, 2), (1, 2), (2, 1), (-2, 0), (-1, 1), (0, 1), (1, 1), (2, 0), (-1, 0), (0, 0), (1, 0), (-1, -1), (0, -1), (1, -1), (0, -2)]
    _detail(k, [decal(k.n(f"Px{i}"), rrect(x * px, 1.128 + y * px, px * 0.9, px * 0.9, 0.003), front, heart, lift=0.0125, sink=0.0)
                for i, (x, y) in enumerate(heart_cells)])
    _detail(k, strip(k.n("Zip"), line_path((0, 1.2), (0, 1.33), 0.02, steps=4), front, cyan, lift=0.006))
    k.belt(0.96, 0.04, purple, name="Belt")
    p = k.torso_point(0.95, 215, 0.02)
    k.add([box(k.n("Pouch"), (0.05, 0.11, 0.1), p, rot=rad(0, 0, 35), bevel=0.02, m=purple),
           box(k.n("CoinSlot"), (0.012, 0.05, 0.008), p + Vector((-0.023, -0.016, 0.028)), rot=rad(0, 0, 35), bevel=0.003, m=gold)], bone="Hips", tag="gear")
    k.add(blob(k.n("Tail"), 0.075, (0, _back_y(k, 0.9, 0.05), 0.9), cream), bone="Hips", tag="gear")

    def limbs(side, s):
        k.upper_arm(side, pink)
        k.fore_arm(side, pink)
        k.arm_band(side, "ForeArm", 0.7, 0.93, cyan, grow=0.008, name="Cuff")
        k.hand(side, cream, plate_m=pink_dark)
        k.thigh(side, pink)
        k.shin(side, pink)
        k.leg_band(side, "Shin", 0.62, 0.9, cyan, grow=0.012, name="Cuff")
        k.shoe(side, cream, pink_dark, toe_m=cream, style="boot", tongue_m=cream, heel_m=pink_dark)
    _both(limbs)
    return k, "bunny_hop", dict(bend=22, out=0.29, look=0.9, aim=BULKY_HOLD)


def op_windup():
    """Wind-Up Wally: a tin toy robot with a riveted barrel body, a can head with
    a glass lamp dome, porthole eyes, a chest dial, spring-coil limbs and a big
    wind-up key on its back."""
    k = Kit("WU_", "#9fb8c4", dict(chest=1.08, waist=1.14, hip=1.04, belly=0.4, arm=1.04, leg=1.02))
    tin = mat("Tin", "#2fb8b0", rough=0.3, metal=0.6)
    tin_dark = mat("TinDark", "#1c7f86", rough=0.32, metal=0.6)
    red = mat("TinRed", "#e8263a", rough=0.3, metal=0.5)
    brass = mat("Brass", "#ffc23d", rough=0.25, metal=0.85)
    silver = mat("Silver", "#d6dbe6", rough=0.25, metal=0.85)
    cream = mat("Cream", "#fff1dc", rough=0.4)
    dark = mat("Dark", "#1c1830", rough=0.4)
    eye = mat("EyeLamp", "#ffe25a", rough=0.2, emit=2.6)
    bulb = mat("Bulb", "#ff8a3a", rough=0.2, emit=3.0)
    glass = mat("FxGlassDome", "#cfefff", rough=0.05)

    c = HEAD_C + Vector((0, 0, -0.01))
    head = [cyl(k.n("Can"), 0.215, 0.3, c, segs=28, bevel=0.04, m=tin),
            torus(k.n("CanRimTop"), 0.212, 0.018, c + Vector((0, 0, 0.145)), m=red, major_segs=28, minor_segs=6),
            torus(k.n("CanRimLow"), 0.212, 0.018, c + Vector((0, 0, -0.145)), m=red, major_segs=28, minor_segs=6),
            cyl(k.n("DomeBase"), 0.13, 0.03, c + Vector((0, 0, 0.165)), segs=24, bevel=0.01, m=brass),
            blob(k.n("Lamp"), 0.05, c + Vector((0, 0, 0.215)), bulb, segs=12, rings=8)]
    k.add(head, bone="Head", tag="head")
    k.add(blob(k.n("Dome"), 0.11, c + Vector((0, 0, 0.2)), glass, scale=(1, 1, 0.9), segs=20, rings=10), bone="Head", tag="headgear")
    face_y = c.y - 0.215
    for side in (1, -1):
        e = Vector((side * 0.085, face_y - 0.004, c.z + 0.035))
        k.add([cyl(k.n(f"EyeRim{side}"), 0.058, 0.03, e, rot=rad(90, 0, 0), segs=20, bevel=0.01, m=silver),
               cyl(k.n(f"Eye{side}"), 0.042, 0.03, e + Vector((0, -0.008, 0)), rot=rad(90, 0, 0), segs=18, bevel=0.008, m=eye),
               cyl(k.n(f"Bolt{side}"), 0.045, 0.05, c + Vector((side * 0.225, 0, 0)), rot=rad(0, 90, 0), segs=14, bevel=0.012, m=brass),
               cyl(k.n(f"Antenna{side}"), 0.008, 0.12, c + Vector((side * 0.255, 0, 0.06)), rot=rad(0, side * 20, 0), segs=6, bevel=0.0, m=silver),
               blob(k.n(f"AntennaTip{side}"), 0.022, c + Vector((side * 0.276, 0, 0.12)), red, segs=8, rings=6)], bone="Head", tag="head")
    for i in range(5):
        k.add(box(k.n(f"Grille{i}"), (0.022, 0.03, 0.06), (-0.06 + i * 0.03, face_y - 0.004, c.z - 0.07), bevel=0.008, m=dark), bone="Head", tag="head")
    k.neck(silver, r=0.07)

    k.torso(tin, lower_m=tin_dark, split_z=0.95)
    k.shell("Barrel", 0.97, 1.33, tin, grow=0.022, thickness=0.016)
    for i, z in enumerate((0.99, 1.31)):
        k.belt(z, 0.035, red, grow=0.004, name=f"Hoop{i}")
        for j in range(12):
            a = 360.0 * j / 12
            k.add(blob(k.n(f"Rivet{i}{j}"), 0.011, k.torso_point(z, a, 0.004), brass, segs=6, rings=4), field=True, tag="detail")
    front = k.on_torso("front")
    _detail(k, [decal(k.n("Dial"), ellipse_outline(0, 1.17, 0.075, 0.075, 20), front, cream, lift=0.006, dome=0.004),
                decal(k.n("DialRim"), ellipse_outline(0, 1.17, 0.09, 0.09, 20), front, brass, lift=0.003),
                strip(k.n("Needle"), line_path((0, 1.17), (0.04, 1.21), 0.014, steps=3, taper=0.4), front, red, lift=0.013, sink=0.0),
                decal(k.n("DialHub"), ellipse_outline(0, 1.17, 0.012, 0.012, 8), front, dark, lift=0.015, sink=0.0)]
            + [decal(k.n(f"Tick{i}"), ellipse_outline(math.cos(a) * 0.058, 1.17 + math.sin(a) * 0.058, 0.007, 0.007, 6), front, dark, lift=0.011, sink=0.0)
               for i, a in enumerate(math.radians(d) for d in (30, 70, 110, 150, 190, 350, 310))])
    by = _back_y(k, 1.16, 0.0)
    key = [cyl(k.n("KeyShaft"), 0.026, 0.14, (0, by + 0.06, 1.16), rot=rad(90, 0, 0), segs=12, bevel=0.008, m=brass),
           cyl(k.n("KeyCollar"), 0.05, 0.03, (0, by + 0.01, 1.16), rot=rad(90, 0, 0), segs=16, bevel=0.01, m=brass),
           blob(k.n("KeyHub"), 0.04, (0, by + 0.14, 1.16), brass, scale=(1, 0.7, 1))]
    for side in (1, -1):
        key.append(torus(k.n(f"KeyLoop{side}"), 0.062, 0.022, (side * 0.085, by + 0.14, 1.16), rot=rad(90, 0, 0), m=brass, major_segs=20, minor_segs=8))
    k.add(key, bone="Chest", tag="gear")

    def limbs(side, s):
        k.upper_arm(side, silver, r0=0.07, r1=0.06)
        for i in range(3):
            k.arm_band(side, "UpperArm", 0.2 + i * 0.17, 0.28 + i * 0.17, tin_dark, grow=0.012, name=f"Coil{i}")
        k.arm_band(side, "UpperArm", -0.1, 0.12, red, grow=0.018, name="Shoulder")
        k.fore_arm(side, silver)
        for i in range(3):
            k.arm_band(side, "ForeArm", 0.12 + i * 0.18, 0.21 + i * 0.18, tin_dark, grow=0.012, name=f"Coil{i}")
        k.arm_band(side, "ForeArm", 0.72, 0.93, red, grow=0.008, name="Cuff")
        k.hand(side, red, plate_m=brass)
        k.thigh(side, silver)
        for i in range(3):
            k.leg_band(side, "Thigh", 0.15 + i * 0.25, 0.26 + i * 0.25, tin_dark, grow=0.012, name=f"Coil{i}")
        k.shin(side, silver)
        k.leg_band(side, "Shin", -0.02, 0.14, brass, grow=0.012, name="Knee")
        k.shoe(side, red, dark, toe_m=tin, style="boot", collar_m=tin_dark, shaft=0.16, shaft_m=red)
    _both(limbs)
    return k, "robot", dict(bend=14, out=0.3, look=0.7, sway=0.5, aim=BULKY_HOLD, run_head=-6.0)


def op_stunt_ace():
    """Wall-of-Death daredevil: white leather jumpsuit with flag stripes and
    stars, a high collar, an open-face moto helmet with goggles on the brow,
    a star buckle, elbow and knee pads, riding boots."""
    k = Kit("SA_", "#d9a07a", dict(shoulder=1.06, chest=1.04, waist=0.95))
    white = mat("Leather", "#f7f4f2", rough=0.4)
    red = mat("FlagRed", "#e8263a", rough=0.4)
    blue = mat("FlagBlue", "#2f4fcf", rough=0.4)
    gold = mat("Gold", "#ffc23d", rough=0.25, metal=0.85)
    helmet = mat("Helmet", "#f7f4f2", rough=0.25)
    dark = mat("Pad", "#2b2836", rough=0.5)
    lens = mat("GoggleLens", "#ffb62e", rough=0.1, metal=0.5)
    hair = mat("Hair", "#2a1a12", rough=0.75)

    k.head()
    k.face(iris="#2f5f9f", brow="#2a1a12", mouth="grin", lids=0.1, brow_tilt=-12, blush="#e08a6a")
    k.hair_cap(hair, _hairline(0.55, 0.3, 0.0, -0.3), grow=0.03)
    k.neck()
    shell_parts = k.hair_cap(helmet, _hairline(0.42, 0.3, 0.12, -0.2), grow=0.16, name="Helmet", tag="headgear")
    top = Surface(shell_parts).projector("top")
    side_l, side_r = Surface(shell_parts).projector("left"), Surface(shell_parts).projector("right")
    hy = HEAD_C.y
    k.add([strip(k.n("StripeR"), line_path((0, hy - 0.26), (0, hy + 0.27), 0.07, steps=12, taper=0.6), top, red, lift=0.005),
           strip(k.n("StripeB1"), line_path((0.055, hy - 0.24), (0.055, hy + 0.25), 0.02, steps=12, taper=0.6), top, blue, lift=0.005),
           strip(k.n("StripeB2"), line_path((-0.055, hy - 0.24), (-0.055, hy + 0.25), 0.02, steps=12, taper=0.6), top, blue, lift=0.005),
           decal(k.n("StarL"), star_at(0.0, HEAD_C.z + 0.08, 0.06, 0.028), side_l, red, lift=0.006, dome=0.002),
           decal(k.n("StarR"), star_at(0.0, HEAD_C.z + 0.08, 0.06, 0.028), side_r, red, lift=0.006, dome=0.002)], bone="Head", tag="headgear")
    # Goggles pushed up on the helmet's brow.
    gz = HEAD_C.z + 0.215
    k.add([box(k.n("GoggleFrame"), (0.3, 0.05, 0.075), (0, HEAD_C.y - 0.235, gz), rot=rad(-30, 0, 0), bevel=0.028, m=dark)]
          + [blob(k.n(f"Goggle{s}"), 1.0, (s * 0.075, HEAD_C.y - 0.262, gz - 0.006), lens, scale=(0.06, 0.028, 0.04), rot=rad(-30, 0, 0)) for s in (1, -1)],
          bone="Head", tag="headgear")

    k.torso(white)
    k.shell("Suit", 0.9, 1.35, white, grow=0.012, thickness=0.012)
    k.shell("Collar", 1.33, 1.43, white, grow=0.032, thickness=0.012, gap=(28.0, 42.0), segs=20)
    front, back = k.on_torso("front"), k.on_torso("back")
    for x, m in ((0.075, red), (0.105, blue), (-0.075, red), (-0.105, blue)):
        _detail(k, [strip(k.n(f"StripeF{x}"), line_path((x, 0.92), (x, 1.32), 0.022, steps=9), front, m, lift=0.004),
                    strip(k.n(f"StripeB{x}"), line_path((x, 0.92), (x, 1.32), 0.022, steps=9), back, m, lift=0.004)])
    _detail(k, [decal(k.n("ChestStar"), star_at(0.0, 1.2, 0.05, 0.022), front, gold, lift=0.006, dome=0.003),
                decal(k.n("BackStar"), star_at(0.0, 1.18, 0.09, 0.04), back, red, lift=0.006, dome=0.002),
                strip(k.n("Zip"), line_path((0, 0.99), (0, 1.15), 0.016, steps=5), front, gold, lift=0.005)])
    k.belt(0.975, 0.06, blue)
    _detail(k, [decal(k.n("Buckle"), star_at(0.0, 0.975, 0.05, 0.026), k.on_torso("front"), gold, lift=0.012, dome=0.004)])
    for side in (1, -1):
        p = k.torso_point(1.345, 270 + side * 62, 0.004)
        k.add(blob(k.n(f"Epaulette{side}"), 0.05, p + Vector((side * 0.0, 0, 0.012)), gold, scale=(1.3, 1.0, 0.45)), bone="Chest", tag="gear")

    def limbs(side, s):
        k.upper_arm(side, white)
        k.arm_band(side, "UpperArm", 0.3, 0.38, red, grow=0.004, name="StripeR")
        k.arm_band(side, "UpperArm", 0.4, 0.46, blue, grow=0.004, name="StripeB")
        k.fore_arm(side, white)
        k.arm_band(side, "ForeArm", -0.04, 0.16, dark, grow=0.014, name="ElbowPad")
        k.arm_band(side, "ForeArm", 0.7, 0.93, white, grow=0.008, name="Gauntlet", taper=(0.006, -0.002))
        k.hand(side, red, plate_m=gold)
        k.thigh(side, white)
        k.leg_band(side, "Thigh", 0.3, 0.37, red, grow=0.004, name="StripeR")
        k.leg_band(side, "Thigh", 0.39, 0.45, blue, grow=0.004, name="StripeB")
        k.shin(side, white)
        k.leg_band(side, "Shin", -0.03, 0.17, dark, grow=0.014, name="KneePad")
        k.shoe(side, white, dark, toe_m=red, style="boot", shaft=0.2, shaft_m=white, heel_m=gold, collar_m=red)
    _both(limbs)
    return k, "rev_up", dict(bend=20, out=0.27, chin=-3.0, aim=BULKY_HOLD)


def op_halfpipe():
    """Neon Skyline skater: slouchy beanie, big over-ear headphones, an
    oversized hoodie with drawstrings, baggy shorts, knee pads, tall socks,
    high-tops and a skateboard strapped to the back."""
    k = Kit("HP_", "#6b4a32", dict(shoulder=0.98, waist=0.98, depth=1.02))
    hoodie = mat("Hoodie", "#7b3fc8", rough=0.8)
    hoodie_dark = mat("HoodieDark", "#5a2a9a", rough=0.8)
    lime = mat("Lime", "#b6ff3a", rough=0.6)
    char = mat("Charcoal", "#2b2836", rough=0.65)
    beanie = mat("Beanie", "#b6ff3a", rough=0.9)
    phones = mat("Phones", "#1c1830", rough=0.35)
    pink = mat("HotPink", "#ff3fa4", rough=0.4)
    sock = mat("Sock", "#f7f4f2", rough=0.7)
    deck = mat("Deck", "#ff3fa4", rough=0.5)
    grip = mat("GripTape", "#1c1830", rough=0.9)
    wheel = mat("Wheel", "#fff1a8", rough=0.4)
    truck = mat("Truck", "#d6dbe6", rough=0.25, metal=0.8)
    hair = mat("Hair", "#1a1220", rough=0.8)

    k.head(ears=False)
    k.face(iris="#4a2c1a", brow="#1a1220", mouth="smirk", lids=0.24, brow_tilt=4, blush=None)
    k.hair_cap(hair, _hairline(0.5, 0.25, -0.05, -0.35), grow=0.03)
    k.hair_cap(beanie, _hairline(0.36, 0.26, 0.16, 0.02), grow=0.075, name="Beanie", tag="headgear",
               volume=lambda d: 0.07 * max(0.0, d.y) * max(0.0, d.z + 0.2))
    k.head_band("BeanieRib", 0.075, 0.125, char, grow=0.085)
    c = HEAD_C + Vector((0, 0.01, -0.005))
    phone_parts = [torus(k.n("Headband"), 0.305, 0.02, c, rot=rad(90, 0, 0), m=phones, major_segs=32, minor_segs=8, arc=math.pi)]
    for side in (1, -1):
        cp = c + Vector((side * 0.29, 0, 0))
        phone_parts += [cyl(k.n(f"Cup{side}"), 0.085, 0.055, cp, rot=rad(0, 90, 0), segs=24, bevel=0.02, m=phones),
                        cyl(k.n(f"CupCap{side}"), 0.06, 0.02, cp + Vector((side * 0.03, 0, 0)), rot=rad(0, 90, 0), segs=20, bevel=0.008, m=pink),
                        cyl(k.n(f"Yoke{side}"), 0.018, 0.08, cp + Vector((side * 0.005, 0, 0.075)), segs=8, bevel=0.006, m=phones)]
    k.add(phone_parts, bone="Head", tag="headgear", occlude=False)
    k.neck()

    k.torso(hoodie_dark, lower_m=char, split_z=0.93)
    k.shell("Hoodie", 0.92, 1.36, hoodie, grow=0.014, thickness=0.014, flare=0.008)
    k.belt(0.935, 0.045, hoodie_dark, grow=0.005, name="Rib")
    front = k.on_torso("front")
    _detail(k, [decal(k.n("Pocket"), rrect(0, 0.99, 0.26, 0.11, 0.03), front, hoodie_dark, lift=0.005),
                decal(k.n("Bolt"), [(0.01, 1.27), (-0.045, 1.17), (-0.005, 1.17), (-0.03, 1.09), (0.045, 1.2), (0.005, 1.2), (0.03, 1.27)], front, lime,
                      lift=0.006, inset=0.15),
                strip(k.n("DrawL"), [(0.045, 1.34, 0.008), (0.05, 1.27, 0.008), (0.052, 1.22, 0.007)], front, sock, lift=0.008),
                strip(k.n("DrawR"), [(-0.045, 1.34, 0.008), (-0.05, 1.28, 0.008), (-0.048, 1.24, 0.007)], front, sock, lift=0.008)])
    k.add(blob(k.n("Hood"), 1.0, (0, _back_y(k, 1.33, 0.02), 1.335), hoodie, scale=(0.2, 0.085, 0.07)), bone="Chest", tag="gear")
    # Skateboard strapped flat across the back, nose up.
    by = _back_y(k, 1.12, 0.035)
    board_rot = rad(0, 14, 0)
    m_rot = Euler(board_rot, "XYZ").to_matrix()
    centre = Vector((0.0, by + 0.012, 1.1))
    board = [box(k.n("Deck"), (0.2, 0.014, 0.66), centre, rot=board_rot, bevel=0.007, m=deck),
             box(k.n("Grip"), (0.19, 0.004, 0.6), centre + m_rot @ Vector((0, -0.009, 0)), rot=board_rot, bevel=0.002, m=grip)]
    for i, dz in enumerate((-0.22, 0.22)):
        hub = centre + m_rot @ Vector((0, 0.03, dz))
        board.append(box(k.n(f"Truck{i}"), (0.15, 0.03, 0.035), hub, rot=board_rot, bevel=0.01, m=truck))
        for s in (1, -1):
            board.append(cyl(k.n(f"Wheel{i}{s}"), 0.028, 0.026, hub + m_rot @ Vector((s * 0.088, 0.012, 0)), rot=(board_rot[0], board_rot[1] + math.pi / 2, 0),
                             segs=12, bevel=0.008, m=wheel))
    k.add(board, bone="Chest", tag="gear")
    k.strap("BoardStrap", [(0.2, 0.25, 1.32), (0.18, 0.0, 1.4), (0.13, -0.27, 1.28), (0.0, -0.31, 1.15), (-0.16, -0.27, 1.03), (-0.24, 0.0, 1.0),
                           (-0.2, 0.25, 1.02)], 0.035, lime)

    def limbs(side, s):
        k.upper_arm(side, hoodie, r0=0.088, r1=0.074)
        k.fore_arm(side, hoodie)
        k.arm_band(side, "ForeArm", 0.72, 0.93, hoodie_dark, grow=0.008, name="Cuff")
        k.hand(side, char, plate_m=lime)
        k.thigh(side, k.skin_m)
        k.shorts_leg(side, char, length=0.7, hem_m=lime, flare=0.016)
        k.shin(side, k.skin_m)
        k.leg_band(side, "Shin", -0.04, 0.16, char, grow=0.016, name="KneePad")
        k.leg_band(side, "Shin", 0.5, 0.92, sock, grow=0.006, name="Sock")
        k.leg_band(side, "Shin", 0.56, 0.6, pink, grow=0.008, name="SockStripe")
        k.shoe(side, char, sock, toe_m=sock, lace_m=lime, collar_m=char, shaft=0.07, shaft_m=char, stripe_m=pink, tongue_m=char)
    _both(limbs)
    return k, "head_bob", dict(bend=24, out=0.28, lean=1.5, chin=4.0, sway=1.2, aim=BULKY_HOLD)


def op_top_dog():
    """Hot-dog stand hero: paper soda-jerk cap with a frank pin, red-and-white
    striped shirt, bow tie, an apron with a mustard splat and a holster belt
    with ketchup and mustard bottles."""
    k = Kit("TD_", "#e8b08a", dict(belly=0.55, waist=1.1, chest=1.02))
    white = mat("White", "#f7f4f2", rough=0.55)
    red = mat("Ketchup", "#e8263a", rough=0.45)
    mustard = mat("Mustard", "#ffc72a", rough=0.45)
    apron = mat("Apron", "#fffaf0", rough=0.7)
    pants = mat("Trousers", "#2b2f5c", rough=0.6)
    leather = mat("Leather", "#7a4a2c", rough=0.55)
    frank = mat("Frank", "#c8502a", rough=0.5)
    bun = mat("Bun", "#f2b45a", rough=0.7)
    shoe_m = mat("Sneaker", "#f7f4f2", rough=0.45)
    hair = mat("Hair", "#7a3a1c", rough=0.75)

    k.head()
    k.face(iris="#3a6f2a", brow="#7a3a1c", mouth="grin", lids=0.1, brow_tilt=-8, freckles=True)
    k.hair_cap(hair, _hairline(0.55, 0.22, -0.12, -0.42), grow=0.035)
    k.neck()
    # Paper garrison cap: a long boat shape riding on top, with a red band and a frank pin.
    f = _hat_frame(0.175, -4.0, roll=-6.0)
    cap = [loft(k.n("Cap"), [(0.0, 0.2, 0.25, 0, 0, 2.6), (0.05, 0.19, 0.255, 0, 0, 2.8), (0.12, 0.07, 0.25, 0, 0, 3.2), (0.15, 0.014, 0.225, 0, 0, 3.2)],
                m=white, segs=28, sub=2, frame=f, caps=("flat", "flat"), sharp=60),
           loft(k.n("CapBand"), [(0.01, 0.203, 0.254, 0, 0, 2.6), (0.045, 0.194, 0.259, 0, 0, 2.8)], m=red, segs=28, sub=1, frame=f, caps=("flat", "flat"),
                sharp=70)]
    pin = f @ Vector((0.17, -0.08, 0.06))
    cap += [limb(k.n("Frank"), pin + Vector((0.0, -0.04, 0.0)), pin + Vector((0.0, 0.04, 0.004)), 0.014, 0.014, frank, segs=10),
            blob(k.n("Bun"), 1.0, pin + Vector((0.006, 0, -0.008)), bun, scale=(0.016, 0.045, 0.014))]
    k.add(cap, bone="Head", tag="headgear")

    k.torso(red, lower_m=pants, split_z=0.93)
    for i, z in enumerate((1.02, 1.1, 1.18, 1.26)):
        k.belt(z, 0.034, white, grow=0.002, name=f"Stripe{i}")
    front = k.on_torso("front")
    _detail(k, [decal(k.n("Apron"), rrect(0, 1.02, 0.3, 0.3, 0.04), front, apron, lift=0.01),
                decal(k.n("ApronBib"), rrect(0, 1.2, 0.18, 0.13, 0.03), front, apron, lift=0.01),
                decal(k.n("Splat"), star_at(0.06, 0.98, 0.05, 0.03, 9, 20.0), front, mustard, lift=0.015, sink=0.0, dome=0.002),
                decal(k.n("Pocket"), rrect(0, 1.21, 0.08, 0.05, 0.012), front, red, lift=0.015, sink=0.0),
                decal(k.n("TieL"), [(0.0, 1.335), (0.075, 1.365), (0.075, 1.305)], front, red, lift=0.014, inset=0.25),
                decal(k.n("TieR"), [(0.0, 1.335), (-0.075, 1.305), (-0.075, 1.365)], front, red, lift=0.014, inset=0.25),
                decal(k.n("TieKnot"), ellipse_outline(0, 1.335, 0.018, 0.022, 8), front, red, lift=0.02, sink=0.0, dome=0.004)])
    for side in (1, -1):
        _detail(k, strip(k.n(f"ApronStrap{side}"), [(side * 0.085, 1.26, 0.012), (side * 0.11, 1.31, 0.012), (side * 0.12, 1.36, 0.01)], front, apron, lift=0.012))
    k.belt(0.945, 0.05, leather, grow=0.008, name="Holster")
    for side, m, name in ((1, mustard, "Mustard"), (-1, red, "Ketchup")):
        p = k.torso_point(0.96, 270 + side * 118, 0.045)
        k.add([cyl(k.n(name), 0.034, 0.12, p, segs=14, bevel=0.012, m=m),
               cyl(k.n(name + "Cap"), 0.022, 0.035, p + Vector((0, 0, 0.075)), segs=10, bevel=0.006, m=white),
               cyl(k.n(name + "Nozzle"), 0.012, 0.04, p + Vector((0, 0, 0.11)), segs=8, bevel=0.0, m=m, radius_top=0.004),
               box(k.n(name + "Loop"), (0.08, 0.08, 0.03), p + Vector((0, 0, -0.005)), rot=rad(0, 0, side * 118), bevel=0.01, m=leather)],
              bone="Hips", tag="gear")

    def limbs(side, s):
        k.upper_arm(side, k.skin_m)
        k.sleeve(side, red, length=0.5, hem_m=white)
        k.arm_band(side, "UpperArm", 0.18, 0.26, white, grow=0.013, name="SleeveStripe")
        k.fore_arm(side, k.skin_m)
        k.hand(side, white)
        k.thigh(side, pants)
        k.shin(side, pants)
        k.leg_band(side, "Shin", 0.8, 0.95, pants, grow=0.012, name="Cuff")
        k.shoe(side, shoe_m, red, toe_m=shoe_m, lace_m=red, stripe_m=mustard, tongue_m=shoe_m)
    _both(limbs)
    return k, "chef_kiss", dict(bend=22, out=0.3)


def op_tide_keeper():
    """Aquarium keeper: yellow sou'wester, a striped jumper, green bib waders
    with yellow braces, a fish-tank backpack with a fish in it."""
    k = Kit("TK_", "#c98a5e", dict(shoulder=1.02, belly=0.25, waist=1.04))
    yellow = mat("Slicker", "#ffd12a", rough=0.3)
    navy = mat("Jumper", "#1d2f5c", rough=0.8)
    stripe = mat("JumperStripe", "#f7f4f2", rough=0.8)
    wader = mat("Wader", "#2f8a4a", rough=0.4)
    wader_dark = mat("WaderDark", "#1f6a36", rough=0.4)
    teal = mat("TankFrame", "#14a3a0", rough=0.4)
    glass = mat("FxGlassTank", "#9fefff", rough=0.05)
    fish = mat("Fish", "#ff7a2a", rough=0.35)
    fin = mat("FishFin", "#fff1dc", rough=0.4)
    water = mat("TankWater", "#2fb8d0", rough=0.2, emit=0.6)
    hair = mat("Hair", "#c8652a", rough=0.75)
    dark = mat("Dark", "#1c1830", rough=0.4)

    k.head()
    k.face(iris="#2f8f9f", brow="#8a4a2a", mouth="smile", lids=0.12, brow_tilt=-6, freckles=True, blush="#e87a6a")
    k.hair_cap(hair, _hairline(0.55, 0.3, -0.05, -0.3), grow=0.035)
    k.neck(navy, r=0.075)
    f = _hat_frame(0.13, -3.0)
    hat = [loft(k.n("Crown"), [(0.0, 0.252, 0.238, 0, 0, 2.2), (0.08, 0.245, 0.232, 0, 0, 2.2), (0.15, 0.2, 0.19, 0, 0, 2.1), (0.185, 0.12, 0.115, 0, 0, 2.0)],
                yellow, segs=28, sub=3, frame=f, caps=("flat", "round"), cap_h=(None, 0.03)),
           loft(k.n("Brim"), [(-0.012, 0.345, 0.36, 0, 0.07, 2.0), (-0.005, 0.355, 0.37, 0, 0.07, 2.0), (0.005, 0.355, 0.37, 0, 0.07, 2.0),
                              (0.012, 0.345, 0.36, 0, 0.07, 2.0)], yellow, segs=32, sub=1, frame=f @ Matrix.Rotation(math.radians(-8), 4, "X"),
                caps=("flat", "flat"), sharp=70)]
    k.add(hat, bone="Head", tag="headgear")

    k.torso(navy, lower_m=wader, split_z=0.98)
    for i, z in enumerate((1.04, 1.12, 1.2, 1.28)):
        k.belt(z, 0.03, stripe, grow=0.002, name=f"Stripe{i}")
    front = k.on_torso("front")
    _detail(k, [decal(k.n("Bib"), rrect(0, 1.08, 0.26, 0.2, 0.03), front, wader, lift=0.009),
                decal(k.n("BibPocket"), rrect(0, 1.1, 0.12, 0.08, 0.016), front, wader_dark, lift=0.014, sink=0.0),
                decal(k.n("FishBadge"), ellipse_outline(0.0, 1.1, 0.035, 0.02, 12), front, fish, lift=0.018, sink=0.0, dome=0.002),
                decal(k.n("FishTail"), [(0.033, 1.1), (0.058, 1.12), (0.058, 1.08)], front, fish, lift=0.018, sink=0.0)])
    _straps(k, yellow, 0.04, 1.14, "Brace")
    for side in (1, -1):
        _detail(k, decal(k.n(f"Clip{side}"), rrect(side * 0.13, 1.16, 0.045, 0.035, 0.008), front, dark, lift=0.016, sink=0.0))
    k.belt(0.98, 0.04, wader_dark, grow=0.004, name="Waist")
    by = _back_y(k, 1.16, 0.09)
    tank = [box(k.n("TankBase"), (0.34, 0.17, 0.05), (0, by, 0.99), bevel=0.02, m=teal),
            box(k.n("TankLid"), (0.34, 0.17, 0.045), (0, by, 1.36), bevel=0.02, m=teal),
            blob(k.n("Fish"), 1.0, (0.02, by + 0.01, 1.18), fish, scale=(0.07, 0.035, 0.045)),
            box(k.n("FishTailFin"), (0.04, 0.012, 0.05), (-0.065, by + 0.01, 1.18), rot=rad(0, 0, 0), bevel=0.006, m=fin),
            box(k.n("Pebbles"), (0.3, 0.13, 0.03), (0, by, 1.025), bevel=0.012, m=wader_dark),
            blob(k.n("Bubble0"), 0.016, (0.08, by - 0.02, 1.27), water, segs=8, rings=6),
            blob(k.n("Bubble1"), 0.011, (0.1, by - 0.02, 1.31), water, segs=8, rings=6)]
    for i, (x, y) in enumerate(((1, 1), (1, -1), (-1, 1), (-1, -1))):
        tank.append(box(k.n(f"Post{i}"), (0.03, 0.03, 0.34), (x * 0.155, by + y * 0.07, 1.175), bevel=0.01, m=teal))
    k.add(tank, bone="Chest", tag="gear")
    k.add(box(k.n("TankGlass"), (0.3, 0.13, 0.32), (0, by, 1.175), bevel=0.02, m=glass), bone="Chest", tag="gear")

    def limbs(side, s):
        k.upper_arm(side, navy)
        k.arm_band(side, "UpperArm", 0.3, 0.37, stripe, grow=0.004, name="Stripe0")
        k.arm_band(side, "UpperArm", 0.55, 0.62, stripe, grow=0.004, name="Stripe1")
        k.fore_arm(side, navy)
        k.arm_band(side, "ForeArm", 0.44, 0.51, stripe, grow=0.004, name="Stripe")
        k.arm_band(side, "ForeArm", 0.7, 0.93, yellow, grow=0.007, name="Gauntlet")
        k.hand(side, yellow, plate_m=yellow)
        k.thigh(side, wader)
        k.shin(side, wader)
        k.leg_band(side, "Shin", -0.03, 0.12, wader_dark, grow=0.008, name="Knee")
        k.shoe(side, wader_dark, dark, toe_m=wader_dark, style="boot", shaft=0.2, shaft_m=wader_dark, collar_m=wader)
    _both(limbs)
    return k, "toss", dict(bend=20, out=0.28, look=0.8)


def op_mech_jockey():
    """Mech pilot: orange flight suit with patches, big armour on the left
    shoulder, a headset with a mic and a flip-up eyepiece, a chest harness
    and a power pack."""
    k = Kit("MJ_", "#8a5636", dict(shoulder=1.05, chest=1.04))
    orange = mat("FlightSuit", "#ff7a1a", rough=0.6)
    orange_dark = mat("FlightSuitDark", "#d85a10", rough=0.6)
    gun = mat("Gunmetal", "#3a3a4a", rough=0.35, metal=0.6)
    gun_hi = mat("GunmetalHi", "#6a6a80", rough=0.35, metal=0.6)
    strap_m = mat("Harness", "#1c1830", rough=0.5)
    glow = mat("Glow", "#35f0ff", rough=0.3, emit=2.6)
    glass = mat("FxGlassEyepiece", "#35f0ff", rough=0.05)
    patch_b = mat("PatchBlue", "#2f4fcf", rough=0.5)
    yellow = mat("Hazard", "#ffd93b", rough=0.45)
    hair = mat("Hair", "#1a1220", rough=0.8)
    boot = mat("Boot", "#2b2836", rough=0.5)

    k.head()
    k.face(iris="#3a2a1e", brow="#1a1220", mouth="flat", lids=0.22, brow_tilt=10, blush=None)
    k.hair_cap(hair, _hairline(0.62, 0.32, 0.05, -0.38), grow=0.03, volume=lambda d: 0.03 * max(0.0, d.z))
    k.neck(orange, r=0.075)
    k.head_band("Headset", 0.11, 0.155, gun, grow=0.04)
    hs = []
    for side in (1, -1):
        cp = HEAD_C + Vector((side * 0.262, 0.0, -0.005))
        hs += [cyl(k.n(f"EarCup{side}"), 0.07, 0.05, cp, rot=rad(0, 90, 0), segs=20, bevel=0.016, m=gun),
               cyl(k.n(f"EarRing{side}"), 0.05, 0.02, cp + Vector((side * 0.026, 0, 0)), rot=rad(0, 90, 0), segs=16, bevel=0.006, m=glow),
               cyl(k.n(f"Strut{side}"), 0.014, 0.12, cp + Vector((side * 0.006, 0.0, 0.1)), rot=rad(0, side * -14, 0), segs=8, bevel=0.004, m=gun_hi)]
    mic_root = HEAD_C + Vector((0.27, -0.03, -0.04))
    hs.append(tube(k.n("MicBoom"), [mic_root, mic_root + Vector((0.0, -0.12, -0.04)), Vector((0.08, HEAD_C.y - 0.27, HEAD_C.z - 0.1))], 0.009, m=gun_hi, segs=8))
    hs.append(blob(k.n("Mic"), 0.022, (0.075, HEAD_C.y - 0.275, HEAD_C.z - 0.1), strap_m, segs=10, rings=6))
    ep = HEAD_C + Vector((-0.11, -0.25, 0.115))
    hs += [tube(k.n("EyeArm"), [HEAD_C + Vector((-0.275, -0.02, 0.05)), HEAD_C + Vector((-0.25, -0.18, 0.11)), ep + Vector((-0.04, 0.0, 0.0))], 0.01, m=gun_hi,
                segs=8),
           box(k.n("EyeFrame"), (0.09, 0.03, 0.06), ep, rot=rad(-35, 0, 0), bevel=0.012, m=gun)]
    k.add(hs, bone="Head", tag="headgear", occlude=False)
    k.add(box(k.n("EyeLens"), (0.07, 0.012, 0.042), ep + Vector((0, -0.012, -0.008)), rot=rad(-35, 0, 0), bevel=0.006, m=glass), bone="Head",
          tag="headgear")
    k.add(box(k.n("Fin"), (0.012, 0.12, 0.05), HEAD_C + Vector((0.0, 0.05, 0.27)), rot=rad(-6, 0, 0), bevel=0.005, m=orange), bone="Head", tag="headgear")

    k.torso(orange)
    front, back = k.on_torso("front"), k.on_torso("back")
    _detail(k, [strip(k.n("Zip"), line_path((0.035, 0.98), (0.0, 1.34), 0.02, steps=10), front, orange_dark, lift=0.004),
                decal(k.n("PatchL"), ellipse_outline(0.14, 1.27, 0.035, 0.035, 14), front, patch_b, lift=0.006),
                decal(k.n("PatchStar"), star_at(0.14, 1.27, 0.024, 0.011), front, yellow, lift=0.01, sink=0.0),
                decal(k.n("PatchR"), rrect(-0.15, 1.25, 0.07, 0.04, 0.008), front, yellow, lift=0.006),
                strip(k.n("PatchRStripe"), line_path((-0.18, 1.25), (-0.12, 1.25), 0.012, steps=2), front, strap_m, lift=0.01, sink=0.0),
                decal(k.n("BackNumber"), rrect(0, 1.2, 0.17, 0.12, 0.02), back, strap_m, lift=0.005),
                strip(k.n("Seven"), [(-0.05, 1.235, 0.012), (0.04, 1.235, 0.012), (0.0, 1.16, 0.012)], back, yellow, lift=0.009, sink=0.0)])
    _straps(k, strap_m, 0.05, 1.0, "Harness")
    k.belt(1.17, 0.045, strap_m, grow=0.008, name="ChestStrap")
    _detail(k, decal(k.n("Buckle"), rrect(0, 1.17, 0.09, 0.07, 0.016), k.on_torso("front"), gun_hi, lift=0.016, sink=0.002))
    _detail(k, decal(k.n("BuckleGlow"), ellipse_outline(0, 1.17, 0.018, 0.018, 10), k.on_torso("front"), glow, lift=0.022, sink=0.0))
    k.belt(0.975, 0.06, strap_m)
    by = _back_y(k, 1.16, 0.075)
    k.add([box(k.n("Pack"), (0.32, 0.13, 0.3), (0, by, 1.16), bevel=0.04, segs=3, m=gun),
           box(k.n("PackPlate"), (0.26, 0.03, 0.22), (0, by + 0.065, 1.16), bevel=0.012, m=gun_hi),
           box(k.n("PackGlow"), (0.2, 0.01, 0.025), (0, by + 0.082, 1.2), bevel=0.004, m=glow),
           box(k.n("PackGlow2"), (0.2, 0.01, 0.025), (0, by + 0.082, 1.13), bevel=0.004, m=glow),
           box(k.n("Hazard"), (0.3, 0.02, 0.03), (0, by + 0.07, 1.03), bevel=0.006, m=yellow)], bone="Chest", tag="gear")
    # Left shoulder armour.
    sp = sx(1, SHOULDER) + Vector((0.04, 0.0, 0.0))
    k.add([open_shell(k.n("Pauldron"), 0.118, sp, 58.0, gun, scale=(0.95, 1.1, 0.8), thickness=0.016, toward=(0.15, 0, -1)),
           blob(k.n("PauldronStud"), 0.02, sp + Vector((0.06, -0.065, 0.045)), yellow, segs=10, rings=6),
           blob(k.n("PauldronStud2"), 0.02, sp + Vector((0.06, 0.065, 0.045)), yellow, segs=10, rings=6)],
          bone="UpperArm.L", tag="arm")

    def limbs(side, s):
        k.upper_arm(side, orange)
        k.fore_arm(side, orange)
        k.arm_band(side, "ForeArm", -0.04, 0.14, gun, grow=0.012, name="ElbowPad")
        k.arm_band(side, "ForeArm", 0.7, 0.93, gun, grow=0.008, name="Cuff")
        k.arm_band(side, "ForeArm", 0.76, 0.8, glow, grow=0.011, name="CuffGlow")
        k.hand(side, gun, plate_m=orange_dark)
        k.thigh(side, orange)
        k.add(box(k.n("Cargo" + s), (0.03, 0.11, 0.12), sx(side, HIP.lerp(KNEE, 0.45) + Vector((0.11, 0.0, 0))), rot=rad(0, side * -3, 0), bevel=0.014,
                  m=orange_dark), bone="Thigh." + s, tag="leg")
        k.shin(side, orange)
        k.leg_band(side, "Shin", -0.04, 0.16, gun, grow=0.014, name="KneePad")
        k.shoe(side, boot, strap_m, toe_m=gun_hi, style="boot", shaft=0.18, shaft_m=boot, lace_m=orange, collar_m=gun)
    _both(limbs)
    return k, "go_signal", dict(bend=20, out=0.3, chin=-2.0, aim=BULKY_HOLD)


def op_cosmic_sheriff():
    """Space cowboy: a ten-gallon hat with a ringed-planet band and an antenna,
    a vest with a star badge, a striped sash, a ray-gun holster, fringed chaps
    and boots with star spurs."""
    k = Kit("CS_", "#9a6a48", dict(shoulder=1.04, waist=0.98))
    hat_m = mat("Hat", "#d8a86a", rough=0.6)
    hat_dark = mat("HatDark", "#a8783a", rough=0.6)
    turq = mat("Turquoise", "#1fb5a8", rough=0.4)
    shirt = mat("Shirt", "#fff1dc", rough=0.6)
    vest = mat("Vest", "#b5532a", rough=0.55)
    rust = mat("Rust", "#8a3a1c", rough=0.55)
    gold = mat("Gold", "#ffc23d", rough=0.25, metal=0.85)
    silver = mat("Silver", "#d6dbe6", rough=0.25, metal=0.85)
    jeans = mat("Jeans", "#3a4f8a", rough=0.65)
    chaps = mat("Chaps", "#7a4424", rough=0.55)
    glove_m = mat("RidingGlove", "#c98a4a", rough=0.6)
    boot = mat("Boot", "#5a3424", rough=0.5)
    glow = mat("RayGlow", "#7cff4a", rough=0.3, emit=2.6)
    planet = mat("Planet", "#ff7ad9", rough=0.4)
    hair = mat("Hair", "#3d2318", rough=0.75)

    k.head()
    k.face(iris="#2f6f5f", brow="#3d2318", mouth="smirk", lids=0.22, brow_tilt=-4, blush=None)
    k.hair_cap(hair, _hairline(0.58, 0.18, -0.12, -0.42), grow=0.035)
    k.neck()
    f = _hat_frame(0.14, -6.0)
    brim_rows = [(-0.012, 0.39, 0.39, 0, 0, 2.1), (-0.004, 0.4, 0.4, 0, 0, 2.1), (0.004, 0.4, 0.4, 0, 0, 2.1), (0.012, 0.39, 0.39, 0, 0, 2.1)]
    hat = [loft(k.n("Brim"), brim_rows, hat_m, segs=36, sub=1, frame=f, caps=("flat", "flat"), sharp=70),
           loft(k.n("Crown"), [(0.0, 0.25, 0.236, 0, 0, 2.3), (0.1, 0.235, 0.225, 0, 0, 2.3), (0.2, 0.2, 0.205, 0, 0, 2.4), (0.25, 0.17, 0.19, 0, 0.0, 2.6)],
                hat_m, segs=28, sub=3, frame=f, caps=("flat", "round"), cap_h=(None, 0.02)),
           loft(k.n("HatBand"), [(0.014, 0.256, 0.242, 0, 0, 2.3), (0.02, 0.259, 0.245, 0, 0, 2.3), (0.06, 0.253, 0.24, 0, 0, 2.3), (0.066, 0.25, 0.237, 0, 0, 2.3)],
                turq, segs=28, sub=1, frame=f, caps=("flat", "flat"), sharp=70)]
    for side in (1, -1):    # the brim curls up at the sides
        hat.append(tube(k.n(f"Curl{side}"), [f @ Vector((side * 0.26, -0.29, 0.02)), f @ Vector((side * 0.38, -0.1, 0.06)), f @ Vector((side * 0.39, 0.1, 0.06)),
                                             f @ Vector((side * 0.26, 0.29, 0.02))], 0.02, m=hat_dark, segs=10))
    pp = f @ Vector((0.0, -0.255, 0.04))
    hat += [blob(k.n("Planet"), 0.034, pp, planet, segs=12, rings=8),
            torus(k.n("PlanetRing"), 0.055, 0.008, pp, rot=rad(70, 20, 0), m=gold, major_segs=20, minor_segs=6),
            cyl(k.n("Antenna"), 0.007, 0.14, f @ Vector((0.17, 0.05, 0.27)), rot=rad(0, 24, 0), segs=6, bevel=0.0, m=silver)]
    k.add(hat, bone="Head", tag="headgear")
    k.add(blob(k.n("AntennaTip"), 0.022, f @ Vector((0.2, 0.05, 0.34)), glow, segs=8, rings=6), bone="Head", tag="headgear")

    k.torso(shirt, lower_m=jeans, split_z=0.96)
    k.shell("Vest", 0.98, 1.355, vest, grow=0.014, thickness=0.014, gap=(16.0, 34.0))
    front = k.on_torso("front")
    _detail(k, [decal(k.n("Badge"), star_at(0.15, 1.24, 0.042, 0.02), front, gold, lift=0.008, dome=0.004),
                decal(k.n("BadgeGem"), ellipse_outline(0.15, 1.24, 0.01, 0.01, 8), front, turq, lift=0.014, sink=0.0)]
            + [decal(k.n(f"Stitch{i}"), rrect(-0.155, 1.06 + i * 0.05, 0.012, 0.025, 0.004), front, turq, lift=0.007) for i in range(5)])
    k.strap("Sash", [(0.22, 0.2, 1.36), (0.18, -0.05, 1.4), (0.08, -0.28, 1.27), (-0.06, -0.3, 1.1), (-0.2, -0.22, 0.99), (-0.24, 0.05, 0.98),
                     (-0.1, 0.27, 1.1), (0.15, 0.25, 1.3)], 0.06, turq, thick=0.006, lift=0.012)
    k.strap("SashStripe", [(0.22, 0.2, 1.36), (0.18, -0.05, 1.4), (0.08, -0.28, 1.27), (-0.06, -0.3, 1.1), (-0.2, -0.22, 0.99), (-0.24, 0.05, 0.98),
                           (-0.1, 0.27, 1.1), (0.15, 0.25, 1.3)], 0.018, gold, thick=0.004, lift=0.02)
    k.add(torus(k.n("Bandana"), 0.112, 0.03, (0, 0.0, 1.375), m=rust, major_segs=22, minor_segs=8), bone="Chest", tag="scarf")
    _detail(k, decal(k.n("BandanaTip"), [(0.0, 1.26), (0.07, 1.345), (-0.07, 1.345)], k.on_torso("front"), rust, lift=0.022, inset=0.2))
    k.belt(0.97, 0.055, rust)
    _detail(k, [decal(k.n("Buckle"), ellipse_outline(0, 0.97, 0.06, 0.045, 16), k.on_torso("front"), silver, lift=0.012, dome=0.004),
                decal(k.n("BucklePlanet"), ellipse_outline(0, 0.97, 0.022, 0.022, 10), k.on_torso("front"), planet, lift=0.019, sink=0.0, dome=0.002)])
    p = k.torso_point(0.92, 196, 0.03)
    k.add([box(k.n("Holster"), (0.045, 0.1, 0.15), p, rot=rad(0, 0, 16), bevel=0.016, m=rust),
           box(k.n("RayGrip"), (0.035, 0.045, 0.07), p + Vector((0.0, 0.03, 0.095)), rot=rad(-20, 0, 16), bevel=0.012, m=silver),
           cyl(k.n("RayBulb"), 0.022, 0.02, p + Vector((0.0, -0.012, 0.085)), rot=rad(90, 0, 16), segs=12, bevel=0.006, m=glow)],
          bone="Hips", tag="gear")

    def limbs(side, s):
        k.upper_arm(side, shirt)
        k.fore_arm(side, shirt)
        k.arm_band(side, "ForeArm", 0.7, 0.93, chaps, grow=0.008, name="Gauntlet", taper=(0.006, -0.002))
        k.hand(side, glove_m, plate_m=silver)
        k.thigh(side, jeans)
        k.leg_band(side, "Thigh", 0.12, 0.98, chaps, grow=0.012, name="Chaps")
        for i in range(5):
            k.add(box(k.n(f"Fringe{i}{s}"), (0.012, 0.03, 0.045), sx(side, HIP.lerp(KNEE, 0.2 + i * 0.16) + Vector((0.112, 0.0, 0))), bevel=0.005, m=chaps),
                  bone="Thigh." + s, tag="leg")
        k.shin(side, jeans)
        k.shoe(side, boot, rust, toe_m=silver, style="boot", shaft=0.24, shaft_m=boot, heel_m=rust, collar_m=turq)
        k.add([cyl(k.n("SpurPin" + s), 0.006, 0.05, (ANKLE.x * side, 0.13, 0.065), rot=rad(90, 0, 0), segs=6, bevel=0.0, m=silver),
               cyl(k.n("Spur" + s), 0.026, 0.008, (ANKLE.x * side, 0.16, 0.065), rot=rad(0, 90, 0), segs=10, bevel=0.002, m=gold)], bone="Foot." + s, tag="foot")
    _both(limbs)
    return k, "quick_draw", dict(bend=22, out=0.29, lean=-1.0, chin=-2.0, aim=BULKY_HOLD)


def op_timber_jack():
    """Lumberjack: trapper hat with fur ear flaps, a big beard, buffalo-check
    flannel under a quilted puffer vest, rolled jeans, work boots and an axe
    across the back."""
    k = Kit("TJ_", "#e8b08a", dict(shoulder=1.04, chest=1.0, waist=1.04, belly=0.2, arm=1.06, leg=1.04))
    check = mat("Flannel", "#d0262e", rough=0.8)
    check_dark = mat("FlannelDark", "#1c1418", rough=0.8)
    puffer = mat("Puffer", "#2f6a3a", rough=0.5)
    puffer_dark = mat("PufferDark", "#1f4a28", rough=0.5)
    fur = mat("Fur", "#e9d7b0", rough=0.95)
    beard = mat("Beard", "#8a4a22", rough=0.85)
    jeans = mat("Jeans", "#3a4f8a", rough=0.65)
    jeans_hi = mat("JeansCuff", "#6a84c0", rough=0.65)
    boot = mat("WorkBoot", "#9a6232", rough=0.55)
    sole = mat("Sole", "#2b2836", rough=0.7)
    glove = mat("WorkGlove", "#e0b066", rough=0.7)
    wood = mat("AxeHandle", "#c8884a", rough=0.6)
    steel = mat("AxeHead", "#d6dbe6", rough=0.25, metal=0.85)

    k.head(ears=False)
    k.face(iris="#3a6f2a", brow="#6a3418", mouth="none", lids=0.12, brow_tilt=-8, blush="#f08a7a", brow_w=0.11)
    face = k.on_face()
    mz = HEAD_C.z - 0.07
    for side in (1, -1):
        k.add(strip(k.n(f"Stache{side}"), [(side * 0.004, mz, 0.018), (side * 0.045, mz - 0.006, 0.022), (side * 0.085, mz - 0.02, 0.016),
                                           (side * 0.1, mz - 0.04, 0.008)], face, beard, lift=0.016), bone="Head", tag="face")
    k.add([blob(k.n("Beard"), 1.0, HEAD_C + Vector((0, -0.165, -0.145)), beard, scale=(0.19, 0.085, 0.095)),
           blob(k.n("BeardTip"), 1.0, HEAD_C + Vector((0, -0.2, -0.19)), beard, scale=(0.11, 0.055, 0.06))]
          + [blob(k.n(f"Burn{s}"), 1.0, HEAD_C + Vector((s * 0.16, -0.085, -0.07)), beard, scale=(0.055, 0.085, 0.11)) for s in (1, -1)],
          bone="Head", tag="face")
    k.neck()
    hat_parts = k.hair_cap(check, _hairline(0.42, 0.34, 0.2, 0.0), grow=0.08, name="Trapper", tag="headgear")
    k.head_band("TrapperFur", 0.12, 0.2, fur, grow=0.11)
    top = Surface(hat_parts).projector("top")
    hy = HEAD_C.y
    k.add([strip(k.n(f"HatCheckX{i}"), line_path((-0.24, hy + y), (0.24, hy + y), 0.035, steps=8), top, check_dark, lift=0.003) for i, y in
           enumerate((-0.12, 0.0, 0.12))]
          + [strip(k.n(f"HatCheckY{i}"), line_path((x, hy - 0.24), (x, hy + 0.24), 0.035, steps=8), top, check_dark, lift=0.004) for i, x in
             enumerate((-0.12, 0.0, 0.12))], bone="Head", tag="headgear")
    for side in (1, -1):
        k.add(blob(k.n(f"Flap{side}"), 1.0, HEAD_C + Vector((side * 0.258, 0.03, -0.02)), check, scale=(0.045, 0.1, 0.12)), bone="Head", tag="headgear")

    k.torso(check, lower_m=jeans, split_z=0.95)
    for i, z in enumerate((1.02, 1.12, 1.22, 1.31)):
        k.belt(z, 0.035, check_dark, grow=0.001, name=f"CheckH{i}")
    front, back = k.on_torso("front"), k.on_torso("back")
    _detail(k, [strip(k.n(f"CheckF{i}"), line_path((x, 0.98), (x, 1.34), 0.035, steps=9), front, check_dark, lift=0.003) for i, x in
                enumerate((-0.17, -0.06, 0.06, 0.17))]
            + [strip(k.n(f"CheckB{i}"), line_path((x, 0.98), (x, 1.34), 0.035, steps=9), back, check_dark, lift=0.003) for i, x in
               enumerate((-0.17, -0.06, 0.06, 0.17))])
    k.shell("Vest", 0.97, 1.355, puffer, grow=0.012, thickness=0.016, gap=(18.0, 32.0))
    for i, z in enumerate((1.06, 1.16, 1.26)):
        k.belt(z, 0.016, puffer_dark, grow=-0.006, name=f"Quilt{i}")
    k.belt(0.965, 0.05, mat("Belt", "#5a3424", rough=0.55), name="Belt")
    by = _back_y(k, 1.16, 0.03)
    a, b = Vector((0.2, by + 0.03, 0.9)), Vector((-0.2, by + 0.03, 1.45))
    axe_dir = (b - a).normalized()
    head_c = b - axe_dir * 0.06
    k.add([limb(k.n("Handle"), a, b, 0.02, 0.018, wood, segs=10),
           box(k.n("AxeBlade"), (0.2, 0.025, 0.1), head_c + Vector((-0.08, 0.0, -0.055)), rot=rad(0, -54, 0), bevel=0.012, m=steel),
           box(k.n("AxePoll"), (0.06, 0.04, 0.07), head_c + Vector((0.025, 0.0, 0.012)), rot=rad(0, -54, 0), bevel=0.012, m=mat("AxeRed", "#e8263a", rough=0.4))],
          bone="Chest", tag="gear")
    k.strap("AxeStrap", [(0.19, 0.27, 1.32), (0.17, 0.0, 1.41), (0.1, -0.28, 1.3), (0.0, -0.31, 1.18)], 0.03, mat("StrapLeather", "#5a3424", rough=0.55))

    def limbs(side, s):
        k.upper_arm(side, check)
        k.arm_band(side, "UpperArm", 0.28, 0.36, check_dark, grow=0.003, name="Check0")
        k.arm_band(side, "UpperArm", 0.5, 0.58, check_dark, grow=0.003, name="Check1")
        k.fore_arm(side, k.skin_m)
        k.arm_band(side, "ForeArm", -0.04, 0.16, check, grow=0.016, name="Rolled")
        k.arm_band(side, "ForeArm", 0.04, 0.09, check_dark, grow=0.02, name="RolledStripe")
        k.arm_band(side, "ForeArm", 0.7, 0.93, glove, grow=0.007, name="GloveCuff")
        k.hand(side, glove, plate_m=boot)
        k.thigh(side, jeans)
        k.shin(side, jeans)
        k.leg_band(side, "Shin", 0.62, 0.8, jeans_hi, grow=0.016, name="Roll")
        k.shoe(side, boot, sole, toe_m=boot, style="boot", lace_m=check, collar_m=check, shaft=0.12, shaft_m=boot)
    _both(limbs)
    return k, "chop", dict(bend=18, out=0.31, aim=BULKY_HOLD, look=0.8, sway=0.8)


OPERATORS_MORE = {
    "pixel_pal": op_pixel_pal,
    "windup": op_windup,
    "stunt_ace": op_stunt_ace,
    "halfpipe": op_halfpipe,
    "top_dog": op_top_dog,
    "tide_keeper": op_tide_keeper,
    "mech_jockey": op_mech_jockey,
    "cosmic_sheriff": op_cosmic_sheriff,
    "timber_jack": op_timber_jack,
}
