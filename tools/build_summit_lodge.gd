extends SceneTree
## Generator for World 5 "Frostpeak Resort" / level "Summit Lodge".
##
## Rebuilds scenes/levels/summit_lodge.tscn: the snowy summit plateau and the
## mountains around it, the raised lodge terrace with its ramps and stairs,
## the frozen pond, the ski-rental loadout station, five zombie entrances,
## the moving chairlift and gondola, dressing, lights, the aurora and a baked
## navigation mesh. The result is an ordinary scene you can keep editing.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_summit_lodge.gd
##
## Run it with a renderer (not --headless): the headless renderer keeps no
## MultiMesh instance data, so fences, lights and trees would save empty.
##
## NOTE: running this overwrites hand edits made to summit_lodge.tscn.
##
## Layout (metres, top view; -Z = north, uphill toward the lodge):
##   - Ski-rental hut (loadout station) at (6, 0, 3): the hub of the plaza loop.
##   - Frozen pond to its west (slippery); fire-pit lounge, ski racks and
##     snowmobiles to its east. Two routes north: the open pond side and the
##     cover-rich lounge side.
##   - The lodge terrace runs along the north edge, 1.4 m up: west ramp,
##     central stairs and east ramp. Its western half is roofed and walled.
##   - Zombie entrances: gondola station (west), maintenance shed (south-west),
##     chairlift landing (east), the ski run coming down the slope (north-east)
##     and the lodge kitchen door (on the terrace).
##   - The exit portal waits at the south lookout.

const OUT_PATH := "res://scenes/levels/summit_lodge.tscn"
const MODELS := "res://art/models/"
const TEXTURES := "res://art/textures/"
const SHADERS := "res://art/shaders/"

const STATION := Vector3(6.0, 0.0, 3.0)
const POND := Vector3(-10.0, 0.0, 2.0)
const POND_RADII := Vector2(7.5, 6.0)
const TERRACE_Y := 1.4
const TERRACE_X0 := -16.0
const TERRACE_X1 := 12.0
const TERRACE_Z0 := -24.0     # lodge front wall
const TERRACE_Z1 := -15.0     # front edge
const RUN_X0 := 12.0
const RUN_X1 := 22.0
const RUN_Z_BOTTOM := -16.0
const RUN_Z_TOP := -30.0
const RUN_TOP_Y := 4.5
## The flat summit plateau (terrain is flat inside, falls or rises outside).
const PLATEAU := Rect2(-34.0, -40.0, 72.0, 68.0)
## Player-only boundary of the arena.
const ARENA_X0 := -24.0
const ARENA_X1 := 23.5
const ARENA_Z1 := 23.5
const MOON_DIRECTION := Vector3(0.42, 0.62, 0.66)     # toward the key light (south-east, high)
## The chairlift landing (east edge) and the direction its line climbs the mountain.
const LANDING := Vector3(29.4, 0.0, 1.2)
const CHAIR_DIR := Vector3(0.215, 0.0, -0.977)

var level: Node3D
var geo: Node3D          # collidable geometry (navmesh source)
var dressing: Node3D     # non-colliding scenery
var _materials := {}
var _boxes := {}
var _noise: FastNoiseLite
var _late_scripts: Array = []     # [node, script path, {property: value}] attached after the bake
var _light_count := 0


func _initialize() -> void:
	level = Node3D.new()
	level.name = "SummitLodge"
	_noise = FastNoiseLite.new()
	_noise.seed = 51
	_noise.frequency = 0.011
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
	_build_plateau()
	_build_lodge()
	_build_terrace()
	_build_pond()
	_build_station()
	_build_entrances()
	_build_ski_run()
	_build_arena_props()
	_build_fences()
	_build_lifts()
	_build_lights()
	_build_backdrop()
	_build_exit()
	_build_markers()

	# Navigation needs the nodes in the tree for their global transforms.
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
	print("build_summit_lodge: saved %s (error %d), %d omni lights" % [OUT_PATH, err, _light_count])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: twilight sky, moonlight, aurora fill
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load(TEXTURES + "frost_sky.png")
	pano.energy_multiplier = 1.0
	sky.sky_material = pano
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.48, 0.86)
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.4
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.27, 0.25, 0.52)
	env.fog_density = 0.0022
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
	sun.light_color = Color(0.72, 0.78, 1.0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_opacity = 0.7
	level.add_child(sun)

	# Aurora fill from the north: a green-violet rim on everything facing away from the moon.
	var fill := DirectionalLight3D.new()
	fill.name = "AuroraFill"
	fill.transform = Transform3D(Basis.looking_at(Vector3(0.1, -0.35, 0.93).normalized(), Vector3.UP), Vector3(0, 30, 0))
	fill.light_color = Color(0.46, 0.95, 0.78)
	fill.light_energy = 0.32
	fill.shadow_enabled = false
	level.add_child(fill)


# ---------------------------------------------------------------------------
# Terrain: flat summit plateau, the mountain rising behind the lodge, the
# valley falling away on the other three sides
# ---------------------------------------------------------------------------

func _terrain_height(x: float, z: float) -> float:
	var dx := maxf(PLATEAU.position.x - x, 0.0) + maxf(x - PLATEAU.end.x, 0.0)
	var dz_south := maxf(z - PLATEAU.end.y, 0.0)
	var dz_north := maxf(PLATEAU.position.y - z, 0.0)
	var n := _noise.get_noise_2d(x, z)
	var rise := 72.0 * (1.0 - exp(-dz_north / 110.0))
	var away := sqrt(dx * dx + dz_south * dz_south)
	var drop := away * 0.5 + away * away * 0.0022
	var h := rise - minf(drop, 95.0) * (1.0 - smoothstep(0.0, 40.0, dz_north))
	var rough := clampf((away + dz_north) / 18.0, 0.0, 1.0)
	h += n * 9.0 * rough + absf(_noise.get_noise_2d(x * 2.3, z * 2.3)) * 3.5 * rough
	# The ski run: a smooth trail carved down the north slope into the arena.
	if z < RUN_Z_TOP:
		var centre := 17.0 + (RUN_Z_TOP - z) * 0.16
		var trail := RUN_TOP_Y + maxf(0.0, -z - 41.0) * 0.36
		var w := 1.0 - smoothstep(4.0, 10.0, absf(x - centre))
		h = lerpf(h, trail, w)
	return h


func _build_terrain() -> void:
	var holder := Node3D.new()
	holder.name = "Terrain"
	dressing.add_child(holder)
	var snow := _snow_material("terrain_snow", 1.0, 1.0)
	holder.add_child(_terrain_mesh("TerrainNear", Rect2(-150, -200, 300, 320), 4.0, snow, 0.0))
	var far := _terrain_mesh("TerrainFar", Rect2(-900, -900, 1800, 1700), 20.0, snow, 4.0)
	holder.add_child(far)


## A heightfield patch. `sink` lowers it inside the near patch so the two never fight.
func _terrain_mesh(mesh_name: String, area: Rect2, cell: float, material: Material, sink: float) -> MeshInstance3D:
	var nx := int(area.size.x / cell)
	var nz := int(area.size.y / cell)
	var heights := PackedFloat32Array()
	heights.resize((nx + 1) * (nz + 1))
	for j in nz + 1:
		for i in nx + 1:
			var x := area.position.x + i * cell
			var z := area.position.y + j * cell
			var h := _terrain_height(x, z)
			if sink > 0.0 and x > -146.0 and x < 146.0 and z > -196.0 and z < 116.0:
				h -= sink
			heights[j * (nx + 1) + i] = h
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz + 1:
		for i in nx + 1:
			st.set_uv(Vector2(i, j))
			st.add_vertex(Vector3(area.position.x + i * cell, heights[j * (nx + 1) + i], area.position.y + j * cell))
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
# Plateau: collision slab, plaza paving and packed-snow trails
# ---------------------------------------------------------------------------

func _build_plateau() -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	geo.add_child(ground)
	var c := PLATEAU.get_center()
	_collider(ground, "PlateauSlab", Vector3(PLATEAU.size.x, 2.0, PLATEAU.size.y), Vector3(c.x, -1.0, c.y))

	var paint := Node3D.new()
	paint.name = "Paving"
	dressing.add_child(paint)
	# Flagstone patio around the station.
	var patio := MeshInstance3D.new()
	patio.name = "Patio"
	var disc := CylinderMesh.new()
	disc.top_radius = 8.6
	disc.bottom_radius = 8.6
	disc.height = 0.04
	disc.radial_segments = 48
	patio.mesh = disc
	patio.material_override = _textured("stone", "frost_stone", 0.22, 0.85)
	patio.position = STATION + Vector3(0, 0.0, 0)
	patio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paint.add_child(patio)
	var rim := MeshInstance3D.new()
	rim.name = "PatioRim"
	var torus := TorusMesh.new()
	torus.inner_radius = 8.45
	torus.outer_radius = 8.95
	torus.rings = 64
	torus.ring_segments = 6
	rim.mesh = torus
	rim.material_override = _mat("snow_lip", Color(0.88, 0.88, 1.0), 0.8)
	rim.position = STATION + Vector3(0, 0.02, 0)
	rim.scale = Vector3(1, 0.35, 1)
	paint.add_child(rim)

	# Packed-snow trails between the areas (readable lanes).
	var trails := [
		[Vector3(3, 0, 22), Vector3(4, 0, 15), Vector3(5, 0, 11)],                        # lookout -> plaza
		[Vector3(2, 0, -4), Vector3(0, 0, -8), Vector3(-1, 0, -11)],                      # plaza -> stairs
		[Vector3(14, 0, 3), Vector3(18, 0, 3), Vector3(23, 0, 3)],                        # plaza -> chairlift
		[Vector3(-1, 0, -2), Vector3(-6, 0, -6.5), Vector3(-14, 0, -7.5), Vector3(-19, 0, -8), Vector3(-24, 0, -8)],   # north of pond -> gondola
		[Vector3(0, 0, 9), Vector3(-6, 0, 11.5), Vector3(-14, 0, 13.5), Vector3(-20, 0, 16), Vector3(-24, 0, 16)],      # south of pond -> shed
		[Vector3(11, 0, -3), Vector3(14, 0, -8), Vector3(17, 0, -13), Vector3(17, 0, -16)],                            # lounge -> ski run
		[Vector3(-14.5, 0, -10.5), Vector3(-13, 0, -7.5)],                                 # west ramp foot
		[Vector3(10.5, 0, -10.5), Vector3(11, 0, -6)],                                     # east ramp foot
	]
	var path_mat := _path_material()
	var i := 0
	for t in trails:
		paint.add_child(_ribbon("Trail%d" % i, t, 3.4, path_mat))
		i += 1


## A flat strip following a polyline (UV.x across, UV.y along in metres / 4).
func _ribbon(ribbon_name: String, points: Array, width: float, material: Material) -> MeshInstance3D:
	var pts: Array[Vector3] = []
	# Densify with Catmull-Rom so corners are smooth.
	for k in points.size() - 1:
		var p0: Vector3 = points[maxi(k - 1, 0)]
		var p1: Vector3 = points[k]
		var p2: Vector3 = points[k + 1]
		var p3: Vector3 = points[mini(k + 2, points.size() - 1)]
		for s in 6:
			var t := s / 6.0
			pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	pts.append(points[-1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	for k in pts.size():
		var dir := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)])
		dir.y = 0.0
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0, dir.x) * width * 0.5
		if k > 0:
			along += pts[k].distance_to(pts[k - 1])
		var y := Vector3.UP * (0.018 + 0.001 * (ribbon_name.hash() % 5))
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.0, along / 4.0))
		st.add_vertex(pts[k] - side + y)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(1.0, along / 4.0))
		st.add_vertex(pts[k] + side + y)
	for k in pts.size() - 1:
		var a := k * 2
		for idx in [a, a + 2, a + 1, a + 1, a + 2, a + 3]:
			st.add_index(idx)
	var mi := MeshInstance3D.new()
	mi.name = ribbon_name
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------------------
# Lodge: the A-frame and its kitchen wing (collision follows the model)
# ---------------------------------------------------------------------------

