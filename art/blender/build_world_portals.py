"""Themed exit-portal frames for worlds 3-5. Each keeps the shared portal's doorway
(scripts/props/exit_portal.gd and art/shaders/portal_swirl.gdshader): straight sides
1.45 m either side of centre up to 2.25 m, an elliptical top reaching 3.75 m, the
swirl 0.12 m behind the frame plane, and solid jambs around x = +-1.75. Faces -Y.

    aqua_portal_arch.glb    Tidal Tunnels: a submarine bulkhead in a riveted wall
                            plate: yellow coaming, brass lip and dogs, portholes,
                            pipes with valve wheels, a gauge, cage lamps, bubble vents
                            and a lit EXIT sign. Under 4.7 m (it stands on the
                            mezzanine).
    dune_portal_arch.glb    Launch Pad 9: a launch gate: hull-white pylons with
                            hazard bands and amber hazard lights, a segmented
                            teleporter ring with glowing emitters, beacons, cables,
                            a hazard-striped pad and a GATE 09 / EXIT sign.
    frost_portal_arch.glb   Summit Lodge: an ice-block arch under heavy snow with
                            icicles, aurora ribbons, lantern posts and a carved
                            timber EXIT sign.

    python art/blender/build_world_portals.py [aqua] [dune] [frost]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import aqua_common as aq  # noqa: E402
import dune_kit as dk  # noqa: E402
import frost_common as fc  # noqa: E402
from wla_common import *  # noqa: F401,F403,E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

OPEN_W = 1.45        # half-width of the swirl doorway
OPEN_SPRING = 2.25   # where its straight sides end
OPEN_RISE = 1.5      # height of its elliptical top above the spring


def arch_path(half_w, rise, steps=24, spring=OPEN_SPRING, base=0.0, y=0.0):
    """Doorway outline offset outward: up the left side, over the elliptical top
    (semi-axes half_w x rise, centred at the spring) and down the right side."""
    pts = [(-half_w, y, base)]
    for i in range(steps + 1):
        a = math.pi - math.pi * i / steps
        pts.append((math.cos(a) * half_w, y, spring + math.sin(a) * rise))
    pts.append((half_w, y, base))
    return pts


def arc_only(half_w, rise, steps=24, spring=OPEN_SPRING, y=0.0, a0=0.0, a1=180.0):
    """Points along the elliptical top only, from angle a1 down to a0 (degrees)."""
    out = []
    for i in range(steps + 1):
        a = math.radians(a1 + (a0 - a1) * i / steps)
        out.append((math.cos(a) * half_w, y, spring + math.sin(a) * rise))
    return out


def opening_outline(grow=0.05, base=-0.2, steps=24):
    """(x, z) outline of the doorway, slightly enlarged, for cutters and backings."""
    w, r = OPEN_W + grow, OPEN_RISE + grow
    pts = [(-w, base)]
    for i in range(steps + 1):
        a = math.pi - math.pi * i / steps
        pts.append((math.cos(a) * w, OPEN_SPRING + math.sin(a) * r))
    pts.append((w, base))
    return pts


def xform(parts, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Move a group of parts as one rigid piece (rotate XYZ about the origin, then translate)."""
    mtx = Matrix.Translation(Vector(loc)) @ Euler(rot, "XYZ").to_matrix().to_4x4()
    for ob in parts:
        ob.matrix_world = mtx @ ob.matrix_basis
    return parts


