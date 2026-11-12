class_name WorldData
extends Resource
## Catalog entry for one world (a themed group of levels).

@export var id: StringName
@export var display_name := ""
@export_multiline var blurb := ""
@export var levels: Array[LevelData] = []