func _build_lodge() -> void:
	var lodge := Node3D.new()
	lodge.name = "Lodge"
	geo.add_child(lodge)
	var model := _prop(lodge, "frost_lodge", "LodgeModel", Vector3(-5.0, 0, TERRACE_Z0), 0.0, Vector3(26, 14, 14))
	_late(model, "res://scripts/props/frost_lodge.gd", {})
	# Front wall with the kitchen doorway (X 7.5..9.5) at terrace level.
	var z := TERRACE_Z0 - 0.35
	_collider(lodge, "FrontWallWest", Vector3(23.4, 13.0, 0.7), Vector3(-4.3, 6.5, z))
	_collider(lodge, "FrontWallEast", Vector3(2.4, 13.0, 0.7), Vector3(10.8, 6.5, z))
	_collider(lodge, "KitchenLintel", Vector3(2.2, 9.0, 0.7), Vector3(8.5, 8.3, z))
	# Body of the building behind the wall, leaving the kitchen room open.
	_collider(lodge, "HallBody", Vector3(22.5, 13.0, 13.4), Vector3(-5.25, 6.5, -31.3))
	_collider(lodge, "KitchenBack", Vector3(5.5, 6.0, 9.6), Vector3(9.25, 3.0, -33.2))
	_collider(lodge, "KitchenSide", Vector3(1.5, 6.0, 4.0), Vector3(11.25, 3.0, -26.4))
	_collider(lodge, "KitchenFloor", Vector3(4.6, TERRACE_Y, 4.4), Vector3(8.5, TERRACE_Y * 0.5, -26.4))
	_collider(lodge, "KitchenWallW", Vector3(0.6, 6.0, 4.4), Vector3(6.2, 3.0, -26.4))


# ---------------------------------------------------------------------------
# Terrace: raised deck, roofed west half, ramps, stairs and railings
# ---------------------------------------------------------------------------

