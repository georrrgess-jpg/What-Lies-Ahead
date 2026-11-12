class_name WorldData
extends Resource
## Catalog entry for one world (a themed group of levels).

@export var id: StringName
@export var display_name := ""
@export_multiline var blurb := ""
@export var levels: Array[LevelData] = []
## Position on the world select (lower first).
@export var sort_order := 0
## One-line hook shown under the world name.
@export var tagline := ""
## Unlock condition for the whole world (null = always open).
@export var requirement: Requirement
## Menu theming: main accent, secondary and dark backing colours.
@export var accent_color := Color("ff3fa4")
@export var secondary_color := Color("35f0ff")
@export var backdrop_color := Color("1b1446")
