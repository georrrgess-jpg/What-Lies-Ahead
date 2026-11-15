"""First-person viewmodel of the Lava Lampoon (lava_lampoon), the Volcano Isle
primary: a chunky magma-orange blaster with a big retro lava lamp standing on
its back like a smokestack.

Same conventions and node contract as build_weapons.py (documented at the top
of weapon_kit.py): origin at the top of the grip, pointing along +Y, its own
palette (set before weapon_mats, so the shared material names stay and every
finish, cell, decal and charm works), built-in sights on a raised tiki bridge
so the lamp stays under the eye line. Moving parts, driven by
scripts/weapons/views/lava_lampoon_view.gd and
scripts/weapons/reloads/lava_lampoon_reload.gd:

  Lamp        the lamp (pivot at the bottom of its screw collar, on the lamp's
              axis), which unscrews, lifts out and flips during the reload >
              LampGlass  the tapered glass (material "LampGlass": the game
                         draws the wax blobs in it with a shader, whose
                         GLASS_* constants follow LAMP_PROFILE below)
              LampWax    a few wax blobs on the glass, for the static model
                         (Arsenal stand, previews); hidden in first person
              LampCap    the gold pointed cap (pivot at its rim), pops off
  LampRingHolo  the teal hologram ring the lamp rides out on (hidden at rest)
  Cell        the glowing heater coil in the lamp's socket
  CellHolo    its hologram copy (shown while the lamp is out)
  Pip0..9     the holographic ammo display on the left flank: one lamp icon
              per three rounds

    python art/blender/build_weapons_lava_lampoon.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapon_kit import *  # noqa: F401,F403
from weapon_kit import _finish_part  # noqa: E402

PIPS = 10
## Lamp axis on the receiver (x, y) and the heights of its parts (z, Blender).
LAMP_X = -0.042
LAMP_Y = -0.03
SOCKET_Z = 0.0775
COLLAR_Z = 0.103
GLASS_Z = 0.112
## The glass: (height above GLASS_Z, radius). Mirrored in lava_lampoon_lamp.gdshader.
LAMP_PROFILE = [(0.0, 0.024), (0.012, 0.03), (0.03, 0.032), (0.05, 0.028), (0.07, 0.021), (0.088, 0.0155)]
CAP_Z = GLASS_Z + 0.087
RAIL_TOP = 0.232


def palette():
    """The shared weapon materials in this weapon's colours (weapon_mats reuses them)."""
    mat("Shell", "#ff6a1f", rough=0.32)
    mat("Trim", "#1fc8b8", rough=0.36)
    mat("GunDark", "#2a2238", rough=0.55, metal=0.15)
    mat("GunSteel", "#f7c04a", rough=0.3, metal=0.5)
    mat("GunPink", "#ff2e88", rough=0.36)