func _build_terrace() -> void:
	var t := Node3D.new()
	t.name = "Terrace"
	geo.add_child(t)
	var cx := (TERRACE_X0 + TERRACE_X1) * 0.5
	var cz := (TERRACE_Z0 + TERRACE_Z1) * 0.5
	var w := TERRACE_X1 - TERRACE_X0
	var d := TERRACE_Z1 - TERRACE_Z0
	_collider(t, "Deck", Vector3(w, TERRACE_Y, d), Vector3(cx, TERRACE_Y * 0.5, cz))
	var timber := _textured("timber", "frost_timber", 0.5, 0.7)
	var stone := _textured("stone_wall", "frost_stone", 0.35, 0.9)
	_visual_box(t, "DeckBoards", Vector3(w, 0.12, d), Vector3(cx, TERRACE_Y - 0.06, cz), timber)
	# Stone retaining walls on the exposed faces.
	_visual_box(t, "WallFront", Vector3(w, TERRACE_Y - 0.1, 0.3), Vector3(cx, (TERRACE_Y - 0.1) * 0.5, TERRACE_Z1 - 0.1), stone)
	_visual_box(t, "WallWest", Vector3(0.3, TERRACE_Y - 0.1, d), Vector3(TERRACE_X0 + 0.1, (TERRACE_Y - 0.1) * 0.5, cz), stone)
	_visual_box(t, "WallEast", Vector3(0.3, TERRACE_Y - 0.1, d), Vector3(TERRACE_X1 - 0.1, (TERRACE_Y - 0.1) * 0.5, cz), stone)
	_visual_box(t, "DeckEdge", Vector3(w + 0.3, 0.16, 0.4), Vector3(cx, TERRACE_Y - 0.02, TERRACE_Z1 + 0.05), _mat("timber_dark", Color(0.33, 0.21, 0.19), 0.7))

	# Access: west ramp, central stairs, east ramp.
	_ramp(t, "WestRamp", TERRACE_X0, TERRACE_X0 + 3.0, TERRACE_Z1, TERRACE_Z1 + 4.6, timber)
	_ramp(t, "EastRamp", TERRACE_X1 - 3.0, TERRACE_X1, TERRACE_Z1, TERRACE_Z1 + 4.6, timber)
	_stairs(t, "Stairs", -3.0, 1.0, TERRACE_Z1, TERRACE_Z1 + 4.2, timber)

	# Roofed west half: posts and the glass windbreak (roof art is in the lodge model).
	for x in [-15.6, -11.2, -6.8, -3.2]:
		_post(t, "RoofPost%d" % int(absf(x) * 10), 0.22, 3.6, Vector3(x, TERRACE_Y, -17.6))
	_collider(t, "Windbreak", Vector3(0.3, 2.4, 6.4), Vector3(TERRACE_X0 + 0.2, TERRACE_Y + 1.2, -20.8))
	# The roof itself (art in the lodge model) is off-limits to the player.
	_player_block(t, "RoofCap", Vector3(TERRACE_X1 - TERRACE_X0 + 1.0, 4.0, TERRACE_Z1 - TERRACE_Z0 + 1.0),
		Vector3(cx, TERRACE_Y + 3.3 + 2.0, cz))

	# Railings along the front edge (gaps for the ramps and stairs) and the east side.
	_fence_run(t, "RailFrontW", Vector3(TERRACE_X0 + 3.0, TERRACE_Y, TERRACE_Z1 + 0.15), Vector3(-3.0, TERRACE_Y, TERRACE_Z1 + 0.15))
	_fence_run(t, "RailFrontE", Vector3(1.0, TERRACE_Y, TERRACE_Z1 + 0.15), Vector3(TERRACE_X1 - 3.0, TERRACE_Y, TERRACE_Z1 + 0.15))
	_fence_run(t, "RailEast", Vector3(TERRACE_X1 - 0.15, TERRACE_Y, TERRACE_Z0), Vector3(TERRACE_X1 - 0.15, TERRACE_Y, TERRACE_Z1))
	# West edge: from the end of the windbreak to the head of the west ramp.
	_fence_run(t, "RailWest", Vector3(TERRACE_X0 + 0.15, TERRACE_Y, -17.5), Vector3(TERRACE_X0 + 0.15, TERRACE_Y, TERRACE_Z1))

	# Terrace furniture (cover up on the deck).
	var y := TERRACE_Y
	_solid_prop(t, "frost_table", "PicnicA", Vector3(-12.6, y, -21.2), 90.0, Vector3(1.8, 0.8, 2.4))
	_solid_prop(t, "frost_table", "PicnicB", Vector3(-8.0, y, -21.2), 90.0, Vector3(1.8, 0.8, 2.4))
	for heater in [["HeaterA", Vector3(-14.8, y, -18.6)], ["HeaterB", Vector3(-5.0, y, -18.6)]]:
		_prop(t, "frost_heater", heater[0], heater[1], 0.0, Vector3(0.5, 2.4, 0.5))
		_post(t, heater[0] + "Collision", 0.27, 2.4, heater[1])
		_player_block(t, heater[0] + "Cap", Vector3(0.9, 1.4, 0.9), heater[1] + Vector3(0, 3.1, 0))
	_solid_prop(t, "frost_ski_rack", "TerraceRack", Vector3(1.5, y, -23.2), 0.0, Vector3(3.0, 1.6, 0.9))
	_solid_prop(t, "frost_fire_table", "FireTable", Vector3(5.0, y, -19.4), 0.0, Vector3(2.4, 0.7, 1.4))
	_fire(t, "FireTableFlame", Vector3(5.0, y + 0.62, -19.4), 0.75, false)
	for k in 3:
		var a := deg_to_rad(-120.0 + k * 60.0)
		var p := Vector3(5.0, y, -19.4) + Vector3(sin(a), 0, cos(a)) * Vector3(2.0, 0, 1.6)
		_prop(dressing, "frost_chair", "LoungeChair%d" % k, p, rad_to_deg(a) + 180.0, Vector3(0.8, 1.0, 0.9))
	# Clear of the kitchen doorway (zombies come out of it and turn east).
	_solid_prop(t, "frost_crates", "KitchenCrates", Vector3(11.1, y, -21.2), 90.0, Vector3(1.6, 1.2, 1.2))


## A ramp from the terrace edge (z_top, at deck height) down to the ground (z_bottom).
func _ramp(parent: Node3D, ramp_name: String, x0: float, x1: float, z_top: float, z_bottom: float, material: Material) -> void:
	var run := z_bottom - z_top
	var length := sqrt(run * run + TERRACE_Y * TERRACE_Y)
	var angle := atan2(TERRACE_Y, run)
	var thick := 0.5
	var body := StaticBody3D.new()
	body.name = ramp_name
	parent.add_child(body)
	var top_mid := Vector3((x0 + x1) * 0.5, TERRACE_Y * 0.5, (z_top + z_bottom) * 0.5)
	var normal := Vector3(0, cos(angle), sin(angle))
	body.position = top_mid - normal * thick * 0.5
	body.rotation.x = angle
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, thick, length + 0.3)
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(Vector3(x1 - x0, thick, length + 0.3), material)
	body.add_child(mi)
	# Side kerbs (timber), solid: KERB_H above the ramp surface.
	for side in [x0 + 0.08, x1 - 0.08]:
		var s := MeshInstance3D.new()
		s.name = "Stringer%s" % ("L" if side < (x0 + x1) * 0.5 else "R")
		s.mesh = _box_mesh(Vector3(0.16, thick + KERB_H, length + 0.3), _mat("timber_dark", Color(0.33, 0.21, 0.19), 0.7))
		s.position = Vector3(side - (x0 + x1) * 0.5, KERB_H * 0.5, 0)
		body.add_child(s)
		_kerb(parent, "%sKerb%s" % [ramp_name, "L" if side < (x0 + x1) * 0.5 else "R"], side - 0.08, side + 0.08, z_top, z_bottom)


## Height of the solid kerbs along ramps and stairs, above the walking surface.
const KERB_H := 0.4


## Collision for a kerb along a ramp or stair side, from the terrace edge
## (z_top) down to the ground (z_bottom): a wedge with upright ends.
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


## Visual steps over an invisible ramp (the player and the navmesh use the ramp).
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
	var steps := 7
	var rise := TERRACE_Y / steps
	var tread := run / steps
	for k in steps:
		var h := TERRACE_Y - rise * (k + 1)
		var mi := MeshInstance3D.new()
		mi.name = "Step%d" % k
		mi.mesh = _box_mesh(Vector3(x1 - x0, h + rise, tread + 0.02), material)
		mi.position = Vector3((x0 + x1) * 0.5, (h + rise) * 0.5, z_top + tread * (k + 0.5))
		body.add_child(mi)
	# Stone cheeks, solid: KERB_H above the line of the step edges.
	for side in [x0 - 0.15, x1 + 0.15]:
		var s := MeshInstance3D.new()
		s.name = "Cheek%s" % ("L" if side < x0 else "R")
		s.mesh = _box_mesh(Vector3(0.3, 0.3 + KERB_H, length + 0.2), _textured("stone_wall", "frost_stone", 0.35, 0.9))
		s.position = top_mid + Vector3(side - (x0 + x1) * 0.5, KERB_H * 0.5 - 0.1, 0)
		s.rotation.x = angle
		body.add_child(s)
		_kerb(parent, "%sKerb%s" % [stairs_name, "L" if side < x0 else "R"], side - 0.15, side + 0.15, z_top, z_bottom)


# ---------------------------------------------------------------------------
# Frozen pond (slippery for the player, slows zombies a little)
# ---------------------------------------------------------------------------

