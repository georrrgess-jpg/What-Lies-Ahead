"""Generates the hand-rolled textures for World 4, Dune Spaceport (no third-party art):

    art/textures/dune_sky.png               golden-hour desert sky: ringed planet, two moons,
                                            cirrus streaks and faint far mesas (equirectangular)
    art/textures/dune_concrete.png          sun-bleached launch-pad concrete, 4 m slabs, 8 m per tile
    art/textures/dune_concrete_normal.png   matching normal map
    art/textures/dune_sand.png              rippled sand, 8 m per tile
    art/textures/dune_sand_normal.png       matching normal map
    art/textures/dune_hazard.png            diagonal yellow/black hazard stripes (painted kerbs)
    art/textures/dune_noise.png             tileable fbm noise (R, G, B = three independent fields)
                                            used by the dune shaders (sand drifts, wisps, vapour)

    python tools/gen_textures_dune.py        (needs numpy + Pillow)
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
        out = np.where((x >= p0)[..., None], c0 + (c1 - c0) * t, out)
    return np.where((x < stops[0][0])[..., None], stops[0][1], out)


def save_rgb(arr, name):
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGB")
    img.save(os.path.join(OUT, name), optimize=True)
    print(name, img.size)


# ---------------------------------------------------------------------------
# Tileable noise
# ---------------------------------------------------------------------------

def value_noise(rng, h, w, cells_y, cells_x):
    """2D value noise that tiles on both axes (smoothstep interpolation)."""
    grid = rng.uniform(-1, 1, (cells_y, cells_x))
    y = np.arange(h) / h * cells_y
    x = np.arange(w) / w * cells_x
    y0 = np.floor(y).astype(int)
    x0 = np.floor(x).astype(int)
    ty = (y - y0)[:, None]
    tx = (x - x0)[None, :]
    ty = ty * ty * (3 - 2 * ty)
    tx = tx * tx * (3 - 2 * tx)
    y1, x1 = (y0 + 1) % cells_y, (x0 + 1) % cells_x
    y0, x0 = y0 % cells_y, x0 % cells_x
    a = grid[y0][:, x0]
    b = grid[y0][:, x1]
    c = grid[y1][:, x0]
    d = grid[y1][:, x1]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def fbm(rng, h, w, base_y, base_x, octaves=5, gain=0.5):
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        out += value_noise(rng, h, w, base_y * 2 ** o, base_x * 2 ** o) * amp
        total += amp
        amp *= gain
    return out / total


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.stack([-dx, -dy, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


# ---------------------------------------------------------------------------
# Sky
# ---------------------------------------------------------------------------

SUN_EL = 5.0          # visible sun elevation (degrees); the key light sits higher in the level
PLANET = (80.0, 25.0, 10.5)      # azimuth (from the sun), elevation, angular radius (degrees)
MOONS = [(-30.0, 40.0, 2.8, "#f6e7cf", "#b39a8a"), (-50.0, 19.0, 1.6, "#e6a27a", "#93584a")]


def make_sky(width=4096, height=2048, seed=23):
    rng = np.random.default_rng(seed)
    az = (np.arange(width) + 0.5) / width * 360.0 - 180.0          # 0 = sun azimuth (image centre)
    el = 90.0 - (np.arange(height) + 0.5) / height * 180.0
    AZ, EL = np.meshgrid(az, el)
    rad = np.radians
    cosd = np.sin(rad(EL)) * math.sin(rad(SUN_EL)) + np.cos(rad(EL)) * math.cos(rad(SUN_EL)) * np.cos(rad(AZ))
    sun_dist = np.degrees(np.arccos(np.clip(cosd, -1, 1)))
    toward = (0.5 + 0.5 * np.cos(rad(AZ)))[..., None]              # 1 toward the sun, 0 away

    # Away from the sun: dusty rose horizon into violet and indigo.
    cool = ramp(EL, [
        (-90, hexc("#5a3a3e")), (-4, hexc("#b9775e")), (0.0, hexc("#f2a88a")), (3, hexc("#ee9f8c")),
        (9, hexc("#d98897")), (17, hexc("#ad73a3")), (28, hexc("#80619f")), (45, hexc("#5a4b8f")),
        (65, hexc("#3d3676")), (90, hexc("#2c2860")),
    ])
    # Toward the sun: gold horizon into peach, salmon and mauve.
    warm = ramp(EL, [
        (-90, hexc("#6a4636")), (-4, hexc("#d08a58")), (0.0, hexc("#ffd690")), (3, hexc("#ffc27a")),
        (8, hexc("#ffa46e")), (15, hexc("#f2887a")), (26, hexc("#c47490")), (42, hexc("#7f5e9c")),
        (65, hexc("#463c80")), (90, hexc("#2c2860")),
    ])
    sky = cool * (1 - toward ** 1.1) + warm * toward ** 1.1

    # Faint stars on the dark side, high up.
    stars = (rng.uniform(0, 1, (height, width)) > 0.9993).astype(float)
    stars *= rng.uniform(0.3, 1.0, (height, width))
    stars *= smooth(30, 70, EL) * (1 - toward[..., 0]) ** 2
    sky += stars[..., None] * 0.55

    # Cirrus streaks: noise stretched along the azimuth, warm-lit near the sun.
    n1 = fbm(rng, height, width, 64, 6, octaves=5)
    n2 = fbm(rng, height, width, 128, 12, octaves=4)
    band = smooth(6, 12, EL) * (1 - smooth(32, 46, EL))
    streak = np.clip((n1 * 0.7 + n2 * 0.5) * 2.2 - 0.18, 0, 1) ** 1.6 * band
    c_lit = hexc("#ffd8b0") * toward + hexc("#f4a6b8") * (1 - toward)
    c_dim = hexc("#e48a7c") * toward + hexc("#9a6aa8") * (1 - toward)
    shade = np.clip(0.5 + n2 * 1.4, 0, 1)[..., None]
    cloud = c_dim + (c_lit - c_dim) * shade
    a = (streak * 0.62)[..., None]
    sky = sky * (1 - a) + cloud * a

    # A few low altocumulus ribbons near the horizon.
    for _ in range(9):
        ca, ce = rng.uniform(-180, 180), rng.uniform(3.0, 10.0)
        w, h = rng.uniform(18, 40), rng.uniform(0.5, 1.2)
        d = ((((AZ - ca + 180) % 360) - 180) / w) ** 2 + ((EL - ce) / h) ** 2
        rib = (np.clip(1 - d, 0, 1) ** 1.3)[..., None] * (0.6 + 0.4 * np.clip(n2[..., None] + 0.5, 0, 1))
        col = hexc("#ffc890") * toward + hexc("#d78aa0") * (1 - toward)
        sky = sky * (1 - rib * 0.5) + col * rib * 0.5

    # Sun: soft wide glow, corona and a bright disc.
    glow = np.exp(-(sun_dist / 22.0) ** 1.4)[..., None]
    sky = sky + hexc("#ffb060") * glow * 0.32
    corona = np.exp(-(sun_dist / 5.0) ** 1.6)[..., None]
    sky = sky + hexc("#ffe2a0") * corona * 0.55
    disc = smooth(2.3, 1.9, sun_dist)[..., None]
    sky = sky * (1 - disc) + hexc("#fff6d8") * disc

    sky = _draw_planet(sky, AZ, EL, rng)
    for m in MOONS:
        sky = _draw_moon(sky, AZ, EL, rng, *m)

    # Far mesas on the horizon, hazy violet-peach silhouettes.
    prof = np.zeros(width)
    for k, amp in ((7, 1.0), (19, 0.5), (47, 0.25)):
        pts = rng.uniform(0, 1, k)
        x = np.arange(width) / width * k
        i0 = np.floor(x).astype(int) % k
        t = x - np.floor(x)
        t = t * t * (3 - 2 * t)
        prof += amp * (pts[i0] * (1 - t) + pts[(i0 + 1) % k] * t)
    prof /= 1.75
    flat = np.round(prof * 4.0) / 4.0                     # quantised: flat mesa tops
    top = 0.3 + np.clip(flat * 0.6 + prof * 0.4 - 0.2, 0, 1) * 3.4
    rim = smooth(0.0, -0.25, EL - top[None, :])
    haze_col = hexc("#c58a86") * toward + hexc("#8f6a9a") * (1 - toward)
    m = (rim * smooth(-1.5, 0.0, EL))[..., None]
    sky = sky * (1 - m * 0.7) + haze_col * m * 0.7
    img = sky
    save_rgb(img, "dune_sky.png")


def _local(AZ, EL, c_az, c_el):
    """Small-angle tangent-plane offsets (degrees) around (c_az, c_el)."""
    daz = ((AZ - c_az + 180) % 360) - 180
    return daz * math.cos(math.radians(c_el)), EL - c_el


def _draw_planet(sky, AZ, EL, rng):
    p_az, p_el, r = PLANET
    u, v = _local(AZ, EL, p_az, p_el)
    tilt = math.radians(-18)
    ru = u * math.cos(tilt) - v * math.sin(tilt)
    rv = u * math.sin(tilt) + v * math.cos(tilt)
    d = np.sqrt(u * u + v * v) / r
    body = smooth(1.0, 0.985, d)
    # Banded atmosphere in the planet's tilted frame.
    lat = np.clip(rv / r, -1, 1)
    bands = 0.5 + 0.5 * np.sin(lat * 13.0 + np.sin(ru / r * 3.0) * 0.4) * 0.6 + 0.2 * np.sin(lat * 31.0)
    base = ramp(np.clip(bands, 0, 1), [(0.0, hexc("#7fa6b8")), (0.45, hexc("#b7c3c4")), (0.75, hexc("#e2cdb0")), (1.0, hexc("#f0dcc0"))])
    # Lit from the sun (to the planet's right: toward azimuth 0).
    nz = np.sqrt(np.clip(1 - d * d, 0, 1))
    # Sphere normal dotted with a light from the right (toward the sun), slightly above.
    toward_sun = -1.0 if p_az > 0 else 1.0
    ndl = (toward_sun * u / r) * 0.8 + nz * 0.55 + (v / r) * 0.12
    light = 0.18 + 0.95 * smooth(-0.35, 0.6, ndl)
    lit = base * light[..., None]
    night = hexc("#3b3a66")
    lit = lit + night * (1 - smooth(-0.35, 0.2, ndl))[..., None] * 0.35
    limb = smooth(0.72, 1.0, d)[..., None]
    rim_light = smooth(0.0, 0.7, toward_sun * u / r)[..., None]
    lit = lit * (1 - limb * 0.25) + hexc("#ffc8a0") * limb * rim_light * 0.35
    # Seen through the atmosphere: let a little sky through.
    alpha = (body * 0.84)[..., None]
    sky = sky * (1 - alpha) + lit * alpha
    # Rings: an annulus seen at a shallow angle, in front of the lower half.
    rx = ru / r
    ry = rv / (r * 0.24)
    rr = np.sqrt(rx * rx + ry * ry)
    ring = smooth(1.32, 1.4, rr) * (1 - smooth(2.15, 2.25, rr))
    gaps = 0.55 + 0.45 * np.sin(rr * 26.0) ** 2
    gap_main = 1 - 0.85 * smooth(0.04, 0.0, np.abs(rr - 1.78))
    ring = ring * gaps * gap_main
    behind = (ry > 0) & (d < 1.0)
    ring = np.where(behind, 0.0, ring)
    ring_col = ramp(np.clip((rr - 1.3) / 0.95, 0, 1), [(0.0, hexc("#e8d2b4")), (0.5, hexc("#c9a98e")), (1.0, hexc("#f2e0c8"))])
    ring_col = ring_col * np.clip(0.95 + 0.15 * toward_sun * u / r, 0.6, 1.15)[..., None]
    a = (ring * 0.75)[..., None]
    sky = sky * (1 - a) + ring_col * a
    return sky


def _draw_moon(sky, AZ, EL, rng, m_az, m_el, r, light_hex, dark_hex):
    u, v = _local(AZ, EL, m_az, m_el)
    d = np.sqrt(u * u + v * v) / r
    body = smooth(1.0, 0.95, d)
    nz = np.sqrt(np.clip(1 - d * d, 0, 1))
    # Sun at azimuth 0: light from the left of these moons (they sit right of the sun).
    lx = -1.0 if m_az > 0 else 1.0
    light = np.clip(0.15 + 1.1 * (lx * u / r * 0.8 + nz * 0.5), 0, 1)
    crater = np.zeros_like(u)
    for _ in range(9):
        cu, cv, cr = rng.uniform(-0.7, 0.7) * r, rng.uniform(-0.7, 0.7) * r, rng.uniform(0.08, 0.22) * r
        crater += smooth(cr, cr * 0.6, np.sqrt((u - cu) ** 2 + (v - cv) ** 2)) * 0.35
    col = hexc(dark_hex) + (hexc(light_hex) - hexc(dark_hex)) * np.clip(light - crater, 0, 1)[..., None]
    a = (body * 0.92)[..., None]
    return sky * (1 - a) + col * a


# ---------------------------------------------------------------------------
# Concrete
# ---------------------------------------------------------------------------

def make_concrete(size=1024, seed=7):
    """8 m tile, four 4 m slabs with sanded joints, aggregate, stains and cracks."""
    rng = np.random.default_rng(seed)
    half = size // 2
    yy, xx = np.mgrid[0:size, 0:size]
    base = hexc("#cdb9a0")
    tone = np.ones((size, size))
    for sy in range(2):
        for sx in range(2):
            tone[sy * half:(sy + 1) * half, sx * half:(sx + 1) * half] *= rng.uniform(0.92, 1.05)
    broad = fbm(rng, size, size, 4, 4, octaves=4)
    fine = fbm(rng, size, size, 64, 64, octaves=3)
    speck = rng.uniform(0, 1, (size, size))
    tone = tone * (1 + broad * 0.08 + fine * 0.05)
    albedo = base[None, None, :] * tone[..., None]
    albedo *= (1 - (speck > 0.985) * 0.18)[..., None]
    albedo += ((speck < 0.01) * 0.06)[..., None]
    height = np.ones((size, size)) - (speck > 0.985) * 0.25

    # Joints every 4 m (half the tile), with sand packed into them.
    jd = np.minimum(np.minimum(xx % half, half - xx % half), np.minimum(yy % half, half - yy % half))
    joint = smooth(4.0, 1.0, jd)
    lip = smooth(9.0, 4.0, jd) * (1 - joint)
    height -= joint * 0.8 + lip * 0.08
    sand_in = hexc("#c99a62")
    albedo = albedo * (1 - joint[..., None] * 0.75) + sand_in * joint[..., None] * 0.55
    albedo *= (1 - lip * 0.06)[..., None]

    # Oil and scorch stains.
    stain = np.zeros((size, size))
    for _ in range(9):
        cx, cy, r = rng.uniform(0, size), rng.uniform(0, size), rng.uniform(25, 90)
        dx = np.minimum(np.abs(xx - cx), size - np.abs(xx - cx))
        dy = np.minimum(np.abs(yy - cy), size - np.abs(yy - cy))
        dist = np.sqrt(dx * dx * rng.uniform(0.6, 1.4) + dy * dy) / r
        stain = np.maximum(stain, smooth(1.0, 0.0, dist + fine * 0.8) * rng.uniform(0.2, 0.45))
    albedo = albedo * (1 - stain[..., None] * 0.45) + hexc("#5c4a3e") * stain[..., None] * 0.18

    # Hairline cracks: short random walks.
    crack = np.zeros((size, size))
    for _ in range(6):
        x, y = rng.uniform(0, size), rng.uniform(0, size)
        ang = rng.uniform(0, math.tau)
        for _ in range(int(rng.uniform(40, 140))):
            ang += rng.normal(0, 0.35)
            x, y = (x + math.cos(ang) * 2.0) % size, (y + math.sin(ang) * 2.0) % size
            crack[int(y), int(x)] = 1.0
    crack = np.maximum(crack, np.roll(crack, 1, 1) * 0.6)
    albedo *= (1 - crack * 0.18)[..., None]
    height -= crack * 0.3

    save_rgb(albedo, "dune_concrete.png")
    h = height.copy()
    for _ in range(2):
        h = (h + np.roll(h, 1, 0) + np.roll(h, -1, 0) + np.roll(h, 1, 1) + np.roll(h, -1, 1)) / 5.0
    save_rgb(normal_from_height(h, 2.0), "dune_concrete_normal.png")


# ---------------------------------------------------------------------------
# Sand
# ---------------------------------------------------------------------------

def make_sand(size=1024, seed=31):
    """8 m tile of wind ripples with grain sparkle."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:size, 0:size] / size
    warp = fbm(rng, size, size, 3, 3, octaves=3)
    warp2 = fbm(rng, size, size, 6, 6, octaves=3)
    # 22 ripple crests per tile, bent by the warp field (integer frequency keeps it tileable).
    phase = (yy * 22 + warp * 2.2 + xx * 2.0) * math.tau
    ripple = np.sin(phase + np.sin(phase) * 0.6)                       # asymmetric crests
    ripple = ripple * (0.65 + 0.35 * np.clip(warp2 * 2 + 0.5, 0, 1))
    grain = rng.uniform(-1, 1, (size, size))
    dunes = fbm(rng, size, size, 2, 2, octaves=3)
    light = hexc("#efc48c")
    dark = hexc("#c98f58")
    t = np.clip(0.55 + ripple * 0.28 + dunes * 0.25 + grain * 0.05, 0, 1)[..., None]
    albedo = dark + (light - dark) * t
    sparkle = (rng.uniform(0, 1, (size, size)) > 0.996)[..., None] * 0.18
    albedo = albedo + sparkle
    save_rgb(albedo, "dune_sand.png")
    save_rgb(normal_from_height(ripple * 0.5 + grain * 0.03, 1.6), "dune_sand_normal.png")


