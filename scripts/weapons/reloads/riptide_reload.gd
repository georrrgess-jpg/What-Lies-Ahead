extends RefCounted
## Riptide Harpoon "tank and spear": the air tank unscrews with a hiss and
## drops away, a new one prints in and screws home, the support hand fetches
## a fresh spear and slides it into the muzzle, and the reel winds the line
## tight with a brass clink.


func play(v: WeaponView, d: float) -> void:
	v.track("Root", d, [[0.12, Vector3(0.0, 0.03, 0.0), Vector3(8, -12, -22)], [0.86, Vector3(0.0, 0.03, 0.0), Vector3(8, -12, -22)],
		[1.0, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.06, 0.2, d, 1.0, 0.15)
	# The tank unscrews (two turns backing out), then drops.
	v.track("Cell", d, ReloadKeys.spin(0.12, 0.3, Vector3.BACK, 720.0, Vector3.ZERO, Vector3(0, 0, 0.03)), Tween.TRANS_LINEAR)
	v.track("Cell", d, [[0.31, Vector3(0, 0, 0.03), Vector3.ZERO, 1.0, "hold"], [0.44, Vector3(0.02, -0.22, 0.06), Vector3(30, 0, 40), 0.8]],
		Tween.TRANS_QUAD, Tween.EASE_IN)
	v.burst(0.3, d, "VentPoint", "steam")
	v.hide_part(0.44, d, "Cell")
	# A new tank prints in and screws home.
	v.track("CellHolo", d, [[0.46, Vector3(0, -0.06, 0.03), Vector3.ZERO, 1.0, "hold"], [0.56, Vector3(0, 0, 0.03), Vector3.ZERO]],
		Tween.TRANS_CUBIC, Tween.EASE_OUT)
	v.track("CellHolo", d, ReloadKeys.spin(0.56, 0.66, Vector3.BACK, -360.0, Vector3(0, 0, 0.03), Vector3.ZERO), Tween.TRANS_LINEAR)
	v.holo_build("CellHolo", 0.46, 0.64, d)
	v.solidify("CellHolo", "Cell", 0.67, d)
	# The support hand fetches a spear and slides it into the muzzle.
	v.track("ArmL", d, [[0.1, Vector3(0, -0.07, 0), Vector3(0, 0, -14)], [0.24, Vector3(-0.07, -0.1, 0.05), Vector3(0, 0, -12)],
		[0.46, Vector3(-0.08, -0.04, -0.17), Vector3(0, 0, -12)], [0.62, Vector3(-0.08, -0.04, -0.17), Vector3(0, 0, -12)],
		[0.74, Vector3(-0.06, -0.09, -0.02), Vector3(0, 0, -6)], [0.8, Vector3(0, -0.08, 0), Vector3(0, 0, -14)], [0.86, Vector3.ZERO, Vector3.ZERO]])
	v.at(0.46, d, func(): var spear := v.model.find_child("Harpoon", true, false) as Node3D; if spear: spear.visible = true)
	v.track("Harpoon", d, [[0.46, Vector3(0, 0, -0.17), Vector3.ZERO, 1.0, "hold"], [0.62, Vector3(0, 0, -0.17), Vector3.ZERO],
		[0.78, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	v.at(0.78, d, func(): Sfx.play(&"reload_clunk", -4.0, 1.3))
	# The reel winds the line tight.
	v.track("Reel", d, ReloadKeys.spin(0.78, 0.92, Vector3.RIGHT, -720.0), Tween.TRANS_LINEAR)
	v.at(0.79, d, func(): Sfx.play(&"reload_spin", -6.0, 1.2))
	v.at(0.92, d, func(): Sfx.play(&"weap_rip_ready", -5.0); var p := v.owner as Player; if p: p.add_shake(0.08))
	v.glow_ramp(0.9, 0.95, d, 0.3, 3.0)
	v.glow_ramp(0.95, 1.0, d, 3.0, 1.0)
