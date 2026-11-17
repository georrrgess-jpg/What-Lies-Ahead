extends RefCounted
## Clutter the zombies cannot snag on, called by tools/build_endless_city.gd
## round the navigation bake:
##
##   preload("res://tools/city/city_clutter.gd").prepare(self)        # before
##   preload("res://tools/city/city_clutter.gd").pass_through(self)   # after
##
## The navmesh is baked round every world collider (agent radius 0.75 m), but
## a zombie (capsule r 0.45-0.8) cuts the corners of its path by up to 0.8 m
## (NavigationAgent3D path_desired_distance). Round a small prop that puts it
## against the prop's side, pushing straight into it toward the next corner
## beyond: move_and_slide has nothing to slide along and the zombie stands
## there until its stall rescue. Measured by tools/stuck_probe.gd.
##
## So once the bake has cut them out of the navmesh, the small props (crates,
## bins, dumpsters, vending machines, debris, hydrants, meters, benches) and
## the low ledges (the statue's steps) standing on the street or the
## platform move from the world layer (1) to the player-only layer (5, 16):
## zombies still path round them, the player still bumps into them, and a
## zombie that clips a corner walks on through. Cover (jersey barriers, the
## police barriers) stays solid: it stops shots. For the bake, each is
## stretched up to BAKE_HEIGHT: the navmesh never climbs onto one (the
## statue's 0.35 m steps rounded to a climbable two cells, and a zombie
## walking through the step stood under its waypoint for good).

## A prop no wider or deeper than this (m) and no taller than PROP_HEIGHT is clutter.
const PROP_FOOTPRINT := 2.6
const PROP_HEIGHT := 2.0
## A ledge no taller than this (m, over max climb) and no wider than
## LEDGE_FOOTPRINT, on the floor or on another ledge (the statue's two steps).
const LEDGE_HEIGHT := 0.6
const LEDGE_FOOTPRINT := 6.0
## Floor levels (m) a prop stands on: the street and the Metro platform.
const FLOORS := [0.0, -6.0]
## Names of cover pieces, which stay on the world layer.
const COVER := ["Jersey", "Barrier"]
## Clutter is baked at least this tall (m).
const BAKE_HEIGHT := 2.0
const WORLD := 1
const PLAYER_WALLS := 16


## Marks every small prop and low ledge under the generator's navmesh
## geometry and stretches its shapes up to BAKE_HEIGHT for the bake.
static func prepare(builder: Variant) -> void:
	for node in (builder.geo as Node3D).find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if body.collision_layer != WORLD or not _is_clutter(body):
			continue
		body.set_meta("clutter", true)
		for cs: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
			var height := _size(cs.shape).y
			cs.set_meta("height", height)
			_set_height(cs, maxf(height, BAKE_HEIGHT))


## After the bake: gives the marked bodies back their shapes and moves them
## onto the player-only layer; returns how many.
static func pass_through(builder: Variant) -> int:
	var count := 0
	for node in (builder.geo as Node3D).find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if not body.has_meta("clutter"):
			continue
		body.remove_meta("clutter")
		for cs: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
			_set_height(cs, cs.get_meta("height"))
			cs.remove_meta("height")
		body.collision_layer = PLAYER_WALLS
		body.collision_mask = 0
		count += 1
	print("city_clutter: %d small props and ledges made zombie pass-through" % count)
	return count


## True for an upright body whose shapes are all small boxes or posts.
static func _is_clutter(body: StaticBody3D) -> bool:
	if body.name.begins_with("BenchFootprint") or body.global_basis.y.dot(Vector3.UP) < 0.999:
		return false
	if COVER.any(func(word: String) -> bool: return body.name.contains(word)):
		return false
	var shapes := body.find_children("*", "CollisionShape3D", false, false)
	if shapes.is_empty():
		return false
	for node in shapes:
		var cs := node as CollisionShape3D
		var size := _size(cs.shape)
		var bottom := cs.global_position.y - size.y * 0.5
		var lift := INF
		for y: float in FLOORS:
			if bottom - y > -0.3:
				lift = minf(lift, bottom - y)
		var footprint := maxf(size.x, size.z)
		var prop := lift < 0.3 and footprint <= PROP_FOOTPRINT and size.y <= PROP_HEIGHT
		var ledge := lift < LEDGE_HEIGHT and footprint <= LEDGE_FOOTPRINT and size.y <= LEDGE_HEIGHT
		if size == Vector3.ZERO or not (prop or ledge):
			return false
	return true


static func _size(shape: Shape3D) -> Vector3:
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size
	if shape is CylinderShape3D:
		var c := shape as CylinderShape3D
		return Vector3(c.radius * 2.0, c.height, c.radius * 2.0)
	return Vector3.ZERO


## Sets a box's or post's height, its bottom where it was.
static func _set_height(cs: CollisionShape3D, height: float) -> void:
	var old := _size(cs.shape).y
	if cs.shape is BoxShape3D:
		(cs.shape as BoxShape3D).size.y = height
	elif cs.shape is CylinderShape3D:
		(cs.shape as CylinderShape3D).height = height
	cs.position += cs.basis.y.normalized() * (height - old) * 0.5
