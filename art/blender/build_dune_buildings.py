"""Dune Spaceport buildings: the zombie entrances and the skyline around the pad.

    dune_hangar_a.glb / dune_hangar_b.glb
                           barrel-roof hangar, 18 x 22 m, front opening 12 x 7 m, lettered A / B,
                           with the parked shuttle and workshop racks inside.
    dune_hangar_door_l.glb / dune_hangar_door_r.glb
                           its sliding door panels (6.2 x 7 m, origin at the bottom centre);
                           closed, they sit at x = -3 / +3 on the door track (local z = 11.75).
    dune_tower.glb         control tower, ~26 m, glass cab. Nodes: Tower, Radar (spins).
    dune_gatehouse.glb     security gate: booth, canopy, raised boom, sign gantry (10 m road).
    dune_cargo_lift.glb    freight lift: 6 x 6 m platform in a yellow frame with pulleys.
    dune_tunnel.glb        maintenance tunnel portal set into a sand berm (5 m opening).
    dune_blast_wall.glb    4 m blast-wall module running along X (arena boundary).

Front faces -Y (Godot +Z). Origins at the centre of the base unless noted.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dune_kit import *  # noqa: F401,F403

# Hangar arch: chord 18 m from wall tops at 6 m, peak at 10 m.
H_W, H_D, H_WALL, H_PEAK = 18.0, 22.0, 6.0, 10.0
DOOR_W, DOOR_H = 12.0, 7.0


def _arch(radius_extra=0.0, steps=20):
    c = H_W / 2
    s = H_PEAK - H_WALL
    r = (c * c + s * s) / (2 * s)
    zc = H_PEAK - r
    a0 = math.asin((H_WALL - zc) / r)
    pts = []
    for i in range(steps + 1):
        a = a0 + (math.pi - 2 * a0) * i / steps
        pts.append((math.cos(a) * (r + radius_extra), zc + math.sin(a) * (r + radius_extra)))
    return pts   # right to left


def build_hangar():
    """Both hangar shells (lettered A and B) and their shared sliding doors."""
    reset_scene()
    shells = {"dune_hangar_" + letter.lower(): [_hangar_shell(letter)] for letter in ("A", "B")}
    # Sliding door panels: corrugated rust with a hazard edge and a stencil.
    doors = {}
    for name, s in (("DoorL", -1), ("DoorR", 1)):
        dp = corrugated(name + "C", DOOR_W / 2 + 0.2, DOOR_H - 0.1, (0, 0, 0.05), 0.0, pitch=0.42, depth=0.16,
                        m=dmat("DoorRust", "#c45a32", rough=0.6), m_rib=dmat("DoorRustDark", "#a8452a", rough=0.6))
        dp += hazard_band(name + "Edge", 0.5, DOOR_H - 0.3, (-s * (DOOR_W / 4 - 0.1), -0.16, DOOR_H / 2), 0.0, stripe=0.25, slant=0.06)
        dp.append(box(name + "Rail", (DOOR_W / 2 + 0.3, 0.24, 0.3), (0, -0.05, 0.2), bevel=0.06, m=dmat("SteelDark", rough=0.45, metal=0.4)))
        dp.append(box(name + "Bar", (DOOR_W / 2 + 0.2, 0.2, 0.22), (0, -0.14, 3.2), bevel=0.05, m=dmat("RustDark", rough=0.6)))
        dp.append(text(name + "Num", "LP9", 1.1, 0.06, (s * 0.6, -0.2, 4.8), m=dmat("Hull", rough=0.45)))
        doors["dune_hangar_door_" + ("l" if s < 0 else "r")] = [merge(name, dp)]
    save_split("dune_hangar", {**shells, **doors})


def _hangar_shell(letter):
    """One hangar shell, its gable roundel and name board lettered `letter`, with
    the workshop inside (see _hangar_interior)."""
    wall, wall_dk = dmat("HangarWall", "#ead8b6", rough=0.75), dmat("HangarWallDark", "#c9b48f", rough=0.8)
    roof, rib = dmat("HangarRoof", "#2b8f88", rough=0.6), dmat("HangarRib", "#1e6764", rough=0.6)
    rust, rdark = dmat("Rust", rough=0.55), dmat("RustDark", rough=0.6)
    inside = dmat("HangarLiner", "#5b4a52", rough=0.95)
    sdark = dmat("SteelDark", rough=0.45, metal=0.4)
    steel = dmat("Steel", rough=0.4, metal=0.5)
    glass = dglow("HangarWindow", "#ffcf7a", 1.3)
    lamp = dglow("HangarLamp", "#fff0c0", 2.4)
    white = dmat("Hull", rough=0.45)
    parts = []
    hw, hd = H_W / 2, H_D / 2
    arch_out = _arch(0.0)
    arch_in = _arch(-0.35)
    # Side and back walls (thick), roof shell extruded along the depth.
    for s in (-1, 1):
        parts += corrugated(f"Side{s}", H_D, H_WALL, (s * hw, 0, 0), math.radians(90 * s), pitch=0.5, depth=0.25, m=wall, m_rib=wall_dk)
        parts.append(fbox(f"SideLiner{s}", (0.1, H_D - 0.6, H_WALL), (s * (hw - 0.3), 0, H_WALL / 2), m=inside))
        parts.append(box(f"SideBase{s}", (0.6, H_D + 0.2, 0.6), (s * hw, 0, 0.3), bevel=0.08, m=rdark))
        parts += window_strip(f"Clere{s}", 6, 3.2, (2.2, 0.9), (s * (hw + 0.36), 0, 4.7), math.radians(90 * s), m_frame=rust, m_glass=glass)
        # The clerestory glows on the inside too.
        parts += window_strip(f"ClereIn{s}", 6, 3.2, (2.2, 0.9), (s * (hw - 0.4), 0, 4.7), math.radians(90 * s + 180), m_frame=rust, m_glass=glass)
    back_outline = [(-hw, 0.0), (hw, 0.0)] + arch_out
    parts.append(make_flat(prism("BackWall", back_outline, 0.4, (0, hd, 0), m=wall)))
    parts.append(make_flat(prism("BackLiner", [(-hw + 0.4, 0.0), (hw - 0.4, 0.0)] + _arch(-0.6), 0.1, (0, hd - 0.3, 0), m=inside)))
    shell = arch_out + list(reversed(arch_in))
    parts.append(make_flat(prism("RoofShell", shell, H_D + 0.6, m=roof)))
    parts.append(make_flat(prism("RoofLiner", _arch(-0.36) + list(reversed(_arch(-0.45))), H_D - 0.4, m=inside)))
    for i in range(9):
        y = -hd + 0.2 + i * (H_D - 0.4) / 8
        parts.append(make_flat(prism(f"Rib{i}", _arch(0.18) + list(reversed(_arch(-0.02))), 0.45, (0, y, 0), m=rib)))
        # Steel roof truss inside, under each outer rib.
        parts.append(make_flat(prism(f"Truss{i}", _arch(-0.45) + list(reversed(_arch(-0.75))), 0.3, (0, y, 0), m=sdark)))
    # Roof vents along the ridge.
    for i in range(3):
        y = -6 + i * 6
        parts.append(box(f"RoofVent{i}", (1.4, 1.6, 0.9), (0, y, H_PEAK + 0.35), bevel=0.12, m=steel))
        parts.append(box(f"RoofVentCap{i}", (1.8, 2.0, 0.2), (0, y, H_PEAK + 0.9), bevel=0.06, m=sdark))
    # Front facade: an arched gable with the door opening cut out.
    facade = [(-hw, 0.0), (-DOOR_W / 2, 0.0), (-DOOR_W / 2, DOOR_H), (DOOR_W / 2, DOOR_H), (DOOR_W / 2, 0.0), (hw, 0.0)] + arch_out
    parts.append(make_flat(prism("Facade", facade, 0.5, (0, -hd, 0), m=wall)))
    parts.append(make_flat(prism("FacadeLiner", [(-DOOR_W / 2 - 0.1, DOOR_H - 0.2), (DOOR_W / 2 + 0.1, DOOR_H - 0.2)] + _arch(-0.6, 16)[3:-3], 0.1, (0, -hd + 0.35, 0), m=inside)))
    parts.append(box("Lintel", (DOOR_W + 1.0, 0.7, 0.6), (0, -hd - 0.15, DOOR_H + 0.3), bevel=0.1, m=rust))
    parts.append(box("DoorTrack", (DOOR_W * 2 - 2.0, 0.35, 0.35), (0, -hd - 0.6, DOOR_H + 0.15), bevel=0.06, m=sdark))
    for s in (-1, 1):
        parts.append(box(f"Pier{s}", (0.8, 0.9, DOOR_H), (s * (DOOR_W / 2 + 0.4), -hd - 0.1, DOOR_H / 2), bevel=0.1, m=rust))
        parts += hazard_band(f"PierStripe{s}", 0.8, 1.6, (s * (DOOR_W / 2 + 0.4), -hd - 0.56, 0.8), 0.0, stripe=0.25)
        parts.append(box(f"Flood{s}", (0.6, 0.7, 0.45), (s * (DOOR_W / 2 + 0.4), -hd - 0.85, DOOR_H - 0.7), bevel=0.08, m=sdark))
        parts.append(fbox(f"FloodLens{s}", (0.46, 0.06, 0.3), (s * (DOOR_W / 2 + 0.4), -hd - 1.22, DOOR_H - 0.75), m=lamp))
        parts.append(rod(f"Downpipe{s}", (s * (hw - 0.4), -hd - 0.35, 0.2), (s * (hw - 0.4), -hd - 0.35, H_WALL + 0.4), 0.12, m=rdark))
    # Big letter roundel and name board on the gable.
    parts.append(cyl("Roundel", 1.25, 0.14, (0, -hd - 0.3, 8.75), rot=(math.pi / 2, 0, 0), segs=28, bevel=0.05, m=rust))
    parts.append(cyl("RoundelIn", 1.0, 0.16, (0, -hd - 0.33, 8.75), rot=(math.pi / 2, 0, 0), segs=28, bevel=0.04, m=white))
    parts.append(text("RoundelLetter", letter, 1.3, 0.12, (0, -hd - 0.43, 8.72), m=rust))
    parts.append(box("NameBoard", (5.6, 0.2, 0.8), (-5.2, -hd - 0.3, 6.3 + 1.75), bevel=0.05, m=dmat("Navy", rough=0.5)))
    parts.append(text("NameText", "HANGAR " + letter, 0.55, 0.06, (-5.2, -hd - 0.43, 8.05), m=white))
    parts += _hangar_interior(letter)
    return merge("Hangar" + letter, parts)


def _hangar_interior(letter):
    """Workshop floor, hanging lamps, the parked shuttle (nose to the doors) and
    the racks along the walls. The shuttle and its wings sit inside the level's
    colliders; the racks hug the walls, clear of the zombies' path to the door."""
    floor = dmat("HangarFloor", "#6a5a56", rough=0.95)
    lamp = dglow("HangarLamp", "#fff0c0", 2.4)
    white, teal, rust = dmat("Hull", rough=0.45), dmat("Teal", rough=0.45), dmat("Rust", rough=0.55)
    steel, sdark, navy = dmat("Steel", rough=0.4, metal=0.5), dmat("SteelDark", rough=0.45, metal=0.4), dmat("Navy", rough=0.5)
    canopy = dmat("ShuttleCanopy", "#1d2a44", rough=0.15, metal=0.3)
    yellow, red = dmat("Hazard"), dmat("Red", rough=0.5)
    crate = dmat("CrateTan", "#c89a5e", rough=0.8)
    hd = H_D / 2
    parts = [fbox("Floor", (H_W - 0.8, H_D - 0.8, 0.05), (0, 0, 0.03), m=floor)]
    # Painted bay round the shuttle and a lead-in line to the doors.
    for name, size, loc in (("BayN", (13.0, 0.18, 0.02), (1.5, -3.6, 0.06)), ("BayS", (13.0, 0.18, 0.02), (1.5, 10.2, 0.06)),
                            ("BayW", (0.18, 13.8, 0.02), (-5.0, 3.3, 0.06)), ("BayE", (0.18, 13.8, 0.02), (8.0, 3.3, 0.06))):
        parts.append(fbox("Paint" + name, size, loc, m=yellow))
    for i in range(4):
        parts.append(fbox(f"Lead{i}", (0.18, 1.2, 0.02), (0, -5.0 - i * 1.8, 0.06), m=yellow))
    parts.append(text("FloorLetter", letter, 2.4, 0.02, (-5.5, -6.5, 0.07), rot=(-math.pi / 2, 0, 0), m=yellow))
    # Hanging lamps.
    for i in range(3):
        for s in (-1, 1):
            parts.append(sphere(f"InLamp{i}{s}", 0.35, (s * 4.0, -6 + i * 6, 8.0), scale=(1, 1, 0.6), m=lamp, segs=10, rings=6))
            parts.append(rod(f"InLampWire{i}{s}", (s * 4.0, -6 + i * 6, 8.2), (s * 4.0, -6 + i * 6, 9.6), 0.03, m=sdark))
    # The shuttle: fuselage on its cradle, swept wings, a tail fin and a dark canopy.
    sx, sz = 1.5, 2.6
    body = lathe("ShuttleBody", [(0.0, -3.4), (2.0, -3.4), (2.2, -3.0), (2.2, 4.0), (1.7, 6.5), (0.9, 8.2), (0.0, 8.8)], m=white, segs=24)
    body.rotation_euler = (math.pi / 2, 0, 0)
    body.location = (sx, 6.5, sz)
    parts.append(body)
    parts.append(lathe("ShuttleStripe", [(2.23, 0.0), (2.23, 0.6)], m=teal, segs=24, loc=(sx, 4.5, sz), rot=(math.pi / 2, 0, 0)))
    parts.append(lathe("ShuttleStripeB", [(2.23, 0.0), (2.23, 0.35)], m=rust, segs=24, loc=(sx, 3.6, sz), rot=(math.pi / 2, 0, 0)))
    parts.append(sphere("ShuttleCanopy", 1.0, (sx, 1.0, sz + 1.55), scale=(1.05, 1.7, 0.5), m=canopy, segs=16, rings=8))
    for s in (-1, 1):
        wing = [(0.0, 0.0), (4.2, 1.6), (4.2, 3.4), (0.0, 5.2)]
        parts.append(make_flat(prism(f"Wing{s}", [(s * x, y) for x, y in wing], 0.28, (sx + s * 1.9, 3.5, sz - 0.9),
                                     rot=(-math.pi / 2, 0, 0), m=white)))
        tip = [(3.9, 1.5), (4.3, 1.6), (4.3, 3.4), (3.9, 3.5)]
        parts.append(make_flat(prism(f"WingTip{s}", [(s * x, y) for x, y in tip], 0.3, (sx + s * 1.9, 3.5, sz - 0.9),
                                     rot=(-math.pi / 2, 0, 0), m=rust)))
    parts.append(make_flat(prism("TailFin", [(0.0, 0.0), (3.2, 0.0), (3.4, 2.8), (2.2, 2.8)], 0.3, (sx, 6.4, sz + 1.9),
                                 rot=(0, 0, math.pi / 2), m=white)))
    parts.append(make_flat(prism("TailFinTip", [(2.2, 2.8), (3.4, 2.8), (3.45, 3.2), (2.15, 3.2)], 0.32, (sx, 6.4, sz + 1.9),
                                 rot=(0, 0, math.pi / 2), m=teal)))
    parts.append(box("ShuttleCart", (3.6, 4.0, 0.8), (sx, 8.5, 0.4), bevel=0.1, m=rust))
    parts.append(box("ShuttleCradle", (3.0, 1.2, 1.0), (sx, 1.6, 0.5), bevel=0.1, m=rust))
    for x in (-1.1, 1.1):
        parts.append(cyl(f"CradleWheel{int(x * 10)}", 0.3, 0.25, (sx + x, 1.6, 0.3), rot=(0, math.pi / 2, 0), segs=12, bevel=0.03, m=sdark))
    # Racks on the back wall either side of the tail, stocked with crates.
    for rx in (-6.0, 6.4):
        parts.append(box(f"RackBack{rx}", (3.2, 0.1, 3.4), (rx, hd - 0.55, 1.7), bevel=0.0, m=sdark))
        for k in range(3):
            z = 0.25 + k * 1.15
            parts.append(box(f"RackShelf{rx}{k}", (3.2, 0.9, 0.08), (rx, hd - 1.0, z), bevel=0.0, m=steel))
            for j in range(2):
                parts.append(box(f"RackCrate{rx}{k}{j}", (1.0, 0.75, 0.7), (rx - 0.8 + j * 1.5, hd - 1.0, z + 0.4), bevel=0.06,
                                 m=crate if (j + k) % 2 else teal))
        for ex in (-1.55, 1.55):
            parts.append(box(f"RackPost{rx}{ex}", (0.1, 0.9, 3.4), (rx + ex, hd - 1.0, 1.7), bevel=0.0, m=yellow))
    # Tool chests, workbenches with pegboards and drums along the side walls.
    for s in (-1, 1):
        x = s * (H_W / 2 - 0.85)
        parts.append(box(f"Chest{s}", (0.9, 1.6, 1.1), (x, 2.0, 0.55), bevel=0.06, m=red))
        for k in range(3):
            parts.append(fbox(f"ChestDrawer{s}{k}", (0.04, 1.4, 0.06), (x - s * 0.46, 2.0, 0.3 + k * 0.3), m=sdark))
        parts.append(box(f"Bench{s}", (0.9, 3.0, 0.12), (x, -1.2, 0.95), bevel=0.03, m=dmat("RustDark", rough=0.6)))
        for k, y in enumerate((-2.5, 0.1)):
            parts.append(box(f"BenchLeg{s}{k}", (0.8, 0.1, 0.9), (x, y, 0.45), bevel=0.0, m=sdark))
        parts.append(box(f"Pegboard{s}", (0.06, 3.0, 1.4), (x + s * 0.4, -1.2, 2.0), bevel=0.0, m=navy))
        for k in range(5):
            parts.append(fbox(f"Tool{s}{k}", (0.05, 0.16, 0.6 - (k % 2) * 0.2), (x + s * 0.35, -2.3 + k * 0.55, 2.0), m=steel))
        parts.append(cyl(f"Drum{s}", 0.35, 1.0, (x + s * 0.1, -4.6, 0.5), segs=14, bevel=0.03, m=teal if s < 0 else rust))
    return parts


