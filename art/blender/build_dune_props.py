"""Dune Spaceport props: cover, set dressing and the animated bits around the pad.

    dune_container.glb     6.1 m cargo container (material "ContainerPaint" is recoloured
                           per instance by the level).
    dune_dish.glb          satellite dish. Nodes: DishBase, DishHead (pivot on the yaw axis;
                           the level sweeps it slowly).
    dune_tank_sphere.glb   spherical LOX tank on legs with a walkway ring.
    dune_tank_long.glb     horizontal fuel tank on saddles, with pipework.
    dune_light_mast.glb    14 m floodlight mast, lamps facing -Y.
    dune_barrier.glb       2.4 m concrete jersey barrier with hazard paint.
    dune_barrels.glb       pallet of four drums.
    dune_crates.glb        stack of supply crates.
    dune_tug.glb           retro tow tug with a baggage cart.
    dune_cable_reel.glb    cable spool lying on its side.
    dune_windsock.glb      striped windsock on a pole.
    dune_sign.glb          roadside billboard with bulbs: "LAUNCH PAD 9".
    dune_lamp.glb          5 m atomic-age lamp post: glowing globe inside two orbit rings.
    dune_cone.glb          traffic cone.
    dune_warning.glb       small warning sign on a post ("FUEL LINE · NO ENTRY").
    dune_monorail_pylon.glb / dune_monorail_beam.glb / dune_monorail_car.glb
                           T pylon, 10 m guideway along X (top at 8.7 m) and a two-car train.

Front faces -Y (Godot +Z); origins at the centre of the base unless noted.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dune_kit import *  # noqa: F401,F403


def build_container():
    """6.1 m cargo container. Both ends read at cover distance: the door end (+X)
    has two doors with four lock bars, cam keepers, hinges, a door seam and a
    stencilled number; the blind end (-X) is corrugated with a vent and a
    hazard placard."""
    reset_scene()
    paint = dmat("ContainerPaint", "#d0582c", rough=0.6)
    rib = dmat("ContainerRib", "#b9b0a4", rough=0.6)
    steel, dark = dmat("SteelDark", rough=0.45, metal=0.4), dmat("HazardDark", rough=0.6)
    white = dmat("ContainerText", "#f3efe6", rough=0.5)
    shade = dmat("ContainerShade", "#2f2a2e", rough=0.8)
    hazard = dmat("Hazard", rough=0.5)
    L, W, H = 6.1, 2.44, 2.6
    parts = [box("Body", (L, W, H), (0, 0, H / 2), bevel=0.05, m=paint)]
    n = 18
    for s_ in (-1, 1):
        for i in range(n):
            x = -L / 2 + 0.35 + i * (L - 0.7) / (n - 1)
            parts.append(box(f"Rib{s_}{i:02d}", (0.16, 0.08, H - 0.36), (x, s_ * (W / 2 + 0.02), H / 2), bevel=0.03, segs=1, m=paint))
    for i in range(6):
        y = -W / 2 + 0.3 + i * (W - 0.6) / 5
        parts.append(box(f"RoofRib{i}", (L - 0.4, 0.14, 0.06), (0, y, H + 0.01), bevel=0.02, segs=1, m=paint))
    # Corner castings and rails.
    for x in (-L / 2, L / 2):
        for y in (-W / 2, W / 2):
            for z in (0.12, H - 0.12):
                parts.append(box(f"Corner{x}{y}{z}", (0.2, 0.2, 0.24), (x * 0.985, y * 0.97, z), bevel=0.03, segs=1, m=steel))
    for s_ in (-1, 1):
        parts.append(box(f"TopRail{s_}", (L, 0.12, 0.16), (0, s_ * W / 2, H - 0.08), bevel=0.02, segs=1, m=paint))
        parts.append(box(f"BotRail{s_}", (L, 0.12, 0.2), (0, s_ * W / 2, 0.1), bevel=0.02, segs=1, m=steel))
    # Door end (+X): header and sill, two door leaves split down the middle.
    xd = L / 2
    parts.append(box("DoorHeader", (0.16, W, 0.24), (xd + 0.04, 0, H - 0.14), bevel=0.03, m=steel))
    parts.append(box("DoorSill", (0.16, W, 0.2), (xd + 0.04, 0, 0.12), bevel=0.03, m=steel))
    for s_ in (-1, 1):
        y0 = s_ * W / 4
        parts.append(box(f"Leaf{s_}", (0.08, W / 2 - 0.12, H - 0.5), (xd + 0.05, y0, H / 2), bevel=0.02, m=paint))
        # Pressed panels on each leaf (shadowed recesses).
        for k in range(3):
            parts.append(fbox(f"LeafPanel{s_}{k}", (0.02, W / 2 - 0.34, 0.5), (xd + 0.1, y0, 0.55 + k * 0.62), m=shade))
        # Hinges on the outer edge of each leaf.
        for k, z in enumerate((0.45, 1.05, 1.65, 2.2)):
            parts.append(box(f"Hinge{s_}{k}", (0.12, 0.14, 0.18), (xd + 0.1, s_ * (W / 2 - 0.08), z), bevel=0.02, segs=1, m=steel))
    parts.append(fbox("DoorSplit", (0.04, 0.05, H - 0.5), (xd + 0.1, 0, H / 2), m=dark))
    # Four lock bars with cam keepers top and bottom and a handle each.
    for i in range(4):
        y = -W / 2 + 0.35 + i * (W - 0.7) / 3
        parts.append(rod(f"LockBar{i}", (xd + 0.14, y, 0.28), (xd + 0.14, y, H - 0.28), 0.045, m=rib))
        for z in (0.32, H - 0.32):
            parts.append(box(f"Keeper{i}{z}", (0.12, 0.16, 0.12), (xd + 0.13, y, z), bevel=0.02, segs=1, m=steel))
        parts.append(box(f"LockHandle{i}", (0.07, 0.26, 0.09), (xd + 0.2, y + 0.12, 1.2), bevel=0.02, segs=1, m=rib))
        parts.append(box(f"HandleClip{i}", (0.08, 0.08, 0.16), (xd + 0.17, y + 0.24, 1.2), bevel=0.02, segs=1, m=steel))
    # Stencilled number and a data plate on the doors.
    parts.append(text("DoorCode", "LP9 0418", 0.24, 0.02, (xd + 0.1, 0, H - 0.52), rot=(0, 0, math.pi / 2), m=white))
    parts.append(box("DataPlate", (0.03, 0.4, 0.26), (xd + 0.1, -W / 4, 0.95), bevel=0.01, m=white))
    # Blind end (-X): corrugated end wall, a vent and a hazard placard.
    xb = -L / 2
    parts += corrugated("End", W - 0.3, H - 0.5, (xb - 0.02, 0, 0.25), rot_z=-math.pi / 2, pitch=0.24, depth=0.05, m=paint)
    parts.append(box("EndHeader", (0.14, W, 0.22), (xb - 0.03, 0, H - 0.13), bevel=0.03, m=steel))
    parts.append(box("EndSill", (0.14, W, 0.2), (xb - 0.03, 0, 0.12), bevel=0.03, m=steel))
    parts.append(box("Vent", (0.06, 0.5, 0.18), (xb - 0.1, -0.6, H - 0.45), bevel=0.02, m=steel))
    for k in range(3):
        parts.append(fbox(f"VentSlot{k}", (0.02, 0.42, 0.03), (xb - 0.135, -0.6, H - 0.5 + k * 0.05), m=shade))
    placard = box("Placard", (0.04, 0.4, 0.4), (0, 0, 0), bevel=0.01, m=white)
    placard.matrix_world = Matrix.Translation((xb - 0.08, 0.55, 1.4)) @ Matrix.Rotation(math.pi / 4, 4, "X") @ placard.matrix_basis
    inner = box("PlacardInner", (0.05, 0.3, 0.3), (0, 0, 0), bevel=0.0, m=hazard)
    inner.matrix_world = Matrix.Translation((xb - 0.085, 0.55, 1.4)) @ Matrix.Rotation(math.pi / 4, 4, "X") @ inner.matrix_basis
    parts += [placard, inner]
    parts.append(text("EndCode", "DUNE LINES", 0.2, 0.02, (xb - 0.1, 0, 0.62), rot=(0, 0, -math.pi / 2), m=white))
    # Stencils on both long sides.
    for s_, rot in ((-1, 0.0), (1, math.pi)):
        parts.append(text(f"Logo{s_}", "DUNE LINES", 0.42, 0.04, (-0.6 * -s_, s_ * (W / 2 + 0.07), H - 0.6), rot=(0, 0, rot), m=white))
        parts.append(text(f"Code{s_}", "LP9 0418", 0.2, 0.03, (1.6 * -s_, s_ * (W / 2 + 0.07), 0.55), rot=(0, 0, rot), m=white))
    save("dune_container", [merge("Container", parts)])


def build_dish():
    reset_scene()
    white, shade = dmat("Hull", rough=0.45), dmat("HullShade", rough=0.5)
    rust, conc = dmat("Rust", rough=0.55), dmat("Concrete", rough=0.9)
    steel, sdark = dmat("Steel", rough=0.4, metal=0.5), dmat("SteelDark", rough=0.45, metal=0.4)
    red = dglow("Beacon", "#ff4a3a", 3.0)
    base = [cyl("Plinth", 1.5, 0.5, (0, 0, 0.25), segs=8, bevel=0.08, m=conc),
            cyl("Pedestal", 0.75, 3.4, (0, 0, 2.2), segs=16, bevel=0.06, m=white, radius_top=0.55),
            cyl("PedestalBand", 0.78, 0.4, (0, 0, 1.0), segs=16, bevel=0.04, m=rust),
            box("Cabinet", (1.0, 0.6, 1.2), (0.0, -0.95, 0.9), bevel=0.06, m=sdark)]
    pivot_z = 4.1
    head = [cyl("Turntable", 0.8, 0.3, (0, 0, pivot_z), segs=16, bevel=0.05, m=sdark)]
    for s in (-1, 1):
        head.append(box(f"Yoke{s}", (0.3, 0.5, 1.6), (s * 1.0, 0, pivot_z + 0.9), bevel=0.06, m=rust))
    head.append(box("YokeBase", (2.3, 0.6, 0.3), (0, 0, pivot_z + 0.2), bevel=0.06, m=rust))
    # Dish: a paraboloid opening toward -Y, tilted up 35 degrees.
    f = 1.3
    prof = [(r * 2.6 / 10, (r * 2.6 / 10) ** 2 / (4 * f)) for r in range(11)]
    dish = [lathe("Bowl", prof, m=white, segs=36, cap=False),
            lathe("BowlBack", [(0.0, -0.08)] + [(r, z - 0.08) for r, z in prof[1:]], m=shade, segs=36, cap=False),
            lathe("Rim", [(2.62, prof[-1][1] - 0.06), (2.68, prof[-1][1] + 0.04)], m=rust, segs=36),
            cyl("Hub", 0.45, 0.6, (0, 0, -0.3), segs=12, bevel=0.05, m=sdark)]
    for i in range(3):
        a = math.tau * i / 3
        dish.append(rod(f"Strut{i}", (math.cos(a) * 2.2, math.sin(a) * 2.2, prof[-1][1] * 0.75), (0, 0, f + 0.1), 0.04, m=steel))
    dish.append(cyl("Feed", 0.18, 0.5, (0, 0, f + 0.2), segs=10, bevel=0.03, m=sdark, radius_top=0.1))
    dish.append(bulb("FeedLight", 0.1, (0, 0, f + 0.5), red))
    for ob in dish:
        ob.matrix_world = Matrix.Translation((0, 0, pivot_z + 1.4)) @ Matrix.Rotation(math.radians(-55), 4, "X") @ ob.matrix_basis
    head += dish
    base_ob = merge("DishBase", base)
    head_ob = merge("DishHead", head, pivot=(0, 0, pivot_z))
    save("dune_dish", [base_ob, head_ob])


def build_tank_sphere():
    reset_scene()
    white, teal = dmat("Hull", rough=0.45), dmat("Teal", rough=0.45)
    rust, rdark = dmat("Rust", rough=0.55), dmat("RustDark", rough=0.6)
    steel, conc = dmat("Steel", rough=0.4, metal=0.5), dmat("Concrete", rough=0.9)
    yellow, navy = dmat("Hazard", rough=0.5), dmat("Navy", rough=0.5)
    R, C = 3.3, 5.0
    parts = [box("Pad", (8.4, 8.4, 0.35), (0, 0, 0.17), bevel=0.06, m=conc),
             sphere("Shell", R, (0, 0, C), m=white, segs=32, rings=18),
             cyl("Band", R + 0.04, 0.7, (0, 0, C - 0.4), segs=40, bevel=0.03, m=teal),
             cyl("Walk", R + 0.9, 0.12, (0, 0, C), segs=40, bevel=0.0, m=dmat("SteelDark", rough=0.45, metal=0.4)),
             torus("WalkRail", R + 0.85, 0.05, (0, 0, C + 1.0), m=yellow, major_segs=40, minor_segs=6)]
    for i in range(8):
        a = math.tau * (i + 0.5) / 8
        x, y = math.cos(a), math.sin(a)
        parts.append(beam(f"Leg{i}", (x * (R + 0.4), y * (R + 0.4), 0.35), (x * (R - 0.1), y * (R - 0.1), C), 0.32, m=rust))
        parts.append(box(f"LegFoot{i}", (0.7, 0.7, 0.3), (x * (R + 0.4), y * (R + 0.4), 0.5), bevel=0.05, m=rdark))
        b = math.tau * (i + 1.5) / 8
        parts.append(beam(f"Brace{i}", (x * (R + 0.3), y * (R + 0.3), 0.6), (math.cos(b) * (R + 0.15), math.sin(b) * (R + 0.15), C * 0.55), 0.1, m=rdark))
    parts.append(beam("Ladder", (R + 0.9, 0.0, 0.35), (R + 0.9, 0.0, C), 0.6, 0.08, m=yellow))
    parts.append(rod("Pipe", (0, 0, C - R + 0.1), (0, 0, 0.35), 0.25, m=steel))
    parts.append(text("Stencil", "LOX", 1.2, 0.08, (0, -R - 0.02, C + 1.4), m=navy))
    save("dune_tank_sphere", [merge("TankSphere", parts)])


def build_tank_long():
    reset_scene()
    white, rust = dmat("Hull", rough=0.45), dmat("Rust", rough=0.55)
    rdark, conc = dmat("RustDark", rough=0.6), dmat("Concrete", rough=0.9)
    steel, sdark = dmat("Steel", rough=0.4, metal=0.5), dmat("SteelDark", rough=0.45, metal=0.4)
    navy, red = dmat("Navy", rough=0.5), dmat("Red", rough=0.5)
    L, R, C = 9.0, 1.45, 2.0
    body = [cyl("Body", R, L, (0, 0, 0), segs=28, bevel=0.0, m=white),
            sphere("CapA", R, (0, 0, L / 2), scale=(1, 1, 0.5), m=white, segs=28, rings=12),
            sphere("CapB", R, (0, 0, -L / 2), scale=(1, 1, 0.5), m=white, segs=28, rings=12)]
    for i, z in enumerate((-2.8, 0.0, 2.8)):
        body.append(cyl(f"Hoop{i}", R + 0.04, 0.35, (0, 0, z), segs=28, bevel=0.03, m=rust))
    for ob in body:
        ob.matrix_world = Matrix.Translation((0, 0, C)) @ Matrix.Rotation(math.pi / 2, 4, "Y") @ ob.matrix_basis
    parts = body
    for x in (-3.0, 3.0):
        parts.append(make_flat(prism(f"Saddle{x}", [(-1.2, 0.0), (1.2, 0.0), (1.1, 1.3), (-1.1, 1.3)], 0.6, (x, 0, 0), rot=(0, 0, math.pi / 2), m=conc)))
    parts.append(text("Stencil", "FUEL", 0.9, 0.06, (0, -R - 0.03, C + 0.1), m=navy))
    parts.append(rod("PipeUp", (L / 2 + 0.4, 0, C), (L / 2 + 0.4, 0, C + 2.0), 0.16, m=steel))
    parts.append(rod("PipeOver", (L / 2 + 0.4, 0, C + 2.0), (L / 2 + 2.4, 0, C + 2.0), 0.16, m=steel))
    parts.append(rod("PipeDown", (L / 2 + 2.4, 0, C + 2.0), (L / 2 + 2.4, 0, 0.0), 0.16, m=steel))
    parts.append(cyl("Valve", 0.32, 0.08, (L / 2 + 0.4, -0.25, C + 1.2), rot=(math.pi / 2, 0, 0), segs=14, bevel=0.02, m=red))
    parts.append(box("Hatch", (0.9, 0.9, 0.3), (-1.6, 0, C + R - 0.05), bevel=0.06, m=sdark))
    parts.append(beam("Ladder", (-L / 2 + 0.6, -R - 0.15, 0.0), (-L / 2 + 0.6, -R - 0.15, C + R), 0.5, 0.08, m=dmat("Hazard", rough=0.5)))
    save("dune_tank_long", [merge("TankLong", parts)])


def build_light_mast():
    reset_scene()
    steel, sdark = dmat("Steel", rough=0.4, metal=0.5), dmat("SteelDark", rough=0.45, metal=0.4)
    rust, conc = dmat("Rust", rough=0.55), dmat("Concrete", rough=0.9)
    lamp = dglow("Flood", "#fff2c8", 2.6)
    red = dglow("Beacon", "#ff4a3a", 3.0)
    parts = [cyl("Footing", 0.8, 0.6, (0, 0, 0.3), segs=8, bevel=0.06, m=conc),
             cyl("Pole", 0.32, 13.0, (0, 0, 7.0), segs=10, bevel=0.0, m=steel, radius_top=0.2),
             cyl("Collar", 0.4, 0.4, (0, 0, 1.0), segs=10, bevel=0.04, m=rust),
             box("Frame", (3.2, 0.3, 1.8), (0, -0.35, 13.6), bevel=0.06, m=sdark),
             bulb("TopBeacon", 0.2, (0, 0, 14.8), red)]
    for r in range(2):
        for c in range(3):
            x, z = -1.0 + c * 1.0, 13.15 + r * 0.9
            parts.append(box(f"Lamp{r}{c}", (0.8, 0.45, 0.7), (x, -0.6, z), bevel=0.08, m=sdark))
            parts.append(fbox(f"Lens{r}{c}", (0.62, 0.06, 0.52), (x, -0.85, z), m=lamp))
    parts.append(beam("Ladder", (0.33, 0.0, 1.2), (0.25, 0.0, 12.6), 0.4, 0.06, m=dmat("Hazard", rough=0.5)))
    save("dune_light_mast", [merge("LightMast", parts)])


def build_barrier():
    reset_scene()
    conc, cdark = dmat("Concrete", rough=0.9), dmat("ConcreteDark", rough=0.92)
    outline = [(-0.36, 0.0), (0.36, 0.0), (0.2, 0.28), (0.13, 0.9), (-0.13, 0.9), (-0.2, 0.28)]
    parts = [make_flat(prism("Body", outline, 2.4, rot=(0, 0, math.pi / 2), m=conc))]
    for s in (-1, 1):
        parts += hazard_band(f"Paint{s}", 2.3, 0.22, (0, s * 0.3, 0.14), 0.0 if s < 0 else math.pi, stripe=0.35, depth=0.03)
    parts.append(fbox("Slot", (0.5, 0.8, 0.12), (0, 0, 0.06), m=cdark))
    save("dune_barrier", [merge("Barrier", parts)])


def build_barrels():
    reset_scene()
    cols = [dmat("BarrelRust", "#c8562b", rough=0.55), dmat("BarrelTeal", "#21a89f", rough=0.5),
            dmat("BarrelYellow", "#ffc21f", rough=0.5), dmat("BarrelWhite", "#ece6da", rough=0.5)]
    dark, wood = dmat("HazardDark", rough=0.6), dmat("Pallet", "#a8794e", rough=0.85)
    parts = []
    for i in range(5):
        parts.append(box(f"Slat{i}", (0.18, 2.4, 0.06), (-0.98 + i * 0.49, 0, 0.13), bevel=0.02, m=wood))
    for s in (-1, 1):
        parts.append(box(f"Runner{s}", (2.2, 0.16, 0.1), (0, s * 0.9, 0.05), bevel=0.02, m=wood))
    for i, (x, y) in enumerate(((-0.52, -0.52), (0.52, -0.52), (-0.52, 0.52), (0.52, 0.52))):
        m = cols[(i * 3 + 1) % 4]
        parts.append(cyl(f"Drum{i}", 0.46, 1.25, (x, y, 0.79), segs=16, bevel=0.04, m=m))
        for k, z in enumerate((0.48, 1.1)):
            parts.append(cyl(f"Hoop{i}{k}", 0.48, 0.06, (x, y, z), segs=16, bevel=0.0, m=dark))
        parts.append(cyl(f"Bung{i}", 0.07, 0.04, (x + 0.2, y, 1.43), segs=8, bevel=0.0, m=dark))
    save("dune_barrels", [merge("Barrels", parts)])


def build_crates():
    reset_scene()
    wood, wdark = dmat("Crate", "#d9a86a", rough=0.8), dmat("CrateDark", "#a87444", rough=0.85)
    rust, navy = dmat("Rust", rough=0.55), dmat("Navy", rough=0.5)
    parts = []

    def crate(prefix, size, loc, rot=0.0):
        sx, sy, sz = size
        p = [box(prefix + "Body", size, (0, 0, sz / 2), bevel=0.04, m=wood)]
        for s in (-1, 1):
            p.append(box(f"{prefix}StrapX{s}", (sx + 0.04, 0.1, sz + 0.04), (0, s * sy * 0.3, sz / 2), bevel=0.01, segs=1, m=rust))
        for e in range(4):
            x, y = (-1 if e % 2 else 1) * sx / 2, (-1 if e // 2 else 1) * sy / 2
            p.append(box(f"{prefix}Edge{e}", (0.1, 0.1, sz + 0.02), (x, y, sz / 2), bevel=0.02, segs=1, m=wdark))
        p.append(text(prefix + "Mark", "LP9", sz * 0.28, 0.02, (0, -sy / 2 - 0.02, sz * 0.5), m=navy))
        return place(p, loc, rot)
    parts += crate("A", (1.6, 1.2, 1.2), (-0.9, 0, 0))
    parts += crate("B", (1.4, 1.3, 1.1), (0.75, 0.1, 0), 0.15)
    parts += crate("C", (1.2, 1.0, 0.9), (-0.7, 0.05, 1.2), -0.2)
    save("dune_crates", [merge("Crates", parts)])


def build_tug():
    reset_scene()
    body, trim = dmat("TugBody", "#ffc21f", rough=0.5), dmat("Teal", rough=0.45)
    dark, rubber = dmat("HazardDark", rough=0.6), dmat("Rubber", rough=0.8)
    steel, white = dmat("Steel", rough=0.4, metal=0.5), dmat("Hull", rough=0.45)
    glass = dmat("TugGlass", "#6fd2e0", rough=0.15, emit=0.3)
    lamp = dglow("TugLamp", "#fff2c8", 2.0)
    amber = dglow("LiftAmber", "#ffa12a", 3.0)
    parts = [box("Chassis", (3.2, 1.8, 0.6), (0, 0, 0.65), bevel=0.15, m=body),
             box("Hood", (1.3, 1.6, 0.6), (-0.9, 0, 1.15), bevel=0.2, m=body),
             box("Cab", (1.4, 1.6, 1.2), (0.6, 0, 1.55), bevel=0.25, m=white),
             box("CabGlass", (1.2, 1.64, 0.6), (0.55, 0, 1.75), bevel=0.15, m=glass),
             box("Stripe", (3.24, 1.84, 0.16), (0, 0, 0.8), bevel=0.05, m=trim),
             box("Bumper", (0.2, 1.9, 0.3), (-1.65, 0, 0.55), bevel=0.06, m=dark),
             bulb("Beacon", 0.13, (0.6, 0, 2.25), amber)]
    for s in (-1, 1):
        parts.append(sphere(f"Head{s}", 0.13, (-1.55, s * 0.6, 1.0), scale=(0.6, 1, 1), m=lamp, segs=10, rings=6))
        for x in (-1.0, 1.0):
            parts.append(cyl(f"Wheel{s}{x}", 0.42, 0.34, (x, s * 0.95, 0.42), rot=(math.pi / 2, 0, 0), segs=16, bevel=0.08, m=rubber))
            parts.append(cyl(f"Hub{s}{x}", 0.2, 0.36, (x, s * 0.95, 0.42), rot=(math.pi / 2, 0, 0), segs=10, bevel=0.03, m=steel))
    parts.append(beam("Hitch", (1.6, 0, 0.5), (2.6, 0, 0.5), 0.12, m=dark))
    # Baggage cart behind.
    cart = [box("CartBed", (3.0, 1.7, 0.2), (4.2, 0, 0.75), bevel=0.05, m=trim),
            box("CartCrateA", (1.2, 1.1, 0.9), (3.6, 0, 1.3), bevel=0.06, m=dmat("Crate", "#d9a86a", rough=0.8)),
            box("CartCrateB", (1.0, 1.0, 0.7), (4.9, 0.1, 1.2), bevel=0.06, m=dmat("BarrelRust", "#c8562b", rough=0.55))]
    for s in (-1, 1):
        cart.append(beam(f"CartRail{s}", (2.8, s * 0.85, 1.1), (5.6, s * 0.85, 1.1), 0.06, m=steel))
        for x in (3.2, 5.2):
            cart.append(cyl(f"CartWheel{s}{x}", 0.3, 0.2, (x, s * 0.8, 0.3), rot=(math.pi / 2, 0, 0), segs=12, bevel=0.05, m=rubber))
    parts += cart
    save("dune_tug", [merge("Tug", parts)])


def build_cable_reel():
    reset_scene()
    wood, wdark = dmat("Crate", "#d9a86a", rough=0.8), dmat("CrateDark", "#a87444", rough=0.85)
    cable = dmat("CableBlack", "#2e2a33", rough=0.7)
    parts = []
    for s in (-1, 1):
        parts.append(cyl(f"Flange{s}", 1.0, 0.12, (0, s * 0.55, 1.0), rot=(math.pi / 2, 0, 0), segs=20, bevel=0.03, m=wood))
    parts.append(cyl("Drum", 0.62, 1.0, (0, 0, 1.0), rot=(math.pi / 2, 0, 0), segs=20, bevel=0.06, m=cable))
    parts.append(cyl("Axle", 0.15, 1.3, (0, 0, 1.0), rot=(math.pi / 2, 0, 0), segs=10, bevel=0.02, m=wdark))
    parts.append(tube("Lead", [(0.0, -0.2, 0.4), (0.5, -0.6, 0.1), (1.6, -0.9, 0.08), (2.4, -0.5, 0.08)], 0.06, m=cable, segs=8))
    save("dune_cable_reel", [merge("CableReel", parts)])


def build_windsock():
    reset_scene()
    steel, conc = dmat("Steel", rough=0.4, metal=0.5), dmat("Concrete", rough=0.9)
    orange, white = dmat("SockOrange", "#ff6a1f", rough=0.6), dmat("Hull", rough=0.45)
    red = dglow("Beacon", "#ff4a3a", 3.0)
    parts = [cyl("Base", 0.4, 0.4, (0, 0, 0.2), segs=8, bevel=0.04, m=conc),
             cyl("Pole", 0.08, 6.0, (0, 0, 3.4), segs=8, bevel=0.0, m=steel),
             torus("Hoop", 0.42, 0.04, (0.1, 0, 6.0), rot=(0, math.pi / 2, 0), m=steel, major_segs=16, minor_segs=5),
             bulb("Top", 0.1, (0, 0, 6.5), red)]
    for i in range(5):
        r0 = 0.42 - i * 0.06
        r1 = r0 - 0.06
        seg = cyl(f"Sock{i}", r0, 0.62, (0.42 + i * 0.6, 0, 6.0 - i * 0.12), rot=(0, math.pi / 2 + 0.2, 0), segs=14, bevel=0.0,
                  m=orange if i % 2 == 0 else white, radius_top=r1)
        parts.append(seg)
    save("dune_windsock", [merge("Windsock", parts)])


def build_sign():
    reset_scene()
    steel, sdark = dmat("Steel", rough=0.4, metal=0.5), dmat("SteelDark", rough=0.45, metal=0.4)
    teal, rust = dmat("Teal", rough=0.45), dmat("Rust", rough=0.55)
    cream, navy = dmat("TowerCream", "#efe2c6", rough=0.7), dmat("Navy", rough=0.5)
    amber = glow("BulbAmber", "#ffc24a", 3.0)
    parts = []
    for s in (-1, 1):
        parts.append(beam(f"Leg{s}", (s * 2.6, 0.2, 0.0), (s * 2.4, 0.2, 4.0), 0.25, m=sdark))
    parts.append(box("Board", (7.0, 0.3, 2.6), (0, 0, 4.9), bevel=0.15, m=teal))
    # Back: a rust panel on a braced steel frame.
    parts.append(box("BackPanel", (6.6, 0.08, 2.2), (0, 0.19, 4.9), bevel=0.03, m=rust))
    for z in (4.0, 5.8):
        parts.append(beam(f"BackRail{z}", (-3.2, 0.3, z), (3.2, 0.3, z), 0.14, m=sdark))
    for x0, x1 in ((-3.2, -0.2), (0.2, 3.2)):
        parts.append(beam(f"BackBrace{x0}", (x0, 0.3, 4.0), (x1, 0.3, 5.8), 0.1, m=sdark))
    parts.append(text("BackText", "LP-9", 0.6, 0.04, (0, 0.25, 4.9), rot=(0, 0, math.pi), m=cream))
    parts.append(box("Panel", (6.4, 0.32, 2.0), (0, -0.02, 4.9), bevel=0.08, m=cream))
    parts.append(text("Line1", "LAUNCH PAD 9", 0.7, 0.06, (0, -0.2, 5.3), m=rust))
    parts.append(text("Line2", "STAND CLEAR OF THE BLAST ZONE", 0.28, 0.04, (0, -0.2, 4.55), m=navy))
    star_ob = star("Star", 0.9, 0.2, (3.1, -0.1, 6.3), m=rust, bevel=0.03)
    parts.append(star_ob)
    parts += bulb_row("SignBulbT", (-3.3, -0.2, 6.15), (3.3, -0.2, 6.15), 14, 0.08, amber)
    parts += bulb_row("SignBulbB", (-3.3, -0.2, 3.65), (3.3, -0.2, 3.65), 14, 0.08, amber)
    save("dune_sign", [merge("Sign", parts)])


def build_lamp():
    reset_scene()
    teal, tdark = dmat("Teal", rough=0.45), dmat("TealDark", rough=0.5)
    rust, conc = dmat("Rust", rough=0.55), dmat("Concrete", rough=0.9)
    steel = dmat("Steel", rough=0.4, metal=0.5)
    globe = glow("BulbAmber", "#ffc24a", 3.0)
    parts = [cyl("Footing", 0.42, 0.3, (0, 0, 0.15), segs=10, bevel=0.05, m=conc),
             cyl("Base", 0.26, 0.9, (0, 0, 0.75), segs=12, bevel=0.05, m=tdark, radius_top=0.16),
             cyl("Pole", 0.09, 3.6, (0, 0, 3.0), segs=10, bevel=0.0, m=teal),
             cyl("Collar", 0.16, 0.18, (0, 0, 1.25), segs=12, bevel=0.04, m=rust),
             cyl("Cup", 0.2, 0.22, (0, 0, 4.82), segs=12, bevel=0.04, m=rust, radius_top=0.28),
             sphere("Globe", 0.32, (0, 0, 5.2), m=globe, segs=16, rings=10),
             bulb("GlobeHalo", 0.3, (0, 0, 5.2), globe),
             cyl("Spike", 0.03, 0.6, (0, 0, 5.75), segs=6, bevel=0.0, m=steel),
             sphere("SpikeBall", 0.06, (0, 0, 6.08), m=rust, segs=8, rings=5)]
    for i, rot in enumerate(((math.radians(70), 0, 0), (math.radians(70), 0, math.radians(90)))):
        ring = torus(f"Orbit{i}", 0.52, 0.03, (0, 0, 0), m=rust, major_segs=28, minor_segs=6)
        ring.rotation_euler = rot
        ring.location = (0, 0, 5.2)
        parts.append(ring)
    save("dune_lamp", [merge("Lamp", parts)])


def build_cone():
    reset_scene()
    orange, white = dmat("ConeOrange", "#ff6a1f", rough=0.55), dmat("Hull", rough=0.45)
    dark = dmat("Rubber", rough=0.8)
    parts = [box("ConeBase", (0.46, 0.46, 0.06), (0, 0, 0.03), bevel=0.02, m=dark),
             cyl("ConeBody", 0.18, 0.66, (0, 0, 0.39), segs=14, bevel=0.0, m=orange, radius_top=0.035),
             cyl("ConeBand", 0.13, 0.12, (0, 0, 0.42), segs=14, bevel=0.0, m=white, radius_top=0.105)]
    save("dune_cone", [merge("Cone", parts)])


def build_warning():
    reset_scene()
    steel, rust = dmat("Steel", rough=0.4, metal=0.5), dmat("Rust", rough=0.55)
    yellow, dark = dmat("Hazard", rough=0.5), dmat("HazardDark", rough=0.6)
    parts = [cyl("Post", 0.05, 1.6, (0, 0.06, 0.8), segs=8, bevel=0.0, m=steel),
             box("Plate", (1.0, 0.05, 0.7), (0, 0, 1.45), bevel=0.03, m=yellow),
             box("PlateRim", (1.06, 0.04, 0.76), (0, 0.02, 1.45), bevel=0.02, m=dark),
             text("Line1", "FUEL LINE", 0.17, 0.02, (0, -0.035, 1.55), m=dark),
             text("Line2", "NO ENTRY", 0.15, 0.02, (0, -0.035, 1.33), m=rust)]
    save("dune_warning", [merge("Warning", parts)])


def build_monorail():
    reset_scene()
    conc, cdark = dmat("Concrete", rough=0.9), dmat("ConcreteDark", rough=0.92)
    white, teal = dmat("Hull", rough=0.45), dmat("Teal", rough=0.45)
    rust, dark = dmat("Rust", rough=0.55), dmat("HazardDark", rough=0.6)
    glass = dmat("TugGlass", "#6fd2e0", rough=0.15, emit=0.3)
    win = dglow("TowerWindow", "#ffd486", 1.4)
    pylon = [cyl("PylonCol", 0.7, 7.0, (0, 0, 3.5), segs=12, bevel=0.06, m=conc, radius_top=0.55),
             box("PylonHead", (1.2, 2.6, 0.8), (0, 0, 7.2), bevel=0.12, m=conc),
             cyl("PylonFoot", 1.1, 0.4, (0, 0, 0.2), segs=12, bevel=0.06, m=cdark)]
    beam_parts = [box("Guideway", (10.0, 0.9, 1.1), (0, 0, 8.15), bevel=0.1, m=white),
                  box("GuideStripe", (10.02, 0.92, 0.18), (0, 0, 8.4), bevel=0.04, m=teal)]
    car = []
    for k in range(2):
        x0 = k * 6.6
        hull = lathe(f"CarHull{k}", [(0.0, -3.0), (0.9, -2.6), (1.25, -1.6), (1.3, 0.0), (1.25, 1.6), (0.9, 2.6), (0.0, 3.0)],
                     m=white, segs=20)
        hull.rotation_euler = (0, math.pi / 2, 0)
        hull.location = (x0, 0, 9.85)
        car.append(hull)
        car.append(cyl(f"CarBand{k}", 1.32, 3.8, (x0, 0, 9.85), rot=(0, math.pi / 2, 0), segs=20, bevel=0.0, m=teal))
        for s in (-1, 1):
            car.append(box(f"CarWin{k}{s}", (3.2, 0.12, 0.55), (x0, s * 1.22, 10.25), bevel=0.05, m=win))
        car.append(box(f"Bogie{k}", (3.6, 1.1, 0.5), (x0, 0, 8.95), bevel=0.08, m=dark))
    car.append(sphere("NoseGlass", 0.9, (-2.6, 0, 10.0), scale=(0.6, 1.0, 0.6), m=glass, segs=14, rings=8))
    car.append(box("Coupler", (1.2, 0.5, 0.4), (3.3, 0, 9.4), bevel=0.06, m=dark))
    save_split("dune_monorail", {"dune_monorail_pylon": [merge("Pylon", pylon)], "dune_monorail_beam": [merge("Beam", beam_parts)],
                                 "dune_monorail_car": [merge("Car", car)]})


if __name__ == "__main__":
    which = sys.argv[1:] or ["container", "dish", "tank_sphere", "tank_long", "light_mast", "barrier", "barrels", "crates",
                             "tug", "cable_reel", "windsock", "sign", "lamp", "cone", "warning", "monorail"]
    for key in which:
        globals()["build_" + key]()
