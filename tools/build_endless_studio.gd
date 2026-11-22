extends "res://tools/build_endless_city.gd"
## Generator for the second Endless map, "Starlot Studios"
## (data/endless/endless_studio.tres): a haunted Hollywood movie backlot at
## night. Rebuilds scenes/levels/endless_studio.tscn to the scene contract in
## docs/ENDLESS.md, reusing the Ashfall City generator's helpers (gates,
## kit props, lights, the navigation bake and the static-mesh merge).
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_endless_studio.gd
##
## Run it with a renderer (not --headless), like the city's generator.
## NOTE: running this overwrites hand edits made to endless_studio.tscn.
##
## Layout (metres, top view; -Z = north; every floor at y 0):
##   Front Lot (start)      x -22..22, z -22..22: the water tower, trailers,
##                          a camera crane, the studio's main gate (south).
##   Western Street (west)  x -90..-34, z -10..10: false-front saloons, a
##                          painted desert flat with its scaffolding behind.
##   Soundstage 7 (east)    x 34..78, z -18..18 under a roof: a starship
##                          bridge set, a green screen, the lighting grid.
##   Monster Lot (north)    x -26..26, z -90..-44: a castle facade, a
##                          graveyard in fog, the studio's hanging moon.
##   Premiere Boulevard     x 36..96, z -86..-30: the red carpet up to the
##   (north-east)           Starlot Grand's marquee, searchlights, bleachers;
##                          gates from the Monster Lot and Soundstage 7.
## Everything that is not floor (districts, passages, alleys) is filled with
## solid blocks (the stages, the facades): no holes and no way out.

const STUDIO_OUT := "res://scenes/levels/endless_studio.tscn"
const FRONT := Rect2(-22.0, -22.0, 44.0, 44.0)
const WEST := Rect2(-90.0, -10.0, 56.0, 20.0)
const STAGE := Rect2(34.0, -18.0, 44.0, 36.0)
const MONSTER := Rect2(-26.0, -90.0, 52.0, 46.0)
const PREMIERE := Rect2(36.0, -86.0, 60.0, 56.0)
## Passages between districts (each holds a gate at its middle).
const PASSAGES := [Rect2(-34.0, -4.0, 12.0, 8.0), Rect2(22.0, -4.0, 12.0, 8.0), Rect2(-4.0, -44.0, 8.0, 22.0),
	Rect2(26.0, -70.0, 10.0, 8.0), Rect2(52.0, -30.0, 8.0, 12.0)]
## The ground the blocks fill, and the size of their cells (m).
const BOUNDS := Rect2(-106.0, -108.0, 216.0, 160.0)
const CELL := 1.0
const LOT_STATION := Vector3(0.0, 0.0, 6.0)
const STAGE_ROOF := 17.0
const MOON_DIRECTION := Vector3(-0.35, 0.62, -0.7)
## Merged static meshes are grouped in squares this big (m), so each stays
## within the renderer's per-object light limit.
const MERGE_CELL := 16.0

## [district, position, yaw, width, style, kit prefix, floor -Z, floor +Z].
const LOT_GATES := [
	[&"western_street", Vector3(-28.0, 0.0, 0.0), 90.0, 8.0, &"slide", "city_gate_fence", 0.0, 0.0],
	[&"soundstage", Vector3(28.0, 0.0, 0.0), 90.0, 8.0, &"shutter", "city_gate_shutter", 0.0, 0.0],
	[&"monster_lot", Vector3(0.0, 0.0, -33.0), 0.0, 8.0, &"slide", "city_gate_fence", 0.0, 0.0],
	[&"premiere", Vector3(31.0, 0.0, -66.0), 90.0, 8.0, &"slide", "city_gate_fence", 0.0, 0.0],
	[&"premiere", Vector3(56.0, 0.0, -24.0), 0.0, 8.0, &"shutter", "city_gate_shutter", 0.0, 0.0],
]

## [district, marker, yaw (as the city's: 180 = an alley to the north), alley
## floor (x, z, w, d)]. The blocks close each alley's far end.
const LOT_ENTRANCES := [
	[&"front_lot", Vector3(-16.5, 0, -28.0), 180.0, Rect2(-19.0, -34.0, 5.0, 12.0)],
	[&"front_lot", Vector3(16.5, 0, -28.0), 180.0, Rect2(14.0, -34.0, 5.0, 12.0)],
	[&"front_lot", Vector3(0.0, 0, 36.0), 0.0, Rect2(-10.0, 22.0, 20.0, 24.0)],
	[&"front_lot", Vector3(-28.0, 0, 14.0), -90.0, Rect2(-32.0, 12.0, 10.0, 4.0)],
	[&"front_lot", Vector3(28.0, 0, 14.0), 90.0, Rect2(22.0, 12.0, 10.0, 4.0)],
	[&"western_street", Vector3(-62.0, 0, -16.0), 180.0, Rect2(-64.0, -22.0, 4.0, 12.0)],
	[&"western_street", Vector3(-46.0, 0, 16.0), 0.0, Rect2(-48.0, 10.0, 4.0, 12.0)],
	[&"western_street", Vector3(-72.0, 0, 16.0), 0.0, Rect2(-74.0, 10.0, 4.0, 12.0)],
	[&"western_street", Vector3(-95.0, 0, 0.0), -90.0, Rect2(-100.0, -2.0, 10.0, 4.0)],
	[&"soundstage", Vector3(70.0, 0, -23.0), 180.0, Rect2(68.0, -27.0, 4.0, 9.0)],
	[&"soundstage", Vector3(56.0, 0, 23.0), 0.0, Rect2(54.0, 18.0, 4.0, 10.0)],
	[&"soundstage", Vector3(44.0, 0, 23.0), 0.0, Rect2(42.0, 18.0, 4.0, 10.0)],
	[&"soundstage", Vector3(68.0, 0, 23.0), 0.0, Rect2(66.0, 18.0, 4.0, 10.0)],
	[&"monster_lot", Vector3(-32.0, 0, -62.0), -90.0, Rect2(-38.0, -64.0, 12.0, 4.0)],
	[&"monster_lot", Vector3(30.0, 0, -50.0), 90.0, Rect2(26.0, -52.0, 8.0, 4.0)],
	[&"monster_lot", Vector3(0.0, 0, -97.0), 180.0, Rect2(-3.0, -104.0, 6.0, 14.0)],
	[&"monster_lot", Vector3(-20.0, 0, -39.0), 0.0, Rect2(-22.0, -44.0, 4.0, 8.0)],
	[&"premiere", Vector3(90.0, 0, -92.0), 180.0, Rect2(88.0, -98.0, 4.0, 12.0)],
	[&"premiere", Vector3(101.0, 0, -58.0), 90.0, Rect2(96.0, -60.0, 10.0, 4.0)],
	[&"premiere", Vector3(42.0, 0, -92.0), 180.0, Rect2(40.0, -98.0, 4.0, 12.0)],
	[&"premiere", Vector3(101.0, 0, -38.0), 90.0, Rect2(96.0, -40.0, 10.0, 4.0)],
]

## Western Street's buildings: [model, x, the street edge z, yaw]; the
## kit's fronts are +Z, so the north row faces south (yaw 0).
const WEST_FACADES := [
	["gulch_hotel", -72.75, -10.0, 0.0], ["gulch_saloon", -52.75, -10.0, 0.0], ["gulch_bank", -40.0, -10.0, 0.0],
	["gulch_livery", -82.5, 10.0, 180.0], ["gulch_store", -64.25, 10.0, 180.0], ["gulch_assay", -53.75, 10.0, 180.0],
	["gulch_sheriff", -39.75, 10.0, 180.0],
]

## [kind, district, position, yaw].
const LOT_FEATURES := [
	[&"trap_fire", &"western_street", Vector3(-62.0, 0, 0.0), 0.0],
	[&"trap_shock", &"soundstage", Vector3(50.0, 0, 4.0), 0.0],
	[&"trap_fire", &"monster_lot", Vector3(0.0, 0, -62.0), 0.0],
	[&"trap_shock", &"premiere", Vector3(74.0, 0, -52.0), 0.0],
	[&"supply_drop", &"front_lot", Vector3(-9.0, 0, 9.0), 0.0],
	[&"supply_drop", &"western_street", Vector3(-44.0, 0, 0.0), 0.0],
	[&"supply_drop", &"soundstage", Vector3(42.0, 0, -9.0), 0.0],
	[&"supply_drop", &"monster_lot", Vector3(12.0, 0, -56.0), 0.0],
	[&"supply_drop", &"premiere", Vector3(84.0, 0, -44.0), 0.0],
	[&"upgrade_bench", &"front_lot", Vector3(9.0, 0, 10.0), 0.0],
	[&"upgrade_bench", &"premiere", Vector3(39.5, 0, -50.0), 90.0],
]

var _part_id := 0
var _cyls := {}
var _kits := {}
## Walkable floor: the districts, passages and alleys.
var _walk: Array[Rect2] = []
## Ground the blocks leave to a model with its own collider (the facades).
var _no_block: Array[Rect2] = []


func _initialize() -> void:
	_rng.seed = 2424
	level = Node3D.new()
	level.name = "EndlessStudio"
	_studio_environment()
	var nav := NavigationRegion3D.new()
	nav.name = "NavigationRegion3D"
	level.add_child(nav)
	geo = Node3D.new()
	geo.name = "Geometry"
	nav.add_child(geo)
	dressing = Node3D.new()
	dressing.name = "Dressing"
	level.add_child(dressing)
	fx = Node3D.new()
	fx.name = "Effects"
	level.add_child(fx)

	_walk.append_array([FRONT, WEST, STAGE, MONSTER, PREMIERE])
	for p in PASSAGES:
		_walk.append(p)
	for e in LOT_ENTRANCES:
		_walk.append(e[3])
	for b in WEST_FACADES:
		_no_block.append(_facade_rect(b[0], Vector3(b[1], 0, b[2]), b[3]))
	_lot_ground()
	_lot_blocks()
	_lot_front()
	_lot_western()
	_lot_soundstage()
	_lot_monster()
	_lot_premiere()
	_lot_horizon()
	_lot_gates()
	_lot_mouths()
	_lot_markers()
	_lot_areas()
	_lot_features()

	get_root().add_child(level)
	await process_frame
	_bake_navigation(nav)
	get_root().remove_child(level)
	_compound_static()

	for entry in _late_scripts:
		var node: Node = entry[0]
		node.set_script(load(entry[1]))
		for key in entry[2]:
			node.set(key, entry[2][key])
	level.set_script(load("res://scripts/run/endless_studio_environment.gd"))
	var director := Node.new()
	director.name = "RunDirector"
	director.set_script(load("res://scripts/run/run_director.gd"))
	level.add_child(director)

	_own(level)
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, STUDIO_OUT)
	print("build_endless_studio: saved %s (error %d), %d omni lights" % [STUDIO_OUT, err, _light_count])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: a clear Hollywood night, a low cool moon, the city's glow
# ---------------------------------------------------------------------------

func _studio_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SHADERS + "mall_night_sky.gdshader")
	sky_mat.set_shader_parameter("zenith", Color(0.02, 0.03, 0.1))
	sky_mat.set_shader_parameter("horizon", Color(0.16, 0.1, 0.3))
	sky_mat.set_shader_parameter("haze", Color(0.62, 0.3, 0.45))
	sky_mat.set_shader_parameter("moon_dir", MOON_DIRECTION.normalized())
	sky_mat.set_shader_parameter("moon_size", 0.05)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.42, 0.62)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.4
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.16, 0.3)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	var moon := DirectionalLight3D.new()
	moon.name = "Sun"
	moon.transform = Transform3D(Basis.looking_at(-MOON_DIRECTION.normalized(), Vector3.UP), Vector3(0, 30, 0))
	moon.light_color = Color(0.62, 0.7, 1.0)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.shadow_bias = 0.06
	moon.shadow_normal_bias = 1.2
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 70.0
	moon.shadow_opacity = 0.75
	level.add_child(moon)
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.transform = Transform3D(Basis.looking_at(Vector3(0.4, -0.5, 0.75).normalized(), Vector3.UP), Vector3(0, 30, 0))
	fill.light_color = Color(0.85, 0.5, 0.75)
	fill.light_energy = 0.22
	fill.shadow_enabled = false
	level.add_child(fill)


# ---------------------------------------------------------------------------
# Ground: one slab under everything (collision), a floor per district
# ---------------------------------------------------------------------------

func _lot_ground() -> void:
	var holder := Node3D.new()
	holder.name = "Ground"
	geo.add_child(holder)
	_collider(holder, "GroundSlab", Vector3(BOUNDS.size.x, 1.0, BOUNDS.size.y), Vector3(BOUNDS.get_center().x, -0.5, BOUNDS.get_center().y))
	var asphalt := _surface("lot_asphalt", ["city_asphalt"], Color(0.62, 0.6, 0.66), 0.12, 0.75)
	var dirt := _surface("lot_dirt", ["gulch_dirt"], Color(0.9, 0.75, 0.6), 0.2, 0.95)
	var stage_floor := _surface("stage_floor", ["dune_concrete"], Color(0.3, 0.3, 0.34), 0.15, 0.35)
	var turf := _surface("lot_turf", ["fright_turf"], Color(0.55, 0.65, 0.6), 0.15, 0.95)
	var terrazzo := _surface("lot_terrazzo", ["city_sidewalk"], Color(0.78, 0.62, 0.66), 0.3, 0.45)
	_floor(holder, "FrontFloor", FRONT, asphalt)
	_floor(holder, "WestFloor", WEST, dirt)
	_floor(holder, "StageFloor", STAGE, stage_floor)
	_floor(holder, "MonsterFloor", MONSTER, turf)
	_floor(holder, "PremiereFloor", PREMIERE, terrazzo)
	var k := 0
	for p in PASSAGES:
		_floor(holder, "PassageFloor%d" % k, p, asphalt)
		k += 1
	k = 0
	for e in LOT_ENTRANCES:
		var r: Rect2 = e[3]
		var mat: Material = dirt if e[0] == &"western_street" else (turf if e[0] == &"monster_lot" else asphalt)
		_floor(holder, "AlleyFloor%d" % k, r, mat)
		k += 1


## A floor's visual: tiles no bigger than MERGE_CELL (each its own object, so
## it takes the lights nearest it), the material as an override so the merge
## leaves them be.
func _floor(parent: Node3D, floor_name: String, r: Rect2, material: Material, top := 0.005) -> void:
	var nx := maxi(1, ceili(r.size.x / MERGE_CELL))
	var nz := maxi(1, ceili(r.size.y / MERGE_CELL))
	var w := r.size.x / nx
	var d := r.size.y / nz
	for i in nx:
		for j in nz:
			var mi := MeshInstance3D.new()
			mi.name = "%s_%d_%d" % [floor_name, i, j]
			var plane := PlaneMesh.new()
			plane.size = Vector2(w, d)
			mi.mesh = plane
			mi.material_override = material
			mi.position = Vector3(r.position.x + w * (i + 0.5), top, r.position.y + d * (j + 0.5))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)


# ---------------------------------------------------------------------------
# Blocks: every cell of the ground that is not floor is solid, merged into
# boxes; heights and looks by the district they face
# ---------------------------------------------------------------------------

