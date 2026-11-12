"""First-person viewmodels for the three starter energy weapons, with gloved arms.

Each weapon is modelled around its own origin (top of the grip), pointing
along +Y (Godot -Z, camera forward). The node contract every weapon follows
(materials, animated parts, sights, arms and empties) is documented at the
top of weapon_kit.py, which also holds the shared parts: grips, hands, rails,
iron sights, the charm lug and the baked shading.

  pulse_pistol     cyan   Slide > (Hammer, IronSight*, SightMount), Cell (grip magazine)
  ion_carbine      cyan   Panel (cell cage), Vents, Cell (side cell)
  scatter_blaster  cyan   Barrels > (Pump > ArmL, IronSightFront), Drum, Capsules

The newer weapons are built by build_weapons_arsenal.py with the same contract.

    python art/blender/build_weapons.py [weapon_id ...]

*Holo parts are hidden copies of the energy cell; the game shows them with a
hologram shader while a new cell "prints" in during the reload.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403


# ---------------------------------------------------------------------------
# Pulse Pistol
# ---------------------------------------------------------------------------

def build_pulse_pistol():
    reset_scene()
    M = weapon_mats()
    grip_loc = (0, -0.014, -0.112)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.07, 0.092, 0.19), body_bottom=-0.035)
    fr = G["frame"]
    shell = grip_parts + [
        box("Frame", (0.078, 0.27, 0.07), (0, 0.115, 0.0), bevel=0.02, m=M["trim"]),
        box("FramePanel", (0.084, 0.13, 0.036), (0, 0.15, -0.004), bevel=0.012, m=M["shell"]),
        # Beavertail over the web of the hand.
        side_profile("Beavertail", [(-0.02, 0.012), (-0.02, -0.03), (-0.05, -0.03), (-0.08, -0.014), (-0.08, 0.0), (-0.06, 0.012)],
                     0.058, (0, 0, 0), M["trim"], bevel=0.006),
        # Accessory rail under the barrel with a lamp.
        box("Rail", (0.05, 0.12, 0.018), (0, 0.2, -0.044), bevel=0.006, m=M["dark"]),
        box("Light", (0.044, 0.06, 0.03), (0, 0.235, -0.064), bevel=0.01, m=M["dark"]),
        cyl("LightLens", 0.012, 0.012, (0, 0.268, -0.064), rot=rad(90, 0, 0), segs=12, bevel=0.003, m=M["cell"]),
        box("LightBand", (0.048, 0.008, 0.034), (0, 0.222, -0.064), bevel=0.003, m=M["steel"]),
        # Barrel shroud and emitter.
        ycyl("Shroud", 0.03, 0.07, 0.27, z=0.065, m=M["dark"], segs=16),
        ring("Emitter", 0.026, 0.006, 0.305, z=0.065, m=M["cell"]),
        ycyl("BoreCap", 0.02, 0.006, 0.304, z=0.065, m=mat("Bore", "#120c22", rough=0.9), segs=14, bevel=0.0),
        ring("ShroudBand", 0.031, 0.004, 0.25, z=0.065, m=M["steel"]),
        # Charge-coil window on the side the player sees: three glowing rings.
        box("CoilRecess", (0.01, 0.1, 0.04), (-0.041, 0.13, 0.0), bevel=0.006, m=M["dark"]),
        # Rear capacitor with three ammo pips facing the camera.
        box("Capacitor", (0.07, 0.03, 0.05), (0, -0.045, 0.02), bevel=0.012, m=M["dark"]),
        box("CapacitorRim", (0.058, 0.006, 0.03), (0, -0.0615, 0.024), bevel=0.003, m=M["steel"]),
        # Controls: slide stop, magazine release, takedown pins.
        box("SlideStop", (0.006, 0.04, 0.01), (-0.041, 0.04, 0.022), bevel=0.003, m=M["steel"]),
        box("MagRelease", (0.008, 0.014, 0.014), (-0.041, 0.03, -0.02), bevel=0.004, m=M["cell"]),
        box("RightVentPlate", (0.008, 0.09, 0.03), (0.041, 0.13, 0.0), bevel=0.004, m=M["dark"]),
    ]
    for i in range(3):
        shell.append(torus(f"Coil{i}", 0.016, 0.004, (-0.045, 0.1 + i * 0.03, 0.0), rot=rad(0, 90, 0), m=M["cell"], major_segs=14, minor_segs=5))
        shell.append(box(f"Pip{i}", (0.013, 0.006, 0.013), (-0.018 + i * 0.018, -0.0635, 0.024), bevel=0.003, m=M["cell"]))
        shell.append(box(f"RightSlit{i}", (0.004, 0.018, 0.02), (0.045, 0.1 + i * 0.03, 0.0), rot=rad(18, 0, 0), bevel=0.0, m=M["cell"]))
    for i in range(4):
        shell.append(box(f"RailTooth{i}", (0.054, 0.012, 0.008), (0, 0.152 + i * 0.022, -0.054), bevel=0.002, m=M["steel"]))
    shell += bolts("Pin", [(-0.04, 0.085, -0.02), (-0.04, 0.215, 0.018), (0.04, 0.03, -0.01), (0.04, 0.215, 0.018)], M["steel"], radius=0.006, height=0.007)
    lug, charm_point = charm_lug(-0.042, 0.212, -0.012, M)
    shell += lug

    rail_top = 0.127
    z_line = rail_top + SIGHT_HEIGHT
    slide_outline = [(-0.045, 0.032), (0.258, 0.032), (0.258, 0.085), (0.23, 0.113), (-0.03, 0.113), (-0.048, 0.098)]
    slide = [
        side_profile("SlideBody", slide_outline, 0.088, (0, 0, 0), M["shell"], bevel=0.008),
        box("SlideBelt", (0.092, 0.2, 0.012), (0, 0.11, 0.046), bevel=0.003, m=M["trim"]),
        box("SlidePlate", (0.07, 0.006, 0.05), (0, -0.0475, 0.068), bevel=0.003, m=M["dark"]),
        box("SlidePlateLight", (0.03, 0.004, 0.008), (0, -0.0505, 0.052), bevel=0.0, m=M["cell"]),
        box("Port", (0.03, 0.05, 0.006), (0.024, 0.085, 0.112), bevel=0.002, m=M["dark"]),
    ]
    slide += top_rail("TopRail", 0.0, 0.2, rail_top, M, width=0.034)
    slide += vent_slots("VentL", -0.045, 0.12, 0.24, 0.076, 4, M["dark"], M["cell"], height=0.03)
    slide += vent_slots("VentR", 0.045, 0.12, 0.24, 0.076, 4, M["dark"], M["cell"], height=0.03, side=1)
    for i in range(4):
        for side in (-1, 1):
            slide.append(box(f"Serration{i}{side}", (0.004, 0.006, 0.044), (side * 0.0445, -0.032 + i * 0.012, 0.074), bevel=0.0, m=M["dark"]))
    for i in range(3):
        slide.append(box(f"Comp{i}", (0.022, 0.008, 0.004), (0, 0.214 + i * 0.013, 0.1135 - i * 0.0), rot=rad(0, 0, 0), bevel=0.0, m=M["dark"]))
    sight_rear, sight_front = sights_notch(0.0, -0.03, 0.236, 0.111, 0.1, z_line, M)

    hammer = [
        box("HammerBody", (0.024, 0.026, 0.032), (0, -0.064, 0.086), bevel=0.006, m=M["dark"]),
        box("HammerSpur", (0.03, 0.012, 0.01), (0, -0.074, 0.103), bevel=0.003, m=M["steel"]),
        sphere("HammerGlow", 0.007, (0, -0.078, 0.086), m=M["cell"], segs=8, rings=5),
    ]
    half = G["size"][2] / 2
    cell = [
        box("CellBody", (0.046, 0.062, 0.17), tuple(fpt(fr, 0, 0, -0.01)), rot=(G["tilt"], 0, 0), bevel=0.012, m=M["dark"]),
        box("CellBase", (0.074, 0.096, 0.024), tuple(fpt(fr, 0, 0, -half - 0.018)), rot=(G["tilt"], 0, 0), bevel=0.009, m=M["cell"]),
        box("CellFoot", (0.06, 0.08, 0.008), tuple(fpt(fr, 0, 0, -half - 0.033)), rot=(G["tilt"], 0, 0), bevel=0.003, m=M["dark"]),
        box("CellTop", (0.04, 0.05, 0.012), tuple(fpt(fr, 0, 0, 0.078)), rot=(G["tilt"], 0, 0), bevel=0.004, m=M["cell"]),
    ]
    cell_holo = holo_copy(cell)
    decal = [side_emblem("Emblem", star_outline(0.024), -0.048, 0.062, 0.078, M["decal"])]
    cell_pivot = tuple(fpt(fr, 0, 0, -0.04))
    arm_r, elbow_r = firing_hand(G, M, (0.42, -0.5, -0.36))
    arm_l, elbow_l = cup_hand(G, M, (-0.55, -0.32, -0.32))
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "Slide": (slide, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.03, 0.111), "Slide"),
        "IronSightFront": (sight_front, (0, 0.236, 0.1), "Slide"),
        "Hammer": (hammer, (0, -0.052, 0.075), "Slide"),
        "Cell": (cell, cell_pivot, None),
        "CellHolo": (cell_holo, cell_pivot, None),
        "Decal": (decal, (0, 0, 0), "Slide"),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, grip_loc, None),
    }
    empties = {
        "Muzzle": ((0, 0.315, 0.065), None),
        "SightPoint": ((0, -0.03, z_line), None),
        "SightMount": ((0, 0.07, rail_top), "Slide"),
        "EjectPoint": ((0, -0.05, -0.25), None),
        "VentPoint": ((-0.05, 0.18, 0.085), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("pulse_pistol", groups, empties)


# ---------------------------------------------------------------------------
# Ion Carbine
# ---------------------------------------------------------------------------

def build_ion_carbine():
    reset_scene()
    M = weapon_mats()
    grip_loc = (0, -0.02, -0.15)
    grip_parts, G = grip("", grip_loc, M, tilt=-13, size=(0.075, 0.095, 0.2), body_bottom=-0.065)
    cell_c = (-0.09, 0.22, 0.03)
    rail_top = 0.178
    z_line = rail_top + SIGHT_HEIGHT
    fore = (0, 0.27, -0.1)
    shell = grip_parts + [
        box("RearBlock", (0.15, 0.2, 0.2), (0, 0.0, 0.035), bevel=0.04, segs=3, m=M["trim"]),
        box("StockPad", (0.13, 0.06, 0.16), (0, -0.12, 0.03), bevel=0.035, m=M["shell"]),
        box("StockPlate", (0.1, 0.012, 0.13), (0, -0.152, 0.03), bevel=0.005, m=M["dark"]),
        box("RearSlotFrame", (0.094, 0.012, 0.06), (0, -0.158, 0.055), bevel=0.008, m=M["trim"]),
        box("RearSlot", (0.074, 0.012, 0.038), (0, -0.162, 0.055), bevel=0.008, m=M["cell"]),
        box("MidShell", (0.17, 0.3, 0.19), (0, 0.22, 0.035), bevel=0.055, segs=3, m=M["shell"]),
        box("MidRidge", (0.085, 0.27, 0.05), (0, 0.22, 0.14), bevel=0.02, m=M["shell"]),
        # Cell chamber on the left: dark recess with glowing coil rings.
        box("Chamber", (0.04, 0.24, 0.12), (-0.078, 0.22, 0.03), bevel=0.02, m=M["dark"]),
        box("FrontBlock", (0.18, 0.21, 0.21), (0, 0.455, 0.035), bevel=0.055, segs=3, m=M["trim"]),
        box("FrontWindow", (0.02, 0.11, 0.065), (-0.091, 0.455, 0.045), bevel=0.008, m=M["cell"]),
        box("FrontWindowFrame", (0.012, 0.13, 0.085), (-0.086, 0.455, 0.045), bevel=0.006, m=M["dark"]),
        box("FrontCheek", (0.19, 0.06, 0.12), (0, 0.37, 0.02), bevel=0.02, m=M["shell"]),
        box("FrontPlateR", (0.012, 0.12, 0.075), (0.088, 0.455, 0.045), bevel=0.006, m=M["shell"]),
        ycyl("Barrel", 0.034, 0.16, 0.6, z=0.035, m=M["dark"], segs=16),
        ycyl("Brake", 0.052, 0.07, 0.69, z=0.035, m=M["shell"], segs=16, bevel=0.012),
        ring("Emitter", 0.034, 0.007, 0.727, z=0.035, m=M["cell"]),
        ycyl("BoreCap", 0.027, 0.006, 0.727, z=0.035, m=mat("Bore", "#120c22", rough=0.9), segs=14, bevel=0.0),
        # Foregrip (the support hand holds it) with end ribs.
        box("Foregrip", (0.1, 0.14, 0.085), fore, bevel=0.022, m=M["trim"]),
        box("ForegripRibF", (0.108, 0.01, 0.092), (0, 0.337, -0.1), bevel=0.004, m=M["dark"]),
        box("ForegripRibR", (0.108, 0.01, 0.092), (0, 0.203, -0.1), bevel=0.004, m=M["dark"]),
        box("FrontSkid", (0.08, 0.12, 0.02), (0, 0.455, -0.072), bevel=0.008, m=M["dark"]),
        # Charging handle and status lights on the rear block.
        box("ChargeHandle", (0.03, 0.05, 0.016), (0.079, 0.0, 0.1), bevel=0.005, m=M["steel"]),
        box("RearTopPlate", (0.09, 0.12, 0.012), (0, -0.01, 0.137), bevel=0.004, m=M["shell"]),
        # Cables: a pink power line on the right, a glowing feed into the chamber on the left.
        tube("CableR", [(0.08, -0.05, 0.08), (0.1, 0.12, 0.1), (0.1, 0.3, 0.1), (0.085, 0.42, 0.08)], 0.011, m=M["pink"], segs=6),
        tube("CableL", [(-0.07, -0.05, -0.04), (-0.088, 0.02, -0.044), (-0.088, 0.08, -0.034), (-0.082, 0.115, 0.0)], 0.009, m=M["cell"], segs=6),
    ]
    shell += top_rail("TopRail", 0.07, 0.37, rail_top, M)
    for i in range(5):
        shell.append(ring(f"Coil{i}", 0.044, 0.005, 0.15 + i * 0.035, z=cell_c[2], x=cell_c[0], m=M["cell"], segs=18))
        shell.append(ycyl(f"Fin{i}", 0.048, 0.008, 0.53 + i * 0.022, z=0.035, m=M["steel"], segs=16, bevel=0.002))
    for i in range(4):
        a = math.radians(45 + 90 * i)
        shell.append(box(f"BrakeSlot{i}", (0.012, 0.036, 0.008), (math.cos(a) * 0.05, 0.69, 0.035 + math.sin(a) * 0.05),
                         rot=(0, math.pi / 2 - a, 0), bevel=0.002, m=M["dark"]))
    for i in range(4):
        shell.append(box(f"StockPip{i}", (0.012, 0.006, 0.012), (-0.027 + i * 0.018, -0.16, 0.0), bevel=0.003, m=M["cell"]))
    shell += bolts("Bolt", [(0.088, 0.1, 0.1), (0.088, 0.34, 0.1), (0.088, 0.1, -0.03), (0.088, 0.34, -0.03),
                            (-0.088, 0.37, -0.03), (-0.078, 0.07, -0.02)], M["steel"])
    shell += bolts("BoltTop", [(-0.05, 0.4, 0.141), (0.05, 0.4, 0.141), (-0.05, 0.51, 0.141), (0.05, 0.51, 0.141)], M["steel"], axis="z", radius=0.006)
    shell += panel_lines("SeamR", 0.0862, [(0.1, 0.035, 0.34, 0.035), (0.22, -0.03, 0.22, 0.1)], M["dark"])
    shell += panel_lines("SeamRear", -0.0762, [(-0.07, -0.032, 0.07, -0.032)], M["dark"])
    lug, charm_point = charm_lug(-0.075, -0.058, 0.103, M)
    shell += lug
    sight_rear, sight_front = sights_ghost_ring(0.0, 0.085, 0.5, rail_top, 0.14, z_line, M)

    # Hinged roll cage over the cell (hinge along its bottom edge).
    hinge = (cell_c[0], 0.22, cell_c[2] - 0.058)
    panel = []
    for i, y in enumerate((0.125, 0.22, 0.315)):
        panel.append(torus(f"CageHoop{i}", 0.058, 0.0055, (cell_c[0], y, cell_c[2]), rot=rad(90, 0, 0), m=M["trim"],
                           major_segs=18, minor_segs=6, arc=math.radians(170), start=math.radians(95)))
    panel += [
        box("CageSpine", (0.014, 0.21, 0.012), (cell_c[0] - 0.004, 0.22, cell_c[2] - 0.058), bevel=0.004, m=M["trim"]),
        box("CageTop", (0.014, 0.21, 0.012), (cell_c[0] - 0.004, 0.22, cell_c[2] + 0.058), bevel=0.004, m=M["trim"]),
        box("CageLatch", (0.012, 0.03, 0.02), (cell_c[0] - 0.058, 0.22, cell_c[2]), bevel=0.004, m=M["steel"]),
        box("CageLight", (0.005, 0.016, 0.01), (cell_c[0] - 0.065, 0.22, cell_c[2]), bevel=0.0, m=M["cell"]),
    ]
    vent_pivot = (0.064, 0.166, 0.118)
    vents = []
    for i in range(4):
        vents.append(box(f"VentSlat{i}", (0.04, 0.02, 0.008), (0.064, 0.18 + i * 0.03, 0.12), rot=rad(0, 38, 0), bevel=0.003, m=M["dark"]))
    cell_parts = [
        ycyl("CellTube", 0.036, 0.19, cell_c[1], z=cell_c[2], x=cell_c[0], m=M["cell"], segs=16, bevel=0.0),
        sphere("CellCapA", 0.036, (cell_c[0], cell_c[1] - 0.095, cell_c[2]), m=M["cell"], segs=16, rings=8),
        sphere("CellCapB", 0.036, (cell_c[0], cell_c[1] + 0.095, cell_c[2]), m=M["cell"], segs=16, rings=8),
        ycyl("CellRingA", 0.039, 0.016, cell_c[1] - 0.052, z=cell_c[2], x=cell_c[0], m=M["dark"], segs=16, bevel=0.003),
        ycyl("CellRingB", 0.039, 0.016, cell_c[1] + 0.052, z=cell_c[2], x=cell_c[0], m=M["dark"], segs=16, bevel=0.003),
    ]
    cell_holo = holo_copy(cell_parts)
    bolt = [(-0.008, 0.045), (0.022, 0.045), (0.006, 0.008), (0.026, 0.008), (-0.014, -0.05), (-0.002, -0.008), (-0.024, -0.008)]
    decal = [side_emblem("Emblem", [(u * 0.8, v * 0.8) for u, v in bolt], -0.077, 0.025, 0.05, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = support_hand(fore, 0.05, 0.0425, M, (-0.52, -0.16, -0.46), finger_len=0.07, thumb_len=0.06)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, 0.085, rail_top), None),
        "IronSightFront": (sight_front, (0, 0.5, 0.14), None),
        "Panel": (panel, hinge, None),
        "Vents": (vents, vent_pivot, None),
        "Cell": (cell_parts, cell_c, None),
        "CellHolo": (cell_holo, cell_c, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    empties = {
        "Muzzle": ((0, 0.74, 0.035), None),
        "SightPoint": ((0, 0.085, z_line), None),
        "SightMount": ((0, 0.2, rail_top), None),
        "EjectPoint": ((-0.17, 0.22, 0.03), None),
        "VentPoint": ((0.07, 0.215, 0.14), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("ion_carbine", groups, empties)


# ---------------------------------------------------------------------------
# Scatter Blaster
# ---------------------------------------------------------------------------

def build_scatter_blaster():
    reset_scene()
    M = weapon_mats()
    bore_z = 0.068
    hinge = (0, 0.215, -0.01)
    grip_loc = (0, -0.05, -0.145)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.08, 0.1, 0.2), body_bottom=-0.067)
    drum_c = (0, -0.005, 0.114)
    rail_top = 0.186
    z_line = rail_top + SIGHT_HEIGHT
    pump_c = (0, 0.385, -0.022)
    shell = grip_parts + [
        box("Body", (0.21, 0.27, 0.18), (0, 0.04, 0.03), bevel=0.05, segs=3, m=M["trim"]),
        box("TopPlate", (0.17, 0.09, 0.04), (0, 0.122, 0.118), bevel=0.014, m=M["shell"]),
        box("Stock", (0.15, 0.13, 0.14), (0, -0.14, 0.02), bevel=0.04, m=M["shell"]),
        box("StockPlate", (0.12, 0.012, 0.11), (0, -0.204, 0.02), bevel=0.005, m=M["dark"]),
        box("RearSlotFrame", (0.11, 0.014, 0.066), (0, -0.21, 0.035), bevel=0.01, m=M["trim"]),
        box("RearSlot", (0.085, 0.014, 0.04), (0, -0.214, 0.035), bevel=0.01, m=M["cell"]),
        xcyl("HingePin", 0.022, 0.24, hinge, m=M["steel"]),
        box("Breech", (0.2, 0.03, 0.15), (0, 0.19, 0.045), bevel=0.02, m=M["dark"]),
        # The drum sits in a well behind the breech, under the sight bridge.
        box("DrumSeat", (0.196, 0.13, 0.03), (0, -0.005, 0.11), bevel=0.01, m=M["dark"]),
        box("ShieldL", (0.012, 0.15, 0.1), (-0.11, 0.097, 0.03), bevel=0.006, m=M["shell"]),
        box("ShieldR", (0.012, 0.18, 0.1), (0.11, 0.06, 0.03), bevel=0.006, m=M["shell"]),
        box("SideLight", (0.006, 0.1, 0.012), (-0.117, 0.097, 0.09), bevel=0.002, m=M["cell"]),
        # Sight bridge over the drum: a post on the stock, a post on the top plate.
        box("BridgePostR", (0.036, 0.03, rail_top - 0.085), (0, -0.108, (rail_top + 0.07) / 2), bevel=0.008, m=M["trim"]),
        box("BridgePostF", (0.036, 0.03, rail_top - 0.14), (0, 0.11, (rail_top + 0.125) / 2), bevel=0.008, m=M["trim"]),
        box("BridgeGussetR", (0.03, 0.05, 0.02), (0, -0.09, rail_top - 0.03), rot=rad(-35, 0, 0), bevel=0.006, m=M["trim"]),
        box("BridgeGussetF", (0.03, 0.05, 0.02), (0, 0.092, rail_top - 0.03), rot=rad(35, 0, 0), bevel=0.006, m=M["trim"]),
        # Spare capsules in loops on the right of the stock.
        box("LoopStrap", (0.008, 0.1, 0.05), (0.077, -0.14, 0.03), bevel=0.003, m=M["dark"]),
        box("BellyPlate", (0.12, 0.2, 0.014), (0, 0.06, -0.06), bevel=0.005, m=M["dark"]),
    ]
    shell += top_rail("TopRail", -0.125, 0.125, rail_top, M)
    for i in range(3):
        shell.append(box(f"ShieldSlit{i}", (0.006, 0.03, 0.06), (-0.118, 0.052 + i * 0.045, 0.02), bevel=0.002, m=M["cell"]))
        shell.append(cyl(f"Spare{i}", 0.015, 0.06, (0.09, -0.175 + i * 0.035, 0.03), segs=10, bevel=0.005, m=M["cell"]))
        shell.append(cyl(f"SpareCap{i}", 0.017, 0.01, (0.09, -0.175 + i * 0.035, 0.062), segs=10, bevel=0.003, m=M["steel"]))
    shell += bolts("Bolt", [(0.1165, -0.01, 0.065), (0.1165, 0.13, 0.065), (0.1165, -0.01, -0.005), (0.1165, 0.13, -0.005),
                            (-0.1165, 0.035, -0.012), (-0.1165, 0.16, -0.012)], M["steel"])
    shell += bolts("StockBolt", [(-0.076, -0.17, 0.06), (-0.076, -0.17, -0.02), (0.076, -0.2, -0.03)], M["steel"], radius=0.006)
    lug, charm_point = charm_lug(-0.105, -0.05, 0.078, M)
    shell += lug
    sight_rear, _unused = sights_bead(0.0, -0.108, 0.5, rail_top, bore_z + 0.08, z_line, M)
    _unused2, sight_front = sights_bead(0.0, -0.108, 0.5, rail_top, bore_z + 0.072, z_line, M)

    barrels = []
    for i, x in enumerate((-0.058, 0.058)):
        barrels += [
            ycyl(f"Barrel{i}", 0.056, 0.36, 0.39, z=bore_z, x=x, m=M["shell"], segs=20, bevel=0.01),
            ycyl(f"MuzzleRing{i}", 0.064, 0.05, 0.565, z=bore_z, x=x, m=M["dark"], segs=20, bevel=0.012),
            ycyl(f"Bore{i}", 0.04, 0.02, 0.592, z=bore_z, x=x, m=M["cell"], segs=14, bevel=0.0),
            ycyl(f"BoreCore{i}", 0.024, 0.006, 0.602, z=bore_z, x=x, m=mat("Bore", "#120c22", rough=0.9), segs=12, bevel=0.0),
            tube(f"PlasmaTube{i}", [(x * 1.95, 0.25, bore_z - 0.015), (x * 1.95, 0.53, bore_z - 0.015)], 0.01, m=M["cell"], segs=6),
            ring(f"ChokeRing{i}", 0.058, 0.004, 0.33, z=bore_z, x=x, m=M["steel"], segs=20),
        ]
        for k in range(3):
            barrels.append(box(f"HeatVent{i}{k}", (0.02, 0.03, 0.01), (x, 0.3 + k * 0.045, bore_z + 0.055), bevel=0.003, m=M["dark"]))
    barrels += [
        box("Band", (0.25, 0.055, 0.15), (0, 0.49, bore_z), bevel=0.03, m=M["trim"]),
        box("BandRear", (0.24, 0.05, 0.14), (0, 0.25, bore_z), bevel=0.03, m=M["trim"]),
        box("RibTop", (0.03, 0.22, 0.014), (0, 0.37, bore_z + 0.058), bevel=0.004, m=M["dark"]),
        box("BandLight", (0.1, 0.006, 0.01), (0, 0.519, bore_z + 0.05), bevel=0.0, m=M["cell"]),
    ]
    barrels += bolts("BandBolt", [(-0.126, 0.49, bore_z), (-0.121, 0.25, bore_z)], M["steel"])
    barrels += bolts("BandBoltR", [(0.126, 0.49, bore_z), (0.121, 0.25, bore_z)], M["steel"])
    pump = [box("PumpBody", (0.2, 0.14, 0.075), pump_c, bevel=0.028, m=M["shell"])]
    for i, y in enumerate((0.3225, 0.4475)):
        pump.append(box(f"PumpRib{i}", (0.208, 0.012, 0.08), (0, y, pump_c[2]), bevel=0.004, m=M["dark"]))
    drum = [
        xcyl("DrumBody", 0.046, 0.14, drum_c, m=M["cell"], segs=18, bevel=0.01),
        xcyl("DrumCapA", 0.052, 0.03, (-0.08, drum_c[1], drum_c[2]), m=M["trim"], segs=18, bevel=0.008),
        xcyl("DrumCapB", 0.052, 0.03, (0.08, drum_c[1], drum_c[2]), m=M["trim"], segs=18, bevel=0.008),
        xcyl("DrumHubA", 0.016, 0.012, (-0.098, drum_c[1], drum_c[2]), m=M["steel"], segs=6, bevel=0.002),
        xcyl("DrumHubB", 0.016, 0.012, (0.098, drum_c[1], drum_c[2]), m=M["steel"], segs=6, bevel=0.002),
    ]
    for k in range(6):
        a = math.tau * k / 6
        drum.append(box(f"DrumRib{k}", (0.13, 0.011, 0.011), (0, drum_c[1] + math.cos(a) * 0.047, drum_c[2] + math.sin(a) * 0.047),
                        rot=(a, 0, 0), bevel=0.003, m=M["trim"]))
    capsule_pivot = (0, 0.2, bore_z)
    capsules = []
    for i, x in enumerate((-0.058, 0.058)):
        capsules += [
            ycyl(f"Capsule{i}", 0.034, 0.07, 0.2, z=bore_z, x=x, m=M["cell"], segs=14, bevel=0.01),
            ycyl(f"CapsuleRim{i}", 0.04, 0.014, 0.17, z=bore_z, x=x, m=M["steel"], segs=14, bevel=0.003),
        ]
    capsules_holo = holo_copy(capsules)
    teeth = [(-0.065, 0.022), (0.065, 0.022), (0.065, 0.0), (0.049, -0.028), (0.033, 0.0), (0.016, -0.028), (0.0, 0.0),
             (-0.016, -0.028), (-0.033, 0.0), (-0.049, -0.028), (-0.065, 0.0)]
    decal = [side_emblem("Emblem", teeth, -0.119, 0.097, 0.045, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = support_hand(pump_c, 0.104, 0.0405, M, (-0.52, -0.12, -0.46), corner=0.028, s_web=2.3, thumb_len=0.065)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.108, rail_top), None),
        "Barrels": (barrels, hinge, None),
        "IronSightFront": (sight_front, (0, 0.5, bore_z + 0.072), "Barrels"),
        "Pump": (pump, pump_c, "Barrels"),
        "Drum": (drum, drum_c, None),
        "Capsules": (capsules, capsule_pivot, None),
        "CapsulesHolo": (capsules_holo, capsule_pivot, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, pump_c, "Pump"),
    }
    empties = {
        "Muzzle": ((0, 0.6, bore_z), "Barrels"),
        "SightPoint": ((0, -0.108, z_line), None),
        "SightMount": ((0, 0.0, rail_top), None),
        "EjectPoint": ((0, 0.2, bore_z + 0.055), None),
        "VentPoint": ((0, 0.39, bore_z + 0.075), "Barrels"),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("scatter_blaster", groups, empties)


BUILDERS = (
    ("pulse_pistol", build_pulse_pistol),
    ("ion_carbine", build_ion_carbine),
    ("scatter_blaster", build_scatter_blaster),
)

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for name, fn in BUILDERS:
        if not only or name in only:
            fn()
