"""First-person viewmodels for the Arsenal weapons (unlocked by player level).

Same conventions and node contract as build_weapons.py (read its docstring):
origin at the top of the grip, pointing along +Y, cream/purple shell family,
materials Shell / Trim / Cell / GunDark / GunSteel / GunPink / Holo / Decal,
parts Shell, Cell, CellHolo, ArmL, ArmR, Decal, and the empties Muzzle,
SightPoint, EjectPoint, VentPoint and CharmPoint. Each weapon has its own
silhouette and accent ("Cell") colour, plus extra animated parts that its
reload script registers (scripts/weapons/reloads/):

  comet_cannon   amber   Crane > Cylinder > Cell/CellHolo (rounds), Hammer
  arc_coil       lime    Prongs, Vents, Cell (Tesla capsule), CellHolo
  bumper_lobber  magenta Lid, Crank, Cell (gumballs), CellHolo
  cryo_beam      ice     Panel (tank clamps), Needle, Fins, Cell (cryo tank), CellHolo
  rail_lancer    crimson Rails, Cell (capacitor), CellHolo

    python art/blender/build_weapons_arsenal.py [weapon_id ...]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wla_common import *  # noqa: F401,F403
from build_weapons import arm, side_profile, vent_slots, screws, side_emblem, holo_copy, finish, charm_loop  # noqa: E402


def wmats(accent, holo=None, shell="#f6dfae", trim="#6b35b8"):
    """The shared weapon materials, with this weapon's accent as the Cell glow."""
    return dict(
        shell=mat("Shell", shell, rough=0.38),
        trim=mat("Trim", trim, rough=0.36),
        cell=mat("Cell", accent, rough=0.3, emit=2.6),
        dark=mat("GunDark", "#241d3a", rough=0.45, metal=0.35),
        steel=mat("GunSteel", "#8a86a3", rough=0.3, metal=0.75),
        pink=mat("GunPink", "#ff3f9f", rough=0.4),
        holo=mat("Holo", holo or accent, rough=0.2, emit=1.5),
        decal=mat("Decal", "#ffd93b", rough=0.4),
    )


def ring(name, radius, minor, y, z=0.0, x=0.0, m=None, segs=20):
    """Torus around the barrel axis (along +Y)."""
    return torus(name, radius, minor, (x, y, z), rot=rad(90, 0, 0), m=m, major_segs=segs, minor_segs=6)


def ycyl(name, radius, length, y, z=0.0, x=0.0, m=None, segs=16, bevel=0.006, radius_top=None):
    """Cylinder lying along the barrel axis, centred at y. radius_top is the front end."""
    return cyl(name, radius, length, (x, y, z), rot=rad(-90, 0, 0), segs=segs, bevel=bevel, m=m, radius_top=radius_top)


def grip(prefix, loc, M, tilt=-14, size=(0.072, 0.094, 0.18), body_bottom=-0.02):
    """Rubberised grip with finger ridges, a trigger guard hung from the body
    underside (`body_bottom`) and a glowing trigger."""
    x, y, z = loc
    r = rad(tilt, 0, 0)
    parts = [box(prefix + "Grip", size, loc, rot=r, bevel=0.022, m=M["dark"]),
             box(prefix + "GripPanel", (size[0] + 0.006, size[1] * 0.6, size[2] * 0.6), (x, y - 0.004, z - 0.005), rot=r, bevel=0.014, m=M["trim"])]
    for i in range(3):
        parts.append(box(f"{prefix}Ridge{i}", (size[0] + 0.008, 0.012, 0.008), (x, y + 0.04 + i * 0.002, z + 0.03 - i * 0.04), rot=r, bevel=0.002, m=M["dark"]))
    gz = body_bottom - 0.058
    parts += [
        box(prefix + "Guard", (0.022, 0.1, 0.014), (x, y + 0.1, gz), bevel=0.005, m=M["dark"]),
        box(prefix + "GuardFront", (0.022, 0.014, 0.064), (x, y + 0.145, gz + 0.03), bevel=0.005, m=M["dark"]),
        box(prefix + "Trigger", (0.014, 0.014, 0.042), (x, y + 0.085, body_bottom - 0.026), rot=rad(15, 0, 0), bevel=0.004, m=M["cell"]),
    ]
    return parts


def fins(prefix, count, radius, y, z, size, m, start=0.0, sweep=0.0):
    """Radial fins around the barrel axis."""
    out = []
    for i in range(count):
        a = start + math.tau * i / count
        out.append(box(f"{prefix}{i}", size, (math.cos(a) * radius, y, z + math.sin(a) * radius),
                       rot=(sweep, math.pi / 2 - a, 0), bevel=min(size) * 0.3, m=m))
    return out


# ---------------------------------------------------------------------------
# Comet Hand Cannon: burst-fire heavy revolver
# ---------------------------------------------------------------------------

