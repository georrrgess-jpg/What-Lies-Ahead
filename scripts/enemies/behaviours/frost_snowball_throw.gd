class_name FrostSnowballBehaviour
extends EnemyBehaviour
## Yeti: at mid range with a line of sight it plants its feet, roars and rears
## back with a snowball over its head (the telegraph; the threat ring warns),
## then hurls it in a high arc at where the player is heading. A headshot
## during the windup staggers it and the throw is lost. Melee still works up
## close.

@export var min_range := 7.0
@export var max_range := 24.0
@export var cooldown := 6.0
@export var windup := 1.05
@export var damage := 10.0
@export var projectile_speed := 15.0
@export var arc := 0.85
@export var size := 0.42
## How much of the player's motion the throw leads (0 = aims at the feet).
@export var lead := 0.55
@export var roar_sound: StringName = &"frost_yeti_roar"
@export var throw_sound: StringName = &"frost_snowball_throw"

## Fraction of the Throw clip at which the arms come forward.
const RELEASE_FRACTION := 15.0 / 28.0

var _cool := 3.0
var _winding := 0.0
var _anim: AnimationPlayer
var _held: MeshInstance3D

static var _ball_mesh: SphereMesh


func on_ready(z: Zombie) -> void:
	_anim = z.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_cool = randf_range(1.5, cooldown)


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	if _winding > 0.0:
		_winding -= delta
		var to := z.target.global_position - z.global_position
		z.face_toward(Vector3(to.x, 0, to.z), delta)
		z.move_with(Vector3.ZERO)
		if _winding <= 0.0:
			_release(z)
		return true
	if _cool <= 0.0 and z.state == Zombie.State.CHASE and z.target.alive:
		var d := z.distance_to_target()
		if d >= min_range and d <= max_range and z.has_line_of_sight():
			_begin(z)
			return true
	return false


func on_hit(z: Zombie, amount: float, _hit_position: Vector3, headshot: bool) -> float:
	if headshot and _winding > 0.0:
		_winding = 0.0
		_cool = cooldown * 0.6
		_drop_ball()
		z.play_animation(&"Hit", 0.05)
		Sfx.play_at(&"frost_snowball_hit", z.global_position + Vector3.UP * 2.0, -4.0, 1.2)
	return amount


func on_death(_z: Zombie) -> void:
	_drop_ball()


func is_winding_up() -> bool:
	return _winding > 0.0


func _begin(z: Zombie) -> void:
	_cool = cooldown
	_winding = windup
	if _anim and _anim.has_animation("Throw"):
		var clip := _anim.get_animation("Throw")
		_anim.play("Throw", 0.1)
		_anim.speed_scale = clip.length * RELEASE_FRACTION / windup
	Sfx.play_at(roar_sound, z.global_position + Vector3.UP * 1.8, 2.0, randf_range(0.92, 1.05))
	_hold_ball(z)


## A snowball appears between the Yeti's raised hands during the windup.
func _hold_ball(z: Zombie) -> void:
	if _ball_mesh == null:
		_ball_mesh = SphereMesh.new()
		_ball_mesh.radius = 1.0
		_ball_mesh.height = 2.0
		_ball_mesh.radial_segments = 12
		_ball_mesh.rings = 6
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.95, 1.0)
		m.roughness = 0.8
		_ball_mesh.material = m
	_held = MeshInstance3D.new()
	_held.mesh = _ball_mesh
	_held.scale = Vector3.ONE * size
	_held.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	z.add_child(_held)
	_held.position = Vector3(0, 2.25 * z.data.body_scale, -0.05)


func _drop_ball() -> void:
	if is_instance_valid(_held):
		_held.queue_free()
	_held = null


func _release(z: Zombie) -> void:
	var from := _held.global_position if is_instance_valid(_held) else z.global_position + Vector3.UP * 2.5 * z.data.body_scale
	_drop_ball()
	var t := clampf(z.distance_to_target() / projectile_speed, 0.0, 1.6)
	var aim := z.target.global_position + Vector3.UP * 0.9 + z.target.velocity * Vector3(1, 0, 1) * t * lead
	FrostSnowball.lob(z.get_parent(), from, aim, projectile_speed, damage, size, arc, z)
	Sfx.play_at(throw_sound, from, 0.0, randf_range(0.9, 1.05))
	z.play_animation(z.data.move_animation, 0.35)
