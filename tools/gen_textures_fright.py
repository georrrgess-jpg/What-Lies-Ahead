"""Generates the hand-rolled textures for World 11, Fright Fair (no third-party art):

    art/textures/fright_cobble.png        violet-grey cobbles with mossy grout (+ _normal), 512
    art/textures/fright_turf.png          midnight turf with fallen orange and plum leaves, 512
    art/textures/fright_boards.png        weathered plum-brown boards, a few painted (+ _normal), 512

The sky is a shader (art/shaders/fright_sky.gdshader), so it needs no texture.

    python tools/gen_textures_fright.py            (needs numpy + Pillow)
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_textures_sky import OUT, blur, hexc, normal_from_height, periodic_noise, save_rgb, smooth  # noqa: E402


def make_cobble(size=512, seed=211):
    """Rounded cobbles on a jittered grid (Voronoi cells), violet-grey with
    mossy green-black grout and a little wear."""
    rng = np.random.default_rng(seed)
    cells = 9
    pts = []
    for j in range(cells):
        for i in range(cells):
            pts.append(((i + 0.5 + rng.uniform(-0.3, 0.3)) / cells, (j + 0.5 + rng.uniform(-0.3, 0.3)) / cells))
    pts = np.array(pts)
    y = (np.arange(size)[:, None] + 0.5) / size
    x = (np.arange(size)[None, :] + 0.5) / size
    d1 = np.full((size, size), 9.0)
    d2 = np.full((size, size), 9.0)
    owner = np.zeros((size, size), dtype=int)
    for k, (px, py) in enumerate(pts):
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                d = np.sqrt((x - px - ox) ** 2 + (y - py - oy) ** 2)
                closer = d < d1
                d2 = np.where(closer, d1, np.minimum(d2, d))
                owner = np.where(closer, k, owner)
                d1 = np.where(closer, d, d1)
    edge = d2 - d1
    stone = smooth(0.006, 0.03, edge)
    dome = np.clip(edge * cells * 2.2, 0, 1) ** 0.5
    tone = rng.uniform(0.85, 1.12, len(pts))[owner]
    tint = rng.integers(0, 3, len(pts))[owner]
    cols = np.stack([hexc("#7a7192"), hexc("#6a6286"), hexc("#857a8e")])[tint]
    wear = periodic_noise(rng, size, beta=1.5, low_cut=2.0)
    albedo = cols * (tone * (0.82 + wear * 0.22))[..., None] * (0.75 + 0.25 * dome)[..., None]
    grout = hexc("#1f2a22") * (0.8 + wear[..., None] * 0.6)
    moss = hexc("#3d6a3a")
    grout = grout * (1 - smooth(0.4, 0.7, wear))[..., None] + moss * smooth(0.4, 0.7, wear)[..., None] * 0.7
    albedo = albedo * stone[..., None] + grout * (1 - stone[..., None])
    save_rgb("fright_cobble.png", albedo)
    save_rgb("fright_cobble_normal.png", normal_from_height(blur(stone * (0.6 + 0.4 * dome), 1), 3.0))


def make_turf(size=512, seed=213):
    """Dark night turf, cool green-violet, with scattered fallen leaves."""
    rng = np.random.default_rng(seed)
    n = periodic_noise(rng, size, beta=1.7, low_cut=2.0)
    m = periodic_noise(rng, size, beta=1.0, low_cut=30.0)
    albedo = hexc("#3f5a48") * (0.75 + n[..., None] * 0.35) + hexc("#2a2440") * (m[..., None] - 0.5) * 0.4
    leaf_cols = [hexc(c) for c in ("#d86a1e", "#b8501a", "#7a3a6a", "#e0a040")]
    yy, xx = np.mgrid[0:size, 0:size]
    for _ in range(90):
        cx, cy = rng.uniform(0, size, 2)
        r = rng.uniform(3, 7)
        a = rng.uniform(0, math.pi)
        dx = (xx - cx + size / 2) % size - size / 2
        dy = (yy - cy + size / 2) % size - size / 2
        u = dx * math.cos(a) + dy * math.sin(a)
        v = -dx * math.sin(a) + dy * math.cos(a)
        mask = (u / r) ** 2 + (v / (r * 0.5)) ** 2 < 1.0
        albedo[mask] = leaf_cols[rng.integers(len(leaf_cols))] * rng.uniform(0.75, 1.0)
    save_rgb("fright_turf.png", albedo)


def make_boards(size=512, planks=8, seed=215):
    """Weathered plum-brown boards with dark seams, nails, and a few planks
    painted purple or orange."""
    rng = np.random.default_rng(seed)
    ph = size // planks
    albedo = np.zeros((size, size, 3))
    height = np.ones((size, size))
    palette = [hexc(c) for c in ("#6a4038", "#5e3a36", "#74483c", "#56342e")]
    paint = [hexc(c) for c in ("#6a45a8", "#d8701e")]
    for p in range(planks):
        y0, y1 = p * ph, (p + 1) * ph
        base = palette[rng.integers(len(palette))] * rng.uniform(0.92, 1.06)
        if p in (1, 5):
            base = base * 0.45 + paint[p % 2] * 0.55
        grain = periodic_noise(rng, size, beta=1.3, low_cut=3.0)[y0:y1]
        streak = np.sin(np.linspace(0, math.tau * rng.uniform(4, 8), size) + rng.uniform(0, 6))[None, :]
        albedo[y0:y1] = base * (0.86 + grain * 0.24 + streak * 0.04)[..., None]
        seam = np.ones(ph)
        seam[:2] = 0.0
        seam[2:4] = 0.6
        height[y0:y1] *= seam[:, None]
        j = int(rng.uniform(0, size))
        height[y0:y1, j % size] *= 0.25
        height[y0:y1, (j + 1) % size] *= 0.65
        for nx in (j + 8, j - 8):
            for ny in (y0 + ph // 3, y0 + 2 * ph // 3):
                albedo[ny - 2:ny + 2, (nx - 2) % size:(nx - 2) % size + 4] = hexc("#2a1c22")
    albedo = albedo * (0.55 + 0.45 * height[..., None])
    save_rgb("fright_boards.png", albedo)
    save_rgb("fright_boards_normal.png", normal_from_height(blur(height, 1), 2.2))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    wanted = sys.argv[1:] or ["cobble", "turf", "boards"]
    for key in wanted:
        globals()["make_" + key]()