func _lot_blocks() -> void:
	var holder := Node3D.new()
	holder.name = "Blocks"
	geo.add_child(holder)
	var nx := int(BOUNDS.size.x / CELL)
	var nz := int(BOUNDS.size.y / CELL)
	# Each cell's style index (-1 = floor).
	var grid := PackedInt32Array()
	grid.resize(nx * nz)
	for j in nz:
		for i in nx:
			var p := Vector2(BOUNDS.position.x + (i + 0.5) * CELL, BOUNDS.position.y + (j + 0.5) * CELL)
			grid[j * nx + i] = -1 if _is_floor(p) or _no_block.any(func(r: Rect2) -> bool: return r.has_point(p)) else _block_style(p)
	# Greedy rectangles: run along x, then grow down z while the row matches.
	var used := PackedByteArray()
	used.resize(nx * nz)
	var count := 0
	for j in nz:
		for i in nx:
			var s := grid[j * nx + i]
			if s < 0 or used[j * nx + i] == 1:
				continue
			var w := 1
			while i + w < nx and grid[j * nx + i + w] == s and used[j * nx + i + w] == 0:
				w += 1
			var d := 1
			var grow := true
			while grow and j + d < nz:
				for k in w:
					if grid[(j + d) * nx + i + k] != s or used[(j + d) * nx + i + k] == 1:
						grow = false
						break
				if grow:
					d += 1
			for dz in d:
				for dx in w:
					used[(j + dz) * nx + i + dx] = 1
			var rect := Rect2(BOUNDS.position.x + i * CELL, BOUNDS.position.y + j * CELL, w * CELL, d * CELL)
			_block_box(holder, "Block%d" % count, rect, s)
			count += 1
	print("build_endless_studio: %d blocks" % count)


## True inside a district (not a passage or an alley: their walls stay plain).
func _faces_district(p: Vector2) -> bool:
	return [FRONT, WEST, STAGE, MONSTER, PREMIERE].any(func(r: Rect2) -> bool: return r.has_point(p))


func _is_floor(p: Vector2) -> bool:
	for r in _walk:
		if r.has_point(p):
			return true
	return false


## Block styles: 0 the stages round the Front Lot, 1 the Western's backs,
## 2 Soundstage 7's walls, 3 the Monster Lot's, 4 Premiere Boulevard's
## facades; +10 per storey band (height variation).
func _block_style(p: Vector2) -> int:
	var best := 0
	var best_d := 1e9
	var rects := [FRONT, WEST, STAGE, MONSTER, PREMIERE]
	for k in rects.size():
		var r: Rect2 = rects[k]
		var dx := maxf(0.0, maxf(r.position.x - p.x, p.x - r.end.x))
		var dz := maxf(0.0, maxf(r.position.y - p.y, p.y - r.end.y))
		var dist := Vector2(dx, dz).length()
		if dist < best_d:
			best_d = dist
			best = k
	var chunk := Vector2i(floori(p.x / 13.0), floori(p.y / 13.0))
	var band := int(absf(sin(chunk.x * 12.9898 + chunk.y * 78.233) * 43758.5453)) % 3
	if best == 1 or best == 2:
		band = 0
	return best + band * 10


## A block's height from its style (district and storey band).
func _style_height(style: int) -> float:
	var heights := [12.0, 7.0, STAGE_ROOF, 9.0, 12.0]
	var steps := [2.5, 0.0, 0.0, 2.0, 3.5]
	return heights[style % 10] + steps[style % 10] * floori(style / 10.0)


func _block_box(parent: Node3D, box_name: String, r: Rect2, style: int) -> void:
	var kind := style % 10
	var h := _style_height(style)
	var materials := [
		_surface("stage_stucco", ["city_concrete"], Color(0.92, 0.84, 0.7), 0.12, 0.85),
		_surface("west_backs", ["gulch_boards"], Color(0.45, 0.32, 0.24), 0.2, 0.9),
		_surface("stage_wall", ["city_concrete"], Color(0.2, 0.2, 0.24), 0.12, 0.9),
		_surface("monster_stone", ["faire_stone"], Color(0.35, 0.4, 0.45), 0.15, 0.9),
		_surface("deco_plaster", ["city_concrete"], Color(0.95, 0.72, 0.7), 0.12, 0.8),
	]
	var body := _box(parent, box_name, Vector3(r.size.x, h, r.size.y), Vector3(r.get_center().x, h * 0.5, r.get_center().y), materials[kind])
	(body.get_node("Mesh") as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_face_dressing(r, h, kind)
	if kind == 0 or kind == 4:
		# A darker plinth and a cap trim, so the blocks read as buildings.
		var trim := _mat("block_trim_%d" % kind, Color(0.55, 0.4, 0.38) if kind == 0 else Color(0.5, 0.25, 0.32), 0.8)
		_visual_box(dressing, box_name + "Cap", Vector3(r.size.x + 0.3, 0.45, r.size.y + 0.3), Vector3(r.get_center().x, h + 0.2, r.get_center().y), trim)
		_visual_box(dressing, box_name + "Plinth", Vector3(r.size.x + 0.12, 0.9, r.size.y + 0.12), Vector3(r.get_center().x, 0.45, r.get_center().y), trim)


## What a block shows on each side that faces a floor: the stages' ribs and
## a painted band, the boulevard's shop windows and awnings, the soundstage's
## dark acoustic ribs.
func _face_dressing(r: Rect2, h: float, kind: int) -> void:
	if kind == 1 or kind == 3:
		return
	var sides := [[Vector2(r.position.x, r.position.y), Vector2(1, 0), Vector2(0, -1), r.size.x],
		[Vector2(r.position.x, r.end.y), Vector2(1, 0), Vector2(0, 1), r.size.x],
		[Vector2(r.position.x, r.position.y), Vector2(0, 1), Vector2(-1, 0), r.size.y],
		[Vector2(r.end.x, r.position.y), Vector2(0, 1), Vector2(1, 0), r.size.y]]
	var rib := _mat("stage_rib", Color(0.8, 0.7, 0.58), 0.85) if kind == 0 else _mat("acoustic_rib", Color(0.1, 0.1, 0.12), 0.95)
	var band := _mat("stage_band", Color(0.55, 0.12, 0.14), 0.7)
	for side in sides:
		var start: Vector2 = side[0]
		var along: Vector2 = side[1]
		var out: Vector2 = side[2]
		var length: float = side[3]
		var yaw := atan2(along.y, along.x) * -1.0
		var step := 6.0 if kind == 4 else 4.0
		var n := int(length / step)
		for k in n:
			var t := (k + 0.5) * length / n
			var p := start + along * t
			if not _faces_district(p + out * 0.6):
				continue
			var at := Vector3(p.x + out.x * 0.12, 0, p.y + out.y * 0.12)
			match kind:
				0, 2:
					_part(dressing, Vector3(0.5, h - 0.4, 0.24), at + Vector3(0, (h - 0.4) * 0.5, 0), rib, Vector3(0, yaw, 0))
					if kind == 0:
						_part(dressing, Vector3(length / n + 0.02, 0.5, 0.2), at + Vector3(0, 3.8, 0), band, Vector3(0, yaw, 0))
				4:
					_storefront(at, yaw, Vector3(out.x, 0, out.y), k)


## A shop window with an awning on a boulevard facade, upper windows over it.
func _storefront(at: Vector3, yaw: float, out: Vector3, k: int) -> void:
	var colors := [Color(1.0, 0.75, 0.45), Color(1.0, 0.45, 0.65), Color(0.45, 0.85, 1.0), Color(1.0, 0.85, 0.55)]
	var c: Color = colors[(k + int(at.x * 0.37 + at.z * 0.21)) % 4]
	var glass := _mat("shop_glass_%d" % colors.find(c), c * 0.6, 0.3, c, 1.3)
	_part(dressing, Vector3(4.0, 2.2, 0.06), at + Vector3(0, 1.7, 0) + out * 0.02, glass, Vector3(0, yaw, 0))
	_part(dressing, Vector3(4.4, 0.25, 0.12), at + Vector3(0, 0.55, 0) + out * 0.05, _mat("deco_gold", Color(0.95, 0.72, 0.3), 0.3, Color(0.5, 0.35, 0.1), 0.4), Vector3(0, yaw, 0))
	var stripes := [_mat("awning_red", Color(0.7, 0.1, 0.15), 0.8), _mat("awning_teal", Color(0.1, 0.45, 0.5), 0.8), _mat("awning_cream", Color(0.92, 0.88, 0.78), 0.8)]
	_part(dressing, Vector3(4.4, 0.12, 1.2), at + Vector3(0, 3.25, 0) + out * 0.6, stripes[k % 3], Vector3(0, yaw, 0))
	for row in 2:
		for col in [-1.0, 1.0]:
			var lit := (k + row + int(col)) % 3 == 0
			var win := _mat("upper_lit", Color(1.0, 0.8, 0.5), 0.3, Color(1.0, 0.75, 0.45), 1.2) if lit else _mat("upper_dark", Color(0.12, 0.1, 0.16), 0.2)
			var right := Basis(Vector3.UP, yaw) * Vector3(1, 0, 0)
			_part(dressing, Vector3(1.1, 1.5, 0.06), at + right * col * 1.3 + Vector3(0, 6.0 + row * 3.0, 0) + out * 0.02, win, Vector3(0, yaw, 0))


# ---------------------------------------------------------------------------
# Front Lot: the station, the water tower, trailers, a crane, the main gate
# ---------------------------------------------------------------------------

func _lot_front() -> void:
	var lot := Node3D.new()
	lot.name = "FrontLot"
	geo.add_child(lot)
	var station_scene := PROPS + "mall_station.tscn"
	var station: Node3D = (load(station_scene) as PackedScene).instantiate()
	station.name = "Station"
	lot.add_child(station)
	station.position = LOT_STATION
	_omni(fx, "StationGlow", LOT_STATION + Vector3(0, 4.5, 2.0), Color(1.0, 0.75, 0.5), 1.0, 9.0)
	_water_tower(lot, Vector3(-14.0, 0, -13.0))
	_trailer(lot, "TrailerStar", Vector3(17.5, 0, -11.0), 90.0, Color(0.92, 0.88, 0.8), "STAR")
	_trailer(lot, "TrailerMakeup", Vector3(-17.5, 0, 8.5), -90.0, Color(0.75, 0.82, 0.9), "HAIR & MAKEUP")
	_crane(lot, "Crane", Vector3(-4.0, 0, -7.0), 35.0)
	_light_stand(lot, "LampA", Vector3(-10.0, 0, -3.0), 60.0, Color(1.0, 0.85, 0.65), true)
	_light_stand(lot, "LampB", Vector3(3.5, 0, -14.0), -20.0, Color(0.65, 0.8, 1.0), true)
	_light_stand(lot, "LampC", Vector3(12.0, 0, 1.0), -110.0, Color(1.0, 0.6, 0.4), true)
	for k in 3:
		_chair(lot, "Chair%d" % k, Vector3(6.0 + k * 1.2, 0, -7.5), 200.0, ["DIRECTOR", "PRODUCER", "STAR"][k])
	_craft_table(lot, "CraftServices", Vector3(8.0, 0, -15.5), 0.0)
	_golf_cart(lot, "GolfCart", Vector3(11.0, 0, -4.0), 25.0)
	_golf_cart(lot, "GolfCart2", Vector3(-9.0, 0, 15.5), -80.0)
	_apple_boxes(lot, "ApplesA", Vector3(-1.0, 0, -12.5), 10.0)
	_apple_boxes(lot, "ApplesB", Vector3(14.5, 0, 6.5), 70.0)
	_road_case(lot, "CaseA", Vector3(-12.0, 0, 3.0), 15.0)
	_road_case(lot, "CaseB", Vector3(13.5, 0, -18.0), 90.0)
	_film_cans(Vector3(-11.4, 0, 4.4))
	_film_cans(Vector3(13.8, 0, -16.6))
	_cable_run([Vector3(-4.0, 0, -7.0), Vector3(-7.5, 0, -4.0), Vector3(-10.0, 0, -3.0)])
	_cable_run([Vector3(3.5, 0, -14.0), Vector3(6.0, 0, -11.0), Vector3(12.0, 0, 1.0)])
	for p in [Vector3(-11.0, 0, -19.6), Vector3(19.6, 0, 19.6), Vector3(11.0, 0, -19.6), Vector3(-19.6, 0, 19.6)]:
		_lot_lamp(lot, p)
	# The stages round the lot: big painted numbers, red lights over the doors.
	_stage_face(Vector3(-9.0, 0, -22.0), 0.0, "3")
	_stage_face(Vector3(9.0, 0, -22.0), 0.0, "4")
	_stage_face(Vector3(-22.0, 0, -12.0), 90.0, "1")
	_stage_face(Vector3(22.0, 0, -13.0), -90.0, "7")
	_sign(Vector3(-22.05, 6.2, 0.0), 90.0, "BACKLOT  ·  WESTERN STREET", Color(1.0, 0.75, 0.4))
	_sign(Vector3(22.05, 6.2, 0.0), -90.0, "SOUNDSTAGE 7", Color(0.55, 0.85, 1.0))
	_sign(Vector3(0.0, 6.2, -22.05), 0.0, "MONSTER LOT", Color(0.55, 1.0, 0.7))
	_lot_markings()
	_billboard(Vector3(9.0, _style_height(_block_style(Vector2(9.0, -24.0))), -22.6))
	_wardrobe(lot, Vector3(-13.5, 0, 14.5), 90.0)
	for at in [Vector3(-6.5, 0, -10.5), Vector3(-1.5, 0, -3.5), Vector3(-7.5, 0, -2.0)]:
		_kit(dressing, "dune_cone", "Cone%d" % _part_id, at, at.x * 17.0, Vector3.ZERO)
		_part_id += 1
	_main_gate()
	_searchlight("SearchGateW", Vector3(-6.5, 0.8, 42.0), 18.0, 200.0, 0.0)
	_searchlight("SearchGateE", Vector3(6.5, 0.8, 42.0), 18.0, 160.0, 2.1)
	for z in [27.0, 33.0, 39.0]:
		_kit(dressing, "palm", "GatePalmW%d" % int(z), Vector3(-8.2, 0, z), z * 7.0, Vector3.ZERO)
		_kit(dressing, "palm", "GatePalmE%d" % int(z), Vector3(8.2, 0, z), z * 11.0, Vector3.ZERO)
		_post(lot, "GatePalmWPost%d" % int(z), 0.4, 3.0, Vector3(-8.2, 0, z))
		_post(lot, "GatePalmEPost%d" % int(z), 0.4, 3.0, Vector3(8.2, 0, z))


## A billboard on Stage 4's roof over the lot: the studio's next picture,
## lit by two lamps on its catwalk.
func _billboard(base: Vector3) -> void:
	var t := _node(dressing, "Billboard", base)
	var steel := _mat("escape_steel", Color(0.22, 0.22, 0.25), 0.5)
	for x in [-4.0, 0.0, 4.0]:
		_part(t, Vector3(0.3, 3.0, 0.3), Vector3(x, 1.5, -0.6), steel)
	_part(t, Vector3(11.0, 4.6, 0.3), Vector3(0, 5.3, 0), _mat("board_back", Color(0.12, 0.06, 0.16), 0.6))
	_part(t, Vector3(11.4, 0.3, 0.6), Vector3(0, 3.0, 0.2), steel)
	_part(t, Vector3(10.4, 0.35, 0.05), Vector3(0, 7.2, 0.17), _mat("board_band", Color(0.95, 0.72, 0.3), 0.4, Color(0.6, 0.4, 0.1), 0.8))
	var title := _label(dressing, "BillboardTitle", "WHAT LIES AHEAD", base + Vector3(0, 5.6, 0.2), 0.0, 230, Color(0.95, 0.25, 0.3))
	title.outline_modulate = Color(0.05, 0.0, 0.05)
	_label(dressing, "BillboardLine", "COMING SOON  ·  A STARLOT PICTURE", base + Vector3(0, 4.25, 0.2), 0.0, 90, Color(1.0, 0.9, 0.7))
	# The lamps sit on the catwalk's front edge, under the board's lettering.
	for x in [-4.6, 4.6]:
		_part(t, Vector3(0.5, 0.4, 0.6), Vector3(x, 3.35, 0.4), _mat("grip_black", Color(0.08, 0.08, 0.09), 0.5))
	_omni(fx, "BillboardLamp", base + Vector3(0, 4.0, 2.4), Color(1.0, 0.85, 0.65), 1.6, 9.0)


## Paint on the lot's asphalt: a dashed yellow lane round the middle and
## zebra stripes at the gates.
func _lot_markings() -> void:
	var yellow := _mat("lane_yellow", Color(0.95, 0.75, 0.2), 0.8)
	var white := _mat("lane_white", Color(0.9, 0.9, 0.88), 0.8)
	var dashes: Array[Transform3D] = []
	for k in 9:
		var t := -16.0 + k * 4.0
		for side in [-1.0, 1.0]:
			dashes.append(Transform3D(Basis(), Vector3(t, 0.015, side * 15.0)))
			dashes.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(side * 15.0, 0.015, t)))
	dressing.add_child(_multimesh("LaneDashes", _box_mesh(Vector3(2.0, 0.02, 0.18), yellow), dashes))
	var stripes: Array[Transform3D] = []
	for k in 6:
		stripes.append(Transform3D(Basis(), Vector3(-19.5, 0.015, -3.0 + k * 1.2)))
		stripes.append(Transform3D(Basis(), Vector3(19.5, 0.015, -3.0 + k * 1.2)))
		stripes.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-3.0 + k * 1.2, 0.015, -19.5)))
	dressing.add_child(_multimesh("Zebra", _box_mesh(Vector3(3.0, 0.02, 0.55), white), stripes))


