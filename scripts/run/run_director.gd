class_name RunDirector
extends Node
## Owns one run of a level: preparation -> wave -> break -> ... -> extraction,
## with defeat reachable from combat. Generic across levels: the level scene
## supplies geometry, navigation and markers; LevelData supplies the waves.
##
## Every wave has a kind (WaveData.kind) that decides how it spawns, and may
## carry a telegraphed surge, a bounty target, an environmental twist or, for
## the finale, the world's alpha. A SpawnPlanner picks the entrance of every
## spawn, a PacingDirector eases or presses the spawn rate within the bounds
## of the Difficulty, and a lost run can be continued from the level's
## checkpoint wave. docs/ROUNDS.md describes the rules.
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
## The overshield was bought, took a hit or broke.
signal overshield_changed(value: float, maximum: float)
## The damage boost was bought (READY), started with a wave (ACTIVE) or ran out (NONE).
signal damage_boost_changed(boost: Boost)
## A surge will pour through `point` in `seconds` (the telegraph).
signal surge_warning(point: Node3D, seconds: float)
## The finale's alpha arrived (null once it has fallen).
signal boss_changed(boss: Zombie)
## A bounty target appeared (null once it was popped or got away).
signal bounty_changed(target: Zombie)
## A wave was graded at its clear: "S", "A", "B" or "C", and the tickets it paid.
signal wave_graded(number: int, grade: String, tickets: int)

enum State { PREP, WAVE, BREAK, EXTRACTION, CLEARED, DEFEAT }
enum Boost { NONE, READY, ACTIVE }

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const ZOMBIE_SCENE := "res://scenes/enemies/zombie.tscn"
const HUD_SCENE := "res://scenes/ui/hud.tscn"
const PAUSE_SCENE := "res://scenes/ui/pause_menu.tscn"
const RESULTS_SCENE := "res://scenes/ui/results.tscn"
const MAX_RECOVERIES := 2
## Station purchases without a project InputMap entry: action -> physical keycodes.
const STATION_ACTIONS := {
	&"buy_overshield": [KEY_G],
	&"buy_damage_boost": [KEY_B],
}
## Entrances a wave works at a time, by kind (0 = all of them).
const FRONTS := {&"standard": 2, &"rush": 2, &"siege": 1, &"ambush": 0, &"ranged": 0, &"bounty": 2, &"finale": 2}
## The most zombies the director keeps alive at once, whatever the wave, the
## difficulty and the pacing ask for (a performance ceiling; packs called by
## a surge or an alpha may briefly exceed it).
const CROWD_LIMIT := 18
## Seconds between the surge warning and the surge.
const SURGE_WARNING := 3.5
## Enemies this wide a flanker (EnemyData.flank_degrees) take the entrance
## behind the player once FLANK_AFTER of the wave has spawned.
const FLANKER_DEGREES := 80.0
const FLANK_AFTER := 0.4
## The last few zombies of a wave spawn at the nearest entrance, then sprint.
const CLOSE_OUT := 3
## A straggler whose walk to the player is longer than this (m) is brought
## to the nearest entrance while the player is not looking.
const REGROUP_ROUTE := 36.0
## Fraction of the wave that must have spawned before the bounty target appears.
const BOUNTY_AT := 0.3
## Seconds a bounty target lingers once it is the last thing standing.
const BOUNTY_LAST_SECONDS := 8.0
## Radius (m) of the ring around the loadout station a bounty target runs.
const BOUNTY_RING_RADIUS := 13.0
const BOUNTY_TINT := Color(0.55, 0.4, 0.05)
const BOSS_TINT := Color(0.16, 0.03, 0.14)
## Share of the wave's crowd cap that escorts an alpha while it stands.
const BOSS_ESCORT_CAP := 0.4
## Zombies an alpha calls in when it reaches a new phase, and the share of
## reserve energy the player gets back for forcing it.
const PHASE_PACK := 5
const PHASE_ENERGY := 0.2
## While an alpha stands and its horde has run out, escorts keep arriving:
## this many every REINFORCE_SECONDS while fewer than REINFORCE_BELOW are alive.
const REINFORCE_COUNT := 2
const REINFORCE_SECONDS := 7.0
const REINFORCE_BELOW := 4
## Energy a continued run starts with, as a share of each weapon's reserve.
const CONTINUE_ENERGY := 0.5

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
## Overshield health still standing (absorbs damage before health does).
var overshield := 0.0
var damage_boost := Boost.NONE
## Score paid for the tickets left over at extraction.
var tickets_cashed := 0
## The difficulty this run is played on (Difficulty.IDS).
var difficulty: StringName = Difficulty.DEFAULT
## Multiplies kill tickets during a wave (the Jackpot twist doubles them).
var ticket_scale := 1.0
## The wave this run was continued from (0 = a normal run from wave 1).
var resumed_from := 0
## The finale's alpha while it stands.
var boss: Zombie
## The bounty target while it is on the loose.
var bounty: Zombie
var pacing: PacingDirector
var planner: SpawnPlanner

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
var _enemies_root: Node3D
var _zombie_scene: PackedScene
var _finished := false
var score: ScoreKeeper
var _new_best := false
var _player_start := Vector3.ZERO
# --- the wave in progress ---
var _wave_total := 0         # enemies in the wave's list
var _spawned := 0            # of those, how many have spawned
var _wave_cap := 8           # crowd cap after the difficulty
var _wave_interval := 2.0    # spawn interval after the difficulty
var _wave_tickets := 0       # kill tickets earned this wave
var _wave_paid := 0          # tickets paid at the last wave clear (grade + difficulty bonus)
var _twist: WaveTwist
var _surge_done := false
var _surge_left := 0.0
var _surge_point: Node3D
var _boss_spawned := false
var _bounty_spawned := false
var _bounty_left := 0.0
var _reinforce_timer := 0.0
var _regroup_timer := 0.0
# --- run totals for the results ---
var _grades: Array[String] = []
var _bosses_defeated := 0
var _bounties_claimed := 0


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
			Game.weapon_id = Loadout.primary()
	waves = level.wave_set
	difficulty = Difficulty.current()
	ensure_station_actions()
	_zombie_scene = load(ZOMBIE_SCENE)
	_begin.call_deferred()


