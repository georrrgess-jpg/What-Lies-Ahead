extends MeleeMode
## Ticket Flipper (ticket_flipper): the balisong's heavy is a lunge-slash.
## Letting the wind-up go throws the player forward along the aim (a short
## dash that keeps the knife's quick feet) and the cut lands as the dash ends,
## so the heavy reaches a little further than a light slash.

const TRAIT := "Lunge"
## Speed of the lunge (m/s, along the ground) at full charge, and the share of it a tap gets.
const LUNGE_SPEED := 11.0
const LUNGE_MIN := 0.45
## How long the lunge carries the player (s) and the extra move scale meanwhile.
const LUNGE_TIME := 0.22
const LUNGE_MOVE := 1.6

var _lunge_left := 0.0
var _lunge_dir := Vector3.ZERO
var _lunge_speed := 0.0


func swing_input(fire: bool, aim: bool, ready: bool, delta: float) -> bool:
	var was := phase
	var used := super.swing_input(fire, aim, ready, delta)
	if was == Phase.WINDUP and phase == Phase.HEAVY:
		var forward := -controller.player.aim_transform().basis.z
		_lunge_dir = Vector3(forward.x, 0.0, forward.z).normalized()
		_lunge_speed = LUNGE_SPEED * lerpf(LUNGE_MIN, 1.0, charge)
		_lunge_left = LUNGE_TIME
	if _lunge_left > 0.0:
		_lunge_left = maxf(0.0, _lunge_left - delta)
		var body := controller.player
		var along := Vector3(body.velocity.x, 0.0, body.velocity.z).dot(_lunge_dir)
		if along < _lunge_speed:
			body.velocity += _lunge_dir * (_lunge_speed - along)
	return used


func move_scale() -> float:
	return super.move_scale() * (LUNGE_MOVE if _lunge_left > 0.0 else 1.0)


func end_trigger() -> void:
	super.end_trigger()
	_lunge_left = 0.0
