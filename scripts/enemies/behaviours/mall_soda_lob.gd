class_name MallSodaLobBehaviour
extends EnemyBehaviour
## Food Court Flinger: at range with a line of sight it plants its feet and
## rears back with a jumbo soda cup over its shoulder (the telegraph: the Lob
## clip, a fizzing shake, the threat ring), then lobs it in an arc at where
## the player is heading. The cup bursts in a pink fizz. A headshot during the
## windup spills the cup and the throw is lost. Melee still works up close.

@export var min_range := 6.0
@export var max_range := 24.0
@export var cooldown := 5.0
@export var windup := 0.9
@export var damage := 7.0
@export var projectile_speed := 14.0
@export var arc := 0.75
@export var size := 0.3
@export var color := Color(1.0, 0.35, 0.72)
## How much of the player's motion the throw leads (0 = aims at the feet).
@export var lead := 0.5
@export var windup_sound: StringName = &"mall_soda_shake"
@export var throw_sound: StringName = &"mall_soda_throw"

## Fraction of the Lob clip at which the arm comes forward.
const RELEASE_FRACTION := 15.0 / 28.0

var _cool := 3.0
var _winding := 0.0
var _anim: AnimationPlayer
var _held: Node3D

static var _cup_mesh: CylinderMesh
static var _lid_mesh: CylinderMesh


func on_ready(z: Zombie) -> void:
	_anim = z.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_cool = randf_range(1.5, cooldown)


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	if _winding > 0.0:
		_winding -= delta
		var to := z.target.global_position - z.global_position
		z.face_toward(Vector3(to.x, 0, to.z), delta * 1.5)
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
	if is_instance_valid(_held):
		Fx.impact(z.get_parent(), _held.global_position, Vector3.UP, color)
	_drop_cup()
	if _anim:
		_anim.speed_scale = 1.0
	z.play_animation(&"Stagger", 0.05)
	Sfx.play_at(&"mall_soda_splash", z.global_position + Vector3.UP * 1.8, -3.0, 1.15)


func on_death(_z: Zombie) -> void:
	_drop_cup()


func is_winding_up() -> bool:
	return _winding > 0.0


func _begin(z: Zombie) -> void:
	_cool = cooldown
	_winding = windup
	if _anim and _anim.has_animation("Lob"):
		var clip := _anim.get_animation("Lob")
		_anim.play("Lob", 0.1)
		_anim.speed_scale = clip.length * RELEASE_FRACTION / windup
	Sfx.play_at(windup_sound, z.global_position + Vector3.UP * 1.8, 0.0, randf_range(0.95, 1.08))
	_hold_cup(z)


## A jumbo soda cup (with a lid and a straw) appears over the right shoulder.
func _hold_cup(z: Zombie) -> void:
	if _cup_mesh == null:
		_cup_mesh = CylinderMesh.new()
		_cup_mesh.top_radius = 0.13
		_cup_mesh.bottom_radius = 0.09
		_cup_mesh.height = 0.34
		_cup_mesh.radial_segments = 12
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.95, 0.9)
		m.roughness = 0.5
		_cup_mesh.material = m
		_lid_mesh = CylinderMesh.new()
		_lid_mesh.top_radius = 0.1
		_lid_mesh.bottom_radius = 0.14
		_lid_mesh.height = 0.06
		_lid_mesh.radial_segments = 12
		var lid := StandardMaterial3D.new()
		lid.albedo_color = color
		lid.emission_enabled = true
		lid.emission = color
		lid.emission_energy_multiplier = 1.2
		_lid_mesh.material = lid
	_held = Node3D.new()
	var cup := MeshInstance3D.new()
	cup.mesh = _cup_mesh
	cup.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held.add_child(cup)
	var lid_mi := MeshInstance3D.new()
	lid_mi.mesh = _lid_mesh
	lid_mi.position.y = 0.19
	lid_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held.add_child(lid_mi)
	z.add_child(_held)
	_held.position = Vector3(-0.35, 2.05, 0.15) * z.data.body_scale


func _drop_cup() -> void:
	if is_instance_valid(_held):
		_held.queue_free()
	_held = null


func _release(z: Zombie) -> void:
	var from := _held.global_position if is_instance_valid(_held) else z.global_position + Vector3.UP * 2.0 * z.data.body_scale
	_drop_cup()
	if _anim:
		_anim.speed_scale = 1.0
	var t := clampf(z.distance_to_target() / projectile_speed, 0.0, 1.6)
	var aim := z.target.global_position + Vector3.UP * 0.9 + z.target.velocity * Vector3(1, 0, 1) * t * lead
	EnemyProjectile.launch(z.get_parent(), from, aim, projectile_speed, damage, color, arc, size, z)
	Sfx.play_at(throw_sound, from, 0.0, randf_range(0.92, 1.06))
	z.play_animation(z.data.move_animation, 0.35)
