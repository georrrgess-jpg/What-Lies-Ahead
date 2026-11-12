extends SceneTree
## Generator for World 3 / Level "Tidal Tunnels" (Abyss Aquarium).
##
## Rebuilds scenes/levels/tidal_tunnels.tscn: an enclosed mega-aquarium after
## hours. Floors, walls, ceilings, the domed rotunda, display tanks (glass,
## water, coral, kelp, fish, sharks, jellies), dressing, lights, spawn markers,
## the loadout station, the exit portal and a baked navigation mesh.
##
##   godot --headless --path . --script res://tools/build_tidal_tunnels.gd
##
## NOTE: running this overwrites hand edits made to tidal_tunnels.tscn.
##
## Layout (metres, top view; -Z = north, the player starts in the south lobby):
##   - Rotunda (r = 12) at the origin around the towering coral-reef tank; the
##     Reef Supply Ring (loadout station) wraps its base. Openings W, E, S; the
##     north arc is a curved window into the shark tank.
##   - West hall: kelp-forest gallery with a 21 m kelp tank along the west wall.
##   - North: shark tank (x +-11.25) with the acrylic walk-through tunnel
##     (z -22.5..-16.5) linking the NW and NE corner halls.
##   - East hall: dark jellyfish room with glowing jelly columns and a jelly wall.
##   - South lobby: gift shop under a mezzanine (ramps at both ends, exit portal
##     on top) and a touch pool.
##   - Zombie entrances (all beyond the loop): filtration room (NW), service
##     elevator (NE), loading bay (E), staff door (W) and the gift-shop stockroom.

const OUT_PATH := "res://scenes/levels/tidal_tunnels.tscn"
const MODELS := "res://art/models/"
const SHADERS := "res://art/shaders/"
const TEX := "res://art/textures/"

const ROT_R := 12.0          # rotunda inner radius
const ROT_WALL := 0.6
const ROT_H := 9.0           # rotunda wall height (dome above)
const CORE := 13.5           # half-size of the square core around the rotunda
const OPEN_HALF := 17.0      # degrees either side of an opening's axis
const HALL_H := 6.5          # west/east halls and corners
const LOBBY_H := 8.0
const X0 := -23.0
const X1 := 23.0
const Z0 := -25.0
const Z1 := 25.0
const TANK_X := 11.25        # shark tank half-width (= tunnel length / 2)
const TUN_Z := -19.5         # tunnel axis
const TUN_HALF := 3.0
const TUN_SPRING := 1.2
const MEZZ_Y := 3.2
const MEZZ_Z := 20.5         # mezzanine front edge
const MEZZ_X := 10.0         # mezzanine half-width (ramps beyond it)
const RAMP_LEN := 8.0
const RAMP_Z0 := 21.5        # ramps run along the south wall, z 21.5..25
const KELP_GLASS_X := -20.2
const KELP_Z0 := -12.0
const KELP_Z1 := 9.0

var level: Node3D
var geo: Node3D          # collidable geometry (navmesh source)
var dressing: Node3D     # non-colliding scenery
var tanks: Node3D
var lights: Node3D
var _materials := {}
var _boxes := {}
var _font: Font
var _caustic_tex: Texture2D
var _rng := RandomNumberGenerator.new()
## Tank contents render on layer 2 so tank-only lights can target them.
const TANK_LAYER := 2


func _initialize() -> void:
	_rng.seed = 1977
	_font = load("res://art/fonts/LilitaOne-Regular.ttf")
	_caustic_tex = load(TEX + "aqua_caustics.png")
	level = Node3D.new()
	level.name = "TidalTunnels"
	_build_environment()

	var nav := NavigationRegion3D.new()
	nav.name = "NavigationRegion3D"
	level.add_child(nav)
	geo = _node(nav, "Geometry")
	dressing = _node(level, "Dressing")
	tanks = _node(level, "Tanks")
	lights = _node(level, "Lights")

	_build_floors()
	_build_rotunda()
	_build_core_faces()
	_build_outer_walls()
	_build_ceilings()
	_build_centerpiece()
	_build_shark_tank()
	_build_kelp_gallery()
	_build_jelly_room()
	_build_pocket_tanks()
	_build_lobby()
	_build_entrances()
	_build_signage()
	_build_lights()
	_build_exit()
	_build_markers()
	for t in tanks.get_children():
		_set_layers(t, TANK_LAYER)
	_set_layers(level.get_node("Centerpiece"), TANK_LAYER)

	get_root().add_child(level)
	await process_frame
	_bake_navigation(nav)
	get_root().remove_child(level)

	level.set_script(load("res://scripts/run/level_environment.gd"))
	var director := Node.new()
	director.name = "RunDirector"
	director.set_script(load("res://scripts/run/run_director.gd"))
	level.add_child(director)

	for cached in _scene_cache.values():
		(cached as Node).free()
	_own(level)
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_PATH)
	print("build_tidal_tunnels: saved %s (error %d)" % [OUT_PATH, err])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: indoor, no sun shadows; deep teal ambience and haze.
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.03, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.55, 0.78)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.0
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.2, 0.32)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	# Indoors there is no sun: "Sun" is a soft, shadowless top light standing in
	# for the ceiling fixtures (level_environment.gd expects the name).
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.looking_at(Vector3(0.25, -1.0, 0.35).normalized(), Vector3.FORWARD), Vector3(0, 20, 0))
	sun.light_color = Color(0.62, 0.86, 1.0)
	sun.light_energy = 0.42
	sun.shadow_enabled = false
	level.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.transform = Transform3D(Basis.looking_at(Vector3(-0.4, -0.5, -0.75).normalized(), Vector3.UP), Vector3(0, 20, 0))
	fill.light_color = Color(0.55, 0.45, 1.0)
	fill.light_energy = 0.22
	fill.shadow_enabled = false
	level.add_child(fill)


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

func _caustic_mat(key: String, tint: Color, params := {}) -> ShaderMaterial:
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.resource_name = key
	m.shader = load(SHADERS + "aqua_caustics.gdshader")
	m.set_shader_parameter("caustic_tex", _caustic_tex)
	m.set_shader_parameter("tint", tint)
	for k in params:
		var v = params[k]
		if v is String:
			v = load(TEX + v)
		m.set_shader_parameter(k, v)
	_materials[key] = m
	return m


func _floor_mat() -> ShaderMaterial:
	return _caustic_mat("floor", Color(0.82, 0.86, 0.95), {"albedo_tex": "aqua_floor_tiles.png", "normal_tex": "aqua_floor_tiles_normal.png",
		"normal_strength": 0.7, "uv_scale": 0.25, "roughness": 0.22, "specular": 0.7, "caustic_strength": 0.55, "caustic_scale": 0.14})


func _wall_mat() -> ShaderMaterial:
	return _caustic_mat("wall", Color(1, 1, 1), {"albedo_tex": "aqua_wall_panels.png", "uv_scale": 0.25, "roughness": 0.6,
		"caustic_strength": 0.22, "wall_fade_height": 4.0, "caustic_scale": 0.14})


func _curved_wall_mat() -> ShaderMaterial:
	return _caustic_mat("wall_curved", Color(1, 1, 1), {"albedo_tex": "aqua_wall_panels.png", "uv_scale": 0.25, "roughness": 0.6,
		"caustic_strength": 0.28, "wall_fade_height": 4.0, "caustic_scale": 0.14, "use_mesh_uv": true})


func _curved_plain_mat() -> ShaderMaterial:
	return _caustic_mat("wall_curved_plain", Color(0.09, 0.16, 0.27), {"roughness": 0.7, "caustic_strength": 0.2,
		"wall_fade_height": 7.0, "use_mesh_uv": true})


func _plain_wall_mat() -> ShaderMaterial:
	return _caustic_mat("wall_plain", Color(0.09, 0.16, 0.27), {"roughness": 0.7, "caustic_strength": 0.2, "wall_fade_height": 7.0})


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


func _glow_mat(key: String, color: Color, energy := 2.5) -> StandardMaterial3D:
	return _mat(key, color, 0.4, color, energy)


## Water-behind-glass material. floor/surface: world heights of that tank.
func _water_mat(key: String, floor_y: float, surface_y: float, params := {}) -> ShaderMaterial:
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.resource_name = key
	m.shader = load(SHADERS + "aqua_water_glass.gdshader")
	m.set_shader_parameter("caustic_tex", _caustic_tex)
	m.set_shader_parameter("floor_y", floor_y)
	m.set_shader_parameter("surface_y", surface_y)
	for k in params:
		m.set_shader_parameter(k, params[k])
	_materials[key] = m
	return m


func _shader_mat(key: String, shader: String, params := {}) -> ShaderMaterial:
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.resource_name = key
	m.shader = load(SHADERS + shader)
	for k in params:
		m.set_shader_parameter(k, params[k])
	_materials[key] = m
	return m


func _tank_wall_mat() -> ShaderMaterial:
	return _caustic_mat("tank_wall", Color(0.03, 0.12, 0.22), {"roughness": 0.9, "caustic_strength": 0.45,
		"caustic_color": Color(0.4, 0.95, 1.0), "wall_fade_height": 8.0, "caustic_scale": 0.22, "patchiness": 0.8})


func _sand_mat() -> ShaderMaterial:
	return _caustic_mat("tank_sand", Color(0.9, 0.85, 0.75), {"albedo_tex": "aqua_sand.png", "uv_scale": 0.35, "roughness": 0.9,
		"caustic_strength": 1.0, "caustic_color": Color(0.5, 1.0, 1.0), "caustic_scale": 0.3})


# ---------------------------------------------------------------------------
# Floors (collision slabs per room, so no navmesh islands form under tanks)
# ---------------------------------------------------------------------------

func _build_floors() -> void:
	var floors := _node(geo, "Floors")
	var tiles := _floor_mat()
	# Rotunda: a round slab.
	var body := StaticBody3D.new()
	body.name = "RotundaFloor"
	floors.add_child(body)
	body.position = Vector3(0, -1.0, 0)
	for q in 4:
		var mi := MeshInstance3D.new()
		mi.name = "Sector%d" % q
		mi.mesh = _sector_mesh(ROT_R + 0.35, TAU * q / 4.0, TAU * (q + 1) / 4.0, 1.0)
		mi.material_override = tiles
		body.add_child(mi)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var cs := CylinderShape3D.new()
	cs.radius = ROT_R + 0.35
	cs.height = 2.0
	shape.shape = cs
	body.add_child(shape)
	# Passages through the rotunda openings.
	var w := tan(deg_to_rad(OPEN_HALF)) * ROT_R + 0.3
	_slab(floors, "PassW", -CORE - 0.2, -ROT_R + 0.6, -w, w, tiles)
	_slab(floors, "PassE", ROT_R - 0.6, CORE + 0.2, -w, w, tiles)
	_slab(floors, "PassS", -w, w, ROT_R - 0.6, CORE + 0.2, tiles)
	# Halls.
	_slab(floors, "WestHall", KELP_GLASS_X, -CORE, KELP_Z0, KELP_Z1, tiles)
	_slab(floors, "WestHallN", X0, -CORE, -CORE, KELP_Z0, tiles)
	_slab(floors, "WestHallS", X0, -CORE, KELP_Z1, CORE, tiles)
	_slab(floors, "NWCorner", X0, -TANK_X, Z0, -CORE, tiles)
	_slab(floors, "Tunnel", -TANK_X, TANK_X, TUN_Z - TUN_HALF, TUN_Z + TUN_HALF, _caustic_mat("tunnel_floor", Color(0.75, 0.85, 1.0),
		{"albedo_tex": "aqua_floor_tiles.png", "normal_tex": "aqua_floor_tiles_normal.png", "normal_strength": 0.7, "uv_scale": 0.5,
		"roughness": 0.15, "specular": 0.8, "caustic_strength": 1.0, "caustic_scale": 0.22}))
	_slab(floors, "NECorner", TANK_X, X1, Z0, -CORE, tiles)
	_slab(floors, "EastHall", CORE, X1, -CORE, CORE, _caustic_mat("jelly_floor", Color(0.7, 0.62, 0.95),
		{"albedo_tex": "aqua_floor_tiles.png", "normal_tex": "aqua_floor_tiles_normal.png", "normal_strength": 0.7, "uv_scale": 0.25,
		"roughness": 0.18, "specular": 0.75, "caustic_strength": 0.5, "caustic_color": Color(0.8, 0.45, 1.0)}))
	_slab(floors, "Lobby", X0, X1, CORE, Z1, _caustic_mat("carpet", Color(1, 1, 1), {"albedo_tex": "aqua_carpet.png",
		"uv_scale": 0.5, "roughness": 0.95, "specular": 0.2, "caustic_strength": 0.45}))


