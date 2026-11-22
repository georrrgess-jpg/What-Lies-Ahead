extends RefCounted
## Claw Grabber "insert token": the gun turns to show its left flank and the
## off hand lets go of the grip, comes up with a gold token between finger and
## thumb and drops it into the lit coin slot (a clink as it rattles down).
## The machine wakes: the marquee bulbs race round the header and flash (the
## view, ClawGrabberView, runs them off the reload's progress), the CREDIT
## display flares, the claw is reeled up into its chute with the spool
## whirring, then lowered out again on a servo whirr, its prongs flexing open
## and snapping shut to arm; the joystick is given a flick and the gun turns
## back and settles. The clink, the bulbs' chime and the servos are in the
## reload sound (clw_reload), timed for WeaponData.reload_time.

## Where the token starts in the hand and lines up outside the slot (model space, from its rest in the slot).
const TOKEN_HAND := Vector3(-0.07, -0.06, 0.03)
const TOKEN_LINE := Vector3(-0.016, 0.0, 0.0)
## How far the claw is reeled up into the chute (model +Z is toward the player).
const CLAW_UP := Vector3(0.0, 0.0, 0.026)
const PRONG_OPEN := -26.0
const SPARKS := [Color(0.22, 0.94, 1.0), Color(1.0, 0.31, 0.64), Color(1.0, 0.96, 0.88)]
const GOLD := [Color(1.0, 0.82, 0.25), Color(1.0, 0.96, 0.88)]


func play(v: WeaponView, d: float) -> void:
	for p in ["Claw", "Token", "ArmL", "Joystick", "Prong0", "Prong1", "Prong2"]:
		v.register_part(p)
	_show(v, "Token", false)
	_gun(v, d)
	_hand(v, d)
	_token(v, d)
	_claw(v, d)
	v.track("Joystick", d, [[0.8, Vector3.ZERO, Vector3.ZERO], [0.84, Vector3.ZERO, Vector3(-14, 0, 18)],
		[0.9, Vector3.ZERO, Vector3(6, 0, -8)], [0.96, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_CUBIC, Tween.EASE_OUT)
	v.glow_ramp(0.02, 0.14, d, 1.0, 0.25)
	v.glow_ramp(0.44, 0.5, d, 0.25, 3.0)
	v.glow_ramp(0.5, 0.7, d, 3.0, 1.0)


## Turned to show the left flank and the coin slot, tipped up a little; back
## with a settle once the claw is armed.
func _gun(v: WeaponView, d: float) -> void:
	v.track("Root", d, [[0.12, Vector3(-0.02, 0.04, 0.01), Vector3(4, -30, -16)], [0.3, Vector3(-0.024, 0.044, 0.01), Vector3(6, -34, -18)],
		[0.42, Vector3(-0.022, 0.04, 0.01), Vector3(5, -33, -17)], [0.45, Vector3(-0.022, 0.034, 0.012), Vector3(2, -32, -16)],
		[0.54, Vector3(-0.012, 0.03, 0.005), Vector3(6, -14, -8)], [0.72, Vector3(-0.006, 0.026, 0.0), Vector3(10, -6, -2)],
		[0.84, Vector3(0.0, -0.004, 0.0), Vector3(-4, 2, 2)], [0.93, Vector3(0.0, 0.003, 0.0), Vector3(2, 0, 0)],
		[1.0, Vector3.ZERO, Vector3.ZERO]])


## The off hand lets go, comes up beside the coin door with the token, pushes
## it in, and takes the grip again.
func _hand(v: WeaponView, d: float) -> void:
	v.track("ArmL", d, [[0.06, Vector3.ZERO, Vector3.ZERO], [0.18, Vector3(-0.1, -0.03, 0.06), Vector3(0, 0, -12)],
		[0.28, Vector3(-0.09, 0.04, 0.04), Vector3(-10, 0, -20)], [0.38, Vector3(-0.06, 0.07, 0.03), Vector3(-14, -6, -24)],
		[0.44, Vector3(-0.05, 0.072, 0.03), Vector3(-14, -6, -24)], [0.52, Vector3(-0.09, 0.02, 0.05), Vector3(-6, 0, -12)],
		[0.66, Vector3(-0.02, -0.01, 0.01), Vector3(0, 0, -4)], [0.74, Vector3.ZERO, Vector3.ZERO]])


## The token: shown in the hand, lined up edge on with the slot, pushed in, gone.
func _token(v: WeaponView, d: float) -> void:
	v.at(0.24, d, _show.bind(v, "Token", true))
	v.track("Token", d, [[0.0, TOKEN_HAND, Vector3(0, 0, 30), 1.0, "hold"], [0.24, TOKEN_HAND, Vector3(0, 0, 30)],
		[0.36, TOKEN_LINE, Vector3.ZERO], [0.42, TOKEN_LINE, Vector3.ZERO], [0.45, Vector3(0.012, 0.0, 0.0), Vector3.ZERO]],
		Tween.TRANS_CUBIC, Tween.EASE_OUT)
	v.at(0.45, d, _clink.bind(v))
	v.hide_part(0.46, d, "Token")


func _clink(v: WeaponView) -> void:
	var tok := v.part("Token")
	if tok:
		var at := v.model.global_transform.affine_inverse() * tok.global_position
		v.spark_burst(at, Vector3(-1, 0.4, 0), GOLD, 6, 0.4, 0.25, 0.004)
	var p := v.owner as Player
	if p:
		p.add_shake(0.02)


## The claw is reeled up into the chute, then lowered back out, its prongs
## flexing open and snapping shut to arm.
func _claw(v: WeaponView, d: float) -> void:
	v.track("Claw", d, [[0.5, Vector3.ZERO, Vector3.ZERO], [0.6, CLAW_UP, Vector3(0, 0, 0)], [0.66, CLAW_UP, Vector3(0, 0, 60)],
		[0.76, Vector3(0, 0, -0.006), Vector3(0, 0, 120)], [0.8, Vector3.ZERO, Vector3(0, 0, 120)], [0.86, Vector3.ZERO, Vector3(0, 0, 120)]],
		Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	for i in 3:
		var rest := v.rest_transform("Prong%d" % i)
		var radial := Vector3(rest.origin.x, rest.origin.y, 0.0)
		if radial.length() < 0.0001:
			continue
		var axis := radial.normalized().cross(Vector3.FORWARD).normalized()
		# Track rotations are Euler degrees in the part's own frame: open about the knuckle's axis.
		var open := Basis(axis, deg_to_rad(PRONG_OPEN)) * rest.basis
		var open_deg := (rest.basis.inverse() * open).get_euler() * (180.0 / PI)
		v.track("Prong%d" % i, d, [[0.74, Vector3.ZERO, Vector3.ZERO], [0.79, Vector3.ZERO, open_deg], [0.82, Vector3.ZERO, open_deg],
			[0.85, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_OUT)
	v.at(0.85, d, _armed.bind(v))


func _armed(v: WeaponView) -> void:
	var claw := v.part("Claw")
	if claw:
		var at := v.model.global_transform.affine_inverse() * claw.global_position
		v.spark_burst(at, Vector3(0, 0.6, -0.4), SPARKS, 8, 0.6, 0.3, 0.005)


func _show(v: WeaponView, part: String, on: bool) -> void:
	var p := v.part(part)
	if p:
		p.visible = on
