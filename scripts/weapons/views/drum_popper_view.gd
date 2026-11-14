extends RefCounted
## Gumball Drum Popper viewmodel motion (WeaponData.view_script): the drum
## turns one chamber per shot, snapping round to the next one, and the
## fore-pump bumps forward (the support hand rides it). The reload
## (drum_popper_reload.gd) swaps in a fresh drum at rest.

## Chambers per turn of the drum.
const CHAMBERS := 8
## How fast the shown drum catches up with the next chamber (1/s).
const TURN_RATE := 26.0
## Pump bump per shot (metres, forward) and how fast it settles (1/s).
const PUMP_KICK := 0.012
const PUMP_RETURN := 10.0

var _drum: Node3D
var _pump: Node3D
var _drum_rest := Transform3D.IDENTITY
var _pump_rest := Transform3D.IDENTITY
var _shots := 0
var _angle := 0.0
var _bump := 0.0


func setup(v: WeaponView) -> void:
	_drum = v.part("Drum")
	_pump = v.part("Pump")
	_drum_rest = v.rest_transform("Drum")
	_pump_rest = v.rest_transform("Pump")


func fired(_v: WeaponView) -> void:
	_shots += 1
	_bump = 1.0


func event(_v: WeaponView, _name: StringName) -> void:
	pass


func update(v: WeaponView, delta: float) -> void:
	if v.is_reloading():
		# A fresh drum: the reload leaves both parts at rest.
		_shots = 0
		_angle = 0.0
		_bump = 0.0
		return
	_angle = lerpf(_angle, _shots * TAU / CHAMBERS, 1.0 - exp(-TURN_RATE * delta))
	_bump = maxf(0.0, _bump - PUMP_RETURN * delta)
	if _drum:
		_drum.transform = Transform3D(_drum_rest.basis * Basis(Vector3.RIGHT, -_angle), _drum_rest.origin)
	if _pump:
		_pump.transform = Transform3D(_pump_rest.basis, _pump_rest.origin + Vector3(0.0, 0.0, -sin(_bump * PI) * PUMP_KICK))