func _build_pond() -> void:
	var pond := Node3D.new()
	pond.name = "Pond"
	dressing.add_child(pond)
	pond.position = POND
	var ice := MeshInstance3D.new()
	ice.name = "Ice"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.04
	disc.radial_segments = 64
	ice.mesh = disc
	ice.scale = Vector3(POND_RADII.x, 1.0, POND_RADII.y)
	ice.position.y = 0.0
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "frost_ice.gdshader")
	m.set_shader_parameter("crack_texture", load(TEXTURES + "frost_ice.png"))
	m.set_shader_parameter("centre", Vector2(POND.x, POND.z))
	m.set_shader_parameter("radii", POND_RADII)
	ice.material_override = m
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pond.add_child(ice)
	# A lip of snow lumps around the ice (walkable, no collision).
	var lump := SphereMesh.new()
	lump.radius = 0.5
	lump.height = 1.0
	lump.radial_segments = 10
	lump.rings = 5
	lump.material = _mat("snow_lip", Color(0.88, 0.88, 1.0), 0.8)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = lump
	var count := 54
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in count:
		var a := TAU * k / count + rng.randf_range(-0.03, 0.03)
		var r := 1.04 + rng.randf_range(-0.02, 0.04)
		var p := Vector3(cos(a) * POND_RADII.x * r, -0.06, sin(a) * POND_RADII.y * r)
		var s := Vector3(rng.randf_range(1.1, 1.8), rng.randf_range(0.28, 0.5), rng.randf_range(0.8, 1.2))
		mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, -a).scaled(s), p))
	var lumps := MultiMeshInstance3D.new()
	lumps.name = "SnowLip"
	lumps.multimesh = mm
	lumps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pond.add_child(lumps)
	# Cold mist hugging the ice (same shader as the Frozen Tourist's frost
	# cloud, so that shader is compiled before the first one bursts).
	var mist := MeshInstance3D.new()
	mist.name = "Mist"
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 2.0
	dome.is_hemisphere = true
	dome.radial_segments = 32
	dome.rings = 8
	mist.mesh = dome
	var mist_mat := ShaderMaterial.new()
	mist_mat.shader = load(SHADERS + "frost_cloud.gdshader")
	mist_mat.set_shader_parameter("strength", 0.14)
	mist_mat.set_shader_parameter("life", 1.0)
	mist.material_override = mist_mat
	mist.scale = Vector3(POND_RADII.x * 0.98, 0.7, POND_RADII.y * 0.98)
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pond.add_child(mist)
	var rink := Node3D.new()
	rink.name = "IceRink"
	pond.add_child(rink)
	_late(rink, "res://scripts/props/frost_ice_rink.gd", {"radii": POND_RADII})
	# Pond-side dressing.
	_prop(dressing, "frost_snowman", "Snowman", POND + Vector3(-2.5, 0, 7.2), 150.0, Vector3(1, 1.8, 1))
	_prop(dressing, "frost_skates", "SkateBench", POND + Vector3(4.2, 0, -6.6), 200.0, Vector3(1.6, 0.6, 0.5))


# ---------------------------------------------------------------------------
# Loadout station: the ski-rental hut
# ---------------------------------------------------------------------------

func _build_station() -> void:
	var station: Node3D = (load("res://scenes/props/frost_station.tscn") as PackedScene).instantiate()
	station.name = "Station"
	geo.add_child(station)
	station.position = STATION
	station.rotation.y = deg_to_rad(-20.0)


# ---------------------------------------------------------------------------
# Zombie entrances (all beyond the arena boundary)
# ---------------------------------------------------------------------------

func _build_entrances() -> void:
	var e := Node3D.new()
	e.name = "Entrances"
	geo.add_child(e)

	# 1. Gondola station (west): cabins arrive inside, the bay opens east.
	_prop(e, "frost_gondola_station", "GondolaStation", Vector3(-28.5, 0, -8.0), 90.0, Vector3(9, 7, 12))
	_collider(e, "GondolaBack", Vector3(0.6, 7.0, 12.0), Vector3(-33.0, 3.5, -8.0))
	_collider(e, "GondolaSideN", Vector3(9.0, 7.0, 0.6), Vector3(-28.5, 3.5, -14.0))
	_collider(e, "GondolaSideS", Vector3(9.0, 7.0, 0.6), Vector3(-28.5, 3.5, -2.0))
	_collider(e, "GondolaPierN", Vector3(0.8, 7.0, 1.6), Vector3(-24.4, 3.5, -13.0))
	_collider(e, "GondolaPierS", Vector3(0.8, 7.0, 1.6), Vector3(-24.4, 3.5, -3.0))

	# 2. Maintenance shed (south-west): roller door facing the plaza.
	_prop(e, "frost_shed", "MaintenanceShed", Vector3(-28.5, 0, 16.0), 90.0, Vector3(8, 5, 9))
	_collider(e, "ShedBack", Vector3(0.6, 5.0, 9.0), Vector3(-32.6, 2.5, 16.0))
	_collider(e, "ShedSideN", Vector3(8.2, 5.0, 0.6), Vector3(-28.5, 2.5, 11.6))
	_collider(e, "ShedSideS", Vector3(8.2, 5.0, 0.6), Vector3(-28.5, 2.5, 20.4))
	_collider(e, "ShedFrontN", Vector3(0.6, 5.0, 2.5), Vector3(-24.4, 2.5, 12.6))
	_collider(e, "ShedFrontS", Vector3(0.6, 5.0, 2.5), Vector3(-24.4, 2.5, 19.4))
	_prop(dressing, "frost_snowcat", "Snowcat", Vector3(-29.0, 0, 25.0), 75.0, Vector3(3, 3, 5))
	_prop(dressing, "frost_logs", "ShedLogs", Vector3(-25.8, 0, 9.6), 0.0, Vector3(2.4, 1.2, 1.2))

	# 3. Chairlift landing (east): the Summit Express comes down the mountain
	# behind it; riders hop off on the ramp and walk west into the plaza.
	var yaw := atan2(-CHAIR_DIR.x, -CHAIR_DIR.z)
	var basis := Basis(Vector3.UP, yaw)
	_prop(e, "frost_lift_station", "ChairliftLanding", LANDING, rad_to_deg(yaw), Vector3(8, 7, 10))
	var k := 0
	for local in [Vector3(-4.6, 3.0, 3.4), Vector3(4.6, 3.0, 3.4), Vector3(-4.6, 3.0, -3.4), Vector3(4.6, 3.0, -3.4)]:
		_post(e, "LandingPost%d" % k, 0.32, 6.0, LANDING + basis * (local * Vector3(1, 0, 1)))
		k += 1
	_post(e, "LandingColumn", 0.65, 4.0, LANDING + basis * Vector3(0, 0, -2.0))


# ---------------------------------------------------------------------------
# Ski run: a slope coming down from the north-east, zombies ski in from the top
# ---------------------------------------------------------------------------

func _build_ski_run() -> void:
	var run := Node3D.new()
	run.name = "SkiRun"
	geo.add_child(run)
	var snow := _snow_material("run_snow", 0.0, 1.0)
	var length_z := RUN_Z_BOTTOM - RUN_Z_TOP
	var slope_len := sqrt(length_z * length_z + RUN_TOP_Y * RUN_TOP_Y)
	var angle := atan2(RUN_TOP_Y, length_z)
	var thick := 1.0
	var slope := StaticBody3D.new()
	slope.name = "Slope"
	run.add_child(slope)
	var normal := Vector3(0, cos(angle), sin(angle))
	slope.position = Vector3((RUN_X0 + RUN_X1) * 0.5, RUN_TOP_Y * 0.5, (RUN_Z_TOP + RUN_Z_BOTTOM) * 0.5) - normal * thick * 0.5
	slope.rotation.x = angle
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(RUN_X1 - RUN_X0, thick, slope_len + 0.4)
	shape.shape = box
	slope.add_child(shape)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(box.size, snow)
	slope.add_child(mi)
	# Top landing where the skiers appear, merging into the trail beyond.
	_box(run, "TopLanding", Vector3(RUN_X1 - RUN_X0, RUN_TOP_Y, 12.0), Vector3((RUN_X0 + RUN_X1) * 0.5, RUN_TOP_Y * 0.5, RUN_Z_TOP - 6.0), snow)
	# Banks of snow along both sides (low; the player walls do the real work).
	var k := 0
	for side in [RUN_X0 + 0.2, RUN_X1 - 0.2]:
		for i in 6:
			var z := RUN_Z_BOTTOM - 1.5 - i * 4.2
			var t := clampf((RUN_Z_BOTTOM - z) / length_z, 0.0, 1.0)
			var y := RUN_TOP_Y * t if z > RUN_Z_TOP else RUN_TOP_Y
			var bank := _prop(dressing, "frost_snowbank", "RunBank%02d" % k, Vector3(side, y - 0.3, z), 90.0 + (i % 2) * 180.0, Vector3(3, 1.2, 1.6))
			bank.scale = Vector3(1.3, 1.1, 1.0)
			k += 1
	# Trail markers and the finish arch.
	for i in 5:
		var z := RUN_Z_BOTTOM - 2.0 - i * 3.6
		var y := RUN_TOP_Y * clampf((RUN_Z_BOTTOM - z) / length_z, 0.0, 1.0)
		_prop(dressing, "frost_marker", "RunMarkerW%d" % i, Vector3(RUN_X0 + 1.4, y, z), 0.0, Vector3(0.1, 1.6, 0.1))
		_prop(dressing, "frost_marker", "RunMarkerE%d" % i, Vector3(RUN_X1 - 1.4, y, z), 0.0, Vector3(0.1, 1.6, 0.1))
	_prop(run, "frost_run_arch", "FinishArch", Vector3((RUN_X0 + RUN_X1) * 0.5, 0, RUN_Z_BOTTOM + 0.5), 0.0, Vector3(10, 5, 0.6))
	_post(run, "ArchPostW", 0.32, 4.6, Vector3(RUN_X0 + 0.6, 0, RUN_Z_BOTTOM + 0.5))
	_post(run, "ArchPostE", 0.32, 4.6, Vector3(RUN_X1 - 0.6, 0, RUN_Z_BOTTOM + 0.5))


