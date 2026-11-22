extends SceneTree
## Stuck probe (developer): do zombies snag on the map's colliders?
##
##   timeout 900 $GODOT --headless --audio-driver Dummy --path . --fixed-fps 60 \
##       --script res://tools/stuck_probe.gd -- [--level=endless_city] [--seconds=150]
##
## Loads the level with every "endless_gate" open, then puts a walker at every
## "enemy_spawn" marker for each of the probe targets (the player spawn and a
## point in each district). A walker is a zombie's movement body without the
## zombie: the regular capsule (r 0.45, h 1.9; every other walker a heavy's
## r 0.62), a NavigationAgent3D with the zombie's path settings, steering at
## the next path position at 3.5 m/s and moving with move_and_slide against
## world collision (layer 1), as Zombie._chase does. Walkers ignore each other.
##
## A walker that has not reached its target and has moved less than 0.5 m in
## the last 3 s is reported as STUCK with its position and the collider it last
## slid against (or the nearest one), then retired. The last lines group the
## stuck walkers by collider and count them.
##
## It also lists every small world collider (footprint under 3 m) that the
## navmesh runs under, i.e. one the navmesh bake did not cut out: zombies path
## straight into those.

const SPEED := 3.5
const WINDOW := 3.0
const MIN_MOVE := 0.5
const ARRIVE := 1.6
const SMALL := 3.0
## Probe targets beside the player spawn: the districts' middles (snapped to the navmesh).
## Ashfall City's; another map uses the middles of its district areas' boxes.
const TARGETS := [Vector3(-54.0, 0, 0.0), Vector3(-50.0, 0, -18.0), Vector3(45.0, 0, 0.0), Vector3(62.0, 0, 3.0),
	Vector3(84.0, 0, -2.0), Vector3(10.0, -6.0, -34.0), Vector3(70.0, 0, -45.0), Vector3(15.0, 0, 15.0)]

var _level: Node3D
var _frames := 0
var _seconds := 150.0
var _walkers: Array[Dictionary] = []
var _stuck: Array[Dictionary] = []
var _time := 0.0
var _started := false
var _city := true


func _initialize() -> void:
	var id := "endless_city"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			id = arg.get_slice("=", 1)
			_city = id == "endless_city"
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.get_slice("=", 1))
	var packed := load("res://scenes/levels/%s.tscn" % id) as PackedScene
	_level = packed.instantiate()
	var director := _level.get_node_or_null("RunDirector")
	if director:
		_level.remove_child(director)
		director.free()
	root.add_child(_level)


