extends WeaponMode
## Riptide Harpoon: every zombie the harpoon skewers is reeled toward the
## player. The pull grows with the zombie's weight (REEL_PULL x sqrt(mass)
## on its knockback), so a Bruiser is yanked out of its charge and staggers
## too, while an alpha only budges; zombies already close are barely pulled,
## so nothing is dragged into the player's face. Heavies take HEAVY_BONUS
## damage. Draws the harpoon on its line (HarpoonLine); the spear and spool
## on the viewmodel move in scripts/weapons/views/riptide_view.gd.

## Pull on a 1-mass zombie at full charge (m/s of knockback toward the player).
const REEL_PULL := 7.0
## No pull inside MIN_GAP metres, full pull from MIN_GAP + PULL_RAMP on.
const MIN_GAP := 3.5
const PULL_RAMP := 4.0
const HEAVY_BONUS := 1.3
const REEL_SOUND := &"weap_rip_reel"


func shape_hits(hits: Dictionary, from: Vector3, end: Vector3, power: float) -> void:
	var eye := controller.player.global_position
	for key in hits:
		var entry: Dictionary = hits[key]
		var z: Zombie = entry["zombie"]
		if not is_instance_valid(z):
			continue
		var gap := Vector2(z.global_position.x - eye.x, z.global_position.z - eye.z).length()
		var reach := clampf((gap - MIN_GAP) / PULL_RAMP, 0.0, 1.0)
		# Pushing against the shot's direction pulls the zombie toward the player.
		entry["push"] = -REEL_PULL * sqrt(maxf(0.2, z.data.mass)) * power * reach
		if z.data.heavy:
			entry["damage"] = float(entry["damage"]) * HEAVY_BONUS
			entry["head_damage"] = float(entry["head_damage"]) * HEAVY_BONUS
	HarpoonLine.spawn(controller.player.get_parent(), controller.player.view, from, end, data.tracer_color, power)
	if not hits.is_empty():
		Sfx.play(REEL_SOUND, -5.0, randf_range(0.96, 1.04))
