extends SceneTree
## Generator for World 13 "Pirate Cove" / level "Skull Harbor".
##
## Rebuilds scenes/levels/skull_harbor.tscn: a pirate harbour ride at sunset.
## Doubloon Quay (a cobbled stone wharf) round The Salty Chandler station; the
## galleon Barnacle Queen moored along its west side, boarded by two
## gangplanks (its main deck is the high ground); the Kraken Swing on the east
## side; the Rusty Anchor tavern and the waterfall under the north cliffs; the
## stilt-hut lagoon with rope bridges to the east; the jetty with the exit
## portal to the south; five zombie entrances (the sea cave, the smugglers'
## tunnel, the far jetty, the slipway and the bonded warehouse); the cliffs,
## sea stacks, the lighthouse on the rocks, moored sloops, lights, bunting
## and a baked navigation mesh.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_skull_harbor.gd
##
## Run it with a renderer (not --headless): the headless renderer keeps no
## MultiMesh instance data, so railings would save empty.
##
## NOTE: running this overwrites hand edits made to skull_harbor.tscn.
##
## Layout (metres, top view; -Z = north; every walkway at y 0 unless noted;
## the sea at y -1.3):
##   - Doubloon Quay x -20..26, z -20..16, the station at (0, 0, -2).
##   - West: the galleon, hull x -31..-21.5, z -19..15, main deck y 3.4
##     (z -12.2..6.2), gangplanks from x -12.8 at z -8.5 and z 2.
##   - North: cliffs; the sea cave (x -12), the waterfall basin (x -2), the
##     tavern (x 7..17) and the smugglers' tunnel (x 22).
##   - East: the Kraken Swing (x 15..21, z -7.5..11.5); boardwalks to the
##     stilt huts A (35, -12), B (43, 0), C (35, 12), rope bridges between
##     them and the far jetty east of hut B.
##   - South: the jetty (x -0.5..4.5, z 16..31) with the portal; the bonded
##     warehouse (x 13.5..24.5, z 16..25.5); the slipway (x -20..-11, z 16..23.5).

const OUT_PATH := "res://scenes/levels/skull_harbor.tscn"
const MODELS := "res://art/models/"
const TEXTURES := "res://art/textures/"
const SHADERS := "res://art/shaders/"

const STATION := Vector3(0.0, 0.0, -2.0)
const QUAY_T := 2.8                                  # quay slab depth (stone wall above the sea)
const SEA_Y := -1.3
const GALLEON := Vector3(-26.25, 0.0, -2.0)          # hull centre at quay level (bow north)
const SHIP_HALF_L := 17.0
const SHIP_HALF_BEAM := 4.75
const DECK_Y := 3.4
const FORE_END := -10.2                              # galleon-local y of the forecastle wall
const QUARTER_START := 8.2
const GANGWAYS := [-6.5, 4.0]                        # galleon-local y of the gangway openings
const GANGPLANK_W := 3.0
const GANGPLANK_FOOT := -12.8                        # x where the gangplanks meet the quay
const SWING := Vector3(18.0, 0.0, 2.0)
const TAVERN := Vector3(12.0, 0.0, -16.5)
const CAVE := Vector3(-12.0, 0.0, -20.4)
const TUNNEL := Vector3(22.0, 0.0, -20.4)
const WAREHOUSE := Vector3(19.0, 0.0, 20.5)
## Stilt huts: [deck centre, yaw]. A (door south) and B (door north) are
## walkable, joined by the rope bridge; C stands off in the lagoon.
const HUTS := [[Vector3(34.0, 0.0, -10.5), 0.0], [Vector3(34.0, 0.0, 8.5), 180.0], [Vector3(47.0, 0.0, 8.0), -90.0]]
const HUT_BODY_Z := 1.3                              # the hut's offset to the back of its deck
const LAGOON_WALKS := [-8.5, 6.5]                    # z of the boardwalks to huts A and B
const BRIDGE_X := 37.0
const PORTAL := Vector3(2.0, 0.0, 28.6)
const FAR_LANDING := Vector3(47.0, 0.0, -8.5)         # the far jetty's landing stage (6 x 6)
const LIGHTHOUSE := Vector3(-72.0, -2.2, 88.0)
const SUN_DIRECTION := Vector3(-0.6, 0.2, 0.77)      # toward the sun (south-west, low)
const PLAYER_WALL_H := 10.0
## Small props zombies path round but walk through (player-only after the bake).
const CLUTTER_BAKE_H := 2.0

var level: Node3D
var geo: Node3D          # collidable geometry (navmesh source)
var dressing: Node3D     # non-colliding scenery
var _materials := {}
var _boxes := {}
var _late_scripts: Array = []
var _light_count := 0
var _mesh_cache := {}
var _bunting: SurfaceTool
var _lines: SurfaceTool
var _bunting_count := 0
var _clutter: Array[CollisionShape3D] = []
## Rails baked as walls but player-only afterwards: zombies cut the corners at
## their ends and would stand pushing into them.
var _soft: Array[StaticBody3D] = []


func _initialize() -> void:
	level = Node3D.new()
	level.name = "SkullHarbor"
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
	_lines = SurfaceTool.new()
	_lines.begin(Mesh.PRIMITIVE_TRIANGLES)

	_build_quay()
	_build_galleon()
	_build_gangplanks()
	_build_north()
	_build_swing()
	_build_lagoon()
	_build_south()
	_build_station()
	_build_quay_props()
	_build_lights()
	_build_sea_and_cliffs()
	_build_backdrop()
	_build_exit()
	_build_markers()
	_finish_bunting()
	var barrage := Node3D.new()
	barrage.name = "Barrage"
	level.add_child(barrage)
	_late(barrage, "res://scripts/props/cove_barrage.gd", {})

	get_root().add_child(level)
	await process_frame
	_bake_navigation(nav)
	_release_clutter()
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
	print("build_skull_harbor: saved %s (error %d), %d omni lights" % [OUT_PATH, err, _light_count])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: sunset sky shader, low gold sun in the south-west, violet fill
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SHADERS + "cove_sky.gdshader")
	sky_mat.set_shader_parameter("sun_direction", SUN_DIRECTION.normalized())
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.68, 0.6, 0.8)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.4
	env.tonemap_exposure = 1.02
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.92, 0.62, 0.6)
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.14
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.looking_at(-SUN_DIRECTION.normalized(), Vector3.UP), Vector3(0, 30, 0))
	sun.light_color = Color(1.0, 0.76, 0.52)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_opacity = 0.7
	level.add_child(sun)

	# The violet evening sky from the north-east: lifts the faces the sun misses.
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.transform = Transform3D(Basis.looking_at(-Vector3(0.5, 0.7, -0.5).normalized(), Vector3.UP), Vector3(0, 30, 0))
	fill.light_color = Color(0.66, 0.62, 1.0)
	fill.light_energy = 0.38
	fill.shadow_enabled = false
	level.add_child(fill)


# ---------------------------------------------------------------------------
# Doubloon Quay: the stone wharf, its pads, railings and the player-only walls
# ---------------------------------------------------------------------------

func _quay_outline() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-20, -20), Vector2(26, -20), Vector2(26, 16), Vector2(-20, 16)])


## Openings in the railings: [centre (x, z), half width, kind]. Walkways are
## open to everyone; entrances get a player-only wall across the gap; "wedge"
## is where a gangplank's trestle closes the edge.
func _openings() -> Array:
	var out := [
		[Vector2(26.0, LAGOON_WALKS[0]), 1.5, &"open"],
		[Vector2(26.0, LAGOON_WALKS[1]), 1.5, &"open"],
		[Vector2(2.0, 16.0), 2.5, &"open"],
		[Vector2(WAREHOUSE.x, 16.0), 5.5, &"entrance"],
		[Vector2(-15.5, 16.0), 4.5, &"entrance"],
		[Vector2(CAVE.x, -20.0), 3.0, &"entrance"],
		[Vector2(TUNNEL.x, -20.0), 2.2, &"entrance"],
	]
	for gy in GANGWAYS:
		out.append([Vector2(-20.0, GALLEON.z + gy), GANGPLANK_W * 0.5 + 0.1, &"wedge"])
	# Hut decks: where the boardwalks, the rope bridge and the far jetty join.
	out.append_array([[Vector2(30.0, LAGOON_WALKS[0]), 1.5, &"open"], [Vector2(30.0, LAGOON_WALKS[1]), 1.5, &"open"],
		[Vector2(BRIDGE_X, -7.0), 1.3, &"open"], [Vector2(BRIDGE_X, 5.0), 1.3, &"open"], [Vector2(38.0, FAR_LANDING.z), 1.5, &"entrance"],
		[Vector2(FAR_LANDING.x - 3.0, FAR_LANDING.z), 1.5, &"open"]])
	return out


