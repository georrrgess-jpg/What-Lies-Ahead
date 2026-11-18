extends SceneTree
## Generator for World 11 "Fright Fair" / level "Ghost Train".
##
## Rebuilds scenes/levels/ghost_train.tscn: a haunted fairground at midnight
## under a huge full moon. The plaza round the Creeps & Treats station, the
## Ghost Train façade with its giant grinning skull (the ride's track runs out
## of the mouth and round a loop in the plaza), the boarding platforms either
## side of the skull, the crooked hall of mirrors (west, enterable), the
## creaky carousel of skeletal horses (east), the misty graveyard maze and its
## crypt (south-east), the front gate and the exit portal (south), five zombie
## entrances, wrought-iron fencing, dead trees, hills and the haunted manor
## against the moon, lantern strings, bats and mist, and a baked navigation mesh.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_ghost_train.gd
##
## Run it with a renderer (not --headless): the headless renderer keeps no
## MultiMesh instance data, so fences and props would save empty.
##
## NOTE: running this overwrites hand edits made to ghost_train.tscn.
##
## Layout (metres, top view; -Z = north; ground at y 0):
##   - Arena x -31..31, z -24..27.5, fenced; the ghost-train façade closes the
##     north side (x -15..15) with the skull's mouth at x 0.
##   - Station at (0, 0, 1); the track loop (centre (0, -12.5), radius 5) and its
##     spur into the mouth; boarding platforms (y 1.8) x +-3.9..12.2.
##   - Hall of mirrors x -28..-18, z -10..4 (doors east, north, west).
##   - Carousel at (19, 0, -3); graveyard maze x 9..29, z 9..26, crypt in its
##     south-east corner; front gate and portal at z 27.5.
##   - Entrances: skull mouth (N), crypt (SE), hall back door (W), staff gate
##     (E), hayride gate (SW).

const OUT_PATH := "res://scenes/levels/ghost_train.tscn"
const MODELS := "res://art/models/"
const TEXTURES := "res://art/textures/"
const SHADERS := "res://art/shaders/"
const KIT := "fright_kit"
const LANDMARKS := "fright_landmarks"

const STATION := Vector3(0.0, 0.0, 1.0)
const FACADE_Z := -24.0
const MOUTH_HALF := 2.3
const PLATFORM_Y := 1.8
const PLATFORM_X := Vector2(3.9, 12.2)
const PLATFORM_Z := Vector2(-23.9, -19.5)
const TRACK_C := Vector3(0.0, 0.0, -12.5)
const TRACK_R := 5.0
const CAROUSEL := Vector3(19.0, 0.0, -3.0)
const HALL := Vector3(-23.0, 0.0, -3.0)
const CRYPT := Vector3(24.0, -0.28, 24.6)
const GATE_Z := 27.5
const PORTAL := Vector3(0.0, 0.0, 26.0)
const ARENA := Rect2(-31.0, -24.0, 62.0, 51.5)
const MOON_DIRECTION := Vector3(-0.42, 0.33, -0.85)
const PLAYER_WALL_H := 10.0

var level: Node3D
var geo: Node3D          # collidable geometry (navmesh source)
var dressing: Node3D     # non-colliding scenery
var _materials := {}
var _boxes := {}
var _late_scripts: Array = []
var _light_count := 0
var _kits := {}
var _rows := {}          # kit mesh name -> Array[Transform3D] (one MultiMesh each)
var _lines: SurfaceTool
var _clutter: Array[StaticBody3D] = []


func _initialize() -> void:
	level = Node3D.new()
	level.name = "GhostTrain"
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
	_lines = SurfaceTool.new()
	_lines.begin(Mesh.PRIMITIVE_TRIANGLES)

	_build_ground()
	_build_boundary()
	_build_ghost_train()
	_build_track()
	_build_station()
	_build_plaza_props()
	_build_mirror_hall()
	_build_carousel()
	_build_graveyard()
	_build_gates()
	_build_lights()
	_build_backdrop()
	_build_exit()
	_build_markers()
	_finish_rows()
	_finish_lines()
	var twist := Node3D.new()
	twist.name = "LightsOut"
	level.add_child(twist)
	_late(twist, "res://scripts/props/fright_lights_out.gd", {})

	get_root().add_child(level)
	await process_frame
	_bake_navigation(nav)
	get_root().remove_child(level)
	_flatten_clutter()

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
	print("build_ghost_train: saved %s (error %d), %d omni lights" % [OUT_PATH, err, _light_count])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: the midnight sky shader, cold moonlight from the north-west
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SHADERS + "fright_sky.gdshader")
	sky_mat.set_shader_parameter("moon_direction", MOON_DIRECTION.normalized())
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.46, 0.86)
	env.ambient_light_energy = 0.82
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.tonemap_exposure = 1.08
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.15, 0.36)
	env.fog_density = 0.0065
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.looking_at(-MOON_DIRECTION.normalized(), Vector3.UP), Vector3(0, 30, 0))
	sun.light_color = Color(0.74, 0.76, 1.0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_opacity = 0.75
	level.add_child(sun)

	# Lantern bounce from the south-east: a warm lift on the moon's shadow side.
	var fill := DirectionalLight3D.new()
	fill.name = "LanternFill"
	fill.transform = Transform3D(Basis.looking_at(-Vector3(0.5, 0.45, 0.7).normalized(), Vector3.UP), Vector3(0, 30, 0))
	fill.light_color = Color(1.0, 0.62, 0.38)
	fill.light_energy = 0.22
	fill.shadow_enabled = false
	level.add_child(fill)


# ---------------------------------------------------------------------------
# Ground: one turf slab, cobbled paths and the plaza
# ---------------------------------------------------------------------------

func _build_ground() -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	geo.add_child(ground)
	var turf := _textured("turf", "fright_turf", 0.12, 0.95)
	_box(ground, "GroundSlab", Vector3(78, 1.0, 70), Vector3(0, -0.5, 0.5), turf)
	# The wide outer ground under the scenery (visual only).
	var outer := MeshInstance3D.new()
	outer.name = "OuterGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	outer.mesh = plane
	outer.material_override = turf
	outer.position = Vector3(0, -0.02, 0)
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(outer)
	var cobble := _textured("cobble", "fright_cobble", 0.22, 0.85)
	# Paths: gate to station to the track, hall door to carousel, a spur to the graveyard.
	_path("PathSouth", Vector3(0, 0, 14.5), Vector3(5.0, 0, 26.0), cobble)
	_path("PathNorth", Vector3(0, 0, -5.5), Vector3(5.0, 0, 7.0), cobble)
	_path("PathWest", Vector3(-11.0, 0, -0.5), Vector3(14.0, 0, 4.4), cobble)
	_path("PathEast", Vector3(10.0, 0, -1.0), Vector3(14.0, 0, 4.4), cobble)
	_path("PathGrave", Vector3(10.5, 0, 11.0), Vector3(7.0, 0, 4.0), cobble)
	_path("PathPlatform", Vector3(0, 0, -17.0), Vector3(26.0, 0, 5.4), cobble)
	var plaza := MeshInstance3D.new()
	plaza.name = "Plaza"
	var disc := CylinderMesh.new()
	disc.top_radius = 7.5
	disc.bottom_radius = 7.5
	disc.height = 0.05
	disc.radial_segments = 48
	plaza.mesh = disc
	plaza.material_override = cobble
	plaza.position = STATION + Vector3(0, 0.03, 0)
	plaza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(plaza)
	var rim := MeshInstance3D.new()
	rim.name = "PlazaRim"
	var torus := TorusMesh.new()
	torus.inner_radius = 7.45
	torus.outer_radius = 7.85
	torus.rings = 64
	torus.ring_segments = 6
	rim.mesh = torus
	rim.material_override = _mat("rim", Color(0.95, 0.5, 0.12), 0.5, Color(1.0, 0.45, 0.1), 0.25)
	rim.position = STATION + Vector3(0, 0.04, 0)
	rim.scale = Vector3(1, 0.2, 1)
	dressing.add_child(rim)


## A flat cobbled strip (visual only, 2 cm proud of the turf).
func _path(path_name: String, centre: Vector3, size: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = path_name
	mi.mesh = _box_mesh(Vector3(size.x, 0.04, size.z), material)
	mi.position = centre + Vector3(0, 0.0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(mi)


# ---------------------------------------------------------------------------
# Boundary: wrought-iron fencing with gaps at the gates, player-only walls
# ---------------------------------------------------------------------------

## Gaps in the fence: [axis ("x" fixed or "z" fixed), fixed coordinate,
## centre along the run, half width].
func _gaps() -> Array:
	return [
		["x", ARENA.position.x, -3.0, 1.9],      # hall of mirrors back door (W)
		["x", ARENA.position.x, 17.0, 1.9],      # hayride gate (SW)
		["x", ARENA.end.x, -12.0, 1.9],          # staff gate (E)
		["z", GATE_Z, 0.0, 3.9],                 # the front gate (S)
	]


func _build_boundary() -> void:
	var b := Node3D.new()
	b.name = "Boundary"
	geo.add_child(b)
	var walls := _player_walls()
	var x0 := ARENA.position.x
	var x1 := ARENA.end.x
	var z0 := ARENA.position.y
	var z1 := ARENA.end.y
	var runs := [
		["West", Vector3(x0, 0, z0), Vector3(x0, 0, z1), "x", x0],
		["East", Vector3(x1, 0, z0), Vector3(x1, 0, z1), "x", x1],
		["South", Vector3(x0, 0, z1), Vector3(x1, 0, z1), "z", z1],
		["NorthW", Vector3(x0, 0, z0), Vector3(-15.6, 0, z0), "z", z0],
		["NorthE", Vector3(15.6, 0, z0), Vector3(x1, 0, z0), "z", z0],
	]
	for run in runs:
		var a: Vector3 = run[1]
		var c: Vector3 = run[2]
		var spans := [[a, c]]
		for g in _gaps():
			if g[0] != run[3] or absf(float(g[1]) - float(run[4])) > 0.1:
				continue
			var next := []
			for s in spans:
				next += _cut_span(s[0], s[1], float(g[2]), float(g[3]))
			spans = next
		var k := 0
		for s in spans:
			_fence_run(b, "%sFence%d" % [run[0], k], s[0], s[1])
			_player_wall(walls, "%sWall%d" % [run[0], k], s[0], s[1], PLAYER_WALL_H)
			k += 1
	# Player-only walls across every gap (zombies pass, the player does not).
	for g in _gaps():
		var c: float = g[2]
		var h: float = g[3]
		var fixed: float = g[1]
		if g[0] == "x":
			_player_wall(walls, "GapWall%d" % int(c), Vector3(fixed, 0, c - h), Vector3(fixed, 0, c + h), PLAYER_WALL_H)
		else:
			_player_wall(walls, "GapWall%d" % int(c), Vector3(c - h, 0, fixed), Vector3(c + h, 0, fixed), PLAYER_WALL_H)
	# Hedges just outside the fence line, broken at the gaps.
	for i in 26:
		var z := z0 + 1.0 + i * 2.0
		if absf(z - (-3.0)) > 3.0 and absf(z - 17.0) > 3.0:
			_row_add("Hedge", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x0 - 1.4, 0, z)))
		if absf(z - (-12.0)) > 3.0:
			_row_add("Hedge", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x1 + 1.4, 0, z)))
	for i in 31:
		var x := x0 + 1.0 + i * 2.0
		if absf(x) > 6.5:
			_row_add("Hedge", Transform3D(Basis(), Vector3(x, 0, z1 + 1.4)))


