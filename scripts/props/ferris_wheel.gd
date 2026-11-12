extends Node3D
## Slowly turns the Ferris wheel (about its axle, local Z) and keeps its
## gondolas hanging upright.

@export var degrees_per_second := 6.0

var _wheel: Node3D
var _gondolas: Array[Node3D] = []


func _ready() -> void:
	_wheel = find_child("Wheel", true, false) as Node3D
	if _wheel == null:
		set_process(false)
		return
	for child in _wheel.get_children():
		if String(child.name).begins_with("Gondola"):
			_gondolas.append(child)


func _process(delta: float) -> void:
	var step := deg_to_rad(degrees_per_second) * delta
	_wheel.rotate_object_local(Vector3.BACK, step)
	for g in _gondolas:
		g.rotate_object_local(Vector3.BACK, -step)