func _begin() -> void:
	var root := get_parent()
	tickets = waves.starting_tickets
	_take_checkpoint()
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
	pacing = PacingDirector.new()
	planner = SpawnPlanner.new()
	planner.setup(get_tree().get_nodes_in_group("enemy_spawn"), player)
	player.died.connect(_on_player_died)
	player.shield_changed.connect(_on_shield_changed)
	player.damaged.connect(_on_player_damaged)
	player.weapons.begin_run()
	var carried := Loadout.run_slots(Game.weapon_id)
	player.weapons.set_loadout(carried[0], carried[1])
	if resumed_from > 0:
		player.weapons.refill_fraction(CONTINUE_ENERGY)

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
	if resumed_from > 0:
		notice.emit("CHECKPOINT — WAVE %d" % resumed_from, &"banner_wave")
		notice.emit("Continuing from the checkpoint: rewards -%d%%" % int(round((1.0 - Difficulty.CONTINUE_REWARD_SCALE) * 100.0)), &"info")
	else:
		notice.emit("Get ready! Follow the marker to the Loadout Station between waves.", &"info")
	_announce_next()
	run_started.emit()
	Events.run_started.emit(self)


## Reads the checkpoint hand-over from Game: a run continued from the results
## screen starts at the checkpoint wave with the checkpoint's tickets.
func _take_checkpoint() -> void:
	var resume := Game.resume_wave
	Game.resume_wave = 0
	Game.checkpoint_wave = 0
	if resume > 1 and resume <= total_waves():
		resumed_from = resume
		wave_number = resume - 1
		waves_cleared = resume - 1
		tickets = waves.checkpoint_tickets
	Difficulty.run_reward_scale = Difficulty.CONTINUE_REWARD_SCALE if resumed_from > 0 else 1.0


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
	# Closing the window mid-run keeps what was earned, like quitting from the pause menu.
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and player != null:
		_settle_abandoned()


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
	elif event.is_action_pressed("buy_overshield"):
		buy_overshield()
	elif event.is_action_pressed("buy_damage_boost"):
		buy_damage_boost()
	elif event.is_action_pressed("kiosk_next"):
		cycle_station_weapon(1)
	elif event.is_action_pressed("kiosk_prev"):
		cycle_station_weapon(-1)


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


## The wave in progress (or the last one started); null before wave 1.
func current_wave() -> WaveData:
	return waves.waves[wave_number - 1] if wave_number >= 1 and wave_number <= total_waves() else null


