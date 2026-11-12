"""Generates the textures for World 2 "Neon Rooftops" (no third-party art):

    art/textures/neon_sky_night.png     equirectangular night sky: big moon, stars,
                                        moonlit clouds, city glow, far skyline
    art/textures/neon_roof.png          tileable rooftop pavers (albedo), 4 m per tile
    art/textures/neon_roof_normal.png   matching normal map
    art/textures/neon_puddles.png       tileable puddle mask (white = standing water)
    art/textures/neon_ads.png           advert atlas: 8 adverts (rows) x 4 frames

    python tools/gen_textures_neon.py      (needs numpy + Pillow)

Panorama convention (Godot): image centre = +Z (south in Neon Skyline),
u = atan2(x, z) / 2pi + 0.5, v = acos(y) / pi.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "art", "textures")
FONT_DISPLAY = os.path.join(HERE, "..", "art", "fonts", "LilitaOne-Regular.ttf")
FONT_BODY = os.path.join(HERE, "..", "art", "fonts", "Baloo2-Variable.ttf")


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def ramp(x, stops):
    out = np.zeros(x.shape + (3,))
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        t = np.clip((x - p0) / (p1 - p0), 0.0, 1.0)[..., None]
        out = np.where((x >= p0)[..., None], c0 + (c1 - c0) * t, out)
    return np.where((x < stops[0][0])[..., None], stops[0][1], out)


def tile_noise(rng, h, w, cells_y, cells_x, wrap_y=True):
    """Bilinear value noise on an (h, w) grid, tileable in x (and y if wrap_y)."""
    grid = rng.uniform(0, 1, (cells_y + 1, cells_x))
    if wrap_y:
        grid[-1] = grid[0]
    y = np.linspace(0, cells_y, h, endpoint=not wrap_y)
    x = np.arange(w) / w * cells_x
    y0 = np.floor(y).astype(int).clip(0, cells_y - 1)
    x0 = np.floor(x).astype(int)
    ty = (y - y0)[:, None]
    tx = (x - x0)[None, :]
    ty, tx = ty * ty * (3 - 2 * ty), tx * tx * (3 - 2 * tx)
    x1 = (x0 + 1) % cells_x
    a, b = grid[y0][:, x0], grid[y0][:, x1]
    c, d = grid[y0 + 1][:, x0], grid[y0 + 1][:, x1]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def fbm(rng, h, w, base_y, base_x, octaves=5, wrap_y=True):
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        out += tile_noise(rng, h, w, base_y * 2 ** o, base_x * 2 ** o, wrap_y) * amp
        total += amp
        amp *= 0.5
    return out / total


def save(arr, name, mode="RGB"):
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), mode)
    img.save(os.path.join(OUT, name), optimize=True)
    print(name, img.size)


# ---------------------------------------------------------------------------
# Night sky
# ---------------------------------------------------------------------------

MOON_DIR = (-0.36, -0.93)       # world xz the moon sits toward (north-north-west)
MOON_EL = 27.0                  # degrees
MOON_RADIUS = 4.2               # degrees (stylised, big)


def make_sky(width=4096, height=2048, seed=23):
    rng = np.random.default_rng(seed)
    u = (np.arange(width) + 0.5) / width
    v = (np.arange(height) + 0.5) / height
    phi = (u - 0.5) * 2 * math.pi                    # atan2(x, z)
    el = 90.0 - v * 180.0
    PHI, EL = np.meshgrid(phi, el)
    dx = np.sin(PHI) * np.cos(np.radians(EL))
    dz = np.cos(PHI) * np.cos(np.radians(EL))
    dy = np.sin(np.radians(EL))

    m_phi = math.atan2(MOON_DIR[0], MOON_DIR[1])
    mx = math.sin(m_phi) * math.cos(math.radians(MOON_EL))
    mz = math.cos(m_phi) * math.cos(math.radians(MOON_EL))
    my = math.sin(math.radians(MOON_EL))
    moon_dist = np.degrees(np.arccos(np.clip(dx * mx + dy * my + dz * mz, -1, 1)))

    sky = ramp(EL, [
        (-90, hexc("#07051a")), (-8, hexc("#140b2c")), (-1.0, hexc("#4a1f5e")),
        (0.0, hexc("#8a3a8c")), (2.5, hexc("#6a2f86")), (7, hexc("#3e2477")), (15, hexc("#251c62")),
        (30, hexc("#161650")), (55, hexc("#0d1040")), (90, hexc("#080a2e")),
    ])
    # City glow: warmer magenta toward the south and east (downtown), cooler north.
    downtown = 0.5 + 0.5 * np.cos(PHI - 0.9)
    glow = smooth(18, 0, EL) * smooth(-6, 0.5, EL)
    sky += (hexc("#b03a8c") * downtown[..., None] + hexc("#3a3aa8") * (1 - downtown[..., None])) * (glow * 0.35)[..., None]
    # Moonlight brightens the sky around the moon.
    halo = np.exp(-(moon_dist / 22.0) ** 1.4)[..., None]
    sky += hexc("#5a6ac8") * halo * 0.35
    sky += hexc("#c8c8ff") * np.exp(-(moon_dist / 7.5) ** 2)[..., None] * 0.25

    # Stars (fewer near the horizon and around the moon).
    star = np.zeros((height, width))
    n = 5200
    sy = rng.integers(0, int(height * 0.47), n)
    sx = rng.integers(0, width, n)
    bright = rng.uniform(0.15, 1.0, n) ** 3
    star[sy, sx] = bright
    big = np.zeros((height, width))
    for _ in range(140):
        y, x = int(rng.integers(20, int(height * 0.42))), int(rng.integers(0, width))
        r = rng.uniform(1.2, 2.4)
        yy, xx = np.ogrid[-4:5, -4:5]
        blob = np.exp(-(yy ** 2 + xx ** 2) / (r * r * 0.5)) * rng.uniform(0.5, 1.0)
        ys, xs = slice(max(0, y - 4), y + 5), (np.arange(x - 4, x + 5) % width)
        big[ys, xs] = np.maximum(big[ys, xs], blob[: big[ys, xs].shape[0]])
    stars = np.clip(star + big, 0, 1) * smooth(4, 22, EL) * smooth(8, 20, moon_dist)
    tint = np.where((np.arange(width)[None, :] * 7 + np.arange(height)[:, None] * 3) % 5 == 0, 1, 0)[..., None]
    sky += stars[..., None] * (hexc("#e8eeff") * (1 - tint) + hexc("#ffd8f0") * tint)

    # Clouds: long stretched bands, violet bodies lifted by moonlight near the
    # moon and lit magenta from below by the city near the horizon.
    n1 = fbm(rng, height, width, 30, 22, 6, wrap_y=False)
    n2 = fbm(rng, height, width, 60, 90, 4, wrap_y=False)
    density = n1 * 0.8 + n2 * 0.2
    band = smooth(2, 9, EL) * smooth(52, 24, EL)
    cover = smooth(0.5, 0.64, density) * band
    lit = smooth(0.4, 0.8, n2)
    near_moon = np.exp(-(moon_dist / 30.0) ** 2)[..., None]
    up = smooth(3, 28, EL)[..., None]
    base = hexc("#5c2a86") * (1 - up) + hexc("#2c2a74") * up
    base = base * (0.85 + 0.3 * downtown[..., None] * (1 - up))
    cloud = base * (0.8 + 0.5 * lit[..., None]) + hexc("#a8a4f0") * near_moon * (0.25 + 0.6 * lit[..., None])
    # Silver lining near the moon.
    rim = smooth(0.5, 0.55, density) * (1 - smooth(0.55, 0.62, density)) * band
    cloud += hexc("#e0e2ff") * (rim * np.exp(-(moon_dist / 16.0) ** 2) * 1.4)[..., None]
    a = (cover * 0.8)[..., None]
    sky = sky * (1 - a) + cloud * a

    # The moon: soft-edged disc, limb darkening, a few maria, after the clouds
    # so it reads clearly (thin cloud wisps cross it).
    disc = smooth(MOON_RADIUS + 0.12, MOON_RADIUS - 0.12, moon_dist)
    limb = np.clip(1 - (moon_dist / MOON_RADIUS) ** 2, 0, 1) ** 0.25
    maria = fbm(rng, height, width, 220, 900, 3, wrap_y=False)
    face = hexc("#f4f0ff") * (0.8 + 0.2 * limb)[..., None] * (1 - 0.12 * smooth(0.48, 0.6, maria))[..., None]
    wisp = (cover * 0.35)[..., None]
    moon_col = face * (1 - wisp) + cloud * wisp
    sky = sky * (1 - disc[..., None]) + moon_col * disc[..., None]
    sky += hexc("#b8b8ff") * (np.exp(-((moon_dist - MOON_RADIUS) / 1.6) ** 2) * (1 - disc) * 0.35)[..., None]

    # Far skyline silhouette on the horizon: hazy, with lit windows and beacons.
    sil = np.zeros(width)
    x = 0
    while x < width:
        w = int(rng.integers(10, 60))
        hgt = 0.5 + rng.uniform(0, 1) ** 2.2 * 4.5
        if rng.uniform() < 0.06:
            hgt += rng.uniform(2.0, 4.0)
            w = int(w * 0.5) + 6
        sil[x:x + w] = np.maximum(sil[x:x + w], hgt)
        x += int(w * rng.uniform(0.4, 1.0))
    sil_mask = (EL < sil[None, :]) & (EL > -6)
    win = rng.uniform(0, 1, (height, width)) > 0.975
    building = hexc("#1a1238") * (1 - smooth(-2, 4, EL)[..., None]) + hexc("#2e1f5a") * smooth(-2, 4, EL)[..., None]
    lights = win[..., None] * (hexc("#ffc890") * 0.55)
    sky = np.where(sil_mask[..., None], building + lights * smooth(-4, 0.5, EL)[..., None], sky)
    for x in range(0, width, 2):
        if sil[x] > 3.2 and rng.uniform() < 0.04:
            y = int((90 - sil[x] - 0.12) / 180 * height)
            sky[max(0, y - 1):y + 2, x:x + 2] = hexc("#ff3050") * 1.2
    # A soft haze line where the city meets the sky.
    sky += hexc("#a0408c") * (np.exp(-(EL / 1.6) ** 2) * 0.25)[..., None]
    save(np.clip(sky, 0, 1), "neon_sky_night.png")


# ---------------------------------------------------------------------------
# Rooftop pavers + normal map + puddle mask
# ---------------------------------------------------------------------------

def make_roof(size=1024, per_tile=4, seed=7):
    rng = np.random.default_rng(seed)
    cell = size // per_tile
    alb = np.zeros((size, size, 3))
    height = np.ones((size, size))
    palette = [hexc(c) for c in ("#3c3f52", "#36394b", "#414458", "#33364a", "#3e4054", "#393b4e")]
    yy, xx = np.mgrid[0:size, 0:size]
    for j in range(per_tile):
        for i in range(per_tile):
            base = palette[rng.integers(len(palette))] * rng.uniform(0.9, 1.08)
            alb[j * cell:(j + 1) * cell, i * cell:(i + 1) * cell] = base
    speck = fbm(rng, size, size, 32, 32, 4) - 0.5
    blotch = fbm(rng, size, size, 4, 4, 4) - 0.5
    alb *= (1.0 + speck * 0.35 + blotch * 0.3)[..., None]
    # Grout lines and a bevel toward each joint.
    fx = (xx % cell) / cell
    fy = (yy % cell) / cell
    edge = np.minimum(np.minimum(fx, 1 - fx), np.minimum(fy, 1 - fy)) * cell
    grout = edge < 4
    height = np.clip(edge / 10.0, 0.0, 1.0) * 0.6 + 0.4
    height[grout] = 0.0
    alb[grout] = hexc("#17161f")
    # Tar seams and stains.
    stain = fbm(rng, size, size, 8, 8, 5)
    alb *= (1 - smooth(0.62, 0.75, stain) * 0.35)[..., None]
    for _ in range(6):
        y = int(rng.integers(0, size))
        thick = int(rng.integers(5, 10))
        alb[y:y + thick, :] = alb[y:y + thick, :] * 0.4 + hexc("#121118") * 0.6
        height[y:y + thick, :] = np.minimum(height[y:y + thick, :], 0.3)
    alb = alb * (0.75 + 0.25 * height[..., None])
    save(alb, "neon_roof.png")
    h = height.astype(np.float64)
    for _ in range(2):
        h = (h + np.roll(h, 1, 0) + np.roll(h, -1, 0) + np.roll(h, 1, 1) + np.roll(h, -1, 1)) / 5.0
    h += speck * 0.15
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 2.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 2.5
    n = np.stack([-dx, -dy, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    save(n * 0.5 + 0.5, "neon_roof_normal.png")


def make_puddles(size=512, seed=3):
    rng = np.random.default_rng(seed)
    n = fbm(rng, size, size, 3, 3, 5) * 0.8 + fbm(rng, size, size, 9, 9, 3) * 0.2
    n = (n - n.min()) / (n.max() - n.min())
    save(np.repeat(n[..., None], 3, axis=2), "neon_puddles.png")


# ---------------------------------------------------------------------------
# Advert atlas (rows = adverts, columns = frames)
# ---------------------------------------------------------------------------

CW, CH = 512, 256


def font(size, body=False):
    return ImageFont.truetype(FONT_BODY if body else FONT_DISPLAY, size)


def gradient(c0, c1, vertical=True):
    t = np.linspace(0, 1, CH if vertical else CW)
    a = np.array(c0) / 255.0
    b = np.array(c1) / 255.0
    g = a[None, :] * (1 - t[:, None]) + b[None, :] * t[:, None]
    if vertical:
        arr = np.repeat(g[:, None, :], CW, axis=1)
    else:
        arr = np.repeat(g[None, :, :], CH, axis=0)
    return Image.fromarray((arr * 255).astype(np.uint8), "RGB")


def glow_layer(draw_fn, radius=10, strength=2):
    """Draw with draw_fn onto a black layer; return (sharp, blurred) layers."""
    layer = Image.new("RGB", (CW, CH), (0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    blur = layer.filter(ImageFilter.GaussianBlur(radius))
    for _ in range(strength - 1):
        blur = Image.blend(blur, layer.filter(ImageFilter.GaussianBlur(radius * 2)), 0.5)
    return layer, blur


def add(base, layer, k=1.0):
    a = np.asarray(base).astype(np.float64) + np.asarray(layer).astype(np.float64) * k
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")


def neon(base, draw_fn, radius=10, k_glow=1.3):
    sharp, blur = glow_layer(draw_fn, radius)
    return add(add(base, blur, k_glow), sharp, 1.0)


def centred(d, text, f, y, fill, x=None, stroke=0, stroke_fill=None):
    box = d.textbbox((0, 0), text, font=f, stroke_width=stroke)
    while box[2] - box[0] > CW - 44 and f.size > 20:
        f = f.font_variant(size=f.size - 4)
        box = d.textbbox((0, 0), text, font=f, stroke_width=stroke)
    w = box[2] - box[0]
    d.text(((CW - w) / 2 - box[0] if x is None else x, y - box[1]), text, font=f, fill=fill,
           stroke_width=stroke, stroke_fill=stroke_fill)


def ad_cola(frame):
    img = gradient((40, 0, 30), (120, 0, 60))
    if frame == 0:
        return neon(img, lambda d: centred(d, "ZAP COLA", font(120), 60, (255, 60, 90), stroke=3, stroke_fill=(255, 220, 230)))
    if frame == 1:
        def can(d):
            d.rounded_rectangle((200, 30, 312, 230), 26, outline=(80, 240, 255), width=8)
            d.line((205, 90, 307, 90), fill=(255, 60, 120), width=10)
            d.polygon([(260, 110), (232, 160), (258, 160), (244, 205), (284, 145), (258, 145), (274, 110)], fill=(255, 240, 90))
        return neon(img, can, 12)
    if frame == 2:
        return neon(img, lambda d: (centred(d, "GET", font(70), 30, (90, 240, 255)),
                                    centred(d, "ZAPPED!", font(120), 100, (255, 230, 90))))
    return neon(img, lambda d: (centred(d, "2X FIZZ", font(110), 40, (255, 60, 120)),
                                centred(d, "ZERO REGRETS", font(46, True), 180, (200, 240, 255))))


def ad_noodle(frame):
    img = gradient((10, 10, 40), (30, 10, 70))
    if frame == 0:
        return neon(img, lambda d: (centred(d, "KAIJU", font(110), 20, (255, 160, 40)),
                                    centred(d, "NOODLE BAR", font(64), 150, (90, 255, 210))))
    if frame == 1:
        def bowl(d):
            d.chord((150, 40, 362, 250), 0, 180, outline=(255, 90, 160), width=9)
            d.line((150, 145, 362, 145), fill=(255, 90, 160), width=9)
            for i in range(3):
                x = 210 + i * 45
                d.arc((x - 18, 40, x + 18, 100), 90, 270, fill=(200, 230, 255), width=6)
                d.arc((x - 18, 0, x + 18, 60), 270, 90, fill=(200, 230, 255), width=6)
            d.line((300, 20, 250, 150), fill=(255, 210, 90), width=8)
            d.line((330, 25, 270, 150), fill=(255, 210, 90), width=8)
        return neon(img, bowl, 12)
    if frame == 2:
        return neon(img, lambda d: (centred(d, "OPEN", font(120), 30, (255, 80, 160)),
                                    centred(d, "ALL NIGHT", font(70), 150, (255, 200, 60))))
    return neon(img, lambda d: (centred(d, "SLURP", font(130), 30, (90, 255, 210)),
                                centred(d, "THE MONSTER BOWL", font(40, True), 190, (255, 200, 230))))


def ad_arcade(frame):
    img = gradient((5, 0, 25), (40, 0, 60))
    def invader(d, cx, cy, s, col, shift):
        rows = ["0011100", "0111110", "1101011", "1111111", "0101010", "1000001" if shift else "0100010"]
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch == "1":
                    x, y = cx + (i - 3.5) * s, cy + (j - 3) * s
                    d.rectangle((x, y, x + s - 2, y + s - 2), fill=col)
    if frame in (0, 2):
        return neon(img, lambda d: (centred(d, "HYPER", font(110), 15, (60, 255, 120)),
                                    centred(d, "ARCADE", font(110), 125, (255, 70, 200))))
    if frame == 1:
        return neon(img, lambda d: (invader(d, 130, 128, 22, (60, 255, 120), False),
                                    invader(d, 256, 128, 22, (255, 220, 60), True),
                                    invader(d, 382, 128, 22, (255, 70, 200), False)), 8)
    return neon(img, lambda d: (centred(d, "INSERT COIN", font(84), 50, (255, 230, 80)),
                                centred(d, "1UP  2UP  HI-SCORE", font(40, True), 170, (120, 220, 255))))


def ad_drive(frame):
    img = gradient((20, 0, 50), (255, 70, 120))
    def sun_grid(d):
        for k in range(6):
            y = 70 + k * 16
            d.rectangle((176, y, 336, y + 9 - k), fill=(255, 200, 60))
        for x in range(-400, 900, 60):
            d.line((256, 180, x, 256), fill=(90, 230, 255), width=3)
        for k, y in enumerate((190, 205, 225, 250)):
            d.line((0, y, CW, y), fill=(90, 230, 255), width=3)
    if frame == 0:
        return neon(img, sun_grid, 8)
    if frame == 1:
        return neon(img, lambda d: (sun_grid(d), centred(d, "NEON DRIVE", font(96), 20, (255, 255, 255))), 8)
    if frame == 2:
        return neon(img, lambda d: centred(d, "RIDE THE GRID", font(84), 80, (90, 230, 255)))
    return neon(img, lambda d: (centred(d, "0 - 300", font(110), 20, (255, 240, 120)),
                                centred(d, "IN 2.1 SECONDS", font(52, True), 170, (255, 255, 255))))


def ad_radio(frame):
    img = gradient((0, 10, 30), (10, 30, 70))
    def bars(d, seed):
        r = np.random.default_rng(seed)
        for i in range(16):
            h = int(r.uniform(20, 150))
            x = 40 + i * 28
            col = (255, 60, 200) if i % 3 == 0 else (80, 230, 255)
            d.rectangle((x, 230 - h, x + 18, 230), fill=col)
    if frame == 0:
        return neon(img, lambda d: (centred(d, "SYNTH FM", font(110), 25, (80, 230, 255)),
                                    centred(d, "88.8", font(80), 145, (255, 70, 200))))
    if frame in (1, 2):
        return neon(img, lambda d: bars(d, frame), 8)
    return neon(img, lambda d: centred(d, "NONSTOP NIGHT", font(80), 80, (255, 230, 90)))


def ad_cat(frame):
    img = gradient((30, 0, 40), (10, 0, 30))
    def cat(d):
        d.ellipse((176, 50, 336, 210), outline=(255, 210, 60), width=9)
        d.polygon([(186, 90), (196, 20), (240, 58)], outline=(255, 210, 60), fill=None)
        d.line([(186, 90), (196, 20), (240, 58)], fill=(255, 210, 60), width=9)
        d.line([(326, 90), (316, 20), (272, 58)], fill=(255, 210, 60), width=9)
        d.arc((210, 100, 246, 136), 200, 340, fill=(80, 255, 220), width=8)
        d.arc((266, 100, 302, 136), 200, 340, fill=(80, 255, 220), width=8)
        d.line((140, 150, 210, 160), fill=(255, 120, 200), width=5)
        d.line((372, 150, 302, 160), fill=(255, 120, 200), width=5)
    if frame == 0:
        return neon(img, cat, 12)
    if frame == 1:
        return neon(img, lambda d: (centred(d, "MOON CAT", font(110), 30, (255, 210, 60)),
                                    centred(d, "LUCKY NIGHTS", font(56), 160, (80, 255, 220))))
    if frame == 2:
        return neon(img, lambda d: (cat(d),), 12)
    return neon(img, lambda d: centred(d, "JACKPOT x7", font(110), 60, (255, 90, 190)))


def ad_ticker(frame):
    img = gradient((10, 0, 10), (25, 0, 20))
    msgs = ["STAY INSIDE", "CURFEW 03:00", "ROOF CLOSED", "KEEP DOORS SHUT"]
    return neon(img, lambda d: centred(d, msgs[frame], font(96), 70, (255, 80, 60)), 8)


def ad_sushi(frame):
    img = gradient((0, 20, 30), (0, 50, 60))
    def roll(d):
        for i in range(3):
            cx = 140 + i * 116
            d.ellipse((cx - 46, 80, cx + 46, 172), outline=(255, 255, 255), width=8)
            d.ellipse((cx - 22, 104, cx + 22, 148), fill=(255, 90, 120))
    if frame == 0:
        return neon(img, lambda d: (centred(d, "CYBER", font(100), 20, (90, 255, 220)),
                                    centred(d, "SUSHI", font(110), 125, (255, 90, 160))))
    if frame == 1:
        return neon(img, roll, 10)
    if frame == 2:
        return neon(img, lambda d: (centred(d, "VR DREAMS", font(100), 40, (200, 120, 255)),
                                    centred(d, "WAKE UP LATER", font(48, True), 170, (255, 255, 255))))
    return neon(img, lambda d: centred(d, "24/7", font(150), 40, (255, 230, 90)))


ADS = [ad_cola, ad_noodle, ad_arcade, ad_drive, ad_radio, ad_cat, ad_ticker, ad_sushi]


def make_ads():
    atlas = Image.new("RGB", (CW * 4, CH * len(ADS)), (0, 0, 0))
    for row, fn in enumerate(ADS):
        for frame in range(4):
            cell = fn(frame)
            # A thin bright frame so screens read as LED panels.
            d = ImageDraw.Draw(cell)
            d.rectangle((0, 0, CW - 1, CH - 1), outline=(40, 30, 70), width=6)
            atlas.paste(cell, (frame * CW, row * CH))
    atlas.save(os.path.join(OUT, "neon_ads.png"), optimize=True)
    print("neon_ads.png", atlas.size)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_sky()
    make_roof()
    make_puddles()
    make_ads()
