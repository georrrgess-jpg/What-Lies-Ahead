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
## The generator's PRECINCT district rect.
const PRECINCT := Rect2(-74.0, -24.0, 40.0, 48.0)
## Openings in the street the fill must not cover: the subway stairs and the
## Tower stairs.
const HOLES := [Rect2(-4.0, -28.0, 8.0, 13.0), Rect2(40.0, -37.0, 16.0, 10.0)]
const NEAR_CELL := 24.0
const NEAR_RADIUS := 178.0
const MID_CELL := 34.0
const MID_RADIUS := 300.0
const HORIZON_RADIUS := 430.0
## The square, the Precinct, the Market, the Tower plaza (generator rects).
const ARENAS := [Rect2(-22.0, -22.0, 44.0, 44.0), Rect2(-74.0, -24.0, 40.0, 48.0), Rect2(34.0, -8.0, 56.0, 16.0),
	Rect2(46.0, -72.0, 48.0, 50.0), Rect2(-34.0, 12.0, 12.0, 6.0), Rect2(-34.0, -4.0, 12.0, 8.0),
	Rect2(22.0, -8.0, 12.0, 16.0)]
const CORDON_SIGNS := ["KEEP OUT", "QUARANTINE", "DO NOT CROSS", "NO ENTRY"]
## Billboards on district roofs, facing their streets: [name, position, yaw].
const ROOF_BILLBOARDS := [["BillboardPrecinct", Vector3(-43.0, 18.0, -30.0), 0.0],
	["BillboardMarketN", Vector3(53.0, 15.0, -16.0), 0.0], ["BillboardTower", Vector3(100.0, 16.0, -61.0), -90.0]]
## Fires on district roofs (small, no light): [name, position].
const ROOF_FIRES := [["RoofFireSqE", Vector3(28.0, 16.7, -16.0)], ["RoofFirePrecS", Vector3(-70.0, 16.7, 31.0)],
	["RoofFireMktS", Vector3(88.0, 16.7, 15.0)]]
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
## The river under the bridge: where it starts (metres out from the centre)
## and its half width.
const RIVER_START := 215.0
const RIVER_HALF := 85.0
const FAR_SHORE := 660.0
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
var _trims: Array[Transform3D] = []
var _trim_colors: PackedColorArray = []


func _init(builder: Object, into: Node3D) -> void:
	b = builder
	parent = into
	rng.seed = 4114


## Builds it all; `towers` are the generator's ring towers (unit-box transforms).
func build(towers: Array[Transform3D]) -> void:
	_fill_ground()
	_bridge()
	_river()
	for xf in towers:
		_tower(xf)
	_ring(NEAR_CELL, CITY.grow(5.0), NEAR_RADIUS, 0.0)
	_ring(MID_CELL, Rect2(), MID_RADIUS, 1.0)
	_cranes()
	_horizon()
	_emit("Skyline")


## The district blocks' roofs ([Rect2, height] each): stair houses, masts
## with beacons, the districts' colours along the parapets (Precinct blue
## and red, Market pink and cyan), billboards facing the streets and a few
## roof fires; they read from the street and from the high views.
func build_roofs(roofs: Array) -> void:
	var k := 0
	for roof in roofs:
		var r: Rect2 = roof[0]
		var h: float = roof[1] + 0.7
		if r.size.x < 6.0 or r.size.y < 6.0:
			continue
		var corner := Vector3(r.position.x + 2.2, h, r.position.y + 2.2) if k % 2 == 0 else Vector3(r.end.x - 2.2, h, r.end.y - 2.2)
		_box(corner, Vector3(2.8, 2.8, 3.4), 0.0, Color(0.3, 0.27, 0.28))
		if h > 17.0 and k % 2 == 0:
			var p := Vector3(r.end.x - 2.0, h, r.position.y + 2.0)
			var ah := rng.randf_range(6.0, 10.0)
			_box(p, Vector3(0.3, ah, 0.3), 0.0, STEEL)
			_box(p + Vector3(0, ah * 0.6, 0), Vector3(1.8, 0.12, 0.12), 0.0, STEEL)
			_beacon(p + Vector3(0, ah, 0))
		_trim(r, h, k)
		k += 1
	for spot in ROOF_BILLBOARDS:
		b._roof_billboard(spot[0], spot[1], spot[2])
	for spot in ROOF_FIRES:
		b._fire_at(b.fx, spot[0], spot[1], 1.4, false, 0.0, true)
		b._smoke(b.fx, spot[0] + "Smoke", spot[1], 0.7)
	_emit("Roofs")
	_emit_trim()


