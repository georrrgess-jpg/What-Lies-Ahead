class_name ClawGrabberReel
extends RefCounted
## Where the Claw Grabber's grapple may reel the player (ClawGrabberShot):
## the safety rules, in one place so the probe (scripts/dev/claw_grabber_probe.gd)
## tests exactly what the game does.
##
## A reel toward a gripped point (a wall, the floor, a heavy zombie) ends at a
## spot that is all of:
##   on the navmesh the zombies walk, under the gripped point (never on a
##   roof, a prop top or anywhere off the playable floor), and no higher than
##   MAX_RISE above the player's feet (no higher than a jump reaches);
##   reachable on foot from where the player stands (a navmesh path that ends
##   there and is not a long detour), so it never crosses into a closed
##   district or past the level's edge;
##   at the end of a straight capsule sweep from the player with the player's
##   own collision mask (scenery and the invisible player-only walls), cut
##   short at the first thing in the way;
##   between MIN_REEL and RANGE metres away.
## The player's own move (Player.reel_to) is then a move_and_slide every tick,
## so even a zombie or a door that moves into the way stops it.

## Longest reel (m, flat), and shortest worth making.
const RANGE := 16.0
const MIN_REEL := 1.5
## Highest the end may be above the player's feet (m).
const MAX_RISE := 0.9
## Furthest (m, flat) the navmesh point may be from the point under the grip.
const LAND_SLOP := 1.4
## The walking route may be at most this many times the straight line (plus DETOUR_PAD m).
const DETOUR := 1.8
const DETOUR_PAD := 3.0
## How far the sweep starts above the feet (clears seams), and the margin kept short of a hit.
const LIFT := 0.25
const SWEEP_MARGIN := 0.15
const MASK_ENEMIES := 4


## The end of a reel toward `goal` for `player`, or Vector3.INF when there is
## no safe one. `goal` is the point the player should end up near (feet level
## or above: a wall grip's stand-off point, a spot in front of a heavy).
static func landing(player: Player, goal: Vector3) -> Vector3:
	var map := player.get_world_3d().navigation_map
	if not map.is_valid() or NavigationServer3D.map_get_regions(map).is_empty():
		return Vector3.INF
	var feet := player.global_position
	var land := NavigationServer3D.map_get_closest_point(map, goal)
	if Vector2(land.x - goal.x, land.z - goal.z).length() > LAND_SLOP:
		return Vector3.INF
	if land.y - feet.y > MAX_RISE:
		return Vector3.INF
	var flat := Vector2(land.x - feet.x, land.z - feet.z).length()
	if flat > RANGE + LAND_SLOP or flat < MIN_REEL:
		return Vector3.INF
	var start := NavigationServer3D.map_get_closest_point(map, feet)
	var path := NavigationServer3D.map_get_path(map, start, land, true)
	if path.is_empty() or path[path.size() - 1].distance_to(land) > 0.6:
		return Vector3.INF
	var walk := 0.0
	for i in range(1, path.size()):
		walk += path[i - 1].distance_to(path[i])
	if walk > flat * DETOUR + DETOUR_PAD:
		return Vector3.INF
	return _sweep(player, land)


## The capsule sweep from the player toward `land`: where it stops short of
## the first thing in the way (or `land` itself), Vector3.INF if that is too close.
static func _sweep(player: Player, land: Vector3) -> Vector3:
	var shape_node := player.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		return Vector3.INF
	var lift := Vector3.UP * LIFT
	var motion := land + lift - (player.global_position + lift)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape_node.shape
	q.transform = Transform3D(Basis.IDENTITY, lift) * player.global_transform * shape_node.transform
	q.motion = motion
	q.collision_mask = player.collision_mask & ~MASK_ENEMIES
	q.exclude = [player.get_rid()]
	q.margin = 0.02
	var space := player.get_world_3d().direct_space_state
	var fraction := space.cast_motion(q)
	var safe := float(fraction[0]) if fraction.size() > 0 else 1.0
	if safe >= 1.0:
		return land
	var length := motion.length()
	var keep := maxf(0.0, safe * length - SWEEP_MARGIN)
	if keep < MIN_REEL:
		return Vector3.INF
	return player.global_position + motion.normalized() * keep
