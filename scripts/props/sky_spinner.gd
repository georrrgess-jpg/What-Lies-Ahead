class_name SkySpinner
extends Node3D
## Turns a node steadily about one of its local axes: Sky Harbor's pinwheels,
## turbine rotors, airship propellers, the beacon lamp and the carousel. The
## Gale twist raises `SkySpinner.wind`, so everything in the wind races.

## The level's wind factor (1 = calm). SkyGale eases it up and back down.
static var wind := 1.0

## Local axis to turn about.
@export var axis := Vector3.BACK
@export var degrees_per_second := 90.0
## How much the wind factor speeds this one up (0 = not at all, the carousel).
@export var wind_response := 1.0

var _base := Basis()
var _angle := 0.0


func _ready() -> void:
	_base = basis
	_angle = deg_to_rad(fposmod(position.x * 13.0 + position.z * 7.0, 360.0))


func _process(delta: float) -> void:
	var k := 1.0 + (wind - 1.0) * wind_response
	_angle = fposmod(_angle + deg_to_rad(degrees_per_second) * k * delta, TAU)
	basis = _base * Basis(axis.normalized(), _angle)
