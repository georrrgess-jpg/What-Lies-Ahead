class_name ChallengeBook
extends RefCounted
## Challenge definitions (scanned from data/progression/challenges/) and their
## progress, stored in Profile.section("progression"):
##   "challenges": { key: progress }     key = id or id@weapon_id
##   "completed":  [ key, ... ]
## Completion is recorded once; a completed challenge never counts again.
## Progression awards the rewards (it calls record() and acts on the result).

const DIR := "res://data/progression/challenges"

static var _all: Array[Challenge] = []
static var _loaded := false


static func all() -> Array[Challenge]:
	if not _loaded:
		_loaded = true
		for r in GameData.scan(DIR, true):
			if r is Challenge:
				_all.append(r)
		_all.sort_custom(func(a, b): return a.sort_order < b.sort_order if a.sort_order != b.sort_order else String(a.id) < String(b.id))
	return _all


static func find(id: StringName) -> Challenge:
	for ch in all():
		if ch.id == id:
			return ch
	return null


static func of_scope(scope: Challenge.Scope) -> Array[Challenge]:
	var out: Array[Challenge] = []
	for ch in all():
		if ch.scope == scope:
			out.append(ch)
	return out


static func progress(ch: Challenge, weapon_id: StringName = &"") -> int:
	return int(_sec()["challenges"].get(ch.key(weapon_id), 0))


static func fraction(ch: Challenge, weapon_id: StringName = &"") -> float:
	return clampf(float(progress(ch, weapon_id)) / float(maxi(1, ch.goal)), 0.0, 1.0)


static func is_complete(ch: Challenge, weapon_id: StringName = &"") -> bool:
	return _sec()["completed"].has(ch.key(weapon_id))


## Completed / total, counting each weapon challenge once per weapon.
static func completion() -> Vector2i:
	var done := 0
	var total := 0
	for ch in all():
		var contexts: Array = [&""]
		if ch.scope == Challenge.Scope.WEAPON:
			contexts = GameData.weapons().map(func(w): return w.id)
		for wid in contexts:
			total += 1
			if is_complete(ch, wid):
				done += 1
	return Vector2i(done, total)


## Cosmetics a challenge unlocks (items whose requirement is that challenge).
static func rewards(ch: Challenge) -> Array[CosmeticItem]:
	var out: Array[CosmeticItem] = []
	for it in GameData.cosmetics():
		if it.requirement and it.requirement.kind == Requirement.Kind.CHALLENGE and it.requirement.target == ch.id:
			out.append(it)
	return out


## Adds a stat sample. Weapon challenges need `weapon_id`; account challenges
## with the same stat are fed too. Returns newly completed [challenge, weapon_id] pairs.
static func record(stat: StringName, value: int, weapon_id: StringName = &"") -> Array:
	var done: Array = []
	if value <= 0:
		return done
	for ch in all():
		if ch.stat != stat:
			continue
		var wid := weapon_id if ch.scope == Challenge.Scope.WEAPON else &""
		if ch.scope == Challenge.Scope.WEAPON and GameData.weapon(wid) == null:
			continue
		if _apply(ch, wid, value):
			done.append([ch, wid])
	return done


## Re-evaluates challenges computed from mastery ranks. Returns newly completed pairs.
static func refresh_computed() -> Array:
	var done: Array = []
	for ch in all():
		var value := -1
		match ch.stat:
			&"max_rank":
				value = 0
				for w in GameData.weapons():
					value = maxi(value, Mastery.rank(w.id))
			&"weapons_at_rank":
				value = GameData.weapons().filter(func(w): return Mastery.rank(w.id) >= ch.param).size()
		if value > 0 and _apply(ch, &"", value):
			done.append([ch, &""])
	return done


static func _apply(ch: Challenge, weapon_id: StringName, value: int) -> bool:
	if is_complete(ch, weapon_id):
		return false
	var sec := _sec()
	var key := ch.key(weapon_id)
	var current := int(sec["challenges"].get(key, 0))
	var next := current + value if ch.mode == Challenge.Mode.TOTAL else maxi(current, value)
	if next == current:
		return false
	sec["challenges"][key] = mini(next, ch.goal)
	if next < ch.goal:
		return false
	sec["completed"].append(key)
	return true


static func _sec() -> Dictionary:
	var s := Profile.section("progression")
	if typeof(s.get("challenges")) != TYPE_DICTIONARY:
		s["challenges"] = {}
	if typeof(s.get("completed")) != TYPE_ARRAY:
		s["completed"] = []
	return s
