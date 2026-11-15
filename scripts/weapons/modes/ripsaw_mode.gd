extends WeaponMode
## Toxic Ripsaw: a slime-pellet shotgun with a chain saw on the "melee" action
## (WeaponController.MELEE_ACTION, T or the middle mouse button by default).
##
## Saw: hold melee and the chain revs up for REV_UP seconds, then every TICK it
## bites up to MAX_TARGETS zombies within REACH in front of the player
## (WeaponController.melee_hit): SAW_DPS to the rank and file, HEAVY_SCALE of it
## to heavies and ALPHA_SCALE to alphas and bosses, so it saws through a pack of
## tourists but barely scratches a Bruno. The first bite on a standard zombie
## knocks it out of its swing and staggers it where it stands (heavies and
## alphas keep coming); a light push holds whatever is on the bar. Sawing slows the player (SAW_MOVE) and cannot be
## combined with the shotgun. Fuel: a full rack saws for FUEL_TIME seconds,
## refills over REFILL_TIME once the saw rests for REFILL_DELAY, and a reload
## swaps in a full rack. Run it dry and it floods: it will not restart until
## RESTART_FUEL has come back.
##
## Shotgun: each blast that hits leaves a slime puddle under the zombie it hit
## hardest (SlimePuddle: slows zombies standing in it) and pops slime confetti.
## The viewmodel (chain, sprocket, canisters, gauge) follows `rev`, `fuel` and
## `biting` in scripts/weapons/views/ripsaw_view.gd.

const SAW_DPS := 150.0
const HEAVY_SCALE := 0.45
const ALPHA_SCALE := 0.3
## A zombie this heavy (EnemyData.mass) counts as an alpha.
const ALPHA_MASS := 5.0
## Reach from the player's centre to a zombie's surface (metres), and the
## widest angle off the aim a zombie can be bitten at (cosine).
const REACH := 1.4
const CONE_COS := 0.55
const MAX_TARGETS := 2
const TICK := 0.1
const REV_UP := 0.22
const REV_DOWN := 0.45
## The saw only bites once it has revved this far.
const BITE_REV := 0.7
const FUEL_TIME := 3.5
const REFILL_TIME := 7.0
const REFILL_DELAY := 0.8
const RESTART_FUEL := 0.35
const SAW_MOVE := 0.78
## Push per tick holding a zombie on the bar.
const HOLD_PUSH := 0.9
## Seconds before a zombie that left the bar is kicked again by a new bite.
const BITE_MEMORY := 1.5
const PUDDLE_MIN_DAMAGE := 20.0
const REV_SOUND := &"weap_ripsaw_rev"
const IDLE_SOUND := &"weap_ripsaw_idle"
const BITE_SOUND := &"weap_ripsaw_bite"
const SPUTTER_SOUND := &"weap_ripsaw_sputter"
const SPLAT_SOUND := &"weap_ripsaw_splat"
## Controller metadata holding the rack's level while the Ripsaw is put away.
const STOWED_META := &"ripsaw_rack"
const SLIME_COLORS: Array[Color] = [Color(0.72, 1.0, 0.2), Color(0.45, 0.92, 0.18), Color(0.95, 1.0, 0.65), Color(1.0, 0.6, 0.15)]

## 0-1: how fast the chain is running (rises while melee is held).
var rev := 0.0
## 0-1: slime left in the rack for the saw.
var fuel := 1.0
## True while melee is held and the saw is running.
var sawing := false
## True while the chain is in a zombie (the last tick bit something).
var biting := false
var _flooded := false
var _tick := 0.0
var _rest := 0.0
var _bite_sound := 0.0
var _bitten := {}               # zombie instance id -> seconds since its last bite
var _buzz: AudioStreamPlayer
var _restored := false


func melee(held: bool, delta: float) -> void:
	if not _restored:
		_restore()
	var want := held and not _flooded and fuel > 0.0
	if want and not sawing:
		Sfx.play(REV_SOUND, -3.0, randf_range(0.97, 1.03))
	sawing = want
	rev = move_toward(rev, 1.0 if sawing else 0.0, delta / (REV_UP if sawing else REV_DOWN))
	if sawing:
		_rest = 0.0
		fuel = maxf(0.0, fuel - delta / FUEL_TIME)
		if fuel <= 0.0:
			_flood()
	else:
		_rest += delta
		if _rest >= REFILL_DELAY:
			fuel = minf(1.0, fuel + delta / REFILL_TIME)
		if _flooded and fuel >= RESTART_FUEL:
			_flooded = false
	_age_bites(delta)
	if sawing and rev >= BITE_REV:
		_tick -= delta
		if _tick <= 0.0:
			_tick += TICK
			_cut()
	else:
		_tick = 0.0
		biting = false
	_update_buzz(delta)


func trigger(_spinning: bool, _delta: float) -> bool:
	return not sawing


func end_trigger() -> void:
	sawing = false
	biting = false


func melee_reach() -> float:
	return REACH if not _flooded and fuel > 0.0 else 0.0


func gauge() -> float:
	return fuel


func reloaded() -> void:
	fuel = 1.0
	_flooded = false


func move_scale() -> float:
	return lerpf(1.0, SAW_MOVE, rev) if sawing else 1.0