## True at the end of a wave, when nothing is left to spawn and only a few
## zombies stand: they sprint, and the HUD pings where they are.
func is_closing_out() -> bool:
	return state == State.WAVE and _queue.is_empty() and not is_instance_valid(boss) \
		and _surge_left <= 0.0 and _alive.size() <= CLOSE_OUT


## The entrance a telegraphed surge is about to use (null when none is pending).
func surge_point() -> Node3D:
	return _surge_point if _surge_left > 0.0 else null


## Seconds before the bounty target escapes (0 when there is none).
func bounty_seconds_left() -> float:
	return maxf(0.0, _bounty_left) if is_instance_valid(bounty) else 0.0


## Every enemy type that appears in this level's waves.
func _level_enemies() -> Array:
	var out: Array = []
	for wave in waves.waves:
		var ids: Array = wave.spawns.keys()
		ids.append(wave.boss)
		ids.append(wave.bounty)
		for key in ids:
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
	_wave_total = _queue.size()
	_spawned = 0
	_wave_tickets = 0
	_wave_cap = maxi(2, int(round(wave.max_alive * Difficulty.value("max_alive"))))
	_wave_interval = wave.spawn_interval * Difficulty.value("interval")
	_surge_done = wave.surge_count <= 0
	_surge_left = 0.0
	_surge_point = null
	_boss_spawned = wave.boss == &""
	_bounty_spawned = wave.bounty == &""
	_reinforce_timer = REINFORCE_SECONDS
	pacing.begin_wave()
	planner.begin_wave(int(FRONTS.get(wave.kind, 2)))
	if kiosk:
		kiosk.set_open(false)
	if damage_boost == Boost.READY:
		_set_damage_boost(Boost.ACTIVE)
	_set_state(State.WAVE)
	var final := wave_number == total_waves()
	Sfx.play(&"final_wave" if final else &"wave_start", -2.0)
	if wave.kind != &"standard" and not final:
		Sfx.play(StringName("rounds_wave_%s" % wave.kind), -3.0)
	if final:
		Sfx.play_music(level.final_music(), level.music_volume_db, true)
	if wave.twist != &"":
		_twist = WaveTwist.new(wave.twist, self)
		_twist.begin()
	score.on_wave_started()
	wave_started.emit(wave_number, total_waves(), _banner_for(wave, final))


## "WAVE 3 — RUNNER RUSH: <hint>" (the HUD shows the kicker, the round's
## title and the hint as its subtitle), or the wave's own banner.
func _banner_for(wave: WaveData, final: bool) -> String:
	if wave.banner != "":
		return wave.banner
	if wave.title == "":
		return ""
	var text := ("FINAL WAVE — %s" if final else "WAVE %d — %%s" % wave_number) % wave.title
	return text + (": " + wave.hint if wave.hint != "" else "")


## The round chip during an intermission: the tier and the wave coming next.
func _announce_next() -> void:
	var text := Difficulty.label(difficulty)
	if wave_number < total_waves() and waves.waves[wave_number].title != "":
		text += "  ·  NEXT: " + waves.waves[wave_number].title
	notice.emit(text, &"round")


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
	planner.tick(delta)
	pacing.tick(delta, player, _alive, _wave_cap, _queue.size())
	_tick_surge(delta, wave)
	_tick_set_pieces(delta, wave)

	_spawn_timer -= delta
	var cap := mini(pacing.live_cap(_wave_cap), CROWD_LIMIT)
	if is_instance_valid(boss):
		# The alpha is the fight now: its escorts are a smaller crowd.
		cap = maxi(3, int(round(cap * BOSS_ESCORT_CAP)))
	if _spawn_timer <= 0.0 and not _queue.is_empty() and _alive.size() < cap and not pacing.is_relieving():
		_spawn_timer = _wave_interval / pacing.pace
		var count := mini(maxi(1, wave.burst), cap - _alive.size())
		for i in count:
			if _queue.is_empty():
				break
			if _spawn(_queue.front(), wave, planner.pick(_role_for(_queue.front(), wave))) == null:
				break
			_queue.pop_front()
			_spawned += 1
	_close_out(delta)

	# A wave ends only when nothing is queued, pending or alive.
	if _queue.is_empty() and _alive.is_empty() and _surge_left <= 0.0 and _boss_spawned and _bounty_spawned:
		_end_wave()


