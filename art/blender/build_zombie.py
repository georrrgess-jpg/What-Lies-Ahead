"""Boardwalk zombie: one rig, three outfits, the shared animation clips.

    Outfit_Tourist     wide Tourist Shambler (hibiscus shirt, cargo shorts)
    Outfit_Lifeguard   lean Lifeguard Runner (tank top, red shorts, red cap)
    Outfit_Bruiser     hulking Boardwalk Bruiser (vest, board shorts, huge fists)

Optional accessory meshes (Acc_<Outfit>_<Name>) are switched on per zombie by
the game, using the accessory slots in each EnemyData resource, and each outfit
has several faces (Face_<Outfit>_<Preset>), one of which the game shows per
zombie, so one rig gives many different-looking zombies.

The Tourist and the Lifeguard appear in every world's waves, so this script also
builds their world outfits (zombie_<world>.glb, same rig, outfits and clips);
EnemyData.world_outfits picks the right one for the current level.

All meshes are skinned to the same armature and share its clips, authored in
zombie_anim.py (boardwalk_clips): Idle, Walk (shamble), Run (sprint), the
"_Heavy" set for the Bruiser, attacks, Roar, Stagger, Hit_Head, Die_* and Emerge.

The body is built from chunky rigid parts (zombie_kit.py), each bound to a
single bone (toy style, no deforming joints). The character faces -Y in Blender (+Z in Godot).
Parts are modelled with ordinary flat materials; skin() bakes them into the
vertices of one shared material (ZombieBody, art/shaders/zombie_body.gdshader),
with baked ambient occlusion, so each mesh is one surface. Parts whose material
is named "Shirt", "Skin" or "SkinDark" are tinted per zombie by the game.
art/blender/zombie_audit.py checks every model for parts that intersect.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from wla_common import HERE, MODELS_DIR  # noqa: E402
import numpy as np  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402
from zombie_kit import (HEAD_Y, head_band, arm, band, base_materials, blob, decal, face_y, faces, head, hips, leg, neck,  # noqa: E402
                        patch, skull, tear_fn, torso, wrap)
from zombie_kit import hair as hair_parts  # noqa: E402
from zombie_kit import cap_crown, hair_top  # noqa: E402
import zombie_anim  # noqa: E402

FPS = 24

BONES = [
    # name, head, tail, parent
    ("Hips", (0, 0, 0.78), (0, 0, 0.98), None),
    ("Spine", (0, 0, 0.98), (0, 0, 1.3), "Hips"),
    ("Head", (0, 0, 1.32), (0, 0, 1.8), "Spine"),
    ("UpperArm.L", (0.36, 0, 1.26), (0.41, 0, 0.98), "Spine"),
    ("ForeArm.L", (0.41, 0, 0.98), (0.43, 0, 0.62), "UpperArm.L"),
    ("UpperArm.R", (-0.36, 0, 1.26), (-0.41, 0, 0.98), "Spine"),
    ("ForeArm.R", (-0.41, 0, 0.98), (-0.43, 0, 0.62), "UpperArm.R"),
    ("Thigh.L", (0.16, 0, 0.78), (0.16, 0, 0.45), "Hips"),
    ("Shin.L", (0.16, 0, 0.45), (0.16, 0, 0.06), "Thigh.L"),
    ("Thigh.R", (-0.16, 0, 0.78), (-0.16, 0, 0.45), "Hips"),
    ("Shin.R", (-0.16, 0, 0.45), (-0.16, 0, 0.06), "Thigh.R"),
]


def build_armature():
    _occluders.clear()
    data = bpy.data.armatures.new("ZombieRig")
    ob = bpy.data.objects.new("Armature", data)
    export_collection().objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, tail, parent in BONES:
        eb = data.edit_bones.new(name)
        eb.head, eb.tail = head, tail
        eb.roll = 0.0
        if parent:
            eb.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return ob


def bind(bone, parts):
    """Tag parts with the bone they follow."""
    if not isinstance(parts, (list, tuple)):
        parts = [parts]
    for p in parts:
        p["bone"] = bone
    return list(parts)


# One material for every opaque part: skin() bakes each part's flat material
# into its vertices (see art/shaders/zombie_body.gdshader), so an outfit, a
# face or an accessory is a single surface (one draw call) however many
# colours it has. Glass stays a separate alpha-blended surface.
BODY_MATERIAL = "ZombieBody"
# Materials the game tints per zombie: their vertices carry a tint slot.
TINT_SLOTS = {"Skin": 1, "SkinDark": 2, "Shirt": 3}
EMIT_RANGE = 8.0
# Baked ambient occlusion: `AO_RAYS` rays over the hemisphere of each vertex,
# reaching AO_REACH metres, darkening by up to AO_STRENGTH, plus a slight
# gradient from head (1) to feet (1 - AO_GROUND).
AO_REACH = 0.3
AO_STRENGTH = 0.5
AO_GROUND = 0.1
AO_RAYS = 14
_occluders = {}


def _srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1.0 / 2.4) - 0.055


def _finish(material):
    """(sRGB r, g, b, roughness, metallic, emission strength, tint slot) of a
    flat material, or None for glass."""
    bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    if bsdf.inputs["Alpha"].default_value < 0.999:
        return None
    c = bsdf.inputs["Base Color"].default_value
    return (_srgb(c[0]), _srgb(c[1]), _srgb(c[2]), bsdf.inputs["Roughness"].default_value, bsdf.inputs["Metallic"].default_value,
            bsdf.inputs["Emission Strength"].default_value, TINT_SLOTS.get(material.name, 0))


def _ao_rays():
    """Fixed directions over the upper hemisphere (z = the normal)."""
    out = []
    for i in range(AO_RAYS):
        z = 0.12 + 0.86 * (i + 0.5) / AO_RAYS
        a = i * 2.39996
        r = math.sqrt(1.0 - z * z)
        out.append((math.cos(a) * r, math.sin(a) * r, z))
    return out


def _occlusion(me, others=()):
    """Per-vertex ambient occlusion (1 = open) of `me` against itself and the
    BVH trees in `others`. Returns (values, this mesh's tree)."""
    cos = [v.co.copy() for v in me.vertices]
    tree = BVHTree.FromPolygons(cos, [tuple(p.vertices) for p in me.polygons])
    trees = (tree,) + tuple(others)
    rays = _ao_rays()
    out = np.ones(len(cos), dtype=np.float32)
    for i, v in enumerate(me.vertices):
        n = v.normal
        t = n.orthogonal().normalized()
        b = n.cross(t)
        origin = v.co + n * 0.012
        occ, buried = 0.0, 0
        for x, y, z in rays:
            d = t * x + b * y + n * z
            near = AO_REACH
            for tr in trees:
                hit = tr.ray_cast(origin, d, near)
                if hit[0] is not None:
                    near = hit[3]
            if near < AO_REACH:
                occ += (1.0 - near / AO_REACH) ** 2
                buried += near < 0.02
        # A vertex buried in another part says nothing about the visible
        # surface around it: keep it mid-grey instead of black.
        shade = 0.5 if buried > AO_RAYS * 0.6 else min(1.0, 1.6 * occ / AO_RAYS)
        ground = 1.0 - AO_GROUND * (1.0 - min(1.0, max(0.0, v.co.z / 1.6)))
        out[i] = (1.0 - AO_STRENGTH * shade) * ground
    return out, tree


def _bake_surface(name, me):
    """Move every flat material of `me` into per-vertex data (colour and baked
    occlusion, finish, emission, tint slot) under the one body material."""
    body = mat(BODY_MATERIAL, "#ffffff")
    plain = (1.0, 1.0, 1.0, 0.6, 0.0, 0.0, 0)
    old = list(me.materials) or [None]
    finishes = [_finish(m) if m else plain for m in old]
    glass = [m for m, f in zip(old, finishes) if f is None]
    table = np.array([f if f is not None else plain for f in finishes], dtype=np.float32)
    n_poly, n_loop = len(me.polygons), len(me.loops)
    mi = np.zeros(n_poly, dtype=np.int32)
    start = np.zeros(n_poly, dtype=np.int32)
    total = np.zeros(n_poly, dtype=np.int32)
    me.polygons.foreach_get("material_index", mi)
    mi = np.minimum(mi, len(old) - 1)
    me.polygons.foreach_get("loop_start", start)
    me.polygons.foreach_get("loop_total", total)
    order = np.argsort(start)
    loop_mat = np.repeat(mi[order], total[order])
    loop_vert = np.zeros(n_loop, dtype=np.int32)
    me.loops.foreach_get("vertex_index", loop_vert)
    # Faces and accessories are also shaded by the outfit they are worn on.
    owner = name.split("_")[1] if name.count("_") >= 2 else ""
    ao, tree = _occlusion(me, [_occluders[owner]] if owner in _occluders and not name.startswith("Outfit_") else [])
    if name.startswith("Outfit_"):
        _occluders[name[7:]] = tree
    per = table[loop_mat]
    for layer in list(me.uv_layers):
        me.uv_layers.remove(layer)
    for attr in list(me.color_attributes):
        me.color_attributes.remove(attr)
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    rgba = np.concatenate([per[:, :3], ao[loop_vert][:, None]], axis=1).astype(np.float32)
    col.data.foreach_set("color", rgba.ravel())
    me.color_attributes.active_color = col
    me.color_attributes.render_color_index = 0
    # glTF flips V on export, so store 1 - v.
    uv = me.uv_layers.new(name="UVMap")
    uv.data.foreach_set("uv", np.stack([per[:, 3], 1.0 - per[:, 4]], axis=1).astype(np.float32).ravel())
    uv2 = me.uv_layers.new(name="UV2")
    uv2.data.foreach_set("uv", np.stack([np.minimum(per[:, 5] / EMIT_RANGE, 1.0), 1.0 - per[:, 6] / 4.0], axis=1).astype(np.float32).ravel())
    new_index = np.array([0 if f is not None else 1 + glass.index(m) for m, f in zip(old, finishes)], dtype=np.int32)
    me.materials.clear()
    me.materials.append(body)
    for g in glass:
        me.materials.append(g)
    me.polygons.foreach_set("material_index", new_index[mi])
    me.update()


def skin(name, parts, armature):
    """Bake + join parts into one skinned mesh, each part weighted to its bone,
    with its materials baked into one surface (see _bake_surface)."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    target = bpy.data.objects.new(name, bpy.data.meshes.new(name))
    export_collection().objects.link(target)
    temps = []
    for ob in parts:
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        tmp = bpy.data.objects.new(ob.name + "_bake", me)
        export_collection().objects.link(tmp)
        tmp.matrix_world = ob.matrix_world.copy()
        vg = tmp.vertex_groups.new(name=ob["bone"])
        vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
        temps.append(tmp)
    bpy.context.view_layer.update()
    with bpy.context.temp_override(active_object=target, object=target,
                                   selected_objects=[target] + temps,
                                   selected_editable_objects=[target] + temps):
        bpy.ops.object.join()
    for p in target.data.polygons:
        p.use_smooth = True
    _bake_surface(name, target.data)
    mod = target.modifiers.new("Armature", "ARMATURE")
    mod.object = armature
    target.parent = armature
    return target


def save_zombie(name, export_objects):
    """Write art/blender/<name>.blend and art/models/<name>.glb with the clips
    and the per-vertex colours and finishes skin() baked."""
    bpy.context.view_layer.update()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, name + ".blend"), compress=True)
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
    return path


# ---------------------------------------------------------------------------
# Body (parts and faces come from zombie_kit.py)
# ---------------------------------------------------------------------------

# Builds shared by the Tourist Shambler (wide) and the Lifeguard Runner (lean),
# in every world.
BUILDS = {
    "wide": dict(head=0.62, chest=(0.7, 0.46), belly=0.05, arm=0.19, leg=0.21, hips=(0.64, 0.44)),
    "lean": dict(head=0.54, chest=(0.52, 0.36), belly=0.0, arm=0.15, leg=0.165, hips=(0.5, 0.37)),
}


def casual(p, m, build, top, top_m, pants_m, pants="shorts", sleeve="short", foot="shoe", shoe=None, sole=None, sock=None,
           lace=None, toe=None, hair=None, belt=None, buckle=None, tear=1, seed=1, cuff=None, hem=None, pants_hem=None, boot_h=0.3,
           sleeve_m=None, hair_style="fringe"):
    """A casual body (head, torso, hips, arms, legs) in one of the BUILDS.
    top: "tee", "tank", "hoodie", "sweater" or "jacket" (sleeves follow `sleeve`).
    Returns (parts, Body) so garments and prints can follow the torso."""
    b = BUILDS[build]
    w, d = b["chest"]
    parts = head(p, m, b["head"])
    if hair is not None:
        parts += hair_parts(p, b["head"], hair, hair_style, seed)
    z0 = 0.86 if top in ("tee", "hoodie", "sweater", "jacket") else 0.9
    tor, body = torso(p, top_m, w=w, d=d, z0=z0, belly=b["belly"], hem=hem or top_m, hem_tear=2 if tear else 0, seed=seed)
    parts += tor
    parts += neck(p, m["skin"], 0.26 if build == "wide" else 0.22)
    hw, hd = b["hips"]
    parts += hips(p, pants_m, w=hw, d=hd, belt=belt, buckle=buckle)
    long_sleeve = sleeve == "long"
    for side in (1, -1):
        parts += arm(p, side, m, w=b["arm"], sleeve=(sleeve_m or top_m) if sleeve != "none" else None, sleeve_len=sleeve,
                     cuff=cuff if (cuff is not None and (long_sleeve or side > 0)) else None,
                     sleeve_tear=tear, seed=seed + 2, nail=m["white"])
        parts += leg(p, side, m, w=b["leg"], pants=pants_m, pants_len=pants, hem=pants_hem, foot=foot, shoe=shoe, sole=sole, sock=sock,
                     lace=lace, toe=toe, tear=tear, seed=seed + 4, boot_h=boot_h)
    return parts, body


def chest_front(build, z=1.15):
    """Approximate Y of the chest surface (for straps, badges, accessories)."""
    return -BUILDS[build]["chest"][1] * 0.5 - 0.012


def tank_straps(p, m, build, top_m):
    """Bare shoulders: the tank top's straps and a skin neckline."""
    w, d = BUILDS[build]["chest"]
    return bind("Spine", [
        blob(p + "Neckline", (0, -0.005, 1.31), (0, 0.0, 1.45), [(0, w * 0.2, d * 0.42), (1, w * 0.25, d * 0.44)], m["skin"], n=2.6, r0=0.03, r1=0.04,
             segs=16, mid=2),
        box(p + "StrapL", (0.1, d + 0.03, 0.12), (w * 0.28, 0.01, 1.4), rot=rad(0, -12, 0), bevel=0.035, m=top_m),
        box(p + "StrapR", (0.1, d + 0.03, 0.12), (-w * 0.28, 0.01, 1.4), rot=rad(0, 12, 0), bevel=0.035, m=top_m),
    ])


def prints(p, body, target, m_petal, m_centre=None, seed=3, count=18, petals=5, radius=(0.06, 0.08), z=(0.92, 1.33), gap=50, off=0.024):
    """An all-over print (hibiscus flowers, dots, stars) laid on a shirt shell."""
    rng = random.Random(seed)
    out = []
    for i in range(count):
        a = math.radians(rng.uniform(gap * 0.5 + 8, 360 - gap * 0.5 - 8))
        zz = rng.uniform(*z)
        sa, sb, du, dv = body.section(zz)
        loc = (du + math.sin(a) * (sa + off), dv - math.cos(a) * (sb + off), zz)
        r = rng.uniform(*radius)
        out.append(decal(f"{p}Print{i}", target, loc, r, m_petal, petals=petals))
        if m_centre is not None:
            out.append(decal(f"{p}PrintC{i}", target, loc, r * 0.32, m_centre, offset=0.009, segs=10))
    return bind("Spine", out)


# --- Boardwalk Breakout ------------------------------------------------------

def boardwalk_materials():
    m = base_materials("boardwalk")
    m.update(
        shirt=mat("Shirt", "#ff4f9c", rough=0.65),
        shorts=mat("Shorts", "#c58a55", rough=0.75),
        pink=mat("Pink", "#ff3f9f", rough=0.55),
        red=mat("LifeguardRed", "#e8263a", rough=0.6),
        yellow=mat("Yellow", "#ffd93b", rough=0.55),
        teal=mat("Teal", "#1fb8a6", rough=0.65),
        board=mat("BoardShorts", "#14a3a0", rough=0.65),
        hair_red=mat("HairCurly", "#9b3b2a", rough=0.8),
        lens=mat("Lens", "#2a1f3d", rough=0.15, metal=0.3),
        lens_mirror=mat("LensMirror", "#ffb84a", rough=0.15, metal=0.6),
        camera_lens=mat("CameraLens", "#5fd9ff", rough=0.15, emit=0.4),
    )
    return m


def tourist(m):
    """Tourist Shambler: untucked hibiscus shirt over a tee, cargo shorts, socks
    and pink sneakers. Seven materials."""
    p = "T_"
    shirt, white, dark = m["shirt"], m["white"], m["dark"]
    parts, body = casual(p, m, "wide", "tee", white, m["shorts"], foot="shoe", shoe=m["pink"], sole=white, sock=white, lace=white,
                         hair=dark, belt=dark, buckle=white, cuff=m["pink"], seed=3, sleeve_m=shirt)
    # The open hibiscus shirt over a white tee.
    over = body.shell(p + "Shirt", shirt, 1.39, 0.83, off=0.024, gap=48, tear=tear_fn(24, 3, 2, 0.05), flare=0.02)
    parts += bind("Spine", [
        over,
        box(p + "CollarL", (0.17, 0.05, 0.13), (0.12, body.front(0.12, 1.38) - 0.01, 1.39), rot=rad(-35, 30, 0), bevel=0.02, m=shirt),
        box(p + "CollarR", (0.17, 0.05, 0.13), (-0.12, body.front(-0.12, 1.38) - 0.01, 1.39), rot=rad(-35, -30, 0), bevel=0.02, m=shirt),
    ])
    parts += prints(p, body, over, white, m["pink"], seed=3)
    for side, s in ((1, "L"), (-1, "R")):
        parts += bind(f"Thigh.{s}", [box(f"{p}Pocket{s}", (0.05, 0.16, 0.15), (side * 0.3, 0.0, 0.62), bevel=0.02, m=m["shorts"]),
                                     box(f"{p}PocketFlap{s}", (0.06, 0.17, 0.05), (side * 0.305, 0.0, 0.69), bevel=0.015, m=dark)])
    return parts


def tourist_accessories(m):
    p = "TA_"
    acc = {}
    acc["Acc_Tourist_Cap"] = bind("Head", [
        cap_crown(p + "Cap", 0.62, m["white"]),
        box(p + "CapBrim", (0.38, 0.28, 0.05), (0, HEAD_Y + 0.38, 1.75), rot=rad(-12, 0, 0), bevel=0.02, m=m["pink"]),
        head_band(p + "CapBand", 0.62, 1.805, 1.745, m["pink"], off=0.038),
        sphere(p + "CapButton", 0.045, (0, HEAD_Y + 0.02, 2.0), m=m["pink"], segs=8, rings=5),
    ])
    acc["Acc_Tourist_Bucket"] = bind("Head", [
        cyl(p + "BucketCrown", 0.31, 0.24, (0, HEAD_Y, 1.92), segs=20, bevel=0.06, m=m["teal"], radius_top=0.27),
        cyl(p + "BucketBrim", 0.47, 0.05, (0, HEAD_Y, 1.8), rot=rad(-6, 0, 0), segs=22, bevel=0.02, m=m["teal"], radius_top=0.41),
        cyl(p + "BucketBand", 0.315, 0.06, (0, HEAD_Y, 1.84), segs=20, bevel=0.015, m=m["pink"]),
    ])
    curls = []
    rng = random.Random(11)
    for i in range(16):
        a = math.tau * i / 16
        r = rng.uniform(0.075, 0.1)
        curls.append(sphere(f"{p}Curl{i}", r, (math.cos(a) * 0.28, HEAD_Y + math.sin(a) * 0.25 + 0.03, 1.82 + rng.uniform(-0.03, 0.04)),
                            m=m["hair_red"], segs=8, rings=6))
    for i in range(7):
        a = math.tau * i / 7
        curls.append(sphere(f"{p}Top{i}", 0.11, (math.cos(a) * 0.14, HEAD_Y + math.sin(a) * 0.13 + 0.04, 1.93), m=m["hair_red"], segs=8, rings=6))
    for side in (-1, 1):
        curls.append(sphere(f"{p}Side{side}", 0.1, (side * 0.33, HEAD_Y + 0.07, 1.56), scale=(0.7, 1.0, 1.6), m=m["hair_red"], segs=8, rings=6))
    acc["Acc_Tourist_Hair"] = bind("Head", curls)
    acc["Acc_Tourist_Shades"] = bind("Head", [
        box(p + "ShadeBar", (0.5, 0.04, 0.04), (0, HEAD_Y - 0.21, 1.93), rot=rad(-35, 0, 0), bevel=0.012, m=m["pink"]),
        sphere(p + "ShadeL", 0.09, (-0.13, HEAD_Y - 0.22, 1.91), scale=(1.2, 0.35, 0.8), rot=rad(-35, 0, 0), m=m["lens"], segs=10, rings=6),
        sphere(p + "ShadeR", 0.09, (0.13, HEAD_Y - 0.22, 1.91), scale=(1.2, 0.35, 0.8), rot=rad(-35, 0, 0), m=m["lens"], segs=10, rings=6),
    ])
    y = chest_front("wide")
    acc["Acc_Tourist_Camera"] = bind("Spine", [
        box(p + "CamBody", (0.22, 0.09, 0.14), (0.06, y - 0.05, 1.06), bevel=0.025, m=m["dark"]),
        cyl(p + "CamLens", 0.045, 0.07, (0.08, y - 0.11, 1.05), rot=rad(90, 0, 0), segs=12, bevel=0.01, m=m["camera_lens"]),
        box(p + "CamFlash", (0.05, 0.02, 0.03), (0.0, y - 0.1, 1.11), bevel=0.006, m=m["white"]),
        tube(p + "CamStrapL", [(-0.02, y - 0.03, 1.1), (-0.12, y - 0.01, 1.34), (-0.12, -0.05, 1.44)], 0.016, m=m["dark"], segs=6),
        tube(p + "CamStrapR", [(0.15, y - 0.03, 1.1), (0.14, y - 0.01, 1.34), (0.13, -0.05, 1.44)], 0.016, m=m["dark"], segs=6),
    ])
    # Inflatable swim ring round the waist (a yellow duck).
    acc["Acc_Tourist_Floatie"] = bind("Hips", [
        torus(p + "Ring", 0.42, 0.1, (0, 0, 0.92), m=m["yellow"], major_segs=28, minor_segs=10),
        sphere(p + "DuckHead", 0.11, (0.0, -0.53, 1.06), m=m["yellow"], segs=12, rings=8),
        sphere(p + "DuckBeak", 0.05, (0.0, -0.63, 1.04), scale=(1.3, 1.1, 0.6), m=m["pink"], segs=8, rings=5),
        sphere(p + "DuckEyeL", 0.02, (0.05, -0.61, 1.1), m=m["dark"], segs=6, rings=4),
        sphere(p + "DuckEyeR", 0.02, (-0.05, -0.61, 1.1), m=m["dark"], segs=6, rings=4),
    ])
    # Flower lei.
    lei = []
    for i in range(18):
        a = math.tau * i / 18
        lei.append(sphere(f"{p}Lei{i}", 0.042, (math.sin(a) * 0.21, -math.cos(a) * 0.18 - 0.03, 1.41 - 0.16 * max(0.0, math.cos(a)) ** 0.7),
                          m=m["pink"] if i % 3 else m["yellow"], segs=8, rings=5))
    acc["Acc_Tourist_Lei"] = bind("Spine", lei)
    return acc


def lifeguard(m):
    """Lifeguard Runner: tank top with the red cross, red shorts, flip-flops, red cap."""
    p = "L_"
    red, white = m["red"], m["white"]
    parts, body = casual(p, m, "lean", "tank", white, red, sleeve="none", foot="flipflop", shoe=m["yellow"], lace=m["yellow"], hair=m["dark"],
                         belt=white, cuff=red, seed=7, tear=1)
    parts += tank_straps(p, m, "lean", white)
    y = chest_front("lean")
    parts += bind("Head", [
        cap_crown(p + "Cap", 0.54, red, top=1.99),
        box(p + "CapBrim", (0.34, 0.26, 0.045), (0, HEAD_Y - 0.36, 1.77), rot=rad(10, 0, 0), bevel=0.02, m=red),
        box(p + "CapPatch", (0.2, 0.04, 0.13), (0, HEAD_Y - 0.27, 1.86), rot=rad(-18, 0, 0), bevel=0.015, m=white),
        box(p + "CapCrossH", (0.12, 0.03, 0.035), (0, HEAD_Y - 0.292, 1.865), rot=rad(-18, 0, 0), bevel=0.0, m=red),
        box(p + "CapCrossV", (0.035, 0.03, 0.1), (0, HEAD_Y - 0.292, 1.865), rot=rad(-18, 0, 0), bevel=0.0, m=red),
    ])
    parts += bind("Spine", [
        box(p + "CrossH", (0.19, 0.03, 0.06), (0, y - 0.004, 1.08), bevel=0.0, m=red),
        box(p + "CrossV", (0.06, 0.03, 0.19), (0, y - 0.004, 1.08), bevel=0.0, m=red),
        text(p + "Label", "LIFEGUARD", 0.062, 0.012, (0, y - 0.006, 1.25), m=red),
    ])
    for side, s in ((1, "L"), (-1, "R")):
        parts += bind(f"Thigh.{s}", [box(f"{p}Stripe{s}", (0.03, 0.09, 0.3), (side * 0.255, 0, 0.64), bevel=0.0, m=white)])
    return parts


def lifeguard_accessories(m):
    p = "LA_"
    red, white = m["red"], m["white"]
    y = chest_front("lean")
    return {
        "Acc_Lifeguard_Whistle": bind("Spine", [
            cyl(p + "Whistle", 0.035, 0.07, (0.1, y - 0.025, 1.3), rot=rad(0, 90, 0), segs=10, bevel=0.008, m=m["yellow"]),
            tube(p + "Cord", [(0.06, y - 0.015, 1.3), (-0.12, y - 0.005, 1.31), (-0.2, -0.05, 1.42)], 0.012, m=white, segs=5),
        ]),
        "Acc_Lifeguard_Shades": bind("Head", [
            box(p + "ShadeBar", (0.44, 0.04, 0.035), (0, HEAD_Y - 0.34, 1.82), rot=rad(14, 0, 0), bevel=0.01, m=white),
            sphere(p + "ShadeL", 0.08, (-0.11, HEAD_Y - 0.35, 1.815), scale=(1.25, 0.3, 0.75), rot=rad(14, 0, 0), m=m["lens_mirror"], segs=10, rings=6),
            sphere(p + "ShadeR", 0.08, (0.11, HEAD_Y - 0.35, 1.815), scale=(1.25, 0.3, 0.75), rot=rad(14, 0, 0), m=m["lens_mirror"], segs=10, rings=6),
        ]),
        "Acc_Lifeguard_Zinc": bind("Head", [
            sphere(p + "Zinc", 0.055, (0, face_y(0.54, 1.5) - 0.045, 1.5), scale=(1.2, 0.5, 0.8), m=white, segs=8, rings=5),
            sphere(p + "ZincL", 0.04, (0.14, face_y(0.54, 1.53) - 0.0, 1.53), scale=(1.4, 0.4, 0.5), m=white, segs=8, rings=5),
            sphere(p + "ZincR", 0.04, (-0.14, face_y(0.54, 1.53) - 0.0, 1.53), scale=(1.4, 0.4, 0.5), m=white, segs=8, rings=5),
        ]),
        "Acc_Lifeguard_Tube": bind("Spine", [
            box(p + "Tube", (0.16, 0.12, 0.78), (0.02, 0.25, 1.1), rot=rad(0, 32, 0), bevel=0.06, segs=3, m=red),
            box(p + "TubeText", (0.1, 0.13, 0.4), (0.02, 0.255, 1.1), rot=rad(0, 32, 0), bevel=0.02, m=white),
            tube(p + "TubeStrap", [(0.2, y + 0.02, 1.38), (0.16, 0.0, 1.44), (0.15, 0.2, 1.4)], 0.02, m=white, segs=5),
        ]),
        "Acc_Lifeguard_Towel": bind("Spine", [
            torus(p + "Towel", 0.15, 0.055, (0, -0.01, 1.375), rot=rad(28, 0, 0), m=m["yellow"], major_segs=18, minor_segs=7),
            box(p + "TowelEndL", (0.1, 0.05, 0.3), (0.1, y - 0.02, 1.24), rot=rad(4, 0, 6), bevel=0.02, m=m["yellow"]),
            box(p + "TowelEndR", (0.1, 0.05, 0.24), (-0.1, y - 0.02, 1.27), rot=rad(4, 0, -6), bevel=0.02, m=m["yellow"]),
            box(p + "TowelStripeL", (0.105, 0.055, 0.04), (0.1, y - 0.02, 1.15), rot=rad(4, 0, 6), bevel=0.01, m=red),
            box(p + "TowelStripeR", (0.105, 0.055, 0.04), (-0.1, y - 0.02, 1.2), rot=rad(4, 0, -6), bevel=0.01, m=red),
        ]),
    }


def bruiser(m):
    """Boardwalk Bruiser: hulking, slow, takes a beating. Bare chest under a
    tintable vest ("Shirt"), board shorts, huge fists."""
    p = "B_"
    vest, shorts, stripe, skin, sd = m["shirt"], m["board"], m["yellow"], m["skin"], m["skin_dark"]
    parts = head(p, m, 0.62)
    parts += hair_parts(p, 0.62, m["dark"], "flat", 4)
    tor, body = torso(p, skin, w=0.9, d=0.56, z0=0.9, z1=1.46, waist=0.9, belly=0.09, hunch=0.06, chest=1.04)
    parts += tor
    parts += neck(p, skin, 0.36, z1=1.46)
    pecs = []
    for side in (1, -1):
        pts = [(side * x, 0, 1.12 + 0.05 * math.sin(math.pi * x / 0.3)) for x in (0.03, 0.12, 0.21, 0.29)]
        pecs.append(tube(f"{p}Pec{side}", [(x, body.front(x, z) + 0.004, z) for x, _, z in pts], 0.014, m=sd, segs=6))
    parts += bind("Spine", pecs + [
        # Trapezius hump: the head sinks between the shoulders.
        blob(p + "Traps", (-0.36, 0.06, 1.42), (0.36, 0.06, 1.42), [(0, 0.06, 0.1), (0.3, 0.13, 0.12), (0.7, 0.13, 0.12), (1, 0.06, 0.1)], skin,
             n=2.4, r0=0.04, r1=0.04, segs=14, mid=6),
        sphere(p + "Navel", 0.03, (0, body.front(0, 1.0) + 0.012, 1.0), scale=(1, 0.5, 1.2), m=sd, segs=8, rings=5),
    ])
    # Open vest with shoulder straps and its name on the back.
    vest_ob = body.shell(p + "Vest", vest, 1.38, 0.93, off=0.024, gap=96, tear=tear_fn(24, 4, 2, 0.05))
    parts += bind("Spine", [vest_ob] + [box(f"{p}VestStrap{side}", (0.17, 0.62, 0.09), (side * 0.27, 0.03, 1.425), rot=rad(0, -side * 8, 0),
                                            bevel=0.035, m=vest) for side in (1, -1)]
                  + [text(p + "Label", "BEACH", 0.11, 0.02, (0, body.front(0, 1.22, back=True, off=0.03), 1.22), rot=(0, 0, math.pi), m=m["white"])])
    parts += hips(p, shorts, w=0.78, d=0.52, z1=1.0, belt=stripe, belt_z=0.965)
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        parts += arm(p, side, m, w=0.25, out=0.1, hand=0.075, nail=m["white"], cuff=m["pink"] if side < 0 else None, fingers=3, curl=0.7)
        parts += leg(p, side, m, w=0.25, pants=shorts, pants_len="shorts", foot="flipflop", shoe=stripe, lace=m["pink"], tear=1, seed=9)
        parts += bind(f"Thigh.{s}", [box(f"{p}Stripe{s}", (0.04, 0.12, 0.32), (side * 0.33, 0, 0.64), bevel=0.0, m=stripe)])
        # Popeye forearms.
        parts += bind(f"ForeArm.{s}", [blob(f"{p}Forearm{s}", (side * 0.51, 0, 0.93), (side * 0.53, 0, 0.7),
                                            [(0, 0.12, 0.12), (0.45, 0.16, 0.15), (1, 0.11, 0.11)], skin, n=2.6, r0=0.05, r1=0.05, segs=16, mid=4)])
    return parts


def bruiser_accessories(m):
    p = "BA_"
    pink, dark, white = m["pink"], m["dark"], m["white"]
    acc = {
        "Acc_Bruiser_TopHair": hair_top(p, 0.62, m["dark"], "flat", 4),
        "Acc_Bruiser_Headband": bind("Head", [
            head_band(p + "Headband", 0.62, 1.78, 1.7, pink, off=0.012, thick=0.02),
            box(p + "BandKnot", (0.1, 0.1, 0.1), (0.0, HEAD_Y + 0.29, 1.73), bevel=0.03, m=pink),
            box(p + "BandTailA", (0.06, 0.18, 0.05), (0.06, HEAD_Y + 0.37, 1.66), rot=rad(-30, 0, 20), bevel=0.015, m=pink),
            box(p + "BandTailB", (0.06, 0.18, 0.05), (-0.06, HEAD_Y + 0.37, 1.64), rot=rad(-40, 0, -20), bevel=0.015, m=pink),
        ]),
        "Acc_Bruiser_Bandana": bind("Head", [
            cap_crown(p + "Bandana", 0.62, m["red"], rim=1.72, top=1.95, off=0.026),
            box(p + "BandanaKnot", (0.12, 0.1, 0.1), (0.0, HEAD_Y + 0.3, 1.75), bevel=0.03, m=m["red"]),
            box(p + "BandanaTail", (0.1, 0.06, 0.2), (0.04, HEAD_Y + 0.34, 1.65), rot=rad(-15, 10, 0), bevel=0.02, m=m["red"]),
        ] + [sphere(f"{p}Dot{i}", 0.03, (math.cos(a) * 0.3, HEAD_Y + math.sin(a) * 0.255, 1.86), scale=(1, 1, 0.5), m=white, segs=6, rings=4)
             for i, a in enumerate((0.3, 1.2, 2.0, 2.9, 3.8, 4.7, 5.5))]),
        "Acc_Bruiser_Cap": bind("Head", [
            cap_crown(p + "Cap", 0.62, m["teal"]),
            box(p + "CapBrim", (0.38, 0.28, 0.05), (0, HEAD_Y + 0.38, 1.75), rot=rad(-12, 0, 0), bevel=0.02, m=m["yellow"]),
            box(p + "CapMesh", (0.3, 0.05, 0.14), (0, HEAD_Y - 0.275, 1.86), rot=rad(-16, 0, 0), bevel=0.02, m=white),
        ]),
        "Acc_Bruiser_Mohawk": bind("Head", [box(p + "Mohawk", (0.09, 0.4, 0.14), (0, HEAD_Y - 0.02, 1.9), bevel=0.035, m=dark)]
                                   + [cyl(f"{p}Spike{i}", 0.04, 0.14, (0, HEAD_Y - 0.18 + i * 0.09, 1.99), rot=rad(-20 + i * 10, 0, 0), segs=6, bevel=0.0,
                                          m=dark, radius_top=0.01) for i in range(5)]),
        "Acc_Bruiser_Shades": bind("Head", [
            box(p + "Wrap", (0.6, 0.06, 0.1), (0, face_y(0.62, 1.64) - 0.04, 1.64), bevel=0.03, m=m["lens"]),
            box(p + "WrapGlint", (0.2, 0.065, 0.025), (-0.12, face_y(0.62, 1.66) - 0.042, 1.665), bevel=0.0, m=m["lens_mirror"]),
            box(p + "ArmL", (0.03, 0.3, 0.03), (0.31, HEAD_Y - 0.1, 1.65), bevel=0.008, m=m["lens"]),
            box(p + "ArmR", (0.03, 0.3, 0.03), (-0.31, HEAD_Y - 0.1, 1.65), bevel=0.008, m=m["lens"]),
        ]),
        "Acc_Bruiser_Chain": bind("Spine", [
            tube(p + "Chain", [(-0.27, -0.1, 1.43), (-0.21, -0.31, 1.27), (0.0, -0.355, 1.2), (0.21, -0.31, 1.27), (0.27, -0.1, 1.43)], 0.022,
                 m=m["yellow"], segs=6),
            cyl(p + "Medal", 0.07, 0.025, (0, -0.365, 1.13), rot=rad(90, 0, 0), segs=14, bevel=0.008, m=m["yellow"]),
        ]),
        "Acc_Bruiser_Whistle": bind("Spine", [
            cyl(p + "Whistle", 0.04, 0.08, (0.12, -0.345, 1.24), rot=rad(0, 90, 0), segs=10, bevel=0.008, m=m["red"]),
            tube(p + "Cord", [(0.07, -0.34, 1.24), (-0.16, -0.32, 1.28), (-0.27, -0.1, 1.43)], 0.012, m=white, segs=5),
        ]),
    }
    return acc


def boardwalk_set(m):
    """(name, parts) of every mesh in zombie.glb."""
    meshes = [("Outfit_Tourist", tourist(m)), ("Outfit_Lifeguard", lifeguard(m)), ("Outfit_Bruiser", bruiser(m))]
    meshes += list(faces("Tourist", m, 0.62, ("Grin", "Gape", "Derp", "Sleepy"), tongue=m["pink"]).items())
    meshes += list(faces("Lifeguard", m, 0.54, ("Grin", "Gape", "Snarl", "Derp"), tongue=m["red"]).items())
    meshes += list(faces("Bruiser", m, 0.62, ("Snarl", "Clench", "Grin"), tongue=m["red"]).items())
    for group in (tourist_accessories(m), lifeguard_accessories(m), bruiser_accessories(m)):
        meshes += list(group.items())
    return meshes


# --- Shared garment bits for the world outfits -------------------------------

def hood(p, m, build, up=False):
    """A hoodie's hood: bunched behind the neck, or up over the head."""
    hw = BUILDS[build]["head"]
    if up:
        sk = skull(hw)
        return bind("Head", [sk.shell(p + "Hood", m, 1.95, 1.36, off=0.05, gap=150, segs=26, steps=7, lip=0.03),
                             sphere(p + "HoodTop", hw * 0.56, (0, HEAD_Y + 0.02, 1.84), scale=(1.0, 0.98, 0.62), m=m, segs=16, rings=8)])
    w, d = BUILDS[build]["chest"]
    return bind("Spine", [torus(p + "Hood", w * 0.24, 0.07, (0, d * 0.32, 1.44), rot=rad(-20, 0, 0), m=m, major_segs=20, minor_segs=8),
                          sphere(p + "HoodBack", w * 0.25, (0, d * 0.5, 1.36), scale=(1.1, 0.5, 0.9), m=m, segs=14, rings=8)])


def drawstrings(p, body, m):
    return bind("Spine", [tube(f"{p}String{side}", [(side * 0.06, body.front(side * 0.06, 1.4) - 0.01, 1.41),
                                                    (side * 0.065, body.front(side * 0.065, 1.24) - 0.012, 1.24)], 0.011, m=m, segs=5)
                          for side in (1, -1)])


def collar_band(p, body, m, z=1.4, h=0.08, off=0.03):
    """A polo / jacket collar standing round the neck."""
    a, b, cx, cy = body.section(z)
    return bind("Spine", [band(p + "Collar", (cx, cy - 0.01, z + h), (cx, cy - 0.01, z - 0.01), a * 0.62 + off, b * 0.7 + off, m, n=2.6,
                               thick=0.025, flare=0.02, segs=20)])


def row_prints(p, body, target, m, z, count=7, radius=0.04, petals=6, star=True, span=70, off=0.024, back=False):
    """A band of prints across the chest (snowflakes, stars)."""
    out = []
    for i in range(count):
        a = math.radians(-span + 2 * span * i / max(1, count - 1)) + (math.pi if back else 0.0)
        sa, sb, du, dv = body.section(z)
        loc = (du + math.sin(a) * (sa + off), dv - math.cos(a) * (sb + off), z)
        out.append(decal(f"{p}Row{i}{'B' if back else ''}", target, loc, radius, m, petals=petals, star=star, segs=petals * 4))
    return bind("Spine", out)


def chest_mark(p, body, target, m, x=0.0, z=1.2, size=0.06, kind="cross", back=False, off=0.02):
    """A cross (lifeguard, ski patrol) made of two flat bars on the chest or back."""
    y = body.front(x, z, back=back, off=off)
    rot = (0, 0, math.pi) if back else (0, 0, 0)
    if kind == "cross":
        return bind("Spine", [wrap(box(p + "MarkH", (size * 3, 0.03, size), (x, y, z), rot=rot, bevel=0.006, m=m), target, 0.004),
                              wrap(box(p + "MarkV", (size, 0.03, size * 3), (x, y, z), rot=rot, bevel=0.006, m=m), target, 0.004)])
    return []


def held(p, side, parts):
    """Bind props to a forearm (held in the hand)."""
    return bind(f"ForeArm.{'L' if side > 0 else 'R'}", parts)


def hand_at(side, out=0.0):
    """Centre of a hanging hand's grip (rest pose)."""
    return (side * (0.435 + out), -0.07, 0.5)


# --- Neon Rooftops: night-market tourist and rooftop runner ----------------

def neon_materials():
    m = base_materials("neon", skin="#86d69a", skin_dark="#58a874", dark="#17151f", white="#eeeaf4")
    m.update(
        shirt=mat("Shirt", "#7a3cff", rough=0.6),
        denim=mat("Denim", "#25285a", rough=0.75),
        glow_pink=mat("GlowPink", "#ff2fae", rough=0.3, emit=3.0),
        glow_cyan=mat("GlowCyan", "#2ef2ff", rough=0.3, emit=3.0),
        glow_lime=mat("GlowLime", "#b6ff3a", rough=0.3, emit=2.6),
        lens=mat("Lens", "#2a1f3d", rough=0.15, metal=0.3),
    )
    return m


def tourist_neon(m):
    """Night-market tourist: oversized hoodie with a neon smiley, joggers,
    sneakers with glowing soles."""
    p = "TN_"
    parts, body = casual(p, m, "wide", "hoodie", m["shirt"], m["denim"], pants="long", sleeve="long", foot="shoe", shoe=m["dark"],
                         sole=m["glow_pink"], lace=m["white"], toe=m["white"], hair=m["dark"], hair_style="mop", cuff=m["dark"], seed=21,
                         pants_hem=m["denim"])
    tor = parts[[o.name for o in parts].index(p + "Torso")]
    parts += hood(p, m["shirt"], "wide")
    parts += drawstrings(p, body, m["white"])
    parts += bind("Spine", [
        patch(p + "Pocket", tor, (0, body.front(0, 1.0) + 0.02, 1.0), (0.36, 0.06, 0.15), m["shirt"], bevel=0.03),
        decal(p + "Smiley", tor, (0.02, body.front(0.02, 1.22), 1.22), 0.11, m["glow_cyan"], segs=24),
        decal(p + "SmileyIn", tor, (0.02, body.front(0.02, 1.22), 1.22), 0.085, m["shirt"], offset=0.007, segs=24),
        decal(p + "SmileyEyeL", tor, (0.06, body.front(0.06, 1.25), 1.25), 0.016, m["glow_cyan"], offset=0.01, segs=10),
        decal(p + "SmileyEyeR", tor, (-0.02, body.front(-0.02, 1.25), 1.25), 0.016, m["glow_cyan"], offset=0.01, segs=10),
        decal(p + "SmileyMouth", tor, (0.02, body.front(0.02, 1.19), 1.19), 0.045, m["glow_cyan"], offset=0.01, squash=0.35, segs=16),
    ])
    for side, s in ((1, "L"), (-1, "R")):
        parts += bind(f"Shin.{s}", [box(f"{p}KneeRip{s}", (0.1, 0.03, 0.06), (side * 0.16, -0.112, 0.46), bevel=0.012, m=m["skin"])])
    return parts


def tourist_neon_accessories(m):
    p = "TNA_"
    gx, gy, gz = hand_at(-1)
    return {
        "Acc_Tourist_TopHair": hair_top(p, BUILDS["wide"]["head"], m["dark"], "mop", 21),
        "Acc_Tourist_LedCap": bind("Head", [
            cap_crown(p + "Cap", 0.62, m["dark"]),
            box(p + "Brim", (0.36, 0.3, 0.045), (0, HEAD_Y - 0.37, 1.77), rot=rad(8, 0, 0), bevel=0.02, m=m["dark"]),
            box(p + "BrimGlow", (0.37, 0.02, 0.05), (0, HEAD_Y - 0.52, 1.75), rot=rad(8, 0, 0), bevel=0.008, m=m["glow_pink"]),
            head_band(p + "CapRing", 0.62, 1.79, 1.762, m["glow_cyan"], off=0.037, thick=0.012),
        ]),
        "Acc_Tourist_HoodUp": hood(p, m["shirt"], "wide", up=True),
        "Acc_Tourist_GlowNecklace": bind("Spine", [torus(p + "Glow", 0.2, 0.016, (0, -0.06, 1.37), rot=rad(26, 0, 0), m=m["glow_lime"],
                                                         major_segs=24, minor_segs=5)]),
        "Acc_Tourist_Phone": held(p, -1, [
            box(p + "Phone", (0.04, 0.1, 0.17), (gx - 0.05, gy - 0.02, gz + 0.02), rot=rad(-30, 0, 0), bevel=0.012, m=m["dark"]),
            box(p + "Screen", (0.045, 0.082, 0.14), (gx - 0.05, gy - 0.02, gz + 0.02), rot=rad(-30, 0, 0), bevel=0.0, m=m["glow_cyan"]),
        ]),
        "Acc_Tourist_Backpack": bind("Spine", [
            box(p + "Pack", (0.42, 0.2, 0.46), (0, 0.33, 1.12), bevel=0.08, segs=3, m=m["dark"]),
            box(p + "PackStrip", (0.43, 0.21, 0.04), (0, 0.33, 1.2), bevel=0.01, m=m["glow_pink"]),
            box(p + "StrapL", (0.06, 0.5, 0.06), (0.17, 0.08, 1.38), bevel=0.02, m=m["dark"]),
            box(p + "StrapR", (0.06, 0.5, 0.06), (-0.17, 0.08, 1.38), bevel=0.02, m=m["dark"]),
        ]),
    }


def lifeguard_neon(m):
    """Rooftop runner: sleeveless running top with reflective bands, running
    shorts, glowing sneakers."""
    p = "LN_"
    parts, body = casual(p, m, "lean", "tank", m["shirt"], m["dark"], sleeve="none", foot="shoe", shoe=m["white"], sole=m["glow_pink"],
                         lace=m["dark"], toe=m["glow_cyan"], hair=m["dark"], hair_style="mop", cuff=m["glow_pink"], seed=23)
    tor = parts[[o.name for o in parts].index(p + "Torso")]
    parts += tank_straps(p, m, "lean", m["shirt"])
    parts += bind("Spine", [body.shell(p + "BandA", m["glow_cyan"], 1.26, 1.22, off=0.012, segs=24, steps=1, lip=0.008),
                            body.shell(p + "BandB", m["glow_cyan"], 1.06, 1.02, off=0.012, segs=24, steps=1, lip=0.008),
                            decal(p + "Num", tor, (0.0, body.front(0, 1.14), 1.14), 0.07, m["white"], petals=5, star=True, segs=20)])
    for side, s in ((1, "L"), (-1, "R")):
        parts += bind(f"Thigh.{s}", [box(f"{p}Stripe{s}", (0.03, 0.08, 0.26), (side * 0.255, 0, 0.66), bevel=0.0, m=m["glow_pink"])])
    return parts


def lifeguard_neon_accessories(m):
    p = "LNA_"
    w = BUILDS["lean"]["head"]
    gx, gy, gz = hand_at(1)
    return {
        "Acc_Lifeguard_TopHair": hair_top(p, BUILDS["lean"]["head"], m["dark"], "mop", 23),
        "Acc_Lifeguard_Headphones": bind("Head", [
            tube(p + "Band", [(-w * 0.52, HEAD_Y, 1.6), (-w * 0.42, HEAD_Y, 1.86), (0, HEAD_Y, 1.95), (w * 0.42, HEAD_Y, 1.86), (w * 0.52, HEAD_Y, 1.6)],
                 0.022, m=m["dark"], segs=6),
            cyl(p + "CupL", 0.09, 0.07, (w * 0.53, HEAD_Y, 1.58), rot=rad(0, 90, 0), segs=14, bevel=0.02, m=m["dark"]),
            cyl(p + "CupR", 0.09, 0.07, (-w * 0.53, HEAD_Y, 1.58), rot=rad(0, 90, 0), segs=14, bevel=0.02, m=m["dark"]),
            cyl(p + "GlowL", 0.06, 0.02, (w * 0.57, HEAD_Y, 1.58), rot=rad(0, 90, 0), segs=14, bevel=0.0, m=m["glow_cyan"]),
            cyl(p + "GlowR", 0.06, 0.02, (-w * 0.57, HEAD_Y, 1.58), rot=rad(0, 90, 0), segs=14, bevel=0.0, m=m["glow_cyan"]),
        ]),
        "Acc_Lifeguard_Visor": bind("Head", [
            head_band(p + "VisorBand", w, 1.8, 1.74, m["white"], off=0.012, thick=0.02),
            box(p + "VisorBrim", (0.36, 0.22, 0.03), (0, HEAD_Y - 0.36, 1.76), rot=rad(12, 0, 0), bevel=0.012, m=m["glow_pink"]),
        ]),
        "Acc_Lifeguard_Armband": bind("UpperArm.L", [
            band(p + "Arm", (0.39, 0, 1.17), (0.4, 0, 1.06), 0.09, 0.09, m["dark"], n=2.6, thick=0.015, segs=14),
            box(p + "ArmScreen", (0.03, 0.08, 0.1), (0.49, -0.0, 1.11), bevel=0.008, m=m["glow_cyan"]),
        ]),
        "Acc_Lifeguard_Bottle": held(p, 1, [
            cyl(p + "Bottle", 0.04, 0.2, (gx, gy, gz), rot=rad(-20, 0, 0), segs=12, bevel=0.01, m=m["glow_lime"]),
            cyl(p + "BottleCap", 0.03, 0.05, (gx, gy - 0.04, gz + 0.12), rot=rad(-20, 0, 0), segs=10, bevel=0.008, m=m["dark"]),
        ]),
    }


def neon_set(m):
    meshes = [("Outfit_Tourist", tourist_neon(m)), ("Outfit_Lifeguard", lifeguard_neon(m))]
    meshes += list(faces("Tourist", m, 0.62, ("Grin", "Gape", "Derp", "Snarl"), tongue=m["glow_pink"]).items())
    meshes += list(faces("Lifeguard", m, 0.54, ("Grin", "Gape", "Snarl", "Sleepy"), tongue=m["glow_pink"]).items())
    for group in (tourist_neon_accessories(m), lifeguard_neon_accessories(m)):
        meshes += list(group.items())
    return meshes


# --- Abyss Aquarium: visitor and keeper -------------------------------------

def aqua_materials():
    m = base_materials("aqua", skin="#9fcf4a", skin_dark="#6aa236")
    m.update(
        shirt=mat("Shirt", "#2fa6e8", rough=0.6),
        sand=mat("Sand", "#d9b27a", rough=0.75),
        teal=mat("Teal", "#1fb8a6", rough=0.6),
        navy=mat("Navy", "#26305e", rough=0.65),
        yellow=mat("Yellow", "#ffd23a", rough=0.5),
        shark=mat("SharkGrey", "#7f93b8", rough=0.7),
        coral=mat("Coral", "#ff6f6f", rough=0.6),
    )
    return m


def tourist_aqua(m):
    """Aquarium visitor: souvenir whale tee with bubbles, shorts, sneakers."""
    p = "TA2_"
    parts, body = casual(p, m, "wide", "tee", m["shirt"], m["sand"], foot="shoe", shoe=m["teal"], sole=m["white"], sock=m["white"],
                         lace=m["white"], hair=m["dark"], hair_style="fringe", belt=m["dark"], seed=31)
    tor = parts[[o.name for o in parts].index(p + "Torso")]
    zc = 1.17
    parts += bind("Spine", [
        decal(p + "Whale", tor, (0.0, body.front(0.0, zc), zc), 0.15, m["white"], squash=0.55, segs=28),
        decal(p + "WhaleTail", tor, (0.17, body.front(0.17, zc + 0.05), zc + 0.05), 0.06, m["white"], petals=2, segs=16),
        decal(p + "WhaleEye", tor, (-0.08, body.front(-0.08, zc + 0.02), zc + 0.02), 0.018, m["dark"], offset=0.008, segs=10),
        decal(p + "WhaleBelly", tor, (-0.01, body.front(-0.01, zc - 0.045), zc - 0.045), 0.1, m["teal"], squash=0.25, offset=0.007, segs=24),
    ])
    rng = random.Random(5)
    bubbles = []
    for i in range(6):
        x, z = rng.uniform(-0.12, 0.05), 1.27 + i * 0.03
        bubbles.append(decal(f"{p}Bubble{i}", tor, (x - 0.06 + i * 0.015, body.front(x, z), z), 0.012 + 0.006 * (i % 3), m["white"], segs=10))
    parts += bind("Spine", bubbles)
    return parts


def tourist_aqua_accessories(m):
    p = "TAA_"
    w = BUILDS["wide"]["head"]
    sk = skull(w)
    gx, gy, gz = hand_at(-1)
    teeth = [cyl(f"{p}Tooth{i}", 0.022, 0.05, (math.sin(a) * w * 0.53, HEAD_Y - math.cos(a) * 0.3, 1.85), rot=rad(180, 0, 0), segs=6, bevel=0.0,
                 m=m["white"], radius_top=0.003) for i, a in enumerate([math.radians(v) for v in (-60, -40, -20, 0, 20, 40, 60)])]
    return {
        # A plush shark hat: the wearer's face peeks out of its mouth.
        "Acc_Tourist_SharkHat": bind("Head", [
            sk.shell(p + "Shark", m["shark"], 2.06, 1.84, off=0.04, segs=26, steps=4, lip=0.03),
            sphere(p + "SharkTop", w * 0.58, (0, HEAD_Y + 0.02, 1.98), scale=(1.0, 1.15, 0.55), m=m["shark"], segs=16, rings=8),
            sphere(p + "Snout", 0.17, (0, HEAD_Y - 0.25, 2.0), scale=(1.3, 1.1, 0.55), m=m["shark"], segs=14, rings=8),
            cyl(p + "Fin", 0.12, 0.26, (0, HEAD_Y + 0.08, 2.18), rot=rad(-25, 0, 0), segs=8, bevel=0.01, m=m["shark"], radius_top=0.012),
            sphere(p + "EyeL", 0.035, (0.17, HEAD_Y - 0.3, 2.05), m=m["dark"], segs=8, rings=5),
            sphere(p + "EyeR", 0.035, (-0.17, HEAD_Y - 0.3, 2.05), m=m["dark"], segs=8, rings=5),
        ] + teeth),
        "Acc_Tourist_Lanyard": bind("Spine", [
            tube(p + "Cord", [(-0.14, -0.14, 1.42), (-0.08, chest_front("wide") - 0.02, 1.22), (0.0, chest_front("wide") - 0.03, 1.12),
                              (0.08, chest_front("wide") - 0.02, 1.22), (0.14, -0.14, 1.42)], 0.012, m=m["coral"], segs=5),
            box(p + "Ticket", (0.13, 0.025, 0.17), (0.0, chest_front("wide") - 0.045, 1.04), bevel=0.012, m=m["white"]),
            box(p + "TicketStripe", (0.135, 0.027, 0.04), (0.0, chest_front("wide") - 0.046, 1.08), bevel=0.0, m=m["teal"]),
        ]),
        "Acc_Tourist_Plush": held(p, -1, [
            sphere(p + "OctoHead", 0.11, (gx, gy - 0.04, gz + 0.02), scale=(1.0, 0.95, 1.1), m=m["coral"], segs=14, rings=8),
            sphere(p + "OctoEyeL", 0.025, (gx + 0.04, gy - 0.14, gz + 0.04), m=m["dark"], segs=6, rings=4),
            sphere(p + "OctoEyeR", 0.025, (gx - 0.04, gy - 0.14, gz + 0.04), m=m["dark"], segs=6, rings=4),
        ] + [tube(f"{p}OctoLeg{i}", [(gx + math.cos(a) * 0.06, gy - 0.04 + math.sin(a) * 0.06, gz - 0.06),
                                      (gx + math.cos(a) * 0.1, gy - 0.04 + math.sin(a) * 0.1, gz - 0.16)], 0.025, m=m["coral"], segs=6,
                  radius_end=0.012) for i, a in enumerate([math.tau * k / 6 for k in range(6)])]),
        "Acc_Tourist_Camera": bind("Spine", [
            box(p + "CamBody", (0.22, 0.09, 0.14), (0.06, chest_front("wide") - 0.05, 1.06), bevel=0.025, m=m["dark"]),
            cyl(p + "CamLens", 0.045, 0.07, (0.08, chest_front("wide") - 0.11, 1.05), rot=rad(90, 0, 0), segs=12, bevel=0.01, m=m["teal"]),
            tube(p + "CamStrap", [(-0.02, chest_front("wide") - 0.03, 1.1), (-0.12, chest_front("wide") - 0.01, 1.34), (-0.12, -0.05, 1.44)],
                 0.016, m=m["dark"], segs=6),
        ]),
    }


def lifeguard_aqua(m):
    """Aquarium keeper: staff polo with a name badge, rolled work trousers,
    yellow rubber boots."""
    p = "LA2_"
    parts, body = casual(p, m, "lean", "tee", m["shirt"], m["navy"], pants="long", foot="boot", shoe=m["yellow"], sole=m["dark"],
                         lace=m["yellow"], hair=m["dark"], hair_style="flat", belt=m["dark"], buckle=m["white"], seed=33, boot_h=0.2)
    tor = parts[[o.name for o in parts].index(p + "Torso")]
    parts += collar_band(p, body, m["shirt"], z=1.39)
    parts += bind("Spine", [
        patch(p + "Badge", tor, (0.12, body.front(0.12, 1.24), 1.24), (0.11, 0.04, 0.07), m["yellow"], bevel=0.01),
        patch(p + "Placket", tor, (0.0, body.front(0.0, 1.3), 1.3), (0.06, 0.04, 0.16), m["white"], bevel=0.01),
        decal(p + "Logo", tor, (-0.12, body.front(-0.12, 1.24), 1.24), 0.045, m["white"], petals=3, segs=18),
    ])
    parts += bind("Head", [
        cap_crown(p + "Cap", 0.54, m["navy"], top=1.99),
        box(p + "CapBrim", (0.34, 0.26, 0.045), (0, HEAD_Y - 0.36, 1.77), rot=rad(10, 0, 0), bevel=0.02, m=m["navy"]),
        sphere(p + "CapFish", 0.06, (0, HEAD_Y - 0.275, 1.86), scale=(1.2, 0.3, 0.6), rot=rad(-18, 0, 0), m=m["teal"], segs=10, rings=5),
    ])
    return parts


def lifeguard_aqua_accessories(m):
    p = "LAA_"
    gx, gy, gz = hand_at(1)
    fish = []
    for i, (dx, dz, rz) in enumerate(((-0.05, 0.12, 20), (0.04, 0.14, -15), (0.0, 0.1, 5))):
        fish.append(cyl(f"{p}FishTail{i}", 0.05, 0.08, (gx + dx, gy - 0.12, gz - 0.18 + dz), rot=rad(0, rz, 0), segs=3, bevel=0.0, m=m["shark"],
                        radius_top=0.004))
    return {
        "Acc_Lifeguard_Bucket": held(p, 1, [
            cyl(p + "Bucket", 0.13, 0.2, (gx, gy - 0.12, gz - 0.2), segs=16, bevel=0.02, m=m["teal"], radius_top=0.15),
            torus(p + "Handle", 0.13, 0.01, (gx, gy - 0.12, gz - 0.1), rot=rad(0, 90, 0), m=m["dark"], major_segs=14, minor_segs=4),
        ] + fish),
        "Acc_Lifeguard_Radio": bind("Hips", [
            box(p + "Radio", (0.08, 0.06, 0.16), (0.27, -0.12, 0.9), bevel=0.015, m=m["dark"]),
            cyl(p + "Aerial", 0.012, 0.12, (0.29, -0.12, 1.02), segs=6, bevel=0.0, m=m["dark"]),
            box(p + "RadioLed", (0.03, 0.065, 0.02), (0.27, -0.12, 0.95), bevel=0.0, m=m["coral"]),
        ]),
        "Acc_Lifeguard_Net": held(p, -1, [
            cyl(p + "NetPole", 0.018, 1.2, (hand_at(-1)[0], -0.06, 0.62), rot=rad(-12, 0, 0), segs=6, bevel=0.0, m=m["white"]),
            torus(p + "NetRing", 0.13, 0.014, (hand_at(-1)[0], -0.2, 1.24), rot=rad(80, 0, 0), m=m["teal"], major_segs=16, minor_segs=4),
            sphere(p + "NetBag", 0.12, (hand_at(-1)[0], -0.22, 1.16), scale=(1.0, 0.6, 1.1), m=m["white"], segs=10, rings=6),
        ]),
        "Acc_Lifeguard_Gloves": bind("ForeArm.L", [sphere(p + "GloveL", 0.1, (0.435, -0.02, 0.56), scale=(0.95, 0.7, 1.1), m=m["yellow"],
                                                          segs=12, rings=7)])
        + bind("ForeArm.R", [sphere(p + "GloveR", 0.1, (-0.435, -0.02, 0.56), scale=(0.95, 0.7, 1.1), m=m["yellow"], segs=12, rings=7)]),
    }


def aqua_set(m):
    meshes = [("Outfit_Tourist", tourist_aqua(m)), ("Outfit_Lifeguard", lifeguard_aqua(m))]
    meshes += list(faces("Tourist", m, 0.62, ("Grin", "Gape", "Derp", "Sleepy"), tongue=m["coral"]).items())
    meshes += list(faces("Lifeguard", m, 0.54, ("Grin", "Sleepy", "Snarl", "Gape"), tongue=m["coral"]).items())
    for group in (tourist_aqua_accessories(m), lifeguard_aqua_accessories(m)):
        meshes += list(group.items())
    return meshes


# --- Dune Spaceport: space-camp tourist and launch-crew runner --------------

def dune_materials():
    m = base_materials("dune")
    m.update(
        shirt=mat("Shirt", "#ff7a2a", rough=0.6),
        sand=mat("Sand", "#e2b27a", rough=0.75),
        teal=mat("Teal", "#21a89f", rough=0.55),
        orange=mat("CrewOrange", "#ff8a1f", rough=0.5),
        glow=mat("WandGlow", "#ff9a3a", rough=0.3, emit=3.0),
        alien=mat("AlienGlow", "#9dff3a", rough=0.3, emit=2.4),
    )
    return m


def tourist_dune(m):
    """Space-camp tourist: rocket-and-stars camp tee, cargo shorts, socks."""
    p = "TD_"
    parts, body = casual(p, m, "wide", "tee", m["shirt"], m["sand"], foot="shoe", shoe=m["teal"], sole=m["white"], sock=m["white"],
                         lace=m["white"], hair=m["dark"], hair_style="mop", belt=m["dark"], buckle=m["white"], seed=41, cuff=m["teal"])
    tor = parts[[o.name for o in parts].index(p + "Torso")]
    zc = 1.15
    rocket = [
        decal(p + "Rocket", tor, (0.0, body.front(0, zc), zc), 0.07, m["white"], squash=2.0, segs=24),
        decal(p + "RocketWin", tor, (0.0, body.front(0, zc + 0.04), zc + 0.04), 0.025, m["teal"], offset=0.008, segs=12),
        decal(p + "FinL", tor, (0.06, body.front(0.06, zc - 0.1), zc - 0.1), 0.035, m["white"], petals=3, star=True, segs=12),
        decal(p + "FinR", tor, (-0.06, body.front(-0.06, zc - 0.1), zc - 0.1), 0.035, m["white"], petals=3, star=True, segs=12),
        decal(p + "Flame", tor, (0.0, body.front(0, zc - 0.17), zc - 0.17), 0.04, m["teal"], petals=4, star=True, segs=16),
    ]
    parts += bind("Spine", rocket)
    parts += prints(p + "S", body, tor, m["white"], None, seed=7, count=8, petals=5, radius=(0.025, 0.035), z=(0.98, 1.34), gap=80, off=0.0)
    return parts


def tourist_dune_accessories(m):
    p = "TDA_"
    gx, gy, gz = hand_at(1)
    w = BUILDS["wide"]["head"]
    return {
        "Acc_Tourist_TopHair": hair_top(p, BUILDS["wide"]["head"], m["dark"], "mop", 41),
        "Acc_Tourist_Antennae": bind("Head", [
            head_band(p + "Band", w, 1.8, 1.74, m["teal"], off=0.012, thick=0.02),
            tube(p + "StalkL", [(0.14, HEAD_Y, 1.84), (0.2, HEAD_Y - 0.02, 2.0), (0.26, HEAD_Y - 0.06, 2.1)], 0.016, m=m["teal"], segs=6),
            tube(p + "StalkR", [(-0.14, HEAD_Y, 1.84), (-0.2, HEAD_Y - 0.02, 2.0), (-0.26, HEAD_Y - 0.06, 2.1)], 0.016, m=m["teal"], segs=6),
            sphere(p + "BallL", 0.055, (0.27, HEAD_Y - 0.07, 2.13), m=m["alien"], segs=10, rings=6),
            sphere(p + "BallR", 0.055, (-0.27, HEAD_Y - 0.07, 2.13), m=m["alien"], segs=10, rings=6),
        ]),
        "Acc_Tourist_Balloon": held(p, 1, [
            tube(p + "String", [(gx, gy, gz), (gx + 0.05, gy - 0.04, gz + 0.5), (gx + 0.08, gy - 0.02, gz + 1.0)], 0.006, m=m["white"], segs=4),
            sphere(p + "Balloon", 0.14, (gx + 0.08, gy - 0.02, gz + 1.2), scale=(0.8, 0.8, 1.35), m=m["shirt"], segs=14, rings=9),
            cyl(p + "Nose", 0.1, 0.14, (gx + 0.08, gy - 0.02, gz + 1.45), segs=12, bevel=0.01, m=m["white"], radius_top=0.01),
            box(p + "FinA", (0.22, 0.02, 0.1), (gx + 0.08, gy - 0.02, gz + 1.05), bevel=0.01, m=m["white"]),
            box(p + "FinB", (0.02, 0.22, 0.1), (gx + 0.08, gy - 0.02, gz + 1.05), bevel=0.01, m=m["white"]),
        ]),
        "Acc_Tourist_SpaceCap": bind("Head", [
            cap_crown(p + "Cap", 0.62, m["white"]),
            box(p + "Brim", (0.36, 0.3, 0.045), (0, HEAD_Y - 0.37, 1.77), rot=rad(8, 0, 0), bevel=0.02, m=m["teal"]),
            sphere(p + "CapStar", 0.06, (0, HEAD_Y - 0.29, 1.86), scale=(1.0, 0.3, 1.0), rot=rad(-20, 0, 0), m=m["shirt"], segs=10, rings=5),
        ]),
        "Acc_Tourist_FannyPack": bind("Hips", [
            box(p + "Pack", (0.3, 0.12, 0.13), (0.0, -0.29, 0.9), bevel=0.05, segs=3, m=m["teal"]),
            band(p + "Strap", (0, 0, 0.93), (0, 0, 0.89), 0.335, 0.235, m["dark"], n=3.0, thick=0.015, segs=24),
        ]),
    }


def lifeguard_dune(m):
    """Launch-crew runner: tintable flight suit with orange shoulder patches and
    a white chest stripe, utility belt, boots."""
    p = "LD_"
    suit = m["shirt"]
    parts, body = casual(p, m, "lean", "tee", suit, suit, pants="long", sleeve="long", foot="boot", shoe=m["dark"], sole=m["dark"],
                         lace=m["orange"], hair=m["dark"], hair_style="flat", belt=m["dark"], buckle=m["orange"], seed=43, cuff=m["orange"],
                         boot_h=0.16, tear=0)
    tor = parts[[o.name for o in parts].index(p + "Torso")]
    parts += collar_band(p, body, suit, z=1.39, h=0.07)
    parts += bind("Spine", [
        body.shell(p + "Stripe", m["white"], 1.24, 1.18, off=0.012, segs=24, steps=1, lip=0.008),
        patch(p + "Zip", tor, (0, body.front(0, 1.12), 1.12), (0.035, 0.03, 0.5), m["dark"], bevel=0.005),
        patch(p + "Patch", tor, (-0.13, body.front(-0.13, 1.08), 1.08), (0.1, 0.04, 0.08), m["orange"], bevel=0.012),
    ])
    for side, s in ((1, "L"), (-1, "R")):
        parts += bind(f"UpperArm.{s}", [sphere(f"{p}Shoulder{s}", 0.09, (side * 0.4, 0.0, 1.22), scale=(0.6, 1.0, 1.0), m=m["orange"], segs=12, rings=7)])
        parts += bind(f"Thigh.{s}", [box(f"{p}Pocket{s}", (0.045, 0.14, 0.14), (side * 0.25, 0, 0.62), bevel=0.02, m=suit)])
    return parts


def lifeguard_dune_accessories(m):
    p = "LDA_"
    w = BUILDS["lean"]["head"]

    def wand(side):
        gx, gy, gz = hand_at(side)
        return held(p, side, [cyl(f"{p}Grip{side}", 0.03, 0.12, (gx, gy, gz + 0.02), rot=rad(-70, 0, 0), segs=10, bevel=0.005, m=m["dark"]),
                              cyl(f"{p}Wand{side}", 0.034, 0.4, (gx, gy - 0.24, gz + 0.09), rot=rad(-70, 0, 0), segs=10, bevel=0.01, m=m["glow"],
                                  radius_top=0.026)])
    return {
        "Acc_Lifeguard_TopHair": hair_top(p, BUILDS["lean"]["head"], m["dark"], "flat", 43),
        "Acc_Lifeguard_Wands": wand(1) + wand(-1),
        "Acc_Lifeguard_Headset": bind("Head", [
            tube(p + "Band", [(-w * 0.52, HEAD_Y, 1.6), (-w * 0.4, HEAD_Y, 1.88), (0, HEAD_Y, 1.95), (w * 0.4, HEAD_Y, 1.88), (w * 0.52, HEAD_Y, 1.6)],
                 0.02, m=m["dark"], segs=6),
            cyl(p + "CupL", 0.085, 0.07, (w * 0.53, HEAD_Y, 1.58), rot=rad(0, 90, 0), segs=14, bevel=0.02, m=m["orange"]),
            cyl(p + "CupR", 0.085, 0.07, (-w * 0.53, HEAD_Y, 1.58), rot=rad(0, 90, 0), segs=14, bevel=0.02, m=m["orange"]),
            tube(p + "Mic", [(w * 0.53, HEAD_Y - 0.04, 1.54), (w * 0.4, HEAD_Y - 0.2, 1.44), (w * 0.2, face_y(w, 1.42) - 0.06, 1.39)], 0.012,
                 m=m["dark"], segs=5),
        ]),
        "Acc_Lifeguard_CrewHelmet": bind("Head", [
            cap_crown(p + "Helmet", 0.54, m["white"], rim=1.715, top=2.0, off=0.045, segs=28),
            box(p + "HelmetStripe", (0.08, 0.66, 0.06), (0, HEAD_Y + 0.02, 2.0), bevel=0.02, m=m["orange"]),
        ]),
        "Acc_Lifeguard_Clipboard": bind("ForeArm.L", [
            box(p + "Board", (0.03, 0.22, 0.3), (hand_at(1)[0] + 0.07, -0.08, 0.55), rot=rad(0, 0, 0), bevel=0.01, m=m["sand"]),
            box(p + "Paper", (0.032, 0.18, 0.22), (hand_at(1)[0] + 0.07, -0.08, 0.54), bevel=0.0, m=m["white"]),
        ]),
    }


def dune_set(m):
    meshes = [("Outfit_Tourist", tourist_dune(m)), ("Outfit_Lifeguard", lifeguard_dune(m))]
    meshes += list(faces("Tourist", m, 0.62, ("Grin", "Gape", "Derp", "Clench")).items())
    meshes += list(faces("Lifeguard", m, 0.54, ("Grin", "Gape", "Snarl", "Clench")).items())
    for group in (tourist_dune_accessories(m), lifeguard_dune_accessories(m)):
        meshes += list(group.items())
    return meshes


# --- Frostpeak Resort: lodge guest and ski patrol ---------------------------

def frost_materials():
    m = base_materials("frost", skin="#8fc7b0", skin_dark="#5f9a86", dark="#1c2030", white="#f6f6ff")
    m.update(
        shirt=mat("Shirt", "#c8304a", rough=0.8),
        navy=mat("FrostNavy", "#232a5c", rough=0.65),
        red=mat("PatrolRed", "#e2343f", rough=0.55),
        grey=mat("BootGrey", "#5d6478", rough=0.6),
        accent=mat("FrostAccent", "#ffd23f", rough=0.5),
        lens=mat("GoggleLens", "#ff7a2a", rough=0.15, emit=1.2),
        cocoa=mat("Cocoa", "#6a3a26", rough=0.5),
    )
    return m


def tourist_frost(m):
    """Lodge guest: chunky knit sweater with a snowflake band, ski pants,
    fluffy moon boots."""
    p = "TF_"
    parts, body = casual(p, m, "wide", "sweater", m["shirt"], m["navy"], pants="long", sleeve="long", foot="boot", shoe=m["white"],
                         sole=m["grey"], lace=m["white"], hair=m["dark"], hair_style="mop", cuff=m["white"], hem=m["white"], seed=51,
                         boot_h=0.2, tear=1)
    tor = parts[[o.name for o in parts].index(p + "Torso")]
    parts += collar_band(p, body, m["white"], z=1.38, h=0.09, off=0.04)
    parts += bind("Spine", [body.shell(p + "BandTop", m["white"], 1.3, 1.27, off=0.012, segs=24, steps=1, lip=0.008),
                            body.shell(p + "BandBot", m["white"], 1.1, 1.07, off=0.012, segs=24, steps=1, lip=0.008)])
    parts += row_prints(p, body, tor, m["white"], 1.185, count=7, radius=0.042, petals=6)
    parts += row_prints(p, body, tor, m["white"], 1.185, count=5, radius=0.042, petals=6, back=True)
    for side, s in ((1, "L"), (-1, "R")):
        parts += bind(f"Shin.{s}", [sphere(f"{p}Fluff{s}", 0.13, (side * 0.16, 0.0, 0.36), scale=(1.0, 1.0, 0.45), m=m["white"], segs=14, rings=7)])
    return parts


def tourist_frost_accessories(m):
    p = "TFA_"
    w = BUILDS["wide"]["head"]
    sk = skull(w)
    gx, gy, gz = hand_at(-1)
    return {
        "Acc_Tourist_TopHair": hair_top(p, BUILDS["wide"]["head"], m["dark"], "mop", 51),
        "Acc_Tourist_Bobble": bind("Head", [
            cap_crown(p + "Beanie", w, m["accent"], rim=1.74, top=2.08),
            head_band(p + "Cuff", w, 1.81, 1.715, m["shirt"], off=0.04, thick=0.03),
            sphere(p + "Pompom", 0.1, (0, HEAD_Y + 0.02, 2.1), m=m["white"], segs=10, rings=7),
        ]),
        "Acc_Tourist_Trapper": bind("Head", [
            sk.shell(p + "Trapper", m["cocoa"], 1.98, 1.66, off=0.03, gap=120, segs=26, steps=4, lip=0.03),
            sphere(p + "TrapTop", w * 0.52, (0, HEAD_Y, 1.86), scale=(1.0, 0.98, 0.5), m=m["cocoa"], segs=16, rings=8),
            box(p + "FlapL", (0.07, 0.2, 0.26), (w * 0.53, HEAD_Y, 1.56), bevel=0.03, m=m["white"]),
            box(p + "FlapR", (0.07, 0.2, 0.26), (-w * 0.53, HEAD_Y, 1.56), bevel=0.03, m=m["white"]),
            head_band(p + "Fur", w, 1.82, 1.72, m["white"], off=0.032, thick=0.03),
        ]),
        "Acc_Tourist_Mug": held(p, -1, [
            cyl(p + "Mug", 0.06, 0.13, (gx, gy - 0.02, gz + 0.02), segs=14, bevel=0.015, m=m["shirt"]),
            cyl(p + "Cocoa", 0.05, 0.01, (gx, gy - 0.02, gz + 0.085), segs=12, bevel=0.0, m=m["cocoa"]),
            torus(p + "MugHandle", 0.04, 0.012, (gx + 0.065, gy - 0.02, gz + 0.02), rot=rad(90, 0, 0), m=m["shirt"], major_segs=12, minor_segs=4),
            sphere(p + "Marsh", 0.025, (gx + 0.01, gy - 0.03, gz + 0.1), m=m["white"], segs=6, rings=4),
        ]),
        "Acc_Tourist_Scarf": bind("Spine", [
            torus(p + "Scarf", 0.17, 0.065, (0, -0.02, 1.365), rot=rad(28, 0, 0), m=m["accent"], major_segs=18, minor_segs=7),
            box(p + "Tail", (0.12, 0.05, 0.38), (0.12, chest_front("wide") - 0.03, 1.24), rot=rad(4, 0, 8), bevel=0.02, m=m["accent"]),
            box(p + "TailStripe", (0.125, 0.055, 0.04), (0.125, chest_front("wide") - 0.03, 1.12), rot=rad(4, 0, 8), bevel=0.01, m=m["shirt"]),
        ]),
    }


def lifeguard_frost(m):
    """Ski patrol: red jacket with white crosses, black ski pants, snow boots."""
    p = "LF_"
    red = m["red"]
    parts, body = casual(p, m, "lean", "jacket", red, m["dark"], pants="long", sleeve="long", foot="boot", shoe=m["grey"], sole=m["dark"],
                         lace=m["dark"], hair=m["dark"], hair_style="fringe", cuff=m["dark"], hem=m["dark"], seed=53, boot_h=0.18, tear=0)
    tor = parts[[o.name for o in parts].index(p + "Torso")]
    parts += collar_band(p, body, red, z=1.38, h=0.11, off=0.035)
    parts += bind("Spine", [
        patch(p + "Zip", tor, (0, body.front(0, 1.12), 1.12), (0.03, 0.03, 0.52), m["dark"], bevel=0.005),
        text(p + "Label", "PATROL", 0.07, 0.012, (0, body.front(0, 1.3, back=True, off=0.008), 1.3), rot=(0, 0, math.pi), m=m["white"]),
    ])
    parts += chest_mark(p, body, tor, m["white"], x=0.0, z=1.12, size=0.06, back=True)
    parts += chest_mark(p + "F", body, tor, m["white"], x=0.11, z=1.25, size=0.025)
    return parts


def lifeguard_frost_accessories(m):
    p = "LFA_"
    w = BUILDS["lean"]["head"]
    return {
        "Acc_Lifeguard_Goggles": bind("Head", [
            head_band(p + "Strap", w, 1.84, 1.78, m["dark"], off=0.012, thick=0.02),
            box(p + "Frame", (0.34, 0.08, 0.13), (0, HEAD_Y - 0.28, 1.83), rot=rad(-15, 0, 0), bevel=0.04, m=m["white"]),
            box(p + "Lens", (0.3, 0.06, 0.1), (0, HEAD_Y - 0.31, 1.83), rot=rad(-15, 0, 0), bevel=0.035, m=m["lens"]),
        ]),
        "Acc_Lifeguard_Helmet": bind("Head", [
            cap_crown(p + "Helmet", 0.54, m["white"], rim=1.715, top=2.0, off=0.045, segs=28),
            box(p + "HelmetCrossH", (0.12, 0.03, 0.04), (0, HEAD_Y - 0.29, 1.86), rot=rad(-25, 0, 0), bevel=0.0, m=m["red"]),
            box(p + "HelmetCrossV", (0.04, 0.03, 0.12), (0, HEAD_Y - 0.29, 1.86), rot=rad(-25, 0, 0), bevel=0.0, m=m["red"]),
        ]),
        "Acc_Lifeguard_Pack": bind("Spine", [
            box(p + "Pack", (0.38, 0.2, 0.46), (0, 0.29, 1.12), bevel=0.07, segs=3, m=m["red"]),
            box(p + "PackCrossH", (0.16, 0.21, 0.05), (0, 0.3, 1.16), bevel=0.0, m=m["white"]),
            box(p + "PackCrossV", (0.05, 0.21, 0.16), (0, 0.3, 1.16), bevel=0.0, m=m["white"]),
            box(p + "StrapL", (0.06, 0.42, 0.06), (0.15, 0.07, 1.38), bevel=0.02, m=m["dark"]),
            box(p + "StrapR", (0.06, 0.42, 0.06), (-0.15, 0.07, 1.38), bevel=0.02, m=m["dark"]),
        ]),
        "Acc_Lifeguard_Radio": bind("Spine", [
            box(p + "Radio", (0.07, 0.05, 0.14), (-0.15, chest_front("lean") - 0.02, 1.25), bevel=0.015, m=m["dark"]),
            cyl(p + "Aerial", 0.01, 0.12, (-0.17, chest_front("lean") - 0.02, 1.37), segs=6, bevel=0.0, m=m["dark"]),
            box(p + "RadioLed", (0.03, 0.055, 0.02), (-0.15, chest_front("lean") - 0.02, 1.29), bevel=0.0, m=m["accent"]),
        ]),
    }


def frost_set(m):
    meshes = [("Outfit_Tourist", tourist_frost(m)), ("Outfit_Lifeguard", lifeguard_frost(m))]
    meshes += list(faces("Tourist", m, 0.62, ("Grin", "Gape", "Sleepy", "Derp"), tongue=m["shirt"]).items())
    meshes += list(faces("Lifeguard", m, 0.54, ("Grin", "Snarl", "Clench", "Gape"), tongue=m["red"]).items())
    for group in (tourist_frost_accessories(m), lifeguard_frost_accessories(m)):
        meshes += list(group.items())
    return meshes


# zombie_<world>.glb: the Tourist and the Lifeguard dressed for each world.
WORLD_SETS = {
    "neon": (neon_materials, neon_set),
    "aqua": (aqua_materials, aqua_set),
    "dune": (dune_materials, dune_set),
    "frost": (frost_materials, frost_set),
}


# ---------------------------------------------------------------------------

def build_set(name, materials, meshes):
    """Skin every (mesh name, parts) of `meshes(m)` to a fresh rig with the shared
    clips and save art/models/<name>.glb."""
    scene = reset_scene()
    scene.render.fps = FPS
    m = materials()
    armature = build_armature()
    objects = [skin(mesh_name, parts, armature) for mesh_name, parts in meshes(m)]
    zombie_anim.bake(armature, zombie_anim.boardwalk_clips, name)
    save_zombie(name, [armature] + objects)


def build():
    build_set("zombie", boardwalk_materials, boardwalk_set)
    for world, (materials, meshes) in WORLD_SETS.items():
        build_set("zombie_" + world, materials, meshes)


if __name__ == "__main__":
    build()
