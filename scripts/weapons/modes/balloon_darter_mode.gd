extends WeaponMode
## Balloon Darter: every dart that hits a zombie sticks and ties a balloon on
## it (BalloonBunch). Just under a second after the first dart the bunch pops for damage
## per balloon and splashes its neighbours, setting off their balloons too, so
## tagging a pack then watching it go off in a chain is the weapon's trick.
## The darts themselves are light hitscan shots (WeaponData damage). The dart,
## plunger, clip and gauge on the viewmodel move in
## scripts/weapons/views/balloon_darter_view.gd.


func shape_hits(hits: Dictionary, _from: Vector3, _end: Vector3, _power: float) -> void:
	for key in hits:
		var entry: Dictionary = hits[key]
		var z: Zombie = entry["zombie"]
		if is_instance_valid(z) and not z.is_dead():
			BalloonBunch.of(z).add(data, controller, entry["body_point"])


## Every dart ties a balloon that pops for BalloonBunch.POP_DAMAGE (at most
## MAX_BALLOONS per FUSE on one zombie).
func arsenal_dps(base: float) -> float:
	var darts_per_second := base / maxf(1.0, data.burst_damage())
	var balloons := minf(darts_per_second, BalloonBunch.MAX_BALLOONS / BalloonBunch.FUSE)
	return base + balloons * BalloonBunch.POP_DAMAGE