## Which kind of entrance the next spawn takes (see SpawnPlanner.Role).
func _role_for(enemy_id: StringName, wave: WaveData) -> SpawnPlanner.Role:
	if _queue.size() <= CLOSE_OUT and not is_instance_valid(boss):
		return SpawnPlanner.Role.CLOSE
	match wave.kind:
		&"ambush", &"ranged":
			return SpawnPlanner.Role.SPREAD
		&"siege", &"rush":
			return SpawnPlanner.Role.MAIN
	var data := GameData.enemy(enemy_id)
	if data and data.flank_degrees >= FLANKER_DEGREES and _spawned >= _wave_total * FLANK_AFTER:
		return SpawnPlanner.Role.FLANK
	return SpawnPlanner.Role.MAIN


## Spawns `enemy_id` at `point`. Returns null if nothing could be spawned
## (the enemy stays queued).
func _spawn(enemy_id: StringName, wave: WaveData, point: Node3D, spread := 1.0) -> Zombie:
	var data := GameData.enemy(enemy_id)
	if data == null or point == null:
		return null
	var z: Zombie = _zombie_scene.instantiate()
	z.setup(data, player, wave.speed_scale)
	if _twist:
		_twist.on_spawn(z)
	var offset := Vector3(randf_range(-spread, spread), 0.0, randf_range(-spread, spread))
	z.position = point.global_position + offset
	if spread > 1.0:
		# A wide pack stands on walkable ground; at an entrance off the
		# navmesh (a ramp below the deck) it keeps the usual tight cluster.
		var ground := NavigationServer3D.map_get_closest_point(player.get_world_3d().navigation_map, z.position)
		z.position = ground if ground.distance_to(z.position) < 1.0 else point.global_position + offset / spread
	z.rotation.y = point.global_rotation.y
	z.died.connect(_on_zombie_died)
	z.stalled.connect(_on_zombie_stalled)
	_enemies_root.add_child(z)
	_alive.append(z)
	return z


## The telegraphed surge: a warning names the entrance, then a pack arrives
## through it together.
func _tick_surge(delta: float, wave: WaveData) -> void:
	if not _surge_done and _spawned >= int(_wave_total * wave.surge_at) and not _queue.is_empty():
		_surge_done = true
		_surge_point = planner.surge_point()
		if _surge_point == null:
			return
		_surge_left = SURGE_WARNING
		Sfx.play(&"rounds_surge_siren", -2.0)
		notice.emit("SURGE INCOMING — %s" % SpawnPlanner.label(_surge_point), &"bad")
		surge_warning.emit(_surge_point, SURGE_WARNING)
	if _surge_left <= 0.0:
		return
	_surge_left -= delta
	if _surge_left > 0.0:
		return
	Sfx.play(&"rounds_surge_hit", -3.0)
	for i in mini(wave.surge_count, _queue.size()):
		if _spawn(_queue.front(), wave, _surge_point, 2.2) == null:
			break
		_queue.pop_front()
		_spawned += 1
	_surge_point = null


## The alpha's entrance, the bounty target's visit, and the alpha's escorts.
func _tick_set_pieces(delta: float, wave: WaveData) -> void:
	if not _boss_spawned and (_spawned >= int(_wave_total * wave.boss_at) or _queue.is_empty()):
		_boss_spawned = true
		_spawn_boss(wave)
	if not _bounty_spawned and (_spawned >= int(_wave_total * BOUNTY_AT) or _queue.is_empty()):
		_bounty_spawned = true
		_spawn_bounty(wave)
	if is_instance_valid(bounty):
		# Nothing else left: it does not hold the wave open for long.
		if _queue.is_empty() and _alive.size() <= 1:
			_bounty_left = minf(_bounty_left, BOUNTY_LAST_SECONDS)
		_bounty_left -= delta
		if _bounty_left <= 0.0:
			_alive.erase(bounty)
			bounty.escape()
			bounty = null
			bounty_changed.emit(null)
			Sfx.play(&"rounds_bounty_lost", -4.0)
			notice.emit("The bounty got away", &"info")
	if is_instance_valid(boss) and _queue.is_empty():
		_reinforce_timer -= delta
		if _reinforce_timer <= 0.0 and _alive.size() < REINFORCE_BELOW:
			_reinforce_timer = REINFORCE_SECONDS
			var escort := StringName(String(wave.spawns.keys()[0])) if not wave.spawns.is_empty() else &""
			for i in REINFORCE_COUNT:
				_spawn(escort, wave, planner.pick(SpawnPlanner.Role.MAIN))


