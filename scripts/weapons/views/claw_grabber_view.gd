extends RefCounted
## Claw Grabber viewmodel motion (WeaponData.view_script).
##
## The big claw (Claw, prongs Prong0..2) hangs out of the cable chute; on a
## shot it leaves the gun (hidden while ClawGrabberShot flies) and the cable
## spool (Spool) spins out under its window; home again, it snaps into the
## chute with its prongs clacking open and shut. The marquee bulbs (Lit0..13,
## seven a side) chase round the header slowly at rest, race while the claw
## is out and all flash on a grab. The joystick (Joystick) jerks with every
## shot and wanders a little at rest; the GRAB button (Button) presses in on
## a shot; the little crane in the prize case (MiniClaw) roams its gantry,
## dipping now and then; the CREDIT display (Cell) glows by the credits left.
## Inspect: the gun turns to show its left flank, the thumb works the joystick
## (the mini crane follows it), dips the crane on a prize and the lights win a
## round; one time in RARE_CHANCE the mini crane actually lifts a prize, the
## bulbs go wild and a jackpot jingle plays.

const BULBS := 14
## Chase speed (bulbs a second) at rest, while the claw is out, in a win.
const CHASE_IDLE := 5.0
const CHASE_OUT := 22.0
## Seconds all bulbs flash after a grab.
const GRAB_FLASH := 0.6
## The claw's catch: how long its prongs clack, how far it kicks back in (model space).
const CATCH_TIME := 0.22
const CATCH_KICK := Vector3(0.0, 0.0, 0.018)
## Prong swing (degrees about the knuckle): shut at rest, open on the catch.
const PRONG_OPEN := -26.0
const SPOOL_TURN := 40.0
## Joystick: degrees it jerks on a shot and wanders at rest.
const JOY_SHOT := 16.0
const JOY_IDLE := 4.0
const BUTTON_PRESS := 0.0025
## The mini crane's gantry: how far it roams along the case (m, model space) and its dip.
const MINI_TRAVEL := 0.045
const MINI_DIP := 0.012
## Inspect.
const INSPECT_LENGTH := 3.6
const RARE_CHANCE := 1.0 / 15.0
const INSPECT_POSES := [
	[0.0, Vector3(0.14, -0.14, -0.62), Vector3(2.0, 14.0, -4.0)],
	[0.12, Vector3(0.05, -0.1, -0.5), Vector3(10.0, 42.0, 18.0)],
	[0.5, Vector3(0.05, -0.1, -0.5), Vector3(12.0, 46.0, 20.0)],
	[0.6, Vector3(0.08, -0.12, -0.52), Vector3(-6.0, -18.0, -10.0)],
	[0.84, Vector3(0.08, -0.12, -0.52), Vector3(-4.0, -20.0, -8.0)],
	[1.0, Vector3(0.14, -0.15, -0.62), Vector3(4.0, 6.0, 0.0)],
]
const SPARKS := [Color(0.22, 0.94, 1.0), Color(1.0, 0.31, 0.64), Color(1.0, 0.96, 0.88)]
const CONFETTI := [Color(1.0, 0.82, 0.25), Color(1.0, 0.31, 0.64), Color(0.22, 0.94, 1.0), Color(0.44, 0.94, 0.75)]

var _claw: Node3D
var _prongs: Array[Node3D] = []
var _lit: Array[Node3D] = []
var _spool: Node3D
var _joy: Node3D
var _button: Node3D
var _mini: Node3D
var _token: Node3D
var _cell: Node3D
var _muzzle: Node3D
var _clock := 0.0
var _chase := 0.0
var _flash := 0.0
var _since_shot := 10.0
var _since_catch := 10.0
var _spool_angle := 0.0
var _spool_speed := 0.0
var _joy_kick := Vector2.ZERO
var _was_out := false
## Inspect state.
var _inspecting := false
var _rare := false
var _won := false


func setup(v: WeaponView) -> void:
	for p in ["Claw", "Spool", "Joystick", "Button", "MiniClaw", "Token", "Cell", "ArmL", "ArmR"]:
		v.register_part(p)
	for i in 3:
		v.register_part("Prong%d" % i)
		_prongs.append(v.part("Prong%d" % i))
	for k in BULBS:
		v.register_part("Lit%d" % k)
		_lit.append(v.part("Lit%d" % k))
	_claw = v.part("Claw")
	_spool = v.part("Spool")
	_joy = v.part("Joystick")
	_button = v.part("Button")
	_mini = v.part("MiniClaw")
	_token = v.part("Token")
	_cell = v.part("Cell")
	_muzzle = v.model.find_child("Muzzle", true, false) as Node3D
	if _token:
		_token.visible = false


