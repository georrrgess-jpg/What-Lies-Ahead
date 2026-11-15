class_name EndlessRecords
extends RefCounted
## The player's Endless records, saved in the profile's "endless" section:
##   best_wave       highest wave reached (any difficulty)
##   best_score      best score of a run
##   best_by_difficulty {difficulty id: best wave}
##   runs            runs played
##   opened          {district id: true} districts opened at least once
## Requirement.ENDLESS_WAVE and ENDLESS_DISTRICT read these. The run director
## notes waves and districts as they happen (so unlocks land mid-run) and
## records the whole run when it ends.


static func _sec() -> Dictionary:
	return Profile.section("endless")


static func best_wave() -> int:
	return int(_sec().get("best_wave", 0))


static func best_score() -> int:
	return int(_sec().get("best_score", 0))


static func runs() -> int:
	return int(_sec().get("runs", 0))


## Best wave reached on difficulty `id` (0 if never played there).
static func best_on(id: StringName) -> int:
	return int((_sec().get("best_by_difficulty", {}) as Dictionary).get(String(id), 0))


static func has_opened(district: StringName) -> bool:
	return bool((_sec().get("opened", {}) as Dictionary).get(String(district), false))


## How many of `rules`' gated districts have been opened at least once.
static func opened_count(rules: EndlessRules) -> int:
	var n := 0
	for d in rules.districts:
		if d.price > 0 and has_opened(d.id):
			n += 1
	return n


## Wave `wave` was reached on difficulty `difficulty`: raises the bests.
## Returns true if it is a new best wave overall.
static func note_wave(wave: int, difficulty: StringName) -> bool:
	var sec := _sec()
	var by: Dictionary = sec.get("best_by_difficulty", {})
	by[String(difficulty)] = maxi(int(by.get(String(difficulty), 0)), wave)
	sec["best_by_difficulty"] = by
	if wave <= best_wave():
		return false
	sec["best_wave"] = wave
	return true


## District `id` was opened (kept for good, for ENDLESS_DISTRICT unlocks).
static func note_opened(id: StringName) -> void:
	var sec := _sec()
	var opened: Dictionary = sec.get("opened", {})
	opened[String(id)] = true
	sec["opened"] = opened


## Records a finished (or abandoned) run from its result (RunDirector.result()).
## Returns true if its score is a new best. The caller saves the profile.
static func record(result: Dictionary) -> bool:
	var sec := _sec()
	sec["runs"] = runs() + 1
	note_wave(int(result.get("wave_reached", 0)), StringName(String(result.get("difficulty", Difficulty.DEFAULT))))
	var endless: Dictionary = result.get("endless", {})
	for id in endless.get("opened", []):
		note_opened(StringName(String(id)))
	var score := int(result.get("score", 0))
	if score <= best_score():
		return false
	sec["best_score"] = score
	return true
