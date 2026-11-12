"""Generates the hand-rolled textures for Boardwalk Breakout (no third-party art):

    art/textures/sky_sunset.png          equirectangular sunset sky with chunky pink clouds
    art/textures/deck_planks.png         tileable boardwalk planks (albedo), 4 m per tile
    art/textures/deck_planks_normal.png  matching normal map

    python tools/gen_textures.py            (needs numpy + Pillow)
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
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        t = np.clip((x - p0) / (p1 - p0), 0.0, 1.0)[..., None]
        seg = c0 + (c1 - c0) * t
        mask = (x >= p0)[..., None]
        out = np.where(mask, seg, out)
    out = np.where((x < stops[0][0])[..., None], stops[0][1], out)
    return out


# ---------------------------------------------------------------------------
# Sky
# ---------------------------------------------------------------------------

def make_sky(width=4096, height=2048, seed=11):
    rng = np.random.default_rng(seed)
    az = (np.arange(width) + 0.5) / width * 360.0 - 180.0          # degrees, 0 = sun direction (image centre)
    el = 90.0 - (np.arange(height) + 0.5) / height * 180.0         # degrees, +90 = zenith
    AZ, EL = np.meshgrid(az, el)

    sun_el = 2.5
    # Angular distance from the sun.
    cosd = (np.sin(np.radians(EL)) * math.sin(math.radians(sun_el)) +
            np.cos(np.radians(EL)) * math.cos(math.radians(sun_el)) * np.cos(np.radians(AZ)))
    sun_dist = np.degrees(np.arccos(np.clip(cosd, -1, 1)))
    toward_sun = np.clip(1.0 - np.abs(AZ) / 180.0, 0, 1)             # 1 at the sun's azimuth, 0 opposite

    # Vertical gradient: deep blue zenith -> violet -> pink -> warm horizon.
    sky = ramp(EL, [
        (-90, hexc("#16365f")), (-6, hexc("#2b6f96")), (-0.5, hexc("#f6a58e")),
        (0.0, hexc("#ffa980")), (3, hexc("#ff9ba4")), (7, hexc("#ec98c6")), (12, hexc("#b490e6")),
        (19, hexc("#7c8af0")), (32, hexc("#5078ea")), (55, hexc("#3c62de")), (90, hexc("#2c4fcf")),
    ])

    # Warmer and brighter toward the sun, cooler and pinker away from it.
    warm = ramp(EL, [(-2, hexc("#ffd27a")), (4, hexc("#ffb866")), (10, hexc("#ff9a8e")), (20, hexc("#a88cea")), (34, hexc("#5078ea")), (90, hexc("#2c4fcf"))])
    glow = (smooth(75, 0, sun_dist) ** 1.8)[..., None] * smooth(-4, 2, EL)[..., None]
    sky = sky * (1 - glow * 0.7) + warm * glow * 0.7
    halo = np.exp(-(sun_dist / 9.0) ** 1.5)[..., None]
    sky = sky * (1 + halo[..., :1] * 0.0) + hexc("#ff9a50") * halo * 0.22
    disc = smooth(2.6, 2.2, sun_dist)[..., None]
    corona = smooth(6.0, 2.2, sun_dist)[..., None] ** 2
    sky = sky + hexc("#ffd070") * corona * 0.35
    sky = sky * (1 - disc) + hexc("#fff3b8") * disc

    # --- clouds: clusters of round puffs with lit tops and violet undersides ---
    cover = np.zeros((height, width))
    shade = np.zeros((height, width))       # 0 = underside, 1 = top
    rim = np.zeros((height, width))
    px_per_deg = width / 360.0

    def puff_cloud(c_az, c_el, span, puffs, size):
        nonlocal cover, shade, rim
        stretch = 1.0 / max(0.35, math.cos(math.radians(c_el)))
        base = c_el - size * 0.55
        circles = []
        for _ in range(puffs):
            t = rng.uniform(-1, 1)
            r = size * rng.uniform(0.45, 1.0) * (1.0 - 0.55 * abs(t) ** 1.5)
            circles.append((c_az + t * span, base + r * rng.uniform(0.75, 1.25), r))
        # A couple of big ones in the middle to give the cloud a crown.
        for _ in range(3):
            r = size * rng.uniform(0.95, 1.35)
            circles.append((c_az + rng.uniform(-0.35, 0.35) * span, base + r * 1.1, r))
        az0, az1 = c_az - span - size * 2.5, c_az + span + size * 2.5
        el0, el1 = base - size * 0.8, c_el + size * 3.2
        x0, x1 = int((az0 * stretch * 0 + az0 + 180) * px_per_deg), int((az1 + 180) * px_per_deg)
        pad = int(size * 2.5 * (stretch - 1) * px_per_deg) + 2
        x0, x1 = x0 - pad, x1 + pad
        y0 = max(0, int((90 - el1) / 180 * height))
        y1 = min(height, int((90 - el0) / 180 * height) + 1)
        xs = np.arange(x0, x1)
        ys = np.arange(y0, y1)
        if len(xs) == 0 or len(ys) == 0:
            return
        a = (xs + 0.5) / px_per_deg - 180.0
        e = 90.0 - (ys + 0.5) / height * 180.0
        A, E = np.meshgrid(a, e)
        dens = np.zeros(A.shape)
        top = np.zeros(A.shape)
        for (ca, ce, r) in circles:
            d2 = (((A - ca) / stretch) ** 2 + (E - ce) ** 2) / (r * r)
            m = np.clip(1.0 - d2, 0.0, 1.0)
            dens = np.maximum(dens, m)
            # Height inside the puff, lit from above.
            local = 0.45 * np.clip((E - (ce - r)) / (2 * r), 0, 1) + 0.55 * np.clip((E - base) / (size * 2.6), 0, 1)
            top = np.where(m >= dens - 1e-6, local, top)
        # Flat-ish bottom.
        dens = dens * smooth(base - size * 0.35, base + size * 0.1, E)
        mask = smooth(0.0, 0.16, dens)
        edge = smooth(0.0, 0.16, dens) * (1 - smooth(0.16, 0.5, dens))
        cols = xs % width
        region_c = cover[y0:y1][:, cols]
        region_s = shade[y0:y1][:, cols]
        region_r = rim[y0:y1][:, cols]
        new_c = np.maximum(region_c, mask)
        take = mask > region_c
        cover[np.ix_(ys, cols)] = new_c
        shade[np.ix_(ys, cols)] = np.where(take, top, region_s)
        rim[np.ix_(ys, cols)] = np.where(take, edge * smooth(0.35, 0.9, top), region_r)

    # Big hero clouds (a few placed like the reference: centre-left and right of the sun).
    hero = [(-62, 21, 13, 16, 4.6), (22, 15, 12, 15, 4.2), (-18, 34, 9, 12, 3.4), (58, 27, 10, 12, 3.4),
            (-105, 17, 12, 14, 4.0), (95, 13, 13, 14, 3.6), (150, 20, 14, 15, 4.4), (-150, 26, 12, 13, 3.8),
            (-38, 9, 8, 10, 2.4), (40, 37, 7, 9, 2.6), (-80, 40, 8, 10, 2.8), (118, 38, 9, 10, 2.8)]
    for (a, e, span, puffs, size) in hero:
        puff_cloud(a, e + 1.0, span * 1.1, puffs + 2, size * 1.12)
    for _ in range(15):
        size = rng.uniform(1.1, 2.2)
        puff_cloud(rng.uniform(-180, 180), rng.uniform(6, 52), size * rng.uniform(2.0, 3.6), int(rng.integers(6, 11)), size)

    # Cloud colours: bright pink tops, magenta bodies, violet undersides; warmer near the sun.
    sun_side = (smooth(120, 10, sun_dist))[..., None]
    c_top = hexc("#ffc2dc") * (1 - sun_side) + hexc("#ffd9b0") * sun_side
    c_mid = hexc("#ff86c0") * (1 - sun_side) + hexc("#ff9a94") * sun_side
    c_low = hexc("#9a62cf") * (1 - sun_side) + hexc("#d0669e") * sun_side
    s = shade[..., None]
    cloud = np.where(s < 0.5, c_low + (c_mid - c_low) * (s / 0.5), c_mid + (c_top - c_mid) * ((s - 0.5) / 0.5))
    cloud = cloud + hexc("#fff0e0") * rim[..., None] * 0.5
    # Fade clouds slightly into the horizon haze.
    haze = smooth(2.0, 12.0, EL)[..., None]
    alpha = cover[..., None] * (0.55 + 0.45 * haze)
    sky = sky * (1 - alpha) + cloud * alpha

    # Thin warm streaks low on the horizon.
    for _ in range(14):
        ca, ce = rng.uniform(-180, 180), rng.uniform(2.0, 9.0)
        w, h = rng.uniform(10, 26), rng.uniform(0.35, 0.8)
        d = ((((AZ - ca + 180) % 360) - 180) / w) ** 2 + ((EL - ce) / h) ** 2
        streak = np.clip(1 - d, 0, 1)[..., None] ** 1.5
        col = hexc("#ffb0a0") * (0.5 + 0.5 * toward_sun[..., None]) + hexc("#e080c0") * (0.5 - 0.5 * toward_sun[..., None])
        sky = sky * (1 - streak * 0.55) + col * streak * 0.55

    img = Image.fromarray((np.clip(sky, 0, 1) * 255).astype(np.uint8), "RGB")
    img.save(os.path.join(OUT, "sky_sunset.png"), optimize=True)
    print("sky_sunset.png", img.size)


# ---------------------------------------------------------------------------
# Deck planks
# ---------------------------------------------------------------------------

def periodic_noise(rng, n, octaves=4):
    """1D tileable value noise of length n."""
    out = np.zeros(n)
    amp = 1.0
    for o in range(octaves):
        k = 4 * 2 ** o
        pts = rng.uniform(-1, 1, k)
        x = np.arange(n) / n * k
        i0 = np.floor(x).astype(int) % k
        i1 = (i0 + 1) % k
        t = x - np.floor(x)
        t = t * t * (3 - 2 * t)
        out += amp * (pts[i0] * (1 - t) + pts[i1] * t)
        amp *= 0.5
    return out


def make_planks(size=1024, planks=20, seed=5):
    rng = np.random.default_rng(seed)
    ph = size // planks                      # plank height in pixels (planks run along U)
    albedo = np.zeros((size, size, 3))
    height = np.ones((size, size))
    palette = [hexc(c) for c in ("#7c4638", "#6f3d34", "#87523e", "#653632", "#76443b", "#8d5842")]
    for p in range(planks):
        y0 = p * ph
        y1 = size if p == planks - 1 else y0 + ph
        rows = y1 - y0
        base = palette[rng.integers(len(palette))] * rng.uniform(0.92, 1.06)
        # Long grain streaks: noise stretched along U, a little variation across the plank.
        grain = np.zeros((rows, size))
        for r in range(rows):
            grain[r] = periodic_noise(rng, size, 5) * 0.5 if r % 3 == 0 else grain[r - 1]
        grain = (grain + np.roll(grain, 1, axis=0) + np.roll(grain, -1, axis=0)) / 3.0
        broad = periodic_noise(rng, size, 2)[None, :] * 0.5
        tone = 1.0 + grain * 0.11 + broad * 0.07
        albedo[y0:y1] = base[None, None, :] * tone[..., None]
        # Seam between planks.
        seam = np.ones(rows)
        seam[:2] = 0.0
        seam[2:4] = 0.55
        seam[-1:] = 0.6
        height[y0:y1] *= seam[:, None]
        # Butt joints with nail heads, staggered per plank.
        joints = (rng.uniform(0, size) + np.array([0.0, size * rng.uniform(0.42, 0.6)])) % size
        for j in joints:
            j = int(j)
            for dx in range(-1, 2):
                height[y0:y1, (j + dx) % size] *= 0.25 if dx == 0 else 0.7
            for nx in (-14, 14):
                for ny in (int(rows * 0.28), int(rows * 0.72)):
                    cy, cx = y0 + ny, (j + nx) % size
                    for dy in range(-3, 4):
                        for dx in range(-3, 4):
                            if dy * dy + dx * dx <= 9:
                                yy, xx = cy + dy, (cx + dx) % size
                                if 0 <= yy < size:
                                    height[yy, xx] = min(height[yy, xx], 0.45 if dy * dy + dx * dx <= 4 else 0.75)
    dark = hexc("#4a2630")
    shade = height[..., None]
    albedo = albedo * (0.35 + 0.65 * shade) + dark * (1 - shade) * 0.35
    img = Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8), "RGB")
    img.save(os.path.join(OUT, "deck_planks.png"), optimize=True)

    # Normal map from the height field (tileable).
    h = height.astype(np.float64)
    for _ in range(2):
        h = (h + np.roll(h, 1, 0) + np.roll(h, -1, 0) + np.roll(h, 1, 1) + np.roll(h, -1, 1)) / 5.0
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 2.2
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 2.2
    n = np.stack([-dx, -dy, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    nimg = Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB")
    nimg.save(os.path.join(OUT, "deck_planks_normal.png"), optimize=True)
    print("deck_planks.png", img.size)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_sky()
    make_planks()
