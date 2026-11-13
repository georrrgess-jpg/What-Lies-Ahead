class_name CosmeticThumbs
extends SubViewport
## Bakes small 3D thumbnails for Locker cards (operators, weapon skins,
## charms, decals, gloves) in an offscreen viewport, one per frame, and keeps
## them for the session. Add one to the tree, then:
##
##   thumbs.request(item, func(tex: Texture2D): rect.texture = tex)

const SIZE := 192
## Oldest thumbnails are dropped beyond this many (each is about 150 KB).
const MAX_CACHED := 160
const BAKED_SLOTS := [&"avatar", &"weapon_finish", &"weapon_charm", &"weapon_decal", &"gloves", &"weapon_sight"]

static var _cache := {}

var _queue: Array = []
var _job: Array = []
var _frames := 0
var _stage: Node3D
var _camera: Camera3D


static func can_bake(item: CosmeticItem) -> bool:
	return item != null and item.slot in BAKED_SLOTS


## Cache key: weapon skins (and iron sights) are shown on the weapon they are browsed for.
static func key(item: CosmeticItem, weapon: WeaponData) -> String:
	var on_weapon := item.slot == &"weapon_finish" or item.slot == &"weapon_sight" and WeaponSights.optic_name(item) == ""
	if on_weapon and weapon:
		return "%s@%s" % [item.id, weapon.id]
	return String(item.id)


static func cached(item: CosmeticItem, weapon: WeaponData = null) -> Texture2D:
	return _cache.get(key(item, weapon)) if item else null


func _init() -> void:
	size = Vector2i(SIZE, SIZE)
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED


func _ready() -> void:
	set_process(false)
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
## `weapon` picks the model weapon skins are shown on.
func request(item: CosmeticItem, done: Callable, weapon: WeaponData = null) -> void:
	if not can_bake(item):
		return
	var k := key(item, weapon)
	if _cache.has(k):
		done.call(_cache[k])
		return
	_queue.append([item, done, weapon, k])
	set_process(true)


# One bake at a time: build the scene, render it once, read it back two
# frames later (polled, so a freed Locker never leaves a coroutine behind).
func _process(_delta: float) -> void:
	if _job.is_empty():
		_start_next()
		return
	_frames += 1
	if _frames < 2:
		return
	var image := get_texture().get_image()
	if image:
		_cache[_job[3]] = ImageTexture.create_from_image(image)
		while _cache.size() > MAX_CACHED:
			_cache.erase(_cache.keys()[0])
	_stage.queue_free()
	_stage = null
	_deliver(_job)
	_job = []


func _start_next() -> void:
	while not _queue.is_empty():
		var job: Array = _queue.pop_front()
		var item: CosmeticItem = job[0]
		if _cache.has(job[3]):
			_deliver(job)
			continue
		_stage = _build(item, job[2])
		if _stage == null:
			continue
		add_child(_stage)
		_frame(_stage, item)
		render_target_update_mode = SubViewport.UPDATE_ONCE
		_job = job
		_frames = 0
		return
	set_process(false)


func _deliver(job: Array) -> void:
	var done: Callable = job[1]
	if done.is_valid() and _cache.has(job[3]):
		done.call(_cache[job[3]])


func _build(item: CosmeticItem, weapon: WeaponData) -> Node3D:
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
			return _weapon({"finish": item}, false, weapon)
		&"gloves":
			return _weapon({"arms": item}, true)
		&"weapon_sight":
			# An optic on its own, from the eye's side so its reticle shows;
			# iron sights on the weapon they belong to.
			var optic := WeaponSights.build_optic(item)
			if optic == null:
				return _weapon({}, false, weapon)
			optic.rotation_degrees = Vector3(6, 28, 0)
			return optic
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
				# A turning part (a wheel, a saucer) sits beside the charm in the library.
				var spin_mesh := WeaponCosmetics.prop_mesh(lib, node_name + "Spin")
				if spin_mesh:
					var spin := WeaponCharm.charm_mesh(spin_mesh)
					spin.transform = WeaponCosmetics.prop_transform(lib, node_name + "Spin")
					mi.add_child(spin)
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
	WeaponCosmetics.prepare_preview(model, arms_only)
	WeaponCosmetics.apply(model, weapon, loadout)
	if arms_only:
		# Just the firing hand: hide the weapon and the other arm.
		for node in model.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).visible = String(node.name) == "ArmR"
	model.rotation_degrees = Vector3(10, -65, 0) if not arms_only else Vector3(15, 205, 0)
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
		# The hand and cuff (the forearm runs on off-screen).
		var arm := root.find_child("ArmR", true, false) as Node3D
		var hand := arm.global_position if arm else Vector3.ZERO
		box = AABB(hand + Vector3(-0.2, -0.2, -0.17), Vector3(0.34, 0.34, 0.34))
	var centre := box.get_center()
	var radius := maxf(box.size.x, maxf(box.size.y, box.size.z)) * 0.5
	var dist := radius / tan(deg_to_rad(_camera.fov * 0.5)) * (1.05 if item.slot == &"avatar" else 1.15)
	if item.slot == &"weapon_finish" and box.size.y >= box.size.x * 0.9:
		# A weapon as tall as it is long (a pistol) has its near side closer to
		# the camera than its outline suggests: step back so nothing is cropped.
		dist += box.size.z * 0.5
	_camera.look_at_from_position(centre + Vector3(0, radius * 0.15, dist), centre)
