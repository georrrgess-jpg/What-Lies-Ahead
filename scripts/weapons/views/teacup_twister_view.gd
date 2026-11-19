extends RefCounted
## Teacup Twister viewmodel motion (WeaponData.view_script): the teacup
## carousel round the barrel (Drum) turns a quarter per shot to bring the
## next cup under the muzzle, and the spent cups are gone (Cup0..3 show the
## magazine); the saucer rim on the muzzle spins up with every shot and the
## candy swirl on the flank whirls and coasts down. A shot throws a pinch of
## confetti from the cup. The reload (teacup_twister_reload.gd) dumps the
## cups, prints new ones and flicks the carousel round by hand.
## Inspect: the carousel becomes the fairground ride: it winds up and whirls,
## every cup spinning on its own and bobbing up and down on its arm, the
## saucer and the swirl spinning along, then coasts down and a puff of
## confetti pops out of the front cup.

const CUPS := 4
## Carousel step per shot (degrees) and how fast it snaps there (1/s).
const STEP := 90.0
const SNAP := 18.0
## Saucer and swirl: degrees a second added per shot, and how fast they coast down (1/s).
const SAUCER_KICK := 900.0
const SAUCER_DRAG := 2.2
const SWIRL_KICK := 1600.0
const SWIRL_DRAG := 1.4
const INSPECT_LENGTH := 2.8
## The ride: carousel turns, each cup's own turns, the bob (model units).
const RIDE_TURNS := 2.5
const CUP_TURNS := 4.0
const BOB := 0.012
const INSPECT_POSES := [
	[0.0, Vector3(0.14, -0.14, -0.62), Vector3(2.0, 14.0, -4.0)],
	[0.16, Vector3(0.06, -0.11, -0.58), Vector3(14.0, 56.0, -6.0)],
	[0.5, Vector3(0.05, -0.1, -0.57), Vector3(16.0, 62.0, -2.0)],
	[0.78, Vector3(0.05, -0.11, -0.57), Vector3(10.0, 50.0, 4.0)],
	[1.0, Vector3(0.14, -0.15, -0.62), Vector3(2.0, 6.0, 0.0)],
]
const CONFETTI := [Color(1.0, 0.42, 0.78), Color(0.35, 0.92, 1.0), Color(1.0, 0.86, 0.3), Color(1.0, 1.0, 1.0)]

var _drum: Node3D
var _saucer: Node3D
var _swirl: Node3D
var _muzzle: Node3D
var _cups: Array[Node3D] = []
var _drum_angle := 0.0
var _saucer_speed := 0.0
var _saucer_angle := 0.0
var _swirl_speed := 0.0
var _swirl_angle := 0.0
var _popped := false


func setup(v: WeaponView) -> void:
	for part in ["Saucer", "Swirl"]:
		v.register_part(part)
	for i in CUPS:
		v.register_part("Cup%d" % i)
		_cups.append(v.part("Cup%d" % i))
	_drum = v.part("Drum")
	_saucer = v.part("Saucer")
	_swirl = v.part("Swirl")
	_muzzle = v.model.find_child("Muzzle", true, false) as Node3D


func fired(v: WeaponView) -> void:
	_saucer_speed += SAUCER_KICK
	_swirl_speed += SWIRL_KICK
	if _muzzle:
		v.spark_burst(v.model.global_transform.affine_inverse() * _muzzle.global_position, Vector3(0, 0.3, -1), CONFETTI, 10, 1.4, 0.4, 0.012)


func event(_v: WeaponView, _name: StringName) -> void:
	pass


func update(v: WeaponView, delta: float) -> void:
	if v.is_reloading():
		_drum_angle = 0.0
		return
	var spent := CUPS - _magazine(v)
	_drum_angle = lerpf(_drum_angle, spent * STEP, 1.0 - exp(-SNAP * delta))
	if _drum:
		_drum.transform = _turned(v, "Drum", Vector3.BACK, _drum_angle)
	for k in _cups.size():
		if _cups[k]:
			# Cup0 fires first, then the cups the carousel brings round: 3, 2, 1.
			_cups[k].visible = (CUPS - k) % CUPS >= spent
	_saucer_speed *= exp(-SAUCER_DRAG * delta)
	_saucer_angle = fmod(_saucer_angle + _saucer_speed * delta, 360.0)
	if _saucer:
		_saucer.transform = _turned(v, "Saucer", Vector3.BACK, -_saucer_angle)
	_swirl_speed *= exp(-SWIRL_DRAG * delta)
	_swirl_angle = fmod(_swirl_angle + _swirl_speed * delta, 360.0)
	if _swirl:
		_swirl.transform = _turned(v, "Swirl", Vector3.RIGHT, _swirl_angle)


func inspect_length() -> float:
	return INSPECT_LENGTH


func inspect_poses() -> Array:
	return INSPECT_POSES


func inspect_start(_v: WeaponView) -> void:
	_popped = false
	Sfx.play(&"gn8_twister_whirl", -10.0, 0.9)


func inspect(v: WeaponView, t: float) -> void:
	# The ride's speed: winds up, runs, coasts down (its integral is the turn).
	var ride := _ride(t)
	if _drum:
		_drum.transform = _turned(v, "Drum", Vector3.BACK, _drum_angle + ride * RIDE_TURNS * 360.0)
	for k in _cups.size():
		if _cups[k] == null:
			continue
		var rest := v.rest_transform("Cup%d" % k)
		var phase := TAU * k / CUPS
		var bob := BOB * sin(t * 7.0 + phase) * WeaponInspect.hump(t, 0.3, 2.4)
		# Bobs out along its arm (away from the carousel's axis) and spins on its own axis.
		var arm := Vector3(rest.origin.x, rest.origin.y, 0.0).normalized()
		var own := ride * CUP_TURNS * 360.0 * (1.0 if k % 2 == 0 else -1.0)
		_cups[k].transform = Transform3D(rest.basis * Basis(Vector3.BACK, deg_to_rad(own)), rest.origin + arm * bob)
	_saucer_speed = maxf(_saucer_speed, 900.0 * WeaponInspect.hump(t, 0.3, 2.3))
	_swirl_speed = maxf(_swirl_speed, 1400.0 * WeaponInspect.hump(t, 0.3, 2.3))
	if t > 2.15 and not _popped:
		_popped = true
		Sfx.play(&"gn8_twister_pop", -8.0, 1.15)
		if _muzzle:
			v.spark_burst(WeaponInspect.in_model(v, _muzzle), Vector3(0, 0.6, -1), CONFETTI, 18, 1.0, 0.5, 0.01)


## How far round the ride is (0-1): an eased wind-up, run and coast.
static func _ride(t: float) -> float:
	return smoothstep(0.3, 2.2, t)


func _magazine(v: WeaponView) -> int:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return v.data.magazine_size
	return clampi(p.weapons.magazine(), 0, CUPS)


static func _turned(v: WeaponView, part: String, axis: Vector3, degrees: float) -> Transform3D:
	var rest := v.rest_transform(part)
	return Transform3D(rest.basis * Basis(axis, deg_to_rad(degrees)), rest.origin)
