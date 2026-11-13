extends SceneTree
## Generator for World 8 "Sugar Rush Factory" / level "Candy Works".
##
## Rebuilds scenes/levels/candy_works.tscn: a cathedral-sized candy factory hall
## under a sawtooth roof of skylights, the chocolate river and its three striped
## bridges, the colossal gumball machine and its silos, the taffy puller on its
## platform, mixing vats, the packing mezzanine, the packaging line, the
## gingerbread office, the Sweet Shop loadout station, six zombie entrances,
## moving machinery, lights and a baked navigation mesh.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_candy_works.gd
##
## Run it with a renderer (not --headless): the headless renderer keeps no
## MultiMesh instance data, so rails, trusses and sweets would save empty.
##
## NOTE: running this overwrites hand edits made to candy_works.tscn.
##
## Layout (metres, top view; -Z = north):
##   - The hall: X -32..32, Z -36..30, walls to 20.5 m, roof bays of glass.
##   - The chocolate river crosses the hall at Z -15..-9 (west to east), with
##     bridges at X -19 (3.6 m), 0 (6 m) and 19 (3.6 m).
##   - North yard: the gumball machine (0, -28), four silos on the north wall,
##     the exit portal (0, -19) in front of the machine.
##   - South floor: the Sweet Shop station (0, 3); the taffy puller on a 1.2 m
##     platform (west); mixing vats on the river bank; the packing mezzanine
##     (3 m, east) with a ramp and stairs; the packaging line along Z 23.5; the
##     gingerbread office in the south-west corner.
##   - Zombie entrances: Cocoa Store (west wall, north), Silo Service (east wall,
##     north), Sugar Room (west wall, south), Delivery Bay (east wall, south),
##     Loading Dock (south wall) and the Foreman's door on the mezzanine.

const OUT_PATH := "res://scenes/levels/candy_works.tscn"
const MODELS := "res://art/models/"
const TEXTURES := "res://art/textures/"
const SHADERS := "res://art/shaders/"

const HALL_X := 32.0
const HALL_Z0 := -36.0
const HALL_Z1 := 30.0
const WALL_TOP := 20.5
const WALL_BASE := -1.6
const WALL_THICK := 1.0
const ROOF_LOW := 16.0
const ROOF_HIGH := 20.0
const RIVER_Z0 := -15.0
const RIVER_Z1 := -9.0
const RIVER_BED := -1.5
const RIVER_SURFACE := -0.38
const STATION := Vector3(0.0, 0.0, 3.0)
const GUMBALL := Vector3(0.0, 0.0, -28.0)
const PORTAL := Vector3(0.0, 0.0, -19.5)
const BRIDGES := [[-19.0, 3.6, "candy_bridge"], [0.0, 6.0, "candy_bridge_wide"], [19.0, 3.6, "candy_bridge"]]
const MEZZ_Y := 3.0
const MEZZ := Rect2(19.0, -4.0, 13.0, 18.0)      # x, z, width, depth
const TAFFY_Y := 1.2
const TAFFY := Rect2(-27.0, 1.0, 10.0, 10.0)
const BELT_Z := 23.5
const SUN_DIRECTION := Vector3(0.45, 0.62, 0.64)    # toward the sun (south-east, high)
## Door openings: [name, wall ("W", "E", "S"), centre along the wall, sill height].
const DOORS := [
	["CocoaStore", "W", -25.0, 0.0], ["SiloService", "E", -25.0, 0.0], ["SugarRoom", "W", 14.5, 0.0],
	["DeliveryBay", "E", 20.5, 0.0], ["LoadingDock", "S", 12.0, 0.0], ["ForemanDoor", "E", 5.0, MEZZ_Y],
]
const DOOR_W := 4.4
const DOOR_H := 4.2
const RECESS := 6.5

var level: Node3D
var geo: Node3D          # collidable geometry (navmesh source)
var dressing: Node3D     # non-colliding scenery
var _materials := {}
var _boxes := {}
var _mesh_cache := {}
var _late_scripts: Array = []     # [node, script path, {property: value}] attached after the bake
var _light_count := 0


func _initialize() -> void:
	level = Node3D.new()
	level.name = "CandyWorks"
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

	_build_floor()
	_build_river()
	_build_walls()
	_build_entrances()
	_build_roof()
	_build_north_yard()
	_build_station()
	_build_taffy_platform()
	_build_vats()
	_build_mezzanine()
	_build_packing_line()
	_build_office()
	_build_floor_props()
	_build_pipes()
	_build_lights()
	_build_exit()
	_build_markers()
	_build_sugar_rush()

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
	print("build_candy_works: saved %s (error %d), %d omni lights" % [OUT_PATH, err, _light_count])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: late-morning sun through the skylights, pastel haze
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load(TEXTURES + "candy_sky.png")
	pano.energy_multiplier = 1.15
	sky.sky_material = pano
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.92, 0.78, 0.95)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.6
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.86, 0.93)
	env.fog_density = 0.0028
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.1
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.looking_at(-SUN_DIRECTION.normalized(), Vector3.UP), Vector3(0, 40, 0))
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.1
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.shadow_opacity = 0.82
	level.add_child(sun)

	# Skylight bounce: a soft cool fill from above the north, no shadows.
	var fill := DirectionalLight3D.new()
	fill.name = "SkylightFill"
	fill.transform = Transform3D(Basis.looking_at(Vector3(-0.2, -0.8, 0.55).normalized(), Vector3.UP), Vector3(0, 40, 0))
	fill.light_color = Color(0.75, 0.88, 1.0)
	fill.light_energy = 0.3
	fill.shadow_enabled = false
	level.add_child(fill)


# ---------------------------------------------------------------------------
# Floor: collision slabs either side of the river, tiled floor, walkway paint
# ---------------------------------------------------------------------------

func _build_floor() -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	geo.add_child(ground)
	var north_d := RIVER_Z0 - HALL_Z0
	var south_d := HALL_Z1 - RIVER_Z1
	_collider(ground, "SlabNorth", Vector3(HALL_X * 2.0, 2.0, north_d), Vector3(0, -1.0, HALL_Z0 + north_d * 0.5))
	_collider(ground, "SlabSouth", Vector3(HALL_X * 2.0, 2.0, south_d), Vector3(0, -1.0, RIVER_Z1 + south_d * 0.5))
	var floor_mat := _textured("floor", "candy_floor", 0.25, 0.55)
	_visual_box(dressing, "FloorNorth", Vector3(HALL_X * 2.0, 0.1, north_d), Vector3(0, -0.05, HALL_Z0 + north_d * 0.5), floor_mat)
	_visual_box(dressing, "FloorSouth", Vector3(HALL_X * 2.0, 0.1, south_d), Vector3(0, -0.05, RIVER_Z1 + south_d * 0.5), floor_mat)
	# Painted walkways: butter-yellow lanes between the areas.
	var paint := Node3D.new()
	paint.name = "Walkways"
	dressing.add_child(paint)
	var lane := _mat("lane", Color(1.0, 0.86, 0.45), 0.6)
	var lanes := [
		[Vector3(0, 0, 21), Vector3(0, 0, 10.8)], [Vector3(0, 0, -4.8), Vector3(0, 0, -8.4)],
		[Vector3(-12, 0, 16.5), Vector3(14, 0, 16.5)], [Vector3(-19, 0, -8.4), Vector3(-19, 0, -1.0)],
		[Vector3(19, 0, -8.4), Vector3(19, 0, -5.0)],
		[Vector3(-19, 0, -16.6), Vector3(-19, 0, -30)], [Vector3(19, 0, -16.6), Vector3(19, 0, -30)],
	]
	var i := 0
	for l in lanes:
		var a: Vector3 = l[0]
		var b: Vector3 = l[1]
		for side: float in [-1.0, 1.0]:
			var dir := (b - a).normalized()
			var off := Vector3(-dir.z, 0, dir.x) * 1.6 * side
			var run_len := a.distance_to(b)
			var mi := _visual_box(paint, "Lane%d%s" % [i, "L" if side < 0 else "R"], Vector3(0.14, 0.012, run_len), (a + b) * 0.5 + off + Vector3(0, 0.006, 0), lane)
			mi.rotation.y = atan2(dir.x, dir.z)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		i += 1


# ---------------------------------------------------------------------------
# The chocolate river: channel, flowing surface, waterfall, banks and rails
# ---------------------------------------------------------------------------

