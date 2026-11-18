extends SceneTree
## Generator for World 15 "Toybox Town" / level "Toy Shop".
##
## Rebuilds scenes/levels/toy_shop.tscn: a giant old toy shop at night, after
## closing, seen at toy size (1 m here is about 10 cm of shop). The arena is the
## shop floor between the window display and the counter: the Toy Chest
## station on its round play rug, letter-block towers, the jack-in-the-box, a
## ball pit, a crayon box, stacked board-game boxes climbed by a book stair,
## the race track and the enterable two-storey dollhouse; the window display
## podium along the shop window, walls of letter blocks to the east and west,
## the toy train on its elevated loop round everything, five zombie entrances,
## the shop itself (shelves of giant toys, pendant lamps, the counter) and the
## moonlit street beyond the window, and a baked navigation mesh.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/build_toy_shop.gd
##
## Run it with a renderer (not --headless): the headless renderer keeps no
## MultiMesh instance data, so the block walls and shelf toys would save empty.
##
## NOTE: running this overwrites hand edits made to toy_shop.tscn.
##
## Layout (metres, top view; -Z = north; the shop floor is y 0):
##   - Arena x -38..38, z -38..36. Station at the origin; the window wall at
##     z -38 (glass x -36..36, y 4.5..34); the display podium (y 2.4) along it,
##     x -18..18, climbed by book stairs at both ends; the counter at z 36..44.
##   - Letter-block walls at x +-38..40.4, with service corridors behind them
##     (x +-40.4..46) in front of the wall shelving.
##   - Dollhouse: centre (33.5, 0, -8), its open side facing west; upper floor y 4.
##   - Train loop: ellipse 28 x 22 m round the origin, rail top y 6.4.
##   - Entrances: under the west shelves (N and S), the toy box and the stock
##     shelves (east), and through the counter flap (south).

const OUT_PATH := "res://scenes/levels/toy_shop.tscn"
const MODELS := "res://art/models/"
const TEXTURES := "res://art/textures/"
const SHADERS := "res://art/shaders/"

const STATION := Vector3(0.0, 0.0, 0.0)
const PORTAL := Vector3(0.0, 0.0, 32.0)
const ARENA_X := 38.0
const WINDOW_Z := -38.0
const COUNTER_Z := 36.0
const COUNTER_H := 11.0
const SHELF_X := 46.0
const ROOM_X := 51.5
const ROOM_BACK := 56.0
const CEILING := 50.0
const PODIUM_Y := 2.4
const PODIUM := Rect2(-18.0, -37.9, 36.0, 8.9)     # x, z, w, d
const BLOCK := 2.4
const DOLLHOUSE := Vector3(33.5, 0.0, -8.0)
const TRACK_R := Vector2(28.0, 22.0)
const TRACK_Y := 6.4
const BALLPIT := Vector3(-19.0, 0.0, 6.0)
const GAMEBOXES := Vector3(-25.0, 0.0, 22.0)
const RACETRACK := Vector3(20.0, 0.0, 20.0)
const JACK := Vector3(12.0, 0.0, -11.0)
const MOON_DIR := Vector3(0.18, 0.5, -0.85)          # toward the moon (north, low)
const PLAYER_WALL_H := 12.0
## Entrance gaps in the block walls and the counter: [name, gap centre, marker].
const ENTRANCES := [
	["Shelves", Vector3(-ARENA_X, 0, -12.0), Vector3(-43.2, 0.1, -12.0)],
	["Bookcase", Vector3(-ARENA_X, 0, 18.0), Vector3(-43.2, 0.1, 18.0)],
	["ToyBox", Vector3(ARENA_X, 0, -24.0), Vector3(43.2, 0.1, -24.0)],
	["StockShelf", Vector3(ARENA_X, 0, 16.8), Vector3(43.2, 0.1, 16.8)],
	["Counter", Vector3(-15.5, 0, COUNTER_Z), Vector3(-15.5, 0.1, 48.5)],
]

var level: Node3D
var geo: Node3D          # collidable geometry (navmesh source)
var dressing: Node3D     # non-colliding scenery
var _materials := {}
var _boxes := {}
var _late_scripts: Array = []
var _light_count := 0
var _mesh_cache := {}
var _multi := {}         # model -> Array[Transform3D] (flushed to MultiMeshes)
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 1515
	level = Node3D.new()
	level.name = "ToyShop"
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

	_build_room()
	_build_window()
	_build_podium()
	_build_counter()
	_build_block_walls()
	_build_station()
	_build_arena_props()
	_build_gamebox_stack()
	_build_dollhouse()
	_build_train()
	_build_shelves()
	_build_lamps()
	_build_street()
	_build_bunting()
	_build_exit()
	_build_markers()
	_flush_multi()
	var windup := Node3D.new()
	windup.name = "WindUp"
	level.add_child(windup)
	_late(windup, "res://scripts/props/toy_windup.gd", {})

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
	print("build_toy_shop: saved %s (error %d), %d omni lights" % [OUT_PATH, err, _light_count])
	level.free()
	quit(0 if err == OK else 1)