def build_tower():
    reset_scene()
    cream, cdark = dmat("TowerCream", "#efe2c6", rough=0.7), dmat("TowerCreamDark", "#cdbb98", rough=0.75)
    teal, rust, rdark = dmat("Teal", rough=0.45), dmat("Rust", rough=0.55), dmat("RustDark", rough=0.6)
    conc = dmat("Concrete", rough=0.9)
    steel, sdark = dmat("Steel", rough=0.4, metal=0.5), dmat("SteelDark", rough=0.45, metal=0.4)
    glass = dmat("CabGlass", "#6fd2e0", rough=0.15, emit=0.7, emit_color="#3ab6c8")
    win = dglow("TowerWindow", "#ffd486", 1.4)
    red = dglow("Beacon", "#ff4a3a", 3.0)
    parts = [
        box("Base", (9.0, 9.0, 4.2), (0, 0, 2.1), bevel=0.2, m=conc),
        box("BaseCap", (9.4, 9.4, 0.4), (0, 0, 4.4), bevel=0.1, m=rust),
        box("Door", (2.0, 0.2, 2.6), (0, -4.55, 1.3), bevel=0.05, m=teal),
        box("DoorCanopy", (3.0, 1.4, 0.2), (0, -5.1, 2.9), bevel=0.06, m=rust),
    ]
    parts += window_strip("BaseWin", 3, 2.4, (1.6, 1.0), (0, -4.56, 3.3), 0.0, m_frame=rdark, m_glass=win)
    parts += window_strip("BaseWinE", 3, 2.6, (1.6, 1.0), (4.56, 0, 3.0), math.radians(90), m_frame=rdark, m_glass=win)
    # Tapered shaft with a teal stripe and slit windows.
    parts.append(lathe("Shaft", [(2.5, 4.4), (2.2, 9.0), (1.9, 19.0), (2.05, 19.6)], m=cream, segs=8))
    parts.append(box("ShaftStripe", (0.6, 0.3, 14.4), (0, -2.15, 11.9), rot=(math.radians(-1.0), 0, 0), bevel=0.08, m=teal))
    for i in range(5):
        z = 7.0 + i * 2.6
        parts.append(fbox(f"Slit{i}", (0.25, 0.2, 1.3), (1.15, -1.8, z), rot=(0, 0, math.radians(22.5)), m=win))
    # Cab: balcony, slanted glass, roof disc, antennas and the radar.
    parts.append(cyl("Balcony", 3.7, 0.35, (0, 0, 19.8), segs=8, bevel=0.08, m=rust))
    parts.append(cyl("BalconyRail", 3.6, 0.08, (0, 0, 20.9), segs=8, bevel=0.0, m=steel))
    for i in range(8):
        a = math.tau * (i + 0.5) / 8
        parts.append(rod(f"BalPost{i}", (math.cos(a) * 3.45, math.sin(a) * 3.45, 20.0), (math.cos(a) * 3.45, math.sin(a) * 3.45, 20.9), 0.05, m=steel))
    parts.append(lathe("CabFloor", [(2.8, 20.0), (2.8, 20.35)], m=cdark, segs=8))
    parts.append(lathe("CabGlass", [(2.75, 20.35), (3.35, 22.9)], m=glass, segs=8, cap=False))
    for i in range(8):
        a = math.tau * i / 8
        parts.append(beam(f"Mullion{i}", (math.cos(a) * 2.8, math.sin(a) * 2.8, 20.35), (math.cos(a) * 3.4, math.sin(a) * 3.4, 22.9), 0.14, m=rdark))
    parts.append(lathe("CabRoof", [(3.9, 22.9), (3.9, 23.3), (2.6, 23.9), (1.0, 24.2)], m=cream, segs=8))
    parts.append(lathe("CabRoofRim", [(3.95, 22.85), (3.95, 23.1)], m=rust, segs=8))
    parts.append(cyl("Mast", 0.1, 5.0, (-1.4, 0.6, 26.5), segs=8, bevel=0.0, m=steel))
    parts.append(cyl("MastB", 0.07, 3.0, (1.6, 0.9, 25.6), segs=8, bevel=0.0, m=steel))
    parts.append(bulb("MastBeacon", 0.22, (-1.4, 0.6, 29.1), red))
    parts.append(bulb("MastBeaconB", 0.16, (1.6, 0.9, 27.2), red))
    parts.append(cyl("RadarPost", 0.25, 1.0, (0, 0, 24.6), segs=10, bevel=0.03, m=sdark))
    tower = merge("Tower", parts)
    radar = [box("RadarBar", (3.6, 0.35, 0.7), (0, 0, 0.45), bevel=0.1, m=dmat("Hull", rough=0.45)),
             box("RadarFace", (3.4, 0.12, 0.5), (0, -0.22, 0.45), bevel=0.04, m=rust),
             cyl("RadarHub", 0.3, 0.4, (0, 0, 0.1), segs=10, bevel=0.04, m=sdark)]
    for ob in radar:
        ob.location.z += 25.1
    radar_ob = merge("Radar", radar, pivot=(0, 0, 25.1))
    save("dune_tower", [tower, radar_ob])


