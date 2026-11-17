extends RefCounted
## Street-level dressing of Ashfall City, called once by
## tools/build_endless_city.gd at the end of _build_story():
##
##   preload("res://tools/city/city_streets.gd").new(self).build()
##
## Street furniture on every district's pavements (phone booths, newspaper
## boxes, planters and benches, parking meters, bike racks, hydrants, traffic
## cones, wall pipes and air conditioners), potholes in the roads, and the
## stories left behind: a field triage post at Precinct 9, a KWLA news van
## crashed at the Broadcast Tower with its camera still on the mast, luggage
## dropped on the Metro platform, a noodle bar in the Neon Market.
##
## Everything stands against a wall or on the kerb line, out of the fighting
## lanes, the zombies' entrances and the features; props of one kind share
## one MultiMesh, and anything bigger than a bin is solid (the navmesh flows
## round it). It never draws from the generator's random numbers, so the
## rest of the city keeps its layout.

const Batch := preload("res://scripts/props/city_map_batch.gd")
const METRO_Y := -6.0
## Kinds that cast shadows (the big ones).
const SHADOWED := ["phone_booth", "tent", "news_van", "vending"]

## The generator (tools/build_endless_city.gd): its node roots and helpers.
## Untyped: the generator is a SceneTree script run with --script.
var b
var _rng := RandomNumberGenerator.new()
## Colliders of the solid props (under the navmesh's geometry).
var _solid: Node3D
## Kind (+ "Metro" below the street) -> [kind, Array[Transform3D]].
var _placed := {}
var _mesh_cache := {}


func _init(builder: Variant) -> void:
	b = builder
	_rng.seed = 1514


func build() -> void:
	_solid = Node3D.new()
	_solid.name = "Streets"
	b.geo.add_child(_solid)
	_square()
	_precinct()
	_market()
	_metro()
	_tower()
	_back_streets()
	_flush()


# ---------------------------------------------------------------------------
# Districts
# ---------------------------------------------------------------------------

## Ashfall Square's pavements: a phone booth, newspaper boxes, a bench
## between planters, parking meters, a bike rack; potholes in the ring road.
func _square() -> void:
	_put("phone_booth", Vector3(-21.3, 0, 8.0), 90.0, Vector3(1.1, 2.6, 1.1))
	_put("news_boxes", Vector3(6.9, 0, 21.5), 180.0, Vector3(1.7, 1.0, 0.5))
	_put("planter", Vector3(-12.0, 0, -21.0), 0.0, Vector3(1.6, 0.6, 1.6))
	_put("planter", Vector3(-5.2, 0, -21.0), 0.0, Vector3(1.6, 0.6, 1.6))
	_put("bench", Vector3(-8.6, 0, -21.45), 180.0, Vector3(2.4, 0.5, 0.6))
	_put("bike_rack", Vector3(21.2, 0, -8.5), 90.0, Vector3(2.4, 0.9, 0.6))
	for x in [9.5, 12.0]:
		_meter(Vector3(x, 0, 19.85), 180.0)
	for x in [-11.0, 5.5]:
		_meter(Vector3(x, 0, -19.85), 0.0)
	b._solid_kit(_solid, "city_hydrant", "HydrantW", Vector3(-20.1, 0, 11.2), 90.0, Vector3(0.5, 0.9, 0.5))
	_pothole(Vector3(-17.8, 0, -4.6), 0.9)
	_pothole(Vector3(6.2, 0, -18.0), 1.0)
	_pothole(Vector3(18.0, 0, 3.6), 0.8)
	_pothole(Vector3(-4.6, 0, 17.8), 0.7)
	_put("cone", Vector3(7.5, 0, -18.8), 0.0)
	_put("cone", Vector3(4.9, 0, -17.3), 30.0)
	_put("cone", Vector3(7.1, 0, -16.9), 70.0, Vector3.ZERO, Basis(Vector3.RIGHT, PI * 0.5), 0.17)


