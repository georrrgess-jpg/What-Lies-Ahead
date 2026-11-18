"""Gold Rush Gulch zombies (World 12, Boomtown): the shared rig (build_zombie.py),
three outfits.

    Outfit_Cowpoke   Cowpoke: a lanky gunslinger in a tintable shirt ("Shirt"), a
                     leather vest, a red bandana, a gun belt with a holster and a
                     big gold buckle, chaps and spurred boots; a ten-gallon hat
                     (Acc_Cowpoke_Hat) and a toy six-shooter in the right hand
                     (Acc_Cowpoke_Pistol)
    Outfit_Prospector  Prospector: a stout old miner in tintable long johns
                     ("Shirt") with braces, patched trousers and big boots, a bushy
                     beard; a hard hat with a lamp (Acc_Prospector_Helmet) and a
                     pickaxe and gold pan slung on the back (Acc_Prospector_Pick)
    Outfit_Sheriff   Sheriff Rattlebones (the alpha): a hulking sheriff in a toy
                     skeleton shirt (bone ribs over the tintable "Shirt"), a long
                     duster coat, a gold star and a double gun belt; a huge black
                     hat (Acc_Sheriff_Hat), a handlebar moustache (Acc_Sheriff_Stache)
                     and a giant toy revolver (Acc_Sheriff_Revolver)

Faces: two presets per outfit (Face_<Outfit>_<Preset>).

Clips (gulch_clips below, from zombie_anim): the shared set, the Cowpoke's
swagger and quick-draw (Draw, the shot at its release time), the Prospector's
trudge and dig (Dig, a deep crouch before it burrows), the Sheriff's stomp,
charge, slam, roar, dynamite throw and draw ("_Heavy" style).

    python art/blender/build_gulch_zombies.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gulch_common import *  # noqa: F401,F403
import build_zombie as bz  # noqa: E402
import zombie_anim  # noqa: E402
from zombie_anim import (FPS, arms, attack, attack_heavy, charge, crouch, deaths, emerge, feet, gait, hit_head, idle, keyed,  # noqa: E402
                         ready, roar, shamble, stagger, stomp, swagger, throw, trudge)
from zombie_kit import (HEAD_Y, SPARK_EYE, arm, band, base_materials, blob, cap_crown, face_y, faces, hair, head, head_band,  # noqa: E402
                        hips, leg, neck, patch, torso)


def materials():
    m = base_materials("gulch", skin="#a9cf62", skin_dark="#6f9a3c", dark="#2b2230", white="#fbf7ee", eye=(SPARK_EYE, 2.6))
    m.update(
        shirt=mat("Shirt", "#e8574a", rough=0.6),
        leather=mat("GulchZLeather", "#8a5530", rough=0.7),
        leather_dark=mat("GulchZLeatherDark", "#5c3520", rough=0.7),
        denim=mat("GulchZDenim", "#3f6fa8", rough=0.75),
        red=mat("GulchZRed", "#d23b2f", rough=0.55),
        gold=mat("GulchZGold", "#ffc93c", rough=0.3, metal=0.5),
        steel=mat("GulchZSteel", "#b8bcc8", rough=0.3, metal=0.6),
        orange=mat("GulchZOrange", "#ff8a2a", rough=0.5),
        hat=mat("GulchZHat", "#c48a50", rough=0.7),
        hat_band=mat("GulchZHatBand", "#5c3520", rough=0.6),
        black=mat("GulchZBlack", "#3b2a24", rough=0.6),
        beard=mat("GulchZBeard", "#e8e2d6", rough=0.9),
        yellow=mat("GulchZYellow", "#ffd23c", rough=0.5),
        lamp=mat("GulchZLamp", "#fff2b8", rough=0.2, emit=3.0),
        bone=mat("GulchZBone", "#f3ead4", rough=0.6),
        canvas=mat("GulchZCanvas", "#d9b98a", rough=0.85),
        wood=mat("GulchZWood", "#a8693f", rough=0.7),
    )
    return m


def six_shooter(p, m, wrist, scale=1.0):
    """A toy revolver held in the right hand, barrel down the arm (it points
    where the forearm points), with an orange safety tip."""
    x, y, z = wrist
    k = scale
    return [box(p + "Grip", (0.05 * k, 0.07 * k, 0.12 * k), (x, y - 0.02 * k, z - 0.07 * k), rot=(math.radians(-15), 0, 0), bevel=0.015, m=m["wood"]),
            cyl(p + "Drum", 0.05 * k, 0.08 * k, (x, y - 0.05 * k, z - 0.15 * k), segs=10, bevel=0.01, m=m["gold"]),
            cyl(p + "Barrel", 0.026 * k, 0.26 * k, (x, y - 0.06 * k, z - 0.3 * k), segs=8, bevel=0.0, m=m["steel"]),
            cyl(p + "Tip", 0.03 * k, 0.04 * k, (x, y - 0.06 * k, z - 0.44 * k), segs=8, bevel=0.0, m=m["orange"]),
            box(p + "Hammer", (0.02 * k, 0.04 * k, 0.04 * k), (x, y - 0.0, z - 0.11 * k), bevel=0.0, m=m["steel"])]


def ten_gallon(p, m, top=2.12, brim_r=0.46, crown_r=0.24, brim_m=None, band_m=None, z0=1.84):
    brim_m = brim_m or m["hat"]
    band_m = band_m or m["hat_band"]
    parts = [cyl(p + "Brim", brim_r, 0.035, (0, HEAD_Y, z0), segs=28, bevel=0.012, m=brim_m),
             cyl(p + "Crown", crown_r, top - z0, (0, HEAD_Y, (top + z0) / 2), segs=24, bevel=0.04, m=brim_m, radius_top=crown_r * 0.86),
             cyl(p + "Band", crown_r + 0.006, 0.06, (0, HEAD_Y, z0 + 0.06), segs=24, bevel=0.0, m=band_m),
             box(p + "Dent", (0.06, crown_r * 1.4, 0.06), (0, HEAD_Y, top - 0.01), bevel=0.02, m=band_m)]
    # Upturned brim sides.
    for s in (-1, 1):
        parts.append(box(f"{p}Curl{s}", (0.08, brim_r * 1.3, 0.035), (s * (brim_r - 0.05), HEAD_Y, z0 + 0.06), rot=(0, s * math.radians(35), 0),
                         bevel=0.012, m=brim_m))
    return parts


# ---------------------------------------------------------------------------
# Cowpoke
# ---------------------------------------------------------------------------

def cowpoke(m):
    p = "W_"
    w = 0.56
    parts = head(p, m, w)
    parts += hair(p, w, m["dark"], "fringe", 41)
    tor, body = torso(p, m["shirt"], w=0.58, d=0.4, z0=0.9, hunch=0.06, n=3.0)
    parts += tor
    parts += neck(p, m["skin"], 0.22)
    t = tor[0]
    vest = []
    for s in (-1, 1):
        x = s * 0.16
        vest.append(patch(f"{p}Vest{s}", t, (x, body.front(x, 1.18), 1.18), (0.17, 0.03, 0.42), m["leather"], bevel=0.01))
        vest.append(sphere(f"{p}VestStud{s}", 0.02, (s * 0.09, body.front(s * 0.09, 1.08) - 0.015, 1.08), m=m["gold"], segs=6, rings=4))
    vest.append(band(p + "VestBack", (0, 0, 1.38), (0, 0, 0.98), 0.3, 0.21, m["leather"], n=3.0, thick=0.012, segs=22))
    # Bandana knotted at the throat.
    vest += [prism(p + "Bandana", [(-0.14, 0), (0.14, 0), (0, -0.18)], 0.04, (0, body.front(0, 1.4) - 0.03, 1.44), m=m["red"]),
             sphere(p + "Knot", 0.04, (0.06, body.front(0, 1.42) - 0.04, 1.44), m=m["red"], segs=6, rings=4)]
    parts += bz.bind("Spine", vest)
    parts += hips(p, m["denim"], w=0.54, d=0.4, belt=m["leather_dark"], buckle=m["gold"])
    parts += bz.bind("Hips", [box(p + "BigBuckle", (0.16, 0.04, 0.11), (0, -0.23, 0.97), bevel=0.02, m=m["gold"]),
                              box(p + "Holster", (0.1, 0.12, 0.26), (-0.3, -0.04, 0.8), rot=(0, math.radians(-8), 0), bevel=0.03, m=m["leather"]),
                              box(p + "HolsterFlap", (0.11, 0.13, 0.05), (-0.3, -0.04, 0.94), bevel=0.02, m=m["leather_dark"])])
    for side in (1, -1):
        parts += arm(p, side, m, w=0.15, sleeve=m["shirt"], sleeve_len="long", cuff=m["shirt"], seed=61)
        parts += leg(p, side, m, w=0.17, pants=m["denim"], pants_len="long", foot="boot", shoe=m["leather_dark"], sole=m["dark"], tear=0)
        sx = "L" if side > 0 else "R"
        parts += bz.bind(f"Thigh.{sx}", [box(f"{p}Chap{sx}", (0.08, 0.2, 0.34), (side * 0.2, -0.02, 0.66), bevel=0.03, m=m["leather"])])
        parts += bz.bind(f"Shin.{sx}", [torus(f"{p}Spur{sx}", 0.04, 0.012, (side * 0.13, 0.12, 0.08), rot=rad(0, 90, 0), m=m["steel"], major_segs=10,
                                              minor_segs=4)])
    return parts


def cowpoke_accessories(m):
    p = "WA_"
    w = 0.56
    acc = {
        "Acc_Cowpoke_Hat": bz.bind("Head", ten_gallon(p + "Hat", m)),
        "Acc_Cowpoke_Pistol": bz.bind("ForeArm.R", six_shooter(p + "Gun", m, (-0.44, -0.02, 0.58))),
    }
    acc.update(faces("Cowpoke", m, w, ("Grin", "Snarl"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Prospector
# ---------------------------------------------------------------------------

def prospector(m):
    p = "P_"
    w = 0.64
    parts = head(p, m, w)
    tor, body = torso(p, m["shirt"], w=0.78, d=0.54, z0=0.86, belly=0.14, hunch=0.1, n=2.8, hem=m["shirt"])
    parts += tor
    parts += neck(p, m["skin"], 0.27)
    t = tor[0]
    braces = []
    for s in (-1, 1):
        x = s * 0.17
        braces.append(patch(f"{p}Brace{s}", t, (x, body.front(x, 1.15), 1.15), (0.06, 0.02, 0.56), m["leather_dark"], bevel=0.005))
        braces.append(sphere(f"{p}BraceButton{s}", 0.025, (x, body.front(x, 0.95) - 0.01, 0.95), m=m["gold"], segs=6, rings=4))
    for i in range(3):
        braces.append(sphere(f"{p}Button{i}", 0.022, (0, body.front(0, 1.35 - i * 0.1) - 0.01, 1.35 - i * 0.1), m=m["bone"], segs=6, rings=4))
    braces.append(patch(p + "Patch", t, (0.12, body.front(0.12, 1.05), 1.05), (0.12, 0.02, 0.12), m["canvas"], bevel=0.005))
    parts += bz.bind("Spine", braces)
    parts += hips(p, m["leather"], w=0.72, d=0.52, belt=m["dark"])
    beard = []
    for i, (x, y, z, r) in enumerate(((0, -0.12, 1.44, 0.16), (-0.14, -0.08, 1.49, 0.12), (0.14, -0.08, 1.49, 0.12), (0, -0.17, 1.33, 0.12),
                                      (-0.09, -0.14, 1.38, 0.1), (0.09, -0.14, 1.38, 0.1))):
        beard.append(sphere(f"{p}Beard{i}", r, (x, HEAD_Y + y - 0.2, z), m=m["beard"], segs=10, rings=7))
    beard += [sphere(f"{p}Brow{s}", 0.06, (s * 0.12, face_y(w, 1.72) - 0.02, 1.72), scale=(1.4, 0.6, 0.6), m=m["beard"], segs=8, rings=5)
              for s in (-1, 1)]
    parts += bz.bind("Head", beard)
    for side in (1, -1):
        parts += arm(p, side, m, w=0.2, sleeve=m["shirt"], sleeve_len="long", cuff=m["shirt"], hand=0.03, out=0.04, seed=63)
        parts += leg(p, side, m, w=0.22, pants=m["leather"], pants_len="long", foot="boot", shoe=m["leather_dark"], sole=m["dark"], tear=0)
        sx = "L" if side > 0 else "R"
        parts += bz.bind(f"Thigh.{sx}", [box(f"{p}KneePatch{sx}", (0.14, 0.04, 0.14), (side * 0.13, -0.13, 0.55), bevel=0.02, m=m["canvas"])])
    return parts


def prospector_accessories(m):
    p = "PA_"
    w = 0.64
    helmet = [cap_crown(p + "Helmet", w, m["yellow"], rim=1.74, top=2.02, off=0.045),
              head_band(p + "HelmetRim", w, 1.76, 1.72, m["yellow"], off=0.07, thick=0.025),
              box(p + "Peak", (0.3, 0.14, 0.03), (0, HEAD_Y - 0.33, 1.75), rot=(math.radians(-8), 0, 0), bevel=0.01, m=m["yellow"]),
              cyl(p + "LampBody", 0.07, 0.07, (0, face_y(w, 1.9) - 0.06, 1.9), rot=rad(80, 0, 0), segs=12, bevel=0.01, m=m["black"]),
              cyl(p + "LampLens", 0.055, 0.02, (0, face_y(w, 1.9) - 0.1, 1.9), rot=rad(80, 0, 0), segs=12, bevel=0.0, m=m["lamp"])]
    # On the back: a pickaxe across the shoulders and a gold pan.
    back = [tube(p + "PickHandle", [(-0.4, 0.33, 0.95), (0.42, 0.33, 1.55)], 0.03, m=m["wood"], segs=6),
            box(p + "PickHead", (0.07, 0.07, 0.62), (0.4, 0.34, 1.54), rot=(0, math.radians(-35), 0), bevel=0.02, m=m["steel"]),
            cyl(p + "Pan", 0.24, 0.05, (0, 0.34, 1.18), rot=rad(90, 0, 0), segs=20, bevel=0.015, m=m["steel"]),
            sphere(p + "PanNugget", 0.07, (0.03, 0.37, 1.16), scale=(1, 0.6, 0.8), m=m["gold"], segs=7, rings=5),
            box(p + "Strap", (0.05, 0.03, 0.66), (0.0, 0.3, 1.2), rot=(0, math.radians(40), 0), bevel=0.0, m=m["leather_dark"])]
    acc = {
        "Acc_Prospector_Helmet": bz.bind("Head", helmet),
        "Acc_Prospector_Pick": bz.bind("Spine", back),
    }
    acc.update(faces("Prospector", m, w, ("Gape", "Grin"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Sheriff Rattlebones (the alpha)
# ---------------------------------------------------------------------------

def sheriff(m):
    p = "S_"
    w = 0.68
    parts = head(p, m, w)
    tor, body = torso(p, m["shirt"], w=1.0, d=0.66, z0=0.84, z1=1.48, waist=0.9, belly=0.08, hunch=0.1, chest=1.06, n=2.8, hem=m["shirt"])
    parts += tor
    parts += neck(p, m["skin"], 0.4, z1=1.48)
    t = tor[0]
    coat = []
    # Toy skeleton ribs painted on the shirt, a sternum and the star badge.
    coat.append(patch(p + "Sternum", t, (0, body.front(0, 1.2), 1.2), (0.08, 0.025, 0.46), m["bone"], bevel=0.008))
    for i in range(4):
        z = 1.34 - i * 0.12
        for s in (-1, 1):
            x = s * 0.15
            coat.append(patch(f"{p}Rib{i}{s}", t, (x, body.front(x, z), z), (0.24 - i * 0.02, 0.025, 0.065), m["bone"], bevel=0.008))
    coat.append(star(p + "Star", 0.15, 0.05, (0.38, body.front(0.38, 1.3) - 0.08, 1.3), rot=(math.pi / 2, 0, 0), m=m["gold"]))
    # The duster: lapels and long tails.
    for s in (-1, 1):
        coat.append(patch(f"{p}Lapel{s}", t, (s * 0.4, body.front(s * 0.4, 1.15), 1.15), (0.12, 0.03, 0.62), m["leather"], bevel=0.01))
    coat.append(band(p + "CoatBack", (0, 0, 1.44), (0, 0, 0.9), 0.52, 0.36, m["leather"], n=2.8, thick=0.015, segs=24))
    for s in (-1, 1):
        coat.append(box(f"{p}Epaulette{s}", (0.26, 0.24, 0.06), (s * 0.5, 0.0, 1.47), bevel=0.03, m=m["leather_dark"]))
    parts += bz.bind("Spine", coat)
    parts += bz.bind("Hips", [blob(p + "Tails", (0, 0.06, 0.32), (0, 0.06, 0.86), [(0, 0.52, 0.38), (0.5, 0.5, 0.38), (1, 0.48, 0.37)], m["leather"],
                                   n=2.6, r0=0.04, r1=0.03, segs=22, mid=4),
                              box(p + "Buckle", (0.22, 0.05, 0.14), (0, -0.33, 0.96), bevel=0.02, m=m["gold"])]
                     + [box(f"{p}Holster{s}", (0.12, 0.16, 0.32), (s * 0.48, -0.06, 0.78), bevel=0.03, m=m["leather_dark"]) for s in (-1, 1)])
    parts += hips(p, m["black"], w=0.9, d=0.62, z0=0.7, belt=m["leather_dark"], buckle=m["gold"])
    for side in (1, -1):
        parts += arm(p, side, m, w=0.3, sleeve=m["leather"], sleeve_len="long", cuff=m["leather_dark"], hand=0.1, out=0.14, curl=0.8, seed=67)
        parts += leg(p, side, m, w=0.3, pants=m["black"], pants_len="long", foot="boot", shoe=m["leather_dark"], sole=m["dark"], tear=0)
        sx = "L" if side > 0 else "R"
        parts += bz.bind(f"Shin.{sx}", [torus(f"{p}Spur{sx}", 0.06, 0.016, (side * 0.18, 0.16, 0.08), rot=rad(0, 90, 0), m=m["gold"],
                                              major_segs=10, minor_segs=4)])
    return parts


def sheriff_accessories(m):
    p = "SA_"
    w = 0.68
    hat = ten_gallon(p + "Hat", m, top=2.3, brim_r=0.62, crown_r=0.3, brim_m=m["black"], band_m=m["gold"], z0=1.88)
    hat.append(star(p + "HatStar", 0.08, 0.03, (0, HEAD_Y - 0.31, 2.0), rot=(math.pi / 2, 0, 0), m=m["gold"]))
    stache = []
    for s in (-1, 1):
        stache.append(tube(f"{p}Stache{s}", [(0, face_y(w, 1.52) - 0.04, 1.53), (s * 0.12, face_y(w, 1.52) - 0.03, 1.52),
                                             (s * 0.22, face_y(w, 1.52) + 0.02, 1.58), (s * 0.25, face_y(w, 1.52) + 0.05, 1.66)],
                           0.035, m=m["beard"], segs=8, radius_end=0.012))
    acc = {
        "Acc_Sheriff_Hat": bz.bind("Head", hat),
        "Acc_Sheriff_Stache": bz.bind("Head", stache),
        "Acc_Sheriff_Revolver": bz.bind("ForeArm.R", six_shooter(p + "Gun", m, (-0.6, -0.02, 0.56), scale=1.8)),
    }
    acc.update(faces("Sheriff", m, w, ("Snarl", "Grin"), tongue=m["red"]))
    return acc


# ---------------------------------------------------------------------------
# Clips
# ---------------------------------------------------------------------------

def draw(rig, name="Draw", heavy=False):
    """Quick-draw: settles into a wide gunslinger crouch with the gun hand
    twitching at the hip, then snaps the arm out level and fires at frame 22
    (0.92 s, the windup); holds the aim, then recovers."""
    r = ready(heavy=heavy, hands=False)
    low = 0.16 if heavy else 0.12
    set_ = dict(r, **{"Hips": (6, 0, 0), "Spine": (8, 0, -8), "Head": (-6, 0, 8), "hips": (0, 0, -low),
                      **feet(0.26, 0.08, -0.08), **arms(-30, -30, 12, -24, spread=22)})
    twitch = dict(set_, **arms(-30, -30, 16, -32, spread=26))
    aim = dict(set_, **{"Spine": (4, 0, 12), "Head": (-4, 0, 6), **arms(-34, -34, -92, -2, spread=-6)})
    kick = dict(aim, **arms(-34, -34, -104, -10, spread=-6))
    return keyed(rig, name, [(0, r), (6, set_, "out"), (11, twitch), (15, set_), (19, twitch), (22, aim, "snap"), (24, kick), (28, aim),
                             (36, r)], release=round(22 / FPS, 4))


def gulch_clips(rig):
    """gulch_zombies.glb: Cowpoke (Swagger, Draw), Prospector (Walk = trudge,
    Dig), Sheriff (style "Heavy": stomp, charge, slam, roar, throw, Draw_Heavy)."""
    return [idle(rig), gait(rig, "Walk", trudge()), gait(rig, "Swagger", swagger()), gait(rig, "Run", zombie_anim.flail_sprint()),
            gait(rig, "Shamble", shamble()), draw(rig), crouch(rig, "Dig", depth=1.3),
            idle(rig, "Idle_Heavy", heavy=True), gait(rig, "Walk_Heavy", stomp()), gait(rig, "Run_Heavy", charge()),
            attack(rig), attack_heavy(rig), throw(rig), roar(rig), draw(rig, "Draw_Heavy", heavy=True),
            stagger(rig), hit_head(rig), *deaths(rig), emerge(rig),
            stagger(rig, "Stagger_Heavy", heavy=True), emerge(rig, "Emerge_Heavy", heavy=True)]


def build():
    scene = reset_scene()
    scene.render.fps = bz.FPS
    m = materials()
    armature = bz.build_armature()
    meshes = [
        bz.skin("Outfit_Cowpoke", cowpoke(m), armature),
        bz.skin("Outfit_Prospector", prospector(m), armature),
        bz.skin("Outfit_Sheriff", sheriff(m), armature),
    ]
    accessories = {}
    accessories.update(cowpoke_accessories(m))
    accessories.update(prospector_accessories(m))
    accessories.update(sheriff_accessories(m))
    for name, parts in accessories.items():
        meshes.append(bz.skin(name, parts, armature))
    zombie_anim.bake(armature, gulch_clips, "gulch_zombies")
    bz.save_zombie("gulch_zombies", [armature] + meshes)


if __name__ == "__main__":
    build()
