class_name FinishPulse
extends Node
## Drives a reactive shader finish (params.pulse, e.g. Celestial Midway's
## finish_celestial_midway.gdshader): a kill made with the weapon wearing it
## sets the shader's `pulse` to 1 and eases it back to 0 over DURATION (a
## shooting star crosses the weapon and the sky flares), with a fresh
## `pulse_seed` each time. It also holds the finish still (`motion` 0) while
## Settings "Reduce motion" is on, and then skips the pulses. Added to the
## weapon model by WeaponCosmetics; in menus no kills come, so it only keeps
## `motion` in step with the setting.
##
## The finish's materials are shared by every model wearing it, so the pulse
## is reset when this node leaves the tree.

const DURATION := 1.4

## The weapon whose kills fire the pulse.
var weapon_id: StringName
## The finish's shader: the surfaces wearing it are the ones driven.
var shader: Shader
var _materials: Array[ShaderMaterial] = []
var _left := 0.0
## Bounds of the parts wearing the finish, in the model's space.
var _box := AABB()
## The shooting star's path in the model's space.
var _from := Vector3.ZERO
var _to := Vector3.ZERO


func _ready() -> void:
	var model := get_parent() as Node3D
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m == null or m.shader != shader:
				continue
			if not _materials.has(m):
				_materials.append(m)
			var part := WeaponCosmetics.to_model(model, mi) * mi.mesh.get_aabb()
			_box = part if first else _box.merge(part)
			first = false
	Events.enemy_killed.connect(_on_enemy_killed)
	Settings.changed.connect(_apply_motion)
	_apply_motion()
	set_process(false)


func _exit_tree() -> void:
	_set_pulse(0.0)


func _on_enemy_killed(_enemy: Node, by_weapon: StringName, _headshot: bool, _points: int) -> void:
	if by_weapon != weapon_id or Settings.reduce_motion() or not _on_screen():
		return
	_left = DURATION
	# A fresh path each time: from behind the finished parts to past their
	# front, at a random height through their upper half, rising or falling.
	var y0 := _box.position.y + _box.size.y * randf_range(0.45, 0.85)
	var y1 := clampf(y0 + _box.size.y * randf_range(-0.25, 0.25), _box.position.y, _box.end.y)
	var x := _box.get_center().x
	_from = Vector3(x, y0, _box.end.z + 0.05)
	_to = Vector3(x, y1, _box.position.z - 0.05)
	var spark_seed := randf()
	for m in _materials:
		m.set_shader_parameter("pulse_seed", spark_seed)
	_place()
	_set_pulse(1.0)
	set_process(true)


func _process(delta: float) -> void:
	_left = maxf(_left - delta, 0.0)
	_place()
	_set_pulse(_left / DURATION)
	if _left <= 0.0:
		set_process(false)


## Whether the model this node dresses is shown (not a holstered weapon).
func _on_screen() -> bool:
	var model := get_parent() as Node3D
	return model != null and model.is_visible_in_tree()


## Puts the shooting star's path where the weapon is now (the shader works in
## world space, so the path follows the weapon as it moves).
func _place() -> void:
	var xf := (get_parent() as Node3D).global_transform
	for m in _materials:
		m.set_shader_parameter("pulse_from", xf * _from)
		m.set_shader_parameter("pulse_to", xf * _to)
		m.set_shader_parameter("pulse_side", xf.basis.x.normalized())


func _apply_motion() -> void:
	var still := Settings.reduce_motion()
	for m in _materials:
		m.set_shader_parameter("motion", 0.0 if still else 1.0)
	if still:
		_left = 0.0
		_set_pulse(0.0)


func _set_pulse(k: float) -> void:
	for m in _materials:
		m.set_shader_parameter("pulse", k)
