extends RefCounted
## Sarsaparilla Six viewmodel motion (WeaponData.view_script).
##
## The cage cylinder (Cylinder) holds the magazine as six glass soda-bottle
## rounds (Round0..5): a fired round loses its crown cap (Cap0..5) and its
## soda (Soda0..5). After each shot the cylinder turns a sixth (eased, with a
## little overshoot) to bring the next round under the hammer; the sixth,
## Round5 with its gold star cap, is the Last Call, and its red ring (Halo5)
## pulses while it is next. The hammer (Hammer) is cocked at rest, falls on
## every shot and is thumbed back for the next tap; while the trigger is held
## (SarsaparillaSixMode.fanning) the off hand (ArmL) leaves the grip, turns
## palm down over the frame and slaps the hammer back for every shot. The
## trigger (Trigger) pulls on each shot and soda spray puffs from the muzzle.
## Fizz bubbles (Bubble0..6) drift up through the bottle under the barrel,
## faster after shots.
## Inspect: the thumb spins the cylinder (it ratchets to a stop), then the
## gun is tossed out of the hand, turns over once in the air and drops back
## into the grip. One time in RARE_CHANCE the bottle's cap blows instead and
## soda foams out of its neck.

const ROUNDS := 6
const BUBBLES := 7
## Hammer: cocked back (degrees about its pin), its fall and the thumb's cock (seconds).
const COCK_DEG := 30.0
const FALL_TIME := 0.025
const RECOCK_START := 0.07
const RECOCK_TIME := 0.12
## Seconds the cylinder takes to turn to the next round.
const TURN_TIME := 0.075
const TRIGGER_TIME := 0.09
## The fan hand (ArmLFist, modelled palm down over the cocked hammer): where it comes
## up from, its sweep forward and back (offsets from rest, model space), how far the
## cupping hand (ArmL) drops away meanwhile, and how fast it comes in and goes back.
const FAN_FROM := Vector3(-0.12, -0.2, 0.08)
const FAN_FORWARD := Vector3(0.0, 0.012, -0.024)
const FAN_BACK := Vector3(0.0, -0.002, 0.022)
const GRIP_DROP := Vector3(-0.04, -0.2, 0.06)
## The gun's fanning stance: lower and canted (model root offset; degrees).
const FAN_HIP := Vector3(0.03, -0.05, 0.03)
const FAN_HIP_ROT := Vector3(4.0, 8.0, -14.0)
const FAN_IN := 14.0
const FAN_OUT := 7.0
## Bottle bubbles: the stretch of soda they drift through (model -Z) and speed (m/s).
const BUBBLE_FRONT := -0.186
const BUBBLE_BACK := -0.092
const BUBBLE_SPEED := 0.012
const BUBBLE_SHOT := 0.09
## Inspect.
const INSPECT_LENGTH := 3.4
const SPIN_START := 0.55
const SPIN_END := 1.45
const SPIN_TURNS := 2.5
const TOSS_START := 1.6
const TOSS_END := 2.45
const TOSS_HEIGHT := 0.2
## Where the gun turns over in the toss (its middle, model space).
const TOSS_PIVOT := Vector3(0.0, 0.0, -0.06)
const RARE_CHANCE := 1.0 / 15.0
const INSPECT_POSES := [
	[0.0, Vector3(0.14, -0.14, -0.62), Vector3(2.0, 14.0, -4.0)],
	[0.14, Vector3(0.06, -0.12, -0.5), Vector3(8.0, 30.0, 28.0)],
	[0.42, Vector3(0.05, -0.12, -0.49), Vector3(10.0, 34.0, 30.0)],
	[0.5, Vector3(0.07, -0.17, -0.55), Vector3(6.0, 22.0, 6.0)],
	[0.74, Vector3(0.07, -0.17, -0.55), Vector3(6.0, 20.0, 4.0)],
	[0.86, Vector3(0.08, -0.13, -0.52), Vector3(14.0, 26.0, 10.0)],
	[1.0, Vector3(0.14, -0.15, -0.62), Vector3(4.0, 6.0, 0.0)],
]
const FIZZ := [Color(1.0, 0.957, 0.839), Color(1.0, 0.647, 0.227), Color(1.0, 0.85, 0.6)]
const LAST_CALL := [Color(1.0, 0.239, 0.431), Color(1.0, 0.957, 0.839), Color(1.0, 0.82, 0.25)]

