extends RefCounted
## Rail Lancer "capacitor swap": the rails slide forward and vent three hot
## puffs, the drained capacitor unlatches from the side and drops away, a
## hologram capacitor is printed in the free hand's path and slotted home,
## the rails slam back and the charge rings light up front to back.


func play(v: WeaponView, d: float) -> void:
	v.register_part("Rails")
	v.track("Root", d, [[0.12, Vector3(0.02, 0.035, 0.02), Vector3(4, -12, -24)], [0.84, Vector3(0.02, 0.035, 0.02), Vector3(4, -12, -24)],
		[1.0, Vector3.ZERO, Vector3.ZERO]])
	v.track("Rails", d, [[0.08, Vector3(0, 0, -0.07), Vector3.ZERO], [0.84, Vector3(0, 0, -0.07), Vector3.ZERO], [0.89, Vector3.ZERO, Vector3.ZERO]],
		Tween.TRANS_BACK, Tween.EASE_OUT)
	v.at(0.08, d, func(): Sfx.play(&"reload_vent", -5.0, 0.8))
	for t in [0.12, 0.24, 0.36]:
		v.burst(t, d, "VentPoint", "steam")
	v.glow_ramp(0.08, 0.2, d, 1.0, 0.08)
	# The drained capacitor unlatches and drops away.
	v.track("Cell", d, [[0.28, Vector3.ZERO, Vector3.ZERO], [0.34, Vector3(-0.02, 0, 0), Vector3.ZERO],
		[0.5, Vector3(-0.17, -0.22, 0.05), Vector3(0, 0, 130), 0.75]], Tween.TRANS_QUAD, Tween.EASE_IN)
	v.at(0.3, d, func(): Sfx.play(&"reload_clunk", -6.0, 1.4))
	v.burst(0.34, d, "EjectPoint", "sparks")
	v.hide_part(0.5, d, "Cell")
	# The support hand drops away to fetch a capacitor and returns to the handguard.
	v.track("ArmL", d, [[0.26, Vector3(-0.03, -0.24, 0.14), Vector3(25, 0, 0)], [0.74, Vector3(-0.03, -0.24, 0.14), Vector3(25, 0, 0)],
		[0.92, Vector3.ZERO, Vector3.ZERO]])
	# A hologram capacitor prints in and slots home.
	v.track("CellHolo", d, [[0.52, Vector3(-0.1, -0.05, 0), Vector3(0, 0, 30), 1.0, "hold"], [0.7, Vector3(-0.08, -0.04, 0), Vector3(0, 0, 20)],
		[0.76, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_CUBIC, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.52, 0.72, d)
	v.solidify("CellHolo", "Cell", 0.77, d)
	v.at(0.89, d, func(): Sfx.play(&"reload_clunk", -1.0, 0.85); var p := v.owner as Player; if p: p.add_shake(0.14))
	v.at(0.9, d, func(): Sfx.play(&"weap_rail_ready", -6.0))
	# Charge rings light up.
	v.glow_ramp(0.89, 0.95, d, 0.3, 3.2)
	v.glow_ramp(0.95, 1.0, d, 3.2, 1.0)
