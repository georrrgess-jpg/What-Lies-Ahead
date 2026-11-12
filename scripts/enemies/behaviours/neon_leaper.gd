class_name NeonLeaperBehaviour
extends EnemyBehaviour
## Hover Courier: crouches while its hover boots flare (the telegraph: the
## threat ring warns and the boots whine), then leaps in a high arc to land
## just short of the player. Leaps reach raised platforms and cross gaps the
## navmesh would walk around, so high ground is never fully safe. Landing
## close to the player sends out a shockwave hit.

@export var min_range := 4.5
@export var max_range := 12.0
## Longer leaps are allowed when the player is on a different level.
@export var climb_range := 17.0
@export var cooldown := 5.5
@export var telegraph := 0.6
@export var flight_time := 0.8
## Arc height above the higher end of the leap.
@export var apex := 2.0
## Lands this far short of the player.
@export var land_short := 1.7
@export var land_damage := 14.0
@export var land_radius := 2.1
@export var recover := 0.55
@export var crouch_clip: StringName = &"Crouch"
@export var flight_clip: StringName = &"Leap"
@export var launch_sound: StringName = &"neon_leap_charge"
@export var land_sound: StringName = &"neon_leap_land"
@export var color := Color(0.3, 0.95, 1.0)

var _cool := 2.0
var _crouch := 0.0
var _flight := -1.0
var _recover := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _peak := 0.0


func on_ready(_z: Zombie) -> void:
	_cool = randf_range(1.5, cooldown)


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	if _flight >= 0.0:
		_fly(z, delta)
		return true
	if _crouch > 0.0:
		_crouch -= delta
		var to := z.target.global_position - z.global_position
		z.face_toward(Vector3(to.x, 0.0, to.z), delta)
		z.move_with(Vector3.ZERO)
		if _crouch <= 0.0:
			_launch(z)
		return true
	if _recover > 0.0:
		_recover -= delta
		z.move_with(Vector3.ZERO)
		if _recover <= 0.0:
			z.play_animation(z.data.move_animation, 0.15)
		return true
	if _cool <= 0.0 and z.state == Zombie.State.CHASE and z.is_on_floor() and _wants_leap(z):
		_cool = cooldown * randf_range(0.85, 1.2)
		_crouch = telegraph
		z.play_animation(crouch_clip, 0.08)
		Sfx.play_at(launch_sound, z.global_position + Vector3.UP, 0.0, randf_range(0.95, 1.05))
		return true
	return false


func is_winding_up() -> bool:
	return _crouch > 0.0 or _flight >= 0.0


## In range, in sight, and a landing spot on the navmesh beside the player.
func _wants_leap(z: Zombie) -> bool:
	var d := z.distance_to_target()
	var level_gap := absf(z.target.global_position.y - z.global_position.y) > 1.2
	if d < min_range or d > (climb_range if level_gap else max_range) or not z.has_line_of_sight():
		return false
	var flat := z.target.global_position - z.global_position
	flat.y = 0.0
	var want := z.target.global_position - flat.normalized() * land_short
	var spot := NavigationServer3D.map_get_closest_point(z.get_world_3d().navigation_map, want)
	# Only leap onto solid ground at the player's level, near where we aimed.
	if Vector2(spot.x - want.x, spot.z - want.z).length() > 1.2 or absf(spot.y - z.target.global_position.y) > 0.6:
		return false
	_to = spot
	return true


func _launch(z: Zombie) -> void:
	_from = z.global_position
	_peak = apex + absf(_to.y - _from.y) * 0.75
	_flight = 0.0
	z.play_animation(flight_clip, 0.05)
	Fx.impact(z.get_parent(), _from + Vector3.UP * 0.1, Vector3.UP, color)


## Scripted arc: start and end on the navmesh, high enough to clear railings.
func _fly(z: Zombie, delta: float) -> void:
	_flight += delta
	var t := clampf(_flight / flight_time, 0.0, 1.0)
	var p := _from.lerp(_to, t)
	p.y += 4.0 * _peak * t * (1.0 - t)
	z.global_position = p
	z.velocity = Vector3.ZERO
	var to := _to - _from
	z.face_toward(Vector3(to.x, 0.0, to.z), delta * 2.0)
	if t >= 1.0:
		_land(z)


func _land(z: Zombie) -> void:
	_flight = -1.0
	_recover = recover
	z.global_position = _to + Vector3.UP * 0.05
	z.reset_stall()
	z.play_animation(crouch_clip, 0.05)
	Sfx.play_at(land_sound, _to + Vector3.UP * 0.3, 0.0, randf_range(0.9, 1.05))
	for i in 8:
		var a := TAU * i / 8.0
		Fx.impact(z.get_parent(), _to + Vector3(cos(a), 0.15, sin(a)) * 0.9, Vector3(cos(a), 0.6, sin(a)), color)
	var player := z.target
	if player.alive and player.global_position.distance_to(_to) <= land_radius:
		player.take_damage(land_damage, _to)
