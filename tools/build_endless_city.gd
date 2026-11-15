extends SceneTree
## Generator for the Endless map "Ashfall City" (data/endless/endless_city.tres).
##
## Rebuilds scenes/levels/endless_city.tscn to the scene contract in
## docs/ENDLESS.md: five districts joined by EndlessGate nodes, every
## district's entrances, areas and feature markers, the burning city around
## them, the dusk sky and a navigation mesh baked with every gate shut.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_endless_city.gd
##
## Run it with a renderer (not --headless): the headless renderer keeps no
## MultiMesh instance data, so rubble and the skyline would save empty.
## Models of the Ashfall City kit (art/models/city_*.glb, scenes/props/city_*)
## are used when present; anything missing is stood in for by simple shapes.
##
## NOTE: running this overwrites hand edits made to endless_city.tscn.
##
## Layout (metres, top view; -Z = north):
##   Ashfall Square (start)  x -22..22, z -22..22, the station south of the
##                           toppled statue, a ring road of burning cars;
##                           four alleys (NW, NE, SW, SE) bring the zombies.
##   Precinct 9 (west)       x -74..-34, z -24..24, through the barricaded
##                           street at x -34..-22; the station front at x -74.
##   Neon Market (east)      x 34..90, z -8..8, through the shuttered arcade at
##                           x 22..34; two lanes either side of the stalls.
##   Metro Line (north, y -6) the subway stairs in the square (x -3..3, z -16)
##                           down to the platform hall x -18..40, z -42..-28.
##   Broadcast Tower (NE)    x 46..94, z -72..-22: the plaza at the foot of the
##                           broken skyscraper; gates from the Market's north
##                           alley (z -15) and the Metro's east stairs (x 40).

const OUT_PATH := "res://scenes/levels/endless_city.tscn"
const MODELS := "res://art/models/"
const TEXTURES := "res://art/textures/"
const SHADERS := "res://art/shaders/"
const PROPS := "res://scenes/props/"

const SQ := 22.0                       # Ashfall Square half size
const STATION := Vector3(0.0, 0.0, 8.5)
const STATUE := Vector3(0.0, 0.0, -6.0)
const METRO_Y := -6.0
const HALL := Rect2(-18.0, -42.0, 58.0, 14.0)   # x, z, width, depth
const PLATFORM_EDGE_Z := -38.0
const HALL_CEILING := -0.6
const STAIR_HALF := 3.0
const STAIR_TOP_Z := -16.0
const STAIR_FOOT_Z := -27.0
const EXIT_Z := Vector2(-35.0, -29.0)  # the tower stairs' z span
const EXIT_FOOT_X := 42.0
const EXIT_TOP_X := 54.0
const PRECINCT := Rect2(-74.0, -24.0, 40.0, 48.0)
const MARKET := Rect2(34.0, -8.0, 56.0, 16.0)
const TOWER := Rect2(46.0, -72.0, 48.0, 50.0)
const TOWER_ALLEY := Rect2(62.0, -22.0, 8.0, 14.0)
const SUN_DIRECTION := Vector3(0.75, 0.16, 0.62)     # toward the setting sun (low, SE)
const WALL_H := 14.0

## Every district's gates: district, position, yaw (degrees; local X spans the
## opening), opening width, style, kit model prefix, the floor heights on the
## gate's -Z and +Z sides (for the nav links).
const GATES := [
	[&"precinct", Vector3(-28.0, 0.0, 0.0), 90.0, 8.0, &"topple", "city_gate_barricade", 0.0, 0.0],
	[&"metro", Vector3(0.0, 0.0, STAIR_TOP_Z), 0.0, 6.0, &"shutter", "city_gate_shutter", -1.1, 0.0],
	[&"market", Vector3(28.0, 0.0, 0.0), 90.0, 8.0, &"shutter", "city_gate_shutter", 0.0, 0.0],
	[&"tower", Vector3(66.0, 0.0, -15.0), 0.0, 8.0, &"slide", "city_gate_fence", 0.0, 0.0],
	[&"tower", Vector3(HALL.end.x + 0.5, METRO_Y, -32.0), 90.0, 6.0, &"shutter", "city_gate_shutter", METRO_Y, METRO_Y + 0.4],
]

var level: Node3D
var geo: Node3D          # collidable geometry (navmesh source)
var dressing: Node3D     # non-colliding scenery
var fx: Node3D           # fires, smoke, lights
var _materials := {}
var _boxes := {}
var _late_scripts: Array = []
var _light_count := 0
var _mesh_cache := {}
var _aabb_cache := {}
var _rng := RandomNumberGenerator.new()
var _spawn_points: Array[Vector3] = []


func _initialize() -> void:
	_rng.seed = 909
	level = Node3D.new()
	level.name = "EndlessCity"
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
	fx = Node3D.new()
	fx.name = "Effects"
	level.add_child(fx)

	_build_ground()
	_build_square()
	_build_precinct()
	_build_market()
	_build_metro()
	_build_tower()
	_build_blocks()
	_build_gates()
	_build_entrances()
	_build_boundary()
	_build_skyline()
	_build_ashfall()
	_build_markers()
	_build_areas()
	_build_features()

	get_root().add_child(level)
	await process_frame
	_bake_navigation(nav)
	get_root().remove_child(level)

	for entry in _late_scripts:
		var node: Node = entry[0]
		node.set_script(load(entry[1]))
		for key in entry[2]:
			node.set(key, entry[2][key])
	level.set_script(load("res://scripts/run/endless_city_environment.gd"))
	var director := Node.new()
	director.name = "RunDirector"
	director.set_script(load("res://scripts/run/run_director.gd"))
	level.add_child(director)

	_own(level)
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_PATH)
	print("build_endless_city: saved %s (error %d), %d omni lights" % [OUT_PATH, err, _light_count])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: ember dusk sky, a low orange sun, the city's fire glow
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SHADERS + "city_sky.gdshader")
	sky_mat.set_shader_parameter("sun_direction", SUN_DIRECTION)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.4, 0.5)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.6
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.46, 0.25, 0.2)
	env.fog_density = 0.0055
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.looking_at(-SUN_DIRECTION.normalized(), Vector3.UP), Vector3(0, 30, 0))
	sun.light_color = Color(1.0, 0.62, 0.38)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_opacity = 0.72
	level.add_child(sun)

	# Cold fill from the dark side of the sky, so faces away from the sun stay readable.
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.transform = Transform3D(Basis.looking_at(Vector3(0.5, -0.6, 0.6).normalized(), Vector3.UP), Vector3(0, 30, 0))
	fill.light_color = Color(0.5, 0.55, 0.95)
	fill.light_energy = 0.32
	fill.shadow_enabled = false
	level.add_child(fill)


# ---------------------------------------------------------------------------
# Ground: every district's floor (collision) and its paving, road and kerbs
# ---------------------------------------------------------------------------

func _build_ground() -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	geo.add_child(ground)
	var paving := _surface("paving", ["city_sidewalk", "dune_concrete"], Color(0.95, 0.9, 0.9), 0.25, 0.85)
	var asphalt := _surface("asphalt", ["city_asphalt", "neon_roof"], Color(1.0, 1.0, 1.0), 0.12, 0.8)
	# Square: a slab round the subway stairs' opening (x -3..3, z -22..-16).
	_slab(ground, "SquareSlab", Rect2(-SQ, STAIR_TOP_Z, SQ * 2.0, SQ - STAIR_TOP_Z), asphalt)
	_slab(ground, "SquareSlabNW", Rect2(-SQ, -SQ, SQ - STAIR_HALF, SQ + STAIR_TOP_Z), asphalt)
	_slab(ground, "SquareSlabNE", Rect2(STAIR_HALF, -SQ, SQ - STAIR_HALF, SQ + STAIR_TOP_Z), asphalt)
	_slab(ground, "PassageW", Rect2(-34.0, -4.0, 12.0, 8.0), asphalt)
	_slab(ground, "PassageE", Rect2(SQ, -4.0, 12.0, 8.0), paving)
	_slab(ground, "PrecinctSlab", PRECINCT, asphalt)
	_slab(ground, "MarketSlab", MARKET, paving)
	_slab(ground, "SouthStreet", Rect2(-5.0, SQ, 10.0, 22.0), asphalt)
	_slab(ground, "TowerAlleySlab", TOWER_ALLEY, asphalt)
	# Tower plaza round the stairwell up from the metro (x 46..54, z -35..-29).
	_slab(ground, "TowerSlabN", Rect2(TOWER.position.x, TOWER.position.y, TOWER.size.x, EXIT_Z.x - TOWER.position.y), paving)
	_slab(ground, "TowerSlabS", Rect2(TOWER.position.x, EXIT_Z.y, TOWER.size.x, TOWER.end.y - EXIT_Z.y), paving)
	_slab(ground, "TowerSlabMid", Rect2(EXIT_TOP_X, EXIT_Z.x, TOWER.end.x - EXIT_TOP_X, EXIT_Z.y - EXIT_Z.x), paving)
	# The plaza paving of the square inside the ring road.
	var plaza := _surface("plaza", ["city_sidewalk", "frost_stone"], Color(0.85, 0.72, 0.66), 0.4, 0.85)
	_visual_box(dressing, "SquarePaving", Vector3(26.0, 0.06, 26.0), Vector3(0, 0.03, -1.0), plaza)
	_kerb_ring(dressing, "SquareKerb", Rect2(-13.0, -14.0, 26.0, 26.0))
	_kerb_ring(dressing, "SidewalkKerb", Rect2(-SQ + 2.5, -SQ + 2.5, SQ * 2.0 - 5.0, SQ * 2.0 - 5.0))
	_road_lines(dressing)


## A floor slab 1 m thick whose top is y 0, over `rect` (x, z, width, depth).
func _slab(parent: Node3D, slab_name: String, rect: Rect2, material: Material, top := 0.0) -> StaticBody3D:
	var size := Vector3(rect.size.x, 1.0, rect.size.y)
	var pos := Vector3(rect.position.x + rect.size.x * 0.5, top - 0.5, rect.position.y + rect.size.y * 0.5)
	return _box(parent, slab_name, size, pos, material)


## A low kerb round a rectangle (visual: 12 cm, below the zombies' step).
func _kerb_ring(parent: Node3D, ring_name: String, r: Rect2) -> void:
	var stone := _mat("kerb", Color(0.5, 0.47, 0.46), 0.85)
	var w := 0.3
	var h := 0.12
	_visual_box(parent, ring_name + "N", Vector3(r.size.x, h, w), Vector3(r.get_center().x, h * 0.5, r.position.y), stone)
	_visual_box(parent, ring_name + "S", Vector3(r.size.x, h, w), Vector3(r.get_center().x, h * 0.5, r.end.y), stone)
	_visual_box(parent, ring_name + "W", Vector3(w, h, r.size.y), Vector3(r.position.x, h * 0.5, r.get_center().y), stone)
	_visual_box(parent, ring_name + "E", Vector3(w, h, r.size.y), Vector3(r.end.x, h * 0.5, r.get_center().y), stone)


## Faded lane paint on the square's ring road and the side streets (one MultiMesh).
func _road_lines(parent: Node3D) -> void:
	var xforms: Array[Transform3D] = []
	for k in 6:
		var t := -15.0 + k * 6.0
		for side in [-1.0, 1.0]:
			xforms.append(Transform3D(Basis(), Vector3(t, 0.02, side * 16.5)))
			xforms.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(side * 16.5, 0.02, t)))
	for k in 5:
		xforms.append(Transform3D(Basis(), Vector3(-66.0 + k * 7.0, 0.02, -10.0)))
		xforms.append(Transform3D(Basis(), Vector3(-66.0 + k * 7.0, 0.02, 10.0)))
	var paint := _mat("lane_paint", Color(0.85, 0.74, 0.42), 0.8)
	var mesh := _box_mesh(Vector3(2.6, 0.02, 0.22), paint)
	parent.add_child(_multimesh("RoadLines", mesh, xforms))


# ---------------------------------------------------------------------------
# Ashfall Square: the station, the toppled statue, the ring of burning cars
# ---------------------------------------------------------------------------

