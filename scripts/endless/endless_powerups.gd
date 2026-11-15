class_name EndlessPowerups
extends Node
## The power-ups of an Endless run (owned by the EndlessDirector). Now and
## then a kill drops one (EndlessRules.powerup_*: a small chance per kill,
## never two on the ground, a gap of seconds between drops, a boss always
## drops Max Ammo). The drop is telegraphed with a sting, a notice and a HUD
## marker; it lies for a while, blinking before it goes. Taking it:
##   Double Tickets  every kill pays twice for powerup_seconds;
##   Max Ammo        both weapons full;
##   Blast Wave      knocks back and hurts every zombie within BLAST_RADIUS;
##   Rapid Fire      faster shots and reloads for powerup_seconds.
## A timed one taken again restarts its clock; nothing stacks or lasts past
## the run.

## A power-up dropped (null once it was taken or ran out).
signal dropped(powerup: EndlessPowerup)
## A timed power-up started or ended.
signal changed

const DOUBLE := &"double_tickets"
const AMMO := &"max_ammo"
const BLAST := &"blast_wave"
const RAPID := &"rapid_fire"
## Every kind: title, glyph on the token, colour, timed.
const KINDS := {
	DOUBLE: ["DOUBLE TICKETS", "2X", Color(1.0, 0.8, 0.2), true],
	AMMO: ["MAX AMMO", "AMMO", Color(0.4, 1.0, 0.5), false],
	BLAST: ["BLAST WAVE", "BOOM", Color(1.0, 0.42, 0.2), false],
	RAPID: ["RAPID FIRE", "FAST", Color(0.35, 0.85, 1.0), true],
}
const ORDER: Array[StringName] = [DOUBLE, AMMO, BLAST, RAPID]
const BLAST_RADIUS := 11.0
## Blast damage at health scale 1 (heavies take HEAVY_SHARE, a boss BOSS_SHARE).
const BLAST_DAMAGE := 160.0
const BLAST_PUSH := 16.0
const HEAVY_SHARE := 0.6
const BOSS_SHARE := 0.15
## A drop further than this (m) from the navmesh is not made.
const GROUND_REACH := 3.0

var director: EndlessDirector
## The power-up on the ground, if any.
var pickup: EndlessPowerup
## Timed power-ups running: kind -> seconds left.
var active := {}
## Power-ups taken this run.
var taken := 0

var _since := 0.0
var _last: StringName


## Rolls a drop where `z` fell.
func on_kill(z: Zombie, n: int) -> void:
	var boss := z.data.id == director.rules.boss_id
	if not boss and (n < director.rules.powerup_from_wave or is_instance_valid(pickup) or _since < director.rules.powerup_gap):
		return
	if not boss and randf() >= director.rules.powerup_chance:
		return
	_drop(AMMO if boss else _roll(), z.global_position)


## Seconds left of timed power-up `kind` (0 when it is not running).
func left(kind: StringName) -> float:
	return float(active.get(kind, 0.0))


func _process(delta: float) -> void:
	_since += delta
	if active.is_empty():
		return
	for kind in active.keys():
		active[kind] = float(active[kind]) - delta
		if float(active[kind]) <= 0.0:
			_end(kind)


## Ends every timed power-up (the run is over).
func clear() -> void:
	for kind in active.keys():
		_end(kind)
	if is_instance_valid(pickup):
		pickup.queue_free()


## A kind other than the last one, Max Ammo more likely when the player runs low.
func _roll() -> StringName:
	var pool: Array[StringName] = []
	for kind in ORDER:
		if kind != _last:
			pool.append(kind)
	var w := director.run.player.weapons
	if w.reserve() < w.current.reserve_max * 0.3 and _last != AMMO:
		return AMMO
	return pool[randi() % pool.size()]


