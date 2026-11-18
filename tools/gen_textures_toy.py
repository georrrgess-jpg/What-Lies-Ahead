"""Generates the hand-rolled textures for World 15, Toybox Town (no third-party art):

    art/textures/toy_planks.png           honey-oak shop floorboards, toy scale (+ _normal), 512
    art/textures/toy_wallpaper.png        cream shop wallpaper with blue stars and pinstripes, 512
    art/textures/toy_rug.png              the round play rug under the station: primary rings, 512

The night sky beyond the shop window is the shared procedural night-sky shader,
so it needs no texture.

    python tools/gen_textures_toy.py            (needs numpy + Pillow)
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


def make_planks(size=512, planks=4, seed=151):
    """Wide honey-oak floorboards (at toy scale each board is ~3 m wide): long grain
    streaks, a few knots, dark seams and staggered butt joints."""
    rng = np.random.default_rng(seed)
    ph = size // planks
    albedo = np.zeros((size, size, 3))
    height = np.ones((size, size))
    palette = [hexc(c) for c in ("#c98d55", "#bd8049", "#d39a60", "#b57a45")]
    x = np.arange(size)
    for p in range(planks):
        y0, y1 = p * ph, (p + 1) * ph
        base = palette[p % len(palette)] * rng.uniform(0.95, 1.04)
        grain = periodic_noise(rng, size, beta=1.2, low_cut=4.0)[y0:y1]
        rows = np.arange(ph)[:, None]
        wave = np.sin(rows / ph * math.tau * rng.uniform(2.5, 4.5) + np.sin(x[None, :] / size * math.tau * 2 + p) * 1.6)
        streak = 0.5 + 0.5 * np.sin(wave * 3.0 + rows * 0.9)
        albedo[y0:y1] = base * (0.86 + grain[..., None] * 0.16 + streak[..., None] * 0.07)
        seam = np.ones(ph)
        seam[:3] = 0.0
        seam[3:5] = 0.55
        height[y0:y1] *= seam[:, None]
        j = int((p * 0.37 + rng.uniform(0, 0.3)) * size) % size
        height[y0:y1, j] *= 0.2
        height[y0:y1, (j + 1) % size] *= 0.6
        # A knot or two: dark rings.
        for _ in range(rng.integers(1, 3)):
            cx, cy = rng.uniform(0, size), rng.uniform(y0 + 12, y1 - 12)
            yy, xx = np.mgrid[y0:y1, 0:size]
            d = np.sqrt(((xx - cx + size / 2) % size - size / 2) ** 2 / 3.0 + (yy - cy) ** 2)
            ring = smooth(9, 2, d) * (0.6 + 0.4 * np.sin(d * 1.4))
            albedo[y0:y1] *= (1 - ring[..., None] * 0.35)
    albedo = albedo * (0.5 + 0.5 * height[..., None])
    save_rgb("toy_planks.png", albedo)
    save_rgb("toy_planks_normal.png", normal_from_height(blur(height, 1), 2.0))


def make_wallpaper(size=512, seed=153):
    """Cream wallpaper: soft blue pinstripes and rows of little five-point stars."""
    rng = np.random.default_rng(seed)
    y = (np.arange(size)[:, None] + 0.5) / size
    x = (np.arange(size)[None, :] + 0.5) / size
    paper = hexc("#f3e6cc") * (0.95 + periodic_noise(rng, size, beta=1.5, low_cut=3.0)[..., None] * 0.08)
    pin = (x * 4) % 1.0
    pin = np.minimum(pin, 1 - pin)
    stripe = smooth(0.012, 0.004, pin)
    albedo = paper * (1 - stripe[..., None]) + hexc("#7fa6d9") * stripe[..., None]
    # Stars on a staggered grid between the stripes.
    for row in range(4):
        for col in range(4):
            cx = (col + 0.5) / 4
            cy = (row + (0.25 if col % 2 else 0.75)) / 4
            dx, dy = x - cx, y - cy
            ang = np.arctan2(dy, dx) + math.pi / 2
            r = np.sqrt(dx * dx + dy * dy)
            k = np.cos(ang * 5) * 0.5 + 0.5
            edge = 0.032 + 0.03 * k
            star = smooth(edge + 0.004, edge - 0.002, r)
            colour = hexc("#3f6fc4") if (row + col) % 3 else hexc("#e8b13a")
            albedo = albedo * (1 - star[..., None]) + colour * star[..., None]
    save_rgb("toy_wallpaper.png", albedo)


def make_rug(size=512, seed=155):
    """Round play rug (UV 0..1 over the disc): concentric red, yellow and blue
    rings with stitched edges and a star in the middle."""
    rng = np.random.default_rng(seed)
    y = (np.arange(size)[:, None] + 0.5) / size - 0.5
    x = (np.arange(size)[None, :] + 0.5) / size - 0.5
    r = np.sqrt(x * x + y * y) * 2.0
    ang = np.arctan2(y, x)
    fibre = periodic_noise(rng, size, beta=0.6, low_cut=60.0)
    bands = [(0.0, hexc("#f4e4c4")), (0.3, hexc("#3b6fd1")), (0.46, hexc("#f2c23a")), (0.62, hexc("#e2443a")),
             (0.78, hexc("#f4e4c4")), (0.86, hexc("#3b6fd1")), (0.97, hexc("#2a4c96"))]
    albedo = np.zeros((size, size, 3)) + bands[0][1]
    for r0, c in bands[1:]:
        m = smooth(r0 - 0.004, r0 + 0.004, r)
        albedo = albedo * (1 - m[..., None]) + c * m[..., None]
    # Stitches along each band edge.
    for r0, _c in bands[1:]:
        dash = (np.sin(ang * 90) > 0.2).astype(float)
        st = smooth(0.006, 0.002, np.abs(r - r0 - 0.02)) * dash
        albedo = albedo * (1 - st[..., None] * 0.7) + hexc("#fff4dc") * st[..., None] * 0.7
    # Centre star.
    k = np.cos((ang + math.pi / 2) * 5) * 0.5 + 0.5
    star = smooth(0.17 + 0.1 * k + 0.01, 0.17 + 0.1 * k - 0.01, r)
    albedo = albedo * (1 - star[..., None]) + hexc("#e2443a") * star[..., None]
    albedo *= (0.9 + fibre[..., None] * 0.14)
    save_rgb("toy_rug.png", albedo)


if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    wanted = sys.argv[1:] or ["planks", "wallpaper", "rug"]
    for key in wanted:
        globals()["make_" + key]()
