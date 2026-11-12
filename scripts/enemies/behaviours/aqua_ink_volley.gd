class_name AquaInkVolley
extends EnemyBehaviour
## Mascot Inker ranged attack. At mid range with a clear line of sight the
## octopus stops, its ink sac swells and glows while it gurgles (the windup,
## which the threat ring shows), then it spits a fan of lobbed ink globs that
## land around the player: strafing sideways or closing in beats it. Up close
## it falls back to the normal melee swipe.

@export var min_range := 4.5
@export var max_range := 15.0
@export var cooldown := 5.0
@export var windup := 0.9
@export var shots := 3
## Angle between neighbouring globs in the fan.
@export var spread_degrees := 12.0
@export var damage := 6.0
@export var projectile_speed := 11.0
@export var arc := 0.45
@export var color := Color(0.6, 0.25, 1.0)
## Name of the ink sac accessory mesh that glows during the windup.
@export var sac_mesh := "Acc_Octo_InkSac"
@export var windup_sound: StringName = &"aqua_octo_gurgle_1"
@export var fire_sound: StringName = &"aqua_ink_spit"

var _cool := 2.0
var _winding := 0.0
var _sac: MeshInstance3D
var _glow: StandardMaterial3D


func on_ready(z: Zombie) -> void:
	_cool = randf_range(1.5, cooldown)
	_sac = z.find_child(sac_mesh, true, false) as MeshInstance3D
	# Swapped onto the sac during the windup (material_override, so the
	# zombie's own hit flash, which uses the overlay slot, never clears it).
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = color
	_glow.emission_enabled = true
	_glow.emission = color.lightened(0.35)


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	if _winding > 0.0:
		_winding -= delta
		var to := z.target.global_position - z.global_position
		z.face_toward(Vector3(to.x, 0.0, to.z), delta)
		z.move_with(Vector3.ZERO)
		var k := 1.0 - _winding / windup
		_glow.emission_energy_multiplier = (1.5 + 5.0 * k) * (0.8 + 0.2 * sin(k * 40.0))
		if _winding <= 0.0:
			_fire(z)
		return true
	if _cool <= 0.0 and z.state == Zombie.State.CHASE and z.target.alive:
		var d := z.distance_to_target()
		if d >= min_range and d <= max_range and z.has_line_of_sight():
			_cool = cooldown
			_winding = windup
			z.play_animation(&"Spit", 0.1)
			Sfx.play_at(windup_sound, z.global_position + Vector3.UP * 1.5, 0.0, randf_range(0.95, 1.08))
			if _sac:
				_sac.material_override = _glow
			return true
	return false


func _fire(z: Zombie) -> void:
	if _sac:
		_sac.material_override = null
	var from := z.global_position + Vector3.UP * 1.2 * z.data.body_scale + Vector3(sin(z.rotation.y), 0.0, cos(z.rotation.y)) * 0.4
	# Lead the target a little so running in a straight line is not free.
	var lead := z.target.velocity * clampf(z.distance_to_target() / projectile_speed, 0.0, 1.0) * 0.35
	var aim := z.target.global_position + Vector3.UP * 0.6 + lead - from
	for i in shots:
		var yaw := deg_to_rad(spread_degrees) * (i - (shots - 1) * 0.5)
		EnemyProjectile.launch(z.get_parent(), from, from + aim.rotated(Vector3.UP, yaw), projectile_speed, damage, color, arc, 0.2, z)
	Sfx.play_at(fire_sound, from, 0.0, randf_range(0.95, 1.1))
	z.play_animation(z.data.move_animation, 0.2)


func on_death(_z: Zombie) -> void:
	_winding = 0.0
	if _sac:
		_sac.material_override = null


func is_winding_up() -> bool:
	return _winding > 0.0


func interrupt(z: Zombie) -> void:
	if _winding > 0.0:
		_winding = 0.0
		z.play_animation(z.data.move_animation, 0.2)
