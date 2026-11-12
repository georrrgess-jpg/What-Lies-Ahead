class_name DuneMoonLeapBehaviour
extends DuneLeapBehaviour
## Space Cadet: moves in floaty low-gravity bounds (the model hops in step with
## its "Bound" clip), and at mid range crouches, then pounces in a long arc onto
## the spot where the player stood. Strafing during the crouch dodges it.

## Height of the bounding gait's hops (metres, visual only).
@export var hop_height := 0.5

var _model: Node3D


func on_ready(z: Zombie) -> void:
	super.on_ready(z)
	_model = z.model_root


func on_physics(z: Zombie, delta: float) -> bool:
	var busy := super.on_physics(z, delta)
	_model.position.y = 0.0 if busy else _gait_height()
	return busy


func on_death(_z: Zombie) -> void:
	if _model and not is_airborne():
		_model.create_tween().tween_property(_model, "position:y", 0.0, 0.12)


func _launch(z: Zombie) -> void:
	super._launch(z)
	# With the Attack clip as the flight clip, time its strike to the touchdown.
	if _anim and _anim.has_animation(flight_clip):
		_anim.speed_scale = (_anim.get_animation(flight_clip).length * Zombie.ATTACK_STRIKE_FRACTION) / flight_time


func _on_flight_tick(z: Zombie, _delta: float, _t: float) -> void:
	if randf() < 0.25:
		Fx.impact(z.get_parent(), z.global_position + Vector3.UP * 1.0, Vector3.DOWN, Color(0.6, 0.95, 1.0))


## The hop height in step with the Bound clip (airborne between 20% and 80%).
func _gait_height() -> float:
	if _anim == null or not _anim.is_playing() or not String(_anim.current_animation).begins_with("Bound"):
		return 0.0
	var f := _anim.current_animation_position / maxf(0.01, _anim.current_animation_length)
	var air := clampf((f - 0.2) / 0.6, 0.0, 1.0)
	return hop_height * sin(air * PI)
