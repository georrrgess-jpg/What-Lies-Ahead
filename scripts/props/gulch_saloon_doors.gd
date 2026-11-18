extends Node3D
## Bat-wing doors of the Gold Pan Saloon (art/blender/build_gulch_town.py):
## when the player or a zombie walks into the doorway both leaves are shoved
## away from them and swing back and forth on their hinges until they hang at
## rest again. Attach to the instanced saloon model.

## Distance (metres) from the doorway at which someone pushes through.
const PUSH_RADIUS := 1.5
const POLL_SECONDS := 0.2
const STIFFNESS := 38.0
const DAMPING := 4.5
const KICK := 5.5

var _leaves: Array[Node3D] = []
var _rest: Array[float] = []
var _offset := 0.0
var _speed := 0.0
var _poll := 0.0
var _center := Vector3.ZERO


func _ready() -> void:
	for leaf_name: String in ["SaloonDoorL", "SaloonDoorR"]:
		var leaf := find_child(leaf_name, true, false) as Node3D
		if leaf:
			_leaves.append(leaf)
			_rest.append(leaf.rotation.y)
	if _leaves.size() < 2:
		set_process(false)
		return
	_center = (_leaves[0].global_position + _leaves[1].global_position) * 0.5


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_SECONDS
		_look_for_walkers()
	if absf(_offset) < 0.001 and absf(_speed) < 0.01:
		return
	_speed += (-STIFFNESS * _offset - DAMPING * _speed) * delta
	_offset += _speed * delta
	for i in _leaves.size():
		var ext := -signf(_leaves[i].position.x - _leaves[1 - i].position.x)
		_leaves[i].rotation.y = _rest[i] + _offset * ext


## A walker in the doorway while the leaves hang still shoves them away from
## the side they came from.
func _look_for_walkers() -> void:
	if absf(_offset) > 0.05 or absf(_speed) > 0.5:
		return
	var reach := PUSH_RADIUS * PUSH_RADIUS
	for group: StringName in [&"player", &"zombies"]:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or body.global_position.distance_squared_to(_center) > reach:
				continue
			var local := _leaves[0].get_parent_node_3d().to_local(body.global_position)
			_speed = KICK * signf(local.z)
			return
