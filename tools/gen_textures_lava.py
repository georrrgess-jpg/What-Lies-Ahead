"""Generates the hand-rolled textures for World 9, Volcano Isle (no third-party art):

    art/textures/lava_basalt.png          basalt flagstones with ember-lit joints (+ _normal), 512
    art/textures/lava_deck.png            weathered tiki-wood deck boards (+ _normal), 512
    art/textures/lava_sand.png            black volcanic sand with shell flecks, 512
    art/textures/lava_rock.png            rough lava rock for the terrain and banks (+ _normal), 512

The sky is a shader (art/shaders/lava_sky.gdshader), so it needs no texture.

    python tools/gen_textures_lava.py            (needs numpy + Pillow)
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


def periodic_voronoi(rng, size, count):
    pts = rng.uniform(0, size, (count, 2))
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64)
    f1 = np.full((size, size), 1e9)
    f2 = np.full((size, size), 1e9)
    ids = np.zeros((size, size), dtype=np.int32)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(xs - px)
        dx = np.minimum(dx, size - dx)
        dy = np.abs(ys - py)
        dy = np.minimum(dy, size - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        ids = np.where(closer, i, ids)
        f1 = np.where(closer, d, f1)
    return f1, f2, ids


def make_basalt(size=512, seed=91):
    """Irregular basalt flagstones; the joints are dark with a faint ember warmth."""
    rng = np.random.default_rng(seed)
    count = 26
    f1, f2, ids = periodic_voronoi(rng, size, count)
    edge = f2 - f1
    joint = smooth(1.5, 5.0, edge)
    palette = [hexc(c) for c in ("#3b3442", "#443c4c", "#352f3d", "#4d4454", "#3f3747")]
    base = np.array([palette[i % len(palette)] for i in range(count)])
    tones = rng.uniform(0, 1, count)
    stone = base[ids] * (0.88 + tones[ids][..., None] * 0.24)
    grit = periodic_noise(rng, size, beta=0.9, low_cut=40.0)
    pits = smooth(0.78, 0.92, periodic_noise(rng, size, beta=0.6, low_cut=80.0))
    stone *= (0.9 + grit[..., None] * 0.2) * (1 - pits[..., None] * 0.35)
    bevel = smooth(1.0, 6.0, edge)
    stone *= (0.72 + 0.28 * bevel[..., None])
    gap = (1 - joint)[..., None]
    albedo = stone * (1 - gap) + hexc("#2a1416") * gap
    height = joint * (0.6 + 0.4 * bevel) + grit * 0.06 - pits * 0.08
    save_rgb("lava_basalt.png", albedo)
    save_rgb("lava_basalt_normal.png", normal_from_height(blur(height, 1), 2.6))


def make_deck(size=512, planks=6, seed=93):
    """Tiki-wood deck boards, warm brown, with nail dots and darker seams."""
    rng = np.random.default_rng(seed)
    ph = size // planks
    albedo = np.zeros((size, size, 3))
    height = np.ones((size, size))
    palette = [hexc(c) for c in ("#7a4a2e", "#86532f", "#6c4129", "#93603a", "#7f4d33")]
    for p in range(planks):
        y0, y1 = p * ph, (p + 1) * ph
        base = palette[rng.integers(len(palette))] * rng.uniform(0.92, 1.06)
        grain = periodic_noise(rng, size, beta=1.3, low_cut=3.0)[y0:y1]
        streak = np.sin(np.linspace(0, math.tau * rng.uniform(4, 8), size) + rng.uniform(0, 6))[None, :]
        albedo[y0:y1] = base * (0.86 + grain * 0.24 + streak * 0.04)[..., None]
        seam = np.ones(ph)
        seam[:3] = 0.0
        seam[3:5] = 0.55
        height[y0:y1] *= seam[:, None]
        j = int(rng.uniform(0, size))
        height[y0:y1, j % size] *= 0.2
        height[y0:y1, (j + 1) % size] *= 0.6
        for nx in (j + 10, j - 10):
            for ny in (y0 + ph // 4, y0 + 3 * ph // 4):
                albedo[ny - 2:ny + 2, (nx - 2) % size:(nx - 2) % size + 4] = hexc("#2a1c18")
    albedo = albedo * (0.45 + 0.55 * height[..., None])
    save_rgb("lava_deck.png", albedo)
    save_rgb("lava_deck_normal.png", normal_from_height(blur(height, 1), 2.4))


def make_sand(size=512, seed=95):
    """Black volcanic sand: fine grain, ripples and pale shell flecks."""
    rng = np.random.default_rng(seed)
    n = periodic_noise(rng, size, beta=1.5, low_cut=3.0)
    fine = rng.uniform(0, 1, (size, size))
    y = np.arange(size)[:, None] / size
    x = np.arange(size)[None, :] / size
    ripple = 0.5 + 0.5 * np.sin((y * 9 + n * 1.6 + x * 2) * math.tau)
    albedo = hexc("#2d2833") * (0.8 + n[..., None] * 0.35 + fine[..., None] * 0.12 + ripple[..., None] * 0.08)
    flecks = fine > 0.9965
    albedo[flecks] = hexc("#d8c8b8")
    save_rgb("lava_sand.png", albedo)


def make_rock(size=512, seed=97):
    """Rough lava rock: ropey ridges, dark with violet-grey highlights."""
    rng = np.random.default_rng(seed)
    n = periodic_noise(rng, size, beta=1.8, low_cut=2.0)
    m = periodic_noise(rng, size, beta=1.1, low_cut=20.0)
    ridges = 1 - np.abs(np.sin((n * 7.0 + m * 0.8) * math.pi))
    height = ridges * 0.6 + m * 0.4
    albedo = hexc("#272230") * (0.75 + height[..., None] * 0.6)
    albedo += hexc("#3a1a1c") * smooth(0.2, 0.0, height)[..., None] * 0.5
    save_rgb("lava_rock.png", albedo)
    save_rgb("lava_rock_normal.png", normal_from_height(blur(height, 1), 3.0))


if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    wanted = sys.argv[1:] or ["basalt", "deck", "sand", "rock"]
    for key in wanted:
        globals()["make_" + key]()
