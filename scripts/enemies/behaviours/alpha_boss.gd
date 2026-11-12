class_name AlphaBossBehaviour
extends EnemyBehaviour
## A finale alpha: a named, oversized version of a world's signature enemy
## (data/enemies/**/alpha_*.tres). On top of that enemy's own behaviour it has
## readable patterns of its own:
##
##   - Phases: at each health threshold it roars, speeds up and calls its
##     horde (it emits Zombie.phase_reached; the run director sends a pack).
##   - Ground slam: with the player close it rears up while a ring grows on
##     the floor (the telegraph), then the shockwave hits anyone standing
##     inside the ring. Back out of the ring or jump the shockwave.
##   - Volley (optional): at range it plants its feet, glows, and fires a fan
##     of slow orbs. Strafe between them.
##
## A pulsing ring under its feet marks it in a crowd.

@export var color := Color(1.0, 0.35, 0.75)
## Health fractions at which a new phase starts (highest first).
@export var phases := PackedFloat32Array([0.66, 0.33])
## Speed gained per phase (fraction of the base speed).
@export var phase_speed := 0.1

@export_group("Slam")
## The slam starts when the player is within this distance (0 = no slam).
@export var slam_trigger := 4.2
@export var slam_radius := 5.5
@export var slam_windup := 1.15
@export var slam_damage := 26.0
@export var slam_cooldown := 8.0
@export var slam_clip: StringName = &"Roar"
@export var slam_windup_sound: StringName = &"rounds_boss_windup"
@export var slam_sound: StringName = &"rounds_boss_slam"

@export_group("Volley")
## Orbs per volley (0 = no volley).
@export var volley_shots := 0
@export var volley_min_range := 7.0
@export var volley_max_range := 24.0
@export var volley_windup := 1.0
@export var volley_cooldown := 7.5
@export var volley_damage := 8.0
@export var volley_speed := 12.0
## Angle between neighbouring orbs.
@export var volley_spread_degrees := 11.0
## Above 0 the orbs are lobbed (see EnemyProjectile.launch).
@export var volley_arc := 0.0
@export var volley_size := 0.3
@export var volley_clip: StringName = &"Attack"
@export var volley_sound: StringName = &"rounds_boss_volley"

var _phase := 0
var _slam_cool := 4.0
var _slam_left := 0.0
var _volley_cool := 3.0
var _volley_left := 0.0
var _aura: MeshInstance3D
var _ring: MeshInstance3D
var _pulse := 0.0

static var _torus: TorusMesh


func on_ready(z: Zombie) -> void:
	_aura = _make_ring(color, 0.9)
	z.add_child(_aura)
	_aura.position.y = 0.06
	_aura.scale = Vector3.ONE * 1.35 * z.data.body_scale


func on_physics(z: Zombie, delta: float) -> bool:
	_pulse += delta
	if is_instance_valid(_aura):
		var k := 1.3 + 0.12 * sin(_pulse * 4.0)
		_aura.scale = Vector3(k, 1.0, k) * z.data.body_scale
	_slam_cool -= delta
	_volley_cool -= delta
	if _slam_left > 0.0:
		_tick_slam(z, delta)
		return true
	if _volley_left > 0.0:
		_tick_volley(z, delta)
		return true
	if z.state != Zombie.State.CHASE or not z.target.alive or z.is_winding_up():
		return false
	var d := z.distance_to_target()
	if slam_trigger > 0.0 and _slam_cool <= 0.0 and d <= slam_trigger:
		_begin_slam(z)
		return true
	if volley_shots > 0 and _volley_cool <= 0.0 and d >= volley_min_range and d <= volley_max_range and z.has_line_of_sight():
		_begin_volley(z)
		return true
	return false


func on_hit(z: Zombie, amount: float, _hit_position: Vector3, _headshot: bool) -> float:
	if _phase < phases.size() and (z.health - amount) / maxf(1.0, z.max_health) <= phases[_phase] and z.health - amount > 0.0:
		_phase += 1
		z.speed *= 1.0 + phase_speed
		_slam_cool = minf(_slam_cool, 1.5)
		z.enrage(4.0)
		z.phase_reached.emit(z, _phase)
	return amount


