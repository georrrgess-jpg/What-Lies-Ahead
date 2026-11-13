extends SceneTree
## Generator for World 6 "Megamall Midnight" / level "Midnight Mall".
##
## Rebuilds scenes/levels/midnight_mall.tscn: the Moonbeam Galleria after
## closing time. Two full floors round the Grand Court, the eight-sided glass
## dome, the Moonfall Fountain and the glass elevator, the scissor escalators,
## the Galaxy Carousel, shop fronts (shuttered, half-shuttered with lit
## interiors, or glass with window displays), the food court, the department
## store, the staff corridor, the cinema, the main entrance, lights, the exit
## route, spawn markers and a baked navigation mesh.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_midnight_mall.gd
##
## Run it with a renderer (not --headless): the headless renderer keeps no
## MultiMesh instance data, so palms, tables and lights would save empty.
## NOTE: running this overwrites hand edits made to midnight_mall.tscn.
##
## Layout (metres, top view; -Z = north; ground floor y 0, upper floor y 5):
##   - The building is 48 x 60 m (x -24..24, z -30..30). The hall inside the
##     shop fronts is x -18..18, z -24..24; the Grand Court void in its middle
##     is an elongated octagon (x +-10, z +-18, 5 m chamfers) open to the dome.
##   - Court: Moonfall Fountain (0, -9) with the glass elevator behind it,
##     Guest Services (loadout station) at (0, 2.5), the Galaxy Carousel and
##     kiddie rides at (0, 12.5). East escalator rises north (z 12 -> 2), the
##     dead west escalator rises south (z -12 -> -2); both land on balcony
##     landings joined to the upper floor.
##   - Colonnade ring round the court on both floors; the food court fills the
##     east colonnade on the ground floor.
##   - Zombie entrances: main entrance vestibule (S), staff corridor (W),
##     department store under its half-raised shutter (N), food-court kitchen
##     (E), and the Starplex cinema lobby upstairs (S).
##   - The exit portal waits on the north balcony; lights chase up the east
##     escalator to it.

const OUT_PATH := "res://scenes/levels/midnight_mall.tscn"
const MODELS := "res://art/models/"
const SHADERS := "res://art/shaders/"

const X0 := -24.0
const X1 := 24.0
const Z0 := -30.0
const Z1 := 30.0
const HX := 18.0          # shop-front lines (hall half-width)
const HZ := 24.0
const VX := 10.0          # void half-width
const VZ := 18.0
const VC := 5.0           # void chamfer
const UP := 5.0           # upper floor level
const SLAB := 0.6
const CEIL := 10.4        # upper ceiling
const DRUM := 12.0        # dome springing
const DOME_H := 9.0
const OPEN_H := 3.4       # shop opening height above its floor
const RAIL_H := 1.1
const KERB_H := 1.4       # escalator balustrade collision above the walkway
const STATION := Vector3(0.0, 0.0, 2.5)
const FOUNTAIN := Vector3(0.0, 0.0, -9.0)
const CAROUSEL := Vector3(0.0, 0.0, 12.5)
const ELEVATOR := Vector3(0.0, 0.0, -16.2)
const ESC_X := 8.3        # escalator centre lines (east +, west -)
const ESC_HALF := 1.5     # escalator half-width (cladding)
const ESC_WALK := 1.25    # half-width of the walkway between the balustrades
const PORTAL := Vector3(10.0, UP, -22.4)
## Light-sized batching cells (the Compatibility renderer lights an object with
## at most 8 omni lights, so merged geometry is split into 12 m cells).
const CELL := 12.0
const MOON_DIR := Vector3(0.35, 0.78, -0.52)

const PINK := Color(1.0, 0.31, 0.66)
const TEAL := Color(0.25, 0.94, 0.88)
const AMBER := Color(1.0, 0.71, 0.28)
const VIOLET := Color(0.6, 0.42, 1.0)
const MINT := Color(0.56, 0.96, 0.78)
const CREAM := Color(1.0, 0.93, 0.8)
const ORANGE := Color(1.0, 0.5, 0.2)
const WARM := Color(1.0, 0.74, 0.46)

## Octagon outline of the void, clockwise from the north-west (x, z).
var OCT: Array[Vector2] = [Vector2(-VX + VC, -VZ), Vector2(VX - VC, -VZ), Vector2(VX, -VZ + VC), Vector2(VX, VZ - VC),
	Vector2(VX - VC, VZ), Vector2(-VX + VC, VZ), Vector2(-VX, VZ - VC), Vector2(-VX, -VZ + VC)]

var level: Node3D
var geo: Node3D          # collidable geometry (navmesh source)
var dressing: Node3D     # non-colliding scenery
var lights: Node3D
var signs: Node3D
var _materials := {}
var _batches := {}       # "material|cell" -> SurfaceTool
var _batch_material := {}
var _font: Font
var _late_scripts: Array = []
var _mesh_cache := {}
var _multi := {}         # model -> Array[Transform3D]
var _light_count := 0


