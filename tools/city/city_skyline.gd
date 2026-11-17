extends RefCounted
## Ashfall City's landscape beyond the districts, for tools/build_endless_city.gd:
## the ground under the whole city's footprint, a dense near ring of low
## blocks round it, a sparser mid ring, the generator's tower rings dressed as
## one city (setbacks, cornices, spires, broken tops, water tanks), cranes, a
## suspension bridge against the sunset, red aircraft-warning beacons and
## smoke over the burning towers. Everything is one MultiMesh per mesh (a few
## draw calls for the whole horizon).
##
##   preload("res://tools/city/city_skyline.gd").new(builder, parent).build(towers)

const SHADERS := "res://art/shaders/"
## The skyline's centre (the generator's tower rings circle it).
const CENTRE := Vector3(10.0, 0.0, -24.0)
## The districts' footprint: its own floors and blocks (kept clear).
const CITY := Rect2(-100.0, -104.0, 222.0, 168.0)
## Openings in the street the fill must not cover: the subway stairs and the
## Tower stairs.
const HOLES := [Rect2(-4.0, -28.0, 8.0, 13.0), Rect2(40.0, -37.0, 16.0, 10.0)]
const NEAR_CELL := 24.0
const NEAR_RADIUS := 178.0
const MID_CELL := 34.0
const MID_RADIUS := 300.0
## One city's palette: soot-dark concrete, brick, sandstone, blue-grey, tar.
const PALETTE := [Color(0.42, 0.36, 0.34), Color(0.5, 0.3, 0.26), Color(0.52, 0.45, 0.36),
	Color(0.36, 0.38, 0.44), Color(0.3, 0.27, 0.28), Color(0.46, 0.4, 0.38)]
## Smoke columns over broken towers (each a few big quads).
const MAX_SMOKES := 7
const STEEL := Color(0.16, 0.14, 0.15)
const RUST := Color(0.55, 0.36, 0.14)
## Toward the setting sun (the generator's SUN_DIRECTION, flattened).
const BRIDGE_DIR := Vector3(0.77, 0.0, 0.64)
const BRIDGE_DISTANCE := 330.0
const BRIDGE_LENGTH := 560.0
const BRIDGE_DECK_Y := 26.0
const PYLON_H := 100.0
const PYLON_SPAN := 120.0
## The fallen stretch of the bridge's main span (metres along it from the middle).
const GAP := Vector2(18.0, 50.0)

var b: Object
var parent: Node3D
var rng := RandomNumberGenerator.new()
## Unit boxes: transform, tint, custom (lit, burning, seed, window cell).
var _boxes: Array[Transform3D] = []
var _tints: PackedColorArray = []
var _custom: PackedColorArray = []
var _tanks: Array[Transform3D] = []
var _beacons: Array[Transform3D] = []
var _beacon_phase: PackedColorArray = []
## Footprints already built on (x, z, radius), so rings do not overlap.
var _taken: Array[Vector3] = []
var _smokes := 0


func _init(builder: Object, into: Node3D) -> void:
	b = builder
	parent = into
	rng.seed = 4114


## Builds it all; `towers` are the generator's ring towers (unit-box transforms).
func build(towers: Array[Transform3D]) -> void:
	_fill_ground()
	_bridge()
	for xf in towers:
		_tower(xf)
	_ring(NEAR_CELL, CITY.grow(5.0), NEAR_RADIUS, 0.0)
	_ring(MID_CELL, Rect2(), MID_RADIUS, 1.0)
	_cranes()
	_emit()


# ---------------------------------------------------------------------------
# Ground
# ---------------------------------------------------------------------------

## The far ground under the city's footprint (between and behind the
## district blocks the void showed black from every high view), cut round
## the stairwells.
func _fill_ground() -> void:
	var xs: Array[float] = [CITY.position.x, CITY.end.x]
	var zs: Array[float] = [CITY.position.y, CITY.end.y]
	for h in HOLES:
		xs.append_array([(h as Rect2).position.x, (h as Rect2).end.x])
		zs.append_array([(h as Rect2).position.y, (h as Rect2).end.y])
	xs.sort()
	zs.sort()
	var material: Material = b._mat("far_ground", Color(0.16, 0.13, 0.13), 1.0)
	var k := 0
	for i in xs.size() - 1:
		var x0: float = xs[i]
		var x1: float = xs[i + 1]
		if x1 - x0 < 0.01:
			continue
		# One strip per column, split only where it crosses a hole.
		var z0: float = zs[0]
		for j in zs.size() - 1:
			var cell := Rect2(x0, zs[j], x1 - x0, zs[j + 1] - zs[j])
			if _in_hole(cell.get_center()):
				_ground_strip(material, Rect2(x0, z0, x1 - x0, zs[j] - z0), k)
				z0 = zs[j + 1]
				k += 1
		_ground_strip(material, Rect2(x0, z0, x1 - x0, zs[zs.size() - 1] - z0), k)
		k += 1