func _build_square() -> void:
	var sq := Node3D.new()
	sq.name = "Square"
	geo.add_child(sq)
	var station_scene := PROPS + "city_station.tscn"
	if not ResourceLoader.exists(station_scene):
		station_scene = PROPS + "kiosk.tscn"
	var station: Node3D = (load(station_scene) as PackedScene).instantiate()
	station.name = "Station"
	sq.add_child(station)
	station.position = STATION
	# The statue: plinth and the fallen founder across the plaza.
	var statue := _solid_kit(sq, "city_statue_toppled", "Statue", STATUE, 20.0, Vector3(9.0, 2.6, 4.0))
	var statue_box := (statue.get_child(0) as CollisionShape3D).shape as BoxShape3D
	_player_block(sq, "StatueCap", Vector3(statue_box.size.x, 3.0, statue_box.size.z), statue.position + Vector3(0, statue_box.size.y * 0.5 + 1.5, 0), deg_to_rad(20.0))
	# The ring of wrecks on the road (cover, loops round the plaza), half of them burning.
	var wrecks := [
		["city_car_burnt", Vector3(-16.5, 0, -10.0), 12.0, true], ["city_taxi_wreck", Vector3(-16.8, 0, 7.0), 168.0, false],
		["city_car_burnt_b", Vector3(-9.0, 0, 16.6), 78.0, true], ["city_police_van", Vector3(8.5, 0, 16.4), 96.0, false],
		["city_car_burnt", Vector3(16.6, 0, 9.0), 188.0, true], ["city_car_burnt_b", Vector3(16.4, 0, -9.5), -10.0, false],
		["city_taxi_wreck", Vector3(9.0, 0, -16.8), 104.0, true], ["city_car_burnt", Vector3(-8.5, 0, -16.4), 262.0, false],
	]
	var i := 0
	for w in wrecks:
		_wreck(sq, w[0], "Wreck%d" % i, w[1], w[2], w[3])
		i += 1
	# Chest-high cover in the plaza and on the pavements.
	_solid_kit(sq, "city_barrier_jersey", "JerseyA", Vector3(-7.5, 0, 0.5), 75.0, Vector3(3.0, 1.0, 0.7))
	_solid_kit(sq, "city_barrier_jersey", "JerseyB", Vector3(7.5, 0, -1.0), 100.0, Vector3(3.0, 1.0, 0.7))
	_solid_kit(sq, "city_rubble_a", "RubbleNW", Vector3(-19.0, 0, -18.5), 30.0, Vector3(3.2, 1.2, 2.6))
	_solid_kit(sq, "city_rubble_b", "RubbleSE", Vector3(19.5, 0, 18.0), 200.0, Vector3(3.0, 1.1, 2.4))
	_solid_kit(sq, "city_dumpster", "DumpsterSW", Vector3(-12.0, 0, 20.4), 0.0, Vector3(2.0, 1.4, 1.2))
	_solid_kit(sq, "city_newsstand", "Newsstand", Vector3(-19.6, 0, 13.0), 90.0, Vector3(2.4, 2.6, 1.6))
	_solid_kit(sq, "city_bus_stop", "BusStop", Vector3(19.8, 0, -14.0), -90.0, Vector3(3.6, 2.6, 1.4))
	_solid_kit(sq, "city_hydrant", "Hydrant", Vector3(12.0, 0, -20.2), 0.0, Vector3(0.5, 0.9, 0.5))
	_solid_kit(sq, "city_debris", "DebrisA", Vector3(5.5, 0, -10.5), 40.0, Vector3(2.0, 0.5, 1.6))
	_solid_kit(sq, "city_debris", "DebrisB", Vector3(-6.0, 0, 13.5), 160.0, Vector3(2.0, 0.5, 1.6))
	# Streetlights on the corners (two still lit) and the dead traffic lights.
	var lamps := [[Vector3(-12.6, 0, -13.6), true], [Vector3(12.6, 0, -13.6), false], [Vector3(-12.6, 0, 11.6), false],
		[Vector3(12.6, 0, 11.6), true]]
	i = 0
	for l in lamps:
		_streetlight(sq, "Lamp%d" % i, l[0], i * 90.0 + 45.0, l[1])
		i += 1
	_pole_kit(sq, "city_traffic_light", "TrafficNW", Vector3(-20.0, 0, -20.0), 45.0)
	_pole_kit(sq, "city_traffic_light", "TrafficSE", Vector3(20.0, 0, 20.0), 225.0)
	# The south street: a burnt-out bus across it, the city beyond.
	_wreck(sq, "city_bus_wreck", "SouthBus", Vector3(0.0, 0, 26.5), 84.0, true)
	_fire_at(fx, "SquareBarrelFire", Vector3(-4.5, 0, 20.6), 0.8, true)
	_smoke(fx, "SmokeSquare", Vector3(-30.0, 10.0, 40.0), 1.2)
	_omni(fx, "StationGlow", STATION + Vector3(0, 4.0, 0), Color(1.0, 0.62, 0.32), 1.2, 10.0)


## A vehicle wreck with a collider from its model (or its stand-in), maybe burning.
## A vehicle wreck with a collider from its model (or its stand-in), maybe
## burning: at the model's "Fire" empties (the first one lit), or on its roof.
## Returns the wreck's node.
func _wreck(parent: Node3D, model: String, wreck_name: String, pos: Vector3, yaw: float, burning: bool) -> Node3D:
	var sizes := {"city_bus_wreck": Vector3(11.0, 3.2, 2.8), "city_police_van": Vector3(5.6, 2.6, 2.3),
		"city_truck_jackknifed": Vector3(11.0, 3.6, 5.0), "city_taxi_wreck": Vector3(4.4, 1.5, 2.0)}
	var size: Vector3 = sizes.get(model, Vector3(4.3, 1.45, 2.0))
	var body := _solid_kit(parent, model, wreck_name, pos, yaw, size)
	var node := parent.get_node(wreck_name) as Node3D
	var top: float = body.get_meta("top", size.y)
	var cap := (body.get_child(0) as CollisionShape3D).shape as BoxShape3D
	_player_block(parent, wreck_name + "Cap", Vector3(cap.size.x, 3.0, cap.size.z), body.position + Vector3(0, cap.size.y * 0.5 + 1.5, 0), deg_to_rad(yaw))
	if burning:
		var spots := _empties(node, "Fire")
		if spots.is_empty():
			spots.append(pos + Vector3(0, top * 0.75, 0))
		# A main blaze and a smaller tongue beside it per spot, so a wreck
		# burns like a fire and not a marker.
		var side := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0.6, 0, 0.35)
		for k in spots.size():
			var big := (1.6 if k == 0 else 1.15) + size.x * 0.04
			_fire_at(fx, "%sFire%d" % [wreck_name, k], spots[k], big, k == 0)
			_fire_at(fx, "%sFire%dSmall" % [wreck_name, k], spots[k] + side * (1.0 if k % 2 == 0 else -1.0) - Vector3(0, 0.15, 0), big * 0.55, false)
	return node


func _empty_or(node: Node3D, empty_name: String, fallback: Vector3) -> Vector3:
	var spots := _empties(node, empty_name)
	return spots[0] if not spots.is_empty() else fallback


## World positions of a kit model's empties whose names start with `prefix`.
func _empties(node: Node3D, prefix: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for child in node.get_children():
		if child is Node3D and not child is MeshInstance3D and String(child.name).begins_with(prefix):
			out.append(node.transform * (child as Node3D).position)
	return out


func _streetlight(parent: Node3D, lamp_name: String, pos: Vector3, yaw: float, lit: bool) -> void:
	_pole_kit(parent, "city_streetlight", lamp_name, pos, yaw)
	if lit:
		var lamp := parent.get_node(lamp_name) as Node3D
		var head := _empty_or(lamp, "Light", pos + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0.0, 6.2, 1.4))
		var l := _omni(fx, lamp_name + "Light", head + Vector3(0, -0.4, 0), Color(1.0, 0.78, 0.52), 1.5, 11.0)
		_late(l, "res://scripts/props/frost_flicker.gd", {})


## A pole-like prop: a thin collider and a cap so nobody stands on it.
func _pole_kit(parent: Node3D, model: String, pole_name: String, pos: Vector3, yaw: float) -> void:
	_kit(parent, model, pole_name, pos, yaw, Vector3(0.25, 6.5, 0.25))
	_post(parent, pole_name + "Post", 0.18, 3.0, pos)


# ---------------------------------------------------------------------------
# Precinct 9: the station front, riot vans and barricades in the car park
# ---------------------------------------------------------------------------

func _build_precinct() -> void:
	var p := Node3D.new()
	p.name = "Precinct"
	geo.add_child(p)
	# Riot vans parked in the bays (two rows: a loop round each), lights still turning.
	var vans := [[Vector3(-46.0, 0, -12.0), 90.0], [Vector3(-46.0, 0, 11.0), 95.0], [Vector3(-60.0, 0, -15.0), 20.0],
		[Vector3(-61.0, 0, 14.0), -25.0]]
	var i := 0
	for v in vans:
		var van := _wreck(p, "city_police_van", "RiotVan%d" % i, v[0], v[1], i == 2)
		_police_lights(fx, "VanLights%d" % i, _empty_or(van, "Light", v[0] + Vector3(0, 2.6, 0)), i)
		i += 1
	_wreck(p, "city_car_burnt", "CruiserA", Vector3(-54.0, 0, 2.5), 160.0, true)
	_wreck(p, "city_car_burnt_b", "CruiserB", Vector3(-40.0, 0, -20.0), 10.0, false)
	# Barricades: a chicane of police barriers and jersey barriers before the steps.
	_solid_kit(p, "city_police_barrier", "BarrierA", Vector3(-66.0, 0, -6.0), 90.0, Vector3(2.8, 1.1, 0.5))
	_solid_kit(p, "city_police_barrier", "BarrierB", Vector3(-66.0, 0, 6.0), 90.0, Vector3(2.8, 1.1, 0.5))
	_solid_kit(p, "city_barrier_jersey", "JerseyA", Vector3(-52.5, 0, -6.5), 0.0, Vector3(3.0, 1.0, 0.7))
	_solid_kit(p, "city_barrier_jersey", "JerseyB", Vector3(-38.0, 0, 6.5), 0.0, Vector3(3.0, 1.0, 0.7))
	_solid_kit(p, "city_barrier_jersey", "JerseyC", Vector3(-58.0, 0, 20.5), 90.0, Vector3(3.0, 1.0, 0.7))
	_solid_kit(p, "city_barrier_jersey", "JerseyD", Vector3(-66.0, 0, -17.0), 0.0, Vector3(3.0, 1.0, 0.7))
	_solid_kit(p, "city_barrier_jersey", "JerseyE", Vector3(-40.0, 0, -5.5), 90.0, Vector3(3.0, 1.0, 0.7))
	_solid_kit(p, "city_police_barrier", "BarrierC", Vector3(-50.0, 0, 17.5), 0.0, Vector3(2.8, 1.1, 0.5))
	_solid_kit(p, "city_dumpster", "Dumpster", Vector3(-71.6, 0, -19.0), 90.0, Vector3(2.0, 1.4, 1.2))
	_fallen_slab(p, "FallenSlab", Vector3(-68.0, 0, 17.0), Vector3(4.5, 0.6, 3.0), 30.0, 18.0)
	_solid_kit(p, "city_rubble_a", "Rubble", Vector3(-37.0, 0, 20.0), 120.0, Vector3(3.2, 1.2, 2.6))
	_streetlight(p, "LampA", Vector3(-48.0, 0, -22.4), 0.0, true)
	_streetlight(p, "LampB", Vector3(-48.0, 0, 22.4), 180.0, false)
	_fire_at(fx, "PrecinctBarrel", Vector3(-69.0, 0, 9.5), 0.8, true)
	_smoke(fx, "SmokePrecinct", Vector3(-90.0, 12.0, -30.0), 1.4)
	# The station front: steps, the stencilled sign and the blue lamp.
	var front := Vector3(-74.0, 0, 0)
	var concrete := _surface("precinct_wall", ["city_concrete", "dune_concrete"], Color(0.6, 0.62, 0.72), 0.2, 0.9)
	_visual_box(dressing, "StationSign", Vector3(0.3, 1.2, 10.0), front + Vector3(0.3, 7.2, 0), _mat("precinct_sign", Color(0.1, 0.2, 0.55), 0.5, Color(0.3, 0.55, 1.0), 1.4))
	_visual_box(dressing, "StationPorch", Vector3(3.0, 0.4, 12.0), front + Vector3(-1.5, 5.2, 0), concrete)
	_omni(fx, "StationLamp", front + Vector3(1.2, 4.2, 0), Color(0.35, 0.55, 1.0), 1.6, 9.0)
	_label(dressing, "StationName", "PRECINCT 9", front + Vector3(0.48, 7.2, 0), 90.0, 240, Color(0.85, 0.92, 1.0))


