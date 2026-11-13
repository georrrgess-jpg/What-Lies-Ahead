class_name RunTracker
extends RefCounted
## Progression bookkeeping for one run, created by the Progression autoload on
## Events.run_started and fed by the Events bus:
##   - counts run stats and feeds the contracts (ContractBoard) and the
##     milestones (ChallengeBook), paying their XP, Sparks and mastery XP,
##   - grants mastery bonuses (headshot, multi-kill and longshot finishing blows),
##   - banks account XP: score share and wave bonus at every wave clear,
##     contract and milestone rewards on completion, the rest when the run
##     finishes (wave and clear XP are scaled by the difficulty).
## Every bank has a key, so nothing is paid twice even if an event repeats;
## finish() runs once, also for abandoned runs (what was earned is kept).

const LOW_HEALTH := 0.25

var id := ""
var director: RunDirector
var level_id: StringName
var finished := false
var victory := false
var abandoned := false

var xp_before := 0
var level_before := 1
## Account XP banked this run per breakdown label, in award order.
var lines := {}
## [challenge, weapon_id] milestones completed this run.
var challenges: Array = []
## Contract entries (see ContractBoard) completed this run, and the ones dealt
## to replace them when the run was settled.
var contracts: Array = []
var new_contracts: Array = []
## [cosmetic, weapon_id] unlocked this run (weapon_id empty for account rewards).
var rewards: Array = []
## [weapon_id, rank] reached this run.
var rank_ups: Array = []
## weapon_id -> { "Headshots": xp, "Multi-kills": xp, "Longshots": xp }
var mastery_bonus := {}
var stats := {"kills": 0, "headshots": 0, "multi_kills": 0, "longshots": 0, "close_calls": 0, "heavy_kills": 0, "flawless_waves": 0, "best_combo": 0}
var min_health := 1.0

var _keys := {}
var _score_xp := 0
var _wave_damage := 0.0
var _chain := 0
var _chain_time := -100.0


func _init(run: RunDirector) -> void:
	director = run
	level_id = run.level.id if run.level else &""
	id = "%d-%06d" % [int(Time.get_unix_time_from_system()), randi() % 1000000]
	xp_before = Progression.xp()
	level_before = Progression.level()
	run.wave_started.connect(func(_n, _t, _b): _wave_damage = 0.0)
	if run.player:
		run.player.damaged.connect(_on_damaged)
		run.player.health_changed.connect(_on_health_changed)


## Score XP earned this run that is not banked yet (banked at the next wave clear).
func pending_xp() -> int:
	if not is_instance_valid(director) or director.score == null:
		return 0
	return maxi(0, _score_target(director.score.score) - _score_xp)


func total_xp() -> int:
	var total := 0
	for label in lines:
		total += int(lines[label])
	return total


# --- events --------------------------------------------------------------------

func on_kill(enemy: Node, weapon_id: StringName, headshot: bool) -> void:
	if finished:
		return
	var z := enemy as Zombie
	var now := director.elapsed if is_instance_valid(director) else 0.0
	_chain = _chain + 1 if now - _chain_time <= ScoreKeeper.MULTI_WINDOW else 1
	_chain_time = now
	var longshot := z != null and z.kill_distance >= ScoreKeeper.LONGSHOT_DISTANCE
	var health := _health_fraction()
	_count(&"kills", weapon_id)
	if headshot:
		_count(&"headshots", weapon_id)
	if longshot:
		_count(&"longshots", weapon_id)
	if _chain == 2:
		_count(&"multi_kills", weapon_id)
	if health > 0.0 and health < LOW_HEALTH:
		_count(&"close_calls", weapon_id)
	if z and z.data and z.data.heavy:
		_count(&"heavy_kills", weapon_id)
	if is_instance_valid(director) and director.score:
		_best(&"best_combo", director.score.combo)
	_mastery_bonus(weapon_id, z.data.xp if z and z.data else 0, headshot, longshot)
	Progression.pending_changed.emit(pending_xp())


func on_wave_cleared(wave_number: int) -> void:
	if finished:
		return
	if _wave_damage <= 0.0:
		_count(&"flawless_waves", _current_weapon())
	_count(&"waves", &"")
	_wave_damage = 0.0
	var before := total_xp()
	_bank("wave:%d" % wave_number, "Wave bonuses", _scaled(Progression.rules.wave_xp(wave_number)))
	_bank_score(director.score.score if is_instance_valid(director) and director.score else 0)
	Progression.collect_rewards(self)
	Progression.xp_banked.emit(total_xp() - before, "WAVE %d" % wave_number)
	Progression.pending_changed.emit(0)


## Settles the run (victory, defeat or abandon). Runs once.
func finish(result: Dictionary) -> void:
	if finished:
		return
	victory = bool(result.get("victory", false))
	abandoned = bool(result.get("abandoned", false))
	# Waves whose clear event was missed still pay (keys stop double payment).
	for n in range(1, int(result.get("waves_cleared", 0)) + 1):
		_bank("wave:%d" % n, "Wave bonuses", _scaled(Progression.rules.wave_xp(n)))
	var score := int(result.get("score", 0))
	_bank_score(score)
	_best(&"run_score", score)
	if victory:
		_bank("clear", "Level clear", _scaled(Progression.clear_xp(level_id)))
		var firsts: Array = Profile.section("progression").get("first_clears", [])
		if level_id != &"" and not firsts.has(String(level_id)):
			firsts.append(String(level_id))
			Profile.section("progression")["first_clears"] = firsts
			_bank("first_clear", "First clear", _scaled(Progression.rules.first_clear_xp))
		_count(&"clears", &"")
		if min_health >= LOW_HEALTH:
			_count(&"healthy_clears", &"")
	finished = true
	Progression.collect_rewards(self)
	new_contracts = ContractBoard.roll_over()


