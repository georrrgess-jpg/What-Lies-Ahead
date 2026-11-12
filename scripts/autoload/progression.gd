extends Node
## Player account level (1-50) and everything that pays into it.
##
## Account XP lives in Profile.section("progression")["xp"]. Runs pay out
## through a RunTracker (scripts/progression/run_tracker.gd) created on
## Events.run_started: a share of the score and a bonus at every wave clear,
## then the level-clear and first-clear bonuses when the run is settled
## (Events.run_finished, abandoned runs included). Challenges
## (data/progression/challenges/) pay XP when completed. Tuning lives in
## data/progression/rules.tres; the level reward track is every CosmeticItem
## with a PLAYER_LEVEL requirement plus the Pier Pass stamps in the rules.

signal xp_changed(xp: int)
signal level_up(new_level: int)
## XP banked at a wave clear (score share + wave bonus), for HUD popups.
signal xp_banked(amount: int, caption: String)
## Score XP earned in the current run that is not banked yet.
signal pending_changed(amount: int)
signal challenge_completed(challenge: Challenge, weapon_id: StringName)
## Cosmetics unlocked by a level-up, a challenge or another account goal.
signal rewards_unlocked(items: Array[CosmeticItem])
## The current run was settled; `summary` is RunTracker.summary().
signal run_settled(summary: Dictionary)

const MAX_LEVEL := 50
const RULES_PATH := "res://data/progression/rules.tres"
## Settled runs kept in the profile's "runs" log.
const RUN_LOG_SIZE := 12

var rules: ProgressionRules
## The run in progress, or the last one (until the next run starts).
var tracker: RunTracker

var _level_xp := PackedInt32Array()


func _ready() -> void:
	rules = load(RULES_PATH)
	_level_xp.resize(MAX_LEVEL + 1)
	for lvl in range(2, MAX_LEVEL + 1):
		_level_xp[lvl] = _level_xp[lvl - 1] + rules.level_cost(lvl - 1)
	Events.run_started.connect(_on_run_started)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.wave_cleared.connect(_on_wave_cleared)
	Events.run_finished.connect(settle)
	Mastery.rank_up.connect(_on_rank_up)
	Mastery.reward_unlocked.connect(_on_mastery_reward)


# --- level curve -------------------------------------------------------------------

func xp() -> int:
	return int(Profile.section("progression").get("xp", 0))


## Total XP needed to reach `lvl` (level 1 = 0 XP).
func xp_for_level(lvl: int) -> int:
	return _level_xp[clampi(lvl, 1, MAX_LEVEL)]


func level() -> int:
	return level_for_xp(xp())


func level_for_xp(amount: int) -> int:
	var lvl := 1
	while lvl < MAX_LEVEL and amount >= _level_xp[lvl + 1]:
		lvl += 1
	return lvl


## 0-1 progress through the current level.
func level_progress() -> float:
	return progress_for_xp(xp())


func progress_for_xp(amount: int) -> float:
	var lvl := level_for_xp(amount)
	if lvl >= MAX_LEVEL:
		return 1.0
	var a := xp_for_level(lvl)
	var b := xp_for_level(lvl + 1)
	return clampf(float(amount - a) / float(maxi(1, b - a)), 0.0, 1.0)


## XP still needed for the next level (0 at max level).
func xp_to_next() -> int:
	var lvl := level()
	return 0 if lvl >= MAX_LEVEL else xp_for_level(lvl + 1) - xp()


## Adds XP; emits level_up for every level gained. Caller saves the profile.
func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := level()
	Profile.section("progression")["xp"] = xp() + amount
	xp_changed.emit(xp())
	var after := level()
	for l in range(before + 1, after + 1):
		level_up.emit(l)
	return after - before


## Level-clear XP for `level_id` (rises with the world's position).
func clear_xp(level_id: StringName) -> int:
	var level_data := GameData.level(level_id)
	var world_index := GameData.worlds().find(level_data.world) if level_data else 0
	return rules.clear_xp_for(world_index)


# --- reward track -------------------------------------------------------------------

## Cosmetics unlocked exactly at `lvl`.
func level_rewards(lvl: int) -> Array[CosmeticItem]:
	var out: Array[CosmeticItem] = []
	for it in GameData.cosmetics():
		if it.requirement and it.requirement.kind == Requirement.Kind.PLAYER_LEVEL and it.requirement.amount == lvl:
			out.append(it)
	return out