func _in_hole(p: Vector2) -> bool:
	for h in HOLES:
		if (h as Rect2).has_point(p):
			return true
	return false


func _ground_strip(material: Material, r: Rect2, k: int) -> void:
	if r.size.x < 0.01 or r.size.y < 0.01:
		return
	var mi: MeshInstance3D = b._visual_box(parent, "CityFloor%d" % k, Vector3(r.size.x, 0.1, r.size.y), Vector3(r.get_center().x, -0.12, r.get_center().y), material)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------------------
# Buildings
# ---------------------------------------------------------------------------

## Adds one unit box: `size` at `pos` (its base centre), turned `yaw`.
func _box(pos: Vector3, size: Vector3, yaw: float, tint: Color, lit := 0.0, burning := 0.0, cell := 0.0) -> void:
	var basis := Basis(Vector3.UP, yaw).scaled(size)
	_boxes.append(Transform3D(basis, pos + Vector3(0, size.y * 0.5, 0)))
	_tints.append(tint)
	_custom.append(Color(lit, burning, rng.randf() * 10.0, cell))


func _tint() -> Color:
	var c: Color = PALETTE[rng.randi() % PALETTE.size()]
	return c * rng.randf_range(0.85, 1.12)


## A building: its body with windows, a cornice, then setbacks, roof houses,
## AC units, a water tank or an antenna; `burning` raises its burning windows.
func _building(base: Vector3, w: float, d: float, h: float, yaw: float, burning: float) -> void:
	var tint := _tint()
	var cell := 3.2 if h < 40.0 else 3.8
	var lit := rng.randf_range(0.03, 0.12)
	_box(base, Vector3(w, h, d), yaw, tint, lit, burning, cell)
	var basis := Basis(Vector3.UP, yaw)
	_box(base + Vector3(0, h, 0), Vector3(w + 0.8, 0.7, d + 0.8), yaw, tint * 0.7)
	var top := h + 0.7
	var tw := w
	var td := d
	# Setbacks on the taller ones (the stepped tops of an old downtown).
	var steps := 0 if h < 22.0 else rng.randi_range(0, 2 if h > 45.0 else 1)
	for s in steps:
		tw *= rng.randf_range(0.6, 0.8)
		td *= rng.randf_range(0.6, 0.8)
		var sh := h * rng.randf_range(0.15, 0.3)
		var off := basis * Vector3(rng.randf_range(-0.1, 0.1) * tw, 0, rng.randf_range(-0.1, 0.1) * td)
		_box(base + off + Vector3(0, top, 0), Vector3(tw, sh, td), yaw, tint * 0.95, lit, burning, cell)
		top += sh
		_box(base + off + Vector3(0, top, 0), Vector3(tw + 0.6, 0.5, td + 0.6), yaw, tint * 0.7)
		top += 0.5
	_roof_clutter(base, tw, td, top, yaw, h)


