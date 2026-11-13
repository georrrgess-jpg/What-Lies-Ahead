extends SceneTree
## Generator for World 7 "Jungle Expedition" / level "Lost Temple".
##
## Rebuilds scenes/levels/lost_temple.tscn: the jungle basin of a theme-park
## adventure ride gone wild, at golden hour. The stepped Jade Idol temple
## (whose giant carved face has the temple door for a mouth) closes the north;
## its lowest tier is a raised forecourt terrace with stairs and a ramp. A
## waterfall pours off the west cliff into a shallow lagoon where a ride boat
## lies beached; ruin towers and a rope bridge make an eastern high-ground
## loop; the ride's mine-cart track crosses the south past the explorer camp.
## The expedition outfitters hut in the middle is the loadout station. Five
## zombie entrances, dressing, lights, the monsoon weather and a baked
## navigation mesh. The result is an ordinary scene you can keep editing.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_lost_temple.gd
##
## Run it with a renderer (not --headless): the headless renderer keeps no
## MultiMesh instance data, so foliage, track and rails would save empty.
##
## NOTE: running this overwrites hand edits made to lost_temple.tscn.
##
## Layout (metres, top view; -Z = north, toward the temple):
##   - Outfitters hut (loadout station) at (1, 0, 1), ringed by tiki torches.
##   - Temple terrace along the north, 2.4 m up (x -15..15): west ramp, central
##     stairs, and to the east a boardwalk onto the NE ruin tower, a rope bridge
##     south to the SE ruin platform and its stairs down to the camp.
##   - Lagoon and waterfall to the west, the beached boat in the shallows.
##   - Ride track along z = 11 with stalled carts; explorer camp south-east.
##   - Entrances: the idol's mouth (terrace, N), the waterfall cave (W), the
##     jungle trail gate (SW), the ride tunnel (E) and the camp road (SE).
##   - The exit portal waits in the carved exit arch to the south-west.

const OUT_PATH := "res://scenes/levels/lost_temple.tscn"
const MODELS := "res://art/models/"
const TEXTURES := "res://art/textures/"
const SHADERS := "res://art/shaders/"

const STATION := Vector3(1.0, 0.0, 1.0)
const TERRACE_Y := 2.4
const TERRACE_X := 15.0            # half-width of the terrace and tier 1
const TERRACE_FRONT := -18.0
const FACE_Z := -26.0              # the idol face's front plane
const TIER1_FRONT := -26.6
const MOUTH_HALF := 1.7
const MOUTH_TOP := TERRACE_Y + 3.4
const PASSAGE_BACK := -31.8
const LAGOON := Vector3(-16.0, 0.0, -2.0)
const LAGOON_RADII := Vector2(8.5, 6.5)
const FALLS := Vector3(-27.2, 0.0, -2.6)
const TRACK_Z := 11.0
const PORTAL := Vector3(-6.0, 0.0, 21.8)
const BRIDGE_X0 := 19.6
const BRIDGE_X1 := 22.0
## The flat jungle floor (the terrain rises into hills outside it).
const BASIN := Rect2(-31.0, -46.0, 63.0, 80.0)
const ARENA := 24.0
const SUN_DIRECTION := Vector3(-0.74, 0.3, 0.5)     # toward the low golden sun (west-south-west)

var level: Node3D
var geo: Node3D          # collidable geometry (navmesh source)
var dressing: Node3D     # non-colliding scenery
var _materials := {}
var _boxes := {}
var _noise: FastNoiseLite
var _late_scripts: Array = []
var _light_count := 0
var _mesh_cache := {}
## Discs kept clear of scattered foliage: [Vector2 centre, radius].
var _clear: Array = []
## Dirt trails painted into the ground (polylines, XZ).
var _trails: Array = []


func _initialize() -> void:
	level = Node3D.new()
	level.name = "LostTemple"
	_noise = FastNoiseLite.new()
	_noise.seed = 77
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

	_plan_trails()
	_clear.append([Vector2(3.0, 18.0), 3.0])
	_build_ground()
	_build_temple()
	_build_terrace_access()
	_build_ruins()
	_build_lagoon()
	_build_station()
	_build_entrances()
	_build_track()
	_build_camp()
	_build_cover()
	_build_torches()
	_build_boundary()
	_build_foliage()
	_build_backdrop()
	_build_lights()
	_build_weather()
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
	print("build_lost_temple: saved %s (error %d), %d omni lights" % [OUT_PATH, err, _light_count])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: golden-hour sun, teal sky fill, warm haze
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SHADERS + "jungle_sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.68, 0.7)
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.6
	env.tonemap_exposure = 0.96
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.72, 0.5)
	env.fog_density = 0.0032
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.12
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.looking_at(-SUN_DIRECTION.normalized(), Vector3.UP), Vector3(0, 30, 0))
	sun.light_color = Color(1.0, 0.72, 0.46)
	sun.light_energy = 1.9
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_opacity = 0.75
	level.add_child(sun)

	# Sky fill from the east: a cool teal rim on everything facing away from the sun.
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.transform = Transform3D(Basis.looking_at(Vector3(-0.6, -0.45, -0.3).normalized(), Vector3.UP), Vector3(0, 30, 0))
	fill.light_color = Color(0.5, 0.82, 0.86)
	fill.light_energy = 0.3
	fill.shadow_enabled = false
	level.add_child(fill)


# ---------------------------------------------------------------------------
# Ground: collision slab, the painted jungle floor and the hills around
# ---------------------------------------------------------------------------

func _plan_trails() -> void:
	_trails = [
		[Vector2(3, 18), Vector2(2, 12), Vector2(1, 6)],                                      # spawn -> hut
		[Vector2(1, -4), Vector2(0, -9), Vector2(0, -12)],                                     # hut -> stairs
		[Vector2(-4, -1), Vector2(-9, -8), Vector2(-14, -11), Vector2(-20, -11.5), Vector2(-27, -11)],   # cave -> hut
		[Vector2(6, 3), Vector2(12, 7), Vector2(17, 8.5), Vector2(19.5, 10.5)],                   # hut -> camp stairs
		[Vector2(13, 28), Vector2(12.5, 21), Vector2(10, 15), Vector2(6, 7)],                    # camp road
		[Vector2(-28, 15), Vector2(-20, 14), Vector2(-12, 11.5), Vector2(-4, 6)],                # trail gate
		[Vector2(-1, 7), Vector2(-3.5, 14), Vector2(-6, 19.5)],                                  # exit trail
		[Vector2(-13.5, -12), Vector2(-13.5, -16)],                                              # west ramp foot
	]


func _terrain_height(x: float, z: float) -> float:
	var dx := maxf(BASIN.position.x - x, 0.0) + maxf(x - BASIN.end.x, 0.0)
	var dz := maxf(BASIN.position.y - z, 0.0) + maxf(z - BASIN.end.y, 0.0)
	var away := sqrt(dx * dx + dz * dz)
	var n := _noise.get_noise_2d(x, z)
	# Jungle hills rise all round the basin; the west is a steep cliff.
	var rise := 34.0 * (1.0 - exp(-away / 26.0)) + away * 0.06
	if x < BASIN.position.x:
		rise += 10.0 * smoothstep(0.0, 6.0, dx)
	var rough := clampf(away / 10.0, 0.0, 1.0)
	return rise + n * 10.0 * rough


func _trail_weight(p: Vector2) -> float:
	var best := 99.0
	for t in _trails:
		for k in t.size() - 1:
			var a: Vector2 = t[k]
			var b: Vector2 = t[k + 1]
			var ab := b - a
			var u := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * u))
	return 1.0 - smoothstep(1.0, 2.2, best)


