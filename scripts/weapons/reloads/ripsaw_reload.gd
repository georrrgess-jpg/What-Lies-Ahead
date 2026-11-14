extends RefCounted
## Toxic Ripsaw "rack swap": the weapon rolls its slime rack toward you, the
## support hand lets go of the pump, the spent rack pops off the flank with a
## wet glug and tumbles away, a full one prints in as a hologram beside the
## receiver, slides home and fills (slime splashes from the seam), the hand
## returns and racks the pump back and forth. A full rack also refuels the
## saw (RipsawMode.reloaded).


func play(v: WeaponView, d: float) -> void:
	# Rolled and lifted so the rack faces the camera.
	v.track("Root", d, [[0.12, Vector3(-0.03, 0.07, 0.02), Vector3(4, 24, -22)], [0.8, Vector3(-0.03, 0.07, 0.02), Vector3(4, 24, -22)],
		[0.86, Vector3(-0.01, 0.03, 0.0), Vector3(-6, 10, -8)], [1.0, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.1, 0.2, d, 1.0, 0.25)
	# The support hand drops off the pump while the rack is swapped.
	v.track("ArmL", d, [[0.1, Vector3(0, -0.04, 0.0), Vector3.ZERO], [0.22, Vector3(-0.12, -0.11, 0.02), Vector3(0, 0, -14)],
		[0.66, Vector3(-0.12, -0.11, 0.02), Vector3(0, 0, -14)], [0.76, Vector3(0, -0.04, 0.0), Vector3.ZERO], [0.8, Vector3.ZERO, Vector3.ZERO]])
	# The spent rack pops off the flank and tumbles away.
	v.at(0.2, d, func(): Sfx.play(&"weap_ripsaw_glug", -4.0, 0.9))
	v.track("Cell", d, [[0.2, Vector3.ZERO, Vector3.ZERO, 1.0, "hold"], [0.27, Vector3(-0.035, 0.008, 0.0), Vector3(0, 0, 8)],
		[0.42, Vector3(-0.1, -0.24, 0.03), Vector3(-30, 25, 70), 0.9]], Tween.TRANS_QUAD, Tween.EASE_IN)
	v.burst(0.22, d, "EjectPoint", "steam")
	v.hide_part(0.42, d, "Cell")
	v.track("Cell", d, [[0.44, Vector3.ZERO, Vector3.ZERO, 1.0, "hold"]])
	# A full rack prints in beside the receiver and slides home.
	v.track("CellHolo", d, [[0.44, Vector3(-0.07, 0.0, 0.0), Vector3(0, 0, -6), 1.0, "hold"], [0.56, Vector3(-0.05, 0.0, 0.0), Vector3(0, 0, -3)],
		[0.62, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.44, 0.58, d)
	v.solidify("CellHolo", "Cell", 0.62, d)
	v.at(0.63, d, func(): Sfx.play(&"weap_ripsaw_glug", -3.0, 1.15); var p := v.owner as Player; if p: p.add_shake(0.08))
	v.at(0.64, d, func(): v.spark_burst(_eject(v), Vector3(-1, 0.6, 0), [Color(0.75, 1.0, 0.2), Color(0.95, 1.0, 0.6), Color(0.45, 0.9, 0.15)],
		12, 0.6, 0.4, 0.012))
	# The pump racks it home: back, then forward.
	v.track("Pump", d, [[0.82, Vector3.ZERO, Vector3.ZERO, 1.0, "hold"], [0.87, Vector3(0, 0, 0.04), Vector3.ZERO], [0.93, Vector3.ZERO, Vector3.ZERO]],
		Tween.TRANS_QUAD, Tween.EASE_OUT)
	v.at(0.85, d, func(): Sfx.play(&"weap_ripsaw_pump", -3.0, 1.0))
	v.glow_ramp(0.88, 0.94, d, 0.8, 2.6)
	v.glow_ramp(0.94, 1.0, d, 2.6, 1.0)


func _eject(v: WeaponView) -> Vector3:
	var e := v.model.find_child("EjectPoint", true, false) as Node3D if v.model else null
	return e.position if e else Vector3.ZERO
