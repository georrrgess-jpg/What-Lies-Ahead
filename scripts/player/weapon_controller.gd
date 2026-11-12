class_name WeaponController
extends Node
## Shared combat code for every weapon: ammo, fire timing, reloads and hitscan.
## All tuning comes from WeaponData resources (data/weapons/*.tres).
##
## Ammo is tracked per weapon for the whole run, so swapping at the kiosk and
## swapping back returns exactly the ammo that weapon had.

signal weapon_changed(data: WeaponData)
signal ammo_changed(magazine: int, reserve: int)
signal fired(data: WeaponData)
signal reload_started(data: WeaponData, duration: float)
signal reload_finished(data: WeaponData)
signal hit_confirmed(killed: bool, headshot: bool)

const MASK_WORLD := 1
const MASK_ENEMIES := 4
const FIRE_BUFFER := 0.14

var current: WeaponData
## False between runs or while the results screen is up.
var enabled := true

var _ammo := {}            # weapon id -> { "mag": int, "reserve": int }
var _cooldown := 0.0
var _reload_left := 0.0
var _reloading := false
var _bloom := 0.0
var _fire_buffer := 0.0
var _dry_cooldown := 0.0
var _trickle := 0.0
var _since_shot := 10.0
var _recoil_side := 1.0
var _burst_count := 0

@onready var player: Player = get_parent()


## Gives every weapon its starting ammo. Call once per run.
func begin_run() -> void:
	_ammo.clear()
	for w in GameData.weapons():
		_ammo[w.id] = {"mag": w.magazine_size, "reserve": w.reserve_start}


func equip(weapon_id: StringName) -> bool:
	var data := GameData.weapon(weapon_id)
	if data == null or data == current:
		return false
	if not _ammo.has(data.id):
		_ammo[data.id] = {"mag": data.magazine_size, "reserve": data.reserve_start}
	current = data
	_reloading = false
	_reload_left = 0.0
	_cooldown = 0.35
	_bloom = 0.0
	weapon_changed.emit(data)
	_emit_ammo()
	return true


func magazine() -> int:
	return int(_ammo[current.id]["mag"]) if current else 0


func reserve() -> int:
	return int(_ammo[current.id]["reserve"]) if current else 0


func is_reloading() -> bool:
	return _reloading


## 0-1 through the current reload.
func reload_progress() -> float:
	if not _reloading or current == null:
		return 0.0
	return 1.0 - clampf(_reload_left / maxf(0.01, current.reload_time), 0.0, 1.0)


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


func is_ammo_full() -> bool:
	return current == null or (magazine() >= current.magazine_size and reserve() >= current.reserve_max)


## Free break refill: adds a fraction of reserve_max to the held weapon.
func refill_fraction(fraction: float) -> int:
	if current == null:
		return 0
	var state: Dictionary = _ammo[current.id]
	var before := int(state["reserve"])
	state["reserve"] = mini(current.reserve_max, before + int(ceil(current.reserve_max * fraction)))
	_emit_ammo()
	return int(state["reserve"]) - before


## Kiosk purchase: full magazine and full reserve for the held weapon.
func top_up() -> void:
	if current == null:
		return
	var state: Dictionary = _ammo[current.id]
	state["mag"] = current.magazine_size
	state["reserve"] = current.reserve_max
	_reloading = false
	_emit_ammo()


func start_reload() -> bool:
	if current == null or _reloading or magazine() >= current.magazine_size or reserve() <= 0:
		return false
	_reloading = true
	_reload_left = current.reload_time
	Sfx.play(current.reload_sound, -2.0)
	reload_started.emit(current, current.reload_time)
	return true


func _physics_process(delta: float) -> void:
	_since_shot += delta
	if _since_shot > 0.35:
		_burst_count = 0
	_cooldown = maxf(0.0, _cooldown - delta)
	_fire_buffer = maxf(0.0, _fire_buffer - delta)
	_dry_cooldown = maxf(0.0, _dry_cooldown - delta)
	if current == null:
		return
	_bloom = maxf(0.0, _bloom - current.spread_bloom_max * 2.5 * delta)

	if _reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()

	# Emergency recharge: only when the reserve is empty and the magazine is low.
	if is_emergency_recharging():
		_trickle += delta
		if _trickle >= current.emergency_recharge_interval:
			_trickle = 0.0
			_ammo[current.id]["mag"] = magazine() + 1
			_emit_ammo()
	else:
		_trickle = 0.0

	if not enabled or not player.alive or not player.controls_enabled:
		return

	if Input.is_action_just_pressed("reload"):
		start_reload()

	var wants_fire := false
	if current.automatic:
		wants_fire = Input.is_action_pressed("fire")
	else:
		# Buffer semi-auto clicks slightly so a click just before the weapon is
		# ready still fires.
		if Input.is_action_just_pressed("fire"):
			_fire_buffer = FIRE_BUFFER
		wants_fire = _fire_buffer > 0.0

	if wants_fire and _cooldown <= 0.0 and not _reloading:
		if magazine() > 0:
			_fire_buffer = 0.0
			_fire()
		elif reserve() > 0:
			start_reload()
		elif _dry_cooldown <= 0.0:
			_fire_buffer = 0.0
			_dry_cooldown = 0.3
			Sfx.play(current.empty_sound, -4.0)