func _build_river() -> void:
	var river := Node3D.new()
	river.name = "River"
	geo.add_child(river)
	var w := RIVER_Z1 - RIVER_Z0
	var cz := (RIVER_Z0 + RIVER_Z1) * 0.5
	# Bed (its navmesh island is dropped) and retaining walls.
	_collider(river, "Bed", Vector3(HALL_X * 2.0, 0.4, w), Vector3(0, RIVER_BED - 0.2, cz))
	var choc_wall := _mat("river_wall", Color(0.36, 0.2, 0.13), 0.7)
	var coping := _mat("coping", Color(1.0, 0.95, 0.88), 0.5)
	for side in [[RIVER_Z0, -1.0], [RIVER_Z1, 1.0]]:
		var z: float = side[0]
		var s: float = side[1]
		_visual_box(river, "Wall%s" % ("N" if s < 0 else "S"), Vector3(HALL_X * 2.0, -RIVER_BED, 0.3), Vector3(0, RIVER_BED * 0.5, z - s * 0.15), choc_wall)
		_visual_box(river, "Coping%s" % ("N" if s < 0 else "S"), Vector3(HALL_X * 2.0, 0.14, 0.7), Vector3(0, 0.05, z + s * 0.2), coping)
	var surface := MeshInstance3D.new()
	surface.name = "Chocolate"
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALL_X * 2.0, w)
	plane.subdivide_width = 16
	surface.mesh = plane
	surface.material_override = _chocolate(Vector2(0.06, 0.0), true)
	surface.position = Vector3(0, RIVER_SURFACE, cz)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(surface)
	# Bank railings with gaps for the bridges.
	var edges: Array[float] = [-HALL_X + 0.6]
	for b in BRIDGES:
		edges.append(float(b[0]) - float(b[1]) * 0.5 - 0.35)
		edges.append(float(b[0]) + float(b[1]) * 0.5 + 0.35)
	edges.append(HALL_X - 0.6)
	var walls := _player_walls()
	for k in range(0, edges.size(), 2):
		for side in [[RIVER_Z0 - 0.25, "N"], [RIVER_Z1 + 0.25, "S"]]:
			var z: float = side[0]
			_fence_run(river, "Rail%s%d" % [side[1], k / 2], Vector3(edges[k], 0, z), Vector3(edges[k + 1], 0, z))
			_player_wall(walls, "Bank%s%d" % [side[1], k / 2], Vector3(edges[k], 0, z), Vector3(edges[k + 1], 0, z), 4.0)
	# Bridges.
	for b in BRIDGES:
		var x: float = b[0]
		var bw: float = b[1]
		var bridge := _prop(river, b[2], "Bridge%d" % int(x), Vector3(x, 0, cz), 0.0, Vector3(bw, 1.2, 9))
		bridge.name = "Bridge%s" % ("W" if x < 0 else ("E" if x > 0 else "Main"))
		_collider(river, bridge.name + "Deck", Vector3(bw + 0.4, 0.4, 9.0), Vector3(x, -0.1, cz))
		for s: float in [-1.0, 1.0]:
			var sx := x + s * (bw * 0.5 + 0.12)
			_collider(river, bridge.name + "Side%s" % ("L" if s < 0 else "R"), Vector3(0.3, 1.2, 9.0), Vector3(sx, 0.6, cz))
			_player_wall(walls, bridge.name + "Side%s" % ("L" if s < 0 else "R"), Vector3(sx, 0, cz - 4.5), Vector3(sx, 0, cz + 4.5), 4.0)
	# The chocolate waterfall pours from a pipe in the west wall.
	var spout_pos := Vector3(-HALL_X + 0.4, 3.6, cz)
	_prop(dressing, "candy_spout", "ChocolateSpout", spout_pos, 90.0, Vector3(2.6, 2.6, 3))
	var fall := MeshInstance3D.new()
	fall.name = "Waterfall"
	fall.mesh = _waterfall_mesh(spout_pos + Vector3(0.5, -0.9, 0), 2.0)
	fall.material_override = _chocolate(Vector2(0.0, -0.9), false)
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(fall)
	# The culvert where it leaves through the east wall (dark, behind a grille).
	_visual_box(dressing, "CulvertDark", Vector3(0.2, 3.4, w), Vector3(HALL_X + WALL_THICK + 0.6, 0.2, cz), _mat("void", Color(0.06, 0.03, 0.04), 1.0))
	for k in 7:
		_visual_box(dressing, "CulvertBar%d" % k, Vector3(0.16, 2.6, 0.16), Vector3(HALL_X + 0.3, 0.4, RIVER_Z0 + 0.75 * (k + 1)), _mat("steel_dark", Color(0.42, 0.4, 0.52), 0.4))


## A curved sheet from the spout mouth down to the river surface.
func _waterfall_mesh(top: Vector3, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 10
	for j in rows + 1:
		var t := float(j) / rows
		var p := top + Vector3(0.9 * sin(t * PI * 0.5) + 0.4 * t, (RIVER_SURFACE - top.y) * t * t * 0.6 + (RIVER_SURFACE - top.y) * t * 0.4, 0)
		for side in 2:
			st.set_uv(Vector2(side, t * 2.0))
			st.set_normal(Vector3(1, 0.3, 0).normalized())
			st.add_vertex(p + Vector3(0, 0, (side - 0.5) * width * (1.0 + t * 0.25)))
	for j in rows:
		var a := j * 2
		for idx in [a, a + 1, a + 2, a + 1, a + 3, a + 2]:
			st.add_index(idx)
	return st.commit()


func _chocolate(flow: Vector2, world_uv: bool) -> ShaderMaterial:
	var key := "choc%s%s" % [flow, world_uv]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "candy_chocolate.gdshader")
	m.set_shader_parameter("swirl", load(TEXTURES + "candy_choc.png"))
	m.set_shader_parameter("flow", flow)
	m.set_shader_parameter("world_uv", world_uv)
	_materials[key] = m
	return m


# ---------------------------------------------------------------------------
# Hall walls: brick, chocolate wainscot, cornice, pilasters, frosted windows
# ---------------------------------------------------------------------------

func _build_walls() -> void:
	var walls := Node3D.new()
	walls.name = "Walls"
	geo.add_child(walls)
	var gaps := {"W": [], "E": [], "S": [], "N": []}
	for d in DOORS:
		gaps[d[1]].append([float(d[2]), DOOR_W, float(d[3]), float(d[3]) + DOOR_H])
	# The river runs under the west and east walls (the east culvert is open).
	gaps["E"].append([(RIVER_Z0 + RIVER_Z1) * 0.5, RIVER_Z1 - RIVER_Z0, WALL_BASE, 2.0])
	_wall(walls, "WallW", Vector3(-HALL_X, 0, HALL_Z1), Vector3(-HALL_X, 0, HALL_Z0), gaps["W"])
	_wall(walls, "WallE", Vector3(HALL_X, 0, HALL_Z0), Vector3(HALL_X, 0, HALL_Z1), gaps["E"])
	_wall(walls, "WallS", Vector3(HALL_X, 0, HALL_Z1), Vector3(-HALL_X, 0, HALL_Z1), gaps["S"])
	_wall(walls, "WallN", Vector3(-HALL_X, 0, HALL_Z0), Vector3(HALL_X, 0, HALL_Z0), gaps["N"])
	_build_pilasters_and_windows()
	# The great lollipop rose window in the north gable, behind the gumball machine.
	_prop(dressing, "candy_rose_window", "RoseWindow", Vector3(0, 12.6, HALL_Z0 + 0.05), 0.0, Vector3(12, 12, 0.5))


