extends MeleeMode
## High Striker (high_striker): the charged heavy slams the ground in front of
## the player whether or not it lands on a zombie. The slam rings the bell
## (the view sends the puck up the scale on `slams`) and its shock stuns every
## zombie within SLAM_RADIUS: the rank and file are knocked out of what they
## were doing and all are slowed for a moment (heavies and alphas less,
## through StatusEffects' mass scaling), and they take a share of the slam's
## damage that falls off to the edge.

const TRAIT := "Ground slam"
const SLAM_RADIUS := 4.2
const SLAM_AHEAD := 1.6
const STUN_TIME := 1.6
## The share of melee_heavy_damage the shock deals at its centre (on top of a direct hit).
const SLAM_SHARE := 0.35

## Counts the slams (the view rings the bell on a change).
var slams := 0


func swing_input(fire: bool, aim: bool, ready: bool, delta: float) -> bool:
	var was := phase
	var used := super.swing_input(fire, aim, ready, delta)
	if phase == Phase.WINDUP and was == Phase.IDLE:
		Sfx.play(&"hstrk_windup", -4.0, randf_range(0.97, 1.03))
	return used


func _strike(heavy: bool) -> void:
	super._strike(heavy)
	if not heavy:
		return
	slams += 1
	var player := controller.player
	var forward := -player.aim_transform().basis.z
	var at := player.global_position + Vector3(forward.x, 0.0, forward.z).normalized() * SLAM_AHEAD
	var level := _level()
	player.add_shake(0.35)
	Sfx.play_at(&"hstrk_slam", at, 0.0, randf_range(0.96, 1.04))
	WeaponFx.shockwave(level, at + Vector3.UP * 0.3, Color(1.0, 0.82, 0.3), SLAM_RADIUS)
	WeaponFx.burst(level, at, Vector3.UP, [Color(1.0, 0.82, 0.3), Color(1.0, 0.25, 0.3), Color(1, 1, 1)], 18, 5.0, 0.7, 0.05, 70.0)
	var power := lerpf(data.melee_heavy_min_scale, 1.0, charge)
	for node in player.get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var d := z.global_position.distance_to(at)
		if d > SLAM_RADIUS:
			continue
		var tough := z.data.heavy or z.rank == Zombie.RANK_BOSS or z.data.mass >= ALPHA_MASS
		if not tough:
			z.interrupt()
		var status := StatusEffects.of(z)
		status.shock_left = maxf(status.shock_left, STUN_TIME)
		var dmg := data.melee_heavy_damage * SLAM_SHARE * power * (1.0 - 0.6 * d / SLAM_RADIUS)
		if tough:
			dmg *= data.melee_heavy_target_scale
		var dir := (z.global_position - at).normalized()
		controller.melee_hit(data, z, z.global_position + Vector3.UP, dir, dmg, 3.0 * (1.0 - d / SLAM_RADIUS))
