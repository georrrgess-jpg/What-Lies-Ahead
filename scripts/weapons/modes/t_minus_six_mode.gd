class_name TMinusSixMode
extends WeaponMode
## T-Minus Six: a pocket launchpad with six gyrojet mini-rockets in its pod.
##
##   paint   hold aim: the radar sweeps and paints the zombie nearest the
##           crosshair (inside LOCK_CONE, within LOCK_RANGE, in sight) once
##           every LOCK_TIME, up to one lock per rocket in the pod
##           (MAX_LOCKS). The sweep prefers zombies with fewer locks, so a
##           slow pan across a lane spreads the paint; holding on a lone
##           zombie stacks every lock on it.
##   swarm   the trigger with locks launches one rocket per lock in a quick
##           ripple (RIPPLE apart); they corkscrew out and home in on the
##           painted heads (TMinusRocket).
##   dumb    the trigger with no locks (hip or aimed) fires one straight,
##           unguided rocket at the crosshair.
##
## Locks drop LOCK_KEEP seconds after the sights come down, and with the
## zombie (dead, gone or out of LOCK_RANGE). Reloading with rockets still in
## the pod is quicker (PARTIAL_RELOAD_CUT). The pod, dish, lock screen and
## countdown strip move in scripts/weapons/views/t_minus_six_view.gd; the lock
## brackets are drawn by TMinusLockHud.

const LOCK_TIME := 0.33
const MAX_LOCKS := 6
## Degrees off the crosshair a zombie can be painted at.
const LOCK_CONE := 6.0
const LOCK_RANGE := 42.0
## Aim blend (Player.ads) from which the radar paints.
const AIM_IN := 0.8
const LOCK_KEEP := 0.6
## Seconds between the rockets of one swarm.
const RIPPLE := 0.06
## Seconds a reload saves when rockets are still in the pod.
const PARTIAL_RELOAD_CUT := 0.6
## Radians of aim angle one lock already on a zombie is worth: the sweep
## moves on to an unpainted zombie this much further off the crosshair.
const SPREAD_BIAS := 0.035
const LOCK_SOUND := &"tm6_lock"
const FULL_SOUND := &"tm6_lock_full"

## Painted zombies in lock order (a zombie with stacked locks repeats).
var locks: Array[Zombie] = []
## 0-1 progress of the lock being painted now, and on whom.
var paint := 0.0
var painting: Zombie
## Seconds since the last lock landed (the view and HUD flash on it).
var since_lock := 10.0
## Seconds since the last swarm left (the countdown strip blinks 3-2-1).
var since_swarm := 10.0
var _keep := 0.0
var _ripple: Array[float] = []
var _hud: TMinusLockHud
var _hooked := false


func trigger(_spinning: bool, delta: float) -> bool:
	_hook()
	since_lock += delta
	since_swarm += delta
	_tick_ripple(delta)
	_prune()
	var p := controller.player
	var aimed := p.ads >= AIM_IN and not controller.is_reloading() and not controller.is_switching() and p.weapon_ready()
	if aimed:
		_keep = LOCK_KEEP
		_paint(delta)
	else:
		paint = 0.0
		painting = null
		_keep -= delta
		if _keep <= 0.0 and not locks.is_empty():
			locks.clear()
	return true


func end_trigger() -> void:
	paint = 0.0
	painting = null


## With locks: the whole swarm (this pull's round and one more per extra
## lock). Without: one dumb rocket at the crosshair.
func launch(from: Vector3, dir: Vector3, _scale: float) -> bool:
	var level := controller.player.get_parent()
	if locks.is_empty():
		TMinusRocket.launch(level, from, _aim_dir(from, dir), data, controller, null, 0, 0.0)
		return true
	var count := 1 + controller.spend_rounds(data, locks.size() - 1)
	for i in count:
		TMinusRocket.launch(level, from, dir, data, controller, locks[i], i, i * RIPPLE)
		if i > 0:
			_ripple.append(i * RIPPLE)
	locks.clear()
	paint = 0.0
	since_swarm = 0.0
	controller.player.view.weapon_event(data, &"swarm")
	return true


## Rockets of the last swarm still waiting in the pod for their turn.
func queued() -> int:
	return _ripple.size()


func lock_count() -> int:
	return locks.size()


## Locks on `z` (how many rockets it will take).
func locks_on(z: Zombie) -> int:
	return locks.count(z)


## The most locks the pod can hold right now.
func lock_cap() -> int:
	return mini(MAX_LOCKS, controller.magazine())


func reloaded() -> void:
	locks.clear()


func dispose() -> void:
	if _hud and is_instance_valid(_hud):
		_hud.get_parent().queue_free()
	if _hooked and controller.reload_started.is_connected(_on_reload_started):
		controller.reload_started.disconnect(_on_reload_started)