func _build_quay() -> void:
	var quay := Node3D.new()
	quay.name = "Quay"
	geo.add_child(quay)
	var stone := _textured("quay", "cove_quay", 0.3, 0.85)
	_deck(quay, "QuayDeck", _quay_outline(), 0.0, QUAY_T, stone)
	# A ring of darker setts and a compass rose round the station.
	var rose := MeshInstance3D.new()
	rose.name = "CompassRose"
	var disc := CylinderMesh.new()
	disc.top_radius = 6.5
	disc.bottom_radius = 6.5
	disc.height = 0.03
	disc.radial_segments = 48
	rose.mesh = disc
	rose.material_override = _mat("rose_base", Color(0.24, 0.42, 0.5), 0.7)
	rose.position = STATION + Vector3(0, 0.012, 0)
	rose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(rose)
	for k in 8:
		var point := MeshInstance3D.new()
		point.name = "RosePoint%d" % k
		var prism := PrismMesh.new()
		var long := k % 2 == 0
		prism.size = Vector3(1.3 if long else 0.9, 5.8 if long else 3.8, 0.02)
		point.mesh = prism
		point.material_override = _mat("rose_gold" if long else "rose_cream", Color(1.0, 0.76, 0.3) if long else Color(1.0, 0.94, 0.84), 0.5)
		point.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * k / 8.0
		var dir := Vector3(sin(a), 0, -cos(a))
		point.transform = Transform3D(Basis(dir.cross(Vector3.UP).normalized(), dir, Vector3.UP).orthonormalized(), STATION + dir * (prism.size.y * 0.5) + Vector3(0, 0.03, 0))
		dressing.add_child(point)
	var rim := MeshInstance3D.new()
	rim.name = "RoseRim"
	var torus := TorusMesh.new()
	torus.inner_radius = 6.45
	torus.outer_radius = 6.85
	torus.rings = 64
	torus.ring_segments = 6
	rim.mesh = torus
	rim.material_override = _mat("brass", Color(0.89, 0.66, 0.23), 0.4)
	rim.position = STATION + Vector3(0, 0.02, 0)
	rim.scale = Vector3(1, 0.2, 1)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(rim)
	# Railings along the waterfront edges; the north edge meets the cliffs.
	var o := _quay_outline()
	_edge_rails(quay, "QuayW", o[3], o[0], true)
	_edge_rails(quay, "QuayE", o[1], o[2], true)
	_edge_rails(quay, "QuayS", o[2], o[3], true)
	_cliff_foot(quay)
	# Mooring bollards on the south front, where the boats tie up.
	for x in [-8.0, 8.0, 12.0]:
		_prop(dressing, "cove_bollard", "BollardS%d" % int(x), Vector3(x, 0, 15.7), 0.0, Vector3(0.5, 0.9, 0.5))


## The north edge: a solid foot of rock under the cliffs, broken at the cave,
## the tunnel and the waterfall basin, with the player-only wall along it.
func _cliff_foot(parent: Node3D) -> void:
	var walls := _player_walls()
	var spans := [[-20.0, CAVE.x - 3.4], [CAVE.x + 3.4, -5.2], [1.2, TUNNEL.x - 2.9], [TUNNEL.x + 2.9, 26.0]]
	for s in spans:
		var x0: float = s[0]
		var x1: float = s[1]
		_collider(parent, "CliffFoot%d" % int(x0), Vector3(x1 - x0, 6.0, 1.2), Vector3((x0 + x1) * 0.5, 3.0, -20.6))
	_player_wall(walls, "NorthWall", Vector3(-20, 0, -20.0), Vector3(26, 0, -20.0), PLAYER_WALL_H)


## A deck slab from an outline (top at y, `depth` deep), with a fascia.
func _deck(parent: Node3D, deck_name: String, outline: PackedVector2Array, y: float, depth: float, top: StandardMaterial3D,
		fascia: StandardMaterial3D = null) -> void:
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
		var quad := [Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(b.x, y - depth, b.y), Vector3(a.x, y - depth, a.y)]
		for k in [0, 1, 2, 0, 2, 3]:
			side.set_normal(out)
			side.add_vertex(quad[k])
	side.commit(mesh)
	top.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wall := fascia if fascia else _textured("quay_wall", "cove_quay", 0.42, 0.9)
	mesh.surface_set_material(0, top)
	mesh.surface_set_material(1, wall)
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
		pts.append(Vector3(p.x, y - minf(depth, 1.0), p.y))
	convex.points = pts
	shape.shape = convex
	body.add_child(shape)


## Rope railings (and player-only walls) from a to b, broken at the openings.
func _edge_rails(parent: Node3D, prefix: String, a: Vector2, b: Vector2, walls: bool, y := 0.0) -> void:
	var holder := _player_walls()
	var k := 0
	for span in _edge_spans(a, b):
		var pa := Vector3(span[0].x, y, span[0].y)
		var pb := Vector3(span[1].x, y, span[1].y)
		_fence_run(parent, "%sRail%d" % [prefix, k], pa, pb)
		if walls:
			_player_wall(holder, "%sWall%d" % [prefix, k], pa, pb, PLAYER_WALL_H)
		k += 1
	if walls:
		for o in _openings():
			if o[2] == &"entrance" and _on_edge(a, b, o[0]):
				var d := (b - a).normalized()
				var c: Vector2 = o[0]
				var h: float = o[1]
				_player_wall(holder, "%sGate%d" % [prefix, int(c.x)], Vector3(c.x - d.x * h, y, c.y - d.y * h), Vector3(c.x + d.x * h, y, c.y + d.y * h), PLAYER_WALL_H)


