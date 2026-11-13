extends SceneTree
## Repeatable performance probe: runs scripted scenarios with the real game
## code and prints one table row per scenario.
##
##   Script time (headless, fast):
##     godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tools/perf_probe.gd -- [options]
##   With draw calls / primitives and the Locker thumbnail bake (software renderer, slow):
##     xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . --fixed-fps 60 \
##         --resolution 960x540 --script res://tools/perf_probe.gd -- [options]
##
## Options:
##   --profile=<file>      profile to use (a copy; use one with everything unlocked)
##   --level=<id>          level for the in-game scenarios (default prize_pier)
##   --only=a,b,...        scenarios to run (default: all but soak). Names:
##                         menu, locker, load, weapons (all 8) or weapon:<id>, kill_fx,
##                         tracers, crowd, soak
##   --seconds=<s>         length of each weapon / crowd scenario (default 8)
##   --soak-minutes=<m>    length of the soak (default 10): every weapon in turn into a
##                         crowd, printing node / object counts every 30 s
##
##   --materials=1         also run the shader warm-up check below (it scans the scene
##                         tree, so leave it off when reading frame times)
##
## Columns: frames; average, 95th percentile and worst CPU time per frame in ms
## (wall clock; see _Stats); node and object counts at
## the end and their growth over the scenario; orphan nodes; nodes and audio players
## created per second (SceneTree.node_added); draw calls and primitives per frame
## (rendered runs only).
##
## Shader warm-up check: every material variant on a visible node is recorded (a
## StandardMaterial3D by its shader-affecting flags and textures, a ShaderMaterial
## by its shader, plus the kind of geometry: mesh, skinned, multimesh, label).
## Variants first seen after the level's warm-up window are listed at the end as
## "late material" lines (each one is a shader compile in the middle of play).
##
## Script mode compiles this file before the autoloads exist, so game singletons
## are reached through root.get_node().

const ZOMBIE_SCENE := "res://scenes/enemies/zombie.tscn"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const STATE_WAVE := 1
const CROWD := 10
const SPECIAL_CROWD := 14
## Frames after the level is up that count as the warm-up window (the HUD's
## fade-in lasts 0.8 s).
const WARMUP_FRAMES := 48

var opts := {}
var rendered := false
var rows: Array = []
var _created := 0
var _audio_created := 0
var _scenario := ""
var _seen := {}
var _late: Array = []
var _warm_closed := false
var _mat_keys := {}
var _scan_tick := 0
var tracking := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
	rendered = DisplayServer.get_name() != "headless"
	tracking = _opt("materials", "0") == "1"
	node_added.connect(_on_node_added)
	create_timer(float(_opt("timeout", "3000"))).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _opt(key: String, default_value: String) -> String:
	return String(opts.get(key, default_value))


func _wants(name: String) -> bool:
	var only := _opt("only", "menu,locker,load,weapons,kill_fx,tracers,crowd")
	for part in only.split(","):
		if part == name or (name.begins_with("weapon:") and part == "weapons"):
			return true
	return false


func _on_node_added(n: Node) -> void:
	_created += 1
	if n is AudioStreamPlayer or n is AudioStreamPlayer3D:
		_audio_created += 1
	if tracking and n is GeometryInstance3D:
		_note_geometry.call_deferred(n)


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


# --- the run --------------------------------------------------------------------

func _run() -> void:
	await _wait(3)
	if _opt("profile", "") != "":
		print("[perf] profile %s" % _opt("profile", ""))
	print("[perf] rendered=%s level=%s" % [rendered, _opt("level", "prize_pier")])
	if _wants("menu") or _wants("locker"):
		change_scene_to_file(MENU_SCENE)
		await _wait(30)
		if _wants("menu"):
			await _measure("menu idle", 240, Callable())
		if _wants("locker"):
			await _locker()
	var director = await _load_level()
	if director == null:
		quit(1)
		return
	await _stage(director)
	var weapons: Array = root.get_node("GameData").weapons()
	for w in weapons:
		if _wants("weapon:" + String(w.id)):
			await _weapon(director, w)
	if _wants("kill_fx"):
		await _kill_fx(director)
	if _wants("tracers"):
		await _tracers(director)
	if _wants("crowd"):
		await _crowd(director)
	if _wants("soak"):
		await _soak(director, weapons)
	_print_table()
	quit(0)


