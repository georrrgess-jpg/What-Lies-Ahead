class_name WeaponController
extends Node
## Shared combat code for every weapon: the two carried slots and switching,
## ammo, fire timing, reloads, and every fire mode. All tuning comes from
## WeaponData resources (data/weapons/*.tres); the effects, projectiles and
## status effects live in scripts/weapons/.
##
## Fire modes, picked by the data:
##   semi / automatic   one shot per click / while held
##   burst              burst_count shots per click
##   charge             hold to charge, release to fire (damage scales; only a
##                      full charge pierces)
##   beam               continuous damage ticks while held, drawn as a beam
##   projectile         launches WeaponProjectile (gravity, bounces, splash)
## and on top of any of them: pierce, chain lightning, seeking, status
## effects (chill/freeze, shock) and heat (a magazine that cools on its own).
##
## Ammo is tracked per weapon for the whole run, so switching slots or
## swapping at the loadout station and back returns exactly the ammo that
## weapon had. Switching cancels a reload.

signal weapon_changed(data: WeaponData)
signal ammo_changed(magazine: int, reserve: int)
signal fired(data: WeaponData)
signal reload_started(data: WeaponData, duration: float)
signal reload_finished(data: WeaponData)
signal hit_confirmed(killed: bool, headshot: bool)
## The carried weapons or the active slot changed.
signal slots_changed(slots: Array, active: int)

const MASK_WORLD := 1
const MASK_ENEMIES := 4
const FIRE_BUFFER := 0.14
## Seconds after a shot before bloom starts to recover, so sustained fire
## builds spread and short bursts (or aiming down sights) keep it tight.
const BLOOM_RECOVER_DELAY := 0.12
## Seconds the old weapon takes to drop out of view when switching.
const LOWER_TIME := 0.12
const SWITCH_SOUND := &"weap_switch"

var current: WeaponData
## Weapon ids of the primary and secondary slot.
var slots: Array[StringName] = [&"", &""]
var active_slot := 0
## False between runs or while the results screen is up.
var enabled := true
## Zombie a seeking weapon would hit right now (for the HUD lock marker).
var lock_target: Zombie

var _ammo := {}            # weapon id -> { "mag": int, "reserve": int }
## Seconds until the next shot. Runs below zero by up to one frame so the
## time a frame overshoots is carried into the next shot (exact fire rates).
var _cooldown := 0.0
var _tick := 1.0 / 60.0    # length of the last physics frame
var _reload_left := 0.0
var _reloading := false
var _bloom := 0.0
var _fire_buffer := 0.0
var _dry_cooldown := 0.0
var _trickle := 0.0
var _since_shot := 10.0
var _recoil_side := 1.0
var _burst_count := 0      # shots in the current string (recoil pattern)
var _switch_left := 0.0
var _charging := false
var _charge := 0.0
var _charge_ready := false
var _burst_left := 0
var _burst_timer := 0.0
var _regen := 0.0
var _beam_on := false
var _beam_linger := 0.0      # keeps the beam drawn briefly after a tick
var _beam_end := Vector3.ZERO
var _confirm_cool := 0.0
var _beam: BeamVisual
var _arc: ArcPreview
var _loop_player: AudioStreamPlayer
var _charge_player: AudioStreamPlayer

@onready var player: Player = get_parent()


func _ready() -> void:
	_loop_player = AudioStreamPlayer.new()
	_loop_player.bus = &"SFX"
	add_child(_loop_player)
	_charge_player = AudioStreamPlayer.new()
	_charge_player.bus = &"SFX"
	add_child(_charge_player)


## Gives every weapon its starting ammo. Call once per run.
func begin_run() -> void:
	_ammo.clear()
	for w in GameData.weapons():
		_ammo[w.id] = {"mag": w.magazine_size, "reserve": w.reserve_start}
	_warm_up.call_deferred()


