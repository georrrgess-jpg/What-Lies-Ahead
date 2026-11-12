class_name RunDirector
extends Node
## Owns one run of a level: preparation -> wave -> break -> ... -> extraction,
## with defeat reachable from combat. Generic across levels: the level scene
## supplies geometry, navigation and markers; LevelData supplies the waves.
##
## The level scene needs:
##   - one node in group "player_spawn"   (Marker3D)
##   - nodes in group "enemy_spawn"       (Marker3D, outside the main loop)
##   - a PrizeKiosk (group "kiosk") and an ExitPortal (group "portal")

signal state_changed(state: State)
signal wave_started(number: int, total: int, banner: String)
signal wave_cleared(number: int, total: int)
signal tickets_changed(tickets: int)
## Short HUD message. kind: "info", "good", "bad", "banner".
signal notice(text: String, kind: StringName)
signal reward_unlocked(weapon: WeaponData, reward: CosmeticItem)
signal run_finished(result: Dictionary)
## Emitted once the player, HUD and level are set up.
signal run_started
## A stalled zombie was moved back to an entrance (removed = true if it was despawned instead).
signal enemy_recovered(zombie: Zombie, removed: bool)
## A zombie died (after tickets, XP and score were awarded).
signal enemy_killed(zombie: Zombie, weapon_id: StringName)

enum State { PREP, WAVE, BREAK, EXTRACTION, CLEARED, DEFEAT }

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const ZOMBIE_SCENE := "res://scenes/enemies/zombie.tscn"
const HUD_SCENE := "res://scenes/ui/hud.tscn"
const PAUSE_SCENE := "res://scenes/ui/pause_menu.tscn"
const RESULTS_SCENE := "res://scenes/ui/results.tscn"
## Minimum distance from the player for a spawn point to be used.
const SPAWN_MIN_DISTANCE := 13.0
const MAX_RECOVERIES := 2

var level: LevelData
var waves: WaveSet
var state: State = State.PREP
## 1-based number of the wave in progress (or the last one started).
var wave_number := 0
var waves_cleared := 0
var tickets := 0
## Seconds left in PREP or BREAK.
var countdown := 0.0
var heals_this_break := 0
var total_kills := 0
var elapsed := 0.0

var player: Player
var kiosk: PrizeKiosk
var portal: ExitPortal
var hud: Node

var _alive: Array[Zombie] = []
var _queue: Array[StringName] = []
var _spawn_timer := 0.0
var _wave_kills := {}        # weapon id -> kills in the current wave
var _run_stats := {}         # weapon id -> { xp, kills, xp_before, rank_before, unlocks }
var _recoveries := {}        # zombie instance id -> times relocated
var _last_spawn: Node3D
var _enemies_root: Node3D
var _zombie_scene: PackedScene
var _finished := false
var score: ScoreKeeper
var _new_best := false
var _player_start := Vector3.ZERO


func _ready() -> void:
	add_to_group("run_director")
	level = Game.level
	if level == null:
		# Scene launched directly from the editor: find its catalog entry.
		var path := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
		for world in GameData.worlds():
			for l in world.levels:
				if l.scene_path == path:
					level = l
		if level == null:
			level = GameData.worlds()[0].levels[0]
		Game.level = level
		if Game.weapon_id == &"":
			Game.weapon_id = GameData.default_weapon_id()
	waves = level.wave_set
	_zombie_scene = load(ZOMBIE_SCENE)
	_begin.call_deferred()


