class_name LavaCoconutLobBehaviour
extends EnemyBehaviour
## Tiki Bartender (and Kahuna Krakatoa's lava bombs): at mid range with a line
## of sight it plants its feet and rears back with a coconut held overhead
## (the telegraph: the Throw clip, a call, the threat ring), then lobs it in a
## high arc at where the player is heading. A headshot during the windup
## staggers it and the throw is lost. Melee still works up close.

@export var min_range := 6.0
@export var max_range := 22.0
@export var cooldown := 5.5
@export var windup := 0.95
@export var damage := 9.0
@export var projectile_speed := 14.0
@export var arc := 0.8
@export var size := 0.3
## How much of the player's motion the throw leads (0 = aims at the feet).
@export var lead := 0.5
@export var color := Color(0.62, 0.4, 0.22)
## The held object: its colour and glow (0 = a plain coconut).
@export var held_color := Color(0.36, 0.22, 0.12)
@export var held_glow := 0.0
@export var windup_sound: StringName = &"lava_bartender_call"
@export var throw_sound: StringName = &"lava_coconut_throw"

## Fraction of the Throw clip at which the arms come forward.
const RELEASE_FRACTION := 15.0 / 28.0

var _cool := 3.0
var _winding := 0.0
var _anim: AnimationPlayer
var _held: MeshInstance3D
var _held_mesh: SphereMesh


func on_ready(z: Zombie) -> void:
	_anim = z.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_cool = randf_range(1.5, cooldown)
	_held_mesh = SphereMesh.new()
	_held_mesh.radius = 1.0
	_held_mesh.height = 2.0
	_held_mesh.radial_segments = 10
	_held_mesh.rings = 6
	var m := StandardMaterial3D.new()
	m.albedo_color = held_color
	m.roughness = 0.7
	if held_glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = held_glow
	_held_mesh.material = m


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
	if headshot:
		interrupt(z)
	return amount


func interrupt(z: Zombie) -> void:
	if _winding <= 0.0:
		return
	_winding = 0.0
	_cool = cooldown * 0.6
	_drop()
	z.play_animation(&"Stagger", 0.05)


func on_death(_z: Zombie) -> void:
	_drop()


func is_winding_up() -> bool:
	return _winding > 0.0


func _begin(z: Zombie) -> void:
	_cool = cooldown
	_winding = windup
	if _anim and _anim.has_animation("Throw"):
		var clip := _anim.get_animation("Throw")
		_anim.play("Throw", 0.1)
		_anim.speed_scale = clip.length * RELEASE_FRACTION / windup
	Sfx.play_at(windup_sound, z.global_position + Vector3.UP * 1.8, 0.0, randf_range(0.92, 1.06))
	_held = MeshInstance3D.new()
	_held.mesh = _held_mesh
	_held.scale = Vector3.ONE * size
	_held.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	z.add_child(_held)
	_held.position = Vector3(0, 2.2 * z.data.body_scale, -0.05)


func _drop() -> void:
	if is_instance_valid(_held):
		_held.queue_free()
	_held = null


func _release(z: Zombie) -> void:
	var from := _held.global_position if is_instance_valid(_held) else z.global_position + Vector3.UP * 2.4 * z.data.body_scale
	_drop()
	var t := clampf(z.distance_to_target() / projectile_speed, 0.0, 1.6)
	var aim := z.target.global_position + Vector3.UP * 0.9 + z.target.velocity * Vector3(1, 0, 1) * t * lead
	EnemyProjectile.launch(z.get_parent(), from, aim, projectile_speed, damage, color, arc, size, z)
	Sfx.play_at(throw_sound, from, 0.0, randf_range(0.9, 1.05))
	z.play_animation(z.data.move_animation, 0.35)
