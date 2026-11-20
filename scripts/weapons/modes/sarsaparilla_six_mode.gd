class_name SarsaparillaSixMode
extends WeaponMode
## Sarsaparilla Six (sarsaparilla_six): a soda-pop six-shooter.
##
##   tap       one accurate shot a pull, no faster than TAP_INTERVAL (the
##             thumb cocks the hammer between shots)
##   hold      "fan the hammer": keep the trigger held past FAN_DELAY and the
##             off hand slaps the hammer back again and again, emptying the
##             cylinder at the data rate (WeaponData.fire_interval) while the
##             cone widens by FAN_SPREAD degrees a shot (up to FAN_SPREAD_MAX)
##   Last Call the shot that empties the cylinder (the sixth chamber, a gold
##             star cap) fizzes: LAST_CALL_SCALE damage, an extra shove, a
##             fizz trail and a soda pop that splashes the zombies round the
##             hit (POP_DAMAGE, POP_RADIUS). The cylinder on the gun and the
##             HUD ring under the crosshair (SarsaparillaCylinderHud) count
##             the rounds so it can be saved for the right zombie.
##
## Six rounds and a slow-ish speed-loader reload: a burst sidearm that rewards
## counting shots, poor at sustained fire. The cylinder, hammer, fan hand and
## bottle move in scripts/weapons/views/sarsaparilla_six_view.gd (reads
## fanning, since_shot, pull_shots and is_last_call()).

const ROUNDS := 6
## Seconds between tapped shots (the data rate is the fanned one).
const TAP_INTERVAL := 0.26
## Seconds the trigger must stay down after a pull's first shot before fanning.
const FAN_DELAY := 0.16
## Extra spread (degrees) per shot already fired in a fanned pull, and its cap.
const FAN_SPREAD := 1.3
const FAN_SPREAD_MAX := 5.0
const LAST_CALL_SCALE := 1.6
const LAST_CALL_PUSH := 3.0
const POP_RADIUS := 2.2
const POP_DAMAGE := 16.0
const LAST_CALL_SOUND := &"ssx_last_call"
## View events: a Last Call left the barrel.
const LAST_CALL_EVENT := &"last_call"
## The bot fans the hammer at zombies closer than this (metres) and taps beyond.
const BOT_FAN_RANGE := 7.0
const FIZZ := [Color(1.0, 0.957, 0.839), Color(1.0, 0.647, 0.227), Color(1.0, 0.239, 0.431)]

## True while the off hand fans the hammer (the trigger held past FAN_DELAY).
var fanning := false
## Shots fired in the current pull (the fan's spread grows with them).
var pull_shots := 0
## Seconds since the last shot.
var since_shot := 10.0
var _shot_this_pull := false
var _hud: SarsaparillaCylinderHud
var _bot_tap := false


func trigger(spinning: bool, delta: float) -> bool:
	_hook()
	since_shot += delta
	if not spinning:
		_shot_this_pull = false
		fanning = false
		return true
	if not _shot_this_pull:
		# The pull's first shot, at the tapping pace.
		return since_shot >= TAP_INTERVAL - 0.001
	fanning = fanning or since_shot >= FAN_DELAY
	return fanning


func end_trigger() -> void:
	_shot_this_pull = false
	fanning = false


## The fan widens the cone shot by shot (WeaponController adds this).
func spread_bonus() -> float:
	return minf(FAN_SPREAD_MAX, FAN_SPREAD * pull_shots) if fanning else 0.0


## True when the next shot is the Last Call (one round left in the cylinder).
func is_last_call() -> bool:
	return controller != null and controller.current == data and controller.magazine() == 1


## Every shot: count it, and make the one that empties the cylinder a Last Call.
func shape_hits(hits: Dictionary, from: Vector3, end: Vector3, _power: float) -> void:
	since_shot = 0.0
	pull_shots = pull_shots + 1 if _shot_this_pull else 1
	_shot_this_pull = true
	if controller.magazine() > 0:
		return
	var at := end
	for key in hits:
		var entry: Dictionary = hits[key]
		entry["damage"] = float(entry["damage"]) * LAST_CALL_SCALE
		entry["head_damage"] = float(entry["head_damage"]) * LAST_CALL_SCALE
		entry["push"] = float(entry["push"]) + LAST_CALL_PUSH
		at = entry["point"]
	_pop(hits, from, at)


## The Last Call's soda pop: a fizz trail down the shot, a splash that hits
## every other zombie near where it landed, the bottle-pop sound.
func _pop(hits: Dictionary, from: Vector3, at: Vector3) -> void:
	var level := controller.player.get_parent()
	Fx.beam(level, from, at, FIZZ[1], 0.07)
	var length := from.distance_to(at)
	var puffs := clampi(int(length / 1.5), 2, 8)
	for i in puffs:
		var p := from.lerp(at, (i + 0.5) / puffs)
		WeaponFx.burst(level, p, Vector3.UP, FIZZ, 3, 0.9, 0.55, 0.035, 180.0, Vector3(0, 1.6, 0))
	WeaponFx.burst(level, at, Vector3.UP, FIZZ, 18, 4.2, 0.5, 0.05, 160.0, Vector3(0, -3.0, 0))
	WeaponFx.flash(level, at, FIZZ[2], 0.9)
	WeaponFx.shockwave(level, at, FIZZ[1], POP_RADIUS)
	Sfx.play(LAST_CALL_SOUND, -2.0, randf_range(0.97, 1.03))
	controller.player.add_shake(0.08)
	var view := controller.player.view
	if view:
		view.weapon_event(data, LAST_CALL_EVENT)
	var struck := {}
	for key in hits:
		struck[key] = true
	for node in controller.get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead() or struck.has(z.get_instance_id()):
			continue
		var chest := z.global_position + Vector3.UP * 1.05 * z.data.body_scale
		if chest.distance_to(at) > POP_RADIUS + z.data.capsule_radius * z.data.body_scale:
			continue
		var dir := (chest - at).normalized() if chest.distance_to(at) > 0.05 else Vector3.FORWARD
		controller.strike(data, z, chest, dir, 0.0, POP_DAMAGE / data.damage)


## The Arsenal shows a fanned cylinder: FAN_DELAY then the data rate, the Last
## Call's bonus, and the reload.
func arsenal_dps(_base: float) -> float:
	var cylinder := data.damage * (ROUNDS - 1 + LAST_CALL_SCALE)
	return cylinder / (FAN_DELAY + (ROUNDS - 1) * data.fire_interval + data.reload_time)


func dispose() -> void:
	if is_instance_valid(_hud):
		_hud.get_parent().queue_free()
	_hud = null
	fanning = false


## Adds the cylinder ring to the HUD the first time the weapon is used.
func _hook() -> void:
	if _hud != null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 4
	_hud = SarsaparillaCylinderHud.new()
	_hud.mode = self
	layer.add_child(_hud)
	controller.add_child(layer)


# --- the bot (scripts/dev/dev_driver.gd) ---------------------------------------

## The bot shoots from the hip.
func bot_aim() -> bool:
	return false


## Close zombies: hold the trigger and fan the hammer. Farther: tap (the
## trigger goes up every other frame, so a pull never turns into a fan).
func bot_fire(nearest: float) -> bool:
	if nearest < BOT_FAN_RANGE:
		return true
	_bot_tap = not _bot_tap
	return _bot_tap
