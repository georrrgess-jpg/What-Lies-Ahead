class_name NeonSprayTaggerBehaviour
extends EnemyBehaviour
## Neon Punk: at mid range with a clear line, stops and rattles its spray can
## (the telegraph: the threat ring warns and the rattle is audible), then
## sprays a short fan of glowing paint blobs at the player. A headshot during
## the rattle knocks the can down and cancels the burst. Only a few punks tag
## at once (the rest keep walking), so volleys never stack into a wall of
## paint. Melee still works up close.

@export var min_range := 4.5
@export var max_range := 16.0
@export var cooldown := 4.2
@export var windup := 0.8
@export var shots := 3
@export var shot_gap := 0.12
@export var damage := 6.0
@export var projectile_speed := 17.0
@export var fan_degrees := 6.0
## Paint colours; each punk picks one for its whole life.
@export var colors: Array[Color] = [Color(1.0, 0.25, 0.8), Color(0.25, 1.0, 0.9), Color(0.75, 1.0, 0.25)]
@export var windup_clip: StringName = &"Spray"
@export var windup_sound: StringName = &"neon_spray_rattle"
@export var fire_sound: StringName = &"neon_spray_hiss"
## How many punks may be shaking or spraying at the same time.
@export var max_concurrent := 2

## Behaviours currently shaking or spraying (weak references, shared by all punks).
static var _busy: Array = []

var _cool := 2.5
var _winding := 0.0
var _left := 0
var _gap := 0.0
var _color := Color.WHITE
var _owner: WeakRef


func on_ready(z: Zombie) -> void:
	_owner = weakref(z)
	_cool = randf_range(1.2, cooldown)
	_color = colors[randi() % colors.size()] if not colors.is_empty() else Color.WHITE


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	if _winding > 0.0:
		_winding -= delta
		_hold(z, delta)
		if _winding <= 0.0:
			_left = shots
			_gap = 0.0
		return true
	if _left > 0:
		_hold(z, delta)
		_gap -= delta
		if _gap <= 0.0:
			_gap = shot_gap
			_spray(z, shots - _left)
			_left -= 1
			if _left == 0:
				z.play_animation(z.data.move_animation, 0.2)
		return true
	if _cool <= 0.0 and z.state == Zombie.State.CHASE:
		var d := z.distance_to_target()
		if d >= min_range and d <= max_range and z.has_line_of_sight():
			if _busy_count() >= max_concurrent:
				_cool = 0.6
				return false
			_busy.append(weakref(self))
			_cool = cooldown * randf_range(0.85, 1.2)
			_winding = windup
			z.play_animation(windup_clip, 0.1)
			Sfx.play_at(windup_sound, z.global_position + Vector3.UP * 1.3, -1.0, randf_range(0.95, 1.08))
			return true
	return false


## A headshot while it is shaking the can makes it fumble the burst.
func on_hit(z: Zombie, amount: float, _hit_position: Vector3, headshot: bool) -> float:
	if headshot and _winding > 0.0:
		_winding = 0.0
		_left = 0
		z.play_animation(z.data.move_animation, 0.15)
	return amount


func is_winding_up() -> bool:
	return _winding > 0.0 or _left > 0


## Live sprayers: still shaking or spraying, on a zombie that is still alive.
static func _busy_count() -> int:
	_busy = _busy.filter(func(w: WeakRef) -> bool:
		var b = w.get_ref()
		if b == null or not b.is_winding_up():
			return false
		var z = b._owner.get_ref() if b._owner else null
		return z != null and not z.is_dead())
	return _busy.size()


func _hold(z: Zombie, delta: float) -> void:
	var to := z.target.global_position - z.global_position
	z.face_toward(Vector3(to.x, 0.0, to.z), delta)
	z.move_with(Vector3.ZERO)


## One blob of the fan; index 0 is the leftmost.
func _spray(z: Zombie, index: int) -> void:
	var forward := Vector3(sin(z.rotation.y), 0.0, cos(z.rotation.y))
	var from := z.global_position + Vector3.UP * 1.3 * z.data.body_scale + forward * 0.45
	var aim := z.target.global_position + Vector3.UP * 1.0
	# Lead a little so a straight strafe is not a free dodge.
	aim += z.target.velocity * clampf(from.distance_to(aim) / projectile_speed, 0.0, 1.0) * 0.5
	var offset := (index - (shots - 1) * 0.5) * deg_to_rad(fan_degrees)
	aim = from + (aim - from).rotated(Vector3.UP, offset)
	EnemyProjectile.launch(z.get_parent(), from, aim, projectile_speed, damage, _color, 0.12, 0.15, z)
	Sfx.play_at(fire_sound, from, -3.0, randf_range(0.92, 1.1))