# ---------------------------------------------------------------------------
# Environment: moonlight through the shop window, warm lamps inside
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SHADERS + "mall_night_sky.gdshader")
	sky_mat.set_shader_parameter("moon_dir", MOON_DIR.normalized())
	sky_mat.set_shader_parameter("moon_size", 0.05)
	sky_mat.set_shader_parameter("zenith", Color(0.03, 0.05, 0.16))
	sky_mat.set_shader_parameter("horizon", Color(0.12, 0.16, 0.38))
	sky_mat.set_shader_parameter("haze", Color(0.3, 0.26, 0.5))
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.52, 0.56)
	env.ambient_light_energy = 0.54
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.3
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.28, 0.22, 0.3)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	level.add_child(we)

	# Moonlight through the shop window: the only shadowed light, so the
	# window frame lays its long shadow across the floor and the podium.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.looking_at(-MOON_DIR.normalized(), Vector3.UP), Vector3(0, 40, 0))
	sun.light_color = Color(0.62, 0.72, 1.0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.shadow_opacity = 0.8
	level.add_child(sun)


# ---------------------------------------------------------------------------
# The room: floor, walls, ceiling
# ---------------------------------------------------------------------------

func _build_room() -> void:
	var room := Node3D.new()
	room.name = "Room"
	geo.add_child(room)
	var planks := _textured("planks", "toy_planks", 0.085, 0.75)
	_box(room, "Floor", Vector3(ROOM_X * 2 + 2, 1.0, ROOM_BACK - WINDOW_Z + 2), Vector3(0, -0.5, (ROOM_BACK + WINDOW_Z) * 0.5), planks)
	var paper := _textured("wallpaper", "toy_wallpaper", 0.11, 0.85)
	var skirting := _mat("skirting", Color(0.95, 0.9, 0.8), 0.6)
	for s: float in [-1.0, 1.0]:
		_visual_box(dressing, "Wall%d" % int(s), Vector3(1.0, CEILING, ROOM_BACK - WINDOW_Z + 2), Vector3(s * (ROOM_X + 0.5), CEILING * 0.5, (ROOM_BACK + WINDOW_Z) * 0.5), paper)
	_visual_box(dressing, "BackWall", Vector3(ROOM_X * 2 + 2, CEILING, 1.0), Vector3(0, CEILING * 0.5, ROOM_BACK + 0.5), paper)
	_visual_box(dressing, "BackSkirting", Vector3(ROOM_X * 2, 2.4, 0.4), Vector3(0, 1.2, ROOM_BACK - 0.2), skirting)
	var ceiling := _mat("ceiling", Color(0.36, 0.27, 0.24), 0.9)
	_visual_box(dressing, "Ceiling", Vector3(ROOM_X * 2 + 2, 1.0, ROOM_BACK - WINDOW_Z + 4), Vector3(0, CEILING + 0.5, (ROOM_BACK + WINDOW_Z) * 0.5), ceiling)
	# Ceiling beams across the room.
	var beam := _mat("beam", Color(0.55, 0.36, 0.24), 0.8)
	for k in 6:
		var z := WINDOW_Z + 6.0 + k * 16.0
		_visual_box(dressing, "Beam%d" % k, Vector3(ROOM_X * 2, 2.4, 1.8), Vector3(0, CEILING - 1.2, z), beam)
	# The shelf footprints and the back of the room are solid (zombies keep to
	# the corridors in front of the shelving).
	for s: float in [-1.0, 1.0]:
		_collider(room, "ShelfBase%d" % int(s), Vector3(ROOM_X - SHELF_X + 1, 8.0, ROOM_BACK - WINDOW_Z), Vector3(s * (SHELF_X + (ROOM_X - SHELF_X + 1) * 0.5), 4.0, (ROOM_BACK + WINDOW_Z) * 0.5))
	_collider(room, "BackBase", Vector3(ROOM_X * 2, 8.0, 1.0), Vector3(0, 4.0, ROOM_BACK - 0.5))


func _build_window() -> void:
	var win := Node3D.new()
	win.name = "ShopWindow"
	geo.add_child(win)
	var wall := _mat("window_wall", Color(0.27, 0.42, 0.72), 0.7)
	var frame := _mat("window_frame", Color(0.96, 0.92, 0.84), 0.55)
	var x0 := -36.0
	var x1 := 36.0
	var y0 := 4.5
	var y1 := 34.0
	var z := WINDOW_Z - 0.5
	# Wall around the opening (solid below the sill; the rest out of reach).
	_box(win, "Sill", Vector3(ROOM_X * 2 + 2, y0, 1.0), Vector3(0, y0 * 0.5, z), wall)
	_visual_box(dressing, "WallL", Vector3(ROOM_X + 1 + x0, CEILING - y0, 1.0), Vector3((x0 - ROOM_X - 1) * 0.5, (CEILING + y0) * 0.5, z), wall)
	_visual_box(dressing, "WallR", Vector3(ROOM_X + 1 - x1, CEILING - y0, 1.0), Vector3((x1 + ROOM_X + 1) * 0.5, (CEILING + y0) * 0.5, z), wall)
	_visual_box(dressing, "WallTop", Vector3(x1 - x0, CEILING - y1, 1.0), Vector3(0, (CEILING + y1) * 0.5, z), wall)
	# Painted panels on the sill wall and the window frame.
	for k in 8:
		var px := -45.0 + k * 12.86
		_visual_box(dressing, "SillPanel%d" % k, Vector3(9.0, 2.6, 0.2), Vector3(px, 2.25, WINDOW_Z + 0.1), _mat("sill_panel", Color(0.36, 0.55, 0.86), 0.6))
	_visual_box(dressing, "SillCap", Vector3(x1 - x0 + 3, 0.6, 2.2), Vector3(0, y0 + 0.3, WINDOW_Z - 0.2), frame)
	_visual_box(dressing, "FrameTop", Vector3(x1 - x0 + 3, 1.6, 1.6), Vector3(0, y1 + 0.8, z), frame)
	for s: float in [-1.0, 1.0]:
		_visual_box(dressing, "FrameSide%d" % int(s), Vector3(1.6, y1 - y0 + 1.6, 1.6), Vector3(s * (x1 + 0.8), (y0 + y1) * 0.5 + 0.8, z), frame)
	for k in 5:
		var mx := -24.0 + k * 12.0
		_visual_box(dressing, "Mullion%d" % k, Vector3(0.9, y1 - y0, 1.0), Vector3(mx, (y0 + y1) * 0.5, z), frame)
	_visual_box(dressing, "Transom", Vector3(x1 - x0, 0.9, 1.0), Vector3(0, 23.0, z), frame)
	# Gold lettering on the glass, read from the street (mirrored from inside).
	var sign := Label3D.new()
	sign.name = "ShopName"
	sign.text = "TINKER & CO.\nFINE TOYS"
	sign.font_size = 256
	sign.pixel_size = 0.02
	sign.modulate = Color(1.0, 0.8, 0.35)
	sign.outline_modulate = Color(0.35, 0.18, 0.05)
	sign.outline_size = 24
	sign.double_sided = true
	sign.shaded = true
	sign.position = Vector3(0, 28.0, z - 0.05)
	sign.rotation.y = PI
	dressing.add_child(sign)
	_player_block(win, "SillLedge", Vector3(ROOM_X * 2, 4.0, 2.0), Vector3(0, y0 + 2.0, WINDOW_Z - 0.6))
	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	var quad := QuadMesh.new()
	quad.size = Vector2(x1 - x0, y1 - y0)
	glass.mesh = quad
	var gm := StandardMaterial3D.new()
	gm.resource_name = "window_glass"
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.55, 0.7, 0.95, 0.12)
	gm.roughness = 0.05
	gm.metallic_specular = 0.9
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.material_override = gm
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.position = Vector3(0, (y0 + y1) * 0.5, z)
	dressing.add_child(glass)
	_collider(win, "GlassCollision", Vector3(x1 - x0, y1 - y0, 0.6), Vector3(0, (y0 + y1) * 0.5, z))


