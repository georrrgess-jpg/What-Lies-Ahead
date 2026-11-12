extends Node
## Loads the data catalog once and offers lookups by stable ID.

const CATALOG_PATH := "res://data/catalog.tres"

var catalog: GameCatalog
var _weapons := {}
var _enemies := {}
var _levels := {}


func _ready() -> void:
	catalog = load(CATALOG_PATH) as GameCatalog
	if catalog == null:
		push_error("GameData: could not load %s" % CATALOG_PATH)
		catalog = GameCatalog.new()
	for w in catalog.weapons:
		_weapons[w.id] = w
	for e in catalog.enemies:
		_enemies[e.id] = e
	for world in catalog.worlds:
		for level in world.levels:
			_levels[level.id] = level


func weapons() -> Array[WeaponData]:
	return catalog.weapons


func weapon(id: StringName) -> WeaponData:
	return _weapons.get(id)


func enemy(id: StringName) -> EnemyData:
	return _enemies.get(id)


func level(id: StringName) -> LevelData:
	return _levels.get(id)


func worlds() -> Array[WorldData]:
	return catalog.worlds


func default_weapon_id() -> StringName:
	return catalog.weapons[0].id if not catalog.weapons.is_empty() else &""


## A level is playable when it has a scene and its requirement (if any) is cleared.
func is_level_unlocked(level_data: LevelData) -> bool:
	if level_data.scene_path.is_empty() or level_data.wave_set == null:
		return false
	if level_data.requires_level == &"":
		return true
	return Profile.is_level_completed(level_data.requires_level)


func lock_reason(level_data: LevelData) -> String:
	if level_data.scene_path.is_empty() or level_data.wave_set == null:
		return "Coming soon"
	if level_data.requires_level != &"" and not Profile.is_level_completed(level_data.requires_level):
		var req := level(level_data.requires_level)
		return "Clear %s to unlock" % (req.display_name if req else String(level_data.requires_level))
	return ""
