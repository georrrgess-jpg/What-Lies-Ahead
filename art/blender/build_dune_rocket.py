"""Launch Pad 9 centrepiece: the rocket, its service gantry, the launch mount and ramps.

    dune_rocket.glb        retro-futurist rocket, ~31 m, standing on its four fins.
                           Origin = centre of the fin tips (sits on the launch table).
    dune_gantry.glb        rust-red lattice service tower (~36 m) with crew-access and
                           umbilical arms reaching toward +X (the rocket). Origin = base centre.
    dune_launch_mount.glb  20 x 14 m concrete pedestal, 2 m high, with the steel launch
                           table, flame-trench mouths, pipework and stencils. Origin = base centre.
    dune_ramp.glb          4 m wide steel ramp: its high end (2 m, deck height) sits over the
                           origin and it descends 8 m toward -Y (Godot +Z) to the ground.
    dune_rail.glb          3 m yellow safety-rail module running along X (deck edges).

Front faces -Y (Godot +Z).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dune_kit import *  # noqa: F401,F403

BODY_R = 2.0
DECK_H = 2.0


def _ogive(r0, z0, z1, steps=10):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        r = r0 * (1.0 - t ** 1.7) ** 0.62
        pts.append((max(r, 0.12 if i == steps else 0.0), z0 + (z1 - z0) * t))
    return pts


def build_rocket():
    reset_scene()
    hull, shade = dmat("Hull", rough=0.45), dmat("HullShade", rough=0.5)
    teal, tdark = dmat("Teal", rough=0.45), dmat("TealDark", rough=0.5)
    rust, rdark = dmat("Rust", rough=0.5), dmat("RustDark", rough=0.55)
    steel, sdark = dmat("Steel", rough=0.35, metal=0.6), dmat("SteelDark", rough=0.4, metal=0.5)
    copper = dmat("Copper", rough=0.35, metal=0.7)
    line = dmat("PanelLine", "#5b5560", rough=0.6)
    glass = dglow("PortGlass", "#ffd486", 1.6)
    burn = dglow("EngineGlow", "#ff7a2a", 1.2)
    parts = []
    # Hull: flared skirt, long body, ogive nose.
    profile = [(2.45, 1.5), (2.42, 1.75), (BODY_R + 0.06, 3.4), (BODY_R, 3.6), (BODY_R, 21.4)] + _ogive(BODY_R, 21.4, 30.2)[1:]
    parts.append(lathe("Hull", profile, m=hull, segs=40))
    parts.append(lathe("SkirtLip", [(2.48, 1.35), (2.52, 1.5), (2.5, 1.75), (2.4, 1.85)], m=rdark, segs=40))
    parts.append(lathe("BaseCap", [(2.36, 1.38), (1.2, 1.25)], m=sdark, segs=40, cap=True))
    # Coloured bands and panel lines.
    for name, z0, z1, m in (("BandLow", 5.6, 6.9, teal), ("BandMid", 14.2, 14.9, teal), ("BandTop", 19.6, 20.0, rust)):
        parts.append(cyl(name, BODY_R + 0.025, z1 - z0, (0, 0, (z0 + z1) / 2), segs=40, bevel=0.02, m=m))
    for i, z in enumerate((4.4, 8.4, 10.6, 12.6, 16.6, 18.4, 21.2)):
        parts.append(cyl(f"Seam{i}", BODY_R + 0.012, 0.05, (0, 0, z), segs=40, bevel=0.0, m=line))
    parts += hazard_ring("Hazard", BODY_R + 0.02, 4.0, 0.62, count=20)
    # Nose: rust tip with a needle antenna.
    parts.append(lathe("NoseTip", [(0.84, 27.6), (0.62, 28.6), (0.36, 29.5), (0.13, 30.25), (0.0, 30.35)], m=rust, segs=24))
    parts.append(cyl("Needle", 0.05, 2.2, (0, 0, 31.3), segs=8, bevel=0.0, m=steel))
    parts.append(sphere("NeedleBall", 0.13, (0, 0, 32.45), m=dglow("Beacon", "#ff4a3a", 3.0), segs=10, rings=6))
    # Portholes around the crew cabin (front half) and the hatch on the -X side (gantry).
    for i in range(5):
        a = math.radians(-90 + (i - 2) * 26)
        x, y = math.cos(a) * BODY_R, math.sin(a) * BODY_R
        rim = cyl(f"PortRim{i}", 0.36, 0.16, (x * 1.01, y * 1.01, 18.0), rot=(math.pi / 2, 0, a - math.pi / 2), segs=18, bevel=0.04, m=rdark)
        pane = cyl(f"PortPane{i}", 0.27, 0.12, (x * 1.04, y * 1.04, 18.0), rot=(math.pi / 2, 0, a - math.pi / 2), segs=18, bevel=0.03, m=glass)
        parts += [rim, pane]
    hatch = [box("HatchFrame", (0.2, 1.3, 1.9), (-BODY_R - 0.03, 0, 18.6), bevel=0.06, m=rdark),
             box("HatchDoor", (0.18, 1.0, 1.6), (-BODY_R - 0.08, 0, 18.6), bevel=0.06, m=shade),
             cyl("HatchWheel", 0.22, 0.08, (-BODY_R - 0.2, 0, 18.7), rot=(0, math.pi / 2, 0), segs=14, bevel=0.02, m=steel)]
    parts += hatch
    # Lettering down the front.
    for i, ch in enumerate("LP9"):
        parts.append(text(f"Mark{i}", ch, 1.45, 0.14, (0, -BODY_R - 0.02, 12.7 - i * 1.55), m=rust))
    parts.append(box("MarkStripe", (0.22, 0.12, 4.6), (-0.95, -BODY_R + 0.04, 11.1), bevel=0.04, m=teal))
    parts.append(box("MarkStripe2", (0.22, 0.12, 4.6), (0.95, -BODY_R + 0.04, 11.1), bevel=0.04, m=teal))
    # Conduit fairing up the back and RCS quads near the nose.
    parts.append(box("Conduit", (0.42, 0.3, 15.0), (0, BODY_R + 0.08, 12.6), bevel=0.1, m=shade))
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        rcs = [box(f"Rcs{i}", (0.5, 0.36, 0.5), (BODY_R + 0.12, 0, 22.4), bevel=0.08, m=sdark)]
        for k, (dy, dz) in enumerate(((0.26, 0), (-0.26, 0), (0, 0.3))):
            rcs.append(cyl(f"Rcs{i}N{k}", 0.07, 0.16, (BODY_R + 0.12, dy, 22.4 + dz), rot=(math.pi / 2 if dz == 0 else 0, 0, 0),
                           segs=8, bevel=0.0, m=steel, radius_top=0.1))
        parts += place(rcs, rot_z=a)
    # Four big swept fins (rust) on the diagonals; the rocket stands on them.
    fin_outline = [(1.85, 10.2), (1.85, 1.9), (3.6, 0.55), (4.95, 0.0), (5.35, 0.0), (5.25, 1.3), (3.15, 6.7)]
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        fin = prism(f"Fin{i}", fin_outline, 0.4, (0, 0, 0), m=rust, bevel=0.1, segs=2)
        fin.rotation_euler = (0, 0, 0)
        fin.matrix_world = Matrix.Rotation(math.pi / 2, 4, "Z") @ fin.matrix_basis
        cap = prism(f"FinCap{i}", [(4.95, 0.0), (5.35, 0.0), (5.25, 1.3), (4.95, 1.25)], 0.46, m=hull, bevel=0.06)
        cap.matrix_world = Matrix.Rotation(math.pi / 2, 4, "Z") @ cap.matrix_basis
        stripe = prism(f"FinStripe{i}", [(2.3, 7.2), (2.3, 6.4), (3.55, 4.2), (3.85, 4.6)], 0.46, m=hull, bevel=0.04)
        stripe.matrix_world = Matrix.Rotation(math.pi / 2, 4, "Z") @ stripe.matrix_basis
        pod = sphere(f"FinPod{i}", 0.42, (0, 4.95, 0.65), scale=(1, 1, 2.0), m=rdark, segs=12, rings=8)
        parts += place([fin, cap, stripe, pod], rot_z=a - math.pi / 2)
    # Engines: one big bell and four small ones.
    def bell(prefix, r_top, r_bottom, z_top, z_bottom, x=0.0, y=0.0):
        out = [lathe(prefix, [(r_bottom, z_bottom), (r_bottom * 0.92, z_bottom + (z_top - z_bottom) * 0.35), (r_top, z_top)],
                     m=sdark, segs=24, loc=(x, y, 0), cap=False),
               lathe(prefix + "In", [(r_top * 0.82, z_top - 0.02), (r_bottom * 0.88, z_bottom + 0.06)], m=burn, segs=24,
                     loc=(x, y, 0), cap=False),
               cyl(prefix + "Ring", r_bottom * 1.02, 0.09, (x, y, z_bottom + 0.05), segs=24, bevel=0.02, m=copper),
               cyl(prefix + "Neck", r_top * 1.05, 0.3, (x, y, z_top + 0.1), segs=20, bevel=0.03, m=steel)]
        return out
    parts += bell("BellMain", 0.6, 1.08, 1.3, 0.35)
    for i in range(4):
        a = math.tau * i / 4
        parts += bell(f"Bell{i}", 0.3, 0.5, 1.35, 0.55, math.cos(a) * 1.55, math.sin(a) * 1.55)
    # Canards near the cabin.
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        c = prism(f"Canard{i}", [(1.9, 21.0), (1.9, 19.9), (2.75, 19.6), (2.7, 20.1)], 0.18, m=rust, bevel=0.05)
        c.matrix_world = Matrix.Rotation(math.pi / 2, 4, "Z") @ c.matrix_basis
        parts += place([c], rot_z=a - math.pi / 2)
    save("dune_rocket", [merge("Rocket", parts)])


# ---------------------------------------------------------------------------
# Gantry
# ---------------------------------------------------------------------------

G_HALF = 2.2
G_HEIGHT = 33.0
G_LEVEL = 3.0
ARM_REACH = 3.75     # from the tower's +X face to the rocket skin


def build_gantry():
    reset_scene()
    rust, rdark = dmat("Rust", rough=0.55), dmat("RustDark", rough=0.6)
    yellow, dark = dmat("Hazard", rough=0.5), dmat("HazardDark", rough=0.6)
    hull, steel = dmat("Hull", rough=0.45), dmat("Steel", rough=0.4, metal=0.5)
    sdark = dmat("SteelDark", rough=0.45, metal=0.4)
    concrete = dmat("Concrete", rough=0.9)
    hose = dmat("Hose", "#2e2a33", rough=0.7)
    glass = dglow("CabWindow", "#ffd486", 1.4)
    red = dglow("Beacon", "#ff4a3a", 3.0)
    flood = dglow("Flood", "#fff2c8", 2.6)
    h, top = G_HALF, G_HEIGHT
    parts = [box("Footing", (h * 2 + 1.0, h * 2 + 1.0, 0.5), (0, 0, 0.25), bevel=0.08, m=concrete)]
    parts += hazard_band("FootStripeF", h * 2 + 0.9, 0.3, (0, -h - 0.52, 0.25))
    corners = [(-h, -h), (h, -h), (h, h), (-h, h)]
    for i, (x, y) in enumerate(corners):
        parts.append(box(f"Column{i}", (0.42, 0.42, top), (x, y, top / 2 + 0.5), bevel=0.05, m=rust))
        parts.append(box(f"ColumnFoot{i}", (0.8, 0.8, 0.4), (x, y, 0.7), bevel=0.06, m=rdark))
    levels = int(top / G_LEVEL)
    for k in range(levels + 1):
        z = 0.5 + k * G_LEVEL
        for i in range(4):
            a, b = corners[i], corners[(i + 1) % 4]
            parts.append(beam(f"Girder{k:02d}_{i}", (a[0], a[1], z), (b[0], b[1], z), 0.26, m=rust))
            if k < levels:
                # X bracing on each face.
                parts.append(beam(f"BraceA{k:02d}_{i}", (a[0], a[1], z), (b[0], b[1], z + G_LEVEL), 0.12, m=rdark))
                parts.append(beam(f"BraceB{k:02d}_{i}", (b[0], b[1], z), (a[0], a[1], z + G_LEVEL), 0.12, m=rdark))
    # Work platforms with yellow rails, and the arms that reach the rocket.
    for idx, z in enumerate((12.5, 18.5, 24.5)):
        parts.append(fbox(f"Deck{idx}", (h * 2 + 1.6, h * 2 + 1.6, 0.16), (0, 0, z), m=sdark))
        for side, (dx, dy, ln, rot) in enumerate(((0, -h - 0.8, h * 2 + 1.6, 0), (0, h + 0.8, h * 2 + 1.6, 0), (-h - 0.8, 0, h * 2 + 1.6, 90))):
            rail = [fbox(f"Rail{idx}_{side}T", (ln, 0.08, 0.08), (0, 0, 1.05), m=yellow),
                    fbox(f"Rail{idx}_{side}M", (ln, 0.06, 0.06), (0, 0, 0.55), m=yellow)]
            for p in range(5):
                rail.append(fbox(f"Rail{idx}_{side}P{p}", (0.07, 0.07, 1.05), (-ln / 2 + ln * p / 4, 0, 0.53), m=yellow))
            parts += place(rail, (dx, dy, z), math.radians(rot))
    # Crew access arm with its white room at cabin height.
    za = 18.5
    x0, x1 = h, h + ARM_REACH
    arm = [fbox("ArmFloor", (ARM_REACH, 1.6, 0.18), ((x0 + x1) / 2, 0, za), m=sdark)]
    for s in (-1, 1):
        arm.append(beam(f"ArmTruss{s}", (x0, s * 0.8, za + 0.1), (x1 - 1.4, s * 0.8, za + 0.1), 0.18, m=rust))
        arm.append(beam(f"ArmTop{s}", (x0, s * 0.8, za + 2.4), (x1 - 1.4, s * 0.8, za + 2.4), 0.16, m=rust))
        for p in range(3):
            xa = x0 + p * (ARM_REACH - 1.4) / 3
            arm.append(beam(f"ArmDiag{s}{p}", (xa, s * 0.8, za + 0.1), (xa + (ARM_REACH - 1.4) / 3, s * 0.8, za + 2.4), 0.1, m=rdark))
    arm += [box("WhiteRoom", (1.6, 2.0, 2.5), (x1 - 0.75, 0, za + 1.3), bevel=0.12, m=hull),
            box("WhiteRoomBand", (1.64, 2.04, 0.3), (x1 - 0.75, 0, za + 2.3), bevel=0.06, m=dmat("Teal", rough=0.45)),
            fbox("WhiteRoomWin", (0.9, 0.08, 0.6), (x1 - 0.75, -1.02, za + 1.6), m=glass),
            fbox("WhiteRoomWinB", (0.9, 0.08, 0.6), (x1 - 0.75, 1.02, za + 1.6), m=glass)]
    parts += arm
    # Umbilical arms: trusses with drooping hoses down to the hull.
    for idx, z in enumerate((9.5, 24.5)):
        reach = ARM_REACH - (0.0 if idx == 0 else 0.25)
        um = [beam(f"Umb{idx}Low", (h, 0, z), (h + reach - 0.4, 0, z), 0.3, m=rust),
              beam(f"Umb{idx}High", (h, 0, z + 1.4), (h + reach - 0.8, 0, z + 0.9), 0.24, m=rust),
              beam(f"Umb{idx}Tie", (h + reach - 0.8, 0, z + 0.9), (h + reach - 0.4, 0, z), 0.16, m=rdark),
              box(f"Umb{idx}Plate", (0.3, 1.0, 0.9), (h + reach - 0.12, 0, z + 0.2), bevel=0.06, m=sdark)]
        for k, dy in enumerate((-0.32, 0.0, 0.32)):
            pts = []
            for s in range(9):
                t = s / 8
                pts.append((h + 0.2 + (reach - 0.5) * t, dy, z - 0.25 - 0.9 * math.sin(math.pi * t)))
            um.append(tube(f"Umb{idx}Hose{k}", pts, 0.08, m=hose, segs=8))
        parts += um
    # Lift cage on the -X face and stair flights on the front.
    parts.append(fbox("LiftShaftA", (0.12, 1.6, top - 1.0), (-h - 0.9, -0.8, top / 2), m=yellow))
    parts.append(fbox("LiftShaftB", (0.12, 1.6, top - 1.0), (-h - 0.9, 0.8, top / 2), m=yellow))
    parts.append(box("LiftCar", (1.5, 1.5, 2.3), (-h - 0.85, 0, 7.4), bevel=0.08, m=dmat("Teal", rough=0.45)))
    parts.append(fbox("LiftCarWin", (0.08, 0.9, 0.7), (-h - 1.62, 0, 7.9), m=glass))
    for f in range(9):
        z0 = 0.5 + f * G_LEVEL
        sx = -1 if f % 2 else 1
        parts.append(beam(f"Stair{f}", (-sx * (h - 0.5), -h - 0.55, z0 + 0.15), (sx * (h - 0.5), -h - 0.55, z0 + G_LEVEL), 0.7, 0.12, m=sdark))
        parts.append(beam(f"StairRail{f}", (-sx * (h - 0.5), -h - 0.92, z0 + 1.1), (sx * (h - 0.5), -h - 0.92, z0 + G_LEVEL + 0.95), 0.06, m=yellow))
    # Hammerhead crane on top, lightning mast and lights.
    parts.append(fbox("TopDeck", (h * 2 + 0.6, h * 2 + 0.6, 0.3), (0, 0, top + 0.6), m=rdark))
    parts.append(beam("CraneBoom", (-h - 1.5, 0, top + 2.4), (h + 4.5, 0, top + 2.4), 0.55, 0.7, m=rust))
    parts.append(beam("CraneKing", (0, 0, top + 0.6), (0, 0, top + 4.2), 0.5, m=rust))
    parts.append(beam("CraneStayA", (0, 0, top + 4.2), (h + 4.3, 0, top + 2.6), 0.08, m=steel))
    parts.append(beam("CraneStayB", (0, 0, top + 4.2), (-h - 1.4, 0, top + 2.6), 0.08, m=steel))
    parts.append(box("CraneCounter", (1.2, 1.0, 1.0), (-h - 1.2, 0, top + 1.8), bevel=0.08, m=concrete))
    parts.append(box("CraneTrolley", (0.8, 0.9, 0.5), (h + 3.4, 0, top + 1.95), bevel=0.06, m=yellow))
    parts.append(beam("CraneHook", (h + 3.4, 0, top + 1.7), (h + 3.4, 0, top - 2.5), 0.05, m=steel))
    parts.append(box("CraneHookBlock", (0.4, 0.3, 0.5), (h + 3.4, 0, top - 2.7), bevel=0.06, m=yellow))
    parts.append(cyl("Mast", 0.12, 6.0, (-h + 0.3, h - 0.3, top + 3.8), segs=8, bevel=0.0, m=steel))
    for i, (x, y, z) in enumerate(((-h + 0.3, h - 0.3, top + 6.9), (h + 4.5, 0, top + 2.95), (-h, -h, top + 1.0), (h, -h, top + 1.0))):
        parts.append(bulb(f"BeaconBulb{i}", 0.2, (x, y, z), red))
    for i, z in enumerate((12.9, 24.9)):
        parts.append(box(f"FloodHousing{i}", (0.7, 0.4, 0.5), (h + 0.3, -h - 0.4, z + 0.5), bevel=0.06, m=sdark))
        parts.append(fbox(f"FloodLens{i}", (0.56, 0.08, 0.38), (h + 0.3, -h - 0.62, z + 0.5), m=flood))
    # Stencil on the footing.
    parts.append(text("FootText", "LP-9", 0.42, 0.04, (0, -h - 0.55, 0.62), m=dark))
    save("dune_gantry", [merge("Gantry", parts)])


# ---------------------------------------------------------------------------
# Launch mount and ramp
# ---------------------------------------------------------------------------

MOUNT_W, MOUNT_D = 20.0, 14.0


def build_launch_mount():
    reset_scene()
    conc, cdark, clight = dmat("Concrete", rough=0.9), dmat("ConcreteDark", rough=0.92), dmat("ConcreteLight", rough=0.9)
    steel, sdark = dmat("Steel", rough=0.4, metal=0.5), dmat("SteelDark", rough=0.45, metal=0.4)
    rust, rdark = dmat("Rust", rough=0.55), dmat("RustDark", rough=0.6)
    yellow, dark = dmat("Hazard", rough=0.5), dmat("HazardDark", rough=0.6)
    teal = dmat("Teal", rough=0.45)
    soot = dmat("Soot", "#3a3034", rough=0.95)
    pipe_w, pipe_b = dmat("PipeWhite", "#e9e4da", rough=0.5), dmat("PipeBlue", "#3c78b8", rough=0.5)
    vent = dglow("VentGlow", "#ff8a3a", 0.9)
    W, D, H = MOUNT_W, MOUNT_D, DECK_H
    parts = [
        box("Plinth", (W, D, H - 0.3), (0, 0, (H - 0.3) / 2), bevel=0.12, segs=2, m=conc),
        box("Cap", (W + 0.3, D + 0.3, 0.32), (0, 0, H - 0.16), bevel=0.08, m=clight),
        box("Skirt", (W + 0.4, D + 0.4, 0.35), (0, 0, 0.175), bevel=0.08, m=cdark),
        fbox("DeckPlate", (W - 0.6, D - 0.6, 0.04), (0, 0, H + 0.01), m=dmat("DeckSteel", "#a2a4a6", rough=0.55, metal=0.3)),
    ]
    # Deck panel seams.
    for i in range(1, 10):
        parts.append(fbox(f"SeamX{i}", (0.05, D - 0.6, 0.02), (-W / 2 + 0.3 + i * (W - 0.6) / 10, 0, H + 0.035), m=sdark))
    for i in range(1, 7):
        parts.append(fbox(f"SeamY{i}", (W - 0.6, 0.05, 0.02), (0, -D / 2 + 0.3 + i * (D - 0.6) / 7, H + 0.035), m=sdark))
    # Hazard stripes along the deck edge and down the front corners.
    for side, (x, y, ln, rot) in enumerate(((0, -D / 2 - 0.17, W + 0.3, 0), (0, D / 2 + 0.17, W + 0.3, 180),
                                             (-W / 2 - 0.17, 0, D + 0.3, -90), (W / 2 + 0.17, 0, D + 0.3, 90))):
        parts += hazard_band(f"Edge{side}", ln, 0.3, (x, y, H - 0.16), math.radians(rot), stripe=0.45)
    # Flame-trench mouths on the east and west faces (sooty openings).
    for s in (-1, 1):
        x = s * (W / 2 + 0.02)
        parts.append(fbox(f"TrenchMouth{s}", (0.1, 5.0, 1.2), (x, 0, 0.95), m=dmat("TrenchDark", "#1e1820", rough=1.0)))
        parts.append(box(f"TrenchFrame{s}T", (0.4, 5.6, 0.3), (x, 0, 1.68), bevel=0.06, m=sdark))
        for k in (-1, 1):
            parts.append(box(f"TrenchFrame{s}{k}", (0.4, 0.3, 1.5), (x, k * 2.65, 0.9), bevel=0.06, m=sdark))
        parts.append(sphere(f"Soot{s}", 2.6, (x, 0, 1.4), scale=(0.08, 1.4, 0.9), m=soot, segs=16, rings=8))
    # Stencil and big pad number on the front (south) face.
    parts.append(text("FaceText", "LAUNCH PAD 9", 0.62, 0.06, (-3.2, -D / 2 - 0.04, 0.95), m=dark))
    parts.append(box("FacePlate", (2.2, 0.08, 1.1), (5.6, -D / 2 - 0.02, 0.95), bevel=0.04, m=rust))
    parts.append(text("FaceNum", "09", 0.8, 0.05, (5.6, -D / 2 - 0.08, 0.95), m=dmat("Hull", rough=0.45)))
    # Pipe runs along the back and the west face, with valves and supports.
    for k, (m, z) in enumerate(((pipe_w, 0.55), (pipe_b, 0.95))):
        parts.append(rod(f"PipeBack{k}", (-W / 2 + 1.0, D / 2 + 0.45, z), (W / 2 - 1.0, D / 2 + 0.45, z), 0.17, m=m, segs=12))
        parts.append(rod(f"PipeWest{k}", (-W / 2 - 0.45, D / 2 - 1.0, z), (-W / 2 - 0.45, -D / 2 + 3.0, z), 0.17, m=m, segs=12))
    for i in range(6):
        x = -W / 2 + 2.0 + i * (W - 4.0) / 5
        parts.append(box(f"PipeStand{i}", (0.3, 0.5, 1.15), (x, D / 2 + 0.45, 0.58), bevel=0.04, m=sdark))
    for i, (x, y) in enumerate(((-3.5, D / 2 + 0.75), (4.5, D / 2 + 0.75))):
        parts.append(cyl(f"Valve{i}", 0.26, 0.08, (x, y, 1.35), rot=(math.pi / 2, 0, 0), segs=14, bevel=0.02, m=dmat("Red", rough=0.5)))
        parts.append(cyl(f"ValveStem{i}", 0.06, 0.4, (x, y - 0.1, 1.15), segs=8, bevel=0.0, m=steel))
    # Steel launch table: thick plate, flame hole, hold-down clamps on the fin diagonals.
    tz = H + 0.02
    parts.append(box("Table", (8.4, 8.4, 0.5), (0, 0, tz + 0.25), bevel=0.12, m=sdark))
    parts.append(box("TableTop", (8.0, 8.0, 0.12), (0, 0, tz + 0.53), bevel=0.04, m=steel))
    parts.append(cyl("FlameHole", 2.6, 0.06, (0, 0, tz + 0.6), segs=32, bevel=0.0, m=dmat("TrenchDark", "#1e1820", rough=1.0)))
    parts.append(cyl("FlameHoleRim", 2.8, 0.1, (0, 0, tz + 0.58), segs=32, bevel=0.03, m=rdark))
    parts += hazard_band("TableEdgeF", 8.4, 0.34, (0, -4.22, tz + 0.27), 0.0, stripe=0.4)
    parts += hazard_band("TableEdgeB", 8.4, 0.34, (0, 4.22, tz + 0.27), math.pi, stripe=0.4)
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        clamp = [box(f"Clamp{i}", (0.9, 1.2, 0.7), (5.1, 0, tz + 0.9), bevel=0.1, m=rust),
                 box(f"ClampJaw{i}", (0.4, 0.9, 0.5), (4.6, 0, tz + 1.05), bevel=0.06, m=rdark),
                 box(f"ClampBase{i}", (1.4, 1.6, 0.3), (5.1, 0, tz + 0.7), bevel=0.06, m=sdark)]
        parts += place(clamp, rot_z=a)
    # Tail service masts beside the table (east side), with vents that glow faintly.
    for k, y in enumerate((-2.6, 2.6)):
        parts.append(box(f"TsmBody{k}", (1.0, 1.0, 3.2), (5.2, y, tz + 1.6), bevel=0.1, m=teal))
        parts.append(box(f"TsmCap{k}", (1.2, 1.2, 0.3), (5.2, y, tz + 3.35), bevel=0.08, m=rust))
        parts.append(fbox(f"TsmVent{k}", (0.08, 0.6, 0.3), (4.68, y, tz + 2.6), m=vent))
    # Vent grilles in the deck (vapour rises from these in the level).
    for i, (x, y) in enumerate(((-4.6, -5.4), (4.6, 5.4), (6.8, -5.3), (-6.6, 5.3))):
        parts.append(fbox(f"Grille{i}", (1.4, 0.9, 0.05), (x, y, H + 0.04), m=sdark))
        for b in range(5):
            parts.append(fbox(f"Grille{i}Bar{b}", (1.3, 0.06, 0.03), (x, y - 0.36 + b * 0.18, H + 0.08), m=steel))
    save("dune_launch_mount", [merge("LaunchMount", parts)])


def build_rail():
    """3 m safety rail along X: one post per module so runs tile."""
    reset_scene()
    yellow, sdark = dmat("Hazard", rough=0.5), dmat("SteelDark", rough=0.45, metal=0.4)
    parts = [box("Post", (0.12, 0.12, 1.1), (0, 0, 0.55), bevel=0.03, m=yellow),
             box("PostFoot", (0.26, 0.26, 0.08), (0, 0, 0.04), bevel=0.02, m=sdark),
             box("Top", (3.0, 0.1, 0.1), (0, 0, 1.08), bevel=0.03, m=yellow),
             box("Mid", (3.0, 0.07, 0.07), (0, 0, 0.6), bevel=0.02, m=yellow),
             box("Kick", (3.0, 0.05, 0.16), (0, 0, 0.1), bevel=0.01, m=sdark)]
    save("dune_rail", [merge("Rail", parts)])


def build_ramp():
    """Steel ramp, 4 m wide, 8 m long, 2 m rise; the high end over the origin, descending toward -Y."""
    reset_scene()
    sdark, steel = dmat("SteelDark", rough=0.45, metal=0.4), dmat("Steel", rough=0.4, metal=0.5)
    yellow, dark = dmat("Hazard", rough=0.5), dmat("HazardDark", rough=0.6)
    plate = dmat("DeckSteel", "#a2a4a6", rough=0.55, metal=0.3)
    run, rise, w = 8.0, DECK_H, 4.0
    slope = math.atan2(rise, run)
    length = math.hypot(run, rise)
    parts = []
    deck = [box("Surface", (w, length, 0.24), (0, 0, -0.12), bevel=0.04, m=plate)]
    for i in range(14):
        deck.append(fbox(f"Tread{i}", (w - 0.5, 0.08, 0.05), (0, -length / 2 + 0.4 + i * (length - 0.8) / 13, 0.02), m=sdark))
    deck += [fbox("EdgeL", (0.2, length, 0.08), (-w / 2 + 0.1, 0, 0.03), m=yellow),
             fbox("EdgeR", (0.2, length, 0.08), (w / 2 - 0.1, 0, 0.03), m=yellow)]
    for s in (-1, 1):
        x = s * (w / 2 - 0.1)
        deck.append(fbox(f"HandTop{s}", (0.08, length, 0.08), (x, 0, 1.05), m=yellow))
        deck.append(fbox(f"HandMid{s}", (0.06, length, 0.06), (x, 0, 0.55), m=yellow))
        for p in range(5):
            deck.append(fbox(f"Post{s}{p}", (0.08, 0.08, 1.05), (x, -length / 2 + 0.3 + p * (length - 0.6) / 4, 0.52), m=yellow))
    for ob in deck:
        ob.matrix_world = Matrix.Translation((0, -run / 2, rise / 2)) @ Matrix.Rotation(slope, 4, "X") @ ob.matrix_basis
    parts += deck
    # Side skirts (solid triangles) and a stencilled arrow.
    for s in (-1, 1):
        tri = prism(f"Skirt{s}", [(-run, 0.0), (0.0, 0.0), (0.0, rise - 0.05)], 0.16, m=sdark)
        tri.matrix_world = Matrix.Translation((s * (w / 2 - 0.08), 0, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z") @ tri.matrix_basis
        parts.append(make_flat(tri))
        parts += hazard_band(f"SkirtStripe{s}", run * 0.6, 0.28, (s * (w / 2), -run * 0.65, 0.2), math.radians(90 * s), stripe=0.4)
    save("dune_ramp", [merge("Ramp", parts)])


if __name__ == "__main__":
    which = sys.argv[1:] or ["rocket", "gantry", "launch_mount", "ramp", "rail"]
    for key in which:
        globals()["build_" + key]()