## Carries `primary` and `secondary` and holds the primary (no switch animation).
func set_loadout(primary: StringName, secondary: StringName) -> void:
	slots = [primary, secondary] as Array[StringName]
	active_slot = 0
	current = null
	var data := GameData.weapon(primary)
	if data:
		_take(data, false)
	slots_changed.emit(slots, active_slot)


## Puts `weapon_id` in the active slot (loadout station swaps). If the other
## slot already holds it, switches to that slot instead.
func equip(weapon_id: StringName) -> bool:
	var data := GameData.weapon(weapon_id)
	if data == null or data == current:
		return false
	if slots[1 - active_slot] == weapon_id:
		return switch_to_slot(1 - active_slot)
	slots[active_slot] = weapon_id
	_take(data, current != null)
	slots_changed.emit(slots, active_slot)
	return true


## Switches to slot 0 (primary) or 1 (secondary). Cancels any reload.
func switch_to_slot(index: int) -> bool:
	if index == active_slot or index < 0 or index > 1 or not player.alive:
		return false
	var data := GameData.weapon(slots[index])
	if data == null:
		return false
	active_slot = index
	_take(data, true)
	slots_changed.emit(slots, active_slot)
	return true


func switch_next() -> bool:
	return switch_to_slot(1 - active_slot)


func slot_weapon(index: int) -> WeaponData:
	return GameData.weapon(slots[index]) if index >= 0 and index < slots.size() else null


func _take(data: WeaponData, animate: bool) -> void:
	_end_trigger()
	current = data
	if not _ammo.has(data.id):
		_ammo[data.id] = {"mag": data.magazine_size, "reserve": data.reserve_start}
	_reloading = false
	_reload_left = 0.0
	_switch_left = LOWER_TIME + data.equip_time if animate else 0.0
	_cooldown = 0.0
	_bloom = 0.0
	_regen = 0.0
	if animate:
		Sfx.play(data.equip_sound if data.equip_sound != &"" else SWITCH_SOUND, -5.0, randf_range(0.96, 1.04))
	weapon_changed.emit(data)
	_emit_ammo()


# --- queries ---------------------------------------------------------------------

func magazine() -> int:
	return int(_ammo[current.id]["mag"]) if current else 0


func reserve() -> int:
	return int(_ammo[current.id]["reserve"]) if current else 0


## Magazine and reserve of any weapon (for the HUD's slot cards).
func ammo_of(weapon_id: StringName) -> Vector2i:
	if not _ammo.has(weapon_id):
		return Vector2i.ZERO
	return Vector2i(int(_ammo[weapon_id]["mag"]), int(_ammo[weapon_id]["reserve"]))


func is_reloading() -> bool:
	return _reloading


## True while the weapon is being raised after a switch (it cannot fire yet).
func is_switching() -> bool:
	return _switch_left > 0.0


## 0-1 through the current reload.
func reload_progress() -> float:
	if not _reloading or current == null:
		return 0.0
	return 1.0 - clampf(_reload_left / maxf(0.01, current.reload_time), 0.0, 1.0)


## 0-1 charge of a charge weapon (0 when not charging).
func charge_progress() -> float:
	if not _charging or current == null or current.charge_time <= 0.0:
		return 0.0
	return clampf(_charge / current.charge_time, 0.0, 1.0)


func is_charging() -> bool:
	return _charging


## 0-1 heat of a heat weapon (1 = overheated).
func heat() -> float:
	if current == null or not current.uses_heat():
		return 0.0
	return 1.0 - float(magazine()) / maxf(1.0, current.magazine_size)


## True while the beam of a beam weapon is on.
func is_beaming() -> bool:
	return _beam_on


## Player move speed multiplier for the held weapon (and charging).
func move_scale() -> float:
	if current == null:
		return 1.0
	return current.move_speed_scale * (current.charge_move_scale if _charging else 1.0)


## Spread cone half-angle (degrees) the next shot will use, including bloom
## and aiming. Precision weapons put a rested first shot dead centre.
func current_spread() -> float:
	if current == null:
		return 0.0
	var spread := current.spread_degrees + _bloom
	if current.first_shot_accurate and _since_shot > 0.32 and current.pellets == 1:
		spread = 0.0
	# Moving fast or in the air costs accuracy (shown live on the reticle).
	if player.sprinting:
		spread += 0.8
	if not player.is_on_floor():
		spread += 1.5
	return spread * lerpf(1.0, current.ads_spread_scale, player.ads)


## True while the weapon is out of reserve energy and slowly refilling itself.
func is_emergency_recharging() -> bool:
	return current != null and reserve() <= 0 and magazine() < int(ceil(current.magazine_size * 0.5))


## True when both carried weapons are full.
func is_ammo_full() -> bool:
	for w in _carried():
		var a := ammo_of(w.id)
		if a.x < w.magazine_size or a.y < w.reserve_max:
			return false
	return true


## Free break refill: adds a fraction of reserve_max to both carried weapons.
## Returns the energy added to the held one.
func refill_fraction(fraction: float) -> int:
	var gained := 0
	for w in _carried():
		var state: Dictionary = _ammo[w.id]
		var before := int(state["reserve"])
		state["reserve"] = mini(w.reserve_max, before + int(ceil(w.reserve_max * fraction)))
		if w == current:
			gained = int(state["reserve"]) - before
	_emit_ammo()
	return gained


## Loadout station purchase: full magazine and reserve for both carried weapons.
func top_up() -> void:
	for w in _carried():
		_ammo[w.id]["mag"] = w.magazine_size
		_ammo[w.id]["reserve"] = w.reserve_max
	_reloading = false
	_emit_ammo()


func _carried() -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for id in slots:
		var w := GameData.weapon(id)
		if w and _ammo.has(w.id) and not out.has(w):
			out.append(w)
	if out.is_empty() and current:
		out.append(current)
	return out


func start_reload() -> bool:
	if current == null or _reloading or is_switching() or magazine() >= current.magazine_size or reserve() <= 0:
		return false
	_end_trigger()
	_reloading = true
	_reload_left = current.reload_time
	Sfx.play(current.reload_sound, -2.0)
	reload_started.emit(current, current.reload_time)
	return true


# --- per frame --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_since_shot += delta
	if _since_shot > 0.35:
		_burst_count = 0
	_tick = delta
	_cooldown = maxf(-delta, _cooldown - delta)
	_fire_buffer = maxf(0.0, _fire_buffer - delta)
	_dry_cooldown = maxf(0.0, _dry_cooldown - delta)
	_switch_left = maxf(0.0, _switch_left - delta)
	_confirm_cool = maxf(0.0, _confirm_cool - delta)
	_beam_linger = maxf(0.0, _beam_linger - delta)
	if current == null:
		return
	if _since_shot >= BLOOM_RECOVER_DELAY:
		_bloom = maxf(0.0, _bloom - current.spread_recovery * delta)

	if _reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
	_cool_down(delta)
	_emergency_recharge(delta)

	var can_fire := enabled and player.alive and player.controls_enabled
	if not can_fire:
		_end_trigger()
	else:
		if Input.is_action_just_pressed("reload"):
			start_reload()
		_handle_trigger(delta)
	_update_aim_visuals()


## Heat weapons: the magazine refills from reserve once the trigger rests.
func _cool_down(delta: float) -> void:
	if not current.uses_heat() or _reloading or _since_shot < current.regen_delay:
		_regen = 0.0
		return
	var state: Dictionary = _ammo[current.id]
	if int(state["mag"]) >= current.magazine_size or int(state["reserve"]) <= 0:
		return
	_regen += current.regen_rate * delta
	var moved := mini(mini(int(_regen), current.magazine_size - int(state["mag"])), int(state["reserve"]))
	if moved > 0:
		_regen -= moved
		state["mag"] = int(state["mag"]) + moved
		state["reserve"] = int(state["reserve"]) - moved
		_emit_ammo()