func _on_edge(a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d := b - a
	var t := (c - a).dot(d) / d.length_squared()
	return t > 0.0 and t < 1.0 and (a + d * t).distance_to(c) < 0.6


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
# The galleon Barnacle Queen (its deck is the high ground)
# ---------------------------------------------------------------------------

## Half-beam of the hull at galleon-local y (bow -17, stern +17), as in
## art/blender/build_cove_galleon.py.
func _ship_plan(y: float) -> float:
	var s := (y + SHIP_HALF_L) / (2.0 * SHIP_HALF_L)
	if s < 0.35:
		return maxf(0.06, SHIP_HALF_BEAM * pow(sin(s / 0.35 * PI * 0.5), 0.8))
	if s > 0.8:
		return SHIP_HALF_BEAM * (1.0 - 0.28 * pow((s - 0.8) / 0.2, 1.5))
	return SHIP_HALF_BEAM


## A galleon-local point (x across, y along, z up; Blender axes) in the level.
## The ship is turned 180 degrees: its bow points north and its port side east.
func _ship(x: float, y: float, z: float) -> Vector3:
	return Vector3(GALLEON.x - x, z, GALLEON.z + y)


func _in_gangway(y: float) -> bool:
	for g in GANGWAYS:
		if absf(y - g) < GANGPLANK_W * 0.5 - 0.01:
			return true
	return false


func _build_galleon() -> void:
	var ship := Node3D.new()
	ship.name = "Galleon"
	geo.add_child(ship)
	var model := _prop(dressing, "cove_galleon", "BarnacleQueen", GALLEON, 180.0, Vector3(9, 20, 34))
	model.name = "BarnacleQueen"
	# The main deck slab between the castles.
	var body := StaticBody3D.new()
	body.name = "MainDeck"
	ship.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var convex := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	var ys: Array[float] = []
	var y := FORE_END
	while y < QUARTER_START:
		ys.append(y)
		y += 1.0
	ys.append(QUARTER_START)
	for yy in ys:
		var half := _ship_plan(yy) * 0.94 - 0.16
		for s in [-1.0, 1.0]:
			pts.append(_ship(s * half, yy, DECK_Y))
			pts.append(_ship(s * half, yy, DECK_Y - 0.5))
	convex.points = pts
	shape.shape = convex
	body.add_child(shape)
	# Bulwarks along both sides (open at the port gangways) and the player walls.
	var walls := _player_walls()
	for side in [-1.0, 1.0]:
		y = FORE_END
		while y < QUARTER_START - 0.01:
			var y1 := minf(y + 1.0, QUARTER_START)
			var mid := (y + y1) * 0.5
			if not (side < 0.0 and _in_gangway(mid)):
				var a := _ship(side * (_ship_plan(y) * 0.94 - 0.05), y, DECK_Y)
				var b := _ship(side * (_ship_plan(y1) * 0.94 - 0.05), y1, DECK_Y)
				_wall_segment(ship, "Bulwark%d_%d" % [int(side), int(y * 10)], a, b, 1.15, 0.3)
				_player_wall(walls, "ShipWall%d_%d" % [int(side), int(y * 10)], a, b, 6.0)
			y = y1
	# The forecastle and the quarterdeck: solid blocks (no way up).
	var fore_half := _ship_plan(FORE_END) * 0.94
	var fore_c := _ship(0.0, (-SHIP_HALF_L + FORE_END) * 0.5, 0.0)
	_collider(ship, "Forecastle", Vector3(fore_half * 2.0, 3.0, FORE_END + SHIP_HALF_L), fore_c + Vector3(0, DECK_Y + 1.5, -0.1))
	_player_block(ship, "ForecastleCap", Vector3(fore_half * 2.0, 6.0, FORE_END + SHIP_HALF_L), fore_c + Vector3(0, DECK_Y + 5.5, -0.1))
	var q_half := SHIP_HALF_BEAM * 0.94
	var q_c := _ship(0.0, (QUARTER_START + SHIP_HALF_L) * 0.5, 0.0)
	_collider(ship, "Quarterdeck", Vector3(q_half * 2.0, 3.6, SHIP_HALF_L - QUARTER_START), q_c + Vector3(0, DECK_Y + 1.8, 0.1))
	_player_block(ship, "QuarterdeckCap", Vector3(q_half * 2.0, 6.0, SHIP_HALF_L - QUARTER_START), q_c + Vector3(0, DECK_Y + 6.6, 0.1))
	# Masts and the capstan on the main deck.
	_post(ship, "ForeMast", 0.45, 4.0, _ship(0.0, -7.0, DECK_Y))
	_post(ship, "MainMast", 0.45, 4.0, _ship(0.0, 0.5, DECK_Y))
	_post(ship, "Capstan", 0.58, 1.05, _ship(0.0, 6.4, DECK_Y))
	# Fenders on the port side, gun-port markers for the Broadside twist.
	for k in 7:
		var gy := -8.4 + k * 2.6
		if _in_gangway(gy):
			continue
		var m := Marker3D.new()
		m.name = "GunPort%d" % k
		m.position = _ship(-(_ship_plan(gy) + 0.73), gy, 2.5)
		m.add_to_group("cove_gunport", true)
		ship.add_child(m)
	for k in 4:
		var fy := -13.0 + k * 8.0
		var fender := MeshInstance3D.new()
		fender.name = "Fender%d" % k
		var cap := CapsuleMesh.new()
		cap.radius = 0.32
		cap.height = 1.3
		cap.material = _mat("rope", Color(0.89, 0.77, 0.54), 0.9)
		fender.mesh = cap
		fender.position = _ship(-(_ship_plan(fy) + 0.25), fy, 0.4)
		dressing.add_child(fender)


## Two gangplanks from the quay up to the gangway openings: a sloped plank
## deck on a timber trestle (solid underneath), rope rails along both sides.
func _build_gangplanks() -> void:
	var g := Node3D.new()
	g.name = "Gangplanks"
	geo.add_child(g)
	var walls := _player_walls()
	var planks := _textured("planks", "cove_planks", 0.45, 0.8)
	var deck_x := GALLEON.x + _ship_plan(0.0) * 0.94 - 0.4
	for k in GANGWAYS.size():
		var z: float = GALLEON.z + GANGWAYS[k]
		var top := Vector3(-21.0, DECK_Y, z)
		var foot := Vector3(GANGPLANK_FOOT, 0.0, z)
		_ramp(g, "Gangplank%d" % k, top, foot, GANGPLANK_W, planks)
		# Landing plank across the gap onto the deck.
		_box(g, "Landing%d" % k, Vector3(top.x - deck_x, 0.3, GANGPLANK_W), Vector3((top.x + deck_x) * 0.5, DECK_Y - 0.15, z), planks)
		for s in [-1.0, 1.0]:
			var side_z: float = z + s * (GANGPLANK_W * 0.5 + 0.1)
			_player_wall(walls, "GangplankWall%d_%d" % [k, int(s)], Vector3(foot.x, 0.0, side_z), Vector3(deck_x, 0.0, side_z), 6.0 + DECK_Y)
		# Trestle legs under the part over the water.
		for s in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			leg.name = "Trestle%d_%d" % [k, int(s)]
			leg.mesh = _box_mesh(Vector3(0.3, 4.6, 0.3), _mat("timber", Color(0.48, 0.27, 0.16), 0.8))
			leg.position = Vector3(-20.6, DECK_Y - 2.6, z + s * (GANGPLANK_W * 0.5 - 0.2))
			dressing.add_child(leg)


## A sloped walkway from `top` down to `bottom` (along X): a sloped collider,
## a solid wedge under it on the quay, plank deck and side boards, rope rails.
func _ramp(parent: Node3D, ramp_name: String, top: Vector3, bottom: Vector3, width: float, planks: Material) -> void:
	var run := bottom.x - top.x
	var rise := top.y - bottom.y
	var length := absf(run)
	var angle := atan2(rise, length)
	var body := StaticBody3D.new()
	body.name = ramp_name
	parent.add_child(body)
	body.position = (top + bottom) * 0.5
	var dir := signf(run)
	# Walking surface: a thin slab along the slope.
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(sqrt(length * length + rise * rise) + 0.2, 0.3, width)
	shape.shape = box
	shape.rotation.z = -angle * dir
	shape.position = Vector3(0, -0.15 / cos(angle), 0)
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	mi.name = "Deck"
	var bm := BoxMesh.new()
	bm.size = box.size
	bm.material = planks
	mi.mesh = bm
	mi.rotation.z = -angle * dir
	mi.position = shape.position
	body.add_child(mi)
	# The wedge under it, down to the quay (only where it stands on the quay).
	var wedge := CollisionShape3D.new()
	wedge.name = "Wedge"
	var convex := ConvexPolygonShape3D.new()
	var quay_x := -20.0
	var t := (quay_x - bottom.x) / (top.x - bottom.x)
	var h := rise * t
	var pts := PackedVector3Array()
	for zz in [-width * 0.5, width * 0.5]:
		pts.append(Vector3(bottom.x, 0.0, zz) - body.position)
		pts.append(Vector3(quay_x, 0.0, zz) - body.position)
		pts.append(Vector3(quay_x, h - 0.25, zz) - body.position)
	convex.points = pts
	wedge.shape = convex
	body.add_child(wedge)
	var side_mat := _mat("timber", Color(0.48, 0.27, 0.16), 0.8)
	var side_mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zz in [-width * 0.5 - 0.02, width * 0.5 + 0.02]:
		var n := Vector3(0, 0, signf(zz))
		var tri := [Vector3(bottom.x, 0.02, zz), Vector3(quay_x, 0.02, zz), Vector3(quay_x, h - 0.05, zz)]
		for v in tri:
			st.set_normal(n)
			st.add_vertex(v - body.position)
	st.commit(side_mesh)
	side_mesh.surface_set_material(0, side_mat)
	side_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sides := MeshInstance3D.new()
	sides.name = "Sides"
	sides.mesh = side_mesh
	body.add_child(sides)
	# Rope rails on posts along both sides.
	for s in [-1.0, 1.0]:
		var rail := StaticBody3D.new()
		rail.name = "%sRail%d" % [ramp_name, int(s)]
		parent.add_child(rail)
		rail.position = body.position + Vector3(0, 0, s * (width * 0.5 + 0.1))
		var rs := CollisionShape3D.new()
		rs.name = "CollisionShape3D"
		var rb := BoxShape3D.new()
		rb.size = Vector3(sqrt(length * length + rise * rise), 1.15, 0.2)
		rs.shape = rb
		rs.rotation.z = -angle * dir
		rs.position.y = 0.575 / cos(angle)
		rail.add_child(rs)
		var row := _module_row("Modules", "cove_rail", rb.size.x, 2.5)
		row.rotation.z = -angle * dir
		rail.add_child(row)
		_soft.append(rail)


# ---------------------------------------------------------------------------
# North: the sea cave, the waterfall and its basin, the tavern, the tunnel
# ---------------------------------------------------------------------------

func _build_north() -> void:
	var n := Node3D.new()
	n.name = "North"
	geo.add_child(n)
	var planks := _textured("planks", "cove_planks", 0.45, 0.8)
	var sand := _textured("sand", "cove_sand", 0.25, 0.95)
	# 1. The sea cave: a dark vault in the cliff with a plank floor.
	_prop(dressing, "cove_cave", "SeaCave", CAVE, 0.0, Vector3(8, 6, 10))
	_box(n, "CaveFloor", Vector3(6.2, 0.4, 10.4), Vector3(CAVE.x, -0.2, CAVE.z - 5.0), sand)
	_collider(n, "CaveWallW", Vector3(0.6, 6.0, 10.4), Vector3(CAVE.x - 3.4, 3.0, CAVE.z - 5.0))
	_collider(n, "CaveWallE", Vector3(0.6, 6.0, 10.4), Vector3(CAVE.x + 3.4, 3.0, CAVE.z - 5.0))
	_collider(n, "CaveBack", Vector3(7.0, 6.0, 0.6), Vector3(CAVE.x, 3.0, CAVE.z - 10.2))
	# 2. The waterfall: a curtain down the cliff into a rock-rimmed basin.
	var basin := Vector3(-2.0, 0.0, -18.6)
	_collider(n, "Basin", Vector3(6.4, 0.7, 3.2), basin + Vector3(0, 0.35, -0.2))
	_player_block(n, "BasinCap", Vector3(6.4, PLAYER_WALL_H, 3.2), basin + Vector3(0, 0.7 + PLAYER_WALL_H * 0.5, -0.2))
	var rim := _mat("rock", Color(0.79, 0.54, 0.37), 0.9)
	for k in 5:
		_visual_box(dressing, "BasinRim%d" % k, [Vector3(6.4, 0.7, 0.5), Vector3(0.5, 0.7, 3.0), Vector3(0.5, 0.7, 3.0), Vector3(6.4, 0.7, 0.5), Vector3(6.2, 0.1, 3.0)][k],
			basin + [Vector3(0, 0.35, 1.2), Vector3(-2.95, 0.35, -0.2), Vector3(2.95, 0.35, -0.2), Vector3(0, 0.35, -1.6), Vector3(0, -0.05, -0.2)][k], rim)
	var pool := MeshInstance3D.new()
	pool.name = "BasinWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(5.4, 2.4)
	pool.mesh = plane
	pool.material_override = _sea_material()
	pool.position = basin + Vector3(0, 0.45, -0.2)
	dressing.add_child(pool)
	var fall := MeshInstance3D.new()
	fall.name = "Waterfall"
	var quad := QuadMesh.new()
	quad.size = Vector2(3.6, 14.0)
	fall.mesh = quad
	var fm := ShaderMaterial.new()
	fm.shader = load(SHADERS + "jungle_waterfall.gdshader")
	fm.set_shader_parameter("water", Color(0.62, 0.92, 0.9))
	fm.set_shader_parameter("rate", 1.3)
	fall.material_override = fm
	fall.position = basin + Vector3(0, 7.45, -1.25)
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(fall)
	var foam := MeshInstance3D.new()
	foam.name = "WaterfallFoam"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 0.8
	sphere.radial_segments = 16
	sphere.rings = 6
	sphere.material = _mat("foam", Color(0.95, 1.0, 0.98), 0.4, Color(0.8, 0.95, 0.95), 0.25)
	foam.mesh = sphere
	foam.position = basin + Vector3(0, 0.45, -1.0)
	foam.scale = Vector3(2.0, 0.7, 1.0)
	dressing.add_child(foam)
	_late(foam, "res://scripts/props/ambient_motion.gd", {"bob_height": 0.08, "bob_seconds": 0.9})
	# 3. The Rusty Anchor tavern (solid; its veranda is part of the quay).
	_prop(dressing, "cove_tavern", "RustyAnchor", TAVERN, 0.0, Vector3(10, 10, 7))
	_collider(n, "TavernBody", Vector3(10.6, 7.0, 7.6), TAVERN + Vector3(0, 3.5, 0))
	_player_block(n, "TavernRoof", Vector3(11.0, 6.0, 9.0), TAVERN + Vector3(0, 9.5, 0))
	for k in 5:
		var px := TAVERN.x - 4.8 + 9.6 * k / 4.0
		_post(n, "VerandaPost%d" % k, 0.2, 3.0, Vector3(px, 0.0, TAVERN.z + 3.55 + 2.6))
	_player_block(n, "VerandaCap", Vector3(10.6, 4.0, 3.2), TAVERN + Vector3(0, 5.0, 4.9))
	_clutter_prop(n, "cove_barrels", "VerandaBarrels", TAVERN + Vector3(-3.0, 0.0, 4.9), 30.0, Vector3(1.9, 1.6, 1.6))
	_clutter_prop(n, "cove_crates", "VerandaCrates", TAVERN + Vector3(-6.4, 0.0, -1.5), -15.0, Vector3(2.2, 2.0, 1.6))
	# 4. The smugglers' tunnel.
	_prop(dressing, "cove_tunnel", "SmugglersTunnel", TUNNEL, 0.0, Vector3(6, 5, 8))
	_box(n, "TunnelFloor", Vector3(5.2, 0.4, 8.4), Vector3(TUNNEL.x, -0.2, TUNNEL.z - 4.0), planks)
	_collider(n, "TunnelWallW", Vector3(0.6, 5.0, 8.4), Vector3(TUNNEL.x - 2.6, 2.5, TUNNEL.z - 4.0))
	_collider(n, "TunnelWallE", Vector3(0.6, 5.0, 8.4), Vector3(TUNNEL.x + 2.6, 2.5, TUNNEL.z - 4.0))
	_collider(n, "TunnelBack", Vector3(6.0, 5.0, 0.6), Vector3(TUNNEL.x, 2.5, TUNNEL.z - 8.2))


# ---------------------------------------------------------------------------
# East: the Kraken Swing
# ---------------------------------------------------------------------------

func _build_swing() -> void:
	var s := Node3D.new()
	s.name = "KrakenSwing"
	geo.add_child(s)
	var base := MeshInstance3D.new()
	base.name = "SwingBase"
	base.mesh = _glb_mesh("cove_swing", "Base")
	base.position = SWING
	dressing.add_child(base)
	var boat := MeshInstance3D.new()
	boat.name = "SwingBoat"
	boat.mesh = _glb_mesh("cove_swing", "Boat")
	boat.position = SWING + Vector3(0, 8.2, 0)
	dressing.add_child(boat)
	_late(boat, "res://scripts/props/cove_swing.gd", {"amplitude_degrees": 40.0, "period": 6.5})
	# A rope fence round the ride (the boat swings inside it).
	var r := Rect2(SWING.x - 3.4, SWING.z - 9.5, 6.8, 19.0)
	var pts := [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]
	var walls := _player_walls()
	for k in 4:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[(k + 1) % 4]
		_fence_run(s, "SwingFence%d" % k, Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y))
		_player_wall(walls, "SwingWall%d" % k, Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), PLAYER_WALL_H)
	for e in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			_post(s, "SwingLeg%d%d" % [int(e), int(side)], 0.4, 8.0, SWING + Vector3(side * 2.3, 0, e * 4.6))


