"""Printed stickers: the die-cut outlines and the artwork of the textured decal
emblems (build_cosmetics.py builds their meshes; the game prints the picture
on the sticker's face, see WeaponCosmetics.decal_art_material).

Every design is drawn with Pillow in sticker space: x right and z up, the
picture square spanning -1..1 both ways, the outline (a polygon in the same
space) being the sticker's die-cut edge. Pictures are drawn at 4x and scaled
down, so their edges are smooth.

    ART_STICKERS = {name: (outline, draw)}   draw(canvas) paints the picture
    write_art(out_dir)                        writes <out_dir>/decal_<name>.png
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 256
SCALE = 4
HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.normpath(os.path.join(HERE, "..", "fonts", "LilitaOne-Regular.ttf"))
INK = (28, 24, 48)
WHITE = (255, 255, 255)


# ---------------------------------------------------------------------------
# Outlines (sticker space)
# ---------------------------------------------------------------------------

def circle_pts(r, steps=48, cx=0.0, cz=0.0, a0=0.0, a1=360.0):
    closed = a1 - a0 >= 360
    n = steps if closed else steps + 1
    return [(cx + math.cos(math.radians(a0 + (a1 - a0) * i / steps)) * r, cz + math.sin(math.radians(a0 + (a1 - a0) * i / steps)) * r)
            for i in range(n)]


def rounded_rect(w, h, r, steps=6):
    """Half width / half height w, h, corner radius r (counter-clockwise)."""
    pts = []
    for cx, cz, a0 in ((w - r, -h + r, 270), (w - r, h - r, 0), (-w + r, h - r, 90), (-w + r, -h + r, 180)):
        pts += circle_pts(r, steps, cx, cz, a0, a0 + 90)
    return pts


def radial(fn, steps=72):
    return [(math.cos(math.tau * i / steps) * fn(math.tau * i / steps), math.sin(math.tau * i / steps) * fn(math.tau * i / steps))
            for i in range(steps)]


def burst(points, outer, inner, rot=90.0):
    return [(math.cos(math.radians(rot) + math.pi * i / points) * (outer if i % 2 == 0 else inner),
             math.sin(math.radians(rot) + math.pi * i / points) * (outer if i % 2 == 0 else inner)) for i in range(points * 2)]


# ---------------------------------------------------------------------------
# Canvas
# ---------------------------------------------------------------------------

class Canvas:
    """Draws in sticker space on a SIZE*SCALE square image."""

    def __init__(self):
        self.n = SIZE * SCALE
        self.img = Image.new("RGBA", (self.n, self.n), (0, 0, 0, 255))
        self.d = ImageDraw.Draw(self.img)

    def px(self, x, z):
        return ((x + 1.0) * 0.5 * self.n, (1.0 - z) * 0.5 * self.n)

    def w(self, width):
        return max(1, int(width * 0.5 * self.n))

    def fill(self, colour):
        self.d.rectangle((0, 0, self.n, self.n), fill=colour)

    def poly(self, pts, fill=None, outline=None, width=0.0):
        p = [self.px(x, z) for x, z in pts]
        self.d.polygon(p, fill=fill)
        if outline and width > 0:
            self.d.line(p + [p[0]], fill=outline, width=self.w(width), joint="curve")

    def line(self, pts, colour, width):
        self.d.line([self.px(x, z) for x, z in pts], fill=colour, width=self.w(width), joint="curve")
        r = width * 0.5
        for x, z in (pts[0], pts[-1]):
            self.circle(x, z, r, colour)

    def circle(self, x, z, r, fill=None, outline=None, width=0.0):
        a, b = self.px(x - r, z + r), self.px(x + r, z - r)
        self.d.ellipse((a[0], a[1], b[0], b[1]), fill=fill, outline=outline, width=self.w(width) if outline else 0)

    def ellipse(self, x, z, rx, rz, fill=None, outline=None, width=0.0):
        a, b = self.px(x - rx, z + rz), self.px(x + rx, z - rz)
        self.d.ellipse((a[0], a[1], b[0], b[1]), fill=fill, outline=outline, width=self.w(width) if outline else 0)

    def rect(self, x0, z0, x1, z1, fill=None, outline=None, width=0.0, radius=0.0):
        a, b = self.px(x0, z1), self.px(x1, z0)
        self.d.rounded_rectangle((a[0], a[1], b[0], b[1]), radius=self.w(radius * 2) // 2 if radius else 0, fill=fill,
                                 outline=outline, width=self.w(width) if outline else 0)

    def arc(self, x, z, r, a0, a1, colour, width):
        """Arc from a0 to a1 degrees, counter-clockwise from +x (sticker space)."""
        a, b = self.px(x - r, z + r), self.px(x + r, z - r)
        self.d.arc((a[0], a[1], b[0], b[1]), -a1, -a0, fill=colour, width=self.w(width))

    def text(self, body, x, z, size, fill, stroke=None, stroke_width=0.0, rotate=0.0, shadow=None):
        font = ImageFont.truetype(FONT, int(size * 0.5 * self.n))
        layer = Image.new("RGBA", (self.n, self.n), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        sw = self.w(stroke_width) if stroke else 0
        cx, cz = self.px(x, z)
        if shadow:
            off = self.w(size * 0.06)
            ld.text((cx + off, cz + off), body, font=font, fill=shadow, anchor="mm", stroke_width=sw, stroke_fill=shadow)
        ld.text((cx, cz), body, font=font, fill=fill, anchor="mm", stroke_width=sw, stroke_fill=stroke)
        if rotate:
            layer = layer.rotate(rotate, center=(cx, cz), resample=Image.BICUBIC)
        self.img.alpha_composite(layer)

    def glow(self, draw, radius):
        """Runs draw(canvas) on a layer, blurs a copy under it (neon tubes)."""
        sub = Canvas()
        sub.img = Image.new("RGBA", (self.n, self.n), (0, 0, 0, 0))
        sub.d = ImageDraw.Draw(sub.img)
        draw(sub)
        halo = sub.img.filter(ImageFilter.GaussianBlur(self.w(radius)))
        self.img.alpha_composite(halo)
        self.img.alpha_composite(halo)
        self.img.alpha_composite(sub.img)

    def gradient(self, stops, z0=-1.0, z1=1.0):
        """Vertical gradient between z0 (first stop) and z1 (last)."""
        for row in range(self.n):
            z = 1.0 - 2.0 * row / self.n
            t = min(1.0, max(0.0, (z - z0) / (z1 - z0)))
            k = t * (len(stops) - 1)
            i = min(int(k), len(stops) - 2)
            f = k - i
            c = tuple(int(stops[i][j] + (stops[i + 1][j] - stops[i][j]) * f) for j in range(3))
            self.d.line((0, row, self.n, row), fill=c)

    def dots(self, colour, spacing, r, clip=None):
        k = int(2.0 / spacing) + 2
        for i in range(k):
            for j in range(k):
                x = -1.0 + i * spacing + (spacing * 0.5 if j % 2 else 0.0)
                z = -1.0 + j * spacing
                if clip is None or clip(x, z):
                    self.circle(x, z, r, colour)

    def finish(self, outline):
        """Inks the die-cut edge and scales the picture down."""
        self.poly(outline, outline=INK, width=0.05)
        return self.img.resize((SIZE, SIZE), Image.LANCZOS)


# ---------------------------------------------------------------------------
# Pictures
# ---------------------------------------------------------------------------

def star_pts(x, z, r, inner=0.45, points=5, rot=90.0):
    return [(x + px, z + pz) for px, pz in burst(points, r, r * inner, rot)]


def heart_pts(x, z, s, steps=32):
    pts = []
    for i in range(steps):
        t = math.tau * i / steps
        hx = 16 * math.sin(t) ** 3
        hz = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x + hx / 17.0 * s, z + hz / 17.0 * s))
    return pts


def ribbon(c, z, half_w, h, colour, text, text_size, text_colour=WHITE):
    tail = [(-half_w - 0.16, z - h * 0.6), (-half_w + 0.02, z - h * 0.6), (-half_w + 0.02, z + h * 0.4), (-half_w - 0.16, z + h * 0.4),
            (-half_w - 0.08, z - h * 0.1)]
    c.poly(tail, fill=tuple(int(v * 0.7) for v in colour), outline=INK, width=0.025)
    c.poly([(-x, zz) for x, zz in tail], fill=tuple(int(v * 0.7) for v in colour), outline=INK, width=0.025)
    c.rect(-half_w, z - h * 0.5, half_w, z + h * 0.5, fill=colour, outline=INK, width=0.03)
    c.text(text, 0, z + h * 0.02, text_size, text_colour, stroke=INK, stroke_width=0.025)


def draw_pier_pass(c):
    c.gradient([(255, 214, 92), (255, 132, 70), (255, 70, 150), (122, 58, 196)], -0.15, 1.0)
    c.circle(0.0, -0.05, 0.42, (255, 236, 130))
    c.rect(-1, -1, 1, -0.15, fill=(18, 160, 150))
    for i in range(4):
        z = -0.3 - i * 0.12
        c.line([(-0.7 + i * 0.1, z), (-0.2 + i * 0.1, z)], (120, 230, 210), 0.025)
        c.line([(0.25 - i * 0.05, z - 0.05), (0.7 - i * 0.05, z - 0.05)], (120, 230, 210), 0.025)
    dark = (60, 28, 96)
    hub = (0.0, 0.18)
    c.line([hub, (-0.38, -0.45)], dark, 0.07)
    c.line([hub, (0.38, -0.45)], dark, 0.07)
    c.rect(-0.55, -0.52, 0.55, -0.42, fill=dark)
    c.circle(hub[0], hub[1], 0.5, outline=dark, width=0.06)
    c.circle(hub[0], hub[1], 0.36, outline=dark, width=0.025)
    for i in range(10):
        a = math.tau * i / 10
        c.line([hub, (hub[0] + math.cos(a) * 0.5, hub[1] + math.sin(a) * 0.5)], dark, 0.02)
        colour = [(255, 79, 176), (63, 244, 255), (255, 217, 59)][i % 3]
        c.circle(hub[0] + math.cos(a) * 0.5, hub[1] + math.sin(a) * 0.5 - 0.07, 0.07, fill=colour, outline=dark, width=0.02)
    c.circle(hub[0], hub[1], 0.07, fill=(255, 217, 59), outline=dark, width=0.02)
    ribbon(c, -0.66, 0.62, 0.3, (232, 38, 58), "PRIZE PIER", 0.2)


def draw_skyline_tag(c):
    c.fill((44, 22, 78))
    c.dots((90, 50, 140), 0.16, 0.025)
    for x, z, r, col in ((-0.6, 0.5, 0.18, (255, 79, 176)), (0.65, -0.55, 0.2, (63, 244, 255)), (0.55, 0.62, 0.1, (255, 217, 59))):
        c.circle(x, z, r, fill=col + (255,))
    # Crown doodle over the tag.
    c.poly([(-0.32, 0.42), (-0.36, 0.7), (-0.18, 0.55), (0.0, 0.76), (0.18, 0.55), (0.36, 0.7), (0.32, 0.42)], fill=(255, 217, 59),
           outline=INK, width=0.035)
    for x in (-0.36, 0.0, 0.36):
        c.circle(x, 0.72 + (0.04 if x == 0 else 0), 0.05, fill=(255, 217, 59), outline=INK, width=0.02)
    for x, length in ((-0.42, 0.28), (-0.1, 0.42), (0.2, 0.22), (0.48, 0.34)):
        c.line([(x, -0.2), (x, -0.2 - length)], (63, 244, 255), 0.07)
    c.text("ZAP!", 0.0, 0.0, 0.78, (255, 79, 176), stroke=(63, 244, 255), stroke_width=0.06, rotate=8, shadow=INK)


def draw_deep_diver(c):
    c.gradient([(10, 40, 110), (20, 110, 190), (70, 200, 230)], -0.8, 0.8)
    for i, (x, z, r) in enumerate(((-0.45, 0.35, 0.06), (-0.38, 0.55, 0.04), (-0.5, 0.65, 0.03), (0.5, 0.45, 0.05), (0.42, 0.62, 0.035))):
        c.circle(x, z, r, outline=(210, 245, 255), width=0.02)
    for k in range(5):
        x = -0.6 + k * 0.3
        pts = [(x + math.sin(j * 0.9 + k) * 0.06, -0.85 + j * 0.09) for j in range(5 + k % 2)]
        c.line(pts, (40, 180, 90), 0.07)
    c.poly([(-0.9, -1), (-0.9, -0.62), (-0.5, -0.7), (0.0, -0.6), (0.5, -0.72), (0.9, -0.6), (0.9, -1)], fill=(240, 205, 140))
    # The fish.
    body = [(0.32 + math.cos(t) * 0.36, 0.0 + math.sin(t) * 0.24) for t in [math.tau * i / 30 for i in range(30)]]
    c.poly([(0.62, 0.0), (0.9, 0.22), (0.86, -0.22)], fill=(255, 120, 40), outline=INK, width=0.03)
    c.poly(body, fill=(255, 150, 50), outline=INK, width=0.035)
    c.poly([(0.2, 0.2), (0.38, 0.38), (0.48, 0.18)], fill=(255, 120, 40), outline=INK, width=0.03)
    for x in (0.28, 0.42):
        c.line([(x, 0.2), (x, -0.2)], WHITE, 0.05)
    c.circle(0.08, 0.05, 0.08, fill=WHITE, outline=INK, width=0.02)
    c.circle(0.06, 0.05, 0.04, fill=INK)
    c.arc(0.06, -0.08, 0.06, 200, 320, INK, 0.025)
    # Brass porthole ring and bolts.
    c.circle(0, 0, 0.93, outline=(214, 160, 52), width=0.2)
    c.circle(0, 0, 0.83, outline=(255, 210, 100), width=0.03)
    for i in range(8):
        a = math.tau * i / 8 + math.pi / 8
        c.circle(math.cos(a) * 0.9, math.sin(a) * 0.9, 0.055, fill=(160, 110, 40), outline=INK, width=0.015)


def draw_mission_patch(c):
    c.fill((24, 30, 86))
    for i in range(40):
        x = math.sin(i * 12.9898) * 0.9
        z = math.sin(i * 78.233) * 0.7
        c.circle(x, z, 0.012 + (i % 3) * 0.008, (255, 255, 230))
    c.circle(-0.5, -0.32, 0.36, fill=(255, 140, 60), outline=INK, width=0.03)
    c.arc(-0.5, -0.32, 0.28, 120, 200, (255, 190, 120), 0.05)
    c.ellipse(-0.5, -0.32, 0.6, 0.12, outline=(255, 217, 59), width=0.05)
    # Rocket climbing to the upper right.
    rocket = Canvas()
    rocket.img = Image.new("RGBA", (c.n, c.n), (0, 0, 0, 0))
    rocket.d = ImageDraw.Draw(rocket.img)
    rocket.poly([(0.0, -0.55), (0.12, -0.75), (0.0, -0.95), (-0.12, -0.75)], fill=(255, 200, 60))
    rocket.poly([(-0.18, -0.45), (0.18, -0.45), (0.18, 0.25), (0.0, 0.62), (-0.18, 0.25)], fill=WHITE, outline=INK, width=0.035)
    rocket.poly([(-0.18, 0.25), (0.18, 0.25), (0.0, 0.62)], fill=(232, 38, 58), outline=INK, width=0.035)
    rocket.circle(0.0, 0.05, 0.09, fill=(63, 200, 255), outline=INK, width=0.03)
    for side in (-1, 1):
        rocket.poly([(side * 0.18, -0.15), (side * 0.36, -0.5), (side * 0.18, -0.45)], fill=(232, 38, 58), outline=INK, width=0.03)
    rocket.img = rocket.img.rotate(-35, center=rocket.px(0, 0), resample=Image.BICUBIC, translate=(int(c.n * 0.08), -int(c.n * 0.04)))
    c.img.alpha_composite(rocket.img)
    c.ellipse(0, 0, 0.93, 0.93 * 0.78, outline=(255, 217, 59), width=0.07)
    c.text("LAUNCH PAD", 0.05, -0.56, 0.2, WHITE, stroke=INK, stroke_width=0.025)


def draw_summit_pennant(c):
    c.fill((30, 150, 140))
    for i in range(14):
        c.circle(-0.85 + (i * 0.37) % 1.2, 0.62 - (i * 0.23) % 0.3, 0.022, WHITE)
    c.poly([(-0.92, -0.05), (-0.58, 0.48), (-0.42, 0.26), (-0.18, 0.56), (0.25, -0.05)], fill=(90, 110, 170), outline=INK, width=0.03)
    c.poly([(-0.68, 0.32), (-0.58, 0.48), (-0.5, 0.36), (-0.55, 0.32), (-0.6, 0.37), (-0.64, 0.3)], fill=WHITE)
    c.poly([(-0.3, 0.38), (-0.18, 0.56), (-0.05, 0.36), (-0.12, 0.31), (-0.18, 0.38), (-0.25, 0.3)], fill=WHITE)
    for x, s_ in ((-0.8, 0.2), (-0.64, 0.15), (0.08, 0.18)):
        c.poly([(x, -0.05 + s_ * 1.4), (x - s_ * 0.5, -0.05), (x + s_ * 0.5, -0.05)], fill=(20, 90, 60), outline=INK, width=0.02)
    c.rect(-1, -1, 1, -0.05, fill=(240, 248, 255))
    c.text("SUMMIT", -0.3, -0.27, 0.26, (232, 38, 58), stroke=INK, stroke_width=0.02)
    c.rect(-1.0, -1.0, -0.88, 1.0, fill=(150, 90, 50))


def draw_zombie_buddy(c):
    c.fill((122, 214, 92))
    c.dots((108, 196, 80), 0.22, 0.04)
    c.poly([(-0.45, 0.82), (-0.3, 1.0), (-0.18, 0.78), (0.0, 1.0), (0.12, 0.8)], fill=(60, 40, 90), outline=INK, width=0.02)
    # Mismatched eyes.
    c.circle(-0.34, 0.2, 0.3, fill=WHITE, outline=INK, width=0.04)
    c.circle(-0.28, 0.16, 0.1, fill=INK)
    c.circle(-0.31, 0.2, 0.03, fill=WHITE)
    c.circle(0.36, 0.22, 0.2, fill=(255, 245, 200), outline=INK, width=0.04)
    c.circle(0.4, 0.2, 0.06, fill=(232, 38, 58))
    # Stitched scar.
    c.line([(0.12, 0.62), (0.62, 0.48)], INK, 0.04)
    for i in range(4):
        x = 0.18 + i * 0.13
        z = 0.6 - i * 0.036
        c.line([(x - 0.02, z + 0.08), (x + 0.02, z - 0.08)], INK, 0.03)
    # Plaster on the cheek.
    c.poly([(-0.72, -0.18), (-0.48, -0.06), (-0.4, -0.22), (-0.64, -0.34)], fill=(255, 190, 200), outline=INK, width=0.025)
    # Smile with a tooth and a drip of drool.
    c.arc(0.0, -0.18, 0.38, 200, 340, INK, 0.06)
    c.rect(-0.08, -0.53, 0.06, -0.4, fill=WHITE, outline=INK, width=0.02)
    c.ellipse(0.26, -0.54, 0.05, 0.08, fill=(170, 230, 255), outline=INK, width=0.015)


def draw_popcorn_pal(c):
    c.fill((255, 245, 225))
    for i in range(-5, 6):
        x0 = i * 0.18
        c.poly([(x0 - 0.045, 0.25), (x0 + 0.045, 0.25), (x0 * 0.82 + 0.037, -1.0), (x0 * 0.82 - 0.037, -1.0)], fill=(232, 38, 58))
    for i, (x, z, r) in enumerate(((-0.55, 0.45, 0.22), (-0.2, 0.62, 0.26), (0.2, 0.6, 0.25), (0.55, 0.45, 0.22), (0.0, 0.85, 0.18),
                                   (-0.42, 0.78, 0.16), (0.42, 0.8, 0.16))):
        c.circle(x, z, r, fill=(255, 248, 220) if i % 3 else (255, 222, 120), outline=INK, width=0.03)
    c.rect(-0.62, 0.12, 0.62, 0.3, fill=(255, 217, 59), outline=INK, width=0.03)
    c.ellipse(-0.25, -0.18, 0.11, 0.14, fill=WHITE, outline=INK, width=0.03)
    c.ellipse(0.25, -0.18, 0.11, 0.14, fill=WHITE, outline=INK, width=0.03)
    c.circle(-0.22, -0.2, 0.05, fill=INK)
    c.circle(0.28, -0.2, 0.05, fill=INK)
    c.arc(0.0, -0.36, 0.22, 200, 340, INK, 0.05)
    c.ellipse(-0.45, -0.36, 0.08, 0.05, fill=(255, 140, 170))
    c.ellipse(0.45, -0.36, 0.08, 0.05, fill=(255, 140, 170))


def draw_neon_kitty(c):
    c.fill((30, 20, 52))
    c.dots((48, 34, 80), 0.12, 0.018)

    def tubes(t):
        pink = (255, 90, 190)
        cyan = (90, 245, 255)
        head = [(math.cos(a) * 0.62, -0.08 + math.sin(a) * 0.5) for a in [math.tau * i / 40 for i in range(41)]]
        t.line(head, pink, 0.07)
        t.line([(-0.52, 0.18), (-0.5, 0.75), (-0.18, 0.4)], pink, 0.07)
        t.line([(0.52, 0.18), (0.5, 0.75), (0.18, 0.4)], pink, 0.07)
        for side in (-1, 1):
            t.line([(side * 0.32, 0.02), (side * 0.18, 0.08)], cyan, 0.06)
            t.line([(side * 0.3, -0.2), (side * 0.85, -0.12)], cyan, 0.035)
            t.line([(side * 0.3, -0.28), (side * 0.85, -0.34)], cyan, 0.035)
        t.poly([(-0.07, -0.12), (0.07, -0.12), (0.0, -0.2)], fill=pink)
        t.line([(0.0, -0.2), (-0.1, -0.3), (-0.18, -0.25)], pink, 0.04)
        t.line([(0.0, -0.2), (0.1, -0.3), (0.18, -0.25)], pink, 0.04)

    c.glow(tubes, 0.06)
    c.text("OPEN 24/7", 0.0, -0.78, 0.17, (255, 217, 59), stroke=INK, stroke_width=0.015)


def draw_extra_life(c):
    c.fill((24, 30, 90))
    for i in range(-10, 11):
        c.line([(i * 0.1, -1), (i * 0.1, 1)], (34, 42, 110), 0.01)
        c.line([(-1, i * 0.1), (1, i * 0.1)], (34, 42, 110), 0.01)
    rows = ["..XX...XX..", ".XXXX.XXXX.", "XXWXXXXXXXX", "XWXXXXXXXXX", "XXXXXXXXXXX", ".XXXXXXXXX.", "..XXXXXXX..", "...XXXXX...",
            "....XXX....", ".....X....."]
    cell = 0.1
    for r, row in enumerate(rows):
        for k, ch in enumerate(row):
            if ch == ".":
                continue
            x = -0.55 + k * cell
            z = 0.78 - r * cell
            colour = WHITE if ch == "W" else (255, 40, 80)
            c.rect(x, z - cell, x + cell, z, fill=colour, outline=INK, width=0.012)
    c.text("1UP", 0.0, -0.62, 0.44, (120, 255, 120), stroke=INK, stroke_width=0.04)


def draw_hi_score(c):
    c.fill((150, 60, 200))
    c.rect(-0.86, -0.56, 0.86, 0.56, fill=(14, 10, 26), outline=(255, 217, 59), width=0.05, radius=0.08)
    c.text("HI-SCORE", 0.0, 0.26, 0.3, (255, 217, 59), stroke=(255, 90, 40), stroke_width=0.012)
    c.text("999990", 0.0, -0.18, 0.42, (255, 60, 90), stroke=(120, 10, 40), stroke_width=0.012)
    for x in (-0.78, 0.78):
        for z in (-0.68, 0.68):
            c.circle(x, z, 0.05, fill=(255, 217, 59), outline=INK, width=0.015)
    for i in range(7):
        c.circle(-0.6 + i * 0.2, -0.43, 0.025, fill=(63, 244, 255) if i % 2 else (255, 79, 176))


def draw_pow(c):
    c.fill((255, 217, 59))
    c.dots((255, 170, 40), 0.12, 0.035)
    c.poly(burst(10, 0.8, 0.5, 80), fill=(232, 38, 58), outline=INK, width=0.04)
    c.poly(burst(10, 0.55, 0.38, 98), fill=(255, 120, 40))
    c.text("POW!", 0.0, 0.02, 0.62, WHITE, stroke=INK, stroke_width=0.05, rotate=-10)


def draw_lucky_sevens(c):
    c.fill((120, 40, 180))
    c.rect(-0.94, -0.62, 0.94, 0.5, fill=(255, 194, 61), outline=INK, width=0.04, radius=0.1)
    for i in range(3):
        x = -0.6 + i * 0.6
        c.rect(x - 0.26, -0.5, x + 0.26, 0.38, fill=WHITE, outline=INK, width=0.03, radius=0.04)
        c.rect(x - 0.26, 0.24, x + 0.26, 0.38, fill=(225, 225, 240))
        c.rect(x - 0.26, -0.5, x + 0.26, -0.36, fill=(225, 225, 240))
        c.text("7", x, -0.06, 0.62, (232, 38, 58), stroke=INK, stroke_width=0.03)
    c.line([(-0.92, -0.06), (0.92, -0.06)], (255, 79, 176), 0.02)
    c.rect(-0.62, 0.52, 0.62, 0.86, fill=(232, 38, 58), outline=INK, width=0.03, radius=0.08)
    c.text("JACKPOT", 0.0, 0.69, 0.24, (255, 217, 59), stroke=INK, stroke_width=0.02)
    for i in range(8):
        c.circle(-0.8 + i * 0.228, -0.8, 0.05, fill=(255, 240, 150) if i % 2 else (255, 140, 60), outline=INK, width=0.012)


def draw_cherry_bomb(c):
    c.fill((255, 228, 236))
    c.dots((255, 190, 210), 0.2, 0.05)
    c.line([(-0.32, -0.12), (-0.05, 0.42), (0.1, 0.55)], (60, 140, 50), 0.07)
    c.line([(0.38, -0.08), (0.1, 0.42), (0.1, 0.55)], (60, 140, 50), 0.07)
    c.poly([(0.1, 0.55), (0.42, 0.75), (0.68, 0.62), (0.36, 0.5)], fill=(90, 190, 70), outline=INK, width=0.03)
    for x, z in ((-0.36, -0.36), (0.4, -0.32)):
        c.circle(x, z, 0.36, fill=(220, 20, 50), outline=INK, width=0.04)
        c.ellipse(x - 0.14, z + 0.14, 0.08, 0.05, fill=(255, 150, 160))
    # Lit fuse spark on top of the stems.
    c.poly(star_pts(0.1, 0.68, 0.2, 0.4, 6), fill=(255, 217, 59), outline=(255, 120, 40), width=0.02)
    c.circle(0.1, 0.68, 0.06, fill=WHITE)
    c.arc(-0.36, -0.42, 0.14, 210, 330, INK, 0.035)
    c.circle(-0.46, -0.3, 0.035, INK)
    c.circle(-0.26, -0.3, 0.035, INK)
    c.arc(0.4, -0.38, 0.14, 210, 330, INK, 0.035)
    c.circle(0.3, -0.26, 0.035, INK)
    c.circle(0.5, -0.26, 0.035, INK)


def draw_rocket_pop(c):
    c.fill((63, 120, 230))
    c.rect(-1, 0.25, 1, 1, fill=(232, 38, 58))
    c.rect(-1, -0.18, 1, 0.25, fill=WHITE)
    c.rect(-1, -0.85, 1, -0.18, fill=(63, 120, 230))
    c.rect(-0.12, -1.0, 0.12, -0.62, fill=(222, 170, 110))
    for z in (0.62, -0.5):
        c.ellipse(-0.4, z, 0.05, 0.16, fill=WHITE)
    # A happy face on the white stripe.
    c.circle(-0.18, 0.06, 0.05, fill=INK)
    c.circle(0.18, 0.06, 0.05, fill=INK)
    c.arc(0.0, 0.02, 0.12, 200, 340, INK, 0.035)
    c.ellipse(-0.3, -0.02, 0.06, 0.035, fill=(255, 150, 170))
    c.ellipse(0.3, -0.02, 0.06, 0.035, fill=(255, 150, 170))


def draw_bite_hazard(c):
    c.fill((255, 210, 40))
    c.poly([(0, 0.82), (0.82, 0), (0, -0.82), (-0.82, 0)], outline=INK, width=0.07)
    # A wide-open zombie mouth full of teeth.
    rx, rz, cz = 0.4, 0.26, 0.08
    c.ellipse(0, cz, rx, rz, fill=(120, 14, 40))
    c.ellipse(0, cz - 0.1, 0.18, 0.08, fill=(232, 80, 110))
    for i in range(5):
        x = -0.28 + i * 0.14
        top = cz + rz * math.sqrt(max(0.0, 1.0 - (x / rx) ** 2))
        bottom = cz - rz * math.sqrt(max(0.0, 1.0 - (x / rx) ** 2))
        c.poly([(x - 0.065, top + 0.02), (x + 0.065, top + 0.02), (x, top - 0.13)], fill=WHITE, outline=INK, width=0.015)
        if 0 < i < 4:
            c.poly([(x - 0.06, bottom - 0.02), (x + 0.06, bottom - 0.02), (x, bottom + 0.11)], fill=WHITE, outline=INK, width=0.015)
    c.ellipse(0, cz, rx, rz, outline=INK, width=0.05)
    c.text("BITES!", 0.0, -0.42, 0.19, INK)


def draw_champion(c):
    c.gradient([(255, 170, 40), (255, 226, 120), (255, 190, 60)], -1.0, 1.0)
    c.circle(0, 0, 0.8, outline=(200, 120, 20), width=0.04)
    for i in range(24):
        a = math.tau * i / 24
        c.line([(math.cos(a) * 0.55, math.sin(a) * 0.55), (math.cos(a) * 0.72, math.sin(a) * 0.72)], (255, 245, 200), 0.03)
    c.poly(star_pts(0, 0.1, 0.48, 0.45), fill=(255, 245, 190), outline=INK, width=0.04)
    c.poly(star_pts(0, 0.1, 0.28, 0.45), fill=(255, 200, 60))
    ribbon(c, -0.5, 0.56, 0.3, (232, 38, 58), "CHAMP", 0.26)


def outline_popcorn():
    """A bucket with a bumpy heap of popcorn on top."""
    bumps = ((0.55, 0.45, 0.32), (0.2, 0.62, 0.36), (-0.2, 0.62, 0.36), (-0.55, 0.45, 0.32), (0.0, 0.85, 0.2))
    pts = [(-0.66, -0.98), (0.66, -0.98), (0.84, 0.25)]
    for i in range(29):
        x = 0.84 - 1.68 * i / 28
        z = 0.25
        for bx, bz, r in bumps:
            if abs(x - bx) < r:
                z = max(z, bz + math.sqrt(r * r - (x - bx) ** 2))
        pts.append((x, z))
    pts.append((-0.84, 0.25))
    return pts


def outline_pennant():
    return [(-1.0, -0.8), (1.0, -0.06), (1.0, 0.06), (-1.0, 0.8)]


def outline_rocket_pop():
    """An ice pop on its stick, with a bite out of the top."""
    def pop(deg):
        return (math.cos(math.radians(deg)) * 0.6, 0.4 + math.sin(math.radians(deg)) * 0.6)

    bite = (math.cos(math.radians(46)) * 0.66, 0.4 + math.sin(math.radians(46)) * 0.66)
    start, end = pop(30), pop(62)
    r = math.dist(start, bite)
    a0 = math.degrees(math.atan2(start[1] - bite[1], start[0] - bite[0])) % 360
    a1 = math.degrees(math.atan2(end[1] - bite[1], end[0] - bite[0])) % 360
    pts = [(-0.12, -1.0), (0.12, -1.0), (0.12, -0.85), (0.6, -0.85)]
    pts += [pop(a) for a in range(0, 30, 6)]
    pts += [(bite[0] + math.cos(math.radians(a0 + (a1 - a0) * k / 8)) * r, bite[1] + math.sin(math.radians(a0 + (a1 - a0) * k / 8)) * r)
            for k in range(9)]
    pts += [pop(a) for a in range(66, 181, 6)]
    pts += [(-0.6, -0.85), (-0.12, -0.85)]
    return pts

ART_STICKERS = {
    "PierPass": (circle_pts(1.0, 56), draw_pier_pass),
    "SkylineTag": (radial(lambda a: 0.86 + 0.09 * math.sin(5 * a + 0.4) + 0.05 * math.sin(11 * a)), draw_skyline_tag),
    "DeepDiver": (circle_pts(1.0, 56), draw_deep_diver),
    "MissionPatch": ([(math.cos(math.tau * i / 56), math.sin(math.tau * i / 56) * 0.78) for i in range(56)], draw_mission_patch),
    "SummitPennant": (outline_pennant(), draw_summit_pennant),
    "ZombieBuddy": (rounded_rect(0.9, 0.86, 0.42), draw_zombie_buddy),
    "PopcornPal": (outline_popcorn(), draw_popcorn_pal),
    "NeonKitty": (rounded_rect(0.98, 0.9, 0.22), draw_neon_kitty),
    "ExtraLife": (rounded_rect(0.8, 0.98, 0.16), draw_extra_life),
    "HiScore": (rounded_rect(0.98, 0.76, 0.2), draw_hi_score),
    "Pow": (burst(12, 1.0, 0.72, 90), draw_pow),
    "LuckySevens": (rounded_rect(0.98, 0.94, 0.16), draw_lucky_sevens),
    "CherryBomb": (circle_pts(0.98, 56), draw_cherry_bomb),
    "RocketPop": (outline_rocket_pop(), draw_rocket_pop),
    "BiteHazard": ([(0.0, 1.0), (1.0, 0.0), (0.0, -1.0), (-1.0, 0.0)], draw_bite_hazard),
    "Champion": (radial(lambda a: 0.92 + 0.07 * math.cos(16 * a), 96), draw_champion),
}


def write_art(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for name, (outline, draw) in ART_STICKERS.items():
        c = Canvas()
        draw(c)
        img = c.finish(outline)
        img.convert("RGB").save(os.path.join(out_dir, "decal_%s.png" % name.lower()), optimize=True)
