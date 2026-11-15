class_name GroundControlMode
extends WeaponMode
## Ground Control: charge-and-release radar pings. Every shot is a
## GroundControlRing sent at the point under the crosshair; the charge picks
## its size in STEP_COUNT steps (a tap is a small fast ping, a full charge a
## huge slow ring that knocks zombies back). Rings pierce, bounce once off
## scenery and mark every zombie they pass (GroundControlMark: outlined
## through walls, +15% damage taken).
##
## Overcharge: hold a full charge OVER_READY seconds longer and the dish
## turns pink and crackles; released, it sends the wide feedback blast
## (GroundControlRing.OVERCHARGE). Held OVER_HOLD seconds more, the gun
## stalls for STALL_TIME (no shot, the radar screen goes to static). The
## dish, beacon, solar wing and radar screen move in
## scripts/weapons/views/ground_control_view.gd.
##
## The data's charge runs from 0 (charge_min_fraction and
## charge_min_damage_scale are 0), so the controller's damage scale is the
## charge fraction itself.

const STEP_COUNT := 3
const OVER_READY := 0.7
const OVER_HOLD := 0.9
const STALL_TIME := 1.1
const STEP_SOUND := &"gc_step"
const OVER_SOUND := &"gc_overcharge"
const STALL_SOUND := &"gc_stall"
const BIG_SOUND := &"gc_fire_big"
const FEEDBACK_SOUND := &"gc_feedback"

## Charge step reached so far this charge (0 = a tap .. 3 = full).
var step := 0
## Seconds the charge has been held full.
var over := 0.0
## The step of the last ring sent (4 = the feedback blast), for the view.
var last_step := 0
var _stall_until := 0


func charging(charge: float, delta: float) -> float:
	var now := mini(STEP_COUNT, int(floor(charge * STEP_COUNT + 0.0001)))
	if now > step:
		step = now
		Sfx.play(STEP_SOUND, -6.0, 0.9 + 0.15 * step)
	if charge < 1.0:
		over = 0.0
		return 0.0
	var was_over := is_overcharged()
	over += delta
	if not was_over and is_overcharged():
		Sfx.play(OVER_SOUND, -3.0)
	if over >= OVER_READY + OVER_HOLD:
		_reset()
		_stall_until = Time.get_ticks_msec() + int(STALL_TIME * 1000.0)
		Sfx.play(STALL_SOUND, -2.0)
		return STALL_TIME
	return 0.0


func end_trigger() -> void:
	_reset()


func launch(from: Vector3, dir: Vector3, scale: float) -> bool:
	var shot := STEP_COUNT + 1 if is_overcharged() else mini(STEP_COUNT, int(floor(scale * STEP_COUNT + 0.0001)))
	_reset()
	last_step = shot
	var eye := controller.player.aim_transform().origin
	var query := PhysicsRayQueryParameters3D.create(eye, eye + dir * data.max_range, WeaponController.MASK_WORLD | WeaponController.MASK_ENEMIES)
	query.exclude = [controller.player.get_rid()]
	var hit := controller.player.get_world_3d().direct_space_state.intersect_ray(query)
	var aim_at: Vector3 = hit["position"] if not hit.is_empty() else eye + dir * data.max_range
	var to := aim_at - from
	var send := to.normalized() if to.length() > 1.5 else dir
	GroundControlRing.launch(controller.player.get_parent(), from, send, data, controller, shot)
	if shot > STEP_COUNT:
		Sfx.play(FEEDBACK_SOUND, -1.0)
		controller.player.add_shake(0.35)
	elif shot == STEP_COUNT:
		Sfx.play(BIG_SOUND, -3.0)
	return true


## 0-1: how far into the overcharge the held charge is (1 = the feedback blast is ready).
func overcharge() -> float:
	return clampf(over / OVER_READY, 0.0, 1.0)


func is_overcharged() -> bool:
	return over >= OVER_READY


## 0-1 of the warning before a stall (once overcharged).
func stall_warning() -> float:
	return clampf((over - OVER_READY) / OVER_HOLD, 0.0, 1.0)


## Seconds of a stall still to run.
func stall_left() -> float:
	return maxf(0.0, (_stall_until - Time.get_ticks_msec()) / 1000.0)


func _reset() -> void:
	step = 0
	over = 0.0