# ---------------------------------------------------------------------------
# The lagoon: stilt huts, boardwalks, rope bridges and the far jetty
# ---------------------------------------------------------------------------

func _build_lagoon() -> void:
	var l := Node3D.new()
	l.name = "Lagoon"
	geo.add_child(l)
	var planks := _textured("planks", "cove_planks", 0.45, 0.8)
	var timber := _mat("timber", Color(0.48, 0.27, 0.16), 0.8)
	var names := ["HutA", "HutB", "HutC"]
	for k in HUTS.size():
		var c: Vector3 = HUTS[k][0]
		var yaw: float = HUTS[k][1]
		var turn := Basis(Vector3.UP, deg_to_rad(yaw))
		_prop(dressing, "cove_hut", names[k], c, yaw, Vector3(8, 5, 7))
		var deck := _collider(l, names[k] + "Deck", Vector3(8.0, 0.4, 7.0), c + Vector3(0, -0.2, 0))
		deck.rotation.y = deg_to_rad(yaw)
		var body := _collider(l, names[k] + "Body", Vector3(4.4, 2.8, 3.8), c + turn * Vector3(0, 1.4, -HUT_BODY_Z))
		body.rotation.y = deg_to_rad(yaw)
		_player_block(l, names[k] + "Roof", Vector3(6.0, 3.0, 6.0), c + turn * Vector3(0, 4.2, -HUT_BODY_Z), deg_to_rad(yaw))
		var net := _collider(l, names[k] + "Net", Vector3(0.3, 2.2, 2.8), c + turn * Vector3(3.4, 1.1, -1.75))
		net.rotation.y = deg_to_rad(yaw)
		var o := PackedVector2Array()
		for corner in [Vector3(-4, 0, -3.5), Vector3(4, 0, -3.5), Vector3(4, 0, 3.5), Vector3(-4, 0, 3.5)]:
			var w: Vector3 = c + turn * corner
			o.append(Vector2(w.x, w.z))
		for e in 4:
			_edge_rails(l, "%sEdge%d" % [names[k], e], o[e], o[(e + 1) % 4], true)
	# Boardwalks from the quay to the front walks of huts A and B.
	for entry in [["BoardwalkA", LAGOON_WALKS[0]], ["BoardwalkB", LAGOON_WALKS[1]]]:
		var z: float = entry[1]
		_walkway(l, entry[0], Vector3(26.0, 0, z), Vector3(30.0, 0, z), 3.0, planks, timber, false)
	# The rope bridge between them, and the far jetty east of hut A.
	_walkway(l, "RopeBridge", Vector3(BRIDGE_X, 0, -7.0), Vector3(BRIDGE_X, 0, 5.0), 2.4, planks, timber, true)
	var f := FAR_LANDING
	_walkway(l, "FarJetty", Vector3(38.0, 0, f.z), f - Vector3(3.0, 0, 0), 3.0, planks, timber, false)
	var stage := PackedVector2Array([Vector2(f.x - 3.0, f.z - 3.0), Vector2(f.x + 3.0, f.z - 3.0), Vector2(f.x + 3.0, f.z + 3.0), Vector2(f.x - 3.0, f.z + 3.0)])
	_deck(l, "FarLanding", stage, 0.0, 0.5, planks, timber)
	for e in 4:
		_edge_rails(l, "FarLandingEdge%d" % e, stage[e], stage[(e + 1) % 4], true)
	var boat := _prop(dressing, "cove_rowboat", "JettyBoat", f + Vector3(1.0, SEA_Y - 0.15, -4.4), 90.0, Vector3(4, 1, 1.5))
	_late(boat, "res://scripts/props/ambient_motion.gd", {"bob_height": 0.1, "bob_seconds": 3.4, "rock_degrees": 2.5})
	_lamp(l, "JettyLamp", f + Vector3(2.4, 0, 2.4), 0.0)