## A rolling wardrobe rail hung with costumes.
func _wardrobe(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var t := _node(dressing, "Wardrobe", pos, yaw)
	var steel := _mat("grip_steel", Color(0.55, 0.57, 0.6), 0.35)
	for sx in [-1.2, 1.2]:
		_part(t, Vector3(0.05, 1.9, 0.05), Vector3(sx, 0.95, 0), steel)
		_part(t, Vector3(0.05, 0.05, 0.7), Vector3(sx, 0.1, 0), steel)
	_part(t, Vector3(2.5, 0.05, 0.05), Vector3(0, 1.88, 0), steel)
	var colors := [Color(0.75, 0.1, 0.15), Color(0.15, 0.25, 0.6), Color(0.9, 0.8, 0.3), Color(0.1, 0.1, 0.1), Color(0.4, 0.6, 0.3), Color(0.85, 0.85, 0.9)]
	for k in 9:
		var c: Color = colors[k % colors.size()]
		_part(t, Vector3(0.12, 1.0 + (k % 3) * 0.15, 0.55), Vector3(-1.0 + k * 0.25, 1.3 - (k % 3) * 0.07, 0), _mat("costume%d" % (k % colors.size()), c, 0.9))
	var c := _collider(parent, "WardrobeCollision", Vector3(2.6, 2.0, 0.8), pos + Vector3(0, 1.0, 0))
	c.rotation.y = deg_to_rad(yaw)


## The studio's water tower: four legs (zombies walk between them), a tank
## with the STARLOT name, a catwalk ring and a blinking red beacon.
func _water_tower(parent: Node3D, base: Vector3) -> void:
	var t := _node(dressing, "WaterTower", base)
	var steel := _mat("tower_steel", Color(0.62, 0.64, 0.7), 0.5)
	var tank := _mat("tower_tank", Color(0.86, 0.88, 0.92), 0.55)
	var legs := 2.6
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_part(t, Vector3(0.35, 14.0, 0.35), Vector3(sx * legs, 7.0, sz * legs), steel)
			_post(parent, "TowerLeg%d%d" % [int(sx), int(sz)], 0.3, 4.0, base + Vector3(sx * legs, 0, sz * legs))
	for y in [4.5, 9.0]:
		for side in 4:
			var yaw := side * PI * 0.5
			var b := Basis(Vector3.UP, yaw)
			_part(t, Vector3(legs * 2.0, 0.18, 0.18), b * Vector3(0, y, legs), steel, Vector3(0, yaw, 0))
			_part(t, Vector3(legs * 2.8, 0.12, 0.12), b * Vector3(0, y + 2.2, legs), steel, Vector3(0, yaw, 0.95))
	_cyl(t, 4.4, 0.25, Vector3(0, 14.0, 0), steel)
	_cyl(t, 3.8, 6.4, Vector3(0, 17.3, 0), tank)
	_cyl(t, 3.9, 0.3, Vector3(0, 15.0, 0), steel)
	_cyl(t, 3.9, 0.3, Vector3(0, 19.6, 0), steel)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.3
	roof.bottom_radius = 4.1
	roof.height = 2.4
	roof.radial_segments = 24
	roof.material = _mat("tower_roof", Color(0.55, 0.2, 0.18), 0.6)
	var r := MeshInstance3D.new()
	r.name = "Roof"
	r.mesh = roof
	r.position = Vector3(0, 21.7, 0)
	t.add_child(r)
	for k in 12:
		var a := k * TAU / 12.0
		_part(t, Vector3(0.08, 1.0, 0.08), Vector3(cos(a) * 4.35, 14.6, sin(a) * 4.35), steel)
	for yaw in [0.0, 90.0, 180.0, 270.0]:
		var dir := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 3.86)
		var l := _label(dressing, "TowerName%d" % int(yaw), "STARLOT", base + dir + Vector3(0, 17.8, 0), yaw, 300, Color(0.95, 0.3, 0.28))
		l.outline_modulate = Color(1, 1, 1)
		l.outline_size = 24
		l.shaded = true
		var star := _label(dressing, "TowerStar%d" % int(yaw), "STUDIOS", base + dir + Vector3(0, 16.0, 0), yaw, 120, Color(0.15, 0.2, 0.45))
		star.shaded = true
	var beacon := _omni(fx, "TowerBeacon", base + Vector3(0, 23.4, 0), Color(1.0, 0.15, 0.1), 1.6, 8.0)
	beacon.add_to_group("studio_beacon", true)
	var bulb := _visual_box(fx, "TowerBeaconBulb", Vector3(0.4, 0.4, 0.4), base + Vector3(0, 23.1, 0), _mat("beacon_red", Color(1, 0.2, 0.15), 0.4, Color(1, 0.15, 0.1), 6.0))
	bulb.add_to_group("studio_beacon", true)
	_omni(fx, "TowerWash", base + Vector3(0, 12.0, 4.5), Color(0.75, 0.8, 1.0), 1.4, 12.0)


## A production trailer: a long box on wheels with a door, lit windows,
## steps, an air conditioner and a name on the door.
func _trailer(parent: Node3D, trailer_name: String, pos: Vector3, yaw: float, color: Color, title: String) -> void:
	var t := _node(dressing, trailer_name, pos, yaw)
	var body := _mat("trailer_" + title, color, 0.55)
	var dark := _mat("trailer_dark", Color(0.12, 0.12, 0.14), 0.7)
	var window := _mat("trailer_window", Color(1.0, 0.8, 0.5), 0.3, Color(1.0, 0.72, 0.4), 1.6)
	var stripe := _mat("trailer_stripe", Color(0.75, 0.15, 0.2), 0.5)
	_part(t, Vector3(9.0, 2.6, 2.6), Vector3(0, 1.75, 0), body)
	_part(t, Vector3(9.02, 0.25, 2.62), Vector3(0, 1.2, 0), stripe)
	_part(t, Vector3(8.6, 0.12, 2.4), Vector3(0, 3.1, 0), body)
	_part(t, Vector3(1.4, 0.7, 1.0), Vector3(-2.0, 3.5, 0), _mat("ac_grey", Color(0.7, 0.72, 0.75), 0.6))
	for x in [-2.6, 1.0, 3.4]:
		_part(t, Vector3(1.3, 0.7, 0.06), Vector3(x, 2.25, 1.31), window)
	_part(t, Vector3(0.95, 2.0, 0.06), Vector3(-0.8, 1.6, 1.31), _mat("trailer_door", color.darkened(0.25), 0.5))
	_part(t, Vector3(1.2, 0.2, 0.9), Vector3(-0.8, 0.45, 1.8), dark)
	_part(t, Vector3(1.2, 0.2, 0.6), Vector3(-0.8, 0.2, 2.3), dark)
	for x in [-3.0, -2.0, 2.4, 3.4]:
		_cyl(t, 0.42, 0.3, Vector3(x, 0.42, 1.1), dark, Vector3(PI * 0.5, 0, 0))
		_cyl(t, 0.42, 0.3, Vector3(x, 0.42, -1.1), dark, Vector3(PI * 0.5, 0, 0))
	_part(t, Vector3(1.2, 0.22, 0.4), Vector3(-5.0, 0.5, 0), dark)
	var label := _label(dressing, trailer_name + "Name", title, Vector3.ZERO, 0.0, 64, Color(0.12, 0.1, 0.15))
	label.outline_size = 0
	label.shaded = true
	label.position = pos + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(-0.8, 2.25, 1.35)
	label.rotation.y = deg_to_rad(yaw)
	var light := _omni(fx, trailer_name + "Porch", pos + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(-0.8, 2.9, 2.0), Color(1.0, 0.75, 0.45), 0.9, 6.0)
	light.add_to_group("studio_flicker", true)
	var c := _collider(parent, trailer_name + "Collision", Vector3(9.2, 3.6, 2.7), pos + Vector3(0, 1.8, 0))
	c.rotation.y = deg_to_rad(yaw)


## A camera crane: a dolly on wheels, the column, the arm with its
## counterweights and a camera on a remote head over the action.
func _crane(parent: Node3D, crane_name: String, pos: Vector3, yaw: float) -> void:
	var t := _node(dressing, crane_name, pos, yaw)
	var black := _mat("grip_black", Color(0.08, 0.08, 0.09), 0.5)
	var steel := _mat("grip_steel", Color(0.55, 0.57, 0.6), 0.35)
	var yellow := _mat("grip_yellow", Color(0.95, 0.7, 0.1), 0.5)
	_part(t, Vector3(2.2, 0.5, 1.6), Vector3(0, 0.55, 0), black)
	for sx in [-0.9, 0.9]:
		for sz in [-0.7, 0.7]:
			_cyl(t, 0.25, 0.2, Vector3(sx, 0.25, sz), black, Vector3(PI * 0.5, 0, 0))
	_cyl(t, 0.22, 2.6, Vector3(0, 2.1, 0), steel)
	var arm := _node(t, "Arm", Vector3(0, 3.5, 0))
	arm.rotation.z = deg_to_rad(18.0)
	_part(arm, Vector3(9.0, 0.35, 0.35), Vector3(2.0, 0, 0), yellow)
	_part(arm, Vector3(8.0, 0.08, 0.08), Vector3(2.0, 0.45, 0), steel)
	for x in [-2.0, -2.35, -2.7]:
		_part(arm, Vector3(0.3, 0.8, 0.8), Vector3(x, -0.2, 0), black)
	_part(arm, Vector3(0.9, 0.7, 0.55), Vector3(6.7, -0.6, 0), black)
	_cyl(arm, 0.18, 0.6, Vector3(7.3, -0.6, 0), steel, Vector3(0, 0, PI * 0.5))
	var red := _visual_box(t, "Tally", Vector3(0.12, 0.12, 0.12), Vector3(0, 0, 0), _mat("tally_red", Color(1, 0.1, 0.1), 0.4, Color(1, 0.1, 0.1), 5.0))
	red.position = Vector3(0, 3.5, 0) + Basis(Vector3.BACK, deg_to_rad(18.0)) * Vector3(6.7, -0.2, 0)
	var c := _collider(parent, crane_name + "Collision", Vector3(2.3, 2.0, 1.7), pos + Vector3(0, 1.0, 0))
	c.rotation.y = deg_to_rad(yaw)


## A film light on a stand: three legs, a column and a lamp head with barn
## doors; lit ones throw a pool of light where they point.
func _light_stand(parent: Node3D, stand_name: String, pos: Vector3, yaw: float, color: Color, lit: bool, height := 3.2) -> void:
	var t := _node(dressing, stand_name, pos, yaw)
	var black := _mat("grip_black", Color(0.08, 0.08, 0.09), 0.5)
	var steel := _mat("grip_steel", Color(0.55, 0.57, 0.6), 0.35)
	for k in 3:
		var a := k * TAU / 3.0
		_part(t, Vector3(0.06, 1.3, 0.06), Vector3(cos(a) * 0.45, 0.5, sin(a) * 0.45), steel, Vector3(sin(a) * 0.6, 0, -cos(a) * 0.6))
	_cyl(t, 0.05, height, Vector3(0, height * 0.5, 0), steel)
	var head := _node(t, "Head", Vector3(0, height + 0.2, 0))
	head.rotation.x = deg_to_rad(-25.0)
	_part(head, Vector3(0.75, 0.7, 0.8), Vector3(0, 0, 0), black)
	var lens := _mat("lens_" + color.to_html(false), color, 0.2, color, 4.0 if lit else 0.3)
	_part(head, Vector3(0.6, 0.55, 0.04), Vector3(0, 0, 0.42), lens)
	for side in [-1.0, 1.0]:
		_part(head, Vector3(0.04, 0.6, 0.35), Vector3(side * 0.42, 0, 0.55), black, Vector3(0, side * 0.5, 0))
	_part(head, Vector3(0.6, 0.04, 0.3), Vector3(0, 0.38, 0.55), black, Vector3(-0.4, 0, 0))
	_post(parent, stand_name + "Post", 0.35, 2.0, pos)
	if lit:
		var b := Basis(Vector3.UP, deg_to_rad(yaw))
		_omni(fx, stand_name + "Light", pos + b * Vector3(0, height - 0.4, 2.2), color, 1.4, 9.0)


func _chair(parent: Node3D, chair_name: String, pos: Vector3, yaw: float, title: String) -> void:
	var t := _node(dressing, chair_name, pos, yaw)
	var wood := _mat("chair_wood", Color(0.45, 0.28, 0.15), 0.6)
	var canvas := _mat("chair_canvas", Color(0.1, 0.1, 0.12), 0.9)
	for sx in [-0.28, 0.28]:
		_part(t, Vector3(0.05, 0.9, 0.05), Vector3(sx, 0.45, 0.22), wood, Vector3(0.3, 0, 0))
		_part(t, Vector3(0.05, 0.9, 0.05), Vector3(sx, 0.45, -0.22), wood, Vector3(-0.3, 0, 0))
		_part(t, Vector3(0.05, 0.6, 0.05), Vector3(sx, 1.15, -0.25), wood)
		_part(t, Vector3(0.06, 0.05, 0.5), Vector3(sx, 0.95, 0), wood)
	_part(t, Vector3(0.56, 0.04, 0.42), Vector3(0, 0.85, 0), canvas)
	_part(t, Vector3(0.56, 0.3, 0.03), Vector3(0, 1.3, -0.26), canvas)
	var l := _label(dressing, chair_name + "Name", title, Vector3.ZERO, 0.0, 22, Color(1, 1, 1))
	l.outline_size = 0
	l.position = pos + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 1.3, -0.28)
	l.rotation.y = deg_to_rad(yaw + 180.0)
	_post(parent, chair_name + "Post", 0.3, 1.0, pos)