def build_gatehouse():
    reset_scene()
    cream = dmat("TowerCream", "#efe2c6", rough=0.7)
    rust, rdark = dmat("Rust", rough=0.55), dmat("RustDark", rough=0.6)
    teal, conc = dmat("Teal", rough=0.45), dmat("Concrete", rough=0.9)
    white, red = dmat("Hull", rough=0.45), dmat("Red", rough=0.5)
    steel, sdark = dmat("Steel", rough=0.4, metal=0.5), dmat("SteelDark", rough=0.45, metal=0.4)
    win = dglow("TowerWindow", "#ffd486", 1.4)
    signl = dglow("SignLight", "#fff0c8", 1.8)
    navy, dark = dmat("Navy", rough=0.5), dmat("HazardDark", rough=0.6)
    parts = []
    # Booth on the left (-X) of the 10 m road; canopy over the lane.
    bx = -6.6
    parts += [box("BoothBase", (3.4, 3.4, 0.4), (bx, 0, 0.2), bevel=0.06, m=conc),
              box("Booth", (3.0, 3.0, 2.8), (bx, 0, 1.8), bevel=0.15, m=cream),
              box("BoothBand", (3.06, 3.06, 0.35), (bx, 0, 2.3), bevel=0.06, m=teal),
              box("BoothRoof", (3.8, 3.8, 0.3), (bx, 0, 3.35), bevel=0.08, m=rust)]
    for i, (dx, dy, rot) in enumerate(((0, -1.52, 0), (1.52, 0, 90), (0, 1.52, 180))):
        parts += place([box(f"BoothWinF{i}", (2.2, 0.1, 1.0), (0, 0, 0), bevel=0.04, m=rdark),
                        fbox(f"BoothWin{i}", (2.0, 0.12, 0.8), (0, -0.02, 0), m=win)], (bx + dx, dy, 2.6), math.radians(rot))
    # Canopy on four columns over the lane.
    for x in (-5.0, 5.0):
        for y in (-2.5, 2.5):
            parts.append(box(f"Col{x}{y}", (0.45, 0.45, 4.8), (x, y, 2.4), bevel=0.06, m=rdark))
    parts.append(box("Canopy", (11.4, 6.4, 0.5), (0, 0, 5.05), bevel=0.12, m=rust))
    parts.append(box("CanopyFascia", (11.6, 0.3, 0.9), (0, -3.25, 5.0), bevel=0.06, m=cream))
    parts.append(text("CanopyText", "GATE 3  ·  SPACEPORT", 0.55, 0.06, (0, -3.42, 5.0), m=navy))
    for i in range(6):
        parts.append(fbox(f"CanopyLight{i}", (0.9, 0.5, 0.05), (-4.0 + i * 1.6, 0, 4.78), m=signl))
    # Raised boom barrier on the right side of the lane.
    parts.append(box("BoomPost", (0.6, 0.6, 1.2), (4.4, 1.2, 0.6), bevel=0.08, m=sdark))
    parts.append(box("BoomHousing", (0.8, 0.7, 0.6), (4.4, 1.2, 1.35), bevel=0.08, m=dmat("Hazard", rough=0.5)))
    boom = []
    for i in range(8):
        boom.append(box(f"Boom{i}", (0.8, 0.14, 0.14), (-0.4 - i * 0.8, 0, 0), bevel=0.03, m=red if i % 2 == 0 else white))
    for ob in boom:
        ob.matrix_world = Matrix.Translation((4.4, 1.2, 1.55)) @ Matrix.Rotation(math.radians(72), 4, "Y") @ ob.matrix_basis
    parts += boom
    # Jersey barriers lining the lane and the guard's chair.
    for i, x in enumerate((-4.2, 4.2)):
        for k in range(2):
            parts.append(make_flat(prism(f"Jersey{i}{k}", [(-0.35, 0), (0.35, 0), (0.18, 0.3), (0.12, 0.85), (-0.12, 0.85), (-0.18, 0.3)],
                                         2.4, (x, 4.6 + k * 2.5, 0), m=conc)))
    parts += hazard_band("Speed", 9.6, 0.12, (0, -3.0, 0.02), 0.0, depth=0.5, stripe=0.6)
    save("dune_gatehouse", [merge("Gatehouse", parts)])


