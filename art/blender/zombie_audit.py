"""Intersection audit of every zombie model: parts that cross where they are
not meant to, at rest (every accessory combination, faces, headgear over hair)
and through every clip (limbs, props and accessories against the body and each
other, and everything against the ground).

    python art/blender/zombie_audit.py [model ...] [--json=out.json] [--verbose]

It runs the real builders with their `skin`, `bake` and `save` swapped for
recorders, so it always checks exactly what the builders make (nothing is
written to art/). Models: zombie, zombie_neon, zombie_aqua, zombie_dune,
zombie_frost, neon_punk, neon_courier, neon_riot, aqua_zombies, dune_zombies,
frost_zombies.

Findings

  static  acc-acc      two accessories that can be worn together cross
          acc-face     a face part (brow, eye, tooth) sticks out through a head
                       accessory, or any other accessory crosses the face
          headgear     hair, ears or built-in headgear stick out through a
                       bigger head accessory
          acc-feature  an accessory crosses a collar, hood, strap, prop...
          face-feature a face part sticks out through hair or built-in headgear

On the head, "sticks out through" means the two surfaces cross and the smaller
part has vertices outside the other above the lowest point of the crossing: a
cap pulled down over the brows or hair showing below a hat's rim is fine, a
brow or a tuft coming out through the hat is a finding.
  clips   a part sinks >= DEPTH into a part on another bone, deeper than it
          does at rest (arms through bellies, props through legs...), counted
          once per clip and pair of (mesh, bone)
  ground  a (mesh, bone) dips >= GROUND below the floor in a clip (Emerge
          clips climb out of it)

Static findings are counted once per conflict (an accessory against a kind of
face part, whatever the face preset), with the raw part pairs alongside.

Accessory slots, clip styles and special clips are read from data/enemies.
"""
import glob
import json
import math
import os
import re
import sys
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

import zombie_anim  # noqa: E402

DEPTH = 0.03        # clip finding: this much deeper than at rest
GROUND = 0.035      # ground finding: this far below the floor
CROSS = 0.02        # static finding: the crossing curve is at least this long
JOINT = 0.25        # ...not counting what sits this close to either part's joint
STEP = 4            # clip poses sampled (of KEY_FPS = 48 per second)
STYLES = ("Heavy", "Diver", "Octo", "Hazmat", "Mechanic", "Skier")
# Clips only some enemies play (their behaviours ask for them by name).
EXCLUSIVE = {"Spit": {"Octo"}, "Throw": {"Yeti"}, "Tuck": {"Skier"}, "Spray": {"Punk"}, "Leap": {"Courier"},
             "Roar": {"Bruiser", "Yeti", "Riot"}, "Bound": {"Cadet"}, "Hover": {"Mechanic"},
             "Crouch": {"Cadet", "Mechanic", "Courier"}}
FEATURE = re.compile(r"(Collar|Hood|Lapel|Strap|String|Chain|Pouch|Tank|Pack|Can|Baton|Holster|Badge|Scarf|Label|Hose|Valve|Box)")
# Crossings that are part of the design: (regex on "mesh/part|mesh/part", tried
# both ways round, why).
INTENDED = [
    (r"Acc_Frozen_Ice/", "the ice block encases the frozen tourist and all he wears"),
    (r"Acc_Diver_Helmet/.*\|Face_Diver", "the diving helmet seals the whole head in"),
    (r"Face_Hazmat_\w+/.*\|Outfit_Hazmat/H_Hood", "the mask sits in the opening of the hood"),
    (r"Face_Octo_\w+/.*\|Outfit_Octo/O_(FaceRing|Hood)", "the face pushes through the costume's face hole"),
    (r"Face_Yeti_\w+/.*\|Outfit_Yeti/Y_(FaceRim|HoodTop)", "the fur hood frames the face"),
    (r"Outfit_Tourist/T_Clump\d+\|Acc_Tourist_Hair/", "the curly wig sits on the fringe"),
    (r"Outfit_Yeti/Y_HoodFur\d*\|Acc_Yeti_Beanie/", "the little beanie nestles in the fur"),
    (r"Outfit_Courier/C_Helmet\|Acc_Courier_Goggles/", "the goggles are strapped round the helmet"),
    (r"Outfit_Bruiser/B_Crop\|Acc_Bruiser_(Headband|Shades)/", "the headband and the arms of the shades lie in the crop"),
    (r"Acc_Cadet_(Antenna|Pennant)/.*\|Outfit_Cadet/C_(Pack|Tank)", "mounted on the backpack"),
    (r"Acc_Lifeguard_Gloves/.*\|Acc_Lifeguard_Net/", "the glove holds the net"),
    (r"Acc_Lifeguard_(Towel|Tube)/.*\|Outfit_Lifeguard/L_Strap", "worn over the tank top's straps"),
    (r"Acc_\w+_Camera/\w+Strap\w*\|Outfit_\w+/\w+Collar", "the camera strap runs under the collar"),
    (r"Acc_\w+_Scarf/.*\|Outfit_\w+/\w+Collar", "a scarf wraps the collar"),
]