## Precinct 9: a field triage post against the north row (tent, cots, red
## cross crates, its sign), riot shields dropped on the run to the station,
## a sinkhole coned off in the car park, potholes, a hydrant.
func _precinct() -> void:
	_put("tent", Vector3(-65.5, 0, -21.6), 90.0, Vector3(3.0, 2.4, 4.4))
	_put("cot", Vector3(-61.9, 0, -22.3), 0.0)
	_put("cot", Vector3(-60.7, 0, -22.1), 4.0)
	_put("med_crates", Vector3(-69.4, 0, -19.6), 12.0, Vector3(1.4, 0.8, 0.6))
	_tag("FIELD TRIAGE", Vector3(-65.5, 3.4, -23.94), 0.0, Color(1.0, 0.25, 0.22), 88)
	_tag("WALK-INS >", Vector3(-61.0, 2.2, -23.94), 0.0, Color(0.95, 0.95, 0.9), 56)
	for s in [[Vector3(-70.2, 0, -2.6), 20.0], [Vector3(-68.4, 0, 4.4), 140.0], [Vector3(-63.2, 0, -1.4), 75.0],
			[Vector3(-59.0, 0, 5.2), 200.0], [Vector3(-69.5, 0, 12.0), 310.0]]:
		_put("shield", s[0], s[1], Vector3.ZERO, Basis(Vector3.RIGHT, -PI * 0.5), 0.02)
	var sink := Vector3(-58.5, 0, 8.0)
	_pothole(sink, 1.7)
	for k in 5:
		var a := k * TAU / 5.0 + 0.3
		var p := sink + Vector3(cos(a), 0, sin(a)) * 2.5
		if k == 3:
			_put("cone", p, rad_to_deg(a), Vector3.ZERO, Basis(Vector3.RIGHT, PI * 0.5), 0.17)
		else:
			_put("cone", p, rad_to_deg(a))
	_pothole(Vector3(-49.5, 0, -8.5), 0.9)
	_pothole(Vector3(-61.5, 0, -5.8), 0.7)
	_pothole(Vector3(-42.0, 0, 10.8), 1.0)
	b._solid_kit(_solid, "city_hydrant", "HydrantPrecinct", Vector3(-46.0, 0, 23.2), 0.0, Vector3(0.5, 0.9, 0.5))
	_put("bike_rack", Vector3(-62.0, 0, 23.3), 0.0, Vector3(2.4, 0.9, 0.6))


## Neon Market: a noodle bar (tables, stools, bowls) by a lit vending
## machine, crates stacked at the shop doors, shopping trolleys (one over).
func _market() -> void:
	_put("table_set", Vector3(68.6, 0, 6.2), 15.0, Vector3(0.9, 0.78, 0.9))
	_put("table_set", Vector3(71.6, 0, 6.4), -20.0, Vector3(0.9, 0.78, 0.9))
	_put("vending", Vector3(73.8, 0, 7.45), 180.0, Vector3(1.0, 1.9, 0.8))
	_put("crates", Vector3(37.4, 0, -7.4), 0.0, Vector3(1.3, 0.9, 0.5))
	_put("crates", Vector3(59.8, 0, -7.4), 180.0, Vector3(1.3, 0.9, 0.5))
	_put("crates", Vector3(49.0, 0, 7.4), 0.0, Vector3(1.3, 0.9, 0.5))
	_put("trolley", Vector3(50.4, 0, -6.8), 80.0)
	_put("trolley", Vector3(86.4, 0, 6.5), 30.0, Vector3.ZERO, Basis(Vector3.FORWARD, PI * 0.5), 0.3)


## The Metro platform: luggage dropped in the rush for the trains, vending
## machines against the wall between the ads.
func _metro() -> void:
	var y := METRO_Y
	for p in [[Vector3(-4.5, y, -31.5), 20.0], [Vector3(6.5, y, -35.6), 150.0], [Vector3(16.2, y, -30.4), 260.0],
			[Vector3(29.5, y, -34.8), 80.0], [Vector3(-15.5, y, -30.0), 200.0], [Vector3(36.5, y, -31.2), 330.0],
			[Vector3(13.8, y, -36.4), 45.0]]:
		_put("luggage", p[0], p[1])
	_put("vending", Vector3(-4.0, y, -28.45), 180.0, Vector3(1.0, 1.9, 0.8))
	_put("vending", Vector3(13.0, y, -28.45), 180.0, Vector3(1.0, 1.9, 0.8))


## The Broadcast Tower plaza: the KWLA news van crashed at the alley's foot,
## its dish torn off, the crew's camera left filming the mast; benches
## between planters along the edges.
func _tower() -> void:
	var van := Vector3(78.5, 0, -26.6)
	_put("news_van", van, -8.0, Vector3(5.7, 2.5, 2.2))
	b._player_block(_solid, "NewsVanCap", Vector3(5.7, 3.0, 2.2), van + Vector3(0, 4.0, 0), deg_to_rad(-8.0))
	var side := Basis(Vector3.UP, deg_to_rad(-8.0))
	for s in [1.0, -1.0]:
		var face := van + side * Vector3(-0.75, 0, s * 1.08)
		var yaw := -8.0 + (0.0 if s > 0.0 else 180.0)
		b._label(b.dressing, "NewsVanLogo%s" % ("S" if s > 0.0 else "N"), "KWLA", face + Vector3(0, 1.75, 0), yaw, 150, Color(1.0, 0.2, 0.18))
		b._label(b.dressing, "NewsVanLine%s" % ("S" if s > 0.0 else "N"), "NEWS 7  LIVE", face + Vector3(0, 0.75, 0), yaw, 64, Color(0.1, 0.1, 0.14))
	_put("dish", Vector3(82.6, 0, -24.0), 35.0, Vector3.ZERO, Basis(Vector3.RIGHT, deg_to_rad(-62.0)), 0.55)
	b._cable(van + side * Vector3(-1.5, 2.5, 0), Vector3(82.4, 0.3, -24.2), 0.2, 6)
	_put("tv_camera", Vector3(67.6, 0, -41.4), -45.0)
	_put("planter", Vector3(51.0, 0, -23.2), 0.0, Vector3(1.6, 0.6, 1.6))
	_put("planter", Vector3(56.5, 0, -23.2), 0.0, Vector3(1.6, 0.6, 1.6))
	_put("bench", Vector3(53.75, 0, -23.35), 0.0, Vector3(2.4, 0.5, 0.6))
	_put("planter", Vector3(92.8, 0, -66.0), 0.0, Vector3(1.6, 0.6, 1.6))
	_put("planter", Vector3(92.8, 0, -59.2), 0.0, Vector3(1.6, 0.6, 1.6))
	_put("bench", Vector3(93.35, 0, -62.6), 90.0, Vector3(2.4, 0.5, 0.6))
	_pothole(Vector3(66.2, 0, -18.4), 0.8)