func _build_podium() -> void:
	var pod := Node3D.new()
	pod.name = "Podium"
	geo.add_child(pod)
	var r := PODIUM
	var centre := Vector3(r.position.x + r.size.x * 0.5, PODIUM_Y * 0.5, r.position.y + r.size.y * 0.5)
	var body := _collider(pod, "Stage", Vector3(r.size.x, PODIUM_Y, r.size.y), centre)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(Vector3(r.size.x, PODIUM_Y - 0.2, r.size.y), _mat("podium", Color(0.82, 0.22, 0.2), 0.55))
	mi.position.y = -0.1
	body.add_child(mi)
	_visual_box(dressing, "StageTop", Vector3(r.size.x + 0.3, 0.25, r.size.y + 0.1), centre + Vector3(0, PODIUM_Y * 0.5 - 0.12, 0), _textured("planks", "toy_planks", 0.085, 0.75))
	_visual_box(dressing, "StageTrim", Vector3(r.size.x + 0.4, 0.3, r.size.y + 0.2), centre + Vector3(0, PODIUM_Y * 0.5 - 0.38, 0), _mat("gold", Color(0.95, 0.72, 0.3), 0.35))
	# Stars along the stage front.
	for k in 7:
		var star := _prop(dressing, "toy_exit_star", "StageLamp%d" % k, Vector3(-15.0 + k * 5.0, 0.0, r.end.y + 0.6), 0.0, Vector3(0.7, 1.6, 0.7))
		star.scale = Vector3.ONE * 0.8
	# Book stairs at both ends, descending outward.
	var sz := r.position.y + r.size.y * 0.5 + 1.2
	_book_stairs(pod, "StairW", Vector3(r.position.x, PODIUM_Y, sz), Vector3(r.position.x - 8.4, 0, sz), 3.0)
	_book_stairs(pod, "StairE", Vector3(r.end.x, PODIUM_Y, sz), Vector3(r.end.x + 8.4, 0, sz), 3.0)
	# The window display: a rocket, a big teddy, a drum and blocks (cover up top).
	var y := PODIUM_Y
	_solid_prop(pod, "toy_rocket", "DisplayRocket", Vector3(-9.0, y, -35.0), 20.0, Vector3(3.0, 6.5, 3.0), 0.75)
	_solid_prop(pod, "toy_teddy", "DisplayTeddy", Vector3(9.0, y, -35.0), 10.0, Vector3(4.2, 5.0, 3.4), 0.8)
	_solid_prop(pod, "toy_drum", "DisplayDrum", Vector3(0.0, y, -34.5), 0.0, Vector3(2.6, 1.6, 2.6), 0.62)
	_block(pod, "DisplayBlockA", Vector3(-14.0, y, -32.0), "red", 12.0)
	_block(pod, "DisplayBlockB", Vector3(14.5, y, -33.0), "blue", -18.0)
	_block(pod, "DisplayBlockC", Vector3(4.5, y, -31.3), "yellow", 30.0, 0.6)


## A stair of stacked hardbacks from `top` down to `bottom` along X: a sloped
## collider (as _stairs in the other generators) under columns of books.
func _book_stairs(parent: Node3D, stair_name: String, top: Vector3, bottom: Vector3, width: float) -> void:
	var run := Vector3(bottom.x - top.x, 0, bottom.z - top.z)
	var length := run.length()
	var rise := top.y - bottom.y
	var dir := run / length
	var body := StaticBody3D.new()
	body.name = stair_name
	parent.add_child(body)
	body.position = (top + bottom) * 0.5
	body.rotation.y = atan2(-dir.z, dir.x)
	var angle := atan2(rise, length)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(sqrt(length * length + rise * rise) + 0.3, 0.4, width)
	shape.shape = box
	shape.rotation.z = -angle
	shape.position = Vector3(0, -0.2 / cos(angle) + 0.06, 0)
	body.add_child(shape)
	var steps := int(round(rise / 0.48))
	var colours := ["red", "blue", "green", "yellow"]
	for k in steps:
		var along := length * (k + 0.5) / steps
		var h := rise * (steps - k) / steps
		var books := int(ceil(h / 0.5))
		for b in books:
			var p := top + dir * along + Vector3(0, h - 0.5 * (b + 1) - top.y + bottom.y, 0)
			p.y = maxf(bottom.y, p.y)
			var yaw := rad_to_deg(atan2(-dir.z, dir.x)) + _rng.randf_range(-4.0, 4.0)
			_add_multi("toy_book_" + colours[(k + b * 3) % 4], Transform3D(Basis(Vector3.UP, deg_to_rad(yaw + 90.0)), p))


# ---------------------------------------------------------------------------
# The counter (south) with its flap through to the back
# ---------------------------------------------------------------------------