func _begin() -> void:
	var root := get_parent()
	score = ScoreKeeper.new()
	score.name = "Score"
	add_child(score)
	_enemies_root = Node3D.new()
	_enemies_root.name = "Enemies"
	root.add_child(_enemies_root)

	kiosk = get_tree().get_first_node_in_group("kiosk") as PrizeKiosk
	portal = get_tree().get_first_node_in_group("portal") as ExitPortal
	if portal:
		portal.entered.connect(_on_portal_entered)

	player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	root.add_child(player)
	var spawn := get_tree().get_first_node_in_group("player_spawn") as Node3D
	if spawn:
		_player_start = spawn.global_position
		player.global_position = spawn.global_position
		player.set_look(spawn.global_rotation.y, 0.0)
	player.died.connect(_on_player_died)
	player.damaged.connect(func(amount: float, _src: Vector3): score.on_player_damaged(amount))
	player.weapons.begin_run()
	player.weapons.equip(Game.weapon_id)

	hud = (load(HUD_SCENE) as PackedScene).instantiate()
	root.add_child(hud)
	hud.bind(self, player)
	# Extra HUD widgets registered in data/ui/ (progression bars, etc.).
	for ext in GameData.ui_extensions(UiExtension.Kind.HUD_WIDGET):
		if ext.script_ref:
			var widget = ext.script_ref.new()
			widget.name = String(ext.id)
			hud.add_widget(widget)
			if widget.has_method("bind"):
				widget.bind(self, player)

	Game.capture_mouse(true)
	Sfx.warm_up()
	# Compile every effect and enemy shader now, behind the fade-in, instead of
	# mid-fight on the first kill.
	var warm := FxWarmup.new()
	warm.name = "FxWarmup"
	root.add_child(warm)
	warm.run(player.camera, _level_enemies(), GameData.weapons())
	hud.fade_in()
	Sfx.play_ambience(level.ambience, level.ambience_volume_db)
	Sfx.play_music(level.music, level.music_volume_db)

	countdown = waves.prep_seconds
	_set_state(State.PREP)
	if kiosk:
		kiosk.set_open(true)
	notice.emit("Get ready! Follow the marker to the Loadout Station between waves.", &"info")
	run_started.emit()
	Events.run_started.emit(self)


func _process(delta: float) -> void:
	if player == null or _finished:
		return
	elapsed += delta
	# Safety net: nothing should let the player leave the pier, but never strand them.
	if player.global_position.y < -12.0:
		player.global_position = _player_start
		player.velocity = Vector3.ZERO
	match state:
		State.PREP, State.BREAK:
			countdown -= delta
			if countdown <= 0.0:
				start_next_wave()
		State.WAVE:
			_tick_wave(delta)


func _notification(what: int) -> void:
	# Alt-tabbing away mid-wave pauses the run instead of leaving the player to die.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and player != null and not _finished and DisplayServer.get_name() != "headless":
		pause()


func _unhandled_input(event: InputEvent) -> void:
	if player == null or _finished:
		return
	if event.is_action_pressed("pause"):
		pause()
		return
	if not player.alive:
		return
	if event.is_action_pressed("start_wave"):
		if state == State.PREP or state == State.BREAK:
			start_next_wave()
	elif event.is_action_pressed("interact"):
		buy_ammo()
	elif event.is_action_pressed("interact_alt"):
		buy_heal()
	elif event.is_action_pressed("weapon_1"):
		swap_weapon_index(0)
	elif event.is_action_pressed("weapon_2"):
		swap_weapon_index(1)
	elif event.is_action_pressed("weapon_3"):
		swap_weapon_index(2)
	elif event.is_action_pressed("weapon_next"):
		_cycle_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		_cycle_weapon(-1)


# --- queries -------------------------------------------------------------------

func total_waves() -> int:
	return waves.waves.size()


func enemies_remaining() -> int:
	return _queue.size() + _alive.size()


func alive_enemies() -> Array[Zombie]:
	return _alive


func is_intermission() -> bool:
	return state == State.PREP or state == State.BREAK


## True while the player can shop: kiosk open and the player standing at it.
func kiosk_available() -> bool:
	return is_intermission() and kiosk != null and kiosk.open and kiosk.player_inside


func heals_left() -> int:
	return maxi(0, waves.heals_per_break - heals_this_break)


## Every enemy type that appears in this level's waves.
func _level_enemies() -> Array:
	var out: Array = []
	for wave in waves.waves:
		for key in wave.spawns:
			var e := GameData.enemy(StringName(String(key)))
			if e and not out.has(e):
				out.append(e)
	return out


# --- waves ---------------------------------------------------------------------

func start_next_wave() -> void:
	if not is_intermission():
		return
	wave_number += 1
	var wave := waves.waves[wave_number - 1]
	_queue = _build_queue(wave)
	_wave_kills.clear()
	_spawn_timer = 1.6
	_last_spawn = null
	if kiosk:
		kiosk.set_open(false)
	_set_state(State.WAVE)
	var final := wave_number == total_waves()
	Sfx.play(&"final_wave" if final else &"wave_start", -2.0)
	score.on_wave_started()
	wave_started.emit(wave_number, total_waves(), wave.banner)


