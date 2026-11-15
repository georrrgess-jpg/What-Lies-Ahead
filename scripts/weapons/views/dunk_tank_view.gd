extends RefCounted
## Dunk Tank viewmodel motion (WeaponData.view_script): the water in the tank
## under the front (Water, scaled from its bottom) falls with the magazine,
## the pressure gauge's needle follows it and trembles while the jet runs,
## the pink pump sleeve strokes back on the first shot of a string and every
## PUMP_EVERY shots after, and the dunk-tank bullseye on the flank swings as
## the gun bucks. The reload (dunk_tank_reload.gd) swaps the tank and
## test-squirts.

const PUMP_EVERY := 10
const PUMP_TIME := 0.16
## Pump stroke (model space, toward the player).
const PUMP_TRAVEL := Vector3(0.0, 0.0, 0.03)
## Needle angle (degrees about X) at a full and an empty tank.
const NEEDLE_FULL := -30.0
const NEEDLE_EMPTY := 110.0
const LEVEL_RATE := 14.0
const PUMP_SOUND := &"gn8_dunk_pump"
const DROPS := [Color(0.55, 0.88, 1.0), Color(0.9, 0.98, 1.0)]

var _water: Node3D
var _needle: Node3D
var _pump: Node3D
var _target: Node3D
var _muzzle: Node3D
var _level := 1.0
var _since_shot := 10.0
var _since_pump := 10.0
var _string := 0
var _swing := 0.0
var _swing_speed := 0.0


func setup(v: WeaponView) -> void:
	for part in ["Water", "Pump", "Needle", "Target"]:
		v.register_part(part)
	_water = v.part("Water")
	_needle = v.part("Needle")
	_pump = v.part("Pump")
	_target = v.part("Target")
	_muzzle = v.model.find_child("Muzzle", true, false) as Node3D


func fired(v: WeaponView) -> void:
	if _since_shot > 0.3:
		_string = 0
	if _string % PUMP_EVERY == 0:
		_since_pump = 0.0
		Sfx.play(PUMP_SOUND, -12.0, randf_range(0.95, 1.05))
	_string += 1
	_since_shot = 0.0
	_swing_speed += randf_range(60.0, 110.0)
	if _muzzle and _string % 4 == 0:
		v.spark_burst(v.model.global_transform.affine_inverse() * _muzzle.global_position, Vector3(0, -0.6, -0.4), DROPS, 2, 0.6, 0.3, 0.006)


func event(_v: WeaponView, _name: StringName) -> void:
	pass


func update(v: WeaponView, delta: float) -> void:
	_since_shot += delta
	_since_pump += delta
	if v.is_reloading():
		_level = 0.0
		return
	_level = lerpf(_level, _fill(v), 1.0 - exp(-LEVEL_RATE * delta))
	if _water:
		var rest := v.rest_transform("Water")
		_water.transform = Transform3D(rest.basis.scaled_local(Vector3(1.0, maxf(0.03, _level), 1.0)), rest.origin)
	if _needle:
		var tremble := sin(_since_shot * 90.0) * 4.0 if _since_shot < 0.12 else 0.0
		var angle := lerpf(NEEDLE_EMPTY, NEEDLE_FULL, _level) + tremble
		_needle.transform = v.rest_transform("Needle") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(angle)), Vector3.ZERO)
	if _pump:
		var k := sin(clampf(_since_pump / PUMP_TIME, 0.0, 1.0) * PI)
		_pump.transform = Transform3D(v.rest_transform("Pump").basis, v.rest_transform("Pump").origin + PUMP_TRAVEL * k)
	# The bullseye swings on its hinge like a damped pendulum.
	_swing_speed += (-_swing * 120.0 - _swing_speed * 7.0) * delta
	_swing += _swing_speed * delta
	if _target:
		_target.transform = v.rest_transform("Target") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(clampf(_swing, -25.0, 25.0))), Vector3.ZERO)


## Share of the tank still full (a staged or menu view shows it full).
func _fill(v: WeaponView) -> float:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return 1.0
	return clampf(float(p.weapons.magazine()) / maxf(1.0, v.data.magazine_size), 0.0, 1.0)
