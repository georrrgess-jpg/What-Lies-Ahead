"""Intersection audit for the operators (python build_operators.py --audit).

For sampled frames of every clip the skinned mesh is posed with the same
solver that wrote the animation, split into body regions (head, torso, upper
arms, forearms, hands, thighs, shins, feet, plus any extra bones) and every
pair of regions is tested for interpenetration:

  * Regions that meet at a joint ignore the geometry around that joint (the
    ball joints are meant to overlap there).
  * A hit is reported when a vertex of one region sits deeper than TOLERANCE
    inside the other.

With weapons (WLA_AUDIT_WEAPONS="ion_carbine,scatter_blaster") the weapon
model is placed on the WeaponSocket in AimIdle and Fire and tested against
every region; the hands may press into the grip by GRIP_TOLERANCE.

A static check flags hair that pokes out through headgear.
"""
import os
from collections import defaultdict

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

from operator_kit import HEAD_C, MODELS_DIR, REGION, weapon_socket_matrix

TOLERANCE = 0.008
GRIP_TOLERANCE = 0.016
RAY = Vector((0.31, 0.47, 0.83)).normalized()

# Region pairs that share a joint: (bone at the joint, radius ignored around it).
JOINTS = {("head", "torso"): ("Head", 0.125), ("cape", "torso"): ("Cape1", 0.34)}
for _s in (".L", ".R"):
    JOINTS[("torso", "upperarm" + _s)] = ("UpperArm" + _s, 0.14)
    JOINTS[("forearm" + _s, "upperarm" + _s)] = ("ForeArm" + _s, 0.1)
    JOINTS[("forearm" + _s, "hand" + _s)] = ("Hand" + _s, 0.09)
    JOINTS[("thigh" + _s, "torso")] = ("Thigh" + _s, 0.17)
    JOINTS[("shin" + _s, "thigh" + _s)] = ("Shin" + _s, 0.125)
    JOINTS[("foot" + _s, "shin" + _s)] = ("Foot" + _s, 0.12)


def _inside(tree, point):
    """True if `point` is inside the closed surfaces in `tree` (winding count along a ray)."""
    count = 0
    origin = point
    for _ in range(14):
        loc, nor, _i, _d = tree.ray_cast(origin, RAY)
        if loc is None:
            break
        count += 1 if nor.dot(RAY) > 0.0 else -1
        origin = loc + RAY * 1e-4
    return count > 0


class Model:
    """Rest geometry of the skinned mesh with what is needed to pose it."""

    def __init__(self, mesh_obj, info, rig):
        me = mesh_obj.data
        self.rest = [v.co.copy() for v in me.vertices]
        names = [g.name for g in mesh_obj.vertex_groups]
        self.weights = [[(names[g.group], g.weight) for g in v.groups if g.weight > 0.0] for v in me.vertices]
        part = [0] * len(me.polygons)
        me.attributes["part"].data.foreach_get("value", part)
        self.info = info
        self.rig = rig
        self.polys = defaultdict(list)       # region -> [(vertex ids, part index)]
        self.part_polys = defaultdict(list)  # part index -> [vertex ids]
        for p in me.polygons:
            data = info[part[p.index]]
            if data["glass"]:
                continue
            region = data["region"]
            if region == "extra":
                region = REGION.get(data["bone"], data["bone"] or "extra")
            self.polys[region].append((tuple(p.vertices), part[p.index]))
            self.part_polys[part[p.index]].append(tuple(p.vertices))

    def posed(self, sol):
        mats = {}
        for name in self.rig.order:
            m = sol.D[name].to_matrix()
            mats[name] = (m, sol.P[name] - m @ self.rig.head[name])
        out = []
        for co, weights in zip(self.rest, self.weights):
            if len(weights) == 1:
                m, o = mats[weights[0][0]]
                out.append(m @ co + o)
            else:
                total = sum(w for _n, w in weights)
                p = Vector((0, 0, 0))
                for name, w in weights:
                    m, o = mats[name]
                    p += (m @ co + o) * (w / total)
                out.append(p)
        return out