func _build_counter() -> void:
	var c := Node3D.new()
	c.name = "Counter"
	geo.add_child(c)
	var wood := _mat("counter_wood", Color(0.62, 0.38, 0.22), 0.65)
	var panel := _mat("counter_panel", Color(0.2, 0.36, 0.7), 0.6)
	var top := _textured("planks", "toy_planks", 0.085, 0.75)
	var depth := 8.0
	var zc := COUNTER_Z + depth * 0.5
	var gap0 := -18.0
	var gap1 := -13.0
	_box(c, "BodyW", Vector3(gap0 + SHELF_X, COUNTER_H, depth), Vector3((gap0 - SHELF_X) * 0.5, COUNTER_H * 0.5, zc), wood)
	_box(c, "BodyE", Vector3(SHELF_X - gap1, COUNTER_H, depth), Vector3((gap1 + SHELF_X) * 0.5, COUNTER_H * 0.5, zc), wood)
	_box(c, "Lintel", Vector3(gap1 - gap0, COUNTER_H - 6.0, depth), Vector3((gap0 + gap1) * 0.5, (COUNTER_H + 6.0) * 0.5, zc), wood)
	_visual_box(dressing, "CounterTop", Vector3(SHELF_X * 2 + 1, 0.8, depth + 1.6), Vector3(0, COUNTER_H + 0.4, zc - 0.4), top)
	# Raised panels along the front (skipping the flap).
	var x := -SHELF_X + 4.0
	var k := 0
	while x < SHELF_X - 3.0:
		if x + 3.0 < gap0 or x - 3.0 > gap1:
			_visual_box(dressing, "Panel%d" % k, Vector3(6.0, 6.5, 0.3), Vector3(x, 4.5, COUNTER_Z - 0.1), panel)
			_visual_box(dressing, "PanelStar%d" % k, Vector3(1.4, 1.4, 0.3), Vector3(x, 4.5, COUNTER_Z - 0.25), _mat("gold", Color(0.95, 0.72, 0.3), 0.35))
		x += 8.0
		k += 1
	_visual_box(dressing, "Kick", Vector3(SHELF_X * 2, 0.8, 0.4), Vector3(0, 0.4, COUNTER_Z - 0.15), _mat("skirting", Color(0.95, 0.9, 0.8), 0.6))
	# The flap itself, swung open against the counter side.
	_visual_box(dressing, "Flap", Vector3(0.4, 5.6, 4.0), Vector3(gap0 + 0.25, 2.8, COUNTER_Z - 2.1), panel)
	_player_wall(_player_walls(), "CounterGate", Vector3(gap0, 0, COUNTER_Z - 0.3), Vector3(gap1, 0, COUNTER_Z - 0.3), PLAYER_WALL_H)
	# On the counter: the cash register, a jar of marbles, a desk lamp, toys.
	var ty := COUNTER_H + 0.8
	_visual_box(dressing, "Register", Vector3(9.0, 6.0, 6.0), Vector3(18.0, ty + 3.0, zc), _mat("register", Color(0.85, 0.66, 0.3), 0.35))
	_visual_box(dressing, "RegisterTop", Vector3(8.0, 2.5, 3.5), Vector3(18.0, ty + 7.2, zc + 1.0), _mat("register", Color(0.85, 0.66, 0.3), 0.35))
	_visual_box(dressing, "RegisterKeys", Vector3(7.0, 0.8, 2.6), Vector3(18.0, ty + 6.3, zc - 2.2), _mat("ink", Color(0.12, 0.11, 0.16), 0.5))
	_add_multi("toy_teddy", Transform3D(Basis(Vector3.UP, deg_to_rad(165.0)).scaled(Vector3.ONE * 0.9), Vector3(-30.0, ty, zc)))
	_add_multi("toy_robot", Transform3D(Basis(Vector3.UP, deg_to_rad(190.0)), Vector3(4.0, ty, zc + 0.5)))
	_add_multi("toy_jack_box", Transform3D(Basis(Vector3.UP, deg_to_rad(170.0)).scaled(Vector3.ONE * 0.8), Vector3(-6.0, ty, zc)))
	_add_multi("toy_train_loco", Transform3D(Basis(Vector3.UP, deg_to_rad(80.0)).scaled(Vector3.ONE * 1.4), Vector3(32.0, ty, zc - 1.0)))


# ---------------------------------------------------------------------------
# Letter-block walls east and west, with their entrance gaps
# ---------------------------------------------------------------------------

func _build_block_walls() -> void:
	var walls := Node3D.new()
	walls.name = "BlockWalls"
	geo.add_child(walls)
	var colours := ["red", "yellow", "blue", "green"]
	for s: float in [-1.0, 1.0]:
		var x: float = s * (ARENA_X + BLOCK * 0.5)
		var z := WINDOW_Z + BLOCK * 0.5
		var i := 0
		while z < COUNTER_Z:
			var skip := false
			for e in ENTRANCES:
				var g: Vector3 = e[1]
				if absf(g.x - x) < 3.0 and absf(g.z - z) < 2.5:
					skip = true
			if s > 0.0 and absf(z - DOLLHOUSE.z) < 7.0:
				skip = true
			if not skip:
				for level_k in 2:
					var c: String = colours[(i + level_k * 2 + (1 if s > 0 else 0)) % 4]
					var yaw := _rng.randf_range(-3.0, 3.0) + 90.0 * _rng.randi_range(0, 3)
					_add_multi("toy_block_" + c, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3(x, level_k * BLOCK, z)))
				_collider(walls, "Wall%d_%d" % [int(s), i], Vector3(BLOCK, BLOCK * 2, BLOCK), Vector3(x, BLOCK, z))
			z += BLOCK
			i += 1
		# The player-only boundary along the block faces (gaps included).
		_player_wall(_player_walls(), "Boundary%d" % int(s), Vector3(s * ARENA_X, 0, WINDOW_Z), Vector3(s * ARENA_X, 0, COUNTER_Z), PLAYER_WALL_H)
	# Gap dressing: a block on its corner at each side, and the corridor ends.
	for e in ENTRANCES:
		var g: Vector3 = e[1]
		if absf(g.x) < ARENA_X - 1.0:
			continue
		var out := signf(g.x)
		_block(walls, "Gate%sA" % e[0], Vector3(g.x + out * 3.6, 0, g.z - 3.5), colours[int(absf(g.z)) % 4], 25.0, 0.7)


# ---------------------------------------------------------------------------
# Loadout station: the Toy Chest
# ---------------------------------------------------------------------------

func _build_station() -> void:
	var station: Node3D = (load("res://scenes/props/toy_station.tscn") as PackedScene).instantiate()
	station.name = "Station"
	geo.add_child(station)
	station.position = STATION
	var rug := MeshInstance3D.new()
	rug.name = "Rug"
	rug.mesh = _disc_mesh(8.0, 48)
	var rm := StandardMaterial3D.new()
	rm.resource_name = "rug"
	rm.albedo_texture = load(TEXTURES + "toy_rug.png")
	rm.roughness = 0.95
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	rug.material_override = rm
	rug.position = STATION + Vector3(0, 0.02, 0)
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(rug)


