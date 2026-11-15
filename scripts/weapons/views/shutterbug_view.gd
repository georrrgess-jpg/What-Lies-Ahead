extends RefCounted
## Shutterbug viewmodel motion (WeaponData.view_script): the flash wheel on
## the left flank holds a bulb for every shot in the magazine. A shot fires
## the bulb facing forward (it pops white and goes dark) and the wheel turns
## the next one round; the shutter blades in the lens twist shut and open,
## and the film lever on top is thumbed back and springs home. Aiming turns
## the focus ring. The reload (shutterbug_reload.gd) swaps the wheel.

const BULBS := 8
## Degrees the wheel turns per shot, and how fast it gets there (1/s).
const STEP := 45.0
const WHEEL_RATE := 22.0
const IRIS_TIME := 0.12
const IRIS_TWIST := 50.0
## The film lever: starts after WIND_START, out and back over WIND_TIME.
const WIND_START := 0.08
const WIND_TIME := 0.3
const WIND_SWING := 75.0
const FOCUS_TURN := 140.0
const POP := [Color(1.0, 1.0, 1.0), Color(0.75, 0.95, 1.0), Color(1.0, 0.95, 0.7)]

var _bulbs: Array[Node3D] = []
var _wheel: Node3D
var _iris: Node3D
var _focus: Node3D
var _winder: Node3D
var _flash_point: Node3D
var _angle := 0.0
var _since_shot := 10.0
var _focus_k := 0.0


func setup(v: WeaponView) -> void:
	for part in ["Iris", "Focus", "Winder"]:
		v.register_part(part)
	for i in BULBS:
		v.register_part("Bulb%d" % i)
		_bulbs.append(v.part("Bulb%d" % i))
	_wheel = v.part("Cell")
	_iris = v.part("Iris")
	_focus = v.part("Focus")
	_winder = v.part("Winder")
	_flash_point = v.model.find_child("FlashPoint", true, false) as Node3D
	_angle = _spent(v) * STEP


func fired(v: WeaponView) -> void:
	_since_shot = 0.0
	if _flash_point:
		var at := v.model.global_transform.affine_inverse() * _flash_point.global_position
		v.spark_burst(at, Vector3(0, 0.3, -1), POP, 10, 1.1, 0.2, 0.01)


func update(v: WeaponView, delta: float) -> void:
	_since_shot += delta
	var aim := 0.0
	if v.player:
		aim = v.player.ads
	_focus_k = lerpf(_focus_k, aim, 1.0 - exp(-12.0 * delta))
	if v.is_reloading():
		_angle = 0.0
		return
	var spent := _spent(v)
	_angle = lerpf(_angle, spent * STEP, 1.0 - exp(-WHEEL_RATE * delta))
	if _wheel:
		_wheel.transform = v.rest_transform("Cell") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-_angle)), Vector3.ZERO)
	for i in _bulbs.size():
		if _bulbs[i]:
			_bulbs[i].visible = i >= spent
	if _iris:
		var k := sin(clampf(_since_shot / IRIS_TIME, 0.0, 1.0) * PI)
		_iris.transform = v.rest_transform("Iris") * Transform3D(Basis(Vector3.BACK, deg_to_rad(IRIS_TWIST * k)), Vector3.ZERO)
	if _winder:
		var w := sin(clampf((_since_shot - WIND_START) / WIND_TIME, 0.0, 1.0) * PI)
		_winder.transform = v.rest_transform("Winder") * Transform3D(Basis(Vector3.UP, deg_to_rad(-WIND_SWING * w)), Vector3.ZERO)
	if _focus:
		_focus.transform = v.rest_transform("Focus") * Transform3D(Basis(Vector3.BACK, deg_to_rad(FOCUS_TURN * _focus_k)), Vector3.ZERO)


func event(_v: WeaponView, _name: StringName) -> void:
	pass


## Bulbs used up: the magazine's empty share (a staged or menu view shows it full).
func _spent(v: WeaponView) -> int:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return 0
	return clampi(v.data.magazine_size - p.weapons.magazine(), 0, BULBS)