def _weapon_mesh(name):
    """World-space triangles of a weapon model without its first-person arms (Blender axes, origin at the grip top)."""
    path = os.path.join(MODELS_DIR, name + ".glb")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    bpy.context.view_layer.update()
    verts, polys = [], []
    for ob in new:
        chain, hidden = ob, False
        while chain is not None:
            hidden = hidden or chain.name.split(".")[0] in ("ArmL", "ArmR")
            chain = chain.parent
        if ob.type != "MESH" or hidden or "Holo" in ob.name or ob.name.split(".")[0] == "Decal":
            continue
        off = len(verts)
        verts += [ob.matrix_world @ v.co for v in ob.data.vertices]
        polys += [[off + i for i in p.vertices] for p in ob.data.polygons]
    for ob in new:
        bpy.data.objects.remove(ob, do_unlink=True)
    return verts, polys


def _depth_report(a_tree, a_cos, a_polys, b_tree, b_cos, b_polys, skip_a, skip_b):
    """Deepest penetration between two posed regions: (depth, point, part index of the buried vertex)."""
    pairs = a_tree.overlap(b_tree)
    if not pairs:
        return 0.0, None, None
    best = (0.0, None, None)
    for own, own_cos, own_polys, other, skip, column in ((a_tree, a_cos, a_polys, b_tree, skip_a, 0), (b_tree, b_cos, b_polys, a_tree, skip_b, 1)):
        seen = set()
        for pair in pairs:
            verts, part = own_polys[pair[column]]
            for vi in verts:
                if vi in seen:
                    continue
                seen.add(vi)
                p = own_cos[vi]
                if skip(p) or not _inside(other, p):
                    continue
                d = other.find_nearest(p)[3]
                if d is not None and d > best[0]:
                    best = (d, p.copy(), part)
    return best


