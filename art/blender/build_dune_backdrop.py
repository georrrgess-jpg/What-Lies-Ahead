"""Desert backdrop for Dune Spaceport: layered mesas, buttes, hoodoos and dunes.

    dune_mesa_a.glb        broad flat-topped mesa, ~90 x 60 m, 34 m tall
    dune_mesa_b.glb        smaller, stepped mesa
    dune_butte.glb         tall, narrow butte
    dune_hoodoo.glb        balanced rock spire
    dune_sanddune_a.glb / dune_sanddune_b.glb   smooth crescent dunes (70 x 40 m, 50 x 30 m)
    dune_radio_mast.glb    38 m lattice mast with red lights

Faceted, flat-shaded strata in rust, orange and cream. Origins at the centre of the base.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dune_kit import *  # noqa: F401,F403
from dune_kit import _finish  # noqa: F401


def slab(name, outline, z0, z1, m, top_scale=1.0):
    """Vertical-sided (or slightly tapered) slab from an XY outline."""
    bm = bmesh.new()
    lo = [bm.verts.new((x, y, z0)) for x, y in outline]
    hi = [bm.verts.new((x * top_scale, y * top_scale, z1)) for x, y in outline]
    n = len(outline)
    bm.faces.new(list(reversed(lo)))
    bm.faces.new(hi)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish(name, bm, m, (0, 0, 0), (0, 0, 0), smooth=False)
    return make_flat(ob)


def outline(rng, rx, ry, n=18, rough=0.18, seed_phase=0.0):
    """Irregular closed outline: broad lobes, a little noise."""
    p1, p2 = rng.uniform(0, math.tau), rng.uniform(0, math.tau)
    pts = []
    for i in range(n):
        a = math.tau * i / n + seed_phase
        k = 1.0 + 0.16 * math.sin(a * 3 + p1) + 0.08 * math.sin(a * 5 + p2) + rng.uniform(-rough, rough) * 0.4
        pts.append((math.cos(a) * rx * k, math.sin(a) * ry * k))
    return pts


def shrink(pts, f, rng, jitter=0.04):
    return [(x * f * (1 + rng.uniform(-jitter, jitter)), y * f * (1 + rng.uniform(-jitter, jitter))) for x, y in pts]


def strata_mesa(prefix, rng, rx, ry, height, layers, cols, talus_col, cap_col, step=0.99):
    """Near-vertical banded cliffs on a concave talus apron, with gullies cut
    down the walls (some outline points pulled in through every layer)."""
    parts = []
    n = 40
    base = outline(rng, rx, ry, n=n, rough=0.16, seed_phase=rng.uniform(0, 3))
    gully = [1.0] * n
    for _ in range(n // 6):
        i = rng.randrange(n)
        gully[i] = rng.uniform(0.82, 0.9)
    base = [(x * g, y * g) for (x, y), g in zip(base, gully)]
    # Talus: three tapered rings, steepening toward the cliff foot.
    for k, (f0, f1, z0, z1) in enumerate(((1.55, 1.3, -2.0, height * 0.06), (1.3, 1.12, height * 0.06, height * 0.13),
                                          (1.12, 1.02, height * 0.13, height * 0.19))):
        parts.append(slab(f"{prefix}Talus{k}", shrink(base, f0, rng, 0.02), z0, z1, talus_col, top_scale=f1 / f0))
    z = height * 0.18
    cur = shrink(base, 1.0, rng, 0.01)
    weights = [rng.uniform(0.6, 1.4) for _ in range(layers)]
    total = sum(weights)
    for k in range(layers):
        lh = (height - height * 0.18) * weights[k] / total
        m = cols[k % len(cols)]
        parts.append(slab(f"{prefix}L{k:02d}", cur, z, z + lh, m, top_scale=1.0 - rng.uniform(0.0, 0.012)))
        if k % 3 == 1:
            parts.append(slab(f"{prefix}Ledge{k:02d}", shrink(cur, 1.025, rng, 0.01), z + lh - 0.5, z + lh, cap_col))
        cur = shrink(cur, step + rng.uniform(-0.01, 0.006), rng, 0.012)
        z += lh
    parts.append(slab(prefix + "Cap", shrink(cur, 1.02, rng, 0.01), z, z + 1.0, cap_col, top_scale=0.985))
    return parts


def dune(prefix, rng, length, width, height, m):
    """Crescent dune: gentle windward slope, steep lee face, sharp crest."""
    bm = bmesh.new()
    nx, ny = 28, 18
    verts = []
    for j in range(ny + 1):
        row = []
        v = j / ny * 2 - 1                    # -1 windward .. 1 lee
        for i in range(nx + 1):
            u = i / nx * 2 - 1
            along = math.cos(u * math.pi / 2) ** 1.4
            crest = 0.25 * (1 - u * u)          # crest bends forward in the middle (crescent)
            if v < crest:
                h = ((v + 1) / (crest + 1)) ** 1.6
            else:
                h = max(0.0, 1 - (v - crest) / (1 - crest)) ** 0.7
            z = height * h * along + rng.uniform(-0.05, 0.05)
            row.append(bm.verts.new((u * length / 2, v * width / 2, z - 0.5)))
        verts.append(row)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _finish(prefix, bm, m, (0, 0, 0), (0, 0, 0), smooth=True)
    return [ob]


def build():
    reset_scene()
    rng = random.Random(9)
    rust, orange = dmat("RockRust", "#b9552f", rough=0.95), dmat("RockOrange", "#d6763f", rough=0.95)
    cream, deep = dmat("RockCream", "#e4ad78", rough=0.95), dmat("RockDeep", "#8e3f2a", rough=0.95)
    talus, cap = dmat("RockTalus", "#c98a5a", rough=0.95), dmat("RockCap", "#a54a2c", rough=0.95)
    sand, sand_lee = dmat("DuneSand", "#e7b47c", rough=1.0), dmat("DuneSandLee", "#d99d64", rough=1.0)
    cols = [orange, rust, cream, orange, deep, cream]
    exports = {}
    exports["dune_mesa_a"] = [merge("MesaA", strata_mesa("MA", rng, 46, 30, 34, 9, cols, talus, cap))]
    exports["dune_mesa_b"] = [merge("MesaB", strata_mesa("MB", rng, 26, 20, 22, 6, [rust, cream, orange, deep], talus, cap, step=0.96))]
    exports["dune_butte"] = [merge("Butte", strata_mesa("BU", rng, 10, 8, 30, 8, [cream, orange, rust, deep], talus, cap, step=0.995))]
    hoodoo = [slab("HoStem0", outline(rng, 3.0, 2.6, 10, 0.2), -1.0, 6.0, orange, 0.8),
              slab("HoStem1", outline(rng, 2.4, 2.1, 10, 0.2), 6.0, 11.0, cream, 0.7),
              slab("HoNeck", outline(rng, 1.6, 1.4, 9, 0.2), 11.0, 13.5, rust, 1.1),
              slab("HoCap", outline(rng, 3.4, 3.0, 11, 0.15), 13.5, 15.8, deep, 0.85)]
    exports["dune_hoodoo"] = [merge("Hoodoo", hoodoo)]
    exports["dune_sanddune_a"] = [merge("DuneA", dune("DA", rng, 70, 40, 9, sand))]
    exports["dune_sanddune_b"] = [merge("DuneB", dune("DB", rng, 50, 30, 6, sand_lee))]
    # Radio mast: triangular lattice with red lights.
    steel = dmat("Rust", rough=0.55)
    red = dglow("Beacon", "#ff4a3a", 3.0)
    mast = []
    r, H = 0.9, 38.0
    corners = [(math.cos(math.tau * i / 3) * r, math.sin(math.tau * i / 3) * r) for i in range(3)]
    for i, (x, y) in enumerate(corners):
        mast.append(beam(f"MastLeg{i}", (x, y, 0), (x * 0.5, y * 0.5, H), 0.12, m=steel))
    for k in range(12):
        z = k * H / 12
        t = 1 - 0.5 * z / H
        for i in range(3):
            a, b = corners[i], corners[(i + 1) % 3]
            mast.append(beam(f"MastRung{k}{i}", (a[0] * t, a[1] * t, z), (b[0] * t, b[1] * t, z + H / 12), 0.06, m=steel))
    for z in (H * 0.5, H):
        mast.append(bulb(f"MastLight{int(z)}", 0.3, (0, 0, z + 0.3), red))
    exports["dune_radio_mast"] = [merge("RadioMast", mast)]
    save_split("dune_backdrop", exports)


if __name__ == "__main__":
    build()
