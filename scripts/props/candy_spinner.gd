class_name CandySpinner
extends Node3D
## A factory machine part that turns steadily about one of its own axes: the
## gumball machine's crank, the taffy puller's arms, a mixing vat's paddle.
## During the Sugar Rush twist the factory speeds every spinner up
## (group "candy_machine", see CandySugarRush).

## Local axis to turn about.
@export var axis := Vector3.UP
@export var degrees_per_second := 30.0

## Multiplies the turning speed (the Sugar Rush raises it).
var rush := 1.0

var _base := Basis()
var _angle := 0.0


func _ready() -> void:
	add_to_group("candy_machine")
	_base = basis
	_angle = fposmod(position.x * 13.0 + position.z * 7.0, 360.0)


func _process(delta: float) -> void:
	_angle = fposmod(_angle + degrees_per_second * rush * delta, 360.0)
	basis = _base * Basis(axis.normalized(), deg_to_rad(_angle))