## With no energy left at all, the cell trickles back so the player is never helpless.
func _emergency_recharge(delta: float) -> void:
	if not is_emergency_recharging():
		_trickle = 0.0
		return
	_trickle += delta
	if _trickle >= current.emergency_recharge_interval:
		_trickle = 0.0
		_ammo[current.id]["mag"] = magazine() + 1
		_emit_ammo()


func _handle_trigger(delta: float) -> void:
	var held := Input.is_action_pressed("fire")
	if Input.is_action_just_pressed("fire"):
		# Buffer clicks slightly so a click just before the weapon is ready still fires.
		_fire_buffer = FIRE_BUFFER
	var can_shoot := _cooldown <= 0.0 and not _reloading and _switch_left <= 0.0
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_step()
		return
	if current.charge_time > 0.0:
		_handle_charge(held, can_shoot, delta)
		return
	var wants := held if (current.automatic or current.beam) else _fire_buffer > 0.0
	# The beam stays on between damage ticks (they are paced by the cooldown).
	_set_beam(current.beam and held and not _reloading and _switch_left <= 0.0 and magazine() > 0)
	if not wants or not can_shoot:
		return
	if magazine() > 0:
		_fire_buffer = 0.0
		_fire()
	elif reserve() > 0:
		start_reload()
	elif _dry_cooldown <= 0.0:
		_fire_buffer = 0.0
		_dry_cooldown = 0.3
		Sfx.play(current.empty_sound, -4.0)


func _handle_charge(held: bool, can_shoot: bool, delta: float) -> void:
	if _charging:
		if not held:
			_release_charge()
			return
		_charge = minf(current.charge_time, _charge + delta)
		if not _charge_ready and _charge >= current.charge_time:
			_charge_ready = true
			Sfx.play(current.charge_ready_sound, -4.0)
		return
	if not held or not can_shoot:
		return
	if magazine() > 0:
		_charging = true
		_charge = 0.0
		_charge_ready = false
		_play_on(_charge_player, current.charge_sound, -6.0, false)
	elif reserve() > 0:
		start_reload()
	elif _dry_cooldown <= 0.0:
		_dry_cooldown = 0.3
		Sfx.play(current.empty_sound, -4.0)


func _release_charge() -> void:
	var fraction := charge_progress()
	_set_charging(false)
	if fraction < current.charge_min_fraction or magazine() <= 0:
		Sfx.play(current.empty_sound, -10.0, 0.8)
		return
	var t := inverse_lerp(current.charge_min_fraction, 1.0, fraction)
	_fire_shot(lerpf(current.charge_min_damage_scale, 1.0, t), fraction)


func _set_charging(on: bool) -> void:
	_charging = on
	if not on:
		_charge = 0.0
		_charge_ready = false
		_charge_player.stop()


func _set_beam(on: bool) -> void:
	if on == _beam_on:
		return
	_beam_on = on
	if on:
		_play_on(_loop_player, current.beam_loop_sound, -5.0, true)
		Sfx.play(current.fire_sound, -4.0)
	else:
		_loop_player.stop()


## Stops whatever the trigger was doing (switching, reloading, disabled).
func _end_trigger() -> void:
	_burst_left = 0
	if _charging:
		_set_charging(false)
	_set_beam(false)


func _play_on(p: AudioStreamPlayer, sound: StringName, volume_db: float, loop: bool) -> void:
	var s := Sfx.stream(sound)
	if s == null:
		return
	if loop and s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
	p.stream = s
	p.volume_db = volume_db
	p.play()


func _finish_reload() -> void:
	_reloading = false
	var state: Dictionary = _ammo[current.id]
	var need := current.magazine_size - int(state["mag"])
	var moved := mini(need, int(state["reserve"]))
	state["mag"] = int(state["mag"]) + moved
	state["reserve"] = int(state["reserve"]) - moved
	_emit_ammo()
	reload_finished.emit(current)


# --- firing -----------------------------------------------------------------------