## The cordons across the alley mouths ([a, b] each, the generator's tape
## lines over player-only walls): the tape tied to police sawhorses against
## the alley walls, a sign facing the district, ash smoke drifting in the
## alley behind, so a blocked street reads as cordoned off, not as an
## invisible wall.
func build_boundary(mouths: Array) -> void:
	var k := 0
	for m in mouths:
		var a: Vector3 = m[0]
		var to: Vector3 = m[1]
		var along := (to - a).normalized()
		var out := Vector3(-along.z, 0, along.x)
		var mid := (a + to) * 0.5
		if _in_arena(mid + out * 3.0):
			out = -out
		var yaw := rad_to_deg(atan2(-out.z, out.x))
		for end: Vector3 in [a + along * 0.35, to - along * 0.35]:
			b._kit(parent, "city_police_barrier", "Cordon%d_%d" % [k, int(end.distance_to(a))], end + out * 1.2, yaw, Vector3(2.8, 1.1, 0.5))
		var face := -out
		var sign_text: String = CORDON_SIGNS[k % CORDON_SIGNS.size()]
		var board := mid + Vector3(0, 0.55, 0) + out * 0.06
		_box(board, Vector3(1.3, 0.42, 0.04), atan2(-along.z, along.x), Color(0.95, 0.75, 0.12))
		b._label(parent, "CordonSign%d" % k, sign_text, board + Vector3(0, 0.21, 0) + face * 0.04, rad_to_deg(atan2(face.x, face.z)), 52, Color(0.08, 0.06, 0.05)).outline_size = 0
		b._steam(mid + out * 5.0, Color(0.5, 0.42, 0.4), 0.85)
		# A fire escape up one of the alley's walls (alternating sides).
		if k % 2 == 0:
			_fire_escape(a, out, along)
		else:
			_fire_escape(to, out, -along)
		k += 1
	_emit("Cordons")


## A fire escape on the wall through `wall` (facing `normal`), running
## `into` the alley: three landings, rails, a stair between each, the drop
## ladder under the first (visual only, above the zombies' heads).
func _fire_escape(wall: Vector3, into: Vector3, normal: Vector3) -> void:
	var yaw := atan2(-into.z, into.x)
	var iron := Color(0.2, 0.15, 0.13)
	var length := 6.0
	var depth := 1.1
	var centre := wall + into * 4.6 + normal * depth * 0.5
	for f in 3:
		var y := 3.4 + f * 3.2
		_box(centre + Vector3(0, y, 0), Vector3(length, 0.08, depth), yaw, iron)
		for rail_y: float in [0.45, 0.95]:
			_box(centre + normal * depth * 0.5 + Vector3(0, y + rail_y, 0), Vector3(length, 0.05, 0.05), yaw, iron)
		for end: float in [-0.5, 0.5]:
			_box(centre + into * length * end + normal * depth * 0.5 + Vector3(0, y, 0), Vector3(0.06, 0.95, 0.06), yaw, iron)
		if f < 2:
			var foot := centre - into * 1.8 + Vector3(0, y + 0.05, 0)
			var head := centre + into * 1.8 + Vector3(0, y + 3.2, 0)
			var run := head - foot
			var x := run.normalized()
			var zx := normal.normalized()
			var up := zx.cross(x).normalized()
			if up.y < 0.0:
				up = -up
			_boxes.append(Transform3D(Basis(run, up * 0.1, zx * 0.75), (foot + head) * 0.5))
			_tints.append(iron)
			_custom.append(Color(0, 0, 0, 0))
	for side: float in [-0.3, 0.3]:
		_box(centre + into * (length * 0.5 - 0.6 + side) + Vector3(0, 1.4, 0), Vector3(0.05, 2.0, 0.05), yaw, iron)


## Open ground the player fights on (the square, the districts): the side of
## a cordon that is not the alley.
func _in_arena(p: Vector3) -> bool:
	for r: Rect2 in ARENAS:
		if r.has_point(Vector2(p.x, p.z)):
			return true
	return false


## Neon along the parapet edge each Precinct block turns to its district
## (police blue and red). Not the Market's: from its street those long tubes
## read as loose lines across the sky; its neon is on the shops
## (tools/city/city_market.gd).
func _trim(r: Rect2, h: float, k: int) -> void:
	var district := PRECINCT
	var colors := [Color(0.25, 0.4, 1.0), Color(1.0, 0.12, 0.12)]
	if not r.grow(1.0).intersects(district):
		return
	var y := h - 0.05
	var edge := Vector3.ZERO
	var size := Vector3.ZERO
	if r.end.y <= district.position.y + 0.5:
		edge = Vector3(r.get_center().x, y, r.end.y + 0.25)
	elif r.position.y >= district.end.y - 0.5:
		edge = Vector3(r.get_center().x, y, r.position.y - 0.25)
	elif r.end.x <= district.position.x + 0.5:
		edge = Vector3(r.end.x + 0.25, y, r.get_center().y)
	elif r.position.x >= district.end.x - 0.5:
		edge = Vector3(r.position.x - 0.25, y, r.get_center().y)
	else:
		return
	size = Vector3(r.size.x + 0.5, 0.14, 0.14) if absf(edge.z - r.get_center().y) > 0.1 else Vector3(0.14, 0.14, r.size.y + 0.5)
	_trims.append(Transform3D(Basis.IDENTITY.scaled(size), edge))
	_trim_colors.append(colors[k % 2])


