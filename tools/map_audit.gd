extends SceneTree
## Map audit tool (developer): batch captures and physics probes of one level
## scene, loaded on its own (no run, no player, no HUD).
##
## Captures (needs a renderer):
##   godot --path . --resolution 960x540 --script res://tools/map_audit.gd -- \
##       --level=<id> --out=<dir> --shots=<file> [--portal=1] [--open=1] [--collision=1]
##   Each line of the shots file is one image <dir>/<name>.png:
##     cam  <name> <x,y,z> <tx,ty,tz> [fov]   free camera looking at a point
##     pano <name> <x,y,z>                    4 views (N, E / S, W) from feet x,y,z
##     top  <name> <cx,cz> <size> [height]    orthographic top view, north up
##   --collision=1 draws every world collision shape as red lines (player-only
##   walls in yellow), to compare what is solid with what looks solid.
##   Draw calls and primitives of every `cam` shot are printed.
##
## Probe (headless is fine):
##   godot --headless --path . --script res://tools/map_audit.gd -- --level=<id> --probe=<out.png>
##   Flood-fills everywhere the player's capsule can get to from the spawn by
##   walking, stepping, falling, jumping, mantling and vaulting (the real
##   PlayerTraversal planner), then reports: falls out of the world, every
##   collider the player can stand on, places with no way back to the spawn
##   (stuck spots), places where walking along a wall stops dead (snags) and
##   navmesh polygons a zombie-sized capsule does not fit on. The PNG is a top
##   view of the reachable set coloured by height.
##
## Script mode compiles this file before the autoloads exist, so game classes
## are only reached untyped.

const EYE := 1.62
const WALK := 5.2
const SPRINT := 7.6
const SLIDE_JUMP := 10.1
const JUMP_VELOCITY := 7.44
const GRAVITY := 23.0
const FALL_SCALE := 1.45
## Run-ups tried for every jump: a standing hop and a slide-jump.
const JUMP_SPEEDS := [1.5, SLIDE_JUMP]
const TICK := 1.0 / 60.0
const CELL := 0.5

var opts := {}
var level: Node3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
	create_timer(float(_opt("timeout", "1500"))).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _opt(key: String, default_value: String) -> String:
	return String(opts.get(key, default_value))


func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _run() -> void:
	var packed: PackedScene = load("res://scenes/levels/%s.tscn" % _opt("level", "prize_pier"))
	level = packed.instantiate()
	var director := level.get_node_or_null("RunDirector")
	if director:
		level.remove_child(director)
		director.free()
	root.add_child(level)
	await _wait(4)
	if _opt("portal", "0") == "1":
		for p in get_nodes_in_group("portal"):
			p.activate()
	if _opt("open", "0") == "1":
		for k in get_nodes_in_group("kiosk"):
			k.set_open(true)
	if _opt("probe", "") != "":
		await physics_frame
		await physics_frame
		_probe()
		quit(0)
		return
	if _opt("collision", "0") == "1":
		_draw_collision(level)
	await _shots()
	quit(0)


# ---------------------------------------------------------------------------
# Captures
# ---------------------------------------------------------------------------

func _shots() -> void:
	var cam := Camera3D.new()
	cam.far = 900.0
	level.add_child(cam)
	cam.make_current()
	var out := _opt("out", "/tmp")
	DirAccess.make_dir_recursive_absolute(out)
	var settle := int(_opt("frames", "3"))
	await _wait(20)
	var f := FileAccess.open(_opt("shots", ""), FileAccess.READ)
	while f and not f.eof_reached():
		var bits := f.get_line().strip_edges().split(" ", false)
		if bits.size() < 3 or bits[0].begins_with("#"):
			continue
		var img: Image
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		match bits[0]:
			"cam":
				cam.fov = float(bits[4]) if bits.size() > 4 else 62.0
				cam.look_at_from_position(_vec(bits[2]), _vec(bits[3]))
				img = await _grab(settle)
				print("[audit] %s draw calls %d primitives %d" % [bits[1],
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
			"pano":
				cam.fov = 60.0
				cam.position = _vec(bits[2]) + Vector3.UP * EYE
				var size := root.get_viewport().get_visible_rect().size
				img = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGB8)
				for k in 4:
					cam.rotation = Vector3(0.0, -k * PI * 0.5, 0.0)
					var view: Image = await _grab(settle)
					view.convert(Image.FORMAT_RGB8)
					view.resize(int(size.x) / 2, int(size.y) / 2, Image.INTERPOLATE_BILINEAR)
					img.blit_rect(view, Rect2i(Vector2i.ZERO, view.get_size()), Vector2i((k % 2) * int(size.x) / 2, (k / 2) * int(size.y) / 2))
			"top":
				var c := bits[2].split(",")
				cam.projection = Camera3D.PROJECTION_ORTHOGONAL
				cam.size = float(bits[3])
				cam.position = Vector3(float(c[0]), float(bits[4]) if bits.size() > 4 else 60.0, float(c[1]))
				cam.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
				img = await _grab(settle)
			_:
				continue
		img.save_png("%s/%s.png" % [out, bits[1]])
	print("[audit] shots done")


func _grab(settle: int) -> Image:
	await _wait(settle)
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()


func _draw_collision(node: Node) -> void:
	if node is CollisionShape3D and node.shape and node.get_parent() is CollisionObject3D:
		var layer: int = node.get_parent().collision_layer
		if layer & 17:
			var mi := MeshInstance3D.new()
			mi.mesh = node.shape.get_debug_mesh()
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1, 0.1, 0.1) if layer & 1 else Color(1, 0.95, 0.1)
			m.no_depth_test = true
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(mi)
	for child in node.get_children():
		_draw_collision(child)