def cut(ob, cutter):
    mod = ob.modifiers.new("DoorCut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    return ob


def block_on_arc(name, half_w, rise, a_deg, size, m, y=0.0, bevel=0.06, spring=OPEN_SPRING):
    """A box sitting on the ellipse at angle a_deg, its X axis along the tangent."""
    a = math.radians(a_deg)
    p = Vector((math.cos(a) * half_w, y, spring + math.sin(a) * rise))
    tangent = Vector((-math.sin(a) * half_w, 0, math.cos(a) * rise)).normalized()
    ang = math.atan2(tangent.z, tangent.x)
    return box(name, size, tuple(p), rot=(0, -ang, 0), bevel=bevel, m=m)


def backing(name, m, y=0.32):
    """Dark doorway fill behind the swirl (what the dormant portal shows)."""
    return prism(name, opening_outline(0.12, 0.0), 0.1, (0, y, 0), m=m)


# ---------------------------------------------------------------------------
# Tidal Tunnels: submarine bulkhead
# ---------------------------------------------------------------------------

def build_aqua():
    reset_scene()
    navy, navyd = aq.amat("NavyLight", rough=0.5), aq.amat("NavyDark", rough=0.5)
    steel, brass = aq.amat("SteelDark", rough=0.4, metal=0.5), aq.amat("Brass", rough=0.35, metal=0.6)
    yellow, ydark = aq.amat("SubYellow", rough=0.45, emit=0.22), aq.amat("SubYellowDark", rough=0.5)
    teal, red = aq.amat("Teal", rough=0.45), aq.amat("Red", rough=0.5)
    port = aq.aglow("PortGlow", "Cyan", 2.2)
    lamp = glow("PortalLampAmber", "#ffb84a", 3.2)
    coral = aq.aglow("ExitCoral", "#ff7a5a", 2.8)
    pw, ph = 2.9, 4.6
    p = []
    cutter = prism("DoorCutter", opening_outline(0.02, -0.5), 1.0, (0, 0.2, 0))
    cutter.hide_render = True
    plate = box("Plate", (2 * pw, 0.22, ph), (0, 0.2, ph / 2), bevel=0.08, m=navy)
    p.append(cut(plate, cutter))
    # Raised border round the plate and a rivet line inside it.
    p += [
        box("BorderT", (2 * pw, 0.3, 0.2), (0, 0.16, ph - 0.1), bevel=0.05, m=steel),
        box("BorderL", (0.2, 0.3, ph), (-pw + 0.1, 0.16, ph / 2), bevel=0.05, m=steel),
        box("BorderR", (0.2, 0.3, ph), (pw - 0.1, 0.16, ph / 2), bevel=0.05, m=steel),
        box("Kick", (2 * pw, 0.3, 0.22), (0, 0.16, 0.11), bevel=0.04, m=steel),
    ]
    p += aq.rivet_row("RivT", (-pw + 0.3, 0.05, ph - 0.32), (pw - 0.3, 0.05, ph - 0.32), 18, 0.035, brass)
    for s in (-1, 1):
        p += aq.rivet_row(f"RivS{s}", (s * (pw - 0.32), 0.05, 0.4), (s * (pw - 0.32), 0.05, 2.2), 5, 0.035, brass)
        p += aq.rivet_row(f"RivU{s}", (s * (pw - 0.32), 0.05, 3.35), (s * (pw - 0.32), 0.05, ph - 0.5), 3, 0.035, brass)
    # The coaming: a fat yellow lip round the doorway, a brass inner edge and dog latches.
    p.append(tube("Coaming", arch_path(OPEN_W + 0.27, OPEN_RISE + 0.27, base=0.02, y=-0.02), 0.27, m=yellow, segs=12))
    p.append(tube("CoamingBand", arch_path(OPEN_W + 0.27, OPEN_RISE + 0.27, base=0.02, y=-0.12), 0.2, m=ydark, segs=10))
    p.append(tube("Lip", arch_path(OPEN_W + 0.03, OPEN_RISE + 0.03, base=0.0, y=-0.28), 0.06, m=brass, segs=8))
    for i, a in enumerate((20, 55, 90, 125, 160)):
        p.append(block_on_arc(f"Dog{i}", OPEN_W + 0.52, OPEN_RISE + 0.52, a, (0.14, 0.22, 0.36), steel, y=-0.2, bevel=0.03))
    for s in (-1, 1):
        for i, z in enumerate((0.7, 1.6)):
            p.append(box(f"DogSide{s}{i}", (0.36, 0.22, 0.14), (s * (OPEN_W + 0.52), -0.2, z), bevel=0.03, m=steel))
    # Portholes with lit water behind, one each side.
    for s in (-1, 1):
        p += aq.porthole(f"Port{s}", 0.3, (s * 2.3, 0.06, 2.75), frame=brass, glass=port, rivets=8)
    # Pipes up the outer edges; valve wheel on the left, gauge on the right.
    for s in (-1, 1):
        x = s * (pw - 0.15)
        p.append(tube(f"Pipe{s}", [(x, -0.12, 0.0), (x, -0.12, 3.85), (x - s * 0.05, -0.12, 4.05), (x - s * 0.5, -0.12, 4.12)], 0.08, m=teal, segs=10))
        for i, z in enumerate((0.6, 2.0, 3.4)):
            p.append(cyl(f"PipeCollar{s}{i}", 0.11, 0.08, (x, -0.12, z), segs=10, bevel=0.0, m=brass))
    wheel = [torus("Wheel", 0.24, 0.035, (0, 0, 0), rot=rad(90, 0, 0), m=red, major_segs=20, minor_segs=5),
             cyl("WheelHub", 0.06, 0.08, (0, 0, 0), rot=rad(90, 0, 0), segs=10, bevel=0.0, m=steel),
             cyl("WheelStem", 0.03, 0.16, (0, 0.08, 0), rot=rad(90, 0, 0), segs=6, bevel=0.0, m=steel)]
    for i in range(4):
        wheel.append(box(f"WheelSpoke{i}", (0.46, 0.03, 0.03), (0, 0, 0), rot=(0, math.radians(45 * i), 0), bevel=0.0, m=red))
    p += place(wheel, (-(pw - 0.15), -0.32, 1.45))
    p += [
        cyl("Gauge", 0.17, 0.08, (pw - 0.15, -0.3, 1.6), rot=rad(90, 0, 0), segs=16, bevel=0.02, m=brass),
        cyl("GaugeFace", 0.14, 0.02, (pw - 0.15, -0.35, 1.6), rot=rad(90, 0, 0), segs=16, bevel=0.0, m=aq.amat("White", rough=0.4)),
        box("GaugeNeedle", (0.02, 0.02, 0.12), (pw - 0.15 + 0.03, -0.37, 1.63), rot=rad(0, 35, 0), bevel=0.0, m=red),
        box("GaugeStem", (0.06, 0.18, 0.06), (pw - 0.15, -0.2, 1.6), bevel=0.0, m=steel),
    ]
    # Cage lamps at the top corners, the EXIT sign between them.
    for s in (-1, 1):
        x = s * 2.3
        p += [
            box(f"LampBase{s}", (0.3, 0.12, 0.3), (x, 0.0, 4.05), bevel=0.04, m=steel),
            cyl(f"LampGlass{s}", 0.11, 0.24, (x, -0.16, 4.05), rot=rad(90, 0, 0), segs=12, bevel=0.0, m=lamp),
            torus(f"LampCage{s}", 0.13, 0.018, (x, -0.2, 4.05), rot=rad(90, 0, 0), m=brass, major_segs=12, minor_segs=4),
            bulb(f"LampHalo{s}", 0.1, (x, -0.24, 4.05), lamp),
        ]
    p += [
        box("SignBox", (1.3, 0.22, 0.36), (0, -0.08, 4.4), bevel=0.05, m=navyd),
        box("SignRim", (1.38, 0.18, 0.44), (0, -0.04, 4.4), bevel=0.05, m=brass),
        text("SignText", "EXIT", 0.28, 0.03, (0, -0.21, 4.39), m=coral),
    ]
    # Bubble vents either side of the threshold, a tread plate and a few barnacles.
    for s in (-1, 1):
        p += [
            cyl(f"Vent{s}", 0.26, 0.04, (s * 2.05, -0.55, 0.02), segs=16, bevel=0.0, m=navyd),
            torus(f"VentRim{s}", 0.26, 0.03, (s * 2.05, -0.55, 0.04), m=brass, major_segs=16, minor_segs=4),
            box(f"VentBarA{s}", (0.46, 0.04, 0.02), (s * 2.05, -0.55, 0.05), bevel=0.0, m=steel),
            box(f"VentBarB{s}", (0.04, 0.46, 0.02), (s * 2.05, -0.55, 0.05), bevel=0.0, m=steel),
        ]
    p.append(box("Tread", (3.1, 1.0, 0.03), (0, -0.62, 0.015), bevel=0.0, m=teal))
    for i in range(5):
        p.append(box(f"TreadRib{i}", (2.9, 0.04, 0.02), (0, -0.98 + i * 0.18, 0.035), bevel=0.0, m=aq.amat("TealDark", rough=0.5)))
    # A starfish and barnacles clinging to the plate.
    p.append(star("Starfish", 0.16, 0.05, (-2.3, 0.05, 0.75), rot=(0, math.radians(20), 0), m=aq.amat("Coral", rough=0.5), inner=0.07, bevel=0.012))
    p.append(star("StarfishB", 0.12, 0.05, (2.25, 0.05, 3.55), rot=(0, math.radians(-15), 0), m=aq.amat("SubYellow", rough=0.45, emit=0.22), inner=0.05, bevel=0.01))
    for i, (x, z) in enumerate(((-2.05, 0.5), (-2.15, 0.62), (2.3, 0.55), (2.4, 0.68), (-2.4, 3.5))):
        p.append(sphere(f"Barnacle{i}", 0.07, (x, 0.07, z), scale=(1, 0.6, 1), m=aq.amat("CoralLight", rough=0.6), segs=8, rings=5))
    p.append(backing("Back", navyd, y=0.28))
    save("aqua_portal_arch", [merge("PortalArch", p)])


# ---------------------------------------------------------------------------
# Launch Pad 9: launch gate
# ---------------------------------------------------------------------------

def build_dune():
    reset_scene()
    white, shade = dk.dmat("Hull", rough=0.45), dk.dmat("HullShade", rough=0.5)
    teal, tdark = dk.dmat("Teal", rough=0.45), dk.dmat("TealDark", rough=0.5)
    rust = dk.dmat("Rust", rough=0.55)
    sdark, steel = dk.dmat("SteelDark", rough=0.45, metal=0.4), dk.dmat("Steel", rough=0.4, metal=0.5)
    navy, rubber = dk.dmat("Navy", rough=0.5), dk.dmat("Rubber", rough=0.8)
    concrete = dk.dmat("ConcreteDark", rough=0.9)
    amber = dk.dglow("GateAmber", "#ffa12a", 3.2)
    emitter = dk.dglow("GateEmitter", "#5cf2ff", 2.6)
    sign_glow = dk.dglow("GateSign", "#7cf6d8", 2.4)
    p = []
    # Pad: a low octagon with a hazard-striped front edge.
    p.append(cyl("Pad", 2.9, 0.04, (0, -0.3, 0.02), rot=(0, 0, math.pi / 8), segs=8, bevel=0.0, m=concrete))
    p.append(cyl("PadRing", 2.2, 0.012, (0, -0.3, 0.045), segs=8, bevel=0.0, m=sdark, radius_top=2.2))
    band = dk.hazard_band("PadEdge", 3.6, 0.32, (0, 0, 0), 0.0, depth=0.02, stripe=0.32)
    p += xform(band, (0, -2.45, 0.05), (math.radians(-90), 0, 0))
    # Pylons.
    for s in (-1, 1):
        x = s * 1.95
        p += [
            box(f"Pylon{s}", (0.9, 1.0, 2.5), (x, 0, 1.25), bevel=0.08, m=white),
            box(f"PylonFoot{s}", (1.1, 1.2, 0.3), (x, 0, 0.15), bevel=0.05, m=sdark),
            box(f"PylonPanel{s}", (0.92, 0.7, 0.9), (x, 0.0, 1.6), bevel=0.04, m=teal),
            box(f"PylonCap{s}", (1.0, 1.1, 0.22), (x, 0, 2.5), bevel=0.05, m=rust),
        ]
        hb = dk.hazard_band(f"PylonHazard{s}", 0.86, 0.3, (0, 0, 0), 0.0, depth=0.02, stripe=0.18)
        p += xform(hb, (x, -0.51, 0.55))
        for i in range(3):
            p.append(dk.fbox(f"PylonVent{s}{i}", (0.6, 0.03, 0.06), (x, -0.51, 2.0 + i * 0.12), m=sdark))
        # Hazard lights down the inner edge.
        for i in range(4):
            p.append(bulb(f"PylonLight{s}{i}", 0.07, (x - s * 0.36, -0.53, 0.95 + i * 0.36), amber))
        # Beacon on top.
        p += [
            cyl(f"BeaconBase{s}", 0.22, 0.14, (x, 0, 2.68), segs=12, bevel=0.03, m=sdark),
            sphere(f"BeaconDome{s}", 0.17, (x, 0, 2.78), scale=(1, 1, 1.15), m=amber, segs=10, rings=6),
            torus(f"BeaconCage{s}", 0.19, 0.02, (x, 0, 2.86), m=steel, major_segs=12, minor_segs=4),
            bulb(f"BeaconHalo{s}", 0.12, (x, 0, 2.86), amber),
        ]
        # Cable from the back of the pylon into the pad.
        p.append(tube(f"Cable{s}", [(x + s * 0.2, 0.5, 1.2), (x + s * 0.35, 0.75, 0.6), (x + s * 0.5, 0.9, 0.05), (x + s * 1.2, 1.1, 0.03)],
                      0.05, m=rubber, segs=6))
    p.append(cyl("Antenna", 0.025, 1.0, (2.25, 0.25, 3.25), segs=6, bevel=0.0, m=steel))
    # Segmented teleporter ring over the doorway.
    hw, rise = OPEN_W + 0.35, OPEN_RISE + 0.35
    for i in range(9):
        a = 180.0 * (i + 0.5) / 9
        p.append(block_on_arc(f"RingSeg{i}", hw, rise, a, (0.46, 0.62, 0.36), white if i % 2 == 0 else teal, bevel=0.05))
    for i in range(10):
        a = 180.0 * i / 9
        p.append(block_on_arc(f"Emitter{i}", hw, rise, a, (0.12, 0.66, 0.3), emitter, bevel=0.02))
    p.append(tube("RingOuter", arc_only(hw + 0.32, rise + 0.32, y=0.05), 0.07, m=rust, segs=8))
    p.append(tube("RingInner", arc_only(OPEN_W + 0.05, OPEN_RISE + 0.05, y=-0.25), 0.045, m=emitter, segs=6))
    # Jambs inside the pylons: emitter strips down to the pad.
    for s in (-1, 1):
        p.append(box(f"JambStrip{s}", (0.06, 0.06, OPEN_SPRING - 0.1), (s * (OPEN_W + 0.05), -0.25, OPEN_SPRING / 2 + 0.05), bevel=0.0, m=emitter))
    # Sign on a gantry over the ring.
    top = OPEN_SPRING + rise + 0.5
    p += [
        box("SignBox", (1.9, 0.24, 0.62), (0, 0, top + 0.2), bevel=0.05, m=navy),
        box("SignTrim", (2.0, 0.2, 0.08), (0, 0, top - 0.12), bevel=0.02, m=rust),
        text("SignText", "EXIT", 0.34, 0.03, (0, -0.14, top + 0.26), m=sign_glow),
        text("SignSub", "GATE 09", 0.12, 0.02, (0, -0.14, top + 0.0), m=amber),
    ]
    for s in (-1, 1):
        p.append(box(f"SignStrut{s}", (0.1, 0.1, 0.6), (s * 0.7, 0.0, top - 0.35), bevel=0.0, m=sdark))
    p.append(backing("Back", navy, y=0.32))
    save("dune_portal_arch", [merge("PortalArch", p)])


# ---------------------------------------------------------------------------
# Summit Lodge: ice and aurora arch
# ---------------------------------------------------------------------------

def build_frost():
    reset_scene()
    ice = mat("FrostPortalIce", "#bfeaff", rough=0.15, emit=0.35)
    ice_deep = mat("FrostPortalIceDeep", "#7fc0ee", rough=0.15, emit=0.25)
    snow = fc.snow_mat()
    timber, dark = fc.fmat("Timber"), fc.fmat("TimberDark")
    lantern = fc.fglow("FrostBulbAmber", "#ffc46b", 3.0)
    green = fc.fglow("PortalAurora", "#3cf59a", 1.2)
    lilac = fc.fglow("PortalAuroraLilac", "#a070ff", 1.2)
    navy = fc.fmat("Navy")
    rng = random.Random(5)
    p = []
    # Ice-block jambs.
    for s in (-1, 1):
        z = 0.0
        for i, h in enumerate((0.8, 0.75, 0.7)):
            w = 0.82 + rng.uniform(-0.05, 0.05)
            p.append(box(f"Jamb{s}{i}", (w, 0.86, h - 0.03), (s * (OPEN_W + 0.4) + rng.uniform(-0.03, 0.03), 0, z + h / 2),
                         rot=(0, 0, math.radians(rng.uniform(-3, 3))), bevel=0.09, m=ice if (i + (s > 0)) % 2 == 0 else ice_deep))
            z += h
    # Voussoirs round the top.
    hw, rise = OPEN_W + 0.4, OPEN_RISE + 0.4
    for i in range(9):
        a = 180.0 * (i + 0.5) / 9
        size = (0.6 + (0.12 if i == 4 else 0.0), 0.9, 0.78 + (0.14 if i == 4 else 0.0))
        p.append(block_on_arc(f"Vous{i}", hw, rise, a, size, ice_deep if i % 2 else ice, bevel=0.09))
    # Snow piled on top, drifts at the feet, icicles hanging off the front edge.
    for i in range(9):
        a = math.radians(180.0 * (i + 0.5) / 9)
        x, z = math.cos(a) * (hw + 0.2), OPEN_SPRING + math.sin(a) * (rise + 0.3)
        p.append(sphere(f"ArchSnow{i}", 0.42, (x, 0.0, z), scale=(1.3, 1.25, 0.7), m=snow, segs=10, rings=6))
    for s in (-1, 1):
        p.append(sphere(f"JambSnow{s}", 0.45, (s * (OPEN_W + 0.4), 0, 2.3), scale=(1.1, 1.15, 0.5), m=snow, segs=10, rings=6))
        p.append(sphere(f"FootDrift{s}", 0.7, (s * (OPEN_W + 0.55), -0.25, 0.05), scale=(1.3, 1.1, 0.5), m=snow, segs=10, rings=6))
        p.append(sphere(f"FootDriftB{s}", 0.5, (s * (OPEN_W + 1.25), 0.1, 0.0), scale=(1.4, 1.0, 0.45), m=snow, segs=10, rings=6))
    for i in range(14):
        a = math.radians(12 + 156.0 * i / 13)
        x, z = math.cos(a) * (OPEN_W + 0.05), OPEN_SPRING + math.sin(a) * (OPEN_RISE + 0.05)
        ln = 0.18 + 0.22 * rng.random()
        p.append(fc.cone_down(f"Icicle{i:02d}", 0.045, ln, (x, -0.42, z), mat("FrostIcicle", "#bfeaff", rough=0.15, emit=0.25)))
    # Aurora ribbons behind the arch top.
    for k, (off, m, phase) in enumerate(((0.75, green, 0.0), (1.05, lilac, 1.4))):
        pts = []
        for i in range(25):
            a = math.radians(-6 + 192.0 * i / 24)
            wob = 0.08 * math.sin(i * 0.8 + phase)
            pts.append((math.cos(a) * (hw + off + wob), 0.25, OPEN_SPRING + math.sin(a) * (rise + off + wob)))
        p.append(tube(f"Aurora{k}", pts, 0.09 - k * 0.015, m=m, segs=6))
    # Lantern posts either side.
    for s in (-1, 1):
        x = s * 2.75
        p += [
            box(f"Post{s}", (0.16, 0.16, 2.5), (x, -0.2, 1.25), bevel=0.03, m=timber),
            box(f"PostArm{s}", (0.42, 0.08, 0.08), (x - s * 0.17, -0.2, 2.42), bevel=0.02, m=dark),
            box(f"Lantern{s}", (0.22, 0.22, 0.3), (x - s * 0.35, -0.2, 2.18), bevel=0.03, m=lantern),
            cyl(f"LanternCap{s}", 0.19, 0.1, (x - s * 0.35, -0.2, 2.38), segs=4, bevel=0.0, m=dark, radius_top=0.04),
            bulb(f"LanternHalo{s}", 0.13, (x - s * 0.35, -0.2, 2.18), lantern),
            sphere(f"PostSnow{s}", 0.13, (x, -0.2, 2.53), scale=(1.2, 1.2, 0.6), m=snow, segs=8, rings=5),
        ]
    # Carved EXIT board hung from the keystone.
    top = OPEN_SPRING + rise
    p += [
        box("Board", (1.3, 0.1, 0.46), (0, -0.55, top - 0.25), bevel=0.04, m=timber),
        box("BoardEdge", (1.38, 0.08, 0.54), (0, -0.5, top - 0.25), bevel=0.03, m=dark),
        text("BoardText", "EXIT", 0.3, 0.03, (0, -0.62, top - 0.27), m=fc.fmat("Cream")),
        sphere("BoardSnow", 0.2, (0, -0.55, top - 0.01), scale=(3.0, 0.5, 0.35), m=snow, segs=10, rings=5),
    ]
    for s in (-1, 1):
        p.append(cyl(f"BoardChain{s}", 0.012, 0.25, (s * 0.5, -0.5, top + 0.05), segs=4, bevel=0.0, m=dark))
    p.append(backing("Back", navy, y=0.3))
    save("frost_portal_arch", [merge("PortalArch", p)])


ALL = {"aqua": build_aqua, "dune": build_dune, "frost": build_frost}


if __name__ == "__main__":
    wanted = [a for a in sys.argv[1:] if a in ALL] or list(ALL)
    for key in wanted:
        ALL[key]()
