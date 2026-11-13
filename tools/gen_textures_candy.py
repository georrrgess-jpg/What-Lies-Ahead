"""Generates the hand-rolled textures for World 8, Sugar Rush Factory (no third-party art):

    art/textures/candy_sky.png      equirectangular late-morning sky: pastel blue with
                                    cotton-candy clouds (seen through the skylights)
    art/textures/candy_floor.png    mint and cream factory floor tiles with grout, scuffs
                                    and a few sprinkles; 1 tile = 1 m, the image = 4 m
    art/textures/candy_brick.png    strawberry-pink brick with cream mortar; the image = 2 m
    art/textures/candy_choc.png     melted-chocolate swirl (R height, G sheen) for the river
                                    and the waterfall (candy_chocolate.gdshader)

    python tools/gen_textures_candy.py            (needs numpy + Pillow)
"""
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


def periodic_noise(rng, size, beta=2.0, low_cut=1.0, shape=None):
    """Tileable 2D noise (white noise shaped by 1/f^beta), range 0..1."""
    h, w = shape if shape else (size, size)
    white = rng.normal(0, 1, (h, w))
    f = np.sqrt(np.fft.fftfreq(h)[:, None] ** 2 * h * h + np.fft.fftfreq(w)[None, :] ** 2 * w * w)
    f[0, 0] = 1.0
    gain = 1.0 / np.maximum(f, low_cut) ** beta
    gain[0, 0] = 0.0
    n = np.real(np.fft.ifft2(np.fft.fft2(white) * gain))
    return (n - n.min()) / (n.max() - n.min() + 1e-9)


def make_sky(width=1024, height=512, seed=81):
    rng = np.random.default_rng(seed)
    v = (np.arange(height) + 0.5)[:, None] / height          # 0 top .. 1 bottom
    elev = (0.5 - v) * np.pi                                  # +pi/2 zenith
    up = np.clip(elev / (np.pi / 2), -1, 1)
    zen, mid, hor = hexc("#6fb6ff"), hexc("#a9dcff"), hexc("#ffe4f1")
    t = np.clip(up, 0, 1)
    sky = np.where((t < 0.25)[..., None], hor + (mid - hor) * (t / 0.25)[..., None], mid + (zen - mid) * ((t - 0.25) / 0.75)[..., None])
    sky = np.broadcast_to(sky, (height, width, 3)).copy()
    sky[(up < 0)[:, 0]] = hexc("#ffd6e8")
    # Cotton-candy clouds: banded noise, denser near the horizon.
    n = periodic_noise(rng, 0, beta=2.2, low_cut=2.0, shape=(height, width))
    n2 = periodic_noise(rng, 0, beta=1.6, low_cut=4.0, shape=(height, width))
    band = np.exp(-((up - 0.22) / 0.22) ** 2)
    cover = smooth(0.52, 0.7, n * 0.8 + n2 * 0.25) * band
    shade = np.clip((n2 - 0.4) * 1.6, 0, 1)
    pink, white = hexc("#ffc2df"), hexc("#fffaff")
    cloud = white + (pink - white) * shade[..., None]
    sky = sky + (cloud - sky) * cover[..., None]
    # A soft sun glow up in the south-east.
    xs = (np.arange(width) + 0.5)[None, :] / width
    d = np.sqrt(((xs - 0.38) * 2.0) ** 2 + ((v - 0.22) * 2.0) ** 2)
    sky += hexc("#fff3c4") * (np.exp(-(d / 0.07) ** 2) * 0.9 + np.exp(-(d / 0.25) ** 2) * 0.25)[..., None]
    save_rgb("candy_sky.png", sky)


def make_floor(size=512, tiles=4, seed=82):
    """Checker of mint and cream tiles with soft grout and wear."""
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:size, 0:size] / (size / tiles)
    ix, iy = np.floor(xs).astype(int), np.floor(ys).astype(int)
    fx, fy = xs - ix, ys - iy
    checker = ((ix + iy) % 2 == 0)[..., None]
    mint, cream = hexc("#86e6c6"), hexc("#ffe9c6")
    base = np.where(checker, mint, cream)
    # Per-tile tint jitter.
    jitter = rng.uniform(-0.035, 0.035, (tiles, tiles))
    base = base + jitter[iy % tiles, ix % tiles][..., None]
    edge = np.minimum(np.minimum(fx, 1 - fx), np.minimum(fy, 1 - fy))
    grout = 1.0 - smooth(0.012, 0.03, edge)
    bevel = smooth(0.03, 0.08, edge)
    wear = periodic_noise(rng, size, beta=1.8, low_cut=3.0)
    base = base * (0.93 + 0.07 * bevel)[..., None] * (0.96 + 0.06 * wear)[..., None]
    base = base + (hexc("#c9b8c8") - base) * grout[..., None]
    # A few sprinkles stuck in the grout lines and scuffs.
    for _ in range(26):
        cx, cy = rng.uniform(0, size, 2)
        ang = rng.uniform(0, np.pi)
        col = hexc(["#ff7eb6", "#ffd23f", "#9fd8ff", "#c9a7ff", "#ff4a5e"][rng.integers(5)])
        dx, dy = np.cos(ang), np.sin(ang)
        px = (np.mgrid[0:size, 0:size][1] - cx)
        py = (np.mgrid[0:size, 0:size][0] - cy)
        along = px * dx + py * dy
        across = -px * dy + py * dx
        m = (np.abs(along) < 5) & (np.abs(across) < 1.6)
        base[m] = col
    save_rgb("candy_floor.png", base)


def make_brick(size=512, rows=8, cols=4, seed=83):
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:size, 0:size] / size
    row = np.floor(ys * rows).astype(int)
    xo = xs * cols + 0.5 * (row % 2)
    col = np.floor(xo).astype(int)
    fx, fy = xo - col, ys * rows - row
    edge = np.minimum(np.minimum(fx * 2.0, (1 - fx) * 2.0), np.minimum(fy, 1 - fy))
    mortar = 1.0 - smooth(0.05, 0.1, edge)
    tint = rng.uniform(-0.06, 0.06, (rows, cols + 1))
    pinks = [hexc("#f77aae"), hexc("#ec6aa2"), hexc("#ff8dbc")]
    pick = rng.integers(0, 3, (rows, cols + 1))
    base = np.zeros((size, size, 3))
    for k in range(3):
        base[pick[row % rows, col % (cols + 1)] == k] = pinks[k]
    base = base + tint[row % rows, col % (cols + 1)][..., None]
    grain = periodic_noise(rng, size, beta=1.4, low_cut=6.0)
    base = base * (0.94 + 0.1 * grain)[..., None] * (0.92 + 0.08 * smooth(0.1, 0.3, edge))[..., None]
    base = base + (hexc("#ffe6dc") - base) * mortar[..., None]
    save_rgb("candy_brick.png", base)


def make_choc(size=256, seed=84):
    rng = np.random.default_rng(seed)
    n = periodic_noise(rng, size, beta=2.4, low_cut=2.0)
    m = periodic_noise(rng, size, beta=1.6, low_cut=5.0)
    ripple = 0.5 + 0.5 * np.sin((n * 7.0 + m * 2.0) * np.pi * 2.0)
    sheen = smooth(0.7, 0.95, ripple * 0.7 + m * 0.4)
    save_rgb("candy_choc.png", np.stack([n * 0.6 + ripple * 0.4, sheen, m], axis=-1))


if __name__ == "__main__":
    make_sky()
    make_floor()
    make_brick()
    make_choc()