## A fallen slab of facade: tilted concrete with a window row, chest-high
## cover (the collider is its upright box, capped against standing on it).
func _fallen_slab(parent: Node3D, slab_name: String, pos: Vector3, size: Vector3, yaw: float, tilt: float) -> void:
	var holder := Node3D.new()
	holder.name = slab_name
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = deg_to_rad(yaw)
	var mi := MeshInstance3D.new()
	mi.name = "Slab"
	mi.mesh = _box_mesh(size, _facade_material(slab_name.hash()))
	mi.rotation.x = deg_to_rad(tilt)
	mi.position.y = size.z * 0.5 * sin(deg_to_rad(tilt)) + size.y * 0.3
	holder.add_child(mi)
	var height := size.z * sin(deg_to_rad(tilt)) + size.y
	_collider(holder, "Collision", Vector3(size.x, height, size.z * cos(deg_to_rad(tilt)) + size.y * 0.5), Vector3(0, height * 0.5, 0))
	_player_block(holder, "Cap", Vector3(size.x, 3.0, size.z), Vector3(0, height + 1.5, 0))


## A light bar's light: the environment script swaps it red and blue.
func _police_lights(parent: Node3D, bar_name: String, pos: Vector3, phase: int) -> void:
	var l := _omni(parent, bar_name, pos + Vector3(0, 0.4, 0), Color(1.0, 0.15, 0.12), 2.4, 10.0)
	l.add_to_group("city_police_light", true)
	l.set_meta("phase", float(phase) * 0.37)


# ---------------------------------------------------------------------------
# Neon Market: stalls down the middle of the street, signs overhead
# ---------------------------------------------------------------------------

func _build_market() -> void:
	var m := Node3D.new()
	m.name = "Market"
	geo.add_child(m)
	# Stall islands down the middle: lanes either side, crossings between them.
	var islands := [40.0, 52.0, 72.0, 82.0]
	var i := 0
	for x in islands:
		for k in 2:
			_solid_kit(m, "city_market_stall", "Stall%d%d" % [i, k], Vector3(x - 2.0 + k * 4.0, 0, 0.0), k * 180.0, Vector3(3.6, 2.8, 2.4))
		_player_block(m, "Stall%dCap" % i, Vector3(8.0, 3.0, 2.8), Vector3(x, 4.5, 0.0))
		i += 1
	# The fire-trap gas line crosses the open middle (x 58..66).
	_solid_kit(m, "city_debris", "DebrisA", Vector3(62.0, 0, 5.5), 30.0, Vector3(2.0, 0.5, 1.6))
	_solid_kit(m, "city_dumpster", "DumpsterN", Vector3(46.0, 0, -6.8), 0.0, Vector3(2.0, 1.4, 1.2))
	_solid_kit(m, "city_dumpster", "DumpsterS", Vector3(76.0, 0, 6.8), 180.0, Vector3(2.0, 1.4, 1.2))
	_wreck(m, "city_car_burnt_b", "MarketCar", Vector3(64.0, 0, -5.4), 8.0, true)
	_wreck(m, "city_truck_jackknifed", "EastTruck", Vector3(91.0, 0, 1.5), 60.0, true)
	# Neon signs on both facades (flickering), and a cable of bulbs over the street.
	# Blade signs (a) stand out from the wall, panels (b) hang on it; both
	# models have their origin at street level under the wall.
	var signs := [[Vector3(38.0, 2.6, -8.0), 0.0, "city_neon_sign_a"], [Vector3(55.0, 2.4, 8.0), 180.0, "city_neon_sign_b"],
		[Vector3(68.0, 2.0, -8.0), 0.0, "city_neon_sign_b"], [Vector3(86.0, 2.8, 8.0), 180.0, "city_neon_sign_a"],
		[Vector3(48.0, 2.4, 8.0), 180.0, "city_neon_sign_a"], [Vector3(79.0, 3.2, -8.0), 0.0, "city_neon_sign_a"]]
	var colors := [Color(1.0, 0.2, 0.7), Color(0.2, 0.9, 1.0), Color(1.0, 0.75, 0.2), Color(0.5, 0.35, 1.0)]
	i = 0
	for s in signs:
		var c: Color = colors[i % colors.size()]
		_neon_sign(dressing, s[2], "Neon%d" % i, s[0], s[1], c)
		i += 1
	_market_canopy()
	_fire_at(fx, "MarketBarrel", Vector3(57.0, 0, -6.6), 0.8, true)
	_smoke(fx, "SmokeMarket", Vector3(110.0, 14.0, 20.0), 1.3)


## Over the market street: sagging cables of coloured bulbs from facade to
## facade, and neon tube banners across it (one MultiMesh per colour).
func _market_canopy() -> void:
	var colors := [Color(1.0, 0.3, 0.75), Color(0.3, 0.9, 1.0), Color(1.0, 0.78, 0.3)]
	var bulbs: Array[Array] = [[], [], []]
	var cable: Array[Transform3D] = []
	var k := 0
	for x in range(38, 90, 6):
		var a := Vector3(float(x), 6.2 + (k % 2) * 0.6, MARKET.position.y)
		var b := Vector3(float(x) + 3.0, 6.0 + ((k + 1) % 2) * 0.5, MARKET.end.y)
		var n := 12
		for i in n + 1:
			var t := float(i) / n
			var p := a.lerp(b, t) + Vector3(0, -1.1 * sin(PI * t), 0)
			if i < n:
				var q := a.lerp(b, (i + 1.0) / n) + Vector3(0, -1.1 * sin(PI * (i + 1.0) / n), 0)
				var seg := q - p
				cable.append(Transform3D(Basis.looking_at(seg.normalized(), Vector3.UP).scaled(Vector3(1, 1, seg.length())), (p + q) * 0.5))
			if i > 0 and i < n:
				bulbs[(i + k) % 3].append(Transform3D(Basis(), p + Vector3(0, -0.12, 0)))
		k += 1
	dressing.add_child(_multimesh("MarketCables", _box_mesh(Vector3(0.03, 0.03, 1.0), _mat("cable", Color(0.05, 0.05, 0.05), 0.8)), cable))
	for c in 3:
		var color: Color = colors[c]
		var sphere := SphereMesh.new()
		sphere.radius = 0.09
		sphere.height = 0.18
		sphere.radial_segments = 8
		sphere.rings = 4
		sphere.material = _mat("bulb_" + color.to_html(false), color, 0.3, color, 4.0)
		var xforms: Array[Transform3D] = []
		xforms.assign(bulbs[c])
		var mm := _multimesh("MarketBulbs%d" % c, sphere, xforms)
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dressing.add_child(mm)
	# Two banners across the street.
	for entry in [[40.0, "NEON MARKET", colors[0]], [80.0, "OPEN ALL NIGHT", colors[1]]]:
		var x: float = entry[0]
		var col: Color = entry[2]
		_visual_box(dressing, "Banner%d" % int(x), Vector3(0.25, 1.1, 9.0), Vector3(x, 7.6, 0.0), _mat("banner_back", Color(0.08, 0.06, 0.1), 0.6))
		for side in [-1.0, 1.0]:
			var l := _label(dressing, "Banner%dText%s" % [int(x), "W" if side < 0 else "E"], entry[1], Vector3(x + side * 0.14, 7.6, 0.0), 90.0 * side, 120, col)
			l.outline_modulate = col.darkened(0.6)
			l.add_to_group("city_neon_flicker", true)
		_visual_box(dressing, "Banner%dWireN" % int(x), Vector3(0.04, 0.04, MARKET.size.y * 0.5 - 4.5), Vector3(x, 7.9, MARKET.position.y + (MARKET.size.y * 0.5 - 4.5) * 0.5), _mat("cable", Color(0.05, 0.05, 0.05), 0.8))
		_visual_box(dressing, "Banner%dWireS" % int(x), Vector3(0.04, 0.04, MARKET.size.y * 0.5 - 4.5), Vector3(x, 7.9, MARKET.end.y - (MARKET.size.y * 0.5 - 4.5) * 0.5), _mat("cable", Color(0.05, 0.05, 0.05), 0.8))


## A neon sign from the kit, or a glowing panel; with a coloured light below it.
func _neon_sign(parent: Node3D, model: String, sign_name: String, pos: Vector3, yaw: float, color: Color) -> void:
	var node := _kit(parent, model, sign_name, pos, yaw, Vector3(3.2, 1.2, 0.2))
	if not ResourceLoader.exists(MODELS + model + ".glb"):
		var panel := node.get_node("Placeholder") as MeshInstance3D
		panel.mesh = _box_mesh(Vector3(3.2, 1.2, 0.2), _mat("neon_" + color.to_html(false), color, 0.4, color, 3.0))
	node.add_to_group("city_neon_flicker", true)
	var forward := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)
	var l := _omni(fx, sign_name + "Light", pos + forward * 1.4 + Vector3(0, 2.6, 0), color, 1.4, 7.0)
	l.add_to_group("city_neon_flicker", true)


# ---------------------------------------------------------------------------
# Metro Line: the stairs, the platform hall, the stalled train
# ---------------------------------------------------------------------------

func _build_metro() -> void:
	var m := Node3D.new()
	m.name = "Metro"
	geo.add_child(m)
	var tiles := _surface("metro_tiles", ["sky_tiles"], Color(0.62, 0.7, 0.66), 0.5, 0.6)
	var wall := _surface("metro_wall", ["city_concrete", "frost_stone"], Color(0.62, 0.74, 0.7), 0.3, 0.8)
	var dark := _mat("metro_dark", Color(0.12, 0.12, 0.14), 0.95)
	var x0 := HALL.position.x
	var x1 := HALL.end.x
	var zn := HALL.position.y
	var zs := HALL.end.y
	var len_x := x1 - x0
	# Platform (y -6) and the service tunnel west of it.
	_slab(m, "Platform", Rect2(x0 - 8.0, PLATFORM_EDGE_Z, len_x + 8.0, zs - PLATFORM_EDGE_Z), tiles, METRO_Y)
	# Track pit (visual) and the train standing in it, end to end.
	_visual_box(dressing, "TrackBed", Vector3(len_x + 16.0, 0.3, PLATFORM_EDGE_Z - zn), Vector3((x0 + x1) * 0.5, METRO_Y - 1.35, (zn + PLATFORM_EDGE_Z) * 0.5), dark)
	_collider(m, "TrackBedFloor", Vector3(len_x + 16.0, 1.0, PLATFORM_EDGE_Z - zn), Vector3((x0 + x1) * 0.5, METRO_Y - 1.7, (zn + PLATFORM_EDGE_Z) * 0.5))
	_build_train(m, Vector3((x0 + x1) * 0.5, METRO_Y - 1.2, (zn + PLATFORM_EDGE_Z) * 0.5 - 0.3), len_x + 12.0)
	_metro_dressing(m)
	# The hall: walls, ceiling, a row of pillars down the platform.
	var ceiling_x0 := x0 - 8.0
	var ceiling_x1 := TOWER.position.x
	_box(m, "Ceiling", Vector3(ceiling_x1 - ceiling_x0, 0.6, zs - zn + 2.0), Vector3((ceiling_x0 + ceiling_x1) * 0.5, HALL_CEILING + 0.3, (zn + zs) * 0.5), dark)
	_box(m, "WallNorth", Vector3(len_x + 16.0, 6.0, 1.0), Vector3((x0 + x1) * 0.5, METRO_Y + 2.5, zn - 0.5), wall)
	_hall_south_wall(m, wall)
	_hall_end_walls(m, wall)
	for k in 7:
		var px := x0 + 5.0 + k * 8.0
		_box(m, "Pillar%d" % k, Vector3(0.9, 5.4, 0.9), Vector3(px, METRO_Y + 2.7, -33.0), wall)
	_solid_kit(m, "city_newsstand", "PlatformKiosk", Vector3(13.0, METRO_Y, -30.2), 180.0, Vector3(2.4, 2.6, 1.6))
	_solid_kit(m, "city_barrier_jersey", "PlatformBarrierA", Vector3(-6.0, METRO_Y, -35.5), 0.0, Vector3(3.0, 1.0, 0.7))
	_solid_kit(m, "city_barrier_jersey", "PlatformBarrierB", Vector3(26.0, METRO_Y, -30.5), 0.0, Vector3(3.0, 1.0, 0.7))
	_solid_kit(m, "city_debris", "PlatformDebris", Vector3(30.0, METRO_Y, -35.8), 0.0, Vector3(2.0, 0.5, 1.6))
	# Platform edge: a hazard stripe and a player-only wall (no jumping on the tracks).
	_visual_box(dressing, "EdgeStripe", Vector3(len_x + 8.0, 0.03, 0.5), Vector3((x0 + x1) * 0.5 - 4.0, METRO_Y + 0.015, PLATFORM_EDGE_Z + 0.3), _surface("hazard", ["dune_hazard"], Color.WHITE, 1.0, 0.7))
	_player_wall(_player_walls(), "PlatformEdge", Vector3(x0 - 8.0, METRO_Y, PLATFORM_EDGE_Z - 0.2), Vector3(x1 + 2.0, METRO_Y, PLATFORM_EDGE_Z - 0.2), 6.0)
	# Emergency lamps (orange, a few red) along the ceiling.
	for k in 6:
		var lx := x0 + 4.0 + k * 10.0
		var red := k % 3 == 1
		var color := Color(1.0, 0.25, 0.15) if red else Color(1.0, 0.62, 0.3)
		_visual_box(dressing, "EmergencyLamp%d" % k, Vector3(1.4, 0.2, 0.4), Vector3(lx, HALL_CEILING - 0.15, -31.0), _mat("lamp_" + color.to_html(false), color, 0.4, color, 4.0))
		var l := _omni(fx, "Emergency%d" % k, Vector3(lx, HALL_CEILING - 1.0, -32.0), color, 2.4 if red else 2.2, 12.0)
		if red:
			l.add_to_group("city_neon_flicker", true)
	_build_stairs(m)


