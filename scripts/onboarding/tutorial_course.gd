class_name TutorialCourse
extends Node
## Boot Camp's step machine: one idea at a time, each with an objective, keys,
## a visible goal and a reward beat (chime, score, a tick on the checklist).
## Steps and lines are in TutorialScript; this owns what each step builds and
## what completes it. There is no fail state: health tops up, steps can be
## redone (Backspace) and a section can be skipped (hold Enter).

signal step_started(index: int)
signal step_completed(index: int)
signal finished(paid: Dictionary)

const SKIP_ACTION := &"tutorial_skip"
const REDO_ACTION := &"tutorial_redo"
const SKIP_HOLD := 1.0
const STEP_POINTS := 100
const HEADSHOT_POINTS := 50
const LOW_HEALTH := 35.0
const LOOK_CONE := deg_to_rad(7.0)

var run: TutorialRun
var player: Player
var hud: TutorialHud
## Index into TutorialScript.STEPS of the step in progress.
var index := -1
var done := false
## Steps completed (by id) and the ones that already paid their points.
var completed := {}
var skipped_sections: Array[int] = []
var balloons: Array[TutorialProps.Balloon] = []
var pads := {}
var targets := {}
## Zombies the current step is waiting on.
var wave_left: Array[Zombie] = []

var _marks: Node3D
var _flags := {}
var _skip_held := 0.0
var _aim := Transform3D()
var _hurt_cool := 0.0
var _spawn_queue: Array = []
var _spawn_timer := 0.0
var _arena_entered := false
var _start_time := 0.0


func _ready() -> void:
	process_physics_priority = -50
	_ensure_actions()


## Builds the course on the level's markers and starts the first step.
func start(director: TutorialRun) -> void:
	run = director
	player = director.player
	_marks = director.get_parent().get_node_or_null("Course")
	hud = TutorialHud.new()
	hud.name = "TutorialHud"
	director.get_parent().add_child(hud)
	hud.bind(self)
	_build_props()
	player.weapons.fired.connect(_on_fired)
	player.weapons.reload_started.connect(func(_d, _t): _flags["reloaded"] = true)
	player.slide_started.connect(func(): _flags["slid"] = true)
	player.jumped.connect(func(): _flags["jumped"] = true)
	player.traversal_finished.connect(func(vault: bool): _flags["vaulted" if vault else "mantled"] = true)
	player.damaged.connect(_on_player_damaged)
	run.enemy_killed.connect(_on_enemy_killed)
	_start_time = run.elapsed
	enter_step(0)


static func step(i: int) -> Dictionary:
	return TutorialScript.STEPS[i]


func step_count() -> int:
	return TutorialScript.STEPS.size()


func current_id() -> String:
	return String(step(index)["id"]) if index >= 0 and index < step_count() else ""


func section_of(i: int) -> int:
	return int(step(i)["section"])


## The marker `name` under the level's Course node (its position), or ZERO.
func mark(mark_name: String) -> Vector3:
	var m := _marks.get_node_or_null(mark_name) as Node3D if _marks else null
	return m.global_position if m else Vector3.ZERO


func _ensure_actions() -> void:
	for pair in [[SKIP_ACTION, [KEY_ENTER, KEY_KP_ENTER]], [REDO_ACTION, [KEY_BACKSPACE]]]:
		if InputMap.has_action(pair[0]):
			continue
		InputMap.add_action(pair[0])
		for key in pair[1]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(pair[0], e)


# --- props ----------------------------------------------------------------------------

func _build_props() -> void:
	var root := run.get_parent()
	var colors := [TutorialProps.PINK, TutorialProps.CYAN, TutorialProps.GOLD]
	for i in 3:
		var b := TutorialProps.Balloon.new()
		b.color = colors[i]
		root.add_child(b)
		b.global_position = mark("Balloon%d" % i)
		balloons.append(b)
	for pad_name in ["PadMove", "PadSprint", "PadJump", "PadMantle", "PadVault", "PadSlide", "FiringLine", "ArenaEntry"]:
		var pad := TutorialProps.Pad.new()
		root.add_child(pad)
		pad.global_position = mark(pad_name)
		pads[pad_name] = pad
	for i in 5:
		_target("Target%d" % i, TutorialProps.Target.Kind.TIN)
	_target("FarTarget", TutorialProps.Target.Kind.FAR)
	for i in 3:
		_target("Cutout%d" % i, TutorialProps.Target.Kind.CUTOUT)