var _cylinder: Node3D
var _hammer: Node3D
var _trigger: Node3D
var _arm: Node3D
var _fan_hand: Node3D
var _hip := false
var _halo: Node3D
var _muzzle: Node3D
var _caps: Array[Node3D] = []
var _sodas: Array[Node3D] = []
var _bubbles: Array[Node3D] = []
var _bubble_at := PackedFloat32Array()
var _since_shot := 10.0
var _spent := 0
var _turn := 0.0
var _turn_from := 0.0
var _turn_t := 1.0
var _fan := 0.0
var _interval := 0.11
var _fizz := 0.0
var _clock := 0.0
## Inspect state: the gun's nodes (not the arms) and their rest, the rare roll.
var _gun_nodes: Array[Node3D] = []
var _rare := false
var _spin_clicks := 0
var _tossed := false
var _caught := false


func setup(v: WeaponView) -> void:
	for p in ["Cylinder", "Hammer", "Trigger", "ArmL", "ArmLFist", "Halo5", "Cell"]:
		v.register_part(p)
	for i in ROUNDS:
		for prefix in ["Round", "Cap", "Soda"]:
			v.register_part("%s%d" % [prefix, i])
		_caps.append(v.part("Cap%d" % i))
		_sodas.append(v.part("Soda%d" % i))
	for k in BUBBLES:
		v.register_part("Bubble%d" % k)
		_bubbles.append(v.part("Bubble%d" % k))
		_bubble_at.append(v.rest_transform("Bubble%d" % k).origin.z if v.part("Bubble%d" % k) else 0.0)
	_cylinder = v.part("Cylinder")
	_hammer = v.part("Hammer")
	_trigger = v.part("Trigger")
	_arm = v.part("ArmL")
	_fan_hand = v.part("ArmLFist")
	_halo = v.part("Halo5")
	_muzzle = v.model.find_child("Muzzle", true, false) as Node3D
	_interval = v.data.fire_interval
	_spent = _spent_now(v)
	_turn = _goal(_spent)
	for child in v.model.get_children():
		var n := child as Node3D
		if n and not String(n.name).begins_with("Arm"):
			v.register_part(String(n.name))
			_gun_nodes.append(n)


func fired(v: WeaponView) -> void:
	_since_shot = 0.0
	_fizz = 1.0
	if _muzzle:
		var at := v.model.global_transform.affine_inverse() * _muzzle.global_position
		v.spark_burst(at, Vector3(0, 0.3, -1), FIZZ, 3, 0.8, 0.22, 0.006)


func event(v: WeaponView, event_name: StringName) -> void:
	if event_name != SarsaparillaSixMode.LAST_CALL_EVENT or _muzzle == null:
		return
	var at := v.model.global_transform.affine_inverse() * _muzzle.global_position
	v.spark_burst(at, Vector3(0, 0.4, -1), LAST_CALL, 14, 1.4, 0.4, 0.008)


func update(v: WeaponView, delta: float) -> void:
	_since_shot += delta
	_clock += delta
	_fizz = maxf(0.0, _fizz - delta * 1.5)
	_drift_bubbles(v, delta)
	if v.is_reloading():
		_fan = 0.0
		_spent = 0
		_turn = 0.0
		_turn_t = 1.0
		return
	var mode := _mode(v)
	_pose_rounds(v, delta)
	_pose_hammer(v, mode)
	_pose_fan_hand(v, mode, delta)
	if _trigger:
		var k := sin(clampf(_since_shot / TRIGGER_TIME, 0.0, 1.0) * PI)
		_trigger.transform = v.rest_transform("Trigger") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-20.0 * k)), Vector3.ZERO)
	if _halo:
		_halo.visible = mode != null and mode.is_last_call()
		if _halo.visible:
			var beat := 0.5 + 0.5 * sin(_clock * 10.0)
			_halo.transform = v.rest_transform("Halo5").scaled_local(Vector3.ONE * (1.0 + 0.18 * beat))


## Spent rounds lose cap and soda; the cylinder eases round to the next one.
func _pose_rounds(v: WeaponView, delta: float) -> void:
	var spent := _spent_now(v)
	if spent != _spent:
		_turn_from = _turn
		_turn_t = 0.0 if spent > _spent else 1.0
		_spent = spent
	for i in ROUNDS:
		var loaded := i >= _spent
		if _caps[i]:
			_caps[i].visible = loaded
		if _sodas[i]:
			_sodas[i].visible = loaded
	_turn_t = minf(1.0, _turn_t + delta / TURN_TIME)
	var t := _turn_t
	var k := 1.0 - pow(1.0 - t, 3.0) + 0.12 * sin(t * PI)
	_turn = lerpf(_turn_from, _goal(_spent), k) if t < 1.0 else _goal(_spent)
	if _cylinder:
		_cylinder.transform = v.rest_transform("Cylinder") * Transform3D(Basis(Vector3.BACK, _turn), Vector3.ZERO)