## One trigger pull: a whole burst for burst weapons, otherwise one shot.
func _fire() -> void:
	if current.burst_count > 1:
		_burst_left = current.burst_count
		_burst_timer = _overshoot()
		_burst_step()
	else:
		_fire_shot(1.0, 1.0)


func _burst_step() -> void:
	if magazine() <= 0 or _reloading:
		_burst_left = 0
		return
	var carry := minf(_burst_timer, 0.0)
	_fire_shot(1.0, 1.0)
	_burst_left -= 1
	_burst_timer = current.burst_interval + carry
	_cooldown = (current.fire_interval if _burst_left <= 0 else current.burst_interval) + carry


## How far this frame ran past the moment the weapon was ready again (0 to
## one frame), carried into the next cooldown. A weapon that has been resting
## longer than a frame gets no credit.
func _overshoot() -> float:
	return _cooldown if _cooldown <= 0.0 and _cooldown > -_tick else 0.0


## Fires one shot. `scale` multiplies damage (charge), `power` 0-1 is the
## charge (1 for every other weapon); only a full charge pierces.
func _fire_shot(scale: float, power: float) -> void:
	var data := current
	var state: Dictionary = _ammo[data.id]
	state["mag"] = int(state["mag"]) - 1
	_cooldown = data.fire_interval + _overshoot()
	_emit_ammo()

	var cam := player.camera
	var origin := cam.global_position
	var aim := cam.global_transform.basis
	var muzzle := player.view.muzzle_position()
	var spread := deg_to_rad(current_spread())
	# Hits are gathered per zombie so a scatter blast is one solid hit
	# (one flash, one sound, summed damage and knockback), not nine tiny ones.
	var hits := {}
	for i in data.pellets:
		var dir := _spread_dir(aim, spread)
		if data.projectile_speed > 0.0:
			WeaponProjectile.launch(_level(), muzzle, launch_velocity(dir, data), data, self)
			continue
		var end := _trace(origin, dir, data, scale, data.pierce if power >= 1.0 else 0, hits)
		if data.beam:
			_beam_end = end
			_beam_linger = data.fire_interval * 1.5
		# Only a few streaks per scatter blast keep the screen readable.
		elif i < 4:
			WeaponFx.shot(_level(), muzzle, end, data, power)
	if data.chain_count > 0 and not hits.is_empty():
		_chain(hits, data, scale)
	var result := _apply_hits(hits, data)

	_bloom = minf(data.spread_bloom_max, _bloom + data.spread_bloom)
	_since_shot = 0.0
	_burst_count += 1
	# Learnable recoil: mostly vertical, drifting side to side every few shots.
	if _burst_count % 4 == 0:
		_recoil_side = -_recoil_side
	var ads_k := lerpf(1.0, 0.7, player.ads)
	var kick := data.recoil_kick * lerpf(0.5, 1.0, power)
	player.add_recoil(kick * ads_k, data.recoil_yaw * _recoil_side * randf_range(0.6, 1.0) * ads_k)
	player.add_shake(data.shake * lerpf(0.5, 1.0, power))
	if not data.beam:
		Sfx.play(data.fire_sound, -3.0, 1.0 + randf_range(-data.fire_pitch_variance, data.fire_pitch_variance))
	fired.emit(data)
	_confirm(result)
	if int(state["mag"]) <= 0 and int(state["reserve"]) > 0:
		# Auto-reload shortly after the last shot so the player is never stuck clicking.
		_cooldown = maxf(_cooldown, 0.2)
		get_tree().create_timer(0.2, false).timeout.connect(_auto_reload.bind(data))


func _spread_dir(aim: Basis, spread: float) -> Vector3:
	var angle := randf() * TAU
	var radius := tan(spread) * sqrt(randf())
	return (-aim.z + aim.x * cos(angle) * radius + aim.y * sin(angle) * radius).normalized()


