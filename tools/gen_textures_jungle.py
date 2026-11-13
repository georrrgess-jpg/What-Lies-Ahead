"""Generates the hand-rolled textures for World 7, Jungle Expedition (no third-party art).
The sky, the water and the waterfall are shaders, so only surfaces are written here:

    art/textures/jungle_grass.png          tileable lush grass and clover, 1 tile = ~4 m
    art/textures/jungle_dirt.png           tileable trail dirt with pebbles and fallen leaves
    art/textures/jungle_stone.png          sandstone temple masonry with moss in the joints (+ _normal)
    art/textures/jungle_planks.png         weathered boardwalk planks (+ _normal)

    python tools/gen_textures_jungle.py            (needs numpy + Pillow)
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_textures_frost import OUT, blur, hexc, normal_from_height, periodic_noise, save_rgb, smooth  # noqa: E402

SIZE = 512


def _blades(rng, size, count, length, colours):
    """Short soft strokes (grass blades, leaves) stamped on a tileable canvas."""
    canvas = np.zeros((size, size, 3))
    weight = np.zeros((size, size))
    ys, xs = np.mgrid[-length:length + 1, -length:length + 1]
    for _ in range(count):
        cx, cy = rng.integers(0, size, 2)
        a = rng.uniform(0, math.pi)
        ca, sa = math.cos(a), math.sin(a)
        along = xs * ca + ys * sa
        across = -xs * sa + ys * ca
        w = rng.uniform(0.9, 1.9)
        mask = np.clip(1 - np.abs(across) / w, 0, 1) * np.clip(1 - np.abs(along) / length, 0, 1)
        col = colours[rng.integers(len(colours))] * rng.uniform(0.85, 1.15)
        yi = (ys + cy) % size
        xi = (xs + cx) % size
        canvas[yi, xi] += mask[..., None] * col
        weight[yi, xi] += mask
    return canvas, weight


def make_grass(size=SIZE, seed=71):
    rng = np.random.default_rng(seed)
    low = periodic_noise(rng, size, beta=2.2, low_cut=2.0)
    mid = periodic_noise(rng, size, beta=1.4, low_cut=8.0)
    base = hexc("#3f8f3c") * (1 - low[..., None] * 0.35) + hexc("#7fb83f") * (low[..., None] * 0.35)
    base *= 0.82 + mid[..., None] * 0.3
    blades, weight = _blades(rng, size, 2600, 7, [hexc("#5fae3f"), hexc("#8ccf4f"), hexc("#2f7a3a"), hexc("#a8d65a")])
    k = np.clip(weight, 0, 1)[..., None]
    albedo = base * (1 - k * 0.7) + (blades / np.maximum(weight, 1e-6)[..., None]) * k * 0.7
    # Clover and moss clumps.
    clump = smooth(0.62, 0.8, periodic_noise(rng, size, beta=1.8, low_cut=4.0))[..., None]
    albedo = albedo * (1 - clump * 0.4) + hexc("#2d6b33") * clump * 0.4
    save_rgb("jungle_grass.png", albedo)


def make_dirt(size=SIZE, seed=72):
    rng = np.random.default_rng(seed)
    n = periodic_noise(rng, size, beta=1.7, low_cut=3.0)
    grit = periodic_noise(rng, size, beta=0.8, low_cut=60.0)
    albedo = hexc("#8a5e3b") * (0.82 + n[..., None] * 0.3) * (0.92 + grit[..., None] * 0.14)
    # Pebbles.
    ys, xs = np.mgrid[0:size, 0:size]
    for _ in range(140):
        cx, cy = rng.uniform(0, size, 2)
        r = rng.uniform(2.0, 5.5)
        dx = np.minimum(np.abs(xs - cx), size - np.abs(xs - cx))
        dy = np.minimum(np.abs(ys - cy), size - np.abs(ys - cy))
        d = np.sqrt(dx * dx + dy * dy) / r
        m = np.clip(1 - d, 0, 1) ** 0.6
        tone = hexc("#c4a27c") if rng.uniform() < 0.6 else hexc("#6d5a4a")
        albedo = albedo * (1 - m[..., None] * 0.8) + tone * m[..., None] * 0.8
    # Fallen leaves (greens and ochres).
    leaves, weight = _blades(rng, size, 260, 9, [hexc("#5d8f3a"), hexc("#c08a3a"), hexc("#8a6a2a"), hexc("#3f7a3a")])
    k = np.clip(weight, 0, 1)[..., None] * 0.85
    albedo = albedo * (1 - k) + (leaves / np.maximum(weight, 1e-6)[..., None]) * k
    save_rgb("jungle_dirt.png", albedo)


def make_stone(size=SIZE, seed=73, rows=4):
    """Running-bond sandstone blocks, bevelled, with moss creeping out of the joints."""
    rng = np.random.default_rng(seed)
    rh = size // rows
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64)
    height = np.ones((size, size))
    albedo = np.zeros((size, size, 3))
    palette = [hexc(c) for c in ("#c9a27a", "#d4ae84", "#b8906c", "#cfa27a", "#bf9a74")]
    grit = periodic_noise(rng, size, beta=1.0, low_cut=50.0)
    stain = periodic_noise(rng, size, beta=2.0, low_cut=2.0)
    for r in range(rows):
        y0 = r * rh
        cols = 2 if r % 2 == 0 else 3
        bw = size // cols
        off = (r % 2) * bw // 2
        for c in range(cols + 1):
            x0 = (c * bw + off) % size
            col = palette[rng.integers(len(palette))] * rng.uniform(0.92, 1.06)
            xi = (np.arange(bw) + x0) % size
            block = (slice(y0, y0 + rh), xi)
            u = np.arange(bw)[None, :]
            v = np.arange(rh)[:, None]
            edge = np.minimum(np.minimum(u, bw - 1 - u), np.minimum(v, rh - 1 - v)).astype(np.float64)
            bevel = smooth(2.0, 12.0, edge)
            albedo[block] = col * (0.8 + 0.2 * bevel)[..., None]
            height[block] = bevel
    albedo *= (0.88 + grit[..., None] * 0.2) * (0.85 + stain[..., None] * 0.25)
    joint = 1 - smooth(0.05, 0.4, height)
    albedo = albedo * (1 - joint[..., None]) + hexc("#5a4636") * joint[..., None]
    patch = smooth(0.55, 0.8, periodic_noise(rng, size, beta=1.8, low_cut=3.0))
    moss = np.clip(joint * smooth(0.35, 0.6, patch + 0.2) + patch * smooth(0.5, 0.75, grit + patch * 0.4) * 0.9, 0, 1)
    m = moss[..., None]
    albedo = albedo * (1 - m) + (hexc("#4f8a34") * (0.75 + grit[..., None] * 0.45)) * m
    save_rgb("jungle_stone.png", albedo)
    save_rgb("jungle_stone_normal.png", normal_from_height(blur(height + grit * 0.08, 1), 3.0))


def make_planks(size=SIZE, planks=6, seed=74):
    rng = np.random.default_rng(seed)
    ph = size // planks
    albedo = np.zeros((size, size, 3))
    height = np.ones((size, size))
    palette = [hexc(c) for c in ("#9c7048", "#8a6040", "#a87a50", "#7e5a3c", "#94683f")]
    for p in range(planks):
        y0, y1 = p * ph, (p + 1) * ph
        base = palette[rng.integers(len(palette))] * rng.uniform(0.92, 1.06)
        grain = periodic_noise(rng, size, beta=1.4, low_cut=3.0)[y0:y1]
        streak = np.sin(np.linspace(0, math.tau * rng.uniform(3, 7), size) + rng.uniform(0, 6))[None, :]
        albedo[y0:y1] = base * (0.86 + grain * 0.24 + streak * 0.04)[..., None]
        seam = np.ones(ph)
        seam[:3] = 0.0
        seam[3:5] = 0.55
        height[y0:y1] *= seam[:, None]
        j = int(rng.uniform(0, size))
        height[y0:y1, j % size] *= 0.2
        height[y0:y1, (j + 1) % size] *= 0.6
        # Nail heads.
        for nx in (j + 10, j + size // 2):
            cy = y0 + ph // 2
            albedo[cy - 2:cy + 2, nx % size] = hexc("#3a3a3a")
    damp = smooth(0.6, 0.85, periodic_noise(rng, size, beta=1.8, low_cut=3.0))[..., None]
    albedo = albedo * (0.55 + 0.45 * height[..., None])
    albedo = albedo * (1 - damp * 0.35) + hexc("#5a7a3a") * damp * 0.25
    save_rgb("jungle_planks.png", albedo)
    save_rgb("jungle_planks_normal.png", normal_from_height(blur(height, 1), 2.5))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    wanted = sys.argv[1:] or ["grass", "dirt", "stone", "planks"]
    for key in wanted:
        globals()["make_" + key]()