func _build_ground() -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	geo.add_child(ground)
	var c := BASIN.get_center()
	_collider(ground, "FloorSlab", Vector3(BASIN.size.x + 10.0, 2.0, BASIN.size.y + 10.0), Vector3(c.x, -1.0, c.y))
	var holder := Node3D.new()
	holder.name = "Terrain"
	dressing.add_child(holder)
	var floor_mat := ShaderMaterial.new()
	floor_mat.resource_name = "JungleFloor"
	floor_mat.shader = load(SHADERS + "jungle_ground.gdshader")
	floor_mat.set_shader_parameter("grass_texture", load(TEXTURES + "jungle_grass.png"))
	floor_mat.set_shader_parameter("dirt_texture", load(TEXTURES + "jungle_dirt.png"))
	holder.add_child(_terrain_mesh("TerrainNear", Rect2(-60, -80, 120, 140), 1.0, floor_mat, 0.0, true))
	holder.add_child(_terrain_mesh("TerrainFar", Rect2(-700, -700, 1400, 1400), 16.0, floor_mat, 3.0, false))


## A heightfield patch; `paint` writes the trail (R) and damp shade (G)
## vertex colours. `sink` lowers it inside the near patch so the two never fight.
func _terrain_mesh(mesh_name: String, area: Rect2, cell: float, material: Material, sink: float, paint: bool) -> MeshInstance3D:
	var nx := int(area.size.x / cell)
	var nz := int(area.size.y / cell)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz + 1:
		for i in nx + 1:
			var x := area.position.x + i * cell
			var z := area.position.y + j * cell
			var h := _terrain_height(x, z)
			if sink > 0.0 and x > -58.0 and x < 58.0 and z > -78.0 and z < 58.0:
				h -= sink
			var col := Color(0, 0, 0)
			if paint:
				var p := Vector2(x, z)
				col.r = _trail_weight(p)
				var lag := ((p - Vector2(LAGOON.x, LAGOON.z)) / LAGOON_RADII).length()
				col.r = maxf(col.r, 1.0 - smoothstep(0.9, 1.15, lag))
				col.g = (1.0 - smoothstep(0.0, 4.0, absf(z - TERRACE_FRONT))) * float(absf(x) < TERRACE_X) * 0.5
				col.g = maxf(col.g, (1.0 - smoothstep(0.7, 1.05, lag)) * 0.8)
			else:
				col.g = 0.55
			st.set_color(col)
			st.set_uv(Vector2(i, j))
			st.add_vertex(Vector3(x, h, z))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var cc := a + nx + 1
			var d := cc + 1
			for idx in [a, b, cc, b, d, cc]:
				st.add_index(idx)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------------------
# Temple: stepped sandstone tiers, the idol face and the summit shrine
# ---------------------------------------------------------------------------

func _build_temple() -> void:
	var t := Node3D.new()
	t.name = "Temple"
	geo.add_child(t)
	var stone := _textured("stone", "jungle_stone", 0.42, 0.9)
	var band := _mat("stone_band", Color(0.55, 0.42, 0.34), 0.9)
	var back := -46.0
	# Tier 0: the forecourt terrace (and the floor of the idol's mouth passage).
	_tier(t, "Tier0", Vector3(-TERRACE_X, 0, back), Vector3(TERRACE_X, TERRACE_Y, TERRACE_FRONT), stone, band)
	# Tier 1, cut through by the mouth passage.
	var y0 := TERRACE_Y
	var y1 := TERRACE_Y + 4.2
	_tier(t, "Tier1W", Vector3(-TERRACE_X, y0, back), Vector3(-MOUTH_HALF, y1, TIER1_FRONT), stone, band)
	_tier(t, "Tier1E", Vector3(MOUTH_HALF, y0, back), Vector3(TERRACE_X, y1, TIER1_FRONT), stone, band)
	_tier(t, "Tier1Lintel", Vector3(-MOUTH_HALF, MOUTH_TOP, PASSAGE_BACK), Vector3(MOUTH_HALF, y1, TIER1_FRONT), stone, null)
	_tier(t, "Tier1Back", Vector3(-MOUTH_HALF, y0, back), Vector3(MOUTH_HALF, y1, PASSAGE_BACK), stone, null)
	_tier(t, "Tier2", Vector3(-12.0, y1, back + 2.0), Vector3(12.0, y1 + 5.0, -29.5), stone, band)
	_tier(t, "Tier3", Vector3(-9.0, y1 + 5.0, back + 3.0), Vector3(9.0, y1 + 9.5, -32.5), stone, band)
	_tier(t, "Tier4", Vector3(-6.0, y1 + 9.5, back + 4.0), Vector3(6.0, y1 + 13.0, -35.0), stone, band)
	_prop(t, "jungle_idol_face", "IdolFace", Vector3(0, TERRACE_Y, FACE_Z), 0.0, Vector3(10, 10, 1.4))
	_prop(t, "jungle_shrine", "Shrine", Vector3(0, y1 + 13.0, -39.0), 0.0, Vector3(7, 7, 5)).scale = Vector3.ONE * 1.35
	for x in [-4.6, 4.6]:
		_prop(t, "jungle_brazier", "SummitBrazier%d" % int(x), Vector3(x, y1 + 13.0, -35.8), 0.0, Vector3(1, 1.4, 1)).scale = Vector3.ONE * 1.3
		_fire(t, "SummitFire%d" % int(x), Vector3(x, y1 + 13.0 + 1.9, -35.8), 1.8, false)
	# Mouth passage: the player never walks in (the spawn is inside).
	_player_block(t, "MouthBlock", Vector3(MOUTH_HALF * 2.0 + 0.4, 4.0, 0.4), Vector3(0, TERRACE_Y + 2.0, FACE_Z + 0.3))
	# Face slab collision (it stands proud of tier 1).
	_collider(t, "FaceSlabW", Vector3(5.0 - MOUTH_HALF, 8.4, 0.7), Vector3(-(MOUTH_HALF + (5.0 - MOUTH_HALF) * 0.5), TERRACE_Y + 4.2, FACE_Z - 0.35))
	_collider(t, "FaceSlabE", Vector3(5.0 - MOUTH_HALF, 8.4, 0.7), Vector3(MOUTH_HALF + (5.0 - MOUTH_HALF) * 0.5, TERRACE_Y + 4.2, FACE_Z - 0.35))
	_collider(t, "FaceLips", Vector3(MOUTH_HALF * 2.0 + 1.4, 1.0, 0.9), Vector3(0, MOUTH_TOP + 0.5, FACE_Z + 0.2))
	# Terrace braziers and the columns of the old colonnade.
	for x in [-6.0, 6.0]:
		_solid_prop(t, "jungle_brazier", "TerraceBrazier%d" % int(x), Vector3(x, TERRACE_Y, -21.0), 0.0, Vector3(1.1, 1.4, 1.1))
		_fire(t, "TerraceFire%d" % int(x), Vector3(x, TERRACE_Y + 1.45, -21.0), 1.2, false)
	for x in [-12.0, -9.0, 9.0, 12.0]:
		_prop(t, "jungle_column", "TerraceColumn%d" % int(x + 20), Vector3(x, TERRACE_Y, -24.6), 0.0, Vector3(1.3, 4.6, 1.3))
		_post(t, "TerraceColumn%dPost" % int(x + 20), 0.62, 4.6, Vector3(x, TERRACE_Y, -24.6))
	_solid_prop(t, "jungle_rubble", "TerraceRubble", Vector3(-10.5, TERRACE_Y, -20.0), 30.0, Vector3(2.6, 1.2, 1.8))
	_solid_prop(t, "jungle_crates", "TerraceCrates", Vector3(10.6, TERRACE_Y, -20.2), -10.0, Vector3(2.0, 1.6, 1.2))
	# Greenery sprouting from every ledge.
	var ledges := [
		[Vector3(-TERRACE_X, y1, TIER1_FRONT), Vector3(TERRACE_X, y1, TIER1_FRONT)],
		[Vector3(-12.0, y1 + 5.0, -29.5), Vector3(12.0, y1 + 5.0, -29.5)],
		[Vector3(-9.0, y1 + 9.5, -32.5), Vector3(9.0, y1 + 9.5, -32.5)],
		[Vector3(-6.0, y1 + 13.0, -35.0), Vector3(6.0, y1 + 13.0, -35.0)],
		[Vector3(18.3, TERRACE_Y, -19.9), Vector3(23.2, TERRACE_Y, -19.9)],
		[Vector3(17.3, TERRACE_Y, -0.6), Vector3(19.3, TERRACE_Y, -0.6)],
	]
	var xforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for l in ledges:
		var a: Vector3 = l[0]
		var b: Vector3 = l[1]
		var n := int(a.distance_to(b) / 1.6)
		for k in n:
			var p := a.lerp(b, (k + rng.randf()) / n) + Vector3(0, 0, -0.6)
			if absf(p.x) < 5.5 and p.y < y1 + 1.0:
				continue
			if absf(p.x) < 2.6:
				continue
			var s := rng.randf_range(0.7, 1.2)
			xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p))
	_multimesh(dressing, "TempleFerns", "jungle_fern", xforms)


