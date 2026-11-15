extends WeaponMode
## Balloon Darter: every dart that hits a zombie sticks and ties a balloon on
## it (BalloonBunch). A second after the first dart the bunch pops for damage
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