## Floor slab; thick by default so nothing shoved by physics can drop through.
func _slab(parent: Node3D, slab_name: String, x0: float, x1: float, z0: float, z1: float, material: Material, top := 0.0, thick := 2.0) -> StaticBody3D:
	return _box(parent, slab_name, Vector3(x1 - x0, thick, z1 - z0), Vector3((x0 + x1) * 0.5, top - thick * 0.5, (z0 + z1) * 0.5), material)


# ---------------------------------------------------------------------------
# Rotunda: curved wall with three openings and the shark window, dome above
# ---------------------------------------------------------------------------

## Angles (degrees, x = cos, z = sin) of solid wall arcs; gaps are the openings
## (E 0, S 90, W 180) and the north window (237..303).
func _wall_arcs() -> Array:
	var h := OPEN_HALF
	return [[h, 90.0 - h], [90.0 + h, 180.0 - h], [180.0 + h, 237.0], [303.0, 360.0 - h]]


func _build_rotunda() -> void:
	var rot := _node(geo, "Rotunda")
	var lower := _curved_wall_mat()
	var upper := _curved_plain_mat()
	for arc in _wall_arcs():
		var a0: float = deg_to_rad(arc[0])
		var a1: float = deg_to_rad(arc[1])
		_lower_wall(rot, "Wall%d" % int(arc[0]), a0, a1, lower)
		_arc_wall(rot, "WallUp%d" % int(arc[0]), ROT_R, a0, a1, 4.6, ROT_H, upper)
		_arc_colliders(rot, "WallCol%d" % int(arc[0]), ROT_R + ROT_WALL * 0.5, a0, a1, ROT_H, ROT_WALL)
	# Over the openings and the window: lintels, and a soffit over each passage.
	for centre in [0.0, 90.0, 180.0]:
		var a0 := deg_to_rad(centre - OPEN_HALF)
		var a1 := deg_to_rad(centre + OPEN_HALF)
		_arc_wall(rot, "Lintel%d" % int(centre), ROT_R, a0, a1, 4.6, ROT_H, upper)
		var ac := deg_to_rad(centre)
		var soffit := _mesh_box(dressing, "Soffit%d" % int(centre), Vector3(2.0, 0.3, 2.0 * tan(deg_to_rad(OPEN_HALF)) * ROT_R + 1.0),
			Vector3(cos(ac), 0, sin(ac)) * (ROT_R + 0.9) + Vector3(0, 4.75, 0), _mat("navy_light", Color(0.11, 0.23, 0.39), 0.5))
		soffit.rotation.y = -ac
	var wa0 := deg_to_rad(237.0)
	var wa1 := deg_to_rad(303.0)
	_arc_wall(rot, "WindowHead", ROT_R, wa0, wa1, 6.6, ROT_H, upper)
	_arc_wall(rot, "WindowSill", ROT_R, wa0, wa1, 0.0, 0.7, _mat("navy", Color(0.08, 0.14, 0.27), 0.5))
	_arc_colliders(rot, "WindowCol", ROT_R + 0.1, wa0, wa1, ROT_H, 0.4)
	# Window glass (shark tank behind).
	var glass := MeshInstance3D.new()
	glass.name = "SharkWindow"
	glass.mesh = _arc_mesh(ROT_R + 0.05, wa0, wa1, 0.7, 6.6, true)
	glass.material_override = _water_mat("water_shark", 0.0, 6.5, {"density": 0.13, "max_distance": 30.0})
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tanks.add_child(glass)
	# Brass mullions and frame on the window.
	var brass := _mat("brass", Color(0.84, 0.64, 0.27), 0.35)
	brass.metallic = 0.6
	for i in 7:
		var a := lerpf(wa0, wa1, i / 6.0)
		var p := Vector3(cos(a), 0, sin(a)) * (ROT_R - 0.02)
		var m := _mesh_box(dressing, "Mullion%d" % i, Vector3(0.18, 5.9, 0.18), p + Vector3(0, 3.65, 0), brass)
		m.rotation.y = -a
	for y in [0.7, 6.6]:
		var band := MeshInstance3D.new()
		band.name = "WindowFrame%d" % int(y)
		band.mesh = _arc_band_mesh(ROT_R - 0.04, wa0, wa1, y - 0.08, y + 0.08, 0.16)
		band.material_override = brass
		dressing.add_child(band)
	# Cornice with an LED strip at the top of the wall, and a low LED skirting.
	_ring_band(dressing, "Cornice", ROT_R - 0.15, ROT_H - 0.35, ROT_H, 0.3, _mat("navy_light", Color(0.11, 0.23, 0.39), 0.5))
	_ring_band(dressing, "CorniceLed", ROT_R - 0.32, ROT_H - 0.42, ROT_H - 0.36, 0.05, _glow_mat("led_cyan", Color(0.25, 0.95, 1.0), 2.8))
	_ring_band(dressing, "MidLed", ROT_R - 0.02, 4.55, 4.65, 0.06, _glow_mat("led_cyan", Color(0.25, 0.95, 1.0), 2.8))
	# Dome.
	var dome := MeshInstance3D.new()
	dome.name = "Dome"
	dome.mesh = _dome_mesh(ROT_R + 0.3, 0.52)
	dome.position.y = ROT_H
	dome.material_override = _shader_mat("dome", "aqua_dome.gdshader", {"caustic_tex": _caustic_tex, "squash": 0.52})
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(dome)
	# Pillars at the opening jambs.
	for centre in [0.0, 90.0, 180.0]:
		for s in [-1.0, 1.0]:
			var a := deg_to_rad(centre + s * (OPEN_HALF + 2.5))
			var p := Vector3(cos(a), 0, sin(a)) * (ROT_R + 0.55)
			var pillar := _prop(geo, "aqua_pillar", "Pillar%d%s" % [int(centre), "A" if s < 0 else "B"], p, 0.0, Vector3(1.5, 9, 1.5))
			pillar.rotation.y = -a
			var c := _collider(geo, "PillarCol%d%s" % [int(centre), "A" if s < 0 else "B"], Vector3(1.6, 9.0, 1.8), p + Vector3(0, 4.5, 0))
			c.rotation.y = -a
	# Floor inlay rings around the station (scenery).
	var inlay := _node(dressing, "FloorInlay")
	_flat_ring(inlay, "RingOuter", 10.6, 10.85, _glow_mat("inlay_cyan", Color(0.2, 0.85, 1.0), 1.2))
	_flat_ring(inlay, "RingMid", 7.3, 7.45, _mat("inlay_brass", Color(0.84, 0.64, 0.27), 0.4))
	_flat_ring(inlay, "RingBand", 7.45, 10.6, _mat("inlay_navy", Color(0.08, 0.15, 0.3), 0.3), 0.004)
	var star := _star_mesh()
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		var s := MeshInstance3D.new()
		s.name = "InlayStar%d" % i
		s.mesh = star
		s.material_override = _glow_mat("inlay_star_%d" % (i % 2), Color(1.0, 0.75, 0.3) if i % 2 == 0 else Color(1.0, 0.4, 0.75), 0.9)
		s.position = Vector3(cos(a), 0, sin(a)) * 9.0 + Vector3(0, 0.014, 0)
		s.rotation.y = -a
		s.scale = Vector3.ONE * 1.3
		inlay.add_child(s)


## Solid square faces of the core, seen from the halls (with the openings cut out).
func _build_core_faces() -> void:
	var core := _node(geo, "CoreFaces")
	var wall := _wall_mat()
	var w := tan(deg_to_rad(OPEN_HALF)) * ROT_R + 1.5
	# West and east faces (x = -+CORE), openings at z -w..w.
	for s in [-1.0, 1.0]:
		var x: float = s * (CORE + 0.25)
		_wall_box(core, "Face%sN" % ("W" if s < 0 else "E"), Vector3(0.5, HALL_H, CORE - w), Vector3(x, HALL_H * 0.5, -(CORE + w) * 0.5), wall)
		_wall_box(core, "Face%sS" % ("W" if s < 0 else "E"), Vector3(0.5, HALL_H, CORE - w), Vector3(x, HALL_H * 0.5, (CORE + w) * 0.5), wall)
		_wall_box(core, "Face%sTop" % ("W" if s < 0 else "E"), Vector3(0.5, HALL_H - 4.6, 2.0 * w), Vector3(x, (HALL_H + 4.6) * 0.5, 0), wall)
		# North stub between the core corner and the shark tank.
		_wall_box(core, "FaceN%s" % ("W" if s < 0 else "E"), Vector3(CORE - TANK_X, HALL_H, 0.5), Vector3(s * (CORE + TANK_X) * 0.5, HALL_H * 0.5, -CORE - 0.25), wall)
	# South face (z = CORE), opening at x -w..w; lobby side is taller.
	for s in [-1.0, 1.0]:
		_wall_box(core, "FaceS%s" % ("W" if s < 0 else "E"), Vector3(CORE - w, LOBBY_H, 0.5), Vector3(s * (CORE + w) * 0.5, LOBBY_H * 0.5, CORE + 0.25), wall)
	_wall_box(core, "FaceSTop", Vector3(2.0 * w, LOBBY_H - 4.6, 0.5), Vector3(0, (LOBBY_H + 4.6) * 0.5, CORE + 0.25), wall)


func _build_outer_walls() -> void:
	var walls := _node(geo, "OuterWalls")
	var wall := _wall_mat()
	# North wall: NW corner (filtration door at x -18.5..-15.5) and NE corner (elevator at 15.8..18.2).
	_wall_seg(walls, "NorthW1", Vector2(X0, Z0), Vector2(-18.6, Z0), HALL_H, wall)
	_wall_seg(walls, "NorthW2", Vector2(-15.4, Z0), Vector2(-TANK_X, Z0), HALL_H, wall)
	_wall_seg(walls, "NorthE1", Vector2(TANK_X, Z0), Vector2(15.6, Z0), HALL_H, wall)
	_wall_seg(walls, "NorthE2", Vector2(18.4, Z0), Vector2(X1, Z0), HALL_H, wall)
	# Door heads above the openings.
	_wall_box(walls, "FiltHead", Vector3(3.2, HALL_H - 3.2, 0.5), Vector3(-17.0, (HALL_H + 3.2) * 0.5, Z0 - 0.25), wall)
	_wall_box(walls, "ElevHead", Vector3(2.8, HALL_H - 3.0, 0.5), Vector3(17.0, (HALL_H + 3.0) * 0.5, Z0 - 0.25), wall)
	# West wall: staff door at z 10.4..12.6; the kelp tank covers z -12..9.
	_wall_seg(walls, "WestN", Vector2(X0, Z0), Vector2(X0, KELP_Z0), HALL_H, wall)
	_wall_seg(walls, "WestMid", Vector2(X0, KELP_Z1), Vector2(X0, 10.3), HALL_H, wall)
	_wall_seg(walls, "WestS", Vector2(X0, 12.7), Vector2(X0, Z1), LOBBY_H, wall)
	_wall_box(walls, "StaffHead", Vector3(0.5, HALL_H - 3.0, 2.4), Vector3(X0 - 0.25, (HALL_H + 3.0) * 0.5, 11.5), wall)
	# East wall: jelly wall tank at z -11..-1 (glass), loading bay at z 4.7..9.3.
	_wall_seg(walls, "EastN", Vector2(X1, Z0), Vector2(X1, -11.0), HALL_H, wall)
	_wall_seg(walls, "EastMid", Vector2(X1, -1.0), Vector2(X1, 4.6), HALL_H, wall)
	_wall_seg(walls, "EastS", Vector2(X1, 9.4), Vector2(X1, Z1), LOBBY_H, wall)
	_wall_box(walls, "LoadHead", Vector3(0.5, HALL_H - 3.9, 5.0), Vector3(X1 + 0.25, (HALL_H + 3.9) * 0.5, 7.0), wall)
	# South wall.
	_wall_seg(walls, "South", Vector2(X0, Z1), Vector2(X1, Z1), LOBBY_H, wall)
	# Lobby / hall transitions: the halls are lower; a header beam over each.
	_wall_box(walls, "HeaderW", Vector3(X0 * -1.0 - CORE, LOBBY_H - HALL_H, 0.5), Vector3((X0 - CORE) * 0.5, (LOBBY_H + HALL_H) * 0.5, CORE), _plain_wall_mat())
	_wall_box(walls, "HeaderE", Vector3(X1 - CORE, LOBBY_H - HALL_H, 0.5), Vector3((X1 + CORE) * 0.5, (LOBBY_H + HALL_H) * 0.5, CORE), _plain_wall_mat())


