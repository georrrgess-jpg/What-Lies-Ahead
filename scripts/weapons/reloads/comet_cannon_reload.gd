extends RefCounted
## Comet Hand Cannon "speedloader": the cylinder swings out on its crane, the
## six spent comet cores shoot out the back in a shower of sparks, a hologram
## speedloader prints in behind the cylinder and pushes home, then a wrist
## flick snaps the crane shut with the cylinder spinning.


func play(v: WeaponView, d: float) -> void:
	v.register_part("Crane")
	v.register_part("Cylinder")
	v.track("Root", d, [[0.12, Vector3(-0.02, 0.03, 0.0), Vector3(6, 4, 24)], [0.74, Vector3(-0.02, 0.035, 0.0), Vector3(8, 4, 26)],
		[0.84, Vector3(0.01, 0.02, 0.0), Vector3(2, -4, -10)], [1.0, Vector3.ZERO, Vector3.ZERO]])
	v.track("Hammer", d, [[0.08, Vector3.ZERO, Vector3(-35, 0, 0)], [0.84, Vector3.ZERO, Vector3(-35, 0, 0)], [0.9, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.06, 0.18, d, 1.0, 0.2)
	v.track("Crane", d, [[0.1, Vector3.ZERO, Vector3.ZERO], [0.22, Vector3.ZERO, Vector3(0, 0, 105)], [0.78, Vector3.ZERO, Vector3(0, 0, 105)],
		[0.85, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_OUT)
	v.at(0.2, d, func(): Sfx.play(&"reload_clunk", -6.0, 1.3))
	# The spent cores fly out the back of the cylinder.
	v.track("Cell", d, [[0.26, Vector3.ZERO, Vector3.ZERO], [0.33, Vector3(0, 0, 0.115), Vector3.ZERO],
		[0.42, Vector3(-0.01, 0.06, 0.3), Vector3(0, 0, 160), 0.75]], Tween.TRANS_QUAD, Tween.EASE_IN)
	v.burst(0.28, d, "EjectPoint", "sparks")
	v.hide_part(0.42, d, "Cell")
	# The support hand slides forward off the firing hand and waits below the cylinder.
	v.track("ArmL", d, [[0.1, Vector3(-0.03, -0.012, -0.085), Vector3.ZERO], [0.24, Vector3(-0.17, -0.05, -0.02), Vector3(0, 0, -14)],
		[0.72, Vector3(-0.16, -0.04, -0.02), Vector3(0, 0, -10)], [0.84, Vector3(-0.03, -0.012, -0.085), Vector3.ZERO],
		[0.94, Vector3.ZERO, Vector3.ZERO]])
	# Hologram speedloader behind the cylinder, then pushed home.
	v.track("CellHolo", d, [[0.44, Vector3(0, 0, 0.12), Vector3.ZERO, 1.0, "hold"], [0.66, Vector3(0, 0, 0.12), Vector3.ZERO],
		[0.72, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_CUBIC, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.44, 0.66, d)
	v.solidify("CellHolo", "Cell", 0.73, d)
	# Snap shut with the cylinder spinning.
	v.track("Cylinder", d, [[0.78, Vector3.ZERO, Vector3.ZERO], [0.95, Vector3.ZERO, Vector3(0, 0, -420)]], Tween.TRANS_CUBIC, Tween.EASE_OUT)
	v.at(0.79, d, func(): Sfx.play(&"reload_spin", -5.0, 1.25))
	v.at(0.85, d, func(): Sfx.play(&"reload_clunk", -2.0); var p := v.owner as Player; if p: p.add_shake(0.1))
	v.burst(0.88, d, "VentPoint", "steam")
	v.glow_ramp(0.86, 0.93, d, 0.6, 3.0)
	v.glow_ramp(0.93, 1.0, d, 3.0, 1.0)