## Opens with the first listed enemy type, then mixes the rest in once
## `late_types_after` of the wave has spawned.
func _build_queue(wave: WaveData) -> Array[StringName]:
	var primary: Array[StringName] = []
	var others: Array[StringName] = []
	var first := true
	for key in wave.spawns:
		var id := StringName(String(key))
		if GameData.enemy(id) == null:
			push_warning("Wave %d lists unknown enemy '%s'" % [wave_number, id])
			continue
		for i in int(wave.spawns[key]):
			if first:
				primary.append(id)
			else:
				others.append(id)
		first = false
	var total := primary.size() + others.size()
	var head_count := mini(primary.size(), int(round(total * wave.late_types_after)))
	var queue: Array[StringName] = []
	queue.append_array(primary.slice(0, head_count))
	var rest: Array[StringName] = []
	rest.append_array(primary.slice(head_count))
	rest.append_array(others)
	rest.shuffle()
	queue.append_array(rest)
	return queue


func _tick_wave(delta: float) -> void:
	var wave := waves.waves[wave_number - 1]
	# Drop anything that was freed behind our back so it cannot hold the wave open.
	for i in range(_alive.size() - 1, -1, -1):
		if not is_instance_valid(_alive[i]) or _alive[i].is_dead():
			_alive.remove_at(i)

	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and not _queue.is_empty() and _alive.size() < wave.max_alive:
		_spawn_timer = wave.spawn_interval
		var count := mini(maxi(1, wave.burst), wave.max_alive - _alive.size())
		for i in count:
			if _queue.is_empty():
				break
			if not _spawn(_queue.front(), wave):
				break
			_queue.pop_front()

	# A wave ends only when nothing is queued and nothing is alive.
	if _queue.is_empty() and _alive.is_empty():
		_end_wave()
		return


## Returns false if nothing could be spawned (the enemy stays queued).
func _spawn(enemy_id: StringName, wave: WaveData) -> bool:
	var data := GameData.enemy(enemy_id)
	var point := _pick_spawn()
	if data == null or point == null:
		return false
	var z: Zombie = _zombie_scene.instantiate()
	z.setup(data, player, wave.speed_scale)
	var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	z.position = point.global_position + offset
	z.rotation.y = point.global_rotation.y
	z.died.connect(_on_zombie_died)
	z.stalled.connect(_on_zombie_stalled)
	_enemies_root.add_child(z)
	_alive.append(z)
	return true


## Prefers entrances that are far from the player and outside their view.
func _pick_spawn() -> Node3D:
	var points := get_tree().get_nodes_in_group("enemy_spawn")
	if points.is_empty():
		return null
	var forward := -player.camera.global_transform.basis.z
	var best: Array = []
	var best_score := -INF
	for p in points:
		var to_point: Vector3 = p.global_position - player.global_position
		var distance := to_point.length()
		var score := 0.0
		if distance < SPAWN_MIN_DISTANCE:
			score -= 100.0
		var facing := forward.dot(to_point.normalized())
		score -= maxf(0.0, facing) * 2.0          # in front of the player = worse
		score += minf(distance, 40.0) * 0.03
		if p == _last_spawn:
			score -= 1.0
		score += randf() * 1.5
		if score > best_score:
			best_score = score
			best = [p]
	_last_spawn = best[0]
	return _last_spawn


func _on_zombie_died(z: Zombie, weapon_id: StringName) -> void:
	_alive.erase(z)
	total_kills += 1
	tickets += z.data.tickets
	tickets_changed.emit(tickets)
	_wave_kills[weapon_id] = int(_wave_kills.get(weapon_id, 0)) + 1
	_grant(weapon_id, z.data.xp, 1)
	var w := GameData.weapon(weapon_id)
	# Squad reaction: allies near the fallen zombie get enraged briefly.
	for other in _alive:
		if is_instance_valid(other) and other.data.enrage_radius > 0.0 \
				and other.global_position.distance_to(z.global_position) <= other.data.enrage_radius:
			other.enrage(other.data.enrage_seconds)
	var points := score.on_kill(z.data.score, z.killed_by_headshot, w.headshot_multiplier if w else 1.5,
		z.kill_distance, player.health / player.max_health if player else 1.0)
	Events.enemy_killed.emit(z, weapon_id, z.killed_by_headshot, points)
	enemy_killed.emit(z, weapon_id)


