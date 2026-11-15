"""Ashfall City buildings (the Endless map): broken shells that line the
streets, a corner block, the snapped skyscraper landmark and the radio mast.
Every face is dressed (no blank backs): window bays with dark rooms behind,
sills, shards, boards; collapsed corners step down storey by storey, exposing
floor slabs, column stubs and rebar; blown-out bays show the gutted floor.

    city_building_shell_a   brick tenement, 14 x 10 m, 4 storeys (~16 m), corner collapsed,
                            pawn shop and boarded store below, fire escape at the back
    city_building_shell_b   teal plaster block, 18 x 10 m, 3 storeys (~12.5 m), middle floor
                            blown out, burnt roof
    city_building_shell_c   concrete offices, 16 x 12 m, 6 storeys (~23 m), ribbon windows,
                            the top floors torn away on one side
    city_building_corner    corner block, 14 x 14 m, 4 storeys, two street faces (-Y, -X)
                            meeting at a chamfered DINER entrance
    city_skyscraper_broken  far landmark, 16 x 16 m, ~78 m: the top snapped and leaning,
                            fires at the break, a red warning lamp (empties Fire, Fire2)
    city_radio_tower        45 m lattice mast on a plinth, dishes, red beacons, the top bent

Origin at the centre of the footprint on the ground; fronts face -Y (Godot +Z).

    python art/blender/build_city_buildings.py [shell_a shell_b shell_c corner skyscraper radio_tower]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from city_common import *  # noqa: F401,F403
from build_city_gates import rubble, posters  # noqa: E402

T = 0.32          # wall thickness
SILL = 0.9        # window sill height above the storey floor
WIN_H = 1.75


class Style:
    """Materials and odds for one building."""

    def __init__(self, wall, band, trim, seed, lit=0.06, shard=0.35, boarded=0.1, soot=None):
        self.wall, self.band, self.trim = wall, band, trim
        self.rng = random.Random(seed)
        self.lit, self.shard, self.boarded = lit, shard, boarded
        self.soot = soot
        self.inner = cm("Interior", rough=0.95)
        self.slab = cm("ConcreteDark", rough=0.9)
        self.glow = steady("#ff9a3a", 0.8)


def bay_wall(prefix, length, z0, h, bays, st, blown=(), shop=False):
    """One storey of a wall along X (outer face at y = 0 facing -Y, thickness to +Y):
    piers between window bays; blown bays are open to the room behind."""
    p = []
    pw = max(0.45, length * 0.38 / (bays + 1))
    ww = (length - pw * (bays + 1)) / bays
    for i in range(bays + 1):
        x = -length / 2 + pw / 2 + i * (pw + ww)
        p.append(fbox(f"{prefix}P{i}", (pw, T, h), (x, T / 2, z0 + h / 2), m=st.wall))
    for i in range(bays):
        x = -length / 2 + pw + ww / 2 + i * (pw + ww)
        if i in blown:
            p.append(fbox(f"{prefix}Lip{i}", (ww, T + 0.2, 0.18), (x, T / 2 - 0.1, z0 + 0.09), m=st.slab))
            continue
        sill = 0.25 if shop else SILL
        wh = h - 0.7 if shop else WIN_H
        top = h - sill - wh
        p += [fbox(f"{prefix}Lo{i}", (ww, T, sill), (x, T / 2, z0 + sill / 2), m=st.wall),
              fbox(f"{prefix}Hi{i}", (ww, T, top), (x, T / 2, z0 + h - top / 2), m=st.band)]
        if not shop:
            p.append(fbox(f"{prefix}Ledge{i}", (ww + 0.16, 0.16, 0.08), (x, -0.05, z0 + sill - 0.02), m=st.trim))
        r = st.rng.random()
        zc = z0 + sill + wh / 2
        if r < st.lit:
            p.append(fbox(f"{prefix}Lit{i}", (ww, 0.04, wh), (x, T * 0.7, zc), m=st.glow))
        else:
            p.append(fbox(f"{prefix}Back{i}", (ww, 0.04, wh), (x, T * 0.75, zc), m=st.inner))
        r = st.rng.random()
        if r < st.boarded:
            for k in range(3):
                p.append(fbox(f"{prefix}Board{i}{k}", (ww + 0.1, 0.04, 0.2), (x, -0.02, zc - wh * 0.3 + k * wh * 0.3),
                              rot=(0, st.rng.uniform(-0.12, 0.12), 0), m=cm("WoodLight")))
        elif r < st.boarded + st.shard:
            p += shards(f"{prefix}Sh{i}", ww, wh, (x, T * 0.4, zc), seed=st.rng.randint(0, 999))
        if st.soot is not None and st.rng.random() < 0.3:
            p.append(fbox(f"{prefix}Soot{i}", (ww * 0.9, 0.03, 0.5), (x, -0.015, z0 + sill + wh + 0.25), m=st.soot))
    return p


def storey(prefix, x0, x1, D, z0, h, st, bays_per_m=0.33, blown=None, cut_right=False, shop_front=()):
    """A storey over the rectangle [x0, x1] x [-D/2, D/2]: four walls, the floor slab
    and a dark room volume. `blown` maps side -> bay indices left open. With
    `cut_right` the +X wall is a broken edge instead (a collapsed neighbour)."""
    blown = blown or {}
    W = x1 - x0
    cx = (x0 + x1) / 2
    p = [fbox(prefix + "Slab", (W, D, 0.3), (cx, 0, z0 - 0.15 + 0.3), m=st.slab),
         fbox(prefix + "Room", (W - 3.0, D - 3.0, h - 0.3), (cx, 0, z0 + h / 2 + 0.15), m=st.inner)]
    nb = max(1, round(W * bays_per_m))
    nd = max(1, round(D * bays_per_m))
    sides = [("F", W, nb, (cx, -D / 2, 0), 0.0), ("B", W, nb, (cx, D / 2, 0), math.pi),
             ("L", D, nd, (x0, 0, 0), -math.pi / 2), ("R", D, nd, (x1, 0, 0), math.pi / 2)]
    for key, length, bays, loc, rz in sides:
        if key == "R" and cut_right:
            wall = broken_wall(prefix + "RBreak", D, h, T, st.wall, seed=len(prefix) + int(z0), amp=h * 0.4, steps=6)
            place([wall], loc, rz)
            p.append(make_flat(wall))
            continue
        parts = bay_wall(prefix + key, length - 0.02, z0 + 0.15, h, bays, st, blown=blown.get(key, ()), shop=key in shop_front)
        p += place(parts, loc, rz)
    # Corner pilasters.
    for k, (x, y) in enumerate(((x0, -D / 2), (x1, -D / 2), (x0, D / 2), (x1, D / 2))):
        if cut_right and x == x1:
            continue
        p.append(fbox(f"{prefix}Cn{k}", (0.5, 0.5, h), (x, y, z0 + 0.15 + h / 2), m=st.trim))
    return p


def parapet(prefix, x0, x1, D, z, st, h=0.8):
    W = x1 - x0
    cx = (x0 + x1) / 2
    return [fbox(prefix + "F", (W + 0.3, 0.4, h), (cx, -D / 2, z + h / 2), m=st.trim),
            fbox(prefix + "B", (W + 0.3, 0.4, h), (cx, D / 2, z + h / 2), m=st.trim),
            fbox(prefix + "L", (0.4, D, h), (x0, 0, z + h / 2), m=st.trim),
            fbox(prefix + "R", (0.4, D, h), (x1, 0, z + h / 2), m=st.trim),
            fbox(prefix + "Roof", (W, D, 0.2), (cx, 0, z + 0.1), m=cm("Asphalt", rough=0.95))]


def stubs(prefix, x, D, z, st, seed, count=3):
    """Column stubs and rebar standing on an exposed slab edge at x."""
    rng = random.Random(seed)
    p = []
    for k in range(count):
        y = -D / 2 + 0.6 + k * (D - 1.2) / max(1, count - 1)
        h = rng.uniform(0.6, 2.2)
        p.append(fbox(f"{prefix}Col{k}", (0.45, 0.45, h), (x, y, z + h / 2), m=st.trim))
        p += rebar(f"{prefix}Rb{k}", (x, y, z + h), (0.1, 0, 1), 0.7, 3, (0.1, 0.12, 0), seed=seed + k)
    return p


def water_tank(prefix, loc):
    x, y, z = loc
    wood, steel = cm("WoodDark"), cm("SteelDark", metal=0.4)
    p = [cyl(prefix + "Tank", 1.1, 2.0, (x, y, z + 2.6), segs=10, bevel=0.0, m=wood),
         cyl(prefix + "Cap", 1.25, 0.9, (x, y, z + 4.05), segs=10, bevel=0.0, m=steel, radius_top=0.05)]
    for k in range(4):
        a = math.tau * k / 4 + 0.6
        p.append(fbox(f"{prefix}Leg{k}", (0.14, 0.14, 1.6), (x + math.cos(a) * 0.8, y + math.sin(a) * 0.8, z + 0.8), m=steel))
    for k in range(2):
        p.append(torus(f"{prefix}Hoop{k}", 1.12, 0.035, (x, y, z + 2.0 + k * 1.2), m=steel, major_segs=10, minor_segs=3))
    return p


def shopfront(prefix, x, width, z0, st, sign, sign_color, shutter=True):
    """A ground-floor shop facing -Y at y = 0: a shutter or a dark broken window
    behind the bay, a box sign above with neon lettering, a torn awning."""
    p = [box(prefix + "SignBox", (width * 0.9, 0.35, 0.7), (x, -0.25, z0 + 3.55), bevel=0.04, segs=1, m=cm("Soot")),
         text(prefix + "Sign", sign, 0.42, 0.05, (x, -0.45, z0 + 3.54), m=neon(sign_color))]
    if shutter:
        p.append(fbox(prefix + "Shutter", (width * 0.8, 0.06, 2.6), (x, 0.05, z0 + 1.45), m=cm("Steel", metal=0.4)))
        for k in range(8):
            p.append(fbox(f"{prefix}Rib{k}", (width * 0.8, 0.09, 0.05), (x, 0.03, z0 + 0.3 + k * 0.32), m=cm("SteelLight", metal=0.4)))
    # Awning frame with a torn canvas.
    rng = random.Random(len(prefix) + int(x * 10))
    p += [beam(prefix + "AwnL", (x - width * 0.42, 0, z0 + 3.05), (x - width * 0.42, -1.3, z0 + 2.65), 0.05, m=cm("SteelDark")),
          beam(prefix + "AwnR", (x + width * 0.42, 0, z0 + 3.05), (x + width * 0.42, -1.3, z0 + 2.65), 0.05, m=cm("SteelDark"))]
    torn = [(-width * 0.42, 0.0), (width * 0.42, 0.0), (width * 0.42, -0.9), (width * 0.1, -0.6 - rng.uniform(0, 0.4)), (-width * 0.2, -1.3), (-width * 0.42, -0.7)]
    canvas = slab(prefix + "Canvas", torn, 0.0, 0.04, m=cm(rng.choice(["Red", "Teal", "Orange"]), rough=0.9))
    canvas.location = (x, 0, z0 + 3.0)
    canvas.rotation_euler = (math.radians(-17), 0, 0)
    p.append(canvas)
    return p


def fire_escape(prefix, x, floors, z0, h, width=3.2):
    """Zig-zag fire escape on a wall facing -Y at y = 0 (landings, stairs, rails)."""
    steel = cm("SteelDark", rough=0.5, metal=0.5)
    rail = cm("Rust", rough=0.7, metal=0.3)
    p = []
    for f in range(floors):
        z = z0 + f * h + 0.15
        p += [fbox(f"{prefix}Land{f}", (width, 1.1, 0.08), (x, -0.6, z), m=steel),
              fbox(f"{prefix}Rail{f}", (width, 0.05, 0.05), (x, -1.13, z + 0.95), m=rail),
              fbox(f"{prefix}RailL{f}", (0.05, 1.1, 0.05), (x - width / 2, -0.6, z + 0.95), m=rail)]
        for k in range(4):
            p.append(fbox(f"{prefix}Post{f}{k}", (0.05, 0.05, 0.95), (x - width / 2 + k * width / 3, -1.13, z + 0.47), m=rail))
        if f + 1 < floors:
            d = 1 if f % 2 == 0 else -1
            p.append(beam(f"{prefix}Stair{f}", (x - d * width * 0.4, -0.6, z), (x + d * width * 0.4, -0.6, z + h), 0.7, depth=0.08, m=steel))
    return p


# ---------------------------------------------------------------------------

def build_shell_a():
    """Brick tenement: 4 storeys, the +X top corner collapsed, shops below."""
    reset_scene()
    st = Style(cm("Brick"), cm("BrickDark"), cm("ConcreteLight"), seed=11, soot=cm("Char"))
    W, D, H0, H = 14.0, 10.0, 4.4, 3.6
    x0, x1 = -W / 2, W / 2
    p = storey("G_", x0, x1, D, 0.0, H0, st, bays_per_m=0.22, shop_front=("F",))
    p += shopfront("SA", -3.5, 5.0, 0.0, st, "PAWN", NEON_CYAN)
    p += shopfront("SB", 3.5, 5.0, 0.0, st, "LIQUOR", NEON_PINK, shutter=False)
    z = H0
    cuts = [x1, x1, x1 - 4.5, x1 - 8.0]
    for f in range(3):
        right = cuts[f + 1]
        p += storey(f"S{f}_", x0, right, D, z, H, st, cut_right=right < x1, blown={"F": (1,)} if f == 0 else {})
        if right < cuts[f]:
            p += stubs(f"St{f}", right + 0.6, D, z + 0.15, st, seed=f * 7 + 1)
            p += rubble(f"Rb{f}", ((right + cuts[f]) / 2, 0, z + 0.15), seed=f + 4, count=4, spread=1.2)
        z += H
    p += parapet("Par", x0, cuts[3], D, z + 0.15, st)
    p += water_tank("WT", (x0 + 2.4, 1.5, z + 0.35))
    p += place(fire_escape("FE", 0.0, 4, 0.0, H), (2.0, D / 2, 0), rot_z=math.pi)
    p += graffiti("Tag", "ASHFALL", 0.9, (-3.5, -D / 2 - 0.02, 3.3), NEON_LIME)
    p += place(posters("Post", (0, 0, 1.2), 0.0, seed=3), (0.0, -D / 2 - 0.01, 0))
    csave("city_building_shell_a", [merge("ShellA", p)], budget=8000)


def build_shell_b():
    """Teal plaster block: 3 storeys, the first floor blown out along the front,
    the roof caved in with charred rafters."""
    reset_scene()
    st = Style(cm("PlasterTeal"), cm("ConcreteLight"), cm("Plaster"), seed=23, soot=cm("Char"), lit=0.04)
    W, D, H0, H = 18.0, 10.0, 4.2, 3.6
    x0, x1 = -W / 2, W / 2
    p = storey("G_", x0, x1, D, 0.0, H0, st, bays_per_m=0.22, shop_front=("F",))
    p += shopfront("SA", -5.5, 5.0, 0.0, st, "NOODLES", NEON_AMBER)
    p += shopfront("SB", 0.5, 4.5, 0.0, st, "VIDEO", NEON_VIOLET)
    p += shopfront("SC", 6.0, 4.5, 0.0, st, "24/7", NEON_LIME, shutter=False)
    p += storey("S0_", x0, x1, D, H0, H, st, blown={"F": (1, 2, 3, 4), "R": (1,)})
    p += storey("S1_", x0, x1, D, H0 + H, H, st, blown={"F": (5,)})
    z = H0 + 2 * H + 0.15
    p += [fbox("ParF", (W + 0.3, 0.4, 0.8), (0, -D / 2, z + 0.4), m=st.trim),
          fbox("ParB", (W + 0.3, 0.4, 0.8), (0, D / 2, z + 0.4), m=st.trim),
          fbox("ParL", (0.4, D, 0.8), (x0, 0, z + 0.4), m=st.trim),
          fbox("ParR", (0.4, D, 0.8), (x1, 0, z + 0.4), m=st.trim),
          fbox("RoofA", (W * 0.45, D, 0.2), (x0 + W * 0.225, 0, z + 0.1), m=cm("Asphalt", rough=0.95))]
    # Caved-in half: charred rafters across the hole, one dropped in.
    for k in range(6):
        x = 0.8 + k * 1.4
        p.append(beam(f"Raft{k}", (x, -D / 2 + 0.3, z + 0.05), (x + 0.3, D / 2 - 0.3, z - (0.9 if k == 3 else 0.05)), 0.22, m=cm("Char")))
    p += [fbox("Billboard", (6.0, 0.2, 2.6), (x0 + 4.0, 1.0, z + 3.4), m=cm("Cream", rough=0.8)),
          text("BillTxt", "SMILE CITY", 0.6, 0.04, (x0 + 4.0, 0.88, z + 3.6), m=cm("Pink")),
          text("BillTxt2", "it's a great day!", 0.3, 0.04, (x0 + 4.0, 0.88, z + 2.9), m=cm("Teal"))]
    for k in range(3):
        p.append(fbox(f"BillLeg{k}", (0.15, 0.15, 2.2), (x0 + 1.5 + k * 2.5, 1.2, z + 1.1), m=cm("SteelDark")))
    p += graffiti("Tag", "WE WERE HERE", 0.5, (6.0, -D / 2 - 0.02, H0 + H * 1.5), NEON_PINK)
    csave("city_building_shell_b", [merge("ShellB", p)], budget=8000)


def build_shell_c():
    """Concrete offices: 6 storeys with ribbon windows; the top floors torn away
    towards +X, a slab hanging off the break."""
    reset_scene()
    st = Style(cm("ConcreteWarm"), cm("GlassDark", rough=0.2, metal=0.3), cm("ConcreteLight"), seed=37, lit=0.05, shard=0.45, boarded=0.0)
    W, D, H0, H = 16.0, 12.0, 4.4, 3.5
    x0, x1 = -W / 2, W / 2
    p = storey("G_", x0, x1, D, 0.0, H0, st, bays_per_m=0.25, shop_front=("F",))
    p += [box("Lobby", (6.0, 0.4, 0.8), (0, -D / 2 - 0.3, 3.7), bevel=0.04, segs=1, m=cm("Soot")),
          text("LobbyTxt", "MERIDIAN", 0.5, 0.05, (0, -D / 2 - 0.52, 3.7), m=steady("#e9e4dc", 1.6))]
    cuts = [x1, x1, x1, x1 - 3.0, x1 - 6.5, x1 - 9.5, x1 - 11.0]
    z = H0
    for f in range(5):
        right = cuts[f + 1]
        p += storey(f"S{f}_", x0, right, D, z, H, st, cut_right=right < x1, blown={"B": (2, 3)} if f == 1 else {}, bays_per_m=0.38)
        if right < cuts[f]:
            p += stubs(f"St{f}", right + 0.6, D, z + 0.15, st, seed=f * 5 + 3)
        z += H
    p += parapet("Par", x0, cuts[5], D, z + 0.15, st)
    # The slab of a torn-off floor hanging down from the break.
    hang = fbox("Hang", (3.2, D - 1.0, 0.3), (0, 0, 0), m=st.slab)
    hang.rotation_euler = (0, math.radians(-55), 0)
    hang.location = (x1 - 1.0, 0, H0 + 3 * H - 1.0)
    p.append(hang)
    p += rebar("HangRb", (x1 - 2.0, 0, H0 + 3 * H + 0.2), (0.6, 0, -0.4), 1.0, 6, (0, 1.5, 0), seed=9)
    p += rubble("Rub", (x1 - 1.5, -D / 2 - 1.2, 0), seed=7, count=6, spread=1.6)
    for k in range(2):
        p.append(fbox(f"Mast{k}", (0.12, 0.12, 4.0), (x0 + 1.5 + k * 1.2, 2.0, z + 2.2), m=cm("SteelDark")))
    p.append(lamp("MastLamp", 0.12, (x0 + 1.5, 2.0, z + 4.25), NEON_RED, strength=4.0))
    csave("city_building_shell_c", [merge("ShellC", p)], budget=8000)


def build_corner():
    """Corner block, 14 x 14 m, 4 storeys: street faces on -Y and -X meeting at a
    chamfered corner with the DINER entrance; the other faces plainer."""
    reset_scene()
    st = Style(cm("PlasterPink"), cm("Plaster"), cm("Cream"), seed=41, soot=cm("Char"), lit=0.07)
    S, H0, H = 14.0, 4.4, 3.6
    p = storey("G_", -S / 2, S / 2, S, 0.0, H0, st, bays_per_m=0.22, shop_front=("F", "L"))
    z = H0
    for f in range(3):
        p += storey(f"S{f}_", -S / 2, S / 2, S, z, H, st, blown={"L": (2,)} if f == 1 else {})
        z += H
    p += parapet("Par", -S / 2, S / 2, S, z + 0.15, st)
    # Chamfered corner: a diagonal block over the -X -Y corner with the entrance.
    c = (-S / 2 + 1.2, -S / 2 + 1.2)
    corner = [box("CornerBlock", (3.6, 0.6, z + 0.9), (0, 0, (z + 0.9) / 2), bevel=0.05, segs=1, m=st.trim),
              fbox("Door", (2.0, 0.1, 2.6), (0, -0.32, 1.3), m=cm("Interior")),
              box("CornerSign", (3.2, 0.4, 0.9), (0, -0.55, 3.6), bevel=0.04, segs=1, m=cm("Soot")),
              text("CornerTxt", "DINER", 0.6, 0.06, (0, -0.78, 3.58), m=neon(NEON_RED, 3.6)),
              fbox("Step", (2.6, 0.8, 0.15), (0, -0.6, 0.075), m=cm("ConcreteLight"))]
    for k in range(3):
        corner.append(fbox(f"CornerWin{k}", (1.4, 0.08, 1.7), (0, -0.31, H0 + 1.75 + k * H), m=st.inner if k != 1 else st.glow))
    p += place(corner, (c[0] - 0.4, c[1] - 0.4, 0), rot_z=math.radians(-45))
    # Shops along both street faces.
    p += shopfront("FA", 2.0, 5.0, 0.0, st, "LAUNDRY", NEON_CYAN)
    p += place(shopfront("LA", 2.0, 5.0, 0.0, st, "RECORDS", NEON_LIME, shutter=False), (-S / 2, 0, 0), rot_z=-math.pi / 2)
    p += water_tank("WT", (3.0, 3.0, z + 0.35))
    p += graffiti("Tag", "NO ONE LEFT", 0.55, (4.0, -S / 2 - 0.02, H0 + 1.8), NEON_PINK)
    csave("city_building_corner", [merge("Corner", p)], budget=8000)


def build_skyscraper():
    """Snapped tower for the skyline (~78 m): glass core in a grid of fins and
    floor bands; the top section broken off and leaning, fire at the break."""
    reset_scene()
    S = 16.0
    glass = cm("GlassDark", rough=0.2, metal=0.4)
    fin, band = cm("ConcreteLight"), cm("Concrete")
    rng = random.Random(77)
    p = [box("Plinth", (S + 4, S + 4, 6.0), (0, 0, 3.0), bevel=0.1, segs=1, m=cm("ConcreteDark")),
         text("PlinthTxt", "AXIOM TOWER", 1.2, 0.1, (0, -(S + 4) / 2 - 0.06, 4.2), m=steady("#e9e4dc", 1.4))]

    def section(prefix, z0, z1, broken_top=False):
        out = [fbox(prefix + "Core", (S - 0.6, S - 0.6, z1 - z0), (0, 0, (z0 + z1) / 2), m=glass)]
        h = z1 - z0
        for side in range(4):
            rz = side * math.pi / 2
            parts = []
            for k in range(9):
                x = -S / 2 + k * S / 8
                fh = h if not broken_top else h - rng.uniform(0.0, 6.0)
                parts.append(fbox(f"{prefix}Fin{side}{k}", (0.45, 0.5, fh), (x, -S / 2, z0 + fh / 2), m=fin))
            nb = int(h / 4.0)
            for k in range(nb):
                parts.append(fbox(f"{prefix}Band{side}{k}", (S, 0.4, 0.6), (0, -S / 2 - 0.05, z0 + 2.0 + k * 4.0), m=band))
            for k in range(6):
                x = -S / 2 + 1.0 + rng.randint(0, 7) * S / 8
                zz = z0 + 3.0 + rng.randint(0, max(0, nb - 2)) * 4.0
                parts.append(fbox(f"{prefix}Lit{side}{k}", (1.6, 0.1, 1.6), (x, -S / 2 + 0.25, zz), m=steady(LAMP_WARM if k % 3 else NEON_CYAN, 2.0)))
            out += place(parts, (0, 0, 0), rot_z=rz)
        return out

    p += section("A", 6.0, 54.0, broken_top=True)
    top = section("T", 0.0, 18.0)
    top += [fbox("Crown", (S - 2, S - 2, 2.5), (0, 0, 19.0), m=cm("ConcreteDark")),
            cyl("Spire", 0.3, 8.0, (2.0, 2.0, 24.0), segs=6, bevel=0.0, m=cm("SteelLight", metal=0.6)),
            lamp("Beacon", 0.35, (2.0, 2.0, 28.2), NEON_RED, strength=5.0)]
    xform(top, (3.5, 1.0, 50.6), (math.radians(6), math.radians(-13), math.radians(5)))
    p += top
    # The break: steel frame sticking out, fire glow in the gutted floors.
    for k in range(10):
        a = math.tau * k / 10
        x0, y0 = math.cos(a) * S * 0.45, math.sin(a) * S * 0.45
        p.append(beam(f"Frame{k}", (x0, y0, 53.5), (x0 * 1.05, y0 * 1.05, 54.5 + rng.uniform(0.5, 3.0)), 0.3, m=cm("Rust", metal=0.4)))
    p += [box("Gut", (S - 1.2, S - 1.2, 2.8), (0, 0, 52.0), bevel=0.0, m=fire_m()),
          box("Gut2", (S - 1.2, S - 1.2, 2.0), (0, 0, 46.0), bevel=0.0, m=ember_m())]
    for side in range(4):
        p += place([fbox(f"Hole{side}", (6.0, 0.6, 3.5), (rng.uniform(-3, 3), -S / 2 - 0.02, 52.0), m=fire_m())], rot_z=side * math.pi / 2)
    csave("city_skyscraper_broken", [merge("Skyscraper", p), socket("Fire", (0, -S / 2, 53.0)), socket("Fire2", (S / 2, 0, 47.0))], budget=8000)


def build_radio_tower():
    """45 m triangular lattice mast on a concrete plinth: platforms, dish
    antennas, red beacons; the top 8 m bent over."""
    reset_scene()
    steel = cm("Red", rough=0.5, metal=0.3)
    white = cm("White", rough=0.5, metal=0.2)
    p = [box("Plinth", (5.0, 5.0, 1.2), (0, 0, 0.6), bevel=0.06, segs=1, m=cm("ConcreteDark")),
         box("Hut", (3.0, 2.4, 2.6), (4.2, 1.0, 1.3), bevel=0.05, segs=1, m=cm("Concrete")),
         fbox("HutDoor", (1.0, 0.06, 2.0), (3.6, -0.23, 1.0), m=cm("SteelDark")),
         text("HutTxt", "KWLA", 0.5, 0.04, (4.2, -0.24, 2.25), m=cm("Red"))]
    p += place(hazard("HutHaz", 3.0, 0.3, stripe=0.4), (4.2, -0.22, 0.2))
    width = 1.8
    sections = [(1.2, 13.0), (13.0, 25.0), (25.0, 37.0)]
    for i, (z0, z1) in enumerate(sections):
        w = width * (1.0 - 0.18 * i)
        lat = lattice(f"L{i}", z1 - z0, w, steel if i % 2 == 0 else white, rod=0.09, steps=7)
        p += place(lat, (0, 0, z0))
        p.append(cyl(f"Deck{i}", w * 1.4, 0.12, (0, 0, z1), segs=3, bevel=0.0, m=cm("SteelDark")))
        p.append(lamp(f"Beacon{i}", 0.2, (w * 0.9, 0, z1 + 0.25), NEON_RED, strength=5.0))
    # Bent top: the last section kinked over.
    top = lattice("Top", 8.0, width * 0.4, white, rod=0.07, steps=5)
    xform(top, (0, 0, 37.0), (math.radians(38), 0, math.radians(20)))
    p += top
    p.append(lamp("TopBeacon", 0.28, (1.6, -4.3, 43.2), NEON_RED, strength=6.0))
    for k, (z, a) in enumerate(((18.0, 0.4), (30.0, 2.6))):
        dish = [cyl(f"Dish{k}", 1.1, 0.35, (0, -1.6, 0), rot=(math.pi / 2, 0, 0), segs=12, bevel=0.0, m=cm("White", rough=0.4), radius_top=0.3),
                fbox(f"DishArm{k}", (0.15, 1.2, 0.15), (0, -0.8, 0), m=cm("SteelDark"))]
        p += place(dish, (0, 0, z), rot_z=a)
    p += [beam("GuyA", (0.6, 0, 12.0), (7.0, -6.0, 0.2), 0.04, m=cm("SteelLight")),
          beam("GuyB", (-0.6, 0, 12.0), (-7.5, -4.0, 0.2), 0.04, m=cm("SteelLight")),
          beam("GuyC", (0, 0.6, 12.0), (-1.0, 8.5, 0.2), 0.04, m=cm("SteelLight"))]
    for k, (x, y) in enumerate(((7.0, -6.0), (-7.5, -4.0), (-1.0, 8.5))):
        p.append(box(f"Anchor{k}", (0.8, 0.8, 0.5), (x, y, 0.25), bevel=0.04, segs=1, m=cm("ConcreteDark")))
    csave("city_radio_tower", [merge("RadioTower", p)], budget=8000)


def lattice(prefix, height, width, m, rod=0.05, steps=None):
    """Triangular lattice mast along +Z, base at the origin (box members)."""
    steps = steps or max(4, int(height / 0.9))
    out = []
    corners = [(math.cos(a) * width, math.sin(a) * width) for a in (math.pi / 2, math.pi / 2 + math.tau / 3, math.pi / 2 + 2 * math.tau / 3)]
    for i, (cx, cy) in enumerate(corners):
        out.append(fbox(f"{prefix}Leg{i}", (rod * 2, rod * 2, height), (cx, cy, height / 2), m=m))
    for s in range(steps):
        z0 = height * s / steps
        z1 = height * (s + 1) / steps
        for i in range(3):
            a = corners[i]
            b = corners[(i + 1) % 3]
            p0 = (a[0], a[1], z0) if s % 2 == 0 else (b[0], b[1], z0)
            p1 = (b[0], b[1], z1) if s % 2 == 0 else (a[0], a[1], z1)
            out.append(beam(f"{prefix}Br{s}_{i}", p0, p1, rod * 1.2, m=m))
            out.append(beam(f"{prefix}Ri{s}_{i}", (a[0], a[1], z1), (b[0], b[1], z1), rod, m=m))
    return out


BUILDERS = {
    "shell_a": build_shell_a,
    "shell_b": build_shell_b,
    "shell_c": build_shell_c,
    "corner": build_corner,
    "skyscraper": build_skyscraper,
    "radio_tower": build_radio_tower,
}

if __name__ == "__main__":
    run(BUILDERS)
