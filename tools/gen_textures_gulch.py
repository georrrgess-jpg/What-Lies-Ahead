"""Generates the hand-rolled textures for World 12, Gold Rush Gulch (no third-party art):

    art/textures/gulch_sand.png        sun-baked street dust: warm sand, pebbles, hoof dimples, 512
    art/textures/gulch_boards.png      weathered boardwalk planks with nail heads (+ _normal), 512
    art/textures/gulch_dirt.png        darker packed earth for the yards and back lanes, 512

The sky is a shader (art/shaders/gulch_sky.gdshader), so it needs no texture.

    python tools/gen_textures_gulch.py            (needs numpy + Pillow)
"""
import math
import os

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "textures")


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def save_rgb(name, arr):
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGB")
    img.save(os.path.join(OUT, name), optimize=True)
    print(name, img.size)


def periodic_noise(rng, size, beta=2.0, low_cut=1.0):
    """Tileable 2D noise (white noise shaped by 1/f^beta), range 0..1."""
    white = rng.normal(0, 1, (size, size))
    f = np.sqrt(np.fft.fftfreq(size)[:, None] ** 2 + np.fft.fftfreq(size)[None, :] ** 2) * size
    f[0, 0] = 1.0
    gain = 1.0 / np.maximum(f, low_cut) ** beta
    gain[0, 0] = 0.0
    n = np.real(np.fft.ifft2(np.fft.fft2(white) * gain))
    return (n - n.min()) / (n.max() - n.min() + 1e-9)


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.stack([-dx, -dy, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def blur(h, passes=1):
    for _ in range(passes):
        h = (h + np.roll(h, 1, 0) + np.roll(h, -1, 0) + np.roll(h, 1, 1) + np.roll(h, -1, 1)) / 5.0
    return h


def speckle(rng, albedo, size, count, radius, colors):
    yy, xx = np.mgrid[0:size, 0:size]
    for _ in range(count):
        cx, cy = rng.integers(0, size, 2)
        r = rng.uniform(radius * 0.5, radius)
        d = np.sqrt(((xx - cx + size / 2) % size - size / 2) ** 2 + ((yy - cy + size / 2) % size - size / 2) ** 2)
        mask = d < r
        albedo[mask] = colors[rng.integers(len(colors))] * rng.uniform(0.9, 1.05)
    return albedo


def make_sand(size=512, seed=201):
    """Street dust: warm sand with soft drifts, pebbles and darker hoof dimples."""
    rng = np.random.default_rng(seed)
    big = periodic_noise(rng, size, beta=2.2, low_cut=1.5)
    mid = periodic_noise(rng, size, beta=1.4, low_cut=6.0)
    fine = rng.uniform(0, 1, (size, size))
    a, b = hexc("#e9b97c"), hexc("#d79a5c")
    albedo = a * (1 - big[..., None]) + b * big[..., None]
    albedo *= (0.9 + mid[..., None] * 0.16 + fine[..., None] * 0.05)
    albedo = speckle(rng, albedo, size, 90, 3.0, [hexc("#b77a4c"), hexc("#f3d3a0"), hexc("#c98a62")])
    albedo = speckle(rng, albedo, size, 30, 7.0, [hexc("#cf8e58")])
    save_rgb("gulch_sand.png", albedo)


def make_dirt(size=512, seed=203):
    """Packed earth for the yards: redder, with wheel-worn streaks and gravel."""
    rng = np.random.default_rng(seed)
    big = periodic_noise(rng, size, beta=2.0, low_cut=1.5)
    streak = periodic_noise(rng, size, beta=1.2, low_cut=4.0)
    fine = rng.uniform(0, 1, (size, size))
    a, b = hexc("#c98352"), hexc("#a8613e")
    albedo = a * (1 - big[..., None]) + b * big[..., None]
    albedo *= (0.88 + streak[..., None] * 0.18 + fine[..., None] * 0.05)
    albedo = speckle(rng, albedo, size, 140, 2.5, [hexc("#8e5236"), hexc("#e3b07c"), hexc("#7a4a34")])
    save_rgb("gulch_dirt.png", albedo)


def make_boards(size=512, planks=6, seed=205):
    """Sun-greyed boardwalk planks running along X, a few warmer, with seams and nails."""
    rng = np.random.default_rng(seed)
    ph = size // planks
    albedo = np.zeros((size, size, 3))
    height = np.ones((size, size))
    palette = [hexc(c) for c in ("#b88358", "#a87650", "#c08f62", "#9c6c48", "#b5865f")]
    for p in range(planks):
        y0, y1 = p * ph, (p + 1) * ph
        base = palette[rng.integers(len(palette))] * rng.uniform(0.94, 1.05)
        grain = periodic_noise(rng, size, beta=1.3, low_cut=3.0)[y0:y1]
        streak = np.sin(np.linspace(0, math.tau * rng.uniform(5, 9), size) + rng.uniform(0, 6))[None, :]
        albedo[y0:y1] = base * (0.86 + grain * 0.22 + streak * 0.04)[..., None]
        seam = np.ones(ph)
        seam[:3] = 0.0
        seam[3:5] = 0.55
        height[y0:y1] *= seam[:, None]
        j = int(rng.uniform(0, size))
        height[y0:y1, j % size] *= 0.25
        height[y0:y1, (j + 1) % size] *= 0.6
        for nx in (j + 10, j - 10):
            for ny in (y0 + ph // 3, y0 + 2 * ph // 3):
                albedo[ny - 2:ny + 2, (nx - 2) % size:(nx - 2) % size + 4] = hexc("#4a3426")
    albedo = albedo * (0.55 + 0.45 * height[..., None])
    save_rgb("gulch_boards.png", albedo)
    save_rgb("gulch_boards_normal.png", normal_from_height(blur(height, 1), 2.2))


if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    wanted = sys.argv[1:] or ["sand", "dirt", "boards"]
    for key in wanted:
        globals()["make_" + key]()
