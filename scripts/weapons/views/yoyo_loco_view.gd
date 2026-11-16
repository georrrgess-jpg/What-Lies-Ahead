extends RefCounted
## Yo-Yo Loco viewmodel motion (WeaponData.view_script): the loaded yo-yo
## sleeps in the fork on the nose, slowly spinning, on its short glowing
## string (Tether); the spool on the right flank holds the wound string (Cell).
## A throw flicks the yo-yo out of the fork and it is gone while it is out
## (the string in the world takes over); the spool whirs, unwinding, and
## faster while a Sleeper grinds, when the wound string glows hot orange and
## the gun trembles and tugs forward on the string. When the yo-yo comes home
## (YoyoLocoShot -> WeaponView.weapon_event) it snaps back into the fork
## spinning hard, the gun jolts and sparks fly.

const IDLE_SPIN := 3.5
const CATCH_SPIN := 40.0
const SPIN_SETTLE := 3.0
## Seconds: the yo-yo leaves the fork, and the catch.
const THROW_TIME := 0.06
const CATCH_TIME := 0.26
## How far the yo-yo flies off the fork before it vanishes, and where it
## comes back in from (model space, -Z forward).
const THROW_OFFSET := Vector3(0.0, 0.0, -0.12)
const CATCH_FROM := Vector3(0.0, 0.004, -0.05)
## Spool spin (rad/s) while the yo-yo is out, and how fast it follows.
const SPOOL_OUT := 38.0
const SPOOL_FOLLOW := 10.0
const HOT := Color(1.0, 0.42, 0.1)
const LIME := [Color(0.85, 1.0, 0.35), Color(1.0, 1.0, 0.85), Color(1.0, 0.45, 0.85)]
const HOT_SPARKS := [Color(1.0, 0.55, 0.15), Color(1.0, 0.95, 0.6), Color(1.0, 0.3, 0.1)]

var _yoyo: Node3D
var _spool: Node3D
var _tether: Node3D
var _muzzle: Node3D
var _coil_mat: StandardMaterial3D
var _coil_emission := Color.WHITE
var _since_shot := 10.0
var _since_catch := 10.0
var _hit := false
var _spin := 0.0
var _spin_rate := IDLE_SPIN
var _spool_angle := 0.0
var _spool_rate := 0.0
var _time := 0.0


func setup(v: WeaponView) -> void:
	for part in ["Yoyo", "Spool", "Tether"]:
		v.register_part(part)
	_yoyo = v.part("Yoyo")
	_spool = v.part("Spool")
	_tether = v.part("Tether")
	_muzzle = v.model.find_child("Muzzle", true, false) as Node3D
	var coil := v.part("Cell") as MeshInstance3D
	if coil and coil.mesh and coil.mesh.get_surface_count() > 0:
		_coil_mat = coil.get_surface_override_material(0) as StandardMaterial3D
		if _coil_mat:
			_coil_emission = _coil_mat.emission


func fired(_v: WeaponView) -> void:
	_since_shot = 0.0


func event(v: WeaponView, event_name: StringName) -> void:
	_since_catch = 0.0
	_hit = event_name == &"catch_hit"
	_spin_rate = CATCH_SPIN
	if _muzzle:
		var at := v.model.global_transform.affine_inverse() * _muzzle.global_position
		v.spark_burst(at, Vector3(0, 1, 0.3), LIME, 9 if _hit else 5, 0.9, 0.3, 0.008)


func update(v: WeaponView, delta: float) -> void:
	_since_shot += delta
	_since_catch += delta
	_time += delta
	if v.is_reloading():
		return
	var mode := _mode(v)
	var out := mode != null and mode.is_out()
	var heat := mode.heat() if mode else 0.0
	_spin_rate = lerpf(_spin_rate, IDLE_SPIN, 1.0 - exp(-SPIN_SETTLE * delta))
	_spin = fmod(_spin + _spin_rate * delta, TAU)
	_spool_rate = lerpf(_spool_rate, SPOOL_OUT * (1.0 + 1.5 * heat) if out else 0.0, 1.0 - exp(-SPOOL_FOLLOW * delta))
	_spool_angle = fmod(_spool_angle + _spool_rate * delta, TAU)
	if _spool:
		_spool.transform = v.rest_transform("Spool") * Transform3D(Basis(Vector3.RIGHT, -_spool_angle), Vector3.ZERO)
	_pose_yoyo(v, out)
	if _tether:
		_tether.visible = not out
	if _coil_mat:
		_coil_mat.emission = _coil_emission.lerp(HOT, heat)
	_pose_root(v, heat)


## The loaded yo-yo: flicked out, gone while out, snapping back in, or asleep in the fork.
func _pose_yoyo(v: WeaponView, out: bool) -> void:
	if _yoyo == null:
		return
	var rest := v.rest_transform("Yoyo")
	var spin := Basis(Vector3.RIGHT, -_spin)
	if _since_shot < THROW_TIME:
		var k := _since_shot / THROW_TIME
		_yoyo.visible = true
		_yoyo.transform = Transform3D(rest.basis * spin, rest.origin + THROW_OFFSET * k * k)
	elif out:
		_yoyo.visible = false
	else:
		var k := clampf(_since_catch / CATCH_TIME, 0.0, 1.0)
		var settle := 1.0 - k
		_yoyo.visible = true
		_yoyo.transform = Transform3D(rest.basis * spin, rest.origin + CATCH_FROM * settle * settle * settle)


## The catch jolts the gun; a Sleeper tugs it forward on the string and makes it tremble.
func _pose_root(v: WeaponView, heat: float) -> void:
	if v.model == null:
		return
	var k := sin(clampf(_since_catch / CATCH_TIME, 0.0, 1.0) * PI) * (1.4 if _hit else 1.0)
	var buzz := heat * 0.6 + (0.25 if heat > 0.0 else 0.0)
	var rot := Vector3(-5.0, 1.5, 4.0) * k + Vector3(sin(_time * 63.0), sin(_time * 47.0 + 1.0), 0.0) * buzz
	var pos := Vector3(0.0, -0.006, 0.014) * k + Vector3(0.0, -0.004, -0.012) * minf(1.0, heat * 3.0)
	v.model.transform = v.rest_transform("Root") * Transform3D(Basis.from_euler(rot * (PI / 180.0)), pos)
	if heat > 0.0 and _muzzle and randf() < heat * 0.25:
		var at := v.model.global_transform.affine_inverse() * _muzzle.global_position
		v.spark_burst(at, Vector3(0, 0.6, -1), HOT_SPARKS, 2, 0.7, 0.2, 0.006)


func _mode(v: WeaponView) -> YoyoLocoMode:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return null
	return p.weapons.mode as YoyoLocoMode
