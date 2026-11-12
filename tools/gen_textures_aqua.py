"""Generates the textures for World 3 "Abyss Aquarium" (no third-party art):

    art/textures/aqua_floor_tiles.png         large-format terrazzo tiles (albedo), 4 m per tile
    art/textures/aqua_floor_tiles_normal.png  matching normal map (grout lines, chip relief)
    art/textures/aqua_wall_panels.png         ribbed acoustic wall panels, 4 m per tile
    art/textures/aqua_caustics.png            tileable caustic light network (greyscale)
    art/textures/aqua_sand.png                rippled tank sand with shell flecks
    art/textures/aqua_carpet.png              lobby carpet with a wave motif

    python tools/gen_textures_aqua.py            (needs numpy + Pillow)
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


def save_rgb(name, rgb):
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size)


def tile_noise(size, cells, seed):
    """Tileable value noise in 0..1 (bicubic interpolation of a wrapped grid)."""
    rng = np.random.default_rng(seed)
    grid = rng.uniform(0, 1, (cells, cells))
    x = np.arange(size) / size * cells
    i0 = np.floor(x).astype(int)
    f = x - i0
    f = f * f * (3 - 2 * f)
    a = grid[np.ix_(i0 % cells, i0 % cells)]
    b = grid[np.ix_(i0 % cells, (i0 + 1) % cells)]
    c = grid[np.ix_((i0 + 1) % cells, i0 % cells)]
    d = grid[np.ix_((i0 + 1) % cells, (i0 + 1) % cells)]
    fy, fx = f[:, None], f[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(size, seed, octaves=(4, 8, 16, 32), gains=(0.5, 0.25, 0.15, 0.1)):
    out = np.zeros((size, size))
    for k, (cells, g) in enumerate(zip(octaves, gains)):
        out += tile_noise(size, cells, seed + k * 17) * g
    return out / sum(gains)


def worley(size, cells, seed, jitter=0.9):
    """Tileable Worley noise: returns (F1, F2) distances in cell units."""
    rng = np.random.default_rng(seed)
    pts = rng.uniform(0.5 - jitter * 0.5, 0.5 + jitter * 0.5, (cells, cells, 2))
    coords = (np.arange(size) + 0.5) / size * cells
    gy, gx = np.meshgrid(coords, coords, indexing="ij")
    cy, cx = np.floor(gy).astype(int), np.floor(gx).astype(int)
    f1 = np.full((size, size), 9.0)
    f2 = np.full((size, size), 9.0)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ny, nx = cy + dy, cx + dx
            p = pts[ny % cells, nx % cells]
            px = nx + p[..., 0]
            py = ny + p[..., 1]
            d = np.sqrt((gx - px) ** 2 + (gy - py) ** 2)
            f2 = np.where(d < f1, f1, np.minimum(f2, d))
            f1 = np.minimum(f1, d)
    return f1, f2


def normal_from_height(h, strength):
    gy, gx = np.gradient(h)
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx, ny = -gx * strength, gy * strength
    nz = np.ones_like(h)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / length * 0.5 + 0.5, ny / length * 0.5 + 0.5, nz / length * 0.5 + 0.5], axis=-1)


# ---------------------------------------------------------------------------

def make_floor(size=1024):
    """4 x 4 large tiles (1 m each) of dark blue terrazzo with coloured chips."""
    rng = np.random.default_rng(5)
    px = size / 4.0
    yy, xx = np.meshgrid(np.arange(size), np.arange(size), indexing="ij")
    tile_x, tile_y = (xx // px).astype(int), (yy // px).astype(int)
    lx, ly = (xx % px) / px, (yy % px) / px
    # Each tile: a slightly different tone; a checker of two slate blues.
    tones = rng.uniform(-0.035, 0.035, (4, 4))
    base_a, base_b = hexc("#2c3f5c"), hexc("#26364f")
    checker = ((tile_x + tile_y) % 2)[..., None]
    rgb = base_a * (1 - checker) + base_b * checker
    rgb = rgb + tones[tile_y, tile_x][..., None]
    # Cloudy marbling.
    cloud = fbm(size, 9)
    rgb = rgb * (0.88 + cloud[..., None] * 0.24)
    # Terrazzo chips: worley cells, small, multi-coloured.
    f1, f2 = worley(size, 96, 21, 0.85)
    chip = smooth(0.28, 0.2, f1)
    chip_id = (worley(size, 96, 21, 0.85)[0] * 0 + tile_noise(size, 96, 33))
    palette = [hexc("#d8e6ef"), hexc("#5fb9c9"), hexc("#16233a"), hexc("#e08aa8"), hexc("#8fa4c4")]
    chip_rgb = np.zeros_like(rgb)
    for k, col in enumerate(palette):
        lo, hi = k / len(palette), (k + 1) / len(palette)
        sel = ((chip_id >= lo) & (chip_id < hi))[..., None]
        chip_rgb = np.where(sel, col, chip_rgb)
    sparse = (tile_noise(size, 96, 44) > 0.45)[..., None]
    rgb = rgb * (1 - chip[..., None] * sparse * 0.85) + chip_rgb * chip[..., None] * sparse * 0.85
    # Grout lines and a soft bevel at tile edges.
    edge = np.minimum(np.minimum(lx, 1 - lx), np.minimum(ly, 1 - ly))
    grout = smooth(0.012, 0.004, edge)
    bevel = smooth(0.04, 0.012, edge)
    rgb = rgb * (1 - bevel[..., None] * 0.18)
    rgb = rgb * (1 - grout[..., None]) + hexc("#111a29") * grout[..., None]
    save_rgb("aqua_floor_tiles.png", rgb)
    height = 1.0 - grout * 0.9 - bevel * 0.25 + chip * sparse[..., 0] * 0.05 + cloud * 0.02
    save_rgb("aqua_floor_tiles_normal.png", normal_from_height(height, 6.0))


def make_wall(size=512):
    """Vertical acoustic slats with a horizontal rail every 2 m (4 m tile)."""
    yy, xx = np.meshgrid(np.arange(size), np.arange(size), indexing="ij")
    u, v = xx / size * 4.0, yy / size * 4.0      # metres
    slat = (u * 6.0) % 1.0                          # 6 slats per metre
    groove = smooth(0.1, 0.0, slat) + smooth(0.9, 1.0, slat)
    rail_d = np.abs(((v + 1.0) % 2.0) - 1.0)        # distance to the rail lines at v = 1, 3
    rail = smooth(0.07, 0.05, rail_d)
    rail_edge = smooth(0.08, 0.07, rail_d) * (1 - rail)
    grain = fbm(size, 61, octaves=(4, 16, 64, 128), gains=(0.3, 0.3, 0.25, 0.15))
    base = hexc("#1d4a5c") * (0.92 + grain[..., None] * 0.16)
    rgb = base * (1 - groove[..., None] * 0.45)
    rgb = rgb * (1 - rail[..., None]) + hexc("#0f2b3a") * rail[..., None]
    rgb = rgb + rail_edge[..., None] * 0.08
    save_rgb("aqua_wall_panels.png", rgb)


def make_caustics(size=512):
    """Bright thin caustic network: the edges between Worley cells, softened."""
    f1, f2 = worley(size, 7, 77, 1.0)
    edge = f2 - f1
    a = np.exp(-(edge / 0.09) ** 1.4)
    f1b, f2b = worley(size, 11, 78, 1.0)
    b = np.exp(-((f2b - f1b) / 0.08) ** 1.4)
    val = np.clip(a * 0.8 + b * 0.45, 0, 1)
    val = val ** 1.2
    img = Image.fromarray((val * 255).astype(np.uint8), "L")
    img.save(os.path.join(OUT, "aqua_caustics.png"))
    print("wrote aqua_caustics.png", img.size)


def make_sand(size=512):
    yy, xx = np.meshgrid(np.arange(size), np.arange(size), indexing="ij")
    warp = fbm(size, 91) * 3.0
    ripple = 0.5 + 0.5 * np.sin((yy / size * 14 + warp) * math.tau)
    grain = tile_noise(size, 256, 92)
    rgb = hexc("#d9bf8f") * (0.82 + ripple[..., None] * 0.12 + grain[..., None] * 0.08)
    f1, _ = worley(size, 40, 93, 0.9)
    fleck = smooth(0.16, 0.08, f1) * (tile_noise(size, 40, 94) > 0.6)
    rgb = rgb * (1 - fleck[..., None] * 0.5) + hexc("#fff3e0") * fleck[..., None] * 0.5
    save_rgb("aqua_sand.png", rgb)


def make_carpet(size=512):
    """Deep blue carpet with teal wave lines (2 m tile)."""
    yy, xx = np.meshgrid(np.arange(size), np.arange(size), indexing="ij")
    u, v = xx / size, yy / size
    fib = tile_noise(size, 256, 120) * 0.5 + tile_noise(size, 128, 121) * 0.5
    rgb = hexc("#16244a") * (0.85 + fib[..., None] * 0.3)
    for k, (amp, off, col, w) in enumerate(((0.035, 0.25, "#2bb3c0", 0.018), (0.035, 0.75, "#2bb3c0", 0.018),
                                           (0.02, 0.5, "#ff6fae", 0.008))):
        y = off + amp * np.sin(u * math.tau * 2 + k)
        d = np.abs(v - y)
        line = smooth(w, w * 0.4, d)
        rgb = rgb * (1 - line[..., None]) + hexc(col) * (0.85 + fib[..., None] * 0.3) * line[..., None]
    save_rgb("aqua_carpet.png", rgb)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_floor()
    make_wall()
    make_caustics()
    make_sand()
    make_carpet()