## A plank walkway from a to b (width w) at y 0: a box collider, a plank deck,
## stilts or rope hand lines, railings and player walls along both sides.
## `rope` makes it a rope bridge (bridge modules).
func _walkway(parent: Node3D, walk_name: String, a: Vector3, b: Vector3, w: float, planks: Material, timber: Material, rope: bool) -> void:
	var d := b - a
	var length := d.length()
	var yaw := atan2(-d.z, d.x)
	var body := _collider(parent, walk_name, Vector3(length + 0.6, 0.4, w), (a + b) * 0.5 + Vector3(0, -0.2, 0))
	body.rotation.y = yaw
	if rope:
		var row := _module_row("Planks", "cove_bridge", length + 0.4, 1.0)
		row.position = Vector3(0, 0.2, 0)
		row.scale = Vector3(1, 1, w / 2.1)
		body.add_child(row)
	else:
		var mi := MeshInstance3D.new()
		mi.name = "Deck"
		mi.mesh = _box_mesh(Vector3(length + 0.6, 0.3, w), planks)
		mi.position = Vector3(0, 0.05, 0)
		body.add_child(mi)
		var n := int(length / 2.0) + 1
		for k in n + 1:
			for s in [-1.0, 1.0]:
				var stilt := MeshInstance3D.new()
				stilt.name = "Stilt%d_%d" % [k, int(s)]
				stilt.mesh = _box_mesh(Vector3(0.25, 3.2, 0.25), timber)
				stilt.position = Vector3(-length * 0.5 + length * k / n, -1.6, s * (w * 0.5 - 0.2))
				body.add_child(stilt)
	var dir := d / length
	var side := Vector3(-dir.z, 0, dir.x)
	var walls := _player_walls()
	for s in [-1.0, 1.0]:
		var pa: Vector3 = a + side * s * (w * 0.5 + 0.1)
		var pb: Vector3 = b + side * s * (w * 0.5 + 0.1)
		if rope:
			var c := _collider(parent, "%sSide%d" % [walk_name, int(s)], Vector3(length + 0.4, 1.15, 0.2), (pa + pb) * 0.5 + Vector3(0, 0.575, 0))
			c.rotation.y = yaw
			_soft.append(c)
		else:
			_fence_run(parent, "%sRail%d" % [walk_name, int(s)], pa, pb)
			_soft.append(parent.get_node("%sRail%d" % [walk_name, int(s)]) as StaticBody3D)
		_player_wall(walls, "%sWall%d" % [walk_name, int(s)], pa, pb, PLAYER_WALL_H)


# ---------------------------------------------------------------------------
# South: the jetty, the bonded warehouse, the slipway, the moored sloops
# ---------------------------------------------------------------------------