# ---------------------------------------------------------------------------
# Probe
# ---------------------------------------------------------------------------

var _body: CharacterBody3D
var _traverse
var _space: PhysicsDirectSpaceState3D
var _fell: Array = []


func _probe() -> void:
	_space = root.get_world_3d().direct_space_state
	_body = CharacterBody3D.new()
	_body.collision_layer = 0
	_body.collision_mask = 17
	_body.floor_snap_length = 0.35
	_body.safe_margin = 0.03
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	_body.add_child(shape)
	level.add_child(_body)
	_traverse = load("res://scripts/player/player_traversal.gd").new(_body, 0.4)

	var spawn: Node3D = get_first_node_in_group("player_spawn")
	var start := _settle(spawn.global_position)
	var dirs: Array[Vector3] = []
	for k in 16:
		dirs.append(Vector3(sin(TAU * k / 16.0), 0.0, -cos(TAU * k / 16.0)))
	var states := {}        # key -> feet position
	var edges := {}         # key -> Array of keys reached from it
	var moves := {}         # key -> how it was first reached
	var queue: Array = [start]
	states[_key(start)] = start
	moves[_key(start)] = "spawn"
	var head := 0
	while head < queue.size():
		var pos: Vector3 = queue[head]
		head += 1
		var from := _key(pos)
		var out: Array = []
		for k in 16:
			var dir := dirs[k]
			var results: Array = []
			var walked = _walk(pos, dir) if k % 2 == 0 else null
			if walked != null:
				results.append([walked, "walk"])
			# Jumps and ledge moves only where something is near or the floor ends
			# (an even slope or stair is plain walking).
			var plain: bool = walked != null and absf(walked.y - pos.y) < 0.32 and walked.distance_to(pos) > 0.45
			_body.global_position = pos
			if (k % 2 == 0 and not plain) or _body.test_move(_body.global_transform.translated(Vector3.UP * 0.35), dir * 1.4):
				for speed in JUMP_SPEEDS:
					var landed = _jump(pos, dir, speed)
					if landed != null:
						results.append([landed[0], landed[1]])
			for r in results:
				var p: Vector3 = r[0]
				var key := _key(p)
				if key == from:
					continue
				out.append(key)
				if not states.has(key):
					states[key] = p
					moves[key] = "%s from %s" % [r[1], _fmt(pos)]
					queue.append(p)
		edges[from] = out
		if head % 2000 == 0:
			print("[probe] ... %d of %d cells" % [head, queue.size()])
	print("[probe] reachable cells: %d" % states.size())
	_report(states, edges, moves, _key(start))
	_snags(states, dirs)
	_nav_fit()
	_save_map(states, _opt("probe", ""))


func _key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x / CELL), roundi(p.y / 0.25), roundi(p.z / CELL))


func _fmt(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]


## Drops the capsule onto the floor under `p`.
func _settle(p: Vector3) -> Vector3:
	_body.global_position = p + Vector3.UP * 0.05
	_body.move_and_collide(Vector3.DOWN * 3.0)
	return _body.global_position