## A wall along a -> b (inner face on that line, the hall on its right-hand
## side), with openings [centre along the wall, width, bottom, top].
func _wall(parent: Node3D, wall_name: String, a: Vector3, b: Vector3, gaps: Array) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var outward := Vector3(dir.z, 0, -dir.x)     # left of the walking direction
	var yaw := atan2(dir.x, dir.z)
	var brick := _textured("brick", "candy_brick", 0.5, 0.8)
	var wainscot := _mat("wainscot", Color(0.42, 0.23, 0.15), 0.6)
	var trim := _mat("butter", Color(1.0, 0.86, 0.5), 0.5)
	var pink_trim := _mat("pink_trim", Color(1.0, 0.55, 0.74), 0.5)
	# Spans of the wall between openings, and the parts above/below each opening.
	var cuts: Array = []
	for g in gaps:
		var along := absf((Vector3(0, 0, g[0]) if absf(dir.z) > 0.5 else Vector3(g[0], 0, 0)).dot(dir) - a.dot(dir))
		cuts.append([along - float(g[1]) * 0.5, along + float(g[1]) * 0.5, float(g[2]), float(g[3])])
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var pieces: Array = []      # [from, to, bottom, top]
	var at := 0.0
	for c in cuts:
		pieces.append([at, c[0], WALL_BASE, WALL_TOP])
		pieces.append([c[0], c[1], c[3], WALL_TOP])
		if c[2] > WALL_BASE + 0.1:
			pieces.append([c[0], c[1], WALL_BASE, c[2]])
		at = c[1]
	pieces.append([at, length, WALL_BASE, WALL_TOP])
	var k := 0
	for p in pieces:
		var from: float = p[0]
		var to: float = p[1]
		var bottom: float = p[2]
		var top: float = p[3]
		if to - from < 0.05:
			continue
		var mid := a + dir * (from + to) * 0.5
		var seg_len := to - from
		var body := _collider(parent, "%s_%d" % [wall_name, k], Vector3(seg_len, top - bottom, WALL_THICK),
			mid + outward * WALL_THICK * 0.5 + Vector3(0, (top + bottom) * 0.5, 0))
		body.rotation.y = yaw - PI * 0.5
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = _box_mesh(Vector3(seg_len, top - bottom, WALL_THICK), brick)
		body.add_child(mi)
		# Wainscot and dado where the piece reaches the floor; cornice at the top.
		if bottom < 0.5:
			var wtop := minf(top, 1.6)
			_wall_strip(body, "Wainscot", seg_len, bottom, wtop, 0.16, wainscot, top, bottom)
			if top > 1.75:
				_wall_strip(body, "Dado", seg_len, 1.6, 1.78, 0.22, trim, top, bottom)
		if top > 16.0 and bottom < 15.2:
			_wall_strip(body, "Cornice", seg_len, 15.2, 15.7, 0.4, pink_trim, top, bottom)
			_wall_strip(body, "CorniceTop", seg_len, 15.7, 16.1, 0.55, trim, top, bottom)
		k += 1


## A horizontal band on the hall side of a wall piece (local to the piece).
func _wall_strip(body: Node3D, strip_name: String, length: float, y0: float, y1: float, depth: float, material: Material,
		top: float, bottom: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = strip_name
	mi.mesh = _box_mesh(Vector3(length, y1 - y0, depth), material)
	mi.position = Vector3(0, (y0 + y1) * 0.5 - (top + bottom) * 0.5, WALL_THICK * 0.5 + depth * 0.5 - 0.02)
	body.add_child(mi)


## Candy-cane pilasters every 8 m and frosted windows between them (all walls).
func _build_pilasters_and_windows() -> void:
	var pil_xf: Array[Transform3D] = []
	var win_xf: Array[Transform3D] = []
	var runs := [
		[Vector3(-HALL_X, 0, HALL_Z1), Vector3(-HALL_X, 0, HALL_Z0)], [Vector3(HALL_X, 0, HALL_Z0), Vector3(HALL_X, 0, HALL_Z1)],
		[Vector3(HALL_X, 0, HALL_Z1), Vector3(-HALL_X, 0, HALL_Z1)], [Vector3(-HALL_X, 0, HALL_Z0), Vector3(HALL_X, 0, HALL_Z0)],
	]
	for r in runs:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var inward := Vector3(-dir.z, 0, dir.x)
		var yaw := atan2(inward.x, inward.z)
		var n := int(length / 8.0)
		var step := length / n
		var north := absf(a.z - HALL_Z0) < 0.1 and absf(b.z - HALL_Z0) < 0.1
		for i in range(1, n):
			var p := a + dir * step * i + inward * 0.45
			if not _near_door(p, 3.2):
				pil_xf.append(Transform3D(Basis(Vector3.UP, yaw), p))
		for i in n:
			var p := a + dir * step * (i + 0.5) + inward * 0.06
			if north and absf(p.x) < 8.0:
				continue
			win_xf.append(Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 10.5, 0)))
	_multimesh(dressing, "Pilasters", _model_mesh("candy_pilaster"), pil_xf, true)
	# Frosted windows: a lit pane in a cream frame with a mullion cross.
	var frosted := _mat("frosted", Color(0.92, 0.97, 1.0), 0.3, Color(0.9, 0.96, 1.0), 1.15)
	var frame := _mat("cream", Color(1.0, 0.95, 0.88), 0.5)
	_multimesh(dressing, "WindowPanes", _box_mesh(Vector3(3.4, 6.0, 0.08), frosted), win_xf, false)
	var frame_parts: Array[Transform3D] = []
	for t in win_xf:
		for piece in [[Vector3(0, 3.1, 0.06), Vector3(3.8, 0.25, 0.2)], [Vector3(0, -3.1, 0.08), Vector3(3.9, 0.3, 0.3)],
				[Vector3(-1.8, 0, 0.06), Vector3(0.22, 6.2, 0.2)], [Vector3(1.8, 0, 0.06), Vector3(0.22, 6.2, 0.2)],
				[Vector3(0, 0, 0.05), Vector3(0.1, 6.0, 0.12)], [Vector3(0, 0.6, 0.05), Vector3(3.4, 0.1, 0.12)]]:
			var off: Vector3 = piece[0]
			var size: Vector3 = piece[1]
			frame_parts.append(Transform3D(t.basis * Basis.from_scale(size), t.origin + t.basis * off))
	_multimesh(dressing, "WindowFrames", _box_mesh(Vector3.ONE, frame), frame_parts, false)


func _near_door(p: Vector3, margin: float) -> bool:
	for d in DOORS:
		var c := _door_centre(d)
		if Vector2(p.x - c.x, p.z - c.z).length() < DOOR_W * 0.5 + margin:
			return true
	return false


## The point at the middle of a door opening, on the wall's inner face.
func _door_centre(d: Array) -> Vector3:
	match d[1]:
		"W":
			return Vector3(-HALL_X, d[3], d[2])
		"E":
			return Vector3(HALL_X, d[3], d[2])
	return Vector3(d[2], d[3], HALL_Z1)


## Unit vector from the door into the hall.
func _door_inward(d: Array) -> Vector3:
	match d[1]:
		"W":
			return Vector3.RIGHT
		"E":
			return Vector3.LEFT
	return Vector3.FORWARD


# ---------------------------------------------------------------------------
# Zombie entrances: a striped roller door and a short dark loading bay
# ---------------------------------------------------------------------------

func _build_entrances() -> void:
	var e := Node3D.new()
	e.name = "Entrances"
	geo.add_child(e)
	var walls := _player_walls()
	var dark := _mat("bay_dark", Color(0.16, 0.1, 0.14), 0.9)
	var bay_floor := _mat("bay_floor", Color(0.35, 0.3, 0.38), 0.8)
	for d in DOORS:
		var c := _door_centre(d)
		var inward := _door_inward(d)
		var side := Vector3(-inward.z, 0, inward.x)
		var yaw := atan2(inward.x, inward.z)
		var y: float = d[3]
		var door := _prop(dressing, "candy_door", "%sDoor" % d[0], c + inward * 0.25, rad_to_deg(yaw), Vector3(6, 6, 1))
		door.position.y = y
		# The bay behind the opening: floor, sides, back and ceiling.
		var back := c - inward * (WALL_THICK + RECESS)
		var mid := c - inward * (WALL_THICK + RECESS) * 0.5
		var basis := Basis(Vector3.UP, yaw)
		var fl := _box(e, "%sBayFloor" % d[0], Vector3(DOOR_W + 2.0, 2.0 + y, RECESS + WALL_THICK), Vector3.ZERO, bay_floor)
		fl.basis = basis
		fl.position = Vector3(mid.x, (y - 2.0) * 0.5, mid.z)
		for s: float in [-1.0, 1.0]:
			var sw := _box(e, "%sBaySide%s" % [d[0], "L" if s < 0 else "R"], Vector3(0.5, DOOR_H + 1.0, RECESS + WALL_THICK),
				Vector3(0, 0, 0), dark)
			sw.basis = basis
			sw.position = Vector3(c.x, y + (DOOR_H + 1.0) * 0.5, c.z) - inward * (WALL_THICK + RECESS) * 0.5 + side * s * (DOOR_W * 0.5 + 0.25)
		var bk := _box(e, "%sBayBack" % d[0], Vector3(DOOR_W + 1.0, DOOR_H + 1.0, 0.5), Vector3.ZERO, dark)
		bk.basis = basis
		bk.position = Vector3(back.x, y + (DOOR_H + 1.0) * 0.5, back.z)
		var roof := _box(e, "%sBayRoof" % d[0], Vector3(DOOR_W + 1.0, 0.5, RECESS + WALL_THICK), Vector3.ZERO, dark)
		roof.basis = basis
		roof.position = Vector3(c.x, y + DOOR_H + 0.25, c.z) - inward * (WALL_THICK + RECESS) * 0.5
		# Stacked crates inside the bay, beside the way in.
		_prop(dressing, "candy_crates", "%sBayCrates" % d[0], back + inward * 1.4 + side * (DOOR_W * 0.5 - 0.9) + Vector3(0, y, 0), rad_to_deg(yaw) + 90.0, Vector3(2, 1.6, 1.2))
		# Keep the player out of the bay.
		_player_wall(walls, "%sBay" % d[0], c - side * DOOR_W * 0.5 + Vector3(0, y, 0) - inward * 0.3, c + side * DOOR_W * 0.5 + Vector3(0, y, 0) - inward * 0.3, 8.0)
		_omni(dressing, "%sLight" % d[0], c + inward * 1.6 + Vector3(0, y + DOOR_H + 0.4, 0), Color(1.0, 0.72, 0.4), 1.4, 7.5)


