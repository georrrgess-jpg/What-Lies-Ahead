extends Node
## Developer driver for automated playtests and screenshots. Only created when
## the game is launched with one of these user arguments (after `--`):
##
##   --autoplay=clear     play a full run with a bot and step through the portal
##   --autoplay=defeat    start a run and let the zombies win
##   --weapon=<id>        starter weapon for the bot (default: pulse_pistol)
##   --swap               bot switches weapon at the kiosk every break
##   --aim-error=<deg>    random aim error for the bot (default 1.2)
##   --god                bot takes no damage (for flow tests, not for tuning)
##   --then=retry|menu    after the results screen, press Retry / Main Menu once
##   --max-seconds=<n>    give up after n simulated seconds (default 1500)
##   --shot=<file.png>    stage the reference composition and save a screenshot
##
## The bot plays through the real input pipeline (InputEventAction), so the
## same code paths run as for a human player.

enum Mode { NONE, CLEAR, DEFEAT, SHOT }

var mode := Mode.NONE
var weapon := &"pulse_pistol"
var swap_each_break := false
var aim_error := 1.2
var god := false
var then := ""
var max_seconds := 1500.0
var shot_path := ""
var shot_args := {}

var _director: RunDirector
var _player: Player
var _clock := 0.0
var _started_level := false
var _held := {}
var _fire_down := false
var _ring_index := 0
var _break_timer := 0.0
var _break_done := false
var _path: PackedVector3Array
var _path_index := 0
var _repath := 0.0
var _result_logged := false
var _runs := 0
var _then_done := false
var _aim_offset := Vector2.ZERO
var _aim_timer := 0.0
var _log_timer := 0.0
var _min_health := 100.0
var _frame_times: Array[float] = []
var _stuck_time := 0.0
var _last_pos := Vector3.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg == "--autoplay=clear":
			mode = Mode.CLEAR
		elif arg == "--autoplay=defeat":
			mode = Mode.DEFEAT
		elif arg.begins_with("--weapon="):
			weapon = StringName(arg.trim_prefix("--weapon="))
		elif arg == "--swap":
			swap_each_break = true
		elif arg.begins_with("--aim-error="):
			aim_error = float(arg.trim_prefix("--aim-error="))
		elif arg == "--god":
			god = true
		elif arg.begins_with("--then="):
			then = arg.trim_prefix("--then=")
		elif arg.begins_with("--max-seconds="):
			max_seconds = float(arg.trim_prefix("--max-seconds="))
		elif arg.begins_with("--shot="):
			mode = Mode.SHOT
			shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shot-"):
			var kv := arg.trim_prefix("--shot-").split("=")
			if kv.size() == 2:
				shot_args[kv[0]] = kv[1]
	print("[dev] mode=%s weapon=%s swap=%s god=%s" % [Mode.keys()[mode], weapon, swap_each_break, god])
	if mode == Mode.SHOT:
		var shot = load("res://scripts/dev/screenshot.gd").new()
		shot.name = "Screenshot"
		shot.path = shot_path
		shot.args = shot_args
		add_child(shot)
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if mode == Mode.NONE or mode == Mode.SHOT:
		return
	_clock += delta
	if _clock > max_seconds:
		print("[dev] TIMEOUT after %.0fs" % _clock)
		_quit(2)
		return

	var scene := get_tree().current_scene
	if scene == null:
		return

	# Menu -> run, through the same calls the buttons make.
	if scene.name == "MainMenu":
		if not _started_level and _clock > 0.5:
			_started_level = true
			print("[dev] menu loaded; starting level via Play page")
			scene._show("play")
			scene._select_weapon(weapon)
			scene._start()
		elif _then_done and _clock > 1.0:
			print("[dev] back at main menu after results: OK")
			_quit(0)
		return

	_director = get_tree().get_first_node_in_group("run_director") as RunDirector
	if _director == null or _director.player == null:
		return
	if _player != _director.player:
		_player = _director.player
		_runs += 1
		_result_logged = false
		_break_done = false
		_ring_index = 0
		_min_health = 100.0
		print("[dev] run %d started: state=%s tickets=%d wave=%d health=%d weapon=%s mag=%d" % [
			_runs, RunDirector.State.keys()[_director.state], _director.tickets, _director.wave_number,
			int(_player.health), _player.weapons.current.id, _player.weapons.magazine()])
		if _runs > 1 and then == "retry":
			# Retry must have produced a clean run.
			var clean := _director.tickets == 0 and _director.wave_number == 0 and _player.health == _player.max_health
			print("[dev] retry reset check: %s" % ("OK" if clean else "FAILED"))
			_quit(0 if clean else 1)
			return

	if god and _player.health < _player.max_health and _player.alive:
		_player.health = _player.max_health
	_min_health = minf(_min_health, _player.health)

	_log_timer -= delta
	if _log_timer <= 0.0:
		_log_timer = 15.0
		print("[dev] t=%4.0fs state=%-10s wave=%d left=%d hp=%3d tickets=%d %s %d/%d fps=%.0f" % [
			_clock, RunDirector.State.keys()[_director.state], _director.wave_number, _director.enemies_remaining(),
			int(_player.health), _director.tickets, _player.weapons.current.id,
			_player.weapons.magazine(), _player.weapons.reserve(), Engine.get_frames_per_second()])

	match _director.state:
		RunDirector.State.PREP, RunDirector.State.BREAK:
			_do_break(delta)
		RunDirector.State.WAVE:
			_break_done = false
			_break_timer = 0.0
			if mode == Mode.DEFEAT:
				_stop_moving()
				_release("fire")
			else:
				_do_fight(delta)
		RunDirector.State.EXTRACTION:
			_release("fire")
			_walk_to(_director.portal.global_position + _director.portal.global_transform.basis.z * 0.4, delta, true)
		RunDirector.State.CLEARED, RunDirector.State.DEFEAT:
			_stop_moving()
			_release("fire")
			_after_run()


