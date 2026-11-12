extends Node3D
## Gentle idle motion for scenery: bobbing and rocking on the swell (boats,
## buoys) and a steady turn about the vertical axis (lighthouse beams).

## How far the node rises and falls (metres) and how long one swell takes.
@export var bob_height := 0.0
@export var bob_seconds := 3.0
## Peak roll and pitch (degrees) while it rides the swell.
@export var rock_degrees := 0.0
@export var spin_degrees_per_second := 0.0

var _base := Transform3D()
var _time := 0.0


func _ready() -> void:
	_base = transform
	# Out of step with its neighbours.
	_time = fposmod(position.x * 0.37 + position.z * 0.21, maxf(0.1, bob_seconds))


func _process(delta: float) -> void:
	_time += delta
	var phase := TAU * _time / maxf(0.1, bob_seconds)
	var moved := _base
	if spin_degrees_per_second != 0.0:
		moved.basis = moved.basis.rotated(Vector3.UP, deg_to_rad(spin_degrees_per_second) * _time)
	if rock_degrees != 0.0:
		var rock := deg_to_rad(rock_degrees)
		moved.basis = moved.basis * Basis(Vector3.RIGHT, rock * sin(phase * 0.5 + 1.0)) * Basis(Vector3.BACK, rock * 0.6 * sin(phase))
	moved.origin.y += bob_height * sin(phase)
	transform = moved
