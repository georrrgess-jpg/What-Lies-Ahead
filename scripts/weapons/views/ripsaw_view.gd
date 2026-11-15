extends RefCounted
## Toxic Ripsaw viewmodel motion (WeaponData.view_script). Reads the held
## weapon's RipsawMode (`rev`, `fuel`, `biting`):
##   chain     the 22 teeth run round the bar (the path built by
##             art/blender/build_weapons_ripsaw.py: CHAIN_* below), wrapping
##             round inside the receiver; the nose sprocket turns with them
##   lunge     revving swings the bar out in front (lifted, turned in and
##             canted) so the saw is pressed into what is ahead
##   shake     the whole weapon buzzes with the rev and judders while biting
##   gauge     the needle swings up with the rev and flutters
##   slime     each canister holds a quarter of the saw's fuel and drains in
##             turn, front first; bubbles rise faster while the saw runs
##   pump      every shotgun blast racks the under-pump back and forth
##   equip     the pull-start: the pink handle yanks up on its cord, the engine
##             catches with a spurt of the chain and a puff from the exhaust
## The reload (ripsaw_reload.gd) swaps the canister rack.

const CHAIN_START := 0.325
const CHAIN_R := 0.058
const TEETH := 22
## Chain speed at full rev (m/s, model space) and the nose sprocket's radius.
const CHAIN_SPEED := 0.62
const SPROCKET_R := 0.043
## Model-space buzz of the weapon at full rev, and the extra judder while biting.
const BUZZ := 0.0016
const JUDDER := 0.0045
## The sawing pose (model-space offset and degrees) and how fast it is taken (1/s).
const LUNGE_POS := Vector3(-0.05, 0.06, -0.07)
const LUNGE_ROT := Vector3(4.0, 16.0, -16.0)
const LUNGE_RATE := 9.0
const CANISTERS := 4
const BUBBLES_PER := 2
## Height of the slime in a full canister (model space).
const SLIME_HEIGHT := 0.044
## Gauge needle: angle at rest and at full rev (degrees).
const NEEDLE_REST := -55.0
const NEEDLE_FULL := 95.0
const PUMP_KICK := 0.02
const PUMP_TIME := 0.32
## Equip flourish (seconds from the weapon being raised).
const PULL_START := 0.06
const PULL_END := 0.26
const CATCH := 0.3
const RETURN_END := 0.44
const PULL_OFFSET := Vector3(-0.025, 0.085, 0.05)
const CORD_LENGTH := 0.05
const EXHAUST_COLORS := [Color(0.75, 1.0, 0.35), Color(0.6, 0.6, 0.7), Color(0.9, 0.95, 0.8)]

var _teeth: Array[Node3D] = []
var _tooth_u: PackedFloat32Array = []
var _tooth_rest_angle: PackedFloat32Array = []
var _slimes: Array[Node3D] = []
var _bubbles: Array[Node3D] = []
var _rests := {}
var _length := 0.0
var _run := 0.0
var _nose := Vector2.ZERO          # Godot (y, z) of the nose sprocket's centre
var _travel := 0.0
var _spurt := 0.0
var _time := 0.0
var _equip := 10.0
var _caught := false
var _pump := 10.0
var _levels: PackedFloat32Array = [1.0, 1.0, 1.0, 1.0]
var _bubble_phase: PackedFloat32Array = []
var _needle := 0.0
var _lunge := 0.0


func setup(v: WeaponView) -> void:
	var names: Array[String] = ["Sprocket", "GaugeNeedle", "PullHandle", "PullCord"]
	for i in TEETH:
		names.append("Tooth%d" % i)
	for i in CANISTERS:
		names.append("Slime%d" % i)
	for i in CANISTERS * BUBBLES_PER:
		names.append("Bubble%d" % i)
	for part in names:
		v.register_part(part)
		_rests[part] = v.rest_transform(part)
	var sprocket: Transform3D = _rests["Sprocket"]
	_nose = Vector2(sprocket.origin.y, sprocket.origin.z)
	_run = -_nose.y - CHAIN_START
	_length = 2.0 * _run + PI * CHAIN_R
	for i in TEETH:
		var tooth := v.part("Tooth%d" % i)
		if tooth == null:
			continue
		var u := (i + 0.5) * _length / TEETH
		_teeth.append(tooth)
		_tooth_u.append(u)
		_tooth_rest_angle.append(_angle(u))
	for i in CANISTERS:
		_slimes.append(v.part("Slime%d" % i))
	for i in CANISTERS * BUBBLES_PER:
		_bubbles.append(v.part("Bubble%d" % i))
		_bubble_phase.append(fmod(i * 0.37, 1.0))
	_equip = 0.0 if v.player else 10.0


