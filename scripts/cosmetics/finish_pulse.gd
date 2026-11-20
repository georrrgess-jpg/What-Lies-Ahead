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

const DURATION := 1.1

## The weapon whose kills fire the pulse.
var weapon_id: StringName
## The finish's shader: the surfaces wearing it are the ones driven.
var shader: Shader
var _materials: Array[ShaderMaterial] = []
var _left := 0.0


func _ready() -> void:
	for node in get_parent().find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m and m.shader == shader and not _materials.has(m):
				_materials.append(m)
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
	for m in _materials:
		m.set_shader_parameter("pulse_seed", randf())
	_set_pulse(1.0)
	set_process(true)


func _process(delta: float) -> void:
	_left = maxf(_left - delta, 0.0)
	_set_pulse(_left / DURATION)
	if _left <= 0.0:
		set_process(false)


## Whether the model this node dresses is shown (not a holstered weapon).
func _on_screen() -> bool:
	var model := get_parent() as Node3D
	return model != null and model.is_visible_in_tree()


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