func _target(mark_name: String, kind: TutorialProps.Target.Kind) -> void:
	var t := TutorialProps.Target.new()
	t.kind = kind
	run.get_parent().add_child(t)
	t.global_position = mark(mark_name)
	t.hit.connect(_on_target_hit)
	targets[mark_name] = t


func _raise(names: Array) -> void:
	var k := 0
	for n in names:
		targets[n].raise(true, k * 0.12)
		k += 1


func _lower_all() -> void:
	for t in targets.values():
		if t.up:
			t.raise(false)


func _show_pad(pad_name: String) -> void:
	for key in pads:
		pads[key].set_active(key == pad_name)


func _on_pad(pad_name: String) -> bool:
	return pads[pad_name].contains(player.global_position)


# --- step flow ------------------------------------------------------------------------

## Starts step `i` (also used to redo one).
func enter_step(i: int) -> void:
	index = i
	_flags.clear()
	_skip_held = 0.0
	var id := current_id()
	_setup_step(id)
	hud.show_step(i, section_of(i) != section_of(i - 1) if i > 0 else true)
	run.notice.emit(String(step(i)["title"]), &"objective")
	hud.say(step(i)["lines"])
	step_started.emit(i)


func _setup_step(id: String) -> void:
	_show_pad("")
	match id:
		"look":
			pass
		"move": _show_pad("PadMove")
		"sprint": _show_pad("PadSprint")
		"jump": _show_pad("PadJump")
		"mantle": _show_pad("PadMantle")
		"vault": _show_pad("PadVault")
		"slide": _show_pad("PadSlide")
		"shoot":
			_show_pad("FiringLine")
			_raise(["Target0", "Target1", "Target2", "Target3", "Target4"])
			_flags["hits"] = 0
		"ads":
			_raise(["FarTarget"])
			_flags["hits"] = 0
		"headshot":
			_raise(["Cutout0", "Cutout1", "Cutout2"])
			_flags["hits"] = 0
		"reload":
			_drain_magazine()
		"switch":
			_raise(["Target1", "Target3"])
		"zombies":
			_open_gate()
			_show_pad("ArenaEntry")
			_arena_entered = false
		"dodge":
			_spawn([[&"boardwalk_bruiser", "PenNorth", 0.85]])
		"special":
			_spawn([[&"mascot_inker", "PenEast", 0.9]])
		"station":
			_setup_station()
		"wave":
			run.set_station_open(false)
			_spawn([[&"tourist_shambler", "PenNorth", 0.9], [&"lifeguard_runner", "PenEast", 0.8], [&"tourist_shambler", "PenSouth", 0.9],
				[&"tourist_shambler", "PenEast", 0.9], [&"lifeguard_runner", "PenNorth", 0.8], [&"tourist_shambler", "PenSouth", 0.9]], 1.6)
		"portal":
			run.open_portal()


func _physics_process(delta: float) -> void:
	if run == null or done or index < 0:
		return
	_aim = player.aim_transform()
	_hurt_cool = maxf(0.0, _hurt_cool - delta)
	_tick_spawns(delta)
	_tick_skip(delta)
	if _check(current_id()):
		complete_step()


