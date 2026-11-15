extends RefCounted
## Dunk Tank "refill": the gun rolls over, the empty tank drops off its yoke
## with a slosh and the support hand swats it away; a hologram tank prints in
## below, is shoved home and solidifies, and the water rises in it. Then the
## flourish: the pump racks twice, the needle swings to full, the gun bucks
## up with a test squirt arcing out of the spout, and the bullseye flips
## right over as if the squirt had dunked someone.

const DROPS := [Color(0.55, 0.88, 1.0), Color(0.9, 0.98, 1.0), Color(0.3, 0.62, 1.0)]
const FILL_TIME := 0.32


func play(v: WeaponView, d: float) -> void:
	for part in ["Water", "Pump", "Needle", "Target"]:
		v.register_part(part)
	v.track("Root", d, [[0.1, Vector3(-0.01, 0.03, 0.0), Vector3(6, 6, 24)], [0.62, Vector3(-0.01, 0.03, 0.0), Vector3(6, 6, 24)],
		[0.7, Vector3.ZERO, Vector3(-2, 0, 2)], [0.86, Vector3(0.0, 0.03, 0.0), Vector3(-14, 0, -4)], [0.96, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.06, 0.16, d, 1.0, 0.2)
	# The empty tank drops off its yoke and is swatted away to the left.
	v.track("Cell", d, [[0.14, Vector3.ZERO, Vector3.ZERO], [0.24, Vector3(0, -0.1, 0), Vector3.ZERO],
		[0.36, Vector3(-0.26, -0.2, 0.04), Vector3(40, 0, 220), 0.8]], Tween.TRANS_QUAD, Tween.EASE_IN)
	v.at(0.15, d, func(): Sfx.play(&"reload_clunk", -6.0, 1.3))
	v.at(0.16, d, _slosh.bind(v, "EjectPoint", 8))
	v.hide_part(0.36, d, "Cell")
	v.track("ArmL", d, [[0.1, Vector3(-0.03, -0.012, -0.085), Vector3.ZERO], [0.24, Vector3(-0.17, -0.05, -0.02), Vector3(0, 0, -14)],
		[0.3, Vector3(-0.19, -0.07, -0.05), Vector3(0, 0, -30)], [0.36, Vector3(-0.17, -0.05, -0.02), Vector3(0, 0, -14)],
		[0.58, Vector3(-0.17, -0.05, -0.02), Vector3(0, 0, -14)], [0.68, Vector3(-0.03, -0.012, -0.085), Vector3.ZERO],
		[0.76, Vector3.ZERO, Vector3.ZERO]])
	# A hologram tank prints in below the yoke and is shoved home.
	v.track("CellHolo", d, [[0.38, Vector3(0, -0.13, 0), Vector3(0, 90, 0), 1.0, "hold"], [0.54, Vector3(0, -0.1, 0), Vector3.ZERO],
		[0.6, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.38, 0.56, d)
	v.solidify("CellHolo", "Cell", 0.6, d)
	v.at(0.6, d, _fill.bind(v))
	v.at(0.6, d, func(): Sfx.play(&"reload_clunk", -3.0); var p := v.owner as Player; if p: p.add_shake(0.05))
	# The flourish: two pumps, the needle to full, a test squirt, the bullseye flips.
	v.track("Pump", d, [[0.66, Vector3.ZERO, Vector3.ZERO], [0.7, Vector3(0, 0, 0.03), Vector3.ZERO], [0.74, Vector3.ZERO, Vector3.ZERO],
		[0.78, Vector3(0, 0, 0.03), Vector3.ZERO], [0.82, Vector3.ZERO, Vector3.ZERO]])
	v.track("Needle", d, [[0.66, Vector3.ZERO, Vector3(110, 0, 0)], [0.74, Vector3.ZERO, Vector3(40, 0, 0)],
		[0.83, Vector3.ZERO, Vector3(-40, 0, 0)], [0.9, Vector3.ZERO, Vector3(-24, 0, 0)], [0.96, Vector3.ZERO, Vector3(-30, 0, 0)]])
	v.at(0.86, d, _slosh.bind(v, "Muzzle", 14))
	v.track("Target", d, ReloadKeys.spin(0.87, 1.0, Vector3.RIGHT, 360.0, Vector3.ZERO, Vector3.ZERO, 1.0), Tween.TRANS_LINEAR)
	v.glow_ramp(0.86, 0.9, d, 0.6, 2.6)
	v.glow_ramp(0.9, 1.0, d, 2.6, 1.0)


## The new tank fills up from the bottom.
func _fill(v: WeaponView) -> void:
	var water := v.part("Water")
	if water == null:
		return
	var rest := v.rest_transform("Water")
	water.transform = Transform3D(rest.basis.scaled_local(Vector3(1.0, 0.03, 1.0)), rest.origin)
	var tw := water.create_tween()
	tw.tween_property(water, "transform", rest, FILL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Droplets from `anchor` (an empty in the model): the tank's slosh, the test squirt.
func _slosh(v: WeaponView, anchor: String, amount: int) -> void:
	var point := v.model.find_child(anchor, true, false) as Node3D if v.model else null
	if point:
		var up := Vector3(0, 1.0, -0.6) if anchor == "Muzzle" else Vector3(0, -1, 0)
		v.spark_burst(v.model.global_transform.affine_inverse() * point.global_position, up, DROPS, amount, 1.3, 0.45, 0.008)
