class_name EndlessRecords
extends RefCounted
## The player's Endless records, saved in the profile's "endless" section:
##   best_wave       highest wave reached (any difficulty)
##   best_score      best score of a run
##   best_by_difficulty {difficulty id: best wave}
##   runs            runs played
##   opened          {district id: true} districts opened at least once
## Requirement.ENDLESS_WAVE and ENDLESS_DISTRICT read these.


static func _sec() -> Dictionary:
	return Profile.section("endless")


static func best_wave() -> int:
	return int(_sec().get("best_wave", 0))


static func has_opened(district: StringName) -> bool:
	return bool((_sec().get("opened", {}) as Dictionary).get(String(district), false))
