extends SceneTree
## Generator for World 9 "Volcano Isle" / level "Lava Lagoon".
##
## Rebuilds scenes/levels/lava_lagoon.tscn: a tiki resort on a black-basalt
## shelf below an erupting volcano, at dusk. The lava river in its walled
## channel, the three stone bridges up to the observatory terrace, the plaza
## round the Tiki Outfitters station, the tiki bar and the hot springs, the
## boardwalk and the beach, six zombie entrances, Mount Kahuna and its plume,
## the ocean, lights, embers and a baked navigation mesh.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_lava_lagoon.gd
##
## Run it with a renderer (not --headless): the headless renderer keeps no
## MultiMesh instance data, so railings, kerbs and palms would save empty.
##
## NOTE: running this overwrites hand edits made to lava_lagoon.tscn.
##
## Layout (metres, top view; -Z = north, toward the volcano):
##   - Plaza (y 0) from the river (z -9.4) to the beach railing (z 23.6); the
##     station at (0, 0, 2) is its hub, ringed by tiki totems; the Lava Lounge
##     bar to the west, the hot springs to the east, the boardwalk and the
##     portal lookout to the south.
##   - The lava river runs east to west in a walled channel (z -13.6..-10);
##     three stair-bridges climb over it to the terrace (y 2, z -26..-13.6)
##     with the giant Kahuna head, the observatory (NW) and the funicular (NE).
##   - Entrances: observatory door, funicular, lava-tube cave (W), staff hut
##     (SW), beach stairs (SE), jungle-trail gate (E).

const OUT_PATH := "res://scenes/levels/lava_lagoon.tscn"
const MODELS := "res://art/models/"
const TEXTURES := "res://art/textures/"
const SHADERS := "res://art/shaders/"

const STATION := Vector3(0.0, 0.0, 2.0)
const TERRACE_Y := 2.0
const TERRACE_Z1 := -13.6        # terrace front wall (north bank of the river)
const TERRACE_BACK := -26.0      # player boundary at the back of the terrace
const RIVER_Z0 := -13.6
const RIVER_Z1 := -10.0
const RIVER_Y := -0.55           # lava surface
const KERB_Z := -9.65            # centre line of the south bank wall
const BRIDGE_XS: Array[float] = [-15.0, 0.0, 14.0]
const BRIDGE_HALF := 2.0
const BRIDGE_RUN := 8.5
const ARENA_X := 24.0
const ARENA_Z1 := 23.6           # beach railing
const BEACH_Y := -3.0
const BEACH_STAIRS_X := 19.0
const SPRING_A := Vector3(12.5, 0.0, 4.5)
const SPRING_B := Vector3(17.5, 0.0, 11.5)
const SPRING_RADII := Vector2(3.4, 2.5)
const BAR := Vector3(-13.0, 0.0, 4.0)
const PORTAL := Vector3(0.0, 0.0, 21.2)
const VOLCANO := Vector3(40.0, -14.0, -300.0)
const SUN_DIRECTION := Vector3(-0.8, 0.3, 0.45)       # toward the afterglow (WSW, low)

var level: Node3D
var geo: Node3D          # collidable geometry (navmesh source)
var dressing: Node3D     # non-colliding scenery
var _materials := {}
var _boxes := {}
var _noise: FastNoiseLite
var _late_scripts: Array = []
var _light_count := 0
var _mesh_cache := {}


func _initialize() -> void:
	level = Node3D.new()
	level.name = "LavaLagoon"
	_noise = FastNoiseLite.new()
	_noise.seed = 91
	_noise.frequency = 0.012
	_noise.fractal_octaves = 4

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

	_build_terrain()
	_build_ground()
	_build_river()
	_build_terrace()
	_build_bridges()
	_build_station()
	_build_bar()
	_build_springs()
	_build_plaza_props()
	_build_boardwalk()
	_build_entrances()
	_build_boundary()
	_build_lights()
	_build_backdrop()
	_build_exit()
	_build_markers()

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
	print("build_lava_lagoon: saved %s (error %d), %d omni lights" % [OUT_PATH, err, _light_count])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: dusk sky shader, low magenta sun, the volcano's red fill
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SHADERS + "lava_sky.gdshader")
	sky_mat.set_shader_parameter("sun_direction", SUN_DIRECTION)
	sky_mat.set_shader_parameter("fire_direction", (VOLCANO * Vector3(1, 0, 1)).normalized() + Vector3.UP * 0.2)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.36, 0.66)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.6
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.62
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.42, 0.2, 0.42)
	env.fog_density = 0.0026
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
	sun.light_color = Color(1.0, 0.6, 0.5)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_opacity = 0.75
	level.add_child(sun)

	# The volcano's glow from the north: a red rim on everything facing it.
	var fill := DirectionalLight3D.new()
	fill.name = "VolcanoGlow"
	var to_volcano := Vector3(VOLCANO.x, 60.0, VOLCANO.z).normalized()
	fill.transform = Transform3D(Basis.looking_at(-to_volcano, Vector3.UP), Vector3(0, 30, 0))
	fill.light_color = Color(1.0, 0.36, 0.2)
	fill.light_energy = 0.55
	fill.shadow_enabled = false
	level.add_child(fill)


# ---------------------------------------------------------------------------
# Terrain: the island around the resort shelf (visual only)
# ---------------------------------------------------------------------------

func _terrain_height(x: float, z: float) -> float:
	var n := _noise.get_noise_2d(x, z)
	# North: the volcano's lower flank rising behind the terrace.
	var north := maxf(-40.0 - z, 0.0)
	var h := TERRACE_Y + north * 0.1 + north * north * 0.0002
	# East and west: rocky headlands.
	var side := maxf(absf(x) - 40.0, 0.0)
	h += side * 0.35 * (1.0 - smoothstep(20.0, 60.0, z))
	# South: the shelf drops to the beach, which runs out under the sea.
	var south := z - ARENA_Z1
	if south > 0.0:
		var beach := lerpf(BEACH_Y, -5.0, smoothstep(6.0, 60.0, south))
		h = lerpf(h, beach, smoothstep(0.0, 4.0, south) * (1.0 - smoothstep(30.0, 80.0, side)))
	h += n * 6.0 * clampf((north + side) / 25.0, 0.0, 1.0)
	# The resort shelf itself is under the slabs: keep the terrain out of sight.
	if absf(x) < 40.0 and z > -40.0 and z < ARENA_Z1 + 1.0:
		h = minf(h, -1.2)
	return h


func _build_terrain() -> void:
	var holder := Node3D.new()
	holder.name = "Terrain"
	dressing.add_child(holder)
	var rock := _textured("terrain_rock", "lava_rock", 0.08, 0.95)
	holder.add_child(_terrain_mesh("TerrainNear", Rect2(-160, -220, 320, 300), 4.0, rock, 0.0))
	holder.add_child(_terrain_mesh("TerrainFar", Rect2(-700, -700, 1400, 900), 20.0, rock, 3.0))


func _terrain_mesh(mesh_name: String, area: Rect2, cell: float, material: Material, sink: float) -> MeshInstance3D:
	var nx := int(area.size.x / cell)
	var nz := int(area.size.y / cell)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz + 1:
		for i in nx + 1:
			var x := area.position.x + i * cell
			var z := area.position.y + j * cell
			var h := _terrain_height(x, z)
			if sink > 0.0 and x > -156.0 and x < 156.0 and z > -216.0 and z < 76.0:
				h -= sink
			st.set_uv(Vector2(i, j))
			st.add_vertex(Vector3(x, h, z))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			for idx in [a, b, c, b, d, c]:
				st.add_index(idx)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------------------
# Ground: plaza slab, paving, the shelf edge and the beach
# ---------------------------------------------------------------------------