func _spawn_boss(wave: WaveData) -> void:
	var z := _spawn(wave.boss, wave, planner.pick(SpawnPlanner.Role.MAIN), 0.0)
	if z == null:
		return
	z.set_rank(Zombie.RANK_BOSS, Difficulty.boss_health_scale() / Difficulty.enemy_health_scale(), BOSS_TINT)
	z.phase_reached.connect(_on_boss_phase)
	boss = z
	Sfx.play(&"rounds_boss_intro", 0.0)
	notice.emit("%s — HAS ARRIVED" % z.data.display_name.to_upper(), &"banner_boss")
	boss_changed.emit(z)


## The alpha crossed a health threshold: its pack arrives at once, and the
## player gets some energy back for forcing the phase.
func _on_boss_phase(z: Zombie, _phase: int) -> void:
	var wave := current_wave()
	Sfx.play(&"rounds_boss_phase", -1.0)
	var gained := player.weapons.refill_fraction(PHASE_ENERGY)
	notice.emit("%s CALLS THE HORDE%s" % [z.data.display_name.to_upper(), "  ·  +%d energy" % gained if gained > 0 else ""], &"bad")
	for i in PHASE_PACK:
		var id: StringName = _queue.front() if not _queue.is_empty() else StringName(String(wave.spawns.keys()[0]))
		if _spawn(id, wave, planner.pick(SpawnPlanner.Role.MAIN)) == null:
			break
		if not _queue.is_empty():
			_queue.pop_front()
			_spawned += 1


func _on_boss_down(z: Zombie) -> void:
	boss = null
	_bosses_defeated += 1
	# The horde breaks: nothing more arrives (the usual close-out sends the
	# last few in once only a handful stand).
	_queue.clear()
	Sfx.play(&"rounds_boss_down", 0.0)
	notice.emit("%s — DEFEATED!" % z.data.display_name.to_upper(), &"banner_boss")
	boss_changed.emit(null)


func _spawn_bounty(wave: WaveData) -> void:
	var z := _spawn(wave.bounty, wave, planner.pick(SpawnPlanner.Role.FLANK), 0.0)
	if z == null:
		return
	z.set_rank(Zombie.RANK_BOUNTY, 1.5, BOUNTY_TINT)
	# It runs; it does not leap, spit or swing.
	z.behaviours.clear()
	z.flee_points = _arena_ring(BOUNTY_RING_RADIUS, 8)
	bounty = z
	_bounty_left = wave.bounty_seconds
	Sfx.play(&"rounds_bounty_spawn", -2.0)
	notice.emit("BOUNTY ON THE RUN — pop it for +%d tickets" % wave.bounty_tickets, &"good")
	bounty_changed.emit(z)


## Points on the navmesh in a ring around the loadout station: the arena the
## player fights in, where a bounty target runs its laps.
func _arena_ring(radius: float, count: int) -> PackedVector3Array:
	var centre := kiosk.global_position if kiosk else _player_start
	var map := player.get_world_3d().navigation_map
	var out := PackedVector3Array()
	for i in count:
		var a := TAU * i / count
		out.append(NavigationServer3D.map_get_closest_point(map, centre + Vector3(cos(a), 0.0, sin(a)) * radius))
	return out


func _on_bounty_claimed(z: Zombie) -> void:
	var prize := current_wave().bounty_tickets
	bounty = null
	_bounties_claimed += 1
	tickets += prize
	tickets_changed.emit(tickets)
	Fx.ticket_popup(z.get_parent(), z.global_position + Vector3.UP * 2.4, prize, "BOUNTY +%d" % prize)
	Sfx.play(&"rounds_bounty_claimed", -1.0)
	notice.emit("BOUNTY CLAIMED  +%d TICKETS" % prize, &"good")
	bounty_changed.emit(null)


## End of a wave: the last few zombies sprint straight in, and one that is
## still a long walk away is brought to the nearest entrance out of sight.
func _close_out(delta: float) -> void:
	if not is_closing_out():
		return
	_regroup_timer -= delta
	var regroup := _regroup_timer <= 0.0
	if regroup:
		_regroup_timer = 1.0
	for z in _alive:
		if z == bounty or z.is_dead():
			continue
		z.hurry = true
		if not regroup or z.state != Zombie.State.CHASE or _recoveries.has(z.get_instance_id()):
			continue
		if planner.route_length(z.global_position) > REGROUP_ROUTE and not _in_view(z.global_position):
			_recoveries[z.get_instance_id()] = 1
			var point := planner.pick(SpawnPlanner.Role.CLOSE)
			if point:
				z.global_position = point.global_position
				z.reset_stall()


