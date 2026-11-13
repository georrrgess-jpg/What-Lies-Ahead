extends SceneTree
## Movement probe (developer): what one physics tick of the player's movement
## costs, and the movement numbers, with the real player in a real level (the
## waves held, no zombies).
##
##   godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tools/move_probe.gd -- \
##       [--level=prize_pier] [--profile=<file>] [--repeat=3]
##   Frame sequences of the moves instead (needs a renderer):
##     xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . --fixed-fps 60 \
##         --resolution 960x540 --script res://tools/move_probe.gd -- --frames=<dir>
##     saves <dir>/<move>_<tick>.png for a slide, a dash to the right, a mantle
##     onto the planter, a landing roll and a mantle at the signpost planter
##     (its arrows are fenced off); with --level=boot_camp, the crate mantle,
##     the barrier vault and the slide under the low sign, every other tick.
##
## Each scenario drives the player with InputMap actions and calls its
## _physics_process itself (the body's own physics processing is off), timing
## every call. Prints one row per scenario: ticks, mean / median / 95th
## percentile / worst microseconds per tick. Then the numbers: jump height,
## sprint, slide and dash speeds and distances, mantle and vault times, and a
## rail check (dashing, sliding and jumping at the ocean rail must never get
## past it).
##
## Positions are Prize Pier's (open deck, the ocean rail at x = 14, a planter).
## Script mode compiles this file before the autoloads exist, so game classes
## are reached untyped.

const TICK := 1.0 / 60.0
const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump", "slide", "dash"]
## Open deck west of the carousel: a clear run of about 9 m toward -Z.
const OPEN := Vector3(-14.0, 0.1, 2.0)
## Beside the ocean rail (x = 14), facing along it.
const RAIL_SIDE := Vector3(13.4, 0.1, 2.0)
## In front of a 1 m planter (Planter0, centre (-12.5, 0, 10.5)), clear of
## its palm, facing it.
const PLANTER := Vector3(-11.6, 0.1, 13.0)
## Boot Camp's movement lane (x -4.5..4.5, run toward -Z): a 1.2 m crate
## stack at z -38, a 1 m barrier at z -45, a low sign at z -52.5.
const CAMP_CRATE := Vector3(1.0, 0.1, -32.0)
const CAMP_BARRIER := Vector3(1.0, 0.1, -38.0)
const CAMP_SIGN := Vector3(1.0, 0.1, -45.0)
const RAIL_X := 14.0

var opts := {}
var player
var rows: Array = []
var numbers: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
	create_timer(float(_opt("timeout", "600"))).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _opt(key: String, default_value: String) -> String:
	return String(opts.get(key, default_value))


func _run() -> void:
	var game: Node = root.get_node("Game")
	var id := StringName(_opt("level", "prize_pier"))
	game.level = root.get_node("GameData").level(id)
	if game.level == null:
		game.level = load("res://data/tutorial/%s.tres" % id)
	game.weapon_id = &"pulse_pistol"
	change_scene_to_file(game.level.scene_path)
	var director = null
	while director == null or director.player == null:
		await process_frame
		director = get_first_node_in_group("run_director")
	for i in 60:
		await process_frame
	director.set_process(false)
	director._set_state(1)
	player = director.player
	player.invulnerable = true
	player.controls_enabled = true
	player.set_physics_process(false)
	print("[move] level %s, dash action: %s" % [_opt("level", "prize_pier"), InputMap.has_action("dash")])
	if _opt("frames", "") != "":
		await _film(_opt("frames", ""))
		quit(0)
		return
	for r in int(_opt("repeat", "3")):
		rows.clear()
		await _scenarios()
		_print_rows()
	await _parts()
	for n in numbers:
		print("[move] %s" % n)
	quit(0)


# --- driving the player ---------------------------------------------------------

func _hold(actions: Array) -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a):
			continue
		if actions.has(a):
			Input.action_press(a)
		else:
			Input.action_release(a)


func _place(at: Vector3, yaw_degrees: float) -> void:
	_hold([])
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.set_look(deg_to_rad(yaw_degrees), 0.0)
	for i in 20:
		await _step([])