func _build_ceilings() -> void:
	var ceil := _node(dressing, "Ceilings")
	var m := _mat("ceiling", Color(0.07, 0.11, 0.2), 0.85)
	# Coffer beams under the lobby ceiling so it reads as a structure, not a void.
	var beam := _mat("beam", Color(0.1, 0.17, 0.3), 0.6)
	for bx in range(-20, 21, 5):
		_mesh_box(ceil, "LobbyBeamX%d" % bx, Vector3(0.35, 0.5, Z1 - CORE), Vector3(bx, LOBBY_H - 0.25, (CORE + Z1) * 0.5), beam)
	for bz in [16.5, 20.5]:
		_mesh_box(ceil, "LobbyBeamZ%d" % int(bz), Vector3(X1 - X0, 0.5, 0.35), Vector3(0, LOBBY_H - 0.25, bz), beam)
	for bz in range(-12, 13, 6):
		_mesh_box(ceil, "WestBeam%d" % bz, Vector3(-CORE - X0, 0.4, 0.3), Vector3((X0 - CORE) * 0.5, HALL_H - 0.2, bz), beam)
		_mesh_box(ceil, "EastBeam%d" % bz, Vector3(X1 - CORE, 0.4, 0.3), Vector3((X1 + CORE) * 0.5, HALL_H - 0.2, bz), beam)
	_ceiling(ceil, "WestHall", X0, -CORE, -CORE, CORE, HALL_H, m)
	_ceiling(ceil, "EastHall", CORE, X1, -CORE, CORE, HALL_H, m)
	_ceiling(ceil, "NWCorner", X0, -TANK_X, Z0, -CORE, HALL_H, m)
	_ceiling(ceil, "NECorner", TANK_X, X1, Z0, -CORE, HALL_H, m)
	_ceiling(ceil, "Lobby", X0, X1, CORE, Z1, LOBBY_H, m)
	_ceiling(ceil, "TankLid", -TANK_X, TANK_X, Z0, -CORE, 7.0, m)
	# Light coves: glowing strips along the hall ceilings.
	var led := _glow_mat("ceiling_led", Color(0.3, 0.9, 1.0), 2.2)
	var violet := _glow_mat("ceiling_led_violet", Color(0.75, 0.4, 1.0), 2.2)
	for z in [-9.0, -3.0, 3.0, 9.0]:
		_mesh_box(ceil, "WestStrip%d" % int(z), Vector3(5.5, 0.05, 0.18), Vector3(-17.5, HALL_H - 0.03, z), led)
		_mesh_box(ceil, "EastStrip%d" % int(z), Vector3(5.5, 0.05, 0.18), Vector3(18.0, HALL_H - 0.03, z), violet)
	for x in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		_mesh_box(ceil, "LobbyStrip%d" % int(x), Vector3(0.18, 0.05, 5.5), Vector3(x, LOBBY_H - 0.03, 17.0), led)
	# Ducts along the hall ceilings.
	for i in 6:
		_prop(ceil, "aqua_duct", "DuctW%d" % i, Vector3(-14.8, HALL_H - 0.9, -24.0 + i * 4.0), -90.0, Vector3(4, 0.8, 0.8))
		_prop(ceil, "aqua_duct", "DuctE%d" % i, Vector3(21.6, HALL_H - 1.0, -24.0 + i * 4.0), -90.0, Vector3(4, 0.8, 0.8))


func _ceiling(parent: Node3D, cname: String, x0: float, x1: float, z0: float, z1: float, y: float, m: Material) -> void:
	_mesh_box(parent, cname, Vector3(x1 - x0, 0.4, z1 - z0), Vector3((x0 + x1) * 0.5, y + 0.2, (z0 + z1) * 0.5), m)


# ---------------------------------------------------------------------------
# Centerpiece: the coral-reef tank (the station wraps its base)
# ---------------------------------------------------------------------------

func _build_centerpiece() -> void:
	var centre := _node(level, "Centerpiece")
	_prop(centre, "aqua_reef_column", "ReefColumn", Vector3.ZERO, 0.0, Vector3(7, 10, 7))
	_bubbles(centre, "ReefBubblesA", Vector3(1.6, 1.4, 1.2), 7.2)
	_bubbles(centre, "ReefBubblesB", Vector3(-1.9, 1.4, -0.8), 7.2)
	var glass := MeshInstance3D.new()
	glass.name = "ReefGlass"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.2
	cyl.bottom_radius = 3.2
	cyl.height = 7.7
	cyl.radial_segments = 48
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	glass.mesh = cyl
	glass.position.y = 1.3 + 3.85
	glass.material_override = _water_mat("water_reef", 1.3, 8.7, {"density": 0.075, "max_distance": 7.0,
		"shallow_color": Color(0.06, 0.48, 0.6), "ray_strength": 0.7, "caustic_strength": 0.9})
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	centre.add_child(glass)
	# Fish orbiting the spire.
	_school(centre, "ReefClowns", "FishClown", 14, Vector3(0, 2.6, 0), Vector2(2.2, 2.2), Vector2(0.35, 0.5), 0.15, 2.0, 0.6)
	_school(centre, "ReefTangs", "FishTang", 10, Vector3(0, 4.6, 0), Vector2(2.5, 2.5), Vector2(-0.42, -0.3), 0.2, 1.4, 0.8)
	_school(centre, "ReefAngels", "FishAngel", 6, Vector3(0, 6.2, 0), Vector2(2.1, 2.1), Vector2(0.25, 0.35), 0.2, 1.2, 1.0)
	_school(centre, "ReefPuffers", "FishPuffer", 3, Vector3(0, 3.6, 0), Vector2(2.6, 2.6), Vector2(-0.2, -0.15), 0.3, 0.5, 1.2)
	_school(centre, "ReefSardines", "FishSardine", 40, Vector3(0, 7.4, 0), Vector2(2.4, 2.4), Vector2(0.7, 0.7), 0.25, 1.5, 0.35)
	# Light shaft from the dome crown into the tank.
	_light_shaft(centre, "CrownShaft", Vector3(0, 15.0, 0), 5.0, 6.0, Color(0.35, 0.9, 1.0), 0.28)
	var station: Node3D = (load("res://scenes/props/aqua_station.tscn") as PackedScene).instantiate()
	station.name = "AquaStation"
	geo.add_child(station)


# ---------------------------------------------------------------------------
# Shark tank and the walk-through tunnel
# ---------------------------------------------------------------------------

func _build_shark_tank() -> void:
	var tank := _node(tanks, "SharkTank")
	var wall := _tank_wall_mat()
	# Interior shell: back wall, side walls, sand floor, the window bay.
	_mesh_box(tank, "BackWall", Vector3(2.0 * TANK_X, 7.0, 0.4), Vector3(0, 3.5, Z0 - 0.2), wall)
	for s in [-1.0, 1.0]:
		_mesh_box(tank, "SideN%d" % int(s), Vector3(0.4, 7.0, (Z0 + 22.5 - 0.0) * -1.0), Vector3(s * (TANK_X + 0.2), 3.5, (Z0 + TUN_Z - TUN_HALF) * 0.5), wall)
		_mesh_box(tank, "SideS%d" % int(s), Vector3(0.4, 7.0, -CORE - (TUN_Z + TUN_HALF)), Vector3(s * (TANK_X + 0.2), 3.5, (-CORE + TUN_Z + TUN_HALF) * 0.5), wall)
		_mesh_box(tank, "SideTop%d" % int(s), Vector3(0.4, 7.0 - 4.4, 2.0 * TUN_HALF), Vector3(s * (TANK_X + 0.2), (7.0 + 4.4) * 0.5, TUN_Z), wall)
		# The bay's side walls, from the core face down to the window.
		_mesh_box(tank, "Bay%d" % int(s), Vector3(TANK_X - 6.4, 7.0, 0.4), Vector3(s * (TANK_X + 6.4) * 0.5, 3.5, -CORE + 0.2), wall)
	var zn := TUN_Z - TUN_HALF - 0.45
	var zs := TUN_Z + TUN_HALF + 0.45
	_mesh_box(tank, "SandN", Vector3(2.0 * TANK_X, 0.3, zn - Z0), Vector3(0, 0.05, (Z0 + zn) * 0.5), _sand_mat())
	_mesh_box(tank, "SandS", Vector3(2.0 * TANK_X, 0.3, -9.5 - zs), Vector3(0, 0.05, (zs - 9.5) * 0.5), _sand_mat())
	for s in [-1.0, 1.0]:
		_mesh_box(tank, "BayEdge%d" % int(s), Vector3(0.4, 7.0, 4.0), Vector3(s * 6.75, 3.5, -11.6), wall)
	var surface := _mesh_box(tank, "Surface", Vector3(2.0 * TANK_X, 0.1, -Z0 - 9.0), Vector3(0, 6.6, (Z0 - 9.0) * 0.5),
		_caustic_mat("water_surface", Color(0.1, 0.55, 0.7), {"caustic_strength": 2.2, "caustic_color": Color(0.6, 1.0, 1.0), "caustic_scale": 0.25, "roughness": 0.1}))
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Tunnel: ribs, mouths, glass, collision.
	var ribs := _node(geo, "Tunnel")
	var x := -TANK_X
	var i := 0
	while x <= TANK_X + 0.01:
		_prop(ribs, "aqua_tunnel_rib", "Rib%02d" % i, Vector3(x, 0, TUN_Z), 0.0, Vector3(0.3, 4.2, 6.4))
		x += 2.5
		i += 1
	for s in [-1.0, 1.0]:
		var mouth := _prop(ribs, "aqua_tunnel_mouth", "Mouth%s" % ("W" if s < 0 else "E"), Vector3(s * (TANK_X + 0.35), 0, TUN_Z), s * 90.0, Vector3(1, 5, 8))
		mouth.name = "Mouth%s" % ("W" if s < 0 else "E")
	for s in [-1.0, 1.0]:
		var z: float = TUN_Z + s * (TUN_HALF + 0.2)
		_collider(ribs, "TunnelWall%s" % ("N" if s < 0 else "S"), Vector3(2.0 * TANK_X + 1.0, 4.4, 0.4), Vector3(0, 2.2, z))
		# The tank's end walls either side of the tunnel mouths.
		for e in [-1.0, 1.0]:
			var zc: float = (Z0 + TUN_Z - TUN_HALF) * 0.5 if s < 0 else (-CORE + TUN_Z + TUN_HALF) * 0.5
			var depth: float = absf(Z0 - (TUN_Z - TUN_HALF)) if s < 0 else absf(-CORE - (TUN_Z + TUN_HALF))
			_collider(ribs, "TankEnd%s%s" % ["N" if s < 0 else "S", "W" if e < 0 else "E"], Vector3(0.5, HALL_H, depth), Vector3(e * (TANK_X + 0.25), HALL_H * 0.5, zc))
	var glass := MeshInstance3D.new()
	glass.name = "TunnelGlass"
	glass.mesh = _tunnel_glass_mesh(-TANK_X, TANK_X, TUN_HALF + 0.02)
	glass.position.z = TUN_Z
	glass.material_override = _water_mat("water_tunnel", 0.0, 6.5, {"density": 0.15, "max_distance": 26.0, "ray_strength": 0.8})
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tank.add_child(glass)
	# Reef dressing on the tank floor (both sides of the tunnel), kelp along the back.
	var spots := [Vector3(-8.5, 0, -24.0), Vector3(-3.0, 0, -24.2), Vector3(4.5, 0, -24.0), Vector3(9.0, 0, -23.8),
		Vector3(-9.0, 0, -15.0), Vector3(-4.5, 0, -14.6), Vector3(5.0, 0, -14.8), Vector3(9.2, 0, -15.2)]
	var reefs := ["aqua_reef_a", "aqua_reef_b", "aqua_rocks"]
	for k in spots.size():
		var r := _prop(tank, reefs[k % 3], "Reef%d" % k, spots[k] + Vector3(0, 0.15, 0), k * 47.0, Vector3(1.5, 1, 1.5))
		r.scale = Vector3.ONE * (1.2 + 0.25 * (k % 2))
	_kelp(tank, "TankKelp", 16, Vector3(-10.0, 0.2, -24.4), Vector3(10.0, 0.2, -23.6), 0.8, 1.05, Color(0.3, 0.55, 0.22))
	_bubbles(tank, "SharkBubblesA", Vector3(-6.0, 0.3, -24.3), 6.0)
	_bubbles(tank, "SharkBubblesB", Vector3(7.5, 0.3, -24.3), 6.0)
	_bubbles(tank, "SharkBubblesC", Vector3(3.0, 0.3, -12.5), 6.0)
	# Sharks circle the tunnel, rising over it at the ends of their loop.
	_school(tank, "Sharks", "Shark", 3, Vector3(0, 2.3, TUN_Z), Vector2(8.3, 4.5), Vector2(0.16, 0.2), 0.0, 0.25, 0.3,
		{"wiggle": 0.12, "wiggle_freq": 2.2, "body_length": 2.6, "lift": 3.1, "bob": 0.15}, true)
	_school(tank, "Rays", "Ray", 2, Vector3(0, 5.6, TUN_Z), Vector2(6.0, 2.2), Vector2(-0.12, -0.1), 0.0, 0.2, 0.2,
		{"wiggle": 0.0, "flap": 0.35, "body_length": 1.4}, true)
	_school(tank, "BaySardines", "FishSardine", 50, Vector3(0, 2.8, -14.7), Vector2(5.5, 0.7), Vector2(0.55, 0.55), 0.25, 0.8, 0.3)
	_school(tank, "BackSnappers", "FishSnapper", 8, Vector3(0, 2.0, -24.0), Vector2(8.5, 0.5), Vector2(-0.18, -0.12), 0.3, 1.0, 0.8)
	_school(tank, "TopTangs", "FishTang", 10, Vector3(0, 5.4, TUN_Z), Vector2(7.5, 2.0), Vector2(0.3, 0.4), 0.3, 1.2, 0.5)


