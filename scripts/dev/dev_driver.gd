extends Node
## Developer driver for automated playtests and screenshots. Only created when
## the game is launched with one of these user arguments (after `--`):
##
##   --autoplay=clear     play a full run with a bot and step through the portal
##   --autoplay=defeat    start a run and let the zombies win
##   --autoplay=pause     exercise the pause menu: resume, restart, main menu
##   --autoplay=route     crowd test: do zombies use both lanes around the kiosk?
##   --weapon=<id>        starter weapon for the bot (default: pulse_pistol)
##   --level=<id>         level to play (default: the first one); locks are ignored
##   --ring=<m>           radius of the bot's patrol ring around the loadout station
##   --swap               bot swaps the held weapon at the kiosk every break
##   --switch             bot switches to its other slot whenever it starts a reload
##   --boost              bot buys the damage boost whenever it can afford it (before
##                        the overshield, which it always buys when it can)
##   --aim-error=<deg>    random aim error for the bot (default 1.2)
##   --ads                bot aims down sights whenever it stands and shoots
##   --sight=<id>         every weapon wears this sight for the session (data/cosmetics/sights)
##   --god                bot takes no damage (for flow tests, not for tuning)
##   --then=retry|menu|next   after the results screen, press Retry / Main Menu /
##                        Next World once
##   --max-seconds=<n>    give up after n simulated seconds (default 1500)
##   --shot=<file.png>    stage the reference composition and save a screenshot
##   --dump-profile       print the loaded profile and settings, then quit
##   --start-wave=<n>     jump straight to wave n (testing late waves)
##   --perf               print frame statistics every few seconds during waves
##
## The bot plays through the real input pipeline (InputEventAction), so the
## same code paths run as for a human player.

enum Mode { NONE, CLEAR, DEFEAT, SHOT, PAUSE, ROUTE }

var mode := Mode.NONE
var weapon := &"pulse_pistol"
var swap_each_break := false
var switch_on_reload := false
var buy_boost := false
var _switches := 0
var _switch_cancels := 0
var aim_error := 1.2
var use_ads := false
var _aimed_time := 0.0
var god := false
var then := ""
var max_seconds := 1500.0
var shot_path := ""
var shot_args := {}
var start_wave := 1
var level_id := &""
var ring_radius := 11.0
var perf := false
var _perf_timer := 0.0
var _perf_samples: Array = []

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
		elif arg == "--autoplay=pause":
			mode = Mode.PAUSE
		elif arg == "--autoplay=route":
			mode = Mode.ROUTE
		elif arg.begins_with("--level="):
			level_id = StringName(arg.trim_prefix("--level="))
		elif arg.begins_with("--ring="):
			ring_radius = float(arg.trim_prefix("--ring="))
		elif arg.begins_with("--weapon="):
			weapon = StringName(arg.trim_prefix("--weapon="))
		elif arg == "--swap":
			swap_each_break = true
		elif arg == "--switch":
			switch_on_reload = true
		elif arg == "--boost":
			buy_boost = true
		elif arg.begins_with("--aim-error="):
			aim_error = float(arg.trim_prefix("--aim-error="))
		elif arg == "--ads":
			use_ads = true
		elif arg.begins_with("--sight="):
			for w in GameData.weapons():
				WeaponSights.wear_for_session(w.id, StringName(arg.trim_prefix("--sight=")))
		elif arg == "--god":
			god = true
		elif arg.begins_with("--then="):
			then = arg.trim_prefix("--then=")
		elif arg.begins_with("--max-seconds="):
			max_seconds = float(arg.trim_prefix("--max-seconds="))
		elif arg.begins_with("--start-wave="):
			start_wave = int(arg.trim_prefix("--start-wave="))
		elif arg == "--perf":
			perf = true
		elif arg == "--dump-profile":
			print("[dev] PROFILE recovered_from_bad_save=%s data=%s" % [Profile.recovered_from_bad_save, JSON.stringify(Profile.data)])
			get_tree().quit.call_deferred()
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
			if level_id != &"":
				scene._selected_level = GameData.level(level_id)
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
		_director.enemy_recovered.connect(_on_enemy_recovered)
		_director.damage_boost_changed.connect(func(b: RunDirector.Boost):
			print("[dev] damage boost %s: damage x%.2f" % [RunDirector.Boost.keys()[b], _player.weapons.damage_multiplier]))
		if start_wave > 1 and _runs == 1:
			_director.wave_number = start_wave - 1
			_director.tickets = 400
		_result_logged = false
		_break_done = false
		_ring_index = 0
		_min_health = 100.0
		print("[dev] run %d started: state=%s tickets=%d wave=%d health=%d weapon=%s mag=%d" % [
			_runs, RunDirector.State.keys()[_director.state], _director.tickets, _director.wave_number,
			int(_player.health), _player.weapons.current.id, _player.weapons.magazine()])
		if _runs > 1 and then == "next":
			print("[dev] next world started: %s" % _director.level.id)
			_quit(0)
			return
		if _runs > 1 and then == "retry" and mode != Mode.PAUSE:
			# Retry must have produced a clean run.
			var clean := _director.tickets == _director.waves.starting_tickets and _director.wave_number == 0 \
				and _player.health == _player.max_health and _director.overshield == 0.0
			print("[dev] retry reset check: %s" % ("OK" if clean else "FAILED"))
			_quit(0 if clean else 1)
			return

	if mode == Mode.PAUSE:
		_pause_test()
		return
	if mode == Mode.ROUTE:
		_route_test(delta)
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

	if perf and _director.state == RunDirector.State.WAVE:
		_sample_perf(delta)

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