func on_death(_z: Zombie) -> void:
	_slam_left = 0.0
	_volley_left = 0.0
	_drop_ring()
	if is_instance_valid(_aura):
		_aura.queue_free()


func is_winding_up() -> bool:
	return _slam_left > 0.0 or _volley_left > 0.0


## Phases reached so far (0 at full health).
func phase() -> int:
	return _phase


# --- slam ------------------------------------------------------------------------

func _begin_slam(z: Zombie) -> void:
	_slam_cool = slam_cooldown * z.special_scale
	_slam_left = slam_windup
	z.play_animation(slam_clip, 0.1)
	Sfx.play_at(slam_windup_sound, z.global_position + Vector3.UP * 1.6, 2.0, 1.0, 14.0)
	_drop_ring()
	_ring = _make_ring(color, 1.0)
	z.get_parent().add_child(_ring)
	_ring.global_position = z.global_position + Vector3.UP * 0.08


func _tick_slam(z: Zombie, delta: float) -> void:
	_slam_left -= delta
	z.move_with(Vector3.ZERO)
	var k := clampf(1.0 - _slam_left / slam_windup, 0.0, 1.0)
	if is_instance_valid(_ring):
		var r := lerpf(0.6, slam_radius, k)
		_ring.scale = Vector3(r, 1.0 + 2.0 * k, r)
	if _slam_left > 0.0:
		return
	var at := z.global_position
	_drop_ring()
	Sfx.play_at(slam_sound, at + Vector3.UP, 4.0, 1.0, 16.0)
	for i in 10:
		var a := TAU * i / 10.0
		Fx.impact(z.get_parent(), at + Vector3(cos(a), 0.0, sin(a)) * slam_radius * 0.8 + Vector3.UP * 0.15, Vector3.UP, color)
	var player := z.target
	var flat := player.global_position - at
	flat.y = 0.0
	if player.alive and flat.length() <= slam_radius and player.is_on_floor():
		player.take_damage(slam_damage * z.damage_scale, at)
	z.play_animation(z.data.move_animation, 0.25)


func _drop_ring() -> void:
	if is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null


# --- volley ----------------------------------------------------------------------

func _begin_volley(z: Zombie) -> void:
	_volley_cool = volley_cooldown * z.special_scale
	_volley_left = volley_windup
	z.play_animation(volley_clip, 0.1)
	Sfx.play_at(slam_windup_sound, z.global_position + Vector3.UP * 1.6, 0.0, 1.25, 14.0)


func _tick_volley(z: Zombie, delta: float) -> void:
	_volley_left -= delta
	var to := z.target.global_position - z.global_position
	z.face_toward(Vector3(to.x, 0.0, to.z), delta)
	z.move_with(Vector3.ZERO)
	if _volley_left > 0.0:
		return
	var from := z.global_position + Vector3.UP * 1.5 * z.data.body_scale + Vector3(sin(z.rotation.y), 0.0, cos(z.rotation.y)) * 0.6
	var aim := z.target.global_position + Vector3.UP * 0.9 - from
	for i in volley_shots:
		var yaw := deg_to_rad(volley_spread_degrees) * (i - (volley_shots - 1) * 0.5)
		EnemyProjectile.launch(z.get_parent(), from, from + aim.rotated(Vector3.UP, yaw), volley_speed,
			volley_damage * z.damage_scale, color, volley_arc, volley_size, z)
	Sfx.play_at(volley_sound, from, 2.0, 1.0, 14.0)
	z.play_animation(z.data.move_animation, 0.25)


# --- visuals ---------------------------------------------------------------------

## A flat glowing ring of radius 1 (scale it to size).
static func _make_ring(tint: Color, alpha: float) -> MeshInstance3D:
	if _torus == null:
		_torus = TorusMesh.new()
		_torus.inner_radius = 0.93
		_torus.outer_radius = 1.0
		_torus.rings = 40
		_torus.ring_segments = 6
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(tint.lightened(0.2), alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	var ring := MeshInstance3D.new()
	ring.mesh = _torus
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring
