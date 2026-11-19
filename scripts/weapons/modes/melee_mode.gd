class_name MeleeMode
extends WeaponMode
## The swings of every melee weapon (WeaponData.slot_class "melee"); a melee
## weapon's own mode extends this one and overrides the hooks at the end.
##
## Fire is a light swing: it lasts WeaponData.fire_interval and connects at
## melee_hit_at of the way through. Aim held winds up a heavy swing (full
## after melee_charge_time; the player moves at charge_move_scale meanwhile)
## and releasing it swings for melee_heavy_time. A swing strikes up to
## melee_max_targets zombies within max_range (from the player's centre to
## the zombie's surface) and melee_arc_degrees of the aim, nearest first,
## through WeaponController.melee_hit. Light swings stagger the rank and file
## out of their windup; heavies stagger anything but heavies, alphas and
## bosses, which take melee_heavy_target_scale of the damage. Each swing
## leaves melee_recovery seconds in which the player cannot sprint (no
## swing-sprint-swing spam). No ammo, no reload.
##
## The viewmodel (MeleeView and the weapon's own view on top) follows
## `phase`, `progress()`, `charge`, `swing_index` and `hits`.

enum Phase { IDLE, LIGHT, WINDUP, HEAVY }

## A zombie this heavy (EnemyData.mass) counts as an alpha.
const ALPHA_MASS := 5.0
## A zombie whose back is turned at least this much (cosine) takes a backstab.
const BACKSTAB_COS := -0.3
## A wind-up let go below this share of a full one still swings, at melee_heavy_min_scale.
const HEAVY_MIN_CHARGE := 0.15
const SPARKS := [Color(1, 1, 1), Color(1.0, 0.85, 0.4)]

var phase := Phase.IDLE
## Seconds into the current swing (or wind-up).
var elapsed := 0.0
## 0-1 wind-up of the heavy swing (kept through the heavy swing it powers).
var charge := 0.0
## Counts the swings: even swings go right to left, odd ones left to right.
var swing_index := 0
## Counts the swings that struck something (the view shakes on a change).
var hits := 0
## True when the last swing that connected struck from behind.
var backstabbed := false
var _connected := false
var _recover := 0.0
var _queued := false


## Called by the controller every physics frame while the weapon is held.
## `fire` is a buffered or held fire press, `aim` the aim button held,
## `ready` false while the weapon is being raised or the player sprints or
## mantles. Returns true when a press was used to start a light swing.
func swing_input(fire: bool, aim: bool, ready: bool, delta: float) -> bool:
	_recover = maxf(0.0, _recover - delta)
	match phase:
		Phase.IDLE:
			if not ready:
				return false
			if aim:
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
				_begin(Phase.HEAVY)
				Sfx.play(data.melee_heavy_sound, -2.0, randf_range(0.95, 1.05))
		Phase.LIGHT, Phase.HEAVY:
			elapsed += delta
			var length := swing_time()
			if not _connected and elapsed >= length * data.melee_hit_at:
				_connected = true
				_strike(phase == Phase.HEAVY)
			if elapsed >= length:
				phase = Phase.IDLE
				charge = 0.0
				_recover = data.melee_recovery
	return false


## Seconds the swing in progress lasts (light or heavy).
func swing_time() -> float:
	return maxf(0.08, data.melee_heavy_time if phase == Phase.HEAVY else data.fire_interval)


## 0-1 through the swing in progress (0 when idle or winding up).
func progress() -> float:
	if phase != Phase.LIGHT and phase != Phase.HEAVY:
		return 0.0
	return clampf(elapsed / swing_time(), 0.0, 1.0)


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


## True while a swing, a queued quick swing or a recovery keeps the player from sprinting.
func blocks_sprint() -> bool:
	return phase == Phase.LIGHT or phase == Phase.HEAVY or _recover > 0.0 or _queued


func move_scale() -> float:
	return data.charge_move_scale if phase == Phase.WINDUP else 1.0


func trigger(_spinning: bool, _delta: float) -> bool:
	return false


func end_trigger() -> void:
	if phase == Phase.WINDUP:
		phase = Phase.IDLE
		charge = 0.0
	_queued = false


func melee_reach() -> float:
	return data.max_range


func _begin(next: Phase) -> void:
	phase = next
	elapsed = 0.0
	_connected = false
	if next == Phase.WINDUP:
		charge = 0.0
		return
	swing_index += 1
	if next == Phase.LIGHT:
		charge = 0.0
		Sfx.play(data.melee_swing_sound, -4.0, randf_range(0.92, 1.1))


## The swing connects: every zombie in the cone, nearest first.
func _strike(heavy: bool) -> void:
	var player := controller.player
	var eye := player.aim_transform()
	var forward := -eye.basis.z
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	var cone_cos := cos(deg_to_rad(data.melee_arc_degrees))
	var found: Array[Zombie] = []
	var gaps: Array[float] = []
	for node in player.get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var to := z.global_position - player.global_position
		var flat := Vector3(to.x, 0.0, to.z)
		var gap := flat.length() - z.data.capsule_radius * z.data.body_scale
		if gap > data.max_range or to.y > 1.6 or to.y < -2.2 * z.data.body_scale:
			continue
		if flat.length() > 0.35 and flat.normalized().dot(flat_forward) < cone_cos:
			continue
		var at := 0
		while at < gaps.size() and gaps[at] < gap:
			at += 1
		found.insert(at, z)
		gaps.insert(at, gap)
	var struck := 0
	backstabbed = false
	for z in found:
		if struck >= data.melee_max_targets:
			break
		var chest := z.global_position + Vector3.UP * 1.0 * z.data.body_scale
		if not _clear(eye.origin, chest):
			continue
		var dir := (chest - eye.origin).normalized()
		var point := chest - Vector3(dir.x, 0.0, dir.z).normalized() * z.data.capsule_radius * z.data.body_scale
		_hit(z, point, dir, heavy)
		struck += 1
	if struck > 0:
		hits += 1
		player.add_shake(0.22 if heavy else 0.1)
		Sfx.play_at(data.melee_hit_sound, player.global_position + flat_forward, -2.0 if heavy else -4.0, randf_range(0.92, 1.08))


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
