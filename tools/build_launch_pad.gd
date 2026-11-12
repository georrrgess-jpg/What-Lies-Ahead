extends SceneTree
## Generator for World 4 / "Launch Pad 9" (Dune Spaceport).
##
## Rebuilds scenes/levels/launch_pad.tscn: the concrete apron, the launch mount
## with its rocket, gantry and ramps, the boundary blast walls and buildings,
## cover, lights, vapour, blowing sand, backdrop, markers, the supply-pod
## loadout station, the exit portal and a baked navigation mesh.
##
##   xvfb-run godot --rendering-driver opengl3 --path . --script res://tools/build_launch_pad.gd
##
## Run it with a renderer (not --headless): the headless dummy renderer keeps no
## MultiMesh instance data, so the blast walls, lights and vapour would be saved empty.
## NOTE: running this overwrites hand edits made to launch_pad.tscn.
##
## Layout (metres, top view; the player starts at the south edge facing -Z):
##   - Arena X -26..26, Z -32..26 on a sand-blown concrete apron.
##   - Launch mount (20 x 14 m, deck at 2 m) centred at (0, -9): rocket on the
##     launch table, gantry on its west end. Ramps: south-east (up from the
##     plaza) and north (down to the back yard), so the deck is a third route
##     between the west and east lanes.
##   - Supply-pod loadout station in the south plaza at (0, 9).
##   - Zombie entrances beyond the walls: Hangar A doors (west), Hangar B doors
##     (north-west), maintenance tunnel (north-east), cargo lift (east) and the
##     security gate (south-west, behind the start).
##   - Exit portal in the back yard at (5, -27); exit lights run up the east lane.

const OUT_PATH := "res://scenes/levels/launch_pad.tscn"
const MODELS := "res://art/models/"
const TEX := "res://art/textures/"

const X0 := -26.6
const X1 := 26.6
const Z0 := -31.4
const Z1 := 26.6
const DECK_Y := 2.0
const MOUNT_C := Vector3(0, 0, -9)
const MOUNT_SIZE := Vector2(20, 14)
const STATION_POS := Vector3(0, 0, 9)
const PORTAL_POS := Vector3(5, 0, -27)
const HANGAR_A := Vector3(-37, 0, -14)
const HANGAR_B := Vector3(-12, 0, -43)
const TUNNEL := Vector3(14, 0, -32)
const LIFT := Vector3(29.5, 0, 4)
const GATE := Vector3(-12, 0, 29)
## Visible sun azimuth: 0 = straight ahead (-Z), 90 = right (+X).
const SUN_AZIMUTH_DEGREES := -55.0
const SKY_YAW_DEGREES := 180.0 - SUN_AZIMUTH_DEGREES

var level: Node3D
var geo: Node3D          # collidable geometry (navmesh source)
var dressing: Node3D     # non-colliding scenery
var _materials := {}
var _meshes := {}
var _editable: Array[Node3D] = []     # instanced models carrying material overrides


func _initialize() -> void:
	level = Node3D.new()
	level.name = "LaunchPad"
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
	_build_launch_mount()
	_build_walls()
	_build_hangars()
	_build_tunnel()
	_build_cargo_lift()
	_build_gate()
	_build_cover()
	_build_details()
	_build_station_and_portal()
	_build_markings()
	_build_lights()
	_build_vapour()
	_build_sand()
	_build_backdrop()
	_build_animation()
	_build_markers()

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
	# Save the per-instance recolours (container paint): without editable
	# children the packer drops overrides made inside instanced models.
	for node in _editable:
		level.set_editable_instance(node, true)
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_PATH)
	print("build_launch_pad: saved %s (error %d)" % [OUT_PATH, err])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: golden-hour sky, long golden key light, cool violet fill and
# ambient (warm light against cool shadows keeps the sand from washing out)
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load(TEX + "dune_sky.png")
	pano.energy_multiplier = 1.0
	sky.sky_material = pano
	env.sky = sky
	env.sky_rotation = Vector3(0.0, deg_to_rad(SKY_YAW_DEGREES), 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.48, 0.78)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.4
	env.tonemap_exposure = 0.98
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.64, 0.46)
	env.fog_density = 0.0014
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.28
	env.adjustment_contrast = 1.1
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	# Key light from the sun's compass direction but higher, so shadows run long
	# across the apron without swallowing the zombies.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	var azimuth := deg_to_rad(SUN_AZIMUTH_DEGREES)
	var elevation := deg_to_rad(24.0)
	var to_sun := Vector3(sin(azimuth) * cos(elevation), sin(elevation), -cos(azimuth) * cos(elevation))
	sun.transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP), Vector3(0, 30, 0))
	sun.light_color = Color(1.0, 0.72, 0.44)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_opacity = 0.78
	level.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.transform = Transform3D(Basis.looking_at(Vector3(-0.5, -0.45, 0.75).normalized(), Vector3.UP), Vector3(0, 30, 0))
	fill.light_color = Color(0.55, 0.6, 1.0)
	fill.light_energy = 0.32
	fill.shadow_enabled = false
	level.add_child(fill)


# ---------------------------------------------------------------------------
# Ground: apron, entrance floors and the open desert
# ---------------------------------------------------------------------------

func _ground_mat(sand := 0.15, clear_radius := 30.0) -> ShaderMaterial:
	var key := "ground_%s_%s" % [sand, clear_radius]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://art/shaders/dune_ground.gdshader")
	m.set_shader_parameter("concrete_tex", load(TEX + "dune_concrete.png"))
	m.set_shader_parameter("concrete_normal", load(TEX + "dune_concrete_normal.png"))
	m.set_shader_parameter("sand_tex", load(TEX + "dune_sand.png"))
	m.set_shader_parameter("sand_normal", load(TEX + "dune_sand_normal.png"))
	m.set_shader_parameter("noise_tex", load(TEX + "dune_noise.png"))
	m.set_shader_parameter("sand_amount", sand)
	m.set_shader_parameter("clear_center", Vector2(0, -3))
	m.set_shader_parameter("clear_radius", clear_radius)
	_materials[key] = m
	return m


func _build_ground() -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	geo.add_child(ground)
	var apron := _ground_mat()
	_slab(ground, "Apron", Vector3(X0, 0, Z0), Vector3(X1, 0, Z1), apron)
	_slab(ground, "HangarAFloor", Vector3(-47.6, 0, -22.6), Vector3(X0, 0, -5.4), apron)
	_slab(ground, "HangarBFloor", Vector3(-20.6, 0, -53.6), Vector3(-3.4, 0, Z0), apron)
	_slab(ground, "LiftApron", Vector3(X1, 0, 0.4), Vector3(33.4, 0, 7.6), apron)
	_slab(ground, "GateRoad", Vector3(-17.2, 0, Z1), Vector3(-6.8, 0, 42.0), _ground_mat(0.55))
	# The open desert around everything (visual only).
	var desert := MeshInstance3D.new()
	desert.name = "Desert"
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	desert.mesh = plane
	desert.material_override = _ground_mat(1.0, 10.0)
	desert.position = Vector3(0, -0.04, 0)
	desert.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(desert)


