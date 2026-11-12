class_name LevelData
extends Resource
## Catalog entry for one handcrafted level.

## Stable ID used by saves and unlock requirements.
@export var id: StringName
@export var display_name := ""
@export_multiline var blurb := ""
## The level's own scene.
@export_file("*.tscn") var scene_path := ""
@export var wave_set: WaveSet
## ID of a level that must be cleared first. Empty = available from the start.
@export var requires_level: StringName
## Any other unlock condition (null = none).
@export var requirement: Requirement
@export var sort_order := 0
## Music loop and ambience bed (sound names, see Sfx / tools/gen_audio.py).
@export var music: StringName = &"boardwalk_loop"
@export var ambience: StringName = &"pier_ambience"
@export var music_volume_db := -9.0
@export var ambience_volume_db := -8.0
## Accent colour for menus and loading screens.
@export var accent_color := Color("ff3fa4")

## Set by GameData at load: the world that lists this level.
var world: WorldData