func _drop(kind: StringName, at: Vector3) -> void:
	var run := director.run
	if is_instance_valid(pickup):
		pickup.queue_free()
	# It lies on walkable ground the player can reach, or not at all.
	var map := run.player.get_world_3d().navigation_map
	var ground := NavigationServer3D.map_get_closest_point(map, at)
	if ground.distance_to(at) > GROUND_REACH:
		return
	var info: Array = KINDS[kind]
	pickup = EndlessPowerup.new()
	pickup.name = "PowerUp"
	pickup.kind = kind
	pickup.title = info[0]
	pickup.glyph = info[1]
	pickup.color = info[2]
	pickup.life = director.rules.powerup_life
	pickup.director = run
	pickup.collected.connect(_take)
	pickup.tree_exited.connect(func(): dropped.emit(null))
	run.get_parent().add_child(pickup)
	pickup.global_position = ground
	_last = kind
	_since = 0.0
	Sfx.play_at(&"cos_unlock", pickup.global_position + Vector3.UP, -2.0, 1.0, 30.0)
	run.notice.emit("POWER-UP: %s" % info[0], &"good")
	dropped.emit(pickup)


func _take(p: EndlessPowerup) -> void:
	var run := director.run
	var info: Array = KINDS[p.kind]
	taken += 1
	Sfx.play(&"mall_power_up", -2.0)
	match p.kind:
		AMMO:
			run.player.weapons.top_up()
			run.notice.emit("MAX AMMO!", &"good")
		BLAST:
			_blast(run, p.global_position)
			run.notice.emit("BLAST WAVE!", &"good")
		_:
			_begin(p.kind)
			run.notice.emit("%s  ·  %d s" % [info[0], int(director.rules.powerup_seconds)], &"good")


func _begin(kind: StringName) -> void:
	active[kind] = director.rules.powerup_seconds
	if kind == DOUBLE:
		director.run.ticket_scale = 2.0
	elif kind == RAPID:
		director.upgrades.set_rapid(true)
	changed.emit()


func _end(kind: StringName) -> void:
	active.erase(kind)
	if kind == DOUBLE:
		director.run.ticket_scale = 1.0
	elif kind == RAPID:
		director.upgrades.set_rapid(false)
	Sfx.play(&"mall_power_down", -8.0)
	changed.emit()


## Every zombie near the player is thrown back and hurt; a ring of fire shows it.
func _blast(run: RunDirector, at: Vector3) -> void:
	var centre := run.player.global_position
	var scale := director.health_scale()
	for item in run.alive_enemies().duplicate():
		var z := item as Zombie
		if not is_instance_valid(z) or z.is_dead():
			continue
		var to := z.global_position - centre
		to.y = 0.0
		var d := to.length()
		if d > BLAST_RADIUS:
			continue
		var share := BOSS_SHARE if z == run.boss else (HEAVY_SHARE if z.data.heavy else 1.0)
		var falloff := lerpf(1.0, 0.5, d / BLAST_RADIUS)
		var dir := to.normalized() if d > 0.01 else Vector3.FORWARD
		z.knockback(dir * BLAST_PUSH * falloff + Vector3.UP * 3.0)
		z.interrupt()
		z.take_hit(BLAST_DAMAGE * scale * share * falloff, z.global_position + Vector3.UP, dir, &"blast_wave", false)
	Sfx.play_at(&"rounds_surge_hit", at + Vector3.UP, 2.0, 0.8, 30.0)
	run.player.add_shake(0.45)
	for i in 3:
		EndlessProps.burst(run.get_parent(), centre + Vector3.UP * 0.4, Vector3.UP, [Color(1.0, 0.85, 0.3), Color(1.0, 0.45, 0.15), Color(1.0, 0.95, 0.8)],
			40, 9.0 + i * 3.0, 0.6, 0.18, 88.0, Vector3(0, -2.0, 0))
	_ring(run.get_parent(), centre)


## An expanding flat ring of light out to BLAST_RADIUS.
func _ring(parent: Node, at: Vector3) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.85
	mesh.outer_radius = 1.0
	mesh.rings = 32
	mesh.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = EndlessPowerup._additive(Color(1.0, 0.6, 0.2, 0.8))
	parent.add_child(mi)
	mi.global_position = at + Vector3.UP * 0.5
	mi.scale = Vector3(1, 0.4, 1)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(BLAST_RADIUS, 0.6, BLAST_RADIUS), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(mi.queue_free)
