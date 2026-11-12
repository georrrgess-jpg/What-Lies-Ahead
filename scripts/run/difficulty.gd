class_name Difficulty
extends RefCounted
## The difficulty the player picked on the Play page: how hard the zombies hit,
## how tough and how many they are, how often they use their special attacks,
## how far the pacing director may push or ease a wave, and how much a run
## pays. Saved in the settings. The table below is the single source of truth
## (docs/ROUNDS.md explains the choices).

const IDS: Array[StringName] = [&"casual", &"standard", &"hard"]
const DEFAULT: StringName = &"standard"

const LABELS := {&"casual": "CASUAL", &"standard": "STANDARD", &"hard": "HARD"}
const DESCRIPTIONS := {
	&"casual": "Zombies hit softer and go down faster. Pays a little less.",
	&"standard": "The intended challenge.",
	&"hard": "Tougher, meaner hordes. Pays more.",
}
const COLORS := {
	&"casual": Color(0.45, 0.95, 0.6),
	&"standard": Color(0.5, 0.95, 0.91),
	&"hard": Color(1.0, 0.36, 0.5),
}

## Rewards of a run continued from a checkpoint are multiplied by this.
const CONTINUE_REWARD_SCALE := 0.75

## One row per tier.
##   health / damage / speed   multiply every enemy's stats (boss_health: alphas only)
##   max_alive / interval      multiply each wave's crowd cap and spawn interval
##   specials                  multiplies the cooldown of special attacks (leaps, volleys, charges)
##   pace_min / pace_max       bounds of the pacing director's spawn-rate multiplier
##                             (below 1 = it may ease off, above 1 = it may press)
##   relief                    seconds of spawn pause the director may grant a player in trouble, per wave
##   wave_heal                 health restored at every wave clear
##   tickets                   multiplies ticket income
##   reward                    multiplies score, account XP and Sparks
const TABLE := {
	&"casual": {
		"health": 0.8, "boss_health": 0.7, "damage": 0.6, "speed": 0.95,
		"max_alive": 0.8, "interval": 1.2, "specials": 1.45,
		"pace_min": 0.55, "pace_max": 1.0, "relief": 6.0,
		"wave_heal": 20.0, "tickets": 1.25, "reward": 0.8,
	},
	&"standard": {
		"health": 1.0, "boss_health": 1.0, "damage": 1.0, "speed": 1.0,
		"max_alive": 1.0, "interval": 1.0, "specials": 1.0,
		"pace_min": 0.7, "pace_max": 1.35, "relief": 3.5,
		"wave_heal": 0.0, "tickets": 1.0, "reward": 1.0,
	},
	&"hard": {
		"health": 1.2, "boss_health": 1.3, "damage": 1.3, "speed": 1.06,
		"max_alive": 1.25, "interval": 0.85, "specials": 0.75,
		"pace_min": 0.85, "pace_max": 1.5, "relief": 0.0,
		"wave_heal": 0.0, "tickets": 1.0, "reward": 1.3,
	},
}

## Set by the run director for the run in progress: CONTINUE_REWARD_SCALE
## while a run continued from a checkpoint is being played, otherwise 1.
static var run_reward_scale := 1.0


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


## Accent colour of a tier, for chips and banners.
static func color(id: StringName) -> Color:
	return COLORS.get(id, COLORS[DEFAULT])


## What a tier changes, as short lines for a menu ("Enemy damage -40%", ...).
static func effects(id: StringName) -> PackedStringArray:
	var row: Dictionary = TABLE.get(id, TABLE[DEFAULT])
	var out := PackedStringArray()
	for item in [["damage", "Enemy damage"], ["health", "Enemy health"], ["max_alive", "Horde size"], ["reward", "Rewards"]]:
		var percent := int(round((float(row[item[0]]) - 1.0) * 100.0))
		if percent != 0:
			out.append("%s %+d%%" % [item[1], percent])
	if float(row["wave_heal"]) > 0.0:
		out.append("+%d health every wave" % int(row["wave_heal"]))
	return out


## One value of the current tier's row (see TABLE).
static func value(key: String) -> float:
	return float(TABLE[current()][key])


## Multiplies enemy health.
static func enemy_health_scale() -> float:
	return value("health")


## Multiplies the health of a finale alpha (on top of nothing else).
static func boss_health_scale() -> float:
	return value("boss_health")


## Multiplies the damage enemies deal.
static func enemy_damage_scale() -> float:
	return value("damage")


## Multiplies enemy move speed.
static func enemy_speed_scale() -> float:
	return value("speed")


## Multiplies the cooldown of enemy special attacks (above 1 = rarer).
static func special_cooldown_scale() -> float:
	return value("specials")


## Multiplies score, account XP and Sparks earned in a run (the tier's pay,
## less the continue penalty while a checkpoint run is being played).
static func reward_scale() -> float:
	return value("reward") * run_reward_scale