func _build_ground() -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	geo.add_child(ground)
	var basalt := _textured("basalt", "lava_basalt", 0.22, 0.85)
	var rock := _textured("terrain_rock", "lava_rock", 0.08, 0.95)
	# Plaza slab (collision and the basalt paving on top).
	_box(ground, "PlazaSlab", Vector3(80.0, 2.0, 35.6), Vector3(0, -1.0, 8.0 - 0.2), basalt)
	# The shelf's south face down to the beach.
	_visual_box(dressing, "ShelfFace", Vector3(80.0, 4.0, 1.0), Vector3(0, -2.0, 26.3), rock)
	# Beach: black sand running out under the sea (the stairs' landing collides).
	var sand := _textured("sand", "lava_sand", 0.16, 0.95)
	var beach := MeshInstance3D.new()
	beach.name = "Beach"
	beach.mesh = _box_mesh(Vector3(320.0, 0.4, 60.0), sand)
	beach.position = Vector3(0, BEACH_Y - 1.1, 56.0)
	beach.rotation.x = deg_to_rad(-1.6)
	beach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(beach)
	_collider(ground, "BeachLanding", Vector3(12.0, 1.0, 10.0), Vector3(BEACH_STAIRS_X, BEACH_Y - 0.5, 34.0))
	# Round basalt-mosaic patio under the station and its rim of ember tiles.
	var patio := MeshInstance3D.new()
	patio.name = "Patio"
	var disc := CylinderMesh.new()
	disc.top_radius = 6.4
	disc.bottom_radius = 6.4
	disc.height = 0.04
	disc.radial_segments = 48
	patio.mesh = disc
	patio.material_override = _textured("deck", "lava_deck", 0.3, 0.75)
	patio.position = STATION + Vector3(0, 0.0, 0)
	patio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(patio)
	var rim := MeshInstance3D.new()
	rim.name = "PatioRim"
	var torus := TorusMesh.new()
	torus.inner_radius = 6.3
	torus.outer_radius = 6.75
	torus.rings = 64
	torus.ring_segments = 6
	rim.mesh = torus
	rim.material_override = _mat("ember_tile", Color(0.9, 0.36, 0.14), 0.5, Color(1.0, 0.4, 0.12), 0.8)
	rim.position = STATION + Vector3(0, 0.02, 0)
	rim.scale = Vector3(1, 0.25, 1)
	dressing.add_child(rim)


# ---------------------------------------------------------------------------
# The lava river: walled channel, molten surface, falls at both ends
# ---------------------------------------------------------------------------

func _build_river() -> void:
	var river := Node3D.new()
	river.name = "River"
	geo.add_child(river)
	var lava := _lava_material("river", Vector2(-0.32, 0.0), 0.0, 0.42)
	# The molten surface (no collision) and a floor under it so nothing falls forever.
	var surface := MeshInstance3D.new()
	surface.name = "Lava"
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, RIVER_Z1 - RIVER_Z0 + 0.4)
	plane.subdivide_width = 24
	surface.mesh = plane
	surface.material_override = lava
	surface.position = Vector3(0, RIVER_Y, (RIVER_Z0 + RIVER_Z1) * 0.5)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(surface)
	_collider(river, "RiverBed", Vector3(120.0, 1.0, RIVER_Z1 - RIVER_Z0), Vector3(0, RIVER_Y - 0.6, (RIVER_Z0 + RIVER_Z1) * 0.5))
	# South bank: a basalt parapet with gaps for the bridges.
	var spans := _kerb_spans(-60.0, 60.0)
	var k := 0
	for span in spans:
		_kerb_run(river, "SouthBank%d" % k, Vector3(span.x, 0, KERB_Z), Vector3(span.y, 0, KERB_Z))
		k += 1
	# Inside face of the south bank, down to the lava.
	_visual_box(dressing, "SouthBankFace", Vector3(120.0, 1.2, 0.4), Vector3(0, RIVER_Y + 0.1, RIVER_Z1 + 0.05), _textured("terrain_rock", "lava_rock", 0.08, 0.95))
	# Embers rising off the river.
	var embers := _embers("RiverEmbers", Vector3(48.0, 0.2, 3.0), 70, 2.6)
	embers.position = Vector3(0, RIVER_Y + 0.3, (RIVER_Z0 + RIVER_Z1) * 0.5)
	dressing.add_child(embers)
	# East: the river pours down a cliff of basalt columns; west: it vanishes into a lava tube.
	var fall := _lava_material("fall", Vector2(0.0, 0.0), 1.6, 0.35)
	var sheet := MeshInstance3D.new()
	sheet.name = "LavaFall"
	var fall_plane := PlaneMesh.new()
	fall_plane.size = Vector2(15.0, 6.0)
	sheet.mesh = fall_plane
	sheet.material_override = fall
	sheet.position = Vector3(41.0, 5.0, -11.8)
	sheet.rotation = Vector3(0, 0, deg_to_rad(62.0))
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(sheet)
	_prop(dressing, "lava_cliff", "FallCliff", Vector3(47.0, -1.0, -11.8), 90.0, Vector3(16, 10, 6)).scale = Vector3(1.0, 1.3, 1.0)
	_prop(dressing, "lava_cliff", "FallCliffN", Vector3(40.0, 1.0, -20.0), 10.0, Vector3(16, 10, 6))
	_prop(dressing, "lava_cliff", "FallCliffS", Vector3(38.0, -1.0, -2.5), 175.0, Vector3(16, 10, 6)).scale = Vector3(0.8, 0.7, 0.8)
	_prop(dressing, "lava_cave", "TubeMouth", Vector3(-41.0, RIVER_Y - 0.5, -11.8), 90.0, Vector3(8, 6, 8))
	_prop(dressing, "lava_cliff", "TubeCliff", Vector3(-46.0, 1.0, -12.0), -90.0, Vector3(16, 10, 6))
	var glow := _embers("FallEmbers", Vector3(3.0, 6.0, 4.0), 40, 3.0)
	glow.position = Vector3(40.0, 3.0, -11.8)
	dressing.add_child(glow)


