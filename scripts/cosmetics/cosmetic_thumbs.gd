class_name CosmeticThumbs
extends SubViewport
## Bakes small 3D thumbnails for Locker cards (operators, weapon skins,
## charms, decals, gloves) in an offscreen viewport, one per frame, and keeps
## them for the session. Add one to the tree, then:
##
##   thumbs.request(item, func(tex: Texture2D): rect.texture = tex)

const SIZE := 192
const BAKED_SLOTS := [&"avatar", &"weapon_finish", &"weapon_charm", &"weapon_decal", &"gloves"]

static var _cache := {}

var _queue: Array = []
var _busy := false
var _stage: Node3D
var _camera: Camera3D


static func can_bake(item: CosmeticItem) -> bool:
	return item != null and item.slot in BAKED_SLOTS


static func cached(item: CosmeticItem) -> Texture2D:
	return _cache.get(item.id) if item else null


func _init() -> void:
	size = Vector2i(SIZE, SIZE)
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.72, 0.95)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	for spec in [[Vector3(-30, 30, 0), 1.3, Color(1.0, 0.93, 0.85)], [Vector3(-15, 165, 0), 1.0, Color(0.5, 0.9, 1.0)],
			[Vector3(-10, -140, 0), 0.7, Color(1.0, 0.5, 0.8)]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = spec[0]
		l.light_energy = spec[1]
		l.light_color = spec[2]
		add_child(l)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	add_child(_camera)


## Calls `done(texture)` once the item's thumbnail is ready (maybe right away).
func request(item: CosmeticItem, done: Callable) -> void:
	if not can_bake(item):
		return
	if _cache.has(item.id):
		done.call(_cache[item.id])
		return
	_queue.append([item, done])
	if not _busy:
		_pump()


func _pump() -> void:
	_busy = true
	while not _queue.is_empty():
		var job: Array = _queue.pop_front()
		var item: CosmeticItem = job[0]
		if not _cache.has(item.id):
			_stage = _build(item)
			if _stage:
				add_child(_stage)
				_frame(_stage, item)
				render_target_update_mode = SubViewport.UPDATE_ONCE
				await RenderingServer.frame_post_draw
				if not is_inside_tree():
					return
				_cache[item.id] = ImageTexture.create_from_image(get_texture().get_image())
				_stage.queue_free()
				_stage = null
		var done: Callable = job[1]
		if done.is_valid() and _cache.has(item.id):
			done.call(_cache[item.id])
	_busy = false


func _build(item: CosmeticItem) -> Node3D:
	match item.slot:
		&"avatar":
			var op := Operators.instantiate(item)
			var anim := Operators.animation_player(op)
			if anim and anim.current_animation != "":
				anim.seek(0.4, true)
				anim.pause()
			op.rotation_degrees.y = 18.0
			return op
		&"weapon_finish":
			return _weapon({"finish": item}, false)
		&"gloves":
			return _weapon({"arms": item}, true)
		&"weapon_decal" when not item.params.has("emblem"):
			# A tint of a weapon's own emblem: show it on that weapon.
			return _weapon({"decal": item}, false, GameData.weapon(item.weapon_id))
		&"weapon_charm", &"weapon_decal":
			var lib := WeaponCosmetics.CHARMS_SCENE if item.slot == &"weapon_charm" else WeaponCosmetics.DECALS_SCENE
			var node_name := ("Charm_" + String(item.params.get("charm", ""))) if item.slot == &"weapon_charm" else ("Emblem_" + String(item.params.get("emblem", "")))
			var mesh := WeaponCosmetics.prop_mesh(lib, node_name)
			if mesh == null:
				return null
			var root := Node3D.new()
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			root.add_child(mi)
			if item.slot == &"weapon_decal":
				# Stickers face -X; turn them to the camera and colour them.
				mi.rotation_degrees.y = 90.0
				mi.scale = Vector3.ONE * 0.8
				for i in mesh.get_surface_count():
					var base := mesh.surface_get_material(i) as StandardMaterial3D
					if base:
						mi.set_surface_override_material(i, WeaponCosmetics.sticker_material(item, base))
			else:
				for i in mesh.get_surface_count():
					var base := mesh.surface_get_material(i) as BaseMaterial3D
					var special := Operators.special_material(base) if base else null
					if special:
						mi.set_surface_override_material(i, special)
				mi.rotation_degrees.y = 20.0
			return root
	return null


## A weapon model (default: the first weapon) wearing `loadout`. arms_only
## shows just the right arm instead of the weapon.
func _weapon(loadout: Dictionary, arms_only: bool, weapon: WeaponData = null) -> Node3D:
	if weapon == null and not GameData.weapons().is_empty():
		weapon = GameData.weapons()[0]
	if weapon == null or weapon.viewmodel == null:
		return null
	var model: Node3D = weapon.viewmodel.instantiate()
	WeaponCosmetics.apply(model, weapon, loadout)
	for child in model.get_children():
		if child is Node3D:
			var keep := String(child.name) == "ArmR" if arms_only else not String(child.name).begins_with("Arm")
			child.visible = keep
	model.rotation_degrees = Vector3(10, -65, 0) if not arms_only else Vector3(-25, 160, 0)
	return model


## Points the camera at the visible geometry of `root`, filling the frame.
func _frame(root: Node3D, item: CosmeticItem) -> void:
	var box := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var b := mi.global_transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if item.slot == &"avatar":
		# Head and shoulders.
		box = AABB(Vector3(-0.45, 1.15, -0.4), Vector3(0.9, 0.95, 0.8))
	elif item.slot == &"gloves":
		# The fist and cuff (the forearm runs on off-screen).
		box = AABB(Vector3(-0.16, -0.26, -0.12), Vector3(0.32, 0.34, 0.36))
	var centre := box.get_center()
	var radius := maxf(box.size.x, maxf(box.size.y, box.size.z)) * 0.5
	var dist := radius / tan(deg_to_rad(_camera.fov * 0.5)) * (1.05 if item.slot == &"avatar" else 1.15)
	_camera.look_at_from_position(centre + Vector3(0, radius * 0.15, dist), centre)