func _roof_clutter(base: Vector3, w: float, d: float, top: float, yaw: float, h: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var dark := Color(0.22, 0.2, 0.21)
	# A stair house and a couple of AC units.
	var p := base + basis * Vector3(rng.randf_range(-0.3, 0.3) * w, 0, rng.randf_range(-0.3, 0.3) * d)
	_box(p + Vector3(0, top, 0), Vector3(3.0, 2.6, 3.4), yaw, dark)
	for k in rng.randi_range(1, 3):
		p = base + basis * Vector3(rng.randf_range(-0.38, 0.38) * w, 0, rng.randf_range(-0.38, 0.38) * d)
		_box(p + Vector3(0, top, 0), Vector3(1.6, 1.1, 1.2), yaw, Color(0.4, 0.4, 0.42))
	var roll := rng.randf()
	if roll < 0.35 and h < 45.0:
		p = base + basis * Vector3(rng.randf_range(-0.3, 0.3) * w, 0, rng.randf_range(-0.3, 0.3) * d)
		_tank(p + Vector3(0, top, 0), rng.randf_range(1.6, 2.4))
	elif roll < 0.6:
		var ah := rng.randf_range(5.0, 14.0) * (2.0 if h > 60.0 else 1.0)
		p = base + basis * Vector3(rng.randf_range(-0.2, 0.2) * w, 0, rng.randf_range(-0.2, 0.2) * d)
		_box(p + Vector3(0, top, 0), Vector3(0.35, ah, 0.35), 0.0, STEEL)
		if h > 35.0:
			_beacon(p + Vector3(0, top + ah, 0))


## A wooden water tank on its legs (the tank MultiMesh draws both).
func _tank(pos: Vector3, radius: float) -> void:
	var legs := radius * 1.4
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		_box(pos + Vector3(cos(a), 0, sin(a)) * radius * 0.7, Vector3(0.25, legs, 0.25), 0.0, STEEL)
	_tanks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(radius, radius * 1.5, radius)), pos + Vector3(0, legs + radius * 0.75, 0)))


func _beacon(pos: Vector3) -> void:
	_beacons.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.9), pos + Vector3(0, 0.4, 0)))
	_beacon_phase.append(Color(rng.randf(), 0, 0, 0))


## One of the generator's ring towers (kept where it stands, dressed): a
## tower in the city's palette, some with spires, some broken and burning.
func _tower(xf: Transform3D) -> void:
	var size := Vector3(xf.basis.x.length(), xf.basis.y.length(), xf.basis.z.length())
	var base := xf.origin - Vector3(0, size.y * 0.5, 0)
	if _blocked(base, maxf(size.x, size.z) * 0.5):
		return
	var yaw := atan2(-xf.basis.x.z, xf.basis.x.x)
	var r := Vector2(base.x - CENTRE.x, base.z - CENTRE.z).length()
	var h := size.y
	# The first ring stands among the near blocks: lower, so the rings layer.
	if r < 190.0:
		h *= 0.65
	var broken := rng.randf() < 0.14
	var burning := rng.randf_range(0.0, 0.05) + (0.18 if broken else 0.0)
	_taken.append(Vector3(base.x, base.z, maxf(size.x, size.z) * 0.6))
	if broken:
		_broken_tower(base, size.x, size.z, h, yaw, burning)
	else:
		_building(base, size.x, size.z, h, yaw, burning)
		if h > 70.0 and rng.randf() < 0.6:
			_spire(base + Vector3(0, h + 0.7, 0), h)


## A tower with its top floors torn off: a jagged stump, a slab hanging off
## the edge, fire in the top windows and smoke over it.
func _broken_tower(base: Vector3, w: float, d: float, h: float, yaw: float, burning: float) -> void:
	var tint := _tint() * 0.8
	_box(base, Vector3(w, h, d), yaw, tint, 0.02, burning, 3.8)
	var basis := Basis(Vector3.UP, yaw)
	for k in 3:
		var cw := w * rng.randf_range(0.25, 0.5)
		var ch := rng.randf_range(4.0, 14.0)
		var p := base + basis * Vector3(rng.randf_range(-0.3, 0.3) * w, 0, rng.randf_range(-0.3, 0.3) * d)
		_box(p + Vector3(0, h, 0), Vector3(cw, ch, d * rng.randf_range(0.4, 0.9)), yaw, tint, 0.0, 0.3, 3.8)
	# A floor slab torn loose, hanging down one side.
	var slab := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(35.0, 60.0))).scaled(Vector3(w * 0.7, 0.8, d * 0.5)),
		base + basis * Vector3(0, 0, d * 0.55) + Vector3(0, h - d * 0.15, 0))
	_boxes.append(slab)
	_tints.append(tint * 0.7)
	_custom.append(Color(0, 0, 0, 0))
	if _smokes < MAX_SMOKES:
		b._smoke(b.fx, "SkylineSmoke%d" % _smokes, base + Vector3(0, h, 0), rng.randf_range(2.2, 3.4))
		_smokes += 1


## A radio spire: a tapering mast in three sections, beacons up its length.
func _spire(pos: Vector3, h: float) -> void:
	var length := h * rng.randf_range(0.25, 0.4)
	var y := 0.0
	for k in 3:
		var part := length / 3.0
		var t := 1.6 - k * 0.5
		_box(pos + Vector3(0, y, 0), Vector3(t, part, t), 0.0, STEEL)
		y += part
		_beacon(pos + Vector3(0, y, 0))


