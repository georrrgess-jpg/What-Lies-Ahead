class_name FrightGhostFadeBehaviour
extends EnemyBehaviour
## Bedsheet Ghost (Ghost Train): glides along with a gentle hover, and every
## few seconds, once it is in the fight, it stops and throws its arms up with a
## wail (the tell: the Roar clip, the sound, the threat ring), then fades half
## transparent and darts in faster for a moment. A faded ghost is still
## hittable and takes full damage; its eyes keep glowing. A headshot, freeze
## or heavy stagger during the tell cancels the fade.

## Seconds between fades (a random pick in this range).
@export var interval := Vector2(5.0, 8.0)
## Length of the tell and of the fade.
@export var tell := 0.6
@export var fade_seconds := 2.2
## How see-through a faded ghost is (0 = solid, 1 = invisible).
@export var fade_amount := 0.62
## Speed multiplier while faded.
@export var dash_speed := 1.55
## Only fades within this distance of the player.
@export var max_range := 22.0
## The hover: height and seconds per bob.
@export var hover_height := 0.07
@export var hover_seconds := 1.3
@export var tell_clip: StringName = &"Roar"
@export var tell_sound: StringName = &"fright_ghost_wail"
@export var fade_sound: StringName = &"fright_ghost_fade"

const FADE_RAMP := 0.25

var _cool := 4.0
var _telling := 0.0
var _faded := 0.0
var _shown := 0.0
var _time := 0.0
var _meshes: Array[GeometryInstance3D] = []


func on_ready(z: Zombie) -> void:
	_cool = randf_range(2.5, interval.y)
	_time = randf() * hover_seconds
	for node in z.model_root.find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(node as GeometryInstance3D)


func on_physics(z: Zombie, delta: float) -> bool:
	_time += delta
	z.model_root.position.y = hover_height * (1.0 + sin(TAU * _time / hover_seconds))
	if _telling > 0.0:
		_telling -= delta
		z.face_toward(BossMove.flat_to_target(z), delta * 1.5)
		z.move_with(Vector3.ZERO)
		if _telling <= 0.0:
			_begin_fade(z)
		return true
	if _faded > 0.0:
		_faded -= delta
		z.speed_multiplier = dash_speed
		_set_fade(minf(1.0, minf(_faded, fade_seconds - _faded) / FADE_RAMP))
		if _faded <= 0.0:
			_set_fade(0.0)
		return false
	_cool -= delta
	if _cool <= 0.0 and z.state == Zombie.State.CHASE and z.target.alive and z.distance_to_target() < max_range:
		_begin_tell(z)
		return true
	return false


func on_hit(z: Zombie, amount: float, _hit_position: Vector3, headshot: bool) -> float:
	if headshot:
		interrupt(z)
	return amount


func interrupt(z: Zombie) -> void:
	if _telling <= 0.0:
		return
	_telling = 0.0
	_cool = randf_range(interval.x, interval.y)
	z.play_animation(&"Stagger", 0.05)


func on_death(z: Zombie) -> void:
	_telling = 0.0
	_faded = 0.0
	_set_fade(0.0)
	z.model_root.position.y = 0.0


func is_winding_up() -> bool:
	return _telling > 0.0


func _begin_tell(z: Zombie) -> void:
	_telling = tell
	z.play_animation(tell_clip, 0.1)
	Sfx.play_at(tell_sound, z.global_position + Vector3.UP * 1.6, 0.0, randf_range(0.92, 1.1))


func _begin_fade(z: Zombie) -> void:
	_faded = fade_seconds
	_cool = randf_range(interval.x, interval.y) + fade_seconds
	z.play_animation(z.data.move_animation, 0.2)
	Sfx.play_at(fade_sound, z.global_position + Vector3.UP * 1.4, -2.0, randf_range(0.95, 1.08))


## k: 0 = solid, 1 = fully faded (fade_amount).
func _set_fade(k: float) -> void:
	var t := fade_amount * k
	if is_equal_approx(t, _shown):
		return
	_shown = t
	for gi in _meshes:
		if is_instance_valid(gi):
			gi.transparency = t
