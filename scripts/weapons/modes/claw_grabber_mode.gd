class_name ClawGrabberMode
extends WeaponMode
## Claw Grabber (claw_grabber): a prize claw machine in a pistol. Every shot
## fires the claw on its cable (ClawGrabberShot); the gun cannot fire again
## until it is home.
##
##   grab      the first zombie it reaches takes the hit; a light one is
##             grabbed, yanked to the player's feet and dropped there stunned
##             (bowled over, about 1.7 s), and it is Prized: it takes more
##             damage from every hit for a few seconds (ClawPrize)
##   heavies   too big to lift: the claw slips off (they are Prized all the same)
##   grapple   hold the trigger as the claw grips a heavy, a boss, a wall or
##             the floor and it reels the player there: a short dash for
##             mobility, at most ClawGrabberReel.RANGE metres, only to a spot
##             the player could walk to, never through scenery or past the
##             level's edge (ClawGrabberReel). Then it cools down for
##             GRAPPLE_COOLDOWN (the GRAB button on the gun lights up again
##             and chimes when it is ready)
##
## The magazine is credits: a shot's round is spent when the claw comes home
## (so the gun never reloads with the claw out); an empty machine takes a
## token (the reload). The gun's claw, lights and joystick move in
## scripts/weapons/views/claw_grabber_view.gd.

## The Arsenal's tags: how it fires (in place of AUTO / SEMI) and what it adds.
const FIRE_TAG := "CLAW"
const TRAIT := "GRAB & YANK"
## Seconds the grapple needs between reels.
const GRAPPLE_COOLDOWN := 3.5
## Share of the shots that find a zombie (the Arsenal's DPS).
const TAP_HITS := 0.8
## View events.
const GRAB_EVENT := &"grab"
const REEL_EVENT := &"reel"
const READY_SOUND := &"clw_ready"

var shot: ClawGrabberShot
## Seconds since the last grab (the view's lights flash on a grab).
var since_grab := 10.0
var _held_since_shot := false
var _cooldown := 0.0


func trigger(spinning: bool, delta: float) -> bool:
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)
		if _cooldown <= 0.0:
			Sfx.play(READY_SOUND, -8.0)
	since_grab += delta
	if not spinning:
		_held_since_shot = false
	return not is_out()


func end_trigger() -> void:
	_held_since_shot = false


func launch(from: Vector3, dir: Vector3, _scale: float) -> bool:
	if is_out():
		return true
	var player := controller.player
	var eye := player.aim_transform().origin
	var query := PhysicsRayQueryParameters3D.create(eye, eye + dir * data.max_range, WeaponController.MASK_WORLD | WeaponController.MASK_ENEMIES)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var aim_at: Vector3 = hit["position"] if not hit.is_empty() else eye + dir * data.max_range
	var to := aim_at - from
	# The round is spent when the claw comes home (see on_home).
	controller.return_round(data)
	_held_since_shot = true
	shot = ClawGrabberShot.launch(player.get_parent(), from, to.normalized() if to.length() > 1.0 else dir, data, controller, self)
	return true


## True while the claw is off the gun.
func is_out() -> bool:
	return is_instance_valid(shot)


## True while the trigger has been held since the shot (the claw asks when it grips).
func holding() -> bool:
	return _held_since_shot


func grapple_ready() -> bool:
	return _cooldown <= 0.0


## The claw grabbed a zombie (ClawGrabberShot).
func grabbed(_z: Zombie) -> void:
	since_grab = 0.0
	if controller.current == data:
		controller.player.view.weapon_event(data, GRAB_EVENT)


## The claw is reeling the player in (ClawGrabberShot): the grapple cools down.
func grappled() -> void:
	_cooldown = GRAPPLE_COOLDOWN
	if controller.current == data:
		controller.player.view.weapon_event(data, REEL_EVENT)


## The grapple's readiness, 0-1 (1 = ready): the GRAB button on the gun lights by it.
func grapple_charge() -> float:
	return 1.0 - _cooldown / GRAPPLE_COOLDOWN


## The claw is back on the gun: its shot's round is spent, and an empty
## machine takes a token straight away.
func on_home(event_name: StringName) -> void:
	shot = null
	if controller.current != data:
		return
	controller.player.view.weapon_event(data, event_name)
	if controller.is_reloading():
		return
	controller.spend_rounds(data, 1)
	if controller.magazine() <= 0 and controller.reserve() > 0:
		controller.start_reload()


func dispose() -> void:
	if is_out():
		shot.release()
		controller.spend_rounds(data, 1)
		shot.queue_free()
	shot = null


## Shots at a target: one hit a shot, paced by the claw's round trip (about
## 8 m out and home) and the magazine's reloads; TAP_HITS of them find a
## zombie; every grabbed zombie is Prized for the next hit.
func arsenal_dps(_base: float) -> float:
	var cycle := maxf(data.fire_interval, ClawGrabberShot.round_trip(8.0))
	return TAP_HITS * data.damage * data.magazine_size / (cycle * data.magazine_size + data.reload_time)


# --- the bot (scripts/dev/dev_driver.gd) ---------------------------------------

## The bot fires from the hip.
func bot_aim() -> bool:
	return false


## The bot fires whenever the claw is home.
func bot_fire(_nearest: float) -> bool:
	return not is_out()


## The bot never holds the trigger for a grapple.
func bot_hold(_target: Zombie) -> bool:
	return false
