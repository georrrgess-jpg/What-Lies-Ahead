class_name EndlessDistrict
extends Resource
## One district of an Endless map: a part of the city behind a gate. The
## start district is open from the beginning (price 0); every other one opens
## when the player pays its price in tickets at one of its gates
## (EndlessGate). Opening a district wakes its entrances (enemy spawns tagged
## with its id) and adds its enemies to the spawn pool. docs/ENDLESS.md.

## Stable id, used by the map's markers and gates and saved in the profile.
@export var id: StringName
@export var display_name := ""
## One line for the gate sign and the district reveal.
@export_multiline var blurb := ""
## Tickets to open it (0 = open from the start).
@export var price := 0
## Enemy ids that join the endless spawn pool once the district is open.
@export var enemies: Array[StringName] = []
@export var accent_color := Color("ff7a2e")