def build_cargo_lift():
    reset_scene()
    yellow, dark = dmat("Hazard", rough=0.5), dmat("HazardDark", rough=0.6)
    steel, sdark = dmat("Steel", rough=0.4, metal=0.5), dmat("SteelDark", rough=0.45, metal=0.4)
    plate = dmat("DeckSteel", "#a2a4a6", rough=0.55, metal=0.3)
    rust, conc = dmat("Rust", rough=0.55), dmat("Concrete", rough=0.9)
    amber = dglow("LiftAmber", "#ffa12a", 3.0)
    cable = dmat("Hose", "#2e2a33", rough=0.7)
    navy, white = dmat("Navy", rough=0.5), dmat("Hull", rough=0.45)
    S, H = 6.0, 8.5
    parts = [box("Pit", (S + 1.2, S + 1.2, 0.3), (0, 0, 0.15), bevel=0.06, m=conc),
             fbox("Platform", (S - 0.2, S - 0.2, 0.08), (0, 0, 0.31), m=plate)]
    for i in range(6):
        parts.append(fbox(f"PlateSeam{i}", (S - 0.4, 0.05, 0.03), (0, -S / 2 + 0.6 + i * 0.96, 0.36), m=sdark))
    for side, (x, y, rot) in enumerate(((0, -S / 2 - 0.3, 0), (0, S / 2 + 0.3, 180), (-S / 2 - 0.3, 0, -90), (S / 2 + 0.3, 0, 90))):
        parts += hazard_band(f"Border{side}", S + 0.6, 0.6, (x, y, 0.32), math.radians(rot), depth=0.04, stripe=0.4)
        parts[-1].rotation_euler.x = 0
    for i, (x, y) in enumerate(((-S / 2, -S / 2), (S / 2, -S / 2), (S / 2, S / 2), (-S / 2, S / 2))):
        parts.append(box(f"Post{i}", (0.5, 0.5, H), (x * 1.08, y * 1.08, H / 2), bevel=0.06, m=yellow))
        parts.append(box(f"PostFoot{i}", (0.9, 0.9, 0.5), (x * 1.08, y * 1.08, 0.25), bevel=0.06, m=sdark))
        parts.append(bulb(f"Warn{i}", 0.22, (x * 1.08, y * 1.08, H + 0.35), amber))
    for i, (a, b) in enumerate((((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1)))):
        h = S / 2 * 1.08
        parts.append(beam(f"TopBeam{i}", (a[0] * h, a[1] * h, H - 0.3), (b[0] * h, b[1] * h, H - 0.3), 0.45, m=yellow))
        parts.append(beam(f"MidBeam{i}", (a[0] * h, a[1] * h, 4.2), (b[0] * h, b[1] * h, 4.2), 0.2, m=dark))
    parts.append(beam("Crosshead", (-S / 2 * 1.08, 0, H - 0.3), (S / 2 * 1.08, 0, H - 0.3), 0.55, m=sdark))
    for s in (-1, 1):
        parts.append(cyl(f"Pulley{s}", 0.7, 0.3, (s * 1.4, 0, H + 0.2), rot=(math.pi / 2, 0, 0), segs=20, bevel=0.05, m=rust))
        parts.append(rod(f"Cable{s}", (s * 1.4 + s * 0.7, 0, H + 0.2), (s * 2.1, 0, 0.4), 0.05, m=cable))
        parts.append(rod(f"CableB{s}", (s * 1.4 - s * 0.7, 0, H + 0.2), (s * 0.7, 0, 0.4), 0.05, m=cable))
    # Back wall with the lift sign and a control box.
    parts.append(box("BackWall", (S + 1.6, 0.6, H - 1.0), (0, S / 2 + 1.0, (H - 1.0) / 2), bevel=0.1, m=conc))
    parts.append(box("Sign", (3.8, 0.2, 1.0), (0, S / 2 + 0.62, H - 2.2), bevel=0.05, m=navy))
    parts.append(text("SignText", "CARGO 3", 0.62, 0.06, (0, S / 2 + 0.5, H - 2.2), m=white))
    parts.append(box("Control", (0.8, 0.5, 1.2), (S / 2 + 0.6, -S / 2 - 0.9, 1.0), bevel=0.06, m=dmat("Teal", rough=0.45)))
    parts.append(fbox("ControlLight", (0.3, 0.05, 0.2), (S / 2 + 0.6, -S / 2 - 1.17, 1.3), m=amber))
    save("dune_cargo_lift", [merge("CargoLift", parts)])


