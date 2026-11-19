class_name WeaponThumbs
extends Node
## Small side-on pictures of the weapons (with their equipped cosmetics) for
## in-game cards. texture() hands out a picture at once; it is blank until
## the baker has rendered it, then fills in by itself. Pictures are kept for
## the session, so each weapon is rendered once per look.
##
##   var thumbs := WeaponThumbs.new()
##   hud.add_child(thumbs)
##   thumbs.bake(Loadout.available())          # one weapon every few frames
##   rect.texture = WeaponThumbs.texture(weapon)

const SIZE := Vector2i(288, 144)
## How the weapon is turned: side-on with the barrel to the left, a little
## from above.
const TURN_DEGREES := Vector3(8, 82, 0)
## Height of the frame in model units (the camera is orthographic).
const VIEW_HEIGHT := 1.0
## Share of the frame's width and height the weapon's silhouette may fill.
const FILL := Vector2(0.9, 0.84)

static var _cache := {}

var _queue: Array[WeaponData] = []
var _viewport: SubViewport
var _pivot: Node3D
var _busy := false


## The picture of `weapon` as it looks now (blank until it has been baked).
static func texture(weapon: WeaponData) -> Texture2D:
	var key := _key(weapon)
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8))
		_cache[key].set_meta("baked", false)
	return _cache[key]


static func _key(weapon: WeaponData) -> String:
	return "%s|%s" % [weapon.id, Cosmetics.weapon_loadout(weapon.id)]


## Renders the pictures of `weapons` that are still blank, a few frames apart;
## with `first`, ahead of the ones already waiting (the pictures on screen).
func bake(weapons: Array[WeaponData], first := false) -> void:
	# The headless bot has no renderer to bake with.
	if DisplayServer.get_name() == "headless":
		return
	var at := 0
	for w in weapons:
		if not w or not w.viewmodel or texture(w).get_meta("baked"):
			continue
		if first:
			_queue.erase(w)
			_queue.insert(at, w)
			at += 1
		elif not _queue.has(w):
			_queue.append(w)
	if not _busy and not _queue.is_empty():
		_run()


func _run() -> void:
	_busy = true
	_build_stage()
	# The stage's camera takes effect a frame after it enters the tree; a picture
	# rendered sooner is taken from inside the first weapon.
	await get_tree().process_frame
	await get_tree().process_frame
	while not _queue.is_empty():
		var weapon: WeaponData = _queue.pop_front()
		_pose(weapon)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := _viewport.get_texture().get_image()
		if image and not image.is_empty():
			var tex: ImageTexture = texture(weapon)
			tex.set_image(image)
			tex.set_meta("baked", true)
	_viewport.queue_free()
	_viewport = null
	_busy = false


func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.72, 0.95)
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	for spec in [[Vector3(-35, 35, 0), 1.4, Color(1.0, 0.93, 0.85)], [Vector3(-10, -140, 0), 0.7, Color(0.75, 0.6, 1.0)]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_energy = spec[1]
		light.light_color = spec[2]
		_viewport.add_child(light)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	var cam := Camera3D.new()
	# Orthographic: no perspective to stretch the near end of a long weapon,
	# and the frame is an exact VIEW_HEIGHT tall (twice that wide) to fit into.
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = VIEW_HEIGHT
	cam.position = Vector3(0, 0, 4)
	_viewport.add_child(cam)


## Puts `weapon` (no arms, with its cosmetics) side-on in front of the camera,
## scaled so its silhouette fills FILL of the frame and centred on it.
func _pose(weapon: WeaponData) -> void:
	for c in _pivot.get_children():
		c.free()
	var model: Node3D = weapon.viewmodel.instantiate()
	# The arms, the reload-only fists and the hologram copies are not part of
	# the weapon (Jack Pot's fist alone is four times its height).
	WeaponCosmetics.prepare_preview(model)
	WeaponCosmetics.apply(model, weapon, Cosmetics.weapon_loadout(weapon.id))
	# Turned before it enters the tree, so a charm hangs from it the way it shows.
	var turn := Basis.from_euler(TURN_DEGREES * PI / 180.0)
	_pivot.transform = Transform3D(turn, Vector3.ZERO)
	_pivot.add_child(model)
	var shape := silhouette(model, turn)
	var view := Vector2(VIEW_HEIGHT * SIZE.x / SIZE.y, VIEW_HEIGHT)
	var k := minf(view.x * FILL.x / maxf(0.001, shape.size.x), view.y * FILL.y / maxf(0.001, shape.size.y))
	var centre := shape.get_center()
	_pivot.transform = Transform3D(turn.scaled(Vector3.ONE * k), Vector3(-centre.x, -centre.y, 0.0) * k)


## The rectangle the visible meshes of `model` cover on screen (x right, y up)
## when it is turned by `turn` and seen from the front, in model units.
## Measured mesh by mesh, so it is as tight as the parts themselves; a part
## under a hidden node does not count.
static func silhouette(model: Node3D, turn: Basis) -> Rect2:
	var rect := Rect2()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not _shown(model, mesh):
			continue
		var xf := Transform3D(turn, Vector3.ZERO) * _relative(model, mesh)
		var box := mesh.mesh.get_aabb()
		for i in 8:
			var p := xf * box.get_endpoint(i)
			if first:
				rect = Rect2(p.x, p.y, 0.0, 0.0)
				first = false
			else:
				rect = rect.expand(Vector2(p.x, p.y))
	return rect


static func _shown(root: Node3D, node: Node3D) -> bool:
	var n: Node = node
	while n and n != root:
		if n is Node3D and not (n as Node3D).visible:
			return false
		n = n.get_parent()
	return true


## `child`'s transform in `root`'s space.
static func _relative(root: Node3D, child: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = child
	while n and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