## A tier block: textured stone with a darker cornice band along its top edge.
func _tier(parent: Node3D, tier_name: String, lo: Vector3, hi: Vector3, stone: Material, band: Material) -> void:
	var size := hi - lo
	_box(parent, tier_name, size, (lo + hi) * 0.5, stone)
	if band:
		_visual_box(parent, tier_name + "Cornice", Vector3(size.x + 0.3, 0.32, 0.3), Vector3((lo.x + hi.x) * 0.5, hi.y - 0.16, hi.z + 0.05), band)


# ---------------------------------------------------------------------------
# Terrace access: central stairs, west ramp
# ---------------------------------------------------------------------------

func _build_terrace_access() -> void:
	var a := Node3D.new()
	a.name = "TerraceAccess"
	geo.add_child(a)
	var stone := _textured("stone", "jungle_stone", 0.42, 0.9)
	_stairs(a, "GrandStairs", -3.5, 3.5, TERRACE_FRONT, TERRACE_FRONT + 6.0, stone)
	_ramp(a, "WestRamp", -TERRACE_X, -TERRACE_X + 3.0, TERRACE_FRONT, TERRACE_FRONT + 6.5, stone)
	for x in [-5.5, 5.5]:
		_prop(a, "jungle_column", "StairColumn%d" % int(x + 10), Vector3(x, 0, TERRACE_FRONT + 4.8), 0.0, Vector3(1.3, 4.6, 1.3))
		_post(a, "StairColumn%dPost" % int(x + 10), 0.62, 4.6, Vector3(x, 0, TERRACE_FRONT + 4.8))


const KERB_H := 0.4


## A ramp from the terrace edge (z_top, at deck height) down to the ground (z_bottom).
func _ramp(parent: Node3D, ramp_name: String, x0: float, x1: float, z_top: float, z_bottom: float, material: Material) -> void:
	var run := z_bottom - z_top
	var length := sqrt(run * run + TERRACE_Y * TERRACE_Y)
	var angle := atan2(TERRACE_Y, run)
	var thick := 0.5
	var body := StaticBody3D.new()
	body.name = ramp_name
	parent.add_child(body)
	var normal := Vector3(0, cos(angle), sin(angle))
	body.position = Vector3((x0 + x1) * 0.5, TERRACE_Y * 0.5, (z_top + z_bottom) * 0.5) - normal * thick * 0.5
	body.rotation.x = angle
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, thick, length + 0.3)
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(box.size, material)
	body.add_child(mi)
	var side_x := x1 - 0.1
	var s := MeshInstance3D.new()
	s.name = "Kerb"
	s.mesh = _box_mesh(Vector3(0.2, thick + KERB_H, length + 0.3), _mat("stone_band", Color(0.55, 0.42, 0.34), 0.9))
	s.position = Vector3(side_x - (x0 + x1) * 0.5, KERB_H * 0.5, 0)
	body.add_child(s)
	_kerb(parent, ramp_name + "Kerb", side_x - 0.1, side_x + 0.1, z_top, z_bottom)


func _kerb(parent: Node3D, kerb_name: String, xa: float, xb: float, z_top: float, z_bottom: float) -> void:
	var body := StaticBody3D.new()
	body.name = kerb_name
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var wedge := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for x in [xa, xb]:
		pts.append(Vector3(x, 0.0, z_top))
		pts.append(Vector3(x, TERRACE_Y + KERB_H, z_top))
		pts.append(Vector3(x, KERB_H, z_bottom))
		pts.append(Vector3(x, 0.0, z_bottom))
	wedge.points = pts
	shape.shape = wedge
	body.add_child(shape)


## Visual steps over an invisible ramp (the player and the navmesh use the ramp),
## from the deck edge (z_top) down toward +Z (z_bottom).
func _stairs(parent: Node3D, stairs_name: String, x0: float, x1: float, z_top: float, z_bottom: float, material: Material) -> void:
	var run := z_bottom - z_top
	var length := sqrt(run * run + TERRACE_Y * TERRACE_Y)
	var angle := atan2(TERRACE_Y, run)
	var body := StaticBody3D.new()
	body.name = stairs_name
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, 0.4, length + 0.2)
	shape.shape = box
	var top_mid := Vector3((x0 + x1) * 0.5, TERRACE_Y * 0.5, (z_top + z_bottom) * 0.5)
	shape.position = top_mid - Vector3(0, cos(angle), sin(angle)) * 0.2 - Vector3(0, 0.03, 0)
	shape.rotation.x = angle
	body.add_child(shape)
	var steps := 9
	var rise := TERRACE_Y / steps
	var tread := run / steps
	for k in steps:
		var h := TERRACE_Y - rise * (k + 1)
		var mi := MeshInstance3D.new()
		mi.name = "Step%d" % k
		mi.mesh = _box_mesh(Vector3(x1 - x0, h + rise, tread + 0.02), material)
		mi.position = Vector3((x0 + x1) * 0.5, (h + rise) * 0.5, z_top + tread * (k + 0.5))
		body.add_child(mi)
	for side in [x0 - 0.2, x1 + 0.2]:
		var s := MeshInstance3D.new()
		s.name = "Cheek%s" % ("L" if side < x0 else "R")
		s.mesh = _box_mesh(Vector3(0.4, 0.3 + KERB_H, length + 0.2), _mat("stone_band", Color(0.55, 0.42, 0.34), 0.9))
		s.position = top_mid + Vector3(side - (x0 + x1) * 0.5, KERB_H * 0.5 - 0.1, 0)
		s.rotation.x = angle
		body.add_child(s)
		_kerb(parent, "%sKerb%s" % [stairs_name, "L" if side < x0 else "R"], side - 0.2, side + 0.2, z_top, z_bottom)


# ---------------------------------------------------------------------------
# Ruins: the NE tower, the boardwalk, the rope bridge and the SE platform
# ---------------------------------------------------------------------------

