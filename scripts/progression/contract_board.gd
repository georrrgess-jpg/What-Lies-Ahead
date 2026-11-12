class_name ContractBoard
extends RefCounted
## Contracts: three short goals at a time ("Get 20 headshot kills", "Clear 6
## waves", "Pop 40 zombies with the Arc Coil"). Finishing one pays Sparks and
## XP; when the run ends, finished contracts are replaced by new ones, so
## there are always three to work on and never more.
##
## Templates are Challenge resources in data/progression/contracts/. Active
## contracts live in Profile.section("progression")["contracts"] as
##   { "id": template id, "weapon": weapon id or "", "progress": int, "done": bool }
## The run tracker feeds them (record()) and pays out what they return.

const DIR := "res://data/progression/contracts"
const SLOTS := 3

static var _templates: Array[Challenge] = []
static var _loaded := false


static func templates() -> Array[Challenge]:
	if not _loaded:
		_loaded = true
		for r in GameData.scan(DIR, false):
			if r is Challenge:
				_templates.append(r)
		_templates.sort_custom(func(a, b): return a.sort_order < b.sort_order if a.sort_order != b.sort_order else String(a.id) < String(b.id))
	return _templates


## The three active contracts (dealing new ones into empty slots first).
static func active() -> Array:
	var list := _list()
	_deal(list)
	return list


static func template(entry: Dictionary) -> Challenge:
	for ch in templates():
		if String(ch.id) == String(entry.get("id", "")):
			return ch
	return null


static func weapon(entry: Dictionary) -> WeaponData:
	return GameData.weapon(StringName(String(entry.get("weapon", ""))))


static func title(entry: Dictionary) -> String:
	var ch := template(entry)
	return ch.display_name if ch else ""


## "Get 12 headshot kills with the Ion Carbine".
static func describe(entry: Dictionary) -> String:
	var ch := template(entry)
	if ch == null:
		return ""
	var w := weapon(entry)
	return ch.describe() + (" with the %s" % w.display_name if w else "")


static func goal(entry: Dictionary) -> int:
	var ch := template(entry)
	return ch.goal if ch else 1


static func progress(entry: Dictionary) -> int:
	return mini(int(entry.get("progress", 0)), goal(entry))


static func fraction(entry: Dictionary) -> float:
	return clampf(float(progress(entry)) / float(maxi(1, goal(entry))), 0.0, 1.0)


static func is_done(entry: Dictionary) -> bool:
	return bool(entry.get("done", false))


## Contracts completed over the whole career.
static func completed_count() -> int:
	return int(Profile.section("progression").get("contracts_done", 0))


## Adds a stat sample to every active contract that tracks it. Returns the
## entries this completed.
static func record(stat: StringName, value: int, weapon_id: StringName = &"") -> Array:
	var done: Array = []
	if value <= 0:
		return done
	for entry in active():
		var ch := template(entry)
		if ch == null or ch.stat != stat or is_done(entry):
			continue
		if ch.scope == Challenge.Scope.WEAPON and String(weapon_id) != String(entry.get("weapon", "")):
			continue
		var current := int(entry.get("progress", 0))
		var next := current + value if ch.mode == Challenge.Mode.TOTAL else maxi(current, value)
		entry["progress"] = mini(next, ch.goal)
		if next >= ch.goal:
			entry["done"] = true
			var sec := Profile.section("progression")
			sec["contracts_done"] = int(sec.get("contracts_done", 0)) + 1
			done.append(entry)
	return done


## Replaces finished contracts with new ones (when a run is settled). Returns
## the entries that were dealt.
static func roll_over() -> Array:
	var list := _list()
	for i in range(list.size() - 1, -1, -1):
		if is_done(list[i]) or template(list[i]) == null:
			list.remove_at(i)
	return _deal(list)


static func _list() -> Array:
	var sec := Profile.section("progression")
	if typeof(sec.get("contracts")) != TYPE_ARRAY:
		sec["contracts"] = []
	return sec["contracts"]


## Fills empty slots. A new profile gets the three easiest templates; after
## that the pick is random among templates that are not active already and
## track a stat no active contract tracks.
static func _deal(list: Array) -> Array:
	var dealt: Array = []
	var first_hand := completed_count() == 0 and list.is_empty()
	while list.size() < SLOTS:
		var options := _options(list)
		if options.is_empty():
			break
		var ch: Challenge = options[0] if first_hand else options[randi() % options.size()]
		var entry := {"id": String(ch.id), "weapon": "", "progress": 0, "done": false}
		if ch.scope == Challenge.Scope.WEAPON:
			entry["weapon"] = String(_pick_weapon(list))
		list.append(entry)
		dealt.append(entry)
	return dealt


static func _options(list: Array) -> Array:
	var used_ids := {}
	var used_stats := {}
	for entry in list:
		var ch := template(entry)
		if ch:
			used_ids[ch.id] = true
			used_stats[ch.stat] = true
	var fresh: Array = []
	var fallback: Array = []
	for ch in templates():
		if used_ids.has(ch.id) or ch.param > Progression.level():
			continue
		fallback.append(ch)
		if not used_stats.has(ch.stat):
			fresh.append(ch)
	return fresh if not fresh.is_empty() else fallback


## A weapon for a weapon contract: usually one of the two carried weapons,
## otherwise any unlocked weapon without a weapon contract already.
static func _pick_weapon(list: Array) -> StringName:
	var taken := {}
	for entry in list:
		taken[String(entry.get("weapon", ""))] = true
	var carried: Array[StringName] = []
	for id in [Loadout.primary(), Loadout.secondary()]:
		if id != &"" and not taken.has(String(id)):
			carried.append(id)
	if not carried.is_empty() and randf() < 0.7:
		return carried[randi() % carried.size()]
	var pool: Array[StringName] = []
	for w in Loadout.available():
		if not taken.has(String(w.id)):
			pool.append(w.id)
	if pool.is_empty():
		return GameData.default_weapon_id()
	return pool[randi() % pool.size()]
