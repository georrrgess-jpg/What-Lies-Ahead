class_name CoveCutlassLungeBehaviour
extends FrostSkiRushBehaviour
## Deckhand (Skull Harbor): the Ski Racer's telegraphed straight-line rush cut
## short into a cutlass lunge. It crouches with the blade drawn back (the
## Tuck clip, a steel scrape, the threat ring), locks its line and lunges a
## few metres along it, then stumbles out of it. Stepping sideways out of the
## line is the dodge. Sparks fly off the blade instead of snow.


## Sparks struck off the cutlass.
func _spray(z: Zombie, strength: float) -> void:
	if randf() < 0.4 * strength:
		var at := z.global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.6, 1.2), randf_range(-0.3, 0.3)) + _dir * 0.6
		Fx.impact(z.get_parent(), at, Vector3.UP + _dir * 0.5, Color(1.0, 0.9, 0.55))
