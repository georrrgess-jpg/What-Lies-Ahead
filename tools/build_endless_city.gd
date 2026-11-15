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
const Batch := preload("res://scripts/props/city_map_batch.gd")
## Kit models placed as their own scenes (scripts animate their parts).
const KIT_SCENES := ["city_gate_barricade_door", "city_gate_fence_door", "city_gate_shutter_door"]
## Small kit props: no shadows, culled beyond SMALL_RANGE.
const KIT_SMALL := ["city_hydrant", "city_debris", "city_neon_sign", "city_streetlight", "city_traffic_light",
	"city_police_barrier", "city_newsstand", "city_bus_stop", "city_market_stall"]
const SMALL_RANGE := 75.0

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
## The back street from the square's south-west to the Precinct (a second
## gate, so the Precinct is a loop, not a dead end): z 12..18.
const PRECINCT_BACK_Z := 15.0
const SUN_DIRECTION := Vector3(0.75, 0.16, 0.62)     # toward the setting sun (low, SE)
const WALL_H := 14.0
const UNDERGROUND_Y := -1.6
const GROUND_TILE := 16.0

## Every district's gates: district, position, yaw (degrees; local X spans the
## opening), opening width, style, kit model prefix, the floor heights on the
## gate's -Z and +Z sides (for the nav links).
const GATES := [
	[&"precinct", Vector3(-28.0, 0.0, 0.0), 90.0, 8.0, &"topple", "city_gate_barricade", 0.0, 0.0],
	[&"precinct", Vector3(-28.0, 0.0, PRECINCT_BACK_Z), 90.0, 6.0, &"slide", "city_gate_fence", 0.0, 0.0],
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
var _empty_cache := {}
## Kit nodes placed by _kit -> their model name.
var _kit_models := {}
var _aabb_cache := {}
var _rng := RandomNumberGenerator.new()
var _spawn_points: Array[Vector3] = []
## Ground tiles: [MeshInstance3D, base ShaderMaterial]; their lights and
## scorches are filled in at the end (nearest first).
var _tiles: Array = []
var _ground_materials := {}
## Lights mirrored in the puddles: [position, colour, streak width, intensity].
var _reflectors: Array = []
## Scorched patches: (x, radius, z).
var _scorches: Array[Vector3] = []
## Light pools: colour -> transforms, split by kind (see _pool).
var _pools := {}
## Block roofs: [Rect2, height] (for the rooftop clutter).
var _roofs: Array = []
## Merged dressing meshes by name.
var _meshes := {}


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
	_build_streets()
	_build_story()
	_build_market_glow()
	_build_metro_life()
	_build_rooftops()
	_build_ambience()
	_build_instanced()
	_build_pools()
	_finish_ground()

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
	var paving := _ground("paving", "city_sidewalk", Color(0.95, 0.9, 0.9), 4.0, 0.22)
	var asphalt := _ground("asphalt", "city_asphalt", Color(1.0, 1.0, 1.0), 8.0, 0.3)
	# Square: a slab round the subway stairs' opening (x -3..3, z -22..-16).
	_slab(ground, "SquareSlab", Rect2(-SQ, STAIR_TOP_Z, SQ * 2.0, SQ - STAIR_TOP_Z), asphalt)
	_slab(ground, "SquareSlabNW", Rect2(-SQ, -SQ, SQ - STAIR_HALF, SQ + STAIR_TOP_Z), asphalt)
	_slab(ground, "SquareSlabNE", Rect2(STAIR_HALF, -SQ, SQ - STAIR_HALF, SQ + STAIR_TOP_Z), asphalt)
	_slab(ground, "PassageW", Rect2(-34.0, -4.0, 12.0, 8.0), asphalt)
	_slab(ground, "PassageE", Rect2(SQ, -4.0, 12.0, 8.0), paving)
	_slab(ground, "PassageSW", Rect2(-34.0, PRECINCT_BACK_Z - 3.0, 12.0, 6.0), asphalt)
	_slab(ground, "PrecinctSlab", PRECINCT, asphalt)
	_slab(ground, "MarketSlab", MARKET, _ground("market_paving", "city_sidewalk", Color(0.86, 0.82, 0.95), 4.0, 0.55))
	_slab(ground, "SouthStreet", Rect2(-5.0, SQ, 10.0, 22.0), asphalt)
	_slab(ground, "TowerAlleySlab", TOWER_ALLEY, asphalt)
	# Tower plaza round the stairwell up from the metro (x 46..54, z -35..-29).
	_slab(ground, "TowerSlabN", Rect2(TOWER.position.x, TOWER.position.y, TOWER.size.x, EXIT_Z.x - TOWER.position.y), paving)
	_slab(ground, "TowerSlabS", Rect2(TOWER.position.x, EXIT_Z.y, TOWER.size.x, TOWER.end.y - EXIT_Z.y), paving)
	_slab(ground, "TowerSlabMid", Rect2(EXIT_TOP_X, EXIT_Z.x, TOWER.end.x - EXIT_TOP_X, EXIT_Z.y - EXIT_Z.x), paving)
	# The plaza paving of the square inside the ring road.
	var plaza := _ground("plaza", "city_sidewalk", Color(0.85, 0.72, 0.66), 2.5, 0.25)
	_ground_tiles("SquarePaving", Rect2(-13.0, -14.0, 26.0, 26.0), 0.06, plaza)
	_kerb_ring(dressing, "SquareKerb", Rect2(-13.0, -14.0, 26.0, 26.0))
	_kerb_ring(dressing, "SidewalkKerb", Rect2(-SQ + 2.5, -SQ + 2.5, SQ * 2.0 - 5.0, SQ * 2.0 - 5.0))
	_road_lines(dressing)


## A floor slab 1 m thick whose top is y 0, over `rect` (x, z, width, depth).
func _slab(parent: Node3D, slab_name: String, rect: Rect2, material: Material, top := 0.0) -> StaticBody3D:
	var size := Vector3(rect.size.x, 1.0, rect.size.y)
	var pos := Vector3(rect.position.x + rect.size.x * 0.5, top - 0.5, rect.position.y + rect.size.y * 0.5)
	if _ground_materials.has(material):
		_ground_tiles(slab_name, rect, top, material)
		return _collider(parent, slab_name, size, pos)
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
	_solid_kit(sq, "city_newsstand", "Newsstand", Vector3(-20.2, 0, 20.4), 90.0, Vector3(2.4, 2.6, 1.6))
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
		_burning_wreck(wreck_name, pos, yaw, size, spots)
	return node


## A wreck ablaze: a big blaze per fire spot with tongues licking along the
## body, sparks, a column of black smoke, a scorched patch and the fire's
## glow on the ground round it.
func _burning_wreck(wreck_name: String, pos: Vector3, yaw: float, size: Vector3, spots: Array[Vector3]) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var along := basis * Vector3(size.x * 0.3, 0, 0)
	var across := basis * Vector3(0, 0, size.z * 0.28)
	for k in spots.size():
		var big := (2.3 if k == 0 else 1.7) + size.x * 0.05
		_fire_at(fx, "%sFire%d" % [wreck_name, k], spots[k], big, k == 0, 3.4)
		var flip := 1.0 if k % 2 == 0 else -1.0
		_fire_at(fx, "%sFire%dTongue" % [wreck_name, k], spots[k] + along * flip + across - Vector3(0, 0.25, 0), big * 0.6, false, 0.0, true)
		_fire_at(fx, "%sFire%dLick" % [wreck_name, k], spots[k] - along * flip * 0.6 - across - Vector3(0, 0.35, 0), big * 0.45, false, 0.0, true)
	_sparks(fx, wreck_name + "Sparks", spots[0] + Vector3(0, 0.4, 0), 3.0)
	_smoke(fx, wreck_name + "Smoke", spots[0] + Vector3(0, 0.6, 0), 0.2 + size.x * 0.012)
	_scorches.append(Vector3(pos.x, size.x * 0.75 + 1.0, pos.z))


func _empty_or(node: Node3D, empty_name: String, fallback: Vector3) -> Vector3:
	var spots := _empties(node, empty_name)
	return spots[0] if not spots.is_empty() else fallback


## World positions of a kit model's empties whose names start with `prefix`.
func _empties(node: Node3D, prefix: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var spots: Dictionary = _model_empties(_kit_models.get(node, ""))
	for empty_name in spots:
		if String(empty_name).begins_with(prefix):
			out.append(node.transform * (spots[empty_name] as Vector3))
	return out


## A kit model's empties (name -> position in the model), cached.
func _model_empties(model: String) -> Dictionary:
	if _empty_cache.has(model):
		return _empty_cache[model]
	var spots := {}
	var path := MODELS + model + ".glb"
	if model != "" and ResourceLoader.exists(path):
		var source: Node3D = (load(path) as PackedScene).instantiate()
		for child in source.get_children():
			if child is Node3D and not child is MeshInstance3D:
				spots[child.name] = (child as Node3D).position
		source.free()
	_empty_cache[model] = spots
	return spots


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
	# Relief on the station's face: pilasters, cornices, a blue band.
	var trim := _surface("precinct_trim", ["city_concrete"], Color(0.78, 0.8, 0.86), 0.3, 0.85)
	var blue := _mat("precinct_band", Color(0.12, 0.22, 0.55), 0.5)
	for side in [-1.0, 1.0]:
		var zc: float = side * 13.5
		for z in [3.6, 8.5, 13.5, 18.5, 23.4]:
			_visual_box(dressing, "Pilaster%d" % int(side * z), Vector3(0.4, 15.6, 0.8), front + Vector3(0.1, 7.8, side * z), trim)
		for band in [[4.5, 0.45, trim], [10.2, 0.35, trim], [15.7, 0.6, trim], [3.9, 0.5, blue]]:
			_visual_box(dressing, "Cornice%d_%d" % [int(side), int(band[0] * 10)], Vector3(0.5, band[1], 21.0), front + Vector3(0.15, band[0], zc), band[2])


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
	mi.mesh = _slab_mesh(size, slab_name.hash())
	mi.rotation.x = deg_to_rad(tilt)
	mi.position.y = size.z * 0.5 * sin(deg_to_rad(tilt)) + size.y * 0.3
	holder.add_child(mi)
	# Broken concrete heaped round its foot.
	var foot := holder.transform * Vector3(0, 0, -size.z * 0.5 * cos(deg_to_rad(tilt)) - 0.4)
	for k in 9:
		var p := foot + holder.basis * Vector3(_rng.randf_range(-size.x * 0.55, size.x * 0.55), 0.05, _rng.randf_range(-0.9, 0.5))
		var sc := _rng.randf_range(1.2, 2.6)
		var shade := _rng.randf_range(0.45, 0.7)
		_instance("chunk", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3(sc, sc, sc)), p), Color(shade, shade * 0.96, shade * 0.92))
	var height := size.z * sin(deg_to_rad(tilt)) + size.y
	_collider(holder, "Collision", Vector3(size.x, height, size.z * cos(deg_to_rad(tilt)) + size.y * 0.5), Vector3(0, height * 0.5, 0))
	_player_block(holder, "Cap", Vector3(size.x, 3.0, size.z), Vector3(0, height + 1.5, 0))


## A slab of facade torn off a building: concrete body, the facade's windows
## on its face, rebar bent out of both broken ends (one merged mesh).
func _slab_mesh(size: Vector3, seed: int) -> Mesh:
	var key := "slab_%s_%d" % [size, absi(seed) % 3]
	if _meshes.has(key):
		return _meshes[key]
	var concrete := _surface("slab_concrete", ["city_concrete"], Color(0.62, 0.58, 0.56), 0.35, 0.9)
	var rebar := _mat("rebar", Color(0.32, 0.17, 0.1), 0.7)
	var body := BoxMesh.new()
	body.size = size
	var face := BoxMesh.new()
	face.size = Vector3(size.x - 0.2, 0.04, size.z - 0.2)
	var rod := BoxMesh.new()
	rod.size = Vector3(0.05, 0.05, 1.0)
	var parts: Array = [[body, Transform3D(), concrete], [face, Transform3D(Basis(), Vector3(0, size.y * 0.5 + 0.02, 0)), _facade_material(seed)]]
	for end in [-1.0, 1.0]:
		for k in 5:
			var x := (k - 2) * size.x * 0.2
			var bend := Basis(Vector3.UP, _rng.randf_range(-0.5, 0.5)) * Basis(Vector3.RIGHT, _rng.randf_range(-0.6, 0.4))
			var length := _rng.randf_range(0.5, 1.3)
			var tip := Vector3(x, _rng.randf_range(-0.15, 0.15), end * (size.z * 0.5 + length * 0.45))
			parts.append([rod, Transform3D(bend.scaled_local(Vector3(1, 1, length)), tip), rebar])
	var mesh := Batch.compound(parts)
	_meshes[key] = mesh
	return mesh


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