## A 1 m thick ground slab whose top is at `a.y`, spanning a..b in X and Z.
func _slab(parent: Node3D, slab_name: String, a: Vector3, b: Vector3, material: Material) -> StaticBody3D:
	var size := Vector3(absf(b.x - a.x), 1.0, absf(b.z - a.z))
	var centre := Vector3((a.x + b.x) * 0.5, a.y - 0.5, (a.z + b.z) * 0.5)
	return _box(parent, slab_name, size, centre, material)


# ---------------------------------------------------------------------------
# The launch mount: pedestal, rocket, gantry, ramps and deck rails
# ---------------------------------------------------------------------------

func _build_launch_mount() -> void:
	var pad := Node3D.new()
	pad.name = "LaunchPad9"
	geo.add_child(pad)
	var c := MOUNT_C
	_prop(pad, "dune_launch_mount", "Mount", c, 0.0)
	# The pedestal's corners are chamfered so zombies rounding it slide past.
	var body := StaticBody3D.new()
	body.name = "MountBody"
	body.position = c
	pad.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var convex := ConvexPolygonShape3D.new()
	var mx := MOUNT_SIZE.x * 0.5
	var mz := MOUNT_SIZE.y * 0.5
	var ch := 0.8
	var pts := PackedVector3Array()
	for y in [0.0, DECK_Y]:
		for p in [Vector2(-mx + ch, -mz), Vector2(mx - ch, -mz), Vector2(mx, -mz + ch), Vector2(mx, mz - ch),
				Vector2(mx - ch, mz), Vector2(-mx + ch, mz), Vector2(-mx, mz - ch), Vector2(-mx, -mz + ch)]:
			pts.append(Vector3(p.x, y, p.y))
	convex.points = pts
	shape.shape = convex
	body.add_child(shape)
	# Launch table, rocket and the tail service masts beside it are off-limits.
	_collider(pad, "TableBlock", Vector3(10.2, 4.0, 8.4), c + Vector3(0.9, DECK_Y + 2.0, 0))
	_prop(pad, "dune_rocket", "Rocket", c + Vector3(0, 2.6, 0), 0.0)
	var hull := _collider(pad, "RocketHull", Vector3(4.2, 28.0, 4.2), c + Vector3(0, 2.6 + 4.0 + 14.0, 0))
	hull.rotation.y = deg_to_rad(45.0)
	_prop(pad, "dune_gantry", "Gantry", c + Vector3(-7.75, DECK_Y, 0), 0.0)
	# Kept inside the deck edge: tall zombies (the Bruiser) walk under the overhang.
	_collider(pad, "GantryBody", Vector3(4.9, 36.0, 5.4), c + Vector3(-7.55, DECK_Y + 18.0, 0))

	# Ramps: the model's high end sits over its origin, descending toward +Z.
	_ramp(pad, "RampSouth", Vector3(7.0, 0, c.z + MOUNT_SIZE.y * 0.5), 0.0)
	_ramp(pad, "RampNorth", Vector3(-2.5, 0, c.z - MOUNT_SIZE.y * 0.5), 180.0)

	# Deck safety rails, leaving the ramp heads open.
	var hx := MOUNT_SIZE.x * 0.5 - 0.2
	var hz := MOUNT_SIZE.y * 0.5 - 0.2
	var y := DECK_Y
	var runs := [
		[Vector3(-hx, y, c.z + hz), Vector3(4.8, y, c.z + hz)],
		[Vector3(9.2, y, c.z + hz), Vector3(hx, y, c.z + hz)],
		[Vector3(-hx, y, c.z - hz), Vector3(-4.7, y, c.z - hz)],
		[Vector3(-0.3, y, c.z - hz), Vector3(hx, y, c.z - hz)],
		[Vector3(hx, y, c.z - hz), Vector3(hx, y, c.z + hz)],
		[Vector3(-hx, y, c.z - hz), Vector3(-hx, y, c.z - 2.7)],
		[Vector3(-hx, y, c.z + 2.7), Vector3(-hx, y, c.z + hz)],
	]
	var i := 0
	for run in runs:
		_rail(pad, "DeckRail%d" % i, run[0], run[1])
		i += 1


func _ramp(parent: Node3D, ramp_name: String, top: Vector3, yaw: float) -> void:
	_prop(parent, "dune_ramp", ramp_name, top, yaw)
	# Solid wedge collision: flat underside, sloped top from the deck to the ground.
	var body := StaticBody3D.new()
	body.name = ramp_name + "Wedge"
	body.position = top
	body.rotation.y = deg_to_rad(yaw)
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var convex := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for x in [-2.0, 2.0]:
		pts.append(Vector3(x, DECK_Y, -0.05))
		pts.append(Vector3(x, 0.0, -0.05))
		pts.append(Vector3(x, 0.0, 8.0))
	convex.points = pts
	shape.shape = convex
	body.add_child(shape)
	# Side walls under the handrails: the ramp is only entered from its ends
	# (otherwise the navmesh would let zombies step onto its raised edges).
	for x in [-2.1, 2.1]:
		var side := CollisionShape3D.new()
		side.name = "Side%d" % int(x)
		var box := BoxShape3D.new()
		box.size = Vector3(0.2, DECK_Y + 1.1, 8.0)
		side.shape = box
		side.position = Vector3(x, (DECK_Y + 1.1) * 0.5, 4.0)
		body.add_child(side)
		# Round bollards cap the wall ends (foot and head), so corner-cutting
		# zombies slide past instead of snagging.
		for end in [Vector3(x, 0.0, 8.0), Vector3(x, DECK_Y, 0.0)]:
			var cap := CollisionShape3D.new()
			cap.name = "Bollard%d_%d" % [int(x), int(end.z)]
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.32
			cyl.height = 1.2
			cap.shape = cyl
			cap.position = end + Vector3(0, 0.6, 0)
			body.add_child(cap)
			var post := MeshInstance3D.new()
			post.name = "BollardMesh%d_%d" % [int(x), int(end.z)]
			post.mesh = _bollard_mesh()
			post.position = end + Vector3(0, 0.55, 0)
			body.add_child(post)


func _bollard_mesh() -> Mesh:
	if _meshes.has("bollard"):
		return _meshes["bollard"]
	var m := StandardMaterial3D.new()
	m.resource_name = "BollardPaint"
	m.albedo_texture = load(TEX + "dune_hazard.png")
	m.uv1_scale = Vector3(2.0, 1.0, 1.0)
	m.roughness = 0.6
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.26
	mesh.bottom_radius = 0.3
	mesh.height = 1.1
	mesh.radial_segments = 14
	mesh.material = m
	_meshes["bollard"] = mesh
	return mesh


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
	body.rotation.y = atan2(-dir.z, dir.x)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(length, 1.25, 0.25)
	shape.shape = box
	shape.position.y = 0.625
	body.add_child(shape)
	var count := maxi(1, int(round(length / 3.0)))
	var step := length / count
	for i in count:
		var m := _instance("dune_rail")
		m.name = "Module%02d" % i
		m.position = Vector3(-length * 0.5 + step * (i + 0.5), 0, 0)
		m.scale = Vector3(step / 3.0, 1, 1)
		body.add_child(m)


# ---------------------------------------------------------------------------
# Boundary: blast walls between the buildings, invisible player walls
# ---------------------------------------------------------------------------