## A zombie reports itself stalled when it stops making progress or loses
## contact with the player for a long time (see zombie.gd). It is moved back to
## an entrance; if that keeps happening it is removed (no rewards) so a stuck
## enemy can never hold the wave open forever.
func _on_zombie_stalled(z: Zombie) -> void:
	if not is_instance_valid(z) or z.is_dead():
		return
	var key := z.get_instance_id()
	var count := int(_recoveries.get(key, 0)) + 1
	_recoveries[key] = count
	if count > MAX_RECOVERIES:
		_alive.erase(z)
		_recoveries.erase(key)
		enemy_recovered.emit(z, true)
		z.despawn()
		return
	enemy_recovered.emit(z, false)
	var point := _pick_spawn()
	if point:
		z.global_position = point.global_position
		z.reset_stall()


func _end_wave() -> void:
	if state != State.WAVE:
		return
	waves_cleared = wave_number
	var bonus := waves.wave_bonus_base + waves.wave_bonus_per_wave * wave_number
	for weapon_id in _wave_kills:
		if int(_wave_kills[weapon_id]) > 0:
			_grant(weapon_id, bonus, 0)
	_wave_kills.clear()
	score.on_wave_cleared(wave_number)
	Profile.record_wave_cleared(level.id, wave_number)
	_commit()
	wave_cleared.emit(wave_number, total_waves())
	Events.wave_cleared.emit(wave_number, total_waves())
	if wave_number >= total_waves():
		_begin_extraction()
	else:
		_begin_break()


func _begin_break() -> void:
	heals_this_break = 0
	countdown = waves.break_seconds
	_set_state(State.BREAK)
	var gained := player.weapons.refill_fraction(waves.break_refill_fraction)
	if kiosk:
		kiosk.set_open(true)
	Sfx.play(&"wave_clear", -2.0)
	var extra := "  +%d energy" % gained if gained > 0 else ""
	notice.emit("WAVE %d CLEARED%s" % [wave_number, extra], &"banner")


func _begin_extraction() -> void:
	_set_state(State.EXTRACTION)
	if kiosk:
		kiosk.set_open(false)
	if portal:
		portal.activate()
	Sfx.play(&"portal_open", 0.0)
	notice.emit("PORTAL OPEN — FOLLOW THE LIGHTS", &"banner")


func _on_portal_entered() -> void:
	if state != State.EXTRACTION:
		return
	_set_state(State.CLEARED)
	Profile.record_level_cleared(level.id)
	_commit()
	Sfx.play(&"level_clear", 0.0)
	_finish(true)


func _on_player_died() -> void:
	if state == State.CLEARED or state == State.DEFEAT:
		return
	_set_state(State.DEFEAT)
	_commit()
	Sfx.play(&"defeat", 0.0)
	_finish(false)


# --- kiosk ---------------------------------------------------------------------

func buy_ammo() -> bool:
	if not kiosk_available():
		return false
	if player.weapons.is_ammo_full():
		notice.emit("Energy already full", &"info")
		return false
	if not _spend(waves.ammo_topup_price):
		return false
	player.weapons.top_up()
	player.view.cancel_reload()
	notice.emit("Energy topped up", &"good")
	return true


func buy_heal() -> bool:
	if not kiosk_available():
		return false
	if heals_left() <= 0:
		notice.emit("Snack already eaten this break", &"info")
		return false
	if player.health >= player.max_health:
		notice.emit("Health already full", &"info")
		return false
	if not _spend(waves.heal_price):
		return false
	heals_this_break += 1
	player.heal(waves.heal_amount)
	notice.emit("Boardwalk snack: health restored", &"good")
	return true


func _spend(price: int) -> bool:
	if tickets < price:
		Sfx.play(&"deny", -4.0)
		notice.emit("Not enough tickets (%d needed)" % price, &"bad")
		return false
	tickets -= price
	tickets_changed.emit(tickets)
	Sfx.play(&"purchase", -2.0)
	return true


