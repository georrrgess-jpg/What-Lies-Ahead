"""The Neon Skyline loadout station: HYPERVEND, a cross of four glowing vending
machines around a central mast, a ring canopy with LED underglow and a
spinning holographic energy cell on top. About 5.6 m tall, radius ~2.6 m.

Exports: Station (static body art) and SpinHolo (the hologram, which the
level turns slowly; its NeonHolo* materials become the hologram shader).
Front faces -Y (Godot +Z).

    python art/blender/build_neon_station.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from neon_common import *  # noqa: F401,F403

MACHINES = [
    # (heading degrees, body colour, glow colour, header label)
    (0, "#ff2fae", "#ff6ad0", "AMMO"),
    (90, "#2ef2ff", "#7af8ff", "SWAP"),
    (180, "#9a5bff", "#c49bff", "CELLS"),
    (270, "#ffb43a", "#ffd27a", "HEAL"),
]


def vending_machine(prefix, body_hex, glow_hex, label, dark, steel, ink):
    """One machine facing -Y, back against the mast. Origin at its back centre."""
    body = nmat(prefix + "Body", body_hex, rough=0.4, metal=0.2)
    glow = neon_glow(prefix + "Glow", glow_hex, 2.6)
    window = nmat(prefix + "Window", "#1a1a33", rough=0.05, metal=0.3, emit=0.0)
    y = -0.5
    parts = [
        box(prefix + "Shell", (1.5, 1.0, 2.55), (0, y, 1.58), bevel=0.08, segs=2, m=body),
        box(prefix + "Face", (1.32, 0.06, 2.3), (0, y - 0.5, 1.58), bevel=0.02, m=dark),
        box(prefix + "Window", (0.86, 0.04, 1.5), (-0.17, y - 0.535, 1.86), bevel=0.02, m=window),
        box(prefix + "Header", (1.4, 0.12, 0.34), (0, y - 0.52, 2.98), bevel=0.04, m=ink),
        sign_text(prefix + "Label", label, 0.24, 0.03, (0, y - 0.6, 2.98), m=glow),
        box(prefix + "Keypad", (0.3, 0.05, 0.62), (0.5, y - 0.545, 1.95), bevel=0.02, m=steel),
        box(prefix + "Screen", (0.24, 0.03, 0.16), (0.5, y - 0.575, 2.15), bevel=0.0, m=glow),
        box(prefix + "Slot", (0.86, 0.08, 0.26), (-0.17, y - 0.54, 0.75), bevel=0.03, m=ink),
        box(prefix + "SlotGlow", (0.7, 0.02, 0.05), (-0.17, y - 0.585, 0.86), bevel=0.0, m=glow),
        box(prefix + "Kick", (1.5, 1.0, 0.12), (0, y, 0.36), bevel=0.03, m=dark),
        box(prefix + "SideStripL", (0.04, 0.9, 2.2), (-0.77, y, 1.6), bevel=0.0, m=glow),
        box(prefix + "SideStripR", (0.04, 0.9, 2.2), (0.77, y, 1.6), bevel=0.0, m=glow),
    ]
    # Product rows behind the window: little glowing cans and cells.
    for r in range(4):
        z = 1.3 + r * 0.36
        parts.append(box(f"{prefix}Shelf{r}", (0.84, 0.25, 0.02), (-0.17, y - 0.38, z - 0.12), bevel=0.0, m=steel))
        for k in range(5):
            x = -0.53 + k * 0.18
            hexc = [glow_hex, "#ffffff", "#ffd23a", glow_hex, "#3af0ff"][(k + r) % 5]
            parts.append(cyl(f"{prefix}Item{r}{k}", 0.05, 0.17, (x, y - 0.42, z), segs=8, bevel=0.01,
                             m=neon_glow(f"Item{hexc.lstrip('#')}", hexc, 1.6)))
    return parts


def build():
    reset_scene()
    dark = nmat("StationDark", "#1d1a2e", rough=0.45, metal=0.4)
    steel = nmat("StationSteel", "#7a7e9c", rough=0.3, metal=0.7)
    ink = nmat("StationInk", "#120f1e", rough=0.5)
    cyan = neon_glow("StationCyan", "#2ef2ff", 3.2)
    pink = neon_glow("StationPink", "#ff2fae", 3.2)
    parts = [
        cyl("Plinth", 2.15, 0.22, (0, 0, 0.11), segs=8, bevel=0.05, m=dark),
        cyl("PlinthLed", 2.18, 0.05, (0, 0, 0.19), segs=8, bevel=0.0, m=cyan),
        box("Core", (1.3, 1.3, 3.6), (0, 0, 2.0), bevel=0.06, m=dark),
        cyl("Mast", 0.32, 1.4, (0, 0, 4.4), segs=12, bevel=0.03, m=steel),
        # Ring canopy with an LED underglow and bulbs round the rim.
        cyl("Canopy", 2.75, 0.22, (0, 0, 3.85), segs=32, bevel=0.06, m=dark),
        cyl("CanopyTop", 2.45, 0.16, (0, 0, 4.02), segs=32, bevel=0.05, m=steel, radius_top=1.2),
        torus("CanopyLed", 2.6, 0.05, (0, 0, 3.73), m=pink, major_segs=48, minor_segs=6),
        torus("CanopyLed2", 2.2, 0.035, (0, 0, 3.73), m=cyan, major_segs=40, minor_segs=5),
        # Projector dish on the mast.
        cyl("Projector", 0.7, 0.25, (0, 0, 5.15), segs=20, bevel=0.06, m=steel, radius_top=0.45),
        cyl("Lens", 0.32, 0.08, (0, 0, 5.3), segs=16, bevel=0.02, m=cyan),
    ]
    for i in range(24):
        a = math.tau * i / 24
        parts.append(neon_bulb(f"Rim{i:02d}", 0.07, (math.cos(a) * 2.78, math.sin(a) * 2.78, 3.8),
                               "#ffd27a" if i % 2 else "#ff6ad0", 3.0))
    # Struts from the core to the canopy.
    for i in range(4):
        a = math.tau * (i + 0.5) / 4
        parts.append(tube(f"Strut{i}", [(math.cos(a) * 0.9, math.sin(a) * 0.9, 3.3), (math.cos(a) * 2.2, math.sin(a) * 2.2, 3.75)],
                          0.06, m=steel, segs=6))
    # The four machines, each facing outward.
    for heading, body_hex, glow_hex, label in MACHINES:
        machine = vending_machine(f"M{heading}_", body_hex, glow_hex, label, dark, steel, ink)
        # Scale up a touch and push out from the core along the machine's facing.
        a = math.radians(heading)
        place(machine, (math.sin(a) * 0.38, -math.cos(a) * 0.38, 0.12), rot_z=a, scale=1.1)
        parts += machine
    # Brand ring on the canopy edge, front and back.
    for k, a in enumerate((0.0, math.pi)):
        sign = [box(f"BrandPlate{k}", (2.2, 0.1, 0.36), (0, -2.82, 4.12), bevel=0.04, m=ink),
                sign_text(f"Brand{k}", "HYPERVEND", 0.26, 0.03, (0, -2.88, 4.12), m=cyan)]
        place(sign, rot_z=a)
        parts += sign
    station = merge("Station", parts)

    # Hologram: an energy cell with orbit rings, above the projector.
    holo = mat("NeonHoloCell", "#2ef2ff", rough=1.0)
    holo2 = mat("NeonHoloBolt", "#ff6ad0", rough=1.0)
    cell = [
        cyl("CellBody", 0.42, 1.1, (0, 0, 6.25), segs=16, bevel=0.12, m=holo),
        cyl("CellCap", 0.22, 0.18, (0, 0, 6.9), segs=12, bevel=0.04, m=holo),
        torus("OrbitA", 0.85, 0.03, (0, 0, 6.25), rot=(math.radians(70), 0, 0), m=holo2, major_segs=36, minor_segs=4),
        torus("OrbitB", 0.85, 0.03, (0, 0, 6.25), rot=(math.radians(70), 0, math.radians(90)), m=holo2, major_segs=36, minor_segs=4),
        prism("Bolt", [(-0.06, 0.32), (-0.2, 0.0), (-0.02, 0.0), (-0.1, -0.34), (0.16, 0.08), (0.0, 0.08), (0.08, 0.32)], 0.05,
              (0, -0.44, 6.25), m=holo2),
        cyl("Beam", 0.55, 0.9, (0, 0, 5.65), segs=16, bevel=0.0, m=holo, radius_top=0.15),
    ]
    spin = merge("SpinHolo", cell, pivot=(0, 0, 6.25))
    save("neon_station", [station, spin])


if __name__ == "__main__":
    build()