func _craft_table(parent: Node3D, table_name: String, pos: Vector3, yaw: float) -> void:
	var t := _node(dressing, table_name, pos, yaw)
	var cloth := _mat("craft_cloth", Color(0.85, 0.2, 0.22), 0.8)
	_part(t, Vector3(3.0, 0.08, 0.9), Vector3(0, 0.9, 0), _mat("craft_top", Color(0.9, 0.9, 0.88), 0.6))
	_part(t, Vector3(3.02, 0.6, 0.92), Vector3(0, 0.6, 0), cloth)
	var colors := [Color(0.95, 0.75, 0.2), Color(0.3, 0.7, 0.35), Color(0.9, 0.4, 0.15), Color(0.6, 0.35, 0.2)]
	for k in 6:
		_cyl(t, 0.16, 0.12, Vector3(-1.2 + k * 0.48, 1.0, 0.1), _mat("craft_food%d" % (k % 4), colors[k % 4], 0.7))
	_cyl(t, 0.18, 0.5, Vector3(1.25, 1.2, -0.2), _mat("urn", Color(0.75, 0.76, 0.8), 0.25))
	# A pop-up canopy over it.
	for sx in [-1.6, 1.6]:
		for sz in [-0.8, 0.8]:
			_part(t, Vector3(0.06, 2.6, 0.06), Vector3(sx, 1.3, sz), _mat("grip_steel", Color(0.55, 0.57, 0.6), 0.35))
	_part(t, Vector3(3.4, 0.1, 2.0), Vector3(0, 2.62, 0), _mat("canopy_white", Color(0.92, 0.9, 0.86), 0.8))
	var c := _collider(parent, table_name + "Collision", Vector3(3.1, 1.0, 1.0), pos + Vector3(0, 0.5, 0))
	c.rotation.y = deg_to_rad(yaw)
	_omni(fx, table_name + "Light", pos + Vector3(0, 2.3, 0.6), Color(1.0, 0.8, 0.55), 0.8, 5.0)


func _golf_cart(parent: Node3D, cart_name: String, pos: Vector3, yaw: float) -> void:
	var t := _node(dressing, cart_name, pos, yaw)
	var white := _mat("cart_white", Color(0.9, 0.9, 0.88), 0.45)
	var black := _mat("grip_black", Color(0.08, 0.08, 0.09), 0.5)
	_part(t, Vector3(2.4, 0.5, 1.2), Vector3(0, 0.55, 0), white)
	_part(t, Vector3(0.6, 0.5, 1.15), Vector3(0.85, 0.95, 0), white)
	_part(t, Vector3(0.7, 0.18, 1.0), Vector3(-0.1, 0.9, 0), _mat("cart_seat", Color(0.55, 0.12, 0.15), 0.7))
	_part(t, Vector3(0.1, 0.55, 1.0), Vector3(-0.45, 1.2, 0), _mat("cart_seat", Color(0.55, 0.12, 0.15), 0.7))
	for sx in [-0.5, 0.95]:
		for sz in [-0.55, 0.55]:
			_part(t, Vector3(0.05, 1.3, 0.05), Vector3(sx, 1.45, sz), black)
	_part(t, Vector3(1.8, 0.08, 1.25), Vector3(0.2, 2.1, 0), white)
	for sx in [-0.8, 0.8]:
		for sz in [-0.6, 0.6]:
			_cyl(t, 0.25, 0.18, Vector3(sx, 0.25, sz), black, Vector3(PI * 0.5, 0, 0))
	var c := _collider(parent, cart_name + "Collision", Vector3(2.5, 1.4, 1.3), pos + Vector3(0, 0.7, 0))
	c.rotation.y = deg_to_rad(yaw)


func _apple_boxes(parent: Node3D, boxes_name: String, pos: Vector3, yaw: float) -> void:
	var t := _node(dressing, boxes_name, pos, yaw)
	var ply := _mat("apple_box", Color(0.75, 0.58, 0.36), 0.8)
	_part(t, Vector3(0.6, 0.3, 0.45), Vector3(0, 0.15, 0), ply)
	_part(t, Vector3(0.6, 0.3, 0.45), Vector3(0.05, 0.45, 0.02), ply, Vector3(0, 0.3, 0))
	_part(t, Vector3(0.6, 0.15, 0.45), Vector3(0.7, 0.075, 0.1), ply, Vector3(0, -0.4, 0))
	_post(parent, boxes_name + "Post", 0.5, 0.8, pos)


func _road_case(parent: Node3D, case_name: String, pos: Vector3, yaw: float) -> void:
	var t := _node(dressing, case_name, pos, yaw)
	var black := _mat("case_black", Color(0.07, 0.07, 0.08), 0.7)
	var chrome := _mat("case_chrome", Color(0.8, 0.82, 0.85), 0.2)
	_part(t, Vector3(1.6, 1.0, 0.8), Vector3(0, 0.5, 0), black)
	_part(t, Vector3(1.62, 0.06, 0.82), Vector3(0, 0.98, 0), chrome)
	_part(t, Vector3(1.62, 0.06, 0.82), Vector3(0, 0.05, 0), chrome)
	_part(t, Vector3(1.2, 0.7, 0.6), Vector3(0.1, 1.35, 0), black, Vector3(0, 0.2, 0))
	_part(t, Vector3(1.22, 0.05, 0.62), Vector3(0.1, 1.68, 0), chrome, Vector3(0, 0.2, 0))
	var stencil := _label(dressing, case_name + "Stencil", "STARLOT", Vector3.ZERO, 0.0, 40, Color(0.95, 0.85, 0.5))
	stencil.outline_size = 0
	stencil.position = pos + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0.55, 0.41)
	stencil.rotation.y = deg_to_rad(yaw)
	var c := _collider(parent, case_name + "Collision", Vector3(1.7, 1.7, 0.9), pos + Vector3(0, 0.85, 0))
	c.rotation.y = deg_to_rad(yaw)


func _film_cans(pos: Vector3) -> void:
	var t := _node(dressing, "FilmCans%d" % _part_id, pos)
	var tin := _mat("film_tin", Color(0.62, 0.62, 0.66), 0.3)
	for k in 5:
		_cyl(t, 0.32, 0.07, Vector3(0, 0.04 + k * 0.075, 0), tin, Vector3(0, k * 0.4, 0))


## Black cable lying on the floor along `points`.
func _cable_run(points: Array) -> void:
	var cable := _mat("cable", Color(0.05, 0.05, 0.05), 0.6)
	for k in points.size() - 1:
		var a: Vector3 = points[k]
		var b: Vector3 = points[k + 1]
		var mid := (a + b) * 0.5 + Vector3(0, 0.03, 0)
		var dir := b - a
		_part(dressing, Vector3(dir.length(), 0.05, 0.05), mid, cable, Vector3(0, atan2(-dir.z, dir.x), 0))


func _lot_lamp(parent: Node3D, pos: Vector3) -> void:
	_kit(dressing, "lamp_post", "LotLamp%d" % _part_id, pos, 0.0, Vector3.ZERO)
	_part_id += 1
	_post(parent, "LotLampPost%d" % _part_id, 0.2, 3.0, pos)
	_omni(fx, "LotLampLight%d" % _part_id, pos + Vector3(0, 4.6, 0), Color(1.0, 0.82, 0.6), 1.2, 10.0)


## A soundstage's face over the lot: its number painted huge, a red
## "ROLLING" lamp over a stage door, a wall lamp and a fire escape.
func _stage_face(foot: Vector3, yaw: float, number: String) -> void:
	var out := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)
	var right := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(1, 0, 0)
	var face := foot + out * 0.05
	var big := _label(dressing, "StageNo" + number, number, face + Vector3(0, 7.4, 0), yaw, 600, Color(0.75, 0.2, 0.18))
	big.pixel_size = 0.012
	big.outline_size = 0
	big.shaded = true
	var word := _label(dressing, "StageWord" + number, "STAGE", face + Vector3(0, 3.6, 0) + right * 0.0, yaw, 180, Color(0.75, 0.2, 0.18))
	word.outline_size = 0
	word.shaded = true
	_part(dressing, Vector3(1.6, 2.6, 0.12), face + right * 3.5 + Vector3(0, 1.3, 0), _mat("stage_door", Color(0.35, 0.36, 0.4), 0.5), Vector3(0, deg_to_rad(yaw), 0))
	var lamp := _part(dressing, Vector3(0.5, 0.3, 0.25), face + right * 3.5 + Vector3(0, 3.1, 0.12), _mat("rolling_red", Color(1, 0.15, 0.1), 0.4, Color(1, 0.12, 0.08), 5.0), Vector3(0, deg_to_rad(yaw), 0))
	lamp.position = face + right * 3.5 + Vector3(0, 3.1, 0) + out * 0.15
	var red := _omni(fx, "Rolling" + number, face + right * 3.5 + Vector3(0, 3.0, 0) + out * 0.8, Color(1.0, 0.2, 0.12), 0.9, 5.0)
	red.add_to_group("studio_flicker", true)
	_label(dressing, "Quiet" + number, "QUIET PLEASE", face + right * 3.5 + Vector3(0, 3.6, 0) + out * 0.05, yaw, 40, Color(1, 0.85, 0.8))
	_omni(fx, "StageWash" + number, face + Vector3(0, 9.5, 0) + out * 2.5, Color(1.0, 0.8, 0.62), 1.2, 11.0)
	# Fire escape: landings and a stair run.
	var steel := _mat("escape_steel", Color(0.22, 0.22, 0.25), 0.5)
	for y in [4.5, 8.5]:
		_part(dressing, Vector3(3.2, 0.12, 1.1), face - right * 3.2 + Vector3(0, y, 0) + out * 0.55, steel, Vector3(0, deg_to_rad(yaw), 0))
		_part(dressing, Vector3(3.2, 0.9, 0.05), face - right * 3.2 + Vector3(0, y + 0.5, 0) + out * 1.1, steel, Vector3(0, deg_to_rad(yaw), 0))
	_part(dressing, Vector3(4.6, 0.1, 0.9), face - right * 3.2 + Vector3(0, 6.5, 0) + out * 0.55, steel, Vector3(0, deg_to_rad(yaw), 0.75))


## A painted sign board over a gate, with a lamp on it.
func _sign(pos: Vector3, yaw: float, text: String, color: Color) -> void:
	var out := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)
	_part(dressing, Vector3(maxf(6.0, text.length() * 0.42), 1.1, 0.12), pos + out * 0.06, _mat("sign_board", Color(0.1, 0.08, 0.14), 0.6), Vector3(0, deg_to_rad(yaw), 0))
	_label(dressing, "Sign%d" % _part_id, text, pos + out * 0.14, yaw, 90, color)
	_part_id += 1
	_omni(fx, "SignLight%d" % _part_id, pos + out * 1.2 + Vector3(0, 0.9, 0), color, 0.7, 4.0)


## The studio's main gate (south): two pillars, an arch with the studio's
## name in lights and the iron gates pushed open (the zombies' way in).
func _main_gate() -> void:
	var stucco := _mat("gate_stucco", Color(0.95, 0.9, 0.78), 0.8)
	var trim := _mat("gate_trim", Color(0.75, 0.55, 0.3), 0.5)
	for side in [-1.0, 1.0]:
		var x: float = side * 11.2
		_box(geo, "GatePillar%s" % ("W" if side < 0 else "E"), Vector3(2.4, 9.0, 2.4), Vector3(x, 4.5, 22.6), stucco)
		_visual_box(dressing, "GatePillarCap%s" % ("W" if side < 0 else "E"), Vector3(2.8, 0.5, 2.8), Vector3(x, 9.25, 22.6), trim)
		_cyl(dressing, 0.45, 0.6, Vector3(x, 9.8, 22.6), _mat("gate_globe", Color(1, 0.9, 0.7), 0.3, Color(1.0, 0.85, 0.6), 3.0))
		_omni(fx, "GateGlobe%s" % ("W" if side < 0 else "E"), Vector3(x, 10.2, 21.0), Color(1.0, 0.82, 0.55), 1.4, 10.0)
		# The iron gate's leaf, swung open toward the street.
		var leaf := _node(dressing, "GateLeaf%s" % ("W" if side < 0 else "E"), Vector3(side * 9.85, 0, 22.9), side * 90.0)
		var iron := _mat("gate_iron", Color(0.1, 0.1, 0.12), 0.5)
		for k in 9:
			_part(leaf, Vector3(0.07, 3.6, 0.07), Vector3(-side * (0.3 + k * 0.5), 1.8, 0), iron)
		_part(leaf, Vector3(4.6, 0.12, 0.1), Vector3(-side * 2.3, 0.4, 0), iron)
		_part(leaf, Vector3(4.6, 0.12, 0.1), Vector3(-side * 2.3, 3.4, 0), iron)
	var arch := _node(dressing, "GateArch", Vector3(0, 0, 22.6))
	_part(arch, Vector3(20.0, 1.8, 1.2), Vector3(0, 8.1, 0), stucco)
	_part(arch, Vector3(20.2, 0.25, 1.3), Vector3(0, 7.2, 0), trim)
	_part(arch, Vector3(20.2, 0.25, 1.3), Vector3(0, 9.0, 0), trim)
	_part(arch, Vector3(7.0, 2.0, 0.9), Vector3(0, 10.0, 0), stucco)
	for side in [-1.0, 1.0]:
		var name_label := _label(dressing, "GateName%s" % ("N" if side < 0 else "S"), "STARLOT STUDIOS", Vector3(0, 8.1, 22.6 + side * 0.62), 0.0 if side > 0 else 180.0, 210, Color(1.0, 0.85, 0.45))
		name_label.outline_modulate = Color(0.35, 0.15, 0.05)
		var est := _label(dressing, "GateEst%s" % ("N" if side < 0 else "S"), "EST.  1927", Vector3(0, 10.1, 22.6 + side * 0.47), 0.0 if side > 0 else 180.0, 90, Color(0.95, 0.75, 0.4))
		est.outline_modulate = Color(0.35, 0.15, 0.05)
		_marquee_strip(Vector3(0, 6.95, 22.6 + side * 0.62), 0.0 if side > 0 else 180.0, 19.8, 0.22, 60.0)
	_player_wall(_player_walls(), "MainGate", Vector3(-10.0, 0, 22.4), Vector3(10.0, 0, 22.4), WALL_H)
	# A guard booth beside the gate, inside the lot.
	var booth := _node(dressing, "GuardBooth", Vector3(15.5, 0, 19.0))
	_part(booth, Vector3(2.4, 2.6, 2.0), Vector3(0, 1.3, 0), stucco)
	_part(booth, Vector3(2.6, 0.2, 2.2), Vector3(0, 2.7, 0), trim)
	_part(booth, Vector3(1.6, 0.8, 0.05), Vector3(0, 1.6, -1.01), _mat("booth_glass", Color(1.0, 0.8, 0.5), 0.2, Color(1.0, 0.75, 0.45), 1.4))
	_collider(geo, "GuardBoothCollision", Vector3(2.5, 2.8, 2.1), Vector3(15.5, 1.4, 19.0))
	_omni(fx, "BoothLight", Vector3(15.5, 2.4, 17.4), Color(1.0, 0.8, 0.5), 0.8, 5.0)
	# The street beyond the gate ends at a row of shops.
	for k in 3:
		var x := -6.6 + k * 6.6
		_label(dressing, "GowerShop%d" % k, ["DINER", "CAMERAS", "COCKTAILS"][k], Vector3(x, 5.0, 45.9), 180.0, 120, [Color(1.0, 0.35, 0.6), Color(0.4, 0.9, 1.0), Color(1.0, 0.8, 0.3)][k])
		_omni(fx, "GowerGlow%d" % k, Vector3(x, 4.0, 44.0), [Color(1.0, 0.35, 0.6), Color(0.4, 0.9, 1.0), Color(1.0, 0.8, 0.3)][k], 1.0, 7.0)


## A strip of `bulbs` chasing bulbs facing `yaw` (studio_marquee shader).
func _marquee_strip(pos: Vector3, yaw: float, length: float, height: float, bulbs: float, color := Color(1.0, 0.82, 0.45)) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(length, height)
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "studio_marquee.gdshader")
	# A tall strip runs its bulbs down (rows) instead of along.
	m.set_shader_parameter("bulbs", bulbs if length >= height else 1.0)
	m.set_shader_parameter("rows", 1.0 if length >= height else bulbs)
	m.set_shader_parameter("bulb_color", color)
	quad.material = m
	var mi := MeshInstance3D.new()
	mi.name = "Marquee%d" % _part_id
	_part_id += 1
	mi.mesh = quad
	mi.position = pos
	mi.rotation.y = deg_to_rad(yaw)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(mi)