def build_comet_cannon():
    reset_scene()
    M = wmats("#ffb22e")
    bore_z = 0.092
    cyl_c = (0, 0.066, 0.066)
    shell = grip("", (0, -0.032, -0.095), M, tilt=-17, size=(0.072, 0.094, 0.175), body_bottom=-0.018)
    shell += [
        # Frame: rear block, lower bridge under the cylinder, top strap over it.
        box("FrameRear", (0.08, 0.06, 0.13), (0, -0.04, 0.062), bevel=0.02, m=M["trim"]),
        box("FrameLow", (0.074, 0.2, 0.04), (0, 0.06, 0.0), bevel=0.016, m=M["trim"]),
        box("TopStrap", (0.062, 0.17, 0.022), (0, 0.06, 0.124), bevel=0.008, m=M["trim"]),
        box("FramePlate", (0.084, 0.07, 0.07), (0, -0.04, 0.05), bevel=0.014, m=M["shell"]),
        box("RecoilShield", (0.07, 0.012, 0.11), (0, 0.006, 0.066), bevel=0.004, m=M["dark"]),
        box("SideStripe", (0.004, 0.13, 0.012), (-0.038, 0.06, 0.012), bevel=0.0, m=M["cell"]),
        # Barrel: heavy cream shroud, dark underlug with an amber light strip, vented rib.
        side_profile("Barrel", [(0.118, 0.052), (0.39, 0.052), (0.418, 0.068), (0.418, 0.112), (0.392, 0.128), (0.118, 0.128)], 0.064, (0, 0, 0), M["shell"], bevel=0.01),
        box("Underlug", (0.05, 0.25, 0.034), (0, 0.27, 0.04), bevel=0.014, m=M["dark"]),
        box("LugLightL", (0.004, 0.2, 0.009), (-0.026, 0.27, 0.04), bevel=0.0, m=M["cell"]),
        box("LugLightR", (0.004, 0.2, 0.009), (0.026, 0.27, 0.04), bevel=0.0, m=M["cell"]),
        box("Rib", (0.03, 0.29, 0.014), (0, 0.268, 0.134), bevel=0.004, m=M["dark"]),
        box("BarrelBand", (0.07, 0.03, 0.084), (0, 0.15, 0.09), bevel=0.012, m=M["trim"]),
        box("BarrelBandF", (0.07, 0.022, 0.084), (0, 0.37, 0.09), bevel=0.01, m=M["trim"]),
        # Comet muzzle: dark crown, amber emitter ring and swept tail fins.
        ycyl("Crown", 0.036, 0.036, 0.43, z=bore_z, m=M["dark"], segs=18),
        ring("Emitter", 0.024, 0.006, 0.45, z=bore_z, m=M["cell"]),
        ycyl("Bore", 0.017, 0.01, 0.446, z=bore_z, m=M["cell"], segs=12, bevel=0.0),
        # Sights: notched rear, blade front with an amber dot.
        box("SightRear", (0.05, 0.02, 0.022), (0, -0.04, 0.138), bevel=0.006, m=M["dark"]),
        box("SightNotch", (0.014, 0.024, 0.012), (0, -0.04, 0.146), bevel=0.0, m=M["cell"]),
        box("SightFront", (0.012, 0.03, 0.028), (0, 0.395, 0.142), bevel=0.005, m=M["dark"]),
        sphere("SightFrontDot", 0.0065, (0, 0.384, 0.152), m=M["cell"], segs=8, rings=5),
        # Ejector rod housing tip and a cylinder release button.
        ycyl("EjectorTip", 0.012, 0.02, 0.4, z=0.04, m=M["steel"], segs=10),
        box("Release", (0.012, 0.018, 0.016), (-0.042, -0.012, 0.09), bevel=0.004, m=M["cell"]),
    ]
    for i in range(5):
        shell.append(box(f"RibVent{i}", (0.016, 0.022, 0.006), (0, 0.17 + i * 0.05, 0.142), bevel=0.002, m=M["cell"]))
    for i, a in enumerate((90, 210, 330)):
        r = math.radians(a)
        shell.append(box(f"TailFin{i}", (0.01, 0.07, 0.03), (math.cos(r) * 0.042, 0.41, bore_z + math.sin(r) * 0.042),
                         rot=(math.radians(14), -r + math.pi / 2, 0), bevel=0.004, m=M["shell"]))
    shell += screws("Screw", [(-0.041, -0.05, 0.03), (-0.041, -0.05, 0.1), (-0.038, 0.12, 0.0)], M["steel"])
    shell += charm_loop((-0.042, -0.05, 0.002), M["steel"])

    hammer = [
        box("HammerBody", (0.024, 0.032, 0.04), (0, -0.075, 0.12), bevel=0.006, m=M["dark"]),
        box("HammerSpur", (0.03, 0.03, 0.014), (0, -0.092, 0.14), rot=rad(-25, 0, 0), bevel=0.004, m=M["dark"]),
        sphere("HammerGlow", 0.007, (0, -0.088, 0.122), m=M["cell"], segs=8, rings=5),
    ]
    crane_pivot = (-0.026, 0.066, 0.016)
    crane = [box("CraneArm", (0.016, 0.1, 0.022), (-0.02, 0.066, 0.024), bevel=0.005, m=M["steel"])]
    cylinder = [
        ycyl("CylBody", 0.054, 0.104, cyl_c[1], z=cyl_c[2], m=M["trim"], segs=24, bevel=0.012),
        ycyl("CylCore", 0.016, 0.116, cyl_c[1], z=cyl_c[2], m=M["steel"], segs=12),
        ycyl("CylStar", 0.022, 0.006, cyl_c[1] - 0.056, z=cyl_c[2], m=M["steel"], segs=6, bevel=0.0),
    ]
    rounds = []
    for k in range(6):
        a = math.tau * k / 6 + math.pi / 2
        cx, cz = math.cos(a) * 0.033, cyl_c[2] + math.sin(a) * 0.033
        # Flutes between the chambers, a comet core in each chamber.
        b = a + math.tau / 12
        cylinder.append(box(f"Flute{k}", (0.012, 0.074, 0.01), (math.cos(b) * 0.05, cyl_c[1], cyl_c[2] + math.sin(b) * 0.05),
                            rot=(0, -b + math.pi / 2, 0), bevel=0.003, m=M["dark"]))
        rounds.append(ycyl(f"Round{k}", 0.0125, 0.112, cyl_c[1], z=cz, x=cx, m=M["cell"], segs=10, bevel=0.003))
        rounds.append(ycyl(f"RoundRim{k}", 0.015, 0.008, cyl_c[1] - 0.056, z=cz, x=cx, m=M["steel"], segs=10, bevel=0.002))
    rounds_holo = holo_copy(rounds)
    rounds_holo.append(torus("LoaderRing", 0.042, 0.006, (0, cyl_c[1] - 0.066, cyl_c[2]), rot=rad(90, 0, 0), m=mat("Holo"), major_segs=20, minor_segs=5))

    star = [(0.0, 0.03), (0.009, 0.009), (0.03, 0.0), (0.009, -0.009), (0.0, -0.03), (-0.009, -0.009), (-0.03, 0.0), (-0.009, 0.009)]
    decal = [side_emblem("Emblem", star, -0.043, -0.035, 0.07, M["decal"])]
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "Hammer": (hammer, (0, -0.07, 0.1), None),
        "Crane": (crane, crane_pivot, None),
        "Cylinder": (cylinder, cyl_c, "Crane"),
        "Cell": (rounds, cyl_c, "Cylinder"),
        "CellHolo": (rounds_holo, cyl_c, "Cylinder"),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm("R", (0.0, -0.03, -0.1), (0.42, -0.5, -0.36), thumb_side=-1.0), (0, 0, 0), None),
        "ArmL": (arm("L", (-0.07, -0.005, -0.14), (-0.55, -0.32, -0.32), thumb_side=-1.0, underhand=True), (0, 0, 0), None),
    }
    empties = {
        "Muzzle": ((0, 0.458, bore_z), None),
        "SightPoint": ((0, -0.04, 0.151), None),
        "EjectPoint": ((-0.06, -0.01, 0.05), None),
        "VentPoint": ((0, 0.27, 0.15), None),
        "CharmPoint": ((-0.045, -0.05, -0.009), None),
    }
    finish("comet_cannon", groups, empties)


