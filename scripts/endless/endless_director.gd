class_name EndlessDirector
extends Node
## The Endless side of a run, owned by the RunDirector when its level is
## endless (LevelData.is_endless()): the districts and their gates, the
## spawn pool and entrances of the open districts, the waves (EndlessWaves)
## and how tough each wave's zombies are, the traps and supply drops, the
## district the player stands in, and the records. docs/ENDLESS.md.
##
## The RunDirector asks it for each wave, hands it every zombie it spawns
## and tells it when waves start and end; the HUD widget (EndlessHud) reads
## prompt(), current_district() and the signals below.

## A district was opened this run (by paying at one of its gates).
signal district_opened(district: EndlessDistrict)
## The player walked into another district.
signal district_entered(district: EndlessDistrict)
## A supply crate is on its way (null once it has been picked up).
signal supply_changed(crate: EndlessSupply)
## A new best wave was reached during this run.
signal new_best(wave: int)

## Seconds the interact key is held to pay at a gate or arm a trap.
const HOLD_SECONDS := 0.5
## Spawn-planner bonus for the entrances of the player's own district.
const HOME_BIAS := 2.5
## Heavies take this share of the wave's health growth.
const HEAVY_GROWTH := 0.5
## Breaks before a boss wave are this much longer.
const BOSS_REST := 1.4
## Enemies that stand in for the city's own until they exist (the map and the
## zombies are built alongside this mode; an id missing from the catalog uses
## its stand-in instead of breaking the run).
const STAND_INS := {
	&"city_shambler": &"tourist_shambler",
	&"city_runner": &"lifeguard_runner",
	&"city_bruiser": &"boardwalk_bruiser",
	&"riot_shield": &"riot_bruiser",
	&"tunnel_crawler": &"hover_courier",
	&"firebug": &"mall_flinger",
	&"the_wrecker": &"alpha_bruiser",
}

var run: RunDirector
var rules: EndlessRules
var waves: EndlessWaves
## District id -> true for every district open in this run.
var opened := {}
## Districts opened in this run, in order (ids).
var opened_order: Array[StringName] = []
## The best wave before this run started.
var best_before := 0
## Districts opened in earlier runs (id -> true).
var opened_before := {}
var supply: EndlessSupply
## The interactable the player is at (an EndlessGate or EndlessTrap), and how
## long the interact key has been held there.
var focus: Node3D
var hold := 0.0

var _gates: Array[EndlessGate] = []
var _areas: Array[Area3D] = []
var _traps: Array[EndlessTrap] = []
var _drops: Array[Node3D] = []
var _spawns: Array[Node3D] = []
var _current: EndlessDistrict
var _area_timer := 0.0
var _new_best_shown := false


## The station economy of an endless level: its rules' WaveSet with no waves
## (the run fills them in), or a default one.
static func make_wave_set(level: LevelData) -> WaveSet:
	var base := level.endless.economy
	var out: WaveSet = base.duplicate() if base else WaveSet.new()
	out.waves = []
	out.checkpoint_wave = 0
	return out


func setup(director: RunDirector) -> void:
	run = director
	rules = run.level.endless
	waves = EndlessWaves.new(rules)
	best_before = EndlessRecords.best_wave()
	for d in rules.districts:
		if EndlessRecords.has_opened(d.id):
			opened_before[d.id] = true
	var start := rules.start_district()
	if start:
		opened[start.id] = true
		_current = start
	var tree := run.get_tree()
	for node in tree.get_nodes_in_group("enemy_spawn"):
		if node is Node3D:
			_spawns.append(node)
	for node in tree.get_nodes_in_group("endless_district_area"):
		if node is Area3D:
			_areas.append(node)
	for node in tree.get_nodes_in_group("endless_gate"):
		var gate := node as EndlessGate
		if gate == null:
			continue
		gate.bind(rules.district(gate.district))
		if opened.has(gate.district):
			gate.open(false)
		_gates.append(gate)
	_build_features()


# --- queries ---------------------------------------------------------------------

## The districts open now, in the rules' order.
func open_districts() -> Array[EndlessDistrict]:
	var out: Array[EndlessDistrict] = []
	for d in rules.districts:
		if opened.has(d.id):
			out.append(d)
	return out


