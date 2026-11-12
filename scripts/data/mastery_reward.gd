class_name MasteryReward
extends Resource
## One cosmetic unlock on a weapon's mastery track. Purely visual.

enum Kind { DECAL, CELL, FINISH }

## Stable ID. Saved in the profile, so never rename it once shipped.
@export var id: StringName
@export var display_name := ""
@export var kind: Kind = Kind.DECAL
## Mastery rank (1-based) that unlocks this reward.
@export_range(1, 10) var rank_required := 1
## DECAL: emblem colour. CELL: energy-cell colour. FINISH: shell colour.
@export var color := Color.WHITE
## FINISH only: colour for the trim panels.
@export var secondary_color := Color.WHITE
@export_range(0.0, 1.0) var metallic := 0.0
@export_range(0.0, 1.0) var roughness := 0.5


func slot() -> String:
	match kind:
		Kind.DECAL: return "decal"
		Kind.CELL: return "cell"
		_: return "finish"


func kind_label() -> String:
	match kind:
		Kind.DECAL: return "Decal"
		Kind.CELL: return "Energy cell"
		_: return "Shell finish"
