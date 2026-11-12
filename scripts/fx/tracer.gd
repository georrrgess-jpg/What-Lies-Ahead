class_name Tracer
extends MeshInstance3D
## A short energy streak flying along a shot line.

const SPEED := 160.0
const LENGTH := 3.5

var _from := Vector3.ZERO
var _dir := Vector3.FORWARD
var _distance := 0.0
var _travelled := 0.0
var _width := 0.03


func launch(from: Vector3, to: Vector3, width: float) -> void:
	_from = from
	_distance = from.distance_to(to)
	_dir = (to - from) / _distance
	_width = width
	_travelled = minf(LENGTH * 0.5, _distance)
	_update()


func _process(delta: float) -> void:
	_travelled += SPEED * delta
	if _travelled - LENGTH >= _distance:
		queue_free()
		return
	_update()


func _update() -> void:
	var head := minf(_travelled, _distance)
	var tail := clampf(_travelled - LENGTH, 0.0, _distance)
	var length := maxf(0.05, head - tail)
	var mid := _from + _dir * (tail + length * 0.5)
	var up := Vector3.UP if absf(_dir.y) < 0.95 else Vector3.RIGHT
	var b := Basis.looking_at(_dir, up)
	global_transform = Transform3D(Basis(b.x * _width, b.y * _width, b.z * length), mid)
