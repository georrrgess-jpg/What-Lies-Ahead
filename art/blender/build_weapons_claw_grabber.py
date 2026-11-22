"""First-person viewmodel of the Claw Grabber (update 24 secondary): a prize
claw machine shrunk into a pistol. A candy-red cabinet on the grip with a
glass prize case on top (a heap of tiny plush prizes, and a mini crane on its
gantry hanging over them), a marquee header with a row of chase bulbs down
each side and the iron sights on its flat roof, a control deck on the left
flank with a ball-top joystick and a glowing GRAB button, a chrome coin door
with a lit slot behind it, and at the front a chrome cable chute with the big
three-pronged claw hanging out of it on its cable. A CREDIT display on the
back of the cabinet (the Cell) faces the player.

Same conventions and node contract as build_weapons.py (documented at the
top of weapon_kit.py): origin at the top of the grip, pointing along +Y, its
own palette (set before weapon_mats, so the shared material names stay and
every finish, cell, decal and charm works). Its moving parts are driven by
scripts/weapons/views/claw_grabber_view.gd and the reload by
scripts/weapons/reloads/claw_grabber_reload.gd:

  Claw        the claw's hub, hanging out of the chute (it flies off on a
              shot: hidden while out, reeled back in on the return)
    Prong0..2 the three prongs, each pivoting at its knuckle (open/close)
  Spool       the cable drum inside the cabinet (seen through the chute's window)
  Joystick    the joystick (pivot at its boot)
  Button      the GRAB button (presses in on a shot)
  MiniClaw    the little crane inside the prize case (rides its gantry)
  Token       a gold token for the reload (hidden; dropped into the slot)
  Lit0..13    the marquee bulbs lit (the view chases them), 7 a side
  Cell        the CREDIT display
  Trigger     the trigger

A second model, art/models/claw_grabber_claw.glb, is the claw in flight
(scripts/weapons/claw_grabber_shot.gd): the same claw at world size, hub
Claw with Prong0..2, pointing along -Z in Godot.

    python art/blender/build_weapons_claw_grabber.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403
from weapon_kit import _save  # noqa: E402

## Cabinet: base (lower box) and the glass prize case over it, and the marquee header.
CAB_X = 0.029
BASE_Y0, BASE_Y1 = -0.072, 0.092
BASE_Z0, BASE_Z1 = -0.03, 0.024
CASE_Y0, CASE_Y1 = -0.058, 0.08
CASE_Z1 = 0.078
HEAD_Z1 = 0.093
RAIL_TOP = HEAD_Z1
## The cable chute along the barrel line, and where the claw hangs.
CHUTE_Z = -0.003
CHUTE_R = 0.0175
CHUTE_Y1 = 0.142
CLAW_Y = 0.163
## The viewmodel claw's size (claw_parts scale).
CLAW_SCALE = 1.5
BULBS = 7


def palette():
    """Candy Red cabinet, Marquee Purple trim, chrome metal, Prize Pink panels."""
    mat("Shell", "#e8283f", rough=0.32)
    mat("Trim", "#5b2bb5", rough=0.36)
    mat("GunDark", "#211a33", rough=0.45, metal=0.3)
    mat("GunSteel", "#d6dbe8", rough=0.16, metal=0.92)
    mat("GunPink", "#ff6fc1", rough=0.4)


def glass(name, color, alpha):
    """Translucent tinted glass (exported with alpha blending)."""
    m = mat(name, color, rough=0.08, metal=0.0)
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Alpha"].default_value = alpha
    m.diffuse_color = (*m.diffuse_color[:3], alpha)
    if hasattr(m, "surface_render_method"):
        m.surface_render_method = "BLENDED"
    if hasattr(m, "blend_method"):
        m.blend_method = "BLEND"
    return m


def claw_parts(prefix, scale, steel, knuckle_m, tip_m):
    """A three-pronged claw pointing along +Y from its hub at the origin,
    `scale` 1 = viewmodel size. Returns (hub parts, [prong parts...], [prong pivots...])."""
    s = scale
    hub = [
        ycyl(prefix + "Hub", 0.0125 * s, 0.018 * s, 0.0, m=steel, segs=20, bevel=0.002 * s),
        ycyl(prefix + "HubCap", 0.008 * s, 0.008 * s, -0.012 * s, m=knuckle_m, segs=16, bevel=0.0015 * s),
        ring(prefix + "HubRing", 0.0128 * s, 0.0018 * s, 0.006 * s, m=knuckle_m, segs=20),
        sphere(prefix + "HubNose", 0.006 * s, (0, 0.011 * s, 0), m=steel, segs=12, rings=6),
    ]
    prongs, pivots = [], []
    for i in range(3):
        a = math.radians(90 + 120 * i)
        ca, sa = math.cos(a), math.sin(a)

        def at(radial, y, ca=ca, sa=sa):
            return (ca * radial * s, y * s, sa * radial * s)

        r0 = 0.0115
        pivot = at(r0, 0.004)
        pts = [at(r0, 0.004), at(r0 + 0.012, 0.016), at(r0 + 0.018, 0.034), at(r0 + 0.014, 0.05), at(r0 + 0.003, 0.062),
               at(r0 - 0.006, 0.066)]
        parts = [
            sphere(f"{prefix}Knuckle{i}", 0.0048 * s, pivot, m=knuckle_m, segs=12, rings=7),
            tube(f"{prefix}ProngArm{i}", pts[:4], 0.0036 * s, m=steel, segs=10, radius_end=0.0031 * s),
            tube(f"{prefix}ProngHook{i}", pts[3:], 0.0031 * s, m=steel, segs=10, radius_end=0.0017 * s),
            sphere(f"{prefix}ProngJoint{i}", 0.0038 * s, pts[3], m=knuckle_m, segs=10, rings=6),
            sphere(f"{prefix}ProngTip{i}", 0.0024 * s, pts[-1], m=tip_m, segs=8, rings=5),
        ]
        prongs.append(parts)
        pivots.append(pivot)
    return hub, prongs, pivots


def prize(name, loc, radius, body_m, ear_m):
    """A tiny round plush prize: a ball body with two ears and dot eyes."""
    x, y, z = loc
    parts = [sphere(name + "Body", radius, loc, m=body_m, segs=12, rings=8)]
    for k, side in enumerate((-1, 1)):
        parts.append(sphere(f"{name}Ear{k}", radius * 0.38, (x + side * radius * 0.62, y, z + radius * 0.78), m=ear_m, segs=8, rings=5))
    return parts


def build_claw_grabber():
    reset_scene()
    palette()
    M = weapon_mats("#38f0ff", emit=2.2)
    chrome = M["steel"]
    dark = M["dark"]
    gold = mat("TokenGold", "#ffc93c", rough=0.22, metal=0.8)
    case_glass = glass("CaseGlass", "#bfeaff", 0.22)
    bulb_dim = mat("BulbDim", "#a07a40", rough=0.35)
    bulb_lit = mat("BulbLit", "#fff0a0", rough=0.3, emit=4.5)
    button_m = mat("GrabButton", "#ff3fa0", rough=0.3, emit=1.6)
    knob_m = mat("KnobRed", "#ff3048", rough=0.25)
    slot_m = mat("SlotGlow", "#ff5a3c", rough=0.4, emit=2.4)
    plush = [mat("PlushMint", "#6ff0c0", rough=0.85), mat("PlushPink", "#ff8fd0", rough=0.85),
             mat("PlushSun", "#ffd34a", rough=0.85), mat("PlushSky", "#6fb8ff", rough=0.85)]

    grip_loc = (0, -0.034, -0.1)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.07, 0.094, 0.185), body_bottom=BASE_Z0, panel="pink")
    trig = [p for p in grip_parts if p.name in ("Trigger", "TriggerToe")]
    grip_parts = [p for p in grip_parts if p not in trig]
    for p in trig:
        p.name = "Chrome" + p.name     # the export node takes the name "Trigger"
    y_trig = G["trigger"][0]
    z_line = RAIL_TOP + SIGHT_HEIGHT
    base_cy = (BASE_Y0 + BASE_Y1) / 2
    case_cy = (CASE_Y0 + CASE_Y1) / 2
    case_len = CASE_Y1 - CASE_Y0
    case_h = CASE_Z1 - BASE_Z1

    shell = grip_parts + [
        # The lower cabinet, a purple kick plate along its foot and a chrome edge on top.
        box("Cabinet", (2 * CAB_X, BASE_Y1 - BASE_Y0, BASE_Z1 - BASE_Z0), (0, base_cy, (BASE_Z0 + BASE_Z1) / 2), bevel=0.006, m=M["shell"]),
        box("KickPlate", (2 * CAB_X + 0.002, BASE_Y1 - BASE_Y0 - 0.012, 0.011), (0, base_cy, BASE_Z0 + 0.0075), bevel=0.003, m=M["trim"]),
        box("CabinetLip", (2 * CAB_X + 0.003, BASE_Y1 - BASE_Y0 + 0.002, 0.004), (0, base_cy, BASE_Z1 - 0.001), bevel=0.0015, m=chrome),
        # The prize case: a floor, four chrome corner posts, glass all round.
        box("CaseFloor", (2 * CAB_X - 0.006, case_len - 0.006, 0.003), (0, case_cy, BASE_Z1 + 0.0015), bevel=0.001, m=dark),
    ]
    case_glass_parts = [
        box("CaseGlassL", (0.0016, case_len, case_h), (-CAB_X + 0.002, case_cy, BASE_Z1 + case_h / 2), bevel=0.0, m=case_glass),
        box("CaseGlassR", (0.0016, case_len, case_h), (CAB_X - 0.002, case_cy, BASE_Z1 + case_h / 2), bevel=0.0, m=case_glass),
        box("CaseGlassF", (2 * CAB_X - 0.004, 0.0016, case_h), (0, CASE_Y1 - 0.001, BASE_Z1 + case_h / 2), bevel=0.0, m=case_glass),
        box("CaseGlassB", (2 * CAB_X - 0.004, 0.0016, case_h), (0, CASE_Y0 + 0.001, BASE_Z1 + case_h / 2), bevel=0.0, m=case_glass),
    ]
    shell += [
        # The marquee header: purple, a chrome band, flat on top for the sights and an optic.
        box("Header", (2 * CAB_X + 0.002, CASE_Y1 - CASE_Y0 + 0.012, HEAD_Z1 - CASE_Z1), (0, case_cy, (CASE_Z1 + HEAD_Z1) / 2),
            bevel=0.003, m=M["trim"]),
        box("HeaderBand", (2 * CAB_X + 0.004, CASE_Y1 - CASE_Y0 + 0.014, 0.0022), (0, case_cy, CASE_Z1 + 0.0011), bevel=0.0008, m=chrome),
        # The gantry the mini crane rides along, under the header.
        box("GantryRail", (0.004, case_len - 0.012, 0.003), (0, case_cy, CASE_Z1 - 0.003), bevel=0.0008, m=chrome),
        # The cable chute: chrome, a purple collar, a flared mouth the claw hangs from.
        ycyl("Chute", CHUTE_R, CHUTE_Y1 - BASE_Y1 + 0.01, (CHUTE_Y1 + BASE_Y1) / 2 - 0.005, z=CHUTE_Z, m=chrome, segs=28, bevel=0.002),
        ring("ChuteCollar", CHUTE_R + 0.0012, 0.003, BASE_Y1 + 0.006, z=CHUTE_Z, m=M["trim"], segs=28),
        ring("ChuteMouth", CHUTE_R + 0.0008, 0.0032, CHUTE_Y1, z=CHUTE_Z, m=chrome, segs=28),
        ycyl("ChuteBore", 0.011, 0.004, CHUTE_Y1 + 0.0005, z=CHUTE_Z, m=dark, segs=18, bevel=0.0),
        # The cable from the chute to the claw.
        ycyl("Cable", 0.0018, CLAW_Y - CHUTE_Y1, (CLAW_Y + CHUTE_Y1) / 2, z=CHUTE_Z, m=dark, segs=8, bevel=0.0),
        # A window on top of the chute that shows the spool's stripes.
        box("SpoolWindow", (0.014, 0.026, 0.002), (0, BASE_Y1 + 0.022, CHUTE_Z + CHUTE_R - 0.0002), bevel=0.0006, m=dark),
        # The control deck on the left flank (joystick and GRAB button).
        box("Deck", (0.016, 0.06, 0.012), (-CAB_X - 0.007, 0.012, BASE_Z1 - 0.008), rot=rad(0, 18, 0), bevel=0.003, m=M["trim"]),
        box("DeckTop", (0.017, 0.056, 0.002), (-CAB_X - 0.0085, 0.012, BASE_Z1 - 0.0005), rot=rad(0, 18, 0), bevel=0.0007, m=dark),
        # The coin door on the left flank behind the deck, its lit slot and an arrow.
        box("CoinDoor", (0.002, 0.03, 0.036), (-CAB_X - 0.0009, -0.046, -0.003), bevel=0.0008, m=chrome),
        box("CoinSlot", (0.0016, 0.0035, 0.016), (-CAB_X - 0.0021, -0.046, 0.003), bevel=0.0, m=slot_m),
        box("CoinReturn", (0.0018, 0.012, 0.006), (-CAB_X - 0.0021, -0.046, -0.014), bevel=0.0008, m=dark),
        # The CREDIT plate on the back (its display is the Cell).
        box("CreditPlate", (0.04, 0.003, 0.02), (0, BASE_Y0 - 0.0012, 0.004), bevel=0.001, m=dark),
        box("ButtCap", (0.076, 0.102, 0.012), tuple(fpt(G["frame"], 0, 0, -0.185 / 2 - 0.002)), rot=(math.radians(-14), 0, 0),
            bevel=0.005, m=chrome),
    ]
    # The GRAB button's chrome bezel on the deck (ycyl builds along Y: stand it up).
    bezel = ycyl("ButtonBezel", 0.0068, 0.003, 0.0, m=chrome, segs=18, bevel=0.0008)
    bezel.location = (-CAB_X - 0.0105, 0.03, BASE_Z1 + 0.0005)
    bezel.rotation_euler = rad(90, 18, 0)
    shell.append(bezel)
    # Purple marquee stripes and the chrome screws on the cabinet flanks.
    for side in (-1, 1):
        shell.append(box(f"FlankStripe{side}", (0.0012, BASE_Y1 - BASE_Y0 - 0.02, 0.004), (side * (CAB_X + 0.0004), base_cy + 0.01, 0.012),
                         bevel=0.0, m=M["trim"]))
    shell += screws("CabScrew", [(-CAB_X - 0.0005, 0.075, -0.018), (CAB_X + 0.0005, 0.075, -0.018), (CAB_X + 0.0005, -0.062, -0.018)], chrome)
    # The marquee bulbs: dim sockets down both sides of the header (the lit ones are their own nodes).
    lit = []
    for k in range(2 * BULBS):
        side = -1 if k < BULBS else 1
        i = k % BULBS
        y = CASE_Y0 + 0.006 + i * (case_len - 0.012) / (BULBS - 1)
        p = (side * (CAB_X + 0.0016), y, (CASE_Z1 + HEAD_Z1) / 2 + 0.0008)
        shell.append(sphere(f"BulbDim{k}", 0.0042, p, scale=(0.6, 1, 1), m=bulb_dim, segs=10, rings=6))
        lit.append(([sphere(f"BulbLit{k}", 0.0048, p, scale=(0.7, 1, 1), m=bulb_lit, segs=10, rings=6)], p))
    # The prizes heaped on the case floor.
    z_floor = BASE_Z1 + 0.003
    for k, (x, y, r) in enumerate([(-0.012, -0.04, 0.0082), (0.011, -0.03, 0.0078), (-0.004, -0.016, 0.0086), (0.012, 0.0, 0.0074),
                                   (-0.013, 0.012, 0.008), (0.003, 0.026, 0.0084), (-0.01, 0.046, 0.0076), (0.011, 0.056, 0.0078),
                                   (0.0, 0.066, 0.007)]):
        m = plush[k % len(plush)]
        shell += prize(f"Prize{k}", (x, y, z_floor + r * 0.9 + (0.004 if k % 3 == 1 else 0.0)), r, m, plush[(k + 2) % len(plush)])
    lug, charm_point = charm_lug(CAB_X, 0.048, -0.014, M, out=1.0)
    shell += lug
    sight_rear, sight_front = sights_notch(0.0, CASE_Y0 + 0.004, CASE_Y1 - 0.004, RAIL_TOP, RAIL_TOP, z_line, M, gap=0.015)

    # The big claw on its cable at the muzzle.
    hub, prongs, pivots = claw_parts("Big", CLAW_SCALE, chrome, M["trim"], M["cell"])
    for ob in hub + [p for ps in prongs for p in ps]:
        ob.location = (ob.location[0], ob.location[1] + CLAW_Y, ob.location[2] + CHUTE_Z)
    claw_c = (0, CLAW_Y, CHUTE_Z)

    # The cable spool inside the chute's root (its stripes show through the window).
    spool = [xcyl("SpoolDrum", 0.0105, 0.02, (0, BASE_Y1 + 0.022, CHUTE_Z), m=chrome, segs=20)]
    for k in range(6):
        a = math.tau * k / 6
        spool.append(box(f"SpoolStripe{k}", (0.021, 0.003, 0.0016), (0, BASE_Y1 + 0.022 + math.cos(a) * 0.0108, CHUTE_Z + math.sin(a) * 0.0108),
                         rot=(a, 0, 0), bevel=0.0, m=M["trim"]))

    # The joystick: a chrome stick in a rubber boot, a red ball knob.
    jx, jy, jz = -CAB_X - 0.011, -0.006, BASE_Z1 + 0.001
    joystick = [
        sphere("JoyBoot", 0.0062, (jx, jy, jz + 0.002), scale=(1, 1, 0.7), m=dark, segs=14, rings=7),
        tube("JoyStick", [(jx, jy, jz), (jx, jy, jz + 0.026)], 0.0022, m=chrome, segs=10),
        sphere("JoyKnob", 0.0072, (jx, jy, jz + 0.031), m=knob_m, segs=16, rings=10),
    ]
    button = [ycyl("GrabCap", 0.0052, 0.004, 0.0, m=button_m, segs=18, bevel=0.0012)]
    button[0].location = (-CAB_X - 0.0108, 0.03, BASE_Z1 + 0.003)
    button[0].rotation_euler = rad(90, 18, 0)
    btn_c = (-CAB_X - 0.0108, 0.03, BASE_Z1 + 0.003)

    # The mini crane in the prize case: a trolley on the gantry, a thread, a tiny claw.
    mx, my, mz = 0.0, case_cy + 0.01, CASE_Z1 - 0.006
    mini = [box("MiniTrolley", (0.008, 0.01, 0.004), (mx, my, mz), bevel=0.001, m=chrome),
            ycyl("MiniThread", 0.0006, 0.018, 0.0, m=dark, segs=6, bevel=0.0)]
    mini[1].location = (mx, my, mz - 0.011)
    mini[1].rotation_euler = rad(90, 0, 0)
    mhub, mprongs, _mp = claw_parts("Mini", 0.36, chrome, M["trim"], chrome)
    turn_down = Matrix.Translation(Vector((mx, my, mz - 0.022))) @ Matrix.Rotation(math.radians(-90), 4, "X")
    bpy.context.view_layer.update()
    for ob in mhub + [p for ps in mprongs for p in ps]:
        ob.matrix_world = turn_down @ ob.matrix_world
        mini.append(ob)

    # The reload's token: a gold coin with a star, edge on to the flank so it fits the slot (faces along Y).
    token = [ycyl("TokenDisc", 0.0105, 0.0024, 0.0, m=gold, segs=24, bevel=0.0006),
             star("TokenStarB", 0.0058, 0.0008, (0, -0.0014, 0), rot=rad(90, 0, 0), m=M["trim"], inner=0.0026),
             star("TokenStarF", 0.0058, 0.0008, (0, 0.0014, 0), rot=rad(90, 0, 0), m=M["trim"], inner=0.0026)]
    token_c = (-CAB_X - 0.002, -0.046, 0.003)
    for ob in token:
        ob.location = (ob.location[0] + token_c[0], ob.location[1] + token_c[1], ob.location[2] + token_c[2])

    cell = [box("CreditScreen", (0.032, 0.002, 0.012), (0, BASE_Y0 - 0.0028, 0.004), bevel=0.0006, m=M["cell"])]
    decal = [side_emblem("Emblem", star_outline(0.011, 0.005), CAB_X + 0.0003, -0.028, -0.008, M["decal"], depth=0.004)]
    arm_r, elbow_r = firing_hand(G, M, (0.42, -0.5, -0.36))
    arm_l, elbow_l = cup_hand(G, M, (-0.55, -0.32, -0.32))
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "Glass": (case_glass_parts, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, CASE_Y0 + 0.004, RAIL_TOP), None),
        "IronSightFront": (sight_front, (0, CASE_Y1 - 0.004, RAIL_TOP), None),
        "Claw": (hub, claw_c, None),
        "Spool": (spool, (0, BASE_Y1 + 0.022, CHUTE_Z), None),
        "Joystick": (joystick, (jx, jy, jz), None),
        "Button": (button, btn_c, None),
        "MiniClaw": (mini, (mx, my, mz), None),
        "Token": (token, token_c, None),
        "Cell": (cell, (0, BASE_Y0 - 0.0028, 0.004), None),
        "Trigger": (trig, (0, y_trig, -0.03), None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, grip_loc, None),
    }
    for i, parts in enumerate(prongs):
        p = pivots[i]
        groups[f"Prong{i}"] = (parts, (p[0], p[1] + CLAW_Y, p[2] + CHUTE_Z), "Claw")
    for k, (parts, p) in enumerate(lit):
        groups[f"Lit{k}"] = (parts, p, None)
    empties = {
        "Muzzle": ((0, CLAW_Y, CHUTE_Z), None),
        "SightPoint": ((0, CASE_Y0 + 0.004, z_line), None),
        "SightMount": ((0, case_cy, RAIL_TOP), None),
        "EjectPoint": ((-CAB_X - 0.004, -0.046, 0.003), None),
        "VentPoint": ((0, BASE_Y1 + 0.022, CHUTE_Z + CHUTE_R), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish_clear("claw_grabber", groups, empties)


def finish_clear(name, groups, empties):
    """weapon_kit.finish, except that the case glass is not an occluder in the
    baked shading (the prizes behind it stay lit) and is not shaded itself."""
    exports = {}
    for key, (parts, pivot, parent_name) in groups.items():
        if not parts:
            continue
        parent = exports.get(parent_name) if parent_name else None
        exports[key] = merge(key, [p for p in parts if "glove_kit" not in p], pivot=pivot, parent=parent)
        for shape in GLOVE_KITS:
            kit = [p for p in parts if p.get("glove_kit") == shape]
            if kit:
                exports[f"{key}Kit{shape}"] = merge(f"{key}Kit{shape}", kit, pivot=pivot, parent=exports[key])
    for key, (loc, parent_name) in empties.items():
        exports[key] = empty(key, loc, parent=exports.get(parent_name) if parent_name else None)
    bpy.context.view_layer.update()
    meshes = {k: ob for k, ob in exports.items() if ob.type == "MESH" and k not in ("Decal", "Glass")}
    body = [ob for k, ob in meshes.items() if not k.startswith("Arm")]
    bake_shading(body, body)
    arms = [ob for k, ob in meshes.items() if k.startswith("Arm") and "Kit" not in k]
    bake_shading(arms, body + arms, strength=0.42, gradient=0.0)
    for k, ob in meshes.items():
        if k.startswith("Arm") and "Kit" in k:
            bake_shading([ob], body + arms + [ob], strength=0.42, gradient=0.0)
    _save(name, list(exports.values()))


def build_flying_claw():
    """The claw in flight (ClawGrabberShot): claw_parts at 4.2 times its base size,
    hub at the origin, prongs open along +Y (Godot -Z)."""
    reset_scene()
    chrome = mat("ClawChrome", "#e4e8f2", rough=0.14, metal=0.92)
    purple = mat("ClawPurple", "#7a3cf0", rough=0.32)
    tip = mat("ClawTip", "#38f0ff", rough=0.3, emit=2.4)
    hub, prongs, pivots = claw_parts("Fly", 4.2, chrome, purple, tip)
    exports = [merge("Claw", hub)]
    for i, parts in enumerate(prongs):
        exports.append(merge(f"Prong{i}", parts, pivot=pivots[i], parent=exports[0]))
    _save("claw_grabber_claw", exports)


BUILDERS = (
    ("claw_grabber", build_claw_grabber),
    ("claw_grabber_claw", build_flying_claw),
)

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for name, fn in BUILDERS:
        if not only or name in only:
            fn()