func _physics_process(delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		for gate in get_nodes_in_group("endless_gate"):
			if gate.has_method("open"):
				gate.call("open", false)
	# Wait for the navigation map to sync (its closest point is zero before).
	var map: RID = _level.get_world_3d().navigation_map
	if _frames < 90 or NavigationServer3D.map_get_closest_point(map, Vector3(-54.0, 0, 0)) == Vector3.ZERO:
		return false
	if not _started:
		_started = true
		_report_uncut()
		_spawn_walkers()
		return false
	_time += delta
	var active := 0
	for w in _walkers:
		if not w.done:
			_step(w, delta)
			active += 1
	if active == 0 or _time >= _seconds:
		_finish()
		return true
	return false


func _spawn_walkers() -> void:
	var map: RID = _level.get_world_3d().navigation_map
	var goals: Array[Vector3] = []
	for node in get_nodes_in_group("player_spawn"):
		goals.append(NavigationServer3D.map_get_closest_point(map, (node as Node3D).global_position))
	var targets: Array = TARGETS
	if not _city:
		targets = []
		for area in get_nodes_in_group("endless_district_area"):
			for box in (area as Node).get_children():
				if box is CollisionShape3D:
					targets.append(Vector3((box as Node3D).global_position.x, 0, (box as Node3D).global_position.z))
	for t in targets:
		goals.append(NavigationServer3D.map_get_closest_point(map, t))
	var k := 0
	for sp in get_nodes_in_group("enemy_spawn"):
		for g in goals:
			var body := CharacterBody3D.new()
			body.collision_layer = 0
			body.collision_mask = 1
			body.floor_snap_length = 0.45
			var shape := CollisionShape3D.new()
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.62 if k % 2 else 0.45
			capsule.height = 1.9
			shape.shape = capsule
			shape.position.y = 0.95
			body.add_child(shape)
			var agent := NavigationAgent3D.new()
			agent.path_desired_distance = 0.8
			agent.target_desired_distance = 1.2
			agent.path_max_distance = 3.0
			body.add_child(agent)
			_level.add_child(body)
			body.global_position = (sp as Node3D).global_position
			agent.target_position = g
			_walkers.append({"body": body, "agent": agent, "goal": g, "anchor": body.global_position, "timer": 0.0,
				"repath": randf() * 0.3, "done": false, "from": String(sp.name), "radius": capsule.radius, "last": ""})
			k += 1
	print("[stuck] %d walkers (%d spawns x %d targets)" % [_walkers.size(), get_nodes_in_group("enemy_spawn").size(), goals.size()])


func _step(w: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = w.body
	var agent: NavigationAgent3D = w.agent
	var goal: Vector3 = w.goal
	if Vector2(body.global_position.x - goal.x, body.global_position.z - goal.z).length() < ARRIVE:
		w.done = true
		return
	w.repath -= delta
	if w.repath <= 0.0:
		w.repath = 0.3
		agent.target_position = goal
	var dir := goal - body.global_position
	if not agent.is_navigation_finished():
		dir = agent.get_next_path_position() - body.global_position
	dir.y = 0.0
	dir = dir.normalized()
	body.velocity.x = dir.x * SPEED
	body.velocity.z = dir.z * SPEED
	body.velocity.y = -1.0 if body.is_on_floor() else body.velocity.y - 20.0 * delta
	body.move_and_slide()
	w.last = ""
	for i in body.get_slide_collision_count():
		var c := body.get_slide_collision(i)
		if c.get_normal().y < 0.7:
			w.last = _name(c.get_collider())
	w.timer += delta
	if w.timer < WINDOW:
		return
	w.timer = 0.0
	var moved := body.global_position.distance_to(w.anchor)
	w.anchor = body.global_position
	if moved < MIN_MOVE or body.global_position.y < -12.0:
		w.done = true
		var what: String = w.last if w.last != "" else _nearest(body)
		_stuck.append({"at": body.global_position, "what": what})
		print("[stuck] STUCK %s r%.2f -> %s at %s by %s" % [w.from, w.radius, _v(goal), _v(body.global_position), what])


func _nearest(body: CharacterBody3D) -> String:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.5
	query.shape = sphere
	query.collision_mask = 1
	query.transform = Transform3D(Basis.IDENTITY, body.global_position + Vector3.UP * 0.9)
	var hits := body.get_world_3d().direct_space_state.intersect_shape(query, 4)
	var names := PackedStringArray()
	for h in hits:
		names.append(_name(h.collider))
	return ", ".join(names) if not names.is_empty() else "nothing near"


## Small world colliders the navmesh runs under (the bake did not cut them out).
func _report_uncut() -> void:
	var map: RID = _level.get_world_3d().navigation_map
	var count := 0
	for body in _level.find_children("*", "StaticBody3D", true, false):
		var sb := body as StaticBody3D
		if sb.collision_layer & 1 == 0:
			continue
		for shape in sb.find_children("*", "CollisionShape3D", false, false):
			var cs := shape as CollisionShape3D
			if cs.disabled or cs.shape == null:
				continue
			var box := cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
			if box.size.x > SMALL or box.size.z > SMALL or box.size.y < 0.3:
				continue
			var centre := box.get_center()
			var probe := Vector3(centre.x, box.position.y, centre.z)
			var near := NavigationServer3D.map_get_closest_point(map, probe)
			if Vector2(near.x - centre.x, near.z - centre.z).length() < 0.2 and absf(near.y - box.position.y) < 0.6:
				count += 1
				print("[stuck] UNCUT %s at %s size %s" % [_name(sb), _v(centre), _v(box.size)])
	print("[stuck] %d small colliders with navmesh under them" % count)


func _finish() -> void:
	var by := {}
	for s in _stuck:
		by[s.what] = int(by.get(s.what, 0)) + 1
	for what in by:
		print("[stuck] %3d x %s" % [by[what], what])
	print("[stuck] RESULT %d walkers, %d stuck, %d still walking after %.0f s" % [_walkers.size(), _stuck.size(),
		_walkers.filter(func(w: Dictionary) -> bool: return not w.done).size(), _time])
	quit(0 if _stuck.is_empty() else 2)


func _name(node: Object) -> String:
	if node is Node:
		var n := node as Node
		return "%s/%s" % [n.get_parent().name, n.name] if n.get_parent() else String(n.name)
	return "?"


func _v(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]
