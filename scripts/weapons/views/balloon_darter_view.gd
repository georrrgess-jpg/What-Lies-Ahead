extends RefCounted
## Balloon Darter viewmodel motion (WeaponData.view_script): a shot snaps the
## air plunger at the back forward and spits the loaded dart out of the top
## channel; the next one slides in from the back. The open clip under the
## barrel shows the darts left (each tail is two), and the helium gauge's
## needle sinks toward red as the clip empties. The reload
## (balloon_darter_reload.gd) swaps the clip and blows up a balloon.

const TAILS := 6
## Seconds: the dart leaves, then the next slides into the channel.
const LAUNCH := 0.06
const FEED_START := 0.1
const FEED_END := 0.2
const LAUNCH_OFFSET := Vector3(0.0, 0.0, -0.3)
const FEED_OFFSET := Vector3(0.0, 0.0, 0.07)
const PLUNGE_TIME := 0.16
const PLUNGE := Vector3(0.0, 0.0, -0.022)
## Gauge needle: degrees at a full clip and an empty one.
const NEEDLE_FULL := 55.0
const NEEDLE_EMPTY := -55.0
const PUFF := [Color(1.0, 1.0, 1.0), Color(0.75, 1.0, 0.5), Color(1.0, 0.6, 0.85)]

var _dart: Node3D
var _plunger: Node3D
var _needle: Node3D
var _muzzle: Node3D
var _tails: Array[Node3D] = []
var _since_shot := 10.0
var _needle_deg := NEEDLE_FULL


func setup(v: WeaponView) -> void:
	for part in ["Dart", "Plunger", "Needle", "BalloonHolo"]:
		v.register_part(part)
	for i in TAILS:
		v.register_part("Tail%d" % i)
		_tails.append(v.part("Tail%d" % i))
	_dart = v.part("Dart")
	_plunger = v.part("Plunger")
	_needle = v.part("Needle")
	_muzzle = v.model.find_child("Muzzle", true, false) as Node3D
	var balloon := v.part("BalloonHolo")
	if balloon:
		balloon.visible = false


func fired(v: WeaponView) -> void:
	_since_shot = 0.0
	if _muzzle:
		var at := v.model.global_transform.affine_inverse() * _muzzle.global_position
		v.spark_burst(at, Vector3(0, 0.2, -1), PUFF, 5, 0.6, 0.18, 0.006)


func update(v: WeaponView, delta: float) -> void:
	_since_shot += delta
	if v.is_reloading():
		return
	var mag := _magazine(v)
	_pose_dart(v, mag)
	var shown := ceili(maxf(0.0, mag - 1) / 2.0)
	for i in _tails.size():
		if _tails[i]:
			_tails[i].visible = i < shown
	if _plunger:
		var k := sin(clampf(_since_shot / PLUNGE_TIME, 0.0, 1.0) * PI)
		_plunger.transform = Transform3D(v.rest_transform("Plunger").basis, v.rest_transform("Plunger").origin + PLUNGE * k)
	if _needle:
		var goal := lerpf(NEEDLE_EMPTY, NEEDLE_FULL, float(mag) / maxf(1.0, v.data.magazine_size))
		_needle_deg = lerpf(_needle_deg, goal, 1.0 - exp(-10.0 * delta))
		_needle.transform = v.rest_transform("Needle") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(_needle_deg)), Vector3.ZERO)


## The loaded dart: flying off, hidden, sliding in from the back, or at rest.
func _pose_dart(v: WeaponView, mag: int) -> void:
	if _dart == null:
		return
	var rest := v.rest_transform("Dart")
	var t := _since_shot
	if t < LAUNCH:
		_dart.visible = true
		_dart.transform = Transform3D(rest.basis, rest.origin + LAUNCH_OFFSET * (t / LAUNCH))
	elif t < FEED_START or mag <= 0:
		_dart.visible = false
	elif t < FEED_END:
		_dart.visible = true
		_dart.transform = Transform3D(rest.basis, rest.origin + FEED_OFFSET * (1.0 - smoothstep(FEED_START, FEED_END, t)))
	else:
		_dart.visible = true
		_dart.transform = rest


func event(_v: WeaponView, _name: StringName) -> void:
	pass


func _magazine(v: WeaponView) -> int:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return v.data.magazine_size
	return p.weapons.magazine()
