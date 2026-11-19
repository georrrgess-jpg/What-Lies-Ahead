class_name MeleeMode
extends WeaponMode
## The swings of every melee weapon (WeaponData.slot_class "melee"); a melee
## weapon's own mode extends this one and overrides the hooks at the end.
##
## Fire is a light swing: it lasts WeaponData.fire_interval. Aim held winds up
## a heavy swing (full after melee_charge_time; the player moves at
## charge_move_scale meanwhile) and releasing it swings for melee_heavy_time.
## An aim press the weapon cannot answer yet (mid-swing, coming out of a
## sprint) is kept for HEAVY_BUFFER seconds, and holding aim ends a sprint, so
## a heavy asked for always comes out.
##
## A swing lands in a short active window about its contact moment
## (contact_at(): the light's melee_hit_at, the heavy's HEAVY_CONTACT, or what
## the weapon's view reports so the hit matches the animation): every physics
## frame of the window sweeps the cone again, so a zombie that steps in, or that
## the player strafes onto, mid-swing is still struck (each at most once). A
## sweep strikes up to melee_max_targets zombies whose body is within reach
## (max_range from the player's centre to the zombie's surface, plus
## REACH_LEEWAY; the heavy adds HEAVY_REACH, a knife's heavy lunges LUNGE_REACH
## further) and whose body overlaps melee_arc_degrees of the facing, nearest
## first, through WeaponController.melee_hit. The heavy locks on at release to
## the zombie nearest the aim within ASSIST_DEGREES beyond the arc and keeps it
## through the window. Light swings stagger the rank and file out of their
## windup; heavies stagger anything but heavies, alphas and bosses, which take
## melee_heavy_target_scale of the damage. Each swing leaves melee_recovery
## seconds in which the player cannot sprint (no swing-sprint-swing spam). No
## ammo, no reload.
##
## The viewmodel (MeleeView and the weapon's own view on top) follows
## `phase`, `progress()`, `charge`, `swing_index` and `hits`, and reports its
## contact moments in `view_contact`.

enum Phase { IDLE, LIGHT, WINDUP, HEAVY }

## A zombie this heavy (EnemyData.mass) counts as an alpha.
const ALPHA_MASS := 5.0
## A zombie whose back is turned at least this much (cosine) takes a backstab.
const BACKSTAB_COS := -0.3
## A wind-up let go below this share of a full one still swings, at melee_heavy_min_scale.
const HEAVY_MIN_CHARGE := 0.15
## The heavy's contact moment (share of melee_heavy_time) when no view reports one.
const HEAVY_CONTACT := 0.16
## The active window: seconds before and after the contact moment (light, heavy).
const LIGHT_WINDOW := Vector2(0.04, 0.09)
const HEAVY_WINDOW := Vector2(0.05, 0.14)
## Metres of reach beyond max_range: the swing's sweep, the heavy's step in,
## and a knife's heavy lunge (weapons as quick as KNIFE_INTERVAL).
const REACH_LEEWAY := 0.25
const HEAVY_REACH := 0.3
const LUNGE_REACH := 0.55
const KNIFE_INTERVAL := 0.5
## A zombie this close (its surface, metres) is struck whatever the angle short of behind.
const TOUCHING := 0.3
const TOUCHING_DEGREES := 80.0
## Degrees beyond the arc the heavy locks on at release, and keeps its lock.
const ASSIST_DEGREES := 12.0
const ASSIST_KEEP_DEGREES := 25.0
## The vertical band a swing reaches (metres from the player's feet): any part of the body inside it.
const BAND_LOW := -1.2
const BAND_HIGH := 2.0
## Seconds an aim press waits for the weapon to come up (after the swing it fell in).
const HEAVY_BUFFER := 0.35
const SPARKS := [Color(1, 1, 1), Color(1.0, 0.85, 0.4)]