# ---------------------------------------------------------------------------
# Roof: sawtooth bays, south-facing skylights, mint trusses
# ---------------------------------------------------------------------------

func _build_roof() -> void:
	var roof := Node3D.new()
	roof.name = "Roof"
	dressing.add_child(roof)
	var bays := 8
	var depth := (HALL_Z1 - HALL_Z0) / bays
	var panel := _mat("roof_under", Color(1.0, 0.93, 0.9), 0.8)
	var glass := StandardMaterial3D.new()
	glass.resource_name = "CandySkylight"
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.86, 0.95, 1.0, 0.16)
	glass.roughness = 0.1
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var slope := atan2(ROOF_HIGH - ROOF_LOW, depth)
	var slope_len := sqrt(depth * depth + (ROOF_HIGH - ROOF_LOW) * (ROOF_HIGH - ROOF_LOW))
	var truss_xf: Array[Transform3D] = []
	var mullion_xf: Array[Transform3D] = []
	for i in bays:
		var zs := HALL_Z1 - depth * i           # south edge: the glass
		var zn := zs - depth
		var mid := Vector3(0, (ROOF_LOW + ROOF_HIGH) * 0.5 + 0.2, (zs + zn) * 0.5)
		var p := _visual_box(roof, "Slope%d" % i, Vector3(HALL_X * 2.0 + 2.0, 0.35, slope_len + 0.3), mid, panel)
		p.rotation.x = -slope
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var g := _visual_box(roof, "Glass%d" % i, Vector3(HALL_X * 2.0, ROOF_HIGH - ROOF_LOW, 0.06), Vector3(0, (ROOF_LOW + ROOF_HIGH) * 0.5, zs - 0.1), glass)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for k in 17:
			var x := -HALL_X + k * 4.0
			mullion_xf.append(Transform3D(Basis().scaled(Vector3(0.16, ROOF_HIGH - ROOF_LOW, 0.2)), Vector3(x, (ROOF_LOW + ROOF_HIGH) * 0.5, zs - 0.1)))
		if i == 0:
			continue
		# A Warren truss under the glass line: chords and diagonals.
		truss_xf.append(Transform3D(Basis().scaled(Vector3(HALL_X * 2.0, 0.3, 0.3)), Vector3(0, ROOF_LOW - 0.15, zs)))
		truss_xf.append(Transform3D(Basis().scaled(Vector3(HALL_X * 2.0, 0.3, 0.3)), Vector3(0, ROOF_LOW - 1.65, zs)))
		for k in 32:
			var x0 := -HALL_X + k * 2.0
			var up := k % 2 == 0
			var a := Vector3(x0, ROOF_LOW - (1.65 if up else 0.15), zs)
			var b := Vector3(x0 + 2.0, ROOF_LOW - (0.15 if up else 1.65), zs)
			var d := b - a
			var basis := Basis(Vector3.BACK, atan2(d.y, d.x)) * Basis.from_scale(Vector3(d.length(), 0.16, 0.16))
			truss_xf.append(Transform3D(basis, (a + b) * 0.5))
	_multimesh(roof, "Trusses", _box_mesh(Vector3.ONE, _mat("truss", Color(0.45, 0.82, 0.72), 0.45)), truss_xf, true)
	_multimesh(roof, "Mullions", _box_mesh(Vector3.ONE, _mat("truss", Color(0.45, 0.82, 0.72), 0.45)), mullion_xf, false)
	# The big hanging sign over the main bridge.
	_prop(dressing, "candy_sign", "FactorySign", Vector3(0, 9.6, (RIVER_Z0 + RIVER_Z1) * 0.5), 0.0, Vector3(11, 3, 0.4))


# ---------------------------------------------------------------------------
# North yard: the colossal gumball machine, the silos, cover
# ---------------------------------------------------------------------------

func _build_north_yard() -> void:
	var yard := Node3D.new()
	yard.name = "NorthYard"
	geo.add_child(yard)
	var machine := _prop(yard, "candy_gumball_machine", "GumballMachine", GUMBALL, 0.0, Vector3(7, 16, 7))
	var crank := machine.get_node_or_null("Crank")
	if crank:
		_late(crank, "res://scripts/props/candy_spinner.gd", {"axis": Vector3.FORWARD, "degrees_per_second": 40.0})
	_collider(yard, "GumballPlinth", Vector3(7.4, 0.6, 7.4), GUMBALL + Vector3(0, 0.3, 0))
	_post(yard, "GumballBody", 3.3, 7.0, GUMBALL)
	_collider(yard, "GumballChute", Vector3(1.8, 3.0, 2.2), GUMBALL + Vector3(0, 1.5, 3.4))
	_player_block(yard, "GumballCap", Vector3(9.0, 12.0, 9.0), GUMBALL + Vector3(0, 13.0, 0))
	# Gumballs tumble from the chute onto a short belt toward the sorter.
	_conveyor_line(yard, "ChuteBelt", Vector3(-0.8, 0, GUMBALL.z + 4.9), Vector3(14.2, 0, GUMBALL.z + 4.9), "SweetDrop", 0.7)
	_solid_prop(yard, "candy_box_machine", "Sorter", Vector3(16.6, 0, GUMBALL.z + 4.9), 0.0, Vector3(4.2, 3.2, 2.6))
	# Silos against the north wall.
	var silos := [[-25.5, "candy_silo"], [-17.5, "candy_silo_b"], [17.5, "candy_silo"], [25.5, "candy_silo_b"]]
	for s in silos:
		var p := Vector3(s[0], 0, HALL_Z0 + 2.6)
		_prop(yard, s[1], "Silo%d" % int(s[0]), p, 0.0, Vector3(5, 16, 5))
		_post(yard, "Silo%dBody" % int(s[0]), 2.5, 16.0, p)
	_player_block(yard, "SiloBacks", Vector3(HALL_X * 2.0, 18.0, 1.6), Vector3(0, 9.0, HALL_Z0 + 0.8))
	# Cover in the yard.
	_solid_prop(yard, "candy_sacks", "YardSacksW", Vector3(-9.0, 0, -22.5), 20.0, Vector3(1.6, 1.1, 1.2))
	_solid_prop(yard, "candy_crates", "YardCratesE", Vector3(9.5, 0, -18.5), -15.0, Vector3(2.0, 1.6, 1.2))
	_solid_prop(yard, "candy_cart", "YardCartW", Vector3(-12.5, 0, -18.0), 70.0, Vector3(1.8, 1.25, 1.1))
	_solid_prop(yard, "candy_boxes", "YardBoxes", Vector3(-24.0, 0, -18.5), 0.0, Vector3(1.5, 1.6, 1.2))
	_solid_prop(yard, "candy_forklift", "YardForklift", Vector3(24.5, 0, -19.0), 200.0, Vector3(1.3, 2.3, 2.6))
	_solid_prop(yard, "candy_sacks", "YardSacksE", Vector3(11.0, 0, -29.5), -30.0, Vector3(1.6, 1.1, 1.2))
	for l: Vector3 in [Vector3(-7.0, 0, -31.0), Vector3(7.0, 0, -24.0), Vector3(-6.0, 0, -17.0)]:
		_prop(dressing, "candy_lollipop", "YardPop%d" % int(l.x), l, l.x * 9.0, Vector3(2, 3.6, 0.5))
		_post(yard, "YardPop%dPost" % int(l.x), 0.65, 1.0, l)


