class_name BossBurrow
extends BossMove
## The alpha goes under: it sinks into the floor (it cannot be hit while it is
## down), a ripple ring travels toward the player, stops, and grows as the
## warning; then the alpha bursts back up there and anyone inside the ring is
## hit. With `ring_count` it also brings strikes up around itself as it
## surfaces (tentacles, a ring of geysers): BossZones that follow the usual
## telegraph. Keep moving while the ripple follows you.

@export var sink_time := 0.7
@export var travel_time := 2.6
@export var travel_speed := 6.5
@export var surface_telegraph := 1.0
@export var radius := 3.2
@export var damage := 18.0
@export var color := Color(0.7, 0.35, 1)
@export var surface_clip: StringName = &"Emerge"
@export var surface_sound: StringName = &"boss_surface"
@export_group("Ring")
@export var ring_count := 0
@export var ring_spread := 5.0
@export var ring_radius := 1.6
@export var ring_damage := 10.0
@export var ring_prop := BossZone.Prop.SPIKES
@export var ring_prop_color := Color(0.55, 0.3, 0.9)

enum Step { NONE, SINK, TRAVEL, TELEGRAPH, RISE }

const RISE_TIME := 0.45

var _step := Step.NONE
var _t := 0.0
var _ripple: MeshInstance3D
var _layer := 0
var _depth := 3.0
var _model_y := 0.0


func begin(z: Zombie) -> void:
	super.begin(z)
	_step = Step.SINK
	_t = 0.0
	_layer = z.collision_layer
	_model_y = z.model_root.position.y
	_depth = 2.2 * z.data.body_scale


func tick(z: Zombie, delta: float) -> bool:
	_t += delta
	match _step:
		Step.SINK:
			z.move_with(Vector3.ZERO)
			_set_depth(z, clampf(_t / sink_time, 0.0, 1.0))
			if _t >= sink_time:
				_go_under(z)
		Step.TRAVEL:
			var to := z.target.global_position - z.global_position
			to.y = 0.0
			z.move_with(to.normalized() * travel_speed if to.length() > 0.8 else Vector3.ZERO)
			_place_ripple(z, 1.2 + 0.2 * sin(_t * 12.0), 0.6)
			if _t >= travel_time or to.length() < 0.8:
				_step = Step.TELEGRAPH
				_t = 0.0
				Sfx.play_at(&"boss_zone_warn", z.global_position + Vector3.UP * 0.5, 0.0, 0.8, 12.0)
		Step.TELEGRAPH:
			z.move_with(Vector3.ZERO)
			var k := clampf(_t / surface_telegraph, 0.0, 1.0)
			_place_ripple(z, lerpf(1.2, radius, k), 0.6 + 0.4 * k)
			if _t >= surface_telegraph:
				_surface(z)
		Step.RISE:
			z.move_with(Vector3.ZERO)
			_set_depth(z, 1.0 - clampf(_t / RISE_TIME, 0.0, 1.0))
			if _t >= RISE_TIME:
				_step = Step.NONE
				z.play_animation(z.data.move_animation, 0.25)
				return false
	return true


func cancel(z: Zombie) -> void:
	if _step == Step.NONE:
		return
	# Only the sink can be cut short: once under, it always comes back up.
	if _step == Step.SINK:
		_step = Step.NONE
		_set_depth(z, 0.0)


func filter_hit(_z: Zombie, amount: float, _at: Vector3, _headshot: bool) -> float:
	return 0.0 if _step == Step.TRAVEL or _step == Step.TELEGRAPH else amount


func is_winding_up() -> bool:
	return _step == Step.TELEGRAPH


func escape_from(z: Zombie, point: Vector3) -> Vector3:
	if _step != Step.TELEGRAPH:
		return Vector3.ZERO
	var away := point - z.global_position
	away.y = 0.0
	if away.length() > radius + 1.0:
		return Vector3.ZERO
	return away.normalized() if away.length() > 0.1 else Vector3.RIGHT


## True while it is under the floor (the alpha's aura and bar dim).
func is_under() -> bool:
	return _step == Step.TRAVEL or _step == Step.TELEGRAPH


func _go_under(z: Zombie) -> void:
	_step = Step.TRAVEL
	_t = 0.0
	z.collision_layer = 0
	z.model_root.visible = false
	_ripple = AlphaBossBehaviour.make_ring(color, 0.8)
	z.get_parent().add_child(_ripple)
	Fx.impact(z.get_parent(), z.global_position + Vector3.UP * 0.2, Vector3.UP, color)


func _surface(z: Zombie) -> void:
	_step = Step.RISE
	_t = 0.0
	z.collision_layer = _layer
	z.model_root.visible = true
	z.play_animation(surface_clip, 0.05)
	if is_instance_valid(_ripple):
		_ripple.queue_free()
	_ripple = null
	var at := z.global_position
	Sfx.play_at(surface_sound, at + Vector3.UP, 4.0, randf_range(0.92, 1.05), 18.0)
	for i in 10:
		var a := TAU * i / 10.0
		Fx.impact(z.get_parent(), at + Vector3(cos(a), 0.2, sin(a)) * radius * 0.7, Vector3.UP, color)
	var player := z.target
	var flat := player.global_position - at
	flat.y = 0.0
	if player.alive and flat.length() <= radius:
		player.take_damage(damage * z.damage_scale, at)
	z.target.add_shake(0.4)
	for i in ring_count:
		var a := TAU * i / ring_count + randf() * 0.3
		var zone := BossZone.new()
		zone.radius = ring_radius
		zone.telegraph = 0.9 + 0.12 * i
		zone.damage = ring_damage * z.damage_scale
		zone.color = color
		zone.prop = ring_prop
		zone.prop_color = ring_prop_color
		zone.prop_height = 3.2
		zone.source = z
		z.get_parent().add_child(zone)
		zone.global_position = floor_point(z, at + Vector3(cos(a), 0.0, sin(a)) * ring_spread)


func _place_ripple(z: Zombie, r: float, alpha: float) -> void:
	if not is_instance_valid(_ripple):
		return
	_ripple.global_position = z.global_position + Vector3.UP * 0.08
	_ripple.scale = Vector3(r, 2.0, r)
	(_ripple.material_override as StandardMaterial3D).albedo_color.a = alpha


func _set_depth(z: Zombie, k: float) -> void:
	z.model_root.position.y = _model_y - _depth * k
