"""Building and furniture props for Tidal Tunnels (Abyss Aquarium).

Each function builds one prop in a fresh scene and writes
art/blender/<name>.blend + art/models/<name>.glb. Front faces -Y (Godot +Z),
origin at the centre of the base unless noted.

    aqua_bench, aqua_bin, aqua_signpost, aqua_info_kiosk, aqua_exit_sign
    aqua_jelly_column      floor-to-ceiling jelly tank frame (glass in-engine)
    aqua_touch_pool        oval touch pool with rocks, stars and urchins
    aqua_gift_shop         17 m shopfront with a stocked interior behind glass
    aqua_staff_door        open staff door with STAFF ONLY plaque and red beacon
    aqua_elevator          open service elevator with a lit car
    aqua_loading_door      half-raised roller door with hazard stripes, crates
    aqua_filtration        filtration-room doorway and pump room interior
    aqua_tunnel_rib        2.5 m module of the acrylic shark tunnel (axis = X)
    aqua_tunnel_mouth      heavy end frame for the tunnel, with signage
    aqua_pillar            9 m rotunda column with wave bands and a light strip
    aqua_glass_rail        3 m glass balustrade for the mezzanine
    aqua_pendant           hanging porthole lamp
    aqua_porthole          round wall-tank window frame
    aqua_duct              4 m ceiling duct with hangers
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aqua_common import *  # noqa: F401,F403


def build_bench():
    reset_scene()
    navy, teal, cream = amat("NavyLight", rough=0.5), amat("Teal", rough=0.6), amat("Cream", rough=0.6)
    wave = [(x * 0.05, 0.15 + 0.07 * math.sin(x * 0.6)) for x in range(-6, 7)]
    leg_outline = [(-0.32, 0.0), (0.32, 0.0), (0.32, 0.44), (0.0, 0.44), (-0.32, 0.44)]
    parts = [
        box("Seat", (2.4, 0.66, 0.16), (0, 0, 0.44), bevel=0.06, segs=3, m=navy),
        box("Cushion", (2.3, 0.58, 0.1), (0, 0, 0.56), bevel=0.05, segs=3, m=teal),
        box("Plaque", (0.5, 0.02, 0.1), (0, -0.335, 0.44), bevel=0.01, m=cream),
    ]
    for i, x in enumerate((-0.95, 0.95)):
        parts.append(prism(f"Leg{i}", leg_outline, 0.12, (x, 0, 0), rot=rad(0, 0, 90), m=navy, bevel=0.03))
        parts.append(box(f"Foot{i}", (0.16, 0.7, 0.05), (x, 0, 0.025), bevel=0.02, m=amat("Dark", rough=0.5)))
    for i in range(3):
        parts.append(box(f"Stitch{i}", (0.02, 0.5, 0.012), (-0.75 + i * 0.75, 0, 0.615), bevel=0.0, m=amat("TealDark", rough=0.6)))
    save("aqua_bench", [merge("Bench", parts)])


def build_bin():
    reset_scene()
    navy, teal, orange = amat("NavyLight", rough=0.5), amat("Teal", rough=0.5), amat("Orange", rough=0.5)
    parts = [
        cyl("Body", 0.3, 0.9, (0, 0, 0.45), segs=18, bevel=0.06, m=navy),
        cyl("Band", 0.31, 0.14, (0, 0, 0.62), segs=18, bevel=0.02, m=teal),
        cyl("Lid", 0.33, 0.12, (0, 0, 0.96), segs=18, bevel=0.05, m=teal, radius_top=0.26),
        cyl("Slot", 0.16, 0.03, (0, 0, 1.025), segs=12, bevel=0.0, m=amat("Dark", rough=0.5)),
        # A little orange fish decal on the front.
        sphere("FishBody", 0.08, (0, -0.305, 0.4), scale=(1.4, 0.2, 0.8), m=orange, segs=10, rings=6),
        prism("FishTail", [(0.0, 0.0), (0.09, 0.07), (0.09, -0.07)], 0.02, (0.1, -0.31, 0.4), m=orange),
    ]
    save("aqua_bin", [merge("Bin", parts)])


def build_signpost():
    """Wayfinding totem; the level adds the text with Label3D on the panel face (z 2.2-3.0).
    The panel starts above head height (1.8 m), so walking past never clips it."""
    reset_scene()
    navy, steel, teal = amat("Navy", rough=0.5), amat("SteelDark", rough=0.4, metal=0.5), amat("Teal", rough=0.5)
    cyan = aglow("SignEdge", "Cyan", 2.2)
    parts = [
        box("Base", (0.7, 0.4, 0.12), (0, 0, 0.06), bevel=0.04, m=steel),
        box("Post", (0.14, 0.14, 2.1), (0, 0, 1.15), bevel=0.03, m=steel),
        box("Panel", (1.3, 0.12, 0.95), (0, 0, 2.6), bevel=0.05, m=navy),
        box("Header", (1.32, 0.13, 0.16), (0, 0, 3.12), bevel=0.04, m=teal),
        box("GlowF", (1.2, 0.02, 0.03), (0, -0.065, 2.15), bevel=0.0, m=cyan),
        box("GlowB", (1.2, 0.02, 0.03), (0, 0.065, 2.15), bevel=0.0, m=cyan),
    ]
    save("aqua_signpost", [merge("Signpost", parts)])


def build_info_kiosk():
    reset_scene()
    navy, steel = amat("NavyLight", rough=0.5), amat("SteelDark", rough=0.4, metal=0.5)
    screen = aglow("KioskScreen", "#123a6b", 1.2)
    fish_o, fish_y, fish_p = aglow("InfoFishA", "Orange", 2.0), aglow("InfoFishB", "Yellow", 2.0), aglow("InfoFishC", "Pink", 2.0)
    cyan = aglow("InfoText", "Cyan", 2.0)
    parts = [
        box("Foot", (0.8, 0.5, 0.1), (0, 0, 0.05), bevel=0.04, m=steel),
        box("Stand", (0.5, 0.2, 1.0), (0, 0.05, 0.6), bevel=0.06, m=navy),
        box("Frame", (1.05, 0.16, 1.5), (0, 0, 1.75), rot=rad(-8, 0, 0), bevel=0.07, m=navy),
        box("Screen", (0.92, 0.02, 1.32), (0, -0.09, 1.75), rot=rad(-8, 0, 0), bevel=0.0, m=screen),
    ]
    # Glowing infographic: three fish and text bars.
    for i, (x, z, m) in enumerate(((-0.2, 2.15, fish_o), (0.2, 1.85, fish_y), (-0.15, 1.55, fish_p))):
        f = [sphere(f"Fish{i}", 0.09, (x, -0.105, z), scale=(1.5, 0.15, 0.85), m=m, segs=10, rings=6),
             prism(f"Tail{i}", [(0.0, 0.0), (0.1, 0.08), (0.1, -0.08)], 0.015, (x + 0.12, -0.105, z), m=m)]
        for ob in f:
            ob.matrix_world = Matrix.Rotation(math.radians(-8), 4, "X") @ ob.matrix_basis
        parts += f
    for i in range(4):
        bar = box(f"Bar{i}", (0.5 - 0.08 * (i % 2), 0.01, 0.035), (0.1, -0.105, 1.3 - i * 0.07), bevel=0.0, m=cyan)
        bar.matrix_world = Matrix.Rotation(math.radians(-8), 4, "X") @ bar.matrix_basis
        parts.append(bar)
    save("aqua_info_kiosk", [merge("InfoKiosk", parts)])


def build_exit_sign():
    reset_scene()
    dark = amat("Dark", rough=0.5)
    green = aglow("ExitGreen", "Green", 3.0)
    white = aglow("ExitWhite", "#eafff0", 2.0)
    parts = [
        box("Box", (0.9, 0.12, 0.34), (0, 0, 0.17), bevel=0.03, m=dark),
        box("Face", (0.82, 0.02, 0.26), (0, -0.06, 0.17), bevel=0.0, m=green),
        text("Text", "EXIT", 0.17, 0.02, (0.06, -0.075, 0.16), m=white),
        prism("Arrow", [(-0.1, 0.0), (0.0, 0.07), (0.0, 0.03), (0.08, 0.03), (0.08, -0.03), (0.0, -0.03), (0.0, -0.07)], 0.02,
              (-0.28, -0.075, 0.17), m=white),
    ]
    save("aqua_exit_sign", [merge("ExitSign", parts)])


def build_jelly_column(height=6.5):
    """Base and cap of a floor-to-ceiling jelly tank. Glass radius 0.9 between z 0.7 and height - 0.6."""
    reset_scene()
    navy, brass = amat("Navy", rough=0.5), amat("Brass", rough=0.35, metal=0.6)
    violet = aglow("JellyRing", "#b45cff", 3.0)
    pink = aglow("JellyDown", "#ff6ad5", 2.6)
    parts = [
        cyl("Base", 1.1, 0.7, (0, 0, 0.35), segs=32, bevel=0.08, m=navy),
        cyl("BaseRing", 1.12, 0.07, (0, 0, 0.55), segs=32, bevel=0.0, m=violet),
        torus("BaseLip", 0.93, 0.05, (0, 0, 0.71), m=brass, major_segs=40, minor_segs=6),
        cyl("Floor", 0.9, 0.03, (0, 0, 0.7), segs=32, bevel=0.0, m=amat("VioletDark", rough=0.6)),
        cyl("Cap", 1.1, 0.6, (0, 0, height - 0.3), segs=32, bevel=0.08, m=navy),
        cyl("CapGlow", 0.88, 0.03, (0, 0, height - 0.61), segs=32, bevel=0.0, m=pink),
        torus("CapLip", 0.93, 0.05, (0, 0, height - 0.6), m=brass, major_segs=40, minor_segs=6),
        cyl("CapRing", 1.12, 0.07, (0, 0, height - 0.42), segs=32, bevel=0.0, m=violet),
        box("Plaque", (0.6, 0.04, 0.22), (0, -1.08, 0.38), bevel=0.02, m=amat("Cream", rough=0.6)),
    ]
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        parts.append(cyl(f"Strut{i}", 0.035, height - 1.3, (math.cos(a) * 0.95, math.sin(a) * 0.95, height / 2), segs=8, bevel=0.0, m=brass))
    save("aqua_jelly_column", [merge("JellyColumn", parts)])


def build_touch_pool():
    """Oval pool, 6.4 x 3.8 m, rim 0.78 m high. The water is the 'TouchWater' node."""
    reset_scene()
    stone, stone_d = amat("SlateLight", rough=0.8), amat("Slate", rough=0.85)
    teal = amat("Teal", rough=0.5)
    rockm, rockd = amat("Rock", rough=0.85), amat("RockDark", rough=0.9)
    star_o, star_p, star_y = amat("Coral", rough=0.6), amat("Pink", rough=0.6), amat("Yellow", rough=0.6)
    urchin_m, spike = amat("VioletDark", rough=0.6), amat("Violet", rough=0.5)
    an, an_tip = amat("CoralLight", rough=0.6), aglow("AnTip", "PinkLight", 1.2)
    sx = 1.75
    rim = [
        annulus("Rim", 1.55, 1.9, 0.74, z=0.37, m=stone_d, segs=48, bevel=0.06),
        annulus("RimTop", 1.5, 1.98, 0.1, z=0.78, m=stone, segs=48, bevel=0.04),
        annulus("RimBand", 1.88, 1.93, 0.1, z=0.3, m=teal, segs=48, bevel=0.0),
        cyl("Bed", 1.56, 0.3, (0, 0, 0.15), segs=48, bevel=0.0, m=amat("SandDark", rough=0.9)),
    ]
    for ob in rim:
        ob.scale = (sx, 1.0, 1.0)
    inside = []
    r = rng(12)
    for i in range(7):
        a = math.tau * i / 7
        inside += rock(f"R{i}", (math.cos(a) * 1.0 * sx, math.sin(a) * 0.95, 0.3), 0.35 + 0.1 * (i % 3), (rockm, rockd)[i % 2], seed=i)
    for i in range(6):
        a = math.tau * i / 6 + 0.4
        inside += starfish(f"S{i}", (math.cos(a) * 0.9 * sx, math.sin(a) * 0.6, 0.48), 0.14, (star_o, star_p, star_y)[i % 3], yaw=a)
    for i in range(3):
        inside += urchin(f"U{i}", (-1.6 + i * 1.6, 0.25 * (-1) ** i, 0.42), 0.11, urchin_m, spike)
    for i in range(3):
        inside += anemone(f"A{i}", (-1.0 + i * 1.1, -0.45 + 0.4 * (i % 2), 0.32), 0.18, an, an_tip, seed=i)
    water = cyl("TouchWater", 1.56, 0.02, (0, 0, 0.6), segs=48, bevel=0.0, m=aglow("TouchWaterMat", "#2ec7d8", 0.6))
    water.scale = (sx, 1.0, 1.0)
    sign = [
        box("SignPost", (0.08, 0.08, 0.5), (0, -2.05, 0.95), bevel=0.02, m=amat("SteelDark", rough=0.4, metal=0.5)),
        box("SignBoard", (1.1, 0.06, 0.34), (0, -2.08, 1.25), rot=rad(-20, 0, 0), bevel=0.03, m=amat("SubYellow", rough=0.5)),
        text("SignText", "TOUCH POOL", 0.12, 0.02, (0, -2.12, 1.26), rot=(-math.radians(20), 0, 0), m=amat("Navy", rough=0.5)),
    ]
    save("aqua_touch_pool", [merge("TouchPool", rim + inside + sign), merge("TouchWater", [water])])


def _plush_shark(prefix, loc, s, m_body, m_belly, dark):
    p = [sphere(prefix + "B", 0.3 * s, loc, scale=(1.6, 0.9, 0.85), m=m_body, segs=10, rings=7),
         sphere(prefix + "Bl", 0.27 * s, (loc[0], loc[1] - 0.05 * s, loc[2] - 0.06 * s), scale=(1.5, 0.85, 0.6), m=m_belly, segs=10, rings=6),
         cyl(prefix + "F", 0.1 * s, 0.24 * s, (loc[0], loc[1], loc[2] + 0.32 * s), segs=6, bevel=0.0, m=m_body, radius_top=0.01),
         cyl(prefix + "T", 0.1 * s, 0.24 * s, (loc[0] + 0.52 * s, loc[1], loc[2] + 0.05 * s), rot=rad(0, 70, 0), segs=6, bevel=0.0,
             m=m_body, radius_top=0.01)]
    for k in (-1, 1):
        p.append(sphere(f"{prefix}E{k}", 0.035 * s, (loc[0] - 0.32 * s, loc[1] - 0.2 * s * k * 0 - 0.22 * s, loc[2] + 0.06 * s + 0.02 * k),
                        m=dark, segs=6, rings=4))
    return p


def _plush_octo(prefix, loc, s, m, dark):
    p = [sphere(prefix + "H", 0.26 * s, (loc[0], loc[1], loc[2] + 0.1 * s), m=m, segs=10, rings=7)]
    for i in range(6):
        a = math.tau * i / 6
        p.append(sphere(f"{prefix}L{i}", 0.09 * s, (loc[0] + math.cos(a) * 0.2 * s, loc[1] + math.sin(a) * 0.2 * s, loc[2] - 0.1 * s), m=m, segs=6, rings=4))
    for k in (-1, 1):
        p.append(sphere(f"{prefix}E{k}", 0.04 * s, (loc[0] + 0.09 * s * k, loc[1] - 0.23 * s, loc[2] + 0.14 * s), m=dark, segs=6, rings=4))
    return p


def _plush_whale(prefix, loc, s, m, belly):
    return [sphere(prefix + "B", 0.32 * s, loc, scale=(1.7, 1.0, 0.9), m=m, segs=10, rings=7),
            sphere(prefix + "Bl", 0.28 * s, (loc[0] - 0.05 * s, loc[1], loc[2] - 0.1 * s), scale=(1.5, 0.9, 0.55), m=belly, segs=10, rings=6),
            prism(prefix + "T", [(0.0, 0.0), (0.25 * s, 0.18 * s), (0.18 * s, 0.0), (0.25 * s, -0.18 * s)], 0.05 * s,
                  (loc[0] + 0.5 * s, loc[1], loc[2] + 0.1 * s), rot=rad(90, 0, 0), m=m)]


def build_gift_shop():
    """Shopfront 17 m wide x 3.2 m tall; the interior (4.4 m deep) is behind it (+Y).
    The 2.8 m door opening is centred on x = 0."""
    reset_scene()
    navy, teal, cream = amat("NavyLight", rough=0.5), amat("Teal", rough=0.5), amat("Cream", rough=0.6)
    pink, yellow, orange = amat("Pink", rough=0.55), amat("SubYellow", rough=0.5), amat("Orange", rough=0.55)
    dark, steel = amat("Dark", rough=0.5), amat("SteelDark", rough=0.4, metal=0.5)
    wood = amat("ShelfWood", "#b77a4f", rough=0.7)
    glass = mat("ShopGlass", "#bff3ff", rough=0.05)
    glass.blend_method = "BLEND" if hasattr(glass, "blend_method") else None
    bsdf = next(n for n in glass.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Alpha"].default_value = 0.18
    glass.diffuse_color = (0.75, 0.95, 1.0, 0.18)
    sign_pink = aglow("ShopSignPink", "#ff5fc0", 3.0)
    sign_yellow = aglow("ShopSignYellow", "#ffd65a", 2.6)
    light = aglow("ShopLight", "#fff1d0", 2.2)
    W, H, D = 17.0, 3.2, 4.4
    front = [
        box("Sill", (W, 0.3, 0.5), (0, 0, 0.25), bevel=0.04, m=navy),
        box("Fascia", (W + 0.3, 0.45, 0.62), (0, -0.05, H - 0.31), bevel=0.06, m=teal),
        box("FasciaTrim", (W + 0.34, 0.47, 0.08), (0, -0.05, H - 0.64), bevel=0.02, m=yellow),
        text("Sign", "GIFT SHOP", 0.5, 0.08, (0, -0.32, H - 0.3), m=sign_pink),
        star("SignStarL", 0.22, 0.06, (-2.2, -0.31, H - 0.3), m=sign_yellow, bevel=0.01),
        star("SignStarR", 0.22, 0.06, (2.2, -0.31, H - 0.3), m=sign_yellow, bevel=0.01),
        box("GlassL", (6.6, 0.04, 2.0), (-5.1, 0.02, 1.5), bevel=0.0, m=glass),
        box("GlassR", (6.6, 0.04, 2.0), (5.1, 0.02, 1.5), bevel=0.0, m=glass),
        box("Mull_L", (0.12, 0.12, 2.0), (-5.1, 0, 1.5), bevel=0.02, m=steel),
        box("Mull_R", (0.12, 0.12, 2.0), (5.1, 0, 1.5), bevel=0.02, m=steel),
        box("Transom", (W, 0.14, 0.1), (0, 0, 2.5), bevel=0.02, m=steel),
    ]
    for i, x in enumerate((-W / 2 + 0.25, -1.6, 1.6, W / 2 - 0.25)):
        front.append(box(f"Pillar{i}", (0.5 if abs(x) > 2 else 0.4, 0.4, H - 0.6), (x, 0, (H - 0.6) / 2), bevel=0.06, m=navy))
        front.append(box(f"PillarBand{i}", (0.52 if abs(x) > 2 else 0.42, 0.42, 0.1), (x, 0, 1.2), bevel=0.02, m=teal))
    # Scalloped awning under the fascia (a callback to the prize kiosk).
    for i in range(34):
        x = -W / 2 + 0.25 + i * 0.5
        front.append(cyl(f"Scallop{i:02d}", 0.25, 0.08, (x, -0.3, H - 0.66), rot=rad(90, 0, 0), segs=12, bevel=0.02,
                         m=cream if i % 2 else pink))
    # Interior shell.
    inner = [
        box("Floor", (W - 0.6, D, 0.04), (0, D / 2, 0.02), bevel=0.0, m=amat("ShopFloor", "#2a3d63", rough=0.6)),
        box("BackWall", (W, 0.2, H), (0, D, H / 2), bevel=0.0, m=amat("ShopWall", "#25528a", rough=0.7)),
        box("Ceil", (W, D, 0.12), (0, D / 2, H - 0.36), bevel=0.0, m=amat("ShopCeil", "#16264a", rough=0.7)),
        box("SideL", (0.2, D, H), (-W / 2 + 0.1, D / 2, H / 2), bevel=0.0, m=amat("ShopWall", "#25528a", rough=0.7)),
        box("SideR", (0.2, D, H), (W / 2 - 0.1, D / 2, H / 2), bevel=0.0, m=amat("ShopWall", "#25528a", rough=0.7)),
    ]
    for i in range(4):
        inner.append(box(f"Light{i}", (2.6, 0.3, 0.04), (-6 + i * 4, D * 0.5, H - 0.43), bevel=0.0, m=light))
    # Shelving along the back wall and two display tables, stocked with plush.
    blue, white, grey = amat("PlushBlue", "#3a7be0", rough=0.8), amat("White", rough=0.7), amat("PlushGrey", "#7d8ba6", rough=0.8)
    octo_m, whale_m = amat("PlushPink", "PinkLight", rough=0.8), amat("PlushNavy", "#2b4f9e", rough=0.8)
    for side in (-1, 1):
        x0 = side * 5.0
        inner.append(box(f"ShelfBack{side}", (5.6, 0.5, 2.5), (x0, D - 0.35, 1.25), bevel=0.03, m=wood))
        for k in range(3):
            z = 0.55 + k * 0.72
            inner.append(box(f"Shelf{side}_{k}", (5.6, 0.6, 0.06), (x0, D - 0.42, z), bevel=0.01, m=cream))
            for j in range(6):
                x = x0 - 2.3 + j * 0.92
                loc = (x, D - 0.5, z + 0.22)
                kind = (j + k + (side > 0)) % 3
                if kind == 0:
                    inner += _plush_shark(f"PS{side}{k}{j}", loc, 0.7, grey, white, dark)
                elif kind == 1:
                    inner += _plush_octo(f"PO{side}{k}{j}", loc, 0.8, octo_m, dark)
                else:
                    inner += _plush_whale(f"PW{side}{k}{j}", loc, 0.7, whale_m, white)
        inner.append(box(f"Table{side}", (2.2, 1.0, 0.8), (side * 4.6, 1.6, 0.4), bevel=0.05, m=wood))
        for j in range(3):
            inner += _plush_shark(f"TS{side}{j}", (side * 4.6 - 0.7 + j * 0.7, 1.6, 0.98), 0.9, blue, white, dark)
    # Big hanging shark over the doorway inside.
    inner += _plush_shark("Hang", (0, 2.4, 2.3), 2.2, grey, white, dark)
    inner.append(cyl("HangWire", 0.01, 0.4, (0, 2.4, 2.75), segs=4, bevel=0.0, m=steel))
    # Counter by the door.
    inner += [box("Counter", (1.8, 0.7, 1.0), (-2.8, 2.6, 0.5), bevel=0.05, m=orange),
              box("CounterTop", (1.9, 0.8, 0.06), (-2.8, 2.6, 1.03), bevel=0.02, m=cream),
              box("Register", (0.4, 0.3, 0.28), (-2.6, 2.6, 1.2), bevel=0.04, m=dark)]
    save("aqua_gift_shop", [merge("GiftShop", front + inner)])


def build_staff_door():
    """Wall unit 3.2 m wide x 3.4 m tall with a 2.2 x 2.6 m opening; the door swings in (+Y)."""
    reset_scene()
    navy, steel, grey = amat("Navy", rough=0.5), amat("SteelDark", rough=0.4, metal=0.5), amat("DoorGrey", "#8292ab", rough=0.5)
    yellow, dark = amat("SubYellow", rough=0.5), amat("Dark", rough=0.5)
    red = glow("Beacon", "#ff3040", 4.0)
    parts = frame_rect("Frame", 2.2, 2.6, 0.36, 0.16, (0, 0, 0), steel)
    # Double doors swung open into the back corridor, hinged on the jambs.
    for side in (-1, 1):
        leaf = [
            box(f"Door{side}", (1.08, 0.07, 2.5), (0, 0, 1.27), bevel=0.02, m=grey),
            box(f"Kick{side}", (1.04, 0.08, 0.25), (0, 0, 0.14), bevel=0.01, m=steel),
            box(f"Window{side}", (0.3, 0.08, 0.5), (0, 0, 1.75), bevel=0.02, m=aglow("DoorWin", "#ffb2a0", 0.8)),
            box(f"Bar{side}", (0.8, 0.1, 0.06), (0, -0.06, 1.05), bevel=0.02, m=steel),
        ]
        hinge = (Matrix.Translation((side * 1.1, 0.0, 0.0)) @ Matrix.Rotation(math.radians(-100 * side), 4, "Z")
                 @ Matrix.Translation((-side * 0.55, 0.0, 0.0)))
        for ob in leaf:
            ob.matrix_world = hinge @ ob.matrix_basis
        parts += leaf
    parts += [
        box("Plaque", (0.9, 0.04, 0.3), (0, -0.2, 2.95), bevel=0.02, m=yellow),
        text("PlaqueText", "STAFF ONLY", 0.13, 0.02, (0, -0.225, 2.94), m=dark),
        cyl("BeaconBase", 0.12, 0.08, (0.85, -0.18, 2.9), rot=rad(90, 0, 0), segs=12, bevel=0.02, m=steel),
        bulb("BeaconLamp", 0.1, (0.85, -0.26, 2.9), red),
        box("Floor", (2.2, 3.0, 0.03), (0, 1.5, 0.015), bevel=0.0, m=amat("Concrete", "#4a5466", rough=0.8)),
        box("Hazard", (2.2, 0.15, 0.02), (0, -0.05, 0.02), bevel=0.0, m=yellow),
    ]
    save("aqua_staff_door", [merge("StaffDoor", parts)])


def build_elevator():
    """3.6 m wide wall unit; 2.4 x 2.8 m opening, lit car 2.6 m deep behind it (+Y)."""
    reset_scene()
    steel, chrome, navy = amat("SteelDark", rough=0.35, metal=0.6), amat("Chrome", rough=0.25, metal=0.8), amat("Navy", rough=0.5)
    amber = aglow("FloorDigits", "#ffb030", 3.0)
    light = aglow("CarLight", "#e8fbff", 2.4)
    wall = amat("CarWall", "#7f8ea8", rough=0.4, metal=0.3)
    parts = frame_rect("Frame", 2.4, 2.8, 0.4, 0.22, (0, 0, 0), chrome)
    parts += [
        box("DoorL", (0.3, 0.1, 2.8), (-1.05, 0.1, 1.4), bevel=0.01, m=steel),
        box("DoorR", (0.3, 0.1, 2.8), (1.05, 0.1, 1.4), bevel=0.01, m=steel),
        box("Indicator", (0.9, 0.08, 0.3), (0, -0.2, 3.35), bevel=0.03, m=navy),
        text("Digits", "B2", 0.2, 0.02, (0, -0.25, 3.34), m=amber),
        prism("ArrowUp", [(-0.07, 0.0), (0.07, 0.0), (0.0, 0.1)], 0.02, (-0.32, -0.25, 3.3), m=amber),
        box("CallPanel", (0.18, 0.05, 0.4), (1.55, -0.03, 1.3), bevel=0.02, m=chrome),
        cyl("CallBtn", 0.04, 0.03, (1.55, -0.07, 1.36), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=amber),
        box("CarFloor", (2.4, 2.6, 0.05), (0, 1.5, 0.025), bevel=0.0, m=amat("CarFloorM", "#3a3f4f", rough=0.6)),
        box("CarBack", (2.4, 0.1, 2.8), (0, 2.8, 1.4), bevel=0.0, m=wall),
        box("CarL", (0.1, 2.6, 2.8), (-1.25, 1.5, 1.4), bevel=0.0, m=wall),
        box("CarR", (0.1, 2.6, 2.8), (1.25, 1.5, 1.4), bevel=0.0, m=wall),
        box("CarCeil", (2.4, 2.6, 0.08), (0, 1.5, 2.84), bevel=0.0, m=steel),
        box("CarLight", (1.6, 1.6, 0.03), (0, 1.5, 2.79), bevel=0.0, m=light),
        box("Handrail", (2.2, 0.06, 0.06), (0, 2.7, 0.95), bevel=0.02, m=chrome),
    ]
    save("aqua_elevator", [merge("Elevator", parts)])


def build_loading_door():
    """5.2 m wide wall unit: roller door raised to 2.9 m; dock behind (+Y) with crates."""
    reset_scene()
    steel, grey = amat("SteelDark", rough=0.4, metal=0.5), amat("RollerGrey", "#9aa7bb", rough=0.5, metal=0.3)
    yellow, black = amat("SubYellow", rough=0.5), amat("Dark", rough=0.5)
    amber = glow("Warn", "#ffae2a", 4.0)
    crate, crate_d = amat("Crate", "#c58a4e", rough=0.75), amat("CrateDark", "#8f5d33", rough=0.8)
    blue = amat("Barrel", "#2f6fd6", rough=0.5)
    W, H = 4.6, 3.8
    parts = frame_rect("Frame", W, H, 0.45, 0.3, (0, 0, 0), steel)
    parts += [box("Housing", (W + 0.4, 0.6, 0.55), (0, 0.05, H + 0.1), bevel=0.08, m=steel)]
    # Roller slats from the top down to 2.9 m.
    z = H - 0.1
    k = 0
    while z > 2.95:
        parts.append(box(f"Slat{k:02d}", (W, 0.08, 0.14), (0, 0.15, z), bevel=0.02, m=grey))
        z -= 0.15
        k += 1
    parts.append(box("BottomBar", (W, 0.12, 0.1), (0, 0.15, 2.95), bevel=0.02, m=yellow))
    # Hazard stripes on the jambs and the sill.
    for side in (-1, 1):
        x = side * (W / 2 + 0.15)
        for i in range(8):
            parts.append(box(f"Haz{side}_{i}", (0.32, 0.47, 0.22), (x, 0, 0.2 + i * 0.44), rot=rad(0, 30 * side, 0), bevel=0.0,
                             m=yellow if i % 2 == 0 else black))
        parts.append(bulb(f"Warn{side}", 0.12, (x, -0.3, H + 0.15), amber))
    for i in range(10):
        parts.append(box(f"Sill{i}", (W / 10, 0.3, 0.02), (-W / 2 + W / 20 + i * W / 10, -0.1, 0.01), bevel=0.0,
                         m=yellow if i % 2 == 0 else black))
    parts.append(box("DockFloor", (W, 4.0, 0.04), (0, 2.2, 0.02), bevel=0.0, m=amat("Concrete", "#4a5466", rough=0.8)))
    # Crates and barrels piled inside (to the sides, leaving the middle clear).
    for i, (x, y, s) in enumerate(((-1.7, 2.6, 0.9), (-1.7, 3.5, 0.9), (-1.7, 3.05, 0.75), (1.75, 3.4, 1.0))):
        zz = 0.45 if i != 2 else 1.3
        parts.append(box(f"Crate{i}", (s, s, s), (x, y, zz + (s - 0.9) * 0.5), bevel=0.04, m=crate))
        parts.append(box(f"CrateBand{i}", (s + 0.02, s + 0.02, 0.1), (x, y, zz + (s - 0.9) * 0.5), bevel=0.0, m=crate_d))
    for i in range(2):
        parts.append(cyl(f"Barrel{i}", 0.3, 0.9, (1.4 + i * 0.65, 2.3, 0.45), segs=14, bevel=0.04, m=blue))
    save("aqua_loading_door", [merge("LoadingDoor", parts)])


def build_filtration():
    """Doorway (3 x 3 m) into a 6 x 5 m pump room behind it (+Y)."""
    reset_scene()
    steel, pipe, navy = amat("SteelDark", rough=0.4, metal=0.5), amat("Pipe", "#6c8fb0", rough=0.35, metal=0.5), amat("Navy", rough=0.5)
    green, teal = aglow("SightGlass", "#3dff9a", 2.4), amat("Teal", rough=0.45)
    yellow, red = amat("SubYellow", rough=0.5), amat("Valve", "#e8263a", rough=0.5)
    gauge = amat("Gauge", "#f2f6f8", rough=0.4)
    parts = frame_rect("Frame", 3.0, 3.0, 0.4, 0.2, (0, 0, 0), steel)
    parts += [
        box("Plaque", (1.6, 0.04, 0.3), (0, -0.21, 3.35), bevel=0.02, m=yellow),
        text("PlaqueText", "FILTRATION", 0.15, 0.02, (0, -0.235, 3.34), m=navy),
        box("Floor", (6.0, 5.0, 0.04), (0, 2.6, 0.02), bevel=0.0, m=amat("Grate", "#3d4a5c", rough=0.6, metal=0.4)),
    ]
    # Two big pumps either side, with sight glasses and valves.
    for side in (-1, 1):
        x = side * 2.1
        parts += [
            cyl(f"Pump{side}", 0.75, 2.4, (x, 3.3, 1.2), segs=20, bevel=0.1, m=teal),
            cyl(f"PumpCap{side}", 0.8, 0.2, (x, 3.3, 2.45), segs=20, bevel=0.05, m=steel),
            cyl(f"Sight{side}", 0.16, 1.2, (x - side * 0.68, 3.3 - 0.35, 1.3), segs=10, bevel=0.0, m=green),
            cyl(f"PipeUp{side}", 0.18, 1.8, (x, 3.3, 3.4), segs=12, bevel=0.0, m=pipe),
            tube(f"PipeOver{side}", [(x, 3.3, 4.2), (x, 1.5, 4.2), (x * 0.4, 0.6, 4.2)], 0.18, m=pipe, segs=12),
            cyl(f"Valve{side}", 0.25, 0.06, (x - side * 0.8, 2.6, 1.1), rot=rad(90, 0, 0), segs=12, bevel=0.02, m=red),
            cyl(f"Gauge{side}", 0.15, 0.06, (x, 2.52, 1.9), rot=rad(90, 0, 0), segs=14, bevel=0.02, m=gauge),
            box(f"Needle{side}", (0.02, 0.02, 0.11), (x, 2.48, 1.93), rot=rad(0, 30 * side, 0), bevel=0.0, m=red),
        ]
    # Pipes run out above the door into the hall (along -Y).
    for i, x in enumerate((-0.5, 0.5)):
        parts.append(cyl(f"OutPipe{i}", 0.16, 3.0, (x, -0.8, 4.2), rot=rad(90, 0, 0), segs=12, bevel=0.0, m=pipe))
    save("aqua_filtration", [merge("Filtration", parts)])


TUNNEL_HALF = 3.0      # inner half-width of the walkway (metres)
TUNNEL_SPRING = 1.2    # height where the arch starts
RIB_STEP = 2.5


def arch_points(offset=0.0, steps=16):
    """Tunnel profile in the YZ plane (Blender), from one floor edge to the other."""
    r = TUNNEL_HALF + offset
    pts = [(0.0, -r, 0.0), (0.0, -r, TUNNEL_SPRING)]
    for i in range(1, steps):
        a = math.pi * i / steps
        pts.append((0.0, -math.cos(a) * r, TUNNEL_SPRING + math.sin(a) * r))
    pts += [(0.0, r, TUNNEL_SPRING), (0.0, r, 0.0)]
    return pts


def build_tunnel_rib():
    """One 2.5 m module of the walk-through tunnel; axis along X, rib at x = 0."""
    reset_scene()
    steel, navy = amat("SteelDark", rough=0.35, metal=0.6), amat("Navy", rough=0.5)
    cyan = aglow("TunnelLed", "Cyan", 2.6)
    parts = [tube("Rib", arch_points(0.06), 0.09, m=steel, segs=8, cap=True)]
    for i, (y, z) in enumerate([(p[1], p[2]) for p in arch_points(0.14)[2:-2:3]]):
        parts.append(sphere(f"Bolt{i}", 0.05, (0, y, z), m=steel, segs=6, rings=4))
    for side in (-1, 1):
        y = side * (TUNNEL_HALF + 0.05)
        parts += [
            box(f"Curb{side}", (RIB_STEP, 0.4, 0.32), (RIB_STEP / 2, y - side * 0.1, 0.16), bevel=0.05, m=navy),
            box(f"Led{side}", (RIB_STEP, 0.03, 0.04), (RIB_STEP / 2, y - side * 0.31, 0.26), bevel=0.0, m=cyan),
            box(f"RibFoot{side}", (0.3, 0.5, 0.36), (0, y - side * 0.05, 0.18), bevel=0.05, m=steel),
        ]
    save("aqua_tunnel_rib", [merge("TunnelRib", parts)])


def build_tunnel_mouth():
    """Heavy portal frame at each end of the tunnel (faces -X... built facing -Y, rotate in level)."""
    reset_scene()
    navy, teal, steel = amat("NavyLight", rough=0.5), amat("Teal", rough=0.45), amat("SteelDark", rough=0.35, metal=0.6)
    cyan = aglow("MouthLed", "Cyan", 2.8)
    sign = aglow("MouthSign", "#ffd65a", 2.6)
    # Profile rotated so the arch stands in the XZ plane, facing -Y.
    pts = [(p[1], 0.0, p[2]) for p in arch_points(0.35)]
    parts = [tube("Arch", pts, 0.3, m=navy, segs=10, cap=True)]
    pts_in = [(p[1], -0.32, p[2]) for p in arch_points(0.05)]
    parts.append(tube("ArchLed", pts_in[1:-1], 0.05, m=cyan, segs=6))
    parts += [
        box("SignBoard", (4.4, 0.25, 0.7), (0, -0.15, TUNNEL_SPRING + TUNNEL_HALF + 0.85), bevel=0.08, m=teal),
        text("SignText", "SHARK TUNNEL", 0.36, 0.06, (0, -0.3, TUNNEL_SPRING + TUNNEL_HALF + 0.83), m=sign),
    ]
    for side in (-1, 1):
        parts.append(box(f"Pier{side}", (0.9, 0.9, TUNNEL_SPRING + 0.4), (side * (TUNNEL_HALF + 0.7), 0, (TUNNEL_SPRING + 0.4) / 2),
                         bevel=0.1, m=steel))
    save("aqua_tunnel_mouth", [merge("TunnelMouth", parts)])


def build_pillar(height=9.0):
    reset_scene()
    navy, navyl, teal = amat("Navy", rough=0.5), amat("NavyLight", rough=0.5), amat("Teal", rough=0.45)
    brass = amat("Brass", rough=0.35, metal=0.6)
    cyan = aglow("PillarLed", "Cyan", 2.4)
    parts = [
        box("Plinth", (1.5, 1.5, 0.5), (0, 0, 0.25), bevel=0.08, m=navy),
        box("Shaft", (1.2, 1.2, height - 1.2), (0, 0, 0.5 + (height - 1.2) / 2), bevel=0.1, m=navyl),
        box("Capital", (1.5, 1.5, 0.7), (0, 0, height - 0.35), bevel=0.1, m=navy),
        box("CapTrim", (1.56, 1.56, 0.1), (0, 0, height - 0.72), bevel=0.03, m=brass),
        box("BaseTrim", (1.56, 1.56, 0.1), (0, 0, 0.52), bevel=0.03, m=brass),
    ]
    for side in range(4):
        a = math.tau * side / 4
        strip = [box(f"Led{side}", (0.08, 0.04, height - 2.0), (0, -0.61, 0.9 + (height - 2.0) / 2), bevel=0.0, m=cyan)]
        for k in range(3):
            z = 2.2 + k * 2.2
            pts = [(x * 0.1, -0.62, z + 0.12 * math.sin(x * 0.9)) for x in range(-5, 6)]
            strip.append(tube(f"Wave{side}{k}", pts, 0.035, m=teal, segs=6))
        parts += place(strip, rot_z=a)
    save("aqua_pillar", [merge("Pillar", parts)])


def build_glass_rail():
    """3 m mezzanine balustrade module along X (a post at x = 0)."""
    reset_scene()
    chrome, navy = amat("Chrome", rough=0.25, metal=0.8), amat("Navy", rough=0.5)
    glass = mat("RailGlass", "#bff3ff", rough=0.05)
    bsdf = next(n for n in glass.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Alpha"].default_value = 0.22
    glass.diffuse_color = (0.75, 0.95, 1.0, 0.22)
    cyan = aglow("RailLed", "Cyan", 2.4)
    parts = [
        box("Post", (0.08, 0.08, 1.1), (0, 0, 0.55), bevel=0.02, m=chrome),
        box("Top", (3.0, 0.1, 0.07), (1.5, 0, 1.12), bevel=0.03, m=chrome),
        box("Glass", (2.9, 0.03, 0.9), (1.5, 0, 0.6), bevel=0.0, m=glass),
        box("Kick", (3.0, 0.14, 0.12), (1.5, 0, 0.06), bevel=0.02, m=navy),
        box("Led", (3.0, 0.03, 0.03), (1.5, -0.08, 0.1), bevel=0.0, m=cyan),
    ]
    save("aqua_glass_rail", [merge("GlassRail", parts)])


def build_pendant():
    reset_scene()
    steel, navy = amat("SteelDark", rough=0.35, metal=0.6), amat("Navy", rough=0.5)
    brass = amat("Brass", rough=0.35, metal=0.6)
    lamp = aglow("PendantGlow", "#bff8ff", 3.2)
    parts = [
        cyl("Cable", 0.012, 1.6, (0, 0, -0.8), segs=4, bevel=0.0, m=steel),
        cyl("Shade", 0.45, 0.3, (0, 0, -1.75), segs=20, bevel=0.06, m=navy, radius_top=0.3),
        torus("Rim", 0.44, 0.04, (0, 0, -1.9), m=brass, major_segs=24, minor_segs=6),
        cyl("Lens", 0.4, 0.03, (0, 0, -1.92), segs=20, bevel=0.0, m=lamp),
    ]
    save("aqua_pendant", [merge("Pendant", parts)])


def build_porthole():
    """Round wall-tank window frame, outer radius ~1.35 m, centre at z = 0 (mount at eye height)."""
    reset_scene()
    navy, brass = amat("NavyLight", rough=0.5), amat("Brass", rough=0.35, metal=0.6)
    parts = [annulus("Surround", 1.05, 1.4, 0.2, z=0, m=navy, segs=40)]
    parts[0].rotation_euler = rad(90, 0, 0)
    parts += porthole("Port", 1.08, (0, -0.12, 0), frame=brass, glass=None, rivets=12)
    save("aqua_porthole", [merge("Porthole", parts)])


def build_duct():
    reset_scene()
    duct, steel = amat("Duct", "#5a6b86", rough=0.45, metal=0.4), amat("SteelDark", rough=0.35, metal=0.6)
    parts = [cyl("Duct", 0.4, 4.0, (2.0, 0, 0), rot=rad(0, 90, 0), segs=16, bevel=0.0, m=duct)]
    for i in range(3):
        x = 0.1 + i * 1.9
        parts.append(torus(f"Band{i}", 0.41, 0.03, (x, 0, 0), rot=rad(0, 90, 0), m=steel, major_segs=20, minor_segs=4))
    parts.append(cyl("Hanger", 0.02, 1.2, (2.0, 0, 1.0), segs=4, bevel=0.0, m=steel))
    save("aqua_duct", [merge("Duct", parts)])


def build_whale():
    """Hanging whale sculpture, ~9.5 m long, centred on its body; cables rise to z = 2.6."""
    reset_scene()
    blue, belly = amat("WhaleBlue", "#3c6fd8", rough=0.5), amat("WhaleBelly", "#e8f1ff", rough=0.5)
    dark, steel = amat("WhaleDark", "#1d2f63", rough=0.5), amat("SteelDark", rough=0.35, metal=0.6)
    spot = amat("WhaleSpot", "#9cc2ff", rough=0.5)
    parts = [
        sphere("Body", 1.0, (0, 0, 0), scale=(1.05, 4.4, 0.95), m=blue, segs=24, rings=14),
        sphere("Head", 1.0, (0, -2.6, -0.05), scale=(1.12, 2.2, 0.98), m=blue, segs=20, rings=12),
        sphere("Belly", 1.0, (0, -0.8, -0.35), scale=(0.95, 3.6, 0.65), m=belly, segs=20, rings=12),
        box("Mouth", (1.7, 1.8, 0.05), (0, -3.6, -0.32), rot=rad(-6, 0, 0), bevel=0.02, m=dark),
        prism("Fluke", [(0.0, 0.0), (1.6, 0.9), (1.9, 0.2), (0.6, 0.0), (1.9, -0.2), (1.6, -0.9)], 0.12,
              (0, 4.2, 0.05), rot=rad(0, 90, 90), m=blue, bevel=0.05),
        prism("Dorsal", [(-0.4, 0.0), (0.4, 0.0), (0.3, 0.45)], 0.1, (0, 1.6, 0.85), rot=rad(0, 0, 90), m=blue, bevel=0.03),
    ]
    # Belly grooves.
    for i in range(7):
        parts.append(box(f"Groove{i}", (0.05, 2.6, 0.03), (-0.6 + i * 0.2, -1.6, -0.9 + 0.02 * abs(i - 3)), bevel=0.0, m=dark))
    for s_ in (-1, 1):
        fin = prism(f"Fin{s_}", [(0.0, 0.0), (2.6, -0.5), (2.9, -0.9), (2.4, -0.95), (0.0, -0.45)], 0.12, (0, 0, 0), m=blue, bevel=0.04)
        fin.matrix_world = Matrix.Translation((s_ * 0.85, -1.3, -0.4)) @ Matrix.Rotation(math.radians(-25 * s_), 4, "Y") @ \
            Matrix.Rotation(math.radians(90 if s_ > 0 else -90), 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "X") @ fin.matrix_basis
        parts.append(fin)
        parts.append(sphere(f"Eye{s_}", 0.09, (s_ * 0.98, -2.9, 0.1), m=dark, segs=8, rings=5))
        for k in range(4):
            parts.append(sphere(f"Spot{s_}{k}", 0.12, (s_ * 1.0, -0.5 + k * 0.9, 0.35 - 0.1 * k), scale=(0.3, 1, 1), m=spot, segs=8, rings=5))
    for i, y in enumerate((-1.8, 1.6)):
        parts.append(cyl(f"Cable{i}", 0.015, 2.0, (0, y, 1.6), segs=4, bevel=0.0, m=steel))
    save("aqua_whale", [merge("Whale", parts)])


def build_mural():
    """6 x 2.8 m wall graphic: glowing line-art sea creatures on a dark panel (faces -Y)."""
    reset_scene()
    panel, frame = amat("MuralPanel", "#0b1a33", rough=0.8), amat("MuralFrame", "#1b3a63", rough=0.5)
    cyan, pink, gold = aglow("MuralCyan", "#3ff0ff", 2.4), aglow("MuralPink", "#ff5fc0", 2.4), aglow("MuralGold", "#ffcf4a", 2.2)
    dark = amat("MuralFill", "#0e2244", rough=0.8)
    parts = [box("Panel", (6.0, 0.1, 2.8), (0, 0, 1.4), bevel=0.03, m=panel),
             box("FrameT", (6.2, 0.16, 0.1), (0, 0, 2.85), bevel=0.03, m=frame),
             box("FrameB", (6.2, 0.16, 0.1), (0, 0, -0.05), bevel=0.03, m=frame)]

    def outlined(name, outline, loc, glow_m, scale=1.0, rot=0.0):
        big = prism(name + "Glow", [(x * scale, z * scale) for x, z in outline], 0.02, (loc[0], -0.06, loc[1]), rot=rad(0, rot, 0), m=glow_m)
        inner = [(x * scale * 0.86, z * scale * 0.86) for x, z in outline]
        small = prism(name + "Fill", inner, 0.02, (loc[0], -0.075, loc[1]), rot=rad(0, rot, 0), m=dark)
        return [big, small]

    manta = [(0.0, 0.5), (1.3, 0.05), (0.45, -0.25), (0.12, -0.3), (0.0, -1.0), (-0.12, -0.3), (-0.45, -0.25), (-1.3, 0.05)]
    parts += outlined("Manta", manta, (-1.4, 1.6), cyan, 0.9, rot=-12)
    fish = [(0.5, 0.0), (0.2, 0.22), (-0.25, 0.15), (-0.5, 0.3), (-0.45, 0.0), (-0.5, -0.3), (-0.25, -0.15), (0.2, -0.22)]
    for i, (x, z, sc, m) in enumerate(((1.0, 2.1, 0.55, pink), (1.9, 1.6, 0.45, gold), (1.3, 1.1, 0.4, pink), (2.4, 2.3, 0.35, cyan),
                                       (2.2, 0.75, 0.5, gold), (-2.6, 0.7, 0.4, pink))):
        parts += outlined(f"Fish{i}", fish, (x, z), m, sc)
    # Bubbles.
    for i in range(7):
        parts.append(torus(f"Bubble{i}", 0.06 + 0.02 * (i % 3), 0.012, (-2.4 + i * 0.12, -0.07, 1.4 + i * 0.18),
                           rot=rad(90, 0, 0), m=cyan, major_segs=12, minor_segs=4))
    save("aqua_mural", [merge("Mural", parts)])


if __name__ == "__main__":
    build_bench()
    build_bin()
    build_signpost()
    build_info_kiosk()
    build_exit_sign()
    build_jelly_column()
    build_touch_pool()
    build_gift_shop()
    build_staff_door()
    build_elevator()
    build_loading_door()
    build_filtration()
    build_tunnel_rib()
    build_tunnel_mouth()
    build_pillar()
    build_glass_rail()
    build_pendant()
    build_porthole()
    build_duct()
    build_whale()
    build_mural()
