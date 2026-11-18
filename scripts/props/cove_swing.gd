extends Node3D
## The Kraken Swing's gondola at Skull Harbor: swings about its axle (local X)
## like a pendulum, easing at the top of each arc, between `amplitude_degrees`
## either way. The node's origin is the axle.

@export var amplitude_degrees := 40.0
## Seconds for a full swing there and back.
@export var period := 6.5

var _base := Basis()
var _time := 0.0


func _ready() -> void:
	_base = basis


func _process(delta: float) -> void:
	_time += delta
	var angle := deg_to_rad(amplitude_degrees) * sin(TAU * _time / period)
	basis = _base * Basis(Vector3.RIGHT, angle)
