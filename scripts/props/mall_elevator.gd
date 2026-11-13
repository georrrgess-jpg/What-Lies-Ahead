extends Node3D
## The Moonbeam Galleria's glass elevator cab: rides between the two floors,
## easing in and out, and waits at each stop with its doors "open".

## Cab floor heights of the two stops (local Y).
@export var low := 0.0
@export var high := 5.0
## Seconds spent travelling between the stops and waiting at each one.
@export var travel_seconds := 4.5
@export var wait_seconds := 3.5

var _time := 0.0


func _ready() -> void:
	# Out of step with the level's start, so the cab is not always downstairs.
	_time = fposmod(position.x * 1.7 + position.z * 0.9, (travel_seconds + wait_seconds) * 2.0)


func _process(delta: float) -> void:
	_time = fposmod(_time + delta, (travel_seconds + wait_seconds) * 2.0)
	var leg := travel_seconds + wait_seconds
	var going_up := _time < leg
	var t := clampf((fmod(_time, leg) - wait_seconds) / travel_seconds, 0.0, 1.0)
	var k := smoothstep(0.0, 1.0, t)
	position.y = lerpf(low, high, k) if going_up else lerpf(high, low, k)