## The stalled train: carriages end to end along the platform (one collider),
## cream bodies with the line's green stripe, lit and broken windows, doors
## (one per carriage jammed half open) and dark couplings between them.
func _build_train(parent: Node3D, centre: Vector3, length: float) -> void:
	var cars := 5
	var gap := 0.7
	var car_len := (length - gap * (cars - 1)) / cars
	var body := _mat("train_body", Color(0.82, 0.83, 0.8), 0.45)
	var roof := _mat("train_roof", Color(0.42, 0.44, 0.46), 0.6)
	var stripe := _mat("train_stripe", Color(0.2, 0.75, 0.42), 0.5, Color(0.3, 1.0, 0.55), 0.35)
	var lit := _mat("train_window_lit", Color(0.95, 0.85, 0.6), 0.3, Color(1.0, 0.78, 0.45), 0.7)
	var dark := _mat("train_window_dark", Color(0.06, 0.07, 0.08), 0.2)
	var door := _mat("train_door", Color(0.62, 0.64, 0.62), 0.5)
	var under := _mat("train_under", Color(0.08, 0.08, 0.09), 0.9)
	var face_z := centre.z + 1.5
	var windows_lit: Array[Transform3D] = []
	var windows_dark: Array[Transform3D] = []
	var doors: Array[Transform3D] = []
	for c in cars:
		var cx := centre.x - length * 0.5 + car_len * 0.5 + c * (car_len + gap)
		_visual_box(dressing, "TrainCar%d" % c, Vector3(car_len, 2.9, 3.0), Vector3(cx, centre.y + 2.05, centre.z), body)
		_visual_box(dressing, "TrainCar%dRoof" % c, Vector3(car_len - 0.2, 0.35, 2.6), Vector3(cx, centre.y + 3.65, centre.z), roof)
		_visual_box(dressing, "TrainCar%dStripe" % c, Vector3(car_len + 0.02, 0.28, 3.04), Vector3(cx, centre.y + 1.25, centre.z), stripe)
		_visual_box(dressing, "TrainCar%dBogies" % c, Vector3(car_len - 1.0, 0.6, 2.4), Vector3(cx, centre.y + 0.3, centre.z), under)
		for w in 4:
			var wx := cx - car_len * 0.5 + car_len * (w + 0.5) / 4.0
			for d in [-1.0, 1.0]:
				var on := (c * 7 + w * 3 + int(d)) % 5 != 0
				var xf := Transform3D(Basis(), Vector3(wx + d * 1.05, centre.y + 2.45, face_z + 0.02))
				(windows_lit if on else windows_dark).append(xf)
			if w < 3:
				var dx := cx - car_len * 0.5 + car_len * (w + 1) / 4.0
				doors.append(Transform3D(Basis(), Vector3(dx + (0.35 if w == 1 and c % 2 == 0 else 0.0), centre.y + 1.95, face_z + 0.03)))
		if c < cars - 1:
			_visual_box(dressing, "TrainCoupling%d" % c, Vector3(gap + 0.2, 2.4, 2.2), Vector3(cx + car_len * 0.5 + gap * 0.5, centre.y + 1.8, centre.z), under)
	dressing.add_child(_multimesh("TrainWindowsLit", _box_mesh(Vector3(1.5, 0.95, 0.04), lit), windows_lit))
	dressing.add_child(_multimesh("TrainWindowsDark", _box_mesh(Vector3(1.5, 0.95, 0.04), dark), windows_dark))
	dressing.add_child(_multimesh("TrainDoors", _box_mesh(Vector3(1.3, 2.3, 0.05), door), doors))
	_collider(parent, "Train", Vector3(length, 3.8, 3.0), centre + Vector3(0, 1.9, 0))
	_player_block(parent, "TrainCap", Vector3(length, 3.0, 3.0), centre + Vector3(0, 5.3, 0))


## Platform furniture: the station's name boards, lightbox ads, benches and
## litter, so the hall reads as a station that was busy until it was not.
func _metro_dressing(parent: Node3D) -> void:
	var wall_z := HALL.end.y - 0.02
	var board := _mat("metro_board", Color(0.08, 0.32, 0.2), 0.5)
	for x in [-16.0, 8.0, 31.0]:
		_visual_box(dressing, "NameBoard%d" % int(x), Vector3(6.0, 1.0, 0.1), Vector3(x, METRO_Y + 3.2, wall_z - 0.05), board)
		_label(dressing, "NameText%d" % int(x), "ASHFALL SQUARE", Vector3(x, METRO_Y + 3.2, wall_z - 0.11), 180.0, 64, Color(1, 1, 1))
	var ads := ["ad0", "ad1", "ad2", "ad3"]
	var k := 0
	for x in [-20.0, 0.0 + 6.5, 15.5, 27.0, 35.5]:
		var m := _ad_material(ads[k % ads.size()], k)
		_visual_box(dressing, "AdFrame%d" % k, Vector3(3.2, 1.9, 0.12), Vector3(x, METRO_Y + 1.9, wall_z - 0.06), _mat("ad_frame", Color(0.2, 0.2, 0.22), 0.4))
		var ad := MeshInstance3D.new()
		ad.name = "Ad%d" % k
		var quad := QuadMesh.new()
		quad.size = Vector2(2.9, 1.45)
		quad.material = m
		ad.mesh = quad
		ad.position = Vector3(x, METRO_Y + 1.9, wall_z - 0.13)
		ad.rotation.y = PI
		dressing.add_child(ad)
		if k % 2 == 1:
			ad.add_to_group("city_neon_flicker", true)
		k += 1
	var bench := _mat("bench", Color(0.5, 0.3, 0.18), 0.6)
	for x in [-9.0, 1.0, 23.0]:
		_solid_kit(parent, "city_bench", "Bench%d" % int(x), Vector3(x, METRO_Y, -28.7), 180.0, Vector3(2.4, 0.5, 0.6))
	# Line signs over the platform edge, hanging from the ceiling.
	for x in [-6.0, 22.0]:
		_visual_box(dressing, "LineSign%d" % int(x), Vector3(3.4, 0.7, 0.12), Vector3(x, HALL_CEILING - 1.2, -37.0), board)
		_label(dressing, "LineSignText%d" % int(x), "LINE 3  >  TOWER", Vector3(x, HALL_CEILING - 1.2, -36.92), 0.0, 48, Color(1.0, 0.95, 0.6))
		_visual_box(dressing, "LineSign%dRod" % int(x), Vector3(0.06, 0.8, 0.06), Vector3(x, HALL_CEILING - 0.45, -37.0), bench)


## A lightbox ad: one cell of the neon ads atlas, lit from behind.
func _ad_material(key: String, cell: int) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var tex: Texture2D = load(TEXTURES + "neon_ads.png")
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission_energy_multiplier = 0.9
	m.uv1_scale = Vector3(0.25, 0.125, 1.0)
	m.uv1_offset = Vector3((cell % 4) * 0.25, ((cell * 3) % 8) * 0.125, 0.0)
	_materials[key] = m
	return m


func _label(parent: Node3D, label_name: String, text: String, pos: Vector3, yaw_degrees: float, font_size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.name = label_name
	l.text = text
	l.font = load("res://art/fonts/LilitaOne-Regular.ttf")
	l.font_size = font_size
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.03, 0.06)
	l.outline_size = 16
	l.shaded = false
	l.double_sided = false
	l.position = pos
	l.rotation.y = deg_to_rad(yaw_degrees)
	parent.add_child(l)
	return l


## Service doors in the hall's south wall (entrances), centred on these x.
const SERVICE_DOORS: Array[float] = [-12.0, 21.5]
const SERVICE_DOOR_WIDTH := 4.0


## The hall's south wall: the opening of the stairs from the square and the
## service doors, each into a small dark room the zombies come out of.
func _hall_south_wall(parent: Node3D, material: Material) -> void:
	var z := HALL.end.y + 0.5
	var y := METRO_Y + 2.7
	var half := SERVICE_DOOR_WIDTH * 0.5
	# Wall pieces between the openings, west to east.
	var cuts: Array[Vector2] = [Vector2(-STAIR_HALF, STAIR_HALF)]
	for x in SERVICE_DOORS:
		cuts.append(Vector2(x - half, x + half))
	cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var from := HALL.position.x - 8.0
	var k := 0
	for c in cuts:
		_box(parent, "WallSouth%d" % k, Vector3(c.x - from, 5.4, 1.0), Vector3((from + c.x) * 0.5, y, z), material)
		from = c.y
		k += 1
	_box(parent, "WallSouth%d" % k, Vector3(HALL.end.x - from, 5.4, 1.0), Vector3((from + HALL.end.x) * 0.5, y, z), material)
	var dark := _mat("metro_dark", Color(0.12, 0.12, 0.14), 0.95)
	var depth := 5.0
	for x in SERVICE_DOORS:
		var room := "ServiceDoor%d" % int(x)
		_box(parent, room + "Lintel", Vector3(SERVICE_DOOR_WIDTH, 2.4, 1.0), Vector3(x, METRO_Y + 4.2, z), material)
		_slab(parent, room + "Floor", Rect2(x - half - 0.5, HALL.end.y, SERVICE_DOOR_WIDTH + 1.0, depth + 0.5), dark, METRO_Y)
		_box(parent, room + "W", Vector3(0.5, 5.4, depth), Vector3(x - half - 0.25, y, z + depth * 0.5 - 0.5), dark)
		_box(parent, room + "E", Vector3(0.5, 5.4, depth), Vector3(x + half + 0.25, y, z + depth * 0.5 - 0.5), dark)
		_box(parent, room + "Back", Vector3(SERVICE_DOOR_WIDTH + 1.0, 5.4, 0.5), Vector3(x, y, z + depth - 0.25), dark)
		_box(parent, room + "Ceiling", Vector3(SERVICE_DOOR_WIDTH + 1.0, 0.6, depth), Vector3(x, HALL_CEILING + 0.3, z + depth * 0.5 - 0.5), dark)
		_player_wall(_player_walls(), room, Vector3(x - half, METRO_Y, z + 0.3), Vector3(x + half, METRO_Y, z + 0.3), 6.0)
		_omni(fx, room + "Glow", Vector3(x, METRO_Y + 2.5, z + 3.0), Color(1.0, 0.3, 0.15), 0.8, 5.0)


## The hall's ends: the west service tunnel (an entrance) and the east wall
## with the tower stairs' opening.
func _hall_end_walls(parent: Node3D, material: Material) -> void:
	var zn := HALL.position.y
	var zs := HALL.end.y
	var y := METRO_Y + 2.7
	# West: the tunnel continues 8 m (platform level) to a collapse.
	var xw := HALL.position.x - 8.0
	_box(parent, "WestCollapse", Vector3(1.0, 5.4, zs - zn), Vector3(xw - 0.5, y, (zn + zs) * 0.5), material)
	_solid_kit(parent, "city_rubble_a", "WestRubble", Vector3(xw + 1.8, METRO_Y, -36.4), 90.0, Vector3(3.0, 1.1, 2.4))
	_player_wall(_player_walls(), "WestTunnel", Vector3(HALL.position.x - 2.0, METRO_Y, PLATFORM_EDGE_Z), Vector3(HALL.position.x - 2.0, METRO_Y, zs), 6.0)
	# East: wall at x 40 with the exit opening (z -35..-29).
	var xe := HALL.end.x + 0.5
	_box(parent, "EastWallS", Vector3(1.0, 5.4, zs - EXIT_Z.y), Vector3(xe, y, (EXIT_Z.y + zs) * 0.5), material)
	_box(parent, "EastWallN", Vector3(1.0, 5.4, EXIT_Z.x - zn), Vector3(xe, y, (zn + EXIT_Z.x) * 0.5), material)
	_box(parent, "EastExitLintel", Vector3(1.0, 1.6, EXIT_Z.y - EXIT_Z.x), Vector3(xe, METRO_Y + 4.6, (EXIT_Z.x + EXIT_Z.y) * 0.5), material)