## True if the player is looking toward `at` (whatever stands in between).
func _in_view(at: Vector3) -> bool:
	var to := at - player.camera.global_position
	return (-player.camera.global_transform.basis.z).dot(to.normalized()) > 0.35


func _on_player_damaged(amount: float, _source: Vector3) -> void:
	score.on_player_damaged(amount)
	pacing.on_player_damaged(amount)


func _on_zombie_died(z: Zombie, weapon_id: StringName) -> void:
	_alive.erase(z)
	total_kills += 1
	tickets += z.data.tickets
	_wave_tickets += z.data.tickets
	if ticket_scale > 1.0:
		var extra := int(round(z.data.tickets * (ticket_scale - 1.0)))
		tickets += extra
		Fx.ticket_popup(z.get_parent(), z.global_position + Vector3.UP * 2.6, extra, "JACKPOT +%d" % extra)
	tickets_changed.emit(tickets)
	_wave_kills[weapon_id] = int(_wave_kills.get(weapon_id, 0)) + 1
	_grant(weapon_id, z.data.xp, 1)
	# Squad reaction: allies near the fallen zombie get enraged briefly.
	for other in _alive:
		if is_instance_valid(other) and other.data.enrage_radius > 0.0 \
				and other.global_position.distance_to(z.global_position) <= other.data.enrage_radius:
			other.enrage(other.data.enrage_seconds)
	var points := score.on_kill(z.data.score, z.killed_by_headshot, z.kill_distance,
		player.health / player.max_health if player else 1.0)
	if z == bounty:
		_on_bounty_claimed(z)
	elif z == boss:
		_on_boss_down(z)
	Events.enemy_killed.emit(z, weapon_id, z.killed_by_headshot, points)
	enemy_killed.emit(z, weapon_id)


## A zombie reports itself stalled when it stops making progress or loses
## contact with the player for a long time (see zombie.gd). It is moved back to
## an entrance; if that keeps happening it is removed (no rewards) so a stuck
## enemy can never hold the wave open forever. An alpha is never removed.
func _on_zombie_stalled(z: Zombie) -> void:
	if not is_instance_valid(z) or z.is_dead():
		return
	var key := z.get_instance_id()
	var count := int(_recoveries.get(key, 0)) + 1
	_recoveries[key] = count
	if count > MAX_RECOVERIES and z != boss:
		_alive.erase(z)
		_recoveries.erase(key)
		enemy_recovered.emit(z, true)
		z.despawn()
		return
	enemy_recovered.emit(z, false)
	var point := planner.pick(SpawnPlanner.Role.CLOSE)
	if point:
		z.global_position = point.global_position
		z.reset_stall()


func _end_wave() -> void:
	if state != State.WAVE:
		return
	waves_cleared = wave_number
	if damage_boost == Boost.ACTIVE:
		_set_damage_boost(Boost.NONE)
	if _twist:
		_twist.end()
		_twist = null
	var bonus := waves.wave_bonus_base + waves.wave_bonus_per_wave * wave_number
	for weapon_id in _wave_kills:
		if int(_wave_kills[weapon_id]) > 0:
			_grant(weapon_id, bonus, 0)
	_wave_kills.clear()
	score.on_wave_cleared(wave_number)
	_pay_wave_grade()
	Profile.record_wave_cleared(level.id, wave_number)
	_commit()
	wave_cleared.emit(wave_number, total_waves())
	Events.wave_cleared.emit(wave_number, total_waves())
	if wave_number >= total_waves():
		_begin_extraction()
	else:
		_begin_break()


## The wave's grade (from the damage taken, see ScoreKeeper) pays tickets,
## and the difficulty's ticket bonus on the wave's kills is settled here.
func _pay_wave_grade() -> void:
	var index := score.last_grade
	var grade: String = ScoreKeeper.GRADES[index]
	_grades.append(grade)
	var paid := waves.grade_tickets[index] if index < waves.grade_tickets.size() else 0
	paid += int(round(_wave_tickets * (Difficulty.value("tickets") - 1.0)))
	_wave_paid = paid
	if paid > 0:
		tickets += paid
		tickets_changed.emit(tickets)
	wave_graded.emit(wave_number, grade, paid)


