extends RefCounted
## Ring Toss "ring toss": the gun rolls over, the empty spine drops out of the
## bottom of the magazine cage and the support hand swats it away; a hologram
## stack of hoops prints in below the cage and the palm shoves it home. Then
## the flourish: the top hoop pops up into the cradle, the gun tosses it into
## the air, it spins flat like a carnival hoop and drops back over the peg
## with a ding while the catch hooks clamp it.

const STACK := 4
const PINK := [Color(1.0, 0.45, 0.85), Color(1.0, 1.0, 1.0), Color(1.0, 0.85, 0.35)]


func play(v: WeaponView, d: float) -> void:
	for part in ["Ring", "Flipper", "Hooks"]:
		v.register_part(part)
	for i in STACK:
		v.register_part("Stack%d" % i)
	v.track("Root", d, [[0.12, Vector3(-0.01, 0.03, 0.0), Vector3(6, 6, 22)], [0.66, Vector3(-0.01, 0.03, 0.0), Vector3(6, 6, 22)],
		[0.74, Vector3(0.0, 0.0, 0.0), Vector3(-4, 0, 0)], [0.8, Vector3(0.0, 0.035, 0.0), Vector3(-12, 0, -4)],
		[0.9, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.06, 0.16, d, 1.0, 0.2)
	v.hide_part(0.0, d, "Ring")
	# The empty spine drops out of the cage and is swatted away to the left.
	v.track("Cell", d, [[0.14, Vector3.ZERO, Vector3.ZERO], [0.24, Vector3(0, -0.12, 0), Vector3.ZERO],
		[0.36, Vector3(-0.26, -0.2, 0.04), Vector3(40, 0, 220), 0.8]], Tween.TRANS_QUAD, Tween.EASE_IN)
	v.at(0.15, d, func(): Sfx.play(&"reload_clunk", -6.0, 1.25))
	v.burst(0.16, d, "EjectPoint", "sparks")
	v.hide_part(0.36, d, "Cell")
	# The support hand slides off the grip and out to the left, then back.
	v.track("ArmL", d, [[0.1, Vector3(-0.03, -0.012, -0.085), Vector3.ZERO], [0.24, Vector3(-0.17, -0.05, -0.02), Vector3(0, 0, -14)],
		[0.3, Vector3(-0.19, -0.07, -0.05), Vector3(0, 0, -30)], [0.36, Vector3(-0.17, -0.05, -0.02), Vector3(0, 0, -14)],
		[0.62, Vector3(-0.17, -0.05, -0.02), Vector3(0, 0, -14)], [0.72, Vector3(-0.03, -0.012, -0.085), Vector3.ZERO],
		[0.8, Vector3.ZERO, Vector3.ZERO]])
	# A hologram stack prints in below the cage and is shoved home.
	v.track("CellHolo", d, [[0.38, Vector3(0, -0.13, 0), Vector3(0, 90, 0), 1.0, "hold"], [0.54, Vector3(0, -0.11, 0), Vector3.ZERO],
		[0.6, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.38, 0.56, d)
	v.at(0.6, d, _stack_full.bind(v))
	v.solidify("CellHolo", "Cell", 0.6, d)
	v.at(0.6, d, func(): Sfx.play(&"reload_clunk", -3.0); var p := v.owner as Player; if p: p.add_shake(0.06))
	# The flourish: up into the cradle, tossed, spinning flat, and back over the peg.
	v.track("Ring", d, [[0.66, Vector3(0, -0.036, 0), Vector3.ZERO, 1.0, "hold"], [0.72, Vector3.ZERO, Vector3.ZERO],
		[0.8, Vector3(0, 0.12, 0.01), Vector3(14, 360, 0)], [0.9, Vector3.ZERO, Vector3(0, 720, 0)]], Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	v.at(0.66, d, func(): var r := v.part("Ring"); if r: r.visible = true)
	v.track("Flipper", d, [[0.7, Vector3.ZERO, Vector3(-40, 0, 0)], [0.76, Vector3.ZERO, Vector3(-60, 0, 0)], [0.84, Vector3.ZERO, Vector3.ZERO]],
		Tween.TRANS_BACK, Tween.EASE_OUT)
	v.at(0.73, d, func(): Sfx.play(&"gn2_ring_toss", -5.0, 1.15))
	v.track("Hooks", d, [[0.86, Vector3.ZERO, Vector3.ZERO], [0.9, Vector3.ZERO, Vector3(35, 0, 0)], [0.98, Vector3.ZERO, Vector3.ZERO]])
	v.at(0.9, d, _landed.bind(v))
	v.glow_ramp(0.9, 0.95, d, 0.6, 3.0)
	v.glow_ramp(0.95, 1.0, d, 3.0, 1.0)


func _stack_full(v: WeaponView) -> void:
	for i in STACK:
		var s := v.part("Stack%d" % i)
		if s:
			s.visible = true


func _landed(v: WeaponView) -> void:
	Sfx.play(&"gn2_ring_catch", -3.0)
	var muzzle := v.model.find_child("VentPoint", true, false) as Node3D if v.model else null
	if muzzle:
		v.spark_burst(v.model.global_transform.affine_inverse() * muzzle.global_position, Vector3.UP, PINK, 12, 0.9, 0.3, 0.009)
