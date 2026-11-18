"""First-person viewmodel of the Coin-Op (coin_op), the arcade token machine
pistol: a cobalt mini arcade cabinet with a lit magenta marquee head at the
back, an open coin tube of brass tokens along its top-left shoulder (the
magazine, fed through an INSERT COIN slot at its back), a coin mech star
wheel on the deck, a flat brass coin-chute muzzle, a score screen on the
cabinet's back (the side the player sees) with a red TILT lamp and three
CREDIT lamps, and a coin-return cup with a slap paddle under the nose.

Same conventions and node contract as build_weapons.py (documented at the top
of weapon_kit.py): origin at the top of the grip, pointing along +Y, its own
palette (set before weapon_mats, so the shared material names stay and every
finish, cell, decal and charm works), built-in pistol sights: the rail rides
on the marquee head, the front post on the chute. Moving parts, driven by
scripts/weapons/views/coin_op_view.gd and
scripts/weapons/reloads/coin_op_reload.gd:

  Token0..14   the brass tokens standing in the coin tube, Token0 at the
               front (one per two rounds; the view hides the spent ones)
  Wheel        the coin mech star wheel (axle along X; a notch per shot)
  Cell         the glowing lip of the INSERT COIN slot on the tube's back cap
  TiltGlow     the lit TILT lamp on the back screen (shown while tilted)
  Credit0..2   the lit CREDIT lamps (kills toward the next Free Play token)
  ReturnButton the pink coin-return paddle under the cup (slapped in the reload)
  ReturnFlap   the coin-return cup's flap (pivot at its hinge)
  CellHolo     the hologram token roll's back half, CapsulesHolo its front
               half (the reload breaks the roll open over the slot)
  FeedHolo     a short stack of hologram tokens that drops into the slot

    python art/blender/build_weapons_coin_op.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403

## Tokens in the tube, their radius, thickness and pitch along the tube.
TOKENS = 15
TOKEN_R = 0.0158
TOKEN_T = 0.0066
TOKEN_PITCH = 0.0104
## The tube's axis (x, z) along the top-left shoulder and the y of its front token.
TUBE_X = -0.036
TUBE_Z = 0.083
TUBE_FRONT = 0.19
## The INSERT COIN slot on top of the tube's back cap (centre, top surface).
SLOT = (TUBE_X, 0.04, 0.104)
## The roll of tokens the reload breaks open: radius, half length.
ROLL_R = 0.019
ROLL_HALF = 0.034
CREDITS = 3


def palette():
    """The shared weapon materials in this weapon's colours (weapon_mats reuses them)."""
    mat("Shell", "#2f49d8", rough=0.32)
    mat("Trim", "#ffc23d", rough=0.34)
    mat("GunDark", "#1d1834", rough=0.55, metal=0.1)
    mat("GunSteel", "#ffd36b", rough=0.28, metal=0.6)
    mat("GunPink", "#ff3d8a", rough=0.36)


def token(name, y, m_face, m_rim, x=TUBE_X, z=TUBE_Z):
    """One brass token standing in the tube (axis along Y): a disc with a raised rim."""
    return [
        ycyl(name + "Face", TOKEN_R, TOKEN_T, y, z=z, x=x, m=m_face, segs=20, bevel=0.0012),
        ring(name + "Rim", TOKEN_R - 0.0012, 0.0016, y, z=z, x=x, m=m_rim, segs=20),
    ]