## Everything the results screen shows about this run's progression.
func summary() -> Dictionary:
	var ordered: Array = []
	for label in lines:
		ordered.append([label, int(lines[label])])
	return {
		"id": id,
		"xp_before": xp_before,
		"xp_after": Progression.xp(),
		"level_before": level_before,
		"level_after": Progression.level(),
		"total": total_xp(),
		"lines": ordered,
		"challenges": challenges,
		"contracts": contracts,
		"new_contracts": new_contracts,
		"rewards": rewards,
		"rank_ups": rank_ups,
		"mastery_bonus": mastery_bonus,
		"victory": victory,
		"abandoned": abandoned,
	}


# --- internals -------------------------------------------------------------------

## Adds an account stat sample from outside the tracker (Sparks banked, ...).
func count(stat: StringName, amount := 1) -> void:
	if not finished:
		_count(stat, &"", amount)


## Adds a stat sample and pays out any contract or milestone it completes.
func _count(stat: StringName, weapon_id: StringName, amount := 1) -> void:
	if stats.has(stat):
		stats[stat] = int(stats[stat]) + amount
	_complete_contracts(ContractBoard.record(stat, amount, weapon_id))
	complete(ChallengeBook.record(stat, amount, weapon_id))


func _best(stat: StringName, value: int) -> void:
	if stats.has(stat):
		stats[stat] = maxi(int(stats[stat]), value)
	_complete_contracts(ContractBoard.record(stat, value))
	complete(ChallengeBook.record(stat, value))


## Pays out contracts that were just completed (ContractBoard entries).
func _complete_contracts(entries: Array) -> void:
	for entry in entries:
		var ch := ContractBoard.template(entry)
		contracts.append(entry)
		_bank("contract:%d" % contracts.size(), "Contracts", ch.xp)
		Wallet.earn(ch.sparks, &"contract")
		Progression.contract_completed.emit(entry)
	for entry in entries:
		var ch := ContractBoard.template(entry)
		if ch.mastery_xp > 0 and String(entry.get("weapon", "")) != "":
			Mastery.grant(StringName(String(entry["weapon"])), ch.mastery_xp)


## Pays out newly completed milestones ([challenge, weapon_id] pairs).
func complete(pairs: Array) -> void:
	if pairs.is_empty():
		return
	for pair in pairs:
		var ch: Challenge = pair[0]
		challenges.append(pair)
		_bank("challenge:" + ch.key(pair[1]), "Milestones", ch.xp)
		Wallet.earn(ch.sparks, &"milestone")
		Progression.challenge_completed.emit(ch, pair[1])
	# Account rewards first, so Mastery.grant only reports weapon unlocks.
	Progression.collect_rewards(self)
	for pair in pairs:
		if pair[1] != &"" and pair[0].mastery_xp > 0:
			Mastery.grant(pair[1], pair[0].mastery_xp)


func _bank(key: String, label: String, amount: int) -> void:
	if amount <= 0 or _keys.has(key):
		return
	_keys[key] = amount
	_add(label, amount)


## Score XP is cumulative: bank whatever the run's score is worth beyond what was banked.
func _bank_score(score: int) -> void:
	var target := _score_target(score)
	if target > _score_xp:
		var delta := target - _score_xp
		_score_xp = target
		_add("Score", delta)


func _add(label: String, amount: int) -> void:
	lines[label] = int(lines.get(label, 0)) + amount
	Progression.add_xp(amount)


func _score_target(score: int) -> int:
	return int(floor(score * Progression.rules.score_xp_rate))


## Wave and clear XP follow the difficulty's reward scale (the score share
## follows the score itself).
static func _scaled(amount: int) -> int:
	return int(round(amount * Difficulty.reward_scale()))


func _mastery_bonus(weapon_id: StringName, base_xp: int, headshot: bool, longshot: bool) -> void:
	var curve := Mastery.curve
	var parts := {}
	if headshot:
		parts["Headshots"] = int(round(base_xp * curve.headshot_bonus))
	if _chain >= 2:
		parts["Multi-kills"] = curve.multi_kill_bonus * (_chain - 1)
	if longshot:
		parts["Longshots"] = curve.longshot_bonus
	var total := 0
	var entry: Dictionary = mastery_bonus.get(weapon_id, {})
	for k in parts:
		entry[k] = int(entry.get(k, 0)) + int(parts[k])
		total += int(parts[k])
	if total > 0:
		mastery_bonus[weapon_id] = entry
		Mastery.grant(weapon_id, total)


func _on_damaged(amount: float, _source: Vector3) -> void:
	if is_instance_valid(director) and director.state == RunDirector.State.WAVE:
		_wave_damage += amount


func _on_health_changed(current: float, maximum: float) -> void:
	if finished or current <= 0.0:
		return
	min_health = minf(min_health, current / maxf(1.0, maximum))


func _health_fraction() -> float:
	if not is_instance_valid(director) or director.player == null:
		return 1.0
	return director.player.health / maxf(1.0, director.player.max_health)


func _current_weapon() -> StringName:
	if is_instance_valid(director) and director.player and director.player.weapons.current:
		return director.player.weapons.current.id
	return &""