func _build_walls() -> void:
	var walls := Node3D.new()
	walls.name = "BlastWalls"
	geo.add_child(walls)
	var runs := [
		# South edge, either side of the gate road.
		[Vector3(X0, 0, Z1), Vector3(-17.4, 0, Z1)], [Vector3(-6.6, 0, Z1), Vector3(X1, 0, Z1)],
		# West edge, either side of Hangar A.
		[Vector3(X0, 0, Z1), Vector3(X0, 0, -5.2)], [Vector3(X0, 0, -22.8), Vector3(X0, 0, -32.0)],
		# North edge: Hangar B, then the tunnel portal.
		[Vector3(X0, 0, -32.0), Vector3(-21.0, 0, -32.0)], [Vector3(-3.0, 0, -32.0), Vector3(8.4, 0, -32.0)],
		[Vector3(19.6, 0, -32.0), Vector3(X1, 0, -32.0)],
		# East edge, either side of the cargo lift.
		[Vector3(X1, 0, -32.0), Vector3(X1, 0, 0.6)], [Vector3(X1, 0, 7.4), Vector3(X1, 0, Z1)],
	]
	var transforms: Array[Transform3D] = []
	var i := 0
	for run in runs:
		var a: Vector3 = run[0]
		var b: Vector3 = run[1]
		var length := a.distance_to(b)
		var dir := (b - a).normalized()
		var yaw := atan2(-dir.z, dir.x)
		var count := maxi(1, int(ceil(length / 4.0)))
		var step := length / count
		for k in count:
			var p := a + dir * step * (k + 0.5)
			transforms.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(step / 4.0, 1, 1)), p))
		var col := _collider(walls, "WallRun%d" % i, Vector3(length, 3.4, 1.0), (a + b) * 0.5 + Vector3(0, 1.7, 0))
		col.rotation.y = yaw
		i += 1
	_multimesh(walls, "WallModules", "dune_blast_wall", transforms)
	# Player-only walls (layer 5): nobody climbs out over the walls or wanders into a spawn.
	var pw := Node3D.new()
	pw.name = "PlayerWalls"
	level.add_child(pw)
	var h := 14.0
	for spec in [
		[Vector3(X1 - X0 + 2.0, h, 0.4), Vector3(0, h * 0.5, Z1 + 0.2)],
		[Vector3(X1 - X0 + 2.0, h, 0.4), Vector3(0, h * 0.5, -32.2)],
		[Vector3(0.4, h, Z1 + 34.0), Vector3(X0 - 0.2, h * 0.5, -2.8)],
		[Vector3(0.4, h, Z1 + 34.0), Vector3(X1 + 0.2, h * 0.5, -2.8)],
	]:
		var wall := StaticBody3D.new()
		wall.name = "PlayerWall%d" % pw.get_child_count()
		wall.collision_layer = 16
		wall.collision_mask = 0
		wall.position = spec[1]
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = spec[0]
		shape.shape = box
		wall.add_child(shape)
		pw.add_child(wall)


# ---------------------------------------------------------------------------
# Zombie entrances
# ---------------------------------------------------------------------------

func _build_hangars() -> void:
	var hangars := Node3D.new()
	hangars.name = "Hangars"
	geo.add_child(hangars)
	_hangar(hangars, "HangarA", HANGAR_A, 90.0, 4.5, 6.0)
	_hangar(hangars, "HangarB", HANGAR_B, 0.0, 6.0, 2.5)


## One hangar: shell, two sliding doors opened by `open_l` / `open_r` metres,
## its walls and the parked shuttle as colliders. Local front = +Z.
func _hangar(parent: Node3D, hangar_name: String, centre: Vector3, yaw: float, open_l: float, open_r: float) -> void:
	var holder := Node3D.new()
	holder.name = hangar_name
	holder.position = centre
	holder.rotation.y = deg_to_rad(yaw)
	parent.add_child(holder)
	var shell := _instance("dune_hangar")
	shell.name = "Shell"
	holder.add_child(shell)
	var door_l := _instance("dune_hangar_door_l")
	door_l.name = "DoorL"
	door_l.position = Vector3(-3.0 - open_l, 0, 11.75)
	holder.add_child(door_l)
	var door_r := _instance("dune_hangar_door_r")
	door_r.name = "DoorR"
	door_r.position = Vector3(3.0 + open_r, 0, 11.75)
	holder.add_child(door_r)
	for spec in [
		[Vector3(0.6, 7, 22), Vector3(-9.0, 3.5, 0)], [Vector3(0.6, 7, 22), Vector3(9.0, 3.5, 0)],
		[Vector3(18, 7, 0.6), Vector3(0, 3.5, -11.0)],
		[Vector3(3.6, 7, 1.0), Vector3(-7.4, 3.5, 11.2)], [Vector3(3.6, 7, 1.0), Vector3(7.4, 3.5, 11.2)],
		[Vector3(4.6, 4.6, 11.0), Vector3(1.5, 2.3, -3.0)],
	]:
		_collider(holder, "Collider%d" % holder.get_child_count(), spec[0], spec[1])


func _build_tunnel() -> void:
	var t := Node3D.new()
	t.name = "MaintenanceTunnel"
	t.position = TUNNEL
	geo.add_child(t)
	_prop(t, "dune_tunnel", "Portal", Vector3.ZERO, 0.0)
	var floor_mat := _mat("tunnel_floor", Color(0.32, 0.27, 0.27), 0.95)
	# Ramp down 2.6 m from the portal mouth, then a landing where zombies gather.
	var body := StaticBody3D.new()
	body.name = "TunnelRamp"
	t.add_child(body)
	var pts := PackedVector3Array()
	for x in [-2.7, 2.7]:
		pts.append(Vector3(x, 0.0, 0.6))
		pts.append(Vector3(x, -2.6, -8.0))
		pts.append(Vector3(x, -3.6, 0.6))
		pts.append(Vector3(x, -3.6, -8.0))
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var convex := ConvexPolygonShape3D.new()
	convex.points = pts
	shape.shape = convex
	body.add_child(shape)
	var ramp_mesh := MeshInstance3D.new()
	ramp_mesh.name = "RampSurface"
	var slope_len := Vector2(8.6, 2.6).length()
	ramp_mesh.mesh = _box_mesh(Vector3(5.4, 0.2, slope_len), floor_mat)
	ramp_mesh.position = Vector3(0, -1.4, -3.7)
	ramp_mesh.rotation.x = atan2(2.6, 8.6)
	t.add_child(ramp_mesh)
	_box(t, "Landing", Vector3(5.4, 1.0, 4.4), Vector3(0, -3.1, -10.2), floor_mat)
	for x in [-2.95, 2.95]:
		_collider(t, "Side%d" % int(x), Vector3(0.5, 6.0, 13.2), Vector3(x, -0.6, -6.0))
	_collider(t, "Back", Vector3(6.0, 6.0, 0.5), Vector3(0, -0.6, -12.6))
	for x in [-4.1, 4.1]:
		_collider(t, "Pier%d" % int(x), Vector3(2.8, 6.0, 1.2), Vector3(x, 2.0, 0.0))


func _build_cargo_lift() -> void:
	var lift := Node3D.new()
	lift.name = "CargoLift"
	lift.position = LIFT
	lift.rotation.y = deg_to_rad(-90.0)
	geo.add_child(lift)
	_prop(lift, "dune_cargo_lift", "Lift", Vector3(0, -0.28, 0), 0.0)
	for x in [-3.24, 3.24]:
		for z in [-3.24, 3.24]:
			_collider(lift, "Post%d%d" % [int(x), int(z)], Vector3(0.6, 8.5, 0.6), Vector3(x, 4.25, z))
	_collider(lift, "BackWall", Vector3(7.6, 7.5, 0.6), Vector3(0, 3.75, -4.0))