func _initialize() -> void:
	_font = load("res://art/fonts/LilitaOne-Regular.ttf")
	level = Node3D.new()
	level.name = "MidnightMall"
	_build_environment()
	var nav := NavigationRegion3D.new()
	nav.name = "NavigationRegion3D"
	level.add_child(nav)
	geo = _node(nav, "Geometry")
	dressing = _node(level, "Dressing")
	lights = _node(level, "Lights")
	signs = _node(dressing, "Signs")

	_build_shell()
	_build_balconies()
	_build_dome()
	_build_escalators()
	_build_elevator()
	_build_fountain()
	_build_station()
	_build_kiddie_zone()
	_build_shopfronts()
	_build_food_court()
	_build_department_store()
	_build_entrances()
	_build_hall_dressing()
	_build_banners()
	_build_lights()
	_build_exit()
	_build_markers()
	_flush_multimeshes()
	_flush_batches()

	get_root().add_child(level)
	await process_frame
	_bake_navigation(nav)
	get_root().remove_child(level)

	for entry in _late_scripts:
		var node: Node = entry[0]
		node.set_script(load(entry[1]))
		for key in entry[2]:
			node.set(key, entry[2][key])
	level.set_script(load("res://scripts/run/midnight_mall_environment.gd"))
	var director := Node.new()
	director.name = "RunDirector"
	director.set_script(load("res://scripts/run/run_director.gd"))
	level.add_child(director)

	_own(level)
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_PATH)
	print("build_midnight_mall: saved %s (error %d), %d omni lights" % [OUT_PATH, err, _light_count])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: moonlight through the dome, warm shops, pink and teal neon
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SHADERS + "mall_night_sky.gdshader")
	sky_mat.set_shader_parameter("moon_dir", MOON_DIR)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.44, 0.84)
	env.ambient_light_energy = 0.46
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.3
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.17, 0.4)
	env.fog_density = 0.0075
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	# Moonlight through the dome: the only shadowed light, so the ribs throw
	# their pattern on the court and the colonnades stay out of it.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.looking_at(-MOON_DIR.normalized(), Vector3.UP), Vector3(0, 30, 0))
	sun.light_color = Color(0.66, 0.74, 1.0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_opacity = 0.85
	level.add_child(sun)


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

func _mat(key: String, color: Color, roughness := 0.6, emission := Color.BLACK, energy := 0.0, metal := 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metal
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	_materials[key] = m
	return m


func _glow(key: String, color: Color, energy := 2.4) -> StandardMaterial3D:
	return _mat(key, color, 0.35, color, energy)


func _glass_mat(key: String, color: Color, alpha: float) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := _mat(key, Color(color.r, color.g, color.b, alpha), 0.06)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic_specular = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
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


## Material for a batch key (created on first use).
func _m(key: String) -> Material:
	match key:
		"terrazzo":
			return _shader_mat("terrazzo", "mall_terrazzo.gdshader", {"base_color": Color(0.78, 0.72, 0.74), "chip_scale": 14.0})
		"terrazzo_up":
			return _shader_mat("terrazzo_up", "mall_terrazzo.gdshader", {"base_color": Color(0.68, 0.66, 0.78), "tile_size": 2.4,
				"chip_a": Color(0.6, 0.5, 0.95), "chip_scale": 14.0})
		"shutter":
			return _shader_mat("shutter", "mall_shutter.gdshader")
		"ceiling":
			return _mat("ceiling", Color(0.5, 0.48, 0.66), 0.8)
		"wall":
			return _mat("wall", Color(0.74, 0.7, 0.78), 0.7)
		"wall_dark":
			return _mat("wall_dark", Color(0.16, 0.17, 0.32), 0.7)
		"navy":
			return _mat("navy", Color(0.11, 0.13, 0.32), 0.45)
		"chrome":
			return _mat("chrome", Color(0.78, 0.8, 0.88), 0.18, Color.BLACK, 0.0, 0.85)
		"cream":
			return _mat("cream", Color(1.0, 0.93, 0.84), 0.5)
		"pink":
			return _mat("pink", Color(0.93, 0.36, 0.62), 0.5)
		"teal":
			return _mat("teal", Color(0.1, 0.62, 0.62), 0.45)
		"violet":
			return _mat("violet", Color(0.42, 0.28, 0.82), 0.5)
		"glass":
			return _glass_mat("glass", Color(0.7, 0.88, 1.0), 0.18)
		"dome_glass":
			return _glass_mat("dome_glass", Color(0.35, 0.45, 0.95), 0.16)
		"neon_pink":
			return _glow("neon_pink", PINK, 3.0)
		"neon_teal":
			return _glow("neon_teal", TEAL, 3.0)
		"neon_amber":
			return _glow("neon_amber", AMBER, 2.6)
		"neon_violet":
			return _glow("neon_violet", VIOLET, 3.0)
		"lamp":
			return _glow("lamp", Color(1.0, 0.92, 0.8), 2.2)
		"interior_warm":
			return _mat("interior_warm", Color(1.0, 0.86, 0.72), 0.7, Color(1.0, 0.72, 0.45), 0.35)
		"interior_cool":
			return _mat("interior_cool", Color(0.8, 0.9, 1.0), 0.7, Color(0.55, 0.75, 1.0), 0.3)
		"interior_pink":
			return _mat("interior_pink", Color(1.0, 0.8, 0.9), 0.7, Color(1.0, 0.5, 0.75), 0.3)
		"panel_light":
			return _glow("panel_light", Color(1.0, 0.95, 0.85), 1.8)
		"outside":
			return _mat("outside", Color(0.05, 0.06, 0.12), 0.9)
	push_error("unknown material " + key)
	return _mat("missing", Color.MAGENTA)


# ---------------------------------------------------------------------------
# Batched geometry: boxes and prisms merged per material and 12 m cell
# ---------------------------------------------------------------------------

func _cell(p: Vector3) -> String:
	return "%d_%d_%d" % [floori((p.x - X0) / CELL), floori((p.z - Z0) / CELL), 0 if p.y < UP - 0.1 else 1]


func _st(mat_key: String, at: Vector3) -> SurfaceTool:
	var key := mat_key + "|" + _cell(at)
	if not _batches.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[key] = st
		_batch_material[key] = _m(mat_key)
	return _batches[key]


## Adds a triangle with the winding Godot draws as front-facing for normal n.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(v.x + v.z, v.y))
		st.add_vertex(v)


## A visual box merged into its material's batch. Long axis-aligned boxes are
## split into cell-sized pieces so each piece picks up its own nearby lights.
func _bbox(mat_key: String, size: Vector3, center: Vector3, yaw := 0.0, pitch := 0.0) -> void:
	if yaw == 0.0 and pitch == 0.0:
		if size.x > CELL + 0.5:
			var n := ceili(size.x / CELL)
			for i in n:
				_bbox(mat_key, Vector3(size.x / n, size.y, size.z), center + Vector3(-size.x * 0.5 + size.x / n * (i + 0.5), 0, 0))
			return
		if size.z > CELL + 0.5:
			var n := ceili(size.z / CELL)
			for i in n:
				_bbox(mat_key, Vector3(size.x, size.y, size.z / n), center + Vector3(0, 0, -size.z * 0.5 + size.z / n * (i + 0.5)))
			return
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var st := _st(mat_key, center)
	var h := size * 0.5
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = sgn
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			var c := n * h[axis]
			var du := u * h[(axis + 1) % 3]
			var dv := v * h[(axis + 2) % 3]
			var q := [c - du - dv, c + du - dv, c + du + dv, c - du + dv]
			var wn := basis * n
			var w: Array[Vector3] = []
			for p in q:
				w.append(center + basis * p)
			_tri(st, w[0], w[1], w[2], wn)
			_tri(st, w[0], w[2], w[3], wn)


## A vertical prism over a convex (x, z) outline from y0 to y1, merged.
func _bprism(mat_key: String, pts: Array, y0: float, y1: float) -> void:
	var centre := Vector2.ZERO
	for p in pts:
		centre += p
	centre /= pts.size()
	var st := _st(mat_key, Vector3(centre.x, (y0 + y1) * 0.5, centre.y))
	for k in range(1, pts.size() - 1):
		var a: Vector2 = pts[0]
		var b: Vector2 = pts[k]
		var c: Vector2 = pts[k + 1]
		_tri(st, Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3(c.x, y1, c.y), Vector3.UP)
		_tri(st, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(c.x, y0, c.y), Vector3.DOWN)
	for k in pts.size():
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[(k + 1) % pts.size()]
		var mid := (a + b) * 0.5
		var e := b - a
		var n := Vector3(e.y, 0, -e.x).normalized()
		if Vector2(n.x, n.z).dot(mid - centre) < 0.0:
			n = -n
		_tri(st, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), n)
		_tri(st, Vector3(a.x, y0, a.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y), n)


func _flush_batches() -> void:
	var holder := _node(level, "Architecture")
	var keys := _batches.keys()
	keys.sort()
	for key in keys:
		var st: SurfaceTool = _batches[key]
		var mesh := st.commit()
		var mi := MeshInstance3D.new()
		mi.name = String(key).replace("|", "_")
		mi.mesh = mesh
		mi.material_override = _batch_material[key]
		var mat_key := String(key).get_slice("|", 0)
		if mat_key.ends_with("glass") or mat_key.begins_with("neon") or mat_key == "lamp" or mat_key == "panel_light":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mat_key.begins_with("neon") or mat_key == "panel_light" or mat_key.begins_with("interior"):
			mi.add_to_group("mall_neon", true)
		holder.add_child(mi)


# ---------------------------------------------------------------------------
# Shell: floors, upper slab, ceilings, outer walls
# ---------------------------------------------------------------------------

## The rectangle x0..x1, z0..z1 minus the void, as convex (x, z) pieces.
func _ring_pieces() -> Array:
	return [
		[Vector2(X0, Z0), Vector2(X1, Z0), Vector2(X1, -VZ), Vector2(X0, -VZ)],
		[Vector2(X0, VZ), Vector2(X1, VZ), Vector2(X1, Z1), Vector2(X0, Z1)],
		[Vector2(X0, -VZ), Vector2(-VX, -VZ), Vector2(-VX, VZ), Vector2(X0, VZ)],
		[Vector2(VX, -VZ), Vector2(X1, -VZ), Vector2(X1, VZ), Vector2(VX, VZ)],
		[OCT[0], Vector2(-VX, -VZ), OCT[7]],
		[OCT[1], OCT[2], Vector2(VX, -VZ)],
		[OCT[3], Vector2(VX, VZ), OCT[4]],
		[OCT[6], OCT[5], Vector2(-VX, VZ)],
	]


func _build_shell() -> void:
	var shell := _node(geo, "Shell")
	_collider(shell, "GroundSlab", Vector3(X1 - X0 + 2.0, 1.0, Z1 - Z0 + 2.0), Vector3(0, -0.5, 0))
	_bbox("terrazzo", Vector3(X1 - X0, 0.2, Z1 - Z0), Vector3(0, -0.1, 0))
	var k := 0
	for piece in _ring_pieces():
		var rect: bool = piece.size() == 4
		# Upper floor slab: collision and its terrazzo top / ceiling underside.
		_prism_collider(shell, "UpperSlab%d" % k, piece, UP - SLAB, UP)
		_prism_collider(shell, "Roof%d" % k, piece, CEIL, CEIL + 0.5)
		if rect:
			var a: Vector2 = piece[0]
			var b: Vector2 = piece[2]
			var size := Vector3(b.x - a.x, 0.05, b.y - a.y)
			var mid := Vector3((a.x + b.x) * 0.5, 0, (a.y + b.y) * 0.5)
			_bbox("terrazzo_up", size, mid + Vector3(0, UP - 0.025, 0))
			_bbox("ceiling", Vector3(size.x, SLAB - 0.05, size.z), mid + Vector3(0, UP - SLAB * 0.5 - 0.025, 0))
			_bbox("ceiling", Vector3(size.x, 0.5, size.z), mid + Vector3(0, CEIL + 0.25, 0))
		else:
			_bprism("terrazzo_up", piece, UP - 0.05, UP)
			_bprism("ceiling", piece, UP - SLAB, UP - 0.05)
			_bprism("ceiling", piece, CEIL, CEIL + 0.5)
		k += 1
	# Outer walls (the backs of every shop).
	var h := CEIL + 0.5
	var door_top := 3.6
	for w in [[Vector3(0.6, h, Z1 - Z0 + 1.2), Vector3(X0 - 0.3, h * 0.5, 0)], [Vector3(0.6, h, Z1 - Z0 + 1.2), Vector3(X1 + 0.3, h * 0.5, 0)],
			[Vector3(X1 - X0, h, 0.6), Vector3(0, h * 0.5, Z0 - 0.3)], [Vector3(20.0, h, 0.6), Vector3(-14.0, h * 0.5, Z1 + 0.3)],
			[Vector3(20.0, h, 0.6), Vector3(14.0, h * 0.5, Z1 + 0.3)], [Vector3(8.0, h - door_top, 0.6), Vector3(0, (h + door_top) * 0.5, Z1 + 0.3)]]:
		_collider(shell, "Outer%d" % k, w[0], w[1])
		_bbox("wall_dark", w[0], w[1])
		k += 1
	# Slab edge round the void: chrome fascia with a neon line.
	for i in OCT.size():
		var a := OCT[i]
		var b := OCT[(i + 1) % OCT.size()]
		_edge_strip(a, b, UP - SLAB * 0.5, SLAB, "navy", 0.06)
		_edge_strip(a, b, UP - SLAB + 0.12, 0.06, "neon_teal", 0.1)
		_edge_strip(a, b, CEIL + 0.1, 0.3, "navy", 0.06)
		_edge_strip(a, b, CEIL + 0.02, 0.05, "neon_pink", 0.1)


## A thin strip along the void edge a -> b (pushed `out` into the void).
func _edge_strip(a: Vector2, b: Vector2, y: float, height: float, mat_key: String, out: float) -> void:
	var mid := (a + b) * 0.5
	var e := b - a
	var n := Vector2(e.y, -e.x).normalized()
	if n.dot(mid) > 0.0:
		n = -n
	var c := mid + n * out
	_bbox(mat_key, Vector3(e.length() + 0.02, height, 0.12), Vector3(c.x, y, c.y), atan2(-e.y, e.x))


# ---------------------------------------------------------------------------
# Balconies: glass rails, landings, columns, ceiling lights
# ---------------------------------------------------------------------------

## Gaps in the balcony rail along each octagon edge (start, end along the edge in metres).
func _rail_gaps(i: int) -> Array:
	match i:
		0:
			return [[VX - VC - 1.1, VX - VC + 1.1]]     # north edge: the elevator bridge (x -1.1..1.1)
		2:
			return [[VZ - VC - 1.0, VZ - VC + 2.0]]      # east edge, z -1..2: the east landing
		6:
			return [[VZ - VC - 1.0, VZ - VC + 2.0]]      # west edge, z 1..-2: the west landing
	return []


func _build_balconies() -> void:
	var b := _node(geo, "Balconies")
	for i in OCT.size():
		var a := OCT[i]
		var c := OCT[(i + 1) % OCT.size()]
		var length := a.distance_to(c)
		var cuts := [0.0]
		for g in _rail_gaps(i):
			cuts.append(g[0])
			cuts.append(g[1])
		cuts.append(length)
		for k in range(0, cuts.size(), 2):
			var t0: float = cuts[k] / length
			var t1: float = cuts[k + 1] / length
			if t1 - t0 > 0.01:
				_rail(b, "Rail%d_%d" % [i, k], a.lerp(c, t0), a.lerp(c, t1), UP)
	# Escalator landings, joined to the east and west balconies.
	_landing(b, "LandingEast", Vector2(ESC_X - ESC_HALF, -1.0), Vector2(VX, 2.0))
	_landing(b, "LandingWest", Vector2(-VX, -2.0), Vector2(-ESC_X + ESC_HALF, 1.0))
	_rail(b, "LandingEastN", Vector2(ESC_X - ESC_HALF, -1.0), Vector2(VX, -1.0), UP)
	_rail(b, "LandingEastW", Vector2(ESC_X - ESC_HALF, -1.0), Vector2(ESC_X - ESC_HALF, 2.0), UP)
	_rail(b, "LandingWestS", Vector2(-VX, 1.0), Vector2(-ESC_X + ESC_HALF, 1.0), UP)
	_rail(b, "LandingWestE", Vector2(-ESC_X + ESC_HALF, -2.0), Vector2(-ESC_X + ESC_HALF, 1.0), UP)
	# Columns just outside the void edge on both floors.
	var cols: Array[Vector2] = []
	for p in OCT:
		cols.append(p * Vector2((absf(p.x) + 0.55) / absf(p.x), (absf(p.y) + 0.55) / absf(p.y)))
	for x in [-VX - 0.55, VX + 0.55]:
		for z in [-7.0, 7.0]:
			cols.append(Vector2(x, z))
	var xforms: Array[Transform3D] = []
	var k := 0
	for p in cols:
		for floor_y in [0.0, UP]:
			var h := (UP - SLAB) if floor_y == 0.0 else (CEIL - UP)
			_post(b, "Column%d" % k, 0.42, h, Vector3(p.x, floor_y, p.y))
			xforms.append(Transform3D(Basis().scaled(Vector3(1, h, 1)), Vector3(p.x, floor_y + h * 0.5, p.y)))
			k += 1
	_multimesh(dressing, "Columns", _cylinder_mesh(0.42, 1.0, "cream"), xforms)
	var rings: Array[Transform3D] = []
	for t in xforms:
		var base := t.origin - Vector3(0, t.basis.y.length() * 0.5, 0)
		rings.append(Transform3D(Basis(), base + Vector3(0, 0.15, 0)))
		rings.append(Transform3D(Basis(), base + Vector3(0, t.basis.y.length() - 0.2, 0)))
	_multimesh(dressing, "ColumnRings", _cylinder_mesh(0.5, 0.3, "chrome"), rings)
	_build_ceiling_lights()


func _rail(parent: Node3D, rail_name: String, a: Vector2, b: Vector2, floor_y: float) -> void:
	var e := b - a
	var length := e.length()
	var yaw := atan2(-e.y, e.x)
	var mid := (a + b) * 0.5
	var body := _collider(parent, rail_name, Vector3(length, RAIL_H, 0.16), Vector3(mid.x, floor_y + RAIL_H * 0.5, mid.y))
	body.rotation.y = yaw
	_bbox("glass", Vector3(length, RAIL_H - 0.15, 0.04), Vector3(mid.x, floor_y + (RAIL_H - 0.15) * 0.5 + 0.05, mid.y), yaw)
	_bbox("chrome", Vector3(length + 0.04, 0.08, 0.12), Vector3(mid.x, floor_y + RAIL_H, mid.y), yaw)
	_bbox("chrome", Vector3(length, 0.06, 0.08), Vector3(mid.x, floor_y + 0.05, mid.y), yaw)
	var posts := maxi(1, int(length / 2.0))
	for i in posts + 1:
		var p := a.lerp(b, float(i) / posts)
		_bbox("chrome", Vector3(0.06, RAIL_H, 0.06), Vector3(p.x, floor_y + RAIL_H * 0.5, p.y))


func _landing(parent: Node3D, landing_name: String, a: Vector2, b: Vector2) -> void:
	var size := Vector3(b.x - a.x, SLAB, b.y - a.y)
	var mid := Vector3((a.x + b.x) * 0.5, UP - SLAB * 0.5, (a.y + b.y) * 0.5)
	_collider(parent, landing_name, size, mid)
	_bbox("terrazzo_up", Vector3(size.x, 0.05, size.z), mid + Vector3(0, SLAB * 0.5 - 0.025, 0))
	_bbox("navy", Vector3(size.x, SLAB - 0.05, size.z), mid - Vector3(0, 0.025, 0))
	_bbox("neon_teal", Vector3(size.x + 0.02, 0.06, size.z + 0.02), mid - Vector3(0, SLAB * 0.5 - 0.12, 0))


## Round flush lights in the ceilings of both colonnades (one MultiMesh).
func _build_ceiling_lights() -> void:
	var xforms: Array[Transform3D] = []
	for ceiling_y in [UP - SLAB - 0.02, CEIL - 0.02]:
		for x in range(-21, 22, 6):
			for z in range(-27, 28, 6):
				var p := Vector2(x, z)
				if _in_void(p, 0.8):
					continue
				if absf(x) > HX or absf(z) > HZ:
					continue
				xforms.append(Transform3D(Basis(), Vector3(x, ceiling_y, z)))
	_multimesh(dressing, "CeilingLights", _cylinder_mesh(0.42, 0.05, "lamp"), xforms, false).add_to_group("mall_neon", true)


func _in_void(p: Vector2, margin := 0.0) -> bool:
	if absf(p.x) > VX + margin or absf(p.y) > VZ + margin:
		return false
	return absf(p.x) + absf(p.y) <= VX + VZ - VC + margin * 1.4


# ---------------------------------------------------------------------------
# The Starlight Dome: an eight-sided ribbed glass vault over the court
# ---------------------------------------------------------------------------

func _dome_point(i: float, v: float) -> Vector3:
	var n := OCT.size()
	var k := int(floorf(i)) % n
	var t := i - floorf(i)
	var p := OCT[k].lerp(OCT[(k + 1) % n], t)
	var e := v * PI * 0.5
	return Vector3(p.x * cos(e), DRUM + DOME_H * sin(e), p.y * cos(e))


func _build_dome() -> void:
	var dome := _node(dressing, "Dome")
	# Drum: a band of wall from the ceiling to the dome's springing, lettered.
	for i in OCT.size():
		var a := OCT[i]
		var b := OCT[(i + 1) % OCT.size()]
		var mid := (a + b) * 0.5
		var e := b - a
		var n := Vector2(e.y, -e.x).normalized()
		if n.dot(mid) < 0.0:
			n = -n
		var c := mid + n * 0.2
		_bbox("navy", Vector3(e.length() + 0.6, DRUM - CEIL + 0.3, 0.4), Vector3(c.x, (CEIL + DRUM) * 0.5 + 0.15, c.y), atan2(-e.y, e.x))
		_bbox("neon_violet", Vector3(e.length(), 0.08, 0.06), Vector3(mid.x + n.x * -0.02, DRUM - 0.1, mid.y + n.y * -0.02), atan2(-e.y, e.x))
	# Glass: one mesh, 8 sides x 6 rings.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 6
	var steps := 4
	for i in OCT.size() * steps:
		for r in rings:
			var p00 := _dome_point(float(i) / steps, float(r) / rings)
			var p10 := _dome_point(float(i + 1) / steps, float(r) / rings)
			var p01 := _dome_point(float(i) / steps, float(r + 1) / rings)
			var p11 := _dome_point(float(i + 1) / steps, float(r + 1) / rings)
			var n := (p10 - p00).cross(p01 - p00).normalized()
			if n.y < 0.0:
				n = -n
			_tri(st, p00, p10, p11, -n)
			_tri(st, p00, p11, p01, -n)
	var glass := MeshInstance3D.new()
	glass.name = "DomeGlass"
	glass.mesh = st.commit()
	glass.material_override = _m("dome_glass")
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.add_child(glass)
	# Ribs: meridians from every corner and edge midpoint, and the rings.
	var ribs: Array[Transform3D] = []
	for i in OCT.size() * 2:
		for r in rings:
			ribs.append(_beam(_dome_point(i * 0.5, float(r) / rings), _dome_point(i * 0.5, float(r + 1) / rings), 0.16))
	for r in range(1, rings):
		for i in OCT.size() * steps:
			ribs.append(_beam(_dome_point(float(i) / steps, float(r) / rings), _dome_point(float(i + 1) / steps, float(r) / rings), 0.1))
	for i in OCT.size() * steps:
		ribs.append(_beam(_dome_point(float(i) / steps, 0.0), _dome_point(float(i + 1) / steps, 0.0), 0.3))
	_multimesh(dome, "Ribs", _box_unit("navy"), ribs, false)
	# A crown lantern at the top.
	var crown := MeshInstance3D.new()
	crown.name = "Crown"
	crown.mesh = _cylinder_mesh(0.9, 0.5, "chrome")
	crown.position = Vector3(0, DRUM + DOME_H, 0)
	dome.add_child(crown)


## A beam (unit box scaled) from a to b with square section `thick`.
func _beam(a: Vector3, b: Vector3, thick: float) -> Transform3D:
	var d := b - a
	var basis := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.FORWARD)
	return Transform3D(Basis(basis.x * thick, basis.y * thick, basis.z * d.length()), (a + b) * 0.5)