## True when step `id` is done (some steps also nudge the player here).
func _check(id: String) -> bool:
	match id:
		"look":
			_look_at_balloons()
			return balloons.all(func(b): return not is_instance_valid(b) or not b.alive)
		"move":
			return _on_pad("PadMove")
		"sprint":
			if player.sprinting:
				_flags["sprinted"] = true
			if _on_pad("PadSprint"):
				if _flags.has("sprinted"):
					return true
				if not _flags.has("nudged"):
					_flags["nudged"] = true
					hud.say([TutorialScript.LINE_NO_SPRINT])
			return false
		"jump":
			return _on_pad("PadJump")
		"mantle":
			return _flags.has("mantled") or _on_pad("PadMantle")
		"vault":
			return _on_pad("PadVault")
		"slide":
			return _flags.has("slid") and _on_pad("PadSlide")
		"shoot":
			return int(_flags["hits"]) >= 5
		"ads", "headshot":
			return int(_flags["hits"]) >= (2 if id == "ads" else 3)
		"reload":
			return _flags.has("reloaded")
		"switch":
			return _flags.has("switch_hit")
		"zombies":
			if not _arena_entered and player.global_position.x > mark("ArenaEntry").x - 1.0:
				_arena_entered = true
				_show_pad("")
				_spawn([[&"tourist_shambler", "PenNorth", 0.6], [&"tourist_shambler", "PenEast", 0.6], [&"tourist_shambler", "PenSouth", 0.6]], 1.2)
			return _arena_entered and _wave_done()
		"dodge":
			_watch_charge()
			return _wave_done()
		"special":
			return _wave_done()
		"station":
			return _station_done()
		"wave":
			return _wave_done()
	return false


## Finishes the current step: the reward beat, then the next step.
func complete_step() -> void:
	var id := current_id()
	var first := not completed.has(id)
	completed[id] = true
	_cleanup_step(id)
	if first:
		_add_score("STEP CLEAR", STEP_POINTS, UiKit.CYAN)
	Sfx.play(&"onb_step", -3.0)
	hud.tick(index)
	step_completed.emit(index)
	if id != "portal":
		hud.say([TutorialScript.CHEERS[randi() % TutorialScript.CHEERS.size()]], true)
	if index + 1 < step_count():
		enter_step(index + 1)


func _cleanup_step(id: String) -> void:
	match id:
		"shoot", "ads", "headshot", "switch":
			_lower_all()
		"station":
			run.set_station_open(false)


## Jumps straight to step `i` as if the ones before were done (screenshots,
## tests): no rewards, the arena gate opened if the step is past it.
func stage(i: int) -> void:
	_cleanup_step(current_id())
	_clear_zombies()
	for k in i:
		completed[String(step(k)["id"])] = true
		if step(k)["id"] == "zombies":
			_open_gate()
	for b in balloons:
		if i > 0 and is_instance_valid(b):
			b.queue_free()
	enter_step(i)
	hud.say(step(i)["lines"], true)


## Steps of the first two sections can be done again; nothing pays twice.
func redo_step() -> void:
	if index <= 0 or section_of(index) == 2 or section_of(index - 1) != section_of(index):
		return
	_cleanup_step(current_id())
	enter_step(index - 1)


## Skips the rest of the current section and starts the next one.
func skip_section() -> void:
	var section := section_of(index)
	if not skipped_sections.has(section):
		skipped_sections.append(section)
	_cleanup_step(current_id())
	_clear_zombies()
	var next := index
	while next < step_count() and section_of(next) == section:
		next += 1
	Sfx.play(&"onb_section", -4.0)
	if next >= step_count():
		finish()
		return
	if section_of(next) == 2:
		# Live fire starts at the arena gate.
		player.global_position = mark("ArenaEntry") + Vector3(-1.5, 0.1, 0)
	elif section_of(next) == 1:
		player.global_position = mark("FiringLine") + Vector3(0, 0.1, 0)
		player.set_look(0.0, 0.0)
	enter_step(next)
	hud.say([TutorialScript.LINE_SECTION_SKIPPED] + Array(step(next)["lines"]))


func _tick_skip(delta: float) -> void:
	if get_tree().paused:
		return
	if Input.is_action_just_pressed(REDO_ACTION):
		redo_step()
	if Input.is_action_pressed(SKIP_ACTION):
		_skip_held += delta
		if _skip_held >= SKIP_HOLD:
			_skip_held = 0.0
			skip_section()
	else:
		_skip_held = 0.0
	hud.set_skip_progress(_skip_held / SKIP_HOLD)


# --- the end --------------------------------------------------------------------------