## Spans of the south bank between the bridge gaps.
func _kerb_spans(x0: float, x1: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var start := x0
	for bx in BRIDGE_XS:
		out.append(Vector2(start, bx - BRIDGE_HALF))
		start = bx + BRIDGE_HALF
	out.append(Vector2(start, x1))
	return out


## A run of basalt parapet modules (lava_kerb.glb, 2.5 m each) with one collider:
## 0.95 m tall, 0.7 m thick.
func _kerb_run(parent: Node3D, run_name: String, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var body := StaticBody3D.new()
	body.name = run_name
	parent.add_child(body)
	body.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	body.rotation.y = atan2(-dir.z, dir.x)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(length, 0.95, 0.7)
	shape.shape = box
	shape.position.y = 0.475
	body.add_child(shape)
	body.add_child(_module_row("Modules", "lava_kerb", length, 2.5))


# ---------------------------------------------------------------------------
# Terrace: raised basalt shelf north of the river, the Kahuna head, lookouts
# ---------------------------------------------------------------------------

func _build_terrace() -> void:
	var t := Node3D.new()
	t.name = "Terrace"
	geo.add_child(t)
	var basalt := _textured("basalt", "lava_basalt", 0.22, 0.85)
	var deck := _textured("deck", "lava_deck", 0.3, 0.75)
	var wall := _textured("terrain_rock", "lava_rock", 0.08, 0.95)
	var depth := TERRACE_Z1 + 46.0
	_box(t, "TerraceSlab", Vector3(110.0, TERRACE_Y + 1.0, depth), Vector3(0, TERRACE_Y * 0.5 - 0.5, TERRACE_Z1 - depth * 0.5 - 0.0), basalt)
	# Retaining wall face down into the lava.
	_visual_box(dressing, "TerraceWall", Vector3(120.0, TERRACE_Y - RIVER_Y + 0.6, 0.5), Vector3(0, (TERRACE_Y + RIVER_Y) * 0.5 - 0.3, TERRACE_Z1 + 0.15), wall)
	_visual_box(dressing, "TerraceCoping", Vector3(120.0, 0.18, 0.7), Vector3(0, TERRACE_Y + 0.06, TERRACE_Z1 + 0.15), _mat("coping", Color(0.32, 0.27, 0.34), 0.8))
	# A timber lookout deck across the middle.
	_visual_box(dressing, "LookoutDeck", Vector3(20.0, 0.06, 9.0), Vector3(0, TERRACE_Y + 0.02, -19.6), deck)
	# Railing along the front edge, open at the bridge heads.
	var k := 0
	for span in _kerb_spans(-ARENA_X, ARENA_X):
		_fence_run(t, "TerraceRail%d" % k, Vector3(span.x, TERRACE_Y, TERRACE_Z1 + 0.35), Vector3(span.y, TERRACE_Y, TERRACE_Z1 + 0.35))
		k += 1
	# The Kahuna head, braziers and lookout furniture (cover up top).
	var head_pos := Vector3(0.0, TERRACE_Y, -23.6)
	_solid_prop(t, "lava_kahuna_head", "KahunaHead", head_pos, 0.0, Vector3(4.2, 5.4, 3.6))
	_player_block(t, "KahunaHeadCap", Vector3(4.6, 4.0, 4.0), head_pos + Vector3(0, 7.4, 0))
	for s in [-1.0, 1.0]:
		var p := head_pos + Vector3(s * 4.2, 0, 1.2)
		_prop(t, "lava_torch", "HeadTorch%d" % int(s), p, 0.0, Vector3(0.3, 2.5, 0.3))
		_post(t, "HeadTorch%dPost" % int(s), 0.14, 2.5, p)
		_fire(t, "HeadTorch%dFlame" % int(s), p + Vector3(0, 2.52, 0), 0.7, false)
	_solid_prop(t, "lava_planter", "TerracePlanterW", Vector3(-7.0, TERRACE_Y, -18.6), 0.0, Vector3(1.6, 0.75, 1.6))
	_solid_prop(t, "lava_planter", "TerracePlanterE", Vector3(7.0, TERRACE_Y, -18.6), 30.0, Vector3(1.6, 0.75, 1.6))
	_solid_prop(t, "lava_boulder", "TerraceRockW", Vector3(-21.0, TERRACE_Y, -19.0), 40.0, Vector3(2.4, 1.4, 1.5))
	_solid_prop(t, "lava_boulder", "TerraceRockE", Vector3(21.5, TERRACE_Y, -19.5), 200.0, Vector3(2.4, 1.4, 1.5))
	_solid_prop(t, "lava_crates", "TerraceCrates", Vector3(11.0, TERRACE_Y, -24.6), 0.0, Vector3(1.8, 1.3, 1.2))
	for i in 3:
		_prop(dressing, "lava_lounger", "TerraceLounger%d" % i, Vector3(-4.5 + i * 4.5, TERRACE_Y, -16.0), 180.0, Vector3(0.8, 0.6, 2.0))
	_solid_prop(t, "lava_boulder_b", "TerraceColumns", Vector3(-9.5, TERRACE_Y, -24.8), 0.0, Vector3(1.6, 2.4, 1.4))
	_prop(t, "lava_signpost", "TerraceSign", Vector3(4.0, TERRACE_Y, -16.5), 200.0, Vector3(0.2, 3.0, 0.2))
	_post(t, "TerraceSignPost", 0.12, 3.0, Vector3(4.0, TERRACE_Y, -16.5))


# ---------------------------------------------------------------------------
# Bridges: stone stairs climbing over the river (the player and the navmesh
# use an invisible ramp; the parapets collide as wedges)
# ---------------------------------------------------------------------------

func _build_bridges() -> void:
	var b := Node3D.new()
	b.name = "Bridges"
	geo.add_child(b)
	var walls := _player_walls()
	for bx in BRIDGE_XS:
		var name := "Bridge%d" % int(bx)
		_prop(b, "lava_bridge", name, Vector3(bx, 0.0, TERRACE_Z1), 0.0, Vector3(4, 2, 8.5))
		_ramp(b, name + "Ramp", bx - BRIDGE_HALF, bx + BRIDGE_HALF, TERRACE_Z1, TERRACE_Z1 + BRIDGE_RUN)
		for s in [-1.0, 1.0]:
			var x: float = bx + s * (BRIDGE_HALF + 0.15)
			_kerb(b, "%sParapet%s" % [name, "L" if s < 0 else "R"], x - 0.17, x + 0.17, TERRACE_Z1, TERRACE_Z1 + BRIDGE_RUN)
			_player_wall(walls, "%sSide%s" % [name, "L" if s < 0 else "R"], Vector3(x, 0, TERRACE_Z1 - 0.3), Vector3(x, 0, TERRACE_Z1 + BRIDGE_RUN), 7.0)
			_post(b, "%sNewelTop%s" % [name, "L" if s < 0 else "R"], 0.3, 1.6, Vector3(x, TERRACE_Y, TERRACE_Z1 - 0.25))
			_post(b, "%sNewelFoot%s" % [name, "L" if s < 0 else "R"], 0.3, 1.6, Vector3(x, 0.0, TERRACE_Z1 + BRIDGE_RUN + 0.25))


## A ramp from the terrace edge (z_top, at terrace height) down to the plaza (z_bottom).
func _ramp(parent: Node3D, ramp_name: String, x0: float, x1: float, z_top: float, z_bottom: float) -> void:
	var run := z_bottom - z_top
	var length := sqrt(run * run + TERRACE_Y * TERRACE_Y)
	var angle := atan2(TERRACE_Y, run)
	var thick := 0.5
	var body := StaticBody3D.new()
	body.name = ramp_name
	parent.add_child(body)
	var normal := Vector3(0, cos(angle), sin(angle))
	body.position = Vector3((x0 + x1) * 0.5, TERRACE_Y * 0.5, (z_top + z_bottom) * 0.5) - normal * (thick * 0.5 - 0.06)
	body.rotation.x = angle
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, thick, length + 0.3)
	shape.shape = box
	body.add_child(shape)


const KERB_H := 0.9


## Collision for a bridge parapet: a wedge from the terrace edge down to the plaza.
func _kerb(parent: Node3D, kerb_name: String, xa: float, xb: float, z_top: float, z_bottom: float) -> void:
	var body := StaticBody3D.new()
	body.name = kerb_name
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var wedge := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for x in [xa, xb]:
		pts.append(Vector3(x, RIVER_Y, z_top))
		pts.append(Vector3(x, TERRACE_Y + KERB_H, z_top))
		pts.append(Vector3(x, KERB_H, z_bottom))
		pts.append(Vector3(x, 0.0, z_bottom))
	wedge.points = pts
	shape.shape = wedge
	body.add_child(shape)


# ---------------------------------------------------------------------------
# Loadout station: Tiki Outfitters
# ---------------------------------------------------------------------------

func _build_station() -> void:
	var station: Node3D = (load("res://scenes/props/lava_station.tscn") as PackedScene).instantiate()
	station.name = "Station"
	geo.add_child(station)
	station.position = STATION
	station.rotation.y = deg_to_rad(8.0)


# ---------------------------------------------------------------------------
# The Lava Lounge: open tiki bar west of the plaza (walk round it, not over it)
# ---------------------------------------------------------------------------

func _build_bar() -> void:
	var bar := Node3D.new()
	bar.name = "Bar"
	geo.add_child(bar)
	_prop(bar, "lava_bar", "LavaLounge", BAR, 0.0, Vector3(7, 4, 4.6))
	_collider(bar, "CounterF", Vector3(5.6, 1.2, 0.85), BAR + Vector3(0, 0.6, 1.2))
	_collider(bar, "CounterL", Vector3(0.85, 1.2, 2.2), BAR + Vector3(-2.35, 0.6, -0.15))
	_collider(bar, "CounterR", Vector3(0.85, 1.2, 2.2), BAR + Vector3(2.35, 0.6, -0.15))
	_collider(bar, "Shelf", Vector3(4.6, 2.6, 0.6), BAR + Vector3(0, 1.3, -1.9))
	for x in [-3.3, 3.3]:
		for z in [-2.1, 2.1]:
			_post(bar, "Post%d%d" % [int(x), int(z)], 0.2, 3.2, BAR + Vector3(x, 0, z))
	_player_block(bar, "RoofCap", Vector3(8.4, 3.0, 6.2), BAR + Vector3(0, 4.6, 0))
	for i in 4:
		_prop(dressing, "lava_parasol", "BarParasol%d" % i, BAR + Vector3(-4.0 + i * 2.7, 0, 5.8 + (i % 2) * 1.2), i * 40.0, Vector3(3, 2.7, 3))
		_post(bar, "BarParasol%dPole" % i, 0.1, 2.6, BAR + Vector3(-4.0 + i * 2.7, 0, 5.8 + (i % 2) * 1.2))
		_player_block(bar, "BarParasol%dCap" % i, Vector3(2.6, 2.0, 2.6), BAR + Vector3(-4.0 + i * 2.7, 3.4, 5.8 + (i % 2) * 1.2))


# ---------------------------------------------------------------------------
# Hot springs: two teal pools ringed with rocks (cover), steam and lanterns
# ---------------------------------------------------------------------------

func _build_springs() -> void:
	var springs := Node3D.new()
	springs.name = "Springs"
	geo.add_child(springs)
	var k := 0
	for entry in [[SPRING_A, SPRING_RADII.x], [SPRING_B, SPRING_RADII.y]]:
		var c: Vector3 = entry[0]
		var r: float = entry[1]
		var body := StaticBody3D.new()
		body.name = "Pool%dRim" % k
		body.position = c + Vector3(0, 0.4, 0)
		springs.add_child(body)
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var cyl := CylinderShape3D.new()
		cyl.radius = r + 0.45
		cyl.height = 0.8
		shape.shape = cyl
		body.add_child(shape)
		_player_block(springs, "Pool%dLid" % k, Vector3(r * 2.0, 2.0, r * 2.0), c + Vector3(0, 1.9, 0))
		var water := MeshInstance3D.new()
		water.name = "Pool%dWater" % k
		var disc := CylinderMesh.new()
		disc.top_radius = r
		disc.bottom_radius = r
		disc.height = 0.1
		disc.radial_segments = 40
		water.mesh = disc
		var m := ShaderMaterial.new()
		m.shader = load(SHADERS + "lava_pool.gdshader")
		m.set_shader_parameter("centre", Vector2(c.x, c.z))
		m.set_shader_parameter("radius", r)
		water.material_override = m
		water.position = c + Vector3(0, 0.42, 0)
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dressing.add_child(water)
		_visual_box(dressing, "Pool%dBasin" % k, Vector3(r * 1.5, 0.42, r * 1.5), c + Vector3(0, 0.2, 0), _mat("basin", Color(0.12, 0.1, 0.16), 0.9))
		dressing.add_child(_rock_ring("Pool%dRocks" % k, c, r + 0.25, int(r * 7.0), k))
		for i in 2:
			var steam := _steam("Pool%dSteam%d" % [k, i], c + Vector3(randf_range(-0.6, 0.6), 0.45, randf_range(-0.6, 0.6)), r * 1.3, 4.0, i * 1.7 + k)
			steam.rotation.y = i * PI * 0.5
			dressing.add_child(steam)
		_omni(dressing, "Pool%dGlow" % k, c + Vector3(0, 1.0, 0), Color(0.3, 1.0, 0.85), 1.1, r * 2.6)
		k += 1
	_prop(dressing, "lava_spring_steps", "SpringSteps", SPRING_A + Vector3(-SPRING_RADII.x - 0.3, 0, 0), -90.0, Vector3(1.4, 1.5, 1.2))
	# Floating lanterns on the big pool.
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var lantern := MeshInstance3D.new()
		lantern.name = "FloatLantern%d" % i
		var s := SphereMesh.new()
		s.radius = 0.16
		s.height = 0.26
		s.radial_segments = 10
		s.rings = 5
		lantern.mesh = s
		lantern.material_override = _mat("float_lantern", Color(1.0, 0.7, 0.35), 0.4, Color(1.0, 0.62, 0.3), 3.0)
		lantern.position = SPRING_A + Vector3(cos(a) * 1.6, 0.5, sin(a) * 1.6)
		dressing.add_child(lantern)
		_late(lantern, "res://scripts/props/ambient_motion.gd", {"bob_height": 0.05, "bob_seconds": 2.6 + i * 0.4, "rock_degrees": 6.0})
	# Loungers and parasols beside the springs.
	for i in 3:
		var p := Vector3(19.5 + (i % 2) * 1.3, 0, -1.0 + i * 2.6)
		_prop(dressing, "lava_lounger", "SpringLounger%d" % i, p, 100.0, Vector3(0.8, 0.6, 2.0))
	_prop(dressing, "lava_parasol", "SpringParasol", Vector3(21.6, 0, 6.2), 30.0, Vector3(3, 2.7, 3))
	_post(springs, "SpringParasolPole", 0.1, 2.6, Vector3(21.6, 0, 6.2))
	_player_block(springs, "SpringParasolCap", Vector3(2.6, 2.0, 2.6), Vector3(21.6, 3.4, 6.2))


## A ring of basalt rocks round a pool (one MultiMesh, no collision of its own).
func _rock_ring(ring_name: String, c: Vector3, r: float, count: int, seed: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _model_mesh("lava_pebble")
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 30 + seed
	for i in count:
		var a := TAU * i / count + rng.randf_range(-0.05, 0.05)
		var s := Vector3(rng.randf_range(0.8, 1.2), rng.randf_range(0.8, 1.3), rng.randf_range(0.7, 1.0))
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, -a + rng.randf_range(-0.4, 0.4)).scaled(s),
			c + Vector3(cos(a) * r, -0.05, sin(a) * r)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = ring_name
	mmi.multimesh = mm
	return mmi


## Rising steam (a vertical card with the shared steam shader).
func _steam(steam_name: String, pos: Vector3, width: float, height: float, offset: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	quad.center_offset = Vector3(0, height * 0.5, 0)
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "neon_steam.gdshader")
	m.set_shader_parameter("steam_color", Color(0.75, 0.95, 0.95))
	m.set_shader_parameter("strength", 0.42)
	m.set_shader_parameter("speed", 0.35)
	m.set_shader_parameter("time_offset", offset)
	var mi := MeshInstance3D.new()
	mi.name = steam_name
	mi.mesh = quad
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------------------
# Plaza dressing: totems, torches, boulders, palms, planters
# ---------------------------------------------------------------------------

func _build_plaza_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	geo.add_child(props)
	# Tiki totems round the station (the inner loop's cover).
	var i := 0
	for a in [-30.0, 30.0, 150.0, 210.0]:
		var p := STATION + Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a))) * 8.6
		var yaw := rad_to_deg(atan2(STATION.x - p.x, STATION.z - p.z)) + 180.0
		_prop(props, "lava_totem", "Totem%d" % i, p, yaw, Vector3(0.9, 3.4, 0.9))
		_post(props, "Totem%dCollision" % i, 0.5, 3.6, p)
		_player_block(props, "Totem%dCap" % i, Vector3(1.6, 3.0, 1.6), p + Vector3(0, 5.0, 0))
		i += 1
	# Basalt boulders: chest-high cover along the routes.
	var rocks := [
		[Vector3(-6.0, 0, -5.4), 20.0], [Vector3(7.5, 0, -6.0), 160.0], [Vector3(-19.5, 0, -4.0), 80.0],
		[Vector3(-8.5, 0, 12.6), 200.0], [Vector3(9.0, 0, 13.4), 330.0], [Vector3(21.0, 0, -6.5), 110.0],
	]
	i = 0
	for r in rocks:
		_solid_prop(props, "lava_boulder", "Boulder%d" % i, r[0], r[1], Vector3(2.4, 1.35, 1.5))
		i += 1
	_solid_prop(props, "lava_boulder_b", "ColumnsW", Vector3(-21.0, 0, 10.0), 30.0, Vector3(1.6, 2.4, 1.4))
	_solid_prop(props, "lava_boulder_b", "ColumnsE", Vector3(5.0, 0, -7.6), 200.0, Vector3(1.6, 2.4, 1.4))
	# Planters and supplies.
	for entry in [["PlanterA", Vector3(-4.6, 0, 9.6)], ["PlanterB", Vector3(5.2, 0, 9.0)], ["PlanterC", Vector3(-18.0, 0, -7.0)],
			["PlanterD", Vector3(12.0, 0, -6.6)]]:
		_solid_prop(props, "lava_planter", entry[0], entry[1], 15.0, Vector3(1.6, 0.75, 1.6))
	_solid_prop(props, "lava_crates", "CratesW", Vector3(-17.8, 0, 1.0), 80.0, Vector3(1.8, 1.3, 1.2))
	_solid_prop(props, "lava_crates", "CratesE", Vector3(21.5, 0, 16.8), 200.0, Vector3(1.8, 1.3, 1.2))
	_solid_prop(props, "lava_surf_rack", "SurfRack", Vector3(-15.0, 0, 17.0), 0.0, Vector3(2.4, 1.6, 0.8))
	_prop(props, "lava_signpost", "Signpost", Vector3(4.6, 0, 7.4), 20.0, Vector3(0.2, 3.0, 0.2))
	_post(props, "SignpostCollision", 0.12, 3.0, Vector3(4.6, 0, 7.4))
	# Palms (trunks collide; the crowns are out of reach).
	var palms := [
		[Vector3(-22.0, 0, -6.5), 0.0, "lava_palm"], [Vector3(-21.5, 0, 21.0), 70.0, "lava_palm"], [Vector3(22.5, 0, 21.5), 200.0, "lava_palm_b"],
		[Vector3(22.0, 0, -8.0), 140.0, "lava_palm_b"], [Vector3(-10.0, 0, 20.5), 250.0, "lava_palm"], [Vector3(11.0, 0, 20.0), 300.0, "lava_palm"],
		[Vector3(-9.5, 0, -7.0), 20.0, "lava_palm_b"], [Vector3(15.5, 0, -2.0), 100.0, "lava_palm"],
		[Vector3(-19.0, TERRACE_Y, -24.5), 40.0, "lava_palm_b"], [Vector3(19.5, TERRACE_Y, -16.2), 230.0, "lava_palm"],
		[Vector3(-12.0, TERRACE_Y, -16.0), 160.0, "lava_palm"],
	]
	i = 0
	for p in palms:
		var tree := _prop(dressing, p[2], "Palm%d" % i, p[0], p[1], Vector3(1, 8, 1))
		_late(tree, "res://scripts/props/ambient_motion.gd", {"rock_degrees": 1.2, "bob_seconds": 5.0 + (i % 3)})
		_post(props, "Palm%dTrunk" % i, 0.32, 3.5, p[0])
		i += 1
	# Torches with live flames round the plaza (a few carry a light).
	var torches := [
		[Vector3(-3.4, 0, -4.8), true], [Vector3(3.4, 0, -4.8), false], [Vector3(-16.0, 0, -3.4), false], [Vector3(10.0, 0, -3.8), true],
		[Vector3(-7.0, 0, 15.0), false], [Vector3(7.0, 0, 15.8), false], [Vector3(-19.5, 0, 6.0), true], [Vector3(15.0, 0, 15.5), true],
	]
	i = 0
	for t in torches:
		var p: Vector3 = t[0]
		_prop(dressing, "lava_torch", "Torch%02d" % i, p, i * 31.0, Vector3(0.3, 2.5, 0.3))
		_post(props, "Torch%02dPost" % i, 0.13, 2.5, p)
		_player_block(props, "Torch%02dCap" % i, Vector3(0.6, 2.0, 0.6), p + Vector3(0, 3.6, 0))
		_fire(dressing, "Torch%02dFlame" % i, p + Vector3(0, 2.52, 0), 0.75, t[1])
		i += 1
	_build_string_lights()