## Cuts [centre - half, centre + half] (measured along the run) out of a-b.
func _cut_span(a: Vector3, b: Vector3, centre: float, half: float) -> Array:
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var lo := minf(a.x, b.x) if along_x else minf(a.z, b.z)
	var hi := maxf(a.x, b.x) if along_x else maxf(a.z, b.z)
	if centre + half <= lo or centre - half >= hi:
		return [[a, b]]
	var out := []
	var p := func(t: float) -> Vector3: return Vector3(t, 0, a.z) if along_x else Vector3(a.x, 0, t)
	if centre - half - lo > 0.5:
		out.append([p.call(lo), p.call(centre - half)])
	if hi - (centre + half) > 0.5:
		out.append([p.call(centre + half), p.call(hi)])
	return out


# ---------------------------------------------------------------------------
# The Ghost Train: façade, skull, mouth tunnel, boarding platforms
# ---------------------------------------------------------------------------

func _build_ghost_train() -> void:
	var gt := Node3D.new()
	gt.name = "GhostTrainRide"
	geo.add_child(gt)
	_landmark(gt, "SkullRide", Vector3(0, 0, FACADE_Z), 0.0)
	# Colliders: the wings, the towers, the jaws, the tunnel and the skull mass.
	for s: float in [-1.0, 1.0]:
		_collider(gt, "Wing%d" % int(s), Vector3(10.9, 7.4, 6.2), Vector3(s * 9.55, 3.7, FACADE_Z - 3.0))
		_collider(gt, "Tower%d" % int(s), Vector3(3.2, 10.0, 3.2), Vector3(s * 14.0, 5.0, FACADE_Z - 2.0))
		_collider(gt, "Jaw%d" % int(s), Vector3(1.5, 4.0, 3.4), Vector3(s * (MOUTH_HALF + 0.75), 2.0, FACADE_Z + 0.7))
		_collider(gt, "Tunnel%d" % int(s), Vector3(0.4, 4.0, 7.2), Vector3(s * (MOUTH_HALF + 0.2), 2.0, FACADE_Z - 1.3))
		_collider(gt, "Cheek%d" % int(s), Vector3(1.8, 8.0, 3.0), Vector3(s * 4.1, 7.6, FACADE_Z + 0.5))
	_collider(gt, "TunnelBack", Vector3(MOUTH_HALF * 2 + 0.8, 4.0, 0.4), Vector3(0, 2.0, FACADE_Z - 4.85))
	_collider(gt, "Skull", Vector3(7.0, 9.0, 6.0), Vector3(0, 3.6 + 4.5, FACADE_Z - 0.3))
	var walls := _player_walls()
	_player_wall(walls, "MouthGate", Vector3(-MOUTH_HALF, 0, FACADE_Z + 2.2), Vector3(MOUTH_HALF, 0, FACADE_Z + 2.2), PLAYER_WALL_H)
	_player_block(gt, "SkullCap", Vector3(31.0, 6.0, 8.0), Vector3(0, 10.5, FACADE_Z - 3.0))
	_omni(gt, "MouthGlow", Vector3(0, 2.2, FACADE_Z - 1.0), Color(0.45, 1.0, 0.4), 2.2, 9.0)
	_omni(gt, "EyeGlow", Vector3(0, 7.0, FACADE_Z + 1.0), Color(0.45, 1.0, 0.4), 1.4, 10.0)
	# Boarding platforms either side of the skull, stairs down at the front.
	var boards := _textured("boards", "fright_boards", 0.35, 0.85)
	var fascia := _mat("fascia", Color(0.14, 0.09, 0.2), 0.8)
	for s: float in [-1.0, 1.0]:
		var xa := s * PLATFORM_X.x
		var xb := s * PLATFORM_X.y
		var cx := (xa + xb) * 0.5
		var w := absf(xb - xa)
		var d := PLATFORM_Z.y - PLATFORM_Z.x
		var cz := (PLATFORM_Z.x + PLATFORM_Z.y) * 0.5
		var body := _collider(gt, "Platform%d" % int(s), Vector3(w, PLATFORM_Y, d), Vector3(cx, PLATFORM_Y * 0.5, cz))
		var side := MeshInstance3D.new()
		side.name = "Fascia"
		side.mesh = _box_mesh(Vector3(w, PLATFORM_Y - 0.1, d), fascia)
		side.position.y = -0.05
		body.add_child(side)
		_visual_box(dressing, "PlatformTop%d" % int(s), Vector3(w + 0.2, 0.2, d + 0.2), Vector3(cx, PLATFORM_Y - 0.1, cz), boards)
		_visual_box(dressing, "PlatformTrim%d" % int(s), Vector3(w + 0.3, 0.16, d + 0.3), Vector3(cx, PLATFORM_Y - 0.32, cz),
			_mat("orange", Color(0.95, 0.5, 0.12), 0.5))
		# Crates fill the nook under the skull's cheek.
		_box(gt, "CheekCrates%d" % int(s), Vector3(1.3, 1.8, 1.9), Vector3(s * 4.6, PLATFORM_Y + 0.9, PLATFORM_Z.x + 0.95), boards)
		var sx := s * 10.4
		_stairs(gt, "Stair%d" % int(s), Vector3(sx, PLATFORM_Y, PLATFORM_Z.y), Vector3(sx, 0.0, PLATFORM_Z.y + 4.8), 2.2)
		# Railings: the front (open at the stair head) and the inner end.
		var y := PLATFORM_Y
		_low_fence(gt, "RailFrontA%d" % int(s), Vector3(xa, y, PLATFORM_Z.y - 0.15), Vector3(sx - s * 1.2, y, PLATFORM_Z.y - 0.15))
		_low_fence(gt, "RailFrontB%d" % int(s), Vector3(sx + s * 1.2, y, PLATFORM_Z.y - 0.15), Vector3(xb, y, PLATFORM_Z.y - 0.15))
		_low_fence(gt, "RailEnd%d" % int(s), Vector3(xa + s * 0.15, y, PLATFORM_Z.x + 1.95), Vector3(xa + s * 0.15, y, PLATFORM_Z.y - 0.15))
		_low_fence(gt, "RailOuter%d" % int(s), Vector3(xb - s * 0.15, y, PLATFORM_Z.y - 0.15), Vector3(xb - s * 0.15, y, PLATFORM_Z.x))
		# Dressing up top: a bench, lamps, a pumpkin pile, and a lantern string.
		_kit_prop(gt, "Bench", "PlatformBench%d" % int(s), Vector3(cx - s * 1.2, y, PLATFORM_Z.x + 0.7), 180.0, Vector3(1.8, 0.9, 0.6))
		_kit_prop(gt, "PumpkinPile", "PlatformPumpkins%d" % int(s), Vector3(xb - s * 1.1, y, PLATFORM_Z.x + 1.0), s * 90.0, Vector3(1.5, 0.8, 0.8))
		_lamp(gt, "PlatformLampA%d" % int(s), Vector3(xa + s * 0.6, y, PLATFORM_Z.y - 0.6))
		_lamp(gt, "PlatformLampB%d" % int(s), Vector3(xb - s * 0.6, y, PLATFORM_Z.y - 0.6))
		_lantern_string(Vector3(xa + s * 0.6, y + 3.7, PLATFORM_Z.y - 0.6), Vector3(xb - s * 0.6, y + 3.7, PLATFORM_Z.y - 0.6), 0.5)
		_omni(gt, "PlatformGlow%d" % int(s), Vector3(cx, y + 2.8, cz + 1.5), Color(1.0, 0.62, 0.3), 0.9, 8.0)


