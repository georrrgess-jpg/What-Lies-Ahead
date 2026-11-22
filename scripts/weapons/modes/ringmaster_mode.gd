class_name RingmasterMode
extends WeaponMode
## Ringmaster "The Main Event": a full-auto drum rifle, accurate and fast.
##
## Spotlight: kills with it fill the Spotlight meter (a headshot kill counts
## double, every headshot hit adds a sliver). The meter is kept on the
## controller, so it survives a weapon switch and waits once full.
##
## The Main Event: with the meter full, holding the sights for CALL_HOLD calls
## it: for EVENT_TIME seconds the drum spins up (BASE_INTERVAL down to the
## data rate, WeaponData.fire_interval, the fastest it fires), every round
## flies as a wide spotlight beam that passes through EVENT_PIERCE more
## zombies, and every kill pops a confetti burst (POP_DAMAGE to the zombies
## within POP_RADIUS, less at the edge, heavies take half), which can set off
## the next pop, so a packed crowd chains. The meter drains with the clock.
##
## The drum's rings, bulbs and the spotlight on the handguard move in
## scripts/weapons/views/ringmaster_view.gd (reads `spotlight`, `event_left`,
## `since_call`, `since_pop`); the HUD chip reads `chip()`.

const TRAIT := "MAIN EVENT"
## Seconds between rounds outside the Main Event (13.5 a second).
const BASE_INTERVAL := 0.074
## Meter per kill (a headshot kill counts twice) and per headshot hit.
const FILL_KILL := 1.0 / 16.0
const FILL_HEAD := 0.01
## Seconds of aiming that call the Main Event, its length, its pierce.
const CALL_HOLD := 0.3
const EVENT_TIME := 6.0
const EVENT_PIERCE := 1
## Seconds the drum takes to spin up to the Main Event's rate.
const SPIN_UP := 0.45
## Confetti pops: damage at the centre, radius, edge and heavy scale, and the
## most that go off in one physics frame (the rest wait for the next).
const POP_DAMAGE := 30.0
const POP_RADIUS := 2.6
const POP_EDGE := 0.5
const POP_HEAVY := 0.5
const POPS_PER_FRAME := 3
const SPOTLIGHT := Color(1.0, 0.93, 0.68)
const CONFETTI := [Color(1.0, 0.84, 0.25), Color(0.93, 0.16, 0.3), Color(1.0, 0.97, 0.88), Color(0.35, 0.78, 1.0), Color(1.0, 0.45, 0.75)]
const READY_SOUND := &"rm_ready"
const CALL_SOUND := &"rm_call"
const END_SOUND := &"rm_end"
const POP_SOUND := &"rm_pop"
## Controller metadata that keeps the meter while another weapon is out.
const METER_META := &"ringmaster_spotlight"

## 0-1: the Spotlight meter.
var spotlight := 0.0
## Seconds of the Main Event left (0 when it is not on).
var event_left := 0.0
## Seconds since the Main Event was called, and since the last confetti pop.
var since_call := 10.0
var since_pop := 10.0
var _aim_held := 0.0
var _since := 10.0
var _pops: Array[Vector3] = []
var _listening := false
var _beam: WeaponData


## True while the Main Event is on.
func live() -> bool:
	return event_left > 0.0


## 0-1: how far the drum has spun up (the Main Event's rate).
func spin() -> float:
	return clampf(since_call / SPIN_UP, 0.0, 1.0) if live() else 0.0


## The Arsenal shows the everyday rate (the data rate is the Main Event's):
## the same magazine and reload, paced at BASE_INTERVAL.
func arsenal_dps(base: float) -> float:
	var mag := float(data.magazine_size)
	return base * (mag * data.fire_interval + data.reload_time) / (mag * BASE_INTERVAL + data.reload_time)


func trigger(_spinning: bool, delta: float) -> bool:
	_listen()
	_since += delta
	since_call += delta
	since_pop += delta
	if live():
		event_left = maxf(0.0, event_left - delta)
		spotlight = event_left / EVENT_TIME
		if not live():
			Sfx.play(END_SOUND, -6.0)
	elif spotlight >= 1.0 and controller.player.aim_blend > 0.8:
		_aim_held += delta
		if _aim_held >= CALL_HOLD:
			_call()
	else:
		_aim_held = 0.0
	_save()
	var n := mini(POPS_PER_FRAME, _pops.size())
	for i in n:
		_pop(_pops.pop_front())
	return _since >= _interval() - 0.001


## The drum's gauge in the HUD's side bar: the meter.
func gauge() -> float:
	return spotlight


## The HUD chip: {text, fill, ready, live}.
func chip() -> Dictionary:
	var text := "SPOTLIGHT"
	if live():
		text = "MAIN EVENT  %.1f" % event_left
	elif spotlight >= 1.0:
		text = "MAIN EVENT READY  ·  HOLD AIM"
	return {"text": text, "fill": spotlight, "ready": spotlight >= 1.0 and not live(), "live": live()}


