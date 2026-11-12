class_name EnemyBehaviour
extends Resource
## A behaviour component for an enemy type (listed in EnemyData.behaviours).
## Each zombie gets its own duplicate, so components may keep state.
## Override any of the hooks below. Useful Zombie API for behaviours:
##   z.target (Player), z.data (EnemyData), z.state (Zombie.State), z.speed,
##   z.health, z.global_position, z.distance_to_target(), z.has_line_of_sight(),
##   z.face_toward(dir, delta), z.play_animation(name), z.knockback(vec),
##   z.speed_multiplier (scales chase speed; reset to 1 each frame you don't set it),
##   EnemyProjectile.launch(...) for ranged attacks.


## Called once when the zombie enters the tree (after its model is built).
func on_ready(_z: Zombie) -> void:
	pass


## Called every physics frame before the default state machine. Return true
## to skip the default behaviour this frame (you then move the zombie yourself).
func on_physics(_z: Zombie, _delta: float) -> bool:
	return false


## Called when hit, before damage applies. Return the damage to actually take
## (e.g. 0 for a blocked shot, amount * 0.5 for armour).
func on_hit(_z: Zombie, amount: float, _hit_position: Vector3, _headshot: bool) -> float:
	return amount


## Called when the melee swipe resolves (hit or miss).
func on_attack(_z: Zombie, _hit_player: bool) -> void:
	pass


## Called once on death (before the death animation).
func on_death(_z: Zombie) -> void:
	pass