# ---------------------------------------------------------------------------
# The ride track: a loop in the plaza and the spur into the mouth
# ---------------------------------------------------------------------------

func _build_track() -> void:
	var pts := PackedVector3Array()
	var n := 16
	for k in n:
		var a := TAU * k / n
		pts.append(TRACK_C + Vector3(sin(a), 0, -cos(a)) * TRACK_R)
	for k in n:
		_track_segment(pts[k], pts[(k + 1) % n])
	var top := TRACK_C + Vector3(0, 0, -TRACK_R)
	var mouth := Vector3(0, 0, FACADE_Z - 4.4)
	var steps := int(round((top.z - mouth.z) / 2.0))
	for k in steps:
		_track_segment(mouth.lerp(top, float(k) / steps), mouth.lerp(top, float(k + 1) / steps))
	# Parked cars: cover on the loop, one waiting at the mouth.
	var cars := Node3D.new()
	cars.name = "GhostCars"
	geo.add_child(cars)
	for entry in [[TAU * 0.25, "CarEast"], [TAU * 0.62, "CarSouthWest"], [TAU * 0.85, "CarWest"]]:
		var a: float = entry[0]
		var p := TRACK_C + Vector3(sin(a), 0, -cos(a)) * TRACK_R
		_kit_prop(cars, "GhostCar", entry[1], p, 90.0 - rad_to_deg(a), Vector3(1.3, 1.4, 2.4))
	# The loop's centre: a raised bed of pumpkins and a tombstone sign.
	_kit_prop(cars, "PumpkinPile", "LoopPumpkins", TRACK_C + Vector3(0, 0, 0.6), 15.0, Vector3(1.5, 0.8, 0.8))
	_kit_prop(cars, "GooBarrel", "LoopBarrel", TRACK_C + Vector3(-1.6, 0, -1.2), 0.0, Vector3(0.9, 0.95, 0.9))


func _track_segment(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var yaw := atan2(-d.z, d.x)
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(d.length() / 2.0, 1, 1))
	_row_add("Track", Transform3D(basis, (a + b) * 0.5 + Vector3(0, 0.02, 0)))


# ---------------------------------------------------------------------------
# Loadout station: Creeps & Treats
# ---------------------------------------------------------------------------

func _build_station() -> void:
	var station: Node3D = (load("res://scenes/props/fright_station.tscn") as PackedScene).instantiate()
	station.name = "Station"
	geo.add_child(station)
	station.position = STATION
	station.rotation.y = deg_to_rad(4.0)


# ---------------------------------------------------------------------------
# Plaza dressing: booths, carts, coffins, barrels, lamps and lantern strings
# ---------------------------------------------------------------------------

