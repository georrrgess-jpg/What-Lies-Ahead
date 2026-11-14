extends RefCounted
## Gumball Drum Popper "drum swap": the thumb pops the release and the drum
## whirls its last gumballs round, drops out and tumbles away, a new drum
## prints in as a hologram and rolls up into place, winds one turn on a
## ratchet and the fore-pump racks it home (the support hand rides the pump).


func play(v: WeaponView, d: float) -> void:
	v.track("Root", d, [[0.12, Vector3(0.0, 0.03, 0.0), Vector3(10, -8, 24)], [0.86, Vector3(0.0, 0.03, 0.0), Vector3(10, -8, 24)],
		[1.0, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.06, 0.18, d, 1.0, 0.2)
	# The release: two quick turns, then the drum drops away.
	v.track("Drum", d, ReloadKeys.spin(0.1, 0.3, Vector3.RIGHT, -720.0, Vector3.ZERO, Vector3.ZERO, -0.6), Tween.TRANS_LINEAR)
	v.track("Drum", d, [[0.31, Vector3.ZERO, Vector3.ZERO, 1.0, "hold"], [0.34, Vector3(0, -0.015, 0), Vector3.ZERO],
		[0.48, Vector3(0.05, -0.3, 0.02), Vector3(-60, 0, -40), 0.8]], Tween.TRANS_QUAD, Tween.EASE_IN)
	v.burst(0.32, d, "EjectPoint", "sparks")
	v.hide_part(0.48, d, "Drum")
	v.track("Drum", d, [[0.5, Vector3.ZERO, Vector3.ZERO, 1.0, "hold"]])
	# The support hand drops off the pump while the drum is swapped.
	v.track("ArmL", d, [[0.12, Vector3(0, -0.05, 0.0), Vector3.ZERO], [0.26, Vector3(-0.1, -0.14, 0.06), Vector3(0, 0, -15)],
		[0.62, Vector3(-0.1, -0.14, 0.06), Vector3(0, 0, -15)], [0.76, Vector3(0, -0.05, 0.0), Vector3.ZERO], [0.82, Vector3.ZERO, Vector3.ZERO]])
	# A new drum prints in below the slot and rolls up into it.
	v.track("CellHolo", d, [[0.5, Vector3(0, -0.16, 0.0), Vector3(90, 0, 0), 1.0, "hold"], [0.6, Vector3(0, -0.06, 0), Vector3(30, 0, 0)],
		[0.68, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.5, 0.68, d)
	v.at(0.7, d, func(): var drum := v.model.find_child("Drum", true, false) as Node3D; if drum: drum.visible = true)
	v.solidify("CellHolo", "Cell", 0.7, d)
	# One wound turn on the ratchet, then the pump racks it home.
	v.track("Drum", d, ReloadKeys.spin(0.72, 0.84, Vector3.RIGHT, -360.0), Tween.TRANS_LINEAR)
	v.at(0.72, d, func(): Sfx.play(&"reload_spin", -6.0, 1.15))
	v.track("Pump", d, [[0.86, Vector3.ZERO, Vector3.ZERO, 1.0, "hold"], [0.9, Vector3(0, 0, 0.035), Vector3.ZERO], [0.95, Vector3.ZERO, Vector3.ZERO]],
		Tween.TRANS_QUAD, Tween.EASE_OUT)
	v.at(0.88, d, func(): Sfx.play(&"reload_clunk", -3.0, 1.2); var p := v.owner as Player; if p: p.add_shake(0.1))
	v.at(0.94, d, func(): Sfx.play(&"reload_clunk", -4.0, 1.45))
	v.burst(0.9, d, "VentPoint", "steam")
	v.glow_ramp(0.88, 0.94, d, 0.8, 2.8)
	v.glow_ramp(0.94, 1.0, d, 2.8, 1.0)