func _build_gate() -> void:
	var gate := Node3D.new()
	gate.name = "SecurityGate"
	gate.position = GATE
	gate.rotation.y = deg_to_rad(180.0)
	geo.add_child(gate)
	_prop(gate, "dune_gatehouse", "Gatehouse", Vector3.ZERO, 0.0)
	_collider(gate, "Booth", Vector3(3.4, 3.6, 3.4), Vector3(-6.6, 1.8, 0))
	for x in [-5.0, 5.0]:
		for z in [-2.5, 2.5]:
			_collider(gate, "Column%d%d" % [int(x), int(z)], Vector3(0.5, 4.8, 0.5), Vector3(x, 2.4, z))
	for x in [-4.2, 4.2]:
		_collider(gate, "Jersey%d" % int(x), Vector3(0.7, 0.9, 5.0), Vector3(x, 0.45, -5.85))
	_collider(gate, "BoomPost", Vector3(0.7, 1.4, 0.7), Vector3(4.4, 0.7, -1.2))


# ---------------------------------------------------------------------------
# Cover and set dressing inside the arena
# ---------------------------------------------------------------------------

const CONTAINER_COLORS := [Color(0.82, 0.35, 0.17), Color(0.13, 0.62, 0.6), Color(0.93, 0.89, 0.8),
	Color(0.85, 0.66, 0.22), Color(0.2, 0.3, 0.52), Color(0.72, 0.24, 0.2)]


func _build_cover() -> void:
	var cover := Node3D.new()
	cover.name = "Cover"
	geo.add_child(cover)
	# Containers: [position, yaw, colour index, stacked]
	var containers := [
		[Vector3(-18.5, 0, 4.5), 90.0, 0, false],
		[Vector3(-21.4, 0, -27.6), 0.0, 1, true],
		[Vector3(-15.8, 0, -21.0), 18.0, 3, false],
		[Vector3(17.6, 0, -7.0), 90.0, 2, false],
		[Vector3(22.2, 0, -21.5), 0.0, 4, true],
		[Vector3(19.5, 0, 16.4), 0.0, 5, false],
		[Vector3(-22.8, 0, 19.6), 90.0, 1, false],
	]
	var i := 0
	for c in containers:
		var pos: Vector3 = c[0]
		var levels := 2 if c[3] else 1
		for k in levels:
			var box := _prop(cover, "dune_container", "Container%d_%d" % [i, k], pos + Vector3(0, k * 2.6, 0), c[1] + k * 4.0)
			_tint(box, "ContainerPaint", CONTAINER_COLORS[(int(c[2]) + k * 2) % CONTAINER_COLORS.size()])
		var col := _collider(cover, "Container%dCollision" % i, Vector3(6.1, 2.6 * levels, 2.44), pos + Vector3(0, 1.3 * levels, 0))
		col.rotation.y = deg_to_rad(c[1])
		i += 1
	# Jersey barriers: low cover in the plaza and along the lanes.
	var barriers := [
		[Vector3(-6.4, 0, 16.0), 20.0], [Vector3(6.6, 0, 16.4), -24.0], [Vector3(-13.5, 0, 9.0), 90.0],
		[Vector3(13.6, 0, 3.8), 80.0], [Vector3(-15.2, 0, -13.0), 90.0], [Vector3(15.4, 0, -13.5), 95.0],
		[Vector3(-16.0, 0, 15.5), 0.0],
	]
	i = 0
	for b in barriers:
		_prop(cover, "dune_barrier", "Barrier%d" % i, b[0], b[1])
		var col := _collider(cover, "Barrier%dCollision" % i, Vector3(2.4, 0.9, 0.72), b[0] + Vector3(0, 0.45, 0))
		col.rotation.y = deg_to_rad(b[1])
		i += 1
	var smalls := [
		["dune_crates", Vector3(14.5, 0, 11.5), 30.0, Vector3(3.2, 1.6, 1.4)],
		["dune_crates", Vector3(-8.2, 0, -27.4), -15.0, Vector3(3.2, 1.6, 1.4)],
		["dune_barrels", Vector3(-23.8, 0, 11.2), 10.0, Vector3(2.2, 1.45, 2.4)],
		["dune_barrels", Vector3(12.6, 0, -24.5), -20.0, Vector3(2.2, 1.45, 2.4)],
		["dune_cable_reel", Vector3(23.4, 0, -12.5), 60.0, Vector3(1.4, 2.0, 2.0)],
		["dune_tug", Vector3(-17.5, 0, -6.5), 70.0, Vector3(7.4, 2.4, 2.2)],
		["dune_crates", Vector3(-19.8, 0, 23.6), 0.0, Vector3(3.2, 1.6, 1.4)],
	]
	i = 0
	for s in smalls:
		_prop(cover, s[0], "Prop%d" % i, s[1], s[2])
		var size: Vector3 = s[3]
		var offset := Vector3(1.9, 0, 0).rotated(Vector3.UP, deg_to_rad(s[2])) if s[0] == "dune_tug" else Vector3.ZERO
		var col := _collider(cover, "Prop%dCollision" % i, size, s[1] + offset + Vector3(0, size.y * 0.5, 0))
		col.rotation.y = deg_to_rad(s[2])
		i += 1
	# Floodlight masts in the corners, facing the pad.
	for spot in [Vector3(-24.8, 0, 24.8), Vector3(24.8, 0, 24.8), Vector3(24.8, 0, -30.2), Vector3(-24.8, 0, -30.2)]:
		var to_centre: Vector3 = MOUNT_C - spot
		var yaw := rad_to_deg(atan2(to_centre.x, to_centre.z))
		_prop(cover, "dune_light_mast", "Mast%d" % i, spot, yaw)
		_collider(cover, "Mast%dCollision" % i, Vector3(0.7, 8.0, 0.7), spot + Vector3(0, 4.0, 0))
		i += 1
	# White-and-teal ground equipment and wayfinding: the spacecraft livery
	# against the sand and rust (cool accents for colour contrast).
	var accents := [
		["dune_gse_cart", Vector3(12.0, 0, 21.0), -15.0, Vector3(3.6, 1.75, 1.5), Vector3(-0.2, 0, 0)],
		["dune_gse_cart", Vector3(20.5, 0, -16.5), 90.0, Vector3(3.6, 1.75, 1.5), Vector3(-0.2, 0, 0)],
		["dune_console", Vector3(-9.0, 0, 2.4), 35.0, Vector3(1.9, 1.3, 1.0), Vector3.ZERO],
		["dune_totem", Vector3(-6.5, 0, 19.0), 30.0, Vector3(1.0, 3.3, 0.5), Vector3.ZERO],
		["dune_totem", Vector3(11.2, 0, 9.0), -90.0, Vector3(1.0, 3.3, 0.5), Vector3.ZERO],
	]
	for a in accents:
		_prop(cover, a[0], "Accent%d" % i, a[1], a[2])
		var size: Vector3 = a[3]
		var yaw := deg_to_rad(a[2])
		var col := _collider(cover, "Accent%dCollision" % i, size, a[1] + (a[4] as Vector3).rotated(Vector3.UP, yaw) + Vector3(0, size.y * 0.5, 0))
		col.rotation.y = yaw
		i += 1
	_prop(dressing, "dune_windsock", "Windsock", Vector3(24.6, 0, 20.0), 70.0)
	_collider(cover, "WindsockPole", Vector3(0.4, 4.0, 0.4), Vector3(24.6, 2.0, 20.0))
	_prop(dressing, "dune_sign", "PadSign", Vector3(15.5, 0, 25.4), 180.0)
	for x in [-2.5, 2.5]:
		_collider(cover, "PadSignLeg%d" % int(x), Vector3(0.4, 4.0, 0.4), Vector3(15.5 - x, 2.0, 25.2))