func shape_hits(hits: Dictionary, _from: Vector3, _end: Vector3, _power: float) -> void:
	var best: Zombie = null
	var best_damage := PUDDLE_MIN_DAMAGE
	for key in hits:
		var entry: Dictionary = hits[key]
		var z: Zombie = entry["zombie"]
		if not is_instance_valid(z):
			continue
		var at: Vector3 = entry["body_point"]
		WeaponFx.burst(_level(), at, -Vector3(entry["dir"]), SLIME_COLORS, 7, 3.4, 0.45, 0.05, 70.0)
		if float(entry["damage"]) > best_damage:
			best_damage = float(entry["damage"])
			best = z
	if best:
		SlimePuddle.spawn(_level(), best.global_position, data.tracer_color)
		Sfx.play_at(SPLAT_SOUND, best.global_position + Vector3.UP, -4.0, randf_range(0.92, 1.08))


func dispose() -> void:
	if is_instance_valid(_buzz):
		_buzz.queue_free()
	# The rack keeps its level while stowed, so swapping weapons never refuels the saw.
	controller.set_meta(STOWED_META, [fuel, _flooded, Engine.get_physics_frames()])


## Picks up the rack where it was put away, refilled for the time it was stowed.
func _restore() -> void:
	_restored = true
	if not controller.has_meta(STOWED_META):
		return
	var stowed: Array = controller.get_meta(STOWED_META)
	var away := float(Engine.get_physics_frames() - int(stowed[2])) / Engine.physics_ticks_per_second
	fuel = minf(1.0, float(stowed[0]) + maxf(0.0, away - REFILL_DELAY) / REFILL_TIME)
	_flooded = bool(stowed[1]) and fuel < RESTART_FUEL


## Ran dry: the engine sputters out and will not restart until it refills a little.
func _flood() -> void:
	_flooded = true
	sawing = false
	Sfx.play(SPUTTER_SOUND, -3.0)


## One bite: the nearest zombies on the bar take a tick of damage.
func _cut() -> void:
	var player := controller.player
	var eye := player.aim_transform()
	var forward := -eye.basis.z
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	var found: Array[Zombie] = []
	var gaps: Array[float] = []
	for node in player.get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var to := z.global_position - player.global_position
		var flat := Vector3(to.x, 0.0, to.z)
		var gap := flat.length() - z.data.capsule_radius * z.data.body_scale
		if gap > REACH or absf(to.y) > 2.2 * z.data.body_scale:
			continue
		if flat.length() > 0.3 and flat.normalized().dot(flat_forward) < CONE_COS:
			continue
		var at := 0
		while at < gaps.size() and gaps[at] < gap:
			at += 1
		found.insert(at, z)
		gaps.insert(at, gap)
	biting = false
	for i in mini(found.size(), MAX_TARGETS):
		var z := found[i]
		var chest := z.global_position + Vector3.UP * 1.0 * z.data.body_scale
		if not _clear(eye.origin, chest):
			continue
		_bite(z, chest, (chest - eye.origin).normalized())


func _bite(z: Zombie, chest: Vector3, dir: Vector3) -> void:
	var key := z.get_instance_id()
	var fresh := not _bitten.has(key)
	_bitten[key] = 0.0
	var scale := ALPHA_SCALE if z.rank == Zombie.RANK_BOSS or z.data.mass >= ALPHA_MASS else (HEAVY_SCALE if z.data.heavy else 1.0)
	var point := chest - Vector3(dir.x, 0.0, dir.z).normalized() * z.data.capsule_radius * z.data.body_scale
	biting = true
	if fresh and scale >= 1.0:
		z.interrupt()
	controller.melee_hit(data, z, point, dir, SAW_DPS * TICK * scale, HOLD_PUSH)
	WeaponFx.burst(_level(), point, -dir, SLIME_COLORS, 4, 3.0, 0.3, 0.04, 80.0)
	controller.player.add_shake(0.07)
	if fresh or _bite_sound <= 0.0:
		_bite_sound = 0.3
		Sfx.play(BITE_SOUND, -4.0, randf_range(0.94, 1.06))


func _age_bites(delta: float) -> void:
	_bite_sound -= delta
	if _bitten.is_empty():
		return
	for key in _bitten.keys():
		_bitten[key] = float(_bitten[key]) + delta
		if float(_bitten[key]) > BITE_MEMORY:
			_bitten.erase(key)


func _clear(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, WeaponController.MASK_WORLD)
	return controller.player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _level() -> Node:
	return controller.player.get_parent()


## The engine's idle buzz: rises with the rev and growls while biting.
func _update_buzz(delta: float) -> void:
	if rev <= 0.0:
		if is_instance_valid(_buzz) and _buzz.playing:
			_buzz.stop()
		return
	if not is_instance_valid(_buzz):
		var stream := Sfx.stream(IDLE_SOUND)
		if stream == null:
			return
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_buzz = AudioStreamPlayer.new()
		_buzz.bus = &"SFX"
		_buzz.stream = stream
		controller.add_child(_buzz)
	var bite := 1.0 if biting else 0.0
	_buzz.pitch_scale = lerpf(_buzz.pitch_scale, lerpf(0.6, 1.0, rev) - 0.12 * bite, 1.0 - exp(-12.0 * delta))
	_buzz.volume_db = lerpf(-22.0, -8.0, sqrt(rev)) + 1.5 * bite + Sfx.mix_db(IDLE_SOUND)
	if not _buzz.playing:
		_buzz.play()