# ---------------------------------------------------------------------------
# Western Street: false fronts down a dirt street, a painted desert flat
# ---------------------------------------------------------------------------

func _lot_western() -> void:
	var w := Node3D.new()
	w.name = "Western"
	geo.add_child(w)
	for b in WEST_FACADES:
		_facade(w, b[0], Vector3(b[1], 0, b[2]), b[3])
	_backdrop("DesertFlat", Vector3(-80.0, 0, 0.0), 90.0, 12.0, 9.0, 0)
	# Props down the street: a wagon, hay, barrels, troughs, hitching rails.
	_solid_kit(w, "gulch_wagon", "Wagon", Vector3(-58.0, 0, 3.5), 80.0, Vector3(2.2, 2.6, 5.5))
	_solid_kit(w, "gulch_hay", "HayA", Vector3(-68.0, 0, -6.5), 20.0, Vector3(1.6, 1.6, 1.0))
	_solid_kit(w, "gulch_hay", "HayB", Vector3(-46.0, 0, 6.6), -15.0, Vector3(1.6, 1.6, 1.0))
	_solid_kit(w, "gulch_barrels", "BarrelsA", Vector3(-50.0, 0, -7.0), 0.0, Vector3(1.5, 1.8, 0.9))
	_solid_kit(w, "gulch_barrels", "BarrelsB", Vector3(-76.0, 0, 7.4), 90.0, Vector3(1.5, 1.8, 0.9))
	_solid_kit(w, "gulch_trough", "Trough", Vector3(-55.0, 0, -7.6), 0.0, Vector3(2.4, 0.8, 0.8))
	_solid_kit(w, "gulch_hitch", "HitchA", Vector3(-48.0, 0, -7.8), 0.0, Vector3(3.0, 1.1, 0.2))
	_solid_kit(w, "gulch_hitch", "HitchB", Vector3(-67.0, 0, 7.8), 180.0, Vector3(3.0, 1.1, 0.2))
	for p in [[-77.5, -3.5], [-77.8, 4.0], [-76.5, 0.5]]:
		_solid_kit(w, "gulch_cactus_a", "SetCactus%d" % int(p[1]), Vector3(p[0], 0, p[1]), p[1] * 20.0, Vector3(0.6, 3.6, 0.6))
	for x in [-70.0, -58.0, -45.0]:
		for side in [-1.0, 1.0]:
			_kit(dressing, "gulch_lamp", "WestLamp%d%d" % [int(x), int(side)], Vector3(x, 0, side * 8.6), 0.0 if side < 0 else 180.0, Vector3.ZERO)
			_post(w, "WestLampPost%d%d" % [int(x), int(side)], 0.2, 3.0, Vector3(x, 0, side * 8.6))
			_omni(fx, "WestLampLight%d%d" % [int(x), int(side)], Vector3(x, 2.8, side * 8.2), Color(1.0, 0.65, 0.3), 1.2, 8.0)
	# Magic hour, on a night shoot: big tungsten lights on the street.
	_light_stand(w, "WestKey", Vector3(-38.0, 0, -6.5), -120.0, Color(1.0, 0.62, 0.32), true, 4.5)
	_light_stand(w, "WestFill", Vector3(-66.0, 0, 6.5), 30.0, Color(1.0, 0.55, 0.3), true, 4.5)
	_omni(fx, "DesertFlatWash", Vector3(-74.0, 6.0, 0.0), Color(1.0, 0.55, 0.3), 1.3, 13.0)
	_dolly_track(w, Vector3(-44.0, 0, -2.0), 90.0, 10.0)
	# A lighting truss slung across the street between the false fronts.
	var truss := _mat("truss_alu", Color(0.7, 0.72, 0.76), 0.3)
	_part(dressing, Vector3(0.4, 0.4, 22.0), Vector3(-56.0, 9.0, 0.0), truss)
	_part(dressing, Vector3(0.06, 0.06, 22.0), Vector3(-56.0, 9.45, 0.2), truss)
	for z in [-5.0, 0.0, 5.0]:
		var lamp := _node(dressing, "StreetLamp%d" % int(z), Vector3(-56.0, 8.4, z))
		lamp.rotation.x = deg_to_rad(-90.0)
		_part(lamp, Vector3(0.6, 0.6, 0.7), Vector3.ZERO, _mat("grip_black", Color(0.08, 0.08, 0.09), 0.5))
		_part(lamp, Vector3(0.5, 0.5, 0.04), Vector3(0, 0, 0.37), _mat("lens_ffb070", Color(1.0, 0.69, 0.44), 0.2, Color(1.0, 0.69, 0.44), 4.0))
	_omni(fx, "StreetTrussLight", Vector3(-56.0, 6.0, 0.0), Color(1.0, 0.7, 0.45), 1.3, 12.0)
	_chair(w, "WestChair", Vector3(-36.5, 0, 5.0), 250.0, "DIRECTOR")


## The model's origin that puts its front (the porch, its +Z face) on the
## street edge `front`.
func _facade_origin(aabb: AABB, front: Vector3, yaw: float) -> Vector3:
	return front - Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, aabb.end.z)


## A facade's footprint on the ground (the blocks leave it to the model).
func _facade_rect(model: String, front: Vector3, yaw: float) -> Rect2:
	var aabb := _model_aabb(model)
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), _facade_origin(aabb, front, yaw))
	var box := xf * aabb
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)


## A false-front building from the Gold Rush kit: collides over its whole
## footprint, and timber bracing stands up behind it (it is a set).
func _facade(parent: Node3D, model: String, front: Vector3, yaw: float) -> void:
	var aabb := _model_aabb(model)
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	var origin := _facade_origin(aabb, front, yaw)
	_kit(dressing, model, "Facade_" + model, origin, yaw, Vector3(10, 8, 10))
	var body := _collider(parent, "Facade_%sCollision" % model, aabb.size, origin + b * aabb.get_center())
	body.rotation.y = deg_to_rad(yaw)
	var timber := _mat("brace_timber", Color(0.5, 0.36, 0.22), 0.9)
	var back := origin + b * Vector3(0, 0, aabb.position.z + 0.6)
	for k in 3:
		var x := (k - 1) * aabb.size.x * 0.35
		_part(dressing, Vector3(0.2, aabb.size.y + 2.5, 0.2), back + b * Vector3(x, 0, 0) + Vector3(0, (aabb.size.y + 2.5) * 0.5, 0), timber, Vector3(0, deg_to_rad(yaw), 0))
		_part(dressing, Vector3(0.16, aabb.size.y * 0.9, 0.16), back + b * Vector3(x, 0, 2.0) + Vector3(0, aabb.size.y * 0.55, 0), timber, Vector3(deg_to_rad(-22.0), deg_to_rad(yaw), 0))


## A painted flat on a timber frame: the painting faces `yaw`, braces and
## sandbags behind it (the backstage side shows how it is made).
func _backdrop(flat_name: String, centre: Vector3, yaw: float, width: float, height: float, scene: int) -> void:
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "studio_backdrop.gdshader")
	m.set_shader_parameter("scene", scene)
	m.set_shader_parameter("strength", 0.95)
	quad.material = m
	var mi := MeshInstance3D.new()
	mi.name = flat_name
	mi.mesh = quad
	mi.position = centre + Vector3(0, height * 0.5 + 0.2, 0)
	mi.rotation.y = deg_to_rad(yaw)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(mi)
	var timber := _mat("brace_timber", Color(0.5, 0.36, 0.22), 0.9)
	var ply := _mat("flat_back", Color(0.7, 0.62, 0.5), 0.9)
	_part(dressing, Vector3(width, height, 0.1), centre + b * Vector3(0, 0, -0.08) + Vector3(0, height * 0.5 + 0.2, 0), ply, Vector3(0, deg_to_rad(yaw), 0))
	var bags := _mat("sandbag", Color(0.45, 0.4, 0.3), 0.95)
	var n := int(width / 2.0) + 1
	for k in n:
		var x := -width * 0.5 + width * k / (n - 1)
		_part(dressing, Vector3(0.18, height + 0.2, 0.18), centre + b * Vector3(x, 0, -0.25) + Vector3(0, height * 0.5 + 0.1, 0), timber, Vector3(0, deg_to_rad(yaw), 0))
		if k % 2 == 0:
			_part(dressing, Vector3(0.14, height * 0.75, 0.14), centre + b * Vector3(x, 0, -1.6) + Vector3(0, height * 0.37, 0), timber, Vector3(deg_to_rad(28.0), deg_to_rad(yaw), 0))
			_part(dressing, Vector3(0.6, 0.25, 0.4), centre + b * Vector3(x, 0, -2.9) + Vector3(0, 0.12, 0), bags, Vector3(0, deg_to_rad(yaw), 0))
	for y in [0.5, height * 0.5, height - 0.2]:
		_part(dressing, Vector3(width, 0.14, 0.14), centre + b * Vector3(0, 0, -0.25) + Vector3(0, y, 0), timber, Vector3(0, deg_to_rad(yaw), 0))
	var body := _collider(geo, flat_name + "Collision", Vector3(width, height, 0.5), centre + b * Vector3(0, 0, -0.2) + Vector3(0, height * 0.5, 0))
	body.rotation.y = deg_to_rad(yaw)
	# The bracing's feet (the sandbagged jacks) are solid too.
	var jacks := _collider(geo, flat_name + "Jacks", Vector3(width, 1.2, 2.8), centre + b * Vector3(0, 0, -1.8) + Vector3(0, 0.6, 0))
	jacks.rotation.y = deg_to_rad(yaw)


## Dolly track on the ground with a camera on its dolly.
func _dolly_track(parent: Node3D, pos: Vector3, yaw: float, length: float) -> void:
	var t := _node(dressing, "Dolly%d" % _part_id, pos, yaw)
	_part_id += 1
	var steel := _mat("grip_steel", Color(0.55, 0.57, 0.6), 0.35)
	var wood := _mat("apple_box", Color(0.75, 0.58, 0.36), 0.8)
	for side in [-0.35, 0.35]:
		_part(t, Vector3(length, 0.06, 0.06), Vector3(0, 0.08, side), steel)
	for k in int(length / 0.8):
		_part(t, Vector3(0.12, 0.04, 0.9), Vector3(-length * 0.5 + 0.4 + k * 0.8, 0.02, 0), wood)
	var black := _mat("grip_black", Color(0.08, 0.08, 0.09), 0.5)
	_part(t, Vector3(1.2, 0.4, 0.9), Vector3(1.0, 0.35, 0), black)
	_cyl(t, 0.08, 0.9, Vector3(1.0, 1.0, 0), steel)
	_part(t, Vector3(0.8, 0.5, 0.35), Vector3(1.0, 1.65, 0), black)
	_cyl(t, 0.14, 0.4, Vector3(1.55, 1.65, 0), black, Vector3(0, 0, PI * 0.5))
	_cyl(t, 0.22, 0.12, Vector3(0.9, 2.05, 0.0), black, Vector3(PI * 0.5, 0, 0))
	_cyl(t, 0.22, 0.12, Vector3(1.3, 2.05, 0.0), black, Vector3(PI * 0.5, 0, 0))
	var c := _collider(parent, "DollyCollision%d" % _part_id, Vector3(1.3, 2.0, 1.0), pos + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(1.0, 0, 0) + Vector3(0, 1.0, 0))
	c.rotation.y = deg_to_rad(yaw)


# ---------------------------------------------------------------------------
# Soundstage 7: a starship bridge set under the lighting grid
# ---------------------------------------------------------------------------

