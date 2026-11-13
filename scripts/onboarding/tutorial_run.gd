class_name TutorialRun
extends RunDirector
## The run director of Boot Camp. It sets the run up exactly like a real level
## (player, HUD, station, portal, pause menu) and then hands the pacing to a
## TutorialCourse: no automatic waves, no countdown, no defeat, and nothing it
## does pays XP, mastery or Sparks (the course pays its one-time reward).
##
## The loadout station opens when the course says so (station_open), and the
## HUD's wave counter is hidden in favour of the course's own objective card.

## The course in progress (built when the run starts).
var course: TutorialCourse
## True while the course lets the player shop at the station.
var station_open := false


func _begin() -> void:
	super._begin()
	# Nothing in Boot Camp counts toward the account: drop the run's trackers.
	Wallet.run = null
	Progression.tracker = null
	tickets = 0
	tickets_changed.emit(tickets)
	_set_state(State.WAVE)
	if kiosk:
		kiosk.set_open(false)
	if hud and hud.has_method("hide_wave_counter"):
		hud.hide_wave_counter()
	player.weapons.set_loadout(&"ion_carbine", &"pulse_pistol")
	course = TutorialCourse.new()
	course.name = "Course"
	add_child(course)
	course.start(self)


func _process(delta: float) -> void:
	if player == null or _finished:
		return
	elapsed += delta
	if player.global_position.y < -12.0:
		player.global_position = _player_start
		player.velocity = Vector3.ZERO
	for i in range(_alive.size() - 1, -1, -1):
		if not is_instance_valid(_alive[i]) or _alive[i].is_dead():
			_alive.remove_at(i)


## The station sells only while the course has it open.
func is_intermission() -> bool:
	return station_open


func total_waves() -> int:
	return 1


func enemies_remaining() -> int:
	return _alive.size()


## Waves come from the course, never from the start-wave key.
func start_next_wave() -> void:
	pass


## Opens or closes the loadout station for the course.
func set_station_open(open: bool) -> void:
	station_open = open
	if kiosk:
		kiosk.set_open(open)


## Gives the player tickets to spend (the station lesson).
func give_tickets(amount: int) -> void:
	tickets += amount
	tickets_changed.emit(tickets)


## Spawns one zombie of `enemy_id` at `at`, facing the player. It counts like
## a wave's zombie (score, tickets, HUD) but grants no XP.
func spawn_zombie(enemy_id: StringName, at: Vector3, speed_scale := 1.0) -> Zombie:
	var data := GameData.enemy(enemy_id)
	if data == null:
		return null
	var z: Zombie = _zombie_scene.instantiate()
	z.setup(data, player, speed_scale)
	z.position = at
	var to := player.global_position - at
	z.rotation.y = atan2(-to.x, -to.z)
	z.died.connect(_on_zombie_died)
	z.stalled.connect(_on_zombie_stalled)
	_enemies_root.add_child(z)
	_alive.append(z)
	return z


## Opens the exit portal and lights the route (the HUD shows its marker).
func open_portal() -> void:
	_begin_extraction()


## No mastery, XP or unlocks from Boot Camp kills.
func _grant(_weapon_id: StringName, _xp: int, _kills: int) -> void:
	pass


## There is no defeat in Boot Camp: the player gets back up, healed.
func _on_player_died() -> void:
	player.alive = true
	player.controls_enabled = true
	player.heal(player.max_health)
	if course:
		course.on_player_downed()


func _on_portal_entered() -> void:
	if state != State.EXTRACTION or _finished:
		return
	_set_state(State.CLEARED)
	Sfx.play(&"level_clear", 0.0)
	_finished = true
	_freeze_player()
	if course:
		course.finish()


## The course ended (portal or skipped to the end): the run is over, so the
## pause menu cannot open over the graduation card.
func end_course() -> void:
	if _finished:
		return
	_finished = true
	_set_state(State.CLEARED)
	_freeze_player()


## Leaving from the pause menu: RESTART replays Boot Camp, MAIN MENU leaves it.
func abandon(retry: bool) -> void:
	_settle_abandoned()
	get_parent().process_mode = Node.PROCESS_MODE_DISABLED
	if retry:
		Onboarding.start_tutorial()
	else:
		Game.to_menu()


## The pause menu's SKIP TUTORIAL: remember the skip and go to the menu.
func skip_tutorial() -> void:
	Onboarding.mark_tutorial_skipped()
	abandon(false)