## The streets between the districts: pipes, air conditioners and notices
## on the bare walls of the passages, pallets and a dumpster in the back
## street to the Precinct.
func _back_streets() -> void:
	# Back street to the Precinct (x -34..-22, z 12..18; the gate at x -28).
	b._solid_kit(_solid, "city_dumpster", "BackStreetDumpster", Vector3(-24.6, 0, 12.75), 0.0, Vector3(2.0, 1.4, 1.2))
	_put("crates", Vector3(-32.4, 0, 17.45), 180.0, Vector3(1.3, 0.9, 0.5))
	_tag("LOOTERS WILL BE SHOT", Vector3(-31.0, 2.7, 12.06), 0.0, Color(1.0, 0.85, 0.2), 64)
	_tag("KEEP OUT", Vector3(-24.6, 2.9, 17.94), 180.0, Color(1.0, 0.3, 0.25), 90)
	for p in [[Vector3(-30.6, 4.4, 12.5), 0.0], [Vector3(-25.0, 6.8, 12.5), 0.0], [Vector3(-31.5, 5.2, 17.5), 180.0]]:
		b._instance("ac", Transform3D(Basis(Vector3.UP, deg_to_rad(p[1])), p[0]), Color.WHITE)
	_pipe(Vector3(-26.8, 0, 12.1), 12.0)
	_pipe(Vector3(-33.0, 0, 17.9), 12.0)
	# The checkpoint street (x -34..-22, z -4..4) and the arcade (x 22..34).
	_pipe(Vector3(-27.2, 0, -3.9), 11.0)
	_pipe(Vector3(-23.0, 0, 3.9), 13.0)
	_pipe(Vector3(24.6, 0, -3.9), 12.0)
	_pipe(Vector3(32.4, 0, 3.9), 11.0)
	for p in [[Vector3(-31.8, 5.6, -3.5), 180.0], [Vector3(29.6, 4.8, 3.5), 0.0], [Vector3(25.0, 7.4, -3.5), 180.0]]:
		b._instance("ac", Transform3D(Basis(Vector3.UP, deg_to_rad(p[1])), p[0]), Color.WHITE)


# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------

## One prop of `kind` standing at `pos` facing `yaw` (degrees; its front is
## local +Z), tipped by `tilt` and raised `lift` metres; `solid` (width,
## height, depth) gives it a box collider.
func _put(kind: String, pos: Vector3, yaw: float, solid := Vector3.ZERO, tilt := Basis(), lift := 0.0) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var key := kind + ("Metro" if pos.y < -0.2 else "")
	if not _placed.has(key):
		_placed[key] = [kind, [] as Array[Transform3D]]
	(_placed[key][1] as Array[Transform3D]).append(Transform3D(basis * tilt, pos + Vector3(0, lift, 0)))
	if solid != Vector3.ZERO:
		var body: StaticBody3D = b._collider(_solid, "%s%d" % [key.to_pascal_case(), _solid.get_child_count()], solid, pos + Vector3(0, solid.y * 0.5, 0))
		body.rotation.y = deg_to_rad(yaw)


## A parking meter on the kerb (a thin post the player bumps into).
func _meter(pos: Vector3, yaw: float) -> void:
	_put("meter", pos, yaw)
	b._post(_solid, "Meter%d" % _solid.get_child_count(), 0.08, 1.4, pos)