## The course is over (portal, or the last section skipped): pay the reward
## once and show the graduation card. Skipping live fire counts as skipping
## the tutorial: no graduation bonus, which then waits for a full replay.
func finish() -> void:
	if done:
		return
	done = true
	if current_id() == "portal":
		completed["portal"] = true
	_clear_zombies()
	_lower_all()
	run.set_station_open(false)
	run.end_course()
	var paid := {"sparks": 0, "item": null, "unearned": true}
	if skipped_sections.has(2):
		Onboarding.mark_tutorial_skipped()
	else:
		paid = Onboarding.complete_tutorial()
	paid["seconds"] = run.elapsed - _start_time
	paid["steps"] = completed.size()
	paid["skipped"] = skipped_sections.size()
	paid["score"] = run.score.score if run.score else 0
	player.controls_enabled = false
	player.weapons.enabled = false
	player.invulnerable = true
	Sfx.play(&"onb_complete", 0.0)
	hud.show_finale(paid)
	Game.capture_mouse(false)
	finished.emit(paid)


func on_player_downed() -> void:
	hud.say([TutorialScript.LINE_HURT])


func _on_player_damaged(_amount: float, _source: Vector3) -> void:
	if player.health < LOW_HEALTH:
		player.heal(player.max_health)
		if _hurt_cool <= 0.0:
			_hurt_cool = 8.0
			hud.say([TutorialScript.LINE_HURT])
	if current_id() == "dodge":
		_flags["hurt"] = true


# --- step helpers ---------------------------------------------------------------------

func _look_at_balloons() -> void:
	var cam := player.camera
	var eye := cam.global_position
	var forward := -cam.global_transform.basis.z
	for b in balloons:
		if is_instance_valid(b) and b.alive:
			var to: Vector3 = b.centre() - eye
			if to.length() < 30.0 and forward.angle_to(to) < LOOK_CONE:
				b.pop()
				_add_score("POP", 25, TutorialProps.PINK)


## Shots land on targets through the aim this frame started with (before the
## shot's recoil), so a hit on screen is a hit here.
func _on_fired(_data: WeaponData) -> void:
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(_aim.origin, _aim.origin - _aim.basis.z * 140.0, 1)
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	var body: Object = hit["collider"]
	if body and body.has_meta("tutorial_target"):
		(body.get_meta("tutorial_target") as TutorialProps.Target).take_shot(hit["position"])


func _on_target_hit(t: TutorialProps.Target, head: bool, at: Vector3) -> void:
	var id := current_id()
	if id == "ads" and not player.is_aiming():
		Sfx.play(&"onb_buzz", -6.0)
		if not _flags.has("hip"):
			_flags["hip"] = true
			hud.say([TutorialScript.LINE_HIP_FIRE])
		return
	if t.kind == TutorialProps.Target.Kind.CUTOUT and not head:
		Sfx.play(&"onb_buzz", -6.0)
		KillPopup.spawn(run.get_parent(), at + Vector3.UP * 0.4, 0, 0, "HIGHER!", UiKit.AMBER)
		if not _flags.has("body"):
			_flags["body"] = true
			hud.say([TutorialScript.LINE_BODY_SHOT])
		return
	if id == "switch" and player.weapons.active_slot != 1:
		Sfx.play(&"onb_buzz", -6.0)
		return
	Sfx.play_at(&"onb_ding", at, 3.0, randf_range(0.97, 1.05), 20.0)
	Fx.hit_pop(run.get_parent(), at, _aim.basis.z, head)
	var headshot := t.kind == TutorialProps.Target.Kind.CUTOUT
	var points := HEADSHOT_POINTS if headshot else 20
	KillPopup.spawn(run.get_parent(), at + Vector3.UP * 0.5, points, 0, "HEADSHOT" if headshot else "", Color(1.0, 0.45, 0.7) if headshot else UiKit.CYAN)
	_add_score("", points, UiKit.CYAN)
	if id == "switch":
		_flags["switch_hit"] = true
	_flags["hits"] = int(_flags.get("hits", 0)) + 1
	# The far target stays up for the second hit; the rest drop when hit.
	if t.kind != TutorialProps.Target.Kind.FAR:
		t.raise(false)


func _add_score(caption: String, points: int, color: Color) -> void:
	var s := run.score
	if s == null:
		return
	s.score += points
	s.score_changed.emit(s.score, points)
	if caption != "":
		s.award.emit(caption, points, color)