## Festoon lights strung between the bar, the station mast and the springs.
func _build_string_lights() -> void:
	var holder := Node3D.new()
	holder.name = "StringLights"
	dressing.add_child(holder)
	var spans := [
		[Vector3(-9.7, 3.3, 2.0), Vector3(-2.0, 4.6, 2.0)], [Vector3(2.0, 4.6, 2.4), Vector3(9.4, 3.0, 4.0)],
		[Vector3(-3.4, 2.7, -4.8), Vector3(3.4, 2.7, -4.8)], [Vector3(-7.0, 2.7, 15.0), Vector3(7.0, 2.7, 15.8)],
	]
	var colors := [Color(1.0, 0.45, 0.7), Color(1.0, 0.8, 0.35), Color(0.3, 0.95, 0.85)]
	var i := 0
	for s in spans:
		_garland(holder, "Garland%d" % i, s[0], s[1], colors)
		i += 1


func _garland(parent: Node3D, garland_name: String, a: Vector3, b: Vector3, colors: Array) -> void:
	var count := int(a.distance_to(b) / 0.8)
	var sag := 0.6
	var bulb := SphereMesh.new()
	bulb.radius = 0.07
	bulb.height = 0.14
	bulb.radial_segments = 6
	bulb.rings = 3
	for c in colors.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var mesh := bulb.duplicate() as SphereMesh
		mesh.material = _mat("garland%d" % c, colors[c], 0.4, colors[c], 3.2)
		mm.mesh = mesh
		var pts: Array[Vector3] = []
		for k in count:
			if k % colors.size() == c:
				var t := (k + 0.5) / count
				pts.append(a.lerp(b, t) - Vector3.UP * sag * 4.0 * t * (1.0 - t))
		mm.instance_count = pts.size()
		for k in pts.size():
			mm.set_instance_transform(k, Transform3D(Basis(), pts[k]))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d" % [garland_name, c]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)