func _build_ruins() -> void:
	var r := Node3D.new()
	r.name = "Ruins"
	geo.add_child(r)
	var stone := _textured("stone", "jungle_stone", 0.42, 0.9)
	var band := _mat("stone_band", Color(0.55, 0.42, 0.34), 0.9)
	var planks := _textured("planks", "jungle_planks", 0.5, 0.8)
	var y := TERRACE_Y
	# NE tower and SE platform: stone blocks with low parapets on their outer sides.
	_tier(r, "NETower", Vector3(18.0, 0, -25.5), Vector3(23.5, y, -19.5), stone, band)
	_tier(r, "SEPlatform", Vector3(17.0, 0, -1.5), Vector3(23.5, y, 5.0), stone, band)
	for p in [["NEParapetN", Vector3(20.75, y + 0.45, -25.3), Vector3(5.5, 0.9, 0.4)], ["NEParapetE", Vector3(23.3, y + 0.45, -22.5), Vector3(0.4, 0.9, 6.0)],
			["SEParapetE", Vector3(23.3, y + 0.45, 1.75), Vector3(0.4, 0.9, 6.5)], ["SEParapetW", Vector3(17.2, y + 0.45, 1.0), Vector3(0.4, 0.9, 5.0)]]:
		_box(r, p[0], p[2], p[1], stone)
	_prop(r, "jungle_column_broken", "NEColumn", Vector3(22.2, y, -24.2), 30.0, Vector3(1.3, 2.2, 1.3))
	_post(r, "NEColumnPost", 0.6, 2.2, Vector3(22.2, y, -24.2))
	_fire(r, "NETorchFire", Vector3(18.4, y + 2.1, -19.9), 0.6, false)
	_prop(r, "jungle_tiki_torch", "NETorch", Vector3(18.4, y, -19.9), 0.0, Vector3(0.3, 2.2, 0.3))
	_prop(r, "jungle_column", "SEColumn", Vector3(22.4, y, 4.0), 15.0, Vector3(1.3, 4.6, 1.3))
	_post(r, "SEColumnPost", 0.62, 4.6, Vector3(22.4, y, 4.0))
	_prop(r, "jungle_tiki_torch", "SETorch", Vector3(18.0, y, 4.4), 0.0, Vector3(0.3, 2.2, 0.3))
	_fire(r, "SETorchFire", Vector3(18.0, y + 2.1, 4.4), 0.6, false)
	_solid_prop(r, "jungle_crates", "SECrates", Vector3(21.6, y, 0.6), 80.0, Vector3(2.0, 1.6, 1.2))
	# Boardwalk from the terrace's east end onto the tower.
	_deck(r, "Boardwalk", Vector3(TERRACE_X, y, -24.0), Vector3(18.0, y, -20.5), planks)
	_fence_run(r, "BoardwalkRailN", Vector3(TERRACE_X, y, -24.1), Vector3(18.0, y, -24.1), "jungle_rope_rail", 2.0)
	_fence_run(r, "BoardwalkRailS", Vector3(TERRACE_X, y, -20.4), Vector3(18.0, y, -20.4), "jungle_rope_rail", 2.0)
	# Rope bridge south from the tower to the platform.
	_deck(r, "Bridge", Vector3(BRIDGE_X0, y, -19.5), Vector3(BRIDGE_X1, y, -1.5), planks, 0.22)
	_fence_run(r, "BridgeRailW", Vector3(BRIDGE_X0 - 0.1, y, -19.5), Vector3(BRIDGE_X0 - 0.1, y, -1.5), "jungle_rope_rail", 2.0)
	_fence_run(r, "BridgeRailE", Vector3(BRIDGE_X1 + 0.1, y, -19.5), Vector3(BRIDGE_X1 + 0.1, y, -1.5), "jungle_rope_rail", 2.0)
	# The SE platform's stairs down to the camp.
	_stairs(r, "CampStairs", 18.0, 21.4, 5.0, 10.4, planks)


## A plank deck (walkable top at `a.y`) on timber posts.
func _deck(parent: Node3D, deck_name: String, a: Vector3, b: Vector3, material: Material, thick := 0.3) -> void:
	var lo := Vector3(minf(a.x, b.x), a.y - thick, minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), a.y, maxf(a.z, b.z))
	_box(parent, deck_name, hi - lo, (lo + hi) * 0.5, material)
	var post_m := _mat("timber", Color(0.36, 0.25, 0.17), 0.85)
	var long_x := (hi.x - lo.x) > (hi.z - lo.z)
	var length := maxf(hi.x - lo.x, hi.z - lo.z)
	var n := maxi(2, int(length / 4.5) + 1)
	for k in n:
		var t := float(k) / (n - 1)
		for side in [0.0, 1.0]:
			var p := Vector3(lerpf(lo.x, hi.x, t) if long_x else lerpf(lo.x, hi.x, side), 0.0, lerpf(lo.z, hi.z, side) if long_x else lerpf(lo.z, hi.z, t))
			p.x = clampf(p.x, lo.x + 0.15, hi.x - 0.15)
			p.z = clampf(p.z, lo.z + 0.15, hi.z - 0.15)
			var post_name := "%sPost%d%d" % [deck_name, k, int(side)]
			_visual_box(parent, post_name, Vector3(0.24, a.y - thick, 0.24), Vector3(p.x, (a.y - thick) * 0.5, p.z), post_m)
			_post(parent, post_name + "Collision", 0.16, a.y - thick, Vector3(p.x, 0, p.z))


# ---------------------------------------------------------------------------
# Lagoon and waterfall
# ---------------------------------------------------------------------------

func _build_lagoon() -> void:
	var lagoon := Node3D.new()
	lagoon.name = "Lagoon"
	dressing.add_child(lagoon)
	var water := MeshInstance3D.new()
	water.name = "Water"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 64
	water.mesh = disc
	water.scale = Vector3(LAGOON_RADII.x, 1.0, LAGOON_RADII.y)
	water.position = LAGOON + Vector3(0, 0.1, 0)
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "jungle_water.gdshader")
	m.set_shader_parameter("centre", Vector2(LAGOON.x, LAGOON.z))
	m.set_shader_parameter("radii", LAGOON_RADII)
	m.set_shader_parameter("falls", Vector2(FALLS.x + 1.2, FALLS.z))
	water.material_override = m
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lagoon.add_child(water)
	# The pool the falls drop into spills past the west wall.
	var pool := MeshInstance3D.new()
	pool.name = "FallsPool"
	pool.mesh = disc
	pool.scale = Vector3(3.6, 1.0, 4.2)
	pool.position = FALLS + Vector3(1.4, 0.11, 0)
	pool.material_override = m
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lagoon.add_child(pool)
	# Shore stones (walkable lumps, no collision) and reeds.
	var xforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for k in 34:
		var a := TAU * k / 34.0 + rng.randf_range(-0.04, 0.04)
		if cos(a) < -0.75:
			continue
		var p := LAGOON + Vector3(cos(a) * LAGOON_RADII.x * 1.03, -0.25, sin(a) * LAGOON_RADII.y * 1.03)
		var s := rng.randf_range(0.25, 0.45)
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.5, s)), p))
	_multimesh(lagoon, "ShoreStones", "jungle_boulder", xforms)
	# The beached ride boat in the shallows (cover).
	var boat := _prop(geo, "jungle_boat", "Boat", LAGOON + Vector3(1.5, 0.0, 0.5), 74.0, Vector3(7, 3, 2.6))
	boat.rotation.z = deg_to_rad(4.0)
	var hull := _collider(geo, "BoatHull", Vector3(6.6, 1.3, 2.3), LAGOON + Vector3(1.5, 0.65, 0.5))
	hull.rotation.y = deg_to_rad(74.0)
	_player_block(geo, "BoatCanopy", Vector3(7.2, 1.0, 3.0), LAGOON + Vector3(1.5, 3.6, 0.5), deg_to_rad(74.0))
	_clear.append([Vector2(LAGOON.x, LAGOON.z), 7.0])
	# Waterfall: a curtain pouring off the cliff into the pool.
	var falls := MeshInstance3D.new()
	falls.name = "Waterfall"
	var quad := QuadMesh.new()
	quad.size = Vector2(5.0, 16.0)
	falls.mesh = quad
	var fm := ShaderMaterial.new()
	fm.shader = load(SHADERS + "jungle_waterfall.gdshader")
	falls.material_override = fm
	# Leaning back against the cliff: the foot in the pool, the lip 15 m up.
	falls.position = FALLS + Vector3(-1.6, 7.8, 0)
	falls.rotation.y = PI * 0.5
	falls.rotation.x = deg_to_rad(-12.0)
	falls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	falls.add_to_group("jungle_waterfall", true)
	lagoon.add_child(falls)


