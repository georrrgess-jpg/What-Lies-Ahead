"""Generates the hand-rolled textures for World 5, Frostpeak Resort (no third-party art):

    art/textures/frost_sky.png            equirectangular twilight sky: stars, a crescent moon,
                                          a faint aurora glow and far mountain ranges
    art/textures/frost_snow.png           tileable lavender snow (albedo), 1 tile = ~6 m
    art/textures/frost_snow_normal.png    matching normal map (soft drifts and dimples)
    art/textures/frost_ice.png            ice detail: R cracks, G frost, B bubbles (frost_ice.gdshader)
    art/textures/frost_timber.png         snowy deck boards for the lodge terrace (+ _normal)
    art/textures/frost_stone.png          flagstone paving with snow in the joints (+ _normal)
    art/textures/frost_path.png           packed-snow trail with ski and sled tracks (tiles along V)

    python tools/gen_textures_frost.py            (needs numpy + Pillow)
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


def ramp(x, stops):
    """Piecewise-linear colour ramp. stops = [(position, colour), ...] sorted by position."""
    out = np.zeros(x.shape + (3,))
    out[...] = stops[0][1]
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        t = np.clip((x - p0) / (p1 - p0), 0.0, 1.0)[..., None]
        seg = c0 + (c1 - c0) * t
        out = np.where((x >= p0)[..., None], seg, out)
    return out


def save_rgb(name, arr):
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGB")
    img.save(os.path.join(OUT, name), optimize=True)
    print(name, img.size)


def periodic_noise(rng, size, beta=2.0, low_cut=1.0):
    """Tileable 2D noise (white noise shaped by 1/f^beta in frequency space), range ~0..1."""
    white = rng.normal(0, 1, (size, size))
    f = np.fft.fftfreq(size)[:, None] ** 2 + np.fft.fftfreq(size)[None, :] ** 2
    f = np.sqrt(f) * size
    f[0, 0] = 1.0
    gain = 1.0 / np.maximum(f, low_cut) ** beta
    gain[0, 0] = 0.0
    n = np.real(np.fft.ifft2(np.fft.fft2(white) * gain))
    n = (n - n.min()) / (n.max() - n.min() + 1e-9)
    return n


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
    """F1, F2 distances (pixels) and the nearest cell id for a tileable Voronoi diagram."""
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


# ---------------------------------------------------------------------------
# Sky
# ---------------------------------------------------------------------------

def make_sky(width=4096, height=2048, seed=23):
    """Image centre (azimuth 0) is +Z in Godot: the valley side, where the last
    of the sunset glows. Azimuth +-180 (the image edges) is the north, over the
    lodge, where the aurora hangs."""
    rng = np.random.default_rng(seed)
    az = (np.arange(width) + 0.5) / width * 360.0 - 180.0
    el = 90.0 - (np.arange(height) + 0.5) / height * 180.0
    AZ, EL = np.meshgrid(az, el)
    toward_glow = np.clip(np.cos(np.radians(AZ - 20.0)), 0, 1) ** 1.6     # afterglow a little right of centre
    toward_north = np.clip(-np.cos(np.radians(AZ)), 0, 1)

    sky = ramp(EL, [
        (-90, hexc("#191a40")), (-4, hexc("#2c2a63")), (0, hexc("#4a3a86")), (3, hexc("#5d4796")),
        (8, hexc("#4a3d8e")), (16, hexc("#33307a")), (30, hexc("#222260")), (55, hexc("#141849")), (90, hexc("#0b0e33")),
    ])
    glow = ramp(EL, [
        (-4, hexc("#3b2c66")), (0, hexc("#ff9c74")), (2.5, hexc("#ff8c88")), (6, hexc("#d8689e")),
        (12, hexc("#8a4ea6")), (22, hexc("#40357e")), (40, hexc("#1b1c55")), (90, hexc("#0b0e33")),
    ])
    k = (toward_glow * smooth(28, 0, EL) * smooth(-5, 0, EL))[..., None]
    sky = sky * (1 - k * 0.85) + glow * k * 0.85

    # Painted aurora glow over the north: two soft arcs of green with violet tops.
    for (centre_el, amp, phase, width_deg, strength) in ((24, 7, 0.0, 6.0, 0.5), (34, 9, 1.7, 5.0, 0.32)):
        arc = centre_el + amp * np.sin(np.radians(AZ) * 2.0 + phase) * 0.5 + 3.0 * np.sin(np.radians(AZ) * 5.0 + phase)
        d = (EL - arc) / width_deg
        hem = np.exp(-np.clip(d, -10, 10) ** 2 * 2.5) * (EL > arc - width_deg)
        curtain = np.exp(-np.clip(d - 1.2, 0, 10) * 0.9) * smooth(arc - 0.5, arc + 0.5, EL)
        rays = 0.8 + 0.2 * np.sin(np.radians(AZ) * 46.0 + np.sin(np.radians(AZ) * 9.0) * 3.0)
        mask = (toward_north ** 1.3 * strength)[..., None]
        sky += hexc("#3cff9a") * (hem * rays)[..., None] * mask * 0.55
        sky += hexc("#9a5cff") * (curtain * (1 - hem) * rays * smooth(0, 1, d))[..., None] * mask * 0.35

    # Stars: denser and brighter toward the zenith, hidden by the afterglow.
    star_layer = np.zeros((height, width))
    count = 5200
    sx = rng.integers(0, width, count)
    sy = (np.arccos(rng.uniform(0.02, 1.0, count)) / math.pi * height).astype(int)   # uniform on the upper hemisphere
    sy = np.clip(sy, 0, height // 2 - 20)
    mag = rng.uniform(0, 1, count) ** 3.5
    for x, y, m in zip(sx, sy, mag):
        r = 1 if m < 0.5 else 2
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                fall = math.exp(-(dx * dx + dy * dy) / (0.6 + m * 1.6))
                yy, xx = y + dy, (x + dx) % width
                star_layer[yy, xx] = max(star_layer[yy, xx], (0.35 + 0.65 * m) * fall)
    star_vis = smooth(4, 20, EL) * (1 - 0.85 * toward_glow * smooth(30, 5, EL))
    sky += (star_layer * star_vis)[..., None] * hexc("#e8ecff")

    # Crescent moon with a soft halo (south-east, opposite the afterglow's lean).
    moon_az, moon_el, moon_r = -55.0, 34.0, 1.6
    stretch = 1.0 / math.cos(math.radians(moon_el))
    dmoon = np.sqrt(((AZ - moon_az) / stretch) ** 2 + (EL - moon_el) ** 2)
    dcut = np.sqrt(((AZ - moon_az - 0.7) / stretch) ** 2 + (EL - moon_el - 0.45) ** 2)
    disc = smooth(moon_r, moon_r - 0.15, dmoon) * smooth(moon_r - 0.2, moon_r + 0.05, dcut)
    halo = np.exp(-(dmoon / 7.0) ** 1.4)
    sky += hexc("#5c63b8") * halo[..., None] * 0.35
    sky = sky * (1 - disc[..., None]) + hexc("#fff6dc") * disc[..., None]

    # Far mountain ranges along the horizon (two layers, snowy tops lit by the glow).
    for layer, (base_el, amp, col_dark, col_snow, freq_seed) in enumerate((
            (1.0, 7.5, "#2a2a5e", "#8f86c8", 3), (0.4, 4.0, "#3a3470", "#b9a6dc", 9))):
        lr = np.random.default_rng(freq_seed)
        prof = np.zeros(width)
        a = np.radians(az)
        for k_, amp_k in ((2, 1.0), (5, 0.55), (11, 0.32), (23, 0.18), (47, 0.08)):
            prof += amp_k * np.sin(a * k_ + lr.uniform(0, math.tau))
        prof = base_el + amp * (0.5 + 0.5 * prof / 2.1) ** 1.6
        top = prof[None, :]
        inside = EL < top
        snow = smooth(top - 1.4, top - 0.2, EL) * inside
        col = hexc(col_dark) * (1 - snow[..., None]) + hexc(col_snow) * snow[..., None]
        lit = (toward_glow * 0.7)[..., None]
        col = col * (1 - lit * 0.4) + (col * hexc("#ff9ab0")) * lit * 0.8
        haze = smooth(-2, 6, EL)[..., None] * (0.35 if layer == 0 else 0.5)
        col = col * (1 - haze) + sky * haze
        sky = np.where(inside[..., None], col, sky)

    save_rgb("frost_sky.png", sky)


# ---------------------------------------------------------------------------
# Snow
# ---------------------------------------------------------------------------

def make_snow(size=1024, seed=31):
    rng = np.random.default_rng(seed)
    drifts = periodic_noise(rng, size, beta=1.9, low_cut=2.0)
    fine = periodic_noise(rng, size, beta=1.1, low_cut=40.0)
    dimples = np.zeros((size, size))
    ys, xs = np.mgrid[0:size, 0:size]
    for _ in range(420):
        cx, cy, r = rng.uniform(0, size), rng.uniform(0, size), rng.uniform(4, 13)
        dx = np.minimum(np.abs(xs - cx), size - np.abs(xs - cx))
        dy = np.minimum(np.abs(ys - cy), size - np.abs(ys - cy))
        d = np.sqrt(dx * dx + dy * dy) / r
        dimples -= np.clip(1 - d * d, 0, 1) ** 2 * rng.uniform(0.2, 0.6)
    height = drifts * 0.8 + fine * 0.2 + dimples * 0.06
    shade = smooth(0.15, 0.85, drifts)[..., None]
    albedo = hexc("#c9c8f2") * (1 - shade) + hexc("#f2f2ff") * shade
    albedo = albedo * (0.95 + fine[..., None] * 0.08) + (dimples[..., None] * 0.12) * hexc("#7a78c8")
    save_rgb("frost_snow.png", albedo)
    save_rgb("frost_snow_normal.png", normal_from_height(blur(height, 2), 6.0))


# ---------------------------------------------------------------------------
# Ice
# ---------------------------------------------------------------------------

def make_ice(size=1024, seed=41):
    rng = np.random.default_rng(seed)
    f1, f2, _ = periodic_voronoi(rng, size, 46)
    edge = f2 - f1
    cracks = np.clip(1 - edge / 3.2, 0, 1) ** 1.5
    # Break up the cell edges so they read as cracks, not a mesh.
    cracks *= smooth(0.35, 0.6, periodic_noise(rng, size, beta=1.5, low_cut=4.0))
    # A few long radial fractures.
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64)
    for _ in range(9):
        x, y = rng.uniform(0, size, 2)
        ang = rng.uniform(0, math.tau)
        for _ in range(int(rng.integers(30, 70))):
            ang += rng.normal(0, 0.25)
            nx, ny = x + math.cos(ang) * 6, y + math.sin(ang) * 6
            for t in np.linspace(0, 1, 7):
                px, py = int(x + (nx - x) * t) % size, int(y + (ny - y) * t) % size
                cracks[py, px] = 1.0
                cracks[py, (px + 1) % size] = max(cracks[py, (px + 1) % size], 0.6)
            x, y = nx, ny
    cracks = np.clip(blur(cracks, 1) * 1.6, 0, 1)
    frost = smooth(0.45, 0.85, periodic_noise(rng, size, beta=1.7, low_cut=3.0))
    bubbles = np.zeros((size, size))
    for _ in range(900):
        cx, cy, r = rng.uniform(0, size), rng.uniform(0, size), rng.uniform(1.5, 5.0)
        x0, x1, y0, y1 = int(cx - r - 2), int(cx + r + 3), int(cy - r - 2), int(cy + r + 3)
        for yy in range(y0, y1):
            for xx in range(x0, x1):
                d = math.hypot(xx - cx, yy - cy) / r
                if d < 1.0:
                    v = 0.4 + 0.6 * (d > 0.65)
                    bubbles[yy % size, xx % size] = max(bubbles[yy % size, xx % size], v)
    save_rgb("frost_ice.png", np.stack([cracks, frost, bubbles], axis=-1))


# ---------------------------------------------------------------------------
# Timber deck and flagstones
# ---------------------------------------------------------------------------

def make_timber(size=1024, planks=8, seed=51):
    rng = np.random.default_rng(seed)
    ph = size // planks
    albedo = np.zeros((size, size, 3))
    height = np.ones((size, size))
    palette = [hexc(c) for c in ("#6e4636", "#7a4e3a", "#634033", "#835640", "#6a4438")]
    for p in range(planks):
        y0, y1 = p * ph, (p + 1) * ph
        base = palette[rng.integers(len(palette))] * rng.uniform(0.92, 1.06)
        grain = periodic_noise(rng, size, beta=1.4, low_cut=3.0)[y0:y1]
        streak = np.sin(np.linspace(0, math.tau * rng.uniform(3, 7), size) + rng.uniform(0, 6))[None, :]
        tone = 0.88 + grain * 0.2 + streak * 0.03
        albedo[y0:y1] = base * tone[..., None]
        seam = np.ones(ph)
        seam[:3] = 0.0
        seam[3:5] = 0.6
        height[y0:y1] *= seam[:, None]
        for j in (rng.uniform(0, size), ):
            j = int(j)
            height[y0:y1, j % size] *= 0.2
            height[y0:y1, (j + 1) % size] *= 0.6
    # Snow drifted into the seams and a light dusting.
    dust = smooth(0.62, 0.9, periodic_noise(rng, size, beta=1.6, low_cut=3.0))
    seam_snow = (1 - height) * 0.9
    snow = np.clip(seam_snow + dust * 0.5, 0, 1)[..., None]
    albedo = albedo * (0.5 + 0.5 * height[..., None])
    albedo = albedo * (1 - snow) + hexc("#e3e2fb") * snow
    save_rgb("frost_timber.png", albedo)
    save_rgb("frost_timber_normal.png", normal_from_height(blur(height * (1 - dust * 0.3), 1), 2.5))


def make_stone(size=1024, seed=61):
    rng = np.random.default_rng(seed)
    f1, f2, ids = periodic_voronoi(rng, size, 38)
    edge = f2 - f1
    joint = smooth(3.0, 9.0, edge)                     # 0 in the joints
    tones = rng.uniform(0, 1, 38)
    palette = [hexc(c) for c in ("#6d6a8e", "#7c7898", "#5e5b80", "#8a86a6", "#716c90")]
    base = np.array([palette[i % len(palette)] for i in range(38)])
    stone = base[ids] * (0.9 + tones[ids][..., None] * 0.2)
    grit = periodic_noise(rng, size, beta=1.0, low_cut=60.0)
    stone *= (0.9 + grit[..., None] * 0.18)
    bevel = smooth(2.0, 9.0, edge)
    stone *= (0.75 + 0.25 * bevel[..., None])
    snow = (1 - joint)[..., None]
    albedo = stone * (1 - snow) + hexc("#dcdcf8") * snow
    height = joint * (0.6 + 0.4 * bevel) + grit * 0.05
    save_rgb("frost_stone.png", albedo)
    save_rgb("frost_stone_normal.png", normal_from_height(blur(height, 1), 3.0))


def make_path(width=512, height=1024, seed=71):
    """Packed trail snow; U runs across the trail, V along it (tiles along V)."""
    rng = np.random.default_rng(seed)
    n = periodic_noise(rng, height, beta=1.6, low_cut=3.0)[:, :width]
    u = (np.arange(width) + 0.5) / width
    v = (np.arange(height) + 0.5) / height
    U, V = np.meshgrid(u, v)
    albedo = hexc("#b9b6e6") * (0.92 + n[..., None] * 0.12)
    # Two pairs of ski tracks that wander gently (periodic in V).
    for centre, amp, phase in ((0.3, 0.035, 0.0), (0.68, 0.03, 2.0)):
        c = centre + amp * np.sin(V * math.tau * 2 + phase)
        for off in (-0.045, 0.045):
            d = np.abs(U - (c + off)) * width
            groove = np.clip(1 - d / 5.0, 0, 1)
            albedo = albedo * (1 - groove[..., None] * 0.22) + hexc("#8e8ac8") * groove[..., None] * 0.1
    # Boot prints down the middle.
    for i in range(14):
        cy = (i + 0.5) / 14 * height
        cx = (0.5 + (0.05 if i % 2 else -0.05)) * width
        d = np.sqrt(((U * width - cx) / 9.0) ** 2 + ((V * height - cy) / 18.0) ** 2)
        print_mask = np.clip(1 - d, 0, 1) ** 0.5 * (d < 1)
        albedo = albedo * (1 - print_mask[..., None] * 0.18)
    # Soft lighter edges blend into the surrounding snow.
    edge = smooth(0.0, 0.12, U) * smooth(0.0, 0.12, 1 - U)
    albedo = albedo * edge[..., None] + hexc("#e6e6ff") * (1 - edge[..., None])
    save_rgb("frost_path.png", albedo)


if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    wanted = sys.argv[1:] or ["sky", "snow", "ice", "timber", "stone", "path"]
    for key in wanted:
        globals()["make_" + key]()