func _build_plaza_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	geo.add_child(props)
	_kit_prop(props, "Booth", "BoothNW", Vector3(-10.5, 0, -7.5), 135.0, Vector3(3.2, 2.6, 2.0))
	_kit_prop(props, "Booth", "BoothSW", Vector3(-11.0, 0, 9.5), 60.0, Vector3(3.2, 2.6, 2.0))
	_kit_prop(props, "Booth", "BoothNE", Vector3(10.0, 0, -9.5), 215.0, Vector3(3.2, 2.6, 2.0))
	_kit_prop(props, "AppleCart", "CartE", Vector3(7.5, 0, 6.5), 290.0, Vector3(1.6, 1.2, 0.9))
	_kit_prop(props, "AppleCart", "CartW", Vector3(-6.0, 0, -5.0), 40.0, Vector3(1.6, 1.2, 0.9))
	_kit_prop(props, "Coffins", "CoffinsE", Vector3(11.5, 0, -5.0), 250.0, Vector3(1.8, 2.0, 1.0))
	_kit_prop(props, "Coffins", "CoffinsS", Vector3(-4.0, 0, 11.5), 10.0, Vector3(1.8, 2.0, 1.0))
	_kit_prop(props, "Coffins", "CoffinsW", Vector3(-14.5, 0, 2.5), 100.0, Vector3(1.8, 2.0, 1.0))
	_kit_prop(props, "PumpkinPile", "PumpkinsS", Vector3(5.0, 0, 13.0), 340.0, Vector3(1.5, 0.8, 0.8))
	_kit_prop(props, "PumpkinPile", "PumpkinsW", Vector3(-11.5, 0, 5.5), 80.0, Vector3(1.5, 0.8, 0.8))
	_kit_prop(props, "PumpkinPile", "PumpkinsN", Vector3(6.5, 0, -6.5), 20.0, Vector3(1.5, 0.8, 0.8))
	for entry in [["BarrelA", Vector3(6.5, 0, -9.0)], ["BarrelB", Vector3(-7.0, 0, -9.5)], ["BarrelC", Vector3(11.5, 0, 3.0)], ["BarrelD", Vector3(-12.0, 0, -2.0)],
			["BarrelE", Vector3(-6.5, 0, 15.5)]]:
		_kit_prop(props, "GooBarrel", entry[0], entry[1], 0.0, Vector3(0.9, 0.95, 0.9))
	for entry in [["BenchA", Vector3(-4.5, 0, 7.8), 20.0], ["BenchB", Vector3(4.6, 0, 8.0), -20.0], ["BenchC", Vector3(-15.5, 0, -12.0), 90.0],
			["BenchD", Vector3(14.5, 0, 9.0), 270.0]]:
		_kit_prop(props, "Bench", entry[0], entry[1], entry[2], Vector3(1.8, 0.9, 0.6))
	# Single jack-o'-lanterns along the paths (dressing).
	for entry in [[Vector3(-2.9, 0, 21.5), 0.0], [Vector3(2.9, 0, 21.0), 0.0], [Vector3(-7.5, 0, 1.8), 90.0], [Vector3(7.8, 0, 1.9), -90.0],
			[Vector3(-2.8, 0, -6.6), 180.0], [Vector3(16.0, 0, 12.0), -60.0], [Vector3(-17.0, 0, 6.5), 120.0]]:
		_row_add("Pumpkin", Transform3D(Basis(Vector3.UP, deg_to_rad(entry[1])), entry[0]))
	# Lamps round the plaza ring with lantern strings between them and to the station.
	var lamps: Array[Vector3] = []
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		lamps.append(STATION + Vector3(sin(a), 0, cos(a)) * 9.2)
	for i in lamps.size():
		_lamp(props, "PlazaLamp%d" % i, lamps[i])
	for i in lamps.size():
		_lantern_string(lamps[i] + Vector3.UP * 3.7, lamps[(i + 1) % lamps.size()] + Vector3.UP * 3.7, 0.7)
	for i in [1, 3, 5, 7]:
		_lantern_string(lamps[i] + Vector3.UP * 3.7, STATION + Vector3(0, 5.9, 0), 0.8)
	_build_pumpkin_patch(props)
	for entry in [Vector3(-16.0, 0, -15.0), Vector3(16.0, 0, -15.0), Vector3(-17.0, 0, 13.0), Vector3(-26.0, 0, 12.0), Vector3(27.0, 0, -18.0),
			Vector3(26.0, 0, 6.0), Vector3(-4.2, 0, 24.5), Vector3(4.2, 0, 24.5)]:
		_lamp(props, "Lamp%d_%d" % [int(entry.x), int(entry.z)], entry)


## The pumpkin patch (south-west): two raised beds of pumpkins, booths facing
## the path, and odds and ends in the corners of the fair.
func _build_pumpkin_patch(props: Node3D) -> void:
	var soil := _mat("soil", Color(0.24, 0.15, 0.14), 0.95)
	var kerb := _textured("boards", "fright_boards", 0.35, 0.85)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	for bed: Vector3 in [Vector3(-21.0, 0, 15.5), Vector3(-21.0, 0, 21.0)]:
		var body := _box(props, "Bed%d" % int(bed.z), Vector3(8.0, 0.5, 2.4), bed + Vector3(0, 0.25, 0), kerb)
		_visual_box(body, "Soil", Vector3(7.7, 0.04, 2.1), Vector3(0, 0.26, 0), soil)
		for k in 9:
			var p := bed + Vector3(-3.4 + k * 0.85 + rng.randf_range(-0.12, 0.12), 0.5, rng.randf_range(-0.45, 0.45))
			var s := rng.randf_range(0.55, 0.95)
			_row_add("Pumpkin", Transform3D(Basis(Vector3.UP, rng.randf_range(-0.6, 0.6)) * Basis.from_scale(Vector3.ONE * s), p))
	_kit_prop(props, "Booth", "BoothWest", Vector3(-26.5, 0, 9.0), 90.0, Vector3(3.2, 2.6, 2.0))
	_kit_prop(props, "Booth", "BoothSouth", Vector3(-12.0, 0, 23.5), 70.0, Vector3(3.2, 2.6, 2.0))
	_kit_prop(props, "Coffins", "CoffinsCorner", Vector3(-28.0, 0, 25.0), 120.0, Vector3(1.8, 2.0, 1.0))
	_kit_prop(props, "GooBarrel", "BarrelPatch", Vector3(-15.5, 0, 18.3), 0.0, Vector3(0.9, 0.95, 0.9))
	_kit_prop(props, "PumpkinPile", "PumpkinsPatch", Vector3(-27.5, 0, 18.5), 90.0, Vector3(1.5, 0.8, 0.8))
	_kit_prop(props, "Bench", "BenchPatch", Vector3(-15.0, 0, 12.0), 200.0, Vector3(1.8, 0.9, 0.6))
	_kit_prop(props, "AppleCart", "CartPatch", Vector3(-19.5, 0, 25.0), 10.0, Vector3(1.6, 1.2, 0.9))
	_kit_prop(props, "Booth", "BoothPatchN", Vector3(-21.0, 0, 9.6), 180.0, Vector3(3.2, 2.6, 2.0))
	_lantern_string(Vector3(-17.0, 3.7, 13.0), Vector3(-26.0, 3.7, 12.0), 0.6)
	_lantern_string(Vector3(-26.0, 3.7, 12.0), Vector3(-28.5, 3.7, 23.0), 0.7)
	_lamp(props, "LampPatchS", Vector3(-28.5, 0, 23.0))
	_kit_prop(props, "Booth", "BoothNE2", Vector3(20.5, 0, -16.0), 0.0, Vector3(3.2, 2.6, 2.0))
	_kit_prop(props, "Booth", "BoothNW2", Vector3(-21.0, 0, -20.6), 0.0, Vector3(3.2, 2.6, 2.0))
	_kit_prop(props, "AppleCart", "CartNW", Vector3(-17.0, 0, -18.0), 300.0, Vector3(1.6, 1.2, 0.9))
	_lantern_string(Vector3(-16.0, 3.7, -15.0), Vector3(-29.0, 3.7, -15.0), 0.6)
	_lamp(props, "LampNW2", Vector3(-29.0, 0, -15.0))
	# The far corners by the façade.
	_kit_prop(props, "PumpkinPile", "PumpkinsNW", Vector3(-25.5, 0, -15.5), 30.0, Vector3(1.5, 0.8, 0.8))
	_kit_prop(props, "GooBarrel", "BarrelNW", Vector3(-28.8, 0, -21.5), 0.0, Vector3(0.9, 0.95, 0.9))
	_kit_prop(props, "Coffins", "CoffinsNE2", Vector3(22.0, 0, -20.5), 200.0, Vector3(1.8, 2.0, 1.0))
	_kit_prop(props, "GooBarrel", "BarrelNE", Vector3(17.5, 0, -18.5), 0.0, Vector3(0.9, 0.95, 0.9))
	for entry in [[Vector3(-27.0, 0, -19.5), "TreeA", 0.8], [Vector3(28.0, 0, -21.5), "TreeB", 2.6], [Vector3(-16.0, 0, 15.0), "TreeA", 4.0]]:
		var p: Vector3 = entry[0]
		_row_add(entry[1], Transform3D(Basis(Vector3.UP, entry[2]) * Basis.from_scale(Vector3.ONE * 0.85), p))
		_post(props, "Trunk%d_%d" % [int(p.x), int(p.z)], 0.45, 4.0, p)


