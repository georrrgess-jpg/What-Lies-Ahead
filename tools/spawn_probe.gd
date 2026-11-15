extends SceneTree
## Spawn probe: checks that every zombie entrance of a level leads onto the
## navmesh and into the arena, the way RunDirector._spawn places zombies.
##
##   xvfb-run -a -s "-screen 0 640x480x24" $GODOT --audio-driver Dummy --rendering-driver opengl3 \
##       --path . --script res://tools/spawn_probe.gd -- <level_id> [<level_id> ...]
##   (--headless works as well; use --open-gates=0 to probe an Endless map
##   with its gates shut)
##
## Each level scene is loaded from scenes/levels/<id>.tscn. Every node in the
## "endless_gate" group is opened first (EndlessGate.open()), so an Endless
## map is probed with every district open. Then, for every "enemy_spawn"
## marker and a 9 x 9 grid of offsets at each spread RunDirector uses (0, 1
## and 2.2 m; above 1 m the offset is snapped to the navmesh within 1 m, as
## _spawn does), it measures:
##   floor  the drop from the spawn position to the world floor (layer 1)
##          below it (a navmesh floats about 0.5 m over steps, so 0.6-0.7 m
##          where a pack is snapped onto it is benign)
##   nav    the horizontal distance to the nearest navmesh point: where the
##          zombie walks first (NavigationAgent3D starts its path there)
##   walk   whether a zombie capsule (r 0.45, h 1.9, lifted 0.3 m over lips)
##          moving straight from the spawn to that point hits world collision
##          (layer 1; player walls on layer 16 do not stop zombies), or
##          whether the zombie would appear inside a collider (a pack offset
##          too close to a wall or prop: physics may push it out either side)
##   path   whether the navmesh path from that point reaches the player spawn
##
## Per spawn the verdict is OK (every offset on the navmesh), CLIMB-IN (some
## offsets off it but walking freely onto it: an entrance by design) or BAD
## (no floor, a blocked walk or no path), with the first bad samples listed.
## A blocked walk means the zombie walks into a wall at the wrong nearest
## point until its stall rescue teleports it. The last line counts BAD spawns.

const SPREADS := [0.0, 1.0, 2.2]
const GRID := 4                   ## offsets -GRID..GRID per axis (spread 0: one)
const SETTLE_FRAMES := 60         ## frames for the navigation map to sync
const ON_MESH := 0.6              ## m: closer than this counts as on the navmesh
const MAX_DROP := 0.75            ## m: a deeper drop to the floor is reported
const PATH_GAP := 1.5             ## m: the path must end this close to the goal
const CAPSULE_LIFT := 0.3
const CORE_RADIUS := 0.05         ## m: the axis cast when the full capsule grazes a wall at the spawn
const FAR := 4.0                  ## m: a free climb-in this long is noted

var _queue: PackedStringArray
var _open_gates := true
var _level: Node
var _frames := 0
var _bad_total := 0
var _capsule := CapsuleShape3D.new()
var _core := CapsuleShape3D.new()


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--open-gates="):
			_open_gates = arg.get_slice("=", 1) != "0"
		else:
			_queue.append(arg)
	_capsule.radius = 0.45
	_capsule.height = 1.9
	_core.radius = CORE_RADIUS
	_core.height = 1.9
	if _queue.is_empty():
		push_error("spawn_probe: name at least one level id")
		quit(1)
		return
	_load_next()


func _process(_delta: float) -> bool:
	if _level == null:
		return false
	_frames += 1
	if _frames == 2 and _open_gates:
		for gate in get_nodes_in_group("endless_gate"):
			if gate.has_method("open"):
				gate.call("open", false)
	if _frames < SETTLE_FRAMES:
		return false
	_probe_level()
	root.remove_child(_level)
	_level.queue_free()
	_level = null
	if _queue.is_empty():
		print("[probe] done: %d BAD spawn(s)" % _bad_total)
		quit(0 if _bad_total == 0 else 2)
	else:
		_load_next.call_deferred()
	return false


func _load_next() -> void:
	var id: String = _queue[0]
	_queue.remove_at(0)
	var path := "res://scenes/levels/%s.tscn" % id
	var packed := load(path) as PackedScene
	if packed == null:
		print("[probe] %s: cannot load %s" % [id, path])
		_bad_total += 1
		if _queue.is_empty():
			quit(2)
		else:
			_load_next.call_deferred()
		return
	print("== %s" % id)
	_level = packed.instantiate()
	_frames = 0
	root.add_child(_level)


func _probe_level() -> void:
	var world := (_level as Node3D).get_world_3d()
	var map: RID = world.navigation_map
	var space := world.direct_space_state
	var goal := Vector3.ZERO
	for node in get_nodes_in_group("player_spawn"):
		if node is Node3D and _level.is_ancestor_of(node):
			goal = (node as Node3D).global_position
	goal = NavigationServer3D.map_get_closest_point(map, goal)
	for node in get_nodes_in_group("enemy_spawn"):
		if node is Node3D and _level.is_ancestor_of(node):
			_probe_spawn(node as Node3D, map, space, goal)


