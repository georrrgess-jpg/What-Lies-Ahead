class_name StrikeZoneMode
extends WeaponMode
## Strike Zone (strike_zone): every shot is a bowling ball (StrikeZoneBall)
## dropped from the chamber and rolled down the flat line of the aim. The
## charge winds it up: a tap rolls it at TAP_SPEED share of projectile_speed
## for charge_min_damage_scale of the damage, a full wind-up at full speed
## and damage. Strikes on back-to-back rolls climb the bowling ladder
## (STRIKE!, DOUBLE!, TURKEY!); a roll without one resets it. The launcher's
## kicker, lane arrows and balls move in scripts/weapons/views/strike_zone_view.gd.

## Roll speed of a tap, as a share of a full wind-up's.
const TAP_SPEED := 0.55

## Strikes on back-to-back rolls (0 after a roll without one).
var streak := 0


func launch(from: Vector3, dir: Vector3, scale: float) -> bool:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.2:
		# Looking straight down or up: roll the way the player faces.
		flat = -controller.player.global_basis.z
	var power := inverse_lerp(data.charge_min_damage_scale, 1.0, scale) if data.charge_min_damage_scale < 1.0 else 1.0
	var speed := data.projectile_speed * lerpf(TAP_SPEED, 1.0, clampf(power, 0.0, 1.0))
	StrikeZoneBall.launch(controller, self, from, flat.normalized(), speed, scale)
	return true


## A roll scored a strike: returns its rung on the ladder (1 = STRIKE!,
## 2 = DOUBLE!, 3 and up = TURKEY!).
func scored_strike() -> int:
	streak += 1
	return streak


## A roll ended without a strike: the ladder starts again.
func missed_strike() -> void:
	streak = 0
