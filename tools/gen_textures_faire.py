"""Generates the hand-rolled textures for World 14, Castle Kingdom (no third-party art):

    art/textures/faire_grass.png          spring meadow turf with clover and daisies, 512
    art/textures/faire_cobble.png         rounded cobbles for the paths and the courtyard (+ _normal), 512
    art/textures/faire_stone.png          toy castle ashlar: pale blocks, soft mortar (+ _normal), 512
    art/textures/faire_sand.png           raked tilting-yard sand with hoof scuffs, 512

The sky and the moat are shaders (art/shaders/faire_sky.gdshader,
faire_water.gdshader), so they need no texture.

    python tools/gen_textures_faire.py            (needs numpy + Pillow)
"""
import math
import os

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "textures")


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


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


def make_grass(size=512, seed=1401):
    """Bright meadow: mottled spring greens, darker clover clumps, daisies and buttercups."""
    rng = np.random.default_rng(seed)
    n = periodic_noise(rng, size, beta=1.7, low_cut=2.0)
    m = periodic_noise(rng, size, beta=1.0, low_cut=30.0)
    clover = smooth(0.62, 0.7, periodic_noise(rng, size, beta=2.2, low_cut=6.0))
    albedo = hexc("#7cc95c") * (0.8 + n[..., None] * 0.28) + hexc("#2f7a3c") * (m[..., None] - 0.5) * 0.22
    albedo = albedo * (1 - clover[..., None] * 0.18) + hexc("#4f9a46") * clover[..., None] * 0.12
    fine = rng.uniform(0, 1, (size, size))
    albedo[fine > 0.9976] = hexc("#fffaf0")
    albedo[(fine > 0.9969) & (fine <= 0.9976)] = hexc("#ffd84a")
    albedo[(fine > 0.9965) & (fine <= 0.9969)] = hexc("#ff9ec4")
    save_rgb("faire_grass.png", albedo)


def _cells(size, count, rng, jitter=0.35):
    """Distance to the nearest and second-nearest jittered grid point (tileable)."""
    g = int(math.sqrt(count))
    pts = []
    for j in range(g):
        for i in range(g):
            pts.append(((i + 0.5 + rng.uniform(-jitter, jitter)) / g, (j + 0.5 + rng.uniform(-jitter, jitter)) / g))
    pts = np.array(pts)
    y = (np.arange(size)[:, None] + 0.5) / size
    x = (np.arange(size)[None, :] + 0.5) / size
    d1 = np.full((size, size), 9.0)
    d2 = np.full((size, size), 9.0)
    idx = np.zeros((size, size), dtype=int)
    for k, (px, py) in enumerate(pts):
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                d = np.sqrt((x - px - ox) ** 2 + (y - py - oy) ** 2)
                closer = d < d1
                d2 = np.where(closer, d1, np.minimum(d2, d))
                idx = np.where(closer, k, idx)
                d1 = np.where(closer, d, d1)
    return d1, d2, idx, g


def make_cobble(size=512, seed=1403):
    """Rounded cobbles in warm greys and honey tones with dark gaps."""
    rng = np.random.default_rng(seed)
    d1, d2, idx, g = _cells(size, 64, rng)
    edge = (d2 - d1) * g
    stone = smooth(0.04, 0.28, edge)
    tones = [hexc(c) for c in ("#c9bfae", "#b8ad9c", "#d6c9b0", "#a9a39a", "#cdb894", "#bfb6a8")]
    pick = np.array(tones)[(idx * 7 + 3) % len(tones)]
    wear = periodic_noise(rng, size, beta=1.6, low_cut=3.0)
    albedo = pick * (0.82 + 0.22 * wear[..., None]) * (0.55 + 0.45 * stone[..., None])
    albedo = albedo * stone[..., None] + hexc("#6f7a52") * (1 - stone[..., None]) * 0.9
    save_rgb("faire_cobble.png", albedo)
    save_rgb("faire_cobble_normal.png", normal_from_height(blur(np.sqrt(np.clip(stone, 0, 1)), 2), 3.0))


def make_stone(size=512, seed=1405):
    """Toy ashlar: four courses of pale blocks per tile, staggered, soft mortar."""
    rng = np.random.default_rng(seed)
    rows = 8
    rh = size // rows
    albedo = np.zeros((size, size, 3))
    height = np.ones((size, size))
    tones = [hexc(c) for c in ("#d5d0db", "#c9c3d0", "#dcd6d2", "#c4c0cc", "#d9d2c8", "#cfcad6")]
    fine = periodic_noise(rng, size, beta=1.4, low_cut=4.0)
    for r in range(rows):
        y0, y1 = r * rh, (r + 1) * rh
        blocks = 4
        bw = size // blocks
        off = (bw // 2) * (r % 2)
        for b in range(blocks):
            x0 = (b * bw + off) % size
            col = tones[(r * 5 + b * 3) % len(tones)] * rng.uniform(0.95, 1.04)
            xs = (np.arange(bw) + x0) % size
            albedo[y0:y1][:, xs] = col
            mort = np.ones((rh, bw))
            mort[:4, :] = 0.0
            mort[:, :4] = 0.0
            mort[4:7, 4:] = np.minimum(mort[4:7, 4:], 0.6)
            mort[4:, 4:7] = np.minimum(mort[4:, 4:7], 0.6)
            height[y0:y1][:, xs] = mort
    albedo = albedo * (0.9 + fine[..., None] * 0.14)
    albedo = albedo * (0.6 + 0.4 * height[..., None]) + hexc("#9a93a3") * (1 - height[..., None]) * 0.25
    save_rgb("faire_stone.png", albedo)
    save_rgb("faire_stone_normal.png", normal_from_height(blur(height, 2), 2.0))


def make_sand(size=512, seed=1407):
    """Raked tilting-yard sand: warm tan, rake lines and soft hoof scuffs."""
    rng = np.random.default_rng(seed)
    n = periodic_noise(rng, size, beta=1.6, low_cut=2.0)
    fine = rng.uniform(0, 1, (size, size))
    y = np.arange(size)[:, None] / size
    rake = 0.5 + 0.5 * np.sin(y * math.tau * 24 + n * 3.0)
    albedo = hexc("#e3c48f") * (0.86 + n[..., None] * 0.18 + rake[..., None] * 0.05 + fine[..., None] * 0.04)
    scuff = smooth(0.7, 0.8, periodic_noise(rng, size, beta=2.4, low_cut=8.0))
    albedo = albedo * (1 - scuff[..., None] * 0.12)
    save_rgb("faire_sand.png", albedo)


if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    wanted = sys.argv[1:] or ["grass", "cobble", "stone", "sand"]
    for key in wanted:
        globals()["make_" + key]()