func _begin_break() -> void:
	heals_this_break = 0
	var next := waves.waves[wave_number]
	countdown = next.rest_before if next.rest_before > 0.0 else waves.break_seconds
	_set_state(State.BREAK)
	var gained := player.weapons.refill_fraction(waves.break_refill_fraction)
	var healed := player.heal(Difficulty.value("wave_heal")) if player.health < player.max_health else 0.0
	if kiosk:
		kiosk.set_open(true)
	Sfx.play(&"wave_clear", -2.0)
	var banner := "WAVE %d CLEARED — GRADE %s" % [wave_number, _grades.back()]
	if wave_number + 1 == waves.checkpoint_wave:
		banner += " · CHECKPOINT REACHED"
		Sfx.play(&"rounds_checkpoint", -3.0)
	notice.emit(banner, &"banner_cleared")
	_announce_next()
	var extras := PackedStringArray()
	if _wave_paid > 0:
		extras.append("+%d tickets" % _wave_paid)
	if gained > 0:
		extras.append("+%d energy" % gained)
	if healed >= 1.0:
		extras.append("+%d health" % int(healed))
	if not extras.is_empty():
		notice.emit("  ·  ".join(extras), &"good")


func _begin_extraction() -> void:
	_set_state(State.EXTRACTION)
	if kiosk:
		kiosk.set_open(false)
	if portal:
		portal.activate()
	Sfx.play(&"portal_open", 0.0)
	Sfx.play_music(level.final_music(), level.music_volume_db, true)
	notice.emit("PORTAL OPEN — FOLLOW THE LIGHTS", &"banner_portal")


func _on_portal_entered() -> void:
	if state != State.EXTRACTION:
		return
	_set_state(State.CLEARED)
	_cash_in_tickets()
	Profile.record_level_cleared(level.id)
	_commit()
	Sfx.play(&"level_clear", 0.0)
	_finish(true)


func _on_player_died() -> void:
	if state == State.CLEARED or state == State.DEFEAT:
		return
	_set_state(State.DEFEAT)
	# Past the checkpoint the run can be continued from it (see Game.continue_run).
	if waves.checkpoint_wave > 1 and wave_number >= waves.checkpoint_wave:
		Game.checkpoint_wave = waves.checkpoint_wave
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
		notice.emit("One %s per break" % level.heal_item_name.to_lower(), &"info")
		return false
	if player.health >= player.max_health:
		notice.emit("Health already full", &"info")
		return false
	if not _spend(waves.heal_price):
		return false
	heals_this_break += 1
	player.heal(waves.heal_amount)
	notice.emit("%s: health restored" % level.heal_item_name, &"good")
	return true


## An extra health layer on top of the health bar; buying again refills it.
func buy_overshield() -> bool:
	if not kiosk_available():
		return false
	if overshield >= waves.overshield_amount:
		notice.emit("Overshield already full", &"info")
		return false
	if not _spend(waves.overshield_price):
		return false
	player.set_shield(waves.overshield_amount, waves.overshield_amount)
	Sfx.play(&"reload_materialize", -4.0, 0.8)
	notice.emit("Overshield up: +%d shield" % int(waves.overshield_amount), &"good")
	return true


## More damage for the whole next wave (one boost at a time).
func buy_damage_boost() -> bool:
	if not kiosk_available():
		return false
	if damage_boost != Boost.NONE:
		notice.emit("Damage boost already loaded", &"info")
		return false
	if not _spend(waves.damage_boost_price):
		return false
	_set_damage_boost(Boost.READY)
	Sfx.play(&"weap_rail_ready", -6.0, 1.2)
	notice.emit("Damage boost: +%d%% damage next wave" % boost_percent(), &"good")
	return true


## The damage boost as a whole percentage (20 for +20%).
func boost_percent() -> int:
	return int(round((waves.damage_boost_scale - 1.0) * 100.0))


func _set_damage_boost(value: Boost) -> void:
	damage_boost = value
	player.weapons.damage_multiplier = waves.damage_boost_scale if value == Boost.ACTIVE else 1.0
	damage_boost_changed.emit(value)