# ---------------------------------------------------------------------------
# Escalators: east (working, rises north) and west (out of order, rises south)
# ---------------------------------------------------------------------------

func _build_escalators() -> void:
	var esc := _node(geo, "Escalators")
	_escalator(esc, "EscalatorEast", "mall_escalator", ESC_X, 12.0, -1.0)
	_escalator(esc, "EscalatorWest", "mall_escalator_dead", -ESC_X, -12.0, 1.0)


## An escalator whose foot is at z_foot, rising toward `dir` (-1 north, +1 south)
## 10 m to the upper floor: a solid wedge (walkway on top), kerbed sides.
func _escalator(parent: Node3D, esc_name: String, model: String, x: float, z_foot: float, dir: float) -> void:
	_prop(parent, model, esc_name + "Model", Vector3(x, 0, z_foot), 0.0 if dir < 0.0 else 180.0)
	var z_top := z_foot + dir * 10.0
	var pts := PackedVector3Array()
	for sx in [x - ESC_HALF, x + ESC_HALF]:
		pts.append(Vector3(sx, 0.0, z_foot))
		pts.append(Vector3(sx, 0.0, z_top))
		pts.append(Vector3(sx, UP, z_top))
	_convex(parent, esc_name + "Wedge", pts)
	for side in [-1.0, 1.0]:
		var x0: float = x + side * ESC_WALK
		var x1: float = x + side * (ESC_HALF + 0.05)
		var kerb := PackedVector3Array()
		# Taller than a mantle (1.25 m) above the walkway, so nobody climbs out.
		for sx in [x0, x1]:
			kerb.append(Vector3(sx, 0.0, z_foot - dir * 1.3))
			kerb.append(Vector3(sx, KERB_H, z_foot - dir * 1.3))
			kerb.append(Vector3(sx, KERB_H, z_foot))
			kerb.append(Vector3(sx, UP + KERB_H, z_top))
			kerb.append(Vector3(sx, UP, z_top))
			kerb.append(Vector3(sx, 0.0, z_top))
		_convex(parent, "%sKerb%d" % [esc_name, int(side)], kerb)