def build_coin_op():
    reset_scene()
    palette()
    M = weapon_mats("#ff5ad1", emit=2.3)
    brass = mat("Token", "#ffc93c", rough=0.24, metal=0.85)
    brass_rim = mat("TokenRim", "#d98a1c", rough=0.3, metal=0.8)
    marquee = mat("Marquee", "#ff5ad1", rough=0.3, emit=1.6)
    lamp_off = mat("TiltOff", "#6a1020", rough=0.25)
    tilt_on = mat("TiltOn", "#ff2a2a", rough=0.2, emit=3.2)
    credit_off = mat("CreditOff", "#1f3a1c", rough=0.3)
    credit_on = mat("CreditOn", "#8dff3a", rough=0.25, emit=2.6)
    bore = mat("Bore", "#120d20", rough=0.9)
    cream = mat("Lettering", "#fff1c8", rough=0.4, emit=0.6)

    grip_size = (0.066, 0.088, 0.178)
    grip_tilt = -16.0
    grip_loc = (0, -0.02, -0.1)
    grip_parts, G = grip("", grip_loc, M, tilt=grip_tilt, size=grip_size, body_bottom=-0.02, panel="trim")
    head_top = 0.104
    rail_top = head_top + 0.014
    z_line = rail_top + SIGHT_HEIGHT
    chute_z = 0.03
    tube_back = TUBE_FRONT - TOKEN_PITCH * (TOKENS - 1)

    shell = grip_parts + [
        # The cabinet: a cobalt slab with a chamfered nose and a dark belly.
        side_profile("Body", [(-0.082, -0.02), (0.196, -0.02), (0.208, -0.004), (0.208, 0.05), (0.196, 0.062), (-0.082, 0.062)],
                     0.068, (0, 0, 0), M["shell"], bevel=0.012, segs=3),
        box("Belly", (0.072, 0.22, 0.014), (0, 0.06, -0.014), bevel=0.005, m=M["dark"]),
        # The marquee head at the back: a raised cabinet top that carries the rail.
        box("Head", (0.07, 0.11, head_top - 0.056), (0, -0.031, (head_top + 0.056) / 2), bevel=0.01, segs=3, m=M["shell"]),
        box("HeadCap", (0.072, 0.008, head_top - 0.05), (0, -0.086, (head_top + 0.05) / 2), bevel=0.003, m=M["dark"]),
        # The cabinet's back (the side the player sees): a score screen with
        # the TILT lamp and the three CREDIT lamps.
        box("Screen", (0.056, 0.004, 0.036), (0, -0.0905, 0.079), bevel=0.0015, m=mat("Screen", "#1a1240", rough=0.2, emit=0.5, emit_color="#3a2a8a")),
        box("ScreenFrame", (0.062, 0.003, 0.042), (0, -0.0895, 0.079), bevel=0.002, m=M["trim"]),
        # The lit marquee panels down both sides of the head, with chaser bands.
        box("MarqueeL", (0.004, 0.084, 0.026), (-0.0355, -0.031, 0.085), bevel=0.0015, m=marquee),
        box("MarqueeR", (0.004, 0.084, 0.026), (0.0355, -0.031, 0.085), bevel=0.0015, m=marquee),
        box("MarqueeTrimL", (0.005, 0.09, 0.004), (-0.036, -0.031, 0.0995), bevel=0.001, m=M["trim"]),
        box("MarqueeTrimL2", (0.005, 0.09, 0.004), (-0.036, -0.031, 0.0705), bevel=0.001, m=M["trim"]),
        box("MarqueeTrimR", (0.005, 0.09, 0.004), (0.036, -0.031, 0.0995), bevel=0.001, m=M["trim"]),
        box("MarqueeTrimR2", (0.005, 0.09, 0.004), (0.036, -0.031, 0.0705), bevel=0.001, m=M["trim"]),
        text("CoinOpL", "COIN-OP", 0.016, 0.0016, (-0.0385, -0.031, 0.0852), rot=rad(0, 0, -90), m=cream),
        text("CoinOpR", "COIN-OP", 0.016, 0.0016, (0.0385, -0.031, 0.0852), rot=rad(0, 0, 90), m=cream),
        # The deck: a gold kick plate, the INSERT COIN bezel and the star wheel's housing.
        box("DeckPlate", (0.05, 0.13, 0.004), (0.006, 0.105, 0.063), bevel=0.0015, m=M["trim"]),
        box("SlotBezel", (0.03, 0.02, 0.01), (SLOT[0], SLOT[1], SLOT[2] - 0.003), bevel=0.003, m=M["steel"]),
        box("SlotMouth", (0.022, 0.0055, 0.006), (SLOT[0], SLOT[1], SLOT[2] + 0.0005), bevel=0.001, m=bore),
        box("WheelHousing", (0.03, 0.05, 0.012), (0.016, 0.125, 0.066), bevel=0.004, m=M["dark"]),
        # A lit INSERT COIN strip down the left flank.
        box("CoinStrip", (0.003, 0.15, 0.006), (-0.0352, 0.1, 0.038), bevel=0.001, m=M["cell"]),
        # The coin chute muzzle: a flat brass mouth with a dark slot and a magenta lip.
        box("Chute", (0.062, 0.036, 0.04), (0, 0.222, chute_z), bevel=0.01, segs=3, m=M["trim"]),
        box("ChuteLip", (0.07, 0.01, 0.048), (0, 0.242, chute_z), bevel=0.006, segs=3, m=M["pink"]),
        box("ChuteMouth", (0.044, 0.006, 0.012), (0, 0.2465, chute_z), bevel=0.002, m=bore),
        box("ChuteHump", (0.026, 0.03, 0.03), (0, 0.205, 0.068), bevel=0.008, m=M["shell"]),
        # The coin tube's sockets in the flank (the tube itself is its own parts below).
        box("TubeBed", (0.03, TUBE_FRONT - tube_back + 0.03, 0.012), (TUBE_X + 0.004, (TUBE_FRONT + tube_back) / 2, 0.064), bevel=0.004, m=M["dark"]),
        # The coin return: a hood over the cup under the nose, and the button's bezel.
        box("ReturnHood", (0.05, 0.034, 0.014), (0, 0.18, -0.026), bevel=0.005, m=M["dark"]),
        box("ReturnCup", (0.044, 0.03, 0.012), (0, 0.18, -0.038), bevel=0.004, m=M["steel"]),
        # The TILT lamp's bezel on the back screen.
        box("TiltBezel", (0.036, 0.004, 0.014), (0, -0.0925, 0.0895), bevel=0.0015, m=M["dark"]),
    ]
    # A chequered arcade band round the cabinet's waist.
    for side in (-1, 1):
        for i in range(8):
            shell.append(box(f"Check{side}{i}", (0.003, 0.012, 0.006), (side * 0.0352, -0.075 + i * 0.0125, 0.003 + (0.006 if i % 2 else 0.0)),
                             bevel=0.0, m=M["trim"] if i % 2 else M["pink"]))
    shell += bolts("Pin", [(0.036, 0.06, 0.03), (0.036, -0.01, 0.03), (-0.036, -0.064, 0.03)], M["steel"], radius=0.0055, height=0.006)
    shell += top_rail("TopRail", -0.08, 0.03, rail_top, M, width=0.03)
    lug, charm_point = charm_lug(0.036, 0.222, 0.03, M, out=1.0)
    shell += lug
    sight_rear, sight_front = sights_notch(0.0, -0.083, 0.205, rail_top, 0.083, z_line, M, gap=0.015)

    # The coin tube: brass end caps and three chrome rods, open so the tokens show.
    ty = (TUBE_FRONT + tube_back) / 2
    tlen = TUBE_FRONT - tube_back + 0.026
    shell += [
        ycyl("TubeCapF", TOKEN_R + 0.005, 0.008, TUBE_FRONT + 0.012, z=TUBE_Z, x=TUBE_X, m=M["trim"], segs=22),
        ycyl("TubeCapB", TOKEN_R + 0.005, 0.008, tube_back - 0.012, z=TUBE_Z, x=TUBE_X, m=M["trim"], segs=22),
        ycyl("TubeSpring", TOKEN_R * 0.55, 0.006, tube_back - 0.006, z=TUBE_Z, x=TUBE_X, m=M["steel"], segs=14),
    ]
    for k, a in enumerate((70, 180, 290)):
        r = TOKEN_R + 0.0035
        shell.append(ycyl(f"TubeRod{k}", 0.0022, tlen, ty, z=TUBE_Z + math.sin(math.radians(a)) * r,
                          x=TUBE_X + math.cos(math.radians(a)) * r, m=M["steel"], segs=8, bevel=0.0))

    tokens = {}
    for i in range(TOKENS):
        y = TUBE_FRONT - i * TOKEN_PITCH
        tokens[f"Token{i}"] = (token(f"Token{i}", y, brass, brass_rim), (TUBE_X, y, TUBE_Z))

    # The coin mech star wheel: eight brass teeth round a magenta hub.
    wc = (0.016, 0.125, 0.068)
    wheel = [xcyl("WheelDisc", 0.016, 0.02, wc, m=M["dark"], segs=24), xcyl("WheelHub", 0.007, 0.024, wc, m=M["pink"], segs=14)]
    for k in range(8):
        a = math.tau * k / 8
        wheel.append(obox(f"WheelTooth{k}", (0.018, 0.008, 0.008), (wc[0], wc[1] + math.cos(a) * 0.017, wc[2] + math.sin(a) * 0.017),
                          (1, 0, 0), (0, math.cos(a), math.sin(a)), bevel=0.002, m=M["steel"]))

    slot_glow = [box("SlotLip", (0.026, 0.01, 0.003), (SLOT[0], SLOT[1], SLOT[2] + 0.0065), bevel=0.001, m=M["cell"])]
    tilt_c = (0, -0.0945, 0.0895)
    tilt_lamp = [box("TiltLamp", (0.03, 0.003, 0.009), tilt_c, bevel=0.0012, m=lamp_off)]
    tilt_glow = [box("TiltGlowBar", (0.031, 0.0036, 0.0098), (tilt_c[0], tilt_c[1] - 0.0004, tilt_c[2]), bevel=0.0013, m=tilt_on),
                 text("TiltText", "TILT", 0.0085, 0.0008, (tilt_c[0], tilt_c[1] - 0.0024, tilt_c[2] - 0.0002), rot=rad(0, 0, 0), m=mat("TiltInk", "#3a0008", rough=0.5))]
    shell += tilt_lamp
    credits = {}
    for i in range(CREDITS):
        c = (-0.015 + i * 0.015, -0.0928, 0.071)
        shell.append(sphere(f"CreditOff{i}", 0.0048, c, scale=(1, 0.5, 1), m=credit_off, segs=12, rings=6))
        credits[f"Credit{i}"] = ([sphere(f"CreditLamp{i}", 0.0053, (c[0], c[1] - 0.0004, c[2]), scale=(1, 0.55, 1), m=credit_on, segs=12, rings=6)], c)

    button_c = (0, 0.178, -0.047)
    button = [box("ButtonPaddle", (0.032, 0.022, 0.006), button_c, bevel=0.0025, m=M["pink"]),
              box("ButtonRib", (0.024, 0.004, 0.003), (0, 0.17, -0.0505), bevel=0.001, m=M["trim"])]
    flap_c = (0, 0.195, -0.032)
    flap = [box("FlapPlate", (0.04, 0.004, 0.016), (0, 0.196, -0.04), bevel=0.0015, m=M["pink"]),
            xcyl("FlapPin", 0.0025, 0.042, flap_c, m=M["steel"], segs=8)]

    # The hologram roll (two halves) and the short stack that drops into the slot.
    roll_c = (SLOT[0], SLOT[1], SLOT[2] + 0.075)
    holo = mat("Holo")
    roll_back = [ycyl("RollB", ROLL_R, ROLL_HALF, roll_c[1] - ROLL_HALF / 2, z=roll_c[2], x=roll_c[0], m=holo, segs=20, bevel=0.003),
                 ring("RollBCrimp", ROLL_R - 0.002, 0.003, roll_c[1] - ROLL_HALF + 0.002, z=roll_c[2], x=roll_c[0], m=holo, segs=20)]
    roll_front = [ycyl("RollF", ROLL_R, ROLL_HALF, roll_c[1] + ROLL_HALF / 2, z=roll_c[2], x=roll_c[0], m=holo, segs=20, bevel=0.003),
                  ring("RollFCrimp", ROLL_R - 0.002, 0.003, roll_c[1] + ROLL_HALF - 0.002, z=roll_c[2], x=roll_c[0], m=holo, segs=20)]
    feed_c = (SLOT[0], SLOT[1], SLOT[2] + 0.03)
    feed = []
    for k in range(5):
        feed.append(ycyl(f"Feed{k}", TOKEN_R * 0.95, TOKEN_T, SLOT[1] - 0.024 + k * 0.012, z=feed_c[2], x=SLOT[0], m=holo, segs=18, bevel=0.001))

    decal = [side_emblem("Emblem", star_outline(0.014, 0.006), 0.034, 0.075, 0.03, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.42, -0.5, -0.36))
    arm_l, elbow_l = cup_hand(G, M, (-0.55, -0.32, -0.32))
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.083, rail_top), None),
        "IronSightFront": (sight_front, (0, 0.205, 0.083), None),
        "Wheel": (wheel, wc, None),
        "Cell": (slot_glow, (SLOT[0], SLOT[1], SLOT[2] + 0.0065), None),
        "TiltGlow": (tilt_glow, tilt_c, None),
        "ReturnButton": (button, button_c, None),
        "ReturnFlap": (flap, flap_c, None),
        "CellHolo": (roll_back, roll_c, None),
        "CapsulesHolo": (roll_front, roll_c, None),
        "FeedHolo": (feed, feed_c, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, grip_loc, None),
    }
    for name, (parts, pivot) in tokens.items():
        groups[name] = (parts, pivot, None)
    for name, (parts, pivot) in credits.items():
        groups[name] = (parts, pivot, None)
    empties = {
        "Muzzle": ((0, 0.25, chute_z), None),
        "SightPoint": ((0, -0.083, z_line), None),
        "SightMount": ((0, -0.02, rail_top), None),
        "EjectPoint": ((SLOT[0], SLOT[1], SLOT[2] + 0.008), None),
        "VentPoint": ((0, 0.18, -0.044), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("coin_op", groups, empties)


if __name__ == "__main__":
    build_coin_op()
