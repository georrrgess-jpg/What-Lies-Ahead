class_name WeaponView
extends Node3D
## First-person viewmodel: shows the held weapon and arms, applies mastery
## cosmetics, and animates sway, bob, recoil, reloads and the muzzle flash.
##
## The whole rig is scaled down and held very close to the camera. On screen it
## looks identical, but it can no longer poke through walls or zombies.

const VIEW_SCALE := 0.2

var data: WeaponData
var model: Node3D
var _holder: Node3D
var _muzzle: Node3D
var _flash: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_time := 0.0

var _sway := Vector2.ZERO
var _bob_time := 0.0
var _kick := 0.0
var _kick_rot := 0.0
var _raise := 1.0          # 1 = lowered off-screen, 0 = in firing position
var _reload_tween: Tween
var _rest := {}            # node -> rest Transform3D, for reload animations

@onready var player: Player = owner as Player


func _ready() -> void:
	scale = Vector3.ONE * VIEW_SCALE
	_holder = Node3D.new()
	_holder.name = "Holder"
	add_child(_holder)


func add_sway(mouse_delta: Vector2) -> void:
	_sway += mouse_delta * 0.00035
	_sway = _sway.limit_length(0.05)


func show_weapon(weapon: WeaponData) -> void:
	data = weapon
	_kill_reload_tween()
	if model:
		model.queue_free()
	model = weapon.viewmodel.instantiate() if weapon.viewmodel else _placeholder_model()
	_holder.add_child(model)
	model.position = Vector3.ZERO
	_disable_shadows(model)
	_muzzle = model.find_child("Muzzle", true, false) as Node3D
	_rest.clear()
	for part_name in ["Cell", "Slide", "Pump", "ArmL", "ArmR", "Shell"]:
		var part := model.find_child(part_name, true, false) as Node3D
		if part:
			_rest[part_name] = {"node": part, "transform": part.transform}
	_build_flash()
	WeaponCosmetics.apply(model, weapon, Mastery.cosmetics(weapon.id))
	_raise = 1.0
	_kick = 0.0


func muzzle_position() -> Vector3:
	if _muzzle and is_instance_valid(_muzzle):
		return _muzzle.global_position
	return global_position + global_transform.basis * Vector3(0.25, -0.2, -0.8)


func on_fired(weapon: WeaponData) -> void:
	_kick = minf(_kick + weapon.view_kick, weapon.view_kick * 2.2)
	_kick_rot = minf(_kick_rot + weapon.recoil_kick * 1.6, 14.0)
	_flash_time = 0.055
	if _flash:
		_flash.visible = true
		_flash.rotation.z = randf() * TAU
		_flash.scale = Vector3.ONE * randf_range(0.8, 1.25)
	if _flash_light:
		_flash_light.visible = Settings.flash_scale() > 0.05
		_flash_light.light_energy = 2.2 * Settings.flash_scale()


func _process(delta: float) -> void:
	if data == null or model == null:
		return
	_raise = move_toward(_raise, 0.0, delta * 4.0)
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-14.0 * delta))
	_kick_rot = lerpf(_kick_rot, 0.0, 1.0 - exp(-12.0 * delta))
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-7.0 * delta))

	var speed := player.horizontal_speed() if player else 0.0
	var moving := clampf(speed / 5.0, 0.0, 1.6)
	_bob_time += delta * (6.0 + speed * 1.1)
	var bob := Vector3(sin(_bob_time * 0.5) * 0.012, absf(cos(_bob_time * 0.5)) * -0.012, 0.0) * moving
	var ease_raise := _raise * _raise

	_holder.position = data.view_position + bob \
		+ Vector3(-_sway.x, _sway.y - ease_raise * 0.45, _kick)
	_holder.rotation_degrees = data.view_rotation_degrees \
		+ Vector3(_kick_rot + ease_raise * -35.0 + _sway.y * 60.0, -_sway.x * 80.0, -_sway.x * 60.0)

	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			if _flash:
				_flash.visible = false
			if _flash_light:
				_flash_light.visible = false


# --- reload animations ------------------------------------------------------
# Each weapon names a style in its data. The clips are tweens on the model's
# named parts (Cell, Slide, Pump, ArmL), scaled to the weapon's reload_time.

func play_reload(weapon: WeaponData, duration: float) -> void:
	_kill_reload_tween()
	_reset_parts()
	match weapon.reload_style:
		&"side_swap": _reload_side_swap(duration)
		&"break_open": _reload_break_open(duration)
		_: _reload_cell_drop(duration)


func cancel_reload() -> void:
	_kill_reload_tween()
	_reset_parts()


func _kill_reload_tween() -> void:
	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()
	_reload_tween = null


func _reset_parts() -> void:
	for key in _rest:
		var entry: Dictionary = _rest[key]
		if is_instance_valid(entry["node"]):
			entry["node"].transform = entry["transform"]


func _part(part_name: String) -> Node3D:
	return _rest[part_name]["node"] if _rest.has(part_name) else null


func _rest_xf(part_name: String) -> Transform3D:
	return _rest[part_name]["transform"]


func _move(tw: Tween, part_name: String, offset: Vector3, rot_deg: Vector3, time: float) -> void:
	var node := _part(part_name)
	if node == null:
		tw.tween_interval(maxf(time, 0.001))
		return
	var rest := _rest_xf(part_name)
	var target := Transform3D(rest.basis * Basis.from_euler(rot_deg * (PI / 180.0)), rest.origin + offset)
	tw.tween_property(node, "transform", target, maxf(time, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Pulse Pistol: tilt the gun, the cell drops out of the grip, the off hand
## slaps a fresh one in, the slide snaps forward.
func _reload_cell_drop(d: float) -> void:
	var tw := create_tween().set_parallel(true)
	_reload_tween = tw
	_move(tw, "Shell", Vector3(0, 0.02, 0), Vector3(18, 0, -22), d * 0.2)
	_move(tw, "Cell", Vector3(0, -0.28, 0.02), Vector3(18, 0, -22), d * 0.25)
	_move(tw, "ArmL", Vector3(-0.05, -0.3, 0.08), Vector3(0, 0, 0), d * 0.25)
	_move(tw, "Slide", Vector3(0, 0.02, 0.05), Vector3(18, 0, -22), d * 0.2)
	tw.chain().tween_interval(d * 0.2)
	tw.chain()
	_move(tw, "Cell", Vector3(0, 0.02, 0), Vector3(18, 0, -22), d * 0.2)
	_move(tw, "ArmL", Vector3(0, 0.02, 0), Vector3(0, 0, 0), d * 0.2)
	tw.chain()
	_move(tw, "Shell", Vector3.ZERO, Vector3.ZERO, d * 0.25)
	_move(tw, "Cell", Vector3.ZERO, Vector3.ZERO, d * 0.25)
	_move(tw, "Slide", Vector3.ZERO, Vector3.ZERO, d * 0.12)
	_move(tw, "ArmL", Vector3.ZERO, Vector3.ZERO, d * 0.25)


## Ion Carbine: roll the gun over, the side cell slides out, a new one
## slides in, roll back.
func _reload_side_swap(d: float) -> void:
	var tw := create_tween().set_parallel(true)
	_reload_tween = tw
	_move(tw, "Shell", Vector3(-0.03, -0.02, 0), Vector3(-6, 12, 38), d * 0.22)
	_move(tw, "Cell", Vector3(-0.03, -0.02, 0), Vector3(-6, 12, 38), d * 0.22)
	_move(tw, "ArmL", Vector3(-0.1, -0.12, 0.1), Vector3.ZERO, d * 0.22)
	tw.chain()
	_move(tw, "Cell", Vector3(-0.32, -0.1, 0.06), Vector3(-6, 12, 38), d * 0.18)
	_move(tw, "ArmL", Vector3(-0.3, -0.2, 0.12), Vector3.ZERO, d * 0.18)
	tw.chain().tween_interval(d * 0.12)
	tw.chain()
	_move(tw, "Cell", Vector3(-0.03, -0.02, 0), Vector3(-6, 12, 38), d * 0.2)
	_move(tw, "ArmL", Vector3(-0.1, -0.12, 0.1), Vector3.ZERO, d * 0.2)
	tw.chain()
	_move(tw, "Shell", Vector3.ZERO, Vector3.ZERO, d * 0.28)
	_move(tw, "Cell", Vector3.ZERO, Vector3.ZERO, d * 0.28)
	_move(tw, "ArmL", Vector3.ZERO, Vector3.ZERO, d * 0.28)


## Scatter Blaster: tip the barrels down, feed the cell, then two heavy pumps.
func _reload_break_open(d: float) -> void:
	var tw := create_tween().set_parallel(true)
	_reload_tween = tw
	_move(tw, "Shell", Vector3(0, -0.04, 0.02), Vector3(-26, 8, 10), d * 0.2)
	_move(tw, "Cell", Vector3(0, 0.16, 0.04), Vector3(-26, 8, 10), d * 0.2)
	_move(tw, "Pump", Vector3(0, -0.04, 0.02), Vector3(-26, 8, 10), d * 0.2)
	_move(tw, "ArmL", Vector3(0.04, 0.1, 0.1), Vector3.ZERO, d * 0.2)
	tw.chain().tween_interval(d * 0.15)
	tw.chain()
	_move(tw, "Cell", Vector3(0, -0.04, 0.02), Vector3(-26, 8, 10), d * 0.15)
	_move(tw, "ArmL", Vector3(0, -0.04, 0.02), Vector3.ZERO, d * 0.15)
	tw.chain()
	_move(tw, "Shell", Vector3.ZERO, Vector3.ZERO, d * 0.18)
	_move(tw, "Cell", Vector3.ZERO, Vector3.ZERO, d * 0.18)
	_move(tw, "Pump", Vector3.ZERO, Vector3.ZERO, d * 0.18)
	_move(tw, "ArmL", Vector3.ZERO, Vector3.ZERO, d * 0.18)
	for i in 2:
		tw.chain()
		_move(tw, "Pump", Vector3(0, 0, 0.14), Vector3.ZERO, d * 0.07)
		_move(tw, "ArmL", Vector3(0, 0, 0.14), Vector3.ZERO, d * 0.07)
		tw.chain()
		_move(tw, "Pump", Vector3.ZERO, Vector3.ZERO, d * 0.07)
		_move(tw, "ArmL", Vector3.ZERO, Vector3.ZERO, d * 0.07)


# --- helpers ------------------------------------------------------------------

func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows(child)


func _build_flash() -> void:
	_flash = null
	_flash_light = null
	if _muzzle == null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = data.tracer_color.lerp(Color.WHITE, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.2
	mesh.radial_segments = 8
	mesh.rings = 4
	_flash = MeshInstance3D.new()
	_flash.mesh = mesh
	_flash.material_override = mat
	_flash.rotation_degrees.x = 90
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	_muzzle.add_child(_flash)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = data.tracer_color
	_flash_light.omni_range = 5.0 * VIEW_SCALE * 5.0
	_flash_light.visible = false
	_muzzle.add_child(_flash_light)


func _placeholder_model() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.16, 0.5)
	body.mesh = box
	body.name = "Shell"
	root.add_child(body)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.02, -0.3)
	root.add_child(muzzle)
	return root
