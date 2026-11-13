extends SceneTree
## Generator for World 10 "Sky Carnival" / level "Sky Harbor".
##
## Rebuilds scenes/levels/sky_harbor.tscn: a travelling carnival moored on
## floating islands above a sea of clouds, at sunrise. The hub island round the
## Cloud Nine Supply station (carousel, beacon, game booths, carts), the dock
## isle with its raised boarding deck and the airship Cumulus at its mooring
## tower, the big-top isle with the enterable tent, the plank bridges between
## them, five zombie entrances, the sky ride, the cloud sea, cloud banks, far
## islands and balloons, lights, bunting and a baked navigation mesh.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_sky_harbor.gd
##
## Run it with a renderer (not --headless): the headless renderer keeps no
## MultiMesh instance data, so railings and props would save empty.
##
## NOTE: running this overwrites hand edits made to sky_harbor.tscn.
##
## Layout (metres, top view; -Z = north; every deck at y 0 unless noted):
##   - Hub isle (x -16..16, z -15..14, chamfered), the station at (0, 0, -2);
##     the south lookout (x -5..5, z 14..21) holds the exit portal.
##   - West: a 6 m bridge to the dock isle (x -42..-22); its boarding deck
##     (y 3.2, x -42..-34) is climbed by two stair runs; the gangway runs west
##     to the airship's gondola. The airship floats along Z at x -53.
##   - East: a 6 m bridge to the big-top isle (centre (34, 0, 1), apothem 12).
##   - Entrances: airship gangway (W), sky-ride station (N), backstage wagon
##     (E, behind the tent), balloon basket (W of the hub), cargo lift (S).

const OUT_PATH := "res://scenes/levels/sky_harbor.tscn"
const MODELS := "res://art/models/"
const TEXTURES := "res://art/textures/"
const SHADERS := "res://art/shaders/"

const STATION := Vector3(0.0, 0.0, -2.0)
const DECK_T := 0.6                                  # deck slab thickness
const UPPER_Y := 3.2                                 # dock boarding deck
const BRIDGE_W := 4.6
const BRIDGE_L := 6.0
const WEST_BRIDGE := Vector3(-19.0, 0.0, -2.0)
const EAST_BRIDGE := Vector3(19.0, 0.0, 1.0)
const BIGTOP := Vector3(34.0, 0.0, 1.0)
const BIGTOP_R := 9.5
const BIGTOP_APOTHEM := 12.0
const AIRSHIP := Vector3(-53.0, 13.8, -1.5)
const PORTAL := Vector3(0.0, 0.0, 18.6)
const GONDOLA_DECK := Rect2(2.0, -25.0, 8.0, 10.0)   # x, z, w, d
const SUN_DIRECTION := Vector3(0.92, 0.3, 0.25)      # toward the sun (east, low)
const PLAYER_WALL_H := 10.0

var level: Node3D
var geo: Node3D          # collidable geometry (navmesh source)
var dressing: Node3D     # non-colliding scenery
var _materials := {}
var _boxes := {}
var _late_scripts: Array = []
var _light_count := 0
var _mesh_cache := {}
var _bunting: SurfaceTool
var _bunting_count := 0


func _initialize() -> void:
	level = Node3D.new()
	level.name = "SkyHarbor"
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
	_bunting = SurfaceTool.new()
	_bunting.begin(Mesh.PRIMITIVE_TRIANGLES)

	_build_hub()
	_build_dock()
	_build_bigtop_isle()
	_build_bridges()
	_build_station()
	_build_hub_props()
	_build_entrances()
	_build_airship()
	_build_sky_ride()
	_build_lights()
	_build_backdrop()
	_build_exit()
	_build_markers()
	_finish_bunting()
	var gale := Node3D.new()
	gale.name = "Gale"
	level.add_child(gale)
	_late(gale, "res://scripts/props/sky_gale.gd", {})

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
	print("build_sky_harbor: saved %s (error %d), %d omni lights" % [OUT_PATH, err, _light_count])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: sunrise sky shader, low gold sun in the east, cool sky fill
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SHADERS + "sky_sky.gdshader")
	sky_mat.set_shader_parameter("sun_direction", SUN_DIRECTION.normalized())
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.72, 0.92)
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.4
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.98, 0.84, 0.78)
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.looking_at(-SUN_DIRECTION.normalized(), Vector3.UP), Vector3(0, 30, 0))
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_opacity = 0.7
	level.add_child(sun)

	# The open sky from the west: a cool lift on everything in the sun's shadow.
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.transform = Transform3D(Basis.looking_at(-Vector3(-0.6, 0.7, -0.3).normalized(), Vector3.UP), Vector3(0, 30, 0))
	fill.light_color = Color(0.62, 0.74, 1.0)
	fill.light_energy = 0.32
	fill.shadow_enabled = false
	level.add_child(fill)


# ---------------------------------------------------------------------------
# Islands: deck slabs, rock undersides, railings and the player-only walls
# ---------------------------------------------------------------------------

func _hub_outline() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-16, -10), Vector2(-11, -15), Vector2(11, -15), Vector2(16, -10), Vector2(16, 9),
		Vector2(11, 14), Vector2(-11, 14), Vector2(-16, 9)])


func _dock_outline() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-22, -10), Vector2(-26, -14), Vector2(-38, -14), Vector2(-42, -10), Vector2(-42, 7),
		Vector2(-38, 11), Vector2(-26, 11), Vector2(-22, 7)])


func _bigtop_outline() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := BIGTOP_APOTHEM / cos(PI / 16.0)
	for k in 16:
		var a := TAU * (k + 0.5) / 16.0
		pts.append(Vector2(BIGTOP.x + cos(a) * r, BIGTOP.z + sin(a) * r))
	return pts


## Openings in the island railings: [centre (x, z), half width, kind]. Bridges
## are open to everyone; entrances get a player-only wall across the gap.
func _openings() -> Array:
	return [
		[Vector2(WEST_BRIDGE.x + BRIDGE_L * 0.5, WEST_BRIDGE.z), BRIDGE_W * 0.5 - 0.05, &"bridge"],
		[Vector2(WEST_BRIDGE.x - BRIDGE_L * 0.5, WEST_BRIDGE.z), BRIDGE_W * 0.5 - 0.05, &"bridge"],
		[Vector2(EAST_BRIDGE.x - BRIDGE_L * 0.5, EAST_BRIDGE.z), BRIDGE_W * 0.5 - 0.05, &"bridge"],
		[Vector2(EAST_BRIDGE.x + BRIDGE_L * 0.5, EAST_BRIDGE.z), BRIDGE_W * 0.5 - 0.05, &"bridge"],
		[Vector2(0.0, 14.0), 5.0, &"open"],
		[Vector2(6.0, -15.0), 2.5, &"entrance"],
		[Vector2(-16.0, 6.5), 2.5, &"entrance"],
		[Vector2(7.5, 14.0), 1.8, &"entrance"],
		[Vector2(BIGTOP.x + BIGTOP_APOTHEM, BIGTOP.z), 2.4, &"entrance"],
	]


func _build_hub() -> void:
	var hub := Node3D.new()
	hub.name = "HubIsle"
	geo.add_child(hub)
	var deck := _textured("deck", "sky_deck", 0.32, 0.8)
	_deck(hub, "HubDeck", _hub_outline(), 0.0, deck)
	# The south lookout and the plaza tiles round the station.
	_deck(hub, "Lookout", PackedVector2Array([Vector2(-5, 13.5), Vector2(5, 13.5), Vector2(5, 21), Vector2(-5, 21)]), 0.0, deck)
	var tiles := MeshInstance3D.new()
	tiles.name = "Plaza"
	var disc := CylinderMesh.new()
	disc.top_radius = 7.0
	disc.bottom_radius = 7.0
	disc.height = 0.04
	disc.radial_segments = 48
	tiles.mesh = disc
	tiles.material_override = _textured("tiles", "sky_tiles", 0.18, 0.75)
	tiles.position = STATION + Vector3(0, 0.0, 0)
	tiles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(tiles)
	var rim := MeshInstance3D.new()
	rim.name = "PlazaRim"
	var torus := TorusMesh.new()
	torus.inner_radius = 6.95
	torus.outer_radius = 7.35
	torus.rings = 64
	torus.ring_segments = 6
	rim.mesh = torus
	rim.material_override = _mat("plaza_rim", Color(0.17, 0.23, 0.4), 0.6)
	rim.position = STATION + Vector3(0, 0.02, 0)
	rim.scale = Vector3(1, 0.25, 1)
	dressing.add_child(rim)
	_isle_rock("HubRock", Vector3(0, -DECK_T, -0.5), Vector3(19.5, 24.0, 17.5))
	_isle_rock("LookoutRock", Vector3(0, -DECK_T, 18.0), Vector3(6.0, 8.0, 4.5))
	_rails_round(hub, "Hub", _hub_outline())
	_rails_round(hub, "Lookout", PackedVector2Array([Vector2(5, 14), Vector2(5, 21), Vector2(-5, 21), Vector2(-5, 14)]), true, false)


func _build_dock() -> void:
	var dock := Node3D.new()
	dock.name = "DockIsle"
	geo.add_child(dock)
	_deck(dock, "DockDeck", _dock_outline(), 0.0, _textured("deck", "sky_deck", 0.32, 0.8))
	_isle_rock("DockRock", Vector3(-32, -DECK_T, -1.5), Vector3(13.0, 18.0, 15.0))
	_rails_round(dock, "Dock", _dock_outline())
	# The boarding deck: a cream-walled platform at y 3.2 with two stair runs east.
	var wall := _mat("boarding_wall", Color(0.98, 0.93, 0.86), 0.7)
	var x0 := -42.0
	var x1 := -34.0
	var z0 := -9.5
	var z1 := 5.5
	var body := _collider(dock, "BoardingDeck", Vector3(x1 - x0, UPPER_Y, z1 - z0), Vector3((x0 + x1) * 0.5, UPPER_Y * 0.5, (z0 + z1) * 0.5))
	var mi := MeshInstance3D.new()
	mi.name = "Walls"
	mi.mesh = _box_mesh(Vector3(x1 - x0, UPPER_Y - 0.1, z1 - z0), wall)
	mi.position.y = -0.05
	body.add_child(mi)
	_visual_box(dressing, "BoardingTop", Vector3(x1 - x0 + 0.2, 0.2, z1 - z0 + 0.2), Vector3((x0 + x1) * 0.5, UPPER_Y - 0.1, (z0 + z1) * 0.5),
		_textured("deck", "sky_deck", 0.32, 0.8))
	_visual_box(dressing, "BoardingBand", Vector3(x1 - x0 + 0.3, 0.3, z1 - z0 + 0.3), Vector3((x0 + x1) * 0.5, UPPER_Y - 0.35, (z0 + z1) * 0.5),
		_mat("navy", Color(0.17, 0.23, 0.4), 0.6))
	for k in 5:
		var z := z0 + 1.5 + k * 3.0
		_visual_box(dressing, "WallStripe%d" % k, Vector3(0.06, UPPER_Y - 0.6, 1.0), Vector3(x1 + 0.02, (UPPER_Y - 0.6) * 0.5, z),
			_mat("red", Color(0.91, 0.22, 0.31), 0.5))
	# Stairs at both ends of the east face (top at the deck edge, foot to the east).
	_stairs(dock, "StairN", Vector3(x1, UPPER_Y, z0 + 1.5), Vector3(x1 + 8.0, 0.0, z0 + 1.5), 3.0)
	_stairs(dock, "StairS", Vector3(x1, UPPER_Y, z1 - 1.5), Vector3(x1 + 8.0, 0.0, z1 - 1.5), 3.0)
	# Railings round the boarding deck, open at the stair heads and the gangway.
	var y := UPPER_Y
	_fence_run(dock, "UpperRailN", Vector3(x0, y, z0 + 0.15), Vector3(x1, y, z0 + 0.15))
	_fence_run(dock, "UpperRailS", Vector3(x0, y, z1 - 0.15), Vector3(x1, y, z1 - 0.15))
	_fence_run(dock, "UpperRailE", Vector3(x1 - 0.15, y, z0 + 3.0), Vector3(x1 - 0.15, y, z1 - 3.0))
	_fence_run(dock, "UpperRailWN", Vector3(x0 + 0.15, y, z0), Vector3(x0 + 0.15, y, -3.5))
	_fence_run(dock, "UpperRailWS", Vector3(x0 + 0.15, y, -0.5), Vector3(x0 + 0.15, y, z1))
	var walls := _player_walls()
	_player_wall(walls, "GangwayGate", Vector3(x0, y, -3.6), Vector3(x0, y, -0.4), 6.0)
	# Dressing on the boarding deck: benches, planters, a telescope-like lamp row.
	_prop(dressing, "sky_bench", "UpperBenchA", Vector3(-39.0, y, z0 + 0.9), 0.0, Vector3(1.8, 1, 0.6))
	_prop(dressing, "sky_bench", "UpperBenchB", Vector3(-39.0, y, z1 - 0.9), 180.0, Vector3(1.8, 1, 0.6))
	_solid_prop(dock, "sky_planter", "UpperPlanterA", Vector3(-36.0, y, -6.0), 90.0, Vector3(1.6, 0.7, 0.8))
	_solid_prop(dock, "sky_planter", "UpperPlanterB", Vector3(-36.0, y, 2.0), 90.0, Vector3(1.6, 0.7, 0.8))
	_solid_prop(dock, "sky_crates", "UpperCrates", Vector3(-40.0, y, -6.5), 30.0, Vector3(1.9, 1.6, 1.3))
	_lamp(dock, "UpperLampN", Vector3(-41.2, y, z0 + 0.8))
	_lamp(dock, "UpperLampS", Vector3(-41.2, y, z1 - 0.8))
	_lamp(dock, "UpperLampE", Vector3(-34.8, y, -2.0))
	_string_bunting(Vector3(-41.2, y + 3.0, z0 + 0.8), Vector3(-34.8, y + 3.0, -2.0), 0.6)
	_string_bunting(Vector3(-34.8, y + 3.0, -2.0), Vector3(-41.2, y + 3.0, z1 - 0.8), 0.6)
	# Ground-level dock: freight, carts and benches as cover along the routes.
	_solid_prop(dock, "sky_crates", "DockCratesA", Vector3(-28.0, 0, -11.5), 0.0, Vector3(1.9, 1.6, 1.3))
	_solid_prop(dock, "sky_crates", "DockCratesB", Vector3(-29.0, 0, 8.5), 160.0, Vector3(1.9, 1.6, 1.3))
	_solid_prop(dock, "sky_balloon_cart", "DockBalloonCart", Vector3(-28.5, 0, -6.5), 60.0, Vector3(1.4, 1.1, 0.8))
	_solid_prop(dock, "sky_planter", "DockPlanterA", Vector3(-24.0, 0, 5.5), 90.0, Vector3(1.6, 0.7, 0.8))
	_solid_prop(dock, "sky_planter", "DockPlanterB", Vector3(-24.0, 0, -8.5), 90.0, Vector3(1.6, 0.7, 0.8))
	_solid_prop(dock, "sky_booth", "DockBooth", Vector3(-30.0, 0, 9.4), 180.0, Vector3(3.2, 2.6, 2.0))
	_lamp(dock, "DockLampA", Vector3(-25.0, 0, -12.6))
	_lamp(dock, "DockLampB", Vector3(-25.0, 0, 9.6))
	_lamp(dock, "DockLampC", Vector3(-39.5, 0, -12.6))
	_string_bunting(Vector3(-25.0, 3.0, -12.6), Vector3(-39.5, 3.0, -12.6), 0.7)
	_pinwheel(dock, "DockPinwheelA", Vector3(-23.0, 0, 9.8), 0.0)
	_pinwheel(dock, "DockPinwheelB", Vector3(-41.0, 0, 9.8), 20.0)


func _build_bigtop_isle() -> void:
	var isle := Node3D.new()
	isle.name = "BigTopIsle"
	geo.add_child(isle)
	_deck(isle, "BigTopDeck", _bigtop_outline(), 0.0, _textured("deck", "sky_deck", 0.32, 0.8))
	_isle_rock("BigTopRock", BIGTOP + Vector3(0, -DECK_T, 0), Vector3(14.5, 19.0, 14.5))
	_rails_round(isle, "BigTop", _bigtop_outline())
	_prop(isle, "sky_bigtop", "BigTop", BIGTOP, 0.0, Vector3(19, 11, 19))
	# Tent walls: arcs between the four doorways (each a few colliders).
	var door_half := asin(2.6 / BIGTOP_R)
	for d in 4:
		var a0 := d * PI * 0.5 + door_half
		var a1 := d * PI * 0.5 + PI * 0.5 - door_half
		for k in 4:
			var aa := a0 + (a1 - a0) * k / 4.0
			var ab := a0 + (a1 - a0) * (k + 1) / 4.0
			var pa := BIGTOP + Vector3(cos(aa), 0, -sin(aa)) * (BIGTOP_R - 0.1)
			var pb := BIGTOP + Vector3(cos(ab), 0, -sin(ab)) * (BIGTOP_R - 0.1)
			_wall_segment(isle, "TentWall%d_%d" % [d, k], pa, pb, 4.2, 0.3)
		for s in [-1.0, 1.0]:
			var a: float = d * PI * 0.5 + s * door_half
			_post(isle, "DoorPole%d%d" % [d, int(s)], 0.18, 4.8, BIGTOP + Vector3(cos(a), 0, -sin(a)) * (BIGTOP_R - 0.05))
	_post(isle, "KingPole", 0.3, 12.0, BIGTOP)
	_post(isle, "Pedestal", 0.95, 0.75, BIGTOP)
	# The ring kerb: two arcs (gaps east and west) of low wall.
	for half in 2:
		for k in 6:
			var aa := deg_to_rad(half * 180.0 + 20.0 + 140.0 * k / 6.0)
			var ab := deg_to_rad(half * 180.0 + 20.0 + 140.0 * (k + 1) / 6.0)
			_wall_segment(isle, "Kerb%d_%d" % [half, k], BIGTOP + Vector3(cos(aa), 0, -sin(aa)) * 3.6, BIGTOP + Vector3(cos(ab), 0, -sin(ab)) * 3.6, 0.65, 0.6)
	# Bleachers inside, between the doorways (NE and SW), facing the ring.
	for entry in [[45.0, "BleachersNE"], [225.0, "BleachersSW"]]:
		var a := deg_to_rad(entry[0])
		var p := BIGTOP + Vector3(cos(a), 0, -sin(a)) * 6.9
		var yaw := rad_to_deg(atan2(BIGTOP.x - p.x, BIGTOP.z - p.z))
		_solid_prop(isle, "sky_bleachers", entry[1], p, yaw, Vector3(5.2, 1.45, 2.4))
	for entry in [[135.0, "CratesNW"], [315.0, "CratesSE"]]:
		var a := deg_to_rad(entry[0])
		_solid_prop(isle, "sky_crates", entry[1], BIGTOP + Vector3(cos(a), 0, -sin(a)) * 7.0, entry[0], Vector3(1.9, 1.6, 1.3))
	_omni(isle, "TentGlow", BIGTOP + Vector3(0, 6.0, 0), Color(1.0, 0.78, 0.55), 1.6, 12.0)
	# Outside the tent: carts, planters, lamps and pinwheels round the edge.
	_solid_prop(isle, "sky_popcorn", "TentPopcorn", BIGTOP + Vector3(-6.5, 0, 9.5), 200.0, Vector3(1.8, 1.4, 0.9))
	_solid_prop(isle, "sky_balloon_cart", "TentBalloons", BIGTOP + Vector3(6.0, 0, -9.8), 20.0, Vector3(1.4, 1.1, 0.8))
	_solid_prop(isle, "sky_planter", "TentPlanterA", BIGTOP + Vector3(-9.5, 0, -6.5), 50.0, Vector3(1.6, 0.7, 0.8))
	_solid_prop(isle, "sky_planter", "TentPlanterB", BIGTOP + Vector3(9.5, 0, 7.0), 50.0, Vector3(1.6, 0.7, 0.8))
	for k in 4:
		var a := deg_to_rad(45.0 + k * 90.0)
		_lamp(isle, "TentLamp%d" % k, BIGTOP + Vector3(cos(a), 0, -sin(a)) * 11.2)
	_pinwheel(isle, "TentPinwheelA", BIGTOP + Vector3(-3.0, 0, -11.3), 0.0)
	_pinwheel(isle, "TentPinwheelB", BIGTOP + Vector3(3.0, 0, 11.3), 180.0)


## A deck slab: the outline (x, z), top at `y`, DECK_T thick, one collider.
## Both surfaces draw double-sided, so the outline's winding does not matter.
func _deck(parent: Node3D, deck_name: String, outline: PackedVector2Array, y: float, top: StandardMaterial3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(outline)
	for v in idx:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(outline[v].x, y, outline[v].y))
	var mesh := st.commit()
	var centre := Vector2.ZERO
	for p in outline:
		centre += p / outline.size()
	var side := SurfaceTool.new()
	side.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := outline.size()
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		var out := Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
		var mid := (a + b) * 0.5 - centre
		if out.x * mid.x + out.z * mid.y < 0.0:
			out = -out
		var quad := [Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(b.x, y - DECK_T, b.y), Vector3(a.x, y - DECK_T, a.y)]
		for k in [0, 1, 2, 0, 2, 3]:
			side.set_normal(out)
			side.add_vertex(quad[k])
	side.commit(mesh)
	top.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fascia := _mat("deck_fascia", Color(0.17, 0.23, 0.4), 0.6)
	fascia.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, top)
	mesh.surface_set_material(1, fascia)
	var body := StaticBody3D.new()
	body.name = deck_name
	parent.add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var convex := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for p in outline:
		pts.append(Vector3(p.x, y, p.y))
		pts.append(Vector3(p.x, y - DECK_T, p.y))
	convex.points = pts
	shape.shape = convex
	body.add_child(shape)


func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


## The banded rock hanging under an island (sky_isle_rock is unit size).
func _isle_rock(rock_name: String, top: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = rock_name
	mi.mesh = _model_mesh("sky_isle_rock")
	mi.position = top
	mi.scale = size
	mi.rotation.y = fposmod(top.x * 0.37 + top.z * 0.11, TAU)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(mi)


## Railings (and player-only walls) along every edge of an outline, broken at
## the openings. With `closed` false the closing edge (last point back to the
## first) is left open: the side that joins a pad to its island. With `walls`
## false only the railings are built (pads beyond an entrance gate).
func _rails_round(parent: Node3D, prefix: String, outline: PackedVector2Array, walls := true, closed := true) -> void:
	var holder := _player_walls()
	var n := outline.size()
	for i in (n if closed else n - 1):
		var a := outline[i]
		var b := outline[(i + 1) % n]
		for span in _edge_spans(a, b):
			var pa := Vector3(span[0].x, 0, span[0].y)
			var pb := Vector3(span[1].x, 0, span[1].y)
			var inward := Vector3(-(pb.z - pa.z), 0, pb.x - pa.x).normalized() * (1.0 if _area(outline) > 0.0 else -1.0)
			_fence_run(parent, "%sRail%d_%d" % [prefix, i, int(span[0].x * 10)], pa + inward * 0.2, pb + inward * 0.2)
			if walls:
				_player_wall(holder, "%sWall%d_%d" % [prefix, i, int(span[0].x * 10)], pa, pb, PLAYER_WALL_H)
		if walls:
			for o in _openings():
				if o[2] == &"entrance" and _on_edge(a, b, o[0]):
					var d := (b - a).normalized()
					var c: Vector2 = o[0]
					var h: float = o[1]
					_player_wall(holder, "%sGate%d" % [prefix, i], Vector3(c.x - d.x * h, 0, c.y - d.y * h), Vector3(c.x + d.x * h, 0, c.y + d.y * h), PLAYER_WALL_H)


func _on_edge(a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d := b - a
	var t := (c - a).dot(d) / d.length_squared()
	return t > 0.0 and t < 1.0 and (a + d * t).distance_to(c) < 1.2


## The parts of edge a-b left after cutting the openings out.
func _edge_spans(a: Vector2, b: Vector2) -> Array:
	var cuts: Array[Vector2] = []
	var d := b - a
	var length := d.length()
	for o in _openings():
		if _on_edge(a, b, o[0]):
			var t: float = (o[0] - a).dot(d) / length
			cuts.append(Vector2(t - o[1], t + o[1]))
	cuts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var out: Array = []
	var start := 0.0
	for c in cuts:
		if c.x - start > 0.4:
			out.append([a + d / length * start, a + d / length * c.x])
		start = c.y
	if length - start > 0.4:
		out.append([a + d / length * start, b])
	return out


# ---------------------------------------------------------------------------
# Bridges: plank decks with rope railings between the islands
# ---------------------------------------------------------------------------

func _build_bridges() -> void:
	var b := Node3D.new()
	b.name = "Bridges"
	geo.add_child(b)
	var walls := _player_walls()
	for entry in [["WestBridge", WEST_BRIDGE], ["EastBridge", EAST_BRIDGE]]:
		var c: Vector3 = entry[1]
		var bridge := _prop(b, "sky_bridge", entry[0], c, 90.0, Vector3(BRIDGE_L, 0.4, BRIDGE_W))
		bridge.scale = Vector3(1.0, 1.0, 1.0)
		_collider(b, entry[0] + "Floor", Vector3(BRIDGE_L + 1.0, DECK_T, BRIDGE_W), c + Vector3(0, -DECK_T * 0.5, 0))
		for s in [-1.0, 1.0]:
			var z: float = c.z + s * (BRIDGE_W * 0.5 - 0.05)
			_collider(b, "%sSide%d" % [entry[0], int(s)], Vector3(BRIDGE_L + 0.6, 1.2, 0.25), Vector3(c.x, 0.6, z))
			_player_wall(walls, "%sWall%d" % [entry[0], int(s)], Vector3(c.x - BRIDGE_L * 0.5 - 0.3, 0, z), Vector3(c.x + BRIDGE_L * 0.5 + 0.3, 0, z), PLAYER_WALL_H)
		# Rock buttresses under both ends.
		for e in [-1.0, 1.0]:
			_isle_rock("%sButtress%d" % [entry[0], int(e)], c + Vector3(e * BRIDGE_L * 0.45, -0.7, 0), Vector3(2.4, 3.0, 2.8))


# ---------------------------------------------------------------------------
# Loadout station: Cloud Nine Supply
# ---------------------------------------------------------------------------

func _build_station() -> void:
	var station: Node3D = (load("res://scenes/props/sky_station.tscn") as PackedScene).instantiate()
	station.name = "Station"
	geo.add_child(station)
	station.position = STATION
	station.rotation.y = deg_to_rad(-6.0)


# ---------------------------------------------------------------------------
# Hub dressing: carousel, beacon, booths, carts, crates, lamps, bunting
# ---------------------------------------------------------------------------

func _build_hub_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	geo.add_child(props)
	# The carousel (south-west): the base collides, the top turns.
	var car := Vector3(-9.5, 0, 6.0)
	_prop(props, "sky_carousel", "Carousel", car, 0.0, Vector3(10, 4, 10))
	var top := _prop(dressing, "sky_carousel_top", "CarouselTop", car, 0.0, Vector3(10, 4, 10))
	_late(top, "res://scripts/props/sky_spinner.gd", {"axis": Vector3.UP, "degrees_per_second": 14.0, "wind_response": 0.0})
	_post(props, "CarouselBase", 5.0, 0.45, car)
	_post(props, "CarouselRide", 4.6, 4.0, car + Vector3(0, 0.45, 0))
	_player_block(props, "CarouselCap", Vector3(10.4, 4.0, 10.4), car + Vector3(0, 6.5, 0))
	# The beacon (north-west corner) and its turning lamp.
	var beacon := Vector3(-11.5, 0, -10.5)
	_prop(props, "sky_beacon", "Beacon", beacon, 20.0, Vector3(4, 14, 4))
	_post(props, "BeaconCollision", 2.6, 14.0, beacon)
	var lamp := _prop(dressing, "sky_beacon_lamp", "BeaconLamp", beacon + Vector3(0, 12.7, 0), 0.0, Vector3(1, 1, 1))
	_late(lamp, "res://scripts/props/sky_spinner.gd", {"axis": Vector3.UP, "degrees_per_second": 70.0, "wind_response": 0.0})
	_omni(dressing, "BeaconLight", beacon + Vector3(0, 12.8, 0), Color(1.0, 0.9, 0.6), 1.4, 9.0)
	# Game booths and carts: the inner loop's cover.
	_solid_prop(props, "sky_booth", "BoothNE", Vector3(10.5, 0, -9.5), 210.0, Vector3(3.2, 2.6, 2.0))
	_solid_prop(props, "sky_booth", "BoothE", Vector3(12.5, 0, 5.0), 260.0, Vector3(3.2, 2.6, 2.0))
	_solid_prop(props, "sky_popcorn", "Popcorn", Vector3(5.5, 0, 6.5), 160.0, Vector3(1.8, 1.4, 0.9))
	_solid_prop(props, "sky_balloon_cart", "BalloonCart", Vector3(-3.0, 0, -10.0), 20.0, Vector3(1.4, 1.1, 0.8))
	_solid_prop(props, "sky_crates", "CratesN", Vector3(3.5, 0, -11.5), 10.0, Vector3(1.9, 1.6, 1.3))
	_solid_prop(props, "sky_crates", "CratesW", Vector3(-12.5, 0, -3.5), 100.0, Vector3(1.9, 1.6, 1.3))
	_solid_prop(props, "sky_crates", "CratesSE", Vector3(9.0, 0, 11.0), 250.0, Vector3(1.9, 1.6, 1.3))
	_solid_prop(props, "sky_crates", "CratesE", Vector3(7.0, 0, -4.5), 40.0, Vector3(1.9, 1.6, 1.3))
	_solid_prop(props, "sky_planter", "PlanterA", Vector3(-3.5, 0, 7.5), 0.0, Vector3(1.6, 0.7, 0.8))
	_solid_prop(props, "sky_planter", "PlanterB", Vector3(4.0, 0, -8.0), 90.0, Vector3(1.6, 0.7, 0.8))
	_solid_prop(props, "sky_planter", "PlanterC", Vector3(-6.5, 0, -6.0), 45.0, Vector3(1.6, 0.7, 0.8))
	for entry in [["BenchA", Vector3(-14.8, 0, -6.5), 90.0], ["BenchB", Vector3(14.8, 0, -4.5), 270.0], ["BenchC", Vector3(-7.0, 0, 12.8), 0.0],
			["BenchD", Vector3(13.0, 0, 10.5), 315.0]]:
		_prop(dressing, "sky_bench", entry[0], entry[1], entry[2], Vector3(1.8, 1, 0.6))
		_collider(props, entry[0] + "Collision", Vector3(1.8, 0.9, 0.6), entry[1] + Vector3(0, 0.45, 0)).rotation.y = deg_to_rad(entry[2])
	# Lamps round the edge with bunting strung between them.
	var lamps := [Vector3(-15.0, 0, -9.0), Vector3(-10.5, 0, -14.0), Vector3(-1.0, 0, -14.0), Vector3(10.5, 0, -14.0), Vector3(15.0, 0, -9.0),
		Vector3(15.0, 0, 8.5), Vector3(10.5, 0, 13.0), Vector3(-10.5, 0, 13.0), Vector3(-15.0, 0, 8.5)]
	for i in lamps.size():
		_lamp(props, "HubLamp%d" % i, lamps[i])
	for i in lamps.size():
		var a: Vector3 = lamps[i]
		var b: Vector3 = lamps[(i + 1) % lamps.size()]
		if a.distance_to(b) < 15.0:
			_string_bunting(a + Vector3.UP * 3.0, b + Vector3.UP * 3.0, 0.7)
	for i in 4:
		var l: Vector3 = [lamps[1], lamps[3], lamps[6], lamps[7]][i]
		_string_bunting(l + Vector3.UP * 3.0, STATION + Vector3(0, 6.6, 0), 0.9)
	# Pinwheels round the edges.
	var pins := [[Vector3(-15.0, 0, 3.0), 90.0], [Vector3(15.0, 0, -2.5), 270.0], [Vector3(-6.0, 0, -14.2), 10.0], [Vector3(-13.0, 0, 11.2), 225.0],
		[Vector3(-4.5, 0, 20.0), 180.0], [Vector3(4.5, 0, 20.0), 180.0]]
	for i in pins.size():
		_pinwheel(props, "Pinwheel%d" % i, pins[i][0], pins[i][1])


func _lamp(parent: Node3D, lamp_name: String, pos: Vector3) -> void:
	_prop(dressing, "sky_lamp", lamp_name, pos, fposmod(pos.x * 31.0, 360.0), Vector3(0.3, 4, 0.3))
	_post(parent, lamp_name + "Post", 0.16, 3.6, pos)
	_player_block(parent, lamp_name + "Cap", Vector3(0.9, 2.0, 0.9), pos + Vector3(0, 4.6, 0))


func _pinwheel(parent: Node3D, pin_name: String, pos: Vector3, yaw: float) -> void:
	_prop(dressing, "sky_pinwheel", pin_name, pos, yaw, Vector3(0.2, 3.2, 0.2))
	_post(parent, pin_name + "Post", 0.12, 3.2, pos)
	_player_block(parent, pin_name + "Cap", Vector3(0.9, 2.0, 0.9), pos + Vector3(0, 4.2, 0))
	var wheel := _prop(dressing, "sky_pinwheel_wheel", pin_name + "Wheel", pos, yaw, Vector3(1.6, 1.6, 0.1))
	wheel.position += Vector3(0, 3.2, 0) + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 0.3)
	_late(wheel, "res://scripts/props/sky_spinner.gd", {"axis": Vector3.BACK, "degrees_per_second": 140.0 + fposmod(pos.x * 17.0, 60.0)})


## A string of fluttering pennants from a to b (added to the shared bunting mesh).
func _string_bunting(a: Vector3, b: Vector3, sag: float) -> void:
	var colors := [Color(0.91, 0.22, 0.31), Color(1.0, 0.81, 0.35), Color(0.12, 0.71, 0.69), Color(1.0, 0.95, 0.88), Color(0.56, 0.82, 1.0)]
	var length := a.distance_to(b)
	var count := int(length / 0.55)
	var flat := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var normal := flat.cross(Vector3.UP).normalized()
	for k in count:
		var t0 := (k + 0.1) / count
		var t1 := (k + 0.9) / count
		var tm := (k + 0.5) / count
		var p0 := a.lerp(b, t0) - Vector3.UP * sag * 4.0 * t0 * (1.0 - t0)
		var p1 := a.lerp(b, t1) - Vector3.UP * sag * 4.0 * t1 * (1.0 - t1)
		var tip := a.lerp(b, tm) - Vector3.UP * (sag * 4.0 * tm * (1.0 - tm) + 0.36)
		var c: Color = colors[(_bunting_count + k) % colors.size()]
		for v in [[p0, 0.0], [p1, 0.0], [tip, 1.0]]:
			_bunting.set_color(c)
			_bunting.set_normal(normal)
			_bunting.set_uv(Vector2(0.5, v[1]))
			_bunting.add_vertex(v[0])
	_bunting_count += 1
	# The string itself.
	var line := MeshInstance3D.new()
	line.name = "BuntingLine%d" % _bunting_count
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = 1.0
	cyl.radial_segments = 4
	cyl.rings = 1
	cyl.material = _mat("rope", Color(0.9, 0.82, 0.62), 0.9)
	line.mesh = cyl
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(line)
	var mid := a.lerp(b, 0.5) - Vector3.UP * sag * 0.75
	_orient_between(line, a, mid, b)


## Places a unit cylinder as two straight runs a-m and m-b (a cheap sag).
func _orient_between(line: MeshInstance3D, a: Vector3, m: Vector3, b: Vector3) -> void:
	var second := line.duplicate() as MeshInstance3D
	second.name = line.name + "B"
	line.get_parent().add_child(second)
	for pair in [[line, a, m], [second, m, b]]:
		var node: MeshInstance3D = pair[0]
		var p: Vector3 = pair[1]
		var q: Vector3 = pair[2]
		var dir := (q - p)
		var y := dir.normalized()
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		node.transform = Transform3D(Basis(x, y * dir.length(), z), (p + q) * 0.5)


func _finish_bunting() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Bunting"
	mi.mesh = _bunting.commit()
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "sky_bunting.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group("sky_bunting", true)
	dressing.add_child(mi)


# ---------------------------------------------------------------------------
# Zombie entrances (all beyond the player boundary)
# ---------------------------------------------------------------------------

func _build_entrances() -> void:
	var e := Node3D.new()
	e.name = "Entrances"
	geo.add_child(e)
	var deck := _textured("deck", "sky_deck", 0.32, 0.8)
	# 1. Sky-ride station (north): an open shed facing the hub.
	var r := GONDOLA_DECK
	_deck(e, "RideDeck", PackedVector2Array([Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y),
		Vector2(r.position.x, r.end.y)]), 0.0, deck)
	var ride := Vector3(6.0, 0.0, -19.4)
	_prop(e, "sky_ride_station", "RideStation", ride, 0.0, Vector3(7, 5, 6))
	_collider(e, "RideBack", Vector3(7.2, 4.6, 0.4), ride + Vector3(0, 2.3, -3.0))
	_collider(e, "RideSideW", Vector3(0.4, 4.6, 6.2), ride + Vector3(-3.5, 2.3, 0))
	_collider(e, "RideSideE", Vector3(0.4, 4.6, 6.2), ride + Vector3(3.5, 2.3, 0))
	_isle_rock("RideRock", Vector3(6.0, -DECK_T, -20.0), Vector3(5.5, 8.0, 6.0))
	# 2. Balloon basket (west of the hub): a landing pad and a tethered balloon.
	_deck(e, "BalloonPad", PackedVector2Array([Vector2(-21.5, 3.5), Vector2(-15.5, 3.5), Vector2(-15.5, 9.5), Vector2(-21.5, 9.5)]), 0.0, deck)
	_isle_rock("BalloonRock", Vector3(-18.5, -DECK_T, 6.5), Vector3(3.5, 5.0, 3.5))
	var basket := Vector3(-20.2, 0.0, 6.8)
	_balloon(e, "TetheredBalloon", basket, Color(0.12, 0.71, 0.69), Color(1.0, 0.95, 0.88), false)
	_collider(e, "BasketCollision", Vector3(1.6, 1.1, 1.6), basket + Vector3(0, 0.55, 0))
	_rails_round(e, "BalloonPad", PackedVector2Array([Vector2(-15.5, 3.5), Vector2(-21.5, 3.5), Vector2(-21.5, 9.5), Vector2(-15.5, 9.5)]), false, false)
	# 3. Cargo lift (south): the cage sits level with the hub deck.
	_deck(e, "CargoPad", PackedVector2Array([Vector2(5.4, 13.5), Vector2(9.6, 13.5), Vector2(9.6, 19.0), Vector2(5.4, 19.0)]), 0.0, deck)
	var lift := Vector3(7.5, -0.13, 17.0)
	_prop(e, "sky_cargo_lift", "CargoLift", lift, 180.0, Vector3(3.4, 5, 3.4))
	_collider(e, "LiftBack", Vector3(3.6, 2.6, 0.3), lift + Vector3(0, 1.3, 1.65))
	_collider(e, "LiftGantry", Vector3(4.6, 5.4, 0.4), lift + Vector3(0, 2.7, 2.0))
	_isle_rock("CargoRock", Vector3(7.5, -DECK_T, 16.5), Vector3(3.0, 5.0, 3.5))
	_rails_round(e, "CargoPad", PackedVector2Array([Vector2(5.4, 14.0), Vector2(5.4, 19.0), Vector2(9.6, 19.0), Vector2(9.6, 14.0)]), false, false)
	# 4. Backstage wagon (east of the big top).
	var bx := BIGTOP.x + BIGTOP_APOTHEM
	_deck(e, "BackstagePad", PackedVector2Array([Vector2(bx - 0.5, -3.0), Vector2(bx + 7.0, -3.0), Vector2(bx + 7.0, 5.0), Vector2(bx - 0.5, 5.0)]), 0.0, deck)
	_isle_rock("BackstageRock", Vector3(bx + 3.5, -DECK_T, 1.0), Vector3(5.0, 7.0, 5.0))
	_solid_prop(e, "sky_wagon", "Wagon", Vector3(bx + 4.8, 0, -0.6), 90.0, Vector3(4.6, 3.0, 2.2))
	_rails_round(e, "BackstagePad", PackedVector2Array([Vector2(bx, -3.0), Vector2(bx + 7.0, -3.0), Vector2(bx + 7.0, 5.0), Vector2(bx, 5.0)]), false, false)
	# 5. The airship gangway (west, at the boarding-deck level).
	var g0 := Vector3(-51.2, UPPER_Y, -2.0)
	var g1 := Vector3(-42.0, UPPER_Y, -2.0)
	_box(e, "Gangway", Vector3(g1.x - g0.x, 0.3, 3.0), Vector3((g0.x + g1.x) * 0.5, UPPER_Y - 0.15, g0.z), deck)
	for s in [-1.0, 1.0]:
		_fence_run(e, "GangwayRail%d" % int(s), Vector3(g0.x, UPPER_Y, g0.z + s * 1.45), Vector3(g1.x, UPPER_Y, g0.z + s * 1.45))
	_visual_box(dressing, "GangwayKeel", Vector3(g1.x - g0.x, 0.4, 0.5), Vector3((g0.x + g1.x) * 0.5, UPPER_Y - 0.5, g0.z), _mat("navy", Color(0.17, 0.23, 0.4), 0.6))


## A hot-air balloon with recoloured gores (its own nodes, so the colours save).
func _balloon(parent: Node3D, balloon_name: String, pos: Vector3, a: Color, b: Color, drift: bool) -> Node3D:
	var holder := Node3D.new()
	holder.name = balloon_name
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = fposmod(pos.x * 0.7, TAU)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var mesh := _model_mesh("sky_balloon")
	mi.mesh = mesh
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m and m.resource_name == "SkyBalloonA":
			mi.set_surface_override_material(i, _mat("balloon_%s" % a.to_html(false), a, 0.5))
		elif m and m.resource_name == "SkyBalloonB":
			mi.set_surface_override_material(i, _mat("balloon_%s" % b.to_html(false), b, 0.5))
	holder.add_child(mi)
	if drift:
		_late(holder, "res://scripts/props/ambient_motion.gd", {"bob_height": 1.5, "bob_seconds": 7.0 + fposmod(pos.z, 4.0), "rock_degrees": 2.0})
	return holder


# ---------------------------------------------------------------------------
# The airship Cumulus and its mooring tower
# ---------------------------------------------------------------------------

func _build_airship() -> void:
	var rig := Node3D.new()
	rig.name = "AirshipRig"
	dressing.add_child(rig)
	rig.position = AIRSHIP
	_late(rig, "res://scripts/props/ambient_motion.gd", {"bob_height": 0.12, "bob_seconds": 9.0, "rock_degrees": 0.25})
	_prop(rig, "sky_airship", "Airship", Vector3.ZERO, 0.0, Vector3(14, 14, 56))
	for k in 4:
		var y := [4.0, 4.0, -6.0, -6.0][k] as float
		var s := -1.0 if k % 2 == 0 else 1.0
		var pod := Vector3(s * 6.4, -7.0 - 3.8 + 1.8 + 1.6, -y)
		var prop := _prop(rig, "sky_propeller", "Propeller%d" % k, pod + Vector3(0, 0, -1.6), 0.0, Vector3(3.4, 3.4, 0.2))
		_late(prop, "res://scripts/props/sky_spinner.gd", {"axis": Vector3.BACK, "degrees_per_second": 300.0 + k * 20.0})
	var tower := Vector3(AIRSHIP.x, -0.8, AIRSHIP.z + 28.0 + 1.3 + 1.4)
	_prop(dressing, "sky_mooring_tower", "MooringTower", tower, 0.0, Vector3(4, 16, 4))
	_isle_rock("TowerRock", tower, Vector3(4.5, 9.0, 4.5))


# ---------------------------------------------------------------------------
# The sky ride: cabins gliding from the station north to a far island
# ---------------------------------------------------------------------------

func _build_sky_ride() -> void:
	var ride := Node3D.new()
	ride.name = "SkyRide"
	dressing.add_child(ride)
	var wheel := Vector3(6.0, 7.2, -23.9)
	var far := Vector3(30.0, 46.0, -330.0)
	var side := Vector3(1, 0, 0)
	var path := PackedVector3Array([wheel - side * 2.3, far - side * 2.3, far + side * 2.3, wheel + side * 2.3])
	for i in 2:
		var a := path[0] if i == 0 else path[3]
		var b := path[1] if i == 0 else path[2]
		var cable := MeshInstance3D.new()
		cable.name = "Cable%d" % i
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.04
		cyl.height = 1.0
		cyl.radial_segments = 4
		cyl.rings = 1
		cyl.material = _mat("cable", Color(0.25, 0.27, 0.36), 0.5)
		cable.mesh = cyl
		cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ride.add_child(cable)
		var dir := b - a
		var y := dir.normalized()
		var x := y.cross(Vector3.RIGHT).normalized()
		cable.transform = Transform3D(Basis(x, y * dir.length(), x.cross(y)), (a + b) * 0.5)
	var carriers := Node3D.new()
	carriers.name = "Cabins"
	ride.add_child(carriers)
	for k in 12:
		_prop(carriers, "sky_ride_cabin", "Cabin%02d" % k, Vector3.ZERO, 0.0, Vector3(2, 3.5, 2))
	_late(carriers, "res://scripts/props/frost_lift.gd", {"path": path, "speed": 3.2})
	var isle := _prop(dressing, "sky_far_isle", "RideIsle", far + Vector3(0, -12.0, -10.0), 30.0, Vector3(36, 30, 36))
	isle.scale = Vector3.ONE * 0.9


# ---------------------------------------------------------------------------
# Lights
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	var lights := Node3D.new()
	lights.name = "WarmLights"
	level.add_child(lights)
	_omni(lights, "StationGlow", STATION + Vector3(0, 3.5, 3.0), Color(1.0, 0.82, 0.6), 1.2, 9.0)
	_omni(lights, "RideGlow", Vector3(6.0, 3.2, -18.5), Color(1.0, 0.8, 0.55), 1.2, 8.0)
	_omni(lights, "GondolaGlow", AIRSHIP + Vector3(4.0, -9.0, 0.0), Color(1.0, 0.85, 0.6), 1.6, 10.0)
	_omni(lights, "CarouselGlow", Vector3(-9.5, 4.0, 6.0), Color(1.0, 0.85, 0.6), 1.0, 8.0)


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


# ---------------------------------------------------------------------------
# Backdrop: the cloud sea, cloud banks, far islands, balloons, other airships
# ---------------------------------------------------------------------------

func _build_backdrop() -> void:
	var back := Node3D.new()
	back.name = "Backdrop"
	dressing.add_child(back)
	var sea := MeshInstance3D.new()
	sea.name = "CloudSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(5000.0, 5000.0)
	sea.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = load(SHADERS + "sky_cloud_sea.gdshader")
	sm.set_shader_parameter("sun_direction", Vector2(SUN_DIRECTION.x, SUN_DIRECTION.z).normalized())
	sea.material_override = sm
	sea.position = Vector3(0, -48.0, 0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.add_to_group("sky_cloud_sea", true)
	back.add_child(sea)
	_build_cloud_banks(back)
	var isles := [[Vector3(-260, 30, -360), 1.2, 20.0, true], [Vector3(280, 12, -300), 0.9, 140.0, false], [Vector3(420, 50, 120), 1.4, 70.0, true],
		[Vector3(-420, 18, 160), 1.1, 200.0, false], [Vector3(-120, -10, 420), 0.8, 300.0, true], [Vector3(150, 40, 380), 1.0, 250.0, false]]
	var i := 0
	for isle in isles:
		var node := _prop(back, "sky_far_isle", "FarIsle%d" % i, isle[0], isle[2], Vector3(36, 30, 36))
		node.scale = Vector3.ONE * isle[1]
		if isle[3]:
			var base: Vector3 = isle[0] + Vector3(6.0, 0.6, 4.0) * isle[1]
			var tower := _prop(back, "sky_turbine", "FarTurbine%d" % i, base, isle[2], Vector3(1, 10, 1))
			tower.scale = Vector3.ONE * isle[1] * 1.4
			var rotor := _prop(back, "sky_turbine_rotor", "FarRotor%d" % i, base + Basis(Vector3.UP, deg_to_rad(isle[2])) * Vector3(0, 10.2, 1.0) * isle[1] * 1.4,
				isle[2], Vector3(8, 8, 0.2))
			rotor.scale = Vector3.ONE * isle[1] * 1.4
			_late(rotor, "res://scripts/props/sky_spinner.gd", {"axis": Vector3.BACK, "degrees_per_second": 50.0})
		i += 1
	# Hot-air balloons drifting round the harbour.
	var balloons := [[Vector3(-90, 26, -120), Color(0.91, 0.22, 0.31), Color(1.0, 0.81, 0.35)], [Vector3(110, 18, -90), Color(0.12, 0.71, 0.69), Color(1.0, 0.95, 0.88)],
		[Vector3(150, 44, 60), Color(0.71, 0.6, 0.91), Color(1.0, 0.95, 0.88)], [Vector3(-140, 12, 80), Color(1.0, 0.56, 0.71), Color(0.56, 0.82, 1.0)],
		[Vector3(40, 60, -200), Color(1.0, 0.81, 0.35), Color(0.91, 0.22, 0.31)], [Vector3(-60, 34, 160), Color(0.56, 0.89, 0.72), Color(1.0, 0.95, 0.88)],
		[Vector3(230, 70, -160), Color(0.91, 0.22, 0.31), Color(1.0, 0.95, 0.88)]]
	i = 0
	for bl in balloons:
		var node := _balloon(back, "Balloon%d" % i, bl[0], bl[1], bl[2], true)
		node.scale = Vector3.ONE * (1.3 + fposmod(i * 0.37, 0.8))
		i += 1
	# Two more airships far off.
	for entry in [[Vector3(-300, 60, -120), 0.45, 75.0], [Vector3(260, 35, 230), 0.35, -30.0]]:
		var ship := _prop(back, "sky_airship", "FarAirship%d" % i, entry[0], entry[2], Vector3(14, 14, 56))
		ship.scale = Vector3.ONE * entry[1]
		_late(ship, "res://scripts/props/ambient_motion.gd", {"bob_height": 1.0, "bob_seconds": 11.0, "rock_degrees": 0.5})
		i += 1


## Puffy cloud cards round the islands: a ring below the decks and banks far out.
func _build_cloud_banks(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 0.6)
	quad.center_offset = Vector3(0, 0.3, 0)
	var mats: Array[ShaderMaterial] = []
	for k in 6:
		var m := ShaderMaterial.new()
		m.shader = load(SHADERS + "sky_cloud.gdshader")
		m.set_shader_parameter("seed", k * 1.37)
		m.set_shader_parameter("drift", 0.01 + k * 0.004)
		mats.append(m)
	var count := 0
	for ring in [[60.0, 140.0, -42.0, -18.0, 22, Vector2(40, 80)], [180.0, 420.0, -40.0, 30.0, 26, Vector2(90, 200)],
			[500.0, 900.0, -45.0, 10.0, 18, Vector2(220, 420)]]:
		for k in int(ring[4]):
			var a: float = TAU * k / float(ring[4]) + rng.randf_range(-0.12, 0.12)
			var d: float = rng.randf_range(ring[0], ring[1])
			var size: float = rng.randf_range(ring[5].x, ring[5].y)
			var mi := MeshInstance3D.new()
			mi.name = "Cloud%02d" % count
			mi.mesh = quad
			mi.material_override = mats[count % mats.size()]
			mi.position = Vector3(cos(a) * d, rng.randf_range(ring[2], ring[3]), sin(a) * d)
			mi.scale = Vector3(size, size, 1.0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
			count += 1


func _model_mesh(model: String) -> Mesh:
	if _mesh_cache.has(model):
		return _mesh_cache[model]
	var source: Node3D = (load(MODELS + model + ".glb") as PackedScene).instantiate()
	var mesh: Mesh = (source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	source.free()
	_mesh_cache[model] = mesh
	return mesh


# ---------------------------------------------------------------------------
# Exit: the portal on the south lookout and the lantern trail to it
# ---------------------------------------------------------------------------

func _build_exit() -> void:
	var portal: Node3D = (load("res://scenes/props/sky_portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	geo.add_child(portal)
	portal.position = PORTAL
	portal.rotation.y = PI
	var lights := Node3D.new()
	lights.name = "ExitLights"
	level.add_child(lights)
	var a := STATION + Vector3(0.0, 0, 7.6)
	var b := PORTAL + Vector3(0, 0, -2.4)
	var steps := 4
	for k in steps:
		var t := float(k) / (steps - 1)
		for s in [-1.0, 1.0]:
			var pos := a.lerp(b, t) + Vector3(s * 2.4, 0, 0)
			var lantern := _prop(lights, "sky_exit_lantern", "ExitLantern%02d%s" % [k, "L" if s < 0 else "R"], pos, k * 23.0, Vector3(0.2, 1.6, 0.2))
			_late(lantern, "res://scripts/props/sky_exit_lantern.gd", {"order": k})


# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(2.5, 0.1, 10.5)
	start.rotation.y = deg_to_rad(4.0)
	start.add_to_group("player_spawn", true)
	level.add_child(start)

	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	var points := {
		"SpawnGangway": [Vector3(-48.5, UPPER_Y + 0.1, -2.0), -90.0],
		"SpawnSkyRide": [Vector3(6.0, 0.1, -20.0), 0.0],
		"SpawnBackstage": [Vector3(BIGTOP.x + BIGTOP_APOTHEM + 2.5, 0.1, 2.5), 90.0],
		"SpawnBalloon": [Vector3(-18.6, 0.1, 5.2), -90.0],
		"SpawnCargoLift": [Vector3(7.5, 0.1, 17.0), 180.0],
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
	mesh.filter_baking_aabb = AABB(Vector3(-56, -1.0, -26), Vector3(116, UPPER_Y + 2.2, 50))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	region.navigation_mesh = _largest_island(mesh)
	print("build_sky_harbor: navmesh polygons = %d (dropped %d on islands)" % [region.navigation_mesh.get_polygon_count(),
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


## A thin upright wall collider from a to b (tent canvas, ring kerb).
func _wall_segment(parent: Node3D, wall_name: String, a: Vector3, b: Vector3, height: float, thick: float) -> void:
	var body := _collider(parent, wall_name, Vector3(a.distance_to(b) + thick * 0.5, height, thick), (a + b) * 0.5 + Vector3(0, height * 0.5, 0))
	var dir := (b - a).normalized()
	body.rotation.y = atan2(-dir.z, dir.x)


## A stair run from `top` down to `bottom` (along X or Z), `width` wide: a
## sloped collider under visual steps, side stringers and rails.
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
	var tread := _mat("stair_tread", Color(0.85, 0.6, 0.38), 0.75)
	for k in steps:
		var h := rise - (k + 1) * rise / steps
		var mi := MeshInstance3D.new()
		mi.name = "Step%d" % k
		mi.mesh = _box_mesh(Vector3(length / steps + 0.02, rise / steps, width), tread if k % 2 == 0 else _mat("stair_tread_b", Color(0.78, 0.53, 0.33), 0.75))
		mi.position = Vector3(-length * 0.5 + length / steps * (k + 0.5), h + rise / steps * 0.5 - rise * 0.5, 0)
		body.add_child(mi)
		if h > 0.01:
			var fill := MeshInstance3D.new()
			fill.name = "Riser%d" % k
			fill.mesh = _box_mesh(Vector3(length / steps + 0.02, h, width - 0.02), _mat("boarding_wall", Color(0.98, 0.93, 0.86), 0.7))
			fill.position = Vector3(-length * 0.5 + length / steps * (k + 0.5), h * 0.5 - rise * 0.5, 0)
			body.add_child(fill)
	for s in [-1.0, 1.0]:
		var side := StaticBody3D.new()
		side.name = "%sSide%d" % [stair_name, int(s)]
		parent.add_child(side)
		side.position = (top + bottom) * 0.5 + Vector3(-dir.z, 0, dir.x) * s * (width * 0.5 + 0.1)
		side.rotation.y = yaw
		var wedge := CollisionShape3D.new()
		wedge.name = "CollisionShape3D"
		var convex := ConvexPolygonShape3D.new()
		var pts := PackedVector3Array()
		for zz in [-0.1, 0.1]:
			pts.append(Vector3(-length * 0.5, top.y - (top.y + bottom.y) * 0.5 + 1.1, zz))
			pts.append(Vector3(-length * 0.5, -rise * 0.5, zz))
			pts.append(Vector3(length * 0.5, -rise * 0.5, zz))
			pts.append(Vector3(length * 0.5, -rise * 0.5 + 1.1, zz))
		convex.points = pts
		wedge.shape = convex
		side.add_child(wedge)
		var rail := _module_row("Rail", "sky_rail", sqrt(length * length + rise * rise), 2.5)
		rail.rotation.z = -angle
		side.add_child(rail)


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


## A run of carnival railing modules with one collision box (blocks walking).
func _fence_run(parent: Node3D, run_name: String, a: Vector3, b: Vector3) -> void:
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
	box.size = Vector3(length, 1.15, 0.3)
	shape.shape = box
	shape.position.y = 0.575
	body.add_child(shape)
	body.add_child(_module_row("Modules", "sky_rail", length, 2.5))


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
