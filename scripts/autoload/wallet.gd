extends Node
## The player's Sparks: the permanent currency.
##
## Every zombie carries a stolen Spark (the glow in its eyes). Popping one
## sets it free, and the player banks it. Sparks are earned by playing (kills,
## waves, clears, level-ups, mastery, contracts, leftover tickets) and spent in
## the shop on cosmetics that are for sale (CosmeticItem.price > 0). They never
## buy power: weapons and anything that changes combat come from progression.
##
## State lives in Profile.section("wallet"). Earning during a run only changes
## memory; the run director's commits save it. Spending saves immediately.
##
## What everything pays is in data/progression/economy.tres (EconomyRules).
## During a run a SparkLedger (`run`) pays the kills, waves and the clear and
## keeps the breakdown the results screen shows (settle()).

## The balance changed (earned or spent).
signal balance_changed(balance: int)
signal earned(amount: int, source: StringName)
signal spent(amount: int, what: StringName)
## A zombie popped at `at` (world space) and dropped `amount` Sparks, already
## banked: the cue for the pickup stars (scripts/economy/spark_field.gd).
signal sparks_dropped(at: Vector3, amount: int)
## A run's Sparks were settled; `summary` is SparkLedger.summary().
signal run_settled(summary: Dictionary)

const CURRENCY := "Sparks"
const CURRENCY_SINGULAR := "Spark"
## Colour used for Sparks everywhere in the UI.
const COLOR := Color("ffd84a")
const COLOR_GLOW := Color("38f0ff")
const RULES_PATH := "res://data/progression/economy.tres"

var rules: EconomyRules
## The run in progress, or the last one (until the next run starts).
var run: SparkLedger


func _ready() -> void:
	rules = load(RULES_PATH)
	Events.run_started.connect(_on_run_started)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.wave_cleared.connect(_on_wave_cleared)
	Events.run_finished.connect(settle)
	Progression.level_up.connect(_on_level_up)
	Mastery.rank_up.connect(_on_rank_up)


func _sec() -> Dictionary:
	var s := Profile.section("wallet")
	if not s.has("balance"):
		s["balance"] = 0
	if not s.has("lifetime"):
		s["lifetime"] = 0
	return s


## Sparks the player can spend now.
func balance() -> int:
	return int(_sec()["balance"])


## Sparks ever earned (for stats and challenges).
func lifetime_earned() -> int:
	return int(_sec()["lifetime"])


func can_afford(amount: int) -> bool:
	return amount <= balance()


## Adds Sparks. `source` names where they came from (&"kill", &"wave",
## &"clear", &"level_up", &"mastery", &"contract", &"tickets", ...).
func earn(amount: int, source: StringName = &"") -> void:
	if amount <= 0:
		return
	var s := _sec()
	s["balance"] = int(s["balance"]) + amount
	s["lifetime"] = int(s["lifetime"]) + amount
	if run:
		run.note(amount, source)
	earned.emit(amount, source)
	balance_changed.emit(int(s["balance"]))


## Takes Sparks if the player has them and saves the profile. `what` names the
## purchase (an item id). Returns false, changing nothing, if they cannot pay.
func spend(amount: int, what: StringName = &"") -> bool:
	if amount < 0 or not can_afford(amount):
		return false
	var s := _sec()
	s["balance"] = int(s["balance"]) - amount
	Profile.save_profile()
	spent.emit(amount, what)
	balance_changed.emit(int(s["balance"]))
	return true


## "1,250" (thousands separators), for every place an amount is shown.
static func format(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + out


# --- runs -------------------------------------------------------------------

## Sparks earned in the current (or just finished) run.
func run_total() -> int:
	return run.total() if run else 0


## Settles the current run's Sparks once (normally on Events.run_finished) and
## returns the ledger summary; later calls return it without paying again.
func settle(result: Dictionary) -> Dictionary:
	if run == null:
		return {}
	if not run.finished:
		# Level-ups and contracts settled by Progression belong to this run.
		Progression.settle(result)
		run.finish(result)
		Profile.save_profile()
		run_settled.emit(run.summary())
	return run.summary()


## True the first time `level_id` is cleared (and remembers it), for the
## one-off first-clear Sparks.
func claim_first_clear(level_id: StringName) -> bool:
	var s := _sec()
	var firsts: Array = s.get("first_clears", [])
	if firsts.has(String(level_id)):
		return false
	firsts.append(String(level_id))
	s["first_clears"] = firsts
	return true


func _on_run_started(director: Node) -> void:
	run = SparkLedger.new(director) if director is RunDirector else null


func _on_enemy_killed(enemy: Node, _weapon_id: StringName, headshot: bool, _points: int) -> void:
	if run:
		run.on_kill(enemy, headshot)


func _on_wave_cleared(wave_number: int, _total: int) -> void:
	if run:
		run.on_wave_cleared(wave_number)
		Profile.save_profile()


func _on_level_up(new_level: int) -> void:
	earn(rules.level_sparks(new_level), &"level_up")


func _on_rank_up(_weapon: WeaponData, rank: int) -> void:
	earn(rules.rank_sparks(rank), &"mastery")