func _build_south() -> void:
	var s := Node3D.new()
	s.name = "South"
	geo.add_child(s)
	var planks := _textured("planks", "cove_planks", 0.45, 0.8)
	var timber := _mat("timber", Color(0.48, 0.27, 0.16), 0.8)
	var sand := _textured("sand", "cove_sand", 0.25, 0.95)
	# The jetty to the portal.
	var jetty := PackedVector2Array([Vector2(-0.5, 16.0), Vector2(4.5, 16.0), Vector2(4.5, 31.0), Vector2(-0.5, 31.0)])
	_deck(s, "Jetty", jetty, 0.0, 0.5, planks, timber)
	for k in 6:
		for e in [-1.0, 1.0]:
			var pile := MeshInstance3D.new()
			pile.name = "Pile%d_%d" % [k, int(e)]
			pile.mesh = _box_mesh(Vector3(0.35, 3.0, 0.35), timber)
			pile.position = Vector3(2.0 + e * 2.3, -1.9, 17.5 + k * 2.6)
			dressing.add_child(pile)
	_edge_rails(s, "JettyW", Vector2(-0.5, 16.0), Vector2(-0.5, 31.0), true)
	_edge_rails(s, "JettyE", Vector2(4.5, 31.0), Vector2(4.5, 16.0), true)
	_edge_rails(s, "JettyEnd", Vector2(4.5, 31.0), Vector2(-0.5, 31.0), true)
	# The bonded warehouse (zombies come out of its open doors).
	var pad := PackedVector2Array([Vector2(13.5, 16.0), Vector2(24.5, 16.0), Vector2(24.5, 25.5), Vector2(13.5, 25.5)])
	_deck(s, "WarehousePad", pad, 0.0, QUAY_T, _textured("quay", "cove_quay", 0.3, 0.85))
	_prop(dressing, "cove_warehouse", "BondedWarehouse", WAREHOUSE, 180.0, Vector3(11, 8, 9))
	var w := WAREHOUSE
	_collider(s, "WarehouseBack", Vector3(11.0, 6.0, 0.5), w + Vector3(0, 3.0, 4.5))
	_collider(s, "WarehouseW", Vector3(0.5, 6.0, 9.0), w + Vector3(-5.5, 3.0, 0))
	_collider(s, "WarehouseE", Vector3(0.5, 6.0, 9.0), w + Vector3(5.5, 3.0, 0))
	_collider(s, "WarehouseFrontW", Vector3(3.3, 6.0, 0.5), w + Vector3(-3.85, 3.0, -4.5))
	_collider(s, "WarehouseFrontE", Vector3(3.3, 6.0, 0.5), w + Vector3(3.85, 3.0, -4.5))
	_collider(s, "WarehouseLintel", Vector3(4.4, 1.8, 0.5), w + Vector3(0, 5.1, -4.5))
	_collider(s, "WarehouseCratesE", Vector3(2.0, 2.4, 2.2), w + Vector3(3.7, 1.2, 2.9))
	_collider(s, "WarehouseCratesW", Vector3(1.3, 2.4, 2.5), w + Vector3(-3.9, 1.2, 2.15))
	_collider(s, "WarehouseKegs", Vector3(1.7, 1.0, 1.9), w + Vector3(3.8, 0.5, -0.5))
	_player_block(s, "WarehouseRoof", Vector3(12.0, 4.0, 10.0), w + Vector3(0, 8.0, 0))
	# The slipway: a sandy landing with beached rowboats.
	var slip := PackedVector2Array([Vector2(-20.0, 16.0), Vector2(-11.0, 16.0), Vector2(-11.0, 23.5), Vector2(-20.0, 23.5)])
	_deck(s, "Slipway", slip, 0.0, QUAY_T, sand, _mat("rock", Color(0.79, 0.54, 0.37), 0.9))
	var beach := MeshInstance3D.new()
	beach.name = "Beach"
	var bmesh := PrismMesh.new()
	bmesh.left_to_right = 0.0
	bmesh.size = Vector3(4.0, 1.6, 9.0)
	bmesh.material = sand
	beach.mesh = bmesh
	beach.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-15.5, -0.8, 25.5))
	dressing.add_child(beach)
	_edge_rails(s, "SlipW", Vector2(-20.0, 16.0), Vector2(-20.0, 23.5), true)
	_edge_rails(s, "SlipE", Vector2(-11.0, 23.5), Vector2(-11.0, 16.0), true)
	_edge_rails(s, "SlipS", Vector2(-11.0, 23.5), Vector2(-20.0, 23.5), true)
	_clutter_prop(s, "cove_rowboat", "BeachedBoatA", Vector3(-18.6, 0.0, 19.8), 8.0, Vector3(1.6, 1.0, 4.2))
	_clutter_prop(s, "cove_rowboat", "BeachedBoatB", Vector3(-12.4, 0.0, 20.8), -12.0, Vector3(1.6, 1.0, 4.2))
	# Sloops moored off the jetty, bobbing.
	for entry in [["SloopW", Vector3(-7.0, SEA_Y - 0.3, 25.0), 82.0], ["SloopE", Vector3(10.5, SEA_Y - 0.3, 27.5), -95.0],
			["SloopFar", Vector3(-30.0, SEA_Y - 0.3, 40.0), 30.0]]:
		var sl := _prop(dressing, "cove_sloop", entry[0], entry[1], entry[2], Vector3(4, 12, 11))
		_late(sl, "res://scripts/props/ambient_motion.gd", {"bob_height": 0.18, "bob_seconds": 4.6, "rock_degrees": 2.0})
	for entry in [["RowboatA", Vector3(6.6, SEA_Y - 0.15, 19.0), 10.0], ["RowboatB", Vector3(-3.0, SEA_Y - 0.15, 20.5), -20.0]]:
		var rb := _prop(dressing, "cove_rowboat", entry[0], entry[1], entry[2], Vector3(1.5, 1, 4))
		_late(rb, "res://scripts/props/ambient_motion.gd", {"bob_height": 0.1, "bob_seconds": 3.2, "rock_degrees": 3.0})


# ---------------------------------------------------------------------------
# Loadout station: The Salty Chandler
# ---------------------------------------------------------------------------

func _build_station() -> void:
	var station: Node3D = (load("res://scenes/props/cove_station.tscn") as PackedScene).instantiate()
	station.name = "Station"
	geo.add_child(station)
	station.position = STATION
	station.rotation.y = deg_to_rad(8.0)


# ---------------------------------------------------------------------------
# Quay dressing: treasure, cannons, crates, barrels, the stall, lamps, bunting
# ---------------------------------------------------------------------------

func _build_quay_props() -> void:
	var p := Node3D.new()
	p.name = "Props"
	geo.add_child(p)
	_clutter_prop(p, "cove_treasure", "Treasure", Vector3(-7.0, 0, 7.0), 25.0, Vector3(1.6, 1.2, 1.2))
	for entry in [["CannonS1", Vector3(-6.0, 0, 13.8), 0.0], ["CannonS2", Vector3(9.0, 0, 13.8), 0.0], ["CannonN", Vector3(-6.5, 0, -14.5), 160.0],
			["CannonW", Vector3(-17.8, 0, -1.5), 90.0]]:
		_clutter_prop(p, "cove_cannon", entry[0], entry[1], entry[2], Vector3(1.1, 1.3, 2.3))
	for entry in [["CratesA", Vector3(-11.0, 0, -11.5), 15.0], ["CratesB", Vector3(7.5, 0, 6.5), -20.0], ["CratesC", Vector3(-15.0, 0, 10.5), 70.0],
			["CratesD", Vector3(-17.4, 0, 6.5), 95.0]]:
		_clutter_prop(p, "cove_crates", entry[0], entry[1], entry[2], Vector3(2.2, 2.0, 1.6))
	for entry in [["BarrelsA", Vector3(-3.5, 0, -11.0), 40.0], ["BarrelsB", Vector3(-13.0, 0, 13.6), -30.0], ["BarrelsC", Vector3(-17.0, 0, -17.0), 0.0],
			["BarrelsD", Vector3(8.5, 0, -6.5), 100.0]]:
		_clutter_prop(p, "cove_barrels", entry[0], entry[1], entry[2], Vector3(1.9, 1.6, 1.6))
	_clutter_prop(p, "cove_stall", "ParrotStall", Vector3(-9.5, 0, 1.0), 90.0, Vector3(2.9, 2.6, 1.2))
	_prop(dressing, "cove_flagpole", "Flagpole", Vector3(5.5, 0, -13.0), 0.0, Vector3(0.4, 9, 0.4))
	_post(p, "FlagpolePost", 0.4, 3.0, Vector3(5.5, 0, -13.0))
	_player_block(p, "FlagpoleCap", Vector3(1.0, 6.0, 1.0), Vector3(5.5, 6.0, -13.0))
	var lamps := [Vector3(-19.2, 0, -12.0), Vector3(-19.2, 0, 10.5), Vector3(-4.0, 0, 15.3), Vector3(8.0, 0, 15.3), Vector3(25.3, 0, -4.0),
		Vector3(25.3, 0, 6.0), Vector3(-15.0, 0, -19.75), Vector3(2.4, 0, -19.75)]
	var yaws := [90.0, 90.0, 180.0, 180.0, -90.0, -90.0, 0.0, 0.0]
	for k in lamps.size():
		_lamp(p, "Lamp%d" % k, lamps[k], yaws[k])
	_prop(dressing, "cove_palm", "PalmSlip", Vector3(-19.0, 0, 22.5), 200.0, Vector3(1, 8, 1))
	_prop(dressing, "cove_palm", "PalmSE", Vector3(25.2, 0, 15.0), -60.0, Vector3(1, 8, 1))
	_post(p, "PalmSEPost", 0.3, 4.0, Vector3(25.2, 0, 15.0))
	# Bunting: pennant strings from the flagpole and the station's mast.
	var mast_top := STATION + Vector3(0, 10.3, 0)
	_string_bunting(Vector3(5.5, 8.6, -13.0), mast_top, 0.9)
	_string_bunting(mast_top, Vector3(-19.2, 3.4, 10.5), 1.4)
	_string_bunting(mast_top, Vector3(8.0, 3.4, 15.3), 1.2)
	_string_bunting(Vector3(5.5, 8.6, -13.0), Vector3(-15.0, 3.4, -19.75), 1.2)
	_string_bunting(Vector3(-19.2, 3.4, -12.0), Vector3(-4.0, 3.4, 15.3), 1.0)
	_string_bunting(Vector3(25.3, 3.4, -4.0), Vector3(2.4, 3.4, -19.75), 1.0)


func _lamp(parent: Node3D, lamp_name: String, pos: Vector3, yaw: float) -> void:
	_prop(dressing, "cove_lamp", lamp_name, pos, yaw, Vector3(0.3, 3.6, 0.3))
	_post(parent, lamp_name + "Post", 0.2, 3.4, pos)
	_player_block(parent, lamp_name + "Cap", Vector3(0.9, 4.0, 0.9), pos + Vector3(0, 5.4, 0))


