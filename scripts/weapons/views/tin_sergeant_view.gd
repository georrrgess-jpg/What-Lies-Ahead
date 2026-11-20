extends RefCounted
## Tin Sergeant viewmodel motion (WeaponData.view_script). The loaded soldier
## stands in the open hatch on the chest's deck (Soldier, his right arm
## SoldierArm), his back and key to the player. A shot drops him into the
## chest and the hatch (Hatch, built open) slaps shut over him as he is
## fired out of the bugle; then it flips open and the next soldier pops up
## on a springy overshoot (none when the magazine is empty). Now and then
## the soldier at the hatch marks time. The big key on the left flank (Key)
## ratchets a quarter turn per shot; the six lamps on the lid (Lamp0..5)
## light one per soldier out (the oldest blinks when the next shot will pop
## it); the pennant (Flag) stands up while the "Fall in!" flag is planted.
## Inspect: the soldier climbs half out of the hatch, about-turns to face
## you and salutes to a bugle call while the key winds. One time in
## PARADE_CHANCE he twirls first, the lamps chase, the pennant flies and a
## fanfare plays under a shower of gold confetti.

const LAMPS := 6
## Seconds: the soldier drops and the hatch shuts, then it opens and the next rises.
const DROP := 0.06
const OPEN_AT := 0.16
const RISE_TIME := 0.26
const DROP_DEPTH := 0.05
## Degrees the hatch turns to shut (about the hinge, Godot -Z = Blender Y).
const HATCH_SHUT := -172.0
const KEY_STEP := 90.0
const FLAG_UP := Vector3(80.0, 0.0, -22.0)
## Every MARK_EVERY seconds the soldier at the hatch marks time for MARK_TIME.
const MARK_EVERY := 3.4
const MARK_TIME := 0.8
## Inspect.
const INSPECT_LENGTH := 3.2
const PARADE_CHANCE := 1.0 / 15.0
const CLIMB := 0.034
const SALUTE := Vector3(150.0, 0.0, 28.0)
const CONFETTI := [Color(1.0, 0.84, 0.25), Color(1.0, 0.95, 0.6), Color(0.89, 0.27, 0.23), Color(0.3, 0.5, 1.0)]
const INSPECT_POSES := [
	[0.0, Vector3(0.18, -0.2, -0.6), Vector3(2.0, 6.0, -3.0)],
	[0.12, Vector3(0.06, -0.2, -0.5), Vector3(30.0, 28.0, 6.0)],
	[0.5, Vector3(0.05, -0.19, -0.49), Vector3(34.0, 24.0, 4.0)],
	[0.78, Vector3(0.05, -0.19, -0.49), Vector3(32.0, 20.0, 2.0)],
	[0.9, Vector3(0.1, -0.2, -0.56), Vector3(16.0, 16.0, 2.0)],
	[1.0, Vector3(0.18, -0.21, -0.62), Vector3(3.0, 4.0, 0.0)],
]

var _hatch: Node3D
var _soldier: Node3D
var _arm: Node3D
var _key: Node3D
var _flag: Node3D
var _lamps: Array[Node3D] = []
var _since_shot := 10.0
var _time := 0.0
var _key_target := 0.0
var _key_angle := 0.0
var _flag_k := 0.0
var _parade := false
var _called := false
var _cheered := false


func setup(v: WeaponView) -> void:
	for part in ["Hatch", "Soldier", "SoldierArm", "Key", "Flag"]:
		v.register_part(part)
	for i in LAMPS:
		v.register_part("Lamp%d" % i)
		_lamps.append(v.part("Lamp%d" % i))
	_hatch = v.part("Hatch")
	_soldier = v.part("Soldier")
	_arm = v.part("SoldierArm")
	_key = v.part("Key")
	_flag = v.part("Flag")


func fired(_v: WeaponView) -> void:
	_since_shot = 0.0
	_key_target += KEY_STEP


func event(_v: WeaponView, _event_name: StringName) -> void:
	pass


func update(v: WeaponView, delta: float) -> void:
	_since_shot += delta
	_time += delta
	_light_lamps(v)
	_pose_flag(v, delta)
	if v.is_reloading():
		return
	_key_angle = lerpf(_key_angle, _key_target, 1.0 - exp(-18.0 * delta))
	_turn_key(v, _key_angle)
	if v.is_inspecting():
		return
	_pose_hatch(v)


## The drop, the slap shut, the flip open and the next soldier rising; at
## rest he marks time now and then.
func _pose_hatch(v: WeaponView) -> void:
	var loaded := _magazine(v) > 0
	var shut := 0.0
	var depth := 0.0
	var squash := 1.0
	var shown := loaded
	if _since_shot < DROP:
		depth = DROP_DEPTH * _since_shot / DROP
		shut = _since_shot / DROP
		shown = true
	elif _since_shot < OPEN_AT:
		shut = 1.0
		shown = false
	else:
		var u := clampf((_since_shot - OPEN_AT) / RISE_TIME, 0.0, 1.0)
		shut = 1.0 - _spring(clampf(u * 1.8, 0.0, 1.0))
		depth = DROP_DEPTH * (1.0 - _spring(u))
		squash = 1.0 + 0.1 * sin(PI * clampf(u * 1.6, 0.0, 1.0)) * (1.0 - u)
		if not loaded:
			shut = 0.0
	if _hatch:
		_hatch.transform = v.rest_transform("Hatch") * Transform3D(Basis(Vector3.BACK, deg_to_rad(HATCH_SHUT * shut)), Vector3.ZERO)
	if _soldier:
		_soldier.visible = shown
		var mark := fmod(_time, MARK_EVERY)
		var step := sin(mark / MARK_TIME * TAU * 2.0) * sin(PI * clampf(mark / MARK_TIME, 0.0, 1.0)) if mark < MARK_TIME else 0.0
		var pose := Transform3D(Basis(Vector3.BACK, deg_to_rad(4.0 * step)).scaled(Vector3(1.0, squash, 1.0)),
			Vector3(0.0, -depth + 0.002 * absf(step), 0.0))
		_soldier.transform = v.rest_transform("Soldier") * pose
	if _arm:
		_arm.transform = v.rest_transform("SoldierArm")


