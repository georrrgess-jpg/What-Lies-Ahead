extends SceneTree
## Generator for World 14 "Castle Kingdom" / level "Royal Faire".
##
## Rebuilds scenes/levels/royal_faire.tscn: a storybook faire on a spring
## morning in front of the King's castle. The faire green round the Royal
## Armoury station, the market lane (west), the jousting list with its stands
## (east), the dragon bouncy castle and the catapult range (south) under the
## village houses; across the moat and the drawbridge, the gatehouse, the
## courtyard, the wall-walks and the keep (the landmark) with the exit portal at
## its great door; the flank lanes either side of the castle; six zombie
## entrances, the windmill hill, forests, far hills, lights, bunting and a baked
## navigation mesh.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_royal_faire.gd
##
## Run it with a renderer (not --headless): the headless renderer keeps no
## MultiMesh instance data, so fences and trees would save empty.
##
## NOTE: running this overwrites hand edits made to royal_faire.tscn.
##
## Layout (metres, top view; -Z = north; ground y 0):
##   - Faire green (x -36..36, z -3..34): the station at (0, 0, 5), the market
##     (x -30..-15), the list (x 13..33) with the stands (y 2.4) on its east side.
##   - Moat (x -16..16, z -9..-3), crossed by the drawbridge (x -2.5..2.5).
##   - Castle: curtain walls x -18..18, z -40..-14 (walk on the south wall at y
##     5, two stair runs in the courtyard), the gatehouse at (0, -14), doors in
##     the west and east walls at z -27, the keep at (0, -36).
##   - Flank lanes x -36..-19.5 and 19.5..36 from the moat ends north to z -46.
##   - Entrances: courtyard postern (NW tower), forest road (NW), barn track (NE),
##     market gate (W), knights' pavilion (E), village lane (S).

const OUT_PATH := "res://scenes/levels/royal_faire.tscn"
const MODELS := "res://art/models/"
const TEXTURES := "res://art/textures/"
const SHADERS := "res://art/shaders/"

const STATION := Vector3(0.0, 0.0, 5.0)
const PORTAL := Vector3(0.0, 0.0, -29.4)
const KEEP := Vector3(0.0, 0.0, -36.0)
const GATE := Vector3(0.0, 0.0, -14.0)
const WALL_H := 5.0
const WALL_T := 3.0
const CASTLE_X := 18.0
const CASTLE_N := -40.0
const CASTLE_S := -14.0
const SIDE_DOOR_Z := -27.0
const MOAT := Rect2(-16.0, -9.0, 32.0, 6.0)          # x, z, w, d
const MOAT_Y := -1.0
const ARENA := Rect2(-36.0, -46.0, 72.0, 80.2)       # the player boundary
const SUN_DIRECTION := Vector3(0.6, 0.55, 0.58)      # toward the sun (east-south-east, morning)
const PLAYER_WALL_H := 12.0
const RED := Color(0.85, 0.2, 0.25)
const BLUE := Color(0.18, 0.36, 0.83)
const GOLD := Color(0.95, 0.76, 0.31)
const GREEN := Color(0.25, 0.66, 0.36)
const CREAM := Color(0.96, 0.93, 0.84)

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
var _scatter := {}       # model -> Array[Transform3D] (backdrop MultiMeshes)


func _initialize() -> void:
	level = Node3D.new()
	level.name = "RoyalFaire"
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

	_build_ground()
	_build_moat()
	_build_castle()
	_build_courtyard()
	_build_station()
	_build_green()
	_build_market()
	_build_list()
	_build_south()
	_build_lanes()
	_build_boundary()
	_build_entrances()
	_build_lights()
	_build_backdrop()
	_build_exit()
	_build_markers()
	_finish_bunting()
	_finish_scatter()
	var volley := Node3D.new()
	volley.name = "CatapultVolley"
	level.add_child(volley)
	_late(volley, "res://scripts/props/faire_catapult_volley.gd", {})

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
	print("build_royal_faire: saved %s (error %d), %d omni lights" % [OUT_PATH, err, _light_count])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: morning sky shader, the sun high in the east-south-east
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SHADERS + "faire_sky.gdshader")
	sky_mat.set_shader_parameter("sun_direction", SUN_DIRECTION.normalized())
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.78, 0.94)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.6
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.88, 0.98)
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.looking_at(-SUN_DIRECTION.normalized(), Vector3.UP), Vector3(0, 30, 0))
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 100.0
	sun.shadow_opacity = 0.72
	level.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.transform = Transform3D(Basis.looking_at(-Vector3(-0.5, 0.7, -0.5).normalized(), Vector3.UP), Vector3(0, 30, 0))
	fill.light_color = Color(0.66, 0.78, 1.0)
	fill.light_energy = 0.3
	fill.shadow_enabled = false
	level.add_child(fill)


# ---------------------------------------------------------------------------
# Ground: the playable turf (around the moat), the paths and the far meadow
# ---------------------------------------------------------------------------

func _build_ground() -> void:
	var g := Node3D.new()
	g.name = "Ground"
	geo.add_child(g)
	var grass := _textured("grass", "faire_grass", 0.16, 0.9)
	var x0 := -46.0
	var x1 := 46.0
	var z0 := -56.0
	var z1 := 44.0
	var mx0 := MOAT.position.x
	var mx1 := MOAT.end.x
	var mz0 := MOAT.position.y
	var mz1 := MOAT.end.y
	_ground_box(g, "TurfNorth", Rect2(x0, z0, x1 - x0, mz0 - z0), grass)
	_ground_box(g, "TurfSouth", Rect2(x0, mz1, x1 - x0, z1 - mz1), grass)
	_ground_box(g, "TurfWest", Rect2(x0, mz0, mx0 - x0, MOAT.size.y), grass)
	_ground_box(g, "TurfEast", Rect2(mx1, mz0, x1 - mx1, MOAT.size.y), grass)
	# The far meadow round it (scenery only, just under the turf).
	var meadow := MeshInstance3D.new()
	meadow.name = "Meadow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400.0, 1400.0)
	meadow.mesh = plane
	meadow.material_override = _textured("grass_far", "faire_grass", 0.05, 0.95)
	meadow.position = Vector3(0, -0.04, 0)
	meadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(meadow)
	# Cobbled paths: the courtyard, the gate passage, the plaza and the way to it.
	var cobble := _textured("cobble", "faire_cobble", 0.33, 0.8)
	_decal(dressing, "Courtyard", Rect2(-16.5, -38.5, 33.0, 24.6), 0.012, cobble)
	_decal(dressing, "GatePath", Rect2(-2.4, -16.4, 4.8, 7.5), 0.012, cobble)
	_decal(dressing, "GreenPath", Rect2(-2.2, -3.0, 4.4, 4.0), 0.012, cobble)
	_decal(dressing, "WestDoorPath", Rect2(-21.0, SIDE_DOOR_Z - 2.0, 5.0, 4.0), 0.012, cobble)
	_decal(dressing, "EastDoorPath", Rect2(16.0, SIDE_DOOR_Z - 2.0, 5.0, 4.0), 0.012, cobble)
	_decal(dressing, "MarketAisle", Rect2(-26.0, -1.0, 8.0, 21.0), 0.012, cobble)
	_decal(dressing, "VillageLane", Rect2(-3.0, 26.0, 6.0, 14.0), 0.012, cobble)
	var plaza := MeshInstance3D.new()
	plaza.name = "Plaza"
	var disc := CylinderMesh.new()
	disc.top_radius = 7.5
	disc.bottom_radius = 7.5
	disc.height = 0.03
	disc.radial_segments = 48
	plaza.mesh = disc
	plaza.material_override = cobble
	plaza.position = STATION + Vector3(0, 0.0, 0)
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
	rim.material_override = _stone_trim()
	rim.position = STATION + Vector3(0, 0.02, 0)
	rim.scale = Vector3(1, 0.25, 1)
	dressing.add_child(rim)


## A slab of turf: top at y 0, 0.6 thick, one collider with its mesh.
func _ground_box(parent: Node3D, box_name: String, r: Rect2, material: Material) -> void:
	_box(parent, box_name, Vector3(r.size.x, 0.6, r.size.y), Vector3(r.get_center().x, -0.3, r.get_center().y), material)