# ---------------------------------------------------------------------------
# Loadout station: the Sweet Shop
# ---------------------------------------------------------------------------

func _build_station() -> void:
	var station: Node3D = (load("res://scenes/props/candy_station.tscn") as PackedScene).instantiate()
	station.name = "Station"
	geo.add_child(station)
	station.position = STATION
	var pad := MeshInstance3D.new()
	pad.name = "StationPad"
	var disc := CylinderMesh.new()
	disc.top_radius = 7.6
	disc.bottom_radius = 7.6
	disc.height = 0.03
	disc.radial_segments = 48
	pad.mesh = disc
	pad.material_override = _mat("pad", Color(1.0, 0.78, 0.88), 0.6)
	pad.position = STATION + Vector3(0, 0.012, 0)
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(pad)
	var rim := MeshInstance3D.new()
	rim.name = "StationPadRim"
	var torus := TorusMesh.new()
	torus.inner_radius = 7.5
	torus.outer_radius = 7.85
	torus.rings = 64
	torus.ring_segments = 6
	rim.mesh = torus
	rim.material_override = _mat("butter", Color(1.0, 0.86, 0.5), 0.5)
	rim.position = STATION + Vector3(0, 0.0, 0)
	rim.scale = Vector3(1, 0.12, 1)
	dressing.add_child(rim)


# ---------------------------------------------------------------------------
# The taffy puller on its platform (west), with steps and a ramp
# ---------------------------------------------------------------------------

func _build_taffy_platform() -> void:
	var t := Node3D.new()
	t.name = "TaffyPlatform"
	geo.add_child(t)
	var c := Vector3(TAFFY.get_center().x, 0, TAFFY.get_center().y)
	var deck := _mat("mint_deck", Color(0.62, 0.9, 0.8), 0.6)
	var side := _mat("wainscot", Color(0.42, 0.23, 0.15), 0.6)
	_box(t, "Deck", Vector3(TAFFY.size.x, TAFFY_Y, TAFFY.size.y), c + Vector3(0, TAFFY_Y * 0.5, 0), side)
	_visual_box(t, "DeckTop", Vector3(TAFFY.size.x - 0.1, 0.06, TAFFY.size.y - 0.1), c + Vector3(0, TAFFY_Y + 0.01, 0), deck)
	# Steps down to the east, a ramp down to the south.
	_slope(t, "EastSteps", Vector3(TAFFY.end.x, TAFFY_Y, c.z - 1.0), Vector3.RIGHT, 2.6, 3.4, TAFFY_Y, deck, true)
	_slope(t, "SouthRamp", Vector3(TAFFY.end.x - 2.0, TAFFY_Y, TAFFY.end.y), Vector3.BACK, 3.4, 3.0, TAFFY_Y, deck, false)
	# Railings: north edge, the east edge either side of the steps, the south edge east of the ramp.
	var y := TAFFY_Y
	_fence_run(t, "RailN", Vector3(TAFFY.position.x + 0.4, y, TAFFY.position.y + 0.15), Vector3(TAFFY.end.x - 0.15, y, TAFFY.position.y + 0.15))
	_fence_run(t, "RailEN", Vector3(TAFFY.end.x - 0.15, y, TAFFY.position.y + 0.15), Vector3(TAFFY.end.x - 0.15, y, c.z - 2.9))
	_fence_run(t, "RailES", Vector3(TAFFY.end.x - 0.15, y, c.z + 0.9), Vector3(TAFFY.end.x - 0.15, y, TAFFY.end.y - 0.15))
	_fence_run(t, "RailS", Vector3(TAFFY.position.x + 0.15, y, TAFFY.end.y - 0.15), Vector3(TAFFY.end.x - 3.7, y, TAFFY.end.y - 0.15))
	_fence_run(t, "RailW", Vector3(TAFFY.position.x + 0.15, y, TAFFY.position.y + 0.15), Vector3(TAFFY.position.x + 0.15, y, TAFFY.end.y - 0.15))
	# The machine faces east over the floor; its arms turn in the plane of the front.
	var machine := _prop(t, "candy_taffy_puller", "TaffyPuller", c + Vector3(-1.6, y, 0), 90.0, Vector3(4.6, 8, 3))
	var arms := machine.get_node_or_null("Arms")
	if arms:
		_late(arms, "res://scripts/props/candy_spinner.gd", {"axis": Vector3.FORWARD, "degrees_per_second": 34.0})
	var mc := c + Vector3(-2.0, y, 0)
	_collider(t, "TaffyHousing", Vector3(3.2, 2.5, 4.8), mc + Vector3(0, 1.25, 0))
	_post(t, "TaffyColumn", 0.7, 6.0, mc + Vector3(0.6, 0, 0))
	_player_block(t, "TaffyCap", Vector3(5.0, 8.0, 7.0), mc + Vector3(0, 6.5, 0))
	_solid_prop(t, "candy_boxes", "PlatformBoxes", Vector3(TAFFY.position.x + 1.2, y, TAFFY.end.y - 1.2), 10.0, Vector3(1.5, 1.6, 1.2))
	_solid_prop(t, "candy_sacks", "PlatformSacks", Vector3(TAFFY.position.x + 1.3, y, TAFFY.position.y + 1.2), 80.0, Vector3(1.6, 1.1, 1.2))
	_omni(dressing, "TaffyGlow", c + Vector3(1.0, 5.5, 0), Color(1.0, 0.6, 0.8), 1.2, 9.0)


# ---------------------------------------------------------------------------
# Mixing vats on the south bank of the river (west)
# ---------------------------------------------------------------------------

func _build_vats() -> void:
	var v := Node3D.new()
	v.name = "Vats"
	geo.add_child(v)
	for p: Vector3 in [Vector3(-27.0, 0, -4.2), Vector3(-10.5, 0, -4.4)]:
		var vat := _prop(v, "candy_vat", "Vat%d" % int(absf(p.x)), p, 0.0, Vector3(4.6, 5.8, 4.6))
		var paddle := vat.get_node_or_null("Paddle")
		if paddle:
			_late(paddle, "res://scripts/props/candy_spinner.gd", {"axis": Vector3.UP, "degrees_per_second": 55.0})
		_post(v, "Vat%dBody" % int(absf(p.x)), 2.45, 4.0, p)
		_player_block(v, "Vat%dCap" % int(absf(p.x)), Vector3(5.6, 6.0, 1.4), p + Vector3(0, 7.0, 0))


# ---------------------------------------------------------------------------
# Packing mezzanine (east, 3 m): deck, columns, ramp, stairs, railings
# ---------------------------------------------------------------------------

