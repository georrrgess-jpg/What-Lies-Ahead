class_name PopcornPopperMode
extends WeaponMode
## Popcorn Popper: a kettle cannon that heats as it fires.
##
## Heat (0-1) climbs HEAT_PER_SHOT with every kernel and falls at COOL_RATE
## once the trigger has rested COOL_DELAY. It sets the stage of each shot
## (PopcornKernels flies and lands them):
##   cold   (below WARM_AT) single kernel pellets at the slowest rate
##   warm   (WARM_AT to HOT_AT) kernels pop into popcorn mid-flight and land
##          in a small splash puff; the popping speeds up
##   hot    (HOT_AT and up) big buttered popcorn at the fastest rate that
##          bursts wide and butters (slows) what it splashes
## A shot that takes the heat to 1 jams the kettle: nothing fires for
## JAM_TIME while the lid rattles and it vents down to JAM_VENT_TO. A
## reload never cools it below WARM_AT (the kettle keeps warm). Held
## down, the gun runs cold, warm, hot and jams; pulsed in short bursts it
## stays hot. The view (scripts/weapons/views/popcorn_popper_view.gd) reads
## `heat`, `stage()` and `jam`; PopcornHeatHud draws the gauge round the
## crosshair. The heat keeps while the gun is stowed (cooling for the time
## away), so a swap never clears a jam early.

enum Stage { COLD, WARM, HOT }

const WARM_AT := 0.34
const HOT_AT := 0.7
const HEAT_PER_SHOT := 0.025
## Heat lost per second once the trigger has rested COOL_DELAY seconds.
const COOL_RATE := 1.2
const COOL_DELAY := 0.08
## Seconds between shots per stage (the hot rate is WeaponData.fire_interval).
const COLD_INTERVAL := 0.12
const WARM_INTERVAL := 0.1
const JAM_TIME := 1.0
## Heat the kettle has vented down to when a jam clears (it comes back warm).
const JAM_VENT_TO := 0.45
## The playtest bot rests the trigger at BOT_REST heat until it is back to BOT_RESUME.
const BOT_REST := 0.96
const BOT_RESUME := 0.82
## Share of a fight the kettle spends hot (the Arsenal's DPS counts only that).
const HOT_UPTIME := 0.7
const STOWED_META := &"popcorn_heat"
const JAM_SOUND := &"pcp_jam"
const UNJAM_SOUND := &"pcp_unjam"
const STAGE_SOUND := &"pcp_stage"

## 0 cold to 1 overheated.
var heat := 0.0
## Seconds of jam left (0 = free).
var jam := 0.0
var _since := 10.0
var _rest := 10.0
var _restored := false
var _bot_resting := false
var _hud: PopcornHeatHud


## The Arsenal's DPS: kernels at the hot rate, paced by the rests that keep
## it hot, and the reload, over the HOT_UPTIME of a fight (the rest is
## warming up after a reload or a pause).
func arsenal_dps(_base: float) -> float:
	var per_shot := data.fire_interval + HEAT_PER_SHOT / COOL_RATE
	return HOT_UPTIME * data.damage * data.magazine_size / (data.magazine_size * per_shot + data.reload_time)


func stage() -> Stage:
	return stage_of(heat)


static func stage_of(h: float) -> Stage:
	if h >= HOT_AT:
		return Stage.HOT
	return Stage.WARM if h >= WARM_AT else Stage.COLD


func trigger(spinning: bool, delta: float) -> bool:
	_hook()
	_since += delta
	if jam > 0.0:
		jam -= delta
		heat = maxf(JAM_VENT_TO, heat - (1.0 - JAM_VENT_TO) / JAM_TIME * delta)
		if jam <= 0.0:
			jam = 0.0
			Sfx.play(UNJAM_SOUND, -4.0)
		return false
	if spinning:
		_rest = 0.0
	else:
		_rest += delta
		if _rest >= COOL_DELAY:
			# The kettle keeps warm while it is refilled.
			var floor_heat := minf(heat, WARM_AT) if controller.is_reloading() else 0.0
			heat = maxf(floor_heat, heat - COOL_RATE * delta)
	return _since >= _interval() - 0.001


func launch(from: Vector3, dir: Vector3, scale: float) -> bool:
	var eye := controller.player.aim_transform().origin
	var query := PhysicsRayQueryParameters3D.create(eye, eye + dir * data.max_range, WeaponController.MASK_WORLD | WeaponController.MASK_ENEMIES)
	query.exclude = [controller.player.get_rid()]
	var hit := controller.player.get_world_3d().direct_space_state.intersect_ray(query)
	var aim_at: Vector3 = hit["position"] if not hit.is_empty() else eye + dir * data.max_range
	var to := aim_at - from
	var before := stage()
	PopcornKernels.fire(controller, from, to.normalized() if to.length() > 0.5 else dir, data, scale, before)
	_since = 0.0
	heat = minf(1.0, heat + HEAT_PER_SHOT)
	if heat >= 1.0:
		_jam()
	elif stage() != before:
		Sfx.play(STAGE_SOUND, -6.0, 1.0 if stage() == Stage.WARM else 1.25)
	return true


func dispose() -> void:
	if _hud and is_instance_valid(_hud):
		_hud.get_parent().queue_free()
	controller.set_meta(STOWED_META, [heat, jam, Engine.get_physics_frames()])


# --- the bot (scripts/dev/dev_driver.gd) ---------------------------------------

## The playtest bot fires from the hip, like it does with every other gun.
func bot_aim() -> bool:
	return false


## The bot pulses the trigger the way a player learns to: it rests just
## before the jam and fires again once the kettle is back near the hot line.
func bot_fire(_nearest: float) -> bool:
	if jam > 0.0:
		return false
	if _bot_resting:
		_bot_resting = heat > BOT_RESUME
	else:
		_bot_resting = heat >= BOT_REST
	return not _bot_resting


# --- inside ---------------------------------------------------------------------

func _interval() -> float:
	match stage():
		Stage.COLD:
			return COLD_INTERVAL
		Stage.WARM:
			return WARM_INTERVAL
	return data.fire_interval


func _jam() -> void:
	jam = JAM_TIME
	Sfx.play(JAM_SOUND, -1.0)
	controller.player.add_shake(0.25)


## Restores the heat it was stowed with (cooled for the time away) and adds
## the heat gauge the first time the weapon is used.
func _hook() -> void:
	if _restored:
		return
	_restored = true
	var layer := CanvasLayer.new()
	layer.layer = 4
	_hud = PopcornHeatHud.new()
	_hud.mode = self
	layer.add_child(_hud)
	controller.add_child(layer)
	if not controller.has_meta(STOWED_META):
		return
	var stowed: Array = controller.get_meta(STOWED_META)
	var away := float(Engine.get_physics_frames() - int(stowed[2])) / Engine.physics_ticks_per_second
	jam = maxf(0.0, float(stowed[1]) - away)
	var cooled := maxf(0.0, away - float(stowed[1]))
	heat = maxf(JAM_VENT_TO if jam > 0.0 else 0.0, float(stowed[0]) - COOL_RATE * cooled)
