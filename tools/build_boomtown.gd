extends SceneTree
## Generator for World 12 "Gold Rush Gulch" / level "Boomtown".
##
## Rebuilds scenes/levels/boomtown.tscn: a Wild West theme park at high noon.
## Main Street runs north-south between two rows of false-front buildings on
## raised boardwalks (bank, sheriff, the walk-in Gold Pan Saloon with its
## balcony, the general store; the assay office, the walk-through livery barn,
## the water tower deck and the Grand Hotel), the mine yard under the red mesa
## at the north end, the back lane and the corral behind the rows, the
## BOOMTOWN gate and the south plaza with the exit. Over it all runs the
## Runaway Mine Train: lift hill behind the east row, a drop and a vertical
## loop over the street, a tunnel into the west cliff (the train really runs).
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_boomtown.gd
##
## Run it with a renderer (not --headless): the headless renderer keeps no
## MultiMesh instance data, so fences, ties and trestles would save empty.
##
## NOTE: running this overwrites hand edits made to boomtown.tscn.
##
## Layout (metres, top view; -Z = north; street y 0, boardwalks y 0.2):
##   - Main Street x -7..7 from the mine yard (z -46..-35) to the gate (z 27);
##     boardwalks x +-(7..9.6); facades at x +-9.6.
##   - West row (fronts face east): bank z -35..-23, sheriff -23..-15, alley,
##     saloon -10..4 (balcony y 3.6, stairs up from the south alley), alley,
##     store 12..23. The back lane runs behind it (x -26..-19.6).
##   - East row (fronts face west): assay -35..-27, livery -27..-13 (open both
##     ends), corral alley, the water tower deck (y 3.2) round (14.5, -3.5),
##     hotel 9..23. The corral runs behind it (x 19.6..30).
##   - Coaster: lift hill along x 35, the drop west along z 24.5, the loop over
##     the street at x 0, out west along z 26 into the west cliff.
##   - Entrances: gold mine (N), canyon trail (NE), back lane (W), corral gate
##     (E), stage road (SE, through the south plaza).

const OUT_PATH := "res://scenes/levels/boomtown.tscn"
const MODELS := "res://art/models/"
const TEXTURES := "res://art/textures/"
const SHADERS := "res://art/shaders/"

const STATION := Vector3(0.0, 0.0, -2.0)
const PORTAL := Vector3(0.0, 0.0, 34.0)
const STREET := 7.0          # street half-width
const FACADE := 9.6          # facade line (|x|)
const WALK_Y := 0.2          # boardwalk top
const ROW_N := -35.0         # north end of both rows
const ROW_S := 23.0          # south end of both rows
const GATE_Z := 27.0
const MINE_Z := -46.0        # north cliff face
const WEST_CLIFF := -26.0
const CORRAL_X := 30.0
const PLAZA_S := 38.0
const SUN_DIRECTION := Vector3(0.42, 0.82, 0.38)   # toward the sun (high, south-east)
const PLAYER_WALL_H := 12.0

# Saloon (west row, centre z -3): see art/blender/build_gulch_town.py.
const SALOON_Z := -3.0
const BALCONY_Y := 3.6
# Water tower deck (east row).
const TOWER := Vector3(14.5, 0.0, -3.5)
const TOWER_DECK := 3.2
const TOWER_HALF := 3.2
# Coaster.
const LOOP_C := Vector3(0.0, 16.5, 24.5)
const LOOP_R := 6.5
const LOOP_DRIFT := 1.5
const TRACK_Y := 10.0
const LIFT_X := 35.0
const TOP_Y := 24.0

var level: Node3D
var geo: Node3D          # collidable geometry (navmesh source)
var dressing: Node3D     # non-colliding scenery
var _materials := {}
var _boxes := {}
var _late_scripts: Array = []
var _light_count := 0
var _mesh_cache := {}
# Coaster path: points, frame up vectors, and which samples are hidden (inside rock).
var _track := PackedVector3Array()
var _hidden: Array[bool] = []
var _lift_range := Vector2.ZERO
var _loop_start := 0.0


func _initialize() -> void:
	level = Node3D.new()
	level.name = "Boomtown"
	_build_environment()
	var nav := NavigationRegion3D.new()
	nav.name = "NavigationRegion3D"
	level.add_child(nav)
	geo = Node3D.new()
	geo.name = "Geometry"
	nav.add_child(geo)
	dressing = Node3D.new()
	dressing.name = "Dressing"
	level.add_child(dressing)

	_build_ground()
	_build_west_row()
	_build_east_row()
	_build_saloon_extras()
	_build_tower()
	_build_mine_yard()
	_build_edges()
	_build_gate_and_plaza()
	_build_station()
	_build_street_props()
	_build_bunting()
	_build_coaster()
	_build_backdrop()
	_build_lights()
	_build_exit()
	_build_markers()
	var storm := Node3D.new()
	storm.name = "DustStorm"
	level.add_child(storm)
	_late(storm, "res://scripts/props/gulch_dust_storm.gd", {})

	get_root().add_child(level)
	await process_frame
	_bake_navigation(nav)
	get_root().remove_child(level)

	for entry in _late_scripts:
		var node: Node = entry[0]
		node.set_script(load(entry[1]))
		for key in entry[2]:
			node.set(key, entry[2][key])
	level.set_script(load("res://scripts/run/level_environment.gd"))
	var director := Node.new()
	director.name = "RunDirector"
	director.set_script(load("res://scripts/run/run_director.gd"))
	level.add_child(director)

	_own(level)
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_PATH)
	print("build_boomtown: saved %s (error %d), %d omni lights" % [OUT_PATH, err, _light_count])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: high noon, a hot white-gold sun, turquoise sky fill
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SHADERS + "gulch_sky.gdshader")
	sky_mat.set_shader_parameter("sun_direction", SUN_DIRECTION.normalized())
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.8, 0.84)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.6
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.92, 0.88, 0.78)
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.looking_at(-SUN_DIRECTION.normalized(), Vector3.FORWARD), Vector3(0, 30, 0))
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_opacity = 0.75
	level.add_child(sun)

	# The turquoise sky bouncing back into the shade side.
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.transform = Transform3D(Basis.looking_at(-Vector3(-0.5, 0.6, -0.6).normalized(), Vector3.UP), Vector3(0, 30, 0))
	fill.light_color = Color(0.55, 0.85, 0.9)
	fill.light_energy = 0.28
	fill.shadow_enabled = false
	level.add_child(fill)


# ---------------------------------------------------------------------------
# Ground: the street, yards, boardwalks
# ---------------------------------------------------------------------------

func _build_ground() -> void:
	var g := Node3D.new()
	g.name = "Ground"
	geo.add_child(g)
	var dirt := _textured("dirt", "gulch_dirt", 0.12, 0.95)
	dirt.albedo_color = Color(0.9, 0.82, 0.76)
	var sand := _textured("sand", "gulch_sand", 0.14, 0.95)
	sand.albedo_color = Color(0.88, 0.78, 0.68)
	_box(g, "Floor", Vector3(150, 1.0, 150), Vector3(5, -0.5 - 0.02, -5), dirt)
	_collider(g, "FloorTop", Vector3(150, 0.4, 150), Vector3(5, -0.2, -5))
	_visual_box(dressing, "Street", Vector3(2 * STREET, 0.04, PLAZA_S - MINE_Z + 4.0), Vector3(0, -0.02, (PLAZA_S + MINE_Z) * 0.5), sand)
	_visual_box(dressing, "Plaza", Vector3(40.0, 0.04, PLAZA_S - GATE_Z), Vector3(6.0, -0.021, (PLAZA_S + GATE_Z) * 0.5), sand)
	var boards := _textured("boards", "gulch_boards", 0.32, 0.85)
	for s: float in [-1.0, 1.0]:
		var x := s * (STREET + FACADE) * 0.5
		_box(g, "Boardwalk%s" % ("W" if s < 0 else "E"), Vector3(FACADE - STREET, WALK_Y, ROW_S - ROW_N),
			Vector3(x, WALK_Y * 0.5, (ROW_S + ROW_N) * 0.5), boards)
		_visual_box(dressing, "BoardwalkKerb%s" % ("W" if s < 0 else "E"), Vector3(0.14, 0.24, ROW_S - ROW_N),
			Vector3(s * (STREET + 0.05), 0.1, (ROW_S + ROW_N) * 0.5), _mat("kerb", Color(0.43, 0.27, 0.17), 0.8))
		# Gentle collision ramps up both edges, so nobody snags on the 0.2 m step.
		_ramp(g, "WalkRampStreet%d" % int(s), Vector3(s * STREET, 0, ROW_N), Vector3(s * STREET, 0, ROW_S), -s, WALK_Y, 0.55)
		_ramp(g, "WalkRampBack%d" % int(s), Vector3(s * FACADE, 0, ROW_N), Vector3(s * FACADE, 0, ROW_S), s, WALK_Y, 0.55)


# ---------------------------------------------------------------------------
# Building rows
# ---------------------------------------------------------------------------

## A closed false-front building on a row: `side` -1 west (front faces east),
## +1 east. `zc` is its centre along the street, `w` its width along the
## street, `d` its depth, `f` its false-front height.
func _shop(model: String, node_name: String, side: float, zc: float, w: float, d: float, f: float, posts: int, post_r := 0.15) -> void:
	var parent := geo.get_node("Rows") as Node3D
	var yaw := 90.0 if side < 0 else -90.0
	_prop(parent, model, node_name, Vector3(side * FACADE, 0, zc), yaw, Vector3(d, f, w))
	_collider(parent, node_name + "Body", Vector3(d + 0.3, f, w), Vector3(side * (FACADE + d * 0.5 - 0.15), f * 0.5, zc))
	_porch_posts(parent, node_name, side, zc, w, posts, 2.22, post_r)