## A neon sign from the kit, or a glowing panel; its glow on the wall and the
## paving, its smear in the puddles, and maybe a coloured light below it.
func _neon_sign(parent: Node3D, model: String, sign_name: String, pos: Vector3, yaw: float, color: Color, with_light := true) -> void:
	var node := _kit(parent, model, sign_name, pos, yaw, Vector3(3.2, 1.2, 0.2))
	if not ResourceLoader.exists(MODELS + model + ".glb"):
		var panel := node.get_node("Placeholder") as MeshInstance3D
		panel.mesh = _box_mesh(Vector3(3.2, 1.2, 0.2), _mat("neon_" + color.to_html(false), color, 0.4, color, 3.0))
	node.add_to_group("city_neon_flicker", true)
	var forward := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)
	_wall_glow(pos + Vector3(0, 1.0, 0), forward, 2.8, color, 0.35)
	_pool(Vector3(pos.x, 0, pos.z) + forward * 2.6, 3.4, color, false, 0.4)
	if with_light:
		var l := _omni(fx, sign_name + "Light", pos + forward * 1.4 + Vector3(0, 2.6, 0), color, 1.4, 7.0)
		l.add_to_group("city_neon_flicker", true)
		_ambient(sign_name + "Buzz", pos + forward * 0.4 + Vector3(0, 1.0, 0), &"city_buzz_loop", 8.0)
	else:
		_reflectors.append([pos + forward * 0.4 + Vector3(0, 1.0, 0), color, 0.45, 0.65])


# ---------------------------------------------------------------------------
# Metro Line: the stairs, the platform hall, the stalled train
# ---------------------------------------------------------------------------

func _build_metro() -> void:
	var m := Node3D.new()
	m.name = "Metro"
	geo.add_child(m)
	var tiles := _ground("metro_tiles", "sky_tiles", Color(0.72, 0.78, 0.74), 2.0, 0.5)
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
	# Lit windows show the carriage behind them (city_train_window shader).
	var pane := QuadMesh.new()
	pane.size = Vector2(1.5, 0.95)
	var interior := ShaderMaterial.new()
	interior.shader = load(SHADERS + "city_train_window.gdshader")
	pane.material = interior
	var lit_windows := _multimesh("TrainWindowsLit", pane, windows_lit)
	lit_windows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(lit_windows)
	dressing.add_child(_multimesh("TrainWindowsDark", _box_mesh(Vector3(1.5, 0.95, 0.04), dark), windows_dark))
	dressing.add_child(_multimesh("TrainDoors", _box_mesh(Vector3(1.3, 2.3, 0.05), door), doors))
	_collider(parent, "Train", Vector3(length, 3.8, 3.0), centre + Vector3(0, 1.9, 0))
	_player_block(parent, "TrainCap", Vector3(length, 3.0, 3.0), centre + Vector3(0, 5.3, 0))


## Platform furniture: the station's name boards, lightbox ads, benches and
## litter, so the hall reads as a station that was busy until it was not.
func _metro_dressing(parent: Node3D) -> void:
	var wall_z := HALL.end.y - 0.02
	var board := _mat("metro_board", Color(0.08, 0.32, 0.2), 0.5)
	for x in [-16.0, 8.0, 27.5]:
		_visual_box(dressing, "NameBoard%d" % int(x), Vector3(6.0, 1.0, 0.1), Vector3(x, METRO_Y + 3.2, wall_z - 0.05), board)
		_label(dressing, "NameText%d" % int(x), "ASHFALL SQUARE", Vector3(x, METRO_Y + 3.2, wall_z - 0.11), 180.0, 64, Color(1, 1, 1))
	var ads := ["ad0", "ad1", "ad2", "ad3"]
	var k := 0
	for x in [-20.0, 0.0 + 6.5, 15.5, 27.0, 37.5]:
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
		_bench(parent, "Bench%d" % int(x), Vector3(x, METRO_Y, -28.7), 180.0)
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
const SERVICE_DOORS: Array[float] = [-12.0, 21.5, 33.0]
const SERVICE_DOOR_WIDTH := 4.0


## The hall's south wall: the opening of the stairs from the square and the
## service doors, each into a small dark room the zombies come out of.
func _hall_south_wall(parent: Node3D, material: Material) -> void:
	var z := HALL.end.y + 0.5
	var y := METRO_Y + 2.7
	var half := SERVICE_DOOR_WIDTH * 0.5
	# Wall pieces between the openings, west to east.
	var k := 0
	for s in _south_wall_spans():
		_box(parent, "WallSouth%d" % k, Vector3(s.y - s.x, 5.4, 1.0), Vector3((s.x + s.y) * 0.5, y, z), material)
		k += 1
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


## The x spans of the hall's south wall between its openings (the stairs
## from the square and the service doors), west to east.
func _south_wall_spans() -> Array[Vector2]:
	var cuts: Array[Vector2] = [Vector2(-STAIR_HALF, STAIR_HALF)]
	for x in SERVICE_DOORS:
		cuts.append(Vector2(x - SERVICE_DOOR_WIDTH * 0.5, x + SERVICE_DOOR_WIDTH * 0.5))
	cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var spans: Array[Vector2] = []
	var from := HALL.position.x - 8.0
	for c in cuts:
		spans.append(Vector2(from, c.x))
		from = c.y
	spans.append(Vector2(from, HALL.end.x))
	return spans


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
	# The tower stairs' railings too (no standing on them).
	for s in [-1.0, 1.0]:
		var rz: float = zc + s * (width * 0.5 + 0.1)
		_player_wall(walls, "TowerStair%s" % ("N" if s < 0 else "S"), Vector3(TOWER.position.x, 0, rz), Vector3(EXIT_TOP_X, 0, rz), 4.0)
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
	_box(t, "MastBase", Vector3(6.0, 1.2, 6.0), mast + Vector3(0, 0.6, 0), _surface("mast_base", ["city_concrete"], Color(0.7, 0.68, 0.66), 0.3, 0.9))
	var hazard := _surface("hazard", ["dune_hazard"], Color.WHITE, 1.0, 0.7)
	for k in 4:
		var trim := _visual_box(dressing, "MastBaseTrim%d" % k, Vector3(6.1, 0.25, 0.08), mast + Basis(Vector3.UP, k * PI * 0.5) * Vector3(0, 0.95, 3.02), hazard)
		trim.rotation.y = k * PI * 0.5
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
		["SqW_N", -34.0, -22.0, -22.0, -4.0, 14.0, "E"], ["SqW_S", -34.0, 4.0, -22.0, 12.0, 17.0, "E"],
		["SqW_SS", -34.0, 18.0, -22.0, 22.0, 15.0, "E"],
		["SqE_N", 22.0, -22.0, 34.0, -4.0, 16.0, "W"], ["SqE_SN", 22.0, 4.0, 34.0, 11.0, 13.0, "W"],
		["SqE_SS", 22.0, 15.0, 34.0, 22.0, 13.0, "W"],
		# Precinct: the station (west), north and south rows.
		["PrecinctHQ_N", -88.0, -24.0, -74.0, -3.0, 16.0, "E"], ["PrecinctHQ_S", -88.0, 3.0, -74.0, 24.0, 16.0, "E"],
		["PrecN_W", -88.0, -38.0, -56.0, -24.0, 14.0, "S"], ["PrecN_E", -52.0, -38.0, -34.0, -24.0, 18.0, "S"],
		["PrecS_W", -88.0, 24.0, -56.0, 38.0, 16.0, "N"], ["PrecS_E", -52.0, 24.0, -42.0, 38.0, 12.0, "N"],
		["PrecS_EE", -38.0, 24.0, -34.0, 38.0, 12.0, "N"],
		# Market: north row (with the tower alley and a side alley), south row.
		["MktN_W", 34.0, -22.0, 40.0, -8.0, 13.0, "S"], ["MktN_Mid", 44.0, -22.0, 62.0, -8.0, 15.0, "S"],
		["MktN_E", 70.0, -22.0, 84.0, -8.0, 12.0, "S"], ["MktN_EE", 88.0, -22.0, 98.0, -8.0, 12.0, "S"],
		["MktS_W", 34.0, 8.0, 54.0, 22.0, 14.0, "N"], ["MktS_E", 58.0, 8.0, 76.0, 22.0, 16.0, "N"], ["MktS_EE", 80.0, 8.0, 98.0, 22.0, 16.0, "N"],
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
	_roofs.append([r, height + 0.0])
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
	# Tar and gravel inside the parapet (the roofs show from the high views).
	var roof := _surface("roof_tar", ["city_asphalt"], Color(0.95, 0.85, 0.8), 0.15, 0.95)
	_visual_box(dressing, block_name + "Roof", Vector3(look_size.x - 0.2, 0.1, look_size.z - 0.2), Vector3(look_centre.x, height + 0.65, look_centre.z), roof).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		# Three bands west to east: a view culls the bands behind it.
		var band := "W" if face.x < -30.0 else ("M" if face.x < 40.0 else "E")
		var key := "%s|%s" % [band, model]
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
	return Batch.merged_model(MODELS + model + ".glb")


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
	m.set_shader_parameter("lit_fraction", 0.07)
	m.set_shader_parameter("fire_fraction", 0.035)
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
	# The leaves move on their own: each keeps its node, its surfaces merged.
	for leaf in door.find_children("*", "MeshInstance3D", true, false):
		(leaf as MeshInstance3D).mesh = Batch.compound([[(leaf as MeshInstance3D).mesh, Transform3D()]])
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
## alley's far end, the lintel over it (bottom, top; zero: open to the sky)].
## A marker stands over 1 m clear of the alley's end block and a door's back
## wall: RunDirector spreads a pack 1 m round it (tools/spawn_probe.gd).
const ENTRANCES := [
	[&"ashfall_square", Vector3(-15.5, 0, -27.5), 180.0, Rect2(-18.0, -34.0, 5.0, 12.0), 10.0, Vector2.ZERO],
	[&"ashfall_square", Vector3(15.5, 0, -27.5), 180.0, Rect2(13.0, -34.0, 5.0, 12.0), 10.0, Vector2.ZERO],
	[&"ashfall_square", Vector3(-15.5, 0, 27.5), 0.0, Rect2(-18.0, 22.0, 5.0, 12.0), 10.0, Vector2.ZERO],
	[&"ashfall_square", Vector3(15.5, 0, 27.5), 0.0, Rect2(13.0, 22.0, 5.0, 12.0), 10.0, Vector2.ZERO],
	[&"ashfall_square", Vector3(27.0, 0, 13.0), 90.0, Rect2(22.0, 11.0, 8.0, 4.0), 4.0, Vector2(4.0, 13.0)],
	[&"precinct", Vector3(-54.0, 0, -29.5), 180.0, Rect2(-56.0, -36.0, 4.0, 12.0), 10.0, Vector2.ZERO],
	[&"precinct", Vector3(-54.0, 0, 29.5), 0.0, Rect2(-56.0, 24.0, 4.0, 12.0), 10.0, Vector2.ZERO],
	[&"precinct", Vector3(-78.0, 0, 0.0), -90.0, Rect2(-82.0, -3.0, 8.0, 6.0), 10.0, Vector2(4.5, 16.0)],
	[&"precinct", Vector3(-40.0, 0, 29.5), 0.0, Rect2(-42.0, 24.0, 4.0, 12.0), 10.0, Vector2.ZERO],
	[&"market", Vector3(42.0, 0, -14.0), 180.0, Rect2(40.0, -20.0, 4.0, 12.0), 2.0, Vector2.ZERO],
	[&"market", Vector3(56.0, 0, 14.0), 0.0, Rect2(54.0, 8.0, 4.0, 12.0), 10.0, Vector2.ZERO],
	[&"market", Vector3(96.0, 0, -5.0), 90.0, Rect2(90.0, -8.0, 8.0, 16.0), 10.0, Vector2.ZERO],
	[&"market", Vector3(78.0, 0, 14.0), 0.0, Rect2(76.0, 8.0, 4.0, 12.0), 10.0, Vector2(4.0, 16.0)],
	[&"metro", Vector3(-23.5, METRO_Y, -31.5), -90.0, null, 0.0, Vector2.ZERO],
	[&"metro", Vector3(21.5, METRO_Y, -25.0), 0.0, null, 0.0, Vector2.ZERO],
	[&"metro", Vector3(-12.0, METRO_Y, -25.0), 0.0, null, 0.0, Vector2.ZERO],
	[&"metro", Vector3(33.0, METRO_Y, -25.0), 0.0, null, 0.0, Vector2.ZERO],
	[&"tower", Vector3(70.0, 0, -77.0), 180.0, Rect2(66.0, -84.0, 8.0, 12.0), 6.0, Vector2(5.0, 24.0)],
	[&"tower", Vector3(99.0, 0, -46.0), 90.0, Rect2(94.0, -50.0, 12.0, 8.0), 10.0, Vector2.ZERO],
	[&"tower", Vector3(40.0, 0, -56.0), -90.0, Rect2(34.0, -58.0, 12.0, 4.0), 10.0, Vector2.ZERO],
	[&"tower", Vector3(86.0, 0, -16.5), 0.0, Rect2(84.0, -22.0, 4.0, 10.0), 4.0, Vector2.ZERO],
]


