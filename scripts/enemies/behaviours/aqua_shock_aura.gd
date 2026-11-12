class_name AquaShockAura
extends EnemyBehaviour
## Jelly Head's electric aura. When the player comes within `trigger_range`,
## the jellyfish hat charges: it glows hotter, a crackling ring marks the
## danger radius on the floor and the zombie slows down (the windup, which the
## threat ring shows). Then it discharges: anyone still inside `radius` gets
## zapped. Backing off during the charge, or killing it first, avoids the hit.

@export var trigger_range := 3.0
@export var radius := 3.4
@export var charge_time := 0.95
@export var cooldown := 3.8
@export var damage := 14.0
## Chase speed multiplier while charging.
@export var slow_while_charging := 0.35
@export var color := Color(1.0, 0.45, 0.95)
@export var spark_color := Color(0.55, 0.95, 1.0)
## Name of the hat accessory mesh that brightens while charging.
@export var hat_mesh := "Acc_Jelly_Hat"
@export var charge_sound: StringName = &"aqua_jelly_charge"
@export var zap_sound: StringName = &"aqua_jelly_zap"

const FLASH_TIME := 0.35

var _cool := 1.5
var _charge := 0.0
var _flash := 0.0
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _hat: MeshInstance3D
var _hat_glow: StandardMaterial3D


func on_ready(z: Zombie) -> void:
	_cool = randf_range(0.8, cooldown * 0.6)
	_hat = z.find_child(hat_mesh, true, false) as MeshInstance3D
	_hat_glow = StandardMaterial3D.new()
	_hat_glow.albedo_color = color
	_hat_glow.emission_enabled = true
	_hat_glow.emission = color.lightened(0.4)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.albedo_color = Color(color, 0.0)
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.12
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 4
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = 0.12
	_ring.scale = Vector3(1.0, 0.25, 1.0)
	_ring.visible = false
	z.add_child(_ring)


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	if _flash > 0.0:
		_flash -= delta
		var f := 1.0 - _flash / FLASH_TIME
		_ring.scale = Vector3(1.0 + f * 0.35, 0.25, 1.0 + f * 0.35)
		_ring_mat.albedo_color = Color(spark_color, 1.0 - f)
		if _flash <= 0.0:
			_ring.visible = false
	if _charge > 0.0:
		_charge -= delta
		z.speed_multiplier = slow_while_charging
		var k := 1.0 - _charge / charge_time
		var flicker := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.05)
		_ring.visible = true
		_ring.scale = Vector3(1.0, 0.25, 1.0)
		_ring_mat.albedo_color = Color(color, (0.25 + 0.65 * k) * flicker)
		_hat_glow.emission_energy_multiplier = (1.5 + 6.0 * k) * flicker
		if _charge <= 0.0:
			_discharge(z)
		return false
	if _cool <= 0.0 and z.state == Zombie.State.CHASE and z.target.alive and z.distance_to_target() <= trigger_range:
		_charge = charge_time
		if _hat:
			_hat.material_override = _hat_glow
		Sfx.play_at(charge_sound, z.global_position + Vector3.UP * 1.8, 0.0, randf_range(0.95, 1.08))
	return false


func _discharge(z: Zombie) -> void:
	_cool = cooldown
	_flash = FLASH_TIME
	if _hat:
		_hat.material_override = null
	var centre := z.global_position + Vector3.UP * 1.0
	if z.target.alive and z.distance_to_target() <= radius:
		z.target.take_damage(damage, z.global_position)
		z.target.add_shake(0.4)
		Fx.impact(z.get_parent(), z.target.global_position + Vector3.UP * 1.0, (centre - z.target.global_position).normalized(), spark_color)
	for i in 6:
		var a := TAU * i / 6.0
		var dir := Vector3(cos(a), 0.15, sin(a))
		Fx.impact(z.get_parent(), centre + dir * 0.6, dir, spark_color if i % 2 == 0 else color)
	Sfx.play_at(zap_sound, centre, 2.0, randf_range(0.95, 1.08))


func on_death(_z: Zombie) -> void:
	_charge = 0.0
	if _ring:
		_ring.visible = false
	if _hat:
		_hat.material_override = null


func is_winding_up() -> bool:
	return _charge > 0.0