func _porch_posts(parent: Node3D, node_name: String, side: float, zc: float, w: float, count: int, depth: float, r: float) -> void:
	for i in count:
		var t := float(i) / maxf(1.0, count - 1)
		var along := lerpf(-w * 0.5 + 0.3, w * 0.5 - 0.3, t)
		var z := zc - along if side < 0 else zc + along
		_post(parent, "%sPost%d" % [node_name, i], r, 3.0, Vector3(side * (FACADE - depth), WALK_Y, z))
		_cap(parent, "%sPostCap%d" % [node_name, i], Vector3(side * (FACADE - depth), WALK_Y + 3.0, z))


func _build_west_row() -> void:
	var rows := Node3D.new()
	rows.name = "Rows"
	geo.add_child(rows)
	_shop("gulch_bank", "Bank", -1.0, -29.0, 12.0, 9.0, 8.2, 0)
	# The bank's portico columns (4, radius 0.24, 2.3 m out).
	for i in 4:
		var along := -6.0 + 0.6 + 10.8 * i / 3.0
		_post(rows, "BankColumn%d" % i, 0.3, 3.0, Vector3(-(FACADE - 2.1), WALK_Y, -29.0 - along))
		_cap(rows, "BankColumnCap%d" % i, Vector3(-(FACADE - 2.1), WALK_Y + 3.0, -29.0 - along))
	_shop("gulch_sheriff", "Sheriff", -1.0, -19.0, 8.0, 8.0, 6.6, 2)
	_shop("gulch_store", "Store", -1.0, 17.5, 11.0, 9.0, 7.6, 3)
	_build_saloon()


func _build_east_row() -> void:
	var rows := geo.get_node("Rows") as Node3D
	_shop("gulch_assay", "Assay", 1.0, -31.0, 8.0, 9.0, 7.0, 2)
	_shop("gulch_hotel", "Hotel", 1.0, 16.0, 14.0, 10.0, 9.0, 4)
	_build_livery(rows)


## The saloon: wall colliders round the walk-in bar room, the bar, tables,
## piano and stage, the balcony deck and its railing.
func _build_saloon() -> void:
	var rows := geo.get_node("Rows") as Node3D
	var s := Node3D.new()
	s.name = "Saloon"
	rows.add_child(s)
	var zc := SALOON_Z
	_prop(s, "gulch_saloon", "SaloonModel", Vector3(-FACADE, 0, zc), 90.0, Vector3(10, 9, 14))
	var back := -FACADE - 10.0
	var f := 9.6
	# Front wall (with the parapet: x -9.9..-9.3), the doorway z zc-1.2..zc+1.2.
	_collider(s, "FrontN", Vector3(0.6, f, 5.8), Vector3(-FACADE, f * 0.5, zc - 4.1))
	_collider(s, "FrontS", Vector3(0.6, f, 5.8), Vector3(-FACADE, f * 0.5, zc + 4.1))
	_collider(s, "FrontLintel", Vector3(0.6, f - 2.7, 2.4), Vector3(-FACADE, 2.7 + (f - 2.7) * 0.5, zc))
	# Back wall, the back door at z zc-3.8..zc-2.2.
	_collider(s, "BackN", Vector3(0.3, f, 3.2), Vector3(back + 0.15, f * 0.5, zc - 5.4))
	_collider(s, "BackS", Vector3(0.3, f, 9.2), Vector3(back + 0.15, f * 0.5, zc + 2.4))
	_collider(s, "BackLintel", Vector3(0.3, f - 2.4, 1.6), Vector3(back + 0.15, 2.4 + (f - 2.4) * 0.5, zc - 3.0))
	_collider(s, "SideN", Vector3(10.0, f, 0.3), Vector3(-FACADE - 5.0, f * 0.5, zc - 6.85))
	_collider(s, "SideS", Vector3(10.0, f, 0.3), Vector3(-FACADE - 5.0, f * 0.5, zc + 6.85))
	_player_block(s, "Lid", Vector3(10.4, 1.0, 14.4), Vector3(-FACADE - 5.0, f + 0.5, zc))
	_collider(s, "Ceiling", Vector3(10.0, 0.3, 14.0), Vector3(-FACADE - 5.0, 3.65, zc))
	_collider(s, "Floor", Vector3(9.6, WALK_Y, 13.6), Vector3(-FACADE - 4.9, WALK_Y * 0.5, zc))
	_ramp(s, "BackStep", Vector3(back, 0, zc - 3.9), Vector3(back, 0, zc - 2.1), -1.0, WALK_Y, 0.55)
	# Inside: the bar, the back bar, tables, piano and stage.
	_collider(s, "Bar", Vector3(0.7, 1.34, 6.4), Vector3(-FACADE - 7.7, 0.67, zc + 2.6))
	_collider(s, "BackBar", Vector3(0.5, 1.2, 6.8), Vector3(-FACADE - 9.4, 0.6, zc + 2.6))
	for t: Vector2 in [Vector2(2.8, 3.0), Vector2(4.6, 6.4), Vector2(-3.4, 3.6), Vector2(0.4, 5.6)]:
		_post(s, "Table%d%d" % [int(t.x * 10), int(t.y * 10)], 0.75, 1.05, Vector3(-FACADE - t.y, 0.2, zc - t.x))
	_collider(s, "Piano", Vector3(1.7, 1.6, 0.8), Vector3(-FACADE - 4.0, 0.8, zc - 6.25))
	_collider(s, "Stage", Vector3(2.6, 0.6, 3.6), Vector3(-FACADE - 8.3, 0.3, zc - 4.8))
	# Balcony deck over the boardwalk and its railing (front and north end).
	_collider(s, "Balcony", Vector3(2.8, 0.3, 14.2), Vector3(-FACADE + 1.4, BALCONY_Y - 0.15, zc))
	_collider(s, "BalconyRail", Vector3(0.2, 1.15, 14.2), Vector3(-FACADE + 2.72, BALCONY_Y + 0.575, zc))
	_collider(s, "BalconyRailN", Vector3(2.8, 1.15, 0.2), Vector3(-FACADE + 1.4, BALCONY_Y + 0.575, zc - 6.95))
	_player_block(s, "BalconyRailCap", Vector3(0.4, 6.0, 16.2), Vector3(-FACADE + 2.8, BALCONY_Y + 4.1, zc + 1.0))
	_porch_posts(s, "Saloon", -1.0, zc, 14.0, 4, 2.62, 0.16)


## The livery barn: walls round its open front and back, the stall partitions.
func _build_livery(rows: Node3D) -> void:
	var zc := -20.0
	var l := Node3D.new()
	l.name = "Livery"
	rows.add_child(l)
	_prop(l, "gulch_livery", "LiveryModel", Vector3(FACADE, 0, zc), -90.0, Vector3(10, 8, 14))
	var back := FACADE + 10.0
	for x: float in [FACADE + 0.15, back - 0.15]:
		var tag := "Front" if x < FACADE + 1.0 else "Back"
		_collider(l, tag + "N", Vector3(0.3, 4.8, 4.5), Vector3(x, 2.4, zc - 4.75))
		_collider(l, tag + "S", Vector3(0.3, 4.8, 4.5), Vector3(x, 2.4, zc + 4.75))
		_collider(l, tag + "Gable", Vector3(0.3, 4.2, 14.0), Vector3(x, 4.2 + 2.1, zc))
	_collider(l, "SideN", Vector3(10.0, 4.8, 0.3), Vector3(FACADE + 5.0, 2.4, zc - 6.85))
	_collider(l, "SideS", Vector3(10.0, 4.8, 0.3), Vector3(FACADE + 5.0, 2.4, zc + 6.85))
	_collider(l, "Loft", Vector3(10.0, 0.3, 14.0), Vector3(FACADE + 5.0, 4.95, zc))
	for s: float in [-1.0, 1.0]:
		for k in 4:
			var y := 0.9 + k * 2.75
			_collider(l, "Stall%d%d" % [int(s), k], Vector3(0.16, 1.4, 2.4), Vector3(FACADE + y, 0.7, zc + s * 5.5))
		_collider(l, "Hay%d" % int(s), Vector3(9.4, 0.8, 1.6), Vector3(FACADE + 5.0, 0.4, zc + s * 6.0))
	_porch_posts(l, "Livery", 1.0, zc, 14.0, 0, 2.22, 0.15)


## Stairs from the south alley up to the balcony and the landing at the top.
func _build_saloon_extras() -> void:
	var s := geo.get_node("Rows/Saloon") as Node3D
	var zs := SALOON_Z + 7.0 + 1.05      # stair centre line (just south of the saloon)
	_stairs(s, "BalconyStairs", Vector3(-FACADE - 1.0, BALCONY_Y, zs), Vector3(-FACADE - 7.6, 0.0, zs), 1.9)
	var planks := _textured("boards", "gulch_boards", 0.32, 0.85)
	var land_z0 := SALOON_Z + 7.1
	var land_z1 := zs + 1.0
	_box(s, "Landing", Vector3(3.8, 0.3, land_z1 - land_z0), Vector3(-FACADE + 0.9, BALCONY_Y - 0.15, (land_z0 + land_z1) * 0.5), planks)
	_box(s, "LandingRailS", Vector3(3.8, 1.1, 0.12), Vector3(-FACADE + 0.9, BALCONY_Y + 0.55, land_z1 - 0.06), _mat("trim", Color(0.98, 0.91, 0.78), 0.6))
	_box(s, "LandingRailE", Vector3(0.12, 1.1, land_z1 - land_z0), Vector3(-FACADE + 2.74, BALCONY_Y + 0.55, (land_z0 + land_z1) * 0.5),
		_mat("trim", Color(0.98, 0.91, 0.78), 0.6))
	for x: float in [-FACADE + 2.6, -FACADE - 0.8]:
		_box(s, "LandingPost%d" % int(x * 10), Vector3(0.26, BALCONY_Y - WALK_Y, 0.26), Vector3(x, (BALCONY_Y + WALK_Y) * 0.5, land_z1 - 0.2),
			_mat("post", Color(0.81, 0.58, 0.38), 0.8))
	_player_block(s, "LandingCap", Vector3(4.2, 6.0, 0.4), Vector3(-FACADE + 0.9, BALCONY_Y + 4.1, land_z1))
	_player_block(s, "LandingCapE", Vector3(0.4, 6.0, land_z1 - land_z0 + 0.4), Vector3(-FACADE + 2.8, BALCONY_Y + 4.1, (land_z0 + land_z1) * 0.5))


