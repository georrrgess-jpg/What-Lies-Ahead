extends RefCounted
## Teacup Twister "ride reset": the gun rolls over and the carousel spins
## out, flinging the remaining cups away one after another; hologram cups
## print into the empty seats and solidify with a flare. Then the flourish:
## the support hand leaves the foregrip, flicks the carousel round like a
## teacup ride, it whirls two turns and clicks to a stop as the saucer
## spins and the cup rings with a ding.

const CUPS := 4
const CONFETTI := [Color(1.0, 0.42, 0.78), Color(0.35, 0.92, 1.0), Color(1.0, 0.86, 0.3), Color(1.0, 1.0, 1.0)]


func play(v: WeaponView, d: float) -> void:
	for part in ["Saucer", "Swirl"]:
		v.register_part(part)
	for i in CUPS:
		v.register_part("Cup%d" % i)
	var mag := v.data.magazine_size
	if v.player and v.player.weapons:
		mag = v.player.weapons.magazine()
	var spent := CUPS - clampi(mag, 0, CUPS)
	for k in CUPS:
		var cup := v.part("Cup%d" % k)
		if cup:
			cup.visible = (CUPS - k) % CUPS >= spent
	# Roll over to show the carousel, then back for the flick.
	v.track("Root", d, [[0.1, Vector3(0.0, 0.02, 0.0), Vector3(8, 4, -14)], [0.58, Vector3(0.0, 0.02, 0.0), Vector3(8, 4, -14)],
		[0.66, Vector3(0.0, 0.01, 0.0), Vector3(2, 0, -6)], [0.9, Vector3(0.0, 0.0, 0.0), Vector3(-3, 0, 4)], [0.97, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.08, 0.16, d, 1.0, 0.2)
	# The carousel spins out (turning the cups to the open side) and they fly off.
	v.track("Drum", d, ReloadKeys.spin(0.12, 0.34, Vector3.BACK, -360.0, Vector3.ZERO, Vector3.ZERO, -0.6), Tween.TRANS_LINEAR)
	for k in CUPS:
		var t := 0.16 + 0.04 * k
		var out := Vector3(cos(TAU * k / CUPS + PI / 4), sin(TAU * k / CUPS + PI / 4), 0.0)
		v.track("Cup%d" % k, d, [[t, Vector3.ZERO, Vector3.ZERO], [t + 0.12, out * 0.16 + Vector3(-0.08, 0.06, -0.1), Vector3(120, 0, 200), 0.7]],
			Tween.TRANS_QUAD, Tween.EASE_IN)
		v.hide_part(t + 0.12, d, "Cup%d" % k)
		v.at(t, d, func(): Sfx.play(&"reload_clunk", -12.0, 1.5 + 0.08 * k))
	v.burst(0.2, d, "EjectPoint", "sparks")
	# The support hand drops off the foregrip while the cups print in.
	v.track("ArmL", d, [[0.07, Vector3(0, -0.07, 0), Vector3(0, 0, -14)], [0.14, Vector3(-0.03, -0.11, 0.06), Vector3(0, 0, 8)],
		[0.58, Vector3(-0.04, -0.12, 0.08), Vector3(0, 0, 10)], [0.65, Vector3(-0.21, -0.04, 0.17), Vector3(0, 8, 0)],
		[0.7, Vector3(-0.2, 0.05, 0.17), Vector3(0, 8, -6)], [0.78, Vector3(-0.06, -0.09, 0.1), Vector3(0, 0, 4)],
		[0.84, Vector3(0, -0.07, 0), Vector3(0, 0, -14)], [0.92, Vector3.ZERO, Vector3.ZERO]])
	v.holo_build("CellHolo", 0.36, 0.56, d)
	v.at(0.58, d, _cups_in.bind(v))
	v.solidify("CellHolo", "Cell", 0.58, d)
	v.at(0.58, d, func(): Sfx.play(&"reload_clunk", -4.0, 1.1); var p := v.owner as Player; if p: p.add_shake(0.05))
	# The flick: two turns, slowing to a click; the saucer whirls with it.
	v.track("Drum", d, ReloadKeys.spin(0.69, 0.92, Vector3.BACK, 720.0, Vector3.ZERO, Vector3.ZERO, 1.0), Tween.TRANS_LINEAR)
	v.track("Saucer", d, ReloadKeys.spin(0.69, 0.95, Vector3.BACK, -1080.0, Vector3.ZERO, Vector3.ZERO, 1.0), Tween.TRANS_LINEAR)
	v.track("Swirl", d, ReloadKeys.spin(0.7, 0.98, Vector3.RIGHT, 1080.0, Vector3.ZERO, Vector3.ZERO, 1.0), Tween.TRANS_LINEAR)
	v.at(0.92, d, _ding.bind(v))
	v.glow_ramp(0.92, 0.95, d, 0.6, 3.0)
	v.glow_ramp(0.95, 1.0, d, 3.0, 1.0)


func _cups_in(v: WeaponView) -> void:
	for k in CUPS:
		var cup := v.part("Cup%d" % k)
		if cup:
			cup.visible = true
			cup.transform = v.rest_transform("Cup%d" % k)


func _ding(v: WeaponView) -> void:
	var muzzle := v.model.find_child("VentPoint", true, false) as Node3D if v.model else null
	if muzzle:
		v.spark_burst(v.model.global_transform.affine_inverse() * muzzle.global_position, Vector3.UP, CONFETTI, 16, 1.2, 0.45, 0.012)