func fired(_v: WeaponView) -> void:
	_pump = 0.0


func event(_v: WeaponView, _name: StringName) -> void:
	pass


func update(v: WeaponView, delta: float) -> void:
	_time += delta
	var mode := _mode(v)
	var rev := float(mode.get("rev")) if mode else 0.0
	var biting := bool(mode.get("biting")) if mode else false
	var fuel := float(mode.get("fuel")) if mode else 1.0
	_update_equip(v, delta)
	_travel = fmod(_travel + (rev * CHAIN_SPEED + _spurt) * delta, _length)
	_spurt = maxf(0.0, _spurt - 2.4 * delta)
	_place_chain(v)
	_update_needle(v, rev, delta)
	if v.is_reloading():
		# The reload swaps the rack: the new one shows full once it is in.
		var w := v.player.weapons if v.player else null
		if w and w.reload_progress() > 0.72:
			fuel = 1.0
	else:
		_update_pump(v, delta)
		_lunge = lerpf(_lunge, 1.0 if rev > 0.05 else 0.0, 1.0 - exp(-LUNGE_RATE * delta))
		_shake(v, rev, biting)
	_update_slime(fuel, rev, delta)


## The held weapon's RipsawMode, or null (staged in a menu, or not held).
func _mode(v: WeaponView) -> WeaponMode:
	var w := v.player.weapons if v.player else null
	if w == null or w.current != v.data:
		return null
	return w.mode


# --- chain ---------------------------------------------------------------------

## Godot (y, z) of the chain path at distance u.
func _point(u: float) -> Vector2:
	if u < _run:
		return Vector2(_nose.x + CHAIN_R, -(CHAIN_START + u))
	if u < _run + PI * CHAIN_R:
		var a := (u - _run) / CHAIN_R
		return Vector2(_nose.x + cos(a) * CHAIN_R, _nose.y - sin(a) * CHAIN_R)
	return Vector2(_nose.x - CHAIN_R, _nose.y + (u - _run - PI * CHAIN_R))


## Turn of a tooth about X at distance u (0 on the top run, -PI on the bottom).
func _angle(u: float) -> float:
	return -clampf((u - _run) / CHAIN_R, 0.0, PI)


func _place_chain(v: WeaponView) -> void:
	for i in _teeth.size():
		var u := fmod(_tooth_u[i] + _travel, _length)
		var p := _point(u)
		_teeth[i].transform = Transform3D(Basis(Vector3.RIGHT, _angle(u) - _tooth_rest_angle[i]), Vector3(0.0, p.x, p.y))
	var sprocket := v.part("Sprocket")
	if sprocket:
		var rest: Transform3D = _rests["Sprocket"]
		sprocket.transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, -_travel / SPROCKET_R), rest.origin)


# --- body ----------------------------------------------------------------------

## The sawing pose, and the weapon buzzing with the engine (fast sines: the
## same at any frame rate).
func _shake(v: WeaponView, rev: float, biting: bool) -> void:
	var root := v.part("Root")
	if root == null:
		return
	var rest := v.rest_transform("Root")
	var k := rev * BUZZ + (JUDDER if biting else 0.0)
	var jitter := Vector3(sin(_time * 83.0) * k * 0.6, sin(_time * 97.0 + 1.3) * k, sin(_time * 71.0 + 0.4) * k * 0.4)
	var roll := sin(_time * 61.0) * k * 2.5
	var turn := Basis.from_euler(LUNGE_ROT * (PI / 180.0) * _lunge)
	root.transform = Transform3D(rest.basis * turn * Basis(Vector3.BACK, roll), rest.origin + LUNGE_POS * _lunge + jitter)


func _update_needle(v: WeaponView, rev: float, delta: float) -> void:
	var needle := v.part("GaugeNeedle")
	if needle == null:
		return
	var goal := lerpf(NEEDLE_REST, NEEDLE_FULL, rev) + sin(_time * 37.0) * 6.0 * rev
	_needle = lerpf(_needle, goal, 1.0 - exp(-14.0 * delta))
	var rest: Transform3D = _rests["GaugeNeedle"]
	needle.transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, deg_to_rad(-_needle)), rest.origin)


