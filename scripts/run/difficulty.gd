class_name Difficulty
extends RefCounted
## The difficulty the player picked on the Play page: how hard the zombies hit,
## how tough they are and how much a run pays. Saved in the settings.

const IDS: Array[StringName] = [&"casual", &"standard", &"hard"]
const DEFAULT: StringName = &"standard"

const LABELS := {&"casual": "CASUAL", &"standard": "STANDARD", &"hard": "HARD"}
const DESCRIPTIONS := {
	&"casual": "Zombies hit softer and go down faster. Pays a little less.",
	&"standard": "The intended challenge.",
	&"hard": "Tougher, meaner hordes. Pays more.",
}


## The saved choice (DEFAULT if unset or unknown).
static func current() -> StringName:
	var id := StringName(String(Profile.data["settings"].get("difficulty", DEFAULT)))
	return id if id in IDS else DEFAULT


static func set_current(id: StringName) -> void:
	if id in IDS:
		Profile.data["settings"]["difficulty"] = String(id)
		Profile.save_profile()


static func label(id: StringName) -> String:
	return LABELS.get(id, String(id).to_upper())


static func description(id: StringName) -> String:
	return DESCRIPTIONS.get(id, "")


## Multiplies enemy health.
static func enemy_health_scale() -> float:
	return 1.0


## Multiplies the damage enemies deal.
static func enemy_damage_scale() -> float:
	return 1.0


## Multiplies score, account XP and Sparks earned in a run.
static func reward_scale() -> float:
	return 1.0
