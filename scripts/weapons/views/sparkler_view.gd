extends RefCounted
## Sparkler viewmodel motion (WeaponData.view_script): the fuse wound round
## the canister burns down with the magazine (FuseSeg7, the front, goes
## first) and spits sparks at its burning end, the Catherine wheel on the
## nose spins up with the trigger and coasts down, and the flint wheel at the
## back turns a notch on every shot, throwing a spark. The reload
## (sparkler_reload.gd) re-lights the fuse with a struck match.

const SEGMENTS := 8
const SPARKS := [Color(1.0, 0.85, 0.35), Color(1.0, 1.0, 0.85), Color(1.0, 0.5, 0.85)]
## Pinwheel: degrees a second added per shot, top speed, and how fast it coasts down (1/s).
const WHEEL_KICK := 240.0
const WHEEL_MAX := 1440.0
const WHEEL_DRAG := 1.5
const FLINT_STEP := 36.0

var _segments: Array[Node3D] = []
var _wheel: Node3D
var _flint: Node3D
var _flint_point: Node3D
var _wheel_speed := 0.0
var _wheel_angle := 0.0
var _flint_goal := 0.0
var _flint_angle := 0.0
var _spit := 0.0
var _shots := 0
var _firing := 0.0


func setup(v: WeaponView) -> void:
	for part in ["Pinwheel", "Flint", "MatchHolo", "MatchFlame"]:
		v.register_part(part)
	for i in SEGMENTS:
		v.register_part("FuseSeg%d" % i)
		_segments.append(v.part("FuseSeg%d" % i))
	_wheel = v.part("Pinwheel")
	_flint = v.part("Flint")
	_flint_point = v.model.find_child("FlintPoint", true, false) as Node3D
	var match_part := v.part("MatchHolo")
	if match_part:
		match_part.visible = false


func fired(v: WeaponView) -> void:
	_wheel_speed = minf(WHEEL_MAX, _wheel_speed + WHEEL_KICK)
	_flint_goal += FLINT_STEP
	_firing = 0.12
	_shots += 1
	if _shots % 3 == 0 and _flint_point:
		v.spark_burst(model_point(v, _flint_point), Vector3(0, 0.6, 1), SPARKS, 4, 0.7, 0.22, 0.008)


func update(v: WeaponView, delta: float) -> void:
	if v.is_reloading():
		return
	_firing = maxf(0.0, _firing - delta)
	_wheel_speed *= exp(-WHEEL_DRAG * delta)
	_wheel_angle = fmod(_wheel_angle + _wheel_speed * delta, 360.0)
	_flint_angle = lerpf(_flint_angle, _flint_goal, 1.0 - exp(-30.0 * delta))
	if _wheel:
		_wheel.transform = v.rest_transform("Pinwheel") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-_wheel_angle)), Vector3.ZERO)
	if _flint:
		_flint.transform = v.rest_transform("Flint") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-_flint_angle)), Vector3.ZERO)
	var lit := _lit_segments(v)
	for i in _segments.size():
		if _segments[i]:
			_segments[i].visible = i < lit
	_spit -= delta
	if _spit <= 0.0 and lit > 0 and _segments[lit - 1]:
		_spit = 0.05 if _firing > 0.0 else randf_range(0.18, 0.32)
		v.spark_burst(model_point(v, _segments[lit - 1]), Vector3(-0.4, 1, -0.2), SPARKS, 3 if _firing > 0.0 else 2, 0.5, 0.25, 0.006)


## Fuse segments still alight: the magazine's share of a full one (a staged
## or menu view without a player shows it full).
func _lit_segments(v: WeaponView) -> int:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return SEGMENTS
	return ceili(float(p.weapons.magazine()) / maxf(1.0, v.data.magazine_size) * SEGMENTS)


func event(_v: WeaponView, _name: StringName) -> void:
	pass


## Where `node` is in the model's own space right now.
static func model_point(v: WeaponView, node: Node3D) -> Vector3:
	if node == null or v.model == null:
		return Vector3.ZERO
	return v.model.global_transform.affine_inverse() * node.global_position