# ---------------------------------------------------------------------------
# Glass elevator: a tube from the court to the dome, the cab riding in it
# ---------------------------------------------------------------------------

func _build_elevator() -> void:
	var e := _node(geo, "Elevator")
	var shaft_h := DRUM + 1.0
	var body := _post(e, "ShaftCollision", 1.55, shaft_h, ELEVATOR)
	body.name = "ShaftCollision"
	var tube := MeshInstance3D.new()
	tube.name = "ShaftGlass"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.5
	cyl.bottom_radius = 1.5
	cyl.height = shaft_h
	cyl.radial_segments = 32
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.material = _m("glass")
	tube.mesh = cyl
	tube.position = ELEVATOR + Vector3(0, shaft_h * 0.5, 0)
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(tube)
	for i in 6:
		var a := TAU * i / 6.0
		_bbox("chrome", Vector3(0.12, shaft_h, 0.12), ELEVATOR + Vector3(cos(a) * 1.52, shaft_h * 0.5, sin(a) * 1.52))
	for y in [0.15, UP - 0.3, UP + 0.05, CEIL, shaft_h - 0.2]:
		var ring := MeshInstance3D.new()
		ring.name = "ShaftRing%d" % int(y * 10)
		var tor := TorusMesh.new()
		tor.inner_radius = 1.48
		tor.outer_radius = 1.68
		tor.rings = 32
		tor.ring_segments = 6
		tor.material = _m("neon_pink") if y > 1.0 and y < shaft_h - 1.0 else _m("chrome")
		ring.mesh = tor
		ring.position = ELEVATOR + Vector3(0, y, 0)
		dressing.add_child(ring)
	_bbox("chrome", Vector3(3.6, 0.3, 3.6), ELEVATOR + Vector3(0, 0.15, 0))
	# The bridge from the north balcony to the elevator's upper door.
	_collider(e, "Bridge", Vector3(2.0, SLAB, 0.7), Vector3(0, UP - SLAB * 0.5, -VZ + 0.15))
	_bbox("terrazzo_up", Vector3(2.0, 0.05, 0.7), Vector3(0, UP - 0.025, -VZ + 0.15))
	var cab := _prop(dressing, "mall_elevator_cab", "ElevatorCab", ELEVATOR + Vector3(0, 0.05, 0), 0.0)
	_late(cab, "res://scripts/props/mall_elevator.gd", {"low": 0.05, "high": UP + 0.05})


# ---------------------------------------------------------------------------
# The Moonfall Fountain
# ---------------------------------------------------------------------------

func _build_fountain() -> void:
	var f := _node(geo, "Fountain")
	var model := _prop(f, "mall_fountain", "FountainModel", FOUNTAIN, 20.0)
	model.add_to_group("mall_fountain", true)
	_post(f, "Basin", 4.15, 0.65, FOUNTAIN)
	_post(f, "Pedestal", 0.85, 3.4, FOUNTAIN)
	var blk := _player_block(f, "NoClimb", Vector3(8.4, 11.4, 8.4), FOUNTAIN + Vector3(0, 6.35, 0))
	blk.name = "FountainNoClimb"
	var light := _omni(lights, "FountainGlow", FOUNTAIN + Vector3(0, 2.0, 0), Color(1.0, 0.45, 0.85), 2.2, 10.0)
	light.add_to_group("mall_fountain_light", true)
	# A ring of benches facing the fountain.
	for a_deg in [55.0, 125.0]:
		var a := deg_to_rad(a_deg)
		var p := FOUNTAIN + Vector3(sin(a), 0, cos(a)) * 6.2
		_solid_multi("mall_bench", p, rad_to_deg(a), Vector3(2.3, 0.85, 0.7))


# ---------------------------------------------------------------------------
# Loadout station: Guest Services
# ---------------------------------------------------------------------------

func _build_station() -> void:
	var station: Node3D = (load("res://scenes/props/mall_station.tscn") as PackedScene).instantiate()
	station.name = "Station"
	geo.add_child(station)
	station.position = STATION
	_player_block(geo, "StationCap", Vector3(6.4, 8.0, 6.4), STATION + Vector3(0, 7.2, 0))


# ---------------------------------------------------------------------------
# Kiddie zone: the Galaxy Carousel and coin-op rides on a soft play mat
# ---------------------------------------------------------------------------

func _build_kiddie_zone() -> void:
	var z := _node(geo, "KiddieZone")
	var carousel := _prop(z, "mall_carousel", "Carousel", CAROUSEL, 0.0)
	_late(carousel.get_node("Spin"), "res://scripts/props/ambient_motion.gd", {"spin_degrees_per_second": 14.0})
	_post(z, "CarouselCollision", 3.15, 4.0, CAROUSEL)
	_player_block(z, "CarouselCap", Vector3(6.4, 8.0, 6.4), CAROUSEL + Vector3(0, 8.0, 0))
	var mat_mesh := MeshInstance3D.new()
	mat_mesh.name = "PlayMat"
	var disc := CylinderMesh.new()
	disc.top_radius = 5.0
	disc.bottom_radius = 5.0
	disc.height = 0.04
	disc.radial_segments = 48
	disc.material = _mat("play_mat", Color(0.36, 0.24, 0.62), 0.8)
	mat_mesh.mesh = disc
	mat_mesh.position = CAROUSEL + Vector3(0, 0.02, 0)
	dressing.add_child(mat_mesh)
	var rides := [["mall_kiddie_rocket", Vector3(-5.6, 0, 9.5), 30.0], ["mall_kiddie_car", Vector3(5.2, 0, 16.2), -150.0],
		["mall_kiddie_car", Vector3(-5.0, 0, 16.2), 160.0]]
	var k := 0
	for r in rides:
		_prop(z, r[0], "Ride%d" % k, r[1], r[2])
		_post(z, "Ride%dCollision" % k, 0.8, 1.6, r[1])
		k += 1


# ---------------------------------------------------------------------------
# Shop fronts: data-driven slots along the four shop-front lines, both floors
# ---------------------------------------------------------------------------

## [line, from, to, floor, kind, name, colour, interior]
##   line  W/E (x = -+HX, slot along z) or N/S (z = -+HZ, slot along x)
##   kind  shutter | half | window | open (the opening is built elsewhere)
const SLOTS := [
	["W", -24.0, -14.0, 0, "window", "STARDUST TOYS", "pink", "toys"],
	["W", -14.0, -2.0, 0, "half", "LUNA LINENS", "teal", "shelf"],
	["W", -2.0, 2.0, 0, "open", "STAFF ONLY", "amber", ""],
	["W", 2.0, 14.0, 0, "window", "NOVA FASHION", "violet", "fashion"],
	["W", 14.0, 24.0, 0, "shutter", "SATURN SPORTS", "orange", ""],
	["S", -18.0, -4.0, 0, "window", "STARLIGHT SHOES", "amber", "shelf"],
	["S", -4.0, 4.0, 0, "open", "MAIN ENTRANCE", "teal", ""],
	["S", 4.0, 18.0, 0, "window", "PLUSH PLANET", "mint", "toys"],
	["E", -24.0, -15.5, 0, "window", "BYTE BAZAAR", "teal", "tech"],
	["E", 15.5, 24.0, 0, "half", "SWEET ORBIT", "pink", "shelf"],
	["W", -24.0, -12.0, 1, "shutter", "RETRO RECORDS", "violet", ""],
	["W", -12.0, 0.0, 1, "window", "ROCKET ARCADE", "pink", "tech"],
	["W", 0.0, 12.0, 1, "half", "MOON BOOKS", "amber", "shelf"],
	["W", 12.0, 24.0, 1, "shutter", "COMET CAMERAS", "teal", ""],
	["E", -24.0, -12.0, 1, "window", "GADGET GALAXY", "teal", "tech"],
	["E", -12.0, 0.0, 1, "shutter", "PRISM PERFUME", "pink", ""],
	["E", 0.0, 12.0, 1, "window", "TEDDY TOWN", "amber", "toys"],
	["E", 12.0, 24.0, 1, "half", "VELVET VINYL", "violet", "shelf"],
	["N", -18.0, -6.0, 1, "shutter", "", "pink", ""],
	["N", -6.0, 6.0, 1, "shutter", "HALLEY & HART", "cream", ""],
	["N", 6.0, 18.0, 1, "shutter", "", "pink", ""],
	["S", -18.0, -6.0, 1, "half", "ASTRO ATHLETICS", "orange", "shelf"],
	["S", -6.0, 6.0, 1, "open", "", "violet", ""],
	["S", 6.0, 18.0, 1, "window", "COSMO COSMETICS", "pink", "fashion"],
]

const SIGN_COLORS := {"pink": PINK, "teal": TEAL, "amber": AMBER, "violet": VIOLET, "mint": MINT, "orange": ORANGE, "cream": CREAM}