# ---------------------------------------------------------------------------
# Arc Coil: Tesla thrower with a chaining arc
# ---------------------------------------------------------------------------

def build_arc_coil():
    reset_scene()
    M = wmats("#b8ff3a")
    copper = mat("Copper", "#e2894a", rough=0.32, metal=0.7)
    ceramic = mat("Ceramic", "#fbf3e6", rough=0.25)
    bore_z = 0.045
    tower = (-0.042, 0.11, 0.105)
    shell = grip("", (0, -0.03, -0.13), M, tilt=-13, size=(0.075, 0.095, 0.19), body_bottom=-0.052)
    shell += [
        box("Body", (0.15, 0.3, 0.13), (0, 0.11, 0.04), bevel=0.04, segs=3, m=M["trim"]),
        box("SidePanel", (0.158, 0.2, 0.07), (0, 0.1, 0.03), bevel=0.02, m=M["shell"]),
        box("RearCap", (0.13, 0.07, 0.115), (0, -0.065, 0.045), bevel=0.035, m=M["shell"]),
        box("RearSlotFrame", (0.09, 0.02, 0.06), (0, -0.102, 0.05), bevel=0.012, m=M["trim"]),
        box("RearSlot", (0.07, 0.02, 0.036), (0, -0.108, 0.05), bevel=0.01, m=M["cell"]),
        box("Belly", (0.11, 0.2, 0.04), (0, 0.14, -0.035), bevel=0.016, m=M["dark"]),
        # Front collar and the ceramic insulator stack around the electrode.
        ycyl("Collar", 0.068, 0.05, 0.285, z=bore_z, m=M["dark"], segs=20, bevel=0.012),
        ring("CollarGlow", 0.066, 0.006, 0.305, z=bore_z, m=M["cell"]),
        ycyl("Rod", 0.012, 0.16, 0.37, z=bore_z, m=M["steel"], segs=10),
        sphere("Electrode", 0.024, (0, 0.452, bore_z), m=M["cell"], segs=14, rings=8),
        # Tesla tower cradle (left on top) with copper windings.
        box("TowerBase", (0.07, 0.09, 0.022), (tower[0], tower[1], tower[2]), bevel=0.008, m=M["dark"]),
        cyl("TowerCollar", 0.04, 0.02, (tower[0], tower[1], tower[2] + 0.02), segs=18, bevel=0.006, m=M["steel"]),
        # Reflex ring sight on the right of the tower.
        box("SightPost", (0.026, 0.04, 0.036), (0.032, 0.0, 0.118), bevel=0.008, m=M["dark"]),
        torus("SightRing", 0.019, 0.004, (0.032, 0.0, 0.15), rot=rad(90, 0, 0), m=M["trim"], major_segs=18, minor_segs=5),
        sphere("SightDot", 0.0045, (0.032, 0.003, 0.15), m=M["pink"], segs=8, rings=5),
        box("FrontPost", (0.012, 0.02, 0.03), (0.032, 0.25, 0.122), bevel=0.004, m=M["dark"]),
        sphere("FrontDot", 0.006, (0.032, 0.25, 0.14), m=M["cell"], segs=8, rings=5),
        # Cables: a pink power line and a glowing feed into the tower.
        tube("CableR", [(0.07, -0.06, 0.06), (0.095, 0.05, 0.09), (0.094, 0.2, 0.08), (0.06, 0.27, 0.07)], 0.011, m=M["pink"], segs=6),
        tube("CableL", [(-0.065, -0.06, 0.02), (-0.085, 0.0, 0.07), (-0.07, 0.07, 0.1)], 0.009, m=M["cell"], segs=6),
    ]
    for i in range(4):
        shell.append(ycyl(f"Insulator{i}", 0.038 - i * 0.004, 0.012, 0.33 + i * 0.022, z=bore_z, m=ceramic, segs=16, bevel=0.004))
    for i in range(5):
        shell.append(torus(f"Winding{i}", 0.033, 0.0055, (tower[0], tower[1], tower[2] + 0.04 + i * 0.016), m=copper, major_segs=16, minor_segs=5))
    for i in range(4):
        shell.append(cyl(f"CradlePost{i}", 0.005, 0.1, (tower[0] + math.cos(i * math.pi / 2 + 0.78) * 0.038, tower[1] + math.sin(i * math.pi / 2 + 0.78) * 0.038,
                                                       tower[2] + 0.07), segs=6, bevel=0.0, m=M["steel"]))
    shell += vent_slots("Vent", -0.08, 0.02, 0.2, 0.03, 4, M["dark"], M["cell"])
    shell += screws("Screw", [(0.078, 0.0, 0.0), (0.078, 0.22, 0.0)], M["steel"])
    shell += charm_loop((-0.077, -0.05, -0.005), M["steel"])

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
    vents = []
    for i in range(3):
        vents.append(box(f"VentSlat{i}", (0.05, 0.018, 0.008), (0.035, 0.17 + i * 0.028, 0.108), bevel=0.003, m=M["dark"]))
    # The Tesla capsule: glass core, copper top ring and a glowing crown.
    capsule = [
        cyl("CapsuleGlass", 0.021, 0.11, (tower[0], tower[1], tower[2] + 0.085), segs=14, bevel=0.006, m=M["cell"]),
        torus("CapsuleHat", 0.036, 0.011, (tower[0], tower[1], tower[2] + 0.148), m=M["steel"], major_segs=18, minor_segs=6),
        sphere("CapsuleCrown", 0.022, (tower[0], tower[1], tower[2] + 0.158), m=M["cell"], segs=14, rings=8),
        cyl("CapsuleFoot", 0.026, 0.016, (tower[0], tower[1], tower[2] + 0.034), segs=14, bevel=0.004, m=M["dark"]),
    ]
    capsule_holo = holo_copy(capsule)
    bolt = [(-0.008, 0.03), (0.016, 0.03), (0.004, 0.006), (0.018, 0.006), (-0.01, -0.034), (-0.002, -0.006), (-0.018, -0.006)]
    decal = [side_emblem("Emblem", bolt, -0.08, 0.1, 0.075, M["decal"])]
    cap_pivot = (tower[0], tower[1], tower[2] + 0.09)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "Prongs": (prongs, (0, 0.3, bore_z), None),
        "Vents": (vents, (0.035, 0.2, 0.108), None),
        "Cell": (capsule, cap_pivot, None),
        "CellHolo": (capsule_holo, cap_pivot, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm("R", (0.0, -0.03, -0.14), (0.17, -0.62, -0.44), thumb_side=-1.0), (0, 0, 0), None),
        "ArmL": (arm("L", (-0.02, 0.17, -0.1), (-0.52, -0.16, -0.46), thumb_side=-1.0, underhand=True), (0, 0, 0), None),
    }
    empties = {
        "Muzzle": ((0, 0.47, bore_z), None),
        "SightPoint": ((0.032, -0.01, 0.15), None),
        "EjectPoint": ((tower[0] - 0.05, tower[1], tower[2] + 0.12), None),
        "VentPoint": ((0.035, 0.2, 0.12), None),
        "CharmPoint": ((-0.08, -0.05, -0.016), None),
    }
    finish("arc_coil", groups, empties)


