extends RefCounted
## Bumper Lobber "gumball refill": the hopper lid flips open, the spent
## gumball shells pop out like popcorn, a fresh batch rains in as holograms
## and solidifies, the side crank turns twice to feed the drum, and the free
## hand slaps the lid shut.


func play(v: WeaponView, d: float) -> void:
	v.register_part("Lid")
	v.register_part("Crank")
	v.track("Root", d, [[0.12, Vector3(0.0, 0.03, 0.0), Vector3(12, 6, 20)], [0.84, Vector3(0.0, 0.03, 0.0), Vector3(12, 6, 20)],
		[1.0, Vector3.ZERO, Vector3.ZERO]])
	v.track("Lid", d, [[0.1, Vector3.ZERO, Vector3(115, 0, 0)], [0.83, Vector3.ZERO, Vector3(115, 0, 0)], [0.88, Vector3.ZERO, Vector3.ZERO]],
		Tween.TRANS_BACK, Tween.EASE_OUT)
	v.at(0.1, d, func(): Sfx.play(&"reload_clunk", -6.0, 1.5))
	v.glow_ramp(0.08, 0.2, d, 1.0, 0.25)
	# Spent shells pop up out of the hopper.
	v.track("Cell", d, [[0.18, Vector3.ZERO, Vector3.ZERO], [0.32, Vector3(-0.03, 0.14, 0.05), Vector3(140, 0, 60), 0.8]],
		Tween.TRANS_QUAD, Tween.EASE_OUT)
	v.at(0.19, d, func(): Sfx.play(&"weap_lobber_bounce", -6.0, 1.3))
	v.burst(0.22, d, "EjectPoint", "sparks")
	v.hide_part(0.32, d, "Cell")
	# A fresh batch rains in.
	v.track("CellHolo", d, [[0.36, Vector3(0, 0.09, 0), Vector3(0, 0, 0), 1.0, "hold"], [0.6, Vector3(0, 0.03, 0), Vector3(0, 90, 0)],
		[0.66, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.36, 0.62, d)
	v.solidify("CellHolo", "Cell", 0.67, d)
	# Two turns of the crank feed the drum.
	v.track("Crank", d, [[0.64, Vector3.ZERO, Vector3.ZERO], [0.82, Vector3.ZERO, Vector3(-720, 0, 0)]], Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	v.at(0.66, d, func(): Sfx.play(&"reload_spin", -5.0, 0.9))
	v.at(0.74, d, func(): Sfx.play(&"reload_spin", -6.0, 1.05))
	# The free hand slaps the lid shut.
	# It drops off the foregrip, comes up beside the hopper, pats it and goes back.
	v.track("ArmL", d, [[0.14, Vector3(0, -0.09, 0.02), Vector3.ZERO], [0.34, Vector3(-0.17, -0.04, 0.16), Vector3(0, 0, -10)],
		[0.78, Vector3(-0.21, 0.19, 0.27), Vector3(-10, 0, -20)], [0.84, Vector3(-0.19, 0.17, 0.27), Vector3(-6, 0, -20)],
		[0.9, Vector3(-0.17, -0.04, 0.16), Vector3(0, 0, -10)], [0.96, Vector3(0, -0.09, 0.02), Vector3.ZERO],
		[1.0, Vector3.ZERO, Vector3.ZERO]])
	v.at(0.88, d, func(): Sfx.play(&"reload_clunk", -2.0, 1.1); var p := v.owner as Player; if p: p.add_shake(0.1))
	v.burst(0.89, d, "VentPoint", "steam")
	v.glow_ramp(0.88, 0.94, d, 0.8, 2.8)
	v.glow_ramp(0.94, 1.0, d, 2.8, 1.0)