var phase := Phase.IDLE
## Seconds into the current swing (or wind-up).
var elapsed := 0.0
## 0-1 wind-up of the heavy swing (kept through the heavy swing it powers).
var charge := 0.0
## Counts the swings: the first (odd) swings go right to left, even ones left to right.
var swing_index := 0
## Counts the swings that struck something (the view shakes on a change).
var hits := 0
## True when the last swing that connected struck from behind.
var backstabbed := false
## The contact moments (shares of the light swing, the heavy swing) the
## weapon's view reports every frame; negative until it does.
var view_contact := Vector2(-1.0, -1.0)
var _connected := false
var _recover := 0.0
var _queued := false
var _heavy_wait := 0.0
var _aim_down := false
var _struck: Array[Zombie] = []
var _lock: Zombie


## Called by the controller every physics frame while the weapon is held.
## `fire` is a buffered or held fire press, `aim` the aim button held,
## `ready` false while the weapon is being raised or the player sprints or
## mantles. Returns true when a press was used to start a light swing.
func swing_input(fire: bool, aim: bool, ready: bool, delta: float) -> bool:
	_recover = maxf(0.0, _recover - delta)
	if aim and not _aim_down:
		_heavy_wait = HEAVY_BUFFER
	elif phase == Phase.IDLE:
		_heavy_wait = maxf(0.0, _heavy_wait - delta)
	_aim_down = aim
	match phase:
		Phase.IDLE:
			if not ready:
				return false
			if aim or _heavy_wait > 0.0:
				_heavy_wait = 0.0
				# A tapped aim winds up for a frame and swings on the next.
				_begin(Phase.WINDUP)
				Sfx.play(data.melee_heavy_sound, -10.0, 0.8)
				return false
			if fire or _queued:
				_queued = false
				_begin(Phase.LIGHT)
				return true
		Phase.WINDUP:
			elapsed += delta
			charge = minf(1.0, elapsed / maxf(0.05, data.melee_charge_time))
			if not aim:
				_release()
		Phase.LIGHT, Phase.HEAVY:
			elapsed += delta
			_active(phase == Phase.HEAVY)
			if elapsed >= swing_time():
				phase = Phase.IDLE
				charge = 0.0
				_recover = data.melee_recovery
				_lock = null
				_struck.clear()
	return false


## Seconds the swing in progress lasts (light or heavy).
func swing_time() -> float:
	return maxf(0.08, data.melee_heavy_time if phase == Phase.HEAVY else data.fire_interval)


## 0-1 through the swing in progress (0 when idle or winding up).
func progress() -> float:
	if phase != Phase.LIGHT and phase != Phase.HEAVY:
		return 0.0
	return clampf(elapsed / swing_time(), 0.0, 1.0)


## The share of a light (or heavy) swing at which it connects: the view's
## report, else melee_hit_at (or HEAVY_CONTACT).
func contact_at(heavy: bool) -> float:
	var reported := view_contact.y if heavy else view_contact.x
	if reported > 0.0:
		return reported
	return HEAVY_CONTACT if heavy else data.melee_hit_at


## 0-1 back to the next swing: 1 when one can start now, rising through a
## swing and its recovery; 0 while winding up.
func readiness() -> float:
	match phase:
		Phase.LIGHT, Phase.HEAVY:
			return progress() * 0.85
		Phase.WINDUP:
			return 0.0
	return 1.0 - 0.15 * _recover / maxf(0.01, data.melee_recovery) if _recover > 0.0 else 1.0


## A light swing as soon as the weapon is ready (the melee key's quick swing).
func queue_light() -> void:
	_queued = true


## True while a quick swing waits for the weapon to come up.
func has_queued() -> bool:
	return _queued


## True while swinging, winding up, recovering or with a swing queued.
func is_busy() -> bool:
	return phase != Phase.IDLE or _queued or _recover > 0.0


## True while a swing, a wind-up (or aim held for one), a queued swing or a
## recovery keeps the player from sprinting.
func blocks_sprint() -> bool:
	return phase != Phase.IDLE or _recover > 0.0 or _queued or _aim_down or _heavy_wait > 0.0


