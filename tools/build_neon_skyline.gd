extends SceneTree
## Generator for World 2 / Level 1 "Neon Skyline": a rain-slicked night
## rooftop block above the arcade city.
##
## Rebuilds scenes/levels/neon_skyline.tscn: roofs, ramps, stairs, the
## sky-bridge, parapets and player-only walls, props, spawn markers, the
## loadout station, the portal, lighting, the city backdrop and a baked
## navigation mesh (with disconnected islands, such as prop tops, removed).
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_neon_skyline.gd
##
## Run it with a renderer (not --headless): the headless renderer keeps no
## MultiMesh instance data, so railings, lights and windows would save empty.
##
## NOTE: running this overwrites hand edits made to neon_skyline.tscn.
##
## Layout (metres, top view; -Z = north, away from the start):
##   - Main roof A (y 0) around the helipad vending hub at the origin.
##   - East strip B: landings at y 0, a stairway (north) and a ramp (south)
##     up to the billboard terrace at y 3. Two routes round the hub: the
##     cover-rich west half of the roof and the high road over the terrace.
##   - North: the sky-bridge climbs over the street canyon to the portal roof
##     (y 1.2) with the freight elevator.
##   - Zombie entrances beyond the loop: freight elevator (north, over the
##     bridge), roof access door (west), west and east fire escapes (from
##     below) and a service hatch (north-east landing).

const OUT_PATH := "res://scenes/levels/neon_skyline.tscn"
const MODELS := "res://art/models/"
const SHADERS := "res://art/shaders/"
const TEX := "res://art/textures/"
const SLAB := 0.6

# Building A, the main roof.
const A_X0 := -19.0
const A_X1 := 13.5
const A_Z0 := -16.0
const A_Z1 := 15.0
# Strip B east of A.
const B_X1 := 21.0
const L1 := 3.0
const RAMP_N := Vector2(-13.0, -5.0)    # z at the bottom, z at the top
const RAMP_S := Vector2(11.0, 3.0)
const TERRACE := Vector2(-5.0, 3.0)
# North tower (portal roof) and the sky-bridge.
const N_Y := 1.2
const N_X0 := -13.0
const N_X1 := 9.0
const N_Z0 := -34.0
const N_Z1 := -24.0
const BRIDGE_X := Vector2(-4.25, 0.25)
# Fire escapes (outside the west and east walls).
const FE_W_X := Vector2(-23.5, -19.0)
const FE_E_X := Vector2(21.0, 24.5)
const FE_LOW_W := -3.0
## Both fire escapes enter between these z values (their top landings).
const FE_GAP := Vector2(-2.0, 3.0)
const PARAPET_H := 1.05
const RAIL_H := 1.1
const WALL_H := 6.0
const STREET_Y := -38.0
## Base of the terrace billboard (outside B's east parapet).
const BILLBOARD := Vector3(21.75, 0.0, -7.2)

var level: Node3D
var geo: Node3D          # collidable geometry (navmesh source)
var dressing: Node3D     # non-colliding scenery
var _materials := {}
var _boxes := {}
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 2077
	level = Node3D.new()
	level.name = "NeonSkyline"

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

	_build_roofs()
	_build_east_strip()
	_build_bridge()
	_build_fire_escapes()
	_build_edges()
	_build_entrances()
	_build_station()
	_build_props()
	_build_signage()
	_build_exit()
	_build_lights()
	_build_backdrop()
	_build_markers()

	get_root().add_child(level)
	await process_frame
	_bake_navigation(nav)
	get_root().remove_child(level)

	level.set_script(load("res://scripts/run/neon_skyline_environment.gd"))
	var director := Node.new()
	director.name = "RunDirector"
	director.set_script(load("res://scripts/run/run_director.gd"))
	level.add_child(director)

	_own(level)
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_PATH)
	print("build_neon_skyline: saved %s (error %d)" % [OUT_PATH, err])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: night sky, moon key light, coloured fills, fog
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load(TEX + "neon_sky_night.png")
	pano.energy_multiplier = 1.0
	sky.sky_material = pano
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.42, 0.7)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.4
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.13, 0.36)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.0
	env.fog_height = -4.0
	env.fog_height_density = 0.035
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	# Moonlight: from the moon's side of the sky (north-north-west), higher than
	# the painted moon so shadows stay short and readable.
	var moon := DirectionalLight3D.new()
	moon.name = "Sun"
	var to_moon := Vector3(-0.36, 0.0, -0.93).normalized() * cos(deg_to_rad(48.0)) + Vector3.UP * sin(deg_to_rad(48.0))
	moon.transform = Transform3D(Basis.looking_at(-to_moon, Vector3.UP), Vector3(0, 30, 0))
	moon.light_color = Color(0.66, 0.72, 1.0)
	moon.light_energy = 0.85
	moon.shadow_enabled = true
	moon.shadow_bias = 0.06
	moon.shadow_normal_bias = 1.2
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 80.0
	moon.shadow_opacity = 0.7
	level.add_child(moon)
	# Magenta city glow from the south-east and a cool cyan kick from the west:
	# every silhouette gets a coloured edge on both sides.
	_fill("CityGlow", Vector3(-0.55, -0.35, -0.75), Color(1.0, 0.32, 0.78), 0.42)
	_fill("CyanKick", Vector3(0.85, -0.25, 0.45), Color(0.3, 0.85, 1.0), 0.28)


func _fill(fill_name: String, direction: Vector3, color: Color, energy: float) -> void:
	var fill := DirectionalLight3D.new()
	fill.name = fill_name
	fill.transform = Transform3D(Basis.looking_at(direction.normalized(), Vector3.UP), Vector3(0, 30, 0))
	fill.light_color = color
	fill.light_energy = energy
	fill.shadow_enabled = false
	level.add_child(fill)


# ---------------------------------------------------------------------------
# Roofs
# ---------------------------------------------------------------------------

func _build_roofs() -> void:
	var roofs := Node3D.new()
	roofs.name = "Roofs"
	geo.add_child(roofs)
	_slab(roofs, "RoofA", A_X0, A_X1, A_Z0, A_Z1, 0.0, _roof_material())
	_slab(roofs, "RoofB", A_X1, B_X1, A_Z0, A_Z1, 0.0, _roof_material())
	_slab(roofs, "RoofNorth", N_X0, N_X1, N_Z0, N_Z1, N_Y, _roof_material())
	# Building bodies below the roofs (city facades, no collision).
	_tower_body(dressing, "BodyA", Vector3(A_X0, STREET_Y, A_Z0), Vector3(B_X1, -SLAB, A_Z1), 1.0)
	_tower_body(dressing, "BodyNorth", Vector3(N_X0, STREET_Y, N_Z0), Vector3(N_X1, N_Y - SLAB, N_Z1), 2.0)


## A walkable slab: one collision box plus 8 m visual tiles (so each tile
## only gathers the lights near it; the renderer caps lights per mesh).
func _slab(parent: Node3D, slab_name: String, x0: float, x1: float, z0: float, z1: float, top: float, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = slab_name
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, SLAB, z1 - z0)
	shape.shape = box
	shape.position = Vector3((x0 + x1) * 0.5, top - SLAB * 0.5, (z0 + z1) * 0.5)
	body.add_child(shape)
	var tile := 8.0
	var nx := maxi(1, int(ceil((x1 - x0) / tile)))
	var nz := maxi(1, int(ceil((z1 - z0) / tile)))
	var sx := (x1 - x0) / nx
	var sz := (z1 - z0) / nz
	for i in nx:
		for j in nz:
			var mi := MeshInstance3D.new()
			mi.name = "Tile%d_%d" % [i, j]
			mi.mesh = _box_mesh(Vector3(sx, SLAB, sz), material)
			mi.position = Vector3(x0 + sx * (i + 0.5), top - SLAB * 0.5, z0 + sz * (j + 0.5))
			body.add_child(mi)


