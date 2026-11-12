class_name FrostSkiRushBehaviour
extends EnemyBehaviour
## Ski Racer: at mid range with a clear run at the player it drops into a
## downhill tuck (the telegraph: crouch, lean, a rising whoosh; the threat
## ring warns), locks its heading, then rushes straight along that line at
## high speed. Passing close to the player bowls them over. Stepping sideways
## out of the locked line is the dodge. Afterwards it skids to a stop and
## shakes itself off before chasing again.

enum Phase { NONE, TUCK, RUSH, SKID }

@export var min_range := 6.0
@export var max_range := 22.0
## Seconds crouched in the tuck before the rush; the heading locks partway in.
@export var tuck_time := 0.9
@export_range(0.0, 1.0) var lock_fraction := 0.45
@export var rush_speed := 12.5
@export var rush_time := 1.5
@export var skid_time := 0.8
@export var cooldown := 5.5
@export var damage := 12.0
## The rush hits if the racer passes within this distance of the player.
@export var hit_radius := 1.35
## Shove (m/s) given to the player on a hit.
@export var shove := 7.0
@export var tuck_sound: StringName = &"frost_ski_tuck"
@export var rush_sound: StringName = &"frost_ski_rush"

var _phase := Phase.NONE
var _time := 0.0
var _cool := 3.0
var _dir := Vector3.FORWARD
var _hit := false


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	match _phase:
		Phase.TUCK:
			return _tuck(z, delta)
		Phase.RUSH:
			return _rush(z, delta)
		Phase.SKID:
			return _skid(z, delta)
	if _cool <= 0.0 and z.state == Zombie.State.CHASE and z.target.alive:
		var d := z.distance_to_target()
		if d >= min_range and d <= max_range and z.has_line_of_sight() and _clear_run(z):
			_phase = Phase.TUCK
			_time = tuck_time
			_dir = _flat(z.target.global_position - z.global_position).normalized()
			z.play_animation(&"Tuck", 0.12)
			Sfx.play_at(tuck_sound, z.global_position + Vector3.UP, 0.0, randf_range(0.95, 1.05))
			return true
	return false


func is_winding_up() -> bool:
	return _phase == Phase.TUCK or _phase == Phase.RUSH


## Breaks the tuck (not a rush already under way).
func interrupt(z: Zombie) -> void:
	if _phase == Phase.TUCK:
		_phase = Phase.NONE
		_cool = cooldown * 0.5
		z.play_animation(z.data.move_animation, 0.15)


func _tuck(z: Zombie, delta: float) -> bool:
	_time -= delta
	# Track the player until the heading locks, then commit to the line.
	if _time > tuck_time * (1.0 - lock_fraction):
		var to := _flat(z.target.global_position - z.global_position)
		if to.length() > 0.1:
			_dir = to.normalized()
	z.face_toward(_dir, delta * 2.5)
	z.move_with(Vector3.ZERO)
	if _time <= 0.0:
		_phase = Phase.RUSH
		_time = rush_time
		_hit = false
		Sfx.play_at(rush_sound, z.global_position + Vector3.UP, 2.0, randf_range(0.95, 1.05))
	return true


func _rush(z: Zombie, delta: float) -> bool:
	_time -= delta
	z.face_toward(_dir, delta * 3.0)
	z.move_with(_dir * rush_speed)
	if not _hit and z.target.alive and _flat(z.target.global_position - z.global_position).length() <= hit_radius:
		_hit = true
		z.target.take_damage(damage, z.global_position)
		z.target.velocity += _dir * shove + Vector3.UP * 2.0
		Sfx.play_at(&"bruiser_slam", z.global_position + Vector3.UP, -2.0, 1.3)
	_spray(z, 0.6)
	# Stop when the time runs out, or early if a wall or rail blocked the run.
	var blocked := _time < rush_time - 0.25 and _flat(z.get_real_velocity()).length() < rush_speed * 0.35
	if _time <= 0.0 or blocked:
		_phase = Phase.SKID
		_time = skid_time
		z.play_animation(&"Stagger", 0.1)
	return true


func _skid(z: Zombie, delta: float) -> bool:
	_time -= delta
	var k := clampf(_time / skid_time, 0.0, 1.0)
	z.move_with(_dir * rush_speed * 0.3 * k)
	_spray(z, k)
	if _time <= 0.0:
		_phase = Phase.NONE
		_cool = cooldown
		z.play_animation(z.data.move_animation, 0.2)
	return true


## Snow kicked up from the skis.
func _spray(z: Zombie, strength: float) -> void:
	if randf() < 0.35 * strength:
		var at := z.global_position + Vector3(randf_range(-0.3, 0.3), 0.1, randf_range(-0.3, 0.3))
		Fx.impact(z.get_parent(), at, Vector3.UP - _dir * 0.6, Color(0.88, 0.92, 1.0))


## Nothing solid at knee height between the racer and a point a little past the player.
func _clear_run(z: Zombie) -> bool:
	var from := z.global_position + Vector3.UP * 0.5
	var to := z.target.global_position + Vector3.UP * 0.5
	to += _flat(to - from).normalized() * 2.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [z.get_rid()]
	return z.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