func _finish_reload() -> void:
	_reloading = false
	var state: Dictionary = _ammo[current.id]
	var need := current.magazine_size - int(state["mag"])
	var moved := mini(need, int(state["reserve"]))
	state["mag"] = int(state["mag"]) + moved
	state["reserve"] = int(state["reserve"]) - moved
	_emit_ammo()
	reload_finished.emit(current)


func _fire() -> void:
	var data := current
	var state: Dictionary = _ammo[data.id]
	state["mag"] = int(state["mag"]) - 1
	_cooldown = data.fire_interval
	_emit_ammo()

	var cam := player.camera
	var origin := cam.global_position
	var aim := cam.global_transform.basis
	var space := player.get_world_3d().direct_space_state
	var muzzle := player.view.muzzle_position()
	var spread := deg_to_rad(current_spread())
	var any_hit := false
	var any_kill := false
	var any_head := false
	# Pellets are gathered per zombie so a scatter blast is one solid hit
	# (one flash, one sound, summed damage and knockback), not nine tiny ones.
	var hits := {}

	for i in data.pellets:
		var angle := randf() * TAU
		var radius := tan(spread) * sqrt(randf())
		var dir := (-aim.z + aim.x * cos(angle) * radius + aim.y * sin(angle) * radius).normalized()
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * data.max_range, MASK_WORLD | MASK_ENEMIES)
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		var end := origin + dir * data.max_range
		if not hit.is_empty():
			end = hit["position"]
			var collider = hit["collider"]
			if collider is Zombie and not collider.is_dead():
				var zombie: Zombie = collider
				var head := zombie.is_head_hit(end)
				var dmg := data.damage * _falloff(data, origin.distance_to(end))
				if head:
					dmg *= data.headshot_multiplier
				var key := zombie.get_instance_id()
				if not hits.has(key):
					hits[key] = {"zombie": zombie, "damage": 0.0, "push": 0.0, "head": false, "heads": 0, "count": 0, "point": end, "dir": dir}
				var entry: Dictionary = hits[key]
				entry["damage"] = float(entry["damage"]) + dmg
				entry["push"] = float(entry["push"]) + data.knockback
				entry["count"] = int(entry["count"]) + 1
				if head:
					entry["heads"] = int(entry["heads"]) + 1
					entry["point"] = end
				# A blast counts as a headshot when at least a third of its hits are to the head.
				entry["head"] = int(entry["heads"]) * 3 >= int(entry["count"])
			else:
				Fx.impact(player.get_parent(), end, hit["normal"], data.tracer_color)
		# Only a few streaks per scatter blast keep the screen readable.
		if i < 4:
			Fx.tracer(player.get_parent(), muzzle, end, data.tracer_color, data.tracer_width)

	for key in hits:
		var entry: Dictionary = hits[key]
		var zombie: Zombie = entry["zombie"]
		if not is_instance_valid(zombie) or zombie.is_dead():
			continue
		var killed := zombie.take_hit(float(entry["damage"]), entry["point"], entry["dir"], data.id, bool(entry["head"]), float(entry["push"]))
		any_hit = true
		any_kill = any_kill or killed
		any_head = any_head or bool(entry["head"])

	_bloom = minf(data.spread_bloom_max, _bloom + data.spread_bloom)
	_since_shot = 0.0
	_burst_count += 1
	# Learnable recoil: mostly vertical, drifting side to side every few shots.
	if _burst_count % 4 == 0:
		_recoil_side = -_recoil_side
	var ads_k := lerpf(1.0, 0.7, player.ads)
	player.add_recoil(data.recoil_kick * ads_k, data.recoil_yaw * _recoil_side * randf_range(0.6, 1.0) * ads_k)
	player.add_shake(data.shake)
	Sfx.play(data.fire_sound, -3.0, 1.0 + randf_range(-data.fire_pitch_variance, data.fire_pitch_variance))
	fired.emit(data)
	if any_hit:
		hit_confirmed.emit(any_kill, any_head)
		# Non-positional confirms so far-away hits still register.
		# The kill sound climbs in pitch with the combo, like an arcade multiplier.
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
	if int(state["mag"]) <= 0 and int(state["reserve"]) > 0:
		# Auto-reload shortly after the last shot so the player is never stuck clicking.
		_cooldown = maxf(_cooldown, 0.2)
		get_tree().create_timer(0.2, false).timeout.connect(_auto_reload.bind(data))


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