func fired(v: WeaponView) -> void:
	_since_shot = 0.0
	_joy_kick = Vector2(randf_range(-1.0, 1.0), 1.0)
	_spool_speed = SPOOL_TURN
	if _muzzle:
		var at := v.model.global_transform.affine_inverse() * _muzzle.global_position
		v.spark_burst(at, Vector3(0, 0.2, -1), SPARKS, 4, 0.8, 0.2, 0.005)


func event(v: WeaponView, event_name: StringName) -> void:
	match event_name:
		ClawGrabberMode.GRAB_EVENT, ClawGrabberMode.REEL_EVENT:
			_flash = GRAB_FLASH
		&"catch", &"catch_hit":
			_since_catch = 0.0
			_spool_speed = -SPOOL_TURN * 1.5
			if _muzzle:
				var at := v.model.global_transform.affine_inverse() * _muzzle.global_position
				v.spark_burst(at, Vector3(0, 0.4, 0.3), SPARKS, 5, 0.6, 0.2, 0.004)


func update(v: WeaponView, delta: float) -> void:
	_clock += delta
	_since_shot += delta
	_since_catch += delta
	_flash = maxf(0.0, _flash - delta)
	var mode := _mode(v)
	var out := mode != null and mode.is_out()
	if _token and not v.is_reloading():
		_token.visible = false
	if not v.is_reloading() and not _inspecting:
		_pose_claw(v, out)
		_pose_mini(v, delta)
	var woken := _woken(v)
	_pose_lights(out or woken, delta)
	_pose_spool(v, out or woken, delta)
	_pose_controls(v, delta)
	_was_out = out


## Hidden while it flies; home, it kicks back into the chute with a clack of its prongs.
func _pose_claw(v: WeaponView, out: bool) -> void:
	if _claw == null:
		return
	_claw.visible = not out
	var u := clampf(_since_catch / CATCH_TIME, 0.0, 1.0)
	var kick := sin(u * PI) * (1.0 - u)
	_claw.transform = v.rest_transform("Claw").translated_local(CATCH_KICK * kick)
	var open := sin(u * PI * 2.0) * (1.0 - u) if u < 1.0 else 0.0
	_pose_prongs(v, maxf(0.0, open))


## 0 shut, 1 fully open.
func _pose_prongs(v: WeaponView, open: float) -> void:
	for i in _prongs.size():
		var p := _prongs[i]
		if p == null:
			continue
		var rest := v.rest_transform("Prong%d" % i)
		# The knuckle's radial direction about the claw's axis (-Z).
		var radial := Vector3(rest.origin.x, rest.origin.y, 0.0)
		if radial.length() < 0.0001:
			continue
		var axis := radial.normalized().cross(Vector3.FORWARD).normalized()
		p.transform = Transform3D(Basis(axis, deg_to_rad(PRONG_OPEN * open)) * rest.basis, rest.origin)


## The bulbs chase round the header (down the left side, back up the right).
func _pose_lights(out: bool, delta: float) -> void:
	var speed := CHASE_OUT if out or _inspecting and _won else CHASE_IDLE
	_chase = fmod(_chase + speed * delta, float(BULBS))
	var flash_on := _flash > 0.0 and int(_flash * 16.0) % 2 == 0 and not Settings.reduce_motion()
	for k in BULBS:
		var b := _lit[k]
		if b == null:
			continue
		# Ring order: left side front to back, right side back to front.
		var ring := k if k < BULBS / 2 else BULBS - 1 - (k - BULBS / 2)
		var d := fmod(_chase - ring + BULBS, float(BULBS))
		b.visible = flash_on or d < 2.2 or (Settings.reduce_motion() and k % 2 == 0)


func _pose_spool(v: WeaponView, out: bool, delta: float) -> void:
	if _spool == null:
		return
	var want := SPOOL_TURN if out else 0.0
	_spool_speed = lerpf(_spool_speed, want, 1.0 - exp(-6.0 * delta))
	_spool_angle = fmod(_spool_angle + _spool_speed * delta, TAU)
	_spool.transform = v.rest_transform("Spool") * Transform3D(Basis(Vector3.RIGHT, _spool_angle), Vector3.ZERO)


