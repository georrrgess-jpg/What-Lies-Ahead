class_name FrostIceRink
extends Node3D
## The frozen pond at Summit Lodge. While the player stands on the ice their
## ground acceleration and braking drop sharply, so they keep sliding and
## turns are wide. Zombies shuffle a little slower on it.
## The rink is the ellipse `radii` (world X / Z half-axes) around this node.

@export var radii := Vector2(7.5, 6.0)
## Fraction of normal acceleration and braking left on the ice.
@export var player_grip := 0.16
## Zombie chase speed on the ice (multiplier).
@export var zombie_speed := 0.8

var _player: Player
var _base_accel := 0.0
var _base_decel := 0.0
var _on_ice := false


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
		_base_accel = _player.acceleration
		_base_decel = _player.deceleration
	var inside := _player.is_on_floor() and is_on_ice(_player.global_position)
	if inside != _on_ice:
		_on_ice = inside
		_player.acceleration = _base_accel * (player_grip if inside else 1.0)
		_player.deceleration = _base_decel * (player_grip if inside else 1.0)
	for z in get_tree().get_nodes_in_group("zombies"):
		if is_on_ice((z as Node3D).global_position):
			(z as Zombie).speed_multiplier = minf((z as Zombie).speed_multiplier, zombie_speed)


## True if a world position is on the ice (and near its surface).
func is_on_ice(world_position: Vector3) -> bool:
	var local := world_position - global_position
	if absf(local.y) > 0.8:
		return false
	return pow(local.x / radii.x, 2.0) + pow(local.z / radii.y, 2.0) <= 1.0


func _exit_tree() -> void:
	if is_instance_valid(_player) and _on_ice:
		_player.acceleration = _base_accel
		_player.deceleration = _base_decel