func _disc_mesh(radius: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		for p in [Vector2.ZERO, Vector2(cos(a1), sin(a1)), Vector2(cos(a0), sin(a0))]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(p.x * 0.5 + 0.5, p.y * 0.5 + 0.5))
			st.add_vertex(Vector3(p.x * radius, 0, p.y * radius))
	return st.commit()


# ---------------------------------------------------------------------------
# Arena props: block towers, the jack-in-the-box, ball pit, crayons, cars
# ---------------------------------------------------------------------------

func _build_arena_props() -> void:
	var props := Node3D.new()
	props.name = "ArenaProps"
	geo.add_child(props)
	# Stepped block towers NW and SE of the station (3 / 2 / 1 high).
	_block_tower(props, "TowerNW", Vector3(-11.0, 0, -11.0), 1.0)
	_block_tower(props, "TowerSE", Vector3(12.0, 0, 7.5), -1.0)
	# The jack-in-the-box, its jester bobbing on the spring.
	_solid_prop(props, "toy_jack_box", "JackBox", JACK, -30.0, Vector3(4.7, 4.6, 4.7))
	var pop := _prop(dressing, "toy_jack_pop", "JackPop", JACK + Vector3(0, 4.6, 0), -30.0, Vector3(2, 6, 2))
	_late(pop, "res://scripts/props/ambient_motion.gd", {"bob_height": 0.35, "bob_seconds": 2.2, "rock_degrees": 7.0})
	# Ball pit (cover you can climb into), the crayon box and loose crayons.
	_prop(props, "toy_ballpit", "BallPit", BALLPIT, 0.0, Vector3(8, 1.2, 8))
	_post(props, "BallPitCollision", 4.2, 1.15, BALLPIT)
	_solid_prop(props, "toy_crayon_box", "CrayonBox", Vector3(-29.0, 0, -22.0), 20.0, Vector3(6.0, 4.2, 2.6))
	_crayon(props, "CrayonA", Vector3(-22.0, 0, -12.0), 65.0)
	_crayon(props, "CrayonB", Vector3(23.5, 0, 4.0), 100.0)
	_crayon(props, "CrayonC", Vector3(-12.0, 0, 27.0), 20.0)
	# A big teddy slumped against the west wall, a robot in the south-east corner.
	_solid_prop(props, "toy_teddy", "Teddy", Vector3(-33.5, 0, -2.0), 80.0, Vector3(4.6, 6.0, 4.0))
	_solid_prop(props, "toy_robot", "Robot", Vector3(33.0, 0, 31.0), -150.0, Vector3(3.6, 7.0, 2.4), 0.85)
	_solid_prop(props, "toy_drum", "DrumA", Vector3(-8.0, 0, 13.5), 0.0, Vector3(2.5, 1.6, 2.5), 0.6)
	_solid_prop(props, "toy_drum", "DrumB", Vector3(4.0, 0, -21.0), 30.0, Vector3(2.5, 1.6, 2.5), 0.6)
	# Single blocks scattered as low cover.
	_block(props, "LooseA", Vector3(-16.0, 0, 16.0), "green", -12.0)
	_block(props, "LooseB", Vector3(20.0, 0, -21.0), "red", 22.0)
	_block(props, "LooseC", Vector3(-30.0, 0, -30.0), "blue", 8.0)
	_block(props, "LooseD", Vector3(31.0, 0, -31.0), "yellow", -25.0)
	# The race track and its cars.
	_prop(dressing, "toy_racetrack", "RaceTrack", RACETRACK, 0.0, Vector3(25, 0.1, 16))
	_solid_prop(props, "toy_car_red", "CarRed", RACETRACK + Vector3(-8.0, 0, -4.5), 75.0, Vector3(1.5, 1.2, 2.9))
	_solid_prop(props, "toy_car_blue", "CarBlue", RACETRACK + Vector3(6.5, 0, 5.5), -110.0, Vector3(1.5, 1.2, 2.9))


func _block_tower(parent: Node3D, tower_name: String, base: Vector3, flip: float) -> void:
	var colours := ["red", "yellow", "blue", "green"]
	var cells := [[Vector2(0, 0), 0], [Vector2(1, 0), 0], [Vector2(0, 1), 0], [Vector2(0, 0), 1], [Vector2(1, 0), 1], [Vector2(0, 0), 2]]
	var k := 0
	for cell in cells:
		var c: Vector2 = cell[0]
		var p := base + Vector3(c.x * BLOCK * flip, cell[1] * BLOCK, c.y * BLOCK * flip)
		_block(parent, "%s%d" % [tower_name, k], p, colours[(k + int(flip > 0)) % 4], _rng.randf_range(-6.0, 6.0))
		k += 1


## One letter block (MultiMesh-batched) with its own collider.
func _block(parent: Node3D, block_name: String, pos: Vector3, colour: String, yaw := 0.0, scale := 1.0) -> void:
	var size := BLOCK * scale
	_add_multi("toy_block_" + colour, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)).scaled(Vector3.ONE * scale), pos))
	var body := _collider(parent, block_name, Vector3(size, size, size), pos + Vector3(0, size * 0.5, 0))
	body.rotation.y = deg_to_rad(yaw)


func _crayon(parent: Node3D, crayon_name: String, pos: Vector3, yaw: float) -> void:
	_prop(dressing, "toy_crayon", crayon_name, pos, yaw, Vector3(7.4, 1, 1))
	var body := _collider(parent, crayon_name + "Collision", Vector3(7.4, 1.0, 1.0), pos + Vector3(0, 0.5, 0))
	body.rotation.y = deg_to_rad(yaw)


func _build_gamebox_stack() -> void:
	var g := Node3D.new()
	g.name = "GameBoxes"
	geo.add_child(g)
	_solid_prop(g, "toy_gamebox_a", "GameBoxBottom", GAMEBOXES, 0.0, Vector3(7.0, 1.3, 5.0))
	var top := _prop(dressing, "toy_gamebox_b", "GameBoxTop", GAMEBOXES + Vector3(-0.6, 1.3, 0.0), 8.0, Vector3(5.6, 1.04, 4.0))
	top.scale = Vector3(0.8, 0.8, 0.8)
	var c := _collider(g, "GameBoxTopCollision", Vector3(5.6, 1.04, 4.0), GAMEBOXES + Vector3(-0.6, 1.3 + 0.52, 0.0))
	c.rotation.y = deg_to_rad(8.0)
	var y := 1.3 + 1.04
	_book_stairs(g, "GameStair", GAMEBOXES + Vector3(2.0, y, 0.0), GAMEBOXES + Vector3(2.0 + 8.4, 0, 0.0), 3.0)