## Arch-shaped glass for the tunnel, from x0 to x1, centred on z = 0.
func _tunnel_glass_mesh(x0: float, x1: float, r: float) -> ArrayMesh:
	var profile: Array[Vector2] = []    # (z, y)
	profile.append(Vector2(-r, 0.35))
	profile.append(Vector2(-r, TUN_SPRING))
	var steps := 20
	for k in range(1, steps):
		var a := PI * k / steps
		profile.append(Vector2(-cos(a) * r, TUN_SPRING + sin(a) * r))
	profile.append(Vector2(r, TUN_SPRING))
	profile.append(Vector2(r, 0.35))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in profile.size() - 1:
		var p0 := profile[k]
		var p1 := profile[k + 1]
		var n0 := Vector3(0, p0.y - TUN_SPRING, p0.x).normalized() if p0.y > TUN_SPRING else Vector3(0, 0, signf(p0.x))
		var quad := [Vector3(x0, p0.y, p0.x), Vector3(x1, p0.y, p0.x), Vector3(x1, p1.y, p1.x), Vector3(x0, p1.y, p1.x)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(-n0)
			st.add_vertex(quad[idx])
	return st.commit()


# ---------------------------------------------------------------------------
# Kelp forest gallery (west)
# ---------------------------------------------------------------------------

func _build_kelp_gallery() -> void:
	var tank := _node(tanks, "KelpTank")
	var wall := _tank_wall_mat()
	var len_z := KELP_Z1 - KELP_Z0
	var zc := (KELP_Z0 + KELP_Z1) * 0.5
	_mesh_box(tank, "Back", Vector3(0.4, HALL_H, len_z), Vector3(X0 - 0.2, HALL_H * 0.5, zc), wall)
	_mesh_box(tank, "EndN", Vector3(X0 * -1.0 + KELP_GLASS_X, HALL_H, 0.4), Vector3((X0 + KELP_GLASS_X) * 0.5, HALL_H * 0.5, KELP_Z0 - 0.2), wall)
	_mesh_box(tank, "EndS", Vector3(X0 * -1.0 + KELP_GLASS_X, HALL_H, 0.4), Vector3((X0 + KELP_GLASS_X) * 0.5, HALL_H * 0.5, KELP_Z1 + 0.2), wall)
	_mesh_box(tank, "Sand", Vector3(KELP_GLASS_X - X0, 0.5, len_z), Vector3((X0 + KELP_GLASS_X) * 0.5, 0.25, zc), _sand_mat())
	var glass := MeshInstance3D.new()
	glass.name = "KelpGlass"
	var quad := QuadMesh.new()
	quad.size = Vector2(len_z, HALL_H - 0.7 - 0.5)
	glass.mesh = quad
	glass.position = Vector3(KELP_GLASS_X, 0.7 + (HALL_H - 1.2) * 0.5, zc)
	glass.rotation.y = PI * 0.5
	glass.material_override = _water_mat("water_kelp", 0.5, HALL_H, {"density": 0.16, "max_distance": 14.0,
		"shallow_color": Color(0.08, 0.45, 0.42), "deep_color": Color(0.01, 0.1, 0.14), "ray_color": Color(0.6, 1.0, 0.75), "ray_strength": 0.9})
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tank.add_child(glass)
	_collider(geo, "KelpGlassCol", Vector3(0.3, HALL_H, len_z), Vector3(KELP_GLASS_X - 0.15, HALL_H * 0.5, zc))
	# Frame: sill, header and mullions.
	var navy := _mat("navy", Color(0.08, 0.14, 0.27), 0.5)
	_mesh_box(dressing, "KelpSill", Vector3(0.5, 0.7, len_z + 0.4), Vector3(KELP_GLASS_X + 0.15, 0.35, zc), navy)
	_mesh_box(dressing, "KelpHeader", Vector3(0.5, 0.5, len_z + 0.4), Vector3(KELP_GLASS_X + 0.15, HALL_H - 0.25, zc), navy)
	_mesh_box(dressing, "KelpSillLed", Vector3(0.06, 0.05, len_z), Vector3(KELP_GLASS_X + 0.42, 0.62, zc), _glow_mat("led_green", Color(0.4, 1.0, 0.7), 2.2))
	for k in 8:
		var z := KELP_Z0 + len_z * k / 7.0
		_mesh_box(dressing, "KelpMullion%d" % k, Vector3(0.25, HALL_H - 1.2, 0.2), Vector3(KELP_GLASS_X + 0.05, 0.7 + (HALL_H - 1.2) * 0.5, z), navy)
	for z in [-8.0, 0.5, 6.5]:
		_bubbles(tank, "KelpBubbles%d" % int(z), Vector3(-22.4, 0.5, z), 5.5)
	_kelp(tank, "Kelp", 44, Vector3(-22.6, 0.5, KELP_Z0 + 0.6), Vector3(-20.8, 0.5, KELP_Z1 - 0.6), 0.85, 1.15, Color(0.28, 0.55, 0.2))
	for k in 6:
		var r := _prop(tank, ["aqua_rocks", "aqua_reef_a", "aqua_reef_b"][k % 3], "Rocks%d" % k, Vector3(-21.4 + 0.4 * (k % 2), 0.5, KELP_Z0 + 2.0 + k * 3.4), k * 63.0, Vector3(1, 1, 1))
		r.scale = Vector3.ONE * 0.9
	_school(tank, "KelpSardines", "FishSardine", 60, Vector3(-21.5, 3.8, zc), Vector2(0.8, 8.5), Vector2(0.45, 0.45), 0.3, 1.0, 0.35)
	_school(tank, "KelpSnappers", "FishSnapper", 7, Vector3(-21.6, 2.2, zc), Vector2(0.6, 8.0), Vector2(-0.22, -0.15), 0.3, 0.8, 0.8)
	_school(tank, "KelpPuffers", "FishPuffer", 3, Vector3(-21.4, 1.6, zc), Vector2(0.5, 7.0), Vector2(0.12, 0.16), 0.3, 0.4, 1.0)
	_light_shaft(tank, "KelpShaftA", Vector3(-21.6, HALL_H, -6.0), 1.4, HALL_H, Color(0.6, 1.0, 0.7), 0.18)
	_light_shaft(tank, "KelpShaftB", Vector3(-21.6, HALL_H, 3.0), 1.4, HALL_H, Color(0.6, 1.0, 0.7), 0.18)
	# Benches facing the glass.
	for k in 2:
		var z := -9.0 + k * 16.0
		_prop(geo, "aqua_bench", "KelpBench%d" % k, Vector3(-14.3, 0, z), -90.0, Vector3(2.4, 0.6, 0.7))
		_collider(geo, "KelpBenchCol%d" % k, Vector3(0.7, 0.6, 2.4), Vector3(-14.3, 0.3, z))


# ---------------------------------------------------------------------------
# Jellyfish room (east)
# ---------------------------------------------------------------------------

func _build_jelly_room() -> void:
	var room := _node(tanks, "JellyRoom")
	var jelly_glass := _water_mat("water_jelly", 0.7, HALL_H - 0.6, {"density": 0.2, "max_distance": 2.2,
		"deep_color": Color(0.05, 0.02, 0.16), "shallow_color": Color(0.22, 0.08, 0.4), "ray_color": Color(0.85, 0.5, 1.0),
		"ray_strength": 0.35, "caustic_strength": 0.0, "particle_strength": 0.6, "transmit_tint": Color(1.0, 0.85, 1.0)})
	var colours := [Color(1.0, 0.45, 0.85), Color(0.5, 0.75, 1.0), Color(0.75, 0.45, 1.0), Color(1.0, 0.6, 0.4)]
	var k := 0
	for z in [-9.0, -3.0, 3.0, 9.0]:
		var p := Vector3(18.2, 0, z)
		_prop(geo, "aqua_jelly_column", "JellyColumn%d" % k, p, 0.0, Vector3(2.2, HALL_H, 2.2))
		var c := StaticBody3D.new()
		c.name = "JellyColumnCol%d" % k
		geo.add_child(c)
		c.position = p + Vector3(0, HALL_H * 0.5, 0)
		var shape := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = 1.1
		cs.height = HALL_H
		shape.shape = cs
		c.add_child(shape)
		var glass := MeshInstance3D.new()
		glass.name = "JellyGlass%d" % k
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.92
		cyl.bottom_radius = 0.92
		cyl.height = HALL_H - 1.3
		cyl.radial_segments = 32
		cyl.cap_top = false
		cyl.cap_bottom = false
		glass.mesh = cyl
		glass.position = p + Vector3(0, 0.7 + (HALL_H - 1.3) * 0.5, 0)
		glass.material_override = jelly_glass
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		room.add_child(glass)
		# Backdrop core inside the column so the glass has something to fog.
		var core := MeshInstance3D.new()
		core.name = "JellyCore%d" % k
		var cm := CylinderMesh.new()
		cm.top_radius = 0.25
		cm.bottom_radius = 0.25
		cm.height = HALL_H - 1.3
		cm.radial_segments = 12
		core.mesh = cm
		core.material_override = _mat("jelly_core", Color(0.12, 0.04, 0.25), 0.8, Color(0.3, 0.1, 0.5), 0.6)
		core.position = glass.position
		room.add_child(core)
		_jellies(room, "Jellies%d" % k, 6, p + Vector3(0, 3.2, 0), 0.45, 1.6, colours[k % colours.size()])
		k += 1
	# The jelly wall: a recessed tank in the east wall.
	var wall := _caustic_mat("jelly_wall", Color(0.12, 0.05, 0.28), {"caustic_strength": 0.6, "caustic_color": Color(0.7, 0.4, 1.0), "roughness": 0.9})
	var zc := -6.0
	_mesh_box(room, "WallTankBack", Vector3(0.4, HALL_H, 10.0), Vector3(X1 + 2.6, HALL_H * 0.5, zc), wall)
	_mesh_box(room, "WallTankN", Vector3(2.6, HALL_H, 0.4), Vector3(X1 + 1.3, HALL_H * 0.5, -11.2), wall)
	_mesh_box(room, "WallTankS", Vector3(2.6, HALL_H, 0.4), Vector3(X1 + 1.3, HALL_H * 0.5, -0.8), wall)
	_mesh_box(room, "WallTankFloor", Vector3(2.6, 0.6, 10.0), Vector3(X1 + 1.3, 0.3, zc), wall)
	var glass_w := MeshInstance3D.new()
	glass_w.name = "JellyWallGlass"
	var quad := QuadMesh.new()
	quad.size = Vector2(10.0, HALL_H - 1.3)
	glass_w.mesh = quad
	glass_w.position = Vector3(X1, 0.7 + (HALL_H - 1.3) * 0.5, zc)
	glass_w.rotation.y = -PI * 0.5
	glass_w.material_override = _water_mat("water_jelly_wall", 0.6, HALL_H, {"density": 0.28, "max_distance": 4.0,
		"deep_color": Color(0.04, 0.01, 0.12), "shallow_color": Color(0.3, 0.1, 0.5), "ray_color": Color(0.9, 0.55, 1.0),
		"ray_strength": 0.6, "caustic_strength": 0.0, "particle_strength": 0.8, "transmit_tint": Color(1.0, 0.85, 1.0)})
	glass_w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(glass_w)
	_collider(geo, "JellyWallCol", Vector3(0.3, HALL_H, 10.4), Vector3(X1 + 0.15, HALL_H * 0.5, zc))
	var navy := _mat("navy", Color(0.08, 0.14, 0.27), 0.5)
	_mesh_box(dressing, "JellyWallSill", Vector3(0.5, 0.7, 10.4), Vector3(X1 - 0.15, 0.35, zc), navy)
	_mesh_box(dressing, "JellyWallHead", Vector3(0.5, 0.6, 10.4), Vector3(X1 - 0.15, HALL_H - 0.3, zc), navy)
	_mesh_box(dressing, "JellyWallLed", Vector3(0.06, 0.05, 10.0), Vector3(X1 - 0.42, 0.62, zc), _glow_mat("led_violet", Color(0.8, 0.45, 1.0), 2.4))
	_jellies(room, "WallJellies", 22, Vector3(X1 + 1.3, 3.2, zc), 0.6, 2.0, Color(0.95, 0.5, 1.0), Vector3(0.7, 1.6, 4.3))
	# Benches.
	for z in [-10.5, 10.5]:
		_prop(geo, "aqua_bench", "JellyBench%d" % int(z), Vector3(14.3, 0, z), 90.0, Vector3(2.4, 0.6, 0.7))
		_collider(geo, "JellyBenchCol%d" % int(z), Vector3(0.7, 0.6, 2.4), Vector3(14.3, 0.3, z))


# ---------------------------------------------------------------------------
# Small reef tanks in the core corners, seen through portholes
# ---------------------------------------------------------------------------

func _build_pocket_tanks() -> void:
	var holder := _node(tanks, "PocketTanks")
	var wall := _tank_wall_mat()
	var k := 0
	for deg in [45.0, 135.0, 225.0, 315.0]:
		var a := deg_to_rad(deg)
		var dir := Vector3(cos(a), 0, sin(a))
		var centre := dir * (ROT_R + 2.0)
		var t := _node(holder, "Pocket%d" % k)
		t.position = centre
		t.rotation.y = -a + PI * 0.5      # local -Z faces the rotunda centre... local +Z = outward
		# Box interior (inverted cube) 3 m deep x 3.4 wide x 3.6 tall.
		var shell := MeshInstance3D.new()
		shell.name = "Shell"
		var bm := BoxMesh.new()
		bm.size = Vector3(3.4, 3.6, 3.9)
		bm.flip_faces = true
		bm.material = wall
		shell.mesh = bm
		shell.position = Vector3(0, 2.4, -0.05)
		t.add_child(shell)
		var sand := _mesh_box(t, "Sand", Vector3(3.4, 0.2, 3.0), Vector3(0, 0.7, 0.4), _sand_mat())
		sand.name = "Sand"
		var reef := _prop(t, ["aqua_reef_b", "aqua_reef_a"][k % 2], "Reef", Vector3(0, 0.75, 1.0), k * 70.0, Vector3(1, 1, 1))
		reef.scale = Vector3.ONE * 0.9
		_school(t, "Fish", ["FishClown", "FishTang", "FishAngel", "FishPuffer"][k], 6, Vector3(0, 2.4, 0.6), Vector2(1.0, 0.7), Vector2(0.45, 0.6), 0.2, 0.7, 0.8)
		# Porthole glass + frame on the rotunda wall.
		var port := MeshInstance3D.new()
		port.name = "PortGlass"
		var disc := CylinderMesh.new()
		disc.top_radius = 1.08
		disc.bottom_radius = 1.08
		disc.height = 0.02
		disc.radial_segments = 32
		port.mesh = disc
		port.rotation.x = PI * 0.5
		port.position = Vector3(0, 2.4, -1.9)
		port.material_override = _water_mat("water_pocket", 0.7, 4.2, {"density": 0.12, "max_distance": 4.0, "caustic_strength": 1.0})
		port.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.add_child(port)
		var frame := _prop(t, "aqua_porthole", "Frame", Vector3(0, 2.4, -2.02), 180.0, Vector3(2.8, 2.8, 0.3))
		frame.name = "Frame"
		k += 1


# ---------------------------------------------------------------------------
# South lobby: gift shop, mezzanine and ramps, touch pool
# ---------------------------------------------------------------------------

func _build_lobby() -> void:
	var lobby := _node(geo, "Lobby")
	var slab_m := _mat("mezz_slab", Color(0.1, 0.18, 0.32), 0.5)
	var deck := _caustic_mat("mezz_deck", Color(0.85, 0.9, 1.0), {"albedo_tex": "aqua_floor_tiles.png", "uv_scale": 0.5, "roughness": 0.3,
		"caustic_strength": 0.5})
	# Mezzanine deck over the gift shop.
	_slab(lobby, "Mezzanine", -MEZZ_X, MEZZ_X, MEZZ_Z, Z1, deck, MEZZ_Y, 0.35)
	_mesh_box(lobby, "MezzFascia", Vector3(2.0 * MEZZ_X, 0.45, 0.2), Vector3(0, MEZZ_Y - 0.2, MEZZ_Z - 0.05), slab_m)
	_mesh_box(lobby, "MezzLed", Vector3(2.0 * MEZZ_X, 0.05, 0.06), Vector3(0, MEZZ_Y - 0.38, MEZZ_Z - 0.16), _glow_mat("led_cyan", Color(0.25, 0.95, 1.0), 2.8))
	# Ramps: west goes up toward +x, east up toward -x.
	for s in [-1.0, 1.0]:
		var top_x: float = s * MEZZ_X
		var bottom_x: float = s * (MEZZ_X + RAMP_LEN)
		var ramp_w := Z1 - RAMP_Z0
		var slope_len := sqrt(RAMP_LEN * RAMP_LEN + MEZZ_Y * MEZZ_Y)
		var angle := atan2(MEZZ_Y, RAMP_LEN)
		var ramp := _box(lobby, "Ramp%s" % ("W" if s < 0 else "E"), Vector3(slope_len, 0.35, ramp_w), Vector3.ZERO, deck)
		ramp.rotation.z = angle * -s
		var mid := Vector3((top_x + bottom_x) * 0.5, MEZZ_Y * 0.5, (RAMP_Z0 + Z1) * 0.5)
		var normal := Vector3(sin(angle) * s, cos(angle), 0)
		ramp.position = mid - normal * 0.175
		# Skirt under the ramp's open side so nothing walks beneath it.
		var skirt := _box(lobby, "RampSkirt%s" % ("W" if s < 0 else "E"), Vector3(slope_len, 2.6, 0.3), Vector3.ZERO, slab_m)
		skirt.rotation.z = angle * -s
		skirt.position = mid - normal * 1.45 + Vector3(0, 0, RAMP_Z0 - (RAMP_Z0 + Z1) * 0.5 + 0.15)
		# Glass rail along the open side, over a solid side wall, so the ramp can
		# only be entered from its foot (the player cannot step onto its edge).
		var start := Vector3(minf(top_x, bottom_x), MEZZ_Y if s > 0 else 0.0, RAMP_Z0 + 0.1)
		var run := Vector3(RAMP_LEN, -MEZZ_Y if s > 0 else MEZZ_Y, 0.0)
		for k in 3:
			var rail := _prop(dressing, "aqua_glass_rail", "RampRail%s%d" % ["W" if s < 0 else "E", k], start + run * (k / 3.0), 0.0, Vector3(3, 1.1, 0.1))
			rail.rotation.z = atan2(run.y, run.x)
			rail.scale.x = slope_len / 9.0
		var side := _collider(lobby, "RampSide%s" % ("W" if s < 0 else "E"), Vector3(slope_len + 0.4, 1.3, 0.3), mid + normal * 0.5 + Vector3(0, 0, RAMP_Z0 - 0.05 - mid.z))
		side.rotation.z = angle * -s
		var post := StaticBody3D.new()
		post.name = "RampPost%s" % ("W" if s < 0 else "E")
		lobby.add_child(post)
		post.position = Vector3(bottom_x, 0.6, RAMP_Z0 - 0.05)
		var pshape := CollisionShape3D.new()
		var cyl_shape := CylinderShape3D.new()
		cyl_shape.radius = 0.25
		cyl_shape.height = 1.2
		pshape.shape = cyl_shape
		post.add_child(pshape)
		_mesh_box(dressing, "RampPostMesh%s" % ("W" if s < 0 else "E"), Vector3(0.3, 1.2, 0.3), post.position, _mat("chrome", Color(0.79, 0.83, 0.89), 0.25))
		# Solid block under the mezzanine beside the shop (between shop and ramps).
		_box(lobby, "UnderMezz%s" % ("W" if s < 0 else "E"), Vector3(1.5, MEZZ_Y - 0.35, Z1 - MEZZ_Z), Vector3(s * (MEZZ_X - 0.75), (MEZZ_Y - 0.35) * 0.5, (MEZZ_Z + Z1) * 0.5), slab_m)
	# Mezzanine balustrade along the front edge.
	var x := -MEZZ_X
	var n := 0
	while x < MEZZ_X - 0.1:
		_prop(dressing, "aqua_glass_rail", "MezzRail%02d" % n, Vector3(x, MEZZ_Y, MEZZ_Z + 0.12), 0.0, Vector3(3, 1.1, 0.1)).scale.x = 2.0 * MEZZ_X / 7.0 / 3.0
		x += 2.0 * MEZZ_X / 7.0
		n += 1
	_collider(lobby, "MezzRailCol", Vector3(2.0 * MEZZ_X, 1.2, 0.2), Vector3(0, MEZZ_Y + 0.6, MEZZ_Z + 0.12))
	# Gift shop under the mezzanine (front at z = MEZZ_Z, facing north).
	_prop(lobby, "aqua_gift_shop", "GiftShop", Vector3(0, 0, MEZZ_Z), 180.0, Vector3(17, 3.2, 4.4))
	for s in [-1.0, 1.0]:
		_collider(lobby, "ShopFront%s" % ("W" if s < 0 else "E"), Vector3(7.1, MEZZ_Y - 0.35, 0.4), Vector3(s * 4.95, (MEZZ_Y - 0.35) * 0.5, MEZZ_Z))
		_collider(lobby, "ShopShelf%s" % ("W" if s < 0 else "E"), Vector3(5.6, 2.5, 0.7), Vector3(s * 5.0, 1.25, MEZZ_Z + 4.4 - 0.35))
		_collider(lobby, "ShopTable%s" % ("W" if s < 0 else "E"), Vector3(2.2, 0.8, 1.0), Vector3(s * 4.6, 0.4, MEZZ_Z + 1.6))
	_collider(lobby, "ShopCounter", Vector3(1.8, 1.0, 0.7), Vector3(2.8, 0.5, MEZZ_Z + 2.6))
	_collider(lobby, "ShopBack", Vector3(17.0, MEZZ_Y, 0.3), Vector3(0, MEZZ_Y * 0.5, Z1 - 0.1))
	# Touch pool at the west end of the lobby (long axis north-south).
	_prop(lobby, "aqua_touch_pool", "TouchPool", Vector3(-19.0, 0, 18.0), 90.0, Vector3(6.4, 0.8, 3.8))
	# Stadium-shaped collision (a box plus two round ends; shapes are never scaled).
	_collider(lobby, "TouchPoolCol", Vector3(3.9, 0.8, 3.2), Vector3(-19.0, 0.4, 18.0))
	for e in [-1.0, 1.0]:
		var end := StaticBody3D.new()
		end.name = "TouchPoolEnd%s" % ("N" if e < 0 else "S")
		lobby.add_child(end)
		end.position = Vector3(-19.0, 0.4, 18.0 + e * 1.6)
		var es := CollisionShape3D.new()
		var ec := CylinderShape3D.new()
		ec.radius = 1.95
		ec.height = 0.8
		es.shape = ec
		end.add_child(es)
	var water := level.find_child("TouchWater", true, false)
	if water is MeshInstance3D:
		(water as MeshInstance3D).material_override = _water_mat("water_touch", 0.0, 0.6, {"density": 0.6, "max_distance": 1.0})
	# Hanging whale sculpture over the lobby, swimming toward the rotunda.
	var whale := _prop(dressing, "aqua_whale", "Whale", Vector3(-4.0, 5.9, 18.0), 200.0, Vector3(2, 2, 9))
	whale.rotation.z = deg_to_rad(4.0)
	# Pendant lamps.
	for px in [-16.0, -8.0, 8.0, 16.0]:
		_prop(dressing, "aqua_pendant", "Pendant%d" % int(px), Vector3(px, LOBBY_H, 16.5), 0.0, Vector3(0.9, 2, 0.9))
	for z in [-10.0, -2.0, 6.0]:
		_prop(dressing, "aqua_pendant", "PendantW%d" % int(z), Vector3(-16.5, HALL_H, z), 0.0, Vector3(0.9, 2, 0.9))
		_prop(dressing, "aqua_pendant", "PendantE%d" % int(z), Vector3(15.3, HALL_H, z + 3.0), 0.0, Vector3(0.9, 2, 0.9))
	# Glowing murals on the long blank walls.
	_prop(dressing, "aqua_mural", "MuralLobbyE", Vector3(X1 - 0.1, 2.4, 17.5), -90.0, Vector3(6, 2.8, 0.2))
	_prop(dressing, "aqua_mural", "MuralLobbyW", Vector3(X0 + 0.1, 2.4, 22.0), 90.0, Vector3(6, 2.8, 0.2))
	_prop(dressing, "aqua_mural", "MuralCoreW", Vector3(-CORE - 0.55, 1.2, -9.2), -90.0, Vector3(6, 2.8, 0.2))
	_prop(dressing, "aqua_mural", "MuralCoreE", Vector3(CORE + 0.55, 1.2, 9.0), 90.0, Vector3(6, 2.8, 0.2))
	_prop(dressing, "aqua_mural", "MuralNW", Vector3(X0 + 0.1, 1.4, -19.0), 90.0, Vector3(6, 2.8, 0.2))
	_prop(dressing, "aqua_mural", "MuralNE", Vector3(X1 - 0.1, 1.4, -19.5), -90.0, Vector3(6, 2.8, 0.2))
	# Lobby furniture.
	for spot in [[Vector3(-6.0, 0, 15.6), 0.0], [Vector3(6.0, 0, 15.6), 0.0], [Vector3(-12.0, 0, 19.5), 180.0], [Vector3(12.0, 0, 19.5), 180.0]]:
		var p: Vector3 = spot[0]
		_prop(lobby, "aqua_bench", "LobbyBench%d" % int(p.x), p, spot[1], Vector3(2.4, 0.6, 0.7))
		_collider(lobby, "LobbyBenchCol%d" % int(p.x), Vector3(2.4, 0.6, 0.7), p + Vector3(0, 0.3, 0))
	for spot in [Vector3(-9.0, 0, 15.0), Vector3(9.0, 0, 15.0)]:
		_prop(lobby, "aqua_info_kiosk", "InfoKiosk%d" % int(spot.x), spot, 0.0, Vector3(1, 2.5, 0.5))
		_collider(lobby, "InfoKioskCol%d" % int(spot.x), Vector3(1.0, 2.4, 0.5), spot + Vector3(0, 1.2, 0))
	for spot in [Vector3(-7.4, 0, 19.8), Vector3(7.4, 0, 19.8), Vector3(-16.0, 0, -12.5), Vector3(16.0, 0, 12.6), Vector3(-22.4, 0, -14.0)]:
		_prop(lobby, "aqua_bin", "Bin%d%d" % [int(spot.x), int(spot.z)], spot, 0.0, Vector3(0.6, 1, 0.6))
		_collider(lobby, "BinCol%d%d" % [int(spot.x), int(spot.z)], Vector3(0.6, 1.0, 0.6), spot + Vector3(0, 0.5, 0))


# ---------------------------------------------------------------------------
# Zombie entrances (all beyond the walking loop) with small rooms behind them
# ---------------------------------------------------------------------------

func _build_entrances() -> void:
	var ent := _node(geo, "Entrances")
	var concrete := _mat("concrete", Color(0.24, 0.27, 0.33), 0.85)
	var wall := _plain_wall_mat()
	# 1. Filtration room behind the north wall, NW corner.
	_prop(ent, "aqua_filtration", "Filtration", Vector3(-17.0, 0, Z0), 0.0, Vector3(3, 3, 0.5))
	_collider(ent, "PumpW", Vector3(1.7, 2.6, 1.7), Vector3(-19.1, 1.3, Z0 - 3.3))
	_collider(ent, "PumpE", Vector3(1.7, 2.6, 1.7), Vector3(-14.9, 1.3, Z0 - 3.3))
	_slab(ent, "FiltFloor", -20.0, -14.0, Z0 - 5.4, Z0 + 0.1, concrete)
	_room_walls(ent, "Filt", -20.0, -14.0, Z0 - 5.4, Z0, 4.6, wall)
	# 2. Service elevator, NE corner.
	_prop(ent, "aqua_elevator", "Elevator", Vector3(17.0, 0, Z0), 0.0, Vector3(3, 3, 0.5))
	_slab(ent, "ElevFloor", 15.7, 18.3, Z0 - 2.9, Z0 + 0.1, concrete)
	_room_walls(ent, "Elev", 15.7, 18.3, Z0 - 2.9, Z0, 3.0, wall)
	# 3. Loading bay on the east wall.
	_prop(ent, "aqua_loading_door", "LoadingDoor", Vector3(X1, 0, 7.0), -90.0, Vector3(5, 4, 0.5))
	_slab(ent, "DockFloor", X1 - 0.1, X1 + 4.4, 4.6, 9.4, concrete)
	_room_walls(ent, "Dock", X1, X1 + 4.4, 4.6, 9.4, 4.0, wall, "W")
	_collider(ent, "DockCrates", Vector3(1.2, 1.8, 1.6), Vector3(X1 + 3.0, 0.9, 5.4))
	_collider(ent, "DockCrates2", Vector3(2.2, 1.2, 1.4), Vector3(X1 + 2.9, 0.6, 8.6))
	# 4. Staff door on the west wall.
	_prop(ent, "aqua_staff_door", "StaffDoor", Vector3(X0, 0, 11.5), 90.0, Vector3(3, 3, 0.5))
	_slab(ent, "StaffFloor", X0 - 4.0, X0 + 0.1, 10.3, 12.7, concrete)
	_room_walls(ent, "Staff", X0 - 4.0, X0, 10.3, 12.7, 3.0, wall, "E")
	# Red emergency beacons above each door (light + pulsing via the Ambience animation).
	for spot in [Vector3(-17.0, 3.6, Z0 + 0.6), Vector3(17.0, 3.8, Z0 + 0.6), Vector3(X1 - 0.6, 4.4, 7.0), Vector3(X0 + 0.6, 3.4, 11.5), Vector3(0.0, 2.9, MEZZ_Z - 0.4)]:
		var l := _omni(lights, "Emergency%d%d" % [int(spot.x), int(spot.z)], spot, Color(1.0, 0.18, 0.15), 1.4, 5.0)
		l.add_to_group("aqua_emergency", true)


## Three walls (and a lid) around a spawn room; `open` names the side left open
## (the door side). Default open side is south (+Z) for rooms north of the hall.
func _room_walls(parent: Node3D, prefix: String, x0: float, x1: float, z0: float, z1: float, h: float, m: Material, open := "S") -> void:
	if open != "W":
		_wall_box(parent, prefix + "W", Vector3(0.4, h, z1 - z0), Vector3(x0 - 0.2, h * 0.5, (z0 + z1) * 0.5), m)
	if open != "E":
		_wall_box(parent, prefix + "E", Vector3(0.4, h, z1 - z0), Vector3(x1 + 0.2, h * 0.5, (z0 + z1) * 0.5), m)
	if open != "N":
		_wall_box(parent, prefix + "N", Vector3(x1 - x0 + 0.8, h, 0.4), Vector3((x0 + x1) * 0.5, h * 0.5, z0 - 0.2), m)
	if open != "S":
		_wall_box(parent, prefix + "S", Vector3(x1 - x0 + 0.8, h, 0.4), Vector3((x0 + x1) * 0.5, h * 0.5, z1 + 0.2), m)
	_mesh_box(dressing, prefix + "Lid", Vector3(x1 - x0 + 0.8, 0.3, z1 - z0 + 0.8), Vector3((x0 + x1) * 0.5, h + 0.15, (z0 + z1) * 0.5), _mat("ceiling", Color(0.05, 0.08, 0.15), 0.85))


# ---------------------------------------------------------------------------
# Wayfinding and banners (Label3D)
# ---------------------------------------------------------------------------

func _build_signage() -> void:
	var signs := _node(dressing, "Signage")
	# Over the rotunda openings, both faces.
	var over := [[180.0, "KELP FOREST", Color(0.55, 1.0, 0.7)], [0.0, "JELLYFISH", Color(1.0, 0.6, 0.95)], [90.0, "LOBBY & GIFT SHOP", Color(1.0, 0.85, 0.4)]]
	for entry in over:
		var a := deg_to_rad(entry[0])
		var dir := Vector3(cos(a), 0, sin(a))
		_label(signs, "In%d" % int(entry[0]), entry[1], dir * (ROT_R - 0.05) + Vector3(0, 5.6, 0), -a - PI * 0.5, 0.012, entry[2])
		_label(signs, "Out%d" % int(entry[0]), "ROTUNDA", dir * (CORE + 0.55) + Vector3(0, 5.2, 0), -a + PI * 0.5, 0.01, Color(0.6, 0.95, 1.0))
	_label(signs, "SharkWindow", "SHARK BAY", Vector3(0, 7.4, -ROT_R + 0.1), 0.0, 0.014, Color(0.6, 0.95, 1.0))
	_label(signs, "Welcome", "ABYSS AQUARIUM", Vector3(0, 6.3, CORE + 0.55), 0.0, 0.016, Color(1.0, 0.8, 0.35))
	# Signposts at the hall junctions.
	var posts := [[Vector3(-17.0, 0, -16.5), 0.0, "SHARK\nTUNNEL >"], [Vector3(17.0, 0, -16.5), 0.0, "< SHARK\nTUNNEL"],
		[Vector3(-14.5, 0, 14.6), 0.0, "TOUCH\nPOOL"], [Vector3(15.0, 0, 14.6), 0.0, "UPPER\nDECK"]]
	var k := 0
	for p in posts:
		_prop(geo, "aqua_signpost", "Signpost%d" % k, p[0], p[1], Vector3(1.3, 2.7, 0.2))
		_collider(geo, "SignpostCol%d" % k, Vector3(0.5, 2.0, 0.3), p[0] + Vector3(0, 1.0, 0))
		_label(signs, "Post%dF" % k, p[2], p[0] + Vector3(0, 2.1, 0.075), deg_to_rad(p[1]), 0.0028, Color(1.0, 0.9, 0.55))
		_label(signs, "Post%dB" % k, p[2], p[0] + Vector3(0, 2.1, -0.075), deg_to_rad(p[1]) + PI, 0.0028, Color(1.0, 0.9, 0.55))
		k += 1
	# Exit signs.
	for e in [[Vector3(-17.0, 3.4, Z0 + 0.3), 0.0], [Vector3(17.0, 3.6, Z0 + 0.3), 0.0], [Vector3(X0 + 0.3, 3.3, 11.5), 90.0], [Vector3(X1 - 0.3, 4.2, 2.0), -90.0]]:
		_prop(dressing, "aqua_exit_sign", "Exit%d%d" % [int(e[0].x), int(e[0].z)], e[0], e[1], Vector3(0.9, 0.34, 0.12))
	# Hanging banners in the rotunda between the openings.
	var texts := ["DIVE\nDEEP", "REEF\nLIFE", "MEET\nTHE\nSHARKS", "GLOW\nZONE"]
	var k2 := 0
	for deg in [45.0, 135.0, 225.0, 315.0]:
		var a := deg_to_rad(deg)
		var p := Vector3(cos(a), 0, sin(a)) * (ROT_R - 0.3) + Vector3(0, 6.6, 0)
		var colour := Color(0.06, 0.42, 0.52) if k2 % 2 == 0 else Color(0.42, 0.14, 0.55)
		var banner := _mesh_box(signs, "Banner%d" % int(deg), Vector3(1.6, 3.0, 0.06), p, _mat("banner_%d" % (k2 % 2), colour, 0.6))
		banner.rotation.y = -a - PI * 0.5
		var rod := _mesh_box(signs, "BannerRod%d" % int(deg), Vector3(1.9, 0.08, 0.08), Vector3.ZERO, _mat("brass", Color(0.84, 0.64, 0.27), 0.35))
		rod.transform = banner.transform.translated_local(Vector3(0, 1.55, 0))
		_label(signs, "BannerText%d" % int(deg), texts[k2], p - Vector3(cos(a), 0, sin(a)) * 0.05 + Vector3(0, 0.2, 0), -a - PI * 0.5, 0.0075, Color(1.0, 0.9, 0.6))
		k2 += 1


func _label(parent: Node3D, lname: String, text: String, pos: Vector3, yaw: float, pixel: float, color: Color) -> Label3D:
	var l := Label3D.new()
	l.name = lname
	l.text = text
	l.font = _font
	l.font_size = 128
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 18
	l.outline_modulate = Color(0.02, 0.05, 0.12)
	l.position = pos
	l.rotation.y = yaw
	l.shaded = false
	l.double_sided = false
	parent.add_child(l)
	return l


# ---------------------------------------------------------------------------
# Lights: a few shadowless omnis per room plus the emergency beacons
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	_omni(lights, "TankCore", Vector3(0, 5.0, 0), Color(0.3, 0.95, 1.0), 2.2, 13.0)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		_omni(lights, "RotundaRing%d" % i, Vector3(cos(a) * 8.5, 7.0, sin(a) * 8.5), Color(0.35, 0.75, 1.0), 0.9, 10.0)
	_omni(lights, "SharkBay", Vector3(0, 3.5, -13.0), Color(0.2, 0.55, 1.0), 1.6, 8.0, true)
	for x in [-7.0, 0.0, 7.0]:
		_omni(lights, "Tunnel%d" % int(x), Vector3(x, 3.4, TUN_Z), Color(0.25, 0.65, 1.0), 1.5, 7.0)
		_omni(lights, "TankFill%d" % int(x), Vector3(x, 5.8, TUN_Z + (5.0 if x == 0.0 else -4.5)), Color(0.2, 0.75, 1.0), 1.4, 9.0, true)
	for z in [-9.0, 0.0, 9.0]:
		_omni(lights, "Kelp%d" % int(z), Vector3(-17.0, 4.0, z), Color(0.35, 1.0, 0.75), 1.1, 9.0)
	_omni(lights, "KelpTank", Vector3(-21.6, 4.8, -1.5), Color(0.5, 1.0, 0.6), 1.8, 12.0, true)
	for z in [-9.0, -3.0, 3.0, 9.0]:
		_omni(lights, "Jelly%d" % int(z), Vector3(18.2, 2.0, z), Color(0.85, 0.4, 1.0) if int(z) % 2 == 0 else Color(1.0, 0.45, 0.8), 1.5, 6.0)
	_omni(lights, "JellyWall", Vector3(24.3, 3.0, -6.0), Color(0.75, 0.45, 1.0), 1.6, 7.0, true)
	_omni(lights, "NW", Vector3(-17.0, 4.5, -19.5), Color(0.35, 0.8, 1.0), 1.0, 9.0)
	_omni(lights, "NE", Vector3(17.0, 4.5, -19.5), Color(0.6, 0.5, 1.0), 1.0, 9.0)
	_omni(lights, "LobbyShop", Vector3(0, 2.2, 18.5), Color(1.0, 0.72, 0.45), 1.8, 8.0)
	_omni(lights, "ShopInside", Vector3(0, 2.0, 22.5), Color(1.0, 0.8, 0.55), 1.4, 7.0)
	_omni(lights, "Whale", Vector3(-4.0, 7.2, 16.5), Color(0.55, 0.8, 1.0), 1.0, 8.0)
	_omni(lights, "LobbyW", Vector3(-14.0, 5.0, 18.5), Color(0.4, 0.9, 1.0), 1.2, 11.0)
	_omni(lights, "LobbyE", Vector3(14.0, 5.0, 18.5), Color(1.0, 0.5, 0.85), 1.2, 11.0)
	_omni(lights, "Mezz", Vector3(0, MEZZ_Y + 3.0, 22.8), Color(0.5, 0.85, 1.0), 1.1, 9.0)
	for deg in [45.0, 135.0, 225.0, 315.0]:
		var a := deg_to_rad(deg)
		_omni(lights, "Pocket%d" % int(deg), Vector3(cos(a), 0, sin(a)) * (ROT_R + 2.2) + Vector3(0, 3.2, 0), Color(0.3, 0.9, 1.0), 1.6, 4.0, true)
	# Warm pools of light around the Reef Supply Ring.
	for i in 4:
		var a := TAU * i / 4.0
		_omni(lights, "StationWarm%d" % i, Vector3(cos(a) * 6.4, 1.6, sin(a) * 6.4), Color(1.0, 0.7, 0.3), 1.1, 5.5)
	_omni(lights, "ReefInside", Vector3(0, 4.5, 0), Color(0.6, 0.95, 1.0), 1.6, 5.0, true)
	# Emergency beacons pulse (an always-running animation, no script needed).
	var player := AnimationPlayer.new()
	player.name = "Ambience"
	level.add_child(player)
	var anim := Animation.new()
	anim.length = 1.2
	anim.loop_mode = Animation.LOOP_LINEAR
	for l in lights.get_children():
		if l.is_in_group("aqua_emergency"):
			var track := anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(track, NodePath("Lights/%s:light_energy" % l.name))
			anim.track_insert_key(track, 0.0, 0.2)
			anim.track_insert_key(track, 0.15, 2.2)
			anim.track_insert_key(track, 0.6, 0.25)
			anim.track_insert_key(track, 1.2, 0.2)
	var lib := AnimationLibrary.new()
	lib.add_animation(&"pulse", anim)
	player.add_animation_library(&"", lib)
	player.autoplay = &"pulse"


func _omni(parent: Node3D, lname: String, pos: Vector3, color: Color, energy: float, range_m: float, tank_only := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	if tank_only:
		l.light_cull_mask = 1 << (TANK_LAYER - 1)
	l.name = lname
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	parent.add_child(l)
	return l


# ---------------------------------------------------------------------------
# Exit: portal on the observation deck; lights from the rotunda up the east ramp
# ---------------------------------------------------------------------------

func _build_exit() -> void:
	var portal: Node3D = (load("res://scenes/props/portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	geo.add_child(portal)
	portal.position = Vector3(0, MEZZ_Y, Z1 - 1.0)
	portal.rotation.y = PI
	var route: Array[Vector3] = [Vector3(0, 0, 10.5), Vector3(2.5, 0, 14.0), Vector3(6.5, 0, 16.6), Vector3(10.5, 0, 18.4),
		Vector3(14.5, 0, 19.6), Vector3(18.6, 0, 21.0)]
	var steps := 6
	for k in steps + 1:
		var t := float(k) / steps
		var x: float = lerpf(MEZZ_X + RAMP_LEN - 0.6, MEZZ_X, t)
		route.append(Vector3(x, MEZZ_Y * (MEZZ_X + RAMP_LEN - x) / RAMP_LEN, 23.2))
	for xx in [7.5, 5.0, 2.5]:
		route.append(Vector3(xx, MEZZ_Y, 23.4))
	var holder := _node(level, "ExitLights")
	var strip := BoxMesh.new()
	strip.size = Vector3(1.1, 0.04, 0.24)
	var light_script: Script = load("res://scripts/props/exit_light.gd")
	for i in route.size():
		var mi := MeshInstance3D.new()
		mi.name = "ExitLight%02d" % i
		mi.mesh = strip
		mi.position = route[i] + Vector3(0, 0.03, 0)
		var nxt: Vector3 = route[mini(i + 1, route.size() - 1)]
		var prv: Vector3 = route[maxi(i - 1, 0)]
		var d := nxt - prv
		mi.rotation.y = atan2(-d.z, d.x)
		if absf(d.y) > 0.01:
			mi.rotation.z = atan2(d.y, Vector2(d.x, d.z).length())
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_script(light_script)
		mi.set("order", i)
		holder.add_child(mi)


# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(0.0, 0.1, 18.0)
	start.rotation.y = 0.0
	start.add_to_group("player_spawn", true)
	level.add_child(start)
	var spawns := _node(level, "EnemySpawns")
	var points := {
		"SpawnFiltration": [Vector3(-17.0, 0.1, Z0 - 3.0), 0.0],
		"SpawnElevator": [Vector3(17.0, 0.1, Z0 - 1.6), 0.0],
		"SpawnLoadingBay": [Vector3(X1 + 1.8, 0.1, 7.2), -90.0],
		"SpawnStaffDoor": [Vector3(X0 - 2.2, 0.1, 11.5), 90.0],
		"SpawnStockroom": [Vector3(0.0, 0.1, MEZZ_Z + 2.5), 180.0],
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
	mesh.agent_max_slope = 32.0
	mesh.region_min_size = 6.0
	# Walkable surfaces only (floors, ramps, the deck): keeps roofs and tank lids out.
	mesh.filter_baking_aabb = AABB(Vector3(-40, -1.0, -40), Vector3(80, 4.8, 80))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	region.navigation_mesh = mesh
	print("build_tidal_tunnels: navmesh polygons = %d" % mesh.get_polygon_count())


# ---------------------------------------------------------------------------
# Sea life helpers
# ---------------------------------------------------------------------------

var _scene_cache := {}
var _swim_meshes := {}


func _glb_mesh(model: String, node_name: String) -> Mesh:
	if not _scene_cache.has(model):
		_scene_cache[model] = (load(MODELS + model + ".glb") as PackedScene).instantiate()
	var root: Node = _scene_cache[model]
	var mi := root.find_child(node_name, true, false) as MeshInstance3D
	return mi.mesh if mi else null


## A copy of a fish mesh whose surfaces use the swim shader (colours taken from
## the exported materials). `params` are shared shader settings for the species.
func _swim_mesh(node_name: String, params: Dictionary) -> Mesh:
	var key := node_name + str(params)
	if _swim_meshes.has(key):
		return _swim_meshes[key]
	var src := _glb_mesh("aqua_fish", node_name)
	var mesh: Mesh = src.duplicate()
	var shader: Shader = load(SHADERS + "aqua_swim.gdshader")
	for i in mesh.get_surface_count():
		var base := mesh.surface_get_material(i) as StandardMaterial3D
		var sm := ShaderMaterial.new()
		sm.resource_name = "%s_swim_%d" % [node_name, i]
		sm.shader = shader
		if base:
			sm.set_shader_parameter("albedo", base.albedo_color)
			sm.set_shader_parameter("roughness", base.roughness)
			if base.emission_enabled:
				sm.set_shader_parameter("emission", base.emission)
				sm.set_shader_parameter("emission_energy", base.emission_energy_multiplier)
		for k in params:
			sm.set_shader_parameter(k, params[k])
		mesh.surface_set_material(i, sm)
	_swim_meshes[key] = mesh
	return mesh


const SPECIES := {
	"FishClown": {"body_length": 0.24, "wiggle": 0.03, "wiggle_freq": 9.0},
	"FishTang": {"body_length": 0.32, "wiggle": 0.035, "wiggle_freq": 8.0},
	"FishAngel": {"body_length": 0.26, "wiggle": 0.025, "wiggle_freq": 5.0},
	"FishPuffer": {"body_length": 0.24, "wiggle": 0.02, "wiggle_freq": 6.0},
	"FishSnapper": {"body_length": 0.48, "wiggle": 0.05, "wiggle_freq": 6.5},
	"FishSardine": {"body_length": 0.18, "wiggle": 0.025, "wiggle_freq": 12.0},
}


## A school of `count` fish orbiting `centre` on ellipses of `radii`, with
## angular speeds drawn from `speed` (x..y, rad/s; negative = clockwise).
## `jitter` spreads orbit centres/radii, `height` spreads them vertically and
## `spread` is the phase spread (small = tight school).
func _school(parent: Node3D, sname: String, species: String, count: int, centre: Vector3, radii: Vector2, speed: Vector2,
		jitter: float, height: float, spread: float, params := {}, big := false) -> MultiMeshInstance3D:
	var p: Dictionary = SPECIES.get(species, {}).duplicate()
	p.merge(params, true)
	if not p.has("bob"):
		p["bob"] = 0.2
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _swim_mesh(species, p)
	mm.instance_count = count
	var base_phase := _rng.randf() * TAU
	for i in count:
		var s := _rng.randf_range(0.85, 1.15) * (1.0 if not big else _rng.randf_range(0.9, 1.1))
		var off := Vector3(_rng.randf_range(-jitter, jitter), _rng.randf_range(-height, height) * 0.5, _rng.randf_range(-jitter, jitter))
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), off))
		var phase := base_phase + (TAU * i / count if spread >= 1.0 else _rng.randf_range(-spread, spread))
		if big:
			phase = base_phase + TAU * i / count
		var rj := 1.0 + _rng.randf_range(-0.12, 0.12) * (1.0 if not big else 0.3)
		mm.set_instance_custom_data(i, Color(radii.x * rj, radii.y * rj, _rng.randf_range(speed.x, speed.y), phase))
	var node := MultiMeshInstance3D.new()
	node.name = sname
	node.multimesh = mm
	node.position = centre
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var extent := Vector3(radii.x + jitter + 2.0, height + 4.0, radii.y + jitter + 2.0)
	node.custom_aabb = AABB(-extent, extent * 2.0)
	parent.add_child(node)
	return node


## Kelp strands scattered between two corners (a line or a box).
func _kelp(parent: Node3D, kname: String, count: int, a: Vector3, b: Vector3, smin: float, smax: float, colour: Color) -> void:
	var mesh_tall: Mesh = _glb_mesh("aqua_kelp", "KelpTall").duplicate()
	var mesh_short: Mesh = _glb_mesh("aqua_kelp", "KelpShort").duplicate()
	var mat := _shader_mat("kelp_" + kname, "aqua_kelp.gdshader", {"albedo": colour, "tip_color": colour.lightened(0.45), "height": 5.6, "sway": 0.5})
	var mat_s := _shader_mat("kelp_s_" + kname, "aqua_kelp.gdshader", {"albedo": colour.darkened(0.1), "tip_color": colour.lightened(0.35), "height": 3.4, "sway": 0.35})
	for m in [[mesh_tall, mat], [mesh_short, mat_s]]:
		var mesh: Mesh = m[0]
		for i in mesh.get_surface_count():
			mesh.surface_set_material(i, m[1])
	for variant in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh_tall if variant == 0 else mesh_short
		var n := count >> 1
		mm.instance_count = n
		for i in n:
			var t := Vector3(_rng.randf(), 0, _rng.randf())
			var pos := Vector3(lerpf(a.x, b.x, t.x), a.y, lerpf(a.z, b.z, t.z))
			var s := _rng.randf_range(smin, smax)
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.85, 1.1), s)), pos))
		var node := MultiMeshInstance3D.new()
		node.name = "%s%d" % [kname, variant]
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)