## One lamp per soldier out; the oldest blinks when the next shot will pop it.
func _light_lamps(v: WeaponView) -> void:
	var mode := _mode(v)
	var out := mode.soldiers_out() if mode else 0
	for i in _lamps.size():
		if _lamps[i] == null:
			continue
		var on := i < out
		if on and out >= TinSoldier.MAX_SOLDIERS and i == 0:
			on = fmod(_time, 0.4) < 0.24
		_lamps[i].visible = on


## The pennant stands up while the squad has a flag to fall in on, and flutters.
func _pose_flag(v: WeaponView, delta: float) -> void:
	if _flag == null:
		return
	var mode := _mode(v)
	var up := 1.0 if (mode and mode.rallying()) or _parade_up() else 0.0
	_flag_k = move_toward(_flag_k, up, delta * 4.0)
	var k := _ease_out_back(_flag_k) if up > 0.0 else _flag_k * _flag_k
	var flutter := Vector3(0.0, 0.0, 6.0 * sin(_time * 11.0)) * _flag_k
	_flag.transform = v.rest_transform("Flag") * Transform3D(Basis.from_euler((FLAG_UP * k + flutter) * (PI / 180.0)), Vector3.ZERO)


func _parade_up() -> bool:
	return _parade and _cheered


func _turn_key(v: WeaponView, degrees: float) -> void:
	if _key:
		_key.transform = v.rest_transform("Key") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-degrees)), Vector3.ZERO)


# --- inspect ---------------------------------------------------------------------

func inspect_length() -> float:
	return INSPECT_LENGTH


func inspect_poses() -> Array:
	return INSPECT_POSES


func inspect_start(v: WeaponView) -> void:
	_parade = v.inspect_rare(PARADE_CHANCE)
	_called = false
	_cheered = false
	if _hatch:
		_hatch.transform = v.rest_transform("Hatch")
	if _soldier:
		_soldier.visible = true


## He climbs half out, about-turns (twirling first on parade), salutes for a
## bugle call, then turns back and climbs down; the key winds the while.
func inspect(v: WeaponView, t: float) -> void:
	_turn_key(v, _key_angle - 360.0 * 1.5 * WeaponInspect.window(t, 0.2, 2.8))
	if _soldier == null:
		return
	var climb := _spring(clampf((t - 0.3) / 0.4, 0.0, 1.0)) * (1.0 - WeaponInspect.window(t, 2.55, 2.85))
	var turn := 180.0 * WeaponInspect.window(t, 0.62, 0.92) * (1.0 - WeaponInspect.window(t, 2.15, 2.45))
	if _parade:
		turn += 360.0 * WeaponInspect.window(t, 0.62, 0.92)
	var hop := 0.006 * WeaponInspect.hump(t, 0.62, 0.77) + 0.006 * WeaponInspect.hump(t, 0.77, 0.92)
	_soldier.transform = v.rest_transform("Soldier") * Transform3D(Basis(Vector3.UP, deg_to_rad(turn)), Vector3(0.0, CLIMB * climb + hop, 0.0))
	var salute := WeaponInspect.window(t, 1.0, 1.2) * (1.0 - WeaponInspect.window(t, 1.85, 2.08))
	var snap := 1.0 + 0.06 * WeaponInspect.hump(t, 1.18, 1.32)
	if _arm:
		_arm.transform = v.rest_transform("SoldierArm") * Transform3D(Basis.from_euler(SALUTE * salute * snap * (PI / 180.0)), Vector3.ZERO)
	if t >= 1.05 and not _called:
		_called = true
		Sfx.play(&"ts_fanfare" if _parade else &"ts_salute", -7.0)
		if _parade:
			_cheered = true
			var at := WeaponInspect.in_model(v, _soldier) + Vector3(0.0, 0.05, 0.0)
			FxBurst.spawn(v.model, at, Vector3(0, 1, 0.1), CONFETTI, 28, 0.8, 1.0, 0.006, 65.0, Vector3(0, -0.8, 0), WeaponView._burst_mesh())
	if _parade and t > 1.05:
		var chase := int((t - 1.05) * 14.0) % _lamps.size()
		for i in _lamps.size():
			if _lamps[i]:
				_lamps[i].visible = i == chase or t > 2.4


func inspect_end(_v: WeaponView) -> void:
	_parade = false
	_cheered = false


func _magazine(v: WeaponView) -> int:
	if v.player and v.player.weapons and v.player.weapons.current == v.data:
		return v.player.weapons.magazine()
	return v.data.magazine_size


func _mode(v: WeaponView) -> TinSergeantMode:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return null
	return p.weapons.mode as TinSergeantMode


## A springy settle from 0 to 1 (overshoots a little).
static func _spring(u: float) -> float:
	return 1.0 - exp(-6.0 * u) * cos(11.0 * u)


static func _ease_out_back(u: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(u - 1.0, 3.0) + c * pow(u - 1.0, 2.0)
