"""Fright Fair zombies (World 11, Ghost Train): the shared rig (build_zombie.py),
three outfits.

    Outfit_Ghost       Bedsheet Ghost: a zombie under a tintable bedsheet
                       ("Shirt"): a hooded sheet over the head with two cut eye
                       holes (the glowing eyes show through), a draped sheet
                       to the knees with a ragged hem, sheet sleeves, green hands
                       and striped socks; a little bow tie (Acc_Ghost_Bow) and a
                       chain with a padlock (Acc_Ghost_Chain)
    Outfit_Pumpkin     Pumpkin Head: a farmhand in a tintable plaid shirt
                       ("Shirt") and denim overalls, straw poking from the cuffs,
                       boots, and a carved jack-o'-lantern for a head (its face
                       glows); a straw hat (Acc_Pumpkin_Hat) and the lit pumpkin
                       bomb it throws (Acc_Pumpkin_Bomb, shown by the game
                       during the wind-up)
    Outfit_Ringmaster  Ringmaster Rictus (the alpha): a towering ringmaster with a
                       bone-white skull face, a red tailcoat ("Shirt") with gold
                       buttons and black lapels, a white shirt front, black
                       trousers and boots; a tall purple top hat with a
                       green-glowing band (Acc_Ringmaster_Hat), a skull-topped cane
                       (Acc_Ringmaster_Cane) and a curled moustache
                       (Acc_Ringmaster_Moustache)

Faces: two presets each for the Ghost and the Ringmaster (Face_<Outfit>_<Preset>);
the Pumpkin's face is carved into its head.

Clips (fright_clips below): the shared set, the Ghost's glide ("_Ghost"), the
Pumpkin Head's Throw_Bottle (lights the fuse, cocks back, hurls at frame 21),
the Ringmaster's stomp, slam and roar ("_Heavy"), and Roar / Throw for tells.

    python art/blender/build_fright_zombies.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fright_common import FRIGHT  # noqa: E402
from wla_common import *  # noqa: F401,F403,E402
import build_zombie as bz  # noqa: E402
import zombie_anim  # noqa: E402
from build_city_zombies_b import throw_bottle  # noqa: E402
from zombie_anim import (attack, attack_heavy, deaths, emerge, flail_sprint, gait, glide, hit_head, idle, roar, shamble,  # noqa: E402
                         stagger, stomp, throw)
from zombie_kit import (HEAD_Y, SPARK_EYE, arm, band, base_materials, blob, cap_crown, face_y, faces, head, head_band,  # noqa: E402
                        hips, leg, neck, patch, tear_fn, torso)


def materials():
    m = base_materials("fright", skin="#9ccf6a", skin_dark="#679a44", dark="#1c1428", white="#f6f1e6", eye=(SPARK_EYE, 3.0))
    m.update(
        shirt=mat("Shirt", "#f2ecf6", rough=0.7),
        sheet_dark=mat("FrightZSheetDark", "#cfc4dc", rough=0.75),
        stripe=mat("FrightZStripe", FRIGHT["Purple"], rough=0.6),
        stripe_b=mat("FrightZStripeB", FRIGHT["Orange"], rough=0.6),
        denim=mat("FrightZDenim", "#3f5a8a", rough=0.7),
        denim_dark=mat("FrightZDenimDark", "#2c4068", rough=0.7),
        straw=mat("FrightZStraw", FRIGHT["Hay"], rough=0.9),
        boot=mat("FrightZBoot", "#4a2e26", rough=0.7),
        brass=mat("FrightZBrass", FRIGHT["Gold"], rough=0.35, metal=0.5),
        pumpkin=mat("FrightZPumpkin", FRIGHT["Pumpkin"], rough=0.55),
        pumpkin_dark=mat("FrightZPumpkinDark", FRIGHT["OrangeDark"], rough=0.6),
        stem=mat("FrightZStem", FRIGHT["Stem"], rough=0.8),
        carve=mat("FrightZCarve", "#ffcf5a", rough=0.4, emit=3.0),
        bone=mat("FrightZBone", FRIGHT["Bone"], rough=0.5),
        red=mat("FrightZRed", FRIGHT["Crimson"], rough=0.5),
        black=mat("FrightZBlack", "#1a1420", rough=0.55),
        green=mat("FrightZGreen", "#7dff6a", rough=0.4, emit=3.0),
        chain=mat("FrightZChain", "#8a8698", rough=0.35, metal=0.7),
    )
    return m


# ---------------------------------------------------------------------------
# Bedsheet Ghost
# ---------------------------------------------------------------------------

def ghost(m):
    p = "G_"
    w = 0.6
    sheet = m["shirt"]
    # The head is the hooded sheet itself (no ears, no nose, no marks).
    parts = head(p, m, w, ears=False, nose=False, skin=sheet, dark=m["sheet_dark"], marks=False)
    # A twisted tip on top and two cut eye holes the glowing eyes peer through.
    parts += bz.bind("Head", [sphere(p + "Tip", 0.08, (0.03, HEAD_Y + 0.05, 1.98), scale=(1, 1, 1.4), m=sheet, segs=8, rings=5)] +
                     [sphere(f"{p}EyeHole{s}", 0.1, (s * 0.135, face_y(w, 1.63) + 0.025, 1.63), scale=(1.0, 0.35, 1.35), m=m["dark"], segs=12, rings=7)
                      for s in (-1, 1)])
    tor, body = torso(p, sheet, w=0.82, d=0.6, z0=0.86, z1=1.42, waist=0.92, belly=0.06, hunch=0.04, n=2.4)
    parts += tor
    parts += neck(p, sheet, 0.3)
    # The drape: a flared, ragged sheet skirt from the hips to the knees.
    parts += bz.bind("Hips", [band(p + "Drape", (0, 0.0, 0.98), (0, 0.02, 0.42), 0.46, 0.36, sheet, n=2.4, thick=0.03, flare=0.12, segs=26,
                                   tear=tear_fn(26, 7, count=6, depth=0.09, width=1.8))])
    parts += hips(p, sheet, w=0.74, d=0.56)
    for side in (1, -1):
        parts += arm(p, side, m, w=0.19, sleeve=sheet, sleeve_len="long", cuff=m["sheet_dark"], seed=61, sleeve_tear=2)
        parts += leg(p, side, m, w=0.15, pants=None, pants_len="shorts", foot="shoe", shoe=m["black"], sole=m["white"],
                     sock=m["stripe"] if side > 0 else m["stripe_b"], tear=0)
    return parts


def ghost_accessories(m):
    p = "GA_"
    bow = [box(p + "BowL", (0.12, 0.05, 0.09), (-0.07, -0.33, 1.4), rot=(0, 0, 0.3), bevel=0.02, m=m["stripe_b"]),
           box(p + "BowR", (0.12, 0.05, 0.09), (0.07, -0.33, 1.4), rot=(0, 0, -0.3), bevel=0.02, m=m["stripe_b"]),
           sphere(p + "Knot", 0.035, (0, -0.35, 1.4), m=m["stripe"], segs=8, rings=5)]
    chain = []
    for k in range(7):
        a = -0.5 + k * 0.17
        chain.append(torus(f"{p}Link{k}", 0.045, 0.012, (math.sin(a) * 0.46, -math.cos(a) * 0.33, 1.02 - 0.03 * math.sin(k)), rot=(math.pi / 2, k * 0.8, a),
                           m=m["chain"], major_segs=8, minor_segs=4))
    chain += [box(p + "Lock", (0.12, 0.06, 0.14), (0.3, -0.36, 0.86), bevel=0.02, m=m["brass"]),
              torus(p + "Shackle", 0.04, 0.012, (0.3, -0.36, 0.95), rot=(math.pi / 2, 0, 0), m=m["chain"], major_segs=8, minor_segs=4)]
    acc = {
        "Acc_Ghost_Bow": bz.bind("Spine", bow),
        "Acc_Ghost_Chain": bz.bind("Hips", chain),
    }
    acc.update(faces("Ghost", m, 0.6, ("Gape", "Grin"), tongue=m["dark"], lid=m["shirt"], brow=m["sheet_dark"], scale=1.2))
    return acc


# ---------------------------------------------------------------------------
# Pumpkin Head
# ---------------------------------------------------------------------------

def pumpkin_head(prefix, m, centre, r, lit=True, seed=1):
    """A ribbed carved pumpkin (eight lobes) centred on `centre`, its glowing
    face toward -Y."""
    rng = random.Random(seed)
    x, y, z = centre
    p = []
    for k in range(8):
        a = math.tau * k / 8
        p.append(sphere(f"{prefix}Lobe{k}", r * 0.62, (x + math.cos(a) * r * 0.42, y + math.sin(a) * r * 0.42, z), scale=(1.0, 1.0, 1.0),
                        m=m["pumpkin"] if k % 2 else m["pumpkin_dark"], segs=12, rings=8))
    p.append(sphere(prefix + "Core", r * 0.82, (x, y, z), scale=(1, 1, 0.92), m=m["pumpkin"], segs=14, rings=9))
    p.append(tube(prefix + "Stem", [(x, y, z + r * 0.75), (x + 0.02, y, z + r * 1.05), (x + r * 0.22 * rng.uniform(0.7, 1.0), y + 0.02, z + r * 1.18)],
                  r * 0.11, m=m["stem"], segs=6, radius_end=r * 0.05))
    if lit:
        fy = y - r * 0.9
        g = m["carve"]
        for s in (-1, 1):
            p.append(prism(f"{prefix}Eye{s}", [(-r * 0.17, 0), (r * 0.17, 0), (0, r * 0.28)], 0.06, (x + s * r * 0.33, fy, z + r * 0.12), m=g))
        p.append(prism(prefix + "Nose", [(-r * 0.08, 0), (r * 0.08, 0), (0, r * 0.15)], 0.06, (x, fy, z - r * 0.06), m=g))
        mouth = []
        for i in range(11):
            t = i / 10
            mouth.append(((t - 0.5) * r * 1.15, -r * 0.3 - math.sin(t * math.pi) * r * 0.2 + (0.07 * r if i % 2 else 0.0)))
        lower = [(px, pz - r * 0.15 - (0.0 if i % 2 else 0.05 * r)) for i, (px, pz) in enumerate(mouth)]
        p.append(prism(prefix + "Mouth", mouth + list(reversed(lower)), 0.06, (x, fy, z), m=g))
    return p


def pumpkin(m):
    p = "P_"
    w = 0.6
    parts = bz.bind("Head", pumpkin_head(p + "Head", m, (0, HEAD_Y - 0.02, 1.66), 0.36, seed=3))
    tor, body = torso(p, m["shirt"], w=0.72, d=0.5, z0=0.88, belly=0.08, hunch=0.06, n=2.8, hem=m["shirt"])
    parts += tor
    parts += neck(p, m["straw"], 0.24)
    t = tor[0]
    # Overall bib and straps over the plaid shirt, a patch pocket.
    parts += bz.bind("Spine", [
        patch(p + "Bib", t, (0, body.front(0, 1.05), 1.05), (0.38, 0.03, 0.34), m["denim"], bevel=0.02),
        patch(p + "Pocket", t, (0.05, body.front(0.05, 1.08) - 0.02, 1.08), (0.16, 0.02, 0.12), m["denim_dark"], bevel=0.01),
        patch(p + "StrapL", t, (0.15, body.front(0.15, 1.3), 1.3), (0.07, 0.03, 0.34), m["denim"], bevel=0.01),
        patch(p + "StrapR", t, (-0.15, body.front(-0.15, 1.3), 1.3), (0.07, 0.03, 0.34), m["denim"], bevel=0.01),
        sphere(p + "ButtonL", 0.03, (0.15, body.front(0.15, 1.2) - 0.03, 1.2), m=m["brass"], segs=6, rings=4),
        sphere(p + "ButtonR", 0.03, (-0.15, body.front(-0.15, 1.2) - 0.03, 1.2), m=m["brass"], segs=6, rings=4),
    ] + [patch(f"{p}Plaid{i}", t, (x, body.front(x, 1.25), 1.25), (0.025, 0.02, 0.4), m["red"], bevel=0.004)
         for i, x in enumerate((-0.3, 0.3))] + [
        cyl(f"{p}Straw{i}", 0.012, 0.16, (math.cos(i) * 0.12, 0.05 + math.sin(i) * 0.08, 1.52), rot=(0.4 * math.sin(i * 2), 0.4 * math.cos(i * 3), 0),
            segs=3, bevel=0.0, m=m["straw"]) for i in range(7)])
    parts += hips(p, m["denim"], w=0.66, d=0.48, belt=m["denim_dark"])
    for side in (1, -1):
        parts += arm(p, side, m, w=0.18, sleeve=m["shirt"], sleeve_len="long", cuff=m["straw"], seed=63, hand=0.02)
        parts += leg(p, side, m, w=0.2, pants=m["denim"], pants_len="long", hem=m["denim_dark"], foot="boot", shoe=m["boot"], sole=m["dark"], tear=1)
    return parts


def pumpkin_accessories(m):
    p = "PA_"
    hat = [cyl(p + "Brim", 0.46, 0.03, (0, HEAD_Y - 0.02, 1.98), rot=(0.12, 0.05, 0), segs=20, bevel=0.01, m=m["straw"]),
           cyl(p + "Crown", 0.24, 0.2, (0.0, HEAD_Y - 0.0, 2.08), rot=(0.12, 0.05, 0), segs=16, bevel=0.03, m=m["straw"], radius_top=0.2),
           cyl(p + "Band", 0.245, 0.05, (0.0, HEAD_Y - 0.01, 2.02), rot=(0.12, 0.05, 0), segs=16, bevel=0.0, m=m["red"])]
    bomb = pumpkin_head(p + "Bomb", m, (-0.44, -0.12, 0.42), 0.17, seed=9)
    bomb += [tube(p + "Fuse", [(-0.44, -0.12, 0.6), (-0.42, -0.1, 0.68), (-0.38, -0.12, 0.72)], 0.012, m=m["black"], segs=4),
             sphere(p + "Spark", 0.035, (-0.37, -0.12, 0.73), m=m["green"], segs=6, rings=4)]
    acc = {
        "Acc_Pumpkin_Hat": bz.bind("Head", hat),
        "Acc_Pumpkin_Bomb": bz.bind("ForeArm.R", bomb),
    }
    return acc


# ---------------------------------------------------------------------------
# Ringmaster Rictus (the alpha)
# ---------------------------------------------------------------------------

def ringmaster(m):
    p = "R_"
    w = 0.62
    parts = head(p, m, w, ears=False, marks=False)
    tor, body = torso(p, m["shirt"], w=0.94, d=0.6, z0=0.84, z1=1.48, waist=0.78, belly=0.0, hunch=0.08, chest=1.08, n=2.8, hem=m["shirt"])
    parts += tor
    parts += neck(p, m["skin"], 0.28, z1=1.48)
    t = tor[0]
    coat = [patch(p + "ShirtFront", t, (0, body.front(0, 1.22), 1.22), (0.26, 0.03, 0.46), m["white"], bevel=0.015),
            patch(p + "LapelL", t, (0.17, body.front(0.17, 1.3), 1.3), (0.1, 0.035, 0.36), m["black"], rot=(0, 0.25, 0), bevel=0.015),
            patch(p + "LapelR", t, (-0.17, body.front(-0.17, 1.3), 1.3), (0.1, 0.035, 0.36), m["black"], rot=(0, -0.25, 0), bevel=0.015),
            box(p + "BowL", (0.14, 0.06, 0.1), (-0.08, body.front(0, 1.44) - 0.06, 1.45), rot=(0, 0, 0.3), bevel=0.02, m=m["black"]),
            box(p + "BowR", (0.14, 0.06, 0.1), (0.08, body.front(0, 1.44) - 0.06, 1.45), rot=(0, 0, -0.3), bevel=0.02, m=m["black"])]
    for i in range(3):
        z = 1.2 - i * 0.13
        for s in (-1, 1):
            coat.append(sphere(f"{p}Button{i}{s}", 0.035, (s * 0.25, body.front(s * 0.25, z) - 0.015, z), m=m["brass"], segs=8, rings=5))
    for s in (-1, 1):
        coat += [box(f"{p}Epaulette{s}", (0.24, 0.22, 0.06), (s * 0.48, 0.0, 1.47), bevel=0.03, m=m["brass"])]
        coat += [cyl(f"{p}Fringe{s}{k}", 0.015, 0.1, (s * (0.38 + 0.05 * k), -0.1, 1.4), segs=4, bevel=0.0, m=m["brass"]) for k in range(5)]
    parts += bz.bind("Spine", coat)
    # Long tails behind.
    parts += bz.bind("Hips", [blob(p + "TailL", (0.13, 0.22, 0.32), (0.13, 0.12, 0.88), [(0, 0.14, 0.05), (1, 0.2, 0.08)], m["shirt"], n=2.4, r0=0.04,
                                   r1=0.02, segs=14, mid=3),
                              blob(p + "TailR", (-0.13, 0.22, 0.32), (-0.13, 0.12, 0.88), [(0, 0.14, 0.05), (1, 0.2, 0.08)], m["shirt"], n=2.4, r0=0.04,
                                   r1=0.02, segs=14, mid=3)])
    parts += hips(p, m["black"], w=0.8, d=0.56, z0=0.7, belt=m["red"], buckle=m["brass"])
    # Skull-face paint: dark sockets round the eyes and a grin line.
    parts += bz.bind("Head", [sphere(f"{p}Socket{s}", 0.11, (s * 0.13, face_y(w, 1.63) + 0.02, 1.63), scale=(1.1, 0.4, 1.0), m=m["dark"], segs=10, rings=6)
                              for s in (-1, 1)] +
                     [box(f"{p}Stitch{k}", (0.012, 0.02, 0.08), (-0.12 + k * 0.04, face_y(w, 1.44) - 0.005, 1.44), bevel=0.0, m=m["dark"]) for k in range(7)])
    for side in (1, -1):
        parts += arm(p, side, m, w=0.26, sleeve=m["shirt"], sleeve_len="long", cuff=m["brass"], glove=m["white"], hand=0.08, out=0.1, curl=0.7, seed=67)
        parts += leg(p, side, m, w=0.24, pants=m["black"], pants_len="long", foot="boot", shoe=m["black"], sole=m["dark"], tear=0)
    return parts


def ringmaster_accessories(m):
    p = "RA_"
    w = 0.62
    hat = [cap_crown(p + "Crown", w, m["black"], rim=1.76, top=1.98, off=0.04),
           cyl(p + "Brim", 0.44, 0.04, (0, HEAD_Y + 0.02, 1.86), segs=24, bevel=0.015, m=m["black"]),
           cyl(p + "Tall", 0.27, 0.7, (0, HEAD_Y + 0.02, 2.24), segs=20, bevel=0.03, m=m["stripe"], radius_top=0.31),
           cyl(p + "Band", 0.285, 0.14, (0, HEAD_Y + 0.02, 1.97), segs=20, bevel=0.0, m=m["green"]),
           cyl(p + "Top", 0.31, 0.05, (0, HEAD_Y + 0.02, 2.59), segs=20, bevel=0.015, m=m["red"]),
           tube(p + "Feather", [(0.24, HEAD_Y + 0.1, 1.98), (0.32, HEAD_Y + 0.15, 2.3), (0.26, HEAD_Y + 0.25, 2.6)], 0.035, m=m["red"], segs=6, radius_end=0.01)]
    cane = [cyl(p + "Cane", 0.03, 1.15, (-0.5, -0.22, 0.05), rot=rad(14, 0, 0), segs=8, bevel=0.0, m=m["black"]),
            sphere(p + "Knob", 0.08, (-0.5, -0.08, 0.6), scale=(1, 0.85, 1.05), m=m["bone"], segs=10, rings=7),
            cyl(p + "Ferrule", 0.035, 0.08, (-0.5, -0.36, -0.5), rot=rad(14, 0, 0), segs=8, bevel=0.0, m=m["brass"])]
    stache = [tube(f"{p}Stache{s}", [(0, face_y(w, 1.49) - 0.02, 1.5), (s * 0.12, face_y(w, 1.49) - 0.0, 1.48), (s * 0.2, face_y(w, 1.49) + 0.04, 1.54),
                                     (s * 0.17, face_y(w, 1.49) + 0.04, 1.58)], 0.022, m=m["black"], segs=6, radius_end=0.008) for s in (-1, 1)]
    acc = {
        "Acc_Ringmaster_Hat": bz.bind("Head", hat),
        "Acc_Ringmaster_Cane": bz.bind("ForeArm.R", cane),
        "Acc_Ringmaster_Moustache": bz.bind("Head", stache),
    }
    acc.update(faces("Ringmaster", m, w, ("Grin", "Snarl"), tongue=m["red"]))
    return acc


def fright_clips(rig):
    """fright_zombies.glb: Ghost (glide "_Ghost"), Pumpkin Head (Walk, Throw_Bottle),
    Ringmaster (style "Heavy": stomp, slam, roar)."""
    return [idle(rig), gait(rig, "Walk", shamble()), gait(rig, "Run", flail_sprint()), gait(rig, "Run_Ghost", glide()), gait(rig, "Walk_Ghost", glide()),
            idle(rig, "Idle_Heavy", heavy=True), gait(rig, "Walk_Heavy", stomp()), attack(rig), attack_heavy(rig),
            throw(rig), throw_bottle(rig), roar(rig), stagger(rig), hit_head(rig), *deaths(rig), emerge(rig),
            stagger(rig, "Stagger_Heavy", heavy=True), emerge(rig, "Emerge_Heavy", heavy=True)]


def build():
    scene = reset_scene()
    scene.render.fps = bz.FPS
    m = materials()
    armature = bz.build_armature()
    meshes = [
        bz.skin("Outfit_Ghost", ghost(m), armature),
        bz.skin("Outfit_Pumpkin", pumpkin(m), armature),
        bz.skin("Outfit_Ringmaster", ringmaster(m), armature),
    ]
    accessories = {}
    accessories.update(ghost_accessories(m))
    accessories.update(pumpkin_accessories(m))
    accessories.update(ringmaster_accessories(m))
    for name, parts in accessories.items():
        meshes.append(bz.skin(name, parts, armature))
    zombie_anim.bake(armature, fright_clips, "fright_zombies")
    save_zombie_glb("fright_zombies", [armature] + meshes)


def save_zombie_glb(name, export_objects):
    """build_zombie.save_zombie without the .blend: this script is the source."""
    bpy.context.view_layer.update()
    for ob in bpy.context.scene.objects:
        ob.select_set(ob in export_objects)
    path = os.path.join(MODELS_DIR, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_apply=False, export_yup=True, export_materials="EXPORT",
        export_tangents=False, export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
        export_force_sampling=True, export_optimize_animation_size=False, export_texcoords=True,
        export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True)
    tris = sum(len(o.data.polygons) for o in export_objects if o.type == "MESH")
    print(f"[wla] {name}: {len(export_objects)} export objects, ~{tris} faces -> {os.path.relpath(path)}")


if __name__ == "__main__":
    build()
