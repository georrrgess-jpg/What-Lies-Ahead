class_name Difficulty
extends RefCounted
## The difficulty the player picked on the Play page: how hard the zombies hit,
## how tough and how many they are, how often they use their special attacks,
## how far the pacing director may push or ease a wave, and how much a run
## pays. Saved in the settings. The table below is the single source of truth
## (docs/ROUNDS.md explains the choices).

const IDS: Array[StringName] = [&"casual", &"standard", &"hard", &"last_ride"]
const DEFAULT: StringName = &"standard"

const LABELS := {&"casual": "CASUAL", &"standard": "STANDARD", &"hard": "HARD", &"last_ride": "LAST RIDE"}
const DESCRIPTIONS := {
	&"casual": "Zombies hit softer and go down faster. Pays a little less.",
	&"standard": "The intended challenge.",
	&"hard": "Tougher, meaner hordes. Pays more.",
	&"last_ride": "The final ride: brutal hordes, no healing, no checkpoints, no mercy. Pays 2.5x.",
}
const COLORS := {
	&"casual": Color(0.45, 0.95, 0.6),
	&"standard": Color(0.5, 0.95, 0.91),
	&"hard": Color(1.0, 0.36, 0.5),
	&"last_ride": Color(0.74, 0.42, 1.0),
}

## Last Ride opens at this player level (until then its tab is dimmed and
## picking it explains why).
const UNLOCK_LEVEL := {&"last_ride": 20}

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
##   reward                    multiplies account XP and Sparks (not the score)
##   checkpoints               1 = a fallen run may continue from its checkpoint, 0 = it may not
const TABLE := {
	&"casual": {
		"health": 0.8, "boss_health": 0.7, "damage": 0.6, "speed": 0.95,
		"max_alive": 0.8, "interval": 1.2, "specials": 1.45,
		"pace_min": 0.55, "pace_max": 1.0, "relief": 6.0,
		"wave_heal": 20.0, "tickets": 1.25, "reward": 0.8, "checkpoints": 1.0,
	},
	&"standard": {
		"health": 1.08, "boss_health": 1.05, "damage": 1.1, "speed": 1.03,
		"max_alive": 1.06, "interval": 0.95, "specials": 0.92,
		"pace_min": 0.75, "pace_max": 1.4, "relief": 2.5,
		"wave_heal": 0.0, "tickets": 1.0, "reward": 1.0, "checkpoints": 1.0,
	},
	&"hard": {
		"health": 1.28, "boss_health": 1.12, "damage": 1.2, "speed": 1.08,
		"max_alive": 1.12, "interval": 0.9, "specials": 0.82,
		"pace_min": 0.9, "pace_max": 1.45, "relief": 0.0,
		"wave_heal": 0.0, "tickets": 1.0, "reward": 1.4, "checkpoints": 1.0,
	},
	# Skill, not grind: every zombie is tougher, faster and hits harder, the
	# crowd is bigger and arrives sooner, specials come often, the pacing
	# director only ever presses and never grants relief, and a fallen run is
	# over. Two and a half times Standard's XP and Arcade Tokens.
	&"last_ride": {
		"health": 1.5, "boss_health": 1.25, "damage": 1.38, "speed": 1.12,
		"max_alive": 1.3, "interval": 0.8, "specials": 0.65,
		"pace_min": 1.0, "pace_max": 1.6, "relief": 0.0,
		"wave_heal": 0.0, "tickets": 1.0, "reward": 2.5, "checkpoints": 0.0,
	},
}

## Set by the run director for the run in progress: CONTINUE_REWARD_SCALE
## while a run continued from a checkpoint is being played, otherwise 1.
static var run_reward_scale := 1.0


## The saved choice (DEFAULT if unset, unknown or still locked).
static func current() -> StringName:
	var id := StringName(String(Profile.data["settings"].get("difficulty", DEFAULT)))
	return id if id in IDS and is_unlocked(id) else DEFAULT


## True when the player's level has opened tier `id`.
static func is_unlocked(id: StringName) -> bool:
	return Progression.level() >= int(UNLOCK_LEVEL.get(id, 0))


## Why a tier is still closed ("" when it is open).
static func lock_reason(id: StringName) -> String:
	return "" if is_unlocked(id) else "Reach player level %d to take the Last Ride." % int(UNLOCK_LEVEL[id])


static func set_current(id: StringName) -> void:
	if id in IDS and is_unlocked(id):
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
	for item in [["damage", "Enemy damage"], ["health", "Enemy health"], ["max_alive", "Horde size"], ["reward", "XP & Tokens"]]:
		var percent := int(round((float(row[item[0]]) - 1.0) * 100.0))
		if percent != 0:
			out.append("%s %+d%%" % [item[1], percent])
	if float(row["wave_heal"]) > 0.0:
		out.append("+%d health every wave" % int(row["wave_heal"]))
	if float(row["checkpoints"]) <= 0.0:
		out.append("No checkpoints")
	return out


## Endless overrides per tier: a run that never ends compounds every
## multiplier, so Hard keeps a little relief there (it stays clearly harder
## than Standard: about wave 18-22 against the mid-20s for the same player).
const ENDLESS_TABLE := {
	&"hard": {"health": 1.22, "relief": 1.0, "pace_max": 1.4},
	&"last_ride": {"health": 1.5, "damage": 1.55, "pace_max": 1.55},
}


## One value of the current tier's row (see TABLE), with the Endless
## override when an endless level is being played.
static func value(key: String) -> float:
	var tier := current()
	if Game.level and Game.level.is_endless() and ENDLESS_TABLE.has(tier) and ENDLESS_TABLE[tier].has(key):
		return float(ENDLESS_TABLE[tier][key])
	return float(TABLE[tier][key])


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