# ---------------------------------------------------------------------------
# Boardwalk: deck strip along the south, the beach railing and the stairs down
# ---------------------------------------------------------------------------

func _build_boardwalk() -> void:
	var walk := Node3D.new()
	walk.name = "Boardwalk"
	geo.add_child(walk)
	var deck := _textured("deck", "lava_deck", 0.3, 0.75)
	_visual_box(dressing, "Deck", Vector3(2.0 * ARENA_X + 6.0, 0.1, 8.6), Vector3(0, -0.03, ARENA_Z1 - 4.0), deck)
	_visual_box(dressing, "DeckEdge", Vector3(2.0 * ARENA_X + 6.0, 0.3, 0.4), Vector3(0, -0.12, ARENA_Z1 - 8.3), _mat("deck_edge", Color(0.3, 0.18, 0.14), 0.8))
	# Beach railing with a gap at the top of the stairs.
	_fence_run(walk, "RailSouthW", Vector3(-ARENA_X - 3.0, 0, ARENA_Z1 + 0.3), Vector3(BEACH_STAIRS_X - 2.0, 0, ARENA_Z1 + 0.3))
	_fence_run(walk, "RailSouthE", Vector3(BEACH_STAIRS_X + 2.0, 0, ARENA_Z1 + 0.3), Vector3(ARENA_X + 3.0, 0, ARENA_Z1 + 0.3))
	# Stairs down to the beach (a ramp under visual steps).
	var run := 7.0
	var top := ARENA_Z1 + 0.2
	var body := StaticBody3D.new()
	body.name = "BeachStairs"
	walk.add_child(body)
	var length := sqrt(run * run + BEACH_Y * BEACH_Y)
	var angle := atan2(-BEACH_Y, run)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(3.6, 0.4, length + 0.4)
	shape.shape = box
	shape.position = Vector3(BEACH_STAIRS_X, BEACH_Y * 0.5 - 0.17, top + run * 0.5)
	shape.rotation.x = angle
	body.add_child(shape)
	var steps := 12
	for k in steps:
		var h := -(k + 1) * (-BEACH_Y / steps)
		var mi := MeshInstance3D.new()
		mi.name = "Step%d" % k
		mi.mesh = _box_mesh(Vector3(3.6, 0.3, run / steps + 0.02), deck)
		mi.position = Vector3(BEACH_STAIRS_X, h + (-BEACH_Y / steps) - 0.15, top + run / steps * (k + 0.5))
		body.add_child(mi)
	for s in [-1.0, 1.0]:
		var x: float = BEACH_STAIRS_X + s * 1.95
		_visual_box(dressing, "StairWall%d" % int(s), Vector3(0.3, 3.4, run + 0.4), Vector3(x, BEACH_Y * 0.5 + 0.2, top + run * 0.5), _textured("terrain_rock", "lava_rock", 0.08, 0.95))
		_collider(walk, "StairWallCollision%d" % int(s), Vector3(0.3, 4.0, run + 0.4), Vector3(x, BEACH_Y * 0.5 + 0.5, top + run * 0.5))
	_prop(dressing, "lava_torch", "StairTorchW", Vector3(BEACH_STAIRS_X - 2.4, 0, ARENA_Z1 - 0.4), 0.0, Vector3(0.3, 2.5, 0.3))
	_fire(dressing, "StairTorchWFlame", Vector3(BEACH_STAIRS_X - 2.4, 2.52, ARENA_Z1 - 0.4), 0.7, false)
	_prop(dressing, "lava_torch", "StairTorchE", Vector3(BEACH_STAIRS_X + 2.4, 0, ARENA_Z1 - 0.4), 0.0, Vector3(0.3, 2.5, 0.3))
	_fire(dressing, "StairTorchEFlame", Vector3(BEACH_STAIRS_X + 2.4, 2.52, ARENA_Z1 - 0.4), 0.7, false)
	# Beach dressing below the railing.
	for i in 4:
		_prop(dressing, "lava_lounger", "BeachLounger%d" % i, Vector3(-16.0 + i * 3.0, BEACH_Y - 0.1, 31.0 + (i % 2)), 170.0 + i * 8.0, Vector3(0.8, 0.6, 2.0))
	_prop(dressing, "lava_parasol", "BeachParasolA", Vector3(-11.0, BEACH_Y - 0.1, 33.0), 0.0, Vector3(3, 2.7, 3))
	_prop(dressing, "lava_parasol", "BeachParasolB", Vector3(-4.0, BEACH_Y - 0.15, 34.5), 40.0, Vector3(3, 2.7, 3))
	_prop(dressing, "lava_surf_rack", "BeachSurf", Vector3(6.0, BEACH_Y - 0.15, 33.0), 190.0, Vector3(2.4, 1.6, 0.8))