func _probe_spawn(point: Node3D, map: RID, space: PhysicsDirectSpaceState3D, goal: Vector3) -> void:
	var p := point.global_position
	var bad: Array[String] = []
	var samples := 0
	var climbs := 0
	var worst_nav := 0.0
	var worst_drop := 0.0
	for spread: float in SPREADS:
		var steps := 0 if spread == 0.0 else GRID
		for ix in range(-steps, steps + 1):
			for iz in range(-steps, steps + 1):
				var off := Vector3(ix, 0, iz) * (spread / maxf(steps, 1))
				var at := p + off
				if spread > 1.0:
					var ground := NavigationServer3D.map_get_closest_point(map, at)
					at = ground if ground.distance_to(at) < 1.0 else p + off / spread
				samples += 1
				var r := _sample(at, map, space, goal)
				worst_nav = maxf(worst_nav, r.nav)
				worst_drop = maxf(worst_drop, r.drop)
				if r.problem != "":
					bad.append("spread %.1f off (%.1f, %.1f) at %s: %s" % [spread, off.x, off.z, _v(at), r.problem])
				elif r.nav >= ON_MESH:
					climbs += 1
	var verdict := "BAD" if not bad.is_empty() else ("CLIMB-IN" if climbs > 0 else "OK")
	var note := "  (far: walks %.1f m onto the navmesh)" % worst_nav if verdict == "CLIMB-IN" and worst_nav > FAR else ""
	print("[spawn] %-18s %s %-8s %d samples: %d climb in, %d bad; nav <= %.1f m, drop <= %.2f m%s" % [point.name, _v(p), verdict,
		samples, climbs, bad.size(), worst_nav, worst_drop, note])
	for line in bad.slice(0, 6):
		print("    ", line)
	if not bad.is_empty():
		_bad_total += 1


## One spawn position: {drop, nav, problem} ("" when it is fine).
func _sample(at: Vector3, map: RID, space: PhysicsDirectSpaceState3D, goal: Vector3) -> Dictionary:
	var feet := _floor(space, at)
	var drop: float = at.y - feet.y if feet.x == feet.x else 99.0
	if drop > MAX_DROP:
		return {"drop": drop, "nav": 0.0, "problem": "no floor within 0.75 m (drop %.1f)" % drop}
	var near := NavigationServer3D.map_get_closest_point(map, at)
	var nav := Vector2(near.x - at.x, near.z - at.z).length()
	var route := NavigationServer3D.map_get_path(map, near, goal, true)
	var gap: float = route[route.size() - 1].distance_to(goal) if route.size() > 0 else 99.0
	if gap > PATH_GAP:
		return {"drop": drop, "nav": nav, "problem": "no navmesh path to the player spawn from %s (ends %.1f m short)" % [_v(near), gap]}
	if nav < ON_MESH:
		return {"drop": drop, "nav": nav, "problem": ""}
	var target := _floor(space, near)
	if target.x != target.x:
		target = near
	var blocker := _walk(space, feet, target)
	if blocker != "":
		return {"drop": drop, "nav": nav, "problem": "walk to the nearest navmesh point %s (%.1f m) blocked by %s" % [_v(near), nav, blocker]}
	return {"drop": drop, "nav": nav, "problem": ""}


## The world floor (layer 1) under `at`, or a NAN vector if none within 6 m.
func _floor(space: PhysicsDirectSpaceState3D, at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 6.0, 1)
	var hit := space.intersect_ray(query)
	return hit.position if hit else Vector3(NAN, NAN, NAN)


## Casts the zombie capsule from `from` to `to` (feet positions); returns the
## blocking collider's name, or "" when the walk is free. A spawn the capsule
## only grazes (physics pushes the zombie back out on its own side) is cast
## with its axis instead; one whose axis is inside a collider is reported.
func _walk(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> String:
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = 1
	var lift := Vector3.UP * (_capsule.height * 0.5 + CAPSULE_LIFT)
	query.transform = Transform3D(Basis.IDENTITY, from + lift)
	for shape in [_capsule, _core]:
		query.shape = shape
		var inside := space.intersect_shape(query, 1)
		if inside.is_empty():
			break
		if shape == _core:
			return "%s (the spawn stands inside it)" % _name(inside[0].collider)
	query.motion = to - from
	var frac := space.cast_motion(query)
	if frac[0] >= 1.0:
		return ""
	var travel := (to - from) * frac[1]
	query.transform = Transform3D(Basis.IDENTITY, from + lift + travel)
	query.motion = Vector3.ZERO
	var rest := space.get_rest_info(query)
	var what := _name(instance_from_id(rest.collider_id)) if rest else "?"
	return "%s after %.1f m" % [what, travel.length()]


func _name(node: Object) -> String:
	if node is Node:
		var n := node as Node
		return "%s/%s" % [n.get_parent().name, n.name] if n.get_parent() else String(n.name)
	return "?"


func _v(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]
