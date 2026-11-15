extends RefCounted
## T-Minus Six viewmodel motion (WeaponData.view_script). The six rockets in
## the pod (Rocket0..5) are the magazine: one leaves the pod per round (a
## swarm's rockets one by one, as each takes its turn). Painting while aiming
## arms them: every lock pops a rocket forward in its tube with its teal
## arming ring lit (Arm0..5) and lights a pip on the lock screen at the back
## (Pip0..5). The radar dish (Dish) turns slowly at rest and sweeps hard while
## aiming, its antenna bulb (Bulb) pulsing faster per lock. The countdown
## strip on the flank (Count0..2) blinks 3-2-1 as a swarm leaves; the fat
## trigger (Trigger) pulls on every shot.

const ROCKETS := 6
const COUNT := 3
## How far an armed rocket pops forward in its tube (model space, -Z forward).
const ARM_PUSH := Vector3(0.0, 0.0, -0.016)
const ARM_RATE := 16.0
## Dish turn rates (rad/s): at rest, sweeping, and extra per lock.
const DISH_IDLE := 0.8
const DISH_SWEEP := 5.0
const DISH_PER_LOCK := 1.6
const COUNT_STEP := 0.18
const TRIGGER_TIME := 0.1

var _rockets: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _pips: Array[Node3D] = []
var _count: Array[Node3D] = []
var _arm_k := PackedFloat32Array()
var _dish: Node3D
var _bulb: Node3D
var _trigger: Node3D
var _dish_angle := 0.0
var _pulse := 0.0
var _since_shot := 10.0


func setup(v: WeaponView) -> void:
	for i in ROCKETS:
		for prefix in ["Rocket", "Arm", "Pip"]:
			v.register_part("%s%d" % [prefix, i])
		_rockets.append(v.part("Rocket%d" % i))
		_arms.append(v.part("Arm%d" % i))
		_pips.append(v.part("Pip%d" % i))
	for i in COUNT:
		v.register_part("Count%d" % i)
		_count.append(v.part("Count%d" % i))
	for part in ["Dish", "Bulb", "Trigger"]:
		v.register_part(part)
	_dish = v.part("Dish")
	_bulb = v.part("Bulb")
	_trigger = v.part("Trigger")
	_arm_k.resize(ROCKETS)
	_arm_k.fill(0.0)


func fired(_v: WeaponView) -> void:
	_since_shot = 0.0


func event(_v: WeaponView, _event_name: StringName) -> void:
	pass


func update(v: WeaponView, delta: float) -> void:
	_since_shot += delta
	if v.is_reloading():
		return
	var mode := _mode(v)
	var aiming := v.player != null and mode != null and v.player.ads >= mode.AIM_IN
	var locks := mode.lock_count() if mode else 0
	var shown := v.data.magazine_size
	if mode:
		shown = v.player.weapons.magazine() + mode.queued()
	_pose_rockets(v, delta, shown, locks)
	for i in _pips.size():
		if _pips[i]:
			_pips[i].visible = i < locks
	_turn_dish(v, delta, aiming, locks)
	_blink_count(mode)
	if _trigger:
		var k := sin(clampf(_since_shot / TRIGGER_TIME, 0.0, 1.0) * PI)
		_trigger.transform = v.rest_transform("Trigger") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-22.0 * k)), Vector3.ZERO)


## Loaded rockets show; armed ones pop forward (overshooting a little) with their ring lit.
func _pose_rockets(v: WeaponView, delta: float, shown: int, locks: int) -> void:
	for i in _rockets.size():
		var rocket := _rockets[i]
		if rocket == null:
			continue
		rocket.visible = i < shown
		var want := 1.0 if i < locks else 0.0
		_arm_k[i] = lerpf(_arm_k[i], want, 1.0 - exp(-ARM_RATE * delta))
		var k := _arm_k[i]
		var push := ARM_PUSH * (k + 0.6 * sin(k * PI) * want)
		rocket.transform = v.rest_transform("Rocket%d" % i) * Transform3D(Basis(Vector3.FORWARD, k * PI * 0.5), push)
		if _arms[i]:
			_arms[i].visible = k > 0.5


func _turn_dish(v: WeaponView, delta: float, aiming: bool, locks: int) -> void:
	var rate := DISH_SWEEP + DISH_PER_LOCK * locks if aiming else DISH_IDLE
	_dish_angle = wrapf(_dish_angle + rate * delta, 0.0, TAU)
	if _dish:
		_dish.transform = v.rest_transform("Dish") * Transform3D(Basis(Vector3.UP, _dish_angle), Vector3.ZERO)
	_pulse += delta * (3.0 + 2.5 * locks + (3.0 if aiming else 0.0))
	if _bulb:
		var beat := pow(maxf(0.0, sin(_pulse * TAU * 0.5)), 6.0)
		_bulb.transform = v.rest_transform("Bulb").scaled_local(Vector3.ONE * (1.0 + 0.45 * beat))


## The strip stands lit at three; a swarm counts it down 3-2-1 and out, a
## dumb shot blinks it once.
func _blink_count(mode: TMinusSixMode) -> void:
	var lit := COUNT
	if mode and mode.since_swarm < COUNT_STEP * (COUNT + 1):
		lit = COUNT - int(mode.since_swarm / COUNT_STEP)
	elif _since_shot < 0.08:
		lit = 0
	for i in _count.size():
		if _count[i]:
			_count[i].visible = i < lit


func _mode(v: WeaponView) -> TMinusSixMode:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return null
	return p.weapons.mode as TMinusSixMode