func _build_entrances() -> void:
	var e := Node3D.new()
	e.name = "Entrances"
	geo.add_child(e)
	var asphalt := _ground("asphalt", "city_asphalt", Color(1.0, 1.0, 1.0), 8.0, 0.3)
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
		[Vector3(22.4, 0, 11), Vector3(22.4, 0, 15)], [Vector3(-42, 0, 24.4), Vector3(-38, 0, 24.4)],
		[Vector3(76, 0, 8.4), Vector3(80, 0, 8.4)], [Vector3(84, 0, -21.6), Vector3(88, 0, -21.6)],
	]
	var i := 0
	for m in mouths:
		_player_wall(walls, "Mouth%d" % i, m[0], m[1], WALL_H)
		_tape_line(m[0], m[1], i)
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
	# Searchlights on the roofs round the districts sweeping the smoke (the
	# environment script swings them).
	_searchlight("SearchlightW", Vector3(-81.0, 16.6, -14.0), 30.0, 70.0, 0.0)
	_searchlight("SearchlightS", Vector3(0.0, 20.6, 50.0), 26.0, 180.0, 2.1)
	_searchlight("SearchlightE", Vector3(90.0, 30.6, -93.0), 34.0, -20.0, 4.2)


## A searchlight's beam: a pivot at the lamp (tilted `tilt` degrees off
## vertical, facing `yaw`), swung by the environment script (meta "yaw",
## "phase").
func _searchlight(light_name: String, base: Vector3, tilt: float, yaw: float, phase: float) -> void:
	var pivot := Node3D.new()
	pivot.name = light_name
	pivot.position = base
	pivot.rotation = Vector3(deg_to_rad(tilt), deg_to_rad(yaw), 0.0)
	pivot.set_meta("yaw", deg_to_rad(yaw))
	pivot.set_meta("phase", phase)
	pivot.add_to_group("city_searchlight", true)
	pivot.add_to_group("city_surface", true)
	fx.add_child(pivot)
	var cone := CylinderMesh.new()
	cone.top_radius = 10.0
	cone.bottom_radius = 0.5
	cone.height = 130.0
	cone.radial_segments = 16
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "city_beam.gdshader")
	cone.material = m
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = cone
	beam.position.y = 65.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(beam)
	# The lamp on its stand (it stays put while the beam swings).
	var stand := _visual_box(dressing, light_name + "Stand", Vector3(0.6, 1.0, 0.6), base + Vector3(0, -0.5, 0), _mat("flood_stand", Color(0.12, 0.12, 0.13), 0.6))
	stand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lens := _visual_box(dressing, light_name + "Lens", Vector3(1.3, 0.5, 1.3), base + Vector3(0, 0.2, 0), _mat("searchlight_lens", Color(0.9, 0.95, 1.0), 0.3, Color(0.85, 0.92, 1.0), 6.0))
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The kit's drifting ash round the camera (it follows the camera itself).
func _build_ashfall() -> void:
	var scene := PROPS + "city_ashfall.tscn"
	if ResourceLoader.exists(scene):
		var ash: Node3D = (load(scene) as PackedScene).instantiate()
		ash.name = "Ashfall"
		fx.add_child(ash)


# ---------------------------------------------------------------------------
# Ambience: positional sound emitters, the police helicopter, the Broadcast
# Tower's aircraft-warning lights (the environment script runs them all)
# ---------------------------------------------------------------------------

## A positional ambient loop (Marker3D in group "city_ambient"): the
## environment script plays the nearest few, `sound` heard out to `reach`
## metres, `db` louder or quieter than its mix.
func _ambient(emitter_name: String, pos: Vector3, sound: StringName, reach: float, db := 0.0) -> void:
	var holder := fx.get_node_or_null("Ambience") as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = "Ambience"
		fx.add_child(holder)
	var m := Marker3D.new()
	m.name = emitter_name
	m.position = pos
	m.set_meta("sound", sound)
	m.set_meta("reach", reach)
	m.set_meta("db", db)
	m.add_to_group("city_ambient", true)
	holder.add_child(m)


func _build_ambience() -> void:
	# Sirens wailing over the Precinct and beyond the tower, police radios
	# left on in the vans, a shop alarm in the Market, drips in the Metro.
	_ambient("SirenPrecinct", Vector3(-84.0, 18.0, -12.0), &"city_siren_loop", 75.0, -3.0)
	_ambient("SirenTower", Vector3(104.0, 26.0, -84.0), &"city_siren_loop", 70.0, -5.0)
	for v in [Vector3(-46.0, 1.6, -12.0), Vector3(-61.0, 1.6, 14.0), Vector3(8.5, 1.6, 16.4), Vector3(62.0, 1.6, -27.5)]:
		_ambient("Radio%d" % int(v.x), v, &"city_radio_loop", 13.0)
	_ambient("AlarmMarket", Vector3(66.0, 3.2, 8.3), &"city_alarm_loop", 26.0)
	_ambient("AlarmSquare", Vector3(-21.8, 3.0, -12.0), &"city_alarm_loop", 18.0, -4.0)
	for x in [-14.0, 6.0, 30.0]:
		_ambient("Drip%d" % int(x), Vector3(x, METRO_Y + 2.0, -34.0), &"city_drip_loop", 16.0)
	_ambient("TubeBuzz", Vector3(9.0, HALL_CEILING - 0.8, -34.5), &"city_buzz_loop", 9.0, 2.0)
	_build_helicopter()
	_build_warning_lights()


## The police helicopter circling the city (group "city_helicopter"; the
## environment script flies it round meta "centre" at "radius", "speed"
## rad/s): a dark body, a rotor, blinking navigation lights and a searchlight
## sweeping the streets (hidden underground, like the skyline).
func _build_helicopter() -> void:
	var heli := Node3D.new()
	heli.name = "Helicopter"
	var centre := Vector3(14.0, 44.0, -26.0)
	heli.position = centre + Vector3(80.0, 0, 0)
	heli.set_meta("centre", centre)
	heli.set_meta("radius", 80.0)
	heli.set_meta("speed", 0.055)
	heli.add_to_group("city_helicopter", true)
	heli.add_to_group("city_surface", true)
	fx.add_child(heli)
	var body := _mat("heli_body", Color(0.16, 0.18, 0.24), 0.45)
	var stripe := _mat("heli_stripe", Color(0.9, 0.9, 0.95), 0.4)
	var glass := _mat("heli_glass", Color(0.5, 0.75, 1.0), 0.2, Color(0.4, 0.65, 1.0), 0.8)
	var parts := [
		[_box_mesh(Vector3(2.0, 1.8, 4.4), body), Transform3D(Basis(), Vector3(0, 0, 0))],
		[_box_mesh(Vector3(1.7, 1.1, 1.4), glass), Transform3D(Basis(), Vector3(0, 0.15, -2.4))],
		[_box_mesh(Vector3(2.05, 0.3, 4.0), stripe), Transform3D(Basis(), Vector3(0, -0.2, 0.1))],
		[_box_mesh(Vector3(0.45, 0.5, 4.6), body), Transform3D(Basis(), Vector3(0, 0.4, 4.4))],
		[_box_mesh(Vector3(0.15, 1.5, 0.9), body), Transform3D(Basis(), Vector3(0, 1.0, 6.5))],
		[_box_mesh(Vector3(0.12, 0.12, 3.6), body), Transform3D(Basis(), Vector3(-0.9, -1.2, 0))],
		[_box_mesh(Vector3(0.12, 0.12, 3.6), body), Transform3D(Basis(), Vector3(0.9, -1.2, 0))],
	]
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = Batch.compound(parts)
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	heli.add_child(hull)
	var rotor := MeshInstance3D.new()
	rotor.name = "Rotor"
	var blade := _box_mesh(Vector3(10.0, 0.06, 0.32), _mat("heli_blade", Color(0.1, 0.1, 0.12), 0.5))
	rotor.mesh = Batch.compound([[blade, Transform3D()], [blade, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)]])
	rotor.position = Vector3(0, 1.1, 0)
	rotor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	heli.add_child(rotor)
	# Navigation lights: red port, green starboard, a white strobe on the tail.
	var lights := [[Vector3(-1.1, -0.3, 0), Color(1.0, 0.1, 0.1)], [Vector3(1.1, -0.3, 0), Color(0.1, 1.0, 0.3)],
		[Vector3(0, 1.8, 6.6), Color(1.0, 1.0, 1.0)]]
	var k := 0
	for l in lights:
		var c: Color = l[1]
		var lamp := _visual_box(heli, "NavLight%d" % k, Vector3(0.3, 0.3, 0.3), l[0], _mat("nav_" + c.to_html(false), c, 0.3, c, 8.0))
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if k == 2:
			lamp.add_to_group("city_beacon", true)
		k += 1
	# The searchlight: a cone from under the nose, down and ahead.
	var pivot := Node3D.new()
	pivot.name = "Beam"
	pivot.position = Vector3(0, -1.0, -2.0)
	heli.add_child(pivot)
	var aim := Node3D.new()
	aim.name = "Aim"
	aim.rotation = Vector3(deg_to_rad(155.0), 0, 0)
	pivot.add_child(aim)
	var cone := CylinderMesh.new()
	cone.top_radius = 5.5
	cone.bottom_radius = 0.35
	cone.height = 56.0
	cone.radial_segments = 16
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "city_beam.gdshader")
	m.set_shader_parameter("strength", 0.5)
	m.set_shader_parameter("beam_color", Color(0.85, 0.92, 1.0))
	cone.material = m
	var beam := MeshInstance3D.new()
	beam.name = "Cone"
	beam.mesh = cone
	beam.position.y = 28.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim.add_child(beam)


