"""Operators: the playable characters (the "avatar" cosmetic slot) shown on the
title screen, in the Locker, on the player card and in third-person shots.

Every operator is built from the shared kit in operator_kit.py (a rounded
"designer vinyl toy" figure, about 1.9 m tall, facing -Y in Blender / +Z in
Godot, standing on the origin) and exported as art/models/operator_<id>.glb
with the clips from operator_anim.py:

    Idle-loop, Pose, Run-loop, AimIdle-loop, Fire, Victory, Wave

and two sockets:

    WeaponSocket   child of the right hand. A weapon model (origin at the top
                   of its grip, -Z forward, +Y up in Godot) parented here with
                   an identity transform sits in both hands in AimIdle / Fire.
    HeadSocket     child of the head, at its centre (+Z = where the face looks).

Material contract (see scripts/cosmetics/operators.gd):
    OpBody     every flat colour, baked into vertex colours with ambient
               occlusion (UV.x = roughness, UV.y = metallic)
    FxHolo*    hologram shader          FxGold*   sparkling gold shader
    FxGlass*   clear glass shader       others    glowing accents, kept as they are

    python art/blender/build_operators.py [operator_id ...] [--audit]

--audit runs the intersection check (operator_audit.py) on every clip; set
WLA_AUDIT_WEAPONS="ion_carbine,scatter_blaster" to include held weapons.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from operator_kit import *  # noqa: F401,F403
from operator_kit import HEAD_C, SHOULDER, ELBOW, WRIST, HIP, KNEE, Kit, sx
from operator_anim import Rig, build_clips, bake_clips, curve


# ---------------------------------------------------------------------------
# Shared costume pieces
# ---------------------------------------------------------------------------

def hairline(front=0.55, temple=0.2, side=-0.1, back=-0.42):
    """Hairline height by azimuth (0 = front, pi = back)."""
    def fn(az):
        return curve(abs(az), [(0.0, front), (0.75, front), (1.15, temple), (1.6, side), (2.3, back), (math.pi, back)])
    return fn


def step(a, b, v):
    k = min(max((v - a) / (b - a), 0.0), 1.0)
    return k * k * (3 - 2 * k)


def hat_frame(z=0.15, tilt=-6.0, roll=0.0, y=0.0):
    """Frame of a hat sitting on the head: origin on the hat line, +Z up the crown."""
    return (Matrix.Translation(HEAD_C) @ Euler((math.radians(tilt), math.radians(roll), 0.0), "XYZ").to_matrix().to_4x4()
            @ Matrix.Translation((0.0, y, z)))


def disc_sections(radius, half, ratio=0.94, n=2.0):
    """A thin rounded-edge disc (hat brims, plates)."""
    return [(-half, radius * 0.985, radius * 0.985 * ratio, 0, 0, n), (-half * 0.4, radius, radius * ratio, 0, 0, n),
            (half * 0.4, radius, radius * ratio, 0, 0, n), (half, radius * 0.985, radius * 0.985 * ratio, 0, 0, n)]


def both(fn):
    for side in (1, -1):
        fn(side, "L" if side > 0 else "R")


def pocket(k, name, cx, cz, w, h, m, flap_m, button_m=None, where="front"):
    proj = k.on_torso(where)
    parts = [decal(k.n(name), rrect(cx, cz, w, h, 0.012), proj, m, lift=0.005),
             decal(k.n(name + "Flap"), rrect(cx, cz + h * 0.36, w * 1.08, h * 0.36, 0.01), proj, flap_m, lift=0.009, sink=0.0)]
    if button_m:
        parts.append(decal(k.n(name + "Btn"), ellipse_outline(cx, cz + h * 0.3, 0.008, 0.008, 8), proj, button_m, lift=0.0125, sink=0.0, dome=0.002))
    return k.add(parts, field=True, tag="detail")


def detail(k, parts):
    """Details worn on the torso (skinned with it)."""
    return k.add(parts, field=True, tag="detail")


def back_y(k, z, out=0.0):
    return k.torso_point(z, 90, out).y


def shoulder_straps(k, m, width=0.045, z_low=1.08, name="Strap"):
    for side in (1, -1):
        pts = [(side * 0.13, -0.3, z_low), (side * 0.14, -0.3, 1.22), (side * 0.15, -0.2, 1.345), (side * 0.15, 0.0, 1.38),
               (side * 0.15, 0.2, 1.345), (side * 0.14, 0.3, 1.22)]
        k.strap(f"{name}{side}", pts, width, m)


# ---------------------------------------------------------------------------
# Operators
# ---------------------------------------------------------------------------

def op_boardwalk_ranger():
    """Pier ranger: teal shirt with a badge, khaki shorts, campaign hat, hiking
    boots. Dark gloves, pink cuffs and dark sleeves match the default first-person arms."""
    k = Kit("BR_", "#e8b08a")
    shirt = mat("Shirt", "#17a39a", rough=0.6)
    shirt_dark = mat("ShirtDark", "#0e7a73", rough=0.6)
    khaki = mat("Khaki", "#d8b77a", rough=0.7)
    khaki_dark = mat("KhakiDark", "#b08f55", rough=0.7)
    pink = mat("Pink", "#ff3f9f", rough=0.5)
    leather = mat("Leather", "#7a4a2c", rough=0.55)
    leather_dark = mat("LeatherDark", "#553220", rough=0.6)
    gold = mat("Badge", "#ffc94a", rough=0.3, metal=0.7)
    sock = mat("Sock", "#f7f4f2", rough=0.7)
    hair = mat("Hair", "#5a3424", rough=0.75)
    glove = mat("Glove", "#2b2836", rough=0.7)
    plate = mat("GlovePlate", "#4a4560", rough=0.45, metal=0.3)
    under = mat("Undershirt", "#1d1b26", rough=0.8)
    radio = mat("Radio", "#26232f", rough=0.5)
    sole = mat("Sole", "#e9d7b0", rough=0.8)

    k.head()
    k.face(iris="#2f8f9f", brow="#4a2a1c", mouth="smile", lids=0.14, brow_tilt=-3)
    k.hair_cap(hair, hairline(0.62, 0.05, -0.22, -0.45), grow=0.035)
    k.neck()
    # Campaign hat: wide brim, tall crown, pink band, gold badge.
    f = hat_frame(0.135, -7.0)
    hat = [loft(k.n("Brim"), disc_sections(0.43, 0.013), khaki, segs=32, sub=1, frame=f, caps=("flat", "flat"), sharp=70),
           loft(k.n("Crown"), [(0.0, 0.243, 0.229, 0, 0, 2.2), (0.07, 0.238, 0.224, 0, 0, 2.2), (0.15, 0.205, 0.19, 0, 0, 2.1),
                               (0.19, 0.16, 0.146, 0, 0, 2.0)], khaki, segs=28, sub=3, frame=f, caps=("flat", "round"), cap_h=(None, 0.035)),
           loft(k.n("HatBand"), [(0.014, 0.249, 0.235, 0, 0, 2.2), (0.022, 0.253, 0.239, 0, 0, 2.2), (0.058, 0.25, 0.236, 0, 0, 2.2),
                                 (0.066, 0.246, 0.232, 0, 0, 2.2)], pink, segs=28, sub=1, frame=f, caps=("flat", "flat"), sharp=70)]
    k.add(hat, bone="Head", tag="headgear")
    crown = Surface(hat[1:2]).projector("front")
    k.add(decal(k.n("HatBadge"), star_at(0.0, HEAD_C.z + 0.2, 0.034, 0.016), crown, gold, lift=0.01, sink=0.004), bone="Head", tag="headgear")

    k.torso(shirt, lower_m=khaki)
    front = k.on_torso("front")
    detail(k, strip(k.n("Placket"), line_path((0, 1.0), (0, 1.33), 0.05, steps=10), front, shirt_dark, lift=0.004))
    for i in range(4):
        detail(k, decal(k.n(f"Button{i}"), ellipse_outline(0, 1.06 + i * 0.075, 0.009, 0.009, 8), front, gold, lift=0.009, sink=0.0, dome=0.002))
    pocket(k, "PocketL", 0.12, 1.215, 0.105, 0.1, shirt, shirt_dark, gold)
    pocket(k, "PocketR", -0.12, 1.215, 0.105, 0.1, shirt, shirt_dark, gold)
    detail(k, decal(k.n("Star"), star_at(0.12, 1.2, 0.034, 0.016), front, gold, lift=0.014, sink=0.0, dome=0.003))
    for side in (1, -1):    # collar points
        detail(k, strip(k.n(f"Collar{side}"), [(side * 0.035, 1.3, 0.022), (side * 0.075, 1.335, 0.03), (side * 0.12, 1.36, 0.026),
                                               (side * 0.15, 1.366, 0.014)], front, shirt_dark, lift=0.012))
    k.belt(0.985, 0.055, leather)
    belt = k.on_torso("front")
    detail(k, [decal(k.n("Buckle"), rrect(0, 0.985, 0.075, 0.06, 0.012), belt, gold, lift=0.011, sink=0.002),
               decal(k.n("BuckleIn"), rrect(0, 0.985, 0.04, 0.03, 0.006), belt, leather_dark, lift=0.0135, sink=0.0)])
    # Pouch on the right hip, radio on the back of the belt, whistle on a lanyard.
    p = k.torso_point(0.975, 197, 0.02)
    k.add(box(k.n("Pouch"), (0.05, 0.095, 0.1), p, rot=rad(0, 0, 17), bevel=0.018, m=leather_dark), bone="Hips", tag="gear")
    p = k.torso_point(1.0, 68, 0.022)
    k.add([box(k.n("Radio"), (0.085, 0.05, 0.13), p, rot=rad(0, 0, -22), bevel=0.015, m=radio),
           cyl(k.n("Antenna"), 0.007, 0.11, p + Vector((0.02, 0.008, 0.115)), segs=6, bevel=0.0, m=radio),
           box(k.n("RadioLight"), (0.02, 0.012, 0.012), p + Vector((0.01, 0.027, 0.04)), rot=rad(0, 0, -22), bevel=0.004,
               m=mat("RadioGlow", "#ff3f9f", rough=0.3, emit=2.4))], bone="Hips", tag="gear")
    lanyard = [(0.085, -0.02, 1.37), (0.075, -0.12, 1.3), (0.03, -0.16, 1.2), (0.0, -0.17, 1.15), (-0.03, -0.16, 1.2), (-0.075, -0.12, 1.3),
               (-0.085, -0.02, 1.37)]
    k.strap("Lanyard", lanyard, 0.012, pink, thick=0.004, lift=0.012)
    wp, wn = front(0.0, 1.135)
    k.add(cyl(k.n("Whistle"), 0.02, 0.055, wp + wn * 0.03, rot=rad(0, 90, 0), segs=12, bevel=0.007, m=gold), bone="Chest", tag="gear")

    def limbs(side, s):
        k.upper_arm(side, under)
        k.sleeve(side, shirt, length=0.55, hem_m=shirt_dark)
        k.fore_arm(side, under)
        k.arm_band(side, "ForeArm", 0.7, 0.93, pink, grow=0.01, name="Cuff")
        k.hand(side, glove, plate_m=plate)
        k.thigh(side, k.skin_m)
        k.shorts_leg(side, khaki, length=0.66, hem_m=khaki_dark)
        k.add(box(k.n("Cargo" + s), (0.03, 0.105, 0.11), sx(side, HIP.lerp(KNEE, 0.36) + Vector((0.112, 0.0, 0))), rot=rad(0, side * -3, 0),
                  bevel=0.012, m=khaki_dark), bone="Thigh." + s, tag="leg")
        k.shin(side, k.skin_m)
        k.leg_band(side, "Shin", 0.6, 0.88, sock, grow=0.006, name="Sock")
        k.shoe(side, leather, sole, toe_m=leather_dark, lace_m=sole, style="boot", collar_m=leather_dark, tongue_m=leather_dark)
    both(limbs)
    return k, "tip_hat", dict(bend=18)


def op_surf_rescue():
    """Lifeguard: red rash vest, board shorts, visor over sun-bleached spikes,
    zinc on the nose, rescue tube slung across the back."""
    k = Kit("SR_", "#b9774d", dict(shoulder=1.05, chest=1.03, waist=0.94))
    red = mat("Rash", "#e8263a", rough=0.55)
    red_dark = mat("RashDark", "#b0182a", rough=0.55)
    white = mat("White", "#f7f4f2", rough=0.55)
    shorts = mat("Boardies", "#ffd93b", rough=0.6)
    shorts_hi = mat("BoardiesStripe", "#ff8a2a", rough=0.6)
    teal = mat("VisorBrim", "#14a3a0", rough=0.45)
    tube_m = mat("RescueTube", "#ff4d3a", rough=0.45)
    hair = mat("Hair", "#ffd27a", rough=0.7)
    dark = mat("Strap", "#1c1830", rough=0.5)

    k.head()
    k.face(iris="#1f6f8a", brow="#b98a3a", mouth="grin", lids=0.08, brow_tilt=-7, blush="#e0705a")
    face = k.on_face()
    k.add([strip(k.n("Zinc"), line_path((-0.05, HEAD_C.z - 0.012), (0.05, HEAD_C.z - 0.012), 0.024, steps=6, taper=0.6), face, white, lift=0.005),
           strip(k.n("ZincL"), line_path((0.125, HEAD_C.z - 0.03), (0.175, HEAD_C.z - 0.022), 0.014, steps=3, taper=0.6), face, white, lift=0.006),
           strip(k.n("ZincR"), line_path((-0.125, HEAD_C.z - 0.03), (-0.175, HEAD_C.z - 0.022), 0.014, steps=3, taper=0.6), face, white, lift=0.006)],
          bone="Head", tag="face")
    k.hair_cap(hair, hairline(0.5, 0.18, -0.12, -0.4), grow=0.04,
               volume=lambda d: 0.1 * step(0.6, 0.9, d.z) * (0.8 + 0.2 * math.sin(7 * math.atan2(d.x, -d.y))))
    for i, (a, tilt, length) in enumerate(((-70, 34, 0.1), (-35, 22, 0.12), (0, 12, 0.13), (35, 22, 0.12), (70, 34, 0.1), (-20, -18, 0.1), (25, -22, 0.1))):
        base = HEAD_C + Vector((math.sin(math.radians(a)) * 0.11, -math.cos(math.radians(a)) * 0.05 * (1 if tilt > 0 else -1.6), 0.21))
        tip = base + Vector((math.sin(math.radians(a)) * math.sin(math.radians(abs(tilt))), -math.cos(math.radians(a)) * math.sin(math.radians(tilt)),
                             math.cos(math.radians(tilt)))) * length
        k.add(limb(k.n(f"Spike{i}"), base, tip, 0.055, 0.014, hair, segs=8, light=True), bone="Head", tag="hair")
    k.neck()
    k.head_band("VisorBand", 0.085, 0.14, white, grow=0.017)
    k.add(cyl(k.n("VisorBrim"), 0.2, 0.018, HEAD_C + Vector((0, -0.185, 0.085)), rot=rad(-9, 0, 0), segs=28, bevel=0.007, m=teal), bone="Head", tag="headgear")

    k.torso(red, lower_m=shorts)
    front = k.on_torso("front")
    detail(k, [decal(k.n("Panel"), rrect(0, 1.225, 0.26, 0.12, 0.03), front, white, lift=0.004),
               strip(k.n("CrossH"), line_path((-0.045, 1.225), (0.045, 1.225), 0.028, steps=3), front, red, lift=0.008, sink=0.0),
               strip(k.n("CrossV"), line_path((0, 1.18), (0, 1.27), 0.028, steps=3), front, red, lift=0.008, sink=0.0)])
    for side in (1, -1):
        detail(k, strip(k.n(f"Side{side}"), line_path((side * 0.012, 1.0), (side * 0.012, 1.3), 0.05, steps=8), k.on_torso("left" if side > 0 else "right"),
                        red_dark, lift=0.003))
    k.belt(0.975, 0.03, shorts_hi, grow=0.008, name="Waistband")
    detail(k, strip(k.n("Drawstring"), [(-0.012, 0.975, 0.006), (-0.022, 0.94, 0.006), (-0.03, 0.9, 0.005)], k.on_torso("front"), white, lift=0.012))
    detail(k, strip(k.n("Drawstring2"), [(0.012, 0.975, 0.006), (0.026, 0.945, 0.006), (0.03, 0.91, 0.005)], k.on_torso("front"), white, lift=0.012))
    # Rescue tube across the back on a chest strap.
    by = back_y(k, 1.15, 0.075)
    a, b = Vector((0.2, by, 1.35)), Vector((-0.22, by, 0.97))
    k.add([limb(k.n("Tube"), a, b, 0.064, 0.064, tube_m, segs=12, squash=0.8),
           band(k.n("TubeBand"), a, b, 0.42, 0.58, 0.069, 0.069, white, squash=0.8, segs=12)], bone="Chest", tag="gear")
    k.strap("TubeStrap", [(0.2, 0.25, 1.3), (0.19, 0.0, 1.4), (0.14, -0.25, 1.3), (0.0, -0.3, 1.16), (-0.15, -0.28, 1.04), (-0.24, 0.0, 0.99),
                          (-0.2, 0.25, 1.0)], 0.04, dark)

    def limbs(side, s):
        k.upper_arm(side, k.skin_m)
        k.sleeve(side, red, length=0.42, hem_m=red_dark)
        k.fore_arm(side, k.skin_m)
        k.arm_band(side, "ForeArm", 0.76, 0.92, white if side < 0 else red, grow=0.006, name="Wrist")
        k.hand(side, k.skin_m)
        k.thigh(side, k.skin_m)
        k.shorts_leg(side, shorts, length=0.6, hem_m=shorts_hi)
        k.shin(side, k.skin_m)
        k.shoe(side, teal, white, style="sandal")
    both(limbs)
    return k, "big_wave", dict(bend=16, out=0.26)


def op_neon_courier():
    """Night-shift bike courier: aero helmet with a glass visor, piped jacket,
    messenger bag, glowing sneakers."""
    k = Kit("NC_", "#8a5636", dict(waist=0.95, hip=0.97))
    jacket = mat("Jacket", "#1f1b33", rough=0.55)
    panel = mat("JacketPanel", "#3a2f6b", rough=0.5)
    neon_p = mat("NeonPink", "#ff3fa4", rough=0.3, emit=2.6)
    neon_c = mat("NeonCyan", "#35f0ff", rough=0.3, emit=2.6)
    pants = mat("Joggers", "#2c2450", rough=0.65)
    shoe_m = mat("Sneaker", "#f4f0ff", rough=0.45)
    helmet = mat("Helmet", "#ff3fa4", rough=0.3)
    visor = mat("FxGlassVisor", "#35f0ff", rough=0.05)
    bag = mat("Bag", "#ffc24a", rough=0.6)
    flap = mat("BagFlap", "#ff8a2a", rough=0.6)
    hair = mat("Hair", "#1a1220", rough=0.8)
    glove = mat("Glove", "#1b1828", rough=0.6)

    k.head()
    k.face(iris="#4a2c1a", brow="#1a1220", mouth="smirk", lids=0.2, brow_tilt=5, blush="#c8584e")
    k.hair_cap(hair, hairline(0.5, 0.2, -0.1, -0.38), grow=0.03)
    k.add([blob(k.n("Puff"), 0.125, HEAD_C + Vector((0, 0.27, -0.06)), hair),
           torus(k.n("PuffTie"), 0.07, 0.018, HEAD_C + Vector((0, 0.19, -0.05)), rot=rad(90, 0, 0), m=neon_p, major_segs=16, minor_segs=6)],
          bone="Head", tag="hair")
    k.neck()
    # Helmet: a moulded shell over the top of the head, vents, glow stripe and a peak.
    shell_parts = k.hair_cap(helmet, hairline(0.36, 0.3, 0.16, 0.02), grow=0.2, name="Helmet", tag="headgear")
    top = Surface(shell_parts).projector("top")
    hy = HEAD_C.y
    k.add([strip(k.n("HelmetStripe"), line_path((0, hy - 0.22), (0, hy + 0.24), 0.034, steps=10, taper=0.5), top, neon_c, lift=0.006)]
          + [strip(k.n(f"Vent{i}"), line_path((x, hy - 0.16), (x * 1.1, hy + 0.15), 0.03, steps=8, taper=0.3), top, jacket, lift=0.004)
             for i, x in enumerate((-0.135, -0.07, 0.07, 0.135))], bone="Head", tag="headgear")
    k.add(cyl(k.n("Peak"), 0.17, 0.02, HEAD_C + Vector((0, -0.2, 0.105)), rot=rad(-12, 0, 0), segs=24, bevel=0.008, m=helmet), bone="Head", tag="headgear")
    k.add(blob(k.n("Visor"), 1.0, HEAD_C + Vector((0, -0.165, 0.018)), visor, scale=(0.222, 0.1, 0.07), segs=20, rings=10), bone="Head", tag="headgear")

    k.torso(panel, lower_m=pants)
    detail(k, strip(k.n("Zip"), line_path((0, 0.99), (0, 1.33), 0.026, steps=10), k.on_torso("front"), neon_p, lift=0.004))
    k.shell("Jacket", 0.95, 1.355, jacket, grow=0.012, thickness=0.014, gap=(7.0, 15.0))
    k.shell("Collar", 1.33, 1.415, jacket, grow=0.03, thickness=0.012, gap=(26.0, 40.0), segs=20)
    k.belt(0.965, 0.034, neon_c, grow=0.004, name="Hem")
    front = k.on_torso("front")
    detail(k, [decal(k.n("PanelL"), rrect(0.14, 1.19, 0.1, 0.17, 0.02), front, panel, lift=0.004),
               decal(k.n("PanelR"), rrect(-0.14, 1.19, 0.1, 0.17, 0.02), front, panel, lift=0.004),
               strip(k.n("PipeL"), line_path((0.14, 1.115), (0.14, 1.265), 0.012, steps=4), front, neon_c, lift=0.008, sink=0.0)])
    by = back_y(k, 1.12, 0.07)
    k.add([box(k.n("Bag"), (0.36, 0.13, 0.27), (0.02, by, 1.11), rot=rad(0, 8, 0), bevel=0.05, segs=3, m=bag),
           box(k.n("BagFlap"), (0.37, 0.05, 0.14), (0.02, by + 0.055, 1.175), rot=rad(0, 8, 0), bevel=0.024, m=flap),
           box(k.n("BagLogo"), (0.06, 0.02, 0.06), (0.02, by + 0.08, 1.165), rot=rad(0, 45, 0), bevel=0.008, m=neon_p)], bone="Chest", tag="gear")
    k.strap("BagStrap", [(-0.2, 0.25, 1.0), (-0.25, 0.0, 1.0), (-0.16, -0.28, 1.05), (0.0, -0.3, 1.18), (0.14, -0.25, 1.31), (0.19, 0.0, 1.4),
                         (0.17, 0.25, 1.3)], 0.045, bag)

    def limbs(side, s):
        k.upper_arm(side, jacket)
        k.arm_band(side, "UpperArm", 0.4, 0.47, neon_p, grow=0.005, name="Pipe")
        k.fore_arm(side, jacket)
        k.arm_band(side, "ForeArm", 0.74, 0.93, neon_c, grow=0.009, name="Cuff")
        k.hand(side, glove, plate_m=neon_p)
        k.thigh(side, pants)
        k.leg_band(side, "Thigh", 0.5, 0.56, neon_c, grow=0.004, name="Pipe")
        k.shin(side, pants)
        k.leg_band(side, "Shin", -0.02, 0.2, helmet, grow=0.012, name="KneePad")
        k.leg_band(side, "Shin", 0.78, 0.9, panel, grow=0.01, name="AnkleCuff")
        k.shoe(side, shoe_m, neon_c, toe_m=shoe_m, lace_m=neon_p, heel_m=helmet, stripe_m=neon_p, tongue_m=shoe_m)
    both(limbs)
    return k, "thumbs_up", dict(bend=22)


def op_deep_diver():
    """Brass diving helmet with a face behind the glass, navy wetsuit with
    orange panels, twin tanks, weight belt, a depth gauge on the wrist."""
    k = Kit("DD_", "#f0c4a0", dict(chest=1.04))
    brass = mat("Brass", "#e8a83a", rough=0.28, metal=0.75)
    brass_dark = mat("BrassDark", "#a8661f", rough=0.32, metal=0.7)
    glass = mat("FxGlassPort", "#9fefff", rough=0.05)
    suit = mat("Wetsuit", "#1d2f5c", rough=0.5)
    orange = mat("SuitPanel", "#ff8a2a", rough=0.5)
    tank = mat("Tank", "#ffd93b", rough=0.35)
    rubber = mat("Rubber", "#ffd93b", rough=0.55)
    dark = mat("DiveDark", "#1c1830", rough=0.5)
    lead = mat("Lead", "#5a5670", rough=0.4, metal=0.6)
    hair = mat("Hair", "#c8652a", rough=0.75)

    k.head(ears=False)
    k.face(iris="#2f8f7f", brow="#8a4a2a", mouth="smile", lids=0.06, brow_tilt=-9, eye_w=0.09, eye_h=0.106, freckles=True)
    k.hair_cap(hair, hairline(0.55, 0.36, 0.1, -0.2), grow=0.03)
    k.neck(dark, r=0.075)
    c = HEAD_C + Vector((0, 0.012, 0.03))
    radius, opening = 0.3, 37.0
    rim_r = radius * math.sin(math.radians(opening))
    rim_y = c.y - radius * math.cos(math.radians(opening))
    helmet = [open_shell(k.n("Helmet"), radius, c, opening, brass, scale=(1.0, 1.0, 0.96), thickness=0.02),
              torus(k.n("PortRim"), rim_r + 0.006, 0.03, (0, rim_y - 0.004, c.z), rot=rad(90, 0, 0), m=brass_dark, major_segs=28, minor_segs=8),
              blob(k.n("Valve"), 0.055, c + Vector((0, 0, radius * 0.96 + 0.02)), brass_dark, scale=(1, 1, 0.8)),
              cyl(k.n("HoseJoint"), 0.04, 0.09, c + Vector((0, radius + 0.02, 0.06)), rot=rad(90, 0, 0), segs=12, bevel=0.01, m=brass_dark)]
    for side in (1, -1):
        helmet += [torus(k.n(f"SideRim{side}"), 0.07, 0.02, c + Vector((side * (radius + 0.012), 0, 0.02)), rot=rad(0, 90, 0), m=brass_dark, major_segs=18,
                         minor_segs=6),
                   cyl(k.n(f"SidePort{side}"), 0.07, 0.016, c + Vector((side * (radius + 0.012), 0, 0.02)), rot=rad(0, 90, 0), segs=18, bevel=0.0, m=dark)]
    for i in range(10):
        a = math.tau * (i + 0.5) / 10
        helmet.append(blob(k.n(f"Rivet{i}"), 0.016, (math.cos(a) * (rim_r + 0.008), rim_y - 0.03, c.z + math.sin(a) * (rim_r + 0.008)), brass, segs=6, rings=4))
    k.add(helmet, bone="Head", tag="headgear", occlude=False)
    k.add(blob(k.n("Port"), 1.0, (0, rim_y + 0.004, c.z), glass, scale=(rim_r, 0.03, rim_r), segs=24, rings=8), bone="Head", tag="headgear")

    k.torso(suit)
    # Corselet: the brass collar the helmet seals onto.
    k.add(loft(k.n("Corselet"), [(1.315, 0.265, 0.16, 0, 0, 2.4), (1.34, 0.25, 0.15, 0, 0, 2.4), (1.375, 0.17, 0.12, 0, 0, 2.2), (1.388, 0.15, 0.11, 0, 0, 2.2)],
               brass_dark, segs=24, sub=1, caps=("flat", "flat"), sharp=70), field=True, tag="shell")
    k.shells.append((1.3, 1.4, 0.02))
    front = k.on_torso("front")
    detail(k, [decal(k.n("ChestPanel"), rrect(0, 1.2, 0.28, 0.12, 0.03), front, orange, lift=0.004),
               strip(k.n("Zip"), line_path((0, 1.0), (0, 1.3), 0.018, steps=8), front, dark, lift=0.008, sink=0.0)])
    for side in (1, -1):
        detail(k, strip(k.n(f"Flank{side}"), line_path((side * 0.01, 0.9), (side * 0.01, 1.26), 0.045, steps=9), k.on_torso("left" if side > 0 else "right"),
                        orange, lift=0.003))
    by = back_y(k, 1.14, 0.1)
    tanks = []
    for side in (1, -1):
        tanks += [limb(k.n(f"Tank{side}"), (side * 0.092, by, 0.99), (side * 0.092, by, 1.3), 0.086, 0.086, tank, segs=12),
                  cyl(k.n(f"TankValve{side}"), 0.03, 0.05, (side * 0.092, by, 1.385), segs=10, bevel=0.01, m=brass_dark)]
    tanks.append(box(k.n("TankBand"), (0.37, 0.19, 0.045), (0, by - 0.01, 1.14), bevel=0.018, m=dark))
    tanks.append(tube(k.n("AirHose"), [(0.092, by, 1.4), (0.12, by + 0.03, 1.415), (0.16, by + 0.04, 1.39)], 0.02, m=dark, segs=8))
    k.add(tanks, bone="Chest", tag="gear")
    shoulder_straps(k, dark, 0.04, 1.02, "Harness")
    k.belt(0.985, 0.06, dark)
    for i, a in enumerate((236, 258, 282, 304, 122, 58)):
        p = k.torso_point(0.985, a, 0.012)
        k.add(box(k.n(f"Weight{i}"), (0.075, 0.045, 0.075), p, rot=rad(0, 0, a - 270), bevel=0.014, m=lead), bone="Hips", tag="gear")

    def limbs(side, s):
        k.upper_arm(side, suit)
        k.arm_band(side, "UpperArm", 0.36, 0.5, orange, grow=0.004, name="Stripe")
        k.fore_arm(side, suit)
        k.arm_band(side, "ForeArm", 0.74, 0.93, orange, grow=0.009, name="Cuff")
        k.hand(side, rubber, plate_m=brass)
        k.thigh(side, suit)
        k.leg_band(side, "Thigh", 0.42, 0.56, orange, grow=0.004, name="Stripe")
        k.shin(side, suit)
        k.leg_band(side, "Shin", -0.02, 0.17, orange, grow=0.01, name="Knee")
        k.shoe(side, dark, lead, toe_m=brass, style="boot", collar_m=orange, shaft=0.15, shaft_m=dark, heel_m=brass_dark)
    both(limbs)
    gp = sx(1, ELBOW.lerp(WRIST, 0.48)) + Vector((0.075, 0, 0))
    k.add([cyl(k.n("Gauge"), 0.05, 0.035, gp, rot=rad(0, 90, 0), segs=14, bevel=0.01, m=brass_dark),
           cyl(k.n("GaugeFace"), 0.037, 0.012, gp + Vector((0.016, 0, 0)), rot=rad(0, 90, 0), segs=14, bevel=0.0,
               m=mat("GaugeGlow", "#baffff", rough=0.3, emit=1.6))], bone="ForeArm.L", tag="arm")
    return k, "knock", dict(bend=20, out=0.27, look=0.8)


def op_frost_guard():
    """Summit Lodge patroller: quilted parka with a fur-trimmed hood, goggles,
    knit scarf, mittens and snow boots."""
    k = Kit("FG_", "#f2c8a8", dict(shoulder=1.02, chest=1.03, waist=1.14, hip=1.06, depth=1.02, arm=1.16, leg=1.06))
    parka = mat("Parka", "#4fb4ff", rough=0.55)
    parka_dark = mat("ParkaDark", "#2f7fcf", rough=0.55)
    fur = mat("Fur", "#f7f4f2", rough=0.95)
    scarf = mat("Scarf", "#e8263a", rough=0.8)
    pants = mat("SnowPants", "#3d2f73", rough=0.65)
    boot = mat("SnowBoot", "#7a4a2c", rough=0.6)
    mitt = mat("Mitten", "#e8263a", rough=0.85)
    lens = mat("GoggleLens", "#ffb62e", rough=0.12, metal=0.5)
    dark = mat("FrostDark", "#1c1830", rough=0.5)
    hair = mat("Hair", "#f2c85a", rough=0.7)

    k.head(ears=False)
    k.face(iris="#3a6fbf", brow="#c9a37a", mouth="smile", lids=0.05, brow_tilt=-10, blush="#ff9fb0")
    k.hair_cap(hair, hairline(0.4, 0.3, 0.2, 0.0), grow=0.035)
    k.neck()
    c = HEAD_C + Vector((0, 0.035, 0.06))
    radius, opening = 0.3, 49.0
    rim_r = radius * math.sin(math.radians(opening))
    rim_y = c.y - radius * math.cos(math.radians(opening))
    hood = [open_shell(k.n("Hood"), radius, c, opening, parka, scale=(1.0, 1.0, 0.9), thickness=0.03),
            torus(k.n("HoodFur"), rim_r + 0.02, 0.055, (0, rim_y, c.z), rot=rad(90, 0, 0), m=fur, major_segs=28, minor_segs=8),
            blob(k.n("Pom"), 0.075, c + Vector((0, 0, radius * 0.9 + 0.045)), fur),
            box(k.n("GoggleFrame"), (0.3, 0.05, 0.08), (0, rim_y - 0.03, c.z + rim_r + 0.045), rot=rad(-28, 0, 0), bevel=0.03, m=dark)]
    for side in (1, -1):
        hood.append(blob(k.n(f"Goggle{side}"), 1.0, (side * 0.075, rim_y - 0.05, c.z + rim_r + 0.04), lens, scale=(0.062, 0.03, 0.042), rot=rad(-28, 0, 0)))
    k.add(hood, bone="Head", tag="headgear")

    k.torso(parka_dark, lower_m=pants, split_z=0.93)
    k.shell("Parka", 0.9, 1.36, parka, grow=0.018, thickness=0.02, flare=0.012)
    for i, z in enumerate((1.0, 1.11, 1.22)):
        k.belt(z, 0.016, parka_dark, grow=-0.004, name=f"Quilt{i}")
    k.belt(0.918, 0.05, fur, grow=0.004, name="FurHem")
    front = k.on_torso("front")
    detail(k, [strip(k.n("Zip"), line_path((0, 0.93), (0, 1.3), 0.024, steps=10), front, parka_dark, lift=0.006),
               decal(k.n("Patch"), rrect(-0.15, 1.255, 0.085, 0.085, 0.02), front, scarf, lift=0.005),
               strip(k.n("PatchH"), line_path((-0.178, 1.255), (-0.122, 1.255), 0.018, steps=2), front, fur, lift=0.009, sink=0.0),
               strip(k.n("PatchV"), line_path((-0.15, 1.227), (-0.15, 1.283), 0.018, steps=2), front, fur, lift=0.009, sink=0.0),
               strip(k.n("ScarfTail"), [(0.07, 1.37, 0.04), (0.1, 1.3, 0.05), (0.115, 1.22, 0.05), (0.12, 1.15, 0.046)], front, scarf, lift=0.012),
               strip(k.n("ScarfStripeA"), line_path((0.067, 1.18), (0.167, 1.18), 0.02, steps=2), front, fur, lift=0.016, sink=0.0),
               strip(k.n("ScarfStripeB"), line_path((0.064, 1.215), (0.164, 1.215), 0.02, steps=2), front, fur, lift=0.016, sink=0.0)])
    k.add(torus(k.n("ScarfWrap"), 0.12, 0.04, (0, 0.0, 1.385), m=scarf, major_segs=22, minor_segs=8), bone="Chest", tag="scarf")

    def limbs(side, s):
        k.upper_arm(side, parka)
        k.arm_band(side, "UpperArm", 0.44, 0.5, parka_dark, grow=-0.002, name="Quilt")
        k.fore_arm(side, parka)
        k.arm_band(side, "ForeArm", 0.3, 0.36, parka_dark, grow=-0.002, name="Quilt")
        k.arm_band(side, "ForeArm", 0.72, 0.95, fur, grow=0.014, name="Cuff")
        k.hand(side, mitt, mitten=True)
        k.thigh(side, pants)
        k.shin(side, pants)
        k.shoe(side, boot, dark, toe_m=boot, style="boot", collar_m=fur, shaft=0.13, shaft_m=boot, lace_m=fur)
    both(limbs)
    return k, "warm_hands", dict(bend=24, out=0.36, look=0.55, sway=0.8)


def op_astro_cadet():
    """Launch Pad cadet: white suit with orange trim, chest controls, bubble
    helmet over an orange bob, life-support pack."""
    k = Kit("AC_", "#c98a5e", dict(chest=1.05, arm=1.1, leg=1.08))
    suit = mat("Suit", "#f4f2fa", rough=0.5)
    shade = mat("SuitShade", "#c9c6d8", rough=0.55)
    orange = mat("Orange", "#ff7a2a", rough=0.45)
    glass = mat("FxGlassBubble", "#bfefff", rough=0.05)
    dark = mat("AstroDark", "#2b2840", rough=0.45)
    hair = mat("Hair", "#e0652a", rough=0.7)
    blue = mat("PatchBlue", "#3a7be0", rough=0.5)
    light_r = mat("LightRed", "#ff3f5f", rough=0.3, emit=2.5)
    light_g = mat("LightGreen", "#52f060", rough=0.3, emit=2.5)

    k.head()
    k.face(iris="#4a2c1a", brow="#a8461f", mouth="grin", lids=0.07, brow_tilt=-8, freckles=True, blush="#e87a6a")
    k.hair_cap(hair, hairline(0.42, 0.12, -0.34, -0.52), grow=0.06, volume=lambda d: 0.05 * step(0.5, -0.3, d.z))
    for i, x in enumerate((-0.09, 0.0, 0.085)):
        k.add(blob(k.n(f"Fringe{i}"), 0.07, HEAD_C + Vector((x, -0.2, 0.135 - abs(x) * 0.25)), hair, scale=(0.95, 0.5, 0.62), rot=rad(0, x * 180, 0)),
              bone="Head", tag="hair")
    k.neck(shade, r=0.08)
    k.add(blob(k.n("Bubble"), 0.315, HEAD_C + Vector((0, 0, 0.035)), glass, segs=28, rings=16), bone="Head", tag="headgear")

    k.torso(suit)
    k.add([loft(k.n("Yoke"), [(1.33, 0.262, 0.17, 0, 0, 2.4), (1.37, 0.24, 0.18, 0, 0, 2.2), (1.41, 0.205, 0.185, 0, 0, 2.0)], suit, segs=24, sub=1,
                caps=("flat", "flat"), sharp=70),
           torus(k.n("NeckRing"), 0.205, 0.04, (0, 0, 1.418), m=shade, major_segs=30, minor_segs=8)], bone="Chest", tag="shell")
    front = k.on_torso("front")
    detail(k, [decal(k.n("ChestPlate"), rrect(0, 1.195, 0.3, 0.19, 0.035), front, shade, lift=0.006),
               decal(k.n("Display"), rrect(0, 1.155, 0.19, 0.055, 0.012), front, dark, lift=0.011, sink=0.0),
               decal(k.n("BtnR"), rrect(-0.075, 1.235, 0.05, 0.04, 0.01), front, light_r, lift=0.012, sink=0.0),
               decal(k.n("BtnG"), rrect(0.0, 1.235, 0.05, 0.04, 0.01), front, light_g, lift=0.012, sink=0.0),
               decal(k.n("BtnB"), rrect(0.075, 1.235, 0.05, 0.04, 0.01), front, blue, lift=0.012, sink=0.0),
               strip(k.n("DisplayLine"), line_path((-0.07, 1.155), (0.07, 1.155), 0.012, steps=3), front, light_g, lift=0.0135, sink=0.0)])
    k.belt(0.985, 0.06, orange)
    detail(k, decal(k.n("Buckle"), rrect(0, 0.985, 0.08, 0.05, 0.012), k.on_torso("front"), dark, lift=0.01))
    by = back_y(k, 1.15, 0.085)
    pack = [box(k.n("Pack"), (0.4, 0.17, 0.42), (0, by, 1.15), bevel=0.06, segs=3, m=suit),
            box(k.n("PackBand"), (0.41, 0.18, 0.055), (0, by, 1.27), bevel=0.02, m=orange),
            blob(k.n("PackLight"), 0.028, (0.0, by + 0.09, 1.2), light_g, segs=8, rings=6),
            cyl(k.n("Antenna"), 0.01, 0.12, (0.19, by + 0.05, 1.41), rot=rad(0, 10, 0), segs=6, bevel=0.0, m=dark),
            blob(k.n("AntennaTip"), 0.026, (0.2, by + 0.05, 1.47), light_r, segs=8, rings=6)]
    for side in (1, -1):
        pack.append(limb(k.n(f"PackTank{side}"), (side * 0.215, by + 0.01, 0.99), (side * 0.215, by + 0.01, 1.3), 0.05, 0.05, shade, segs=10))
    k.add(pack, bone="Chest", tag="gear")
    shoulder_straps(k, orange, 0.04, 1.07)
    detail(k, [decal(k.n("MissionPatch"), ellipse_outline(0.17, 1.32, 0.036, 0.036, 12), k.on_torso("front"), blue, lift=0.012, sink=0.0),
               decal(k.n("PatchStar"), star_at(0.17, 1.32, 0.022, 0.01), k.on_torso("front"), mat("Star", "#ffd93b", rough=0.4), lift=0.016, sink=0.0)])

    def limbs(side, s):
        k.upper_arm(side, suit)
        k.arm_band(side, "UpperArm", 0.1, 0.3, orange, grow=0.01, name="Shoulder")
        k.fore_arm(side, suit)
        k.arm_band(side, "ForeArm", -0.04, 0.12, shade, grow=0.01, name="Elbow")
        k.arm_band(side, "ForeArm", 0.74, 0.93, orange, grow=0.01, name="Cuff")
        k.hand(side, suit, plate_m=orange)
        k.thigh(side, suit)
        k.shin(side, suit)
        k.leg_band(side, "Shin", -0.03, 0.14, shade, grow=0.01, name="Knee")
        k.shoe(side, shade, dark, toe_m=suit, style="boot", collar_m=orange, shaft=0.15, shaft_m=suit)
    both(limbs)
    return k, "salute", dict(bend=18, out=0.33)


def op_midway_maestro():
    """Carnival barker: striped blazer over a waistcoat belly, bow tie, straw
    boater and a grand curled moustache."""
    k = Kit("MM_", "#f2c09a", dict(belly=0.7, waist=1.16, chest=1.0, hip=1.05))
    pink = mat("StripePink", "#ff3f9f", rough=0.5)
    cream = mat("StripeCream", "#fff0d4", rough=0.5)
    straw = mat("Straw", "#f2cf7a", rough=0.75)
    purple = mat("HatBand", "#6b35b8", rough=0.5)
    pants = mat("Trousers", "#3d1f73", rough=0.6)
    shoe_m = mat("Shoe", "#1c1830", rough=0.25)
    spat = mat("Spat", "#f7f4f2", rough=0.5)
    tie = mat("BowTie", "#ffd93b", rough=0.4)
    stache = mat("Moustache", "#3d2318", rough=0.6)
    gold = mat("Gold", "#ffc23d", rough=0.25, metal=0.85)
    glove = mat("WhiteGlove", "#fbfaff", rough=0.5)
    shirt = mat("ShirtWhite", "#f7f4f2", rough=0.55)

    k.head()
    k.face(iris="#2a6a2e", brow="#3d2318", mouth="smile", lids=0.12, brow_tilt=-10, brow_w=0.11, mouth_z=-0.115)
    face = k.on_face()
    mz = HEAD_C.z - 0.078
    for side in (1, -1):
        path = [(side * 0.004, mz, 0.015), (side * 0.04, mz - 0.01, 0.019), (side * 0.082, mz - 0.006, 0.015), (side * 0.112, mz + 0.014, 0.009),
                (side * 0.112, mz + 0.034, 0.005)]
        k.add(strip(k.n(f"Stache{side}"), path, face, stache, lift=0.014), bone="Head", tag="face")
    k.hair_cap(stache, hairline(0.6, 0.25, -0.06, -0.4), grow=0.03)
    k.neck()
    f = hat_frame(0.17, -5.0, roll=6.0)
    hat = [loft(k.n("Brim"), disc_sections(0.36, 0.012), straw, segs=32, sub=1, frame=f, caps=("flat", "flat"), sharp=70),
           loft(k.n("Crown"), [(0.0, 0.246, 0.232, 0, 0, 2.1), (0.1, 0.242, 0.228, 0, 0, 2.1), (0.112, 0.232, 0.218, 0, 0, 2.1)], straw, segs=28, sub=1,
                frame=f, caps=("flat", "flat"), sharp=70),
           loft(k.n("HatBand"), [(0.014, 0.251, 0.237, 0, 0, 2.1), (0.02, 0.254, 0.24, 0, 0, 2.1), (0.062, 0.253, 0.239, 0, 0, 2.1),
                                 (0.068, 0.249, 0.235, 0, 0, 2.1)], purple, segs=28, sub=1, frame=f, caps=("flat", "flat"), sharp=70),
           box(k.n("Ticket"), (0.012, 0.07, 0.1), f @ Vector((0.255, -0.04, 0.085)), rot=rad(-5, 6, 8), bevel=0.004, m=tie)]
    k.add(hat, bone="Head", tag="headgear")

    k.torso(shirt, lower_m=pants, split_z=0.95)
    k.shell("Blazer", 0.9, 1.355, pink, grow=0.012, thickness=0.014, gap=(9.0, 30.0))
    front, back = k.on_torso("front"), k.on_torso("back")
    stripes = [strip(k.n(f"StripeF{i}"), line_path((x, 0.925), (x, 1.31), 0.026, steps=9), front, cream, lift=0.003) for i, x in enumerate((-0.19, -0.125, 0.125, 0.19))]
    stripes += [strip(k.n(f"StripeB{i}"), line_path((x, 0.925), (x, 1.31), 0.026, steps=9), back, cream, lift=0.003) for i, x in enumerate((-0.17, -0.085, 0.0, 0.085, 0.17))]
    detail(k, stripes)
    for side in (1, -1):
        detail(k, strip(k.n(f"Lapel{side}"), [(side * 0.04, 0.99, 0.014), (side * 0.06, 1.1, 0.024), (side * 0.085, 1.22, 0.03), (side * 0.115, 1.32, 0.022)],
                        front, purple, lift=0.007))
    detail(k, [decal(k.n("TieL"), [(0.0, 1.335), (0.085, 1.37), (0.085, 1.3)], front, tie, lift=0.014, inset=0.25),
               decal(k.n("TieR"), [(0.0, 1.335), (-0.085, 1.3), (-0.085, 1.37)], front, tie, lift=0.014, inset=0.25),
               decal(k.n("TieKnot"), ellipse_outline(0, 1.335, 0.02, 0.024, 8), front, tie, lift=0.02, sink=0.0, dome=0.004),
               decal(k.n("ButtonA"), ellipse_outline(0.0, 1.16, 0.011, 0.011, 8), front, gold, lift=0.006, dome=0.003),
               decal(k.n("ButtonB"), ellipse_outline(0.0, 1.08, 0.011, 0.011, 8), front, gold, lift=0.006, dome=0.003),
               decal(k.n("Carnation"), star_at(0.135, 1.27, 0.034, 0.022, 7), front, mat("Carnation", "#ff86c4", rough=0.6), lift=0.014, sink=0.0, dome=0.004),
               decal(k.n("CarnationEye"), ellipse_outline(0.135, 1.27, 0.01, 0.01, 8), front, tie, lift=0.02, sink=0.0)])
    k.strap("WatchChain", [(0.03, -0.3, 1.03), (0.08, -0.3, 1.005), (0.14, -0.3, 1.02)], 0.012, gold, thick=0.004, lift=0.006)

    def limbs(side, s):
        k.upper_arm(side, pink)
        for i, f0 in enumerate((0.3, 0.56)):
            k.arm_band(side, "UpperArm", f0, f0 + 0.08, cream, grow=0.003, name=f"Stripe{i}")
        k.fore_arm(side, pink)
        k.arm_band(side, "ForeArm", 0.26, 0.34, cream, grow=0.003, name="Stripe")
        k.arm_band(side, "ForeArm", 0.74, 0.93, cream, grow=0.009, name="Cuff")
        k.hand(side, glove, plate_m=gold)
        k.thigh(side, pants)
        k.shin(side, pants)
        k.leg_band(side, "Shin", 0.74, 0.99, spat, grow=0.012, name="Spat")
        k.shoe(side, shoe_m, shoe_m, toe_m=spat, style="shoe")
    both(limbs)
    return k, "ta_da", dict(bend=22, out=0.3, lean=-2.0)


def op_glitch():
    """GL1TCH: a hologram body under a CRT monitor head with a pixel face."""
    k = Kit("GL_", "#35f0ff")
    holo = mat("FxHoloBody", "#35f0ff", rough=0.3, emit=1.2)
    holo2 = mat("FxHoloAccent", "#ff3fa4", rough=0.3, emit=1.2)
    frame = mat("GlitchFrame", "#1a1436", rough=0.35, metal=0.3)
    frame_hi = mat("GlitchFrameHi", "#3a2f6b", rough=0.4, metal=0.3)
    screen = mat("Screen", "#070512", rough=0.15)
    pixel = mat("ScreenPixel", "#35f0ff", rough=0.2, emit=3.0)
    pixel2 = mat("ScreenPixelPink", "#ff3fa4", rough=0.2, emit=3.0)

    c = HEAD_C + Vector((0, 0, 0.0))
    sy = c.y - 0.215
    head = [box(k.n("Monitor"), (0.54, 0.43, 0.45), c, bevel=0.075, segs=3, m=frame),
            box(k.n("Bezel"), (0.47, 0.05, 0.38), (0, sy + 0.012, c.z), bevel=0.04, segs=3, m=frame_hi),
            box(k.n("Screen"), (0.41, 0.04, 0.32), (0, sy - 0.004, c.z), bevel=0.035, segs=3, m=screen),
            box(k.n("Back"), (0.36, 0.1, 0.3), (0, c.y + 0.22, c.z), bevel=0.04, segs=2, m=frame_hi),
            cyl(k.n("Antenna"), 0.012, 0.17, (0.17, c.y + 0.03, c.z + 0.3), rot=rad(0, 18, 0), segs=6, bevel=0.0, m=frame_hi),
            blob(k.n("AntennaTip"), 0.03, (0.197, c.y + 0.03, c.z + 0.385), pixel2, segs=8, rings=6),
            cyl(k.n("Knob"), 0.03, 0.03, (-0.275, c.y - 0.05, c.z - 0.11), rot=rad(0, 90, 0), segs=10, bevel=0.008, m=frame_hi),
            cyl(k.n("Knob2"), 0.022, 0.03, (-0.275, c.y + 0.03, c.z - 0.11), rot=rad(0, 90, 0), segs=10, bevel=0.008, m=frame_hi)]
    px = 0.036
    for side in (-1, 1):       # ^ ^ eyes
        for i, (u, v) in enumerate(((-1, 0), (0, 1), (1, 0))):
            head.append(box(k.n(f"Eye{side}{i}"), (px, 0.016, px), (side * 0.1 + u * px, sy - 0.022, c.z + 0.05 + v * px), bevel=0.004, m=pixel))
    for i, (u, v) in enumerate(((-2, 1), (-1, 0), (0, 0), (1, 0), (2, 1))):
        head.append(box(k.n(f"Mouth{i}"), (px, 0.016, px), (u * px, sy - 0.022, c.z - 0.085 + v * px), bevel=0.004, m=pixel2))
    k.add(head, bone="Head", tag="head")
    k.neck(holo, r=0.06)

    k.torso(holo)
    front = k.on_torso("front")
    detail(k, [decal(k.n("Core"), [(0, 1.275), (0.058, 1.205), (0, 1.135), (-0.058, 1.205)], front, holo2, lift=0.01, inset=0.3),
               decal(k.n("CoreIn"), [(0, 1.24), (0.028, 1.205), (0, 1.17), (-0.028, 1.205)], front, pixel, lift=0.016, sink=0.0, inset=0.3)])
    k.belt(0.985, 0.05, frame)
    k.belt(1.075, 0.02, holo2, grow=0.004, name="Slice")
    detail(k, decal(k.n("Buckle"), rrect(0, 0.985, 0.07, 0.04, 0.008), k.on_torso("front"), pixel2, lift=0.008))

    def limbs(side, s):
        k.upper_arm(side, holo)
        k.arm_band(side, "UpperArm", -0.08, 0.16, frame, grow=0.012, name="Shoulder")
        k.fore_arm(side, holo)
        k.arm_band(side, "ForeArm", 0.4, 0.46, holo2, grow=0.004, name="Slice")
        k.arm_band(side, "ForeArm", 0.76, 0.93, frame, grow=0.009, name="Cuff")
        k.hand(side, holo2)
        k.thigh(side, holo)
        k.leg_band(side, "Thigh", 0.5, 0.56, holo2, grow=0.004, name="Slice")
        k.shin(side, holo)
        k.leg_band(side, "Shin", -0.04, 0.14, frame, grow=0.01, name="Knee")
        k.shoe(side, frame, holo2, toe_m=frame_hi, style="sneaker", collar_m=frame_hi)
    both(limbs)
    # Pixels breaking off the edges of the projection.
    bits = [("UpperArm.L", sx(1, SHOULDER) + Vector((0.085, 0.02, 0.0)), 0.045, holo), ("UpperArm.L", sx(1, SHOULDER) + Vector((0.1, -0.03, -0.07)), 0.03, holo2),
            ("ForeArm.R", sx(-1, ELBOW.lerp(WRIST, 0.5)) + Vector((-0.07, 0.01, 0.0)), 0.04, holo), ("ForeArm.R", sx(-1, ELBOW.lerp(WRIST, 0.3)) + Vector((-0.085, -0.02, 0.03)), 0.026, holo2),
            ("Thigh.L", sx(1, HIP.lerp(KNEE, 0.5)) + Vector((0.095, 0.0, 0.0)), 0.04, holo), ("Shin.R", sx(-1, KNEE.lerp(HIP, -0.4)) + Vector((-0.08, 0.02, 0.0)), 0.034, holo2)]
    for i, (bone, p, size, m) in enumerate(bits):
        k.add(box(k.n(f"Bit{i}"), (size, size, size), p, rot=rad(0, 0, 20 * i), bevel=0.004, m=m), bone=bone, tag="bits")
    return k, "glitch", dict(bend=14, out=0.27, look=0.7)


def op_arcade_champion():
    """Arcade Champion: sparkling gold suit, title belt, purple cape, crown and
    star shades."""
    k = Kit("CH_", "#a86a42", dict(shoulder=1.08, chest=1.06, waist=0.97))
    k.extra_bones = [("Cape1", (0, 0.15, 1.34), (0, 0.19, 1.02), "Chest"), ("Cape2", (0, 0.19, 1.02), (0, 0.25, 0.64), "Cape1")]
    gold = mat("FxGoldSuit", "#ffc23d", rough=0.25, metal=0.9)
    trim = mat("GoldTrim", "#ffd96a", rough=0.2, metal=0.9)
    purple = mat("Cape", "#6b35b8", rough=0.55)
    lining = mat("CapeLining", "#ff3f9f", rough=0.5)
    shades = mat("StarShades", "#ff3f9f", rough=0.2, metal=0.3)
    lens = mat("ShadeLens", "#1c1830", rough=0.1, metal=0.4)
    gem = mat("GemRed", "#ff2f5f", rough=0.15, emit=1.2)
    gem_b = mat("GemBlue", "#3fc4ff", rough=0.12, metal=0.3)
    hair = mat("Hair", "#1c1220", rough=0.75)
    kick = mat("Kick", "#6b35b8", rough=0.4)
    white = mat("KickSole", "#f7f4f2", rough=0.4)

    k.head()
    k.face(brow="#1c1220", mouth="grin", brow_tilt=-6, blush=None, eyes=False, brow_z=0.1)
    face = k.on_face()
    z = HEAD_C.z + 0.012
    for side in (1, -1):
        k.add([decal(k.n(f"Shade{side}"), star_at(side * 0.1, z, 0.078, 0.044), face, shades, lift=0.012, sink=0.004, inset=0.16),
               decal(k.n(f"Lens{side}"), star_at(side * 0.1, z, 0.052, 0.03), face, lens, lift=0.017, sink=0.0, inset=0.3, dome=0.003)], bone="Head", tag="face")
    k.add(strip(k.n("Bridge"), line_path((-0.04, z + 0.008), (0.04, z + 0.008), 0.014, steps=3), face, shades, lift=0.012), bone="Head", tag="face")
    k.hair_cap(hair, hairline(0.56, 0.3, 0.0, -0.3), grow=0.035, volume=lambda d: 0.07 * step(0.55, 0.9, d.z))
    k.neck()
    f = hat_frame(0.195, -5.0)
    crown = [loft(k.n("CrownBand"), [(0.0, 0.212, 0.2, 0, 0, 2.1), (0.012, 0.218, 0.206, 0, 0, 2.1), (0.075, 0.228, 0.215, 0, 0, 2.1), (0.085, 0.222, 0.21, 0, 0, 2.1)],
                  trim, segs=28, sub=1, frame=f, caps=("flat", "flat"), sharp=70)]
    for i in range(7):
        a = math.tau * i / 7 - math.pi / 2
        p = Vector((math.cos(a) * 0.212, math.sin(a) * 0.2, 0.0))
        crown += [cyl(k.n(f"Point{i}"), 0.042, 0.1, f @ (p + Vector((0, 0, 0.12))), rot=rad(-5, 0, 0), segs=8, bevel=0.006, m=trim, radius_top=0.008),
                  blob(k.n(f"Pearl{i}"), 0.02, f @ (p + Vector((0, 0, 0.178))), trim, segs=8, rings=5),
                  blob(k.n(f"Gem{i}"), 0.021, f @ (p * 1.045 + Vector((0, 0, 0.044))), gem if i % 2 == 0 else gem_b, scale=(1, 1, 1.25), segs=8, rings=6)]
    k.add(crown, bone="Head", tag="headgear")

    k.torso(gold)
    front = k.on_torso("front")
    for side in (1, -1):
        detail(k, strip(k.n(f"Lapel{side}"), [(side * 0.02, 1.06, 0.012), (side * 0.045, 1.16, 0.026), (side * 0.085, 1.26, 0.034), (side * 0.12, 1.34, 0.026)],
                        front, purple, lift=0.006))
    detail(k, decal(k.n("ChestStar"), star_at(0.0, 1.245, 0.03, 0.014), front, lining, lift=0.006, dome=0.002))
    k.belt(0.985, 0.085, purple)
    belt = k.on_torso("front")
    detail(k, [decal(k.n("Plate"), ellipse_outline(0, 0.985, 0.095, 0.075, 16), belt, trim, lift=0.014, dome=0.006),
               decal(k.n("PlateStar"), star_at(0, 0.985, 0.046, 0.022), belt, gem, lift=0.024, sink=0.0, dome=0.003),
               decal(k.n("SidePlateL"), rrect(0.165, 0.985, 0.07, 0.06, 0.012), belt, trim, lift=0.009),
               decal(k.n("SidePlateR"), rrect(-0.165, 0.985, 0.07, 0.06, 0.012), belt, trim, lift=0.009)])
    # Cape on two bones so it trails behind in a run.
    rows = [(1.37, 0.15, 0.46), (1.3, 0.172, 0.52), (1.2, 0.19, 0.58), (1.08, 0.2, 0.63), (0.95, 0.212, 0.68), (0.82, 0.23, 0.72), (0.7, 0.252, 0.74), (0.62, 0.262, 0.72)]
    normals = [(0, 1, 0.12)] * len(rows)
    cape = [ribbon(k.n("Cape"), [(0, y, zz) for zz, y, _w in rows], normals, [w for _z, _y, w in rows], 0.008, purple),
            ribbon(k.n("CapeLining"), [(0, y - 0.011, zz + 0.004) for zz, y, _w in rows], [(0, -1, -0.12)] * len(rows), [w - 0.035 for _z, _y, w in rows], 0.004, lining)]
    k.add(cape, tag="cape", region="cape", blend=("Cape1", "Cape2", 1.1, 0.94))
    for side in (1, -1):
        p = k.torso_point(1.345, 270 + side * 50, 0.012)
        k.add(blob(k.n(f"Clasp{side}"), 0.034, Vector((side * 0.2, p.y - 0.01, 1.345)), gem, segs=10, rings=6), bone="Chest", tag="gear")
    k.strap("Chain", [(0.2, -0.3, 1.34), (0.1, -0.3, 1.31), (0.0, -0.3, 1.3), (-0.1, -0.3, 1.31), (-0.2, -0.3, 1.34)], 0.016, trim, thick=0.005, lift=0.006)
    k.strap("CapeYoke", [(0.24, 0.25, 1.3), (0.2, 0.0, 1.4), (0.205, -0.25, 1.33)], 0.07, purple, thick=0.008)
    k.strap("CapeYokeR", [(-0.24, 0.25, 1.3), (-0.2, 0.0, 1.4), (-0.205, -0.25, 1.33)], 0.07, purple, thick=0.008)

    def limbs(side, s):
        k.upper_arm(side, gold)
        k.fore_arm(side, gold)
        k.arm_band(side, "ForeArm", 0.72, 0.93, purple, grow=0.01, name="Cuff")
        k.hand(side, trim, plate_m=lining)
        k.thigh(side, gold)
        k.shin(side, gold)
        k.leg_band(side, "Shin", 0.8, 0.92, trim, grow=0.008, name="Ankle")
        k.shoe(side, kick, white, toe_m=white, lace_m=white, stripe_m=trim, tongue_m=kick, heel_m=trim)
    both(limbs)
    return k, "flex", dict(bend=20, out=0.3, chin=-5.0, lean=-1.5)


OPERATORS = {
    "boardwalk_ranger": op_boardwalk_ranger,
    "surf_rescue": op_surf_rescue,
    "neon_courier": op_neon_courier,
    "deep_diver": op_deep_diver,
    "frost_guard": op_frost_guard,
    "astro_cadet": op_astro_cadet,
    "midway_maestro": op_midway_maestro,
    "glitch": op_glitch,
    "arcade_champion": op_arcade_champion,
}


def build(op_id, audit=False):
    scene = reset_scene()
    scene.render.fps = 30
    k, pose_style, idle_style = OPERATORS[op_id]()
    armature = build_armature(k.extra_bones)
    # Sockets are placed while the rig is still at rest (before any clip exists).
    sockets = [socket("WeaponSocket", armature, "Hand.R", weapon_socket_matrix()),
               socket("HeadSocket", armature, "Head", Matrix.Translation(HEAD_C))]
    body_mesh, info = skin("Body", k, armature)
    rig = Rig(k.extra_bones)
    clips = build_clips(rig, pose_style, idle_style)
    bake_clips(armature, clips)
    export("operator_" + op_id, [armature, body_mesh] + sockets)
    if audit:
        import operator_audit
        operator_audit.run(op_id, body_mesh, info, rig, clips)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    for op in args or list(OPERATORS):
        build(op, audit="--audit" in sys.argv)