## A string of fluttering pennants from a to b (added to the shared bunting mesh).
func _string_bunting(a: Vector3, b: Vector3, sag: float) -> void:
	var colors := [Color(0.85, 0.2, 0.25), Color(1.0, 0.94, 0.84), Color(0.13, 0.13, 0.17), Color(1.0, 0.76, 0.29), Color(0.12, 0.66, 0.62)]
	var length := a.distance_to(b)
	var count := int(length / 0.6)
	var flat := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var normal := flat.cross(Vector3.UP).normalized()
	for k in count:
		var t0 := (k + 0.1) / count
		var t1 := (k + 0.9) / count
		var tm := (k + 0.5) / count
		var p0 := a.lerp(b, t0) - Vector3.UP * sag * 4.0 * t0 * (1.0 - t0)
		var p1 := a.lerp(b, t1) - Vector3.UP * sag * 4.0 * t1 * (1.0 - t1)
		var tip := a.lerp(b, tm) - Vector3.UP * (sag * 4.0 * tm * (1.0 - tm) + 0.4)
		var c: Color = colors[(_bunting_count + k) % colors.size()]
		for v in [[p0, 0.0], [p1, 0.0], [tip, 1.0]]:
			_bunting.set_color(c)
			_bunting.set_normal(normal)
			_bunting.set_uv(Vector2(0.5, v[1]))
			_bunting.add_vertex(v[0])
	_bunting_count += 1
	var steps := 10
	for k in steps:
		var ta := float(k) / steps
		var tb := float(k + 1) / steps
		var pa := a.lerp(b, ta) - Vector3.UP * sag * 4.0 * ta * (1.0 - ta)
		var pb := a.lerp(b, tb) - Vector3.UP * sag * 4.0 * tb * (1.0 - tb)
		var up := Vector3.UP * 0.025
		for v in [pa + up, pb + up, pb - up, pa + up, pb - up, pa - up]:
			_lines.set_normal(normal)
			_lines.add_vertex(v)


func _finish_bunting() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Bunting"
	mi.mesh = _bunting.commit()
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "sky_bunting.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(mi)
	var lines := MeshInstance3D.new()
	lines.name = "BuntingLines"
	lines.mesh = _lines.commit()
	var rope := _mat("rope", Color(0.89, 0.77, 0.54), 0.9)
	rope.cull_mode = BaseMaterial3D.CULL_DISABLED
	lines.material_override = rope
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(lines)


# ---------------------------------------------------------------------------
# Lights
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	var lights := Node3D.new()
	lights.name = "WarmLights"
	level.add_child(lights)
	_omni(lights, "StationGlow", STATION + Vector3(0, 3.5, 3.2), Color(1.0, 0.78, 0.5), 1.3, 9.0)
	_omni(lights, "TavernGlow", TAVERN + Vector3(0, 2.6, 5.5), Color(1.0, 0.72, 0.42), 1.4, 9.0)
	_omni(lights, "SternGlow", _ship(0.0, 16.0, 8.0), Color(1.0, 0.78, 0.5), 1.6, 10.0)
	_omni(lights, "CaveGlow", CAVE + Vector3(2.0, 3.0, -2.5), Color(1.0, 0.7, 0.4), 1.2, 7.0)
	_omni(lights, "WarehouseGlow", WAREHOUSE + Vector3(0, 3.2, -5.6), Color(1.0, 0.75, 0.45), 1.2, 7.0)
	_omni(lights, "LagoonGlow", Vector3(BRIDGE_X, 2.6, -1.0), Color(1.0, 0.75, 0.45), 1.0, 8.0)


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
# The sea, the cliffs round the cove and the sea stacks
# ---------------------------------------------------------------------------

func _sea_material() -> ShaderMaterial:
	if _materials.has("sea"):
		return _materials["sea"]
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "cove_water.gdshader")
	m.set_shader_parameter("sun_direction", Vector2(SUN_DIRECTION.x, SUN_DIRECTION.z).normalized())
	_materials["sea"] = m
	return m