## World frame of a slot: origin on the shop-front line at the slot's middle and
## floor, `along` running the slot's length, `inward` pointing into the shop.
func _slot_frame(line: String, a: float, b: float, floor_y: float) -> Array:
	var mid := (a + b) * 0.5
	match line:
		"W":
			return [Vector3(-HX, floor_y, mid), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
		"E":
			return [Vector3(HX, floor_y, mid), Vector3(0, 0, -1), Vector3(1, 0, 0)]
		"N":
			return [Vector3(mid, floor_y, -HZ), Vector3(-1, 0, 0), Vector3(0, 0, -1)]
	return [Vector3(mid, floor_y, HZ), Vector3(1, 0, 0), Vector3(0, 0, 1)]


func _depth(line: String) -> float:
	return (X1 - HX) if line == "W" or line == "E" else (Z1 - HZ)


func _build_shopfronts() -> void:
	var fronts := _node(geo, "ShopFronts")
	var k := 0
	for s in SLOTS:
		_shopfront(fronts, k, s)
		k += 1
	# Party walls between neighbouring shops (both floors), so lit interiors
	# never look into each other.
	var walls := [["W", -24.0, [0, 1]], ["W", -14.0, [0]], ["W", -2.0, [0]], ["W", 2.0, [0]], ["W", 14.0, [0]], ["W", -12.0, [1]],
		["W", 0.0, [1]], ["W", 12.0, [1]], ["W", 24.0, [0, 1]], ["E", -24.0, [0, 1]], ["E", -15.5, [0]], ["E", 15.5, [0]],
		["E", -12.0, [1]], ["E", 0.0, [1]], ["E", 12.0, [1]], ["E", 24.0, [0, 1]], ["S", -18.0, [0, 1]], ["S", -4.0, [0]],
		["S", 4.0, [0]], ["S", 18.0, [0, 1]], ["S", -6.0, [1]], ["S", 6.0, [1]], ["N", -18.0, [0, 1]], ["N", 18.0, [0, 1]]]
	for w in walls:
		for fl in w[2]:
			var floor_y := UP * float(fl)
			var line: String = w[0]
			var at: float = w[1]
			var depth := _depth(line)
			var h := (UP - SLAB) if floor_y == 0.0 else (CEIL - UP)
			var f := _slot_frame(line, at, at, floor_y)
			var c: Vector3 = f[0] + f[2] * depth * 0.5 + Vector3(0, h * 0.5, 0)
			var size := Vector3(depth, h, 0.3) if line == "W" or line == "E" else Vector3(0.3, h, depth)
			_bbox("wall", size, c)
			_collider(fronts, "Party%d" % k, size, c)
			k += 1


func _shopfront(parent: Node3D, index: int, s: Array) -> void:
	var line: String = s[0]
	var a: float = s[1]
	var b: float = s[2]
	var floor_y: float = UP * float(s[3])
	var kind: String = s[4]
	var title: String = s[5]
	var colour: Color = SIGN_COLORS[s[6]]
	var f := _slot_frame(line, a, b, floor_y)
	var o: Vector3 = f[0]
	var along: Vector3 = f[1]
	var inward: Vector3 = f[2]
	var width := b - a
	var storey := (UP - SLAB) if floor_y == 0.0 else (CEIL - UP)
	var yaw := atan2(-inward.x, -inward.z)
	# Pilasters at both ends, the fascia band over the opening.
	for e in [-1.0, 1.0]:
		var p: Vector3 = o + along * e * (width * 0.5 - 0.3) + Vector3(0, storey * 0.5, 0)
		_bbox("cream", Vector3(0.6, storey, 0.6), p, yaw)
		_bbox("chrome", Vector3(0.64, 0.25, 0.64), p - Vector3(0, storey * 0.5 - 0.125, 0), yaw)
		_collider(parent, "Pilaster%d%d" % [index, int(e)], Vector3(0.6, storey, 0.6), p).rotation.y = yaw
	var fascia_h := storey - OPEN_H
	var fascia_c: Vector3 = o + Vector3(0, OPEN_H + fascia_h * 0.5, 0) - inward * 0.05
	_bbox("navy", Vector3(width - 1.2, fascia_h, 0.5), fascia_c, yaw)
	_bbox("neon_" + _neon_key(colour), Vector3(width - 1.2, 0.06, 0.06), o + Vector3(0, OPEN_H + 0.05, 0) - inward * 0.32, yaw)
	if title != "":
		var sign_y := OPEN_H + fascia_h * (0.5 if floor_y == 0.0 else 0.32)
		var pixel := minf(0.0075, (width - 2.0) / (title.length() * 80.0))
		_label(signs, "Sign%d" % index, title, o + Vector3(0, sign_y, 0) - inward * 0.32, yaw, pixel, colour * 1.6)
	if kind == "open":
		# Solid above the opening, so nothing climbs over the doorway.
		_collider(parent, "Fascia%d" % index, Vector3(width - 1.2, fascia_h, 0.5), fascia_c).rotation.y = yaw
		return
	# The opening: shutter, half shutter or glass.
	var opening := Vector3(width - 1.2, OPEN_H, 0.12)
	var block := _collider(parent, "Front%d" % index, Vector3(width - 1.2, storey, 0.3), o + Vector3(0, storey * 0.5, 0))
	block.rotation.y = yaw
	match kind:
		"shutter":
			_bbox("shutter", opening, o + Vector3(0, OPEN_H * 0.5, 0) + inward * 0.05, yaw)
			_bbox("chrome", Vector3(width - 1.2, 0.12, 0.2), o + Vector3(0, 0.06, 0) + inward * 0.05, yaw)
			return
		"half":
			var top := 1.5
			_bbox("shutter", Vector3(width - 1.2, OPEN_H - top, 0.12), o + Vector3(0, (OPEN_H + top) * 0.5, 0) + inward * 0.05, yaw)
			_bbox("chrome", Vector3(width - 1.2, 0.14, 0.2), o + Vector3(0, top + 0.07, 0) + inward * 0.05, yaw)
		"window":
			_bbox("glass", opening, o + Vector3(0, OPEN_H * 0.5, 0), yaw)
			var mullions := int(width / 3.0)
			for i in mullions + 1:
				var p: Vector3 = o + along * (-(width - 1.2) * 0.5 + (width - 1.2) * i / maxf(1.0, mullions)) + Vector3(0, OPEN_H * 0.5, 0)
				_bbox("chrome", Vector3(0.08, OPEN_H, 0.1), p, yaw)
			_bbox("chrome", Vector3(width - 1.2, 0.1, 0.14), o + Vector3(0, 0.05, 0), yaw)
	_interior(index, s, o, along, inward, width, storey, yaw)


func _neon_key(c: Color) -> String:
	if c == TEAL or c == MINT:
		return "teal"
	if c == AMBER or c == ORANGE or c == CREAM:
		return "amber"
	if c == VIOLET:
		return "violet"
	return "pink"


## A lit shop interior behind a window or a half shutter: tinted back wall and
## floor, a glowing ceiling panel, and fittings for its trade.
func _interior(index: int, s: Array, o: Vector3, along: Vector3, inward: Vector3, width: float, storey: float, yaw: float) -> void:
	var depth := _depth(s[0])
	var tint := "interior_warm"
	match s[6]:
		"teal", "mint":
			tint = "interior_cool"
		"pink", "violet":
			tint = "interior_pink"
	_bbox(tint, Vector3(width - 0.4, storey, 0.1), o + inward * (depth - 0.1) + Vector3(0, storey * 0.5, 0), yaw)
	_bbox(tint, Vector3(width - 0.4, 0.04, depth - 0.4), o + inward * (depth * 0.5 + 0.1) + Vector3(0, 0.02, 0), yaw)
	_bbox("panel_light", Vector3(width - 2.0, 0.06, depth - 2.0), o + inward * depth * 0.5 + Vector3(0, storey - 0.08, 0), yaw)
	var r := RandomNumberGenerator.new()
	r.seed = index * 31 + 7
	var props := _node(dressing, "Shop%d" % index)
	var trade: String = s[7]
	var deg := rad_to_deg(yaw)
	match trade:
		"toys":
			_prop(props, "mall_display_toys", "Window", o + inward * 1.2, deg)
			_prop(props, "mall_shelf", "ShelfA", o + inward * (depth - 0.6) + along * (-width * 0.25), deg)
			_prop(props, "mall_shelf", "ShelfB", o + inward * (depth - 0.6) + along * (width * 0.25), deg)
		"tech":
			_prop(props, "mall_display_tech", "Window", o + inward * 1.2 + along * (-width * 0.2), deg)
			_prop(props, "mall_display_tech", "WindowB", o + inward * (depth - 0.8) + along * (width * 0.2), deg)
		"fashion":
			_prop(props, "mall_mannequins", "Window", o + inward * 1.3 + along * (-width * 0.18), deg)
			_prop(props, "mall_mannequins", "WindowB", o + inward * 1.6 + along * (width * 0.22), deg + 15.0)
			_prop(props, "mall_shelf", "Shelf", o + inward * (depth - 0.6), deg)
		_:
			for i in 3:
				_prop(props, "mall_shelf", "Shelf%d" % i, o + inward * (depth - 0.6) + along * (-width * 0.3 + width * 0.3 * i), deg)
			_prop(props, "mall_shelf", "Gondola", o + inward * 2.4 + along * r.randf_range(-1.0, 1.0), deg + 180.0)


# ---------------------------------------------------------------------------
# Food court: stalls along the east line, the kitchen door, tables
# ---------------------------------------------------------------------------

const STALLS := [[-12.5, "NOODLE ORBIT", "teal"], [-6.5, "TACO COMET", "orange"], [6.5, "BOBA MOON", "pink"], [12.5, "BURGER BLAST", "amber"]]


func _build_food_court() -> void:
	var fc := _node(geo, "FoodCourt")
	for s in STALLS:
		var z: float = s[0]
		var colour: Color = SIGN_COLORS[s[2]]
		var stall := _prop(fc, "mall_stall", "Stall%d" % int(z), Vector3(HX + 3.0, 0, z), -90.0)
		stall.name = "Stall%d" % int(z)
		_recolor(stall, "MallAccent", _mat("stall_" + s[2], colour.darkened(0.15), 0.5))
		_recolor(stall, "MallNeonAccent", _glow("stall_neon_" + s[2], colour, 2.8))
		_collider(fc, "Stall%dCounter" % int(z), Vector3(1.9, 1.1, 5.4), Vector3(HX + 1.85, 0.55, z))
		_collider(fc, "Stall%dBack" % int(z), Vector3(4.0, 4.4, 6.0), Vector3(HX + 4.8, 2.2, z))
		_label(signs, "StallSign%d" % int(z), s[1], Vector3(HX + 0.72, 3.98, z), -PI * 0.5, 0.006, colour * 1.7)
		_omni(lights, "Stall%d" % int(z), Vector3(HX + 1.0, 3.0, z), colour.lerp(WARM, 0.4), 1.3, 6.5).add_to_group("mall_mains", true)
	# Walls either side of the kitchen door (z -1.5..1.5) and the fascia above.
	for zz in [[-3.5, -1.5], [1.5, 3.5]]:
		var c := Vector3(HX + 0.15, (UP - SLAB) * 0.5, (zz[0] + zz[1]) * 0.5)
		var size := Vector3(0.3, UP - SLAB, zz[1] - zz[0])
		_bbox("wall", size, c)
		_collider(fc, "KitchenWall%d" % int(zz[0]), size, c)
	_bbox("wall", Vector3(0.3, UP - SLAB - 3.0, 3.0), Vector3(HX + 0.15, 3.0 + (UP - SLAB - 3.0) * 0.5, 0))
	_label(signs, "FoodCourtSign", "FOOD COURT", Vector3(HX - 0.05, 3.95, 0), -PI * 0.5, 0.0055, PINK * 1.8)
	# Tables (cover) between the stalls and the court.
	var tables := [Vector3(12.5, 0, -14.0), Vector3(15.2, 0, -9.5), Vector3(12.4, 0, -5.0), Vector3(15.0, 0, -0.5),
		Vector3(12.6, 0, 4.5), Vector3(15.2, 0, 8.8), Vector3(12.4, 0, 13.4), Vector3(15.6, 0, 16.6)]
	var k := 0
	for p in tables:
		_multi_add("mall_table_set", p, k * 37.0)
		_post(fc, "Table%d" % k, 1.25, 0.95, p)
		k += 1
	# Bins at the ends of the stall row.
	for p in [Vector3(16.9, 0, -17.0), Vector3(16.9, 0, 17.6), Vector3(17.0, 0, -3.0)]:
		_solid_multi("mall_bin", p, 0.0, Vector3(0.66, 1.0, 0.66), true)


# ---------------------------------------------------------------------------
# Department store (north, ground floor): window displays and the entrance
# under its half-raised shutter (zombie entrance)
# ---------------------------------------------------------------------------

func _build_department_store() -> void:
	var d := _node(geo, "DepartmentStore")
	var storey := UP - SLAB
	# Frontage x -18..18 at z = -24: two display windows, the 12 m entrance.
	for w in [[-18.0, -6.0], [6.0, 18.0]]:
		var s := ["N", w[0], w[1], 0, "window", "", "cream", "fashion"]
		_shopfront(d, 100 + int(w[0]), s)
		_bbox("wall", Vector3(0.3, storey, 3.0), Vector3(-6.15 if w[0] < 0.0 else 6.15, storey * 0.5, -HZ - 1.5))
	# Entrance pilasters and the big sign band above it.
	for x in [-6.0, 6.0]:
		_bbox("cream", Vector3(0.8, storey, 0.8), Vector3(x, storey * 0.5, -HZ))
		_collider(d, "EntrancePier%d" % int(x), Vector3(0.8, storey, 0.8), Vector3(x, storey * 0.5, -HZ))
	# The half-raised shutter: zombies duck out under its 2.9 m edge.
	_bbox("shutter", Vector3(11.2, storey - 2.9, 0.12), Vector3(0, (storey + 2.9) * 0.5, -HZ - 0.1))
	_bbox("chrome", Vector3(11.2, 0.15, 0.22), Vector3(0, 2.95, -HZ - 0.1))
	_label(signs, "DeptSignLow", "HALLEY & HART", Vector3(0, 3.62, -HZ + 0.1), 0.0, 0.009, CREAM * 1.6)
	# Interior: cosmetics counters, clothing racks, mannequins, a lit back wall.
	_bbox("interior_warm", Vector3(12.0, storey, 0.1), Vector3(0, storey * 0.5, Z0 + 0.1))
	_bbox("panel_light", Vector3(10.0, 0.06, 3.0), Vector3(0, storey - 0.1, -27.0))
	_bbox("panel_light", Vector3(6.0, 0.06, 2.0), Vector3(-12.0, storey - 0.1, -27.0))
	_bbox("panel_light", Vector3(6.0, 0.06, 2.0), Vector3(12.0, storey - 0.1, -27.0))
	_bbox("interior_pink", Vector3(12.0, 0.04, 5.6), Vector3(0, 0.02, -27.0))
	for x in [-8.5, 8.5]:
		_bbox("cream", Vector3(3.0, 1.0, 0.8), Vector3(x, 0.5, -26.6))
		_bbox("glass", Vector3(3.0, 0.25, 0.8), Vector3(x, 1.12, -26.6))
		_collider(d, "Counter%d" % int(x), Vector3(3.0, 1.2, 0.8), Vector3(x, 0.6, -26.6))
	for x in [-3.6, 3.6]:
		_prop(dressing, "mall_mannequins", "DeptMannequins%d" % int(x), Vector3(x, 0, -28.6), 0.0)
		_collider(d, "DeptPlinth%d" % int(x), Vector3(2.2, 1.0, 1.0), Vector3(x, 0.5, -28.6))
	# Clothing racks by the entrance.
	var garments := ["pink", "teal", "violet", "cream", "navy"]
	for x in [-4.2, 4.2]:
		var c := Vector3(x, 0, -25.9)
		_bbox("chrome", Vector3(2.4, 0.06, 0.06), c + Vector3(0, 1.55, 0))
		for e in [-1.15, 1.15]:
			_bbox("chrome", Vector3(0.06, 1.55, 0.06), c + Vector3(e, 0.78, 0))
			_bbox("chrome", Vector3(0.1, 0.04, 0.6), c + Vector3(e, 0.02, 0))
		for i in 8:
			_bbox(garments[(i + int(x)) % garments.size()], Vector3(0.22, 0.8, 0.5), c + Vector3(-0.95 + i * 0.27, 1.1, 0))
		_collider(d, "Rack%d" % int(x), Vector3(2.5, 1.6, 0.6), c + Vector3(0, 0.8, 0))
	_omni(lights, "DeptStore", Vector3(0, 3.2, -27.0), WARM, 1.6, 10.0).add_to_group("mall_mains", true)


# ---------------------------------------------------------------------------
# Entrances: main vestibule (S), staff corridor (W), kitchen (E), cinema (S, up)
# ---------------------------------------------------------------------------

func _build_entrances() -> void:
	var e := _node(geo, "Entrances")
	var storey := UP - SLAB
	# Main entrance vestibule x -4..4, z 24..30: side walls, a lower ceiling,
	# the security gates and the glass outer doors onto the car park.
	_bbox("ceiling", Vector3(8.0, 0.2, 6.0), Vector3(0, 3.6, 27.0))
	_bbox("panel_light", Vector3(5.0, 0.04, 3.0), Vector3(0, 3.48, 27.0))
	_prop(e, "mall_security_gate", "SecurityGate", Vector3(0, 0, HZ - 0.6), 0.0)
	for x in [-1.3, 1.3]:
		_collider(e, "Gate%d" % int(x * 10), Vector3(0.2, 1.6, 0.5), Vector3(x, 0.8, HZ - 0.6))
	_collider(e, "OuterDoors", Vector3(8.0, storey, 0.3), Vector3(0, storey * 0.5, Z1 - 0.4))
	_bbox("glass", Vector3(7.4, 3.4, 0.06), Vector3(0, 1.7, Z1 - 0.4))
	for x in [-3.7, -1.85, 0.0, 1.85, 3.7]:
		_bbox("chrome", Vector3(0.1, 3.4, 0.14), Vector3(x, 1.7, Z1 - 0.4))
	_bbox("chrome", Vector3(7.4, 0.12, 0.16), Vector3(0, 3.42, Z1 - 0.4))
	_bbox("navy", Vector3(4.0, 0.03, 2.4), Vector3(0, 0.015, Z1 - 2.0))
	# Lit welcome posters on the vestibule walls.
	for x in [-3.8, 3.8]:
		_bbox("chrome", Vector3(0.1, 1.9, 1.4), Vector3(x, 1.6, 26.6))
		_bbox("panel_light", Vector3(0.04, 1.7, 1.2), Vector3(x - signf(x) * 0.06, 1.6, 26.6))
		_label(signs, "Poster%d" % int(x), "OPEN\nLATE\n10-9", Vector3(x - signf(x) * 0.1, 1.65, 26.6), -signf(x) * PI * 0.5, 0.0032,
			PINK * 1.2 if x < 0.0 else VIOLET * 1.2)
	_label(signs, "Closed", "CLOSED\nSEE YOU TOMORROW!", Vector3(0, 2.3, Z1 - 0.48), PI, 0.0028, CREAM * 1.4)
	# The night outside: a car park with lamp posts and a sliver of the sky.
	_build_outside()
	# Staff corridor (W, ground): x -24..-18, z -2..2.
	_bbox("wall_dark", Vector3(6.0, 0.05, 4.0), Vector3(-21.0, 0.025, 0))
	_bbox("ceiling", Vector3(6.0, 0.2, 4.0), Vector3(-21.0, 3.2, 0))
	_bbox("panel_light", Vector3(0.3, 0.05, 3.0), Vector3(-21.0, 3.08, 0))
	_bbox("wall_dark", Vector3(1.8, 2.6, 0.2), Vector3(-22.0, 1.3, -1.8))
	_omni(lights, "Corridor", Vector3(-21.0, 2.6, 0), Color(0.75, 1.0, 0.85), 1.2, 6.0).add_to_group("mall_mains", true)
	# Kitchen behind the food court (E, ground): x 18..24, z -3.5..3.5.
	_bbox("interior_warm", Vector3(6.0, 0.05, 7.0), Vector3(21.0, 0.025, 0))
	_bbox("ceiling", Vector3(6.0, 0.2, 7.0), Vector3(21.0, 3.1, 0))
	_bbox("chrome", Vector3(1.0, 1.0, 4.0), Vector3(23.4, 0.5, 0))
	_collider(e, "KitchenCounter", Vector3(1.0, 1.0, 4.0), Vector3(23.4, 0.5, 0))
	_bbox("chrome", Vector3(1.2, 0.6, 3.0), Vector3(23.3, 2.6, 0))
	_label(signs, "KitchenSign", "KITCHEN", Vector3(HX - 0.04, 3.25, 0), -PI * 0.5, 0.003, AMBER * 1.4)
	_omni(lights, "Kitchen", Vector3(21.0, 2.6, 0), WARM, 1.2, 6.0).add_to_group("mall_mains", true)
	# Starplex cinema lobby (S, upper floor): x -6..6, z 24..30.
	_prop(e, "mall_cinema_doors", "CinemaDoors", Vector3(0, UP, HZ + 0.2), 180.0)
	for x in [-2.75, 2.75]:
		_collider(e, "CinemaWall%d" % int(x), Vector3(2.3, 4.6, 0.4), Vector3(x, UP + 2.3, HZ + 0.2))
	_collider(e, "CinemaLintel", Vector3(3.2, 2.0, 0.4), Vector3(0, UP + 4.0, HZ + 0.2))
	_bbox("violet", Vector3(12.0, 0.05, 5.6), Vector3(0, UP + 0.025, 27.2))
	_bbox("interior_pink", Vector3(12.0, CEIL - UP, 0.1), Vector3(0, UP + (CEIL - UP) * 0.5, Z1 - 0.1))
	_bbox("panel_light", Vector3(6.0, 0.05, 3.0), Vector3(0, CEIL - 0.1, 27.2))
	_label(signs, "CinemaSign", "STARPLEX 8", Vector3(0, UP + 3.35, HZ - 1.25), PI, 0.0075, VIOLET * 1.9)
	_omni(lights, "Cinema", Vector3(0, UP + 3.0, 27.0), VIOLET.lerp(WARM, 0.3), 1.4, 8.0).add_to_group("mall_mains", true)


func _build_outside() -> void:
	var out := _node(dressing, "Outside")
	var ground := MeshInstance3D.new()
	ground.name = "CarPark"
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 120)
	plane.material = _mat("asphalt", Color(0.09, 0.09, 0.14), 0.85)
	ground.mesh = plane
	ground.position = Vector3(0, -0.02, Z1 + 60.0)
	out.add_child(ground)
	var bays: Array[Transform3D] = []
	for row in [14.0, 26.0]:
		for i in 12:
			bays.append(Transform3D(Basis().scaled(Vector3(0.12, 0.02, 4.5)), Vector3(-16.5 + i * 3.0, 0.0, Z1 + row)))
	_multimesh(out, "BayLines", _box_unit("cream"), bays, false)
	for p in [Vector3(-9, 0, Z1 + 20), Vector3(9, 0, Z1 + 20), Vector3(-22, 0, Z1 + 34), Vector3(22, 0, Z1 + 34), Vector3(0, 0, Z1 + 44)]:
		var pole := MeshInstance3D.new()
		pole.name = "LampPost%d" % int(p.x)
		pole.mesh = _cylinder_mesh(0.12, 7.0, "navy")
		pole.position = p + Vector3(0, 3.5, 0)
		out.add_child(pole)
		var head := MeshInstance3D.new()
		head.name = "LampHead%d" % int(p.x)
		head.mesh = _cylinder_mesh(0.45, 0.25, "neon_amber")
		head.position = p + Vector3(0, 7.0, 0)
		out.add_child(head)
	var wall := MeshInstance3D.new()
	wall.name = "TreeLine"
	var bx := BoxMesh.new()
	bx.size = Vector3(160, 6, 2)
	bx.material = _mat("treeline", Color(0.05, 0.08, 0.12), 0.9)
	wall.mesh = bx
	wall.position = Vector3(0, 3.0, Z1 + 70.0)
	out.add_child(wall)
	_omni(lights, "CarParkLamp", Vector3(0, 6.0, Z1 + 16.0), AMBER, 1.4, 14.0)


