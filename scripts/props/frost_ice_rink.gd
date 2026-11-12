class_name FrostIceRink
extends Node3D
## The frozen pond at Summit Lodge. Over the ice the player's grip
## (Player.surface_grip) drops sharply: acceleration and braking, air control
## and slide friction all shrink, so they keep sliding, turns are wide and
## slides run about three times as far. The grip stays low in the air above
## the pond, so hopping across is no better than skating. Zombies shuffle a
## little slower on it.
## The rink is the ellipse `radii` (world X / Z half-axes) around this node.

@export var radii := Vector2(7.5, 6.0)
## Share of the player's normal grip left on the ice.
@export var player_grip := 0.16
## Zombie chase speed on the ice (multiplier).
@export var zombie_speed := 0.8
## The grip stays low up to this high above the ice (a jump's height).
@export var air_height := 2.5

var _player: Player
var _on_ice := false


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	var inside := is_on_ice(_player.global_position, 0.8 if _player.is_on_floor() else air_height)
	if inside != _on_ice:
		_on_ice = inside
		_player.surface_grip = player_grip if inside else 1.0
	for z in get_tree().get_nodes_in_group("zombies"):
		if is_on_ice((z as Node3D).global_position):
			(z as Zombie).speed_multiplier = minf((z as Zombie).speed_multiplier, zombie_speed)


## True if a world position is over the ice, at most `height` above (or 0.8 m below) its surface.
func is_on_ice(world_position: Vector3, height := 0.8) -> bool:
	var local := world_position - global_position
	if local.y > height or local.y < -0.8:
		return false
	return pow(local.x / radii.x, 2.0) + pow(local.z / radii.y, 2.0) <= 1.0


func _exit_tree() -> void:
	if is_instance_valid(_player) and _on_ice:
		_player.surface_grip = 1.0