## Glowing jellies drifting in a column (or a box when `box` is given: half extents).
func _jellies(parent: Node3D, jname: String, count: int, centre: Vector3, drift: float, rise: float, colour: Color, box := Vector3.ZERO) -> void:
	var mesh: Mesh = _glb_mesh("aqua_jelly", "Jelly").duplicate()
	var mat := _shader_mat("jelly_%s" % colour.to_html(false), "aqua_jelly.gdshader", {"albedo": colour, "glow": colour, "glow_energy": 1.8})
	for i in mesh.get_surface_count():
		mesh.surface_set_material(i, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var off := Vector3(_rng.randf_range(-box.x, box.x), _rng.randf_range(-1.6, 1.6) if box == Vector3.ZERO else _rng.randf_range(-box.y, box.y),
			_rng.randf_range(-box.z, box.z))
		var s := _rng.randf_range(0.7, 1.25)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), off))
		mm.set_instance_custom_data(i, Color(drift * _rng.randf_range(0.3, 1.0), rise * _rng.randf_range(0.2, 0.5), _rng.randf_range(0.25, 0.5), _rng.randf() * TAU))
	var node := MultiMeshInstance3D.new()
	node.name = jname
	node.multimesh = mm
	node.position = centre
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-3, -4, -6), Vector3(6, 8, 12))
	parent.add_child(node)


