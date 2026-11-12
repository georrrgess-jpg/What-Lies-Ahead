"""Sea life for the Abyss Aquarium tanks.

    aqua_fish.glb      FishClown, FishTang, FishAngel, FishPuffer, FishSnapper,
                       FishSardine, Shark, Ray: each one mesh facing -Y
                       (Godot +Z), centred on its body, for the aqua_swim shader
    aqua_jelly.glb     Jelly: bell above the origin, tentacles below
    aqua_kelp.glb      KelpTall, KelpShort, SeaGrass: base at the origin
    aqua_reef_a.glb    rock outcrop with branching coral and a sea fan
    aqua_reef_b.glb    brain coral, tube sponges and anemones on a rock
    aqua_rocks.glb     low rock pile with starfish and urchins

The swimming, swaying and pulsing are done by shaders in the level
(art/shaders/aqua_swim.gdshader, aqua_kelp.gdshader, aqua_jelly.gdshader).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aqua_common import *  # noqa: F401,F403


def ellipsoid(name, a, loc, m, segs=12, rings=8):
    """Ellipsoid with semi-axes a = (x, y, z)."""
    return sphere(name, 1.0, loc, scale=a, m=m, segs=segs, rings=rings)


def band(name, a, y0, m, thick=0.03, grow=1.05):
    """Thin ring around an ellipsoid body at y0 (a stripe)."""
    k = math.sqrt(max(0.0, 1.0 - (y0 / a[1]) ** 2))
    return sphere(name, 1.0, (0, y0, 0), scale=(a[0] * k * grow, thick, a[2] * k * grow), m=m, segs=12, rings=6)


def fin(name, outline, depth, loc, m, rot=(0, 0, 0)):
    return prism(name, outline, depth, loc, rot=rot, m=m, bevel=0.0)


def eyes(prefix, x, y, z, r, white, dark):
    out = []
    for s in (-1, 1):
        out.append(sphere(f"{prefix}Eye{s}", r, (s * x, y, z), m=white, segs=8, rings=5))
        out.append(sphere(f"{prefix}Pupil{s}", r * 0.55, (s * (x + r * 0.5), y - r * 0.2, z), m=dark, segs=6, rings=4))
    return out


def side_fin(name, length, height, loc, m):
    """Tail/side fin standing in the YZ plane (thin along X)."""
    return fin(name, [(0.0, 0.0), (length, height), (length * 0.75, 0.0), (length, -height)], 0.02, loc, m, rot=rad(0, 0, 90))


def tail(name, a_y, size, m):
    # Vertical tail fin behind the body (+Y), thin along X.
    outline = [(0.0, 0.0), (size, size * 0.9), (size * 0.7, 0.0), (size, -size * 0.9)]
    ob = prism(name, outline, 0.02, (0, 0, 0), m=m, bevel=0.0)
    ob.rotation_euler = rad(0, 0, 90)
    ob.location = (0, a_y * 0.85, 0)
    return ob


def build_fish():
    reset_scene()
    white, dark = amat("FishWhite", "White", rough=0.4), amat("FishDark", "Dark", rough=0.4)
    out = []

    # Clownfish: orange with three white bands.
    o, wb = amat("ClownOrange", "#ff7a1f", rough=0.45), amat("ClownWhite", "#ffffff", rough=0.45)
    a = (0.045, 0.11, 0.06)
    p = [ellipsoid("C_Body", a, (0, 0, 0), o), tail("C_Tail", a[1], 0.06, o)]
    p += [band(f"C_Band{i}", a, y, wb, 0.012) for i, y in enumerate((-0.06, 0.0, 0.06))]
    p += [fin("C_Dorsal", [(-0.05, 0.0), (0.04, 0.0), (0.0, 0.035)], 0.012, (0, 0.0, 0.055), o, rot=rad(0, 0, 90))]
    p += eyes("C_", 0.028, -0.075, 0.02, 0.012, white, dark)
    out.append(merge("FishClown", p))

    # Blue tang: tall blue body, yellow tail, dark swoosh.
    b, y, bd = amat("TangBlue", "#2f6bff", rough=0.4), amat("TangYellow", "#ffd23a", rough=0.45), amat("TangDark", "#10204f", rough=0.5)
    a = (0.04, 0.14, 0.1)
    p = [ellipsoid("T_Body", a, (0, 0, 0), b), tail("T_Tail", a[1], 0.08, y),
         sphere("T_Swoosh", 1.0, (0, 0.02, 0.02), scale=(0.042, 0.09, 0.04), m=bd, segs=10, rings=6)]
    p += eyes("T_", 0.025, -0.1, 0.03, 0.014, white, dark)
    out.append(merge("FishTang", p))

    # Angelfish: tall striped disc with long fins.
    ya, st = amat("AngelYellow", "#ffe14a", rough=0.45), amat("AngelStripe", "#1b1b30", rough=0.5)
    a = (0.025, 0.11, 0.12)
    p = [ellipsoid("A_Body", a, (0, 0, 0), ya), tail("A_Tail", a[1], 0.07, ya)]
    p += [band(f"A_Stripe{i}", a, yy, st, 0.01) for i, yy in enumerate((-0.04, 0.03))]
    p += [fin("A_Top", [(-0.05, 0.0), (0.08, 0.0), (0.1, 0.13)], 0.012, (0, 0.0, 0.1), ya, rot=rad(0, 0, 90)),
          fin("A_Bot", [(-0.05, 0.0), (0.08, 0.0), (0.1, -0.13)], 0.012, (0, 0.0, -0.1), ya, rot=rad(0, 0, 90))]
    p += eyes("A_", 0.016, -0.08, 0.03, 0.013, white, dark)
    out.append(merge("FishAngel", p))

    # Pufferfish: round, spotted.
    pf, sp = amat("PufferBody", "#f5c542", rough=0.5), amat("PufferSpot", "#7a5520", rough=0.5)
    p = [sphere("P_Body", 0.1, (0, 0, 0), scale=(1, 1.15, 0.95), m=pf, segs=14, rings=9), tail("P_Tail", 0.11, 0.05, pf),
         sphere("P_Belly", 0.09, (0, -0.01, -0.03), scale=(0.95, 1.05, 0.8), m=white, segs=12, rings=7)]
    r = rng(3)
    for i in range(10):
        th, ph = r.uniform(0, math.tau), r.uniform(0.3, 1.4)
        p.append(sphere(f"P_Spot{i}", 0.012, (math.cos(th) * math.sin(ph) * 0.1, math.sin(th) * math.sin(ph) * 0.115, math.cos(ph) * 0.095),
                        m=sp, segs=5, rings=3))
    p += eyes("P_", 0.05, -0.08, 0.04, 0.02, white, dark)
    out.append(merge("FishPuffer", p))

    # Snapper: long coral-pink body with a yellow stripe.
    sn, sy = amat("SnapperPink", "#ff5f6f", rough=0.45), amat("SnapperStripe", "#ffd84a", rough=0.45)
    a = (0.05, 0.22, 0.08)
    p = [ellipsoid("S_Body", a, (0, 0, 0), sn), tail("S_Tail", a[1], 0.1, sn),
         sphere("S_Stripe", 1.0, (0, 0, 0.0), scale=(a[0] * 1.03, a[1] * 0.85, 0.012), m=sy, segs=12, rings=6),
         fin("S_Dorsal", [(-0.1, 0.0), (0.12, 0.0), (0.06, 0.05)], 0.012, (0, 0.0, 0.07), sn, rot=rad(0, 0, 90))]
    p += eyes("S_", 0.03, -0.16, 0.025, 0.014, white, dark)
    out.append(merge("FishSnapper", p))

    # Sardine: tiny silver-blue schooling fish (low poly).
    sv, sb = amat("SardineSilver", "#d6e6f5", rough=0.25, metal=0.4), amat("SardineBack", "#2d6fae", rough=0.35)
    a = (0.018, 0.08, 0.022)
    p = [ellipsoid("D_Body", a, (0, 0, 0), sv, segs=8, rings=5),
         sphere("D_Back", 1.0, (0, 0.0, 0.008), scale=(a[0] * 0.9, a[1] * 0.95, a[2] * 0.7), m=sb, segs=8, rings=5),
         tail("D_Tail", a[1], 0.03, sb)]
    out.append(merge("FishSardine", p))

    # Shark: grey back, white belly, big fins, about 2.6 m long.
    g, gw = amat("SharkGrey", "#6f86a8", rough=0.45), amat("SharkBelly", "#eef3f8", rough=0.45)
    gd = amat("SharkDark", "#3b4c68", rough=0.5)
    a = (0.32, 1.3, 0.36)
    p = [ellipsoid("K_Body", a, (0, 0, 0.0), g, segs=18, rings=10),
         sphere("K_Belly", 1.0, (0, -0.05, -0.1), scale=(a[0] * 0.92, a[1] * 0.92, a[2] * 0.75), m=gw, segs=16, rings=9),
         sphere("K_Snout", 0.2, (0, -1.2, -0.02), scale=(1.0, 1.4, 0.7), m=g, segs=10, rings=6),
         fin("K_Dorsal", [(-0.3, 0.0), (0.25, 0.0), (0.2, 0.55)], 0.06, (0, 0.05, 0.3), g, rot=rad(0, 0, 90)),
         fin("K_Tail", [(0.0, 0.0), (0.35, 0.75), (0.25, 0.0), (0.3, -0.42)], 0.05, (0, 1.2, 0.05), g, rot=rad(0, 0, 90)),
         fin("K_Pec", [(-0.15, 0.0), (0.2, 0.0), (0.35, -0.08)], 0.05, (0, -0.15, -0.2), g, rot=rad(0, 0, 0)),
         box("K_Mouth", (0.3, 0.03, 0.02), (0, -1.0, -0.22), bevel=0.0, m=gd)]
    # Pectoral fins: flat wings either side.
    for s in (-1, 1):
        w = fin(f"K_Wing{s}", [(0.0, 0.0), (0.55, 0.25), (0.15, 0.25)], 0.04, (s * 0.25, -0.25, -0.18), g, rot=rad(90, 0, 0 if s > 0 else 180))
        p.append(w)
        for k in range(3):
            p.append(box(f"K_Gill{s}{k}", (0.01, 0.02, 0.14), (s * 0.31, -0.62 + k * 0.08, 0.0), bevel=0.0, m=gd))
    p += eyes("K_", 0.2, -0.85, 0.1, 0.045, amat("SharkEye", "#202433", rough=0.2), dark)
    out.append(merge("Shark", p))

    # Manta ray: flat diamond, dark top, white underside, long tail.
    rt, rb = amat("RayTop", "#2b3a5c", rough=0.5), amat("RayBelly", "#e8eef5", rough=0.5)
    outline = [(0.0, -0.55), (0.85, 0.05), (0.2, 0.35), (0.0, 0.42), (-0.2, 0.35), (-0.85, 0.05)]
    top = prism("R_Top", outline, 0.08, (0, 0, 0.02), rot=rad(90, 0, 0), m=rt, bevel=0.03)
    bot = prism("R_Bot", [(x * 0.95, y * 0.95) for x, y in outline], 0.04, (0, 0, -0.03), rot=rad(90, 0, 0), m=rb, bevel=0.02)
    p = [top, bot, sphere("R_Hump", 0.22, (0, 0.0, 0.04), scale=(1.0, 1.3, 0.4), m=rt, segs=12, rings=6),
         tube("R_Tail", [(0, 0.4, 0.0), (0, 0.9, 0.02), (0, 1.3, 0.05)], 0.025, m=rt, segs=5, radius_end=0.005)]
    for s in (-1, 1):
        p.append(box(f"R_Horn{s}", (0.06, 0.16, 0.04), (s * 0.13, -0.6, 0.02), bevel=0.02, m=rt))
    out.append(merge("Ray", p))
    save("aqua_fish", out)


def build_jelly():
    reset_scene()
    bell_m = amat("JellyBell", "#ff8ad8", rough=0.3)
    arm_m = amat("JellyArm", "#ffc2ec", rough=0.3)
    parts = [sphere("Bell", 0.25, (0, 0, 0.0), scale=(1.0, 1.0, 0.75), m=bell_m, segs=16, rings=8)]
    # Cut the bottom of the bell flat-ish by squashing the lower verts.
    for v in parts[0].data.vertices:
        if v.co.z < 0:
            v.co.z *= 0.25
    for i in range(12):
        a = math.tau * i / 12
        parts.append(sphere(f"Scallop{i}", 0.05, (math.cos(a) * 0.24, math.sin(a) * 0.24, -0.02), scale=(1, 1, 0.5), m=bell_m, segs=6, rings=4))
    for i in range(4):
        a = math.tau * i / 4 + 0.4
        pts = [(math.cos(a) * 0.04, math.sin(a) * 0.04, -0.03), (math.cos(a) * 0.08, math.sin(a) * 0.08, -0.25),
               (math.cos(a) * 0.04, math.sin(a) * 0.04, -0.45), (math.cos(a) * 0.09, math.sin(a) * 0.09, -0.6)]
        parts.append(tube(f"Arm{i}", pts, 0.03, m=arm_m, segs=6, radius_end=0.012))
    for i in range(10):
        a = math.tau * i / 10
        pts = [(math.cos(a) * 0.21, math.sin(a) * 0.21, -0.03), (math.cos(a) * 0.2, math.sin(a) * 0.2, -0.4),
               (math.cos(a) * 0.17, math.sin(a) * 0.17, -0.8)]
        parts.append(tube(f"Ten{i}", pts, 0.008, m=arm_m, segs=4, radius_end=0.004))
    save("aqua_jelly", [merge("Jelly", parts)])


def kelp_strand(name, height, seed, m):
    r = rng(seed)
    parts = []
    stipe = [(0.06 * math.sin(t * 2.5 + seed), 0.05 * math.cos(t * 1.7 + seed), t * height) for t in [i / 10 for i in range(11)]]
    parts.append(tube(name + "Stipe", stipe, 0.035, m=m, segs=5, radius_end=0.02))
    n = int(height / 0.42)
    for i in range(n):
        t = (i + 0.7) / (n + 0.5)
        base = Vector(stipe[min(10, int(t * 10))])
        a = r.uniform(0, math.tau) if i % 2 else (i * 2.4)
        dir_ = Vector((math.cos(a), math.sin(a), 0.0))
        length = r.uniform(0.55, 0.9) * (1.0 - 0.35 * t)
        pts, widths = [], []
        for k in range(6):
            u = k / 5
            pts.append(base + dir_ * u * length * 0.8 + Vector((0, 0, u * length * 0.75 + 0.02)))
            widths.append(0.16 * math.sin(math.pi * min(1.0, u * 1.15 + 0.08)) + 0.015)
        parts.append(ribbon(f"{name}Blade{i}", pts, widths, m=m, normal=(-dir_.y, dir_.x, 0.0)))
        parts.append(sphere(f"{name}Bladder{i}", 0.04, base + dir_ * 0.04, m=m, segs=6, rings=4))
    return parts


def build_kelp():
    reset_scene()
    k = amat("KelpGreen", "Kelp", rough=0.6)
    g = amat("GrassGreen", "#5fae3a", rough=0.6)
    grass = []
    r = rng(9)
    for i in range(9):
        a = r.uniform(0, math.tau)
        d = r.uniform(0.0, 0.15)
        h = r.uniform(0.35, 0.7)
        base = Vector((math.cos(a) * d, math.sin(a) * d, 0))
        lean = Vector((math.cos(a), math.sin(a), 0)) * 0.12
        pts = [base + lean * (u * u) + Vector((0, 0, u * h)) for u in (0, 0.33, 0.66, 1.0)]
        grass.append(ribbon(f"Grass{i}", pts, [0.05, 0.045, 0.03, 0.005], m=g, normal=(-math.sin(a), math.cos(a), 0)))
    save("aqua_kelp", [merge("KelpTall", kelp_strand("KT", 5.6, 1, k)), merge("KelpShort", kelp_strand("KS", 3.4, 2, k)),
                       merge("SeaGrass", grass)])


def _reef_mats():
    return dict(
        rock=amat("Rock", rough=0.85), rockd=amat("RockDark", rough=0.9), rockl=amat("RockLight", rough=0.85),
        orange=amat("Coral", rough=0.6), pink=amat("Pink", rough=0.55), violet=amat("Violet", rough=0.55),
        yellow=amat("Yellow", rough=0.55), teal=amat("TealLight", rough=0.55), light=amat("CoralLight", rough=0.6),
        dark=amat("Dark", rough=0.5), tip=aglow("TipGlow", "#ffe36b", 1.4), pinkglow=aglow("PinkGlow", "PinkLight", 1.2),
        groove=amat("YellowDark", "#c99a1a"), urchin=amat("VioletDark", rough=0.6),
    )


def build_reefs():
    reset_scene()
    m = _reef_mats()
    p = rock("A1", (0, 0, 0), 0.8, m["rock"], seed=1) + rock("A2", (0.7, 0.3, 0), 0.55, m["rockd"], seed=2)
    p += rock("A3", (-0.6, -0.2, 0), 0.5, m["rockl"], seed=3)
    p += coral_branch("AB", (0.0, 0.0, 0.45), 0.9, m["orange"], seed=4, tip=m["tip"])
    p += coral_fan("AF", (0.6, 0.35, 0.3), 0.8, m["violet"], yaw=0.4, seed=5)
    p += coral_branch("AB2", (-0.6, -0.1, 0.3), 0.6, m["pink"], seed=6, tip=m["pinkglow"])
    p += coral_table("AT", (0.35, -0.45, 0.1), 0.38, m["teal"], seed=7)
    save("aqua_reef_a", [merge("ReefA", p)])

    reset_scene()
    m = _reef_mats()
    p = rock("B1", (0, 0, 0), 0.7, m["rockd"], seed=11, squash=0.55)
    p += coral_brain("BB", (-0.25, 0.1, 0.25), 0.4, m["yellow"], seed=12, groove=m["groove"])
    p += coral_tubes("BT", (0.45, -0.1, 0.15), 0.9, m["pink"], m["dark"], seed=13)
    p += anemone("BA", (0.1, -0.45, 0.15), 0.3, m["light"], m["pinkglow"], seed=14)
    p += anemone("BA2", (-0.55, -0.35, 0.05), 0.24, m["teal"], m["tip"], seed=15)
    p += coral_fan("BF", (0.0, 0.45, 0.25), 0.7, m["orange"], yaw=-0.3, seed=16)
    save("aqua_reef_b", [merge("ReefB", p)])

    reset_scene()
    m = _reef_mats()
    p = []
    for i in range(5):
        a = math.tau * i / 5
        p += rock(f"C{i}", (math.cos(a) * 0.55, math.sin(a) * 0.45, 0), 0.32 + 0.08 * (i % 3), (m["rock"], m["rockd"], m["rockl"])[i % 3], seed=20 + i)
    p += starfish("CS1", (0.2, -0.3, 0.25), 0.14, m["orange"], yaw=0.3)
    p += starfish("CS2", (-0.4, 0.2, 0.2), 0.12, m["yellow"], yaw=1.3)
    p += urchin("CU", (0.0, 0.25, 0.25), 0.1, m["urchin"], m["violet"])
    save("aqua_rocks", [merge("Rocks", p)])


if __name__ == "__main__":
    build_fish()
    build_jelly()
    build_kelp()
    build_reefs()