## Cocked at rest; falls on the shot; the thumb cocks it again for a tap,
## the fanning hand's sweep cocks it while fanning.
func _pose_hammer(v: WeaponView, mode: SarsaparillaSixMode) -> void:
	if _hammer == null:
		return
	var cock := 1.0
	if _spent >= ROUNDS:
		cock = 0.0 if _since_shot < RECOCK_START + 0.3 else 1.0
	if _since_shot < FALL_TIME:
		cock = 1.0 - _since_shot / FALL_TIME
	elif mode and mode.fanning:
		cock = smoothstep(0.55, 0.95, _since_shot / _interval)
	elif _since_shot < RECOCK_START + RECOCK_TIME and _spent < ROUNDS:
		cock = smoothstep(RECOCK_START, RECOCK_START + RECOCK_TIME, _since_shot)
	_hammer.transform = v.rest_transform("Hammer") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(COCK_DEG * cock)), Vector3.ZERO)


## The off hand comes up over the frame while fanning; each shot it has just
## slapped the hammer back, then it swings forward ready for the next.
func _pose_fan_hand(v: WeaponView, mode: SarsaparillaSixMode, delta: float) -> void:
	if _arm == null or _fan_hand == null:
		return
	var on := mode != null and (mode.fanning or mode.pull_shots > 1 and _since_shot < 0.12)
	_fan = lerpf(_fan, 1.0 if on else 0.0, 1.0 - exp(-(FAN_IN if on else FAN_OUT) * delta))
	if _fan < 0.002:
		_arm.transform = v.rest_transform("ArmL")
		_fan_hand.visible = false
		if _hip:
			_hip = false
			v.model.transform = v.rest_transform("Root")
		return
	var k := _fan * _fan * (3.0 - 2.0 * _fan)
	# The cupping hand drops away under the gun; the fan hand comes up from the lower left.
	_arm.transform = v.rest_transform("ArmL").translated(GRIP_DROP * k)
	var u := clampf(_since_shot / _interval, 0.0, 1.0)
	# Back at the shot, forward until 55% of the interval, then the next slap.
	var sweep := 1.0 - smoothstep(0.0, 0.55, u) + smoothstep(0.6, 1.0, u) if on else 1.0
	var pos := FAN_FROM * (1.0 - k) + FAN_FORWARD.lerp(FAN_BACK, sweep)
	var tilt := Basis.from_euler(Vector3(deg_to_rad(-12.0 * sweep), 0.0, deg_to_rad(-25.0 * (1.0 - k))))
	var rest := v.rest_transform("ArmLFist")
	_fan_hand.visible = true
	_fan_hand.transform = Transform3D(rest.basis * tilt, rest.origin + pos)
	# The gun drops to the hip and cants for the fan, bucking a little with every shot.
	var buck := (1.0 - smoothstep(0.0, 0.5, u)) * k if on else 0.0
	var hip := Basis.from_euler(Vector3(deg_to_rad(FAN_HIP_ROT.x + 6.0 * buck), deg_to_rad(FAN_HIP_ROT.y), deg_to_rad(FAN_HIP_ROT.z)) * k)
	v.model.transform = v.rest_transform("Root") * Transform3D(hip, FAN_HIP * k)
	_hip = true


## Bubbles drift along the bottle to the neck, wobbling, faster after a shot.
func _drift_bubbles(v: WeaponView, delta: float) -> void:
	var span := BUBBLE_BACK - BUBBLE_FRONT
	for k in _bubbles.size():
		var b := _bubbles[k]
		if b == null:
			continue
		var speed := BUBBLE_SPEED * (1.0 + 0.4 * (k % 3)) + BUBBLE_SHOT * _fizz
		_bubble_at[k] -= speed * delta
		if _bubble_at[k] < BUBBLE_FRONT:
			_bubble_at[k] += span
		var rest := v.rest_transform("Bubble%d" % k)
		var wob := Vector3(sin(_clock * 7.0 + k * 1.9) * 0.0018, 0.003 + sin(_clock * 5.0 + k) * 0.0015, 0.0)
		# Small near the ends of the stretch (they pop at the neck and are born at the base).
		var edge := clampf(minf(_bubble_at[k] - BUBBLE_FRONT, BUBBLE_BACK - _bubble_at[k]) / 0.012, 0.0, 1.0)
		b.transform = Transform3D(rest.basis.scaled(Vector3.ONE * maxf(0.05, edge)), Vector3(rest.origin.x, rest.origin.y, _bubble_at[k]) + wob)


func _goal(spent: int) -> float:
	return -float(spent) * TAU / ROUNDS


func _spent_now(v: WeaponView) -> int:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return 0
	return clampi(ROUNDS - p.weapons.magazine(), 0, ROUNDS)


func _mode(v: WeaponView) -> SarsaparillaSixMode:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return null
	return p.weapons.mode as SarsaparillaSixMode