func swap_weapon_index(index: int) -> bool:
	var list := GameData.weapons()
	if index < 0 or index >= list.size():
		return false
	return swap_weapon(list[index].id)


## Free at the kiosk during breaks. Each weapon keeps its own ammo for the run.
func swap_weapon(weapon_id: StringName) -> bool:
	if not kiosk_available():
		return false
	if player.weapons.equip(weapon_id):
		Sfx.play(&"swap", -3.0)
		return true
	return false


func _cycle_weapon(step: int) -> void:
	var list := GameData.weapons()
	var index := list.find(player.weapons.current)
	swap_weapon_index(posmod(index + step, list.size()))


# --- mastery -------------------------------------------------------------------

func _grant(weapon_id: StringName, xp: int, kills: int) -> void:
	if GameData.weapon(weapon_id) == null:
		return
	if not _run_stats.has(weapon_id):
		_run_stats[weapon_id] = {
			"xp": 0, "kills": 0,
			"xp_before": Mastery.xp(weapon_id),
			"rank_before": Mastery.rank(weapon_id),
			"unlocks": [],
		}
	var stats: Dictionary = _run_stats[weapon_id]
	stats["xp"] = int(stats["xp"]) + xp
	stats["kills"] = int(stats["kills"]) + kills
	for reward in Mastery.grant(weapon_id, xp, kills):
		stats["unlocks"].append(reward)
		Sfx.play(&"unlock", -1.0)
		reward_unlocked.emit(GameData.weapon(weapon_id), reward)


## Writes progress to disk. Called at wave boundaries, defeat, extraction and
## when a run is abandoned. XP is added to the profile exactly once, when it is
## earned; committing only persists it, so repeating a commit is harmless.
func _commit() -> void:
	Profile.save_profile()


# --- flow ----------------------------------------------------------------------

func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)


func result() -> Dictionary:
	var weapon_rows: Array = []
	for w in GameData.weapons():
		if not _run_stats.has(w.id):
			continue
		var stats: Dictionary = _run_stats[w.id]
		weapon_rows.append({
			"weapon": w,
			"xp_gained": int(stats["xp"]),
			"kills": int(stats["kills"]),
			"xp_before": int(stats["xp_before"]),
			"xp_after": Mastery.xp(w.id),
			"rank_before": int(stats["rank_before"]),
			"rank_after": Mastery.rank(w.id),
			"unlocks": stats["unlocks"],
		})
	return {
		"victory": state == State.CLEARED,
		"level": level,
		"waves_cleared": waves_cleared,
		"wave_reached": wave_number,
		"total_waves": total_waves(),
		"kills": total_kills,
		"seconds": elapsed,
		"best_wave": Profile.best_wave(level.id),
		"weapons": weapon_rows,
		"score": score.score if score else 0,
		"best_score": Profile.best_score(level.id),
		"new_best": _new_best,
		"best_combo": score.best_combo if score else 0,
		"headshots": score.headshot_kills if score else 0,
		"score_breakdown": score.breakdown.duplicate() if score else {},
	}


func _finish(victory: bool) -> void:
	if _finished:
		return
	_finished = true
	player.controls_enabled = false
	player.weapons.enabled = false
	_new_best = Profile.record_score(level.id, score.score)
	Profile.save_profile()
	var data := result()
	run_finished.emit(data)
	Events.run_finished.emit(data)
	await get_tree().create_timer(0.9 if victory else 1.6).timeout
	Game.capture_mouse(false)
	var screen = (load(RESULTS_SCENE) as PackedScene).instantiate()
	get_parent().add_child(screen)
	screen.show_result(data)


func pause() -> void:
	if _finished or get_tree().paused:
		return
	var menu = (load(PAUSE_SCENE) as PackedScene).instantiate()
	get_parent().add_child(menu)
	menu.open(self)


## Leaves the run early (from the pause menu). Earned mastery is kept.
func abandon(retry: bool) -> void:
	_finished = true
	# Progress earned so far still counts (XP, unlocks) when quitting mid-run.
	var data := result()
	data["abandoned"] = true
	Events.run_finished.emit(data)
	_commit()
	if retry:
		Game.retry()
	else:
		Game.to_menu()
