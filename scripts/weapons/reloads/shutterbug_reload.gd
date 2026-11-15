extends RefCounted
## Shutterbug "new flash wheel": the camera rolls over to show its left flank,
## the spent wheel of bulbs pops off its axle in a puff of smoke and the
## support hand flicks it away; a fresh wheel prints in as a hologram and is
## pressed onto the axle. Then the flourish: the hand spins the wheel like a
## prize wheel, the thumb cranks the film lever twice, the bulbs blink alight
## one by one and the camera snaps up for a test flash.

const BULBS := 8
const POP := [Color(1.0, 1.0, 1.0), Color(0.75, 0.95, 1.0), Color(1.0, 0.95, 0.7)]


func play(v: WeaponView, d: float) -> void:
	for part in ["Winder", "Iris", "Focus"]:
		v.register_part(part)
	for i in BULBS:
		v.register_part("Bulb%d" % i)
	# Starting a reload resets every part: the old wheel keeps its spent bulbs dark.
	var spent := 0
	if v.player and v.player.weapons:
		spent = clampi(v.data.magazine_size - v.player.weapons.magazine(), 0, BULBS)
	for i in spent:
		_show(v, "Bulb%d" % i, false)
	v.track("Root", d, [[0.12, Vector3(-0.01, 0.03, 0.0), Vector3(8, 10, 26)], [0.8, Vector3(-0.01, 0.03, 0.0), Vector3(8, 10, 26)],
		[0.88, Vector3(0.0, 0.02, 0.0), Vector3(-6, 0, 0)], [0.92, Vector3(0.0, 0.035, 0.0), Vector3(-14, 0, -3)], [1.0, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.06, 0.16, d, 1.0, 0.2)
	# The spent wheel pops off the axle, smoking, and is flicked away.
	v.track("Cell", d, [[0.14, Vector3.ZERO, Vector3.ZERO], [0.2, Vector3(-0.04, 0.015, 0.0), Vector3(-30, 0, 0)],
		[0.36, Vector3(-0.28, -0.16, 0.06), Vector3(-280, 40, 120), 0.8]], Tween.TRANS_QUAD, Tween.EASE_OUT)
	v.at(0.15, d, func(): Sfx.play(&"reload_clunk", -7.0, 1.3))
	v.burst(0.16, d, "EjectPoint", "steam")
	v.hide_part(0.36, d, "Cell")
	# The support hand lets go, flicks the old wheel away and comes back up beside the axle.
	v.track("ArmL", d, [[0.1, Vector3(-0.03, -0.012, -0.085), Vector3.ZERO], [0.22, Vector3(-0.15, -0.05, -0.03), Vector3(0, 0, -14)],
		[0.28, Vector3(-0.17, -0.07, -0.06), Vector3(0, 0, -30)], [0.36, Vector3(-0.15, -0.05, -0.03), Vector3(0, 0, -14)],
		[0.6, Vector3(-0.1, -0.03, -0.05), Vector3(0, 0, 20)], [0.68, Vector3(-0.09, -0.01, -0.06), Vector3(16, 0, 34)],
		[0.72, Vector3(-0.1, -0.03, -0.05), Vector3(0, 0, 20)], [0.84, Vector3(-0.03, -0.012, -0.085), Vector3.ZERO],
		[0.9, Vector3.ZERO, Vector3.ZERO]])
	# A fresh wheel prints in out to the left and is pressed onto the axle.
	v.track("CellHolo", d, [[0.38, Vector3(-0.07, 0.0, 0.0), Vector3(90, 0, 0), 1.0, "hold"], [0.54, Vector3(-0.025, 0.0, 0.0), Vector3.ZERO],
		[0.6, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.38, 0.56, d)
	v.at(0.6, d, _bulbs_dark.bind(v))
	v.solidify("CellHolo", "Cell", 0.6, d)
	v.glow_ramp(0.61, 0.66, d, 3.0, 0.2)
	v.at(0.6, d, func(): Sfx.play(&"reload_clunk", -3.0, 1.1); var p := v.owner as Player; if p: p.add_shake(0.05))
	# Flourish: a spin of the wheel...
	v.track("Cell", d, ReloadKeys.spin(0.66, 0.84, Vector3.RIGHT, -405.0, Vector3.ZERO, Vector3.ZERO, 1.0), Tween.TRANS_LINEAR)
	v.at(0.66, d, func(): Sfx.play(&"gn8b_shutter_spin", -4.0))
	# ...the film lever cranked twice...
	v.track("Winder", d, [[0.68, Vector3.ZERO, Vector3(0, -80, 0)], [0.73, Vector3.ZERO, Vector3.ZERO], [0.78, Vector3.ZERO, Vector3(0, -80, 0)],
		[0.83, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_QUAD, Tween.EASE_OUT)
	v.at(0.68, d, func(): Sfx.play(&"gn8b_shutter_wind", -4.0))
	v.at(0.78, d, func(): Sfx.play(&"gn8b_shutter_wind", -4.0, 1.08))
	# ...the bulbs blink alight one by one, and a test flash.
	for i in BULBS:
		v.at(0.7 + i * 0.018, d, _show.bind(v, "Bulb%d" % i, true))
	v.glow_ramp(0.7, 0.86, d, 0.2, 1.0)
	v.track("Iris", d, [[0.9, Vector3.ZERO, Vector3(0, 0, 50)], [0.95, Vector3.ZERO, Vector3.ZERO]])
	v.at(0.9, d, _test_flash.bind(v))
	v.glow_ramp(0.9, 0.93, d, 1.0, 3.4)
	v.glow_ramp(0.93, 1.0, d, 3.4, 1.0)


func _show(v: WeaponView, part: String, on: bool) -> void:
	var p := v.part(part)
	if p:
		p.visible = on


func _bulbs_dark(v: WeaponView) -> void:
	for i in BULBS:
		_show(v, "Bulb%d" % i, false)


func _test_flash(v: WeaponView) -> void:
	Sfx.play(&"gn8b_shutter_ready", -3.0)
	var at := v.model.find_child("FlashPoint", true, false) as Node3D if v.model else null
	if at:
		v.spark_burst(v.model.global_transform.affine_inverse() * at.global_position, Vector3(0, 0.4, -1), POP, 14, 1.2, 0.25, 0.01)
