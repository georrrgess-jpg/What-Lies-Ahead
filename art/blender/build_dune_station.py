"""The Dune Spaceport loadout station: a supply drop pod that came down on the apron.

    dune_station.glb   Nodes: Pod (capsule on four landing legs, two open supply hatches
                       with glowing energy cells and med packs), Chute (the deflated
                       parachute draped behind it), Scorch (blast mark under the pod).

About 5.6 m tall, 7 m across the legs. Front (-Y, Godot +Z) and back hatches.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dune_kit import *  # noqa: F401,F403

POD_R = 2.45


def _hatch(prefix, m):
    """One open supply hatch at the front (-Y): frame, dark recess, shelves, folded-down door."""
    p = []
    y = -POD_R + 0.25
    p.append(box(prefix + "Recess", (2.0, 0.5, 1.7), (0, y + 0.05, 2.05), bevel=0.08, m=m["inside"]))
    p.append(box(prefix + "FrameT", (2.4, 0.4, 0.22), (0, y - 0.12, 2.98), bevel=0.06, m=m["rust"]))
    p.append(box(prefix + "FrameB", (2.4, 0.4, 0.22), (0, y - 0.12, 1.12), bevel=0.06, m=m["rust"]))
    for s in (-1, 1):
        p.append(box(f"{prefix}FrameS{s}", (0.22, 0.4, 2.05), (s * 1.1, y - 0.12, 2.05), bevel=0.06, m=m["rust"]))
    # Two shelves: energy cells (top) and med packs (bottom).
    for k, z in enumerate((1.55, 2.3)):
        p.append(fbox(f"{prefix}Shelf{k}", (1.9, 0.5, 0.06), (0, y - 0.05, z), m=m["steel"]))
    for i in range(5):
        x = -0.72 + i * 0.36
        p.append(cyl(f"{prefix}Cell{i}", 0.11, 0.42, (x, y - 0.1, 2.55), segs=10, bevel=0.03, m=m["cell"]))
        p.append(cyl(f"{prefix}CellCap{i}", 0.12, 0.08, (x, y - 0.1, 2.78), segs=10, bevel=0.02, m=m["steel"]))
    for i in range(3):
        x = -0.6 + i * 0.6
        p.append(box(f"{prefix}Med{i}", (0.42, 0.3, 0.3), (x, y - 0.1, 1.74), bevel=0.05, m=m["teal"]))
        p.append(fbox(f"{prefix}MedH{i}", (0.24, 0.04, 0.07), (x, y - 0.26, 1.74), m=m["white"]))
        p.append(fbox(f"{prefix}MedV{i}", (0.07, 0.04, 0.24), (x, y - 0.26, 1.74), m=m["white"]))
    # The door folded down into a counter.
    door = box(prefix + "Door", (2.2, 0.16, 1.1), (0, 0, 0), bevel=0.05, m=m["white"])
    door.rotation_euler = (math.radians(-80), 0, 0)
    door.location = (0, y - 0.62, 1.12)
    p.append(door)
    p += hazard_band(prefix + "DoorStripe", 2.0, 0.22, (0, y - 1.12, 1.03), 0.0, depth=0.03, stripe=0.3)
    for s in (-1, 1):
        p.append(rod(f"{prefix}Strap{s}", (s * 0.95, y - 1.15, 1.06), (s * 1.0, y - 0.15, 1.75), 0.025, m=m["steel"]))
    # A little holo screen beside the hatch.
    p.append(box(prefix + "Screen", (0.6, 0.12, 0.45), (1.55, y + 0.12, 2.3), rot=(0, 0, math.radians(-18)), bevel=0.04, m=m["sdark"]))
    p.append(fbox(prefix + "ScreenGlow", (0.48, 0.06, 0.33), (1.53, y + 0.04, 2.3), rot=(0, 0, math.radians(-18)), m=m["screen"]))
    return p


def build():
    reset_scene()
    m = dict(
        white=dmat("Hull", rough=0.45), shade=dmat("HullShade", rough=0.5),
        teal=dmat("Teal", rough=0.45), tdark=dmat("TealDark", rough=0.5),
        rust=dmat("Rust", rough=0.55), rdark=dmat("RustDark", rough=0.6),
        steel=dmat("Steel", rough=0.4, metal=0.5), sdark=dmat("SteelDark", rough=0.45, metal=0.4),
        inside=dmat("Interior", rough=1.0), shield=dmat("HeatShield", "#5a3a30", rough=0.8),
        cell=dglow("CellGlow", "#5cf2ff", 2.2), screen=dglow("ScreenGlow", "#7cf6d8", 1.8),
        amber=dglow("LiftAmber", "#ffa12a", 3.0), navy=dmat("Navy", rough=0.5),
    )
    pod = []
    # Hull: rounded heat shield, conical body, domed top.
    pod.append(lathe("HeatShield", [(0.0, 0.62), (1.4, 0.68), (2.25, 0.86), (POD_R + 0.08, 1.12), (POD_R + 0.05, 1.3)], m=m["shield"], segs=36))
    pod.append(lathe("Body", [(POD_R, 1.3), (POD_R - 0.12, 2.2), (1.72, 4.3), (1.62, 4.5)], m=m["white"], segs=36))
    pod.append(lathe("Dome", [(1.62, 4.5), (1.5, 4.85), (1.15, 5.15), (0.6, 5.35), (0.0, 5.4)], m=m["teal"], segs=36))
    pod.append(cyl("BandLow", POD_R + 0.04, 0.26, (0, 0, 1.42), segs=36, bevel=0.03, m=m["rust"]))
    pod.append(lathe("BandMid", [(2.18, 3.2), (2.03, 3.55)], m=m["rust"], segs=36))
    pod += hazard_ring("Hazard", POD_R + 0.02, 1.68, 0.24, count=24)
    # Side panels with the stencil, and four retro thrusters.
    for s in (-1, 1):
        panel = [box(f"SidePanel{s}", (0.2, 1.7, 1.1), (s * (POD_R - 0.2), 0, 2.45), rot=(0, s * math.radians(-12), 0), bevel=0.06, m=m["teal"])]
        pod += panel
        pod.append(text(f"Stencil{s}", "SUPPLY", 0.34, 0.04, (s * (POD_R - 0.06), 0, 2.45),
                        rot=(0, 0, math.radians(90 * s)), m=m["white"]))
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        th = [box(f"Thruster{i}", (0.5, 0.5, 0.36), (POD_R - 0.05, 0, 1.95), bevel=0.06, m=m["sdark"]),
              cyl(f"ThrusterNozzle{i}", 0.12, 0.3, (POD_R + 0.2, 0, 1.75), rot=(0, math.radians(120), 0), segs=10, bevel=0.0, m=m["steel"], radius_top=0.2)]
        pod += place(th, rot_z=a)
    # Landing legs on the diagonals, between the hatches.
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        leg = [beam(f"LegMain{i}", (1.9, 0, 1.9), (3.3, 0, 0.3), 0.24, m=m["sdark"]),
               beam(f"LegStrut{i}", (2.3, 0, 1.0), (3.0, 0, 0.55), 0.14, m=m["steel"]),
               cyl(f"LegPiston{i}", 0.14, 0.9, (2.55, 0, 1.3), rot=(0, math.radians(-50), 0), segs=10, bevel=0.02, m=m["rust"]),
               cyl(f"Foot{i}", 0.5, 0.18, (3.35, 0, 0.12), segs=16, bevel=0.05, m=m["sdark"]),
               box(f"LegHinge{i}", (0.4, 0.4, 0.4), (1.95, 0, 1.9), bevel=0.06, m=m["rust"])]
        pod += place(leg, rot_z=a)
    # Hatches front and back.
    pod += _hatch("Front", m)
    pod += place(_hatch("Back", m), rot_z=math.pi)
    # Top: antenna, small dish, chute ring and a beacon.
    pod.append(torus("ChuteRing", 0.45, 0.07, (0, 0, 5.42), m=m["steel"], major_segs=16, minor_segs=6))
    pod.append(cyl("Antenna", 0.04, 1.6, (0.7, 0.4, 5.8), segs=6, bevel=0.0, m=m["steel"]))
    pod.append(bulb("AntennaLight", 0.12, (0.7, 0.4, 6.65), m["amber"]))
    pod.append(lathe("MiniDish", [(0.0, 0.0), (0.25, 0.03), (0.45, 0.11)], m=m["white"], segs=16, loc=(-0.75, 0.3, 5.2),
                     rot=(math.radians(40), 0, 0)))
    pod.append(text("PodNumber", "09", 0.42, 0.04, (0, -1.73, 4.0), rot=(math.radians(-25), 0, 0), m=m["navy"]))
    pod_ob = merge("Pod", pod)

    # Parachute: a deflated canopy with alternating gores, draped behind the pod.
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
                          0.025, m=m["shade"], segs=5))
    chute_ob = merge("Chute", chute)

    sand = dmat("Sand", rough=0.95)
    rim = torus("Rim", 4.9, 0.7, (0, 0, -0.05), m=sand, major_segs=40, minor_segs=8)
    rim.scale = (1.0, 1.0, 0.32)
    scorch = [disc("ScorchOuter", 4.4, m=dmat("Scorch", "#8a6450", rough=1.0), inner=3.0, thickness=0.015),
              disc("ScorchInner", 3.0, m=dmat("ScorchDark", "#5a4038", rough=1.0), thickness=0.02), rim]
    for i in range(6):
        a = math.tau * i / 6 + 0.4
        scorch.append(sphere(f"Mound{i}", 1.0, (math.cos(a) * 5.4, math.sin(a) * 5.4, -0.05), scale=(1.6, 0.9, 0.3),
                             rot=(0, 0, a + math.pi / 2), m=sand, segs=10, rings=6))
    scorch_ob = merge("Scorch", scorch)
    save("dune_station", [pod_ob, chute_ob, scorch_ob])


if __name__ == "__main__":
    build()
