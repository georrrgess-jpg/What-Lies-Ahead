class_name EnemyLook
extends Resource
## A world outfit for an enemy (EnemyData.world_outfits). In levels of `world`
## the enemy wears this look: its model, accessory slots and colours replace the
## enemy's own (stats, behaviours and hitboxes stay the same). The model needs
## the same outfit mesh (Outfit_<EnemyData.outfit>) and clips as the default one.

## WorldData id this look is for (e.g. &"frostpeak_resort").
@export var world: StringName
@export var model_scene: PackedScene
## Replace the enemy's lists; an empty list means no tint.
@export var shirt_colors: Array[Color] = []
@export var skin_colors: Array[Color] = []
@export var accessory_slots: PackedStringArray = PackedStringArray()


## Copies this look's visual fields onto `enemy` (a copy of the EnemyData).
func apply_to(enemy: EnemyData) -> void:
	if model_scene:
		enemy.model_scene = model_scene
	enemy.shirt_colors = shirt_colors
	enemy.skin_colors = skin_colors
	enemy.accessory_slots = accessory_slots