## Launch velocity of a projectile fired along `dir`.
static func launch_velocity(dir: Vector3, data: WeaponData) -> Vector3:
	return dir * data.projectile_speed + Vector3.UP * data.projectile_loft


## Casts one shot along `dir`, through up to `pierce` extra zombies, and
## records its damage in `hits`. A miss with a seeking weapon locks onto the
## zombie nearest the crosshair. Returns where the shot ends.
func _trace(origin: Vector3, dir: Vector3, data: WeaponData, scale: float, pierce: int, hits: Dictionary) -> Vector3:
	var space := player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	var far := origin + dir * data.max_range
	var end := far
	var passed := 0
	var hit_any := false
	while true:
		var query := PhysicsRayQueryParameters3D.create(origin, far, MASK_WORLD | MASK_ENEMIES)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			end = far
			break
		end = hit["position"]
		var collider = hit["collider"]
		if collider is Zombie and not collider.is_dead():
			var z: Zombie = collider
			_record_ray_hit(hits, z, end, dir, data, origin.distance_to(end), scale * pow(data.pierce_falloff, passed))
			hit_any = true
			if passed >= pierce:
				break
			passed += 1
			exclude.append(z.get_rid())
			continue
		WeaponFx.impact(_level(), end, hit["normal"], data)
		break
	if not hit_any and data.seek_cone_degrees > 0.0:
		var target := seek(origin, dir, data)
		if target:
			end = _facing_point(target, origin)
			_record_ray_hit(hits, target, end, dir, data, origin.distance_to(end), scale)
	return end


func _record_ray_hit(hits: Dictionary, z: Zombie, point: Vector3, dir: Vector3, data: WeaponData, distance: float, scale: float) -> void:
	var head := z.is_head_hit(point)
	var dmg := data.damage * _falloff(data, distance) * scale
	if head:
		dmg *= data.headshot_multiplier
	_record(hits, z, point, dir, dmg, data.knockback, head)


## Adds damage to a zombie's entry for this shot.
func _record(hits: Dictionary, z: Zombie, point: Vector3, dir: Vector3, dmg: float, push: float, head: bool) -> void:
	var key := z.get_instance_id()
	if not hits.has(key):
		hits[key] = {"zombie": z, "damage": 0.0, "head_damage": 0.0, "push": 0.0, "head": false, "heads": 0, "count": 0, "point": point, "body_point": point, "dir": dir}
	var entry: Dictionary = hits[key]
	entry["damage"] = float(entry["damage"]) + dmg
	entry["push"] = float(entry["push"]) + push
	entry["count"] = int(entry["count"]) + 1
	if head:
		entry["heads"] = int(entry["heads"]) + 1
		entry["head_damage"] = float(entry["head_damage"]) + dmg
		entry["point"] = point
	elif int(entry["heads"]) == int(entry["count"]) - 1:
		entry["body_point"] = point
	# A blast counts as a headshot when at least a third of its hits are to the head.
	entry["head"] = int(entry["heads"]) * 3 >= int(entry["count"])


## The zombie closest to the aim line inside the seek cone, with line of sight.
func seek(origin: Vector3, dir: Vector3, data: WeaponData) -> Zombie:
	var best: Zombie = null
	var best_angle := deg_to_rad(data.seek_cone_degrees)
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var to := _chest(z) - origin
		if to.length() > data.max_range:
			continue
		var angle := dir.angle_to(to)
		if angle < best_angle and _clear_line(origin, _chest(z)):
			best = z
			best_angle = angle
	return best


## Chain lightning: from the first zombie hit, arcs to the nearest unhit
## zombie within chain_range, again and again, weaker each jump.
func _chain(hits: Dictionary, data: WeaponData, scale: float) -> void:
	var from: Zombie = hits[hits.keys()[0]]["zombie"]
	var dmg := data.damage * scale
	for k in data.chain_count:
		dmg *= data.chain_falloff
		var next := _nearest_unhit(from, data.chain_range, hits)
		if next == null:
			return
		var a := _chest(from)
		var b := _facing_point(next, a)
		LightningBolt.spawn(_level(), a, b, data.tracer_color, data.tracer_width * 0.75, 0.16, 0.22)
		Sfx.play_at(data.chain_sound, b, -6.0, randf_range(0.95, 1.15))
		_record(hits, next, b, (b - a).normalized(), dmg, data.knockback * 0.5, false)
		from = next