func _lamp(parent: Node3D, lamp_name: String, pos: Vector3) -> void:
	_row_add("Lamp", Transform3D(Basis(Vector3.UP, fposmod(pos.x * 0.7 + pos.z * 0.3, TAU)), pos))
	_post(parent, lamp_name + "Post", 0.16, 3.6, pos)
	_player_block(parent, lamp_name + "Cap", Vector3(1.4, 2.0, 1.4), pos + Vector3(0, 4.6, 0))


## A string of paper lanterns from a to b, sagging (MultiMesh rows plus one
## shared ribbon mesh for the cord).
func _lantern_string(a: Vector3, b: Vector3, sag: float) -> void:
	var length := a.distance_to(b)
	var count := maxi(2, int(length / 1.3))
	var flat := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var normal := flat.cross(Vector3.UP).normalized()
	for k in count:
		var t := (k + 0.5) / count
		var p := a.lerp(b, t) - Vector3.UP * sag * 4.0 * t * (1.0 - t)
		_row_add("LanternO" if (k + int(a.x)) % 2 == 0 else "LanternG", Transform3D(Basis(Vector3.UP, t * 3.0), p))
	var steps := 10
	for k in steps:
		var ta := float(k) / steps
		var tb := float(k + 1) / steps
		var pa := a.lerp(b, ta) - Vector3.UP * sag * 4.0 * ta * (1.0 - ta)
		var pb := a.lerp(b, tb) - Vector3.UP * sag * 4.0 * tb * (1.0 - tb)
		var up := Vector3.UP * 0.02
		for v in [pa + up, pb + up, pb - up, pa + up, pb - up, pa - up]:
			_lines.set_normal(normal)
			_lines.add_vertex(v)


func _finish_lines() -> void:
	var lines := MeshInstance3D.new()
	lines.name = "LanternCords"
	lines.mesh = _lines.commit()
	var cord := _mat("cord", Color(0.12, 0.09, 0.16), 0.9)
	cord.cull_mode = BaseMaterial3D.CULL_DISABLED
	lines.material_override = cord
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(lines)


# ---------------------------------------------------------------------------
# The hall of mirrors (west): crooked, enterable, three doors
# ---------------------------------------------------------------------------

func _build_mirror_hall() -> void:
	var hall := Node3D.new()
	hall.name = "MirrorHall"
	geo.add_child(hall)
	_landmark(hall, "MirrorHall", HALL, 0.0)
	# Walls (Blender x -5..5, y -7..7 -> Godot x, z flipped about the centre).
	var h := 5.0
	var t := 0.3
	var spans := [
		# [from, to] in hall-local (x, z) with z = -blender_y.
		[Vector2(-5, 7), Vector2(5, 7)],                  # south wall (blender y -7)
		[Vector2(-5, -7), Vector2(0.3, -7)],              # north wall west of the door
		[Vector2(2.7, -7), Vector2(5, -7)],               # north wall east of the door
		[Vector2(5, -7), Vector2(5, 1.8)],                # east wall north of the door
		[Vector2(5, 4.2), Vector2(5, 7)],                 # east wall south of the door
		[Vector2(-5, -7), Vector2(-5, -1.2)],             # west wall north of the door
		[Vector2(-5, 1.2), Vector2(-5, 7)],               # west wall south of the door
		[Vector2(-1.6, 0), Vector2(5, 0)],                # the partition
	]
	var k := 0
	for s in spans:
		var a := HALL + Vector3(s[0].x, 0, s[0].y)
		var b := HALL + Vector3(s[1].x, 0, s[1].y)
		var height := h if k < 7 else 3.4
		_wall_segment(hall, "HallWall%d" % k, a, b, height, t)
		k += 1
	_collider(hall, "HallRoof", Vector3(10.6, 0.4, 14.6), HALL + Vector3(0, h + 0.2, 0))
	_player_block(hall, "HallCap", Vector3(11.0, 6.0, 15.0), HALL + Vector3(0, h + 3.4, 0))
	_omni(hall, "HallGlowS", HALL + Vector3(0.5, 3.2, 3.5), Color(0.75, 0.45, 1.0), 1.4, 7.0)
	_omni(hall, "HallGlowN", HALL + Vector3(0.5, 3.2, -3.5), Color(0.45, 1.0, 0.6), 1.2, 7.0)
	# Outside: a ticket barrel and pumpkins at the east door.
	_kit_prop(hall, "GooBarrel", "HallBarrel", HALL + Vector3(6.2, 0, 5.6), 0.0, Vector3(0.9, 0.95, 0.9))
	_row_add("Pumpkin", Transform3D(Basis(Vector3.UP, -PI * 0.5), HALL + Vector3(5.8, 0, 1.2)))
	_row_add("Pumpkin", Transform3D(Basis(Vector3.UP, -PI * 0.5), HALL + Vector3(5.7, 0, 4.9)))


# ---------------------------------------------------------------------------
# The carousel (east): the base collides, the top turns
# ---------------------------------------------------------------------------

func _build_carousel() -> void:
	var props := Node3D.new()
	props.name = "CarouselRide"
	geo.add_child(props)
	_landmark(props, "Carousel", CAROUSEL, 0.0)
	var top := _landmark(dressing, "CarouselTop", CAROUSEL, 0.0)
	_late(top, "res://scripts/props/ambient_motion.gd", {"spin_degrees_per_second": -16.0})
	_post(props, "CarouselBase", 5.6, 0.45, CAROUSEL)
	_post(props, "CarouselRide", 5.2, 4.2, CAROUSEL + Vector3(0, 0.45, 0))
	_player_block(props, "CarouselCap", Vector3(12.4, 4.0, 12.4), CAROUSEL + Vector3(0, 6.6, 0))
	_omni(props, "CarouselGlow", CAROUSEL + Vector3(0, 3.6, 0), Color(1.0, 0.66, 0.32), 1.6, 10.0)
	_kit_prop(props, "AppleCart", "CarouselCart", CAROUSEL + Vector3(-1.5, 0, 8.4), 160.0, Vector3(1.6, 1.2, 0.9))
	_kit_prop(props, "Booth", "BoothE", CAROUSEL + Vector3(8.6, 0, 7.0), 270.0, Vector3(3.2, 2.6, 2.0))
	_kit_prop(props, "Coffins", "CoffinsNE", CAROUSEL + Vector3(7.5, 0, -8.0), 300.0, Vector3(1.8, 2.0, 1.0))


# ---------------------------------------------------------------------------
# The graveyard maze (south-east) and its crypt
# ---------------------------------------------------------------------------