## A pothole `radius` metres across in the asphalt, broken bits round it.
func _pothole(pos: Vector3, radius: float) -> void:
	var stretch := Vector3(radius * _rng.randf_range(0.9, 1.25), 1.0, radius * _rng.randf_range(0.7, 1.0))
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(stretch)
	var key := "pothole"
	if not _placed.has(key):
		_placed[key] = [key, [] as Array[Transform3D]]
	(_placed[key][1] as Array[Transform3D]).append(Transform3D(basis, pos))
	for k in int(3 + radius * 3.0):
		var a := _rng.randf() * TAU
		var p := pos + Vector3(cos(a) * stretch.x, 0.05, sin(a) * stretch.z) * _rng.randf_range(0.9, 1.4)
		var s := _rng.randf_range(0.5, 1.0)
		var shade := _rng.randf_range(0.18, 0.3)
		b._instance("chunk", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3(s, s * 0.6, s)), p), Color(shade, shade * 0.95, shade * 0.92))


## A drainpipe up a wall from `base`, `height` metres, with its shoe.
func _pipe(base: Vector3, height: float) -> void:
	var xf := Transform3D(Basis().scaled_local(Vector3(1.0, height, 1.0)), base + Vector3(0, height * 0.5, 0))
	if not _placed.has("pipe"):
		_placed["pipe"] = ["pipe", [] as Array[Transform3D]]
	(_placed["pipe"][1] as Array[Transform3D]).append(xf)


## Painted notice on a wall: `yaw` turns the text to face away from it.
func _tag(text: String, pos: Vector3, yaw: float, color: Color, font_size: int) -> void:
	var l: Label3D = b._label(b.dressing, "Notice_%s_%d" % [text.validate_node_name().replace(" ", ""), int(pos.x * 10 + pos.z)], text, pos, yaw, font_size, color)
	l.outline_size = 6
	l.outline_modulate = color.darkened(0.75)
	l.shaded = true


## Every kind's placements as one MultiMesh each.
func _flush() -> void:
	for key in _placed:
		var kind: String = _placed[key][0]
		var xforms: Array[Transform3D] = _placed[key][1]
		var mmi: MultiMeshInstance3D = b._multimesh("Streets_" + String(key), _mesh(kind), xforms)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind in SHADOWED else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.dressing.add_child(mmi)


# ---------------------------------------------------------------------------
# Meshes: primitives merged into one mesh per kind (city_map_batch.gd)
# ---------------------------------------------------------------------------

func _mesh(kind: String) -> Mesh:
	if _mesh_cache.has(kind):
		return _mesh_cache[kind]
	var parts: Array = []
	match kind:
		"phone_booth":
			parts = _phone_booth()
		"news_boxes":
			parts = _news_boxes()
		"planter":
			parts = _planter()
		"bench":
			# The Metro's platform bench (built by the generator before this runs).
			return b._meshes["bench"]
		"meter":
			parts = [[_bx(Vector3(0.07, 1.05, 0.07)), _at(0, 0.52, 0), _m("meter_post", Color(0.2, 0.21, 0.22), 0.5)],
				[_bx(Vector3(0.2, 0.32, 0.15)), _at(0, 1.2, 0), _m("meter_head", Color(0.5, 0.53, 0.56), 0.35)],
				[_bx(Vector3(0.13, 0.08, 0.02)), _at(0, 1.26, 0.08), _m("meter_flag", Color(0.85, 0.12, 0.08), 0.4)]]
		"bike_rack":
			parts = _bike_rack()
		"cone":
			parts = [[_cyl(0.03, 0.16, 0.55), _at(0, 0.31, 0), _m("cone", Color(1.0, 0.4, 0.06), 0.6)],
				[_cyl(0.085, 0.11, 0.09), _at(0, 0.32, 0), _m("cone_band", Color(0.95, 0.95, 0.92), 0.5)],
				[_bx(Vector3(0.38, 0.04, 0.38)), _at(0, 0.02, 0), _m("cone_base", Color(0.08, 0.08, 0.08), 0.8)]]
		"pothole":
			parts = [[_cyl(1.12, 1.12, 0.012, 18), _at(0, 0.008, 0), _m("pothole_rim", Color(0.2, 0.19, 0.18), 0.9)],
				[_cyl(1.0, 1.0, 0.02, 18), _at(0, 0.012, 0), _m("pothole", Color(0.035, 0.032, 0.03), 0.15)]]
		"tent":
			parts = _tent()
		"cot":
			parts = _cot()
		"med_crates":
			parts = _med_crates()
		"shield":
			parts = [[_bx(Vector3(0.55, 0.95, 0.03)), _at(0, 0, 0), _m("shield", Color(0.16, 0.2, 0.26), 0.2)],
				[_bx(Vector3(0.42, 0.09, 0.035)), _at(0, 0.22, 0), _m("shield_band", Color(0.9, 0.9, 0.86), 0.5)]]
		"table_set":
			parts = _table_set()
		"vending":
			parts = _vending()
		"crates":
			parts = _crates()
		"trolley":
			parts = _trolley()
		"luggage":
			parts = _luggage()
		"news_van":
			parts = _news_van()
		"dish":
			parts = [[_cyl(0.8, 0.12, 0.22, 16), _at(0, 0, 0), _m("dish", Color(0.78, 0.78, 0.8), 0.4)],
				[_bx(Vector3(0.06, 0.06, 0.8)), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.45, 0)), _m("van_dark", Color(0.12, 0.12, 0.13), 0.5)]]
		"tv_camera":
			parts = _tv_camera()
		"pipe":
			parts = [[_cyl(0.07, 0.07, 1.0, 8), _at(0, 0, 0), _m("pipe", Color(0.24, 0.27, 0.25), 0.5)]]
	var mesh := Batch.compound(parts)
	_mesh_cache[kind] = mesh
	return mesh


