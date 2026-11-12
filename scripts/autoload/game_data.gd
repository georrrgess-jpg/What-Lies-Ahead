extends Node
## Discovers all game content by scanning data folders, so adding a weapon,
## enemy, world or cosmetic is just adding a .tres file (no shared list to
## edit):
##
##   data/weapons/*.tres          WeaponData      (sorted by sort_order)
##   data/enemies/**/*.tres       EnemyData
##   data/worlds/*.tres           WorldData       (sorted by sort_order; each lists its levels)
##   data/cosmetics/**/*.tres     CosmeticItem    (see the Cosmetics autoload)
##   data/ui/*.tres               UiExtension     (menu pages, HUD widgets, results sections)
##
## Works in exported builds too (handles .remap files).

var _weapons: Array[WeaponData] = []
var _weapon_map := {}
var _enemies := {}
var _worlds: Array[WorldData] = []
var _levels := {}
var _cosmetics: Array[CosmeticItem] = []
var _ui: Array[UiExtension] = []


func _ready() -> void:
	for r in scan("res://data/weapons", false):
		if r is WeaponData:
			_weapons.append(r)
			_weapon_map[r.id] = r
	_weapons.sort_custom(func(a, b): return a.sort_order < b.sort_order if a.sort_order != b.sort_order else String(a.id) < String(b.id))
	for r in scan("res://data/enemies", true):
		if r is EnemyData:
			_enemies[r.id] = r
	for r in scan("res://data/worlds", false):
		if r is WorldData:
			_worlds.append(r)
	_worlds.sort_custom(func(a, b): return a.sort_order < b.sort_order if a.sort_order != b.sort_order else String(a.id) < String(b.id))
	for world in _worlds:
		for level in world.levels:
			if level:
				_levels[level.id] = level
				level.world = world
	for r in scan("res://data/cosmetics", true):
		if r is CosmeticItem:
			_cosmetics.append(r)
	_cosmetics.sort_custom(func(a, b): return a.sort_order < b.sort_order if a.sort_order != b.sort_order else String(a.id) < String(b.id))
	for r in scan("res://data/ui", true):
		if r is UiExtension:
			_ui.append(r)
	_ui.sort_custom(func(a, b): return a.order < b.order)


## Loads every resource in `dir` (optionally recursing).
static func scan(dir: String, recursive: bool) -> Array[Resource]:
	var out: Array[Resource] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	var seen := {}
	for file in d.get_files():
		# Exported builds list "x.tres.remap" (text resources become binary).
		var name := file.trim_suffix(".remap")
		if not (name.ends_with(".tres") or name.ends_with(".res")) or seen.has(name):
			continue
		seen[name] = true
		var res := load(dir.path_join(name))
		if res:
			out.append(res)
	if recursive:
		for sub in d.get_directories():
			out.append_array(scan(dir.path_join(sub), true))
	return out


func weapons() -> Array[WeaponData]:
	return _weapons


func weapon(id: StringName) -> WeaponData:
	return _weapon_map.get(id)


func enemy(id: StringName) -> EnemyData:
	return _enemies.get(id)


func enemies() -> Array:
	return _enemies.values()


func level(id: StringName) -> LevelData:
	return _levels.get(id)


func worlds() -> Array[WorldData]:
	return _worlds


func cosmetics() -> Array[CosmeticItem]:
	return _cosmetics


func ui_extensions(kind: UiExtension.Kind) -> Array[UiExtension]:
	var out: Array[UiExtension] = []
	for e in _ui:
		if e.kind == kind:
			out.append(e)
	return out


func default_weapon_id() -> StringName:
	return _weapons[0].id if not _weapons.is_empty() else &""


## A weapon is usable if it has no requirement or the requirement is met.
func is_weapon_unlocked(w: WeaponData) -> bool:
	return w != null and (w.unlock == null or w.unlock.is_met())


func is_world_unlocked(world: WorldData) -> bool:
	return world.requirement == null or world.requirement.is_met()


## A level is playable when it has a scene and its requirements are met.
func is_level_unlocked(level_data: LevelData) -> bool:
	if level_data.scene_path.is_empty() or level_data.wave_set == null:
		return false
	if level_data.world and not is_world_unlocked(level_data.world):
		return false
	if level_data.requirement and not level_data.requirement.is_met():
		return false
	if level_data.requires_level == &"":
		return true
	return Profile.is_level_completed(level_data.requires_level)


func lock_reason(level_data: LevelData) -> String:
	if level_data.scene_path.is_empty() or level_data.wave_set == null:
		return "Coming soon"
	if level_data.world and level_data.world.requirement and not level_data.world.requirement.is_met():
		return level_data.world.requirement.describe()
	if level_data.requirement and not level_data.requirement.is_met():
		return level_data.requirement.describe()
	if level_data.requires_level != &"" and not Profile.is_level_completed(level_data.requires_level):
		var req := level(level_data.requires_level)
		return "Clear %s to unlock" % (req.display_name if req else String(level_data.requires_level))
	return ""