## Blocks on a grid round the city: every free cell within `radius` of the
## centre, clipped clear of `keep_out` (the districts and the street round
## them); `far` 0 is the near ring (low, dense), 1 the mid ring (taller,
## sparser, behind the near one).
func _ring(cell: float, keep_out: Rect2, radius: float, far: float) -> void:
	var n := int(ceil(radius / cell))
	var street := 6.0 if far < 0.5 else 8.0
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var c := CENTRE + Vector3(i * cell, 0, j * cell)
			var r := Vector2(c.x - CENTRE.x, c.z - CENTRE.z).length()
			if r > radius or (far > 0.5 and r < NEAR_RADIUS):
				continue
			var lot := Rect2(c.x - cell * 0.5, c.z - cell * 0.5, cell, cell).grow(-street * 0.5)
			if keep_out.size.x > 0.0 and keep_out.intersects(lot):
				lot = _clip_outside(lot, keep_out)
			if lot.size.x < 9.0 or lot.size.y < 9.0:
				continue
			if far > 0.5 and rng.randf() < 0.3:
				continue
			_lot(lot, r, far)


## The largest part of `lot` outside `keep_out` (empty if none).
func _clip_outside(lot: Rect2, keep_out: Rect2) -> Rect2:
	var parts := [Rect2(lot.position.x, lot.position.y, keep_out.position.x - lot.position.x, lot.size.y),
		Rect2(keep_out.end.x, lot.position.y, lot.end.x - keep_out.end.x, lot.size.y),
		Rect2(lot.position.x, lot.position.y, lot.size.x, keep_out.position.y - lot.position.y),
		Rect2(lot.position.x, keep_out.end.y, lot.size.x, lot.end.y - keep_out.end.y)]
	var best := Rect2()
	for p: Rect2 in parts:
		if p.size.x > 0.0 and p.size.y > 0.0 and p.get_area() > best.get_area():
			best = p
	return best


## One lot: one to three buildings side by side.
func _lot(lot: Rect2, r: float, far: float) -> void:
	var parts := rng.randi_range(1, 3) if far < 0.5 else rng.randi_range(1, 2)
	var along := lot.size.x >= lot.size.y
	var length := lot.size.x if along else lot.size.y
	if length / parts < 7.0:
		parts = 1
	var centre := Vector3(lot.get_center().x, 0, lot.get_center().y)
	var lot_radius := maxf(lot.size.x, lot.size.y) * 0.5
	if _blocked(centre, lot_radius * 0.8):
		return
	_taken.append(Vector3(centre.x, centre.z, lot_radius * 0.7))
	var x0 := 0.0
	for k in parts:
		var wpart := length / parts
		var w := wpart - (0.0 if k == parts - 1 else 0.6)
		var part := Rect2(lot.position + Vector2(x0, 0), Vector2(w, lot.size.y)) if along else Rect2(lot.position + Vector2(0, x0), Vector2(lot.size.x, w))
		x0 += wpart
		var pos := Vector3(part.get_center().x, 0, part.get_center().y)
		var h := rng.randf_range(9.0, 22.0) + (r - 120.0) * 0.08
		if far > 0.5:
			h = rng.randf_range(22.0, 48.0) + (r - NEAR_RADIUS) * 0.15
		if rng.randf() < 0.08:
			h *= 1.7
		_building(pos, part.size.x, part.size.y, h, 0.0, 0.0 if rng.randf() < 0.9 else 0.2)


func _blocked(pos: Vector3, radius: float) -> bool:
	for t in _taken:
		if Vector2(t.x - pos.x, t.y - pos.z).length() < t.z + radius:
			return true
	return _near_bridge(pos, radius)


# ---------------------------------------------------------------------------
# Landmarks: the bridge, the cranes
# ---------------------------------------------------------------------------

func _bridge_frame() -> Array:
	var mid := CENTRE + BRIDGE_DIR * BRIDGE_DISTANCE
	var across := Vector3(-BRIDGE_DIR.z, 0, BRIDGE_DIR.x)
	return [mid, across]