func _phone_booth() -> Array:
	var red := _m("booth_red", Color(0.72, 0.1, 0.08), 0.45)
	var glass := _m("booth_glass", Color(0.16, 0.22, 0.27), 0.08)
	var parts: Array = [[_bx(Vector3(1.12, 0.12, 1.12)), _at(0, 0.06, 0), _m("booth_base", Color(0.45, 0.44, 0.42), 0.9)],
		[_bx(Vector3(1.14, 0.2, 1.14)), _at(0, 2.52, 0), red],
		[_bx(Vector3(1.04, 0.24, 1.04)), _at(0, 2.3, 0), _m("booth_sign", Color(0.95, 0.92, 0.82), 0.5)],
		[_bx(Vector3(0.9, 1.75, 0.03)), _at(0, 1.25, -0.48), glass],
		[_bx(Vector3(0.03, 1.75, 0.9)), _at(-0.48, 1.25, 0), glass],
		[_bx(Vector3(0.03, 1.75, 0.9)), _at(0.48, 1.25, 0), glass],
		[_bx(Vector3(0.45, 1.75, 0.03)), Transform3D(Basis(Vector3.UP, deg_to_rad(-65.0)), Vector3(0.62, 1.25, 0.66)), glass],
		[_bx(Vector3(0.26, 0.4, 0.12)), _at(0, 1.45, -0.4), _m("booth_phone", Color(0.18, 0.18, 0.2), 0.4)],
		[_bx(Vector3(0.06, 0.28, 0.06)), Transform3D(Basis(Vector3.FORWARD, 0.2), Vector3(0.12, 0.92, -0.38)), _m("van_dark", Color(0.12, 0.12, 0.13), 0.5)]]
	for x in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			parts.append([_bx(Vector3(0.09, 2.3, 0.09)), _at(x, 1.27, z), red])
	return parts


func _news_boxes() -> Array:
	var colors := [Color(0.14, 0.3, 0.7), Color(0.75, 0.12, 0.1), Color(0.92, 0.7, 0.1)]
	var parts: Array = []
	for i in 3:
		var x := (i - 1) * 0.56
		var lean := Basis(Vector3.FORWARD, 0.06 if i == 2 else 0.0)
		parts.append([_bx(Vector3(0.48, 0.62, 0.42)), Transform3D(lean, Vector3(x, 0.64, 0)), _m("newsbox_%d" % i, colors[i], 0.45)])
		parts.append([_bx(Vector3(0.36, 0.22, 0.02)), Transform3D(lean, Vector3(x, 0.74, 0.215)), _m("newsbox_window", Color(0.82, 0.84, 0.8), 0.2)])
		parts.append([_bx(Vector3(0.07, 0.34, 0.07)), _at(x, 0.17, 0), _m("meter_post", Color(0.2, 0.21, 0.22), 0.5)])
	return parts


func _planter() -> Array:
	var shrub := _m("shrub", Color(0.42, 0.42, 0.22), 0.95)
	var parts: Array = [[_bx(Vector3(1.6, 0.6, 1.6)), _at(0, 0.3, 0), _m("planter", Color(0.56, 0.53, 0.5), 0.9)],
		[_bx(Vector3(1.4, 0.05, 1.4)), _at(0, 0.6, 0), _m("soil", Color(0.17, 0.11, 0.07), 1.0)],
		[_sphere(0.45), _at(0.1, 0.92, -0.05), shrub],
		[_sphere(0.3), _at(-0.38, 0.8, 0.28), _m("shrub_dry", Color(0.55, 0.46, 0.24), 0.95)]]
	for k in 4:
		var a := k * 1.6
		parts.append([_bx(Vector3(0.03, 0.7, 0.03)), Transform3D(Basis(Vector3(cos(a), 0, sin(a)), 0.5), Vector3(0.1 + cos(a) * 0.2, 1.1, sin(a) * 0.2)), _m("twig", Color(0.22, 0.16, 0.1), 0.9)])
	return parts


