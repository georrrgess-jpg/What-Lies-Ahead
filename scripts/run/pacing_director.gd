class_name PacingDirector
extends RefCounted
## Watches how the fight is going and nudges the spawn rate, within the
## bounds of the difficulty (Difficulty.TABLE: pace_min, pace_max, relief).
##
## `stress` (0 calm .. 1 overwhelmed) blends how hurt the player is, how many
## zombies are in their face and how much damage they took in the last few
## seconds. `pace` multiplies the spawn rate:
##   - stress above EASE_FROM: pace falls toward pace_min, and the crowd cap
##     drops a little;
##   - a player in real trouble (low health and swarmed) gets a short spawn
##     pause, at most `relief` seconds per wave;
##   - stress below PRESS_BELOW while the player keeps the crowd small: pace
##     rises toward pace_max, and past PRESS_CAP_FROM the crowd cap grows.
## Changes are gradual, so the player feels a wave breathe, not a switch.

const EASE_FROM := 0.55
const PRESS_BELOW := 0.2
## Above this pace the crowd cap grows too.
const PRESS_CAP_FROM := 1.15
## Zombies within this distance count as "in the player's face".
const NEAR_DISTANCE := 7.0
## Health fraction under which a swarmed player gets the spawn pause.
const RELIEF_HEALTH := 0.3
const RELIEF_NEAR := 3
## Seconds for half of the remembered damage to wear off.
const DAMAGE_HALF_LIFE := 3.5

var pace := 1.0
var stress := 0.0
## Seconds of pause used and granted in this run (for the dev log).
var relief_used := 0.0

var _pace_min := 0.7
var _pace_max := 1.2
var _relief_budget := 0.0
var _relief_left := 0.0
var _recent_damage := 0.0
var _relieving := false
var _pace_sum := 0.0
var _pace_time := 0.0


func _init() -> void:
	_pace_min = Difficulty.value("pace_min")
	_pace_max = Difficulty.value("pace_max")
	_relief_budget = Difficulty.value("relief")


func begin_wave() -> void:
	pace = 1.0
	_relief_left = _relief_budget
	_relieving = false


func on_player_damaged(amount: float) -> void:
	_recent_damage += amount


## Call every frame of a wave. `cap` is the wave's crowd cap.
func tick(delta: float, player: Player, alive: Array[Zombie], cap: int, queued: int) -> void:
	_recent_damage *= pow(0.5, delta / DAMAGE_HALF_LIFE)
	var health := clampf((player.health + player.shield) / player.max_health, 0.0, 1.0)
	var near := 0
	for z in alive:
		if is_instance_valid(z) and z.global_position.distance_squared_to(player.global_position) < NEAR_DISTANCE * NEAR_DISTANCE:
			near += 1
	var target := clampf(0.55 * (1.0 - health) + 0.25 * minf(1.0, near / 6.0) + 0.35 * minf(1.0, _recent_damage / 45.0), 0.0, 1.0)
	# Stress climbs quickly and settles slowly.
	stress = move_toward(stress, target, delta * (0.9 if target > stress else 0.3))
	_relieving = health < RELIEF_HEALTH and near >= RELIEF_NEAR and _relief_left > 0.0
	if _relieving:
		_relief_left -= delta
		relief_used += delta
	var want := 1.0
	if stress > EASE_FROM:
		want = lerpf(1.0, _pace_min, (stress - EASE_FROM) / (1.0 - EASE_FROM))
	elif stress < PRESS_BELOW and queued > 0 and alive.size() <= int(cap * 0.6):
		want = _pace_max
	pace = move_toward(pace, want, delta * 0.2)
	_pace_sum += pace * delta
	_pace_time += delta


## True while the director holds spawns back for a player in trouble.
func is_relieving() -> bool:
	return _relieving


## The crowd cap right now: a stressed player faces a slightly smaller crowd,
## a player who is being pressed a slightly larger one.
func live_cap(cap: int) -> int:
	if stress > EASE_FROM:
		return maxi(2, int(round(cap * lerpf(1.0, 0.75, (stress - EASE_FROM) / (1.0 - EASE_FROM)))))
	if pace > PRESS_CAP_FROM:
		return cap + maxi(1, int(round(cap * 0.15)))
	return cap


## Mean pace over the run so far (1 = never eased or pressed).
func average_pace() -> float:
	return _pace_sum / _pace_time if _pace_time > 0.0 else 1.0