# ---------------------------------------------------------------------------
# The dollhouse (east): open side west, two floors, stair along its back
# ---------------------------------------------------------------------------

## Dollhouse model coordinates (Blender x, y, z) to world: the model is turned
## so its open side (-Y) faces west.
func _dh(bx: float, by: float, bz: float) -> Vector3:
	return DOLLHOUSE + Vector3(by, bz, bx)


func _build_dollhouse() -> void:
	var d := Node3D.new()
	d.name = "Dollhouse"
	geo.add_child(d)
	_prop(d, "toy_dollhouse", "DollhouseModel", DOLLHOUSE, -90.0, Vector3(9, 11, 14))
	# Walls (world-axis boxes: model X is world Z, model Y is world X).
	_collider(d, "Back", Vector3(0.35, 8.0, 14.0), _dh(0, 4.325, 4.0))
	for s: float in [-1.0, 1.0]:
		_collider(d, "Side%d" % int(s), Vector3(9.0, 8.0, 0.35), _dh(s * 6.825, 0, 4.0))
	_collider(d, "Roof", Vector3(9.4, 3.2, 14.6), _dh(0, 0, 9.4))
	# Upper floor (slot over the stair along the back), its rails.
	_collider(d, "UpperA", Vector3(8.65, 0.3, 5.65), _dh(3.825, -0.175, 3.85))
	_collider(d, "UpperB", Vector3(6.65, 0.3, 7.65), _dh(-2.825, -1.175, 3.85))
	_collider(d, "FrontRail", Vector3(0.2, 1.15, 13.3), _dh(0, -4.3, 4.575))
	_collider(d, "WellRail", Vector3(0.2, 1.15, 7.65), _dh(-2.825, 2.05, 4.575))
	_ramp_collider(d, "Stair", _dh(1.0, 3.15, 4.0), _dh(-6.0, 3.15, 0.0), 2.0)
	_collider(d, "Partition", Vector3(5.65, 3.7, 0.35), _dh(2.5, 1.325, 1.85))
	# Furniture: table and chairs, sofa, bed.
	_collider(d, "Table", Vector3(1.6, 1.15, 2.4), _dh(-3.5, -1.8, 0.575))
	for s: float in [-1.0, 1.0]:
		_collider(d, "Chair%d" % int(s), Vector3(0.8, 1.55, 0.8), _dh(-3.5 + s * 1.75, -1.8, 0.775))
	_collider(d, "Sofa", Vector3(1.4, 1.2, 3.2), _dh(4.8, -0.9, 0.6))
	_collider(d, "Bed", Vector3(1.9, 0.9, 3.2), _dh(4.7, 1.0, 4.45))
	_player_block(d, "UpperRoofCap", Vector3(9.0, 3.0, 14.0), _dh(0, 0, 9.5))
	_omni(d, "DollhouseLampDown", _dh(-2.0, -1.0, 3.2), Color(1.0, 0.8, 0.55), 1.0, 7.0)
	_omni(d, "DollhouseLampUp", _dh(2.0, 0.5, 7.2), Color(1.0, 0.82, 0.6), 0.9, 7.0)


## A collider-only stair slope from `top` down to `bottom` (the model draws the steps).
func _ramp_collider(parent: Node3D, ramp_name: String, top: Vector3, bottom: Vector3, width: float) -> void:
	var run := Vector3(bottom.x - top.x, 0, bottom.z - top.z)
	var length := run.length()
	var rise := top.y - bottom.y
	var dir := run / length
	var body := StaticBody3D.new()
	body.name = ramp_name
	parent.add_child(body)
	body.position = (top + bottom) * 0.5
	body.rotation.y = atan2(-dir.z, dir.x)
	var angle := atan2(rise, length)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(sqrt(length * length + rise * rise) + 0.3, 0.4, width)
	shape.shape = box
	shape.rotation.z = -angle
	shape.position = Vector3(0, -0.2 / cos(angle) + 0.06, 0)
	body.add_child(shape)


# ---------------------------------------------------------------------------
# The toy train: elevated loop on block piers, and the running train
# ---------------------------------------------------------------------------

func _track_point(a: float) -> Vector3:
	return Vector3(cos(a) * TRACK_R.x, TRACK_Y, sin(a) * TRACK_R.y)


func _build_train() -> void:
	var t := Node3D.new()
	t.name = "TrainLoop"
	geo.add_child(t)
	var segments := 84
	for i in segments:
		var a := _track_point(TAU * i / segments)
		var b := _track_point(TAU * (i + 1) / segments)
		var dir := (b - a)
		var yaw := atan2(-dir.z, dir.x)
		_add_multi("toy_track", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(dir.length() / 2.0 + 0.03, 1, 1)), (a + b) * 0.5))
	# Piers every ~8.5 m, skipped where they would crowd a prop or a lane.
	var piers := 19
	for i in piers:
		var p := _track_point(TAU * (i + 0.5) / piers)
		p.y = 0.0
		if _pier_blocked(p):
			continue
		var yaw := rad_to_deg(atan2(-(p.z / TRACK_R.y), p.x / TRACK_R.x))
		_add_multi("toy_pier", Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), p))
		_collider(t, "Pier%d" % i, Vector3(1.4, TRACK_Y - 0.8, 1.4), p + Vector3(0, (TRACK_Y - 0.8) * 0.5, 0)).rotation.y = deg_to_rad(yaw)
	# The train itself (no collision: it runs above everyone's heads).
	var train := Node3D.new()
	train.name = "Train"
	dressing.add_child(train)
	for entry in [["Loco", "toy_train_loco"], ["CarA", "toy_train_car_a"], ["CarB", "toy_train_car_b"], ["CarC", "toy_train_car_a"]]:
		var car := _prop(train, entry[1], entry[0], Vector3.ZERO, 0.0, Vector3(2, 2.5, 4))
		car.position = _track_point(0.0)
	_late(train, "res://scripts/props/toy_train.gd", {"radius": TRACK_R, "height": TRACK_Y})