# ---------------------------------------------------------------------------
# Arena dressing: cover, fire pits, lanterns, trees
# ---------------------------------------------------------------------------

func _build_arena_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	geo.add_child(props)

	# Snowbanks: chest-high cover, kept off the patrol ring around the station.
	var banks := [
		[Vector3(-3.6, 0, -8.6), 15.0, 1.0], [Vector3(-19.2, 0, -11.2), -25.0, 1.1], [Vector3(13.3, 0, -9.2), 55.0, 0.95],
		[Vector3(-16.4, 0, 12.6), 30.0, 1.0], [Vector3(17.6, 0, 19.0), -10.0, 1.1], [Vector3(-21.4, 0, 2.6), 80.0, 0.9],
		[Vector3(8.6, 0, 18.6), 5.0, 0.85],
	]
	var i := 0
	for b in banks:
		var bank := _prop(props, "frost_snowbank", "Snowbank%d" % i, b[0], b[1], Vector3(3.2, 1.2, 1.6))
		bank.scale = Vector3.ONE * b[2]
		var c := _collider(props, "Snowbank%dCollision" % i, Vector3(2.9, 1.15, 1.3) * b[2], b[0] + Vector3(0, 0.55 * b[2], 0))
		c.rotation.y = deg_to_rad(b[1])
		i += 1

	# Ski racks: waist-high cover with a see-through top.
	_solid_prop(props, "frost_ski_rack", "SkiRackEast", Vector3(13.2, 0, -0.4), 90.0, Vector3(3.0, 1.6, 0.9))
	_solid_prop(props, "frost_ski_rack", "SkiRackSouth", Vector3(-2.4, 0, 13.8), 10.0, Vector3(3.0, 1.6, 0.9))
	_solid_prop(props, "frost_ski_rack", "SkiRackRamp", Vector3(6.9, 0, -12.6), 0.0, Vector3(3.0, 1.6, 0.9))

	# Fire-pit lounge (east) with log benches.
	for entry in [[Vector3(17.6, 0, -6.4), 0], [Vector3(14.6, 0, 15.2), 1]]:
		var p: Vector3 = entry[0]
		_solid_prop(props, "frost_fire_pit", "FirePit%d" % entry[1], p, 0.0, Vector3(1.8, 0.55, 1.8))
		_fire(props, "FirePit%dFlame" % entry[1], p + Vector3(0, 0.32, 0), 1.0, true)
		for k in 3:
			var a := deg_to_rad(30.0 + k * 120.0 + entry[1] * 40.0)
			var bp := p + Vector3(sin(a), 0, cos(a)) * 2.4
			_solid_prop(props, "frost_bench", "FirePit%dBench%d" % [entry[1], k], bp, rad_to_deg(a) + 90.0, Vector3(2.0, 0.5, 0.6))

	# Snowmobiles parked near the chairlift path.
	_solid_prop(props, "frost_snowmobile", "SnowmobileA", Vector3(19.4, 0, 9.0), 200.0, Vector3(1.2, 1.2, 2.8))
	_solid_prop(props, "frost_snowmobile", "SnowmobileB", Vector3(21.2, 0, 12.2), 165.0, Vector3(1.2, 1.2, 2.8))
	_solid_prop(props, "frost_snowmobile", "SnowmobileC", Vector3(-20.8, 0, -3.6), 20.0, Vector3(1.2, 1.2, 2.8))

	# Pines inside the arena (trunks collide).
	var pines := [
		[Vector3(-21.4, 0, 8.4), 1.0], [Vector3(-12.2, 0, 20.4), 0.9], [Vector3(11.4, 0, 21.4), 1.05],
		[Vector3(21.2, 0, 20.6), 1.15], [Vector3(21.0, 0, -11.0), 1.1], [Vector3(-22.0, 0, -13.4), 1.2],
		[Vector3(-22.4, 0, 21.4), 1.1], [Vector3(-8.6, 0, -12.4), 0.85],
	]
	i = 0
	for p in pines:
		var tree := _prop(dressing, "frost_pine", "Pine%d" % i, p[0], i * 53.0, Vector3(3, 8, 3))
		tree.scale = Vector3.ONE * p[1]
		_post(props, "Pine%dTrunk" % i, 0.38, 4.0, p[0])
		_player_block(props, "Pine%dCap" % i, Vector3(1.6, 4.0, 1.6), p[0] + Vector3(0, 6.0, 0))
		i += 1

	# Lantern posts around the plaza and along the edges of the trails.
	var lamps := [
		Vector3(-1.2, 0, 0.6), Vector3(13.0, 0, 8.4), Vector3(0.6, 0, 7.2), Vector3(14.2, 0, -3.6),
		Vector3(-4.6, 0, -11.2), Vector3(5.2, 0, -11.4), Vector3(-17.6, 0, -5.6), Vector3(-17.8, 0, 9.4),
		Vector3(19.0, 0, 0.4), Vector3(6.2, 0, 20.6), Vector3(-9.0, 0, 15.6), Vector3(19.8, 0, -13.6),
	]
	i = 0
	for p in lamps:
		_prop(dressing, "frost_lamp", "Lantern%02d" % i, p, i * 37.0, Vector3(0.3, 3.6, 0.3))
		_post(props, "Lantern%02dPost" % i, 0.17, 3.4, p)
		_player_block(props, "Lantern%02dCap" % i, Vector3(0.5, 2.0, 0.5), p + Vector3(0, 4.4, 0))
		i += 1
	_build_string_lights(lamps)

	# Signs.
	_prop(props, "frost_signpost", "Signpost", Vector3(-0.4, 0, 4.8), 30.0, Vector3(0.3, 3.3, 0.3))
	_post(props, "SignpostCollision", 0.14, 3.3, Vector3(-0.4, 0, 4.8))
	_prop(dressing, "frost_resort_sign", "ResortSign", Vector3(14.0, 0, 23.0), 200.0, Vector3(5, 3, 0.4))
	_prop(dressing, "frost_telescope", "Telescope", Vector3(-1.0, 0, 23.2), 180.0, Vector3(0.5, 1.4, 0.5))

	# A blocker in the north-west corner beside the terrace (snowdrift and rocks).
	_prop(dressing, "frost_snowbank", "NWDrift", Vector3(-20.5, 0, -18.0), 70.0, Vector3(3.2, 1.2, 1.6)).scale = Vector3(2.2, 1.6, 1.8)
	_collider(props, "NWDriftCollision", Vector3(6.0, 2.0, 7.0), Vector3(-20.0, 1.0, -19.5))


# ---------------------------------------------------------------------------
# Boundary fences and the invisible player-only walls
# ---------------------------------------------------------------------------

