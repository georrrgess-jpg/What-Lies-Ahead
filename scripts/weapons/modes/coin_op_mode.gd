class_name CoinOpMode
extends WeaponMode
## Coin-Op: an arcade token machine pistol that sprays brass tokens full-auto.
##
## Free Play: kills with it bank CREDITs (the three lamps on the cabinet);
## every PAYOUT_EVERY-th kill, and every headshot kill, pays a bonus token
## that puts PAYOUT_ROUNDS rounds straight back in the magazine with a
## ka-ching (or into the reserve while it reloads or is full), so a killing
## streak keeps it firing. The credits survive a weapon switch (kept on the
## controller).
##
## Tilt: hold the trigger past TILT_DELAY and the machine tilts over
## TILT_RAMP: the rate climbs from BASE_INTERVAL to the data rate
## (WeaponData.fire_interval, the fastest it goes) while the cone widens by
## up to TILT_SPREAD degrees, and the red TILT lamp lights. Resting the
## trigger for REST_RESET clears it, so short bursts stay accurate.
##
## Tokens glance off heavies and alphas (HEAVY_SCALE): it picks off the rank
## and file. The cabinet's moving parts are in
## scripts/weapons/views/coin_op_view.gd (reads tilt, credits, since_payout).

## Seconds between tokens before the tilt (12 a second).
const BASE_INTERVAL := 0.08333
const TILT_DELAY := 1.0
const TILT_RAMP := 0.6
const TILT_SPREAD := 1.7
const REST_RESET := 0.22
const PAYOUT_EVERY := 3
const PAYOUT_ROUNDS := 4
const HEAVY_SCALE := 0.7
const PAYOUT_SOUND := &"cop_payout"
const TILT_SOUND := &"cop_tilt"
## Controller metadata that keeps the credits while another weapon is out.
const CREDITS_META := &"coin_op_credits"
## View event the cabinet plays on a payout.
const PAYOUT_EVENT := &"payout"

## 0-1: how far the machine has tilted.
var tilt := 0.0
## Kills banked toward the next bonus token (0 to PAYOUT_EVERY - 1).
var credits := 0
## Seconds since the last bonus token (the lamps flash, the stack pops).
var since_payout := 10.0
var _held := 0.0
var _rest := 10.0
var _since := 10.0
var _listening := false


## The Arsenal shows the untilted rate: the data rate is the tilted peak.
func arsenal_dps(base: float) -> float:
	return base * data.fire_interval / BASE_INTERVAL


func trigger(spinning: bool, delta: float) -> bool:
	_listen()
	since_payout += delta
	_since += delta
	if spinning:
		_rest = 0.0
		_held += delta
	else:
		_rest += delta
		if _rest >= REST_RESET:
			_held = 0.0
	var was := tilt
	tilt = clampf((_held - TILT_DELAY) / TILT_RAMP, 0.0, 1.0)
	if was <= 0.0 and tilt > 0.0:
		Sfx.play(TILT_SOUND, -4.0)
	return _since >= _interval() - 0.001


func end_trigger() -> void:
	_held = 0.0
	tilt = 0.0


## The cone widens as the machine tilts (WeaponController adds this).
func spread_bonus() -> float:
	return TILT_SPREAD * tilt


## Every shot: the next token waits for the (tilted) interval; tokens
## glance off heavies and alphas.
func shape_hits(hits: Dictionary, _from: Vector3, _end: Vector3, _power: float) -> void:
	_since = clampf(_since - _interval(), 0.0, 1.0 / 60.0)
	for key in hits:
		var entry: Dictionary = hits[key]
		var z: Zombie = entry["zombie"]
		if is_instance_valid(z) and (z.data.heavy or z.rank == Zombie.RANK_BOSS):
			entry["damage"] = float(entry["damage"]) * HEAVY_SCALE
			entry["head_damage"] = float(entry["head_damage"]) * HEAVY_SCALE


func dispose() -> void:
	if _listening and Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.disconnect(_on_kill)
	_listening = false


func _interval() -> float:
	return lerpf(BASE_INTERVAL, data.fire_interval, tilt)


func _listen() -> void:
	if _listening:
		return
	_listening = true
	credits = int(controller.get_meta(CREDITS_META, 0))
	Events.enemy_killed.connect(_on_kill)


func _on_kill(enemy: Node, weapon_id: StringName, headshot: bool, _points: int) -> void:
	if weapon_id != data.id or not is_instance_valid(controller):
		return
	credits += 1
	if headshot or credits >= PAYOUT_EVERY:
		credits = 0
		_pay_out(enemy as Node3D, headshot)
	controller.set_meta(CREDITS_META, credits)


## A bonus token: rounds back in the magazine, the ka-ching, the cabinet's
## payout flourish and a FREE PLAY popup over the zombie.
func _pay_out(enemy: Node3D, headshot: bool) -> void:
	for i in PAYOUT_ROUNDS:
		controller.catch_round(data)
	since_payout = 0.0
	Sfx.play(PAYOUT_SOUND, -3.0, randf_range(0.98, 1.03))
	var view := controller.player.view
	if view:
		view.weapon_event(data, PAYOUT_EVENT)
	if is_instance_valid(enemy) and enemy.is_inside_tree():
		CoinOpPopup.spawn(enemy.get_parent(), enemy.global_position + Vector3.UP * 1.2, PAYOUT_ROUNDS, headshot)