## Leaves a few shots in the magazine so a reload is the obvious next move.
func _drain_magazine() -> void:
	var w := player.weapons
	if w.current == null or w.current.uses_heat():
		return
	var ammo: Dictionary = w.get("_ammo")
	if ammo and ammo.has(w.current.id):
		ammo[w.current.id]["mag"] = mini(3, w.current.magazine_size)
		w.ammo_changed.emit(w.magazine(), w.reserve())


func _open_gate() -> void:
	var gate := _marks.get_node_or_null("ArenaGate") if _marks else null
	if gate == null:
		return
	Sfx.play(&"portal_open", -6.0, 1.3)
	var tw := gate.create_tween()
	tw.tween_property(gate, "position:y", -2.5, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(gate.queue_free)


## Queues zombies: [enemy id, pen marker, speed scale] each, `interval` apart.
func _spawn(list: Array, interval := 0.0) -> void:
	wave_left.clear()
	_spawn_queue = list.duplicate()
	_spawn_timer = 0.4
	_flags["interval"] = interval


func _tick_spawns(delta: float) -> void:
	if _spawn_queue.is_empty():
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = float(_flags.get("interval", 0.0))
	var entry: Array = _spawn_queue.pop_front()
	var z := run.spawn_zombie(entry[0], mark(entry[1]), entry[2])
	if z:
		wave_left.append(z)
	if _spawn_timer <= 0.0:
		_tick_spawns(0.0)


func _wave_done() -> bool:
	if not _spawn_queue.is_empty():
		return false
	for z in wave_left:
		if is_instance_valid(z) and not z.is_dead():
			return false
	return not wave_left.is_empty()


func _clear_zombies() -> void:
	_spawn_queue.clear()
	for z in run.alive_enemies().duplicate():
		if is_instance_valid(z) and not z.is_dead():
			z.despawn()
	wave_left.clear()


func _on_enemy_killed(_z: Zombie, _weapon_id: StringName) -> void:
	Sfx.play(&"onb_ding", -8.0, 1.2)


## Notes a Bruiser charge, and cheers when it missed.
func _watch_charge() -> void:
	for z in wave_left:
		if is_instance_valid(z) and z.is_charging():
			_flags["charging"] = true
		elif _flags.has("charging") and is_instance_valid(z):
			_flags.erase("charging")
			if not _flags.has("hurt") and not _flags.has("dodged"):
				_flags["dodged"] = true
				hud.say([TutorialScript.LINE_DODGED], true)
				_add_score("DODGED", 50, UiKit.GREEN)


# --- the station ----------------------------------------------------------------------

func _setup_station() -> void:
	run.give_tickets(600 - run.tickets if run.tickets < 600 else 0)
	run.set_station_open(true)
	_show_pad("")
	# Something to buy: a little hurt, a little low on energy.
	if player.health > 60.0:
		player.health = 60.0
		player.health_changed.emit(player.health, player.max_health)
	var w := player.weapons
	var ammo: Dictionary = w.get("_ammo")
	if ammo and w.current and ammo.has(w.current.id) and w.is_ammo_full():
		ammo[w.current.id]["reserve"] = int(ammo[w.current.id]["reserve"]) / 2
		w.ammo_changed.emit(w.magazine(), w.reserve())
	_flags["slots"] = w.slots.duplicate()
	_flags["can_swap"] = run.station_weapons().size() > 1
	if not _flags["can_swap"]:
		hud.say([TutorialScript.LINE_SWAP_NONE])


## Which station purchases are done: [energy, snack, overshield, swap].
func station_progress() -> Array[bool]:
	var w := player.weapons
	# Purchases stick once made (a swap brings in a weapon that is not full).
	if w.is_ammo_full():
		_flags["energy"] = true
	if player.health >= player.max_health or run.heals_left() <= 0:
		_flags["snack"] = true
	return [_flags.has("energy"), _flags.has("snack"),
		run.overshield > 0.0, w.slots != _flags.get("slots", w.slots) or not _flags.get("can_swap", true)]


func _station_done() -> bool:
	var parts := station_progress()
	hud.show_station(parts)
	return not parts.has(false)