func _on_enemy_recovered(z: Zombie, removed: bool) -> void:
	print("[dev] STALL %s %s at %s state=%d player at %s dist=%.1f nav_finished=%s" % [
		"removed" if removed else "moved", z.data.id, z.global_position.snapped(Vector3.ONE * 0.1), z.state,
		_player.global_position.snapped(Vector3.ONE * 0.1), z.global_position.distance_to(_player.global_position),
		z.nav.is_navigation_finished()])


func _sample_perf(delta: float) -> void:
	_perf_timer -= delta
	if _perf_timer > 0.0:
		return
	_perf_timer = 3.0
	var sample := {
		"alive": _director.alive_enemies().size(),
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	}
	_perf_samples.append(sample)
	print("[perf] wave=%d alive=%2d fps=%5.1f process=%.2fms physics=%.2fms draws=%d prims=%d nodes=%d" % [
		_director.wave_number, sample["alive"], sample["fps"], sample["process_ms"], sample["physics_ms"],
		sample["draw_calls"], sample["primitives"], sample["nodes"]])


var _route_started := false
var _route_time := 0.0
var _route_zombies: Array = []
var _route_side := {}
var _route_arrival := {}
var _route_min_gap := INF


## Crowd test. The player stands still (invulnerable) south of the kiosk while
## a mixed group starts in a tight clump on the north side. Records which lane
## each zombie takes around the kiosk, how long it needs to arrive, and how
## close they pack, to show a crowd can pass itself and never plugs a lane.
func _route_test(delta: float) -> void:
	if not _route_started:
		_route_started = true
		_director.set_process(false)
		_player.global_position = Vector3(0.5, 0.1, 15.8)
		_player.set_look(0.0, 0.0)
		var scene: PackedScene = load(RunDirector.ZOMBIE_SCENE)
		for i in 16:
			var id := &"lifeguard_runner" if i % 4 == 3 else &"tourist_shambler"
			var z: Zombie = scene.instantiate()
			z.setup(GameData.enemy(id), _player, 1.0)
			z.position = Vector3(-2.6 + (i % 4) * 1.7, 0.1, -11.0 - (i / 4) * 1.5)
			_director._enemies_root.add_child(z)
			_route_zombies.append(z)
		print("[dev] route test: 16 zombies clumped north of the kiosk, player south")
		return
	_route_time += delta
	_player.health = _player.max_health
	for z in _route_zombies:
		var id: int = z.get_instance_id()
		var p: Vector3 = z.global_position
		if not _route_side.has(id) and absf(p.z) < 1.0 and absf(p.x) > 4.0:
			_route_side[id] = "ocean side (+X)" if p.x > 0.0 else "ride side (-X)"
		if not _route_arrival.has(id) and p.distance_to(_player.global_position) < 3.2:
			_route_arrival[id] = _route_time
	if _route_arrival.size() == _route_zombies.size() or _route_time > 60.0:
		var east := 0
		var west := 0
		for id in _route_side:
			if String(_route_side[id]).begins_with("ocean"):
				east += 1
			else:
				west += 1
		var times := _route_arrival.values()
		times.sort()
		print("[dev] ROUTE lanes: ocean side=%d ride side=%d (of %d)" % [east, west, _route_zombies.size()])
		print("[dev] ROUTE arrived=%d/%d first=%.1fs last=%.1fs" % [times.size(), _route_zombies.size(),
			times[0] if times.size() > 0 else -1.0, times[-1] if times.size() > 0 else -1.0])
		var ok := times.size() == _route_zombies.size() and east > 0 and west > 0
		print("[dev] route test: %s" % ("OK" if ok else "FAILED"))
		_quit(0 if ok else 1)


