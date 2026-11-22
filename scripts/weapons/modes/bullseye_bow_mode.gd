class_name BullseyeBowMode
extends WeaponMode
## Bullseye Longbow (bullseye_bow): a recurve that looses real arrows.
##
##   draw      hold fire to draw (WeaponData.charge_*: a part-drawn arrow
##             flies slower and hits softer; under charge_min_fraction the
##             string is let down and the arrow kept)
##   Bullseye  the moment the bow reaches full draw a short window opens
##             (BULLSEYE_WINDOW, longer aimed): a ring tightens round the
##             crosshair (BullseyeRingHud) and the arrowhead glints. Loosed
##             inside it the arrow is a Bullseye: BULLSEYE_SCALE damage,
##             faster, and it passes through BULLSEYE_PIERCE zombies before
##             it pins the next one (a short stagger)
##   fatigue   held past the window the bow arm tires: the aim trembles and
##             the spread grows (spread_bonus, up to TREMBLE_MAX degrees;
##             half that aimed), and after HOLD_MAX seconds at full draw the
##             string is let down (the arrow stays nocked)
##
## Every arrow is a BowArrow: it flies on a slight arc, sticks in what it hits
## and, stuck in scenery or dropped by a zombie that dies, can be picked up
## again by walking over it (an arrow back in the quiver). The bow's limbs,
## string, arrow and hands move in scripts/weapons/views/bullseye_bow_view.gd
## (reads draw_state()), the nock reload is scripts/weapons/reloads/bullseye_bow_reload.gd.

## The Arsenal's tags: how it fires (in place of AUTO / SEMI) and what it adds.
const FIRE_TAG := "DRAW"
const TRAIT := "BULLSEYE"
## Seconds the Bullseye window stays open at full draw, from the hip and aimed.
const BULLSEYE_WINDOW := 0.26
const BULLSEYE_WINDOW_AIMED := 0.36
const BULLSEYE_SCALE := 1.4
const BULLSEYE_PIERCE := 2
## Extra flight speed of a Bullseye, and of a part drawn arrow at the least
## draw (shares of WeaponData.projectile_speed).
const BULLSEYE_SPEED := 1.15
const WEAK_SPEED := 0.55
## Fatigue: spread (degrees a second past the window, and its cap) and the
## longest hold at full draw (seconds) before the string is let down.
const TREMBLE_RATE := 2.6
const TREMBLE_MAX := 4.5
const HOLD_MAX := 4.5
const LET_DOWN_STALL := 0.45
const BULLSEYE_SOUND := &"bb_bullseye"
const LET_DOWN_SOUND := &"bb_letdown"
## View events: a Bullseye or a plain arrow left the string.
const LOOSE_EVENT := &"loose"
const BULLSEYE_EVENT := &"bullseye_loose"

## Seconds the bow has been at full draw (-1 while not fully drawn).
var full_time := -1.0
## True when the last arrow loosed was a Bullseye; how many have been loosed.
var last_bullseye := false
var bullseyes := 0
var _hud: BullseyeRingHud


func arsenal_dps(base: float) -> float:
	# A good archer looses most arrows inside the window.
	return base * lerpf(1.0, BULLSEYE_SCALE, 0.5)


func trigger(_spinning: bool, _delta: float) -> bool:
	_hook()
	return true


func charging(charge: float, delta: float) -> float:
	_hook()
	if charge < 1.0:
		full_time = -1.0
		return 0.0
	full_time = maxf(0.0, full_time) + delta
	if full_time >= HOLD_MAX:
		full_time = -1.0
		Sfx.play(LET_DOWN_SOUND, -4.0)
		return LET_DOWN_STALL
	return 0.0


func end_trigger() -> void:
	full_time = -1.0


func spread_bonus() -> float:
	var over := fatigue()
	if over <= 0.0:
		return 0.0
	var aim := controller.player.aim_blend if controller and controller.player else 0.0
	return minf(TREMBLE_MAX, over * TREMBLE_RATE) * lerpf(1.0, 0.5, aim)


func launch(from: Vector3, dir: Vector3, scale: float) -> bool:
	var bullseye := in_window()
	last_bullseye = bullseye
	full_time = -1.0
	var power := inverse_lerp(data.charge_min_damage_scale, 1.0, scale) if data.charge_min_damage_scale < 1.0 else 1.0
	var speed := data.projectile_speed * lerpf(WEAK_SPEED, 1.0, clampf(power, 0.0, 1.0))
	if bullseye:
		speed *= BULLSEYE_SPEED
		scale *= BULLSEYE_SCALE
		bullseyes += 1
		Sfx.play(BULLSEYE_SOUND, -3.0)
	BowArrow.launch(controller, data, from, dir * speed, scale, BULLSEYE_PIERCE if bullseye else 0, bullseye)
	var view := controller.player.view
	if view:
		view.weapon_event(data, BULLSEYE_EVENT if bullseye else LOOSE_EVENT)
	return true


## Seconds the Bullseye window lasts right now (longer with the sights up).
func window() -> float:
	var aim := controller.player.aim_blend if controller and controller.player else 0.0
	return lerpf(BULLSEYE_WINDOW, BULLSEYE_WINDOW_AIMED, aim)


## True while a release would be a Bullseye.
func in_window() -> bool:
	return full_time >= 0.0 and full_time <= window()


## Seconds held past the Bullseye window (0 inside it or before full draw).
func fatigue() -> float:
	return maxf(0.0, full_time - window()) if full_time >= 0.0 else 0.0


func dispose() -> void:
	if is_instance_valid(_hud):
		_hud.get_parent().queue_free()
	_hud = null
	full_time = -1.0


## Adds the Bullseye ring to the HUD the first time the bow is used.
func _hook() -> void:
	if _hud != null or controller == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 4
	_hud = BullseyeRingHud.new()
	_hud.mode = self
	layer.add_child(_hud)
	controller.add_child(layer)