## Aircraft-warning lamps on the roof corners round the Broadcast Tower and
## on the skyscraper (one MultiMesh, blinking with the mast's beacon).
func _build_warning_lights() -> void:
	var xforms: Array[Transform3D] = []
	for roof in _roofs:
		var r: Rect2 = roof[0]
		var h: float = roof[1]
		if r.get_center().x < 34.0 or r.get_center().y > -8.0 or h < 12.0:
			continue
		for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			xforms.append(Transform3D(Basis(), Vector3(corner.x, h + 1.0, corner.y)))
	var red := Color(1.0, 0.08, 0.05)
	var lamps := _multimesh("WarningLights", _box_mesh(Vector3(0.45, 0.45, 0.45), _mat("warning_lamp", red, 0.3, red, 12.0)), xforms)
	lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamps.add_to_group("city_beacon", true)
	fx.add_child(lamps)


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
			AABB(Vector3(-28.0, -0.5, -4.0), Vector3(6.0, 14.0, 8.0)), AABB(Vector3(SQ, -0.5, -4.0), Vector3(6.0, 14.0, 8.0)),
			AABB(Vector3(-28.0, -0.5, PRECINCT_BACK_Z - 3.0), Vector3(6.0, 14.0, 6.0))],
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
		# Upgrade benches: the bench's front (where the player stands) faces
		# the marker's +Z; about 2.6 x 1.2 m, 2 m clear in front.
		[&"upgrade_bench", &"ashfall_square", Vector3(7.5, 0, 7.0), 0.0],
		[&"upgrade_bench", &"tower", Vector3(48.0, 0, -46.0), 90.0],
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
# Wet streets: the city_ground shader in tiles, each mirroring and lit by the
# lights nearest it (a tile is one object: the renderer lights an object with
# its first few lights only)
# ---------------------------------------------------------------------------

func _ground(key: String, texture: String, tint: Color, tile_metres: float, puddles: float) -> ShaderMaterial:
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.resource_name = key
	m.shader = load(SHADERS + "city_ground.gdshader")
	m.set_shader_parameter("albedo_tex", load(TEXTURES + texture + ".png"))
	var normal_path := TEXTURES + texture + "_normal.png"
	if ResourceLoader.exists(normal_path):
		m.set_shader_parameter("normal_tex", load(normal_path))
	m.set_shader_parameter("puddle_tex", load(TEXTURES + "neon_puddles.png"))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("tile_metres", tile_metres)
	m.set_shader_parameter("puddle_amount", puddles)
	_materials[key] = m
	_ground_materials[m] = true
	return m


## Visual floor tiles (1 m thick, top at `top`) over `rect`.
func _ground_tiles(tiles_name: String, rect: Rect2, top: float, material: ShaderMaterial) -> void:
	var nx := maxi(1, ceili(rect.size.x / GROUND_TILE))
	var nz := maxi(1, ceili(rect.size.y / GROUND_TILE))
	var sx := rect.size.x / nx
	var sz := rect.size.y / nz
	var mesh := _box_mesh(Vector3(sx, 1.0, sz), material)
	for i in nx:
		for j in nz:
			var mi := MeshInstance3D.new()
			mi.name = "%sTile%d_%d" % [tiles_name, i, j]
			mi.mesh = mesh
			mi.position = Vector3(rect.position.x + sx * (i + 0.5), top - 0.5, rect.position.y + sz * (j + 0.5))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dressing.add_child(mi)
			_tiles.append([mi, material])


## Gives every ground tile its own copy of its material holding the lights
## and scorched patches nearest it.
func _finish_ground() -> void:
	for entry in _tiles:
		var mi: MeshInstance3D = entry[0]
		var centre := mi.position + Vector3(0, 0.5, 0)
		var below := centre.y < UNDERGROUND_Y
		var near: Array = []
		for r in _reflectors:
			var p: Vector3 = r[0]
			if (p.y < UNDERGROUND_Y) != below:
				continue
			var d := Vector2(p.x - centre.x, p.z - centre.z).length()
			if d < 34.0:
				near.append([d, r])
		near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var pos := PackedVector4Array()
		var col := PackedVector4Array()
		for k in 12:
			if k < near.size():
				var r: Array = near[k][1]
				var p: Vector3 = r[0]
				var c: Color = r[1]
				pos.append(Vector4(p.x, p.y, p.z, r[2]))
				col.append(Vector4(c.r, c.g, c.b, r[3]))
			else:
				pos.append(Vector4.ZERO)
				col.append(Vector4.ZERO)
		var burns := PackedVector3Array()
		for s in _scorches:
			if burns.size() < 4 and not below and Vector2(s.x - centre.x, s.z - centre.z).length() < GROUND_TILE + s.y:
				burns.append(s)
		burns.resize(4)
		var m := (entry[1] as ShaderMaterial).duplicate() as ShaderMaterial
		m.set_shader_parameter("light_pos", pos)
		m.set_shader_parameter("light_col", col)
		m.set_shader_parameter("scorch", burns)
		mi.material_override = m


# ---------------------------------------------------------------------------
# Light pools: additive glow cards on floors and walls (one MultiMesh per kind)
# ---------------------------------------------------------------------------

## A pool of light on the floor at `pos`, `radius` metres; fire pools waver.
func _pool(pos: Vector3, radius: float, color: Color, fire := false, strength := 0.5) -> void:
	_pool_xform(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3.ONE * radius), pos + Vector3(0, 0.09, 0)), color, fire, strength)


## A glow on a wall: `normal` is the direction the wall faces.
func _wall_glow(pos: Vector3, normal: Vector3, radius: float, color: Color, strength := 0.4) -> void:
	var basis := Basis.looking_at(-normal, Vector3.UP)
	_pool_xform(Transform3D(basis.scaled_local(Vector3(radius, radius * 0.8, 1.0)), pos + normal * 0.06), color, false, strength)


func _pool_xform(xf: Transform3D, color: Color, fire: bool, strength: float) -> void:
	var key := ("fire" if fire else "steady") + ("Metro" if xf.origin.y < UNDERGROUND_Y else "")
	if not _pools.has(key):
		_pools[key] = [[], []]
	_pools[key][0].append(xf)
	_pools[key][1].append(Color(color.r, color.g, color.b, clampf(strength, 0.0, 1.0)))