func _lot_soundstage() -> void:
	var s := Node3D.new()
	s.name = "Soundstage"
	geo.add_child(s)
	var roof := _visual_box(dressing, "StageRoof", Vector3(STAGE.size.x + 4.0, 0.6, STAGE.size.y + 4.0), Vector3(STAGE.get_center().x, STAGE_ROOF + 0.3, STAGE.get_center().y), _mat("stage_roof", Color(0.12, 0.12, 0.14), 0.9))
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# The viewscreen and the bridge's hull wall on the east side.
	_backdrop("Viewscreen", Vector3(76.8, 0, 0.0), -90.0, 20.0, 8.5, 1)
	var hull := _mat("hull_panel", Color(0.55, 0.58, 0.66), 0.4)
	var neon := _mat("bridge_neon", Color(0.3, 0.9, 1.0), 0.3, Color(0.3, 0.9, 1.0), 5.0)
	var red := _mat("bridge_red", Color(1.0, 0.2, 0.25), 0.3, Color(1.0, 0.18, 0.2), 4.0)
	for side in [-1.0, 1.0]:
		var z: float = side * 11.0
		# The set's walls: panels with light strips, braces showing behind.
		for k in 4:
			var x := 58.0 + k * 4.6
			_box(s, "BridgeWall%d%d" % [k, int(side)], Vector3(4.2, 5.0, 0.4), Vector3(x, 2.5, z), hull)
			_visual_box(dressing, "BridgeStrip%d%d" % [k, int(side)], Vector3(3.8, 0.12, 0.05), Vector3(x, 3.8, z - side * 0.22), neon)
			_visual_box(dressing, "BridgeStripLow%d%d" % [k, int(side)], Vector3(3.8, 0.08, 0.05), Vector3(x, 0.6, z - side * 0.22), red if k % 2 == 0 else neon)
			_part(dressing, Vector3(0.14, 4.8, 0.14), Vector3(x, 2.4, z + side * 1.2), _mat("brace_timber", Color(0.5, 0.36, 0.22), 0.9), Vector3(side * 0.45, 0, 0))
	# Consoles round the captain's chair.
	for k in 5:
		var a := deg_to_rad(-60.0 + k * 30.0)
		var p := Vector3(66.0, 0, 0) + Vector3(cos(a), 0, sin(a)) * 5.5
		_solid_kit(s, "dune_console", "Console%d" % k, p, rad_to_deg(-a) - 90.0, Vector3(1.9, 2.2, 1.0))
	_captain_chair(s, Vector3(64.0, 0, 0.0))
	_reactor(s, Vector3(73.5, 0, -14.5))
	_reactor(s, Vector3(73.5, 0, 14.5))
	# The green screen in the north-west corner, the camera crane on it.
	var green := _mat("green_screen", Color(0.1, 0.75, 0.2), 0.9, Color(0.05, 0.4, 0.1), 0.35)
	_visual_box(dressing, "GreenScreen", Vector3(16.0, 9.0, 0.2), Vector3(44.0, 4.5, -17.8), green)
	_visual_box(dressing, "GreenFloor", Vector3(16.0, 0.04, 5.0), Vector3(44.0, 0.02, -15.2), green)
	for k in 6:
		_label(dressing, "TrackMark%d" % k, "+", Vector3(38.0 + k * 2.4, 2.0 + (k % 3) * 2.4, -17.65), 0.0, 120, Color(0.05, 0.25, 0.05))
	_crane(s, "StageCrane", Vector3(44.0, 0, -9.0), 120.0)
	_light_stand(s, "GreenKeyA", Vector3(38.0, 0, -12.0), 160.0, Color(0.95, 0.95, 1.0), true, 4.0)
	_light_stand(s, "GreenKeyB", Vector3(50.5, 0, -12.5), 200.0, Color(0.95, 0.95, 1.0), true, 4.0)
	# Road cases, carts and a make-up table along the south wall.
	_road_case(s, "StageCaseA", Vector3(38.0, 0, 15.5), 0.0)
	_road_case(s, "StageCaseB", Vector3(54.0, 0, 15.8), 10.0)
	_road_case(s, "StageCaseC", Vector3(40.0, 0, 4.0), 80.0)
	_solid_kit(s, "neon_crates", "StageCratesA", Vector3(58.0, 0, 15.6), 0.0, Vector3(2.2, 1.5, 1.2))
	_solid_kit(s, "dune_crates", "StageCratesB", Vector3(36.6, 0, -2.0), 90.0, Vector3(3.3, 2.1, 1.6))
	_chair(s, "StageChairA", Vector3(47.0, 0, -3.0), 120.0, "DIRECTOR")
	_chair(s, "StageChairB", Vector3(48.0, 0, -4.2), 130.0, "SCRIPT")
	_cable_run([Vector3(44.0, 0, -9.0), Vector3(48.0, 0, -2.0), Vector3(58.0, 0, -1.0), Vector3(62.0, 0, 3.0)])
	# The lighting grid: trusses across the stage, lamps hung from them.
	var truss := _mat("truss_alu", Color(0.7, 0.72, 0.76), 0.3)
	for k in 5:
		var z := -14.0 + k * 7.0
		_part(dressing, Vector3(STAGE.size.x, 0.4, 0.4), Vector3(STAGE.get_center().x, 12.0, z), truss)
		_part(dressing, Vector3(STAGE.size.x, 0.06, 0.06), Vector3(STAGE.get_center().x, 12.4, z + 0.2), truss)
	for k in 3:
		_part(dressing, Vector3(0.4, 0.4, STAGE.size.y), Vector3(42.0 + k * 14.0, 12.0, 0), truss)
	var colors := [Color(0.4, 0.85, 1.0), Color(1.0, 0.4, 0.85), Color(1.0, 0.8, 0.55), Color(0.5, 0.6, 1.0)]
	var i := 0
	for k in 5:
		for c in 4:
			var p := Vector3(40.0 + c * 11.0, 11.3, -14.0 + k * 7.0)
			var col: Color = colors[(k + c) % 4]
			var lamp := _node(dressing, "GridLamp%d" % i, p)
			lamp.rotation.x = deg_to_rad(-70.0)
			_part(lamp, Vector3(0.55, 0.55, 0.7), Vector3.ZERO, _mat("grip_black", Color(0.08, 0.08, 0.09), 0.5))
			_part(lamp, Vector3(0.45, 0.45, 0.04), Vector3(0, 0, 0.37), _mat("lens_" + col.to_html(false), col, 0.2, col, 4.0))
			if (k + c) % 2 == 0:
				_omni(fx, "GridLight%d" % i, Vector3(p.x, 6.0, p.z), col, 1.5, 12.0)
				_stage_beam("GridBeam%d" % i, p, col)
			i += 1
	# A catwalk round the walls at 7 m.
	var steel := _mat("escape_steel", Color(0.22, 0.22, 0.25), 0.5)
	_visual_box(dressing, "CatwalkN", Vector3(STAGE.size.x, 0.12, 1.2), Vector3(STAGE.get_center().x, 7.0, STAGE.position.y + 0.6), steel)
	_visual_box(dressing, "CatwalkS", Vector3(STAGE.size.x, 0.12, 1.2), Vector3(STAGE.get_center().x, 7.0, STAGE.end.y - 0.6), steel)
	_visual_box(dressing, "CatwalkRailN", Vector3(STAGE.size.x, 0.06, 0.06), Vector3(STAGE.get_center().x, 8.0, STAGE.position.y + 1.2), steel)
	_visual_box(dressing, "CatwalkRailS", Vector3(STAGE.size.x, 0.06, 0.06), Vector3(STAGE.get_center().x, 8.0, STAGE.end.y - 1.2), steel)
	# ON AIR lamps over the doors.
	for d in [[Vector3(70.0, 3.3, -17.9), 0.0], [Vector3(44.0, 3.3, 17.9), 180.0], [Vector3(68.0, 3.3, 17.9), 180.0], [Vector3(56.0, 3.3, 17.9), 180.0]]:
		var on_air := _label(dressing, "OnAir%d" % _part_id, "ON AIR", d[0], d[1], 70, Color(1.0, 0.25, 0.2))
		on_air.outline_modulate = Color(0.3, 0.0, 0.0)
		_part_id += 1
	_omni(fx, "ViewscreenGlow", Vector3(72.0, 4.5, 0.0), Color(0.45, 0.6, 1.0), 1.6, 12.0)
	_omni(fx, "BridgeRedA", Vector3(62.0, 1.5, -9.0), Color(1.0, 0.25, 0.3), 1.0, 7.0).add_to_group("studio_alert", true)
	_omni(fx, "BridgeRedB", Vector3(62.0, 1.5, 9.0), Color(1.0, 0.25, 0.3), 1.0, 7.0).add_to_group("studio_alert", true)
	_omni(fx, "StageWork", Vector3(44.0, 6.0, 10.0), Color(1.0, 0.78, 0.55), 1.0, 12.0)


## A light's beam hung from the grid: a short additive cone (city_beam).
func _stage_beam(beam_name: String, lamp: Vector3, color: Color) -> void:
	var pivot := Node3D.new()
	pivot.name = beam_name
	pivot.position = lamp
	pivot.rotation.x = deg_to_rad(160.0)
	fx.add_child(pivot)
	var cone := CylinderMesh.new()
	cone.top_radius = 2.6
	cone.bottom_radius = 0.25
	cone.height = 11.0
	cone.radial_segments = 12
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "city_beam.gdshader")
	m.set_shader_parameter("beam_color", color)
	m.set_shader_parameter("strength", 0.22)
	cone.material = m
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = cone
	beam.position.y = 5.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(beam)


func _captain_chair(parent: Node3D, pos: Vector3) -> void:
	var t := _node(dressing, "CaptainChair", pos, -90.0)
	var white := _mat("chair_white", Color(0.88, 0.9, 0.94), 0.35)
	var neon := _mat("bridge_neon", Color(0.3, 0.9, 1.0), 0.3, Color(0.3, 0.9, 1.0), 5.0)
	_cyl(t, 1.4, 0.3, Vector3(0, 0.15, 0), _mat("hull_panel", Color(0.55, 0.58, 0.66), 0.4))
	_cyl(t, 1.42, 0.05, Vector3(0, 0.31, 0), neon)
	_cyl(t, 0.2, 0.7, Vector3(0, 0.6, 0), white)
	_part(t, Vector3(0.9, 0.2, 0.8), Vector3(0, 1.0, 0), white)
	_part(t, Vector3(0.9, 1.2, 0.18), Vector3(0, 1.6, -0.4), white, Vector3(-0.15, 0, 0))
	for side in [-1.0, 1.0]:
		_part(t, Vector3(0.18, 0.2, 0.8), Vector3(side * 0.5, 1.3, 0.05), white)
		_part(t, Vector3(0.1, 0.04, 0.3), Vector3(side * 0.5, 1.42, 0.25), neon)
	_post(parent, "CaptainChairPost", 1.0, 1.5, pos)


## A glowing reactor column (set dressing): rings round a lit core.
func _reactor(parent: Node3D, pos: Vector3) -> void:
	var t := _node(dressing, "Reactor%d" % int(pos.z), pos)
	var core := _mat("reactor_core", Color(0.5, 1.0, 0.95), 0.2, Color(0.3, 1.0, 0.9), 4.5)
	var steel := _mat("hull_panel", Color(0.55, 0.58, 0.66), 0.4)
	_cyl(t, 1.3, 0.6, Vector3(0, 0.3, 0), steel)
	_cyl(t, 0.65, 6.0, Vector3(0, 3.6, 0), core)
	for k in 5:
		_cyl(t, 0.95, 0.18, Vector3(0, 1.4 + k * 1.2, 0), steel)
	_cyl(t, 1.3, 0.6, Vector3(0, 6.9, 0), steel)
	_post(parent, "ReactorPost%d" % int(pos.z), 1.3, 7.0, pos)
	_omni(fx, "ReactorLight%d" % int(pos.z), pos + Vector3(-1.5, 3.0, 0), Color(0.35, 1.0, 0.9), 1.3, 8.0)


# ---------------------------------------------------------------------------
# Monster Lot: a castle front, a foggy graveyard and the hanging moon
# ---------------------------------------------------------------------------

func _lot_monster() -> void:
	var m := Node3D.new()
	m.name = "Monster"
	geo.add_child(m)
	# The castle: a gatehouse (the zombies come through its arch) and towers.
	# Both stand in the blocks behind the lot's north edge (z -90).
	_kit(dressing, "faire_gatehouse", "CastleGate", Vector3(0, 0, -94.9), 0.0, Vector3.ZERO)
	_kit(dressing, "faire_tower", "CastleTowerW", Vector3(-12.5, 0, -93.4), 0.0, Vector3.ZERO)
	_kit(dressing, "faire_tower", "CastleTowerE", Vector3(12.5, 0, -93.4), 0.0, Vector3.ZERO)
	for side in [-1.0, 1.0]:
		_kit(dressing, "faire_brazier", "CastleBrazier%d" % int(side), Vector3(side * 4.2, 0, -87.5), 0.0, Vector3.ZERO)
		_post(m, "CastleBrazierPost%d" % int(side), 0.5, 2.5, Vector3(side * 4.2, 0, -87.5))
		_fire_at(fx, "CastleTorch%d" % int(side), Vector3(side * 4.2, 2.4, -87.5), 0.7, true, 1.6)
	# Painted hills on both side walls, pines in front of them.
	_backdrop("HillsWest", Vector3(-25.4, 0, -77.0), 90.0, 22.0, 9.0, 2)
	_backdrop("HillsWest2", Vector3(-25.4, 0, -52.0), 90.0, 12.0, 9.0, 2)
	_backdrop("HillsEast", Vector3(25.4, 0, -79.0), -90.0, 16.0, 9.0, 2)
	for k in 7:
		if k == 4:
			continue
		var z := -86.0 + k * 6.0
		_kit(dressing, "faire_pine", "PineW%d" % k, Vector3(-21.5 + (k % 2) * 1.2, 0, z), k * 47.0, Vector3.ZERO)
		_post(m, "PineWPost%d" % k, 0.6, 3.0, Vector3(-21.5 + (k % 2) * 1.2, 0, z))
	for k in 3:
		var z := -86.0 + k * 6.5
		_kit(dressing, "faire_pine", "PineE%d" % k, Vector3(21.5 - (k % 2) * 1.2, 0, z), k * 61.0, Vector3.ZERO)
		_post(m, "PineEPost%d" % k, 0.6, 3.0, Vector3(21.5 - (k % 2) * 1.2, 0, z))
	# The graveyard either side of the cobbled path.
	_floor(dressing, "MonsterPath", Rect2(-2.5, -88.0, 5.0, 44.0), _surface("monster_cobble", ["fright_cobble"], Color(0.6, 0.62, 0.7), 0.25, 0.9), 0.02)
	var graves := ["GraveA", "GraveB", "GraveC"]
	var k := 0
	for row in 6:
		for col in 3:
			for side in [-1.0, 1.0]:
				if row == 3 and col == 0 and side > 0.0:
					continue
				var x: float = side * (6.5 + col * 3.4 + (row % 2) * 0.8)
				var z := -83.0 + row * 4.2
				var g: String = graves[(row + col) % 3]
				_kit_piece(m, "fright_kit", g, "Grave%d" % k, Vector3(x, 0, z), _rng.randf_range(-12.0, 12.0), Vector3(1.0, 1.2, 0.5))
				k += 1
	# Low iron fences round the two plots, open on the path side.
	for side in [-1.0, 1.0]:
		for f in 4:
			_kit_piece(m, "fright_kit", "FenceLow", "PlotFence%d_%d" % [int(side), f], Vector3(side * (7.0 + f * 3.0), 0, -86.4), 0.0, Vector3(2.8, 0.8, 0.2))
	_kit_piece(m, "fright_kit", "TreeA", "DeadTreeA", Vector3(-11.0, 0, -58.0), 30.0, Vector3(0.8, 4.0, 0.8))
	_kit_piece(m, "fright_kit", "TreeB", "DeadTreeB", Vector3(12.0, 0, -86.5), 160.0, Vector3(0.8, 4.0, 0.8))
	_kit_piece(m, "fright_kit", "TreeA", "DeadTreeC", Vector3(17.5, 0, -52.0), 250.0, Vector3(0.8, 4.0, 0.8))
	_kit_piece(m, "fright_kit", "Coffins", "Coffins", Vector3(-15.0, 0, -50.0), 20.0, Vector3(2.2, 1.0, 1.6))
	_kit_piece(m, "fright_kit", "PumpkinPile", "Pumpkins", Vector3(8.0, 0, -48.0), 0.0, Vector3(1.6, 0.8, 1.6))
	for p in [Vector3(-4.0, 0, -80.0), Vector3(4.0, 0, -70.0), Vector3(-4.0, 0, -58.0), Vector3(4.0, 0, -48.0)]:
		_kit_piece(m, "fright_kit", "LanternG", "Lantern%d" % int(p.z), p, 0.0, Vector3(0.4, 2.0, 0.4))
		_omni(fx, "LanternLight%d" % int(p.z), p + Vector3(0, 2.0, 0), Color(0.45, 1.0, 0.55), 1.1, 8.0).add_to_group("studio_flicker", true)
	# Fog, low over the graves.
	for z in [-80.0, -64.0, -50.0]:
		for x in [-12.0, 12.0]:
			_mist(Vector3(x, 0.5, z), 16.0)
	_mist(Vector3(0.0, 0.9, -72.0), 22.0)
	_hanging_moon(Vector3(18.0, 0, -88.0))
	# The storm machine: a lightning rig that flashes the lot now and then.
	_light_stand(m, "LightningRig", Vector3(16.0, 0, -60.0), -110.0, Color(0.8, 0.85, 1.0), false, 5.0)
	var flash := _omni(fx, "LightningFlash", Vector3(8.0, 12.0, -66.0), Color(0.75, 0.82, 1.0), 0.0, 40.0)
	flash.add_to_group("studio_lightning", true)
	_omni(fx, "CastleWash", Vector3(0.0, 9.0, -82.0), Color(0.5, 0.65, 1.0), 1.4, 16.0)
	_omni(fx, "GraveGlowW", Vector3(-12.0, 3.0, -70.0), Color(0.4, 0.75, 0.6), 0.8, 12.0)
	_omni(fx, "GraveGlowE", Vector3(12.0, 3.0, -64.0), Color(0.4, 0.75, 0.6), 0.8, 12.0)
	_chair(m, "MonsterChair", Vector3(19.0, 0, -46.5), 200.0, "MONSTER")
	# Rubber bats on wires round the castle's towers.
	for b in [Vector3(-9.0, 13.0, -88.0), Vector3(-6.5, 15.0, -87.0), Vector3(8.0, 12.5, -87.5), Vector3(11.0, 14.5, -88.5), Vector3(2.0, 18.5, -89.0)]:
		var bat := MeshInstance3D.new()
		bat.name = "Bat%d" % int(b.x * 10.0)
		bat.mesh = _kit_mesh_of("fright_kit", "Bat")
		bat.position = b
		bat.rotation.y = b.x * 0.4
		bat.scale = Vector3.ONE * 1.6
		dressing.add_child(bat)
		_part(dressing, Vector3(0.02, 4.0, 0.02), b + Vector3(0, 2.0, 0), _mat("wire", Color(0.1, 0.1, 0.1), 0.5))


