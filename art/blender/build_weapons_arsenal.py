"""First-person viewmodels for the Arsenal weapons (unlocked by player level).

Same conventions and node contract as build_weapons.py (the contract is
documented at the top of weapon_kit.py): origin at the top of the grip,
pointing along +Y, cream/purple shell family. Each weapon has its own
silhouette, built-in sights and accent ("Cell") colour, plus extra animated
parts that its reload script registers (scripts/weapons/reloads/):

  comet_cannon   amber   Crane > Cylinder > Cell/CellHolo (rounds), Hammer
  arc_coil       lime    Prongs, Vents, Cell (Tesla capsule on the left flank), CellHolo
  bumper_lobber  magenta Lid, Crank, Cell (gumballs), CellHolo
  cryo_beam      ice     Panel (tank clamps), Needle, Fins, Cell (cryo tank), CellHolo
  rail_lancer    crimson Rails, Cell (capacitor), CellHolo

    python art/blender/build_weapons_arsenal.py [weapon_id ...]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403


def hanger_block(wall_x, side_x, y, z, M):
    """Fills the step between a narrow stock side and the weapon's widest side,
    so the charm lug can stand on it."""
    width = abs(wall_x - side_x) + 0.008
    return [box("CharmBlock", (width, 0.044, 0.034), ((wall_x + side_x) / 2 + 0.004, y, z + 0.004), bevel=0.006, m=M["trim"])]


# ---------------------------------------------------------------------------
# Comet Hand Cannon: burst-fire heavy revolver
# ---------------------------------------------------------------------------

def build_comet_cannon():
    reset_scene()
    M = weapon_mats("#ff8a14", emit=2.0)
    bore_z = 0.094
    cyl_c = (0, 0.06, 0.066)
    grip_loc = (0, -0.034, -0.1)
    grip_parts, G = grip("", grip_loc, M, tilt=-17, size=(0.072, 0.094, 0.185), body_bottom=-0.028)
    rail_top = 0.142
    z_line = rail_top + SIGHT_HEIGHT
    shell = grip_parts + [
        # Frame: rear block, lower bridge under the cylinder, top strap over it.
        box("FrameRear", (0.066, 0.05, 0.12), (0, -0.04, 0.058), bevel=0.018, m=M["trim"]),
        box("FrameLow", (0.07, 0.2, 0.036), (0, 0.055, -0.01), bevel=0.016, m=M["trim"]),
        box("TopStrap", (0.056, 0.17, 0.02), (0, 0.055, 0.136), bevel=0.008, m=M["trim"]),
        box("FramePlate", (0.067, 0.05, 0.05), (0, -0.04, 0.03), bevel=0.012, m=M["shell"]),
        box("RecoilShield", (0.064, 0.012, 0.11), (0, -0.004, 0.066), bevel=0.004, m=M["dark"]),
        side_profile("Beavertail", [(-0.03, 0.02), (-0.03, -0.024), (-0.06, -0.024), (-0.088, -0.006), (-0.088, 0.008), (-0.064, 0.02)],
                     0.054, (0, 0, 0), M["trim"], bevel=0.006),
        # Burst counter on the back of the frame: three amber pips.
        box("PipPlate", (0.05, 0.012, 0.026), (0, -0.068, 0.085), bevel=0.006, m=M["dark"]),
        box("SideStripe", (0.004, 0.13, 0.012), (-0.038, 0.06, 0.012), bevel=0.0, m=M["cell"]),
        box("SideStripeR", (0.004, 0.13, 0.012), (0.038, 0.06, 0.012), bevel=0.0, m=M["cell"]),
        # Barrel: heavy cream shroud, dark underlug with an amber light strip.
        side_profile("Barrel", [(0.118, 0.052), (0.39, 0.052), (0.418, 0.068), (0.418, 0.112), (0.392, 0.128), (0.118, 0.128)], 0.064, (0, 0, 0), M["shell"], bevel=0.01),
        box("Underlug", (0.05, 0.25, 0.034), (0, 0.27, 0.04), bevel=0.014, m=M["dark"]),
        box("LugLightL", (0.004, 0.2, 0.009), (-0.026, 0.27, 0.04), bevel=0.0, m=M["cell"]),
        box("LugLightR", (0.004, 0.2, 0.009), (0.026, 0.27, 0.04), bevel=0.0, m=M["cell"]),
        box("BarrelBand", (0.07, 0.03, 0.084), (0, 0.15, 0.09), bevel=0.012, m=M["trim"]),
        box("BarrelBandF", (0.07, 0.022, 0.084), (0, 0.37, 0.09), bevel=0.01, m=M["trim"]),
        # Comet muzzle: dark crown, amber emitter ring and swept tail fins.
        ycyl("Crown", 0.036, 0.036, 0.43, z=bore_z, m=M["dark"], segs=18),
        ring("Emitter", 0.024, 0.006, 0.45, z=bore_z, m=M["cell"]),
        ycyl("Bore", 0.017, 0.01, 0.446, z=bore_z, m=mat("Bore", "#120c22", rough=0.9), segs=12, bevel=0.0),
        # Ejector rod housing tip and a cylinder release button.
        ycyl("EjectorTip", 0.012, 0.02, 0.4, z=0.04, m=M["steel"], segs=10),
        box("Release", (0.012, 0.018, 0.016), (-0.042, -0.012, 0.09), bevel=0.004, m=M["cell"]),
    ]
    shell += top_rail("TopRail", 0.165, 0.355, rail_top, M, width=0.034)
    for i in range(4):
        for side in (-1, 1):
            shell.append(box(f"PortSlit{i}{side}", (0.004, 0.022, 0.012), (side * 0.0325, 0.2 + i * 0.04, 0.105), rot=rad(20, 0, 0), bevel=0.0, m=M["cell"]))
    for i in range(3):
        shell.append(box(f"Pip{i}", (0.011, 0.008, 0.011), (-0.015 + i * 0.015, -0.075, 0.085), bevel=0.002, m=M["cell"]))
    for i, a in enumerate((90, 210, 330)):
        r = math.radians(a)
        shell.append(box(f"TailFin{i}", (0.01, 0.07, 0.03), (math.cos(r) * 0.042, 0.41, bore_z + math.sin(r) * 0.042),
                         rot=(math.radians(14), -r + math.pi / 2, 0), bevel=0.004, m=M["shell"]))
    shell += bolts("Pin", [(-0.036, -0.05, 0.03), (-0.036, -0.05, 0.1), (-0.036, 0.12, -0.01), (0.036, -0.05, 0.03), (0.036, 0.12, -0.01)], M["steel"], radius=0.006, height=0.007)
    lug, charm_point = charm_lug(-0.032, 0.28, 0.07, M)
    shell += lug
    sight_rear, sight_front = sights_notch(0.0, -0.018, 0.384, 0.144, 0.128, z_line, M, gap=0.014)

    hammer = [
        box("HammerBody", (0.024, 0.032, 0.04), (0, -0.075, 0.12), bevel=0.006, m=M["dark"]),
        box("HammerSpur", (0.03, 0.03, 0.012), (0, -0.092, 0.138), rot=rad(-25, 0, 0), bevel=0.004, m=M["steel"]),
        sphere("HammerGlow", 0.007, (0, -0.088, 0.122), m=M["cell"], segs=8, rings=5),
    ]
    crane_pivot = (-0.028, 0.06, 0.012)
    crane = [box("CraneYoke", (0.016, 0.006, 0.07), (-0.014, 0.1145, 0.04), bevel=0.002, m=M["steel"]),
             ycyl("CranePin", 0.007, 0.115, 0.06, z=crane_pivot[2], x=crane_pivot[0], m=M["steel"], segs=8, bevel=0.002)]
    cylinder = [
        ycyl("CylBody", 0.06, 0.1, cyl_c[1], z=cyl_c[2], m=M["trim"], segs=24, bevel=0.014),
        ycyl("CylCore", 0.016, 0.116, cyl_c[1], z=cyl_c[2], m=M["steel"], segs=12),
        ycyl("CylStar", 0.022, 0.006, cyl_c[1] - 0.056, z=cyl_c[2], m=M["steel"], segs=6, bevel=0.0),
        ring("CylBandA", 0.0605, 0.003, cyl_c[1] - 0.03, z=cyl_c[2], m=M["steel"], segs=24),
        ring("CylBandB", 0.0605, 0.003, cyl_c[1] + 0.03, z=cyl_c[2], m=M["steel"], segs=24),
    ]
    rounds = []
    for k in range(6):
        a = math.tau * k / 6 + math.pi / 2
        cx, cz = math.cos(a) * 0.036, cyl_c[2] + math.sin(a) * 0.036
        # Flutes between the chambers, a comet core in each chamber.
        b = a + math.tau / 12
        cylinder.append(box(f"Flute{k}", (0.013, 0.07, 0.01), (math.cos(b) * 0.057, cyl_c[1], cyl_c[2] + math.sin(b) * 0.057),
                            rot=(0, -b + math.pi / 2, 0), bevel=0.003, m=M["cell"]))
        rounds.append(ycyl(f"Round{k}", 0.0135, 0.108, cyl_c[1], z=cz, x=cx, m=M["cell"], segs=10, bevel=0.003))
        rounds.append(ycyl(f"RoundRim{k}", 0.016, 0.008, cyl_c[1] - 0.052, z=cz, x=cx, m=M["steel"], segs=10, bevel=0.002))
    rounds_holo = holo_copy(rounds)
    rounds_holo.append(torus("LoaderRing", 0.046, 0.006, (0, cyl_c[1] - 0.064, cyl_c[2]), rot=rad(90, 0, 0), m=mat("Holo"), major_segs=20, minor_segs=5))

    star = [(0.0, 0.03), (0.009, 0.009), (0.03, 0.0), (0.009, -0.009), (0.0, -0.03), (-0.009, -0.009), (-0.03, 0.0), (-0.009, 0.009)]
    decal = [side_emblem("Emblem", star, -0.0335, 0.225, 0.09, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.42, -0.5, -0.36))
    arm_l, elbow_l = cup_hand(G, M, (-0.55, -0.32, -0.32))
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.018, 0.144), None),
        "IronSightFront": (sight_front, (0, 0.384, 0.128), None),
        "Hammer": (hammer, (0, -0.07, 0.1), None),
        "Crane": (crane, crane_pivot, None),
        "Cylinder": (cylinder, cyl_c, "Crane"),
        "Cell": (rounds, cyl_c, "Cylinder"),
        "CellHolo": (rounds_holo, cyl_c, "Cylinder"),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, grip_loc, None),
    }
    empties = {
        "Muzzle": ((0, 0.458, bore_z), None),
        "SightPoint": ((0, -0.018, z_line), None),
        "SightMount": ((0, 0.24, rail_top), None),
        "EjectPoint": ((-0.06, -0.01, 0.05), None),
        "VentPoint": ((0, 0.27, 0.15), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("comet_cannon", groups, empties)


# ---------------------------------------------------------------------------
# Arc Coil: Tesla thrower with a chaining arc
# ---------------------------------------------------------------------------

def build_arc_coil():
    reset_scene()
    M = weapon_mats("#7dff2e", emit=1.9)
    copper = mat("Copper", "#e2894a", rough=0.32, metal=0.7)
    ceramic = mat("Ceramic", "#fbf3e6", rough=0.25)
    bore_z = 0.045
    # The Tesla capsule stands in a cradle on the left flank, below the sight line.
    tower = (-0.128, 0.075, -0.034)
    grip_loc = (0, -0.03, -0.115)
    grip_parts, G = grip("", grip_loc, M, tilt=-13, size=(0.075, 0.095, 0.19), body_bottom=-0.025, guard_len=0.09)
    rail_top = 0.119
    z_line = rail_top + SIGHT_HEIGHT
    fore = (0, 0.2, -0.05)
    shell = grip_parts + [
        box("Body", (0.15, 0.3, 0.13), (0, 0.11, 0.04), bevel=0.04, segs=3, m=M["trim"]),
        box("SidePanel", (0.158, 0.2, 0.07), (0, 0.1, 0.03), bevel=0.02, m=M["shell"]),
        box("RearCap", (0.13, 0.07, 0.115), (0, -0.065, 0.045), bevel=0.035, m=M["shell"]),
        box("RearSlotFrame", (0.09, 0.02, 0.06), (0, -0.102, 0.05), bevel=0.012, m=M["trim"]),
        box("RearSlot", (0.07, 0.02, 0.036), (0, -0.108, 0.05), bevel=0.01, m=M["cell"]),
        torus("RearRing", 0.05, 0.005, (0, -0.1, 0.045), rot=rad(90, 0, 0), m=M["steel"], major_segs=22, minor_segs=5),
        # Handguard under the body (the support hand holds it).
        box("Handguard", (0.1, 0.14, 0.06), fore, bevel=0.02, m=M["dark"]),
        box("HandguardRibF", (0.108, 0.01, 0.066), (0, 0.267, -0.05), bevel=0.004, m=M["trim"]),
        box("HandguardRibR", (0.108, 0.01, 0.066), (0, 0.133, -0.05), bevel=0.004, m=M["trim"]),
        # Front collar and the ceramic insulator stack around the electrode.
        ycyl("Collar", 0.068, 0.05, 0.285, z=bore_z, m=M["dark"], segs=20, bevel=0.012),
        ring("CollarGlow", 0.066, 0.006, 0.305, z=bore_z, m=M["cell"]),
        ycyl("Rod", 0.012, 0.16, 0.37, z=bore_z, m=M["steel"], segs=10),
        sphere("Electrode", 0.024, (0, 0.452, bore_z), m=M["cell"], segs=14, rings=8),
        # Cradle for the capsule: a shelf on the flank, a collar and copper windings.
        box("TowerShelf", (0.078, 0.09, 0.016), (tower[0] + 0.016, tower[1], tower[2] - 0.004), bevel=0.006, m=M["dark"]),
        box("TowerBrace", (0.05, 0.02, 0.05), (tower[0] + 0.03, tower[1], tower[2] - 0.03), rot=rad(0, 35, 0), bevel=0.006, m=M["trim"]),
        cyl("TowerCollar", 0.04, 0.02, (tower[0], tower[1], tower[2] + 0.014), segs=18, bevel=0.006, m=M["steel"]),
        # A dial and status lights on the top-left of the body.
        cyl("Dial", 0.02, 0.012, (-0.048, 0.03, 0.109), segs=14, bevel=0.004, m=M["steel"]),
        box("DialMark", (0.004, 0.018, 0.003), (-0.048, 0.03, 0.1155), bevel=0.0, m=M["cell"]),
        # Cables: a pink power line and a glowing feed into the cradle.
        tube("CableR", [(0.07, -0.06, 0.06), (0.095, 0.05, 0.09), (0.094, 0.2, 0.08), (0.06, 0.27, 0.07)], 0.011, m=M["pink"], segs=6),
        tube("CableL", [(-0.076, 0.022, 0.004), (-0.095, 0.03, -0.012), (tower[0] + 0.012, tower[1] - 0.03, tower[2] + 0.002)], 0.008, m=M["cell"], segs=6),
    ]
    shell += top_rail("TopRail", -0.025, 0.245, rail_top, M)
    for i in range(4):
        shell.append(ycyl(f"Insulator{i}", 0.038 - i * 0.004, 0.012, 0.33 + i * 0.022, z=bore_z, m=ceramic, segs=16, bevel=0.004))
        shell.append(box(f"StatusLight{i}", (0.01, 0.01, 0.004), (-0.05, 0.08 + i * 0.022, 0.106), bevel=0.0, m=M["cell"]))
    for i in range(5):
        shell.append(torus(f"Winding{i}", 0.033, 0.0055, (tower[0], tower[1], tower[2] + 0.03 + i * 0.013), m=copper, major_segs=16, minor_segs=5))
    for i in range(4):
        shell.append(cyl(f"CradlePost{i}", 0.005, 0.096, (tower[0] + math.cos(i * math.pi / 2 + 0.78) * 0.038, tower[1] + math.sin(i * math.pi / 2 + 0.78) * 0.038,
                                                       tower[2] + 0.052), segs=6, bevel=0.0, m=M["steel"]))
    shell += vent_slots("Vent", 0.08, 0.02, 0.2, 0.03, 4, M["dark"], M["cell"], side=1)
    shell += bolts("Bolt", [(0.079, 0.0, 0.0), (0.079, 0.22, 0.0), (-0.079, 0.225, 0.0), (-0.079, 0.225, 0.07)], M["steel"])
    shell += hanger_block(-0.079, -0.065, -0.07, 0.078, M)
    lug, charm_point = charm_lug(-0.079, -0.07, 0.078, M)
    shell += lug
    sight_rear, sight_front = sights_fork(0.0, -0.012, 0.232, rail_top, rail_top, z_line, M)

    # Three claws around the electrode (rotate together as "Prongs").
    prongs = []
    for i, a in enumerate((90, 210, 330)):
        r = math.radians(a)
        pts = []
        for y, rad_ in ((0.3, 0.056), (0.35, 0.08), (0.41, 0.078), (0.462, 0.048)):
            pts.append((math.cos(r) * rad_, y, bore_z + math.sin(r) * rad_))
        prongs.append(tube(f"Claw{i}", pts, 0.012, m=M["steel"], segs=8, radius_end=0.009))
        prongs.append(sphere(f"ClawTip{i}", 0.014, pts[-1], m=M["cell"], segs=10, rings=6))
        prongs.append(box(f"ClawPlate{i}", (0.022, 0.05, 0.01), (math.cos(r) * 0.082, 0.38, bore_z + math.sin(r) * 0.082),
                          rot=(0, -r + math.pi / 2, 0), bevel=0.004, m=M["trim"]))
    vent_pivot = (0.052, 0.2, 0.108)
    vents = []
    for i in range(3):
        vents.append(box(f"VentSlat{i}", (0.03, 0.018, 0.008), (0.052, 0.17 + i * 0.028, 0.108), bevel=0.003, m=M["dark"]))
    # The Tesla capsule: glass core, copper top ring and a glowing crown.
    capsule = [
        cyl("CapsuleGlass", 0.021, 0.1, (tower[0], tower[1], tower[2] + 0.078), segs=14, bevel=0.006, m=M["cell"]),
        torus("CapsuleHat", 0.03, 0.009, (tower[0], tower[1], tower[2] + 0.13), m=M["steel"], major_segs=18, minor_segs=6),
        sphere("CapsuleCrown", 0.02, (tower[0], tower[1], tower[2] + 0.138), m=M["cell"], segs=14, rings=8),
        cyl("CapsuleFoot", 0.026, 0.016, (tower[0], tower[1], tower[2] + 0.028), segs=14, bevel=0.004, m=M["dark"]),
    ]
    capsule_holo = holo_copy(capsule)
    bolt = [(-0.008, 0.03), (0.016, 0.03), (0.004, 0.006), (0.018, 0.006), (-0.01, -0.034), (-0.002, -0.006), (-0.018, -0.006)]
    decal = [side_emblem("Emblem", bolt, -0.081, 0.175, 0.032, M["decal"])]
    cap_pivot = (tower[0], tower[1], tower[2] + 0.08)
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = support_hand(fore, 0.05, 0.03, M, (-0.52, -0.16, -0.46), corner=0.02, finger_len=0.046, thumb_len=0.045)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.012, rail_top), None),
        "IronSightFront": (sight_front, (0, 0.232, rail_top), None),
        "Prongs": (prongs, (0, 0.3, bore_z), None),
        "Vents": (vents, vent_pivot, None),
        "Cell": (capsule, cap_pivot, None),
        "CellHolo": (capsule_holo, cap_pivot, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    empties = {
        "Muzzle": ((0, 0.47, bore_z), None),
        "SightPoint": ((0, -0.012, z_line), None),
        "SightMount": ((0, 0.11, rail_top), None),
        "EjectPoint": ((tower[0] - 0.03, tower[1], tower[2] + 0.15), None),
        "VentPoint": ((0.052, 0.2, 0.12), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("arc_coil", groups, empties)


# ---------------------------------------------------------------------------
# Bumper Lobber: gumball grenade launcher
# ---------------------------------------------------------------------------

def build_bumper_lobber():
    reset_scene()
    M = weapon_mats("#ff4fe0", emit=2.0)
    bore_z = 0.05
    dome = (-0.04, 0.05, 0.132)
    cage_r = 0.052
    grip_loc = (0, -0.03, -0.125)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.078, 0.098, 0.19), body_bottom=-0.04)
    rail_x = 0.05
    rail_top = 0.178
    z_line = rail_top + SIGHT_HEIGHT
    fore = (0, 0.33, -0.045)
    shell = grip_parts + [
        box("Body", (0.17, 0.26, 0.15), (0, 0.08, 0.035), bevel=0.05, segs=3, m=M["trim"]),
        box("BodyPanel", (0.176, 0.16, 0.08), (0, 0.06, 0.03), bevel=0.025, m=M["shell"]),
        box("Stock", (0.13, 0.1, 0.12), (0, -0.1, 0.035), bevel=0.04, m=M["shell"]),
        box("StockPad", (0.11, 0.02, 0.09), (0, -0.152, 0.035), bevel=0.012, m=M["trim"]),
        box("CounterFrame", (0.084, 0.012, 0.044), (0, -0.162, 0.045), bevel=0.008, m=M["dark"]),
        torus("StockRim", 0.05, 0.005, (0, -0.158, 0.035), rot=rad(90, 0, 0), m=M["pink"], major_segs=22, minor_segs=5),
        # Fat barrel with bands, a pink stripe and a flared bell.
        ycyl("Barrel", 0.064, 0.25, 0.32, z=bore_z, m=M["shell"], segs=24, bevel=0.012),
        ring("BandRear", 0.066, 0.008, 0.215, z=bore_z, m=M["trim"]),
        ring("BandMid", 0.066, 0.008, 0.39, z=bore_z, m=M["trim"]),
        ring("Stripe", 0.065, 0.006, 0.25, z=bore_z, m=M["pink"]),
        ycyl("Bell", 0.07, 0.06, 0.47, z=bore_z, m=M["dark"], segs=24, bevel=0.012, radius_top=0.086),
        ring("BellGlow", 0.062, 0.007, 0.5, z=bore_z, m=M["cell"]),
        ycyl("BoreDark", 0.054, 0.01, 0.497, z=bore_z, m=mat("Bore", "#120c22", rough=0.9), segs=20, bevel=0.0),
        # Foregrip under the barrel (the support hand holds it).
        box("Foregrip", (0.09, 0.13, 0.07), fore, bevel=0.02, m=M["trim"]),
        box("ForegripRibF", (0.098, 0.01, 0.076), (0, 0.392, -0.045), bevel=0.004, m=M["dark"]),
        box("ForegripRibR", (0.098, 0.01, 0.076), (0, 0.268, -0.045), bevel=0.004, m=M["dark"]),
        # Gumball hopper: base, cage ribs (top cap is the Lid).
        cyl("HopperBase", cage_r - 0.002, 0.03, (dome[0], dome[1], dome[2] - 0.03), segs=24, bevel=0.01, m=M["trim"]),
        torus("HopperRim", cage_r, 0.006, (dome[0], dome[1], dome[2] - 0.016), m=M["cell"], major_segs=24, minor_segs=5),
        # Sight rail on two posts to the right of the hopper, clear above it.
        box("RailPostR", (0.026, 0.026, rail_top - 0.12), (rail_x, -0.02, (rail_top + 0.1) / 2), bevel=0.006, m=M["trim"]),
        box("RailPostF", (0.026, 0.026, rail_top - 0.12), (rail_x, 0.17, (rail_top + 0.1) / 2), bevel=0.006, m=M["trim"]),
        box("RailFoot", (0.04, 0.24, 0.012), (rail_x, 0.075, 0.113), bevel=0.004, m=M["dark"]),
        # Crank housing on the right.
        xcyl("CrankHub", 0.03, 0.02, (0.092, 0.05, 0.04), m=M["dark"], segs=18, bevel=0.006),
        box("BellyPlate", (0.1, 0.18, 0.014), (0, 0.09, -0.04), bevel=0.005, m=M["dark"]),
    ]
    shell += top_rail("TopRail", -0.045, 0.195, rail_top, M, width=0.034, x=rail_x)
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        shell.append(torus(f"CageRib{i}", cage_r, 0.004, (dome[0], dome[1], dome[2] - 0.016),
                           rot=(math.pi / 2, 0, a), m=M["steel"], major_segs=16, minor_segs=5, arc=math.pi * 0.42, start=0.0))
    shell += vent_slots("Vent", -0.088, 0.1, 0.18, 0.06, 3, M["dark"], M["cell"])
    shell += vent_slots("VentR", 0.088, 0.1, 0.18, 0.06, 3, M["dark"], M["cell"], side=1)
    for i in range(5):
        shell.append(sphere(f"CountDot{i}", 0.0065, (-0.028 + i * 0.014, -0.169, 0.045), m=M["cell"], segs=8, rings=5))
    shell += bolts("Bolt", [(0.088, -0.005, 0.0), (0.088, 0.125, 0.0), (-0.088, -0.005, 0.0), (-0.088, 0.125, 0.0)], M["steel"])
    shell += hanger_block(-0.088, -0.065, -0.085, 0.08, M)
    lug, charm_point = charm_lug(-0.088, -0.085, 0.08, M)
    shell += lug
    sight_rear, sight_front = sights_leaf(rail_x, -0.03, 0.18, rail_top, rail_top, z_line, M)

    lid_pivot = (dome[0], dome[1] - 0.048, dome[2] + 0.03)
    lid = [
        cyl("LidCap", 0.032, 0.012, (dome[0], dome[1], dome[2] + 0.04), segs=20, bevel=0.005, m=M["shell"]),
        sphere("LidKnob", 0.011, (dome[0], dome[1], dome[2] + 0.052), m=M["pink"], segs=12, rings=8),
        box("LidHinge", (0.03, 0.014, 0.01), (dome[0], dome[1] - 0.046, dome[2] + 0.03), bevel=0.004, m=M["steel"]),
        torus("LidRing", 0.035, 0.0045, (dome[0], dome[1], dome[2] + 0.034), m=M["steel"], major_segs=20, minor_segs=5),
    ]
    crank = [
        box("CrankArm", (0.012, 0.012, 0.07), (0.106, 0.05, 0.065), bevel=0.004, m=M["steel"]),
        xcyl("CrankKnob", 0.012, 0.03, (0.118, 0.05, 0.098), m=M["pink"], segs=12, bevel=0.005),
    ]
    balls = []
    spots = [(-0.017, -0.013, -0.004), (0.017, -0.01, -0.003), (0.0, 0.019, -0.002), (-0.01, 0.003, 0.024), (0.013, 0.01, 0.022)]
    for i, (dx, dy, dz) in enumerate(spots):
        balls.append(sphere(f"Ball{i}", 0.018, (dome[0] + dx, dome[1] + dy, dome[2] + dz), m=M["cell"], segs=14, rings=9))
        balls.append(torus(f"BallBand{i}", 0.0176, 0.0026, (dome[0] + dx, dome[1] + dy, dome[2] + dz), rot=rad(70, 20 * i, 0),
                           m=M["shell"], major_segs=14, minor_segs=4))
    balls_holo = holo_copy(balls)
    swirl = [(math.cos(math.tau * k / 10) * (0.02 + 0.008 * (k % 2)), math.sin(math.tau * k / 10) * (0.02 + 0.008 * (k % 2))) for k in range(10)]
    decal = [side_emblem("Emblem", swirl, -0.089, 0.04, 0.035, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = support_hand(fore, 0.045, 0.035, M, (-0.52, -0.12, -0.46), corner=0.02, finger_len=0.052, thumb_len=0.05)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (rail_x, -0.03, rail_top), None),
        "IronSightFront": (sight_front, (rail_x, 0.18, rail_top), None),
        "Lid": (lid, lid_pivot, None),
        "Crank": (crank, (0.092, 0.05, 0.04), None),
        "Cell": (balls, dome, None),
        "CellHolo": (balls_holo, dome, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    empties = {
        "Muzzle": ((0, 0.51, bore_z), None),
        "SightPoint": ((rail_x, -0.03, z_line), None),
        "SightMount": ((rail_x, 0.075, rail_top), None),
        "EjectPoint": ((dome[0], dome[1], dome[2] + 0.06), None),
        "VentPoint": ((0, 0.5, bore_z + 0.07), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("bumper_lobber", groups, empties)


# ---------------------------------------------------------------------------
# Frostbite Cryo Beam: freezing beam projector
# ---------------------------------------------------------------------------

def build_cryo_beam():
    reset_scene()
    M = weapon_mats("#5cc8ff", holo="#bff3ff", emit=1.5)
    frost = mat("Frost", "#eaf6ff", rough=0.28)
    bore_z = 0.05
    tank_x, tank_y, tank_z = -0.098, 0.15, 0.06
    grip_loc = (0, -0.03, -0.115)
    grip_parts, G = grip("", grip_loc, M, tilt=-12, size=(0.074, 0.094, 0.19), body_bottom=-0.025)
    rail_top = 0.141
    z_line = rail_top + SIGHT_HEIGHT
    fore = (0, 0.3, -0.095)
    fore_tilt = 8.0
    shell = grip_parts + [
        box("Body", (0.14, 0.4, 0.13), (0, 0.14, 0.04), bevel=0.04, segs=3, m=M["trim"]),
        box("FrostPanel", (0.146, 0.24, 0.07), (0, 0.15, 0.025), bevel=0.02, m=frost),
        box("Stock", (0.12, 0.1, 0.12), (0, -0.09, 0.045), bevel=0.04, m=M["shell"]),
        box("StockPad", (0.1, 0.02, 0.09), (0, -0.142, 0.045), bevel=0.012, m=frost),
        torus("PressureRing", 0.03, 0.006, (0, -0.152, 0.045), rot=rad(90, 0, 0), m=M["cell"], major_segs=22, minor_segs=6),
        ycyl("PressureCore", 0.02, 0.01, -0.151, z=0.045, m=M["dark"], segs=16, bevel=0.002),
        box("TopShell", (0.1, 0.3, 0.03), (0, 0.15, 0.112), bevel=0.012, m=M["shell"]),
        # Tank cradle on the left.
        box("TankSaddle", (0.03, 0.26, 0.05), (-0.072, tank_y, 0.03), bevel=0.012, m=M["dark"]),
        ycyl("TankCapRear", 0.03, 0.03, tank_y - 0.135, z=tank_z, x=tank_x, m=M["steel"], segs=16),
        ycyl("TankCapFront", 0.03, 0.03, tank_y + 0.135, z=tank_z, x=tank_x, m=M["steel"], segs=16),
        # Emitter: coolant coils, radial frost fins and a flared nozzle.
        ycyl("Emitter", 0.032, 0.2, 0.4, z=bore_z, m=M["dark"], segs=16),
        ycyl("Nozzle", 0.046, 0.075, 0.53, z=bore_z, m=frost, segs=24, bevel=0.012, radius_top=0.074),
        ring("NozzleGlow", 0.058, 0.008, 0.566, z=bore_z, m=M["cell"], segs=24),
        ycyl("NozzleCore", 0.03, 0.012, 0.56, z=bore_z, m=M["cell"], segs=16, bevel=0.0),
        # Gauge on the top right (the needle is its own part).
        cyl("GaugeBody", 0.024, 0.02, (0.04, -0.015, 0.113), segs=20, bevel=0.006, m=M["steel"]),
        cyl("GaugeFace", 0.019, 0.006, (0.04, -0.015, 0.124), segs=20, bevel=0.0, m=frost),
        box("GaugeRed", (0.01, 0.004, 0.002), (0.05, -0.015, 0.1275), bevel=0.0, m=M["pink"]),
        # Vertical foregrip (the support hand holds it).
        box("Foregrip", (0.05, 0.06, 0.15), fore, rot=rad(fore_tilt, 0, 0), bevel=0.016, m=M["trim"]),
        box("ForegripMount", (0.074, 0.1, 0.03), (0, 0.3, -0.018), bevel=0.01, m=M["dark"]),
        box("ForegripCap", (0.05, 0.06, 0.014), (0, 0.3 + 0.0105, -0.169), rot=rad(fore_tilt, 0, 0), bevel=0.004, m=M["steel"]),
        tube("Hose", [(-0.068, 0.0, -0.012), (-0.09, 0.008, 0.0), (-0.098, 0.022, 0.024)], 0.009, m=M["cell"], segs=6),
        tube("HoseTop", [(0.045, 0.31, 0.1), (0.06, 0.35, 0.09), (0.03, 0.4, 0.075)], 0.008, m=M["cell"], segs=6),
    ]
    shell += top_rail("TopRail", 0.02, 0.28, rail_top, M)
    for i in range(4):
        shell.append(ring(f"Coil{i}", 0.041, 0.0065, 0.33 + i * 0.03, z=bore_z, m=M["steel"]))
        shell.append(ring(f"CoilGlow{i}", 0.036, 0.004, 0.345 + i * 0.03, z=bore_z, m=M["cell"]))
    for i in range(3):
        a = math.radians(70 + i * 20)
        shell.append(prism(f"Icicle{i}", [(-0.006, 0.0), (0.006, 0.0), (0.0, -0.03)], 0.006,
                           (math.cos(a) * 0.07, 0.55, bore_z - 0.035 - 0.004 * i), m=frost))
    shell += vent_slots("VentR", 0.073, 0.05, 0.25, 0.03, 5, M["dark"], M["cell"], side=1)
    shell += bolts("Bolt", [(0.073, 0.02, 0.0), (0.073, 0.28, 0.0), (-0.073, 0.3, 0.0), (-0.073, 0.3, 0.05)], M["steel"])
    shell += hanger_block(-0.073, -0.06, -0.085, 0.088, M)
    lug, charm_point = charm_lug(-0.073, -0.085, 0.088, M)
    shell += lug
    sight_rear, sight_front = sights_frame(0.0, 0.035, 0.268, rail_top, rail_top, z_line, M)

    fins_parts = fins("Fin", 6, 0.056, 0.45, bore_z, (0.006, 0.07, 0.03), frost, start=math.pi / 6)
    needle = [box("NeedleBar", (0.003, 0.016, 0.003), (0.04, -0.007, 0.129), bevel=0.0, m=M["dark"])]
    clamp_pivot = (-0.072, tank_y, 0.012)
    clamps = []
    for i, y in enumerate((tank_y - 0.07, tank_y + 0.07)):
        clamps.append(torus(f"Clamp{i}", 0.05, 0.007, (tank_x, y, tank_z), rot=rad(90, 0, 0), m=M["trim"], major_segs=20, minor_segs=6,
                            arc=math.radians(250), start=math.radians(-35)))
        clamps.append(box(f"ClampLatch{i}", (0.02, 0.022, 0.014), (tank_x - 0.035, y, tank_z + 0.04), bevel=0.004, m=M["cell"]))
    tank = [
        ycyl("TankGlass", 0.04, 0.23, tank_y, z=tank_z, x=tank_x, m=M["cell"], segs=20, bevel=0.012),
        ycyl("TankBandA", 0.042, 0.014, tank_y - 0.04, z=tank_z, x=tank_x, m=M["dark"], segs=20, bevel=0.003),
        ycyl("TankBandB", 0.042, 0.014, tank_y + 0.04, z=tank_z, x=tank_x, m=M["dark"], segs=20, bevel=0.003),
        box("TankLabel", (0.004, 0.05, 0.03), (tank_x - 0.041, tank_y, tank_z), bevel=0.0, m=frost),
    ]
    tank_holo = holo_copy(tank)
    flake = [(0.0, 0.03), (0.007, 0.007), (0.03, 0.0), (0.007, -0.007), (0.0, -0.03), (-0.007, -0.007), (-0.03, 0.0), (-0.007, 0.007)]
    decal = [side_emblem("Emblem", flake, -0.074, 0.305, 0.06, M["decal"])]
    tank_pivot = (tank_x, tank_y, tank_z)
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = vertical_hand(fore, 0.025, 0.03, 0.15, M, (-0.52, -0.16, -0.46), tilt=fore_tilt)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, 0.035, rail_top), None),
        "IronSightFront": (sight_front, (0, 0.268, rail_top), None),
        "Fins": (fins_parts, (0, 0.45, bore_z), None),
        "Needle": (needle, (0.04, -0.015, 0.129), None),
        "Panel": (clamps, clamp_pivot, None),
        "Cell": (tank, tank_pivot, None),
        "CellHolo": (tank_holo, tank_pivot, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    empties = {
        "Muzzle": ((0, 0.575, bore_z), None),
        "SightPoint": ((0, 0.035, z_line), None),
        "SightMount": ((0, 0.15, rail_top), None),
        "EjectPoint": ((tank_x - 0.06, tank_y, tank_z), None),
        "VentPoint": ((0, 0.45, bore_z + 0.06), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("cryo_beam", groups, empties)


# ---------------------------------------------------------------------------
# Rail Lancer: charge-up piercing railgun
# ---------------------------------------------------------------------------

def build_rail_lancer():
    reset_scene()
    M = weapon_mats("#ff1f3d", emit=1.7)
    axis_z = 0.05
    grip_loc = (0, -0.03, -0.1)
    grip_parts, G = grip("", grip_loc, M, tilt=-12, size=(0.074, 0.094, 0.19), body_bottom=-0.01)
    rail_top = 0.148
    z_line = rail_top + SIGHT_HEIGHT
    fore = (0, 0.31, -0.045)
    shell = grip_parts + [
        side_profile("Receiver", [(-0.09, -0.01), (0.33, -0.01), (0.35, 0.02), (0.35, 0.1), (0.31, 0.118), (-0.05, 0.118), (-0.09, 0.09)],
                     0.12, (0, 0, 0), M["trim"], bevel=0.02),
        box("SidePanel", (0.126, 0.24, 0.06), (0, 0.14, 0.05), bevel=0.02, m=M["shell"]),
        box("TopCover", (0.08, 0.3, 0.02), (0, 0.14, 0.124), bevel=0.008, m=M["shell"]),
        # Handguard (the support hand holds it).
        box("Handguard", (0.084, 0.15, 0.08), fore, bevel=0.018, m=M["shell"]),
        box("HandguardRibF", (0.092, 0.01, 0.086), (0, 0.38, -0.045), bevel=0.004, m=M["dark"]),
        box("HandguardRibR", (0.092, 0.01, 0.086), (0, 0.24, -0.045), bevel=0.004, m=M["dark"]),
        # Skeleton stock.
        box("StockTop", (0.05, 0.22, 0.032), (0, -0.19, 0.08), bevel=0.012, m=M["shell"]),
        box("StockLow", (0.05, 0.2, 0.03), (0, -0.19, 0.022), rot=rad(-9, 0, 0), bevel=0.012, m=M["shell"]),
        box("StockPad", (0.064, 0.04, 0.14), (0, -0.305, 0.045), bevel=0.016, m=M["dark"]),
        box("Cheek", (0.056, 0.12, 0.03), (0, -0.16, 0.105), bevel=0.012, m=M["trim"]),
        # Inner coil running between the rails.
        ycyl("Coil", 0.013, 0.34, 0.52, z=axis_z, m=M["steel"], segs=10),
        ycyl("RailRoot", 0.05, 0.05, 0.35, z=axis_z, m=M["dark"], segs=18, bevel=0.012),
        # Crimson stripe and right-side vents.
        box("Stripe", (0.004, 0.22, 0.012), (-0.062, 0.15, 0.096), bevel=0.0, m=M["cell"]),
        tube("CableR", [(0.06, -0.05, 0.03), (0.075, 0.1, 0.02), (0.07, 0.3, 0.03)], 0.01, m=M["pink"], segs=6),
        box("BoltHandle", (0.03, 0.022, 0.016), (0.07, 0.05, 0.1), bevel=0.005, m=M["steel"]),
    ]
    shell += top_rail("TopRail", -0.01, 0.29, rail_top, M)
    shell += vent_slots("Vent", 0.064, 0.02, 0.26, 0.09, 5, M["dark"], M["cell"], side=1)
    shell.append(box("PipStrip", (0.06, 0.06, 0.01), (0, -0.05, 0.122), bevel=0.004, m=M["dark"]))
    for i in range(3):
        for j in range(2):
            shell.append(box(f"ShotPip{i}{j}", (0.012, 0.012, 0.006), (-0.016 + i * 0.016, -0.062 + j * 0.024, 0.128), bevel=0.002, m=M["cell"]))
    shell += bolts("Bolt", [(-0.0615, 0.3, 0.0), (-0.0615, 0.3, 0.085), (0.0615, 0.0, 0.0), (0.0615, 0.3, 0.0)], M["steel"])
    lug, charm_point = charm_lug(-0.0255, -0.19, 0.08, M)
    shell += lug
    # Charge rings around the rail gap.
    for i in range(3):
        shell.append(ring(f"ChargeRing{i}", 0.054, 0.0075, 0.47 + i * 0.12, z=axis_z, m=M["cell"], segs=22))
        shell.append(ring(f"RingCollar{i}", 0.058, 0.004, 0.47 + i * 0.12, z=axis_z, m=M["dark"], segs=22))
    sight_rear, sight_front = sights_globe(0.0, 0.005, 0.272, rail_top, rail_top, z_line, M)

    rails = []
    for i, z in enumerate((axis_z + 0.044, axis_z - 0.044)):
        side = 1 if i == 0 else -1
        rails += [
            side_profile(f"Rail{i}", [(0.34, -0.012), (0.82, -0.012), (0.86, 0.0), (0.82, 0.012), (0.34, 0.012)], 0.034, (0, 0, z), M["shell"], bevel=0.005),
            box(f"RailGlow{i}", (0.018, 0.46, 0.005), (0, 0.58, z - side * 0.0135), bevel=0.0, m=M["cell"]),
            box(f"RailSpine{i}", (0.04, 0.3, 0.012), (0, 0.5, z + side * 0.014), bevel=0.004, m=M["trim"]),
        ]
    rails.append(box("RailTipBrace", (0.012, 0.024, 0.1), (0, 0.835, axis_z), bevel=0.004, m=M["dark"]))
    capacitor = [
        box("CapBody", (0.03, 0.13, 0.075), (-0.074, 0.17, 0.035), bevel=0.01, m=M["dark"]),
        box("CapWindow", (0.006, 0.1, 0.028), (-0.09, 0.17, 0.045), bevel=0.002, m=M["cell"]),
        box("CapHandle", (0.01, 0.05, 0.01), (-0.092, 0.17, 0.068), bevel=0.003, m=M["steel"]),
    ]
    for k in range(4):
        capacitor.append(box(f"CapPip{k}", (0.006, 0.014, 0.01), (-0.09, 0.13 + k * 0.026, 0.017), bevel=0.002, m=M["cell"]))
    capacitor_holo = holo_copy(capacitor)
    chevron = [(-0.03, 0.012), (0.0, -0.016), (0.03, 0.012), (0.03, 0.024), (0.0, -0.004), (-0.03, 0.024)]
    decal = [side_emblem("Emblem", [(u * 0.8, v * 0.8) for u, v in chevron], -0.064, 0.292, 0.05, M["decal"])]
    cap_pivot = (-0.074, 0.17, 0.035)
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = support_hand(fore, 0.042, 0.04, M, (-0.52, -0.14, -0.46), corner=0.018, finger_len=0.05, thumb_len=0.042)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, 0.005, rail_top), None),
        "IronSightFront": (sight_front, (0, 0.272, rail_top), None),
        "Rails": (rails, (0, 0.34, axis_z), None),
        "Cell": (capacitor, cap_pivot, None),
        "CellHolo": (capacitor_holo, cap_pivot, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    empties = {
        "Muzzle": ((0, 0.85, axis_z), None),
        "SightPoint": ((0, 0.005, z_line), None),
        "SightMount": ((0, 0.14, rail_top), None),
        "EjectPoint": ((-0.12, 0.17, 0.0), None),
        "VentPoint": ((0, 0.6, axis_z + 0.07), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("rail_lancer", groups, empties)


BUILDERS = (
    ("comet_cannon", build_comet_cannon),
    ("arc_coil", build_arc_coil),
    ("bumper_lobber", build_bumper_lobber),
    ("cryo_beam", build_cryo_beam),
    ("rail_lancer", build_rail_lancer),
)

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for name, fn in BUILDERS:
        if not only or name in only:
            fn()