# ---------------------------------------------------------------------------
# Loadout station: the expedition outfitters hut
# ---------------------------------------------------------------------------

func _build_station() -> void:
	var station: Node3D = (load("res://scenes/props/jungle_station.tscn") as PackedScene).instantiate()
	station.name = "Station"
	geo.add_child(station)
	station.position = STATION
	station.rotation.y = deg_to_rad(-15.0)
	_player_block(geo, "StationRoof", Vector3(6.0, 4.0, 5.6), STATION + Vector3(0, 5.6, 0), deg_to_rad(-15.0))
	_clear.append([Vector2(STATION.x, STATION.z), 7.5])


# ---------------------------------------------------------------------------
# Zombie entrances (all beyond the arena boundary)
# ---------------------------------------------------------------------------

func _build_entrances() -> void:
	var e := Node3D.new()
	e.name = "Entrances"
	geo.add_child(e)
	# 2. Waterfall cave (west): a dark hollow in the cliff north of the falls.
	var cave := Vector3(-28.5, 0, -11.0)
	_prop(e, "jungle_cliff", "CaveCliffN", cave + Vector3(-2.5, 0, -6.5), 90.0, Vector3(10, 9, 5)).scale = Vector3(1.2, 1.4, 1.2)
	_prop(e, "jungle_cliff", "CaveCliffS", cave + Vector3(-2.5, 0, 6.0), 90.0, Vector3(10, 9, 5)).scale = Vector3(1.1, 1.6, 1.2)
	_prop(e, "jungle_cliff", "CaveCliffTop", cave + Vector3(-4.0, 4.5, 0), 90.0, Vector3(10, 9, 5)).scale = Vector3(1.0, 1.0, 1.4)
	_visual_box(e, "CaveDark", Vector3(0.3, 5.0, 6.0), cave + Vector3(-5.5, 2.5, 0), _mat("cave_dark", Color(0.05, 0.06, 0.05), 1.0))
	_collider(e, "CaveWallN", Vector3(8.0, 8.0, 1.0), cave + Vector3(-2.0, 4.0, -3.4))
	_collider(e, "CaveWallS", Vector3(8.0, 8.0, 1.0), cave + Vector3(-2.0, 4.0, 3.2))
	_collider(e, "CaveBack", Vector3(1.0, 8.0, 7.0), cave + Vector3(-6.0, 4.0, 0))
	# 3. Ride tunnel (east), where the track leaves the basin.
	var tunnel := Vector3(26.6, 0, TRACK_Z)
	_prop(e, "jungle_tunnel_mouth", "RideTunnel", tunnel, -90.0, Vector3(12, 7, 3))
	_collider(e, "TunnelSideN", Vector3(6.0, 6.0, 0.6), tunnel + Vector3(2.6, 3.0, -2.35))
	_collider(e, "TunnelSideS", Vector3(6.0, 6.0, 0.6), tunnel + Vector3(2.6, 3.0, 2.35))
	_collider(e, "TunnelBack", Vector3(0.6, 6.0, 5.0), tunnel + Vector3(5.6, 3.0, 0))
	_collider(e, "TunnelFaceN", Vector3(3.0, 7.0, 4.5), tunnel + Vector3(1.0, 3.5, -4.9))
	_collider(e, "TunnelFaceS", Vector3(3.0, 7.0, 4.5), tunnel + Vector3(1.0, 3.5, 4.9))
	_post(e, "TunnelPillarN", 0.55, 4.4, tunnel + Vector3(0.3, 0, -2.45))
	_post(e, "TunnelPillarS", 0.55, 4.4, tunnel + Vector3(0.3, 0, 2.45))
	# 4. Jungle trail gate (south-west).
	var gate := Vector3(-25.0, 0, 14.5)
	_prop(e, "jungle_trail_gate", "TrailGate", gate, 90.0, Vector3(8, 6, 1.2))
	_post(e, "TrailGatePostN", 0.62, 4.4, gate + Vector3(0, 0, -3.15))
	_post(e, "TrailGatePostS", 0.62, 4.4, gate + Vector3(0, 0, 3.15))
	# 5. The camp road (south-east): the expedition's gate, a second carved gateway.
	var road := Vector3(13.0, 0, 25.6)
	_prop(e, "jungle_trail_gate", "CampGate", road, 180.0, Vector3(8, 6, 1.2))
	_post(e, "CampGatePostW", 0.62, 4.4, road + Vector3(-3.15, 0, 0))
	_post(e, "CampGatePostE", 0.62, 4.4, road + Vector3(3.15, 0, 0))
	_prop(dressing, "jungle_ride_sign", "RideSign", Vector3(-12.5, 0, 16.6), 150.0, Vector3(6, 4.6, 0.5))
	_post(e, "RideSignPostA", 0.3, 4.6, Vector3(-12.5, 0, 16.6) + Basis(Vector3.UP, deg_to_rad(150.0)) * Vector3(-2.7, 0, 0))
	_post(e, "RideSignPostB", 0.3, 4.6, Vector3(-12.5, 0, 16.6) + Basis(Vector3.UP, deg_to_rad(150.0)) * Vector3(2.7, 0, 0))


# ---------------------------------------------------------------------------
# Ride track with stalled carts
# ---------------------------------------------------------------------------

func _build_track() -> void:
	var points: Array[Vector3] = []
	var x := 31.0
	while x > -6.0:
		points.append(Vector3(x, 0.0, TRACK_Z))
		x -= 2.0
	# Curve into the old loading platform south-west.
	for k in 6:
		var a := k / 5.0 * PI * 0.4
		points.append(Vector3(-6.0 - sin(a) * 6.0, 0.0, TRACK_Z + (1.0 - cos(a)) * 6.0))
	var xforms: Array[Transform3D] = []
	for k in points.size() - 1:
		var a := points[k]
		var b := points[k + 1]
		var dir := (b - a).normalized()
		var turn := Basis(Vector3.UP, atan2(-dir.z, dir.x))
		var basis := Basis(turn.x * a.distance_to(b) / 2.0, turn.y, turn.z)
		xforms.append(Transform3D(basis, (a + b) * 0.5))
	_multimesh(dressing, "Track", "jungle_track", xforms)
	var end := points[-1]
	_box(geo, "TrackBuffer", Vector3(0.8, 1.0, 1.8), end + Vector3(-0.6, 0.5, 0.6), _mat("ride_red", Color(0.85, 0.28, 0.23), 0.5))
	for c in [[Vector3(15.5, 0, TRACK_Z), 0.0], [Vector3(6.5, 0, TRACK_Z), 0.0], [Vector3(-7.6, 0, TRACK_Z + 0.2), -8.0]]:
		_solid_prop(geo, "jungle_mine_cart", "Cart%d" % int(c[0].x + 10), c[0], c[1], Vector3(2.2, 1.3, 1.4))
		_clear.append([Vector2(c[0].x, c[0].z), 2.0])


# ---------------------------------------------------------------------------
# Explorer camp (south-east)
# ---------------------------------------------------------------------------

