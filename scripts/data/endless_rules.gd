class_name EndlessRules
extends Resource
## The rules of an Endless level (LevelData.endless): its districts and how
## the waves scale. Waves never run out; the run ends when the player falls.
## The director builds every wave from these numbers (docs/ENDLESS.md).

## The start district first, then the rest in the order a player meets them.
@export var districts: Array[EndlessDistrict] = []
## Enemies of the start district's pool that every wave can draw on.
@export var base_enemies: Array[StringName] = []
## The boss and how often it comes (every Nth wave).
@export var boss_id: StringName
@export var boss_every := 10


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