var _pause_step := 0
var _pause_busy := false


## Pause -> resume, pause -> restart run, pause -> main menu. Checks tree pause
## state and mouse capture at each step.
func _pause_test() -> void:
	if _pause_busy:
		return
	_pause_busy = true
	await get_tree().create_timer(0.5, true, false, true).timeout
	var ok := true
	_director.pause()
	await get_tree().process_frame
	var menu := get_tree().current_scene.get_node_or_null("PauseMenu")
	var opened := menu != null and get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	print("[dev] pause %d: menu=%s paused=%s mouse_visible=%s" % [_pause_step, menu != null, get_tree().paused, Input.mouse_mode == Input.MOUSE_MODE_VISIBLE])
	ok = ok and opened
	if menu == null:
		_quit(1)
		return
	match _pause_step:
		0:
			menu._open_settings()
			menu._close_settings()
			menu._resume()
			await get_tree().process_frame
			var resumed := not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			print("[dev] resume: unpaused=%s mouse_captured=%s  -> %s" % [not get_tree().paused, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "OK" if resumed else "FAILED"])
			ok = ok and resumed
		1:
			print("[dev] restart run from pause menu")
			menu._leave(true)
		2:
			print("[dev] main menu from pause menu")
			_then_done = true
			_clock = 0.0
			menu._leave(false)
	_pause_step += 1
	if not ok:
		_quit(1)
		return
	await get_tree().create_timer(0.5, true, false, true).timeout
	_pause_busy = false


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
		_tap("kiosk_next")
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
	var waves := _director.waves
	if buy_boost and _director.tickets >= waves.damage_boost_price and _director.damage_boost == RunDirector.Boost.NONE:
		_tap("buy_damage_boost")
		await get_tree().physics_frame
		await get_tree().physics_frame
	if _director.tickets >= waves.overshield_price and _director.overshield < waves.overshield_amount:
		_tap("buy_overshield")
		await get_tree().physics_frame
		await get_tree().physics_frame
	print("[dev] kiosk: tickets %d->%d  %s %d/%d (was %d/%d)  hp %d->%d  shield %d  boost %s" % [
		before[0], _director.tickets, w.current.id, w.magazine(), w.reserve(), before[1], before[2],
		before[3], int(_player.health), int(_director.overshield), RunDirector.Boost.keys()[_director.damage_boost]])


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
		_release("aim")
		return

	# Aim with a slowly wandering error, like a human hand.
	_aim_timer -= delta
	if _aim_timer <= 0.0:
		_aim_timer = 0.25
		_aim_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * deg_to_rad(aim_error)
	var aim_point := target.global_position + Vector3(0, (1.0 if randf() < 0.7 else 1.45) * target.data.body_scale, 0)
	var eye := _player.camera.global_position
	if w.current.projectile_speed > 0.0:
		aim_point = _ballistic_aim(target, eye, w.current)
	var to := aim_point - eye
	var yaw := atan2(-to.x, -to.z) + _aim_offset.x
	var pitch := atan2(to.y, Vector2(to.x, to.z).length()) + _aim_offset.y
	var cur_yaw := _player.rotation.y
	var cur_pitch := _player.look_pitch()
	var turn := 1.0 - exp(-14.0 * delta)
	_player.set_look(lerp_angle(cur_yaw, yaw, turn), lerpf(cur_pitch, pitch, turn))

	var aligned := absf(angle_difference(_player.rotation.y, yaw)) < deg_to_rad(4.0)
	var dist := to.length()
	var in_range := dist < _bot_range(w.current)
	if use_ads:
		# Steady shots from the sights; back at the hip when it has to move.
		_set_held("aim", in_range and not should_move)
		_aimed_time += delta if _player.is_aiming() else 0.0
	if w.current.charge_time > 0.0:
		_fire_charge(w, target, aligned, in_range, dist)
	elif aligned and in_range and not w.is_reloading():
		if w.current.automatic or w.current.beam:
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
	if w.magazine() == 0 and w.reserve() > 0 and not w.is_reloading() and not w.current.uses_heat():
		_tap("reload")
	if switch_on_reload and w.is_reloading() and w.reload_progress() < 0.5:
		_switch_slot(w)