func is_open(id: StringName) -> bool:
	return opened.has(id)


## The district the player stands in (the start district until they leave it).
func current_district() -> EndlessDistrict:
	return _current


## The entrances of the open districts (an entrance without a district
## belongs to the start district).
func open_spawns() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for p in _spawns:
		if opened.has(_district_of(p)):
			out.append(p)
	return out


## An enemy id the catalog has: `id` itself or its stand-in.
static func resolve(id: StringName) -> StringName:
	if GameData.enemy(id) == null and STAND_INS.has(id) and GameData.enemy(STAND_INS[id]):
		return STAND_INS[id]
	return id


## The enemies the open districts field, by role: "regular", "fast",
## "heavy" (EnemyData.heavy) and "special" (the districts' own that are not heavies).
func pool() -> Dictionary:
	var out := {"regular": [], "fast": [], "heavy": [], "special": []}
	for raw in rules.base_enemies:
		var e := GameData.enemy(resolve(raw))
		if e == null:
			continue
		var role := "heavy" if e.heavy else ("fast" if e.move_speed >= 4.0 else "regular")
		if not (out[role] as Array).has(e.id):
			out[role].append(e.id)
	for d in open_districts():
		for raw in d.enemies:
			var e := GameData.enemy(resolve(raw))
			if e == null:
				continue
			# A heavy (the riot squad, the Tower's bruisers) joins the heavies'
			# share; the others are the wave's specials.
			var role := "heavy" if e.heavy else "special"
			if not (out[role] as Array).has(e.id):
				out[role].append(e.id)
	return out


## Every enemy an endless run can field (for the shader warm-up).
func all_enemies() -> Array:
	var out: Array = []
	var ids: Array[StringName] = []
	ids.append_array(rules.base_enemies)
	for d in rules.districts:
		ids.append_array(d.enemies)
	ids.append(rules.boss_id)
	for raw in ids:
		var e := GameData.enemy(resolve(raw))
		if e and not out.has(e):
			out.append(e)
	return out


## Enemy health multiplier of the wave in progress (traps scale with it too).
func health_scale() -> float:
	return rules.health_scale(maxi(1, run.wave_number))


## Seconds of the break before wave `next`.
func rest_before(next: int) -> float:
	var rest := run.waves.break_seconds
	return rest * BOSS_REST if waves.kind_of(next) == &"boss" else rest


## The banner title of wave `n` for the round chip ("" for a plain wave).
func title_of(n: int) -> String:
	return waves.title_of(n)


# --- the run director's hooks --------------------------------------------------------

## Wave `n`, from the enemies of the districts open now.
func build_wave(n: int) -> WaveData:
	return waves.build(n, pool())


## A freshly set-up zombie of wave `n`: tougher and harder-hitting with the
## wave. Heavies grow at half the rate (they are already the tanks and hit hardest).
func prepare(z: Zombie, n: int) -> void:
	z.max_health *= _growth(z, n)
	z.health = z.max_health
	var d := 1.0 + (rules.damage_scale(n) - 1.0) * (HEAVY_GROWTH if z.data.heavy else 1.0)
	z.damage_scale *= d
	for b in z.behaviours:
		for field in Zombie.BEHAVIOUR_DAMAGE_FIELDS:
			if field in b:
				b.set(field, float(b.get(field)) * d)


## set_rank() health factor of `boss` on wave `n` (its own curve, not the horde's).
func boss_rank_scale(boss: Zombie, n: int) -> float:
	return Difficulty.boss_health_scale() * rules.boss_scale(n) / (Difficulty.enemy_health_scale() * _growth(boss, n))


## The health factor prepare() gives `z` on wave `n`.
func _growth(z: Zombie, n: int) -> float:
	return 1.0 + (rules.health_scale(n) - 1.0) * (HEAVY_GROWTH if z.data.heavy else 1.0)


## Tickets a kill of `z` pays on wave `n`.
func kill_tickets(z: Zombie, n: int) -> int:
	return int(round(z.data.tickets * rules.ticket_scale(n)))


