class_name EndlessWaves
extends RefCounted
## Builds the waves of an Endless run, one at a time, from the level's
## EndlessRules, the wave number and the enemies of the open districts.
## Nothing here is random but the order of the queue, so the same wave number
## always has the same kind and size (docs/ENDLESS.md has the table).
##
## The schedule: every boss_every-th wave is the boss's (with its escorts),
## every 5th a HORDE (all entrances, a surge), and the waves between cycle
## through the kinds of the story levels, gentle for the first four.

## The kinds of the waves between hordes, in turn (waves 1-4 are fixed).
const CYCLE: Array[StringName] = [&"standard", &"rush", &"siege", &"bounty", &"ranged", &"standard", &"ambush", &"rush"]
const OPENING: Array[StringName] = [&"standard", &"standard", &"rush", &"standard"]
const HORDE_EVERY := 5

## Banner title and hint of each kind ("horde" and "boss" are Endless's own).
const TITLES := {
	&"standard": ["", ""],
	&"rush": ["RUSH HOUR", "Fast ones in numbers: keep your back to a wall."],
	&"siege": ["HEAVY TRAFFIC", "The heavies come first, one street at a time."],
	&"ambush": ["AMBUSH", "They pour in from every street at once."],
	&"ranged": ["CROSSFIRE", "Specialists from every side: take them first."],
	&"bounty": ["THE GOLDEN COURIER", "Pop the golden runner before it gets away."],
	&"horde": ["HORDE", "The whole city at once. Use the traps."],
	&"boss": ["", "Its escorts keep coming while it stands."],
}

## Shares of a wave's zombies by role, per kind: regular, fast, heavy, special.
const MIX := {
	&"standard": [0.62, 0.22, 0.06, 0.10],
	&"rush": [0.25, 0.62, 0.0, 0.13],
	&"siege": [0.5, 0.12, 0.16, 0.22],
	&"ambush": [0.55, 0.25, 0.06, 0.14],
	&"ranged": [0.45, 0.15, 0.05, 0.35],
	&"bounty": [0.6, 0.24, 0.06, 0.10],
	&"horde": [0.55, 0.25, 0.08, 0.12],
	&"boss": [0.6, 0.25, 0.0, 0.15],
}
## Size and spawn interval of each kind, relative to a standard wave.
const SIZE := {&"rush": 1.1, &"siege": 0.85, &"ambush": 1.0, &"ranged": 0.9, &"horde": 1.3, &"boss": 0.6}
const PACE := {&"rush": 0.6, &"siege": 1.15, &"ambush": 0.75, &"horde": 0.7, &"boss": 1.1}

var rules: EndlessRules


func _init(endless_rules: EndlessRules) -> void:
	rules = endless_rules


## The kind of wave `n`: "boss", "horde" or one of WaveData.KINDS.
func kind_of(n: int) -> StringName:
	if rules.boss_id != &"" and rules.boss_every > 0 and n % rules.boss_every == 0:
		return &"boss"
	if n % HORDE_EVERY == 0:
		return &"horde"
	if n <= OPENING.size():
		return OPENING[n - 1]
	# The waves between hordes count up past the opening, skipping the 5ths.
	var slot := n - 1 - n / HORDE_EVERY - OPENING.size()
	return CYCLE[slot % CYCLE.size()]


## The banner title of wave `n` ("" for a plain wave).
func title_of(n: int) -> String:
	var kind := kind_of(n)
	if kind == &"boss":
		var boss := GameData.enemy(EndlessDirector.resolve(rules.boss_id))
		return boss.display_name.to_upper() if boss else "THE BOSS"
	return TITLES[kind][0]


## Zombies in a standard wave `n` (before the kind's size).
func base_count(n: int) -> int:
	return mini(rules.count_max, int(round(rules.count_base + rules.count_per_wave * (n - 1))))


## Wave `n` drawn from `pool` ({"regular", "fast", "heavy", "special": Array of
## enemy ids}, see EndlessDirector.pool()).
func build(n: int, pool: Dictionary) -> WaveData:
	var kind := kind_of(n)
	var wave := WaveData.new()
	wave.kind = &"ambush" if kind == &"horde" else (&"finale" if kind == &"boss" else kind)
	wave.title = title_of(n)
	wave.hint = TITLES[kind][1]
	var count := maxi(4, int(round(base_count(n) * float(SIZE.get(kind, 1.0)))))
	wave.spawns = _spawns(count, MIX[kind], pool, n)
	wave.spawn_interval = maxf(rules.interval_min, rules.interval_base - rules.interval_per_wave * (n - 1)) * float(PACE.get(kind, 1.0))
	wave.max_alive = mini(rules.crowd_max, int(round(rules.crowd_base + rules.crowd_per_wave * (n - 1))))
	wave.burst = 2 if kind in [&"rush", &"horde", &"ambush"] and n >= 8 else 1
	wave.speed_scale = rules.speed_scale(n)
	wave.late_types_after = 0.2 if n > 2 else 0.4
	if kind == &"horde" or (kind == &"standard" and n >= 4):
		wave.surge_at = 0.45
		wave.surge_count = mini(4 + n / 4, 9)
	if kind == &"boss":
		wave.boss = EndlessDirector.resolve(rules.boss_id)
		wave.boss_at = 0.3
	if kind == &"bounty":
		var runner := _first(pool, "fast")
		wave.bounty = runner
		wave.bounty_tickets = 150 + 10 * n
		wave.title = "THE GOLDEN %s" % (GameData.enemy(runner).display_name.to_upper() if GameData.enemy(runner) else "RUNNER")
	return wave


## Splits `count` over the roles by `mix` (a role with nothing open hands its
## share to the regulars), then spreads each role over its enemy kinds.
func _spawns(count: int, mix: Array, pool: Dictionary, n: int) -> Dictionary:
	var roles := ["regular", "fast", "heavy", "special"]
	var shares := mix.duplicate()
	# Heavies join from wave 3; early waves are mostly the shamblers.
	if n < 3:
		shares[0] += shares[2]
		shares[2] = 0.0
	for i in range(1, 4):
		if (pool.get(roles[i], []) as Array).is_empty():
			shares[0] += shares[i]
			shares[i] = 0.0
	var out := {}
	var left := count
	for i in range(3, -1, -1):
		var ids: Array = pool.get(roles[i], [])
		if ids.is_empty():
			continue
		var amount := left if i == 0 else mini(left, int(round(count * float(shares[i]))))
		if i == 2 and amount == 0 and shares[2] > 0.0:
			amount = 1
		left -= amount
		for k in amount:
			var id: StringName = ids[k % ids.size()]
			out[String(id)] = int(out.get(String(id), 0)) + 1
	return _regulars_first(out, pool)


## The regulars open the wave (WaveData spawns its first listed type first).
func _regulars_first(spawns: Dictionary, pool: Dictionary) -> Dictionary:
	var first := String(_first(pool, "regular"))
	if not spawns.has(first):
		return spawns
	var ordered := {first: spawns[first]}
	for key in spawns:
		if key != first:
			ordered[key] = spawns[key]
	return ordered


static func _first(pool: Dictionary, role: String) -> StringName:
	var ids: Array = pool.get(role, [])
	if ids.is_empty():
		ids = pool.get("regular", [])
	return ids[0] if not ids.is_empty() else &""