## How close a target must be before the bot opens fire with this weapon.
func _bot_range(data: WeaponData) -> float:
	if data.pellets > 1:
		return 10.0
	if data.beam or data.chain_count > 0:
		return minf(data.max_range * 0.85, 17.0)
	if data.projectile_speed > 0.0:
		return 21.0
	return 26.0


## Charge weapons: hold to charge, release once charged enough and on target.
## Fast or close zombies get a quicker, weaker shot.
func _fire_charge(w: WeaponController, target: Zombie, aligned: bool, in_range: bool, dist: float) -> void:
	if w.is_reloading() or not in_range:
		_release("fire")
		return
	var want := 1.0 if dist > 7.0 and target.data.move_speed < 4.0 else 0.45
	if w.is_charging() and w.charge_progress() >= want and aligned:
		_release("fire")
	else:
		_press("fire")


## Aim point for a lobbed projectile: lead the target and lift the aim to
## cancel the drop over the flight time.
func _ballistic_aim(target: Zombie, eye: Vector3, data: WeaponData) -> Vector3:
	var p := target.global_position + Vector3.UP * 0.7 * target.data.body_scale
	var t := eye.distance_to(p) / maxf(1.0, data.projectile_speed)
	p += target.velocity * t * 0.8
	p.y += 0.5 * data.projectile_gravity * t * t - data.projectile_loft * t
	return p


## Switches to the other slot mid-reload (faster than waiting), if it has energy.
func _switch_slot(w: WeaponController) -> void:
	var other := w.slot_weapon(1 - w.active_slot)
	if other == null or w.ammo_of(other.id).x <= 0:
		return
	_switches += 1
	_tap("weapon_%d" % (2 - w.active_slot))
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not w.is_reloading() and w.current == other:
		_switch_cancels += 1
	if _switches % 10 == 1:
		print("[dev] switch %d: reload cancelled=%s now %s %d/%d" % [_switches, not w.is_reloading(), w.current.id, w.magazine(), w.reserve()])


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
## Patrol ring around the loadout station, snapped onto the navmesh, so the
## bot works on any level.
var _ring_cache: Array = []


func _ring_points() -> Array:
	if not _ring_cache.is_empty():
		return _ring_cache
	var centre := _director.kiosk.global_position if _director.kiosk else _player.global_position
	var map := _player.get_world_3d().navigation_map
	for i in 8:
		var a := TAU * i / 8.0
		var want := centre + Vector3(cos(a), 0, sin(a)) * ring_radius
		_ring_cache.append(NavigationServer3D.map_get_closest_point(map, want))
	return _ring_cache


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

	# Unstick: if we are not getting anywhere, re-plan from scratch and hop
	# (pushing forward, a jump mantles or vaults out of whatever holds us).
	_stuck_time += delta
	if _stuck_time > 2.0:
		if _player.global_position.distance_to(_last_pos) < 0.5:
			_path = PackedVector3Array()
			_ring_index += 1
			_tap("jump")
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
		var sparks := Wallet.settle(r)
		var career := Progression.settle(r)
		print("[dev] RESULT victory=%s waves=%d/%d kills=%d time=%.0fs min_hp=%d tickets_left=%d cashed=%d score=%d headshots=%d best_combo=%d switches=%d/%d sparks=%d wallet=%d xp=%d level=%d" % [
			r["victory"], r["waves_cleared"], r["total_waves"], r["kills"], r["seconds"], int(_min_health), _director.tickets, int(r.get("tickets_cashed", 0)),
			int(r.get("score", 0)), int(r.get("headshots", 0)), int(r.get("best_combo", 0)), _switch_cancels, _switches,
			int(sparks.get("total", 0)), Wallet.balance(), int(career.get("total", 0)), Progression.level()])
		for line in rows:
			print("[dev]   ", line)
		if use_ads:
			print("[dev] aimed down sights for %.0fs" % _aimed_time)
		print("[dev]   sparks: ", sparks.get("lines", []), " contracts done: ", (career.get("contracts", []) as Array).map(func(e): return e["id"]))
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
	elif then == "next":
		var next := screen.find_child("NextWorld", true, false) as Button
		print("[dev] NEXT WORLD button shown: %s" % (next != null))
		if next == null:
			_quit(0 if not _director.result()["victory"] else 1)
			return
		_then_done = true
		next.pressed.emit()
	else:
		_quit(0)


func _quit(code: int) -> void:
	set_physics_process(false)
	for a in _held.keys():
		_set_held(a, false)
	print("[dev] exit code %d" % code)
	get_tree().quit(code)