## Each swarm rocket hits for full damage (seeking heads), and a swarm
## spreads one lock a LOCK_TIME: on one target the paint, the ripple and
## the reload set the pace.
func arsenal_dps(_base: float) -> float:
	var rocket := data.damage * lerpf(1.0, data.headshot_multiplier, 0.7)
	var cycle := data.magazine_size * LOCK_TIME + data.magazine_size * RIPPLE + 0.35 + data.reload_time
	return rocket * data.magazine_size / cycle


# --- the bot (scripts/dev/dev_driver.gd) ---------------------------------------

## The playtest bot raises the sights to paint.
func bot_aim() -> bool:
	return controller.magazine() > 0


## The bot fires a full paint, or what it has when a zombie closes in, or
## from the hip (not while the sights are still coming up).
func bot_fire(nearest: float) -> bool:
	if controller.player.ads < AIM_IN:
		return not Input.is_action_pressed("aim")
	return lock_count() >= lock_cap() or (lock_count() > 0 and nearest < 7.0)


# --- painting -----------------------------------------------------------------

func _paint(delta: float) -> void:
	var target := _candidate()
	if target != painting:
		painting = target
		paint = 0.0
	if target == null or locks.size() >= lock_cap():
		paint = 0.0
		return
	paint += delta / LOCK_TIME
	if paint < 1.0:
		return
	paint = 0.0
	locks.append(target)
	since_lock = 0.0
	var full := locks.size() >= lock_cap()
	Sfx.play(FULL_SOUND if full else LOCK_SOUND, -4.0, 1.0 + 0.07 * (locks.size() - 1))
	controller.player.view.weapon_event(data, &"lock")


## The zombie the radar paints next: nearest the crosshair inside the cone,
## zombies already painted counting as SPREAD_BIAS further off per lock.
## One with locks enough to drop it is painted again only when no other
## zombie is in the cone, and takes one spare lock at most (a lone heavy
## still takes every lock).
func _candidate() -> Zombie:
	var eye := controller.player.aim_transform()
	var aim := -eye.basis.z
	var best: Zombie = null
	var best_score := INF
	var cone := deg_to_rad(LOCK_CONE)
	for node in controller.get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var at := TMinusRocket.seek_point(z)
		var to := at - eye.origin
		var dist := to.length()
		if dist > LOCK_RANGE or dist < 0.5:
			continue
		var angle := aim.angle_to(to)
		if angle > cone:
			continue
		var on := locks.count(z)
		# Painted enough to drop it (and one spare): it takes no more.
		if on > ceili(z.health / _rocket_damage()):
			continue
		var score := angle + SPREAD_BIAS * on
		# Painted enough to drop it: paint the next one first.
		if on * _rocket_damage() >= z.health:
			score += cone + SPREAD_BIAS * MAX_LOCKS
		if score < best_score and _in_sight(eye.origin, at):
			best = z
			best_score = score
	return best


## Drops locks on zombies that died, escaped or left the radar's range.
func _prune() -> void:
	if locks.is_empty():
		return
	var origin := controller.player.global_position
	for i in range(locks.size() - 1, -1, -1):
		var z := locks[i]
		if not is_instance_valid(z) or z.is_dead() or z.global_position.distance_to(origin) > LOCK_RANGE * 1.2:
			locks.remove_at(i)


## A seeking rocket's hit on a head.
func _rocket_damage() -> float:
	return data.damage * data.headshot_multiplier


func _in_sight(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, WeaponController.MASK_WORLD)
	return controller.player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## A dumb rocket flies from the muzzle to the point under the crosshair.
func _aim_dir(from: Vector3, dir: Vector3) -> Vector3:
	var eye := controller.player.aim_transform().origin
	var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * data.max_range, WeaponController.MASK_WORLD | WeaponController.MASK_ENEMIES)
	q.exclude = [controller.player.get_rid()]
	var hit := controller.player.get_world_3d().direct_space_state.intersect_ray(q)
	var at: Vector3 = hit["position"] if not hit.is_empty() else eye + dir * data.max_range
	var to := at - from
	return to.normalized() if to.length() > 1.0 else dir


func _tick_ripple(delta: float) -> void:
	for i in range(_ripple.size() - 1, -1, -1):
		_ripple[i] -= delta
		if _ripple[i] <= 0.0:
			_ripple.remove_at(i)


## Connects the reload and the lock HUD the first time the weapon is used.
func _hook() -> void:
	if _hooked:
		return
	_hooked = true
	controller.reload_started.connect(_on_reload_started)
	var layer := CanvasLayer.new()
	layer.layer = 4
	_hud = TMinusLockHud.new()
	_hud.mode = self
	layer.add_child(_hud)
	controller.add_child(layer)


func _on_reload_started(weapon: WeaponData, _duration: float) -> void:
	locks.clear()
	if weapon == data and controller.magazine() > 0:
		controller.hurry_reload(data, PARTIAL_RELOAD_CUT)