func _build_mezzanine() -> void:
	var m := Node3D.new()
	m.name = "Mezzanine"
	geo.add_child(m)
	var c := Vector3(MEZZ.get_center().x, 0, MEZZ.get_center().y)
	var steel := _mat("mezz_steel", Color(0.78, 0.66, 0.95), 0.45)
	var deck := _mat("mezz_deck", Color(1.0, 0.82, 0.9), 0.6)
	_box(m, "Deck", Vector3(MEZZ.size.x, 0.35, MEZZ.size.y), c + Vector3(0, MEZZ_Y - 0.175, 0), steel)
	_visual_box(m, "DeckTop", Vector3(MEZZ.size.x - 0.05, 0.04, MEZZ.size.y - 0.05), c + Vector3(0, MEZZ_Y + 0.01, 0), deck)
	_visual_box(m, "Fascia", Vector3(0.12, 0.5, MEZZ.size.y), Vector3(MEZZ.position.x - 0.06, MEZZ_Y - 0.25, c.z), _mat("butter", Color(1.0, 0.86, 0.5), 0.5))
	for x: float in [MEZZ.position.x + 0.4, MEZZ.position.x + 6.5]:
		for z: float in [MEZZ.position.y + 0.4, c.z, MEZZ.end.y - 0.4]:
			_post(m, "Column%d_%d" % [int(x), int(z)], 0.22, MEZZ_Y - 0.35, Vector3(x, 0, z))
			var col := _visual_box(m, "ColumnMesh%d_%d" % [int(x), int(z)], Vector3(0.36, MEZZ_Y - 0.35, 0.36), Vector3(x, (MEZZ_Y - 0.35) * 0.5, z), steel)
			col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Ramp at the north end and stairs at the south end, both down to the west.
	_slope(m, "Ramp", Vector3(MEZZ.position.x, MEZZ_Y, MEZZ.position.y + 2.0), Vector3.LEFT, 7.2, 3.2, MEZZ_Y, deck, false)
	_slope(m, "Stairs", Vector3(MEZZ.position.x, MEZZ_Y, MEZZ.end.y - 2.2), Vector3.LEFT, 5.6, 3.0, MEZZ_Y, deck, true)
	var y := MEZZ_Y
	var x0 := MEZZ.position.x + 0.15
	_fence_run(m, "RailN", Vector3(x0, y, MEZZ.position.y + 0.15), Vector3(MEZZ.end.x - 0.4, y, MEZZ.position.y + 0.15))
	_fence_run(m, "RailS", Vector3(x0, y, MEZZ.end.y - 0.15), Vector3(MEZZ.end.x - 0.4, y, MEZZ.end.y - 0.15))
	_fence_run(m, "RailW1", Vector3(x0, y, MEZZ.position.y + 3.8), Vector3(x0, y, MEZZ.end.y - 3.9))
	# Packing dressing on the deck (cover up top).
	_solid_prop(m, "candy_boxes", "DeckBoxesA", Vector3(24.5, y, -1.0), 15.0, Vector3(1.5, 1.6, 1.2))
	_solid_prop(m, "candy_conveyor", "DeckBelt", Vector3(27.5, y, -1.6), 90.0, Vector3(4.0, 1.1, 1.3))
	_solid_prop(m, "candy_boxes", "DeckBoxesB", Vector3(29.6, y, 11.0), -10.0, Vector3(1.5, 1.6, 1.2))
	_solid_prop(m, "candy_sacks", "DeckSacks", Vector3(21.6, y, 4.2), 80.0, Vector3(1.6, 1.1, 1.2))
	# Under the deck: pallets and a warm work light.
	_solid_prop(m, "candy_sacks", "UnderSacks", Vector3(28.5, 0, -1.5), 0.0, Vector3(1.6, 1.1, 1.2))
	_solid_prop(m, "candy_boxes", "UnderBoxes", Vector3(29.0, 0, 9.0), 90.0, Vector3(1.5, 1.6, 1.2))
	_omni(dressing, "UnderDeckLight", c + Vector3(1.0, 2.4, 0), Color(1.0, 0.78, 0.55), 1.0, 9.0)


# ---------------------------------------------------------------------------
# Packaging line along the south wall: belts, the box folder, moving sweets
# ---------------------------------------------------------------------------

func _build_packing_line() -> void:
	var line := Node3D.new()
	line.name = "PackingLine"
	geo.add_child(line)
	_conveyor_line(line, "BeltWest", Vector3(-20.0, 0, BELT_Z), Vector3(-8.0, 0, BELT_Z), "SweetWrapped", 0.55)
	_solid_prop(line, "candy_box_machine", "BoxFolder", Vector3(-5.0, 0, BELT_Z), 0.0, Vector3(4.2, 3.2, 2.6))
	_conveyor_line(line, "BeltMid", Vector3(-2.9, 0, BELT_Z), Vector3(9.1, 0, BELT_Z), "SweetBox", 0.55)
	_conveyor_line(line, "BeltEast", Vector3(14.6, 0, BELT_Z), Vector3(26.6, 0, BELT_Z), "SweetBox", 0.55)
	_solid_prop(line, "candy_boxes", "LineEndBoxes", Vector3(28.6, 0, BELT_Z + 1.2), 0.0, Vector3(1.5, 1.6, 1.2))
	_solid_prop(line, "candy_boxes", "LineMidBoxes", Vector3(11.6, 0, BELT_Z + 3.2), 30.0, Vector3(1.5, 1.6, 1.2))
	_solid_prop(line, "candy_forklift", "LineForklift", Vector3(-12.0, 0, BELT_Z - 3.4), 100.0, Vector3(1.3, 2.3, 2.6))


## A straight run of conveyor modules from a to b (on the floor) carrying `sweet`.
func _conveyor_line(parent: Node3D, line_name: String, a: Vector3, b: Vector3, sweet: String, speed: float) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var yaw := atan2(-dir.z, dir.x)
	var count := int(round(length / 4.0))
	var step := length / count
	var xf: Array[Transform3D] = []
	for i in count:
		xf.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(step / 4.0, 1, 1)), a + dir * step * (i + 0.5)))
	_multimesh(parent, line_name + "Modules", _model_mesh("candy_conveyor"), xf, true)
	var body := _collider(parent, line_name + "Collision", Vector3(length, 1.15, 1.3), (a + b) * 0.5 + Vector3(0, 0.575, 0))
	body.rotation.y = yaw
	# Sweets ride along the belt top (local start/end on the belt line).
	var sweets := MultiMeshInstance3D.new()
	sweets.name = line_name + "Sweets"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _sweet_mesh(sweet)
	var n := int(length / 1.1)
	mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = line_name.hash()
	for i in n:
		var t := (i + rng.randf_range(0.0, 0.4)) / n
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.5, 0.5) + yaw), a.lerp(b, t) + Vector3(0, 0.97, 0)))
	sweets.multimesh = mm
	sweets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(sweets)
	_late(sweets, "res://scripts/props/candy_conveyor.gd", {"start": a + Vector3(0, 0.97, 0), "end": b + Vector3(0, 0.97, 0), "speed": speed})


func _sweet_mesh(sweet: String) -> Mesh:
	var key := "sweet_" + sweet
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var source: Node3D = (load(MODELS + "candy_sweets.glb") as PackedScene).instantiate()
	var node := source.find_child(sweet, true, false) as MeshInstance3D
	var mesh: Mesh = node.mesh if node else BoxMesh.new()
	source.free()
	_mesh_cache[key] = mesh
	return mesh


# ---------------------------------------------------------------------------
# The gingerbread office (south-west corner)
# ---------------------------------------------------------------------------

func _build_office() -> void:
	var o := Node3D.new()
	o.name = "Office"
	geo.add_child(o)
	var p := Vector3(-27.0, 0, 21.0)
	_prop(o, "candy_office", "GingerbreadOffice", p, 90.0, Vector3(10, 7.6, 8))
	_collider(o, "OfficeBody", Vector3(8.4, 7.0, 10.4), p + Vector3(0, 3.5, 0))
	_player_block(o, "OfficeRoof", Vector3(9.0, 6.0, 11.0), p + Vector3(0, 9.0, 0))
	_prop(dressing, "candy_lollipop", "OfficePop", p + Vector3(5.5, 0, 6.2), 90.0, Vector3(2, 3.6, 0.5))
	_post(o, "OfficePopPost", 0.65, 1.0, p + Vector3(5.5, 0, 6.2))


# ---------------------------------------------------------------------------
# Floor props: cover around the station, lamps, vents
# ---------------------------------------------------------------------------

func _build_floor_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	geo.add_child(props)
	# Chest-high cover rings the station (kept off the patrol ring at ~5 m).
	_solid_prop(props, "candy_crates", "CratesNW", Vector3(-8.5, 0, -0.5), 25.0, Vector3(2.0, 1.6, 1.2))
	_solid_prop(props, "candy_sacks", "SacksNE", Vector3(7.5, 0, -1.8), -20.0, Vector3(1.6, 1.1, 1.2))
	_solid_prop(props, "candy_cart", "CartW", Vector3(-9.0, 0, 9.0), 75.0, Vector3(1.8, 1.25, 1.1))
	_solid_prop(props, "candy_boxes", "BoxesE", Vector3(9.5, 0, 9.5), 10.0, Vector3(1.5, 1.6, 1.2))
	_solid_prop(props, "candy_crates", "CratesS", Vector3(5.5, 0, 13.6), 0.0, Vector3(2.0, 1.6, 1.2))
	_solid_prop(props, "candy_sacks", "SacksSW", Vector3(-6.0, 0, 15.0), 60.0, Vector3(1.6, 1.1, 1.2))
	_solid_prop(props, "candy_forklift", "ForkliftE", Vector3(13.0, 0, 3.0), 160.0, Vector3(1.3, 2.3, 2.6))
	_solid_prop(props, "candy_cart", "CartBank", Vector3(5.5, 0, -5.5), 0.0, Vector3(1.8, 1.25, 1.1))
	_solid_prop(props, "candy_crates", "CratesBankW", Vector3(-15.5, 0, -6.4), 0.0, Vector3(2.0, 1.6, 1.2))
	_solid_prop(props, "candy_boxes", "BoxesWest", Vector3(-15.0, 0, 13.5), 40.0, Vector3(1.5, 1.6, 1.2))
	_solid_prop(props, "candy_sacks", "SacksEast", Vector3(15.0, 0, 15.5), 15.0, Vector3(1.6, 1.1, 1.2))
	# Steam vents (low, walk-around).
	for v: Vector3 in [Vector3(-13.0, 0, 3.5), Vector3(10.0, 0, -6.2), Vector3(-6.0, 0, -26.0)]:
		_solid_prop(props, "candy_vent", "Vent%d" % int(v.x), v, 0.0, Vector3(1.0, 1.6, 1.0))
	# Lollipop lamps round the station and along the routes.
	var lamps := [
		Vector3(-5.8, 0, -2.5), Vector3(5.8, 0, -2.5), Vector3(-6.4, 0, 7.8), Vector3(6.4, 0, 7.8),
		Vector3(-3.6, 0, -16.6), Vector3(3.6, 0, -16.6), Vector3(-3.6, 0, -7.4), Vector3(3.6, 0, -7.4),
		Vector3(-23.0, 0, -6.5), Vector3(15.5, 0, -6.5), Vector3(-2.8, 0, 19.5), Vector3(10.5, 0, 19.5),
	]
	var i := 0
	for p in lamps:
		_prop(dressing, "candy_lamp", "Lamp%02d" % i, p, i * 37.0, Vector3(0.3, 4.6, 0.3))
		_post(props, "Lamp%02dPost" % i, 0.16, 4.2, p)
		_player_block(props, "Lamp%02dCap" % i, Vector3(1.4, 2.0, 1.4), p + Vector3(0, 5.2, 0))
		i += 1