def lathe(name, profile, centre, m, segs=24, smooth=True):
    """Surface of revolution about +Z through `centre`: profile [(z, radius), ...], capped."""
    bm = bmesh.new()
    rings = []
    cx, cy, cz = centre
    for z, r in profile:
        rings.append([bm.verts.new((cx + math.cos(math.tau * i / segs) * r, cy + math.sin(math.tau * i / segs) * r, cz + z)) for i in range(segs)])
    for i in range(len(rings) - 1):
        for j in range(segs):
            bm.faces.new((rings[i][j], rings[i][(j + 1) % segs], rings[i + 1][(j + 1) % segs], rings[i + 1][j]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish_part(name, bm, m, smooth)


def glass_radius(h):
    for (h0, r0), (h1, r1) in zip(LAMP_PROFILE, LAMP_PROFILE[1:]):
        if h <= h1:
            return r0 + (r1 - r0) * (h - h0) / (h1 - h0)
    return LAMP_PROFILE[-1][1]


def tiki_post(prefix, y, M, eye):
    """A little teal tiki totem holding the sight bridge up: carved bands and two glowing eyes."""
    h = RAIL_TOP - 0.02 - SOCKET_Z
    zc = SOCKET_Z + h / 2
    parts = [
        box(prefix + "Body", (0.024, 0.018, h), (0, y, zc), bevel=0.006, m=M["trim"]),
        box(prefix + "Brow", (0.028, 0.022, 0.007), (0, y, zc + h * 0.22), bevel=0.003, m=M["dark"]),
        box(prefix + "Mouth", (0.016, 0.022, 0.005), (0, y, zc - h * 0.18), bevel=0.002, m=M["dark"]),
        box(prefix + "Band", (0.028, 0.022, 0.006), (0, y, zc - h * 0.38), bevel=0.002, m=M["pink"]),
    ]
    for side in (-1, 1):
        parts.append(sphere(f"{prefix}Eye{side}", 0.004, (side * 0.006, y + eye * 0.009, zc + h * 0.1), m=M["cell"], segs=8, rings=5))
    return parts


def build_lava_lampoon():
    reset_scene()
    palette()
    M = weapon_mats("#ffd23f", emit=2.2)
    basalt = mat("Basalt", "#3a2a4d", rough=0.5)
    glass = mat("LampGlass", "#ff2e88", rough=0.12, emit=1.1, emit_color="#ff6a1f")
    wax = mat("Wax", "#ffd23f", rough=0.3, emit=1.8)
    display = mat("Display", "#3ff0e0", rough=0.3, emit=2.4)
    grip_loc = (0, -0.03, -0.115)
    grip_parts, G = grip("", grip_loc, M, tilt=-14, size=(0.07, 0.092, 0.19), body_bottom=-0.02)
    bore_z = 0.04
    fore = (0, 0.215, -0.062)
    lx, ly = LAMP_X, LAMP_Y

    shell = grip_parts + [
        # Stubby magma-orange receiver on a basalt belly.
        loft("Body", [(-0.115, 0.042, 0.04, 0.032, 0.018), (-0.06, 0.048, 0.047, 0.03, 0.022), (0.12, 0.048, 0.047, 0.03, 0.022),
                      (0.19, 0.04, 0.038, 0.034, 0.018)], M["shell"]),
        box("Belly", (0.09, 0.27, 0.03), (0, 0.04, -0.016), bevel=0.01, m=basalt),
        box("TopDeck", (0.07, 0.2, 0.01), (0.008, 0.03, 0.077), bevel=0.004, m=basalt),
        # The lamp's sponson: a basalt shelf under the overhang on the left.
        box("Sponson", (0.05, 0.08, 0.022), (lx, ly, SOCKET_Z - 0.008), bevel=0.008, m=basalt),
        box("SponsonRib", (0.012, 0.06, 0.03), (lx - 0.022, ly, SOCKET_Z - 0.03), bevel=0.004, m=M["dark"]),
        # Tiki-band wrap round the front of the receiver.
        box("TikiBand", (0.104, 0.044, 0.1), (0, 0.13, 0.03), bevel=0.012, m=M["trim"]),
        box("TikiBandLip0", (0.106, 0.006, 0.102), (0, 0.108, 0.03), bevel=0.002, m=M["dark"]),
        box("TikiBandLip1", (0.106, 0.006, 0.102), (0, 0.152, 0.03), bevel=0.002, m=M["dark"]),
        # Barrel and the flared trumpet muzzle with its glowing yolk core.
        ycyl("Barrel", 0.024, 0.1, 0.235, z=bore_z, m=M["dark"], segs=18),
        ring("BarrelBand", 0.025, 0.004, 0.215, z=bore_z, m=M["steel"], segs=18),
        ycyl("Flare", 0.028, 0.06, 0.31, z=bore_z, m=M["shell"], segs=24, radius_top=0.048),
        ring("FlareLip", 0.047, 0.006, 0.34, z=bore_z, m=M["pink"], segs=24),
        ycyl("FlareCore", 0.032, 0.006, 0.336, z=bore_z, m=M["cell"], segs=20, bevel=0.0),
        ycyl("FlareBore", 0.014, 0.008, 0.339, z=bore_z, m=mat("Bore", "#3a1020", rough=0.9), segs=14, bevel=0.0),
        # Rounded obsidian foregrip.
        box("ForegripMount", (0.05, 0.06, 0.04), (0, fore[1], 0.0), bevel=0.01, m=M["dark"]),
        box("Foregrip", (0.044, 0.05, 0.11), fore, bevel=0.02, m=M["dark"]),
        sphere("ForegripKnob", 0.026, (0, fore[1], fore[2] - 0.062), scale=(1, 1, 0.6), m=M["pink"], segs=14, rings=8),
        # Short stock with a magenta butt pad.
        box("StockNeck", (0.05, 0.06, 0.05), (0, -0.13, 0.02), bevel=0.012, m=M["dark"]),
        box("Stock", (0.056, 0.05, 0.07), (0, -0.165, 0.012), bevel=0.016, m=M["shell"]),
        box("ButtPad", (0.06, 0.012, 0.074), (0, -0.193, 0.012), bevel=0.006, m=M["dark"]),
        box("ButtStripe", (0.062, 0.013, 0.012), (0, -0.193, 0.03), bevel=0.003, m=M["pink"]),
        # The holographic ammo display's housing on the left flank.
        box("DisplayFrame", (0.006, 0.086, 0.04), (-0.049, -0.07, 0.03), bevel=0.003, m=M["dark"]),
        box("DisplayGlass", (0.003, 0.078, 0.032), (-0.0525, -0.07, 0.03), bevel=0.001, m=mat("DisplayBack", "#0d3a40", rough=0.2, emit=0.6, emit_color="#1fc8b8")),
        # The lamp's gold cone socket, with a teal emitter groove for the hologram ring.
        lathe("Socket", [(0.0, 0.041), (0.012, 0.038), (0.02, 0.033), (0.0255, 0.03)], (lx, ly, SOCKET_Z), M["steel"], segs=28),
        torus("SocketGroove", 0.036, 0.003, (lx, ly, SOCKET_Z + 0.014), m=M["trim"], major_segs=28, minor_segs=5),
        # Bridge for the sights over the lamp: two tiki posts and a flat rail.
        box("BridgeBeam", (0.03, 0.2, 0.012), (0, 0.012, RAIL_TOP - 0.018), bevel=0.004, m=M["dark"]),
    ]
    shell += tiki_post("PostRear", -0.088, M, -1)
    shell += tiki_post("PostFront", 0.098, M, -1)
    shell += top_rail("TopRail", -0.06, 0.1, RAIL_TOP, M, width=0.03)
    # Tiki-band diamonds in yolk and magenta down both flanks.
    for side in (-1, 1):
        for i in range(3):
            shell.append(box(f"Diamond{side}{i}", (0.004, 0.013, 0.013), (side * 0.0525, 0.116 + i * 0.014, 0.03 + (0.022 if i % 2 else -0.0)),
                             rot=rad(45, 0, 0), bevel=0.0, m=M["cell"] if i % 2 == 0 else M["pink"]))
        shell.append(box(f"Zig{side}", (0.004, 0.04, 0.006), (side * 0.0525, 0.13, 0.002), bevel=0.0, m=M["cell"]))
    # Vent slits behind the muzzle that glow when it pulses.
    shell += vent_slots("Vent", 0.049, 0.05, 0.095, 0.03, 3, M["dark"], M["cell"], height=0.03, side=1)
    shell += bolts("Pin", [(-0.049, 0.06, 0.0), (0.049, 0.02, 0.05), (-0.049, 0.16, 0.06)], M["steel"], radius=0.006, height=0.006)
    lug, charm_point = charm_lug(-0.028, -0.165, 0.004, M)
    shell += lug
    sight_rear, sight_front = sights_notch(0.0, -0.055, 0.095, RAIL_TOP, RAIL_TOP, RAIL_TOP + SIGHT_HEIGHT, M, gap=0.016)

    # The heater coil in the socket: hot yolk turns, seen when the lamp is out.
    coil = [torus(f"Coil{i}", 0.02 - i * 0.004, 0.0026, (lx, ly, SOCKET_Z + 0.02 + i * 0.003), m=M["cell"], major_segs=20, minor_segs=5)
            for i in range(3)]
    coil.append(cyl("CoilPost", 0.006, 0.012, (lx, ly, SOCKET_Z + 0.022), segs=10, bevel=0.001, m=M["cell"]))
    coil_holo = holo_copy(coil)

    # The lamp: screw collar, the glass, the cap and a few wax blobs on the glass.
    collar = [
        lathe("Collar", [(0.0, 0.029), (0.004, 0.03), (0.009, 0.026)], (lx, ly, COLLAR_Z), M["steel"], segs=28),
    ]
    for i in range(2):
        collar.append(torus(f"Thread{i}", 0.0275, 0.0016, (lx, ly, COLLAR_Z + 0.0025 + i * 0.0035), m=M["steel"], major_segs=24, minor_segs=4))
    glass_ob = lathe("Glass", LAMP_PROFILE, (lx, ly, GLASS_Z), glass, segs=32)
    cap = [
        lathe("CapCone", [(0.0, 0.019), (0.004, 0.0205), (0.01, 0.015), (0.02, 0.006), (0.024, 0.002)], (lx, ly, CAP_Z), M["steel"], segs=24),
        torus("CapRim", 0.019, 0.0022, (lx, ly, CAP_Z + 0.002), m=M["pink"], major_segs=24, minor_segs=5),
        sphere("CapTip", 0.004, (lx, ly, CAP_Z + 0.025), m=M["cell"], segs=10, rings=6),
    ]
    blobs = []
    for i, (h, a, s) in enumerate([(0.016, 200, 0.011), (0.04, 150, 0.009), (0.058, 235, 0.008), (0.03, 300, 0.008), (0.072, 175, 0.006)]):
        r = glass_radius(h) - s * 0.55
        rad_a = math.radians(a)
        blobs.append(sphere(f"Blob{i}", s, (lx + math.cos(rad_a) * r, ly + math.sin(rad_a) * r, GLASS_Z + h), scale=(1, 1, 1.25), m=wax, segs=12, rings=8))
    # The hologram ring the lamp rides out on, with ticks so its spin reads.
    ring_parts = [torus("RingBand", 0.046, 0.0035, (lx, ly, SOCKET_Z + 0.027), m=M["holo"], major_segs=36, minor_segs=5)]
    for i in range(8):
        a = math.tau * i / 8
        ring_parts.append(box(f"RingTick{i}", (0.012, 0.004, 0.003), (lx + math.cos(a) * 0.052, ly + math.sin(a) * 0.052, SOCKET_Z + 0.027),
                              rot=(0, 0, a), bevel=0.0, m=M["holo"]))
    # Ammo display: two rows of little lamp icons.
    pips = {}
    for i in range(PIPS):
        c = (-0.0545, -0.101 + (i % 5) * 0.0155, 0.038 - (i // 5) * 0.016)
        pips[f"Pip{i}"] = ([sphere(f"Pip{i}Lamp", 0.0042, c, scale=(0.5, 1.0, 1.5), m=display, segs=8, rings=6)], c)

    emblem = [(-0.012, -0.014), (0.012, -0.014), (0.008, 0.004), (0.0, 0.018), (-0.008, 0.004)]
    decal = [side_emblem("Emblem", emblem, -0.05, 0.05, 0.03, M["decal"])]
    arm_r, elbow_r = firing_hand(G, M, (0.17, -0.62, -0.44))
    arm_l, elbow_l = vertical_hand(fore, 0.023, 0.027, 0.11, M, (-0.52, -0.16, -0.46))
    lamp_pivot = (lx, ly, COLLAR_Z)
    groups = {
        "Shell": (shell, (0, 0, 0), None),
        "IronSightRear": (sight_rear, (0, -0.055, RAIL_TOP), None),
        "IronSightFront": (sight_front, (0, 0.095, RAIL_TOP), None),
        "Lamp": (collar, lamp_pivot, None),
        "LampGlass": ([glass_ob], (lx, ly, GLASS_Z), "Lamp"),
        "LampWax": (blobs, (lx, ly, GLASS_Z), "Lamp"),
        "LampCap": (cap, (lx, ly, CAP_Z), "Lamp"),
        "LampRingHolo": (ring_parts, (lx, ly, SOCKET_Z + 0.027), None),
        "Cell": (coil, (lx, ly, SOCKET_Z + 0.02), None),
        "CellHolo": (coil_holo, (lx, ly, SOCKET_Z + 0.02), None),
        "Decal": (decal, (0, 0, 0), None),
        "ArmR": (arm_r, grip_loc, None),
        "ArmL": (arm_l, fore, None),
    }
    for name, (parts, centre) in pips.items():
        groups[name] = (parts, centre, None)
    empties = {
        "Muzzle": ((0, 0.345, bore_z), None),
        "SightPoint": ((0, -0.055, RAIL_TOP + SIGHT_HEIGHT), None),
        "SightMount": ((0, 0.02, RAIL_TOP), None),
        "EjectPoint": ((lx, ly, CAP_Z + 0.03), None),
        "VentPoint": ((0.05, 0.07, 0.03), None),
        "CharmPoint": (charm_point, None),
        "ElbowR": (elbow_r, "ArmR"),
        "ElbowL": (elbow_l, "ArmL"),
    }
    finish("lava_lampoon", groups, empties)


if __name__ == "__main__":
    build_lava_lampoon()