## The Pier Pass stamp for `lvl`: [name, description], or [] if it has none.
func stamp(lvl: int) -> PackedStringArray:
	return rules.stamp(lvl)


## One line naming what `lvl` gives, e.g. "Title: Pier Rat".
func reward_text(lvl: int) -> String:
	var items := level_rewards(lvl)
	if not items.is_empty():
		return "%s: %s" % [items[0].slot_label(), items[0].display_name]
	var s := stamp(lvl)
	return "Pier Pass stamp: %s" % s[0] if not s.is_empty() else ""


# --- challenges -------------------------------------------------------------------

## For Requirement.Kind.CHALLENGE. Weapon challenges: on `weapon_ctx`, or on any weapon.
func is_challenge_complete(id: StringName, weapon_ctx: StringName = &"") -> bool:
	var ch := ChallengeBook.find(id)
	if ch == null:
		return false
	if ch.scope == Challenge.Scope.ACCOUNT or weapon_ctx != &"":
		return ChallengeBook.is_complete(ch, weapon_ctx)
	for w in GameData.weapons():
		if ChallengeBook.is_complete(ch, w.id):
			return true
	return false


func challenge_name(id: StringName) -> String:
	var ch := ChallengeBook.find(id)
	return ch.display_name if ch else String(id)


# --- runs -------------------------------------------------------------------

## Settles the current run once (normally on Events.run_finished) and returns
## its summary; later calls return the same summary without paying again.
func settle(result: Dictionary) -> Dictionary:
	if tracker == null:
		return {}
	if not tracker.finished:
		tracker.finish(result)
		_log_run(result)
		Profile.save_profile()
		run_settled.emit(tracker.summary())
	return tracker.summary()


## Marks cosmetics that just became owned as seen and credits them to the run.
func collect_rewards(run: RunTracker) -> void:
	var fresh := Cosmetics.check_new_unlocks()
	if fresh.is_empty():
		return
	for it in fresh:
		run.rewards.append([it, &""])
	rewards_unlocked.emit(fresh)


## Credits an account reward that became owned outside collect_rewards (for
## example a total-kills item noticed while Mastery granted XP mid-run).
func credit_account_reward(it: CosmeticItem) -> void:
	if tracker and not tracker.finished:
		tracker.rewards.append([it, &""])
	var items: Array[CosmeticItem] = [it]
	rewards_unlocked.emit(items)


func _on_run_started(director: Node) -> void:
	# Whatever is owned before the run is not a reward of this run.
	Cosmetics.check_new_unlocks()
	tracker = RunTracker.new(director) if director is RunDirector else null
	# Rank-based challenges a returning save already meets count from the start.
	if tracker:
		tracker.complete(ChallengeBook.refresh_computed())


func _on_enemy_killed(enemy: Node, weapon_id: StringName, headshot: bool, _points: int) -> void:
	if tracker:
		tracker.on_kill(enemy, weapon_id, headshot)


func _on_wave_cleared(wave_number: int, _total: int) -> void:
	if tracker and not tracker.finished:
		tracker.on_wave_cleared(wave_number)
		Profile.save_profile()


func _on_rank_up(weapon: WeaponData, rank: int) -> void:
	if tracker and not tracker.finished:
		tracker.rank_ups.append([weapon.id, rank])
		# After Mastery.grant has reported its own unlocks.
		_refresh_rank_challenges.call_deferred()


func _refresh_rank_challenges() -> void:
	if tracker:
		tracker.complete(ChallengeBook.refresh_computed())


func _on_mastery_reward(weapon: WeaponData, item: CosmeticItem) -> void:
	if tracker and not tracker.finished:
		tracker.rewards.append([item, weapon.id])


func _log_run(result: Dictionary) -> void:
	var sec := Profile.section("progression")
	var runs: Array = sec.get("runs", [])
	runs.append({
		"id": tracker.id,
		"level": String(tracker.level_id),
		"victory": tracker.victory,
		"abandoned": tracker.abandoned,
		"score": int(result.get("score", 0)),
		"xp": tracker.total_xp(),
		"player_level": level(),
	})
	while runs.size() > RUN_LOG_SIZE:
		runs.pop_front()
	sec["runs"] = runs
	sec["runs_played"] = int(sec.get("runs_played", 0)) + 1