def run(op_id, mesh_obj, info, rig, clips, samples=9):
    model = Model(mesh_obj, info, rig)
    regions = sorted(model.polys)
    worst = {}
    reach = {}
    weapons = [w for w in os.environ.get("WLA_AUDIT_WEAPONS", "").split(",") if w]
    weapon_data = {w: _weapon_mesh(w) for w in weapons}
    socket_rest = weapon_socket_matrix()
    frames_checked = 0
    for clip, frames in clips.items():
        reach[clip] = max(f.reach_error for f in frames)
        step = max(1, (len(frames) - 1) // samples)
        for fi in range(0, len(frames), step):
            sol = frames[fi]
            frames_checked += 1
            cos = model.posed(sol)
            trees = {r: BVHTree.FromPolygons(cos, [v for v, _p in model.polys[r]]) for r in regions}
            for i, a in enumerate(regions):
                for b in regions[i + 1:]:
                    joint = JOINTS.get((a, b)) or JOINTS.get((b, a))
                    if joint:
                        centre, radius = sol.P[joint[0]], joint[1]
                        skip = lambda p, c=centre, r=radius: (p - c).length < r     # noqa: E731
                    else:
                        skip = lambda p: False                                      # noqa: E731
                    depth, point, part = _depth_report(trees[a], cos, model.polys[a], trees[b], cos, model.polys[b], skip, skip)
                    if depth > TOLERANCE and depth > worst.get((a, b), (0.0,))[0]:
                        worst[(a, b)] = (depth, clip, fi, info[part]["name"], point)
            if clip in ("AimIdle-loop", "Fire"):
                hand = sol.D["Hand.R"].to_matrix().to_4x4()
                m = Matrix.Translation(sol.P["Hand.R"]) @ hand @ Matrix.Translation(-rig.head["Hand.R"]) @ socket_rest
                for w, (wv, wp) in weapon_data.items():
                    w_cos = [m @ v for v in wv]
                    w_tree = BVHTree.FromPolygons(w_cos, wp)
                    w_polys = [(tuple(p), -1) for p in wp]
                    for r in regions:
                        depth, point, part = _depth_report(trees[r], cos, model.polys[r], w_tree, w_cos, w_polys, lambda p: False, lambda p: False)
                        limit = GRIP_TOLERANCE if r.startswith("hand") else TOLERANCE
                        key = (r, "weapon:" + w)
                        if depth > limit and depth > worst.get(key, (0.0,))[0]:
                            worst[key] = (depth, clip, fi, info[part]["name"] if part is not None and part >= 0 else w, point)
    static = _hair_check(model, info)
    print(f"[audit] {op_id}: {frames_checked} frames, {len(regions)} regions, weapons={weapons or 'none'}")
    print("[audit]   reach error (m): " + ", ".join(f"{c} {e:.4f}" for c, e in reach.items()))
    slide = _foot_slide(clips["Run-loop"], rig)
    print(f"[audit]   run: planted foot drifts {slide * 1000:.1f} mm from the moving ground")
    for (a, b), (depth, clip, fi, part, point) in sorted(worst.items(), key=lambda kv: -kv[1][0]):
        print(f"[audit]   HIT {a} x {b}: {depth * 1000:.0f} mm in {clip} f{fi} ({part} at {point.x:.2f},{point.y:.2f},{point.z:.2f})")
    for line in static:
        print("[audit]   STATIC " + line)
    if not worst and not static:
        print("[audit]   clean")
    return worst, static


def _foot_slide(frames, rig):
    """Largest distance a planted foot's contact point strays from ground moving at RUN_SPEED."""
    from operator_anim import RUN_SPEED, RUN_LEN, _STANCE, _BALL
    worst = 0.0
    count = len(frames) - 1
    for side, name, offset in ((1, "Foot.L", 0.0), (-1, "Foot.R", 0.5)):
        ref = None
        for f in range(count):
            phase = (f / count + offset) % 1.0
            u = phase / _STANCE
            if not 0.15 <= u <= 0.6:
                ref = None
                continue
            sol = frames[f]
            ball = sol.P[name] + sol.D[name] @ _BALL
            ground_y = ball.y - RUN_SPEED * (phase * RUN_LEN)
            if ref is None:
                ref = (ground_y, ball.z)
            worst = max(worst, abs(ground_y - ref[0]), abs(ball.z - ref[1]))
    return worst


def _hair_check(model, info):
    """Headgear faces that are buried in hair (hair poking out through a hat)."""
    hair = [i for i, d in enumerate(info) if d["tag"] == "hair"]
    gear = [i for i, d in enumerate(info) if d["tag"] == "headgear" and not d["glass"]]
    if not hair or not gear:
        return []
    cos = model.rest
    hair_tree = BVHTree.FromPolygons(cos, [p for i in hair for p in model.part_polys[i]])
    out = []
    head_parts = [i for i, d in enumerate(info) if d["region"] == "head" and not d["glass"] and i not in hair]
    for g in gear:
        others = [p for i in head_parts if i != g for p in model.part_polys[i]]
        other_tree = BVHTree.FromPolygons(cos, others) if others else None
        buried = 0
        for poly in model.part_polys[g]:
            c = sum((cos[i] for i in poly), Vector((0, 0, 0))) / len(poly)
            normal = (cos[poly[1]] - cos[poly[0]]).cross(cos[poly[2]] - cos[poly[0]])
            if normal.length < 1e-12 or normal.normalized().dot((c - HEAD_C).normalized()) < 0.3:
                continue
            if _inside(hair_tree, c) and hair_tree.find_nearest(c)[3] > 0.004 and not (other_tree and _inside(other_tree, c)):
                buried += 1
        if buried:
            out.append(f"hair covers {buried} outward faces of {info[g]['name']}")
    return out
