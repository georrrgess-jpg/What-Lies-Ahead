class_name CandyGummyBehaviour
extends EnemyBehaviour
## Gummy Bear: a jelly body that wobbles on every hit and shrinks as it loses
## health, getting quicker as it gets smaller (chip damage makes it zippy;
## headshots finish it before it gets going). The size and the speed follow
## its health, so a small gummy always reads as a fast one.

## Model scale at zero health (1 = full size).
@export var min_scale := 0.66
## Chase speed multiplier at zero health.
@export var max_speed := 1.6
## Peak squash of the jelly wobble after a hit, and how fast it settles.
@export var wobble := 0.16
@export var wobble_decay := 5.0
@export var wobble_rate := 26.0
@export var wobble_sound: StringName = &"candy_gummy_wobble"

var _model: Node3D
var _base := Vector3.ONE
var _size := 1.0
var _shake := 0.0
var _time := 0.0
var _sound_cool := 0.0


func on_ready(z: Zombie) -> void:
	for child in z.model_root.get_children():
		if child.find_child("AnimationPlayer", true, false):
			_model = child as Node3D
			_base = _model.scale
			break


func on_physics(z: Zombie, delta: float) -> bool:
	var f := z.health_fraction()
	z.speed_multiplier *= lerpf(max_speed, 1.0, f)
	_sound_cool -= delta
	if _model == null:
		return false
	_size = move_toward(_size, lerpf(min_scale, 1.0, f), delta * 0.8)
	_shake = maxf(0.0, _shake - delta * wobble_decay)
	_time += delta
	var k := wobble * _shake * sin(_time * wobble_rate)
	_model.scale = _base * _size * Vector3(1.0 + k, 1.0 - k, 1.0 + k)
	return false


func on_hit(z: Zombie, amount: float, _hit_position: Vector3, _headshot: bool) -> float:
	_shake = 1.0
	_time = 0.0
	if _sound_cool <= 0.0:
		_sound_cool = 0.35
		Sfx.play_at(wobble_sound, z.global_position + Vector3.UP, -6.0, lerpf(1.35, 0.95, z.health_fraction()))
	return amount
