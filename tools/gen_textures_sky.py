"""Generates the hand-rolled textures for World 10, Sky Carnival (no third-party art):

    art/textures/sky_deck.png             honey-wood deck boards, a few painted (+ _normal), 512
    art/textures/sky_tiles.png            cream and peach diamond plaza tiles, 512
    art/textures/sky_grass.png            spring turf with daisies, 512

The sky and the cloud sea are shaders (art/shaders/sky_sky.gdshader,
sky_cloud_sea.gdshader), so they need no texture.

    python tools/gen_textures_sky.py            (needs numpy + Pillow)
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




def make_deck(size=512, planks=8, seed=101):
    """Honey-wood carnival deck boards with a few pastel-painted planks, nail dots and seams."""
    rng = np.random.default_rng(seed)
    ph = size // planks
    albedo = np.zeros((size, size, 3))
    height = np.ones((size, size))
    palette = [hexc(c) for c in ("#c08a58", "#b98050", "#cc965f", "#ad7646", "#c4905c")]
    paint = [hexc(c) for c in ("#e8a0a0", "#8fc4d8", "#e7c27a")]
    for p in range(planks):
        y0, y1 = p * ph, (p + 1) * ph
        base = palette[rng.integers(len(palette))] * rng.uniform(0.94, 1.05)
        if p in (2, 6):
            base = base * 0.4 + paint[p % 3] * 0.6
        grain = periodic_noise(rng, size, beta=1.3, low_cut=3.0)[y0:y1]
        streak = np.sin(np.linspace(0, math.tau * rng.uniform(4, 8), size) + rng.uniform(0, 6))[None, :]
        albedo[y0:y1] = base * (0.88 + grain * 0.2 + streak * 0.035)[..., None]
        seam = np.ones(ph)
        seam[:2] = 0.0
        seam[2:4] = 0.6
        height[y0:y1] *= seam[:, None]
        for j in (int(rng.uniform(0, size)), int(rng.uniform(0, size))):
            height[y0:y1, j % size] *= 0.25
            height[y0:y1, (j + 1) % size] *= 0.65
            for nx in (j + 8, j - 8):
                for ny in (y0 + ph // 3, y0 + 2 * ph // 3):
                    albedo[ny - 2:ny + 2, (nx - 2) % size:(nx - 2) % size + 4] = hexc("#5a3c2c")
    albedo = albedo * (0.55 + 0.45 * height[..., None])
    save_rgb("sky_deck.png", albedo)
    save_rgb("sky_deck_normal.png", normal_from_height(blur(height, 1), 2.2))


def make_tiles(size=512, seed=103):
    """Plaza paving: cream and peach diamond tiles with gold-grey grout and soft wear."""
    rng = np.random.default_rng(seed)
    y = (np.arange(size)[:, None] + 0.5) / size
    x = (np.arange(size)[None, :] + 0.5) / size
    n = 4
    u = (x + y) * n
    v = (x - y) * n
    fu, fv = u - np.floor(u), v - np.floor(v)
    parity = (np.floor(u) + np.floor(v)) % 2
    edge = np.minimum(np.minimum(fu, 1 - fu), np.minimum(fv, 1 - fv))
    grout = smooth(0.035, 0.055, edge)
    wear = periodic_noise(rng, size, beta=1.6, low_cut=2.0)
    fine = rng.uniform(0, 1, (size, size))
    a, b = hexc("#f4e2c8"), hexc("#f2b796")
    tile = np.where(parity[..., None] > 0.5, a, b)
    tile = tile * (0.9 + wear[..., None] * 0.14 + fine[..., None] * 0.04)
    albedo = tile * grout[..., None] + hexc("#b49a7e") * (1 - grout[..., None])
    save_rgb("sky_tiles.png", albedo)


def make_grass(size=512, seed=105):
    """Soft spring turf: mottled greens with tiny daisies."""
    rng = np.random.default_rng(seed)
    n = periodic_noise(rng, size, beta=1.7, low_cut=2.0)
    m = periodic_noise(rng, size, beta=1.0, low_cut=30.0)
    albedo = hexc("#6cbf5c") * (0.78 + n[..., None] * 0.3) + hexc("#2f7a44") * (m[..., None] - 0.5) * 0.25
    fine = rng.uniform(0, 1, (size, size))
    albedo[fine > 0.9975] = hexc("#fff6e8")
    albedo[(fine > 0.9968) & (fine <= 0.9975)] = hexc("#ffd36b")
    save_rgb("sky_grass.png", albedo)


if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    wanted = sys.argv[1:] or ["deck", "tiles", "grass"]
    for key in wanted:
        globals()["make_" + key]()