def make_hazard(w=256, h=64):
    """Diagonal yellow/black hazard stripes, tiling along U (one tile = 1 m of stripe)."""
    yy, xx = np.mgrid[0:h, 0:w]
    phase = ((xx + yy * 0.9) / (w / 4.0)) % 1.0
    yellow, black = hexc("#ffc21f"), hexc("#2b2530")
    stripe = smooth(0.47, 0.53, phase) * (1 - smooth(0.97, 1.0, phase))
    arr = black + (yellow - black) * stripe[..., None]
    wear = np.random.default_rng(4).uniform(0, 1, (h, w)) > 0.97
    arr = arr * (1 - wear[..., None] * 0.25)
    save_rgb(arr, "dune_hazard.png")


def make_noise(size=512, seed=3):
    rng = np.random.default_rng(seed)
    chans = [fbm(rng, size, size, 4, 4, octaves=5), fbm(rng, size, size, 8, 8, octaves=4),
             fbm(rng, size, size, 2, 6, octaves=5)]
    arr = np.stack([np.clip(c * 1.6 + 0.5, 0, 1) for c in chans], axis=-1)
    save_rgb(arr, "dune_noise.png")


if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    wanted = sys.argv[1:] or ["noise", "hazard", "concrete", "sand", "sky"]
    for key in wanted:
        globals()["make_" + key]()