func _bike_rack() -> Array:
	var steel := _m("rack_steel", Color(0.55, 0.57, 0.6), 0.3)
	var parts: Array = [[_bx(Vector3(2.4, 0.05, 0.08)), _at(0, 0.025, 0), steel]]
	for x in [-0.9, -0.3, 0.3, 0.9]:
		for z in [-0.25, 0.25]:
			parts.append([_bx(Vector3(0.05, 0.8, 0.05)), _at(x, 0.4, z), steel])
		parts.append([_bx(Vector3(0.05, 0.05, 0.55)), _at(x, 0.8, 0), steel])
	# A bike locked through the second hoop, its back wheel gone.
	var frame := _m("bike_red", Color(0.7, 0.12, 0.1), 0.4)
	var tyre := _m("tyre", Color(0.06, 0.06, 0.06), 0.8)
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.28
	wheel.outer_radius = 0.33
	wheel.rings = 16
	wheel.ring_segments = 6
	parts.append([wheel, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.3, 0.33, 0.5)), tyre])
	parts.append([wheel, Transform3D(Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.RIGHT, 1.3), Vector3(-0.25, 0.05, -0.65)), tyre])
	parts.append([_bx(Vector3(0.04, 0.04, 0.75)), Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(-0.3, 0.55, 0.05)), frame])
	parts.append([_bx(Vector3(0.04, 0.5, 0.04)), _at(-0.3, 0.6, -0.3), frame])
	parts.append([_bx(Vector3(0.08, 0.04, 0.22)), _at(-0.3, 0.86, -0.32), tyre])
	parts.append([_bx(Vector3(0.46, 0.03, 0.03)), _at(-0.3, 0.92, 0.42), tyre])
	return parts


func _tent() -> Array:
	var canvas := _m("tent", Color(0.86, 0.85, 0.78), 0.95)
	var prism := PrismMesh.new()
	prism.size = Vector3(3.0, 2.4, 4.4)
	var cross := _m("red_cross", Color(0.85, 0.08, 0.08), 0.6)
	var parts: Array = [[prism, _at(0, 1.2, 0), canvas],
		[_bx(Vector3(1.0, 1.3, 0.02)), _at(0, 0.65, 2.21), _m("tent_door", Color(0.08, 0.07, 0.07), 0.9)],
		[_bx(Vector3(0.14, 0.62, 0.02)), _at(0, 1.05, -2.21), cross],
		[_bx(Vector3(0.62, 0.14, 0.02)), _at(0, 1.05, -2.21), cross],
		[_bx(Vector3(0.1, 0.42, 0.02)), _at(0, 1.72, 2.22), cross],
		[_bx(Vector3(0.42, 0.1, 0.02)), _at(0, 1.72, 2.22), cross]]
	# Guy ropes to pegs.
	for z in [-1.8, 1.8]:
		for s in [-1.0, 1.0]:
			var top := Vector3(s * 0.75, 1.2, z)
			var peg := Vector3(s * 2.1, 0.0, z)
			var seg := peg - top
			parts.append([_bx(Vector3(0.015, 0.015, seg.length())), Transform3D(Basis.looking_at(seg.normalized(), Vector3.UP), (top + peg) * 0.5), _m("rope", Color(0.55, 0.5, 0.4), 0.9)])
	return parts


func _cot() -> Array:
	var frame := _m("cot_frame", Color(0.3, 0.33, 0.22), 0.7)
	var parts: Array = [[_bx(Vector3(0.7, 0.05, 1.9)), _at(0, 0.5, 0), frame],
		[_bx(Vector3(0.66, 0.08, 1.55)), _at(0, 0.56, 0.1), _m("sheet", Color(0.9, 0.9, 0.86), 0.9)],
		[_bx(Vector3(0.48, 0.1, 0.3)), _at(0, 0.6, -0.75), _m("sheet", Color(0.9, 0.9, 0.86), 0.9)],
		[_bx(Vector3(0.3, 0.02, 0.4)), Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.05, 0.61, 0.35)), _m("blood", Color(0.35, 0.03, 0.03), 0.3)]]
	for x in [-0.32, 0.32]:
		for z in [-0.9, 0.9]:
			parts.append([_bx(Vector3(0.04, 0.5, 0.04)), _at(x, 0.25, z), frame])
	return parts


func _med_crates() -> Array:
	var white := _m("med_crate", Color(0.86, 0.86, 0.82), 0.6)
	var cross := _m("red_cross", Color(0.85, 0.08, 0.08), 0.6)
	var parts: Array = []
	for c in [[Vector3(-0.35, 0.25, 0), 0.0], [Vector3(0.4, 0.25, 0.02), 0.1], [Vector3(0.0, 0.75, 0), -0.15]]:
		var basis := Basis(Vector3.UP, c[1])
		var p: Vector3 = c[0]
		parts.append([_bx(Vector3(0.7, 0.5, 0.5)), Transform3D(basis, p), white])
		parts.append([_bx(Vector3(0.1, 0.32, 0.02)), Transform3D(basis, p + basis * Vector3(0, 0, 0.26)), cross])
		parts.append([_bx(Vector3(0.32, 0.1, 0.02)), Transform3D(basis, p + basis * Vector3(0, 0, 0.26)), cross])
	return parts


