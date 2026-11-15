class_name CityCrawlerBehaviour
extends DuneLeapBehaviour
## Tunnel Crawler (Ashfall City, Metro Line): scuttles in low on all fours and
## darts sideways in quick jinks while it closes in, so it is hard to keep in
## the sights (and its low body and small head are hard targets), but it is
## fragile. At pouncing range it flattens itself, rear end up and shaking
## (the telegraph: the threat ring warns, it hisses), then leaps low and flat
## at the spot the player stood on. Strafing during the crouch dodges it.

@export_group("Skitter")
## Sideways dart speed (m/s) at the start of a jink; it fades in ~0.3 s.
@export var jink_speed := 4.2
## Seconds between jinks.
@export var jink_every := Vector2(0.55, 1.0)
## Jinks only between these distances to the player.
@export var jink_range := Vector2(3.0, 18.0)
@export var skitter_sound: StringName = &"cz_crawler_skitter"
## Seconds before the first pounce (it pounces on the way in).
@export var first_pounce := Vector2(0.4, 1.4)

var _jink := 0.0
var _side := 1.0


func on_ready(z: Zombie) -> void:
	super.on_ready(z)
	_cool = randf_range(first_pounce.x, first_pounce.y)
	_jink = randf_range(jink_every.x, jink_every.y)
	_side = 1.0 if randf() < 0.5 else -1.0


func on_physics(z: Zombie, delta: float) -> bool:
	if super.on_physics(z, delta):
		return true
	_jink -= delta
	if _jink <= 0.0:
		_jink = randf_range(jink_every.x, jink_every.y)
		if z.state == Zombie.State.CHASE:
			_dart(z)
	return false


## Lands right where the player stood when it took off.
func _landing_goal(z: Zombie) -> Vector3:
	var p := z.target.global_position
	var back := z.global_position - p
	back.y = 0.0
	return p + back.normalized() * land_offset


## A quick sideways dart across the line to the player (mostly alternating).
func _dart(z: Zombie) -> void:
	var d := z.distance_to_target()
	if d < jink_range.x or d > jink_range.y or not z.is_on_floor() or not z.has_line_of_sight():
		return
	if randf() < 0.75:
		_side = -_side
	var to := BossMove.flat_to_target(z)
	z.knockback(Vector3(-to.z, 0.0, to.x) * _side * jink_speed)
	if randf() < 0.35:
		Sfx.play_at(skitter_sound, z.global_position + Vector3.UP * 0.4, -4.0, randf_range(0.9, 1.15))