## Walks CELL along `dir` as the player does (step-ups, slopes, floor snap),
## then falls if the floor ended. Null when blocked or lost.
func _walk(pos: Vector3, dir: Vector3):
	_body.global_position = pos
	_body.velocity = Vector3.ZERO
	var ticks := int(ceil(CELL / (WALK * TICK))) + 1
	for i in ticks:
		var climbed: float = _traverse.step_up(dir * WALK * TICK)
		if climbed < 0.0:
			_body.velocity = dir * WALK + Vector3.DOWN
			_body.move_and_slide()
	if not _body.is_on_floor() and not _fall(dir * WALK):
		return null
	var p := _body.global_position
	if Vector2(p.x - pos.x, p.z - pos.z).length() < 0.2 and absf(p.y - pos.y) < 0.2:
		return null
	return p


## Lets the body fall until it stands on something. False if it leaves the world.
func _fall(flat: Vector3) -> bool:
	var vy := minf(_body.velocity.y, 0.0)
	var from := _body.global_position
	for i in 600:
		vy -= GRAVITY * FALL_SCALE * TICK
		_body.velocity = Vector3(flat.x, vy, flat.z)
		_body.move_and_slide()
		if _body.is_on_floor():
			return true
		if _body.global_position.y < from.y - 30.0:
			_fell.append(from)
			return false
	return false


## A jump from `pos` along `dir` at `speed`, taking any ledge move the player
## would get on the way (on the ground first, then in the air). Returns
## [landing, description] or null.
func _jump(pos: Vector3, dir: Vector3, speed: float):
	_body.global_position = pos
	_body.velocity = Vector3.ZERO
	var how := "jump"
	var kind: int = _traverse.plan(dir, pos.y, false, speed)
	if kind == 1 and _traverse.planned_height() < 0.7:
		kind = 0
	if kind != 0:
		how = "mantle" if kind == 1 else "vault"
		_ledge_move(speed)
	else:
		var vy := JUMP_VELOCITY
		var flat := dir * speed
		var landed := false
		for i in 240:
			kind = _traverse.plan(dir, pos.y, true, speed)
			if kind != 0:
				var apex := _body.global_position.y + pow(maxf(vy, 0.0), 2.0) / (2.0 * GRAVITY)
				if apex <= _body.global_position.y + _traverse.planned_height() + 0.15:
					how = "jump+mantle" if kind == 1 else "jump+vault"
					_ledge_move(speed)
					break
			vy -= GRAVITY * (1.0 if vy > 0.0 else FALL_SCALE) * TICK
			_body.velocity = Vector3(flat.x, vy, flat.z)
			_body.move_and_slide()
			if _body.is_on_ceiling():
				vy = minf(vy, 0.0)
			if _body.is_on_floor() and vy <= 0.0:
				landed = true
				break
			if _body.global_position.y < pos.y - 30.0:
				_fell.append(pos)
				return null
		if landed:
			return [_body.global_position, "%s %.0f m/s" % [how, speed]]
	if not _body.is_on_floor():
		_body.velocity.y = 0.0
		if not _fall(dir * minf(speed, WALK)):
			return null
	return [_body.global_position, "%s %.0f m/s" % [how, speed]]


func _ledge_move(speed: float) -> void:
	_traverse.begin(speed)
	for i in 240:
		if not _traverse.step(TICK):
			break
	_body.velocity = Vector3.ZERO
	_body.move_and_slide()


## What the capsule stands on at `p`: the collider's path in the level.
func _floor_under(p: Vector3) -> String:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p + Vector3.DOWN * 0.6, 1)
	var hit := _space.intersect_ray(q)
	if hit.is_empty():
		# The capsule can rest on an edge: look around its foot.
		for k in 8:
			var o := Vector3(cos(TAU * k / 8.0), 0, sin(TAU * k / 8.0)) * 0.35
			q.from = p + o + Vector3.UP * 0.5
			q.to = p + o + Vector3.DOWN * 0.6
			hit = _space.intersect_ray(q)
			if not hit.is_empty():
				break
	if hit.is_empty():
		return "?"
	return String(level.get_path_to(hit["collider"] as Node))