## Stairs from the square down to the platform, and from the hall up to the tower plaza.
func _build_stairs(parent: Node3D) -> void:
	var wall := _surface("metro_wall", ["city_concrete", "frost_stone"], Color(0.62, 0.74, 0.7), 0.3, 0.8)
	var steps := _mat("stair_steps", Color(0.42, 0.42, 0.44), 0.8)
	# Square stairs: z -16 (y 0) to z -27 (y -6), then a landing to the hall.
	_ramp(parent, "SquareStairs", Vector3(0, 0, STAIR_TOP_Z), Vector3(0, METRO_Y, STAIR_FOOT_Z), STAIR_HALF * 2.0)
	_slab(parent, "SquareStairsLanding", Rect2(-STAIR_HALF, STAIR_FOOT_Z - 1.0, STAIR_HALF * 2.0, 1.0), steps, METRO_Y)
	_step_visuals("SquareSteps", Vector3(0, 0, STAIR_TOP_Z), Vector3(0, METRO_Y, STAIR_FOOT_Z), STAIR_HALF * 2.0, steps)
	for s in [-1.0, 1.0]:
		var x: float = s * (STAIR_HALF + 0.4)
		_box(parent, "StairWall%s" % ("W" if s < 0 else "E"), Vector3(0.8, 6.6, 12.0), Vector3(x, METRO_Y * 0.5 - 0.3, (STAIR_TOP_Z + STAIR_FOOT_Z) * 0.5 - 0.5), wall)
	_box(parent, "StairRoof", Vector3(STAIR_HALF * 2.0 + 1.6, 0.6, 6.0), Vector3(0, -0.3, -25.0), wall)
	# Tower stairs: x 42 (y -6) to x 54 (y 0) along z -35..-29.
	var zc := (EXIT_Z.x + EXIT_Z.y) * 0.5
	var width := EXIT_Z.y - EXIT_Z.x
	_slab(parent, "TowerStairsFoot", Rect2(HALL.end.x, EXIT_Z.x, EXIT_FOOT_X - HALL.end.x, width), steps, METRO_Y)
	_ramp(parent, "TowerStairs", Vector3(EXIT_TOP_X, 0, zc), Vector3(EXIT_FOOT_X, METRO_Y, zc), width)
	_step_visuals("TowerSteps", Vector3(EXIT_TOP_X, 0, zc), Vector3(EXIT_FOOT_X, METRO_Y, zc), width, steps)
	for s in [-1.0, 1.0]:
		var z: float = zc + s * (width * 0.5 + 0.4)
		_box(parent, "ExitWall%s" % ("N" if s < 0 else "S"), Vector3(EXIT_TOP_X - HALL.end.x, 6.6, 0.8), Vector3((HALL.end.x + EXIT_TOP_X) * 0.5, METRO_Y * 0.5 - 0.3, z), wall)
	_box(parent, "ExitRoof", Vector3(TOWER.position.x - HALL.end.x, 0.6, width + 1.6), Vector3((HALL.end.x + TOWER.position.x) * 0.5, -0.3, zc), wall)
	# Railings round both openings at street level (block walking in from the sides).
	var walls := _player_walls()
	for s in [-1.0, 1.0]:
		_rail(parent, "SquareRail%s" % ("W" if s < 0 else "E"), Vector3(s * (STAIR_HALF + 0.1), 0, STAIR_TOP_Z), Vector3(s * (STAIR_HALF + 0.1), 0, -SQ))
		_rail(parent, "TowerRail%s" % ("N" if s < 0 else "S"), Vector3(TOWER.position.x, 0, zc + s * (width * 0.5 + 0.1)), Vector3(EXIT_TOP_X, 0, zc + s * (width * 0.5 + 0.1)))
	_player_wall(walls, "SquareStairW", Vector3(-STAIR_HALF - 0.1, 0, STAIR_TOP_Z), Vector3(-STAIR_HALF - 0.1, 0, -SQ), 4.0)
	_player_wall(walls, "SquareStairE", Vector3(STAIR_HALF + 0.1, 0, STAIR_TOP_Z), Vector3(STAIR_HALF + 0.1, 0, -SQ), 4.0)
	# The tower stairs' street entrance (the kit's canopied stairs, fitted to the flight).
	var entrance := _model_aabb("city_subway_entrance")
	if entrance.size.x > 0.1:
		var run := EXIT_TOP_X - EXIT_FOOT_X
		var sc := Vector3(width / entrance.size.x, -METRO_Y / -entrance.position.y, run / entrance.size.z)
		var node := _kit(dressing, "city_subway_entrance", "SubwayEntranceTower", Vector3(EXIT_TOP_X - entrance.end.z * sc.z, 0, zc), 90.0, Vector3.ZERO)
		node.scale = sc
		dressing.get_node("TowerSteps").visible = false


## A walkable ramp (collision) from `top` down to `foot`, `width` across.
func _ramp(parent: Node3D, ramp_name: String, top: Vector3, foot: Vector3, width: float) -> void:
	var flat := Vector3(foot.x - top.x, 0, foot.z - top.z)
	var run := flat.length()
	var drop := top.y - foot.y
	var thick := 0.5
	var body := StaticBody3D.new()
	body.name = ramp_name
	parent.add_child(body)
	var forward := flat.normalized()
	var yaw := atan2(-forward.x, -forward.z) + PI
	var angle := atan2(drop, run)
	body.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, angle)
	var normal := body.basis * Vector3.UP
	body.position = (top + foot) * 0.5 - normal * (thick * 0.5 - 0.06)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(width, thick, sqrt(run * run + drop * drop) + 0.3)
	shape.shape = box
	body.add_child(shape)


## The visible steps of a ramp (one MultiMesh of step blocks).
func _step_visuals(steps_name: String, top: Vector3, foot: Vector3, width: float, material: Material) -> void:
	var count := int(round((top.y - foot.y) / 0.3))
	var flat := Vector3(foot.x - top.x, 0, foot.z - top.z)
	var tread := flat.length() / count
	var basis := Basis(Vector3.UP, atan2(flat.x, flat.z))
	var xforms: Array[Transform3D] = []
	for k in count:
		var t := (k + 0.5) / count
		var p := top.lerp(foot, t)
		var y := top.y - (k + 1) * 0.3
		xforms.append(Transform3D(basis, Vector3(p.x, y - 0.6 + 0.3, p.z)))
	dressing.add_child(_multimesh(steps_name, _box_mesh(Vector3(width, 1.2, tread + 0.02), material), xforms))