func _near_bridge(pos: Vector3, radius: float) -> bool:
	var frame := _bridge_frame()
	var rel: Vector3 = pos - frame[0]
	var along: float = rel.dot(frame[1])
	var off: float = absf(rel.dot(BRIDGE_DIR))
	return absf(along) < BRIDGE_LENGTH * 0.5 + radius and off < 24.0 + radius


## A suspension bridge across the sunset: deck on piers, two tall pylons,
## the main cables sagging between them, hangers down to the deck. One span
## has fallen into the gap.
func _bridge() -> void:
	var frame := _bridge_frame()
	var mid: Vector3 = frame[0]
	var across: Vector3 = frame[1]
	var yaw := atan2(-across.z, across.x)
	var deck := Color(0.24, 0.22, 0.23)
	var gap := GAP
	var step := 20.0
	var t := -BRIDGE_LENGTH * 0.5
	while t < BRIDGE_LENGTH * 0.5:
		var p := mid + across * (t + step * 0.5)
		if t + step * 0.5 > gap.x and t + step * 0.5 < gap.y:
			# The fallen span: one end still on the deck, the other in the gap.
			if t + step > gap.y:
				var hang := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, deg_to_rad(28.0)).scaled(Vector3(step * 1.4, 1.4, 16.0)), p + Vector3(0, BRIDGE_DECK_Y - 8.0, 0))
				_boxes.append(hang)
				_tints.append(deck)
				_custom.append(Color(0, 0, 0, 0))
			t += step
			continue
		_box(p + Vector3(0, BRIDGE_DECK_Y, 0), Vector3(step + 0.05, 1.6, 16.0), yaw, deck)
		_box(p + Vector3(0, BRIDGE_DECK_Y + 1.6, 0) + BRIDGE_DIR * 7.6, Vector3(step, 1.0, 0.4), yaw, STEEL)
		_box(p + Vector3(0, BRIDGE_DECK_Y + 1.6, 0) - BRIDGE_DIR * 7.6, Vector3(step, 1.0, 0.4), yaw, STEEL)
		if absf(t) > PYLON_SPAN + 10.0 and int(t / step) % 2 == 0:
			_box(p, Vector3(4.0, BRIDGE_DECK_Y, 10.0), yaw, deck * 0.8)
		t += step
	for side: float in [-1.0, 1.0]:
		var at := mid + across * PYLON_SPAN * side
		for lane: float in [-1.0, 1.0]:
			_box(at + BRIDGE_DIR * 7.0 * lane, Vector3(3.2, PYLON_H, 3.2), yaw, deck * 1.1)
		_box(at + Vector3(0, BRIDGE_DECK_Y + 22.0, 0), Vector3(3.0, 2.4, 17.0), yaw, deck * 1.1)
		_box(at + Vector3(0, PYLON_H - 6.0, 0), Vector3(3.0, 2.4, 17.0), yaw, deck * 1.1)
		_beacon(at + Vector3(0, PYLON_H, 0) + BRIDGE_DIR * 7.0)
		_beacon(at + Vector3(0, PYLON_H, 0) - BRIDGE_DIR * 7.0)
	for lane: float in [-1.0, 1.0]:
		_main_cable(mid, across, BRIDGE_DIR * 7.0 * lane)


## A main cable from the anchorages over both pylons, a parabola between
## them, and the hangers down to the deck (thin boxes).
func _main_cable(mid: Vector3, across: Vector3, side: Vector3) -> void:
	var points: Array[Vector3] = []
	var n := 24
	for k in n + 1:
		var u := -PYLON_SPAN + 2.0 * PYLON_SPAN * k / n
		var sag := (u / PYLON_SPAN) * (u / PYLON_SPAN)
		points.append(mid + side + across * u + Vector3(0, BRIDGE_DECK_Y + 6.0 + (PYLON_H - BRIDGE_DECK_Y - 6.0) * sag, 0))
	# The back spans down to the anchorages.
	for s: float in [-1.0, 1.0]:
		var top := mid + side + across * PYLON_SPAN * s + Vector3(0, PYLON_H, 0)
		_strut(top, mid + side + across * (PYLON_SPAN + 90.0) * s + Vector3(0, BRIDGE_DECK_Y + 1.0, 0), 0.6)
	for k in n:
		_strut(points[k], points[k + 1], 0.6)
		var foot := Vector3(points[k].x, BRIDGE_DECK_Y + 1.6, points[k].z)
		var u := (points[k] - mid).dot(across)
		if k > 0 and (u < GAP.x or u > GAP.y):
			_strut(points[k], foot, 0.15)