## A mesh from a multi-part kit (fright_kit) with a box collider.
func _kit_piece(parent: Node3D, kit: String, mesh_name: String, prop_name: String, pos: Vector3, yaw: float, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = prop_name
	mi.mesh = _kit_mesh_of(kit, mesh_name)
	mi.position = pos
	mi.rotation.y = deg_to_rad(yaw)
	dressing.add_child(mi)
	var c := _collider(parent, prop_name + "Collision", size, pos + Vector3(0, size.y * 0.5, 0))
	c.rotation.y = deg_to_rad(yaw)


## The named mesh of a multi-part kit .glb (cached).
func _kit_mesh_of(kit: String, mesh_name: String) -> Mesh:
	var key := kit + "/" + mesh_name
	if not _kits.has(key):
		var source: Node3D = (load(MODELS + kit + ".glb") as PackedScene).instantiate()
		for n in source.find_children("*", "MeshInstance3D", true, false):
			_kits[kit + "/" + String(n.name)] = (n as MeshInstance3D).mesh
		source.free()
	return _kits[key]


func _mist(pos: Vector3, size: float) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "fright_mist.gdshader")
	m.set_shader_parameter("mist_color", Color(0.6, 0.78, 0.8))
	m.set_shader_parameter("strength", 0.5)
	plane.material = m
	var mi := MeshInstance3D.new()
	mi.name = "Mist%d" % _part_id
	_part_id += 1
	mi.mesh = plane
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(mi)


## The studio's moon: a big glowing disc hung from a crane arm over the
## graveyard (it is a set, after all).
func _hanging_moon(base: Vector3) -> void:
	var t := _node(dressing, "MoonCrane", base)
	var steel := _mat("grip_steel", Color(0.55, 0.57, 0.6), 0.35)
	var yellow := _mat("grip_yellow", Color(0.95, 0.7, 0.1), 0.5)
	t.rotation.y = PI
	_part(t, Vector3(0.8, 22.0, 0.8), Vector3(0, 11.0, 0), yellow)
	_part(t, Vector3(14.0, 0.6, 0.6), Vector3(5.0, 22.0, 0), yellow)
	_part(t, Vector3(1.6, 1.6, 1.6), Vector3(-1.8, 21.6, 0), _mat("grip_black", Color(0.08, 0.08, 0.09), 0.5))
	_part(t, Vector3(0.05, 4.0, 0.05), Vector3(11.0, 20.0, 0), steel)
	var moon := _mat("set_moon", Color(0.9, 0.95, 1.0), 0.3, Color(0.8, 0.9, 1.0), 2.5)
	_cyl(t, 3.0, 0.3, Vector3(11.0, 15.0, 0), moon, Vector3(PI * 0.5, 0, 0))
	_post(geo, "MoonCranePost", 0.6, 3.0, base)
	_omni(fx, "MoonGlow", base + Vector3(-11.0, 15.0, 4.0), Color(0.7, 0.85, 1.0), 1.8, 24.0)


# ---------------------------------------------------------------------------
# Premiere Boulevard: the red carpet, the Starlot Grand, searchlights
# ---------------------------------------------------------------------------

func _lot_premiere() -> void:
	var p := Node3D.new()
	p.name = "Premiere"
	geo.add_child(p)
	var carpet := _mat("red_carpet", Color(0.62, 0.04, 0.08), 0.95, Color(0.35, 0.0, 0.02), 0.25)
	var gold := _mat("carpet_gold", Color(0.95, 0.75, 0.3), 0.3, Color(0.6, 0.45, 0.15), 0.6)
	_visual_box(dressing, "RedCarpet", Vector3(5.0, 0.03, 52.0), Vector3(56.0, 0.02, -56.0), carpet)
	for side in [-1.0, 1.0]:
		_visual_box(dressing, "CarpetEdge%d" % int(side), Vector3(0.15, 0.035, 52.0), Vector3(56.0 + side * 2.55, 0.02, -56.0), gold)
	# Velvet ropes along the carpet, with gaps to cross.
	for side in [-1.0, 1.0]:
		var x: float = 56.0 + side * 3.4
		for seg in [[-78.0, -66.0], [-60.0, -48.0], [-42.0, -34.0]]:
			_rope_line(Vector3(x, 0, seg[0]), Vector3(x, 0, seg[1]))
	_theatre()
	# Bleachers for the fans either side, a step-and-repeat wall, a limousine.
	for z in [-74.0, -62.0, -50.0]:
		_solid_kit(p, "sky_bleachers", "BleacherW%d" % int(-z), Vector3(46.0, 0, z), 90.0, Vector3(5.3, 1.6, 2.4))
		_solid_kit(p, "sky_bleachers", "BleacherE%d" % int(-z), Vector3(66.5, 0, z + 4.0), -90.0, Vector3(5.3, 1.6, 2.4))
	_step_and_repeat(p, Vector3(64.0, 0, -76.5), -90.0)
	_limo(p, Vector3(62.5, 0, -40.0), 0.0)
	_limo(p, Vector3(86.0, 0, -66.0), 70.0)
	for k in 6:
		var at := Vector3(40.0 + (k % 2) * 52.0, 0, -80.0 + int(k / 2.0) * 20.0)
		_kit(dressing, "palm", "BlvdPalm%d" % k, at, k * 53.0, Vector3.ZERO)
		_post(p, "BlvdPalmPost%d" % k, 0.4, 3.0, at)
	for at in [Vector3(80.0, 0, -36.0), Vector3(92.0, 0, -50.0), Vector3(78.0, 0, -80.0)]:
		_kit(dressing, "palm", "BlvdPalmB%d" % int(at.z), at, at.x * 3.0, Vector3.ZERO)
		_post(p, "BlvdPalmBPost%d" % int(at.z), 0.4, 3.0, at)
	for at in [Vector3(50.5, 0, -34.0), Vector3(61.5, 0, -34.0), Vector3(50.5, 0, -70.0), Vector3(61.5, 0, -58.0), Vector3(76.0, 0, -60.0), Vector3(90.0, 0, -76.0)]:
		_lot_lamp(p, at)
	# Searchlights on trailers, sweeping the sky.
	var phase := 0.0
	for at in [Vector3(42.0, 0.9, -36.0), Vector3(90.0, 0.9, -34.0), Vector3(92.0, 0.9, -82.0), Vector3(72.0, 0.9, -84.0)]:
		_searchlight_trailer(p, at, phase)
		phase += 1.7
	# Paparazzi flashes by the step-and-repeat.
	for k in 3:
		_omni(fx, "Flash%d" % k, Vector3(60.0 + k * 1.2, 1.8, -73.0 + k * 1.5), Color(0.95, 0.97, 1.0), 0.0, 9.0).add_to_group("studio_flash", true)
	# Walk-of-fame stars in the pavement.
	var xforms: Array[Transform3D] = []
	for k in 14:
		for side in [-1.0, 1.0]:
			xforms.append(Transform3D(Basis(), Vector3(56.0 + side * 6.5, 0.015, -82.0 + k * 3.6)))
	var plaque := _box_mesh(Vector3(1.3, 0.02, 1.3), _mat("star_plaque", Color(0.2, 0.08, 0.12), 0.4))
	dressing.add_child(_multimesh("StarPlaques", plaque, xforms))
	var star_xforms: Array[Transform3D] = []
	for xf in xforms:
		star_xforms.append(xf.translated(Vector3(0, 0.012, 0)))
	var star := MultiMeshInstance3D.new()
	star.name = "Stars"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _star_mesh(0.5, _mat("star_gold", Color(1.0, 0.8, 0.35), 0.25, Color(0.9, 0.6, 0.2), 0.8))
	mm.instance_count = star_xforms.size()
	for k in star_xforms.size():
		mm.set_instance_transform(k, star_xforms[k])
	star.multimesh = mm
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(star)
	# Neon over the boulevard's east side.
	var neon := [["HOTEL ROSALIND", Color(1.0, 0.35, 0.65), Vector3(95.9, 7.0, -70.0)], ["DINER", Color(0.35, 0.95, 1.0), Vector3(95.9, 5.0, -48.0)],
		["COCKTAILS", Color(1.0, 0.75, 0.3), Vector3(95.9, 6.0, -33.5)]]
	for n in neon:
		var l := _label(dressing, "Neon%s" % String(n[0]).replace(" ", ""), n[0], n[2], -90.0, 170, n[1])
		l.outline_modulate = Color(n[1], 0.35)
		l.add_to_group("studio_flicker", true)
		_omni(fx, "NeonGlow%s" % String(n[0]).replace(" ", ""), n[2] + Vector3(-2.5, -1.0, 0), n[1], 1.2, 9.0)
	_omni(fx, "CarpetWashA", Vector3(56.0, 5.0, -44.0), Color(1.0, 0.45, 0.45), 1.0, 12.0)
	_omni(fx, "CarpetWashB", Vector3(56.0, 5.0, -64.0), Color(1.0, 0.6, 0.5), 1.0, 12.0)


## The Starlot Grand: a deco facade, a marquee canopy rimmed with chasing
## bulbs, a vertical blade sign and the doors at the top of the carpet.
func _theatre() -> void:
	var front_z := PREMIERE.position.y
	var deco := _mat("deco_cream", Color(0.95, 0.88, 0.78), 0.6)
	var gold := _mat("deco_gold", Color(0.95, 0.72, 0.3), 0.3, Color(0.5, 0.35, 0.1), 0.4)
	var t := _node(dressing, "Theatre", Vector3(56.0, 0, front_z))
	_part(t, Vector3(24.0, 16.0, 0.6), Vector3(0, 8.0, 0.3), deco)
	for k in 7:
		_part(t, Vector3(0.6, 16.0, 0.4), Vector3(-10.8 + k * 3.6, 8.0, 0.75), gold)
	_part(t, Vector3(24.6, 0.6, 0.9), Vector3(0, 16.2, 0.5), gold)
	_part(t, Vector3(10.0, 3.0, 0.5), Vector3(0, 17.8, 0.3), deco)
	_part(t, Vector3(4.0, 2.0, 0.5), Vector3(0, 20.3, 0.3), gold)
	for x in [-4.4, 4.4]:
		_kit(dressing, "mall_cinema_doors", "TheatreDoors%d" % int(x), Vector3(56.0 + x, 0, front_z + 1.0), 0.0, Vector3.ZERO)
	# The marquee canopy and its letter boards.
	var canopy := _node(dressing, "Marquee", Vector3(56.0, 6.2, front_z + 3.0))
	var black := _mat("marquee_black", Color(0.06, 0.05, 0.07), 0.6)
	_part(canopy, Vector3(22.0, 3.2, 5.0), Vector3(0, 1.6, 0), black)
	_part(canopy, Vector3(22.2, 0.3, 5.2), Vector3(0, 3.3, 0), gold)
	var board := _mat("letter_board", Color(0.95, 0.93, 0.85), 0.4, Color(1.0, 0.95, 0.8), 1.2)
	_part(canopy, Vector3(19.0, 2.0, 0.06), Vector3(0, 1.6, 2.53), board)
	_part(canopy, Vector3(0.06, 2.0, 4.0), Vector3(-11.03, 1.6, 0), board)
	_part(canopy, Vector3(0.06, 2.0, 4.0), Vector3(11.03, 1.6, 0), board)
	var line1 := _label(dressing, "MarqueeLine1", "WORLD PREMIERE TONIGHT", Vector3(56.0, 8.3, front_z + 5.6), 0.0, 120, Color(0.08, 0.05, 0.08))
	line1.outline_size = 0
	var line2 := _label(dressing, "MarqueeLine2", "WHAT LIES AHEAD", Vector3(56.0, 7.3, front_z + 5.6), 0.0, 150, Color(0.75, 0.05, 0.08))
	line2.outline_size = 0
	for y in [6.35, 9.4]:
		_marquee_strip(Vector3(56.0, y, front_z + 5.56), 0.0, 22.0, 0.28, 66.0)
	for side in [-1.0, 1.0]:
		var strip_x: float = 56.0 + side * 11.06
		_marquee_strip(Vector3(strip_x, 9.4, front_z + 3.0), side * 90.0, 5.0, 0.28, 15.0)
		_marquee_strip(Vector3(strip_x, 6.35, front_z + 3.0), side * 90.0, 5.0, 0.28, 15.0)
	# The upright sign: STARLOT down a tall panel over the canopy, rimmed
	# with chasing bulbs.
	var blade := _node(dressing, "UprightSign", Vector3(56.0, 10.0, front_z + 1.2))
	_part(blade, Vector3(2.6, 12.4, 0.6), Vector3(0, 6.0, 0), _mat("blade_red", Color(0.55, 0.05, 0.1), 0.5))
	_part(blade, Vector3(2.9, 0.3, 0.8), Vector3(0, 12.3, 0), gold)
	var letters := "STARLOT"
	for k in letters.length():
		var l := _label(dressing, "Upright%s%d" % [letters[k], k], letters[k], Vector3(56.0, 20.9 - k * 1.6, front_z + 1.52), 0.0, 230, Color(1.0, 0.88, 0.55))
		l.outline_modulate = Color(1.0, 0.4, 0.1)
	for side in [-1.0, 1.0]:
		_marquee_strip(Vector3(56.0 + side * 1.12, 16.0, front_z + 1.52), 0.0, 0.26, 12.0, 46.0)
	_marquee_strip(Vector3(56.0, 22.1, front_z + 1.52), 0.0, 2.5, 0.26, 8.0)
	_marquee_strip(Vector3(56.0, 10.1, front_z + 1.52), 0.0, 2.5, 0.26, 8.0)
	_omni(fx, "MarqueeGlow", Vector3(56.0, 5.5, front_z + 7.0), Color(1.0, 0.82, 0.5), 2.0, 14.0)
	_omni(fx, "BladeGlow", Vector3(56.0, 16.0, front_z + 5.0), Color(1.0, 0.5, 0.3), 1.4, 12.0)
	_omni(fx, "DoorsGlow", Vector3(56.0, 3.0, front_z + 2.2), Color(1.0, 0.75, 0.45), 1.2, 9.0)
	# Ticket booth in front of the doors.
	var booth := _node(dressing, "TicketBooth", Vector3(48.0, 0, front_z + 4.0))
	_cyl(booth, 1.1, 0.4, Vector3(0, 0.2, 0), gold)
	_cyl(booth, 1.0, 2.2, Vector3(0, 1.5, 0), _mat("booth_glass", Color(1.0, 0.8, 0.5), 0.2, Color(1.0, 0.75, 0.45), 1.4))
	_cyl(booth, 1.2, 0.5, Vector3(0, 2.85, 0), _mat("blade_red", Color(0.55, 0.05, 0.1), 0.5))
	_post(geo, "TicketBoothPost", 1.1, 3.0, Vector3(48.0, 0, front_z + 4.0))


func _rope_line(a: Vector3, b: Vector3) -> void:
	var brass := _mat("brass", Color(0.95, 0.75, 0.35), 0.25)
	var velvet := _mat("velvet", Color(0.55, 0.02, 0.08), 0.9)
	var n := int(a.distance_to(b) / 2.0)
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		_cyl(dressing, 0.05, 1.0, p + Vector3(0, 0.5, 0), brass)
		_cyl(dressing, 0.18, 0.05, p + Vector3(0, 0.03, 0), brass)
		_cyl(dressing, 0.07, 0.07, p + Vector3(0, 1.03, 0), brass)
		if k < n:
			var q := a.lerp(b, float(k + 1) / n)
			var dir := q - p
			_part(dressing, Vector3(0.06, 0.06, dir.length()), (p + q) * 0.5 + Vector3(0, 0.82, 0), velvet, Vector3(0, atan2(dir.x, dir.z), 0))
	var mid := (a + b) * 0.5
	var c := _collider(geo, "Rope%d" % _part_id, Vector3(0.3, 1.0, a.distance_to(b)), mid + Vector3(0, 0.5, 0))
	_part_id += 1
	c.rotation.y = atan2(b.x - a.x, b.z - a.z)