## Lamp posts along the walls, cones at the ramp feet, warning signs by the mount.
func _build_details() -> void:
	var details := Node3D.new()
	details.name = "Details"
	geo.add_child(details)
	var lamps := [Vector3(-24.6, 0, 18.0), Vector3(-24.6, 0, 6.0), Vector3(-24.6, 0, -2.5), Vector3(24.6, 0, 12.5),
		Vector3(24.6, 0, -3.0), Vector3(24.6, 0, -16.5), Vector3(-5.5, 0, 24.6), Vector3(6.0, 0, 24.6),
		Vector3(-0.5, 0, -30.6), Vector3(21.5, 0, -30.6)]
	var i := 0
	for spot in lamps:
		_prop(details, "dune_lamp", "Lamp%02d" % i, spot, i * 37.0)
		_collider(details, "Lamp%02dCollision" % i, Vector3(0.45, 4.0, 0.45), spot + Vector3(0, 2.0, 0))
		i += 1
	var cones := [Vector3(4.3, 0, 6.9), Vector3(9.7, 0, 6.9), Vector3(-5.1, 0, -24.9), Vector3(0.1, 0, -24.9),
		Vector3(-15.0, 0, -4.2), Vector3(-14.3, 0, -5.4), Vector3(13.2, 0, 13.4)]
	i = 0
	for spot in cones:
		_prop(dressing, "dune_cone", "Cone%02d" % i, spot, i * 23.0)
		i += 1
	var signs := [[Vector3(-12.4, 0, -3.0), -90.0], [Vector3(12.4, 0, -15.2), 90.0], [Vector3(-3.6, 0, 0.8), 0.0],
		[Vector3(3.0, 0, -18.6), 180.0]]
	i = 0
	for spec in signs:
		_prop(dressing, "dune_warning", "Warning%d" % i, spec[0], spec[1])
		i += 1