func move_scale() -> float:
	return data.charge_move_scale if phase == Phase.WINDUP else 1.0


func trigger(_spinning: bool, _delta: float) -> bool:
	return false


func end_trigger() -> void:
	if phase == Phase.WINDUP:
		phase = Phase.IDLE
		charge = 0.0
	_queued = false
	_heavy_wait = 0.0


func melee_reach() -> float:
	return data.max_range


## Metres the swing in progress reaches beyond max_range.
func reach_bonus(heavy: bool) -> float:
	var bonus := REACH_LEEWAY
	if heavy:
		bonus += HEAVY_REACH + (LUNGE_REACH if data.fire_interval <= KNIFE_INTERVAL else 0.0)
	return bonus


func _begin(next: Phase) -> void:
	phase = next
	elapsed = 0.0
	_connected = false
	_struck.clear()
	_lock = null
	if next == Phase.WINDUP:
		charge = 0.0
		return
	swing_index += 1
	if next == Phase.LIGHT:
		charge = 0.0
		Sfx.play(data.melee_swing_sound, -4.0, randf_range(0.92, 1.1))


## The wind-up is let go: the heavy swings, locked on to the zombie nearest the aim.
func _release() -> void:
	_begin(Phase.HEAVY)
	Sfx.play(data.melee_heavy_sound, -2.0, randf_range(0.95, 1.05))
	var best := INF
	for z in _candidates(true, ASSIST_DEGREES):
		var score: float = z[1] + z[2] * 0.02
		if score < best:
			best = score
			_lock = z[0]


## Every physics frame of a swing: sweeps through the active window and
## strikes at the contact moment (_strike, once).
func _active(heavy: bool) -> void:
	var length := swing_time()
	var at := contact_at(heavy) * length
	var window := HEAVY_WINDOW if heavy else LIGHT_WINDOW
	if elapsed < at - window.x or elapsed > at + window.y + 0.001:
		return
	if not _connected and elapsed >= at:
		_connected = true
		_strike(heavy)
	else:
		_sweep(heavy)


## The contact moment of a swing (once per swing; a weapon's own mode adds its slam here).
func _strike(heavy: bool) -> void:
	_sweep(heavy)


## Strikes every zombie in reach not yet struck this swing, nearest first.
func _sweep(heavy: bool) -> void:
	if _struck.size() >= data.melee_max_targets:
		return
	var found := _candidates(heavy, 0.0)
	if heavy and is_instance_valid(_lock) and not _lock.is_dead() and not _struck.has(_lock):
		var kept := _candidates(heavy, ASSIST_KEEP_DEGREES)
		for entry in kept:
			if entry[0] == _lock and not found.any(func(e: Array) -> bool: return e[0] == _lock):
				found.append(entry)
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	var player := controller.player
	var eye := player.aim_transform()
	var first := _struck.is_empty()
	var struck := 0
	if first:
		backstabbed = false
	for entry in found:
		if _struck.size() >= data.melee_max_targets:
			break
		var z: Zombie = entry[0]
		var target := _aim_point(z, eye.origin)
		if target == Vector3.INF:
			continue
		var dir := (target - eye.origin).normalized()
		var flat := Vector3(dir.x, 0.0, dir.z)
		var point := target - (flat.normalized() if flat.length() > 0.01 else Vector3.ZERO) * z.data.capsule_radius * z.data.body_scale
		_struck.append(z)
		_hit(z, point, dir, heavy)
		struck += 1
	if struck > 0 and first:
		hits += 1
		player.add_shake(0.22 if heavy else 0.1)
		player.add_recoil(0.7 if heavy else 0.3, (0.35 if swing_index % 2 == 1 else -0.35) * (0.5 if heavy else 1.0))
		var forward := _flat_forward()
		Sfx.play_at(data.melee_hit_sound, player.global_position + forward, -2.0 if heavy else -4.0, randf_range(0.92, 1.08))