# ---------------------------------------------------------------------------
# Hall dressing: palms, benches, carts, directories, bins
# ---------------------------------------------------------------------------

func _build_hall_dressing() -> void:
	var d := _node(geo, "HallDressing")
	# Palms in planters (cover): ground colonnades and the upper balconies.
	var palms := [Vector3(-14.0, 0, -20.5), Vector3(-14.0, 0, 20.5), Vector3(14.0, 0, 21.0), Vector3(-14.6, 0, -8.0),
		Vector3(-14.6, 0, 8.0), Vector3(6.0, 0, -21.0), Vector3(-6.5, 0, 21.0), Vector3(6.5, 0, 21.0),
		Vector3(-14.0, UP, -21.0), Vector3(14.0, UP, 21.0), Vector3(-14.5, UP, 6.0), Vector3(14.5, UP, -6.0),
		Vector3(-6.0, UP, 21.5), Vector3(-5.0, UP, -21.5)]
	var k := 0
	for p in palms:
		_multi_add("mall_palm", p, k * 41.0)
		_post(d, "Palm%d" % k, 1.0, 0.85, p)
		_player_block(d, "Palm%dCap" % k, Vector3(2.0, 3.0, 2.0), p + Vector3(0, 2.4, 0))
		k += 1
	# Benches back to back with the columns and along the balconies.
	var benches := [[Vector3(-15.8, 0, -3.0), 90.0], [Vector3(-15.8, 0, 3.5), 90.0], [Vector3(-12.0, 0, -21.6), 0.0],
		[Vector3(3.5, 0, 21.8), 180.0], [Vector3(-12.0, UP, -12.0), 90.0], [Vector3(12.0, UP, 12.0), -90.0],
		[Vector3(-12.2, UP, 12.5), 90.0], [Vector3(10.0, UP, 21.8), 180.0], [Vector3(15.8, UP, -3.0), -90.0]]
	for b in benches:
		_solid_multi("mall_bench", b[0], b[1], Vector3(2.3, 0.85, 0.7))
	# Retail carts (big cover pieces) in the colonnades.
	var carts := [[Vector3(-14.0, 0, -14.0), 90.0, PINK], [Vector3(-13.8, 0, 14.0), 90.0, TEAL], [Vector3(-8.0, 0, -21.0), 0.0, VIOLET],
		[Vector3(-11.5, 0, 20.6), 0.0, AMBER], [Vector3(14.0, UP, -14.0), 90.0, TEAL], [Vector3(-14.0, UP, 15.0), 90.0, PINK]]
	k = 0
	for c in carts:
		var cart := _prop(d, "mall_cart", "Cart%d" % k, c[0], c[1])
		_recolor(cart, "MallAccent", _mat("cart_%d" % k, (c[2] as Color).darkened(0.1), 0.5))
		_collider(d, "Cart%dCollision" % k, Vector3(2.3, 1.15, 1.1), (c[0] as Vector3) + Vector3(0, 0.575, 0)).rotation.y = deg_to_rad(c[1])
		_player_block(d, "Cart%dCap" % k, Vector3(2.4, 1.6, 1.4), (c[0] as Vector3) + Vector3(0, 1.95, 0), deg_to_rad(c[1]))
		k += 1
	for p in [[Vector3(-11.8, 0, 17.0), 45.0], [Vector3(14.6, UP, 9.0), -90.0], [Vector3(11.6, 0, -18.6), -45.0]]:
		_prop(d, "mall_directory", "Directory%d" % int(p[0].x), p[0], p[1])
		_collider(d, "Directory%dCollision" % int(p[0].x), Vector3(1.3, 2.4, 0.4), (p[0] as Vector3) + Vector3(0, 1.2, 0)).rotation.y = deg_to_rad(p[1])
	for p in [Vector3(-11.2, 0, -10.8), Vector3(11.2, 0, 19.0), Vector3(-11.0, UP, -16.5), Vector3(11.0, UP, 16.5), Vector3(-16.6, UP, 0.0)]:
		_solid_multi("mall_bin", p, 0.0, Vector3(0.66, 1.0, 0.66), true)
	# Emergency lamps and exit boxes over the doors (the power cut wakes them).
	var em := [[Vector3(0, 3.0, HZ - 0.32), 180.0], [Vector3(-HX + 0.35, 3.3, 3.0), 90.0], [Vector3(HX - 0.35, 3.3, 2.5), -90.0],
		[Vector3(9.0, UP + 3.5, -HZ + 0.35), 0.0], [Vector3(0, 2.6, -HZ + 0.45), 0.0], [Vector3(-9.0, UP + 3.5, HZ - 0.35), 180.0],
		[Vector3(-HX + 0.35, UP + 3.4, -6.0), 90.0], [Vector3(HX - 0.35, UP + 3.4, 6.0), -90.0]]
	k = 0
	for e in em:
		_prop(dressing, "mall_emergency_light", "Emergency%d" % k, e[0], e[1])
		var l := _omni(lights, "EmergencyLight%d" % k, (e[0] as Vector3) + Vector3(0, -0.4, 0) + Basis(Vector3.UP, deg_to_rad(e[1])) * Vector3(0, 0, 0.8),
			Color(1.0, 0.18, 0.15), 0.0, 9.0)
		l.add_to_group("mall_emergency", true)
		l.visible = false
		k += 1
	for e in [[Vector3(-3.0, 3.9, HZ - 0.3), 180.0], [Vector3(3.0, 3.9, HZ - 0.3), 180.0], [Vector3(-HX + 0.3, 3.0, -1.4), 90.0],
			[Vector3(HX - 0.3, 3.0, 2.0), -90.0], [Vector3(-4.0, UP + 4.6, HZ - 0.3), 180.0]]:
		_prop(dressing, "mall_exit_sign", "ExitBox%d" % int(e[0].x * 10 + e[0].z), e[0], e[1])


