extends MeleeMode
## Swirl Smasher (swirl_smasher): a charged smash cracks the candy and sprays
## sugar shards round the first zombie it lands on: every zombie within
## SHARD_RADIUS is slowed (StatusEffects' shock slow, mass-scaled) for a time
## that grows with the charge, and the others take a little shard damage.

const TRAIT := "Sugar shards"
const SHARD_RADIUS := 3.2
const SLOW_TIME := 2.6
const SHARD_DAMAGE := 18.0
const CANDY := [Color(1.0, 0.23, 0.42), Color(1.0, 0.6, 0.18), Color(1.0, 0.88, 0.29), Color(0.45, 0.88, 0.29),
		Color(0.23, 0.55, 1.0), Color(0.64, 0.36, 1.0), Color(1, 1, 1)]

var _shattered := false


func swing_input(fire: bool, aim: bool, ready: bool, delta: float) -> bool:
	var was := phase
	var used := super.swing_input(fire, aim, ready, delta)
	if phase == Phase.HEAVY and was != Phase.HEAVY:
		_shattered = false
	elif phase == Phase.WINDUP and was == Phase.IDLE:
		Sfx.play(&"swirl_windup", -4.0, randf_range(0.97, 1.03))
	return used


func struck_zombie(z: Zombie, point: Vector3, heavy: bool) -> void:
	if not heavy or _shattered:
		return
	_shattered = true
	var level := _level()
	Sfx.play_at(&"swirl_crack", point, -2.0, randf_range(0.95, 1.05))
	Sfx.play_at(&"swirl_shatter", point, -4.0, randf_range(0.95, 1.05))
	WeaponFx.burst(level, point, Vector3.UP, CANDY, 26, 5.5, 0.9, 0.05, 80.0)
	WeaponFx.shockwave(level, point, Color(1.0, 0.6, 0.85), SHARD_RADIUS, 0.8)
	var slow := SLOW_TIME * lerpf(0.6, 1.0, charge)
	for node in z.get_tree().get_nodes_in_group("zombies"):
		var other := node as Zombie
		if other == null or other.is_dead() or other.global_position.distance_to(point) > SHARD_RADIUS:
			continue
		var status := StatusEffects.of(other)
		status.shock_left = maxf(status.shock_left, slow)
		if other != z:
			var dir := (other.global_position - point).normalized()
			controller.melee_hit(data, other, other.global_position + Vector3.UP, dir, SHARD_DAMAGE, 1.5)