func _build_graveyard() -> void:
	var g := Node3D.new()
	g.name = "Graveyard"
	geo.add_child(g)
	# Low iron fence round the yard, open to the plaza (west and north gaps).
	_low_fence(g, "YardFenceN1", Vector3(13.0, 0, 9.0), Vector3(20.0, 0, 9.0))
	_low_fence(g, "YardFenceN2", Vector3(24.0, 0, 9.0), Vector3(30.5, 0, 9.0))
	_low_fence(g, "YardFenceW1", Vector3(9.0, 0, 15.0), Vector3(9.0, 0, 20.0))
	_low_fence(g, "YardFenceW2", Vector3(9.0, 0, 23.5), Vector3(9.0, 0, 27.0))
	# Hedge walls: two lanes winding to the crypt.
	var hedges := [
		[Vector3(13.0, 0, 12.5), 0.0], [Vector3(15.0, 0, 12.5), 0.0], [Vector3(17.0, 0, 12.5), 0.0],
		[Vector3(22.0, 0, 12.5), 0.0], [Vector3(24.0, 0, 12.5), 0.0],
		[Vector3(13.0, 0, 20.0), 90.0], [Vector3(13.0, 0, 22.0), 90.0],
		[Vector3(18.5, 0, 17.5), 0.0], [Vector3(20.5, 0, 17.5), 0.0], [Vector3(22.5, 0, 17.5), 0.0],
		[Vector3(27.5, 0, 15.0), 90.0], [Vector3(17.5, 0, 22.5), 90.0],
	]
	var i := 0
	for entry in hedges:
		var p: Vector3 = entry[0]
		_row_add("Hedge", Transform3D(Basis(Vector3.UP, deg_to_rad(entry[1])), p))
		var c := _collider(g, "Hedge%d" % i, Vector3(2.0, 1.6, 0.9), p + Vector3(0, 0.8, 0))
		c.rotation.y = deg_to_rad(entry[1])
		_player_block(g, "HedgeCap%d" % i, Vector3(2.0, 2.0, 0.9), p + Vector3(0, 2.6, 0), deg_to_rad(entry[1]))
		i += 1
	# Gravestones: rows between the hedges (snag-free clutter).
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var graves := ["GraveA", "GraveB", "GraveC"]
	var spots := [Vector3(11.0, 0, 15.0), Vector3(11.2, 0, 18.5), Vector3(11.0, 0, 22.5), Vector3(15.5, 0, 15.2), Vector3(16.0, 0, 20.0),
		Vector3(20.0, 0, 15.0), Vector3(23.5, 0, 15.2), Vector3(25.5, 0, 11.0), Vector3(29.0, 0, 11.5), Vector3(29.0, 0, 19.5),
		Vector3(20.5, 0, 20.5), Vector3(15.5, 0, 25.0), Vector3(19.5, 0, 25.5), Vector3(28.8, 0, 24.5), Vector3(11.0, 0, 26.0),
		Vector3(18.0, 0, 10.6), Vector3(29.5, 0, 22.0)]
	for k in spots.size():
		var p: Vector3 = spots[k]
		var yaw := rng.randf_range(-0.25, 0.25) + (PI if p.z > 20.0 else 0.0)
		_row_add(graves[k % 3], Transform3D(Basis(Vector3.UP, yaw), p))
		_clutter_block(g, "Grave%d" % k, Vector3(0.8, 1.2, 0.5), p, yaw)
	# Dead trees in the yard.
	for entry in [[Vector3(26.5, 0, 13.5), "TreeA", 0.4], [Vector3(14.5, 0, 24.5), "TreeB", 2.1]]:
		var p: Vector3 = entry[0]
		_row_add(entry[1], Transform3D(Basis(Vector3.UP, entry[2]), p))
		_post(g, "TreeTrunk%d" % int(p.x), 0.5, 4.0, p)
	# The crypt: entrance E2, its door facing north into the yard.
	_landmark(g, "Crypt", CRYPT, 180.0)
	_collider(g, "CryptBack", Vector3(4.4, 4.2, 0.4), CRYPT + Vector3(0, 2.1, 2.0))
	_collider(g, "CryptSideW", Vector3(0.4, 4.2, 4.4), CRYPT + Vector3(-2.0, 2.1, 0))
	_collider(g, "CryptSideE", Vector3(0.4, 4.2, 4.4), CRYPT + Vector3(2.0, 2.1, 0))
	_collider(g, "CryptRoof", Vector3(5.0, 0.6, 5.0), CRYPT + Vector3(0, 4.3, 0))
	for s: float in [-1.0, 1.0]:
		_post(g, "CryptColumn%d" % int(s), 0.24, 3.8, CRYPT + Vector3(s * 1.45, 0.28, -2.4))
	_player_wall(_player_walls(), "CryptGate", CRYPT + Vector3(-1.9, 0.28, -2.6), CRYPT + Vector3(1.9, 0.28, -2.6), PLAYER_WALL_H)
	_omni(g, "CryptGlow", CRYPT + Vector3(0, 2.0, -3.0), Color(0.45, 1.0, 0.45), 1.6, 8.0)
	_omni(g, "YardGlow", Vector3(19.0, 2.5, 17.0), Color(0.5, 0.9, 0.7), 0.9, 11.0)
	# Mist over the graves.
	var mist := ShaderMaterial.new()
	mist.shader = load(SHADERS + "fright_mist.gdshader")
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(11.0, 9.0)
	for k in 8:
		var mi := MeshInstance3D.new()
		mi.name = "Mist%d" % k
		mi.mesh = sheet
		mi.material_override = mist
		mi.position = Vector3(14.5 + (k % 2) * 10.0, 0.3 + (k / 4) * 0.45 + (k % 3) * 0.08, 13.5 + ((k / 2) % 2) * 9.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dressing.add_child(mi)


# ---------------------------------------------------------------------------
# Gates: the front gate (portal), the staff gate, the hayride gate, the hall's
# back door; the spawn pads beyond the fence
# ---------------------------------------------------------------------------

func _build_gates() -> void:
	var gates := Node3D.new()
	gates.name = "Gates"
	geo.add_child(gates)
	_landmark(gates, "FairGate", Vector3(0, 0, GATE_Z), 180.0)
	for s: float in [-1.0, 1.0]:
		_collider(gates, "GateTower%d" % int(s), Vector3(1.4, 7.4, 1.4), Vector3(s * 4.6, 3.7, GATE_Z))
	# Side gates: brick piers, an iron arch and a crooked sign.
	_side_gate(gates, "HallBackGate", Vector3(ARENA.position.x, 0, -3.0), 90.0, "STAFF ONLY")
	_side_gate(gates, "HayrideGate", Vector3(ARENA.position.x, 0, 17.0), 90.0, "HAYRIDE")
	_side_gate(gates, "StaffGate", Vector3(ARENA.end.x, 0, -12.0), -90.0, "NO ENTRY")
	# Beyond the gates: a hay wagon of pumpkins, crates, a lamp.
	_kit_prop(gates, "PumpkinPile", "HayrideHay", Vector3(-35.5, 0, 14.0), 90.0, Vector3(1.5, 0.8, 0.8))
	_kit_prop(gates, "Coffins", "StaffCoffins", Vector3(35.0, 0, -15.5), 270.0, Vector3(1.8, 2.0, 1.0))
	_row_add("Lamp", Transform3D(Basis(), Vector3(-35.0, 0, 20.0)))
	_row_add("Lamp", Transform3D(Basis(), Vector3(35.0, 0, -8.5)))


func _side_gate(parent: Node3D, gate_name: String, centre: Vector3, yaw_degrees: float, label: String) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_degrees))
	var brick := _mat("brick", Color(0.42, 0.23, 0.27), 0.9)
	var iron := _mat("iron", Color(0.16, 0.14, 0.22), 0.5)
	for s: float in [-1.0, 1.0]:
		var p := centre + basis * Vector3(s * 2.25, 0, 0)
		_box(parent, "%sPier%d" % [gate_name, int(s)], Vector3(0.6, 3.0, 0.6), p + Vector3(0, 1.5, 0), brick)
		_visual_box(dressing, "%sCap%d" % [gate_name, int(s)], Vector3(0.75, 0.16, 0.75), p + Vector3(0, 3.08, 0), _mat("stone", Color(0.56, 0.54, 0.64), 0.85))
	var bar := _visual_box(dressing, gate_name + "Bar", Vector3(4.5, 0.14, 0.14), centre + Vector3(0, 3.3, 0), iron)
	bar.basis = basis
	var sign := _visual_box(dressing, gate_name + "Board", Vector3(2.6, 0.6, 0.1), centre + Vector3(0, 3.75, 0), _mat("ink", Color(0.12, 0.08, 0.18), 0.8))
	sign.basis = basis * Basis(Vector3.BACK, 0.06)
	var text := Label3D.new()
	text.name = gate_name + "Text"
	text.text = label
	text.font = load("res://art/fonts/LilitaOne-Regular.ttf")
	text.font_size = 72
	text.pixel_size = 0.005
	text.modulate = Color(1.0, 0.6, 0.2)
	text.outline_size = 0
	text.shaded = false
	text.double_sided = false
	dressing.add_child(text)
	text.position = centre + Vector3(0, 3.75, 0) + basis * Vector3(0, 0, 0.07)
	text.basis = basis * Basis(Vector3.BACK, 0.06)