func _pose_controls(v: WeaponView, delta: float) -> void:
	_joy_kick = _joy_kick.lerp(Vector2.ZERO, 1.0 - exp(-10.0 * delta))
	if _joy and not _inspecting and not v.is_reloading():
		var idle := Vector2(sin(_clock * 0.9), sin(_clock * 1.3 + 1.0)) * JOY_IDLE
		var tilt := idle + _joy_kick * JOY_SHOT
		_joy.transform = v.rest_transform("Joystick") * Transform3D(Basis.from_euler(Vector3(deg_to_rad(-tilt.y), 0.0, deg_to_rad(tilt.x))), Vector3.ZERO)
	if _button:
		var press := 1.0 - clampf(_since_shot / 0.12, 0.0, 1.0)
		_button.transform = v.rest_transform("Button").translated(Vector3(BUTTON_PRESS * press, -BUTTON_PRESS * press, 0.0))


## The little crane roams its gantry and dips for a prize now and then.
func _pose_mini(v: WeaponView, _delta: float) -> void:
	if _mini == null:
		return
	var roam := sin(_clock * 0.55) * 0.6 + sin(_clock * 1.3) * 0.4
	var dip := maxf(0.0, sin(_clock * 0.8)) ** 6
	if Settings.reduce_motion():
		roam = 0.0
		dip = 0.0
	_mini.transform = v.rest_transform("MiniClaw").translated(Vector3(0.0, -dip * MINI_DIP, -roam * MINI_TRAVEL * 0.5))


## True through the part of a reload where the token has dropped and the
## machine wakes (the lights race, the spool reels the claw up and down).
func _woken(v: WeaponView) -> bool:
	if not v.is_reloading() or v.player == null or v.player.weapons == null:
		return false
	var k := v.player.weapons.reload_progress()
	if k > 0.45 and k < 0.47 and _flash <= 0.0:
		_flash = GRAB_FLASH
	return k > 0.45 and k < 0.86


func _mode(v: WeaponView) -> ClawGrabberMode:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return null
	return p.weapons.mode as ClawGrabberMode


# --- inspect -------------------------------------------------------------------

func inspect_length() -> float:
	return INSPECT_LENGTH


func inspect_poses() -> Array:
	return INSPECT_POSES


func inspect_start(v: WeaponView) -> void:
	_rare = v.inspect_rare(RARE_CHANCE)
	_won = false
	_inspecting = true


## The thumb works the joystick (the crane follows), the crane drops on a
## prize, closes, rises: the prize slips (or, rarely, comes up with it and
## the lights win), and the gun turns to look down the claw, its prongs
## flexing open and shut.
func inspect(v: WeaponView, t: float) -> void:
	var steer := 0.0
	if t > 0.5 and t < 1.6:
		steer = sin((t - 0.5) / 1.1 * TAU * 1.5)
	if _joy:
		_joy.transform = v.rest_transform("Joystick") * Transform3D(Basis.from_euler(Vector3(deg_to_rad(-6.0 * steer), 0.0, deg_to_rad(14.0 * steer))), Vector3.ZERO)
	if _mini:
		var along := -steer * MINI_TRAVEL * 0.5
		var dip := WeaponInspect.hump(t, 1.65, 2.2) * MINI_DIP * 1.6
		_mini.transform = v.rest_transform("MiniClaw").translated(Vector3(0.0, -dip, along))
	if t > 1.95 and not _won:
		_won = true
		Sfx.play(&"clw_servo", -10.0, 1.6)
		if _rare:
			Sfx.play(&"clw_jackpot", -6.0)
			_flash = 1.2
			var at := v.model.global_transform.affine_inverse() * _mini.global_position if _mini else Vector3.ZERO
			v.spark_burst(at, Vector3(0, 1, 0), CONFETTI, 14, 0.8, 0.6, 0.005)
	# Looking down the claw: its prongs flex open and shut twice.
	if t > 2.2 and t < 3.2:
		var u := (t - 2.2) / 1.0
		_pose_prongs(v, absf(sin(u * TAU)))
		if int(u * 4.0) != int((u - 0.02) * 4.0):
			Sfx.play(&"clw_clank", -16.0, 1.3)


func inspect_end(v: WeaponView) -> void:
	_inspecting = false
	if _joy:
		_joy.transform = v.rest_transform("Joystick")
	if _mini:
		_mini.transform = v.rest_transform("MiniClaw")
	_pose_prongs(v, 0.0)