## A railing (a kerb-height barrier the player cannot step over but sees through).
func _rail(parent: Node3D, rail_name: String, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var metal := _mat("rail_metal", Color(0.32, 0.36, 0.3), 0.5)
	var body := StaticBody3D.new()
	body.name = rail_name
	parent.add_child(body)
	body.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	body.rotation.y = atan2(-dir.z, dir.x)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(length, 1.1, 0.2)
	shape.shape = box
	shape.position.y = 0.55
	body.add_child(shape)
	var top_bar := MeshInstance3D.new()
	top_bar.name = "Bar"
	top_bar.mesh = _box_mesh(Vector3(length, 0.08, 0.08), metal)
	top_bar.position.y = 1.05
	body.add_child(top_bar)
	var xforms: Array[Transform3D] = []
	var posts := maxi(2, int(length / 1.2) + 1)
	for k in posts:
		xforms.append(Transform3D(Basis(), Vector3(-length * 0.5 + length * k / (posts - 1), 0.52, 0)))
	body.add_child(_multimesh("Posts", _box_mesh(Vector3(0.07, 1.04, 0.07), metal), xforms))


# ---------------------------------------------------------------------------
# Broadcast Tower: the plaza under the broken skyscraper and its radio mast
# ---------------------------------------------------------------------------

func _build_tower() -> void:
	var t := Node3D.new()
	t.name = "Tower"
	geo.add_child(t)
	var cx := TOWER.get_center().x
	# The radio mast's fenced base in the middle of the plaza (the boss arena's pillar).
	var mast := Vector3(cx + 4.0, 0, -48.0)
	_kit(dressing, "city_radio_tower", "RadioMast", mast, 15.0, Vector3(3.0, 40.0, 3.0))
	_box(t, "MastBase", Vector3(6.0, 1.2, 6.0), mast + Vector3(0, 0.6, 0), _surface("precinct_wall", ["city_concrete", "dune_concrete"], Color(0.6, 0.62, 0.72), 0.2, 0.9))
	_player_block(t, "MastCap", Vector3(6.0, 30.0, 6.0), mast + Vector3(0, 16.2, 0))
	var beacon := _omni(fx, "MastBeacon", mast + Vector3(0, 38.0, 0), Color(1.0, 0.15, 0.1), 3.0, 30.0)
	beacon.add_to_group("city_beacon", true)
	# Cover: wrecks, barriers and fallen chunks of the skyscraper.
	_wreck(t, "city_bus_wreck", "PlazaBus", Vector3(58.0, 0, -58.0), 35.0, true)
	_wreck(t, "city_car_burnt", "PlazaCarA", Vector3(84.0, 0, -30.0), 120.0, true)
	_wreck(t, "city_taxi_wreck", "PlazaTaxi", Vector3(86.0, 0, -62.0), 200.0, false)
	var van := _wreck(t, "city_police_van", "PlazaVan", Vector3(62.0, 0, -27.5), 0.0, false)
	_police_lights(fx, "PlazaVanLights", _empty_or(van, "Light", Vector3(62.0, 2.6, -27.5)), 5)
	_solid_kit(t, "city_rubble_a", "ChunkA", Vector3(72.0, 0, -36.0), 10.0, Vector3(3.2, 1.2, 2.6))
	_solid_kit(t, "city_rubble_b", "ChunkB", Vector3(66.0, 0, -64.0), 140.0, Vector3(3.0, 1.1, 2.4))
	_solid_kit(t, "city_rubble_a", "ChunkC", Vector3(90.0, 0, -46.0), 260.0, Vector3(3.2, 1.2, 2.6))
	_solid_kit(t, "city_barrier_jersey", "JerseyA", Vector3(55.0, 0, -42.0), 90.0, Vector3(3.0, 1.0, 0.7))
	_solid_kit(t, "city_barrier_jersey", "JerseyB", Vector3(79.0, 0, -53.0), 30.0, Vector3(3.0, 1.0, 0.7))
	# Chunks of the skyscraper's facade that came down on the plaza.
	_fallen_slab(t, "FallenSlabA", Vector3(60.0, 0, -45.0), Vector3(5.0, 0.7, 3.4), 80.0, 24.0)
	_fallen_slab(t, "FallenSlabB", Vector3(85.0, 0, -52.0), Vector3(4.6, 0.7, 3.2), 200.0, 20.0)
	_fallen_slab(t, "FallenSlabC", Vector3(70.0, 0, -64.0), Vector3(6.0, 0.8, 3.6), 10.0, 14.0)
	_fallen_slab(t, "FallenSlabD", Vector3(52.0, 0, -66.0), Vector3(4.0, 0.6, 3.0), 300.0, 28.0)
	_solid_kit(t, "city_billboard_torn", "Billboard", Vector3(92.0, 0, -36.0), -90.0, Vector3(6.0, 7.0, 0.6))
	_streetlight(t, "LampA", Vector3(48.0, 0, -24.0), 135.0, true)
	_streetlight(t, "LampB", Vector3(92.0, 0, -70.0), -45.0, true)
	_fire_at(fx, "PlazaFireA", Vector3(76.0, 0.2, -68.5), 1.6, true)
	_smoke(fx, "SmokeTower", Vector3(80.0, 20.0, -95.0), 2.0)
	_smoke(fx, "SmokeTowerB", Vector3(130.0, 14.0, -60.0), 1.5)


# ---------------------------------------------------------------------------
# City blocks: the buildings that wall every district (solid, closed boxes or
# the kit's broken facades in front of a solid core)
# ---------------------------------------------------------------------------

func _build_blocks() -> void:
	var b := Node3D.new()
	b.name = "Blocks"
	geo.add_child(b)
	# [name, x0, z0, x1, z1, height, facing ("N","S","E","W": the side the district sees)]
	var blocks := [
		# Square: north row (over the metro), south row, west and east rows.
		["SqN_W", -34.0, -36.0, -18.0, -22.0, 16.0, "S"], ["SqN_Mid", -13.0, -40.0, 13.0, -22.0, 22.0, "S"],
		["SqN_E", 18.0, -36.0, 34.0, -22.0, 14.0, "S"],
		["SqS_W", -34.0, 22.0, -18.0, 36.0, 15.0, "N"], ["SqS_MidW", -13.0, 22.0, -5.0, 34.0, 12.0, "N"],
		["SqS_MidE", 5.0, 22.0, 13.0, 34.0, 18.0, "N"], ["SqS_E", 18.0, 22.0, 34.0, 36.0, 13.0, "N"],
		["SqS_Far", -12.0, 44.0, 12.0, 56.0, 20.0, "N"],
		["SqW_N", -34.0, -22.0, -22.0, -4.0, 14.0, "E"], ["SqW_S", -34.0, 4.0, -22.0, 22.0, 17.0, "E"],
		["SqE_N", 22.0, -22.0, 34.0, -4.0, 16.0, "W"], ["SqE_S", 22.0, 4.0, 34.0, 22.0, 13.0, "W"],
		# Precinct: the station (west), north and south rows.
		["PrecinctHQ_N", -88.0, -24.0, -74.0, -3.0, 16.0, "E"], ["PrecinctHQ_S", -88.0, 3.0, -74.0, 24.0, 16.0, "E"],
		["PrecN_W", -88.0, -38.0, -56.0, -24.0, 14.0, "S"], ["PrecN_E", -52.0, -38.0, -34.0, -24.0, 18.0, "S"],
		["PrecS_W", -88.0, 24.0, -56.0, 38.0, 16.0, "N"], ["PrecS_E", -52.0, 24.0, -34.0, 38.0, 12.0, "N"],
		# Market: north row (with the tower alley and a side alley), south row.
		["MktN_W", 34.0, -22.0, 40.0, -8.0, 13.0, "S"], ["MktN_Mid", 44.0, -22.0, 62.0, -8.0, 15.0, "S"],
		["MktN_E", 70.0, -22.0, 98.0, -8.0, 12.0, "S"],
		["MktS_W", 34.0, 8.0, 54.0, 22.0, 14.0, "N"], ["MktS_E", 58.0, 8.0, 98.0, 22.0, 16.0, "N"],
		# Tower plaza: west row (over the stairs), east row, and the skyscraper's base.
		["TowW_N", 34.0, -72.0, 46.0, -58.0, 18.0, "E"], ["TowW_M", 34.0, -54.0, 46.0, -36.0, 18.0, "E"], ["TowW_S", 34.0, -28.0, 46.0, -22.0, 12.0, "E"],
		["TowE", 94.0, -72.0, 108.0, -50.0, 16.0, "W"], ["TowE_S", 94.0, -42.0, 108.0, -22.0, 14.0, "W"],
		["SkyscraperW", 46.0, -84.0, 66.0, -72.0, 24.0, "S"], ["SkyscraperE", 74.0, -84.0, 108.0, -72.0, 24.0, "S"],
		["SkyscraperBack", 46.0, -96.0, 108.0, -90.0, 30.0, ""],
		# Metro: the block over the hall's east end and the service rooms.
		["OverHallE", 34.0, -36.0, 46.0, -28.0, 10.0, "S"],
	]
	for row in blocks:
		_block(b, row[0], Rect2(row[1], row[2], row[3] - row[1], row[4] - row[2]), row[5], row[6])
	_build_shell_multimeshes()


## One city block: a solid collider and its look. With the kit, broken
## facades front the district side over a dark solid core; without it, a
## concrete box with rows of dark and a few lit windows.
func _block(parent: Node3D, block_name: String, r: Rect2, height: float, facing: String) -> void:
	var size := Vector3(r.size.x, height, r.size.y)
	var centre := Vector3(r.get_center().x, height * 0.5, r.get_center().y)
	_collider(parent, block_name, size, centre)
	var facade := _facade_material(block_name.hash())
	var shelled := ResourceLoader.exists(MODELS + SHELLS[0] + ".glb") and facing != "" and not block_name.begins_with("PrecinctHQ")
	if block_name.begins_with("PrecinctHQ"):
		facade = _precinct_material()
	# The core: behind the kit's facades (set back so their open floors show
	# dark rooms, not a wall), or the whole block's look without them.
	var look_size := size
	var look_centre := centre
	if shelled:
		var depth := _kit_facades(block_name, r, height, facing)
		var inset := minf(depth - 1.0, (r.size.y if facing in ["N", "S"] else r.size.x) - 2.0)
		var back := {"S": Vector3(0, 0, -1), "N": Vector3(0, 0, 1), "E": Vector3(-1, 0, 0), "W": Vector3(1, 0, 0)}[facing] as Vector3
		look_size -= back.abs() * inset
		look_centre += back * inset * 0.5
	var mi := MeshInstance3D.new()
	mi.name = block_name + "Look"
	mi.mesh = _box_mesh(look_size, facade)
	mi.position = look_centre
	dressing.add_child(mi)
	if shelled:
		var shadow := MeshInstance3D.new()
		shadow.name = block_name + "Shadow"
		shadow.mesh = _box_mesh(size - Vector3(0.6, 0.0, 0.6), facade)
		shadow.position = centre
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		dressing.add_child(shadow)
	# Roof parapet (breaks the box's top edge against the sky).
	var cap := _mat("parapet", Color(0.3, 0.27, 0.28), 0.9)
	_visual_box(dressing, block_name + "Parapet", Vector3(look_size.x + 0.4, 0.6, look_size.z + 0.4), Vector3(look_centre.x, height + 0.3, look_centre.z), cap)
	_player_block(parent, block_name + "Cap", Vector3(r.size.x, 12.0, r.size.y), Vector3(centre.x, height + 6.0, centre.z))


const SHELLS := ["city_building_shell_a", "city_building_shell_b", "city_building_shell_c", "city_building_corner"]
## Kit facades collected per district and model: one MultiMesh each.
var _shell_xforms := {}


## Places kit building shells along the district side of a block, their
## fronts on the block's face, scaled to the block's height; returns their
## depth (metres).
func _kit_facades(block_name: String, r: Rect2, height: float, facing: String) -> float:
	var along_x := facing == "N" or facing == "S"
	var length := r.size.x if along_x else r.size.y
	var count := maxi(1, int(round(length / 15.0)))
	var step := length / count
	var yaw := deg_to_rad({"S": 0.0, "N": 180.0, "E": 90.0, "W": -90.0}[facing] as float)
	var basis := Basis(Vector3.UP, yaw)
	var depth := 0.0
	for k in count:
		var t := -length * 0.5 + step * (k + 0.5)
		var face := Vector3(r.get_center().x, 0, r.get_center().y)
		if along_x:
			face += Vector3(t, 0, r.size.y * 0.5 * (1.0 if facing == "S" else -1.0))
		else:
			face += Vector3(r.size.x * 0.5 * (1.0 if facing == "E" else -1.0), 0, t)
		var model: String = SHELLS[absi(block_name.hash() + k * 7) % SHELLS.size()]
		var aabb := _model_aabb(model)
		var sx := step / aabb.size.x
		var sc := Vector3(sx, height / aabb.size.y, sx)
		# Local +Z is the front: its far edge goes on the face.
		var origin := face - basis * Vector3(aabb.get_center().x * sc.x, 0, aabb.end.z * sc.z)
		var key := "%s|%s" % [block_name.substr(0, 3), model]
		if not _shell_xforms.has(key):
			var fresh: Array[Transform3D] = []
			_shell_xforms[key] = fresh
		(_shell_xforms[key] as Array[Transform3D]).append(Transform3D(basis.scaled_local(sc), origin))
		depth = maxf(depth, aabb.size.z * sc.z)
	return depth


func _build_shell_multimeshes() -> void:
	for key in _shell_xforms:
		var model := String(key).get_slice("|", 1)
		var mmi := _multimesh("Shells_" + String(key).replace("|", "_"), _model_mesh(model), _shell_xforms[key])
		# The block cores behind cast the buildings' shadows (one surface
		# each, not the facades' twenty-odd).
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 120.0
		mmi.add_to_group("city_surface", true)
		dressing.add_child(mmi)


func _model_mesh(model: String) -> Mesh:
	if _mesh_cache.has(model):
		return _mesh_cache[model]
	var source: Node3D = (load(MODELS + model + ".glb") as PackedScene).instantiate()
	var mesh: Mesh = (source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	source.free()
	_mesh_cache[model] = mesh
	return mesh


## The police station: blue-grey with more of its windows still lit.
func _precinct_material() -> Material:
	if _materials.has("facade_precinct"):
		return _materials["facade_precinct"]
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "city_sky_skyline.gdshader")
	m.set_shader_parameter("wall_color", Color(0.42, 0.48, 0.6))
	m.set_shader_parameter("window_lit", Color(0.75, 0.85, 1.0))
	m.set_shader_parameter("lit_fraction", 0.18)
	m.set_shader_parameter("fire_fraction", 0.0)
	m.set_shader_parameter("window_size", Vector2(2.6, 3.6))
	_materials["facade_precinct"] = m
	return m


func _facade_material(seed: int) -> Material:
	var key := "facade_%d" % (absi(seed) % 3)
	if _materials.has(key):
		return _materials[key]
	var tints := [Color(0.58, 0.47, 0.42), Color(0.46, 0.45, 0.52), Color(0.55, 0.5, 0.4)]
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "city_sky_skyline.gdshader")
	m.set_shader_parameter("wall_color", tints[absi(seed) % 3])
	m.set_shader_parameter("seed", float(absi(seed) % 3) * 7.3)
	m.set_shader_parameter("lit_fraction", 0.03)
	m.set_shader_parameter("fire_fraction", 0.025)
	_materials[key] = m
	return m


# ---------------------------------------------------------------------------
# Gates: EndlessGate nodes (Frame, Door, Blocker, Zone, NavLinks)
# ---------------------------------------------------------------------------

func _build_gates() -> void:
	var holder := Node3D.new()
	holder.name = "Gates"
	geo.add_child(holder)
	var counts := {}
	for g in GATES:
		var district: StringName = g[0]
		counts[district] = int(counts.get(district, 0)) + 1
		var gate_name := "Gate_%s%s" % [district, "" if counts[district] == 1 else str(counts[district])]
		_gate(holder, gate_name, g)


func _gate(parent: Node3D, gate_name: String, g: Array) -> void:
	var pos: Vector3 = g[1]
	var width: float = g[3]
	var prefix: String = g[5]
	var gate := Node3D.new()
	gate.name = gate_name
	parent.add_child(gate)
	gate.position = pos
	gate.rotation.y = deg_to_rad(g[2])
	_late(gate, "res://scripts/endless/endless_gate.gd", {"district": g[0], "open_style": g[4]})
	var height := 5.0
	# The kit's frame and door share one origin and one scale: shrunk only
	# when the door is wider than the opening.
	var door_aabb := _model_aabb(prefix + "_door")
	var kit_scale := minf(1.0, width / door_aabb.size.x) if door_aabb.size.x > 0.1 else 1.0
	# Frame: posts and lintel (collide), the kit frame on top when present.
	var frame := _kit(gate, prefix + "_frame", "Frame", Vector3.ZERO, 0.0, Vector3.ZERO)
	frame.scale = Vector3.ONE * kit_scale
	if frame.get_child_count() == 0:
		var concrete := _mat("gate_frame", Color(0.42, 0.4, 0.4), 0.85)
		for s in [-1.0, 1.0]:
			_visual_box(frame, "Post%s" % ("L" if s < 0 else "R"), Vector3(0.8, height + 0.6, 0.8), Vector3(s * (width * 0.5 + 0.4), (height + 0.6) * 0.5, 0), concrete)
		_visual_box(frame, "Lintel", Vector3(width + 1.6, 0.6, 0.8), Vector3(0, height + 0.3, 0), concrete)
	for s in [-1.0, 1.0]:
		_collider(frame, "PostCollision%s" % ("L" if s < 0 else "R"), Vector3(0.8, height + 0.6, 0.8), Vector3(s * (width * 0.5 + 0.4), (height + 0.6) * 0.5, 0))
	# Door: what moves away.
	var door := _kit(gate, prefix + "_door", "Door", Vector3.ZERO, 0.0, Vector3.ZERO)
	door.scale = Vector3.ONE * kit_scale
	if door_aabb.size.x > 0.1:
		_late(door, "res://scripts/props/city_gate_door.gd", {"style": g[4]})
	else:
		var hazard := _surface("hazard", ["dune_hazard"], Color.WHITE, 1.0, 0.7)
		_visual_box(door, "Panel", Vector3(width, height, 0.25), Vector3(0, height * 0.5, 0), _mat("gate_door", Color(0.5, 0.52, 0.55), 0.5))
		_visual_box(door, "Stripe", Vector3(width, 0.6, 0.3), Vector3(0, 1.0, 0), hazard)
	# Blocker: the solid barrier (world layer), removed on open.
	var blocker := StaticBody3D.new()
	blocker.name = "Blocker"
	gate.add_child(blocker)
	var bs := CollisionShape3D.new()
	bs.name = "CollisionShape3D"
	var bbox := BoxShape3D.new()
	bbox.size = Vector3(width, height + 2.0, 0.8)
	bs.shape = bbox
	bs.position.y = (height + 2.0) * 0.5 - 1.0
	blocker.add_child(bs)
	# Zone: both sides, where the player can pay.
	var zone := Area3D.new()
	zone.name = "Zone"
	zone.collision_layer = 8
	zone.collision_mask = 2
	zone.monitorable = false
	gate.add_child(zone)
	var zs := CollisionShape3D.new()
	zs.name = "CollisionShape3D"
	var zbox := BoxShape3D.new()
	zbox.size = Vector3(width + 1.0, 3.5, 7.0)
	zs.shape = zbox
	zs.position.y = 1.75
	zone.add_child(zs)
	# NavLinks across the threshold, disabled until open.
	var links := 3 if width >= 7.0 else 2
	for k in links:
		var link := NavigationLink3D.new()
		link.name = "NavLink" if k == 0 else "NavLink%d" % (k + 1)
		var lx := (float(k) / (links - 1) - 0.5) * (width - 2.4)
		var y_neg: float = g[6] - pos.y
		var y_pos: float = g[7] - pos.y
		link.start_position = Vector3(lx, y_neg, -2.2)
		link.end_position = Vector3(lx, y_pos, 2.2)
		link.bidirectional = true
		link.enabled = false
		gate.add_child(link)


