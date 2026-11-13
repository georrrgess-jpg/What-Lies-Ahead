"""Sugar Rush Factory props (World 8, Candy Works): the colossal gumball machine,
the taffy-pulling machine, mixing vats, silos, conveyors and the sweets they
carry, the box folder, crates, sacks, carts, lollipop lamps, candy-cane rails,
striped bridges, the gingerbread office, roller doors, pipes and signs.

Each function builds one prop in a fresh scene and saves
art/blender/candy_<name>.blend + art/models/candy_<name>.glb.
Moving parts are separate export objects (named below) that the level animates.

    python art/blender/build_candy_props.py            (all props)
    python art/blender/build_candy_props.py vat silo   (only these)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from candy_common import *  # noqa: F401,F403
from mathutils import Matrix, Vector  # noqa: E402


# ---------------------------------------------------------------------------
# The colossal gumball machine (landmark, ~16 m)
# ---------------------------------------------------------------------------

def build_gumball_machine():
    """Gumball  red pedestal, gold trim, glass globe of gumballs, lid and knob.
    Crank       the brass crank on the front (-Y), pivot on its axle (turns)."""
    reset_scene()
    red, red_d, gold = cmat("Red", rough=0.35), cmat("RedDeep", rough=0.4), cmat("Gold", rough=0.3, metal=0.6)
    cream, choc = cmat("Cream"), cmat("ChocDark")
    glass = glass_mat("CandyGlobeGlass", "#e6f6ff", alpha=0.22, emit=0.12)
    balls = gumball_mats()
    p = [
        box("Plinth", (7.4, 7.4, 0.6), (0, 0, 0.3), bevel=0.15, m=choc),
        box("PlinthTrim", (7.0, 7.0, 0.2), (0, 0, 0.7), bevel=0.06, m=gold),
        cyl("Foot", 3.3, 1.0, (0, 0, 1.3), segs=40, bevel=0.2, m=red_d),
        cyl("Body", 2.9, 4.2, (0, 0, 3.8), segs=40, bevel=0.3, m=red, radius_top=2.6),
        torus("BodyRingLow", 3.0, 0.12, (0, 0, 2.0), m=gold, major_segs=48, minor_segs=8),
        torus("BodyRingHigh", 2.68, 0.12, (0, 0, 5.6), m=gold, major_segs=48, minor_segs=8),
        cyl("Collar", 3.1, 0.7, (0, 0, 6.2), segs=40, bevel=0.15, m=red_d),
        torus("CollarRing", 3.12, 0.14, (0, 0, 6.55), m=gold, major_segs=48, minor_segs=8),
        # Coin plate and chute on the front.
        box("CoinPlate", (2.2, 0.3, 1.8), (0, -2.75, 4.3), bevel=0.12, m=gold),
        cyl("CoinSlot", 0.22, 0.12, (0, -2.92, 4.75), rot=rad(90, 0, 0), segs=16, bevel=0.0, m=choc),
        box("Chute", (1.6, 1.6, 1.2), (0, -3.2, 2.4), bevel=0.2, m=gold),
        box("ChuteMouth", (1.2, 0.4, 0.8), (0, -3.95, 2.3), bevel=0.1, m=choc),
        box("ChuteFlap", (1.25, 0.1, 0.5), (0, -4.18, 2.55), rot=rad(-20, 0, 0), bevel=0.04, m=gold),
        text("Price", "1c", 0.55, 0.06, (0, -2.95, 3.75), m=red_d),
    ]
    # The globe and the gumballs inside it.
    gz, gr = 10.6, 4.4
    p.append(sphere("Globe", gr, (0, 0, gz), m=glass, segs=40, rings=24))
    rng = random.Random(8)
    count = 0
    tries = 0
    placed = []
    while count < 230 and tries < 8000:
        tries += 1
        br = rng.uniform(0.42, 0.5)
        x, y = rng.uniform(-gr, gr), rng.uniform(-gr, gr)
        z = rng.uniform(gz - gr, gz + gr * 0.45)
        v = Vector((x, y, z - gz))
        if v.length > gr - br - 0.06:
            continue
        if any((Vector((x, y, z)) - q).length < br + 0.42 for q in placed):
            continue
        placed.append(Vector((x, y, z)))
        p.append(ico(f"Ball{count:03d}", br, (x, y, z), balls[count % len(balls)]))
        count += 1
    p += [
        cyl("LidBase", 2.0, 0.5, (0, 0, gz + gr - 0.2), segs=36, bevel=0.12, m=red_d),
        sphere("LidDome", 2.0, (0, 0, gz + gr + 0.05), scale=(1, 1, 0.55), m=red, segs=32, rings=12),
        torus("LidRing", 2.02, 0.1, (0, 0, gz + gr + 0.05), m=gold, major_segs=40, minor_segs=8),
        cyl("KnobStem", 0.3, 0.6, (0, 0, gz + gr + 1.3), segs=16, bevel=0.06, m=gold),
        sphere("Knob", 0.6, (0, 0, gz + gr + 1.9), m=gold, segs=20, rings=12),
    ]
    # Marquee bulbs round the collar and the lid.
    bulb_m = cglow("CandyBulbWarm", "#ffe9a8", 3.0)
    for i in range(20):
        a = math.tau * i / 20
        p.append(bulb(f"CollarBulb{i:02d}", 0.12, (math.cos(a) * 3.2, math.sin(a) * 3.2, 6.25), bulb_m))
    machine = merge("Gumball", p)
    # The crank: hub, two spokes and handle; its axle points along -Y.
    c = [
        cyl("CrankHub", 0.55, 0.35, (0, 0, 0), rot=rad(90, 0, 0), segs=24, bevel=0.08, m=gold),
        box("CrankArm", (2.4, 0.18, 0.32), (0, -0.25, 0), bevel=0.06, m=gold),
        cyl("CrankGrip", 0.18, 0.7, (1.1, -0.6, 0), rot=rad(90, 0, 0), segs=12, bevel=0.05, m=red_d),
        cyl("CrankBall", 0.24, 0.3, (-1.1, -0.45, 0), rot=rad(90, 0, 0), segs=12, bevel=0.08, m=red_d),
    ]
    crank = merge("Crank", c)
    crank.location = (2.2, -3.05, 3.4)
    save("candy_gumball_machine", [machine, crank])


# ---------------------------------------------------------------------------
# Taffy-pulling machine (second landmark, ~7 m)
# ---------------------------------------------------------------------------

def build_taffy_puller():
    """TaffyPuller  mint housing, gantry and the fixed hook with its taffy.
    Arms         the rotating arm pair with their pins and the taffy loops,
                 pivot on the hub (spins about the Y axis, facing -Y)."""
    reset_scene()
    mint, mint_d, cream = cmat("Mint", rough=0.45), cmat("MintDeep", rough=0.45), cmat("Cream")
    steel, steel_d, gold = cmat("Steel", rough=0.35, metal=0.5), cmat("SteelDark", rough=0.4, metal=0.4), cmat("Gold", rough=0.3, metal=0.6)
    pink, pink_d = cmat("Pink", rough=0.4), cmat("PinkDeep", rough=0.4)
    taffy = mat("CandyTaffy", "#ff6fb0", rough=0.3, emit=0.25)
    hub = (0, -1.2, 4.6)
    p = [
        box("Housing", (4.6, 3.0, 2.4), (0, 0.4, 1.2), bevel=0.2, m=mint),
        box("HousingTrim", (4.7, 3.1, 0.25), (0, 0.4, 2.45), bevel=0.08, m=cream),
        box("HousingBand", (4.66, 3.06, 0.3), (0, 0.4, 0.5), bevel=0.06, m=mint_d),
        box("Motor", (2.0, 1.6, 1.2), (0, 1.0, 3.1), bevel=0.15, m=mint_d),
        cyl("Column", 0.55, 4.6, (0, -0.2, 4.0), segs=24, bevel=0.1, m=mint),
        cyl("HubBearing", 0.85, 0.9, (0, -0.65, hub[2]), rot=rad(90, 0, 0), segs=28, bevel=0.12, m=cream),
        torus("HubRing", 0.85, 0.08, (0, -1.1, hub[2]), rot=rad(90, 0, 0), m=gold, major_segs=32, minor_segs=6),
        # Fixed hook above the hub where the taffy drapes between pulls.
        cyl("HookPost", 0.18, 2.0, (0, -0.4, 7.2), segs=12, bevel=0.04, m=steel),
        box("HookBar", (0.3, 1.6, 0.3), (0, -1.0, 8.05), bevel=0.06, m=steel),
        cyl("Hook", 0.22, 1.0, (0, -1.7, 7.7), rot=rad(90, 0, 0), segs=16, bevel=0.05, m=gold),
        sphere("HookTaffy", 0.55, (0, -1.7, 7.45), scale=(1.4, 1.1, 0.8), m=taffy, segs=16, rings=10),
        # A thick rope of taffy sags from the hook down past the hub to the tray.
        tube("HookRope", [(0.3, -1.75, 7.2), (0.7, -1.9, 6.2), (0.5, -2.0, 5.2), (-0.4, -2.05, 4.0), (-1.2, -1.9, 2.7), (-1.6, -1.65, 1.35)],
             0.2, m=taffy, segs=10, radius_end=0.14),
        # Control panel with lit buttons.
        box("Panel", (1.2, 0.3, 0.9), (1.6, -1.15, 1.6), rot=rad(-20, 0, 0), bevel=0.06, m=cream),
    ]
    for i, c in enumerate(("#ff4a5e", "#7fe3c4", "#ffd23f")):
        p.append(cyl(f"Button{i}", 0.09, 0.08, (1.3 + i * 0.3, -1.33, 1.65), rot=rad(70, 0, 0), segs=12, bevel=0.02, m=cglow(f"CandyButton{i}", c, 2.0)))
    # Striped name band and a dish catching the finished taffy.
    p.append(text("Label", "TAFFY PULLER", 0.32, 0.05, (0, -1.14, 1.25), m=pink_d))
    p.append(cyl("Tray", 1.2, 0.3, (-1.6, -1.6, 1.0), segs=24, bevel=0.06, m=steel))
    p.append(sphere("TrayTaffy", 0.7, (-1.6, -1.6, 1.15), scale=(1.4, 1.1, 0.45), m=taffy, segs=14, rings=8))
    machine = merge("TaffyPuller", p)
    # The arms: two spokes from the hub ending in pins; a taffy rope loops
    # from each pin past the hub (it turns with them).
    arm_len = 2.8
    a = [cyl("ArmHub", 0.6, 0.5, (0, 0, 0), rot=rad(90, 0, 0), segs=24, bevel=0.1, m=gold)]
    for s in (-1, 1):
        a += [
            box(f"Spoke{s}", (arm_len, 0.32, 0.36), (s * arm_len * 0.5, -0.35, 0), bevel=0.08, m=steel_d),
            cyl(f"Pin{s}", 0.2, 1.4, (s * arm_len, -0.9, 0), rot=rad(90, 0, 0), segs=16, bevel=0.05, m=steel),
            cyl(f"PinCap{s}", 0.3, 0.12, (s * arm_len, -1.62, 0), rot=rad(90, 0, 0), segs=16, bevel=0.04, m=pink),
        ]
    loop = []
    for i in range(33):
        t = math.tau * i / 32
        loop.append((math.cos(t) * arm_len * 1.02, -1.15, math.sin(t) * 0.5 * (1.0 - 0.35 * math.cos(2 * t))))
    a.append(tube("TaffyLoop", loop, 0.32, m=taffy, segs=10, cap=False))
    loop_b = [(x * 0.92, y - 0.2, z * 0.8 + 0.12) for x, y, z in loop]
    a.append(tube("TaffyLoopB", loop_b, 0.17, m=taffy, segs=8, cap=False))
    arms = merge("Arms", a)
    arms.location = hub
    save("candy_taffy_puller", [machine, arms])


# ---------------------------------------------------------------------------
# Mixing vat (paddle turns)
# ---------------------------------------------------------------------------

def build_vat():
    """Vat     a steel kettle on legs with a pink band, batter inside, a motor bridge.
    Paddle  the mixing paddle, pivot on its vertical shaft."""
    reset_scene()
    steel, steel_d = cmat("Steel", rough=0.3, metal=0.55), cmat("SteelDark", rough=0.4, metal=0.4)
    pink, cream, lilac = cmat("Pink", rough=0.4), cmat("Cream"), cmat("Lilac", rough=0.45)
    batter = mat("CandyBatter", "#ffb3d4", rough=0.3, emit=0.1)
    p = [
        cyl("Kettle", 2.3, 2.6, (0, 0, 2.4), segs=36, bevel=0.15, m=steel),
        sphere("KettleBottom", 2.3, (0, 0, 1.1), scale=(1, 1, 0.45), m=steel, segs=32, rings=10),
        torus("Rim", 2.3, 0.14, (0, 0, 3.7), m=steel_d, major_segs=44, minor_segs=8),
        cyl("Band", 2.33, 0.6, (0, 0, 2.6), segs=36, bevel=0.05, m=pink),
        cyl("Batter", 2.15, 0.1, (0, 0, 3.45), segs=36, bevel=0.0, m=batter),
        box("Bridge", (5.2, 0.6, 0.5), (0, 0, 4.4), bevel=0.1, m=lilac),
        box("Motor", (1.2, 1.0, 1.0), (0, 0, 5.1), bevel=0.15, m=lilac),
        cyl("MotorCap", 0.4, 0.3, (0, 0, 5.75), segs=16, bevel=0.06, m=cream),
        box("Valve", (0.5, 0.8, 0.5), (0, -2.4, 1.0), bevel=0.08, m=steel_d),
        cyl("ValveWheel", 0.35, 0.08, (0, -2.85, 1.0), rot=rad(90, 0, 0), segs=16, bevel=0.02, m=cmat("Red", rough=0.4)),
    ]
    for i in range(4):
        a = math.tau * (i + 0.5) / 4
        x, y = math.cos(a) * 1.8, math.sin(a) * 1.8
        p.append(cyl(f"Leg{i}", 0.16, 1.4, (x, y, 0.7), segs=10, bevel=0.03, m=steel_d))
        p.append(cyl(f"Foot{i}", 0.3, 0.12, (x, y, 0.06), segs=12, bevel=0.03, m=steel_d))
    for s in (-1, 1):
        p.append(box(f"Upright{s}", (0.4, 0.5, 1.3), (s * 2.4, 0, 3.8), bevel=0.08, m=lilac))
    p.append(text("VatLabel", "MIX", 0.5, 0.05, (0, -2.36, 2.6), m=cream))
    vat = merge("Vat", p)
    q = [
        cyl("Shaft", 0.12, 2.0, (0, 0, -1.0), segs=10, bevel=0.0, m=steel_d),
        box("BladeA", (3.4, 0.12, 0.6), (0, 0, -1.6), rot=rad(0, 0, 0), bevel=0.04, m=steel),
        box("BladeB", (0.12, 3.4, 0.6), (0, 0, -1.25), bevel=0.04, m=steel),
    ]
    paddle = merge("Paddle", q)
    paddle.location = (0, 0, 4.2)
    save("candy_vat", [vat, paddle])


# ---------------------------------------------------------------------------
# Gumball silo (~16 m)
# ---------------------------------------------------------------------------

def silo(name, body_key, band_key):
    reset_scene()
    body, band = cmat(body_key, rough=0.45), cmat(band_key, rough=0.45)
    steel_d, cream = cmat("SteelDark", rough=0.4, metal=0.4), cmat("Cream")
    glass = glass_mat("CandySiloGlass", "#e6f6ff", alpha=0.3, emit=0.1)
    balls = gumball_mats()
    p = [
        cyl("Tank", 2.4, 12.0, (0, 0, 8.0), segs=36, bevel=0.1, m=body),
        cyl("Roof", 2.55, 1.6, (0, 0, 14.8), segs=36, bevel=0.1, m=band, radius_top=0.4),
        cyl("Hopper", 2.4, 2.0, (0, 0, 1.0), segs=36, bevel=0.0, m=body, radius_top=2.4),
        cyl("Outlet", 0.45, 0.8, (0, -2.5, 1.0), rot=rad(90, 0, 0), segs=16, bevel=0.05, m=steel_d),
    ]
    for i, z in enumerate((3.0, 6.5, 10.0, 13.5)):
        p.append(cyl(f"Band{i}", 2.45, 0.5, (0, 0, z), segs=36, bevel=0.04, m=band))
    # A window strip down the front showing the gumballs inside.
    p.append(box("Window", (0.9, 0.2, 8.0), (0, -2.33, 8.0), bevel=0.06, m=glass))
    p.append(box("WindowFrame", (1.15, 0.12, 8.3), (0, -2.26, 8.0), bevel=0.04, m=cream))
    rng = random.Random(len(name))
    for i in range(34):
        z = 4.3 + i * 0.22 + rng.uniform(-0.05, 0.05)
        x = rng.uniform(-0.28, 0.28)
        p.append(ico(f"SiloBall{i}", 0.2, (x, -2.2, z), balls[rng.randrange(len(balls))]))
    # Ladder up the side.
    for s in (-1, 1):
        p.append(box(f"Rail{s}", (0.06, 0.06, 13.0), (2.55, s * 0.25, 7.5), bevel=0.0, m=steel_d))
    for i in range(26):
        p.append(box(f"Rung{i}", (0.06, 0.5, 0.05), (2.55, 0, 1.4 + i * 0.5), bevel=0.0, m=steel_d))
    p.append(text("SiloLabel", "GUMBALLS", 0.55, 0.06, (0, -2.42, 2.0), m=cream))
    save(name, [merge("Silo", p)])


def build_silo():
    silo("candy_silo", "Pink", "PinkDeep")


def build_silo_b():
    silo("candy_silo_b", "Mint", "MintDeep")


# ---------------------------------------------------------------------------
# Conveyor module and the sweets it carries
# ---------------------------------------------------------------------------

def build_conveyor():
    """A 4 m conveyor section along X: legs, side rails, rollers and a
    chocolate rubber belt, top at 0.95 m. Repeats end to end."""
    reset_scene()
    steel, steel_d = cmat("Steel", rough=0.35, metal=0.5), cmat("SteelDark", rough=0.4, metal=0.4)
    belt, mint, cream = cmat("ChocDark", rough=0.7), cmat("Mint", rough=0.45), cmat("Cream")
    L, W, top = 4.0, 1.3, 0.95
    p = [
        box("Belt", (L, W - 0.2, 0.08), (0, 0, top - 0.04), bevel=0.0, m=belt),
        box("Bed", (L, W - 0.24, 0.2), (0, 0, top - 0.2), bevel=0.0, m=steel_d),
    ]
    for s in (-1, 1):
        p.append(box(f"Side{s}", (L, 0.1, 0.36), (0, s * (W / 2 - 0.05), top - 0.08), bevel=0.03, m=mint))
        p.append(box(f"Lip{s}", (L, 0.14, 0.06), (0, s * (W / 2 - 0.05), top + 0.12), bevel=0.02, m=cream))
        for k in (-1, 1):
            p.append(box(f"Leg{s}{k}", (0.12, 0.12, top - 0.25), (k * (L / 2 - 0.4), s * (W / 2 - 0.2), (top - 0.25) / 2), bevel=0.02, m=steel))
            p.append(box(f"Foot{s}{k}", (0.3, 0.3, 0.05), (k * (L / 2 - 0.4), s * (W / 2 - 0.2), 0.025), bevel=0.01, m=steel_d))
    p.append(box("Brace", (L - 0.8, 0.08, 0.08), (0, 0, 0.3), bevel=0.0, m=steel))
    for i in range(5):
        p.append(cyl(f"Roller{i}", 0.07, W - 0.25, (-L / 2 + 0.4 + i * (L - 0.8) / 4, 0, top - 0.32), rot=rad(90, 0, 0), segs=8, bevel=0.0, m=steel))
    save("candy_conveyor", [merge("Conveyor", p)])


def build_sweets():
    """The sweets riding the belts, one export object each (MultiMesh sources):
    SweetWrapped (pink bonbon), SweetDrop (lemon gumdrop), SweetSwirl (mint
    lollipop lying flat), SweetBox (a small candy box with a ribbon)."""
    reset_scene()
    out = []
    out.append(merge("SweetWrapped", wrapped("W", 0.13, (0, 0, 0.13), 0.0, cmat("Pink", rough=0.3), cmat("PinkPale", rough=0.4))))
    drop = [cyl("Drop", 0.16, 0.2, (0, 0, 0.1), segs=14, bevel=0.06, m=cmat("Lemon", rough=0.35), radius_top=0.11),
            sphere("DropTop", 0.11, (0, 0, 0.2), scale=(1, 1, 0.7), m=cmat("Lemon", rough=0.35), segs=12, rings=6)]
    out.append(merge("SweetDrop", drop))
    white = cmat("White", rough=0.35)
    sw = [cyl("LDisc", 0.2, 0.06, (0, 0, 0.03), segs=20, bevel=0.015, m=cmat("Mint", rough=0.35)),
          tube("LSwirl", [(math.cos(t * 0.27) * 0.017 * t, math.sin(t * 0.27) * 0.017 * t, 0.062) for t in range(11)], 0.016, m=white, segs=5),
          cyl("LStick", 0.014, 0.35, (0, -0.36, 0.03), rot=rad(90, 0, 0), segs=6, bevel=0.0, m=white)]
    out.append(merge("SweetSwirl", sw))
    bx = [box("Box", (0.5, 0.36, 0.3), (0, 0, 0.15), bevel=0.03, m=cmat("Lilac", rough=0.5)),
          box("BoxRibbonA", (0.52, 0.06, 0.31), (0, 0, 0.152), bevel=0.0, m=cmat("Butter", rough=0.5)),
          box("BoxRibbonB", (0.06, 0.38, 0.31), (0, 0, 0.152), bevel=0.0, m=cmat("Butter", rough=0.5))]
    out.append(merge("SweetBox", bx))
    for i, ob in enumerate(out):
        ob.location = (i * 1.0, 0, 0)
    save("candy_sweets", out)


# ---------------------------------------------------------------------------
# Packaging: the box folder and stacks of boxes
# ---------------------------------------------------------------------------

def build_box_machine():
    """The box folder at the end of the packing belt (belt enters at -X,
    boxes leave at +X), 4.2 x 2.6 x 3.4 m with a glass hood, lamps and a sign."""
    reset_scene()
    lilac, lilac_d, cream = cmat("Lilac", rough=0.45), cmat("LilacDeep", rough=0.45), cmat("Cream")
    steel_d, butter = cmat("SteelDark", rough=0.4, metal=0.4), cmat("Butter", rough=0.45)
    glass = glass_mat()
    lamp_r, lamp_g = cglow("CandyLampRed", "#ff4a5e", 3.0), cglow("CandyLampGreen", "#7fffb0", 3.0)
    p = [
        box("Base", (4.2, 2.6, 1.0), (0, 0, 0.5), bevel=0.12, m=lilac_d),
        box("Hood", (3.8, 2.4, 1.8), (0, 0, 1.95), bevel=0.15, m=lilac),
        box("HoodWindow", (2.6, 0.1, 1.0), (0, -1.22, 2.0), bevel=0.04, m=glass),
        box("Cap", (4.0, 2.6, 0.3), (0, 0, 3.0), bevel=0.08, m=cream),
        box("Mouth", (0.3, 1.3, 0.9), (-2.0, 0, 1.45), bevel=0.06, m=steel_d),
        box("Exit", (0.3, 1.3, 0.9), (2.0, 0, 1.45), bevel=0.06, m=steel_d),
        box("Stack", (0.8, 0.8, 0.9), (0.9, 0.5, 3.6), bevel=0.06, m=lilac_d),
        cyl("Lamp0", 0.16, 0.35, (-1.2, 0.6, 3.3), segs=12, bevel=0.04, m=lamp_r),
        cyl("Lamp1", 0.16, 0.35, (-0.7, 0.6, 3.3), segs=12, bevel=0.04, m=lamp_g),
        box("SignBoard", (2.6, 0.12, 0.55), (0, -1.32, 3.05), bevel=0.04, m=butter),
        text("Sign", "BOX-O-MATIC", 0.3, 0.04, (0, -1.4, 3.03), m=lilac_d),
    ]
    # Flat-packed cardboard waiting in the hopper.
    for i in range(5):
        p.append(box(f"Flat{i}", (0.7, 0.7, 0.05), (0.9, 0.5, 4.08 + i * 0.06), rot=rad(0, 0, i * 7), bevel=0.0, m=cmat("PinkPale", rough=0.6)))
    save("candy_box_machine", [merge("BoxMachine", p)])


def build_boxes():
    """A pallet stacked with ribboned candy boxes (cover, 1.5 x 1.2 x 1.4 m)."""
    reset_scene()
    wood = cmat("Ginger", rough=0.7)
    cols = [cmat("Pink", rough=0.5), cmat("Mint", rough=0.5), cmat("Lilac", rough=0.5), cmat("Butter", rough=0.5)]
    ribbon = cmat("White", rough=0.4)
    p = [box("Pallet", (1.5, 1.2, 0.15), (0, 0, 0.075), bevel=0.02, m=wood)]
    rng = random.Random(4)
    k = 0
    for layer in range(2):
        for ix in range(2):
            for iy in range(2):
                c = cols[(k + layer) % len(cols)]
                x, y = -0.36 + ix * 0.72, -0.28 + iy * 0.56
                z = 0.15 + layer * 0.6 + 0.29
                r = rng.uniform(-6, 6)
                p.append(box(f"Box{k}", (0.68, 0.52, 0.56), (x, y, z), rot=rad(0, 0, r), bevel=0.04, m=c))
                p.append(box(f"Rib{k}", (0.7, 0.07, 0.57), (x, y, z), rot=rad(0, 0, r), bevel=0.0, m=ribbon))
                k += 1
    p.append(box("TopBox", (0.6, 0.5, 0.36), (0.1, 0.05, 1.53), rot=rad(0, 0, 12), bevel=0.04, m=cols[3]))
    save("candy_boxes", [merge("Boxes", p)])


# ---------------------------------------------------------------------------
# Floor dressing and cover
# ---------------------------------------------------------------------------

def build_crates():
    """Two stacked candy-cane crates (cover, 2.0 x 1.2 x 1.6 m)."""
    reset_scene()
    wood, wood_d = cmat("Ginger", rough=0.7), cmat("GingerDark", rough=0.7)
    label = cmat("Cream")
    p = []
    for i, (x, z, s, r) in enumerate(((-0.5, 0.5, 1.0, 0), (0.55, 0.45, 0.9, 8), (-0.35, 1.32, 0.72, -10))):
        p.append(box(f"Crate{i}", (s, s * 1.1, s), (x, 0, z * 1.0 if i < 2 else z), rot=rad(0, 0, r), bevel=0.05, m=wood))
        for k in (-1, 1):
            p.append(box(f"Slat{i}{k}", (s + 0.02, s * 1.1 + 0.02, 0.08), (x, 0, (z if i < 2 else z) + k * s * 0.3), rot=rad(0, 0, r), bevel=0.0, m=wood_d))
        p.append(box(f"Label{i}", (s * 0.5, 0.02, s * 0.3), (x, -s * 0.56, z if i < 2 else z), rot=rad(0, 0, r), bevel=0.0, m=label))
    p += cane("Cane", 0.05, 1.0, (0.55, -0.2, 0.9), hook=0.12, rot_z=0.4)
    save("candy_crates", [merge("Crates", p)])


def build_sacks():
    """Sugar sacks on a pallet (cover, 1.6 x 1.2 x 1.1 m)."""
    reset_scene()
    wood, sack, print_m = cmat("Ginger", rough=0.7), mat("CandySack", "#f4ead8", rough=0.85), cmat("PinkDeep", rough=0.6)
    p = [box("Pallet", (1.6, 1.2, 0.15), (0, 0, 0.075), bevel=0.02, m=wood)]
    rng = random.Random(9)
    k = 0
    for layer in range(3):
        for i in range(2 if layer < 2 else 1):
            x = -0.38 + i * 0.76 if layer < 2 else 0.0
            z = 0.32 + layer * 0.3
            r = 90 * (layer % 2) + rng.uniform(-8, 8)
            p.append(sphere(f"Sack{k}", 0.5, (x, 0, z), scale=(0.78, 1.15, 0.34), rot=(0, 0, math.radians(r)), m=sack, segs=14, rings=8))
            p.append(cyl(f"Print{k}", 0.16, 0.02, (x, 0, z + 0.165), rot=(0, 0, 0), segs=12, bevel=0.0, m=print_m))
            k += 1
    save("candy_sacks", [merge("Sacks", p)])


def build_cart():
    """A gumball trolley heaped with gumballs (cover, 1.8 x 1.1 x 1.25 m)."""
    reset_scene()
    pink, steel_d, cream = cmat("Pink", rough=0.45), cmat("SteelDark", rough=0.4, metal=0.4), cmat("Cream")
    balls = gumball_mats()
    p = [
        box("Tub", (1.7, 1.0, 0.7), (0, 0, 0.75), bevel=0.12, m=pink),
        box("TubLip", (1.8, 1.1, 0.1), (0, 0, 1.1), bevel=0.04, m=cream),
        tube("Handle", [(0.85, -0.45, 1.05), (1.25, -0.45, 1.3), (1.25, 0.45, 1.3), (0.85, 0.45, 1.05)], 0.04, m=steel_d, segs=6),
    ]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(cyl(f"Wheel{sx}{sy}", 0.17, 0.1, (sx * 0.65, sy * 0.4, 0.17), rot=rad(90, 0, 0), segs=12, bevel=0.03, m=steel_d))
            p.append(box(f"Fork{sx}{sy}", (0.08, 0.08, 0.3), (sx * 0.65, sy * 0.4, 0.35), bevel=0.0, m=steel_d))
    rng = random.Random(2)
    for i in range(26):
        x, y = rng.uniform(-0.65, 0.65), rng.uniform(-0.35, 0.35)
        z = 1.08 + 0.18 * math.cos(x * 2.0) * math.cos(y * 3.0) + rng.uniform(0, 0.08)
        p.append(ico(f"Ball{i}", 0.13, (x, y, z), balls[i % len(balls)]))
    save("candy_cart", [merge("Cart", p)])


def build_lamp():
    """A lollipop lamp post, 4.2 m: striped pole, glowing swirl disc head."""
    reset_scene()
    white, pink = cmat("White", rough=0.35), cmat("Pink", rough=0.35)
    glow_a = cglow("CandyLampDisc", "#ffd6ea", 1.8)
    glow_b = cglow("CandyLampSwirl", "#ff7eb6", 2.2)
    p = striped_post("Pole", 0.09, 3.3, (0, 0, 0.3), white, pink, bands=11)
    p += [
        cyl("Base", 0.3, 0.3, (0, 0, 0.15), segs=16, bevel=0.06, m=cmat("Mint", rough=0.45)),
        cyl("Collar", 0.14, 0.2, (0, 0, 3.6), segs=12, bevel=0.04, m=cmat("Gold", rough=0.3, metal=0.6)),
    ]
    p += lollipop("Head", 0.62, 3.5, (0, 0, 0.0), glow_a, glow_b, thick=0.3)[1:]
    save("candy_lamp", [merge("Lamp", p)])


def build_rail():
    """A 2.5 m candy-cane railing module along X: striped posts at both ends
    (shared with the neighbour), a top rail and a mid rail, 1.05 m high."""
    reset_scene()
    white, red = cmat("White", rough=0.3), cmat("Red", rough=0.3)
    p = []
    p += striped_post("Post", 0.06, 1.05, (-1.25, 0, 0), white, red, bands=5, segs=10)
    p.append(sphere("PostCap", 0.08, (-1.25, 0, 1.08), m=red, segs=10, rings=6))
    p += swirl("Top", 0.045, 2.5, (0, 0, 1.0), rad(0, 90, 0), white, red, turns=5, segs=6, stripe=0.5)
    p.append(cyl("Mid", 0.03, 2.5, (0, 0, 0.55), rot=rad(0, 90, 0), segs=8, bevel=0.0, m=white))
    save("candy_rail", [merge("Rail", p)])


def bridge(name, width):
    """A footbridge 9 m long (along Y) over the chocolate river: flat deck at
    0.1 m in candy stripes, arched candy-cane side trusses, end posts with
    gumdrop finials."""
    reset_scene()
    pink, mint, cream, butter = cmat("Pink", rough=0.45), cmat("Mint", rough=0.45), cmat("Cream"), cmat("Butter", rough=0.45)
    white, red = cmat("White", rough=0.3), cmat("Red", rough=0.3)
    L = 9.0
    p = [box("Under", (width, L, 0.5), (0, 0, -0.25), bevel=0.06, m=cmat("ChocLight", rough=0.6))]
    n = 18
    for i in range(n):
        y = -L / 2 + L * (i + 0.5) / n
        p.append(box(f"Board{i}", (width, L / n - 0.03, 0.1), (0, y, 0.05), bevel=0.02, m=(pink, cream, mint, cream)[i % 4]))
    for s in (-1, 1):
        x = s * (width / 2 + 0.12)
        p.append(box(f"Stringer{s}", (0.24, L, 0.6), (x, 0, -0.1), bevel=0.05, m=butter))
        # Arched striped truss.
        pts = [(x, -L / 2 + L * t, 1.0 + 1.0 * math.sin(math.pi * t)) for t in [i / 16 for i in range(17)]]
        p.append(tube(f"Arch{s}", pts, 0.09, m=white, segs=8))
        for i in range(8):
            t = (i + 0.5) / 8
            pts_seg = [(x, -L / 2 + L * (t - 0.03), 1.0 + math.sin(math.pi * (t - 0.03))), (x, -L / 2 + L * (t + 0.03), 1.0 + math.sin(math.pi * (t + 0.03)))]
            p.append(tube(f"ArchBand{s}{i}", pts_seg, 0.1, m=red, segs=8))
        for i in range(7):
            t = (i + 1) / 8
            y = -L / 2 + L * t
            top = 1.0 + math.sin(math.pi * t)
            p.append(cyl(f"Hanger{s}{i}", 0.035, top, (x, y, top / 2), segs=6, bevel=0.0, m=white))
        p.append(cyl(f"Handrail{s}", 0.05, L, (x, 0, 1.0), rot=rad(90, 0, 0), segs=8, bevel=0.0, m=red))
        for e in (-1, 1):
            y = e * L / 2
            p += striped_post(f"End{s}{e}", 0.13, 1.4, (x, y, 0), white, red, bands=6, segs=12)
            p.append(sphere(f"Drop{s}{e}", 0.22, (x, y, 1.55), scale=(1, 1, 0.9), m=(mint if e > 0 else pink), segs=12, rings=8))
    save(name, [merge("Bridge", p)])


def build_bridge():
    bridge("candy_bridge", 3.6)


def build_bridge_wide():
    bridge("candy_bridge_wide", 6.0)


def build_lollipop():
    """A giant decorative lollipop in a gumdrop planter (3.6 m)."""
    reset_scene()
    p = [cyl("Planter", 0.7, 0.6, (0, 0, 0.3), segs=20, bevel=0.1, m=cmat("Mint", rough=0.45), radius_top=0.55),
         sphere("Soil", 0.55, (0, 0, 0.6), scale=(1, 1, 0.25), m=cmat("ChocDark", rough=0.8), segs=16, rings=6)]
    p += lollipop("Pop", 1.1, 2.1, (0, 0, 0.55), cmat("Pink", rough=0.35), cmat("White", rough=0.35))
    save("candy_lollipop", [merge("Lollipop", p)])


def build_vent():
    """A steam vent: a squat pipe stack with a grate and a lilac hood (1.6 m)."""
    reset_scene()
    steel, steel_d, lilac = cmat("Steel", rough=0.35, metal=0.5), cmat("SteelDark", rough=0.4, metal=0.4), cmat("Lilac", rough=0.45)
    p = [box("Grate", (1.6, 1.6, 0.12), (0, 0, 0.06), bevel=0.03, m=steel_d),
         cyl("Stack", 0.4, 1.3, (0, 0, 0.75), segs=16, bevel=0.05, m=steel),
         cyl("Hood", 0.6, 0.35, (0, 0, 1.5), segs=16, bevel=0.06, m=lilac, radius_top=0.3)]
    for i in range(5):
        p.append(box(f"Bar{i}", (1.5, 0.06, 0.04), (0, -0.6 + i * 0.3, 0.13), bevel=0.0, m=steel))
    save("candy_vent", [merge("Vent", p)])


def build_forklift():
    """A pastel forklift carrying a pallet of boxes (cover, 2.6 x 1.3 x 2.3 m),
    forks toward -Y."""
    reset_scene()
    butter, steel_d, choc = cmat("Butter", rough=0.45), cmat("SteelDark", rough=0.4, metal=0.4), cmat("ChocDark", rough=0.7)
    p = [
        box("Body", (1.2, 1.8, 0.8), (0, 0.3, 0.7), bevel=0.15, m=butter),
        box("Counter", (1.2, 0.5, 0.7), (0, 1.1, 0.75), bevel=0.15, m=cmat("Orange", rough=0.45)),
        box("Seat", (0.6, 0.5, 0.25), (0, 0.5, 1.2), bevel=0.08, m=choc),
        box("SeatBack", (0.6, 0.15, 0.5), (0, 0.75, 1.45), bevel=0.06, m=choc),
    ]
    for sx in (-1, 1):
        p.append(cyl(f"WheelF{sx}", 0.3, 0.25, (sx * 0.6, -0.35, 0.3), rot=rad(0, 90, 0), segs=14, bevel=0.05, m=choc))
        p.append(cyl(f"WheelR{sx}", 0.24, 0.22, (sx * 0.58, 0.95, 0.24), rot=rad(0, 90, 0), segs=14, bevel=0.05, m=choc))
        p.append(box(f"Mast{sx}", (0.1, 0.12, 2.2), (sx * 0.4, -0.65, 1.1), bevel=0.02, m=steel_d))
        p.append(box(f"Cage{sx}", (0.06, 1.0, 0.06), (sx * 0.5, 0.35, 2.05), bevel=0.0, m=steel_d))
        p.append(box(f"CageP{sx}", (0.06, 0.06, 0.9), (sx * 0.5, -0.1, 1.6), bevel=0.0, m=steel_d))
        p.append(box(f"CagePB{sx}", (0.06, 0.06, 0.9), (sx * 0.5, 0.8, 1.6), bevel=0.0, m=steel_d))
        p.append(box(f"Fork{sx}", (0.12, 1.2, 0.06), (sx * 0.3, -1.3, 0.38), bevel=0.0, m=steel_d))
    p.append(box("CageTop", (1.06, 1.0, 0.06), (0, 0.35, 2.08), bevel=0.0, m=steel_d))
    p.append(box("Pallet", (1.1, 1.1, 0.12), (0, -1.3, 0.47), bevel=0.02, m=cmat("Ginger", rough=0.7)))
    for i, c in enumerate(("Pink", "Mint", "Lilac")):
        p.append(box(f"Load{i}", (0.95, 0.95, 0.4), (0, -1.3, 0.75 + i * 0.42), rot=rad(0, 0, i * 6 - 6), bevel=0.04, m=cmat(c, rough=0.5)))
    save("candy_forklift", [merge("Forklift", p)])


# ---------------------------------------------------------------------------
# Architecture pieces
# ---------------------------------------------------------------------------

def build_door():
    """A loading door for the zombie entrances, 6 x 6 m frame facing -Y: a
    half-open striped roller door over a dark opening, a striped awning, amber
    beacons and a lit sign plate (the level writes nothing on it)."""
    reset_scene()
    frame, pink, white = cmat("Butter", rough=0.45), cmat("Pink", rough=0.45), cmat("White", rough=0.35)
    steel_d = cmat("SteelDark", rough=0.4, metal=0.4)
    beacon = cglow("CandyBeacon", "#ffb03a", 3.0)
    W, H = 4.4, 4.2
    p = [
        box("JambL", (0.6, 0.9, H + 0.6), (-W / 2 - 0.3, 0.1, (H + 0.6) / 2), bevel=0.08, m=frame),
        box("JambR", (0.6, 0.9, H + 0.6), (W / 2 + 0.3, 0.1, (H + 0.6) / 2), bevel=0.08, m=frame),
        box("Lintel", (W + 1.2, 0.9, 0.7), (0, 0.1, H + 0.35), bevel=0.08, m=frame),
        box("Housing", (W + 0.4, 0.7, 0.6), (0, -0.2, H + 0.05), bevel=0.12, m=steel_d),
    ]
    # Half-raised roller door: horizontal slats in alternating stripes.
    for i in range(6):
        z = H - 0.2 - i * 0.24
        p.append(box(f"Slat{i}", (W, 0.08, 0.22), (0, 0.2, z), bevel=0.02, m=pink if i % 2 == 0 else white))
    for i in range(8):
        x = -W / 2 - 0.3 + i * (W + 0.6) / 7
        p.append(box(f"Awning{i}", ((W + 0.6) / 8 + 0.01, 1.1, 0.08), (x + (W + 0.6) / 16 - (W + 0.6) / 14, -0.85, H + 0.85),
                     rot=rad(-18, 0, 0), bevel=0.02, m=pink if i % 2 == 0 else white))
    for s in (-1, 1):
        p.append(cyl(f"Beacon{s}", 0.16, 0.3, (s * (W / 2 + 0.3), -0.4, H + 0.5), segs=12, bevel=0.04, m=beacon))
        # Hazard chevrons up the jamb faces.
        for i in range(6):
            p.append(box(f"Chev{s}{i}", (0.62, 0.02, 0.18), (s * (W / 2 + 0.3), -0.36, 0.4 + i * 0.7), rot=rad(0, s * 30, 0), bevel=0.0,
                         m=cmat("ChocDark") if i % 2 else cmat("Lemon", rough=0.5)))
    save("candy_door", [merge("Door", p)])


def build_office():
    """The gingerbread foreman's office, 10 x 8 m, 7.6 m to the ridge, front
    (-Y) with a door, lit frosted windows, icing trim, gumdrops and canes.
    Closed (its door is painted shut with icing)."""
    reset_scene()
    ginger, ginger_d = cmat("Ginger", rough=0.7), cmat("GingerDark", rough=0.7)
    icing, pink, mint = cmat("White", rough=0.4), cmat("Pink", rough=0.4), cmat("Mint", rough=0.4)
    frosted = frosted_mat()
    W, D, H = 10.0, 8.0, 5.2
    p = [
        box("Walls", (W, D, H), (0, 0, H / 2), bevel=0.12, m=ginger),
        box("Plinth", (W + 0.2, D + 0.2, 0.5), (0, 0, 0.25), bevel=0.06, m=ginger_d),
        prism("Gable", [(-W / 2, 0), (W / 2, 0), (0, 2.4)], D, (0, 0, H), m=ginger),
    ]
    # Roof slabs with icing along the ridge and eaves.
    slope = math.atan2(2.4, W / 2)
    rl = math.hypot(W / 2, 2.4) + 0.5
    for s in (-1, 1):
        p.append(box(f"Roof{s}", (rl, D + 0.8, 0.3), (s * W / 4, 0, H + 1.25), rot=(0, s * slope, 0), bevel=0.1, m=cmat("ChocDark", rough=0.6)))
        p += icing_drips(f"Eave{s}", (s * (W / 2 + 0.2), -D / 2 - 0.42, H - 0.05), (s * (W / 2 + 0.2), D / 2 + 0.42, H - 0.05), 10, 0.4, seed=4 + s)
    p.append(cyl("RidgeIcing", 0.18, D + 0.9, (0, 0, H + 2.5), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=icing))
    for s in (-1, 1):
        p += icing_drips(f"Gable{s}", (-W / 2 - 0.1, s * (D / 2 + 0.42), H + 0.1), (0, s * (D / 2 + 0.42), H + 2.5), 6, 0.3, seed=9 + s)
        p += icing_drips(f"GableR{s}", (0, s * (D / 2 + 0.42), H + 2.5), (W / 2 + 0.1, s * (D / 2 + 0.42), H + 0.1), 6, 0.3, seed=12 + s)
    # Windows: frosted glass in icing frames on the front and sides.
    def window(name, x, y, z, w, h, face):
        q = [box(name + "Glass", (w, 0.1, h), (0, 0, 0), bevel=0.0, m=frosted),
             box(name + "FrameT", (w + 0.3, 0.16, 0.14), (0, -0.03, h / 2 + 0.07), bevel=0.05, m=icing),
             box(name + "FrameB", (w + 0.3, 0.2, 0.16), (0, -0.05, -h / 2 - 0.08), bevel=0.05, m=icing),
             box(name + "FrameL", (0.14, 0.16, h), (-w / 2 - 0.07, -0.03, 0), bevel=0.04, m=icing),
             box(name + "FrameR", (0.14, 0.16, h), (w / 2 + 0.07, -0.03, 0), bevel=0.04, m=icing),
             box(name + "Mull", (0.08, 0.14, h), (0, -0.04, 0), bevel=0.0, m=icing),
             box(name + "Shutter", (0.12, 0.12, h + 0.2), (-w / 2 - 0.3, -0.05, 0), bevel=0.03, m=pink),
             box(name + "ShutterR", (0.12, 0.12, h + 0.2), (w / 2 + 0.3, -0.05, 0), bevel=0.03, m=pink)]
        return place(q, (x, y, z), face)
    for i, x in enumerate((-3.2, 3.2)):
        p += window(f"FrontW{i}", x, -D / 2 - 0.02, 1.9, 1.6, 1.4, 0.0)
        p += window(f"UpperW{i}", x, -D / 2 - 0.02, 4.0, 1.4, 1.0, 0.0)
    for i, y in enumerate((-1.8, 1.8)):
        p += window(f"SideW{i}", W / 2 + 0.02, y, 2.4, 1.6, 1.4, math.pi / 2)
    # Door (iced shut) with a gumdrop on top and a sign.
    p += [box("Door", (1.6, 0.14, 2.6), (0, -D / 2 - 0.04, 1.6), bevel=0.06, m=pink),
          box("DoorFrame", (2.0, 0.12, 3.0), (0, -D / 2 + 0.01, 1.75), bevel=0.06, m=icing),
          sphere("DoorKnob", 0.08, (0.55, -D / 2 - 0.16, 1.55), m=cmat("Gold", rough=0.3, metal=0.6), segs=10, rings=6),
          box("Step", (2.4, 0.8, 0.3), (0, -D / 2 - 0.4, 0.15), bevel=0.06, m=ginger_d),
          box("SignBoard", (3.2, 0.12, 0.6), (0, -D / 2 - 0.06, 3.15), bevel=0.05, m=mint),
          text("Sign", "FOREMAN", 0.36, 0.04, (0, -D / 2 - 0.14, 3.13), m=icing)]
    # Gumdrops along the eaves and candy canes at the corners.
    gum = gumball_mats()
    for i in range(9):
        x = -W / 2 + 0.6 + i * (W - 1.2) / 8
        p.append(sphere(f"Gumdrop{i}", 0.22, (x, -D / 2 - 0.15, 5.0), scale=(1, 1, 0.85), m=gum[i % len(gum)], segs=12, rings=7))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p += cane(f"Corner{sx}{sy}", 0.16, 4.6, (sx * (W / 2 + 0.1), sy * (D / 2 + 0.1), 0.0), hook=0.3, rot_z=0.0 if sx > 0 else math.pi)
    # Icing squiggles across the walls.
    for z in (0.65, 3.0):
        p += icing_drips(f"Belt{z}", (-W / 2 - 0.05, -D / 2 - 0.08, z), (W / 2 + 0.05, -D / 2 - 0.08, z), 0, 0.0, seed=1)
    save("candy_office", [merge("Office", p)])


def build_pipe():
    """A 4 m lollipop-striped pipe section along X, 0.45 m radius, with a
    flange at the -X end (repeats end to end in MultiMeshes)."""
    reset_scene()
    p = swirl("Pipe", 0.45, 4.0, (0, 0, 0), rad(0, 90, 0), cmat("Pink", rough=0.4), cmat("White", rough=0.35), turns=2.5, segs=10, stripe=0.32)
    p.append(cyl("Flange", 0.56, 0.16, (-1.95, 0, 0), rot=rad(0, 90, 0), segs=20, bevel=0.03, m=cmat("Gold", rough=0.3, metal=0.6)))
    save("candy_pipe", [merge("Pipe", p)])


def build_pipe_mint():
    reset_scene()
    p = swirl("Pipe", 0.45, 4.0, (0, 0, 0), rad(0, 90, 0), cmat("Mint", rough=0.4), cmat("White", rough=0.35), turns=2.5, segs=10, stripe=0.32)
    p.append(cyl("Flange", 0.56, 0.16, (-1.95, 0, 0), rot=rad(0, 90, 0), segs=20, bevel=0.03, m=cmat("Gold", rough=0.3, metal=0.6)))
    save("candy_pipe_mint", [merge("Pipe", p)])


def build_spout():
    """The chocolate pipe outlet in the west wall: a 2.6 m flanged pipe mouth
    with a valve wheel, facing -Y (the level turns it to face the river)."""
    reset_scene()
    choc, choc_l, gold = cmat("ChocDark", rough=0.5), cmat("ChocLight", rough=0.5), cmat("Gold", rough=0.3, metal=0.6)
    p = [cyl("Pipe", 1.3, 3.0, (0, 1.2, 0), rot=rad(90, 0, 0), segs=32, bevel=0.1, m=choc_l),
         torus("Flange", 1.35, 0.22, (0, -0.3, 0), rot=rad(90, 0, 0), m=gold, major_segs=40, minor_segs=10),
         cyl("Mouth", 1.12, 0.2, (0, -0.32, 0), rot=rad(90, 0, 0), segs=32, bevel=0.0, m=mat("CandyChocMouth", "#2a160e", rough=0.4)),
         cyl("Valve", 0.7, 0.12, (1.6, 0.6, 1.0), rot=rad(0, 90, 0), segs=20, bevel=0.03, m=cmat("Red", rough=0.4)),
         cyl("ValveStem", 0.1, 0.5, (1.4, 0.6, 1.0), rot=rad(0, 90, 0), segs=8, bevel=0.0, m=gold)]
    for i in range(8):
        a = math.tau * i / 8
        p.append(cyl(f"Bolt{i}", 0.08, 0.12, (math.cos(a) * 1.4, -0.48, math.sin(a) * 1.4), rot=rad(90, 0, 0), segs=6, bevel=0.0, m=choc))
    save("candy_spout", [merge("Spout", p)])


def build_rose_window():
    """The great round window in the north gable: 12 m across, a lollipop
    swirl of coloured glass in a gold frame (faces -Y, centre at the origin)."""
    reset_scene()
    gold, cream = cmat("Gold", rough=0.3, metal=0.6), cmat("Cream")
    cols = [cglow(f"CandyRose{i}", c, 1.6) for i, c in enumerate(("#ff8ec4", "#ffe08a", "#8ff0d0", "#c9a7ff", "#9fd8ff", "#ffb07a"))]
    R = 6.0
    p = [torus("Rim", R, 0.35, (0, 0, 0), rot=rad(90, 0, 0), m=gold, major_segs=64, minor_segs=10),
         torus("RimIn", R * 0.32, 0.2, (0, 0, 0), rot=rad(90, 0, 0), m=gold, major_segs=40, minor_segs=8),
         cyl("Hub", R * 0.3, 0.12, (0, 0.05, 0), rot=rad(90, 0, 0), segs=40, bevel=0.0, m=cols[0])]
    petals = 12
    for i in range(petals):
        a0 = math.tau * i / petals
        a1 = math.tau * (i + 1) / petals
        # A swirled petal: an annular sector twisted by a quarter turn outward.
        out = []
        for k in range(9):
            t = k / 8
            r = R * 0.32 + (R - R * 0.32) * t
            a = a0 + t * 0.8
            out.append((math.cos(a) * r, math.sin(a) * r))
        back = []
        for k in range(9):
            t = 1 - k / 8
            r = R * 0.32 + (R - R * 0.32) * t
            a = a1 + t * 0.8
            back.append((math.cos(a) * r, math.sin(a) * r))
        p.append(prism(f"Petal{i}", out + back, 0.08, (0, 0.06, 0), m=cols[i % len(cols)]))
        pts = [(out[k][0], -0.05, out[k][1]) for k in range(9)]
        p.append(tube(f"Lead{i}", pts, 0.09, m=cream, segs=6))
    save("candy_rose_window", [merge("RoseWindow", p)])


def build_sign():
    """The hanging factory sign over the main bridge, 11 m wide: SUGAR RUSH
    over CANDY WORKS on a scalloped butter-yellow board with marquee bulbs."""
    reset_scene()
    board, pink, choc = cmat("Butter", rough=0.45), cmat("Pink", rough=0.4), cmat("ChocDark", rough=0.5)
    bulb_m = cglow("CandyBulbWarm", "#ffe9a8", 3.0)
    p = [box("Board", (11.0, 0.3, 2.6), (0, 0, 0), bevel=0.15, m=board),
         box("Edge", (11.3, 0.24, 2.9), (0, 0.06, 0), bevel=0.15, m=pink),
         text("Top", "SUGAR RUSH", 0.95, 0.12, (0, -0.2, 0.42), m=cmat("PinkDeep", rough=0.4)),
         text("Bottom", "CANDY WORKS", 0.7, 0.1, (0, -0.2, -0.62), m=choc)]
    for i in range(11):
        p.append(sphere(f"Scallop{i}", 0.5, (-5.0 + i * 1.0, 0.0, -1.42), scale=(1, 0.5, 0.6), m=pink, segs=12, rings=6))
    for i in range(22):
        p.append(bulb(f"Bulb{i:02d}", 0.08, (-5.25 + i * 0.5, -0.2, 1.25), bulb_m))
    for s in (-1, 1):
        p.append(cyl(f"Chain{s}", 0.04, 6.0, (s * 4.5, 0, 4.3), segs=6, bevel=0.0, m=cmat("SteelDark", rough=0.4, metal=0.4)))
    save("candy_sign", [merge("Sign", p)])


def build_pilaster():
    """A candy-cane pilaster for the hall walls, 15 m tall, 0.9 m across,
    standing on a chocolate plinth (repeats along the walls)."""
    reset_scene()
    p = striped_post("Shaft", 0.45, 13.6, (0, 0, 1.4), cmat("White", rough=0.35), cmat("Red", rough=0.35), bands=26, segs=16)
    p += [box("Plinth", (1.3, 1.3, 1.4), (0, 0, 0.7), bevel=0.1, m=cmat("ChocDark", rough=0.5)),
          box("Capital", (1.3, 1.3, 0.6), (0, 0, 15.3), bevel=0.12, m=cmat("Butter", rough=0.45)),
          sphere("Gumdrop", 0.5, (0, 0, 15.8), scale=(1, 1, 0.8), m=cmat("Mint", rough=0.4), segs=14, rings=7)]
    save("candy_pilaster", [merge("Pilaster", p)])


BUILDERS = {
    "gumball_machine": build_gumball_machine, "taffy_puller": build_taffy_puller, "vat": build_vat,
    "silo": build_silo, "silo_b": build_silo_b, "conveyor": build_conveyor, "sweets": build_sweets,
    "box_machine": build_box_machine, "boxes": build_boxes, "crates": build_crates, "sacks": build_sacks,
    "cart": build_cart, "lamp": build_lamp, "rail": build_rail, "bridge": build_bridge, "bridge_wide": build_bridge_wide,
    "lollipop": build_lollipop, "vent": build_vent, "forklift": build_forklift, "door": build_door, "office": build_office,
    "pipe": build_pipe, "pipe_mint": build_pipe_mint, "spout": build_spout, "rose_window": build_rose_window,
    "sign": build_sign, "pilaster": build_pilaster,
}


if __name__ == "__main__":
    wanted = [a for a in sys.argv[1:] if a in BUILDERS] or list(BUILDERS)
    for key in wanted:
        BUILDERS[key]()