func _table_set() -> Array:
	var red := _m("plastic_red", Color(0.82, 0.16, 0.12), 0.4)
	var blue := _m("plastic_blue", Color(0.14, 0.34, 0.72), 0.4)
	var bowl := _m("bowl", Color(0.95, 0.93, 0.88), 0.3)
	return [[_cyl(0.45, 0.45, 0.04, 16), _at(0, 0.74, 0), red],
		[_cyl(0.04, 0.04, 0.72, 8), _at(0, 0.36, 0), red],
		[_cyl(0.25, 0.25, 0.03, 12), _at(0, 0.015, 0), red],
		[_cyl(0.17, 0.15, 0.45, 12), _at(0.72, 0.225, 0.1), blue],
		[_cyl(0.17, 0.15, 0.45, 12), _at(-0.7, 0.225, -0.15), blue],
		[_cyl(0.17, 0.15, 0.45, 12), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.1, 0.17, 0.85)), blue],
		[_cyl(0.1, 0.06, 0.07, 10), _at(0.12, 0.795, 0.05), bowl],
		[_cyl(0.1, 0.06, 0.07, 10), _at(-0.16, 0.795, -0.12), bowl],
		[_bx(Vector3(0.012, 0.012, 0.24)), Transform3D(Basis(Vector3.UP, 0.5), Vector3(0.14, 0.84, 0.03)), _m("twig", Color(0.22, 0.16, 0.1), 0.9)]]


func _vending() -> Array:
	return [[_bx(Vector3(1.0, 1.9, 0.8)), _at(0, 0.95, 0), _m("vending", Color(0.72, 0.1, 0.14), 0.4)],
		[_bx(Vector3(0.62, 1.2, 0.02)), _at(-0.12, 1.2, 0.405), b._mat("vending_glow", Color(0.25, 0.45, 0.6), 0.3, Color(0.35, 0.7, 1.0), 0.55)],
		[_bx(Vector3(0.6, 0.16, 0.03)), _at(-0.12, 0.36, 0.41), _m("van_dark", Color(0.12, 0.12, 0.13), 0.5)],
		[_bx(Vector3(0.16, 0.5, 0.03)), _at(0.33, 1.3, 0.41), _m("booth_phone", Color(0.18, 0.18, 0.2), 0.4)]]


func _crates() -> Array:
	var wood := _m("crate", Color(0.56, 0.38, 0.2), 0.85)
	var slat := _m("crate_slat", Color(0.42, 0.27, 0.14), 0.85)
	var parts: Array = []
	for c in [[Vector3(-0.32, 0.22, 0), 0.05], [Vector3(0.34, 0.22, 0.03), -0.08], [Vector3(-0.05, 0.67, 0.0), 0.2]]:
		var basis := Basis(Vector3.UP, c[1])
		parts.append([_bx(Vector3(0.6, 0.44, 0.45)), Transform3D(basis, c[0]), wood])
		parts.append([_bx(Vector3(0.62, 0.06, 0.47)), Transform3D(basis, c[0] + Vector3(0, 0.08, 0)), slat])
	return parts


func _trolley() -> Array:
	var wire := _m("trolley", Color(0.62, 0.64, 0.68), 0.3)
	var parts: Array = [[_bx(Vector3(0.55, 0.02, 0.85)), _at(0, 0.5, 0), wire],
		[_bx(Vector3(0.02, 0.4, 0.85)), _at(-0.27, 0.7, 0), wire], [_bx(Vector3(0.02, 0.4, 0.85)), _at(0.27, 0.7, 0), wire],
		[_bx(Vector3(0.55, 0.4, 0.02)), _at(0, 0.7, -0.42), wire], [_bx(Vector3(0.55, 0.45, 0.02)), _at(0, 0.72, 0.42), wire],
		[_bx(Vector3(0.55, 0.04, 0.04)), _at(0, 1.0, -0.52), _m("plastic_red", Color(0.82, 0.16, 0.12), 0.4)]]
	for x in [-0.22, 0.22]:
		for z in [-0.35, 0.35]:
			parts.append([_bx(Vector3(0.03, 0.45, 0.03)), _at(x, 0.27, z), wire])
			parts.append([_cyl(0.05, 0.05, 0.04, 8), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x, 0.05, z)), _m("tyre", Color(0.06, 0.06, 0.06), 0.8)])
	return parts