func _load_level(): # -> RunDirector
	var game: Node = root.get_node("Game")
	game.level = root.get_node("GameData").level(StringName(_opt("level", "prize_pier")))
	game.weapon_id = &"pulse_pistol"
	var t0 := Time.get_ticks_usec()
	var s := _Stats.new(self)
	if rendered and current_scene != null:
		# The real path: the loading card with a threaded load.
		load("res://scripts/ui/loading_screen.gd").start(self, game.level)
	else:
		change_scene_to_file(game.level.scene_path)
	var director = null
	while director == null or director.player == null:
		await process_frame
		s.sample()
		director = get_first_node_in_group("run_director")
		if Time.get_ticks_usec() - t0 > 120_000_000:
			push_error("level did not load")
			return null
	# The warm-up window: the fade-in plus the warm-up nodes' frames.
	for i in WARMUP_FRAMES:
		await process_frame
		s.sample()
		_scan()
	_warm_closed = true
	if _wants("load"):
		rows.append(s.row("level load (%.0f ms)" % ((Time.get_ticks_usec() - t0) / 1000.0)))
	return director


## Stops the waves and makes the player an invulnerable turret.
func _stage(director) -> void:
	director.set_process(false)
	director._set_state(STATE_WAVE)
	director.player.invulnerable = true
	director.player.controls_enabled = true
	await _wait(5)


## Samples `frames` frames, calling `step(frame)` before each.
func _measure(name: String, frames: int, step: Callable) -> void:
	_scenario = name
	var s := _Stats.new(self)
	for f in frames:
		if step.is_valid():
			step.call(f)
		await process_frame
		s.sample()
		_scan()
	rows.append(s.row(name))


# --- scenarios ------------------------------------------------------------------

func _locker() -> void:
	var menu := current_scene
	menu._show("locker")
	await _wait(20)
	var page: Node = menu.page("locker")
	var catalog = load("res://scripts/cosmetics/locker_catalog.gd")
	var cats: Array = catalog.CATEGORIES
	_scenario = "locker"
	var s := _Stats.new(self)
	for cat in cats:
		page.show_category(cat["slot"])
		for f in 45:
			await process_frame
			s.sample()
	for w in root.get_node("GameData").weapons():
		page.select_weapon(w.id)
		page.show_category(&"weapon_finish")
		for f in 30:
			await process_frame
			s.sample()
	rows.append(s.row("locker: every tab and weapon"))


func _weapon(director, w) -> void:
	var player = director.player
	player.weapons.set_loadout(w.id, player.weapons.slots[1])
	_fill_crowd(director, CROWD, [])
	await _wait(20)
	var frames := int(float(_opt("seconds", "8")) * 60.0)
	await _measure("fire %s" % w.id, frames, func(f: int): _fire_step(director, f, w))
	Input.action_release("fire")
	await _wait(30)


func _fire_step(director, f: int, w) -> void:
	_fill_crowd(director, CROWD, [])
	_aim_at_nearest(director)
	var weapons = director.player.weapons
	if f % 30 == 0:
		weapons.top_up()
	# Charge weapons need the trigger let go to fire; everything else holds it.
	var hold := 100000 if w.automatic or w.beam else (50 if w.charge_time > 0.0 else 3)
	if f % (hold + maxi(3, hold / 12)) < hold:
		Input.action_press("fire")
	else:
		Input.action_release("fire")


func _kill_fx(director) -> void:
	var cos: Node = root.get_node("Cosmetics")
	var parent: Node = director.get_parent()
	var cam: Camera3D = director.player.camera
	var at := cam.global_position - cam.global_transform.basis.z * 6.0
	var ke = load("res://scripts/cosmetics/kill_effects.gd")
	for it in cos.items_for(&"kill_effect"):
		await _measure("kill effect %s" % it.id, 120, func(f: int):
			if f % 10 == 0:
				ke.play(parent, at + Vector3(randf_range(-2, 2), 0, randf_range(-1, 1)), it))
	await _wait(60)


func _tracers(director) -> void:
	var cos: Node = root.get_node("Cosmetics")
	var parent: Node = director.get_parent()
	var cam: Camera3D = director.player.camera
	var from := cam.global_position - cam.global_transform.basis.z * 0.6 + Vector3.DOWN * 0.15
	var ts = load("res://scripts/cosmetics/tracer_styles.gd")
	for it in cos.items_for(&"tracer"):
		await _measure("tracer %s" % it.id, 120, func(f: int):
			if f % 5 == 0:
				var to := from - cam.global_transform.basis.z * 25.0 + Vector3(randf_range(-3, 3), randf_range(-1, 1), 0)
				ts.draw(parent, from, to, 0.05, it))
	await _wait(60)


## Specials and regulars walk in and attack; the player does not shoot.
func _crowd(director) -> void:
	Input.action_release("fire")
	var kinds: Array = director._level_enemies()
	_fill_crowd(director, SPECIAL_CROWD, kinds)
	await _wait(10)
	var frames := int(float(_opt("seconds", "8")) * 60.0)
	await _measure("crowd of %d (specials)" % SPECIAL_CROWD, frames, func(_f: int): _fill_crowd(director, SPECIAL_CROWD, kinds))


func _soak(director, weapons: Array) -> void:
	var minutes := float(_opt("soak-minutes", "10"))
	var frames := int(minutes * 3600.0)
	_scenario = "soak"
	var s := _Stats.new(self)
	var per := 1800
	for f in frames:
		var w = weapons[(f / per) % weapons.size()]
		if f % per == 0:
			director.player.weapons.set_loadout(w.id, director.player.weapons.slots[1])
		_fire_step(director, f, w)
		await process_frame
		s.sample()
		if f % 1800 == 0:
			print("[soak] t=%4ds nodes=%d objects=%d orphans=%d alive=%d" % [f / 60, Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
				director.alive_enemies().size()])
	Input.action_release("fire")
	rows.append(s.row("soak %.0f min" % minutes))


# --- helpers --------------------------------------------------------------------

## Keeps `count` enemies alive in an arc 9-15 m in front of the player.
func _fill_crowd(director, count: int, kinds: Array) -> void:
	var alive: Array = director.alive_enemies()
	if alive.size() >= count:
		return
	var game_data: Node = root.get_node("GameData")
	if kinds.is_empty():
		kinds = [game_data.enemy(&"tourist_shambler")]
	var scene: PackedScene = load(ZOMBIE_SCENE)
	var player = director.player
	var fwd: Vector3 = -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	for i in count - alive.size():
		var z = scene.instantiate()
		z.setup(kinds[randi() % kinds.size()], player, 1.0)
		var a := randf_range(-0.6, 0.6)
		var p: Vector3 = player.global_position + fwd.rotated(Vector3.UP, a) * randf_range(9.0, 15.0)
		z.position = p
		director._enemies_root.add_child(z)
		director._alive.append(z)
		z.died.connect(director._on_zombie_died)


func _aim_at_nearest(director) -> void:
	var player = director.player
	var best = null
	var best_d := INF
	for z in director.alive_enemies():
		if is_instance_valid(z) and not z.is_dead():
			var d: float = z.global_position.distance_squared_to(player.global_position)
			if d < best_d:
				best_d = d
				best = z
	if best == null:
		return
	var to: Vector3 = best.global_position + Vector3(0, 1.1, 0) - player.camera.global_position
	player.set_look(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))


# --- shader variants --------------------------------------------------------------

## A periodic sweep catches materials swapped onto existing nodes (hit flashes,
## status overlays, skins).
func _scan() -> void:
	_scan_tick += 1
	if not tracking or _scan_tick % 10 != 0 or current_scene == null:
		return
	for n in current_scene.find_children("*", "GeometryInstance3D", true, false):
		_note_geometry(n)