func _build_camp() -> void:
	var camp := Node3D.new()
	camp.name = "Camp"
	geo.add_child(camp)
	for t in [["TentA", Vector3(11.0, 0, 17.5), 200.0], ["TentB", Vector3(17.5, 0, 15.2), 150.0], ["TentC", Vector3(7.6, 0, 21.4), 175.0]]:
		_solid_prop(camp, "jungle_tent", t[0], t[1], t[2], Vector3(2.6, 2.3, 3.0))
		_clear.append([Vector2(t[1].x, t[1].z), 2.6])
	_solid_prop(camp, "jungle_jeep", "Jeep", Vector3(19.5, 0, 20.5), -35.0, Vector3(2.0, 1.8, 4.3))
	_prop(camp, "jungle_radio_mast", "RadioMast", Vector3(22.0, 0, 15.8), 20.0, Vector3(1, 10, 1))
	_post(camp, "RadioMastPost", 0.45, 9.0, Vector3(22.0, 0, 15.8))
	_solid_prop(camp, "jungle_camp_table", "CampTable", Vector3(13.4, 0, 14.0), 15.0, Vector3(1.6, 0.9, 0.9))
	_solid_prop(camp, "jungle_crates", "CampCrates", Vector3(15.6, 0, 21.8), 20.0, Vector3(2.0, 1.6, 1.2))
	# Campfire ring with log seats.
	var fire := Vector3(14.6, 0, 18.6)
	var stones := _mat("stone_band", Color(0.55, 0.42, 0.34), 0.9)
	for k in 8:
		var a := TAU * k / 8.0
		_visual_box(camp, "FireStone%d" % k, Vector3(0.35, 0.25, 0.3), fire + Vector3(cos(a) * 0.75, 0.12, sin(a) * 0.75), stones)
	_fire(camp, "Campfire", fire + Vector3(0, 0.1, 0), 1.0, true)
	for k in [Vector3(-2.0, 0, 0.6), Vector3(1.6, 0, 1.4)]:
		_box(camp, "LogSeat%d" % int(k.x), Vector3(1.6, 0.45, 0.45), fire + k + Vector3(0, 0.22, 0), _mat("timber", Color(0.36, 0.25, 0.17), 0.85))
	_clear.append([Vector2(fire.x, fire.z), 3.0])
	_clear.append([Vector2(19.5, 20.5), 3.0])


# ---------------------------------------------------------------------------
# Cover around the forecourt
# ---------------------------------------------------------------------------

func _build_cover() -> void:
	var c := Node3D.new()
	c.name = "Cover"
	geo.add_child(c)
	_solid_prop(c, "jungle_idol_head", "FallenIdol", Vector3(-6.5, 0, -8.0), 25.0, Vector3(2.8, 2.2, 2.4))
	_solid_prop(c, "jungle_rubble", "RubbleNE", Vector3(7.5, 0, -8.5), -15.0, Vector3(2.6, 1.2, 1.8))
	_solid_prop(c, "jungle_rubble", "RubbleSW", Vector3(-6.0, 0, 7.6), 40.0, Vector3(2.6, 1.2, 1.8))
	_solid_prop(c, "jungle_crates", "CratesE", Vector3(9.4, 0, 3.2), 10.0, Vector3(2.0, 1.6, 1.2))
	_solid_prop(c, "jungle_crates", "CratesW", Vector3(-7.4, 0, 1.8), 75.0, Vector3(2.0, 1.6, 1.2))
	for p in [["ColumnBrokenE", Vector3(12.5, 0, -5.0), 10.0], ["ColumnBrokenW", Vector3(-13.0, 0, 8.4), 130.0], ["ColumnBrokenN", Vector3(-1.5, 0, -14.0), 70.0]]:
		_prop(c, "jungle_column_broken", p[0], p[1], p[2], Vector3(1.3, 2.2, 1.3))
		_post(c, p[0] + "Post", 0.62, 2.2, p[1])
	for b in [["BoulderNE", Vector3(13.5, 0, -14.5), 1.1], ["BoulderS", Vector3(-15.5, 0, 20.5), 1.2], ["BoulderE", Vector3(23.0, 0, 6.9), 0.9]]:
		var rock := _prop(c, "jungle_boulder", b[0], b[1], b[0].length() * 40.0, Vector3(2.4, 1.3, 2.4))
		rock.scale = Vector3.ONE * b[2]
		_collider(c, b[0] + "Collision", Vector3(2.0, 1.2, 2.0) * b[2], b[1] + Vector3(0, 0.6 * b[2], 0))
	for cl in [[Vector2(-6.5, -8), 2.5], [Vector2(7.5, -8.5), 2.2], [Vector2(-6, 7.6), 2.2], [Vector2(9.4, 3.2), 2.0], [Vector2(-7.4, 1.8), 2.0],
			[Vector2(12.5, -5), 1.6], [Vector2(-13, 8.4), 1.6], [Vector2(-1.5, -14), 1.6], [Vector2(13.5, -14.5), 2.0]]:
		_clear.append(cl)


# ---------------------------------------------------------------------------
# Tiki torches round the plaza
# ---------------------------------------------------------------------------

func _build_torches() -> void:
	var t := Node3D.new()
	t.name = "Torches"
	geo.add_child(t)
	var spots := [Vector3(-4.5, 0, -4.5), Vector3(6.5, 0, -4.0), Vector3(7.5, 0, 6.5), Vector3(-5.2, 0, 6.8),
		Vector3(-3.6, 0, -16.6), Vector3(3.6, 0, -16.6), Vector3(-8.0, 0, 14.0), Vector3(4.5, 0, 14.6)]
	var i := 0
	for p in spots:
		_prop(t, "jungle_tiki_torch", "Tiki%d" % i, p, i * 41.0, Vector3(0.3, 2.2, 0.3))
		_post(t, "Tiki%dPost" % i, 0.12, 2.2, p)
		_fire(t, "Tiki%dFire" % i, p + Vector3(0, 2.15, 0), 0.55, false)
		_player_block(t, "Tiki%dCap" % i, Vector3(0.5, 2.0, 0.5), p + Vector3(0, 3.2, 0))
		i += 1


# ---------------------------------------------------------------------------
# Boundary: the jungle wall, bamboo fences and the invisible player walls
# ---------------------------------------------------------------------------

func _build_boundary() -> void:
	var f := Node3D.new()
	f.name = "Boundary"
	geo.add_child(f)
	_fence_run(f, "FenceSouthW", Vector3(-24.4, 0, 24.4), Vector3(-9.2, 0, 24.4), "jungle_bamboo_fence", 2.5)
	_fence_run(f, "FenceSouthM", Vector3(-2.8, 0, 24.4), Vector3(9.4, 0, 24.4), "jungle_bamboo_fence", 2.5)
	_fence_run(f, "FenceSouthE", Vector3(16.6, 0, 24.4), Vector3(24.4, 0, 24.4), "jungle_bamboo_fence", 2.5)
	_fence_run(f, "FenceEastS", Vector3(24.4, 0, 14.6), Vector3(24.4, 0, 24.4), "jungle_bamboo_fence", 2.5)
	_fence_run(f, "FenceEastN", Vector3(24.4, 0, -19.0), Vector3(24.4, 0, 7.4), "jungle_bamboo_fence", 2.5)
	_fence_run(f, "FenceWestS", Vector3(-24.4, 0, 18.0), Vector3(-24.4, 0, 24.4), "jungle_bamboo_fence", 2.5)
	_fence_run(f, "FenceWestM", Vector3(-24.4, 0, 6.0), Vector3(-24.4, 0, 11.0), "jungle_bamboo_fence", 2.5)
	_fence_run(f, "FenceNorthW", Vector3(-24.4, 0, -26.4), Vector3(-15.2, 0, -26.4), "jungle_bamboo_fence", 2.5)

	var walls := Node3D.new()
	walls.name = "PlayerWalls"
	level.add_child(walls)
	var h := 9.0
	_player_wall(walls, "West", Vector3(-ARENA, 0, -26.6), Vector3(-ARENA, 0, ARENA), h)
	_player_wall(walls, "South", Vector3(-ARENA, 0, ARENA), Vector3(ARENA, 0, ARENA), h)
	_player_wall(walls, "East", Vector3(ARENA, 0, -25.8), Vector3(ARENA, 0, ARENA), h)
	_player_wall(walls, "NorthW", Vector3(-ARENA, 0, -26.6), Vector3(-TERRACE_X, 0, -26.6), h)
	_player_wall(walls, "NorthE", Vector3(TERRACE_X, 0, -25.8), Vector3(ARENA, 0, -25.8), h + 3.0)
	# Nobody climbs the temple past the terrace.
	_player_wall(walls, "TempleFace", Vector3(-TERRACE_X, 0, TIER1_FRONT + 0.1), Vector3(TERRACE_X, 0, TIER1_FRONT + 0.1), 22.0)


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