# ---------------------------------------------------------------------------
# Zombie entrances (all beyond the player boundary)
# ---------------------------------------------------------------------------

func _build_entrances() -> void:
	var e := Node3D.new()
	e.name = "Entrances"
	geo.add_child(e)
	# 1. Observatory (NW terrace): the door faces the terrace.
	var obs := Vector3(-15.0, TERRACE_Y, -31.2)
	_prop(e, "lava_observatory", "Observatory", obs, 0.0, Vector3(9, 9, 9))
	_collider(e, "ObsBack", Vector3(9.6, 5.0, 5.4), obs + Vector3(0, 2.5, -2.0))
	_collider(e, "ObsCheekW", Vector3(3.2, 5.0, 4.4), obs + Vector3(-3.2, 2.5, 2.2))
	_collider(e, "ObsCheekE", Vector3(3.2, 5.0, 4.4), obs + Vector3(3.2, 2.5, 2.2))
	_collider(e, "ObsPier", Vector3(1.4, 3.0, 1.4), obs + Vector3(0, 1.5, -0.6))
	# 2. Funicular station (NE terrace): the tram car arrives inside.
	var fun := Vector3(17.0, TERRACE_Y, -30.0)
	_prop(e, "lava_funicular", "Funicular", fun, 0.0, Vector3(7, 5, 8))
	_collider(e, "FunWallW", Vector3(0.6, 4.6, 8.2), fun + Vector3(-3.5, 2.3, -3.5))
	_collider(e, "FunWallE", Vector3(0.6, 4.6, 8.2), fun + Vector3(3.5, 2.3, -3.5))
	_collider(e, "FunCar", Vector3(2.6, 3.4, 4.8), fun + Vector3(0, 1.7, -3.1))
	_collider(e, "FunBack", Vector3(7.0, 4.6, 0.6), fun + Vector3(0, 2.3, -7.6))
	# 3. Lava-tube cave (west): its mouth opens east.
	var cave := Vector3(-30.5, 0.0, 2.0)
	_prop(e, "lava_cave", "LavaTube", cave, 90.0, Vector3(8, 6, 8))
	_collider(e, "CaveN", Vector3(10.0, 6.0, 2.6), cave + Vector3(-3.0, 3.0, -4.6))
	_collider(e, "CaveS", Vector3(10.0, 6.0, 2.6), cave + Vector3(-3.0, 3.0, 4.6))
	_collider(e, "CaveBack", Vector3(1.0, 6.0, 8.0), cave + Vector3(-8.6, 3.0, 0))
	# 4. Staff hut (south-west): its door opens east.
	var hut := Vector3(-28.4, 0.0, 15.5)
	_prop(e, "lava_staff_hut", "StaffHut", hut, 90.0, Vector3(6, 4.5, 5))
	_collider(e, "HutBack", Vector3(0.5, 3.2, 6.2), hut + Vector3(-2.6, 1.6, 0))
	_collider(e, "HutN", Vector3(5.2, 3.2, 0.5), hut + Vector3(0, 1.6, -3.0))
	_collider(e, "HutS", Vector3(5.2, 3.2, 0.5), hut + Vector3(0, 1.6, 3.0))
	_collider(e, "HutFrontN", Vector3(0.5, 3.2, 1.6), hut + Vector3(2.5, 1.6, -2.25))
	_collider(e, "HutFrontS", Vector3(0.5, 3.2, 1.6), hut + Vector3(2.5, 1.6, 2.25))
	# 5. Beach stairs (south-east): the landing is built with the boardwalk.
	# 6. Jungle trail (east): a carved gate where the path leaves the palms.
	var gate := Vector3(25.2, 0.0, -1.0)
	_prop(e, "lava_gate", "JungleGate", gate, -90.0, Vector3(7, 4.6, 0.6))
	_post(e, "GatePostN", 0.42, 4.2, gate + Vector3(0, 0, -3.1))
	_post(e, "GatePostS", 0.42, 4.2, gate + Vector3(0, 0, 3.1))
	_collider(e, "TrailFloor", Vector3(14.0, 1.0, 6.0), Vector3(32.0, -0.5, -1.0))


# ---------------------------------------------------------------------------
# Boundary: railings, cliffs and the invisible player-only walls
# ---------------------------------------------------------------------------

