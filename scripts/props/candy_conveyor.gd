class_name CandyConveyor
extends MultiMeshInstance3D
## Sweets riding a conveyor belt: the MultiMesh's instances slide from `start`
## to `end` (local space) at `speed` and wrap round, keeping their spacing.
## Each instance keeps the yaw it was given at build time. The Sugar Rush twist
## speeds the belts up (group "candy_machine").

@export var start := Vector3.ZERO
@export var end := Vector3(4, 0, 0)
## Metres per second along the belt.
@export var speed := 0.6

## Multiplies the belt speed (the Sugar Rush raises it).
var rush := 1.0

var _offsets := PackedFloat32Array()
var _bases: Array[Basis] = []
var _length := 1.0
var _dir := Vector3.RIGHT
var _travel := 0.0


func _ready() -> void:
	add_to_group("candy_machine")
	_length = maxf(0.01, start.distance_to(end))
	_dir = (end - start) / _length
	for i in multimesh.instance_count:
		var t := multimesh.get_instance_transform(i)
		_offsets.append((t.origin - start).dot(_dir))
		_bases.append(t.basis)


func _process(delta: float) -> void:
	_travel = fposmod(_travel + speed * rush * delta, _length)
	for i in _offsets.size():
		var d := fposmod(_offsets[i] + _travel, _length)
		multimesh.set_instance_transform(i, Transform3D(_bases[i], start + _dir * d))