## Scales a kit model so its width (X) is `width` (no-op for stand-ins).
func _fit_width(node: Node3D, model: String, width: float) -> void:
	var aabb := _model_aabb(model)
	if aabb.size.x > 0.1:
		node.scale = Vector3.ONE * (width / aabb.size.x)


# ---------------------------------------------------------------------------
# Entrances: alleys, doors and tunnels the zombies come out of (out of reach)
# ---------------------------------------------------------------------------

## [district, marker position, yaw (facing the district), alley rect (x, z, w, d)
## or null (a door built with its district), depth of the block closing the
## alley's far end, the lintel over it (bottom, top; zero: open to the sky)]
const ENTRANCES := [
	[&"ashfall_square", Vector3(-15.5, 0, -27.5), 180.0, Rect2(-18.0, -34.0, 5.0, 12.0), 10.0, Vector2.ZERO],
	[&"ashfall_square", Vector3(15.5, 0, -27.5), 180.0, Rect2(13.0, -34.0, 5.0, 12.0), 10.0, Vector2.ZERO],
	[&"ashfall_square", Vector3(-15.5, 0, 27.5), 0.0, Rect2(-18.0, 22.0, 5.0, 12.0), 10.0, Vector2.ZERO],
	[&"ashfall_square", Vector3(15.5, 0, 27.5), 0.0, Rect2(13.0, 22.0, 5.0, 12.0), 10.0, Vector2.ZERO],
	[&"precinct", Vector3(-54.0, 0, -29.5), 180.0, Rect2(-56.0, -36.0, 4.0, 12.0), 10.0, Vector2.ZERO],
	[&"precinct", Vector3(-54.0, 0, 29.5), 0.0, Rect2(-56.0, 24.0, 4.0, 12.0), 10.0, Vector2.ZERO],
	[&"precinct", Vector3(-78.0, 0, 0.0), -90.0, Rect2(-82.0, -3.0, 8.0, 6.0), 10.0, Vector2(4.5, 16.0)],
	[&"market", Vector3(42.0, 0, -14.0), 180.0, Rect2(40.0, -20.0, 4.0, 12.0), 2.0, Vector2.ZERO],
	[&"market", Vector3(56.0, 0, 14.0), 0.0, Rect2(54.0, 8.0, 4.0, 12.0), 10.0, Vector2.ZERO],
	[&"market", Vector3(97.0, 0, -5.0), 90.0, Rect2(90.0, -8.0, 8.0, 16.0), 10.0, Vector2.ZERO],
	[&"metro", Vector3(-23.5, METRO_Y, -31.5), -90.0, null, 0.0, Vector2.ZERO],
	[&"metro", Vector3(21.5, METRO_Y, -24.0), 0.0, null, 0.0, Vector2.ZERO],
	[&"metro", Vector3(-12.0, METRO_Y, -24.0), 0.0, null, 0.0, Vector2.ZERO],
	[&"tower", Vector3(70.0, 0, -77.0), 180.0, Rect2(66.0, -84.0, 8.0, 12.0), 6.0, Vector2(5.0, 24.0)],
	[&"tower", Vector3(99.0, 0, -46.0), 90.0, Rect2(94.0, -50.0, 12.0, 8.0), 10.0, Vector2.ZERO],
	[&"tower", Vector3(40.0, 0, -56.0), -90.0, Rect2(34.0, -58.0, 12.0, 4.0), 10.0, Vector2.ZERO],
]


func _build_entrances() -> void:
	var e := Node3D.new()
	e.name = "Entrances"
	geo.add_child(e)
	var asphalt := _surface("asphalt", ["city_asphalt", "neon_roof"], Color(1.0, 1.0, 1.0), 0.12, 0.8)
	var i := 0
	for entry in ENTRANCES:
		if entry[3] != null:
			var r: Rect2 = entry[3]
			_slab(e, "AlleyFloor%d" % i, r, asphalt)
			var away: Vector3 = Basis(Vector3.UP, deg_to_rad(entry[2])) * Vector3(0, 0, 1)
			var depth: float = entry[4]
			var back := r
			if absf(away.x) > 0.5:
				back = Rect2(r.end.x if away.x > 0.0 else r.position.x - depth, r.position.y, depth, r.size.y)
			else:
				back = Rect2(r.position.x, r.end.y if away.z > 0.0 else r.position.y - depth, r.size.x, depth)
			_block(e, "AlleyEnd%d" % i, back, 16.0, "")
			var lintel: Vector2 = entry[5]
			if lintel.y > 0.0:
				var size := Vector3(r.size.x, lintel.y - lintel.x, r.size.y)
				_box(e, "Lintel%d" % i, size, Vector3(r.get_center().x, lintel.x + size.y * 0.5, r.get_center().y), _facade_material(i))
		i += 1


# ---------------------------------------------------------------------------
# Boundary: invisible player-only walls across alleys and at the districts' edges
# ---------------------------------------------------------------------------

func _build_boundary() -> void:
	var walls := _player_walls()
	# Alley mouths: zombies walk out, the player cannot walk in.
	var mouths := [
		[Vector3(-18, 0, -22.4), Vector3(-13, 0, -22.4)], [Vector3(13, 0, -22.4), Vector3(18, 0, -22.4)],
		[Vector3(-18, 0, 22.4), Vector3(-13, 0, 22.4)], [Vector3(13, 0, 22.4), Vector3(18, 0, 22.4)],
		[Vector3(-56, 0, -24.4), Vector3(-52, 0, -24.4)], [Vector3(-56, 0, 24.4), Vector3(-52, 0, 24.4)],
		[Vector3(-74.4, 0, -3), Vector3(-74.4, 0, 3)],
		[Vector3(40, 0, -8.4), Vector3(44, 0, -8.4)], [Vector3(54, 0, 8.4), Vector3(58, 0, 8.4)],
		[Vector3(89.6, 0, -8), Vector3(89.6, 0, 8)],
		[Vector3(66, 0, -72.4), Vector3(74, 0, -72.4)], [Vector3(94.4, 0, -50), Vector3(94.4, 0, -42)],
		[Vector3(46.4, 0, -58), Vector3(46.4, 0, -54)],
		[Vector3(-5, 0, 22.4), Vector3(5, 0, 22.4)],
	]
	var i := 0
	for m in mouths:
		_player_wall(walls, "Mouth%d" % i, m[0], m[1], WALL_H)
		i += 1


func _player_walls() -> Node3D:
	var walls := level.get_node_or_null("PlayerWalls") as Node3D
	if walls == null:
		walls = Node3D.new()
		walls.name = "PlayerWalls"
		level.add_child(walls)
	return walls


func _player_wall(parent: Node3D, wall_name: String, a: Vector3, b: Vector3, height: float) -> void:
	var length := a.distance_to(b)
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


# ---------------------------------------------------------------------------
# Skyline: rings of distant towers, the broken skyscraper, smoke over the city
# ---------------------------------------------------------------------------

func _build_skyline() -> void:
	var back := Node3D.new()
	back.name = "Skyline"
	dressing.add_child(back)
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "city_sky_skyline.gdshader")
	m.set_shader_parameter("far_fade", 1.0)
	m.set_shader_parameter("window_size", Vector2(4.0, 4.4))
	m.set_shader_parameter("wall_color", Color(0.3, 0.24, 0.26))
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = m
	var xforms: Array[Transform3D] = []
	var centre := Vector3(10.0, 0, -24.0)
	for ring in 3:
		var radius := 150.0 + ring * 90.0
		var count := 44 + ring * 18
		for k in count:
			var a := TAU * (k + _rng.randf_range(-0.3, 0.3)) / count
			var r := radius + _rng.randf_range(-25.0, 25.0)
			var w := _rng.randf_range(14.0, 30.0) + ring * 6.0
			var h := _rng.randf_range(24.0, 60.0) + ring * 18.0
			if _rng.randf() < 0.15:
				h *= 1.8
			var pos := centre + Vector3(cos(a) * r, h * 0.5 - 2.0, sin(a) * r)
			var basis := Basis(Vector3.UP, -a + _rng.randf_range(-0.2, 0.2)).scaled(Vector3(w, h, _rng.randf_range(12.0, 26.0)))
			xforms.append(Transform3D(basis, pos))
	var mmi := _multimesh("Towers", mesh, xforms)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	back.add_to_group("city_surface", true)
	back.add_child(mmi)
	# The ground out to the horizon round the city's footprint (the districts
	# have their own floors; the stairwells must stay open), and a dark floor
	# deep under everything.
	var ground := _mat("far_ground", Color(0.16, 0.13, 0.13), 1.0)
	var city := Rect2(-100.0, -104.0, 222.0, 168.0)
	var far := 700.0
	var pieces := [Rect2(-far, -far, far * 2.0, far + city.position.y), Rect2(-far, city.end.y, far * 2.0, far - city.end.y),
		Rect2(-far, city.position.y, far + city.position.x, city.size.y), Rect2(city.end.x, city.position.y, far - city.end.x, city.size.y)]
	var k := 0
	for r in pieces:
		var piece := _visual_box(back, "FarGround%d" % k, Vector3(r.size.x, 0.1, r.size.y), Vector3(r.get_center().x, -0.1, r.get_center().y), ground)
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		k += 1
	_visual_box(back, "UnderFloor", Vector3(city.size.x, 0.1, city.size.y), Vector3(city.get_center().x, METRO_Y - 2.6, city.get_center().y), ground)
	# The broken skyscraper over the tower plaza, and a second ruin across the city.
	var sky := _kit(back, "city_skyscraper_broken", "BrokenSkyscraper", Vector3(64.0, 0, -100.0), 10.0, Vector3(36.0, 110.0, 30.0))
	if sky.get_child_count() > 0 and sky.get_node_or_null("Placeholder") == null:
		_fit_width(sky, "city_skyscraper_broken", 40.0)
	_kit(back, "city_skyscraper_broken", "FarRuin", Vector3(-140.0, 0, 90.0), 200.0, Vector3(30.0, 80.0, 26.0))
	_smoke(fx, "SmokeFarW", Vector3(-160.0, 20.0, -80.0), 3.0)
	_smoke(fx, "SmokeFarS", Vector3(40.0, 20.0, 170.0), 2.6)
	_smoke(fx, "SmokeFarN", Vector3(-40.0, 25.0, -190.0), 3.4)
	_omni(fx, "SkyscraperFire", Vector3(64.0, 60.0, -88.0), Color(1.0, 0.45, 0.15), 4.0, 60.0)


## The kit's drifting ash round the camera (it follows the camera itself).
func _build_ashfall() -> void:
	var scene := PROPS + "city_ashfall.tscn"
	if ResourceLoader.exists(scene):
		var ash: Node3D = (load(scene) as PackedScene).instantiate()
		ash.name = "Ashfall"
		fx.add_child(ash)