## Long sale banners hanging from the drum into the court.
func _build_banners() -> void:
	var texts := [["MIDNIGHT\nMADNESS", PINK, Vector3(-6.5, 0, -16.0)], ["EVERYTHING\nMUST GO", TEAL, Vector3(6.5, 0, 16.0)],
		["OPEN\nLATE", VIOLET, Vector3(-9.0, 0, 6.0)], ["SALE\n50%", AMBER, Vector3(9.0, 0, -6.0)]]
	var k := 0
	for t in texts:
		var p: Vector3 = t[2]
		var yaw := 0.0 if absf(p.z) > 12.0 else PI * 0.5
		var top := DRUM - 0.3
		var c := Vector3(p.x, top - 2.4, p.z)
		_bbox("navy", Vector3(2.0, 4.6, 0.06), c, yaw)
		_bbox("chrome", Vector3(2.3, 0.1, 0.1), Vector3(p.x, top, p.z), yaw)
		_bbox("chrome", Vector3(2.3, 0.1, 0.1), c - Vector3(0, 2.3, 0), yaw)
		var face := Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.05)
		_label(signs, "BannerA%d" % k, t[0], c + face, yaw, 0.0062, (t[1] as Color) * 1.5)
		_label(signs, "BannerB%d" % k, t[0], c - face, yaw + PI, 0.0062, (t[1] as Color) * 1.5)
		k += 1
	_label(signs, "DrumNorth", "MOONBEAM GALLERIA", Vector3(0, CEIL + 0.85, -VZ + 0.05), 0.0, 0.0125, CREAM * 1.6)
	_label(signs, "DrumSouth", "MOONBEAM GALLERIA", Vector3(0, CEIL + 0.85, VZ - 0.05), PI, 0.0125, CREAM * 1.6)


