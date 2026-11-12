class_name LockerStage
extends SubViewportContainer
## The Locker's 3D preview for items that need a scene: a weapon turning
## over its display stand wearing the item (drag to spin), the first-person
## arms in a gloves skin, a zombie popping with a kill effect on a loop, or
## shots fired across the stage with a tracer.

enum Mode { NONE, WEAPON, ARMS, KILL_EFFECT, TRACER }

const ZOMBIE_MODEL := "res://art/models/zombie.glb"
const KILL_LOOP := 2.4
const SHOT_LOOP := 0.7
const BURST := [0.0, 0.08, 0.16]
const TRACER_TARGET := Vector3(3.3, 1.0, -0.8)
## The weapon's longest side on the stand, in stage units.
const WEAPON_SPAN := 0.62

var mode := Mode.NONE
var _viewport: SubViewport
var _camera: Camera3D
var _pivot: Node3D
var _content: Node3D
var _item: CosmeticItem
var _weapon: WeaponData
var _model: Node3D
var _timer := 0.0
var _yaw := -35.0
var _dragging := false
var _idle := 0.0
var _muzzle := Vector3.ZERO
var _rest := Transform3D.IDENTITY
var _shots_fired := 0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.68, 0.95)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	for spec in [[Vector3(-35, 35, 0), 1.35, Color(1.0, 0.93, 0.85)], [Vector3(-12, -140, 0), 0.8, Color(0.75, 0.6, 1.0)],
			[Vector3(-20, 170, 0), 0.9, Color(0.45, 0.9, 1.0)]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = spec[0]
		l.light_energy = spec[1]
		l.light_color = spec[2]
		_viewport.add_child(l)
	_camera = Camera3D.new()
	_viewport.add_child(_camera)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_content = Node3D.new()
	_viewport.add_child(_content)


func _clear() -> void:
	for c in _pivot.get_children() + _content.get_children():
		c.queue_free()
	_model = null
	_pivot.rotation = Vector3.ZERO
	_pivot.scale = Vector3.ONE
	_timer = 0.0
	_shots_fired = 0


## The weapon on a turntable wearing `loadout` (Cosmetics.weapon_loadout shape).
func show_weapon(weapon: WeaponData, loadout: Dictionary) -> void:
	_clear()
	mode = Mode.WEAPON
	_weapon = weapon
	if weapon == null or weapon.viewmodel == null:
		return
	_model = weapon.viewmodel.instantiate()
	_pivot.add_child(_model)
	for arm_name in ["ArmL", "ArmR"]:
		var arm := _model.find_child(arm_name, true, false) as Node3D
		if arm:
			arm.visible = false
	WeaponCosmetics.apply(_model, weapon, loadout)
	var box := _bounds(_model)
	_model.position = -box.get_center()
	var fit := WEAPON_SPAN / maxf(0.01, maxf(box.size.x, maxf(box.size.y, box.size.z)))
	_pivot.scale = Vector3.ONE * fit
	_content.add_child(_stand(0.3, -box.size.y * fit * 0.5 - 0.07))
	_yaw = 62.0
	_idle = 0.0
	_camera.fov = 40.0
	_camera.look_at_from_position(Vector3(0, 0.16, 1.3), Vector3(0, -0.04, 0))


## The weapon held in first person, to show a gloves (or operator) arm look.
func show_arms(weapon: WeaponData, loadout: Dictionary) -> void:
	_clear()
	mode = Mode.ARMS
	_weapon = weapon
	if weapon == null or weapon.viewmodel == null:
		return
	_model = weapon.viewmodel.instantiate()
	_content.add_child(_model)
	WeaponCosmetics.apply(_model, weapon, loadout)
	_model.position = weapon.view_position
	_model.rotation_degrees = weapon.view_rotation_degrees
	# An "inspect" view from the left: both hands, the gloves and the sleeves.
	var grip := weapon.view_position
	_camera.fov = 50.0
	_camera.look_at_from_position(grip + Vector3(-1.0, 0.3, 0.1), grip + Vector3(0.02, -0.1, 0.2))


## A tourist zombie that pops with `item`'s kill effect every few seconds.
func show_kill_effect(item: CosmeticItem) -> void:
	_clear()
	mode = Mode.KILL_EFFECT
	_item = item
	var scene := load(ZOMBIE_MODEL) as PackedScene
	_model = scene.instantiate()
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		mi.visible = String(mi.name) in ["Outfit_Tourist", "Acc_Tourist_Cap", "Face_Tourist_Grin"]
	_content.add_child(_model)
	_content.add_child(_stand(0.85, 0.0))
	_model.rotation_degrees.y = 20.0
	var anim := _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		var clip := "Idle-loop" if anim.has_animation("Idle-loop") else "Idle"
		if anim.has_animation(clip):
			anim.play(clip)
	_camera.fov = 40.0
	_camera.look_at_from_position(Vector3(0, 1.45, 5.4), Vector3(0, 1.25, 0))
	_timer = KILL_LOOP - 1.0


## Shots fired across the stage with `item`'s tracer (null = weapon colour).
func show_tracer(item: CosmeticItem, weapon: WeaponData) -> void:
	_clear()
	mode = Mode.TRACER
	_item = item
	_weapon = weapon
	_muzzle = Vector3(-2.7, 1.2, 0.0)
	if weapon and weapon.viewmodel:
		_model = weapon.viewmodel.instantiate()
		_content.add_child(_model)
		for arm_name in ["ArmL", "ArmR"]:
			var arm := _model.find_child(arm_name, true, false) as Node3D
			if arm:
				arm.visible = false
		WeaponCosmetics.apply(_model, weapon, Cosmetics.weapon_loadout(weapon.id))
		_model.position = _muzzle + Vector3(-0.5, -0.08, 0.15)
		_model.look_at(TRACER_TARGET)
		_model.scale = Vector3.ONE * 2.2
		_rest = _model.transform
		var muzzle := _model.find_child("Muzzle", true, false) as Node3D
		if muzzle:
			_muzzle = _model.transform * WeaponCosmetics.to_model(_model, muzzle).origin
	_camera.fov = 48.0
	_camera.look_at_from_position(Vector3(0.3, 1.9, 6.6), Vector3(0.3, 1.05, -0.3))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_timer += delta
	match mode:
		Mode.WEAPON:
			if not _dragging:
				_idle += delta
				if _idle > 1.5:
					_yaw += delta * 22.0
			_pivot.rotation_degrees.y = _yaw
		Mode.ARMS:
			if _model:
				_model.position = _weapon.view_position + Vector3(sin(_timer * 1.3) * 0.006, sin(_timer * 2.1) * 0.005, 0)
		Mode.KILL_EFFECT:
			if _timer >= KILL_LOOP:
				_timer = 0.0
				_pop()
		Mode.TRACER:
			# Three-shot bursts.
			if _shots_fired < BURST.size() and _timer >= BURST[_shots_fired]:
				_shots_fired += 1
				_shoot()
			if _timer >= SHOT_LOOP:
				_timer = 0.0
				_shots_fired = 0


func _pop() -> void:
	if _model == null:
		return
	var at := Vector3(0, 1.2, 0)
	KillEffects.play(_content, at, _item, false)
	var effect := KillEffects.effect_of(_item)
	Sfx.play(&"zombie_pop", -14.0)
	Sfx.play(StringName("cos_kill_" + effect), -10.0)
	var tw := _model.create_tween()
	tw.tween_property(_model, "scale", Vector3(1.25, 0.12, 1.25), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(_model, "scale", Vector3.ZERO, 0.01)
	tw.tween_interval(1.0)
	tw.tween_property(_model, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shoot() -> void:
	var to := TRACER_TARGET + Vector3(randf_range(-0.3, 0.3), randf_range(-0.35, 0.35), randf_range(-0.3, 0.3))
	# Drawn wider than in game: the stage camera is much further away.
	var width := (_weapon.tracer_width if _weapon else 0.05) * 1.8
	var color := _weapon.tracer_color if _weapon else Color(0.3, 0.95, 1.0)
	if _item == null or not TracerStyles.draw(_content, _muzzle, to, width, _item):
		Fx.beam(_content, _muzzle, to, color, width)
	if _model:
		var kick := _model.create_tween()
		kick.tween_property(_model, "transform", Transform3D(_rest.basis, _rest.origin + _rest.basis.z.normalized() * 0.08), 0.03)
		kick.tween_property(_model, "transform", _rest, 0.08)


func _gui_input(event: InputEvent) -> void:
	if mode != Mode.WEAPON:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_idle = 0.0
	elif event is InputEventMouseMotion and _dragging:
		_yaw += event.relative.x * 0.5
		_idle = 0.0


## A display stand: a dark disc with a glowing rim, its top at height `y`.
func _stand(radius: float, y: float) -> Node3D:
	var root := Node3D.new()
	root.position.y = y
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 1.08
	cyl.height = radius * 0.14
	cyl.radial_segments = 48
	disc.mesh = cyl
	var paint := StandardMaterial3D.new()
	paint.albedo_color = UiKit.NAVY
	paint.roughness = 0.35
	paint.metallic = 0.3
	disc.material_override = paint
	disc.position.y = -cyl.height * 0.5
	root.add_child(disc)
	for spec in [[1.0, 0.045, UiKit.CYAN], [0.62, 0.02, Color(UiKit.CYAN, 0.55)]]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.outer_radius = radius * float(spec[0])
		torus.inner_radius = torus.outer_radius - radius * float(spec[1])
		torus.rings = 48
		torus.ring_segments = 6
		ring.mesh = torus
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = spec[2]
		ring.material_override = glow
		ring.scale.y = 0.35
		root.add_child(ring)
	return root


func _bounds(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null or m.get_parent().name == "WeaponCharm":
			continue
		var box := root.global_transform.affine_inverse() * m.global_transform * m.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