func on_wave_started(n: int) -> void:
	var kind := waves.kind_of(n)
	Sfx.play(&"end_wave_horn", -3.0)
	if kind == &"boss":
		Sfx.play(&"end_boss_siren", -2.0)
		Sfx.play_music(run.level.final_music(), run.level.music_volume_db, true)
	# The first run ever sets the record; later runs announce beating it once.
	if EndlessRecords.note_wave(n, run.difficulty) and best_before > 0 and not _new_best_shown:
		_new_best_shown = true
		Sfx.play(&"end_new_best", -2.0)
		run.notice.emit("NEW BEST WAVE!  (was %d)" % best_before, &"good")
		new_best.emit(n)
	_collect_unlocks()


func on_wave_cleared(n: int) -> void:
	if waves.kind_of(n) == &"boss":
		Sfx.play_music(run.level.music, run.level.music_volume_db, true)
	if rules.supply_every > 0 and n % rules.supply_every == 0:
		_drop_supplies(n)


## The arena a bounty target runs its laps in: the player's district.
func arena_centre() -> Vector3:
	if _current and _current == rules.start_district() and run.kiosk:
		return run.kiosk.global_position
	for area in _areas:
		if _district_of(area) == (_current.id if _current else &""):
			return area.global_position
	return run.player.global_position


## What the run adds to RunDirector.result() under "endless".
func result() -> Dictionary:
	var names: Array = []
	for id in opened_order:
		var d := rules.district(id)
		names.append(d.display_name if d else String(id))
	return {
		"opened": opened_order.map(func(id: StringName) -> String: return String(id)),
		"opened_names": names,
		"first_opened": opened_order.filter(func(id: StringName) -> bool: return not opened_before.has(id)).map(func(id: StringName) -> String: return String(id)),
		"districts_open": open_districts().size(),
		"districts_total": rules.districts.size(),
		"best_before": best_before,
		"new_best_wave": run.wave_number > best_before,
	}


# --- per frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	if run == null or run.player == null or not run.player.alive or run.state in [RunDirector.State.CLEARED, RunDirector.State.DEFEAT]:
		focus = null
		hold = 0.0
		return
	_area_timer -= delta
	if _area_timer <= 0.0:
		_area_timer = 0.25
		_track_district()
	_tick_interaction(delta)


## The gate or trap the player stands at, and the hold of the interact key.
func _tick_interaction(delta: float) -> void:
	var best: Node3D = null
	var best_d := INF
	for gate in _gates:
		if gate.player_inside and not gate.is_open:
			var d := gate.global_position.distance_to(run.player.global_position)
			if d < best_d:
				best = gate
				best_d = d
	if best == null:
		for trap in _traps:
			if trap.player_inside and opened.has(trap.district):
				var d := trap.global_position.distance_to(run.player.global_position)
				if d < best_d:
					best = trap
					best_d = d
	if best != focus:
		focus = best
		hold = 0.0
	if focus == null or not Input.is_action_pressed("interact"):
		hold = 0.0
		return
	var p: Dictionary = focus.prompt()
	if p.is_empty() or p.get("disabled", false):
		hold = 0.0
		return
	hold += delta
	if hold < HOLD_SECONDS:
		return
	hold = 0.0
	if focus is EndlessGate:
		_buy_gate(focus)
	elif focus is EndlessTrap:
		_buy_trap(focus)


func _buy_gate(gate: EndlessGate) -> void:
	var d := gate.data
	if d == null or opened.has(d.id):
		return
	if run.tickets < d.price:
		gate.deny()
		run.notice.emit("Not enough tickets (%d needed)" % d.price, &"bad")
		return
	run.spend_tickets(d.price)
	open_district(d)


## Opens district `d` for the rest of the run: every gate of it opens, its
## entrances wake, its enemies join the pool and the HUD reveals it.
func open_district(d: EndlessDistrict) -> void:
	if opened.has(d.id):
		return
	opened[d.id] = true
	opened_order.append(d.id)
	for gate in _gates:
		if gate.district == d.id:
			gate.open()
	run.planner.set_points(open_spawns())
	refresh_bias()
	EndlessRecords.note_opened(d.id)
	Profile.save_profile()
	Sfx.play(&"end_gate_sting", -1.0)
	run.notice.emit("%s — %s" % [d.display_name.to_upper(), d.blurb], &"banner_district")
	var added: Array = []
	for raw in d.enemies:
		var e := GameData.enemy(resolve(raw))
		if e:
			added.append(e.display_name)
	if not added.is_empty():
		run.notice.emit("New in the city: %s" % ", ".join(added), &"bad")
	district_opened.emit(d)
	_collect_unlocks()


