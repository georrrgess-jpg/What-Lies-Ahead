class_name GulchBurrowBehaviour
extends EnemyBehaviour
## Prospector: at range on the same level as the player it digs in (the
## telegraph: the Dig clip, a pick-and-shovel scrape, the threat ring; a
## headshot or a heavy stagger stops it), sinks out of sight and tunnels
## toward the player under a trail of dust. It stops a short way off, a dust
## ring grows on the ground for `surface_telegraph` seconds, then it bursts up
## with a dust ring that hurts anyone still inside. It cannot be hit while it
## is under. Step out of the ring.

@export var min_range := 7.0
@export var max_range := 18.0
@export var cooldown := 9.0
## Seconds before the first dig (a random pick in this range).
@export var first_dig := Vector2(2.0, 4.5)
@export var dig_time := 0.8
@export var travel_speed := 6.0
@export var travel_time := 2.4
## It surfaces this far from the player (on the line it travelled).
@export var stop_distance := 1.4
@export var surface_telegraph := 0.9
@export var radius := 2.2
@export var damage := 10.0
@export var color := Color(0.93, 0.7, 0.42)
@export var dig_clip: StringName = &"Dig"
@export var surface_clip: StringName = &"Emerge"
@export var dig_sound: StringName = &"gulch_prospector_dig"
@export var surface_sound: StringName = &"gulch_prospector_pop"

enum Step { NONE, DIG, UNDER, RING, RISE }

const RISE_TIME := 0.45
const PUFF_EVERY := 0.18

var _step := Step.NONE
var _t := 0.0
var _cool := 3.0
var _puff := 0.0
var _layer := 0
var _model_y := 0.0
var _depth := 2.0
var _ring: MeshInstance3D


func on_ready(z: Zombie) -> void:
	_cool = randf_range(first_dig.x, first_dig.y)
	_layer = z.collision_layer
	_model_y = z.model_root.position.y
	_depth = 2.1 * z.data.body_scale


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	match _step:
		Step.NONE:
			if _cool <= 0.0 and z.state == Zombie.State.CHASE and z.target.alive and _wants_dig(z):
				_begin(z)
				return true
			return false
		Step.DIG:
			_t += delta
			z.move_with(Vector3.ZERO)
			_set_depth(z, clampf((_t - dig_time * 0.5) / (dig_time * 0.5), 0.0, 1.0))
			if _t >= dig_time:
				_go_under(z)
		Step.UNDER:
			_t += delta
			var to := z.target.global_position - z.global_position
			to.y = 0.0
			var close := to.length() <= stop_distance
			z.move_with(Vector3.ZERO if close else to.normalized() * travel_speed)
			_puff -= delta
			if _puff <= 0.0:
				_puff = PUFF_EVERY
				Fx.impact(z.get_parent(), z.global_position + Vector3.UP * 0.15, Vector3.UP, color)
			_place_ring(z, 0.9 + 0.15 * sin(_t * 14.0), 0.55)
			if close or _t >= travel_time:
				_step = Step.RING
				_t = 0.0
				Sfx.play_at(&"rounds_boss_zone_warn", z.global_position + Vector3.UP * 0.5, -2.0, 1.15, 12.0)
		Step.RING:
			_t += delta
			z.move_with(Vector3.ZERO)
			var k := clampf(_t / surface_telegraph, 0.0, 1.0)
			_place_ring(z, lerpf(0.9, radius, k), 0.55 + 0.4 * k)
			if _t >= surface_telegraph:
				_surface(z)
		Step.RISE:
			_t += delta
			z.move_with(Vector3.ZERO)
			_set_depth(z, 1.0 - clampf(_t / RISE_TIME, 0.0, 1.0))
			if _t >= RISE_TIME:
				_step = Step.NONE
				z.play_animation(z.data.move_animation, 0.25)
				return false
	return true


func on_hit(z: Zombie, amount: float, _hit_position: Vector3, headshot: bool) -> float:
	if _step == Step.UNDER or _step == Step.RING:
		return 0.0
	if headshot and _step == Step.DIG:
		interrupt(z)
	return amount


## Only the dig can be stopped: once under, it always comes back up.
func interrupt(z: Zombie) -> void:
	if _step != Step.DIG:
		return
	_step = Step.NONE
	_cool = cooldown * 0.5
	_set_depth(z, 0.0)
	z.play_animation(&"Stagger", 0.05)


func on_death(z: Zombie) -> void:
	_clear_ring()
	_set_depth(z, 0.0)


func is_winding_up() -> bool:
	return _step == Step.DIG or _step == Step.RING


func _wants_dig(z: Zombie) -> bool:
	var d := z.distance_to_target()
	if d < min_range or d > max_range:
		return false
	return absf(z.target.global_position.y - z.global_position.y) < 0.8 and z.is_on_floor()


func _begin(z: Zombie) -> void:
	_step = Step.DIG
	_t = 0.0
	_cool = cooldown
	z.play_animation(dig_clip, 0.1)
	Sfx.play_at(dig_sound, z.global_position + Vector3.UP * 0.6, 0.0, randf_range(0.92, 1.06))
	Fx.impact(z.get_parent(), z.global_position + Vector3.UP * 0.2, Vector3.UP, color)


func _go_under(z: Zombie) -> void:
	_step = Step.UNDER
	_t = 0.0
	_puff = 0.0
	z.collision_layer = 0
	z.model_root.visible = false
	_clear_ring()
	_ring = AlphaBossBehaviour.make_ring(color, 0.55)
	z.get_parent().add_child(_ring)


func _surface(z: Zombie) -> void:
	_step = Step.RISE
	_t = 0.0
	z.collision_layer = _layer
	z.model_root.visible = true
	z.play_animation(surface_clip, 0.05)
	_clear_ring()
	var at := z.global_position
	Sfx.play_at(surface_sound, at + Vector3.UP, 2.0, randf_range(0.92, 1.06), 14.0)
	for i in 8:
		var a := TAU * i / 8.0
		Fx.impact(z.get_parent(), at + Vector3(cos(a), 0.2, sin(a)) * radius * 0.7, Vector3.UP, color)
	var flat := z.target.global_position - at
	flat.y = 0.0
	if z.target.alive and flat.length() <= radius and absf(z.target.global_position.y - at.y) < 1.5:
		z.target.take_damage(damage * z.damage_scale, at)
		z.target.add_shake(0.25)


func _place_ring(z: Zombie, r: float, alpha: float) -> void:
	if not is_instance_valid(_ring):
		return
	_ring.global_position = z.global_position + Vector3.UP * 0.08
	_ring.scale = Vector3(r, 2.0, r)
	(_ring.material_override as StandardMaterial3D).albedo_color.a = alpha


func _clear_ring() -> void:
	if is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null


func _set_depth(z: Zombie, k: float) -> void:
	z.model_root.position.y = _model_y - _depth * k