## Places the player and waits out every cooldown (dash, slide boost).
func _rest(at: Vector3) -> void:
	await _place(at, 0.0)
	for i in 120:
		await _step([])


## One physics tick of the player with `held` actions down (pressed inside the
## physics frame, so a new press reads as just pressed), timed into `samples`
## when given.
func _step(held: Array, samples = null) -> void:
	await physics_frame
	_hold(held)
	var t0 := Time.get_ticks_usec()
	player._physics_process(TICK)
	if samples != null:
		samples.append(Time.get_ticks_usec() - t0)


## Runs `ticks` ticks; `step.call(i)` sets the inputs before each.
func _measure(name: String, at: Vector3, yaw: float, ticks: int, step: Callable, reset_every := 0) -> void:
	await _place(at, yaw)
	var samples: Array = []
	for i in ticks:
		if reset_every > 0 and i > 0 and i % reset_every == 0:
			player.global_position = at
			player.velocity = Vector3.ZERO
		await _step(step.call(i), samples)
	samples.sort()
	var total := 0
	for s in samples:
		total += s
	rows.append([name, ticks, float(total) / ticks, samples[ticks / 2], samples[int(ticks * 0.95)], samples[-1]])
	_hold([])


func _scenarios() -> void:
	await _measure("stand", OPEN, 0.0, 240, func(_i): return [])
	await _measure("walk", OPEN, 0.0, 360, func(_i): return ["move_forward"], 90)
	await _measure("sprint", OPEN, 0.0, 360, func(_i): return ["move_forward", "sprint"], 60)
	await _measure("sprint + jumps", OPEN, 0.0, 360, func(i): return ["move_forward", "sprint"] + (["jump"] if i % 40 < 3 else []), 60)
	await _measure("slide chain", OPEN, 0.0, 360, func(i): return ["move_forward", "sprint"] + (["slide"] if i % 60 == 30 else []), 60)
	await _measure("strafe hug rail", RAIL_SIDE, 0.0, 360, func(_i): return ["move_forward", "move_right", "sprint"], 60)
	await _measure("jumps at rail", RAIL_SIDE + Vector3(-1.5, 0, 0), -90.0, 360, func(i): return ["move_forward", "sprint"] + (["jump"] if i % 30 < 3 else []), 90)
	await _measure("mantle planter", PLANTER, 0.0, 360, func(i): return ["move_forward"] + (["jump"] if i % 90 == 30 else []), 90)
	if InputMap.has_action("dash"):
		await _measure("dash strafes", OPEN, 0.0, 360, func(i): return ["move_left" if i % 120 < 60 else "move_right"] + (["dash"] if i % 60 == 10 else []), 60)
	if numbers.is_empty():
		await _numbers()


func _print_rows() -> void:
	print("[move] %-18s %5s %8s %8s %8s %8s" % ["scenario", "ticks", "mean_us", "p50_us", "p95_us", "max_us"])
	for r in rows:
		print("[move] %-18s %5d %8.1f %8d %8d %8d" % r)


# --- frame sequences --------------------------------------------------------------