func _buy_trap(trap: EndlessTrap) -> void:
	if trap.state != EndlessTrap.State.READY:
		return
	if run.tickets < trap.price:
		Sfx.play(&"deny", -4.0)
		run.notice.emit("Not enough tickets (%d needed)" % trap.price, &"bad")
		return
	run.spend_tickets(trap.price)
	trap.arm()
	run.notice.emit("%s armed for %d s" % ["Fire trap" if trap.kind == EndlessTrap.FIRE else "Shock trap", int(trap.seconds)], &"good")


## Which district the player stands in (the last area entered wins while
## areas overlap; between areas it stays as it was).
func _track_district() -> void:
	var here: StringName = &""
	for area in _areas:
		if area.overlaps_body(run.player):
			here = _district_of(area)
			if _current and here == _current.id:
				return
	if here == &"" or (_current and here == _current.id):
		return
	var d := rules.district(here)
	if d == null:
		return
	_current = d
	refresh_bias()
	Sfx.play(&"end_district_enter", -6.0)
	district_entered.emit(d)


## The spawn planner prefers the entrances of the district the player is in.
func refresh_bias() -> void:
	var bias := PackedFloat32Array()
	var home := _current.id if _current else &""
	for p in run.planner.points():
		bias.append(HOME_BIAS if _district_of(p) == home else 0.0)
	run.planner.set_bias(bias)


# --- features ----------------------------------------------------------------------

## Builds a trap at every trap marker and keeps the supply-drop markers.
func _build_features() -> void:
	for node in run.get_tree().get_nodes_in_group("endless_feature"):
		var marker := node as Node3D
		if marker == null:
			continue
		var kind := StringName(String(marker.get_meta(&"kind", "")))
		if kind == &"supply_drop":
			_drops.append(marker)
		elif kind in [EndlessTrap.FIRE, EndlessTrap.SHOCK]:
			var trap := EndlessTrap.new()
			trap.name = "Trap_%s" % marker.name
			trap.kind = kind
			trap.district = _district_of(marker)
			trap.radius = float(marker.get_meta(&"radius", 4.5))
			trap.price = rules.trap_price
			trap.seconds = rules.trap_seconds
			trap.cooldown = rules.trap_cooldown
			trap.director = run
			marker.add_child(trap)
			_traps.append(trap)


## A crate lands at a drop marker in an open district: in the player's own
## district if it has one, else the nearest open one.
func _drop_supplies(n: int) -> void:
	if _drops.is_empty() or run.player == null:
		return
	if is_instance_valid(supply):
		supply.queue_free()
	var best: Node3D = null
	var best_score := INF
	for m in _drops:
		var id := _district_of(m)
		if not opened.has(id):
			continue
		var score := m.global_position.distance_to(run.player.global_position)
		if _current and id == _current.id:
			score -= 1000.0
		if score < best_score:
			best_score = score
			best = m
	if best == null:
		return
	supply = EndlessSupply.new()
	supply.name = "SupplyCrate"
	supply.director = run
	supply.tickets = rules.supply_tickets + rules.supply_tickets_per_wave * n
	supply.heal = rules.supply_heal
	supply.collected.connect(func(_c): supply_changed.emit(null))
	run.get_parent().add_child(supply)
	supply.global_position = best.global_position
	var d := rules.district(_district_of(best))
	run.notice.emit("SUPPLY DROP INCOMING — %s" % (d.display_name.to_upper() if d else "NEARBY"), &"good")
	supply_changed.emit(supply)


# --- helpers ---------------------------------------------------------------------

## The district a marker, area or entrance belongs to (meta "district"; the
## start district when it has none).
func _district_of(node: Node) -> StringName:
	if node.has_meta(&"district"):
		return StringName(String(node.get_meta(&"district")))
	var start := rules.start_district()
	return start.id if start else &""


## Cosmetics and weapons an Endless record just unlocked are announced now.
func _collect_unlocks() -> void:
	if Progression.tracker and not Progression.tracker.finished:
		Progression.collect_rewards(Progression.tracker)