# ---------------------------------------------------------------------------
# Lights: warm pools in the colonnades, coloured accents, no shadows
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	var lamps := [
		[Vector3(-14.0, 3.6, -14.0), WARM], [Vector3(-14.0, 3.6, 0.0), WARM], [Vector3(-14.0, 3.6, 14.0), WARM],
		[Vector3(14.0, 3.6, -12.0), WARM], [Vector3(14.0, 3.6, 0.0), Color(1.0, 0.6, 0.8)], [Vector3(14.0, 3.6, 12.0), WARM],
		[Vector3(-8.0, 3.6, -21.0), WARM], [Vector3(8.0, 3.6, -21.0), Color(0.7, 0.85, 1.0)],
		[Vector3(-8.0, 3.6, 21.0), WARM], [Vector3(8.0, 3.6, 21.0), Color(0.75, 1.0, 0.92)], [Vector3(0.0, 3.4, 27.0), Color(0.8, 0.9, 1.0)],
		[Vector3(-14.0, UP + 4.2, -13.0), Color(0.9, 0.75, 1.0)], [Vector3(-14.0, UP + 4.2, 4.0), WARM], [Vector3(-14.0, UP + 4.2, 18.0), WARM],
		[Vector3(14.0, UP + 4.2, -16.0), WARM], [Vector3(14.0, UP + 4.2, -2.0), Color(0.75, 0.95, 1.0)], [Vector3(14.0, UP + 4.2, 13.0), WARM],
		[Vector3(-4.0, UP + 4.2, -21.0), WARM], [Vector3(4.0, UP + 4.2, 21.0), WARM],
	]
	var k := 0
	for l in lamps:
		_omni(lights, "Hall%02d" % k, l[0], l[1], 1.25, 10.5).add_to_group("mall_mains", true)
		k += 1
	_omni(lights, "StationWarm", STATION + Vector3(0, 2.6, 0), Color(1.0, 0.75, 0.5), 1.4, 7.5).add_to_group("mall_mains", true)
	_omni(lights, "CarouselWarm", CAROUSEL + Vector3(0, 3.0, 0), Color(1.0, 0.7, 0.6), 1.5, 8.0).add_to_group("mall_mains", true)
	_omni(lights, "CourtFill", Vector3(0, 9.0, 0), Color(0.55, 0.6, 1.0), 1.0, 16.0).add_to_group("mall_mains", true)
	_omni(lights, "ElevatorGlow", ELEVATOR + Vector3(0, 6.0, 1.8), PINK, 1.2, 7.0).add_to_group("mall_mains", true)


func _omni(parent: Node3D, light_name: String, pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = light_name
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	parent.add_child(l)
	_light_count += 1
	return l


# ---------------------------------------------------------------------------
# Exit: portal on the north balcony; lights chase up the east escalator
# ---------------------------------------------------------------------------

func _build_exit() -> void:
	var portal: Node3D = (load("res://scenes/props/mall_portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	geo.add_child(portal)
	portal.position = PORTAL
	var route: Array[Vector3] = [STATION + Vector3(3.6, 0, 3.0), Vector3(5.0, 0, 14.6), Vector3(ESC_X, 0, 14.6)]
	for i in 6:
		var t := (i + 0.5) / 6.0
		route.append(Vector3(ESC_X, UP * t, 12.0 - 10.0 * t))
	route.append_array([Vector3(ESC_X + 0.5, UP, 0.0), Vector3(13.5, UP, -2.0), Vector3(14.0, UP, -8.0), Vector3(14.0, UP, -14.0),
		Vector3(13.0, UP, -19.0), Vector3(PORTAL.x, UP, PORTAL.z + 2.4)])
	var holder := _node(level, "ExitLights")
	var mesh := _chevron_mesh()
	var order := 0
	for i in route.size() - 1:
		var a := route[i]
		var b := route[i + 1]
		var steps := maxi(1, int(a.distance_to(b) / 2.2))
		for s in steps:
			var p := a.lerp(b, (s + 0.5) / steps)
			var mi := MeshInstance3D.new()
			mi.name = "ExitLight%02d" % order
			mi.mesh = mesh
			var d := b - a
			var flat := Vector3(d.x, 0, d.z).normalized()
			var lift := 0.2 if p.y > 0.05 and p.y < UP - 0.05 else 0.07
			mi.transform = Transform3D(Basis.looking_at(flat, Vector3.UP).rotated(flat.cross(Vector3.UP).normalized(), atan2(d.y, Vector2(d.x, d.z).length())),
				p + Vector3(0, lift, 0))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
			_late(mi, "res://scripts/props/mall_exit_arrow.gd", {"order": order})
			order += 1


## A flat floor chevron pointing along -Z (the route direction).
func _chevron_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector2(-0.45, 0.25), Vector2(0.0, -0.3), Vector2(0.45, 0.25), Vector2(0.45, 0.05), Vector2(0.0, -0.08), Vector2(-0.45, 0.05)]
	var quads := [[0, 1, 4, 5], [1, 2, 3, 4]]
	for q in quads:
		var a: Vector2 = pts[q[0]]
		var b: Vector2 = pts[q[1]]
		var c: Vector2 = pts[q[2]]
		var d: Vector2 = pts[q[3]]
		_tri(st, Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(c.x, 0, c.y), Vector3.UP)
		_tri(st, Vector3(a.x, 0, a.y), Vector3(c.x, 0, c.y), Vector3(d.x, 0, d.y), Vector3.UP)
	return st.commit()


# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(0.0, 0.1, 20.6)
	start.add_to_group("player_spawn", true)
	level.add_child(start)
	var spawns := _node(level, "EnemySpawns")
	var points := {
		"SpawnMainEntrance": [Vector3(0.0, 0.1, 27.6), 0.0],
		"SpawnStaffCorridor": [Vector3(-21.6, 0.1, 0.0), -90.0],
		"SpawnDepartmentStore": [Vector3(0.0, 0.1, -27.4), 180.0],
		"SpawnKitchen": [Vector3(21.4, 0.1, 0.0), 90.0],
		"SpawnCinema": [Vector3(0.0, UP + 0.1, 27.4), 0.0],
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
	# Both floors; the roof and the tops of counters stay out (largest island).
	mesh.filter_baking_aabb = AABB(Vector3(X0 - 1.0, -1.0, Z0 - 1.0), Vector3(X1 - X0 + 2.0, UP + 1.5, Z1 - Z0 + 2.0))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	region.navigation_mesh = _largest_island(mesh)
	print("build_midnight_mall: navmesh polygons = %d (dropped %d on islands)" % [region.navigation_mesh.get_polygon_count(),
		before - region.navigation_mesh.get_polygon_count()])


## Keeps only the largest connected set of polygons (tops of counters, the
## fountain and the carousel form unreachable islands).
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

func _node(parent: Node, node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	parent.add_child(n)
	return n


func _late(node: Node, script_path: String, props: Dictionary) -> void:
	_late_scripts.append([node, script_path, props])


func _label(parent: Node3D, label_name: String, text: String, pos: Vector3, yaw: float, pixel: float, color: Color) -> Label3D:
	var l := Label3D.new()
	l.name = label_name
	l.text = text
	l.font = _font
	l.font_size = 128
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = Color(0.05, 0.03, 0.12)
	l.position = pos
	l.rotation.y = yaw
	l.shaded = false
	l.double_sided = false
	l.add_to_group("mall_signs", true)
	parent.add_child(l)
	return l


func _recolor(node: Node, material_name: String, m: Material) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var sm := mesh.surface_get_material(i)
			if sm and sm.resource_name == material_name:
				(mi as MeshInstance3D).set_surface_override_material(i, m)


func _box_unit(mat_key: String) -> BoxMesh:
	var key := "unitbox_" + mat_key
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	b.material = _m(mat_key)
	_mesh_cache[key] = b
	return b


func _cylinder_mesh(radius: float, height: float, mat_key: String) -> CylinderMesh:
	var key := "cyl_%s_%s_%s" % [radius, height, mat_key]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 20
	c.rings = 1
	c.material = _m(mat_key)
	_mesh_cache[key] = c
	return c


func _multimesh(parent: Node3D, mm_name: String, mesh: Mesh, xforms: Array[Transform3D], shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = mm_name
	mmi.multimesh = mm
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


## Queues one copy of a model for its MultiMesh (written by _flush_multimeshes).
func _multi_add(model: String, pos: Vector3, yaw_degrees: float) -> void:
	if not _multi.has(model):
		_multi[model] = []
	(_multi[model] as Array).append(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), pos))


## A repeated prop with a box (or round) collider.
func _solid_multi(model: String, pos: Vector3, yaw_degrees: float, size: Vector3, round := false) -> void:
	_multi_add(model, pos, yaw_degrees)
	var props := geo.get_node_or_null("Repeats") as Node3D
	if props == null:
		props = _node(geo, "Repeats")
	var n := props.get_child_count()
	if round:
		_post(props, "%s%d" % [model.trim_prefix("mall_"), n], size.x * 0.5, size.y, pos)
	else:
		_collider(props, "%s%d" % [model.trim_prefix("mall_"), n], size, pos + Vector3(0, size.y * 0.5, 0)).rotation.y = deg_to_rad(yaw_degrees)


func _flush_multimeshes() -> void:
	var holder := _node(dressing, "Repeated")
	for model in _multi:
		var xs: Array[Transform3D] = []
		for t in _multi[model]:
			xs.append(t)
		_multimesh(holder, String(model).trim_prefix("mall_").capitalize().replace(" ", ""), _model_mesh(model), xs)


func _prop(parent: Node3D, model: String, prop_name: String, pos: Vector3, yaw_degrees: float) -> Node3D:
	var node: Node3D = (load(MODELS + model + ".glb") as PackedScene).instantiate()
	node.name = prop_name
	parent.add_child(node)
	node.position = pos
	node.rotation.y = deg_to_rad(yaw_degrees)
	return node


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


func _convex(parent: Node3D, collider_name: String, points: PackedVector3Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = collider_name
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var convex := ConvexPolygonShape3D.new()
	convex.points = points
	shape.shape = convex
	body.add_child(shape)
	return body


func _prism_collider(parent: Node3D, collider_name: String, pts: Array, y0: float, y1: float) -> StaticBody3D:
	var p := PackedVector3Array()
	for q in pts:
		p.append(Vector3(q.x, y0, q.y))
		p.append(Vector3(q.x, y1, q.y))
	return _convex(parent, collider_name, p)


## Invisible upright cylinder collider for posts, trunks and round props.
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


## Invisible player-only collider (physics layer 5): keeps the player off perches.
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


func _own(node: Node) -> void:
	for child in node.get_children():
		child.owner = level
		if child.scene_file_path == "":
			_own(child)