func _nearest_unhit(from: Zombie, max_range: float, hits: Dictionary) -> Zombie:
	var best: Zombie = null
	var best_d := max_range
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead() or hits.has(z.get_instance_id()):
			continue
		var d := z.global_position.distance_to(from.global_position)
		if d < best_d and _clear_line(_chest(from), _chest(z)):
			best = z
			best_d = d
	return best


## Deals the gathered damage, applies status effects and returns
## [any_hit, any_kill, any_head].
func _apply_hits(hits: Dictionary, data: WeaponData) -> Array:
	var any_hit := false
	var any_kill := false
	var any_head := false
	for key in hits:
		var entry: Dictionary = hits[key]
		var zombie: Zombie = entry["zombie"]
		if not is_instance_valid(zombie) or zombie.is_dead():
			continue
		var scale := StatusEffects.damage_scale(zombie)
		var dmg := float(entry["damage"]) * scale
		# A blast that hit both head and body: armour sees each part separately.
		var heads := int(entry["heads"])
		var head_part := float(entry["head_damage"]) * scale if heads > 0 and heads < int(entry["count"]) else -1.0
		var killed := zombie.take_hit(dmg, entry["point"], entry["dir"], data.id, bool(entry["head"]), float(entry["push"]), head_part, entry["body_point"])
		if not killed and data.status_effect != &"":
			StatusEffects.of(zombie).apply(data, data.status_amount * int(entry["count"]))
		any_hit = true
		any_kill = any_kill or killed
		any_head = any_head or bool(entry["head"])
	return [any_hit, any_kill, any_head]


## A projectile went off at `at` (`direct` = the zombie it struck, if any).
## Splash damage falls off to the edge; scenery shields zombies behind it.
## The player is never hurt by their own blasts.
func projectile_detonated(data: WeaponData, at: Vector3, direct: Zombie, dir: Vector3) -> void:
	var level := _level()
	if level == null:
		return
	WeaponFx.explosion(level, at, data.tracer_color, data.splash_radius)
	Sfx.play_at(data.explosion_sound, at, 2.0, randf_range(0.94, 1.06), 14.0)
	if is_instance_valid(player):
		player.add_shake(clampf(0.5 - player.global_position.distance_to(at) * 0.03, 0.08, 0.45))
	var hits := {}
	if direct and is_instance_valid(direct) and not direct.is_dead():
		_record(hits, direct, at, dir, data.direct_hit_bonus, 0.0, false)
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var chest := _chest(z)
		var d := minf(at.distance_to(chest), at.distance_to(z.global_position + Vector3.UP * 0.4))
		if d > data.splash_radius:
			continue
		if z != direct and not _clear_line(at + Vector3.UP * 0.2, chest):
			continue
		var k := 1.0 - d / maxf(0.1, data.splash_radius)
		var away := z.global_position - at
		away.y = 0.0
		away = away.normalized() if away.length() > 0.05 else dir
		_record(hits, z, _facing_point(z, at), away, data.damage * lerpf(data.splash_edge_scale, 1.0, k), data.splash_push * (0.4 + 0.6 * k), false)
	_confirm(_apply_hits(hits, data))


