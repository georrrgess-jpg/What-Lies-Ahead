"""The Dune Spaceport loadout station: a supply drop pod that came down on the apron
and has been unpacked.

    dune_station.glb   Nodes:
        Pod            everything static, in one mesh: the capsule on four landing legs
                       with a lit cargo bay cut into the front (energy-cell rack,
                       med-kits, ration packs, ammo cans and a cargo net), a sealed back
                       hatch, stencils, a holo screen, status-lamp housings, antenna and
                       dish; the deflated parachute; the blast mark, scorch streaks and
                       sand rim; and the unloaded cargo (a charging rack of energy
                       cells, a netted crate stack, a holo terminal, a pallet of rations
                       and med-kits).
        Hatch          the front hatch door, pivot on its bottom hinge, exported closed
                       (upright over the bay). scenes/props/dune_station.tscn drops it
                       into a ramp while the station is open.
        OpenLamps      green status lamps and the bay's holo banner (shown while open).
        ClosedLamps    red status lamps (shown while closed).

About 5.6 m tall, 7 m across the legs. Front faces -Y (Godot +Z).

    python art/blender/build_dune_station.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dune_kit import *  # noqa: F401,F403
from mathutils import Euler, Matrix, Vector

POD_R = 2.45
BAY_W, BAY_Z0, BAY_Z1 = 2.0, 1.12, 2.98      # opening width and height range
BAY_BACK = -1.42                            # y of the bay's back wall
FRAME_Y = -2.44                             # y of the hatch frame's centre
HINGE = (0.0, -2.82, 1.04)                  # front door hinge (Blender coordinates)
DOOR_H = 1.95
DOOR_OPEN = 123.0                           # degrees about X once open (ramp on the ground)


def mats():
    return dict(
        white=dmat("Hull", rough=0.45),
        teal=dmat("Teal", rough=0.45), tdark=dmat("TealDark", rough=0.5),
        rust=dmat("Rust", rough=0.55), rdark=dmat("RustDark", rough=0.6),
        steel=dmat("Steel", rough=0.4, metal=0.5), sdark=dmat("SteelDark", rough=0.45, metal=0.4),
        inside=dmat("Interior", rough=1.0), shield=dmat("HeatShield", "#5a3a30", rough=0.8),
        cell=dglow("CellGlow", "#5cf2ff", 2.2), screen=dglow("ScreenGlow", "#7cf6d8", 1.8),
        amber=dglow("LiftAmber", "#ffa12a", 3.0), navy=dmat("Navy", rough=0.5),
        bay=dglow("BayLight", "#86a6c8", 0.3), ration=dmat("Ration", "#ff8a2a", rough=0.35, metal=0.3),
        rubber=dmat("Rubber", rough=0.8), hazard=dmat("Hazard"), hdark=dmat("HazardDark"),
        sand=dmat("Sand", rough=0.95),
    )


def xform(parts, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Move a group of parts as one rigid piece (rotate XYZ about the origin, then translate)."""
    mtx = Matrix.Translation(Vector(loc)) @ Euler(rot, "XYZ").to_matrix().to_4x4()
    for ob in parts:
        ob.matrix_world = mtx @ ob.matrix_basis
    return parts


