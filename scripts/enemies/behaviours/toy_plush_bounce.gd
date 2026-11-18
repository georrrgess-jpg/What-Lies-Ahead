class_name ToyPlushBounceBehaviour
extends SkyDiveBehaviour
## Plush Brute: a stuffed heavy that bounces. At mid range it squashes down
## (the Crouch clip, a creaking-spring sound, the HUD threat ring) while a ring
## lights up on the floor where it will come down, then it springs up in a high
## arc and lands on the ring with a soft, heavy thump: anyone still inside is
## hurt and bounced back out of it. The ring is fixed when the squash starts,
## so stepping out of it is the dodge; a headshot during the squash cancels
## the bounce (the Sky Diver's marker and timing, without the canopy).

## Push (m/s) given to a player caught in the landing, away from its centre.
@export var bounce_push := 8.5
## Upward pop (m/s) added to the push.
@export var bounce_lift := 3.5


## A plain bouncing-ball parabola (no canopy descent).
func _arc_point(t: float) -> Vector3:
	return _from.lerp(_to, t) + Vector3.UP * apex * 4.0 * t * (1.0 - t)


## No canopy: a plush comes down on its own.
func _open_canopy(_z: Zombie) -> void:
	pass


func _on_landed(z: Zombie) -> void:
	super._on_landed(z)
	var player := z.target
	if player == null or not player.alive:
		return
	var away := player.global_position - _to
	away.y = 0.0
	if away.length() > landing_radius or absf(player.global_position.y - _to.y) > 1.6:
		return
	var dir := away.normalized() if away.length() > 0.1 else -z.global_transform.basis.z
	player.velocity += dir * bounce_push + Vector3.UP * bounce_lift