## Each blast racks the pump back and forward (the support hand rides it).
func _update_pump(v: WeaponView, delta: float) -> void:
	var pump := v.part("Pump")
	if pump == null:
		return
	_pump += delta
	var t := clampf(_pump / PUMP_TIME, 0.0, 1.0)
	var back := sin(t * PI) * PUMP_KICK * (1.0 - t * 0.3)
	var rest := v.rest_transform("Pump")
	pump.transform = Transform3D(rest.basis, rest.origin + Vector3(0.0, 0.0, back))


func _update_slime(fuel: float, rev: float, delta: float) -> void:
	var speed := 0.35 + rev * 1.4 + (1.2 if _pump < PUMP_TIME else 0.0)
	for i in _slimes.size():
		var goal := clampf(fuel * CANISTERS - (CANISTERS - 1 - i), 0.0, 1.0)
		_levels[i] = lerpf(_levels[i], goal, 1.0 - exp(-10.0 * delta))
		var slime := _slimes[i]
		if slime == null:
			continue
		var rest: Transform3D = _rests["Slime%d" % i]
		var level := maxf(0.03, _levels[i])
		# A little slosh on top while the engine runs.
		var slosh := 1.0 + sin(_time * 23.0 + i) * 0.03 * rev
		slime.transform = Transform3D(rest.basis.scaled(Vector3(1.0, level * slosh, 1.0)), rest.origin)
		for j in BUBBLES_PER:
			var k := i * BUBBLES_PER + j
			var bubble := _bubbles[k]
			if bubble == null:
				continue
			_bubble_phase[k] = fmod(_bubble_phase[k] + speed * delta * (1.0 + 0.3 * j), 1.0)
			var top := SLIME_HEIGHT * _levels[i] - 0.006
			var rest_b: Transform3D = _rests["Bubble%d" % k]
			var floor_y := rest_b.origin.y - (0.01 + 0.016 * j)
			bubble.visible = top > 0.01
			bubble.transform = Transform3D(rest_b.basis, Vector3(rest_b.origin.x, floor_y + 0.004 + _bubble_phase[k] * maxf(0.0, top - 0.004),
				rest_b.origin.z + sin(_time * 9.0 + k) * 0.0015))


# --- equip flourish ------------------------------------------------------------

func _update_equip(v: WeaponView, delta: float) -> void:
	if _equip > RETURN_END + 0.1:
		return
	_equip += delta
	var handle := v.part("PullHandle")
	var cord := v.part("PullCord")
	if handle == null or cord == null:
		return
	var out := 0.0
	if _equip < PULL_START:
		out = 0.0
	elif _equip < PULL_END:
		out = ease((_equip - PULL_START) / (PULL_END - PULL_START), 0.4)
	elif _equip < CATCH:
		out = 1.0
	else:
		out = 1.0 - ease(clampf((_equip - CATCH) / (RETURN_END - CATCH), 0.0, 1.0), 2.2)
	if _equip >= CATCH and not _caught:
		_caught = true
		_spurt = 1.6
		v.spark_burst(_vent(v), Vector3(0, 0.4, 1), EXHAUST_COLORS, 10, 0.5, 0.45, 0.012)
	var rest: Transform3D = _rests["PullHandle"]
	var offset := PULL_OFFSET * out
	handle.transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, -0.5 * out), rest.origin + offset)
	var cord_rest: Transform3D = _rests["PullCord"]
	# The cord runs from the grommet to the handle.
	if offset.length() < 0.002:
		cord.transform = cord_rest
		return
	# Its mesh runs CORD_LENGTH down from the pivot: map that onto the offset.
	var along := -offset / CORD_LENGTH
	var side := offset.cross(Vector3.FORWARD).normalized()
	var front := side.cross(along).normalized()
	cord.transform = Transform3D(Basis(side, along, front), cord_rest.origin)


## The exhaust (VentPoint) in the model's space.
func _vent(v: WeaponView) -> Vector3:
	var vent := v.model.find_child("VentPoint", true, false) as Node3D if v.model else null
	return vent.position if vent else Vector3.ZERO