func _note_geometry(n) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree() or not n.is_visible_in_tree():
		return
	var kind: String = n.get_class()
	var mats: Array = []
	if n.material_override:
		mats.append(n.material_override)
	if n.material_overlay:
		mats.append(n.material_overlay)
	if n is MeshInstance3D:
		if n.skin != null or n.get_parent() is Skeleton3D:
			kind = "Skinned"
		if n.mesh and n.material_override == null:
			for i in n.mesh.get_surface_count():
				var m: Material = n.get_surface_override_material(i)
				mats.append(m if m else n.mesh.surface_get_material(i))
	elif n is MultiMeshInstance3D:
		if n.multimesh and n.multimesh.mesh and n.material_override == null:
			for i in n.multimesh.mesh.get_surface_count():
				mats.append(n.multimesh.mesh.surface_get_material(i))
	elif n is Label3D or n is SpriteBase3D:
		mats.append("%s|%d|%d|%s|%s" % [kind, n.billboard, n.alpha_cut, n.no_depth_test, n.shaded])
	for m in mats:
		var key := "%s|%s" % [kind, _material_key(m)]
		if _seen.has(key):
			continue
		_seen[key] = true
		if _warm_closed:
			_late.append("%s  [%s]  %s" % [key, _scenario, n.get_path()])


## Shader identity of a material: what decides which shader is compiled.
func _material_key(m) -> String:
	if m == null:
		return "default"
	if m is String:
		return m
	var id: int = m.get_instance_id()
	if _mat_keys.has(id):
		return _mat_keys[id]
	var key := ""
	if m is ShaderMaterial:
		var sh: Shader = m.shader
		key = "shader:" + (sh.resource_path if sh and sh.resource_path != "" else str(sh.get_instance_id()) if sh else "none")
	elif m is BaseMaterial3D:
		var bits := PackedStringArray()
		for p in m.get_property_list():
			var t: int = p["type"]
			var pname: String = p["name"]
			if not (p["usage"] & PROPERTY_USAGE_STORAGE) or pname == "render_priority" or pname.begins_with("resource_"):
				continue
			if t == TYPE_BOOL or t == TYPE_INT:
				bits.append("%s=%s" % [pname, m.get(pname)])
			elif t == TYPE_OBJECT and pname.ends_with("texture"):
				bits.append("%s=%s" % [pname, m.get(pname) != null])
		key = "std:" + str(hash(",".join(bits)))
	else:
		key = m.get_class()
	_mat_keys[id] = key
	return key


func _print_table() -> void:
	print("")
	print("[perf] %-34s %6s %8s %8s %8s %7s %7s %8s %5s %6s %7s %6s %8s" % ["scenario", "frames", "cpu avg", "cpu p95",
		"cpu max", "nodes", "+nodes", "objects", "orph", "new/s", "audio/s", "draws", "prims"])
	for r in rows:
		print("[perf] %-34s %6d %8.2f %8.2f %8.1f %7d %+7d %8d %5d %6.0f %7.1f %6s %8s" % r)
	if tracking:
		print("[perf] material variants seen: %d, first seen after the warm-up: %d" % [_seen.size(), _late.size()])
		for line in _late:
			print("[perf] late material: %s" % line)


## Per-scenario accumulator. Frame time is wall-clock between frames: in a
## headless run with --fixed-fps that is the CPU cost of the frame (scripts,
## physics, animation, audio mixing set-up), with no waiting for vsync.
class _Stats:
	var tree
	var times := PackedFloat32Array()
	var draws_sum := 0.0
	var prims_sum := 0.0
	var nodes0 := 0
	var created0 := 0
	var audio0 := 0
	var last := 0

	func _init(t) -> void:
		tree = t
		nodes0 = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		created0 = t._created
		audio0 = t._audio_created
		last = Time.get_ticks_usec()

	func sample() -> void:
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		draws_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims_sum += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)

	func row(name: String) -> Array:
		var n := maxi(times.size(), 1)
		var sorted := times.duplicate()
		sorted.sort()
		var total := 0.0
		for t in times:
			total += t
		var secs := n / 60.0
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		return [name, times.size(), total / n, sorted[int((n - 1) * 0.95)] if times.size() > 0 else 0.0,
			sorted[n - 1] if times.size() > 0 else 0.0, nodes, nodes - nodes0,
			int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			(tree._created - created0) / secs, (tree._audio_created - audio0) / secs,
			"%d" % (draws_sum / n) if tree.rendered else "-", "%d" % (prims_sum / n) if tree.rendered else "-"]