# ---------------------------------------------------------------------------
# Markers: the player's spawn, the zombies' entrances
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = STATION + Vector3(0.0, 0.1, 9.5)
	start.add_to_group("player_spawn", true)
	level.add_child(start)
	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	var counts := {}
	for entry in ENTRANCES:
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


# ---------------------------------------------------------------------------
# District areas (HUD name, spawn planning) and feature markers
# ---------------------------------------------------------------------------

func _build_areas() -> void:
	var holder := Node3D.new()
	holder.name = "DistrictAreas"
	level.add_child(holder)
	var areas := {
		&"ashfall_square": [AABB(Vector3(-SQ, -0.5, STAIR_TOP_Z), Vector3(SQ * 2.0, 14.0, SQ - STAIR_TOP_Z)),
			AABB(Vector3(-SQ, -0.5, -SQ), Vector3(SQ - STAIR_HALF, 14.0, SQ + STAIR_TOP_Z)),
			AABB(Vector3(STAIR_HALF, -0.5, -SQ), Vector3(SQ - STAIR_HALF, 14.0, SQ + STAIR_TOP_Z)),
			AABB(Vector3(-28.0, -0.5, -4.0), Vector3(6.0, 14.0, 8.0)), AABB(Vector3(SQ, -0.5, -4.0), Vector3(6.0, 14.0, 8.0))],
		&"precinct": [AABB(Vector3(-90.0, -0.5, -36.0), Vector3(62.0, 14.0, 72.0))],
		&"market": [AABB(Vector3(28.0, -0.5, -15.0), Vector3(72.0, 14.0, 35.0))],
		&"metro": [AABB(Vector3(-28.0, -8.0, -44.0), Vector3(68.0, 7.5, 28.0)),
			AABB(Vector3(-STAIR_HALF, -0.5, -SQ), Vector3(STAIR_HALF * 2.0, 4.0, SQ + STAIR_TOP_Z))],
		&"tower": [AABB(Vector3(40.0, -8.0, -86.0), Vector3(70.0, 40.0, 71.0))],
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
			var aabb: AABB = box
			var shape := CollisionShape3D.new()
			shape.name = "Box%d" % k
			var bs := BoxShape3D.new()
			bs.size = aabb.size
			shape.shape = bs
			shape.position = aabb.get_center()
			area.add_child(shape)
			k += 1


func _build_features() -> void:
	var holder := Node3D.new()
	holder.name = "Features"
	level.add_child(holder)
	var features := [
		[&"trap_fire", &"precinct", Vector3(-46.0, 0, 0.0), 90.0],
		[&"trap_shock", &"metro", Vector3(7.0, METRO_Y, -30.5), 0.0],
		[&"trap_fire", &"market", Vector3(62.0, 0, 0.0), 90.0],
		[&"trap_shock", &"tower", Vector3(64.0, 0, -46.0), 0.0],
		[&"supply_drop", &"ashfall_square", Vector3(-8.0, 0, 6.0), 0.0],
		[&"supply_drop", &"precinct", Vector3(-62.0, 0, 0.0), 0.0],
		[&"supply_drop", &"market", Vector3(46.0, 0, 4.5), 0.0],
		[&"supply_drop", &"tower", Vector3(82.0, 0, -38.0), 0.0],
	]
	var counts := {}
	for f in features:
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


# ---------------------------------------------------------------------------
# Fire, smoke and lights
# ---------------------------------------------------------------------------

func _omni(parent: Node3D, light_name: String, pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = light_name
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.3
	l.shadow_enabled = false
	parent.add_child(l)
	_light_count += 1
	return l


## A fire (the kit's city_fire scene, scaled, or crossed flame quads) with an optional light.
func _fire_at(parent: Node3D, fire_name: String, pos: Vector3, size: float, with_light: bool) -> void:
	var scene := PROPS + "city_fire.tscn"
	if ResourceLoader.exists(scene):
		var f: Node3D = (load(scene) as PackedScene).instantiate()
		f.name = fire_name
		parent.add_child(f)
		f.position = pos
		f.set("size", size)
		f.set("with_light", with_light)
		f.add_to_group("city_fire", true)
		return
	var holder := Node3D.new()
	holder.name = fire_name
	parent.add_child(holder)
	holder.position = pos
	holder.add_to_group("city_fire", true)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.1, 1.5) * size
	quad.center_offset = Vector3(0, 0.75 * size, 0)
	for k in 2:
		var m := ShaderMaterial.new()
		m.shader = load(SHADERS + "frost_fire.gdshader")
		m.set_shader_parameter("seed", k * 1.7 + fire_name.length())
		var q := MeshInstance3D.new()
		q.name = "Flame%d" % k
		q.mesh = quad
		q.material_override = m
		q.rotation.y = PI * k / 2.0
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(q)
	if with_light:
		var l := _omni(holder, "Light", Vector3(0, 0.9 * size, 0), Color(1.0, 0.52, 0.2), 1.8, 7.0 + size * 2.0)
		_late(l, "res://scripts/props/frost_flicker.gd", {})


## A tall column of smoke from a far fire (the kit's scene or soft smoke quads).
func _smoke(parent: Node3D, smoke_name: String, pos: Vector3, size: float) -> void:
	var scene := PROPS + "city_smoke_column.tscn"
	if ResourceLoader.exists(scene):
		var s: Node3D = (load(scene) as PackedScene).instantiate()
		s.name = smoke_name
		parent.add_child(s)
		s.position = pos
		s.scale = Vector3.ONE * size
		return
	var holder := Node3D.new()
	holder.name = smoke_name
	parent.add_child(holder)
	holder.position = pos
	for k in 2:
		var quad := QuadMesh.new()
		quad.size = Vector2(22.0, 60.0) * size
		quad.center_offset = Vector3(0, 28.0 * size, 0)
		var m := ShaderMaterial.new()
		m.shader = load(SHADERS + "lava_smoke.gdshader")
		m.set_shader_parameter("seed", k * 3.1 + smoke_name.length())
		m.set_shader_parameter("opacity", 0.85)
		m.set_shader_parameter("smoke_color", Color(0.16, 0.11, 0.11))
		var q := MeshInstance3D.new()
		q.name = "Plume%d" % k
		q.mesh = quad
		q.material_override = m
		q.rotation.y = PI * k / 2.0 + 0.4
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(q)


# ---------------------------------------------------------------------------
# Navigation: baked with every gate shut; every district's island kept
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
	mesh.filter_baking_aabb = AABB(Vector3(-92, METRO_Y - 2.0, -92), Vector3(204, 10.0, 132))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	var seeds: Array[Vector3] = _spawn_points.duplicate()
	seeds.append(STATION + Vector3(0, 0, 9.5))
	region.navigation_mesh = _keep_islands(mesh, seeds)
	print("build_endless_city: navmesh polygons = %d (dropped %d on junk islands)" % [region.navigation_mesh.get_polygon_count(),
		before - region.navigation_mesh.get_polygon_count()])


## Keeps every connected set of polygons that has a polygon near one of
## `seeds` (each district's entrances and the player spawn); drops roofs, the
## tops of props and anything else nothing can reach.
func _keep_islands(mesh: NavigationMesh, seeds: Array[Vector3]) -> NavigationMesh:
	var count := mesh.get_polygon_count()
	var verts := mesh.get_vertices()
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
	var keep := {}
	for s in seeds:
		var best := -1
		var best_d := 1e9
		for i in count:
			var c := Vector3.ZERO
			var poly := mesh.get_polygon(i)
			for v in poly:
				c += verts[v]
			c /= poly.size()
			var d := Vector2(c.x - s.x, c.z - s.z).length() + absf(c.y - s.y) * 3.0
			if d < best_d:
				best_d = d
				best = i
		if best >= 0 and best_d < 6.0:
			keep[_find(parent, best)] = true
	var out: NavigationMesh = mesh.duplicate()
	out.clear_polygons()
	var remap := {}
	var kept := PackedVector3Array()
	for i in count:
		if not keep.has(_find(parent, i)):
			continue
		var mapped := PackedInt32Array()
		for v in mesh.get_polygon(i):
			if not remap.has(v):
				remap[v] = kept.size()
				kept.append(verts[v])
			mapped.append(remap[v])
		out.add_polygon(mapped)
	out.vertices = kept
	print("build_endless_city: kept %d navmesh islands" % keep.size())
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


## World-projected (triplanar) texture: the first of `textures` that exists,
## tinted; a flat colour if none does.
func _surface(key: String, textures: Array, tint: Color, scale: float, roughness: float) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = tint
	m.roughness = roughness
	for texture in textures:
		var path: String = TEXTURES + texture + ".png"
		if not ResourceLoader.exists(path):
			continue
		m.albedo_texture = load(path)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * scale
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var normal_path: String = TEXTURES + texture + "_normal.png"
		if ResourceLoader.exists(normal_path):
			m.normal_enabled = true
			m.normal_texture = load(normal_path)
			m.normal_scale = 0.8
		break
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


func _multimesh(mm_name: String, mesh: Mesh, xforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = mm_name
	mmi.multimesh = mm
	return mmi


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


## Invisible upright cylinder collider for posts and poles.
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


## A kit prop with a box collider: from the model's bounds when the model is
## there, else `size` (footprint, standing on `pos`). The body's meta "top"
## is the collider's height.
func _solid_kit(parent: Node3D, model: String, prop_name: String, pos: Vector3, yaw: float, size: Vector3) -> StaticBody3D:
	_kit(parent, model, prop_name, pos, yaw, size)
	var aabb := _model_aabb(model)
	var box_size := size
	var offset := Vector3(0, size.y * 0.5, 0)
	if aabb.size.x > 0.1:
		box_size = aabb.size
		offset = aabb.get_center()
	var body := _collider(parent, prop_name + "Collision", box_size, pos)
	body.position = pos + Basis(Vector3.UP, deg_to_rad(yaw)) * offset
	body.rotation.y = deg_to_rad(yaw)
	body.set_meta("top", offset.y + box_size.y * 0.5)
	return body


## Instances art/models/<model>.glb, or a stand-in box of `placeholder_size`
## (an empty node when that is zero).
func _kit(parent: Node3D, model: String, prop_name: String, pos: Vector3, yaw_degrees: float, placeholder_size: Vector3) -> Node3D:
	var path := MODELS + model + ".glb"
	var node: Node3D
	if ResourceLoader.exists(path):
		node = (load(path) as PackedScene).instantiate()
	else:
		node = Node3D.new()
		if placeholder_size != Vector3.ZERO:
			var mi := MeshInstance3D.new()
			mi.name = "Placeholder"
			mi.mesh = _box_mesh(placeholder_size, _placeholder_material(model))
			mi.position.y = placeholder_size.y * 0.5
			node.add_child(mi)
	node.name = prop_name
	parent.add_child(node)
	node.position = pos
	node.rotation.y = deg_to_rad(yaw_degrees)
	return node


## Stand-in colours by kind, so the grey-box still reads.
func _placeholder_material(model: String) -> Material:
	var colors := {"car": Color(0.22, 0.2, 0.2), "taxi": Color(0.95, 0.75, 0.15), "police": Color(0.85, 0.88, 0.95),
		"bus": Color(0.3, 0.45, 0.6), "truck": Color(0.6, 0.3, 0.2), "rubble": Color(0.5, 0.46, 0.44),
		"jersey": Color(0.75, 0.72, 0.68), "barrier": Color(0.95, 0.85, 0.2), "statue": Color(0.4, 0.62, 0.55),
		"stall": Color(0.65, 0.3, 0.3), "skyscraper": Color(0.2, 0.19, 0.22), "radio": Color(0.7, 0.2, 0.15)}
	for k in colors:
		if model.contains(k):
			return _mat("ph_" + k, colors[k], 0.75)
	return _mat("placeholder", Color(0.55, 0.52, 0.55), 0.8)


## The bounds of a kit model in its own space (zero size when it is missing).
func _model_aabb(model: String) -> AABB:
	if _aabb_cache.has(model):
		return _aabb_cache[model]
	var aabb := AABB()
	var path := MODELS + model + ".glb"
	if ResourceLoader.exists(path):
		var source: Node3D = (load(path) as PackedScene).instantiate()
		var first := true
		for mi in source.find_children("*", "MeshInstance3D", true, false):
			var inst := mi as MeshInstance3D
			var xf := Transform3D()
			var n: Node = inst
			while n != source:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			var box := xf * inst.mesh.get_aabb()
			aabb = box if first else aabb.merge(box)
			first = false
		source.free()
	_aabb_cache[model] = aabb
	return aabb


func _own(node: Node) -> void:
	for child in node.get_children():
		child.owner = level
		if child.scene_file_path == "":
			_own(child)