func _build_boundary() -> void:
	var f := Node3D.new()
	f.name = "Boundary"
	geo.add_child(f)
	# West: rail between the river and the cave, cave to hut, hut to the beach.
	_fence_run(f, "RailWestN", Vector3(-ARENA_X - 0.4, 0, -9.0), Vector3(-ARENA_X - 0.4, 0, -2.6))
	_fence_run(f, "RailWestMid", Vector3(-ARENA_X - 0.4, 0, 6.6), Vector3(-ARENA_X - 0.4, 0, 12.0))
	_fence_run(f, "RailWestS", Vector3(-ARENA_X - 0.4, 0, 19.0), Vector3(-ARENA_X - 0.4, 0, ARENA_Z1 + 0.3))
	# East: rail either side of the jungle gate.
	_fence_run(f, "RailEastN", Vector3(ARENA_X + 0.6, 0, -9.0), Vector3(ARENA_X + 0.6, 0, -4.4))
	_fence_run(f, "RailEastS", Vector3(ARENA_X + 0.6, 0, 2.4), Vector3(ARENA_X + 0.6, 0, ARENA_Z1 + 0.3))
	# Terrace ends and back: railings and basalt.
	_fence_run(f, "TerraceRailW", Vector3(-ARENA_X - 0.4, TERRACE_Y, TERRACE_Z1), Vector3(-ARENA_X - 0.4, TERRACE_Y, TERRACE_BACK))
	_fence_run(f, "TerraceRailE", Vector3(ARENA_X + 0.4, TERRACE_Y, TERRACE_Z1), Vector3(ARENA_X + 0.4, TERRACE_Y, TERRACE_BACK))
	_fence_run(f, "TerraceRailBackW", Vector3(-ARENA_X - 0.4, TERRACE_Y, TERRACE_BACK - 0.4), Vector3(-19.0, TERRACE_Y, TERRACE_BACK - 0.4))
	_fence_run(f, "TerraceRailBackMid", Vector3(-11.0, TERRACE_Y, TERRACE_BACK - 0.4), Vector3(13.0, TERRACE_Y, TERRACE_BACK - 0.4))
	_fence_run(f, "TerraceRailBackE", Vector3(21.0, TERRACE_Y, TERRACE_BACK - 0.4), Vector3(ARENA_X + 0.4, TERRACE_Y, TERRACE_BACK - 0.4))
	# Cliffs of basalt columns framing the shelf.
	var cliffs := [
		[Vector3(-33.0, 0.0, -4.0), 90.0, 1.0], [Vector3(-33.0, 0.0, 26.0), 80.0, 0.9], [Vector3(34.0, 0.0, 9.0), -90.0, 1.0],
		[Vector3(33.0, 0.0, 24.0), -100.0, 0.8], [Vector3(-36.0, TERRACE_Y, -26.0), 90.0, 1.2], [Vector3(36.0, TERRACE_Y, -22.0), -90.0, 1.2],
		[Vector3(-31.0, 0.0, 10.0), 95.0, 0.6],
	]
	var i := 0
	for c in cliffs:
		var cliff := _prop(dressing, "lava_cliff", "Cliff%d" % i, c[0], c[1], Vector3(16, 10, 6))
		cliff.scale = Vector3(c[2], c[2] * 0.6, c[2])
		i += 1
	# Player-only walls.
	var walls := _player_walls()
	var h := 9.0
	_player_wall(walls, "West", Vector3(-ARENA_X, 0, -9.4), Vector3(-ARENA_X, 0, ARENA_Z1), h)
	_player_wall(walls, "East", Vector3(ARENA_X, 0, -9.4), Vector3(ARENA_X, 0, ARENA_Z1), h)
	_player_wall(walls, "South", Vector3(-ARENA_X, 0, ARENA_Z1), Vector3(ARENA_X, 0, ARENA_Z1), h)
	_player_wall(walls, "TerraceW", Vector3(-ARENA_X, 0, TERRACE_Z1), Vector3(-ARENA_X, 0, TERRACE_BACK), h + 2.0)
	_player_wall(walls, "TerraceE", Vector3(ARENA_X, 0, TERRACE_Z1), Vector3(ARENA_X, 0, TERRACE_BACK), h + 2.0)
	_player_wall(walls, "TerraceBack", Vector3(-ARENA_X, 0, TERRACE_BACK), Vector3(ARENA_X, 0, TERRACE_BACK), h + 2.0)
	# The river: walls above both banks, open only where the bridges cross.
	for span in _kerb_spans(-ARENA_X, ARENA_X):
		_player_wall(walls, "RiverSouth%d" % int(span.x), Vector3(span.x, 0, KERB_Z), Vector3(span.y, 0, KERB_Z), h)
		_player_wall(walls, "RiverNorth%d" % int(span.x), Vector3(span.x, 0, TERRACE_Z1 + 0.35), Vector3(span.y, 0, TERRACE_Z1 + 0.35), h + 2.0)
	_player_wall(walls, "RiverEndW", Vector3(-ARENA_X, 0, KERB_Z), Vector3(-ARENA_X, 0, TERRACE_Z1), h + 2.0)
	_player_wall(walls, "RiverEndE", Vector3(ARENA_X, 0, KERB_Z), Vector3(ARENA_X, 0, TERRACE_Z1), h + 2.0)


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


## A run of bamboo railing modules with one collision box (blocks walking, not jumping).
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
	body.add_child(_module_row("Modules", "lava_rail", length, 2.5))


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


# ---------------------------------------------------------------------------
# Lights
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	var lights := Node3D.new()
	lights.name = "WarmLights"
	level.add_child(lights)
	# Lava glow along the river (warm uplight on the banks and bridges).
	for x in [-18.0, -6.0, 6.0, 18.0]:
		_omni(lights, "RiverGlow%d" % int(x), Vector3(x, 0.6, (RIVER_Z0 + RIVER_Z1) * 0.5), Color(1.0, 0.42, 0.14), 2.2, 9.0)
	_omni(lights, "BarGlow", BAR + Vector3(0, 2.6, 0.4), Color(1.0, 0.6, 0.35), 1.4, 8.0)
	_omni(lights, "HeadGlow", Vector3(0, TERRACE_Y + 3.0, -21.0), Color(1.0, 0.45, 0.2), 1.6, 9.0)
	_omni(lights, "CaveGlow", Vector3(-27.0, 2.0, 2.0), Color(1.0, 0.4, 0.15), 1.4, 8.0)
	_omni(lights, "FalLGlow", Vector3(36.0, 3.0, -11.8), Color(1.0, 0.45, 0.15), 2.5, 16.0)


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


## Torch flame (crossed quads, the shared fire shader) with an optional flickering light.
func _fire(parent: Node3D, fire_name: String, pos: Vector3, size: float, with_light: bool) -> void:
	var holder := Node3D.new()
	holder.name = fire_name
	parent.add_child(holder)
	holder.position = pos
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
		var l := _omni(holder, "Light", Vector3(0, 0.7, 0), Color(1.0, 0.56, 0.22), 1.8, 8.0)
		_late(l, "res://scripts/props/frost_flicker.gd", {})


## Rising embers (CPU particles: small additive sparks drifting up).
func _embers(ember_name: String, extents: Vector3, amount: int, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = ember_name
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.55, 0.2, 1.0)
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	quad.material = m
	p.mesh = quad
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents * 0.5
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.4
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	ramp.set_color(1, Color(1.0, 0.2, 0.05, 0.0))
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# ---------------------------------------------------------------------------
# Backdrop: Mount Kahuna and its plume, the sea, islets, palm groves
# ---------------------------------------------------------------------------

func _build_backdrop() -> void:
	var back := Node3D.new()
	back.name = "Backdrop"
	dressing.add_child(back)
	var volcano := _prop(back, "lava_volcano", "MountKahuna", VOLCANO, 0.0, Vector3(500, 175, 500))
	volcano.scale = Vector3(1.15, 1.25, 1.15)
	# The crater's glow and the plume above it.
	var crater_top := VOLCANO + Vector3(0, 175.0 * 1.25 * 0.86, 0)
	for k in 3:
		var quad := QuadMesh.new()
		quad.size = Vector2(230.0, 330.0)
		quad.center_offset = Vector3(0, 165.0, 0)
		var m := ShaderMaterial.new()
		m.shader = load(SHADERS + "lava_smoke.gdshader")
		m.set_shader_parameter("seed", k * 3.1)
		m.set_shader_parameter("opacity", 1.0 - k * 0.1)
		m.set_shader_parameter("smoke_color", Color(0.11, 0.06, 0.14))
		var plume := MeshInstance3D.new()
		plume.name = "Plume%d" % k
		plume.mesh = quad
		plume.material_override = m
		plume.position = crater_top + Vector3((k - 1) * 18.0, -10.0, k * 12.0)
		plume.rotation.y = deg_to_rad(-10.0 + k * 25.0)
		plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plume.add_to_group("lava_plume")
		back.add_child(plume)
	var sparks := _embers("CraterSparks", Vector3(60.0, 10.0, 60.0), 50, 4.0)
	(sparks.mesh as QuadMesh).size = Vector2(1.6, 1.6)
	sparks.initial_velocity_min = 18.0
	sparks.initial_velocity_max = 34.0
	sparks.gravity = Vector3(0, -9.0, 0)
	sparks.spread = 30.0
	sparks.position = crater_top + Vector3(0, 6.0, 0)
	back.add_child(sparks)
	var crater_light := _omni(back, "CraterLight", crater_top + Vector3(0, 30.0, 60.0), Color(1.0, 0.4, 0.15), 6.0, 160.0)
	crater_light.add_to_group("lava_crater_light")
	# The sea and the islets on the horizon.
	var sea := MeshInstance3D.new()
	sea.name = "Ocean"
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000.0, 1600.0)
	sea.mesh = plane
	var om := ShaderMaterial.new()
	om.shader = load(SHADERS + "ocean.gdshader")
	om.set_shader_parameter("near_color", Color(0.1, 0.26, 0.38))
	om.set_shader_parameter("deep_color", Color(0.12, 0.08, 0.26))
	om.set_shader_parameter("horizon_color", Color(0.85, 0.32, 0.45))
	om.set_shader_parameter("glitter_color", Color(1.0, 0.6, 0.38))
	om.set_shader_parameter("sun_direction", Vector2(SUN_DIRECTION.x, SUN_DIRECTION.z).normalized())
	sea.material_override = om
	sea.position = Vector3(0, -3.9, 820.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	back.add_child(sea)
	var isles := [[Vector3(-160, -6, 330), 1.6, 20.0], [Vector3(120, -6, 420), 2.0, 80.0], [Vector3(330, -8, 260), 1.4, 140.0],
		[Vector3(-380, -8, 240), 2.2, 200.0]]
	var i := 0
	for isle in isles:
		_prop(back, "lava_island", "Islet%d" % i, isle[0], isle[2], Vector3(40, 18, 30)).scale = Vector3.ONE * isle[1]
		i += 1
	_build_groves(back)


## Palms on the headlands and the beach outside the arena (one MultiMesh per model).
func _build_groves(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for model in ["lava_palm", "lava_palm_b"]:
		var xforms: Array[Transform3D] = []
		var tries := 0
		while xforms.size() < 45 and tries < 1000:
			tries += 1
			var x := rng.randf_range(-110.0, 110.0)
			var z := rng.randf_range(-70.0, 46.0)
			if absf(x) < 30.0 and z > -36.0:
				continue
			if absf(x) < 44.0 and z > -36.0 and z < 26.0:
				continue
			var y := _terrain_height(x, z) - 0.3
			if y < BEACH_Y - 1.2:
				continue
			var s := rng.randf_range(0.85, 1.35)
			xforms.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s), Vector3(x, y, z)))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _model_mesh(model)
		mm.instance_count = xforms.size()
		for k in xforms.size():
			mm.set_instance_transform(k, xforms[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Grove_" + model
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
	var eruption := Node.new()
	eruption.name = "Eruption"
	level.add_child(eruption)
	_late(eruption, "res://scripts/props/lava_eruption.gd", {})


func _model_mesh(model: String) -> Mesh:
	if _mesh_cache.has(model):
		return _mesh_cache[model]
	var source: Node3D = (load(MODELS + model + ".glb") as PackedScene).instantiate()
	var mesh: Mesh = (source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	source.free()
	_mesh_cache[model] = mesh
	return mesh


# ---------------------------------------------------------------------------
# Exit: the portal on the boardwalk lookout and the torch trail to it
# ---------------------------------------------------------------------------

func _build_exit() -> void:
	var portal: Node3D = (load("res://scenes/props/lava_portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	geo.add_child(portal)
	portal.position = PORTAL
	portal.rotation.y = PI
	var lights := Node3D.new()
	lights.name = "ExitLights"
	level.add_child(lights)
	var a := STATION + Vector3(0.6, 0, 6.8)
	var b := PORTAL + Vector3(0, 0, -2.6)
	var steps := 4
	for k in steps:
		var t := float(k) / (steps - 1)
		for s in [-1.0, 1.0]:
			var pos := a.lerp(b, t) + Vector3(s * 2.3, 0, 0)
			var torch := _prop(lights, "lava_exit_torch", "ExitTorch%02d%s" % [k, "L" if s < 0 else "R"], pos, k * 23.0, Vector3(0.2, 1.3, 0.2))
			_late(torch, "res://scripts/props/lava_exit_torch.gd", {"order": k})


# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(4.0, 0.1, 16.5)
	start.rotation.y = deg_to_rad(6.0)
	start.add_to_group("player_spawn", true)
	level.add_child(start)

	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	var points := {
		"SpawnObservatory": [Vector3(-15.0, TERRACE_Y + 0.1, -28.4), 0.0],
		"SpawnFunicular": [Vector3(17.0, TERRACE_Y + 0.1, -29.2), 0.0],
		"SpawnLavaTube": [Vector3(-31.0, 0.1, 2.0), -90.0],
		"SpawnStaffHut": [Vector3(-28.6, 0.1, 15.5), -90.0],
		"SpawnBeach": [Vector3(BEACH_STAIRS_X, BEACH_Y + 0.1, 33.0), 180.0],
		"SpawnJungle": [Vector3(31.0, 0.1, -1.0), 90.0],
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
	mesh.filter_baking_aabb = AABB(Vector3(-40, BEACH_Y - 1.0, -40), Vector3(80, TERRACE_Y - BEACH_Y + 2.2, 80))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	region.navigation_mesh = _largest_island(mesh)
	print("build_lava_lagoon: navmesh polygons = %d (dropped %d on islands)" % [region.navigation_mesh.get_polygon_count(),
		before - region.navigation_mesh.get_polygon_count()])


## Keeps only the largest connected set of polygons (drops the river bed,
## the tops of props and anything else nothing can reach).
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


func _lava_material(key: String, flow: Vector2, fall: float, scale: float) -> ShaderMaterial:
	if _materials.has("lava_" + key):
		return _materials["lava_" + key]
	var m := ShaderMaterial.new()
	m.resource_name = "LavaFlow_" + key
	m.shader = load(SHADERS + "lava_flow.gdshader")
	m.set_shader_parameter("flow", flow)
	m.set_shader_parameter("fall", fall)
	m.set_shader_parameter("scale", scale)
	_materials["lava_" + key] = m
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


## Invisible upright cylinder collider for posts, poles and trunks.
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


## Instances art/models/<model>.glb (swapping LavaMolten surfaces for the
## animated lava), or a grey stand-in box if it is missing.
func _prop(parent: Node3D, model: String, prop_name: String, pos: Vector3, yaw_degrees: float, placeholder_size: Vector3) -> Node3D:
	var path := MODELS + model + ".glb"
	var node: Node3D
	if ResourceLoader.exists(path):
		node = (load(path) as PackedScene).instantiate()
		_swap_molten(node)
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


## Props with LavaMolten surfaces get the animated lava at runtime (a material
## override on a node inside an imported model would not be saved).
func _swap_molten(node: Node) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m and m.resource_name == "LavaMolten":
				_late(node, "res://scripts/props/lava_molten.gd", {})
				return


func _own(node: Node) -> void:
	for child in node.get_children():
		child.owner = level
		if child.scene_file_path == "":
			_own(child)
