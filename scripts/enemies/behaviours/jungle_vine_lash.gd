class_name JungleVineLashBehaviour
extends EnemyBehaviour
## Overgrown: at mid range with a line of sight it rears up and drives both
## fists into the ground (the telegraph: a creak of wood, the threat ring, and
## a glowing line of creeping vines that grows along the ground toward the
## player). The line follows the player for the first part of the windup, then
## locks. When it is fully grown, thorny vines burst up along it: anyone
## standing on the line is hit, and the bramble patch left behind slows the
## player for a few seconds (JungleBramble). Step off the line. A headshot, a
## freeze or a heavy stagger during the windup cancels it.

@export var min_range := 4.5
@export var max_range := 17.0
@export var cooldown := 7.5
@export var windup := 1.15
## Fraction of the windup after which the line stops following the player.
@export_range(0.0, 1.0) var lock_fraction := 0.45
## How far past the player the line reaches.
@export var overshoot := 2.5
@export var width := 1.7
@export var damage := 14.0
@export var bramble_seconds := 3.5
@export var bramble_slow := 0.6
@export var windup_clip: StringName = &"Throw"
@export var windup_sound: StringName = &"jungle_vine_creak"
@export var burst_sound: StringName = &"jungle_vine_burst"
@export var color := Color(0.35, 1.0, 0.45)

var _cool := 3.0
var _winding := 0.0
var _dir := Vector3.FORWARD
var _length := 8.0
var _line: MeshInstance3D
var _line_material: StandardMaterial3D

static var _strip: BoxMesh


func on_ready(_z: Zombie) -> void:
	_cool = randf_range(2.0, cooldown)


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	if _winding > 0.0:
		_tick(z, delta)
		return true
	if _cool <= 0.0 and z.state == Zombie.State.CHASE and z.target.alive and not z.is_winding_up():
		var d := z.distance_to_target()
		if d >= min_range and d <= max_range and z.has_line_of_sight():
			_begin(z)
			return true
	return false


func on_hit(z: Zombie, amount: float, _hit_position: Vector3, headshot: bool) -> float:
	if headshot:
		interrupt(z)
	return amount


func on_death(_z: Zombie) -> void:
	_drop_line()


func is_winding_up() -> bool:
	return _winding > 0.0


## Cancels the lash while the vines are still creeping.
func interrupt(z: Zombie) -> void:
	if _winding > 0.0:
		_winding = 0.0
		_cool = cooldown * 0.5
		_drop_line()
		z.play_animation(z.data.move_animation, 0.15)


func _begin(z: Zombie) -> void:
	_winding = windup
	_cool = cooldown * z.special_scale
	_aim(z)
	z.play_animation(windup_clip, 0.1)
	Sfx.play_at(windup_sound, z.global_position + Vector3.UP, 1.0, randf_range(0.92, 1.05), 12.0)
	_drop_line()
	if _strip == null:
		_strip = BoxMesh.new()
		_strip.size = Vector3(1.0, 0.04, 1.0)
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_line_material.albedo_color = Color(color, 0.5)
	_line = MeshInstance3D.new()
	_line.mesh = _strip
	_line.material_override = _line_material
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	z.get_parent().add_child(_line)
	_place_line(z, 0.0)


func _tick(z: Zombie, delta: float) -> void:
	_winding -= delta
	var k := clampf(1.0 - _winding / windup, 0.0, 1.0)
	if k < lock_fraction:
		_aim(z)
	z.face_toward(_dir, delta * 2.0)
	z.move_with(Vector3.ZERO)
	_place_line(z, k)
	if _winding <= 0.0:
		_release(z)


## Points the line at the player (flat), long enough to run past them.
func _aim(z: Zombie) -> void:
	var to := z.target.global_position - z.global_position
	to.y = 0.0
	if to.length() > 0.1:
		_dir = to.normalized()
		_length = clampf(to.length() + overshoot, min_range, max_range + overshoot)


## The glowing line creeps out to `k` of its length and pulses brighter as it grows.
func _place_line(z: Zombie, k: float) -> void:
	if not is_instance_valid(_line):
		return
	var grown := maxf(0.3, _length * ease(k, 0.6))
	var start := z.global_position + _dir * 0.8
	var b := Basis.looking_at(_dir, Vector3.UP)
	b = Basis(b.x * width * (0.5 + 0.5 * k), b.y, b.z * grown)
	_line.global_transform = Transform3D(b, start + _dir * grown * 0.5 + Vector3.UP * 0.06)
	_line_material.albedo_color = Color(color, 0.35 + 0.45 * k + 0.15 * sin(k * 30.0))


func _release(z: Zombie) -> void:
	_drop_line()
	var start := z.global_position + _dir * 0.8
	var bramble := JungleBramble.new()
	bramble.start = start
	bramble.direction = _dir
	bramble.length = _length
	bramble.width = width
	bramble.seconds = bramble_seconds
	bramble.slow = bramble_slow
	z.get_parent().add_child(bramble)
	Sfx.play_at(burst_sound, start + _dir * _length * 0.5 + Vector3.UP, 3.0, randf_range(0.95, 1.05), 14.0)
	var player := z.target
	if player.alive and bramble.covers(player.global_position):
		player.take_damage(damage * z.damage_scale, start)
	z.play_animation(z.data.move_animation, 0.25)


func _drop_line() -> void:
	if is_instance_valid(_line):
		_line.queue_free()
	_line = null