func _film(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	if _opt("level", "prize_pier") == "boot_camp":
		await _film_course(dir)
		return
	await _rest(OPEN)
	await _shoot(dir, "slide", 40, [16, 20, 26, 36], func(i): return ["move_forward", "sprint"] + (["slide"] if i == 14 else []))
	await _rest(OPEN + Vector3(-3, 0, 0))
	await _shoot(dir, "dash", 24, [2, 4, 7, 18], func(i): return ["move_right"] + (["dash"] if i == 1 else []))
	await _place(PLANTER, 0.0)
	await _shoot(dir, "mantle", 40, [13, 17, 21, 26], func(i): return ["move_forward"] + (["jump"] if i >= 10 and i < 13 else []))
	# A long drop: off the planter's back edge is too short, so lift the player.
	await _place(OPEN, 0.0)
	player.global_position = OPEN + Vector3.UP * 4.0
	await _shoot(dir, "drop", 44, [24, 31, 34, 40], func(_i): return ["move_left"])
	await _place(Vector3(0.6, 0.1, 15.5), 0.0)
	await _shoot(dir, "signpost", 40, range(10, 40, 3), func(i): return ["move_forward"] + (["jump"] if i % 10 < 3 else []))


## Boot Camp: the crate mantle, the barrier vault at a sprint and the slide
## under the low sign, a frame every other tick.
func _film_course(dir: String) -> void:
	await _place(CAMP_CRATE, 0.0)
	await _shoot(dir, "crate", 70, range(44, 70, 2), func(i): return ["move_forward"] + (["jump"] if i % 12 < 3 else []))
	await _place(CAMP_BARRIER, 0.0)
	await _shoot(dir, "barrier", 70, range(46, 70, 2), func(i): return ["move_forward", "sprint"] + (["jump"] if i % 12 < 3 else []))
	await _rest(CAMP_SIGN)
	await _shoot(dir, "lowsign", 60, range(10, 60, 2), func(i): return ["move_forward", "sprint"] + (["slide"] if i == 12 else []))


## Runs `ticks` ticks with `step.call(i)` held, saving the frame after each tick in `at`.
func _shoot(dir: String, name: String, ticks: int, at: Array, step: Callable) -> void:
	for i in ticks:
		var was_floor: bool = player.is_on_floor()
		var was_moving: bool = player.is_traversing()
		await _step(step.call(i))
		if player.is_on_floor() != was_floor:
			print("[move] %s: %s at tick %d" % [name, "landed" if was_floor == false else "left the floor", i])
		if player.is_traversing() and not was_moving:
			print("[move] %s: %s at tick %d" % [name, "vault" if player.traversal_is_vault() else "mantle", i])
		if at.has(i):
			await RenderingServer.frame_post_draw
			var file := "%s/%s_%02d.png" % [dir, name, i]
			root.get_texture().get_image().save_png(file)
			print("[move] saved %s" % file)
	_hold([])


# --- the parts ------------------------------------------------------------------

## The costliest pieces on their own, against the ocean rail (best of five
## batches, so other load on the machine matters less): the ledge check a
## jump makes every airborne tick, and the step-up check every running tick.
func _parts() -> void:
	await _place(Vector3(13.43, 0.1, 2.0), -90.0)
	var feet: Vector3 = player.global_position
	var into: Vector3 = -player.global_basis.z
	var along: Vector3 = (into + Vector3.FORWARD).normalized() * 7.6 * TICK
	await physics_frame
	print("[move] part                         us/call")
	_part("ledge check, rising at rail", func():
		player.global_position = feet + Vector3.UP * 0.2
		player.velocity = Vector3(0.0, 7.0, 0.0)
		player._coyote = 0.0
		player._try_traversal(Vector2(0.0, -1.0), into, false))
	_part("ledge check, falling at rail", func():
		player.global_position = feet + Vector3.UP * 0.6
		player.velocity = Vector3(0.0, -3.0, 0.0)
		player._coyote = 0.0
		player._try_traversal(Vector2(0.0, -1.0), into, false))
	_part("step-up check, along rail", func():
		player.global_position = feet
		player._traverse.step_up(along))
	_part("step-up check, open deck", func():
		player.global_position = OPEN
		player._traverse.step_up(Vector3.FORWARD * 7.6 * TICK))
	player.global_position = OPEN
	player.velocity = Vector3.ZERO


func _part(name: String, call: Callable) -> void:
	var best := INF
	for batch in 5:
		var t0 := Time.get_ticks_usec()
		for i in 400:
			call.call()
		best = minf(best, (Time.get_ticks_usec() - t0) / 400.0)
	print("[move] %-28s %8.2f" % [name, best])


# --- the numbers ----------------------------------------------------------------

func _numbers() -> void:
	# Jump height (a held jump, standing).
	await _place(OPEN, 0.0)
	var y0: float = player.global_position.y
	var top := y0
	for i in 70:
		await _step(["jump"] if i < 30 else [])
		top = maxf(top, player.global_position.y)
	numbers.append("jump height %.2f m" % (top - y0))
	# Sprint, then a rested slide: peak speed and the distance it covers.
	await _rest(OPEN)
	for i in 20:
		await _step(["move_forward", "sprint"])
	var sprint: float = player.horizontal_speed()
	var from: Vector3 = player.global_position
	var peak := 0.0
	var ticks := 0
	for i in 120:
		await _step(["move_forward", "sprint"] + (["slide"] if i == 0 else []))
		peak = maxf(peak, player.horizontal_speed())
		if player.sliding:
			ticks = i + 1
		elif i > 2:
			break
	numbers.append("sprint %.2f m/s; slide peak %.2f m/s, %.2f s, %.2f m" % [sprint, peak, ticks * TICK, Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length()])
	# A slide-jump straight out of a rested slide.
	await _rest(OPEN)
	for i in 20:
		await _step(["move_forward", "sprint"])
	var take_off := 0.0
	for i in 40:
		await _step(["move_forward", "sprint"] + (["slide"] if i == 0 else []) + (["jump"] if i >= 6 and i < 9 else []))
		if not player.is_on_floor():
			take_off = maxf(take_off, player.horizontal_speed())
	numbers.append("slide-jump: top air speed %.2f m/s" % take_off)
	if InputMap.has_action("dash"):
		await _dash_numbers()
	await _traversal_numbers()
	await _rail_check()


func _dash_numbers() -> void:
	var moved := []
	var peak := 0.0
	var moving := 0
	for dash in [false, true]:
		await _rest(OPEN + Vector3(-3, 0, 0))
		var from: Vector3 = player.global_position
		for i in 30:
			await _step(["move_right"] + (["dash"] if dash and i == 0 else []))
			peak = maxf(peak, player.horizontal_speed())
			if player.is_dashing():
				moving = i + 1
		moved.append(player.global_position.x - from.x)
	numbers.append("dash peak %.2f m/s, burst %.2f s; sideways in 0.5 s: %.2f m with a dash, %.2f m walking" % [peak, moving * TICK, moved[1], moved[0]])
	# The cooldown: press every tick and count the dashes in 6 s.
	await _place(OPEN, 0.0)
	var count := 0
	var was := false
	for i in 360:
		await _step(["dash"] if i % 2 == 0 else [])
		if player.is_dashing() and not was:
			count += 1
		was = player.is_dashing()
		if i % 60 == 59:
			player.global_position = OPEN
	numbers.append("dashes in 6 s of mashing: %d" % count)
	# Dash-jump take-off speed.
	await _rest(OPEN)
	var take_off := 0.0
	for i in 20:
		await _step(["move_forward", "sprint"] + (["dash"] if i == 0 else []) + (["jump"] if i >= 3 and i < 6 else []))
		if not player.is_on_floor():
			take_off = maxf(take_off, player.horizontal_speed())
	numbers.append("dash-jump: top air speed %.2f m/s" % take_off)


## Mantle onto the planter (walking) and a vault at a run if one is found.
func _traversal_numbers() -> void:
	await _place(PLANTER, 0.0)
	var start := -1
	var end := -1
	var top := 0.0
	for i in 120:
		await _step(["move_forward"] + (["jump"] if i % 15 < 3 else []))
		if player.is_traversing() and start < 0:
			start = i
		if start >= 0 and end < 0 and not player.is_traversing():
			end = i
			top = player.global_position.y
	numbers.append("mantle onto 1 m planter: %s, %.2f s, ends at y %.2f" % [start >= 0, (end - start) * TICK, top])


## Sprint, slide, slide-jump and dash at the ocean rail: x must stay below RAIL_X.
func _rail_check() -> void:
	var worst := -INF
	for attempt in 4:
		await _place(Vector3(10.0, 0.1, 5.0 - attempt * 2.0), -90.0)
		for i in 90:
			var held := ["move_forward", "sprint"]
			if attempt == 1 and i == 20:
				held.append("slide")
			if (attempt == 1 or attempt == 2) and i % 20 >= 2 and i % 20 < 5:
				held.append("jump")
			if attempt == 3 and i % 25 == 5:
				held.append("dash")
			if attempt == 2 and i == 15:
				held.append("dash")
			await _step(held)
			worst = maxf(worst, player.global_position.x)
	numbers.append("rail check: furthest x %.2f (rail at %.1f) -> %s" % [worst, RAIL_X, "BLOCKED" if worst < RAIL_X else "CROSSED"])