# --- inspect -------------------------------------------------------------------

func inspect_length() -> float:
	return INSPECT_LENGTH


func inspect_poses() -> Array:
	return INSPECT_POSES


func inspect_start(v: WeaponView) -> void:
	_rare = v.inspect_rare(RARE_CHANCE)
	_spin_clicks = 0
	_tossed = false
	_caught = false


func inspect(v: WeaponView, t: float) -> void:
	_inspect_spin(v, t)
	_inspect_toss(v, t)


## The thumb flicks the cylinder: it spins SPIN_TURNS and ratchets to a stop
## on the round it started from.
func _inspect_spin(v: WeaponView, t: float) -> void:
	if _cylinder == null or t < SPIN_START or t > SPIN_END + 0.1:
		return
	var u := clampf((t - SPIN_START) / (SPIN_END - SPIN_START), 0.0, 1.0)
	var k := 1.0 - pow(1.0 - u, 3.0)
	var angle := _goal(_spent) + k * SPIN_TURNS * TAU
	_cylinder.transform = v.rest_transform("Cylinder") * Transform3D(Basis(Vector3.BACK, angle), Vector3.ZERO)
	var clicks := int(k * SPIN_TURNS * ROUNDS)
	if clicks > _spin_clicks:
		_spin_clicks = clicks
		Sfx.play(&"ssx_click", -12.0 - 6.0 * k, 1.1 - 0.15 * k)


## The toss: the gun leaves the hand, turns over once and drops back in (the
## hand dips to take it). The rare one: the bottle cap blows and soda foams out.
func _inspect_toss(v: WeaponView, t: float) -> void:
	if t < TOSS_START - 0.1 or t > TOSS_END + 0.4:
		return
	var u := clampf((t - TOSS_START) / (TOSS_END - TOSS_START), 0.0, 1.0)
	if u > 0.0 and not _tossed:
		_tossed = true
		Sfx.play(&"ssx_click", -8.0, 0.8)
	var lift := TOSS_HEIGHT * 4.0 * u * (1.0 - u)
	var turn := -TAU * (u * u * (3.0 - 2.0 * u))
	var spin := Transform3D(Basis(Vector3.RIGHT, turn), Vector3.ZERO)
	var about := Transform3D(Basis.IDENTITY, TOSS_PIVOT + Vector3(0.0, lift, 0.0)) * spin * Transform3D(Basis.IDENTITY, -TOSS_PIVOT)
	for n in _gun_nodes:
		var base := n.transform if n == _cylinder or n == _hammer or n == _trigger or _bubbles.has(n) else v.rest_transform(String(n.name))
		n.transform = about * base
	# The catch: the hand dips under the weight and comes back up.
	var dip := WeaponInspect.hump(t, TOSS_END - 0.06, TOSS_END + 0.3) if t > TOSS_END - 0.06 else 0.0
	var arm := v.part("ArmR")
	if arm == null:
		v.register_part("ArmR")
		arm = v.part("ArmR")
	if arm:
		var lower := WeaponInspect.hump(t, TOSS_START - 0.1, TOSS_END) * 0.02
		arm.transform = v.rest_transform("ArmR") * Transform3D(Basis.IDENTITY, Vector3(0.0, -lower - 0.015 * dip, 0.0))
	if u >= 1.0 and not _caught:
		_caught = true
		Sfx.play(&"ssx_click", -6.0, 0.7)
		if _rare:
			_foam(v)
	if _rare and _caught and t < TOSS_END + 0.35:
		var vent := v.model.find_child("VentPoint", true, false) as Node3D
		if vent and int(t * 30.0) % 2 == 0:
			var at := v.model.global_transform.affine_inverse() * vent.global_position
			v.spark_burst(at, Vector3(0, 1, -0.6), FIZZ, 4, 0.7, 0.5, 0.007)


## The rare inspect: the cap blows off the bottle with a pop.
func _foam(v: WeaponView) -> void:
	Sfx.play(&"ssx_cap_ping", -6.0, 0.9)
	Sfx.play(&"ssx_last_call", -12.0, 1.2)
	var vent := v.model.find_child("VentPoint", true, false) as Node3D
	if vent:
		var at := v.model.global_transform.affine_inverse() * vent.global_position
		v.spark_burst(at, Vector3(0, 1, -0.4), LAST_CALL, 12, 1.2, 0.5, 0.008)


func inspect_end(v: WeaponView) -> void:
	for n in _gun_nodes:
		if n != _cylinder and n != _hammer and n != _trigger and not _bubbles.has(n):
			n.transform = v.rest_transform(String(n.name))
	var arm := v.part("ArmR")
	if arm:
		arm.transform = v.rest_transform("ArmR")