## A flat painted-on surface (no collision) just above the ground.
func _decal(parent: Node3D, decal_name: String, r: Rect2, y: float, material: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = decal_name
	var plane := PlaneMesh.new()
	plane.size = r.size
	mi.mesh = plane
	mi.material_override = material
	mi.position = Vector3(r.get_center().x, y, r.get_center().y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# ---------------------------------------------------------------------------
# The moat and the drawbridge
# ---------------------------------------------------------------------------

func _build_moat() -> void:
	var m := Node3D.new()
	m.name = "Moat"
	geo.add_child(m)
	var stone := _stone()
	var trim := _stone_trim()
	var x0 := MOAT.position.x
	var x1 := MOAT.end.x
	var z0 := MOAT.position.y
	var z1 := MOAT.end.y
	# Basin: a floor under the water and stone walls round it.
	_collider(m, "MoatFloor", Vector3(MOAT.size.x, 0.6, MOAT.size.y), Vector3(MOAT.get_center().x, -2.3, MOAT.get_center().y))
	for entry in [["BankN", Vector3(MOAT.size.x + 1.0, 2.0, 0.5), Vector3(MOAT.get_center().x, -1.0, z0 + 0.25)],
			["BankS", Vector3(MOAT.size.x + 1.0, 2.0, 0.5), Vector3(MOAT.get_center().x, -1.0, z1 - 0.25)],
			["BankW", Vector3(0.5, 2.0, MOAT.size.y), Vector3(x0 + 0.25, -1.0, MOAT.get_center().y)],
			["BankE", Vector3(0.5, 2.0, MOAT.size.y), Vector3(x1 - 0.25, -1.0, MOAT.get_center().y)]]:
		_visual_box(dressing, entry[0], entry[1], entry[2], stone)
	var water := MeshInstance3D.new()
	water.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2(MOAT.size.x - 0.4, MOAT.size.y - 0.4)
	water.mesh = plane
	var wm := ShaderMaterial.new()
	wm.shader = load(SHADERS + "faire_water.gdshader")
	water.material_override = wm
	water.position = Vector3(MOAT.get_center().x, MOAT_Y, MOAT.get_center().y)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(water)
	# Kerbs along both banks (open at the drawbridge) with player-only walls.
	var walls := _player_walls()
	for z in [z0 + 0.25, z1 - 0.25]:
		for span in [[x0 - 0.4, -2.6], [2.6, x1 + 0.4]]:
			var a := Vector3(span[0], 0, z)
			var b := Vector3(span[1], 0, z)
			_box(m, "Kerb%d_%d" % [int(z), int(span[0])], Vector3(b.x - a.x, 0.55, 0.6), (a + b) * 0.5 + Vector3(0, 0.275, 0), trim)
			_player_wall(walls, "MoatWall%d_%d" % [int(z), int(span[0])], a, b, PLAYER_WALL_H)
	for x in [x0 + 0.25, x1 - 0.25]:
		_box(m, "KerbEnd%d" % int(x), Vector3(0.6, 0.55, MOAT.size.y), Vector3(x, 0.275, MOAT.get_center().y), trim)
		_player_wall(walls, "MoatEnd%d" % int(x), Vector3(x, 0, z0), Vector3(x, 0, z1), PLAYER_WALL_H)
	# Lily pads and reeds for life.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1407
	var pad := CylinderMesh.new()
	pad.top_radius = 0.45
	pad.bottom_radius = 0.45
	pad.height = 0.03
	pad.radial_segments = 10
	pad.material = _mat("lily", Color(0.3, 0.66, 0.32), 0.7)
	for k in 14:
		var p := Vector3(rng.randf_range(x0 + 1.0, x1 - 1.0), MOAT_Y + 0.02, rng.randf_range(z0 + 0.8, z1 - 0.8))
		if absf(p.x) < 3.5:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Lily%d" % k
		mi.mesh = pad
		mi.position = p
		mi.scale = Vector3.ONE * rng.randf_range(0.7, 1.3)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dressing.add_child(mi)
	# The drawbridge (hinged at the gate, lowered across the moat).
	var bridge := _prop(dressing, "faire_drawbridge", "Drawbridge", Vector3(0, 0.06, -10.0), 0.0, Vector3(5, 0.4, 7))
	bridge.name = "Drawbridge"
	_collider(m, "DrawbridgeDeck", Vector3(5.0, 0.4, 7.4), Vector3(0, -0.14, -6.3))
	for s in [-1.0, 1.0]:
		_player_wall(walls, "BridgeWall%d" % int(s), Vector3(s * 2.55, 0, -10.0), Vector3(s * 2.55, 0, -2.9), PLAYER_WALL_H)


# ---------------------------------------------------------------------------
# The castle: curtain walls, towers, gatehouse, wall-walk and the keep
# ---------------------------------------------------------------------------

func _build_castle() -> void:
	var c := Node3D.new()
	c.name = "Castle"
	geo.add_child(c)
	var stone := _stone()
	var x := CASTLE_X
	var ht := WALL_T * 0.5
	# South wall either side of the gatehouse (the wall-walk), the north wall
	# behind the keep, the west and east walls with a door each.
	_wall_box(c, "WallSW", Vector3(-x, 0, CASTLE_S), Vector3(-4.5, 0, CASTLE_S), stone)
	_wall_box(c, "WallSE", Vector3(4.5, 0, CASTLE_S), Vector3(x, 0, CASTLE_S), stone)
	_wall_box(c, "WallN", Vector3(-x, 0, CASTLE_N), Vector3(x, 0, CASTLE_N), stone)
	for s in [-1.0, 1.0]:
		var wx: float = s * x
		_wall_box(c, "WallSide%dA" % int(s), Vector3(wx, 0, CASTLE_N), Vector3(wx, 0, SIDE_DOOR_Z - 2.0), stone)
		_wall_box(c, "WallSide%dB" % int(s), Vector3(wx, 0, SIDE_DOOR_Z + 2.0), Vector3(wx, 0, CASTLE_S), stone)
		_box(c, "DoorLintel%d" % int(s), Vector3(WALL_T, WALL_H - 3.9, 4.0), Vector3(wx, 3.9 + (WALL_H - 3.9) * 0.5, SIDE_DOOR_Z), stone)
		_side_door_dressing(wx, s)
	# Crenellations along the tops: outer edges of every wall, both edges of the
	# south wall-walk except at the stair heads.
	_parapet_run(c, "ParN", Vector3(-x + 3.0, WALL_H, CASTLE_N - ht + 0.3), Vector3(x - 3.0, WALL_H, CASTLE_N - ht + 0.3), false)
	for s in [-1.0, 1.0]:
		var ox: float = s * (x + ht - 0.3)
		_parapet_run(c, "ParSide%d" % int(s), Vector3(ox, WALL_H, CASTLE_N + 3.0), Vector3(ox, WALL_H, CASTLE_S - 3.0), false)
		var ix: float = s * (x - ht + 0.3)
		_parapet_run(c, "ParSideIn%d" % int(s), Vector3(ix, WALL_H, CASTLE_N + 3.0), Vector3(ix, WALL_H, CASTLE_S - 3.0), false)
		# The south wall-walk: an outer parapet the player cannot cross.
		_parapet_run(c, "ParSouth%d" % int(s), Vector3(s * 4.6, WALL_H, CASTLE_S + ht - 0.3), Vector3(s * (x - 3.0), WALL_H, CASTLE_S + ht - 0.3), true)
		_parapet_run(c, "ParSouthIn%d" % int(s), Vector3(s * 8.8, WALL_H, CASTLE_S - ht + 0.3), Vector3(s * (x - 3.0), WALL_H, CASTLE_S - ht + 0.3), true)
	_parapet_run(c, "ParNIn", Vector3(-x + 3.0, WALL_H, CASTLE_N + ht - 0.3), Vector3(-7.2, WALL_H, CASTLE_N + ht - 0.3), false)
	_parapet_run(c, "ParNIn2", Vector3(7.2, WALL_H, CASTLE_N + ht - 0.3), Vector3(x - 3.0, WALL_H, CASTLE_N + ht - 0.3), false)
	# Stairs up to the south wall-walk (along the inside of the wall).
	for s in [-1.0, 1.0]:
		var top_x: float = s * 6.6
		var z := CASTLE_S - ht - 1.35
		_box(c, "StairLanding%d" % int(s), Vector3(2.2, WALL_H, 2.7), Vector3(s * 5.5, WALL_H * 0.5, z), stone)
		_stairs(c, "WalkStair%d" % int(s), Vector3(top_x, WALL_H, z), Vector3(s * 15.4, 0.0, z), 2.6)
	# Corner towers.
	for entry in [["TowerSW", Vector3(-x, 0, CASTLE_S)], ["TowerSE", Vector3(x, 0, CASTLE_S)], ["TowerNW", Vector3(-x, 0, CASTLE_N)],
			["TowerNE", Vector3(x, 0, CASTLE_N)]]:
		var t := _prop(dressing, "faire_tower", entry[0], entry[1], fposmod(entry[1].x * 7.0 + entry[1].z, 360.0), Vector3(6, 17, 6))
		_restone(t)
		_post(c, entry[0] + "Collision", 3.25, 11.8, entry[1])
	# The gatehouse.
	var gh := _prop(dressing, "faire_gatehouse", "Gatehouse", GATE, 0.0, Vector3(9, 9, 4.4))
	_restone(gh)
	for s in [-1.0, 1.0]:
		_collider(c, "GatePier%d" % int(s), Vector3(2.2, 9.0, 4.4), GATE + Vector3(s * 3.4, 4.5, 0))
		_post(c, "GateDrum%d" % int(s), 2.15, 11.0, GATE + Vector3(s * 4.6, 0, 2.6))
	_collider(c, "GateArch", Vector3(4.6, 4.6, 4.4), GATE + Vector3(0, 4.4 + 2.3, 0))
	_player_block(c, "GateTopBlock", Vector3(9.4, 6.0, 5.0), GATE + Vector3(0, 12.0, 0))
	# The keep.
	var keep := _prop(dressing, "faire_keep", "Keep", KEEP, 0.0, Vector3(14, 30, 10))
	_restone(keep)
	_collider(c, "KeepBody", Vector3(14.6, 17.0, 10.6), KEEP + Vector3(0, 8.5, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_post(c, "KeepTurret%d%d" % [int(sx), int(sz)], 2.0, 19.0, KEEP + Vector3(sx * 7.0, 0, sz * 5.0))
	# Banner poles and torches on the walls.
	for s in [-1.0, 1.0]:
		_banner(dressing, "WalkBanner%d" % int(s), Vector3(s * 11.5, WALL_H, CASTLE_S + 1.05), 0.0, BLUE if s < 0 else RED)
	# Player-only caps: nobody climbs onto towers, the gatehouse or the keep.
	_player_block(c, "KeepCap", Vector3(18.0, 10.0, 14.0), KEEP + Vector3(0, 22.0, 0))


## A curtain wall from a to b (along X or Z), WALL_T thick, WALL_H tall.
func _wall_box(parent: Node3D, wall_name: String, a: Vector3, b: Vector3, material: Material) -> void:
	var length := a.distance_to(b)
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var size := Vector3(length, WALL_H, WALL_T) if along_x else Vector3(WALL_T, WALL_H, length)
	var body := _box(parent, wall_name, size, (a + b) * 0.5 + Vector3(0, WALL_H * 0.5, 0), material)
	# A lighter string course and a coping along the top.
	var trim := _stone_trim()
	var cap := Vector3(size.x + 0.12, 0.25, size.z + 0.12)
	var mi := MeshInstance3D.new()
	mi.name = "Coping"
	mi.mesh = _box_mesh(cap, trim)
	mi.position = Vector3(0, WALL_H * 0.5 - 0.1, 0)
	body.add_child(mi)
	var course := MeshInstance3D.new()
	course.name = "Course"
	course.mesh = _box_mesh(Vector3(size.x + 0.08, 0.22, size.z + 0.08), trim)
	course.position = Vector3(0, -WALL_H * 0.5 + 1.2, 0)
	body.add_child(course)


## Parapet modules along a wall top; with `solid` they collide (0.75 m wall,
## 1.5 m with merlons) and carry a player-only wall so nobody falls off.
func _parapet_run(parent: Node3D, run_name: String, a: Vector3, b: Vector3, solid: bool) -> void:
	var length := a.distance_to(b)
	if length < 1.0:
		return
	var body := StaticBody3D.new()
	body.name = run_name
	parent.add_child(body)
	body.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	body.rotation.y = atan2(-dir.z, dir.x)
	if solid:
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(length, 1.5, 0.6)
		shape.shape = box
		shape.position.y = 0.75
		body.add_child(shape)
		_player_wall(_player_walls(), run_name + "Guard", a, b, PLAYER_WALL_H)
	var row := _module_row("Modules", "faire_parapet", length, 3.0)
	_restone(row)
	body.add_child(row)


func _side_door_dressing(wx: float, s: float) -> void:
	var timber := _mat("timber", Color(0.48, 0.29, 0.18), 0.8)
	var iron := _mat("iron", Color(0.17, 0.18, 0.22), 0.5)
	var trim := _stone_trim()
	for face in [-1.0, 1.0]:
		var fx: float = wx + face * (WALL_T * 0.5 + 0.12)
		_visual_box(dressing, "DoorArch%d%d" % [int(s), int(face)], Vector3(0.3, 0.6, 4.8), Vector3(fx, 4.1, SIDE_DOOR_Z), trim)
		for dz in [-2.25, 2.25]:
			_visual_box(dressing, "DoorJamb%d%d%d" % [int(s), int(face), int(dz)], Vector3(0.3, 3.9, 0.5), Vector3(fx, 1.95, SIDE_DOOR_Z + dz), trim)
	# One gate leaf swung open against the passage wall on the courtyard side.
	var leaf_x: float = wx - s * (WALL_T * 0.5 - 0.2)
	_visual_box(dressing, "DoorLeaf%d" % int(s), Vector3(1.9, 3.6, 0.15), Vector3(leaf_x - s * 0.95, 1.8, SIDE_DOOR_Z - 1.88), timber)
	for y in [0.8, 2.8]:
		_visual_box(dressing, "DoorStrap%d%d" % [int(s), int(y)], Vector3(1.9, 0.14, 0.2), Vector3(leaf_x - s * 0.95, y, SIDE_DOOR_Z - 1.84), iron)


# ---------------------------------------------------------------------------
# The courtyard: well, quintains, the smithy and stable corners, braziers
# ---------------------------------------------------------------------------

func _build_courtyard() -> void:
	var y := Node3D.new()
	y.name = "Courtyard"
	geo.add_child(y)
	_solid_round(y, "faire_well", "Well", Vector3(-8.5, 0, -24.0), 20.0, 1.15, 1.1)
	for entry in [["QuintainA", Vector3(8.0, 0, -22.0)], ["QuintainB", Vector3(11.5, 0, -27.5)]]:
		_prop(y, "faire_dummy", entry[0] + "Base", entry[1], 0.0, Vector3(0.9, 0.3, 0.9))
		_post(y, entry[0] + "Post", 0.45, 2.6, entry[1])
		_player_block(y, entry[0] + "Cap", Vector3(1.0, 3.0, 1.0), entry[1] + Vector3(0, 4.1, 0))
		var arm := _prop(dressing, "faire_dummy", entry[0], entry[1], 0.0, Vector3(2.4, 2.6, 0.3))
		arm.name = entry[0]
		_late(arm, "res://scripts/props/ambient_motion.gd", {"spin_degrees_per_second": 22.0 if entry[1].x < 10.0 else -16.0})
	# The smithy corner (north-west): a stall with an anvil and a forge glow.
	_solid_prop(y, "faire_stall", "Smithy", Vector3(-14.4, 0, -34.5), 90.0, Vector3(3.2, 2.8, 2.0)).name = "Smithy"
	_solid_prop(y, "faire_barrels", "SmithyBarrels", Vector3(-14.6, 0, -30.2), 30.0, Vector3(1.9, 1.3, 1.4))
	_box(y, "Anvil", Vector3(0.9, 0.8, 0.45), Vector3(-11.6, 0.4, -34.6), _mat("iron", Color(0.17, 0.18, 0.22), 0.5))
	_brazier(y, "Forge", Vector3(-11.8, 0, -36.6))
	# The stable corner (north-east): hay, a cart, crates.
	_solid_prop(y, "faire_cart", "StableCart", Vector3(13.6, 0, -34.0), 160.0, Vector3(1.8, 1.8, 3.3))
	_solid_prop(y, "faire_hay", "StableHay", Vector3(14.6, 0, -30.0), 90.0, Vector3(2.4, 1.4, 1.2))
	_solid_prop(y, "faire_crates", "CourtCratesW", Vector3(-14.8, 0, -19.6), 15.0, Vector3(1.6, 1.5, 1.2))
	_solid_prop(y, "faire_hay", "CourtHayE", Vector3(4.2, 0, -20.0), 20.0, Vector3(2.4, 1.4, 1.2))
	_solid_prop(y, "faire_barrels", "CourtBarrels", Vector3(-4.6, 0, -21.4), 200.0, Vector3(1.9, 1.3, 1.4))
	# Braziers and banners framing the way to the keep and the portal.
	for s in [-1.0, 1.0]:
		_brazier(y, "KeepBrazier%d" % int(s), Vector3(s * 3.6, 0, -29.0))
		_banner(y, "CourtBanner%dA" % int(s), Vector3(s * 4.6, 0, -24.5), 0.0, RED if s < 0 else BLUE)
		_banner(y, "CourtBanner%dB" % int(s), Vector3(s * 5.6, 0, -19.0), 0.0, BLUE if s < 0 else RED)
	_string_bunting(Vector3(-4.6, 5.6, -24.5), Vector3(4.6, 5.6, -24.5), 0.8)
	_string_bunting(Vector3(-5.6, 5.6, -19.0), Vector3(5.6, 5.6, -19.0), 0.8)
	_string_bunting(Vector3(-4.6, 5.6, -24.5), Vector3(-5.6, 5.6, -19.0), 0.5)
	_string_bunting(Vector3(4.6, 5.6, -24.5), Vector3(5.6, 5.6, -19.0), 0.5)


func _brazier(parent: Node3D, b_name: String, pos: Vector3) -> void:
	_prop(dressing, "faire_brazier", b_name, pos, fposmod(pos.x * 40.0, 360.0), Vector3(0.9, 1.6, 0.9))
	_post(parent, b_name + "Post", 0.5, 1.7, pos)


func _banner(parent: Node3D, b_name: String, pos: Vector3, yaw: float, color: Color) -> void:
	var node := _prop(dressing, "faire_banner", b_name, pos, yaw, Vector3(0.4, 6, 0.4))
	_recolour(node, "FaireBanner", color)
	_post(parent, b_name + "Post", 0.35, 6.2, pos)


# ---------------------------------------------------------------------------
# Loadout station: the Royal Armoury
# ---------------------------------------------------------------------------

func _build_station() -> void:
	var station: Node3D = (load("res://scenes/props/faire_station.tscn") as PackedScene).instantiate()
	station.name = "Station"
	geo.add_child(station)
	station.position = STATION
	station.rotation.y = deg_to_rad(4.0)


# ---------------------------------------------------------------------------
# The faire green: carts, hay, banners and bunting round the station
# ---------------------------------------------------------------------------

func _build_green() -> void:
	var g := Node3D.new()
	g.name = "Green"
	geo.add_child(g)
	# Cover in a loose ring round the plaza (the inner loop).
	_solid_prop(g, "faire_hay", "HayN", Vector3(-6.5, 0, -1.0), 15.0, Vector3(2.4, 1.4, 1.2))
	_solid_prop(g, "faire_cart", "CartNE", Vector3(8.5, 0, -0.5), 120.0, Vector3(1.8, 1.8, 3.3))
	_solid_prop(g, "faire_barrels", "BarrelsE", Vector3(10.0, 0, 8.5), 60.0, Vector3(1.9, 1.3, 1.4))
	_solid_prop(g, "faire_hay", "HayS", Vector3(5.5, 0, 14.0), 160.0, Vector3(2.4, 1.4, 1.2))
	_solid_prop(g, "faire_crates", "CratesSW", Vector3(-6.0, 0, 13.0), 200.0, Vector3(1.6, 1.5, 1.2))
	_solid_prop(g, "faire_hay", "HayW", Vector3(-10.0, 0, 6.0), 95.0, Vector3(2.4, 1.4, 1.2))
	for entry in [["BenchA", Vector3(-3.6, 0, 13.6), 0.0], ["BenchB", Vector3(9.4, 0, 3.0), 280.0], ["BenchC", Vector3(-9.0, 0, -0.2), 30.0]]:
		_prop(dressing, "faire_bench", entry[0], entry[1], entry[2], Vector3(1.8, 0.5, 0.4))
		_collider(g, entry[0] + "Collision", Vector3(1.8, 0.5, 0.45), entry[1] + Vector3(0, 0.25, 0)).rotation.y = deg_to_rad(entry[2])
	# Banner poles round the plaza, bunting from them to the station's crown.
	var poles := [Vector3(-7.0, 0, 1.0), Vector3(7.0, 0, 1.5), Vector3(7.5, 0, 10.5), Vector3(-7.5, 0, 10.0)]
	var cols := [BLUE, RED, BLUE, RED]
	for i in poles.size():
		_banner(g, "GreenBanner%d" % i, poles[i], fposmod(i * 47.0, 360.0), cols[i])
		_string_bunting(poles[i] + Vector3.UP * 5.9, STATION + Vector3(0, 7.2, 0), 0.9)
	for i in poles.size():
		_string_bunting(poles[i] + Vector3.UP * 5.9, poles[(i + 1) % poles.size()] + Vector3.UP * 5.9, 0.9)
	# Bunting from the gatehouse towers down to the green.
	_string_bunting(GATE + Vector3(-4.6, 7.5, 2.8), poles[0] + Vector3.UP * 5.9, 1.6)
	_string_bunting(GATE + Vector3(4.6, 7.5, 2.8), poles[1] + Vector3.UP * 5.9, 1.6)


# ---------------------------------------------------------------------------
# The market (west): two rows of stalls along a cobbled aisle
# ---------------------------------------------------------------------------

func _build_market() -> void:
	var m := Node3D.new()
	m.name = "Market"
	geo.add_child(m)
	var awnings := [RED, BLUE, GREEN, GOLD, RED, BLUE, GOLD]
	var k := 0
	for z in [1.5, 7.0, 12.5, 18.0]:
		var node := _solid_prop(m, "faire_stall", "StallW%d" % k, Vector3(-27.5, 0, z), 90.0, Vector3(3.2, 2.9, 2.0))
		_recolour(node, "FaireTentA", awnings[k % awnings.size()])
		k += 1
	for z in [4.0, 9.5, 15.0]:
		var node := _solid_prop(m, "faire_stall", "StallE%d" % k, Vector3(-16.8, 0, z), -90.0, Vector3(3.2, 2.9, 2.0))
		_recolour(node, "FaireTentA", awnings[k % awnings.size()])
		k += 1
	_solid_prop(m, "faire_barrels", "MarketBarrelsA", Vector3(-29.2, 0, 22.0), 20.0, Vector3(1.9, 1.3, 1.4))
	_solid_prop(m, "faire_crates", "MarketCratesA", Vector3(-16.5, 0, 19.5), 80.0, Vector3(1.6, 1.5, 1.2))
	_solid_prop(m, "faire_cart", "MarketCart", Vector3(-30.6, 0, -2.0), 70.0, Vector3(1.8, 1.8, 3.3))
	_solid_prop(m, "faire_hay", "MarketHay", Vector3(-22.0, 0, 23.0), 0.0, Vector3(2.4, 1.4, 1.2))
	_brazier(m, "MarketBrazier", Vector3(-22.0, 0, 0.0))
	for z in [3.0, 9.0, 15.0]:
		_string_bunting(Vector3(-26.4, 3.0, z), Vector3(-17.9, 3.0, z + 1.8), 0.6)


# ---------------------------------------------------------------------------
# The jousting list (east): sand, the tilt barrier, the stands, pavilions
# ---------------------------------------------------------------------------

func _build_list() -> void:
	var l := Node3D.new()
	l.name = "List"
	geo.add_child(l)
	_decal(dressing, "ListSand", Rect2(13.5, 1.0, 14.5, 22.0), 0.012, _textured("sand", "faire_sand", 0.2, 0.95))
	# The tilt barrier down the middle.
	var a := Vector3(21.0, 0, 4.5)
	var b := Vector3(21.0, 0, 19.5)
	var tilt := StaticBody3D.new()
	tilt.name = "Tilt"
	l.add_child(tilt)
	tilt.position = (a + b) * 0.5
	tilt.rotation.y = PI * 0.5
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(a.distance_to(b), 1.3, 0.3)
	shape.shape = box
	shape.position.y = 0.65
	tilt.add_child(shape)
	tilt.add_child(_module_row("Modules", "faire_tilt", a.distance_to(b), 3.0))
	# The stands on the east side, facing the list, with stairs at both ends.
	var stands := Vector3(30.5, 0, 12.0)
	_prop(dressing, "faire_stands", "Stands", stands, -90.0, Vector3(12, 5.8, 3.5)).name = "Stands"
	_collider(l, "StandsDeck", Vector3(3.5, 2.4, 12.0), stands + Vector3(0, 1.2, 0))
	for s in [-1.0, 1.0]:
		_collider(l, "StandsRail%d" % int(s), Vector3(0.2, 1.15, 12.0), stands + Vector3(s * 1.67, 2.4 + 0.575, 0))
		_player_wall(_player_walls(), "StandsGuard%d" % int(s), stands + Vector3(s * 1.67, 2.4, -6.0), stands + Vector3(s * 1.67, 2.4, 6.0), 6.0)
		_stairs(l, "StandsStair%d" % int(s), stands + Vector3(0, 2.4, s * 6.0), stands + Vector3(0, 0, s * 10.6), 2.6)
	# Pavilions round the list.
	var tents := [[Vector3(16.0, 0, -0.5), RED], [Vector3(26.5, 0, -0.8), BLUE], [Vector3(15.5, 0, 25.0), GOLD], [Vector3(24.5, 0, 26.5), GREEN]]
	var i := 0
	for t in tents:
		var node := _prop(dressing, "faire_tent", "Pavilion%d" % i, t[0], fposmod(i * 83.0, 360.0), Vector3(5.2, 5.6, 5.2))
		_recolour(node, "FaireTentA", t[1])
		_post(l, "Pavilion%dCollision" % i, 2.65, 3.2, t[0])
		_player_block(l, "Pavilion%dCap" % i, Vector3(5.6, 4.0, 5.6), t[0] + Vector3(0, 5.2, 0))
		i += 1
	# Hay targets for the lances and bunting over the list.
	_solid_prop(l, "faire_hay", "ListHayN", Vector3(18.5, 0, 2.5), 90.0, Vector3(2.4, 1.4, 1.2))
	_solid_prop(l, "faire_hay", "ListHayS", Vector3(23.5, 0, 21.5), 90.0, Vector3(2.4, 1.4, 1.2))
	_banner(l, "ListBannerN", Vector3(21.0, 0, 2.6), 90.0, RED)
	_banner(l, "ListBannerS", Vector3(21.0, 0, 21.4), 90.0, BLUE)
	_string_bunting(Vector3(21.0, 5.9, 2.6), Vector3(21.0, 5.9, 21.4), 1.4)
	_string_bunting(Vector3(21.0, 5.9, 2.6), stands + Vector3(-1.6, 5.7, -6.0), 1.0)
	_string_bunting(Vector3(21.0, 5.9, 21.4), stands + Vector3(-1.6, 5.7, 6.0), 1.0)


# ---------------------------------------------------------------------------
# South: the dragon bouncy castle, the catapult range, the village houses
# ---------------------------------------------------------------------------

func _build_south() -> void:
	var s := Node3D.new()
	s.name = "South"
	geo.add_child(s)
	var dragon_at := Vector3(-16.0, 0, 26.0)
	var dragon := _prop(dressing, "faire_dragon", "DragonCastle", dragon_at, 180.0, Vector3(7, 7.5, 6))
	dragon.name = "DragonCastle"
	_late(dragon, "res://scripts/props/ambient_motion.gd", {"bob_height": 0.05, "bob_seconds": 2.4, "rock_degrees": 0.6})
	_collider(s, "DragonBase", Vector3(7.2, 2.7, 6.2), dragon_at + Vector3(0, 1.35, 0))
	_post(s, "DragonNeck", 1.6, 7.5, dragon_at + Vector3(0, 0, -3.4))
	_player_block(s, "DragonCap", Vector3(8.0, 4.0, 8.0), dragon_at + Vector3(0, 6.0, 0))
	# The maypole (it turns slowly, ribbons and all).
	var pole_at := Vector3(2.5, 0, 23.5)
	var pole := _prop(dressing, "faire_maypole", "Maypole", pole_at, 0.0, Vector3(0.6, 9, 0.6))
	_late(pole, "res://scripts/props/ambient_motion.gd", {"spin_degrees_per_second": 9.0})
	_post(s, "MaypoleFoot", 0.65, 2.0, pole_at)
	_player_block(s, "MaypoleCap", Vector3(1.2, 8.0, 1.2), pole_at + Vector3(0, 6.0, 0))
	# The catapult range.
	_solid_prop(s, "faire_catapult", "Catapult", Vector3(13.5, 0, 28.5), 200.0, Vector3(2.4, 2.4, 3.4))
	_player_block(s, "CatapultCap", Vector3(2.6, 3.0, 3.6), Vector3(13.5, 3.9, 28.5), deg_to_rad(200.0))
	for entry in [["TargetA", Vector3(29.0, 0, 30.5), 200.0], ["TargetB", Vector3(32.5, 0, 26.0), 230.0], ["TargetC", Vector3(-28.0, 0, 28.5), 150.0]]:
		_solid_prop(s, "faire_hay_target", entry[0], entry[1], entry[2], Vector3(1.8, 2.2, 1.2))
	_solid_prop(s, "faire_hay", "RangeHay", Vector3(8.0, 0, 24.0), 30.0, Vector3(2.4, 1.4, 1.2))
	_solid_prop(s, "faire_barrels", "RangeBarrels", Vector3(-7.5, 0, 24.5), 10.0, Vector3(1.9, 1.3, 1.4))
	# Village houses along the south edge, fronts to the green.
	var roofs := [Color(0.79, 0.35, 0.23), Color(0.55, 0.36, 0.62), Color(0.79, 0.35, 0.23), Color(0.28, 0.42, 0.7), Color(0.79, 0.35, 0.23), Color(0.6, 0.42, 0.24)]
	var xs := [-31.0, -22.0, -9.2, 9.2, 21.0, 30.5]
	for i in xs.size():
		var at := Vector3(xs[i], 0, 37.6)
		var yaw := 180.0
		var house := _prop(dressing, "faire_house", "House%d" % i, at, yaw, Vector3(6, 9, 5))
		_restone(house)
		_recolour(house, "FaireRoofTile", roofs[i])
		_collider(s, "House%dCollision" % i, Vector3(6.8, 6.0, 5.8), at + Vector3(0, 3.0, 0))
		_player_block(s, "House%dCap" % i, Vector3(7.6, 5.0, 6.4), at + Vector3(0, 8.5, 0))


# ---------------------------------------------------------------------------
# Flank lanes either side of the castle
# ---------------------------------------------------------------------------

func _build_lanes() -> void:
	var l := Node3D.new()
	l.name = "Lanes"
	geo.add_child(l)
	# West: the tourney stables (hay, carts, a quintain, an archery butt).
	_solid_prop(l, "faire_hay", "WLaneHayA", Vector3(-31.5, 0, -16.0), 90.0, Vector3(2.4, 1.4, 1.2))
	_solid_prop(l, "faire_cart", "WLaneCart", Vector3(-24.5, 0, -33.0), 10.0, Vector3(1.8, 1.8, 3.3))
	_solid_prop(l, "faire_hay_target", "WLaneTarget", Vector3(-32.5, 0, -27.0), 80.0, Vector3(1.8, 2.2, 1.2))
	_solid_prop(l, "faire_barrels", "WLaneBarrels", Vector3(-31.5, 0, -38.5), 0.0, Vector3(1.9, 1.3, 1.4))
	_solid_prop(l, "faire_crates", "WLaneCrates", Vector3(-22.6, 0, -19.0), 100.0, Vector3(1.6, 1.5, 1.2))
	_solid_prop(l, "faire_tent", "WLaneTent", Vector3(-31.0, 0, -6.0), 30.0, Vector3(5.2, 5.6, 5.2))
	_recolour(l.get_node("WLaneTent"), "FaireTentA", GREEN)
	# East: the barn track (a tent, crates, carts, hay).
	_solid_prop(l, "faire_hay", "ELaneHayA", Vector3(31.5, 0, -18.0), 90.0, Vector3(2.4, 1.4, 1.2))
	_solid_prop(l, "faire_cart", "ELaneCart", Vector3(24.0, 0, -35.5), 190.0, Vector3(1.8, 1.8, 3.3))
	_solid_prop(l, "faire_crates", "ELaneCrates", Vector3(32.5, 0, -30.0), 30.0, Vector3(1.6, 1.5, 1.2))
	_solid_prop(l, "faire_barrels", "ELaneBarrels", Vector3(22.5, 0, -21.0), 120.0, Vector3(1.9, 1.3, 1.4))
	_solid_prop(l, "faire_tent", "ELaneTent", Vector3(31.0, 0, -6.5), 200.0, Vector3(5.2, 5.6, 5.2))
	_recolour(l.get_node("ELaneTent"), "FaireTentA", RED)
	for s in [-1.0, 1.0]:
		_banner(l, "LaneBanner%d" % int(s), Vector3(s * 22.0, 0, -10.6), 0.0, RED if s < 0 else BLUE)
		_brazier(l, "LaneBrazier%d" % int(s), Vector3(s * 22.4, 0, -24.0))


# ---------------------------------------------------------------------------
# The boundary: palisades, gates and the player-only walls
# ---------------------------------------------------------------------------

func _build_boundary() -> void:
	var b := Node3D.new()
	b.name = "Boundary"
	geo.add_child(b)
	var walls := _player_walls()
	var x0 := ARENA.position.x
	var x1 := ARENA.end.x
	var z0 := ARENA.position.y
	var z1 := ARENA.end.y
	# West side (gap for the market gate), east side (gap for the pavilion).
	_palisade(b, walls, "PalW1", Vector3(x0, 0, z0), Vector3(x0, 0, 7.4))
	_palisade(b, walls, "PalW2", Vector3(x0, 0, 11.6), Vector3(x0, 0, z1))
	_palisade(b, walls, "PalE1", Vector3(x1, 0, z0), Vector3(x1, 0, 9.9))
	_palisade(b, walls, "PalE2", Vector3(x1, 0, 14.1), Vector3(x1, 0, z1))
	# North: gaps for the forest road and the barn track; closed behind the castle.
	_palisade(b, walls, "PalNW1", Vector3(x0, 0, z0), Vector3(-30.2, 0, z0))
	_palisade(b, walls, "PalNW2", Vector3(-25.8, 0, z0), Vector3(-CASTLE_X, 0, z0))
	_palisade(b, walls, "PalNE1", Vector3(CASTLE_X, 0, z0), Vector3(25.8, 0, z0))
	_palisade(b, walls, "PalNE2", Vector3(30.2, 0, z0), Vector3(x1, 0, z0))
	for s in [-1.0, 1.0]:
		_palisade(b, walls, "PalBack%d" % int(s), Vector3(s * CASTLE_X, 0, CASTLE_N - 2.6), Vector3(s * CASTLE_X, 0, z0))
	# South: between the houses (a gap for the village lane at x -2.1..2.1).
	var hx := [-31.0, -22.0, -9.2, 9.2, 21.0, 30.5]
	_palisade(b, walls, "PalS0", Vector3(x0, 0, z1), Vector3(hx[0] - 3.4, 0, z1))
	_palisade(b, walls, "PalS1", Vector3(hx[0] + 3.4, 0, z1), Vector3(hx[1] - 3.4, 0, z1))
	_palisade(b, walls, "PalS2", Vector3(hx[1] + 3.4, 0, z1), Vector3(hx[2] - 3.4, 0, z1))
	_palisade(b, walls, "PalS3", Vector3(hx[2] + 3.4, 0, z1), Vector3(-2.1, 0, z1))
	_palisade(b, walls, "PalS4", Vector3(2.1, 0, z1), Vector3(hx[3] - 3.4, 0, z1))
	_palisade(b, walls, "PalS5", Vector3(hx[3] + 3.4, 0, z1), Vector3(hx[4] - 3.4, 0, z1))
	_palisade(b, walls, "PalS6", Vector3(hx[4] + 3.4, 0, z1), Vector3(hx[5] - 3.4, 0, z1))
	_palisade(b, walls, "PalS7", Vector3(hx[5] + 3.4, 0, z1), Vector3(x1, 0, z1))
	# Player walls along the house fronts (the houses are the boundary there).
	for i in hx.size():
		_player_wall(walls, "HouseWall%d" % i, Vector3(hx[i] - 3.6, 0, z1), Vector3(hx[i] + 3.6, 0, z1), PLAYER_WALL_H)


func _palisade(parent: Node3D, walls: Node3D, run_name: String, a: Vector3, b: Vector3) -> void:
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
	box.size = Vector3(length, 2.6, 0.45)
	shape.shape = box
	shape.position.y = 1.3
	body.add_child(shape)
	body.add_child(_module_row("Modules", "faire_palisade", length, 3.0))
	_player_wall(walls, run_name + "Wall", a, b, PLAYER_WALL_H)


# ---------------------------------------------------------------------------
# Zombie entrances (all beyond the player boundary but the courtyard postern)
# ---------------------------------------------------------------------------

func _build_entrances() -> void:
	var e := Node3D.new()
	e.name = "Entrances"
	geo.add_child(e)
	var walls := _player_walls()
	# Gates in the palisade: two posts, a lintel with pennants, one leaf open.
	_gate_arch(e, "MarketGate", Vector3(ARENA.position.x, 0, 9.5), 90.0, 4.2)
	_gate_arch(e, "PavilionGate", Vector3(ARENA.end.x, 0, 12.0), 90.0, 4.2)
	_gate_arch(e, "ForestGate", Vector3(-28.0, 0, ARENA.position.y), 0.0, 4.4)
	_gate_arch(e, "BarnGate", Vector3(28.0, 0, ARENA.position.y), 0.0, 4.4)
	_gate_arch(e, "VillageGate", Vector3(0.0, 0, ARENA.end.y), 0.0, 4.2)
	_player_wall(walls, "MarketGateBar", Vector3(ARENA.position.x, 0, 7.4), Vector3(ARENA.position.x, 0, 11.6), PLAYER_WALL_H)
	_player_wall(walls, "PavilionGateBar", Vector3(ARENA.end.x, 0, 9.9), Vector3(ARENA.end.x, 0, 14.1), PLAYER_WALL_H)
	_player_wall(walls, "ForestGateBar", Vector3(-30.2, 0, ARENA.position.y), Vector3(-25.8, 0, ARENA.position.y), PLAYER_WALL_H)
	_player_wall(walls, "BarnGateBar", Vector3(25.8, 0, ARENA.position.y), Vector3(30.2, 0, ARENA.position.y), PLAYER_WALL_H)
	_player_wall(walls, "VillageGateBar", Vector3(-2.1, 0, ARENA.end.y), Vector3(2.1, 0, ARENA.end.y), PLAYER_WALL_H)
	# Beyond the gates: the knights' pavilion, the market road cart, the
	# forest road and barn, the village lane's houses.
	var pav := _prop(dressing, "faire_tent", "KnightsPavilion", Vector3(42.0, 0, 12.0), 270.0, Vector3(5.2, 5.6, 5.2))
	pav.scale = Vector3.ONE * 1.25
	_recolour(pav, "FaireTentA", BLUE)
	_solid_prop(e, "faire_cart", "RoadCart", Vector3(-41.5, 0, 4.0), 20.0, Vector3(1.8, 1.8, 3.3))
	_solid_prop(e, "faire_hay", "BarnHay", Vector3(33.0, 0, -50.0), 0.0, Vector3(2.4, 1.4, 1.2))
	# The courtyard postern: an open door in the north-west tower.
	var door_at := Vector3(-CASTLE_X, 0, CASTLE_N) + Vector3(0.707, 0, 0.707) * 3.0
	var dark := _mat("doorway", Color(0.08, 0.07, 0.1), 0.9)
	var postern := _visual_box(dressing, "PosternDoorway", Vector3(2.0, 3.0, 0.3), door_at + Vector3(0, 1.5, 0), dark)
	postern.rotation.y = deg_to_rad(45.0)
	var arch := _visual_box(dressing, "PosternArch", Vector3(2.6, 0.5, 0.5), door_at + Vector3(0, 3.2, 0), _stone_trim())
	arch.rotation.y = deg_to_rad(45.0)


## A palisade gateway: two posts, a lintel with a sign board, a gate leaf
## swung outward.
func _gate_arch(parent: Node3D, gate_name: String, at: Vector3, yaw_degrees: float, width: float) -> void:
	var timber := _mat("timber", Color(0.48, 0.29, 0.18), 0.8)
	var holder := Node3D.new()
	holder.name = gate_name
	parent.add_child(holder)
	holder.position = at
	holder.rotation.y = deg_to_rad(yaw_degrees)
	for s in [-1.0, 1.0]:
		_post(holder, "Post%d" % int(s), 0.3, 3.8, Vector3(s * (width * 0.5 + 0.2), 0, 0))
		_visual_box(holder, "PostMesh%d" % int(s), Vector3(0.5, 3.8, 0.5), Vector3(s * (width * 0.5 + 0.2), 1.9, 0), timber)
	_visual_box(holder, "Lintel", Vector3(width + 1.2, 0.45, 0.55), Vector3(0, 3.9, 0), timber)
	_visual_box(holder, "Sign", Vector3(2.2, 0.6, 0.12), Vector3(0, 3.35, 0.32), _mat("gold", GOLD, 0.4))
	var leaf := _visual_box(holder, "Leaf", Vector3(width * 0.5, 2.3, 0.12), Vector3(width * 0.5 + 0.3, 1.25, -width * 0.25 - 0.2), timber)
	leaf.rotation.y = PI * 0.5


# ---------------------------------------------------------------------------
# Lights
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	var lights := Node3D.new()
	lights.name = "WarmLights"
	level.add_child(lights)
	_omni(lights, "StationGlow", STATION + Vector3(0, 3.5, 3.0), Color(1.0, 0.86, 0.62), 1.0, 9.0)
	_omni(lights, "GatePassage", GATE + Vector3(0, 3.2, 0), Color(1.0, 0.78, 0.5), 1.4, 7.0)
	_omni(lights, "KeepDoor", KEEP + Vector3(0, 3.5, 6.5), Color(1.0, 0.78, 0.5), 1.4, 9.0)
	_omni(lights, "Forge", Vector3(-11.8, 2.0, -36.0), Color(1.0, 0.55, 0.25), 1.2, 6.0)


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
# Backdrop: rolling hills, forests, the windmill hill, far castles, birds
# ---------------------------------------------------------------------------

func _build_backdrop() -> void:
	var back := Node3D.new()
	back.name = "Backdrop"
	dressing.add_child(back)
	var hill_a := _textured("hill_a", "faire_grass", 0.04, 0.95)
	var hill_b := _mat("hill_b", Color(0.36, 0.62, 0.3), 0.95)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	var rng := RandomNumberGenerator.new()
	rng.seed = 1409
	var hills := [[Vector3(70, -6, -15), Vector3(34, 14, 30), hill_a], [Vector3(-80, -10, -40), Vector3(50, 18, 40), hill_b],
		[Vector3(-30, -16, -120), Vector3(90, 30, 40), hill_a], [Vector3(60, -14, -110), Vector3(70, 26, 40), hill_b],
		[Vector3(-110, -12, 40), Vector3(60, 22, 60), hill_a], [Vector3(100, -14, 70), Vector3(60, 24, 50), hill_b],
		[Vector3(10, -20, 120), Vector3(110, 34, 40), hill_a], [Vector3(-180, -30, -160), Vector3(140, 60, 80), hill_b],
		[Vector3(190, -30, -120), Vector3(130, 56, 80), hill_a], [Vector3(200, -34, 140), Vector3(140, 60, 90), hill_b],
		[Vector3(-200, -36, 160), Vector3(150, 62, 90), hill_a]]
	var i := 0
	for h in hills:
		var mi := MeshInstance3D.new()
		mi.name = "Hill%d" % i
		mi.mesh = sphere
		mi.material_override = h[2]
		mi.position = h[0]
		mi.scale = h[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		back.add_child(mi)
		i += 1
	# The windmill on its hill (north-east), sails turning.
	var mill_at := Vector3(66.0, 7.2, -18.0)
	var mill := _prop(back, "faire_windmill", "Windmill", mill_at, -110.0, Vector3(6, 13, 6))
	mill.name = "Windmill"
	_restone(mill)
	var hub := mill_at + Basis(Vector3.UP, deg_to_rad(-110.0)) * Vector3(0, 9.6, 2.9)
	var pivot := Node3D.new()
	pivot.name = "SailPivot"
	back.add_child(pivot)
	pivot.position = hub
	pivot.basis = Basis(Vector3.UP, deg_to_rad(-110.0)) * Basis(Vector3.RIGHT, PI * 0.5)
	var sails := _prop(pivot, "faire_windmill_sails", "Sails", Vector3.ZERO, 0.0, Vector3(14, 0.4, 14))
	sails.name = "Sails"
	_late(sails, "res://scripts/props/ambient_motion.gd", {"spin_degrees_per_second": 24.0})
	# Far castles on the northern hills.
	for entry in [[Vector3(-60, 2, -150), 0.9], [Vector3(-48, 4, -146), 0.7], [Vector3(120, 4, -170), 0.8], [Vector3(-170, 8, 60), 0.8]]:
		var t := _prop(back, "faire_tower", "FarTower%d" % i, entry[0], rng.randf_range(0, 360), Vector3(6, 17, 6))
		t.scale = Vector3.ONE * entry[1]
		_restone(t)
		i += 1
	# Village roofs beyond the south edge.
	for k in 7:
		var at := Vector3(-36.0 + k * 12.0 + rng.randf_range(-2, 2), 0, 50.0 + rng.randf_range(-3, 4))
		var house := _prop(back, "faire_house", "FarHouse%d" % k, at, rng.randf_range(150, 210), Vector3(6, 9, 5))
		_restone(house)
	# Forests: trees and pines scattered round the faire.
	for k in 220:
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(54.0, 150.0)
		var p := Vector3(cos(a) * d * 1.1, 0, sin(a) * d)
		if p.distance_to(Vector3(66, 0, -18)) < 24.0 or (p.z > 38.0 and p.z < 62.0 and absf(p.x) < 50.0):
			continue
		var model := "faire_pine" if rng.randf() < 0.45 else "faire_tree"
		var s := rng.randf_range(1.2, 2.2)
		_scatter_add(model, Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * s), p + Vector3(0, _hill_height(p, hills), 0)))
	# A few trees just inside the edges of the lanes and the green.
	for p in [Vector3(-34.0, 0, -42.0), Vector3(34.0, 0, -42.5), Vector3(-34.3, 0, 30.5), Vector3(34.0, 0, 32.0), Vector3(-34.0, 0, -22.0),
			Vector3(34.2, 0, -25.0)]:
		_scatter_add("faire_tree", Transform3D(Basis(Vector3.UP, p.x).scaled(Vector3.ONE * 1.1), p))
		_post(geo, "EdgeTree%d_%d" % [int(p.x), int(p.z)], 0.45, 3.0, p)
	# Birds wheeling over the castle.
	var flock := Node3D.new()
	flock.name = "Flock"
	back.add_child(flock)
	flock.position = Vector3(0, 30, -24)
	_late(flock, "res://scripts/props/ambient_motion.gd", {"spin_degrees_per_second": 14.0, "bob_height": 1.5, "bob_seconds": 9.0})
	for k in 6:
		var a := TAU * k / 6.0 + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(14.0, 22.0)
		var bird := _prop(flock, "faire_bird", "Bird%d" % k, Vector3(cos(a) * r, rng.randf_range(-3, 3), sin(a) * r), rad_to_deg(-a), Vector3(0.6, 0.1, 0.4))
		bird.scale = Vector3.ONE * 2.2


## Rough height of the backdrop hills at p (so far trees sit on them).
func _hill_height(p: Vector3, hills: Array) -> float:
	var best := 0.0
	for h in hills:
		var c: Vector3 = h[0]
		var s: Vector3 = h[1]
		var q := Vector2((p.x - c.x) / s.x, (p.z - c.z) / s.z)
		var k := 1.0 - q.length_squared()
		if k > 0.0:
			best = maxf(best, c.y + s.y * sqrt(k) - 0.4)
	return best


func _scatter_add(model: String, xf: Transform3D) -> void:
	if not _scatter.has(model):
		_scatter[model] = []
	_scatter[model].append(xf)


func _finish_scatter() -> void:
	for model in _scatter:
		var list: Array = _scatter[model]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _model_mesh(model)
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Scatter_" + model
		mmi.multimesh = mm
		dressing.add_child(mmi)


# ---------------------------------------------------------------------------
# Exit: the portal at the keep's great door and the lantern trail to it
# ---------------------------------------------------------------------------

func _build_exit() -> void:
	var portal: Node3D = (load("res://scenes/props/faire_portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	geo.add_child(portal)
	portal.position = PORTAL
	var lights := Node3D.new()
	lights.name = "ExitLights"
	level.add_child(lights)
	var trail := [Vector3(0, 0, -0.5), Vector3(0, 0, -2.6), Vector3(0, 0, -17.5), Vector3(0, 0, -21.0), Vector3(0, 0, -24.5), Vector3(0, 0, -27.5)]
	for k in trail.size():
		for s in [-1.0, 1.0]:
			var pos: Vector3 = trail[k] + Vector3(s * 2.9, 0, 0)
			var lantern := _prop(lights, "faire_exit_lantern", "ExitLantern%02d%s" % [k, "L" if s < 0 else "R"], pos, 90.0 - s * 90.0, Vector3(0.2, 2.2, 0.2))
			_late(lantern, "res://scripts/props/faire_exit_lantern.gd", {"order": k})


# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(0.0, 0.1, 16.0)
	start.rotation.y = 0.0
	start.add_to_group("player_spawn", true)
	level.add_child(start)

	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	var points := {
		"SpawnPostern": [Vector3(-CASTLE_X, 0, CASTLE_N) + Vector3(0.707, 0, 0.707) * 5.2 + Vector3(0, 0.1, 0), 135.0],
		"SpawnForestRoad": [Vector3(-28.0, 0.1, ARENA.position.y - 4.5), 180.0],
		"SpawnBarnTrack": [Vector3(28.0, 0.1, ARENA.position.y - 4.5), 180.0],
		"SpawnMarketGate": [Vector3(ARENA.position.x - 4.0, 0.1, 9.5), -90.0],
		"SpawnPavilion": [Vector3(ARENA.end.x + 3.2, 0.1, 12.0), 90.0],
		"SpawnVillageLane": [Vector3(0.0, 0.1, ARENA.end.y + 4.2), 0.0],
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
	mesh.filter_baking_aabb = AABB(Vector3(-46, -0.8, -56), Vector3(92, WALL_H + 2.2, 100))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	region.navigation_mesh = _largest_island(mesh)
	print("build_royal_faire: navmesh polygons = %d (dropped %d on islands)" % [region.navigation_mesh.get_polygon_count(),
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
# Bunting
# ---------------------------------------------------------------------------

## A string of fluttering pennants from a to b (added to the shared bunting mesh).
func _string_bunting(a: Vector3, b: Vector3, sag: float) -> void:
	var colors := [Color(0.85, 0.2, 0.25), Color(0.95, 0.76, 0.31), Color(0.18, 0.36, 0.83), Color(0.98, 0.96, 0.9), Color(0.25, 0.66, 0.36)]
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
	m.shader = load(SHADERS + "faire_bunting.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(mi)
	var lines := MeshInstance3D.new()
	lines.name = "BuntingLines"
	lines.mesh = _lines.commit()
	var rope := _mat("rope", Color(0.9, 0.82, 0.62), 0.9)
	rope.cull_mode = BaseMaterial3D.CULL_DISABLED
	lines.material_override = rope
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(lines)


# ---------------------------------------------------------------------------
# Materials and re-dressing
# ---------------------------------------------------------------------------

func _stone() -> StandardMaterial3D:
	return _textured("stone", "faire_stone", 0.42, 0.85)


func _stone_trim() -> StandardMaterial3D:
	return _mat("stone_trim", Color(0.8, 0.78, 0.82), 0.8)


## Swaps every "FaireStone" surface under `node` for the block-textured stone.
func _restone(node: Node) -> void:
	_override_surfaces(node, "FaireStone", _stone())


## Recolours every surface named `material_name` under `node`.
func _recolour(node: Node, material_name: String, color: Color) -> void:
	_override_surfaces(node, material_name, _mat("%s_%s" % [material_name, color.to_html(false)], color, 0.6))


func _override_surfaces(node: Node, material_name: String, material: Material) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m and m.resource_name == material_name:
				mi.set_surface_override_material(i, material)
	elif node is MultiMeshInstance3D:
		var mmi := node as MultiMeshInstance3D
		var mesh := mmi.multimesh.mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m and m.resource_name == material_name:
				var copy: Mesh = _mesh_with(mesh, material_name, material)
				mmi.multimesh.mesh = copy
				break
	for child in node.get_children():
		_override_surfaces(child, material_name, material)


## A copy of `mesh` with every `material_name` surface set to `material`
## (MultiMeshes have no per-surface override), cached per mesh.
func _mesh_with(mesh: Mesh, material_name: String, material: Material) -> Mesh:
	var key := "%d|%s" % [mesh.get_instance_id(), material_name]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var copy: Mesh = mesh.duplicate()
	for i in copy.get_surface_count():
		var m := copy.surface_get_material(i)
		if m and m.resource_name == material_name:
			copy.surface_set_material(i, material)
	_mesh_cache[key] = copy
	return copy


func _model_mesh(model: String) -> Mesh:
	if _mesh_cache.has(model):
		return _mesh_cache[model]
	var source: Node3D = (load(MODELS + model + ".glb") as PackedScene).instantiate()
	var mesh: Mesh = (source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	source.free()
	_mesh_cache[model] = mesh
	return mesh


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


## A stair run from `top` down to `bottom` (along X or Z), `width` wide: a
## sloped collider under visual stone steps and timber side rails.
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
	var tread := _stone_trim()
	var fill_mat := _stone()
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
			fill.mesh = _box_mesh(Vector3(length / steps + 0.02, h, width - 0.02), fill_mat)
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
		var rail := _module_row("Rail", "faire_fence", sqrt(length * length + rise * rise), 3.0)
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


## A round prop with a cylinder collider (radius, height).
func _solid_round(parent: Node3D, model: String, prop_name: String, pos: Vector3, yaw_degrees: float, radius: float, height: float) -> Node3D:
	var node := _prop(parent, model, prop_name, pos, yaw_degrees, Vector3(radius * 2, height, radius * 2))
	_restone(node)
	_post(parent, prop_name + "Collision", radius, height, pos)
	return node


## A prop with a matching box collider (footprint `size`, standing on `pos`).
func _solid_prop(parent: Node3D, model: String, prop_name: String, pos: Vector3, yaw_degrees: float, size: Vector3) -> Node3D:
	var node := _prop(parent, model, prop_name, pos, yaw_degrees, size)
	var c := _collider(parent, prop_name + "Collision", size, pos + Vector3(0, size.y * 0.5, 0))
	c.rotation.y = deg_to_rad(yaw_degrees)
	return node


## The mesh of art/models/<model>.glb as the level's own MeshInstance3D (so
## surface recolours save with the scene), or a grey stand-in box if missing.
func _prop(parent: Node3D, model: String, prop_name: String, pos: Vector3, yaw_degrees: float, placeholder_size: Vector3) -> Node3D:
	var path := MODELS + model + ".glb"
	var node: Node3D
	if ResourceLoader.exists(path):
		var mi := MeshInstance3D.new()
		mi.mesh = _model_mesh(model)
		node = mi
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