# ---------------------------------------------------------------------------
# Bumper Lobber: gumball grenade launcher
# ---------------------------------------------------------------------------

def build_bumper_lobber():
    reset_scene()
    M = wmats("#ff4fe0")
    bore_z = 0.05
    dome = (-0.045, 0.05, 0.14)
    shell = grip("", (0, -0.03, -0.13), M, tilt=-14, size=(0.078, 0.098, 0.19), body_bottom=-0.04)
    shell += [
        box("Body", (0.17, 0.26, 0.15), (0, 0.08, 0.035), bevel=0.05, segs=3, m=M["trim"]),
        box("BodyPanel", (0.176, 0.16, 0.08), (0, 0.06, 0.03), bevel=0.025, m=M["shell"]),
        box("Stock", (0.13, 0.1, 0.12), (0, -0.1, 0.035), bevel=0.04, m=M["shell"]),
        box("StockPad", (0.11, 0.02, 0.09), (0, -0.155, 0.035), bevel=0.012, m=M["dark"]),
        # Fat barrel with bands, a pink stripe and a flared bell.
        ycyl("Barrel", 0.064, 0.25, 0.32, z=bore_z, m=M["shell"], segs=24, bevel=0.012),
        ring("BandRear", 0.066, 0.008, 0.215, z=bore_z, m=M["trim"]),
        ring("BandMid", 0.066, 0.008, 0.35, z=bore_z, m=M["trim"]),
        ring("Stripe", 0.065, 0.006, 0.28, z=bore_z, m=M["pink"]),
        ycyl("Bell", 0.07, 0.06, 0.47, z=bore_z, m=M["dark"], segs=24, bevel=0.012, radius_top=0.086),
        ring("BellGlow", 0.062, 0.007, 0.5, z=bore_z, m=M["cell"]),
        ycyl("BoreDark", 0.054, 0.01, 0.497, z=bore_z, m=mat("Bore", "#120c22", rough=0.9), segs=20, bevel=0.0),
        # Foregrip under the barrel.
        box("Foregrip", (0.07, 0.11, 0.05), (0, 0.33, -0.03), bevel=0.02, m=M["trim"]),
        box("ForegripPad", (0.076, 0.07, 0.03), (0, 0.33, -0.045), bevel=0.01, m=M["dark"]),
        # Gumball hopper: base, cage ribs (top cap is the Lid).
        cyl("HopperBase", 0.058, 0.03, (dome[0], dome[1], dome[2] - 0.035), segs=24, bevel=0.01, m=M["trim"]),
        torus("HopperRim", 0.06, 0.007, (dome[0], dome[1], dome[2] - 0.02), m=M["cell"], major_segs=24, minor_segs=5),
        box("HopperNeck", (0.05, 0.05, 0.05), (dome[0] + 0.012, dome[1], dome[2] - 0.065), bevel=0.012, m=M["dark"]),
        # Leaf sight on the right, rear peep + front ring.
        box("PeepPost", (0.022, 0.03, 0.05), (0.048, -0.02, 0.135), bevel=0.006, m=M["dark"]),
        torus("Peep", 0.013, 0.004, (0.048, -0.02, 0.165), rot=rad(90, 0, 0), m=M["trim"], major_segs=16, minor_segs=5),
        box("LeafPost", (0.016, 0.02, 0.06), (0.048, 0.3, 0.13), bevel=0.005, m=M["dark"]),
        torus("LeafRing", 0.02, 0.0035, (0.048, 0.3, 0.165), rot=rad(90, 0, 0), m=M["cell"], major_segs=18, minor_segs=5),
        box("LeafBar", (0.03, 0.006, 0.004), (0.048, 0.3, 0.158), bevel=0.0, m=M["cell"]),
        box("SightRail", (0.03, 0.34, 0.016), (0.048, 0.14, 0.11), bevel=0.005, m=M["dark"]),
        # Crank housing on the right.
        cyl("CrankHub", 0.03, 0.02, (0.092, 0.05, 0.04), rot=rad(0, 90, 0), segs=18, bevel=0.006, m=M["dark"]),
    ]
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        shell.append(torus(f"CageRib{i}", 0.062, 0.0045, (dome[0], dome[1], dome[2] - 0.02),
                           rot=(math.pi / 2, 0, a), m=M["steel"], major_segs=16, minor_segs=5, arc=math.pi * 0.42, start=0.0))
    shell += vent_slots("Vent", -0.088, 0.1, 0.18, 0.06, 3, M["dark"], M["cell"])
    shell += screws("Screw", [(0.088, -0.02, 0.0), (0.088, 0.16, 0.0)], M["steel"])
    shell += charm_loop((-0.088, -0.07, 0.0), M["steel"])

    lid_pivot = (dome[0], dome[1] - 0.06, dome[2] + 0.04)
    lid = [
        cyl("LidCap", 0.036, 0.016, (dome[0], dome[1], dome[2] + 0.052), segs=20, bevel=0.006, m=M["shell"]),
        sphere("LidKnob", 0.016, (dome[0], dome[1], dome[2] + 0.068), m=M["pink"], segs=12, rings=8),
        box("LidHinge", (0.03, 0.014, 0.012), (dome[0], dome[1] - 0.056, dome[2] + 0.04), bevel=0.004, m=M["steel"]),
        torus("LidRing", 0.04, 0.005, (dome[0], dome[1], dome[2] + 0.045), m=M["steel"], major_segs=20, minor_segs=5),
    ]
    crank = [
        box("CrankArm", (0.012, 0.012, 0.07), (0.106, 0.05, 0.065), bevel=0.004, m=M["steel"]),
        cyl("CrankKnob", 0.012, 0.03, (0.118, 0.05, 0.098), rot=rad(0, 90, 0), segs=12, bevel=0.005, m=M["pink"]),
    ]
    balls = []
    spots = [(-0.02, -0.015, -0.005), (0.02, -0.012, -0.004), (0.0, 0.022, -0.003), (-0.012, 0.004, 0.032), (0.016, 0.012, 0.03)]
    for i, (dx, dy, dz) in enumerate(spots):
        balls.append(sphere(f"Ball{i}", 0.022, (dome[0] + dx, dome[1] + dy, dome[2] + dz), m=M["cell"], segs=14, rings=9))
        balls.append(torus(f"BallBand{i}", 0.0215, 0.003, (dome[0] + dx, dome[1] + dy, dome[2] + dz), rot=rad(70, 20 * i, 0),
                           m=M["shell"], major_segs=14, minor_segs=4))
    balls_holo = holo_copy(balls)
    swirl = [(math.cos(math.tau * k / 10) * (0.02 + 0.008 * (k % 2)), math.sin(math.tau * k / 10) * (0.02 + 0.008 * (k % 2))) for k in range(10)]
    decal = [side_emblem("Emblem", swirl, -0.089, 0.05, 0.05, M["decal"])]
    ball_pivot = (dome[0], dome[1], dome[2])
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "Lid": (lid, lid_pivot, None),
        "Crank": (crank, (0.092, 0.05, 0.04), None),
        "Cell": (balls, ball_pivot, None),
        "CellHolo": (balls_holo, ball_pivot, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm("R", (0.0, -0.03, -0.14), (0.17, -0.62, -0.44), thumb_side=-1.0), (0, 0, 0), None),
        "ArmL": (arm("L", (-0.02, 0.33, -0.1), (-0.52, -0.12, -0.46), thumb_side=-1.0, underhand=True), (0, 0, 0), None),
    }
    empties = {
        "Muzzle": ((0, 0.51, bore_z), None),
        "SightPoint": ((0.048, -0.025, 0.165), None),
        "EjectPoint": ((dome[0], dome[1], dome[2] + 0.07), None),
        "VentPoint": ((0, 0.5, bore_z + 0.07), None),
        "CharmPoint": ((-0.091, -0.07, -0.011), None),
    }
    finish("bumper_lobber", groups, empties)