## A rising stream of small opaque bubbles (opaque so it shows through the water glass).
func _bubbles(parent: Node3D, bname: String, pos: Vector3, height: float) -> void:
	var p := CPUParticles3D.new()
	p.name = bname
	p.position = pos
	p.amount = 18
	p.lifetime = height / 1.1
	p.preprocess = p.lifetime
	p.direction = Vector3.UP
	p.spread = 6.0
	p.gravity = Vector3(0, 0.15, 0)
	p.initial_velocity_min = 0.9
	p.initial_velocity_max = 1.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.material = _mat("bubble", Color(0.8, 0.97, 1.0), 0.1, Color(0.6, 0.95, 1.0), 1.4)
	p.mesh = sphere
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var half := Vector3(0.6, height * 0.5 + 0.5, 0.6)
	p.visibility_aabb = AABB(Vector3(-half.x, -0.5, -half.z), Vector3(half.x * 2, height + 1.0, half.z * 2))
	parent.add_child(p)


func _light_shaft(parent: Node3D, sname: String, top: Vector3, width: float, length: float, colour: Color, strength: float) -> void:
	var holder := _node(parent, sname)
	holder.position = top
	var quad := QuadMesh.new()
	quad.size = Vector2(width, length)
	var mat := _shader_mat("shaft_%s_%.2f" % [colour.to_html(false), strength], "aqua_lightshaft.gdshader", {"color": colour, "strength": strength})
	for i in 3:
		var q := MeshInstance3D.new()
		q.name = "Quad%d" % i
		q.mesh = quad
		q.material_override = mat
		q.position.y = -length * 0.5
		q.rotation.y = PI * i / 3.0
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(q)


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

