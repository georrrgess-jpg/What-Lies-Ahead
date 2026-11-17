class_name StrikeZoneMode
extends WeaponMode
## Strike Zone (strike_zone): every shot is a bowling ball (StrikeZoneBall)
## dropped from the chamber and rolled down the flat line of the aim; aimed
## up at a zombie or a floor on a ledge, or at a zombie behind a low wall, it
## is lobbed through the point aimed at instead (_lob_point). The
## charge winds it up: a tap rolls it at TAP_SPEED share of projectile_speed
## for charge_min_damage_scale of the damage, a full wind-up at full speed
## and damage. Strikes on back-to-back rolls climb the bowling ladder
## (STRIKE!, DOUBLE!, TURKEY!); a roll without one resets it. The launcher's
## kicker, lane arrows and balls move in scripts/weapons/views/strike_zone_view.gd.

## Roll speed of a tap, as a share of a full wind-up's.
const TAP_SPEED := 0.55
## A point aimed at this high (m) above the player's feet is up on a ledge.
## A lob takes at least LOB_MIN_TIME seconds and leaves at most LOB_MAX_LIFT
## m/s upward.
const LEDGE := 1.6
const LOB_MIN_TIME := 0.3
const LOB_MAX_LIFT := 15.0

## Strikes on back-to-back rolls (0 after a roll without one).
var streak := 0


func launch(from: Vector3, dir: Vector3, scale: float) -> bool:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.2:
		# Looking straight down or up: roll the way the player faces.
		flat = -controller.player.global_basis.z
	flat = flat.normalized()
	var power := inverse_lerp(data.charge_min_damage_scale, 1.0, scale) if data.charge_min_damage_scale < 1.0 else 1.0
	var speed := data.projectile_speed * lerpf(TAP_SPEED, 1.0, clampf(power, 0.0, 1.0))
	var lift := -StrikeZoneBall.DROP_SPEED
	var up_at := _lob_point(dir)
	if up_at != Vector3.INF:
		# Lobbed through the point aimed at, onto the ledge or over the wall.
		var to := up_at - from
		var reach := Vector2(to.x, to.z).length()
		flat = Vector3(to.x, 0.0, to.z) / maxf(reach, 0.01)
		var t := maxf(LOB_MIN_TIME, reach / speed)
		lift = minf(LOB_MAX_LIFT, (to.y + 0.5 * StrikeZoneBall.GRAVITY * t * t) / t)
	StrikeZoneBall.launch(controller, self, from, flat, speed, scale, lift)
	return true


## The point aimed at when the ball cannot roll there: it stands LEDGE above
## the player's feet (a zombie or a floor up on a bridge), or scenery blocks
## the lane to it at rolling height (a zombie behind a low wall). Otherwise
## Vector3.INF.
func _lob_point(dir: Vector3) -> Vector3:
	var player := controller.player
	var space := player.get_world_3d().direct_space_state
	var eye := player.aim_transform().origin
	var query := PhysicsRayQueryParameters3D.create(eye, eye + dir * data.max_range, WeaponController.MASK_WORLD | WeaponController.MASK_ENEMIES)
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return Vector3.INF
	var at: Vector3 = hit["position"]
	var feet := player.global_position
	if at.y - feet.y >= LEDGE:
		return at
	if not (hit["collider"] is Zombie):
		return Vector3.INF
	var low := feet + Vector3.UP * (data.projectile_size + 0.1)
	var lane := PhysicsRayQueryParameters3D.create(low, Vector3(at.x, low.y, at.z), WeaponController.MASK_WORLD)
	lane.exclude = query.exclude
	return at if not space.intersect_ray(lane).is_empty() else Vector3.INF


## A roll scored a strike: returns its rung on the ladder (1 = STRIKE!,
## 2 = DOUBLE!, 3 and up = TURKEY!).
func scored_strike() -> int:
	streak += 1
	return streak


## A roll ended without a strike: the ladder starts again.
func missed_strike() -> void:
	streak = 0