func _luggage() -> Array:
	var duffel := CapsuleMesh.new()
	duffel.radius = 0.17
	duffel.height = 0.7
	duffel.radial_segments = 10
	duffel.rings = 2
	return [[_bx(Vector3(0.48, 0.66, 0.24)), Transform3D(Basis(Vector3.UP, 0.2), Vector3(0, 0.33, 0)), _m("case_red", Color(0.62, 0.12, 0.14), 0.5)],
		[_bx(Vector3(0.04, 0.3, 0.04)), _at(0.12, 0.8, 0.0), _m("van_dark", Color(0.12, 0.12, 0.13), 0.5)],
		[_bx(Vector3(0.6, 0.22, 0.42)), Transform3D(Basis(Vector3.UP, -0.5), Vector3(0.55, 0.11, 0.35)), _m("case_blue", Color(0.16, 0.3, 0.5), 0.5)],
		[duffel, Transform3D(Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.RIGHT, 0.4), Vector3(-0.5, 0.17, 0.4)), _m("duffel", Color(0.32, 0.36, 0.22), 0.9)]]


func _news_van() -> Array:
	var white := _m("van_white", Color(0.88, 0.88, 0.86), 0.5)
	var red := _m("van_red", Color(0.75, 0.1, 0.1), 0.5)
	var dark := _m("van_dark", Color(0.12, 0.12, 0.13), 0.5)
	var glass := _m("booth_glass", Color(0.16, 0.22, 0.27), 0.08)
	var tyre := _m("tyre", Color(0.06, 0.06, 0.06), 0.8)
	var parts: Array = [[_bx(Vector3(3.9, 2.1, 2.1)), _at(-0.75, 1.4, 0), white],
		[_bx(Vector3(1.7, 1.45, 2.0)), _at(1.95, 1.08, 0), white],
		[_bx(Vector3(3.92, 0.22, 2.12)), _at(-0.75, 1.0, 0), red],
		[_bx(Vector3(0.06, 0.62, 1.8)), Transform3D(Basis(Vector3.FORWARD, -0.35), Vector3(2.62, 1.5, 0)), glass],
		[_bx(Vector3(0.9, 0.5, 2.04)), _at(1.9, 1.45, 0), glass],
		[_bx(Vector3(0.18, 0.3, 2.1)), _at(2.86, 0.48, 0), dark],
		[_bx(Vector3(0.1, 0.3, 2.1)), _at(-2.72, 0.5, 0), dark],
		# The dish's mast, snapped.
		[_bx(Vector3(0.14, 0.7, 0.14)), Transform3D(Basis(Vector3.FORWARD, 0.25), Vector3(-1.5, 2.8, 0)), dark],
		[_bx(Vector3(1.2, 0.1, 0.9)), _at(0.2, 2.5, 0), dark]]
	for x in [-1.9, 1.85]:
		for z in [-1.0, 1.0]:
			parts.append([_cyl(0.42, 0.42, 0.3, 14), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.42, z)), tyre])
	# The front left tyre burst: the nose dips, a crumpled bumper.
	parts.append([_bx(Vector3(0.5, 0.35, 0.25)), Transform3D(Basis(Vector3.UP, 0.5), Vector3(2.95, 0.4, 0.75)), dark])
	return parts


func _tv_camera() -> Array:
	var dark := _m("van_dark", Color(0.12, 0.12, 0.13), 0.5)
	var parts: Array = [[_bx(Vector3(0.26, 0.32, 0.6)), _at(0, 1.55, 0), dark],
		[_cyl(0.09, 0.11, 0.3, 10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.58, -0.42)), _m("lens", Color(0.05, 0.05, 0.08), 0.1)],
		[_bx(Vector3(0.06, 0.06, 0.06)), _at(0.0, 1.76, 0.2), b._mat("tally", Color(1.0, 0.1, 0.08), 0.3, Color(1.0, 0.1, 0.05), 4.0)],
		[_bx(Vector3(0.3, 0.08, 0.1)), _at(0, 1.74, -0.1), _m("van_red", Color(0.75, 0.1, 0.1), 0.5)]]
	for a in 3:
		var foot := Vector3(cos(a * TAU / 3.0), 0, sin(a * TAU / 3.0)) * 0.55
		var head := Vector3(0, 1.38, 0)
		var seg := head - foot
		parts.append([_bx(Vector3(0.04, 0.04, seg.length())), Transform3D(Basis.looking_at(seg.normalized(), Vector3.FORWARD), (foot + head) * 0.5), dark])
	return parts


# ---------------------------------------------------------------------------
# Primitive helpers
# ---------------------------------------------------------------------------

func _m(key: String, color: Color, roughness: float) -> StandardMaterial3D:
	return b._mat("street_" + key, color, roughness)


func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


func _bx(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _cyl(top: float, bottom: float, height: float, segments := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


func _sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 1.7
	s.radial_segments = 10
	s.rings = 5
	return s