func _build_pools() -> void:
	for key in _pools:
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)
		var m := ShaderMaterial.new()
		m.shader = load(SHADERS + "city_pool.gdshader")
		m.set_shader_parameter("use_instance_color", true)
		m.set_shader_parameter("strength", 1.1)
		m.set_shader_parameter("flicker", 1.0 if String(key).begins_with("fire") else 0.0)
		quad.material = m
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = quad
		var xforms: Array = _pools[key][0]
		mm.instance_count = xforms.size()
		for k in xforms.size():
			mm.set_instance_transform(k, xforms[k])
			mm.set_instance_color(k, _pools[key][1][k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "LightPools_" + key
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not String(key).ends_with("Metro"):
			mmi.add_to_group("city_surface", true)
		fx.add_child(mmi)


func _sparks(parent: Node3D, sparks_name: String, pos: Vector3, interval: float) -> void:
	var scene := PROPS + "city_sparks.tscn"
	if not ResourceLoader.exists(scene):
		return
	var s: Node3D = (load(scene) as PackedScene).instantiate()
	s.name = sparks_name
	parent.add_child(s)
	s.position = pos
	s.set("interval", interval)
	_ambient(sparks_name + "Hum", pos, &"city_sparks_loop", 12.0, -3.0)


# ---------------------------------------------------------------------------
# Instanced dressing: small repeated things (litter, tape, sandbags, cables,
# neon tubes) collected by kind and drawn as one MultiMesh each
# ---------------------------------------------------------------------------

## Kind -> [mesh, transforms, colours (or empty), shadows].
var _instanced := {}


func _instance(kind: String, xf: Transform3D, color := Color.WHITE) -> void:
	# Anything below the street (the hall's ceiling included) belongs to the Metro.
	var key := kind + ("Metro" if xf.origin.y < -0.2 else "")
	if not _instanced.has(key):
		_instanced[key] = [kind, [], []]
	_instanced[key][1].append(xf)
	_instanced[key][2].append(color)


func _build_instanced() -> void:
	for key in _instanced:
		var kind: String = _instanced[key][0]
		var mesh := _instance_mesh(kind)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		var xforms: Array = _instanced[key][1]
		mm.instance_count = xforms.size()
		for k in xforms.size():
			mm.set_instance_transform(k, xforms[k])
			mm.set_instance_color(k, _instanced[key][2][k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Dressing_" + String(key)
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind in ["sandbag", "tank", "ac"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not String(key).ends_with("Metro"):
			mmi.add_to_group("city_surface", true)
		dressing.add_child(mmi)


## A colour-by-instance material (the MultiMesh colour is the albedo).
func _tinted(key: String, roughness: float, emission := 0.0, texture := "", tile := 1.0) -> StandardMaterial3D:
	if _materials.has("tinted_" + key):
		return _materials["tinted_" + key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = roughness
	if texture != "":
		m.albedo_texture = load(TEXTURES + texture + ".png")
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE / tile
	if emission > 0.0:
		# Glowing tubes: unshaded and over-bright so the bloom catches them.
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(emission, emission, emission)
	_materials["tinted_" + key] = m
	return m


func _instance_mesh(kind: String) -> Mesh:
	match kind:
		"paper":
			var q := PlaneMesh.new()
			q.size = Vector2(0.3, 0.4)
			var m := _tinted("paper", 0.95)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			q.material = m
			return q
		"chunk":
			var b := BoxMesh.new()
			b.size = Vector3(0.32, 0.14, 0.22)
			b.material = _tinted("chunk", 0.9, 0.0, "city_grime", 1.5)
			return b
		"tape":
			var t := BoxMesh.new()
			t.size = Vector3(1.0, 0.09, 0.012)
			t.material = _tinted("tape", 0.6, 1.25)
			return t
		"cable":
			var c := BoxMesh.new()
			c.size = Vector3(0.035, 0.035, 1.0)
			c.material = _tinted("cable", 0.8)
			return c
		"sandbag":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 10
			s.rings = 5
			s.material = _tinted("sandbag", 0.95, 0.0, "city_grime", 1.0)
			return s
		"bag":
			var s := SphereMesh.new()
			s.radius = 0.35
			s.height = 0.5
			s.radial_segments = 8
			s.rings = 4
			s.material = _tinted("bag", 0.55)
			return s
		"bin":
			var c := CylinderMesh.new()
			c.top_radius = 0.32
			c.bottom_radius = 0.28
			c.height = 0.9
			c.radial_segments = 10
			c.material = _tinted("bin", 0.6, 0.0, "city_grime", 1.0)
			return c
		"manhole":
			var c := CylinderMesh.new()
			c.top_radius = 0.48
			c.bottom_radius = 0.5
			c.height = 0.05
			c.radial_segments = 16
			c.material = _tinted("manhole", 0.5, 0.0, "city_grime", 0.6)
			return c
		"paint":
			var q := PlaneMesh.new()
			q.size = Vector2(1.0, 1.0)
			q.material = _tinted("paint", 0.85, 0.0, "city_grime", 1.2)
			return q
		"tube":
			var b := BoxMesh.new()
			b.size = Vector3(1.0, 0.07, 0.07)
			b.material = _tinted("tube", 0.4, 3.2)
			return b
		"panel":
			var b := BoxMesh.new()
			b.size = Vector3(1.9, 0.05, 0.95)
			b.material = _tinted("panel", 0.8, 0.0, "city_grime", 1.0)
			return b
		"tank":
			return _tank_mesh()
		"ac":
			return _ac_mesh()
		"antenna":
			return _antenna_mesh()
	return BoxMesh.new()


## A rooftop water tank on legs (merged primitives).
func _tank_mesh() -> Mesh:
	var wood := _mat("tank_wood", Color(0.42, 0.27, 0.2), 0.9)
	var steel := _mat("tank_steel", Color(0.16, 0.15, 0.17), 0.6)
	var body := CylinderMesh.new()
	body.top_radius = 1.3
	body.bottom_radius = 1.3
	body.height = 2.4
	body.radial_segments = 14
	var roof := CylinderMesh.new()
	roof.top_radius = 0.05
	roof.bottom_radius = 1.45
	roof.height = 0.8
	roof.radial_segments = 14
	var band := CylinderMesh.new()
	band.top_radius = 1.33
	band.bottom_radius = 1.33
	band.height = 0.08
	band.radial_segments = 14
	var leg := BoxMesh.new()
	leg.size = Vector3(0.16, 2.2, 0.16)
	var parts: Array = [[body, Transform3D(Basis(), Vector3(0, 3.4, 0)), wood], [roof, Transform3D(Basis(), Vector3(0, 5.0, 0)), steel]]
	for y in [2.6, 3.4, 4.2]:
		parts.append([band, Transform3D(Basis(), Vector3(0, y, 0)), steel])
	for a in 4:
		var d := Vector3(cos(a * PI * 0.5 + 0.78), 0, sin(a * PI * 0.5 + 0.78)) * 0.95
		parts.append([leg, Transform3D(Basis(), d + Vector3(0, 1.1, 0)), steel])
	return Batch.compound(parts)


## A rooftop air conditioner with its fan.
func _ac_mesh() -> Mesh:
	var body := BoxMesh.new()
	body.size = Vector3(1.4, 0.9, 1.0)
	var fan := CylinderMesh.new()
	fan.top_radius = 0.34
	fan.bottom_radius = 0.34
	fan.height = 0.06
	fan.radial_segments = 12
	return Batch.compound([[body, Transform3D(Basis(), Vector3(0, 0.45, 0)), _mat("ac_body", Color(0.62, 0.62, 0.6), 0.6)],
		[fan, Transform3D(Basis(), Vector3(0.3, 0.92, 0)), _mat("ac_fan", Color(0.1, 0.1, 0.11), 0.7)],
		[fan, Transform3D(Basis(), Vector3(-0.32, 0.92, 0)), _mat("ac_fan", Color(0.1, 0.1, 0.11), 0.7)]])


## A thin antenna mast with cross bars and a red tip.
func _antenna_mesh() -> Mesh:
	var steel := _mat("tank_steel", Color(0.16, 0.15, 0.17), 0.6)
	var mast := BoxMesh.new()
	mast.size = Vector3(0.1, 6.0, 0.1)
	var bar := BoxMesh.new()
	bar.size = Vector3(1.6, 0.06, 0.06)
	var tip := BoxMesh.new()
	tip.size = Vector3(0.22, 0.22, 0.22)
	return Batch.compound([[mast, Transform3D(Basis(), Vector3(0, 3.0, 0)), steel], [bar, Transform3D(Basis(), Vector3(0, 4.6, 0)), steel],
		[bar, Transform3D(Basis(Vector3.UP, 1.2), Vector3(0, 5.3, 0)), steel],
		[tip, Transform3D(Basis(), Vector3(0, 6.05, 0)), _mat("antenna_tip", Color(1.0, 0.15, 0.1), 0.4, Color(1.0, 0.1, 0.05), 5.0)]])


## A sagging cable from `a` to `b`, `sag` metres at the middle.
func _cable(a: Vector3, b: Vector3, sag: float, segments := 10) -> void:
	for i in segments:
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		var p := a.lerp(b, t0) - Vector3(0, sag * sin(PI * t0), 0)
		var q := a.lerp(b, t1) - Vector3(0, sag * sin(PI * t1), 0)
		var seg := q - p
		_instance("cable", Transform3D(Basis.looking_at(seg.normalized(), Vector3.UP if absf(seg.normalized().y) < 0.98 else Vector3.RIGHT).scaled_local(Vector3(1, 1, seg.length() + 0.02)), (p + q) * 0.5), Color(0.06, 0.055, 0.06))


## Police tape across an opening (a, b at ground): two lines that sag, the
## lower one torn and hanging from both ends where the zombies broke through.
func _tape_line(a: Vector3, b: Vector3, seed: int) -> void:
	var yellow := Color(1.0, 0.8, 0.08)
	var dark := Color(0.08, 0.07, 0.05)
	var torn := seed % 3 != 2
	for line in 2:
		var h := 1.05 - line * 0.32 + (seed % 2) * 0.06
		var pa := a + Vector3(0, h, 0)
		var pb := b + Vector3(0, h + 0.08 * ((seed + line) % 2), 0)
		var pieces: Array = [[pa, pb, 0.18]]
		if torn and line == 1:
			var cut := 0.35 + 0.1 * (seed % 3)
			pieces = [[pa, pa.lerp(pb, cut) - Vector3(0, 0.7, 0), 0.05], [pb, pa.lerp(pb, cut + 0.12) - Vector3(0, 0.85, 0), 0.05]]
		for piece in pieces:
			var p0: Vector3 = piece[0]
			var p1: Vector3 = piece[1]
			var n := maxi(2, int(p0.distance_to(p1) / 0.6))
			for i in n:
				var t0 := float(i) / n
				var t1 := float(i + 1) / n
				var sag: float = piece[2]
				var q0 := p0.lerp(p1, t0) - Vector3(0, sag * sin(PI * t0), 0)
				var q1 := p0.lerp(p1, t1) - Vector3(0, sag * sin(PI * t1), 0)
				var seg := q1 - q0
				var x := seg.normalized()
				var z := x.cross(Vector3.UP).normalized()
				if z.length() < 0.1:
					z = Vector3.FORWARD
				var basis := Basis(x * seg.length(), z.cross(x).normalized(), z)
				_instance("tape", Transform3D(basis, (q0 + q1) * 0.5), yellow if (i + line) % 2 == 0 else dark)


## A wall of sandbags from `a` to `b` (ground), `rows` high, staggered.
func _sandbags(a: Vector3, b: Vector3, rows: int) -> void:
	var dir := (b - a).normalized()
	var yaw := atan2(-dir.z, dir.x)
	var length := a.distance_to(b)
	for row in rows:
		var n := int(length / 0.78)
		for i in n:
			var t := (i + 0.5 + (0.5 if row % 2 == 1 else 0.0)) * 0.78
			if t > length - 0.3:
				continue
			var p := a + dir * t + Vector3(0, 0.13 + row * 0.23, 0)
			var basis := Basis(Vector3.UP, yaw + _rng.randf_range(-0.12, 0.12)) * Basis(Vector3.RIGHT, _rng.randf_range(-0.08, 0.08))
			basis = basis.scaled_local(Vector3(0.8, 0.27, 0.46))
			var shade := _rng.randf_range(0.85, 1.05)
			_instance("sandbag", Transform3D(basis, p), Color(0.72 * shade, 0.62 * shade, 0.44 * shade))


## Litter strewn over `rect` at floor height `y`: paper and chunks of concrete.
func _litter(rect: Rect2, y: float, papers: int, chunks: int) -> void:
	var paper_tints := [Color(0.92, 0.9, 0.82), Color(0.8, 0.78, 0.72), Color(0.95, 0.75, 0.8), Color(0.75, 0.86, 0.95), Color(0.98, 0.92, 0.6)]
	for i in papers:
		var p := Vector3(_rng.randf_range(rect.position.x, rect.end.x), y + 0.035, _rng.randf_range(rect.position.y, rect.end.y))
		if _over_hole(p):
			continue
		var basis := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.15, 0.15))
		_instance("paper", Transform3D(basis, p), paper_tints[_rng.randi() % paper_tints.size()])
	for i in chunks:
		var p := Vector3(_rng.randf_range(rect.position.x, rect.end.x), y + 0.05, _rng.randf_range(rect.position.y, rect.end.y))
		if _over_hole(p):
			continue
		var basis := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.3, 0.3))
		var s := _rng.randf_range(0.5, 1.2)
		var shade := _rng.randf_range(0.35, 0.75)
		var c := Color(shade, shade * 0.95, shade * 0.92) if _rng.randf() < 0.7 else Color(0.62, 0.3, 0.22)
		_instance("chunk", Transform3D(basis.scaled_local(Vector3(s, s * 0.8, s)), p), c)


## True over the stairwells' openings in the street (nothing to lie on).
func _over_hole(p: Vector3) -> bool:
	if p.y < UNDERGROUND_Y:
		return false
	var holes := [Rect2(-STAIR_HALF - 0.6, -SQ - 0.6, STAIR_HALF * 2.0 + 1.2, SQ + STAIR_TOP_Z + 1.2),
		Rect2(TOWER.position.x - 0.6, EXIT_Z.x - 0.6, EXIT_TOP_X - TOWER.position.x + 1.2, EXIT_Z.y - EXIT_Z.x + 1.2)]
	for h in holes:
		if (h as Rect2).has_point(Vector2(p.x, p.z)):
			return true
	return false


## Bins and bin bags along a wall from `a` to `b` (some bins knocked over).
func _bins(a: Vector3, b: Vector3, count: int) -> void:
	for i in count:
		var p := a.lerp(b, (i + 0.5) / count + _rng.randf_range(-0.08, 0.08))
		if _rng.randf() < 0.45:
			var basis := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.FORWARD, PI * 0.5)
			_instance("bin", Transform3D(basis, p + Vector3(0, 0.3, 0)), Color(0.2, 0.36, 0.26))
		else:
			_instance("bin", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), p + Vector3(0, 0.45, 0)), Color(0.22, 0.4, 0.3))
		for k in 2:
			var q := p + Vector3(_rng.randf_range(-0.8, 0.8), 0.18, _rng.randf_range(-0.8, 0.8))
			var bag_tint := Color(0.08, 0.09, 0.1) if _rng.randf() < 0.6 else Color(0.15, 0.24, 0.16)
			_instance("bag", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), q), bag_tint)


## A manhole cover; `steam` puts a lazy plume of steam over it.
func _manhole(pos: Vector3, steam: bool) -> void:
	_instance("manhole", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), pos + Vector3(0, 0.03, 0)), Color(0.32, 0.3, 0.3))
	if steam:
		_steam(pos, Color(0.85, 0.72, 0.68), 0.32)


func _steam(pos: Vector3, color: Color, strength: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 6.0)
	quad.center_offset = Vector3(0, 3.0, 0)
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "neon_steam.gdshader")
	m.set_shader_parameter("steam_color", color)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("speed", 0.35)
	m.set_shader_parameter("time_offset", pos.x * 0.37 + pos.z * 0.11)
	for k in 2:
		var q := MeshInstance3D.new()
		q.name = "Steam%d_%d_%d" % [int(pos.x), int(pos.z), k]
		q.mesh = quad
		q.material_override = m
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.position = pos
		q.rotation.y = k * PI * 0.5 + 0.5
		fx.add_child(q)


## A crosswalk: `count` white bars across the road at `centre`, bars along `yaw`.
func _crosswalk(centre: Vector3, yaw: float, count: int) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	for i in count:
		var off := basis * Vector3((i - (count - 1) * 0.5) * 0.9, 0, 0)
		var worn := _rng.randf_range(0.38, 0.6)
		_instance("paint", Transform3D(basis.scaled_local(Vector3(0.5, 1.0, 3.2)), centre + off + Vector3(0, 0.025, 0)), Color(worn, worn * 0.96, worn * 0.9))


## Graffiti and stencils on a wall: `normal` is the way the wall faces.
func _graffiti(text: String, pos: Vector3, normal: Vector3, color: Color, font_size := 96) -> void:
	var yaw := rad_to_deg(atan2(normal.x, normal.z))
	var l := _label(dressing, "Graffiti_%s_%d" % [text.validate_node_name().replace(" ", ""), int(pos.x * 10 + pos.z)], text, pos + normal * 0.05, yaw, font_size, color)
	l.outline_size = 6
	l.outline_modulate = color.darkened(0.75)
	l.rotation.z = deg_to_rad(_rng.randf_range(-6.0, 6.0))
	l.shaded = true


# ---------------------------------------------------------------------------
# Set dressing: every district's story, street furniture, rooftops
# ---------------------------------------------------------------------------