## Mirrors the player's shield for the HUD and plays its block/break sounds.
func _on_shield_changed(current: float, maximum: float) -> void:
	var was := overshield
	overshield = current
	overshield_changed.emit(current, maximum)
	if current < was:
		if current <= 0.0:
			Sfx.play(&"neon_shield_break", -8.0, 1.2)
			notice.emit("Overshield down", &"bad")
		else:
			Sfx.play(&"neon_shield_block", -10.0, 1.3)


## Leftover tickets become score when the player escapes through the portal.
func _cash_in_tickets() -> void:
	tickets_cashed = tickets * waves.ticket_score_rate
	if tickets_cashed <= 0 or score == null:
		return
	score.breakdown["tickets"] = tickets_cashed
	score.score += tickets_cashed
	score.award.emit("%d TICKETS CASHED" % tickets, tickets_cashed, UiKit.AMBER)
	score.score_changed.emit(score.score, tickets_cashed)


## Adds the station purchase keys to the InputMap unless the project has them.
static func ensure_station_actions() -> void:
	for action in STATION_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in STATION_ACTIONS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action, e)


func _spend(price: int) -> bool:
	if tickets < price:
		Sfx.play(&"deny", -4.0)
		notice.emit("Not enough tickets (%d needed)" % price, &"bad")
		return false
	tickets -= price
	tickets_changed.emit(tickets)
	Sfx.play(&"purchase", -2.0)
	return true


## Free at the loadout station during breaks: puts `weapon_id` in the held
## slot. Each weapon keeps its own ammo for the run.
func swap_weapon(weapon_id: StringName) -> bool:
	if not kiosk_available() or not GameData.is_weapon_unlocked(GameData.weapon(weapon_id)):
		return false
	if player.weapons.equip(weapon_id):
		Sfx.play(&"swap", -3.0)
		return true
	return false


## Weapons the held slot can be swapped to at the station (every unlocked
## weapon except the one in the other slot), in menu order.
func station_weapons() -> Array[WeaponData]:
	var other := player.weapons.slots[1 - player.weapons.active_slot]
	var out: Array[WeaponData] = []
	for w in Loadout.available():
		if w.id != other:
			out.append(w)
	return out


## Loadout station: swaps the held slot to the next (step 1) or previous
## (step -1) weapon of station_weapons().
func cycle_station_weapon(step: int) -> bool:
	var options := station_weapons()
	if options.size() <= 1:
		return false
	var index := options.find(player.weapons.current)
	return swap_weapon(options[posmod(index + step, options.size())].id)


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


## The run so far, for the results screen, progression and the event bus.
## Keys added for rounds: difficulty, difficulty_label, reward_scale,
## resumed_from, checkpoint_wave, can_continue, grades, bosses_defeated,
## bounties_claimed.
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
		"tickets_left": tickets,
		"tickets_cashed": tickets_cashed,
		"difficulty": difficulty,
		"difficulty_label": Difficulty.label(difficulty),
		"reward_scale": Difficulty.reward_scale(),
		"resumed_from": resumed_from,
		"checkpoint_wave": waves.checkpoint_wave,
		"can_continue": state == State.DEFEAT and Game.can_continue_run(),
		"grades": _grades.duplicate(),
		"bosses_defeated": _bosses_defeated,
		"bounties_claimed": _bounties_claimed,
	}


func _finish(victory: bool) -> void:
	if _finished:
		return
	_finished = true
	_freeze_player()
	# A multi-kill still counting down belongs to this run's score.
	score.flush()
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


func _freeze_player() -> void:
	player.controls_enabled = false
	player.weapons.enabled = false
	player.invulnerable = true


## Progress earned so far still counts (XP, unlocks) when a run ends early.
func _settle_abandoned() -> void:
	if _finished:
		return
	_finished = true
	_freeze_player()
	var data := result()
	data["abandoned"] = true
	Events.run_finished.emit(data)
	_commit()


func pause() -> void:
	if _finished or get_tree().paused:
		return
	var menu = (load(PAUSE_SCENE) as PackedScene).instantiate()
	get_parent().add_child(menu)
	menu.open(self)


## Leaves the run early (from the pause menu). Earned mastery is kept.
func abandon(retry: bool) -> void:
	_settle_abandoned()
	# The level stays on screen under the loading card: stop it playing on.
	get_parent().process_mode = Node.PROCESS_MODE_DISABLED
	if retry:
		Game.retry()
	else:
		Game.to_menu()