# ---------------------------------------------------------------------------
# Lights
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	var lights := Node3D.new()
	lights.name = "LanternLights"
	level.add_child(lights)
	_omni(lights, "StationGlow", STATION + Vector3(0, 3.6, 3.2), Color(1.0, 0.66, 0.36), 1.3, 10.0)
	_omni(lights, "BallGlow", STATION + Vector3(0, 8.0, 0), Color(0.5, 1.0, 0.5), 1.2, 9.0)
	_omni(lights, "GateGlow", Vector3(0, 6.0, GATE_Z - 2.0), Color(1.0, 0.6, 0.3), 1.0, 9.0)


func _omni(parent: Node3D, light_name: String, pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = light_name
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.3
	l.shadow_enabled = false
	l.add_to_group("fright_lamps", true)
	parent.add_child(l)
	_light_count += 1
	return l


# ---------------------------------------------------------------------------
# Backdrop: dead trees, hills, the manor on its hill, bats
# ---------------------------------------------------------------------------

func _build_backdrop() -> void:
	var back := Node3D.new()
	back.name = "Backdrop"
	dressing.add_child(back)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# A wood of dead trees all round, outside the fence.
	for k in 70:
		var a := TAU * k / 70.0 + rng.randf_range(-0.04, 0.04)
		var r := rng.randf_range(42.0, 62.0)
		var p := Vector3(cos(a) * r * 1.05, 0, sin(a) * r)
		var s := rng.randf_range(0.9, 1.6)
		_row_add("TreeA" if k % 3 else "TreeB", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
	for k in 18:
		var a := TAU * k / 18.0 + 0.1
		var r := rng.randf_range(34.0, 39.0)
		var p := Vector3(cos(a) * r * 1.1, 0, sin(a) * r)
		if absf(p.z) < 30.0 and absf(p.x) < 38.0:
			continue
		_row_add("TreeB" if k % 2 else "TreeA", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.3)), p))
	# Rolling hills on the horizon (dark violet mounds).
	var hill := _mat("hill", Color(0.11, 0.08, 0.17), 0.95)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	sphere.material = hill
	for k in 14:
		var a := TAU * k / 14.0 + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(120.0, 170.0)
		var mi := MeshInstance3D.new()
		mi.name = "Hill%d" % k
		mi.mesh = sphere
		mi.position = Vector3(cos(a) * r, -rng.randf_range(10.0, 18.0), sin(a) * r)
		mi.scale = Vector3(rng.randf_range(50.0, 80.0), rng.randf_range(24.0, 36.0), rng.randf_range(40.0, 60.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		back.add_child(mi)
	# The manor on its own hill to the north-west, the moon behind it.
	var manor_pos := Vector3(-48.0, 7.0, -96.0)
	var mound := MeshInstance3D.new()
	mound.name = "ManorHill"
	mound.mesh = sphere
	mound.position = manor_pos + Vector3(0, -14.0, 4.0)
	mound.scale = Vector3(46.0, 22.0, 34.0)
	mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	back.add_child(mound)
	var manor := _landmark(back, "Manor", manor_pos, 20.0)
	manor.scale = Vector3.ONE * 1.15
	_omni(back, "ManorGlow", manor_pos + Vector3(8.0, 6.0, 14.0), Color(1.0, 0.6, 0.3), 2.0, 22.0)
	for k in 9:
		var a := deg_to_rad(-30.0 + k * 7.0)
		var p := manor_pos + Vector3(sin(a) * 30.0, -1.0, cos(a) * 20.0 + 18.0)
		_row_add(["GraveA", "GraveB", "GraveC"][k % 3], Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * 2.2), p))
	# Bats circling the manor's tower and the skull.
	var flocks := 0
	for entry in [[manor_pos + Vector3(-13.0, 30.0, 0.0), 9.0, 7, 40.0], [Vector3(0, 17.0, FACADE_Z - 4.0), 7.0, 6, -55.0],
			[Vector3(20.0, 22.0, -40.0), 12.0, 5, 30.0]]:
		var flock := Node3D.new()
		flock.name = "Bats%d" % flocks
		flock.position = entry[0]
		back.add_child(flock)
		for b in int(entry[2]):
			var a := TAU * b / float(entry[2])
			var r: float = entry[1] * (0.8 + 0.4 * fposmod(b * 0.37, 1.0))
			var bat := _kit_mesh_instance("Bat", "Bat%d" % b)
			bat.position = Vector3(cos(a) * r, fposmod(b * 1.3, 3.0) - 1.5, sin(a) * r)
			bat.rotation.y = -a + (PI * 0.5 if entry[3] > 0.0 else -PI * 0.5)
			bat.scale = Vector3.ONE * 3.0
			flock.add_child(bat)
		_late(flock, "res://scripts/props/ambient_motion.gd", {"spin_degrees_per_second": entry[3], "bob_height": 1.2, "bob_seconds": 5.0})
		flocks += 1


# ---------------------------------------------------------------------------
# Exit: the portal in the front gate and the pumpkin lanterns to it
# ---------------------------------------------------------------------------