func _build_streets() -> void:
	# Ashfall Square: crossings over the ring road, manholes (two steaming).
	for c in [[Vector3(-8.5, 0, -16.5), 90.0], [Vector3(0, 0, 16.5), 90.0], [Vector3(-16.5, 0, 0), 0.0], [Vector3(16.5, 0, 0), 0.0]]:
		_crosswalk(c[0], c[1], 7)
	for c in [[Vector3(-46.0, 0, 0.5), 0.0], [Vector3(-30.0, 0, 0.0), 0.0]]:
		_crosswalk(c[0], c[1], 6)
	# The Precinct's car park: bay lines under the riot vans.
	for row in [-14.0, 14.0]:
		for k in 12:
			var x := -71.0 + k * 3.0
			if x > -63.0 and x < -55.0:
				continue
			_instance("paint", Transform3D(Basis().scaled_local(Vector3(0.14, 1.0, 5.0)), Vector3(x, 0.025, row)), Color(0.55, 0.52, 0.45))
	_manhole(Vector3(-10.5, 0, -16.2), true)
	_manhole(Vector3(10.0, 0, 16.0), true)
	_manhole(Vector3(-16.0, 0, 4.0), false)
	_manhole(Vector3(-56.0, 0, -9.0), true)
	_manhole(Vector3(-44.0, 0, 15.5), false)
	_manhole(Vector3(70.0, 0, -36.0), true)
	_manhole(Vector3(88.0, 0, -66.0), false)
	# Litter everywhere people ran.
	_litter(Rect2(-21.0, -21.0, 42.0, 42.0), 0.0, 150, 70)
	_litter(Rect2(-72.0, -22.0, 36.0, 44.0), 0.0, 110, 60)
	_litter(Rect2(35.0, -7.5, 54.0, 15.0), 0.0, 120, 40)
	_litter(Rect2(47.0, -71.0, 46.0, 48.0), 0.0, 90, 90)
	_litter(Rect2(-24.0, -37.5, 63.0, 9.0), METRO_Y, 90, 30)
	_litter(Rect2(-32.0, -3.5, 12.0, 7.0), 0.0, 20, 10)
	# Bins and bags against the facades.
	_bins(Vector3(-21.2, 0, -12.0), Vector3(-21.2, 0, -6.0), 2)
	_bins(Vector3(21.2, 0, 5.5), Vector3(21.2, 0, 9.5), 2)
	_bins(Vector3(-36.0, 0, -23.2), Vector3(-30.0, 0, -23.2), 2)
	_bins(Vector3(-73.0, 0, -14.0), Vector3(-73.0, 0, -8.0), 2)
	_bins(Vector3(36.0, 0, 7.2), Vector3(44.0, 0, 7.2), 2)
	_bins(Vector3(74.0, 0, -7.2), Vector3(84.0, 0, -7.2), 3)
	_bins(Vector3(47.0, 0, -70.0), Vector3(47.0, 0, -64.0), 2)
	_bins(Vector3(93.0, 0, -30.0), Vector3(93.0, 0, -24.0), 2)
	# Cables strung over the streets, a few snapped and sparking.
	for x in [-14.0, -2.0, 9.0]:
		_cable(Vector3(x, 9.5, -22.0), Vector3(x + 3.0, 8.8, 22.0), 2.2, 16)
	_cable(Vector3(-22.0, 10.0, -8.0), Vector3(22.0, 9.0, -12.0), 2.6, 16)
	_cable(Vector3(-34.0, 9.0, -14.0), Vector3(-34.0, 9.5, 14.0), 1.8, 12)
	for z in [-15.0, 6.0]:
		_cable(Vector3(-74.0, 8.5, z), Vector3(-34.0, 9.0, z + 4.0), 2.4, 16)
	_cable(Vector3(46.0, 11.0, -40.0), Vector3(94.0, 10.0, -44.0), 3.0, 18)
	_cable(Vector3(46.0, 10.0, -62.0), Vector3(94.0, 11.0, -58.0), 2.8, 18)
	_cable(Vector3(60.0, 12.0, -72.0), Vector3(62.0, 9.0, -22.0), 3.2, 18)
	# A snapped line hanging off a facade, spitting sparks.
	_cable(Vector3(22.0, 8.0, -14.0), Vector3(20.5, 2.6, -14.6), 0.4, 8)
	_sparks(fx, "SnappedSquare", Vector3(20.5, 2.6, -14.6), 1.8)
	_cable(Vector3(-34.0, 9.0, 21.0), Vector3(-35.4, 3.2, 20.4), 0.3, 8)
	_sparks(fx, "SnappedPrecinct", Vector3(-35.4, 3.2, 20.4), 2.2)
	_cable(Vector3(94.0, 9.0, -55.0), Vector3(92.0, 2.8, -55.5), 0.4, 8)
	_sparks(fx, "SnappedTower", Vector3(92.0, 2.8, -55.5), 2.0)


## The abandoned checkpoint in the street to the Precinct, the station's last
## stand (sandbags, tape, floodlights), the cars that ran into storefronts.
func _build_story() -> void:
	# Checkpoint: sandbags along both walls of the barricaded street, a raised
	# boom, floodlights still burning.
	_sandbags(Vector3(-33.6, 0, -3.55), Vector3(-29.5, 0, -3.55), 3)
	_sandbags(Vector3(-33.6, 0, 3.55), Vector3(-29.5, 0, 3.55), 3)
	_sandbags(Vector3(-26.5, 0, -3.55), Vector3(-22.4, 0, -3.55), 2)
	_sandbags(Vector3(-26.5, 0, 3.55), Vector3(-22.4, 0, 3.55), 2)
	_boom_barrier(Vector3(-24.0, 0, 3.4))
	_floodlight("CheckpointFlood", Vector3(-33.0, 0, -3.0), Vector3(-26.0, 0, 0.5))
	_graffiti("CHECKPOINT 4", Vector3(-30.5, 3.2, -4.0), Vector3(0, 0, 1), Color(0.95, 0.95, 0.9), 80)
	_graffiti("NO ENTRY", Vector3(-30.5, 3.2, 4.0), Vector3(0, 0, -1), Color(1.0, 0.3, 0.25), 90)
	# The station front: sandbags under the windows, floodlights on the steps,
	# tape round the bays.
	_sandbags(Vector3(-73.5, 0, -22.0), Vector3(-73.5, 0, -6.0), 2)
	_sandbags(Vector3(-73.5, 0, 6.0), Vector3(-73.5, 0, 22.0), 2)
	_floodlight("StationFloodN", Vector3(-71.5, 0, -8.0), Vector3(-58.0, 0, -2.0))
	_floodlight("StationFloodS", Vector3(-71.5, 0, 8.0), Vector3(-58.0, 0, 3.0))
	_tape_line(Vector3(-66.0, 0, -4.6), Vector3(-66.0, 0, 4.6), 3)
	_graffiti("QUARANTINE", Vector3(-73.62, 5.4, -13.0), Vector3(1, 0, 0), Color(1.0, 0.82, 0.2), 110)
	_graffiti("HELP US", Vector3(-73.95, 2.7, 16.0), Vector3(1, 0, 0), Color(1.0, 0.25, 0.3), 120)
	# Square: walls of the passages, the last messages.
	_graffiti("THEY CAME FROM THE METRO", Vector3(26.0, 2.8, -4.0), Vector3(0, 0, 1), Color(1.0, 0.3, 0.6), 64)
	var walls := [[Vector3(-24.0, 1.7, -3.96), Vector3(0, 0, 1)], [Vector3(-32.0, 1.6, 3.96), Vector3(0, 0, -1)], [Vector3(23.5, 1.7, 3.96), Vector3(0, 0, -1)],
		[Vector3(31.0, 1.6, -3.96), Vector3(0, 0, 1)], [Vector3(-73.94, 1.8, -17.0), Vector3(1, 0, 0)], [Vector3(-73.94, 1.6, -11.0), Vector3(1, 0, 0)]]
	var n := 0
	for w in walls:
		_poster("StreetPoster%d" % n, w[0], w[1], n * 3 + 1)
		_poster("StreetPoster%db" % n, w[0] + Vector3(-w[1].z, 0.3, w[1].x) * 1.1, w[1], n * 3 + 2)
		n += 1
	_graffiti("EVAC >", Vector3(-25.5, 2.4, 4.0), Vector3(0, 0, -1), Color(0.4, 1.0, 0.6), 96)
	_graffiti("NO WAY OUT", Vector3(4.9, 2.5, 30.0), Vector3(1, 0, 0), Color(1.0, 0.35, 0.2), 80)
	_graffiti("STAY INSIDE", Vector3(87.0, 3.0, -8.0), Vector3(0, 0, 1), Color(0.3, 0.95, 1.0), 72)
	_graffiti("ON AIR", Vector3(93.95, 3.6, -48.0), Vector3(-1, 0, 0), Color(1.0, 0.2, 0.2), 90)
	# Cars that ran into storefronts, nose first, still burning.
	# Cars run into the walls at the far ends of the alleys (behind the
	# zombies' entrances: seen from the street, never in anyone's way).
	_alley_crash("CrashSquareSE", "city_taxi_wreck", Vector3(15.5, 0, 34.0), Vector3(0, 0, 1), 28.0)
	_alley_crash("CrashSquareNW", "city_car_burnt", Vector3(-15.5, 0, -34.0), Vector3(0, 0, -1), -24.0)
	_alley_crash("CrashPrecinctS", "city_car_burnt_b", Vector3(-54.0, 0, 36.0), Vector3(0, 0, 1), 18.0)
	_alley_crash("CrashTowerE", "city_car_burnt", Vector3(106.0, 0, -46.0), Vector3(1, 0, 0), -22.0)
	# Billboards on the roofs round the square, lit from below.
	_roof_billboard("BillboardNorth", Vector3(-4.0, 22.0, -26.0), 0.0)
	_roof_billboard("BillboardSouth", Vector3(9.0, 18.0, 25.0), 180.0)
	_roof_billboard("BillboardMarket", Vector3(80.0, 16.0, 11.0), 180.0)
	# Broadcast plaza: the mast's base taped off and floodlit, wreckage of
	# the skyscraper heaped along its foot.
	var mast := Vector3(TOWER.get_center().x + 4.0, 0, -48.0)
	var corners := [Vector3(-4.2, 0, -4.2), Vector3(4.2, 0, -4.2), Vector3(4.2, 0, 4.2), Vector3(-4.2, 0, 4.2)]
	for k in 4:
		_tape_line(mast + corners[k], mast + corners[(k + 1) % 4], k + 7)
	_floodlight("MastFloodW", mast + Vector3(-7.0, 0, 5.0), mast + Vector3(0, 0, 0))
	_floodlight("MastFloodE", mast + Vector3(8.0, 0, -6.0), mast + Vector3(0, 0, 0))
	_scorches.append(Vector3(70.0, 7.0, -64.0))
	_scorches.append(Vector3(60.0, 5.0, -45.0))
	for x in range(47, 94, 2):
		if x > 65 and x < 75:
			continue
		for k in 3:
			var shade := _rng.randf_range(0.4, 0.68)
			var sc := _rng.randf_range(1.0, 3.2)
			var p := Vector3(float(x) + _rng.randf_range(-1.0, 1.0), 0.05, -71.4 + _rng.randf_range(0.0, 1.4))
			_instance("chunk", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3(sc, sc, sc)), p), Color(shade, shade * 0.95, shade * 0.9))


## The kit's torn billboard on a roof, facing `yaw`, with a lamp on it.
func _roof_billboard(board_name: String, pos: Vector3, yaw: float) -> void:
	var node := _kit(dressing, "city_billboard_torn", board_name, pos, yaw, Vector3(6.0, 7.0, 0.6))
	node.scale = Vector3.ONE * 1.4
	var forward := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)
	_wall_glow(pos + Vector3(0, 4.5, 0) + forward * 0.5, forward, 4.5, Color(1.0, 0.75, 0.45), 0.25)


## A paper poster (a cell of the ads sheet, not lit) pasted on a wall facing
## `normal`, a little crooked.
func _poster(poster_name: String, pos: Vector3, normal: Vector3, cell: int) -> void:
	var key := "poster_%d" % (cell % 32)
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(TEXTURES + "neon_ads.png")
		m.albedo_color = Color(0.85, 0.82, 0.78)
		m.roughness = 0.9
		m.uv1_scale = Vector3(0.25, 0.125, 1.0)
		m.uv1_offset = Vector3((cell % 4) * 0.25, ((cell * 5) % 8) * 0.125, 0.0)
		_materials[key] = m
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 1.25)
	quad.material = _materials[key]
	var mi := MeshInstance3D.new()
	mi.name = poster_name
	mi.mesh = quad
	mi.basis = Basis.looking_at(-normal, Vector3.UP) * Basis(Vector3.BACK, deg_to_rad(_rng.randf_range(-7.0, 7.0)))
	mi.position = pos + normal * 0.01
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(mi)


