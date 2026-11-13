class_name MallPowerWalkBehaviour
extends EnemyBehaviour
## Mall Walker (and the Night Manager): at mid range with a clear path it stops
## and pumps its arms on the spot (the telegraph: the Windup clip, a whistle,
## the threat ring), then power-walks a burst at high speed. During the burst
## it keeps steering toward the player, but only slowly, so a sidestep makes it
## sail past. Clipping the player hurts and shoves; afterwards it stops to
## catch its breath (open to punishment) before chasing again.

enum Phase { NONE, WINDUP, BURST, RECOVER }

@export var min_range := 5.0
@export var max_range := 18.0
@export var windup := 0.75
@export var burst_speed := 7.0
@export var burst_time := 1.7
## How fast the burst can turn toward the player (degrees per second).
@export var steer_degrees := 50.0
@export var recover_time := 1.0
@export var cooldown := 5.0
@export var damage := 12.0
## The burst hits if the walker passes within this distance of the player.
@export var hit_radius := 1.3
## Shove (m/s) given to the player on a hit.
@export var shove := 6.0
@export var windup_sound: StringName = &"mall_walker_whistle"
@export var burst_sound: StringName = &"mall_walker_burst"

var _phase := Phase.NONE
var _time := 0.0
var _cool := 3.0
var _dir := Vector3.FORWARD
var _hit := false


func on_ready(_z: Zombie) -> void:
	_cool = randf_range(1.5, cooldown)


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	match _phase:
		Phase.WINDUP:
			return _windup(z, delta)
		Phase.BURST:
			return _burst(z, delta)
		Phase.RECOVER:
			return _recover(z, delta)
	if _cool <= 0.0 and z.state == Zombie.State.CHASE and z.target.alive:
		var d := z.distance_to_target()
		if d >= min_range and d <= max_range and z.has_line_of_sight() and _clear_path(z):
			_phase = Phase.WINDUP
			_time = windup
			_dir = _flat(z.target.global_position - z.global_position).normalized()
			z.play_animation(&"Windup", 0.12)
			Sfx.play_at(windup_sound, z.global_position + Vector3.UP * 1.6, 0.0, randf_range(0.95, 1.08))
			return true
	return false


func is_winding_up() -> bool:
	return _phase == Phase.WINDUP or _phase == Phase.BURST


## Breaks the windup (not a burst already under way).
func interrupt(z: Zombie) -> void:
	if _phase == Phase.WINDUP:
		_phase = Phase.NONE
		_cool = cooldown * 0.5
		z.play_animation(z.data.move_animation, 0.15)


func _windup(z: Zombie, delta: float) -> bool:
	_time -= delta
	var to := _flat(z.target.global_position - z.global_position)
	if to.length() > 0.1:
		_dir = to.normalized()
	z.face_toward(_dir, delta * 3.0)
	z.move_with(Vector3.ZERO)
	if _time <= 0.0:
		_phase = Phase.BURST
		_time = burst_time
		_hit = false
		z.play_animation(&"PowerWalk", 0.1)
		Sfx.play_at(burst_sound, z.global_position + Vector3.UP, 1.0, randf_range(0.95, 1.05))
	return true


func _burst(z: Zombie, delta: float) -> bool:
	_time -= delta
	# Steer toward the player, but no faster than steer_degrees per second.
	var to := _flat(z.target.global_position - z.global_position)
	if to.length() > 0.5 and not _hit:
		var want := to.normalized()
		var angle := _dir.signed_angle_to(want, Vector3.UP)
		var step := deg_to_rad(steer_degrees) * delta
		_dir = _dir.rotated(Vector3.UP, clampf(angle, -step, step))
	z.face_toward(_dir, delta * 8.0)
	z.move_with(_dir * burst_speed)
	if not _hit and z.target.alive and to.length() <= hit_radius:
		_hit = true
		z.target.take_damage(damage, z.global_position)
		z.target.velocity += _dir * shove + Vector3.UP * 2.0
		Sfx.play_at(&"bruiser_slam", z.global_position + Vector3.UP, -3.0, 1.35)
		_time = minf(_time, 0.2)
	# Stop when the time runs out, or early if something blocked the way.
	var blocked := _time < burst_time - 0.3 and _flat(z.get_real_velocity()).length() < burst_speed * 0.3
	if _time <= 0.0 or blocked:
		_phase = Phase.RECOVER
		_time = recover_time
		z.play_animation(&"Stagger", 0.12)
	return true


func _recover(z: Zombie, delta: float) -> bool:
	_time -= delta
	z.move_with(_dir * burst_speed * 0.25 * clampf(_time / recover_time - 0.5, 0.0, 1.0))
	if _time <= 0.0:
		_phase = Phase.NONE
		_cool = cooldown
		z.play_animation(z.data.move_animation, 0.2)
	return true


## Nothing solid at knee height between the walker and the player.
func _clear_path(z: Zombie) -> bool:
	var from := z.global_position + Vector3.UP * 0.5
	var to := z.target.global_position + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [z.get_rid()]
	return z.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
