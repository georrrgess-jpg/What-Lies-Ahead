extends RefCounted
## Frostbite Cryo Beam "canister vent": the frost fins spin down while the
## nozzle vents icy steam, the gauge needle drops, the tank clamps fly open,
## the spent cryo tank twists loose and falls away, a hologram tank slides
## in and freezes solid, the clamps lock and the needle swings back up.


func play(v: WeaponView, d: float) -> void:
	v.register_part("Fins")
	v.register_part("Needle")
	v.track("Root", d, [[0.12, Vector3(0.02, 0.03, 0.0), Vector3(6, -10, -30)], [0.84, Vector3(0.02, 0.03, 0.0), Vector3(6, -10, -30)],
		[1.0, Vector3.ZERO, Vector3.ZERO]])
	v.track("Fins", d, [[0.04, Vector3.ZERO, Vector3.ZERO], [0.4, Vector3.ZERO, Vector3(0, 0, 300)]], Tween.TRANS_QUAD, Tween.EASE_OUT)
	v.burst(0.08, d, "VentPoint", "steam")
	v.burst(0.2, d, "VentPoint", "steam")
	v.glow_ramp(0.06, 0.2, d, 1.0, 0.1)
	v.track("Needle", d, [[0.14, Vector3.ZERO, Vector3(0, 140, 0)], [0.86, Vector3.ZERO, Vector3(0, 140, 0)], [0.94, Vector3.ZERO, Vector3(0, -25, 0)],
		[1.0, Vector3.ZERO, Vector3.ZERO]])
	v.track("Panel", d, [[0.14, Vector3.ZERO, Vector3(0, 0, 80)], [0.76, Vector3.ZERO, Vector3(0, 0, 80)], [0.82, Vector3.ZERO, Vector3.ZERO]],
		Tween.TRANS_BACK, Tween.EASE_OUT)
	v.at(0.15, d, func(): Sfx.play(&"reload_clunk", -6.0, 1.35))
	# The spent tank twists loose and falls away to the left.
	v.track("Cell", d, [[0.28, Vector3.ZERO, Vector3.ZERO], [0.36, Vector3(-0.015, 0, 0), Vector3(0, 0, 90)],
		[0.52, Vector3(-0.2, -0.16, 0.02), Vector3(30, 0, 260), 0.8]], Tween.TRANS_QUAD, Tween.EASE_IN)
	v.burst(0.36, d, "EjectPoint", "steam")
	v.hide_part(0.52, d, "Cell")
	v.track("ArmL", d, [[0.24, Vector3(-0.08, 0.03, 0.08), Vector3(0, 0, -18)], [0.74, Vector3(-0.09, 0.02, 0.06), Vector3(0, 0, -18)],
		[0.92, Vector3.ZERO, Vector3.ZERO]])
	# A hologram tank slides in from the side and freezes solid.
	v.track("CellHolo", d, [[0.54, Vector3(-0.12, 0, 0), Vector3(0, 0, -90), 1.0, "hold"], [0.7, Vector3(-0.1, 0, 0), Vector3(0, 0, -40)],
		[0.76, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_CUBIC, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.54, 0.72, d)
	v.solidify("CellHolo", "Cell", 0.77, d)
	v.at(0.82, d, func(): Sfx.play(&"reload_clunk", -2.0, 0.95); var p := v.owner as Player; if p: p.add_shake(0.08))
	v.burst(0.83, d, "VentPoint", "steam")
	v.glow_ramp(0.84, 0.92, d, 0.5, 3.0)
	v.glow_ramp(0.92, 1.0, d, 3.0, 1.0)