## A raised boom barrier (striped arm) on a post at `pos`.
func _boom_barrier(pos: Vector3) -> void:
	var post := _mat("boom_post", Color(0.2, 0.2, 0.22), 0.6)
	_visual_box(dressing, "BoomPost", Vector3(0.35, 1.2, 0.35), pos + Vector3(0, 0.6, 0), post)
	var arm := _visual_box(dressing, "BoomArm", Vector3(0.12, 0.12, 5.0), pos + Vector3(0, 1.1, 0), _surface("hazard", ["dune_hazard"], Color.WHITE, 1.0, 0.7))
	arm.rotation.x = deg_to_rad(68.0)
	arm.position += arm.basis * Vector3(0, 0, -2.4)
	arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A work floodlight on a stand at `pos`, aimed at `target`, with its pool.
func _floodlight(flood_name: String, pos: Vector3, target: Vector3) -> void:
	var dark := _mat("flood_stand", Color(0.12, 0.12, 0.13), 0.6)
	var head := pos + Vector3(0, 2.6, 0)
	var dir := (target - head).normalized()
	for a in 3:
		var foot := pos + Vector3(cos(a * TAU / 3.0), 0, sin(a * TAU / 3.0)) * 0.6
		var leg := _visual_box(dressing, "%sLeg%d" % [flood_name, a], Vector3(0.05, 2.7, 0.05), (foot + head) * 0.5, dark)
		leg.basis = Basis(Vector3.UP.cross(head - foot).normalized(), Vector3.UP.angle_to(head - foot)) if (head - foot).normalized() != Vector3.UP else Basis()
		leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lamp := _visual_box(dressing, flood_name + "Head", Vector3(0.7, 0.5, 0.25), head, dark)
	lamp.basis = Basis.looking_at(dir, Vector3.UP)
	var face := _visual_box(dressing, flood_name + "Face", Vector3(0.6, 0.4, 0.04), head + dir * 0.14, _mat("flood_face", Color(1.0, 0.97, 0.88), 0.3, Color(1.0, 0.95, 0.82), 6.0))
	face.basis = Basis.looking_at(dir, Vector3.UP)
	var l := _omni(fx, flood_name + "Light", head + dir * 1.5, Color(1.0, 0.93, 0.8), 2.0, 14.0)
	l.omni_attenuation = 1.8
	_pool(target.lerp(Vector3(pos.x, 0, pos.z), 0.35), 6.0, Color(1.0, 0.92, 0.75), false, 0.32)


## A car run nose-first into the wall at the end of an alley (`end`: the
## wall at ground level, `away`: the alley's direction out of the street,
## `angle`: degrees off straight), burning, the wall scorched above it.
func _alley_crash(crash_name: String, model: String, end: Vector3, away: Vector3, angle: float) -> void:
	var d := Basis(Vector3.UP, deg_to_rad(angle)) * away
	var yaw := rad_to_deg(atan2(-d.z, d.x))
	var centre := end - d * 2.3
	var node := _kit(dressing, model, crash_name, centre, yaw, Vector3(4.3, 1.45, 2.0))
	node.rotation.z = deg_to_rad(-4.0)
	var spots := _empties(node, "Fire")
	if spots.is_empty():
		spots.append(centre + Vector3(0, 1.2, 0))
	_fire_at(fx, crash_name + "Fire", spots[0], 2.0, true, 3.0)
	_fire_at(fx, crash_name + "Nose", end - d * 0.6 + Vector3(0, 0.5, 0), 1.3, false, 0.0, true)
	_smoke(fx, crash_name + "Smoke", end - away * 0.8 + Vector3(0, 1.5, 0), 0.22)
	_sparks(fx, crash_name + "Sparks", end - away * 0.1 + Vector3(0, 3.0, 0), 2.6)
	_scorches.append(Vector3(centre.x, 3.2, centre.z))
	_wall_glow(end - away * 0.05 + Vector3(0, 2.8, 0), -away, 3.6, Color(1.0, 0.45, 0.15), 0.45)
	var side := Vector3(-away.z, 0, away.x)
	for k in 12:
		var p := end - away * _rng.randf_range(0.2, 1.6) + side * _rng.randf_range(-2.0, 2.0) + Vector3(0, 0.05, 0)
		var sc := _rng.randf_range(1.0, 2.4)
		var c := Color(0.62, 0.3, 0.22) if k % 3 == 0 else Color(0.5, 0.48, 0.46)
		_instance("chunk", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3(sc, sc, sc)), p), c)



## Water tanks, air conditioners and masts on the roofs (silhouettes against
## the sky from every street).
func _build_rooftops() -> void:
	var i := 0
	for roof in _roofs:
		var r: Rect2 = roof[0]
		var h: float = roof[1]
		var inner := r.grow(-2.5)
		if inner.size.x < 2.0 or inner.size.y < 2.0:
			continue
		if i % 3 != 1:
			_instance("tank", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), _roof_spot(inner, h)), Color.WHITE)
		for k in 2 + i % 3:
			_instance("ac", Transform3D(Basis(Vector3.UP, _rng.randi() % 4 * PI * 0.5), _roof_spot(inner, h)), Color.WHITE)
		if i % 4 == 0:
			_instance("antenna", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), _roof_spot(inner, h)), Color.WHITE)
		i += 1


func _roof_spot(inner: Rect2, h: float) -> Vector3:
	return Vector3(_rng.randf_range(inner.position.x, inner.end.x), h, _rng.randf_range(inner.position.y, inner.end.y))


# ---------------------------------------------------------------------------
# The Neon Market's glow and the Metro's life
# ---------------------------------------------------------------------------

## More signs up the facades, neon tubes along the shopfronts, lit stalls,
## steam from the drains, the colours pooling on the wet paving.
func _build_market_glow() -> void:
	var colors := [Color(1.0, 0.2, 0.7), Color(0.2, 0.9, 1.0), Color(1.0, 0.75, 0.2), Color(0.5, 0.35, 1.0), Color(0.4, 1.0, 0.45)]
	var more := [[46.0, 4.6, -1.0], [52.0, 6.2, -1.0], [59.0, 4.0, -1.0], [74.0, 6.0, -1.0], [84.5, 4.2, -1.0],
		[41.0, 5.0, 1.0], [50.5, 3.8, 1.0], [61.0, 5.6, 1.0], [70.0, 3.6, 1.0], [76.5, 6.4, 1.0], [88.0, 4.4, 1.0]]
	var i := 0
	for s in more:
		var side: float = s[2]
		var model := "city_neon_sign_a" if i % 2 == 0 else "city_neon_sign_b"
		_neon_sign(dressing, model, "NeonUpper%d" % i, Vector3(s[0], s[1], MARKET.position.y if side < 0.0 else MARKET.end.y), 0.0 if side < 0.0 else 180.0, colors[(i + 1) % colors.size()], false)
		i += 1
	# Tubes along both shopfronts at awning height, broken into runs.
	i = 0
	for side in [-1.0, 1.0]:
		var z: float = (MARKET.position.y + 0.12) if side < 0.0 else (MARKET.end.y - 0.12)
		var x := MARKET.position.x + 1.0
		while x < MARKET.end.x - 2.0:
			var run := _rng.randf_range(2.5, 5.5)
			var skip: bool = (side < 0.0 and x + run > 39.5 and x < 44.5) or (side < 0.0 and x + run > 61.5 and x < 70.5) or (side > 0.0 and x + run > 53.5 and x < 58.5)
			if not skip:
				var c: Color = colors[i % colors.size()]
				var y := 3.1 + (i % 2) * 0.35
				_instance("tube", Transform3D(Basis().scaled(Vector3(run, 1, 1)), Vector3(x + run * 0.5, y, z)), c)
				if i % 3 == 0:
					_instance("tube", Transform3D(Basis().scaled(Vector3(run * 0.7, 1, 1)), Vector3(x + run * 0.5, y + 0.5, z)), colors[(i + 2) % colors.size()])
				_wall_glow(Vector3(x + run * 0.5, y, z - side * 0.12), Vector3(0, 0, -side), run * 0.6, c, 0.3)
				_pool(Vector3(x + run * 0.5, 0, z - side * 1.6), run * 0.55, c, false, 0.28)
				i += 1
			x += run + _rng.randf_range(1.0, 3.0)
	# The stalls' own light under their awnings.
	for x in [40.0, 52.0, 72.0, 82.0]:
		for side in [-1.0, 1.0]:
			_pool(Vector3(x, 0, side * 2.6), 3.2, Color(1.0, 0.72, 0.38), false, 0.4)
	_omni(fx, "StallLightW", Vector3(46.0, 2.6, 0.0), Color(1.0, 0.7, 0.4), 1.2, 9.0)
	_omni(fx, "StallLightE", Vector3(77.0, 2.6, 0.0), Color(1.0, 0.7, 0.4), 1.2, 9.0)
	# Steam out of the drains, lit by the signs.
	_manhole(Vector3(47.0, 0, 5.0), true)
	_manhole(Vector3(67.5, 0, -4.0), true)
	_manhole(Vector3(86.0, 0, 4.5), true)
	_steam(Vector3(57.0, 0, -7.4), Color(0.9, 0.55, 0.85), 0.3)
	_steam(Vector3(79.0, 0, 7.4), Color(0.5, 0.8, 1.0), 0.3)
	# Bulb strings cast their warm glow down the lanes.
	for x in range(40, 90, 6):
		_pool(Vector3(float(x) + 1.5, 0, 0.0), 3.6, Color(1.0, 0.68, 0.4), false, 0.22)
	# Lanterns hanging in the side alleys beyond the zombie entrances.
	_tape_line(Vector3(40.0, 0, -8.4), Vector3(44.0, 0, -8.4), 1)
	_tape_line(Vector3(54.0, 0, 8.4), Vector3(58.0, 0, 8.4), 2)