# --- intermission ----------------------------------------------------------------

func _do_break(delta: float) -> void:
	_release("fire")
	if mode == Mode.DEFEAT:
		_stop_moving()
		_tap("start_wave")
		return
	var kiosk := _director.kiosk
	if kiosk == null or not kiosk.player_inside:
		var target := kiosk.global_position if kiosk else _player.global_position
		var from_kiosk := (_player.global_position - target)
		from_kiosk.y = 0.0
		_walk_to(target + from_kiosk.normalized() * 6.5, delta, true)
		return
	_stop_moving()
	_break_timer += delta
	if _break_done:
		if _break_timer > 4.0:
			_tap("start_wave")
		return
	if _break_timer < 0.6:
		return
	_break_done = true
	var before := [_director.tickets, _player.weapons.magazine(), _player.weapons.reserve(), int(_player.health)]
	if swap_each_break:
		var list := GameData.weapons()
		var next := (list.find(_player.weapons.current) + 1) % list.size()
		_tap("weapon_%d" % (next + 1))
		await get_tree().physics_frame
		await get_tree().physics_frame
	if _player.health <= 70.0:
		_tap("interact_alt")
		await get_tree().physics_frame
		await get_tree().physics_frame
	var w := _player.weapons
	if not w.is_ammo_full() and (w.reserve() < w.current.reserve_max * 0.7 or _director.tickets >= 300):
		_tap("interact")
		await get_tree().physics_frame
		await get_tree().physics_frame
	print("[dev] kiosk: tickets %d->%d  %s %d/%d (was %d/%d)  hp %d->%d" % [
		before[0], _director.tickets, w.current.id, w.magazine(), w.reserve(), before[1], before[2],
		before[3], int(_player.health)])


# --- combat ----------------------------------------------------------------------

func _do_fight(delta: float) -> void:
	var target := _pick_target()
	var w := _player.weapons
	# Keep moving around the loop: kiosk on one side, entrances on the other.
	var ring := _ring_points()
	var goal: Vector3 = ring[_ring_index % ring.size()]
	if _player.global_position.distance_to(goal) < 3.0:
		_ring_index += 1
	var nearest := _nearest_distance()
	var should_move := nearest < 9.0 or target == null
	if should_move:
		_walk_to(goal, delta, target == null)
	else:
		_stop_moving()

	if target == null:
		_release("fire")
		return

	# Aim with a slowly wandering error, like a human hand.
	_aim_timer -= delta
	if _aim_timer <= 0.0:
		_aim_timer = 0.25
		_aim_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * deg_to_rad(aim_error)
	var aim_point := target.global_position + Vector3(0, 1.0 * target.data.body_scale, 0)
	var eye := _player.camera.global_position
	var to := aim_point - eye
	var yaw := atan2(-to.x, -to.z) + _aim_offset.x
	var pitch := atan2(to.y, Vector2(to.x, to.z).length()) + _aim_offset.y
	var cur_yaw := _player.rotation.y
	var cur_pitch := _player.look_pitch()
	var turn := 1.0 - exp(-14.0 * delta)
	_player.set_look(lerp_angle(cur_yaw, yaw, turn), lerpf(cur_pitch, pitch, turn))

	var aligned := absf(angle_difference(_player.rotation.y, yaw)) < deg_to_rad(4.0)
	var dist := to.length()
	var in_range := dist < (10.0 if w.current.pellets > 1 else 26.0)
	if aligned and in_range and not w.is_reloading():
		if w.current.automatic:
			_press("fire")
		else:
			# Semi-auto: click, release, click...
			_fire_down = not _fire_down
			if _fire_down:
				_press("fire")
			else:
				_release("fire")
	else:
		_release("fire")
	if w.magazine() == 0 and w.reserve() > 0 and not w.is_reloading():
		_tap("reload")


func _pick_target() -> Zombie:
	var best: Zombie = null
	var best_d := INF
	var eye := _player.camera.global_position
	var space := _player.get_world_3d().direct_space_state
	for z in _director.alive_enemies():
		if not is_instance_valid(z) or z.is_dead():
			continue
		var chest := z.global_position + Vector3(0, 1.0, 0)
		var d := eye.distance_to(chest)
		if d >= best_d:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, chest, 1)
		if not space.intersect_ray(q).is_empty():
			continue
		best = z
		best_d = d
	return best


