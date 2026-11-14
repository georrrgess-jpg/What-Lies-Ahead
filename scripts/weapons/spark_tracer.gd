class_name SparkTracer
extends RefCounted
## The "spark" tracer style (the Sparkler): a hot streak like a firework
## spark, with glitter that crackles off along its path and falls away. An
## equipped tracer cosmetic draws instead (Fx.tracer), as on every weapon.

const GLITTER := [Color(1.0, 0.92, 0.55), Color(1.0, 1.0, 1.0), Color(1.0, 0.5, 0.85)]


static func draw(parent: Node, from: Vector3, to: Vector3, w: WeaponData) -> void:
	if Cosmetics.equipped(&"tracer") != null:
		Fx.tracer(parent, from, to, w.tracer_color, w.tracer_width)
		return
	Fx.beam(parent, from, to, w.tracer_color, w.tracer_width)
	var length := from.distance_to(to)
	if length < 1.5:
		return
	# Two pinches of glitter somewhere along the streak, crackling outwards.
	for i in 2:
		var at := from.lerp(to, randf_range(0.25, 0.9))
		WeaponFx.burst(parent, at, Vector3.UP, GLITTER, 3, 2.2, 0.32, 0.028, 180.0, Vector3(0, -5.0, 0))