func _emit_trim() -> void:
	var box := BoxMesh.new()
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "city_skyline_beacon.gdshader")
	m.set_shader_parameter("steady", 1.0)
	box.material = m
	_mm("RoofNeon", box, _trims, _trim_colors, PackedColorArray())


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
	var material: Material = b._surface("far_ground", ["city_asphalt"], Color(0.3, 0.25, 0.25), 0.12, 1.0)
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
	var basis := Basis(Vector3.UP, yaw).scaled_local(size)
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
	var lit := rng.randf_range(0.04, 0.14)
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
	var slab := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(35.0, 60.0))).scaled_local(Vector3(w * 0.45, 0.6, d * 0.3)),
		base + basis * Vector3(0, 0, d * 0.55) + Vector3(0, h - d * 0.1, 0))
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
	return _near_bridge(pos, radius) or _near_river(pos, radius)


## The last ring, deep in the haze: tall blocks shoulder to shoulder, so
## the ground's far edge never shows under the sky from any height.
func _horizon() -> void:
	for layer in 2:
		var radius := HORIZON_RADIUS + layer * 60.0
		var count := 64 + layer * 12
		for k in count:
			var a := TAU * (k + layer * 0.5) / count
			var w := TAU * radius / count * rng.randf_range(1.0, 1.25)
			var h := rng.randf_range(55.0, 95.0) + layer * 25.0
			var base := CENTRE + Vector3(cos(a), 0, sin(a)) * (radius + rng.randf_range(-12.0, 12.0))
			if _near_river(base, w * 0.3):
				# Across the river: the far shore's towers, taller (they close
				# the horizon over the water).
				base = CENTRE + (base - CENTRE) * (FAR_SHORE / (base - CENTRE).length())
				h += 60.0
			_box(base, Vector3(w, h, rng.randf_range(20.0, 40.0)), -a + PI * 0.5, _tint() * 0.8, rng.randf_range(0.03, 0.08), 0.02, 4.4)
			if rng.randf() < 0.25:
				_box(base + Vector3(0, h, 0), Vector3(w * 0.5, h * rng.randf_range(0.2, 0.6), 18.0), -a + PI * 0.5, _tint() * 0.8, 0.05, 0.0, 4.4)


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
	return absf(along) < BRIDGE_LENGTH * 0.5 + radius and off < 12.0 + radius


## The river the bridge crosses: from RIVER_START out along BRIDGE_DIR.
func _near_river(pos: Vector3, radius: float) -> bool:
	var rel := pos - CENTRE
	var across := Vector3(-BRIDGE_DIR.z, 0, BRIDGE_DIR.x)
	return rel.dot(BRIDGE_DIR) > RIVER_START - radius and absf(rel.dot(across)) < RIVER_HALF + radius


## Dark water under the bridge's main span, out past the horizon, between
## concrete quays (the sun glints on it behind the bridge's silhouette).
func _river() -> void:
	var across := Vector3(-BRIDGE_DIR.z, 0, BRIDGE_DIR.x)
	var yaw := atan2(-across.z, across.x)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.05, 0.06, 0.08)
	water.metallic = 0.7
	water.roughness = 0.12
	var length := FAR_SHORE - RIVER_START
	var mid := CENTRE + BRIDGE_DIR * (RIVER_START + length * 0.5)
	var mi: MeshInstance3D = b._visual_box(parent, "River", Vector3(RIVER_HALF * 2.0, 0.2, length), mid + Vector3(0, 0.1, 0), water)
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quay := Color(0.36, 0.33, 0.32)
	for side: float in [-1.0, 1.0]:
		_box(mid + across * (RIVER_HALF + 1.0) * side - Vector3(0, 0.1, 0), Vector3(2.0, 1.4, length), yaw, quay)
	_box(CENTRE + BRIDGE_DIR * (RIVER_START - 1.0) - Vector3(0, 0.1, 0), Vector3(RIVER_HALF * 2.0 + 4.0, 1.4, 2.0), yaw, quay)


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
				var hang := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, deg_to_rad(28.0)).scaled_local(Vector3(step * 1.4, 1.4, 16.0)), p + Vector3(0, BRIDGE_DECK_Y - 8.0, 0))
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

func _emit(prefix: String) -> void:
	var box := BoxMesh.new()
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "city_skyline_blocks.gdshader")
	box.material = m
	_mm(prefix, box, _boxes, _tints, _custom)
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
	_mm(prefix + "Tanks", tank, _tanks, PackedColorArray(), PackedColorArray())
	var lamp := SphereMesh.new()
	lamp.radius = 0.5
	lamp.height = 1.0
	lamp.radial_segments = 8
	lamp.rings = 4
	var glow := ShaderMaterial.new()
	glow.shader = load(SHADERS + "city_skyline_beacon.gdshader")
	lamp.material = glow
	_mm(prefix + "Beacons", lamp, _beacons, PackedColorArray(), _beacon_phase)


func _mm(mm_name: String, mesh: Mesh, xforms: Array[Transform3D], colors: PackedColorArray, custom: PackedColorArray) -> void:
	if xforms.is_empty():
		return
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
	# Hidden with the rest of the street while the player is in the Metro.
	mmi.add_to_group("city_surface", true)
	parent.add_child(mmi)