def cut(ob, cutter):
    """Boolean the bay opening out of a hull part (kept as a live modifier)."""
    mod = ob.modifiers.new("BayCut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    return ob


def bolt(name, size, loc, m, rot=(0, 0, 0), depth=0.02):
    """Lightning-bolt decal facing -Y."""
    s = size
    outline = [(-0.2 * s, 1.0 * s), (-0.7 * s, -0.05 * s), (-0.1 * s, -0.05 * s), (-0.4 * s, -1.05 * s),
               (0.65 * s, 0.25 * s), (0.05 * s, 0.25 * s), (0.3 * s, 1.0 * s)]
    return prism(name, outline, depth, loc, rot, m=m)


def cross(prefix, size, loc, m, depth=0.03, rot_z=0.0):
    """A plus-sign decal facing -Y."""
    return place([fbox(prefix + "H", (size, depth, size * 0.32), (0, 0, 0), m=m),
                  fbox(prefix + "V", (size * 0.32, depth, size), (0, 0, 0), m=m)], loc, rot_z)


# ---------------------------------------------------------------------------
# Cargo
# ---------------------------------------------------------------------------

def cell(prefix, m, loc, h=0.4, r=0.1):
    """Upright energy cell: glowing core between steel caps."""
    x, y, z = loc
    return [
        cyl(prefix + "Core", r, h, (x, y, z + h / 2), segs=10, bevel=0.0, m=m["cell"]),
        cyl(prefix + "CapB", r * 1.15, 0.06, (x, y, z + 0.03), segs=10, bevel=0.0, m=m["steel"]),
        cyl(prefix + "CapT", r * 1.15, 0.07, (x, y, z + h - 0.02), segs=10, bevel=0.0, m=m["steel"]),
        cyl(prefix + "Pin", r * 0.4, 0.05, (x, y, z + h + 0.04), segs=6, bevel=0.0, m=m["sdark"]),
    ]


def medkit(prefix, m, loc, rot_z=0.0, size=(0.4, 0.28, 0.28)):
    w, d, h = size
    parts = [
        box(prefix + "Case", size, (0, 0, h / 2), bevel=0.05, segs=1, m=m["white"]),
        fbox(prefix + "Seam", (w + 0.01, d + 0.01, 0.025), (0, 0, h * 0.72), m=m["tdark"]),
        box(prefix + "Grip", (w * 0.4, 0.06, 0.05), (0, 0, h + 0.03), bevel=0.02, segs=1, m=m["sdark"]),
    ]
    parts += cross(prefix + "Cross", h * 0.62, (0, -d / 2 - 0.01, h * 0.42), m["teal"])
    return place(parts, loc, rot_z)


def ration(prefix, m, loc, rot_z=0.0):
    """A foil ration pouch standing up, with a label band."""
    parts = [
        box(prefix + "Pouch", (0.22, 0.08, 0.3), (0, 0, 0.15), bevel=0.035, segs=1, m=m["ration"]),
        fbox(prefix + "Label", (0.16, 0.09, 0.1), (0, 0, 0.14), m=m["white"]),
        fbox(prefix + "Crimp", (0.23, 0.05, 0.03), (0, 0, 0.3), m=m["rdark"]),
    ]
    return place(parts, loc, rot_z)


def ammo_can(prefix, m, loc, rot_z=0.0):
    parts = [
        box(prefix + "Can", (0.5, 0.26, 0.3), (0, 0, 0.15), bevel=0.03, segs=1, m=m["tdark"]),
        fbox(prefix + "Lid", (0.52, 0.28, 0.05), (0, 0, 0.29), m=m["sdark"]),
        box(prefix + "Handle", (0.22, 0.05, 0.04), (0, 0, 0.34), bevel=0.015, segs=1, m=m["steel"]),
        fbox(prefix + "Stripe", (0.5, 0.27, 0.05), (0, 0, 0.12), m=m["hazard"]),
    ]
    return place(parts, loc, rot_z)


def net(prefix, m, x0, x1, z0, z1, y, cols=5, rows=5, bulge=0.08):
    """Cargo net strung across a bay: a grid of straps bulging outward (-Y)."""
    parts = []
    for i in range(cols):
        x = x0 + (x1 - x0) * i / (cols - 1)
        pts = [(x, y - bulge * math.sin(math.pi * j / 6), z0 + (z1 - z0) * j / 6) for j in range(7)]
        parts.append(tube(f"{prefix}V{i}", pts, 0.014, m=m, segs=4))
    for j in range(rows):
        z = z0 + (z1 - z0) * j / (rows - 1)
        b = bulge * math.sin(math.pi * j / (rows - 1))
        pts = [(x0 + (x1 - x0) * i / 6, y - b * math.sin(math.pi * i / 6) - b * 0.3, z) for i in range(7)]
        parts.append(tube(f"{prefix}H{j}", pts, 0.014, m=m, segs=4))
    for i, (x, z) in enumerate(((x0, z0), (x1, z0), (x0, z1), (x1, z1))):
        parts.append(sphere(f"{prefix}Hook{i}", 0.035, (x, y, z), m=m, segs=6, rings=4))
    return parts


# ---------------------------------------------------------------------------
# The pod
# ---------------------------------------------------------------------------

def bay(m):
    """The lit cargo bay behind the front hatch: walls, shelves and their contents."""
    hw = BAY_W / 2
    y0, y1 = FRAME_Y - 0.15, BAY_BACK
    depth, mid = y1 - y0, (y0 + y1) / 2
    p = [
        box("BayBack", (BAY_W, 0.06, BAY_Z1 - BAY_Z0), (0, y1, (BAY_Z0 + BAY_Z1) / 2), bevel=0.0, m=m["bay"]),
        box("BayFloor", (BAY_W, depth, 0.06), (0, mid, BAY_Z0), bevel=0.0, m=m["sdark"]),
        box("BayRoof", (BAY_W, depth, 0.06), (0, mid, BAY_Z1), bevel=0.0, m=m["inside"]),
        box("BayWallL", (0.06, depth, BAY_Z1 - BAY_Z0), (-hw, mid, (BAY_Z0 + BAY_Z1) / 2), bevel=0.0, m=m["inside"]),
        box("BayWallR", (0.06, depth, BAY_Z1 - BAY_Z0), (hw, mid, (BAY_Z0 + BAY_Z1) / 2), bevel=0.0, m=m["inside"]),
        fbox("BayStrip", (BAY_W - 0.1, 0.06, 0.05), (0, mid, BAY_Z1 - 0.06), m=m["cell"]),
    ]
    sy = y1 - 0.3
    for k, z in enumerate((1.72, 2.36)):
        p.append(box(f"Shelf{k}", (BAY_W - 0.06, 0.6, 0.05), (0, sy, z), bevel=0.01, segs=1, m=m["steel"]))
        p.append(fbox(f"ShelfLip{k}", (BAY_W - 0.06, 0.03, 0.08), (0, sy - 0.3, z + 0.03), m=m["hazard"]))
    # Top shelf: a rack of energy cells.
    p.append(fbox("CellRail", (BAY_W - 0.2, 0.05, 0.05), (0, sy - 0.12, 2.6), m=m["sdark"]))
    for i in range(6):
        p += cell(f"BayCell{i}", m, (-0.72 + i * 0.288, sy, 2.39))
    # Middle shelf: med-kits (left) and ration pouches (right).
    p += medkit("BayMedA", m, (-0.66, sy - 0.04, 1.745), size=(0.46, 0.32, 0.32))
    p += medkit("BayMedB", m, (-0.18, sy - 0.04, 1.745), rot_z=math.radians(-6), size=(0.38, 0.28, 0.28))
    for i in range(3):
        p += place(ration(f"BayRation{i}", m, (0, 0, 0), rot_z=math.radians((i - 1) * 8)), (0.3 + i * 0.27, sy - 0.1 + (i % 2) * 0.06, 1.745), scale=1.2)
    # Floor: ammo cans and a small cell crate.
    p += ammo_can("BayAmmoA", m, (-0.55, sy - 0.05, BAY_Z0 + 0.03))
    p += ammo_can("BayAmmoB", m, (-0.02, sy - 0.02, BAY_Z0 + 0.03), rot_z=math.radians(8))
    p += [box("BayCrate", (0.6, 0.45, 0.42), (0.5, sy, BAY_Z0 + 0.24), bevel=0.03, segs=1, m=m["rust"])]
    p.append(bolt("BayCrateBolt", 0.13, (0.5, sy - 0.235, BAY_Z0 + 0.24), m["hazard"]))
    # A cargo net holding the left half in.
    p += net("BayNet", m["rubber"], -0.92, -0.05, BAY_Z0 + 0.06, 2.3, FRAME_Y + 0.05)
    return p


def frame(m, prefix, y):
    """Rust hatch frame with hazard-striped jambs, facing -Y at depth y."""
    hw = BAY_W / 2
    d = 0.6
    p = [
        box(prefix + "FrameT", (BAY_W + 0.44, d, 0.22), (0, y, BAY_Z1 + 0.11), bevel=0.06, m=m["rust"]),
        box(prefix + "FrameB", (BAY_W + 0.44, d, 0.22), (0, y, BAY_Z0 - 0.11), bevel=0.06, m=m["rust"]),
    ]
    for s in (-1, 1):
        p.append(box(f"{prefix}FrameS{s}", (0.22, d, BAY_Z1 - BAY_Z0 + 0.44), (s * (hw + 0.11), y, (BAY_Z0 + BAY_Z1) / 2), bevel=0.06, m=m["rust"]))
        # A hazard band lies along X: stand it upright on the jamb.
        band = hazard_band(f"{prefix}Jamb{s}", 1.6, 0.12, (0, 0, 0), 0.0, depth=0.03, stripe=0.18)
        p += xform(band, (s * (hw + 0.11), y - d / 2 - 0.02, (BAY_Z0 + BAY_Z1) / 2), (0, math.pi / 2, 0))
    return p


def door(m, prefix):
    """The hatch door, built around its bottom hinge at the origin, standing closed.
    Outer face -Y: hull white with a teal band, stencil and chevrons. Inner face +Y:
    ramp treads (it faces up once the door drops open)."""
    w, h, t = BAY_W + 0.34, DOOR_H, 0.12
    p = [
        box(prefix + "Panel", (w, t, h), (0, 0, h / 2), bevel=0.05, m=m["white"]),
        fbox(prefix + "Band", (w + 0.01, t + 0.01, 0.34), (0, 0, h * 0.62), m=m["teal"]),
        text(prefix + "Stencil", "SUPPLY", 0.3, 0.02, (0, -t / 2 - 0.012, h * 0.62 - 0.01), m=m["white"]),
        text(prefix + "Number", "09", 0.26, 0.02, (0.72, -t / 2 - 0.012, h * 0.86), m=m["navy"]),
        box(prefix + "Handle", (0.5, 0.08, 0.08), (0, -t / 2 - 0.05, h * 0.86), bevel=0.03, segs=1, m=m["sdark"]),
        cyl(prefix + "Knuckle", 0.07, w - 0.3, (0, 0, 0.0), rot=(0, math.pi / 2, 0), segs=10, bevel=0.0, m=m["sdark"]),
    ]
    p += hazard_band(prefix + "Chevrons", w - 0.1, 0.22, (0, -t / 2 - 0.01, 0.2), 0.0, depth=0.03, stripe=0.24)
    # Ramp face: grip treads and a hazard lip at the far end.
    for i in range(6):
        p.append(fbox(f"{prefix}Tread{i}", (w - 0.3, 0.03, 0.07), (0, t / 2 + 0.01, 0.3 + i * 0.26), m=m["hdark"]))
    p += place(hazard_band(prefix + "Lip", w - 0.1, 0.2, (0, 0, 0), 0.0, depth=0.03, stripe=0.24), (0, t / 2 + 0.02, h - 0.14), rot_z=math.pi)
    return p


def sealed_door(m, prefix):
    """The back hatch: same door, sealed flat over a frame (part of the pod mesh)."""
    p = door(m, prefix)
    return [ob for ob in p if "Tread" not in ob.name and "Lip" not in ob.name]


def build_pod(m):
    pod = []
    cutter = box("BayCutter", (BAY_W, 2.0, BAY_Z1 - BAY_Z0), (0, -2.4, (BAY_Z0 + BAY_Z1) / 2), bevel=0.0)
    cutter.hide_render = True
    # Hull: rounded heat shield, conical body, domed top. The bay is cut from the front.
    pod.append(lathe("HeatShield", [(0.0, 0.62), (1.4, 0.68), (2.25, 0.86), (POD_R + 0.08, 1.12), (POD_R + 0.05, 1.3)], m=m["shield"], segs=36))
    pod.append(cut(lathe("Body", [(POD_R, 1.3), (POD_R - 0.12, 2.2), (1.72, 4.3), (1.62, 4.5)], m=m["white"], segs=36), cutter))
    pod.append(lathe("Dome", [(1.62, 4.5), (1.5, 4.85), (1.15, 5.15), (0.6, 5.35), (0.0, 5.4)], m=m["teal"], segs=36))
    pod.append(cut(cyl("BandLow", POD_R + 0.04, 0.26, (0, 0, 1.42), segs=36, bevel=0.03, m=m["rust"]), cutter))
    pod.append(lathe("BandMid", [(2.18, 3.2), (2.03, 3.55)], m=m["rust"], segs=36))
    for ob in hazard_ring("Hazard", POD_R + 0.02, 1.68, 0.24, count=24):
        c = ob.matrix_world.translation
        if "Base" in ob.name:
            pod.append(cut(ob, cutter))
        elif not (abs(c.x) < BAY_W / 2 + 0.25 and c.y < 0):
            pod.append(ob)
    # Side panels with the stencil, and four retro thrusters.
    for s in (-1, 1):
        pod.append(box(f"SidePanel{s}", (0.2, 1.7, 1.1), (s * (POD_R - 0.2), 0, 2.45), rot=(0, s * math.radians(-12), 0), bevel=0.06, m=m["teal"]))
        pod.append(text(f"Stencil{s}", "SUPPLY", 0.34, 0.04, (s * (POD_R - 0.06), 0, 2.45), rot=(0, 0, math.radians(90 * s)), m=m["white"]))
        pod += place([bolt(f"SideBolt{s}", 0.16, (0, -0.06, 0), m["hazard"])], (s * (POD_R - 0.04), 0.0, 1.95), rot_z=math.radians(90 * s))
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        th = [box(f"Thruster{i}", (0.5, 0.5, 0.36), (POD_R - 0.05, 0, 1.95), bevel=0.06, m=m["sdark"]),
              cyl(f"ThrusterNozzle{i}", 0.12, 0.3, (POD_R + 0.2, 0, 1.75), rot=(0, math.radians(120), 0), segs=10, bevel=0.0, m=m["steel"], radius_top=0.2)]
        pod += place(th, rot_z=a)
    # Landing legs on the diagonals, each foot with an amber blinker.
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        leg = [beam(f"LegMain{i}", (1.9, 0, 1.9), (3.3, 0, 0.3), 0.24, m=m["sdark"]),
               beam(f"LegStrut{i}", (2.3, 0, 1.0), (3.0, 0, 0.55), 0.14, m=m["steel"]),
               cyl(f"LegPiston{i}", 0.14, 0.9, (2.55, 0, 1.3), rot=(0, math.radians(-50), 0), segs=10, bevel=0.02, m=m["rust"]),
               cyl(f"Foot{i}", 0.5, 0.18, (3.35, 0, 0.12), segs=16, bevel=0.05, m=m["sdark"]),
               fbox(f"FootStripe{i}", (0.98, 0.2, 0.05), (3.35, 0, 0.21), m=m["hazard"]),
               box(f"LegHinge{i}", (0.4, 0.4, 0.4), (1.95, 0, 1.9), bevel=0.06, m=m["rust"]),
               bulb(f"FootBlink{i}", 0.07, (3.35, 0, 0.3), m["amber"])]
        pod += place(leg, rot_z=a)
    # Front: frame round the cut, the lit bay and a holo screen beside it.
    pod += frame(m, "Front", FRAME_Y)
    pod += bay(m)
    for s in (-1, 1):
        pod.append(cyl(f"LampHousing{s}", 0.12, 0.12, (s * (BAY_W / 2 + 0.11), FRAME_Y - 0.11, BAY_Z1 + 0.34), rot=(math.pi / 2, 0, 0),
                       segs=10, bevel=0.02, m=m["sdark"]))
    scr = [
        box("ScreenBox", (0.78, 0.14, 0.58), (0, 0, 0), bevel=0.04, m=m["sdark"]),
        fbox("ScreenFace", (0.66, 0.04, 0.46), (0, -0.07, 0), m=m["screen"]),
        bolt("ScreenBolt", 0.11, (-0.18, -0.1, 0.02), m["hazard"]),
        fbox("ScreenBarA", (0.3, 0.02, 0.05), (0.14, -0.095, 0.1), m=m["white"]),
        fbox("ScreenBarB", (0.22, 0.02, 0.05), (0.1, -0.095, 0.0), m=m["white"]),
        fbox("ScreenBarC", (0.26, 0.02, 0.05), (0.12, -0.095, -0.1), m=m["white"]),
        box("ScreenArm", (0.1, 0.3, 0.1), (0, 0.2, 0), bevel=0.02, segs=1, m=m["sdark"]),
    ]
    pod += place(scr, (1.62, -1.86, 2.3), rot_z=math.radians(-28))
    # Back: a sealed hatch over a frame.
    back = frame(m, "Back", FRAME_Y + 0.02)
    back += xform(sealed_door(m, "BackDoor"), (0, HINGE[1], HINGE[2]))
    pod += place(back, rot_z=math.pi)
    # Top: antenna, small dish, chute ring and a beacon.
    pod.append(torus("ChuteRing", 0.45, 0.07, (0, 0, 5.42), m=m["steel"], major_segs=16, minor_segs=6))
    pod.append(cyl("Antenna", 0.04, 1.6, (0.7, 0.4, 5.8), segs=6, bevel=0.0, m=m["steel"]))
    pod.append(bulb("AntennaLight", 0.12, (0.7, 0.4, 6.65), m["amber"]))
    pod.append(lathe("MiniDish", [(0.0, 0.0), (0.25, 0.03), (0.45, 0.11)], m=m["white"], segs=16, loc=(-0.75, 0.3, 5.2),
                     rot=(math.radians(40), 0, 0)))
    pod.append(text("PodNumber", "09", 0.42, 0.04, (0, -1.73, 4.0), rot=(math.radians(-25), 0, 0), m=m["navy"]))
    return pod


def build_hatch(m):
    ob = merge("Hatch", door(m, "Door"))
    ob.location = HINGE
    return ob


def build_lamps(m, name, colour):
    glow = dglow(name + "Glow", colour, 1.6)
    p = []
    for s in (-1, 1):
        p.append(bulb(f"{name}{s}", 0.1, (s * (BAY_W / 2 + 0.11), FRAME_Y - 0.2, BAY_Z1 + 0.34), glow))
    if name == "OpenLamps":
        # Holo banner across the top of the open bay.
        holo = m["screen"]
        p += [
            fbox("BannerBar", (1.5, 0.03, 0.2), (0, FRAME_Y - 0.32, BAY_Z1 + 0.3), m=m["navy"]),
            text("BannerText", "OPEN", 0.17, 0.02, (0, FRAME_Y - 0.35, BAY_Z1 + 0.29), m=holo),
        ]
    return merge(name, p)


def build_chute(m):
    """Parachute parts: a deflated canopy with alternating gores, draped behind the pod."""
    orange, cream = dmat("ChuteOrange", "#ff6a1f", rough=0.75), dmat("ChuteCream", "#f6ead2", rough=0.75)
    cx, cy = 3.9, 4.6
    canopy = lathe("Canopy", [(0.0, 1.0), (1.2, 0.93), (2.2, 0.72), (2.9, 0.42), (3.25, 0.12), (3.3, 0.0)], m=orange, segs=40)
    canopy.data.materials.append(cream)
    for poly in canopy.data.polygons:
        c = poly.center
        poly.material_index = int(((math.atan2(c.y, c.x) + math.pi) / math.tau) * 12) % 2
    canopy.scale = (1.15, 0.85, 0.42)
    canopy.rotation_euler = (math.radians(6), math.radians(-4), 0.5)
    canopy.location = (cx, cy, 0.0)
    chute = [canopy]
    for i in range(5):
        a = 0.5 + math.tau * i / 5
        chute.append(sphere(f"Wrinkle{i}", 0.7, (cx + math.cos(a) * 2.6, cy + math.sin(a) * 2.0, 0.18), scale=(1.4, 0.6, 0.3),
                            rot=(0, 0, a), m=orange if i % 2 else cream, segs=10, rings=6))
    for i in range(4):
        a0 = math.tau * i / 4 + 0.9
        chute.append(tube(f"Cord{i}", [(0.3, 0.2, 5.35), (1.4, 1.6, 3.0), (cx + math.cos(a0) * 2.4 - 0.4, cy + math.sin(a0) * 1.8 - 0.4, 0.2)],
                          0.025, m=m["sdark"], segs=5))
    return chute


def cell_rack(m):
    """Charging rack of energy cells, facing -Y, origin at its base centre."""
    p = [
        box("RackBase", (1.2, 0.6, 0.14), (0, 0, 0.07), bevel=0.03, segs=1, m=m["sdark"]),
        fbox("RackBaseStripe", (1.21, 0.61, 0.05), (0, 0, 0.1), m=m["hazard"]),
        box("RackTop", (1.2, 0.5, 0.1), (0, 0.02, 1.32), bevel=0.03, segs=1, m=m["teal"]),
        fbox("RackShelf", (1.12, 0.5, 0.05), (0, 0.02, 0.7), m=m["steel"]),
        box("RackLabel", (0.6, 0.04, 0.16), (0, -0.25, 1.32), bevel=0.0, m=m["navy"]),
        text("RackLabelText", "CELLS", 0.11, 0.015, (0, -0.28, 1.315), m=m["cell"]),
    ]
    for s in (-1, 1):
        p.append(box(f"RackPost{s}", (0.1, 0.5, 1.3), (s * 0.58, 0.02, 0.7), bevel=0.02, segs=1, m=m["teal"]))
    for row, z in enumerate((0.14, 0.75)):
        for i in range(4):
            p += cell(f"RackCell{row}{i}", m, (-0.39 + i * 0.26, 0.0, z), h=0.44, r=0.09)
    return p


def crate_stack(m):
    """Netted crate stack facing -Y, origin at its base centre."""
    p = [
        box("StackA", (1.1, 0.85, 0.7), (0, 0, 0.35), bevel=0.04, m=m["teal"]),
        fbox("StackABand", (1.12, 0.87, 0.08), (0, 0, 0.6), m=m["tdark"]),
        text("StackAText", "RATIONS", 0.14, 0.015, (0, -0.435, 0.36), m=m["white"]),
        box("StackB", (0.8, 0.7, 0.55), (0.08, 0.04, 0.975), rot=(0, 0, math.radians(9)), bevel=0.04, m=m["rust"]),
        box("StackC", (0.6, 0.6, 0.5), (0.95, -0.1, 0.25), rot=(0, 0, math.radians(-14)), bevel=0.04, m=m["white"]),
    ]
    p += place([bolt("StackBBolt", 0.12, (0, 0, 0), m["hazard"])], (0.08 + 0.06, 0.04 - 0.36, 0.98), rot_z=math.radians(9))
    p += place(cross("StackCCross", 0.22, (0, -0.31, 0.27), m["teal"]), (0.95, -0.1, 0), rot_z=math.radians(-14))
    p += place([prism("StackArrow", [(-0.08, 0.0), (0.08, 0.0), (0.08, 0.12), (0.16, 0.12), (0.0, 0.26), (-0.16, 0.12), (-0.08, 0.12)],
                      0.02, (0.38, -0.44, 0.1), m=m["navy"])])
    # Net over the top crate: straps across the top and down the front and sides.
    top = 1.255
    for i in range(5):
        t = -0.36 + i * 0.18
        p.append(tube(f"NetX{i}", [(t + 0.08, -0.4, 0.72), (t + 0.08, -0.34, top), (t + 0.08, 0.42, top), (t + 0.08, 0.46, 0.72)], 0.013, m=m["rubber"], segs=4))
        p.append(tube(f"NetY{i}", [(-0.44, t * 0.9 + 0.04, 0.72), (-0.36, t * 0.9 + 0.04, top), (0.52, t * 0.9 + 0.04, top), (0.58, t * 0.9 + 0.04, 0.72)], 0.013, m=m["rubber"], segs=4))
    return p


def holo_terminal(m):
    """A standing holo terminal on a pedestal, screen tilted toward -Y."""
    holo = m["screen"]
    p = [
        cyl("TermFoot", 0.32, 0.1, (0, 0, 0.05), segs=12, bevel=0.03, m=m["sdark"]),
        cyl("TermPost", 0.09, 1.0, (0, 0, 0.6), segs=10, bevel=0.0, m=m["steel"]),
        fbox("TermStripe", (0.2, 0.2, 0.06), (0, 0, 0.4), m=m["hazard"]),
    ]
    scr = [
        box("TermBox", (1.0, 0.1, 0.66), (0, 0, 0), bevel=0.04, m=m["sdark"]),
        fbox("TermFace", (0.88, 0.04, 0.54), (0, -0.05, 0), m=holo),
        bolt("TermBolt", 0.12, (-0.3, -0.08, 0.05), m["hazard"]),
        fbox("TermCrossH", (0.18, 0.02, 0.06), (0.0, -0.08, 0.06), m=m["white"]),
        fbox("TermCrossV", (0.06, 0.02, 0.18), (0.0, -0.08, 0.06), m=m["white"]),
        prism("TermArrow", [(-0.12, -0.03), (0.04, -0.03), (0.04, -0.09), (0.14, 0.0), (0.04, 0.09), (0.04, 0.03), (-0.12, 0.03)],
              0.02, (0.28, -0.08, 0.06), m=m["white"]),
        fbox("TermBar", (0.7, 0.02, 0.05), (0, -0.08, -0.17), m=m["cell"]),
    ]
    p += xform(scr, (0, 0, 1.3), (math.radians(-22), 0, 0))
    # Projector cone of light above the screen.
    p.append(cyl("TermBeam", 0.05, 0.3, (0, -0.1, 1.78), segs=8, bevel=0.0, m=holo, radius_top=0.2))
    return p


def ration_pallet(m):
    """A pallet of ration pouches with an open med case on top, facing -Y."""
    p = [box("Pallet", (1.1, 0.85, 0.12), (0, 0, 0.06), bevel=0.02, segs=1, m=m["rdark"])]
    for i in range(3):
        p.append(fbox(f"PalletSlat{i}", (1.12, 0.12, 0.02), (0, -0.3 + i * 0.3, 0.125), m=m["sdark"]))
    for i in range(5):
        p += ration(f"PalletRation{i}", m, (-0.42 + i * 0.2, -0.22 + (i % 2) * 0.05, 0.13), rot_z=math.radians((i - 2) * 9))
    p += medkit("PalletMed", m, (0.15, 0.22, 0.13), rot_z=math.radians(12), size=(0.5, 0.34, 0.3))
    p += medkit("PalletMedSmall", m, (-0.3, 0.2, 0.13), rot_z=math.radians(-20), size=(0.34, 0.26, 0.24))
    return p


def build_ground(m):
    """Parts for the blast mark, scorch streaks, sand rim and the unloaded cargo around the pod."""
    rim = torus("Rim", 4.9, 0.7, (0, 0, -0.05), m=m["sand"], major_segs=40, minor_segs=8)
    rim.scale = (1.0, 1.0, 0.32)
    g = [disc("ScorchOuter", 4.4, m=dmat("Scorch", "#8a6450", rough=1.0), inner=3.0, thickness=0.015),
         disc("ScorchInner", 3.0, m=dmat("ScorchDark", "#5a4038", rough=1.0), thickness=0.02), rim]
    rng = random.Random(7)
    for i in range(14):
        a = math.tau * i / 14 + rng.uniform(-0.1, 0.1)
        ln = rng.uniform(1.0, 1.7)
        r0 = 3.0 + ln / 2
        streak = prism(f"Streak{i}", [(-0.12, -ln / 2), (0.12, -ln / 2), (0.02, ln / 2), (-0.02, ln / 2)], 0.01, (0, 0, 0),
                       m=dmat("ScorchDark", "#5a4038", rough=1.0))
        streak.rotation_euler = (math.pi / 2, 0, a - math.pi / 2)
        streak.location = (math.cos(a) * r0, math.sin(a) * r0, 0.025)
        g.append(streak)
    for i in range(6):
        a = math.tau * i / 6 + 0.4
        g.append(sphere(f"Mound{i}", 1.0, (math.cos(a) * 5.4, math.sin(a) * 5.4, -0.05), scale=(1.6, 0.9, 0.3),
                        rot=(0, 0, a + math.pi / 2), m=m["sand"], segs=10, rings=6))
    g += place(cell_rack(m), (3.45, -0.55, 0.0), rot_z=math.radians(75))
    g.append(tube("RackCable", [(3.0, -0.75, 0.15), (2.75, -0.95, 0.05), (2.55, -1.1, 0.3), (2.3, -1.2, 1.15)], 0.04, m=m["rubber"], segs=6))
    g += place(crate_stack(m), (-3.35, 0.15, 0.0), rot_z=math.radians(-80))
    g += place(holo_terminal(m), (-1.85, -3.35, 0.0), rot_z=math.radians(-25))
    g += place(ration_pallet(m), (1.85, -3.5, 0.0), rot_z=math.radians(25))
    return g


def build():
    reset_scene()
    m = mats()
    static = merge("Pod", build_pod(m) + build_chute(m) + build_ground(m))
    save("dune_station", [static, build_hatch(m), build_lamps(m, "OpenLamps", "#5cff8a"), build_lamps(m, "ClosedLamps", "#ff4a3a")])


if __name__ == "__main__":
    build()