func _build_fences() -> void:
	var f := Node3D.new()
	f.name = "Boundary"
	geo.add_child(f)
	# Lookout fence along the south edge.
	_fence_run(f, "FenceSouth", Vector3(ARENA_X0, 0, 24.2), Vector3(ARENA_X1 + 0.5, 0, 24.2))
	# East: either side of the chairlift landing.
	_fence_run(f, "FenceEastN", Vector3(24.2, 0, -15.0), Vector3(24.2, 0, -4.0))
	_fence_run(f, "FenceEastS", Vector3(24.2, 0, 7.0), Vector3(24.2, 0, 24.2))
	# West: between the gondola station and the shed, and south of the shed.
	_fence_run(f, "FenceWestMid", Vector3(-24.6, 0, -1.6), Vector3(-24.6, 0, 11.4))
	_fence_run(f, "FenceWestS", Vector3(-24.6, 0, 20.6), Vector3(-24.6, 0, 24.2))
	_fence_run(f, "FenceWestN", Vector3(-24.6, 0, -15.0), Vector3(-24.6, 0, -14.4))

	var walls := Node3D.new()
	walls.name = "PlayerWalls"
	level.add_child(walls)
	var h := 8.0
	_player_wall(walls, "West", Vector3(ARENA_X0, 0, -15.5), Vector3(ARENA_X0, 0, ARENA_Z1), h)
	_player_wall(walls, "South", Vector3(ARENA_X0, 0, ARENA_Z1), Vector3(ARENA_X1, 0, ARENA_Z1), h)
	_player_wall(walls, "East", Vector3(ARENA_X1, 0, -15.0), Vector3(ARENA_X1, 0, ARENA_Z1), h)
	_player_wall(walls, "NorthWest", Vector3(ARENA_X0, 0, -15.5), Vector3(TERRACE_X0, 0, -15.5), h)
	# The terrace's west edge, above its rail and windbreak (nobody hops onto the drift beyond).
	_player_wall(walls, "TerraceWest", Vector3(TERRACE_X0 - 0.2, 0, TERRACE_Z0 - 0.4), Vector3(TERRACE_X0 - 0.2, 0, -15.5), h + 2.0)
	_player_wall(walls, "RunEast", Vector3(RUN_X1 - 0.6, 0, -24.0), Vector3(RUN_X1 - 0.6, 0, -15.0), h + 4.0)
	_player_wall(walls, "RunCorner", Vector3(RUN_X1 - 0.6, 0, -15.0), Vector3(ARENA_X1, 0, -15.0), h)
	_player_wall(walls, "RunTop", Vector3(RUN_X0, 0, -24.0), Vector3(RUN_X1, 0, -24.0), h + 6.0)
	_player_wall(walls, "RunWest", Vector3(RUN_X0 + 0.3, 0, -24.0), Vector3(RUN_X0 + 0.3, 0, -15.0), h + 4.0)


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


## A run of wooden fence modules with one collision box (blocks walking, not jumping).
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
	# The modules of a run are drawn as one MultiMesh.
	var module_len := 2.5
	var count := maxi(1, int(round(length / module_len)))
	var step := length / count
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _model_mesh("frost_fence")
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(step / module_len, 1, 1)), Vector3(-length * 0.5 + step * (i + 0.5), 0, 0)))
	var modules := MultiMeshInstance3D.new()
	modules.name = "Modules"
	modules.multimesh = mm
	body.add_child(modules)


# ---------------------------------------------------------------------------
# Lifts: the chairlift (east, the landmark) and the gondola (west)
# ---------------------------------------------------------------------------

func _build_lifts() -> void:
	var lifts := Node3D.new()
	lifts.name = "Lifts"
	dressing.add_child(lifts)
	# Chairlift: bull wheel in the landing, towers stepping down the east slope.
	# Chairlift: from the landing's bull wheel, up the mountain to a top station.
	var chair_towers: Array[float] = [24.0, 56.0, 94.0, 136.0, 182.0]
	var wheel := LANDING + Basis(Vector3.UP, atan2(-CHAIR_DIR.x, -CHAIR_DIR.z)) * Vector3(0, 5.2, -1.6)
	_lift(lifts, "Chairlift", wheel, 2.3, CHAIR_DIR, chair_towers, 9.5, "frost_lift_chair", 14.0, 2.4, "frost_lift_tower", "frost_lift_station")
	# Gondola: from its station west and down into the valley.
	var gondola_towers: Array[float] = [52.0, 92.0, 140.0]
	_lift(lifts, "Gondola", Vector3(-30.0, 5.6, -8.0), 1.9, Vector3.LEFT, gondola_towers, 12.0, "frost_gondola_cabin", 38.0, 3.2, "frost_gondola_tower", "")


## Builds a looped lift line: a horizontal bull wheel at `wheel`, two cables
## heading along `out_dir` over towers at the given distances, a return wheel
## past the last tower (inside `end_station`, if given), carriers spaced along
## the loop and a mover script.
func _lift(parent: Node3D, lift_name: String, wheel: Vector3, radius: float, out_dir: Vector3, towers: Array[float],
		tower_height: float, carrier_model: String, spacing: float, speed: float, tower_model: String, end_station: String) -> void:
	var holder := Node3D.new()
	holder.name = lift_name
	parent.add_child(holder)
	var side := Vector3(-out_dir.z, 0, out_dir.x)          # left of the travel direction
	var heights: Array[float] = []
	for d in towers:
		var p := wheel + out_dir * d
		heights.append(_terrain_height(p.x, p.z) + tower_height)
	var end_d: float = towers[-1] + 40.0
	var end_p := wheel + out_dir * end_d
	var end_ground := _terrain_height(end_p.x, end_p.z)
	var end_h := end_ground + (5.2 if end_station != "" else tower_height * 0.6)
	if end_station != "":
		var yaw := atan2(out_dir.x, out_dir.z)
		var top := _prop(holder, end_station, "TopStation", Vector3.ZERO, rad_to_deg(yaw), Vector3(8, 7, 10))
		top.position = Vector3(end_p.x, end_ground, end_p.z) - Basis(Vector3.UP, yaw) * Vector3(0, 0, -1.6)
	# Line A runs out on one side, line B returns on the other.
	var line: Array[Vector3] = []
	var stations: Array = [[0.0, wheel.y]]
	for k in towers.size():
		stations.append([towers[k], heights[k]])
	stations.append([end_d, end_h])
	var out_pts: Array[Vector3] = []
	for k in stations.size() - 1:
		var d0: float = stations[k][0]
		var d1: float = stations[k + 1][0]
		var h0: float = stations[k][1]
		var h1: float = stations[k + 1][1]
		var segs := 6
		for s in segs:
			var t := float(s) / segs
			var sag := 4.0 * t * (1.0 - t) * (d1 - d0) * 0.018
			out_pts.append(wheel + out_dir * lerpf(d0, d1, t) + Vector3.UP * (lerpf(h0, h1, t) - wheel.y - sag))
	out_pts.append(wheel + out_dir * end_d + Vector3.UP * (end_h - wheel.y))
	for p in out_pts:
		line.append(p + side * radius)
	# Around the far wheel.
	for s in range(1, 8):
		var a := PI * s / 8.0
		line.append(out_pts[-1] + (side * cos(a) + out_dir * sin(a)) * radius)
	for k in range(out_pts.size() - 1, -1, -1):
		line.append(out_pts[k] - side * radius)
	# Around the station wheel.
	for s in range(1, 8):
		var a := PI * s / 8.0
		line.append(wheel - side * cos(a) * radius - out_dir * sin(a) * radius)
	# Cable.
	var cable := MultiMeshInstance3D.new()
	cable.name = "Cable"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _box_mesh(Vector3(1, 1, 1), _mat("cable", Color(0.12, 0.12, 0.18), 0.4))
	mm.instance_count = line.size()
	for k in line.size():
		var p0 := line[k]
		var p1 := line[(k + 1) % line.size()]
		var basis := Basis.looking_at((p1 - p0).normalized(), Vector3.UP)
		mm.set_instance_transform(k, Transform3D(Basis(basis.x * 0.1, basis.y * 0.1, basis.z * p0.distance_to(p1)), (p0 + p1) * 0.5))
	cable.multimesh = mm
	cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(cable)
	# Towers.
	for k in towers.size():
		var p := wheel + out_dir * towers[k]
		var base_y := _terrain_height(p.x, p.z)
		var t := _prop(holder, tower_model, "Tower%d" % k, Vector3(p.x, base_y - 0.5, p.z), rad_to_deg(atan2(out_dir.x, out_dir.z)), Vector3(1, tower_height, 1))
		t.scale = Vector3(1, (heights[k] - base_y + 0.5) / tower_height, 1) if tower_height > 0.0 else Vector3.ONE
	# Carriers, distributed by the mover at runtime.
	var length := 0.0
	for k in line.size():
		length += line[k].distance_to(line[(k + 1) % line.size()])
	var carriers := Node3D.new()
	carriers.name = "Carriers"
	holder.add_child(carriers)
	var count := int(length / spacing)
	for k in count:
		_prop(carriers, carrier_model, "Carrier%02d" % k, line[0], 0.0, Vector3(1.2, 2.0, 1.0))
	var path := PackedVector3Array()
	for p in line:
		path.append(p)
	_late(carriers, "res://scripts/props/frost_lift.gd", {"path": path, "speed": speed})


