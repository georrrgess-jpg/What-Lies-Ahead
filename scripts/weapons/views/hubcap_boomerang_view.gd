extends RefCounted
## Road Rager viewmodel motion (WeaponData.view_script): the loaded hubcap
## lies on the launch tray between two pitching tyres, and the rack on the
## left flank shows the rest of the magazine (Cap0..1). A throw spins the
## tyres up with a screech, the hubcap shoots off the tray and the next one
## swings over from the rack. When a thrown hubcap comes home
## (HubcapShot -> WeaponView.weapon_event) the horseshoe magnet on the nose
## snaps back with the catch, the gun jolts and sparks fly; a pile-up catch
## (a hubcap that carved through four or more) throws gold.

const SPARES := 2
## Seconds: the hubcap leaves the tray, then the next one swings over from the rack.
const THROW := 0.08
const LOAD_START := 0.16
const LOAD_END := 0.3
## How far the hubcap flies off the tray before it vanishes, and where the
## next one comes from (the rack side), in model space.
const THROW_OFFSET := Vector3(0.0, 0.0, -0.14)
const LOAD_OFFSET := Vector3(-0.07, 0.03, 0.09)
## Tyre spin (rad/s): the kick a throw gives, the idle, and how fast it settles.
const WHEEL_KICK := 60.0
const WHEEL_IDLE := 1.5
const WHEEL_SETTLE := 3.0
const CATCH_TIME := 0.3
const EMBER := [Color(1.0, 0.55, 0.15), Color(1.0, 0.95, 0.8), Color(1.0, 0.3, 0.1)]
const GOLD := [Color(1.0, 0.85, 0.3), Color(1.0, 1.0, 0.8), Color(1.0, 0.6, 0.2)]

var _loaded: Node3D
var _wheels: Array[Node3D] = []
var _catcher: Node3D
var _muzzle: Node3D
var _caps: Array[Node3D] = []
var _since_shot := 10.0
var _since_catch := 10.0
var _pileup := false
var _wheel_speed := WHEEL_IDLE
var _wheel_angle := 0.0


func setup(v: WeaponView) -> void:
	for part in ["Loaded", "WheelL", "WheelR", "Catcher"]:
		v.register_part(part)
	for i in SPARES:
		v.register_part("Cap%d" % i)
		_caps.append(v.part("Cap%d" % i))
	_loaded = v.part("Loaded")
	_wheels.append(v.part("WheelL"))
	_wheels.append(v.part("WheelR"))
	_catcher = v.part("Catcher")
	_muzzle = v.model.find_child("Muzzle", true, false) as Node3D


func fired(_v: WeaponView) -> void:
	_since_shot = 0.0
	_wheel_speed = WHEEL_KICK


func event(v: WeaponView, event_name: StringName) -> void:
	_since_catch = 0.0
	_pileup = event_name == &"catch_pileup"
	if _muzzle:
		var at := v.model.global_transform.affine_inverse() * _muzzle.global_position
		v.spark_burst(at, Vector3(0, 1, 0.4), GOLD if _pileup else EMBER, 16 if _pileup else 9, 1.1, 0.35, 0.01)


func update(v: WeaponView, delta: float) -> void:
	_since_shot += delta
	_since_catch += delta
	if v.is_reloading():
		return
	var mag := _magazine(v)
	_spin_wheels(v, delta)
	_pose_loaded(v, mag)
	for i in _caps.size():
		if _caps[i]:
			_caps[i].visible = i < mag - 1
	_pose_catch(v)


## The pitching tyres turn the hubcap's way (one each way), fast after a throw.
func _spin_wheels(v: WeaponView, delta: float) -> void:
	_wheel_speed = lerpf(_wheel_speed, WHEEL_IDLE, 1.0 - exp(-WHEEL_SETTLE * delta))
	_wheel_angle = wrapf(_wheel_angle + _wheel_speed * delta, 0.0, TAU)
	var names := ["WheelL", "WheelR"]
	for i in _wheels.size():
		if _wheels[i]:
			var turn := _wheel_angle * (1.0 if i == 0 else -1.0)
			_wheels[i].transform = v.rest_transform(names[i]) * Transform3D(Basis(Vector3.UP, turn), Vector3.ZERO)


## The hubcap on the tray: shooting off, gone, swinging over from the rack, or at rest.
func _pose_loaded(v: WeaponView, mag: int) -> void:
	if _loaded == null:
		return
	var rest := v.rest_transform("Loaded")
	var t := _since_shot
	if t < THROW:
		var k := t / THROW
		_loaded.visible = true
		_loaded.transform = Transform3D(rest.basis * Basis(Vector3.UP, k * 4.0), rest.origin + THROW_OFFSET * k * k)
	elif t < LOAD_START or mag <= 0:
		_loaded.visible = false
	elif t < LOAD_END:
		var k := smoothstep(LOAD_START, LOAD_END, t)
		_loaded.visible = true
		var lift := Vector3(0.0, sin(k * PI) * 0.025, 0.0)
		_loaded.transform = Transform3D(rest.basis * Basis(Vector3.UP, (1.0 - k) * PI), rest.origin + LOAD_OFFSET * (1.0 - k) + lift)
	else:
		_loaded.visible = true
		_loaded.transform = rest


## The catch: the magnet snaps back and the whole gun jolts (harder for a pile-up).
func _pose_catch(v: WeaponView) -> void:
	var k := sin(clampf(_since_catch / CATCH_TIME, 0.0, 1.0) * PI)
	if _catcher:
		_catcher.transform = v.rest_transform("Catcher") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(k * 18.0)), Vector3(0.0, 0.0, 0.025 * k))
	if v.model and _since_catch < CATCH_TIME + 0.05:
		var jolt := 1.6 if _pileup else 1.0
		var rot := Vector3(5.0, -2.0, -5.0) * k * jolt
		v.model.transform = v.rest_transform("Root") * Transform3D(Basis.from_euler(rot * (PI / 180.0)), Vector3(0.0, -0.008, 0.016) * k * jolt)


func _magazine(v: WeaponView) -> int:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return v.data.magazine_size
	return p.weapons.magazine()
