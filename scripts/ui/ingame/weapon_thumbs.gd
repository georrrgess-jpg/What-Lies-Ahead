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


## Renders the pictures of `weapons` that are still blank, a few frames apart.
func bake(weapons: Array[WeaponData]) -> void:
	# The headless bot has no renderer to bake with.
	if DisplayServer.get_name() == "headless":
		return
	for w in weapons:
		if w and w.viewmodel and not texture(w).get_meta("baked") and not _queue.has(w):
			_queue.append(w)
	if not _busy and not _queue.is_empty():
		_run()


func _run() -> void:
	_busy = true
	_build_stage()
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
	cam.position = Vector3(0, 0.02, 1.25)
	cam.fov = 26.0
	_viewport.add_child(cam)


## Puts `weapon` (no arms, with its cosmetics) side-on in front of the camera.
func _pose(weapon: WeaponData) -> void:
	for c in _pivot.get_children():
		c.free()
	var model: Node3D = weapon.viewmodel.instantiate()
	for part_name in ["ArmL", "ArmR"]:
		var part := model.find_child(part_name, true, false) as Node3D
		if part:
			part.visible = false
	for holo in model.find_children("*Holo", "Node3D", true, false):
		(holo as Node3D).visible = false
	WeaponCosmetics.apply(model, weapon, Cosmetics.weapon_loadout(weapon.id))
	var bounds := _bounds(model)
	model.position = -bounds.get_center()
	_pivot.add_child(model)
	_pivot.rotation_degrees = Vector3(8, 82, 0)
	_pivot.scale = Vector3.ONE * (1.0 / maxf(0.01, maxf(bounds.size.z, bounds.size.y * 2.2)))


## The box around every visible mesh of `root`, in root's space.
static func _bounds(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.visible or mesh.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = mesh
		while n != root and n != null:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var box := xf * mesh.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