# ---------------------------------------------------------------------------
# Lights: warm pools against the cold night (no shadows)
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	var lights := Node3D.new()
	lights.name = "WarmLights"
	level.add_child(lights)
	# Lodge glass wall spilling onto the terrace and the plaza.
	_omni(lights, "LodgeGlow", Vector3(-5.0, 4.2, -21.0), Color(1.0, 0.62, 0.3), 1.6, 13.0)
	_omni(lights, "TerraceRoof", Vector3(-10.0, 4.4, -19.5), Color(1.0, 0.66, 0.34), 1.4, 8.0)
	_omni(lights, "KitchenDoor", Vector3(8.5, 3.6, -23.0), Color(1.0, 0.7, 0.4), 1.4, 7.0)
	_omni(lights, "GondolaBay", Vector3(-26.0, 4.5, -8.0), Color(0.6, 0.85, 1.0), 1.2, 9.0)
	_omni(lights, "ShedDoor", Vector3(-24.0, 4.0, 16.0), Color(1.0, 0.7, 0.36), 1.0, 7.0)


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


## Animated flames (crossed quads) and, for the big pits, a flickering light.
func _fire(parent: Node3D, fire_name: String, pos: Vector3, size: float, with_light: bool) -> void:
	var holder := Node3D.new()
	holder.name = fire_name
	parent.add_child(holder)
	holder.position = pos
	var quad := QuadMesh.new()
	quad.size = Vector2(1.1, 1.5) * size
	quad.center_offset = Vector3(0, 0.75 * size, 0)
	for k in 3:
		var m := ShaderMaterial.new()
		m.shader = load(SHADERS + "frost_fire.gdshader")
		m.set_shader_parameter("seed", k * 1.7 + fire_name.length())
		var q := MeshInstance3D.new()
		q.name = "Flame%d" % k
		q.mesh = quad
		q.material_override = m
		q.rotation.y = PI * k / 3.0
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(q)
	if with_light:
		var l := _omni(holder, "Light", Vector3(0, 1.1, 0), Color(1.0, 0.56, 0.22), 2.0, 8.5)
		_late(l, "res://scripts/props/frost_flicker.gd", {})


# ---------------------------------------------------------------------------
# Backdrop: peaks, forest, aurora, falling snow
# ---------------------------------------------------------------------------

func _build_backdrop() -> void:
	var back := Node3D.new()
	back.name = "Backdrop"
	dressing.add_child(back)
	# Distant massifs ring the summit (tallest behind the lodge): [position, scale, yaw, model].
	var peaks := [
		[Vector3(-40, -6, -330), Vector3(2.6, 2.7, 2.2), 10.0, "frost_peak"], [Vector3(150, -14, -300), Vector3(2.2, 2.0, 2.0), 70.0, "frost_peak_b"],
		[Vector3(-230, -20, -250), Vector3(2.3, 2.2, 2.0), 140.0, "frost_peak"], [Vector3(290, -45, -120), Vector3(2.4, 1.8, 2.2), 200.0, "frost_peak_b"],
		[Vector3(360, -75, 140), Vector3(2.6, 2.3, 2.4), 30.0, "frost_peak"], [Vector3(-350, -75, 80), Vector3(2.8, 2.0, 2.4), 260.0, "frost_peak_b"],
		[Vector3(-190, -85, 400), Vector3(2.4, 2.1, 2.2), 90.0, "frost_peak_b"], [Vector3(170, -90, 430), Vector3(2.7, 2.6, 2.5), 160.0, "frost_peak"],
		[Vector3(40, -40, -520), Vector3(3.4, 3.2, 3.0), 300.0, "frost_peak"], [Vector3(-130, -40, -470), Vector3(2.6, 1.9, 2.4), 40.0, "frost_peak_b"],
	]
	var i := 0
	for p in peaks:
		var peak := _prop(back, p[3], "Peak%d" % i, p[0], p[2], Vector3(100, 70, 100))
		peak.scale = p[1]
		i += 1
	_build_forest(back)
	_build_aurora(back)
	var snowfall := MultiMeshInstance3D.new()
	snowfall.name = "Snowfall"
	level.add_child(snowfall)
	# Roofed places the snow must not fall through: the terrace's covered west
	# half, the kitchen, the gondola bay, the shed, the chairlift landing and
	# the rental hut.
	var shelters: Array[AABB] = [
		AABB(Vector3(TERRACE_X0 - 0.4, TERRACE_Y - 0.2, TERRACE_Z0 - 0.4), Vector3(13.6, 3.7, 7.2)),
		AABB(Vector3(6.0, TERRACE_Y - 0.2, -28.8), Vector3(5.2, 4.2, 4.6)),
		AABB(Vector3(-33.2, -0.2, -14.2), Vector3(9.0, 6.4, 12.4)),
		AABB(Vector3(-32.8, -0.2, 11.4), Vector3(8.6, 4.8, 9.2)),
		AABB(Vector3(LANDING.x - 4.4, -0.2, LANDING.z - 5.0), Vector3(8.8, 6.0, 9.6)),
		AABB(Vector3(STATION.x - 2.2, -0.2, STATION.z - 1.9), Vector3(4.4, 3.2, 3.8)),
	]
	_late(snowfall, "res://scripts/fx/frost_snowfall.gd", {"shelters": shelters})
	var weather := Node.new()
	weather.name = "Weather"
	level.add_child(weather)
	_late(weather, "res://scripts/props/frost_weather.gd", {})


var _mesh_cache := {}