## The Metro's furniture beyond the benches: tiled walls, a ceiling of panels
## (some fallen), emergency light pooling on the wet platform, the train's
## lit windows spilling onto the edge, exit signs and roundels.
func _build_metro_life() -> void:
	var y0 := METRO_Y
	var tile := StandardMaterial3D.new()
	tile.albedo_texture = load(TEXTURES + "sky_tiles.png")
	tile.albedo_color = Color(0.86, 0.9, 0.82)
	tile.uv1_triplanar = true
	tile.uv1_world_triplanar = true
	tile.uv1_scale = Vector3.ONE * 0.5
	tile.roughness = 0.25
	tile.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var trim := _mat("metro_trim", Color(0.12, 0.45, 0.32), 0.4)
	# Tiles on the hall's south wall (between the openings) and the pillars.
	var wall_z := HALL.end.y - 0.03
	var k := 0
	for s in _south_wall_spans():
		_visual_box(dressing, "WallTiles%d" % k, Vector3(s.y - s.x, 2.6, 0.05), Vector3((s.x + s.y) * 0.5, y0 + 1.3, wall_z), tile)
		_visual_box(dressing, "WallTrim%d" % k, Vector3(s.y - s.x, 0.22, 0.08), Vector3((s.x + s.y) * 0.5, y0 + 2.7, wall_z), trim)
		k += 1
	for p in 7:
		var px := HALL.position.x + 5.0 + p * 8.0
		_visual_box(dressing, "PillarTiles%d" % p, Vector3(1.0, 2.4, 1.0), Vector3(px, y0 + 1.2, -33.0), tile)
		var disc := _visual_box(dressing, "Roundel%d" % p, Vector3(0.9, 0.9, 0.05), Vector3(px, y0 + 3.2, -32.52), _mat("roundel", Color(0.85, 0.16, 0.14), 0.4, Color(1.0, 0.2, 0.15), 0.6))
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_label(dressing, "RoundelText%d" % p, "3", Vector3(px, y0 + 3.2, -32.48), 0.0, 120, Color(1, 1, 1))
	# Ceiling panels; every so often one is missing, hanging or down.
	var hang := 0
	for gx in range(int(HALL.position.x - 7.0), int(HALL.end.x), 2):
		for gz in range(int(HALL.position.y) + 1, int(HALL.end.y), 1):
			var p := Vector3(gx + 1.0, HALL_CEILING - 0.05, gz + 0.5)
			var roll := _rng.randf()
			if roll < 0.06:
				continue
			if roll < 0.09 and p.z > PLATFORM_EDGE_Z + 1.0:
				var tilt := deg_to_rad(_rng.randf_range(35.0, 55.0)) * (1.0 if hang % 2 == 0 else -1.0)
				var pivot := p + Vector3(0, 0, -0.47 if tilt > 0.0 else 0.47)
				var basis := Basis(Vector3.RIGHT, tilt)
				_instance("panel", Transform3D(basis, pivot + basis * Vector3(0, 0, 0.47 if tilt > 0.0 else -0.47)), Color(0.7, 0.72, 0.68))
				hang += 1
				continue
			if roll < 0.11:
				var floor_y := y0 if p.z > PLATFORM_EDGE_Z else y0 - 1.2
				_instance("panel", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.08, 0.08)), Vector3(p.x, floor_y + 0.04, p.z)), Color(0.6, 0.62, 0.58))
				continue
			var shade := _rng.randf_range(0.62, 0.8)
			_instance("panel", Transform3D(Basis(), p), Color(shade, shade * 1.02, shade * 0.96))
	# Emergency light pooling on the platform and the wall.
	for e in 6:
		var lx := HALL.position.x + 4.0 + e * 10.0
		var red := e % 3 == 1
		var color := Color(1.0, 0.25, 0.15) if red else Color(1.0, 0.62, 0.3)
		_pool(Vector3(lx, y0, -31.5), 4.5, color, false, 0.42)
		_wall_glow(Vector3(lx, y0 + 3.4, HALL.end.y - 0.05), Vector3(0, 0, -1), 3.0, color, 0.3)
	# The train's lit windows spill onto the platform edge.
	var train_z := (HALL.position.y + PLATFORM_EDGE_Z) * 0.5 - 0.3
	var length := HALL.size.x + 12.0
	var car_len := (length - 0.7 * 4) / 5
	for c in 5:
		var cx := (HALL.position.x + HALL.end.x) * 0.5 - length * 0.5 + car_len * 0.5 + c * (car_len + 0.7)
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled_local(Vector3(car_len * 0.45, 1.6, 1.0)), Vector3(cx, y0 + 0.09, PLATFORM_EDGE_Z + 1.4))
		_pool_xform(xf, Color(1.0, 0.8, 0.5), false, 0.38)
		if c % 2 == 0:
			_omni(fx, "TrainGlow%d" % c, Vector3(cx, y0 + 1.6, train_z + 1.9), Color(1.0, 0.78, 0.5), 0.9, 6.0)
	# Exit signs over the stairs.
	_exit_sign("ExitSquare", Vector3(0, y0 + 4.4, HALL.end.y - 0.6), 180.0, "EXIT  ASHFALL SQ")
	_exit_sign("ExitTower", Vector3(HALL.end.x - 0.6, y0 + 4.4, (EXIT_Z.x + EXIT_Z.y) * 0.5), -90.0, "EXIT  TOWER >")
	# Cable trays along the north wall and loops hanging from the ceiling.
	_visual_box(dressing, "CableTray", Vector3(HALL.size.x + 8.0, 0.12, 0.5), Vector3((HALL.position.x + HALL.end.x) * 0.5 - 4.0, y0 + 4.6, HALL.position.y + 0.3), _mat("tray", Color(0.22, 0.22, 0.24), 0.6))
	for x in [-14.0, 3.0, 17.0, 33.0]:
		_cable(Vector3(x, HALL_CEILING - 0.1, -30.0), Vector3(x + 4.0, HALL_CEILING - 0.1, -31.5), 1.4, 8)
	# A tube light torn loose, hanging by one end and spitting sparks.
	var tube := _visual_box(dressing, "LooseTube", Vector3(0.12, 1.4, 0.12), Vector3(9.0, HALL_CEILING - 0.75, -34.5), _mat("tube_light", Color(0.9, 0.95, 1.0), 0.3, Color(0.85, 0.95, 1.0), 5.0))
	tube.rotation.z = deg_to_rad(18.0)
	tube.add_to_group("city_neon_flicker", true)
	_sparks(fx, "LooseTubeSparks", Vector3(9.2, HALL_CEILING - 1.4, -34.5), 1.6)
	# Lamps down the stairs from the square.
	for s in [-1.0, 1.0]:
		var lamp_pos := Vector3(s * (STAIR_HALF - 0.05), -2.2, -21.0)
		var lamp := _visual_box(dressing, "StairLamp%s" % ("W" if s < 0 else "E"), Vector3(0.1, 0.3, 0.9), lamp_pos, _mat("stair_lamp", Color(1.0, 0.9, 0.7), 0.3, Color(1.0, 0.82, 0.55), 2.2))
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wall_glow(lamp_pos, Vector3(-s, 0, 0), 2.0, Color(1.0, 0.75, 0.45), 0.16)
	_omni(fx, "StairLight", Vector3(0, -1.8, -21.0), Color(1.0, 0.78, 0.52), 1.2, 8.0)
	# Paper posters pasted on the tiles, peeling.
	var k2 := 0
	for x in [-23.0, -17.5, -6.0, 3.9, 11.0, 18.0, 24.4, 29.8]:
		_poster("MetroPoster%d" % k2, Vector3(x, y0 + 1.6 + (k2 % 2) * 0.25, HALL.end.y - 0.07), Vector3(0, 0, -1), k2 + 3)
		k2 += 1
	# Puddled leaks under the ceiling cracks.
	_steam(Vector3(-20.0, y0, -29.0), Color(0.6, 0.65, 0.7), 0.18)


func _exit_sign(sign_name: String, pos: Vector3, yaw: float, text: String) -> void:
	var board := _visual_box(dressing, sign_name, Vector3(3.6, 0.6, 0.12), pos, _mat("exit_board", Color(0.05, 0.45, 0.22), 0.4, Color(0.15, 0.95, 0.45), 1.6))
	board.rotation.y = deg_to_rad(yaw)
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var forward := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)
	_label(dressing, sign_name + "Text", text, pos + forward * 0.08, yaw, 56, Color(1, 1, 1))
	_wall_glow(pos + forward * 0.1 - Vector3(0, 0.2, 0), forward, 2.2, Color(0.2, 1.0, 0.5), 0.25)


## A metro bench: wooden slats on a steel frame (one merged mesh), with the
## collider the grey-box bench had.
func _bench(parent: Node3D, bench_name: String, pos: Vector3, yaw: float) -> void:
	if not _meshes.has("bench"):
		var wood := _mat("bench_wood", Color(0.55, 0.32, 0.18), 0.6)
		var steel := _mat("bench_steel", Color(0.18, 0.19, 0.2), 0.4)
		var slat := BoxMesh.new()
		slat.size = Vector3(2.4, 0.06, 0.14)
		var leg := BoxMesh.new()
		leg.size = Vector3(0.08, 0.45, 0.5)
		var back := BoxMesh.new()
		back.size = Vector3(2.4, 0.12, 0.05)
		var parts: Array = []
		for k in 3:
			parts.append([slat, Transform3D(Basis(), Vector3(0, 0.46, -0.18 + k * 0.17)), wood])
		for k in 2:
			parts.append([back, Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0, 0.72 + k * 0.18, 0.3)), wood])
		for x in [-1.0, 1.0]:
			parts.append([leg, Transform3D(Basis(), Vector3(x, 0.22, 0)), steel])
		_meshes["bench"] = Batch.compound(parts)
	var mi := MeshInstance3D.new()
	mi.name = bench_name
	mi.mesh = _meshes["bench"]
	mi.position = pos
	mi.rotation.y = deg_to_rad(yaw)
	dressing.add_child(mi)
	var body := _collider(parent, bench_name + "Collision", Vector3(2.4, 0.5, 0.6), pos + Vector3(0, 0.25, 0))
	body.rotation.y = deg_to_rad(yaw)


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
	_reflectors.append([pos, color, 0.45, clampf(energy * 0.25, 0.25, 0.75)])
	return l


## A fire (the kit's city_fire scene, scaled, or crossed flame quads) with an
## optional light (`energy` 0: the scene's default); it glows on the ground
## below and smears in the puddles.
func _fire_at(parent: Node3D, fire_name: String, pos: Vector3, size: float, with_light: bool, energy := 0.0, minor := false) -> void:
	var floor_y := METRO_Y if pos.y < UNDERGROUND_Y else 0.0
	if with_light or size >= 1.5:
		_pool(Vector3(pos.x, floor_y, pos.z), 1.2 + size * 1.4, Color(1.0, 0.42, 0.12), true, 0.3 if with_light else 0.2)
	if size >= 0.7:
		_reflectors.append([pos + Vector3(0, size * 0.8, 0), Color(1.0, 0.5, 0.18), 0.35 + size * 0.25, 0.55 + size * 0.15])
	var scene := PROPS + "city_fire.tscn"
	if ResourceLoader.exists(scene):
		var f: Node3D = (load(scene) as PackedScene).instantiate()
		f.name = fire_name
		parent.add_child(f)
		f.position = pos
		f.set("size", size)
		f.set("with_light", with_light)
		if energy > 0.0:
			f.set("light_energy", energy)
		if minor:
			f.set("with_embers", false)
			f.set("with_smoke", false)
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
# Draw calls: the static boxes merged per district
# ---------------------------------------------------------------------------

## Merges the static boxes (walls, pillars, block cores, parapets, kerbs,
## signs, the train) into one mesh per district and shadow setting, after the
## navigation bake (colliders are kept). Hundreds of objects become a few
## dozen; the Precinct's and the Market's are hidden underground with the
## facades.
func _compound_static() -> void:
	var groups := {}
	var order: Array = []
	for node in level.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not _compoundable(mi):
			continue
		var xf := _to_level(mi)
		var centre := xf * mi.mesh.get_aabb().get_center()
		var key := "%s_%d" % [_area_of(centre), mi.cast_shadow]
		if not groups.has(key):
			groups[key] = [[], [], mi.cast_shadow]
			order.append(key)
		groups[key][0].append([mi.mesh, xf])
		groups[key][1].append(mi)
	for key in order:
		var merged := MeshInstance3D.new()
		merged.name = "Merged_" + String(key)
		merged.mesh = Batch.compound(groups[key][0])
		merged.cast_shadow = groups[key][2]
		if String(key).begins_with("precinct") or String(key).begins_with("market"):
			merged.add_to_group("city_surface", true)
		dressing.add_child(merged)
		for mi in groups[key][1]:
			(mi as Node).get_parent().remove_child(mi)
			(mi as Node).free()
	print("build_endless_city: merged %d static groups" % order.size())


func _compoundable(mi: MeshInstance3D) -> bool:
	if not mi.mesh is PrimitiveMesh or mi.material_override != null or not mi.visible or mi.get_child_count() > 0:
		return false
	if not mi.get_groups().is_empty():
		return false
	var n: Node = mi.get_parent()
	while n != level:
		if n == fx or n.name == "Gates" or n.scene_file_path != "" or not n.get_groups().is_empty():
			return false
		if n is Node3D and not (n as Node3D).visible:
			return false
		n = n.get_parent()
	return true


func _to_level(node: Node3D) -> Transform3D:
	var xf := node.transform
	var n: Node = node.get_parent()
	while n != level:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _area_of(p: Vector3) -> String:
	if p.y < -0.2:
		return "metroW" if p.x < 12.0 else "metroE"
	if p.x < -28.0:
		return "precinct"
	if p.x > 28.0 and p.z > -12.0:
		return "market"
	if p.x > 34.0 and p.z <= -12.0:
		return "tower"
	return "square"


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
	if ResourceLoader.exists(path) and KIT_SCENES.any(func(p: String) -> bool: return model.begins_with(p)):
		node = (load(path) as PackedScene).instantiate()
	elif ResourceLoader.exists(path):
		# Static props: the model's surfaces merged into one mesh.
		node = Node3D.new()
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = Batch.merged_model(path)
		if KIT_SMALL.any(func(p: String) -> bool: return model.begins_with(p)):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = SMALL_RANGE
		node.add_child(mi)
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
	_kit_models[node] = model
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
