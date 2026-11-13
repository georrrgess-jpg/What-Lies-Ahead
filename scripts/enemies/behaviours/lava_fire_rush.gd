class_name LavaFireRushBehaviour
extends FrostSkiRushBehaviour
## Fire Dancer: the Ski Racer's telegraphed straight-line rush (crouch and spin
## up the poi, lock the line, dash, skid) with its own sounds, and a trail of
## embers instead of snow spray. Stepping out of the locked line is the dodge.


## Embers shaken off the burning poi.
func _spray(z: Zombie, strength: float) -> void:
	if randf() < 0.45 * strength:
		var at := z.global_position + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 1.0), randf_range(-0.4, 0.4))
		Fx.impact(z.get_parent(), at, Vector3.UP - _dir * 0.4, Color(1.0, 0.55 + randf() * 0.3, 0.15))