func _pier_blocked(p: Vector3) -> bool:
	var keep_clear := [
		Rect2(DOLLHOUSE.x - 6.5, DOLLHOUSE.z - 9.0, 13.0, 18.0),
		Rect2(BALLPIT.x - 6.0, BALLPIT.z - 6.0, 12.0, 12.0),
		Rect2(-34.0, -26.0, 10.0, 8.0),
		Rect2(-4.0, 16.0, 8.0, 18.0),
		Rect2(GAMEBOXES.x - 5.0, GAMEBOXES.z - 4.5, 19.0, 9.0),
		Rect2(-26.0, -36.0, 52.0, 8.0),
	]
	for r: Rect2 in keep_clear:
		if r.grow(1.0).has_point(Vector2(p.x, p.z)):
			return true
	for e in ENTRANCES:
		var g: Vector3 = e[1]
		if Vector2(g.x, g.z).distance_to(Vector2(p.x, p.z)) < 7.0:
			return true
	return false


# ---------------------------------------------------------------------------
# The shop: wall shelving loaded with giant toys
# ---------------------------------------------------------------------------

func _build_shelves() -> void:
	var toys := ["toy_teddy", "toy_robot", "toy_rocket", "toy_drum", "toy_jack_box", "toy_crayon_box", "toy_gamebox_a", "toy_car_blue", "toy_block_red", "toy_block_yellow"]
	var scales := {"toy_teddy": 0.95, "toy_robot": 0.85, "toy_rocket": 0.7, "toy_drum": 1.0, "toy_jack_box": 1.1, "toy_crayon_box": 0.85,
		"toy_gamebox_a": 1.0, "toy_car_blue": 2.2, "toy_block_red": 1.6, "toy_block_yellow": 1.6}
	for s: float in [-1.0, 1.0]:
		var x: float = s * (SHELF_X + 2.5)
		var yaw := -90.0 * s
		for bay in 6:
			var z := WINDOW_Z + 8.0 + bay * 16.0
			_add_multi("toy_shelf", Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3(x, 0, z)))
			for board: float in [7.25, 15.25, 23.25, 31.25]:
				var slots := 2 if _rng.randf() < 0.6 else 3
				for k in slots:
					var toy: String = toys[_rng.randi_range(0, toys.size() - 1)]
					var offset := (k - (slots - 1) * 0.5) * (14.0 / slots)
					var sc: float = scales[toy] * _rng.randf_range(0.9, 1.05)
					var face := yaw + _rng.randf_range(-20.0, 20.0)
					_add_multi(toy, Transform3D(Basis(Vector3.UP, deg_to_rad(face)).scaled(Vector3.ONE * sc), Vector3(x - s * 0.2, board, z + offset)))


# ---------------------------------------------------------------------------
# Pendant lamps and the warm light they throw
# ---------------------------------------------------------------------------

func _build_lamps() -> void:
	var lamps := Node3D.new()
	lamps.name = "Lamps"
	dressing.add_child(lamps)
	var spots := [Vector3(-18.0, 29.0, -14.0), Vector3(18.0, 29.0, -14.0), Vector3(-18.0, 29.0, 16.0), Vector3(18.0, 29.0, 16.0), Vector3(0.0, 31.0, 1.0)]
	var k := 0
	for p: Vector3 in spots:
		var lamp := _prop(lamps, "toy_pendant", "Pendant%d" % k, p, k * 40.0, Vector3(6, 3, 6))
		_late(lamp, "res://scripts/props/ambient_motion.gd", {"rock_degrees": 1.2, "bob_seconds": 7.0 + k})
		_omni(lamps, "PendantLight%d" % k, p + Vector3(0, -2.5, 0), Color(1.0, 0.8, 0.55), 1.55 if k < 4 else 1.25, 40.0)
		k += 1
	_omni(lamps, "StationGlow", STATION + Vector3(0, 4.0, 3.5), Color(1.0, 0.84, 0.55), 1.1, 11.0)
	_omni(lamps, "WindowGlow", Vector3(0, 8.0, -30.0), Color(0.6, 0.7, 1.0), 0.8, 24.0)


# ---------------------------------------------------------------------------
# The street beyond the window: pavement, road, gas lamps, the houses opposite
# ---------------------------------------------------------------------------

func _build_street() -> void:
	var st := Node3D.new()
	st.name = "Street"
	dressing.add_child(st)
	var pave := _mat("pavement", Color(0.5, 0.52, 0.62), 0.9)
	var road := _mat("road", Color(0.18, 0.2, 0.3), 0.9)
	_visual_box(st, "Pavement", Vector3(400, 1.0, 40), Vector3(0, -1.0, WINDOW_Z - 21.0), pave)
	_visual_box(st, "Road", Vector3(400, 1.0, 60), Vector3(0, -1.8, WINDOW_Z - 71.0), road)
	_visual_box(st, "FarPavement", Vector3(400, 1.0, 24), Vector3(0, -1.0, WINDOW_Z - 113.0), pave)
	for k in 9:
		_visual_box(st, "Dash%d" % k, Vector3(14.0, 0.2, 1.2), Vector3(-160.0 + k * 40.0, -1.25, WINDOW_Z - 71.0), _mat("road_line", Color(0.85, 0.82, 0.6), 0.8))
	for x: float in [-58.0, 40.0]:
		var lamp := _prop(st, "toy_street_lamp", "StreetLamp%d" % int(x), Vector3(x, -0.5, WINDOW_Z - 34.0), 0.0, Vector3(1, 8, 1))
		lamp.scale = Vector3.ONE * 5.5
	_omni(st, "StreetLampLight", Vector3(-58.0, 40.0, WINDOW_Z - 34.0), Color(1.0, 0.82, 0.5), 2.0, 60.0)
	# Houses opposite: a row of tall facades with lit and dark windows.
	var colours := [Color(0.62, 0.3, 0.28), Color(0.8, 0.72, 0.58), Color(0.36, 0.42, 0.6), Color(0.55, 0.38, 0.5), Color(0.7, 0.55, 0.36)]
	var lit := _mat("window_lit", Color(1.0, 0.8, 0.45), 0.5, Color(1.0, 0.75, 0.4), 2.2)
	var dark := _mat("window_dark", Color(0.12, 0.14, 0.26), 0.3)
	var x := -190.0
	var i := 0
	var zf := WINDOW_Z - 128.0
	while x < 190.0:
		var w := _rng.randf_range(44.0, 64.0)
		var h := _rng.randf_range(70.0, 110.0)
		var cx := x + w * 0.5
		_visual_box(st, "House%d" % i, Vector3(w - 2.0, h, 30.0), Vector3(cx, h * 0.5 - 1.5, zf - 15.0), _mat("house%d" % (i % 5), colours[i % 5], 0.85))
		_visual_box(st, "Cornice%d" % i, Vector3(w + 1.0, 5.0, 32.0), Vector3(cx, h - 1.5, zf - 15.0), _mat("house_roof", Color(0.2, 0.18, 0.26), 0.8))
		var rows := int((h - 12.0) / 16.0)
		var cols := int((w - 8.0) / 12.0)
		for r in rows:
			for c in cols:
				var wx := cx - (cols - 1) * 6.0 + c * 12.0
				var wy := 12.0 + r * 16.0
				var m: StandardMaterial3D = lit if _rng.randf() < 0.35 else dark
				_visual_box(st, "Win%d_%d_%d" % [i, r, c], Vector3(6.0, 9.0, 0.6), Vector3(wx, wy, zf + 0.2), m)
		x += w
		i += 1


# ---------------------------------------------------------------------------
# Paper bunting strung across the shop
# ---------------------------------------------------------------------------

func _build_bunting() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colours := [Color(0.89, 0.27, 0.23), Color(0.95, 0.76, 0.23), Color(0.23, 0.44, 0.82), Color(0.31, 0.68, 0.35), Color(0.97, 0.94, 0.88)]
	var runs := [[Vector3(-46.0, 24.0, -30.0), Vector3(46.0, 24.0, -6.0)], [Vector3(-46.0, 24.0, 6.0), Vector3(46.0, 24.0, 30.0)],
		[Vector3(-46.0, 26.0, 28.0), Vector3(46.0, 26.0, -28.0)]]
	var n := 0
	for run in runs:
		var a: Vector3 = run[0]
		var b: Vector3 = run[1]
		var sag := 5.0
		var count := int(a.distance_to(b) / 2.2)
		var flat := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var normal := flat.cross(Vector3.UP).normalized()
		for k in count:
			var t0 := (k + 0.1) / count
			var t1 := (k + 0.9) / count
			var tm := (k + 0.5) / count
			var p0 := a.lerp(b, t0) - Vector3.UP * sag * 4.0 * t0 * (1.0 - t0)
			var p1 := a.lerp(b, t1) - Vector3.UP * sag * 4.0 * t1 * (1.0 - t1)
			var tip := a.lerp(b, tm) - Vector3.UP * (sag * 4.0 * tm * (1.0 - tm) + 2.0)
			st.set_color(colours[(n + k) % colours.size()])
			for v in [p0, p1, tip]:
				st.set_normal(normal)
				st.add_vertex(v)
		n += 1
	var mi := MeshInstance3D.new()
	mi.name = "Bunting"
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.resource_name = "bunting"
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.8
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.add_child(mi)


# ---------------------------------------------------------------------------
# Exit: the portal in front of the counter and the star nightlights to it
# ---------------------------------------------------------------------------

func _build_exit() -> void:
	var portal: Node3D = (load("res://scenes/props/toy_portal.tscn") as PackedScene).instantiate()
	portal.name = "Portal"
	geo.add_child(portal)
	portal.position = PORTAL
	portal.rotation.y = PI
	var lights := Node3D.new()
	lights.name = "ExitLights"
	level.add_child(lights)
	var a := STATION + Vector3(0.0, 0, 9.0)
	var b := PORTAL + Vector3(0, 0, -3.0)
	var steps := 5
	for k in steps:
		var t := float(k) / (steps - 1)
		for s: float in [-1.0, 1.0]:
			var pos := a.lerp(b, t) + Vector3(s * 2.6, 0, 0)
			var star := _prop(lights, "toy_exit_star", "ExitStar%02d%s" % [k, "L" if s < 0 else "R"], pos, k * 17.0, Vector3(0.7, 1.6, 0.7))
			_late(star, "res://scripts/props/toy_exit_star.gd", {"order": k})


# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _build_markers() -> void:
	var start := Marker3D.new()
	start.name = "PlayerSpawn"
	start.position = Vector3(0.0, 0.1, 21.0)
	start.add_to_group("player_spawn", true)
	level.add_child(start)
	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	level.add_child(spawns)
	for e in ENTRANCES:
		var m := Marker3D.new()
		m.name = "Spawn" + e[0]
		var p: Vector3 = e[2]
		var g: Vector3 = e[1]
		m.position = p
		m.rotation.y = atan2(-(g.x - p.x), -(g.z - p.z))
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
	mesh.filter_baking_aabb = AABB(Vector3(-SHELF_X, -1.0, WINDOW_Z), Vector3(SHELF_X * 2, 7.0, ROOM_BACK - WINDOW_Z))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var before := mesh.get_polygon_count()
	region.navigation_mesh = _largest_island(mesh)
	print("build_toy_shop: navmesh polygons = %d (dropped %d on islands)" % [region.navigation_mesh.get_polygon_count(),
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


## Queues one instance of a model for its shared MultiMesh.
func _add_multi(model: String, xform: Transform3D) -> void:
	if not _multi.has(model):
		_multi[model] = []
	_multi[model].append(xform)


func _flush_multi() -> void:
	var holder := Node3D.new()
	holder.name = "Batched"
	dressing.add_child(holder)
	for model in _multi:
		var list: Array = _multi[model]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _model_mesh(model)
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = model.to_pascal_case()
		mmi.multimesh = mm
		holder.add_child(mmi)


func _model_mesh(model: String) -> Mesh:
	if _mesh_cache.has(model):
		return _mesh_cache[model]
	var source: Node3D = (load(MODELS + model + ".glb") as PackedScene).instantiate()
	var mesh: Mesh = (source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	source.free()
	_mesh_cache[model] = mesh
	return mesh


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


## Invisible upright cylinder collider for round props.
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
func _solid_prop(parent: Node3D, model: String, prop_name: String, pos: Vector3, yaw_degrees: float, size: Vector3, scale := 1.0) -> Node3D:
	var node := _prop(parent, model, prop_name, pos, yaw_degrees, size)
	node.scale = Vector3.ONE * scale
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