func _roof_material(variant := "roof") -> Material:
	if _materials.has(variant):
		return _materials[variant]
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "neon_roof.gdshader")
	m.resource_name = "NeonRoof"
	m.set_shader_parameter("albedo_tex", load(TEX + "neon_roof.png"))
	m.set_shader_parameter("normal_tex", load(TEX + "neon_roof_normal.png"))
	m.set_shader_parameter("puddle_tex", load(TEX + "neon_puddles.png"))
	m.set_shader_parameter("sky_tex", load(TEX + "neon_sky_night.png"))
	var pos := PackedVector4Array()
	var col := PackedVector4Array()
	for entry in NEON_REFLECTIONS:
		pos.append(entry[0])
		col.append(entry[1])
	m.set_shader_parameter("neon_pos", pos)
	m.set_shader_parameter("neon_col", col)
	match variant:
		"terrace":
			m.set_shader_parameter("tint", Color(0.95, 0.88, 1.05))
			m.set_shader_parameter("puddle_amount", 0.35)
		"metal":
			m.set_shader_parameter("tint", Color(0.7, 0.72, 0.85))
			m.set_shader_parameter("tile_metres", 2.0)
			m.set_shader_parameter("puddle_amount", 0.15)
		_:
			m.set_shader_parameter("puddle_amount", 0.32)
	_materials[variant] = m
	return m


## Neon signs mirrored in the puddles: [Vector4(x, y, z, streak width), Vector4(r, g, b, intensity)].
const NEON_REFLECTIONS := [
	[Vector4(0.0, 4.6, 0.0, 0.7), Vector4(0.3, 0.95, 1.0, 0.9)],        # station hologram
	[Vector4(21.4, 9.6, -7.2, 1.6), Vector4(1.0, 0.3, 0.85, 1.0)],      # terrace billboard
	[Vector4(-1.0, 6.0, -33.4, 1.6), Vector4(1.0, 0.45, 0.25, 0.9)],    # rooftop sign
	[Vector4(-14.5, 7.2, 9.5, 0.9), Vector4(0.75, 0.4, 1.0, 0.8)],      # water tower band
	[Vector4(-15.3, 3.4, -8.0, 0.5), Vector4(1.0, 0.75, 0.35, 0.7)],    # roof door lamp
	[Vector4(-2.0, 4.2, -20.0, 0.8), Vector4(0.3, 0.95, 1.0, 0.7)],     # sky-bridge ribs
	[Vector4(-18.6, 6.5, 14.4, 0.7), Vector4(1.0, 0.25, 0.6, 0.9)],     # blade sign
	[Vector4(12.9, 5.0, 14.6, 0.6), Vector4(0.4, 1.0, 0.55, 0.7)],      # south-east sign
]


# ---------------------------------------------------------------------------
# East strip: stairway, terrace, ramp
# ---------------------------------------------------------------------------

func _build_east_strip() -> void:
	var strip := Node3D.new()
	strip.name = "EastStrip"
	geo.add_child(strip)
	var x0 := A_X1
	var x1 := B_X1
	var wall := _facade_material()
	# Terrace block.
	_prism(strip, "Terrace", _box_points(Vector3(x0, 0, TERRACE.x), Vector3(x1, L1, TERRACE.y)), BOX_FACES,
		[wall, _roof_material("terrace")], [0, 0, 0, 0, 9, 1])
	# North stairway (visual steps on a smooth collision slope).
	var pts := _wedge_points(x0, x1, RAMP_N.x, RAMP_N.y, 0.0, L1)
	_prism(strip, "StairsN", pts, WEDGE_FACES, [wall], [0, 0, 0, 9, 9])
	_steps("StairsNSteps", x0 + 0.5, x1 - 0.4, RAMP_N.x, RAMP_N.y, 0.0, L1, 15)
	# South ramp with painted chevrons.
	pts = _wedge_points(x0, x1, RAMP_S.x, RAMP_S.y, 0.0, L1)
	_prism(strip, "RampS", pts, WEDGE_FACES, [wall, _roof_material("metal")], [0, 0, 0, 1, 9])
	_chevrons(dressing, "RampChevrons", (x0 + x1) * 0.5 + 0.25, RAMP_S.x, RAMP_S.y, 0.0, L1)
	# Duct run along A's side of the terrace wall: keeps zombies below from
	# swiping through the wall at a player standing at the terrace railing.
	_duct_run(strip, Vector3(12.0, 0, -10.0), Vector3(13.5, 0.85, 8.0))


## A wedge rising along Z from y_low at z_low to y_high at z_high.
func _wedge_points(x0: float, x1: float, z_low: float, z_high: float, y_low: float, y_high: float) -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(x0, y_low - SLAB, z_low), Vector3(x1, y_low - SLAB, z_low),
		Vector3(x1, y_low - SLAB, z_high), Vector3(x0, y_low - SLAB, z_high),
		Vector3(x0, y_high, z_high), Vector3(x1, y_high, z_high),
		Vector3(x0, y_low, z_low), Vector3(x1, y_low, z_low),
	])

## Faces for _wedge_points: low lip, side x0, side x1, top slope, high end.
const WEDGE_FACES := [[0, 1, 7, 6], [0, 3, 4, 6], [1, 7, 5, 2], [6, 7, 5, 4], [3, 2, 5, 4]]


func _box_points(lo: Vector3, hi: Vector3) -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
	])

## Faces for 8-point boxes (bottom 0-3, top 4-7): -z, +x, +z, -x, bottom, top.
const BOX_FACES := [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [0, 1, 2, 3], [4, 5, 6, 7]]


## Stair treads between two heights (scenery; the collision is a smooth slope).
func _steps(steps_name: String, x0: float, x1: float, z_low: float, z_high: float, y_low: float, y_high: float, count: int) -> void:
	var holder := Node3D.new()
	holder.name = steps_name
	dressing.add_child(holder)
	var run := (z_high - z_low) / count
	var rise := (y_high - y_low) / count
	var tread := _mat("tread", Color(0.24, 0.24, 0.32), 0.45)
	var nose := _mat("tread_nose", Color(1.0, 0.75, 0.2), 0.4, Color(1.0, 0.7, 0.2), 1.2)
	for i in count:
		var z := z_low + run * (i + 0.5)
		# Tread tops straddle the smooth collision slope.
		var y := y_low + rise * (i + 0.5)
		var mi := MeshInstance3D.new()
		mi.name = "Step%02d" % i
		mi.mesh = _box_mesh(Vector3(x1 - x0, 0.12, absf(run) + 0.02), tread)
		mi.position = Vector3((x0 + x1) * 0.5, y - 0.06 + 0.02, z)
		holder.add_child(mi)
		var lip := MeshInstance3D.new()
		lip.name = "Nose%02d" % i
		lip.mesh = _box_mesh(Vector3(x1 - x0, 0.03, 0.06), nose)
		lip.position = Vector3((x0 + x1) * 0.5, y + 0.02, z - run * 0.5)
		lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(lip)


## Painted direction chevrons up the ramp (scenery).
func _chevrons(parent: Node3D, chev_name: String, x: float, z_low: float, z_high: float, y_low: float, y_high: float) -> void:
	var holder := Node3D.new()
	holder.name = chev_name
	parent.add_child(holder)
	var paint := _mat("chevron", Color(0.2, 0.9, 1.0), 0.5, Color(0.2, 0.9, 1.0), 0.6)
	var slope := atan2(y_high - y_low, absf(z_high - z_low))
	var n := 5
	for i in n:
		var t := (i + 0.7) / (n + 0.4)
		var z := lerpf(z_low, z_high, t)
		var y := lerpf(y_low, y_high, t) + 0.02
		for side in [-1, 1]:
			var mi := MeshInstance3D.new()
			mi.name = "Chevron%d_%d" % [i, side + 1]
			mi.mesh = _box_mesh(Vector3(1.6, 0.02, 0.32), paint)
			mi.position = Vector3(x + side * 0.62, y, z)
			mi.rotation = Vector3(slope, deg_to_rad(side * 35.0), 0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)


