"""Intersection and contract audit of the weapon viewmodels.

Opens each weapon's .blend (written by build_weapons*.py) and checks:

  nodes      the nodes and empties the game relies on exist
  sight      nothing but the IronSight* parts rises above the eye line
             (SightPoint height), and the rail is clear around SightMount
  charm      nothing a hanging charm can reach stands proud of the side the
             charm lug is on (the plane WeaponCharm keeps the charm outside)
  hands      at rest: the arms cut into nothing (weapon or each other)
  reload     at every sample of the reload animation (poses dumped from the
             game by tools/weapon_pose_dump.gd): the arms cut into nothing,
             and no pair of other parts overlaps that did not at rest

    godot --headless --path . --script res://tools/weapon_pose_dump.gd -- /tmp/poses.json
    python art/blender/audit_weapons.py /tmp/poses.json [weapon_id ...]

Prints one line per finding and "AUDIT OK" or "AUDIT FAILED (n)" at the end.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

from weapon_kit import CHARM_STANDOFF, RAIL_FLAT  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
WEAPONS = ["pulse_pistol", "ion_carbine", "scatter_blaster", "comet_cannon", "arc_coil", "bumper_lobber", "cryo_beam", "rail_lancer"]
REQUIRED = ["Shell", "ArmL", "ArmR", "Decal", "IronSightRear", "IronSightFront",
            "Muzzle", "SightPoint", "SightMount", "EjectPoint", "VentPoint", "CharmPoint", "ElbowL", "ElbowR"]
# The energy cell and its hologram copy (the Scatter Blaster loads two capsules instead).
CELLS = {"scatter_blaster": ["Capsules", "CapsulesHolo"]}
# Godot (Y up, -Z forward) -> Blender (Z up, +Y forward).
TO_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
# How far below the ring a charm reaches, and how far it swings along the barrel.
CHARM_DROP = 0.115
CHARM_SWING = 0.07
# Parts that are built to overlap while they move (an axle in its housing...).
JOINTS = {
    "pulse_pistol": [("Slide", "Shell"), ("Cell", "Shell"), ("Hammer", "Slide")],
    "ion_carbine": [("Panel", "Shell"), ("Vents", "Shell")],
    "scatter_blaster": [("Barrels", "Shell"), ("Drum", "Shell"), ("Pump", "Barrels"), ("Capsules", "Barrels"), ("Capsules", "Shell")],
    "comet_cannon": [("Crane", "Shell"), ("Cylinder", "Crane"), ("Cell", "Cylinder"), ("Hammer", "Shell")],
    "arc_coil": [("Prongs", "Shell"), ("Vents", "Shell"), ("Cell", "Shell")],
    "bumper_lobber": [("Lid", "Shell"), ("Crank", "Shell"), ("Cell", "Shell")],
    "cryo_beam": [("Panel", "Shell"), ("Fins", "Shell"), ("Needle", "Shell"), ("Cell", "Shell"), ("Cell", "Panel")],
    "rail_lancer": [("Rails", "Shell"), ("Cell", "Shell")],
}


def world_tree(ob, matrix=None):
    mw = matrix if matrix is not None else ob.matrix_world
    verts = [mw @ v.co for v in ob.data.vertices]
    polys = [tuple(p.vertices) for p in ob.data.polygons]
    return BVHTree.FromPolygons(verts, polys, epsilon=0.0), verts, polys


def where(tree_a, tree_b):
    """Number of overlapping face pairs and roughly where (centre of the first tree's faces involved)."""
    hits = tree_a[0].overlap(tree_b[0])
    if not hits:
        return 0, ""
    _t, verts, polys = tree_a
    total = Vector((0, 0, 0))
    count = 0
    for ia, _ib in hits:
        for vi in polys[ia]:
            total += verts[vi]
            count += 1
    c = total / count
    return len(hits), f"near ({c.x:.3f}, {c.y:.3f}, {c.z:.3f})"


def box_tree(lo, hi):
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    verts = [Vector(c) for c in ((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
    polys = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return BVHTree.FromPolygons(verts, polys, epsilon=0.0)


def godot_matrix(row):
    """12 floats (basis columns x, y, z then origin, Godot axes) -> Blender-space matrix."""
    bx, by, bz, o = row[0:3], row[3:6], row[6:9], row[9:12]
    m = Matrix(((bx[0], by[0], bz[0], o[0]), (bx[1], by[1], bz[1], o[1]), (bx[2], by[2], bz[2], o[2]), (0, 0, 0, 1)))
    return TO_BLENDER @ m @ TO_BLENDER.inverted()


def audit(name, poses, verbose=True):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, name + ".blend"))
    bpy.context.view_layer.update()
    objs = {o.name: o for o in bpy.data.collections["Export"].objects}
    meshes = {k: o for k, o in objs.items() if o.type == "MESH"}
    problems = []

    def bad(kind, text):
        problems.append(f"{name}: {kind}: {text}")

    for req in REQUIRED + CELLS.get(name, ["Cell", "CellHolo"]):
        if req not in objs:
            bad("nodes", f"missing {req}")
    if problems:
        return problems

    solid = {k: o for k, o in meshes.items() if not k.endswith("Holo") and k != "Decal"}
    trees = {k: world_tree(o) for k, o in solid.items()}

    # --- sight line ------------------------------------------------------------
    eye = objs["SightPoint"].matrix_world.translation
    mount = objs["SightMount"].matrix_world.translation
    for k, (_t, verts, _p) in trees.items():
        top = max(v.z for v in verts)
        if k.startswith("IronSight"):
            near = [v for v in verts if abs(v.y - mount.y) < RAIL_FLAT / 2 and abs(v.x - mount.x) < 0.03 and v.z > mount.z + 0.0005]
            if near:
                bad("sight", f"{k} stands on the optic's place on the rail")
            continue
        if top > eye.z - 0.002:
            bad("sight", f"{k} rises {top - eye.z + 0.002:.4f} above the eye line (z {top:.4f} vs {eye.z:.4f})")
        over = [v for v in verts if abs(v.y - mount.y) < RAIL_FLAT / 2 and abs(v.x - mount.x) < 0.03 and v.z > mount.z + 0.0005]
        if over:
            bad("sight", f"{k} stands on the optic's place on the rail ({max(v.z for v in over) - mount.z:.4f} above it)")
    if abs(eye.x - mount.x) > 1e-4:
        bad("sight", "SightPoint and SightMount are not in line")

    # --- charm zone -------------------------------------------------------------
    ring = objs["CharmPoint"].matrix_world.translation
    centre_x = sum(v.x for v in trees["Shell"][1]) / len(trees["Shell"][1])
    out = -1.0 if ring.x < centre_x else 1.0
    wall = ring.x - out * CHARM_STANDOFF
    x_far = ring.x + out * 0.12
    lo = (min(wall + out * 0.0006, x_far), ring.y - CHARM_SWING, ring.z - CHARM_DROP)
    hi = (max(wall + out * 0.0006, x_far), ring.y + CHARM_SWING, ring.z - 0.009)
    zone = box_tree(lo, hi)
    for k, tree in trees.items():
        n, spot = where(tree, (zone,))
        if n:
            bad("charm", f"{k} stands proud of the charm's side inside its reach ({n} faces {spot})")

    # --- hands at rest -----------------------------------------------------------
    def overlaps(a, b, cache):
        return len(cache[a][0].overlap(cache[b][0]))


    arms = [k for k in solid if k.startswith("Arm")]
    others = [k for k in solid if not k.startswith("Arm")]
    for arm in arms:
        for k in others:
            n, spot = where(trees[arm], trees[k])
            if n:
                bad("hands", f"{arm} cuts into {k} at rest ({n} face pairs {spot})")
    if overlaps("ArmL", "ArmR", trees):
        bad("hands", "ArmL cuts into ArmR at rest")
    # Glove shapes (ArmRKit*, ArmLKit*) must also clear the other hand.
    for kit in [k for k in arms if "Kit" in k]:
        other = "ArmL" if kit.startswith("ArmR") else "ArmR"
        if overlaps(kit, other, trees):
            bad("hands", f"{kit} cuts into {other} at rest")

    # --- reload -----------------------------------------------------------------------
    joints = set()
    for a, b in JOINTS.get(name, []):
        joints.add((a, b))
        joints.add((b, a))
    rest_pairs = set()
    keys = sorted(others)
    for i, a in enumerate(keys):
        for b in keys[i + 1:]:
            if overlaps(a, b, trees):
                rest_pairs.add((a, b))
    data = poses.get(name)
    if data is None:
        bad("reload", "no poses dumped")
        return problems
    found = {}
    for si, t in enumerate(data["times"]):
        posed = {}
        shown = {}
        for k, ob in solid.items():
            rows = data["parts"].get(k)
            if rows is None:
                continue
            row = rows[si]
            shown[k] = bool(row[12])
            m = godot_matrix(row)
            moved = max(abs(m[i][j] - ob.matrix_world[i][j]) for i in range(3) for j in range(4)) > 1e-5
            if moved and si == 0:
                bad("reload", f"{k}: the dumped rest pose does not match the .blend (rebuild and re-import first)")
            posed[k] = world_tree(ob, m) if moved else trees[k]
        live = [k for k in posed if shown.get(k, False)]
        for arm in [k for k in live if k.startswith("Arm")]:
            for k in live:
                # A hand's glove shapes sit on it by design: only the other hand counts.
                if k == arm or (k.startswith("Arm") and (k < arm or k[:4] == arm[:4])):
                    continue
                n, spot = where(posed[arm], posed[k])
                if n:
                    found.setdefault(("hands", arm, k), []).append((t, n, spot))
        body = sorted(k for k in live if not k.startswith("Arm"))
        for i, a in enumerate(body):
            for b in body[i + 1:]:
                if (a, b) in rest_pairs or (a, b) in joints:
                    continue
                if posed[a] is trees[a] and posed[b] is trees[b]:
                    continue
                n, spot = where(posed[a], posed[b])
                if n:
                    found.setdefault(("parts", a, b), []).append((t, n, spot))
    for (kind, a, b), hits in sorted(found.items()):
        times = ", ".join(f"{h[0]:.2f}" for h in hits[:8]) + ("..." if len(hits) > 8 else "")
        worst = max(hits, key=lambda h: h[1])
        bad("reload", f"{a} cuts into {b} at t = {times} (worst {worst[1]} face pairs {worst[2]} at t = {worst[0]:.2f})")
    return problems


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if not args:
        print(__doc__)
        return
    poses = json.load(open(args[0]))
    names = args[1:] or WEAPONS
    total = 0
    for name in names:
        problems = audit(name, poses)
        total += len(problems)
        for p in problems:
            print(p)
        print(f"[audit] {name}: {len(problems)} findings")
    print("AUDIT OK" if total == 0 else f"AUDIT FAILED ({total})")


if __name__ == "__main__":
    main()