# ---------------------------------------------------------------------------
# Pipes: striped feed lines along the roof trusses, down into the machines
# ---------------------------------------------------------------------------

func _build_pipes() -> void:
	var pink: Array[Transform3D] = []
	var mint: Array[Transform3D] = []
	# Each pair of silos feeds the gumball globe from its side (clear of the rose window).
	for s: float in [-1.0, 1.0]:
		_pipe_run(pink, Vector3(s * 28.0, 13.2, HALL_Z0 + 2.6), Vector3(s * 9.0, 13.2, HALL_Z0 + 2.6))
		_pipe_run(pink, Vector3(s * 9.0, 13.2, HALL_Z0 + 2.6), Vector3(s * 9.0, 13.2, GUMBALL.z))
		_pipe_run(pink, Vector3(s * 9.0, 13.2, GUMBALL.z), Vector3(s * 3.4, 13.2, GUMBALL.z))
	# A sugar line from the west wall over the vats and down into the taffy puller.
	_pipe_run(mint, Vector3(-HALL_X, 11.5, -4.3), Vector3(-8.0, 11.5, -4.3))
	for x: float in [-27.0, -10.5]:
		_pipe_run(mint, Vector3(x, 11.5, -4.3), Vector3(x, 6.0, -4.3))
	_pipe_run(mint, Vector3(-23.6, 11.5, -4.3), Vector3(-23.6, 11.5, 6.0))
	_pipe_run(mint, Vector3(-23.6, 11.5, 6.0), Vector3(-23.6, 9.0, 6.0))
	# Overhead lines across the hall to the mezzanine and the packing line.
	_pipe_run(pink, Vector3(-HALL_X, 12.4, 18.0), Vector3(HALL_X, 12.4, 18.0))
	_pipe_run(mint, Vector3(HALL_X, 10.0, 6.0), Vector3(-8.0, 10.0, 6.0))
	_pipe_run(pink, Vector3(-5.0, 12.4, 18.0), Vector3(-5.0, 4.5, 18.0))
	_pipe_run(pink, Vector3(-5.0, 4.5, 18.0), Vector3(-5.0, 4.5, BELT_Z))
	_multimesh(dressing, "PipesPink", _model_mesh("candy_pipe"), pink, true)
	_multimesh(dressing, "PipesMint", _model_mesh("candy_pipe_mint"), mint, true)


