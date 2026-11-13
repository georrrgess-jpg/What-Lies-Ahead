class_name SparkLedger
extends RefCounted
## Sparks bookkeeping for one run, created by the Wallet autoload on
## Events.run_started. It pays the Sparks of every kill, wave and clear into
## the Wallet (scaled by the difficulty), announces where Sparks dropped,
## and keeps a labelled breakdown of everything earned while the run lasted
## (level-ups, mastery ranks and contracts included) for the results screen.
## Every payout has a key, so nothing is paid twice; finish() runs once.

## Breakdown labels by Wallet.earn source, in the order they are shown.
const LABELS := {
	&"kill": "Zombies popped",
	&"headshot": "Headshots",
	&"combo": "Combo bonuses",
	&"wave": "Waves cleared",
	&"flawless": "Flawless waves",
	&"clear": "Level clear",
	&"first_clear": "First clear",
	&"tickets": "Tickets cashed",
	&"level_up": "Level-ups",
	&"mastery": "Mastery ranks",
	&"contract": "Contracts",
	&"milestone": "Milestones",
}

var director: RunDirector
var finished := false
var victory := false
var balance_before := 0
## Sparks by breakdown label.
var lines := {}
## Tickets cashed at the portal (0 unless the level was cleared).
var tickets_cashed := 0

var _keys := {}
var _scale := 1.0
var _carry := 0.0
var _wave_damage := 0.0


func _init(run: RunDirector) -> void:
	director = run
	balance_before = Wallet.balance()
	_scale = Difficulty.reward_scale()
	run.wave_started.connect(func(_n, _t, _b): _wave_damage = 0.0)
	if run.player:
		run.player.damaged.connect(_on_damaged)


## Sparks earned since the run started, from every source.
func total() -> int:
	var sum := 0
	for label in lines:
		sum += int(lines[label])
	return sum


## Records Sparks the Wallet paid while this run was open.
func note(amount: int, source: StringName) -> void:
	if finished:
		return
	var label: String = LABELS.get(source, "Other")
	lines[label] = int(lines.get(label, 0)) + amount


func on_kill(enemy: Node, headshot: bool) -> void:
	var z := enemy as Zombie
	if finished or z == null or z.data == null:
		return
	var rules := Wallet.rules
	var paid := _pay(rules.kill_sparks(z.data.tickets), &"kill")
	if headshot:
		paid += _pay(rules.headshot_sparks, &"headshot")
	var combo := director.score.combo if is_instance_valid(director) and director.score else 0
	if rules.combo_every > 0 and combo > 0 and combo % rules.combo_every == 0:
		paid += _pay(rules.combo_sparks, &"combo")
	if is_instance_valid(Progression.tracker) and paid > 0:
		Progression.tracker.count(&"sparks", paid)
	Wallet.sparks_dropped.emit(z.global_position + Vector3.UP * (0.9 * z.data.body_scale), paid)


func on_wave_cleared(wave_number: int) -> void:
	if finished or _keys.has(wave_number):
		return
	_keys[wave_number] = true
	_pay(Wallet.rules.wave_sparks, &"wave")
	if _wave_damage <= 0.0:
		_pay(Wallet.rules.flawless_wave_sparks, &"flawless")
	_wave_damage = 0.0


## Settles the run: the clear bonuses and the leftover tickets on a victory.
func finish(result: Dictionary) -> void:
	if finished:
		return
	victory = bool(result.get("victory", false))
	if victory:
		var level: LevelData = result.get("level")
		var world_index := GameData.worlds().find(level.world) if level else 0
		_pay(Wallet.rules.clear_sparks_for(world_index), &"clear")
		if level and Wallet.claim_first_clear(level.id):
			_pay(Wallet.rules.first_clear_sparks, &"first_clear")
		tickets_cashed = int(result.get("tickets_left", 0))
		_pay(Wallet.rules.ticket_sparks(tickets_cashed), &"tickets")
	finished = true


## Everything the results screen shows: [label, sparks] rows in display order.
func summary() -> Dictionary:
	var rows: Array = []
	for source in LABELS:
		var label: String = LABELS[source]
		if lines.has(label):
			rows.append([label, int(lines[label])])
	if lines.has("Other"):
		rows.append(["Other", int(lines["Other"])])
	return {
		"total": total(),
		"lines": rows,
		"balance_before": balance_before,
		"balance": Wallet.balance(),
		"tickets_cashed": tickets_cashed,
		"victory": victory,
	}


## Pays `amount` times the difficulty scale, carrying fractions over so a
## scale below 1 still adds up. Returns the whole Sparks paid now.
func _pay(amount: int, source: StringName) -> int:
	if amount <= 0:
		return 0
	_carry += amount * _scale
	var whole := int(floor(_carry))
	_carry -= whole
	Wallet.earn(whole, source)
	return whole


func _on_damaged(amount: float, _source: Vector3) -> void:
	if is_instance_valid(director) and director.state == RunDirector.State.WAVE:
		_wave_damage += amount
