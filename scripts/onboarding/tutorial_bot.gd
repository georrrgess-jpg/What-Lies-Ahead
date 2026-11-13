class_name TutorialBot
extends RefCounted
## The dev driver's Boot Camp player (--autoplay=tutorial): starts the tutorial
## from the menu and plays every step through the real input pipeline, using
## the driver's walking and input helpers. Options:
##   --tutorial-runs=n     play it n times (the reward must pay only on the first)
##   --tutorial-skip=<id>  at step <id>, skip Boot Camp from the pause menu and
##                         check that the game lands back on the main menu
## Prints "[dev] TUTORIAL ..." lines and a final "[dev] RESULT" line.

var driver: Node
var runs_wanted := 1
var skip_at := ""
var _runs := 0
var _paid: Array[int] = []
var _course: TutorialCourse
var _player: Player
var _step := ""
var _step_time := 0.0
var _tap_cool := 0.0
var _fire_down := false
var _started := false
var _menu_wait := 0.0
var _skipping := false
var _station_taps := 0


func _init(dev: Node) -> void:
	driver = dev
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tutorial-runs="):
			runs_wanted = maxi(1, int(arg.trim_prefix("--tutorial-runs=")))
		elif arg.begins_with("--tutorial-skip="):
			skip_at = arg.trim_prefix("--tutorial-skip=")


func tick(delta: float) -> void:
	var scene := driver.get_tree().current_scene
	if scene == null:
		return
	if scene.name == "MainMenu":
		_menu_tick(delta)
		return
	var run := driver.get_tree().get_first_node_in_group("run_director") as TutorialRun
	if run == null or run.course == null:
		return
	if _course != run.course:
		_course = run.course
		_player = run.player
		driver._player = run.player
		driver._director = run
		_step = ""
		_course.finished.connect(_on_finished)
		print("[dev] TUTORIAL run %d started" % (_runs + 1))
	if _course.done or _skipping:
		driver._stop_moving()
		driver._release("fire")
		return
	_player.health = maxf(_player.health, 60.0)
	var id := _course.current_id()
	if id != _step:
		print("[dev] TUTORIAL step %-9s t=%5.1fs  line=\"%s\"" % [id, run.elapsed, _course.hud.current_line()])
		_step = id
		_step_time = 0.0
		_station_taps = 0
		driver._release("aim")
		driver._release("sprint")
		if id == skip_at:
			_skip_from_pause(run)
			return
	_step_time += delta
	_tap_cool -= delta
	_play(id, delta)


func _menu_tick(delta: float) -> void:
	_menu_wait += delta
	if _skipping or (_runs > 0 and _runs >= runs_wanted):
		if _menu_wait > 1.0:
			_report_and_quit()
		return
	if _menu_wait > 0.6 and not _started:
		_started = true
		print("[dev] TUTORIAL starting from the menu (state=%s)" % Onboarding.tutorial_state())
		Onboarding.start_tutorial()


# --- steps ----------------------------------------------------------------------------

func _play(id: String, delta: float) -> void:
	match id:
		"look":
			for b in _course.balloons:
				if is_instance_valid(b) and b.alive:
					_look_at(b.centre(), delta, 10.0)
					break
		"move":
			_go("PadMove", delta, false)
		"sprint":
			_go("PadSprint", delta, true)
		"jump":
			_go("PadJump", delta, true)
			_jump_near("Hurdle", 1.6)
		"mantle":
			_go("PadMantle", delta, false)
			_jump_near("CrateStack", 2.0)
		"vault":
			_go("PadVault", delta, true)
			_jump_near("Barrier", 1.5)
		"slide":
			_go("PadSlide", delta, true)
			var sign := _obstacle("LowSign")
			if sign and _player.global_position.z - sign.global_position.z < 4.0 and _player.global_position.z > sign.global_position.z and not _player.sliding:
				driver._tap("slide")
		"shoot", "ads", "headshot", "switch":
			_shoot_targets(id, delta)
		"reload":
			driver._release("fire")
			if _tap_cool <= 0.0:
				_tap_cool = 0.5
				driver._tap("reload")
		"zombies":
			if _course.wave_left.is_empty():
				_straight(_course.mark("ArenaEntry") + Vector3(3, 0, 0), delta)
			else:
				_fight(delta)
		"dodge", "special", "wave":
			_fight(delta)
		"station":
			_shop(delta)
		"portal":
			driver._release("fire")
			_walk(_course.run.portal.global_position, delta, true)


