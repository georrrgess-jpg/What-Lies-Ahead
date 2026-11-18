extends RefCounted
## Coin-Op viewmodel motion (WeaponData.view_script): the brass tokens in
## the coin tube on the left flank are the magazine (one per two rounds,
## Token0 at the front goes first); when one leaves, the rest advance with a
## little ease, and every shot clicks the coin mech star wheel round a notch
## and throws a glint of brass from the chute. While the machine tilts
## (CoinOpMode.tilt) the red TILT lamp blinks faster and faster, the wheel
## whirs on and the cabinet rattles in the hands. The three CREDIT lamps show the kills banked toward the next
## Free Play token; a payout flashes them, kicks the coin-return flap open
## and spits brass out of the cup while the new tokens drop into the tube.
## The reload (coin_op_reload.gd) slaps the coin return and feeds a roll.

const TOKENS := 15
const CREDITS := 3
## Model-space step between tokens (Blender TOKEN_PITCH along +Y = -Z here).
const PITCH := 0.0118
## Seconds the stack takes to advance one token.
const ADVANCE_TIME := 0.08
## Degrees per notch of the star wheel, how long it takes, and its tilt whir.
const WHEEL_STEP := 45.0
const WHEEL_TIME := 0.06
const WHEEL_WHIR := 900.0
## Payout: the flap's swing (degrees), the lamp flash and the new tokens' drop.
const FLAP_DEG := 70.0
const FLAP_TIME := 0.35
const FLASH_TIME := 0.6
const DROP := 0.03
## Tilt rattle of the whole cabinet at full tilt: roll (degrees), lift (model units), rate (rad/s).
const RATTLE_ROLL := 0.9
const RATTLE_LIFT := 0.0015
const RATTLE_RATE := 52.0
const BRASS := [Color(1.0, 0.79, 0.24), Color(1.0, 0.93, 0.62), Color(0.85, 0.54, 0.11)]
const PAYOUT_SPARKS := [Color(1.0, 0.79, 0.24), Color(1.0, 0.93, 0.62), Color(1.0, 0.35, 0.82)]

var _tokens: Array[Node3D] = []
var _credits: Array[Node3D] = []
var _wheel: Node3D
var _tilt_glow: Node3D
var _flap: Node3D
var _muzzle: Node3D
var _shown := TOKENS
var _advance := 1.0
var _drop := 1.0
var _drop_from := TOKENS
var _since_shot := 10.0
var _wheel_from := 0.0
var _wheel_to := 0.0
var _whir := 0.0
var _blink := 0.0
var _since_payout := 10.0
var _shots := 0
var _clock := 0.0
var _rattling := false


func setup(v: WeaponView) -> void:
	for p in ["Wheel", "TiltGlow", "ReturnButton", "ReturnFlap", "FeedHolo"]:
		v.register_part(p)
	for i in TOKENS:
		v.register_part("Token%d" % i)
		_tokens.append(v.part("Token%d" % i))
	for i in CREDITS:
		v.register_part("Credit%d" % i)
		_credits.append(v.part("Credit%d" % i))
	_wheel = v.part("Wheel")
	_tilt_glow = v.part("TiltGlow")
	_flap = v.part("ReturnFlap")
	_muzzle = v.model.find_child("Muzzle", true, false) as Node3D
	var feed := v.part("FeedHolo")
	if feed:
		feed.visible = false
	_shown = _token_count(v)


func fired(v: WeaponView) -> void:
	_since_shot = 0.0
	_shots += 1
	_wheel_from = _wheel_to
	_wheel_to = fmod(_wheel_to + WHEEL_STEP, 360.0)
	if _muzzle and _shots % 2 == 0:
		var at := v.model.global_transform.affine_inverse() * _muzzle.global_position
		v.spark_burst(at, Vector3(0, 0.25, -1), BRASS, 2, 0.9, 0.12, 0.005)


func update(v: WeaponView, delta: float) -> void:
	_since_shot += delta
	_since_payout += delta
	var mode := _mode(v)
	if v.is_reloading():
		_wheel_from = 0.0
		_wheel_to = 0.0
		_whir = 0.0
		_shown = TOKENS
		_advance = 1.0
		_drop = 1.0
		_show_tilt(false)
		_rattling = false
		return
	_pose_tokens(v, delta)
	_rattle(v, mode, delta)
	_pose_wheel(v, mode, delta)
	_pose_tilt(mode, delta)
	_pose_credits(mode)
	_pose_flap(v)