## The player's facing along the ground (the body's, so a look straight down still has one).
func _flat_forward() -> Vector3:
	var player := controller.player
	var f := -player.global_transform.basis.z
	return Vector3(f.x, 0.0, f.z).normalized()


## [zombie, gap (m, surface), degrees off the facing beyond its body's edge] of
## every live zombie the swing reaches, `extra_degrees` wider than the arc.
func _candidates(heavy: bool, extra_degrees: float) -> Array:
	var player := controller.player
	var forward := _flat_forward()
	var reach := data.max_range + reach_bonus(heavy)
	var arc := data.melee_arc_degrees + extra_degrees
	var out := []
	for node in player.get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead() or _struck.has(z):
			continue
		var to := z.global_position - player.global_position
		var bottom := to.y
		var top := to.y + z.data.capsule_height * z.data.body_scale
		if top < BAND_LOW or bottom > BAND_HIGH:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		var dist := flat.length()
		var radius := z.data.capsule_radius * z.data.body_scale
		var gap := dist - radius
		if gap > reach:
			continue
		var off := 0.0
		if dist > 0.05:
			# Degrees from the facing to the near edge of the body.
			off = maxf(0.0, rad_to_deg(forward.angle_to(flat / dist)) - rad_to_deg(asin(minf(1.0, radius / dist))))
		if off > arc and not (gap <= TOUCHING and off <= TOUCHING_DEGREES):
			continue
		out.append([z, gap, off])
	return out


## Where the swing meets `z` seen from `eye`: its chest, or its head or hips
## when scenery hides the chest; INF when scenery hides all three.
func _aim_point(z: Zombie, eye: Vector3) -> Vector3:
	var height := z.data.capsule_height * z.data.body_scale
	for share: float in [0.55, 0.85, 0.3]:
		var p := z.global_position + Vector3.UP * height * share
		if _clear(eye, p):
			return p
	return Vector3.INF


func _hit(z: Zombie, point: Vector3, dir: Vector3, heavy: bool) -> void:
	var tough := z.data.heavy or z.rank == Zombie.RANK_BOSS or z.data.mass >= ALPHA_MASS
	var dmg := data.damage
	var push := data.knockback
	if heavy:
		var k := inverse_lerp(HEAVY_MIN_CHARGE, 1.0, charge)
		dmg = data.melee_heavy_damage * lerpf(data.melee_heavy_min_scale, 1.0, clampf(k, 0.0, 1.0))
		push = data.melee_heavy_knockback
	if tough:
		dmg *= data.melee_heavy_target_scale
	var zombie_forward := Vector3(sin(z.rotation.y), 0.0, cos(z.rotation.y))
	var to_player := controller.player.global_position - z.global_position
	to_player.y = 0.0
	if data.melee_backstab_scale > 1.0 and to_player.length() > 0.05 and zombie_forward.dot(to_player.normalized()) < BACKSTAB_COS:
		dmg *= data.melee_backstab_scale
		backstabbed = true
	dmg *= hit_scale(z, heavy)
	# Light swings knock the rank and file out of a windup; heavies stagger all but the tough.
	if not tough and (heavy or z.is_winding_up()):
		z.interrupt()
	controller.melee_hit(data, z, point, dir, dmg, push)
	WeaponFx.burst(_level(), point, -dir, [data.tracer_color, data.tracer_color.lerp(Color.WHITE, 0.6)] + SPARKS, 9 if heavy else 5, 3.6, 0.32, 0.035, 75.0)
	struck_zombie(z, point, heavy)


func _clear(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, WeaponController.MASK_WORLD)
	return controller.player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _level() -> Node:
	return controller.player.get_parent()


# --- hooks for a melee weapon's own mode ---------------------------------------------

## Extra damage multiplier for a hit on `z` (1 = none).
func hit_scale(_z: Zombie, _heavy: bool) -> float:
	return 1.0


## After a hit on `z` at `point` was dealt (a weapon's own effect: sugar shards, a bell).
func struck_zombie(_z: Zombie, _point: Vector3, _heavy: bool) -> void:
	pass
