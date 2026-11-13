extends RefCounted
## Arc Coil "coil swap": the vents flip and hiss, the spent Tesla capsule
## pops up out of its copper cradle and tumbles away, a hologram capsule
## lowers in and solidifies, then the claws twist open and snap shut with
## arcs jumping between their tips as the coil re-energises.

const ARC_COLOR := Color(0.75, 1.0, 0.3)


func play(v: WeaponView, d: float) -> void:
	v.register_part("Prongs")
	v.track("Root", d, [[0.12, Vector3(0.02, 0.03, 0.0), Vector3(-6, -10, -22)], [0.82, Vector3(0.02, 0.03, 0.0), Vector3(-6, -10, -22)],
		[1.0, Vector3.ZERO, Vector3.ZERO]])
	v.track("Vents", d, [[0.1, Vector3.ZERO, Vector3(-75, 0, 0)], [0.86, Vector3.ZERO, Vector3(-75, 0, 0)], [0.93, Vector3.ZERO, Vector3.ZERO]],
		Tween.TRANS_BACK, Tween.EASE_OUT)
	v.burst(0.13, d, "VentPoint", "steam")
	v.burst(0.3, d, "VentPoint", "steam")
	v.glow_ramp(0.1, 0.24, d, 1.0, 0.1)
	# The spent capsule pops out of the cradle and tumbles off to the left.
	v.track("Cell", d, [[0.2, Vector3.ZERO, Vector3.ZERO], [0.3, Vector3(0, 0.07, 0), Vector3(0, 200, 0)],
		[0.48, Vector3(-0.26, 0.1, 0.06), Vector3(70, 560, 30), 0.7]], Tween.TRANS_QUAD, Tween.EASE_OUT)
	v.at(0.21, d, func(): Sfx.play(&"reload_vent", -6.0, 1.4))
	v.burst(0.3, d, "EjectPoint", "sparks")
	v.hide_part(0.48, d, "Cell")
	# The free hand drops away to fetch a capsule and comes back to the grip.
	# (Straight down off the handguard first, so the fingers clear it.)
	v.track("ArmL", d, [[0.1, Vector3(0, -0.09, 0), Vector3.ZERO], [0.24, Vector3(-0.03, -0.24, 0.12), Vector3(25, 0, 0)],
		[0.72, Vector3(-0.03, -0.24, 0.12), Vector3(25, 0, 0)], [0.83, Vector3(0, -0.09, 0), Vector3.ZERO],
		[0.91, Vector3.ZERO, Vector3.ZERO]])
	# A hologram capsule lowers into the cradle.
	v.track("CellHolo", d, [[0.5, Vector3(0, 0.1, 0), Vector3.ZERO, 1.0, "hold"], [0.7, Vector3(0, 0.09, 0), Vector3(0, 90, 0)],
		[0.78, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_CUBIC, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.5, 0.72, d)
	v.solidify("CellHolo", "Cell", 0.79, d)
	# Claws twist open and snap shut; arcs jump between their tips.
	v.track("Prongs", d, [[0.8, Vector3.ZERO, Vector3.ZERO, 1.0], [0.86, Vector3.ZERO, Vector3(0, 0, 50), 1.14],
		[0.94, Vector3.ZERO, Vector3.ZERO, 1.0]], Tween.TRANS_BACK, Tween.EASE_OUT)
	for t in [0.86, 0.9, 0.94]:
		v.at(t, d, _tip_arcs.bind(v))
	v.at(0.86, d, func(): Sfx.play(&"weap_arc_chain", -4.0, 1.2); var p := v.owner as Player; if p: p.add_shake(0.06))
	v.glow_ramp(0.86, 0.92, d, 0.5, 3.2)
	v.glow_ramp(0.92, 1.0, d, 3.2, 1.0)


## Small arcs from the electrode to the three claw tips (viewmodel scale).
func _tip_arcs(v: WeaponView) -> void:
	if v.model == null:
		return
	var xf := v.model.global_transform
	var centre := xf * Vector3(0, 0.045, -0.452)
	for a in [90.0, 210.0, 330.0]:
		var r := deg_to_rad(a)
		var tip := xf * Vector3(cos(r) * 0.048, 0.045 + sin(r) * 0.048, -0.462)
		LightningBolt.spawn(v, centre, tip, ARC_COLOR, 0.0035, 0.09, 0.004)
