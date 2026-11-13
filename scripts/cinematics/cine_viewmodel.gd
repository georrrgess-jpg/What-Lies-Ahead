class_name CineViewmodel
extends WeaponView
## The game's first-person weapon (WeaponView: sway, kick, flash, reload) for
## a shot with no Player behind it. The shot drives what the player would:
## `aim` brings the real sight to the eye (the same eye line WeaponView aims
## along, with the optic's reticle lit), `sprint`, `slide` and `mantle` blend
## the movement poses, and `gait` sets the run bob's phase and size.

## 0 = hip, 1 = aimed down the sight.
var aim := 0.0
var sprint := 0.0
var slide := 0.0
var mantle := 0.0
## Run bob: x = phase (radians), y = amount (0-1).
var gait := Vector2.ZERO


func _process(delta: float) -> void:
	super(delta)
	if model == null or aim <= 0.0:
		return
	var ads_pos := -_eye_local + Vector3(0.0, 0.0, _kick * 0.5)
	var ads_rot := Vector3(_kick_rot * 0.35, 0.0, 0.0)
	_holder.position = _holder.position.lerp(ads_pos, aim)
	_holder.rotation_degrees = _holder.rotation_degrees.lerp(ads_rot, aim)
	if _sight and _sight.has_reticle:
		_sight.set_aim(Basis.IDENTITY, smoothstep(RETICLE_IN, 0.95, aim))


func _pose_target_pos() -> Vector3:
	return SPRINT_POS * sprint + SLIDE_POS * slide + MANTLE_POS * mantle


func _pose_target_rot() -> Vector3:
	return SPRINT_ROT * sprint + SLIDE_ROT * slide + MANTLE_ROT * mantle


func _bob() -> Vector3:
	var c := cos(gait.x)
	return Vector3(BOB_SIDE * sin(gait.x), BOB_DIP * (0.5 - c * c * c * c), BOB_ROLL * sin(gait.x)) * gait.y * (1.0 + 0.5 * sprint)


## Fits the sight the model wears now (after a cosmetics change).
func refit() -> void:
	_fit_sight()