## A run of fence modules (`module_len` long, along X in the model) with one collision box.
func _fence_run(parent: Node3D, run_name: String, a: Vector3, b: Vector3, model: String, module_len: float) -> void:
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
	var count := maxi(1, int(round(length / module_len)))
	var step := length / count
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _model_mesh(model)
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(step / module_len, 1, 1)), Vector3(-length * 0.5 + step * (i + 0.5), 0, 0)))
	var modules := MultiMeshInstance3D.new()
	modules.name = "Modules"
	modules.multimesh = mm
	body.add_child(modules)


# ---------------------------------------------------------------------------
# Foliage: palms and giants in the arena, ferns and plants scattered, the
# jungle wall all round
# ---------------------------------------------------------------------------

func _build_foliage() -> void:
	var plants := Node3D.new()
	plants.name = "Plants"
	geo.add_child(plants)
	# Palms inside the arena (trunks collide).
	var palms := [Vector3(-21.0, 0, 8.5), Vector3(-11.0, 0, 20.0), Vector3(16.0, 0, -9.5), Vector3(-20.5, 0, -15.0),
		Vector3(22.5, 0, 22.0), Vector3(-23.0, 0, 23.0), Vector3(9.0, 0, 22.8), Vector3(-17.5, 0, 12.5), Vector3(11.0, 0, -15.5)]
	var i := 0
	for p in palms:
		var palm := _prop(dressing, "jungle_palm", "Palm%d" % i, p, i * 47.0, Vector3(1, 8, 1))
		palm.scale = Vector3.ONE * (0.9 + 0.08 * (i % 3))
		_late(palm, "res://scripts/props/ambient_motion.gd", {"rock_degrees": 0.8, "bob_seconds": 5.0 + i * 0.4})
		_post(plants, "Palm%dTrunk" % i, 0.3, 5.0, p)
		_clear.append([Vector2(p.x, p.z), 1.2])
		i += 1
	# Rainforest giants in the corners.
	for g in [["GiantNW", Vector3(-20.5, 0, -21.5)], ["GiantSW", Vector3(-19.5, 0, 18.5)]]:
		var tree := _prop(dressing, "jungle_canopy_tree", g[0], g[1], 30.0, Vector3(3, 12, 3))
		tree.scale = Vector3.ONE * 1.1
		_post(plants, g[0] + "Trunk", 1.0, 6.0, g[1])
		_player_block(plants, g[0] + "Cap", Vector3(3.0, 6.0, 3.0), g[1] + Vector3(0, 9.0, 0))
		_clear.append([Vector2(g[1].x, g[1].z), 2.5])
	# Ground plants (no collision), kept off the routes, the props and the station ring.
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var kinds := {"jungle_fern": [], "jungle_elephant_ear": [], "jungle_bush": []}
	var tries := 0
	while tries < 2600:
		tries += 1
		var x := rng.randf_range(-24.0, 24.0)
		var z := rng.randf_range(-18.0, 24.0)
		var edge := maxf(absf(x), absf(z)) > 17.0
		if not edge and rng.randf() > 0.12:
			continue
		if not _free(Vector2(x, z), 1.0):
			continue
		if _trail_weight(Vector2(x, z)) > 0.05 or absf(z - TRACK_Z) < 1.8:
			continue
		if x > 16.0 and z > -26.0 and z < 11.0:
			continue          # under the ruins and bridge
		var key: String = ["jungle_fern", "jungle_fern", "jungle_elephant_ear", "jungle_bush"][rng.randi() % 4]
		var s := rng.randf_range(0.8, 1.3)
		(kinds[key] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, 0, z)))
		_clear.append([Vector2(x, z), 0.9])
	for key in kinds:
		var list: Array[Transform3D] = []
		list.assign(kinds[key])
		_multimesh(dressing, "Ground" + key.trim_prefix("jungle_").to_pascal_case(), key, list)
	_build_jungle_wall()


## Dense trees, palms and bushes just outside the arena, hiding the boundary.
func _build_jungle_wall() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var trees: Array[Transform3D] = []
	var palms: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	# Walk the boundary ring a little outside the player walls.
	var ring := [Vector2(-27, -30), Vector2(-27, 30), Vector2(30, 30), Vector2(30, -30)]
	for side in 4:
		var a: Vector2 = ring[side]
		var b: Vector2 = ring[(side + 1) % 4]
		var n := int(a.distance_to(b) / 3.2)
		for k in n:
			var p := a.lerp(b, (k + rng.randf()) / n)
			var out := (p - Vector2(1.5, 0)).normalized()
			p += out * rng.randf_range(0.0, 5.0)
			if _near_gap(p):
				continue
			var y := _terrain_height(p.x, p.y)
			var s := rng.randf_range(0.8, 1.25)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, y - 0.2, p.y))
			if rng.randf() < 0.55:
				trees.append(xf)
			else:
				palms.append(xf)
			for j in 2:
				var q := p - out * rng.randf_range(1.5, 3.5) + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
				if _near_gap(q) or absf(q.x) > 30.0:
					continue
				var bs := rng.randf_range(0.9, 1.5)
				bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(bs, bs, bs)), Vector3(q.x, _terrain_height(q.x, q.y), q.y)))
	_multimesh(dressing, "WallTrees", "jungle_canopy_tree", trees)
	_multimesh(dressing, "WallPalms", "jungle_palm", palms)
	_multimesh(dressing, "WallBushes", "jungle_bush", bushes)


## True near an entrance opening or behind the temple (kept clear of the wall).
func _near_gap(p: Vector2) -> bool:
	for g in [Vector2(-28.5, -11.0), Vector2(26.6, TRACK_Z), Vector2(-25.0, 14.5), Vector2(13.0, 25.6), Vector2(-25.6, -2.2)]:
		if p.distance_to(g) < 5.0:
			return true
	return absf(p.x) < 17.0 and p.y < -26.0


func _free(p: Vector2, radius: float) -> bool:
	for c in _clear:
		if p.distance_to(c[0]) < float(c[1]) + radius:
			return false
	if absf(p.x) < TERRACE_X + 1.0 and p.y < TERRACE_FRONT + 7.0:
		return false
	return true


# ---------------------------------------------------------------------------
# Backdrop: forested hills, cliffs, volcanoes
# ---------------------------------------------------------------------------