func _nearest_distance() -> float:
	var best := INF
	for z in _director.alive_enemies():
		if is_instance_valid(z) and not z.is_dead():
			best = minf(best, z.global_position.distance_to(_player.global_position))
	return best


## Waypoints circling the kiosk: the ride-side midway and the rail-side stretch.
func _ring_points() -> Array:
	return [
		Vector3(9.5, 0, 9.0), Vector3(9.5, 0, -2.0), Vector3(8.0, 0, -12.0), Vector3(-2.0, 0, -15.0),
		Vector3(-11.0, 0, -6.0), Vector3(-13.0, 0, 3.0), Vector3(-7.0, 0, 13.0), Vector3(2.0, 0, 15.0),
	]


# --- movement --------------------------------------------------------------------

func _walk_to(goal: Vector3, delta: float, face_path: bool) -> void:
	_repath -= delta
	if _repath <= 0.0 or _path.is_empty():
		_repath = 0.5
		var map := _player.get_world_3d().navigation_map
		_path = NavigationServer3D.map_get_path(map, _player.global_position, goal, true)
		_path_index = 0
	while _path_index < _path.size() - 1 and _flat(_path[_path_index] - _player.global_position).length() < 0.8:
		_path_index += 1
	var next := goal if _path.is_empty() else _path[mini(_path_index, _path.size() - 1)]
	var dir := _flat(next - _player.global_position)
	if dir.length() < 0.25:
		_stop_moving()
		return
	dir = dir.normalized()
	if face_path:
		var yaw := atan2(-dir.x, -dir.z)
		_player.set_look(lerp_angle(_player.rotation.y, yaw, 1.0 - exp(-10.0 * delta)), lerpf(_player.look_pitch(), 0.0, 0.1))
	# Convert the world direction into WASD relative to where the player faces.
	var local := _player.global_transform.basis.inverse() * dir
	_set_axis("move_forward", "move_back", -local.z)
	_set_axis("move_right", "move_left", local.x)
	_set_held("sprint", face_path and local.z < -0.7)

	# Unstick: if we are not getting anywhere, re-plan from scratch.
	_stuck_time += delta
	if _stuck_time > 2.0:
		if _player.global_position.distance_to(_last_pos) < 0.5:
			_path = PackedVector3Array()
			_ring_index += 1
		_last_pos = _player.global_position
		_stuck_time = 0.0


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _stop_moving() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint"]:
		_set_held(a, false)


func _set_axis(positive: String, negative: String, value: float) -> void:
	_set_held(positive, value > 0.3)
	_set_held(negative, value < -0.3)


# --- input plumbing --------------------------------------------------------------

func _set_held(action: String, down: bool) -> void:
	if bool(_held.get(action, false)) == down:
		return
	_held[action] = down
	var e := InputEventAction.new()
	e.action = action
	e.pressed = down
	Input.parse_input_event(e)


func _press(action: String) -> void:
	_set_held(action, true)


func _release(action: String) -> void:
	_set_held(action, false)


func _tap(action: String) -> void:
	_set_held(action, false)
	_set_held(action, true)
	get_tree().create_timer(0.05, true, true).timeout.connect(func(): _set_held(action, false))


# --- results ---------------------------------------------------------------------

func _after_run() -> void:
	if not _result_logged:
		_result_logged = true
		var r := _director.result()
		var rows := []
		for row in r["weapons"]:
			var unlocks := []
			for u in row["unlocks"]:
				unlocks.append(String(u.id))
			rows.append("%s +%dxp %dkills rank %d->%d unlocks=%s" % [row["weapon"].id, row["xp_gained"], row["kills"], row["rank_before"], row["rank_after"], unlocks])
		print("[dev] RESULT victory=%s waves=%d/%d kills=%d time=%.0fs min_hp=%d tickets_left=%d" % [
			r["victory"], r["waves_cleared"], r["total_waves"], r["kills"], r["seconds"], int(_min_health), _director.tickets])
		for line in rows:
			print("[dev]   ", line)
		print("[dev] profile: ", JSON.stringify(Profile.data["mastery"]), " levels=", JSON.stringify(Profile.data["levels"]))
		_wait_for_results()


func _wait_for_results() -> void:
	# The results screen appears after a short beat.
	var waited := 0.0
	var screen: Node = null
	while waited < 6.0 and screen == null:
		await get_tree().create_timer(0.25, true, false, true).timeout
		waited += 0.25
		var scene := get_tree().current_scene
		if scene:
			screen = scene.get_node_or_null("Results")
	print("[dev] results screen shown: %s  mouse_mode=%d paused=%s" % [screen != null, Input.mouse_mode, get_tree().paused])
	if screen == null:
		_quit(1)
		return
	if then == "retry":
		_then_done = true
		print("[dev] pressing Retry")
		Game.retry()
	elif then == "menu":
		_then_done = true
		_clock = 0.0
		print("[dev] pressing Main Menu")
		Game.to_menu()
	else:
		_quit(0)


func _quit(code: int) -> void:
	set_physics_process(false)
	for a in _held.keys():
		_set_held(a, false)
	print("[dev] exit code %d" % code)
	get_tree().quit(code)