## The Main Event's rounds: a pierced trace from the eye along `dir`, drawn
## as a spotlight beam from the muzzle to where it stops.
func launch(from: Vector3, dir: Vector3, scale: float) -> bool:
	if not live():
		return false
	var player := controller.player
	var origin := player.aim_transform().origin
	var space := player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	var far := origin + dir * data.max_range
	var end := far
	var passed := 0
	var level := player.get_parent()
	while passed <= EVENT_PIERCE:
		var query := PhysicsRayQueryParameters3D.create(origin, far, WeaponController.MASK_WORLD | WeaponController.MASK_ENEMIES)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		end = hit["position"]
		var z := hit["collider"] as Zombie
		if z == null:
			WeaponFx.impact(level, end, hit["normal"], data)
			break
		if z.is_dead():
			exclude.append(z.get_rid())
			continue
		exclude.append(z.get_rid())
		if z.is_head_hit(end):
			_fill(FILL_HEAD)
		controller.strike(data, z, end, dir, origin.distance_to(end), scale * pow(data.pierce_falloff, passed))
		passed += 1
	WeaponFx.shot(level, from, end, _beam_data())
	return true


## Every shot: the next round waits for the (spun-up) interval; headshot hits feed the meter.
func shape_hits(hits: Dictionary, _from: Vector3, _end: Vector3, _power: float) -> void:
	_since = clampf(_since - _interval(), 0.0, 1.0 / 60.0)
	for key in hits:
		if bool(hits[key]["head"]):
			_fill(FILL_HEAD)


func end_trigger() -> void:
	_aim_held = 0.0


func dispose() -> void:
	_save()
	if _listening and Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.disconnect(_on_kill)
	_listening = false


## The bot calls the Main Event as soon as the meter is full (and aims through it).
func bot_aim() -> bool:
	return spotlight >= 1.0 or live()


func bot_fire(_nearest: float) -> bool:
	return true


func _interval() -> float:
	return lerpf(BASE_INTERVAL, data.fire_interval, spin())


func _call() -> void:
	event_left = EVENT_TIME
	since_call = 0.0
	_aim_held = 0.0
	Sfx.play(CALL_SOUND, -2.0)
	controller.player.add_shake(0.08)


func _fill(amount: float) -> void:
	if live() or spotlight >= 1.0:
		return
	spotlight = minf(1.0, spotlight + amount)
	if spotlight >= 1.0:
		Sfx.play(READY_SOUND, -3.0)


func _save() -> void:
	if is_instance_valid(controller):
		controller.set_meta(METER_META, [spotlight, event_left])


func _listen() -> void:
	if _listening:
		return
	_listening = true
	var kept: Array = controller.get_meta(METER_META, [0.0, 0.0])
	spotlight = float(kept[0])
	event_left = float(kept[1])
	since_call = SPIN_UP if live() else 10.0
	Events.enemy_killed.connect(_on_kill)


func _on_kill(enemy: Node, weapon_id: StringName, headshot: bool, _points: int) -> void:
	if weapon_id != data.id or not is_instance_valid(controller):
		return
	if live():
		var z := enemy as Zombie
		if z:
			_pops.append(z.global_position + Vector3.UP * 1.0 * z.data.body_scale)
		return
	_fill(FILL_KILL * (2.0 if headshot else 1.0))


## A confetti pop at `at`: the burst, a party-popper bang and damage round it.
func _pop(at: Vector3) -> void:
	since_pop = 0.0
	var level := controller.player.get_parent()
	WeaponFx.burst(level, at, Vector3.UP, CONFETTI, 26, 5.0, 0.9, 0.045, 160.0, Vector3(0, -6.0, 0))
	WeaponFx.flash(level, at, SPOTLIGHT, 0.8, 0.12)
	Sfx.play_at(POP_SOUND, at, -2.0, randf_range(0.94, 1.08))
	var space := controller.player.get_world_3d().direct_space_state
	for node in controller.get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var chest := z.global_position + Vector3.UP * 1.0 * z.data.body_scale
		var d := chest.distance_to(at)
		if d > POP_RADIUS or d < 0.05:
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(at, chest, WeaponController.MASK_WORLD)).is_empty():
			continue
		var away := (chest - at) / d
		var dmg := POP_DAMAGE * lerpf(1.0, POP_EDGE, d / POP_RADIUS) * (POP_HEAVY if z.data.heavy or z.rank == Zombie.RANK_BOSS else 1.0)
		controller.ring_hit(data, z, chest - away * z.data.capsule_radius * z.data.body_scale, away, dmg, false)


## A copy of the weapon's data with the spotlight's warm, wide beam.
func _beam_data() -> WeaponData:
	if _beam == null:
		_beam = data.duplicate()
		_beam.tracer_color = SPOTLIGHT
		_beam.tracer_width = data.tracer_width * 3.2
	return _beam
