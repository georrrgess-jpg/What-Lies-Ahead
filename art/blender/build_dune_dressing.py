"""Launch Pad 9 accent props in the spacecraft white-and-teal livery: cool,
clean shapes that stand out against the sand, rust and orange containers.

    dune_gse_cart    ground-support coolant cart (3.2 x 1.5 m): white tank with
                     teal bands on a dark chassis, hose reel, control box
    dune_console     pad-side launch console (1.8 x 0.9 m, 1.3 m tall) with a lit
                     screen, status buttons and a whip antenna
    dune_totem       3.2 m wayfinding totem: white body, teal header with a big
                     "9", lit arrows and destination bars

Front faces -Y (Godot +Z); origins at the centre of the base.

    python art/blender/build_dune_dressing.py [gse_cart console totem]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dune_kit import *  # noqa: F401,F403


def build_gse_cart():
    reset_scene()
    hull, shade = dmat("Hull", rough=0.45), dmat("HullShade", rough=0.5)
    teal, teal_d = dmat("Teal", rough=0.45), dmat("TealDark", rough=0.5)
    sdark, steel = dmat("SteelDark", rough=0.45, metal=0.4), dmat("Steel", rough=0.4, metal=0.5)
    rubber = dmat("Rubber", rough=0.8)
    green, red = dglow("CartLampGreen", "#5dff8a", 3.0), dglow("CartLampRed", "#ff4a3a", 3.0)
    navy = dmat("Navy", rough=0.5)
    parts = [
        box("Chassis", (3.0, 1.3, 0.22), (0, 0, 0.52), bevel=0.05, m=sdark),
        box("Bumper", (0.12, 1.36, 0.18), (1.56, 0, 0.5), bevel=0.04, m=dmat("Hazard", rough=0.5)),
        tube("Drawbar", [(-1.5, 0, 0.5), (-2.0, 0, 0.42)], 0.05, m=sdark, segs=8),
        torus("DrawRing", 0.09, 0.025, (-2.05, 0, 0.42), m=steel, major_segs=12, minor_segs=5),
    ]
    for i, x in enumerate((-0.95, 0.95)):
        for s_ in (-1, 1):
            parts.append(cyl(f"Wheel{i}{s_}", 0.36, 0.26, (x, s_ * 0.68, 0.36), rot=(math.pi / 2, 0, 0), segs=16, bevel=0.06, m=rubber))
            parts.append(cyl(f"Hub{i}{s_}", 0.17, 0.28, (x, s_ * 0.68, 0.36), rot=(math.pi / 2, 0, 0), segs=12, bevel=0.03, m=hull))
            parts.append(box(f"Fender{i}{s_}", (0.9, 0.3, 0.06), (x, s_ * 0.68, 0.78), bevel=0.03, m=teal_d))
    # The tank: a white capsule with teal bands, on two saddles.
    tank_z = 1.15
    body = cyl("Tank", 0.55, 1.4, (-0.05, 0, tank_z), rot=(0, math.pi / 2, 0), segs=24, bevel=0.0, m=hull)
    ends = [sphere("TankEndA", 0.55, (-0.75, 0, tank_z), scale=(0.55, 1, 1), m=hull, segs=24, rings=12),
            sphere("TankEndB", 0.55, (0.65, 0, tank_z), scale=(0.55, 1, 1), m=hull, segs=24, rings=12)]
    parts += [body] + ends
    for k, x in enumerate((-0.45, 0.35)):
        parts.append(cyl(f"Band{k}", 0.565, 0.22, (x, 0, tank_z), rot=(0, math.pi / 2, 0), segs=24, bevel=0.0, m=teal))
        parts.append(box(f"Saddle{k}", (0.24, 0.9, 0.36), (x, 0, 0.78), bevel=0.04, m=sdark))
    parts.append(box("Stripe", (1.4, 0.02, 0.12), (-0.05, -0.555, tank_z), bevel=0.0, m=teal))
    parts.append(text("TankText", "COOLANT", 0.2, 0.02, (-0.05, -0.57, tank_z + 0.24), m=navy))
    parts.append(cyl("Manway", 0.2, 0.08, (-0.05, 0, tank_z + 0.56), segs=16, bevel=0.03, m=shade))
    parts.append(tube("Rail", [(-0.6, -0.4, tank_z + 0.5), (-0.6, -0.4, tank_z + 0.75), (0.5, -0.4, tank_z + 0.75), (0.5, -0.4, tank_z + 0.5)],
                      0.025, m=dmat("Hazard", rough=0.5), segs=6))
    # Hose reel and control box at the rear (+X end).
    parts.append(cyl("Reel", 0.34, 0.32, (1.22, 0, 0.98), rot=(math.pi / 2, 0, 0), segs=20, bevel=0.04, m=teal))
    parts.append(cyl("ReelHose", 0.27, 0.34, (1.22, 0, 0.98), rot=(math.pi / 2, 0, 0), segs=20, bevel=0.0, m=rubber))
    parts.append(tube("Hose", [(1.22, -0.18, 0.72), (1.5, -0.5, 0.45), (1.2, -0.75, 0.12), (0.6, -0.85, 0.08)], 0.05, m=rubber, segs=8))
    parts.append(box("ControlBox", (0.36, 0.6, 0.6), (-1.3, 0, 0.93), bevel=0.04, m=hull))
    parts.append(fbox("ControlFace", (0.02, 0.44, 0.24), (-1.49, 0, 1.0), m=navy))
    parts.append(sphere("LampG", 0.05, (-1.5, -0.14, 0.82), m=green, segs=8, rings=5))
    parts.append(sphere("LampR", 0.05, (-1.5, 0.14, 0.82), m=red, segs=8, rings=5))
    save("dune_gse_cart", [merge("GseCart", parts)])


def build_console():
    reset_scene()
    hull, shade = dmat("Hull", rough=0.45), dmat("HullShade", rough=0.5)
    teal, teal_d = dmat("Teal", rough=0.45), dmat("TealDark", rough=0.5)
    sdark = dmat("SteelDark", rough=0.45, metal=0.4)
    screen = dglow("ConsoleScreen", "#2fd6c8", 1.6)
    trace = dglow("ConsoleTrace", "#d8fff4", 2.4)
    red, amber, green = dglow("BtnRed", "#ff4a3a", 2.4), dglow("BtnAmber", "#ffb03a", 2.4), dglow("BtnGreen", "#5dff8a", 2.4)
    parts = [
        box("Plinth", (1.9, 1.0, 0.12), (0, 0, 0.06), bevel=0.03, m=sdark),
        box("Body", (1.8, 0.8, 0.95), (0, 0.05, 0.6), bevel=0.06, segs=2, m=hull),
        box("Kick", (1.82, 0.04, 0.16), (0, -0.36, 0.2), bevel=0.01, m=teal_d),
        box("Band", (1.82, 0.04, 0.12), (0, -0.36, 0.86), bevel=0.01, m=teal),
    ]
    desk = [box("Desk", (1.8, 0.7, 0.1), (0, 0, 0), bevel=0.04, m=teal),
            fbox("Screen", (1.0, 0.02, 0.42), (-0.3, -0.36, 0.26), m=screen)]
    # Slanted top with the screen and a row of buttons.
    tilt = Matrix.Translation((0, 0.0, 1.12)) @ Matrix.Rotation(math.radians(-22), 4, "X")
    hood = box("Hood", (1.2, 0.08, 0.55), (-0.3, -0.33, 0.27), bevel=0.03, m=shade)
    for ob in desk + [hood]:
        ob.matrix_world = tilt @ ob.matrix_basis
    parts += desk + [hood]
    pts = [(-0.75 + i * 0.1, -0.375, 0.16 + 0.12 * math.sin(i * 1.3) + 0.04 * (i % 3)) for i in range(10)]
    line = tube("Trace", pts, 0.012, m=trace, segs=4)
    line.matrix_world = tilt @ line.matrix_basis
    parts.append(line)
    for i, m in enumerate((red, amber, green, green)):
        b = cyl(f"Btn{i}", 0.05, 0.04, (0.45 + (i % 2) * 0.16, -0.1 + (i // 2) * 0.18, 0.06), segs=12, bevel=0.01, m=m)
        b.matrix_world = tilt @ b.matrix_basis
        parts.append(b)
    parts.append(tube("Antenna", [(0.8, 0.35, 1.1), (0.8, 0.35, 2.1)], 0.012, m=sdark, segs=5))
    parts.append(sphere("AntennaTip", 0.035, (0.8, 0.35, 2.12), m=red, segs=8, rings=5))
    parts.append(text("Label", "PAD 9 CONTROL", 0.12, 0.012, (0, -0.36, 0.55), m=dmat("Navy", rough=0.5)))
    save("dune_console", [merge("Console", parts)])


def build_totem():
    reset_scene()
    hull, shade = dmat("Hull", rough=0.45), dmat("HullShade", rough=0.5)
    teal, teal_d = dmat("Teal", rough=0.45), dmat("TealDark", rough=0.5)
    sdark = dmat("SteelDark", rough=0.45, metal=0.4)
    glow = dglow("TotemGlow", "#7ff0e2", 2.6)
    navy = dmat("Navy", rough=0.5)
    rust = dmat("Rust", rough=0.55)
    parts = [
        box("Base", (1.0, 0.5, 0.2), (0, 0, 0.1), bevel=0.05, m=sdark),
        box("Body", (0.86, 0.34, 2.6), (0, 0, 1.5), bevel=0.08, segs=2, m=hull),
        box("Header", (0.92, 0.4, 0.62), (0, 0, 2.95), bevel=0.08, segs=2, m=teal),
        box("Cap", (0.96, 0.44, 0.08), (0, 0, 3.3), bevel=0.03, m=teal_d),
        fbox("EdgeL", (0.03, 0.36, 2.5), (-0.44, 0, 1.5), m=glow),
        fbox("EdgeR", (0.03, 0.36, 2.5), (0.44, 0, 1.5), m=glow),
    ]
    for s_, rot in ((-1, 0.0), (1, math.pi)):
        y = s_ * 0.2
        parts.append(text(f"Nine{s_}", "9", 0.5, 0.03, (0, y + s_ * 0.01, 2.93), rot=(0, 0, rot), m=hull))
        for k, (label, arrow, col) in enumerate((("CREW", 1, navy), ("FUEL", -1, navy), ("PAD", 1, rust))):
            z = 2.2 - k * 0.5
            parts.append(box(f"Bar{s_}{k}", (0.7, 0.03, 0.3), (0, y, z), bevel=0.01, m=shade))
            parts.append(text(f"Txt{s_}{k}", label, 0.16, 0.012, (0.07 * arrow * s_, y + s_ * 0.02, z), rot=(0, 0, rot), m=col))
            ax = 0.25 * arrow * (-s_)
            outline = [(-0.07, -0.06), (0.0, -0.06), (0.0, -0.1), (0.09, 0.0), (0.0, 0.1), (0.0, 0.06), (-0.07, 0.06)]
            if arrow < 0:
                outline = [(-x, z_) for x, z_ in outline]
            arrow_ob = prism(f"Arrow{s_}{k}", outline, 0.012, (ax, y + s_ * 0.02, z), rot=(0, 0, rot), m=glow)
            parts.append(arrow_ob)
    save("dune_totem", [merge("Totem", parts)])


BUILDERS = {"gse_cart": build_gse_cart, "console": build_console, "totem": build_totem}

if __name__ == "__main__":
    for key in sys.argv[1:] or list(BUILDERS):
        BUILDERS[key]()