## The (single) mesh of art/models/<model>.glb, for MultiMesh batching.
func _model_mesh(model: String) -> Mesh:
	if _mesh_cache.has(model):
		return _mesh_cache[model]
	var source: Node3D = (load(MODELS + model + ".glb") as PackedScene).instantiate()
	var mesh: Mesh = (source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	source.free()
	_mesh_cache[model] = mesh
	return mesh


## Low-detail pines scattered over the slopes outside the arena (one MultiMesh).
func _build_forest(parent: Node3D) -> void:
	var mesh := _model_mesh("frost_pine_far")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var xforms: Array[Transform3D] = []
	var tries := 0
	while xforms.size() < 420 and tries < 6000:
		tries += 1
		var x := rng.randf_range(-170.0, 170.0)
		var z := rng.randf_range(-200.0, 140.0)
		# Keep the plateau, the ski trail and the lift lines clear.
		if PLATEAU.grow(3.0).has_point(Vector2(x, z)):
			continue
		if z < -30.0 and absf(x - (17.0 + (-30.0 - z) * 0.16)) < 9.0:
			continue
		if absf(z - 3.0) < 9.0 and x > 25.0:
			continue
		if absf(z + 8.0) < 9.0 and x < -25.0:
			continue
		var h := _terrain_height(x, z)
		var slope := absf(_terrain_height(x + 2.0, z) - h) + absf(_terrain_height(x, z + 2.0) - h)
		if slope > 2.6:
			continue
		var s := rng.randf_range(0.8, 1.6)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.25), s))
		xforms.append(Transform3D(basis, Vector3(x, h - 0.3, z)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var forest := MultiMeshInstance3D.new()
	forest.name = "Forest"
	forest.multimesh = mm
	forest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(forest)


## Tall curtains of light arcing over the north, behind the lodge.
func _build_aurora(parent: Node3D) -> void:
	var curtains := [
		# radius, azimuth from/to (degrees, 0 = north), bottom, height, seed, strength
		[520.0, -75.0, 35.0, 95.0, 190.0, 0.0, 1.0],
		[600.0, -20.0, 80.0, 120.0, 230.0, 3.0, 0.75],
		[460.0, -110.0, -40.0, 130.0, 150.0, 7.0, 0.6],
	]
	var shader: Shader = load(SHADERS + "frost_aurora.gdshader")
	var i := 0
	for c in curtains:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segs := 64
		for s in segs + 1:
			var t := float(s) / segs
			var az := deg_to_rad(lerpf(c[1], c[2], t))
			var wobble: float = c[0] * (1.0 + 0.08 * sin(t * 9.0 + c[5]))
			var p := Vector3(sin(az) * wobble, 0, -cos(az) * wobble)
			var n := -p.normalized()
			for v in 2:
				st.set_normal(n)
				st.set_uv(Vector2(t, float(v)))
				st.add_vertex(p + Vector3.UP * (c[3] + c[4] * v + 20.0 * sin(t * 5.0 + c[5])))
		for s in segs:
			var a := s * 2
			for idx in [a, a + 2, a + 1, a + 1, a + 2, a + 3]:
				st.add_index(idx)
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("seed", c[5])
		m.set_shader_parameter("strength", c[6])
		m.set_shader_parameter("speed", 1.0)
		m.set_shader_parameter("hem_color", Color(0.32, 1.0, 0.62))
		m.set_shader_parameter("top_color", Color(0.66, 0.34, 1.0))
		var mi := MeshInstance3D.new()
		mi.name = "Aurora%d" % i
		mi.mesh = st.commit()
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 200.0
		mi.add_to_group("frost_aurora", true)
		parent.add_child(mi)
		i += 1


# ---------------------------------------------------------------------------
# String lights between the lanterns, the station and the terrace roof
# ---------------------------------------------------------------------------

const LANTERN_TOP := 3.3


func _build_string_lights(lamps: Array) -> void:
	var lights := Node3D.new()
	lights.name = "StringLights"
	level.add_child(lights)
	var top := Vector3.UP * LANTERN_TOP
	var spans := [
		[lamps[0] + top, lamps[4] + top], [lamps[4] + top, lamps[5] + top], [lamps[5] + top, lamps[3] + top],
		[lamps[3] + top, lamps[8] + top], [lamps[8] + top, lamps[1] + top], [lamps[1] + top, lamps[2] + top],
		[lamps[2] + top, lamps[0] + top], [lamps[0] + top, lamps[6] + top], [lamps[10] + top, lamps[7] + top],
		[lamps[9] + top, lamps[1] + top], [lamps[3] + top, lamps[11] + top], [lamps[6] + top, lamps[7] + top],
		# Up to the terrace roof edge.
		[lamps[4] + top, Vector3(-6.8, TERRACE_Y + 3.4, -17.4)], [lamps[5] + top, Vector3(-3.2, TERRACE_Y + 3.4, -17.4)],
	]
	# From the hut's roof peak out to the ring of lanterns.
	for k in [0, 1, 2, 3]:
		spans.append([STATION + Vector3(0, 5.2, 0), lamps[k] + top])
	var i := 0
	for span in spans:
		_garland(lights, "Garland%02d" % i, span[0], span[1])
		i += 1


func _garland(parent: Node3D, garland_name: String, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var sag := clampf(length * 0.06, 0.3, 1.0)
	var bulbs := maxi(4, int(length / 1.0))
	var points: Array[Vector3] = []
	for k in bulbs + 1:
		var t := float(k) / bulbs
		points.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	var holder := Node3D.new()
	holder.name = garland_name
	parent.add_child(holder)
	var wire := MultiMeshInstance3D.new()
	wire.name = "Wire"
	var wm := MultiMesh.new()
	wm.transform_format = MultiMesh.TRANSFORM_3D
	wm.mesh = _box_mesh(Vector3(1, 1, 1), _mat("wire", Color(0.1, 0.09, 0.16), 0.6))
	wm.instance_count = points.size() - 1
	for k in points.size() - 1:
		var p0 := points[k]
		var p1 := points[k + 1]
		var basis := Basis.looking_at((p1 - p0).normalized(), Vector3.UP)
		wm.set_instance_transform(k, Transform3D(Basis(basis.x * 0.025, basis.y * 0.025, basis.z * p0.distance_to(p1)), (p0 + p1) * 0.5))
	wire.multimesh = wm
	wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(wire)
	var colors := [Color(1.0, 0.74, 0.32), Color(1.0, 0.86, 0.55), Color(1.0, 0.62, 0.26)]
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
	m.resource_name = "FrostGarlandBulb"
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = Color(1.0, 0.78, 0.45)
	m.emission_energy_multiplier = 2.4
	var sphere := SphereMesh.new()
	sphere.radius = 0.075
	sphere.height = 0.15
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
	var h := 0.34
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
	halo_mat.resource_name = "FrostGarlandHalo"
	mesh.surface_set_material(0, halo_mat)
	_halo_mesh_cache = mesh
	return mesh


# ---------------------------------------------------------------------------
# Exit route: lantern trail from the plaza to the portal at the lookout
# ---------------------------------------------------------------------------

func _build_exit() -> void:
	var portal: Node3D = (load("res://scenes/props/frost_portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	geo.add_child(portal)
	portal.position = Vector3(-6.0, 0, 21.4)
	portal.rotation.y = PI
	_prop(dressing, "frost_snowbank", "PortalDriftW", Vector3(-9.2, 0, 22.2), 80.0, Vector3(3.2, 1.2, 1.6)).scale = Vector3(0.7, 0.8, 0.7)
	_prop(dressing, "frost_snowbank", "PortalDriftE", Vector3(-2.8, 0, 22.4), 100.0, Vector3(3.2, 1.2, 1.6)).scale = Vector3(0.6, 0.7, 0.6)

	# Lantern stakes along both edges of the trail; they chase cyan once the portal opens.
	var lights := Node3D.new()
	lights.name = "ExitLights"
	level.add_child(lights)
	var a := Vector3(2.4, 0, 10.0)
	var b := Vector3(-5.2, 0, 18.6)
	var dir := (b - a).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var steps := 7
	for k in steps:
		var t := float(k) / (steps - 1)
		var pos := a.lerp(b, t) + side * (1.9 if k % 2 == 0 else -1.9)
		var lantern := _prop(lights, "frost_trail_lantern", "TrailLantern%02d" % k, pos, k * 23.0, Vector3(0.2, 1.2, 0.2))
		_late(lantern, "res://scripts/props/frost_trail_light.gd", {"order": k})
	dressing.get_node("Paving").add_child(_ribbon("TrailExit", [a - dir * 2.0, a.lerp(b, 0.5), b + dir * 1.6], 3.0, _path_material()))


# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(3.0, 0.1, 17.0)
	start.rotation.y = deg_to_rad(4.0)
	start.add_to_group("player_spawn", true)
	level.add_child(start)

	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	var points := {
		"SpawnGondola": [Vector3(-29.0, 0.1, -8.0), 90.0],
		"SpawnShed": [Vector3(-29.0, 0.1, 16.0), 90.0],
		"SpawnChairlift": [LANDING + Vector3(-0.4, 0.1, 1.2), -100.0],
		"SpawnSkiRun": [Vector3(17.0, RUN_TOP_Y + 0.1, RUN_Z_TOP - 5.0), 0.0],
		"SpawnKitchen": [Vector3(8.5, TERRACE_Y + 0.1, -26.6), 0.0],
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
	# Paths keep 0.75 m off walls and props: the largest zombies (a Bruiser or a
	# Yeti is 0.78 m in radius) could not get close enough to a waypoint tucked
	# 0.5 m (or, after contour simplification, less) from a corner to tick it
	# off, and stood pushing at the corner until the stall failsafe moved them.
	mesh.agent_radius = 0.75
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 40.0
	mesh.region_min_size = 14.0
	# Walkable surfaces up to the top of the ski run (keeps roofs out).
	mesh.filter_baking_aabb = AABB(Vector3(-40, -1.0, -46), Vector3(80, RUN_TOP_Y + 1.2, 80))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	region.navigation_mesh = _largest_island(mesh)
	print("build_summit_lodge: navmesh polygons = %d (dropped %d on islands)" % [region.navigation_mesh.get_polygon_count(),
		before - region.navigation_mesh.get_polygon_count()])


## Keeps only the largest connected set of polygons. The bake leaves small
## walkable islands inside the rental hut, on the snowdrift and behind the
## lodge; nothing can reach those, and a path must never end on one.
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


func _snow_material(key: String, rock: float, sparkle: float) -> ShaderMaterial:
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.resource_name = key
	m.shader = load(SHADERS + "frost_snow.gdshader")
	m.set_shader_parameter("snow_texture", load(TEXTURES + "frost_snow.png"))
	m.set_shader_parameter("snow_normal", load(TEXTURES + "frost_snow_normal.png"))
	m.set_shader_parameter("rock_amount", rock)
	m.set_shader_parameter("sparkle_strength", 1.4 * sparkle)
	_materials[key] = m
	return m


func _path_material() -> StandardMaterial3D:
	if _materials.has("path"):
		return _materials["path"]
	var m := StandardMaterial3D.new()
	m.resource_name = "FrostPath"
	m.albedo_texture = load(TEXTURES + "frost_path.png")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 0.85
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_materials["path"] = m
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


## Invisible collision box (for props whose art comes from a .glb).
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


## Invisible upright cylinder collider for posts, poles and trunks: a zombie
## pressing on a round post slides off it, where the flat face of a box post
## can hold one that walks straight into it.
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
