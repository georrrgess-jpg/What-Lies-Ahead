class_name ToyTrain
extends Node3D
## The toy train on its elevated loop round Toy Shop: the locomotive and its
## cars (this node's children, in order) run along an ellipse at a steady
## speed, each a fixed distance behind the one before. The ellipse is sampled
## once into an arc-length table, so every car keeps the same real speed, and
## the engine whistles now and then as it rounds the shop.

const SAMPLES := 256

## Semi-axes of the loop along X and Z (metres), and the rail-top height.
@export var radius := Vector2(28.0, 22.0)
@export var height := 6.4
## Running speed (m/s) and the distance between car centres.
@export var speed := 5.5
@export var spacing := 4.4
## Seconds between whistles (a random pick in this range).
@export var whistle_interval := Vector2(14.0, 24.0)
@export var whistle_sound: StringName = &"toy_train_whistle"
## Speed multiplier (the wind-up twist drives it).
var pace := 1.0

var _lengths := PackedFloat32Array()
var _length := 0.0
var _travel := 0.0
var _whistle := 6.0
var _cars: Array[Node3D] = []


func _ready() -> void:
	for child in get_children():
		if child is Node3D:
			_cars.append(child)
	_lengths.resize(SAMPLES + 1)
	var prev := _point(0.0)
	for i in range(1, SAMPLES + 1):
		var p := _point(TAU * i / SAMPLES)
		_length += prev.distance_to(p)
		_lengths[i] = _length
		prev = p
	_place()


func _process(delta: float) -> void:
	_travel = fposmod(_travel + speed * pace * delta, _length)
	_place()
	_whistle -= delta
	if _whistle <= 0.0 and not _cars.is_empty():
		_whistle = randf_range(whistle_interval.x, whistle_interval.y)
		Sfx.play_at(whistle_sound, _cars[0].global_position, 0.0, randf_range(0.95, 1.05), 30.0)


func _place() -> void:
	for i in _cars.size():
		var a := _angle_at(fposmod(_travel - i * spacing, _length))
		var p := _point(a)
		var forward := (_point(a + 0.01) - p).normalized()
		_cars[i].transform = Transform3D(Basis.looking_at(-forward, Vector3.UP), p)


func _point(angle: float) -> Vector3:
	return Vector3(cos(angle) * radius.x, height, sin(angle) * radius.y)


## The ellipse angle at arc length `d` (binary search in the table).
func _angle_at(d: float) -> float:
	var lo := 0
	var hi := SAMPLES
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if _lengths[mid] <= d:
			lo = mid
		else:
			hi = mid
	var span := maxf(0.0001, _lengths[hi] - _lengths[lo])
	return TAU * (lo + (d - _lengths[lo]) / span) / SAMPLES