def build_tunnel():
    """Portal facing -Y; the tunnel floor descends behind it (built by the level)."""
    reset_scene()
    conc, cdark, clight = dmat("Concrete", rough=0.9), dmat("ConcreteDark", rough=0.92), dmat("ConcreteLight", rough=0.9)
    sand, sdk = dmat("Sand", rough=0.95), dmat("SandDark", rough=0.95)
    rust, inside = dmat("Rust", rough=0.55), dmat("Interior", rough=1.0)
    steel, sdark = dmat("Steel", rough=0.4, metal=0.5), dmat("SteelDark", rough=0.45, metal=0.4)
    navy, white = dmat("Navy", rough=0.5), dmat("Hull", rough=0.45)
    lamp = dglow("TunnelLamp", "#ffb24a", 2.4)
    W, OPEN_W, OPEN_H = 11.0, 5.4, 4.2
    arch = [(math.cos(math.pi * i / 12) * OPEN_W / 2, OPEN_H - 1.4 + math.sin(math.pi * i / 12) * 1.4) for i in range(13)]
    # The portal face: two piers and a lintel whose underside is the arch.
    parts = [box("PierL", ((W - OPEN_W) / 2, 1.2, OPEN_H + 3.8), (-(W + OPEN_W) / 4, 0, (OPEN_H + 3.8) / 2 - 3.0), bevel=0.15, m=conc),
             box("PierR", ((W - OPEN_W) / 2, 1.2, OPEN_H + 3.8), ((W + OPEN_W) / 4, 0, (OPEN_H + 3.8) / 2 - 3.0), bevel=0.15, m=conc)]
    lintel = list(arch) + [(-OPEN_W / 2, OPEN_H + 0.8), (OPEN_W / 2, OPEN_H + 0.8)]
    parts.append(make_flat(prism("Lintel", lintel, 1.2, (0, 0, 0), m=conc)))
    parts.append(box("Coping", (W + 0.4, 1.6, 0.5), (0, 0, OPEN_H + 1.05), bevel=0.12, m=clight))
    parts += hazard_band("ArchStripeL", 0.5, OPEN_H + 2.4, (-OPEN_W / 2 - 0.3, -0.62, (OPEN_H - 0.6) / 2 - 1.2), 0.0, stripe=0.3, slant=0.05)
    parts += hazard_band("ArchStripeR", 0.5, OPEN_H + 2.4, (OPEN_W / 2 + 0.3, -0.62, (OPEN_H - 0.6) / 2 - 1.2), 0.0, stripe=0.3, slant=0.05)
    # Rolled-up shutter, the sign and a caged lamp.
    parts.append(cyl("ShutterRoll", 0.45, OPEN_W + 0.4, (0, -0.2, OPEN_H + 0.2), rot=(0, math.pi / 2, 0), segs=16, bevel=0.04, m=steel))
    parts.append(box("SignBoard", (4.4, 0.2, 0.8), (0, -0.7, OPEN_H + 1.75), bevel=0.05, m=navy))
    parts.append(text("SignText", "MAINT 4", 0.58, 0.06, (0, -0.84, OPEN_H + 1.75), m=white))
    for s in (-1, 1):
        parts.append(box(f"LampBox{s}", (0.5, 0.4, 0.4), (s * (OPEN_W / 2 + 1.3), -0.75, OPEN_H - 0.4), bevel=0.05, m=sdark))
        parts.append(sphere(f"Lamp{s}", 0.2, (s * (OPEN_W / 2 + 1.3), -0.95, OPEN_H - 0.45), m=lamp, segs=10, rings=6))
    # Dark tunnel liner behind the opening.
    parts.append(fbox("LinerTop", (OPEN_W + 0.6, 12.0, 0.2), (0, 6.5, OPEN_H - 0.4), m=inside))
    for s in (-1, 1):
        parts.append(fbox(f"LinerSide{s}", (0.2, 12.0, OPEN_H + 3.0), (s * (OPEN_W / 2 + 0.1), 6.5, OPEN_H / 2 - 1.8), m=inside))
    parts.append(fbox("LinerBack", (OPEN_W + 0.6, 0.2, OPEN_H + 3.0), (0, 12.4, OPEN_H / 2 - 1.8), m=inside))
    for i in range(3):
        parts.append(fbox(f"TunnelLight{i}", (0.6, 0.3, 0.1), (0, 3.0 + i * 3.5, OPEN_H - 0.55 - i * 0.6), m=lamp))
    # Sand berm heaped over the tunnel and drifting around the portal.
    # (The mounds stay clear of the tunnel corridor, so its dark interior reads.)
    parts.append(sphere("BermTop", 1.0, (0, 7.0, 6.4), scale=(8.5, 7.5, 2.6), m=sand, segs=28, rings=14))
    # The side mounds stop behind the blast-wall line (local y 0.6), never poking into the arena.
    parts.append(sphere("BermL", 1.0, (-9.5, 6.6, -0.6), scale=(6.0, 5.8, 5.6), m=sdk, segs=24, rings=12))
    parts.append(sphere("BermR", 1.0, (9.5, 6.6, -0.7), scale=(6.0, 5.8, 5.2), m=sand, segs=24, rings=12))
    parts.append(sphere("BermBack", 1.0, (0, 17.0, -0.5), scale=(10.0, 4.0, 6.0), m=sand, segs=24, rings=12))
    save("dune_tunnel", [merge("Tunnel", parts)])