func _build_station_and_portal() -> void:
	var station: Node3D = (load("res://scenes/props/dune_station.tscn") as PackedScene).instantiate()
	station.name = "LoadoutStation"
	geo.add_child(station)
	station.position = STATION_POS

	var portal: Node3D = (load("res://scenes/props/portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	geo.add_child(portal)
	portal.position = PORTAL_POS

	var lights := Node3D.new()
	lights.name = "ExitLights"
	level.add_child(lights)
	var route: Array[Vector3] = [Vector3(4.2, 0, 4.4), Vector3(10.8, 0, 0.6), Vector3(12.6, 0, -4.0),
		Vector3(12.6, 0, -16.8), Vector3(10.0, 0, -21.6), Vector3(6.6, 0, -24.0)]
	var strip := BoxMesh.new()
	strip.size = Vector3(1.3, 0.04, 0.24)
	var light_script: Script = load("res://scripts/props/exit_light.gd")
	var order := 0
	for k in route.size() - 1:
		var a := route[k]
		var b := route[k + 1]
		var seg := a.distance_to(b)
		var n := maxi(1, int(seg / 2.4))
		for s in n:
			var p := a.lerp(b, float(s) / n)
			var mi := MeshInstance3D.new()
			mi.name = "ExitLight%02d" % order
			mi.mesh = strip
			mi.position = p + Vector3(0, 0.03, 0)
			var d := b - a
			mi.rotation.y = atan2(d.x, d.z)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.set_script(light_script)
			mi.set("order", order)
			lights.add_child(mi)
			order += 1


# ---------------------------------------------------------------------------
# Paint: hazard kerbs around the mount, lane lines, the pod's landing circle
# ---------------------------------------------------------------------------

## A painted strip of diagonal hazard stripes lying on the ground (one stripe tile per 1.2 m).
func _hazard_strip(parent: Node3D, pos: Vector3, length: float, width: float, yaw: float) -> void:
	var key := "hazard_%.1f" % length
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.resource_name = "HazardPaint"
		m.albedo_texture = load(TEX + "dune_hazard.png")
		m.roughness = 0.75
		m.uv1_scale = Vector3(length / 1.2, 1.0, 1.0)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_materials[key] = m
	var plane := PlaneMesh.new()
	plane.size = Vector2(length, width)
	plane.material = _materials[key]
	var mi := MeshInstance3D.new()
	mi.name = "Hazard%02d" % parent.get_child_count()
	mi.mesh = plane
	mi.position = pos + Vector3(0, 0.006, 0)
	mi.rotation.y = deg_to_rad(yaw)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _build_markings() -> void:
	var paint := Node3D.new()
	paint.name = "Paint"
	level.add_child(paint)
	var y := 0.012
	var c := MOUNT_C
	var hx := MOUNT_SIZE.x * 0.5 + 1.2
	var hz := MOUNT_SIZE.y * 0.5 + 1.2
	# Hazard kerb around the mount (the ramps run over it).
	for spec in [[Vector3(0, y, c.z - hz), hx * 2.0 + 0.6, 0.0], [Vector3(0, y, c.z + hz), hx * 2.0 + 0.6, 0.0],
			[Vector3(-hx, y, c.z), hz * 2.0 - 0.6, 90.0], [Vector3(hx, y, c.z), hz * 2.0 - 0.6, 90.0]]:
		_hazard_strip(paint, spec[0], spec[1], 0.6, spec[2])
	var yellow := _mat("paint_yellow", Color(0.98, 0.76, 0.16), 0.7)
	var white := _mat("paint_white", Color(0.95, 0.92, 0.86), 0.7)
	# Lane lines: dashed down the west and east lanes and across the plaza.
	for lane_x in [-17.5, 17.5]:
		var z := 22.0
		while z > -29.0:
			_decal(paint, Vector3(lane_x, y, z), Vector3(0.22, 0.01, 2.0), yellow)
			z -= 3.6
	var x := -22.0
	while x < 22.0:
		if absf(x) > 9.0:
			_decal(paint, Vector3(x, y, 0.8), Vector3(2.0, 0.01, 0.22), white)
		x += 3.6
	# The supply pod's landing circle and its pad number.
	var ring := MeshInstance3D.new()
	ring.name = "PodCircle"
	ring.mesh = _ring_mesh(7.7, 8.2, 64)
	ring.material_override = yellow
	ring.position = STATION_POS + Vector3(0, y, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paint.add_child(ring)
	var ring2 := MeshInstance3D.new()
	ring2.name = "PodCircleInner"
	ring2.mesh = _ring_mesh(6.6, 6.75, 64)
	ring2.material_override = white
	ring2.position = STATION_POS + Vector3(0, y, 0)
	ring2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paint.add_child(ring2)
	_stencil(paint, "09", STATION_POS + Vector3(0, y + 0.004, 5.2), 0.0, 2.4, Color(0.98, 0.76, 0.16))
	_stencil(paint, "LAUNCH PAD 9", Vector3(0, y + 0.004, c.z + hz + 2.2), 0.0, 1.5, Color(0.95, 0.92, 0.86))
	_stencil(paint, "BLAST ZONE", Vector3(-hx - 1.6, y + 0.004, c.z), 90.0, 1.4, Color(0.98, 0.76, 0.16))
	_stencil(paint, "BLAST ZONE", Vector3(hx + 1.6, y + 0.004, c.z), -90.0, 1.4, Color(0.98, 0.76, 0.16))
	_stencil(paint, "KEEP CLEAR", Vector3(-12.0, y + 0.004, 21.5), 0.0, 1.1, Color(0.95, 0.92, 0.86))


func _decal(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Paint%03d" % parent.get_child_count()
	mi.mesh = _box_mesh(size, material)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Flat painted lettering on the ground.
func _stencil(parent: Node3D, text: String, pos: Vector3, yaw: float, height: float, color: Color) -> void:
	var label := Label3D.new()
	label.name = "Stencil%02d" % parent.get_child_count()
	label.text = text
	label.font = load("res://art/fonts/LilitaOne-Regular.ttf")
	label.font_size = 128
	label.pixel_size = height / 128.0
	label.modulate = Color(color, 0.9)
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	label.position = pos
	label.rotation = Vector3(deg_to_rad(-90.0), deg_to_rad(yaw), 0.0)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(label)


func _ring_mesh(inner: float, outer: float, segments: int) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in segments:
		var a0 := TAU * k / segments
		var a1 := TAU * (k + 1) / segments
		var p := [Vector3(cos(a0) * inner, 0, sin(a0) * inner), Vector3(cos(a0) * outer, 0, sin(a0) * outer),
			Vector3(cos(a1) * outer, 0, sin(a1) * outer), Vector3(cos(a1) * inner, 0, sin(a1) * inner)]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p[idx])
	return st.commit()


# ---------------------------------------------------------------------------
# Blinking lights: plaza approach rows, the blast-zone perimeter, deck corners
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	var lights := Node3D.new()
	lights.name = "BlinkLights"
	level.add_child(lights)
	# Approach rows from the gate side of the plaza toward the pod (chasing inward).
	var approach: Array = []
	for side in [-3.4, 3.4]:
		for k in 7:
			approach.append([Vector3(side, 0.0, 24.0 - k * 1.6), float(k) / 7.0])
	_blink_set(lights, "Approach", approach, Color(0.35, 0.9, 1.0), 0.7, 0.18)
	# Amber chaser around the blast-zone border.
	var perimeter: Array = []
	var c := MOUNT_C
	var hx := MOUNT_SIZE.x * 0.5 + 2.0
	var hz := MOUNT_SIZE.y * 0.5 + 2.0
	var corners := [Vector3(-hx, 0, c.z + hz), Vector3(hx, 0, c.z + hz), Vector3(hx, 0, c.z - hz), Vector3(-hx, 0, c.z - hz)]
	var total := 0.0
	for k in 4:
		total += corners[k].distance_to(corners[(k + 1) % 4])
	var travelled := 0.0
	for k in 4:
		var a: Vector3 = corners[k]
		var b: Vector3 = corners[(k + 1) % 4]
		var seg := a.distance_to(b)
		var n := int(seg / 2.0)
		for s in n:
			var p := a.lerp(b, float(s) / n)
			# Leave the ramp feet clear.
			if (absf(p.x - 7.0) < 2.6 and p.z > c.z) or (absf(p.x + 2.5) < 2.6 and p.z < c.z):
				continue
			perimeter.append([p, (travelled + seg * s / n) / total * 3.0])
		travelled += seg
	_blink_set(lights, "BlastPerimeter", perimeter, Color(1.0, 0.55, 0.12), 0.35, 0.12)
	# Red obstruction lights on the deck corners (slow blink).
	var deck: Array = []
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			deck.append([c + Vector3(sx * (MOUNT_SIZE.x * 0.5 - 0.5), DECK_Y, sz * (MOUNT_SIZE.y * 0.5 - 0.5)), 0.25 * (sx + sz + 2)])
	_blink_set(lights, "DeckCorners", deck, Color(1.0, 0.22, 0.16), 0.5, 0.5)


## A MultiMesh of light fixtures plus one of halos, sharing phases.
func _blink_set(parent: Node3D, set_name: String, entries: Array, color: Color, speed: float, duty: float) -> void:
	var housing := CylinderMesh.new()
	housing.top_radius = 0.16
	housing.bottom_radius = 0.2
	housing.height = 0.1
	housing.radial_segments = 10
	housing.rings = 1
	var lens := ShaderMaterial.new()
	lens.shader = load("res://art/shaders/dune_blink.gdshader")
	lens.set_shader_parameter("light_color", color)
	lens.set_shader_parameter("speed", speed)
	lens.set_shader_parameter("duty", duty)
	housing.material = lens
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = housing
	mm.instance_count = entries.size()
	var halo_mm := MultiMesh.new()
	halo_mm.transform_format = MultiMesh.TRANSFORM_3D
	halo_mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var halo := ShaderMaterial.new()
	halo.shader = load("res://art/shaders/dune_blink_halo.gdshader")
	halo.set_shader_parameter("light_color", color)
	halo.set_shader_parameter("speed", speed)
	halo.set_shader_parameter("duty", duty)
	quad.material = halo
	halo_mm.mesh = quad
	halo_mm.instance_count = entries.size()
	for k in entries.size():
		var t := Transform3D(Basis(), entries[k][0] + Vector3(0, 0.05, 0))
		var custom := Color(fposmod(entries[k][1], 1.0), 0, 0, 0)
		mm.set_instance_transform(k, t)
		mm.set_instance_custom_data(k, custom)
		halo_mm.set_instance_transform(k, t)
		halo_mm.set_instance_custom_data(k, custom)
	var node := MultiMeshInstance3D.new()
	node.name = set_name
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	var halos := MultiMeshInstance3D.new()
	halos.name = set_name + "Halos"
	halos.multimesh = halo_mm
	halos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halos.custom_aabb = AABB(Vector3(-60, -5, -60), Vector3(120, 40, 120))
	halos.add_to_group("high_detail", true)
	parent.add_child(halos)


# ---------------------------------------------------------------------------
# Vapour: the rocket breathing at its base, a LOX vent plume, deck grilles
# ---------------------------------------------------------------------------

func _build_vapour() -> void:
	var vapour := Node3D.new()
	vapour.name = "Vapour"
	level.add_child(vapour)
	var c := MOUNT_C
	# Base: puffs roll outward from under the skirt along each emitter's facing.
	var base: Array = []
	for k in 8:
		var a := TAU * k / 8.0 + 0.2
		base.append([c + Vector3(cos(a) * 2.4, 3.2, sin(a) * 2.4), a])
	_vapour_set(vapour, "RocketBase", base, 6, {"drift": Vector3(0, 0, 2.6), "rise": 1.2, "life": 3.6,
		"size_start": 0.7, "size_end": 2.3, "opacity": 0.36})
	# LOX vent high on the hull: a white plume blown sideways that sinks as it cools.
	var vent: Array = [[c + Vector3(2.15, 24.0, 0.4), 0.0], [c + Vector3(-0.6, 15.0, 2.05), PI * 0.5]]
	_vapour_set(vapour, "LoxVent", vent, 10, {"drift": Vector3(0, 0, 5.5), "rise": -3.5, "life": 3.0,
		"size_start": 0.4, "size_end": 2.6, "opacity": 0.6})
	# Deck grilles and the tail service masts.
	var grilles: Array = []
	for g in [Vector2(-4.6, 5.4), Vector2(4.6, -5.4), Vector2(6.8, 5.3), Vector2(-6.6, -5.3)]:
		grilles.append([c + Vector3(g.x, DECK_Y + 0.1, -g.y), 0.0])
	_vapour_set(vapour, "DeckGrilles", grilles, 5, {"drift": Vector3(0.8, 0, 0.4), "rise": 4.0, "life": 4.0,
		"size_start": 0.5, "size_end": 1.8, "opacity": 0.35})


func _vapour_set(parent: Node3D, set_name: String, emitters: Array, per_emitter: int, params: Dictionary) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var m := ShaderMaterial.new()
	m.shader = load("res://art/shaders/dune_vapour.gdshader")
	m.set_shader_parameter("noise_tex", load(TEX + "dune_noise.png"))
	for key in params:
		m.set_shader_parameter(key, params[key])
	quad.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = emitters.size() * per_emitter
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(set_name)
	var idx := 0
	for e in emitters:
		var pos: Vector3 = e[0]
		var yaw: float = e[1]
		for k in per_emitter:
			var basis := Basis(Vector3.UP, PI * 0.5 - yaw)
			mm.set_instance_transform(idx, Transform3D(basis, pos + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))))
			mm.set_instance_custom_data(idx, Color(float(k) / per_emitter + rng.randf() * 0.08, rng.randf_range(0.85, 1.15),
				rng.randf_range(0.8, 1.2), rng.randf_range(0.7, 1.2)))
			idx += 1
	var node := MultiMeshInstance3D.new()
	node.name = set_name
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-60, -5, -60), Vector3(120, 60, 120))
	parent.add_child(node)


