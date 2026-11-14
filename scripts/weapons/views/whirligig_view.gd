extends RefCounted
## Whirligig viewmodel motion (WeaponData.view_script): the prize wheel and
## barrels turn with the spin-up (WhirligigMode.spin, read from the held
## weapon's mode), the side wheel geared to them turns the other way, and
## the ticker on top clacks over the wheel's pegs. The reload
## (whirligig_reload.gd) flicks the wheel by hand.

## Wheel turns per second at full spin, and side-wheel turns per wheel turn.
const MAX_TURNS := 3.2
const SIDE_GEAR := 1.5
## Pegs round the wheel (one ticker clack each) and the flapper's swing (degrees).
const PEGS := 12
const TICKER_SWING := 32.0

var _barrels: Node3D
var _ticker: Node3D
var _wheel: Node3D
var _rests := {}
var _angle := 0.0


func setup(v: WeaponView) -> void:
	for part in ["Ticker", "Wheel"]:
		v.register_part(part)
	_barrels = v.part("Barrels")
	_ticker = v.part("Ticker")
	_wheel = v.part("Wheel")
	for part in ["Barrels", "Ticker", "Wheel"]:
		_rests[part] = v.rest_transform(part)


func fired(_v: WeaponView) -> void:
	pass


func event(_v: WeaponView, _name: StringName) -> void:
	pass


func update(v: WeaponView, delta: float) -> void:
	if v.is_reloading():
		_angle = 0.0
		return
	var spin := _spin(v)
	_angle = fmod(_angle + spin * MAX_TURNS * TAU * delta, TAU)
	if _barrels:
		_barrels.transform = _turned("Barrels", Vector3.BACK, _angle)
	if _wheel:
		_wheel.transform = _turned("Wheel", Vector3.RIGHT, -_angle * SIDE_GEAR)
	if _ticker:
		# The flapper is lifted by each peg and snaps back past it.
		var peg := fmod(_angle * PEGS / TAU, 1.0)
		_ticker.transform = _turned("Ticker", Vector3.RIGHT, deg_to_rad(TICKER_SWING) * (1.0 - peg) * (1.0 - peg) * minf(1.0, spin * 4.0))


## 0-1 spin of the held Whirligig (0 when staged or not held).
func _spin(v: WeaponView) -> float:
	var w := v.player.weapons if v.player else null
	if w == null or w.current != v.data or w.mode == null:
		return 0.0
	return float(w.mode.get("spin"))


func _turned(part: String, axis: Vector3, angle: float) -> Transform3D:
	var rest: Transform3D = _rests[part]
	return Transform3D(rest.basis * Basis(axis, angle), rest.origin)