func _build_backdrop() -> void:
	var back := Node3D.new()
	back.name = "Backdrop"
	dressing.add_child(back)
	# West cliff wall the falls pour from.
	var cliffs := [[Vector3(-32.0, 0, -24.0), 1.5], [Vector3(-34.5, 0, -2.6), 1.8], [Vector3(-32.5, 0, 9.5), 1.4], [Vector3(-31.0, 0, 22.0), 1.4],
		[Vector3(-34.0, 6.0, -10.0), 1.6]]
	var i := 0
	for c in cliffs:
		_prop(back, "jungle_cliff", "WestCliff%d" % i, c[0], 90.0, Vector3(10, 9, 5)).scale = Vector3.ONE * c[1]
		i += 1
	# Forest on the hills (low-detail canopy and palms, one MultiMesh each).
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var canopy: Array[Transform3D] = []
	var palms: Array[Transform3D] = []
	var tries := 0
	while canopy.size() + palms.size() < 900 and tries < 9000:
		tries += 1
		var x := rng.randf_range(-260.0, 260.0)
		var z := rng.randf_range(-280.0, 240.0)
		if BASIN.grow(4.0).has_point(Vector2(x, z)):
			continue
		var h := _terrain_height(x, z)
		var s := rng.randf_range(1.0, 1.9)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.2), s)), Vector3(x, h - 0.5, z))
		if rng.randf() < 0.78:
			canopy.append(xf)
		else:
			palms.append(xf)
	_multimesh(back, "ForestCanopy", "jungle_canopy_far", canopy)
	_multimesh(back, "ForestPalms", "jungle_palm_far", palms)
	# Volcanic peaks on the horizon.
	var peaks := [[Vector3(-160, -10, -420), 2.4, 10.0], [Vector3(260, -20, -330), 1.7, 80.0], [Vector3(420, -40, 60), 1.4, 150.0],
		[Vector3(-430, -30, 120), 1.6, 220.0], [Vector3(60, -30, -560), 1.9, 300.0]]
	i = 0
	for p in peaks:
		var v := _prop(back, "jungle_volcano", "Volcano%d" % i, p[0], p[2], Vector3(100, 70, 100))
		v.scale = Vector3.ONE * p[1]
		i += 1


# ---------------------------------------------------------------------------
# Lights: warm torch pools and the jade glow (no shadows)
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	var lights := Node3D.new()
	lights.name = "Lights"
	level.add_child(lights)
	_omni(lights, "IdolMouth", Vector3(0, TERRACE_Y + 2.0, FACE_Z + 1.8), Color(0.3, 1.0, 0.7), 1.6, 9.0)
	_omni(lights, "IdolEyes", Vector3(0, TERRACE_Y + 6.6, FACE_Z + 2.5), Color(0.3, 1.0, 0.72), 1.4, 10.0)
	_omni(lights, "StationLamp", STATION + Vector3(0, 3.4, 2.6), Color(1.0, 0.72, 0.4), 1.3, 8.0)
	_omni(lights, "TunnelGlow", Vector3(25.0, 2.5, TRACK_Z), Color(0.3, 1.0, 0.7), 1.2, 7.0)
	_omni(lights, "CaveGlow", Vector3(-26.0, 2.2, -11.0), Color(0.5, 0.95, 0.8), 1.0, 7.0)
	for x in [-6.0, 6.0]:
		var l := _omni(lights, "Brazier%d" % int(x + 10), Vector3(x, TERRACE_Y + 2.4, -21.0), Color(1.0, 0.56, 0.22), 1.8, 8.0)
		_late(l, "res://scripts/props/frost_flicker.gd", {})


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


## Animated flames (crossed quads) and, for the campfire, a flickering light.
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
		var l := _omni(holder, "Light", Vector3(0, 1.1, 0), Color(1.0, 0.56, 0.22), 2.0, 8.5)
		_late(l, "res://scripts/props/frost_flicker.gd", {})


# ---------------------------------------------------------------------------
# Weather: the monsoon twist (rain, storm sky) driven by JungleWeather
# ---------------------------------------------------------------------------

func _build_weather() -> void:
	var rain := MultiMeshInstance3D.new()
	rain.name = "Rain"
	level.add_child(rain)
	var shelters: Array[AABB] = [
		AABB(STATION + Vector3(-2.8, -0.2, -2.6), Vector3(5.6, 6.0, 5.2)),
		AABB(Vector3(-MOUTH_HALF, TERRACE_Y - 0.2, PASSAGE_BACK), Vector3(MOUTH_HALF * 2.0, 3.6, PASSAGE_BACK * -1.0 + FACE_Z)),
		AABB(Vector3(BRIDGE_X0, -0.2, -19.5), Vector3(BRIDGE_X1 - BRIDGE_X0, TERRACE_Y - 0.1, 18.0)),
	]
	_late(rain, "res://scripts/props/jungle_rain.gd", {"shelters": shelters})
	var weather := Node.new()
	weather.name = "Weather"
	level.add_child(weather)
	_late(weather, "res://scripts/props/jungle_weather.gd", {})


# ---------------------------------------------------------------------------
# Exit route: torch stakes from the plaza to the portal in the exit arch
# ---------------------------------------------------------------------------

func _build_exit() -> void:
	var portal: Node3D = (load("res://scenes/props/jungle_portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	geo.add_child(portal)
	portal.position = PORTAL
	portal.rotation.y = PI
	_clear.append([Vector2(PORTAL.x, PORTAL.z), 4.0])
	var lights := Node3D.new()
	lights.name = "ExitLights"
	level.add_child(lights)
	var a := Vector3(-0.6, 0, 8.0)
	var b := Vector3(-5.6, 0, 18.8)
	var dir := (b - a).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var steps := 7
	for k in steps:
		var t := float(k) / (steps - 1)
		var pos := a.lerp(b, t) + side * (1.7 if k % 2 == 0 else -1.7)
		var torch := _prop(lights, "jungle_trail_torch", "TrailTorch%02d" % k, pos, k * 23.0, Vector3(0.2, 1.4, 0.2))
		_late(torch, "res://scripts/props/jungle_trail_light.gd", {"order": k})


# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(3.0, 0.1, 18.0)
	start.rotation.y = deg_to_rad(4.0)
	start.add_to_group("player_spawn", true)
	level.add_child(start)

	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	var points := {
		"SpawnIdolMouth": [Vector3(0.0, TERRACE_Y + 0.1, -29.8), 0.0],
		"SpawnCave": [Vector3(-30.0, 0.1, -11.0), -90.0],
		"SpawnTrailGate": [Vector3(-29.0, 0.1, 14.5), -90.0],
		"SpawnRideTunnel": [Vector3(29.5, 0.1, TRACK_Z), 90.0],
		"SpawnCampRoad": [Vector3(13.0, 0.1, 29.5), 180.0],
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
	# Paths keep 0.75 m off walls and props (see build_summit_lodge.gd).
	mesh.agent_radius = 0.75
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 40.0
	mesh.region_min_size = 14.0
	# Walkable surfaces up to the terrace and the ruins (keeps roofs and tier tops out).
	mesh.filter_baking_aabb = AABB(Vector3(-36, -1.0, -36), Vector3(72, TERRACE_Y + 1.2, 72))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	region.navigation_mesh = _largest_island(mesh)
	print("build_lost_temple: navmesh polygons = %d (dropped %d on islands)" % [region.navigation_mesh.get_polygon_count(),
		before - region.navigation_mesh.get_polygon_count()])


## Keeps only the largest connected set of polygons (drops islands on crates,
## carts and inside props that nothing can reach).
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


## The (single) mesh of art/models/<model>.glb, for MultiMesh batching.
func _model_mesh(model: String) -> Mesh:
	if _mesh_cache.has(model):
		return _mesh_cache[model]
	var source: Node3D = (load(MODELS + model + ".glb") as PackedScene).instantiate()
	var mesh: Mesh = (source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	source.free()
	_mesh_cache[model] = mesh
	return mesh


func _multimesh(parent: Node3D, mm_name: String, model: String, xforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _model_mesh(model)
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mi := MultiMeshInstance3D.new()
	mi.name = mm_name
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


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


## Invisible upright cylinder collider for posts, columns and trunks.
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
