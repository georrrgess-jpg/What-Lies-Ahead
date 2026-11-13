"""Jungle Expedition temple pieces (World 7, Lost Temple): the giant idol face
whose open mouth is the temple door, the shrine on the summit, vine-wrapped
columns, a fallen idol head, braziers, rubble, the trail gate, the exit
portal arch and the expedition outfitters hut (the loadout station).

The temple's stepped tiers themselves are textured boxes built by the level
generator (tools/build_lost_temple.gd), so their collision matches exactly.

    python art/blender/build_jungle_temple.py             (everything)
    python art/blender/build_jungle_temple.py idol_face   (only these)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from jungle_common import *  # noqa: F401,F403

MOUTH_W = 3.4      # doorway width
MOUTH_H = 3.4      # doorway height


def stone():
    return jmat("Stone", rough=0.85)


def shade():
    return jmat("StoneShade", rough=0.9)


def vines_over(prefix, xs, top_z, y, seed, lengths=(1.5, 4.0)):
    rng = random.Random(seed)
    out = []
    for i, x in enumerate(xs):
        out += drape(f"{prefix}{i}", (x, y, top_z), rng.uniform(*lengths), 0.2, jmat("LeafDark"), jmat("Leaf"), seed=seed + i, leaves=4)
    return out


def build_idol_face():
    """The Jade Idol: a carved face 10 m wide and 10.5 m tall on the temple's
    front wall. Its gaping mouth (MOUTH_W x MOUTH_H, at the base) is the temple
    door; a dark passage 4 m deep runs back from it. Eyes and the crest gem
    glow jade. Origin at the middle of the threshold; the face looks along -Y."""
    reset_scene()
    st, sh, dark, gold = stone(), shade(), jmat("Charcoal", rough=1.0), jmat("Gold", rough=0.35, metal=0.5)
    jade = jade_glow()
    w2 = MOUTH_W / 2
    parts = [
        # Wall slab around the mouth.
        box("SlabL", (5.0 - w2, 1.4, 8.4), (-(w2 + (5.0 - w2) / 2), 0.7, 4.2), bevel=0.1, m=st),
        box("SlabR", (5.0 - w2, 1.4, 8.4), ((w2 + (5.0 - w2) / 2), 0.7, 4.2), bevel=0.1, m=st),
        box("SlabTop", (MOUTH_W + 0.2, 1.4, 8.4 - MOUTH_H), (0, 0.7, MOUTH_H + (8.4 - MOUTH_H) / 2), bevel=0.1, m=st),
        # The passage behind the mouth.
        box("PassFloor", (MOUTH_W, 4.2, 0.1), (0, 3.4, -0.04), bevel=0.0, m=dark),
        box("PassL", (0.3, 4.2, MOUTH_H), (-w2 - 0.15, 3.4, MOUTH_H / 2), bevel=0.0, m=dark),
        box("PassR", (0.3, 4.2, MOUTH_H), (w2 + 0.15, 3.4, MOUTH_H / 2), bevel=0.0, m=dark),
        box("PassTop", (MOUTH_W + 0.6, 4.2, 0.3), (0, 3.4, MOUTH_H + 0.15), bevel=0.0, m=dark),
        box("PassBack", (MOUTH_W + 0.6, 0.3, MOUTH_H + 0.3), (0, 5.4, MOUTH_H / 2), bevel=0.0, m=dark),
        # Lips and tusks framing the doorway.
        box("UpperLip", (MOUTH_W + 1.4, 0.9, 0.75), (0, -0.25, MOUTH_H + 0.3), bevel=0.25, segs=3, m=sh),
        box("LipL", (0.7, 0.8, MOUTH_H), (-w2 - 0.35, -0.2, MOUTH_H / 2), bevel=0.22, segs=3, m=sh),
        box("LipR", (0.7, 0.8, MOUTH_H), (w2 + 0.35, -0.2, MOUTH_H / 2), bevel=0.22, segs=3, m=sh),
        box("Chin", (MOUTH_W + 1.6, 0.9, 0.35), (0, -0.25, 0.17), bevel=0.12, m=sh),
    ]
    for i in range(6):
        x = -w2 + 0.3 + i * (MOUTH_W - 0.6) / 5
        parts.append(cyl(f"Tooth{i}", 0.2, 0.55, (x, -0.35, MOUTH_H - 0.25), rot=rad(180, 0, 0), segs=6, bevel=0.03,
                         m=jmat("Cream", rough=0.6), radius_top=0.05))
    for s in (-1, 1):
        parts.append(tube(f"Tusk{s}", [(s * (w2 + 0.4), -0.6, MOUTH_H + 0.1), (s * (w2 + 0.7), -0.9, MOUTH_H - 0.8),
                                        (s * (w2 + 0.45), -0.85, MOUTH_H - 1.5)], 0.2, m=jmat("Cream", rough=0.6), segs=8, radius_end=0.04))
        # Cheeks, eyes, brows, ears.
        parts += [
            sphere(f"Cheek{s}", 1.2, (s * 3.0, -0.2, 4.6), scale=(1.0, 0.55, 0.85), m=st, segs=14, rings=8),
            box(f"Socket{s}", (2.0, 0.6, 1.3), (s * 1.9, -0.15, 6.5), bevel=0.3, segs=3, m=jmat("StoneDark", rough=0.9)),
            sphere(f"Eye{s}", 0.62, (s * 1.9, -0.45, 6.5), scale=(1.25, 0.45, 0.78), m=jade, segs=16, rings=8),
            sphere(f"Pupil{s}", 0.24, (s * 1.9, -0.72, 6.48), scale=(1.0, 0.4, 1.0), m=jmat("JadeDeep", rough=0.3, emit=1.0), segs=10, rings=6),
            box(f"Brow{s}", (2.5, 0.9, 0.55), (s * 1.9, -0.45, 7.4), rot=(0, s * math.radians(-12), 0), bevel=0.2, segs=3, m=sh),
            cyl(f"Ear{s}", 0.9, 0.5, (s * 4.75, -0.1, 5.4), rot=rad(90, 0, 0), segs=20, bevel=0.1, m=sh),
            cyl(f"EarSpool{s}", 0.5, 0.6, (s * 4.75, -0.25, 5.4), rot=rad(90, 0, 0), segs=16, bevel=0.08, m=gold),
            cyl(f"EarGem{s}", 0.22, 0.65, (s * 4.75, -0.3, 5.4), rot=rad(90, 0, 0), segs=12, bevel=0.05, m=jade),
            box(f"Fang{s}", (0.35, 0.5, 0.9), (s * 2.6, -0.5, 3.4), rot=(0, s * math.radians(10), 0), bevel=0.12, m=sh),
        ]
    parts += [
        prism("Nose", [(-0.75, 0.0), (0.75, 0.0), (0.45, 0.6), (0.0, 1.9), (-0.45, 0.6)], 1.2, (0, -0.5, 4.3), m=sh, bevel=0.12),
        box("Nostrils", (1.2, 0.3, 0.3), (0, -1.05, 4.45), bevel=0.12, m=jmat("StoneDark")),
        box("Forehead", (6.4, 1.0, 1.0), (0, -0.2, 8.2), bevel=0.2, m=st),
        box("Band", (7.0, 1.1, 0.45), (0, -0.25, 8.9), bevel=0.12, m=gold),
        cyl("CrestGem", 0.55, 0.5, (0, -0.85, 8.9), rot=rad(90, 0, 0), segs=6, bevel=0.06, m=jade),
    ]
    # Headdress: a fan of stepped feathers in stone, tipped with gold.
    for i in range(9):
        a = math.radians(-60 + i * 15)
        h = 2.0 if i % 2 else 2.6
        base = (math.sin(a) * 2.8, 0.2, 9.0 + math.cos(a) * 0.4)
        p = box(f"Feather{i}", (0.9, 0.5, h), (base[0] + math.sin(a) * h * 0.5, 0.2, base[2] + math.cos(a) * h * 0.5),
                rot=(0, a, 0), bevel=0.2, segs=2, m=st if i % 2 else sh)
        parts.append(p)
        parts.append(sphere(f"FeatherTip{i}", 0.3, (base[0] + math.sin(a) * h, 0.0, base[2] + math.cos(a) * h), m=gold, segs=8, rings=5))
    parts += vines_over("Vine", [-4.4, -3.6, -2.4, 2.2, 3.4, 4.3, 0.9, -0.9], 8.6, -0.8, 300, lengths=(1.2, 3.6))
    parts.append(rock("MossBrowL", 1.2, (-3.6, -0.3, 8.1), jmat("Moss", rough=0.9), seed=310, squash=0.35))
    parts.append(rock("MossBrowR", 0.9, (3.9, -0.3, 7.6), jmat("Moss", rough=0.9), seed=311, squash=0.35))
    save("jungle_idol_face", [merge("IdolFace", parts)])


def build_shrine():
    """The summit shrine: a stone house 7 x 5 m with a roof comb and a jade-lit
    doorway. Front faces -Y."""
    reset_scene()
    st, sh, gold = stone(), shade(), jmat("Gold", rough=0.35, metal=0.5)
    parts = [
        box("BodyL", (2.6, 5.0, 3.6), (-2.2, 0, 1.8), bevel=0.1, m=st),
        box("BodyR", (2.6, 5.0, 3.6), (2.2, 0, 1.8), bevel=0.1, m=st),
        box("BodyTop", (1.9, 5.0, 1.2), (0, 0, 3.0), bevel=0.1, m=st),
        box("Inner", (1.8, 0.2, 2.5), (0, 1.6, 1.25), bevel=0.0, m=jade_glow()),
        box("InnerFloor", (1.8, 3.4, 0.1), (0, 0, 0.05), bevel=0.0, m=jmat("Charcoal")),
        box("Cornice", (7.6, 5.6, 0.5), (0, 0, 3.85), bevel=0.12, m=sh),
        box("Roof1", (6.6, 4.6, 0.8), (0, 0, 4.5), bevel=0.12, m=st),
        box("Roof2", (5.0, 3.4, 0.8), (0, 0, 5.3), bevel=0.12, m=sh),
        box("Comb", (4.0, 0.6, 2.4), (0, 0.6, 6.9), bevel=0.12, m=st),
        box("CombBand", (4.2, 0.7, 0.3), (0, 0.6, 7.6), bevel=0.06, m=gold),
        cyl("CombGem", 0.4, 0.3, (0, 0.2, 6.9), rot=rad(90, 0, 0), segs=6, bevel=0.04, m=jade_glow()),
    ]
    for i in range(5):
        parts.append(box(f"Step{i}", (2.0, 0.3, 0.3), (0, -2.65 - i * 0.0, 0.15), bevel=0.04, m=sh))
    parts += vines_over("Vine", [-3.4, -1.4, 1.6, 3.3], 4.1, -2.9, 400, lengths=(1.0, 2.8))
    save("jungle_shrine", [merge("Shrine", parts)])


def column_parts(prefix, height, broken=False, seed=0):
    rng = random.Random(seed)
    st, sh, moss = stone(), shade(), jmat("Moss", rough=0.9)
    parts = [box(prefix + "Base", (1.3, 1.3, 0.5), (0, 0, 0.25), bevel=0.08, m=sh)]
    drums = int(height / 0.9)
    z = 0.5
    for i in range(drums):
        h = 0.88
        tilt = rng.uniform(-0.03, 0.03) if not broken else rng.uniform(-0.06, 0.06)
        parts.append(cyl(f"{prefix}Drum{i}", 0.48, h, (rng.uniform(-0.02, 0.02), 0, z + h / 2), rot=(tilt, tilt * 0.5, 0), segs=12,
                         bevel=0.05, m=st if i % 2 else sh))
        z += h + 0.02
    if broken:
        parts.append(rock(prefix + "Break", 0.5, (0, 0, z), st, seed=seed + 5, squash=0.5))
    else:
        parts.append(box(prefix + "Capital", (1.3, 1.3, 0.45), (0, 0, z + 0.22), bevel=0.08, m=sh))
        z += 0.45
    # Vines spiral round the shaft with leaves.
    pts = []
    for i in range(14):
        t = i / 13
        a = t * math.tau * 1.4 + seed
        pts.append((math.cos(a) * 0.52, math.sin(a) * 0.52, 0.4 + t * (z - 0.6)))
    parts += vine(prefix + "Vine", pts, 0.05, jmat("LeafDark"), jmat("Leaf"), leaves=10, seed=seed + 7, leaf_size=0.3)
    parts.append(rock(prefix + "Moss", 0.75, (0.1, 0, 0.55), moss, seed=seed + 9, squash=0.4))
    return parts


def build_column():
    """Vine-wrapped temple column, 4.6 m."""
    reset_scene()
    save("jungle_column", [merge("Column", column_parts("C_", 4.0, seed=3))])


def build_column_broken():
    """Broken column stump, ~2.2 m, with fallen drums beside it."""
    reset_scene()
    parts = column_parts("B_", 1.8, broken=True, seed=6)
    parts.append(cyl("FallenA", 0.48, 0.88, (1.3, 0.2, 0.48), rot=rad(0, 90, 20), segs=12, bevel=0.05, m=stone()))
    parts.append(cyl("FallenB", 0.48, 0.88, (2.2, -0.5, 0.48), rot=rad(0, 90, -35), segs=12, bevel=0.05, m=shade()))
    save("jungle_column_broken", [merge("ColumnBroken", parts)])


def build_idol_head():
    """A fallen idol head lying on its cheek in the forecourt (cover): 3 m long,
    2 m tall. Eyes dark, a crack across the brow, moss on top."""
    reset_scene()
    st, sh = stone(), shade()
    parts = [
        box("Block", (2.6, 2.2, 2.0), (0, 0, 1.0), rot=rad(0, 12, 0), bevel=0.3, segs=3, m=st),
        box("Brow", (2.7, 0.5, 0.45), (0, -1.2, 1.5), rot=rad(0, 12, 0), bevel=0.15, m=sh),
        sphere("EyeL", 0.32, (-0.6, -1.2, 1.15), scale=(1.2, 0.4, 0.75), m=jmat("StoneDark"), segs=10, rings=6),
        sphere("EyeR", 0.32, (0.6, -1.2, 1.3), scale=(1.2, 0.4, 0.75), m=jmat("StoneDark"), segs=10, rings=6),
        prism("Nose", [(-0.35, 0.0), (0.35, 0.0), (0.0, 0.8)], 0.6, (0.0, -1.3, 0.55), rot=rad(0, 12, 0), m=sh, bevel=0.08),
        box("Mouth", (1.4, 0.3, 0.3), (0.05, -1.15, 0.35), rot=rad(0, 12, 0), bevel=0.1, m=jmat("StoneDark")),
        box("Crown", (2.8, 2.3, 0.4), (0.1, 0.0, 2.1), rot=rad(0, 12, 0), bevel=0.12, m=jmat("Gold", rough=0.4, metal=0.4)),
        rock("Moss", 1.3, (0.3, 0.2, 2.25), jmat("Moss", rough=0.9), seed=12, squash=0.3),
    ]
    parts += vines_over("Vine", [-1.1, 0.2, 1.2], 2.2, -1.2, 500, lengths=(0.8, 1.6))
    save("jungle_idol_head", [merge("IdolHead", parts)])


def build_brazier():
    """Stone fire brazier, 1.4 m: a stepped pedestal and a wide bowl (the
    level adds the flame quads and light)."""
    reset_scene()
    st, sh = stone(), shade()
    parts = [
        box("Foot", (1.1, 1.1, 0.3), (0, 0, 0.15), bevel=0.06, m=sh),
        box("Stem", (0.6, 0.6, 0.8), (0, 0, 0.7), bevel=0.06, m=st),
        cyl("Bowl", 0.75, 0.45, (0, 0, 1.25), segs=14, bevel=0.06, m=sh, radius_top=0.9),
        cyl("Coals", 0.75, 0.08, (0, 0, 1.45), segs=14, bevel=0.0, m=jglow("JungleEmber", "#ff6a1f", 2.2)),
    ]
    save("jungle_brazier", [merge("Brazier", parts)])


def build_rubble():
    """Fallen carved blocks (waist-high cover), 3 x 2 m."""
    reset_scene()
    st, sh = stone(), shade()
    parts = [
        carved_block("BlockA", (1.4, 1.0, 0.9), (-0.6, 0, 0.45), st, rot=rad(0, 0, 10)),
        carved_block("BlockB", (1.2, 0.9, 0.8), (0.8, 0.2, 0.4), sh, rot=rad(0, 0, -25)),
        carved_block("BlockC", (1.0, 0.8, 0.6), (-0.2, 0.1, 1.2), st, rot=rad(4, 6, 40)),
        box("Glyph", (0.6, 0.05, 0.4), (-0.6, -0.52, 0.5), rot=rad(0, 0, 10), bevel=0.02, m=jmat("StoneDark")),
        rock("Moss", 0.7, (0.8, 0.2, 0.85), jmat("Moss", rough=0.9), seed=14, squash=0.3),
    ]
    save("jungle_rubble", [merge("Rubble", parts)])


def build_trail_gate():
    """Carved stone gateway over a jungle trail: posts 5.2 m apart, a lintel
    with a jade sun disc, torches on brackets. 4.2 m clear height."""
    reset_scene()
    st, sh, gold = stone(), shade(), jmat("Gold", rough=0.35, metal=0.5)
    parts = [
        box("PostL", (1.1, 1.1, 4.4), (-3.15, 0, 2.2), bevel=0.1, m=st),
        box("PostR", (1.1, 1.1, 4.4), (3.15, 0, 2.2), bevel=0.1, m=st),
        box("CapL", (1.4, 1.4, 0.4), (-3.15, 0, 4.6), bevel=0.08, m=sh),
        box("CapR", (1.4, 1.4, 0.4), (3.15, 0, 4.6), bevel=0.08, m=sh),
        box("Lintel", (8.0, 1.2, 1.0), (0, 0, 5.3), bevel=0.12, m=st),
        box("LintelTop", (8.6, 1.4, 0.35), (0, 0, 5.95), bevel=0.08, m=sh),
        cyl("Sun", 0.75, 0.3, (0, -0.65, 5.3), rot=rad(90, 0, 0), segs=16, bevel=0.06, m=gold),
        cyl("SunGem", 0.35, 0.36, (0, -0.68, 5.3), rot=rad(90, 0, 0), segs=12, bevel=0.04, m=jade_glow()),
    ]
    for i in range(8):
        a = math.tau * i / 8
        parts.append(box(f"Ray{i}", (0.18, 0.12, 0.5), (math.cos(a) * 1.0, -0.62, 5.3 + math.sin(a) * 1.0), rot=(0, -a + math.pi / 2, 0),
                         bevel=0.03, m=gold))
    for s in (-1, 1):
        for k in range(3):
            parts.append(box(f"Glyph{s}{k}", (0.6, 0.06, 0.55), (s * 3.15, -0.57, 1.2 + k * 1.1), bevel=0.04, m=sh))
    parts += vines_over("Vine", [-3.6, -2.8, 2.6, 3.7, -1.5, 1.6], 5.8, -0.7, 600, lengths=(0.8, 2.6))
    save("jungle_trail_gate", [merge("TrailGate", parts)])


def build_portal_arch():
    """The exit: the ride's carved stone exit arch. Doorway 2.9 x 3.75 m (the
    swirl), pillars 1.45 m wide either side, jade inlays and a gold idol mask
    on the keystone. Front faces -Y."""
    reset_scene()
    st, sh, gold, jade = stone(), shade(), jmat("Gold", rough=0.35, metal=0.5), jade_glow()
    parts = []
    for s in (-1, 1):
        x = s * 2.15
        parts += [
            box(f"Pillar{s}", (1.45, 0.95, 4.2), (x, 0, 2.1), bevel=0.1, m=st),
            box(f"PillarBase{s}", (1.7, 1.2, 0.5), (x, 0, 0.25), bevel=0.08, m=sh),
            box(f"Inlay{s}", (0.3, 0.1, 2.6), (x, -0.5, 2.2), bevel=0.04, m=jade),
            box(f"Band{s}", (1.5, 1.0, 0.25), (x, 0, 3.5), bevel=0.05, m=gold),
        ]
    parts += [
        box("Lintel", (5.9, 1.05, 1.1), (0, 0, 4.75), bevel=0.12, m=st),
        box("Cornice", (6.4, 1.25, 0.35), (0, 0, 5.45), bevel=0.08, m=sh),
        box("Mask", (1.5, 0.4, 1.2), (0, -0.62, 6.2), bevel=0.2, segs=3, m=gold),
        sphere("MaskEyeL", 0.17, (-0.35, -0.85, 6.35), scale=(1.3, 0.5, 0.8), m=jade, segs=10, rings=6),
        sphere("MaskEyeR", 0.17, (0.35, -0.85, 6.35), scale=(1.3, 0.5, 0.8), m=jade, segs=10, rings=6),
        box("MaskMouth", (0.7, 0.1, 0.18), (0, -0.84, 5.9), bevel=0.04, m=jmat("StoneDark")),
        text("Exit", "EXIT", 0.5, 0.06, (0, -0.58, 4.75), m=jade),
    ]
    for i in range(5):
        a = math.radians(-50 + i * 25)
        parts.append(box(f"Feather{i}", (0.4, 0.3, 1.2), (math.sin(a) * 1.0, -0.1, 6.0 + math.cos(a) * 0.6), rot=(0, a, 0), bevel=0.1,
                         m=sh if i % 2 else st))
    parts += vines_over("Vine", [-2.8, -1.6, 1.4, 2.9], 5.3, -0.65, 700, lengths=(0.8, 2.2))
    save("jungle_portal_arch", [merge("PortalArch", parts)])


def build_station():
    """Expedition Outfitters hut (the loadout station): a bamboo-framed hut on
    a timber deck with a steep thatch roof, a crate counter and shelves of
    supplies. The front shutter (Shutter, hinged at its top edge) swings up
    into an awning while the station is open; OpenDressing (an OPEN sign and
    the supplies on the counter) shows only while open, ClosedSign only while
    closed. About 4.6 x 4 m, roof peak 5.6 m. Front faces -Y."""
    reset_scene()
    bamboo, dark, thatch, tdark = jmat("Bamboo"), jmat("BambooDark"), jmat("Thatch", rough=0.9), jmat("ThatchDark", rough=0.9)
    wood, khaki, canvas = jmat("Bark"), jmat("Khaki"), jmat("Canvas", rough=0.85)
    parts = [
        box("Deck", (4.8, 4.2, 0.3), (0, 0, 0.15), bevel=0.05, m=wood),
        box("BackWall", (4.2, 0.15, 2.6), (0, 1.75, 1.6), bevel=0.03, m=khaki),
        box("SideL", (0.15, 3.5, 2.6), (-2.05, 0, 1.6), bevel=0.03, m=khaki),
        box("SideR", (0.15, 3.5, 2.6), (2.05, 0, 1.6), bevel=0.03, m=khaki),
        box("Counter", (4.0, 0.7, 1.0), (0, -1.45, 0.8), bevel=0.06, m=wood),
        box("CounterTop", (4.3, 0.85, 0.12), (0, -1.45, 1.36), bevel=0.04, m=dark),
        box("FrontHeader", (4.4, 0.25, 0.5), (0, -1.75, 3.1), bevel=0.05, m=wood),
        box("Shelf", (3.6, 0.5, 0.08), (0, 1.4, 2.0), bevel=0.02, m=dark),
        box("ShelfLow", (3.6, 0.5, 0.08), (0, 1.4, 1.3), bevel=0.02, m=dark),
    ]
    for x in (-2.15, 2.15):
        for y in (-1.8, 1.8):
            parts.append(cyl(f"Post{x}{y}", 0.12, 3.2, (x, y, 1.75), segs=8, bevel=0.0, m=bamboo))
            for k in range(3):
                parts.append(torus(f"PostNode{x}{y}{k}", 0.125, 0.025, (x, y, 0.8 + k * 0.9), m=dark, major_segs=10, minor_segs=4))
    # Thatch roof: a steep hip built from stacked, shrinking slabs with a ragged fringe.
    for i in range(5):
        t = i / 4
        parts.append(box(f"Thatch{i}", (5.6 - t * 4.4, 5.0 - t * 3.8, 0.55), (0, 0, 3.6 + i * 0.5), bevel=0.25, segs=2,
                         m=thatch if i % 2 == 0 else tdark))
    rng = random.Random(8)
    for i in range(22):
        a = math.tau * i / 22
        x, y = math.cos(a) * 2.8, math.sin(a) * 2.5
        parts.append(cyl(f"Fringe{i}", 0.2, 0.5, (max(-2.75, min(2.75, x)), max(-2.45, min(2.45, y)), 3.25), segs=5, bevel=0.0,
                         m=thatch, radius_top=0.05 + rng.uniform(0, 0.05)))
    parts += [
        cyl("Finial", 0.18, 0.9, (0, 0, 6.25), segs=8, bevel=0.03, m=dark),
        sphere("FinialGem", 0.2, (0, 0, 6.75), m=jade_glow(), segs=10, rings=6),
        box("SignBoard", (3.4, 0.12, 0.7), (0, -2.0, 3.65), bevel=0.05, m=dark),
        text("Sign", "OUTFITTERS", 0.4, 0.05, (0, -2.08, 3.65), m=jmat("Cream")),
        box("PostBox", (0.7, 0.6, 0.6), (1.6, 1.3, 0.6), bevel=0.05, m=khaki),
        cyl("Rope", 0.28, 0.25, (-1.4, 1.35, 2.25), segs=12, bevel=0.03, m=jmat("Rope")),
        box("MapBoard", (1.1, 0.05, 0.8), (-0.4, 1.66, 2.55), bevel=0.02, m=canvas),
        box("MapRoute", (0.6, 0.06, 0.05), (-0.4, 1.63, 2.55), rot=rad(0, 30, 0), bevel=0.0, m=jmat("RideRed")),
        bulb("LampL", 0.1, (-1.9, -1.6, 2.95), m=jglow("JungleLanternGlow", "#ffc25a", 3.0)),
        bulb("LampR", 0.1, (1.9, -1.6, 2.95), m=jglow("JungleLanternGlow", "#ffc25a", 3.0)),
    ]
    # Supplies on the shelves.
    for i in range(6):
        x = -1.5 + i * 0.6
        parts.append(box(f"Tin{i}", (0.3, 0.3, 0.4), (x, 1.4, 1.54), bevel=0.04, m=jmat(("RideRed", "Teal", "Yellow")[i % 3], rough=0.5)))
        parts.append(cyl(f"Jar{i}", 0.13, 0.35, (x + 0.15, 1.4, 2.22), segs=10, bevel=0.03, m=jmat(("Olive", "Orange", "TealDark")[i % 3], rough=0.5)))
    station = merge("Station", parts)

    # Shutter: hinged along the header's lower front edge (pivot), closed hangs down.
    hinge = (0, -1.85, 2.85)
    sp = [
        box("ShutterBoard", (4.2, 0.1, 1.45), (0, -1.85, 2.1), bevel=0.03, m=canvas),
    ]
    for k in range(5):
        sp.append(box(f"ShutterStripe{k}", (0.42, 0.11, 1.45), (-1.68 + k * 0.84, -1.85, 2.1), bevel=0.0, m=jmat("RideRed", rough=0.7)))
    sp.append(box("ShutterBattenTop", (4.3, 0.14, 0.1), (0, -1.86, 2.8), bevel=0.02, m=dark))
    shutter = merge("Shutter", sp, pivot=hinge)

    op = [
        box("OpenBoard", (1.2, 0.08, 0.45), (0, -1.95, 1.9), bevel=0.04, m=jmat("Teal", rough=0.5)),
        text("OpenText", "OPEN", 0.28, 0.04, (0, -2.0, 1.9), m=jmat("Cream")),
        box("Ammo", (0.5, 0.35, 0.3), (-1.3, -1.45, 1.57), bevel=0.04, m=jmat("Olive")),
        cyl("Canteen", 0.15, 0.3, (1.3, -1.45, 1.57), segs=12, bevel=0.04, m=jmat("TealDark")),
        box("Medkit", (0.45, 0.32, 0.25), (0.6, -1.45, 1.55), bevel=0.04, m=jmat("Cream")),
        box("MedCross", (0.12, 0.34, 0.27), (0.6, -1.45, 1.55), bevel=0.0, m=jmat("RideRed")),
    ]
    open_dressing = merge("OpenDressing", op)
    cp = [
        box("ClosedBoard", (1.4, 0.08, 0.5), (0, -1.96, 1.1), bevel=0.04, m=jmat("RideRedDark")),
        text("ClosedText", "CLOSED", 0.26, 0.04, (0, -2.01, 1.1), m=jmat("Cream")),
    ]
    closed_sign = merge("ClosedSign", cp)
    save("jungle_station", [station, shutter, open_dressing, closed_sign])


ALL = {
    "idol_face": build_idol_face, "shrine": build_shrine, "column": build_column, "column_broken": build_column_broken,
    "idol_head": build_idol_head, "brazier": build_brazier, "rubble": build_rubble, "trail_gate": build_trail_gate,
    "portal_arch": build_portal_arch, "station": build_station,
}


if __name__ == "__main__":
    wanted = [a for a in sys.argv[1:] if a in ALL] or list(ALL)
    for key in wanted:
        ALL[key]()