func _build_exit() -> void:
	var portal: Node3D = (load("res://scenes/props/fright_portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	geo.add_child(portal)
	portal.position = PORTAL
	portal.rotation.y = PI
	var lights := Node3D.new()
	lights.name = "ExitLights"
	level.add_child(lights)
	var a := STATION + Vector3(0.0, 0, 8.4)
	var b := PORTAL + Vector3(0, 0, -2.6)
	var steps := 5
	for k in steps:
		var t := float(k) / (steps - 1)
		for s: float in [-1.0, 1.0]:
			var pos := a.lerp(b, t) + Vector3(s * 2.9, 0, 0)
			var lantern := _kit_mesh_instance("ExitLantern", "ExitLantern%02d%s" % [k, "L" if s < 0 else "R"])
			lantern.position = pos
			lantern.rotation.y = PI + s * 0.5
			lights.add_child(lantern)
			_late(lantern, "res://scripts/props/fright_exit_lantern.gd", {"order": k})


# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(0.0, 0.1, 17.0)
	start.add_to_group("player_spawn", true)
	level.add_child(start)
	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	var points := {
		"SpawnSkullMouth": [Vector3(0.0, 0.1, FACADE_Z - 1.8), 0.0],
		"SpawnCrypt": [CRYPT + Vector3(0.0, 0.38, 0.2), 180.0],
		"SpawnHallBack": [Vector3(ARENA.position.x - 2.8, 0.1, -3.0), -90.0],
		"SpawnStaffGate": [Vector3(ARENA.end.x + 2.8, 0.1, -12.0), 90.0],
		"SpawnHayride": [Vector3(ARENA.position.x - 2.8, 0.1, 17.0), -90.0],
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
	mesh.filter_baking_aabb = AABB(Vector3(-37.5, -1.0, -30.0), Vector3(75.0, PLATFORM_Y + 2.2, 61.0))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	region.navigation_mesh = _largest_island(mesh)
	print("build_ghost_train: navmesh polygons = %d (dropped %d on islands)" % [region.navigation_mesh.get_polygon_count(),
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


## A thin upright wall collider from a to b.
func _wall_segment(parent: Node3D, wall_name: String, a: Vector3, b: Vector3, height: float, thick: float) -> void:
	var body := _collider(parent, wall_name, Vector3(a.distance_to(b) + thick, height, thick), (a + b) * 0.5 + Vector3(0, height * 0.5, 0))
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
	var steps := int(round(rise / 0.25))
	var tread := _textured("boards", "fright_boards", 0.35, 0.85)
	var riser := _mat("fascia", Color(0.14, 0.09, 0.2), 0.8)
	for k in steps:
		var h := rise - (k + 1) * rise / steps
		var mi := MeshInstance3D.new()
		mi.name = "Step%d" % k
		mi.mesh = _box_mesh(Vector3(length / steps + 0.02, rise / steps, width), tread)
		mi.position = Vector3(-length * 0.5 + length / steps * (k + 0.5), h + rise / steps * 0.5 - rise * 0.5, 0)
		body.add_child(mi)
		if h > 0.01:
			var fill := MeshInstance3D.new()
			fill.name = "Riser%d" % k
			fill.mesh = _box_mesh(Vector3(length / steps + 0.02, h, width - 0.02), riser)
			fill.position = Vector3(-length * 0.5 + length / steps * (k + 0.5), h * 0.5 - rise * 0.5, 0)
			body.add_child(fill)
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
		for zz in [-0.1, 0.1]:
			pts.append(Vector3(-length * 0.5, rise * 0.5 + 1.1, zz))
			pts.append(Vector3(-length * 0.5, -rise * 0.5, zz))
			pts.append(Vector3(length * 0.5, -rise * 0.5, zz))
			pts.append(Vector3(length * 0.5, -rise * 0.5 + 1.1, zz))
		convex.points = pts
		wedge.shape = convex
		side.add_child(wedge)
		var rail := _module_row("Rail", "FenceLow", sqrt(length * length + rise * rise), 2.0)
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


## A run of wrought-iron fence modules (one MultiMesh) with one tall collider.
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
	box.size = Vector3(length + 0.5, 2.4, 0.5)
	shape.shape = box
	shape.position.y = 1.2
	body.add_child(shape)
	body.add_child(_module_row("Modules", "Fence", length, 2.5))


## A run of low iron railing (1.1 m) with one collider.
func _low_fence(parent: Node3D, run_name: String, a: Vector3, b: Vector3) -> void:
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
	body.add_child(_module_row("Modules", "FenceLow", length, 2.0))


## Modules of a kit mesh laid end to end along local X (one MultiMesh).
func _module_row(row_name: String, kit_mesh: String, length: float, module_len: float) -> MultiMeshInstance3D:
	var count := maxi(1, int(round(length / module_len)))
	var step := length / count
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _kit_mesh(KIT, kit_mesh)
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(step / module_len, 1, 1)), Vector3(-length * 0.5 + step * (i + 0.5), 0, 0)))
	var modules := MultiMeshInstance3D.new()
	modules.name = row_name
	modules.multimesh = mm
	return modules


## Queues one instance of a kit mesh for its shared MultiMesh.
func _row_add(kit_mesh: String, xform: Transform3D) -> void:
	if not _rows.has(kit_mesh):
		_rows[kit_mesh] = []
	_rows[kit_mesh].append(xform)


func _finish_rows() -> void:
	var holder := Node3D.new()
	holder.name = "Repeats"
	dressing.add_child(holder)
	for kit_mesh in _rows:
		var xforms: Array = _rows[kit_mesh]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _kit_mesh(KIT, kit_mesh)
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = kit_mesh + "s"
		mmi.multimesh = mm
		if kit_mesh in ["Track", "LanternO", "LanternG", "Pumpkin"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mmi)


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


## Small clutter (gravestones): baked tall into the navmesh so zombies path
## round it, then made player-only so nothing snags on it.
func _clutter_block(parent: Node3D, block_name: String, size: Vector3, pos: Vector3, yaw: float) -> void:
	var body := _collider(parent, block_name, Vector3(size.x, 2.0, size.z), pos + Vector3(0, 1.0, 0))
	body.rotation.y = yaw
	body.set_meta(&"height", size.y)
	_clutter.append(body)


func _flatten_clutter() -> void:
	for body in _clutter:
		body.collision_layer = 16
		body.collision_mask = 0
		var h: float = body.get_meta(&"height")
		var shape := body.get_child(0) as CollisionShape3D
		var box := (shape.shape as BoxShape3D).duplicate() as BoxShape3D
		box.size.y = h
		shape.shape = box
		body.position.y = h * 0.5
		body.remove_meta(&"height")


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


## The named mesh from a kit .glb (cached).
func _kit_mesh(kit: String, mesh_name: String) -> Mesh:
	var key := kit + "/" + mesh_name
	if _kits.has(key):
		return _kits[key]
	var source: Node3D = (load(MODELS + kit + ".glb") as PackedScene).instantiate()
	for n in source.find_children("*", "MeshInstance3D", true, false):
		_kits[kit + "/" + String(n.name)] = (n as MeshInstance3D).mesh
	source.free()
	assert(_kits.has(key), "missing kit mesh " + key)
	return _kits[key]


func _kit_mesh_instance(mesh_name: String, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = _kit_mesh(KIT, mesh_name)
	return mi


## A kit prop with a matching box collider (footprint `size`, standing on `pos`).
func _kit_prop(parent: Node3D, mesh_name: String, prop_name: String, pos: Vector3, yaw_degrees: float, size: Vector3) -> MeshInstance3D:
	var mi := _kit_mesh_instance(mesh_name, prop_name)
	mi.position = pos
	mi.rotation.y = deg_to_rad(yaw_degrees)
	dressing.add_child(mi)
	var c := _collider(parent, prop_name + "Collision", size, pos + Vector3(0, size.y * 0.5, 0))
	c.rotation.y = deg_to_rad(yaw_degrees)
	return mi


## A landmark mesh (fright_landmarks.glb) placed as a visual.
func _landmark(_parent: Node3D, mesh_name: String, pos: Vector3, yaw_degrees: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = _kit_mesh(LANDMARKS, mesh_name)
	mi.position = pos
	mi.rotation.y = deg_to_rad(yaw_degrees)
	dressing.add_child(mi)
	return mi


func _own(node: Node) -> void:
	for child in node.get_children():
		child.owner = level
		if child.scene_file_path == "":
			_own(child)
