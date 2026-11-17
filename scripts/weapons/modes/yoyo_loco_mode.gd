class_name YoyoLocoMode
extends WeaponMode
## Yo-Yo Loco (yoyo_loco): every shot throws the one yo-yo on its glowing
## string (YoyoLocoShot); the gun cannot throw again until it is home.
##
##   tap       snaps out at the crosshair (up to max_range), hits the first
##             zombie hard (headshots count) and zips back: a fast cycle
##   hold      "Sleeper": keep the trigger held from the throw to the hit and
##             the yo-yo stays on that zombie, spinning against it, grinding
##             it with rising damage until the trigger is let go (string
##             wear: one round per YoyoLocoShot.SLEEP_ROUND_TIME)
##   aimed     "Walk the Dog": thrown down the sights, it drops to the floor
##             and rolls out and back along it, tripping (slowing, light ones
##             stumble) every zombie it passes, for a small hit
##
## The magazine is string wear: a throw's round is spent when the yo-yo comes
## home (so the gun never reloads with the yo-yo still out); an empty string
## re-spools at once. The gun's yo-yo, spool and string glow move in
## scripts/weapons/views/yoyo_loco_view.gd.

## Aim blend at the throw from which it is a Walk the Dog.
const DOG_AIM := 0.5

var shot: YoyoLocoShot
## The trigger has stayed down since the last throw (a Sleeper if it hits).
var _held_since_throw := false


func trigger(spinning: bool, _delta: float) -> bool:
	if not spinning:
		_held_since_throw = false
	return not is_out()


func end_trigger() -> void:
	_held_since_throw = false


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
	var throw_dir := to.normalized() if to.length() > 1.0 else dir
	# The round is spent when the yo-yo comes home (see on_home).
	controller.return_round(data)
	_held_since_throw = true
	var dog := player.ads >= DOG_AIM
	shot = YoyoLocoShot.launch(player.get_parent(), from, throw_dir if not dog else dir, eye, data, controller, self, dog)
	return true


## True while the yo-yo is off the gun.
func is_out() -> bool:
	return is_instance_valid(shot)


## True while the trigger has been held since the throw (the shot asks on a hit).
func holding() -> bool:
	return _held_since_throw


## 0-1 heat of a Sleeper in progress (0 when not sleeping).
func heat() -> float:
	return shot.heat() if is_out() else 0.0


## One round of string wear for the Sleeper. Keeps the throw's own round in
## the magazine: false when the string cannot afford another.
func wear() -> bool:
	if controller.ammo_of(data.id).x <= 1:
		return false
	return controller.spend_rounds(data, 1) == 1


## The yo-yo is back on the gun: its throw's round is spent, and an empty
## string re-spools straight away.
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
		controller.spend_rounds(data, 1)
		shot.queue_free()
	shot = null


## Taps at a target: a hit on the way out, the round trip sets the pace
## (about 8 m out and back), and the magazine's reloads.
func arsenal_dps(_base: float) -> float:
	var cycle := maxf(data.fire_interval, YoyoLocoShot.round_trip(8.0))
	return data.damage * data.magazine_size / (cycle * data.magazine_size + data.reload_time)
