"""The rotunda centrepiece of Tidal Tunnels.

    aqua_station.glb       the Reef Supply Ring: a yellow submarine-hull counter
                           with four docked mini-sub supply pods, wrapped around
                           the base of the coral tank (loadout station art), with
                           diving helmets, snack tins and life rings on the ring.
                           Node OpenLights (terminal screens and pod beacons) is
                           shown only while the station is open
                           (scenes/props/aqua_station.tscn).
    aqua_reef_column.glb   the towering cylindrical coral-reef tank: base drum,
                           rock spire covered in coral, glass hoops, water
                           surface and the lit crown (the glass itself is a
                           shader in the level)

Front faces -Y (Godot +Z). Both are centred on the origin, floor at z = 0.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aqua_common import *  # noqa: F401,F403

GLASS_R = 3.2
BASE_TOP = 1.3
GLASS_TOP = 9.0


def mini_sub(prefix, label, label_m):
    """Docked supply pod, ~2.4 m long along X, its outward side facing -Y."""
    yellow, ydark, orange = amat("SubYellow", rough=0.45, emit=0.22), amat("SubYellowDark", rough=0.5), amat("Orange", rough=0.5, emit=0.18)
    steel, dark = amat("SteelDark", rough=0.4, metal=0.5), amat("Dark", rough=0.5)
    glass = aglow("PortGlow", "Cyan", 2.2)
    amber = glow("PodBeacon", "#ffb84a", 3.5)
    parts = capsule_x(prefix + "Hull", 0.68, 1.5, (0, 0, 1.25), m=yellow, segs=18)
    parts += [
        cyl(prefix + "Band", 0.71, 0.14, (-0.45, 0, 1.25), rot=rad(0, 90, 0), segs=18, bevel=0.03, m=orange),
        cyl(prefix + "Band2", 0.71, 0.14, (0.45, 0, 1.25), rot=rad(0, 90, 0), segs=18, bevel=0.03, m=orange),
        box(prefix + "Tower", (0.7, 0.62, 0.55), (0.1, 0, 1.98), bevel=0.2, segs=3, m=yellow),
        box(prefix + "TowerCap", (0.76, 0.68, 0.08), (0.1, 0, 2.27), bevel=0.03, m=ydark),
        cyl(prefix + "Scope", 0.05, 0.75, (-0.08, 0.12, 2.6), segs=8, bevel=0.0, m=steel),
        box(prefix + "ScopeHead", (0.22, 0.12, 0.1), (-0.13, 0.12, 2.98), bevel=0.03, m=steel),
        cyl(prefix + "ScopeLens", 0.04, 0.03, (-0.25, 0.12, 2.98), rot=rad(0, 90, 0), segs=8, bevel=0.0, m=glass),
        cyl(prefix + "Hub", 0.14, 0.18, (1.5, 0, 1.25), rot=rad(0, 90, 0), segs=10, bevel=0.03, m=steel),
        sphere(prefix + "Nose", 0.1, (1.62, 0, 1.25), m=orange, segs=8, rings=5),
        box(prefix + "FinTop", (0.42, 0.06, 0.34), (1.12, 0, 1.92), bevel=0.02, m=orange),
        box(prefix + "FinL", (0.42, 0.34, 0.06), (1.12, -0.7, 1.25), bevel=0.02, m=orange),
        box(prefix + "FinR", (0.42, 0.34, 0.06), (1.12, 0.7, 1.25), bevel=0.02, m=orange),
        bulb(prefix + "Beacon", 0.09, (0.3, 0, 2.38), amber),
        box(prefix + "Hatch", (0.5, 0.06, 0.5), (-0.5, -0.66, 1.25), bevel=0.06, m=ydark),
        box(prefix + "HatchWheel", (0.26, 0.04, 0.26), (-0.5, -0.71, 1.25), bevel=0.05, m=steel),
        box(prefix + "Plaque", (1.1, 0.05, 0.3), (0.35, -0.6, 1.88), bevel=0.04, m=dark),
        text(prefix + "Label", label, 0.2, 0.03, (0.35, -0.64, 1.88), m=label_m),
    ]
    for i in range(3):
        a = math.tau * i / 3
        parts.append(box(f"{prefix}Blade{i}", (0.05, 0.12, 0.36), (1.48, math.cos(a) * 0.2, 1.25 + math.sin(a) * 0.2),
                         rot=(a, 0.3, 0), bevel=0.02, m=orange))
    parts += porthole(prefix + "Port", 0.22, (-0.1, -0.67, 1.2), frame=amat("Brass", rough=0.35, metal=0.6), glass=glass)
    parts += rivet_row(prefix + "RivA", (-0.75, -0.62, 1.58), (0.75, -0.62, 1.58), 9, 0.025, ydark)
    parts += rivet_row(prefix + "RivB", (-0.75, -0.62, 0.86), (0.75, -0.62, 0.86), 9, 0.025, ydark)
    return parts


def build_station():
    reset_scene()
    yellow, ydark, orange = amat("SubYellow", rough=0.45, emit=0.22), amat("SubYellowDark", rough=0.5), amat("Orange", rough=0.5, emit=0.18)
    navy, steel, teal = amat("NavyLight", rough=0.5), amat("SteelDark", rough=0.4, metal=0.5), amat("Teal", rough=0.45)
    dark = amat("Dark", rough=0.5)
    cyan = aglow("StripGlow", "Cyan", 2.6)
    screen = aglow("ScreenGlow", "#38e1ff", 1.8)
    pink = aglow("SignPink", "Pink", 2.2)
    yellow_glow = aglow("SignYellow", "#ffd45a", 2.0)
    brass = amat("Brass", rough=0.35, metal=0.6)
    port = aglow("PortGlow", "Cyan", 2.2)
    S = 48
    parts = [
        annulus("Plinth", 3.4, 4.95, 0.16, z=0.08, m=amat("NavyDark", rough=0.5), segs=S),
        torus("PlinthGlow", 4.95, 0.035, (0, 0, 0.16), m=cyan, major_segs=64, minor_segs=4),
        annulus("Skirt", 3.5, 4.5, 0.4, z=0.36, m=steel, segs=S),
        annulus("Hull", 3.5, 4.62, 0.82, z=0.94, m=yellow, segs=S, bevel=0.16),
        annulus("Stripe", 4.3, 4.66, 0.12, z=1.02, m=orange, segs=S),
        annulus("Counter", 3.56, 4.8, 0.14, z=1.42, m=navy, segs=S),
        torus("CounterTrim", 4.8, 0.05, (0, 0, 1.42), m=teal, major_segs=64, minor_segs=6),
        torus("InnerTrim", 3.58, 0.06, (0, 0, 1.49), m=brass, major_segs=64, minor_segs=6),
    ]
    # Rivet rows and portholes on the hull.
    for row, z in enumerate((0.62, 1.27)):
        for i in range(56):
            a = math.tau * (i + 0.5 * row) / 56
            parts.append(sphere(f"Rivet{row}_{i:02d}", 0.028, (math.cos(a) * 4.6, math.sin(a) * 4.6, z), m=ydark, segs=6, rings=4))
    for i in range(16):
        a = math.tau * (i + 0.5) / 16
        if i % 4 in (1, 2):
            ph = porthole(f"Port{i:02d}", 0.2, (0, -4.66, 0.82), frame=brass, glass=port, rivets=6)
            parts += place(ph, rot_z=a + math.pi / 2)
    # Four docked mini-sub supply pods on the diagonals, tangent to the ring.
    labels = ("AMMO", "SNACKS", "SWAP", "AMMO")
    for i in range(4):
        a = math.tau * (i + 0.5) / 4
        sub = mini_sub(f"Pod{i}_", labels[i], yellow_glow if i % 2 == 0 else pink)
        # Pod axis tangent to the ring; outward face (-Y) points away from the centre.
        parts += place(sub, (math.cos(a) * 4.55, math.sin(a) * 4.55, 0.0), rot_z=a + math.pi / 2)
        # Hose from the pod into the tank base.
        hx, hy = math.cos(a), math.sin(a)
        parts.append(tube(f"Hose{i}", [(hx * 4.3, hy * 4.3, 1.9), (hx * 3.9, hy * 3.9, 2.35), (hx * 3.62, hy * 3.62, 1.7)],
                          0.07, m=steel, segs=8))
    # Terminals on the cardinal points: a tilted screen on a post.
    for i in range(4):
        a = math.tau * i / 4
        term = [
            box(f"Term{i}Post", (0.2, 0.2, 0.55), (0, -4.25, 1.75), bevel=0.05, m=steel),
            box(f"Term{i}Body", (0.9, 0.16, 0.62), (0, -4.3, 2.22), rot=rad(-18, 0, 0), bevel=0.06, m=dark),
            box(f"Term{i}Glass", (0.76, 0.03, 0.48), (0, -4.385, 2.22), rot=rad(-18, 0, 0), bevel=0.0, m=navy),
            box(f"Term{i}Screen", (0.76, 0.03, 0.48), (0, -4.395, 2.22), rot=rad(-18, 0, 0), bevel=0.0, m=screen),
            box(f"Term{i}Bar", (0.92, 0.06, 0.08), (0, -4.36, 2.55), rot=rad(-18, 0, 0), bevel=0.02, m=orange),
        ]
        # Energy cells racked beside each terminal.
        for k in range(3):
            term.append(cyl(f"Term{i}Cell{k}", 0.07, 0.34, (-0.65 + k * 0.16, -4.35, 1.66), segs=10, bevel=0.0, m=cyan))
            term.append(cyl(f"Term{i}CellCap{k}", 0.08, 0.06, (-0.65 + k * 0.16, -4.35, 1.85), segs=10, bevel=0.0, m=steel))
        parts += place(term, rot_z=a + math.pi / 2)
        # A life ring hung on the hull under each terminal.
        parts += place(life_ring(f"Ring{i}", 0.24, (0, -4.72, 0.84)), rot_z=a + math.pi / 2)
        # Goods in the free stretches of counter either side of the terminal.
        parts += place(diving_helmet(f"Helmet{i}", brass, port), (math.cos(a - 0.37) * 4.18, math.sin(a - 0.37) * 4.18, 1.49),
                       rot_z=a - 0.37 + math.pi / 2)
        parts += place(snack_tins(f"Tins{i}", i), (math.cos(a + 0.37) * 4.18, math.sin(a + 0.37) * 4.18, 1.49),
                       rot_z=a + 0.37 + math.pi / 2)
    lit = [ob for ob in parts if ob.name.endswith("Screen") or ob.name.endswith("Beacon")]
    rest = [ob for ob in parts if ob not in lit]
    save("aqua_station", [merge("Station", rest), merge("OpenLights", lit)])


def life_ring(prefix, radius, loc):
    """Orange-and-white life ring facing -Y."""
    parts = [torus(prefix + "Tube", radius, radius * 0.26, (0, 0, 0), rot=rad(90, 0, 0), m=amat("Orange", rough=0.5, emit=0.18),
                   major_segs=16, minor_segs=6)]
    for k in range(4):
        a = math.tau * (k + 0.5) / 4
        parts.append(box(f"{prefix}Wrap{k}", (radius * 0.6, radius * 0.62, radius * 0.3),
                         (math.cos(a) * radius, 0, math.sin(a) * radius), rot=(0, -a + math.pi / 2, 0), bevel=0.02, segs=1,
                         m=amat("White", rough=0.4)))
    return place(parts, loc)


def diving_helmet(prefix, brass, port):
    """A brass diving helmet on a little stand, faceplate toward -Y."""
    parts = [
        box(prefix + "Stand", (0.46, 0.4, 0.08), (0, 0, 0.04), bevel=0.02, segs=1, m=amat("NavyDark", rough=0.5)),
        cyl(prefix + "Collar", 0.2, 0.12, (0, 0, 0.14), segs=12, bevel=0.0, m=amat("Brass", rough=0.35, metal=0.6)),
        sphere(prefix + "Dome", 0.23, (0, 0, 0.37), scale=(1, 1, 1.05), m=brass, segs=12, rings=8),
        sphere(prefix + "Knob", 0.05, (0, 0, 0.62), m=brass, segs=6, rings=4),
    ]
    parts += porthole(prefix + "Face", 0.1, (0, -0.22, 0.37), frame=amat("SteelDark", rough=0.4, metal=0.5), glass=port, rivets=0)
    for s in (-1, 1):
        parts += place([cyl(f"{prefix}SideRim{s}", 0.075, 0.03, (0, -0.215, 0.4), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=amat("SteelDark", rough=0.4, metal=0.5)),
                        cyl(f"{prefix}SidePane{s}", 0.055, 0.04, (0, -0.22, 0.4), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=port)],
                       rot_z=s * math.radians(80))
    return parts


def snack_tins(prefix, seed):
    """A stack of fish-snack tins with label bands."""
    colours = ("Coral", "SubYellow", "TealLight", "Pink")
    parts = []
    for k, (dx, dy, z) in enumerate(((-0.13, 0.0, 0.0), (0.13, 0.02, 0.0), (0.0, 0.01, 0.17))):
        c = amat(colours[(seed + k) % 4], rough=0.45)
        parts += [
            cyl(f"{prefix}Tin{k}", 0.11, 0.16, (dx, dy, z + 0.08), segs=12, bevel=0.0, m=c),
            cyl(f"{prefix}Label{k}", 0.113, 0.07, (dx, dy, z + 0.08), segs=12, bevel=0.0, m=amat("White", rough=0.4)),
        ]
    parts.append(sphere(prefix + "Fish", 0.06, (0.0, -0.105, 0.25), scale=(1.4, 0.4, 0.8), m=amat("Orange", rough=0.5, emit=0.18), segs=8, rings=5))
    return parts


def build_reef_column():
    reset_scene()
    navy, navyd, brass = amat("NavyLight", rough=0.5), amat("NavyDark", rough=0.5), amat("Brass", rough=0.35, metal=0.6)
    teal = amat("Teal", rough=0.45)
    cyan = aglow("StripGlow", "Cyan", 2.6)
    sand = amat("Sand", rough=0.9)
    rockm, rockd, rockl = amat("LiveRock", "#9a7b92", rough=0.85), amat("LiveRockDark", "#6f6a8e", rough=0.9), amat("LiveRockTan", "#b58d74", rough=0.85)
    coral_o, coral_p, coral_v = amat("Coral", rough=0.6), amat("Pink", rough=0.55), amat("Violet", rough=0.55)
    coral_y, coral_t, coral_l = amat("Yellow", rough=0.55), amat("TealLight", rough=0.55), amat("CoralLight", rough=0.6)
    tip_glow = aglow("TipGlow", "#ffe36b", 1.4)
    pink_glow = aglow("PinkGlow", "PinkLight", 1.2)
    dark = amat("Dark", rough=0.5)
    surface = aglow("Surface", "#6fe6f5", 0.55)

    base = [
        cyl("Base", 3.55, BASE_TOP, (0, 0, BASE_TOP / 2), segs=48, bevel=0.08, m=navy),
        cyl("BaseBand", 3.58, 0.12, (0, 0, BASE_TOP - 0.2), segs=48, bevel=0.02, m=cyan),
        torus("BaseLip", 3.3, 0.08, (0, 0, BASE_TOP + 0.02), m=brass, major_segs=64, minor_segs=6),
        cyl("Sand", GLASS_R - 0.05, 0.08, (0, 0, BASE_TOP + 0.03), segs=40, bevel=0.0, m=sand),
    ]
    # Glass hoops and vertical mullions (read the glass as glass).
    for i, z in enumerate((BASE_TOP + 0.05, 4.6, 7.0, GLASS_TOP)):
        base.append(torus(f"Hoop{i}", GLASS_R + 0.04, 0.07 if i in (0, 3) else 0.045, (0, 0, z), m=brass, major_segs=64, minor_segs=6))
    # Crown: lid, glowing underside ring and a domed cap.
    crown = [
        cyl("Lid", 3.65, 0.55, (0, 0, GLASS_TOP + 0.3), segs=48, bevel=0.12, m=navy),
        cyl("LidGlow", 3.4, 0.06, (0, 0, GLASS_TOP + 0.02), segs=48, bevel=0.0, m=cyan),
        torus("LidTrim", 3.66, 0.06, (0, 0, GLASS_TOP + 0.58), m=brass, major_segs=64, minor_segs=6),
        cyl("Cap", 3.1, 0.6, (0, 0, GLASS_TOP + 0.85), segs=40, bevel=0.2, m=teal, radius_top=2.2),
        cyl("CapTop", 2.2, 0.16, (0, 0, GLASS_TOP + 1.2), segs=32, bevel=0.06, m=navyd),
        cyl("WaterSurface", GLASS_R - 0.05, 0.03, (0, 0, GLASS_TOP - 0.35), segs=40, bevel=0.0, m=surface),
    ]
    for i in range(12):
        a = math.tau * i / 12
        crown.append(bulb(f"CrownBulb{i:02d}", 0.08, (math.cos(a) * 3.66, math.sin(a) * 3.66, GLASS_TOP + 0.3),
                          glow("CrownLamp", "#7ff4ff", 3.0)))
    # Rock spire: stacked lumpy boulders tapering upward.
    reef = []
    z = BASE_TOP
    for i, (r, h) in enumerate(((1.45, 1.1), (1.25, 1.0), (1.1, 1.0), (0.95, 0.9), (0.8, 0.9), (0.62, 0.8))):
        reef.append(lumpy(f"Spire{i}", r, (0.15 * math.sin(i * 1.7), 0.12 * math.cos(i * 2.1), z + h * 0.55), (1.0, 0.95, h / r * 0.8),
                          m=(rockm, rockl, rockd)[i % 3], seed=i + 3, amount=0.22, subdiv=2, freq=1.8))
        z += h * 0.85
    # Ledges and boulders around the foot.
    for i in range(9):
        a = math.tau * i / 9 + 0.2
        d = 2.1 + 0.5 * (i % 2)
        reef += rock(f"Foot{i}", (math.cos(a) * d, math.sin(a) * d, BASE_TOP + 0.05), 0.45 + 0.15 * (i % 3), (rockm, rockd)[i % 2], seed=20 + i)
    # Coral garden: on the foot ring and climbing the spire.
    r = rng(5)
    spots = []
    for i in range(20):
        a = math.tau * i / 20 + r.uniform(-0.1, 0.1)
        spots.append((a, r.uniform(1.7, 2.8), BASE_TOP + 0.08))
    for i in range(24):
        a = math.tau * i / 24 * 3.0 + 0.3
        zz = BASE_TOP + 0.7 + (i % 12) * 0.48
        rr = max(0.5, 1.4 - (zz - BASE_TOP) * 0.14)
        spots.append((a, rr, zz))
    for i, (a, d, zz) in enumerate(spots):
        p = (math.cos(a) * d, math.sin(a) * d, zz)
        kind = i % 7
        if kind == 0:
            reef += coral_branch(f"Br{i}", p, 0.95, coral_o, seed=i, tip=tip_glow)
        elif kind == 1:
            reef += coral_fan(f"Fan{i}", p, 0.85, coral_v, yaw=a + math.pi / 2, seed=i)
        elif kind == 2:
            reef += coral_brain(f"Brn{i}", p, 0.4, coral_y, seed=i, groove=amat("YellowDark", "#c99a1a"))
        elif kind == 3:
            reef += coral_tubes(f"Tb{i}", p, 0.85, coral_p, dark, seed=i)
        elif kind == 4:
            reef += anemone(f"An{i}", p, 0.38, coral_l, pink_glow, seed=i)
        elif kind == 5:
            reef += coral_table(f"Tab{i}", p, 0.5, coral_t, seed=i)
        else:
            reef += coral_branch(f"Br{i}", p, 0.75, coral_p, seed=i + 50, tip=pink_glow)
    for i in range(6):
        a = math.tau * i / 6 + 0.5
        reef += starfish(f"Star{i}", (math.cos(a) * 2.9, math.sin(a) * 2.9, BASE_TOP + 0.07), 0.13, (coral_o, coral_y, coral_p)[i % 3], yaw=a)
    save("aqua_reef_column", [merge("ReefBase", base), merge("ReefCrown", crown), merge("Reef", reef)])


if __name__ == "__main__":
    build_station()
    build_reef_column()