# ---------------------------------------------------------------------------
# Blowing sand
# ---------------------------------------------------------------------------

func _build_sand() -> void:
	var sand := Node3D.new()
	sand.name = "BlowingSand"
	level.add_child(sand)
	var m := ShaderMaterial.new()
	m.shader = load("res://art/shaders/dune_sand_wisps.gdshader")
	m.set_shader_parameter("noise_tex", load(TEX + "dune_noise.png"))
	var curtain := m.duplicate() as ShaderMaterial
	curtain.set_shader_parameter("opacity", 0.22)
	curtain.set_shader_parameter("stretch", Vector2(2.0, 1.0))
	curtain.set_shader_parameter("density", 0.5)
	# Ground-hugging drifts snaking along the wind (west to east).
	var flats := [Vector3(-12, 0.05, 18), Vector3(12, 0.05, 20), Vector3(-15, 0.05, -10), Vector3(16, 0.05, -26),
		Vector3(0, 0.05, -24), Vector3(-8, 0.05, 3), Vector3(18, 0.05, 6)]
	var i := 0
	for p in flats:
		var mi := MeshInstance3D.new()
		mi.name = "Drift%d" % i
		var plane := PlaneMesh.new()
		plane.size = Vector2(22, 5)
		plane.material = m
		mi.mesh = plane
		mi.position = p
		mi.rotation.y = deg_to_rad(-8.0 + i * 5.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sand.add_child(mi)
		i += 1
	# Sand spilling over the west and north wall tops.
	for spec in [[Vector3(X0 + 0.4, 4.3, 12), 90.0], [Vector3(X0 + 0.4, 4.3, -27), 90.0], [Vector3(-12, 4.3, -32.4), 0.0],
			[Vector3(2.5, 4.3, -32.4), 0.0], [Vector3(X1 - 0.4, 4.3, -14), 90.0]]:
		var mi := MeshInstance3D.new()
		mi.name = "Curtain%d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2(14, 2.6)
		quad.material = curtain
		mi.mesh = quad
		mi.position = spec[0]
		mi.rotation.y = deg_to_rad(spec[1])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_to_group("high_detail", true)
		sand.add_child(mi)
		i += 1


# ---------------------------------------------------------------------------
# Skyline: tower, tanks, dishes, monorail, dunes, mesas, distant pads
# ---------------------------------------------------------------------------

func _build_backdrop() -> void:
	var bd := Node3D.new()
	bd.name = "Backdrop"
	level.add_child(bd)
	_prop(bd, "dune_tower", "ControlTower", Vector3(37.0, 0, -42.0), -40.0)
	_prop(bd, "dune_tank_sphere", "LoxTankA", Vector3(34.0, 0, -12.0), 20.0)
	_prop(bd, "dune_tank_sphere", "LoxTankB", Vector3(35.5, 0, 17.0), -10.0)
	_prop(bd, "dune_tank_long", "FuelTankA", Vector3(32.0, 0, -24.5), 90.0)
	_prop(bd, "dune_tank_long", "FuelTankB", Vector3(-34.0, 0, 4.0), 90.0)
	_prop(bd, "dune_dish", "Dish0", Vector3(33.0, 0, 31.0), -140.0)
	_prop(bd, "dune_dish", "Dish1", Vector3(-35.0, 0, 21.0), 120.0)
	_prop(bd, "dune_dish", "Dish2", Vector3(-12.0, 10.1, -47.0), 20.0)
	_prop(bd, "dune_dish", "Dish3", Vector3(-46.0, 10.1, -14.0), 70.0)
	_prop(bd, "dune_radio_mast", "MastA", Vector3(68.0, 0, -80.0), 0.0)
	_prop(bd, "dune_radio_mast", "MastB", Vector3(-82.0, 0, 46.0), 30.0)
	_prop(bd, "dune_crates", "OutCrates", Vector3(31.0, 0, 9.5), 10.0)
	_prop(bd, "dune_tug", "OutTug", Vector3(-30.0, 0, 30.0), 200.0)
	# Monorail running north-south beyond the east wall, with a train parked mid-way.
	var z := -70.0
	while z <= 70.0:
		_prop(bd, "dune_monorail_pylon", "MonoPylon%d" % int(z), Vector3(46.0, 0, z), 90.0)
		if z < 70.0:
			_prop(bd, "dune_monorail_beam", "MonoBeam%d" % int(z), Vector3(46.0, 0, z + 5.0), 90.0)
		z += 10.0
	_prop(bd, "dune_monorail_car", "MonoCar", Vector3(46.0, 0, 8.0), 90.0)
	# A second, distant pad with its own rocket, and two far gantries.
	_prop(bd, "dune_launch_mount", "FarMount", Vector3(-150.0, 0, -210.0), 30.0)
	_prop(bd, "dune_gantry", "FarGantry", Vector3(-156.7, 2.0, -206.1), 30.0)
	_prop(bd, "dune_rocket", "FarRocket", Vector3(-150.0, 2.6, -210.0), 30.0)
	_prop(bd, "dune_gantry", "FarGantryB", Vector3(190.0, 0, -160.0), -60.0)
	# Dunes ring the spaceport; mesas and buttes stand on the horizon.
	var dunes := [
		["dune_sanddune_a", Vector3(-80, 0, -10), 70.0, 1.0], ["dune_sanddune_b", Vector3(-70, 0, 60), 20.0, 1.2],
		["dune_sanddune_a", Vector3(10, 0, 85), 170.0, 1.3], ["dune_sanddune_b", Vector3(75, 0, 50), -30.0, 1.1],
		["dune_sanddune_a", Vector3(85, 0, -30), -80.0, 1.2], ["dune_sanddune_b", Vector3(30, 0, -90), 200.0, 1.4],
		["dune_sanddune_a", Vector3(-45, 0, -95), 120.0, 1.1], ["dune_sanddune_b", Vector3(-110, 0, 25), 90.0, 1.6],
	]
	for d in dunes:
		var n := _prop(bd, d[0], "Dune%d" % bd.get_child_count(), d[1], d[2])
		n.scale = Vector3.ONE * float(d[3])
	var rocks := [
		["dune_mesa_a", Vector3(-250, 0, -260), 20.0, 2.2], ["dune_mesa_b", Vector3(-60, 0, -300), 60.0, 2.0],
		["dune_butte", Vector3(90, 0, -260), 0.0, 1.8], ["dune_mesa_a", Vector3(300, 0, -120), -40.0, 1.8],
		["dune_hoodoo", Vector3(120, 0, -110), 30.0, 1.3], ["dune_mesa_b", Vector3(260, 0, 160), 10.0, 2.2],
		["dune_mesa_a", Vector3(-320, 0, 60), 80.0, 2.0], ["dune_butte", Vector3(-220, 0, 200), 40.0, 2.0],
		["dune_mesa_b", Vector3(40, 0, 300), -20.0, 2.4], ["dune_hoodoo", Vector3(-140, 0, -120), 0.0, 1.5],
		["dune_butte", Vector3(200, 0, -250), 70.0, 1.5], ["dune_hoodoo", Vector3(150, 0, 90), 50.0, 1.2],
	]
	for r in rocks:
		var n := _prop(bd, r[0], "Rock%d" % bd.get_child_count(), r[1], r[2])
		n.scale = Vector3.ONE * float(r[3])


## Ambient motion: dishes sweep, the tower radar spins, the monorail glides by.
func _build_animation() -> void:
	var player := AnimationPlayer.new()
	player.name = "Ambient"
	level.add_child(player)
	var lib := AnimationLibrary.new()
	var dishes := Animation.new()
	dishes.length = 48.0
	dishes.loop_mode = Animation.LOOP_LINEAR
	var k := 0
	for dish_name in ["Dish0", "Dish1", "Dish2", "Dish3"]:
		var t := dishes.add_track(Animation.TYPE_VALUE)
		dishes.track_set_path(t, NodePath("Backdrop/%s/DishHead:rotation:y" % dish_name))
		dishes.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
		var swing := 0.5 + 0.15 * k
		dishes.track_insert_key(t, 0.0, 0.0)
		dishes.track_insert_key(t, 12.0 + k, swing)
		dishes.track_insert_key(t, 30.0 + k, -swing)
		dishes.track_insert_key(t, 48.0, 0.0)
		k += 1
	var radar := dishes.add_track(Animation.TYPE_VALUE)
	dishes.track_set_path(radar, NodePath("Backdrop/ControlTower/Radar:rotation:y"))
	for step in 9:
		dishes.track_insert_key(radar, step * 6.0, -TAU * step)
	var car := dishes.add_track(Animation.TYPE_VALUE)
	dishes.track_set_path(car, NodePath("Backdrop/MonoCar:position:z"))
	dishes.track_set_interpolation_type(car, Animation.INTERPOLATION_CUBIC)
	dishes.track_insert_key(car, 0.0, -60.0)
	dishes.track_insert_key(car, 16.0, 55.0)
	dishes.track_insert_key(car, 24.0, 55.0)
	dishes.track_insert_key(car, 40.0, -60.0)
	dishes.track_insert_key(car, 48.0, -60.0)
	lib.add_animation(&"ambient", dishes)
	player.add_animation_library(&"", lib)
	player.autoplay = "ambient"


# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(0.0, 0.1, 21.5)
	start.rotation.y = deg_to_rad(4.0)
	start.add_to_group("player_spawn", true)
	level.add_child(start)

	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	var points := {
		"SpawnHangarA": [Vector3(-31.5, 0.1, -14.0), 90.0],
		"SpawnHangarB": [Vector3(-12.0, 0.1, -37.0), 0.0],
		"SpawnTunnel": [Vector3(14.0, -2.5, -42.0), 0.0],
		"SpawnCargoLift": [Vector3(29.5, 0.1, 4.0), -90.0],
		"SpawnGate": [Vector3(-12.0, 0.1, 35.0), 180.0],
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
	# Floors up to the launch deck (2 m); container, crate and wall tops stay out.
	mesh.filter_baking_aabb = AABB(Vector3(-60, -4.0, -60), Vector3(120, 6.7, 110))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	region.navigation_mesh = _largest_island(mesh)
	print("build_launch_pad: navmesh polygons = %d (dropped %d on prop tops)" % [region.navigation_mesh.get_polygon_count(),
		before - region.navigation_mesh.get_polygon_count()])


## Keeps only the largest connected set of polygons. The bake clips tall props
## (launch table, gantry, the tug) at the top of the baking box, which leaves
## small walkable islands on their tops; nothing can reach those, so drop them.
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
				var a := _find(parent, i)
				var b := _find(parent, owner_of[v])
				parent[a] = b
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
		var poly := mesh.get_polygon(i)
		var mapped := PackedInt32Array()
		for v in poly:
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

func _mat(key: String, color: Color, roughness := 0.7) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = color
	m.roughness = roughness
	_materials[key] = m
	return m


func _box_mesh(size: Vector3, material: Material) -> BoxMesh:
	var key := "%s|%s" % [size, material.get_instance_id()]
	if _meshes.has(key):
		return _meshes[key]
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	_meshes[key] = mesh
	return mesh


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


func _instance(model: String) -> Node3D:
	return (load(MODELS + model + ".glb") as PackedScene).instantiate()


## Instances art/models/<model>.glb at a position and yaw.
func _prop(parent: Node3D, model: String, prop_name: String, pos: Vector3, yaw_degrees: float) -> Node3D:
	var node := _instance(model)
	node.name = prop_name
	parent.add_child(node)
	node.position = pos
	node.rotation.y = deg_to_rad(yaw_degrees)
	return node


## Recolours every surface using the material named `material_name`.
func _tint(node: Node3D, material_name: String, color: Color) -> void:
	_editable.append(node)
	var key := "%s_%s" % [material_name, color.to_html()]
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var base := m.mesh.surface_get_material(i) as StandardMaterial3D
			if base and base.resource_name == material_name:
				if not _materials.has(key):
					var copy: StandardMaterial3D = base.duplicate()
					copy.albedo_color = color
					_materials[key] = copy
				m.set_surface_override_material(i, _materials[key])


## Many copies of one model's mesh as a single MultiMesh (cheap repeated props).
func _multimesh(parent: Node3D, mm_name: String, model: String, transforms: Array[Transform3D]) -> void:
	var src := _instance(model)
	var mesh_node := src.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_node.mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	src.free()
	var node := MultiMeshInstance3D.new()
	node.name = mm_name
	node.multimesh = mm
	parent.add_child(node)


func _own(node: Node) -> void:
	for child in node.get_children():
		child.owner = level
		if child.scene_file_path == "":
			_own(child)
