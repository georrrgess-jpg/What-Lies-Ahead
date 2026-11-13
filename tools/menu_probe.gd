extends SceneTree
## Main-menu performance probe: drives the real menu through the startup
## screen, home idle, every page switch, the world carousel (every world, so
## every backdrop swap), a fast carousel scrub and the return from a run, and
## prints one row per scenario plus every hitch with what caused it.
##
##   Script time (headless, fast):
##     godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tools/menu_probe.gd -- [options]
##   With draw calls, primitives and render time (software renderer, slow):
##     xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . --fixed-fps 60 \
##         --resolution 960x540 --script res://tools/menu_probe.gd -- [options]
##
## Options:
##   --profile=<file>   profile to use (a copy; one with every world open shows all ten backdrops)
##   --only=a,b,...     scenarios (default all): startup, home, pages, carousel, scrub, return
##   --hitch=<ms>       frames slower than this are listed (default 33)
##
## Columns: frames; wall-clock ms per frame (avg, 95th percentile, worst); the
## worst frame's script time (Performance TIME_PROCESS) and render CPU time
## (the root viewport's measured render time, rendered runs only); node and
## object counts at the end and the node growth over the scenario; average
## draw calls and primitives per frame (rendered runs only).
##
## A hitch line names the action that preceded it (the page shown, the world
## selected), how many frames after it the hitch came, and the split between
## scripts, rendering and nodes created, which is how its cause is read:
##   +nodes in the hundreds = a scene instantiated on the main thread,
##   high script ms with few nodes = script work (layout, refresh, loads),
##   high render ms at normal draw counts = shader compiles / first draws.
##
## Script mode compiles this file before the autoloads exist, so game singletons
## are reached through root.get_node().

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const PAGES: Array[String] = ["play", "arsenal", "locker", "shop", "career", "settings", "title"]

var opts := {}
var rendered := false
var rows: Array = []
var hitches: Array = []
var world_rows: Array = []
var _event := "boot"
var _event_frame := 0
var _frame := 0
var _hitch_ms := 33.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
	rendered = DisplayServer.get_name() != "headless"
	_hitch_ms = float(_opt("hitch", "33"))
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	create_timer(float(_opt("timeout", "1500"))).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _opt(key: String, default_value: String) -> String:
	return String(opts.get(key, default_value))


func _wants(name: String) -> bool:
	return name in _opt("only", "startup,home,pages,carousel,scrub,return").split(",")


func _mark(event: String) -> void:
	_event = event
	_event_frame = _frame


## Adds a scenario row and prints it at once (slow rendered runs may time out).
func _add(r: Array) -> void:
	rows.append(r)
	print("[menu] row %-40s %6d %7.2f %7.2f %7.1f %7.1f %7.1f %6d %+6d %8d %6s %8s" % r)


## Frame counts shrink in rendered runs (software rendering is slow); --scale overrides.
func _n(frames: int) -> int:
	return maxi(8, int(frames * float(_opt("scale", "0.25" if rendered else "1"))))


func _menu() -> Node:
	return current_scene


# --- the run --------------------------------------------------------------------

func _run() -> void:
	await process_frame
	print("[menu] rendered=%s" % rendered)
	var s := _Stats.new(self)
	_mark("open main menu")
	root.get_node("Game").intro_played = false
	change_scene_to_file(MENU_SCENE)
	for i in 30:
		await _tick(s)
	_add(s.row("menu open (first 30 frames)"))
	if _wants("startup"):
		await _startup()
	else:
		_close_intro()
	if _wants("home"):
		_mark("home idle")
		await _measure("home idle", _n(300))
	if _wants("pages"):
		await _pages()
	if _wants("carousel"):
		await _carousel()
	if _wants("scrub"):
		await _scrub()
	if _wants("return"):
		await _return_from_run()
	_print()
	quit(0)


## One frame, sampled.
func _tick(s: _Stats) -> void:
	await process_frame
	_frame += 1
	s.sample()


func _measure(name: String, frames: int) -> void:
	var s := _Stats.new(self)
	for i in frames:
		await _tick(s)
	_add(s.row(name))


# --- scenarios ------------------------------------------------------------------

## The intro plays over the menu (headless menus skip it, so it is added here).
func _startup() -> void:
	var intro := _intro()
	if intro == null:
		intro = load("res://scripts/ui/intro_overlay.gd").new()
		_menu().add_child(intro)
		intro.finished.connect(_menu()._on_intro_finished)
	_mark("startup screen")
	await _measure("startup screen (7.5 s)", 450)
	_mark("startup screen: close")
	intro.close()
	await _measure("startup close + home deal-in", 60)


func _intro() -> Node:
	for c in _menu().get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("intro_overlay.gd"):
			return c
	return null


func _close_intro() -> void:
	var intro := _intro()
	if intro:
		intro.close()


func _pages() -> void:
	var s := _Stats.new(self)
	for visit in 2:
		await _visit_pages(s, "first" if visit == 0 else "again")
	_add(s.row("page switches (all)"))


## Shows every page once, one row per page.
func _visit_pages(s: _Stats, visit: String) -> void:
	for id in PAGES:
		_mark("show %s (%s)" % [id, visit])
		var t0 := Time.get_ticks_usec()
		_menu()._show(id)
		var call_ms := (Time.get_ticks_usec() - t0) / 1000.0
		var ps := _Stats.new(self)
		for i in _n(45):
			await _tick(ps)
			s.times.append(ps.times[ps.times.size() - 1])
		_add(ps.row("  %s: %s (call %.1f ms)" % [visit, id, call_ms]))


## Every world in turn: waits for its backdrop to be on screen, then settles.
func _carousel() -> void:
	var menu := _menu()
	menu._show("play")
	for i in 30:
		await process_frame
	var play: Node = menu.page("play")
	var backdrop: Node = menu._backdrop
	var worlds: Array = root.get_node("GameData").worlds()
	var s := _Stats.new(self)
	for n in worlds.size():
		var t0 := Time.get_ticks_usec()
		play.step_world(1)
		var call_ms := (Time.get_ticks_usec() - t0) / 1000.0
		var level = play.selected_level
		_mark("world %s" % level.id)
		var ws := _Stats.new(self)
		var since := Time.get_ticks_msec()
		while backdrop.current != level and Time.get_ticks_msec() - since < 20000:
			await _tick(ws)
		var shown_ms := float(Time.get_ticks_msec() - since)
		# Let the fade-in finish, then sample the settled view.
		for i in _n(50):
			await _tick(ws)
		var settled := _Stats.new(self)
		for i in _n(40):
			await _tick(settled)
		s.times.append_array(ws.times)
		s.times.append_array(settled.times)
		var w := [String(level.id), call_ms, ws.times.size(), shown_ms, ws.worst(), settled.avg(),
			settled.draws(), settled.prims(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]
		world_rows.append(w)
		print("[menu] world %-16s %8.1f %8d %7.0fms %8.1f %8.2f %6s %8s %6d" % w)
	_add(s.row("carousel: all %d worlds" % worlds.size()))


## A player flicking through the carousel: a step every 8 frames, twice round.
func _scrub() -> void:
	var play: Node = _menu().page("play")
	_menu()._show("play")
	var s := _Stats.new(self)
	var steps: int = root.get_node("GameData").worlds().size() * 2
	for n in steps:
		play.step_world(1)
		_mark("scrub to %s" % play.selected_level.id)
		for i in 8:
			await _tick(s)
	_mark("scrub settle")
	for i in 240:
		await _tick(s)
	_add(s.row("carousel scrub (%d steps)" % steps))


## Into a level and back, the way the results screen's Main Menu goes.
func _return_from_run() -> void:
	var game: Node = root.get_node("Game")
	game.level = root.get_node("GameData").level(&"prize_pier")
	change_scene_to_file(game.level.scene_path)
	for i in 120:
		await process_frame
	_mark("return to menu")
	var s := _Stats.new(self)
	game.to_menu()
	for i in _n(180):
		await _tick(s)
	_add(s.row("return from a run (3 s)"))


# --- output ---------------------------------------------------------------------

func _print() -> void:
	print("")
	print("[menu] %-40s %6s %7s %7s %7s %7s %7s %6s %6s %8s %6s %8s" % ["scenario", "frames", "avg", "p95", "worst",
		"w.scr", "w.rnd", "nodes", "+nodes", "objects", "draws", "prims"])
	for r in rows:
		print("[menu] %-40s %6d %7.2f %7.2f %7.1f %7.1f %7.1f %6d %+6d %8d %6s %8s" % r)
	if not world_rows.is_empty():
		print("")
		print("[menu] %-16s %8s %8s %9s %8s %8s %6s %8s %6s" % ["world", "call ms", "frames", "to shown", "worst", "settled", "draws", "prims", "nodes"])
		for w in world_rows:
			print("[menu] %-16s %8.1f %8d %7.0fms %8.1f %8.2f %6s %8s %6d" % w)
	print("")
	print("[menu] hitches > %.0f ms: %d" % [_hitch_ms, hitches.size()])
	for h in hitches:
		print("[menu] hitch %s" % h)


## Per-scenario accumulator (wall-clock between frames; in a headless run with
## --fixed-fps that is the CPU cost of the frame, with no wait for vsync).
class _Stats:
	var tree
	var times := PackedFloat32Array()
	var draws_sum := 0.0
	var prims_sum := 0.0
	var nodes0 := 0
	var last := 0
	var worst_script := 0.0
	var worst_render := 0.0
	var worst_ms := 0.0
	var nodes_last := 0

	func _init(t) -> void:
		tree = t
		nodes0 = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		nodes_last = nodes0
		last = Time.get_ticks_usec()

	func sample() -> void:
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		times.append(ms)
		var script_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var render_ms: float = RenderingServer.viewport_get_measured_render_time_cpu(tree.root.get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu()
		var draws: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		draws_sum += draws
		prims_sum += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if ms > worst_ms:
			worst_ms = ms
			worst_script = script_ms
			worst_render = render_ms
		if ms > tree._hitch_ms:
			var h := "%6.1f ms  [%s +%d f]  script %.1f  render %.1f  nodes %+d  draws %d" % [ms, tree._event,
				tree._frame - tree._event_frame, script_ms, render_ms, nodes - nodes_last, draws]
			tree.hitches.append(h)
			if tree.rendered:
				print("[menu] hitch %s" % h)
		nodes_last = nodes

	func avg() -> float:
		var total := 0.0
		for t in times:
			total += t
		return total / maxi(times.size(), 1)

	func worst() -> float:
		var w := 0.0
		for t in times:
			w = maxf(w, t)
		return w

	func draws() -> String:
		return "%d" % (draws_sum / maxi(times.size(), 1)) if tree.rendered else "-"

	func prims() -> String:
		return "%d" % (prims_sum / maxi(times.size(), 1)) if tree.rendered else "-"

	func row(name: String) -> Array:
		var n := maxi(times.size(), 1)
		var sorted := times.duplicate()
		sorted.sort()
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		return [name, times.size(), avg(), sorted[int((n - 1) * 0.95)] if times.size() > 0 else 0.0, worst(),
			worst_script, worst_render, nodes, nodes - nodes0, int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			draws(), prims()]
