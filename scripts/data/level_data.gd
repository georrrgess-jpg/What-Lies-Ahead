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
