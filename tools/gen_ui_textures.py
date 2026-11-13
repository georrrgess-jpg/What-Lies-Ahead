"""Generates the materials of the menu/HUD look (no third-party art) into art/ui/:

    painted teal metal with rivets and light wear, cream-trimmed signboards,
    marquee signs and their bulbs, sign-shaped buttons in every state, neon
    plates, cards, keycaps and the icon set (Spark, padlock, ...).

    python3 tools/gen_ui_textures.py            (needs numpy + Pillow)

Everything is drawn 4x supersampled and scaled down, so edges stay crisp. Sizes
are in canvas pixels (the project's 1920x1080 canvas). The 9-slice margins of
each texture live in scripts/ui/kit/kit_tex.gd (KitTex.SPECS); keep both in step.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "ui")
SS = 4

INK = "#120c2e"
PANEL = "#1d1338"
PANEL_DEEP = "#140d2a"
TEAL = "#2b918c"
CREAM = "#f6e7c1"
PINK = "#f43f86"
GOLD = "#f2a23a"
CRIMSON = "#8c2444"


def hexc(h, a=1.0):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] + [a])


def blank(w, h):
    return np.zeros((h * SS, w * SS, 4))


def mask_new(w, h):
    return Image.new("L", (w * SS, h * SS), 0)


def to_arr(mask):
    return np.asarray(mask, dtype=np.float64) / 255.0


def rrect(w, h, box, r):
    """Rounded-rectangle coverage mask. box = (x0, y0, x1, y1) in canvas pixels."""
    m = mask_new(w, h)
    b = [int(round(v * SS)) for v in box]
    ImageDraw.Draw(m).rounded_rectangle([b[0], b[1], b[2] - 1, b[3] - 1], radius=int(round(r * SS)), fill=255)
    return to_arr(m)


def poly(w, h, pts):
    m = mask_new(w, h)
    ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    return to_arr(m)


def circle(w, h, cx, cy, r):
    m = mask_new(w, h)
    ImageDraw.Draw(m).ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS - 1, (cy + r) * SS - 1], fill=255)
    return to_arr(m)


def stroke(w, h, pts, width, closed=False):
    """Round-capped polyline mask."""
    m = mask_new(w, h)
    d = ImageDraw.Draw(m)
    p = [(x * SS, y * SS) for x, y in pts]
    if closed:
        p.append(p[0])
    d.line(p, fill=255, width=int(round(width * SS)), joint="curve")
    r = width * SS / 2.0
    for x, y in p:
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return to_arr(m)


def blur(a, radius):
    if radius <= 0:
        return a
    img = Image.fromarray(np.clip(a * 255.0, 0, 255).astype(np.uint8), "L")
    return to_arr(img.filter(ImageFilter.GaussianBlur(radius * SS)))


def shift(a, dx, dy):
    """`a` moved by (dx, dy) canvas pixels, zero filled."""
    out = np.zeros_like(a)
    sx, sy = int(round(dx * SS)), int(round(dy * SS))
    h, w = a.shape
    xs0, xs1 = max(0, -sx), min(w, w - sx)
    ys0, ys1 = max(0, -sy), min(h, h - sy)
    out[ys0 + sy:ys1 + sy, xs0 + sx:xs1 + sx] = a[ys0:ys1, xs0:xs1]
    return out


def over(dst, color, mask):
    """Alpha-composites a flat or per-pixel `color` (RGBA) through `mask` onto dst."""
    c = np.broadcast_to(color, dst.shape)
    a = (c[..., 3] * mask)[..., None]
    out_a = a + dst[..., 3:4] * (1.0 - a)
    rgb = (c[..., :3] * a + dst[..., :3] * dst[..., 3:4] * (1.0 - a)) / np.maximum(out_a, 1e-6)
    dst[..., :3] = rgb
    dst[..., 3:4] = out_a
    return dst


def lit(mask, base, depth=3.0, hi=0.45, lo=0.5, gloss=0.0):
    """A painted, bevelled surface: `base` colour shaded as if lit from above.
    Returns an RGBA array (alpha 1): the top edge catches light, the bottom
    edge falls into shadow, with an optional soft gloss over the upper half."""
    soft = blur(mask, depth * 0.6)
    light = shift(soft, 0, depth * 0.5) - shift(soft, 0, -depth * 0.5)
    light = np.clip(light * 2.2, -1.0, 1.0)
    rgb = np.broadcast_to(hexc(base)[:3], mask.shape + (3,)).copy()
    up = np.clip(light, 0, 1)[..., None]
    down = np.clip(-light, 0, 1)[..., None]
    rgb = rgb + (1.0 - rgb) * up * hi
    rgb = rgb * (1.0 - down * lo)
    if gloss > 0:
        h = mask.shape[0]
        g = np.clip(1.0 - np.arange(h) / (h * 0.5), 0, 1)[:, None, None]
        rgb = rgb + (1.0 - rgb) * g * gloss
    return np.concatenate([np.clip(rgb, 0, 1), np.ones(mask.shape + (1,))], axis=-1)


def wear_mask(shape, seed, amount=0.5, scale=10):
    """Blotchy chips and fine speckle, 0-1."""
    rng = np.random.default_rng(seed)
    h, w = shape
    small = rng.random((max(2, h // (scale * SS)), max(2, w // (scale * SS))))
    big = np.asarray(Image.fromarray((small * 255).astype(np.uint8), "L").resize((w, h), Image.BICUBIC), dtype=np.float64) / 255.0
    fine = rng.random((h // SS + 1, w // SS + 1))
    fine = np.kron(fine, np.ones((SS, SS)))[:h, :w]
    chips = np.clip((big - (1.0 - amount * 0.45)) * 9.0, 0, 1)
    speck = (fine > 1.0 - amount * 0.035).astype(np.float64)
    return np.clip(chips * (0.5 + 0.5 * fine) + speck * 0.8, 0, 1)


def corner_only(shape, margin):
    """1 inside the four corner squares of side `margin` (canvas px), 0 on the
    parts a 9-slice stretches, so wear never smears."""
    h, w = shape
    m = int(margin * SS)
    out = np.zeros(shape)
    out[:m, :m] = 1
    out[:m, w - m:] = 1
    out[h - m:, :m] = 1
    out[h - m:, w - m:] = 1
    return out


def rivet(dst, w, h, cx, cy, r, color="#d8c9a0"):
    over(dst, hexc("#000000", 0.45), blur(circle(w, h, cx, cy + r * 0.35, r * 1.15), r * 0.3))
    over(dst, hexc(INK, 0.9), circle(w, h, cx, cy, r * 1.08))
    dome = circle(w, h, cx, cy, r * 0.86)
    over(dst, lit(dome, color, depth=r * 0.9, hi=0.7, lo=0.55), dome)
    over(dst, hexc("#ffffff", 0.75), blur(circle(w, h, cx - r * 0.25, cy - r * 0.3, r * 0.22), r * 0.08))


def save(arr, name, w, h):
    os.makedirs(OUT, exist_ok=True)
    img = Image.fromarray((np.clip(arr, 0, 1) * 255.0 + 0.5).astype(np.uint8), "RGBA")
    img = img.resize((w, h), Image.LANCZOS)
    img.save(os.path.join(OUT, name + ".png"))


# --- panels ------------------------------------------------------------------

def metal_frame():
    """Riveted teal frame around a dark recess. 9-slice margin 64, pad 8."""
    w = h = 192
    pad, t = 8, 24
    a = blank(w, h)
    outer = rrect(w, h, (pad, pad, w - pad, h - pad), 20)
    inner = rrect(w, h, (pad + t, pad + t, w - pad - t, h - pad - t), 14)
    over(a, hexc("#000000", 0.5), blur(shift(outer, 0, 5), 5))
    over(a, hexc(INK), rrect(w, h, (pad - 3, pad - 3, w - pad + 3, h - pad + 3), 23))
    frame = np.clip(outer - inner, 0, 1)
    paint = lit(frame, TEAL, depth=5.0, hi=0.5, lo=0.55)
    worn = wear_mask(frame.shape, 11, 0.6) * corner_only(frame.shape, 60)
    paint[..., :3] = paint[..., :3] * (1 - worn[..., None] * 0.55) + hexc("#5b3a44")[:3] * worn[..., None] * 0.3
    over(a, paint, frame)
    # Recess: dark panel with a shadow under the frame's top lip.
    over(a, hexc(PANEL_DEEP, 0.95), inner)
    lip = np.clip(inner - shift(inner, 0, 7), 0, 1)
    over(a, hexc("#000000", 0.5), blur(lip, 2.5) * inner)
    over(a, hexc("#7de0d2", 0.5), np.clip(rrect(w, h, (pad + t - 2, pad + t - 2, w - pad - t + 2, h - pad - t + 2), 15) - inner, 0, 1))
    for cx in (pad + t * 0.5, w - pad - t * 0.5):
        for cy in (pad + t * 0.5, h - pad - t * 0.5):
            rivet(a, w, h, cx, cy, 5.5, "#c7b78d")
    save(a, "metal_frame", w, h)


def metal_plate():
    """Solid teal plate (top bar, small plates). 9-slice margin 40, pad 8."""
    w = h = 128
    pad = 8
    a = blank(w, h)
    body = rrect(w, h, (pad, pad, w - pad, h - pad), 14)
    over(a, hexc("#000000", 0.45), blur(shift(body, 0, 4), 4))
    over(a, hexc(INK), rrect(w, h, (pad - 3, pad - 3, w - pad + 3, h - pad + 3), 17))
    paint = lit(body, "#237a78", depth=5.0, hi=0.45, lo=0.5)
    worn = wear_mask(body.shape, 5, 0.5) * corner_only(body.shape, 38)
    paint[..., :3] = paint[..., :3] * (1 - worn[..., None] * 0.5) + hexc("#5b3a44")[:3] * worn[..., None] * 0.25
    over(a, paint, body)
    for cx in (pad + 12, w - pad - 12):
        for cy in (pad + 12, h - pad - 12):
            rivet(a, w, h, cx, cy, 4.5, "#c7b78d")
    save(a, "metal_plate", w, h)


def signboard():
    """Cream-trimmed signboard on dark aubergine. 9-slice margin 60, pad 10."""
    w = h = 192
    pad, t = 10, 15
    a = blank(w, h)
    outer = rrect(w, h, (pad, pad, w - pad, h - pad), 26)
    inner = rrect(w, h, (pad + t, pad + t, w - pad - t, h - pad - t), 13)
    over(a, hexc("#000000", 0.55), blur(shift(outer, 0, 6), 6))
    over(a, hexc("#1a0f26"), rrect(w, h, (pad - 3, pad - 3, w - pad + 3, h - pad + 3), 29))
    trim = np.clip(outer - inner, 0, 1)
    paint = lit(trim, CREAM, depth=4.0, hi=0.6, lo=0.4)
    worn = wear_mask(trim.shape, 23, 0.45) * corner_only(trim.shape, 56)
    paint[..., :3] = paint[..., :3] * (1 - worn[..., None] * 0.35)
    over(a, paint, trim)
    over(a, hexc("#1a0f26"), np.clip(rrect(w, h, (pad + t - 3, pad + t - 3, w - pad - t + 3, h - pad - t + 3), 15) - inner, 0, 1))
    over(a, hexc(PANEL, 0.97), inner)
    gy = np.linspace(0.10, 0.0, h * SS)[:, None]
    over(a, hexc("#9a6cff", 1.0), inner * gy)
    for cx in (pad + t * 0.5 + 4, w - pad - t * 0.5 - 4):
        for cy in (pad + t * 0.5 + 4, h - pad - t * 0.5 - 4):
            rivet(a, w, h, cx, cy, 5.0, "#9d8a78")
    save(a, "signboard", w, h)


def marquee():
    """Marquee sign body: crimson face in a gold frame the bulbs sit on.
    9-slice margin 56, pad 10; bulbs are drawn by MarqueeSign."""
    w = h = 176
    pad, t = 10, 22
    a = blank(w, h)

    def notched(inset, cut):
        x0, y0, x1, y1 = pad + inset, pad + inset, w - pad - inset, h - pad - inset
        return poly(w, h, [(x0 + cut, y0), (x1 - cut, y0), (x1, y0 + cut), (x1, y1 - cut), (x1 - cut, y1), (x0 + cut, y1), (x0, y1 - cut), (x0, y0 + cut)])

    outer = blur(notched(0, 22), 2.0) > 0.5
    outer = blur(outer.astype(np.float64), 0.5)
    inner = blur((blur(notched(t, 12), 1.5) > 0.5).astype(np.float64), 0.5)
    over(a, hexc("#ff9a3a", 0.55), blur(outer, 7) * 0.9)
    over(a, hexc("#2a0c1c"), blur((blur(notched(-3, 24), 2.0) > 0.5).astype(np.float64), 0.5))
    frame = np.clip(outer - inner, 0, 1)
    over(a, lit(frame, "#e2701f", depth=6.0, hi=0.55, lo=0.5), frame)
    over(a, hexc("#3a0f22"), np.clip(blur((blur(notched(t - 3, 13), 1.5) > 0.5).astype(np.float64), 0.5) - inner, 0, 1))
    face = lit(inner, CRIMSON, depth=6.0, hi=0.25, lo=0.45, gloss=0.10)
    over(a, face, inner)
    save(a, "marquee", w, h)


def neon_plate():
    """Dark plate with a white neon outline (tint with modulate). Margin 36, pad 12."""
    w, h = 128, 96
    pad = 12
    a = blank(w, h)
    body = rrect(w, h, (pad, pad, w - pad, h - pad), 14)
    inner = rrect(w, h, (pad + 4, pad + 4, w - pad - 4, h - pad - 4), 10)
    over(a, hexc("#ffffff", 0.55), blur(body, 5))
    over(a, hexc("#ffffff"), body)
    over(a, hexc("#241a4d"), inner)
    over(a, hexc("#ffffff", 0.22), blur(np.clip(body - inner, 0, 1), 3) * inner)
    save(a, "neon_plate", w, h)


def card(name, fill, border, border_w, glow=None):
    """Item card backing. Margin 28, pad 10."""
    w = h = 96
    pad = 10
    a = blank(w, h)
    body = rrect(w, h, (pad, pad, w - pad, h - pad), 14)
    inner = rrect(w, h, (pad + border_w, pad + border_w, w - pad - border_w, h - pad - border_w), 14 - border_w)
    if glow:
        over(a, hexc(glow, 0.7), blur(body, 5))
    else:
        over(a, hexc("#000000", 0.4), blur(shift(body, 0, 3), 3))
    over(a, hexc(border), body)
    over(a, hexc(fill, 0.96), inner)
    gy = np.linspace(0.16, 0.0, h * SS)[:, None]
    over(a, hexc("#b9a2ff"), inner * gy)
    save(a, name, w, h)


def focus_ring():
    """Cyan focus outline with glow, drawn outside the control. Margin 30, pad 14."""
    w = h = 96
    pad = 14
    a = blank(w, h)
    outer = rrect(w, h, (pad - 5, pad - 5, w - pad + 5, h - pad + 5), 20)
    inner = rrect(w, h, (pad - 1, pad - 1, w - pad + 1, h - pad + 1), 16)
    ring = np.clip(outer - inner, 0, 1)
    over(a, hexc("#35f0ff", 0.6), blur(ring, 4))
    over(a, hexc("#c8fbff"), ring)
    save(a, "focus_ring", w, h)


def shadow():
    """Soft drop shadow. Margin 40."""
    w = h = 96
    a = blank(w, h)
    over(a, hexc("#05020f", 0.75), blur(rrect(w, h, (22, 24, w - 22, h - 20), 14), 9))
    save(a, "shadow", w, h)


# --- buttons -----------------------------------------------------------------

def sign_button(name, base, lip, state):
    """Rounded sign button. Margin (38, 34), pad 10; the lip is 8 px."""
    w, h = 128, 104
    pad, lip_h = 10, 8
    a = blank(w, h)
    drop = 5 if state == "pressed" else 0
    full = rrect(w, h, (pad, pad, w - pad, h - pad), 20)
    face = rrect(w, h, (pad, pad + drop, w - pad, h - pad - lip_h + drop), 20)
    if state == "hover":
        over(a, hexc("#ffffff", 0.5), blur(full, 6))
    else:
        over(a, hexc("#000000", 0.45), blur(shift(full, 0, 4), 4))
    out_box = (pad - 3, pad - 3 + drop, w - pad + 3, h - pad + 3)
    over(a, hexc("#1a0b22"), rrect(w, h, out_box, 23))
    lip_m = rrect(w, h, (pad, pad + 14, w - pad, h - pad), 20)
    over(a, hexc(lip), lip_m)
    bright = {"normal": 0.0, "hover": 0.16, "pressed": -0.12}[state]
    c = hexc(base)
    c[:3] = np.clip(c[:3] + bright if bright > 0 else c[:3] * (1.0 + bright), 0, 1)
    col = "#%02x%02x%02x" % tuple(int(v * 255) for v in c[:3])
    paint = lit(face, col, depth=5.0, hi=0.5, lo=0.3, gloss=0.16)
    worn = wear_mask(face.shape, 31, 0.35) * corner_only(face.shape, 34)
    paint[..., :3] = paint[..., :3] * (1 - worn[..., None] * 0.25)
    over(a, paint, face)
    # Inner cream pin-stripe and a bolt at each end, like a fairground sign.
    s_out = rrect(w, h, (pad + 6, pad + 6 + drop, w - pad - 6, h - pad - lip_h - 6 + drop), 14)
    s_in = rrect(w, h, (pad + 8, pad + 8 + drop, w - pad - 8, h - pad - lip_h - 8 + drop), 12)
    over(a, hexc("#fff3dc", 0.38), np.clip(s_out - s_in, 0, 1))
    save(a, name, w, h)


def sign_arrow(name, base, lip, state):
    """BACK sign: a plate with pointed ends. Margin (44, 30), pad 10."""
    w, h = 144, 92
    pad, lip_h = 10, 7
    a = blank(w, h)
    drop = 4 if state == "pressed" else 0

    def hexagon(x0, y0, x1, y1, tip):
        my = (y0 + y1) * 0.5
        return poly(w, h, [(x0 + tip, y0), (x1 - tip, y0), (x1, my), (x1 - tip, y1), (x0 + tip, y1), (x0, my)])

    def soft(m, r=2.0):
        return blur((blur(m, r) > 0.5).astype(np.float64), 0.5)

    full = soft(hexagon(pad, pad, w - pad, h - pad, 26))
    face = soft(hexagon(pad, pad + drop, w - pad, h - pad - lip_h + drop, 24))
    if state == "hover":
        over(a, hexc("#ffffff", 0.5), blur(full, 6))
    else:
        over(a, hexc("#000000", 0.45), blur(shift(full, 0, 4), 4))
    over(a, hexc("#1a0b22"), soft(hexagon(pad - 4, pad - 3 + drop, w - pad + 4, h - pad + 3, 28)))
    over(a, hexc(lip), soft(hexagon(pad, pad + 10, w - pad, h - pad, 26)))
    bright = {"normal": 0.0, "hover": 0.16, "pressed": -0.12}[state]
    c = hexc(base)
    c[:3] = np.clip(c[:3] + bright if bright > 0 else c[:3] * (1.0 + bright), 0, 1)
    col = "#%02x%02x%02x" % tuple(int(v * 255) for v in c[:3])
    paint = lit(face, col, depth=5.0, hi=0.5, lo=0.3, gloss=0.12)
    worn = wear_mask(face.shape, 47, 0.4) * corner_only(face.shape, 40)
    paint[..., :3] = paint[..., :3] * (1 - worn[..., None] * 0.3)
    over(a, paint, face)
    my = (pad + h - pad - lip_h) * 0.5 + drop
    rivet(a, w, h, pad + 17, my, 4.0, "#c7b78d")
    rivet(a, w, h, w - pad - 17, my, 4.0, "#c7b78d")
    save(a, name, w, h)


def icon_button(name, base, lip, state):
    """Round-cornered square for icon buttons. Margin 30, pad 8."""
    w = h = 88
    pad, lip_h = 8, 6
    a = blank(w, h)
    drop = 4 if state == "pressed" else 0
    full = rrect(w, h, (pad, pad, w - pad, h - pad), 18)
    face = rrect(w, h, (pad, pad + drop, w - pad, h - pad - lip_h + drop), 18)
    if state == "hover":
        over(a, hexc("#ffffff", 0.5), blur(full, 5))
    else:
        over(a, hexc("#000000", 0.4), blur(shift(full, 0, 3), 3))
    over(a, hexc("#1a0b22"), rrect(w, h, (pad - 3, pad - 3 + drop, w - pad + 3, h - pad + 3), 21))
    over(a, hexc(lip), rrect(w, h, (pad, pad + 12, w - pad, h - pad), 18))
    bright = {"normal": 0.0, "hover": 0.16, "pressed": -0.12}[state]
    c = hexc(base)
    c[:3] = np.clip(c[:3] + bright if bright > 0 else c[:3] * (1.0 + bright), 0, 1)
    col = "#%02x%02x%02x" % tuple(int(v * 255) for v in c[:3])
    over(a, lit(face, col, depth=4.0, hi=0.5, lo=0.3, gloss=0.14), face)
    save(a, name, w, h)





def keycap():
    """Keyboard key for prompts. Margin 20."""
    w = h = 64
    a = blank(w, h)
    body = rrect(w, h, (4, 4, w - 4, h - 4), 12)
    top = rrect(w, h, (4, 4, w - 4, h - 11), 12)
    over(a, hexc("#000000", 0.4), blur(shift(body, 0, 2), 2))
    over(a, hexc("#1a0b22"), rrect(w, h, (2, 2, w - 2, h - 2), 14))
    over(a, hexc("#a8946c"), body)
    over(a, lit(top, "#fff3dc", depth=3.0, hi=0.6, lo=0.18), top)
    save(a, "keycap", w, h)


def knob(name, ring):
    """Slider grabber."""
    w = h = 44
    a = blank(w, h)
    over(a, hexc("#000000", 0.45), blur(circle(w, h, 22, 24, 17), 2.5))
    over(a, hexc("#1a0b22"), circle(w, h, 22, 22, 19))
    r = circle(w, h, 22, 22, 17)
    over(a, lit(r, ring, depth=4.0, hi=0.5, lo=0.35), r)
    c = circle(w, h, 22, 22, 10)
    over(a, lit(c, "#fff3dc", depth=4.0, hi=0.6, lo=0.25), c)
    save(a, name, w, h)


def bulbs():
    w = h = 48
    on = blank(w, h)
    over(on, hexc("#ffb23e", 0.75), blur(circle(w, h, 24, 24, 13), 6))
    over(on, hexc("#ffd36a"), circle(w, h, 24, 24, 9.5))
    over(on, hexc("#fff7cf"), blur(circle(w, h, 24, 23, 6.5), 1.2))
    over(on, hexc("#ffffff"), blur(circle(w, h, 22, 21, 2.6), 0.6))
    save(on, "bulb_on", w, h)
    off = blank(w, h)
    over(off, hexc("#2a0c1c", 0.8), circle(w, h, 24, 24, 11))
    d = circle(w, h, 24, 24, 9.5)
    over(off, lit(d, "#b8782e", depth=4.0, hi=0.45, lo=0.5), d)
    over(off, hexc("#ffe2a6", 0.7), blur(circle(w, h, 22, 21, 2.2), 0.6))
    save(off, "bulb_off", w, h)


def rivet_sprite():
    w = h = 24
    a = blank(w, h)
    rivet(a, w, h, 12, 11.5, 6.0, "#c7b78d")
    save(a, "rivet", w, h)


def level_badge():
    """Shield for the player level; the number is drawn by LevelBadge."""
    w = h = 112
    a = blank(w, h)

    def shield(inset):
        x0, y0, x1, y1 = 14 + inset, 10 + inset, w - 14 - inset, h - 10 - inset
        mx = w / 2
        return poly(w, h, [(mx, y0), (x1, y0 + 16), (x1, y0 + 52), (mx, y1), (x0, y0 + 52), (x0, y0 + 16)])

    def soft(m, r=2.5):
        return blur((blur(m, r) > 0.5).astype(np.float64), 0.5)

    outer, inner = soft(shield(0)), soft(shield(9))
    over(a, hexc("#000000", 0.45), blur(shift(outer, 0, 4), 4))
    over(a, hexc("#2a1404"), soft(shield(-3)))
    ring = np.clip(outer - inner, 0, 1)
    over(a, lit(ring, "#ffc24a", depth=5.0, hi=0.6, lo=0.45), ring)
    over(a, lit(inner, "#2b1f66", depth=6.0, hi=0.25, lo=0.4, gloss=0.12), inner)
    save(a, "level_badge", w, h)


# --- icons -------------------------------------------------------------------

def star_pts(cx, cy, r_out, r_in, points, rot=-90.0):
    pts = []
    for i in range(points * 2):
        ang = math.radians(rot + i * 180.0 / points)
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    return pts


def icon_spark():
    """The Spark: a four-point star, gold with a cyan glow."""
    w = h = 96
    a = blank(w, h)
    big = poly(w, h, star_pts(48, 48, 40, 11, 4))
    over(a, hexc("#38f0ff", 0.85), blur(big, 7))
    over(a, hexc("#38f0ff", 0.6), blur(big, 3))
    over(a, hexc("#7a3c00"), blur((blur(poly(w, h, star_pts(48, 48, 43, 13, 4)), 1.2) > 0.4).astype(np.float64), 0.5))
    yy, xx = np.mgrid[0:h * SS, 0:w * SS] / SS
    d = np.hypot(xx - 48, yy - 48) / 40.0
    grad = np.zeros(big.shape + (4,))
    stops = [(0.0, hexc("#fffbe0")), (0.3, hexc("#ffe66b")), (0.7, hexc("#ffc531")), (1.0, hexc("#f08c1a"))]
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        t = np.clip((d - p0) / (p1 - p0), 0, 1)[..., None]
        grad = np.where((d >= p0)[..., None], c0 + (c1 - c0) * t, grad)
    grad[..., 3] = 1.0
    over(a, grad, big)
    # Facet: the lower-right half of every arm sits in shade.
    facet = poly(w, h, [(48, 48), (88, 48), (56, 56), (48, 88), (40, 56)])
    over(a, hexc("#c86a10", 0.35), facet * big)
    over(a, hexc("#ffffff", 0.9), blur(poly(w, h, star_pts(41, 41, 9, 2.5, 4)), 0.5))
    save(a, "icon_spark", w, h)


def icon_lock():
    w = h = 64
    a = blank(w, h)
    shackle = np.clip(stroke(w, h, [(21, 30), (21, 22), (24, 15), (32, 12), (40, 15), (43, 22), (43, 30)], 7.5), 0, 1)
    over(a, hexc("#1a0b22"), np.clip(stroke(w, h, [(21, 30), (21, 22), (24, 15), (32, 12), (40, 15), (43, 22), (43, 30)], 12.5), 0, 1))
    over(a, lit(shackle, "#d9d2c0", depth=3.0, hi=0.6, lo=0.4), shackle)
    over(a, hexc("#1a0b22"), rrect(w, h, (10, 26, 54, 59), 9))
    body = rrect(w, h, (12.5, 28.5, 51.5, 56.5), 7)
    over(a, lit(body, "#ffc24a", depth=4.0, hi=0.55, lo=0.4), body)
    over(a, hexc("#3a1a08"), circle(w, h, 32, 40, 4.5))
    over(a, hexc("#3a1a08"), poly(w, h, [(29.5, 41), (34.5, 41), (35.5, 50), (28.5, 50)]))
    save(a, "icon_lock", w, h)


def white_icon(name, mask):
    a = blank(64, 64)
    over(a, hexc("#ffffff"), np.clip(mask, 0, 1))
    save(a, name, 64, 64)


def icons():
    w = h = 64
    # Gear: toothed ring.
    teeth = np.zeros((h * SS, w * SS))
    for i in range(8):
        ang = math.radians(i * 45.0)
        cx, cy = 32 + math.cos(ang) * 21, 32 + math.sin(ang) * 21
        teeth = np.maximum(teeth, stroke(w, h, [(32 + math.cos(ang) * 14, 32 + math.sin(ang) * 14), (cx, cy)], 10))
    gear = np.maximum(teeth, circle(w, h, 32, 32, 18))
    white_icon("icon_gear", gear - circle(w, h, 32, 32, 8))
    # Power: broken ring with a bar.
    ring = circle(w, h, 32, 34, 22) - circle(w, h, 32, 34, 14.5)
    gap = poly(w, h, [(32, 34), (18, 4), (46, 4)])
    white_icon("icon_power", np.maximum(np.clip(ring - gap, 0, 1), stroke(w, h, [(32, 9), (32, 31)], 8)))
    white_icon("icon_arrow_left", stroke(w, h, [(40, 12), (20, 32), (40, 52)], 11))
    white_icon("icon_arrow_right", stroke(w, h, [(24, 12), (44, 32), (24, 52)], 11))
    white_icon("icon_check", stroke(w, h, [(12, 34), (26, 48), (52, 17)], 10))
    white_icon("icon_close", np.maximum(stroke(w, h, [(16, 16), (48, 48)], 10), stroke(w, h, [(48, 16), (16, 48)], 10)))
    white_icon("icon_play", blur((blur(poly(w, h, [(18, 9), (56, 32), (18, 55)]), 2.5) > 0.5).astype(np.float64), 0.5))
    roof = blur((blur(poly(w, h, [(32, 6), (60, 31), (4, 31)]), 2.0) > 0.5).astype(np.float64), 0.5)
    house = np.maximum(roof, rrect(w, h, (13, 28, 51, 58), 5)) - rrect(w, h, (26, 38, 38, 58), 3)
    white_icon("icon_home", house)
    # Film: a clapperboard.
    board = rrect(w, h, (8, 26, 56, 56), 6)
    top = np.clip(rrect(w, h, (8, 10, 56, 22), 4), 0, 1)
    for x in (16, 30, 44):
        top = top - poly(w, h, [(x, 10), (x + 7, 10), (x + 1, 22), (x - 6, 22)])
    white_icon("icon_film", np.maximum(board - poly(w, h, [(27, 33), (41, 41), (27, 49)]), np.clip(top, 0, 1)))
    # Tutorial: a mortarboard.
    cap = np.maximum(poly(w, h, [(32, 10), (60, 24), (32, 38), (4, 24)]), rrect(w, h, (17, 30, 47, 48), 8))
    cap = np.maximum(cap, stroke(w, h, [(55, 26), (55, 44)], 4.5))
    white_icon("icon_tutorial", cap)
    # Star (gold) and its empty slot.
    for name, col, alpha in (("icon_star", "#ffc24a", 1.0), ("icon_star_empty", "#3a2d6b", 0.9)):
        a = blank(w, h)
        s = blur((blur(poly(w, h, star_pts(32, 34, 27, 12.5, 5)), 1.6) > 0.5).astype(np.float64), 0.5)
        over(a, hexc("#1a0b22", alpha), blur((blur(poly(w, h, star_pts(32, 34, 31, 15, 5)), 1.6) > 0.5).astype(np.float64), 0.5))
        over(a, lit(s, col, depth=4.0, hi=0.6 if alpha == 1.0 else 0.1, lo=0.35), s)
        save(a, name, w, h)
    # Mouse with the left or right button lit.
    for name, side in (("icon_mouse_l", 0), ("icon_mouse_r", 1)):
        a = blank(w, h)
        body = rrect(w, h, (14, 4, 50, 60), 18)
        over(a, hexc("#1a0b22"), rrect(w, h, (11, 1, 53, 63), 21))
        over(a, lit(body, "#fff3dc", depth=4.0, hi=0.5, lo=0.25), body)
        btn = rrect(w, h, (14, 4, 50, 60), 18) * poly(w, h, [(14, 4), (31, 4), (31, 28), (14, 28)] if side == 0 else [(33, 4), (50, 4), (50, 28), (33, 28)])
        over(a, hexc("#ff3fa4"), btn)
        over(a, hexc("#1a0b22"), stroke(w, h, [(32, 5), (32, 28)], 2.5))
        over(a, hexc("#1a0b22"), stroke(w, h, [(15, 28), (49, 28)], 2.5))
        save(a, name, w, h)


def want_mipmaps(import_path):
    """UI textures are drawn smaller than authored when the window is below
    1080p, so they are imported with mipmaps (UiKit.apply() selects the
    mipmapped filter). A texture Godot has not imported yet gets a stub that
    the importer completes."""
    if os.path.exists(import_path):
        text = open(import_path).read()
        if "mipmaps/generate=false" in text:
            open(import_path, "w").write(text.replace("mipmaps/generate=false", "mipmaps/generate=true"))
    else:
        open(import_path, "w").write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\nmipmaps/generate=true\n')


def main():
    metal_frame()
    metal_plate()
    signboard()
    marquee()
    neon_plate()
    card("card", "#1b1338", "#43357a", 2.5)
    card("card_hover", "#2a1d55", "#9c8cf0", 3)
    card("card_selected", "#22194a", "#59f3ff", 4, glow="#35f0ff")
    focus_ring()
    shadow()
    for name, base, lip in (("pink", "#f43f86", "#a11d54"), ("teal", "#1fa6a2", "#0d5f63"), ("gold", "#f5a524", "#a35c0c"), ("purple", "#7a48d0", "#3f2180"), ("grey", "#5a5278", "#35304d")):
        for state in ("normal", "hover", "pressed"):
            if name == "grey" and state != "normal":
                continue
            sign_button("btn_%s_%s" % (name, state), base, lip, state)
    for state in ("normal", "hover", "pressed"):
        sign_arrow("sign_back_%s" % state, "#1f9c98", "#0d5f63", state)
        icon_button("btn_icon_%s" % state, "#3a2a7a", "#1f1548", state)
    keycap()
    knob("knob", "#f43f86")
    knob("knob_hover", "#35f0ff")
    bulbs()
    rivet_sprite()
    level_badge()
    icon_spark()
    icon_lock()
    icons()
    names = [f for f in os.listdir(OUT) if f.endswith(".png")]
    for name in names:
        want_mipmaps(os.path.join(OUT, name + ".import"))
    print("wrote", len(names), "textures to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