class Part:
    """One rigid part, evaluated (modifiers applied) in rest space."""

    def __init__(self, ob, group, dg, joints):
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        mw = ob.matrix_world
        self.name, self.bone, self.group = ob.name, ob["bone"], group
        self.joint = joints[self.bone]
        self.V = np.array([tuple(mw @ v.co) for v in me.vertices], dtype=np.float64).reshape(-1, 3)
        polys = [tuple(p.vertices) for p in me.polygons]
        ev.to_mesh_clear()
        self.ok = len(polys) > 0
        if not self.ok:
            return
        self.bvh = BVHTree.FromPolygons([tuple(v) for v in self.V], polys)
        edges = Counter()
        vol = 0.0
        for p in polys:
            for i in range(len(p)):
                a, b = p[i], p[(i + 1) % len(p)]
                edges[(min(a, b), max(a, b))] += 1
            for i in range(1, len(p) - 1):
                vol += float(np.dot(self.V[p[0]], np.cross(self.V[p[i]], self.V[p[i + 1]])))
        self.closed = len(polys) > 3 and all(c == 2 for c in edges.values())
        self.sign = 1.0 if vol >= 0 else -1.0
        self.C = np.array([self.V[list(p)].mean(0) for p in polys])
        self.lo, self.hi = self.V.min(0), self.V.max(0)
        self.c = (self.lo + self.hi) * 0.5
        self.r = float(np.linalg.norm(self.V - self.c, axis=1).max())
        self.S = self.V[::max(1, len(self.V) // 160)]

    def depth(self, pts, keep=None):
        """Deepest any of `pts` (this part's rest space) sits inside this part."""
        if not self.closed:
            return 0.0
        m = np.all((pts > self.lo) & (pts < self.hi), axis=1)
        if keep is not None:
            m &= keep
        best = 0.0
        for p in pts[m]:
            v = Vector(p)
            loc, n, _, d = self.bvh.find_nearest(v)
            if loc is not None and d > best and (v - loc).dot(n) * self.sign < 0.0:
                best = d
        return best

    def inside(self, p):
        if not self.closed or np.any(p < self.lo) or np.any(p > self.hi):
            return False
        v = Vector(p)
        loc, n, _, _ = self.bvh.find_nearest(v)
        return loc is not None and (v - loc).dot(n) * self.sign < 0.0


def crossing(p, q, hidden=()):
    """(length of the crossing curve, its points) between two parts at rest, or
    None. The stretches of the curve buried inside the solids in `hidden` (the
    skull, the torso) cannot be seen and do not count."""
    if np.any(p.lo > q.hi) or np.any(q.lo > p.hi):
        return None
    pairs = p.bvh.overlap(q.bvh)
    if len(pairs) < 2:
        return None
    sides = []
    for part, idx in ((p, sorted({i for i, _ in pairs})), (q, sorted({j for _, j in pairs}))):
        pts = part.C[idx]
        if hidden:
            pts = pts[[not any(h.inside(c) for h in hidden) for c in pts]]
        if len(pts) > 1:
            sides.append(pts)
    if not sides:
        return None
    ext = min(float(np.linalg.norm(c.max(0) - c.min(0))) for c in sides)
    return ext, max(sides, key=len)


def pokes(part, x, cover):
    """True if `part` has vertices outside every closed part of `cover`, above
    the lowest point of their crossing `x`."""
    low = float(x[1][:, 2].min()) + 0.02
    count = 0
    for v in part.V:
        if v[2] > low and not any(q.inside(v) for q in cover):
            count += 1
            if count >= 3:
                return True
    return False


def intended(a, b):
    x, y = f"{a.group}/{a.name}", f"{b.group}/{b.name}"
    return any(re.search(rx, x + "|" + y) or re.search(rx, y + "|" + x) for rx, _ in INTENDED)


# ---------------------------------------------------------------------------
# Game data: accessory slots, clip styles
# ---------------------------------------------------------------------------

def read_enemy_data():
    """outfit -> clip style, and every accessory-slot list in data/enemies."""
    styles, slot_lists = {}, []
    root = os.path.normpath(os.path.join(HERE, "..", "..", "data", "enemies"))
    for path in glob.glob(os.path.join(root, "**", "*.tres"), recursive=True):
        text = open(path).read()
        outfit = re.search(r'^outfit = &"(\w+)"', text, re.M)
        style = re.search(r'^clip_style = &"(\w+)"', text, re.M)
        if outfit:
            styles[outfit.group(1)] = style.group(1) if style else ""
        for m in re.finditer(r"accessory_slots = PackedStringArray\((.*?)\)", text):
            slots = [[[n for n in opt.split("+") if n] for opt in s.split("|")] for s in re.findall(r'"([^"]*)"', m.group(1))]
            slot_lists.append(slots)
    return styles, slot_lists


def slots_for(outfit, acc_names, slot_lists):
    """The slot list of `outfit` whose accessories all exist in this model."""
    for slots in slot_lists:
        names = {n for s in slots for opt in s for n in opt}
        if names and names <= acc_names and all(n.startswith(f"Acc_{outfit}_") for n in names):
            return slots
    return []


def clips_for(outfit, style, clips):
    names = {c.name.removesuffix("-loop") for c in clips}
    out = []
    for c in clips:
        n = c.name.removesuffix("-loop")
        suffix = n.rsplit("_", 1)[-1] if "_" in n else ""
        if suffix in STYLES:
            if suffix != style:
                continue
        elif style and f"{n}_{style}" in names:
            continue
        base = n.removesuffix("_" + style) if style else n
        if base in EXCLUSIVE and outfit not in EXCLUSIVE[base]:
            continue
        out.append(c)
    return out


# ---------------------------------------------------------------------------
# Audits
# ---------------------------------------------------------------------------

def co_visible(slots):
    """(pairs of accessories from different slots, pairs designed as one '+' option)."""
    free, together = set(), set()
    for i, s in enumerate(slots):
        for opt in s:
            for a in opt:
                for b in opt:
                    if a < b:
                        together.add((a, b))
        for t in slots[i + 1:]:
            for a in {n for opt in s for n in opt}:
                for b in {n for opt in t for n in opt}:
                    if a != b:
                        free.add((min(a, b), max(a, b)))
    return free - together, together


def static_audit(outfit, groups, slots):
    out = []
    body = groups["Outfit_" + outfit]
    accs = {n: g for n, g in groups.items() if n.startswith(f"Acc_{outfit}_")}
    faces = {n: g for n, g in groups.items() if n.startswith(f"Face_{outfit}_")}
    head_feats = [p for p in body if p.bone == "Head" and not p.name.endswith("Skull")]
    solids = [p for p in body if p.closed and p.name.endswith(("Skull", "Torso", "Pelvis"))]
    feats = [p for p in body if p.bone != "Head" and FEATURE.search(p.name)]

    def label(p):
        """Faces count once per part type (not per preset), other parts by name."""
        if p.group.startswith("Face_"):
            return "Face:" + re.sub(r"\d+$", "", p.name.rsplit("_", 1)[-1])
        return p.group if p.group.startswith("Acc_") else re.sub(r"-?\d+$", "", p.name)

    def add(kind, a, b, ext):
        if not intended(a, b):
            out.append(dict(kind=kind, a=f"{a.group}/{a.name}", b=f"{b.group}/{b.name}", size=round(ext, 3),
                            key=f"{kind}: {label(a)} x {label(b)}"))

    free, _ = co_visible(slots)
    for na, nb in sorted(free):
        if na in accs and nb in accs:
            for a in accs[na]:
                for b in accs[nb]:
                    x = crossing(a, b, solids)
                    if x and x[0] >= CROSS:
                        add("acc-acc", a, b, x[0])
    for na, parts in accs.items():
        reach = max(q.r for q in parts)
        for a in parts:
            for fparts in faces.values():
                for f in fparts:
                    x = crossing(a, f, solids)
                    if x and x[0] >= CROSS * 0.75 and (a.bone != "Head" or pokes(f, x, parts)):
                        add("acc-face", a, f, x[0])
            if a.bone == "Head":
                for h in head_feats:
                    x = crossing(a, h, solids)
                    if x and x[0] >= CROSS and h.r < reach and pokes(h, x, parts):
                        add("headgear", h, a, x[0])
            else:
                for f in feats:
                    x = crossing(a, f, solids)
                    if x and x[0] >= CROSS:
                        add("acc-feature", a, f, x[0])
    for fparts in faces.values():
        for f in fparts:
            for h in head_feats:
                x = crossing(f, h, solids)
                if x and x[0] >= CROSS * 0.75 and pokes(f, x, [h]):
                    add("face-feature", f, h, x[0])
    return out


def clip_audit(outfit, groups, slots, clips, rig):
    body = groups["Outfit_" + outfit]
    accs = {n: g for n, g in groups.items() if n.startswith(f"Acc_{outfit}_")}
    parts = [p for p in body if p.r > 0.02] + [p for g in accs.values() for p in g if p.r > 0.02]
    exclusive = set()
    for s in slots:
        names = sorted({n for opt in s for n in opt})
        for a in names:
            for b in names:
                if a < b and not any(a in opt and b in opt for opt in s):
                    exclusive.add((a, b))
    n = len(parts)
    cand = []
    for i in range(n):
        for j in range(i + 1, n):
            a, b = parts[i], parts[j]
            if a.bone == b.bone:
                continue
            ga, gb = sorted((a.group, b.group))
            if (ga, gb) in exclusive:
                continue
            if not (a.closed or b.closed):
                continue
            cand.append((i, j))
    cand = np.array(cand)
    centres = np.array([p.c for p in parts])
    radii = np.array([p.r for p in parts])
    rsum = radii[cand[:, 0]] + radii[cand[:, 1]]
    bone_of = [p.bone for p in parts]
    rest_depth = {}
    found = {}
    ground = {}

    def pair_depth(a, b, Ra, ta, Rb, tb):
        # a's samples into b's rest space, and the other way round; samples
        # near either part's joint do not count (limb roots overlap by design).
        wa, wb = a.S @ Ra.T + ta, b.S @ Rb.T + tb
        ja, jb = Ra @ a.joint + ta, Rb @ b.joint + tb
        ka = (np.linalg.norm(wa - ja, axis=1) > JOINT) & (np.linalg.norm(wa - jb, axis=1) > JOINT)
        kb = (np.linalg.norm(wb - ja, axis=1) > JOINT) & (np.linalg.norm(wb - jb, axis=1) > JOINT)
        return max(b.depth((wa - tb) @ Rb, ka), a.depth((wb - ta) @ Ra, kb))

    eye = np.eye(3)
    zero = np.zeros(3)
    for clip in clips:
        cname = clip.name.removesuffix("-loop")
        for k in range(0, len(clip.poses), STEP):
            pose = clip.poses[k]
            pos, world = rig.fk(pose.rot, pose.hips)
            R, T = {}, {}
            for bname in rig.order:
                m = np.array(world[bname].to_matrix())
                h = np.array(rig.head[bname])
                R[bname] = m
                T[bname] = np.array(pos[bname]) - m @ h
            posed = np.array([R[bone_of[i]] @ centres[i] + T[bone_of[i]] for i in range(n)])
            gone = {b for b, k in pose.scale.items() if k < 0.5}    # a popped head
            if not cname.startswith("Emerge"):
                for i, p in enumerate(parts):
                    if p.bone not in gone and posed[i][2] - radii[i] < -GROUND:
                        z = float((p.S @ R[p.bone].T + T[p.bone])[:, 2].min())
                        if z < -GROUND:
                            key = (cname, f"{p.group}:{p.bone}")
                            ground[key] = min(ground.get(key, 0.0), z)
            d = np.linalg.norm(posed[cand[:, 0]] - posed[cand[:, 1]], axis=1)
            for i, j in cand[d < rsum]:
                a, b = parts[i], parts[j]
                if a.bone in gone or b.bone in gone:
                    continue
                dep = pair_depth(a, b, R[a.bone], T[a.bone], R[b.bone], T[b.bone])
                if dep < DEPTH:
                    continue
                key = (a.name, b.name)
                if key not in rest_depth:
                    rest_depth[key] = pair_depth(a, b, eye, zero, eye, zero)
                if dep - rest_depth[key] >= DEPTH and not intended(a, b):
                    fk = (cname, f"{a.group}:{a.bone}", f"{b.group}:{b.bone}")
                    if dep - rest_depth[key] > found.get(fk, (0.0, ""))[0]:
                        found[fk] = (dep - rest_depth[key], f"{a.name} x {b.name}")
    return ([dict(kind="clip", clip=c, a=a, b=b, size=round(v[0], 3), worst=v[1]) for (c, a, b), v in sorted(found.items())],
            [dict(kind="ground", clip=c, a=p, size=round(-z, 3)) for (c, p), z in sorted(ground.items())])


# ---------------------------------------------------------------------------
# Recording the builders
# ---------------------------------------------------------------------------

class Recorder:
    def __init__(self, wanted, verbose):
        self.groups, self.clips, self.rig = {}, [], None
        self.results = {}
        self.wanted, self.verbose = wanted, verbose
        self.styles, self.slot_lists = read_enemy_data()

    def skin(self, name, parts, armature):
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        joints = {b.name: np.array(b.head_local) for b in armature.data.bones}
        self.groups[name] = [p for p in (Part(ob, name, dg, joints) for ob in parts) if p.ok]
        return armature

    def bake(self, armature, clipset, model_name):
        self.rig = zombie_anim.Rig(armature)
        self.clips = clipset(self.rig)
        return self.clips

    def save(self, name, export_objects, animations=False):
        groups, self.groups = self.groups, {}
        if self.wanted and name not in self.wanted:
            return
        acc_names = {n for n in groups if n.startswith("Acc_")}
        for outfit in sorted(n[7:] for n in groups if n.startswith("Outfit_")):
            slots = slots_for(outfit, acc_names, self.slot_lists)
            st = static_audit(outfit, groups, slots)
            cl, gr = clip_audit(outfit, groups, slots, clips_for(outfit, self.styles.get(outfit, ""), self.clips), self.rig)
            key = f"{name}/{outfit}"
            self.results[key] = dict(static=st, clips=cl, ground=gr)
            conflicts = sorted({f["key"] for f in st})
            print(f"[audit] {key:26s} static {len(conflicts):3d} ({len(st)} part pairs)   clips {len(cl):3d}   ground {len(gr):3d}")
            if self.verbose:
                for c in conflicts:
                    print("     ", c, max(f["size"] for f in st if f["key"] == c))
                for f in cl + gr:
                    print("     ", f["kind"], f["clip"], f["a"], f.get("b", ""), f["size"], f.get("worst", ""))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) if "=" in a else (a[2:], "1") for a in sys.argv[1:] if a.startswith("--"))
    rec = Recorder(set(args), "verbose" in opts)
    import build_aqua_zombies
    import build_dune_zombies
    import build_frost_zombies
    import build_neon_zombies
    import build_zombie
    mods = (build_zombie, build_neon_zombies, build_aqua_zombies, build_dune_zombies, build_frost_zombies)
    zombie_anim.bake = rec.bake
    for mod in mods:
        mod.skin = rec.skin
        mod.save_zombie = rec.save
        mod.save = rec.save
    names = {build_zombie: {"zombie", "zombie_neon", "zombie_aqua", "zombie_dune", "zombie_frost"},
             build_neon_zombies: {"neon_punk", "neon_courier", "neon_riot"}, build_aqua_zombies: {"aqua_zombies"},
             build_dune_zombies: {"dune_zombies"}, build_frost_zombies: {"frost_zombies"}}
    for mod in mods:
        if not rec.wanted or rec.wanted & names[mod]:
            mod.build()
    tot, depth = Counter(), Counter()
    for r in rec.results.values():
        tot["static"] += len({f["key"] for f in r["static"]})
        tot["static part pairs"] += len(r["static"])
        tot["clips"] += len(r["clips"])
        tot["ground"] += len(r["ground"])
        depth["clips"] += sum(f["size"] for f in r["clips"])
        depth["ground"] += sum(f["size"] for f in r["ground"])
    print("[audit] TOTAL " + ", ".join(f"{k} {v}" for k, v in tot.items())
          + "; summed depth: " + ", ".join(f"{k} {v:.1f} m" for k, v in depth.items()))
    if "json" in opts:
        with open(opts["json"], "w") as f:
            json.dump(rec.results, f, indent=1)


if __name__ == "__main__":
    main()
