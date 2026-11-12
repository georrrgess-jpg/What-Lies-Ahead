class_name FrostLift
extends Node3D
## Runs a looped cable lift (the chairlift and the gondola at Summit Lodge).
## Every child is a carrier (chair or cabin) hanging from its grip point; they
## are spread evenly along `path` and travel around it at `speed`, turning to
## face their direction of travel but always hanging upright.

## Closed loop of cable points (world space), in travel order.
@export var path := PackedVector3Array()
@export var speed := 2.2

var _lengths := PackedFloat32Array()
var _total := 0.0
var _offset := 0.0
var _carriers: Array[Node3D] = []


func _ready() -> void:
	for child in get_children():
		if child is Node3D:
			_carriers.append(child)
	if path.size() < 2 or _carriers.is_empty():
		set_process(false)
		return
	_lengths.resize(path.size())
	for i in path.size():
		_lengths[i] = _total
		_total += path[i].distance_to(path[(i + 1) % path.size()])
	_place()


func _process(delta: float) -> void:
	_offset = fmod(_offset + speed * delta, _total)
	_place()


func _place() -> void:
	var gap := _total / _carriers.size()
	for i in _carriers.size():
		var d := fmod(_offset + gap * i, _total)
		var seg := _segment_at(d)
		var a := path[seg]
		var b := path[(seg + 1) % path.size()]
		var seg_len := maxf(0.001, a.distance_to(b))
		var t := (d - _lengths[seg]) / seg_len
		var carrier := _carriers[i]
		carrier.global_position = a.lerp(b, t)
		var dir := b - a
		carrier.rotation.y = atan2(dir.x, dir.z)


## Index of the path segment containing distance `d` (binary search).
func _segment_at(d: float) -> int:
	var lo := 0
	var hi := _lengths.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if _lengths[mid] <= d:
			lo = mid
		else:
			hi = mid - 1
	return lo