func _step_and_repeat(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var t := _node(dressing, "StepRepeat", pos, yaw)
	_part(t, Vector3(10.0, 3.2, 0.15), Vector3(0, 1.8, 0), _mat("press_wall", Color(0.95, 0.95, 0.97), 0.7))
	for sx in [-4.9, 4.9]:
		_part(t, Vector3(0.1, 3.6, 0.1), Vector3(sx, 1.8, -0.15), _mat("grip_black", Color(0.08, 0.08, 0.09), 0.5))
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	for row in 3:
		for col in 5:
			var local := Vector3(-4.0 + col * 2.0 + (row % 2) * 1.0, 0.8 + row * 1.0, 0.09)
			var l := _label(dressing, "Logo%d_%d" % [row, col], "STARLOT", pos + b * local, yaw, 40, Color(0.7, 0.08, 0.12) if (row + col) % 2 == 0 else Color(0.12, 0.12, 0.3))
			l.outline_size = 0
	var c := _collider(parent, "StepRepeatCollision", Vector3(10.0, 3.4, 0.4), pos + Vector3(0, 1.7, 0))
	c.rotation.y = deg_to_rad(yaw)
	_light_stand(parent, "PressLight", pos + b * Vector3(-3.0, 0, 4.0), yaw + 200.0, Color(1.0, 0.95, 0.9), true, 2.8)


func _limo(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var t := _node(dressing, "Limo%d" % int(pos.x), pos, yaw)
	var paint := _mat("limo_black", Color(0.03, 0.03, 0.04), 0.12)
	var glass := _mat("limo_glass", Color(0.1, 0.12, 0.18), 0.05)
	var chrome := _mat("case_chrome", Color(0.8, 0.82, 0.85), 0.2)
	_part(t, Vector3(2.0, 0.8, 8.4), Vector3(0, 0.65, 0), paint)
	_part(t, Vector3(1.8, 0.55, 5.6), Vector3(0, 1.32, -0.3), glass)
	_part(t, Vector3(1.82, 0.08, 5.6), Vector3(0, 1.63, -0.3), paint)
	_part(t, Vector3(2.04, 0.08, 8.44), Vector3(0, 0.6, 0), chrome)
	for z in [-3.0, 3.0]:
		for sx in [-0.95, 0.95]:
			_cyl(t, 0.36, 0.25, Vector3(sx, 0.36, z), _mat("grip_black", Color(0.08, 0.08, 0.09), 0.5), Vector3(0, 0, PI * 0.5))
	_part(t, Vector3(1.4, 0.15, 0.04), Vector3(0, 0.75, 4.21), _mat("headlight", Color(1, 0.95, 0.85), 0.2, Color(1.0, 0.95, 0.85), 3.0))
	_part(t, Vector3(1.4, 0.12, 0.04), Vector3(0, 0.75, -4.21), _mat("taillight", Color(1, 0.1, 0.1), 0.2, Color(1.0, 0.1, 0.08), 3.0))
	var c := _collider(parent, "LimoCollision%d" % int(pos.x), Vector3(2.1, 1.7, 8.5), pos + Vector3(0, 0.85, 0))
	c.rotation.y = deg_to_rad(yaw)


func _searchlight_trailer(parent: Node3D, at: Vector3, phase: float) -> void:
	var t := _node(dressing, "SearchTrailer%d" % _part_id, Vector3(at.x, 0, at.z))
	var drab := _mat("search_drab", Color(0.3, 0.33, 0.28), 0.6)
	_part(t, Vector3(2.4, 0.5, 1.8), Vector3(0, 0.6, 0), drab)
	for sx in [-0.8, 0.8]:
		_cyl(t, 0.35, 0.25, Vector3(sx, 0.35, 1.0), _mat("grip_black", Color(0.08, 0.08, 0.09), 0.5), Vector3(PI * 0.5, 0, 0))
		_cyl(t, 0.35, 0.25, Vector3(sx, 0.35, -1.0), _mat("grip_black", Color(0.08, 0.08, 0.09), 0.5), Vector3(PI * 0.5, 0, 0))
	_cyl(t, 0.9, 0.9, Vector3(0, 1.3, 0), drab)
	_collider(parent, "SearchTrailerCollision%d" % _part_id, Vector3(2.5, 1.8, 2.0), Vector3(at.x, 0.9, at.z))
	_part_id += 1
	_searchlight("Search%d" % _part_id, at + Vector3(0, 1.0, 0), 22.0, phase * 70.0, phase)


## A flat five-pointed star (an inlay), radius `r`.
func _star_mesh(r: float, material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var pts: Array[Vector3] = []
	for k in 10:
		var a := -PI * 0.5 + k * PI / 5.0
		var rr := r if k % 2 == 0 else r * 0.42
		pts.append(Vector3(cos(a) * rr, 0, sin(a) * rr))
	for k in 10:
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(pts[k])
		st.add_vertex(pts[(k + 1) % 10])
	st.set_material(material)
	return st.commit()


# ---------------------------------------------------------------------------
# The horizon: dark hills round the lot and the STARLOT sign on the hillside
# ---------------------------------------------------------------------------

func _lot_horizon() -> void:
	var hill_mat := _mat("hill", Color(0.08, 0.07, 0.12), 0.95)
	var hills := [[Vector3(-40, -20, -330), Vector3(300, 220, 120)], [Vector3(140, -40, -300), Vector3(220, 130, 120)],
		[Vector3(-320, -40, -60), Vector3(120, 120, 300)], [Vector3(330, -40, -80), Vector3(120, 110, 300)],
		[Vector3(0, -50, 280), Vector3(320, 120, 120)]]
	var k := 0
	for h in hills:
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 24
		sphere.rings = 10
		sphere.material = hill_mat
		var mi := MeshInstance3D.new()
		mi.name = "Hill%d" % k
		mi.mesh = sphere
		mi.position = h[0]
		mi.scale = h[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx.add_child(mi)
		k += 1
	# The sign on the north hill, its letters lit from below.
	var word := "STARLOT"
	for i in word.length():
		var x := -78.0 + i * 15.0
		var l := _label(fx, "HillLetter%d" % i, word[i], Vector3(x, 68.0 + sin(i * 1.3) * 2.5, -292.0), 0.0, 400, Color(0.95, 0.95, 0.9))
		l.pixel_size = 0.05
		l.outline_size = 0
		l.fixed_size = false
		l.rotation.z = deg_to_rad(sin(i * 2.1) * 3.0)
	# A far city glow: a band of lit windows along the south horizon.
	var windows := _mat("far_windows", Color(1.0, 0.75, 0.45), 0.5, Color(1.0, 0.7, 0.4), 1.4)
	var xforms: Array[Transform3D] = []
	for i in 60:
		var a := deg_to_rad(-80.0 + i * 160.0 / 60.0)
		var p := Vector3(sin(a) * 220.0, 0, cos(a) * 160.0 + 60.0)
		var hgt := _rng.randf_range(8.0, 30.0)
		xforms.append(Transform3D(Basis().scaled(Vector3(_rng.randf_range(8.0, 16.0), hgt, 8.0)), p + Vector3(0, hgt * 0.5 - 2.0, 0)))
	var block := _box_mesh(Vector3.ONE, _mat("far_block", Color(0.05, 0.05, 0.09), 0.9))
	var mmi := _multimesh("FarBlocks", block, xforms)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(mmi)
	var lit: Array[Transform3D] = []
	for xf in xforms:
		for j in 3:
			lit.append(Transform3D(Basis(), xf.origin + Vector3(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-4.0, 4.0), -4.1)))
	var wmmi := _multimesh("FarWindows", _box_mesh(Vector3(1.2, 0.8, 0.1), windows), lit)
	wmmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(wmmi)


# ---------------------------------------------------------------------------
# Gates, alley mouths, markers, areas and features (docs/ENDLESS.md)
# ---------------------------------------------------------------------------

func _lot_gates() -> void:
	var holder := Node3D.new()
	holder.name = "Gates"
	geo.add_child(holder)
	var counts := {}
	for g in LOT_GATES:
		var district: StringName = g[0]
		counts[district] = int(counts.get(district, 0)) + 1
		_gate(holder, "Gate_%s%s" % [district, "" if counts[district] == 1 else str(counts[district])], g)


## Player-only walls across every alley's mouth (the main gate has its own).
func _lot_mouths() -> void:
	var walls := _player_walls()
	var i := 0
	for e in LOT_ENTRANCES:
		var r: Rect2 = e[3]
		var yaw: float = e[2]
		if r.size.x > 12.0:
			continue
		var a: Vector3
		var b: Vector3
		if is_equal_approx(yaw, 180.0):
			a = Vector3(r.position.x, 0, r.end.y + 0.4)
			b = Vector3(r.end.x, 0, r.end.y + 0.4)
		elif is_equal_approx(yaw, 0.0):
			a = Vector3(r.position.x, 0, r.position.y - 0.4)
			b = Vector3(r.end.x, 0, r.position.y - 0.4)
		elif yaw > 0.0:
			a = Vector3(r.position.x - 0.4, 0, r.position.y)
			b = Vector3(r.position.x - 0.4, 0, r.end.y)
		else:
			a = Vector3(r.end.x + 0.4, 0, r.position.y)
			b = Vector3(r.end.x + 0.4, 0, r.end.y)
		_player_wall(walls, "Mouth%d" % i, a, b, WALL_H)
		_mouth_dressing(a, b, i)
		i += 1


## A cordon across a mouth: a sawhorse with a sign and a lamp on it.
func _mouth_dressing(a: Vector3, b: Vector3, i: int) -> void:
	var mid := (a + b) * 0.5
	var dir := (b - a).normalized()
	var yaw := atan2(-dir.z, dir.x)
	var stripe := _surface("hazard", ["dune_hazard"], Color.WHITE, 1.0, 0.7)
	var t := _node(dressing, "Cordon%d" % i, mid)
	t.rotation.y = yaw
	_part(t, Vector3(a.distance_to(b) * 0.7, 0.25, 0.08), Vector3(0, 1.0, 0), stripe)
	for sx in [-1.0, 1.0]:
		var x: float = sx * a.distance_to(b) * 0.3
		_part(t, Vector3(0.08, 1.1, 0.5), Vector3(x, 0.55, 0), _mat("sawhorse", Color(0.85, 0.82, 0.75), 0.8))
	for side in 2:
		_label(dressing, "CordonSign%d_%d" % [i, side], "CLOSED SET", mid + Vector3(0, 1.45, 0), rad_to_deg(yaw) + side * 180.0, 48, Color(1.0, 0.9, 0.3))


func _lot_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = LOT_STATION + Vector3(0.0, 0.1, 9.5)
	start.add_to_group("player_spawn", true)
	level.add_child(start)
	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	var counts := {}
	for entry in LOT_ENTRANCES:
		var district: StringName = entry[0]
		counts[district] = int(counts.get(district, 0)) + 1
		var m := Marker3D.new()
		m.name = "Spawn_%s%d" % [district, counts[district]]
		m.position = entry[1] + Vector3(0, 0.1, 0)
		m.rotation.y = deg_to_rad(entry[2])
		m.set_meta("district", district)
		m.add_to_group("enemy_spawn", true)
		spawns.add_child(m)
		_spawn_points.append(entry[1])


func _lot_areas() -> void:
	var holder := Node3D.new()
	holder.name = "DistrictAreas"
	level.add_child(holder)
	var areas := {
		&"front_lot": [FRONT, Rect2(-27.0, -4.0, 5.0, 8.0), Rect2(22.0, -4.0, 5.0, 8.0), Rect2(-4.0, -27.0, 8.0, 5.0)],
		&"western_street": [Rect2(-106.0, -24.0, 77.0, 48.0)],
		&"soundstage": [Rect2(29.0, -27.0, 61.0, 56.0)],
		&"monster_lot": [Rect2(-40.0, -106.0, 66.0, 79.0), Rect2(26.0, -70.0, 5.0, 8.0), Rect2(26.0, -53.0, 8.0, 6.0)],
		&"premiere": [Rect2(31.0, -106.0, 77.0, 76.0), Rect2(52.0, -30.0, 8.0, 6.0)],
	}
	for district in areas:
		var area := Area3D.new()
		area.name = "Area_%s" % district
		area.collision_layer = 8
		area.collision_mask = 2
		area.monitorable = false
		area.set_meta("district", district)
		area.add_to_group("endless_district_area", true)
		holder.add_child(area)
		var k := 0
		for box in areas[district]:
			var r: Rect2 = box
			var shape := CollisionShape3D.new()
			shape.name = "Box%d" % k
			var bs := BoxShape3D.new()
			bs.size = Vector3(r.size.x, 14.0, r.size.y)
			shape.shape = bs
			shape.position = Vector3(r.get_center().x, 6.5, r.get_center().y)
			area.add_child(shape)
			k += 1


func _lot_features() -> void:
	var holder := Node3D.new()
	holder.name = "Features"
	level.add_child(holder)
	var counts := {}
	for f in LOT_FEATURES:
		var key := "%s_%s" % [f[1], f[0]]
		counts[key] = int(counts.get(key, 0)) + 1
		var m := Marker3D.new()
		m.name = "Feature_%s%s" % [key, "" if counts[key] == 1 else str(counts[key])]
		m.position = f[2]
		m.rotation.y = deg_to_rad(f[3])
		m.set_meta("kind", f[0])
		m.set_meta("district", f[1])
		m.add_to_group("endless_feature", true)
		holder.add_child(m)
		if f[0] == &"upgrade_bench":
			var foot := _collider(geo, "BenchFootprint_%s" % f[1], Vector3(2.4, 1.1, 1.2), f[2] + Basis(Vector3.UP, deg_to_rad(f[3])) * Vector3(0, 0.55, -0.02))
			foot.rotation.y = deg_to_rad(f[3])


# ---------------------------------------------------------------------------
# Navigation and the static merge (the city's, with this map's bounds)
# ---------------------------------------------------------------------------

func _bake_navigation(region: NavigationRegion3D) -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.agent_height = 1.75
	mesh.agent_radius = 0.75
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 40.0
	mesh.region_min_size = 14.0
	mesh.filter_baking_aabb = AABB(Vector3(BOUNDS.position.x, -2.0, BOUNDS.position.y), Vector3(BOUNDS.size.x, 6.0, BOUNDS.size.y))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	var seeds: Array[Vector3] = _spawn_points.duplicate()
	seeds.append(LOT_STATION + Vector3(0, 0, 9.5))
	region.navigation_mesh = _keep_islands(mesh, seeds)
	for box in _blockers:
		box.size.z = BLOCKER_DEPTH
	print("build_endless_studio: navmesh polygons = %d (dropped %d on junk islands)" % [region.navigation_mesh.get_polygon_count(),
		before - region.navigation_mesh.get_polygon_count()])


## Merge groups: squares of MERGE_CELL metres.
func _area_of(p: Vector3) -> String:
	return "c%d_%d" % [floori(p.x / MERGE_CELL), floori(p.z / MERGE_CELL)]


# ---------------------------------------------------------------------------
# Small builders: parts of composite props (merged by _compound_static)
# ---------------------------------------------------------------------------

func _node(parent: Node3D, node_name: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	n.rotation.y = deg_to_rad(yaw)
	parent.add_child(n)
	return n


func _part(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := _visual_box(parent, "Part%d" % _part_id, size, pos, material)
	_part_id += 1
	mi.rotation = rot
	return mi


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var key := "%s|%s|%d" % [radius, height, material.get_instance_id()]
	if not _cyls.has(key):
		var c := CylinderMesh.new()
		c.top_radius = radius
		c.bottom_radius = radius
		c.height = height
		c.radial_segments = 16 if radius > 0.5 else 10
		c.rings = 1
		c.material = material
		_cyls[key] = c
	var mi := MeshInstance3D.new()
	mi.name = "Cyl%d" % _part_id
	_part_id += 1
	mi.mesh = _cyls[key]
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi
