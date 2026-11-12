class_name DuneJetpackHopBehaviour
extends DuneLeapBehaviour
## Ground-crew mechanic: when the player is far, behind cover or up on a
## platform, its jetpack sputters (telegraph), then it boosts over in a high arc
## and lands near the player with a stomp. Flames trail the whole flight.

## Also hop when the player stands at least this much higher (the launch deck).
@export var climb_trigger := 1.2
@export var flame_color := Color(1.0, 0.6, 0.18)

var _flame_t := 0.0


## Jumps to reach a player on a platform, cuts corners when the view is blocked,
## and closes long gaps.
func _wants_leap(z: Zombie) -> bool:
	var d := z.distance_to_target()
	if d < min_range or d > max_range:
		return false
	var higher := z.target.global_position.y - z.global_position.y > climb_trigger
	return higher or d > max_range * 0.45 or not z.has_line_of_sight()


func _on_windup_tick(z: Zombie, delta: float) -> void:
	_flames(z, delta, 0.12)


func _on_flight_tick(z: Zombie, delta: float, _t: float) -> void:
	_flames(z, delta, 0.04)


func _flames(z: Zombie, delta: float, interval: float) -> void:
	_flame_t -= delta
	if _flame_t > 0.0:
		return
	_flame_t = interval
	var back := -Vector3(sin(z.rotation.y), 0.0, cos(z.rotation.y)) * 0.42 * z.data.body_scale
	for side: float in [-0.15, 0.15]:
		var right := Vector3(cos(z.rotation.y), 0.0, -sin(z.rotation.y)) * side * z.data.body_scale
		var nozzle := z.global_position + back + right + Vector3.UP * 0.72 * z.data.body_scale
		Fx.impact(z.get_parent(), nozzle, Vector3.DOWN, flame_color)
