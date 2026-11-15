"""Generates the hand-rolled textures for Ashfall City, the Endless map (no third-party art):

    art/textures/city_grime.png       neutral wear (soot, rain streaks, chips) multiplied over
                                      every city_*.glb colour on import, 512
    art/textures/city_asphalt.png     cracked road asphalt with tar seams and ash (+ _normal), 512
    art/textures/city_concrete.png    stained cast-concrete panels with tie holes (+ _normal), 512
    art/textures/city_sidewalk.png    square paving slabs, cracked and sooty (+ _normal), 512
    art/textures/city_brick.png       sooty brick courses, light mortar (+ _normal), 512; near
                                      white so the models' brick colours tint it
    art/textures/city_rubble.png      ash, grit and broken concrete for verges and lots, 512

    python tools/gen_textures_city.py [grime asphalt concrete sidewalk brick rubble]   (numpy + Pillow)
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


def periodic_noise(rng, size, beta=2.0, low_cut=1.0, aspect=(1.0, 1.0)):
    """Tileable 2D noise (white noise shaped by 1/f^beta), range 0..1. `aspect`
    stretches the spectrum (y, x) for streaks."""
    white = rng.normal(0, 1, (size, size))
    fy = np.fft.fftfreq(size)[:, None] * aspect[0]
    fx = np.fft.fftfreq(size)[None, :] * aspect[1]
    f = np.sqrt(fy ** 2 + fx ** 2) * size
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


def cracks(rng, size, count, length, wander=0.13):
    """Tileable crack mask (1 on a crack): random walks that branch."""
    mask = np.zeros((size, size))
    for _ in range(count):
        y, x = rng.uniform(0, size, 2)
        a = rng.uniform(0, math.tau)
        width = rng.uniform(0.8, 1.6)
        for step in range(int(length * rng.uniform(0.5, 1.2))):
            a += rng.normal(0, wander)
            y = (y + math.sin(a) * 1.5) % size
            x = (x + math.cos(a) * 1.5) % size
            iy, ix = int(y), int(x)
            mask[iy, ix] = 1.0
            if width > 1.2:
                mask[(iy + 1) % size, ix] = 0.7
            if rng.random() < 0.01:
                a += rng.choice((-1.0, 1.0)) * 1.1
    return np.clip(blur(mask, 1) * 3.0, 0.0, 1.0)


def make_grime(size=512, seed=301):
    """Neutral wear, mean ~0.85: soft soot clouds, vertical rain streaks, chips."""
    rng = np.random.default_rng(seed)
    cloud = periodic_noise(rng, size, beta=1.8, low_cut=2.0)
    streak = periodic_noise(rng, size, beta=1.6, low_cut=3.0, aspect=(1.0, 0.12))
    fine = periodic_noise(rng, size, beta=0.8, low_cut=60.0)
    chips = smooth(0.86, 0.93, periodic_noise(rng, size, beta=1.0, low_cut=30.0))
    v = 0.97 - smooth(0.45, 0.95, cloud) * 0.32 - smooth(0.55, 0.9, streak) * 0.16 - (fine - 0.5) * 0.08
    v = v + chips * 0.1
    tint = np.stack([v * 1.0, v * 0.985, v * 0.97], axis=-1)
    save_rgb("city_grime.png", tint)


def make_asphalt(size=512, seed=303):
    """Road asphalt: dark aggregate, ash dust, wandering cracks filled with tar."""
    rng = np.random.default_rng(seed)
    grain = rng.uniform(0, 1, (size, size))
    n = periodic_noise(rng, size, beta=1.4, low_cut=3.0)
    patch = smooth(0.62, 0.7, periodic_noise(rng, size, beta=2.2, low_cut=1.5))
    crack = cracks(rng, size, 14, 220)
    base = hexc("#3b3739") * (0.82 + n[..., None] * 0.3 + grain[..., None] * 0.14)
    base = base * (1 - patch[..., None] * 0.18) + hexc("#2a2729") * patch[..., None] * 0.18
    ash = smooth(0.55, 0.85, periodic_noise(rng, size, beta=1.7, low_cut=2.0))
    base = base * (1 - ash[..., None] * 0.25) + hexc("#77706a") * ash[..., None] * 0.25
    stones = grain > 0.985
    base[stones] = hexc("#6a6462")
    albedo = base * (1 - crack[..., None] * 0.75) + hexc("#151314") * crack[..., None] * 0.75
    height = 0.6 + grain * 0.15 + n * 0.2 - crack * 0.6
    save_rgb("city_asphalt.png", albedo)
    save_rgb("city_asphalt_normal.png", normal_from_height(blur(height, 1), 2.0))


def make_concrete(size=512, seed=305):
    """Cast concrete in two panels per tile with tie holes, water stains and soot."""
    rng = np.random.default_rng(seed)
    n = periodic_noise(rng, size, beta=1.5, low_cut=3.0)
    fine = periodic_noise(rng, size, beta=0.7, low_cut=80.0)
    streak = periodic_noise(rng, size, beta=1.6, low_cut=3.0, aspect=(1.0, 0.15))
    y = np.arange(size)[:, None]
    x = np.arange(size)[None, :]
    seam = ((y % (size // 2)) < 3) | ((x % (size // 2)) < 3)
    albedo = hexc("#8e8780") * (0.86 + n[..., None] * 0.2 + fine[..., None] * 0.1)
    albedo *= (1 - smooth(0.55, 0.9, streak)[..., None] * 0.22)
    albedo[seam] *= 0.55
    height = 0.7 + fine * 0.1 + n * 0.1 - seam * 0.5
    for cy in (size // 4, 3 * size // 4):
        for cx in (size // 8, 3 * size // 8, 5 * size // 8, 7 * size // 8):
            d = np.sqrt(((y - cy + size // 2) % size - size // 2) ** 2 + ((x - cx + size // 2) % size - size // 2) ** 2)
            hole = d < 5
            albedo[hole] = hexc("#3a3634")
            height = height - hole * 0.4
    crack = cracks(rng, size, 6, 160)
    albedo = albedo * (1 - crack[..., None] * 0.55)
    height = height - crack * 0.35
    save_rgb("city_concrete.png", albedo)
    save_rgb("city_concrete_normal.png", normal_from_height(blur(height, 1), 2.2))


def make_sidewalk(size=512, seed=307, slabs=4):
    """Square paving slabs (4 x 4 per tile), each its own tone, some cracked, soot in the joints."""
    rng = np.random.default_rng(seed)
    s = size // slabs
    y = np.arange(size)[:, None]
    x = np.arange(size)[None, :]
    iy, ix = y // s, x // s
    tone = rng.uniform(0.86, 1.1, (slabs, slabs))
    n = periodic_noise(rng, size, beta=1.3, low_cut=4.0)
    fine = rng.uniform(0, 1, (size, size))
    albedo = hexc("#9a938a") * (tone[iy, ix][..., None] * (0.88 + n[..., None] * 0.18 + fine[..., None] * 0.06))
    joint = ((y % s) < 4) | ((x % s) < 4)
    bevel = np.minimum(np.minimum(y % s, s - 1 - y % s), np.minimum(x % s, s - 1 - x % s))
    edge = smooth(3.0, 10.0, bevel.astype(float))
    albedo *= (0.78 + 0.22 * edge[..., None])
    albedo[joint] = hexc("#2a2628")
    crack = cracks(rng, size, 9, 120)
    albedo = albedo * (1 - crack[..., None] * 0.6)
    soot = smooth(0.6, 0.9, periodic_noise(rng, size, beta=1.9, low_cut=2.0))
    albedo *= (1 - soot[..., None] * 0.3)
    height = edge * 0.8 + fine * 0.05 - crack * 0.4
    save_rgb("city_sidewalk.png", albedo)
    save_rgb("city_sidewalk_normal.png", normal_from_height(blur(height, 1), 2.4))


def make_brick(size=512, seed=309, rows=16, per_row=5):
    """Brick courses, near white with per-brick variation, so a tint gives the colour; mortar light grey."""
    rng = np.random.default_rng(seed)
    bh = size // rows
    bw = size // per_row
    y = np.arange(size)[:, None]
    x = np.arange(size)[None, :]
    row = y // bh
    xs = (x + (row % 2) * (bw // 2)) % size
    col = np.minimum(xs // bw, per_row - 1)
    tone = rng.uniform(0.78, 1.0, (rows, per_row))
    burnt = rng.uniform(0, 1, (rows, per_row)) < 0.12
    n = periodic_noise(rng, size, beta=1.2, low_cut=8.0)
    v = tone[row, col] * (0.9 + n * 0.14)
    v = np.where(burnt[row, col], v * 0.55, v)
    mortar = ((y % bh) < 3) | ((xs % bw) < 3)
    albedo = np.stack([v, v * 0.97, v * 0.95], axis=-1)
    albedo[mortar] = hexc("#c9c2b8") * 0.85
    soot = smooth(0.5, 0.95, periodic_noise(rng, size, beta=1.7, low_cut=2.0, aspect=(1.0, 0.3)))
    albedo *= (1 - soot[..., None] * 0.35)
    height = np.where(mortar, 0.2, 0.8 + n * 0.1)
    save_rgb("city_brick.png", albedo)
    save_rgb("city_brick_normal.png", normal_from_height(blur(height, 1), 2.4))


def make_rubble(size=512, seed=311):
    """Ash and grit with broken concrete chunks and a few ember-red flecks."""
    rng = np.random.default_rng(seed)
    n = periodic_noise(rng, size, beta=1.6, low_cut=2.0)
    fine = rng.uniform(0, 1, (size, size))
    chunk = smooth(0.7, 0.74, periodic_noise(rng, size, beta=1.0, low_cut=25.0))
    albedo = hexc("#5a5452") * (0.75 + n[..., None] * 0.4 + fine[..., None] * 0.15)
    albedo = albedo * (1 - chunk[..., None]) + hexc("#8e877f") * (0.9 + fine[..., None] * 0.2) * chunk[..., None]
    albedo[fine > 0.9975] = hexc("#c2502a")
    save_rgb("city_rubble.png", albedo)


if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    wanted = sys.argv[1:] or ["grime", "asphalt", "concrete", "sidewalk", "brick", "rubble"]
    for key in wanted:
        globals()["make_" + key]()