## A thin box from `a` to `b`.
func _strut(a: Vector3, to: Vector3, thickness: float) -> void:
	var dir := to - a
	var length := dir.length()
	if length < 0.01:
		return
	var y := dir / length
	var x := y.cross(Vector3.FORWARD if absf(y.y) > 0.9 else Vector3.UP).normalized()
	var z := x.cross(y)
	_boxes.append(Transform3D(Basis(x * thickness, y * length, z * thickness), (a + to) * 0.5))
	_tints.append(STEEL)
	_custom.append(Color(0, 0, 0, 0))


## Tower cranes over the near ring (the city was being rebuilt when it
## fell): a mast, the jib and counter-jib, the cab, a beacon on top.
func _cranes() -> void:
	var spots := [[Vector3(-150.0, 0, -90.0), 0.6], [Vector3(150.0, 0, 70.0), 2.2], [Vector3(-60.0, 0, 130.0), 4.0], [Vector3(140.0, 0, -150.0), 1.2]]
	for s in spots:
		var base: Vector3 = s[0]
		var yaw: float = s[1]
		var h := rng.randf_range(48.0, 62.0)
		var dir := Vector3(cos(yaw), 0, -sin(yaw))
		for k in 4:
			var corner := Vector3(1.0 if k % 2 == 0 else -1.0, 0, 1.0 if k < 2 else -1.0) * 0.9
			_box(base + corner, Vector3(0.35, h, 0.35), 0.0, RUST)
		for y in range(4, int(h), 4):
			_box(base + Vector3(0, y, 0), Vector3(2.2, 0.25, 2.2), 0.0, RUST)
		_box(base + Vector3(0, h, 0) + dir * 16.0, Vector3(44.0, 1.2, 1.4), yaw, RUST)
		_box(base + Vector3(0, h, 0) - dir * 12.0, Vector3(4.0, 3.0, 3.0), yaw, Color(0.3, 0.3, 0.32))
		_box(base + Vector3(0, h - 3.0, 0) + dir * 1.5, Vector3(2.6, 2.4, 2.4), yaw, Color(0.6, 0.55, 0.4))
		_box(base + Vector3(0, h, 0), Vector3(1.2, 7.0, 1.2), 0.0, RUST)
		_strut(base + Vector3(0, h + 7.0, 0), base + Vector3(0, h + 1.0, 0) + dir * 36.0, 0.12)
		_strut(base + Vector3(0, h + 7.0, 0), base + Vector3(0, h + 1.0, 0) - dir * 12.0, 0.12)
		_strut(base + Vector3(0, h, 0) + dir * rng.randf_range(18.0, 34.0), base + Vector3(0, h * 0.55, 0) + dir * 26.0, 0.08)
		_beacon(base + Vector3(0, h + 7.0, 0))
		_beacon(base + Vector3(0, h + 1.0, 0) + dir * 38.0)
		_taken.append(Vector3(base.x, base.z, 3.0))


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

func _emit() -> void:
	var box := BoxMesh.new()
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "city_skyline_blocks.gdshader")
	box.material = m
	_mm("Skyline", box, _boxes, _tints, _custom)
	var tank := CylinderMesh.new()
	tank.top_radius = 1.0
	tank.bottom_radius = 1.0
	tank.height = 1.0
	tank.radial_segments = 10
	tank.rings = 1
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.2, 0.13)
	wood.roughness = 0.95
	tank.material = wood
	_mm("SkylineTanks", tank, _tanks, PackedColorArray(), PackedColorArray())
	var lamp := SphereMesh.new()
	lamp.radius = 0.5
	lamp.height = 1.0
	lamp.radial_segments = 8
	lamp.rings = 4
	var glow := ShaderMaterial.new()
	glow.shader = load(SHADERS + "city_skyline_beacon.gdshader")
	lamp.material = glow
	_mm("SkylineBeacons", lamp, _beacons, PackedColorArray(), _beacon_phase)


func _mm(mm_name: String, mesh: Mesh, xforms: Array[Transform3D], colors: PackedColorArray, custom: PackedColorArray) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.use_custom_data = not custom.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
		if mm.use_colors:
			mm.set_instance_color(k, colors[k])
		if mm.use_custom_data:
			mm.set_instance_custom_data(k, custom[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = mm_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi
