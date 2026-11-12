extends SceneTree
## Blockout generator for World 1 / Level 1 "Prize Pier".
##
## Rebuilds scenes/levels/prize_pier.tscn from the layout below: deck, rails,
## props, spawn markers, kiosk, portal, lighting and a baked navigation mesh.
## The result is an ordinary scene you can keep editing in Godot.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_prize_pier.gd
##
## Run it with a renderer (not --headless): MultiMesh instance data (string
## lights) is only stored when a real rendering server is present.
##
## NOTE: running this overwrites hand edits made to prize_pier.tscn.
##
## Layout (metres, top view; +X = ocean side, -Z = away from the start):
##   - Prize kiosk at the origin, the hub of the circulation loop.
##   - Wide midway on the ride side (-X), rail-side stretch on the ocean side (+X).
##   - Exit spur runs off the far-right corner to the portal.
##   - Zombie entrances sit beyond the loop: arcade (left-front), Ferris wheel
##     gate (left-back), service ramp (back) and the pier entrance (front).

const OUT_PATH := "res://scenes/levels/prize_pier.tscn"
const MODELS := "res://art/models/"
const DECK_TOP := 0.0
const DECK_THICK := 0.8

# Main deck bounds.
const X0 := -25.0
const X1 := 14.0
const Z0 := -24.0
const Z1 := 22.0
# Exit spur.
const SPUR_X0 := 8.0
const SPUR_Z0 := -54.0
# The Ferris wheel on its own platform beyond the ride gate.
const WHEEL_POS := Vector3(-34.0, 0.0, -29.0)
const WHEEL_YAW := 42.0
const WHEEL_SCALE := 1.12
## Lamp posts stand in the rail line (their bases are part of the fence), so
## nothing sticks out for the player to snag on while running along a rail.
## Each entry: rail start, rail end, wanted spot along it, yaw of the arm
## (which reaches inward over the deck), true to keep the spot exactly.
## Otherwise the post moves to the nearest seam between two rail modules.
const LAMPS := [
	[Vector3(X1, 0, SPUR_Z0), Vector3(X1, 0, Z1), Vector3(X1, 0, 14.0), 180.0, false],
	[Vector3(X1, 0, SPUR_Z0), Vector3(X1, 0, Z1), Vector3(X1, 0, 0.0), 180.0, false],
	[Vector3(X1, 0, SPUR_Z0), Vector3(X1, 0, Z1), Vector3(X1, 0, -14.0), 180.0, false],
	[Vector3(X1, 0, SPUR_Z0), Vector3(X1, 0, Z1), Vector3(X1, 0, -28.0), 180.0, false],
	[Vector3(X1, 0, SPUR_Z0), Vector3(X1, 0, Z1), Vector3(X1, 0, -42.0), 180.0, false],
	[Vector3(SPUR_X0, 0, SPUR_Z0), Vector3(SPUR_X0, 0, Z0), Vector3(SPUR_X0, 0, -35.0), 0.0, false],
	[Vector3(SPUR_X0, 0, SPUR_Z0), Vector3(SPUR_X0, 0, Z0), Vector3(SPUR_X0, 0, -49.0), 0.0, false],
	# Front-left corner post, its arm on the diagonal.
	[Vector3(X0, 0, 18.0), Vector3(X0, 0, Z1), Vector3(X0, 0, Z1), 45.0, true],
	[Vector3(X0, 0, Z0), Vector3(X0, 0, -19.0), Vector3(X0, 0, -21.5), 0.0, false],
	# Between the two game booths.
	[Vector3(X0, 0, -7.0), Vector3(X0, 0, 4.0), Vector3(X0, 0, -1.1), 0.0, true],
	[Vector3(X0, 0, Z0), Vector3(-13.0, 0, Z0), Vector3(-16.0, 0, Z0), -90.0, false],
	[Vector3(-7.0, 0, Z0), Vector3(SPUR_X0, 0, Z0), Vector3(-3.0, 0, Z0), -90.0, false],
	[Vector3(-7.0, 0, Z0), Vector3(SPUR_X0, 0, Z0), Vector3(5.0, 0, Z0), -90.0, false],
	[Vector3(X0, 0, Z1), Vector3(-8.0, 0, Z1), Vector3(-14.0, 0, Z1), 90.0, false],
	[Vector3(2.0, 0, Z1), Vector3(X1, 0, Z1), Vector3(7.0, 0, Z1), 90.0, false],
]
const RAIL_MODULE := 3.0

var level: Node3D
var geo: Node3D          # collidable geometry (navmesh source)
var dressing: Node3D     # non-colliding scenery
var _materials := {}
var _boxes := {}
var _box_shapes := {}


func _initialize() -> void:
	level = Node3D.new()
	level.name = "PrizePier"

	_build_environment()
	_build_ocean()

	var nav := NavigationRegion3D.new()
	nav.name = "NavigationRegion3D"
	level.add_child(nav)
	geo = Node3D.new()
	geo.name = "Geometry"
	nav.add_child(geo)
	dressing = Node3D.new()
	dressing.name = "Dressing"
	level.add_child(dressing)

	_build_decks()
	_build_rails()
	_build_entrances()
	_build_arena_props()
	_build_exit()
	_build_backdrop()
	_build_set_dressing()
	_build_string_lights()
	_build_deck_paint()
	_build_markers()

	# Navigation needs the nodes in the tree for their global transforms.
	get_root().add_child(level)
	await process_frame
	_bake_navigation(nav)
	get_root().remove_child(level)

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
	print("build_prize_pier: saved %s (error %d)" % [OUT_PATH, err])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_texture_path := "res://art/textures/sky_sunset.png"
	if ResourceLoader.exists(sky_texture_path):
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(sky_texture_path)
		pano.energy_multiplier = 0.92
		sky.sky_material = pano
	else:
		var proc := ProceduralSkyMaterial.new()
		proc.sky_top_color = Color(0.2, 0.36, 0.86)
		proc.sky_horizon_color = Color(1.0, 0.62, 0.62)
		proc.ground_horizon_color = Color(1.0, 0.62, 0.62)
		proc.ground_bottom_color = Color(0.1, 0.25, 0.45)
		sky.sky_material = proc
	env.sky = sky
	# Rotate the panorama so its sun sits over the ocean, ahead and to the right.
	env.sky_rotation = Vector3(0.0, deg_to_rad(SKY_YAW_DEGREES), 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.5, 0.84)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.tonemap_exposure = 0.92
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.6, 0.66)
	env.fog_density = 0.0007
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	# The visible sun is on the horizon ahead-right; the key light comes from the
	# same compass direction but higher, so shadows stay readable.
	var azimuth := deg_to_rad(SUN_AZIMUTH_DEGREES)
	var elevation := deg_to_rad(30.0)
	var to_sun := Vector3(sin(azimuth) * cos(elevation), sin(elevation), -cos(azimuth) * cos(elevation))
	sun.transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP), Vector3(0, 30, 0))
	sun.light_color = Color(1.0, 0.8, 0.62)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_opacity = 0.75
	level.add_child(sun)

	# Soft pink fill from the opposite side, no shadows.
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.transform = Transform3D(Basis.looking_at(Vector3(-0.35, -0.4, -0.85).normalized(), Vector3.UP), Vector3(0, 30, 0))
	fill.light_color = Color(1.0, 0.62, 0.8)
	fill.light_energy = 0.34
	fill.shadow_enabled = false
	level.add_child(fill)

const SUN_AZIMUTH_DEGREES := 24.0   # 0 = straight ahead (-Z), 90 = right (+X)
## The panorama's sun is at its centre, which Godot maps to +Z before rotation.
const SKY_YAW_DEGREES := 180.0 - SUN_AZIMUTH_DEGREES


func _build_ocean() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 1400)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	var ocean := MeshInstance3D.new()
	ocean.name = "Ocean"
	ocean.mesh = plane
	ocean.position = Vector3(0, -4.2, 0)
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader_path := "res://art/shaders/ocean.gdshader"
	if ResourceLoader.exists(shader_path):
		var m := ShaderMaterial.new()
		m.shader = load(shader_path)
		var az := deg_to_rad(SUN_AZIMUTH_DEGREES)
		m.set_shader_parameter("sun_direction", Vector2(sin(az), -cos(az)))
		ocean.material_override = m
	else:
		ocean.material_override = _mat("ocean", Color(0.08, 0.42, 0.6), 0.15)
	level.add_child(ocean)


# ---------------------------------------------------------------------------
# Decks and rails
# ---------------------------------------------------------------------------

func _build_decks() -> void:
	var decks := Node3D.new()
	decks.name = "Decks"
	geo.add_child(decks)
	_deck(decks, "MainDeck", X0, X1, Z0, Z1)
	_deck(decks, "ExitSpur", SPUR_X0, X1, SPUR_Z0, Z0)
	_deck(decks, "ArcadeFloor", -33.0, X0, 4.0, 18.0)
	_deck(decks, "RidePlatform", -33.0, X0, -19.0, -7.0)
	_deck(decks, "EntranceWalk", -8.0, 2.0, Z1, 33.0)

	# Service ramp: slopes down from the back edge to a lower landing.
	var ramp_len := 12.0
	var drop := 2.6
	var slope_len := sqrt(ramp_len * ramp_len + drop * drop)
	var angle := atan2(drop, ramp_len)
	var ramp := _box(decks, "ServiceRamp", Vector3(6.0, DECK_THICK, slope_len), Vector3.ZERO, _deck_material())
	ramp.rotation.x = -angle
	# Place so the top surface meets the deck edge at Z0 and the landing below.
	var top_mid := Vector3(-10.0, -drop * 0.5, Z0 - ramp_len * 0.5)
	var normal := Vector3(0, cos(angle), -sin(angle))
	ramp.position = top_mid - normal * (DECK_THICK * 0.5)
	_deck(decks, "RampLanding", -13.0, -7.0, Z0 - ramp_len - 5.0, Z0 - ramp_len, -drop)

	_build_pylons(angle)


## Pier pylons under every deck, the ramp, its landing and the Ferris wheel's
## platform, so nothing hangs over the water (scenery only, one MultiMesh).
func _build_pylons(ramp_angle: float) -> void:
	var under := -DECK_THICK
	# [x, z, height of the underside it carries]
	var spots: Array = []
	for x in range(-24, 15, 7):
		for z in range(-52, 23, 7):
			if z < -24 and x < 9:
				continue
			spots.append(Vector3(x, under, z))
	for z in [5.5, 11.0, 16.5, -17.5, -13.0, -8.5]:        # arcade floor, ride platform
		spots.append(Vector3(-31.5, under, z))
	for p in [Vector2(-31.5, -25.5), Vector2(-26.5, -25.5)]:  # walkway to the wheel
		spots.append(Vector3(p.x, under, p.y))
	for z in [25.5, 29.0]:                                    # entrance walk
		for x in [-6.6, 0.6]:
			spots.append(Vector3(x, under, z))
	for x in [-12.1, -7.9]:
		for z in [-28.5, -33.0]:                               # service ramp
			spots.append(Vector3(x, (Z0 - z) * -tan(ramp_angle) - DECK_THICK / cos(ramp_angle), z))
		spots.append(Vector3(x, -2.6 - DECK_THICK, Z0 - 15.0))  # ramp landing
	var wheel := Transform3D(Basis(Vector3.UP, deg_to_rad(WHEEL_YAW)).scaled(Vector3.ONE * WHEEL_SCALE), WHEEL_POS)
	for x in [-10.5, 0.0, 10.5]:
		for z in [-3.4, 3.4]:
			var p: Vector3 = wheel * Vector3(x, 0, z)
			spots.append(Vector3(p.x, -0.8 * WHEEL_SCALE, p.z))
	var pylon_mesh := CylinderMesh.new()
	pylon_mesh.top_radius = 0.42
	pylon_mesh.bottom_radius = 0.5
	pylon_mesh.height = 7.0
	pylon_mesh.radial_segments = 10
	pylon_mesh.material = _mat("pylon", Color(0.36, 0.22, 0.2), 0.9)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = pylon_mesh
	mm.instance_count = spots.size()
	for i in spots.size():
		var s: Vector3 = spots[i]
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(s.x, s.y - 3.5, s.z)))
	var pylons := MultiMeshInstance3D.new()
	pylons.name = "Pylons"
	pylons.multimesh = mm
	dressing.add_child(pylons)


func _deck(parent: Node3D, deck_name: String, x0: float, x1: float, z0: float, z1: float, top := DECK_TOP) -> void:
	var size := Vector3(x1 - x0, DECK_THICK, z1 - z0)
	var pos := Vector3((x0 + x1) * 0.5, top - DECK_THICK * 0.5, (z0 + z1) * 0.5)
	_box(parent, deck_name, size, pos, _deck_material())


func _deck_material() -> StandardMaterial3D:
	if _materials.has("deck"):
		return _materials["deck"]
	var m := StandardMaterial3D.new()
	m.resource_name = "DeckWood"
	var tex_path := "res://art/textures/deck_planks.png"
	if ResourceLoader.exists(tex_path):
		m.albedo_texture = load(tex_path)
		m.albedo_color = Color(1, 1, 1)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.25, 0.25, 0.25)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var normal_path := "res://art/textures/deck_planks_normal.png"
		if ResourceLoader.exists(normal_path):
			m.normal_enabled = true
			m.normal_texture = load(normal_path)
			m.normal_scale = 0.8
	else:
		m.albedo_color = Color(0.6, 0.36, 0.3)
	m.roughness = 0.68
	m.metallic_specular = 0.3
	_materials["deck"] = m
	return m


func _build_rails() -> void:
	var rails := Node3D.new()
	rails.name = "Rails"
	geo.add_child(rails)
	# Ocean side: one continuous run from the portal end to the front corner.
	_rail(rails, "RailOcean", Vector3(X1, 0, SPUR_Z0), Vector3(X1, 0, Z1))
	# Front edge, either side of the pier entrance.
	_rail(rails, "RailFrontLeft", Vector3(X0, 0, Z1), Vector3(-8.0, 0, Z1))
	_rail(rails, "RailFrontRight", Vector3(2.0, 0, Z1), Vector3(X1, 0, Z1))
	_rail(rails, "RailEntranceL", Vector3(-8.0, 0, Z1), Vector3(-8.0, 0, 33.0))
	_rail(rails, "RailEntranceR", Vector3(2.0, 0, Z1), Vector3(2.0, 0, 33.0))
	# Back edge: ramp opening at X -13..-7, spur opening at X 8..14.
	_rail(rails, "RailBackLeft", Vector3(X0, 0, Z0), Vector3(-13.0, 0, Z0))
	_rail(rails, "RailBackMid", Vector3(-7.0, 0, Z0), Vector3(SPUR_X0, 0, Z0))
	# Exit spur.
	_rail(rails, "RailSpurLeft", Vector3(SPUR_X0, 0, SPUR_Z0), Vector3(SPUR_X0, 0, Z0))
	_rail(rails, "RailSpurEnd", Vector3(SPUR_X0, 0, SPUR_Z0), Vector3(X1, 0, SPUR_Z0))
	# Ride side (left edge), between the entrances.
	_rail(rails, "RailLeftBack", Vector3(X0, 0, Z0), Vector3(X0, 0, -19.0))
	_rail(rails, "RailLeftMid", Vector3(X0, 0, -7.0), Vector3(X0, 0, 4.0))
	_rail(rails, "RailLeftFront", Vector3(X0, 0, 18.0), Vector3(X0, 0, Z1))
	# Ride platform surround.
	_rail(rails, "RailRideBack", Vector3(-33.0, 0, -19.0), Vector3(X0, 0, -19.0))
	_rail(rails, "RailRideFront", Vector3(-33.0, 0, -7.0), Vector3(X0, 0, -7.0))
	# Ramp sides and landing (low walls that follow the slope).
	var ramp_walls := Node3D.new()
	ramp_walls.name = "RampWalls"
	geo.add_child(ramp_walls)
	var teal := _mat("teal", Color(0.09, 0.56, 0.58), 0.55)
	for side in [-13.0, -7.0]:
		var wall := _box(ramp_walls, "RampWall%s" % ("L" if side < -10.0 else "R"), Vector3(0.3, 1.3, 12.4), Vector3(side, -0.65, Z0 - 6.0), teal)
		wall.rotation.x = -atan2(2.6, 12.0)
		_player_wall(wall, Vector3(0.3, 3.4, 12.4))
		var landing := _box(ramp_walls, "LandingWall%s" % ("L" if side < -10.0 else "R"), Vector3(0.3, 1.3, 5.0), Vector3(side, -2.6 + 0.65, Z0 - 14.5), teal)
		_player_wall(landing, Vector3(0.3, 3.4, 5.0))


## A rail run: repeated rail modules plus one collision box.
func _rail(parent: Node3D, rail_name: String, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 0.5:
		return
	var body := StaticBody3D.new()
	body.name = rail_name
	parent.add_child(body)
	body.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	body.rotation.y = atan2(-dir.z, dir.x)      # local +X runs along the rail
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(length, 1.25, 0.3)
	shape.shape = box
	shape.position.y = 0.625
	body.add_child(shape)
	# Invisible wall on its own layer ("player_walls"): stops the player from
	# jumping over the rail, but not shots, zombies or navigation.
	var wall := StaticBody3D.new()
	wall.name = "PlayerWall"
	wall.collision_layer = 16
	wall.collision_mask = 0
	body.add_child(wall)
	var wall_shape := CollisionShape3D.new()
	wall_shape.name = "CollisionShape3D"
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(length, 3.4, 0.3)
	wall_shape.shape = wall_box
	wall_shape.position.y = 1.7
	wall.add_child(wall_shape)
	var module_path := MODELS + "rail.glb"
	var module_len := RAIL_MODULE
	var count := maxi(1, int(round(length / module_len)))
	var step := length / count
	for i in count:
		var x := -length * 0.5 + step * (i + 0.5)
		if ResourceLoader.exists(module_path):
			var m: Node3D = (load(module_path) as PackedScene).instantiate()
			m.name = "Module%02d" % i
			m.position = Vector3(x, 0, 0)
			m.scale = Vector3(step / module_len, 1, 1)
			body.add_child(m)
		else:
			var mi := MeshInstance3D.new()
			mi.name = "Module%02d" % i
			mi.mesh = _box_mesh(Vector3(step - 0.1, 1.1, 0.12), _mat("teal", Color(0.09, 0.56, 0.58), 0.55))
			mi.position = Vector3(x, 0.55, 0)
			body.add_child(mi)


# ---------------------------------------------------------------------------
# Zombie entrances (all beyond the main walking loop)
# ---------------------------------------------------------------------------

func _build_entrances() -> void:
	var entrances := Node3D.new()
	entrances.name = "Entrances"
	geo.add_child(entrances)

	# 1. Arcade: open-front stall on the left-front. Zombies emerge from inside.
	_prop(entrances, "arcade", "Arcade", Vector3(-29.0, 0, 11.0), 90.0, Vector3(14, 6, 8))
	_collider(entrances, "ArcadeBack", Vector3(0.4, 6, 14), Vector3(-33.0, 3, 11.0))
	_collider(entrances, "ArcadeSideA", Vector3(8, 6, 0.4), Vector3(-29.0, 3, 4.0))
	_collider(entrances, "ArcadeSideB", Vector3(8, 6, 0.4), Vector3(-29.0, 3, 18.0))
	_collider(entrances, "ArcadeFrontA", Vector3(0.6, 6, 1.6), Vector3(X0, 3, 4.8))
	_collider(entrances, "ArcadeFrontB", Vector3(0.6, 6, 1.6), Vector3(X0, 3, 17.2))

	# 2. Ferris wheel gate on the left-back, leading in from the ride platform.
	_prop(entrances, "gate_ride", "RideGate", Vector3(X0, 0, -13.0), 90.0, Vector3(8, 5, 1))
	_collider(entrances, "RideGatePostA", Vector3(1.0, 5, 1.0), Vector3(X0, 2.5, -16.6))
	_collider(entrances, "RideGatePostB", Vector3(1.0, 5, 1.0), Vector3(X0, 2.5, -9.4))
	_rail(entrances, "RideGateFenceA", Vector3(X0, 0, -19.0), Vector3(X0, 0, -17.0))
	_rail(entrances, "RideGateFenceB", Vector3(X0, 0, -9.0), Vector3(X0, 0, -7.0))
	_collider(entrances, "RidePlatformBack", Vector3(0.4, 3, 12), Vector3(-33.0, 1.5, -13.0))

	# 3. Service ramp at the back: closed by a service door at the bottom.
	_prop(entrances, "service_door", "ServiceDoor", Vector3(-10.0, -2.6, Z0 - 17.0), 0.0, Vector3(6.4, 3.4, 0.5))
	_collider(entrances, "ServiceDoorWall", Vector3(6.6, 4, 0.5), Vector3(-10.0, -0.6, Z0 - 17.2))

	# 4. Pier entrance at the front, behind the start position.
	_prop(entrances, "gate_entrance", "PierEntrance", Vector3(-3.0, 0, Z1), 180.0, Vector3(8, 5, 1))
	_collider(entrances, "EntrancePostA", Vector3(1.0, 5, 1.0), Vector3(-6.6, 2.5, Z1))
	_collider(entrances, "EntrancePostB", Vector3(1.0, 5, 1.0), Vector3(0.6, 2.5, Z1))
	_rail(entrances, "EntranceFenceA", Vector3(-8.0, 0, Z1), Vector3(-7.0, 0, Z1))
	_rail(entrances, "EntranceFenceB", Vector3(1.0, 0, Z1), Vector3(2.0, 0, Z1))
	_prop(entrances, "gatehouse", "Gatehouse", Vector3(-3.0, 0, 33.0), 180.0, Vector3(12, 6, 3))
	_collider(entrances, "GatehouseWall", Vector3(12, 6, 0.6), Vector3(-3.0, 3, 33.2))


# ---------------------------------------------------------------------------
# Arena dressing: kiosk, sightline breaks, rail furniture
# ---------------------------------------------------------------------------

func _build_arena_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	geo.add_child(props)

	var kiosk: Node3D = (load("res://scenes/props/kiosk.tscn") as PackedScene).instantiate()
	kiosk.name = "Kiosk"
	props.add_child(kiosk)
	kiosk.position = Vector3.ZERO

	# Game booths against the ride-side fence (between the two left entrances).
	_prop(props, "booth", "BoothA", Vector3(-23.2, 0, -3.6), 90.0, Vector3(4.6, 3.6, 3.4))
	_collider(props, "BoothACollision", Vector3(3.4, 3.6, 4.7), Vector3(-23.2, 1.8, -3.6))
	_prop(props, "booth", "BoothB", Vector3(-23.2, 0, 1.4), 90.0, Vector3(4.6, 3.6, 3.4))
	_collider(props, "BoothBCollision", Vector3(3.4, 3.6, 4.7), Vector3(-23.2, 1.8, 1.4))

	# Planters: occasional sightline breaks, kept clear of the main lanes.
	var planters := [
		[Vector3(-12.5, 0, 10.5), 25.0, true],
		[Vector3(-13.5, 0, -11.5), -30.0, true],
		[Vector3(9.5, 0, 18.4), 0.0, true],
		[Vector3(0.5, 0, -20.5), 0.0, false],
		[Vector3(-20.5, 0, 20.0), 0.0, true],
		[Vector3(0.6, 0, 12.8), -32.0, false],
	]
	var i := 0
	for entry in planters:
		var pos: Vector3 = entry[0]
		var yaw: float = entry[1]
		_prop(props, "planter", "Planter%d" % i, pos, yaw, Vector3(3.2, 0.9, 1.5))
		var c := _collider(props, "Planter%dCollision" % i, Vector3(3.2, 1.0, 1.5), pos + Vector3(0, 0.5, 0))
		c.rotation.y = deg_to_rad(yaw)
		if entry[2]:
			_prop(dressing, "palm", "Palm%d" % i, pos + Vector3(0, 0.6, 0), i * 67.0, Vector3(0.5, 7, 0.5))
			var trunk := _collider(props, "Palm%dTrunk" % i, Vector3(0.5, 5.0, 0.5), pos + Vector3(0, 2.5, 0))
			trunk.rotation.y = deg_to_rad(yaw)
		i += 1

	# Rail-side furniture: tight to the railing so the lane stays open.
	var bench_spots := [Vector3(13.0, 0, 6.5), Vector3(13.0, 0, -7.0), Vector3(13.0, 0, -19.0)]
	i = 0
	for spot in bench_spots:
		_prop(props, "bench", "Bench%d" % i, spot, -90.0, Vector3(0.8, 0.9, 2.2))
		_collider(props, "Bench%dCollision" % i, Vector3(0.9, 0.9, 2.2), spot + Vector3(0, 0.45, 0))
		i += 1
	# Litter bins beside the benches, tight to the rail.
	i = 0
	for spot in bench_spots:
		var bin_pos: Vector3 = spot + Vector3(0.1, 0, 1.9)
		_prop(props, "trash_bin", "Bin%d" % i, bin_pos, 0.0, Vector3(0.7, 1.1, 0.7))
		_collider(props, "Bin%dCollision" % i, Vector3(0.7, 1.1, 0.7), bin_pos + Vector3(0, 0.55, 0))
		i += 1
	# Popcorn cart in the back corner of the ride side, off the main loop.
	_prop(props, "popcorn_cart", "PopcornCart", Vector3(-20.5, 0, -21.2), 90.0, Vector3(1.7, 2.0, 1.0))
	_collider(props, "PopcornCartCollision", Vector3(1.1, 2.0, 1.8), Vector3(-20.5, 1.0, -21.2))
	_prop(dressing, "surfboards", "Surfboards", Vector3(13.45, 0, -2.6), -90.0, Vector3(0.6, 2.4, 1.6))
	_prop(dressing, "life_ring", "LifeRing", Vector3(13.8, 0.75, 3.0), -90.0, Vector3(0.2, 0.8, 0.8))
	_prop(dressing, "life_ring", "LifeRing2", Vector3(13.8, 0.75, -30.0), -90.0, Vector3(0.2, 0.8, 0.8))

	# Lamp posts in the rail lines (the rail's collision covers them).
	for k in LAMPS.size():
		_prop(dressing, "lamp_post", "Lamp%02d" % k, _lamp_spot(k), LAMPS[k][3], Vector3(0.3, 5.5, 0.3))


## Where lamp `index` of LAMPS stands: on its rail's centre line, at the seam
## between two rail modules (clear of the rail's own posts), a touch inward.
func _lamp_spot(index: int) -> Vector3:
	var entry: Array = LAMPS[index]
	var a: Vector3 = entry[0]
	var b: Vector3 = entry[1]
	var wanted: Vector3 = entry[2]
	var yaw := deg_to_rad(float(entry[3]))
	var inward := Vector3(cos(yaw), 0.0, -sin(yaw)) * 0.08
	if entry[4]:
		return wanted + inward
	var length := a.distance_to(b)
	var count := maxi(1, int(round(length / RAIL_MODULE)))
	var step := length / count
	var along := clampi(int(round((wanted - a).dot((b - a) / length) / step)), 1, maxi(1, count - 1))
	return a + (b - a) / length * step * along + inward


# ---------------------------------------------------------------------------
# Exit route
# ---------------------------------------------------------------------------

func _build_exit() -> void:
	var portal: Node3D = (load("res://scenes/props/portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	geo.add_child(portal)
	portal.position = Vector3(11.0, 0, -51.0)

	var lights := Node3D.new()
	lights.name = "ExitLights"
	level.add_child(lights)
	var strip := BoxMesh.new()
	strip.size = Vector3(1.3, 0.04, 0.24)
	var light_script: Script = load("res://scripts/props/exit_light.gd")
	# From the kiosk plaza to the spur mouth, then down the spur to the portal.
	var route: Array[Vector3] = [Vector3(8.6, 0, -13.5), Vector3(9.6, 0, -17.0), Vector3(10.5, 0, -20.5)]
	var z := -24.0
	while z >= -48.0:
		route.append(Vector3(11.0, 0, z))
		z -= 2.4
	for i in route.size():
		var mi := MeshInstance3D.new()
		mi.name = "ExitLight%02d" % i
		mi.mesh = strip
		mi.position = route[i] + Vector3(0, 0.03, 0)
		if i < 3:
			mi.rotation.y = deg_to_rad(-16.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_script(light_script)
		mi.set("order", i)
		lights.add_child(mi)


# ---------------------------------------------------------------------------
# Skyline and surroundings (no collision)
# ---------------------------------------------------------------------------

func _build_backdrop() -> void:
	var backdrop := Node3D.new()
	backdrop.name = "Backdrop"
	level.add_child(backdrop)

	# The giant pink Ferris wheel on the left skyline.
	var wheel := _prop(backdrop, "ferris_wheel", "FerrisWheel", WHEEL_POS, WHEEL_YAW, Vector3(26, 30, 4))
	wheel.scale = Vector3.ONE * WHEEL_SCALE
	wheel.set_script(load("res://scripts/props/ferris_wheel.gd"))
	# Walkway from the ride platform to the wheel (scenery, outside the fence).
	var walk := MeshInstance3D.new()
	walk.name = "RideWalkway"
	walk.mesh = _box_mesh(Vector3(8.0, DECK_THICK, 8.0), _deck_material())
	walk.position = Vector3(-29.0, -DECK_THICK * 0.5, -23.0)
	backdrop.add_child(walk)

	_prop(backdrop, "coaster", "Coaster", Vector3(-22.0, -4.0, -64.0), 8.0, Vector3(60, 14, 10))

	_build_shore(backdrop)
	var shops := ["beach_shop_a", "beach_shop_b", "beach_shop_c", "beach_shop_d"]
	var x := -62.0
	var n := 0
	while x < 50.0:
		if absf(x + 3.0) > 9.0:
			# Shopfronts face the pier across the sand.
			var shop := _prop(backdrop, shops[n % shops.size()], "Shop%02d" % n, Vector3(x, -0.6, 38.5), 180.0, Vector3(9, 5, 7))
			shop.scale = Vector3.ONE * (1.0 + 0.12 * (n % 3))
			_prop(backdrop, "palm", "ShorePalm%02d" % n, Vector3(x + 5.5, -0.6, 36.5), n * 53.0, Vector3(0.5, 7, 0.5))
		x += 11.0
		n += 1
	# Umbrellas and towels on the sand in front of the shops.
	var umbrellas := [Vector3(-38.0, 0, 33.4), Vector3(-27.5, 0, 34.6), Vector3(-15.5, 0, 33.0), Vector3(9.5, 0, 34.2), Vector3(20.5, 0, 33.2), Vector3(31.0, 0, 34.8)]
	for k in umbrellas.size():
		_prop(backdrop, "beach_umbrella", "Umbrella%d" % k, umbrellas[k] + Vector3(0, BEACH_TOP, 0), k * 77.0, Vector3(3.4, 2.6, 3.4))

	# Palms on their own pilings just outside the ocean rail (they frame the view right).
	var piling := CylinderMesh.new()
	piling.top_radius = 1.0
	piling.bottom_radius = 1.15
	piling.height = 5.0
	piling.radial_segments = 14
	piling.material = _mat("pylon", Color(0.36, 0.22, 0.2), 0.9)
	var n_palm := 0
	for spot in [Vector3(15.9, 0, -3.5), Vector3(15.9, 0, -33.0)]:
		var base := MeshInstance3D.new()
		base.name = "PalmPiling%d" % n_palm
		base.mesh = piling
		base.position = spot + Vector3(0, -2.6, 0)
		backdrop.add_child(base)
		_prop(backdrop, "palm", "RailPalm%d" % n_palm, spot + Vector3(0, -0.2, 0), 150.0 + n_palm * 70.0, Vector3(0.5, 9, 0.5)).scale = Vector3.ONE * 1.3
		n_palm += 1

	_build_bay(backdrop)
	# A tall palm leaning in at the front-right, as in the reference frame, on a piling of its own.
	var corner := MeshInstance3D.new()
	corner.name = "PalmPilingCorner"
	corner.mesh = piling
	corner.position = Vector3(15.6, -3.6, 17.5)
	backdrop.add_child(corner)
	_prop(backdrop, "palm", "CornerPalm", Vector3(15.6, -1.2, 17.5), 200.0, Vector3(0.5, 9, 0.5)).scale = Vector3.ONE * 1.35


const BEACH_TOP := -0.6
const OCEAN_Y := -4.2
## The flat beach starts here (the entrance walk lands on it) and slopes
## down into the water toward the pier.
const BEACH_Z := 31.0
const SHORE_Z := 22.5


## The land side: a beach that slopes into the sea under the pier's entrance,
## a foam line at the water's edge, a footing under the gatehouse and dunes
## behind the shops (scenery).
func _build_shore(backdrop: Node3D) -> void:
	var sand := _mat("sand", Color(0.93, 0.74, 0.55), 0.95)
	var beach := MeshInstance3D.new()
	beach.name = "Beach"
	beach.mesh = _box_mesh(Vector3(700, 9.0, 120), sand)
	beach.position = Vector3(-10, BEACH_TOP - 4.5, BEACH_Z + 60.0)
	backdrop.add_child(beach)
	var run := BEACH_Z - SHORE_Z
	var drop := BEACH_TOP + 5.0
	var angle := atan2(drop, run)
	var slope := MeshInstance3D.new()
	slope.name = "ShoreSlope"
	slope.mesh = _box_mesh(Vector3(700, 1.0, sqrt(run * run + drop * drop) + 0.4), sand)
	slope.rotation.x = -angle
	slope.position = Vector3(-10, BEACH_TOP - drop * 0.5, (BEACH_Z + SHORE_Z) * 0.5) - Vector3(0, cos(angle), -sin(angle)) * 0.5
	slope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.add_child(slope)
	# Wet sand and foam where the slope meets the water.
	var water_z := BEACH_Z - run * (BEACH_TOP - OCEAN_Y) / drop
	var wet := MeshInstance3D.new()
	wet.name = "WetSand"
	wet.mesh = _box_mesh(Vector3(700, 0.04, 2.6), _mat("sand_wet", Color(0.72, 0.5, 0.42), 0.45))
	wet.rotation.x = -angle
	wet.position = Vector3(-10, OCEAN_Y + 1.2 * tan(angle), water_z + 1.2) + Vector3(0, cos(angle), -sin(angle)) * 0.02
	wet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.add_child(wet)
	var foam := MeshInstance3D.new()
	foam.name = "Foam"
	foam.mesh = _box_mesh(Vector3(700, 0.05, 1.5), _mat("foam", Color(1.0, 0.93, 0.95), 0.5, Color(1.0, 0.8, 0.85), 0.25))
	foam.position = Vector3(-10, OCEAN_Y + 0.03, water_z - 0.55)
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.add_child(foam)
	# The gatehouse stands on a footing in the sand, not in mid-air.
	var footing := MeshInstance3D.new()
	footing.name = "GatehouseFooting"
	footing.mesh = _box_mesh(Vector3(12.4, 5.0, 3.5), _mat("footing", Color(0.5, 0.33, 0.36), 0.9))
	footing.position = Vector3(-3.0, -2.52, 34.8)
	backdrop.add_child(footing)
	# Dunes behind the shops and headlands closing the horizon.
	var dune := _mat("dune", Color(0.9, 0.68, 0.56), 0.95)
	var far := _mat("headland", Color(0.66, 0.46, 0.6), 0.95)
	var blobs := [
		[Vector3(-70, -3.0, 76), Vector3(46, 9, 22), dune], [Vector3(-16, -3.0, 84), Vector3(52, 11, 24), dune],
		[Vector3(44, -3.0, 78), Vector3(44, 8, 20), dune], [Vector3(96, -3.0, 70), Vector3(40, 7, 20), dune],
		[Vector3(-128, -3.0, 68), Vector3(42, 7, 20), dune],
		[Vector3(-190, -6.0, 120), Vector3(110, 26, 46), far], [Vector3(30, -6.0, 150), Vector3(150, 22, 40), far],
		[Vector3(215, -6.0, 110), Vector3(100, 30, 44), far],
	]
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 20
	ball.rings = 8
	for k in blobs.size():
		var mi := MeshInstance3D.new()
		mi.name = "Dune%d" % k
		mi.mesh = ball
		mi.material_override = blobs[k][2]
		mi.position = blobs[k][0]
		mi.scale = blobs[k][1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		backdrop.add_child(mi)


## Life out on the water (scenery): a lighthouse with turning beams,
## sailboats and channel buoys that ride the swell.
func _build_bay(backdrop: Node3D) -> void:
	var motion: Script = load("res://scripts/props/ambient_motion.gd")
	var lighthouse := _prop(backdrop, "lighthouse", "Lighthouse", Vector3(150.0, OCEAN_Y, -120.0), 20.0, Vector3(8, 30, 8))
	lighthouse.scale = Vector3.ONE * LIGHTHOUSE_SCALE
	var beams := Node3D.new()
	beams.name = "LighthouseBeams"
	beams.position = Vector3(150.0, OCEAN_Y + 24.9 * LIGHTHOUSE_SCALE, -120.0)
	beams.set_script(motion)
	beams.set("spin_degrees_per_second", 16.0)
	backdrop.add_child(beams)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.6
	cone.bottom_radius = 9.0
	cone.height = 110.0
	cone.radial_segments = 12
	cone.cap_top = false
	cone.cap_bottom = false
	var beam_mat := StandardMaterial3D.new()
	beam_mat.resource_name = "LighthouseBeam"
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = Color(1.0, 0.82, 0.5, 0.07)
	beam_mat.disable_fog = true
	cone.material = beam_mat
	for side in [-1.0, 1.0]:
		var beam := MeshInstance3D.new()
		beam.name = "Beam%s" % ("A" if side < 0.0 else "B")
		beam.mesh = cone
		beam.rotation.z = side * PI * 0.5
		beam.position = Vector3(side * 55.6, 0, 0)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beams.add_child(beam)
	var boats := [[Vector3(58.0, OCEAN_Y, -34.0), 205.0, 1.5], [Vector3(92.0, OCEAN_Y, 22.0), 28.0, 1.7], [Vector3(40.0, OCEAN_Y, -92.0), 140.0, 1.4]]
	for k in boats.size():
		var boat := _prop(backdrop, "sailboat", "Sailboat%d" % k, boats[k][0], boats[k][1], Vector3(5, 7, 2))
		boat.scale = Vector3.ONE * boats[k][2]
		boat.set_script(motion)
		boat.set("bob_height", 0.22)
		boat.set("bob_seconds", 3.4 + 0.5 * k)
		boat.set("rock_degrees", 4.0)
	var buoys := [Vector3(24.0, OCEAN_Y, -18.0), Vector3(26.0, OCEAN_Y, -47.0), Vector3(31.0, OCEAN_Y, 9.0)]
	for k in buoys.size():
		var buoy := _prop(backdrop, "buoy", "Buoy%d" % k, buoys[k], k * 40.0, Vector3(1.4, 2.4, 1.4))
		buoy.set_script(motion)
		buoy.set("bob_height", 0.16)
		buoy.set("bob_seconds", 2.6 + 0.4 * k)
		buoy.set("rock_degrees", 7.0)

const LIGHTHOUSE_SCALE := 1.5


## Gulls perched where gulls perch, and fingerposts that point the way to the
## station, the portal and the rides (scenery).
func _build_set_dressing() -> void:
	var gulls := [
		[Vector3(9.5, 1.49, Z1), 205.0],                       # rail post by the start
		[Vector3(X1, 1.49, -22.08), -20.0],                    # ocean rail
		[_lamp_spot(2) + Vector3(0, 5.26, 0), 120.0],          # lamp top
		[Vector3(-1.4, 6.95, 32.9), 100.0],                    # ticket sign
		[Vector3(-24.9, 5.62, 7.2), -15.0],                    # arcade roof
		[Vector3(-18.7, 0.0, -20.0), 40.0],                    # after the popcorn
	]
	for k in gulls.size():
		_prop(dressing, "seagull", "Gull%d" % k, gulls[k][0], gulls[k][1], Vector3(0.7, 0.6, 0.3))
	_prop(dressing, "signpost_a", "SignpostNorth", Vector3(0.5, 0.8, -20.5), 0.0, Vector3(0.2, 3.7, 0.2))
	_prop(dressing, "signpost_b", "SignpostStart", Vector3(0.6, 0.8, 12.8), 0.0, Vector3(0.2, 3.7, 0.2))


# ---------------------------------------------------------------------------
# String lights and deck paint (scenery only, no collision)
# ---------------------------------------------------------------------------

const POLE_TOP := 5.0

func _build_string_lights() -> void:
	var lights := Node3D.new()
	lights.name = "StringLights"
	level.add_child(lights)
	var tops: Array[Vector3] = []
	for k in LAMPS.size():
		tops.append(_lamp_spot(k) + Vector3.UP * POLE_TOP)
	var spans := []
	# Lamp to lamp: along the ocean rail and over the exit spur, then the ride
	# side, the back edge and the front edge (indices into LAMPS).
	for pair in [[0, 1], [1, 2], [2, 3], [3, 4], [3, 5], [4, 6], [5, 6], [7, 9], [9, 8], [10, 11], [11, 12], [13, 14]]:
		spans.append([tops[pair[0]], tops[pair[1]]])
	# Carnival strings from the kiosk's roof out to the lamp posts.
	for k in [1, 9, 11, 14, 13]:
		var flat := Vector3(tops[k].x, 0, tops[k].z).normalized()
		spans.append([flat * 1.7 + Vector3(0, 6.7, 0), tops[k]])
	var i := 0
	for span in spans:
		_garland(lights, "Garland%02d" % i, span[0], span[1])
		i += 1


func _garland(parent: Node3D, garland_name: String, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var sag := clampf(length * 0.06, 0.35, 1.1)
	var bulbs := maxi(4, int(length / 1.1))
	var points: Array[Vector3] = []
	for k in bulbs + 1:
		var t := float(k) / bulbs
		points.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	var holder := Node3D.new()
	holder.name = garland_name
	parent.add_child(holder)
	# Wire.
	var wire := MultiMeshInstance3D.new()
	wire.name = "Wire"
	var wm := MultiMesh.new()
	wm.transform_format = MultiMesh.TRANSFORM_3D
	wm.mesh = _box_mesh(Vector3(1, 1, 1), _mat("wire", Color(0.12, 0.1, 0.18), 0.6))
	wm.instance_count = points.size() - 1
	for k in points.size() - 1:
		var p0 := points[k]
		var p1 := points[k + 1]
		var dir := (p1 - p0).normalized()
		var basis := Basis.looking_at(dir, Vector3.UP)
		wm.set_instance_transform(k, Transform3D(Basis(basis.x * 0.025, basis.y * 0.025, basis.z * p0.distance_to(p1)), (p0 + p1) * 0.5))
	wire.multimesh = wm
	wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(wire)
	# Bulbs (skip the two ends, which sit on the posts).
	var colors := [Color(1.0, 0.76, 0.3), Color(1.0, 0.45, 0.75), Color(0.35, 0.95, 1.0), Color(1.0, 0.76, 0.3)]
	var bulb_mm := MultiMesh.new()
	bulb_mm.transform_format = MultiMesh.TRANSFORM_3D
	bulb_mm.use_colors = true
	bulb_mm.mesh = _bulb_mesh()
	bulb_mm.instance_count = points.size() - 2
	for k in range(1, points.size() - 1):
		bulb_mm.set_instance_transform(k - 1, Transform3D(Basis(), points[k] + Vector3.DOWN * 0.08))
		bulb_mm.set_instance_color(k - 1, colors[k % colors.size()])
	var bulbs_node := MultiMeshInstance3D.new()
	bulbs_node.name = "Bulbs"
	bulbs_node.multimesh = bulb_mm
	bulbs_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(bulbs_node)
	var halo_mm := MultiMesh.new()
	halo_mm.transform_format = MultiMesh.TRANSFORM_3D
	halo_mm.mesh = _halo_mesh()
	halo_mm.instance_count = bulb_mm.instance_count
	for k in bulb_mm.instance_count:
		halo_mm.set_instance_transform(k, bulb_mm.get_instance_transform(k))
	var halos := MultiMeshInstance3D.new()
	halos.name = "Halos"
	halos.multimesh = halo_mm
	halos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halos.add_to_group("high_detail", true)
	holder.add_child(halos)


var _bulb_mesh_cache: Mesh
var _halo_mesh_cache: Mesh


func _bulb_mesh() -> Mesh:
	if _bulb_mesh_cache:
		return _bulb_mesh_cache
	var m := StandardMaterial3D.new()
	m.resource_name = "GarlandBulb"
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.5)
	m.emission_energy_multiplier = 2.2
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = m
	_bulb_mesh_cache = sphere
	return sphere


## Three crossed quads with UVs; the halo shader turns them into a soft glow.
func _halo_mesh() -> Mesh:
	if _halo_mesh_cache:
		return _halo_mesh_cache
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.36
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for axis in 3:
		var quad: Array[Vector3] = []
		for c in corners:
			var v := Vector3.ZERO
			v[(axis + 1) % 3] = c.x * h
			v[(axis + 2) % 3] = c.y * h
			quad.append(v)
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv((corners[idx] + Vector2.ONE) * 0.5)
			st.add_vertex(quad[idx])
	var mesh := st.commit()
	var halo_mat := ShaderMaterial.new()
	halo_mat.shader = load("res://art/shaders/bulb_halo.gdshader")
	halo_mat.resource_name = "GarlandHalo"
	mesh.surface_set_material(0, halo_mat)
	_halo_mesh_cache = mesh
	return mesh


## A flat five-pointed star, 1 m across, lying on the deck.
func _star_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for k in 10:
		var r := 0.5 if k % 2 == 0 else 0.22
		var a := -PI * 0.5 + PI * k / 5.0
		pts.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	for k in 10:
		for v in [Vector3.ZERO, pts[k], pts[(k + 1) % 10]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


## Pink edge stripes painted on the deck, as in the reference.
func _build_deck_paint() -> void:
	var paint := Node3D.new()
	paint.name = "DeckPaint"
	level.add_child(paint)
	var pink := _mat("deck_paint", Color(0.95, 0.3, 0.62), 0.6)
	var y := 0.012
	var stripes := [
		[Vector3(X1 - 1.1, y, (Z0 + Z1) * 0.5), Vector3(0.28, 0.01, Z1 - Z0 - 2.0)],
		[Vector3(X0 + 1.1, y, (Z0 + Z1) * 0.5), Vector3(0.28, 0.01, Z1 - Z0 - 2.0)],
		[Vector3((X0 + X1) * 0.5, y, Z1 - 1.1), Vector3(X1 - X0 - 2.0, 0.01, 0.28)],
		[Vector3((X0 + X1) * 0.5, y, Z0 + 1.1), Vector3(X1 - X0 - 2.0, 0.01, 0.28)],
		[Vector3(SPUR_X0 + 0.9, y, (SPUR_Z0 + Z0) * 0.5), Vector3(0.24, 0.01, Z0 - SPUR_Z0 - 2.0)],
		[Vector3(X1 - 0.9, y, (SPUR_Z0 + Z0) * 0.5), Vector3(0.24, 0.01, Z0 - SPUR_Z0 - 2.0)],
	]
	# Painted stars along the loop (as on the reference deck), no collision.
	var star_mesh := _star_mesh()
	var spots := [
		[Vector3(-14.0, 0.014, 4.0), 0.9, Color(1.0, 0.85, 0.25)], [Vector3(-12.0, 0.014, -16.0), 0.8, Color(0.3, 0.9, 0.95)],
		[Vector3(9.0, 0.014, 4.0), 0.75, Color(1.0, 0.45, 0.75)], [Vector3(4.0, 0.014, -16.5), 0.85, Color(1.0, 0.85, 0.25)],
		[Vector3(-19.0, 0.014, 12.0), 0.7, Color(1.0, 0.45, 0.75)], [Vector3(11.0, 0.014, -36.0), 0.7, Color(0.3, 0.9, 0.95)],
	]
	var n := 0
	for spot in spots:
		var star := MeshInstance3D.new()
		star.name = "PaintedStar%d" % n
		star.mesh = star_mesh
		var star_mat := _mat("star_paint_%d" % n, spot[2], 0.55)
		star_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		star.material_override = star_mat
		star.position = spot[0]
		star.rotation.y = n * 0.9
		star.scale = Vector3.ONE * spot[1] * 2.4
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		paint.add_child(star)
		n += 1
	var i := 0
	for stripe in stripes:
		var mi := MeshInstance3D.new()
		mi.name = "Stripe%d" % i
		mi.mesh = _box_mesh(stripe[1], pink)
		mi.position = stripe[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		paint.add_child(mi)
		i += 1


# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(4.5, 0.1, 14.5)
	start.rotation.y = deg_to_rad(8.0)       # facing the kiosk
	start.add_to_group("player_spawn", true)
	level.add_child(start)

	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	var points := {
		"SpawnArcade": [Vector3(-30.0, 0.1, 11.0), -90.0],
		"SpawnRideGate": [Vector3(-30.0, 0.1, -13.0), -90.0],
		"SpawnServiceRamp": [Vector3(-10.0, -2.5, Z0 - 14.5), 0.0],
		"SpawnPierEntrance": [Vector3(-3.0, 0.1, 30.0), 0.0],
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
	mesh.agent_radius = 0.5
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 40.0
	mesh.region_min_size = 8.0
	# Only walkable surfaces at deck height and below (keeps roofs and planter tops out).
	mesh.filter_baking_aabb = AABB(Vector3(-60, -4.0, -70), Vector3(120, 4.6, 120))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	region.navigation_mesh = _keep_connected(mesh, [Vector3(4.5, 0.0, 14.5)])
	print("build_prize_pier: navmesh polygons = %d (of %d before removing islands)" % [region.navigation_mesh.get_polygon_count(), before])
	_check_reachable(region.navigation_mesh)


## Every entrance, the ramp and the portal must be on the navmesh connected to
## the player's start; prints a warning for any that are not.
func _check_reachable(mesh: NavigationMesh) -> void:
	var probes := {
		"arcade": Vector3(-30.0, 0, 11.0), "ride gate": Vector3(-30.0, 0, -13.0),
		"service ramp": Vector3(-10.0, -1.3, Z0 - 6.0), "ramp landing": Vector3(-10.0, -2.6, Z0 - 14.5),
		"pier entrance": Vector3(-3.0, 0, 30.0), "exit spur": Vector3(11.0, 0, -36.0),
		"portal": Vector3(11.0, 0, -49.5), "kiosk plaza": Vector3(0.0, 0, 7.0),
		"ocean lane": Vector3(11.5, 0, 0.0), "back lane": Vector3(-10.0, 0, -21.0),
	}
	var verts := mesh.get_vertices()
	var bad := 0
	for probe_name in probes:
		var p: Vector3 = probes[probe_name]
		var found := false
		for i in mesh.get_polygon_count():
			if _in_polygon(verts, mesh.get_polygon(i), p):
				found = true
				break
		if not found:
			bad += 1
			print("build_prize_pier: WARNING %s is not connected to the start" % probe_name)
	print("build_prize_pier: reachability check, %d of %d areas connected" % [probes.size() - bad, probes.size()])


## True if `p` lies over the convex polygon (top view) within a metre of its height.
func _in_polygon(verts: PackedVector3Array, poly: PackedInt32Array, p: Vector3) -> bool:
	var sign := 0.0
	var height := 0.0
	for k in poly.size():
		var a := verts[poly[k]]
		var b := verts[poly[(k + 1) % poly.size()]]
		height += a.y
		var c := (b.x - a.x) * (p.z - a.z) - (b.z - a.z) * (p.x - a.x)
		if absf(c) < 1e-6:
			continue
		if sign == 0.0:
			sign = signf(c)
		elif signf(c) != sign:
			return false
	return absf(height / poly.size() - p.y) < 1.0


## Drops every polygon not connected (through shared vertices) to the
## polygon nearest one of `seeds`: the pockets baked inside the kiosk and the
## booths go away, so closest-point queries never snap onto them.
func _keep_connected(mesh: NavigationMesh, seeds: Array) -> NavigationMesh:
	var verts := mesh.get_vertices()
	var count := mesh.get_polygon_count()
	var by_vertex := {}
	for i in count:
		for v in mesh.get_polygon(i):
			if not by_vertex.has(v):
				by_vertex[v] = []
			by_vertex[v].append(i)
	var keep := {}
	var stack: Array[int] = []
	for s in seeds:
		var best := -1
		var best_d := INF
		for i in count:
			var poly := mesh.get_polygon(i)
			var centre := Vector3.ZERO
			for v in poly:
				centre += verts[v]
			centre /= poly.size()
			var d: float = centre.distance_to(s)
			if d < best_d:
				best_d = d
				best = i
		if best >= 0:
			stack.append(best)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		if keep.has(i):
			continue
		keep[i] = true
		for v in mesh.get_polygon(i):
			for other in by_vertex[v]:
				if not keep.has(other):
					stack.append(other)
	var out := NavigationMesh.new()
	for prop in ["cell_size", "cell_height", "agent_height", "agent_radius", "agent_max_climb", "agent_max_slope"]:
		out.set(prop, mesh.get(prop))
	out.vertices = verts
	for i in count:
		if keep.has(i):
			out.add_polygon(mesh.get_polygon(i))
	return out


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

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


func _box_mesh(size: Vector3, material: Material) -> BoxMesh:
	var key := "%s|%s" % [size, material.get_instance_id()]
	if _boxes.has(key):
		return _boxes[key]
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	_boxes[key] = mesh
	return mesh


## Invisible wall on the "player_walls" layer standing on `body` (its
## bottom at the body's centre minus half the visible height), so the player
## cannot jump over a low wall; shots, zombies and navigation ignore it.
func _player_wall(body: StaticBody3D, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.name = "PlayerWall"
	wall.collision_layer = 16
	wall.collision_mask = 0
	body.add_child(wall)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5 - 0.65
	wall.add_child(shape)


## Visible box with matching collision.
func _box(parent: Node3D, box_name: String, size: Vector3, pos: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	parent.add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(size, material)
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


## Invisible collision box (for props whose art comes from a .glb).
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