## Fills a straight run with 4 m pipe modules (stretched to fit).
func _pipe_run(out: Array[Transform3D], a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var count := maxi(1, int(round(length / 4.0)))
	var step := length / count
	var dir := (b - a) / length
	# The module lies along X; build a basis whose X axis follows the run.
	var up := Vector3.UP if absf(dir.y) < 0.9 else Vector3.BACK
	var z := dir.cross(up).normalized()
	var y := z.cross(dir).normalized()
	for i in count:
		out.append(Transform3D(Basis(dir * (step / 4.0), y, z), a + dir * step * (i + 0.5)))


# ---------------------------------------------------------------------------
# Lights: hanging factory lamps and warm accents (no shadows)
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	var lights := Node3D.new()
	lights.name = "FactoryLights"
	level.add_child(lights)
	_omni(lights, "StationGlow", STATION + Vector3(0, 6.0, 1.0), Color(1.0, 0.72, 0.85), 1.4, 12.0)
	_omni(lights, "GumballGlow", GUMBALL + Vector3(0, 4.0, 6.0), Color(1.0, 0.82, 0.55), 1.4, 12.0)
	_omni(lights, "PackingGlow", Vector3(4.0, 5.0, BELT_Z - 1.0), Color(1.0, 0.85, 0.65), 1.0, 12.0)
	# Pendant lamps hang from the trusses on cables (shades + glowing bulbs).
	var shade_xf: Array[Transform3D] = []
	var cable_xf: Array[Transform3D] = []
	for z: float in [-19.5, -3.0, 13.5]:
		for x: float in [-20.0, -8.0, 8.0, 20.0]:
			var p := Vector3(x, 10.6, z)
			shade_xf.append(Transform3D(Basis(), p))
			cable_xf.append(Transform3D(Basis().scaled(Vector3(0.04, ROOF_LOW - 1.65 - p.y, 0.04)), p + Vector3(0, (ROOF_LOW - 1.65 - p.y) * 0.5, 0)))
	var shade := CylinderMesh.new()
	shade.top_radius = 0.25
	shade.bottom_radius = 0.9
	shade.height = 0.6
	shade.radial_segments = 16
	shade.material = _mat("shade", Color(1.0, 0.55, 0.74), 0.5)
	_multimesh(dressing, "PendantShades", shade, shade_xf, false)
	var bulb := SphereMesh.new()
	bulb.radius = 0.3
	bulb.height = 0.45
	bulb.radial_segments = 12
	bulb.rings = 6
	bulb.material = _mat("pendant_bulb", Color(1.0, 0.95, 0.8), 0.3, Color(1.0, 0.9, 0.7), 3.0)
	var bulb_xf: Array[Transform3D] = []
	for t in shade_xf:
		bulb_xf.append(Transform3D(Basis(), t.origin + Vector3(0, -0.3, 0)))
	_multimesh(dressing, "PendantBulbs", bulb, bulb_xf, false)
	_multimesh(dressing, "PendantCables", _box_mesh(Vector3.ONE, _mat("cable", Color(0.2, 0.16, 0.22), 0.5)), cable_xf, false)


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
# Exit: the Golden Wrapper portal and the floor arrows across the main bridge
# ---------------------------------------------------------------------------

func _build_exit() -> void:
	var portal: Node3D = (load("res://scenes/props/candy_portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	geo.add_child(portal)
	portal.position = PORTAL
	var lights := Node3D.new()
	lights.name = "ExitLights"
	level.add_child(lights)
	var arrow := _arrow_mesh()
	var steps := 9
	var a := STATION + Vector3(0, 0.0, -4.6)
	var b := PORTAL + Vector3(0, 0.0, 2.6)
	for k in steps:
		var t := float(k) / (steps - 1)
		var mi := MeshInstance3D.new()
		mi.name = "Arrow%02d" % k
		mi.mesh = arrow
		mi.position = a.lerp(b, t)
		var on_bridge := mi.position.z < RIVER_Z1 + 1.6 and mi.position.z > RIVER_Z0 - 1.6
		mi.position.y = 0.12 if on_bridge else 0.02
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lights.add_child(mi)
		_late(mi, "res://scripts/props/exit_light.gd", {"order": k})


## A flat chevron pointing north (-Z), 1.6 m wide.
func _arrow_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector2(-0.8, 0.35), Vector2(0.0, -0.45), Vector2(0.8, 0.35), Vector2(0.8, 0.75), Vector2(0.0, -0.05), Vector2(-0.8, 0.75)]
	for tri in [[0, 1, 4], [0, 4, 5], [1, 2, 3], [1, 3, 4]]:
		for idx in tri:
			var q: Vector2 = pts[idx]
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(q.x, 0.0, q.y))
	return st.commit()


# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(1.5, 0.1, 18.0)
	start.rotation.y = deg_to_rad(4.0)
	start.add_to_group("player_spawn", true)
	level.add_child(start)
	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	for d in DOORS:
		var c := _door_centre(d)
		var inward := _door_inward(d)
		var m := Marker3D.new()
		m.name = "Spawn%s" % d[0]
		m.position = c - inward * (WALL_THICK + RECESS - 1.6) + Vector3(0, 0.1, 0)
		m.rotation.y = atan2(-inward.x, -inward.z)
		m.add_to_group("enemy_spawn", true)
		spawns.add_child(m)


# ---------------------------------------------------------------------------
# The Sugar Rush twist: siren beacons on the walls and the controller
# ---------------------------------------------------------------------------

func _build_sugar_rush() -> void:
	var sirens := Node3D.new()
	sirens.name = "Sirens"
	level.add_child(sirens)
	var beacon := CylinderMesh.new()
	beacon.top_radius = 0.22
	beacon.bottom_radius = 0.3
	beacon.height = 0.5
	beacon.radial_segments = 12
	beacon.material = _mat("siren", Color(1.0, 0.3, 0.6), 0.3, Color(1.0, 0.3, 0.6), 2.2)
	var spots := [Vector3(-HALL_X + 0.6, 9.0, -4.0), Vector3(HALL_X - 0.6, 9.0, -20.0), Vector3(HALL_X - 0.6, 9.0, 12.0),
		Vector3(-HALL_X + 0.6, 9.0, 22.0), Vector3(-12.0, 9.0, HALL_Z1 - 0.6), Vector3(12.0, 9.0, HALL_Z0 + 0.6)]
	var i := 0
	for p: Vector3 in spots:
		var mi := MeshInstance3D.new()
		mi.name = "Beacon%d" % i
		mi.mesh = beacon
		mi.position = p
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sirens.add_child(mi)
		var l := _omni(sirens, "Siren%d" % i, p + (Vector3(0, 0, 0) - Vector3(p.x, 0, p.z)).normalized() * 1.2, Color(1.0, 0.3, 0.62), 0.0, 22.0)
		l.add_to_group("candy_siren", true)
		i += 1
	var rush := Node.new()
	rush.name = "SugarRush"
	level.add_child(rush)
	_late(rush, "res://scripts/props/candy_sugar_rush.gd", {})


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
	# 0.75 m off walls and props, so the largest zombies can reach every waypoint.
	mesh.agent_radius = 0.75
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 40.0
	mesh.region_min_size = 14.0
	# Walkable surfaces up to the mezzanine (keeps roofs and machine tops out).
	mesh.filter_baking_aabb = AABB(Vector3(-HALL_X - 9.0, -1.0, HALL_Z0 - 1.0), Vector3(HALL_X * 2.0 + 18.0, MEZZ_Y + 1.2, HALL_Z1 - HALL_Z0 + 10.0))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	region.navigation_mesh = _largest_island(mesh)
	print("build_candy_works: navmesh polygons = %d (dropped %d on islands)" % [region.navigation_mesh.get_polygon_count(),
		before - region.navigation_mesh.get_polygon_count()])


## Keeps only the largest connected set of polygons (the river bed, crate tops
## and machine housings leave unreachable islands).
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
# Ramps, stairs and railings
# ---------------------------------------------------------------------------

## Height of the solid kerbs along ramps and stairs, above the walking surface.
const KERB_H := 0.4


## A ramp or a flight of stairs from a top edge (centre `top`, at deck height
## `height`) running `run` metres down along `down_dir` to the floor. Stairs
## are drawn as steps over an invisible ramp (players and navmesh use the ramp).
func _slope(parent: Node3D, slope_name: String, top: Vector3, down_dir: Vector3, run: float, width: float, height: float,
		material: Material, stairs: bool) -> void:
	var frame := Node3D.new()
	frame.name = slope_name
	parent.add_child(frame)
	var x_axis := Vector3.UP.cross(down_dir).normalized()
	frame.transform = Transform3D(Basis(x_axis, Vector3.UP, down_dir), Vector3(top.x, top.y - height, top.z))
	var length := sqrt(run * run + height * height)
	var angle := atan2(height, run)
	var body := StaticBody3D.new()
	body.name = "Body"
	frame.add_child(body)
	var top_mid := Vector3(0, height * 0.5, run * 0.5)
	var thick := 0.4
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(width, thick, length + 0.25)
	shape.shape = box
	shape.position = top_mid - Vector3(0, cos(angle), sin(angle)) * thick * 0.5
	shape.rotation.x = angle
	body.add_child(shape)
	var trim := _mat("butter", Color(1.0, 0.86, 0.5), 0.5)
	if stairs:
		var steps := int(ceil(height / 0.2))
		var rise := height / steps
		var tread := run / steps
		for k in steps:
			var h := height - rise * (k + 1)
			var mi := MeshInstance3D.new()
			mi.name = "Step%d" % k
			mi.mesh = _box_mesh(Vector3(width, h + rise, tread + 0.02), material if k % 2 == 0 else trim)
			mi.position = Vector3(0, (h + rise) * 0.5, tread * (k + 0.5))
			body.add_child(mi)
	else:
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = _box_mesh(Vector3(width, thick, length + 0.25), material)
		mi.position = shape.position
		mi.rotation.x = angle
		body.add_child(mi)
	# Solid kerbs either side (striped candy rails ride on them).
	for side: float in [-1.0, 1.0]:
		var x := side * (width * 0.5 + 0.1)
		var kerb := StaticBody3D.new()
		kerb.name = "Kerb%s" % ("L" if side < 0 else "R")
		frame.add_child(kerb)
		var ks := CollisionShape3D.new()
		ks.name = "CollisionShape3D"
		var wedge := ConvexPolygonShape3D.new()
		var pts := PackedVector3Array()
		for xx: float in [x - 0.1, x + 0.1]:
			pts.append(Vector3(xx, 0.0, 0.0))
			pts.append(Vector3(xx, height + KERB_H, 0.0))
			pts.append(Vector3(xx, KERB_H, run))
			pts.append(Vector3(xx, 0.0, run))
		wedge.points = pts
		ks.shape = wedge
		kerb.add_child(ks)
		var s := MeshInstance3D.new()
		s.name = "Stringer"
		s.mesh = _box_mesh(Vector3(0.2, thick + KERB_H, length + 0.25), _mat("red_trim", Color(1.0, 0.36, 0.45), 0.4))
		s.position = top_mid + Vector3(x, KERB_H * 0.5 - 0.1, 0)
		s.rotation.x = angle
		frame.add_child(s)


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


## A run of candy-cane railing modules with one collision box (blocks walking).
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
	box.size = Vector3(length, 1.1, 0.3)
	shape.shape = box
	shape.position.y = 0.55
	body.add_child(shape)
	var module_len := 2.5
	var count := maxi(1, int(round(length / module_len)))
	var step := length / count
	var xf: Array[Transform3D] = []
	for i in count:
		xf.append(Transform3D(Basis().scaled(Vector3(step / module_len, 1, 1)), Vector3(-length * 0.5 + step * (i + 0.5), 0, 0)))
	_multimesh(body, "Modules", _model_mesh("candy_rail"), xf, true)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _multimesh(parent: Node3D, mm_name: String, mesh: Mesh, xforms: Array[Transform3D], shadows: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = mm_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


## The (single) mesh of art/models/<model>.glb, for MultiMesh batching.
func _model_mesh(model: String) -> Mesh:
	if _mesh_cache.has(model):
		return _mesh_cache[model]
	var source: Node3D = (load(MODELS + model + ".glb") as PackedScene).instantiate()
	var mesh: Mesh = (source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	source.free()
	_mesh_cache[model] = mesh
	return mesh


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


## World-projected texture (triplanar).
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


## Visible box with matching collision.
func _box(parent: Node3D, box_name: String, size: Vector3, pos: Vector3, material: Material) -> StaticBody3D:
	var body := _collider(parent, box_name, size, pos)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(size, material)
	body.add_child(mi)
	return body


## Box without collision (dressing on top of a collider).
func _visual_box(parent: Node3D, box_name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = box_name
	mi.mesh = _box_mesh(size, material)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Invisible player-only collider (physics layer 5: zombies, bullets and the
## navmesh ignore it): keeps the player off perches and out of gaps.
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


## Invisible upright cylinder collider for posts, poles and round machines.
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
