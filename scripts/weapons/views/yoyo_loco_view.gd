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
## Inspect: walk the dog. The yo-yo drops out of the fork on its string and
## sleeps, spinning, then rolls off forward along an imaginary floor, hopping
## a little, and a tug snaps it home into the fork with a spark.

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
## Inspect: length, where the yo-yo sleeps under the fork and how far it
## walks (model space), its tether's rest length, and when each move starts.
const INSPECT_LENGTH := 3.0
const SLEEP_AT := Vector3(0.0, -0.19, -0.03)
const WALK := Vector3(0.0, -0.01, -0.2)
const TETHER_LENGTH := 0.063
const DROP := Vector2(0.35, 0.7)
const WALK_TIME := Vector2(1.05, 1.85)
const TUG := Vector2(1.95, 2.2)
const INSPECT_POSES := [
	[0.0, Vector3(0.14, -0.14, -0.62), Vector3(2.0, 12.0, -4.0)],
	[0.14, Vector3(0.08, -0.05, -0.66), Vector3(4.0, 40.0, -4.0)],
	[0.4, Vector3(0.09, -0.04, -0.66), Vector3(2.0, 44.0, -2.0)],
	[0.68, Vector3(0.1, -0.05, -0.66), Vector3(2.0, 40.0, 0.0)],
	[0.84, Vector3(0.1, -0.1, -0.6), Vector3(4.0, 30.0, 2.0)],
	[1.0, Vector3(0.14, -0.15, -0.62), Vector3(2.0, 6.0, 0.0)],
]
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
var _trick := 0


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


func inspect_length() -> float:
	return INSPECT_LENGTH


func inspect_poses() -> Array:
	return INSPECT_POSES


func inspect_start(_v: WeaponView) -> void:
	_trick = 0


func inspect(v: WeaponView, t: float) -> void:
	if _yoyo == null:
		return
	var fork := v.rest_transform("Yoyo").origin
	var at := fork
	var roll := 0.0
	if t >= DROP.x and t < TUG.x:
		var drop := WeaponInspect.window(t, DROP.x, DROP.y)
		var walk := WeaponInspect.window(t, WALK_TIME.x, WALK_TIME.y)
		at = fork.lerp(fork + SLEEP_AT, drop * drop * (3.0 - 2.0 * drop)) + WALK * walk
		# A pendulum sway while it sleeps, little hops as it walks.
		at.z += 0.012 * sin(t * 7.0) * WeaponInspect.hump(t, DROP.y, WALK_TIME.x + 0.1)
		at.y += 0.008 * absf(sin((t - WALK_TIME.x) * 18.0)) * WeaponInspect.hump(t, WALK_TIME.x, WALK_TIME.y)
		roll = walk * WALK.length() / 0.05
	elif t >= TUG.x:
		var back := WeaponInspect.window(t, TUG.x, TUG.y)
		at = (fork + SLEEP_AT + WALK).lerp(fork, back * back)
	_spin_rate = 60.0 if t > DROP.x and t < TUG.y else _spin_rate
	_yoyo.visible = true
	_yoyo.transform = Transform3D(v.rest_transform("Yoyo").basis * Basis(Vector3.RIGHT, -_spin - roll), at)
	_pose_tether(v, at)
	_cue(v, t)


func inspect_end(v: WeaponView) -> void:
	if _tether:
		_tether.transform = v.rest_transform("Tether")


## The string runs from the fork's throat to the yo-yo's axle.
func _pose_tether(v: WeaponView, to: Vector3) -> void:
	if _tether == null:
		return
	var rest := v.rest_transform("Tether")
	var from := rest.origin
	var span := to - from
	var length := span.length()
	if length < TETHER_LENGTH:
		_tether.transform = rest
		return
	var b := Basis.looking_at(span / length, Vector3.UP if absf(span.normalized().y) < 0.99 else Vector3.BACK)
	_tether.transform = Transform3D(b.scaled_local(Vector3(1.0, 1.0, length / TETHER_LENGTH)), from)
	_tether.visible = true


## Sounds (and the catch's spark) as each move starts.
func _cue(v: WeaponView, t: float) -> void:
	var cues: Array[float] = [DROP.x, WALK_TIME.x, TUG.x, TUG.y]
	if _trick >= cues.size() or t < cues[_trick]:
		return
	match _trick:
		0: Sfx.play(&"yoyo_throw", -12.0, 1.1)
		1: Sfx.play(&"yoyo_whirl", -10.0)
		2: Sfx.play(&"yoyo_rewind", -10.0, 1.2)
		3:
			Sfx.play(&"yoyo_catch", -8.0)
			event(v, &"catch")
	_trick += 1


func _mode(v: WeaponView) -> YoyoLocoMode:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return null
	return p.weapons.mode as YoyoLocoMode