func _node(parent: Node, node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	parent.add_child(n)
	return n


## Curved strip on a circle (inner face toward the centre when `inward`), with
## metre UVs (u = arc length, v = -height).
func _arc_mesh(radius: float, a0: float, a1: float, y0: float, y1: float, inward := true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := maxi(2, int(ceil(absf(a1 - a0) * radius / 0.7)))
	for i in steps:
		var t0 := lerpf(a0, a1, float(i) / steps)
		var t1 := lerpf(a0, a1, float(i + 1) / steps)
		var u0 := t0 * radius
		var u1 := t1 * radius
		var bl := Vector3(cos(t0) * radius, y0, sin(t0) * radius)
		var br := Vector3(cos(t1) * radius, y0, sin(t1) * radius)
		var tr := Vector3(cos(t1) * radius, y1, sin(t1) * radius)
		var tl := Vector3(cos(t0) * radius, y1, sin(t0) * radius)
		var n0 := -Vector3(cos(t0), 0, sin(t0)) if inward else Vector3(cos(t0), 0, sin(t0))
		var n1 := -Vector3(cos(t1), 0, sin(t1)) if inward else Vector3(cos(t1), 0, sin(t1))
		var verts := [tl, tr, br, tl, br, bl] if inward else [tl, br, tr, tl, bl, br]
		var uvs := [Vector2(u0, -y1), Vector2(u1, -y1), Vector2(u1, -y0), Vector2(u0, -y1), Vector2(u1, -y0), Vector2(u0, -y0)] if inward \
			else [Vector2(u0, -y1), Vector2(u1, -y0), Vector2(u1, -y1), Vector2(u0, -y1), Vector2(u0, -y0), Vector2(u1, -y0)]
		for k in 6:
			var v: Vector3 = verts[k]
			st.set_normal(n0 if (v.x == bl.x and v.z == bl.z) else n1)
			st.set_uv(uvs[k])
			st.add_vertex(v)
	return st.commit()


func _arc_wall(parent: Node3D, wname: String, radius: float, a0: float, a1: float, y0: float, y1: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = wname
	mi.mesh = _arc_mesh(radius, a0, a1, y0, y1, true)
	mi.material_override = m
	parent.add_child(mi)


const PORTHOLES := [45.0, 135.0, 225.0, 315.0]
const PORT_HALF := 1.0      # half size of the square hole behind each porthole frame
const PORT_Y := 2.4


## Lower rotunda wall (0..4.6 m) for one arc, leaving square holes where the
## porthole tanks are.
func _lower_wall(parent: Node3D, wname: String, a0: float, a1: float, m: Material) -> void:
	var cuts: Array[float] = []
	for deg in PORTHOLES:
		var c := deg_to_rad(deg)
		if c > a0 and c < a1:
			cuts.append(c)
	var start := a0
	var k := 0
	for c in cuts:
		var h0 := c - PORT_HALF / ROT_R
		var h1 := c + PORT_HALF / ROT_R
		_arc_wall(parent, "%s_%d" % [wname, k], ROT_R, start, h0, 0.0, 4.6, m)
		_arc_wall(parent, "%s_%dlo" % [wname, k], ROT_R, h0, h1, 0.0, PORT_Y - PORT_HALF, m)
		_arc_wall(parent, "%s_%dhi" % [wname, k], ROT_R, h0, h1, PORT_Y + PORT_HALF, 4.6, m)
		start = h1
		k += 1
	_arc_wall(parent, "%s_%d" % [wname, k], ROT_R, start, a1, 0.0, 4.6, m)


## Box colliders following an arc.
func _arc_colliders(parent: Node3D, cname: String, radius: float, a0: float, a1: float, h: float, thick: float) -> void:
	var steps := maxi(1, int(ceil(absf(a1 - a0) * radius / 1.6)))
	for i in steps:
		var t0 := lerpf(a0, a1, float(i) / steps)
		var t1 := lerpf(a0, a1, float(i + 1) / steps)
		var mid := (t0 + t1) * 0.5
		var chord := 2.0 * radius * sin(absf(t1 - t0) * 0.5) + 0.12
		var c := _collider(parent, "%s_%02d" % [cname, i], Vector3(chord, h, thick), Vector3(cos(mid) * radius, h * 0.5, sin(mid) * radius))
		c.rotation.y = -mid + PI * 0.5


## Thin horizontal band (trim/LED) following a ring, as an arc strip of given depth.
func _arc_band_mesh(radius: float, a0: float, a1: float, y0: float, y1: float, _depth: float) -> ArrayMesh:
	return _arc_mesh(radius, a0, a1, y0, y1, true)


func _ring_band(parent: Node3D, bname: String, radius: float, y0: float, y1: float, _depth: float, m: Material) -> void:
	for arc in [[0.0, 120.0], [120.0, 240.0], [240.0, 360.0]]:
		var mi := MeshInstance3D.new()
		mi.name = "%s%d" % [bname, int(arc[0])]
		mi.mesh = _arc_mesh(radius, deg_to_rad(arc[0]), deg_to_rad(arc[1]), y0, y1, true)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


func _flat_ring(parent: Node3D, rname: String, r0: float, r1: float, m: Material, y := 0.008) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 96
	for i in steps:
		var a0 := TAU * i / steps
		var a1 := TAU * (i + 1) / steps
		var p := [Vector3(cos(a0) * r0, y, sin(a0) * r0), Vector3(cos(a1) * r0, y, sin(a1) * r0),
			Vector3(cos(a1) * r1, y, sin(a1) * r1), Vector3(cos(a0) * r1, y, sin(a0) * r1)]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p[idx])
	var mi := MeshInstance3D.new()
	mi.name = rname
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Flat pie slice (floor), top at local y = `top`.
func _sector_mesh(radius: float, a0: float, a1: float, top: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 24
	for i in steps:
		var t0 := lerpf(a0, a1, float(i) / steps)
		var t1 := lerpf(a0, a1, float(i + 1) / steps)
		for v in [Vector3(0, top, 0), Vector3(cos(t1) * radius, top, sin(t1) * radius), Vector3(cos(t0) * radius, top, sin(t0) * radius)]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


## Hemispherical dome (seen from inside), squashed vertically by `k`.
func _dome_mesh(radius: float, k: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 14
	var segs := 64
	for j in rings:
		var e0 := PI * 0.5 * j / rings
		var e1 := PI * 0.5 * (j + 1) / rings
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var q := [_dome_pt(radius, k, e0, a0), _dome_pt(radius, k, e0, a1), _dome_pt(radius, k, e1, a1), _dome_pt(radius, k, e1, a0)]
			for idx in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = q[idx]
				st.set_normal(-v.normalized())
				st.add_vertex(v)
	return st.commit()


func _dome_pt(radius: float, k: float, e: float, a: float) -> Vector3:
	return Vector3(cos(e) * cos(a) * radius, sin(e) * radius * k, cos(e) * sin(a) * radius)


## A flat five-pointed star, 1 m across, lying on the floor.
func _star_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for k in 10:
		var r := 0.5 if k % 2 == 0 else 0.22
		var a := -PI * 0.5 + PI * k / 5.0
		pts.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	for k in 10:
		for v in [Vector3.ZERO, pts[(k + 1) % 10], pts[k]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


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


func _wall_box(parent: Node3D, wname: String, size: Vector3, pos: Vector3, material: Material) -> StaticBody3D:
	return _box(parent, wname, size, pos, material)


## Wall from a to b (top view), 0.5 m thick, on the outside of the line.
func _wall_seg(parent: Node3D, wname: String, a: Vector2, b: Vector2, h: float, material: Material) -> void:
	var d := b - a
	var length := d.length()
	var mid := (a + b) * 0.5
	var body := _box(parent, wname, Vector3(length, h, 0.5), Vector3(mid.x, h * 0.5, mid.y), material)
	body.rotation.y = -atan2(d.y, d.x)
	# Push outward (away from the building centre) so the inner face sits on the line.
	var normal := Vector2(-d.y, d.x).normalized()
	if normal.dot(-mid) > 0.0:
		normal = -normal
	body.position += Vector3(normal.x, 0, normal.y) * 0.25


func _mesh_box(parent: Node3D, mname: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mname
	mi.mesh = _box_mesh(size, material)
	mi.position = pos
	parent.add_child(mi)
	return mi


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


## Moves every visual under `node` to render `layer` (keeps the glass on layer 1).
func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D and not String(node.name).contains("Glass") and not String(node.name).begins_with("PortGlass"):
		(node as VisualInstance3D).layers = 1 << (layer - 1)
	for c in node.get_children():
		_set_layers(c, layer)


func _own(node: Node) -> void:
	for child in node.get_children():
		child.owner = level
		if child.scene_file_path == "":
			_own(child)