func event(v: WeaponView, name: StringName) -> void:
	if name != CoinOpMode.PAYOUT_EVENT:
		return
	_since_payout = 0.0
	var cup := v.model.find_child("VentPoint", true, false) as Node3D if v.model else null
	if cup:
		var at := v.model.global_transform.affine_inverse() * cup.global_position
		v.spark_burst(at, Vector3(-0.3, 1.0, -0.5), PAYOUT_SPARKS, 9, 0.9, 0.35, 0.007)
	var slot := v.model.find_child("EjectPoint", true, false) as Node3D if v.model else null
	if slot:
		var at2 := v.model.global_transform.affine_inverse() * slot.global_position
		v.spark_burst(at2, Vector3(0, 1, 0), BRASS, 5, 0.5, 0.25, 0.006)
	var p := v.owner as Player
	if p:
		p.add_shake(0.04)


## The stack: a spent token leaves the front and the rest ease forward; new
## ones (a payout) drop in at the back.
func _pose_tokens(v: WeaponView, delta: float) -> void:
	var count := _token_count(v)
	if count < _shown:
		_advance = 0.0
	elif count > _shown:
		_drop_from = _shown
		_drop = 0.0
	_shown = count
	_advance = minf(1.0, _advance + delta / ADVANCE_TIME)
	_drop = minf(1.0, _drop + delta / 0.18)
	var back := PITCH * (1.0 - _ease_out(_advance))
	var drop_k := 1.0 - _ease_out(_drop)
	for i in _tokens.size():
		var t := _tokens[i]
		if t == null:
			continue
		t.visible = i < count
		if not t.visible:
			continue
		var rest := v.rest_transform("Token%d" % i)
		var off := Vector3(0.0, 0.0, back)
		if i >= _drop_from:
			off.y += DROP * drop_k
		t.transform = Transform3D(rest.basis, rest.origin + off)


## A notch per shot with a little overshoot, plus a whir while tilted.
func _pose_wheel(v: WeaponView, mode: CoinOpMode, delta: float) -> void:
	if _wheel == null:
		return
	var tilt := mode.tilt if mode else 0.0
	_whir = fmod(_whir + WHEEL_WHIR * tilt * delta, 360.0)
	var t := clampf(_since_shot / WHEEL_TIME, 0.0, 1.0)
	var k := 1.0 - pow(1.0 - t, 3.0) + sin(t * PI) * 0.15
	var goal := _wheel_to
	if _wheel_to < _wheel_from:
		goal += 360.0
	var angle := lerpf(_wheel_from, goal, k) + _whir
	_wheel.transform = v.rest_transform("Wheel") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-angle)), Vector3.ZERO)


## The TILT lamp blinks from slow to frantic as the machine tilts.
func _pose_tilt(mode: CoinOpMode, delta: float) -> void:
	var tilt := mode.tilt if mode else 0.0
	if tilt <= 0.0:
		_blink = 0.0
		_show_tilt(false)
		return
	_blink += delta * lerpf(4.0, 12.0, tilt)
	var duty := 0.75 if tilt >= 1.0 else 0.5
	_show_tilt(fmod(_blink, 1.0) < duty)


func _show_tilt(on: bool) -> void:
	if _tilt_glow:
		_tilt_glow.visible = on


## A tilted machine rattles in the hands (the root of the model).
func _rattle(v: WeaponView, mode: CoinOpMode, delta: float) -> void:
	var tilt := mode.tilt if mode else 0.0
	if tilt <= 0.0:
		if _rattling:
			v.model.transform = v.rest_transform("Root")
			_rattling = false
		return
	_rattling = true
	_clock += delta
	var roll := sin(_clock * RATTLE_RATE) * RATTLE_ROLL * tilt
	var lift := sin(_clock * RATTLE_RATE * 1.37) * RATTLE_LIFT * tilt
	v.model.transform = v.rest_transform("Root") * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(roll)), Vector3(0.0, lift, 0.0))


## Lamps for the banked credits; a payout flashes all three.
func _pose_credits(mode: CoinOpMode) -> void:
	var lit := mode.credits if mode else 0
	var on := true
	if _since_payout < FLASH_TIME:
		lit = CREDITS
		on = fmod(_since_payout * 10.0, 1.0) < 0.55
	for i in _credits.size():
		if _credits[i]:
			_credits[i].visible = i < lit and on


## The coin-return flap kicks open on a payout and swings shut.
func _pose_flap(v: WeaponView) -> void:
	if _flap == null:
		return
	var k := 0.0
	if _since_payout < FLAP_TIME:
		var t := _since_payout / FLAP_TIME
		k = sin(minf(1.0, t * 4.0) * PI * 0.5) * (1.0 - smoothstep(0.35, 1.0, t))
	_flap.transform = v.rest_transform("ReturnFlap") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(FLAP_DEG * k)), Vector3.ZERO)


## Tokens in the tube for the magazine (full on a stand or a menu).
func _token_count(v: WeaponView) -> int:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return TOKENS
	return clampi(ceili(float(p.weapons.magazine()) / maxf(1.0, v.data.magazine_size) * TOKENS), 0, TOKENS)


func _mode(v: WeaponView) -> CoinOpMode:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return null
	return p.weapons.mode as CoinOpMode


static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)