func _go(pad: String, delta: float, sprint: bool) -> void:
	driver._release("fire")
	_straight(_course.mark(pad), delta)
	driver._set_held("sprint", sprint)


## Walking along the navmesh (the arena).
func _walk(goal: Vector3, delta: float, face: bool) -> void:
	driver._walk_to(goal, delta, face)


## Straight at `goal`, facing it: the lane's obstacles cut its navmesh, and
## going over them is the point.
func _straight(goal: Vector3, delta: float) -> void:
	var to := goal - _player.global_position
	to.y = 0.0
	if to.length() < 0.3:
		driver._stop_moving()
		return
	var yaw := atan2(-to.x, -to.z)
	_player.set_look(lerp_angle(_player.rotation.y, yaw, 1.0 - exp(-12.0 * delta)), lerpf(_player.look_pitch(), 0.0, 0.1))
	var local := _player.global_transform.basis.inverse() * to.normalized()
	driver._set_axis("move_forward", "move_back", -local.z)
	driver._set_axis("move_right", "move_left", local.x)


func _obstacle(obstacle_name: String) -> Node3D:
	return _course.run.get_parent().find_child(obstacle_name, true, false) as Node3D


func _jump_near(obstacle_name: String, distance: float) -> void:
	var o := _obstacle(obstacle_name)
	if o == null:
		return
	var dz := _player.global_position.z - o.global_position.z
	if dz > 0.0 and dz < distance and _tap_cool <= 0.0:
		_tap_cool = 0.35
		driver._tap("jump")


func _look_at(point: Vector3, delta: float, rate: float) -> bool:
	var eye := _player.camera.global_position
	var to := point - eye
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var k := 1.0 - exp(-rate * delta)
	_player.set_look(lerp_angle(_player.rotation.y, yaw, k), lerpf(_player.look_pitch(), pitch, k))
	return absf(angle_difference(_player.rotation.y, yaw)) < deg_to_rad(1.5) and absf(_player.look_pitch() - pitch) < deg_to_rad(1.5)


func _shoot_targets(id: String, delta: float) -> void:
	var line := _course.mark("FiringLine")
	if Vector2(_player.global_position.x - line.x, _player.global_position.z - line.z).length() > 1.0:
		_straight(line, delta)
		return
	driver._stop_moving()
	if id == "switch" and _player.weapons.active_slot != 1:
		if _tap_cool <= 0.0:
			_tap_cool = 0.6
			driver._tap("weapon_2")
		return
	driver._set_held("aim", id in ["ads", "headshot"])
	var target: TutorialProps.Target = null
	for t in _course.targets.values():
		if t.up:
			target = t
			break
	if target == null:
		driver._release("fire")
		return
	var on := _look_at(target.aim_point(), delta, 14.0)
	var ready := on and (id not in ["ads", "headshot"] or _player.is_aiming())
	_fire_down = ready and not _fire_down
	driver._set_held("fire", _fire_down)


func _fight(delta: float) -> void:
	var target: Zombie = null
	var best := INF
	for z in _course.run.alive_enemies():
		if is_instance_valid(z) and not z.is_dead():
			var d := z.global_position.distance_to(_player.global_position)
			if d < best:
				best = d
				target = z
	if target == null:
		driver._release("fire")
		_walk(_course.mark("Kiosk") + Vector3(0, 0, -6), delta, true)
		return
	# Keep 7-14 m away, strafing round the target (that dodges the charges).
	var away := _player.global_position - target.global_position
	away.y = 0.0
	if best < 7.0:
		_walk(_player.global_position + away.normalized() * 4.0 + away.cross(Vector3.UP).normalized() * 2.0, delta, false)
	elif best > 16.0:
		_walk(target.global_position, delta, false)
	else:
		driver._stop_moving()
	var on := _look_at(target.global_position + Vector3.UP * 1.1 * target.data.body_scale, delta, 14.0)
	_fire_down = on and not _fire_down
	driver._set_held("fire", _fire_down)
	if _player.weapons.magazine() == 0 and not _player.weapons.is_reloading():
		driver._tap("reload")