## Hit-confirm feedback: reticle marker plus non-positional sounds, so
## far-away hits still register. The kill sound climbs with the combo.
func _confirm(result: Array) -> void:
	if not result[0]:
		return
	var any_kill: bool = result[1]
	var any_head: bool = result[2]
	hit_confirmed.emit(any_kill, any_head)
	# Beam ticks would rattle the hit sound; it plays at most a few times a second.
	if not any_kill and _confirm_cool > 0.0:
		return
	_confirm_cool = 0.22 if current and current.beam else 0.0
	var director := get_tree().get_first_node_in_group("run_director") as RunDirector
	var combo := director.score.combo if director and director.score else 0
	if any_head:
		Sfx.play(&"headshot_ping", -5.0, randf_range(0.98, 1.03))
	if any_kill:
		Sfx.play(&"kill_confirm", -3.0, 1.0 + minf(0.5, 0.05 * maxf(0, combo)))
		if combo > 0 and combo % 5 == 0:
			Sfx.play(&"combo_up", -5.0, 1.0 + minf(0.4, 0.02 * combo))
	elif not any_head:
		Sfx.play(&"hitmarker", -9.0, randf_range(0.96, 1.04))


func _auto_reload(for_weapon: WeaponData) -> void:
	if current == for_weapon and magazine() <= 0:
		start_reload()


func _falloff(data: WeaponData, distance: float) -> float:
	if distance <= data.falloff_start:
		return 1.0
	var t := clampf((distance - data.falloff_start) / maxf(0.01, data.falloff_end - data.falloff_start), 0.0, 1.0)
	return lerpf(1.0, data.falloff_min_scale, t)


func _emit_ammo() -> void:
	ammo_changed.emit(magazine(), reserve())


# --- aim visuals (beam, lob arc, seek lock) ---------------------------------------

func _update_aim_visuals() -> void:
	var cam := player.camera
	var aim_dir := -cam.global_transform.basis.z
	lock_target = null
	if current.seek_cone_degrees > 0.0 and not current.beam:
		lock_target = seek(cam.global_position, aim_dir, current)
	if current.beam:
		if _beam == null:
			_beam = BeamVisual.new()
			add_child(_beam)
		_beam.color = current.tracer_color
		_beam.width = current.tracer_width
		var shown := _beam_on or _beam_linger > 0.0
		var end := _visual_end(cam.global_position, aim_dir) if shown else _beam_end
		_beam.aim(player.view.muzzle_position(), end, shown)
	elif _beam:
		_beam.aim(Vector3.ZERO, Vector3.ZERO, false)
	var lob := current.projectile_speed > 0.0 and current.projectile_gravity > 0.0
	if lob and _arc == null:
		_arc = ArcPreview.new()
		add_child(_arc)
	if _arc:
		var strength := clampf(player.ads * 1.4 - 0.2, 0.0, 1.0) if lob and not _reloading else 0.0
		_arc.show_path(current, player.view.muzzle_position(), launch_velocity(aim_dir, current), strength, [player.get_rid()])


## Where the beam visibly lands this frame (the target it is locked on, or scenery).
func _visual_end(origin: Vector3, dir: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * current.max_range, MASK_WORLD | MASK_ENEMIES)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit["position"]
	if current.seek_cone_degrees > 0.0:
		var target := seek(origin, dir, current)
		if target:
			return _chest(target)
	return origin + dir * current.max_range


# --- helpers -------------------------------------------------------------------

func _level() -> Node:
	return player.get_parent()


static func _chest(z: Zombie) -> Vector3:
	return z.global_position + Vector3.UP * 1.05 * z.data.body_scale


## A chest-height point on the side of `z` facing `from`, so hits that are not
## ray casts (seek, chain, splash) still have a direction (riot shields use it).
static func _facing_point(z: Zombie, from: Vector3) -> Vector3:
	var flat := Vector3(from.x - z.global_position.x, 0.0, from.z - z.global_position.z)
	var side := flat.normalized() * 0.3 * z.data.body_scale if flat.length() > 0.01 else Vector3.ZERO
	return _chest(z) + side


func _clear_line(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD)
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _warm_up() -> void:
	if not is_inside_tree() or _level() == null:
		return
	var cam := player.camera
	WeaponFx.warm_up(_level(), cam.global_position - cam.global_transform.basis.z * 2.5)
