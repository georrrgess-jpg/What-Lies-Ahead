class_name MotionSpring
extends RefCounted
## A damped spring for procedural camera and viewmodel motion. `value` chases
## the target passed to update(); kick() adds velocity for one-off jolts
## (landings, jumps). It integrates in small sub-steps, so it behaves the same
## at 30 fps and 240 fps and never blows up on a long frame (stiff springs,
## such as recoil's, included).

const MAX_STEP := 1.0 / 240.0
const MAX_DELTA := 0.1

var value := Vector3.ZERO
var velocity := Vector3.ZERO
## Natural frequency (rad/s): higher is snappier.
var frequency: float
## Damping ratio: 1 settles without overshoot, lower values wobble.
var damping: float


func _init(omega := 14.0, zeta := 0.55) -> void:
	frequency = omega
	damping = zeta


## Advances the spring toward `target` by `delta` seconds and returns its value.
func update(target: Vector3, delta: float) -> Vector3:
	var left := minf(delta, MAX_DELTA)
	var k := frequency * frequency
	var c := 2.0 * damping * frequency
	while left > 0.0:
		var dt := minf(left, MAX_STEP)
		velocity += ((target - value) * k - velocity * c) * dt
		value += velocity * dt
		left -= dt
	return value


func kick(impulse: Vector3) -> void:
	velocity += impulse


func reset() -> void:
	value = Vector3.ZERO
	velocity = Vector3.ZERO
