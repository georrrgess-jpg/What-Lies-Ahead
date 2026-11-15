class_name EndlessRules
extends Resource
## The rules of an Endless level (LevelData.endless): its districts and how
## the waves scale. Waves never run out; the run ends when the player falls.
## The director builds every wave from these numbers (EndlessWaves,
## docs/ENDLESS.md has the table they make).

## The start district first, then the rest in the order a player meets them.
@export var districts: Array[EndlessDistrict] = []
## Enemies of the start district's pool that every wave can draw on.
@export var base_enemies: Array[StringName] = []
## The boss and how often it comes (every Nth wave).
@export var boss_id: StringName
@export var boss_every := 10

@export_group("Economy")
## Station prices, breaks and starting tickets (its wave list stays empty:
## the director fills it as the run goes).
@export var economy: WaveSet
## Every Nth break a supply crate lands in an open district.
@export var supply_every := 5
## What a supply crate holds: tickets (plus tickets_per_wave per wave) and health.
@export var supply_tickets := 150
@export var supply_tickets_per_wave := 10
@export var supply_heal := 50.0
## Traps: tickets to arm one, seconds it burns, seconds before it can be armed again.
@export var trap_price := 250
@export var trap_seconds := 15.0
@export var trap_cooldown := 40.0

@export_group("Scaling")
## Zombies in wave 1, how many each wave adds, and the most one wave holds.
@export var count_base := 10
@export var count_per_wave := 1.8
@export var count_max := 60
## Crowd cap (zombies alive at once): wave 1, per wave, ceiling.
@export var crowd_base := 7
@export var crowd_per_wave := 0.45
@export var crowd_max := 18
## Seconds between spawns: wave 1, less per wave, floor.
@export var interval_base := 2.0
@export var interval_per_wave := 0.07
@export var interval_min := 0.8
## Enemy health: +health_growth per wave until health_knee, +health_late per
## wave after it, never more than health_max (death comes from pressure,
## not from bullet sponges).
@export var health_growth := 0.06
@export var health_knee := 15
@export var health_late := 0.02
@export var health_max := 2.4
## Enemy damage and speed: + per wave, capped.
@export var damage_growth := 0.02
@export var damage_max := 1.5
@export var speed_growth := 0.01
@export var speed_max := 1.2
## The boss's health: x(1 + boss_growth) for every earlier visit.
@export var boss_growth := 0.45
## Kill tickets: + per wave, capped (tougher zombies pay a little more).
@export var tickets_growth := 0.02
@export var tickets_max := 1.5


## The district with `id`, or null.
func district(id: StringName) -> EndlessDistrict:
	for d in districts:
		if d.id == id:
			return d
	return null


## The district open from the start (price 0).
func start_district() -> EndlessDistrict:
	for d in districts:
		if d.price == 0:
			return d
	return districts[0] if not districts.is_empty() else null


## Enemy health multiplier on wave `n` (before the difficulty).
func health_scale(n: int) -> float:
	var early := mini(n, health_knee) - 1
	var late := maxi(0, n - health_knee)
	return minf(health_max, 1.0 + health_growth * early + health_late * late)


func damage_scale(n: int) -> float:
	return minf(damage_max, 1.0 + damage_growth * (n - 1))


func speed_scale(n: int) -> float:
	return minf(speed_max, 1.0 + speed_growth * (n - 1))


func ticket_scale(n: int) -> float:
	return minf(tickets_max, 1.0 + tickets_growth * (n - 1))


## Health multiplier of the boss on wave `n`, relative to its own data.
func boss_scale(n: int) -> float:
	return 1.0 + boss_growth * maxi(0, n / maxi(1, boss_every) - 1)