# ---------------------------------------------------------------------------
# Frostbite Cryo Beam: freezing beam projector
# ---------------------------------------------------------------------------

def build_cryo_beam():
    reset_scene()
    M = wmats("#a8ecff", holo="#bff3ff")
    frost = mat("Frost", "#eaf6ff", rough=0.28)
    bore_z = 0.05
    tank_x, tank_y, tank_z = -0.098, 0.15, 0.06
    shell = grip("", (0, -0.03, -0.14), M, tilt=-12, size=(0.074, 0.094, 0.19), body_bottom=-0.025)
    shell += [
        box("Body", (0.14, 0.4, 0.13), (0, 0.14, 0.04), bevel=0.04, segs=3, m=M["trim"]),
        box("FrostPanel", (0.146, 0.24, 0.07), (0, 0.15, 0.025), bevel=0.02, m=frost),
        box("Stock", (0.12, 0.1, 0.12), (0, -0.09, 0.045), bevel=0.04, m=M["shell"]),
        box("StockPad", (0.1, 0.02, 0.09), (0, -0.145, 0.045), bevel=0.012, m=M["dark"]),
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
        # Gauge on top (the needle is its own part).
        cyl("GaugeBody", 0.026, 0.02, (0.03, 0.03, 0.13), segs=20, bevel=0.006, m=M["steel"]),
        cyl("GaugeFace", 0.021, 0.006, (0.03, 0.03, 0.141), segs=20, bevel=0.0, m=frost),
        box("GaugeRed", (0.012, 0.004, 0.002), (0.042, 0.03, 0.1445), bevel=0.0, m=M["pink"]),
        # Reflex sight.
        box("SightBase", (0.06, 0.07, 0.022), (0, 0.17, 0.135), bevel=0.008, m=M["dark"]),
        box("SightFrameL", (0.01, 0.025, 0.06), (-0.034, 0.18, 0.17), bevel=0.004, m=M["trim"]),
        box("SightFrameR", (0.01, 0.025, 0.06), (0.034, 0.18, 0.17), bevel=0.004, m=M["trim"]),
        box("SightFrameT", (0.078, 0.025, 0.01), (0, 0.18, 0.202), bevel=0.004, m=M["trim"]),
        box("SightPane", (0.058, 0.003, 0.048), (0, 0.184, 0.171), bevel=0.0, m=M["holo"]),
        sphere("SightDot", 0.0055, (0, 0.182, 0.171), m=M["pink"], segs=8, rings=5),
        # Vertical foregrip.
        box("Foregrip", (0.045, 0.055, 0.11), (0, 0.32, -0.06), rot=rad(8, 0, 0), bevel=0.018, m=M["trim"]),
        box("ForegripMount", (0.07, 0.09, 0.03), (0, 0.32, -0.01), bevel=0.01, m=M["dark"]),
        tube("Hose", [(-0.06, -0.04, 0.0), (-0.09, 0.0, -0.01), (-0.1, 0.02, 0.03)], 0.01, m=M["cell"], segs=6),
    ]
    for i in range(4):
        shell.append(ring(f"Coil{i}", 0.041, 0.0065, 0.33 + i * 0.03, z=bore_z, m=M["steel"]))
        shell.append(ring(f"CoilGlow{i}", 0.036, 0.004, 0.345 + i * 0.03, z=bore_z, m=M["cell"]))
    for i in range(3):
        a = math.radians(70 + i * 20)
        shell.append(prism(f"Icicle{i}", [(-0.006, 0.0), (0.006, 0.0), (0.0, -0.03)], 0.006,
                           (math.cos(a) * 0.07, 0.55, bore_z - 0.035 - 0.004 * i), m=frost))
    shell += screws("Screw", [(0.072, 0.02, 0.0), (0.072, 0.26, 0.0)], M["steel"])
    shell += charm_loop((-0.072, -0.03, -0.012), M["steel"])

    fins_parts = fins("Fin", 6, 0.056, 0.45, bore_z, (0.006, 0.07, 0.03), frost, start=math.pi / 6)
    needle = [box("NeedleBar", (0.003, 0.016, 0.003), (0.03, 0.038, 0.146), bevel=0.0, m=M["dark"])]
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
    decal = [side_emblem("Emblem", flake, -0.074, 0.3, 0.06, M["decal"])]
    tank_pivot = (tank_x, tank_y, tank_z)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "Fins": (fins_parts, (0, 0.45, bore_z), None),
        "Needle": (needle, (0.03, 0.03, 0.146), None),
        "Panel": (clamps, clamp_pivot, None),
        "Cell": (tank, tank_pivot, None),
        "CellHolo": (tank_holo, tank_pivot, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm("R", (0.0, -0.03, -0.15), (0.17, -0.62, -0.44), thumb_side=-1.0), (0, 0, 0), None),
        "ArmL": (arm("L", (-0.01, 0.325, -0.13), (-0.52, -0.16, -0.46), thumb_side=-1.0, underhand=True), (0, 0, 0), None),
    }
    empties = {
        "Muzzle": ((0, 0.575, bore_z), None),
        "SightPoint": ((0, 0.1, 0.171), None),
        "EjectPoint": ((tank_x - 0.06, tank_y, tank_z), None),
        "VentPoint": ((0, 0.45, bore_z + 0.06), None),
        "CharmPoint": ((-0.075, -0.03, -0.023), None),
    }
    finish("cryo_beam", groups, empties)