func _duct_run(parent: Node3D, lo: Vector3, hi: Vector3) -> void:
	var metal := _mat("duct", Color(0.2, 0.2, 0.28), 0.35, Color.BLACK, 0.0, 0.7)
	var band := _mat("duct_band", Color(0.1, 0.09, 0.14), 0.5)
	var body := _box(parent, "DuctRun", hi - lo, (lo + hi) * 0.5, metal)
	var z := lo.z + 1.0
	var i := 0
	while z < hi.z - 0.5:
		var flange := MeshInstance3D.new()
		flange.name = "Flange%02d" % i
		flange.mesh = _box_mesh(Vector3(hi.x - lo.x + 0.1, hi.y - lo.y + 0.1, 0.12), band)
		flange.position = Vector3((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, z) - body.position
		body.add_child(flange)
		z += 2.0
		i += 1
	var conduit := MeshInstance3D.new()
	conduit.name = "Conduit"
	conduit.mesh = _box_mesh(Vector3(0.12, 0.08, hi.z - lo.z - 0.4), _led_material(Color(0.65, 0.4, 1.0)))
	conduit.position = Vector3(lo.x + 0.25, hi.y + 0.04, (lo.z + hi.z) * 0.5) - body.position
	body.add_child(conduit)


# ---------------------------------------------------------------------------
# Sky-bridge
# ---------------------------------------------------------------------------

func _build_bridge() -> void:
	var bridge := Node3D.new()
	bridge.name = "SkyBridge"
	geo.add_child(bridge)
	var x0 := BRIDGE_X.x
	var x1 := BRIDGE_X.y
	var deck := PackedVector3Array([
		Vector3(x0, -0.5, A_Z0), Vector3(x1, -0.5, A_Z0), Vector3(x1, N_Y - 0.5, N_Z1), Vector3(x0, N_Y - 0.5, N_Z1),
		Vector3(x0, 0.0, A_Z0), Vector3(x1, 0.0, A_Z0), Vector3(x1, N_Y, N_Z1), Vector3(x0, N_Y, N_Z1),
	])
	_prism(bridge, "Deck", deck, BOX_FACES, [_mat("bridge_under", Color(0.12, 0.1, 0.2), 0.6), _roof_material("metal")], [0, 0, 0, 0, 0, 1])
	_prop(dressing, "neon_skybridge", "SkyBridgeCanopy", Vector3((x0 + x1) * 0.5, 0, A_Z0), 0.0, Vector3(4.5, 4, 8))
	# The glass canopy keeps the camera-following rain out (neon_skyline_environment.gd).
	_rain_cover("SkyBridgeRainCover", Vector3((x0 + x1) * 0.5, 2.25, (A_Z0 + N_Z1) * 0.5), Vector3((x1 - x0) * 0.5, 2.75, (A_Z0 - N_Z1) * 0.5))


# ---------------------------------------------------------------------------
# Fire escapes (zombie entrances from below)
# ---------------------------------------------------------------------------

func _build_fire_escapes() -> void:
	var fe := Node3D.new()
	fe.name = "FireEscapes"
	geo.add_child(fe)
	var steel := _roof_material("metal")
	var under := _mat("steel_dark", Color(0.13, 0.12, 0.18), 0.45, Color.BLACK, 0.0, 0.6)
	# West: top landing level with the roof, stairs down (south) to a landing at y -3.
	_landing(fe, "FireEscapeWTop", Vector3(FE_W_X.x, 0, FE_GAP.x), Vector3(FE_W_X.y, 0, FE_GAP.y), steel, under)
	_stair_slab(fe, "FireEscapeWStairs", FE_W_X.x, FE_W_X.y, 3.0, 9.0, 0.0, FE_LOW_W, steel, under)
	_landing(fe, "FireEscapeWLow", Vector3(FE_W_X.x, FE_LOW_W, 9.0), Vector3(FE_W_X.y, FE_LOW_W, 13.0), steel, under)
	_fire_escape_frame("FireEscapeWFrame", FE_W_X.x, FE_W_X.y, 0.0, FE_LOW_W, -1.0)
	# East: top landing level with the terrace, stairs down (south) to y 0.
	_landing(fe, "FireEscapeETop", Vector3(FE_E_X.x, L1, FE_GAP.x), Vector3(FE_E_X.y, L1, FE_GAP.y), steel, under)
	_stair_slab(fe, "FireEscapeEStairs", FE_E_X.x + 0.25, FE_E_X.y, 3.0, 9.0, L1, 0.0, steel, under)
	_landing(fe, "FireEscapeELow", Vector3(FE_E_X.x, 0, 9.0), Vector3(FE_E_X.y, 0, 13.0), steel, under)
	_fire_escape_frame("FireEscapeEFrame", FE_E_X.x, FE_E_X.y, L1, 0.0, 1.0)


## Steel under-structure of a fire escape: brackets from the facade under both
## landings and the flight, posts down the outer edge and a drop ladder.
## `outward` is +1 when the escape hangs east of its building, -1 for west.
func _fire_escape_frame(frame_name: String, x0: float, x1: float, y_top: float, y_low: float, outward: float) -> void:
	var holder := Node3D.new()
	holder.name = frame_name
	dressing.add_child(holder)
	var steel := _mat("fe_steel", Color(0.16, 0.13, 0.2), 0.5, Color.BLACK, 0.0, 0.5)
	var wall_x := x0 if outward > 0.0 else x1
	var out_x := x1 if outward > 0.0 else x0
	var spots := [[FE_GAP.x + 0.3, y_top], [FE_GAP.y - 0.3, y_top], [9.3, y_low], [12.7, y_low]]
	for s in spots:
		var z: float = s[0]
		var y: float = s[1] - 0.3
		_strut(holder, Vector3(wall_x, y - 1.6, z), Vector3(out_x, y, z), 0.09, steel)
		_strut(holder, Vector3(wall_x, y, z), Vector3(out_x, y, z), 0.09, steel)
	for z in [FE_GAP.x + 0.1, 3.0, 9.1, 12.9]:
		_strut(holder, Vector3(out_x - outward * 0.1, y_low - 6.0, z), Vector3(out_x - outward * 0.1, y_top + RAIL_H, z), 0.1, steel)
	_strut(holder, Vector3(out_x - outward * 0.1, y_top - 0.3, 3.0), Vector3(out_x - outward * 0.1, y_low - 0.3, 9.0), 0.08, steel)
	# Drop ladder hanging from the lower landing.
	var lx := (x0 + x1) * 0.5
	for side in [-0.25, 0.25]:
		_strut(holder, Vector3(lx + side, y_low - 0.3, 13.1), Vector3(lx + side, y_low - 4.5, 13.1), 0.05, steel)
	for k in 12:
		var y := y_low - 0.6 - k * 0.33
		_strut(holder, Vector3(lx - 0.25, y, 13.1), Vector3(lx + 0.25, y, 13.1), 0.04, steel)
	var lamp := MeshInstance3D.new()
	lamp.name = "Lamp"
	lamp.mesh = _box_mesh(Vector3(0.3, 0.18, 0.3), _mat("fe_lamp", Color(1.0, 0.6, 0.3), 0.4, Color(1.0, 0.55, 0.25), 3.0))
	lamp.position = Vector3(wall_x + outward * 0.15, y_top + 2.2, 4.0)
	holder.add_child(lamp)


## A square bar between two points (scenery).
func _strut(parent: Node3D, a: Vector3, b: Vector3, width: float, material: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Strut%d" % parent.get_child_count()
	mi.mesh = _box_mesh(Vector3(width, width, 1.0), material)
	var dir := b - a
	var up := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(dir, up).scaled(Vector3(1, 1, dir.length())), (a + b) * 0.5)
	parent.add_child(mi)


func _landing(parent: Node3D, landing_name: String, lo: Vector3, hi: Vector3, top: Material, side: Material) -> void:
	_prism(parent, landing_name, _box_points(Vector3(lo.x, lo.y - 0.25, lo.z), Vector3(hi.x, hi.y, hi.z)), BOX_FACES,
		[side, top], [0, 0, 0, 0, 0, 1])


## Open stair flight: a thin sloped slab with treads; z_a/y_a at the north end.
func _stair_slab(parent: Node3D, stair_name: String, x0: float, x1: float, z_a: float, z_b: float, y_a: float, y_b: float, top: Material, side: Material) -> void:
	var pts := PackedVector3Array([
		Vector3(x0, y_a - 0.3, z_a), Vector3(x1, y_a - 0.3, z_a), Vector3(x1, y_b - 0.3, z_b), Vector3(x0, y_b - 0.3, z_b),
		Vector3(x0, y_a, z_a), Vector3(x1, y_a, z_a), Vector3(x1, y_b, z_b), Vector3(x0, y_b, z_b),
	])
	_prism(parent, stair_name, pts, BOX_FACES, [side, top], [0, 0, 0, 0, 0, 9])
	# Steps run from the low end up.
	if y_a > y_b:
		_steps(stair_name + "Steps", x0, x1, z_b, z_a, y_b, y_a, 12)
	else:
		_steps(stair_name + "Steps", x0, x1, z_a, z_b, y_a, y_b, 12)


# ---------------------------------------------------------------------------
# Edges: parapets, railings and player-only walls
# ---------------------------------------------------------------------------

func _build_edges() -> void:
	var edges := Node3D.new()
	edges.name = "Edges"
	geo.add_child(edges)
	# Main roof A + B outer rim (y 0), with gaps for the bridge and fire escapes.
	_parapet(edges, "NorthWest", Vector3(A_X0, 0, A_Z0), Vector3(BRIDGE_X.x, 0, A_Z0))
	_parapet(edges, "NorthEast", Vector3(BRIDGE_X.y, 0, A_Z0), Vector3(B_X1, 0, A_Z0))
	_parapet(edges, "South", Vector3(A_X0, 0, A_Z1), Vector3(B_X1, 0, A_Z1))
	_parapet(edges, "WestNorth", Vector3(A_X0, 0, A_Z0), Vector3(A_X0, 0, FE_GAP.x))
	_parapet(edges, "WestSouth", Vector3(A_X0, 0, FE_GAP.y), Vector3(A_X0, 0, A_Z1))
	# B's east rim follows the stairs, terrace and ramp.
	_parapet(edges, "EastLandingN", Vector3(B_X1, 0, A_Z0), Vector3(B_X1, 0, RAMP_N.x))
	_parapet(edges, "EastStairs", Vector3(B_X1, 0, RAMP_N.x), Vector3(B_X1, L1, RAMP_N.y))
	_parapet(edges, "EastTerrace", Vector3(B_X1, L1, TERRACE.x), Vector3(B_X1, L1, FE_GAP.x))
	_parapet(edges, "EastRamp", Vector3(B_X1, L1, RAMP_S.y), Vector3(B_X1, 0, RAMP_S.x))
	_parapet(edges, "EastLandingS", Vector3(B_X1, 0, RAMP_S.x), Vector3(B_X1, 0, A_Z1))
	# Inner railing between the plaza and the stairs / terrace / ramp.
	var rx := A_X1 + 0.25
	_railing(edges, "InnerStairs", Vector3(rx, 0, RAMP_N.x), Vector3(rx, L1, RAMP_N.y), false)
	_railing(edges, "InnerTerrace", Vector3(rx, L1, TERRACE.x), Vector3(rx, L1, TERRACE.y), false)
	_railing(edges, "InnerRamp", Vector3(rx, L1, RAMP_S.y), Vector3(rx, 0, RAMP_S.x), false)
	# North tower rim.
	_parapet(edges, "NorthTowerBack", Vector3(N_X0, N_Y, N_Z0), Vector3(N_X1, N_Y, N_Z0))
	_parapet(edges, "NorthTowerWest", Vector3(N_X0, N_Y, N_Z0), Vector3(N_X0, N_Y, N_Z1))
	_parapet(edges, "NorthTowerEast", Vector3(N_X1, N_Y, N_Z0), Vector3(N_X1, N_Y, N_Z1))
	_parapet(edges, "NorthTowerFrontW", Vector3(N_X0, N_Y, N_Z1), Vector3(BRIDGE_X.x, N_Y, N_Z1))
	_parapet(edges, "NorthTowerFrontE", Vector3(BRIDGE_X.y, N_Y, N_Z1), Vector3(N_X1, N_Y, N_Z1))
	# Sky-bridge sides.
	_railing(edges, "BridgeWest", Vector3(BRIDGE_X.x + 0.1, 0, A_Z0), Vector3(BRIDGE_X.x + 0.1, N_Y, N_Z1), true)
	_railing(edges, "BridgeEast", Vector3(BRIDGE_X.y - 0.1, 0, A_Z0), Vector3(BRIDGE_X.y - 0.1, N_Y, N_Z1), true)
	# West fire escape (the stairs run along A's facade, which needs collision).
	var wx0 := FE_W_X.x
	_railing(edges, "FEWTopNorth", Vector3(A_X0, 0, FE_GAP.x), Vector3(wx0, 0, FE_GAP.x), true)
	_railing(edges, "FEWTopWest", Vector3(wx0, 0, FE_GAP.x), Vector3(wx0, 0, 3.0), true)
	_railing(edges, "FEWStairsWest", Vector3(wx0, 0, 3.0), Vector3(wx0, FE_LOW_W, 9.0), true)
	_railing(edges, "FEWLowWest", Vector3(wx0, FE_LOW_W, 9.0), Vector3(wx0, FE_LOW_W, 13.0), true)
	_railing(edges, "FEWLowSouth", Vector3(wx0, FE_LOW_W, 13.0), Vector3(FE_W_X.y, FE_LOW_W, 13.0), true)
	_wall(edges, "FEWFacade", Vector3(A_X0 - 0.2, FE_LOW_W - 0.5, 3.0), Vector3(A_X0 - 0.2, FE_LOW_W - 0.5, 13.0), 0.0, -FE_LOW_W + 0.5, 0.4, null, true)
	# East fire escape.
	var ex1 := FE_E_X.y
	_railing(edges, "FEETopNorth", Vector3(B_X1, L1, FE_GAP.x), Vector3(ex1, L1, FE_GAP.x), true)
	_railing(edges, "FEETopEast", Vector3(ex1, L1, FE_GAP.x), Vector3(ex1, L1, 3.0), true)
	_railing(edges, "FEEStairsEast", Vector3(ex1, L1, 3.0), Vector3(ex1, 0, 9.0), true)
	_railing(edges, "FEELowEast", Vector3(ex1, 0, 9.0), Vector3(ex1, 0, 13.0), true)
	_railing(edges, "FEELowSouth", Vector3(ex1, 0, 13.0), Vector3(B_X1, 0, 13.0), true)


## A roof-edge parapet (concrete, coping, LED strip) with a player-only wall.
func _parapet(parent: Node3D, edge_name: String, a: Vector3, b: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "Parapet" + edge_name
	parent.add_child(holder)
	var concrete := _mat("parapet", Color(0.22, 0.2, 0.32), 0.85)
	var coping := _mat("coping", Color(0.45, 0.43, 0.55), 0.6)
	var led := _led_material(_edge_color(a, b))
	_wall(holder, "Wall", a, b, 0.0, PARAPET_H, 0.42, concrete, true)
	_wall(holder, "Coping", a, b, PARAPET_H, 0.1, 0.56, coping, false)
	_wall(holder, "Led", a, b, PARAPET_H - 0.12, 0.05, 0.45, led, false)
	_player_wall(holder, a, b, PARAPET_H)


## Glass balustrade with a glowing handrail. `outer` adds a player-only wall.
func _railing(parent: Node3D, edge_name: String, a: Vector3, b: Vector3, outer: bool) -> void:
	var holder := Node3D.new()
	holder.name = "Railing" + edge_name
	parent.add_child(holder)
	var glass := _glass_material()
	var steel := _mat("rail_steel", Color(0.3, 0.3, 0.4), 0.35, Color.BLACK, 0.0, 0.7)
	var led := _led_material(Color(0.3, 0.95, 1.0))
	_wall(holder, "Glass", a, b, 0.12, RAIL_H - 0.2, 0.05, glass, false)
	_wall(holder, "Kick", a, b, 0.0, 0.14, 0.18, steel, false)
	_wall(holder, "Handrail", a, b, RAIL_H - 0.08, 0.08, 0.14, steel, false)
	_wall(holder, "HandrailLed", a, b, RAIL_H - 0.11, 0.03, 0.15, led, false)
	_posts(holder, a, b, steel)
	# One collision slab for the whole railing (blocks the player and zombies).
	_wall(holder, "Collision", a, b, 0.0, RAIL_H, 0.2, null, true)
	if outer:
		_player_wall(holder, a, b, RAIL_H)


func _posts(parent: Node3D, a: Vector3, b: Vector3, material: Material) -> void:
	var length := Vector2(b.x - a.x, b.z - a.z).length()
	var count := maxi(1, int(round(length / 1.6)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _box_mesh(Vector3(0.09, RAIL_H, 0.09), material)
	mm.instance_count = count + 1
	for i in count + 1:
		var p := a.lerp(b, float(i) / count)
		mm.set_instance_transform(i, Transform3D(Basis(), p + Vector3.UP * RAIL_H * 0.5))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Posts"
	mmi.multimesh = mm
	parent.add_child(mmi)


## Slab between two floor points (sloped ends keep their verticals upright).
## A null material makes an invisible collider.
func _wall(parent: Node3D, wall_name: String, a: Vector3, b: Vector3, y0: float, height: float, thickness: float, material: Material, collide: bool) -> void:
	var dir := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var side := Vector3(-dir.z, 0, dir.x) * thickness * 0.5
	var lo := Vector3.UP * y0
	var hi := Vector3.UP * (y0 + height)
	var pts := PackedVector3Array([
		a - side + lo, b - side + lo, b + side + lo, a + side + lo,
		a - side + hi, b - side + hi, b + side + hi, a + side + hi,
	])
	if material == null:
		var body := StaticBody3D.new()
		body.name = wall_name
		parent.add_child(body)
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var convex := ConvexPolygonShape3D.new()
		convex.points = pts
		shape.shape = convex
		body.add_child(shape)
		return
	_prism(parent, wall_name, pts, BOX_FACES, [material], [], collide)


## Invisible wall on its own layer ("player_walls"): stops the player from
## jumping off the roof, but not shots, zombies or navigation.
func _player_wall(parent: Node3D, a: Vector3, b: Vector3, from_height: float) -> void:
	var body := StaticBody3D.new()
	body.name = "PlayerWall"
	body.collision_layer = 16
	body.collision_mask = 0
	parent.add_child(body)
	var dir := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var side := Vector3(-dir.z, 0, dir.x) * 0.15
	var lo := Vector3.UP * from_height
	var hi := Vector3.UP * WALL_H
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var convex := ConvexPolygonShape3D.new()
	convex.points = PackedVector3Array([
		a - side + lo, b - side + lo, b + side + lo, a + side + lo,
		a - side + hi, b - side + hi, b + side + hi, a + side + hi,
	])
	shape.shape = convex
	body.add_child(shape)


## Parapet LED colour by compass side: cyan north, magenta south, violet else.
func _edge_color(a: Vector3, b: Vector3) -> Color:
	var mid := (a + b) * 0.5
	if mid.z < A_Z0 + 1.0:
		return Color(0.3, 0.95, 1.0)
	if mid.z > A_Z1 - 1.0:
		return Color(1.0, 0.3, 0.8)
	return Color(0.65, 0.4, 1.0)


# ---------------------------------------------------------------------------
# Entrances
# ---------------------------------------------------------------------------

func _build_entrances() -> void:
	var entrances := Node3D.new()
	entrances.name = "Entrances"
	geo.add_child(entrances)
	# Roof access stairwell on the west edge; its door faces east.
	_prop(entrances, "neon_roof_door", "RoofDoor", Vector3(-17.25, 0, -8.0), 90.0, Vector3(6, 3.2, 3.5))
	_collider(entrances, "RoofDoorBody", Vector3(3.5, 3.4, 6.0), Vector3(-17.25, 1.7, -8.0))
	# Freight elevator on the portal roof; doors face south (toward the bridge).
	_prop(entrances, "neon_freight_elevator", "FreightElevator", Vector3(-9.5, N_Y, -31.0), 0.0, Vector3(5, 4.6, 5))
	_collider(entrances, "FreightElevatorBody", Vector3(5.0, 4.6, 5.0), Vector3(-9.5, N_Y + 2.3, -31.0))
	# Service hatch on the north-east landing (flush: no collision).
	_prop(dressing, "neon_hatch", "ServiceHatch", Vector3(17.5, 0, -14.6), 0.0, Vector3(1.6, 0.1, 1.6))


# ---------------------------------------------------------------------------
# Loadout station on the helipad
# ---------------------------------------------------------------------------

func _build_station() -> void:
	var holder := Node3D.new()
	holder.name = "Helipad"
	geo.add_child(holder)
	var station: Node3D = (load("res://scenes/props/neon_station.tscn") as PackedScene).instantiate()
	station.name = "Station"
	holder.add_child(station)
	_prop(dressing, "neon_helipad", "HelipadMarkings", Vector3.ZERO, 0.0, Vector3(14, 0.02, 14))


# ---------------------------------------------------------------------------
# Rooftop props (cover, landmarks)
# ---------------------------------------------------------------------------

func _build_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	geo.add_child(props)
	# Water tower in the south-west corner (legs are the only collision).
	_prop(props, "neon_water_tower", "WaterTower", Vector3(-14.5, 0, 9.5), 70.0, Vector3(5, 10, 5))
	_rain_cover("WaterTowerRainCover", Vector3(-14.5, 2.5, 9.5), Vector3(2.2, 2.5, 2.2))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var leg := Vector2(corner.x, corner.y).rotated(-deg_to_rad(70.0)) * 1.75
		_collider(props, "WaterTowerLeg%d" % props.get_child_count(), Vector3(0.45, 4.2, 0.45), Vector3(-14.5 + leg.x, 2.1, 9.5 + leg.y))
	# Skylights: low cover either side of the hub.
	_solid_prop(props, "neon_skylight", "SkylightWest", Vector3(-6.5, 0, 4.5), 0.0, Vector3(3.2, 1.2, 2.2))
	_solid_prop(props, "neon_skylight", "SkylightEast", Vector3(5.5, 0, -6.5), 90.0, Vector3(3.2, 1.2, 2.2))
	# Air-conditioning units.
	_solid_prop(props, "neon_ac_unit", "ACNorthWest", Vector3(-12.5, 0, -13.4), 0.0, Vector3(2.6, 1.5, 1.8))
	_solid_prop(props, "neon_ac_unit", "ACWest", Vector3(-16.9, 0, 5.2), 90.0, Vector3(2.6, 1.5, 1.8))
	_solid_prop(props, "neon_ac_unit", "ACNorth", Vector3(7.0, 0, -13.6), 0.0, Vector3(2.6, 1.5, 1.8))
	_solid_prop(props, "neon_ac_unit", "ACTerrace", Vector3(19.4, L1, -3.6), 90.0, Vector3(2.6, 1.5, 1.8))
	# Vents and crates along the rim, clear of the loop.
	_solid_prop(props, "neon_vent", "VentSouthWest", Vector3(-9.0, 0, 13.6), 0.0, Vector3(1.2, 1.6, 1.2))
	_solid_prop(props, "neon_vent", "VentSouthEast", Vector3(10.4, 0, 13.4), 0.0, Vector3(1.2, 1.6, 1.2))
	_solid_prop(props, "neon_vent", "VentNorthWest", Vector3(-17.6, 0, -14.5), 0.0, Vector3(1.2, 1.6, 1.2))
	_solid_prop(props, "neon_crates", "CratesNorth", Vector3(-9.0, 0, -14.6), 0.0, Vector3(2.4, 1.3, 1.2))
	_solid_prop(props, "neon_crates", "CratesSouthLanding", Vector3(19.4, 0, 13.6), 0.0, Vector3(2.4, 1.3, 1.2))
	_solid_prop(props, "neon_crates", "CratesPortalRoof", Vector3(6.6, N_Y, -32.6), 0.0, Vector3(2.4, 1.3, 1.2))
	# Antenna masts with blinking beacons (thin, collision only at the base).
	# Keep the corners where the east strip meets the main roof clear.
	for entry in [[Vector3(-17.6, 0, -11.2), 0.0], [Vector3(17.0, 0, 14.4), 30.0], [Vector3(-11.8, N_Y, -33.0), 10.0], [Vector3(6.0, 0, 14.3), 60.0]]:
		_prop(props, "neon_antenna", "Antenna%d" % props.get_child_count(), entry[0], entry[1], Vector3(0.8, 9, 0.8))
		_collider(props, "AntennaBase%d" % props.get_child_count(), Vector3(0.9, 1.2, 0.9), entry[0] + Vector3(0, 0.6, 0))
	# Satellite dishes on the north-east landing.
	_solid_prop(props, "neon_dish", "DishNorthEast", Vector3(19.8, 0, -15.0), -30.0, Vector3(1.4, 2.0, 1.4))


## A prop with a matching box collider.
func _solid_prop(parent: Node3D, model: String, prop_name: String, pos: Vector3, yaw: float, size: Vector3) -> void:
	_prop(parent, model, prop_name, pos, yaw, size)
	var c := _collider(parent, prop_name + "Collision", size, pos + Vector3(0, size.y * 0.5, 0))
	c.rotation.y = deg_to_rad(yaw)


# ---------------------------------------------------------------------------
# Signage: billboard, rooftop sign, blade signs
# ---------------------------------------------------------------------------

func _build_signage() -> void:
	var signs := Node3D.new()
	signs.name = "Signage"
	geo.add_child(signs)
	# Giant billboard on the terrace, facing the plaza.
	# Giant billboard bracketed to the outside of the terrace, facing the plaza.
	_prop(dressing, "neon_billboard", "TerraceBillboard", Vector3(BILLBOARD.x, L1, BILLBOARD.z), -90.0, Vector3(1, 9, 10))
	_screen(dressing, "TerraceScreen", BILLBOARD + Vector3(-0.35, L1 + 6.6, 0), -90.0, Vector2(9.6, 4.8), 0, 4, 3.0, 0.0)
	# Rooftop sign along the back of the portal roof, facing south.
	_prop(signs, "neon_rooftop_sign", "RooftopSign", Vector3(-1.0, N_Y, N_Z0 + 0.6), 0.0, Vector3(16, 6, 1)).scale = Vector3.ONE * 1.3
	# Blade signs on the corners.
	_prop(dressing, "neon_blade_sign", "BladeSignSouthWest", Vector3(-18.6, 0, 14.4), 45.0, Vector3(1, 8, 2))
	_prop(dressing, "neon_blade_sign_b", "BladeSignSouthEast", Vector3(12.9, 0, 14.6), -45.0, Vector3(1, 6, 2))


## An advert screen quad using the atlas shader. Faces +Z before `yaw`.
func _screen(parent: Node3D, screen_name: String, pos: Vector3, yaw: float, size: Vector2, row: int, frames: int, frame_time: float, scroll: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "neon_screen.gdshader")
	m.set_shader_parameter("atlas", load(TEX + "neon_ads.png"))
	m.set_shader_parameter("row", row)
	m.set_shader_parameter("frames", frames)
	m.set_shader_parameter("frame_time", frame_time)
	m.set_shader_parameter("scroll", scroll)
	m.set_shader_parameter("time_offset", _rng.randf_range(0.0, 20.0))
	quad.material = m
	var mi := MeshInstance3D.new()
	mi.name = screen_name
	mi.mesh = quad
	mi.position = pos
	mi.rotation.y = deg_to_rad(yaw)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------------------
# Exit route
# ---------------------------------------------------------------------------

func _build_exit() -> void:
	var portal: Node3D = (load("res://scenes/props/neon_portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	geo.add_child(portal)
	portal.position = Vector3(4.0, N_Y, -29.5)

	var lights := Node3D.new()
	lights.name = "ExitLights"
	level.add_child(lights)
	var strip := BoxMesh.new()
	strip.size = Vector3(0.24, 0.04, 1.3)
	var light_script: Script = load("res://scripts/props/exit_light.gd")
	var route: Array[Vector3] = []
	var z := -7.5
	while z > A_Z0:
		route.append(Vector3(-2.0, 0.0, z))
		z -= 2.4
	z = A_Z0 - 0.6
	while z > N_Z1:
		var t := (A_Z0 - z) / (A_Z0 - N_Z1)
		route.append(Vector3(-2.0, N_Y * t, z))
		z -= 2.0
	for p in [Vector3(-1.2, N_Y, -25.6), Vector3(0.6, N_Y, -26.6), Vector3(2.3, N_Y, -27.4)]:
		route.append(p)
	var slope := atan2(N_Y, A_Z0 - N_Z1)
	for i in route.size():
		var mi := MeshInstance3D.new()
		mi.name = "ExitLight%02d" % i
		mi.mesh = strip
		mi.position = route[i] + Vector3(0, 0.035, 0)
		if route[i].z < A_Z0 and route[i].z > N_Z1:
			mi.rotation.x = slope
		elif route[i].z <= N_Z1:
			mi.rotation.y = deg_to_rad(-55.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_script(light_script)
		mi.set("order", i)
		lights.add_child(mi)


# ---------------------------------------------------------------------------
# Lights (few, unshadowed; emissive materials do most of the work)
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	var lights := Node3D.new()
	lights.name = "Lights"
	level.add_child(lights)
	var spots := [
		["StationGlow", Vector3(0, 4.0, 0), Color(0.3, 0.9, 1.0), 2.2, 11.0],
		["BillboardWash", Vector3(16.5, 8.0, -7.2), Color(1.0, 0.3, 0.8), 2.6, 17.0],
		["WaterTowerGlow", Vector3(-12.5, 5.0, 8.0), Color(0.7, 0.4, 1.0), 1.8, 11.0],
		["RoofDoorLamp", Vector3(-14.6, 3.0, -8.0), Color(1.0, 0.72, 0.38), 1.8, 8.0],
		["BridgeGlow", Vector3(-2.0, 3.4, -20.0), Color(0.3, 0.95, 1.0), 1.6, 10.0],
		["RooftopSignWash", Vector3(-1.0, 6.0, -30.5), Color(1.0, 0.45, 0.3), 2.2, 15.0],
		["SouthWestSign", Vector3(-16.0, 4.0, 12.0), Color(1.0, 0.25, 0.6), 1.6, 10.0],
		["SouthEastSign", Vector3(10.5, 4.0, 12.0), Color(0.4, 1.0, 0.55), 1.4, 10.0],
		["ElevatorLamp", Vector3(-9.5, N_Y + 3.8, -27.5), Color(1.0, 0.85, 0.3), 1.5, 9.0],
		["FireEscapeEast", Vector3(23.0, 2.5, 7.0), Color(1.0, 0.5, 0.25), 1.2, 8.0],
		["FireEscapeWest", Vector3(-21.0, 0.5, 7.0), Color(1.0, 0.5, 0.25), 1.2, 8.0],
	]
	for s in spots:
		var l := OmniLight3D.new()
		l.name = s[0]
		l.position = s[1]
		l.light_color = s[2]
		l.light_energy = s[3]
		l.omni_range = s[4]
		l.omni_attenuation = 1.4
		l.shadow_enabled = false
		lights.add_child(l)


# ---------------------------------------------------------------------------
# City backdrop (no collision): street canyon, towers, adverts, holograms
# ---------------------------------------------------------------------------

func _build_backdrop() -> void:
	var city := Node3D.new()
	city.name = "City"
	level.add_child(city)
	# Streets far below, glowing with traffic.
	_street(city, "StreetNorth", Vector3(0, STREET_Y, (A_Z0 + N_Z1) * 0.5), 0.0, Vector2(260, 8.0))
	_street(city, "StreetEast", Vector3(28.0, STREET_Y, -10.0), 90.0, Vector2(260, 12.0))
	_street(city, "StreetSouth", Vector3(0, STREET_Y, 22.0), 0.0, Vector2(260, 12.0))
	_street(city, "StreetWest", Vector3(-28.0, STREET_Y, -10.0), 90.0, Vector2(260, 12.0))
	# Haze rising out of the canyons.
	for entry in [[Vector3(0, -14.0, -20.0), Vector2(90, 8)], [Vector3(27.0, -14.0, -5.0), Vector2(12, 90)],
			[Vector3(0, -14.0, 21.0), Vector2(90, 12)], [Vector3(-27.0, -14.0, -5.0), Vector2(12, 90)]]:
		var plane := PlaneMesh.new()
		plane.size = entry[1]
		plane.material = _glow_material("canyon_haze", Color(0.55, 0.2, 0.75), 0.22, 0)
		var mi := MeshInstance3D.new()
		mi.name = "CanyonHaze%d" % city.get_child_count()
		mi.mesh = plane
		mi.position = entry[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		city.add_child(mi)
	# Neighbouring blocks: lower roofs right across the streets, towers beyond.
	_neighbour(city, Vector3(34, -7.0, -40), Vector3(62, -7.0, 10), 1)
	_neighbour(city, Vector3(-60, -5.0, -40), Vector3(-34, -5.0, 6), 2)
	_neighbour(city, Vector3(-40, -9.0, 28), Vector3(30, -9.0, 50), 3)
	_neighbour(city, Vector3(-30, -3.0, -70), Vector3(20, -3.0, -40), 4)
	_neighbour(city, Vector3(13, -4.0, -42), Vector3(36, -4.0, -24), 5)
	_neighbour(city, Vector3(-36, -6.0, -42), Vector3(-17, -6.0, -24), 6)
	_towers(city)
	_holograms(city)


func _street(parent: Node3D, street_name: String, pos: Vector3, yaw: float, size: Vector2) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "neon_traffic.gdshader")
	m.set_shader_parameter("length_metres", size.x)
	m.set_shader_parameter("lanes", 4.0 if size.y < 10.0 else 6.0)
	plane.material = m
	var mi := MeshInstance3D.new()
	mi.name = street_name
	mi.mesh = plane
	mi.position = pos
	mi.rotation.y = deg_to_rad(yaw)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## A building body with procedural lit windows.
func _tower_body(parent: Node3D, body_name: String, lo: Vector3, hi: Vector3, seed_value: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = body_name
	var key := "windows_%d" % int(seed_value)
	var m: ShaderMaterial = _materials.get(key)
	if m == null:
		m = ShaderMaterial.new()
		m.shader = load(SHADERS + "neon_windows.gdshader")
		m.set_shader_parameter("seed", seed_value)
		m.set_shader_parameter("lit_ratio", 0.32 + fmod(seed_value * 0.137, 0.3))
		_materials[key] = m
	var box := BoxMesh.new()
	box.size = hi - lo
	box.material = m
	mi.mesh = box
	mi.position = (lo + hi) * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A lower neighbouring roof block with a lit rim and a little rooftop clutter.
func _neighbour(parent: Node3D, lo: Vector3, hi: Vector3, index: int) -> void:
	var top := lo.y
	_tower_body(parent, "Neighbour%d" % index, Vector3(lo.x, STREET_Y - 2.0, lo.z), Vector3(hi.x, top, hi.z), 10.0 + index)
	var rim := _led_material([Color(1.0, 0.3, 0.8), Color(0.3, 0.95, 1.0), Color(0.7, 0.4, 1.0), Color(1.0, 0.7, 0.3)][index % 4])
	for edge in [[Vector3(lo.x, top, lo.z), Vector3(hi.x, top, lo.z)], [Vector3(hi.x, top, lo.z), Vector3(hi.x, top, hi.z)],
			[Vector3(hi.x, top, hi.z), Vector3(lo.x, top, hi.z)], [Vector3(lo.x, top, hi.z), Vector3(lo.x, top, lo.z)]]:
		_wall(parent, "NeighbourRim%d_%d" % [index, parent.get_child_count()], edge[0], edge[1], 0.0, 0.25, 0.3, rim, false)
	for k in 5:
		var size := Vector3(_rng.randf_range(2, 5), _rng.randf_range(1.5, 4), _rng.randf_range(2, 5))
		var p := Vector3(_rng.randf_range(lo.x + 3, hi.x - 3), top + size.y * 0.5, _rng.randf_range(lo.z + 3, hi.z - 3))
		var mi := MeshInstance3D.new()
		mi.name = "NeighbourBox%d_%d" % [index, k]
		mi.mesh = _box_mesh(size, _mat("neighbour_box", Color(0.12, 0.11, 0.2), 0.8))
		mi.position = p
		parent.add_child(mi)


## Skyline towers ringed around the block, with crowns and adverts facing in.
func _towers(parent: Node3D) -> void:
	var placed := 0
	var tries := 0
	var screens_left := [1, 2, 3, 4, 5, 7]
	while placed < 26 and tries < 400:
		tries += 1
		var angle := _rng.randf_range(-PI, PI)
		var dist := _rng.randf_range(62.0, 150.0)
		var c := Vector3(sin(angle) * dist, 0, cos(angle) * dist - 8.0)
		var w := _rng.randf_range(12.0, 26.0)
		var d := _rng.randf_range(12.0, 26.0)
		var h := _rng.randf_range(4.0, 70.0) if dist > 80.0 else _rng.randf_range(-2.0, 30.0)
		var lo := Vector3(c.x - w * 0.5, STREET_Y - 2.0, c.z - d * 0.5)
		var hi := Vector3(c.x + w * 0.5, h, c.z + d * 0.5)
		# Keep the immediate neighbours' footprints clear.
		if absf(c.x) < 50.0 + w * 0.5 and absf(c.z + 10.0) < 50.0 + d * 0.5:
			continue
		_tower_body(parent, "Tower%02d" % placed, lo, hi, 20.0 + placed)
		_crown(parent, placed, lo, hi)
		# Face the block: an advert on the side toward the origin.
		if not screens_left.is_empty() and h > 12.0 and _rng.randf() < 0.6:
			var to_centre := Vector3(-c.x, 0, -c.z - 8.0).normalized()
			var yaw := rad_to_deg(atan2(to_centre.x, to_centre.z))
			var face := c + to_centre * (minf(w, d) * 0.5 + 0.3)
			var sw := minf(w, d) * 0.8
			_screen(parent, "TowerAd%02d" % placed, Vector3(face.x, h - sw * 0.35 - 2.0, face.z), yaw, Vector2(sw, sw * 0.5),
				screens_left.pop_front(), 4, _rng.randf_range(2.2, 3.4), 0.0)
		placed += 1


## Neon outline bands and blinking-red aviation lights on a tower top.
func _crown(parent: Node3D, index: int, lo: Vector3, hi: Vector3) -> void:
	var colors := [Color(1.0, 0.3, 0.8), Color(0.3, 0.95, 1.0), Color(0.7, 0.4, 1.0), Color(1.0, 0.75, 0.3)]
	var led := _led_material(colors[index % colors.size()])
	var corners := [Vector3(lo.x, 0, lo.z), Vector3(hi.x, 0, lo.z), Vector3(hi.x, 0, hi.z), Vector3(lo.x, 0, hi.z)]
	for k in 4:
		_wall(parent, "Crown%02d_%d" % [index, k], corners[k], corners[(k + 1) % 4], hi.y - 0.4, 0.35, 0.25, led, false)
	if index % 3 == 0:
		var setback := Vector3((hi.x - lo.x) * 0.2, 0, (hi.z - lo.z) * 0.2)
		_tower_body(parent, "Setback%02d" % index, Vector3(lo.x, hi.y - 1.0, lo.z) + setback, Vector3(hi.x, hi.y + 9.0, hi.z) - setback, 60.0 + index)
	var beacon := MeshInstance3D.new()
	beacon.name = "Beacon%02d" % index
	beacon.mesh = _beacon_mesh()
	beacon.position = Vector3((lo.x + hi.x) * 0.5, hi.y + (9.6 if index % 3 == 0 else 0.6), (lo.z + hi.z) * 0.5)
	beacon.add_to_group("neon_blink", true)
	parent.add_child(beacon)


var _beacon_cache: Mesh


func _beacon_mesh() -> Mesh:
	if _beacon_cache:
		return _beacon_cache
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = _mat("beacon_red", Color(1.0, 0.1, 0.15), 0.4, Color(1.0, 0.1, 0.15), 4.0)
	_beacon_cache = sphere
	return sphere


## Giant floating holographic adverts over the city.
func _holograms(parent: Node3D) -> void:
	_prop(parent, "neon_holo_koi", "HoloKoi", Vector3(-26.0, 16.0, -52.0), 30.0, Vector3(8, 4, 3)).scale = Vector3.ONE * 2.2
	_prop(parent, "neon_holo_can", "HoloCan", Vector3(48.0, 8.0, 18.0), -60.0, Vector3(3, 7, 3)).scale = Vector3.ONE * 1.8


# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(3.0, 0.1, 12.5)
	start.rotation.y = deg_to_rad(12.0)       # facing the station
	start.add_to_group("player_spawn", true)
	level.add_child(start)

	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	var points := {
		"SpawnFreightElevator": [Vector3(-9.5, N_Y + 0.1, -27.6), 180.0],
		"SpawnRoofDoor": [Vector3(-14.2, 0.1, -8.0), 90.0],
		"SpawnFireEscapeWest": [Vector3(-21.3, FE_LOW_W + 0.1, 11.0), 0.0],
		"SpawnFireEscapeEast": [Vector3(22.8, 0.1, 11.0), 180.0],
		"SpawnServiceHatch": [Vector3(17.5, 0.1, -14.0), -90.0],
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
	# Generous clearance: paths stay clear of wall ends and corners even for
	# the widest zombies, so nobody snags while cutting a corner.
	mesh.agent_radius = 0.8
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 40.0
	mesh.region_min_size = 8.0
	mesh.filter_baking_aabb = AABB(Vector3(-40, FE_LOW_W - 1.0, -45), Vector3(80, L1 + 1.2 - FE_LOW_W, 80))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	region.navigation_mesh = _keep_connected(mesh, [Vector3(3.0, 0.0, 12.5)])
	print("build_neon_skyline: navmesh polygons = %d (of %d before removing islands)" % [region.navigation_mesh.get_polygon_count(), before])
	_check_reachable(region.navigation_mesh)


## Every entrance, landing and the portal must be on the navmesh connected to
## the player's start; prints a warning for any that are not.
func _check_reachable(mesh: NavigationMesh) -> void:
	var probes := {
		"terrace": Vector3(17.0, L1, -1.0), "north landing": Vector3(17.0, 0, -14.5),
		"south landing": Vector3(15.6, 0, 12.4), "bridge": Vector3(-2.0, N_Y * 0.5, -20.0),
		"portal roof": Vector3(4.0, N_Y, -27.0), "west fire escape": Vector3(-21.3, FE_LOW_W, 11.0),
		"east fire escape": Vector3(22.8, 0, 11.0), "east fire escape top": Vector3(22.8, L1, 0.5),
		"freight elevator": Vector3(-9.5, N_Y, -26.6), "roof door": Vector3(-14.2, 0, -8.0),
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
			print("build_neon_skyline: WARNING %s is not connected to the start" % probe_name)
	print("build_neon_skyline: reachability check, %d of %d areas connected" % [probes.size() - bad, probes.size()])


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
## polygon nearest one of `seeds`: prop tops and sealed pockets go away, so
## closest-point queries never snap onto them.
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

func _mat(key: String, color: Color, roughness := 0.7, emission := Color.BLACK, energy := 0.0, metallic := 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	_materials[key] = m
	return m


func _led_material(color: Color) -> StandardMaterial3D:
	var key := "led_%s" % color.to_html(false)
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.resource_name = "NeonLed"
	m.albedo_color = color.darkened(0.6)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.6
	_materials[key] = m
	return m


## The terrace block's walls: a low building front with a row of lit windows.
func _facade_material() -> ShaderMaterial:
	if _materials.has("facade"):
		return _materials["facade"]
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "neon_windows.gdshader")
	m.set_shader_parameter("seed", 7.0)
	m.set_shader_parameter("cell", Vector2(2.6, 3.0))
	m.set_shader_parameter("window", Vector2(0.62, 0.42))
	m.set_shader_parameter("lit_ratio", 0.55)
	m.set_shader_parameter("wall_color", Color(0.16, 0.13, 0.27))
	_materials["facade"] = m
	return m


func _glass_material() -> StandardMaterial3D:
	if _materials.has("glass"):
		return _materials["glass"]
	var m := StandardMaterial3D.new()
	m.resource_name = "RailGlass"
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.35, 0.75, 1.0, 0.22)
	m.roughness = 0.08
	m.metallic_specular = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials["glass"] = m
	return m


func _glow_material(key: String, color: Color, strength: float, shape: int) -> ShaderMaterial:
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + "neon_glow.gdshader")
	m.set_shader_parameter("glow_color", color)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("shape", shape)
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


## Convex solid from `points` and polygon `faces` (index lists, any winding:
## each face is turned to point away from the centre). `face_materials`
## picks a material per face from `materials` (empty = all the first one;
## an index past the end leaves that face out, e.g. hidden undersides).
## With `collide`, a StaticBody3D with a convex shape on `layer` holds it.
func _prism(parent: Node3D, prism_name: String, points: PackedVector3Array, faces: Array, materials: Array,
		face_materials: Array, collide := true, layer := 1) -> Node3D:
	var centre := Vector3.ZERO
	for p in points:
		centre += p
	centre /= points.size()
	var tools := {}
	for f in faces.size():
		var mat_index: int = face_materials[f] if f < face_materials.size() else 0
		if mat_index >= materials.size():
			continue
		if not tools.has(mat_index):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[mat_index] = st
		_face(tools[mat_index], points, faces[f], centre)
	var node: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = layer
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var convex := ConvexPolygonShape3D.new()
		convex.points = points
		shape.shape = convex
		body.add_child(shape)
		node = body
	else:
		node = Node3D.new()
	node.name = prism_name
	parent.add_child(node)
	if not tools.is_empty():
		var mesh := ArrayMesh.new()
		var keys := tools.keys()
		keys.sort()
		for k in keys:
			var st: SurfaceTool = tools[k]
			st.generate_tangents()
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, materials[k])
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = mesh
		node.add_child(mi)
	return node


## One polygon, fan-triangulated, wound clockwise as seen from outside.
func _face(st: SurfaceTool, points: PackedVector3Array, idx: Array, centre: Vector3) -> void:
	var a: Vector3 = points[idx[0]]
	var normal := Vector3.ZERO
	for k in range(1, idx.size() - 1):
		normal += (points[idx[k]] - a).cross(points[idx[k + 1]] - a)
	var face_centre := Vector3.ZERO
	for i in idx:
		face_centre += points[i]
	face_centre /= idx.size()
	var outward := normal.dot(face_centre - centre) > 0.0
	var order: Array = idx.duplicate()
	if outward:
		order.reverse()
		normal = -normal
	# After this, normal points inward for clockwise order; flip for shading.
	var n := -normal.normalized()
	var axis := 0 if absf(n.x) >= absf(n.y) and absf(n.x) >= absf(n.z) else (1 if absf(n.y) >= absf(n.z) else 2)
	for k in range(1, order.size() - 1):
		for v in [order[0], order[k], order[k + 1]]:
			var p: Vector3 = points[v]
			var uv := Vector2(p.z, p.y) if axis == 0 else (Vector2(p.x, p.z) if axis == 1 else Vector2(p.x, p.y))
			st.set_normal(n)
			st.set_uv(uv * 0.25)
			st.add_vertex(p)


## Instances art/models/<model>.glb, or a grey stand-in box if it is missing.
func _prop(parent: Node3D, model: String, prop_name: String, pos: Vector3, yaw_degrees: float, placeholder_size: Vector3) -> Node3D:
	var path := MODELS + model + ".glb"
	var node: Node3D
	if ResourceLoader.exists(path):
		node = (load(path) as PackedScene).instantiate()
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(placeholder_size, _mat("placeholder", Color(0.45, 0.42, 0.6), 0.8))
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


## An invisible box (centre, half extents) in group "neon_rain_cover": while the
## camera is inside it the level's camera-following rain fades out.
func _rain_cover(cover_name: String, centre: Vector3, half_extents: Vector3) -> void:
	var cover := Node3D.new()
	cover.name = cover_name
	cover.position = centre
	cover.set_meta("half_extents", half_extents)
	cover.add_to_group("neon_rain_cover", true)
	dressing.add_child(cover)


func _own(node: Node) -> void:
	for child in node.get_children():
		child.owner = level
		if child.scene_file_path == "":
			_own(child)
