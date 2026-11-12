class_name RangedSpitBehaviour
extends EnemyBehaviour
## Example behaviour (and a reusable one): at mid range with a clear line of
## sight, stop, wind up for `windup` seconds (the threat ring warns), then lob
## a glowing glob at the player. Melee still works up close.

@export var min_range := 5.0
@export var max_range := 18.0
@export var cooldown := 3.5
@export var windup := 0.7
@export var damage := 12.0
@export var projectile_speed := 14.0
@export var arc := 0.6
@export var color := Color(0.6, 1.0, 0.3)
@export var sound: StringName = &"zombie_windup"

var _cool := 2.0
var _winding := 0.0


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	if _winding > 0.0:
		_winding -= delta
		var to := z.target.global_position - z.global_position
		z.face_toward(Vector3(to.x, 0, to.z), delta)
		z.move_with(Vector3.ZERO)
		if _winding <= 0.0:
			var from := z.global_position + Vector3.UP * 1.5 * z.data.body_scale
			# Lead the target a little so strafing in a straight line isn't free.
			var lead := z.target.velocity * clampf(z.distance_to_target() / projectile_speed, 0.0, 1.0) * 0.6
			EnemyProjectile.launch(z.get_parent(), from, z.target.global_position + Vector3.UP * 1.0 + lead,
				projectile_speed, damage, color, arc, 0.22, z)
			z.play_animation(&"Walk", 0.2)
		return true
	if _cool <= 0.0 and z.state == Zombie.State.CHASE:
		var d := z.distance_to_target()
		if d >= min_range and d <= max_range and z.has_line_of_sight():
			_cool = cooldown
			_winding = windup
			z.play_animation(&"Attack", 0.1)
			Sfx.play_at(sound, z.global_position + Vector3.UP, -2.0, 1.3)
			return true
	return false


func is_winding_up() -> bool:
	return _winding > 0.0


func interrupt(z: Zombie) -> void:
	if _winding > 0.0:
		_winding = 0.0
		z.play_animation(&"Walk", 0.2)