# ---------------------------------------------------------------------------
# Rail Lancer: charge-up piercing railgun
# ---------------------------------------------------------------------------

def build_rail_lancer():
    reset_scene()
    M = wmats("#ff2f5a")
    axis_z = 0.05
    shell = grip("", (0, -0.03, -0.14), M, tilt=-12, size=(0.074, 0.094, 0.19), body_bottom=-0.01)
    shell += [
        side_profile("Receiver", [(-0.09, -0.01), (0.33, -0.01), (0.35, 0.02), (0.35, 0.1), (0.31, 0.118), (-0.05, 0.118), (-0.09, 0.09)],
                     0.12, (0, 0, 0), M["trim"], bevel=0.02),
        box("SidePanel", (0.126, 0.26, 0.06), (0, 0.13, 0.05), bevel=0.02, m=M["shell"]),
        box("TopCover", (0.08, 0.3, 0.02), (0, 0.14, 0.124), bevel=0.008, m=M["shell"]),
        box("Handguard", (0.08, 0.14, 0.05), (0, 0.32, -0.02), bevel=0.02, m=M["shell"]),
        box("HandguardPad", (0.086, 0.09, 0.03), (0, 0.32, -0.035), bevel=0.01, m=M["dark"]),
        # Skeleton stock.
        box("StockTop", (0.05, 0.22, 0.032), (0, -0.19, 0.08), bevel=0.012, m=M["shell"]),
        box("StockLow", (0.05, 0.2, 0.03), (0, -0.18, -0.01), rot=rad(-9, 0, 0), bevel=0.012, m=M["shell"]),
        box("StockPad", (0.064, 0.04, 0.14), (0, -0.305, 0.035), bevel=0.016, m=M["dark"]),
        box("Cheek", (0.056, 0.12, 0.03), (0, -0.16, 0.105), bevel=0.012, m=M["trim"]),
        # Aperture sight: dark rear ring, glowing front ring with a crosshair.
        box("SightRail", (0.03, 0.28, 0.014), (0, 0.12, 0.137), bevel=0.004, m=M["dark"]),
        box("RearMount", (0.03, 0.03, 0.03), (0, 0.0, 0.15), bevel=0.006, m=M["dark"]),
        torus("RearRing", 0.02, 0.0045, (0, 0.0, 0.175), rot=rad(90, 0, 0), m=M["dark"], major_segs=20, minor_segs=6),
        box("FrontMount", (0.024, 0.026, 0.024), (0, 0.24, 0.148), bevel=0.006, m=M["dark"]),
        torus("FrontRing", 0.024, 0.0045, (0, 0.24, 0.175), rot=rad(90, 0, 0), m=M["cell"], major_segs=22, minor_segs=6),
        box("CrossH", (0.034, 0.002, 0.0018), (0, 0.24, 0.175), bevel=0.0, m=M["cell"]),
        box("CrossV", (0.0018, 0.002, 0.034), (0, 0.24, 0.175), bevel=0.0, m=M["cell"]),
        # Inner coil running between the rails.
        ycyl("Coil", 0.013, 0.34, 0.52, z=axis_z, m=M["steel"], segs=10),
        ycyl("RailRoot", 0.05, 0.05, 0.35, z=axis_z, m=M["dark"], segs=18, bevel=0.012),
        # Crimson stripe and right-side vents.
        box("Stripe", (0.004, 0.24, 0.012), (-0.062, 0.14, 0.096), bevel=0.0, m=M["cell"]),
        tube("CableR", [(0.06, -0.05, 0.03), (0.075, 0.1, 0.02), (0.07, 0.3, 0.03)], 0.01, m=M["pink"], segs=6),
    ]
    shell += vent_slots("Vent", 0.064, 0.02, 0.26, 0.09, 5, M["dark"], M["cell"], side=1)
    shell += screws("Screw", [(-0.062, 0.0, 0.0), (-0.062, 0.3, 0.0)], M["steel"])
    shell += charm_loop((-0.062, -0.06, 0.035), M["steel"])
    # Charge rings around the rail gap.
    for i in range(3):
        shell.append(ring(f"ChargeRing{i}", 0.054, 0.0075, 0.47 + i * 0.12, z=axis_z, m=M["cell"], segs=22))
        shell.append(ring(f"RingCollar{i}", 0.058, 0.004, 0.47 + i * 0.12, z=axis_z, m=M["dark"], segs=22))

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
    ]
    for k in range(4):
        capacitor.append(box(f"CapPip{k}", (0.006, 0.014, 0.01), (-0.09, 0.13 + k * 0.026, 0.017), bevel=0.002, m=M["cell"]))
    capacitor_holo = holo_copy(capacitor)
    chevron = [(-0.03, 0.012), (0.0, -0.016), (0.03, 0.012), (0.03, 0.024), (0.0, -0.004), (-0.03, 0.024)]
    decal = [side_emblem("Emblem", chevron, -0.064, 0.27, 0.06, M["decal"])]
    cap_pivot = (-0.074, 0.17, 0.035)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "Rails": (rails, (0, 0.34, axis_z), None),
        "Cell": (capacitor, cap_pivot, None),
        "CellHolo": (capacitor_holo, cap_pivot, None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm("R", (0.0, -0.03, -0.15), (0.17, -0.62, -0.44), thumb_side=-1.0), (0, 0, 0), None),
        "ArmL": (arm("L", (-0.02, 0.32, -0.085), (-0.52, -0.14, -0.46), thumb_side=-1.0, underhand=True), (0, 0, 0), None),
    }
    empties = {
        "Muzzle": ((0, 0.85, axis_z), None),
        "SightPoint": ((0, -0.01, 0.175), None),
        "EjectPoint": ((-0.12, 0.17, 0.0), None),
        "VentPoint": ((0, 0.6, axis_z + 0.07), None),
        "CharmPoint": ((-0.065, -0.06, 0.024), None),
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