def build_blast_wall():
    """Concrete blast-wall module, 4 m along X, 3.4 m tall, origin at the base centre."""
    reset_scene()
    conc, cdark, clight = dmat("Concrete", rough=0.9), dmat("ConcreteDark", rough=0.92), dmat("ConcreteLight", rough=0.9)
    rust = dmat("Rust", rough=0.55)
    outline = [(-0.55, 0.0), (0.55, 0.0), (0.4, 0.5), (0.24, 3.1), (-0.24, 3.1), (-0.4, 0.5)]
    parts = [make_flat(prism("Panel", outline, 3.9, rot=(0, 0, math.pi / 2), m=conc))]
    parts.append(box("Cap", (4.0, 0.62, 0.3), (0, 0, 3.2), bevel=0.08, m=rust))
    parts.append(box("Foot", (4.0, 1.25, 0.18), (0, 0, 0.09), bevel=0.05, m=cdark))
    for s in (-1, 1):
        parts += hazard_band(f"Stripe{s}", 3.9, 0.35, (0, s * 0.5, 0.36), 0.0 if s < 0 else math.pi, stripe=0.4)
        parts.append(fbox(f"Seam{s}", (0.06, 0.5, 2.6), (s * 1.97, 0, 1.75), m=cdark))
    for s in (-1, 1):
        parts.append(box(f"Lug{s}", (0.3, 0.7, 0.25), (s * 1.2, 0, 3.45), bevel=0.06, m=clight))
    save("dune_blast_wall", [merge("BlastWall", parts)])


if __name__ == "__main__":
    which = sys.argv[1:] or ["hangar", "tower", "gatehouse", "cargo_lift", "tunnel", "blast_wall"]
    for key in which:
        globals()["build_" + key]()