func _build_sea_and_cliffs() -> void:
	var back := Node3D.new()
	back.name = "Cove"
	dressing.add_child(back)
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000.0, 4000.0)
	plane.subdivide_width = 0
	sea.mesh = plane
	sea.material_override = _sea_material()
	sea.position = Vector3(0, SEA_Y, 0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	back.add_child(sea)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	# The north wall: a run of big cliff chunks behind the line z = -20.6,
	# leaving the cave and the tunnel mouths and the waterfall's notch.
	var x := -64.0
	var k := 0
	while x < 84.0:
		var w := rng.randf_range(9.0, 14.0)
		var cx := x + w * 0.5
		var depth := rng.randf_range(12.0, 18.0)
		var h := rng.randf_range(17.0, 25.0)
		if absf(cx - CAVE.x) < 7.0 or absf(cx - TUNNEL.x) < 6.0:
			h = rng.randf_range(13.0, 16.0)
		var front := -21.2 if cx > -21.0 else -24.0 - absf(cx + 21.0) * 0.25
		# Behind the cave's and the tunnel's vaults, not across their mouths.
		if absf(cx - CAVE.x) < w * 0.6 + 3.5:
			front = CAVE.z - 10.6
		elif absf(cx - TUNNEL.x) < w * 0.6 + 2.8:
			front = TUNNEL.z - 8.6
		_cliff(back, "NorthCliff%02d" % k, Vector3(cx, -2.0, front - depth * 0.56), Vector3(w * 1.15, h, depth), rng.randf_range(0, 360), k % 2 == 0)
		x += w * 0.78
		k += 1
	# Lintels over the cave and tunnel mouths and the waterfall's lip.
	_cliff(back, "CaveLintel", CAVE + Vector3(0, 5.6, -5.5), Vector3(11.0, 9.0, 9.0), 40.0, false)
	_cliff(back, "TunnelLintel", TUNNEL + Vector3(0, 4.8, -5.0), Vector3(8.0, 8.0, 8.0), 110.0, true)
	_cliff(back, "FallLip", Vector3(-2.0, 14.0, -23.5), Vector3(9.0, 9.0, 9.0), 10.0, false)
	# The east headland beyond the lagoon and the west point beyond the ship.
	for entry in [[Vector3(68, -2, -22), Vector3(26, 22, 30)], [Vector3(76, -2, 8), Vector3(22, 16, 26)], [Vector3(66, -2, 34), Vector3(20, 11, 22)],
			[Vector3(-58, -2, -26), Vector3(26, 20, 22)], [Vector3(-70, -2, -4), Vector3(18, 14, 22)]]:
		_cliff(back, "Headland%d" % k, entry[0], entry[1], rng.randf_range(0, 360), k % 2 == 1)
		k += 1
	# Sea stacks in the cove mouth and off the headlands.
	for entry in [[Vector3(-46, SEA_Y - 1.0, 18), Vector3(7, 22, 7)], [Vector3(-54, SEA_Y - 1.0, 40), Vector3(9, 30, 9)], [Vector3(58, SEA_Y - 1.0, 52), Vector3(8, 18, 8)],
			[Vector3(30, SEA_Y - 1.0, 70), Vector3(6, 14, 6)], [Vector3(-34, SEA_Y - 1.0, 62), Vector3(5, 11, 5)]]:
		var st := _prop(back, "cove_stack", "Stack%d" % k, entry[0], rng.randf_range(0, 360), Vector3.ONE)
		st.scale = entry[1]
		k += 1
	# Palms and ferns along the cliff tops.
	var tops := [Vector3(-30, 17, -32), Vector3(-16, 15, -30), Vector3(8, 19, -31), Vector3(16, 21, -33), Vector3(34, 18, -31), Vector3(46, 20, -33),
		Vector3(64, 18, -20), Vector3(72, 14, 8), Vector3(-56, 16, -26)]
	for i in tops.size():
		var palm := _prop(back, "cove_palm", "CliffPalm%d" % i, tops[i] + Vector3(0, -1.2, 0), rng.randf_range(0, 360), Vector3(1, 8, 1))
		palm.scale = Vector3.ONE * rng.randf_range(1.0, 1.4)
		var fern := _prop(back, "cove_fern", "CliffFern%d" % i, tops[i] + Vector3(2.5, -1.0, 1.5), rng.randf_range(0, 360), Vector3.ONE)
		fern.scale = Vector3.ONE * 2.2


func _cliff(parent: Node3D, cliff_name: String, base: Vector3, size: Vector3, yaw: float, alt: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.name = cliff_name
	mi.mesh = _glb_mesh("cove_cliff_b" if alt else "cove_cliff", "")
	mi.position = base
	mi.rotation.y = deg_to_rad(yaw)
	mi.scale = Vector3(size.x, size.y, size.z)
	parent.add_child(mi)


# ---------------------------------------------------------------------------
# Backdrop: the lighthouse on the rocks, far islands, ships on the horizon
# ---------------------------------------------------------------------------

func _build_backdrop() -> void:
	var back := Node3D.new()
	back.name = "Backdrop"
	dressing.add_child(back)
	var lh := MeshInstance3D.new()
	lh.name = "Lighthouse"
	lh.mesh = _glb_mesh("cove_lighthouse", "Lighthouse")
	lh.position = LIGHTHOUSE
	lh.rotation.y = deg_to_rad(-30.0)
	lh.scale = Vector3.ONE * 1.3
	back.add_child(lh)
	var beam := MeshInstance3D.new()
	beam.name = "LighthouseBeam"
	beam.mesh = _glb_mesh("cove_lighthouse", "Beam")
	var bm := ShaderMaterial.new()
	bm.shader = load(SHADERS + "cove_beam.gdshader")
	beam.material_override = bm
	beam.position = LIGHTHOUSE + Vector3(0, 20.7 * 1.3, 0)
	beam.scale = Vector3.ONE * 1.3
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	back.add_child(beam)
	_late(beam, "res://scripts/props/ambient_motion.gd", {"spin_degrees_per_second": 24.0})
	# Far islands with green tops on the horizon.
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var isles := [[Vector3(-380, -4, 260), Vector3(140, 40, 90)], [Vector3(-160, -4, 420), Vector3(110, 30, 80)], [Vector3(260, -4, 380), Vector3(160, 50, 110)],
		[Vector3(420, -4, 120), Vector3(120, 36, 90)], [Vector3(-460, -4, -60), Vector3(150, 55, 120)], [Vector3(80, -4, 520), Vector3(90, 24, 70)]]
	for i in isles.size():
		_cliff(back, "FarIsle%d" % i, isles[i][0], isles[i][1], rng.randf_range(0, 360), i % 2 == 0)
	# Ships on the horizon, at anchor.
	for entry in [[Vector3(-150, SEA_Y - 0.5, 200), 0.7, 60.0], [Vector3(120, SEA_Y - 0.5, 250), 0.55, -30.0]]:
		var ship := _prop(back, "cove_galleon", "FarGalleon%d" % int(entry[0].x), entry[0], entry[2], Vector3(9, 20, 34))
		ship.scale = Vector3.ONE * entry[1]
		_late(ship, "res://scripts/props/ambient_motion.gd", {"bob_height": 0.3, "bob_seconds": 7.0, "rock_degrees": 0.8})
	for entry in [[Vector3(-90, SEA_Y - 0.3, 110), -40.0], [Vector3(60, SEA_Y - 0.3, 130), 70.0], [Vector3(-200, SEA_Y - 0.3, 60), 120.0]]:
		var sl := _prop(back, "cove_sloop", "FarSloop%d" % int(entry[0].x), entry[0], entry[1], Vector3(4, 12, 11))
		_late(sl, "res://scripts/props/ambient_motion.gd", {"bob_height": 0.25, "bob_seconds": 5.0, "rock_degrees": 2.5})


# ---------------------------------------------------------------------------
# Exit: the portal at the end of the jetty and the lantern trail to it
# ---------------------------------------------------------------------------

func _build_exit() -> void:
	var portal: Node3D = (load("res://scenes/props/cove_portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	geo.add_child(portal)
	portal.position = PORTAL
	portal.rotation.y = PI
	var lights := Node3D.new()
	lights.name = "ExitLights"
	level.add_child(lights)
	var spots := []
	for z in [6.0, 10.5, 14.5]:
		spots.append([Vector3(-0.8, 0, z), Vector3(4.8, 0, z)])
	for z in [18.5, 22.0, 25.5]:
		spots.append([Vector3(-0.15, 0, z), Vector3(4.15, 0, z)])
	for k in spots.size():
		for s in 2:
			var pos: Vector3 = spots[k][s]
			var lantern := _prop(lights, "cove_exit_lantern", "ExitLantern%02d%s" % [k, "L" if s == 0 else "R"], pos, 90.0 if s == 0 else -90.0, Vector3(0.2, 1.6, 0.2))
			_late(lantern, "res://scripts/props/cove_exit_lantern.gd", {"order": k})


# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(7.0, 0.1, 10.5)
	start.rotation.y = deg_to_rad(35.0)
	start.add_to_group("player_spawn", true)
	level.add_child(start)

	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	var points := {
		"SpawnSeaCave": [CAVE + Vector3(0, 0.1, -5.5), 0.0],
		"SpawnTunnel": [TUNNEL + Vector3(0, 0.1, -5.6), 0.0],
		"SpawnFarJetty": [FAR_LANDING + Vector3(0.5, 0.1, 0.0), 90.0],
		"SpawnSlipway": [Vector3(-15.5, 0.1, 19.6), 180.0],
		"SpawnWarehouse": [WAREHOUSE + Vector3(0, 0.1, 0.6), 180.0],
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
	mesh.filter_baking_aabb = AABB(Vector3(-32, -1.0, -32), Vector3(90, DECK_Y + 2.4, 66))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	region.navigation_mesh = _largest_island(mesh)
	print("build_skull_harbor: navmesh polygons = %d (dropped %d on islands)" % [region.navigation_mesh.get_polygon_count(),
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


## After the bake: the small props' colliders go back to their real height on
## the player-only layer (zombies path round them but never snag on them), and
## the gangplank and walkway rails go player-only too (the player walls along
## them still hold the player).
func _release_clutter() -> void:
	for cs in _clutter:
		var box := cs.shape as BoxShape3D
		var height: float = cs.get_meta("height")
		box.size.y = height
		cs.position.y = height * 0.5
		cs.remove_meta("height")
		var body := cs.get_parent() as StaticBody3D
		body.collision_layer = 16
		body.collision_mask = 0
	for body in _soft:
		body.collision_layer = 16
		body.collision_mask = 0


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


## A thin upright wall collider from a to b (bulwarks).
func _wall_segment(parent: Node3D, wall_name: String, a: Vector3, b: Vector3, height: float, thick: float) -> void:
	var body := _collider(parent, wall_name, Vector3(a.distance_to(b) + thick * 0.5, height, thick), (a + b) * 0.5 + Vector3(0, height * 0.5, 0))
	var dir := (b - a).normalized()
	body.rotation.y = atan2(-dir.z, dir.x)


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


## A run of rope railing modules with one collision box (blocks walking).
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
	body.add_child(_module_row("Modules", "cove_rail", length, 2.5))


## Modules of a model laid end to end along local X (one MultiMesh).
func _module_row(row_name: String, model: String, length: float, module_len: float) -> MultiMeshInstance3D:
	var count := maxi(1, int(round(length / module_len)))
	var step := length / count
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _glb_mesh(model, "")
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


## A small prop with a box collider zombies path round but walk through: baked
## CLUTTER_BAKE_H tall into the navmesh, then player-only at its real height.
func _clutter_prop(parent: Node3D, model: String, prop_name: String, pos: Vector3, yaw_degrees: float, size: Vector3) -> Node3D:
	var node := _prop(dressing, model, prop_name, pos, yaw_degrees, size)
	var body := StaticBody3D.new()
	body.name = prop_name + "Collision"
	body.position = pos
	body.rotation.y = deg_to_rad(yaw_degrees)
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	var bake_h := maxf(size.y, CLUTTER_BAKE_H)
	box.size = Vector3(size.x, bake_h, size.z)
	shape.shape = box
	shape.position.y = bake_h * 0.5
	shape.set_meta("height", size.y)
	body.add_child(shape)
	_clutter.append(shape)
	return node


## The mesh of a glb's node named `node_name` (or its first mesh when empty).
func _glb_mesh(model: String, node_name: String) -> Mesh:
	var key := model + "/" + node_name
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var source: Node3D = (load(MODELS + model + ".glb") as PackedScene).instantiate()
	var found: MeshInstance3D = null
	for node in source.find_children("*", "MeshInstance3D", true, false):
		if node_name == "" or node.name == node_name:
			found = node
			break
	var mesh: Mesh = found.mesh
	source.free()
	_mesh_cache[key] = mesh
	return mesh


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
