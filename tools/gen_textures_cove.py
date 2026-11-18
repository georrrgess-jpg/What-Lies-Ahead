"""Generates the hand-rolled textures for World 13, Pirate Cove (no third-party art):

    art/textures/cove_quay.png      warm sandstone cobbles in running courses (+ _normal), 512
    art/textures/cove_planks.png    weathered dock planks, sun-bleached, a few tarred (+ _normal), 512
    art/textures/cove_sand.png      damp cove sand with shell flecks and ripples, 512

The sunset sky, the sea and the waterfall are shaders (art/shaders/cove_*.gdshader),
so they need no texture.

    python tools/gen_textures_cove.py [quay] [planks] [sand]     (needs numpy + Pillow)
"""
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_textures_sky import blur, hexc, normal_from_height, periodic_noise, smooth  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "textures")


def save_rgb(name, arr):
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGB")
    img.save(os.path.join(OUT, name), optimize=True)
    print(name, img.size)


def make_quay(size=512, rows=8, seed=131):
    """Rounded sandstone setts in running courses (each course offset by half a stone)."""
    rng = np.random.default_rng(seed)
    y = (np.arange(size)[:, None] + 0.5) / size * rows
    x = (np.arange(size)[None, :] + 0.5) / size * rows * 0.75
    row = np.floor(y)
    xo = x + (row % 2) * 0.5
    col = np.floor(xo)
    fx, fy = xo - col, y - row
    # Rounded-rectangle distance to the stone's edge, then a domed height.
    ex = np.minimum(fx, 1 - fx) * 1.33
    ey = np.minimum(fy, 1 - fy)
    edge = np.minimum(ex, ey)
    dome = smooth(0.0, 0.16, edge)
    ids = (row * 37 + (col % (rows * 0.75)) * 11).astype(int)
    tones = [hexc(c) for c in ("#d9b48a", "#cfa47a", "#e2c29a", "#c79a70", "#d6ab80", "#bf8f68")]
    lut = np.array(tones)
    pick = lut[(ids * 7 + 3) % len(tones)]
    wear = periodic_noise(rng, size, beta=1.5, low_cut=2.0)
    fine = rng.uniform(0, 1, (size, size))
    stone = pick * (0.86 + wear[..., None] * 0.2 + fine[..., None] * 0.05)
    grout = hexc("#7d5a48") * (0.9 + wear[..., None] * 0.2)
    k = smooth(0.02, 0.07, edge)[..., None]
    albedo = stone * k + grout * (1 - k)
    albedo *= (0.82 + 0.18 * dome)[..., None]
    moss = smooth(0.62, 0.8, periodic_noise(rng, size, beta=1.2, low_cut=6.0)) * (1 - k[..., 0])
    albedo = albedo * (1 - moss[..., None] * 0.6) + hexc("#5f8a4c") * moss[..., None] * 0.6
    save_rgb("cove_quay.png", albedo)
    save_rgb("cove_quay_normal.png", normal_from_height(blur(dome, 1), 2.6))


def make_planks(size=512, planks=8, seed=133):
    """Weathered dock planks: sun-bleached greys and honey browns, nail heads, tar seams."""
    rng = np.random.default_rng(seed)
    ph = size // planks
    albedo = np.zeros((size, size, 3))
    height = np.ones((size, size))
    palette = [hexc(c) for c in ("#c98b52", "#b97c48", "#d49a62", "#a96f40", "#c2905e")]
    for p in range(planks):
        y0, y1 = p * ph, (p + 1) * ph
        base = palette[rng.integers(len(palette))] * rng.uniform(0.92, 1.06)
        if p == 5:
            base = base * 0.55 + hexc("#6a4a3a") * 0.45
        grain = periodic_noise(rng, size, beta=1.2, low_cut=3.0)[y0:y1]
        streak = np.sin(np.linspace(0, math.tau * rng.uniform(5, 9), size) + rng.uniform(0, 6))[None, :]
        albedo[y0:y1] = base * (0.86 + grain * 0.22 + streak * 0.04)[..., None]
        seam = np.ones(ph)
        seam[:3] = 0.0
        seam[3:5] = 0.55
        height[y0:y1] *= seam[:, None]
        for j in (int(rng.uniform(0, size)),):
            height[y0:y1, j % size] *= 0.2
            height[y0:y1, (j + 1) % size] *= 0.6
            for ny in (y0 + ph // 3, y0 + 2 * ph // 3):
                for nx in (j + 7, j - 7):
                    albedo[ny - 2:ny + 2, nx % size:(nx % size) + 4] = hexc("#3a3440")
    albedo = albedo * (0.5 + 0.5 * height[..., None])
    save_rgb("cove_planks.png", albedo)
    save_rgb("cove_planks_normal.png", normal_from_height(blur(height, 1), 2.2))


def make_sand(size=512, seed=137):
    """Cove sand: warm and mottled, faint ripples, white shell flecks."""
    rng = np.random.default_rng(seed)
    n = periodic_noise(rng, size, beta=1.6, low_cut=2.0)
    y = (np.arange(size)[:, None] + 0.5) / size
    x = (np.arange(size)[None, :] + 0.5) / size
    ripple = np.sin((y * 9 + np.sin(x * math.tau * 2) * 0.15) * math.tau) * 0.5 + 0.5
    albedo = hexc("#f0cf98") * (0.84 + n[..., None] * 0.18 + ripple[..., None] * 0.05)
    fine = rng.uniform(0, 1, (size, size))
    albedo[fine > 0.997] = hexc("#fff6ea")
    albedo[(fine > 0.9955) & (fine <= 0.997)] = hexc("#e89a8a")
    save_rgb("cove_sand.png", albedo)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for key in (sys.argv[1:] or ["quay", "planks", "sand"]):
        globals()["make_" + key]()