func _report(states: Dictionary, edges: Dictionary, moves: Dictionary, start: Vector3i) -> void:
	for p in _fell:
		print("[probe] FELL OUT of the world from %s" % _fmt(p))
	if _fell.is_empty():
		print("[probe] no falls out of the world")
	# Colliders the player can stand on.
	var floors := {}
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for key in states:
		var p: Vector3 = states[key]
		lo = lo.min(p)
		hi = hi.max(p)
		var path := _floor_under(p)
		if not floors.has(path):
			floors[path] = [0, p, p.y, moves[key]]
		floors[path][0] += 1
		if p.y > floors[path][2]:
			floors[path][1] = p
			floors[path][2] = p.y
			floors[path][3] = moves[key]
	print("[probe] reachable bounds: %s .. %s" % [_fmt(lo), _fmt(hi)])
	var paths := floors.keys()
	paths.sort()
	for path in paths:
		var e: Array = floors[path]
		print("[probe] stands on %-56s cells=%-5d highest %s via %s" % [path, e[0], _fmt(e[1]), e[3]])
	# Cells with no way back to the spawn.
	var back := {}
	for from in edges:
		for to in edges[from]:
			if not back.has(to):
				back[to] = []
			back[to].append(from)
	var ok := {start: true}
	var stack: Array = [start]
	while not stack.is_empty():
		var k: Vector3i = stack.pop_back()
		for prev in back.get(k, []):
			if not ok.has(prev):
				ok[prev] = true
				stack.append(prev)
	var stuck := 0
	for key in states:
		if not ok.has(key):
			stuck += 1
			if stuck <= 40:
				print("[probe] STUCK (no way back) at %s on %s, reached by %s" % [_fmt(states[key]), _floor_under(states[key]), moves[key]])
	print("[probe] stuck cells: %d" % stuck)


## Walking at a glancing angle along a wall must slide, not stop.
func _snags(states: Dictionary, dirs: Array[Vector3]) -> void:
	var hit := KinematicCollision3D.new()
	var found := {}
	for key in states:
		var pos: Vector3 = states[key]
		for k in 16:
			var dir := dirs[k]
			_body.global_position = pos
			if not _body.test_move(_body.global_transform, dir * 0.5, hit, 0.03):
				continue
			var n := hit.get_normal()
			if n.y > 0.5 or absf(n.dot(dir)) > 0.75:
				continue        # floor, or a head-on wall
			_body.velocity = Vector3.ZERO
			for i in 45:
				var climbed: float = _traverse.step_up(dir * WALK * TICK)
				if climbed < 0.0:
					_body.velocity = dir * WALK + Vector3.DOWN
					_body.move_and_slide()
			var p := _body.global_position
			if Vector2(p.x - pos.x, p.z - pos.z).length() < 0.6:
				var cell := Vector3i(roundi(p.x), roundi(p.y), roundi(p.z))
				if not found.has(cell):
					var names := []
					for c in _body.get_slide_collision_count():
						var col := _body.get_slide_collision(c).get_collider() as Node
						names.append(String(level.get_path_to(col)))
					found[cell] = [p, dir, names]
	for cell in found:
		var e: Array = found[cell]
		print("[probe] SNAG at %s walking (%.1f, %.1f) against %s" % [_fmt(e[0]), e[1].x, e[1].z, e[2]])
	print("[probe] snag spots: %d" % found.size())


## Every navmesh polygon centre must have room for a zombie's capsule.
func _nav_fit() -> void:
	var region := level.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	if region == null:
		return
	var mesh := region.navigation_mesh
	var verts := mesh.get_vertices()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.7
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = capsule
	q.collision_mask = 1
	var bad := 0
	for i in mesh.get_polygon_count():
		var poly := mesh.get_polygon(i)
		var centre := Vector3.ZERO
		for v in poly:
			centre += verts[v]
		centre /= poly.size()
		q.transform = Transform3D(Basis(), region.global_transform * centre + Vector3.UP * 1.1)
		var hits := _space.intersect_shape(q, 1)
		if not hits.is_empty():
			bad += 1
			if bad <= 20:
				print("[probe] NAV polygon centre %s is inside %s" % [_fmt(centre), (hits[0]["collider"] as Node).name])
	print("[probe] navmesh: %d polygons, %d with no room for a zombie" % [mesh.get_polygon_count(), bad])


func _save_map(states: Dictionary, path: String) -> void:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for key in states:
		lo = lo.min(states[key])
		hi = hi.max(states[key])
	var scale := 8.0
	var w := int((hi.x - lo.x + 4.0) * scale)
	var h := int((hi.z - lo.z + 4.0) * scale)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.05, 0.05, 0.08))
	for key in states:
		var p: Vector3 = states[key]
		var t := clampf((p.y - lo.y) / maxf(0.5, hi.y - lo.y), 0.0, 1.0)
		var col := Color.from_hsv(0.6 - 0.6 * t, 0.8, 1.0)
		var px := int((p.x - lo.x + 2.0) * scale)
		var pz := int((p.z - lo.z + 2.0) * scale)
		img.fill_rect(Rect2i(px - 1, pz - 1, 3, 3), col)
	img.save_png(path)
	print("[probe] map %s: origin x=%.1f z=%.1f, %d px per metre, blue low .. red high (%.1f .. %.1f m)" % [path, lo.x - 2.0, lo.z - 2.0, int(scale), lo.y, hi.y])