# ---------------------------------------------------------------------------
# Water tower deck (east row high ground)
# ---------------------------------------------------------------------------

func _build_tower() -> void:
	var t := Node3D.new()
	t.name = "WaterTower"
	geo.add_child(t)
	_prop(t, "gulch_water_tower", "TowerModel", TOWER, -90.0, Vector3(6, 12, 6))
	_collider(t, "Deck", Vector3(2 * TOWER_HALF, 0.3, 2 * TOWER_HALF), TOWER + Vector3(0, TOWER_DECK - 0.15, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_post(t, "Leg%d%d" % [int(sx), int(sz)], 0.22, TOWER_DECK, TOWER + Vector3(sx * 2.2, 0, sz * 2.2))
			_post(t, "DeckPost%d%d" % [int(sx), int(sz)], 0.15, TOWER_DECK, TOWER + Vector3(sx * (TOWER_HALF - 0.15), 0, sz * (TOWER_HALF - 0.15)))
			_post(t, "UpperLeg%d%d" % [int(sx), int(sz)], 0.22, 4.0, TOWER + Vector3(sx * 2.2, TOWER_DECK, sz * 2.2))
	# Railings: the opening is on the south side's west end (where the stairs land).
	var y := TOWER_DECK + 0.55
	var h := TOWER_HALF
	_collider(t, "RailN", Vector3(2 * h, 1.1, 0.15), TOWER + Vector3(0, y, -h))
	_collider(t, "RailE", Vector3(0.15, 1.1, 2 * h), TOWER + Vector3(h, y, 0))
	_collider(t, "RailW", Vector3(0.15, 1.1, 2 * h), TOWER + Vector3(-h, y, 0))
	_collider(t, "RailS", Vector3(2 * h - 2.2, 1.1, 0.15), TOWER + Vector3(1.1, y, h))
	for side in ["N", "E", "W"]:
		var off := {"N": Vector3(0, 0, -h), "E": Vector3(h, 0, 0), "W": Vector3(-h, 0, 0)}[side] as Vector3
		var size := Vector3(2 * h + 0.4, 6.0, 0.4) if side == "N" else Vector3(0.4, 6.0, 2 * h + 0.4)
		_player_block(t, "RailCap" + side, size, TOWER + off + Vector3(0, TOWER_DECK + 4.1, 0))
	_player_block(t, "RailCapS", Vector3(2 * h - 1.8, 6.0, 0.4), TOWER + Vector3(1.1, TOWER_DECK + 4.1, h))
	_stairs(t, "TowerStairs", TOWER + Vector3(-h + 1.1, TOWER_DECK, h), TOWER + Vector3(-h + 1.1, 0.0, h + 6.0), 1.8)
	# Barrels on the deck.
	_solid_prop(t, "gulch_barrels", "DeckBarrels", TOWER + Vector3(1.9, TOWER_DECK, 1.9), 30.0, Vector3(1.6, 1.8, 1.0))


# ---------------------------------------------------------------------------
# North: the mine yard under the mesa
# ---------------------------------------------------------------------------

func _build_mine_yard() -> void:
	var m := Node3D.new()
	m.name = "MineYard"
	geo.add_child(m)
	_prop(m, "gulch_mine_mouth", "MineMouth", Vector3(-2.0, 0, MINE_Z + 1.5), 0.0, Vector3(6, 6, 1))
	for s: float in [-1.0, 1.0]:
		_post(m, "MinePost%d" % int(s), 0.35, 4.6, Vector3(-2.0 + s * 2.45, 0, MINE_Z + 1.5))
		_cap(m, "MinePostCap%d" % int(s), Vector3(-2.0 + s * 2.45, 4.6, MINE_Z + 1.5))
	_solid_prop(m, "gulch_crates", "MineCrates", Vector3(-8.5, 0, -42.5), 20.0, Vector3(1.6, 1.5, 1.2))
	_solid_prop(m, "gulch_barrels", "MineBarrels", Vector3(5.5, 0, -43.0), -20.0, Vector3(1.6, 1.8, 1.0))
	_solid_prop(m, "gulch_wagon", "OreWagon", Vector3(14.0, 0, -41.0), 70.0, Vector3(2.0, 3.0, 4.4))
	_solid_prop(m, "gulch_hay", "MineHay", Vector3(-17.0, 0, -40.0), 10.0, Vector3(1.6, 1.6, 1.0))
	_solid_prop(m, "gulch_coaster_car", "OreCartA", Vector3(-6.8, 0, -42.5), 15.0, Vector3(1.4, 1.4, 2.0))
	_prop(dressing, "gulch_cactus_a", "MineCactusA", Vector3(-22.0, 0, -43.0), 30.0, Vector3(1, 3.6, 1))
	_post(m, "MineCactusAPost", 0.4, 3.6, Vector3(-22.0, 0, -43.0))
	_cap(m, "MineCactusACap", Vector3(-22.0, 3.6, -43.0))
	_prop(dressing, "gulch_cactus_b", "MineCactusB", Vector3(21.0, 0, -44.0), 200.0, Vector3(1, 2.6, 1))
	_post(m, "MineCactusBPost", 0.4, 2.6, Vector3(21.0, 0, -44.0))
	_cap(m, "MineCactusBCap", Vector3(21.0, 2.6, -44.0))
	for k in 3:
		_lamp(m, "MineLamp%d" % k, Vector3(-12.0 + k * 12.0, 0, -37.2), 90.0)


func _lamp(parent: Node3D, lamp_name: String, pos: Vector3, yaw: float) -> void:
	_prop(dressing, "gulch_lamp", lamp_name, pos, yaw, Vector3(0.3, 3.4, 0.3))
	_post(parent, lamp_name + "Post", 0.14, 3.2, pos)
	_cap(parent, lamp_name + "Cap", pos + Vector3(0, 3.2, 0))


# ---------------------------------------------------------------------------
# Edges: cliffs, back lane and corral fences, player walls
# ---------------------------------------------------------------------------

func _build_edges() -> void:
	var e := Node3D.new()
	e.name = "Edges"
	geo.add_child(e)
	var walls := _player_walls()
	# Cliffs (visual) with box colliders on their faces.
	for z: float in [-40.0, -14.0, 12.0, 36.0]:
		_cliff(Vector3(WEST_CLIFF - 5.6, 0, z), 90.0, Vector3(1.0, 1.0 + fposmod(z, 7.0) * 0.04, 1.0))
	for x: float in [-26.0, 0.0, 26.0, 50.0]:
		_cliff(Vector3(x, 0, MINE_Z - 5.6), 0.0, Vector3(1.0, 1.15 + fposmod(x, 5.0) * 0.05, 1.0))
	for z: float in [-42.0, -18.0, 6.0, 30.0]:
		_cliff(Vector3(48.6, 0, z), -90.0, Vector3(1.0, 1.05 + fposmod(z, 4.0) * 0.04, 1.0))
	_collider(e, "WestCliffWall", Vector3(10.0, 30.0, 110.0), Vector3(WEST_CLIFF - 5.0, 15.0, -5.0))
	_collider(e, "NorthCliffWall", Vector3(100.0, 30.0, 10.0), Vector3(5.0, 15.0, MINE_Z - 5.0))
	# The canyon trail (north-east): a notch between the north cliff and a butte.
	_prop(dressing, "gulch_butte", "TrailButte", Vector3(37.0, 0, -50.0), 20.0, Vector3(12, 28, 12))
	_post(e, "TrailButteBody", 6.5, 30.0, Vector3(37.0, 0, -50.0))
	for b in [[Vector3(-24.0, 0, -36.0), 20.0], [Vector3(-24.5, 0, 14.0), 140.0], [Vector3(28.5, 0, 21.0), 70.0], [Vector3(23.0, 0, -44.5), 0.0],
			[Vector3(-12.0, 0, -45.0), 110.0]]:
		_solid_prop(e, "gulch_boulder", "Boulder%d" % int(b[0].z * 10 + b[0].x), b[0], b[1], Vector3(2.0, 1.4, 1.8))
	# Back-lane fence at the south end and the corral fences.
	_fence_run(e, "BackLaneFenceS", Vector3(WEST_CLIFF, 0, 23.5), Vector3(-FACADE - 9.0, 0, 23.5))
	_fence_run(e, "CorralFenceE", Vector3(CORRAL_X, 0, -38.0), Vector3(CORRAL_X, 0, -12.0))
	_fence_run(e, "CorralFenceE2", Vector3(CORRAL_X, 0, -7.0), Vector3(CORRAL_X, 0, 23.5))
	_fence_run(e, "CorralFenceS", Vector3(FACADE + 10.0, 0, 23.5), Vector3(CORRAL_X, 0, 23.5))
	_fence_run(e, "CorralFenceN", Vector3(CORRAL_X, 0, -38.0), Vector3(33.0, 0, -41.0))
	_player_wall(walls, "WallCorralE", Vector3(CORRAL_X, 0, -38.0), Vector3(CORRAL_X, 0, 23.5), PLAYER_WALL_H)
	_player_wall(walls, "WallBackLaneS", Vector3(WEST_CLIFF, 0, 23.5), Vector3(-FACADE - 9.0, 0, 23.5), PLAYER_WALL_H)
	_player_wall(walls, "WallCorralS", Vector3(FACADE + 10.0, 0, 23.5), Vector3(CORRAL_X, 0, 23.5), PLAYER_WALL_H)
	_player_wall(walls, "WallTrail", Vector3(CORRAL_X, 0, -38.0), Vector3(33.0, 0, -41.0), PLAYER_WALL_H)
	_player_wall(walls, "WallTrailN", Vector3(33.0, 0, -41.0), Vector3(33.0, 0, MINE_Z), PLAYER_WALL_H)
	# The corral gate (open) where the east entrance comes in.
	for z: float in [-12.0, -7.0]:
		_post(e, "GatePost%d" % int(-z), 0.18, 1.6, Vector3(CORRAL_X, 0, z))
		_visual_box(dressing, "GatePostV%d" % int(-z), Vector3(0.3, 1.6, 0.3), Vector3(CORRAL_X, 0.8, z), _mat("post", Color(0.81, 0.58, 0.38), 0.8))
	# Corral dressing: hay, trough, a wagon, cacti.
	_solid_prop(e, "gulch_trough", "CorralTrough", Vector3(25.0, 0, -22.0), 90.0, Vector3(2.4, 0.9, 0.8))
	_solid_prop(e, "gulch_hay", "CorralHay", Vector3(26.5, 0, 6.0), 30.0, Vector3(1.6, 1.6, 1.0))
	_solid_prop(e, "gulch_wagon", "CorralWagon", Vector3(25.5, 0, 15.0), 10.0, Vector3(2.0, 3.0, 4.4))
	_solid_prop(e, "gulch_hay", "BackLaneHay", Vector3(-23.5, 0, -24.0), 80.0, Vector3(1.6, 1.6, 1.0))
	_solid_prop(e, "gulch_barrels", "BackLaneBarrels", Vector3(-23.6, 0, 17.0), 100.0, Vector3(1.6, 1.8, 1.0))
	_solid_prop(e, "gulch_crates", "BackLaneCrates", Vector3(-21.2, 0, -6.0), 80.0, Vector3(1.6, 1.5, 1.2))
	for c in [[Vector3(23.0, 0, -32.0), "a"], [Vector3(27.5, 0, -2.0), "b"], [Vector3(-24.0, 0, 3.0), "b"]]:
		_prop(dressing, "gulch_cactus_" + c[1], "Cactus%d" % int(c[0].z), c[0], c[0].x * 7.0, Vector3(1, 3, 1))
		_post(e, "CactusPost%d" % int(c[0].z), 0.4, 3.0, c[0])
		_cap(e, "CactusCap%d" % int(c[0].z), c[0] + Vector3(0, 3.0, 0))


## A red-rock cliff block. It casts no shadow: its broad faces only ever
## shadowed themselves (acne) under the high sun.
func _cliff(pos: Vector3, yaw: float, scale: Vector3) -> void:
	var c := MeshInstance3D.new()
	c.name = "Cliff%d_%d" % [int(pos.x), int(pos.z)]
	c.mesh = _model_mesh("gulch_cliff")
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(c)
	c.position = pos
	c.rotation.y = deg_to_rad(yaw)
	c.scale = scale


# ---------------------------------------------------------------------------
# South: the BOOMTOWN gate, palisade and the plaza
# ---------------------------------------------------------------------------

func _build_gate_and_plaza() -> void:
	var p := Node3D.new()
	p.name = "Plaza"
	geo.add_child(p)
	var walls := _player_walls()
	_prop(p, "gulch_gate", "Gate", Vector3(0, 0, GATE_Z), 0.0, Vector3(18, 8, 1))
	for s: float in [-1.0, 1.0]:
		_post(p, "GatePost%d" % int(s), 0.55, 8.0, Vector3(s * 8.2, 0, GATE_Z))
		_cap(p, "GatePostCap%d" % int(s), Vector3(s * 8.2, 8.0, GATE_Z))
		_collider(p, "GateFooting%d" % int(s), Vector3(1.6, 0.6, 1.6), Vector3(s * 8.2, 0.3, GATE_Z))
	_palisade(p, "PalisadeW", Vector3(WEST_CLIFF, 0, GATE_Z), Vector3(-8.9, 0, GATE_Z))
	_palisade(p, "PalisadeE", Vector3(8.9, 0, GATE_Z), Vector3(CORRAL_X + 4.0, 0, GATE_Z))
	_player_wall(walls, "WallGateW", Vector3(WEST_CLIFF, 0, GATE_Z), Vector3(-8.7, 0, GATE_Z), PLAYER_WALL_H)
	_player_wall(walls, "WallGateE", Vector3(8.7, 0, GATE_Z), Vector3(CORRAL_X + 4.0, 0, GATE_Z), PLAYER_WALL_H)
	# The corners between the rows' ends and the gate posts are closed.
	_palisade(p, "CornerW", Vector3(-FACADE, 0, ROW_S), Vector3(-8.7, 0, GATE_Z - 0.3))
	_palisade(p, "CornerE", Vector3(8.7, 0, GATE_Z - 0.3), Vector3(FACADE, 0, ROW_S))
	_player_wall(walls, "WallCornerW", Vector3(-FACADE, 0, ROW_S), Vector3(-8.7, 0, GATE_Z - 0.3), PLAYER_WALL_H)
	_player_wall(walls, "WallCornerE", Vector3(8.7, 0, GATE_Z - 0.3), Vector3(FACADE, 0, ROW_S), PLAYER_WALL_H)
	# Plaza boundary: a rail fence to the south and west, rocks and a wagon east.
	_fence_run(p, "PlazaFenceS", Vector3(-14.0, 0, PLAZA_S), Vector3(27.0, 0, PLAZA_S))
	_fence_run(p, "PlazaFenceW", Vector3(-14.0, 0, GATE_Z), Vector3(-14.0, 0, PLAZA_S))
	_fence_run(p, "PlazaFenceE", Vector3(27.0, 0, GATE_Z), Vector3(27.0, 0, 30.5))
	_player_wall(walls, "WallPlazaS", Vector3(-14.0, 0, PLAZA_S), Vector3(27.0, 0, PLAZA_S), PLAYER_WALL_H)
	_player_wall(walls, "WallPlazaW", Vector3(-14.0, 0, GATE_Z), Vector3(-14.0, 0, PLAZA_S), PLAYER_WALL_H)
	_player_wall(walls, "WallPlazaE", Vector3(27.0, 0, GATE_Z), Vector3(27.0, 0, PLAZA_S), PLAYER_WALL_H)
	_solid_prop(p, "gulch_wagon", "StageWagon", Vector3(25.5, 0, 35.3), 95.0, Vector3(2.0, 3.0, 4.4))
	_solid_prop(p, "gulch_boulder", "PlazaRockE", Vector3(25.5, 0, 31.0), 40.0, Vector3(2.0, 1.4, 1.8))
	_solid_prop(p, "gulch_hay", "PlazaHayW", Vector3(-11.0, 0, 30.0), 20.0, Vector3(1.6, 1.6, 1.0))
	_solid_prop(p, "gulch_barrels", "PlazaBarrels", Vector3(-11.5, 0, 36.0), 70.0, Vector3(1.6, 1.8, 1.0))
	_solid_prop(p, "gulch_trough", "PlazaTrough", Vector3(9.0, 0, 30.6), 0.0, Vector3(2.4, 0.9, 0.8))
	for c in [[Vector3(-6.0, 0, 36.5), "a"], [Vector3(7.5, 0, 36.6), "b"], [Vector3(16.0, 0, 29.5), "a"]]:
		_prop(dressing, "gulch_cactus_" + c[1], "PlazaCactus%d" % int(c[0].x), c[0], c[0].x * 11.0, Vector3(1, 3, 1))
		_post(p, "PlazaCactusPost%d" % int(c[0].x), 0.4, 3.0, c[0])
		_cap(p, "PlazaCactusCap%d" % int(c[0].x), c[0] + Vector3(0, 3.0, 0))
	for k in 2:
		_lamp(p, "PlazaLamp%d" % k, Vector3(-4.0 + k * 8.0, 0, 29.0), 90.0 + k * 180.0)


func _palisade(parent: Node3D, run_name: String, a: Vector3, b: Vector3) -> void:
	_fence_run(parent, run_name, a, b, "gulch_palisade", 2.0, 3.2)


# ---------------------------------------------------------------------------
# Station and street dressing
# ---------------------------------------------------------------------------

func _build_station() -> void:
	var station: Node3D = (load("res://scenes/props/gulch_station.tscn") as PackedScene).instantiate()
	station.name = "Station"
	geo.add_child(station)
	station.position = STATION
	station.rotation.y = deg_to_rad(4.0)


func _build_street_props() -> void:
	var s := Node3D.new()
	s.name = "StreetProps"
	geo.add_child(s)
	# Cover in the street: a parked wagon, troughs, hay, barrels and crates.
	_solid_prop(s, "gulch_wagon", "StreetWagon", Vector3(-3.6, 0, -17.5), 8.0, Vector3(2.0, 3.0, 4.4))
	_solid_prop(s, "gulch_trough", "TroughN", Vector3(4.4, 0, -25.0), 90.0, Vector3(2.4, 0.9, 0.8))
	_solid_prop(s, "gulch_trough", "TroughS", Vector3(-4.6, 0, 9.5), 90.0, Vector3(2.4, 0.9, 0.8))
	_solid_prop(s, "gulch_hay", "HayE", Vector3(4.2, 0, 7.5), 20.0, Vector3(1.6, 1.6, 1.0))
	_solid_prop(s, "gulch_hay", "HayN", Vector3(3.6, 0, -11.5), -15.0, Vector3(1.6, 1.6, 1.0))
	_solid_prop(s, "gulch_barrels", "BarrelsW", Vector3(-4.4, 0, -30.0), 10.0, Vector3(1.6, 1.8, 1.0))
	_solid_prop(s, "gulch_crates", "CratesS", Vector3(4.3, 0, 21.6), 30.0, Vector3(1.6, 1.5, 1.2))
	# On the boardwalks: hitching rails, barrels, crates, benches of hay.
	for h in [[Vector3(-6.4, 0, -19.0)], [Vector3(-6.4, 0, 12.0 + 5.5)], [Vector3(6.4, 0, -31.0)], [Vector3(6.4, 0, 16.0)]]:
		_solid_prop(s, "gulch_hitch", "Hitch%d" % int(h[0].z * 10 + h[0].x), h[0], 90.0, Vector3(3.0, 1.1, 0.25))
	# Two toy horses tied at the rails, noses to the boardwalk.
	_solid_prop(s, "gulch_horse_a", "HorseW", Vector3(-4.6, 0, 18.1), -90.0, Vector3(0.8, 1.9, 2.5))
	_solid_prop(s, "gulch_horse_b", "HorseE", Vector3(4.6, 0, 15.4), 90.0, Vector3(0.8, 1.9, 2.5))
	_solid_prop(s, "gulch_barrels", "WalkBarrelsE", Vector3(8.7, WALK_Y, 21.5), 90.0, Vector3(1.6, 1.8, 1.0))
	_solid_prop(s, "gulch_crates", "WalkCratesW", Vector3(-8.7, WALK_Y, -33.6), 100.0, Vector3(1.6, 1.5, 1.2))
	for i in 6:
		var z := -32.0 + i * 10.6
		_lamp(s, "StreetLampW%d" % i, Vector3(-7.25, WALK_Y, z + 2.0), 0.0)
		_lamp(s, "StreetLampE%d" % i, Vector3(7.25, WALK_Y, z - 3.0), 180.0)


## Pennant strings across Main Street from facade to facade (one fluttering
## mesh, shaded by the shared bunting shader) and their ropes.
func _build_bunting() -> void:
	var flags := SurfaceTool.new()
	flags.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	var strings := [[Vector3(-9.5, 6.0, -31.0), Vector3(9.5, 6.2, -31.0)], [Vector3(-9.5, 5.6, -19.0), Vector3(9.5, 6.0, -20.0)],
		[Vector3(-9.5, 6.4, -1.0), Vector3(12.3, 6.0, -1.3)], [Vector3(-9.5, 6.4, 15.0), Vector3(9.5, 6.4, 17.0)],
		[Vector3(-9.5, 6.4, 21.0), Vector3(9.5, 6.4, 20.5)], [Vector3(-9.5, 6.0, -26.0), Vector3(9.5, 5.8, -15.0)]]
	var colors := [Color(0.82, 0.23, 0.18), Color(1.0, 0.79, 0.24), Color(0.18, 0.72, 0.69), Color(0.98, 0.91, 0.78), Color(0.95, 0.54, 0.24)]
	for n in strings.size():
		var a: Vector3 = strings[n][0]
		var b: Vector3 = strings[n][1]
		var sag := 0.9
		var count := int(a.distance_to(b) / 0.6)
		var normal := Vector3(b.x - a.x, 0, b.z - a.z).normalized().cross(Vector3.UP).normalized()
		for k in count:
			var t0 := (k + 0.1) / count
			var t1 := (k + 0.9) / count
			var tm := (k + 0.5) / count
			var p0 := a.lerp(b, t0) - Vector3.UP * sag * 4.0 * t0 * (1.0 - t0)
			var p1 := a.lerp(b, t1) - Vector3.UP * sag * 4.0 * t1 * (1.0 - t1)
			var tip := a.lerp(b, tm) - Vector3.UP * (sag * 4.0 * tm * (1.0 - tm) + 0.42)
			var c: Color = colors[(n + k) % colors.size()]
			for v in [[p0, 0.0], [p1, 0.0], [tip, 1.0]]:
				flags.set_color(c)
				flags.set_normal(normal)
				flags.set_uv(Vector2(0.5, v[1]))
				flags.add_vertex(v[0])
		for k in 12:
			var ta := k / 12.0
			var tb := (k + 1) / 12.0
			var pa := a.lerp(b, ta) - Vector3.UP * sag * 4.0 * ta * (1.0 - ta)
			var pb := a.lerp(b, tb) - Vector3.UP * sag * 4.0 * tb * (1.0 - tb)
			var up := Vector3.UP * 0.025
			for v in [pa + up, pb + up, pb - up, pa + up, pb - up, pa - up]:
				lines.set_normal(normal)
				lines.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.name = "Bunting"
	mi.mesh = flags.commit()
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "sky_bunting.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(mi)
	var ropes := MeshInstance3D.new()
	ropes.name = "BuntingLines"
	ropes.mesh = lines.commit()
	var rope := _mat("rope", Color(0.9, 0.82, 0.62), 0.9)
	rope.cull_mode = BaseMaterial3D.CULL_DISABLED
	ropes.material_override = rope
	ropes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(ropes)


# ---------------------------------------------------------------------------
# The Runaway Mine Train
# ---------------------------------------------------------------------------

func _build_coaster() -> void:
	_trace_track()
	var c := Node3D.new()
	c.name = "Coaster"
	dressing.add_child(c)
	var ups := _frames(_track)
	_sweep_track(c, ups)
	_build_supports(c, ups)
	_prop(c, "gulch_tunnel_mouth", "TunnelEast", Vector3(42.6, 0.0, -36.0), -90.0, Vector3(6, 6, 1))
	_prop(c, "gulch_tunnel_mouth", "TunnelWest", Vector3(WEST_CLIFF - 0.4, TRACK_Y - 0.4, LOOP_C.z + LOOP_DRIFT), 90.0, Vector3(6, 6, 1))
	var train := Node3D.new()
	train.name = "Train"
	c.add_child(train)
	_prop(train, "gulch_coaster_loco", "Car0", Vector3.ZERO, 0.0, Vector3(1.4, 2, 2))
	for i in range(1, 4):
		_prop(train, "gulch_coaster_car", "Car%d" % i, Vector3.ZERO, 0.0, Vector3(1.4, 1.5, 2))
	var hidden := PackedByteArray()
	for h in _hidden:
		hidden.append(1 if h else 0)
	_late(train, "res://scripts/props/gulch_coaster_train.gd", {"points": _track, "ups": ups, "hidden": hidden, "lift": _lift_range,
		"top_y": TOP_Y + 0.5, "start": _loop_start + 4.0})


## The circuit as a dense polyline (0.5 m apart), starting at the east tunnel.
func _trace_track() -> void:
	var pts := PackedVector3Array()
	var hid: Array[bool] = []
	# East tunnel mouth west, round to the south: the lift's foot.
	_line(pts, hid, Vector3(46.0, 0.4, -36.0), Vector3(40.0, 0.4, -36.0), false)
	_arc(pts, hid, Vector3(40.0, 0.4, -31.0), 5.0, -PI * 0.5, -PI, 0.4, 0.4, false)
	# Lift hill south along x 35.
	var lift_start := _length(pts)
	_ease_line(pts, hid, Vector3(LIFT_X, 0.4, -31.0), Vector3(LIFT_X, TOP_Y, LOOP_C.z - 6.0), false)
	_lift_range = Vector2(lift_start, _length(pts))
	# Over the top and round to the west, then the drop along the loop's line.
	_arc(pts, hid, Vector3(LIFT_X - 6.0, TOP_Y, LOOP_C.z - 6.0), 6.0, 0.0, PI * 0.5, TOP_Y, TOP_Y + 0.5, false)
	_line(pts, hid, Vector3(LIFT_X - 6.0, TOP_Y + 0.5, LOOP_C.z), Vector3(LIFT_X - 8.0, TOP_Y + 0.5, LOOP_C.z), false)
	_drop(pts, hid, Vector3(LIFT_X - 8.0, TOP_Y + 0.5, LOOP_C.z), Vector3(6.0, TRACK_Y, LOOP_C.z))
	_line(pts, hid, Vector3(6.0, TRACK_Y, LOOP_C.z), Vector3(0.0, TRACK_Y, LOOP_C.z), false)
	_loop_start = _length(pts)
	# The loop: in at the bottom heading west, round, out 2 m further south.
	var steps := int(TAU * LOOP_R / 0.5)
	for i in range(1, steps + 1):
		var th := TAU * i / steps
		pts.append(LOOP_C + Vector3(-sin(th) * LOOP_R, -cos(th) * LOOP_R, LOOP_DRIFT * (th / TAU)))
		hid.append(false)
	# West along the loop's exit line into the west cliff tunnel.
	var out_z := LOOP_C.z + LOOP_DRIFT
	_line(pts, hid, Vector3(0.0, TRACK_Y, out_z), Vector3(WEST_CLIFF - 1.0, TRACK_Y, out_z), false)
	# Hidden: inside the west cliff north, under the north cliff east, inside the
	# east mesa south and back out of the east tunnel.
	_line(pts, hid, Vector3(WEST_CLIFF - 1.0, TRACK_Y, out_z), Vector3(-31.0, TRACK_Y, out_z), true)
	_line(pts, hid, Vector3(-31.0, TRACK_Y, out_z), Vector3(-31.0, 6.0, -52.0), true)
	_line(pts, hid, Vector3(-31.0, 6.0, -52.0), Vector3(52.0, 3.0, -52.0), true)
	_line(pts, hid, Vector3(52.0, 3.0, -52.0), Vector3(52.0, 0.4, -36.0), true)
	_line(pts, hid, Vector3(52.0, 0.4, -36.0), Vector3(46.0, 0.4, -36.0), true)
	_track = pts
	_hidden = hid


func _length(pts: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	return total


func _line(pts: PackedVector3Array, hid: Array[bool], a: Vector3, b: Vector3, hidden: bool) -> void:
	var n := maxi(1, int(a.distance_to(b) / 0.5))
	for i in range(1, n + 1):
		pts.append(a.lerp(b, float(i) / n))
		hid.append(hidden)


## A straight run whose height eases in and out (no kinks at either end).
func _ease_line(pts: PackedVector3Array, hid: Array[bool], a: Vector3, b: Vector3, hidden: bool) -> void:
	var n := maxi(1, int(a.distance_to(b) / 0.5))
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t)
		p.y = lerpf(a.y, b.y, smoothstep(0.0, 1.0, t))
		pts.append(p)
		hid.append(hidden)


## The first drop: steep in the middle, flattening out at the bottom.
func _drop(pts: PackedVector3Array, hid: Array[bool], a: Vector3, b: Vector3) -> void:
	var n := maxi(1, int(a.distance_to(b) / 0.5))
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := Vector3(lerpf(a.x, b.x, t), 0.0, lerpf(a.z, b.z, smoothstep(0.0, 0.6, t)))
		var k := t * t * (3.0 - 2.0 * t)
		p.y = lerpf(a.y, b.y, k)
		pts.append(p)
		hid.append(false)


## A horizontal arc round `centre` from angle a0 to a1 (radians, 0 = +X, PI/2 = +Z), height y0 to y1.
func _arc(pts: PackedVector3Array, hid: Array[bool], centre: Vector3, r: float, a0: float, a1: float, y0: float, y1: float, hidden: bool) -> void:
	var n := maxi(2, int(absf(a1 - a0) * r / 0.5))
	for i in range(1, n + 1):
		var t := float(i) / n
		var a := lerpf(a0, a1, t)
		pts.append(Vector3(centre.x + cos(a) * r, lerpf(y0, y1, t), centre.z + sin(a) * r))
		hid.append(hidden)


## Up vectors along the track by parallel transport (they turn through the loop).
func _frames(pts: PackedVector3Array) -> PackedVector3Array:
	var ups := PackedVector3Array()
	ups.resize(pts.size())
	var up := Vector3.UP
	for i in pts.size():
		var t := _tangent(pts, i)
		up = (up - t * up.dot(t)).normalized()
		if up.length() < 0.5:
			up = Vector3.UP
		ups[i] = up
	return ups


func _tangent(pts: PackedVector3Array, i: int) -> Vector3:
	var a := pts[maxi(0, i - 1)]
	var b := pts[mini(pts.size() - 1, i + 1)]
	return (b - a).normalized()


## Rails, the spine and the ties as swept meshes (visible stretches only).
func _sweep_track(parent: Node3D, ups: PackedVector3Array) -> void:
	var rail := _mat("coaster_rail", Color(0.82, 0.2, 0.16), 0.45)
	var spine := _mat("coaster_spine", Color(0.52, 0.17, 0.13), 0.5)
	var tie := _mat("coaster_tie", Color(0.43, 0.27, 0.17), 0.8)
	var st_rail := SurfaceTool.new()
	st_rail.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_spine := SurfaceTool.new()
	st_spine.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-0.55, 0.55]:
		_tube(st_rail, ups, Vector2(side, -0.04), 0.1, 8)
	_tube(st_spine, ups, Vector2(0.0, -0.48), 0.22, 8)
	for pair in [[st_rail, rail, "Rails"], [st_spine, spine, "Spine"]]:
		var st: SurfaceTool = pair[0]
		st.index()
		(pair[1] as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		st.set_material(pair[1])
		var mi := MeshInstance3D.new()
		mi.name = pair[2]
		mi.mesh = st.commit()
		parent.add_child(mi)
	# Ties every 0.75 m.
	var xforms: Array[Transform3D] = []
	var walked := 0.0
	for i in range(1, _track.size()):
		walked += _track[i].distance_to(_track[i - 1])
		if _hidden[i] or walked < 0.75:
			continue
		walked = 0.0
		xforms.append(_frame_at(i, ups).translated_local(Vector3(0, -0.16, 0)))
	_multi(parent, "Ties", _box_mesh(Vector3(1.5, 0.14, 0.26), tie), xforms)



func _multi(parent: Node3D, multi_name: String, mesh: Mesh, xforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = multi_name
	mmi.multimesh = mm
	parent.add_child(mmi)


## Car frame at sample i: Z along the track, Y the track's up.
func _frame_at(i: int, ups: PackedVector3Array) -> Transform3D:
	var t := _tangent(_track, i)
	var up := ups[i]
	var x := up.cross(t).normalized()
	return Transform3D(Basis(x, up, t), _track[i])


## A round tube following the visible track at (side, up) offset in its frame.
func _tube(st: SurfaceTool, ups: PackedVector3Array, offset: Vector2, r: float, segs: int) -> void:
	var prev: Array[Vector3] = []
	var prev_n: Array[Vector3] = []
	for i in _track.size():
		if _hidden[i]:
			prev.clear()
			continue
		if i % 2 == 1 and i + 1 < _track.size() and not _hidden[i + 1]:
			continue
		var f := _frame_at(i, ups)
		var centre := f.origin + f.basis.x * offset.x + f.basis.y * offset.y
		var ring: Array[Vector3] = []
		var ring_n: Array[Vector3] = []
		for k in segs:
			var a := TAU * k / segs
			var n := f.basis.x * cos(a) + f.basis.y * sin(a)
			ring.append(centre + n * r)
			ring_n.append(n)
		if not prev.is_empty():
			for k in segs:
				var k2 := (k + 1) % segs
				for q in [[prev[k], prev_n[k]], [ring[k2], ring_n[k2]], [ring[k], ring_n[k]], [prev[k], prev_n[k]], [prev[k2], prev_n[k2]],
						[ring[k2], ring_n[k2]]]:
					st.set_normal(q[1])
					st.add_vertex(q[0])
		prev = ring
		prev_n = ring_n


## Timber trestle bents from the ground up to the track every 3 m along the
## visible, upright stretches (the loop rides on its own towers and truss):
## two legs, a cap beam under the track and a ledger every 3 m of height.
func _build_supports(parent: Node3D, ups: PackedVector3Array) -> void:
	var legs: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	var ledgers: Array[Transform3D] = []
	var walked := 3.0
	for i in range(1, _track.size()):
		walked += _track[i].distance_to(_track[i - 1])
		var p := _track[i]
		if _hidden[i] or walked < 3.0 or ups[i].y < 0.9 or p.y < 1.0:
			continue
		if absf(p.x) < FACADE + 1.0 and p.z > ROW_S:
			continue
		walked = 0.0
		var t := _tangent(_track, i)
		var basis := Basis(Vector3.UP, atan2(t.x, t.z))
		var side := basis.x
		var h := p.y - 0.45
		for s: float in [-1.0, 1.0]:
			legs.append(Transform3D(basis.scaled(Vector3(1, h, 1)), Vector3(p.x, h * 0.5, p.z) + side * s * 0.75))
		caps.append(Transform3D(basis, Vector3(p.x, h, p.z)))
		var y := 2.6
		while y < h - 0.8:
			ledgers.append(Transform3D(basis, Vector3(p.x, y, p.z)))
			y += 3.0
	var wood := _mat("trestle_wood", Color(0.62, 0.39, 0.23), 0.85)
	var dark := _mat("trestle_dark", Color(0.4, 0.24, 0.15), 0.85)
	_multi(parent, "TrestleLegs", _box_mesh(Vector3(0.24, 1.0, 0.24), wood), legs)
	_multi(parent, "TrestleCaps", _box_mesh(Vector3(2.0, 0.26, 0.34), dark), caps)
	_multi(parent, "TrestleLedgers", _box_mesh(Vector3(1.8, 0.16, 0.16), dark), ledgers)
	# The loop's towers and the truss over the street.
	var steel := _mat("coaster_steel", Color(0.98, 0.76, 0.24), 0.4)
	var red := _mat("coaster_rail", Color(0.82, 0.2, 0.16), 0.45)
	for s: float in [-1.0, 1.0]:
		var base := Vector3(s * 10.2, 0, LOOP_C.z + LOOP_DRIFT * 0.5)
		_visual_box(parent, "LoopTower%d" % int(s), Vector3(1.0, TRACK_Y - 0.6, 1.0), base + Vector3(0, (TRACK_Y - 0.6) * 0.5, 0), red)
		_visual_box(parent, "LoopTowerFoot%d" % int(s), Vector3(1.8, 0.5, 1.8), base + Vector3(0, 0.25, 0), _mat("rock_dark", Color(0.56, 0.2, 0.14), 0.9))
		for k in 3:
			_visual_box(parent, "LoopTowerBand%d%d" % [int(s), k], Vector3(1.1, 0.25, 1.1), base + Vector3(0, 2.5 + k * 2.5, 0), steel)
	_visual_box(parent, "LoopTruss", Vector3(21.4, 0.5, 3.0), Vector3(0, TRACK_Y - 0.85, LOOP_C.z + LOOP_DRIFT * 0.5), steel)
	_visual_box(parent, "LoopTrussRed", Vector3(21.6, 0.2, 3.1), Vector3(0, TRACK_Y - 1.15, LOOP_C.z + LOOP_DRIFT * 0.5), red)
	for k in 9:
		_visual_box(parent, "LoopTrussRib%d" % k, Vector3(0.2, 0.7, 3.1), Vector3(-9.6 + k * 2.4, TRACK_Y - 0.85, LOOP_C.z + LOOP_DRIFT * 0.5), red)
	# Marker lamps up the lift hill.
	for i in 8:
		var z := -28.0 + i * 6.0
		var y := lerpf(0.4, TOP_Y, smoothstep(0.0, 1.0, (z + 31.0) / (LOOP_C.z - 6.0 + 31.0)))
		_prop(parent, "gulch_coaster_lamp", "LiftLamp%d" % i, Vector3(LIFT_X - 0.8, y - 0.3, z), 0.0, Vector3(0.2, 0.6, 0.2))
	_collider(geo, "LoopTowerBodyW", Vector3(1.8, TRACK_Y, 1.8), Vector3(-10.2, TRACK_Y * 0.5, LOOP_C.z + LOOP_DRIFT * 0.5))
	_collider(geo, "LoopTowerBodyE", Vector3(1.8, TRACK_Y, 1.8), Vector3(10.2, TRACK_Y * 0.5, LOOP_C.z + LOOP_DRIFT * 0.5))


# ---------------------------------------------------------------------------
# Backdrop: far mesas and buttes, a windmill, cacti
# ---------------------------------------------------------------------------

func _build_backdrop() -> void:
	var b := Node3D.new()
	b.name = "Backdrop"
	dressing.add_child(b)
	var far := [[Vector3(-90, 0, -150), 10.0, 1.2], [Vector3(40, 0, -170), -8.0, 1.5], [Vector3(150, 0, -60), 80.0, 1.3],
		[Vector3(-150, 0, 20), 95.0, 1.1], [Vector3(60, 0, 160), 170.0, 1.2], [Vector3(-80, 0, 140), 200.0, 1.0]]
	for i in far.size():
		var m := _prop(b, "gulch_mesa_far", "Mesa%d" % i, far[i][0], far[i][1], Vector3(70, 22, 30))
		m.scale = Vector3(1.0, far[i][2], 1.0)
	var buttes := [[Vector3(-62, 0, -70), 1.0], [Vector3(80, 0, -95), 1.3], [Vector3(95, 0, 40), 1.1], [Vector3(-70, 0, 75), 1.2],
		[Vector3(20, 0, 95), 0.9], [Vector3(-40, 0, -110), 1.4]]
	for i in buttes.size():
		var m := _prop(b, "gulch_butte", "Butte%d" % i, buttes[i][0], i * 47.0, Vector3(12, 28, 12))
		m.scale = Vector3(1.0, buttes[i][1], 1.0)
	_build_vultures(b)
	_prop(b, "gulch_windmill", "Windmill", Vector3(-26.0, 0, 52.0), 30.0, Vector3(3, 11, 3))
	var wheel := _prop(b, "gulch_windmill_wheel", "WindmillWheel", Vector3(-26.0, 10.3, 52.0) + Basis(Vector3.UP, deg_to_rad(30.0)) * Vector3(0, 0, 0.5),
		30.0, Vector3(3.6, 3.6, 0.3))
	_late(wheel, "res://scripts/props/sky_spinner.gd", {"axis": Vector3.BACK, "degrees_per_second": 50.0, "wind_response": 0.0})
	var cacti := [Vector3(-20, 0, 46), Vector3(14, 0, 48), Vector3(34, 0, 40), Vector3(-34, 0, 34), Vector3(40, 0, 28), Vector3(4, 0, 58),
		Vector3(-12, 0, 64), Vector3(28, 0, 62), Vector3(48, 0, 10), Vector3(-44, 0, -12)]
	for i in cacti.size():
		_prop(b, "gulch_cactus_a" if i % 2 == 0 else "gulch_cactus_b", "FarCactus%d" % i, cacti[i], i * 63.0, Vector3(1, 3, 1))
	for i in 6:
		var p := Vector3(-30.0 + i * 13.0, 0, 44.0 + (i % 3) * 5.0)
		_prop(b, "gulch_boulder", "FarRock%d" % i, p, i * 37.0, Vector3(2, 1.4, 2))


## Vultures gliding in slow circles high over the mesa (each on a turning pivot).
func _build_vultures(parent: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A gliding bird along +Z: two raked wings, a body and a fanned tail.
	var tris := [[Vector3(0, 0, 0.5), Vector3(-1.4, 0.25, -0.15), Vector3(0, 0, -0.2)], [Vector3(0, 0, 0.5), Vector3(0, 0, -0.2), Vector3(1.4, 0.25, -0.15)],
		[Vector3(-0.12, 0, 0.7), Vector3(0.12, 0, 0.7), Vector3(0, 0, -0.6)], [Vector3(0, 0, -0.45), Vector3(-0.3, 0, -0.9), Vector3(0.3, 0, -0.9)]]
	for tri in tris:
		for v: Vector3 in tri:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var body := _mat("vulture", Color(0.2, 0.15, 0.14), 0.9)
	body.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(body)
	var mesh := st.commit()
	for i in 3:
		var pivot := Node3D.new()
		pivot.name = "VulturePivot%d" % i
		parent.add_child(pivot)
		pivot.position = Vector3(-10.0 + i * 14.0, 34.0 + i * 3.0, -62.0 + i * 6.0)
		var bird := MeshInstance3D.new()
		bird.name = "Vulture"
		bird.mesh = mesh
		bird.position = Vector3(9.0 + i * 3.0, 0, 0)
		bird.rotation = Vector3(0, PI, deg_to_rad(18.0))
		bird.scale = Vector3.ONE * 1.4
		bird.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(bird)
		_late(pivot, "res://scripts/props/ambient_motion.gd", {"spin_degrees_per_second": 11.0 + i * 3.0, "bob_height": 1.2, "bob_seconds": 7.0})


# ---------------------------------------------------------------------------
# Lights: the saloon and the barn inside
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	var l := Node3D.new()
	l.name = "Lights"
	level.add_child(l)
	_omni(l, "SaloonLightA", Vector3(-FACADE - 4.5, 2.7, SALOON_Z + 2.5), Color(1.0, 0.78, 0.5), 1.6, 8.0)
	_omni(l, "SaloonLightB", Vector3(-FACADE - 4.5, 2.7, SALOON_Z - 3.0), Color(1.0, 0.78, 0.5), 1.6, 8.0)
	_omni(l, "LiveryLight", Vector3(FACADE + 5.0, 3.6, -20.0), Color(1.0, 0.82, 0.55), 1.3, 9.0)


func _omni(parent: Node3D, light_name: String, pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.name = light_name
	o.position = pos
	o.light_color = color
	o.light_energy = energy
	o.omni_range = light_range
	o.shadow_enabled = false
	parent.add_child(o)
	_light_count += 1
	return o


# ---------------------------------------------------------------------------
# Exit: the portal in the south plaza and the lantern trail to it
# ---------------------------------------------------------------------------

func _build_exit() -> void:
	var portal: Node3D = (load("res://scenes/props/gulch_portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	geo.add_child(portal)
	portal.position = PORTAL
	portal.rotation.y = PI
	_player_block(geo, "PortalCap", Vector3(5.6, 2.0, 1.8), PORTAL + Vector3(0, 5.3, 0))
	var lights := Node3D.new()
	lights.name = "ExitLights"
	level.add_child(lights)
	var a := STATION + Vector3(0.0, 0, 5.0)
	var b := PORTAL + Vector3(0, 0, -3.0)
	var steps := 6
	for k in steps:
		var t := float(k) / (steps - 1)
		for s: float in [-1.0, 1.0]:
			var pos := a.lerp(b, t) + Vector3(s * 2.6, 0, 0)
			var lantern := _prop(lights, "gulch_exit_lantern", "ExitLantern%02d%s" % [k, "L" if s < 0 else "R"], pos, 90.0 - s * 90.0,
				Vector3(0.2, 2.0, 0.2))
			_late(lantern, "res://scripts/props/gulch_exit_lantern.gd", {"order": k})


# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(0.0, 0.1, 18.0)
	start.add_to_group("player_spawn", true)
	level.add_child(start)

	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	var points := {
		"SpawnMine": [Vector3(-2.0, 0.1, MINE_Z + 3.4), 0.0],
		"SpawnCanyonTrail": [Vector3(29.0, 0.1, -43.0), 30.0],
		"SpawnBackLane": [Vector3(-23.0, 0.1, -10.5), -90.0],
		"SpawnCorralGate": [Vector3(27.5, 0.1, -9.5), 90.0],
		"SpawnStageRoad": [Vector3(21.5, 0.1, 33.5), 90.0],
	}
	for point_name in points:
		var m := Marker3D.new()
		m.name = point_name
		m.position = points[point_name][0]
		m.rotation.y = deg_to_rad(points[point_name][1])
		m.add_to_group("enemy_spawn", true)
		spawns.add_child(m)


# ---------------------------------------------------------------------------
# Navigation
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
	mesh.filter_baking_aabb = AABB(Vector3(-27.0, -1.0, -47.0), Vector3(59.0, 6.0, 86.0))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	region.navigation_mesh = _largest_island(mesh)
	print("build_boomtown: navmesh polygons = %d (dropped %d on islands)" % [region.navigation_mesh.get_polygon_count(),
		before - region.navigation_mesh.get_polygon_count()])


## Keeps only the largest connected set of polygons (drops the tops of props
## and anything else nothing can reach).
func _largest_island(mesh: NavigationMesh) -> NavigationMesh:
	var count := mesh.get_polygon_count()
	var parent := PackedInt32Array()
	parent.resize(count)
	for i in count:
		parent[i] = i
	var owner_of := {}
	for i in count:
		for v in mesh.get_polygon(i):
			if owner_of.has(v):
				parent[_find(parent, i)] = _find(parent, owner_of[v])
			else:
				owner_of[v] = i
	var sizes := {}
	for i in count:
		var r := _find(parent, i)
		sizes[r] = int(sizes.get(r, 0)) + 1
	var best := -1
	for r in sizes:
		if best < 0 or sizes[r] > sizes[best]:
			best = r
	var out: NavigationMesh = mesh.duplicate()
	out.clear_polygons()
	var verts := mesh.get_vertices()
	var remap := {}
	var kept := PackedVector3Array()
	for i in count:
		if _find(parent, i) != best:
			continue
		var mapped := PackedInt32Array()
		for v in mesh.get_polygon(i):
			if not remap.has(v):
				remap[v] = kept.size()
				kept.append(verts[v])
			mapped.append(remap[v])
		out.add_polygon(mapped)
	out.vertices = kept
	return out


func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _late(node: Node, script_path: String, props: Dictionary) -> void:
	_late_scripts.append([node, script_path, props])


func _mat(key: String, color: Color, roughness := 0.7, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = color
	m.roughness = roughness
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	_materials[key] = m
	return m


## World-projected texture (triplanar) with its normal map when present.
func _textured(key: String, texture: String, scale: float, roughness: float) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_texture = load(TEXTURES + texture + ".png")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var normal_path := TEXTURES + texture + "_normal.png"
	if ResourceLoader.exists(normal_path):
		m.normal_enabled = true
		m.normal_texture = load(normal_path)
		m.normal_scale = 0.8
	m.roughness = roughness
	_materials[key] = m
	return m


func _box_mesh(size: Vector3, material: Material) -> BoxMesh:
	var key := "%s|%s" % [size, material.get_instance_id()]
	if _boxes.has(key):
		return _boxes[key]
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	_boxes[key] = mesh
	return mesh


func _box(parent: Node3D, box_name: String, size: Vector3, pos: Vector3, material: Material) -> StaticBody3D:
	var body := _collider(parent, box_name, size, pos)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(size, material)
	body.add_child(mi)
	return body


func _visual_box(parent: Node3D, box_name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = box_name
	mi.mesh = _box_mesh(size, material)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _model_mesh(model: String) -> Mesh:
	if _mesh_cache.has(model):
		return _mesh_cache[model]
	var source: Node3D = (load(MODELS + model + ".glb") as PackedScene).instantiate()
	var mesh: Mesh = (source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	source.free()
	_mesh_cache[model] = mesh
	return mesh


## A stair run from `top` down to `bottom` (along X or Z), `width` wide: a
## sloped collider under visual steps, and side wedges with rails.
func _stairs(parent: Node3D, stair_name: String, top: Vector3, bottom: Vector3, width: float) -> void:
	var run := Vector3(bottom.x - top.x, 0, bottom.z - top.z)
	var length := run.length()
	var rise := top.y - bottom.y
	var dir := run / length
	var yaw := atan2(-dir.z, dir.x)
	var body := StaticBody3D.new()
	body.name = stair_name
	parent.add_child(body)
	body.position = (top + bottom) * 0.5
	body.rotation.y = yaw
	var angle := atan2(rise, length)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(sqrt(length * length + rise * rise) + 0.3, 0.4, width)
	shape.shape = box
	shape.rotation.z = -angle
	shape.position = Vector3(0, -0.2 / cos(angle) + 0.06, 0)
	body.add_child(shape)
	var steps := int(round(rise / 0.267))
	var tread := _mat("stair_tread", Color(0.72, 0.5, 0.33), 0.8)
	var tread_b := _mat("stair_tread_b", Color(0.62, 0.42, 0.27), 0.8)
	var riser := _mat("stair_riser", Color(0.43, 0.27, 0.17), 0.8)
	for k in steps:
		var h := rise - (k + 1) * rise / steps
		var mi := MeshInstance3D.new()
		mi.name = "Step%d" % k
		mi.mesh = _box_mesh(Vector3(length / steps + 0.02, rise / steps, width), tread if k % 2 == 0 else tread_b)
		mi.position = Vector3(-length * 0.5 + length / steps * (k + 0.5), h + rise / steps * 0.5 - rise * 0.5, 0)
		body.add_child(mi)
		if h > 0.01:
			var fill := MeshInstance3D.new()
			fill.name = "Riser%d" % k
			fill.mesh = _box_mesh(Vector3(length / steps + 0.02, h, width - 0.02), riser)
			fill.position = Vector3(-length * 0.5 + length / steps * (k + 0.5), h * 0.5 - rise * 0.5, 0)
			body.add_child(fill)
	var rail_m := _mat("trim", Color(0.98, 0.91, 0.78), 0.6)
	for s: float in [-1.0, 1.0]:
		var side := StaticBody3D.new()
		side.name = "%sSide%d" % [stair_name, int(s)]
		parent.add_child(side)
		side.position = (top + bottom) * 0.5 + Vector3(-dir.z, 0, dir.x) * s * (width * 0.5 + 0.1)
		side.rotation.y = yaw
		var wedge := CollisionShape3D.new()
		wedge.name = "CollisionShape3D"
		var convex := ConvexPolygonShape3D.new()
		var pts := PackedVector3Array()
		for zz: float in [-0.1, 0.1]:
			pts.append(Vector3(-length * 0.5, top.y - (top.y + bottom.y) * 0.5 + 1.1, zz))
			pts.append(Vector3(-length * 0.5, -rise * 0.5, zz))
			pts.append(Vector3(length * 0.5, -rise * 0.5, zz))
			pts.append(Vector3(length * 0.5, -rise * 0.5 + 1.1, zz))
		convex.points = pts
		wedge.shape = convex
		side.add_child(wedge)
		var slope := sqrt(length * length + rise * rise)
		var rail := MeshInstance3D.new()
		rail.name = "Rail"
		rail.mesh = _box_mesh(Vector3(slope, 0.1, 0.1), rail_m)
		rail.rotation.z = -angle
		rail.position = Vector3(0, 1.05, 0)
		side.add_child(rail)
		for k in 4:
			var t := (k + 0.5) / 4.0
			var post := MeshInstance3D.new()
			post.name = "Baluster%d" % k
			post.mesh = _box_mesh(Vector3(0.1, 1.05, 0.1), rail_m)
			post.position = Vector3(-length * 0.5 + length * t, rise * 0.5 - rise * t + 0.52, 0)
			side.add_child(post)


## A collision wedge along a to b (a line on the ground): `rise` high at the
## line, falling to 0 `run` metres out on the `out` side (+1 = +X).
func _ramp(parent: Node3D, ramp_name: String, a: Vector3, b: Vector3, out: float, rise: float, run: float) -> void:
	var body := StaticBody3D.new()
	body.name = ramp_name
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var convex := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for p: Vector3 in [a, b]:
		pts.append(p)
		pts.append(p + Vector3(0, rise, 0))
		pts.append(p + Vector3(out * run, 0, 0))
	convex.points = pts
	shape.shape = convex
	body.add_child(shape)


func _player_walls() -> Node3D:
	var walls := level.get_node_or_null("PlayerWalls") as Node3D
	if walls == null:
		walls = Node3D.new()
		walls.name = "PlayerWalls"
		level.add_child(walls)
	return walls


func _player_wall(parent: Node3D, wall_name: String, a: Vector3, b: Vector3, height: float) -> void:
	var length := a.distance_to(b)
	if length < 0.2:
		return
	var wall := StaticBody3D.new()
	wall.name = wall_name
	wall.collision_layer = 16
	wall.collision_mask = 0
	parent.add_child(wall)
	wall.position = (a + b) * 0.5 + Vector3(0, height * 0.5 - 1.0, 0)
	var dir := (b - a).normalized()
	wall.rotation.y = atan2(-dir.z, dir.x)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(length, height, 0.4)
	shape.shape = box
	wall.add_child(shape)


## A run of fence modules with one collision box (blocks walking).
func _fence_run(parent: Node3D, run_name: String, a: Vector3, b: Vector3, model := "gulch_fence", module_len := 2.5, height := 1.25) -> void:
	var length := a.distance_to(b)
	if length < 0.5:
		return
	var body := StaticBody3D.new()
	body.name = run_name
	parent.add_child(body)
	body.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	body.rotation.y = atan2(-dir.z, dir.x)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(length, height, 0.4)
	shape.shape = box
	shape.position.y = height * 0.5
	body.add_child(shape)
	body.add_child(_module_row("Modules", model, length, module_len))


## Modules of a model laid end to end along local X (one MultiMesh).
func _module_row(row_name: String, model: String, length: float, module_len: float) -> MultiMeshInstance3D:
	var count := maxi(1, int(round(length / module_len)))
	var step := length / count
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _model_mesh(model)
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(step / module_len, 1, 1)), Vector3(-length * 0.5 + step * (i + 0.5), 0, 0)))
	var modules := MultiMeshInstance3D.new()
	modules.name = row_name
	modules.multimesh = mm
	return modules


## A player-only block on top of a post or pole (nobody perches up there).
func _cap(parent: Node3D, cap_name: String, top: Vector3) -> void:
	_player_block(parent, cap_name, Vector3(0.9, 6.0, 0.9), top + Vector3(0, 3.0, 0))


## Invisible player-only collider (physics layer 5).
func _player_block(parent: Node3D, block_name: String, size: Vector3, pos: Vector3, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = block_name
	body.collision_layer = 16
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = yaw
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


## Invisible upright cylinder collider for posts, poles and round props.
func _post(parent: Node3D, post_name: String, radius: float, height: float, base: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = post_name
	body.position = base + Vector3(0, height * 0.5, 0)
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)
	return body


func _collider(parent: Node3D, collider_name: String, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = collider_name
	body.position = pos
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


## A prop with a matching box collider (footprint `size`, standing on `pos`).
func _solid_prop(parent: Node3D, model: String, prop_name: String, pos: Vector3, yaw_degrees: float, size: Vector3) -> Node3D:
	var node := _prop(parent, model, prop_name, pos, yaw_degrees, size)
	var c := _collider(parent, prop_name + "Collision", size, pos + Vector3(0, size.y * 0.5, 0))
	c.rotation.y = deg_to_rad(yaw_degrees)
	if size.y >= 2.4:
		_player_block(parent, prop_name + "Cap", Vector3(size.x + 0.4, 6.0, size.z + 0.4), pos + Vector3(0, size.y + 3.0, 0), deg_to_rad(yaw_degrees))
	return node


## Instances art/models/<model>.glb, or a grey stand-in box if it is missing.
func _prop(parent: Node3D, model: String, prop_name: String, pos: Vector3, yaw_degrees: float, placeholder_size: Vector3) -> Node3D:
	var path := MODELS + model + ".glb"
	var node: Node3D
	if ResourceLoader.exists(path):
		node = (load(path) as PackedScene).instantiate()
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(placeholder_size, _mat("placeholder", Color(0.75, 0.72, 0.8), 0.8))
		var holder := Node3D.new()
		mi.name = "Placeholder"
		mi.position.y = placeholder_size.y * 0.5
		holder.add_child(mi)
		node = holder
	node.name = prop_name
	parent.add_child(node)
	node.position = pos
	node.rotation.y = deg_to_rad(yaw_degrees)
	return node


func _own(node: Node) -> void:
	for child in node.get_children():
		child.owner = level
		if child.scene_file_path == "":
			_own(child)