func _shop(delta: float) -> void:
	driver._release("fire")
	var run := _course.run
	if int(_step_time * 60.0) % 300 == 0:
		print("[dev] TUTORIAL station: at=%s tickets=%d parts=%s pos=%s" % [run.kiosk_available(), run.tickets, _course.station_progress(), _player.global_position.snapped(Vector3.ONE * 0.1)])
	if not run.kiosk_available():
		_walk(run.kiosk.global_position, delta, true)
		return
	driver._stop_moving()
	if _tap_cool > 0.0:
		return
	_tap_cool = 0.4
	var actions := ["interact", "interact_alt", "buy_overshield", "kiosk_next"]
	var parts := _course.station_progress()
	for k in actions.size():
		if not parts[k]:
			driver._tap(actions[k])
			_station_taps += 1
			return


# --- skipping and results ---------------------------------------------------------------

## Opens the pause menu and presses SKIP TUTORIAL, then confirms.
func _skip_from_pause(run: TutorialRun) -> void:
	_skipping = true
	driver._stop_moving()
	run.pause()
	await driver.get_tree().process_frame
	var menu := driver.get_tree().current_scene.get_node_or_null("PauseMenu")
	var skip := menu.find_child("SkipTutorial", true, false) as Button if menu else null
	print("[dev] TUTORIAL skip at %s: pause menu=%s skip button=%s" % [skip_at, menu != null, skip != null])
	if skip == null:
		driver._quit(1)
		return
	skip.pressed.emit()
	await driver.get_tree().process_frame
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text == "SKIP" and b.is_visible_in_tree():
			(b as Button).pressed.emit()
	_menu_wait = 0.0


func _on_finished(paid: Dictionary) -> void:
	_runs += 1
	_paid.append(int(paid.get("sparks", 0)))
	print("[dev] TUTORIAL finished run %d: %.0fs steps=%d sparks paid=%d item=%s wallet=%d state=%s" % [
		_runs, float(paid.get("seconds", 0.0)), int(paid.get("steps", 0)), int(paid.get("sparks", 0)),
		paid.get("item").id if paid.get("item") else "-", Wallet.balance(), Onboarding.tutorial_state()])
	await driver.get_tree().create_timer(1.5).timeout
	var hud := _course.hud
	var deploy := hud.find_child("DeployButton", true, false)
	print("[dev] TUTORIAL finale card: deploy button=%s" % (deploy != null))
	_started = false
	_menu_wait = 0.0
	if _runs < runs_wanted:
		Onboarding.start_tutorial()
	else:
		(hud.find_child("MenuButton", true, false) as Button).pressed.emit()


func _report_and_quit() -> void:
	var ok: bool
	if _skipping:
		ok = Onboarding.tutorial_state() in ["skipped", "completed"] and not Game.tutorial_active
		print("[dev] RESULT tutorial skipped at %s: back at menu, state=%s -> %s" % [skip_at, Onboarding.tutorial_state(), "OK" if ok else "FAILED"])
	else:
		ok = _paid.size() == runs_wanted and _paid[0] == Onboarding.REWARD_SPARKS
		for k in range(1, _paid.size()):
			ok = ok and _paid[k] == 0
		print("[dev] RESULT tutorial runs=%d paid=%s state=%s wallet=%d -> %s" % [_runs, _paid, Onboarding.tutorial_state(), Wallet.balance(), "OK" if ok else "FAILED"])
	driver._quit(0 if ok else 1)
